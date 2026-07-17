import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/contribution/constituent.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/contribution_bar.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';

/// Top contributors and detractors — the shadcn table ([DashTable], same as
/// the Sector / Constituents tabs): Symbol · Sector · diverging contribution
/// bar · Points, default sorted by Points descending so contributors lead and
/// the biggest drags close the table. Bars share one scale (the largest
/// |points| in view); the per-stock values sum to the index's point move.
class ContributionMovers extends StatelessWidget {
  final IndexContribution data;
  final int perSide;

  const ContributionMovers({super.key, required this.data, this.perSide = 8});

  TextStyle _cell(BuildContext c, {Color? color, bool bold = false}) =>
      MyntWebTextStyles.tableCell(
        c,
        color: color,
        darkColor: color ?? MyntColors.textPrimaryDark,
        lightColor: color ?? MyntColors.textPrimary,
        fontWeight: bold ? MyntFonts.semiBold : MyntFonts.medium,
      );

  List<DashCol<Constituent>> _cols(BuildContext context, double maxAbs) {
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    return [
      DashCol(
        label: 'Symbol',
        sortKey: (c) => c.symbol,
        cell: (c, r) => EllipsisText(r.symbol, style: _cell(c, bold: true)),
      ),
      DashCol(
        label: 'Sector',
        sortKey: (c) => c.sector,
        cell: (c, r) =>
            EllipsisText(r.sector, style: _cell(c, color: tertiary)),
      ),
      DashCol(
        label: 'Contribution',
        flex: 2,
        sortKey: (c) => c.pointContribution ?? 0,
        cell: (c, r) => _bar(c, r.pointContribution ?? 0, maxAbs),
      ),
      DashCol(
        label: 'Points',
        width: 90,
        numeric: true,
        sortKey: (c) => c.pointContribution ?? 0,
        cell: (c, r) {
          final v = r.pointContribution ?? 0;
          return Text(signedPts(v),
              style: _cell(c, color: v >= 0 ? profit : loss, bold: true));
        },
      ),
    ];
  }

  /// Diverging bar — negative grows left (red), positive grows right (green),
  /// scaled to [maxAbs]; same rendering as the Sector tab.
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
    final maxAbs = data.maxAbsContribution;
    final contributors = data.contributors.take(perSide).toList();
    final detractors = data.detractors.take(perSide).toList();
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    return DashSectionCard(
      title: 'Contribution to the move',
      trailing: _netChip(context),
      child: (contributors.isEmpty && detractors.isEmpty)
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No contribution data.',
                    style: MyntWebTextStyles.caption(context, color: muted)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (contributors.isNotEmpty) ...[
                  _group(context, 'Top contributors', muted),
                  DashTable<Constituent>(
                    columns: _cols(context, maxAbs),
                    rows: contributors,
                    initialSortCol: 3, // Points, descending
                  ),
                ],
                if (detractors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _group(context, 'Top detractors', muted),
                  DashTable<Constituent>(
                    columns: _cols(context, maxAbs),
                    rows: detractors,
                    initialSortCol: 3,
                    // Biggest drag first (most negative points on top).
                    initialAscending: true,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _group(BuildContext context, String label, Color muted) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: MyntWebTextStyles.body(context,
                  color: muted, fontWeight: MyntFonts.semiBold)
              .copyWith(letterSpacing: 0.5),
        ),
      );

  Widget _netChip(BuildContext context) {
    final pc = data.pointChange;
    final color = dashChangeColor(context, pc);
    // Dashed-outline pill: faint tint fill, dashed border + text in the
    // direction colour (roadmap-tag style).
    return CustomPaint(
      painter: DashedBorderPainter(color: color, radius: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text('Net   ${signedPts(pc)} pts',
            style: MyntWebTextStyles.body(context,
                color: color, fontWeight: MyntFonts.semiBold)),
      ),
    );
  }
}
