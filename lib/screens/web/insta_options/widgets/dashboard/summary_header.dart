import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/day_summary.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// §5.2 Summary header — the day's KPI tiles from `summary`.
class SummaryHeader extends StatelessWidget {
  final DaySummary summary;

  const SummaryHeader({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = <Widget>[
          _Tile(
            label: 'F&O Stocks',
            value: Text('${s.total}', style: _val(context)),
          ),
          _Tile(
            label: 'Advances / Declines',
            value: _Breadth(
              advances: s.advances,
              declines: s.declines,
              unchanged: s.unchanged,
            ),
          ),
          _Tile(
            label: 'Bullish / Bearish',
            value: RichText(
              text: TextSpan(children: [
                TextSpan(text: '${s.bullish}', style: _val(context, profit)),
                TextSpan(text: '  /  ', style: _val(context)),
                TextSpan(text: '${s.bearish}', style: _val(context, loss)),
              ]),
            ),
          ),
          _Tile(
            label: 'Market PCR',
            value: Text(InstaOptionsFormat.pcr(s.marketPcr), style: _val(context)),
          ),
          _Tile(
            label: 'OI Change',
            value: Text(
              InstaOptionsFormat.changePct(s.oiChangePct),
              style: _val(context, dashChangeColor(context, s.oiChangePct)),
            ),
          ),
        ];

        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: tiles[i]),
            ],
          ],
        );
      },
    );
  }

  TextStyle _val(BuildContext context, [Color? color]) =>
      MyntWebTextStyles.head(
        context,
        color: color,
        darkColor: color ?? MyntColors.textPrimaryDark,
        lightColor: color ?? MyntColors.textPrimary,
        fontWeight: MyntFonts.semiBold,
      );
}

class _Tile extends StatelessWidget {
  final String label;
  final Widget value;

  const _Tile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return shadcn.Card(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.bodySmall(
                context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            value,
          ],
        ),
      ),
    );
  }
}

class _Breadth extends StatelessWidget {
  final int advances;
  final int declines;
  final int unchanged;

  const _Breadth({
    required this.advances,
    required this.declines,
    required this.unchanged,
  });

  @override
  Widget build(BuildContext context) {
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(children: [
            TextSpan(
              text: '$advances',
              style: MyntWebTextStyles.head(context,
                  color: profit, fontWeight: MyntFonts.semiBold),
            ),
            TextSpan(
              text: '  /  $declines',
              style: MyntWebTextStyles.head(context,
                  color: loss, fontWeight: MyntFonts.semiBold),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        DashAdBar(advances: advances, declines: declines, unchanged: unchanged),
        if (unchanged > 0) ...[
          const SizedBox(height: 4),
          Text(
            '$unchanged unchanged',
            style: MyntWebTextStyles.caption(context, color: muted),
          ),
        ],
      ],
    );
  }
}
