import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/auth/client_auth_provider.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/phoenix/phoenix_auth_service.dart';
import '../../../core/services/phoenix/phoenix_websocket_service.dart';
import '../../../core/services/wallet/privy_wallet_manager.dart';
import '../models/intelligence_models.dart';
import '../services/ai_proxy_service.dart';
import '../services/copy_engine_service.dart';
import '../services/intelligence_payment_service.dart';
import '../services/leader_discovery_service.dart';

final copyTradingProvider =
    NotifierProvider<CopyTradingNotifier, CopyTradingState>(
      CopyTradingNotifier.new,
    );

/// Drives the always-on copy engine entirely server-side. The Flutter client
/// only:
///  1. captures on-device consent (Privy `addSigner`) so dream-server can sign
///     mirrors while the app is closed,
///  2. registers/enables/disables leader subscriptions on the server, and
///  3. reflects server state (subscriptions + points) for the UI.
///
/// There is NO on-device trade mirroring — the backend polls leaders and
/// executes mirrors continuously regardless of whether the app is running.
class CopyTradingNotifier extends Notifier<CopyTradingState> {
  static const _followedKey = 'intelligence_followed_leaders';
  static const _legacySignerAttachedKey = 'copy_signer_attached';
  static const _signerAttachedKeyPrefix = 'copy_signer_attached_v2';
  static const _refreshFallbackInterval = Duration(seconds: 8);
  static const _embeddedWalletOnlyMessage =
      'Copy trading automation is only available with Dream embedded wallets. '
      'Sign in with email or social to use it.';

  StreamSubscription<TraderStateMessage>? _wsSub;
  Timer? _wsRefreshDebounce;
  Timer? _pollTimer;
  Set<String> _watchedAuthorities = <String>{};

  @override
  CopyTradingState build() {
    ref.onDispose(_dispose);

    // Fast first paint from the local cache, then reconcile with the server.
    Future.microtask(_loadFollowed);
    Future.microtask(_syncFromServer);
    return const CopyTradingState();
  }

  bool _isExternalWalletSignIn() {
    return ref.read(phoenixAuthServiceProvider).persistedWalletType == 'mwa';
  }

  bool _requireEmbeddedWallet() {
    if (!_isExternalWalletSignIn()) return true;

    ref
        .read(loggerServiceProvider)
        .warning(
          'Blocked copy-trading action for external wallet sign-in',
          tag: '[CopyTrade]',
        );
    state = state.copyWith(error: _embeddedWalletOnlyMessage);
    return false;
  }

  // ── Points (Postgres source of truth) ──────────────────────────────────────

  /// Pulls the authoritative global points balance from dream-server.
  Future<void> _loadPointsFromServer() async {
    final wallet = ref.read(clientAuthProvider).walletAddress;
    if (wallet == null || wallet.isEmpty) {
      state = state.copyWith(pointsLoaded: true);
      return;
    }
    try {
      final points = await ref
          .read(copyEngineServiceProvider)
          .fetchPoints(wallet);
      state = state.copyWith(points: points, pointsLoaded: true);
    } catch (e) {
      ref
          .read(loggerServiceProvider)
          .error('Failed to load copy points: $e', tag: '[CopyTrade]');
      state = state.copyWith(pointsLoaded: true);
    }
  }

  /// Purchase credits via on-chain SOL payment. The payment is verified and
  /// credited by dream-server (Postgres is the source of truth); the returned
  /// balance replaces the local one.
  Future<void> purchaseCredits(CreditTier tier) async {
    if (!_requireEmbeddedWallet()) return;
    state = state.copyWith(isBuying: true, clearError: true);
    final wallet = ref.read(clientAuthProvider).walletAddress ?? '';
    if (wallet.isEmpty) {
      state = state.copyWith(isBuying: false, error: 'Connect a wallet first.');
      return;
    }
    try {
      final paymentService = ref.read(intelligencePaymentServiceProvider);
      final txSig = await paymentService.purchaseCredits(tier);

      final newBalance = await ref
          .read(copyEngineServiceProvider)
          .creditPurchase(walletAddress: wallet, txSignature: txSig);

      state = state.copyWith(points: newBalance, isBuying: false);
      ref
          .read(loggerServiceProvider)
          .info(
            'Credits purchased (tx: $txSig) → $newBalance',
            tag: '[Credits]',
          );
    } catch (e) {
      state = state.copyWith(isBuying: false, error: e.toString());
    }
  }

