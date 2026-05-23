import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Reusable button component following app design patterns
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final bool isOutlined;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isPrimary = true,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
  });

  // App colors - consistent with design patterns
  Color get _primaryColor => const Color(0xFF6366F1);
  Color get _cardColor => const Color(0xFF161A20);
  Color get _strokeColor => Colors.white.withValues(alpha: 0.06);

  @override
  Widget build(BuildContext context) {
    final buttonColor =
        backgroundColor ??
        (isPrimary
            ? _primaryColor
            : (isOutlined ? Colors.transparent : _cardColor));
    final borderColor = isOutlined ? _strokeColor : buttonColor;
    final contentColor = textColor ?? Colors.white;

    return SizedBox(
      width: width,
      height: height ?? 48.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: contentColor,
          elevation: isPrimary ? 2 : 0,
          shadowColor: isPrimary ? _primaryColor.withValues(alpha: 0.3) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: BorderSide(color: borderColor),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
        child: isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(contentColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, SizedBox(width: 8.w)],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: contentColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Reusable search input component
class AppSearchInput extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final Widget? suffixIcon;
  final Widget? prefixIcon;

  const AppSearchInput({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Search...',
    this.onTap,
    this.onChanged,
    this.enabled = true,
    this.suffixIcon,
    this.prefixIcon,
  });

  // App colors
  Color get _cardColor => const Color(0xFF161A20);
  Color get _strokeColor => Colors.white.withValues(alpha: 0.06);
  Color get _mutedColor => Colors.white.withValues(alpha: 0.55);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _strokeColor),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        onTap: onTap,
        onChanged: onChanged,
        style: TextStyle(color: Colors.white, fontSize: 16.sp),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: _mutedColor, fontSize: 16.sp),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),
        ),
      ),
    );
  }
}

/// Reusable filter tag component
class AppFilterTag extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const AppFilterTag({
    super.key,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  // App colors
  Color get _primaryColor => const Color(0xFF6366F1);
  Color get _cardColor => const Color(0xFF161A20);
  Color get _strokeColor => Colors.white.withValues(alpha: 0.06);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : _cardColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: isSelected ? _primaryColor : _strokeColor),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
