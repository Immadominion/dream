import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana/base58.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

import '../logger_service.dart';
import '../solana/wire_transaction.dart';

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
  // One app identity for authorize *and* reauthorize — wallets bind auth
  // tokens to it, so a mismatch forces a fresh approval every time.
  static final _identityUri = Uri.parse('https://trydream.fun');
  static const _identityName = 'Dream';
  static final _iconUri = Uri.parse('favicon.png');

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
        identityUri: _identityUri,
        identityName: _identityName,
        iconUri: _iconUri,
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

  /// Open a wallet session, (re)authorize, and run [body] with the client.
  /// Returns null if authorization failed.
  Future<T?> _withAuthorizedClient<T>(
    Future<T> Function(MobileWalletAdapterClient client) body,
  ) async {
    final session = await LocalAssociationScenario.create();
    session.startActivityForResult(null).ignore();
    try {
      final client = await session.start();

      AuthorizationResult? authResult;
      if (_authToken != null) {
        try {
          authResult = await client.reauthorize(
            identityUri: _identityUri,
            identityName: _identityName,
            iconUri: _iconUri,
            authToken: _authToken!,
          );
          if (authResult != null) _authToken = authResult.authToken;
        } catch (e) {
          _logger.warning('Reauthorize failed: $e', tag: 'MWA');
        }
      }
      if (authResult == null) {
        authResult = await client.authorize(
          identityUri: _identityUri,
          identityName: _identityName,
          iconUri: _iconUri,
          cluster: 'mainnet-beta',
        );
        if (authResult == null) return null;
        _authToken = authResult.authToken;
        _connectedPublicKey = base58encode(authResult.publicKey);
      }
      return await body(client);
    } finally {
      try {
        await session.close();
      } catch (_) {}
    }
  }

  /// Sign a UTF-8 text message (SIWS / API auth). The wallet shows the text.
  Future<MwaSignResult> signMessage(String message) =>
      signMessageBytes(Uint8List.fromList(utf8.encode(message)));

  /// Sign raw message bytes with `signMessages`. Never use this for a
  /// transaction — wallets can't decode or simulate it; use
  /// [signTransactionMessage].
  Future<MwaSignResult> signMessageBytes(Uint8List messageBytes) async {
    if (!isAvailable) {
      return MwaSignResult.failure('MWA only available on Android');
    }
    if (_connectedPublicKey == null) {
      return MwaSignResult.failure('No wallet connected');
    }
    try {
      final signature = await _withAuthorizedClient((client) async {
        final result = await client.signMessages(
          messages: [messageBytes],
          addresses: [Uint8List.fromList(base58decode(_connectedPublicKey!))],
        );
        if (result.signedMessages.isEmpty ||
            result.signedMessages.first.signatures.isEmpty) {
          return null;
        }
        return result.signedMessages.first.signatures.first;
      });
      if (signature == null || signature.length != 64) {
        return MwaSignResult.failure('Wallet did not sign the message');
      }
      return MwaSignResult.success(signature);
    } catch (error, stackTrace) {
      _logger.error(
        'MWA message signing failed',
        error: error,
        stackTrace: stackTrace,
        tag: 'MWA',
      );
      return MwaSignResult.failure(error.toString());
    }
  }

  /// Sign a transaction given its serialized [message], via MWA
  /// `signTransactions` so the wallet decodes and simulates what it signs.
  ///
  /// Returns the connected wallet's 64-byte signature. Refuses the result if
  /// the wallet altered the message (the signature would then be over
  /// different bytes than the caller's, e.g. invalidating a server
  /// co-signature).
  Future<MwaSignResult> signTransactionMessage(Uint8List message) async {
    if (!isAvailable) {
      return MwaSignResult.failure('MWA only available on Android');
    }
    if (_connectedPublicKey == null) {
      return MwaSignResult.failure('No wallet connected');
    }
    try {
      final unsigned = WireTransaction.unsignedFromMessage(message);
      final signed = await _withAuthorizedClient((client) async {
        final result = await client.signTransactions(transactions: [unsigned]);
        return result.signedPayloads.isEmpty
            ? null
            : result.signedPayloads.first;
      });
      if (signed == null) {
        return MwaSignResult.failure('Wallet did not sign the transaction');
      }
      final tx = WireTransaction.parse(signed);
      if (!_bytesEqual(tx.message, message)) {
        return MwaSignResult.failure(
          'Wallet modified the transaction — not submitted',
        );
      }
      return MwaSignResult.success(tx.signatureOf(_connectedPublicKey!));
    } catch (error, stackTrace) {
      _logger.error(
        'MWA transaction signing failed',
        error: error,
        stackTrace: stackTrace,
        tag: 'MWA',
      );
      return MwaSignResult.failure(error.toString());
    }
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
