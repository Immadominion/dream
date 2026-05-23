import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth/client_auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/settings_notifications_tile.dart';
import '../widgets/settings_tiles.dart';

// ---------------------------------------------------------------------------
// Settings Page — Phoenix trading terminal settings
// ---------------------------------------------------------------------------

const _kAppVersion = '1.0.0';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(clientAuthProvider);
    final walletAddress = authState.walletAddress ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _Header(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                children: [
                  // Account section
                  if (walletAddress.isNotEmpty) ...[
                    _SectionLabel(label: 'Account'),
                    SizedBox(height: 6.h),
                    SettingsWalletTile(walletAddress: walletAddress),
                    SizedBox(height: 20.h),
                  ],

                  // Trading section
                  _SectionLabel(label: 'Trading'),
                  SizedBox(height: 6.h),
                  SettingsInfoTile(
                    icon: PhosphorIcons.buildings(),
                    title: 'Powered by Phoenix Trade',
                    subtitle: 'Perpetuals on Solana',
                  ),
                  const SettingsFlightBuilderTile(),
                  SizedBox(height: 20.h),

                  // Notifications section
                  _SectionLabel(label: 'Notifications'),
                  SizedBox(height: 6.h),
                  const SettingsNotificationsTile(),
                  SizedBox(height: 20.h),

                  // Network section
                  _SectionLabel(label: 'Network'),
                  SizedBox(height: 6.h),
                  SettingsInfoTile(
                    icon: PhosphorIcons.globe(),
                    title: 'REST API',
                    subtitle: AppConstants.phoenixApiBaseUrl,
                  ),
                  SettingsInfoTile(
                    icon: PhosphorIcons.wifiHigh(),
                    title: 'WebSocket',
                    subtitle: AppConstants.phoenixWsUrl,
                  ),
                  SizedBox(height: 20.h),

                  // About section
                  _SectionLabel(label: 'About'),
                  SizedBox(height: 6.h),
                  SettingsInfoTile(
                    icon: PhosphorIcons.info(),
                    title: 'Version',
                    subtitle: _kAppVersion,
                  ),
                  SizedBox(height: 32.h),

                  // Sign out
                  _SignOutButton(
                    onTap: () async {
                      await ref.read(clientAuthProvider.notifier).signOut();
                      if (context.mounted) context.go('/enhanced-login');
                    },
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              PhosphorIcons.arrowLeft(),
              color: AppColors.textPrimaryDark,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            'Settings',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppColors.textMutedDark,
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.bearish.withOpacity(0.08),
          border: Border.all(color: AppColors.bearish.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(10.r),
        ),
        alignment: Alignment.center,
        child: Text(
          'Sign Out',
          style: TextStyle(
            color: AppColors.bearish,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
