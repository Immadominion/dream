import '../../shared/services/storage_service.dart';

// ---------------------------------------------------------------------------
// UiPreferencesService — persists lightweight UI-state preferences.
//
// All reads are synchronous (SharedPreferences is already loaded).
// All writes are fire-and-forget async (no UI blocking needed).
//
// Keys are namespaced under 'ui_pref_' to avoid collisions.
// ---------------------------------------------------------------------------

class UiPreferencesService {
  // ── Storage keys ─────────────────────────────────────────────────────────
  static const _keyEnabled = 'ui_pref_enabled';
  static const _keyTradeChartVisible = 'ui_pref_trade_chart_visible';
  static const _keyTradeSide = 'ui_pref_trade_side'; // 'buy' | 'sell'
  static const _keyMarketsWatchlistOnly = 'ui_pref_markets_watchlist_only';

  // ── Master switch ─────────────────────────────────────────────────────────
  /// Whether UI memory is active. Default: true.
  static bool get enabled =>
      StorageService.getBool(_keyEnabled, defaultValue: true);
  static Future<void> setEnabled(bool v) =>
      StorageService.setBool(_keyEnabled, v);

  // ── Trade chart visibility ────────────────────────────────────────────────
  /// Returns true (chart visible) by default — first-time users see the chart.
  static bool getTradeChartVisible() =>
      StorageService.getBool(_keyTradeChartVisible, defaultValue: true);

  static Future<void> saveTradeChartVisible(bool v) =>
      StorageService.setBool(_keyTradeChartVisible, v);

  // ── Trade side (buy / sell) ───────────────────────────────────────────────
  /// Returns the last-used trade side, or 'buy' as the default.
  static String getTradeSide() =>
      StorageService.getString(_keyTradeSide, defaultValue: 'buy');

  static Future<void> saveTradeSide(String side) =>
      StorageService.setString(_keyTradeSide, side);

  // ── Markets watchlist-only filter ─────────────────────────────────────────
  static bool getMarketsWatchlistOnly() =>
      StorageService.getBool(_keyMarketsWatchlistOnly, defaultValue: false);

  static Future<void> saveMarketsWatchlistOnly(bool v) =>
      StorageService.setBool(_keyMarketsWatchlistOnly, v);

  // ── Clear all UI preferences ──────────────────────────────────────────────
  static Future<void> clearAll() async {
    await StorageService.setBool(_keyEnabled, true);
    await StorageService.setBool(_keyTradeChartVisible, true);
    await StorageService.setString(_keyTradeSide, 'buy');
    await StorageService.setBool(_keyMarketsWatchlistOnly, false);
  }
}
