import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/constituents_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/sector_contribution_section.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 10, 14, 0),
            child: Row(
              children: [
                _tabButton('Sector', 0),
                const SizedBox(width: 22),
                _tabButton('Constituents', 1),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(count,
                      style: MyntWebTextStyles.caption(context, color: muted)),
                ),
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

  Widget _tabButton(String label, int index) {
    final active = _tab == index;
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final strong = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        behavior: HitTestBehavior.opaque,
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: MyntWebTextStyles.bodySmall(context,
                      color: active ? strong : muted,
                      fontWeight:
                          active ? MyntFonts.semiBold : MyntFonts.medium),
                ),
              ),
              Container(height: 2, color: active ? accent : Colors.transparent),
            ],
          ),
        ),
      ),
    );
  }
}
