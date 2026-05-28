/// Request to build a market order instruction via Phoenix API
class PhoenixMarketOrderRequest {
  final String authority;
  final String symbol;
  final String side;
  final double sizeUsd;
  final int? traderPdaIndex;
  final String? builderCode;

  const PhoenixMarketOrderRequest({
    required this.authority,
    required this.symbol,
    required this.side,
    required this.sizeUsd,
    this.traderPdaIndex,
    this.builderCode,
  });

  Map<String, dynamic> toJson() => {
    'authority': authority,
    'symbol': symbol,
    'side': side,
    'sizeUsd': sizeUsd,
    if (traderPdaIndex != null) 'traderPdaIndex': traderPdaIndex,
    if (builderCode != null && builderCode!.isNotEmpty)
      'builderCode': builderCode,
  };
}

/// Request to build a limit order instruction via Phoenix API
class PhoenixLimitOrderRequest {
  final String authority;
  final String symbol;
  final String side;
  final double price;
  final double sizeUsd;
  final bool postOnly;
  final int? traderPdaIndex;
  final String? builderCode;

  const PhoenixLimitOrderRequest({
    required this.authority,
    required this.symbol,
    required this.side,
    required this.price,
    required this.sizeUsd,
    this.postOnly = false,
    this.traderPdaIndex,
    this.builderCode,
  });

  Map<String, dynamic> toJson() => {
    'authority': authority,
    'symbol': symbol,
    'side': side,
    'price': price,
    'sizeUsd': sizeUsd,
    'postOnly': postOnly,
    if (traderPdaIndex != null) 'traderPdaIndex': traderPdaIndex,
    if (builderCode != null && builderCode!.isNotEmpty)
      'builderCode': builderCode,
  };
}

/// A Solana instruction returned by Phoenix order builder endpoints
class PhoenixInstructionResponse {
  final String programId;
  final List<int> data;
  final List<Map<String, dynamic>> keys;

  const PhoenixInstructionResponse({
    required this.programId,
    required this.data,
    required this.keys,
  });

  factory PhoenixInstructionResponse.fromJson(Map<String, dynamic> json) =>
      PhoenixInstructionResponse(
        programId: json['programId'] as String,
        data: (json['data'] as List<dynamic>).cast<int>(),
        keys: (json['keys'] as List<dynamic>)
            .map((k) => k as Map<String, dynamic>)
            .toList(),
      );
}

/// Enhanced order response includes instructions + liquidation estimate
class PhoenixEnhancedOrderResponse {
  final List<PhoenixInstructionResponse> instructions;
  final double? estimatedLiquidationPrice;
  final double? estimatedFillPrice;

  const PhoenixEnhancedOrderResponse({
    required this.instructions,
    this.estimatedLiquidationPrice,
    this.estimatedFillPrice,
  });

  factory PhoenixEnhancedOrderResponse.fromJson(Map<String, dynamic> json) {
    final rawIxList =
        json['instructions'] as List<dynamic>? ?? [json] as List<dynamic>;
    return PhoenixEnhancedOrderResponse(
      instructions: rawIxList
          .map(
            (ix) =>
                PhoenixInstructionResponse.fromJson(ix as Map<String, dynamic>),
          )
          .toList(),
      estimatedLiquidationPrice: json['estimatedLiquidationPrice'] != null
          ? _toDouble(json['estimatedLiquidationPrice'])
          : json['estimatedLiquidationPriceUsd'] != null
          ? _toDouble(json['estimatedLiquidationPriceUsd'])
          : null,
      estimatedFillPrice: json['estimatedFillPrice'] != null
          ? _toDouble(json['estimatedFillPrice'])
          : null,
    );
  }
}

// --- private helpers ---

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  if (value is num) return value.toDouble();
  return 0.0;
}
