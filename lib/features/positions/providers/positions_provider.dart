import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/phoenix/phoenix_models.dart';
import '../../../core/providers/auth/client_auth_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/phoenix/phoenix_order_service.dart';
import '../../../core/services/phoenix/phoenix_trader_service.dart';
import '../../../core/services/phoenix/phoenix_websocket_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class PositionsState {
  final PhoenixTraderState? traderState;
  final bool isLoading;
  final String? error;

  const PositionsState({this.traderState, this.isLoading = false, this.error});

  PositionsState copyWith({
    PhoenixTraderState? traderState,
    bool? isLoading,
    String? error,
  }) => PositionsState(
    traderState: traderState ?? this.traderState,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );

  List<PhoenixPosition> get positions => traderState?.positions ?? const [];

  List<PhoenixOpenOrder> get openOrders => traderState?.openOrders ?? const [];

  /// True when the trader account hasn't been activated yet on Phoenix.
  bool get isNotRegistered =>
      !isLoading &&
      error == null &&
      traderState != null &&
      !traderState!.isRegistered;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class PositionsNotifier extends Notifier<PositionsState> {
  StreamSubscription<TraderStateMessage>? _wsSub;

  // Tracks which position symbols we've already sent a liq-risk warning for
  // (cleared whenever positions change so re-warnings can fire if risk persists).
  final Set<String> _liqWarnedSymbols = {};

  @override
  PositionsState build() {
    ref.onDispose(_dispose);

    // Re-fetch when auth state changes
    ref.listen(clientAuthProvider, (prev, next) {
      final addr = next.walletAddress;
      if (addr != null && addr != prev?.walletAddress) {
        refresh();
      } else if (addr == null) {
        state = const PositionsState();
        _wsSub?.cancel();
      }
    });

    Future.microtask(refresh);
    return const PositionsState(isLoading: true);
  }

  Future<void> refresh() async {
    final walletAddress = ref.read(clientAuthProvider).walletAddress;
    if (walletAddress == null) {
      state = const PositionsState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final traderState = await ref
          .read(phoenixTraderServiceProvider)
          .fetchTraderState(walletAddress);
      state = state.copyWith(traderState: traderState, isLoading: false);
      _subscribeWs(walletAddress);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load positions: $e',
      );
    }
  }

  /// Close a position (fully or partially) by placing a reverse market order.
  /// [sizeBase] — amount to close; defaults to full position size if null.
  /// Returns null on success, or an error message string on failure.
  Future<String?> closePosition(
    PhoenixPosition position, {
    double? sizeBase,
  }) async {
    final walletAddress = ref.read(clientAuthProvider).walletAddress;
    if (walletAddress == null) return 'No wallet connected';

    final closeSize = (sizeBase != null && sizeBase > 0)
        ? sizeBase.clamp(0.0, position.sizeBase)
        : position.sizeBase;

    try {
      final result = await ref
          .read(phoenixOrderServiceProvider)
          .closePosition(
            authority: walletAddress,
            symbol: position.symbol,
            positionSide: position.side,
            sizeBase: closeSize,
          );

      if (result.success) {
        // Refresh positions after a short delay so the on-chain state settles
        await Future.delayed(const Duration(seconds: 2));
        await refresh();
        return null;
      }
      return result.error ?? 'Close position failed';
    } catch (e) {
      return 'Close position failed: $e';
    }
  }

  /// Update TP/SL on an existing open position.
  /// Returns null on success, or an error message on failure.
  Future<String?> setTpSl(
    PhoenixPosition position, {
    double? stopLossPrice,
    double? takeProfitPrice,
  }) async {
    final walletAddress = ref.read(clientAuthProvider).walletAddress;
    if (walletAddress == null) return 'No wallet connected';

    try {
      final result = await ref
          .read(phoenixOrderServiceProvider)
          .setPositionTpSl(
            authority: walletAddress,
            symbol: position.symbol,
            positionSide: position.side,
            currentOrders: state.openOrders,
            stopLossPrice: stopLossPrice,
            takeProfitPrice: takeProfitPrice,
          );

      if (result.success) {
        await Future.delayed(const Duration(seconds: 2));
        await refresh();
        return null;
      }
      return result.error ?? 'Set TP/SL failed';
    } catch (e) {
      return 'Set TP/SL failed: $e';
    }
  }

  /// Add USDC collateral to an isolated-margin position.
  /// Returns null on success, or an error message on failure.
  Future<String?> addCollateral(
    PhoenixPosition position,
    double amountUsdc,
  ) async {
    final walletAddress = ref.read(clientAuthProvider).walletAddress;
    if (walletAddress == null) return 'No wallet connected';

    try {
      final result = await ref
          .read(phoenixOrderServiceProvider)
          .addCollateral(
            authority: walletAddress,
            symbol: position.symbol,
            positionSide: position.side,
            amountUsdc: amountUsdc,
          );

      if (result.success) {
        await Future.delayed(const Duration(seconds: 2));
        await refresh();
        return null;
      }
      return result.error ?? 'Add collateral failed';
    } catch (e) {
      return 'Add collateral failed: $e';
    }
  }

  void _subscribeWs(String authority) {
    final ws = ref.read(phoenixWebSocketServiceProvider);
    ws.subscribeTraderState(authority);

    _wsSub?.cancel();
    _wsSub = ws.traderStateStream.listen((msg) {
      final previous = state.traderState;

      // Guard: if the account is known to be unregistered, WS messages
      // must not flip isRegistered back to the constructor default (true).
      // Registration can only happen via POST /v1/invite/activate*, never via WS.
      if (previous?.isRegistered == false) return;

      // WebSocket delivers partial traderState — merge with current
      final updated = PhoenixTraderState.fromApiJson(msg.raw, authority);
      state = state.copyWith(traderState: updated, isLoading: false);

      // ── Fill detection ──────────────────────────────────────────────────
      // Fire a local notification whenever a position closes.
      if (previous != null && previous.positions.isNotEmpty) {
        _detectAndNotifyFills(previous.positions, updated.positions);
      }

      // ── Liquidation risk ────────────────────────────────────────────────
      // Clear the warned set when the position list changes so re-warnings
      // can fire if the user adds margin and then loses it again.
      if (previous != null &&
          previous.positions.map((p) => p.symbol).toSet() !=
              updated.positions.map((p) => p.symbol).toSet()) {
        _liqWarnedSymbols.clear();
      }
      _detectAndNotifyLiquidationRisk(updated.positions);
    });
  }

  void _dispose() {
    _wsSub?.cancel();
  }

  /// Compares previous and current positions; fires a notification for each
  /// position that was closed between the two snapshots.
  void _detectAndNotifyFills(
    List<PhoenixPosition> prev,
    List<PhoenixPosition> current,
  ) {
    final currentSymbols = {for (final p in current) p.symbol};
    for (final oldPos in prev) {
      if (!currentSymbols.contains(oldPos.symbol)) {
        // Position was fully closed
        _sendFillNotification(oldPos);
      }
    }
  }

  void _sendFillNotification(PhoenixPosition pos) {
    final side = pos.side == 'long' ? 'Long' : 'Short';
    final base = pos.symbol.replaceAll('-PERP', '');
    final pnlPrefix = pos.unrealizedPnl >= 0 ? '+' : '';
    final pnlStr = '$pnlPrefix\$${pos.unrealizedPnl.toStringAsFixed(2)}';
    ref
        .read(notificationServiceProvider)
        .showFillNotification(
          title: '✅ $base $side Closed',
          body: 'Position closed · uPnL $pnlStr',
        );
  }

  /// Fire a liquidation-risk notification for each position whose mark price
  /// is within 10% of its liquidation price. Each position is warned only
  /// once per lifecycle (until the position set changes).
  void _detectAndNotifyLiquidationRisk(List<PhoenixPosition> positions) {
    for (final pos in positions) {
      if (_liqWarnedSymbols.contains(pos.symbol)) continue;
      if (pos.liquidationPrice <= 0 || pos.markPrice <= 0) continue;

      final double distancePct;
      if (pos.isLong) {
        // Long: liquidated when price falls to liqPrice
        distancePct =
            ((pos.markPrice - pos.liquidationPrice) / pos.markPrice) * 100;
      } else {
        // Short: liquidated when price rises to liqPrice
        distancePct =
            ((pos.liquidationPrice - pos.markPrice) / pos.markPrice) * 100;
      }

      if (distancePct < 10.0 && distancePct >= 0) {
        _liqWarnedSymbols.add(pos.symbol);
        ref
            .read(notificationServiceProvider)
            .showLiquidationWarning(
              symbol: pos.symbol,
              side: pos.side,
              distancePct: distancePct,
            );
      }
    }
  }
}

final positionsProvider = NotifierProvider<PositionsNotifier, PositionsState>(
  PositionsNotifier.new,
);
