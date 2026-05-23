import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/services/phoenix/phoenix_websocket_service.dart';
import '../../../shared/services/storage_service.dart';
import '../models/price_alert.dart';

export '../models/price_alert.dart';

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class PriceAlertsNotifier extends Notifier<PriceAlertsState> {
  StreamSubscription<AllMidsMessage>? _midsSub;
  int _nextSeq = 1;

  static const _kAlertsKey = 'price_alerts';

  @override
  PriceAlertsState build() {
    ref.onDispose(_dispose);
    _startMonitoring();
    return _loadAlerts();
  }

  PriceAlertsState _loadAlerts() {
    try {
      final raw = StorageService.getString(_kAlertsKey);
      if (raw.isEmpty) return const PriceAlertsState();
      final list = jsonDecode(raw) as List<dynamic>;
      final alerts = list
          .cast<Map<String, dynamic>>()
          .map(PriceAlert.fromJson)
          .toList();
      return PriceAlertsState(alerts: alerts);
    } catch (_) {
      return const PriceAlertsState();
    }
  }

  Future<void> _save(List<PriceAlert> alerts) async {
    try {
      await StorageService.setString(
        _kAlertsKey,
        jsonEncode(alerts.map((a) => a.toJson()).toList()),
      );
    } catch (_) {}
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Add a new price alert. Ignored if an identical active alert exists.
  void addAlert({
    required String symbol,
    required double targetPrice,
    required AlertDirection direction,
  }) {
    final isDuplicate = state.alerts.any(
      (a) =>
          a.symbol == symbol &&
          a.targetPrice == targetPrice &&
          a.direction == direction &&
          !a.triggered,
    );
    if (isDuplicate) return;

    final alert = PriceAlert(
      id: '${symbol}_${targetPrice}_${direction.name}_${_nextSeq++}',
      symbol: symbol,
      targetPrice: targetPrice,
      direction: direction,
    );
    final updated = [...state.alerts, alert];
    state = state.copyWith(alerts: updated);
    _save(updated);
  }

  /// Remove an alert by ID (active or triggered).
  void removeAlert(String id) {
    final updated = state.alerts.where((a) => a.id != id).toList();
    state = state.copyWith(alerts: updated);
    _save(updated);
  }

  /// Clear all triggered alerts.
  void clearTriggered() {
    final updated = state.alerts.where((a) => !a.triggered).toList();
    state = state.copyWith(alerts: updated);
    _save(updated);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _startMonitoring() {
    final ws = ref.read(phoenixWebSocketServiceProvider);
    _midsSub = ws.allMidsStream.listen(_onMidsUpdate);
  }

  void _onMidsUpdate(AllMidsMessage msg) {
    final active = state.activeAll;
    if (active.isEmpty) return;

    final triggered = <String>[];

    for (final alert in active) {
      final currentPrice = msg.mids[alert.symbol];
      if (currentPrice == null) continue;

      final shouldFire = alert.direction == AlertDirection.above
          ? currentPrice >= alert.targetPrice
          : currentPrice <= alert.targetPrice;

      if (shouldFire) {
        triggered.add(alert.id);
        _fireNotification(alert);
      }
    }

    if (triggered.isEmpty) return;

    final updated = state.alerts
        .map((a) => triggered.contains(a.id) ? a.copyWith(triggered: true) : a)
        .toList();
    state = state.copyWith(alerts: updated);
    _save(updated);
  }

  void _fireNotification(PriceAlert alert) {
    ref
        .read(notificationServiceProvider)
        .showPriceAlertNotification(
          symbol: alert.symbol.replaceAll('-PERP', ''),
          price: alert.targetPrice,
          direction: alert.direction == AlertDirection.above
              ? 'above'
              : 'below',
        );
  }

  void _dispose() => _midsSub?.cancel();
}

final priceAlertsProvider =
    NotifierProvider<PriceAlertsNotifier, PriceAlertsState>(
      PriceAlertsNotifier.new,
    );
