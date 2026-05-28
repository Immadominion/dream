import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../providers/account_provider.dart';
import '../../../../core/theme/dream_colors.dart';

/// Account health & risk — anti-box layout. The status hero and risk detail
/// live in flat rows inside two squircle sections, no nested tiles.
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

    final collateral = accountState.collateral;
    final available = accountState.availableMargin;
    final reserved = (collateral - available).clamp(0.0, double.infinity);
    final usage = collateral > 0
        ? (reserved / collateral).clamp(0.0, 1.0)
        : 0.0;
    final pnl = accountState.unrealizedPnl;

    return Scaffold(
      backgroundColor: context.dreamColors.background,
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
                        color: context.dreamColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.dreamColors.stroke),
                      ),
                      child: Icon(
                        PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
                        color: context.dreamColors.onSurface,
                        size: 24.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    'Health & Risk',
                    style: TextStyle(
                      color: context.dreamColors.onSurface,
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
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 40.h),
                children: [
                  // Health Status section (squircle)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 8.h),
                    decoration: BoxDecoration(
                      color: context.dreamColors.surface,
                      borderRadius: BorderRadius.circular(28.r),
                      border: Border.all(
                        color: tier == 0
                            ? context.dreamColors.stroke
                            : color.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 60.w,
                          height: 60.w,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
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
                          'Your account status is',
                          style: TextStyle(
                            color: context.dreamColors.muted,
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
                        SizedBox(height: 20.h),
                        // Margin usage bar
                        _MarginUsageBar(usage: usage, color: color),
                        SizedBox(height: 8.h),
                        _HealthRow(
                          label: 'Equity',
                          value: formatUsdc(accountState.equity),
                        ),
                        const _Hairline(),
                        _HealthRow(
                          label: 'Collateral',
                          value: formatUsdc(collateral),
                        ),
                        const _Hairline(),
                        _HealthRow(
                          label: 'Reserved (in positions)',
                          value: formatUsdc(reserved),
                        ),
                        const _Hairline(),
                        _HealthRow(
                          label: 'Available to trade',
                          value: formatUsdc(available),
                        ),
                        const _Hairline(),
                        _HealthRow(
                          label: 'Unrealized PnL',
                          value: formatPnl(pnl),
                          valueColor: pnl >= 0
                              ? AppColors.bullish
                              : AppColors.bearish,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Risk Rules section (squircle)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: context.dreamColors.surface,
                      borderRadius: BorderRadius.circular(28.r),
                      border: Border.all(color: context.dreamColors.stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.info(PhosphorIconsStyle.bold),
                              color: AppColors.primary,
                              size: 16.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'HOW RISK WORKS',
                              style: TextStyle(
                                color: context.dreamColors.muted,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 18.h),
                        const _RiskRuleRow(
                          title: 'Liquidation threshold',
                          desc:
                              'Triggered when available collateral drops below the maintenance margin requirement.',
                        ),
                        SizedBox(height: 16.h),
                        const _RiskRuleRow(
                          title: 'Cross-margin sharing',
                          desc:
                              'All open positions share the same collateral pool to lower individual liquidation pricing.',
                        ),
                        SizedBox(height: 16.h),
                        const _RiskRuleRow(
                          title: 'Auto-deleveraging (ADL)',
                          desc:
                              'In extreme market conditions, highly profitable opposing trades may be automatically adjusted to safeguard system solvency.',
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

class _MarginUsageBar extends StatelessWidget {
  final double usage;
  final Color color;
  const _MarginUsageBar({required this.usage, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Margin usage',
              style: TextStyle(
                color: context.dreamColors.muted,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(usage * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: context.dreamColors.onSurface,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: LinearProgressIndicator(
            value: usage,
            minHeight: 6.h,
            backgroundColor: context.dreamColors.stroke,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _HealthRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.dreamColors.muted,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? context.dreamColors.onSurface,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.dreamColors.stroke.withValues(alpha: 0.5),
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
            color: context.dreamColors.onSurface,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          desc,
          style: TextStyle(
            color: context.dreamColors.muted,
            fontSize: 12.sp,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
