import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logger_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(logger: ref.watch(loggerServiceProvider));
});

/// Centralised local notification helper.
///
/// Channels (Android):
///   - `dream_fills`   — order fills, TP/SL triggers (HIGH importance)
///   - `dream_alerts`  — user-set price alerts (HIGH importance)
///   - `dream_risk`    — liquidation / margin warnings (MAX importance)
///   - `dream_status`  — connectivity / system (DEFAULT importance)
class NotificationService {
  final LoggerService _logger;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Emits the symbol payload when the user taps a price-alert notification.
  final StreamController<String> _tapController =
      StreamController<String>.broadcast();

  /// Stream of market symbols (e.g. `"SOL-PERP"`) that the user tapped
  /// from a price-alert notification. Listen in the app shell to navigate.
  Stream<String> get alertTapSymbol => _tapController.stream;

  // ── Android channel constants ───────────────────────────────────────────
  static const _fillChannelId = 'dream_fills';
  static const _fillChannelName = 'Order Fills';
  static const _fillChannelDesc = 'Notifies when TP, SL or limit orders fill.';

  static const _alertChannelId = 'dream_alerts';
  static const _alertChannelName = 'Price Alerts';
  static const _alertChannelDesc =
      'Notifies when a watched price level is hit.';

  static const _riskChannelId = 'dream_risk';
  static const _riskChannelName = 'Liquidation Risk';
  static const _riskChannelDesc =
      'Critical warnings when a position is close to liquidation.';

  // Notification IDs — use time-based to avoid collision when showing many
  static int _nextId() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 & 0x7FFFFFFF;

  NotificationService({required LoggerService logger}) : _logger = logger;

  // ── Initialisation ──────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // We request at runtime
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _tapController.add(payload);
        }
      },
    );

    _initialized = true;
    _logger.info('NotificationService initialised', tag: 'Notifications');
  }

  /// Request OS-level notification permission (Android 13+, iOS).
  /// Should be called from a user gesture, not at startup.
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  // ── Show helpers ────────────────────────────────────────────────────────

  /// Notify that an order was filled (TP, SL, or limit).
  Future<void> showFillNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _fillChannelId,
          _fillChannelName,
          channelDescription: _fillChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _plugin.show(_nextId(), title, body, details);
    } catch (e) {
      _logger.error(
        'showFillNotification failed',
        error: e,
        tag: 'Notifications',
      );
    }
  }

  /// Notify that a user-set price alert was triggered.
  Future<void> showPriceAlertNotification({
    required String symbol,
    required double price,
    required String direction, // 'above' | 'below'
  }) async {
    if (!_initialized) return;
    try {
      final formattedPrice = price >= 1000
          ? '\$${price.toStringAsFixed(0)}'
          : '\$${price.toStringAsFixed(2)}';
      final dirLabel = direction == 'above' ? 'crossed above' : 'crossed below';
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannelId,
          _alertChannelName,
          channelDescription: _alertChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      );
      await _plugin.show(
        _nextId(),
        '⚡ $symbol Alert',
        '$symbol $dirLabel $formattedPrice',
        details,
        payload: symbol,
      );
    } catch (e) {
      _logger.error(
        'showPriceAlertNotification failed',
        error: e,
        tag: 'Notifications',
      );
    }
  }

  /// Warn the user that a position is dangerously close to liquidation.
  ///
  /// [symbol]        — e.g. "SOL-PERP"
  /// [side]          — "long" or "short"
  /// [distancePct]   — percentage distance from mark to liq price (0–100)
  Future<void> showLiquidationWarning({
    required String symbol,
    required String side,
    required double distancePct,
  }) async {
    if (!_initialized) return;
    try {
      final base = symbol.replaceAll('-PERP', '');
      final sideLabel = side == 'long' ? 'Long' : 'Short';
      final pctStr = distancePct.toStringAsFixed(1);
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _riskChannelId,
          _riskChannelName,
          channelDescription: _riskChannelDesc,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _plugin.show(
        _nextId(),
        '⚠️ $base $sideLabel — Liquidation Risk',
        'Only $pctStr% from liquidation. Add margin or close now.',
        details,
        payload: symbol,
      );
    } catch (e) {
      _logger.error(
        'showLiquidationWarning failed',
        error: e,
        tag: 'Notifications',
      );
    }
  }

  // ── Utility ─────────────────────────────────────────────────────────────

  Future<bool> get areNotificationsEnabled async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    return true; // Assume enabled on iOS if we got here
  }

  void dispose() {
    _tapController.close();
  }
}
