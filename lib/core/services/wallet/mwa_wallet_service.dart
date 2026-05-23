import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/base58.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

import '../logger_service.dart';

/// Result of MWA wallet connection
class MwaConnectionResult {
  final bool success;
  final String? publicKey;
  final String? authToken;
  final String? accountLabel;
  final String? error;

  const MwaConnectionResult._({
    required this.success,
    this.publicKey,
    this.authToken,
    this.accountLabel,
    this.error,
  });

  factory MwaConnectionResult.success({
    required String publicKey,
    required String authToken,
    String? accountLabel,
  }) {
    return MwaConnectionResult._(
      success: true,
      publicKey: publicKey,
      authToken: authToken,
      accountLabel: accountLabel,
    );
  }

  factory MwaConnectionResult.failure(String error) {
    return MwaConnectionResult._(success: false, error: error);
  }
}

/// Result of MWA message signing
class MwaSignResult {
  final bool success;
  final Uint8List? signature;
  final String? error;

  const MwaSignResult._({required this.success, this.signature, this.error});

  factory MwaSignResult.success(Uint8List signature) {
    return MwaSignResult._(success: true, signature: signature);
  }

  factory MwaSignResult.failure(String error) {
    return MwaSignResult._(success: false, error: error);
  }
}

/// Service for Mobile Wallet Adapter (MWA) operations
/// Android-only - connects to external wallets like Phantom, Solflare
class MwaWalletService {
  final LoggerService _logger;

  MwaWalletService(this._logger);

  /// Check if MWA is available (Android only)
  bool get isAvailable => Platform.isAndroid;

  /// Currently connected wallet address (base58)
  String? _connectedPublicKey;
  String? _authToken;

  String? get connectedPublicKey => _connectedPublicKey;

  /// Connect to an external wallet via MWA
  /// Returns the wallet's public key (base58 encoded)
  Future<MwaConnectionResult> connectWallet() async {
    if (!isAvailable) {
      return MwaConnectionResult.failure('MWA only available on Android');
    }

    try {
      _logger.info('Starting MWA wallet connection', tag: 'MWA');

      // Create local association session
      final session = await LocalAssociationScenario.create();

      // Start the wallet app activity - don't await, let it run in background
      session.startActivityForResult(null).ignore();

      // Get the MWA client
      final client = await session.start();

      // Authorize with the wallet
      final authResult = await client.authorize(
        identityUri: Uri.parse('https://solana.com'),
        identityName: 'Dream',
        iconUri: Uri.parse('favicon.ico'),
        cluster: 'mainnet-beta',
      );

      // Check if authorization succeeded
      if (authResult == null) {
        await session.close();
        return MwaConnectionResult.failure(
          'Wallet authorization failed or was cancelled',
        );
      }

      // Extract authorization details
      final authToken = authResult.authToken;
      final publicKey = authResult.publicKey;
      final accountLabel = authResult.accountLabel;

      if (publicKey.isEmpty) {
        await session.close();
        return MwaConnectionResult.failure('No wallet address returned');
      }

      // Convert public key bytes to base58
      final publicKeyBase58 = base58encode(publicKey);

      // Store connection info
      _connectedPublicKey = publicKeyBase58;
      _authToken = authToken;

      _logger.info(
        'MWA connected: $publicKeyBase58 ($accountLabel)',
        tag: 'MWA',
      );

      // Close session after authorization
      await session.close();

      return MwaConnectionResult.success(
        publicKey: publicKeyBase58,
        authToken: authToken,
        accountLabel: accountLabel,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'MWA connection failed',
        error: error,
        stackTrace: stackTrace,
        tag: 'MWA',
      );
      return MwaConnectionResult.failure(error.toString());
    }
  }

  /// Sign a message with the connected wallet
  /// Used for SIWS (Sign-In With Solana)
  Future<MwaSignResult> signMessage(String message) async {
    if (!isAvailable) {
      return MwaSignResult.failure('MWA only available on Android');
    }

    if (_connectedPublicKey == null) {
      return MwaSignResult.failure('No wallet connected');
    }

    try {
      _logger.info('Signing message via MWA', tag: 'MWA');

      // Create a new session for signing
      final session = await LocalAssociationScenario.create();

      // Start the wallet app activity - use .ignore() to not block
      session.startActivityForResult(null).ignore();

      // Get the MWA client
      final client = await session.start();

      // Reauthorize with stored auth token
      AuthorizationResult? authResult;

      if (_authToken != null) {
        _logger.info('Attempting reauthorize with stored token', tag: 'MWA');
        try {
          authResult = await client.reauthorize(
            identityUri: Uri.parse('https://solana.com'),
            identityName: 'Dream',
            iconUri: Uri.parse('favicon.ico'),
            authToken: _authToken!,
          );

          if (authResult != null) {
            // Update stored auth token
            _authToken = authResult.authToken;
            _logger.info('Reauthorize succeeded', tag: 'MWA');
          }
        } catch (e) {
          _logger.warning('Reauthorize failed: $e', tag: 'MWA');
        }
      }

      // If reauthorize failed or no token, do full authorization
      if (authResult == null) {
        _logger.info('Doing full authorization for signing', tag: 'MWA');
        authResult = await client.authorize(
          identityUri: Uri.parse('https://solana.com'),
          identityName: 'Dream',
          iconUri: Uri.parse('favicon.ico'),
          cluster: 'mainnet-beta',
        );

        if (authResult == null) {
          await session.close();
          return MwaSignResult.failure(
            'Failed to authorize wallet for signing',
          );
        }

        // Update stored values
        _authToken = authResult.authToken;
        _connectedPublicKey = base58encode(authResult.publicKey);
      }

      // Convert message to bytes
      final messageBytes = Uint8List.fromList(utf8.encode(message));

      // Get public key bytes from base58
      final publicKeyBytes = Uint8List.fromList(
        base58decode(_connectedPublicKey!),
      );

      _logger.info(
        'Calling signMessages with ${messageBytes.length} byte message',
        tag: 'MWA',
      );

      // Sign the message
      final signResult = await client.signMessages(
        messages: [messageBytes],
        addresses: [publicKeyBytes],
      );

      // Close session
      try {
        await session.close();
      } catch (_) {}

      if (signResult.signedMessages.isEmpty) {
        return MwaSignResult.failure('No signature returned');
      }

      // Get the signed message which contains the signature
      final signedMessage = signResult.signedMessages.first;

      // Get the first signature
      if (signedMessage.signatures.isEmpty) {
        return MwaSignResult.failure('No signature in result');
      }

      final signature = signedMessage.signatures.first;

      if (signature.length != 64) {
        return MwaSignResult.failure(
          'Invalid signature length: ${signature.length}',
        );
      }

      _logger.info(
        'Message signed successfully (${signature.length} bytes)',
        tag: 'MWA',
      );

      return MwaSignResult.success(signature);
    } catch (error, stackTrace) {
      _logger.error(
        'MWA signing failed',
        error: error,
        stackTrace: stackTrace,
        tag: 'MWA',
      );
      return MwaSignResult.failure(error.toString());
    }
  }

  /// Disconnect wallet (clear local state)
  void disconnect() {
    _connectedPublicKey = null;
    _authToken = null;
    _logger.info('MWA wallet disconnected', tag: 'MWA');
  }
}

/// Provider for MWA wallet service
final mwaWalletServiceProvider = Provider<MwaWalletService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  return MwaWalletService(logger);
});
