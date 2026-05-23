// Dream Labs Design System Guide
// ================================
// This file defines the design language for the Dream app.
// AI assistants and developers should follow these principles
// when creating or modifying UI components.
//
// DESIGN PHILOSOPHY: "Premium Dark-Mode Social-Fi"
// - Pitch black backgrounds with soft atmospheric glow
// - Super-ellipse (squircle) containers with glassmorphism
// - Minimalist typography with high contrast
// - Organic, curved UI elements
// - Oversized interactive elements for tactile feel

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// =============================================================================
// SPACING SYSTEM
// =============================================================================
/// Use these consistent spacing values throughout the app.
/// Always use ScreenUtil extensions (.w, .h, .r, .sp)
abstract class DreamSpacing {
  /// Extra small: 4.w
  static double get xs => 4.w;

  /// Small: 8.w
  static double get sm => 8.w;

  /// Medium: 12.w
  static double get md => 12.w;

  /// Default: 16.w
  static double get df => 16.w;

  /// Large: 20.w
  static double get lg => 20.w;

  /// Extra large: 24.w
  static double get xl => 24.w;

  /// 2X large: 32.w
  static double get xxl => 32.w;

  /// 3X large: 48.w
  static double get xxxl => 48.w;

  /// Page horizontal padding
  static EdgeInsets get pagePadding => EdgeInsets.symmetric(horizontal: 16.w);

  /// Card internal padding
  static EdgeInsets get cardPadding => EdgeInsets.all(20.r);

  /// Section spacing (between major content blocks)
  static double get sectionGap => 24.h;

  /// Item spacing (between list items)
  static double get itemGap => 12.h;
}

// =============================================================================
// BORDER RADIUS (Squircle-inspired)
// =============================================================================
/// Use large, organic border radii for that premium feel.
abstract class DreamRadius {
  /// Extra small: 8.r (tags, badges)
  static double get xs => 8.r;

  /// Small: 12.r (small cards, inputs)
  static double get sm => 12.r;

  /// Medium: 16.r (standard cards)
  static double get md => 16.r;

  /// Large: 20.r (large cards)
  static double get lg => 20.r;

  /// Extra large: 24.r (modals, sheets)
  static double get xl => 24.r;

  /// 2X large: 28.r (feature cards)
  static double get xxl => 28.r;

  /// Full: 100.r (pills, circular elements)
  static double get full => 100.r;

  /// Card radius
  static BorderRadius get card => BorderRadius.circular(20.r);

  /// Button radius
  static BorderRadius get button => BorderRadius.circular(16.r);

  /// Input radius
  static BorderRadius get input => BorderRadius.circular(12.r);

  /// Tag/badge radius
  static BorderRadius get tag => BorderRadius.circular(8.r);
}

// =============================================================================
// GLASSMORPHISM & SURFACE STYLES
// =============================================================================
/// Glass-like surface decorations for premium feel.
abstract class DreamSurface {
  /// Primary dark background (pitch black)
  static const Color background = Color(0xFF050507);

  /// Elevated surface with subtle glow
  static const Color surfaceElevated = Color(0xFF0D0E12);

  /// Card surface with glass effect
  static const Color surfaceCard = Color(0xFF12141A);

  /// Subtle overlay for depth
  static const Color surfaceOverlay = Color(0xFF1A1C24);

  /// Primary brand color (indigo/purple)
  static const Color primary = Color(0xFF6366F1);

  /// Primary glow color (for bloom effects)
  static Color get primaryGlow => primary.withOpacity(0.15);

  /// Secondary accent (cyan/teal for highlights)
  static const Color accent = Color(0xFF22D3EE);

  /// Success green
  static const Color success = Color(0xFF10B981);

  /// Error red
  static const Color error = Color(0xFFEF4444);

  /// Warning amber
  static const Color warning = Color(0xFFF59E0B);

  /// Bullish green (for positive price changes)
  static const Color bullish = Color(0xFF22C55E);

  /// Bearish red (for negative price changes)
  static const Color bearish = Color(0xFFEF4444);

  /// Glass card decoration with border glow
  static BoxDecoration glassCard({
    Color? glowColor,
    double borderOpacity = 0.08,
  }) {
    return BoxDecoration(
      color: surfaceCard,
      borderRadius: DreamRadius.card,
      border: Border.all(
        color: Colors.white.withOpacity(borderOpacity),
        width: 1,
      ),
      boxShadow: glowColor != null
          ? [
              BoxShadow(
                color: glowColor.withOpacity(0.12),
                blurRadius: 24.r,
                spreadRadius: -4.r,
              ),
            ]
          : null,
    );
  }

