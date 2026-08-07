import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../models/rupeecase_model/rupeecase_strategy_model.dart';
import '../../provider/fund_provider.dart';
import '../../provider/rupeecase_provider.dart';
import '../../res/mynt_web_color_styles.dart';
import '../../res/mynt_web_text_styles.dart';
import '../../sharedWidget/custom_back_btn.dart';
import '../../utils/rupee_convert_format.dart';

class AllStrategiesScreenWeb extends ConsumerWidget {
  const AllStrategiesScreenWeb({super.key, this.onBack});

  /// Invoked when the header back button is tapped. When null the back button
  /// is hidden (e.g. if the page is ever shown as a standalone route).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(rupeeCaseProvider);
    final strategies = provider.strategies;

    final Color bg = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor);
    final Color muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                CustomBackBtn(onBack: onBack),
                const SizedBox(width: 4),
              ],
              Text(
                'RupeeCase',
                style: MyntWebTextStyles.head(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: strategies.isEmpty
                ? Center(
                    child: provider.loading
                        ? const CircularProgressIndicator()
                        : Text(
                            'No strategies available',
                            style:
                                MyntWebTextStyles.para(context, color: muted),
                          ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _StrategyTable(strategies: strategies),
                  ),
          ),
        ],
      ),
    );
  }
}

const List<String> _kHeaders = [
  'Strategy',
  'Benchmark',
  'Risk',
  'Stocks',
  'Rebalance',
  'CAGR',
  '5Y Return',
  'Min Investment',
  '',
];

const int _kStrategyCol = 0;
const int _kCagrCol = 5;
const int _kActionCol = 8;

const double _kHeaderHeight = 44;
const double _kRowHeight = 52;

bool _isNumeric(String h) =>
    h == 'Stocks' ||
    h == 'Rebalance' ||
    h == 'CAGR' ||
    h == '5Y Return' ||
    h == 'Min Investment';

bool _isSortable(String h) => h.isNotEmpty;

/// Right-aligned columns: every numeric column plus the trailing action column.
bool _alignRight(String h) => _isNumeric(h) || h.isEmpty;

/// Cell padding — extra breathing room on the outer edges (first / last column)
/// so the content doesn't hug the container border, matching the Positions table.
EdgeInsets _cellPadding(int col) {
  if (col == _kStrategyCol) return const EdgeInsets.fromLTRB(16, 0, 10, 0);
  if (col == _kActionCol) return const EdgeInsets.fromLTRB(10, 0, 16, 0);
  return const EdgeInsets.symmetric(horizontal: 10);
}

/// Borderless cell theme — the row/header dividers are drawn by the wrapping
/// [Container], not per-cell (same approach as the Positions table).
const shadcn.TableCellTheme _kBorderlessCell = shadcn.TableCellTheme(
  border: shadcn.WidgetStatePropertyAll(
    shadcn.Border(
      top: shadcn.BorderSide.none,
      bottom: shadcn.BorderSide.none,
      left: shadcn.BorderSide.none,
      right: shadcn.BorderSide.none,
    ),
  ),
);

class _StrategyTable extends StatefulWidget {
  const _StrategyTable({required this.strategies});

  final List<RupeeCaseStrategy> strategies;

  @override
  State<_StrategyTable> createState() => _StrategyTableState();
}

class _StrategyTableState extends State<_StrategyTable> {
  // Default the table to CAGR, highest first.
  int? _sortColumnIndex = _kCagrCol;
  bool _sortAscending = false;

  late final ScrollController _verticalScrollController;
  late final ScrollController _horizontalScrollController;

