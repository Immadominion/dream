import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/services/notifications/remote_notification_service.dart';

class NotificationRuntimeListener extends ConsumerStatefulWidget {
  const NotificationRuntimeListener({super.key});

  @override
  ConsumerState<NotificationRuntimeListener> createState() =>
      _NotificationRuntimeListenerState();
}

class _NotificationRuntimeListenerState
    extends ConsumerState<NotificationRuntimeListener>
    with WidgetsBindingObserver {
  bool _runtimeInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_initializeRuntime);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncAuthenticatedDevice());
    }
  }

  Future<void> _initializeRuntime() async {
    if (_runtimeInitialized) return;
    _runtimeInitialized = true;
    await ref.read(remoteNotificationServiceProvider).initialize();
    await _syncAuthenticatedDevice();
  }

  Future<void> _syncAuthenticatedDevice() async {
    final auth = ref.read(clientAuthProvider);
    final walletAddress = auth.walletAddress;
    if (!auth.isAuthenticated || walletAddress == null) return;

    await ref.read(remoteNotificationServiceProvider).syncCurrentDevice(
      walletAddress: walletAddress,
      email: auth.userEmail,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthStateData>(clientAuthProvider, (previous, next) {
      if (!next.isAuthenticated || next.walletAddress == null) return;

      final walletChanged = next.walletAddress != previous?.walletAddress;
      final emailChanged = next.userEmail != previous?.userEmail;
      final becameAuthenticated = previous == null || !previous.isAuthenticated;

      if (walletChanged || emailChanged || becameAuthenticated) {
        unawaited(
          ref.read(remoteNotificationServiceProvider).syncCurrentDevice(
            walletAddress: next.walletAddress!,
            email: next.userEmail,
            force: becameAuthenticated,
          ),
        );
      }
    });

    return const SizedBox.shrink();
  }
}