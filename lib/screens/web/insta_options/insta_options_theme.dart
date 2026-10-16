import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// Resolved theme tokens for the InstaOptions Analytics module.
///
/// Maps the README's internal token names (bgPrimary, accent, profit, etc.)
/// onto MyntColors light/dark fields, picking the right variant from the
/// **shadcn** theme brightness (via [isDarkMode]) — the same source every
/// other widget in this module resolves against. Reading the Material
/// `Theme.of(context)` here left these tokens light while the rest of the
/// app went dark. Use `InstaOptionsTokens.of(context)` everywhere; do not
/// hard-code hex.
class InstaOptionsTokens {
  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgTertiary;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentDim;
  final Color profit;
  final Color loss;
  final Color warning;
  final Color info;
  final Color neutral;
  final Color barCe;
  final Color barPe;
  final Color atmHighlight;
  final Color sdMarker;

  const InstaOptionsTokens._({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentDim,
    required this.profit,
    required this.loss,
    required this.warning,
    required this.info,
    required this.neutral,
    required this.barCe,
    required this.barPe,
    required this.atmHighlight,
    required this.sdMarker,
  });

  static InstaOptionsTokens of(BuildContext context) =>
      isDarkMode(context) ? _dark : _light;

  static final InstaOptionsTokens _light = InstaOptionsTokens._(
    bgPrimary: MyntColors.backgroundColor,
    bgSecondary: MyntColors.card,
    bgTertiary: MyntColors.cardHover,
    border: MyntColors.cardBorder,
    textPrimary: MyntColors.textPrimary,
    textSecondary: MyntColors.textSecondary,
    textMuted: MyntColors.textTertiary,
    accent: MyntColors.primary,
    accentDim: MyntColors.secondary,
    profit: MyntColors.profit,
    loss: MyntColors.loss,
    warning: MyntColors.warning,
    info: MyntColors.secondary,
    neutral: MyntColors.textTertiary,
    barCe: Color.fromRGBO(0, 177, 79, 0.4),
    barPe: Color.fromRGBO(255, 23, 23, 0.4),
    atmHighlight: MyntColors.selectedBg,
    sdMarker: Color.fromRGBO(74, 74, 74, 0.6),
  );

  static final InstaOptionsTokens _dark = InstaOptionsTokens._(
    bgPrimary: MyntColors.backgroundColorDark,
    bgSecondary: MyntColors.cardDark,
    bgTertiary: MyntColors.cardHoverDark,
    border: MyntColors.cardBorderDark,
    textPrimary: MyntColors.textPrimaryDark,
    textSecondary: MyntColors.textSecondaryDark,
    textMuted: MyntColors.textTertiaryDark,
    accent: MyntColors.primaryDark,
    accentDim: MyntColors.secondaryDark,
    profit: MyntColors.profitDark,
    loss: MyntColors.lossDark,
    warning: MyntColors.warningDark,
    info: MyntColors.secondaryDark,
    neutral: MyntColors.textTertiaryDark,
    barCe: Color.fromRGBO(63, 185, 80, 0.4),
    barPe: Color.fromRGBO(248, 81, 73, 0.4),
    atmHighlight: MyntColors.selectedBgDark,
    sdMarker: Color.fromRGBO(139, 148, 158, 0.6),
  );
}