  @override
  void initState() {
    super.initState();
    _verticalScrollController = ScrollController();
    _horizontalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  List<RupeeCaseStrategy> _sorted() {
    final list = widget.strategies.toList();
    final col = _sortColumnIndex;
    if (col == null) return list;
    final header = _kHeaders[col];

    int cmp(RupeeCaseStrategy a, RupeeCaseStrategy b) {
      switch (header) {
        case 'Strategy':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'Benchmark':
          return a.benchmark.toLowerCase().compareTo(b.benchmark.toLowerCase());
        case 'Risk':
          return a.riskLevel.toLowerCase().compareTo(b.riskLevel.toLowerCase());
        case 'Stocks':
          return a.totalStocks.compareTo(b.totalStocks);
        case 'Rebalance':
          return a.rebalanceWeeks.compareTo(b.rebalanceWeeks);
        case 'CAGR':
          return a.cagr.compareTo(b.cagr);
        case '5Y Return':
          return a.netReturn.compareTo(b.netReturn);
        case 'Min Investment':
          return a.minInvest.compareTo(b.minInvest);
        default:
          return 0;
      }
    }

    list.sort((a, b) => _sortAscending ? cmp(a, b) : -cmp(a, b));
    return list;
  }

  Map<int, double> _calculateMinWidths(BuildContext context) {
    final TextStyle cellStyle = MyntWebTextStyles.tableCell(context);
    final TextStyle nameStyle =
        MyntWebTextStyles.tableCell(context, fontWeight: MyntFonts.semiBold);
    final TextStyle headerStyle =
        MyntWebTextStyles.tableHeader(context, fontWeight: MyntFonts.semiBold);
    const double padding = 24.0;
    const double sortIcon = 20.0;

    final widths = <int, double>{};
    for (int col = 0; col < _kHeaders.length; col++) {
      final header = _kHeaders[col];

      if (header.isEmpty) {
        // Action column sized to the "Backtest" link.
        widths[col] = _measureTextWidth('Backtest', nameStyle) + padding + 8;
        continue;
      }

      double maxWidth = _measureTextWidth(header, headerStyle) +
          (_isSortable(header) ? sortIcon : 0);
      final TextStyle valueStyle = col == _kStrategyCol ? nameStyle : cellStyle;

      for (final s in widget.strategies) {
        double w = _measureTextWidth(_cellText(header, s), valueStyle);
        if (col == _kStrategyCol && s.isDynamic) w += 12; // superscript "D"
        if (w > maxWidth) maxWidth = w;
      }

      // Give the strategy-name column a generous floor so the name stays legible
      // and gets the most room (it's the primary identifier), mirroring the
      // Positions table's Instrument column.
      if (col == _kStrategyCol && maxWidth < 300) maxWidth = 300;
      widths[col] = maxWidth + padding;
    }
    return widths;
  }

  @override
  Widget build(BuildContext context) {
    final Color scrollTrack = resolveThemeColor(context,
        dark: Colors.white.withValues(alpha: 0.06),
        light: Colors.black.withValues(alpha: 0.06));
    final Color scrollThumb = resolveThemeColor(context,
        dark: Colors.white.withValues(alpha: 0.20),
        light: Colors.black.withValues(alpha: 0.20));

    final sorted = _sorted();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double available = constraints.maxWidth;
        final minWidths = _calculateMinWidths(context);

        final columnWidths = <int, double>{
          for (int i = 0; i < _kHeaders.length; i++) i: minWidths[i] ?? 100,
        };
        final double totalMin = columnWidths.values.fold(0.0, (a, b) => a + b);

        if (totalMin < available) {
          final double extra = available - totalMin;
          double totalWeight = 0;
          final weights = <int, double>{};
          for (int i = 0; i < _kHeaders.length; i++) {
            final double w = i == _kStrategyCol ? 3.5 : 1.0;
            weights[i] = w;
            totalWeight += w;
          }
          for (int i = 0; i < _kHeaders.length; i++) {
            columnWidths[i] =
                columnWidths[i]! + extra * (weights[i]! / totalWeight);
          }
        } else if (totalMin > available) {
          final double excess = totalMin - available;
          final absMin = <int, double>{
            for (int i = 0; i < _kHeaders.length; i++) i: 72.0,
          };
          // The name column may shrink (with ellipsis + tooltip) down to a
          // prominent floor before the table resorts to horizontal scrolling —
          // the same graceful shrink-to-fit the Positions table uses. The action
          // column stays pinned since its link has a fixed width.
          absMin[_kStrategyCol] = 240.0;
          absMin[_kActionCol] = columnWidths[_kActionCol]!;

          double totalShrinkable = 0;
          final shrinkable = <int, double>{};
          for (int i = 0; i < _kHeaders.length; i++) {
            final double s = columnWidths[i]! - absMin[i]!;
            shrinkable[i] = s > 0 ? s : 0;
            totalShrinkable += shrinkable[i]!;
          }
          if (totalShrinkable > 0) {
            final double factor =
                excess < totalShrinkable ? excess / totalShrinkable : 1.0;
            for (int i = 0; i < _kHeaders.length; i++) {
              if (shrinkable[i]! > 0) {
                columnWidths[i] = columnWidths[i]! - shrinkable[i]! * factor;
              }
            }
          }
        }

        final double totalRequired =
            columnWidths.values.fold(0.0, (a, b) => a + b);
        final bool needsHScroll = totalRequired > available + 0.5;
        final double tableWidth = needsHScroll ? totalRequired : available;

        final content = Column(
          children: [
            _buildHeaderRow(context, columnWidths),
            Expanded(
              child: RawScrollbar(
                controller: _verticalScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                trackColor: scrollTrack,
                thumbColor: scrollThumb,
                thickness: 6,
                radius: const Radius.circular(3),
                interactive: true,
                child: ListView.builder(
                  controller: _verticalScrollController,
                  padding: EdgeInsets.zero,
                  itemCount: sorted.length,
                  itemBuilder: (context, i) => _StrategyDataRow(
                    strategy: sorted[i],
                    columnWidths: columnWidths,
                  ),
                ),
              ),
            ),
          ],
        );

        return RawScrollbar(
          controller: needsHScroll ? _horizontalScrollController : null,
          thumbVisibility: needsHScroll,
          trackVisibility: needsHScroll,
          trackColor: scrollTrack,
          thumbColor: scrollThumb,
          thickness: needsHScroll ? 6 : 0,
          radius: const Radius.circular(3),
          interactive: needsHScroll,
          child: SingleChildScrollView(
            controller: needsHScroll ? _horizontalScrollController : null,
            scrollDirection: Axis.horizontal,
            physics: needsHScroll
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: SizedBox(width: tableWidth, child: content),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow(
    BuildContext context,
    Map<int, double> columnWidths,
  ) {
    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.cardDark, light: MyntColors.listItemBg),
      child: shadcn.Table(
        columnWidths:
            columnWidths.map((i, w) => MapEntry(i, shadcn.FixedTableSize(w))),
        defaultRowHeight: const shadcn.FixedTableSize(_kHeaderHeight),
        rows: [
          shadcn.TableHeader(
            cells: [
              for (int c = 0; c < _kHeaders.length; c++)
                _headerCell(context, c),
            ],
          ),
        ],
      ),
    );
  }

  shadcn.TableCell _headerCell(BuildContext context, int col) {
    final String header = _kHeaders[col];
    final bool alignRight = _alignRight(header);
    final bool sortable = _isSortable(header);
    final bool sortedHere = _sortColumnIndex == col;

    final Color muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final TextStyle style = MyntWebTextStyles.tableHeader(
      context,
      color: muted,
      fontWeight: MyntFonts.semiBold,
    );

    final sortIcon = Icon(
      _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
      size: 14,
      color: muted,
    );

    Widget label = Container(
      padding: _cellPadding(col),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignRight && sortedHere) ...[sortIcon, const SizedBox(width: 4)],
          Flexible(
            child: Text(header,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          ),
          if (!alignRight && sortedHere) ...[
            const SizedBox(width: 4),
            sortIcon
          ],
        ],
      ),
    );

    if (sortable) {
      label = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _onSort(col),
          behavior: HitTestBehavior.opaque,
          child: label,
        ),
      );
    }

    return shadcn.TableCell(theme: _kBorderlessCell, child: label);
  }
}

