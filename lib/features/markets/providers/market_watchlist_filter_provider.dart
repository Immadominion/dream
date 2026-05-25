import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings/ui_preferences_provider.dart';
import '../../../core/services/ui_preferences_service.dart';

// ---------------------------------------------------------------------------
// Shared watchlist-only filter state so the shell top bar can toggle it.
// Initializes from persisted UI preference (if memory is enabled).
// ---------------------------------------------------------------------------

class _WatchlistFilterNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Load persisted value synchronously (SharedPreferences already loaded)
    return UiPreferencesService.getMarketsWatchlistOnly();
  }

  void toggle() {
    state = !state;
    // Persist via the shared preferences notifier
    ref.read(uiPreferencesProvider.notifier).setMarketsWatchlistOnly(state);
  }

  void setValue(bool v) {
    state = v;
    ref.read(uiPreferencesProvider.notifier).setMarketsWatchlistOnly(v);
  }
}

final marketWatchlistOnlyProvider =
    NotifierProvider<_WatchlistFilterNotifier, bool>(
      _WatchlistFilterNotifier.new,
    );
