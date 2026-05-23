import 'package:flutter/material.dart';

/// App color palette based on premium dark-mode Social-Fi design
///
/// Design Philosophy: Pitch black backgrounds with atmospheric glow,
/// glassmorphism containers, and high-contrast minimalist typography.
class AppColors {
  AppColors._();

  // ==========================================================================
  // PRIMARY BRAND COLORS
  // ==========================================================================
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryVariant = Color(0xFF8B5CF6);

  /// Accent color for highlights (cyan)
  static const Color accent = Color(0xFF22D3EE);

  // ==========================================================================
  // SEMANTIC COLORS
  // ==========================================================================
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF059669);

  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);

  static const Color error = Color(0xFFEF4444); // Red
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFDC2626);

  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoDark = Color(0xFF2563EB);

  /// Trading colors - bullish green
  static const Color bullish = Color(0xFF22C55E);

  /// Trading colors - bearish red
  static const Color bearish = Color(0xFFEF4444);

  // ==========================================================================
  // NEUTRAL GRAYS
  // ==========================================================================
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

  // ==========================================================================
  // DARK THEME SURFACES (Premium pitch black)
  // ==========================================================================

  /// Pitch black background
  static const Color backgroundDark = Color(0xFF050507);

  /// Elevated surface with subtle depth
  static const Color surfaceDark = Color(0xFF0D0E12);

  /// Card surface with glass effect
  static const Color cardDark = Color(0xFF12141A);

  /// Overlay surface for modals
  static const Color overlayDark = Color(0xFF1A1C24);

  /// Inset/sunken surface for inputs
  static const Color insetDark = Color(0xFF0A0B0E);

  // ==========================================================================
  // LIGHT THEME (keeping for compatibility)
  // ==========================================================================
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color cardLight = Color(0xFFFFFFFF);

  // ==========================================================================
  // TEXT COLORS
  // ==========================================================================
  static const Color textPrimaryLight = gray900;
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryLight = gray600;
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textTertiaryLight = gray500;
  static const Color textTertiaryDark = Color(0xFF6B7280);
  static const Color textMutedDark = Color(0xFF4B5563);

  // ==========================================================================
  // BORDER COLORS (subtle for glass effect)
  // ==========================================================================
  static const Color borderLight = gray200;
  static const Color borderDark = Color(0xFF1F2128);

  /// Glass border - very subtle white
  static Color get glassBorder => Colors.white.withOpacity(0.06);

  /// Focused border
  static Color get focusBorder => primary.withOpacity(0.5);

  static const Color dividerLight = gray100;
  static const Color dividerDark = Color(0xFF1A1C22);

  // ==========================================================================
  // TOKEN STATUS COLORS
  // ==========================================================================
  static const Color tokenActive = success;
  static const Color tokenPending = warning;
  static const Color tokenFailed = error;
  static const Color tokenNeutral = gray500;

  // ==========================================================================
  // GRADIENTS
  // ==========================================================================
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, successLight],
  );

  /// Hero gradient for headers
  static LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primary.withOpacity(0.7), const Color(0xFF4F46E5)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surfaceLight, gray50],
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundDark, surfaceDark],
  );

  /// Radial glow for atmospheric effects
  static RadialGradient glowGradient(Color color) => RadialGradient(
    center: Alignment.topCenter,
    radius: 1.2,
    colors: [color.withOpacity(0.1), Colors.transparent],
  );

  // ==========================================================================
  // CHART COLORS
  // ==========================================================================
  static const List<Color> chartColors = [
    primary,
    success,
    warning,
    error,
    info,
    primaryVariant,
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
  ];

  // ==========================================================================
  // SHADOWS & GLOWS
  // ==========================================================================
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowDark = Color(0x40000000);

  /// Primary glow for emphasis
  static Color get primaryGlow => primary.withOpacity(0.15);

  /// Card shadow for elevation
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  /// Glow shadow for highlighted elements
  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(color: color.withOpacity(0.12), blurRadius: 24, spreadRadius: -4),
  ];

  // ==========================================================================
  // OVERLAY COLORS
  // ==========================================================================
  static const Color overlayLight = Color(0x80000000);
  static Color get overlayDarkColor => Colors.black.withOpacity(0.7);

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================
  static Color getTextPrimary(bool isDark) =>
      isDark ? textPrimaryDark : textPrimaryLight;

  static Color getTextSecondary(bool isDark) =>
      isDark ? textSecondaryDark : textSecondaryLight;

  static Color getTextMuted(bool isDark) =>
      isDark ? textTertiaryDark : textTertiaryLight;

  static Color getBackground(bool isDark) =>
      isDark ? backgroundDark : backgroundLight;

  static Color getSurface(bool isDark) => isDark ? surfaceDark : surfaceLight;

  static Color getBorder(bool isDark) => isDark ? borderDark : borderLight;

  static Color getCard(bool isDark) => isDark ? cardDark : cardLight;

  static Color getInset(bool isDark) => isDark ? insetDark : gray100;
}
