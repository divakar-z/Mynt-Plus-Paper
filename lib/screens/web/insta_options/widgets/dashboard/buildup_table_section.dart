import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/buildup_sentiment.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dashboard_enums.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/insta_tab_chip.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/paginated_dash_table.dart';

/// Buildup table (below the Sentiment gauge) — the per-stock detail behind the
/// quadrant counts (`buildup_sentiment.rows`). The toolbar row carries the
/// category filter chips on the left and the symbol search on the right; the
/// table below is sortable across the whole set and paginated 10 rows per page.
/// Changing the category or search resets to page 1 (sort is kept).
class BuildupTableSection extends StatefulWidget {
  final BuildupSentiment sentiment;

  const BuildupTableSection({super.key, required this.sentiment});

  @override
  State<BuildupTableSection> createState() => _BuildupTableSectionState();
}

class _BuildupTableSectionState extends State<BuildupTableSection> {
  BuildupCategory? _category;
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

  void _selectCategory(BuildupCategory? c) =>
      setState(() => _category = c);

  TextStyle _cell(BuildContext c, {Color? color, bool bold = false}) =>
      MyntWebTextStyles.tableCell(
        c,
        color: color,
        darkColor: color ?? MyntColors.textPrimaryDark,
        lightColor: color ?? MyntColors.textPrimary,
        fontWeight: bold ? MyntFonts.semiBold : MyntFonts.medium,
      );

  List<DashCol<BuildupRow>> _cols(bool showCategory) => [
        DashCol(
          label: 'Symbol',
          flex: 2, // name column gets ~2× the share of a data column
          sortKey: (r) => r.symbol,
          cell: (c, r) => Text(r.symbol,
              overflow: TextOverflow.ellipsis, style: _cell(c, bold: true)),
        ),
        // Category only shown on "All" — on a specific category tab it would
        // just repeat the tab's name for every row.
        if (showCategory)
          DashCol(
            label: 'Category', 
            width: 160, // fits the longest label ("SHORT COVERING") without ellipsis
            cell: (c, r) => DashCategoryChip(category: r.category),
          ),
        DashCol(
          label: 'LTP',
          numeric: true,
          sortKey: (r) => r.lastClose ?? 0,
          // LTP coloured by the price move (like the watchlist); the Price %
          // column stays neutral.
          cell: (c, r) => Text(InstaOptionsFormat.price(r.lastClose),
              style: _cell(c, color: dashChangeColor(c, r.priceChangePct))),
        ),
        DashCol(
          label: 'Price %',
          numeric: true,
          sortKey: (r) => r.priceChangePct ?? 0,
          cell: (c, r) => Text(InstaOptionsFormat.changePct(r.priceChangePct),
              style: _cell(c)),
        ),
        DashCol(
          label: 'OI',
          numeric: true,
          sortKey: (r) => r.oi,
          // OI coloured by its change direction; the OI % column stays neutral.
          cell: (c, r) => Text(InstaOptionsFormat.oi(r.oi),
              style: _cell(c, color: dashChangeColor(c, r.oiChangePct))),
        ),
        DashCol(
          label: 'OI %',
          numeric: true,
          sortKey: (r) => r.oiChangePct ?? 0,
          cell: (c, r) => Text(InstaOptionsFormat.changePct(r.oiChangePct),
              style: _cell(c)),
        ),
      ];

  List<BuildupRow> _filtered() {
    final q = _q.trim().toLowerCase();
    return widget.sentiment.rows.where((r) {
      if (_category != null && r.category != _category) return false;
      if (q.isNotEmpty && !r.symbol.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered();
    // Category column only adds value on "All" (mixed categories).
    final showCategory = _category == null;
    return DashSectionCard(
      title: 'BuildUp',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _FilterChips(
                  sentiment: widget.sentiment,
                  selected: _category,
                  onSelect: _selectCategory,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(width: 220, child: DashSearchBox(controller: _search)),
            ],
          ),
          const SizedBox(height: 12),
          PaginatedDashTable<BuildupRow>(
            // Key flips when the Category column shows/hides so the table
            // rebuilds with the correct sort index for the new column set.
            key: ValueKey('buildup_cat_$showCategory'),
            columns: _cols(showCategory),
            rows: rows,
            initialSortCol: showCategory ? 5 : 4, // OI %, descending
            filterKey: '$_category|$_q',
            emptyLabel: 'No stocks match.',
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final BuildupSentiment sentiment;
  final BuildupCategory? selected;
  final ValueChanged<BuildupCategory?> onSelect;

  const _FilterChips({
    required this.sentiment,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(context, 'All', sentiment.total, null),
          _chip(context, 'Long buildup', sentiment.longBuildup,
              BuildupCategory.longBuildup),
          _chip(context, 'Short covering', sentiment.shortCovering,
              BuildupCategory.shortCovering),
          _chip(context, 'Short buildup', sentiment.shortBuildup,
              BuildupCategory.shortBuildup),
          _chip(context, 'Long covering', sentiment.longCovering,
              BuildupCategory.longCovering),
        ],
      ),
    );
  }

  Widget _chip(
      BuildContext context, String label, int count, BuildupCategory? value) {
    // Shared chip → identical size / font / label to the top-nav tabs.
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InstaTabChip(
        label: label,
        count: count,
        selected: selected == value,
        onTap: () => onSelect(value),
      ),
    );
  }
}
