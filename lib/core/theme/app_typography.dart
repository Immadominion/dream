import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography system using Poppins font family
class AppTypography {
  AppTypography._();

  // Base Poppins text style
  static TextStyle get _baseStyle => GoogleFonts.poppins();

  // Display Styles (Largest)
  static TextStyle displayLarge(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700, // Bold
        height: 1.2,
        color:
            color ??
            AppColors.getTextPrimary(
              Theme.of(context).brightness == Brightness.dark,
            ),
        letterSpacing: -0.5,
      );

  static TextStyle displayMedium(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700, // Bold
        height: 1.25,
        color:
            color ??
            AppColors.getTextPrimary(
              Theme.of(context).brightness == Brightness.dark,
            ),
        letterSpacing: -0.25,
      );

  static TextStyle displaySmall(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600, // SemiBold
        height: 1.3,
        color:
            color ??
            AppColors.getTextPrimary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  // Headline Styles
  static TextStyle headlineLarge(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600, // SemiBold
        height: 1.3,
        color:
            color ??
            AppColors.getTextPrimary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  static TextStyle headlineMedium(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600, // SemiBold
        height: 1.35,
        color:
            color ??
            AppColors.getTextPrimary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  static TextStyle headlineSmall(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500, // Medium
        height: 1.4,
        color:
            color ??
            AppColors.getTextPrimary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  // Title Styles
  static TextStyle titleLarge(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600, // SemiBold
        height: 1.4,
        color:
            color ??
            AppColors.getTextPrimary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  static TextStyle titleMedium(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500, // Medium
        height: 1.4,
        color:
            color ??
            AppColors.getTextPrimary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  static TextStyle titleSmall(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500, // Medium
        height: 1.4,
        color:
            color ??
            AppColors.getTextSecondary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  // Body Styles
  static TextStyle bodyLarge(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400, // Regular
        height: 1.5,
        color:
            color ??
            AppColors.getTextPrimary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  static TextStyle bodyMedium(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400, // Regular
        height: 1.5,
        color:
            color ??
            AppColors.getTextSecondary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  static TextStyle bodySmall(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400, // Regular
        height: 1.5,
        color:
            color ??
            AppColors.getTextSecondary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  // Label Styles
  static TextStyle labelLarge(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500, // Medium
        height: 1.4,
        color:
            color ??
            AppColors.getTextPrimary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  static TextStyle labelMedium(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500, // Medium
        height: 1.4,
        color:
            color ??
            AppColors.getTextSecondary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  static TextStyle labelSmall(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500, // Medium
        height: 1.4,
        color:
            color ??
            AppColors.getTextSecondary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  // Special Styles
  static TextStyle button(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600, // SemiBold
        height: 1.2,
        color: color ?? Colors.white,
        letterSpacing: 0.25,
      );

  static TextStyle caption(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400, // Regular
        height: 1.3,
        color:
            color ??
            AppColors.getTextSecondary(
              Theme.of(context).brightness == Brightness.dark,
            ),
      );

  static TextStyle overline(BuildContext context, {Color? color}) =>
      _baseStyle.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600, // SemiBold
        height: 1.2,
        color:
            color ??
            AppColors.getTextSecondary(
              Theme.of(context).brightness == Brightness.dark,
            ),
        letterSpacing: 1.5,
      );

  // Price/Number specific styles
  static TextStyle priceText(
    BuildContext context, {
    Color? color,
    bool isPositive = true,
  }) => _baseStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600, // SemiBold
    height: 1.2,
    color: color ?? (isPositive ? AppColors.success : AppColors.error),
  );

  static TextStyle largePriceText(
    BuildContext context, {
    Color? color,
    bool isPositive = true,
  }) => _baseStyle.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w700, // Bold
    height: 1.2,
    color: color ?? (isPositive ? AppColors.success : AppColors.error),
  );

  // Create TextTheme for Flutter's theme system
  static TextTheme createTextTheme(BuildContext context) {
    return TextTheme(
      displayLarge: displayLarge(context),
      displayMedium: displayMedium(context),
      displaySmall: displaySmall(context),
      headlineLarge: headlineLarge(context),
      headlineMedium: headlineMedium(context),
      headlineSmall: headlineSmall(context),
      titleLarge: titleLarge(context),
      titleMedium: titleMedium(context),
      titleSmall: titleSmall(context),
      bodyLarge: bodyLarge(context),
      bodyMedium: bodyMedium(context),
      bodySmall: bodySmall(context),
      labelLarge: labelLarge(context),
      labelMedium: labelMedium(context),
      labelSmall: labelSmall(context),
    );
  }
}