  /// Elevated card with subtle shadow
  static BoxDecoration elevatedCard({bool withGlow = false}) {
    return BoxDecoration(
      color: surfaceCard,
      borderRadius: DreamRadius.card,
      border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 16.r,
          offset: Offset(0, 8.h),
        ),
        if (withGlow)
          BoxShadow(
            color: primary.withOpacity(0.08),
            blurRadius: 32.r,
            spreadRadius: -8.r,
          ),
      ],
    );
  }

  /// Inset/sunken field decoration (for inputs)
  static BoxDecoration insetField() {
    return BoxDecoration(
      color: const Color(0xFF0A0B0E),
      borderRadius: DreamRadius.input,
      border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
    );
  }

  /// Gradient for headers and hero sections
  static LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primary.withOpacity(0.7), const Color(0xFF4F46E5)],
  );

  /// Subtle radial glow for background
  static RadialGradient backgroundGlow(Color color) {
    return RadialGradient(
      center: Alignment.topCenter,
      radius: 1.2,
      colors: [color.withOpacity(0.08), Colors.transparent],
    );
  }
}

// =============================================================================
// TYPOGRAPHY
// =============================================================================
/// Minimalist typography with proper hierarchy.
abstract class DreamText {
  /// Text colors
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF4B5563);

  /// Display - Hero headlines (32-40sp)
  static TextStyle displayLarge() => TextStyle(
    fontSize: 40.sp,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.1,
    letterSpacing: -1.0,
  );

  static TextStyle displayMedium() => TextStyle(
    fontSize: 32.sp,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.15,
    letterSpacing: -0.5,
  );

  /// Headline - Section headers (20-24sp)
  static TextStyle headlineLarge() => TextStyle(
    fontSize: 24.sp,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.2,
  );

  static TextStyle headlineMedium() => TextStyle(
    fontSize: 20.sp,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.25,
  );

  static TextStyle headlineSmall() => TextStyle(
    fontSize: 18.sp,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );

  /// Title - Card titles, labels (14-16sp)
  static TextStyle titleLarge() => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.35,
  );

  static TextStyle titleMedium() => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.4,
  );

  /// Body - Regular content (13-15sp)
  static TextStyle bodyLarge() => TextStyle(
    fontSize: 15.sp,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );

  static TextStyle bodyMedium() => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );

  static TextStyle bodySmall() => TextStyle(
    fontSize: 13.sp,
    fontWeight: FontWeight.w400,
    color: textMuted,
    height: 1.45,
  );

  /// Caption - Small metadata (10-12sp)
  static TextStyle caption() => TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w500,
    color: textMuted,
    height: 1.3,
  );

  static TextStyle captionSmall() => TextStyle(
    fontSize: 10.sp,
    fontWeight: FontWeight.w500,
    color: textMuted,
    height: 1.3,
  );

  /// Numbers - Financial data (monospace-like weight)
  static TextStyle numberLarge() => TextStyle(
    fontSize: 36.sp,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static TextStyle numberMedium() => TextStyle(
    fontSize: 20.sp,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.2,
  );

  static TextStyle numberSmall() => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );

  /// Button text
  static TextStyle buttonLarge() => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.2,
  );

  static TextStyle buttonMedium() => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.2,
  );
}

// =============================================================================
// BUTTON STYLES
// =============================================================================
/// Oversized, tactile buttons with proper feedback.
abstract class DreamButton {
  /// Large primary button (full width CTAs)
  static ButtonStyle primaryLarge() => ElevatedButton.styleFrom(
    backgroundColor: DreamSurface.primary,
    foregroundColor: Colors.white,
    minimumSize: Size(double.infinity, 56.h),
    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
    shape: RoundedRectangleBorder(borderRadius: DreamRadius.button),
    elevation: 0,
  );

  /// Medium primary button
  static ButtonStyle primaryMedium() => ElevatedButton.styleFrom(
    backgroundColor: DreamSurface.primary,
    foregroundColor: Colors.white,
    minimumSize: Size(0, 48.h),
    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
    shape: RoundedRectangleBorder(borderRadius: DreamRadius.button),
    elevation: 0,
  );

  /// Ghost/outline button
  static ButtonStyle ghost() => OutlinedButton.styleFrom(
    foregroundColor: DreamText.textPrimary,
    minimumSize: Size(0, 48.h),
    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
    shape: RoundedRectangleBorder(borderRadius: DreamRadius.button),
    side: BorderSide(color: Colors.white.withOpacity(0.12), width: 1),
  );

  /// Glass button (for overlays)
  static BoxDecoration glassButton() => BoxDecoration(
    color: Colors.white.withOpacity(0.08),
    borderRadius: DreamRadius.button,
    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
  );

  /// Icon button container
  static BoxDecoration iconButton({bool isActive = false}) => BoxDecoration(
    color: isActive
        ? DreamSurface.primary.withOpacity(0.15)
        : Colors.white.withOpacity(0.05),
    shape: BoxShape.circle,
    border: Border.all(
      color: isActive
          ? DreamSurface.primary.withOpacity(0.3)
          : Colors.white.withOpacity(0.08),
      width: 1,
    ),
  );
}

