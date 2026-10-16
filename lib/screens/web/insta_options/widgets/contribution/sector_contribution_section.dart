import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/models/insta_options/contribution/sector_contribution.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/contribution_bar.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';

/// Sector contribution body — the shadcn table ([DashTable], same as the
/// Constituents tab): Sector · No. of stocks · Advances · Declines · the
/// diverging contribution bar · Points. Advances green / declines red; bars
/// share one scale (the largest |points| in view). Sortable, default by
/// Points descending.
class SectorContributionSection extends StatelessWidget {
  final IndexContribution data;

  const SectorContributionSection({super.key, required this.data});

  TextStyle _cell(BuildContext c, {Color? color, bool bold = false}) =>
      MyntWebTextStyles.tableCell(
        c,
        color: color,
        darkColor: color ?? MyntColors.textPrimaryDark,
        lightColor: color ?? MyntColors.textPrimary,
        fontWeight: bold ? MyntFonts.semiBold : MyntFonts.medium,
      );

  List<DashCol<SectorContribution>> _cols(
      BuildContext context, double maxAbs) {
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    return [
      DashCol(
        label: 'Sector',
        sortKey: (s) => s.sector,
        cell: (c, s) => EllipsisText(s.sector, style: _cell(c, bold: true)),
      ),
      DashCol(
        label: 'Stocks',
        width: 110,
        sortKey: (s) => s.stocks,
        cell: (c, s) => Text('${s.stocks}', style: _cell(c)),
      ),
      DashCol(
        label: 'Advances',
        width: 96,
        sortKey: (s) => s.advances,
        cell: (c, s) =>
            Text('${s.advances}', style: _cell(c, color: profit, bold: true)),
      ),
      DashCol(
        label: 'Declines',
        width: 96,
        sortKey: (s) => s.declines,
        cell: (c, s) =>
            Text('${s.declines}', style: _cell(c, color: loss, bold: true)),
      ),
      // The diverging bar lives in a flexible cell — any widget works as a
      // table cell, and the cell's bounded width is all the bar needs.
      DashCol(
        label: 'Contribution',
        flex: 2,
        sortKey: (s) => s.pointContribution ?? 0,
        cell: (c, s) => _bar(c, s.pointContribution ?? 0, maxAbs),
      ),
      DashCol(
        label: 'Points',
        width: 90,
        numeric: true,
        sortKey: (s) => s.pointContribution ?? 0,
        cell: (c, s) {
          final v = s.pointContribution ?? 0;
          return Text(signedPts(v),
              style: _cell(c, color: v >= 0 ? profit : loss, bold: true));
        },
      ),
    ];
  }

  /// Diverging bar — negative grows left (red), positive grows right (green),
  /// scaled to [maxAbs]; same rendering as [ContribBar].
  Widget _bar(BuildContext context, double value, double maxAbs) {
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final divider = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final pos = value >= 0;
    final factor = maxAbs <= 0 ? 0.0 : (value.abs() / maxAbs).clamp(0.0, 1.0);

    Widget fill(Color c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: DecoratedBox(
            decoration: BoxDecoration(color: c.withValues(alpha: 0.85)),
          ),
        );

    return SizedBox(
      height: 22,
      child: Row(
        children: [
          Expanded(
            child: FractionallySizedBox(
              widthFactor: pos ? 0.0 : factor,
              heightFactor: 1,
              alignment: Alignment.centerRight,
              child: fill(loss),
            ),
          ),
          Container(width: 1, color: divider),
          Expanded(
            child: FractionallySizedBox(
              widthFactor: pos ? factor : 0.0,
              heightFactor: 1,
              alignment: Alignment.centerLeft,
              child: fill(profit),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Already ordered by the caller (live: throttled re-rank; snapshot: desc).
    final sectors = data.sectorContribution;
    final maxAbs = sectors.fold<double>(0, (m, s) {
      final v = (s.pointContribution ?? 0).abs();
      return v > m ? v : m;
    });
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    if (sectors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('No sector data.',
              style: MyntWebTextStyles.caption(context, color: muted)),
        ),
      );
    }
    return DashTable<SectorContribution>(
      columns: _cols(context, maxAbs),
      rows: sectors,
      initialSortCol: 5, // Points, descending
    );
  }
}
