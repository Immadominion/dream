import 'package:flutter/material.dart';

import 'app_theme_palette.dart';
import 'dream_colors.dart';

export 'app_theme_palette.dart' show AppColors, ThemeTypography;
export 'dream_colors.dart' show DreamColors, DreamThemeExtension;

/// App theme configuration — assembles Flutter ThemeData from extracted parts.
class AppTheme {
  static ThemeData get lightTheme {
    const dreamColors = DreamColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
            primary: dreamColors.primary,
            secondary: dreamColors.secondary,
            surface: dreamColors.surface,
            surfaceContainerHighest: dreamColors.surfaceVariant,
            error: dreamColors.error,
            onSurface: dreamColors.onSurface,
            onPrimary: dreamColors.onPrimary,
            outline: dreamColors.stroke,
          ).copyWith(
            surface: dreamColors.surface,
            onSurface: dreamColors.onSurface,
          ),

      // Theme Extensions
      extensions: <ThemeExtension<dynamic>>[dreamColors],

      // Typography
      textTheme: TextTheme(
        displayLarge: ThemeTypography.displayLarge,
        displayMedium: ThemeTypography.displayMedium,
        displaySmall: ThemeTypography.displaySmall,
        headlineLarge: ThemeTypography.headlineLarge,
        headlineMedium: ThemeTypography.headlineMedium,
        headlineSmall: ThemeTypography.headlineSmall,
        titleLarge: ThemeTypography.titleLarge,
        titleMedium: ThemeTypography.titleMedium,
        titleSmall: ThemeTypography.titleSmall,
        bodyLarge: ThemeTypography.bodyLarge,
        bodyMedium: ThemeTypography.bodyMedium,
        bodySmall: ThemeTypography.bodySmall,
        labelLarge: ThemeTypography.labelLarge,
        labelMedium: ThemeTypography.labelMedium,
        labelSmall: ThemeTypography.labelSmall,
      ),

      // Component Themes
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: dreamColors.surface,
        foregroundColor: dreamColors.onSurface,
        titleTextStyle: ThemeTypography.headlineMedium.copyWith(
          color: dreamColors.onSurface,
        ),
        iconTheme: IconThemeData(color: dreamColors.onSurface),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dreamColors.primary,
          foregroundColor: dreamColors.onPrimary,
          textStyle: ThemeTypography.button,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          shadowColor: dreamColors.primary.withValues(alpha: 0.3),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dreamColors.primary,
          textStyle: ThemeTypography.button,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: dreamColors.primary),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dreamColors.primary,
          textStyle: ThemeTypography.button,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dreamColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dreamColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dreamColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dreamColors.error),
        ),
        contentPadding: const EdgeInsets.all(16),
        hintStyle: ThemeTypography.bodyMedium.copyWith(
          color: dreamColors.muted,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: dreamColors.surface,
        surfaceTintColor: dreamColors.primary.withValues(alpha: 0.05),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: dreamColors.surface,
        selectedItemColor: dreamColors.primary,
        unselectedItemColor: dreamColors.muted,
        selectedLabelStyle: ThemeTypography.labelSmall,
        unselectedLabelStyle: ThemeTypography.labelSmall,
        elevation: 8,
      ),

      scaffoldBackgroundColor: dreamColors.background,
    );
  }

  static ThemeData get darkTheme {
    const dreamColors = DreamColors.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color Scheme
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.dark,
            primary: dreamColors.primary,
            secondary: dreamColors.secondary,
            surface: dreamColors.surface,
            surfaceContainerHighest: dreamColors.surfaceVariant,
            error: dreamColors.error,
            onSurface: dreamColors.onSurface,
            onPrimary: dreamColors.onPrimary,
            outline: dreamColors.stroke,
          ).copyWith(
            surface: dreamColors.surface,
            onSurface: dreamColors.onSurface,
          ),

      // Theme Extensions
      extensions: <ThemeExtension<dynamic>>[dreamColors],

      // Typography (same as light theme)
      textTheme: TextTheme(
        displayLarge: ThemeTypography.displayLarge.copyWith(
          color: AppColors.white,
        ),
        displayMedium: ThemeTypography.displayMedium.copyWith(
          color: AppColors.white,
        ),
        displaySmall: ThemeTypography.displaySmall.copyWith(
          color: AppColors.white,
        ),
        headlineLarge: ThemeTypography.headlineLarge.copyWith(
          color: AppColors.white,
        ),
        headlineMedium: ThemeTypography.headlineMedium.copyWith(
          color: AppColors.white,
        ),
        headlineSmall: ThemeTypography.headlineSmall.copyWith(
          color: AppColors.gray200,
        ),
        titleLarge: ThemeTypography.titleLarge.copyWith(
          color: AppColors.white,
        ),
        titleMedium: ThemeTypography.titleMedium.copyWith(
          color: AppColors.gray200,
        ),
        titleSmall: ThemeTypography.titleSmall.copyWith(
          color: AppColors.gray300,
        ),
        bodyLarge: ThemeTypography.bodyLarge.copyWith(color: AppColors.gray200),
        bodyMedium: ThemeTypography.bodyMedium.copyWith(
          color: AppColors.gray300,
        ),
        bodySmall: ThemeTypography.bodySmall.copyWith(color: AppColors.gray400),
        labelLarge: ThemeTypography.labelLarge.copyWith(
          color: AppColors.gray200,
        ),
        labelMedium: ThemeTypography.labelMedium.copyWith(
          color: AppColors.gray300,
        ),
        labelSmall: ThemeTypography.labelSmall.copyWith(
          color: AppColors.gray400,
        ),
      ),

      // Component Themes
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: dreamColors.surface,
        foregroundColor: dreamColors.onSurface,
        titleTextStyle: ThemeTypography.headlineMedium.copyWith(
          color: dreamColors.onSurface,
        ),
        iconTheme: IconThemeData(color: dreamColors.onSurface),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dreamColors.primary,
          foregroundColor: dreamColors.onPrimary,
          textStyle: ThemeTypography.button,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: dreamColors.primary.withValues(alpha: 0.3),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dreamColors.primary,
          textStyle: ThemeTypography.button,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: dreamColors.primary),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dreamColors.primary,
          textStyle: ThemeTypography.button,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dreamColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dreamColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dreamColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dreamColors.error),
        ),
        contentPadding: const EdgeInsets.all(16),
        hintStyle: ThemeTypography.bodyMedium.copyWith(
          color: dreamColors.muted,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: dreamColors.surface,
        surfaceTintColor: dreamColors.primary.withValues(alpha: 0.05),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: dreamColors.surface,
        selectedItemColor: dreamColors.primary,
        unselectedItemColor: dreamColors.muted,
        selectedLabelStyle: ThemeTypography.labelSmall,
        unselectedLabelStyle: ThemeTypography.labelSmall,
        elevation: 8,
      ),

      scaffoldBackgroundColor: dreamColors.background,
    );
  }
}
