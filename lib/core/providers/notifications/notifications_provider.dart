import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_notification.dart';
import '../../services/logger_service.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

/// Convenience: count of unread notifications.
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.isRead).length;
});

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  static const _storageKey = 'dream_notifications_v1';
  static const _maxStored = 100; // cap to avoid unbounded growth

  final _logger = LoggerService();

  @override
  List<AppNotification> build() {
    _loadFromStorage();
    return [];
  }

  // ── Read / load ──────────────────────────────────────────────────────────

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) {
        // No stored data yet — start empty; welcome fires on first sign-in
        return;
      }
      final list = (json.decode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList();
      state = list;
    } catch (e) {
      _logger.error('Failed to load notifications: $e', tag: '[Notifications]');
    }
  }

  /// Call once after the user signs in for the first time.
  /// Adds welcome notifications and sets a persisted flag so they never repeat.
  Future<void> onFirstSignIn() async {
    final prefs = await SharedPreferences.getInstance();
    const welcomedKey = 'dream_welcomed_v1';
    if (prefs.getBool(welcomedKey) == true) return;

    final now = DateTime.now();
    add(
      AppNotification(
        id: 'welcome_2',
        category: AppNotifCategory.system,
        title: 'Powered by Phoenix Trade',
        body:
            'All orders route through Phoenix. The fastest on-chain perps DEX on Solana. '
            'Zero custody, full transparency.',
        timestamp: now.subtract(const Duration(seconds: 1)),
      ),
    );
    add(
      AppNotification(
        id: 'welcome_1',
        category: AppNotifCategory.marketing,
        title: 'Welcome to Dream 👋',
        body:
            'Trade perpetual futures on Solana with institutional-grade tools. '
            'Tap any market to open your first position.',
        timestamp: now,
      ),
    );

    await prefs.setBool(welcomedKey, true);
    _logger.info('Welcome notifications sent', tag: '[Notifications]');
  }

  // ── Write helpers ────────────────────────────────────────────────────────

  /// Add a new notification to the top of the feed.
  void add(AppNotification notification) {
    state = [notification, ...state];
    if (state.length > _maxStored) {
      state = state.sublist(0, _maxStored);
    }
    _persist();
    _logger.info(
      'Notification added: ${notification.title}',
      tag: '[Notifications]',
    );
  }

  /// Convenience helper — build and add in one call.
  void push({
    required AppNotifCategory category,
    required String title,
    required String body,
    String? payload,
    String? id,
  }) {
    add(
      AppNotification(
        id: id ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
        category: category,
        title: title,
        body: body,
        timestamp: DateTime.now(),
        payload: payload,
      ),
    );
  }

  /// Mark a single notification as read.
  void markRead(String id) {
    state = state
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    _persist();
  }

  /// Mark all notifications as read.
  void markAllRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    _persist();
  }

  /// Delete a single notification.
  void remove(String id) {
    state = state.where((n) => n.id != id).toList();
    _persist();
  }

  /// Clear all notifications.
  void clearAll() {
    state = [];
    _persist();
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(state.map((n) => n.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      _logger.error(
        'Failed to persist notifications: $e',
        tag: '[Notifications]',
      );
    }
  }
}
