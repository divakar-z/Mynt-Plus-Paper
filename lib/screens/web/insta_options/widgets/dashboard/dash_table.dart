import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// One column for [DashTable]. `width` null → the column flexes to fill the
/// remaining space, sharing it with the other flex columns in proportion to
/// their [flex] factor.
class DashCol<T> {
  final String label;
  final double? width;

  /// Relative share of the leftover space when [width] is null — a name column
  /// at `flex: 2` gets twice the width of a `flex: 1` numeric column. Ignored
  /// when [width] is set.
  final int flex;
  final bool numeric;
  final Widget Function(BuildContext, T) cell;
  final Comparable<Object> Function(T)? sortKey;

  const DashCol({
    required this.label,
    required this.cell,
    this.width,
    this.flex = 1,
    this.numeric = false,
    this.sortKey,
  });
}

/// Reusable sortable table matching the app's web table look — `shadcn.Table`
/// inside `shadcn.OutlinedContainer`, header with sort arrows, row hover.
///
/// Renders **inline** (no internal vertical scroll) so the dashboard's page
/// scroll is the single scroller — internal vertical scroll-views would trap
/// the mouse wheel and stop the page from scrolling. Wide tables still scroll
/// horizontally (which doesn't conflict with the page's vertical scroll).
class DashTable<T> extends StatefulWidget {
  final List<DashCol<T>> columns;
  final List<T> rows;
  final int? initialSortCol;
  final bool initialAscending;

  /// Controlled sort: when [onSort] is set, the table does NOT sort internally
  /// — it reports header taps via [onSort] and draws the arrow from
  /// [sortColumn]/[ascending], while the parent sorts and supplies [rows].
  /// Used by paginated tables so sorting applies across all pages.
  final void Function(int columnIndex, bool ascending)? onSort;
  final int? sortColumn;
  final bool ascending;

  /// Optional footer rendered INSIDE the outlined container, below the rows
  /// (e.g. a pagination bar) — so it reads as part of the table, not a widget
  /// floating below it. Give it its own top border for a divider.
  final Widget? footer;

  /// When set, the rows area (header + rows) is pinned to this height so a short
  /// final page doesn't shrink the table; the [footer] sits below it.
  final double? bodyHeight;

  const DashTable({
    super.key,
    required this.columns,
    required this.rows,
    this.initialSortCol,
    this.initialAscending = false,
    this.onSort,
    this.sortColumn,
    this.ascending = false,
    this.footer,
    this.bodyHeight,
  });

  @override
  State<DashTable<T>> createState() => _DashTableState<T>();
}

