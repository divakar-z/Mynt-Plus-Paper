import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_columns.dart';

/// The spot marker, rendered as a real row inserted between the two strikes
/// that bracket the underlying price (matches the market-watch chain's LTP
/// line): gradient lines on each side and a rounded spot badge centred in the
/// strike column, so it never overlaps a data cell and re-seats as spot moves.
class ChainSpotRow extends StatelessWidget {
  final double spot;

  const ChainSpotRow({super.key, required this.spot});

  @override
  Widget build(BuildContext context) {
    final line = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final badge = resolveThemeColor(context,
        dark: MyntColors.secondary, light: MyntColors.primary);

    return SizedBox(
      height: kChainRowH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              flex: kCallPutFlex,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [Colors.transparent, line]),
                ),
              ),
            ),
            SizedBox(
              width: kStrikeColWidth,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badge,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: badge.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    InstaOptionsFormat.price(spot),
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: kCallPutFlex,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [line, Colors.transparent]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
