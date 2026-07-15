import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';

/// Concentration & breadth of the move: top-N share of the magnitude, the
/// narrow/broad verdict + HHI, and the advance/decline split.
class ConcentrationCard extends StatelessWidget {
  final IndexContribution data;

  const ConcentrationCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = data.concentration;
    if (c == null) return const SizedBox.shrink();
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final breadthColor = c.isNarrow ? kDashOrange : profit;
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    String pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

    final stats = <Widget>[
      DashStat(label: 'Top 3 share', value: pct(c.top3SharePct)),
      DashStat(label: 'Top 5 share', value: pct(c.top5SharePct)),
      DashStat(
        label: 'Breadth',
        value: c.breadth == null ? '—' : (c.isNarrow ? 'Narrow' : 'Broad'),
        valueColor: breadthColor,
      ),
      DashStat(label: 'HHI', value: c.hhi == null ? '—' : c.hhi!.toStringAsFixed(3)),
      DashStat(
          label: 'A/D ratio',
          value: c.adRatio == null ? '—' : c.adRatio!.toStringAsFixed(2)),
    ];

    return DashSectionCard(
      title: 'Concentration & breadth',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Each stat framed as its own bordered mini-card, matching the
          // Index Contribution header tiles.
          Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _statTile(context, stats[i])),
              ],
            ],
          ),
          const SizedBox(height: 14),
          DashAdBar(
              advances: c.advances,
              declines: c.declines,
              unchanged: c.unchanged),
          const SizedBox(height: 8),
          // Advance / decline split as chips — same design as the Market
          // Dashboard Sentiment legend.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _adChip(context, 'Advances', c.advances, profit),
              _adChip(context, 'Declines', c.declines, loss),
              _adChip(context, 'Unchanged', c.unchanged, muted),
            ],
          ),
        ],
      ),
    );
  }

  /// One legend chip: colour-tinted background, uppercase label in the
  /// category colour, count in bold primary — mirrors the Sentiment legend.
  Widget _adChip(BuildContext context, String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: MyntWebTextStyles.para(context,
                color: color, fontWeight: MyntFonts.medium),
          ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: MyntWebTextStyles.caption(context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
                fontWeight: MyntFonts.bold),
          ),
        ],
      ),
    );
  }

  /// One stat in a bordered mini-card, same frame as the header tiles.
  Widget _statTile(BuildContext context, Widget stat) {
    final border = resolveThemeColor(context,
            dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary)
        .withValues(alpha: 0.2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: stat,
    );
  }
}
