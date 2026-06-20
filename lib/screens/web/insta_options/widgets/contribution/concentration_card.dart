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
    final breadthColor = c.isNarrow ? kDashOrange : profit;
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    String pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

    return DashSectionCard(
      title: 'Concentration & breadth',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              DashStat(label: 'Top 3 share', value: pct(c.top3SharePct)),
              DashStat(label: 'Top 5 share', value: pct(c.top5SharePct)),
              DashStat(
                label: 'Breadth',
                value: c.breadth == null
                    ? '—'
                    : (c.isNarrow ? 'Narrow' : 'Broad'),
                valueColor: breadthColor,
              ),
              DashStat(
                  label: 'HHI',
                  value: c.hhi == null ? '—' : c.hhi!.toStringAsFixed(3)),
              DashStat(
                  label: 'A/D ratio',
                  value:
                      c.adRatio == null ? '—' : c.adRatio!.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 14),
          DashAdBar(
              advances: c.advances,
              declines: c.declines,
              unchanged: c.unchanged),
          const SizedBox(height: 6),
          Text(
            '${c.advances} advances · ${c.declines} declines · '
            '${c.unchanged} unchanged',
            style: MyntWebTextStyles.caption(context, color: muted),
          ),
        ],
      ),
    );
  }
}
