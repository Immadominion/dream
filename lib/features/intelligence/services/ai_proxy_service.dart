import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/phoenix/phoenix_auth_service.dart';
import '../../../core/services/wallet/privy_wallet_manager.dart';
import '../../../core/services/wallet/mwa_wallet_service.dart';

final aiProxyServiceProvider = Provider<AiProxyService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  final privyWallet = ref.watch(privyWalletManagerProvider);
  final mwaService = ref.watch(mwaWalletServiceProvider);
  final phoenixAuth = ref.watch(phoenixAuthServiceProvider);
  return AiProxyService(
    logger: logger,
    privyWallet: privyWallet,
    mwaService: mwaService,
    phoenixAuthService: phoenixAuth,
  );
});

/// Calls the Dream AI Cloudflare Worker for credit management.
///
/// Security model:
///   - Flutter proves identity by signing a short-lived message with the wallet
///   - Worker validates the ed25519 signature before issuing or verifying credits
///   - No sensitive API keys ever touch the device
class AiProxyService {
  final LoggerService _logger;
  final PrivyWalletManager _privyWallet;
  final MwaWalletService _mwaService;
  final PhoenixAuthService _phoenixAuthService;
  late final Dio _dio;

  AiProxyService({
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

  // ── Credit management ────────────────────────────────────────────────────

  Future<int> fetchCredits(String walletAddress) async {
    try {
      final authHeaders = await _buildAuthHeaders(walletAddress);
      final resp = await _dio.get(
        '/v1/credits/balance',
        options: Options(headers: authHeaders),
      );
      return (resp.data?['credits'] as num?)?.toInt() ?? 0;
    } catch (e) {
      _logger.error('Failed to fetch credits: $e', tag: '[Credits]');
      rethrow;
    }
  }

  /// Called after the user sends on-chain SOL to Dream treasury.
  /// [txSignature] — confirmed Solana tx signature of the payment.
  Future<int> topUpCredits({
    required String walletAddress,
    required String txSignature,
    required int credits,
  }) async {
    try {
      final authHeaders = await _buildAuthHeaders(walletAddress);
      final resp = await _dio.post(
        '/v1/credits/topup',
        options: Options(headers: authHeaders),
        data: {'txSignature': txSignature, 'credits': credits},
      );
      return (resp.data?['added'] as num?)?.toInt() ?? credits;
    } catch (e) {
      _logger.error('Failed to top up credits: $e', tag: '[Credits]');
      rethrow;
    }
  }

  // ── Broadcaster marketplace ─────────────────────────────────────────────

  Future<void> registerBroadcaster({
    required String walletAddress,
    required String displayName,
    String? strategy,
    String? twitter,
  }) async {
    try {
      final authHeaders = await _buildAuthHeaders(walletAddress);
      await _dio.post(
        '/v1/broadcasters/register',
        options: Options(headers: authHeaders),
        data: {
          'displayName': displayName,
          'strategy': strategy,
          'twitter': twitter,
        },
      );
    } on DioException catch (e) {
      _logger.error(
        'Failed to register broadcaster: ${_describeWorkerError(e)}',
        tag: '[Broadcast]',
      );
      throw Exception(_describeWorkerError(e));
    }
  }

  Future<BroadcasterAccount?> fetchMyBroadcaster(String walletAddress) async {
    try {
      final authHeaders = await _buildAuthHeaders(walletAddress);
      final resp = await _dio.get(
        '/v1/broadcasters/me',
        options: Options(headers: authHeaders),
      );
      final data = resp.data as Map<String, dynamic>?;
      final broadcaster = data?['broadcaster'] as Map<String, dynamic>?;
      if (broadcaster == null) return null;
      return BroadcasterAccount.fromJson(broadcaster);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      if (_isTransientWorkerError(e)) {
        _logger.warning(
          'Broadcaster profile temporarily unavailable: ${_describeWorkerError(e)}',
          tag: '[Broadcast]',
        );
        return null;
      }
      _logger.error(
        'Failed to fetch broadcaster profile: ${_describeWorkerError(e)}',
        tag: '[Broadcast]',
      );
      throw Exception(_describeWorkerError(e));
    }
  }

  /// Earnings history + aggregate USD stats for the signed-in broadcaster.
  Future<BroadcasterEarnings?> fetchBroadcasterEarnings(
    String walletAddress,
  ) async {
    try {
      final authHeaders = await _buildAuthHeaders(walletAddress);
      final resp = await _dio.get(
        '/v1/broadcasters/earnings',
        options: Options(headers: authHeaders),
      );
      final data = resp.data as Map<String, dynamic>?;
      if (data == null) return null;
      return BroadcasterEarnings.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      _logger.error(
        'Failed to fetch earnings: ${_describeWorkerError(e)}',
        tag: '[Broadcast]',
      );
      throw Exception(_describeWorkerError(e));
    }
  }

  /// Requests a USDC payout of the full claimable balance. Returns the
  /// requested amount, or throws with a [PayoutException] when below minimum.
  Future<double> requestPayout(String walletAddress) async {
    try {
      final authHeaders = await _buildAuthHeaders(walletAddress);
      final resp = await _dio.post(
        '/v1/broadcasters/payout',
        options: Options(headers: authHeaders),
      );
      return (resp.data?['amountUsd'] as num?)?.toDouble() ?? 0;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final min =
            (e.response?.data?['payoutMinUsd'] as num?)?.toDouble() ?? 0;
        final claimable =
            (e.response?.data?['claimableUsd'] as num?)?.toDouble() ?? 0;
        throw PayoutException(claimableUsd: claimable, minUsd: min);
      }
      _logger.error(
        'Failed to request payout: ${_describeWorkerError(e)}',
        tag: '[Broadcast]',
      );
      throw Exception(_describeWorkerError(e));
    }
  }

  Future<void> recordCopyAttribution({
    required String walletAddress,
    required String broadcasterAddress,
    required String market,
    required String side,
    required double notionalUsdc,
    required String eventType,
  }) async {
    try {
      final authHeaders = await _buildAuthHeaders(walletAddress);
      await _dio.post(
        '/v1/broadcasters/attribution',
        options: Options(headers: authHeaders),
        data: {
          'broadcasterAddress': broadcasterAddress,
          'market': market,
          'side': side,
          'notionalUsdc': notionalUsdc,
          'eventType': eventType,
        },
      );
    } on DioException catch (e) {
      _logger.error(
        'Failed to record copy attribution: ${_describeWorkerError(e)}',
        tag: '[Broadcast]',
      );
      throw Exception(_describeWorkerError(e));
    }
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

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
      _logger.error('Failed to sign auth message: $e', tag: '[Credits]');
      signature = '';
    }

    return {
      'X-Wallet-Address': walletAddress,
      'X-Wallet-Signature': signature,
      'X-Timestamp': timestamp,
    };
  }

