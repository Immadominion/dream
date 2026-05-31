import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/phoenix/phoenix_trader_models.dart';
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
  late final Dio _phoenixDio;
  late final Dio _workerDio;

  LeaderDiscoveryService({required LoggerService logger}) : _logger = logger {
    _phoenixDio = Dio(
      BaseOptions(
        baseUrl: AppConstants.phoenixApiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    _workerDio = Dio(
      BaseOptions(
        baseUrl: AppConstants.dreamServerUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
      ),
    );
  }

  /// Load live broadcaster list from the worker, then enrich each address with
  /// Phoenix trader stats.
  Future<List<LeaderProfile>> loadLeaders({String sort = 'earnings'}) async {
    final broadcasters = await _loadBroadcasters(sort: sort);
    if (broadcasters.isEmpty) return [];
    // Fetch stats in parallel with a cap of 5 concurrent requests.
    final results = <LeaderProfile>[];
    const batchSize = 5;
    for (var i = 0; i < broadcasters.length; i += batchSize) {
      final batch = broadcasters.sublist(
        i,
        (i + batchSize).clamp(0, broadcasters.length),
      );
      final fetched = await Future.wait(batch.map(_enrichLeader));
      results.addAll(fetched);
    }
    results.sort((a, b) {
      switch (sort) {
        case 'pnl':
          return b.pnl7d.compareTo(a.pnl7d);
        case 'copiers':
          final cmp = b.copierCount.compareTo(a.copierCount);
          return cmp != 0 ? cmp : b.lifetimeUsd.compareTo(a.lifetimeUsd);
        case 'earnings':
        default:
          final earningsCmp = b.lifetimeUsd.compareTo(a.lifetimeUsd);
          return earningsCmp != 0 ? earningsCmp : b.pnl7d.compareTo(a.pnl7d);
      }
    });
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

  Future<List<LeaderProfile>> _loadBroadcasters({
    String sort = 'earnings',
  }) async {
    try {
      final resp = await _workerDio.get(
        '/v1/broadcasters',
        queryParameters: {'limit': 50, 'sort': sort},
      );
      final data = resp.data as Map<String, dynamic>?;
      final list = (data?['broadcasters'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      return list
          .map(
            (j) => LeaderProfile(
              address: j['address'] as String,
              label: j['displayName'] as String?,
              twitter: j['twitter'] as String?,
              strategy: j['strategy'] as String?,
              isBroadcaster: true,
              copierCount: (j['copierCount'] as num?)?.toInt() ?? 0,
              lifetimeUsd: (j['lifetimeUsd'] as num?)?.toDouble() ?? 0,
              isLoading: true,
            ),
          )
          .toList();
    } catch (e) {
      _logger.error('Failed to load broadcasters: $e', tag: '[Intelligence]');
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
      final resp = await _phoenixDio.get(
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
      final resp = await _phoenixDio.get('/trader/$authority/state');
      final data = resp.data as Map<String, dynamic>?;
      if (data == null) return const _TraderSnapshot();

      final traders = data['traders'] as List<dynamic>? ?? [];
      if (traders.isEmpty) return const _TraderSnapshot();

      final primaryTraderView = _selectPrimaryCrossTraderView(traders);
      final mergedTraderView = _mergeTraderViews(
        primaryTraderView: primaryTraderView,
        traders: traders,
      );
      final traderState = PhoenixTraderState.fromApiJson(
        mergedTraderView,
        authority,
      );
      final positions = traderState.positions
          .where((p) => p.sizeBase > 0)
          .map(
            (p) => LeaderPosition(
              market: p.symbol,
              side: p.side,
              size: p.sizeBase,
              entryPrice: p.entryPrice,
              unrealizedPnl: p.unrealizedPnl,
            ),
          )
          .toList();

      return _TraderSnapshot(
        positions: positions,
        collateral: traderState.collateral,
        equity: traderState.equity,
        openNotional: traderState.positions.fold<double>(
          0,
          (sum, position) => sum + position.sizeUsd,
        ),
        isRegistered: true,
      );
    } catch (_) {
      return const _TraderSnapshot();
    }
  }

  Future<_TradeStats> _fetchTradeHistory(String authority) async {
    try {
      final resp = await _phoenixDio.get(
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
  if (value is Map<String, dynamic>) {
    final ui = value['ui'] ?? value['uiAmount'] ?? value['ui_amount'];
    if (ui != null) {
      return _toDouble(ui);
    }

    final rawValue = value['value'] ?? value['amount'];
    final decimals = value['decimals'];
    if (rawValue != null && decimals is num) {
      return _toDouble(rawValue) / math.pow(10, decimals.toInt());
    }
  }
  return 0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Map<String, dynamic> _selectPrimaryCrossTraderView(List<dynamic> traders) {
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

Map<String, dynamic> _mergeTraderViews({
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

    totalUnrealizedPnl += _toDouble(trader['unrealizedPnl']);
  }

  merged['positions'] = mergedPositions;
  merged['limitOrders'] = mergedLimitOrders.map(
    (symbol, orders) => MapEntry(symbol, List<dynamic>.from(orders)),
  );
  merged['unrealizedPnl'] = totalUnrealizedPnl;
  return merged;
}
