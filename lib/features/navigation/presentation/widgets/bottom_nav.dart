import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../positions/providers/positions_provider.dart';
import '../../providers/bottom_nav_providers.dart';

// ---------------------------------------------------------------------------
// Bottom navigation bar for the 4-tab trading shell
// ---------------------------------------------------------------------------

class ShellBottomNav extends ConsumerWidget {
  final int currentIndex;
  const ShellBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posState = ref.watch(positionsProvider);
    final openCount = posState.positions.length + posState.openOrders.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        border: Border(
          top: BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58.h,
          child: Row(
            children: [
              ShellNavItem(
                icon: PhosphorIcons.chartLine(),
                activeIcon: PhosphorIcons.chartLine(PhosphorIconsStyle.fill),
                label: 'Markets',
                index: 0,
                currentIndex: currentIndex,
              ),
              ShellNavItem(
                icon: PhosphorIcons.arrowsLeftRight(),
                activeIcon: PhosphorIcons.arrowsLeftRight(
                  PhosphorIconsStyle.fill,
                ),
                label: 'Trade',
                index: 1,
                currentIndex: currentIndex,
              ),
              ShellNavItem(
                icon: PhosphorIcons.listBullets(),
                activeIcon: PhosphorIcons.listBullets(PhosphorIconsStyle.fill),
                label: 'Positions',
                index: 2,
                currentIndex: currentIndex,
                badgeCount: openCount,
              ),
              ShellNavItem(
                icon: PhosphorIcons.user(),
                activeIcon: PhosphorIcons.user(PhosphorIconsStyle.fill),
                label: 'Account',
                index: 3,
                currentIndex: currentIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single nav tab item with optional badge
// ---------------------------------------------------------------------------

class ShellNavItem extends ConsumerWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final int badgeCount;

  const ShellNavItem({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = index == currentIndex;
    final color = selected ? AppColors.primary : AppColors.gray600;

    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(bottomNavIndexProvider.notifier).setIndex(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? activeIcon : icon, color: color, size: 22.sp),
                if (badgeCount > 0)
                  Positioned(
                    top: -4.h,
                    right: -6.w,
                    child: Container(
                      constraints: BoxConstraints(minWidth: 14.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(7.r),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 3.h),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.sp,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
