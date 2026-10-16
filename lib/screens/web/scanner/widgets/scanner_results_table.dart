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
  /// Optional column pinned directly after Stock Name (before Symbol / Exch).
  /// Used by the Fundamental Screener to surface Market Cap prominently as
  /// the primary size metric of each match.
  final ScanColumn? secondColumn;
  /// Whether the fixed Symbol / Exch cells are rendered. Callers that expose
  /// column visibility (Fundamentals) flip these from the Manage Columns
  /// menu; older callers get the default `true` and see no change.
  final bool showSymbol;
  final bool showExch;
  final CellFormatter? customCellFormatter;

  const ScannerResultsTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.footer,
    this.onTickerTap,
    this.onExplainTap,
    this.standardPrefixColumns = const [],
    this.secondColumn,
    this.showSymbol = true,
    this.showExch = true,
    this.customCellFormatter,
  });

  @override
  State<ScannerResultsTable> createState() => _ScannerResultsTableState();
}

class _ScannerResultsTableState extends State<ScannerResultsTable> {
  /// -2 = the "Stock Name" column (sorts by name).
  /// -1 = the "Symbol" column (sorts by ticker).
  /// 0 = EXCH (no-op).
  /// 1+ = entries from [_dataCols].
  int? _sortColIdx;
  bool _sortAsc = true;

  // Always-visible scrollbars (matches the financials table): horizontal for
  // the many data columns, vertical for the rows.
  final ScrollController _hCtrl = ScrollController();
  final ScrollController _vCtrl = ScrollController();

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  List<ScanColumn> get _dataCols => [
        ...widget.standardPrefixColumns,
        ...widget.columns,
      ];

  List<ScanRow> get _sortedRows {
    if (_sortColIdx == null) return widget.rows;
    final sorted = [...widget.rows];
    if (_sortColIdx == -3 && widget.secondColumn != null) {
      // Sort by the second column's raw value (Market Cap in the Fundamental
      // Screener). Uses the same null-first / numeric-vs-string rules as the
      // dynamic data columns below.
      final key = widget.secondColumn!.key;
      sorted.sort((a, b) {
        final av = a.values[key];
        final bv = b.values[key];
        if (av == null && bv == null) return 0;
        if (av == null) return _sortAsc ? 1 : -1;
        if (bv == null) return _sortAsc ? -1 : 1;
        final c = (av is num && bv is num)
            ? av.compareTo(bv)
            : av.toString().compareTo(bv.toString());
        return _sortAsc ? c : -c;
      });
      return sorted;
    }
    if (_sortColIdx == -2) {
      sorted.sort((a, b) => _sortAsc
          ? a.name.compareTo(b.name)
          : b.name.compareTo(a.name));
      return sorted;
    }
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
    final thumb = secondary.withValues(alpha: 0.5);
    final headerBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);

    // Columns are sized to the CONTENT they hold rather than to one uniform
    // track: a stock name needs far more room than "NSE" or a 2-decimal
    // ratio. Each column carries a minimum plus a growth weight — spare
    // width goes to the columns that can use it (names, sector labels) and
    // skips the ones with fixed-length content (ticker, exchange), which is
    // what made the old equal-width split feel so sparse. Anything narrower
    // than the sum of the minimums scrolls horizontally instead.
    const rowHPad = 16.0;
    const stockNameMin = 230.0; // "HITACHI ENERGY INDIA LTD"
    const symbolMin = 120.0; // tickers are short and fixed-ish
    const exchMin = 80.0; // "NSE"
    const textColMin = 150.0; // Sector / Industry labels
    const numColMin = 112.0; // prices, ratios, percentages

    const stockNameGrow = 3.0;
    const textColGrow = 2.0;
    const numColGrow = 1.0;
    const fixedGrow = 0.0; // Symbol / Exch never widen

    double minWidthOf(ScanColumn c) =>
        c.fmt == 'string' ? textColMin : numColMin;
    double growOf(ScanColumn c) => c.fmt == 'string' ? textColGrow : numColGrow;