  // ── Discovery ─────────────────────────────────────────────────────────────

  Future<void> loadDiscover({String sort = 'earnings'}) async {
    if (state.isLoadingDiscover) return;
    state = state.copyWith(isLoadingDiscover: true, clearError: true);
    try {
      final service = ref.read(leaderDiscoveryServiceProvider);
      final leaders = await service.loadLeaders(sort: sort);
      state = state.copyWith(discover: leaders, isLoadingDiscover: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingDiscover: false,
        error: 'Failed to load leaders: $e',
      );
    }
  }

  Future<void> refreshMyBroadcaster() async {
    final wallet = ref.read(clientAuthProvider).walletAddress ?? '';
    if (wallet.isEmpty) {
      state = state.copyWith(clearMyBroadcaster: true);
      return;
    }

    state = state.copyWith(isLoadingBroadcaster: true, clearError: true);
    try {
      final ai = ref.read(aiProxyServiceProvider);
      final me = await ai.fetchMyBroadcaster(wallet);
      if (me == null) {
        state = state.copyWith(
          clearMyBroadcaster: true,
          isLoadingBroadcaster: false,
        );
        return;
      }

      state = state.copyWith(
        myBroadcaster: LeaderProfile(
          address: me.address,
          label: me.displayName,
          strategy: me.strategy,
          twitter: me.twitter,
          isBroadcaster: true,
          copierCount: me.copierCount,
          lifetimeUsd: me.lifetimeUsd,
          isRegistered: true,
        ),
        isLoadingBroadcaster: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingBroadcaster: false);
    }
  }

  Future<void> registerAsBroadcaster({
    required String displayName,
    String? strategy,
    String? twitter,
  }) async {
    final wallet = ref.read(clientAuthProvider).walletAddress ?? '';
    if (wallet.isEmpty) {
      state = state.copyWith(error: 'Connect wallet before broadcasting.');
      return;
    }

    state = state.copyWith(isRegisteringBroadcaster: true, clearError: true);
    try {
      await ref
          .read(aiProxyServiceProvider)
          .registerBroadcaster(
            walletAddress: wallet,
            displayName: displayName.trim(),
            strategy: strategy?.trim().isEmpty ?? true
                ? null
                : strategy?.trim(),
            twitter: twitter?.trim().isEmpty ?? true ? null : twitter?.trim(),
          );

      await refreshMyBroadcaster();
      state = state.copyWith(isRegisteringBroadcaster: false);
    } catch (e) {
      state = state.copyWith(
        isRegisteringBroadcaster: false,
        error: 'Failed to register broadcaster: $e',
      );
    }
  }

  /// Fetches the broadcaster's USD earnings history + aggregate stats.
  Future<BroadcasterEarnings?> fetchBroadcasterEarnings() async {
    final wallet = ref.read(clientAuthProvider).walletAddress ?? '';
    if (wallet.isEmpty) return null;
    return ref.read(aiProxyServiceProvider).fetchBroadcasterEarnings(wallet);
  }

  /// Fetches the broadcaster's own Phoenix trading stats (PnL, win rate).
  Future<LeaderProfile?> fetchMyTradingStats() async {
    final wallet = ref.read(clientAuthProvider).walletAddress ?? '';
    if (wallet.isEmpty) return null;
    try {
      return await ref
          .read(leaderDiscoveryServiceProvider)
          .fetchLeaderProfile(wallet, label: 'You');
    } catch (_) {
      return null;
    }
  }

  /// Requests a USDC payout of the full claimable balance. Returns the
  /// requested amount; throws [PayoutException] when below the minimum.
  Future<double> requestPayout() async {
    final wallet = ref.read(clientAuthProvider).walletAddress ?? '';
    if (wallet.isEmpty) {
      throw Exception('Connect wallet before requesting a payout.');
    }
    final amount = await ref.read(aiProxyServiceProvider).requestPayout(wallet);
    await refreshMyBroadcaster();
    return amount;
  }

  // ── Following (server-driven) ──────────────────────────────────────────────

