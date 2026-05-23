import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth/client_auth_provider.dart';
import '../services/logger_service.dart';
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
  final _logger = LoggerService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSessionManagement();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
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
        // Session expired, need to re-authenticate
        _logger.warning('[SessionManager] Session expired, logging out…');
        await authNotifier.signOut();
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/enhanced-login');
        });
      }
    });

    return widget.child;
  }
}
