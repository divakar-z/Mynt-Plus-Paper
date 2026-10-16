import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';

/// A [DashTable] wrapped with pagination — [pageSize] rows per page with a
/// Previous / Next footer, sorting that applies across the WHOLE set (not just
/// the visible page), and a fixed height per page so a short final page doesn't
/// shrink the table and shift the page below it. Tables that fit on one page
/// size to content and show no footer.
///
/// Reset-to-page-1 triggers:
///  • pass a [filterKey] that changes when an upstream filter/search narrows
///    the same columns — page resets, sort is preserved; or
///  • give the whole widget a [Key] that changes when the table's shape changes
///    (e.g. a toggle that swaps the columns) — that resets the sort too.
class PaginatedDashTable<T> extends StatefulWidget {
  final List<DashCol<T>> columns;
  final List<T> rows;
  final int pageSize;
  final int? initialSortCol;
  final bool initialAscending;
  final Object? filterKey;
  final double rowHeight;
  final String emptyLabel;

  const PaginatedDashTable({
    super.key,
    required this.columns,
    required this.rows,
    this.pageSize = 10,
    this.initialSortCol,
    this.initialAscending = false,
    this.filterKey,
    this.rowHeight = 38,
    this.emptyLabel = 'No rows match.',
  });

  @override
  State<PaginatedDashTable<T>> createState() => _PaginatedDashTableState<T>();
}

class _PaginatedDashTableState<T> extends State<PaginatedDashTable<T>> {
  int _page = 0;
  int? _sortCol;
  bool _asc = false;

  @override
  void initState() {
    super.initState();
    _sortCol = widget.initialSortCol;
    _asc = widget.initialAscending;
  }

  @override
  void didUpdateWidget(covariant PaginatedDashTable<T> old) {
    super.didUpdateWidget(old);
    // Upstream filter/search changed → back to page 1 (keep the sort).
    if (old.filterKey != widget.filterKey) _page = 0;
  }

  List<T> get _sorted {
    final col = _sortCol;
    if (col == null || col < 0 || col >= widget.columns.length) {
      return widget.rows;
    }
    final key = widget.columns[col].sortKey;
    if (key == null) return widget.rows;
    final list = [...widget.rows];
    list.sort((a, b) {
      final r = key(a).compareTo(key(b));
      return _asc ? r : -r;
    });
    return list;
  }

  void _onSort(int col, bool asc) => setState(() {
        _sortCol = col;
        _asc = asc;
        _page = 0;
      });

  @override
  Widget build(BuildContext context) {
    final all = _sorted;
    final total = all.length;

    if (total == 0) {
      // App-standard empty state — same widget the Holdings tables use.
      // `subtitle` is suppressed (its default sizes to 70% of screen width and
      // would overflow narrow panes like Gainers/Losers); the per-table
      // `emptyLabel` carries the message as the title instead.
      return NoDataFoundWeb(
        title: widget.emptyLabel,
        subtitle: null,
        primaryEnabled: false,
        secondaryEnabled: false,
      );
    }

    final pageCount = (total / widget.pageSize).ceil();
    final page = _page.clamp(0, pageCount - 1);
    final start = page * widget.pageSize;
    final pageRows = all.skip(start).take(widget.pageSize).toList();
    final multiPage = pageCount > 1;

    final borderColor = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    // Pagination bar rendered as the DashTable footer — it lives INSIDE the
    // table's outlined container (below the rows, above a top-border divider),
    // so it's attached to the table like the Positions total row, not floating
    // below the card.
    final footer = multiPage
        ? Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor, width: 1)),
            ),
            child: _Pagination(
              firstRow: start + 1,
              lastRow: start + pageRows.length,
              total: total,
              page: page,
              pageCount: pageCount,
              onPrev: page > 0 ? () => setState(() => _page = page - 1) : null,
              onNext: page < pageCount - 1
                  ? () => setState(() => _page = page + 1)
                  : null,
            ),
          )
        : null;

    // Per-page key so each page renders its own rows (shadcn.Table can show
    // stale rows when only the row list swaps under the same key).
    return DashTable<T>(
      key: ValueKey('pg_${page}_${_sortCol}_$_asc'),
      columns: widget.columns,
      rows: pageRows,
      sortColumn: _sortCol,
      ascending: _asc,
      onSort: _onSort,
      // Fixed rows-area height on multi-page tables so a short final page keeps
      // the table (and the layout below) from jumping.
      bodyHeight:
          multiPage ? (widget.pageSize + 1) * widget.rowHeight + 4 : null,
      footer: footer,
    );
  }
}

class _Pagination extends StatelessWidget {
  final int firstRow;
  final int lastRow;
  final int total;
  final int page;
  final int pageCount;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _Pagination({
    required this.firstRow,
    required this.lastRow,
    required this.total,
    required this.page,
    required this.pageCount,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final bg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Row(
      children: [
        Text(
          'Showing $firstRow–$lastRow of $total',
          style: MyntWebTextStyles.para(context, color: muted),
        ),
        const Spacer(),
        _PageBtn(label: 'Previous', icon: Icons.chevron_left, onTap: onPrev),
        const SizedBox(width: 10),
        Text(
          'Page ${page + 1} / $pageCount',
          style: MyntWebTextStyles.para(context, color: bg, fontWeight: MyntFonts.semiBold),
        ),
        const SizedBox(width: 10),
        _PageBtn(
          label: 'Next',
          icon: Icons.chevron_right,
          iconTrailing: true,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _PageBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool iconTrailing;
  final VoidCallback? onTap;

  const _PageBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    // Resolve via the shadcn theme (like the rest of the module) — the
    // Material theme stays light even when the app is dark.
    final isDark = isDarkMode(context);
    // Accent (blue) text + arrow when actionable; muted secondary colour when
    // at the first / last page — mirrors the "New Watchlist" accent-text button
    // (borderless, subtle hover, no persistent background).
    final color = enabled
        ? resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary)
        : resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final iconWidget = Icon(icon, size: 15, color: color);
    final labelWidget = Text(
      label,
      style: MyntWebTextStyles.para(
        context,
        color: color,
        fontWeight: MyntFonts.semiBold,
      ),
    );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor:
            (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        splashColor:
            (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        highlightColor:
            (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: iconTrailing
                ? [labelWidget, const SizedBox(width: 2), iconWidget]
                : [iconWidget, const SizedBox(width: 2), labelWidget],
          ),
        ),
      ),
    );
  }
}
