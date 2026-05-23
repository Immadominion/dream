/// A single fill from `/trader/{authority}/trades-history`.
class PhoenixTradeHistoryItem {
  final String symbol;
  final String side;
  final double price;
  final double size;
  final double fee;
  final int timestamp;

  const PhoenixTradeHistoryItem({
    required this.symbol,
    required this.side,
    required this.price,
    required this.size,
    required this.fee,
    required this.timestamp,
  });

  bool get isBuy => side == 'bid';

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(
    timestamp > 9999999999 ? timestamp : timestamp * 1000,
    isUtc: true,
  );

  factory PhoenixTradeHistoryItem.fromJson(Map<String, dynamic> json) {
    final sym = json['symbol'] as String? ?? '';
    final baseAmt = _toDouble(json['baseAmount']);
    final quoteAmt = _toDouble(json['quoteAmount']);
    final price = baseAmt > 0 ? quoteAmt / baseAmt : 0.0;
    return PhoenixTradeHistoryItem(
      symbol: sym.endsWith('-PERP') ? sym : '$sym-PERP',
      side: json['side'] as String? ?? 'bid',
      price: price,
      size: baseAmt,
      fee: _toDouble(json['fee']),
      timestamp: json['timestamp'] != null
          ? int.tryParse(json['timestamp'].toString()) ?? 0
          : 0,
    );
  }
}

/// A single price level in the orderbook (price, size).
class PhoenixOrderLevel {
  final double price;
  final double size;
  const PhoenixOrderLevel({required this.price, required this.size});
}

/// Live orderbook snapshot from WS `orderbook` channel.
class PhoenixOrderbook {
  final String symbol;
  final List<PhoenixOrderLevel> bids;
  final List<PhoenixOrderLevel> asks;
  final double? mid;

  const PhoenixOrderbook({
    required this.symbol,
    required this.bids,
    required this.asks,
    this.mid,
  });

  double get bestBid => bids.isNotEmpty ? bids.first.price : 0;
  double get bestAsk => asks.isNotEmpty ? asks.first.price : 0;
  double get spread => bestAsk - bestBid;
  double get spreadPct => bestBid > 0 ? (spread / bestBid) * 100 : 0;

  factory PhoenixOrderbook.fromWs(Map<String, dynamic> data) {
    final sym = data['symbol'] as String? ?? '';
    final ob = data['orderbook'] as Map<String, dynamic>? ?? {};
    final bidsRaw = ob['bids'] as List<dynamic>? ?? [];
    final asksRaw = ob['asks'] as List<dynamic>? ?? [];

    List<PhoenixOrderLevel> parseLevels(List<dynamic> raw) => raw.map((e) {
      final arr = e as List<dynamic>;
      return PhoenixOrderLevel(
        price: _toDouble(arr[0]),
        size: _toDouble(arr[1]),
      );
    }).toList();

    return PhoenixOrderbook(
      symbol: sym.endsWith('-PERP') ? sym : '$sym-PERP',
      bids: parseLevels(bidsRaw),
      asks: parseLevels(asksRaw),
      mid: ob['mid'] != null ? _toDouble(ob['mid']) : null,
    );
  }
}

/// A single trade from the WS `trades` channel.
class PhoenixRecentTrade {
  final String symbol;
  final String side;
  final double price;
  final double size;
  final int timestamp;

  const PhoenixRecentTrade({
    required this.symbol,
    required this.side,
    required this.price,
    required this.size,
    required this.timestamp,
  });

  bool get isBuy => side == 'bid';

  factory PhoenixRecentTrade.fromJson(
    String symbol,
    Map<String, dynamic> json,
  ) => PhoenixRecentTrade(
    symbol: symbol,
    side: json['side'] as String? ?? 'bid',
    price: json['quoteAmount'] != null && json['baseAmount'] != null
        ? _toDouble(json['quoteAmount']) /
              (_toDouble(json['baseAmount']) > 0
                  ? _toDouble(json['baseAmount'])
                  : 1)
        : 0,
    size: _toDouble(json['baseAmount']),
    timestamp: json['timestamp'] != null
        ? int.tryParse(json['timestamp'].toString()) ?? 0
        : 0,
  );
}

/// A single data point from GET /trader/{authority}/pnl
class PhoenixPnlPoint {
  final int timestamp;
  final double cumulativePnl;
  final double unrealizedPnl;
  final double cumulativeFundingPayment;
  final double cumulativeTakerFee;

  const PhoenixPnlPoint({
    required this.timestamp,
    required this.cumulativePnl,
    required this.unrealizedPnl,
    required this.cumulativeFundingPayment,
    required this.cumulativeTakerFee,
  });

  double get totalPnl => cumulativePnl + unrealizedPnl;

  factory PhoenixPnlPoint.fromJson(Map<String, dynamic> json) =>
      PhoenixPnlPoint(
        timestamp: _toInt(json['timestamp'] ?? json['startTime'] ?? 0),
        cumulativePnl: _toDouble(json['cumulativePnl']),
        unrealizedPnl: _toDouble(json['unrealizedPnl']),
        cumulativeFundingPayment: _toDouble(json['cumulativeFundingPayment']),
        cumulativeTakerFee: _toDouble(json['cumulativeTakerFee']),
      );
}

/// Response from POST /v1/invite/activate or /v1/invite/activate-with-referral
class PhoenixActivateResponse {
  final String traderPda;

  const PhoenixActivateResponse({required this.traderPda});

  factory PhoenixActivateResponse.fromJson(Map<String, dynamic> json) =>
      PhoenixActivateResponse(traderPda: json['trader_pda'] as String);
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

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
