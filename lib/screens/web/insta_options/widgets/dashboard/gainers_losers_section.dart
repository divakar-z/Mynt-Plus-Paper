import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/gainers_losers.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';

/// §5.8 Gainers / losers — two ranked lists of the day's top movers.
class GainersLosersSection extends StatelessWidget {
  final GainersLosers data;

  const GainersLosersSection({super.key, required this.data});

  TextStyle _cell(BuildContext c, {Color? color, bool bold = false}) =>
      MyntWebTextStyles.tableCell(
        c,
        color: color,
        darkColor: color ?? MyntColors.textPrimaryDark,
        lightColor: color ?? MyntColors.textPrimary,
        fontWeight: bold ? MyntFonts.semiBold : MyntFonts.medium,
      );

  List<DashCol<GainerLoserRow>> _cols() => [
        DashCol(
          label: 'Symbol',
          sortKey: (r) => r.symbol,
          cell: (c, r) => Text(r.symbol,
              overflow: TextOverflow.ellipsis, style: _cell(c, bold: true)),
        ),
        DashCol(
          label: 'Price %',
          width: 84,
          numeric: true,
          sortKey: (r) => r.priceChangePct ?? 0,
          cell: (c, r) => Text(InstaOptionsFormat.changePct(r.priceChangePct),
              style: _cell(c, color: dashChangeColor(c, r.priceChangePct))),
        ),
        DashCol(
          label: 'LTP',
          width: 92,
          numeric: true,
          sortKey: (r) => r.lastClose ?? 0,
          cell: (c, r) =>
              Text(InstaOptionsFormat.price(r.lastClose), style: _cell(c)),
        ),
        DashCol(
          label: 'Cat',
          width: 56,
          cell: (c, r) => DashCategoryChip(category: r.category, short: true),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DashSectionCard(
            title: 'Top Gainers',
            child: DashTable<GainerLoserRow>(
              columns: _cols(),
              rows: data.gainers,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DashSectionCard(
            title: 'Top Losers',
            child: DashTable<GainerLoserRow>(
              columns: _cols(),
              rows: data.losers,
            ),
          ),
        ),
      ],
    );
  }
}
