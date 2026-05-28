import 'dart:math' as math;
import 'package:equatable/equatable.dart';

/// An open perpetual position
class PhoenixPosition extends Equatable {
  final String symbol;
  final String side;
  final double sizeBase;
  final double sizeUsd;
  final double entryPrice;
  final double markPrice;
  final double liquidationPrice;
  final double unrealizedPnl;
  final double unrealizedPnlPercent;
  final double collateral;
  final double leverage;
  final double accumulatedFunding;
  final double? stopLossPrice;
  final double? takeProfitPrice;

  const PhoenixPosition({
    required this.symbol,
    required this.side,
    required this.sizeBase,
    required this.sizeUsd,
    required this.entryPrice,
    required this.markPrice,
    required this.liquidationPrice,
    required this.unrealizedPnl,
    required this.unrealizedPnlPercent,
    required this.collateral,
    required this.leverage,
    required this.accumulatedFunding,
    this.stopLossPrice,
    this.takeProfitPrice,
  });

  bool get isLong => side == 'long';
  bool get isProfitable => unrealizedPnl > 0;

  factory PhoenixPosition.fromJson(Map<String, dynamic> json) {
    final entryPrice = _toDouble(
      json['entryPrice'] ?? json['entry_price'] ?? 0,
    );
    final markPrice = _toDouble(
      json['markPrice'] ?? json['mark_price'] ?? entryPrice,
    );
    final sizeBase = _toDouble(json['sizeBase'] ?? json['size'] ?? 0);
    final sizeUsd = _toDouble(
      json['sizeUsd'] ?? json['notional'] ?? sizeBase * entryPrice,
    );
    final pnl = _toDouble(json['unrealizedPnl'] ?? json['unrealized_pnl'] ?? 0);
    final collateral = _toDouble(json['collateral'] ?? 0);

    return PhoenixPosition(
      symbol: json['symbol'] as String? ?? '',
      side: json['side'] as String? ?? 'long',
      sizeBase: sizeBase,
      sizeUsd: sizeUsd,
      entryPrice: entryPrice,
      markPrice: markPrice,
      liquidationPrice: _toDouble(
        json['liquidationPrice'] ?? json['liq_price'] ?? 0,
      ),
      unrealizedPnl: pnl,
      unrealizedPnlPercent: collateral > 0 ? (pnl / collateral) * 100 : 0.0,
      collateral: collateral,
      leverage: _toDouble(json['leverage'] ?? 1),
      accumulatedFunding: _toDouble(
        json['accumulatedFunding'] ?? json['funding_pnl'] ?? 0,
      ),
      stopLossPrice: json['stopLossPrice'] != null
          ? _toDouble(json['stopLossPrice'])
          : null,
      takeProfitPrice: json['takeProfitPrice'] != null
          ? _toDouble(json['takeProfitPrice'])
          : null,
    );
  }

  /// Parse from GET /trader/{authority}/state response
  factory PhoenixPosition.fromApiJson(Map<String, dynamic> json) {
    final rawSize = _toDouble(json['positionSize'] ?? 0);
    final side = rawSize >= 0 ? 'long' : 'short';
    final sizeBase = rawSize.abs();
    final entryPrice = _toDouble(json['entryPrice'] ?? 0);
    final positionValue = _toDouble(
      json['positionValue'] ?? sizeBase * entryPrice,
    );
    final pnl = _toDouble(json['unrealizedPnl'] ?? 0);
    final collateral = _toDouble(
      json['positionInitialMargin'] ?? json['initialMargin'] ?? 0,
    );

    return PhoenixPosition(
      symbol: json['symbol'] as String? ?? '',
      side: side,
      sizeBase: sizeBase,
      sizeUsd: positionValue,
      entryPrice: entryPrice,
      markPrice: _toDouble(json['markPrice'] ?? entryPrice),
      liquidationPrice: _toDouble(json['liquidationPrice'] ?? 0),
      unrealizedPnl: pnl,
      unrealizedPnlPercent: collateral > 0 ? (pnl / collateral) * 100 : 0.0,
      collateral: collateral,
      leverage: collateral > 0 ? positionValue / collateral : 1.0,
      accumulatedFunding: _toDouble(json['accumulatedFunding'] ?? 0),
      stopLossPrice: json['stopLossPrice'] != null
          ? _toDouble(json['stopLossPrice'])
          : null,
      takeProfitPrice: json['takeProfitPrice'] != null
          ? _toDouble(json['takeProfitPrice'])
          : null,
    );
  }

