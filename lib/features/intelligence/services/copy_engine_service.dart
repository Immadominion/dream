import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/phoenix/phoenix_auth_service.dart';
import '../../../core/services/wallet/mwa_wallet_service.dart';
import '../../../core/services/wallet/privy_wallet_manager.dart';
import '../models/intelligence_models.dart';

final copyEngineServiceProvider = Provider<CopyEngineService>((ref) {
  return CopyEngineService(
    logger: ref.watch(loggerServiceProvider),
    privyWallet: ref.watch(privyWalletManagerProvider),
    mwaService: ref.watch(mwaWalletServiceProvider),
    phoenixAuthService: ref.watch(phoenixAuthServiceProvider),
  );
});

/// A single server-side copy subscription as reported by dream-server.
class CopySubscriptionRecord {
  final String leaderWallet;
  final String status; // 'active' | 'paused'
  final CopySettings settings;

  const CopySubscriptionRecord({
    required this.leaderWallet,
    required this.status,
    required this.settings,
  });

  bool get isActive => status == 'active';

  factory CopySubscriptionRecord.fromJson(Map<String, dynamic> j) {
    final rawSettings = j['settings'];
    return CopySubscriptionRecord(
      leaderWallet: (j['leaderWallet'] as String?) ?? '',
      status: (j['status'] as String?) ?? 'paused',
      settings: rawSettings is Map<String, dynamic>
          ? CopySettings.fromJson(rawSettings)
          : const CopySettings(),
    );
  }
}

/// Describes the signer the client must attach on-device (via Privy
/// `addSigner`) so the server can mirror trades while the app is closed.
class SignerConfig {
  final String signerId;
  final List<String> policyIds;

  const SignerConfig({required this.signerId, required this.policyIds});

  bool get isConfigured => signerId.isNotEmpty;

