import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/base58.dart';
import 'package:solana/solana.dart' as solana;

import '../../constants/app_constants.dart';
import '../../models/phoenix/phoenix_models.dart';
import '../logger_service.dart';
import '../phoenix/phoenix_auth_service.dart';
import '../wallet/mwa_wallet_service.dart';
import '../wallet/privy_wallet_manager.dart';

final phoenixOrderServiceProvider = Provider<PhoenixOrderService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  final authService = ref.watch(phoenixAuthServiceProvider);
  final privyWallet = ref.watch(privyWalletManagerProvider);
  final mwaService = ref.watch(mwaWalletServiceProvider);
  return PhoenixOrderService(
    logger: logger,
    authService: authService,
    privyWallet: privyWallet,
    mwaService: mwaService,
  );
});

/// Result of an order submission
class OrderResult {
  final bool success;
  final String? txSignature;
  final String? error;
  final double? estimatedLiquidationPrice;

  const OrderResult._({
    required this.success,
    this.txSignature,
    this.error,
    this.estimatedLiquidationPrice,
  });

  factory OrderResult.success(
    String txSignature, {
    double? estimatedLiquidationPrice,
  }) => OrderResult._(
    success: true,
    txSignature: txSignature,
    estimatedLiquidationPrice: estimatedLiquidationPrice,
  );

  factory OrderResult.failure(String error) =>
      OrderResult._(success: false, error: error);
}

/// Builds and submits Phoenix perpetuals orders.
///
/// Flow:
///   1. Call Phoenix API to build instruction bytes (no blockchain state needed)
///   2. Assemble a Solana legacy transaction from those instructions
///   3. Sign with Privy embedded wallet or MWA
///   4. Broadcast via Solana RPC (Helius)
class PhoenixOrderService {
  final LoggerService _logger;
  final PhoenixAuthService _authService;
  final PrivyWalletManager _privyWallet;
  final MwaWalletService _mwaService;
  late final Dio _dio;
  late final solana.SolanaClient _solana;

