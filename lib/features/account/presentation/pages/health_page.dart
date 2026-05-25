import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/account_provider.dart';
import '../widgets/account_portfolio_card.dart';

class HealthPage extends ConsumerWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);

    final tier = accountState.riskTier;
    final label = accountState.riskTierLabel;
    final color = tier == 0
        ? AppColors.success
        : tier <= 2
        ? AppColors.warning
        : AppColors.bearish;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Icon(
                        PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
                        color: AppColors.textPrimaryDark,
                        size: 24.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    'Account Health & Risk',
                    style: TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 40.h),
                children: [
                  // Health Status Squircle Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(26.r),
                      border: Border.all(
                        color: tier == 0
                            ? AppColors.borderDark
                            : color.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 60.w,
                          height: 60.w,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            tier == 0
                                ? PhosphorIcons.shieldCheck(
                                    PhosphorIconsStyle.bold,
                                  )
                                : PhosphorIcons.warningDiamond(
                                    PhosphorIconsStyle.bold,
                                  ),
                            color: color,
                            size: 32.sp,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Your Account Status Is',
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          label.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        const Divider(color: AppColors.borderDark, height: 1),
                        SizedBox(height: 16.h),
                        AccountRiskCard(accountState: accountState),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Risk Rules Squircle Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(26.r),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.info(PhosphorIconsStyle.bold),
                              color: AppColors.primary,
                              size: 22.sp,
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              'Risk Parameters',
                              style: TextStyle(
                                color: AppColors.textPrimaryDark,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        _RiskRuleRow(
                          title: 'Liquidation Threshold',
                          desc:
                              'Triggered when available collateral drops below the maintenance margin requirement.',
                        ),
                        SizedBox(height: 14.h),
                        _RiskRuleRow(
                          title: 'Cross-Margin Sharing',
                          desc:
                              'All open positions share the same collateral pool to lower individual liquidation pricing.',
                        ),
                        SizedBox(height: 14.h),
                        _RiskRuleRow(
                          title: 'Auto-Deleveraging (ADL)',
                          desc:
                              'In extreme market lockups, highly profitable opposing trades may be automatically adjusted to safeguard net system solvency.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskRuleRow extends StatelessWidget {
  final String title;
  final String desc;
  const _RiskRuleRow({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          desc,
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 12.sp,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
