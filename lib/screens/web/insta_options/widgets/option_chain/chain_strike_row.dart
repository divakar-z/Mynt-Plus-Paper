import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/option_chain/chain_strike_row.dart';
import 'package:mynt_plus/models/insta_options/option_chain/option_leg.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/option_chain/chain_columns.dart';

/// One strike row: `CALL (flex 6) | STRIKE (150px) | PUT (flex 6)`, each side
/// two stacked columns (value over its change), matching the market-watch
/// option chain. CALL = OI/(OI ch) · LTP/(CH); PUT = LTP/(CH) · OI/(OI ch).
/// A null leg renders blank; full-row hover highlight.
class ChainStrikeRowTile extends StatelessWidget {
  final ChainStrikeRow row;
  final int index;
  final ValueNotifier<int?> hovered;

  /// Largest CE/PE OI across the chain — scales the mirrored OI bars.
  final int maxOi;

  const ChainStrikeRowTile({
    super.key,
    required this.row,
    required this.index,
    required this.hovered,
    required this.maxOi,
  });

  @override
  Widget build(BuildContext context) {
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.primaryDark.withValues(alpha: 0.07),
        light: MyntColors.primary.withValues(alpha: 0.06));
    final divider = resolveThemeColor(context,
        dark: MyntColors.dividerDark.withValues(alpha: 0.5),
        light: MyntColors.divider.withValues(alpha: 0.6));

    return MouseRegion(
      onEnter: (_) => hovered.value = index,
      onExit: (_) => hovered.value = null,
      child: ValueListenableBuilder<int?>(
        valueListenable: hovered,
        builder: (context, hov, _) {
          return Container(
            height: kChainRowH,
            decoration: BoxDecoration(
              color: hov == index ? hoverBg : Colors.transparent,
              border: Border(bottom: BorderSide(color: divider, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(flex: kCallPutFlex, child: _callCell(context)),
                _strikeCell(context),
                Expanded(flex: kCallPutFlex, child: _putCell(context)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _callCell(BuildContext context) {
    final leg = row.ce;
    if (leg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(child: _oiStack(context, leg)),
          Expanded(child: _ltpStack(context, leg)),
        ],
      ),
    );
  }

  Widget _putCell(BuildContext context) {
    final leg = row.pe;
    if (leg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(child: _ltpStack(context, leg)),
          Expanded(child: _oiStack(context, leg)),
        ],
      ),
    );
  }

  Widget _strikeCell(BuildContext context) {
    final border = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    return SizedBox(
      width: kStrikeColWidth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.symmetric(
            vertical: BorderSide(color: border, width: 0.5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              row.strike.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.medium,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary)),
            ),
            const SizedBox(height: 4),
            _oiBars(context),
          ],
        ),
      ),
    );
  }

  /// Mirrored OI histogram under the strike number: CALL OI grows left
  /// (loss-red), PUT OI grows right (profit-green), each scaled to the largest
  /// OI in view so support builds green below spot and resistance red above.
  Widget _oiBars(BuildContext context) {
    if (maxOi <= 0) return const SizedBox(height: kOiBarH);
    final ceOi = row.ce?.oi ?? 0;
    final peOi = row.pe?.oi ?? 0;
    final callColor = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final putColor = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    return SizedBox(
      height: kOiBarH,
      child: Row(
        children: [
          Expanded(
            child: FractionallySizedBox(
              widthFactor: (ceOi / maxOi).clamp(0.0, 1.0),
              heightFactor: 1,
              alignment: Alignment.centerRight,
              child: _bar(callColor),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: FractionallySizedBox(
              widthFactor: (peOi / maxOi).clamp(0.0, 1.0),
              heightFactor: 1,
              alignment: Alignment.centerLeft,
              child: _bar(putColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(Color c) => DecoratedBox(
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(kOiBarH / 2),
        ),
      );

  Widget _oiStack(BuildContext context, OptionLeg leg) {
    final lakh = (leg.oi / 100000).toStringAsFixed(2);
    return _stack(
      context,
      lakh,
      _pct(leg.oiChangePct),
      valueColor: leg.oi == 0
          ? resolveThemeColor(context,
              dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary)
          : resolveThemeColor(context,
              dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
      changeColor: dashChangeColor(context, leg.oiChangePct),
    );
  }

  Widget _ltpStack(BuildContext context, OptionLeg leg) {
    return _stack(
      context,
      InstaOptionsFormat.price(leg.ltp),
      _pct(leg.changePct),
      valueColor: (leg.ltp == null || leg.ltp == 0)
          ? resolveThemeColor(context,
              dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary)
          : resolveThemeColor(context,
              dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
      changeColor: dashChangeColor(context, leg.changePct),
    );
  }

  Widget _stack(BuildContext context, String value, String change,
      {required Color valueColor, required Color changeColor}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.body(context,
                fontWeight: MyntFonts.medium, color: valueColor)),
        Text(change,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.para(context,
                fontWeight: MyntFonts.regular, color: changeColor)),
      ],
    );
  }

  String _pct(double? v) =>
      v == null ? '(—)' : '(${v.toStringAsFixed(2)}%)';
}
