import 'package:flutter_riverpod/legacy.dart';

// Shared watchlist-only filter state so the shell top bar can toggle it.
final marketWatchlistOnlyProvider = StateProvider<bool>((ref) => false);
