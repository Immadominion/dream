import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../positions/providers/positions_provider.dart';
import '../../providers/bottom_nav_providers.dart';

// ---------------------------------------------------------------------------
// Bottom navigation bar for the primary mobile shell
// ---------------------------------------------------------------------------

class ShellBottomNav extends ConsumerWidget {
  final int currentIndex;
  const ShellBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(bottomNavVisibilityProvider);
    final posState = ref.watch(positionsProvider);
    final openCount = posState.positions.length + posState.openOrders.length;
    final inMarketFlow = currentIndex == 0 || currentIndex == 1;

    return IgnorePointer(
      ignoring: !isVisible,
      child: SafeArea(
        top: false,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          offset: Offset(0, isVisible ? 0 : 1.3),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            opacity: isVisible ? 1 : 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(48.w, 8.h, 48.w, 12.h),
              child: _GlassPill(
                child: Row(
                  children: [
                    Expanded(
                      child: ShellNavItem(
                        icon: PhosphorIcons.storefront(),
                        activeIcon: PhosphorIcons.storefront(
                          PhosphorIconsStyle.duotone,
                        ),
                        label: 'Markets',
                        selected: inMarketFlow,
                        onTap: () => ref
                            .read(bottomNavIndexProvider.notifier)
                            .setIndex(0),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: ShellNavItem(
                        icon: PhosphorIcons.brain(),
                        activeIcon: PhosphorIcons.brain(
                          PhosphorIconsStyle.duotone,
                        ),
                        label: 'Intelligence',
                        selected: currentIndex == 4,
                        onTap: () => ref
                            .read(bottomNavIndexProvider.notifier)
                            .setIndex(4),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: ShellNavItem(
                        icon: PhosphorIcons.bag(),
                        activeIcon: PhosphorIcons.bag(
                          PhosphorIconsStyle.duotone,
                        ),
                        label: 'Positions',
                        selected: currentIndex == 2,
                        badgeCount: openCount,
                        onTap: () => ref
                            .read(bottomNavIndexProvider.notifier)
                            .setIndex(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Frosted-glass pill container
// ---------------------------------------------------------------------------

class _GlassPill extends StatelessWidget {
  final Widget child;
  const _GlassPill({required this.child});

  @override
  Widget build(BuildContext context) {
    const radius = 48.0;
    return DecoratedBox(
      // Shadow lives outside the ClipRRect so it isn't clipped.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.44),
            blurRadius: 40,
            spreadRadius: -10,
            offset: const Offset(1, 3),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 32,
            spreadRadius: -16,
            offset: const Offset(-1, -3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 48.h,
            padding: EdgeInsets.all(4.r),
            decoration: BoxDecoration(
              // Semi-transparent fill — blurred content shows through.
              color: AppColors.cardDark.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: AppColors.borderDark.withValues(alpha: 0.85),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single nav tab item with optional badge
// Active  → indigo pill, icon + animated label
// Inactive → icon only, transparent background
// ---------------------------------------------------------------------------

class ShellNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const ShellNavItem({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? AppColors.primaryLight
        : AppColors.textSecondaryDark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        height: double.maxFinite,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(32.r),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.30)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            // Icon — always visible
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  color: iconColor,
                  size: 20.sp,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4.h,
                    right: -7.w,
                    child: Container(
                      constraints: BoxConstraints(minWidth: 15.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),

            // Label — only when selected, animates in/out
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: EdgeInsets.only(left: 7.w),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
