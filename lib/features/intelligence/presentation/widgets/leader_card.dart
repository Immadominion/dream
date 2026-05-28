import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../models/intelligence_models.dart';
import '../../../../core/theme/dream_colors.dart';

class LeaderCard extends StatelessWidget {
  final LeaderProfile leader;
  final bool isFollowing;
  final VoidCallback? onFollow;

  const LeaderCard({
    super.key,
    required this.leader,
    this.isFollowing = false,
    this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    if (leader.isLoading) return _Skeleton();

    final pnlAvailable = leader.hasPnlHistory;
    final pnlColor = leader.pnl7d >= 0 ? AppColors.bullish : AppColors.bearish;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: context.dreamColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: context.dreamColors.stroke.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(leader: leader),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leader.displayLabel,
                      style: TextStyle(
                        color: context.dreamColors.onSurface,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        _LiveBadge(active: leader.isRegistered),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            _short(leader.address),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.dreamColors.mutedSecondary,
                              fontSize: 11.sp,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _FollowButton(isFollowing: isFollowing, onTap: onFollow),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: '7d P&L',
                  value: pnlAvailable ? formatPnl(leader.pnl7d) : '--',
                  valueColor: pnlAvailable ? pnlColor : null,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _StatChip(
                  label: 'Win Rate',
                  value: leader.hasTradeStats
                      ? '${(leader.winRate * 100).toStringAsFixed(0)}%'
                      : '--',
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _StatChip(
                  label: 'Trades',
                  value: leader.hasTradeStats ? '${leader.totalTrades}' : '--',
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _StatChip(
                  label: 'Open',
                  value: leader.hasOpenPositions
                      ? '${leader.openPositions.length}'
                      : '0',
                ),
              ),
            ],
          ),
          if (leader.equity > 0 || leader.openNotional > 0) ...[
            SizedBox(height: 10.h),
            Row(
              children: [
                _InlineMetric(
                  label: 'Equity',
                  value: formatCompact(leader.equity),
                ),
                SizedBox(width: 10.w),
                _InlineMetric(
                  label: 'Open notional',
                  value: leader.openNotional > 0
                      ? formatCompact(leader.openNotional)
                      : '--',
                ),
              ],
            ),
          ],
          if (leader.openPositions.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 4.h,
              children: leader.openPositions
                  .take(3)
                  .map(_PositionPill.new)
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _short(String address) =>
      '${address.substring(0, 4)}…${address.substring(address.length - 4)}';
}

class _LiveBadge extends StatelessWidget {
  final bool active;
  const _LiveBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : context.dreamColors.mutedSecondary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        active ? 'LIVE' : 'NO ACCOUNT',
        style: TextStyle(
          color: color,
          fontSize: 8.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InlineMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Text(
            '$label ',
            style: TextStyle(color: context.dreamColors.mutedSecondary, fontSize: 10.sp),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.dreamColors.muted,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final LeaderProfile leader;
  const _Avatar({required this.leader});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36.r,
      height: 36.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          leader.displayLabel.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: AppColors.primaryLight,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback? onTap;

  const _FollowButton({required this.isFollowing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isFollowing
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.primary,
          borderRadius: BorderRadius.circular(20.r),
          border: isFollowing
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
              : null,
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
            color: isFollowing ? AppColors.primary : Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatChip({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: context.dreamColors.surface,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? context.dreamColors.onSurface,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            label,
            style: TextStyle(color: context.dreamColors.mutedSecondary, fontSize: 9.sp),
          ),
        ],
      ),
    );
  }
}

class _PositionPill extends StatelessWidget {
  final LeaderPosition position;
  const _PositionPill(this.position);

  @override
  Widget build(BuildContext context) {
    final isLong = position.side == 'long';
    final color = isLong ? AppColors.bullish : AppColors.bearish;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLong
                ? PhosphorIcons.trendUp(PhosphorIconsStyle.bold)
                : PhosphorIcons.trendDown(PhosphorIconsStyle.bold),
            color: color,
            size: 10.r,
          ),
          SizedBox(width: 3.w),
          Text(
            position.market.replaceAll('-PERP', ''),
            style: TextStyle(
              color: color,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      height: 80.h,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: context.dreamColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: context.dreamColors.stroke.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              color: context.dreamColors.surface,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 11.h,
                  width: 100.w,
                  decoration: BoxDecoration(
                    color: context.dreamColors.surface,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  height: 9.h,
                  width: 60.w,
                  decoration: BoxDecoration(
                    color: context.dreamColors.surface,
                    borderRadius: BorderRadius.circular(4.r),
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
