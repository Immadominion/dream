import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/notifications/remote_notification_service.dart';
import '../../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Notifications settings tile — requests permission, monitors status
// ---------------------------------------------------------------------------

class SettingsNotificationsTile extends ConsumerStatefulWidget {
  const SettingsNotificationsTile({super.key});

  @override
  ConsumerState<SettingsNotificationsTile> createState() =>
      _SettingsNotificationsTileState();
}

class _SettingsNotificationsTileState
    extends ConsumerState<SettingsNotificationsTile>
    with WidgetsBindingObserver {
  bool? _enabled;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check after user returns from system settings
    if (state == AppLifecycleState.resumed) _checkStatus();
  }

  Future<void> _checkStatus() async {
    final svc = ref.read(notificationServiceProvider);
    final enabled = await svc.areNotificationsEnabled;
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);
    try {
      final svc = ref.read(notificationServiceProvider);
      final granted = await svc.requestPermission();
      if (mounted) setState(() => _enabled = granted);
      if (granted) {
        final auth = ref.read(clientAuthProvider);
        final walletAddress = auth.walletAddress;
        if (walletAddress != null) {
          await ref.read(remoteNotificationServiceProvider).syncCurrentDevice(
            walletAddress: walletAddress,
            email: auth.userEmail,
            force: true,
          );
        }
      }
      if (mounted && !granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enable notifications in System Settings for order fills and price alerts.',
              style: TextStyle(fontSize: 12.sp),
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => launchUrl(
                Uri.parse('app-settings:'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            backgroundColor: AppColors.cardDark,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final statusColor = enabled == true ? AppColors.bullish : AppColors.bearish;
    final statusLabel = enabled == null
        ? 'Checking...'
        : enabled
        ? 'Enabled'
        : 'Disabled';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        border: Border.all(color: AppColors.borderDark, width: 0.5),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.bell(),
            color: AppColors.textSecondaryDark,
            size: 16.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Order fills, TP/SL triggers, price alerts',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          if (_requesting)
            SizedBox(
              width: 16.w,
              height: 16.h,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.primary,
              ),
            )
          else if (enabled == false)
            GestureDetector(
              onTap: _requestPermission,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: Text(
                  'Enable',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
