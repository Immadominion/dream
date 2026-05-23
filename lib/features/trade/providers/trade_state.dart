import '../../../core/models/phoenix/phoenix_models.dart';

// ---------------------------------------------------------------------------
// Order enums and immutable state for tradeProvider.
// ---------------------------------------------------------------------------

enum OrderSide { buy, sell }

enum OrderType { market, limit }

class TradeState {
  final String symbol;
  final OrderSide side;
  final OrderType orderType;
  final double
  quantity; // base asset units (auto-calculated from sizeUsdc/leverage)
  final double sizeUsdc; // USDC collateral to put in (user input)
  final double leverage; // leverage multiplier (1–20)
  final double price; // only used for limit orders
  final double collateralUsdc; // extra USDC collateral to transfer
  final PhoenixMarketSnapshot? marketSnapshot;
  final bool isSubmitting;
  final String? submitError;
  final String? lastTxSignature;
  final double? estimatedLiqPrice;
  // TP/SL
  final bool tpSlEnabled;
  final double? stopLossPrice;
  final double? takeProfitPrice;
  // Slippage tolerance for market orders (in bps, e.g. 50 = 0.5%)
  final int slippageBps;
  // Post-only flag for limit orders — order is cancelled if it would cross the
  // book (maker-only, guaranteed taker fee savings).
  final bool postOnly;

  const TradeState({
    this.symbol = 'SOL-PERP',
    this.side = OrderSide.buy,
    this.orderType = OrderType.market,
    this.quantity = 0,
    this.sizeUsdc = 0,
    this.leverage = 5,
    this.price = 0,
    this.collateralUsdc = 0,
    this.marketSnapshot,
    this.isSubmitting = false,
    this.submitError,
    this.lastTxSignature,
    this.estimatedLiqPrice,
    this.tpSlEnabled = false,
    this.stopLossPrice,
    this.takeProfitPrice,
    this.slippageBps = 50,
    this.postOnly = false,
  });

  TradeState copyWith({
    String? symbol,
    OrderSide? side,
    OrderType? orderType,
    double? quantity,
    double? sizeUsdc,
    double? leverage,
    double? price,
    double? collateralUsdc,
    PhoenixMarketSnapshot? marketSnapshot,
    bool? isSubmitting,
    String? submitError,
    String? lastTxSignature,
    double? estimatedLiqPrice,
    bool clearResult = false,
    bool? tpSlEnabled,
    double? stopLossPrice,
    double? takeProfitPrice,
    bool clearTpSl = false,
    int? slippageBps,
    bool? postOnly,
  }) => TradeState(
    symbol: symbol ?? this.symbol,
    side: side ?? this.side,
    orderType: orderType ?? this.orderType,
    quantity: quantity ?? this.quantity,
    sizeUsdc: sizeUsdc ?? this.sizeUsdc,
    leverage: leverage ?? this.leverage,
    price: price ?? this.price,
    collateralUsdc: collateralUsdc ?? this.collateralUsdc,
    marketSnapshot: marketSnapshot ?? this.marketSnapshot,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    submitError: clearResult ? null : (submitError ?? this.submitError),
    lastTxSignature: clearResult
        ? null
        : (lastTxSignature ?? this.lastTxSignature),
    estimatedLiqPrice: clearResult
        ? null
        : (estimatedLiqPrice ?? this.estimatedLiqPrice),
    tpSlEnabled: tpSlEnabled ?? this.tpSlEnabled,
    stopLossPrice: clearTpSl ? null : (stopLossPrice ?? this.stopLossPrice),
    takeProfitPrice: clearTpSl
        ? null
        : (takeProfitPrice ?? this.takeProfitPrice),
    slippageBps: slippageBps ?? this.slippageBps,
    postOnly: postOnly ?? this.postOnly,
  );

  double get markPrice => marketSnapshot?.markPrice ?? 0;
  double get fundingRate => marketSnapshot?.fundingRate ?? 0;

  /// Notional value of the position in USD
  double get notional => quantity * markPrice;

  bool get canSubmit =>
      !isSubmitting &&
      sizeUsdc > 0 &&
      (orderType == OrderType.market || price > 0);
}
