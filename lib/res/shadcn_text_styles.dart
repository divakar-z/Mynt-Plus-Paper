import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../provider/accessibility_provider.dart';

/// Centralized text styles for Shadcn UI implementation
/// Uses Geist font family and shadcn theme colors for consistent styling
///
/// Usage:
/// ```dart
/// Text('Hello', style: ShadcnTextStyles.title(context))
/// Text('Body', style: ShadcnTextStyles.body(context, color: ShadcnColors.primary(context)))
/// ```
class ShadcnTextStyles {
  // Private constructor to prevent instantiation
  ShadcnTextStyles._();

  /// Font family used across all shadcn text styles. Resolved from the
  /// accessibility provider so the Dyslexia Support toggle can swap the
  /// whole UI to OpenDyslexic at runtime.
  static String get fontFamily => uiFontFamily;

  // ============ BASE TEXT STYLES ============

  /// Large title style - 18px, semibold
  static TextStyle h1(BuildContext context,
      {Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? ShadcnColors.foreground(context),
    );
  }

  /// Title style - 16px, semibold
  static TextStyle title(BuildContext context,
      {Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? ShadcnColors.foreground(context),
    );
  }

  /// Subtitle style - 14px, medium
  static TextStyle subtitle(BuildContext context,
      {Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? ShadcnColors.foreground(context),
    );
  }

  /// Body text style - 13px, regular
  static TextStyle body(BuildContext context,
      {Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? ShadcnColors.foreground(context),
    );
  }

  /// Body medium style - 13px, medium weight
  static TextStyle bodyMedium(BuildContext context, {Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: color ?? ShadcnColors.foreground(context),
    );
  }

  /// Body semibold style - 13px, semibold weight
  static TextStyle bodySemibold(BuildContext context, {Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: color ?? ShadcnColors.foreground(context),
    );
  }

  /// Small text style - 12px, regular
  static TextStyle small(BuildContext context,
      {Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? ShadcnColors.mutedForeground(context),
    );
  }

  /// Small medium style - 12px, medium weight
  static TextStyle smallMedium(BuildContext context, {Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: color ?? ShadcnColors.mutedForeground(context),
    );
  }

  /// Caption/Label style - 11px, medium
  static TextStyle caption(BuildContext context,
      {Color? color, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? ShadcnColors.mutedForeground(context),
    );
  }

  // ============ SEMANTIC TEXT STYLES ============

  /// Price/Value display style - 13px, medium, foreground color
  static TextStyle value(BuildContext context, {Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: color ?? ShadcnColors.foreground(context),
    );
  }

  /// Label text style - 12px, medium, muted foreground
  static TextStyle label(BuildContext context, {Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: color ?? ShadcnColors.mutedForeground(context),
    );
  }

  /// Table header style - 11px, medium, muted foreground
  static TextStyle tableHeader(BuildContext context, {Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: color ?? ShadcnColors.mutedForeground(context),
    );
  }

  /// Button text style - 13px, semibold
  static TextStyle button(BuildContext context, {Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: color ?? Colors.white,
    );
  }

  /// Dialog title style - 18px, semibold
  static TextStyle dialogTitle(BuildContext context, {Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: color ?? ShadcnColors.foreground(context),
    );
  }

  // ============ TRADING SPECIFIC STYLES ============

  /// Positive/Buy/Success text style
  static TextStyle positive(BuildContext context,
      {double fontSize = 13, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: ShadcnColors.success(context),
    );
  }

  /// Negative/Sell/Error text style
  static TextStyle negative(BuildContext context,
      {double fontSize = 13, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: ShadcnColors.destructive(context),
    );
  }

  /// Primary colored text style
  static TextStyle primary(BuildContext context,
      {double fontSize = 13, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: ShadcnColors.primary(context),
    );
  }

  // ============ CUSTOM STYLE BUILDER ============

  /// Build a custom text style with shadcn theming
  static TextStyle custom(
    BuildContext context, {
    required double fontSize,
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? ShadcnColors.foreground(context),
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }
}

/// Centralized color accessor for Shadcn theme colors
/// Provides easy access to theme colors without repetitive Theme.of(context) calls
///
/// Usage:
/// ```dart
/// color: ShadcnColors.primary(context)
/// color: ShadcnColors.foreground(context)
/// ```
class ShadcnColors {
  // Private constructor to prevent instantiation
  ShadcnColors._();

