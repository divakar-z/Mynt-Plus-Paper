import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/stock_pcr.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/paginated_dash_table.dart';

/// §5.5 Stock PCR — every F&O stock's PCR, split bullish / bearish by buildup
/// quadrant. One search above the two tables filters both; each table sorts
/// across its whole set and paginates 25 rows per page.
class StockPcrSection extends StatefulWidget {
  final StockPcr stockPcr;

  const StockPcrSection({super.key, required this.stockPcr});

  @override
  State<StockPcrSection> createState() => _StockPcrSectionState();
}

class _StockPcrSectionState extends State<StockPcrSection> {
  final TextEditingController _search = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (_search.text != _q) setState(() => _q = _search.text);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<StockPcrRow> _filtered(List<StockPcrRow> rows) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((r) => r.symbol.toLowerCase().contains(q)).toList();
  }

  TextStyle _cell(BuildContext c, {Color? color, bool bold = false}) =>
      MyntWebTextStyles.tableCell(
        c,
        color: color,
        darkColor: color ?? MyntColors.textPrimaryDark,
        lightColor: color ?? MyntColors.textPrimary,
        fontWeight: bold ? MyntFonts.semiBold : MyntFonts.medium,
      );

  List<DashCol<StockPcrRow>> _cols() => [
        DashCol(
          label: 'Symbol',
          sortKey: (r) => r.symbol,
          cell: (c, r) => Text(r.symbol,
              overflow: TextOverflow.ellipsis, style: _cell(c, bold: true)),
        ),
        DashCol(
          label: 'PCR',
          width: 76,
          numeric: true,
          sortKey: (r) => r.pcr ?? 0,
          cell: (c, r) => Text(InstaOptionsFormat.pcr(r.pcr), style: _cell(c)),
        ),
        DashCol(
          label: 'PE OI',
          width: 82,
          numeric: true,
          sortKey: (r) => r.peOi,
          cell: (c, r) => Text(InstaOptionsFormat.oi(r.peOi), style: _cell(c)),
        ),
        DashCol(
          label: 'CE OI',
          width: 82,
          numeric: true,
          sortKey: (r) => r.ceOi,
          cell: (c, r) => Text(InstaOptionsFormat.oi(r.ceOi), style: _cell(c)),
        ),
        DashCol(
          label: 'Cat',
          width: 56,
          cell: (c, r) => DashCategoryChip(category: r.category, short: true),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final bull = _filtered(widget.stockPcr.bullish);
    final bear = _filtered(widget.stockPcr.bearish);
    return DashSectionCard(
      title: 'Stock PCR',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              SizedBox(width: 220, child: DashSearchBox(controller: _search)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SubTable(
                  title: 'Bullish',
                  rows: bull,
                  cols: _cols(),
                  filterKey: _q,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SubTable(
                  title: 'Bearish',
                  rows: bear,
                  cols: _cols(),
                  filterKey: _q,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubTable extends StatelessWidget {
  final String title;
  final List<StockPcrRow> rows;
  final List<DashCol<StockPcrRow>> cols;
  final String filterKey;

  const _SubTable({
    required this.title,
    required this.rows,
    required this.cols,
    required this.filterKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            '$title  ·  ${rows.length}',
            style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
        ),
        PaginatedDashTable<StockPcrRow>(
          columns: cols,
          rows: rows,
          initialSortCol: 1, // PCR, descending
          filterKey: filterKey,
          emptyLabel: 'No symbols match.',
        ),
      ],
    );
  }
}
