import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/contribution/constituent.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dashboard_enums.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/contribution_bar.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/paginated_dash_table.dart';

/// The full constituents table — every stock's weight, price move, point
/// contribution, share, direction, and the (currently-null) OI positioning
/// overlay. Sortable, default by point contribution descending, paginated.
class ConstituentsTable extends StatelessWidget {
  final IndexContribution data;

  const ConstituentsTable({super.key, required this.data});

  TextStyle _cell(BuildContext c, {Color? color, bool bold = false}) =>
      MyntWebTextStyles.tableCell(
        c,
        color: color,
        darkColor: color ?? MyntColors.textPrimaryDark,
        lightColor: color ?? MyntColors.textPrimary,
        fontWeight: bold ? MyntFonts.semiBold : MyntFonts.medium,
      );

  String _pctOrDash(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)}%';

  Widget _dash(BuildContext c) => Text('—',
      style: _cell(c,
          color: resolveThemeColor(c,
              dark: MyntColors.textTertiaryDark,
              light: MyntColors.textTertiary)));

  List<DashCol<Constituent>> _cols(BuildContext context) {
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return [
      // Symbol column hidden — Name leads the table with the col-1 bold style.
      // DashCol(
      //   label: 'Symbol',
      //   width: 100,
      //   sortKey: (r) => r.symbol,
      //   cell: (c, r) => Text(r.symbol,
      //       overflow: TextOverflow.ellipsis, style: _cell(c, bold: true)),
      // ),
      // Name and Sector split the leftover width evenly; every fixed column
      // is wide enough for its header plus the sort arrow.
      DashCol(
        label: 'Name',
        sortKey: (r) => r.name,
        cell: (c, r) => EllipsisText(r.name, style: _cell(c, bold: true)),
      ),
      DashCol(
        label: 'Sector',
        sortKey: (r) => r.sector,
        cell: (c, r) =>
            EllipsisText(r.sector, style: _cell(c, color: tertiary)),
      ),
      DashCol(
        label: 'Wt %',
        width: 84,
        numeric: true,
        sortKey: (r) => r.weightPct ?? 0,
        cell: (c, r) => Text(_pctOrDash(r.weightPct), style: _cell(c)),
      ),
      DashCol(
        label: 'Price %',
        width: 100,
        numeric: true,
        sortKey: (r) => r.priceChangePct ?? 0,
        cell: (c, r) => Text(InstaOptionsFormat.changePct(r.priceChangePct),
            style: _cell(c, color: dashChangeColor(c, r.priceChangePct))),
      ),
      DashCol(
        label: 'Points',
        width: 100,
        numeric: true,
        sortKey: (r) => r.pointContribution ?? 0,
        cell: (c, r) => Text(signedPts(r.pointContribution),
            style: _cell(c,
                color: dashChangeColor(c, r.pointContribution), bold: true)),
      ),
      DashCol(
        label: 'Share %',
        width: 100,
        numeric: true,
        sortKey: (r) => r.sharePct ?? 0,
        cell: (c, r) => Text(InstaOptionsFormat.changePct(r.sharePct),
            style: _cell(c, color: dashChangeColor(c, r.sharePct))),
      ),
      DashCol(
        label: 'Direction',
        width: 110,
        // Plain neutral text — no badge, no direction colour.
        cell: (c, r) => Text(
            r.direction.isEmpty
                ? '—'
                : '${r.direction[0].toUpperCase()}${r.direction.substring(1)}',
            style: _cell(c)),
      ),
      DashCol(
        label: 'OI Δ%',
        width: 92,
        numeric: true,
        sortKey: (r) => r.oiChangePct ?? 0,
        cell: (c, r) => r.oiChangePct == null
            ? _dash(c)
            : Text(InstaOptionsFormat.changePct(r.oiChangePct),
                style: _cell(c, color: dashChangeColor(c, r.oiChangePct))),
      ),
      DashCol(
        label: 'Buildup',
        width: 160,
        cell: (c, r) => r.category == null
            ? _dash(c)
            : DashCategoryChip(category: BuildupCategory.fromWire(r.category)),
      ),
    ];
  }

  // Direction badge retired — the column shows plain text now.
  // Widget _dirChip(BuildContext context, String dir) {
  //   final profit = resolveThemeColor(context,
  //       dark: MyntColors.profitDark, light: MyntColors.profit);
  //   final loss = resolveThemeColor(context,
  //       dark: MyntColors.lossDark, light: MyntColors.loss);
  //   final muted = resolveThemeColor(context,
  //       dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
  //   final color = dir == 'contributor'
  //       ? profit
  //       : dir == 'detractor'
  //           ? loss
  //           : muted;
  //   final label = dir.isEmpty
  //       ? '—'
  //       : '${dir[0].toUpperCase()}${dir.substring(1)}';
  //   return Align(
  //     alignment: Alignment.centerLeft,
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  //       decoration: BoxDecoration(
  //         color: color.withValues(alpha: 0.14),
  //         borderRadius: BorderRadius.circular(10),
  //       ),
  //       child: Text(label,
  //           style: MyntWebTextStyles.caption(context,
  //               color: color, fontWeight: MyntFonts.semiBold)),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return PaginatedDashTable<Constituent>(
      columns: _cols(context),
      rows: data.constituents,
      initialSortCol: 2, // Weight %, descending (Symbol column removed)
      filterKey: '${data.index}|${data.tradeDate}',
      emptyLabel: 'No constituents.',
    );
  }
}
