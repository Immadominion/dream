import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';

/// iOS-style segmented control widget
/// Follows Apple Human Interface Guidelines for segmented controls
class DreamSegmentedControl<T> extends StatelessWidget {
  const DreamSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedValue,
    required this.onValueChanged,
    this.height,
    this.padding,
  });

  /// Map of segment values to their display labels
  final Map<T, String> segments;

  /// Currently selected value
  final T selectedValue;

  /// Callback when selection changes
  final ValueChanged<T> onValueChanged;

  /// Optional custom height
  final double? height;

  /// Optional padding around the control
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controlHeight = height ?? 36.h;

    return Padding(
      padding: padding ?? EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        height: controlHeight,
        decoration: BoxDecoration(
          color: isDark ? AppColors.insetDark : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        padding: EdgeInsets.all(3.w),
        child: Row(
          children: segments.entries.map((entry) {
            final isSelected = entry.key == selectedValue;
            return Expanded(
              child: GestureDetector(
                onTap: () => onValueChanged(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? AppColors.cardDark : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.3 : 0.08,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.grey.shade600),
                        fontSize: 13.sp,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                      child: Text(entry.value),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
