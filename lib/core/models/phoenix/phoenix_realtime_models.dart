/// A single fill from `/trader/{authority}/trades-history`.
class PhoenixTradeHistoryItem {
  final String symbol;
  final String side;
  final double price;
  final double size;
  final double fee;
  final double realizedPnl;
  final double baseLotsBefore;
  final double baseLotsAfter;
  final double baseLotsDelta;
  final String instructionType;
  final int timestamp;

  const PhoenixTradeHistoryItem({
    required this.symbol,
    required this.side,
    required this.price,
    required this.size,
    required this.fee,
    required this.realizedPnl,
    required this.baseLotsBefore,
    required this.baseLotsAfter,
    required this.baseLotsDelta,
    required this.instructionType,
    required this.timestamp,
  });

  bool get isBuy => side == 'bid';

  bool get isOpeningFill =>
      _isNearZero(baseLotsBefore) && !_isNearZero(baseLotsAfter);
  bool get isClosingFill =>
      !_isNearZero(baseLotsBefore) && _isNearZero(baseLotsAfter);
  bool get isFlipFill =>
      !_isNearZero(baseLotsBefore) &&
      !_isNearZero(baseLotsAfter) &&
      baseLotsBefore.sign != baseLotsAfter.sign;
  bool get isIncreaseFill =>
      !_isNearZero(baseLotsBefore) &&
      !_isNearZero(baseLotsAfter) &&
      baseLotsBefore.sign == baseLotsAfter.sign &&
      baseLotsAfter.abs() > baseLotsBefore.abs();
  bool get isReduceFill =>
      !_isNearZero(baseLotsBefore) &&
      !_isNearZero(baseLotsAfter) &&
      baseLotsBefore.sign == baseLotsAfter.sign &&
      baseLotsAfter.abs() < baseLotsBefore.abs();
  bool get isStopLossExecution =>
      instructionType.toLowerCase().contains('stoploss');
  bool get isTakeProfitExecution =>
      instructionType.toLowerCase().contains('takeprofit');

  String get exposureSideBefore =>
      _signedExposure(baseLotsBefore, fallback: baseLotsDelta);
  String get exposureSideAfter =>
      _signedExposure(baseLotsAfter, fallback: baseLotsDelta);
  String get lifecycleSideLabel => _titleCase(
    (isClosingFill || isReduceFill || isFlipFill)
        ? exposureSideBefore
        : exposureSideAfter,
  );
  String get lifecycleLabel {
    if (isStopLossExecution) return 'Stop Loss';
    if (isTakeProfitExecution) return 'Take Profit';
    if (isFlipFill) return 'Flipped';
    if (isClosingFill) return 'Closed';
    if (isReduceFill) return 'Reduced';
    if (isIncreaseFill) return 'Added';
    if (isOpeningFill) return 'Opened';
    return 'Filled';
  }

  String get instructionLabel => _humanizeInstructionType(instructionType);

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(
    timestamp > 9999999999 ? timestamp : timestamp * 1000,
    isUtc: true,
  );

  factory PhoenixTradeHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawSymbol = (json['symbol'] ?? json['marketSymbol'] ?? '') as String;
    final sym = rawSymbol.endsWith('-PERP') ? rawSymbol : '$rawSymbol-PERP';
    final baseAmt = _historyBaseAmount(json);
    final quoteAmt = _historyQuoteAmount(json);
    final price = _toDouble(json['price']) > 0
        ? _toDouble(json['price'])
        : (baseAmt > 0 ? quoteAmt / baseAmt : 0.0);
    final delta = _toDouble(json['baseLotsDelta'] ?? json['baseAmount']);
    final side = (json['side'] as String?) ?? (delta >= 0 ? 'bid' : 'ask');
    return PhoenixTradeHistoryItem(
      symbol: sym,
      side: side,
      price: price,
      size: baseAmt,
      fee: _toDouble(json['fee'] ?? json['fees']),
      realizedPnl: _toDouble(json['realizedPnl']),
      baseLotsBefore: _toDouble(json['baseLotsBefore']),
      baseLotsAfter: _toDouble(json['baseLotsAfter']),
      baseLotsDelta: delta,
      instructionType: json['instructionType'] as String? ?? 'Fill',
      timestamp: _parseHistoryTimestamp(json['timestamp']),
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

double _historyBaseAmount(Map<String, dynamic> json) {
  final directBaseAmount = _toDouble(json['baseAmount']);
  if (directBaseAmount > 0) return directBaseAmount;
  return _toDouble(json['baseLotsDelta']).abs();
}

double _historyQuoteAmount(Map<String, dynamic> json) {
  final directQuoteAmount = _toDouble(json['quoteAmount']);
  if (directQuoteAmount > 0) return directQuoteAmount;
  return _toDouble(json['virtualQuoteLotsDelta']).abs();
}

int _parseHistoryTimestamp(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();

  if (value is String) {
    final parsedInt = int.tryParse(value);
    if (parsedInt != null) return parsedInt;

    final parsedDateTime = DateTime.tryParse(value);
    if (parsedDateTime != null) {
      return parsedDateTime.millisecondsSinceEpoch;
    }
  }

  return 0;
}

bool _isNearZero(double value) => value.abs() < 0.0000001;

String _signedExposure(double value, {required double fallback}) {
  final source = _isNearZero(value) ? fallback : value;
  return source >= 0 ? 'long' : 'short';
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _humanizeInstructionType(String value) {
  if (value.isEmpty) return 'Fill';

  final words = value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll('_', ' ')
      .trim()
      .split(RegExp(r'\s+'));

  return words
      .where((word) => word.isNotEmpty)
      .map((word) => _titleCase(word.toLowerCase()))
      .join(' ');
}