  @override
  List<Object?> get props => [symbol, side, sizeBase, entryPrice];
}

/// An open resting or conditional order
class PhoenixOpenOrder extends Equatable {
  final String orderId;
  final String symbol;
  final String side;
  final String orderType;
  final double price;
  final double size;
  final double filledSize;
  final DateTime createdAt;
  final bool isConditional;
  final int? conditionalOrderIndex;
  final String? executionDirection;

  const PhoenixOpenOrder({
    required this.orderId,
    required this.symbol,
    required this.side,
    required this.orderType,
    required this.price,
    required this.size,
    required this.filledSize,
    required this.createdAt,
    required this.isConditional,
    this.conditionalOrderIndex,
    this.executionDirection,
  });

  double get remainingSize => size - filledSize;
  double get fillPercent => size > 0 ? (filledSize / size) * 100 : 0;

  factory PhoenixOpenOrder.fromJson(Map<String, dynamic> json) =>
      PhoenixOpenOrder(
        orderId: json['orderId']?.toString() ?? json['id']?.toString() ?? '',
        symbol: json['symbol'] as String? ?? '',
        side: json['side'] as String? ?? 'buy',
        orderType:
            json['orderType'] as String? ??
            json['order_type'] as String? ??
            'limit',
        price: _toDouble(json['price'] ?? 0),
        size: _toDouble(json['size'] ?? json['quantity'] ?? 0),
        filledSize: _toDouble(json['filledSize'] ?? json['filled'] ?? 0),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        isConditional: json['isConditional'] as bool? ?? false,
        conditionalOrderIndex: json['conditionalOrderIndex'] as int?,
        executionDirection: json['executionDirection'] as String?,
      );