  /// Ensures the embedded wallet has delegated the dream-server signer and is
  /// registered on the backend. Captures on-device consent (Privy `addSigner`)
  /// once, then registers the signer so the server can mirror while offline.
  /// Returns the Privy wallet id used for server signing, or null on failure.
  Future<String?> _ensureServerSigner(String walletAddress) async {
    final logger = ref.read(loggerServiceProvider);
    final engine = ref.read(copyEngineServiceProvider);
    final privyWallet = ref.read(privyWalletManagerProvider);

    final privyWalletId = await privyWallet.getWalletId();
    if (privyWalletId == null || privyWalletId.isEmpty) {
      state = state.copyWith(
        error: 'No embedded wallet available to delegate.',
      );
      return null;
    }

    final signerConfig = await engine.fetchSignerConfig(walletAddress);
    if (!signerConfig.isConfigured) {
      state = state.copyWith(
        error: 'Copy trading is not available yet. Please try again later.',
      );
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final attachedKey = _signerAttachmentKey(
      walletAddress: walletAddress,
      signerId: signerConfig.signerId,
      policyIds: signerConfig.policyIds,
    );
    final alreadyAttached = prefs.getBool(attachedKey) ?? false;

    if (!alreadyAttached) {
      final attached = await privyWallet.attachServerSigner(
        signerId: signerConfig.signerId,
        policyIds: signerConfig.policyIds,
      );
      if (!attached) {
        state = state.copyWith(
          error: 'Could not authorize automated copying. Please try again.',
        );
        return null;
      }
      await prefs.remove(_legacySignerAttachedKey);
      await prefs.setBool(attachedKey, true);
      logger.info('Server signer attached on-device', tag: '[CopyTrade]');
    }

    // Register (idempotent server-side) and sync the granted points balance.
    final points = await engine.registerSigner(
      walletAddress: walletAddress,
      privyWalletId: privyWalletId,
    );
    state = state.copyWith(points: points, pointsLoaded: true);
    return privyWalletId;
  }

  Future<void> followLeader(LeaderProfile leader, CopySettings settings) async {
    if (!_requireEmbeddedWallet()) return;

    final alreadyFollowing = state.following.any(
      (f) => f.leader.address == leader.address,
    );
    if (alreadyFollowing) return;

    final walletAddress = ref.read(clientAuthProvider).walletAddress ?? '';
    if (walletAddress.isEmpty) {
      state = state.copyWith(error: 'Connect a wallet first.');
      return;
    }

    state = state.copyWith(isAddingLeader: true, clearError: true);
    try {
      final privyWalletId = await _ensureServerSigner(walletAddress);
      if (privyWalletId == null) {
        state = state.copyWith(isAddingLeader: false);
        return;
      }

      await ref
          .read(copyEngineServiceProvider)
          .enable(
            walletAddress: walletAddress,
            leaderWallet: leader.address,
            settings: settings,
            privyWalletId: privyWalletId,
          );

      final followed = FollowedLeader(
        leader: leader,
        settings: settings,
        followedAt: DateTime.now(),
        lastKnownPositions: leader.openPositions,
      );
      state = state.copyWith(
        following: [...state.following, followed],
        isAddingLeader: false,
      );
      _syncLeaderRealtime();
      await _persistFollowed();

      ref
          .read(loggerServiceProvider)
          .info(
            'Server now mirroring ${leader.displayLabel} (${leader.address})',
            tag: '[CopyTrade]',
          );
    } catch (e) {
      ref
          .read(loggerServiceProvider)
          .error(
            'Failed to enable copy of ${leader.address}: $e',
            tag: '[CopyTrade]',
          );
      state = state.copyWith(
        isAddingLeader: false,
        error: 'Could not start copying — please try again.',
      );
    }
  }

  Future<LeaderProfile?> findLeader(String authority) async {
    if (state.isAddingLeader) return null;
    if (!_requireEmbeddedWallet()) return null;

    // Guard against self-follow: copy trading mirrors another trader's
    // positions onto your wallet. Following your own wallet is a no-op (there
    // is no separate leader to copy) and was the silent failure mode here.
    final myWallet = ref.read(clientAuthProvider).walletAddress;
    if (myWallet != null && myWallet == authority.trim()) {
      ref
          .read(loggerServiceProvider)
          .warning(
            'Blocked self-follow attempt for $authority',
            tag: '[CopyTrade]',
          );
      state = state.copyWith(
        error: "That's your own wallet — copy a different trader to mirror.",
      );
      return null;
    }

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
    final walletAddress = ref.read(clientAuthProvider).walletAddress ?? '';
    final previous = state.following;
    state = state.copyWith(
      following: previous
          .where((f) => f.leader.address != leaderAddress)
          .toList(),
    );
    _syncLeaderRealtime();
    await _persistFollowed();

    if (walletAddress.isNotEmpty) {
      try {
        await ref
            .read(copyEngineServiceProvider)
            .disable(walletAddress: walletAddress, leaderWallet: leaderAddress);
      } catch (e) {
        ref
            .read(loggerServiceProvider)
            .error(
              'Failed to disable copy of $leaderAddress: $e',
              tag: '[CopyTrade]',
            );
        // Restore the optimistic removal so the UI matches the server.
        state = state.copyWith(following: previous);
        _syncLeaderRealtime();
        await _persistFollowed();
        state = state.copyWith(
          error: 'Could not stop copying — please try again.',
        );
      }
    }
  }

  Future<void> pauseLeader(String leaderAddress, {required bool paused}) async {
    final walletAddress = ref.read(clientAuthProvider).walletAddress ?? '';
    final previous = state.following;
    state = state.copyWith(
      following: previous
          .map(
            (f) => f.leader.address == leaderAddress
                ? f.copyWith(isPaused: paused)
                : f,
          )
          .toList(),
    );
    _syncLeaderRealtime();
    await _persistFollowed();
    if (walletAddress.isEmpty) return;

    try {
      final engine = ref.read(copyEngineServiceProvider);
      if (paused) {
        await engine.disable(
          walletAddress: walletAddress,
          leaderWallet: leaderAddress,
        );
      } else {
        final followed = state.following.firstWhere(
          (f) => f.leader.address == leaderAddress,
        );
        final privyWalletId = await _ensureServerSigner(walletAddress);
        await engine.enable(
          walletAddress: walletAddress,
          leaderWallet: leaderAddress,
          settings: followed.settings,
          privyWalletId: privyWalletId,
        );
      }
    } catch (e) {
      ref
          .read(loggerServiceProvider)
          .error(
            'Failed to ${paused ? 'pause' : 'resume'} $leaderAddress: $e',
            tag: '[CopyTrade]',
          );
      state = state.copyWith(following: previous);
      _syncLeaderRealtime();
      await _persistFollowed();
      state = state.copyWith(error: 'Could not update copying — try again.');
    }
  }

  Future<void> updateSettings(
    String leaderAddress,
    CopySettings newSettings,
  ) async {
    final walletAddress = ref.read(clientAuthProvider).walletAddress ?? '';
    final previous = state.following;
    state = state.copyWith(
      following: previous
          .map(
            (f) => f.leader.address == leaderAddress
                ? f.copyWith(settings: newSettings)
                : f,
          )
          .toList(),
    );
    await _persistFollowed();
    if (walletAddress.isEmpty) return;

    // Skip pushing settings for paused leaders — re-enabling is handled by
    // pauseLeader so we don't silently resume a paused subscription.
    final followed = state.following.firstWhere(
      (f) => f.leader.address == leaderAddress,
      orElse: () => previous.first,
    );
    if (followed.isPaused) return;

    try {
      await ref
          .read(copyEngineServiceProvider)
          .enable(
            walletAddress: walletAddress,
            leaderWallet: leaderAddress,
            settings: newSettings,
          );
    } catch (e) {
      ref
          .read(loggerServiceProvider)
          .error(
            'Failed to update settings for $leaderAddress: $e',
            tag: '[CopyTrade]',
          );
      state = state.copyWith(following: previous);
      await _persistFollowed();
      state = state.copyWith(error: 'Could not update settings — try again.');
    }
  }

  // ── Server sync ────────────────────────────────────────────────────────────

  /// Reconciles local UI state with the backend: the server's subscriptions are
  /// the source of truth for who is followed, and Postgres owns the points
  /// balance. Local profile cache is reused for display and enriched after.
  Future<void> _syncFromServer() async {
    final walletAddress = ref.read(clientAuthProvider).walletAddress ?? '';
    if (walletAddress.isEmpty) return;

    try {
      final engine = ref.read(copyEngineServiceProvider);
      final subscriptions = await engine.fetchSubscriptions(walletAddress);

      final byAddress = {for (final f in state.following) f.leader.address: f};

      final reconciled = <FollowedLeader>[];
      for (final sub in subscriptions) {
        final cached = byAddress[sub.leaderWallet];
        final profile =
            cached?.leader ?? LeaderProfile(address: sub.leaderWallet);
        reconciled.add(
          (cached ??
                  FollowedLeader(
                    leader: profile,
                    settings: sub.settings,
                    followedAt: DateTime.now(),
                    lastKnownPositions: profile.openPositions,
                  ))
              .copyWith(settings: sub.settings, isPaused: !sub.isActive),
        );
      }

      state = state.copyWith(following: reconciled);
      _syncLeaderRealtime();
      await _persistFollowed();
      await _loadPointsFromServer();
      if (subscriptions.any((sub) => sub.isActive) &&
          !_isExternalWalletSignIn()) {
        Future.microtask(() => _ensureServerSigner(walletAddress));
      }
      Future.microtask(_refreshFollowingProfiles);
    } catch (e) {
      ref
          .read(loggerServiceProvider)
          .error(
            'Failed to sync copy state from server: $e',
            tag: '[CopyTrade]',
          );
      // Fall back to loading points so the UI still shows a balance.
      await _loadPointsFromServer();
    }
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

      // Drop any stale self-follow entry that may have been persisted before
      // the self-follow guard existed.
      final myWallet = ref.read(clientAuthProvider).walletAddress;
      final cleaned = myWallet == null
          ? followed
          : followed.where((f) => f.leader.address != myWallet).toList();
      if (cleaned.length != followed.length) {
        ref
            .read(loggerServiceProvider)
            .warning(
              'Removed self-follow entry from persisted leaders',
              tag: '[CopyTrade]',
            );
      }

      state = state.copyWith(following: cleaned);
      _syncLeaderRealtime();
      if (cleaned.length != followed.length) {
        await _persistFollowed();
      }
      Future.microtask(_refreshFollowingProfiles);
    } catch (e) {
      ref
          .read(loggerServiceProvider)
          .error('Failed to load followed leaders: $e', tag: '[CopyTrade]');
    }
  }