  bool _isTransientWorkerError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
  }

  String _describeWorkerError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is String && error.trim().isNotEmpty) return error.trim();
    }

    if (_isTransientWorkerError(e)) {
      return 'Could not reach Dream service. Check your network and try again.';
    }

    if (e.response?.statusCode != null) {
      return 'Dream service error (${e.response!.statusCode}). Please try again.';
    }

    return 'Dream service request failed. Please try again.';
  }
}

class BroadcasterAccount {
  final String address;
  final String? displayName;
  final String? strategy;
  final String? twitter;
  final int copierCount;
  final double lifetimeUsd;
  final double claimableUsd;
  final double paidOutUsd;
  final double volumeUsd;
  final int fillsCount;
  final int revenueShareBps;

  const BroadcasterAccount({
    required this.address,
    this.displayName,
    this.strategy,
    this.twitter,
    this.copierCount = 0,
    this.lifetimeUsd = 0,
    this.claimableUsd = 0,
    this.paidOutUsd = 0,
    this.volumeUsd = 0,
    this.fillsCount = 0,
    this.revenueShareBps = 3000,
  });

  factory BroadcasterAccount.fromJson(Map<String, dynamic> json) {
    return BroadcasterAccount(
      address: json['address'] as String? ?? '',
      displayName: json['displayName'] as String?,
      strategy: json['strategy'] as String?,
      twitter: json['twitter'] as String?,
      copierCount: (json['copierCount'] as num?)?.toInt() ?? 0,
      lifetimeUsd: (json['lifetimeUsd'] as num?)?.toDouble() ?? 0,
      claimableUsd: (json['claimableUsd'] as num?)?.toDouble() ?? 0,
      paidOutUsd: (json['paidOutUsd'] as num?)?.toDouble() ?? 0,
      volumeUsd: (json['volumeUsd'] as num?)?.toDouble() ?? 0,
      fillsCount: (json['fillsCount'] as num?)?.toInt() ?? 0,
      revenueShareBps: (json['revenueShareBps'] as num?)?.toInt() ?? 3000,
    );
  }
}

