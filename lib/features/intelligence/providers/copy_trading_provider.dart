import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/auth/client_auth_provider.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/phoenix/phoenix_order_service.dart';
import '../models/intelligence_models.dart';
import '../services/leader_discovery_service.dart';

final copyTradingProvider =
    NotifierProvider<CopyTradingNotifier, CopyTradingState>(
      CopyTradingNotifier.new,
    );

class CopyTradingNotifier extends Notifier<CopyTradingState> {
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 10);
  static const _followedKey = 'intelligence_followed_leaders';

  @override
  CopyTradingState build() {
    ref.onDispose(_stopPolling);
    // Load persisted followed list on init
    Future.microtask(_loadFollowed);
    return const CopyTradingState();
  }

  // ── Discovery ─────────────────────────────────────────────────────────────

  Future<void> loadDiscover() async {
    if (state.isLoadingDiscover) return;
    state = state.copyWith(isLoadingDiscover: true, clearError: true);
    try {
      final service = ref.read(leaderDiscoveryServiceProvider);
      final leaders = await service.loadLeaders();
      state = state.copyWith(discover: leaders, isLoadingDiscover: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingDiscover: false,
        error: 'Failed to load leaders: $e',
      );
    }
  }

  // ── Following ─────────────────────────────────────────────────────────────

  Future<void> followLeader(LeaderProfile leader, CopySettings settings) async {
    final alreadyFollowing = state.following.any(
      (f) => f.leader.address == leader.address,
    );
    if (alreadyFollowing) return;

    final followed = FollowedLeader(
      leader: leader,
      settings: settings,
      followedAt: DateTime.now(),
      lastKnownPositions: leader.openPositions,
    );
    state = state.copyWith(following: [...state.following, followed]);
    await _persistFollowed();

    if (!state.isPolling) _startPolling();
  }

  Future<LeaderProfile?> findLeader(String authority) async {
    if (state.isAddingLeader) return null;
    state = state.copyWith(isAddingLeader: true, clearError: true);
    try {
      final service = ref.read(leaderDiscoveryServiceProvider);
      final leader = await service.fetchLeaderProfile(authority);
      if (!leader.isRegistered) {
        state = state.copyWith(
          isAddingLeader: false,
          error: 'No Phoenix trader account found for that address.',
        );
        return null;
      }
      state = state.copyWith(isAddingLeader: false);
      return leader;
    } catch (e) {
      state = state.copyWith(isAddingLeader: false, error: e.toString());
      return null;
    }
  }

  Future<void> followAddress(String authority, CopySettings settings) async {
    final leader = await findLeader(authority);
    if (leader == null) return;
    await followLeader(leader, settings);
  }

  Future<void> unfollowLeader(String leaderAddress) async {
    state = state.copyWith(
      following: state.following
          .where((f) => f.leader.address != leaderAddress)
          .toList(),
    );
    await _persistFollowed();
    if (state.following.isEmpty) _stopPolling();
  }

  Future<void> pauseLeader(String leaderAddress, {required bool paused}) async {
    state = state.copyWith(
      following: state.following
          .map(
            (f) => f.leader.address == leaderAddress
                ? f.copyWith(isPaused: paused)
                : f,
          )
          .toList(),
    );
    await _persistFollowed();
  }

  Future<void> updateSettings(
    String leaderAddress,
    CopySettings newSettings,
  ) async {
    state = state.copyWith(
      following: state.following
          .map(
            (f) => f.leader.address == leaderAddress
                ? f.copyWith(settings: newSettings)
                : f,
          )
          .toList(),
    );
    await _persistFollowed();
  }

  // ── Polling ───────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    state = state.copyWith(isPolling: true);
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollLeaders());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (state.isPolling) state = state.copyWith(isPolling: false);
  }

  Future<void> _pollLeaders() async {
    final logger = ref.read(loggerServiceProvider);
    final discovery = ref.read(leaderDiscoveryServiceProvider);
    final orderService = ref.read(phoenixOrderServiceProvider);
    final walletAddress = ref.read(clientAuthProvider).walletAddress ?? '';

    if (walletAddress.isEmpty) return;

    final updatedFollowed = <FollowedLeader>[];
    for (final followed in state.following) {
      if (followed.isPaused) {
        updatedFollowed.add(followed);
        continue;
      }
      try {
        final newPositions = await discovery.fetchPositions(
          followed.leader.address,
        );

        final diff = _detectPositionChanges(
          previous: followed.lastKnownPositions,
          current: newPositions,
        );

        for (final change in diff) {
          logger.info(
            'Copy trade: ${change.side} ${change.market} for ${followed.leader.displayLabel}',
            tag: '[CopyTrade]',
          );
          await _mirrorTrade(
            change: change,
            settings: followed.settings,
            walletAddress: walletAddress,
            orderService: orderService,
            logger: logger,
          );
        }

        updatedFollowed.add(
          followed.copyWith(lastKnownPositions: newPositions),
        );
      } catch (e) {
        logger.error(
          'Poll error for ${followed.leader.address}: $e',
          tag: '[CopyTrade]',
        );
        updatedFollowed.add(followed);
      }
    }
    state = state.copyWith(following: updatedFollowed);
  }

  List<_PositionChange> _detectPositionChanges({
    required List<LeaderPosition> previous,
    required List<LeaderPosition> current,
  }) {
    final changes = <_PositionChange>[];
    final prevMap = {for (final p in previous) p.market: p};
    final currMap = {for (final p in current) p.market: p};

    // Opened positions (not in previous or increased significantly)
    for (final curr in current) {
      final prev = prevMap[curr.market];
      if (prev == null) {
        changes.add(
          _PositionChange(
            market: curr.market,
            side: curr.side,
            type: _ChangeType.opened,
            position: curr,
          ),
        );
      } else if ((curr.size - prev.size).abs() / prev.size > 0.1) {
        changes.add(
          _PositionChange(
            market: curr.market,
            side: curr.side,
            type: _ChangeType.increased,
            position: curr,
          ),
        );
      }
    }

    // Closed positions
    for (final prev in previous) {
      if (!currMap.containsKey(prev.market)) {
        changes.add(
          _PositionChange(
            market: prev.market,
            side: prev.side,
            type: _ChangeType.closed,
            position: prev,
          ),
        );
      }
    }
    return changes;
  }

  Future<void> _mirrorTrade({
    required _PositionChange change,
    required CopySettings settings,
    required String walletAddress,
    required PhoenixOrderService orderService,
    required LoggerService logger,
  }) async {
    if (change.type == _ChangeType.closed) {
      // Close our position: reverse the side
      final closeSide = change.side == 'long' ? 'sell' : 'buy';
      await orderService.placeMarketOrder(
        authority: walletAddress,
        symbol: change.market,
        side: closeSide,
        quantity: change.position.size,
      );
    } else {
      // Open / increase
      final openSide = change.side == 'long' ? 'buy' : 'sell';
      // Size in USDC notional / entry price = base units
      final quantity =
          settings.copyUSDC /
          (change.position.entryPrice > 0 ? change.position.entryPrice : 1);
      final stopLoss = change.position.entryPrice > 0
          ? change.position.entryPrice *
                (change.side == 'long'
                    ? 1 - settings.stopLossRatio
                    : 1 + settings.stopLossRatio)
          : null;
      final transferMicro = (settings.copyUSDC * 1e6).toInt();

      await orderService.placeMarketOrder(
        authority: walletAddress,
        symbol: change.market,
        side: openSide,
        quantity: quantity,
        transferAmountUsdc: transferMicro,
        stopLossPrice: stopLoss,
        slippageBps: (settings.maxSlippage * 10000).toInt(),
      );
    }
    logger.info(
      'Mirrored ${change.type.name} on ${change.market}',
      tag: '[CopyTrade]',
    );
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _persistFollowed() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(
      state.following
          .map(
            (f) => {
              'address': f.leader.address,
              'label': f.leader.label,
              'twitter': f.leader.twitter,
              ...f.toJson(),
            },
          )
          .toList(),
    );
    await prefs.setString(_followedKey, json);
  }

  Future<void> _loadFollowed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_followedKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final followed = list.map((j) {
        final profile = LeaderProfile(
          address: j['address'] as String,
          label: j['label'] as String?,
          twitter: j['twitter'] as String?,
        );
        return FollowedLeader.fromJson(j, profile);
      }).toList();
      state = state.copyWith(following: followed);
      if (followed.isNotEmpty) _startPolling();
      Future.microtask(_refreshFollowingProfiles);
    } catch (e) {
      ref
          .read(loggerServiceProvider)
          .error('Failed to load followed leaders: $e', tag: '[CopyTrade]');
    }
  }

  Future<void> _refreshFollowingProfiles() async {
    if (state.following.isEmpty) return;
    final service = ref.read(leaderDiscoveryServiceProvider);
    final refreshed = <FollowedLeader>[];
    for (final followed in state.following) {
      try {
        final profile = await service.fetchLeaderProfile(
          followed.leader.address,
          label: followed.leader.label,
        );
        refreshed.add(
          followed.copyWith(
            leader: profile,
            lastKnownPositions: profile.openPositions,
          ),
        );
      } catch (_) {
        refreshed.add(followed);
      }
    }
    state = state.copyWith(following: refreshed);
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

enum _ChangeType { opened, increased, closed }

class _PositionChange {
  final String market;
  final String side;
  final _ChangeType type;
  final LeaderPosition position;

  const _PositionChange({
    required this.market,
    required this.side,
    required this.type,
    required this.position,
  });
}
