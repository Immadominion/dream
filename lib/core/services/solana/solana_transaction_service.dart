import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/solana.dart' as solana;

import '../logger_service.dart';
import '../wallet/privy_wallet_manager.dart';
import '../../constants/app_constants.dart';

/// Provider for Solana transaction service
final solanaTransactionServiceProvider = Provider<SolanaTransactionService>((
  ref,
) {
  final logger = ref.watch(loggerServiceProvider);
  final walletManager = ref.watch(privyWalletManagerProvider);
  return SolanaTransactionService(logger: logger, walletManager: walletManager);
});

/// Transaction result model
class TransactionResult {
  final bool success;
  final String? signature;
  final String? error;

  const TransactionResult({required this.success, this.signature, this.error});

  factory TransactionResult.success(String signature) =>
      TransactionResult(success: true, signature: signature);

  factory TransactionResult.failure(String error) =>
      TransactionResult(success: false, error: error);
}

/// Service for signing and broadcasting Solana transactions
/// Used by trading and fee claiming flows
class SolanaTransactionService {
  final LoggerService _logger;
  final PrivyWalletManager _walletManager;
  late final solana.SolanaClient _solanaClient;

  SolanaTransactionService({
    required LoggerService logger,
    required PrivyWalletManager walletManager,
  }) : _logger = logger,
       _walletManager = walletManager {
    // Initialize Solana client with Helius RPC
    _solanaClient = solana.SolanaClient(
      rpcUrl: Uri.parse(AppConstants.heliusRpcUrl),
      websocketUrl: Uri.parse(
        AppConstants.heliusRpcUrl.replaceFirst('https', 'wss'),
      ),
    );
    _logger.info('Solana client initialized with Helius RPC', tag: 'SolanaTx');
  }

  /// Get user's wallet from Privy
  Future<WalletInfo?> getWallet() async {
    return _walletManager.getOrCreateWallet();
  }

  /// Sign and broadcast a base64-encoded transaction
  ///
  /// [transactionBase64] - The base64-encoded transaction message from Bags API
  ///
  /// Returns a [TransactionResult] with the signature on success
  Future<TransactionResult> signAndBroadcast(String transactionBase64) async {
    try {
      _logger.info('Starting transaction signing flow', tag: 'SolanaTx');

      // Step 1: Get wallet
      final wallet = await _walletManager.getOrCreateWallet();
      if (wallet == null) {
        return TransactionResult.failure(
          'Wallet not available. Please sign in first.',
        );
      }

      // Step 2: Decode and sign transaction
      final signedTx = await _signTransaction(
        wallet: wallet,
        transactionBase64: transactionBase64,
      );

      if (signedTx == null) {
        return TransactionResult.failure('Failed to sign transaction');
      }

      // Step 3: Broadcast transaction
      final signature = await _broadcastTransaction(signedTx);

      _logger.info('Transaction successful: $signature', tag: 'SolanaTx');
      return TransactionResult.success(signature);
    } catch (error) {
      _logger.error('Transaction failed', error: error, tag: 'SolanaTx');
      return TransactionResult.failure(error.toString());
    }
  }

  /// Sign a transaction and return the signed bytes
  Future<Uint8List?> _signTransaction({
    required WalletInfo wallet,
    required String transactionBase64,
  }) async {
    try {
      _logger.info('Signing transaction', tag: 'SolanaTx');

      // Decode base64 transaction to get message bytes
      final messageBytes = base64Decode(transactionBase64);
      _logger.info(
        'Transaction message size: ${messageBytes.length} bytes',
        tag: 'SolanaTx',
      );

      // Sign the message bytes with Privy wallet
      final signatureBase64 = await _walletManager.signTransaction(
        wallet,
        Uint8List.fromList(messageBytes),
      );

      if (signatureBase64 == null) {
        throw Exception('Failed to get signature from wallet');
      }

      // Decode signature (should be 64 bytes)
      final signatureBytes = base64Decode(signatureBase64);
      if (signatureBytes.length != 64) {
        throw Exception(
          'Invalid signature length: ${signatureBytes.length} (expected 64)',
        );
      }

      _logger.info('Signature received: 64 bytes', tag: 'SolanaTx');

      // Construct signed transaction using Solana wire format:
      // signed_tx = shortvec(num_signatures) || signatures || message_bytes
      final builder = BytesBuilder();

      // Add shortvec encoding of number of signatures (1 signature)
      builder.add(_shortVecEncode(1));

      // Add the 64-byte signature
      builder.add(signatureBytes);

      // Add original message bytes
      builder.add(messageBytes);

      final signedTx = builder.toBytes();
      _logger.info(
        'Signed transaction constructed: ${signedTx.length} bytes',
        tag: 'SolanaTx',
      );

      return signedTx;
    } catch (error) {
      _logger.error(
        'Transaction signing failed',
        error: error,
        tag: 'SolanaTx',
      );
      return null;
    }
  }