    return LayoutBuilder(builder: (ctx, constraints) {
      const borderW = 1.0;
      final available =
          (constraints.maxWidth - borderW * 2).clamp(0.0, double.infinity);
      final availableForContent =
          (available - rowHPad * 2).clamp(0.0, double.infinity);

      final hasSecondCol = widget.secondColumn != null;
      // Tracks in render order: Stock Name, [second], [Symbol], [Exch], then
      // the data columns. Hidden columns drop out entirely so the remaining
      // ones absorb their space.
      final mins = <double>[
        stockNameMin,
        if (hasSecondCol) minWidthOf(widget.secondColumn!),
        if (widget.showSymbol) symbolMin,
        if (widget.showExch) exchMin,
        for (final c in dataCols) minWidthOf(c),
      ];
      final grows = <double>[
        stockNameGrow,
        if (hasSecondCol) growOf(widget.secondColumn!),
        if (widget.showSymbol) fixedGrow,
        if (widget.showExch) fixedGrow,
        for (final c in dataCols) growOf(c),
      ];
      final totalMin = mins.fold<double>(0, (a, b) => a + b);
      final totalGrow = grows.fold<double>(0, (a, b) => a + b);
      final slack = availableForContent - totalMin;
      final widths = (slack <= 0 || totalGrow == 0)
          ? mins
          : [
              for (var i = 0; i < mins.length; i++)
                mins[i] + slack * (grows[i] / totalGrow),
            ];

      var w = 0;

      final stockNameW = widths[w++];
      final secondColW = hasSecondCol ? widths[w++] : 0.0;
      final symbolW = widget.showSymbol ? widths[w++] : 0.0;
      final exchW = widget.showExch ? widths[w++] : 0.0;
      final colWidths = widths.sublist(w);
      final totalWidth =
          rowHPad * 2 + widths.fold<double>(0, (a, b) => a + b);
      final needsScroll = totalWidth > available + 0.5;

      Widget table = SizedBox(
        width: needsScroll ? totalWidth : available,
        child: Column(
          children: [
            // Sticky header — a slim 36px band. Kept flat (one hairline rule
            // underneath, no vertical dividers) so the column labels read as
            // a quiet ruler above the data instead of a boxed-in strip.
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: rowHPad),
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(children: [
                SizedBox(
                  width: stockNameW,
                  child: _SortHeader(
                    label: 'Stock Name',
                    active: _sortColIdx == -2,
                    asc: _sortAsc,
                    onTap: () => _toggleSort(-2),
                  ),
                ),
                if (hasSecondCol)
                  SizedBox(
                    width: secondColW,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _SortHeader(
                        label: widget.secondColumn!.label,
                        description: widget.secondColumn!.description,
                        active: _sortColIdx == -3,
                        asc: _sortAsc,
                        onTap: () => _toggleSort(-3),
                        alignEnd: widget.secondColumn!.fmt != 'string',
                      ),
                    ),
                  ),
                if (widget.showSymbol)
                  SizedBox(
                    width: symbolW,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _SortHeader(
                        label: 'Symbol',
                        active: _sortColIdx == -1,
                        asc: _sortAsc,
                        onTap: () => _toggleSort(-1),
                      ),
                    ),
                  ),
                if (widget.showExch)
                  SizedBox(
                    width: exchW,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: _HeaderText('Exch'),
                    ),
                  ),
                for (int i = 0; i < dataCols.length; i++)
                  SizedBox(
                    width: colWidths[i],
                    // Small internal padding so adjacent right-aligned
                    // headers don't visually glue together ("ROERevenue
                    // Growth (YoY)…"). 12px total gap between columns.
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _SortHeader(
                        label: dataCols[i].label,
                        description: dataCols[i].description,
                        active: _sortColIdx == i + 1,
                        asc: _sortAsc,
                        onTap: () => _toggleSort(i + 1),
                        alignEnd: dataCols[i].fmt != 'string',
                      ),
                    ),
                  ),
              ]),
            ),
            // Scrollable rows with an always-visible vertical scrollbar.
            Expanded(
              child: RawScrollbar(
                controller: _vCtrl,
                thumbVisibility: true,
                thickness: 6,
                radius: const Radius.circular(8),
                thumbColor: thumb,
                notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
                child: ListView.separated(
                  controller: _vCtrl,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1, color: border.withValues(alpha: 0.25)),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    return _DataRow(
                      row: r,
                      cols: dataCols,
                      stockNameW: stockNameW,
                      secondColumn: widget.secondColumn,
                      secondColW: secondColW,
                      symbolW: symbolW,
                      exchW: exchW,
                      showSymbol: widget.showSymbol,
                      showExch: widget.showExch,
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
            ),
          ],
        ),
      );

      // Outer horizontal scrollbar (visible only when the columns overflow)
      // wrapping the table; the rows carry their own vertical scrollbar above.
      return shadcn.OutlinedContainer(
        clipBehavior: Clip.antiAlias,
        child: ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
          child: RawScrollbar(
            controller: _hCtrl,
            thumbVisibility: needsScroll,
            thickness: 6,
            radius: const Radius.circular(8),
            thumbColor: thumb,
            notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _hCtrl,
              scrollDirection: Axis.horizontal,
              physics: needsScroll
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: table,
            ),
          ),
        ),
      );
    });
  }
}

/// Single-cell header — small, semibold, secondary color. Shares the type
/// treatment with [_SortHeader] so sortable and static headers look alike.
class _HeaderText extends StatelessWidget {
  final String label;
  // ignore: unused_element_parameter
  const _HeaderText(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: _headerLabelStyle(context));
  }
}

