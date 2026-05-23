import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Internal color palette used by the Flutter ThemeData builders.
/// These are NOT the same as `app_colors.dart` — these serve
/// the theme system (light + dark) and include gray scale / gradients.
class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color primaryLight = Color(0xFF818CF8);

  // Secondary Colors
  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryDark = Color(0xFF059669);
  static const Color secondaryLight = Color(0xFF34D399);

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Neutral Colors — Light Theme
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF161A20);
  static const Color darkSurfaceVariant = Color(0xFF1E2328);

  // Dark theme semantic colors
  static Color get darkStroke => white.withValues(alpha: 0.06);
  static Color get darkMuted => white.withValues(alpha: 0.55);
  static Color get darkMuted2 => white.withValues(alpha: 0.35);
  static Color get darkSubtle => white.withValues(alpha: 0.15);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, secondaryDark],
  );

  // Chart Colors
  static const List<Color> chartColors = [
    primary,
    success,
    warning,
    error,
    info,
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
  ];
}

/// Getter-based typography for building ThemeData.
/// Distinct from the context-aware AppTypography in app_typography.dart.
class ThemeTypography {
  static TextStyle get _basePoppins => GoogleFonts.poppins();

  // Display Styles
  static TextStyle get displayLarge => _basePoppins.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static TextStyle get displayMedium => _basePoppins.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static TextStyle get displaySmall => _basePoppins.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  // Headline Styles
  static TextStyle get headlineLarge => _basePoppins.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle get headlineMedium => _basePoppins.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle get headlineSmall => _basePoppins.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  // Title Styles
  static TextStyle get titleLarge => _basePoppins.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static TextStyle get titleMedium => _basePoppins.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static TextStyle get titleSmall => _basePoppins.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  // Body Styles
  static TextStyle get bodyLarge => _basePoppins.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static TextStyle get bodyMedium => _basePoppins.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static TextStyle get bodySmall => _basePoppins.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  // Label Styles
  static TextStyle get labelLarge => _basePoppins.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static TextStyle get labelMedium => _basePoppins.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static TextStyle get labelSmall => _basePoppins.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  // Special Styles
  static TextStyle get button => _basePoppins.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static TextStyle get caption => _basePoppins.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    height: 1.3,
  );

  static TextStyle get overline => _basePoppins.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.6,
    letterSpacing: 1.5,
  );
}