  PhoenixOrderService({
    required LoggerService logger,
    required PhoenixAuthService authService,
    required PrivyWalletManager privyWallet,
    required MwaWalletService mwaService,
  }) : _logger = logger,
       _authService = authService,
       _privyWallet = privyWallet,
       _mwaService = mwaService {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.phoenixApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = await _authService.getStoredSession();
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          handler.next(options);
        },
        onError: (err, handler) {
          _logger.error(
            'Order HTTP ${err.response?.statusCode}: ${err.requestOptions.path}',
            error: err,
            tag: 'Order',
          );
          handler.next(err);
        },
      ),
    );

    _solana = solana.SolanaClient(
      rpcUrl: Uri.parse(AppConstants.heliusRpcUrl),
      websocketUrl: Uri.parse(
        AppConstants.heliusRpcUrl.replaceFirst('https', 'wss'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Place a market order. [quantity] is the contract size in base asset units.
  /// [transferAmountUsdc] is the USDC collateral to transfer (in microcents, 10^6 per USD).
  Future<OrderResult> placeMarketOrder({
    required String authority,
    required String symbol,
    required String side, // 'buy' | 'sell'
    required double quantity,
    int transferAmountUsdc = 0,
    double? stopLossPrice,
    double? takeProfitPrice,
    int slippageBps = 50,
  }) async {
    try {
      _logger.info(
        'Building market order: $side $quantity $symbol (slippage ${slippageBps}bps)',
        tag: 'Order',
      );

      final tpSl = _buildTpSl(stopLossPrice, takeProfitPrice);
      final body = <String, dynamic>{
        'authority': authority,
        'symbol': symbol,
        'side': side,
        'quantity': quantity,
        if (transferAmountUsdc > 0) 'transferAmount': transferAmountUsdc,
        if (AppConstants.phoenixBuilderAuthority.isNotEmpty)
          'flightBuilderAuthority': AppConstants.phoenixBuilderAuthority,
        if (slippageBps != 50) 'slippageBps': slippageBps,
        'tpSl': ?tpSl,
      };

      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/ix/place-isolated-market-order-enhanced',
        data: body,
      );

      final orderResp = PhoenixEnhancedOrderResponse.fromJson(response.data!);
      _logger.info(
        'Built ${orderResp.instructions.length} instruction(s)',
        tag: 'Order',
      );

      final txSig = await _signAndSubmit(orderResp.instructions, authority);
      return OrderResult.success(
        txSig,
        estimatedLiquidationPrice: orderResp.estimatedLiquidationPrice,
      );
    } catch (e) {
      _logger.error('placeMarketOrder failed', error: e, tag: 'Order');
      return OrderResult.failure(e.toString());
    }
  }

  /// Close an open position entirely by placing a reverse market order.
  /// [side] is the current position side ('long' or 'short') — we flip it.
  Future<OrderResult> closePosition({
    required String authority,
    required String symbol,
    required String positionSide, // 'long' | 'short'
    required double sizeBase, // position size in base units
  }) async {
    // Closing a long = place a sell; closing a short = place a buy
    final closeSide = positionSide == 'long' ? 'sell' : 'buy';
    _logger.info(
      'Closing $positionSide position: $sizeBase $symbol → $closeSide',
      tag: 'Order',
    );
    return placeMarketOrder(
      authority: authority,
      symbol: symbol,
      side: closeSide,
      quantity: sizeBase,
    );
  }

  /// Cancel a conditional (stop/take-profit) order by its index.
  Future<OrderResult> cancelConditionalOrder({
    required String authority,
    required String symbol,
    required int conditionalOrderIndex,
    required String executionDirection, // 'above' | 'below'
  }) async {
    try {
      _logger.info(
        'Cancelling conditional order #$conditionalOrderIndex for $symbol',
        tag: 'Order',
      );

      final body = <String, dynamic>{
        'authority': authority,
        'conditionalOrderIndex': conditionalOrderIndex,
        'executionDirection': executionDirection,
        'symbol': symbol.replaceAll('-PERP', ''),
        'traderPdaIndex': 0,
      };

      // Returns a plain list of instruction objects (not wrapped in enhanced response)
      final response = await _dio.post<List<dynamic>>(
        '/v1/ix/cancel-conditional-order',
        data: body,
      );

      final instructions = (response.data ?? [])
          .cast<Map<String, dynamic>>()
          .map(PhoenixInstructionResponse.fromJson)
          .toList();

      if (instructions.isEmpty) {
        return OrderResult.failure('No cancel instructions returned');
      }

      final txSig = await _signAndSubmit(instructions, authority);
      return OrderResult.success(txSig);
    } catch (e) {
      _logger.error('cancelConditionalOrder failed', error: e, tag: 'Order');
      return OrderResult.failure(e.toString());
    }
  }

  /// Attach (or replace) TP/SL on an existing open position.
  ///
  /// Cancels any existing conditional orders for [symbol] (derived from
  /// [currentOrders]) and then places a reduce-only market order of zero size
  /// that carries the new TP/SL config.
  Future<OrderResult> setPositionTpSl({
    required String authority,
    required String symbol,
    required String positionSide, // 'long' | 'short'
    required List<PhoenixOpenOrder> currentOrders,
    double? stopLossPrice,
    double? takeProfitPrice,
  }) async {
    if (stopLossPrice == null && takeProfitPrice == null) {
      return OrderResult.failure('At least one of TP or SL must be provided');
    }

    try {
      _logger.info('Setting TP/SL for $symbol', tag: 'Order');

      // 1. Cancel all existing conditional orders for this symbol
      final conditionals = currentOrders
          .where((o) => o.isConditional && o.symbol == symbol)
          .toList();

      for (final order in conditionals) {
        if (order.conditionalOrderIndex == null ||
            order.executionDirection == null) {
          continue;
        }
        await cancelConditionalOrder(
          authority: authority,
          symbol: symbol,
          conditionalOrderIndex: order.conditionalOrderIndex!,
          executionDirection: order.executionDirection!,
        );
      }

      // 2. Place a reduce-only zero-size market order to attach new TP/SL.
      // Using the close side so it's reduce-only by nature.
      final closeSide = positionSide == 'long' ? 'sell' : 'buy';
      final tpSl = _buildTpSl(stopLossPrice, takeProfitPrice);

      final body = <String, dynamic>{
        'authority': authority,
        'symbol': symbol,
        'side': closeSide,
        'isReduceOnly': true,
        if (AppConstants.phoenixBuilderAuthority.isNotEmpty)
          'flightBuilderAuthority': AppConstants.phoenixBuilderAuthority,
        'tpSl': ?tpSl,
      };

      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/ix/place-isolated-market-order-enhanced',
        data: body,
      );

      final orderResp = PhoenixEnhancedOrderResponse.fromJson(response.data!);
      final txSig = await _signAndSubmit(orderResp.instructions, authority);
      _logger.info('TP/SL set: $txSig', tag: 'Order');
      return OrderResult.success(txSig);
    } catch (e) {
      _logger.error('setPositionTpSl failed', error: e, tag: 'Order');
      return OrderResult.failure(e.toString());
    }
  }

  /// Add USDC collateral to an existing isolated-margin position.
  ///
  /// [amountUsdc] is the amount in whole USDC (e.g. 50.0 = $50 USDC).
  Future<OrderResult> addCollateral({
    required String authority,
    required String symbol,
    required String positionSide,
    required double amountUsdc,
  }) async {
    if (amountUsdc <= 0) {
      return OrderResult.failure('Amount must be greater than zero');
    }
    try {
      _logger.info(
        'Adding \$${amountUsdc.toStringAsFixed(2)} collateral to $symbol',
        tag: 'Order',
      );

      // transferAmount is in USDC micro-units (10^6 per USDC)
      final transferMicro = (amountUsdc * 1e6).toInt();
      final closeSide = positionSide == 'long' ? 'sell' : 'buy';

      final body = <String, dynamic>{
        'authority': authority,
        'symbol': symbol,
        'side': closeSide,
        'isReduceOnly': true,
        'transferAmount': transferMicro,
        if (AppConstants.phoenixBuilderAuthority.isNotEmpty)
          'flightBuilderAuthority': AppConstants.phoenixBuilderAuthority,
      };

      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/ix/place-isolated-market-order-enhanced',
        data: body,
      );

      final orderResp = PhoenixEnhancedOrderResponse.fromJson(response.data!);
      final txSig = await _signAndSubmit(orderResp.instructions, authority);
      _logger.info('Collateral added: $txSig', tag: 'Order');
      return OrderResult.success(txSig);
    } catch (e) {
      _logger.error('addCollateral failed', error: e, tag: 'Order');
      return OrderResult.failure(e.toString());
    }
  }

  /// Place a limit order. [price] and [quantity] are in native units.
  Future<OrderResult> placeLimitOrder({
    required String authority,
    required String symbol,
    required String side,
    required double price,
    required double quantity,
    bool postOnly = false,
    int transferAmountUsdc = 0,
    double? stopLossPrice,
    double? takeProfitPrice,
  }) async {
    try {
      _logger.info(
        'Building limit order: $side $quantity $symbol @ $price',
        tag: 'Order',
      );

      final tpSl = _buildTpSl(stopLossPrice, takeProfitPrice);
      final body = <String, dynamic>{
        'authority': authority,
        'symbol': symbol,
        'side': side,
        'price': price,
        'quantity': quantity,
        'isPostOnly': postOnly,
        if (transferAmountUsdc > 0) 'transferAmount': transferAmountUsdc,
        if (AppConstants.phoenixBuilderAuthority.isNotEmpty)
          'flightBuilderAuthority': AppConstants.phoenixBuilderAuthority,
        'tpSl': ?tpSl,
      };

      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/ix/place-isolated-limit-order-enhanced',
        data: body,
      );

      final orderResp = PhoenixEnhancedOrderResponse.fromJson(response.data!);
      final txSig = await _signAndSubmit(orderResp.instructions, authority);
      return OrderResult.success(txSig);
    } catch (e) {
      _logger.error('placeLimitOrder failed', error: e, tag: 'Order');
      return OrderResult.failure(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Transaction building + signing
  // ---------------------------------------------------------------------------

  /// Build optional TP/SL map for order requests. Returns null when neither
  /// stop-loss nor take-profit price is provided.
  Map<String, dynamic>? _buildTpSl(double? stopLoss, double? takeProfit) {
    if (stopLoss == null && takeProfit == null) return null;
    return <String, dynamic>{
      'stopLossTriggerPrice': ?stopLoss,
      'stopLossExecutionPrice': ?stopLoss,
      'takeProfitTriggerPrice': ?takeProfit,
      'takeProfitExecutionPrice': ?takeProfit,
    };
  }

  Future<String> _signAndSubmit(
    List<PhoenixInstructionResponse> instructions,
    String feePayer,
  ) async {
    // 1. Get recent blockhash
    final bh = await _solana.rpcClient.getLatestBlockhash(
      commitment: solana.Commitment.confirmed,
    );
    final recentBlockhash = bh.value.blockhash;
    _logger.info('Blockhash: $recentBlockhash', tag: 'Order');

    // 2. Build serialized message
    final messageBytes = _buildMessage(
      instructions: instructions,
      feePayer: feePayer,
      recentBlockhash: recentBlockhash,
    );

    // 3. Sign
    final signatureBytes = await _sign(messageBytes, feePayer);

    // 4. Assemble signed tx: compact-u16(1) + sig + message
    final builder = BytesBuilder();
    builder.add(_compactU16(1));
    builder.add(signatureBytes);
    builder.add(messageBytes);
    final signedTx = builder.toBytes();

    // 5. Broadcast
    final txBase64 = base64Encode(signedTx);
    final txSig = await _solana.rpcClient.sendTransaction(
      txBase64,
      preflightCommitment: solana.Commitment.confirmed,
    );

    _logger.info('Order submitted: $txSig', tag: 'Order');
    return txSig;
  }

  Future<List<int>> _sign(List<int> messageBytes, String authority) async {
    final isMwa =
        _authService.persistedWalletType == 'mwa' &&
        _mwaService.connectedPublicKey == authority;

    if (isMwa) {
      final result = await _mwaService.signMessage(base64Encode(messageBytes));
      if (!result.success || result.signature == null) {
        throw Exception('MWA signing failed: ${result.error}');
      }
      return result.signature!.toList();
    }

    // Privy embedded wallet
    final wallet = await _privyWallet.getOrCreateWallet();
    if (wallet == null) throw Exception('No wallet available');
    final sigBase64 = await _privyWallet.signTransaction(
      wallet,
      Uint8List.fromList(messageBytes),
    );
    if (sigBase64 == null) throw Exception('Privy signing failed');
    return base64Decode(sigBase64).toList();
  }

  // ---------------------------------------------------------------------------
  // Solana message serialization
  // ---------------------------------------------------------------------------

  /// Build a Solana legacy transaction message from Phoenix instruction bytes.
  ///
  /// Message format:
  ///   [header 3 bytes] [accounts] [blockhash 32 bytes] [instructions]
  List<int> _buildMessage({
    required List<PhoenixInstructionResponse> instructions,
    required String feePayer,
    required String recentBlockhash,
  }) {
    // --- Collect all accounts, deduplicating by pubkey ---
    // Properties: signer/writable flags are OR'd across all instructions
    final accounts = <String, _AccountFlags>{
      feePayer: const _AccountFlags(isSigner: true, isWritable: true),
    };

    for (final ix in instructions) {
      for (final key in ix.keys) {
        final pk = key['pubkey'] as String;
        final isSigner = key['isSigner'] as bool? ?? false;
        final isWritable = key['isWritable'] as bool? ?? false;
        if (accounts.containsKey(pk)) {
          final existing = accounts[pk]!;
          accounts[pk] = _AccountFlags(
            isSigner: existing.isSigner || isSigner,
            isWritable: existing.isWritable || isWritable,
          );
        } else {
          accounts[pk] = _AccountFlags(
            isSigner: isSigner,
            isWritable: isWritable,
          );
        }
      }
      // Program IDs are non-signer, non-writable
      if (!accounts.containsKey(ix.programId)) {
        accounts[ix.programId] = const _AccountFlags(
          isSigner: false,
          isWritable: false,
        );
      }
    }

    // --- Sort accounts: (signer+writable) > (signer+readonly) > (writable) > (readonly) ---
    final sorted = accounts.entries.toList()
      ..sort((a, b) {
        if (a.key == feePayer) return -1;
        if (b.key == feePayer) return 1;
        final aScore =
            (a.value.isSigner ? 2 : 0) + (a.value.isWritable ? 1 : 0);
        final bScore =
            (b.value.isSigner ? 2 : 0) + (b.value.isWritable ? 1 : 0);
        return bScore.compareTo(aScore);
      });

    final keys = sorted.map((e) => e.key).toList();
    final idx = {for (var i = 0; i < keys.length; i++) keys[i]: i};

    // --- Count header values ---
    final numSigners = sorted.where((e) => e.value.isSigner).length;
    final numReadonlySigned = sorted
        .where((e) => e.value.isSigner && !e.value.isWritable)
        .length;
    final numReadonlyUnsigned = sorted
        .where((e) => !e.value.isSigner && !e.value.isWritable)
        .length;

    // --- Serialize ---
    final buf = BytesBuilder();

    // Header
    buf.addByte(numSigners);
    buf.addByte(numReadonlySigned);
    buf.addByte(numReadonlyUnsigned);

    // Account keys
    buf.add(_compactU16(keys.length));
    for (final pk in keys) {
      buf.add(base58decode(pk));
    }

    // Recent blockhash
    buf.add(base58decode(recentBlockhash));

    // Instructions
    buf.add(_compactU16(instructions.length));
    for (final ix in instructions) {
      buf.addByte(idx[ix.programId]!);
      buf.add(_compactU16(ix.keys.length));
      for (final key in ix.keys) {
        buf.addByte(idx[key['pubkey'] as String]!);
      }
      buf.add(_compactU16(ix.data.length));
      buf.add(ix.data.map((b) => b & 0xFF).toList());
    }

    return buf.toBytes().toList();
  }

  /// Encode a number as compact-u16 (Solana short-vector format)
  List<int> _compactU16(int value) {
    if (value < 0x80) return [value];
    if (value < 0x4000) return [(value & 0x7F) | 0x80, value >> 7];
    return [(value & 0x7F) | 0x80, ((value >> 7) & 0x7F) | 0x80, value >> 14];
  }
}

class _AccountFlags {
  final bool isSigner;
  final bool isWritable;
  const _AccountFlags({required this.isSigner, required this.isWritable});
}
