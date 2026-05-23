import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/phoenix/phoenix_models.dart';
import '../../../core/services/phoenix/phoenix_market_service.dart';
import '../../../core/services/phoenix/phoenix_websocket_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class MarketsState {
  final List<PhoenixMarket> markets;
  final Map<String, double> mids; // symbol → live mark price
  final Map<String, PhoenixMarketSnapshot> snapshots;
  final bool isLoading;
  final String? error;

  const MarketsState({
    this.markets = const [],
    this.mids = const {},
    this.snapshots = const {},
    this.isLoading = false,
    this.error,
  });

  MarketsState copyWith({
    List<PhoenixMarket>? markets,
    Map<String, double>? mids,
    Map<String, PhoenixMarketSnapshot>? snapshots,
    bool? isLoading,
    String? error,
  }) => MarketsState(
    markets: markets ?? this.markets,
    mids: mids ?? this.mids,
    snapshots: snapshots ?? this.snapshots,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );

  /// Return the best available price for [symbol]: WS snapshot → allMids → 0
  double priceFor(String symbol) {
    if (snapshots.containsKey(symbol)) return snapshots[symbol]!.markPrice;
    return mids[symbol] ?? 0;
  }

  /// Return 24h change % for [symbol] from last WS snapshot
  double changeFor(String symbol) => snapshots[symbol]?.change24hPercent ?? 0;

  /// Return funding rate for [symbol] from last WS snapshot
  double fundingFor(String symbol) => snapshots[symbol]?.fundingRate ?? 0;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class MarketsNotifier extends Notifier<MarketsState> {
  StreamSubscription<AllMidsMessage>? _midsSub;
  StreamSubscription<MarketSnapshotMessage>? _snapshotSub;

  @override
  MarketsState build() {
    ref.onDispose(_dispose);
    // Kick off initialization once the ref is valid
    Future.microtask(_init);
    return const MarketsState(isLoading: true);
  }

  Future<void> _init() async {
    await _fetchMarkets();
    _startWebSocket();
  }

  Future<void> _fetchMarkets() async {
    try {
      final markets = await ref
          .read(phoenixMarketServiceProvider)
          .fetchMarkets();
      state = state.copyWith(markets: markets, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load markets: $e',
      );
    }
  }

  void _startWebSocket() {
    final ws = ref.read(phoenixWebSocketServiceProvider);

    // All-mids stream → update live prices (only when values actually changed)
    _midsSub = ws.allMidsStream.listen((msg) {
      var hasChange = false;
      for (final entry in msg.mids.entries) {
        if (state.mids[entry.key] != entry.value) {
          hasChange = true;
          break;
        }
      }
      if (!hasChange) return;
      final updated = Map<String, double>.from(state.mids)..addAll(msg.mids);
      state = state.copyWith(mids: updated);
    });

    // Per-market snapshots → richer data (OI, funding, 24h change)
    // Skip update if this exact snapshot is already stored (same object identity)
    _snapshotSub = ws.marketStream.listen((msg) {
      final snap = msg.snapshot;
      if (snap.symbol.isEmpty) return;
      final existing = state.snapshots[snap.symbol];
      if (existing != null &&
          existing.fundingRate == snap.fundingRate &&
          existing.change24hPercent == snap.change24hPercent &&
          existing.volume24hUsd == snap.volume24hUsd) {
        return;
      }
      final updated = Map<String, PhoenixMarketSnapshot>.from(state.snapshots)
        ..[snap.symbol] = snap;
      state = state.copyWith(snapshots: updated);
    });

    // Connect and subscribe to allMids (done inside service on connect)
    ws.connect();

    // Subscribe to each market's detailed channel
    for (final m in state.markets) {
      ws.subscribeMarket(m.symbol);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _fetchMarkets();
  }

  void _dispose() {
    _midsSub?.cancel();
    _snapshotSub?.cancel();
  }
}

final marketsProvider = NotifierProvider<MarketsNotifier, MarketsState>(
  MarketsNotifier.new,
);
