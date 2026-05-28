import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../providers/account_provider.dart';
import '../../../account/presentation/widgets/account_history_providers.dart';

// ---------------------------------------------------------------------------
// Portfolio analytics card
// ---------------------------------------------------------------------------

class AccountAnalyticsCard extends ConsumerWidget {
  final String walletAddress;

  const AccountAnalyticsCard({super.key, required this.walletAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);
    final tradesAsync = ref.watch(accountTradeHistoryProvider(walletAddress));

    final positions = accountState.traderState?.positions ?? [];
    final totalUnrealizedPnl = accountState.traderState?.unrealizedPnl ?? 0.0;
    final equity = accountState.traderState?.equity ?? 0.0;

    // Compute current avg leverage from open positions
    final avgLeverage = positions.isEmpty
        ? 0.0
        : positions.fold<double>(0, (s, p) => s + p.leverage) /
              positions.length;

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
          // Header
          Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.analytics_outlined,
                  color: AppColors.primary,
                  size: 16.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'Portfolio Analytics',
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // Live portfolio stats (2-col grid)
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Unrealized PnL',
                  value: formatPnl(totalUnrealizedPnl),
                  valueColor: totalUnrealizedPnl >= 0
                      ? AppColors.bullish
                      : AppColors.bearish,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _StatTile(
                  label: 'Equity',
                  value: equity > 0 ? formatCompact(equity) : '--',
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Open Positions',
                  value: positions.length.toString(),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _StatTile(
                  label: 'Avg Leverage',
                  value: positions.isEmpty
                      ? '--'
                      : '${avgLeverage.toStringAsFixed(1)}×',
                ),
              ),
            ],
          ),

          // Trade history stats
          tradesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (err, st) => const SizedBox.shrink(),
            data: (trades) {
              if (trades.isEmpty) return const SizedBox.shrink();

              final totalVolume = trades.fold<double>(
                0,
                (s, t) => s + t.price * t.size,
              );
              final totalFees = trades.fold<double>(0, (s, t) => s + t.fee);

              // Most active market
              final counts = <String, int>{};
              for (final t in trades) {
                counts[t.symbol] = (counts[t.symbol] ?? 0) + 1;
              }
              final topSymbol = counts.entries
                  .reduce((a, b) => a.value >= b.value ? a : b)
                  .key;

              // Biggest single trade by notional
              final biggestNotional = trades
                  .map((t) => t.price * t.size)
                  .reduce((a, b) => a >= b ? a : b);

              return Column(
                children: [
                  SizedBox(height: 8.h),
                  const _Divider(),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Total Volume',
                          value: formatCompact(totalVolume),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _StatTile(
                          label: 'Total Fees',
                          value: '\$${totalFees.toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Trades (last 50)',
                          value: trades.length.toString(),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _StatTile(
                          label: 'Most Active',
                          value: topSymbol
                              .replaceAll('-PERP', '')
                              .replaceAll('-USD', ''),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  _StatTile(
                    label: 'Largest Trade',
                    value: formatCompact(biggestNotional),
                    wide: true,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat tile
// ---------------------------------------------------------------------------

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool wide;

  const _StatTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.borderDark, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: wide
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMutedDark,
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimaryDark,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(color: AppColors.borderDark, height: 1, thickness: 0.5);
  }
}
