import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/logger_service.dart';
import '../models/intelligence_models.dart';

final leaderDiscoveryServiceProvider =
    Provider<LeaderDiscoveryService>((ref) {
  final logger = ref.watch(loggerServiceProvider);
  return LeaderDiscoveryService(logger: logger);
});

/// Loads the curated trader list from assets, then enriches each address
/// with live stats from the public Phoenix API (no auth needed).
class LeaderDiscoveryService {
  final LoggerService _logger;
  late final Dio _dio;

  LeaderDiscoveryService({required LoggerService logger}) : _logger = logger {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.phoenixApiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  /// Load curated list, then fetch stats for each address in parallel.
  Future<List<LeaderProfile>> loadLeaders() async {
    final curated = await _loadCuratedList();
    // Fetch stats in parallel with a cap of 5 concurrent requests.
    final results = <LeaderProfile>[];
    const batchSize = 5;
    for (var i = 0; i < curated.length; i += batchSize) {
      final batch = curated.sublist(
        i,
        (i + batchSize).clamp(0, curated.length),
      );
      final fetched = await Future.wait(batch.map(_enrichLeader));
      results.addAll(fetched);
    }
    results.sort((a, b) => b.pnl7d.compareTo(a.pnl7d));
    return results;
  }

  Future<List<LeaderProfile>> _loadCuratedList() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/copy_traders.json',
      );
      final list = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      return list
          .map(
            (j) => LeaderProfile(
              address: j['address'] as String,
              label: j['label'] as String?,
              twitter: j['twitter'] as String?,
              isLoading: true,
            ),
          )
          .toList();
    } catch (e) {
      _logger.error('Failed to load curated list: $e', tag: '[Intelligence]');
      return [];
    }
  }

  Future<LeaderProfile> _enrichLeader(LeaderProfile base) async {
    try {
      final results = await Future.wait([
        _fetchPnl7d(base.address),
        _fetchTraderState(base.address),
        _fetchTradeHistory(base.address),
      ]);

      final pnl7d = results[0] as double;
      final positions = results[1] as List<LeaderPosition>;
      final (winRate, totalTrades) =
          results[2] as (double, int);

      return base.copyWith(
        pnl7d: pnl7d,
        openPositions: positions,
        winRate: winRate,
        totalTrades: totalTrades,
        isLoading: false,
      );
    } catch (e) {
      _logger.error(
        'Failed to enrich leader ${base.address}: $e',
        tag: '[Intelligence]',
      );
      return base.copyWith(isLoading: false);
    }
  }

  Future<double> _fetchPnl7d(String authority) async {
    try {
      final resp = await _dio.get(
        '/trader/$authority/pnl',
        queryParameters: {'resolution': '7d', 'limit': 1},
      );
      final data = resp.data;
      if (data is Map) {
        return (data['realized_pnl'] as num?)?.toDouble() ??
            (data['pnl'] as num?)?.toDouble() ??
            0;
      }
      if (data is List && data.isNotEmpty) {
        final entry = data.last as Map<String, dynamic>;
        return (entry['pnl'] as num?)?.toDouble() ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<LeaderPosition>> _fetchTraderState(String authority) async {
    try {
      final resp = await _dio.get('/trader/$authority/state');
      final data = resp.data as Map<String, dynamic>?;
      if (data == null) return [];
      final positions =
          (data['positions'] ?? data['trader_positions']) as List<dynamic>?;
      if (positions == null) return [];
      return positions
          .cast<Map<String, dynamic>>()
          .map(LeaderPosition.fromJson)
          .where((p) => p.size > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<(double, int)> _fetchTradeHistory(String authority) async {
    try {
      final resp = await _dio.get(
        '/trader/$authority/trades-history',
        queryParameters: {'limit': 50},
      );
      final data = resp.data;
      final trades = (data is List
              ? data
              : (data as Map<String, dynamic>?)?['trades'] as List?) ??
          [];
      if (trades.isEmpty) return (0.0, 0);
      int wins = 0;
      for (final t in trades) {
        final pnl = (t as Map<String, dynamic>?)?['realized_pnl'];
        if (pnl != null && (pnl as num) > 0) wins++;
      }
      final winRate = wins / trades.length;
      return (winRate, trades.length);
    } catch (_) {
      return (0.0, 0);
    }
  }

  /// Fetch current open positions for a single leader (used during polling).
  Future<List<LeaderPosition>> fetchPositions(String authority) =>
      _fetchTraderState(authority);
}
