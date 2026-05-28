import '../../../core/models/phoenix/phoenix_models.dart';

// ---------------------------------------------------------------------------
// Order enums and immutable state for tradeProvider.
// ---------------------------------------------------------------------------

enum OrderSide { buy, sell }

enum OrderType { market, limit }

class TradeSubmittedTrade {
  final String symbol;
  final OrderSide side;
  final OrderType orderType;
  final double leverage;
  final double quantity;
  final double collateralUsdc;
  final double notionalUsdc;
  final double entryPrice;
  final double? estimatedLiqPrice;
  final String txSignature;
  final DateTime submittedAt;

  const TradeSubmittedTrade({
    required this.symbol,
    required this.side,
    required this.orderType,
    required this.leverage,
    required this.quantity,
    required this.collateralUsdc,
    required this.notionalUsdc,
    required this.entryPrice,
    required this.estimatedLiqPrice,
    required this.txSignature,
    required this.submittedAt,
  });

  factory TradeSubmittedTrade.fromPosition(
    PhoenixPosition position, {
    String? txSignature,
  }) {
    return TradeSubmittedTrade(
      symbol: position.symbol,
      side: position.isLong ? OrderSide.buy : OrderSide.sell,
      orderType: OrderType.market,
      leverage: position.leverage,
      quantity: position.sizeBase,
      collateralUsdc: position.collateral,
      notionalUsdc: position.sizeUsd,
      entryPrice: position.entryPrice,
      estimatedLiqPrice: position.liquidationPrice > 0
          ? position.liquidationPrice
          : null,
      txSignature: txSignature ?? '',
      submittedAt: DateTime.now(),
    );
  }
}

const double _baseCollateralHeadroomFraction = 0.02;

double tradeCollateralHeadroomFraction({
  required double takerFeeRateBps,
  required int slippageBps,
}) {
  final feeFraction = takerFeeRateBps / 10000;
  final slippageFraction = slippageBps / 10000;
  final reserved =
      _baseCollateralHeadroomFraction +
      slippageFraction +
      (feeFraction * 2);
  return (1 - reserved).clamp(0.0, 1.0).toDouble();
}

double tradeEffectiveCollateralUsdc({
  required double collateralUsdc,
  required double takerFeeRateBps,
  required int slippageBps,
}) {
  if (collateralUsdc <= 0) return 0;
  return collateralUsdc *
      tradeCollateralHeadroomFraction(
        takerFeeRateBps: takerFeeRateBps,
        slippageBps: slippageBps,
      );
}

double tradeNotionalUsdc({
  required double collateralUsdc,
  required double leverage,
  required double takerFeeRateBps,
  required int slippageBps,
}) {
  if (leverage <= 0) return 0;
  return tradeEffectiveCollateralUsdc(
        collateralUsdc: collateralUsdc,
        takerFeeRateBps: takerFeeRateBps,
        slippageBps: slippageBps,
      ) *
      leverage;
}

double tradeBaseQuantity({
  required double collateralUsdc,
  required double leverage,
  required double markPrice,
  required double takerFeeRateBps,
  required int slippageBps,
}) {
  if (markPrice <= 0) return 0;
  return tradeNotionalUsdc(
        collateralUsdc: collateralUsdc,
        leverage: leverage,
        takerFeeRateBps: takerFeeRateBps,
        slippageBps: slippageBps,
      ) /
      markPrice;
}

class TradeState {
  final String symbol;
  final OrderSide side;
  final OrderType orderType;
  final double
  quantity; // base asset units (auto-calculated from sizeUsdc/leverage)
  final double sizeUsdc; // Phoenix collateral to allocate to the order
  final double leverage; // leverage multiplier (1–20)
  final double price; // only used for limit orders
  final double collateralUsdc; // Phoenix collateral transfer amount
  final PhoenixMarketSnapshot? marketSnapshot;
  final bool isSubmitting;
  final String? submitError;
  final String? lastTxSignature;
  final TradeSubmittedTrade? lastSubmittedTrade;
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
    this.lastSubmittedTrade,
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
    TradeSubmittedTrade? lastSubmittedTrade,
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
    lastSubmittedTrade: clearResult
      ? null
      : (lastSubmittedTrade ?? this.lastSubmittedTrade),
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
