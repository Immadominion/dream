import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

// Sorting modes for the markets list
enum MarketSortMode { change, volume, oi, funding }

// ---------------------------------------------------------------------------
// Markets page header — filter chips only
// ---------------------------------------------------------------------------

class MarketsHeader extends StatelessWidget {
  final MarketSortMode sort;
  final bool sortDesc;
  final bool watchlistOnly;
  final ValueChanged<MarketSortMode> onSortChanged;
  final VoidCallback onWatchlistOnlyToggled;

  const MarketsHeader({
    super.key,
    required this.sort,
    required this.sortDesc,
    required this.watchlistOnly,
    required this.onSortChanged,
    required this.onWatchlistOnlyToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: SizedBox(
        height: 36.h,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _WatchlistChip(
              active: watchlistOnly,
              onTap: onWatchlistOnlyToggled,
            ),
            SizedBox(width: 8.w),
            MarketsSortChip(
              label: '24h %',
              mode: MarketSortMode.change,
              current: sort,
              sortDesc: sortDesc,
              onTap: () => onSortChanged(MarketSortMode.change),
            ),
            SizedBox(width: 8.w),
            MarketsSortChip(
              label: 'Volume',
              mode: MarketSortMode.volume,
              current: sort,
              sortDesc: sortDesc,
              onTap: () => onSortChanged(MarketSortMode.volume),
            ),
            SizedBox(width: 8.w),
            MarketsSortChip(
              label: 'OI',
              mode: MarketSortMode.oi,
              current: sort,
              sortDesc: sortDesc,
              onTap: () => onSortChanged(MarketSortMode.oi),
            ),
            SizedBox(width: 8.w),
            MarketsSortChip(
              label: 'Funding',
              mode: MarketSortMode.funding,
              current: sort,
              sortDesc: sortDesc,
              onTap: () => onSortChanged(MarketSortMode.funding),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Watchlist filter chip — "⭐ Starred"
// ---------------------------------------------------------------------------

class _WatchlistChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _WatchlistChip({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const starColor = Color(0xFFF5C518);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: active
              ? starColor.withValues(alpha: 0.15)
              : AppColors.cardDark,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: active ? starColor : AppColors.borderDark,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 13.sp,
              color: active ? starColor : AppColors.textSecondaryDark,
            ),
            SizedBox(width: 4.w),
            Text(
              'Starred',
              style: TextStyle(
                color: active ? starColor : AppColors.textSecondaryDark,
                fontSize: 11.sp,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sort chip pill
// ---------------------------------------------------------------------------

class MarketsSortChip extends StatelessWidget {
  final String label;
  final MarketSortMode mode;
  final MarketSortMode current;
  final bool sortDesc;
  final VoidCallback onTap;

  const MarketsSortChip({
    super.key,
    required this.label,
    required this.mode,
    required this.current,
    required this.sortDesc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == mode;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.14)
              : AppColors.cardDark,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.borderDark,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.primary : AppColors.textSecondaryDark,
                fontSize: 11.sp,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (active) ...[
              SizedBox(width: 2.w),
              Icon(
                sortDesc ? Icons.arrow_downward : Icons.arrow_upward,
                size: 10.sp,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
