import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../models/phoenix/phoenix_models.dart';
import '../logger_service.dart';
import '../phoenix/phoenix_auth_service.dart';

final phoenixTraderServiceProvider = Provider<PhoenixTraderService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  final authService = ref.watch(phoenixAuthServiceProvider);
  return PhoenixTraderService(logger: logger, authService: authService);
});

/// Handles trader-specific Phoenix endpoints (public read, authenticated writes).
///
/// GET /trader/{authority}/state is public — no auth required.
/// Order endpoints require Phoenix JWT (handled by phoenix_order_service).
class PhoenixTraderService {
  final LoggerService _logger;
  final PhoenixAuthService _authService;
  late final Dio _dio;

  PhoenixTraderService({
    required LoggerService logger,
    required PhoenixAuthService authService,
  }) : _logger = logger,
       _authService = authService {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.phoenixApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Attach Bearer token when available
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = await _authService.getStoredSession();
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          handler.next(options);
        },
        onError: (err, handler) {
          _logger.error(
            'Trader HTTP ${err.response?.statusCode}: ${err.requestOptions.path}',
            error: err,
            tag: 'Trader',
          );
          handler.next(err);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trader state (public — no auth)
  // ---------------------------------------------------------------------------

  /// Fetch the complete trader state for [authority].
  ///
  /// Returns the first (index 0) trader PDA — sufficient for standard accounts.
  /// On 404 (trader not registered), returns an empty state.
  Future<PhoenixTraderState> fetchTraderState(String authority) async {
    try {
      _logger.info('Fetching trader state for $authority', tag: 'Trader');

      final response = await _dio.get<Map<String, dynamic>>(
        '/trader/$authority/state',
      );
      final data = response.data!;
      final traders = data['traders'] as List<dynamic>? ?? [];

      if (traders.isEmpty) {
        _logger.info('No trader account found for $authority', tag: 'Trader');
        return _emptyState(authority);
      }

      final traderView = traders.first as Map<String, dynamic>;
      return PhoenixTraderState.fromApiJson(traderView, authority);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Trader not registered yet
        return _emptyState(authority);
      }
      _logger.error(
        'fetchTraderState($authority) failed',
        error: e,
        tag: 'Trader',
      );
      rethrow;
    } catch (e) {
      _logger.error(
        'fetchTraderState($authority) failed',
        error: e,
        tag: 'Trader',
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Account registration
  // ---------------------------------------------------------------------------

  /// Activate a new Phoenix account with an invite code.
  ///
  /// Returns the trader PDA string on success, or throws on failure.
  /// If the account already exists (409), returns null (no-op).
  Future<String?> activateAccount(String authority, String inviteCode) async {
    try {
      _logger.info('Activating Phoenix account for $authority', tag: 'Trader');
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/invite/activate',
        data: {'authority': authority, 'code': inviteCode},
      );
      final pda = response.data?['trader_pda'] as String?;
      _logger.info('Activated. Trader PDA: $pda', tag: 'Trader');
      return pda;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // Already activated — treat as success
        _logger.info('Account already activated', tag: 'Trader');
        return null;
      }
      _logger.error('activateAccount failed', error: e, tag: 'Trader');
      rethrow;
    }
  }

  /// Activate with a referral code (instead of invite code).
  Future<String?> activateWithReferral(
    String authority,
    String referralCode,
  ) async {
    try {
      _logger.info('Activating with referral for $authority', tag: 'Trader');
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/invite/activate-with-referral',
        data: {'authority': authority, 'referral_code': referralCode},
      );
      final pda = response.data?['trader_pda'] as String?;
      _logger.info('Activated with referral. Trader PDA: $pda', tag: 'Trader');
      return pda;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        return null;
      }
      _logger.error('activateWithReferral failed', error: e, tag: 'Trader');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Trade history (authenticated)
  // ---------------------------------------------------------------------------

  /// Fetch recent fill history for [authority].
  Future<List<PhoenixTradeHistoryItem>> fetchTradeHistory(
    String authority, {
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/trader/$authority/trades-history',
        queryParameters: {'limit': limit},
      );
      return (response.data ?? [])
          .map(
            (e) => PhoenixTradeHistoryItem.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404)
        return []; // new wallet — no history yet
      _logger.error('fetchTradeHistory failed', error: e, tag: 'Trader');
      return [];
    } catch (e) {
      _logger.error('fetchTradeHistory failed', error: e, tag: 'Trader');
      return [];
    }
  }

  /// Fetch funding payment history for [authority].
  Future<List<Map<String, dynamic>>> fetchFundingHistory(
    String authority, {
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/trader/$authority/funding-history',
        queryParameters: {'limit': limit},
      );
      return (response.data ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      _logger.error('fetchFundingHistory failed', error: e, tag: 'Trader');
      return [];
    } catch (e) {
      _logger.error('fetchFundingHistory failed', error: e, tag: 'Trader');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchCollateralHistory(
    String authority, {
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/trader/$authority/collateral-history',
        queryParameters: {'limit': limit},
      );
      return (response.data ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      _logger.error('fetchCollateralHistory failed', error: e, tag: 'Trader');
      return [];
    } catch (e) {
      _logger.error('fetchCollateralHistory failed', error: e, tag: 'Trader');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrderHistory(
    String authority, {
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/trader/$authority/order-history',
        queryParameters: {'limit': limit},
      );
      return (response.data ?? []).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      _logger.error('fetchOrderHistory failed', error: e, tag: 'Trader');
      return [];
    } catch (e) {
      _logger.error('fetchOrderHistory failed', error: e, tag: 'Trader');
      return [];
    }
  }

  Future<List<PhoenixPnlPoint>> fetchTraderPnl(
    String authority, {
    String resolution = '1d',
    int? startTime,
    int? endTime,
    int limit = 90,
  }) async {
    try {
      final params = <String, dynamic>{
        'resolution': resolution,
        'limit': limit,
      };
      if (startTime != null) params['startTime'] = startTime;
      if (endTime != null) params['endTime'] = endTime;

      final response = await _dio.get<List<dynamic>>(
        '/trader/$authority/pnl',
        queryParameters: params,
      );
      return (response.data ?? [])
          .cast<Map<String, dynamic>>()
          .map(PhoenixPnlPoint.fromJson)
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      _logger.error('fetchTraderPnl failed', error: e, tag: 'Trader');
      return [];
    } catch (e) {
      _logger.error('fetchTraderPnl failed', error: e, tag: 'Trader');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  PhoenixTraderState _emptyState(String authority) => PhoenixTraderState(
    authority: authority,
    collateral: 0,
    availableMargin: 0,
    unrealizedPnl: 0,
    equity: 0,
    riskTier: 0,
    positions: const [],
    openOrders: const [],
    updatedAt: DateTime.now(),
    isRegistered: false,
  );
}
