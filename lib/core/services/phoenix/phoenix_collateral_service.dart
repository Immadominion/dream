import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart' as solana;

import '../../constants/app_constants.dart';
import '../logger_service.dart';
import '../solana/solana_transaction_service.dart';
import '../wallet/mwa_wallet_service.dart';
import '../wallet/privy_wallet_manager.dart';

final phoenixCollateralServiceProvider = Provider<PhoenixCollateralService>((
  ref,
) {
  return PhoenixCollateralService(
    logger: ref.watch(loggerServiceProvider),
    privyWallet: ref.watch(privyWalletManagerProvider),
    mwaService: ref.watch(mwaWalletServiceProvider),
    solanaTransactionService: ref.watch(solanaTransactionServiceProvider),
  );
});

class PhoenixCollateralService {
  static const usdcDecimals = 6;
  static const _phoenixLogAuthority =
      'GdxfTLSsdSY37G6fZoYtdGDSfgFnbT2EmRpuePZxWShS';
  static const _emberProgram = 'EMBERpYNE6ehWmXymZZS2skiFmCa9V5dp14e1iduM5qy';
  static const _tokenProgram = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
  static const _associatedTokenProgram =
      'ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL';
  static const _systemProgram = '11111111111111111111111111111111';
  static const _rentSysvar = 'SysvarRent111111111111111111111111111111111';

  final LoggerService _logger;
  final PrivyWalletManager _privyWallet;
  final MwaWalletService _mwaService;
  final SolanaTransactionService _solanaTransactionService;
  late final solana.SolanaClient _solana;
  late final Dio _dio;

  PhoenixCollateralService({
    required LoggerService logger,
    required PrivyWalletManager privyWallet,
    required MwaWalletService mwaService,
    required SolanaTransactionService solanaTransactionService,
  }) : _logger = logger,
       _privyWallet = privyWallet,
       _mwaService = mwaService,
       _solanaTransactionService = solanaTransactionService {
    _solana = solana.SolanaClient(
      rpcUrl: Uri.parse(AppConstants.heliusRpcUrl),
      websocketUrl: Uri.parse(
        AppConstants.heliusRpcUrl.replaceFirst('https', 'wss'),
      ),
    );
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.phoenixApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<TransactionResult> depositUsdc({
    required String authority,
    required double amountUsdc,
  }) async {
    try {
      if (amountUsdc <= 0) {
        return TransactionResult.failure('Amount must be greater than 0');
      }

      final walletBalance = await _solanaTransactionService.getUsdcBalance(
        authority,
      );
      if (walletBalance + 0.000001 < amountUsdc) {
        return TransactionResult.failure(
          'Insufficient wallet USDC (have ${walletBalance.toStringAsFixed(2)}, '
          'need ${amountUsdc.toStringAsFixed(2)})',
        );
      }

      final exchange = await _fetchExchangeAccounts();
      final authorityPk = _pk(authority);
      final usdcMint = _pk(exchange.usdcMint);
      final canonicalMint = _pk(exchange.canonicalMint);
      final programId = _pk(exchange.programId);
      final emberProgram = _pk(_emberProgram);

      final traderAccount = await _findProgramAddress(
        programId: programId,
        seeds: [
          utf8.encode('trader'),
          authorityPk.bytes,
          [0],
          [0],
        ],
      );
      final usdcAta = await solana.findAssociatedTokenAddress(
        owner: authorityPk,
        mint: usdcMint,
      );
      final phoenixAta = await solana.findAssociatedTokenAddress(
        owner: authorityPk,
        mint: canonicalMint,
      );
      final emberState = await _findProgramAddress(
        programId: emberProgram,
        seeds: [programId.bytes, utf8.encode('state')],
      );
      final emberVault = await _findProgramAddress(
        programId: emberProgram,
        seeds: [programId.bytes, utf8.encode('vault')],
      );
      final amountBase = (amountUsdc * 1000000).round();

      final instructions = <Instruction>[
        _createAssociatedTokenAccountIdempotent(
          funder: authorityPk,
          address: phoenixAta,
          owner: authorityPk,
          mint: canonicalMint,
        ),
        _emberDepositInstruction(
          owner: authorityPk,
          emberState: emberState,
          inputMint: usdcMint,
          outputMint: canonicalMint,
          inputTokenAccount: usdcAta,
          outputTokenAccount: phoenixAta,
          emberVault: emberVault,
          amountBase: amountBase,
        ),
        _depositFundsInstruction(
          exchange: exchange,
          trader: authorityPk,
          traderAccount: traderAccount,
          traderTokenAccount: phoenixAta,
          amountBase: amountBase,
        ),
      ];

      _logger.info(
        'Depositing $amountUsdc wallet USDC to Phoenix collateral',
        tag: 'PhoenixCollateral',
      );

      final blockhashResp = await _solana.rpcClient.getLatestBlockhash(
        commitment: solana.Commitment.confirmed,
      );
      final message = solana.Message(instructions: instructions);
      final compiled = message.compile(
        recentBlockhash: blockhashResp.value.blockhash,
        feePayer: authorityPk,
      );
      final messageBytes = Uint8List.fromList(compiled.toByteArray().toList());
      final signatureBytes = await _signMessage(messageBytes, authority);

      final builder = BytesBuilder();
      builder.add(_compactU16(1));
      builder.add(signatureBytes);
      builder.add(messageBytes);

      final signature = await _solana.rpcClient.sendTransaction(
        base64Encode(builder.toBytes()),
        preflightCommitment: solana.Commitment.confirmed,
      );

      await _waitForConfirmation(signature);

      _logger.info(
        'Phoenix collateral deposit submitted: $signature',
        tag: 'PhoenixCollateral',
      );
      return TransactionResult.success(signature);
    } catch (error, stackTrace) {
      _logger.error(
        'Phoenix collateral deposit failed',
        error: error,
        stackTrace: stackTrace,
        tag: 'PhoenixCollateral',
      );
      return TransactionResult.failure(_humanError(error));
    }
  }

  Future<_PhoenixExchangeAccounts> _fetchExchangeAccounts() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/exchange/snapshot',
    );
    final exchange = response.data?['exchange'] as Map<String, dynamic>?;
    if (exchange == null) {
      throw StateError('Phoenix exchange snapshot missing exchange keys');
    }