// =============================================================================
// INPUT STYLES
// =============================================================================
/// Sunken, inset input fields with glass effect.
abstract class DreamInput {
  /// Standard input decoration
  static InputDecoration standard({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: DreamText.bodyMedium().copyWith(color: DreamText.textMuted),
      hintStyle: DreamText.bodyMedium().copyWith(color: DreamText.textDisabled),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF0A0B0E),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      border: OutlineInputBorder(
        borderRadius: DreamRadius.input,
        borderSide: BorderSide(color: Colors.white.withOpacity(0.04), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: DreamRadius.input,
        borderSide: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: DreamRadius.input,
        borderSide: BorderSide(
          color: DreamSurface.primary.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: DreamRadius.input,
        borderSide: BorderSide(
          color: DreamSurface.error.withOpacity(0.5),
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: DreamRadius.input,
        borderSide: BorderSide(
          color: DreamSurface.error.withOpacity(0.7),
          width: 1.5,
        ),
      ),
    );
  }
}

// =============================================================================
// TAG / BADGE STYLES
// =============================================================================
/// Pill-shaped tags and badges.
abstract class DreamTag {
  /// Success tag (green)
  static BoxDecoration success() => BoxDecoration(
    color: DreamSurface.success.withOpacity(0.12),
    borderRadius: DreamRadius.tag,
    border: Border.all(color: DreamSurface.success.withOpacity(0.2), width: 1),
  );

  /// Error tag (red)
  static BoxDecoration error() => BoxDecoration(
    color: DreamSurface.error.withOpacity(0.12),
    borderRadius: DreamRadius.tag,
    border: Border.all(color: DreamSurface.error.withOpacity(0.2), width: 1),
  );

  /// Warning tag (amber)
  static BoxDecoration warning() => BoxDecoration(
    color: DreamSurface.warning.withOpacity(0.12),
    borderRadius: DreamRadius.tag,
    border: Border.all(color: DreamSurface.warning.withOpacity(0.2), width: 1),
  );

  /// Primary tag (brand color)
  static BoxDecoration primary() => BoxDecoration(
    color: DreamSurface.primary.withOpacity(0.12),
    borderRadius: DreamRadius.tag,
    border: Border.all(color: DreamSurface.primary.withOpacity(0.2), width: 1),
  );

  /// Neutral tag (gray)
  static BoxDecoration neutral() => BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: DreamRadius.tag,
    border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
  );

  /// Bullish tag (positive change)
  static BoxDecoration bullish() => BoxDecoration(
    color: DreamSurface.bullish.withOpacity(0.12),
    borderRadius: BorderRadius.circular(6.r),
    border: Border.all(color: DreamSurface.bullish.withOpacity(0.2), width: 1),
  );

  /// Bearish tag (negative change)
  static BoxDecoration bearish() => BoxDecoration(
    color: DreamSurface.bearish.withOpacity(0.12),
    borderRadius: BorderRadius.circular(6.r),
    border: Border.all(color: DreamSurface.bearish.withOpacity(0.2), width: 1),
  );
}

// =============================================================================
// ANIMATION DURATIONS
// =============================================================================
/// Consistent animation timings.
abstract class DreamDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration page = Duration(milliseconds: 300);
}

// =============================================================================
// UI COMPONENT GUIDELINES (for AI reference)
// =============================================================================
/// 
/// TOKEN CARDS (Discovery Feed):
/// - Use glassCard with subtle primary glow
/// - Token image: 44-48px circle with 2px accent border if verified
/// - Ticker: titleLarge(), name: bodyMedium()
/// - Price change: Use bullish/bearish tags
/// - Metrics (MC, LIQ, VOL): captionSmall() in horizontal wrap
/// - Quick-buy button: Glass style, right-aligned
/// 
/// PROFILE HEADER:
/// - Large circular avatar (80-100px) that "breaks" the header boundary
/// - Net worth: displayLarge() or numberLarge()
/// - PnL badge: bullish/bearish pill
/// - Wallet address: caption() with copy button
/// 
/// CREATE TOKEN FORM:
/// - Sunken input fields with DreamInput.standard()
/// - Section headers: headlineMedium() with icon
/// - Card sections: glassCard()
/// - Image picker: Dashed border when empty, solid primary when filled
/// - Launch button: primaryLarge() with gradient, sticky at bottom
/// 
/// NAVIGATION:
/// - Bottom nav: Elevated surface, 56-64px height
/// - Active icon: Primary color with subtle glow
/// - Search bar: Glass card above nav, 48-56px height
/// 
/// GENERAL RULES:
/// 1. Never use hard-coded colors - always use DreamSurface/DreamText
/// 2. Never use bare integers - always use ScreenUtil (.w, .h, .r, .sp)
/// 3. Maintain 16px horizontal page margins
/// 4. Use 12-16px gaps between list items
/// 5. Use 20-24px gaps between sections
/// 6. Cards should have 20px internal padding
/// 7. Interactive elements minimum 44px touch target
/// 8. Use subtle borders (0.06-0.1 opacity white) for depth
/// 9. Add glow effects sparingly for emphasis
/// 10. Prefer vertical rhythm with consistent spacing
