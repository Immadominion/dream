import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../navigation/app_router.dart';
import '../navigation/trade_share_link.dart';
import '../providers/auth/client_auth_provider.dart';
import '../services/logger_service.dart';
import '../services/phoenix/phoenix_trader_service.dart';
import '../../features/navigation/providers/bottom_nav_providers.dart';
import '../../shared/models/user.dart';

/// Session manager widget that handles periodic session refresh and token expiration
class SessionManager extends ConsumerStatefulWidget {
  final Widget child;

  const SessionManager({super.key, required this.child});

  @override
  ConsumerState<SessionManager> createState() => _SessionManagerState();
}

class _SessionManagerState extends ConsumerState<SessionManager>
    with WidgetsBindingObserver {
  Timer? _sessionTimer;
  Timer? _refreshTimer;
  StreamSubscription<Uri>? _appLinkSub;
  final _logger = LoggerService();
  final _appLinks = AppLinks();
  bool _isCheckingRegistration = false;
  TradeShareLink? _pendingTradeLink;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSessionManagement();
    _listenForAppLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _refreshTimer?.cancel();
    _appLinkSub?.cancel();
    super.dispose();
  }

  Future<void> _listenForAppLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _queueTradeLink(initialUri);
      }
    } catch (e) {
      _logger.warning('[SessionManager] Initial app link check failed: $e');
    }

    _appLinkSub = _appLinks.uriLinkStream.listen(
      _queueTradeLink,
      onError: (Object error) {
        _logger.warning('[SessionManager] App link stream error: $error');
      },
    );
  }

  void _queueTradeLink(Uri uri) {
    final tradeLink = TradeShareLink.parse(uri);
    if (tradeLink == null) return;

    _pendingTradeLink = tradeLink;
    _logger.info(
      '[SessionManager] Queued trade link ${tradeLink.routeLocation}',
      tag: 'DeepLink',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(
        const Duration(milliseconds: 700),
        _openPendingTradeLinkIfReady,
      );
    });
  }

  Future<void> _openPendingTradeLinkIfReady() async {
    if (!mounted || _pendingTradeLink == null) return;

    final authState = ref.read(clientAuthProvider);
    if (!authState.isAuthenticated) return;

    final router = ref.read(appRouterProvider);
    final currentPath = router.routeInformationProvider.value.uri.path;

    if (currentPath == AppRoutes.splash) {
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        _openPendingTradeLinkIfReady,
      );
      return;
    }

    if (currentPath == '/activate') return;

    final nextRoute = _pendingTradeLink!.routeLocation;
    _pendingTradeLink = null;
    _logger.info(
      '[SessionManager] Opening trade link $nextRoute',
      tag: 'DeepLink',
    );
    router.go(nextRoute);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground, refresh session
        _refreshSessionOnResume();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App goes to background, stop timers to save battery
        _pauseSessionManagement();
        break;
    }
  }

  void _startSessionManagement() {
    // Check session every 5 minutes
    _sessionTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkAndRefreshSession();
    });

    // Immediate session check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRefreshSession();
    });
  }

  void _pauseSessionManagement() {
    _sessionTimer?.cancel();
    _refreshTimer?.cancel();
  }

  void _refreshSessionOnResume() {
    // Restart session management when app resumes
    _startSessionManagement();

    // Immediate session refresh
    _checkAndRefreshSession();

    // Re-assert activation gate when app comes back to foreground.
    _enforceActivationGate();
  }

  Future<void> _enforceActivationGate() async {
    if (_isCheckingRegistration || !mounted) return;

    final authState = ref.read(clientAuthProvider);
    final wallet = authState.walletAddress;

    if (!authState.isAuthenticated || wallet == null) return;

    _isCheckingRegistration = true;
    try {
      final traderState = await ref
          .read(phoenixTraderServiceProvider)
          .fetchTraderState(wallet);
      if (!mounted) return;

      final router = ref.read(appRouterProvider);
      final path = router.routeInformationProvider.value.uri.path;

      if (!traderState.isRegistered) {
        if (path != '/activate') {
          _logger.info(
            '[SessionManager] Trader not activated, routing to /activate',
          );
          router.go('/activate');
        }
        return;
      }

      if (path == '/activate') {
        if (_pendingTradeLink != null) {
          await _openPendingTradeLinkIfReady();
        } else {
          _logger.info('[SessionManager] Trader activated, routing to home');
          router.go(AppRoutes.home);
        }
        return;
      }

      await _openPendingTradeLinkIfReady();
    } catch (e) {
      _logger.warning('[SessionManager] Activation gate check failed: $e');
    } finally {
      _isCheckingRegistration = false;
    }
  }

  Future<void> _checkAndRefreshSession() async {
    final authNotifier = ref.read(clientAuthProvider.notifier);
    final currentState = ref.read(clientAuthProvider);

    // Only refresh if user is authenticated
    if (currentState.isAuthenticated) {
      final session = currentState.session;

      if (session == null) {
        // No session but state is authenticated, something's wrong - re-initialize
        _logger.warning(
          '[SessionManager] No session but authenticated state, re-initializing…',
        );
        // ClientAuthProvider will handle loading from storage in its _initialize method
      } else if (session.isExpired) {
        _logger.warning(
          '[SessionManager] Session expired, rebuilding from Privy…',
        );
        await authNotifier.refreshSession();
        final refreshedState = ref.read(clientAuthProvider);
        if (refreshedState.session == null ||
            refreshedState.session!.isExpired) {
          _logger.warning(
            '[SessionManager] Session rebuild failed, logging out…',
          );
          await authNotifier.signOut();
        }
      } else {
        _logger.info(
          '[SessionManager] Session valid until ${session.expiresAt}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthStateData>(clientAuthProvider, (previous, next) {
      if (previous?.state != next.state) {
        _logger.info(
          '[SessionManager] Auth state changed: ${previous?.state} → ${next.state}',
        );
      }
      // Redirect to login when user signs out
      if (next.state == AuthState.unauthenticated &&
          previous?.state != AuthState.unauthenticated) {
        final router = ref.read(appRouterProvider);
        ref.read(bottomNavIndexProvider.notifier).reset();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.go('/enhanced-login');
        });
      }

      // Enforce activation gate whenever auth becomes active.
      if (next.state == AuthState.authenticated &&
          previous?.state != AuthState.authenticated) {
        ref.read(bottomNavIndexProvider.notifier).reset();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _enforceActivationGate();
        });
      }
    });

    return widget.child;
  }
}
