import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// ---------------------------------------------------------------------------
/// Scanner design tokens.
///
/// Every surface across the scanner pages — the list, the full scanner
/// browser, the single-scanner detail and the fundamental screener — resolves
/// its colour through here, so light and dark stay in lockstep and no widget
/// hard-codes a hex value. The values themselves come straight from the app
/// palette (MyntColors + the shadcn border), so the scanner reads as part of
/// Mynt rather than a bolt-on.
/// ---------------------------------------------------------------------------
class ScannerTokens {
  const ScannerTokens._();

  // Radii — one step per surface size so nesting never looks arbitrary.
  static const double rPanel = 16;
  static const double rCard = 14;
  static const double rControl = 10;
  static const double rTag = 6;
  static const double rPill = 999;

  /// Height of every control that sits in a page toolbar (search field,
  /// dropdown trigger, icon button), so a toolbar row lines up on one baseline.
  static const double hControl = 42;

  // Motion — one duration and one curve, used for the border fades that are
  // now the only hover response on the page.
  static const Duration fast = Duration(milliseconds: 160);
  static const Curve ease = Curves.easeOutCubic;

  static Color surface(BuildContext c) =>
      resolveThemeColor(c, dark: MyntColors.cardDark, light: MyntColors.card);

  /// One step below [surface]. Used for the panels that hold cards and for
  /// the controls inside a toolbar, so a white card always has an edge to sit
  /// against.
  static Color sunken(BuildContext c) => resolveThemeColor(c,
      dark: const Color(0xFF11161C), light: const Color(0xFFF5F8FC));

  static Color border(BuildContext c) => shadcn.Theme.of(c).colorScheme.border;

  static Color textPrimary(BuildContext c) => resolveThemeColor(c,
      dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

  static Color textSecondary(BuildContext c) => resolveThemeColor(c,
      dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

  /// Description copy — three quarters of the way from [textSecondary] to
  /// [textPrimary]. Paragraphs on the cards are long and set small, so they
  /// need more contrast than a secondary label without reading as a title.
  static Color textBody(BuildContext c) => Color.alphaBlend(
      textPrimary(c).withValues(alpha: 0.75), textSecondary(c));

  static Color accent(BuildContext c) => resolveThemeColor(c,
      dark: MyntColors.secondaryDark, light: MyntColors.primary);

  // ---------------------------------------------------------------------------
  // Landing palette.
  //
  // The hero band and the two entry cards run on the design's own colours
  // rather than the app palette, because the pair has to be told apart by hue:
  // blue for "build your own", green for "explore predefined". Everything else
  // on the scanner keeps using [accent].
  // ---------------------------------------------------------------------------

  /// Ground of the DIY ("build your own") card.
  static Color diyGround(BuildContext c) => resolveThemeColor(c,
      dark: const Color(0xFF101A2A), light: const Color(0xFFF9FBFF));

  /// Hue the DIY card carries — eyebrow, title highlight, CTA and rule.
  static Color diyAccent(BuildContext c) => resolveThemeColor(c,
      dark: MyntColors.secondaryDark, light: const Color(0xFF074DDE));

  /// Ground of the Full Scanner ("explore predefined") card.
  static Color fullGround(BuildContext c) => resolveThemeColor(c,
      dark: const Color(0xFF0D1D1A), light: const Color(0xFFF9FEFC));

  /// Hue the Full Scanner card carries.
  static Color fullAccent(BuildContext c) => resolveThemeColor(c,
      dark: const Color(0xFF2FCFA3), light: const Color(0xFF0FAF83));

  /// Ground of the Custom Scanner ("technical conditions") card.
  static Color customGround(BuildContext c) => resolveThemeColor(c,
      dark: const Color(0xFF1A1530), light: const Color(0xFFFBFAFF));

  /// Hue the Custom Scanner card carries.
  static Color customAccent(BuildContext c) => resolveThemeColor(c,
      dark: const Color(0xFFA78BFA), light: const Color(0xFF6D28D9));

  /// Description copy on the landing cards. A notch darker than [textBody]:
  /// the design sets these paragraphs in a mid slate, which reads too faint
  /// against the pale card grounds, so they take the palette's darker ink.
  static Color cardBody(BuildContext c) => resolveThemeColor(c,
      dark: const Color(0xFFAFBCCC), light: const Color(0xFF263652));

  static Color bull(BuildContext c) => resolveThemeColor(c,
      dark: MyntColors.profitDark, light: MyntColors.profit);

  static Color bear(BuildContext c) =>
      resolveThemeColor(c, dark: MyntColors.lossDark, light: MyntColors.loss);

  /// Two-layer resting elevation: a wide ambient shadow plus a tight contact
  /// shadow. Fixed — nothing on the page raises a surface on hover.
  static List<BoxShadow> lift(BuildContext c) {
    final dark = isDarkMode(c);
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.34 : 0.055),
        blurRadius: 10,
        offset: const Offset(0, 3),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.24 : 0.04),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// The page toolbar: a raised [surface] slab carrying the back button,
  /// title, one-line subtitle and the page's controls. Every scanner page
  /// opens with one of these, which is what makes them read as one product.
  static BoxDecoration toolbar(BuildContext c) => BoxDecoration(
        color: surface(c),
        borderRadius: BorderRadius.circular(rPanel),
        border: Border.all(color: border(c)),
        boxShadow: lift(c),
      );

  /// Padding that pairs with [toolbar].
  static const EdgeInsets toolbarPadding = EdgeInsets.fromLTRB(14, 12, 14, 12);

  /// A recessed tray inside a page: the ground that controls, chips or cards
  /// sit on. Flat by design — the toolbar above it is the only raised slab.
  static BoxDecoration tray(BuildContext c) => BoxDecoration(
        color: sunken(c),
        borderRadius: BorderRadius.circular(rPanel),
        border: Border.all(color: border(c)),
      );

  /// A single control inside a toolbar — dropdown trigger, filter pill.
  static BoxDecoration control(BuildContext c) => BoxDecoration(
        color: sunken(c),
        borderRadius: BorderRadius.circular(rControl),
        border: Border.all(color: border(c)),
      );

  /// Page title, shared by every scanner page header.
  static TextStyle pageTitle(BuildContext c) => MyntWebTextStyles.hero(c,
          fontWeight: MyntFonts.bold, color: textPrimary(c))
      .copyWith(letterSpacing: -0.3);

  /// The one-line strapline under a [pageTitle].
  static TextStyle pageSubtitle(BuildContext c) =>
      MyntWebTextStyles.para(c, color: textSecondary(c));
}
