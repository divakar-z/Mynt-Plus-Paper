import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';

class ScanColumn {
  final String key;
  final String label;
  final String fmt;
  final String? description;
  final bool isStandard;
  const ScanColumn({
    required this.key,
    required this.label,
    required this.fmt,
    this.description,
    this.isStandard = false,
  });
}

class ScanRow {
  final String ticker;
  final String name;
  final Map<String, dynamic> values;
  const ScanRow({required this.ticker, required this.name, required this.values});
}

/// Optional cell-level formatter. When provided, the table calls it instead
/// of the built-in `fmt`-based dispatch from `formatters.dart`. Used by the
/// custom-scan results where keys (`rsi(14)`, `sma(close,50)`) drive the
/// formatting via prefix rules rather than a per-column `fmt` field.
typedef CellFormatter = ({String text, Color? color}) Function(
    BuildContext context, ScanColumn column, dynamic rawValue);

class ScannerResultsTable extends StatefulWidget {
  final List<ScanColumn> columns;
  final List<ScanRow> rows;
  /// Tap on the row body or the "Overview" hover button — opens the
  /// symbol detail. Keeping the row click as Overview preserves muscle
  /// memory (clicking a result has always opened the symbol).
  final ValueChanged<String>? onTickerTap;
  /// Optional — when non-null, a second "Explanation" button appears on
  /// row hover next to "Overview". Wired by scanners + custom scans;
  /// left null by fundamentals (no per-row predicate to explain).
  final ValueChanged<String>? onExplainTap;
  final String footer;
  final List<ScanColumn> standardPrefixColumns;
  final CellFormatter? customCellFormatter;

  const ScannerResultsTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.footer,
    this.onTickerTap,
    this.onExplainTap,
    this.standardPrefixColumns = const [],
    this.customCellFormatter,
  });

  @override
  State<ScannerResultsTable> createState() => _ScannerResultsTableState();
}

class _ScannerResultsTableState extends State<ScannerResultsTable> {
  /// -1 = the combined "Stock Name" column (sorts by ticker).
  /// 0 = EXCH (no-op).
  /// 1+ = entries from [_dataCols].
  int? _sortColIdx;
  bool _sortAsc = true;

  List<ScanColumn> get _dataCols => [
        ...widget.standardPrefixColumns,
        ...widget.columns,
      ];

  List<ScanRow> get _sortedRows {
    if (_sortColIdx == null) return widget.rows;
    final sorted = [...widget.rows];
    if (_sortColIdx == -1) {
      sorted.sort((a, b) => _sortAsc
          ? a.ticker.compareTo(b.ticker)
          : b.ticker.compareTo(a.ticker));
      return sorted;
    }
    if (_sortColIdx == 0) return sorted; // EXCH is uniform
    final col = _dataCols[_sortColIdx! - 1];
    sorted.sort((a, b) {
      final av = a.values[col.key];
      final bv = b.values[col.key];
      if (av == null && bv == null) return 0;
      if (av == null) return _sortAsc ? 1 : -1;
      if (bv == null) return _sortAsc ? -1 : 1;
      int c;
      if (av is num && bv is num) {
        c = av.compareTo(bv);
      } else {
        c = av.toString().compareTo(bv.toString());
      }
      return _sortAsc ? c : -c;
    });
    return sorted;
  }

