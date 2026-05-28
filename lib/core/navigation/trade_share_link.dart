class TradeShareLink {
  final String symbol;
  final String? side;
  final double? leverage;

  const TradeShareLink({
    required this.symbol,
    this.side,
    this.leverage,
  });

  Uri get appUri => Uri(
    scheme: 'dreamapp',
    host: 'trade',
    path: '/$symbol',
    queryParameters: _queryParameters,
  );

  Uri get webUri => Uri(
    scheme: 'https',
    host: 'dream.app',
    path: '/trade/$symbol',
    queryParameters: _queryParameters,
  );

  String get routeLocation => Uri(
    path: '/trade/$symbol',
    queryParameters: _queryParameters,
  ).toString();

  Map<String, String> get _queryParameters {
    final params = <String, String>{};
    if (side != null && side!.isNotEmpty) {
      params['side'] = side!;
    }
    if (leverage != null && leverage! > 0) {
      final value = leverage!;
      params['leverage'] =
          value.truncateToDouble() == value
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
    }
    return params.isEmpty ? const <String, String>{} : params;
  }

  static TradeShareLink? parse(Uri uri) {
    final normalized = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();

    if (uri.scheme == 'dreamapp') {
      if (uri.host != 'trade' || normalized.isEmpty) return null;
      return TradeShareLink(
        symbol: normalized.first.toUpperCase(),
        side: _normalizeSide(uri.queryParameters['side']),
        leverage: _parseLeverage(uri.queryParameters['leverage']),
      );
    }

    final isDreamHost = uri.host == 'dream.app' || uri.host == 'www.dream.app';
    if (!isDreamHost || normalized.length < 2) return null;

    final route = normalized.first;
    if (route != 'trade' && route != 'market') return null;

    return TradeShareLink(
      symbol: normalized[1].toUpperCase(),
      side: _normalizeSide(uri.queryParameters['side']),
      leverage: _parseLeverage(uri.queryParameters['leverage']),
    );
  }

  static String? _normalizeSide(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'buy':
      case 'long':
        return 'buy';
      case 'sell':
      case 'short':
        return 'sell';
      default:
        return null;
    }
  }

  static double? _parseLeverage(String? value) {
    if (value == null) return null;
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) return null;
    return parsed.clamp(1.0, 20.0);
  }
}