    final globalTraderIndex = _stringList(exchange['globalTraderIndex']);
    final activeTraderBuffer = _stringList(exchange['activeTraderBuffer']);
    if (globalTraderIndex.isEmpty || activeTraderBuffer.isEmpty) {
      throw StateError('Phoenix exchange index accounts are unavailable');
    }

    return _PhoenixExchangeAccounts(
      programId: _requiredString(exchange, 'programId'),
      globalConfig: _requiredString(exchange, 'globalConfig'),
      canonicalMint: _requiredString(exchange, 'canonicalMint'),
      usdcMint: _requiredString(exchange, 'usdcMint'),
      globalVault: _requiredString(exchange, 'globalVault'),
      globalTraderIndex: globalTraderIndex,
      activeTraderBuffer: activeTraderBuffer,
    );
  }

  Instruction _createAssociatedTokenAccountIdempotent({
    required solana.Ed25519HDPublicKey funder,
    required solana.Ed25519HDPublicKey address,
    required solana.Ed25519HDPublicKey owner,
    required solana.Ed25519HDPublicKey mint,
  }) {
    return Instruction(
      programId: _pk(_associatedTokenProgram),
      accounts: [
        AccountMeta.writeable(pubKey: funder, isSigner: true),
        AccountMeta.writeable(pubKey: address, isSigner: false),
        AccountMeta.readonly(pubKey: owner, isSigner: false),
        AccountMeta.readonly(pubKey: mint, isSigner: false),
        AccountMeta.readonly(pubKey: _pk(_systemProgram), isSigner: false),
        AccountMeta.readonly(pubKey: _pk(_tokenProgram), isSigner: false),
        AccountMeta.readonly(pubKey: _pk(_rentSysvar), isSigner: false),
      ],
      data: ByteArray([1]),
    );
  }

  Instruction _emberDepositInstruction({
    required solana.Ed25519HDPublicKey owner,
    required solana.Ed25519HDPublicKey emberState,
    required solana.Ed25519HDPublicKey inputMint,
    required solana.Ed25519HDPublicKey outputMint,
    required solana.Ed25519HDPublicKey inputTokenAccount,
    required solana.Ed25519HDPublicKey outputTokenAccount,
    required solana.Ed25519HDPublicKey emberVault,
    required int amountBase,
  }) {
    return Instruction(
      programId: _pk(_emberProgram),
      accounts: [
        AccountMeta.readonly(pubKey: owner, isSigner: true),
        AccountMeta.readonly(pubKey: emberState, isSigner: false),
        AccountMeta.readonly(pubKey: inputMint, isSigner: false),
        AccountMeta.writeable(pubKey: outputMint, isSigner: false),
        AccountMeta.writeable(pubKey: inputTokenAccount, isSigner: false),
        AccountMeta.writeable(pubKey: outputTokenAccount, isSigner: false),
        AccountMeta.writeable(pubKey: emberVault, isSigner: false),
        AccountMeta.readonly(pubKey: _pk(_tokenProgram), isSigner: false),
      ],
      data: _anchorU64Data('global:deposit', amountBase),
    );
  }

  Instruction _depositFundsInstruction({
    required _PhoenixExchangeAccounts exchange,
    required solana.Ed25519HDPublicKey trader,
    required solana.Ed25519HDPublicKey traderAccount,
    required solana.Ed25519HDPublicKey traderTokenAccount,
    required int amountBase,
  }) {
    return Instruction(
      programId: _pk(exchange.programId),
      accounts: [
        AccountMeta.readonly(pubKey: _pk(exchange.programId), isSigner: false),
        AccountMeta.readonly(
          pubKey: _pk(_phoenixLogAuthority),
          isSigner: false,
        ),
        AccountMeta.writeable(
          pubKey: _pk(exchange.globalConfig),
          isSigner: false,
        ),
        AccountMeta.readonly(pubKey: trader, isSigner: true),
        AccountMeta.writeable(pubKey: traderTokenAccount, isSigner: false),
        AccountMeta.writeable(pubKey: traderAccount, isSigner: false),
        AccountMeta.writeable(
          pubKey: _pk(exchange.globalVault),
          isSigner: false,
        ),
        AccountMeta.readonly(pubKey: _pk(_tokenProgram), isSigner: false),
        ...exchange.globalTraderIndex.map(
          (address) =>
              AccountMeta.writeable(pubKey: _pk(address), isSigner: false),
        ),
        ...exchange.activeTraderBuffer.map(
          (address) =>
              AccountMeta.writeable(pubKey: _pk(address), isSigner: false),
        ),
      ],
      data: _anchorU64Data('global:deposit_funds', amountBase),
    );
  }

  ByteArray _anchorU64Data(String discriminatorSource, int amount) {
    final discriminator = sha256
        .convert(utf8.encode(discriminatorSource))
        .bytes
        .take(8);
    return ByteArray.merge([ByteArray(discriminator), ByteArray.u64(amount)]);
  }

  Future<List<int>> _signMessage(
    Uint8List messageBytes,
    String authority,
  ) async {
    if (_mwaService.connectedPublicKey == authority) {
      final result = await _mwaService.signMessage(base64Encode(messageBytes));
      if (!result.success || result.signature == null) {
        throw Exception('MWA signing failed: ${result.error ?? 'unknown'}');
      }
      return result.signature!.toList();
    }

    final wallet = await _privyWallet.getOrCreateWallet();
    if (wallet == null) {
      throw Exception('Privy wallet unavailable');
    }
    final sigBase64 = await _privyWallet.signTransaction(wallet, messageBytes);
    if (sigBase64 == null) {
      throw Exception('Privy signing failed');
    }
    return base64Decode(sigBase64).toList();
  }

  Future<solana.Ed25519HDPublicKey> _findProgramAddress({
    required solana.Ed25519HDPublicKey programId,
    required Iterable<Iterable<int>> seeds,
  }) {
    return solana.Ed25519HDPublicKey.findProgramAddress(
      seeds: seeds,
      programId: programId,
    );
  }

  solana.Ed25519HDPublicKey _pk(String address) {
    return solana.Ed25519HDPublicKey.fromBase58(address);
  }

  static List<int> _compactU16(int value) {
    if (value < 0x80) return [value];
    if (value < 0x4000) return [(value & 0x7f) | 0x80, value >> 7];
    return [(value & 0x7f) | 0x80, ((value >> 7) & 0x7f) | 0x80, value >> 14];
  }

  Future<void> _waitForConfirmation(
    String txSignature, {
    int maxAttempts = 30,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final statuses = await _solana.rpcClient.getSignatureStatuses([
        txSignature,
      ]);
      final status = statuses.value.isNotEmpty ? statuses.value.first : null;

      if (status?.err != null) {
        throw Exception('Transaction failed on-chain: ${status!.err}');
      }

      if (status?.confirmationStatus != null) {
        return;
      }

      await Future<void>.delayed(const Duration(seconds: 1));
    }

    throw Exception('Transaction not confirmed within 30 seconds');
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw StateError('Phoenix exchange snapshot missing $key');
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().where((e) => e.isNotEmpty).toList();
  }

  String _humanError(Object error) {
    final value = error.toString();
    if (value.contains('insufficient funds') ||
        value.contains('insufficient lamports')) {
      return 'Insufficient SOL for the network fee';
    }
    if (value.contains('insufficient') || value.contains('Insufficient')) {
      return 'Insufficient wallet USDC for this deposit';
    }
    if (value.contains('blockhash')) {
      return 'Network busy. Please try again';
    }
    return value.replaceFirst('Exception: ', '');
  }
}

class _PhoenixExchangeAccounts {
  final String programId;
  final String globalConfig;
  final String canonicalMint;
  final String usdcMint;
  final String globalVault;
  final List<String> globalTraderIndex;
  final List<String> activeTraderBuffer;

  const _PhoenixExchangeAccounts({
    required this.programId,
    required this.globalConfig,
    required this.canonicalMint,
    required this.usdcMint,
    required this.globalVault,
    required this.globalTraderIndex,
    required this.activeTraderBuffer,
  });
}
