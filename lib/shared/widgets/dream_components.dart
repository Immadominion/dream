import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';

// =============================================================================
// GLASS CARD - Premium glassmorphic container
// =============================================================================
class DreamCard extends StatelessWidget {
  const DreamCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.glowColor,
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? glowColor;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = Container(
      margin: margin,
      padding: padding ?? EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: glowColor != null
            ? [
                BoxShadow(
                  color: glowColor!.withOpacity(0.12),
                  blurRadius: 24.r,
                  spreadRadius: -4.r,
                ),
              ]
            : isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10.r,
                  offset: Offset(0, 2.h),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }

    return card;
  }
}

// =============================================================================
// SECTION HEADER - For card titles with icon
// =============================================================================
class DreamSectionHeader extends StatelessWidget {
  const DreamSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20.sp, color: AppColors.primary),
          SizedBox(width: 10.w),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// =============================================================================
// INSET INPUT FIELD - Sunken glass input
// =============================================================================
class DreamTextField extends StatelessWidget {
  const DreamTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.obscureText = false,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      obscureText: obscureText,
      enabled: enabled,
      style: TextStyle(
        color: isDark ? AppColors.textPrimaryDark : Colors.black87,
        fontSize: 15.sp,
      ),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: isDark ? AppColors.textTertiaryDark : Colors.grey.shade600,
          fontSize: 14.sp,
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.textMutedDark : Colors.grey.shade400,
          fontSize: 14.sp,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : Colors.grey.shade600,
                size: 20.sp,
              )
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? AppColors.insetDark : Colors.grey.shade100,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        counterStyle: TextStyle(
          color: isDark ? AppColors.textMutedDark : Colors.grey.shade500,
          fontSize: 12.sp,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.grey.shade300,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.grey.shade300,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: AppColors.primary.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: AppColors.error.withOpacity(0.5),
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: AppColors.error.withOpacity(0.7),
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.02)
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
    );
  }
}
