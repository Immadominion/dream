import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../providers/account_provider.dart';
import '../widgets/account_history_providers.dart';

class AnalyticsPage extends ConsumerWidget {
  final String walletAddress;
  const AnalyticsPage({super.key, required this.walletAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);
    final tradesAsync = ref.watch(accountTradeHistoryProvider(walletAddress));

    final positions = accountState.traderState?.positions ?? [];
    final totalUnrealizedPnl = accountState.traderState?.unrealizedPnl ?? 0.0;
    final equity = accountState.traderState?.equity ?? 0.0;

    final avgLeverage = positions.isEmpty
        ? 0.0
        : positions.fold<double>(0, (s, p) => s + p.leverage) /
              positions.length;

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
                    'Analytics',
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
                  // Real-time Overview Container
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
                              PhosphorIcons.chartLine(PhosphorIconsStyle.bold),
                              color: AppColors.primary,
                              size: 24.sp,
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              'Portfolio Stats',
                              style: TextStyle(
                                color: AppColors.textPrimaryDark,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                        Row(
                          children: [
                            Expanded(
                              child: _LargeStatTile(
                                label: 'Unrealized PnL',
                                value: formatPnl(totalUnrealizedPnl),
                                valueColor: totalUnrealizedPnl >= 0
                                    ? AppColors.bullish
                                    : AppColors.bearish,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _LargeStatTile(
                                label: 'Equity Balance',
                                value: equity > 0
                                    ? '\$${formatCompact(equity)}'
                                    : '--',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: _LargeStatTile(
                                label: 'Open Positions',
                                value: positions.length.toString(),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _LargeStatTile(
                                label: 'Average Leverage',
                                value: positions.isEmpty
                                    ? '--'
                                    : '${avgLeverage.toStringAsFixed(1)}×',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Trade History Insights Container
                  tradesAsync.when(
                    loading: () => Container(
                      height: 150.h,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                    error: (err, st) => Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(26.r),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Center(
                        child: Text(
                          'History data currently unavailable.',
                          style: TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ),
                    data: (trades) {
                      if (trades.isEmpty) {
                        return Container(
                          padding: EdgeInsets.all(24.w),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(26.r),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                PhosphorIcons.folderOpen(
                                  PhosphorIconsStyle.bold,
                                ),
                                color: AppColors.textMutedDark,
                                size: 36.sp,
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                'No Trades Found',
                                style: TextStyle(
                                  color: AppColors.textPrimaryDark,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Place your first order on the trade screen to generate performance analytics.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final totalVolume = trades.fold<double>(
                        0,
                        (s, t) => s + t.price * t.size,
                      );
                      final totalFees = trades.fold<double>(
                        0,
                        (s, t) => s + t.fee,
                      );

                      final counts = <String, int>{};
                      for (final t in trades) {
                        counts[t.symbol] = (counts[t.symbol] ?? 0) + 1;
                      }
                      final topSymbol = counts.entries
                          .reduce((a, b) => a.value >= b.value ? a : b)
                          .key;

                      final biggestNotional = trades
                          .map((t) => t.price * t.size)
                          .reduce((a, b) => a >= b ? a : b);

                      return Container(
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
                                  PhosphorIcons.lightning(
                                    PhosphorIconsStyle.bold,
                                  ),
                                  color: const Color(0xFFFBBF24),
                                  size: 24.sp,
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  'Performance Insights',
                                  style: TextStyle(
                                    color: AppColors.textPrimaryDark,
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20.h),
                            Row(
                              children: [
                                Expanded(
                                  child: _LargeStatTile(
                                    label: 'Total Volume traded',
                                    value: '\$${formatCompact(totalVolume)}',
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: _LargeStatTile(
                                    label: 'Total Fees Paid',
                                    value: '\$${formatCompact(totalFees)}',
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            Row(
                              children: [
                                Expanded(
                                  child: _LargeStatTile(
                                    label: 'Preferred Asset',
                                    value: topSymbol,
                                    valueColor: AppColors.primaryLight,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: _LargeStatTile(
                                    label: 'Biggest Single Trade',
                                    value:
                                        '\$${formatCompact(biggestNotional)}',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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

class _LargeStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _LargeStatTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderDark, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimaryDark,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}
