import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_notification.dart';
import '../../../core/models/phoenix/phoenix_models.dart';
import '../../../core/providers/auth/client_auth_provider.dart';
import '../../../core/services/analytics/telegram_analytics_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/notifications/remote_notification_service.dart';
import '../../../core/services/phoenix/phoenix_order_service.dart';
import '../../../core/services/phoenix/phoenix_trader_service.dart';
import '../../../core/services/phoenix/phoenix_websocket_service.dart';
import '../../../shared/services/storage_service.dart';

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
  static const String _positionSnapshotPrefix = 'phoenix_positions_snapshot_v1';

  StreamSubscription<TraderStateMessage>? _wsSub;
  Timer? _wsRefreshDebounce;
  Timer? _pollTimer;

  static const _pollInterval = Duration(seconds: 10);

  // Tracks which positions have already emitted a liq-risk warning.
  final Set<String> _liqWarnedPositionIds = {};

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
        _liqWarnedPositionIds.clear();
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

    await _syncTraderState(walletAddress, showLoading: true, resubscribe: true);
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

        // Analytics
        unawaited(
          ref
              .read(telegramAnalyticsProvider)
              .trackPositionClosed(
                symbol: position.symbol,
                side: position.side,
              ),
        );

        return null;
      }
      return result.error ?? 'Close position failed';
    } catch (e) {
      return 'Close position failed: $e';
    }
  }

  /// Reverse a position: fully close the current side, then open an equal
  /// position on the opposite side using the same collateral (so leverage and
  /// notional are preserved). Isolated Phoenix accounts hold a single position,
  /// so this runs as two sequential market orders — close, then re-open the
  /// flipped side once the close settles.
  ///
  /// Returns null on success, or an error message string on failure.
  Future<String?> reversePosition(PhoenixPosition position) async {
    final walletAddress = ref.read(clientAuthProvider).walletAddress;
    if (walletAddress == null) return 'No wallet connected';

    final sizeBase = position.sizeBase;
    final collateral = position.collateral;
    if (sizeBase <= 0) return 'Position has no size to reverse';

    final orderService = ref.read(phoenixOrderServiceProvider);
    final newSide = position.side == 'long' ? 'sell' : 'buy';

    try {
      // Leg 1 — close the current position fully. Collateral returns to the
      // cross/parent account so it can fund the flipped side.
      final closeResult = await orderService.closePosition(
        authority: walletAddress,
        symbol: position.symbol,
        positionSide: position.side,
        sizeBase: sizeBase,
      );
      if (!closeResult.success) {
        return closeResult.error ?? 'Reverse failed while closing';
      }

      // Let the on-chain close settle before re-opening on the isolated account.
      await Future.delayed(const Duration(seconds: 3));

      // Re-fetch trader state so we know the actual available margin returned
      // from the close (which may differ from position.collateral due to
      // realized PnL, funding and taker fees charged at settlement time).
      await refresh();
      final freshAvailable = state.traderState?.availableMargin ?? 0.0;

      // Budget for leg 2:
      //   • Use the fresh available margin (accurate post-close figure).
      //   • Cap at 101% of original collateral — the extra 1% covers the
      //     taker fee that Phoenix deducts from effective collateral before
      //     comparing against the initial-margin requirement. Without this
      //     buffer the trade bounces with InsufficientFunds even though the
      //     numbers look nearly equal.
      //   • Never exceed what is actually available (prevents over-commit
      //     when the account already had a larger free balance).
      final budget = freshAvailable.clamp(0.0, collateral * 1.01);
      final collateralMicro = (budget * 1e6).floor();

      if (collateralMicro <= 0) {
        return 'Closed your ${position.side.toUpperCase()} but your account '
            'has no available margin to open the reverse side. '
            'Please deposit funds and re-enter manually.';
      }

      // Leg 2 — open the opposite side with the same size and collateral.
      final openResult = await orderService.placeMarketOrder(
        authority: walletAddress,
        symbol: position.symbol,
        side: newSide,
        quantity: sizeBase,
        transferAmountUsdc: collateralMicro,
      );

      if (!openResult.success) {
        // The close succeeded but the flip leg failed — surface a clear message
        // so the user knows they are now flat (not stuck in the old side).
        await Future.delayed(const Duration(seconds: 2));
        await refresh();
        return 'Closed your ${position.side.toUpperCase()} but could not open the '
            '${newSide == 'buy' ? 'LONG' : 'SHORT'}: ${openResult.error ?? 'order failed'}';
      }

      await Future.delayed(const Duration(seconds: 2));
      await refresh();

      unawaited(
        ref
            .read(telegramAnalyticsProvider)
            .trackPositionClosed(symbol: position.symbol, side: position.side),
      );

      return null;
    } catch (e) {
      return 'Reverse failed: $e';
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

        // Analytics
        unawaited(
          ref
              .read(telegramAnalyticsProvider)
              .trackCollateralDeposit(walletAddress, amountUsdc),
        );

        return null;
      }
      return result.error ?? 'Add collateral failed';
    } catch (e) {
      return 'Add collateral failed: $e';
    }
  }

  void _subscribeWs(String authority) {
    final ws = ref.read(phoenixWebSocketServiceProvider);
    ws.connect();
    ws.subscribeTraderState(authority);

    _wsSub?.cancel();
    _wsSub = ws.traderStateStream.listen((msg) {
      final previous = state.traderState;

      // Guard: if the account is known to be unregistered, WS messages
      // must not flip isRegistered back to the constructor default (true).
      // Registration can only happen via POST /v1/invite/activate*, never via WS.
      if (previous?.isRegistered == false) return;

      _scheduleWsRefresh(authority);
    });

    // Fallback polling: refreshes every 10 s so copy-engine positions and
    // any missed WS updates appear without requiring app restart.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_syncTraderState(authority, showLoading: false));
    });
  }

  Future<void> _syncTraderState(
    String authority, {
    required bool showLoading,
    bool resubscribe = false,
  }) async {
    final previousPositions =
        state.traderState?.positions ?? await _loadPositionSnapshot(authority);

    if (showLoading) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final traderState = await ref
          .read(phoenixTraderServiceProvider)
          .fetchTraderState(authority);

      state = state.copyWith(
        traderState: traderState,
        isLoading: false,
        error: null,
      );

      if (resubscribe) {
        _subscribeWs(authority);
      }

      _detectAndNotifyPositionTransitions(
        previousPositions,
        traderState.positions,
      );

      await _savePositionSnapshot(authority, traderState.positions);

      _detectAndNotifyLiquidationRisk(traderState.positions);
    } catch (e) {
      if (showLoading) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load positions: $e',
        );
      }
    }
  }

  void _scheduleWsRefresh(String authority) {
    _wsRefreshDebounce?.cancel();
    _wsRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_syncTraderState(authority, showLoading: false));
    });
  }

  void _dispose() {
    _wsSub?.cancel();
    _wsRefreshDebounce?.cancel();
    _pollTimer?.cancel();
  }

  void _detectAndNotifyPositionTransitions(
    List<PhoenixPosition> prev,
    List<PhoenixPosition> current,
  ) {
    final previousByKey = {for (final pos in prev) _positionKey(pos): pos};
    final currentByKey = {for (final pos in current) _positionKey(pos): pos};

    for (final entry in currentByKey.entries) {
      if (!previousByKey.containsKey(entry.key)) {
        _sendPositionOpenedNotification(entry.value);
      }
    }

    for (final entry in previousByKey.entries) {
      if (!currentByKey.containsKey(entry.key)) {
        _sendPositionClosedNotification(entry.value);
      }
    }
  }

  void _sendPositionOpenedNotification(PhoenixPosition pos) {
    final side = pos.side == 'long' ? 'Long' : 'Short';
    final base = _baseSymbol(pos.symbol);
    final title = '$base $side Opened';
    final body =
        'Position opened · ${_formatBaseAmount(pos.sizeBase)} $base at ${_formatUsd(pos.entryPrice)}';

    ref
        .read(notificationServiceProvider)
        .showGenericNotification(
          category: AppNotifCategory.trade,
          title: title,
          body: body,
          payload: pos.symbol,
        );

    unawaited(
      _recordPositionEvent(
        pos,
        eventType: 'position_opened',
        category: AppNotifCategory.trade,
        title: title,
        body: body,
        eventId: _positionEventId('open', pos, DateTime.now()),
      ),
    );
  }

  void _sendPositionClosedNotification(PhoenixPosition pos) {
    final side = pos.side == 'long' ? 'Long' : 'Short';
    final base = _baseSymbol(pos.symbol);
    final pnlPrefix = pos.unrealizedPnl >= 0 ? '+' : '';
    final pnlStr = '$pnlPrefix\$${pos.unrealizedPnl.toStringAsFixed(2)}';
    final title = '$base $side Closed';
    final body = 'Position closed · uPnL $pnlStr';

    ref
        .read(notificationServiceProvider)
        .showFillNotification(title: title, body: body);

    unawaited(
      _recordPositionEvent(
        pos,
        eventType: 'position_closed',
        category: AppNotifCategory.trade,
        title: title,
        body: body,
        eventId: _positionEventId('close', pos, DateTime.now()),
      ),
    );
  }

  /// Fire a liquidation-risk notification for each position whose mark price
  /// is within 10% of its liquidation price. Each position is warned only
  /// once per lifecycle (until the position set changes).
  void _detectAndNotifyLiquidationRisk(List<PhoenixPosition> positions) {
    final activeIds = positions.map(_riskPositionId).toSet();
    _liqWarnedPositionIds.removeWhere((id) => !activeIds.contains(id));

    for (final pos in positions) {
      final riskId = _riskPositionId(pos);
      if (_liqWarnedPositionIds.contains(riskId)) continue;
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
        _liqWarnedPositionIds.add(riskId);
        final title =
            '${_baseSymbol(pos.symbol)} ${pos.isLong ? 'Long' : 'Short'} Liquidation Risk';
        final body =
            'Only ${distancePct.toStringAsFixed(1)}% from liquidation. Add margin or close now.';
        ref
            .read(notificationServiceProvider)
            .showLiquidationWarning(
              symbol: pos.symbol,
              side: pos.side,
              distancePct: distancePct,
            );

        unawaited(
          _recordPositionEvent(
            pos,
            eventType: 'position_liquidation_risk',
            category: AppNotifCategory.risk,
            title: title,
            body: body,
            eventId: _riskEventId(pos),
          ),
        );
      }
    }
  }

  Future<void> _recordPositionEvent(
    PhoenixPosition pos, {
    required String eventType,
    required AppNotifCategory category,
    required String title,
    required String body,
    required String eventId,
  }) async {
    final walletAddress = ref.read(clientAuthProvider).walletAddress;
    if (walletAddress == null) return;

    await ref
        .read(remoteNotificationServiceProvider)
        .recordClientEvent(
          walletAddress: walletAddress,
          eventId: eventId,
          eventType: eventType,
          category: category,
          title: title,
          body: body,
          symbol: pos.symbol,
          channels: eventType == 'position_liquidation_risk'
              ? const ['push', 'email']
              : const ['push'],
          payload: {
            'symbol': pos.symbol,
            'side': pos.side,
            'sizeBase': pos.sizeBase,
            'entryPrice': pos.entryPrice,
            'markPrice': pos.markPrice,
            'liquidationPrice': pos.liquidationPrice,
            'unrealizedPnl': pos.unrealizedPnl,
            'collateral': pos.collateral,
            'leverage': pos.leverage,
          },
        );
  }

  String _positionKey(PhoenixPosition pos) =>
      '${pos.symbol}:${pos.side}:${pos.entryPrice.toStringAsFixed(6)}:${pos.sizeBase.toStringAsFixed(6)}';

  String _positionEventId(
    String action,
    PhoenixPosition pos,
    DateTime firedAt,
  ) => 'phoenix:$action:${_positionKey(pos)}:${firedAt.millisecondsSinceEpoch}';

  String _riskPositionId(PhoenixPosition pos) =>
      '${pos.symbol}:${pos.side}:${pos.liquidationPrice.toStringAsFixed(6)}';

  String _riskEventId(PhoenixPosition pos) =>
      'phoenix:liq-risk:${_riskPositionId(pos)}';

  String _baseSymbol(String symbol) => symbol.replaceAll('-PERP', '');

  String _formatBaseAmount(double sizeBase) {
    final fixed = sizeBase.toStringAsFixed(4);
    return fixed
        .replaceFirst(RegExp(r'\.0+$'), '')
        .replaceFirst(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  String _formatUsd(double price) => '\$${price.toStringAsFixed(2)}';

  String _positionSnapshotKey(String authority) =>
      '$_positionSnapshotPrefix:$authority';

  Future<List<PhoenixPosition>> _loadPositionSnapshot(String authority) async {
    try {
      final raw = StorageService.getString(_positionSnapshotKey(authority));
      if (raw.isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PhoenixPosition.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _savePositionSnapshot(
    String authority,
    List<PhoenixPosition> positions,
  ) async {
    final payload = positions
        .map(
          (pos) => {
            'symbol': pos.symbol,
            'side': pos.side,
            'sizeBase': pos.sizeBase,
            'sizeUsd': pos.sizeUsd,
            'entryPrice': pos.entryPrice,
            'markPrice': pos.markPrice,
            'liquidationPrice': pos.liquidationPrice,
            'unrealizedPnl': pos.unrealizedPnl,
            'collateral': pos.collateral,
            'leverage': pos.leverage,
            'accumulatedFunding': pos.accumulatedFunding,
            'stopLossPrice': pos.stopLossPrice,
            'takeProfitPrice': pos.takeProfitPrice,
          },
        )
        .toList(growable: false);

    await StorageService.setString(
      _positionSnapshotKey(authority),
      jsonEncode(payload),
    );
  }
}

final positionsProvider = NotifierProvider<PositionsNotifier, PositionsState>(
  PositionsNotifier.new,
);
