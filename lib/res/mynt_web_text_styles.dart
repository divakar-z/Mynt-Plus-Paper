import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../provider/accessibility_provider.dart';
import 'responsive_extensions.dart';

/// ===============================================================
/// FONT SYSTEM – single source of truth
/// ===============================================================
class MyntFonts {
  // Resolved from the accessibility provider so the Dyslexia Support toggle
  // swaps every text style to OpenDyslexic. Kept as a getter (not a const)
  // because the value changes at runtime.
  static String get fontFamily => uiFontFamily;

  // HEADERS
  static const double hero = 20;
  static const double head = 18;
  static const double title = 16;
  static const double titleMedium = 15;

  // BODY
  static const double body = 14;
  static const double bodySmall = 13;
  static const double para = 12;

  // SMALL
  static const double caption = 10;
  static const double overline = 8;

  // WEIGHTS
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

/// ===============================================================
/// THEME HELPERS (SAFE WITH SHADCN)
/// ===============================================================
bool isDarkMode(BuildContext context) =>
    shadcn.Theme.of(context).brightness == Brightness.dark;

Color resolveThemeColor(
  BuildContext context, {
  required Color dark,
  required Color light,
}) =>
    isDarkMode(context) ? dark : light;

/// ===============================================================
/// CORE TEXT STYLE ENGINE (DO NOT DUPLICATE)
/// ===============================================================
TextStyle _text(
  BuildContext context, {
  required double size,
  required FontWeight weight,
  Color? color,
  Color? darkColor,
  Color? lightColor,
  double? height,
}) {
  final scheme = shadcn.Theme.of(context).colorScheme;

  final resolvedColor = color ??
      ((darkColor != null && lightColor != null)
          ? resolveThemeColor(
              context,
              dark: darkColor,
              light: lightColor,
            )
          : scheme.foreground);

  // Use centralized font scale factor from responsive extensions
  final scaleFactor = context.fontScaleFactor;

  return TextStyle(
    fontFamily: MyntFonts.fontFamily,
    fontSize: size * scaleFactor,
    fontWeight: weight,
    color: resolvedColor,
    height: height,
  );
}

/// ===============================================================
/// FLEXIBLE TEXT OVERRIDE (USE SPARINGLY)
/// ===============================================================
TextStyle webText(
  BuildContext context, {
  double? size,
  FontWeight? weight,
  Color? color,
  Color? darkColor,
  Color? lightColor,
  double? height,
}) {
  final scheme = shadcn.Theme.of(context).colorScheme;

  // Use centralized font scale factor from responsive extensions
  final scaleFactor = context.fontScaleFactor;

  return TextStyle(
    fontFamily: MyntFonts.fontFamily,
    fontSize: (size ?? MyntFonts.body) * scaleFactor,
    fontWeight: weight,
    height: height,
    color: color ??
        ((darkColor != null && lightColor != null)
            ? (isDarkMode(context) ? darkColor : lightColor)
            : scheme.foreground),
  );
}

/// ===============================================================
/// STRUCTURAL BASE STYLES (PRIVATE)
/// ===============================================================
class _Base {
  static TextStyle body(
    BuildContext c, {
    FontWeight weight = MyntFonts.regular,
    Color? color,
    Color? darkColor,
    Color? lightColor,
  }) =>
      _text(
        c,
        size: MyntFonts.body,
        weight: weight,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );
}

/// ===============================================================
/// PUBLIC TEXT STYLES (SEMANTIC + STABLE)
/// ===============================================================
class MyntWebTextStyles {
  // ---------------- HEADERS ----------------
  static TextStyle hero(BuildContext c,
          {Color? color, Color? darkColor, Color? lightColor, FontWeight? fontWeight}) =>
      _text(
        c,
        size: MyntFonts.hero,
        weight: fontWeight ?? MyntFonts.bold,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle head(BuildContext c,
          {Color? color,
          Color? darkColor,
          Color? lightColor,
          FontWeight? fontWeight}) =>
      _text(
        c,
        size: MyntFonts.head,
        weight: fontWeight ?? MyntFonts.semiBold,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle title(BuildContext c,
          {Color? color,
          Color? darkColor,
          Color? lightColor,
          FontWeight? fontWeight}) =>
      _text(
        c,
        size: MyntFonts.title,
        weight: fontWeight ?? MyntFonts.medium,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

       static TextStyle titlesub(BuildContext c,
          {Color? color,
          Color? darkColor,
          Color? lightColor,
          FontWeight? fontWeight}) =>
      _text(
        c,
        size: MyntFonts.titleMedium,
          weight: fontWeight ?? FontWeight.w500,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  // ---------------- BODY ----------------
  static TextStyle body(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _Base.body(
        c,
        weight: fontWeight ?? MyntFonts.regular,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle bodyMedium(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _Base.body(
        c,
        weight: fontWeight ?? MyntFonts.medium,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle bodySmall(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _text(
        c,
        size: MyntFonts.bodySmall,
        weight: fontWeight ?? MyntFonts.medium,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle para(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _text(
        c,
        size: MyntFonts.para,
        weight: fontWeight ?? MyntFonts.medium,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle caption(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _text(
        c,
        size: MyntFonts.caption,
        weight: fontWeight ?? MyntFonts.medium,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  // ---------------- TABLE ----------------
  static TextStyle tableHeader(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _text(
        c,
        size: MyntFonts.body,
        weight: fontWeight ?? MyntFonts.bold,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle tableCell(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _Base.body(
        c,
        weight: fontWeight ?? MyntFonts.medium,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  // ---------------- INPUTS ----------------
  static TextStyle input(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _Base.body(
        c,
        weight: fontWeight ?? MyntFonts.medium,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle placeholder(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _text(
        c,
        size: MyntFonts.body,
        weight: fontWeight ?? MyntFonts.regular,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  // ===========================================================
  // WATCHLIST / MARKET LIST (SEMANTIC – DO NOT REMOVE)
  // ===========================================================
  static TextStyle symbol(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _text(
        c,
        size: MyntFonts.body,
        weight: fontWeight ?? MyntFonts.medium,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle price(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _text(
        c,
        size: MyntFonts.body,
        weight: fontWeight ?? MyntFonts.medium,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle priceChange(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _text(
        c,
        size: MyntFonts.para,
        weight: fontWeight ?? MyntFonts.medium,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle exch(
    BuildContext c, {
    Color? color,
    Color? darkColor,
    Color? lightColor,
    FontWeight? fontWeight,
  }) =>
      _text(
        c,
        size: MyntFonts.para,
        weight: fontWeight ?? MyntFonts.medium,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  // ===========================================================
// BUTTON TEXT (EXPLICIT – DO NOT APPLY GLOBALLY)
// ===========================================================

  static TextStyle buttonSm(BuildContext c,
          {Color? color, Color? darkColor, Color? lightColor}) =>
      _text(
        c,
        size: MyntFonts.para, // 12
        weight: MyntFonts.bold,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle buttonMd(BuildContext c,
          {Color? color, Color? darkColor, Color? lightColor, double? fontSize}) =>
      _text(
        c,
        size: fontSize ?? MyntFonts.bodySmall, // 13
        weight: MyntFonts.bold,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );

  static TextStyle buttonXl(BuildContext c,
          {Color? color, Color? darkColor, Color? lightColor, double? fontSize}) =>
      _text(
        c,
        size: fontSize ?? MyntFonts.body, // 14
        weight: MyntFonts.bold,
        color: color,
        darkColor: darkColor,
        lightColor: lightColor,
      );
}
