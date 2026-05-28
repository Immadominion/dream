import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../models/phoenix/phoenix_models.dart';
import '../logger_service.dart';

final phoenixTraderServiceProvider = Provider<PhoenixTraderService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  return PhoenixTraderService(logger: logger);
});

/// Handles trader-specific Phoenix endpoints (public read, authenticated writes).
///
/// GET /trader/{authority}/state is public — no auth required.
/// Order endpoints require Phoenix JWT (handled by phoenix_order_service).
class PhoenixTraderService {
  final LoggerService _logger;
  late final Dio _dio;

  PhoenixTraderService({required LoggerService logger}) : _logger = logger {
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
  /// Uses the primary cross account `(traderPdaIndex=0, traderSubaccountIndex=0)`
  /// for collateral/margin fields, while aggregating positions and resting orders
  /// across all returned trader views so isolated subaccounts remain visible.
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

      final primaryTraderView = selectPrimaryCrossTraderView(traders);
      final mergedTraderView = mergeTraderViews(
        primaryTraderView: primaryTraderView,
        traders: traders,
      );
      return PhoenixTraderState.fromApiJson(mergedTraderView, authority);
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
      final response = await _dio.get<dynamic>(
        '/trader/$authority/trades-history',
        queryParameters: {'limit': limit},
      );
      return _extractHistoryRows(
        response.data,
      ).map(PhoenixTradeHistoryItem.fromJson).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return []; // new wallet — no history yet
      }
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
      final response = await _dio.get<dynamic>(
        '/trader/$authority/funding-history',
        queryParameters: {'limit': limit},
      );
      return _extractHistoryRows(
        response.data,
      ).map(_normalizeFundingHistoryRow).toList(growable: false);
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
      final response = await _dio.get<dynamic>(
        '/trader/$authority/collateral-history',
        queryParameters: {'limit': limit},
      );
      return _extractHistoryRows(
        response.data,
      ).map(_normalizeCollateralHistoryRow).toList(growable: false);
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
      final response = await _dio.get<dynamic>(
        '/trader/$authority/order-history',
        queryParameters: {'limit': limit},
      );
      return _extractHistoryRows(response.data);
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

@visibleForTesting
Map<String, dynamic> selectPrimaryCrossTraderView(List<dynamic> traders) {
  final typedTraders = traders.whereType<Map<String, dynamic>>().toList();
  if (typedTraders.isEmpty) {
    throw StateError('Phoenix trader response contained no trader objects');
  }

  return typedTraders.firstWhere(
    (trader) =>
        _toInt(trader['traderPdaIndex']) == 0 &&
        _toInt(trader['traderSubaccountIndex']) == 0,
    orElse: () => typedTraders.firstWhere(
      (trader) => _toInt(trader['traderSubaccountIndex']) == 0,
      orElse: () => typedTraders.first,
    ),
  );
}

@visibleForTesting
Map<String, dynamic> mergeTraderViews({
  required Map<String, dynamic> primaryTraderView,
  required List<dynamic> traders,
}) {
  final typedTraders = traders.whereType<Map<String, dynamic>>().toList();
  final merged = Map<String, dynamic>.from(primaryTraderView);
  final mergedPositions = <dynamic>[];
  final mergedLimitOrders = <String, List<dynamic>>{};
  var totalUnrealizedPnl = 0.0;

  for (final trader in typedTraders) {
    mergedPositions.addAll((trader['positions'] as List<dynamic>?) ?? const []);

    final limitOrders = Map<String, dynamic>.from(
      (trader['limitOrders'] as Map?) ?? const {},
    );
    for (final entry in limitOrders.entries) {
      mergedLimitOrders
          .putIfAbsent(entry.key, () => <dynamic>[])
          .addAll((entry.value as List<dynamic>?) ?? const []);
    }

    totalUnrealizedPnl += _toDoubleLike(trader['unrealizedPnl']);
  }

  merged['positions'] = mergedPositions;
  merged['limitOrders'] = mergedLimitOrders.map(
    (symbol, orders) => MapEntry(symbol, List<dynamic>.from(orders)),
  );
  merged['unrealizedPnl'] = totalUnrealizedPnl;
  return merged;
}

@visibleForTesting
List<Map<String, dynamic>> extractPhoenixHistoryRows(dynamic payload) {
  return _extractHistoryRows(payload);
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<Map<String, dynamic>> _extractHistoryRows(dynamic payload) {
  if (payload is List) {
    return payload.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  if (payload is Map<String, dynamic>) {
    for (final key in const ['data', 'events']) {
      final value = payload[key];
      if (value is List) {
        return value.whereType<Map<String, dynamic>>().toList(growable: false);
      }
    }
  }

  return const [];
}

Map<String, dynamic> _normalizeFundingHistoryRow(Map<String, dynamic> row) {
  return {
    ...row,
    'symbol': row['symbol'] ?? row['marketSymbol'],
    'amount': _toDoubleLike(row['fundingPayment'] ?? row['amount']),
    'ratePct': _toDoubleLike(
      row['fundingRatePercentage'] ?? row['fundingRate'] ?? row['rate'],
    ),
    'positionSize': _toDoubleLike(row['positionSize'] ?? row['size']),
    'positionSide': row['positionSide'] ?? row['side'],
    'timestamp': row['timestamp'] ?? row['createdAt'] ?? row['time'],
  };
}

Map<String, dynamic> _normalizeCollateralHistoryRow(Map<String, dynamic> row) {
  return {
    ...row,
    'amount': _toUiAmount(row['amount']),
    'collateralAfter': _toUiAmount(row['collateralAfter']),
    'timestamp': row['timestamp'] ?? row['createdAt'] ?? row['time'],
  };
}

double _toUiAmount(dynamic value, {int decimals = 6}) {
  if (value == null) return 0.0;
  if (value is Map<String, dynamic>) return _toDoubleLike(value);

  final parsed = _toDoubleLike(value);
  if (parsed.abs() >= 1000) {
    return parsed / math.pow(10, decimals);
  }
  return parsed;
}

double _toDoubleLike(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  if (value is Map<String, dynamic>) {
    final ui = value['ui'] ?? value['uiAmount'] ?? value['ui_amount'];
    if (ui != null) {
      return _toDoubleLike(ui);
    }

    final rawValue = value['value'] ?? value['amount'];
    final decimals = value['decimals'];
    if (rawValue != null && decimals is num) {
      final parsedRaw = _toDoubleLike(rawValue);
      return parsedRaw / math.pow(10, decimals.toInt());
    }
  }
  return 0.0;
}