  factory SignerConfig.fromJson(Map<String, dynamic> j) {
    return SignerConfig(
      signerId: (j['signerId'] as String?) ?? '',
      policyIds:
          (j['policyIds'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}

/// Client for the always-on copy engine backend (dream-server).
///
/// Reuses the exact wallet-signature auth scheme as [AiProxyService]:
/// the message `dream-ai:<address>:<timestamp>` is signed with the active
/// wallet and sent as `X-Wallet-*` headers, matching the server's
/// `wallet-auth` middleware.
class CopyEngineService {
  final LoggerService _logger;
  final PrivyWalletManager _privyWallet;
  final MwaWalletService _mwaService;
  final PhoenixAuthService _phoenixAuthService;
  late final Dio _dio;

  CopyEngineService({
    required LoggerService logger,
    required PrivyWalletManager privyWallet,
    required MwaWalletService mwaService,
    required PhoenixAuthService phoenixAuthService,
  }) : _logger = logger,
       _privyWallet = privyWallet,
       _mwaService = mwaService,
       _phoenixAuthService = phoenixAuthService {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.dreamServerUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  /// Lists the server-side subscriptions for [walletAddress].
  Future<List<CopySubscriptionRecord>> fetchSubscriptions(
    String walletAddress,
  ) async {
    final headers = await _buildAuthHeaders(walletAddress);
    final resp = await _dio.get(
      '/v1/copy/subscriptions',
      options: Options(headers: headers),
    );
    final list = (resp.data?['subscriptions'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CopySubscriptionRecord.fromJson)
        .toList();
  }

  /// Fetches the signer the client must attach on-device before enabling
  /// always-on mirroring.
  Future<SignerConfig> fetchSignerConfig(String walletAddress) async {
    final headers = await _buildAuthHeaders(walletAddress);
    final resp = await _dio.get(
      '/v1/copy/signer-config',
      options: Options(headers: headers),
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) return SignerConfig.fromJson(data);
    return const SignerConfig(signerId: '', policyIds: []);
  }

  /// Fetches the follower's GLOBAL copy-points balance (Postgres source of
  /// truth). Opens consume one point across all leaders; closes are free.
  Future<int> fetchPoints(String walletAddress) async {
    final headers = await _buildAuthHeaders(walletAddress);
    final resp = await _dio.get(
      '/v1/copy/points',
      options: Options(headers: headers),
    );
    return (resp.data?['points'] as num?)?.toInt() ?? 0;
  }

  /// Credits copy-points from a confirmed on-chain SOL payment. The server
  /// re-verifies the payment and decides how many points to grant — we only
  /// pass the [txSignature]. Returns the new global balance. Idempotent on the
  /// server, so retrying the same signature is safe.
  Future<int> creditPurchase({
    required String walletAddress,
    required String txSignature,
  }) async {
    final headers = await _buildAuthHeaders(walletAddress);
    final resp = await _dio.post(
      '/v1/copy/points/credit',
      options: Options(headers: headers),
      data: {'txSignature': txSignature},
    );
    _logger.info('Credited copy points from $txSignature', tag: '[CopyEngine]');
    return (resp.data?['points'] as num?)?.toInt() ?? 0;
  }

  /// Registers the embedded wallet as a server signer. [privyWalletId] is the
  /// Privy wallet ID (`EmbeddedWallet.id`) the server uses to sign mirrors.
  /// Returns the follower's current global points balance (the server grants a
  /// one-time free allotment on first registration).
  Future<int> registerSigner({
    required String walletAddress,
    required String privyWalletId,
  }) async {
    final headers = await _buildAuthHeaders(walletAddress);
    final resp = await _dio.post(
      '/v1/copy/register-signer',
      options: Options(headers: headers),
      data: {'privyWalletId': privyWalletId},
    );
    _logger.info('Registered server signer', tag: '[CopyEngine]');
    return (resp.data?['points'] as num?)?.toInt() ?? 0;
  }

  /// Enables (or updates) always-on mirroring of [leaderWallet].
  Future<void> enable({
    required String walletAddress,
    required String leaderWallet,
    required CopySettings settings,
    String? privyWalletId,
  }) async {
    final headers = await _buildAuthHeaders(walletAddress);
    await _dio.post(
      '/v1/copy/enable',
      options: Options(headers: headers),
      data: {
        'leaderWallet': leaderWallet,
        'privyWalletId': ?privyWalletId,
        'settings': settings.toJson(),
      },
    );
    _logger.info('Enabled server copy of $leaderWallet', tag: '[CopyEngine]');
  }

  /// Pauses server-side mirroring of [leaderWallet].
  Future<void> disable({
    required String walletAddress,
    required String leaderWallet,
  }) async {
    final headers = await _buildAuthHeaders(walletAddress);
    await _dio.post(
      '/v1/copy/disable',
      options: Options(headers: headers),
      data: {'leaderWallet': leaderWallet},
    );
    _logger.info('Disabled server copy of $leaderWallet', tag: '[CopyEngine]');
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  Future<Map<String, String>> _buildAuthHeaders(String walletAddress) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final message = 'dream-ai:$walletAddress:$timestamp';

    String signature;
    try {
      final isMwa =
          _phoenixAuthService.persistedWalletType == 'mwa' &&
          _mwaService.connectedPublicKey == walletAddress;

      if (isMwa) {
        final msgBytes = Uint8List.fromList(utf8.encode(message));
        final result = await _mwaService.signMessage(base64Encode(msgBytes));
        signature = result.success && result.signature != null
            ? base64Encode(result.signature!)
            : '';
      } else {
        final wallet = await _privyWallet.getOrCreateWallet();
        if (wallet == null) throw Exception('No wallet available');
        signature = await _privyWallet.signMessage(wallet, message) ?? '';
      }
    } catch (e) {
      _logger.error('Failed to sign copy-engine auth: $e', tag: '[CopyEngine]');
      signature = '';
    }

    return {
      'X-Wallet-Address': walletAddress,
      'X-Wallet-Signature': signature,
      'X-Timestamp': timestamp,
    };
  }
}
