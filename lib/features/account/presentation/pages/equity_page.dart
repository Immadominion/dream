import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../widgets/account_history_providers.dart';
import '../widgets/account_pnl_chart.dart';
import '../../../../core/theme/dream_colors.dart';

/// Equity / performance curve — anti-box. A single squircle section wraps a
/// realized-PnL summary and the live equity chart; a second section explains
/// what the curve represents.
class EquityPage extends ConsumerWidget {
  final String walletAddress;
  const EquityPage({super.key, required this.walletAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(accountTradeHistoryProvider(walletAddress));

    // Cumulative realized PnL + max drawdown from closed fills.
    double cumulative = 0;
    double peak = 0;
    double maxDrawdown = 0;
    bool hasClosed = false;
    tradesAsync.whenData((trades) {
      final sorted = [...trades]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      for (final t in sorted) {
        if (t.realizedPnl.abs() > 1e-9) hasClosed = true;
        cumulative += t.realizedPnl;
        if (cumulative > peak) peak = cumulative;
        final dd = peak - cumulative;
        if (dd > maxDrawdown) maxDrawdown = dd;
      }
    });

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
                    'Equity Curve',
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
                  // Curve section (squircle)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
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
                              PhosphorIcons.chartLineUp(
                                PhosphorIconsStyle.bold,
                              ),
                              color: AppColors.primary,
                              size: 16.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'PERFORMANCE',
                              style: TextStyle(
                                color: context.dreamColors.muted,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryStat(
                                label: 'Cumulative PnL',
                                value: hasClosed ? formatPnl(cumulative) : '--',
                                valueColor: cumulative >= 0
                                    ? AppColors.bullish
                                    : AppColors.bearish,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 34.h,
                              color: context.dreamColors.stroke,
                            ),
                            Expanded(
                              child: _SummaryStat(
                                label: 'Max drawdown',
                                value: hasClosed
                                    ? '-${formatUsdc(maxDrawdown)}'
                                    : '--',
                                valueColor: maxDrawdown > 0
                                    ? AppColors.bearish
                                    : context.dreamColors.onSurface,
                                alignEnd: true,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: context.dreamColors.stroke.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        AccountPnlChartSection(walletAddress: walletAddress),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // About section (squircle)
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
                              color: AppColors.primaryLight,
                              size: 16.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'ABOUT THIS CURVE',
                              style: TextStyle(
                                color: context.dreamColors.muted,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'The curve tracks the net asset value (NAV) of your '
                          'cross-margin collateral on Phoenix over time. '
                          'Realized trade profits, fees, and funding all move '
                          'the line — cumulative PnL is your total closed '
                          'result, and max drawdown is the largest drop from a '
                          'prior peak.',
                          style: TextStyle(
                            color: context.dreamColors.muted,
                            fontSize: 12.sp,
                            height: 1.5,
                          ),
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

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool alignEnd;
  const _SummaryStat({
    required this.label,
    required this.value,
    this.valueColor,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.dreamColors.muted,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? context.dreamColors.onSurface,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}
