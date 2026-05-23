import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/phoenix/phoenix_auth_provider.dart';
import '../../../../core/services/phoenix/phoenix_websocket_service.dart';
import '../../../account/providers/account_provider.dart';
import '../../providers/bottom_nav_providers.dart';

// Provider exposing live WS connection status (true = connected, false = lost)
final wsConnectedProvider = StreamProvider<bool>((ref) {
  final ws = ref.watch(phoenixWebSocketServiceProvider);
  return ws.connectionStatusStream;
});

// ---------------------------------------------------------------------------
// Reauth banner — shown when MWA wallet disconnected + Phoenix JWT expired
// ---------------------------------------------------------------------------

class ReauthBanner extends ConsumerWidget {
  const ReauthBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: const Color(0xFF7C3AED),
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () => ref.read(phoenixAuthProvider.notifier).authenticate(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              children: [
                Icon(Icons.link_off, color: Colors.white, size: 15.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Wallet disconnected — tap to reconnect',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white70, size: 16.sp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activation banner — nudge users who haven't activated their Phoenix account
// ---------------------------------------------------------------------------

class ActivationBanner extends ConsumerWidget {
  final int currentIndex;
  const ActivationBanner({super.key, required this.currentIndex});

  static const _accountTab = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);
    if (accountState.traderState == null) return const SizedBox.shrink();
    if (accountState.traderState!.isRegistered) return const SizedBox.shrink();
    if (currentIndex == _accountTab) return const SizedBox.shrink();

    return Material(
      color: AppColors.primary.withOpacity(0.92),
      child: InkWell(
        onTap: () =>
            ref.read(bottomNavIndexProvider.notifier).setIndex(_accountTab),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              children: [
                Icon(
                  Icons.lock_open_outlined,
                  color: Colors.white,
                  size: 15.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Activate your account to start trading',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  'Get started →',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WebSocket status banner — shown only when live data feed is disconnected
// ---------------------------------------------------------------------------

class WsStatusBanner extends ConsumerWidget {
  const WsStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(wsConnectedProvider);
    final isDisconnected = status.whenOrNull(data: (v) => !v) ?? false;
    if (!isDisconnected) return const SizedBox.shrink();

    return Material(
      color: const Color(0xFF92400E), // amber-800
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 8.w,
              height: 8.w,
              child: const CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white70,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'Reconnecting to live data…',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
