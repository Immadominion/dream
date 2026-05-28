import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/logger_service.dart';
import '../models/intelligence_models.dart';

final leaderDiscoveryServiceProvider = Provider<LeaderDiscoveryService>((ref) {
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
    if (curated.isEmpty) return [];
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

  /// Fetch and verify one Phoenix trader authority entered by the user.
  Future<LeaderProfile> fetchLeaderProfile(
    String authority, {
    String? label,
  }) async {
    final trimmed = authority.trim();
    if (trimmed.length < 32) {
      throw ArgumentError('Enter a valid Solana wallet address.');
    }

    return _enrichLeader(
      LeaderProfile(address: trimmed, label: label, isLoading: true),
    );
  }

  Future<List<LeaderProfile>> _loadCuratedList() async {
    try {
      final raw = await rootBundle.loadString('assets/data/copy_traders.json');
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

      final pnl = results[0] as _PnlSnapshot;
      final trader = results[1] as _TraderSnapshot;
      final trades = results[2] as _TradeStats;

      return base.copyWith(
        pnl7d: pnl.pnl7d,
        hasPnlHistory: pnl.hasHistory,
        openPositions: trader.positions,
        collateral: trader.collateral,
        equity: trader.equity,
        openNotional: trader.openNotional,
        isRegistered: trader.isRegistered,
        winRate: trades.winRate,
        totalTrades: trades.totalTrades,
        lastTradeAt: trades.lastTradeAt,
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

  Future<_PnlSnapshot> _fetchPnl7d(String authority) async {
    try {
      final resp = await _dio.get(
        '/trader/$authority/pnl',
        queryParameters: {
          'resolution': '1d',
          'limit': 8,
          'includeEarliest': true,
          'includeLatest': true,
        },
      );
      final data = resp.data;
      if (data is! List || data.isEmpty) return const _PnlSnapshot();

      double total(Map<String, dynamic> point) =>
          _toDouble(point['cumulativePnl']) + _toDouble(point['unrealizedPnl']);

      final points = data.cast<Map<String, dynamic>>();
      if (points.length == 1) {
        return _PnlSnapshot(pnl7d: total(points.first), hasHistory: true);
      }

      final pnl7d = total(points.last) - total(points.first);
      return _PnlSnapshot(pnl7d: pnl7d, hasHistory: true);
    } catch (_) {
      return const _PnlSnapshot();
    }
  }

  Future<_TraderSnapshot> _fetchTraderState(String authority) async {
    try {
      final resp = await _dio.get('/trader/$authority/state');
      final data = resp.data as Map<String, dynamic>?;
      if (data == null) return const _TraderSnapshot();

      final traders = data['traders'] as List<dynamic>? ?? [];
      if (traders.isEmpty) return const _TraderSnapshot();

      final trader = traders.first as Map<String, dynamic>;
      final positions = (trader['positions'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(LeaderPosition.fromJson)
          .where((p) => p.size > 0)
          .toList();

      return _TraderSnapshot(
        positions: positions,
        collateral: _toDouble(trader['collateralBalance']),
        equity: _toDouble(trader['portfolioValue']),
        openNotional: positions.fold<double>(
          0,
          (sum, position) => sum + (position.size * position.entryPrice),
        ),
        isRegistered: true,
      );
    } catch (_) {
      return const _TraderSnapshot();
    }
  }

  Future<_TradeStats> _fetchTradeHistory(String authority) async {
    try {
      final resp = await _dio.get(
        '/trader/$authority/trades-history',
        queryParameters: {'limit': 50},
      );
      final data = resp.data;
      final trades =
          (data is List ? data : (data as Map<String, dynamic>?)?['data'])
              as List? ??
          [];
      if (trades.isEmpty) return const _TradeStats();

      int wins = 0;
      DateTime? lastTradeAt;
      for (final t in trades) {
        final trade = t as Map<String, dynamic>?;
        if (trade == null) continue;
        final pnl = _toDouble(trade['realizedPnl'] ?? trade['realized_pnl']);
        if (pnl > 0) wins++;
        final ts = DateTime.tryParse(trade['timestamp']?.toString() ?? '');
        if (ts != null && (lastTradeAt == null || ts.isAfter(lastTradeAt))) {
          lastTradeAt = ts;
        }
      }
      final winRate = wins / trades.length;
      return _TradeStats(
        winRate: winRate,
        totalTrades: trades.length,
        lastTradeAt: lastTradeAt,
      );
    } catch (_) {
      return const _TradeStats();
    }
  }

  /// Fetch current open positions for a single leader (used during polling).
  Future<List<LeaderPosition>> fetchPositions(String authority) async =>
      (await _fetchTraderState(authority)).positions;
}

class _PnlSnapshot {
  final double pnl7d;
  final bool hasHistory;

  const _PnlSnapshot({this.pnl7d = 0, this.hasHistory = false});
}

class _TraderSnapshot {
  final List<LeaderPosition> positions;
  final double collateral;
  final double equity;
  final double openNotional;
  final bool isRegistered;

  const _TraderSnapshot({
    this.positions = const [],
    this.collateral = 0,
    this.equity = 0,
    this.openNotional = 0,
    this.isRegistered = false,
  });
}

class _TradeStats {
  final double winRate;
  final int totalTrades;
  final DateTime? lastTradeAt;

  const _TradeStats({this.winRate = 0, this.totalTrades = 0, this.lastTradeAt});
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
