import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
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
  static const int _maxSignAttempts = 3;

  final PrivySdkService _privySdk;
  final LoggerService _logger;
  Future<void> _signQueue = Future.value();

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
      return await _serializeSigning(() async {
        _logger.info(
          'Signing transaction (${transactionMessage.length} bytes)',
          tag: 'WalletManager',
        );

        final messageBase64 = base64Encode(transactionMessage);
        final signatureResult = await _signMessageWithRetry(
          wallet,
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
        } else if (signatureResult is privy.Failure<String>) {
          throw Exception(
            'Privy signing failed: ${signatureResult.error.message}',
          );
        } else {
          throw Exception('Unknown Privy response type');
        }
      });
    } catch (error) {
      _logger.error('Transaction signing failed', error: error);
      return null;
    }
  }

  Future<T> _serializeSigning<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _signQueue = _signQueue.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
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

  /// Returns the Privy wallet ID for the embedded wallet, required by the
  /// server-side copy engine to sign on the user's behalf. Null when no
  /// embedded wallet is available or the SDK did not surface an ID.
  Future<String?> getWalletId() async {
    final wallet = await getOrCreateWallet();
    return wallet?.embeddedWallet.id;
  }

  /// Grants the always-on copy engine permission to transact from the embedded
  /// wallet by attaching the server's key-quorum signer, scoped to the supplied
  /// Phoenix-only [policyIds]. This is the on-device consent step the user
  /// takes before server-side mirroring can run while the app is closed.
  ///
  /// Returns true on success. Server signing remains impossible until this
  /// succeeds.
  Future<bool> attachServerSigner({
    required String signerId,
    List<String> policyIds = const [],
  }) async {
    try {
      final wallet = await getOrCreateWallet();
      if (wallet == null) {
        _logger.error('Cannot attach signer: no embedded wallet');
        return false;
      }

      final result = await wallet.embeddedWallet.addSigner(
        privy.SignerInput(
          signerId: signerId,
          policyIds: policyIds.isEmpty ? null : policyIds,
        ),
      );

      if (result is privy.Success<void>) {
        _logger.info('Server signer attached', tag: 'WalletManager');
        return true;
      }
      if (result is privy.Failure<void>) {
        final message = result.error.message;
        // Privy rejects re-adding a signer that is already on the wallet with a
        // "Duplicate signer(s)" 400. That means the signer is ALREADY attached,
        // so server signing is enabled — treat it as success and let the caller
        // persist the consent key so it stops retrying.
        if (_isAlreadyAttachedError(message)) {
          _logger.info(
            'Server signer already attached (Privy reported duplicate)',
            tag: 'WalletManager',
          );
          return true;
        }
        _logger.error('Failed to attach server signer: $message');
      }
      return false;
    } catch (error) {
      if (_isAlreadyAttachedError(error.toString())) {
        _logger.info(
          'Server signer already attached (duplicate on add)',
          tag: 'WalletManager',
        );
        return true;
      }
      _logger.error('Failed to attach server signer', error: error);
      return false;
    }
  }

  /// True when Privy rejects an `addSigner` because the signer is already
  /// present on the wallet. This is a benign, idempotent outcome — the signer
  /// is attached, so the consent step should be considered complete.
  bool _isAlreadyAttachedError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('duplicate signer') ||
        lower.contains('already been added') ||
        lower.contains('already added');
  }

  /// Revokes the server's signer from the embedded wallet, disabling all
  /// always-on mirroring. Use when the user turns copy automation fully off.
  Future<bool> detachServerSigner(String signerId) async {
    try {
      final wallet = await getOrCreateWallet();
      if (wallet == null) return false;

      final result = await wallet.embeddedWallet.removeSigner(signerId);
      if (result is privy.Success<void>) {
        _logger.info('Server signer detached', tag: 'WalletManager');
        return true;
      }
      if (result is privy.Failure<void>) {
        _logger.error(
          'Failed to detach server signer: ${result.error.message}',
        );
      }
      return false;
    } catch (error) {
      _logger.error('Failed to detach server signer', error: error);
      return false;
    }
  }

  Future<privy.Result<String>> _signMessageWithRetry(
    WalletInfo wallet,
    String messageBase64,
  ) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1; attempt <= _maxSignAttempts; attempt++) {
      try {
        await _privySdk.waitForReady();
        final result = await wallet.embeddedWallet.provider.signMessage(
          messageBase64,
        );

        if (result is privy.Failure<String> &&
            _isRetryableSigningMessage(result.error.message) &&
            attempt < _maxSignAttempts) {
          _logger.warning(
            'Privy signing ready check failed; retrying ($attempt/$_maxSignAttempts)',
            tag: 'WalletManager',
          );
          await Future.delayed(Duration(milliseconds: 350 * attempt));
          continue;
        }

        return result;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;

        if (!_isRetryableSigningError(error) || attempt == _maxSignAttempts) {
          rethrow;
        }

        _logger.warning(
          'Privy signing bridge not ready; retrying ($attempt/$_maxSignAttempts)',
          tag: 'WalletManager',
        );
        await Future.delayed(Duration(milliseconds: 350 * attempt));
      }
    }

    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  bool _isRetryableSigningError(Object error) {
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = error.message?.toLowerCase() ?? '';
      return code.contains('sign_message') &&
          _isRetryableSigningMessage(message);
    }
    return _isRetryableSigningMessage(error.toString());
  }

  bool _isRetryableSigningMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('timed out') ||
        normalized.contains('timeout') ||
        normalized.contains('ready request') ||
        normalized.contains('webview ready') ||
        normalized.contains('awaitready') ||
        normalized.contains('notready') ||
        normalized.contains('not ready');
  }
}