  void _toggleSort(int idx) {
    setState(() {
      if (_sortColIdx == idx) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColIdx = idx;
        _sortAsc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final dataCols = _dataCols;
    final rows = _sortedRows;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    // Fixed-width frame columns. Each data column gets a base width based on
    // its content type (string columns need more room than numeric ones);
    // any remaining viewport width is then distributed evenly across all
    // data columns.
    const stockNameW = 240.0;
    const exchW = 64.0;
    const rowHPad = 20.0;
    double baseWidthFor(ScanColumn c) =>
        c.fmt == 'string' ? 130.0 : 110.0;

    return LayoutBuilder(builder: (ctx, constraints) {
      // The wrapping Container has a 1px border on each side, so the inner
      // content area is 2px narrower than the outer constraint.
      const borderW = 1.0;
      final available =
          (constraints.maxWidth - borderW * 2).clamp(0.0, double.infinity);
      final fixedPart = stockNameW + exchW + rowHPad * 2;
      final totalBase = dataCols.fold<double>(
          0.0, (sum, c) => sum + baseWidthFor(c));
      final extra =
          (available - fixedPart - totalBase).clamp(0.0, double.infinity);
      final bonus =
          dataCols.isEmpty ? 0.0 : extra / dataCols.length;
      final colWidths = <double>[
        for (final c in dataCols) baseWidthFor(c) + bonus,
      ];
      final dataColsW = colWidths.fold<double>(0.0, (s, w) => s + w);
      final totalWidth = fixedPart + dataColsW;
      final needsScroll = totalWidth > available + 0.5;

      Widget table = SizedBox(
        width: needsScroll ? totalWidth : available,
        child: Column(
          children: [
            // Sticky header row
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: rowHPad, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(children: [
                SizedBox(
                  width: stockNameW,
                  child: _SortHeader(
                    label: 'Stock Name',
                    active: _sortColIdx == -1,
                    asc: _sortAsc,
                    onTap: () => _toggleSort(-1),
                  ),
                ),
                SizedBox(
                  width: exchW,
                  child: const _HeaderText('EXCH'),
                ),
                for (int i = 0; i < dataCols.length; i++)
                  SizedBox(
                    width: colWidths[i],
                    child: _SortHeader(
                      label: dataCols[i].label,
                      description: dataCols[i].description,
                      active: _sortColIdx == i + 1,
                      asc: _sortAsc,
                      onTap: () => _toggleSort(i + 1),
                      alignEnd: dataCols[i].fmt != 'string',
                    ),
                  ),
              ]),
            ),
            // Scrollable rows
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => Divider(
                    height: 1, color: border.withValues(alpha: 0.4)),
                itemBuilder: (_, i) {
                  final r = rows[i];
                  return _DataRow(
                    row: r,
                    cols: dataCols,
                    stockNameW: stockNameW,
                    exchW: exchW,
                    colWidths: colWidths,
                    customCellFormatter: widget.customCellFormatter,
                    onTap: widget.onTickerTap == null
                        ? null
                        : () => widget.onTickerTap!(r.ticker),
                    onExplainTap: widget.onExplainTap == null
                        ? null
                        : () => widget.onExplainTap!(r.ticker),
                  );
                },
              ),
            ),
          ],
        ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: needsScroll
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal, child: table)
                  : table,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(widget.footer,
                style: MyntWebTextStyles.caption(context, color: secondary)),
          ),
        ],
      );
    });
  }
}

/// Single-cell header — uppercase, semibold, tertiary color.
class _HeaderText extends StatelessWidget {
  final String label;
  // ignore: unused_element_parameter
  const _HeaderText(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: MyntWebTextStyles.caption(context,
                fontWeight: MyntFonts.semiBold,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary))
            .copyWith(letterSpacing: 0.6));
  }
}

/// Header text with up/down sort indicator + optional info tooltip.
class _SortHeader extends StatefulWidget {
  final String label;
  final String? description;
  final bool active;
  final bool asc;
  final VoidCallback onTap;
  /// When true, the header fills its parent's full width and right-aligns
  /// its content (label + arrow + info). Used for numeric data columns.
  final bool alignEnd;
  const _SortHeader({
    required this.label,
    this.description,
    required this.active,
    required this.asc,
    required this.onTap,
    this.alignEnd = false,
  });

  @override
  State<_SortHeader> createState() => _SortHeaderState();
}

class _SortHeaderState extends State<_SortHeader> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final color = widget.active ? primary : secondary;

    final labelWidget = Flexible(
      child: Text(widget.label,
          textAlign: widget.alignEnd ? TextAlign.end : TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: MyntWebTextStyles.caption(context,
                  fontWeight: MyntFonts.semiBold, color: color)
              .copyWith(letterSpacing: 0.6)),
    );
    final sortIcon = Icon(
      widget.active
          ? (widget.asc
              ? shadcn.LucideIcons.arrowUp
              : shadcn.LucideIcons.arrowDown)
          : shadcn.LucideIcons.chevronsUpDown,
      size: 10,
      color: widget.active || _hover ? color : color.withValues(alpha: 0.5),
    );

    // The sort-clickable area (label + arrow) and the info tooltip are
    // SIBLINGS — keeps the Tooltip's MouseRegion outside the sort gesture
    // detector so hover works.
    final sortable = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Inside this inner Row, Flexible has the parent Row's bounded
            // width as its constraint — so the label can wrap to 2 lines.
            labelWidget,
            const SizedBox(width: 4),
            sortIcon,
          ],
        ),
      ),
    );

    final infoIcon = widget.description == null
        ? null
        : Tooltip(
            message: widget.description!,
            waitDuration: const Duration(milliseconds: 200),
            preferBelow: true,
            triggerMode: TooltipTriggerMode.tap,
            child: MouseRegion(
              cursor: SystemMouseCursors.help,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(shadcn.LucideIcons.info,
                    size: 12, color: secondary),
              ),
            ),
          );

    // Outer Row fills the parent's width so Flexible/Expanded inside the
    // sortable cluster has space to flex into.
    return Row(
      mainAxisSize: widget.alignEnd ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment:
          widget.alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(child: sortable),
        if (infoIcon != null) ...[
          const SizedBox(width: 6),
          infoIcon,
        ],
      ],
    );
  }
}

