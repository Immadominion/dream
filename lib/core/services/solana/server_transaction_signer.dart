import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/solana.dart' as solana;

import '../../constants/app_constants.dart';
import '../logger_service.dart';
import '../phoenix/phoenix_auth_service.dart';
import '../wallet/mwa_wallet_service.dart';
import '../wallet/privy_wallet_manager.dart';
import 'server_tx_guard.dart';
import 'wire_transaction.dart';

export 'server_tx_guard.dart'
    show
        ServerTxIntent,
        LaunchCoinIntent,
        SwapCoinIntent,
        ClaimFeesIntent,
        UnsafeTransactionException;

final serverTransactionSignerProvider = Provider<ServerTransactionSigner>((
  ref,
) {
  return ServerTransactionSigner(
    logger: ref.watch(loggerServiceProvider),
    privyWallet: ref.watch(privyWalletManagerProvider),
    mwaService: ref.watch(mwaWalletServiceProvider),
    phoenixAuthService: ref.watch(phoenixAuthServiceProvider),
  );
});

class ServerTransactionException implements Exception {
  final String message;
  const ServerTransactionException(this.message);
  @override
  String toString() => message;
}

/// Signs and submits transactions built by dream-server.
///
/// The server never holds user keys: it returns an unsigned (or partially
/// signed, e.g. by a fresh mint keypair) transaction. Before anything is
/// signed, [ServerTxGuard] checks the transaction does exactly what the user
/// asked ([ServerTxIntent]) — so a compromised server can't slip in a
/// transfer. Then the user's wallet signs (MWA via `signTransactions`, so the
/// wallet also decodes and simulates it), the signature is spliced into the
/// user's slot, and the transaction is broadcast and confirmed.
class ServerTransactionSigner {
  final LoggerService _logger;
  final PrivyWalletManager _privyWallet;
  final MwaWalletService _mwaService;
  final PhoenixAuthService _phoenixAuthService;
  late final solana.SolanaClient _solana;

  ServerTransactionSigner({
    required LoggerService logger,
    required PrivyWalletManager privyWallet,
    required MwaWalletService mwaService,
    required PhoenixAuthService phoenixAuthService,
  }) : _logger = logger,
       _privyWallet = privyWallet,
       _mwaService = mwaService,
       _phoenixAuthService = phoenixAuthService {
    _solana = solana.SolanaClient(
      rpcUrl: Uri.parse(AppConstants.heliusRpcUrl),
      websocketUrl: Uri.parse(
        AppConstants.heliusRpcUrl.replaceFirst('https', 'wss'),
      ),
    );
  }

  /// Verify [transactionBase64] matches [intent], sign it as [walletAddress],
  /// submit it and wait for confirmation. Returns the transaction signature.
  Future<String> signAndSend({
    required String transactionBase64,
    required String walletAddress,
    required ServerTxIntent intent,
  }) async {
    final WireTransaction wire;
    try {
      wire = WireTransaction.parse(base64Decode(transactionBase64));
    } on WireTransactionException catch (e) {
      throw ServerTransactionException(e.message);
    }
    await ServerTxGuard.check(wire, wallet: walletAddress, intent: intent);

    final signature = await _sign(wire.message, walletAddress);
    final signed = wire.withSignature(walletAddress, signature);

    final txSig = await _solana.rpcClient.sendTransaction(
      base64Encode(signed),
      preflightCommitment: solana.Commitment.confirmed,
    );
    _logger.info('Submitted server-built tx $txSig', tag: '[ServerTx]');
    await _waitForConfirmation(txSig);
    return txSig;
  }

  Future<List<int>> _sign(Uint8List message, String walletAddress) async {
    final isMwa =
        _phoenixAuthService.persistedWalletType == 'mwa' &&
        _mwaService.connectedPublicKey == walletAddress;

    if (isMwa) {
      final result = await _mwaService.signTransactionMessage(message);
      if (!result.success || result.signature == null) {
        throw ServerTransactionException(
          result.error ?? 'Wallet declined to sign',
        );
      }
      return result.signature!.toList();
    }

    final wallet = await _privyWallet.getOrCreateWallet();
    if (wallet == null) {
      throw const ServerTransactionException('No wallet available');
    }
    if (wallet.address != walletAddress) {
      throw const ServerTransactionException('Active wallet mismatch');
    }
    final sigBase64 = await _privyWallet.signTransaction(wallet, message);
    if (sigBase64 == null) {
      throw const ServerTransactionException('Signing failed');
    }
    return base64Decode(sigBase64).toList();
  }

  Future<void> _waitForConfirmation(String txSignature) async {
    for (var i = 0; i < 45; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        final statuses = await _solana.rpcClient.getSignatureStatuses([
          txSignature,
        ]);
        final status = statuses.value.first;
        if (status == null) continue;
        if (status.err != null) {
          throw const ServerTransactionException('Transaction failed on-chain');
        }
        // 'processed' can still be rolled back; wait for at least confirmed.
        if (status.confirmationStatus != solana.Commitment.processed) return;
      } on ServerTransactionException {
        rethrow;
      } catch (_) {
        // Transient RPC error — keep polling.
      }
    }
    throw const ServerTransactionException(
      'Transaction not confirmed in time — check your wallet before retrying',
    );
  }
}
