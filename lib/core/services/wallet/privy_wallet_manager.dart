import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privy_flutter/privy_flutter.dart' as privy;

import '../logger_service.dart';
import '../privy_sdk_service.dart';

/// Provider for Privy wallet manager
final privyWalletManagerProvider = Provider<PrivyWalletManager>((ref) {
  final privySdk = ref.watch(privySdkServiceProvider);
  final logger = ref.watch(loggerServiceProvider);
  return PrivyWalletManager(privySdk, logger);
});

/// Wallet information from Privy
class WalletInfo {
  final String address;
  final privy.EmbeddedSolanaWallet embeddedWallet;

  const WalletInfo({required this.address, required this.embeddedWallet});
}

/// Manages Privy embedded Solana wallet operations
/// Handles wallet creation, transaction signing, and message signing
/// NO backend dependencies - all client-side operations
class PrivyWalletManager {
  final PrivySdkService _privySdk;
  final LoggerService _logger;

  PrivyWalletManager(this._privySdk, this._logger);

  /// Get or create embedded Solana wallet for current user
  /// Returns null if user not authenticated
  Future<WalletInfo?> getOrCreateWallet() async {
    try {
      final isAuth = await _privySdk.isAuthenticated();
      if (!isAuth) {
        _logger.warning('Cannot get wallet: user not authenticated');
        return null;
      }

      _logger.info('Getting/creating embedded Solana wallet');
      final wallet = await _privySdk.ensureEmbeddedSolanaWallet();

      if (wallet == null) {
        _logger.error('Failed to create embedded wallet');
        return null;
      }

      _logger.info('Wallet ready: ${wallet.address}');
      return WalletInfo(address: wallet.address, embeddedWallet: wallet);
    } catch (error) {
      _logger.error('Failed to get wallet', error: error);
      return null;
    }
  }

  /// Sign a Solana transaction message
  /// Returns base64-encoded signature
  Future<String?> signTransaction(
    WalletInfo wallet,
    Uint8List transactionMessage,
  ) async {
    try {
      _logger.info(
        'Signing transaction (${transactionMessage.length} bytes)',
        tag: 'WalletManager',
      );

      // Convert transaction bytes to base64 for Privy
      final messageBase64 = base64Encode(transactionMessage);

      // Sign with Privy embedded wallet
      final signatureResult = await wallet.embeddedWallet.provider.signMessage(
        messageBase64,
      );

      if (signatureResult is privy.Success<String>) {
        final signatureBase64 = signatureResult.value;
        final signatureBytes = base64Decode(signatureBase64);

        if (signatureBytes.length != 64) {
          throw Exception(
            'Invalid signature length: ${signatureBytes.length}. Expected 64 bytes',
          );
        }

        _logger.info('Transaction signed successfully', tag: 'WalletManager');
        return signatureBase64;
      } else if (signatureResult is privy.Failure) {
        throw Exception('Privy signing failed: ${signatureResult.toString()}');
      } else {
        throw Exception('Unknown Privy response type');
      }
    } catch (error) {
      _logger.error('Transaction signing failed', error: error);
      return null;
    }
  }

  /// Sign a pre-built Solana transaction message and return the signature
  /// For use with Bags API that returns transaction messages
  Future<String?> signTransactionMessage({
    required WalletInfo wallet,
    required Uint8List transactionMessage,
  }) async {
    return signTransaction(wallet, transactionMessage);
  }

  /// Sign an arbitrary message (for verification/authentication)
  /// Returns base64-encoded signature
  Future<String?> signMessage(WalletInfo wallet, String message) async {
    try {
      _logger.info('Signing message', tag: 'WalletManager');

      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final signatureBase64 = await signTransaction(wallet, messageBytes);

      if (signatureBase64 != null) {
        _logger.info('Message signed successfully', tag: 'WalletManager');
      }

      return signatureBase64;
    } catch (error) {
      _logger.error('Message signing failed', error: error);
      return null;
    }
  }

  /// Export wallet address (safe to share publicly)
  Future<String?> getWalletAddress() async {
    final wallet = await getOrCreateWallet();
    return wallet?.address;
  }
}