class _DataRow extends StatefulWidget {
  final ScanRow row;
  final List<ScanColumn> cols;
  final double stockNameW;
  final double exchW;
  final List<double> colWidths;
  final CellFormatter? customCellFormatter;
  final VoidCallback? onTap;
  final VoidCallback? onExplainTap;
  const _DataRow({
    required this.row,
    required this.cols,
    required this.stockNameW,
    required this.exchW,
    required this.colWidths,
    required this.onTap,
    this.onExplainTap,
    this.customCellFormatter,
  });

  @override
  State<_DataRow> createState() => _DataRowState();
}

class _DataRowState extends State<_DataRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    final hasAnyAction =
        widget.onTap != null || widget.onExplainTap != null;
    final showActions = _hover && hasAnyAction;

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: _hover ? hoverBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(children: [
                // Stock Name (name + ticker stacked)
                SizedBox(
                  width: widget.stockNameW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.row.name,
                          style: MyntWebTextStyles.body(context,
                              fontWeight: MyntFonts.semiBold, color: primary),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(widget.row.ticker,
                          style: MyntWebTextStyles.caption(context,
                                  color: secondary)
                              .copyWith(fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // EXCH
                SizedBox(
                  width: widget.exchW,
                  child: Text('NSE',
                      style:
                          MyntWebTextStyles.body(context, color: secondary)),
                ),
                // Data columns — sized per-column so strings (sector/industry)
                // get more room than numerics.
                for (int i = 0; i < widget.cols.length; i++)
                  SizedBox(
                    width: widget.colWidths[i],
                    child: Align(
                      alignment: widget.cols[i].fmt == 'string'
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: _buildCell(context, widget.row, widget.cols[i]),
                    ),
                  ),
              ]),
              // Hover-only action buttons — Positioned over the trailing
              // edge of the row, vertically centered. Their own InkWell
              // gestures consume the click before the row GestureDetector
              // sees it, so clicking "Explanation" never accidentally
              // opens the Overview.
              if (showActions)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onTap != null)
                          _RowActionButton(
                            label: 'Overview',
                            icon: shadcn.LucideIcons.eye,
                            onPressed: widget.onTap!,
                          ),
                        if (widget.onTap != null &&
                            widget.onExplainTap != null)
                          const SizedBox(width: 6),
                        if (widget.onExplainTap != null)
                          _RowActionButton(
                            label: 'Scanner Details',
                            icon: shadcn.LucideIcons.fileSearch,
                            onPressed: widget.onExplainTap!,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(BuildContext context, ScanRow r, ScanColumn c) {
    final raw = r.values[c.key];
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    // Custom formatter takes precedence over the built-in fmt dispatch —
    // used by the custom-scan results where keys drive formatting.
    if (widget.customCellFormatter != null) {
      final res = widget.customCellFormatter!(context, c, raw);
      return Text(
        res.text,
        style: MyntWebTextStyles.body(context,
                fontWeight: MyntFonts.medium,
                color: res.color ?? (raw == null ? secondary : primary))
            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      );
    }

    if (raw == null) {
      return Text('—',
          style: MyntWebTextStyles.body(context, color: secondary));
    }
    if (raw is num) {
      final res = formatColumn(context, raw, c.fmt);
      return Text(
        res.text,
        style: MyntWebTextStyles.body(context,
                fontWeight: MyntFonts.medium,
                color: res.color ?? primary)
            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      );
    }
    return Text(raw.toString(),
        style: MyntWebTextStyles.body(context, color: primary));
  }
}

/// Small white pill button surfaced on row hover. Compact (28px) so two of
/// them fit at the trailing edge without crowding the data columns.
class _RowActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _RowActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final bg = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark, light: Colors.white);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: primary),
              const SizedBox(width: 6),
              Text(label,
                  style: MyntWebTextStyles.caption(context,
                      fontWeight: MyntFonts.semiBold, color: primary)),
            ],
          ),
        ),
      ),
    );
  }
}
