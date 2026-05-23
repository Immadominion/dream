import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../providers/account_provider.dart';

// ---------------------------------------------------------------------------
// Portfolio summary card
// ---------------------------------------------------------------------------

class AccountPortfolioCard extends StatelessWidget {
  final AccountState accountState;
  const AccountPortfolioCard({super.key, required this.accountState});

  @override
  Widget build(BuildContext context) {
    final pnlIsPositive = accountState.unrealizedPnl >= 0;
    final pnlColor = pnlIsPositive ? AppColors.bullish : AppColors.bearish;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portfolio Value',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            formatUsdc(accountState.equity),
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 12.h),
          Divider(color: AppColors.borderDark, height: 1),
          SizedBox(height: 12.h),
          Row(
            children: [
              _Stat(
                label: 'Collateral',
                value: formatUsdc(accountState.collateral),
              ),
              _Stat(
                label: 'Available',
                value: formatUsdc(accountState.availableMargin),
              ),
              _Stat(
                label: 'Unrealized P&L',
                value: formatPnl(accountState.unrealizedPnl),
                valueColor: pnlColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Risk tier card
// ---------------------------------------------------------------------------

class AccountRiskCard extends StatelessWidget {
  final AccountState accountState;
  const AccountRiskCard({super.key, required this.accountState});

  @override
  Widget build(BuildContext context) {
    final tier = accountState.riskTier;
    final label = accountState.riskTierLabel;
    final color = tier == 0
        ? AppColors.success
        : tier <= 2
        ? AppColors.warning
        : AppColors.bearish;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: tier == 0 ? AppColors.borderDark : color.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            tier == 0 ? Icons.shield_outlined : Icons.warning_amber_rounded,
            color: color,
            size: 18.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Health',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading placeholder
// ---------------------------------------------------------------------------

class AccountLoadingCard extends StatelessWidget {
  const AccountLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120.h,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Stat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 11.sp,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimaryDark,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