class _DashTableState<T> extends State<DashTable<T>> {
  int? _sortCol;
  bool _asc = false;
  final ScrollController _hCtrl = ScrollController();
  final ValueNotifier<int?> _hover = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    _sortCol = widget.initialSortCol;
    _asc = widget.initialAscending;
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _hover.dispose();
    super.dispose();
  }

  bool get _controlled => widget.onSort != null;
  int? get _activeCol => _controlled ? widget.sortColumn : _sortCol;
  bool get _activeAsc => _controlled ? widget.ascending : _asc;

  List<T> get _sortedRows {
    if (_controlled) return widget.rows; // parent sorts (and paginates)
    final col = _sortCol;
    if (col == null) return widget.rows;
    final key = widget.columns[col].sortKey;
    if (key == null) return widget.rows;
    final list = [...widget.rows];
    list.sort((a, b) {
      final r = key(a).compareTo(key(b));
      return _asc ? r : -r;
    });
    return list;
  }

  void _onSort(int i) {
    if (widget.columns[i].sortKey == null) return;
    if (_controlled) {
      final asc = widget.sortColumn == i ? !widget.ascending : true;
      widget.onSort!(i, asc);
      return;
    }
    setState(() {
      if (_sortCol == i) {
        _asc = !_asc;
      } else {
        _sortCol = i;
        _asc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cols = widget.columns;
    final rows = _sortedRows;

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final fixedSum = cols
            .where((c) => c.width != null)
            .fold<double>(0, (s, c) => s + c.width!);
        // Distribute the leftover space across the flex columns in proportion
        // to their flex factor (each clamped to a usable minimum).
        final flexTotal =
            cols.where((c) => c.width == null).fold<int>(0, (s, c) => s + c.flex);
        final unit =
            flexTotal > 0 ? (constraints.maxWidth - fixedSum) / flexTotal : 0.0;
        double colW(DashCol<T> c) {
          if (c.width != null) return c.width!;
          final w = unit * c.flex;
          return w < 130 ? 130.0 : w;
        }

        final widths = <int, shadcn.TableSize>{
          for (var i = 0; i < cols.length; i++)
            i: shadcn.FixedTableSize(colW(cols[i])),
        };
        final totalW = cols.fold<double>(0, (s, c) => s + colW(c));
        final needsHScroll = totalW > constraints.maxWidth + 0.5;

        final table = shadcn.Table(
          key: ValueKey('sort_${_activeCol}_$_activeAsc'),
          columnWidths: widths,
          defaultRowHeight: const shadcn.FixedTableSize(38),
          rows: [
            shadcn.TableHeader(
              cells: [
                for (var i = 0; i < cols.length; i++)
                  _headerCell(context, cols[i], i),
              ],
            ),
            for (var r = 0; r < rows.length; r++)
              _dataRow(context, rows[r], r, cols),
          ],
        );

        final content = SizedBox(
          width: needsHScroll ? totalW : constraints.maxWidth,
          child: table,
        );

        if (!needsHScroll) return content;
        return Scrollbar(
          controller: _hCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _hCtrl,
            scrollDirection: Axis.horizontal,
            child: content,
          ),
        );
      },
    );

    // Pin the rows area to a fixed height (keeps every page the same height so
    // the layout below never jumps); the footer sits below it — both inside the
    // outlined container, so the footer reads as part of the table.
    final sizedBody = widget.bodyHeight != null
        ? SizedBox(
            height: widget.bodyHeight,
            child: Align(alignment: Alignment.topLeft, child: body),
          )
        : body;

    return shadcn.OutlinedContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sizedBody,
          if (widget.footer != null) widget.footer!,
        ],
      ),
    );
  }

  static const shadcn.Border _noBorder = shadcn.Border(
    top: shadcn.BorderSide.none,
    bottom: shadcn.BorderSide.none,
    left: shadcn.BorderSide.none,
    right: shadcn.BorderSide.none,
  );

  shadcn.TableCell _headerCell(BuildContext context, DashCol<T> col, int i) {
    final active = _activeCol == i;
    final sortable = col.sortKey != null;
    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(_noBorder),
      ),
      child: InkWell(
        onTap: sortable ? () => _onSort(i) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: col.numeric ? Alignment.centerRight : Alignment.centerLeft,
          color: resolveThemeColor(context,
              dark: MyntColors.cardDark, light: MyntColors.listItemBg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                col.numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  col.label,
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.tableHeader(
                    context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                    fontWeight: MyntFonts.semiBold,
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 4),
                Icon(
                  _activeAsc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  shadcn.TableRow _dataRow(
      BuildContext context, T row, int rowIndex, List<DashCol<T>> cols) {
    return shadcn.TableRow(
      cells: [
        for (var i = 0; i < cols.length; i++)
          shadcn.TableCell(
            theme: const shadcn.TableCellTheme(
              border: shadcn.WidgetStatePropertyAll(_noBorder),
            ),
            child: MouseRegion(
              onEnter: (_) => _hover.value = rowIndex,
              onExit: (_) => _hover.value = null,
              child: ValueListenableBuilder<int?>(
                valueListenable: _hover,
                builder: (context, hovered, _) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    alignment: cols[i].numeric
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    color: hovered == rowIndex
                        ? resolveThemeColor(context,
                            dark: MyntColors.primaryDark.withValues(alpha: 0.08),
                            light: MyntColors.primary.withValues(alpha: 0.08))
                        : Colors.transparent,
                    child: cols[i].cell(context, row),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
