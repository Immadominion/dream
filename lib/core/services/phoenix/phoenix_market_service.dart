import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../models/phoenix/phoenix_models.dart';
import '../logger_service.dart';

final phoenixMarketServiceProvider = Provider<PhoenixMarketService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  return PhoenixMarketService(logger: logger);
});

/// Handles public (no-auth) Phoenix market data endpoints.
///
/// - GET /exchange/markets  → static market configs
/// - GET /v1/exchange/snapshot → live snapshot with all market states
/// - GET /candles           → OHLCV history
class PhoenixMarketService {
  final LoggerService _logger;
  late final Dio _dio;

  PhoenixMarketService({required LoggerService logger}) : _logger = logger {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.phoenixApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (err, handler) {
          _logger.error(
            'Market HTTP ${err.response?.statusCode}: ${err.requestOptions.path}',
            error: err,
            tag: 'Markets',
          );
          handler.next(err);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Markets list
  // ---------------------------------------------------------------------------

  /// Fetch all active markets from GET /exchange/markets.
  /// Returns markets sorted: active first, then by symbol.
  Future<List<PhoenixMarket>> fetchMarkets() async {
    try {
      _logger.info('Fetching markets list', tag: 'Markets');
      final response = await _dio.get<List<dynamic>>('/exchange/markets');
      final data = response.data ?? [];

      final markets =
          data
              .map((m) => PhoenixMarket.fromApiJson(m as Map<String, dynamic>))
              .where((m) => m.isActive)
              .toList()
            ..sort((a, b) => a.symbol.compareTo(b.symbol));

      _logger.info('Fetched ${markets.length} markets', tag: 'Markets');
      return markets;
    } catch (e) {
      _logger.error('fetchMarkets failed', error: e, tag: 'Markets');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Single market
  // ---------------------------------------------------------------------------

  /// Fetch config for a single market via GET /exchange/market/{symbol}.
  Future<PhoenixMarket> fetchMarket(String symbol) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/exchange/market/$symbol',
      );
      return PhoenixMarket.fromApiJson(response.data!);
    } catch (e) {
      _logger.error('fetchMarket($symbol) failed', error: e, tag: 'Markets');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Candles
  // ---------------------------------------------------------------------------

  /// Fetch OHLCV candles for [symbol] at [timeframe] (e.g. '1m', '5m', '1h', '1d').
  ///
  /// Phoenix candle endpoint: GET /candles?symbol=SOL&timeframe=1h&limit=200
  Future<List<PhoenixCandle>> fetchCandles({
    required String symbol,
    String timeframe = '1h',
    int limit = 200,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/candles',
        queryParameters: {
          'symbol': symbol,
          'timeframe': timeframe,
          'limit': limit,
        },
      );
      final data = response.data ?? [];
      return data
          .map((c) => PhoenixCandle.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.error('fetchCandles($symbol) failed', error: e, tag: 'Markets');
      rethrow;
    }
  }
}
