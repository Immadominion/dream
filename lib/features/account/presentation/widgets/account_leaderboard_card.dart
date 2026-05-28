import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../account/presentation/widgets/account_history_providers.dart';
import '../../../../core/theme/dream_colors.dart';

// ---------------------------------------------------------------------------
// Tier definitions
// ---------------------------------------------------------------------------

enum _Tier {
  bronze,
  silver,
  gold,
  diamond;

  String get label {
    switch (this) {
      case _Tier.bronze:
        return 'Bronze';
      case _Tier.silver:
        return 'Silver';
      case _Tier.gold:
        return 'Gold';
      case _Tier.diamond:
        return 'Diamond';
    }
  }

  Color get color {
    switch (this) {
      case _Tier.bronze:
        return const Color(0xFFCD7F32);
      case _Tier.silver:
        return const Color(0xFFC0C0C0);
      case _Tier.gold:
        return const Color(0xFFFFD700);
      case _Tier.diamond:
        return const Color(0xFF6EC6F5);
    }
  }

  IconData get icon {
    switch (this) {
      case _Tier.bronze:
        return Icons.workspace_premium_outlined;
      case _Tier.silver:
        return Icons.workspace_premium_outlined;
      case _Tier.gold:
        return Icons.emoji_events_outlined;
      case _Tier.diamond:
        return Icons.diamond_outlined;
    }
  }

  /// Volume thresholds (USD notional).
  /// Bronze < 10K | Silver < 100K | Gold < 1M | Diamond ≥ 1M
  String get nextLevelHint {
    switch (this) {
      case _Tier.bronze:
        return 'Trade \$10K+ to reach Silver';
      case _Tier.silver:
        return 'Trade \$100K+ to reach Gold';
      case _Tier.gold:
        return 'Trade \$1M+ to reach Diamond';
      case _Tier.diamond:
        return 'Elite Diamond trader';
    }
  }
}

_Tier _tierFromVolume(double volume) {
  if (volume >= 1_000_000) return _Tier.diamond;
  if (volume >= 100_000) return _Tier.gold;
  if (volume >= 10_000) return _Tier.silver;
  return _Tier.bronze;
}

double _progressToNextTier(double volume) {
  if (volume >= 1_000_000) return 1.0;
  if (volume >= 100_000) return (volume - 100_000) / (1_000_000 - 100_000);
  if (volume >= 10_000) return (volume - 10_000) / (100_000 - 10_000);
  return volume / 10_000;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Shows the trader's tier badge and volume stats computed natively from
/// the trader's recent fills.
class AccountLeaderboardCard extends ConsumerWidget {
  const AccountLeaderboardCard({super.key, required this.walletAddress});

  final String walletAddress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(accountTradeHistoryProvider(walletAddress));

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: context.dreamColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: context.dreamColors.stroke),
      ),
      child: tradesAsync.when(
        loading: () => _buildLoading(context),
        error: (err, st) => _buildError(),
        data: (trades) => _buildContent(context, trades),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18.w,
          height: 18.w,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          'Loading trader stats…',
          style: TextStyle(color: context.dreamColors.muted, fontSize: 12.sp),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Text(
      'Failed to load leaderboard data',
      style: TextStyle(color: AppColors.bearish, fontSize: 12.sp),
    );
  }

  Widget _buildContent(BuildContext context, List trades) {
    // Compute stats from trade history
    final totalVolume = trades.fold<double>(
      0,
      (s, t) => s + (t.price as double) * (t.size as double),
    );
    final totalFees = trades.fold<double>(0, (s, t) => s + (t.fee as double));
    final tradeCount = trades.length;

    final tier = _tierFromVolume(totalVolume);
    final progress = _progressToNextTier(totalVolume);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ───────────────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                color: tier.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              alignment: Alignment.center,
              child: Icon(tier.icon, color: tier.color, size: 16.sp),
            ),
            SizedBox(width: 10.w),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trader Rank',
                    style: TextStyle(
                      color: context.dreamColors.onSurface,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Based on last 50 filled trades',
                    style: TextStyle(
                      color: context.dreamColors.muted,
                      fontSize: 11.sp,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            // Tier badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: tier.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: tier.color.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tier.icon, color: tier.color, size: 11.sp),
                  SizedBox(width: 4.w),
                  Text(
                    tier.label,
                    style: TextStyle(
                      color: tier.color,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 14.h),

        // ── Progress bar ─────────────────────────────────────────────────
        _ProgressBar(progress: progress, tier: tier),
        SizedBox(height: 6.h),
        Text(
          tier.nextLevelHint,
          style: TextStyle(
            color: context.dreamColors.mutedSecondary,
            fontSize: 10.sp,
          ),
        ),

        SizedBox(height: 14.h),

        // ── Stats row ────────────────────────────────────────────────────
        Row(
          children: [
            _StatItem(
              label: 'Volume (50T)',
              value: formatCompact(totalVolume),
              flex: 2,
            ),
            _StatItem(label: 'Trades', value: tradeCount.toString()),
            _StatItem(
              label: 'Fees Paid',
              value: formatCompact(totalFees),
              isLast: true,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.tier});

  final double progress;
  final _Tier tier;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Track
            Container(
              height: 6.h,
              decoration: BoxDecoration(
                color: context.dreamColors.surface,
                borderRadius: BorderRadius.circular(3.r),
              ),
            ),
            // Fill
            Container(
              height: 6.h,
              width: constraints.maxWidth * progress.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: tier.color,
                borderRadius: BorderRadius.circular(3.r),
                boxShadow: [
                  BoxShadow(
                    color: tier.color.withValues(alpha: 0.4),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.flex = 1,
    this.isLast = false,
  });

  final String label;
  final String value;
  final int flex;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        margin: EdgeInsets.only(right: isLast ? 0 : 6.w),
        decoration: BoxDecoration(
          color: context.dreamColors.surface,
          borderRadius: BorderRadius.circular(7.r),
          border: Border.all(color: context.dreamColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.dreamColors.mutedSecondary,
                fontSize: 10.sp,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(
              value,
              style: TextStyle(
                color: context.dreamColors.onSurface,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
