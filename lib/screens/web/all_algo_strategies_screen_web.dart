import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:url_launcher/url_launcher.dart';

import '../../models/rupeecase_model/algo_strategy_model.dart';
import '../../provider/rupeecase_provider.dart';
import '../../res/mynt_web_color_styles.dart';
import '../../res/mynt_web_text_styles.dart';
import '../../sharedWidget/custom_back_btn.dart';
import '../../sharedWidget/mynt_loader.dart';
import '../../utils/rupee_convert_format.dart';

/// Full listing of every algo (automated) strategy basket, laid out as the same
/// sortable table as the curated "See all" page ([AllStrategiesScreenWeb]). Each
/// row opens the Zebu Algo marketplace. Rendered inside the split panel, so it
/// is a plain content widget with its own header. Data comes from
/// [rupeeCaseProvider], already fetched by the dashboard / Strategies section.
class AllAlgoStrategiesScreenWeb extends ConsumerWidget {
  const AllAlgoStrategiesScreenWeb({super.key, this.onBack});

  /// Invoked when the header back button is tapped. When null the back button
  /// is hidden (e.g. if the page is ever shown as a standalone route).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(rupeeCaseProvider);
    final strategies = provider.algoStrategies;

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
                'Zebu Algo Strategies',
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
                    child: provider.algoLoading
                        ? MyntLoader.simple(size: MyntLoaderSize.small)
                        : Text(
                            'No strategies available',
                            style:
                                MyntWebTextStyles.para(context, color: muted),
                          ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _AlgoStrategyTable(strategies: strategies),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Every row opens this Zebu Algo marketplace link — matching the algo strategy
/// cards on the dashboard.
const String _kAlgoMarketplaceUrl = 'https://algo.zebuetrade.com/marketplace';

const List<String> _kHeaders = [
  'Strategy',
  'Min Cap',
  'Total Return',
  'CAGR',
  'Drawdown',
  'Win Rate',
  'Strategies',
  'Subscribers',
  'Category',
  'Risk',
  '',
];

const int _kStrategyCol = 0;
const int _kCapitalCol = 1;
const int _kTotalReturnCol = 2;
const int _kCagrCol = 3;
const int _kDrawdownCol = 4;
const int _kWinRateCol = 5;
const int _kStrategiesCountCol = 6;
const int _kSubscribersCol = 7;
const int _kActionCol = 10;

/// Value columns whose full text must always stay visible — never squeezed to an
/// ellipsis on narrow screens. The table scrolls horizontally instead of hiding
/// these figures behind three dots.
const List<int> _kNoShrinkValueCols = [
  _kStrategiesCountCol,
  _kWinRateCol,
  _kCagrCol,
  _kTotalReturnCol,
  _kDrawdownCol,
  _kCapitalCol,
];

const double _kHeaderHeight = 44;
const double _kRowHeight = 52;

bool _isNumeric(String h) =>
    h == 'Strategies' ||
    h == 'Win Rate' ||
    h == 'CAGR' ||
    h == 'Total Return' ||
    h == 'Subscribers' ||
    h == 'Drawdown' ||
    h == 'Min Cap';

bool _isSortable(String h) => h.isNotEmpty;

/// Right-aligned columns: every numeric column plus the trailing action column.
bool _alignRight(String h) => _isNumeric(h) || h.isEmpty;

/// Cell padding — extra breathing room on the outer edges (first / last column)
/// so the content doesn't hug the container border, matching the RupeeCase table.
EdgeInsets _cellPadding(int col) {
  if (col == _kStrategyCol) return const EdgeInsets.fromLTRB(16, 0, 10, 0);
  if (col == _kActionCol) return const EdgeInsets.fromLTRB(10, 0, 16, 0);
  return const EdgeInsets.symmetric(horizontal: 10);
}

/// Borderless cell theme — the row/header dividers are drawn by the wrapping
/// [Container], not per-cell (same approach as the RupeeCase table).
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

class _AlgoStrategyTable extends StatefulWidget {
  const _AlgoStrategyTable({required this.strategies});

  final List<AlgoStrategy> strategies;

  @override
  State<_AlgoStrategyTable> createState() => _AlgoStrategyTableState();
}

class _AlgoStrategyTableState extends State<_AlgoStrategyTable> {
  // Default the table to Subscribers, highest first.
  int? _sortColumnIndex = _kSubscribersCol;
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

  List<AlgoStrategy> _sorted() {
    final list = widget.strategies.toList();
    final col = _sortColumnIndex;
    if (col == null) return list;
    final header = _kHeaders[col];

    int cmp(AlgoStrategy a, AlgoStrategy b) {
      switch (header) {
        case 'Strategy':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'Category':
          return a.category.toLowerCase().compareTo(b.category.toLowerCase());
        case 'Strategies':
          return a.strategiesCount.compareTo(b.strategiesCount);
        case 'Risk':
          return a.riskLevel.toLowerCase().compareTo(b.riskLevel.toLowerCase());
        case 'Win Rate':
          return a.winRate.compareTo(b.winRate);
        case 'CAGR':
          return a.cagr.compareTo(b.cagr);
        case 'Total Return':
          return a.totalReturn.compareTo(b.totalReturn);
        case 'Subscribers':
          return a.subscriberCount.compareTo(b.subscriberCount);
        case 'Drawdown':
          return a.maxDrawdownPct.compareTo(b.maxDrawdownPct);
        case 'Min Cap':
          return a.capitalRequired.compareTo(b.capitalRequired);
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
        // Action column sized to the "Open" link.
        widths[col] = _measureTextWidth('Open', nameStyle) + padding + 20;
        continue;
      }

      double maxWidth = _measureTextWidth(header, headerStyle) +
          (_isSortable(header) ? sortIcon : 0);
      final TextStyle valueStyle = col == _kStrategyCol ? nameStyle : cellStyle;

      for (final s in widget.strategies) {
        final double w = _measureTextWidth(_cellText(header, s), valueStyle);
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
          // Capital, Total Return and Win Rate keep their full measured width so
          // their values are shown in full (no ellipsis) even on narrow screens —
          // the table scrolls horizontally rather than truncating these figures.
          for (final col in _kNoShrinkValueCols) {
            absMin[col] = columnWidths[col]!;
          }

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
                  itemBuilder: (context, i) => _AlgoStrategyDataRow(
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

/// One algo-strategy row — a borderless [shadcn.Table] wrapped in a [Container]
/// that draws the hover highlight. The row itself is not a tap target; only the
/// trailing "Open" link navigates to the Zebu Algo marketplace.
class _AlgoStrategyDataRow extends StatefulWidget {
  const _AlgoStrategyDataRow({
    required this.strategy,
    required this.columnWidths,
  });

  final AlgoStrategy strategy;
  final Map<int, double> columnWidths;

  @override
  State<_AlgoStrategyDataRow> createState() => _AlgoStrategyDataRowState();
}

class _AlgoStrategyDataRowState extends State<_AlgoStrategyDataRow> {
  bool _hovered = false;

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

String _cellText(String header, AlgoStrategy s) {
  switch (header) {
    case 'Strategy':
      return s.title;
    case 'Category':
      return s.category.isEmpty ? '—' : s.category;
    case 'Strategies':
      return '${s.strategiesCount}';
    case 'Risk':
      return s.riskLevel.isEmpty ? '—' : s.riskLevel;
    case 'Win Rate':
      return '${s.winRate.toStringAsFixed(2)}%';
    case 'CAGR':
      return '${s.cagr.toStringAsFixed(2)}%';
    case 'Total Return':
      return '${s.totalReturn.toStringAsFixed(2)}%';
    case 'Subscribers':
      return '${s.subscriberCount}';
    case 'Drawdown':
      return s.maxDrawdownPct > 0
          ? '${s.maxDrawdownPct.toStringAsFixed(2)}%'
          : '—';
    case 'Min Cap':
      return '₹${RupeeFormat.format(s.capitalRequired, decimalPlaces: 0)}';
    default:
      return 'Open';
  }
}

Widget _cellContent(
  BuildContext context,
  String header,
  AlgoStrategy s,
) {
  final Color primary = resolveThemeColor(context,
      dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

  switch (header) {
    case 'Strategy':
      return Tooltip(
        message: s.title,
        child: Text(
          s.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MyntWebTextStyles.tableCell(
            context,
            color: primary,
            fontWeight: MyntFonts.semiBold,
          ),
        ),
      );
    case 'Category':
      return Text(
        s.category.isEmpty ? '—' : s.category,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MyntWebTextStyles.tableCell(context, color: primary),
      );
    case 'Strategies':
      return _numCell(context, '${s.strategiesCount}', primary);
    case 'Risk':
      return Text(
        s.riskLevel.isEmpty ? '—' : s.riskLevel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MyntWebTextStyles.tableCell(context, color: primary),
      );
    case 'Win Rate':
      // Win rate is always rendered in the profit (green) colour.
      return _numCell(
        context,
        '${s.winRate.toStringAsFixed(2)}%',
        resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit),
      );
    case 'CAGR':
      return _numCell(context, '${s.cagr.toStringAsFixed(2)}%', primary);
    case 'Total Return':
      // Total return is shown in the profit (green) colour, matching Win Rate.
      return _numCell(
        context,
        '${s.totalReturn.toStringAsFixed(2)}%',
        resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit),
      );
    case 'Subscribers':
      return _numCell(context, '${s.subscriberCount}', primary);
    case 'Drawdown':
      final double dd = s.maxDrawdownPct;
      return _numCell(
        context,
        dd > 0 ? '${dd.toStringAsFixed(2)}%' : '—',
        dd > 0
            ? resolveThemeColor(context,
                dark: MyntColors.lossDark, light: MyntColors.loss)
            : primary,
      );
    case 'Min Cap':
      return _numCell(
        context,
        '₹${RupeeFormat.format(s.capitalRequired, decimalPlaces: 0)}',
        primary,
      );
    default:
      return _openLink(context);
  }
}

/// Trailing "Open" link — the only tap target in the row. Opens the Zebu Algo
/// marketplace. Always accent-coloured (blue), matching the RupeeCase table's
/// "Backtest" link.
Widget _openLink(BuildContext context) {
  final Color accent = resolveThemeColor(context,
      dark: MyntColors.primaryDark, light: MyntColors.primary);
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () => _launchUrl(_kAlgoMarketplaceUrl),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Open',
            style: MyntWebTextStyles.tableCell(
              context,
              color: accent,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.open_in_new,
            size: 14,
            color: accent,
          ),
        ],
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

double _measureTextWidth(String text, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );
  tp.layout();
  return tp.width;
}

/// Opens a URL in a new tab/app; failures are swallowed so a bad link never
/// crashes the page.
Future<void> _launchUrl(String url) async {
  final String u = url.trim();
  if (u.isEmpty) return;
  final Uri uri = Uri.parse(u);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (_) {
    // Ignore — a failed launch should never surface an error.
  }
}