  /// Broadcast signed transaction to Solana network
  Future<String> _broadcastTransaction(Uint8List signedTransaction) async {
    _logger.info('Broadcasting transaction to Solana', tag: 'SolanaTx');

    // Convert signed transaction bytes to base64
    final signedTxBase64 = base64Encode(signedTransaction);

    _logger.info(
      'Transaction preview: ${signedTxBase64.substring(0, signedTxBase64.length > 50 ? 50 : signedTxBase64.length)}...',
      tag: 'SolanaTx',
    );

    // Send transaction with confirmed commitment
    final txSignature = await _solanaClient.rpcClient.sendTransaction(
      signedTxBase64,
      preflightCommitment: solana.Commitment.confirmed,
    );

    _logger.info(
      '🎉 Transaction sent successfully: $txSignature',
      tag: 'SolanaTx',
    );
    _logger.info(
      '🔗 Explorer: https://explorer.solana.com/tx/$txSignature',
      tag: 'SolanaTx',
    );

    return txSignature;
  }

  /// Encode a number as a short vector (compact-u16)
  /// Used in Solana transaction wire format
  List<int> _shortVecEncode(int value) {
    if (value < 0x80) {
      return [value];
    } else if (value < 0x4000) {
      return [(value & 0x7f) | 0x80, value >> 7];
    } else if (value < 0x200000) {
      return [(value & 0x7f) | 0x80, ((value >> 7) & 0x7f) | 0x80, value >> 14];
    } else {
      throw Exception('Value too large for short vector encoding: $value');
    }
  }

  /// Get SOL balance for an address
  Future<double> getSolBalance(String address) async {
    try {
      final balance = await _solanaClient.rpcClient.getBalance(address);
      return balance.value / 1e9; // Convert lamports to SOL
    } catch (error) {
      _logger.error('Failed to get SOL balance', error: error, tag: 'SolanaTx');
      return 0;
    }
  }

  /// Get USDC balance for a wallet address.
  ///
  /// Uses `getTokenAccountsByOwner` JSON-RPC via Helius to find the wallet's
  /// USDC associated token account and return the human-readable balance.
  static const _usdcMint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

  Future<double> getUsdcBalance(String walletAddress) async {
    try {
      _logger.info('Fetching USDC balance for $walletAddress', tag: 'SolanaTx');
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final response = await dio.post<Map<String, dynamic>>(
        AppConstants.heliusRpcUrl,
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getTokenAccountsByOwner',
          'params': [
            walletAddress,
            {'mint': _usdcMint},
            {'encoding': 'jsonParsed'},
          ],
        },
      );

      final result = response.data?['result'] as Map<String, dynamic>?;
      final accounts = result?['value'] as List<dynamic>? ?? [];

      double total = 0.0;
      for (final acct in accounts) {
        final info =
            (acct
                as Map<
                  String,
                  dynamic
                >?)?['account']?['data']?['parsed']?['info'];
        if (info != null) {
          final uiAmount = info['tokenAmount']?['uiAmount'] as num?;
          total += uiAmount?.toDouble() ?? 0.0;
        }
      }
      _logger.info('USDC balance: $total', tag: 'SolanaTx');
      return total;
    } catch (error) {
      _logger.error(
        'Failed to get USDC balance',
        error: error,
        tag: 'SolanaTx',
      );
      return 0.0;
    }
  }
}
