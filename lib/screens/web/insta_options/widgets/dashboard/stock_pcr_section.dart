import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/stock_pcr.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';

/// §5.5 Stock PCR — every F&O stock's PCR, split bullish / bearish by buildup
/// quadrant. Searchable + sortable. Tables render inline (no internal scroll),
/// so the un-searched view is capped to the top [_cap] by PCR to keep the page
/// height sane; searching reveals the full set.
class StockPcrSection extends StatefulWidget {
  final StockPcr stockPcr;

  const StockPcrSection({super.key, required this.stockPcr});

  @override
  State<StockPcrSection> createState() => _StockPcrSectionState();
}

class _StockPcrSectionState extends State<StockPcrSection> {
  static const int _cap = 50;

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

  bool get _searching => _q.trim().isNotEmpty;

  List<StockPcrRow> _filtered(List<StockPcrRow> rows) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((r) => r.symbol.toLowerCase().contains(q)).toList();
  }

  /// Top [_cap] by PCR when not searching; all matches when searching.
  List<StockPcrRow> _capped(List<StockPcrRow> filtered) {
    if (_searching || filtered.length <= _cap) return filtered;
    final sorted = [...filtered]
      ..sort((a, b) => (b.pcr ?? 0).compareTo(a.pcr ?? 0));
    return sorted.take(_cap).toList();
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
      trailing: SizedBox(width: 200, child: _SearchBox(controller: _search)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _SubTable(
              title: 'Bullish',
              total: bull.length,
              rows: _capped(bull),
              cols: _cols(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SubTable(
              title: 'Bearish',
              total: bear.length,
              rows: _capped(bear),
              cols: _cols(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubTable extends StatelessWidget {
  final String title;
  final int total;
  final List<StockPcrRow> rows;
  final List<DashCol<StockPcrRow>> cols;

  const _SubTable({
    required this.title,
    required this.total,
    required this.rows,
    required this.cols,
  });

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            '$title  ·  $total',
            style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
        ),
        DashTable<StockPcrRow>(
          columns: cols,
          rows: rows,
          initialSortCol: 1,
        ),
        if (rows.length < total)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              'Top ${rows.length} by PCR · search to find any symbol',
              style: MyntWebTextStyles.caption(context, color: muted),
            ),
          ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBox({required this.controller});

  @override
  Widget build(BuildContext context) {
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return SizedBox(
      height: 34,
      child: TextField(
        controller: controller,
        style: MyntWebTextStyles.bodySmall(context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary),
        cursorColor: accent,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search symbol',
          hintStyle: MyntWebTextStyles.bodySmall(context, color: muted),
          prefixIcon: Icon(Icons.search, size: 16, color: muted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: border, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: accent),
          ),
        ),
      ),
    );
  }
}
