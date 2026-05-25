import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

// Sorting modes for the markets list
enum MarketSortMode { change, volume, oi, funding }

// Three-state sort direction per filter: descending → ascending → none (off)
enum SortDirection { desc, asc, none }

// ---------------------------------------------------------------------------
// Markets page header — multi-filter chips
// Each chip cycles independently: none → desc → asc → none
// Multiple chips can be active at once (composite sort in markets_page)
// ---------------------------------------------------------------------------

class MarketsHeader extends StatelessWidget {
  final Map<MarketSortMode, SortDirection> activeFilters;
  final ValueChanged<MarketSortMode> onSortTapped;

  const MarketsHeader({
    super.key,
    required this.activeFilters,
    required this.onSortTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 2.h),
      child: Row(
        children: [
          MarketsSortChip(
            label: '24h Vol',
            mode: MarketSortMode.volume,
            dir: activeFilters[MarketSortMode.volume] ?? SortDirection.none,
            onTap: () => onSortTapped(MarketSortMode.volume),
          ),
          const Spacer(),
          MarketsSortChip(
            label: '24h %',
            mode: MarketSortMode.change,
            dir: activeFilters[MarketSortMode.change] ?? SortDirection.none,
            onTap: () => onSortTapped(MarketSortMode.change),
          ),
          SizedBox(width: 10.w),
          MarketsSortChip(
            label: 'OI',
            mode: MarketSortMode.oi,
            dir: activeFilters[MarketSortMode.oi] ?? SortDirection.none,
            onTap: () => onSortTapped(MarketSortMode.oi),
          ),
          SizedBox(width: 10.w),
          MarketsSortChip(
            label: 'Funding',
            mode: MarketSortMode.funding,
            dir: activeFilters[MarketSortMode.funding] ?? SortDirection.none,
            onTap: () => onSortTapped(MarketSortMode.funding),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sort chip — plain text + stacked up/down arrows (Bybit-style)
// Three states per chip: desc (↓ lit), asc (↑ lit), none (both dim)
// ---------------------------------------------------------------------------

class MarketsSortChip extends StatelessWidget {
  final String label;
  final MarketSortMode mode;
  final SortDirection dir;
  final VoidCallback onTap;

  const MarketsSortChip({
    super.key,
    required this.label,
    required this.mode,
    required this.dir,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = dir != SortDirection.none;
    final upLit = dir == SortDirection.asc;
    final downLit = dir == SortDirection.desc;

    final labelColor = isActive
        ? AppColors.textPrimaryDark
        : AppColors.textSecondaryDark;
    final dimArrow = AppColors.textMutedDark.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 11.sp,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            SizedBox(width: 1.w),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, 2.h),
                  child: Icon(
                    Icons.arrow_drop_up_rounded,
                    size: 13.sp,
                    color: upLit ? AppColors.primary : dimArrow,
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -2.h),
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 13.sp,
                    color: downLit ? AppColors.primary : dimArrow,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
