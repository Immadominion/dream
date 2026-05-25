import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ui_preferences_service.dart';

// ---------------------------------------------------------------------------
// UiPreferencesState — immutable snapshot of all persisted UI preferences.
// ---------------------------------------------------------------------------

class UiPreferencesState {
  final bool enabled;
  final bool tradeChartVisible;
  final String tradeSide; // 'buy' | 'sell'
  final bool marketsWatchlistOnly;

  const UiPreferencesState({
    required this.enabled,
    required this.tradeChartVisible,
    required this.tradeSide,
    required this.marketsWatchlistOnly,
  });

  UiPreferencesState copyWith({
    bool? enabled,
    bool? tradeChartVisible,
    String? tradeSide,
    bool? marketsWatchlistOnly,
  }) => UiPreferencesState(
    enabled: enabled ?? this.enabled,
    tradeChartVisible: tradeChartVisible ?? this.tradeChartVisible,
    tradeSide: tradeSide ?? this.tradeSide,
    marketsWatchlistOnly: marketsWatchlistOnly ?? this.marketsWatchlistOnly,
  );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class UiPreferencesNotifier extends Notifier<UiPreferencesState> {
  @override
  UiPreferencesState build() {
    return UiPreferencesState(
      enabled: UiPreferencesService.enabled,
      tradeChartVisible: UiPreferencesService.getTradeChartVisible(),
      tradeSide: UiPreferencesService.getTradeSide(),
      marketsWatchlistOnly: UiPreferencesService.getMarketsWatchlistOnly(),
    );
  }

  // ── Master toggle ─────────────────────────────────────────────────────────
  Future<void> setEnabled(bool v) async {
    await UiPreferencesService.setEnabled(v);
    if (!v) {
      // Reset all stored prefs so re-enabling starts fresh
      await UiPreferencesService.clearAll();
      await UiPreferencesService.setEnabled(false); // clearAll resets to true
    }
    state = state.copyWith(enabled: v);
  }

  // ── Trade chart ───────────────────────────────────────────────────────────
  void setTradeChartVisible(bool v) {
    if (!state.enabled) return;
    UiPreferencesService.saveTradeChartVisible(v);
    state = state.copyWith(tradeChartVisible: v);
  }

  // ── Trade side ────────────────────────────────────────────────────────────
  void setTradeSide(String side) {
    if (!state.enabled) return;
    UiPreferencesService.saveTradeSide(side);
    state = state.copyWith(tradeSide: side);
  }

  // ── Markets watchlist ──────────────────────────────────────────────────────
  void setMarketsWatchlistOnly(bool v) {
    if (!state.enabled) return;
    UiPreferencesService.saveMarketsWatchlistOnly(v);
    state = state.copyWith(marketsWatchlistOnly: v);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final uiPreferencesProvider =
    NotifierProvider<UiPreferencesNotifier, UiPreferencesState>(
  UiPreferencesNotifier.new,
);
