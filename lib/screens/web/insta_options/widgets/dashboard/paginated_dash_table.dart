import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';

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
    this.pageSize = 25,
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
      final muted = resolveThemeColor(context,
          dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(widget.emptyLabel,
              style: MyntWebTextStyles.caption(context, color: muted)),
        ),
      );
    }

    final pageCount = (total / widget.pageSize).ceil();
    final page = _page.clamp(0, pageCount - 1);
    final start = page * widget.pageSize;
    final pageRows = all.skip(start).take(widget.pageSize).toList();
    final multiPage = pageCount > 1;

    // Per-page key so each page renders its own rows (shadcn.Table can show
    // stale rows when only the row list swaps under the same key).
    final table = DashTable<T>(
      key: ValueKey('pg_${page}_${_sortCol}_$_asc'),
      columns: widget.columns,
      rows: pageRows,
      sortColumn: _sortCol,
      ascending: _asc,
      onSort: _onSort,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (multiPage)
          // One page worth of rows, top-aligned, so every page is the same
          // height and the page below never jumps when you change pages.
          SizedBox(
            height: (widget.pageSize + 1) * widget.rowHeight + 4,
            child: Align(alignment: Alignment.topLeft, child: table),
          )
        else
          table,
        if (multiPage) ...[
          const SizedBox(height: 10),
          _Pagination(
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
        ],
      ],
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
    final fg = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Row(
      children: [
        Text(
          'Showing $firstRow–$lastRow of $total',
          style: MyntWebTextStyles.caption(context, color: muted),
        ),
        const Spacer(),
        _PageBtn(label: 'Previous', icon: Icons.chevron_left, onTap: onPrev),
        const SizedBox(width: 10),
        Text(
          'Page ${page + 1} / $pageCount',
          style: MyntWebTextStyles.caption(context, color: fg),
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
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final fg = enabled
        ? resolveThemeColor(context,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)
        : resolveThemeColor(context,
            dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final iconWidget = Icon(icon, size: 16, color: fg);
    final labelWidget = Text(
      label,
      style: MyntWebTextStyles.caption(
        context,
        color: fg,
        fontWeight: MyntFonts.semiBold,
      ),
    );
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.cardDark, light: MyntColors.card),
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: iconTrailing
                ? [labelWidget, const SizedBox(width: 4), iconWidget]
                : [iconWidget, const SizedBox(width: 4), labelWidget],
          ),
        ),
      ),
    );
  }
}
