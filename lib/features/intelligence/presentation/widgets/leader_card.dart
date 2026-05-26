import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/intelligence_models.dart';

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

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.borderDark.withValues(alpha: 0.6),
        ),
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
                        color: AppColors.textPrimaryDark,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${leader.address.substring(0, 4)}…${leader.address.substring(leader.address.length - 4)}',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 11.sp,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              _FollowButton(
                isFollowing: isFollowing,
                onTap: onFollow,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _StatChip(
                label: '7d P&L',
                value: _formatPnl(leader.pnl7d),
                valueColor: leader.pnl7d >= 0
                    ? AppColors.bullish
                    : AppColors.bearish,
              ),
              SizedBox(width: 8.w),
              _StatChip(
                label: 'Win Rate',
                value: '${(leader.winRate * 100).toStringAsFixed(0)}%',
              ),
              SizedBox(width: 8.w),
              _StatChip(
                label: 'Trades',
                value: '${leader.totalTrades}',
              ),
              SizedBox(width: 8.w),
              _StatChip(
                label: 'Open',
                value: '${leader.openPositions.length}',
              ),
            ],
          ),
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

  String _formatPnl(double pnl) {
    if (pnl.abs() >= 1000) {
      return '${pnl >= 0 ? '+' : ''}\$${(pnl / 1000).toStringAsFixed(1)}k';
    }
    return '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(0)}';
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
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
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
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                )
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
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimaryDark,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMutedDark,
              fontSize: 9.sp,
            ),
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
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.borderDark.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
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
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  height: 9.h,
                  width: 60.w,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
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
