import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth/client_auth_provider.dart';
import '../../../core/providers/settings/ui_preferences_provider.dart';
import '../../../core/services/phoenix/phoenix_order_service.dart';
import '../../../core/services/phoenix/phoenix_websocket_service.dart';
import '../../../core/services/ui_preferences_service.dart';
import '../../markets/providers/markets_provider.dart';
import 'trade_state.dart';

// Re-export so existing consumers keep working without import changes.
export 'trade_state.dart';

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class TradeNotifier extends Notifier<TradeState> {
  StreamSubscription<MarketSnapshotMessage>? _snapshotSub;

  @override
  TradeState build() {
    ref.onDispose(_dispose);
    // Restore last-used side from UI preferences (if memory is enabled)
    final savedSide = UiPreferencesService.enabled
        ? (UiPreferencesService.getTradeSide() == 'sell'
              ? OrderSide.sell
              : OrderSide.buy)
        : OrderSide.buy;
    // Subscribe to the default symbol immediately
    Future.microtask(() => _subscribeToMarket(state.symbol));
    return TradeState(side: savedSide);
  }

  // ---------------------------------------------------------------------------
  // User interactions
  // ---------------------------------------------------------------------------

  void selectSymbol(String symbol) {
    if (symbol == state.symbol) return;
    _unsubscribeMarket(state.symbol);
    state = state.copyWith(
      symbol: symbol,
      marketSnapshot: null,
      submitError: null,
      lastTxSignature: null,
      lastSubmittedTrade: null,
    );
    _subscribeToMarket(symbol);
  }

  void applyTradeIntent({
    required String symbol,
    OrderSide? side,
    double? leverage,
  }) {
    if (symbol != state.symbol) {
      selectSymbol(symbol);
    }

    if (side != null && side != state.side) {
      setSide(side);
    }

    if (leverage != null && leverage > 0 && leverage != state.leverage) {
      setLeverage(leverage.clamp(1.0, 20.0));
    }
  }

  void setSide(OrderSide side) {
    final liqPrice = _calcLiqPrice(state.markPrice, state.leverage, side);
    state = state.copyWith(side: side, estimatedLiqPrice: liqPrice);
    // Persist so next session opens on the same side
    ref
        .read(uiPreferencesProvider.notifier)
        .setTradeSide(side == OrderSide.sell ? 'sell' : 'buy');
  }

  void setOrderType(OrderType type) {
    // Auto-fill current mark price when switching to limit mode
    final autoPrice =
        type == OrderType.limit && state.price == 0 && state.markPrice > 0
        ? state.markPrice
        : null;
    final nextSlippageBps = type == OrderType.market ? state.slippageBps : 0;
    final qty = _calcQuantity(
      state.sizeUsdc,
      state.leverage,
      state.markPrice,
      _currentTakerFeeBps(),
      nextSlippageBps,
    );
    state = state.copyWith(
      orderType: type,
      submitError: null,
      price: autoPrice ?? state.price,
      quantity: qty,
      // Post-only is only valid for limit orders; reset when switching to market
      postOnly: type == OrderType.market ? false : state.postOnly,
    );
  }

  /// Set the USDC collateral size and recalculate base quantity.
  void setSizeUsdc(double usdc) {
    final qty = _calcQuantity(
      usdc,
      state.leverage,
      state.markPrice,
      _currentTakerFeeBps(),
      _currentSlippageBps(),
    );
    final liqPrice = _calcLiqPrice(state.markPrice, state.leverage, state.side);
    state = state.copyWith(
      sizeUsdc: usdc,
      quantity: qty,
      collateralUsdc: usdc,
      estimatedLiqPrice: liqPrice,
    );
  }

  /// Set leverage multiplier and recalculate base quantity.
  void setLeverage(double leverage) {
    final qty = _calcQuantity(
      state.sizeUsdc,
      leverage,
      state.markPrice,
      _currentTakerFeeBps(),
      _currentSlippageBps(),
    );
    final liqPrice = _calcLiqPrice(state.markPrice, leverage, state.side);
    state = state.copyWith(
      leverage: leverage,
      quantity: qty,
      estimatedLiqPrice: liqPrice,
    );
  }

  void setPrice(double price) => state = state.copyWith(price: price);

  void setCollateral(double usdc) =>
      state = state.copyWith(collateralUsdc: usdc);

  void setSlippageBps(int bps) {
    final qty = _calcQuantity(
      state.sizeUsdc,
      state.leverage,
      state.markPrice,
      _currentTakerFeeBps(),
      state.orderType == OrderType.market ? bps : 0,
    );
    state = state.copyWith(slippageBps: bps, quantity: qty);
  }

  void clearResult() => state = state.copyWith(clearResult: true);

  void setSubmitError(String? error) =>
      state = state.copyWith(submitError: error);

  // TP/SL
  void toggleTpSl(bool enabled) {
    if (!enabled) {
      state = state.copyWith(tpSlEnabled: false, clearTpSl: true);
      return;
    }
    // Auto-calculate sensible defaults when enabling
    final mark = state.markPrice;
    double? sl, tp;
    if (mark > 0) {
      if (state.side == OrderSide.buy) {
        sl = mark * 0.97; // 3% below mark for long SL
        tp = mark * 1.06; // 6% above mark for long TP
      } else {
        sl = mark * 1.03; // 3% above mark for short SL
        tp = mark * 0.94; // 6% below mark for short TP
      }
    }
    state = state.copyWith(
      tpSlEnabled: true,
      stopLossPrice: sl,
      takeProfitPrice: tp,
    );
  }

  void setStopLossPrice(double? price) =>
      state = state.copyWith(stopLossPrice: price);

  void setTakeProfitPrice(double? price) =>
      state = state.copyWith(takeProfitPrice: price);

  /// Toggle post-only mode for limit orders. When enabled, the order is
  /// rejected if it would immediately cross the book (maker-only fill).
  void togglePostOnly(bool v) => state = state.copyWith(postOnly: v);

  double _calcQuantity(
    double sizeUsdc,
    double leverage,
    double markPrice,
    double takerFeeBps,
    int slippageBps,
  ) {
    if (markPrice <= 0 || sizeUsdc <= 0) return 0;
    return tradeBaseQuantity(
      collateralUsdc: sizeUsdc,
      leverage: leverage,
      markPrice: markPrice,
      takerFeeRateBps: takerFeeBps,
      slippageBps: slippageBps,
    );
  }

  double _currentTakerFeeBps() {
    final market = ref
        .read(marketsProvider)
        .markets
        .where((m) => m.symbol == state.symbol)
        .firstOrNull;
    return market?.takerFeeRateBps ?? 5.0;
  }

  int _currentSlippageBps() =>
      state.orderType == OrderType.market ? state.slippageBps : 0;

  /// Estimate liquidation price using isolated-margin formula.
  /// For Long:  liqPrice = entryPrice × (1 - 1/leverage + maintenanceMargin)
  /// For Short: liqPrice = entryPrice × (1 + 1/leverage - maintenanceMargin)
  double? _calcLiqPrice(double entryPrice, double leverage, OrderSide side) {
    if (entryPrice <= 0 || leverage <= 0) return null;
    const maintenanceMargin = 0.02; // 2% maintenance margin (Phoenix default)
    if (side == OrderSide.buy) {
      return entryPrice * (1 - 1 / leverage + maintenanceMargin);
    } else {
      return entryPrice * (1 + 1 / leverage - maintenanceMargin);
    }
  }

  // ---------------------------------------------------------------------------
  // Order submission
  // ---------------------------------------------------------------------------

  Future<bool> submitOrder() async {
    if (!state.canSubmit) return false;

    final walletAddress = ref.read(clientAuthProvider).walletAddress;
    if (walletAddress == null) {
      state = state.copyWith(
        submitError: 'No wallet connected',
        isSubmitting: false,
      );
      return false;
    }

    // Recalculate quantity with live price just before submission
    final livePrice = state.markPrice;
    final takerFeeBps = _currentTakerFeeBps();
    final slippageBps = _currentSlippageBps();
    final finalQty = livePrice > 0
      ? _calcQuantity(
        state.sizeUsdc,
        state.leverage,
        livePrice,
        takerFeeBps,
        slippageBps,
        )
        : state.quantity;

    if (finalQty <= 0) {
      state = state.copyWith(
        submitError: 'Cannot determine position size — wait for price feed',
        isSubmitting: false,
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, submitError: null);

    final orderService = ref.read(phoenixOrderServiceProvider);
    final entryPrice = state.orderType == OrderType.market ? livePrice : state.price;
    final notionalUsdc = tradeNotionalUsdc(
      collateralUsdc: state.sizeUsdc,
      leverage: state.leverage,
      takerFeeRateBps: takerFeeBps,
      slippageBps: slippageBps,
    );
    // transferAmount moves already-deposited Phoenix collateral from the
    // cross/parent account into the isolated order account.
    final collateralMicro = (state.sizeUsdc * 1e6).toInt();
    final sl = state.tpSlEnabled ? state.stopLossPrice : null;
    final tp = state.tpSlEnabled ? state.takeProfitPrice : null;

    OrderResult result;
    if (state.orderType == OrderType.market) {
      result = await orderService.placeMarketOrder(
        authority: walletAddress,
        symbol: state.symbol,
        side: state.side == OrderSide.buy ? 'buy' : 'sell',
        quantity: finalQty,
        transferAmountUsdc: collateralMicro,
        stopLossPrice: sl,
        takeProfitPrice: tp,
        slippageBps: state.slippageBps,
      );
    } else {
      result = await orderService.placeLimitOrder(
        authority: walletAddress,
        symbol: state.symbol,
        side: state.side == OrderSide.buy ? 'buy' : 'sell',
        price: state.price,
        quantity: finalQty,
        transferAmountUsdc: collateralMicro,
        stopLossPrice: sl,
        takeProfitPrice: tp,
        postOnly: state.postOnly,
      );
    }

    if (result.success) {
      final snapshot = TradeSubmittedTrade(
        symbol: state.symbol,
        side: state.side,
        orderType: state.orderType,
        leverage: state.leverage,
        quantity: finalQty,
        collateralUsdc: state.sizeUsdc,
        notionalUsdc: notionalUsdc,
        entryPrice: entryPrice,
        estimatedLiqPrice:
            result.estimatedLiquidationPrice ?? state.estimatedLiqPrice,
        txSignature: result.txSignature ?? '',
        submittedAt: DateTime.now(),
      );
      state = state.copyWith(
        isSubmitting: false,
        lastTxSignature: result.txSignature,
        lastSubmittedTrade: snapshot,
        estimatedLiqPrice: result.estimatedLiquidationPrice,
        submitError: null,
      );
    } else {
      state = state.copyWith(
        isSubmitting: false,
        submitError: result.error ?? 'Order failed',
      );
    }

    return result.success;
  }

  // ---------------------------------------------------------------------------
  // WebSocket
  // ---------------------------------------------------------------------------

  void _subscribeToMarket(String symbol) {
    final ws = ref.read(phoenixWebSocketServiceProvider);
    ws.subscribeMarket(symbol);

    _snapshotSub?.cancel();
    _snapshotSub = ws.marketStream
        .where((m) => m.snapshot.symbol == symbol)
        .listen((m) {
          final newPrice = m.snapshot.markPrice;
          // Recalculate quantity if user has already set a USDC size
          final newQty = state.sizeUsdc > 0 && newPrice > 0
          ? _calcQuantity(
            state.sizeUsdc,
            state.leverage,
            newPrice,
            _currentTakerFeeBps(),
            _currentSlippageBps(),
          )
              : state.quantity;
          final newLiqPrice = state.sizeUsdc > 0
              ? _calcLiqPrice(newPrice, state.leverage, state.side)
              : state.estimatedLiqPrice;
          state = state.copyWith(
            marketSnapshot: m.snapshot,
            quantity: newQty,
            estimatedLiqPrice: newLiqPrice,
          );
        });
  }

  void _unsubscribeMarket(String symbol) {
    _snapshotSub?.cancel();
    ref.read(phoenixWebSocketServiceProvider).unsubscribeMarket(symbol);
  }

  void _dispose() {
    _snapshotSub?.cancel();
  }
}

final tradeProvider = NotifierProvider<TradeNotifier, TradeState>(
  TradeNotifier.new,
);