/// One strategy row — a borderless [shadcn.Table] wrapped in a [Container] that
/// draws the bottom divider and the hover highlight. The row itself is not a
/// tap target; only the trailing "Backtest" link navigates.
class _StrategyDataRow extends ConsumerStatefulWidget {
  const _StrategyDataRow({
    required this.strategy,
    required this.columnWidths,
  });

  final RupeeCaseStrategy strategy;
  final Map<int, double> columnWidths;

  @override
  ConsumerState<_StrategyDataRow> createState() => _StrategyDataRowState();
}

class _StrategyDataRowState extends ConsumerState<_StrategyDataRow> {
  bool _hovered = false;
  bool _openingBacktest = false;

  Future<void> _openBacktest() async {
    if (_openingBacktest) return;

    setState(() => _openingBacktest = true);
    try {
      final funds = ref.read(fundProvider);
      await funds.fetchHstoken(context);
      if (!mounted) return;
      await funds.openSsoInNewTab('rupeecase');
    } finally {
      if (mounted) setState(() => _openingBacktest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color hoverBg = resolveThemeColor(context,
        dark: MyntColors.primaryDark.withValues(alpha: 0.08),
        light: MyntColors.primary.withValues(alpha: 0.06));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? hoverBg : Colors.transparent,
        child: shadcn.Table(
          columnWidths: widget.columnWidths
              .map((i, w) => MapEntry(i, shadcn.FixedTableSize(w))),
          defaultRowHeight: const shadcn.FixedTableSize(_kRowHeight),
          rows: [
            shadcn.TableRow(
              cells: [
                for (int c = 0; c < _kHeaders.length; c++)
                  shadcn.TableCell(
                    theme: _kBorderlessCell,
                    child: Container(
                      padding: _cellPadding(c),
                      alignment: _alignRight(_kHeaders[c])
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: _cellContent(
                        context,
                        _kHeaders[c],
                        widget.strategy,
                        onBacktest: _openBacktest,
                        openingBacktest: _openingBacktest,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _cellText(String header, RupeeCaseStrategy s) {
  switch (header) {
    case 'Strategy':
      return s.name;
    case 'Benchmark':
      return s.benchmark.isEmpty ? '—' : s.benchmark;
    case 'Risk':
      return s.riskLevel.isEmpty ? '—' : s.riskLevel;
    case 'Stocks':
      return '${s.totalStocks}';
    case 'Rebalance':
      return s.rebalanceWeeks > 0 ? '${s.rebalanceWeeks}W' : '—';
    case 'CAGR':
      return '${s.cagr.toStringAsFixed(2)}%';
    case '5Y Return':
      return '${s.netReturn >= 0 ? '+' : ''}${s.netReturn.toStringAsFixed(2)}%';
    case 'Min Investment':
      return '₹${RupeeFormat.format(s.minInvest, decimalPlaces: 0)}';
    default:
      return 'Backtest';
  }
}

Widget _cellContent(
  BuildContext context,
  String header,
  RupeeCaseStrategy s, {
  required VoidCallback onBacktest,
  required bool openingBacktest,
}) {
  final Color primary = resolveThemeColor(context,
      dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
  final Color muted = resolveThemeColor(context,
      dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

  switch (header) {
    case 'Strategy':
      return _strategyName(context, s, primary, muted);
    case 'Benchmark':
      return Text(
        s.benchmark.isEmpty ? '—' : s.benchmark,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MyntWebTextStyles.tableCell(context, color: muted),
      );
    case 'Risk':
      return Text(
        s.riskLevel.isEmpty ? '—' : s.riskLevel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MyntWebTextStyles.tableCell(context, color: primary),
      );
    case 'Stocks':
      return _numCell(context, '${s.totalStocks}', primary);
    case 'Rebalance':
      return _numCell(
        context,
        s.rebalanceWeeks > 0 ? '${s.rebalanceWeeks}W' : '—',
        primary,
      );
    case 'CAGR':
      return _numCell(context, '${s.cagr.toStringAsFixed(2)}%', primary);
    case '5Y Return':
      final double r = s.netReturn;
      return _numCell(
        context,
        '${r >= 0 ? '+' : ''}${r.toStringAsFixed(2)}%',
        _returnColor(context, r),
      );
    case 'Min Investment':
      return _numCell(
        context,
        '₹${RupeeFormat.format(s.minInvest, decimalPlaces: 0)}',
        primary,
      );
    default:
      return _backtestButton(
        context,
        s,
        onTap: onBacktest,
        isLoading: openingBacktest,
      );
  }
}

/// Strategy name (primary, semibold) with a small superscript `D` marker for
/// dynamic strategies — the same marker the dashboard card uses.
Widget _strategyName(
  BuildContext context,
  RupeeCaseStrategy s,
  Color primary,
  Color muted,
) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Flexible(
        child: Tooltip(
          message: s.name,
          child: Text(
            s.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.tableCell(
              context,
              color: primary,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
        ),
      ),
      if (s.isDynamic)
        Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Transform.translate(
            offset: const Offset(0, -4),
            child: Text(
              'D',
              style: MyntWebTextStyles.caption(
                context,
                color: muted,
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
        ),
    ],
  );
}

/// Trailing "Backtest" link — the only tap target in the row. Opens the
/// strategy's RupeeCase SSO destination; muted dash when there is no link.
Widget _backtestButton(
  BuildContext context,
  RupeeCaseStrategy s, {
  required VoidCallback onTap,
  required bool isLoading,
}) {
  final Color muted = resolveThemeColor(context,
      dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
  final Color accent = resolveThemeColor(context,
      dark: MyntColors.primaryDark, light: MyntColors.primary);

  if (s.marketplaceUrl.trim().isEmpty) {
    return Text('—', style: MyntWebTextStyles.tableCell(context, color: muted));
  }

  return MouseRegion(
    cursor: isLoading ? SystemMouseCursors.progress : SystemMouseCursors.click,
    child: GestureDetector(
      onTap: isLoading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        isLoading ? 'Opening…' : 'Backtest',
        style: MyntWebTextStyles.tableCell(
          context,
          color: accent,
          fontWeight: MyntFonts.semiBold,
        ),
      ),
    ),
  );
}

/// Numeric / right-aligned cell text: the standard table-cell style with
/// tabular figures so digits line up vertically down a column.
TextStyle _num(BuildContext context, Color color) =>
    MyntWebTextStyles.tableCell(context, color: color).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Numeric cell rendered as a single-line, ellipsised [Text] so a narrow column
/// truncates the value instead of wrapping it onto a second line (which would
/// overflow the fixed row height).
Widget _numCell(BuildContext context, String text, Color color) => Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: _num(context, color),
    );

Color _returnColor(BuildContext context, double value) {
  if (value == 0) {
    return resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
  }
  return value < 0
      ? resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss)
      : resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
}

double _measureTextWidth(String text, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );
  tp.layout();
  return tp.width;
}
