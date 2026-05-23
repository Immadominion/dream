import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/services/phoenix/phoenix_trader_service.dart';
import '../../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// PnL data provider
// ---------------------------------------------------------------------------

typedef _PnlKey = ({String authority, String resolution});

final _pnlProvider = FutureProvider.family<List<PhoenixPnlPoint>, _PnlKey>((
  ref,
  key,
) async {
  final svc = ref.read(phoenixTraderServiceProvider);
  final limit = switch (key.resolution) {
    '1h' => 48, // 2 days
    '4h' => 42, // 1 week
    '1w' => 52, // 1 year
    _ => 30, // 1d — 1 month
  };
  return svc.fetchTraderPnl(
    key.authority,
    resolution: key.resolution,
    limit: limit,
  );
});

// ---------------------------------------------------------------------------
// PnL chart section — equity curve using /trader/{authority}/pnl
// ---------------------------------------------------------------------------

class AccountPnlChartSection extends ConsumerStatefulWidget {
  final String walletAddress;
  const AccountPnlChartSection({super.key, required this.walletAddress});

  @override
  ConsumerState<AccountPnlChartSection> createState() =>
      _AccountPnlChartSectionState();
}

class _AccountPnlChartSectionState
    extends ConsumerState<AccountPnlChartSection> {
  String _resolution = '1d';

  static const _resolutions = ['1h', '4h', '1d', '1w'];

  @override
  Widget build(BuildContext context) {
    final pnlAsync = ref.watch(
      _pnlProvider((authority: widget.walletAddress, resolution: _resolution)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Equity Curve',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            ..._resolutions.map(
              (r) => _ResolutionChip(
                label: r.toUpperCase(),
                selected: _resolution == r,
                onTap: () {
                  setState(() => _resolution = r);
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          height: 160.h,
          padding: EdgeInsets.fromLTRB(8.w, 12.h, 16.w, 8.h),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: pnlAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 1.5,
              ),
            ),
            error: (_, _) => Center(
              child: Text(
                'Failed to load PnL data',
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontSize: 12.sp,
                ),
              ),
            ),
            data: (points) {
              if (points.isEmpty) {
                return Center(
                  child: Text(
                    'No PnL data yet',
                    style: TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 12.sp,
                    ),
                  ),
                );
              }
              return _PnlLineChart(points: points);
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _ResolutionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ResolutionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(left: 6.w),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4.r),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderDark,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondaryDark,
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PnlLineChart extends StatelessWidget {
  final List<PhoenixPnlPoint> points;
  const _PnlLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].totalPnl));
    }

    final values = spots.map((s) => s.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs();
    final padding = range == 0 ? 1.0 : range * 0.1;
    final lastPnl = values.last;
    final chartColor = lastPnl >= 0 ? AppColors.bullish : AppColors.bearish;

    return LineChart(
      LineChartData(
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.borderDark, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44.w,
              getTitlesWidget: (value, _) => Text(
                _formatAxis(value),
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontSize: 9.sp,
                ),
              ),
            ),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: chartColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  chartColor.withOpacity(0.18),
                  chartColor.withOpacity(0.01),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceDark,
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final sign = s.y >= 0 ? '+' : '';
              return LineTooltipItem(
                '$sign\$${s.y.toStringAsFixed(2)}',
                TextStyle(
                  color: s.y >= 0 ? AppColors.bullish : AppColors.bearish,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _formatAxis(double v) {
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}