  // ============ CUSTOM BRAND COLORS (Theme-aware) ============

  /// Primary Blue - Main brand blue color
  /// Light: #0037B7, Dark: #2E65F6
  static Color primaryBlue(BuildContext context) {
    final isDark = shadcn.Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFF2E65F6) // Dark mode
        : const Color(0xFF0037B7); // Light mode
  }

  /// Secondary Blue - Secondary brand blue color (same for both themes)
  static Color secondaryBlue(BuildContext context) {
    final isDark = shadcn.Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFF0052CC) // Dark mode
        : const Color(0xFF0052CC); // Light mode
  }

  /// Tertiary - Accent/highlight color (red tones)
  /// Light: #C40024, Dark: #FF6B6B
  static Color tertiary(BuildContext context) {
    final isDark = shadcn.Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFFFF6B6B) // Dark mode
        : const Color(0xFFC40024); // Light mode
  }

  /// Helper to check if current theme is dark
  static bool isDarkMode(BuildContext context) =>
      shadcn.Theme.of(context).brightness == Brightness.dark;

  // ============ BASE COLORS ============

  /// Primary accent color (blue)
  static Color primary(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.primary;

  /// Primary foreground (text on primary background)
  static Color primaryForeground(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.primaryForeground;

  /// Main text/foreground color
  static Color foreground(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.foreground;

  /// Muted/secondary text color
  static Color mutedForeground(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.mutedForeground;

  /// Main background color
  static Color background(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.background;

  /// Card/surface background color
  static Color card(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.card;

  /// Muted background color
  static Color muted(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.muted;

  /// Border/divider color
  static Color border(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.border;

  /// Accent color
  static Color accent(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.accent;

  /// Accent foreground color
  static Color accentForeground(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.accentForeground;

  // ============ SEMANTIC COLORS ============

  /// Destructive/Error/Sell color (red)
  static Color destructive(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.destructive;

  /// Destructive foreground color (text on destructive background)
  static Color destructiveForeground(BuildContext context) => Colors.white;

  /// Success/Buy color (green) - using a consistent green
  static Color success(BuildContext context) => const Color(0xff22c55e);

  /// Warning color
  static Color warning(BuildContext context) => const Color(0xfffbbf24);

  // ============ TRADING SPECIFIC COLORS ============

  /// Buy action color (same as primary)
  static Color buy(BuildContext context) => primary(context);

  /// Sell action color (same as destructive)
  static Color sell(BuildContext context) => destructive(context);

  /// Profit/Positive change color
  static Color profit(BuildContext context) => success(context);

  /// Loss/Negative change color
  static Color loss(BuildContext context) => destructive(context);

  // ============ CHART COLORS ============

  /// Chart color 1
  static Color chart1(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.chart1;

  /// Chart color 2
  static Color chart2(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.chart2;

  /// Chart color 3
  static Color chart3(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.chart3;

  /// Chart color 4
  static Color chart4(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.chart4;

  /// Chart color 5
  static Color chart5(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.chart5;

  // ============ UI ELEMENT COLORS ============

  /// Ring/Focus color
  static Color ring(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.ring;

  /// Input background/border color
  static Color input(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.input;

  /// Secondary color
  static Color secondary(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.secondary;

  /// Secondary foreground color
  static Color secondaryForeground(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.secondaryForeground;

  /// Popover background color
  static Color popover(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.popover;

  /// Popover foreground color
  static Color popoverForeground(BuildContext context) =>
      shadcn.Theme.of(context).colorScheme.popoverForeground;

  // ============ HELPER METHODS ============

  /// Get color based on value (positive/negative)
  static Color forValue(BuildContext context, double value) {
    if (value > 0) return success(context);
    if (value < 0) return destructive(context);
    return foreground(context);
  }

  /// Get color based on string value starting with "-"
  static Color forChange(BuildContext context, String changeValue) {
    if (changeValue.startsWith('-')) return destructive(context);
    if (changeValue != '0' && changeValue != '0.00') return success(context);
    return foreground(context);
  }

  /// Get buy or sell color
  static Color forTransaction(BuildContext context, bool isBuy) {
    return isBuy ? buy(context) : sell(context);
  }
}
