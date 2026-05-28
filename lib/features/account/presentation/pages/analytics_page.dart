import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/models/phoenix/phoenix_realtime_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../providers/account_provider.dart';
import '../widgets/account_history_providers.dart';
import '../../../../core/theme/dream_colors.dart';

/// Portfolio analytics — a data-science view of the trader's performance.
///
/// Anti-box by design: metrics live in flat rows separated by hairline
/// dividers, grouped under a small number of squircle sections rather than
/// nested tiles.
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
      backgroundColor: context.dreamColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(title: 'Portfolio', onBack: () => Navigator.pop(context)),
            Expanded(
              child: tradesAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, st) => _MessageState(
                  icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.bold),
                  title: 'Analytics unavailable',
                  subtitle: 'Performance data could not be loaded right now.',
                ),
                data: (trades) {
                  if (trades.isEmpty) {
                    return _MessageState(
                      icon: PhosphorIcons.chartLineUp(PhosphorIconsStyle.bold),
                      title: 'No performance data yet',
                      subtitle:
                          'Place your first order to start building your '
                          'trading analytics.',
                    );
                  }

                  final m = _PortfolioMetrics.fromTrades(trades);

                  return ListView(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 48.h),
                    children: [
                      _PnlHero(
                        realizedPnl: m.realizedPnl,
                        winRate: m.winRate,
                        closedCount: m.closedCount,
                      ),
                      SizedBox(height: 28.h),

                      _Section(
                        title: 'PERFORMANCE',
                        icon: PhosphorIcons.target(PhosphorIconsStyle.bold),
                        iconColor: AppColors.primary,
                        children: [
                          _WinRateRow(
                            winRate: m.winRate,
                            wins: m.wins,
                            losses: m.losses,
                          ),
                          const _Hairline(),
                          _StatRow(
                            label: 'Profit factor',
                            value: m.profitFactorLabel,
                            valueColor: m.profitFactor >= 1
                                ? AppColors.bullish
                                : AppColors.bearish,
                          ),
                          const _Hairline(),
                          _StatRow(
                            label: 'Average win',
                            value: m.wins == 0 ? '--' : formatPnl(m.avgWin),
                            valueColor: AppColors.bullish,
                          ),
                          const _Hairline(),
                          _StatRow(
                            label: 'Average loss',
                            value: m.losses == 0 ? '--' : formatPnl(m.avgLoss),
                            valueColor: AppColors.bearish,
                          ),
                          const _Hairline(),
                          _StatRow(
                            label: 'Best trade',
                            value: m.bestTrade == 0
                                ? '--'
                                : formatPnl(m.bestTrade),
                            valueColor: AppColors.bullish,
                          ),
                          const _Hairline(),
                          _StatRow(
                            label: 'Worst trade',
                            value: m.worstTrade == 0
                                ? '--'
                                : formatPnl(m.worstTrade),
                            valueColor: AppColors.bearish,
                          ),
                          const _Hairline(),
                          _StatRow(
                            label: m.streakIsWin
                                ? 'Current win streak'
                                : 'Current loss streak',
                            value: m.streak == 0 ? '--' : '${m.streak}',
                            valueColor: m.streak == 0
                                ? context.dreamColors.onSurface
                                : (m.streakIsWin
                                      ? AppColors.bullish
                                      : AppColors.bearish),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),

                      _Section(
                        title: 'ACTIVITY',
                        icon: PhosphorIcons.pulse(PhosphorIconsStyle.bold),
                        iconColor: const Color(0xFFFBBF24),
                        children: [
                          _StatRow(
                            label: 'Total volume',
                            value: formatCompact(m.totalVolume),
                          ),
                          const _Hairline(),
                          _StatRow(
                            label: 'Total fees paid',
                            value: formatUsdc(m.totalFees),
                          ),
                          const _Hairline(),
                          _StatRow(label: 'Trades', value: '${m.fillCount}'),
                          const _Hairline(),
                          _StatRow(
                            label: 'Preferred market',
                            value: m.topSymbol,
                            valueColor: AppColors.primaryLight,
                          ),
                          const _Hairline(),
                          _BiasRow(
                            longPct: m.longBias,
                            longCount: m.longCount,
                            shortCount: m.shortCount,
                          ),
                          const _Hairline(),
                          _StatRow(
                            label: 'Biggest single trade',
                            value: formatCompact(m.biggestNotional),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),

                      _Section(
                        title: 'LIVE EXPOSURE',
                        icon: PhosphorIcons.chartLine(PhosphorIconsStyle.bold),
                        iconColor: AppColors.bullish,
                        children: [
                          _StatRow(
                            label: 'Unrealized PnL',
                            value: formatPnl(totalUnrealizedPnl),
                            valueColor: totalUnrealizedPnl >= 0
                                ? AppColors.bullish
                                : AppColors.bearish,
                          ),
                          const _Hairline(),
                          _StatRow(
                            label: 'Equity balance',
                            value: equity > 0 ? formatCompact(equity) : '--',
                          ),
                          const _Hairline(),
                          _StatRow(
                            label: 'Open positions',
                            value: '${positions.length}',
                          ),
                          const _Hairline(),
                          _StatRow(
                            label: 'Average leverage',
                            value: positions.isEmpty
                                ? '--'
                                : '${avgLeverage.toStringAsFixed(1)}×',
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Metrics ───────────────────────────

class _PortfolioMetrics {
  final double realizedPnl;
  final int wins;
  final int losses;
  final double avgWin;
  final double avgLoss;
  final double bestTrade;
  final double worstTrade;
  final double profitFactor;
  final int streak;
  final bool streakIsWin;
  final double totalVolume;
  final double totalFees;
  final int fillCount;
  final String topSymbol;
  final double biggestNotional;
  final int longCount;
  final int shortCount;

  const _PortfolioMetrics({
    required this.realizedPnl,
    required this.wins,
    required this.losses,
    required this.avgWin,
    required this.avgLoss,
    required this.bestTrade,
    required this.worstTrade,
    required this.profitFactor,
    required this.streak,
    required this.streakIsWin,
    required this.totalVolume,
    required this.totalFees,
    required this.fillCount,
    required this.topSymbol,
    required this.biggestNotional,
    required this.longCount,
    required this.shortCount,
  });

  int get closedCount => wins + losses;
  double get winRate => closedCount == 0 ? 0 : wins / closedCount * 100;
  double get longBias {
    final total = longCount + shortCount;
    return total == 0 ? 0 : longCount / total * 100;
  }

  String get profitFactorLabel {
    if (closedCount == 0) return '--';
    if (profitFactor.isInfinite) return '∞';
    return profitFactor.toStringAsFixed(2);
  }

  factory _PortfolioMetrics.fromTrades(List<PhoenixTradeHistoryItem> trades) {
    const eps = 1e-9;

    // Chronological order (oldest → newest) for streak detection.
    final sorted = [...trades]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double realized = 0, grossProfit = 0, grossLoss = 0;
    double winSum = 0, lossSum = 0;
    double best = 0, worst = 0;
    int wins = 0, losses = 0;
    double totalVolume = 0, totalFees = 0, biggestNotional = 0;
    int longCount = 0, shortCount = 0;
    final counts = <String, int>{};

    for (final t in sorted) {
      realized += t.realizedPnl;
      totalFees += t.fee;
      final notional = t.price * t.size;
      totalVolume += notional;
      if (notional > biggestNotional) biggestNotional = notional;
      counts[t.symbol] = (counts[t.symbol] ?? 0) + 1;

      if (t.isOpeningFill || t.isIncreaseFill) {
        if (t.isBuy) {
          longCount++;
        } else {
          shortCount++;
        }
      }

      if (t.realizedPnl > eps) {
        wins++;
        winSum += t.realizedPnl;
        grossProfit += t.realizedPnl;
        if (t.realizedPnl > best) best = t.realizedPnl;
      } else if (t.realizedPnl < -eps) {
        losses++;
        lossSum += t.realizedPnl;
        grossLoss += -t.realizedPnl;
        if (t.realizedPnl < worst) worst = t.realizedPnl;
      }
    }

    // Current streak from the most recent closed trades.
    int streak = 0;
    bool streakIsWin = true;
    for (final t in sorted.reversed) {
      if (t.realizedPnl > eps) {
        if (streak == 0 || streakIsWin) {
          streakIsWin = true;
          streak++;
        } else {
          break;
        }
      } else if (t.realizedPnl < -eps) {
        if (streak == 0 || !streakIsWin) {
          streakIsWin = false;
          streak++;
        } else {
          break;
        }
      }
    }

    final topSymbol = counts.isEmpty
        ? '--'
        : counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return _PortfolioMetrics(
      realizedPnl: realized,
      wins: wins,
      losses: losses,
      avgWin: wins == 0 ? 0 : winSum / wins,
      avgLoss: losses == 0 ? 0 : lossSum / losses,
      bestTrade: best,
      worstTrade: worst,
      profitFactor: grossLoss <= eps
          ? (grossProfit > eps ? double.infinity : 0)
          : grossProfit / grossLoss,
      streak: streak,
      streakIsWin: streakIsWin,
      totalVolume: totalVolume,
      totalFees: totalFees,
      fillCount: trades.length,
      topSymbol: topSymbol,
      biggestNotional: biggestNotional,
      longCount: longCount,
      shortCount: shortCount,
    );
  }
}

// ─────────────────────────── UI pieces ───────────────────────────

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _TopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
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
            title,
            style: TextStyle(
              color: context.dreamColors.onSurface,
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PnlHero extends StatelessWidget {
  final double realizedPnl;
  final double winRate;
  final int closedCount;

  const _PnlHero({
    required this.realizedPnl,
    required this.winRate,
    required this.closedCount,
  });

  @override
  Widget build(BuildContext context) {
    final positive = realizedPnl >= 0;
    final color = positive ? AppColors.bullish : AppColors.bearish;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Realized PnL',
          style: TextStyle(
            color: context.dreamColors.muted,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              positive
                  ? PhosphorIcons.trendUp(PhosphorIconsStyle.bold)
                  : PhosphorIcons.trendDown(PhosphorIconsStyle.bold),
              color: color,
              size: 28.sp,
            ),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                closedCount == 0 ? '--' : formatPnl(realizedPnl),
                style: TextStyle(
                  color: color,
                  fontSize: 38.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            _HeroChip(
              label: 'Win rate',
              value: closedCount == 0 ? '--' : '${winRate.toStringAsFixed(0)}%',
            ),
            SizedBox(width: 10.w),
            _HeroChip(label: 'Closed', value: '$closedCount'),
          ],
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;
  final String value;
  const _HeroChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: context.dreamColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: context.dreamColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.dreamColors.muted,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            value,
            style: TextStyle(
              color: context.dreamColors.onSurface,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 6.h),
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
              Icon(icon, color: iconColor, size: 16.sp),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  color: context.dreamColors.muted,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ...children,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatRow({required this.label, required this.value, this.valueColor});

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

class _WinRateRow extends StatelessWidget {
  final double winRate;
  final int wins;
  final int losses;
  const _WinRateRow({
    required this.winRate,
    required this.wins,
    required this.losses,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (winRate / 100).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Win rate',
                style: TextStyle(
                  color: context.dreamColors.muted,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                wins + losses == 0
                    ? '--'
                    : '${winRate.toStringAsFixed(1)}%  ·  ${wins}W / ${losses}L',
                style: TextStyle(
                  color: context.dreamColors.onSurface,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6.h,
              backgroundColor: AppColors.bearish.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(AppColors.bullish),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiasRow extends StatelessWidget {
  final double longPct;
  final int longCount;
  final int shortCount;
  const _BiasRow({
    required this.longPct,
    required this.longCount,
    required this.shortCount,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (longPct / 100).clamp(0.0, 1.0);
    final hasData = longCount + shortCount > 0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Long / short bias',
                style: TextStyle(
                  color: context.dreamColors.muted,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                hasData ? '${longPct.toStringAsFixed(0)}% long' : '--',
                style: TextStyle(
                  color: context.dreamColors.onSurface,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: hasData ? fraction : 0,
              minHeight: 6.h,
              backgroundColor: AppColors.bearish.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(AppColors.bullish),
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

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.dreamColors.mutedSecondary, size: 44.sp),
            SizedBox(height: 14.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.dreamColors.onSurface,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.dreamColors.muted,
                fontSize: 13.sp,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
