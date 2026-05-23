import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

// Sorting modes for the markets list
enum MarketSortMode { change, volume, oi, funding }

// ---------------------------------------------------------------------------
// Markets page header — search + sort chips
// ---------------------------------------------------------------------------

class MarketsHeader extends StatelessWidget {
  final TextEditingController searchCtrl;
  final MarketSortMode sort;
  final bool sortDesc;
  final bool watchlistOnly;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<MarketSortMode> onSortChanged;
  final VoidCallback onWatchlistOnlyToggled;
  final VoidCallback onRefresh;

  const MarketsHeader({
    super.key,
    required this.searchCtrl,
    required this.sort,
    required this.sortDesc,
    required this.watchlistOnly,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onWatchlistOnlyToggled,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 0),
            child: Row(
              children: [
                Text(
                  'Markets',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onRefresh,
                  icon: Icon(
                    Icons.refresh,
                    color: AppColors.textSecondaryDark,
                    size: 20.sp,
                  ),
                  padding: EdgeInsets.all(8.w),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
            child: SizedBox(
              height: 36.h,
              child: TextField(
                controller: searchCtrl,
                onChanged: onQueryChanged,
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 13.sp,
                ),
                decoration: InputDecoration(
                  hintText: 'Search markets…',
                  hintStyle: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 13.sp,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textMutedDark,
                    size: 16.sp,
                  ),
                  filled: true,
                  fillColor: AppColors.cardDark,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12.w,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: AppColors.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: AppColors.borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Sort chips + watchlist filter row
          SizedBox(
            height: 30.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 0),
              children: [
                // Watchlist filter chip
                _WatchlistChip(
                  active: watchlistOnly,
                  onTap: onWatchlistOnlyToggled,
                ),
                SizedBox(width: 6.w),
                MarketsSortChip(
                  label: '24h %',
                  mode: MarketSortMode.change,
                  current: sort,
                  sortDesc: sortDesc,
                  onTap: () => onSortChanged(MarketSortMode.change),
                ),
                SizedBox(width: 6.w),
                MarketsSortChip(
                  label: 'Volume',
                  mode: MarketSortMode.volume,
                  current: sort,
                  sortDesc: sortDesc,
                  onTap: () => onSortChanged(MarketSortMode.volume),
                ),
                SizedBox(width: 6.w),
                MarketsSortChip(
                  label: 'OI',
                  mode: MarketSortMode.oi,
                  current: sort,
                  sortDesc: sortDesc,
                  onTap: () => onSortChanged(MarketSortMode.oi),
                ),
                SizedBox(width: 6.w),
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
          SizedBox(height: 8.h),
        ],
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
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: active
              ? starColor.withValues(alpha: 0.15)
              : AppColors.cardDark,
          borderRadius: BorderRadius.circular(6.r),
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
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
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
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.cardDark,
          borderRadius: BorderRadius.circular(6.r),
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
