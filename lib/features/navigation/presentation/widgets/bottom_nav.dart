import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../positions/providers/positions_provider.dart';
import '../../providers/bottom_nav_providers.dart';
import '../../../../core/theme/dream_colors.dart';

// ---------------------------------------------------------------------------
// Bottom navigation bar for the primary mobile shell
// ---------------------------------------------------------------------------

/// Visual order of tabs in the pill: Markets → Intelligence → Positions.
/// Values are actual tab indices used by [bottomNavIndexProvider].
const _kTabOrder = [0, 4, 2];

class ShellBottomNav extends ConsumerStatefulWidget {
  final int currentIndex;
  const ShellBottomNav({super.key, required this.currentIndex});

  @override
  ConsumerState<ShellBottomNav> createState() => _ShellBottomNavState();
}

class _ShellBottomNavState extends ConsumerState<ShellBottomNav> {
  /// Visual position (0-2) being previewed during a drag. Null = not dragging.
  int? _dragVisualIndex;

  /// X position where the current drag started, for delta calculation.
  double? _dragStartX;

  int _currentVisual() {
    final i = widget.currentIndex;
    if (i == 0 || i == 1) return 0; // Markets flow
    if (i == 4) return 1; // Intelligence
    if (i == 2) return 2; // Positions
    return 0;
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartX = details.localPosition.dx;
  }

  /// Delta-based: swipe LEFT (negative delta) → next tab (higher visual index).
  /// Swipe RIGHT (positive delta) → previous tab (lower visual index).
  void _onDragUpdate(DragUpdateDetails details) {
    if (_dragStartX == null || _dragVisualIndex != null) return;
    final delta = details.localPosition.dx - _dragStartX!;
    final threshold = 36.w;

    if (delta < -threshold) {
      // Swipe left → go to next tab (right in visual order)
      final next = (_currentVisual() + 1).clamp(0, 2);
      if (next != _currentVisual()) {
        setState(() => _dragVisualIndex = next);
        HapticFeedback.selectionClick();
      }
    } else if (delta > threshold) {
      // Swipe right → go to previous tab (left in visual order)
      final prev = (_currentVisual() - 1).clamp(0, 2);
      if (prev != _currentVisual()) {
        setState(() => _dragVisualIndex = prev);
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onDragEnd(DragEndDetails _) {
    final visual = _dragVisualIndex;
    setState(() {
      _dragVisualIndex = null;
      _dragStartX = null;
    });
    if (visual == null) return;
    if (visual != _currentVisual()) {
      HapticFeedback.mediumImpact();
      ref.read(bottomNavIndexProvider.notifier).setIndex(_kTabOrder[visual]);
    }
  }

  void _onDragCancel() => setState(() {
    _dragVisualIndex = null;
    _dragStartX = null;
  });

  @override
  Widget build(BuildContext context) {
    final isVisible = ref.watch(bottomNavVisibilityProvider);
    final posState = ref.watch(positionsProvider);
    final openCount = posState.positions.length + posState.openOrders.length;

    // Effective visual index: drag preview takes priority over committed state.
    final effectiveVisual = _dragVisualIndex ?? _currentVisual();

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
              padding: EdgeInsets.fromLTRB(40.w, 8.h, 40.w, 12.h),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Fluid widths: active tab grows to fit its label,
                  // inactive tabs shrink to icon-only size.
                  // Subtract _GlassPill's effective horizontal padding:
                  //   4.r explicit padding × 2 sides = 8.r
                  //   Border.all() width (1.0) × 2 sides = 2.0
                  // Flutter's Container adds border.dimensions to explicit padding.
                  final gap = 6.w;
                  final available = constraints.maxWidth - 8.r - 2.0;
                  final activeWidth = available * 0.54;
                  final inactiveWidth = (available - activeWidth - gap * 2) / 2;

                  double w(int visual) =>
                      effectiveVisual == visual ? activeWidth : inactiveWidth;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: _onDragStart,
                    onHorizontalDragUpdate: _onDragUpdate,
                    onHorizontalDragEnd: _onDragEnd,
                    onHorizontalDragCancel: _onDragCancel,
                    child: _GlassPill(
                      child: Row(
                        children: [
                          AnimatedContainer(
                            width: w(0),
                            height: 60.h,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            child: ShellNavItem(
                              icon: PhosphorIcons.storefront(),
                              activeIcon: PhosphorIcons.storefront(
                                PhosphorIconsStyle.duotone,
                              ),
                              label: 'Markets',
                              selected: effectiveVisual == 0,
                              onTap: () => ref
                                  .read(bottomNavIndexProvider.notifier)
                                  .setIndex(0),
                            ),
                          ),
                          SizedBox(width: gap),
                          AnimatedContainer(
                            width: w(1),
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            child: ShellNavItem(
                              icon: PhosphorIcons.sparkle(),
                              activeIcon: PhosphorIcons.sparkle(
                                PhosphorIconsStyle.duotone,
                              ),
                              label: 'Intelligence',
                              selected: effectiveVisual == 1,
                              onTap: () => ref
                                  .read(bottomNavIndexProvider.notifier)
                                  .setIndex(4),
                            ),
                          ),
                          SizedBox(width: gap),
                          AnimatedContainer(
                            width: w(2),
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            child: ShellNavItem(
                              icon: PhosphorIcons.bag(),
                              activeIcon: PhosphorIcons.bag(
                                PhosphorIconsStyle.duotone,
                              ),
                              label: 'Positions',
                              selected: effectiveVisual == 2,
                              badgeCount: openCount,
                              onTap: () => ref
                                  .read(bottomNavIndexProvider.notifier)
                                  .setIndex(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
            height: 60.h,
            padding: EdgeInsets.all(4.r),
            decoration: BoxDecoration(
              // Semi-transparent fill — blurred content shows through.
              color: context.dreamColors.surfaceVariant.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: context.dreamColors.stroke.withValues(alpha: 0.85),
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
        : context.dreamColors.muted;
    final badgeLabel = badgeCount > 99 ? '99+' : '$badgeCount';
    final isSingleDigitBadge = badgeLabel.length == 1;

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
                      constraints: BoxConstraints(
                        minWidth: isSingleDigitBadge ? 16.r : 18.w,
                        minHeight: 16.r,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSingleDigitBadge ? 0 : 4.w,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999.r),
                        border: Border.all(
                          color: context.dreamColors.background,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          badgeLabel,
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
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.dreamColors.onSurface,
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
