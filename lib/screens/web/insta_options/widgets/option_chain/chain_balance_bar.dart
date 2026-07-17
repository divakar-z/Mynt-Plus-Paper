import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';

/// Calls-vs-puts OI balance bar with the PCR value pinned on the split (where
/// call-OI meets put-OI), coloured by band (≤0.7 red · 0.7–1.3 amber · >1.3
/// green). Reads the put/call lean at a glance.
class ChainBalanceBar extends StatelessWidget {
  final int totalCeOi;
  final int totalPeOi;
  final double? pcr;

  const ChainBalanceBar({
    super.key,
    required this.totalCeOi,
    required this.totalPeOi,
    required this.pcr,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalCeOi + totalPeOi;
    final ceFrac = total <= 0 ? 0.5 : totalCeOi / total;
    final red = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final green = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final band = _pcrColor(context);
    final card = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Label in primary; only the bracketed quantity carries the
            // direction colour (same treatment as the wall titles).
            _sideLabel(context, 'Calls OI', totalCeOi, red),
            const Spacer(),
            _sideLabel(context, 'Puts OI', totalPeOi, green),
          ],
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            return SizedBox(
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 6,
                    child: ClipRRect(
                      // borderRadius: BorderRadius.circular(5),
                      child: Row(
                        children: [
                          Expanded(
                            flex: (ceFrac * 1000).round().clamp(1, 1000),
                            child: Container(
                                height: 10,
                                color: red.withValues(alpha: 0.45)),
                          ),
                          Expanded(
                            flex: ((1 - ceFrac) * 1000).round().clamp(1, 1000),
                            child: Container(
                                height: 10,
                                color: green.withValues(alpha: 0.45)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (w * ceFrac - 27).clamp(0.0, w - 54),
                    top: 0,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: card,
                        border: Border.all(color: band),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text('PCR ${InstaOptionsFormat.pcr(pcr)}',
                          style: MyntWebTextStyles.caption(context,
                              color: band, fontWeight: MyntFonts.semiBold)),
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

  Widget _sideLabel(
      BuildContext context, String label, int oi, Color valueColor) {
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: label,
            style: MyntWebTextStyles.para(context,
                color: fg, fontWeight: MyntFonts.semiBold)),
        TextSpan(
            text: ' (${InstaOptionsFormat.oi(oi)})',
            style: MyntWebTextStyles.para(context,
                color: valueColor, fontWeight: MyntFonts.medium)),
      ]),
    );
  }

  Color _pcrColor(BuildContext context) {
    if (pcr == null) {
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    }
    if (pcr! <= 0.7) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    }
    if (pcr! > 1.3) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    }
    return resolveThemeColor(context,
        dark: MyntColors.warningDark, light: MyntColors.warning);
  }
}
