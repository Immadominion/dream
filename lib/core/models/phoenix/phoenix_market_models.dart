import 'package:equatable/equatable.dart';

/// Market configuration from GET /exchange/market/{symbol}
class PhoenixMarket extends Equatable {
  final String symbol;
  final String baseAsset;
  final String quoteAsset;
  final int maxLeverage;
  final double takerFeeRateBps;
  final double makerFeeRateBps;
  final double minOrderSizeUsd;
  final bool isActive;

  const PhoenixMarket({
    required this.symbol,
    required this.baseAsset,
    required this.quoteAsset,
    required this.maxLeverage,
    required this.takerFeeRateBps,
    required this.makerFeeRateBps,
    required this.minOrderSizeUsd,
    required this.isActive,
  });

  factory PhoenixMarket.fromJson(Map<String, dynamic> json) {
    final symbol = json['symbol'] as String? ?? json['name'] as String? ?? '';
    final parts = symbol.split('-');
    final base = parts.isNotEmpty ? parts[0] : symbol;

    return PhoenixMarket(
      symbol: symbol,
      baseAsset: json['baseAsset'] as String? ?? base,
      quoteAsset: json['quoteAsset'] as String? ?? 'USDC',
      maxLeverage: (json['maxLeverage'] as num?)?.toInt() ?? 20,
      takerFeeRateBps: _toDouble(
        json['takerFeeRateBps'] ?? json['takerFee'] ?? 5.0,
      ),
      makerFeeRateBps: _toDouble(
        json['makerFeeRateBps'] ?? json['makerFee'] ?? 2.0,
      ),
      minOrderSizeUsd: _toDouble(json['minOrderSizeUsd'] ?? 1.0),
      isActive:
          json['isActive'] as bool? ??
          ((json['marketStatus'] as String?) == 'active'),
    );
  }

  /// Parse from GET /exchange/markets response (ExchangeMarketConfig)
  factory PhoenixMarket.fromApiJson(Map<String, dynamic> json) {
    final rawSymbol = json['symbol'] as String? ?? '';
    final symbol = rawSymbol.endsWith('-PERP') ? rawSymbol : '$rawSymbol-PERP';
    final parts = rawSymbol.split('-');
    final base = parts.isNotEmpty ? parts[0] : rawSymbol;

    final tiers = (json['leverageTiers'] as List<dynamic>?) ?? [];
    final maxLeverage = tiers.isEmpty
        ? 20
        : tiers
              .map((t) => (t['maxLeverage'] as num?)?.toInt() ?? 1)
              .reduce((a, b) => a > b ? a : b);

    final takerFee = _toDouble(json['takerFee'] ?? 5.0);
    final makerFee = _toDouble(json['makerFee'] ?? 2.0);

    final status = json['marketStatus'] as String? ?? 'active';
    return PhoenixMarket(
      symbol: symbol,
      baseAsset: base,
      quoteAsset: 'USDC',
      maxLeverage: maxLeverage,
      takerFeeRateBps: takerFee * 100,
      makerFeeRateBps: makerFee * 100,
      minOrderSizeUsd: 1.0,
      isActive: status == 'active' || status == 'postOnly',
    );
  }

  @override
  List<Object?> get props => [symbol];
}

/// Live market snapshot — price, 24h stats, funding rate
class PhoenixMarketSnapshot extends Equatable {
  final String symbol;
  final double markPrice;
  final double indexPrice;
  final double fundingRate;
  final double openInterestUsd;
  final double volume24hUsd;
  final double change24hPercent;
  final double high24h;
  final double low24h;
  final DateTime updatedAt;

  const PhoenixMarketSnapshot({
    required this.symbol,
    required this.markPrice,
    required this.indexPrice,
    required this.fundingRate,
    required this.openInterestUsd,
    required this.volume24hUsd,
    required this.change24hPercent,
    required this.high24h,
    required this.low24h,
    required this.updatedAt,
  });

  factory PhoenixMarketSnapshot.fromJson(
    Map<String, dynamic> json,
  ) => PhoenixMarketSnapshot(
    symbol: json['symbol'] as String? ?? '',
    markPrice: _toDouble(json['markPrice'] ?? json['mark_price'] ?? 0),
    indexPrice: _toDouble(json['indexPrice'] ?? json['index_price'] ?? 0),
    fundingRate: _toDouble(json['fundingRate'] ?? json['funding_rate'] ?? 0),
    openInterestUsd: _toDouble(
      json['openInterestUsd'] ?? json['open_interest'] ?? 0,
    ),
    volume24hUsd: _toDouble(json['volume24hUsd'] ?? json['volume_24h'] ?? 0),
    change24hPercent: _toDouble(
      json['change24hPercent'] ?? json['change_24h'] ?? 0,
    ),
    high24h: _toDouble(json['high24h'] ?? json['high_24h'] ?? 0),
    low24h: _toDouble(json['low24h'] ?? json['low_24h'] ?? 0),
    updatedAt: DateTime.now(),
  );

  /// Parse from WebSocket `market` channel message
  factory PhoenixMarketSnapshot.fromWsMarket(Map<String, dynamic> json) {
    final markPx = _toDouble(json['markPx'] ?? json['markPrice'] ?? 0);
    final prevDayPx = _toDouble(json['prevDayPx'] ?? 0);
    final change24h = prevDayPx > 0
        ? (markPx - prevDayPx) / prevDayPx * 100
        : 0.0;
    final rawSym = json['symbol'] as String? ?? '';
    final sym = rawSym.endsWith('-PERP') ? rawSym : '$rawSym-PERP';
    return PhoenixMarketSnapshot(
      symbol: sym,
      markPrice: markPx,
      indexPrice: _toDouble(json['oraclePx'] ?? json['midPx'] ?? markPx),
      fundingRate: _toDouble(json['funding'] ?? 0),
      openInterestUsd: _toDouble(json['openInterest'] ?? 0),
      volume24hUsd: _toDouble(json['dayNtlVlm'] ?? 0),
      change24hPercent: change24h,
      high24h: _toDouble(json['high24h'] ?? markPx),
      low24h: _toDouble(json['low24h'] ?? markPx),
      updatedAt: DateTime.now(),
    );
  }

  /// Create snapshot with just a mark price update (from allMids WS)
  PhoenixMarketSnapshot withMarkPrice(double price) => PhoenixMarketSnapshot(
    symbol: symbol,
    markPrice: price,
    indexPrice: indexPrice,
    fundingRate: fundingRate,
    openInterestUsd: openInterestUsd,
    volume24hUsd: volume24hUsd,
    change24hPercent: change24hPercent,
    high24h: high24h,
    low24h: low24h,
    updatedAt: DateTime.now(),
  );

  @override
  List<Object?> get props => [symbol, markPrice, updatedAt];
}

/// OHLCV candle from GET /candles or WS 'candle' channel.
/// [time] is Unix milliseconds UTC.
class PhoenixCandle extends Equatable {
  final int time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;
  final double? markClose;

  const PhoenixCandle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
    this.markClose,
  });

  bool get isBullish => close >= open;
  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(time, isUtc: true);

  factory PhoenixCandle.fromJson(Map<String, dynamic> json) => PhoenixCandle(
    time: (json['time'] as num).toInt(),
    open: _toDouble(json['open']),
    high: _toDouble(json['high']),
    low: _toDouble(json['low']),
    close: _toDouble(json['close']),
    volume: json['volume'] != null ? _toDouble(json['volume']) : null,
    markClose: json['markClose'] != null ? _toDouble(json['markClose']) : null,
  );

  @override
  List<Object?> get props => [time, open, high, low, close];
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
