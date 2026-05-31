import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../logger_service.dart';
import '../../../shared/services/storage_service.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final telegramAnalyticsProvider = Provider<TelegramAnalyticsService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  final service = TelegramAnalyticsService(logger: logger);
  service.init();
  return service;
});

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Sends real-time analytics events to the developer's Telegram chat — for
/// EVERY user, in every build (debug + release).
///
/// Security model (mirrors [AiProxyService]):
///   - The Telegram bot token + chat id live ONLY in the Cloudflare Worker as
///     encrypted secrets. They are never bundled in the app.
///   - The app POSTs a structured event to the Worker, which formats the
///     message server-side and forwards it to Telegram.
///   - This removes the leakable bot-token-in-APK vulnerability while keeping
///     analytics working for all users.
///
/// Push events (fired automatically):
///   - New user signup (once per wallet address per device)
///   - Trade opened (every successful order)
///   - Position closed
///   - Collateral deposit
///
/// Slash commands (/stats, /fees, /ping, /help) are handled server-side by the
/// Worker's Telegram webhook — see workers/dream-ai-worker.ts. They are
/// intentionally NOT polled on-device: Telegram allows only one getUpdates
/// consumer, so per-device polling would conflict across users.
class TelegramAnalyticsService {
  final LoggerService _logger;

  late final Dio _dio;
  bool _enabled = false;

  // Storage key prefix: tracks which wallets have already been reported as new.
  static const _kReportedPrefix = 'tg_reported_';

  TelegramAnalyticsService({required LoggerService logger}) : _logger = logger {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.dreamServerUrl,
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 6),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  void init() {
    _enabled = AppConstants.dreamServerUrl.isNotEmpty;
    if (!_enabled) {
      _logger.info(
        'TelegramAnalytics: worker URL not set — analytics disabled',
        tag: 'Analytics',
      );
      return;
    }
    _logger.info('TelegramAnalytics: initialized', tag: 'Analytics');
  }

  // ── Push events ─────────────────────────────────────────────────────────

  /// Call when a user first authenticates with Phoenix.
  /// Fires only once per wallet address per device install.
  Future<void> trackNewUser(String walletAddress) async {
    if (!_enabled) return;

    final key = '$_kReportedPrefix$walletAddress';
    if (StorageService.getString(key) == 'true') return;
    await StorageService.setString(key, 'true');

    await _sendEvent('new_user', walletAddress, {'wallet': walletAddress});
  }

  /// Call after a successful order submission.
  Future<void> trackOrderPlaced({
    required String symbol,
    required String side, // 'buy' | 'sell'
    required String orderType, // 'market' | 'limit'
    required double sizeUsdc,
    required double leverage,
    required double notionalUsdc,
    required double entryPrice,
    required String txSignature,
    String walletAddress = '',
  }) async {
    if (!_enabled) return;

    await _sendEvent('order_opened', walletAddress, {
      'symbol': symbol,
      'side': side,
      'orderType': orderType,
      'sizeUsdc': sizeUsdc,
      'leverage': leverage,
      'notionalUsdc': notionalUsdc,
      'entryPrice': entryPrice,
      'txSignature': txSignature,
    });
  }

  /// Call when a position is closed.
  Future<void> trackPositionClosed({
    required String symbol,
    required String side, // 'buy' | 'sell'
    String walletAddress = '',
    double? pnlUsdc,
  }) async {
    if (!_enabled) return;

    await _sendEvent('position_closed', walletAddress, {
      'symbol': symbol,
      'side': side,
      ...?((pnlUsdc == null) ? null : {'pnlUsdc': pnlUsdc}),
    });
  }

  /// Call after a successful collateral deposit.
  Future<void> trackCollateralDeposit(
    String walletAddress,
    double amountUsdc,
  ) async {
    if (!_enabled) return;

    await _sendEvent('collateral_deposit', walletAddress, {
      'wallet': walletAddress,
      'amountUsdc': amountUsdc,
    });
  }

  // ── Core send ───────────────────────────────────────────────────────────

  /// POSTs a structured event to the Worker, which formats + forwards it to
  /// Telegram. Fire-and-forget: analytics must never block or break a user flow.
  Future<void> _sendEvent(
    String type,
    String wallet,
    Map<String, dynamic> data,
  ) async {
    if (!_enabled) return;
    try {
      await _dio.post(
        '/v1/analytics/event',
        data: {'type': type, 'wallet': wallet, 'data': data},
      );
    } catch (e) {
      _logger.error(
        'TelegramAnalytics: event "$type" failed',
        error: e,
        tag: 'Analytics',
      );
    }
  }
}
