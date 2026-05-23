import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/logger_service.dart';
import '../../../shared/services/storage_service.dart';

const _kWatchlistKey = 'markets_watchlist_v1';

// ---------------------------------------------------------------------------
// Watchlist Notifier — persists starred market symbols to local storage
// ---------------------------------------------------------------------------

class WatchlistNotifier extends Notifier<Set<String>> {
  final _logger = LoggerService();

  @override
  Set<String> build() {
    final raw = StorageService.getString(_kWatchlistKey, defaultValue: '');
    if (raw.isEmpty) return {};
    final symbols = raw.split(',').where((s) => s.isNotEmpty).toSet();
    _logger.info('[Markets] Loaded watchlist: ${symbols.length} symbols');
    return symbols;
  }

  /// Toggle a symbol's starred status.
  void toggle(String symbol) {
    final next = Set<String>.from(state);
    if (next.contains(symbol)) {
      next.remove(symbol);
      _logger.info('[Markets] Removed $symbol from watchlist');
    } else {
      next.add(symbol);
      _logger.info('[Markets] Added $symbol to watchlist');
    }
    state = next;
    _persist();
  }

  bool isWatched(String symbol) => state.contains(symbol);

  Future<void> _persist() async {
    await StorageService.setString(_kWatchlistKey, state.join(','));
  }
}

final watchlistProvider = NotifierProvider<WatchlistNotifier, Set<String>>(
  WatchlistNotifier.new,
);
