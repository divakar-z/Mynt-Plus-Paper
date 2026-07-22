import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../provider/accessibility_provider.dart';

/// Drop-in replacement for `GoogleFonts.inter(...)` that stays dyslexia-aware.
///
/// The app styles the vast majority of its text with `GoogleFonts.inter(...)`,
/// which always renders Inter and so ignored the Dyslexia Support toggle. This
/// wrapper forwards every parameter to `GoogleFonts.inter` unchanged — so its
/// behaviour is IDENTICAL when Dyslexia Support is off — and, only when the
/// toggle is on, overrides the family with OpenDyslexic (dropping Inter's
/// fallback list) so the dyslexia-friendly face renders app-wide.
///
/// Call sites migrate with a plain `GoogleFonts.inter(` → `dysInter(` rename;
/// the signature matches google_fonts 6.3.x exactly.
TextStyle dysInter({
  TextStyle? textStyle,
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  final style = GoogleFonts.inter(
    textStyle: textStyle,
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
  if (!dyslexiaFontActive) return style;
  return style.copyWith(
    fontFamily: dyslexiaFontFamily,
    fontFamilyFallback: const <String>[],
  );
}
