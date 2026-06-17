import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/buildup_sentiment.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dashboard_enums.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/paginated_dash_table.dart';

/// Buildup table (below the Sentiment gauge) — the per-stock detail behind the
/// quadrant counts (`buildup_sentiment.rows`). The toolbar row carries the
/// category filter chips on the left and the symbol search on the right; the
/// table below is sortable across the whole set and paginated 25 rows per page.
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

  List<DashCol<BuildupRow>> _cols() => [
        DashCol(
          label: 'Symbol',
          sortKey: (r) => r.symbol,
          cell: (c, r) => Text(r.symbol,
              overflow: TextOverflow.ellipsis, style: _cell(c, bold: true)),
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
          label: 'Price %',
          width: 86,
          numeric: true,
          sortKey: (r) => r.priceChangePct ?? 0,
          cell: (c, r) => Text(InstaOptionsFormat.changePct(r.priceChangePct),
              style: _cell(c, color: dashChangeColor(c, r.priceChangePct))),
        ),
        DashCol(
          label: 'OI',
          width: 84,
          numeric: true,
          sortKey: (r) => r.oi,
          cell: (c, r) => Text(InstaOptionsFormat.oi(r.oi), style: _cell(c)),
        ),
        DashCol(
          label: 'OI %',
          width: 84,
          numeric: true,
          sortKey: (r) => r.oiChangePct ?? 0,
          cell: (c, r) => Text(InstaOptionsFormat.changePct(r.oiChangePct),
              style: _cell(c, color: dashChangeColor(c, r.oiChangePct))),
        ),
        DashCol(
          label: 'Category',
          width: 118,
          cell: (c, r) => DashCategoryChip(category: r.category),
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
    return DashSectionCard(
      title: 'Buildup',
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
            columns: _cols(),
            rows: rows,
            initialSortCol: 4, // OI %, descending
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
          _chip(context, 'Short cov.', sentiment.shortCovering,
              BuildupCategory.shortCovering),
          _chip(context, 'Short buildup', sentiment.shortBuildup,
              BuildupCategory.shortBuildup),
          _chip(context, 'Long cov.', sentiment.longCovering,
              BuildupCategory.longCovering),
        ],
      ),
    );
  }

  Widget _chip(
      BuildContext context, String label, int count, BuildupCategory? value) {
    final active = selected == value;
    final accent = value == null
        ? resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary)
        : dashCategoryColor(context, value);
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final strong = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final mutedNum = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onSelect(value),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active ? accent.withValues(alpha: 0.14) : bg,
              border: Border.all(
                  color: active ? accent : Colors.transparent, width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: MyntWebTextStyles.caption(
                    context,
                    color: active ? strong : fg,
                    fontWeight: active ? MyntFonts.semiBold : MyntFonts.medium,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: MyntWebTextStyles.caption(
                    context,
                    color: mutedNum,
                    fontWeight: MyntFonts.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
