import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_columns.dart';

/// Pinned ladder header matching the market-watch option chain: a CALLS |
/// STRIKES | PUTS band over stacked sub-headers — CALL `OI (OI ch)` · `LTP (CH)`
/// and PUT `LTP (CH)` · `OI (OI ch)`.
class ChainHeaderRow extends StatelessWidget {
  const ChainHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final divider = resolveThemeColor(context,
        dark: MyntColors.dividerDark,
        light: MyntColors.primary.withValues(alpha: 0.07));
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    Widget label(String t) => Center(
          child: Text(t,
              style: MyntWebTextStyles.body(context,
                  color: primary, fontWeight: MyntFonts.medium)),
        );

    return Column(
      children: [
        Container(
          height: kChainHeaderTopH,
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: divider))),
          child: Row(
            children: [
              Expanded(flex: kCallPutFlex, child: label('CALLS')),
              SizedBox(width: kStrikeColWidth, child: label('STRIKES')),
              Expanded(flex: kCallPutFlex, child: label('PUTS')),
            ],
          ),
        ),
        Container(
          height: kChainSubHeaderH,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: divider))),
          child: Row(
            children: [
              Expanded(
                flex: kCallPutFlex,
                child: Row(children: [
                  Expanded(child: _stacked(context, 'OI', 'OI ch')),
                  Expanded(child: _stacked(context, 'LTP', 'CH')),
                ]),
              ),
              const SizedBox(width: kStrikeColWidth),
              Expanded(
                flex: kCallPutFlex,
                child: Row(children: [
                  Expanded(child: _stacked(context, 'LTP', 'CH')),
                  Expanded(child: _stacked(context, 'OI', 'OI ch')),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stacked(BuildContext context, String top, String bottom) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(top,
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.para(context,
                fontWeight: MyntFonts.medium,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary))),
        Text('($bottom)',
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.para(context,
                fontWeight: MyntFonts.regular,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary))),
      ],
    );
  }
}