/// Column-label type: 13px semibold secondary with a hair of tracking. One
/// step down from the 14px data rows so the values carry the emphasis —
/// and not two steps, because `fontScaleFactor` already shrinks everything
/// to 0.8x under 1000px of pane width.
TextStyle _headerLabelStyle(BuildContext context) =>
    MyntWebTextStyles.bodySmall(context,
      fontWeight: MyntFonts.semiBold,
      color: resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark,
          light: MyntColors.textSecondary))
        .copyWith(letterSpacing: 0.2);

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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // The sorted column reads at full text strength; the rest stay
          // secondary. Cheaper signal than a background highlight.
          style: active
              ? _headerLabelStyle(context).copyWith(
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary))
              : _headerLabelStyle(context)),
    );

    // Positions pattern: the sort arrow appears ONLY on the active column
    // (arrow_upward / arrow_downward, 16px). Numeric (right-aligned) columns
    // place the arrow before the label; text columns after it.
    final sortArrow = active
        ? Icon(asc ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14, color: secondary)
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
                    size: 13, color: secondary),
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
  final ScanColumn? secondColumn;
  final double secondColW;
  final double symbolW;
  final double exchW;
  final bool showSymbol;
  final bool showExch;
  final List<double> colWidths;
  final CellFormatter? customCellFormatter;
  final VoidCallback? onTap;
  final VoidCallback? onExplainTap;
  const _DataRow({
    required this.row,
    required this.cols,
    required this.stockNameW,
    this.secondColumn,
    this.secondColW = 0,
    required this.symbolW,
    required this.exchW,
    this.showSymbol = true,
    this.showExch = true,
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
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

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
          // action buttons appear. 44 gives the 14px values room to breathe
          // without costing many rows per screen; the horizontal padding
          // matches the header band so headers sit over their values.
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            // Stock Name column — the name takes the full width, hover
            // buttons pin to the RIGHT edge of the column so they sit BETWEEN
            // the Stock Name text and the "NSE" of the Exch column (never
            // overlap either). Positions-page pattern.
            SizedBox(
              width: widget.stockNameW,
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: widget.row.name,
                      waitDuration: const Duration(milliseconds: 400),
                      child: Text(
                        widget.row.name,
                        style: MyntWebTextStyles.body(context,
                            fontWeight: MyntFonts.medium, color: primary),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
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
                    // Trailing gap so the button strip doesn't hug the Exch
                    // column — visual breathing room before "NSE".
                    const SizedBox(width: 26),
                  ],
                ],
              ),
            ),
            // Optional second column (e.g., Market Cap) — pinned between
            // Stock Name and Symbol so the primary size metric sits right
            // next to the name.
            if (widget.secondColumn != null)
              SizedBox(
                width: widget.secondColW,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Align(
                    alignment: widget.secondColumn!.fmt == 'string'
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: _buildCell(context, widget.row, widget.secondColumn!),
                  ),
                ),
              ),
            // SYMBOL — compact tabular ticker. Rendered one step back from
            // the stock name (secondary) so the name leads the row and the
            // ticker reads as its identifier rather than competing with it.
            // Padding matches the other columns so Symbol doesn't sit flush
            // against the right-aligned Market Cap number to its left.
            if (widget.showSymbol)
              SizedBox(
                width: widget.symbolW,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    widget.row.ticker,
                    style: MyntWebTextStyles.bodySmall(context,
                            fontWeight: MyntFonts.medium, color: secondary)
                        .copyWith(fontFeatures: const [
                      FontFeature.tabularFigures(),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // EXCH — uniform for every row, so it stays quiet.
            if (widget.showExch)
              SizedBox(
                width: widget.exchW,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('NSE',
                      style: MyntWebTextStyles.bodySmall(context,
                          fontWeight: MyntFonts.medium, color: secondary)),
                ),
              ),
            // Data columns — mirror the header's 6px internal padding so
            // header labels and cell values stay aligned in the same tracks.
            for (int i = 0; i < widget.cols.length; i++)
              SizedBox(
                width: widget.colWidths[i],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Align(
                    alignment: widget.cols[i].fmt == 'string'
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: _buildCell(context, widget.row, widget.cols[i]),
                  ),
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
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: MyntWebTextStyles.body(context,
                fontWeight:
                    res.color != null ? MyntFonts.semiBold : MyntFonts.medium,
                color: res.color ?? (raw == null ? secondary : primary))
            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      );
    }

    if (raw == null) {
      return Text('—',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: MyntWebTextStyles.body(context, color: secondary));
    }
    if (raw is num) {
      final res = formatColumn(context, raw, c.fmt);
      return Text(
        res.text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        // A non-null color means the formatter classified the value as a
        // gain/loss (pct, signed_price) — those get semibold so the P&L
        // columns read at a glance down the grid.
        style: MyntWebTextStyles.body(context,
                fontWeight:
                    res.color != null ? MyntFonts.semiBold : MyntFonts.medium,
                color: res.color ?? primary)
            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      );
    }
    // String data (Sector, Industry, …) — wrap in a Tooltip so hover reveals
    // the full label when the column is too narrow.
    final text = raw.toString();
    return Tooltip(
      message: text,
      waitDuration: const Duration(milliseconds: 400),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: MyntWebTextStyles.body(context,
            fontWeight: MyntFonts.medium, color: primary),
      ),
    );
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
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.cardDark, light: MyntColors.card),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: resolveThemeColor(context,
                    dark: MyntColors.borderMutedDark,
                    light: MyntColors.borderMuted),
              ),
            ),
            child: Icon(icon, size: 15, color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}
