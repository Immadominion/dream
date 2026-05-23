import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/phoenix/phoenix_trader_service.dart';
import '../../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Builder fee balance provider
// ---------------------------------------------------------------------------

/// Fetches the accrued builder fee balance by reading the builder authority's
/// Phoenix trader account. Fees accumulate as collateral there and can be
/// withdrawn from https://flight.phoenix.trade.
final _builderFeesProvider = FutureProvider.autoDispose<double>((ref) async {
  final authority = AppConstants.phoenixBuilderAuthority;
  if (authority.isEmpty) return 0.0;
  final svc = ref.read(phoenixTraderServiceProvider);
  final state = await svc.fetchTraderState(authority);
  // Builder fees accrue as collateral on the trader account tied to the
  // builder wallet. availableMargin = collateral after open position reserves.
  return state.collateral;
});

// ---------------------------------------------------------------------------
// Flight builder fee card
// ---------------------------------------------------------------------------

class AccountBuilderFeesCard extends ConsumerWidget {
  const AccountBuilderFeesCard({super.key});

  static const _flightUrl = 'https://flight.phoenix.trade';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feesAsync = ref.watch(_builderFeesProvider);

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.flight_takeoff,
                  color: const Color(0xFF10B981),
                  size: 16.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flight Builder Fees',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Earned on every taker fill routed through Dream',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Refresh button
              GestureDetector(
                onTap: () => ref.invalidate(_builderFeesProvider),
                child: Icon(
                  Icons.refresh,
                  color: AppColors.textMutedDark,
                  size: 16.sp,
                ),
              ),
            ],
          ),

          SizedBox(height: 14.h),

          // Accrued balance
          feesAsync.when(
            loading: () => Row(
              children: [
                Text(
                  'Accrued',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(width: 8.w),
                SizedBox(
                  width: 12.w,
                  height: 12.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            error: (e, _) => Text(
              'Failed to load fee balance',
              style: TextStyle(color: AppColors.bearish, fontSize: 12.sp),
            ),
            data: (balance) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${balance.toStringAsFixed(4)}',
                  style: TextStyle(
                    color: balance > 0
                        ? const Color(0xFF10B981)
                        : AppColors.textPrimaryDark,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(width: 6.w),
                Padding(
                  padding: EdgeInsets.only(bottom: 3.h),
                  child: Text(
                    'USDC',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Open Flight portal button
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse(_flightUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                borderRadius: BorderRadius.circular(7.r),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Open Flight Portal to Withdraw',
                    style: TextStyle(
                      color: const Color(0xFF10B981),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.open_in_new,
                    color: const Color(0xFF10B981),
                    size: 13.sp,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Referral card
// ---------------------------------------------------------------------------

class AccountReferralCard extends StatelessWidget {
  const AccountReferralCard({super.key});

  static const _referralUrl = 'https://app.phoenix.trade/referral';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.people_outline,
                  color: AppColors.primary,
                  size: 16.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Refer & Earn',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Earn 20% of fees from friends you refer',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'Unlock your referral code after \$10k lifetime volume. '
            'Referred traders get a 10% fee discount — you earn 20% of their fees.',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 11.sp,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12.h),
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse(_referralUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(7.r),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Open Referral Portal',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.open_in_new,
                    color: AppColors.primary,
                    size: 13.sp,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
