import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';

// =============================================================================
// TAG / BADGE - Pill-shaped status indicators
// =============================================================================
enum DreamTagVariant { success, error, warning, primary, neutral }

class DreamTag extends StatelessWidget {
  const DreamTag({
    super.key,
    required this.label,
    this.variant = DreamTagVariant.neutral,
    this.icon,
    this.onTap,
  });

  final String label;
  final DreamTagVariant variant;
  final IconData? icon;
  final VoidCallback? onTap;

  Color get _color {
    switch (variant) {
      case DreamTagVariant.success:
        return AppColors.success;
      case DreamTagVariant.error:
        return AppColors.error;
      case DreamTagVariant.warning:
        return AppColors.warning;
      case DreamTagVariant.primary:
        return AppColors.primary;
      case DreamTagVariant.neutral:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tag = Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: _color.withOpacity(
          variant == DreamTagVariant.neutral ? 0.05 : 0.12,
        ),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: _color.withOpacity(
            variant == DreamTagVariant.neutral ? 0.08 : 0.2,
          ),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: _color.withOpacity(
                variant == DreamTagVariant.neutral ? 0.6 : 1,
              ),
              size: 12.sp,
            ),
            SizedBox(width: 4.w),
          ],
          Text(
            label,
            style: TextStyle(
              color: _color.withOpacity(
                variant == DreamTagVariant.neutral ? 0.7 : 1,
              ),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: tag);
    }

    return tag;
  }
}

// =============================================================================
// PRICE CHANGE TAG - For bullish/bearish indicators
// =============================================================================
class DreamPriceTag extends StatelessWidget {
  const DreamPriceTag({super.key, required this.change, this.showIcon = true});

  final double change;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final isPositive = change >= 0;
    final color = isPositive ? AppColors.bullish : AppColors.bearish;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon)
            Icon(
              isPositive ? PhosphorIcons.trendUp() : PhosphorIcons.trendDown(),
              color: color,
              size: 12.sp,
            ),
          if (showIcon) SizedBox(width: 4.w),
          Text(
            '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%',
            style: TextStyle(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
