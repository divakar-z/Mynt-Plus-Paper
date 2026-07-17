import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/models/insta_options/option_chain/option_chain_data.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// The "where is spot in the range" read: a clean evenly-spaced metric row
/// (Support · Max-pain · Spot · Resistance) above a position bar that marks
/// where spot and max-pain sit between the strongest support and resistance
/// walls. Values live in the row (never overlap); the bar shows position only.
class ChainRangeAxis extends StatelessWidget {
  final OptionChainData data;

  const ChainRangeAxis({super.key, required this.data});

  static final NumberFormat _grp = NumberFormat('#,##0');

  @override
  Widget build(BuildContext context) {
    final spot = data.underlyingValue;
    final support = data.support.isNotEmpty ? data.support.first.strike : null;
    final resistance =
        data.resistance.isNotEmpty ? data.resistance.first.strike : null;
    final maxPain = data.maxPain;
    if (spot == null || support == null || resistance == null) {
      return const SizedBox.shrink();
    }

    final green = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final red = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final amber = resolveThemeColor(context,
        dark: MyntColors.warningDark, light: MyntColors.warning);
    final blue = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final card = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);

    final lo = support < resistance ? support : resistance;
    final hi = support < resistance ? resistance : support;
    double frac(double v) =>
        (hi - lo) == 0 ? 0.5 : ((v - lo) / (hi - lo)).clamp(0.0, 1.0);

    // Support / Resistance flank the line on the sides, so the floating
    // labels (Spot above its dot, Max pain below its tick) always sit exactly
    // on their marks — nothing to collide with at the extremes.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _anchoredLabel(context, 'Support', support, green),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              const labelW = 150.0;
              final spotLabelLeft =
                  (w * frac(spot) - labelW / 2).clamp(0.0, w - labelW);
              final mpLabelLeft = maxPain == null
                  ? 0.0
                  : (w * frac(maxPain) - labelW / 2).clamp(0.0, w - labelW);

              return SizedBox(
                height: 68,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Top lane: Spot, centred over its dot ──
                    Positioned(
                      left: spotLabelLeft,
                      top: 0,
                      width: labelW,
                      child: Text(
                        'Spot ${_grp.format(spot)}',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.para(context,
                            color: blue, fontWeight: MyntFonts.semiBold),
                      ),
                    ),
                    // ── The line ──
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 30,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Positioned(left: 0, top: 25, child: _capBox(green)),
                    Positioned(right: 0, top: 25, child: _capBox(red)),
                    if (maxPain != null)
                      Positioned(
                        left: (w * frac(maxPain) - 1.5).clamp(0.0, w - 3),
                        top: 24,
                        child:
                            Container(width: 3, height: 15, color: amber),
                      ),
                    Positioned(
                      left: (w * frac(spot) - 7).clamp(0.0, w - 14),
                      top: 24.5,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: card, width: 2),
                        ),
                      ),
                    ),
                    // ── Bottom lane: Max pain under its tick ──
                    if (maxPain != null)
                      Positioned(
                        left: mpLabelLeft,
                        top: 48,
                        width: labelW,
                        child: Center(
                          child: _anchoredLabel(
                              context, 'Max pain', maxPain, amber),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        _anchoredLabel(context, 'Resistance', resistance, red),
      ],
    );
  }

  Widget _capBox(Color c) => Container(
        width: 6,
        height: 14,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
      );

  /// Coloured label word + primary value on one line — the colour ties the
  /// label to its mark on the line.
  Widget _anchoredLabel(
      BuildContext context, String label, double? value, Color color) {
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: '$label ',
            style: MyntWebTextStyles.para(context, color: color)),
        TextSpan(
            text: value == null ? '—' : _grp.format(value),
            style: MyntWebTextStyles.para(context,
                color: primary, fontWeight: MyntFonts.semiBold)),
      ]),
      maxLines: 1,
    );
  }
}
