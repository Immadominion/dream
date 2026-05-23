import 'package:flutter/material.dart';

import 'app_theme_palette.dart';

/// Flutter ThemeExtension providing semantic color access.
/// Supports light + dark theme instances via const constructors.
@immutable
class DreamColors extends ThemeExtension<DreamColors> {
  const DreamColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.stroke,
    required this.muted,
    required this.mutedSecondary,
    required this.subtle,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onBackground,
    required this.primary,
    required this.primaryContainer,
    required this.onPrimary,
    required this.secondary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color stroke;
  final Color muted;
  final Color mutedSecondary;
  final Color subtle;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color onBackground;
  final Color primary;
  final Color primaryContainer;
  final Color onPrimary;
  final Color secondary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  @override
  DreamColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? stroke,
    Color? muted,
    Color? mutedSecondary,
    Color? subtle,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? onBackground,
    Color? primary,
    Color? primaryContainer,
    Color? onPrimary,
    Color? secondary,
    Color? accent,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
  }) {
    return DreamColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      stroke: stroke ?? this.stroke,
      muted: muted ?? this.muted,
      mutedSecondary: mutedSecondary ?? this.mutedSecondary,
      subtle: subtle ?? this.subtle,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      onBackground: onBackground ?? this.onBackground,
      primary: primary ?? this.primary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
    );
  }

  @override
  DreamColors lerp(DreamColors? other, double t) {
    if (other is! DreamColors) {
      return this;
    }
    return DreamColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedSecondary: Color.lerp(mutedSecondary, other.mutedSecondary, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }

  /// Light theme colors
  static const light = DreamColors(
    background: AppColors.gray50,
    surface: AppColors.white,
    surfaceVariant: AppColors.gray100,
    stroke: AppColors.gray200,
    muted: AppColors.gray500,
    mutedSecondary: AppColors.gray400,
    subtle: AppColors.gray100,
    onSurface: AppColors.gray900,
    onSurfaceVariant: AppColors.gray700,
    onBackground: AppColors.gray900,
    primary: AppColors.primary,
    primaryContainer: AppColors.primaryLight,
    onPrimary: AppColors.white,
    secondary: AppColors.secondary,
    accent: AppColors.primaryLight,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    info: AppColors.info,
  );

  /// Dark theme colors
  static const dark = DreamColors(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceVariant: AppColors.darkSurfaceVariant,
    stroke: Color(0xFF2C3137),
    muted: Color(0xFF8B8D98),
    mutedSecondary: Color(0xFF68696E),
    subtle: Color(0xFF2A2D33),
    onSurface: AppColors.white,
    onSurfaceVariant: Color(0xFFD1D1D6),
    onBackground: AppColors.white,
    primary: AppColors.primary,
    primaryContainer: AppColors.primaryDark,
    onPrimary: AppColors.white,
    secondary: AppColors.secondaryLight,
    accent: AppColors.primaryLight,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    info: AppColors.info,
  );
}

/// Context extension for convenient DreamColors access
extension DreamThemeExtension on BuildContext {
  DreamColors get dreamColors =>
      Theme.of(this).extension<DreamColors>() ?? DreamColors.dark;

  Color get backgroundColor => dreamColors.background;
  Color get surfaceColor => dreamColors.surface;
  Color get primaryColor => dreamColors.primary;
  Color get mutedColor => dreamColors.muted;
  Color get strokeColor => dreamColors.stroke;
  Color get onSurfaceColor => dreamColors.onSurface;
}