/// Aggregate earnings stats + event history for a broadcaster.
class BroadcasterEarnings {
  final double lifetimeUsd;
  final double claimableUsd;
  final double paidOutUsd;
  final double last7dUsd;
  final double last30dUsd;
  final int copierCount;
  final int fillsCount;
  final double volumeUsd;
  final int revenueShareBps;
  final double payoutMinUsd;
  final List<EarningEvent> history;

  const BroadcasterEarnings({
    this.lifetimeUsd = 0,
    this.claimableUsd = 0,
    this.paidOutUsd = 0,
    this.last7dUsd = 0,
    this.last30dUsd = 0,
    this.copierCount = 0,
    this.fillsCount = 0,
    this.volumeUsd = 0,
    this.revenueShareBps = 3000,
    this.payoutMinUsd = 5,
    this.history = const [],
  });

  factory BroadcasterEarnings.fromJson(Map<String, dynamic> json) {
    final stats = (json['stats'] as Map<String, dynamic>?) ?? const {};
    final rawHistory = (json['history'] as List<dynamic>?) ?? const [];
    return BroadcasterEarnings(
      lifetimeUsd: (stats['lifetimeUsd'] as num?)?.toDouble() ?? 0,
      claimableUsd: (stats['claimableUsd'] as num?)?.toDouble() ?? 0,
      paidOutUsd: (stats['paidOutUsd'] as num?)?.toDouble() ?? 0,
      last7dUsd: (stats['last7dUsd'] as num?)?.toDouble() ?? 0,
      last30dUsd: (stats['last30dUsd'] as num?)?.toDouble() ?? 0,
      copierCount: (stats['copierCount'] as num?)?.toInt() ?? 0,
      fillsCount: (stats['fillsCount'] as num?)?.toInt() ?? 0,
      volumeUsd: (stats['volumeUsd'] as num?)?.toDouble() ?? 0,
      revenueShareBps: (stats['revenueShareBps'] as num?)?.toInt() ?? 3000,
      payoutMinUsd: (stats['payoutMinUsd'] as num?)?.toDouble() ?? 5,
      history: rawHistory
          .whereType<Map<String, dynamic>>()
          .map(EarningEvent.fromJson)
          .toList(),
    );
  }
}

/// A single earnings event (a copy fill reward or a payout).
class EarningEvent {
  final DateTime timestamp;
  final String type; // 'copy' | 'payout'
  final String? copier;
  final String? market;
  final String? side;
  final double notionalUsd;
  final double earnedUsd;

  const EarningEvent({
    required this.timestamp,
    required this.type,
    this.copier,
    this.market,
    this.side,
    this.notionalUsd = 0,
    this.earnedUsd = 0,
  });

  bool get isPayout => type == 'payout';

  factory EarningEvent.fromJson(Map<String, dynamic> json) {
    return EarningEvent(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['ts'] as num?)?.toInt() ?? 0,
      ),
      type: json['type'] as String? ?? 'copy',
      copier: json['copier'] as String?,
      market: json['market'] as String?,
      side: json['side'] as String?,
      notionalUsd: (json['notionalUsd'] as num?)?.toDouble() ?? 0,
      earnedUsd: (json['earnedUsd'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Thrown when a payout request is below the minimum threshold.
class PayoutException implements Exception {
  final double claimableUsd;
  final double minUsd;
  const PayoutException({required this.claimableUsd, required this.minUsd});

  @override
  String toString() =>
      'Minimum payout is \$${minUsd.toStringAsFixed(2)} (you have \$${claimableUsd.toStringAsFixed(2)})';
}
