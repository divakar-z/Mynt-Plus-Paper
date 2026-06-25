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
    // Footer "Showing N matches" is commented out per request — re-enable
    // this `secondary` together with the footer block at the bottom.
    // final secondary = resolveThemeColor(context,
    //     dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final headerBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);

    // Min widths that double as proportional weights for the flexible
    // columns. Stock Name carries the long company names, so it gets the
    // largest share of any spare width; numeric columns (short values) get
    // the least. Exch is fixed — it only ever shows "NSE".
    const exchW = 64.0;
    const rowHPad = 20.0;
    const stockNameMin = 300.0;
    double dataMinFor(ScanColumn c) => c.fmt == 'string' ? 150.0 : 120.0;

    return LayoutBuilder(builder: (ctx, constraints) {
      // The wrapping Container has a 1px border on each side, so the inner
      // content area is 2px narrower than the outer constraint.
      const borderW = 1.0;
      final available =
          (constraints.maxWidth - borderW * 2).clamp(0.0, double.infinity);
      // Spread the spare width proportionally across the flexible columns
      // (Stock Name + data columns) by their min width — wider columns grow
      // more, short numeric columns stay compact. Only scale up; when there
      // isn't room, fall back to mins and let the table scroll horizontally.
      final dataMinTotal =
          dataCols.fold<double>(0.0, (sum, c) => sum + dataMinFor(c));
      final flexBaseTotal = stockNameMin + dataMinTotal;
      final availableForFlex =
          (available - exchW - rowHPad * 2).clamp(0.0, double.infinity);
      final rawScale =
          flexBaseTotal == 0 ? 1.0 : availableForFlex / flexBaseTotal;
      final scale = rawScale > 1.0 ? rawScale : 1.0;
      final stockNameW = stockNameMin * scale;
      final colWidths = <double>[
        for (final c in dataCols) dataMinFor(c) * scale,
      ];
      final dataColsW = colWidths.fold<double>(0.0, (s, w) => s + w);
      final totalWidth = stockNameW + exchW + rowHPad * 2 + dataColsW;
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
                color: headerBg,
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
                  child: const _HeaderText('Exch'),
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
            child: shadcn.OutlinedContainer(
              clipBehavior: Clip.antiAlias,
              child: needsScroll
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal, child: table)
                  : table,
            ),
          ),
          // const SizedBox(height: 8),
          // Padding(
          //   padding: const EdgeInsets.only(left: 4),
          //   child: Text(widget.footer,
          //       style: MyntWebTextStyles.caption(context, color: secondary)),
          // ),
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
        style: MyntWebTextStyles.tableHeader(context,
            fontWeight: MyntFonts.semiBold,
            color: resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary)));
  }
}

/// Header text with a Positions-style sort indicator (arrow shown only on
/// the active column) plus an optional info tooltip.
class _SortHeader extends StatelessWidget {
  final String label;
  final String? description;
  final bool active;
  final bool asc;
  final VoidCallback onTap;
  /// When true, the header fills its parent's full width and right-aligns
  /// its content. Used for numeric data columns.
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
  Widget build(BuildContext context) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    final labelWidget = Flexible(
      child: Text(label,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: MyntWebTextStyles.tableHeader(context,
              fontWeight: MyntFonts.semiBold, color: secondary)),
    );

    // Positions pattern: the sort arrow appears ONLY on the active column
    // (arrow_upward / arrow_downward, 16px). Numeric (right-aligned) columns
    // place the arrow before the label; text columns after it.
    final sortArrow = active
        ? Icon(asc ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16, color: secondary)
        : null;

    // The sort-clickable area (label + arrow) and the info tooltip are
    // SIBLINGS — keeps the Tooltip's MouseRegion outside the sort gesture.
    final sortable = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alignEnd && sortArrow != null) ...[
              sortArrow,
              const SizedBox(width: 4),
            ],
            labelWidget,
            if (!alignEnd && sortArrow != null) ...[
              const SizedBox(width: 4),
              sortArrow,
            ],
          ],
        ),
      ),
    );

    final infoIcon = description == null
        ? null
        : Tooltip(
            message: description!,
            waitDuration: const Duration(milliseconds: 200),
            preferBelow: true,
            triggerMode: TooltipTriggerMode.tap,
            child: MouseRegion(
              cursor: SystemMouseCursors.help,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(shadcn.LucideIcons.info,
                    size: 15, color: secondary),
              ),
            ),
          );

    return Row(
      mainAxisSize: alignEnd ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
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
          // Fixed height so the row never grows (bounces) when the hover
          // action buttons appear — matches the Positions fixed-row layout.
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            // Stock Name (name + ticker stacked) with inline hover actions —
            // the name shrinks (ellipsis) to make room, like Positions.
            SizedBox(
              width: widget.stockNameW,
              child: Row(
                children: [
                  // Flexible (not Expanded) so the name takes only the width
                  // it needs — the hover buttons then sit right after the
                  // name text, with the rest of the column left as a gap
                  // before the Exch column (no more clashing with "NSE").
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.row.name,
                            style: MyntWebTextStyles.body(context,
                                fontWeight: MyntFonts.semiBold, color: primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        // Second line (ticker code) commented out per request.
                        // const SizedBox(height: 2),
                        // Text(widget.row.ticker,
                        //     style: MyntWebTextStyles.caption(context,
                        //             color: secondary)
                        //         .copyWith(fontFamily: 'monospace'),
                        //     maxLines: 1,
                        //     overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Hover-only action buttons — inline right after the name
                  // (Positions pattern). Their own gesture wins the tap, so
                  // "Scanner Details" never accidentally opens the Overview.
                  if (showActions) ...[
                    const SizedBox(width: 8),
                    if (widget.onTap != null)
                      _RowActionButton(
                        label: 'Overview',
                        icon: shadcn.LucideIcons.eye,
                        onPressed: widget.onTap!,
                      ),
                    if (widget.onTap != null && widget.onExplainTap != null)
                      const SizedBox(width: 6),
                    if (widget.onExplainTap != null)
                      _RowActionButton(
                        label: 'Scanner Details',
                        icon: shadcn.LucideIcons.fileSearch,
                        onPressed: widget.onExplainTap!,
                      ),
                  ],
                ],
              ),
            ),
            // EXCH
            SizedBox(
              width: widget.exchW,
              child: Text('NSE',
                  style: MyntWebTextStyles.body(context, color: secondary)),
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

/// Row-hover action — Positions-style: a small white icon square with a
/// subtle drop shadow. The label is surfaced as a tooltip.
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
    return Tooltip(
      message: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: resolveThemeColor(context,
                      dark: Colors.transparent, light: Colors.grey),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, size: 16, color: MyntColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