  String _signerAttachmentKey({
    required String walletAddress,
    required String signerId,
    required List<String> policyIds,
  }) {
    final normalizedPolicies = [...policyIds]..sort();
    final policyKey = normalizedPolicies.join(',');
    return '$_signerAttachedKeyPrefix:$walletAddress:$signerId:$policyKey';
  }

  /// Public refresh used by pull-to-refresh on the copy page.
  Future<void> refreshFollowed() => _refreshFollowingProfiles();

  Future<void> _refreshFollowingProfiles() async {
    if (state.following.isEmpty || state.isPolling) return;

    state = state.copyWith(isPolling: true);
    final service = ref.read(leaderDiscoveryServiceProvider);
    final refreshed = <FollowedLeader>[];
    try {
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

      state = state.copyWith(following: refreshed, isPolling: false);
      _syncLeaderRealtime();
    } catch (_) {
      state = state.copyWith(isPolling: false);
    }
  }

  void _syncLeaderRealtime() {
    final authorities = state.following
        .map((followed) => followed.leader.address)
        .where((address) => address.isNotEmpty)
        .toSet();

    final ws = ref.read(phoenixWebSocketServiceProvider);
    for (final authority in _watchedAuthorities.difference(authorities)) {
      ws.unsubscribeTraderState(authority);
    }

    if (authorities.isEmpty) {
      _watchedAuthorities = <String>{};
      _pollTimer?.cancel();
      _pollTimer = null;
      _wsSub?.cancel();
      _wsSub = null;
      _wsRefreshDebounce?.cancel();
      _wsRefreshDebounce = null;
      return;
    }

    unawaited(ws.connect());

    for (final authority in authorities.difference(_watchedAuthorities)) {
      ws.subscribeTraderState(authority);
    }
    _watchedAuthorities = authorities;

    _wsSub ??= ws.traderStateStream.listen((message) {
      final authority = message.raw['authority'] as String?;
      if (authority == null || !_watchedAuthorities.contains(authority)) {
        return;
      }
      _scheduleRealtimeRefresh();
    });

    _pollTimer ??= Timer.periodic(_refreshFallbackInterval, (_) {
      unawaited(_refreshFollowingProfiles());
    });
  }

  void _scheduleRealtimeRefresh() {
    _wsRefreshDebounce?.cancel();
    _wsRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_refreshFollowingProfiles());
    });
  }

  void _dispose() {
    final ws = ref.read(phoenixWebSocketServiceProvider);
    for (final authority in _watchedAuthorities) {
      ws.unsubscribeTraderState(authority);
    }
    _watchedAuthorities = <String>{};
    _wsSub?.cancel();
    _wsRefreshDebounce?.cancel();
    _pollTimer?.cancel();
  }
}
