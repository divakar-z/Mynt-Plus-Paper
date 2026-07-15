import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/constituents_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/sector_contribution_section.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/insta_tab_chip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// The two detail views — Sector contribution and the per-stock Constituents
/// table — behind one underlined tab strip, so they share a card instead of
/// stacking. Movers and Concentration stay as their own cards above.
class ContributionDetailTabs extends StatefulWidget {
  final IndexContribution data;

  const ContributionDetailTabs({super.key, required this.data});

  @override
  State<ContributionDetailTabs> createState() =>
      _ContributionDetailTabsState();
}

class _ContributionDetailTabsState extends State<ContributionDetailTabs> {
  int _tab = 0; // 0 = Sector, 1 = Constituents

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final count = _tab == 0
        ? '${widget.data.sectorContribution.length} sectors'
        : '${widget.data.constituents.length} stocks';

    return shadcn.Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
            child: Row(
              children: [
                InstaTabChip(
                  label: 'Sector',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 6),
                InstaTabChip(
                  label: 'Constituents',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
                // const Spacer(),
                // Text(count,
                //     style: MyntWebTextStyles.caption(context, color: muted)),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: _tab == 0
                ? SectorContributionSection(data: widget.data)
                : ConstituentsTable(data: widget.data),
          ),
        ],
      ),
    );
  }

}
