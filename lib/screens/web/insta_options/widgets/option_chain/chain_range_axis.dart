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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: _metric(context, 'Support', support, green,
                    CrossAxisAlignment.start)),
            Expanded(
                child: _metric(context, 'Max pain', maxPain, amber,
                    CrossAxisAlignment.center)),
            Expanded(
                child: _metric(context, 'Spot', spot, blue,
                    CrossAxisAlignment.center,
                    emphasize: true)),
            Expanded(
                child: _metric(context, 'Resistance', resistance, red,
                    CrossAxisAlignment.end)),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            return SizedBox(
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 5,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  _cap(0, green),
                  Positioned(
                      right: 0,
                      top: 2,
                      child: _capBox(red)),
                  if (maxPain != null)
                    Positioned(
                      left: (w * frac(maxPain) - 1).clamp(0.0, w - 2),
                      top: 3,
                      child: Container(width: 2, height: 8, color: amber),
                    ),
                  Positioned(
                    left: (w * frac(spot) - 6).clamp(0.0, w - 12),
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: card, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _cap(double left, Color c) =>
      Positioned(left: left, top: 2, child: _capBox(c));

  Widget _capBox(Color c) => Container(
        width: 3,
        height: 10,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
      );

  Widget _metric(BuildContext context, String label, double? value, Color color,
      CrossAxisAlignment cross,
      {bool emphasize = false}) {
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: [
        Text(label, style: MyntWebTextStyles.caption(context, color: color)),
        const SizedBox(height: 2),
        Text(
          value == null ? '—' : _grp.format(value),
          style: MyntWebTextStyles.bodySmall(context,
              color: emphasize ? color : primary,
              fontWeight: MyntFonts.semiBold),
        ),
      ],
    );
  }
}
