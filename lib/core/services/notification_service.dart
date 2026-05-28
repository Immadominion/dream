import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_notification.dart';
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

  // Emits every notification that gets shown, so the in-app feed can store it.
  final StreamController<AppNotification> _inAppController =
      StreamController<AppNotification>.broadcast();

  /// Stream of all displayed notifications — subscribe in the shell to
  /// persist them in [NotificationsProvider].
  Stream<AppNotification> get notificationFeed => _inAppController.stream;

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

  static const _statusChannelId = 'dream_status';
  static const _statusChannelName = 'Account Activity';
  static const _statusChannelDesc =
      'Notifies when wallet or collateral balances change.';

  // Notification IDs — use time-based to avoid collision when showing many
  static int _nextId() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 & 0x7FFFFFFF;

  NotificationService({required LoggerService logger}) : _logger = logger;

  // ── Initialisation ──────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@drawable/ic_notification');
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
          icon: '@drawable/ic_notification',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _plugin.show(_nextId(), title, body, details);
      _inAppController.add(
        AppNotification(
          id: 'fill_${DateTime.now().millisecondsSinceEpoch}',
          category: AppNotifCategory.trade,
          title: title,
          body: body,
          timestamp: DateTime.now(),
        ),
      );
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
          icon: '@drawable/ic_notification',
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
      _inAppController.add(
        AppNotification(
          id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
          category: AppNotifCategory.alert,
          title: '⚡ $symbol Alert',
          body: '$symbol $dirLabel $formattedPrice',
          timestamp: DateTime.now(),
          payload: symbol,
        ),
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
          icon: '@drawable/ic_notification',
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
      _inAppController.add(
        AppNotification(
          id: 'risk_${DateTime.now().millisecondsSinceEpoch}',
          category: AppNotifCategory.risk,
          title: '⚠️ $base $sideLabel — Liquidation Risk',
          body: 'Only $pctStr% from liquidation. Add margin or close now.',
          timestamp: DateTime.now(),
          payload: symbol,
        ),
      );
    } catch (e) {
      _logger.error(
        'showLiquidationWarning failed',
        error: e,
        tag: 'Notifications',
      );
    }
  }

  Future<void> showWalletDepositNotification({
    required double amountUsdc,
  }) async {
    if (!_initialized) return;
    try {
      final amount = amountUsdc.toStringAsFixed(2);
      final title = 'USDC received';
      final body =
          '$amount USDC arrived in your Dream wallet. Deposit it to Phoenix collateral to trade.';
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _statusChannelId,
          _statusChannelName,
          channelDescription: _statusChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      );
      await _plugin.show(_nextId(), title, body, details);
      _inAppController.add(
        AppNotification(
          id: 'wallet_deposit_${DateTime.now().millisecondsSinceEpoch}',
          category: AppNotifCategory.system,
          title: title,
          body: body,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _logger.error(
        'showWalletDepositNotification failed',
        error: e,
        tag: 'Notifications',
      );
    }
  }

  Future<void> showPhoenixCollateralDepositNotification({
    required double amountUsdc,
  }) async {
    if (!_initialized) return;
    try {
      final amount = amountUsdc.toStringAsFixed(2);
      final title = 'Phoenix collateral funded';
      final body = '$amount USDC is now being deposited to Phoenix collateral.';
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _statusChannelId,
          _statusChannelName,
          channelDescription: _statusChannelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_notification',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      );
      await _plugin.show(_nextId(), title, body, details);
      _inAppController.add(
        AppNotification(
          id: 'collateral_deposit_${DateTime.now().millisecondsSinceEpoch}',
          category: AppNotifCategory.system,
          title: title,
          body: body,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _logger.error(
        'showPhoenixCollateralDepositNotification failed',
        error: e,
        tag: 'Notifications',
      );
    }
  }

  Future<void> showGenericNotification({
    required AppNotifCategory category,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdFor(category),
          _channelNameFor(category),
          channelDescription: _channelDescriptionFor(category),
          importance: _androidImportanceFor(category),
          priority: _androidPriorityFor(category),
          icon: '@drawable/ic_notification',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: category != AppNotifCategory.marketing,
          presentSound: category != AppNotifCategory.system,
        ),
      );

      await _plugin.show(_nextId(), title, body, details, payload: payload);
      _inAppController.add(
        AppNotification(
          id: 'generic_${DateTime.now().millisecondsSinceEpoch}',
          category: category,
          title: title,
          body: body,
          timestamp: DateTime.now(),
          payload: payload,
        ),
      );
    } catch (e) {
      _logger.error(
        'showGenericNotification failed',
        error: e,
        tag: 'Notifications',
      );
    }
  }

  // ── Utility ─────────────────────────────────────────────────────────────

  String _channelIdFor(AppNotifCategory category) => switch (category) {
    AppNotifCategory.trade => _fillChannelId,
    AppNotifCategory.alert => _alertChannelId,
    AppNotifCategory.risk => _riskChannelId,
    AppNotifCategory.system ||
    AppNotifCategory.marketing ||
    AppNotifCategory.intelligence => _statusChannelId,
  };

  String _channelNameFor(AppNotifCategory category) => switch (category) {
    AppNotifCategory.trade => _fillChannelName,
    AppNotifCategory.alert => _alertChannelName,
    AppNotifCategory.risk => _riskChannelName,
    AppNotifCategory.system ||
    AppNotifCategory.marketing ||
    AppNotifCategory.intelligence => _statusChannelName,
  };

  String _channelDescriptionFor(AppNotifCategory category) =>
      switch (category) {
        AppNotifCategory.trade => _fillChannelDesc,
        AppNotifCategory.alert => _alertChannelDesc,
        AppNotifCategory.risk => _riskChannelDesc,
        AppNotifCategory.system ||
        AppNotifCategory.marketing ||
        AppNotifCategory.intelligence => _statusChannelDesc,
      };

  Importance _androidImportanceFor(AppNotifCategory category) =>
      switch (category) {
        AppNotifCategory.trade || AppNotifCategory.alert => Importance.high,
        AppNotifCategory.risk => Importance.max,
        AppNotifCategory.system ||
        AppNotifCategory.marketing ||
        AppNotifCategory.intelligence => Importance.defaultImportance,
      };

  Priority _androidPriorityFor(AppNotifCategory category) =>
      switch (category) {
        AppNotifCategory.trade || AppNotifCategory.alert => Priority.high,
        AppNotifCategory.risk => Priority.max,
        AppNotifCategory.system ||
        AppNotifCategory.marketing ||
        AppNotifCategory.intelligence => Priority.defaultPriority,
      };

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
    _inAppController.close();
  }
}
