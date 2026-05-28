import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dream_colors.dart';

// =============================================================================
// PRIMARY BUTTON - Large tactile CTA
// =============================================================================
class DreamPrimaryButton extends StatelessWidget {
  const DreamPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 56.h,
      decoration: BoxDecoration(
        gradient: onPressed != null && !isLoading
            ? AppColors.primaryGradient
            : null,
        color: onPressed == null || isLoading ? AppColors.gray700 : null,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: onPressed != null && !isLoading
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 16.r,
                  offset: Offset(0, 4.h),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16.r),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 24.w,
                    height: 24.h,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5.w,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20.sp),
                        SizedBox(width: 8.w),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// GHOST BUTTON - Outline style
// =============================================================================
class DreamGhostButton extends StatelessWidget {
  const DreamGhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 48.h,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16.r),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: context.dreamColors.onSurface, size: 18.sp),
                  SizedBox(width: 8.w),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: context.dreamColors.onSurface,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ICON BUTTON - Circular icon action
// =============================================================================
class DreamIconButton extends StatelessWidget {
  const DreamIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.isActive = false,
    this.size,
    this.backgroundColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;
  final double? size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final buttonSize = size ?? 44.r;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color:
              backgroundColor ??
              (isActive
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05)),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive
                ? AppColors.primary.withOpacity(0.3)
                : Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.primary : context.dreamColors.muted,
          size: (buttonSize * 0.5).sp,
        ),
      ),
    );
  }
}
