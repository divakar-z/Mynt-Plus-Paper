import 'package:flutter/material.dart';

import '../provider/accessibility_provider.dart';

class WebFonts {
  
  // HEADERS
  static const double heroSize = 20;      // Main page titles, major headers
  static const double headSize = 18;       // Section titles, card headers, dialog titles
  static const double titleSize = 16;      // Subsection titles, card titles, list item titles
  static const double titleMediumSize = 15; // Medium titles, slightly smaller card titles
  
  // BODY TEXT
  static const double subSize = 14;        // Primary body text, table data, form inputs
  static const double bodySmallSize = 13; // Secondary table data, compact text, smaller body text
  static const double paraSize = 12;      // Secondary body text, helper text, fine print
  
  // SMALL TEXT
  static const double captionSize = 10;    // Timestamps, version info, small labels
  static const double overlineSize = 8;    // Tiny labels (rarely used)
  
  // Font Weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  
  // Letter Spacing
  static const double defaultLetterSpacing = 0.5;
  static const double tightLetterSpacing = 0.25;
  static const double wideLetterSpacing = 1.0;
}


class WebTextStyles {
  static TextStyle _baseStyle({
    required double fontSize,
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontSize: fontSize,
      // Resolved at call time so the Dyslexia Support toggle swaps the font
      // globally without having to touch every style call site.
      fontFamily: uiFontFamily,
      color: color ?? (isDarkTheme ? Colors.white : Colors.black),
      fontWeight: fontWeight ?? WebFonts.regular,
      letterSpacing: letterSpacing ?? WebFonts.defaultLetterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  /// Hero text style (20px)
  static TextStyle hero({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return _baseStyle(
      fontSize: WebFonts.heroSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Head text style (18px)
  static TextStyle head({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return _baseStyle(
      fontSize: WebFonts.headSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Title text style (16px)
  static TextStyle title({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return _baseStyle(
      fontSize: WebFonts.titleSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Title medium text style (15px)
  /// Use for medium titles, slightly smaller card titles, intermediate headings
  static TextStyle titleMedium({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return _baseStyle(
      fontSize: WebFonts.titleMediumSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Sub text style (14px)
  static TextStyle sub({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return _baseStyle(
      fontSize: WebFonts.subSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Body small text style (13px)
  /// Use for secondary table data, compact text, smaller body content
  static TextStyle bodySmall({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return _baseStyle(
      fontSize: WebFonts.bodySmallSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Paragraph text style (12px)
  static TextStyle para({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return _baseStyle(
      fontSize: WebFonts.paraSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Caption text style (10px)
  static TextStyle caption({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return _baseStyle(
      fontSize: WebFonts.captionSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Overline text style (8px)
  static TextStyle overline({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return _baseStyle(
      fontSize: WebFonts.overlineSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Custom text style with any font size
  /// 
  /// ⚠️ WARNING: Only use this when semantic methods don't fit your needs.
  /// Always use WebFonts constants (heroSize, headSize, etc.) for fontSize parameter.
  /// 
  /// Example:
  /// ```dart
  /// WebTextStyles.custom(
  ///   fontSize: WebFonts.subSize,  // ✅ Good - uses constant
  ///   isDarkTheme: theme.isDarkMode,
  /// )
  /// 
  /// WebTextStyles.custom(
  ///   fontSize: 13,  // ❌ Bad - hardcoded size
  ///   isDarkTheme: theme.isDarkMode,
  /// )
  /// ```
  static TextStyle custom({
    required double fontSize,
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return _baseStyle(
      fontSize: fontSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  // ===== SEMANTIC HELPER METHODS =====
  // Use these for common UI elements to ensure consistency

  /// Table header text style (12px, bold)
  /// Use for DataTable column headers, table column titles
  static TextStyle tableHeader({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.paraSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.bold,
    );
  }

  /// Table data text style (14px, medium)
  /// Use for DataTable cell content, table row data
  static TextStyle tableData({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return _baseStyle(
      fontSize: WebFonts.subSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight ?? WebFonts.medium,
    );
  }

  /// Compact table data text style (13px, medium)
  /// Use for secondary table data, compact displays, smaller table cells
  static TextStyle tableDataCompact({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return _baseStyle(
      fontSize: WebFonts.bodySmallSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight ?? WebFonts.medium,
    );
  }

  /// Button extra small text style (10px, semiBold)
  static TextStyle buttonXs({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return _baseStyle(
      fontSize: WebFonts.captionSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight ?? WebFonts.bold,
    );
  }

  /// Button small text style (12px, semiBold)
  static TextStyle buttonSm({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return _baseStyle(
      fontSize: WebFonts.paraSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight ?? WebFonts.bold,
    );
  }

  /// Button medium text style (14px, semiBold)
  static TextStyle buttonMd({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return _baseStyle(
      fontSize: WebFonts.subSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight ?? WebFonts.bold,
    );
  }

  /// Form label text style (14px, medium)
  /// Use for TextFormField labels, InputDecoration labels
  static TextStyle formLabel({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.subSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.medium,
    );
  }

  /// Form input text style (14px, medium)
  /// Use for TextFormField input text, TextField content
  static TextStyle formInput({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return _baseStyle(
      fontSize: WebFonts.subSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight ?? WebFonts.medium,
    );
  }

  /// Helper text style (14px, medium)
  /// Use for helper text, form hints, validation messages
  static TextStyle helperText({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.subSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.medium,
    );
  }

  /// Navigation item text style (14px, medium)
  /// Use for sidebar navigation, menu items, tabs
  static TextStyle navigation({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.subSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.medium,
    );
  }

  /// Card title text style (16px, semiBold)
  /// Use for card headers, card titles
  static TextStyle cardTitle({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.titleSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.semiBold,
    );
  }

  /// Card content text style (14px, regular)
  /// Use for card body content, card descriptions
  static TextStyle cardContent({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.subSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.regular,
    );
  }

  /// Dialog title text style (16px, semiBold)
  /// Use for dialog headers, modal titles
  static TextStyle dialogTitle({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.titleSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.semiBold,
    );
  }

  /// Dialog content text style (14px, medium)
  /// Use for dialog body text, modal content
  static TextStyle dialogContent({
    required bool isDarkTheme,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return _baseStyle(
      fontSize: WebFonts.subSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight ?? WebFonts.medium,
    );
  }

  /// Symbol list text style (13px, semiBold)
  static TextStyle symbolList({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.bodySmallSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.semiBold,
    );
  }

  /// Price watch text style (13px, semiBold)
  static TextStyle priceWatch({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.bodySmallSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.semiBold,
    );
  }

  /// Price percent text style (13px, semiBold)
  static TextStyle pricePercent({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.bodySmallSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.semiBold,
    ); 
  }

  /// Exchange text style (12px, semiBold)
  static TextStyle exchText({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.paraSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.semiBold,
    );
  }

  /// Tab text style (13px, semiBold)
  /// Use for tab labels, navigation tabs, filter tabs
  static TextStyle tab({
    required bool isDarkTheme, 
    Color? color,
    FontWeight? fontWeight,
  }) {
    return _baseStyle(
      fontSize: WebFonts.bodySmallSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: fontWeight ?? WebFonts.semiBold,
    );
  }

  /// Status badge text style (12px, medium)
  /// Use for status indicators, badges, chips
  static TextStyle statusBadge({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.paraSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.medium,
    );
  }

  /// Timestamp text style (10px, regular)
  /// Use for timestamps, dates, time displays
  static TextStyle timestamp({
    required bool isDarkTheme,
    Color? color,
  }) {
    return _baseStyle(
      fontSize: WebFonts.captionSize,
      isDarkTheme: isDarkTheme,
      color: color,
      fontWeight: WebFonts.regular,
    );
  }
}

