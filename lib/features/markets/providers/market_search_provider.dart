import 'package:flutter_riverpod/legacy.dart';

/// Shared search query that the shell top bar writes and MarketsPage reads.
final marketSearchQueryProvider = StateProvider<String>((ref) => '');