  /// Parse from TraderView.limitOrders[symbol][i]
  factory PhoenixOpenOrder.fromLimitOrder(
    Map<String, dynamic> json,
    String symbol,
  ) {
    final apiSide = (json['side'] as String? ?? 'bid').toLowerCase();
    final side = apiSide == 'bid' ? 'buy' : 'sell';
    final orderId = json['orderSequenceNumber']?.toString() ?? '';
    final size = _toDouble(json['initialTradeSize'] ?? 0);
    final remaining = _toDouble(json['tradeSizeRemaining'] ?? size);
    final filled = size - remaining;
    final isConditional = json['isConditionalOrder'] as bool? ?? false;

    final rawType = (json['orderType'] ?? json['order_type']) as String?;
    final String orderType;
    if (rawType != null && rawType.isNotEmpty) {
      orderType = rawType;
    } else if (isConditional) {
      final subtype =
          (json['conditionalType'] ?? json['orderSubtype'] ?? '') as String;
      if (subtype.toLowerCase().contains('stop')) {
        orderType = 'stop_loss';
      } else if (subtype.toLowerCase().contains('profit') ||
          subtype.toLowerCase().contains('take')) {
        orderType = 'take_profit';
      } else {
        orderType = 'conditional';
      }
    } else {
      orderType = 'limit';
    }

    return PhoenixOpenOrder(
      orderId: orderId,
      symbol: symbol,
      side: side,
      orderType: orderType,
      price: _toDouble(json['price'] ?? 0),
      size: size,
      filledSize: filled.clamp(0, size),
      createdAt: DateTime.now(),
      isConditional: isConditional,
      conditionalOrderIndex: json['conditionalOrderIndex'] as int?,
      executionDirection: json['executionDirection'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    orderId,
    symbol,
    side,
    price,
    conditionalOrderIndex,
  ];
}

/// Complete trader state from GET /trader/{authority}/state
class PhoenixTraderState extends Equatable {
  final String authority;
  final double collateral;
  final double availableMargin;
  final double unrealizedPnl;
  final double equity;
  final int riskTier;
  final List<PhoenixPosition> positions;
  final List<PhoenixOpenOrder> openOrders;
  final DateTime updatedAt;
  final bool isRegistered;

  const PhoenixTraderState({
    required this.authority,
    required this.collateral,
    required this.availableMargin,
    required this.unrealizedPnl,
    required this.equity,
    required this.riskTier,
    required this.positions,
    required this.openOrders,
    required this.updatedAt,
    this.isRegistered = true,
  });

  bool get hasPositions => positions.isNotEmpty;
  bool get hasOpenOrders => openOrders.isNotEmpty;
  bool get isAtRisk => riskTier >= 1;
  bool get isLiquidatable => riskTier >= 3;

  factory PhoenixTraderState.fromJson(
    Map<String, dynamic> json,
    String authority,
  ) {
    final positionsList =
        (json['positions'] as List<dynamic>?)
            ?.map((p) => PhoenixPosition.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    final ordersList =
        (json['openOrders'] ?? json['open_orders'] as List<dynamic>?)
            ?.map((o) => PhoenixOpenOrder.fromJson(o as Map<String, dynamic>))
            .toList() ??
        [];

    final collateral = _toDouble(
      json['collateral'] ?? json['free_collateral'] ?? 0,
    );
    final unrealizedPnl = positionsList.fold<double>(
      0,
      (sum, p) => sum + p.unrealizedPnl,
    );

    return PhoenixTraderState(
      authority: authority,
      collateral: collateral,
      availableMargin: _toDouble(
        json['availableMargin'] ?? json['available_margin'] ?? collateral,
      ),
      unrealizedPnl: unrealizedPnl,
      equity: collateral + unrealizedPnl,
      riskTier: _parseRiskTier(
        (json['riskTier'] ?? json['risk_tier'])?.toString() ?? 'safe',
      ),
      positions: positionsList,
      openOrders: ordersList,
      updatedAt: DateTime.now(),
    );
  }

  /// Parse from GET /trader/{authority}/state response
  factory PhoenixTraderState.fromApiJson(
    Map<String, dynamic> json,
    String authority,
  ) {
    final positionsList =
        (json['positions'] as List<dynamic>?)
            ?.map((p) => PhoenixPosition.fromApiJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    final limitOrdersMap = Map<String, dynamic>.from(
      (json['limitOrders'] as Map?) ?? const {},
    );
    final ordersList = <PhoenixOpenOrder>[];
    for (final entry in limitOrdersMap.entries) {
      final symbol = entry.key;
      final orders = (entry.value as List<dynamic>?) ?? [];
      for (final o in orders) {
        ordersList.add(
          PhoenixOpenOrder.fromLimitOrder(o as Map<String, dynamic>, symbol),
        );
      }
    }

    final collateral = _toDouble(json['collateralBalance'] ?? 0);
    final effectiveCollateral = _toDouble(
      json['effectiveCollateral'] ?? collateral,
    );
    final initialMargin = _toDouble(json['initialMargin'] ?? 0);
    final availableMargin = (effectiveCollateral - initialMargin).clamp(
      0,
      double.infinity,
    );
    final unrealizedPnl = _toDouble(json['unrealizedPnl'] ?? 0);
    final equity = _toDouble(
      json['portfolioValue'] ?? collateral + unrealizedPnl,
    );
    final riskTierInt = _parseRiskTier(json['riskTier'] as String? ?? 'safe');

    return PhoenixTraderState(
      authority: authority,
      collateral: collateral,
      availableMargin: availableMargin.toDouble(),
      unrealizedPnl: unrealizedPnl,
      equity: equity,
      riskTier: riskTierInt,
      positions: positionsList,
      openOrders: ordersList,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [authority, equity, updatedAt];
}

// --- private helpers ---

int _parseRiskTier(String tier) => switch (tier) {
  'safe' => 0,
  'atRisk' => 1,
  'cancellable' => 2,
  'liquidatable' => 3,
  'backstopLiquidatable' => 4,
  'highRisk' => 5,
  _ => 0,
};

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  if (value is num) return value.toDouble();
  if (value is Map<String, dynamic>) {
    final ui = value['ui'] ?? value['uiAmount'] ?? value['ui_amount'];
    if (ui != null) {
      return _toDouble(ui);
    }

    final rawValue = value['value'] ?? value['amount'];
    final decimals = value['decimals'];
    if (rawValue != null && decimals != null) {
      final raw = _toDouble(rawValue);
      final scale = _toDouble(decimals);
      if (scale > 0) {
        return raw / math.pow(10, scale.toInt());
      }
      return raw;
    }
  }
  return 0.0;
}
