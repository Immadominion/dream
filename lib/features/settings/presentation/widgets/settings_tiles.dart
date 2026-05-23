import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Base tile widget (private — used by tiles in this file)
// ---------------------------------------------------------------------------

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        border: Border.all(color: AppColors.borderDark, width: 0.5),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondaryDark, size: 16.sp),
          SizedBox(width: 12.w),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wallet address tile — display + copy
// ---------------------------------------------------------------------------

class SettingsWalletTile extends StatelessWidget {
  final String walletAddress;
  const SettingsWalletTile({super.key, required this.walletAddress});

  String get _truncated {
    if (walletAddress.length <= 16) return walletAddress;
    return '${walletAddress.substring(0, 8)}...${walletAddress.substring(walletAddress.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: PhosphorIcons.wallet(),
      title: 'Wallet',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _truncated,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12.sp,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: walletAddress));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Address copied',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                  backgroundColor: AppColors.cardDark,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Icon(
              PhosphorIcons.copy(),
              color: AppColors.textMutedDark,
              size: 15.sp,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info tile — static label + value row
// ---------------------------------------------------------------------------

class SettingsInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const SettingsInfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: icon,
      title: title,
      trailing: Text(
        subtitle,
        style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 11.sp),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flight builder fee tile — shows configured status + links to flight.phoenix
// ---------------------------------------------------------------------------

class SettingsFlightBuilderTile extends StatelessWidget {
  const SettingsFlightBuilderTile({super.key});

  static const _flightUrl = 'https://flight.phoenix.trade';

  String? get _authority {
    final c = AppConstants.phoenixBuilderAuthority;
    return c.isEmpty ? null : c;
  }

  String _truncate(String s) {
    if (s.length <= 16) return s;
    return '${s.substring(0, 6)}...${s.substring(s.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final authority = _authority;
    final configured = authority != null;
    final pda = AppConstants.phoenixBuilderPdaIndex;
    final sub = AppConstants.phoenixBuilderSubaccountIndex;

    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(_flightUrl),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          border: Border.all(
            color: configured
                ? AppColors.bullish.withOpacity(0.35)
                : AppColors.borderDark,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(
              PhosphorIcons.chartBar(),
              color: AppColors.textSecondaryDark,
              size: 16.sp,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flight Builder Fee',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    configured
                        ? '${_truncate(authority)} · PDA $pda · Sub $sub'
                        : 'Not configured — tap to register',
                    style: TextStyle(
                      color: configured
                          ? AppColors.textSecondaryDark
                          : AppColors.bearish,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: configured
                        ? AppColors.bullish.withOpacity(0.12)
                        : AppColors.bearish.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    configured ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      color: configured ? AppColors.bullish : AppColors.bearish,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(
                  PhosphorIcons.arrowSquareOut(),
                  color: AppColors.textMutedDark,
                  size: 13.sp,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
