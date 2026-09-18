import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart'
    show
        InkWell,
        Icons,
        IconData,
        Icon,
        BoxDecoration,
        BorderRadius,
        BlendMode,
        ColorFilter,
        TextPainter,
        TextSpan,
        WidgetSpan,
        PlaceholderAlignment,
        TextStyle,
        TextDirection,
        GestureDetector,
        HitTestBehavior,
        Row,
        MainAxisSize,
        SizedBox,
        Colors,
        Widget,
        BuildContext,
        Color,
        EdgeInsets,
        Alignment,
        MainAxisAlignment,
        CrossAxisAlignment,
        TextAlign,
        TextOverflow,
        Axis,
        Container,
        MouseRegion,
        Expanded,
        Align,
        Text,
        ScrollController,
        SingleChildScrollView,
        Column,
        LayoutBuilder,
        ValueKey,
        Padding,
        Tooltip,
        RichText,
        ValueNotifier,
        ValueListenableBuilder,
        MediaQuery,
        Builder,
        BoxShadow,
        Offset,
        RawScrollbar,
        Radius,
        ListView;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;

import '../../../provider/portfolio_provider.dart';
import '../../../provider/privacy_provider.dart';
import '../../../res/res.dart';
// websocket_provider import removed — holdings now uses provider-only path (no stream subscriptions)
import '../../../utils/rupee_convert_format.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/snack_bar.dart';
import '../../../sharedWidget/no_data_found.dart';
import '../../../utils/responsive_navigation.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../models/order_book_model/order_book_model.dart';
import 'holding_detail_screen_web.dart';

// Table Example 1 with real Holdings data and WebSocket LTP updates
// This demonstrates the simplest Shadcn table implementation with live data

class TableExample1 extends ConsumerStatefulWidget {
  final String? searchQuery;
  final String filterType; // 'All', 'Stocks', 'Bonds'
  // When true, render the MTF (prd:"F") holdings list instead of the equity
  // (prd:"C") list. Same table UI, different data source.
  final bool isMtf;

  const TableExample1(
      {super.key,
      this.searchQuery,
      this.filterType = 'All',
      this.isMtf = false});

  @override
  ConsumerState<TableExample1> createState() => _TableExample1State();
}

class _TableExample1State extends ConsumerState<TableExample1> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  // PERFORMANCE FIX: Use ValueNotifier for hover instead of setState
  // setState causes full widget rebuild, ValueNotifier only rebuilds hover-dependent parts
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);

  // Track the popover controller to close it when row is unhovered
  shadcn.PopoverController? _activePopoverController;

  // Track which row the popover belongs to
  int? _popoverRowIndex;

  // Track if mouse is hovering over the dropdown menu
  bool _isHoveringDropdown = false;

  // Timer for delayed popover close (allows mouse to move from row to dropdown)
  Timer? _popoverCloseTimer;

  // Scroll controllers - must be in state to persist across rebuilds
  late ScrollController _verticalScrollController;
  late ScrollController _horizontalScrollController;

  @override
  void initState() {
    super.initState();
    _verticalScrollController = ScrollController();
    _horizontalScrollController = ScrollController();

    // Listen to hover changes to close popover when row is unhovered
    _hoveredRowIndex.addListener(_onHoverChanged);
  }

  // Close popover when hover state changes
  void _onHoverChanged() {
    if (_activePopoverController != null) {
      final currentHover = _hoveredRowIndex.value;

      // If still hovering the same row that has the popover, cancel any pending close
      if (currentHover == _popoverRowIndex) {
        _cancelPopoverCloseTimer();
        return;
      }

      // If hovering the dropdown menu, cancel any pending close
      if (_isHoveringDropdown) {
        _cancelPopoverCloseTimer();
        return;
      }

      // Start delayed close - gives time for mouse to move from row to dropdown
      _startPopoverCloseTimer();
    }
  }

  // Start a delayed close timer
  void _startPopoverCloseTimer() {
    _cancelPopoverCloseTimer();
    _popoverCloseTimer = Timer(const Duration(milliseconds: 150), () {
      // Double-check conditions before closing
      if (!_isHoveringDropdown && _hoveredRowIndex.value != _popoverRowIndex) {
        _closePopover();
      }
    });
  }

  // Cancel the close timer
  void _cancelPopoverCloseTimer() {
    _popoverCloseTimer?.cancel();
    _popoverCloseTimer = null;
  }

  // Helper to close popover and reset state
  void _closePopover() {
    _cancelPopoverCloseTimer();
    try {
      _activePopoverController?.close();
    } catch (_) {
      // Overlay might already be closed, ignore
    }
    final needsRebuild =
        _activePopoverController != null || _popoverRowIndex != null;
    _activePopoverController = null;
    _popoverRowIndex = null;
    _isHoveringDropdown = false;

    // Force rebuild to remove row highlight when popover closes
    if (needsRebuild && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _cancelPopoverCloseTimer();
    _hoveredRowIndex.removeListener(_onHoverChanged);
    _hoveredRowIndex.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // Standardized text style helpers
  TextStyle _getTextStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableCell(
      context,
      color: color,
      darkColor: color ?? MyntColors.textPrimaryDark,
      lightColor: color ?? MyntColors.textPrimary,
      fontWeight: MyntFonts.medium,
    ).copyWith(
      fontFeatures: [FontFeature.tabularFigures()],
    );
  }

  TextStyle _getHeaderStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableHeader(
      context,
      color: color,
      darkColor: color ?? MyntColors.textSecondaryDark,
      lightColor: color ?? MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  // Builds a bordered cell; amounts can be right-aligned by passing true.
  shadcn.TableCell buildCell(Widget child, [bool alignRight = false]) {
    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        alignment: alignRight ? Alignment.topRight : null,
        child: child,
      ),
    );
  }

  // Builds a cell with hover detection that covers the entire cell including padding
  // Row tap is handled automatically when holding/exchTsym are provided
  // Inner buttons (Exit, 3-dot menu) take precedence due to Flutter's gesture arena
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    dynamic holding, // Pass holding data for automatic row tap handling
    dynamic exchTsym, // Pass exchTsym data for automatic row tap handling
  }) {
    // Add extra horizontal padding for first and last columns
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 9;

    // For first column (Instrument), use more left padding, minimal right padding
    // For last column, use minimal left padding, more right padding (mirror of first)
    // For other columns, use minimal padding
    EdgeInsets cellPadding;
    if (isFirstColumn) {
      cellPadding =
          const EdgeInsets.fromLTRB(16, 4, 4, 4); // More left, minimal right
    } else if (isLastColumn) {
      cellPadding =
          const EdgeInsets.fromLTRB(4, 4, 16, 4); // Minimal left, more right
    } else {
      cellPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    }

    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) {
          _hoveredRowIndex.value = rowIndex;
          // Cancel any pending close if re-entering the popover's row
          if (_activePopoverController != null && _popoverRowIndex == rowIndex) {
            _cancelPopoverCloseTimer();
          }
        },
        onExit: (_) {
          _hoveredRowIndex.value = null;
          // If popover is open and not hovering dropdown, start close timer
          if (_activePopoverController != null && !_isHoveringDropdown) {
            _startPopoverCloseTimer();
          }
        },
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredRowIndex,
          child: child,
          builder: (context, hoveredIndex, cachedChild) {
            // Row is hovered if mouse is over it OR if its dropdown menu is open
            final isRowHovered = hoveredIndex == rowIndex ||
                (_activePopoverController != null &&
                    _popoverRowIndex == rowIndex);

            final container = Container(
              padding: cellPadding,
              color: isRowHovered
                  ? resolveThemeColor(context,
                      dark: MyntColors.primaryDark.withValues(alpha: 0.08),
                      light: MyntColors.primary.withValues(alpha: 0.08))
                  : null,
              alignment: alignRight ? Alignment.topRight : null,
              child: cachedChild,
            );

            // Automatically wrap with GestureDetector for row tap when holding data is provided
            // Inner buttons (Exit, 3-dot menu) will naturally take precedence in gesture arena
            if (holding != null) {
              return GestureDetector(
                onTap: () {
                  _hoveredRowIndex.value = null;
                  _showHoldingDetail(holding, exchTsym);
                },
                behavior: HitTestBehavior.opaque,
                child: container,
              );
            }
            return container;
          },
        ),
      ),
    );
  }

  // Helper method to get theme-aware colors for positive/negative/neutral values
  Color _getValueColor(double value) {
    if (value > 0) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    }
    if (value < 0) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    }
    return resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
  }

  // Builds a sortable header cell with sort indicator
  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    // Add extra horizontal padding for first and last columns
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 9;

    // Match the cell padding logic - first column has more left, minimal right
    // Last column mirrors this - minimal left, more right
    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding =
          const EdgeInsets.fromLTRB(16, 6, 8, 6); // More left, minimal right
    } else if (isLastColumn) {
      headerPadding =
          const EdgeInsets.fromLTRB(8, 6, 16, 6); // Minimal left, more right
    } else {
      headerPadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 6);
    }

    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: InkWell(
        onTap: () => _onSort(columnIndex),
        child: Container(
          padding: headerPadding,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisAlignment:
                alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (alignRight && _sortColumnIndex == columnIndex)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              if (alignRight && _sortColumnIndex == columnIndex)
                const SizedBox(width: 4),
              Text(
                label,
                style: _getHeaderStyle(context),
              ),
              if (!alignRight && _sortColumnIndex == columnIndex)
                const SizedBox(width: 4),
              if (!alignRight && _sortColumnIndex == columnIndex)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
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

  // Helper method to format instrument display text (remove -EQ and show exchange)
  String _formatInstrumentText(dynamic exchTsym) {
    if (exchTsym == null) return 'N/A';
    final symbol = (exchTsym.tsym ?? '').replaceAll("-EQ", "").trim();
    final exchange = exchTsym.exch ?? '';
    return exchange.isNotEmpty ? '$symbol $exchange' : symbol;
  }

  // Helper method to measure text width dynamically
  double _measureTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();
    return textPainter.width;
  }

  // Calculate minimum column widths dynamically based on header and data
  Map<int, double> _calculateMinWidths(
      List<dynamic> holdings, BuildContext context) {
    // Use default text style for measurement
    final textStyle = const TextStyle(fontSize: 14);
    const padding =
        24.0; // Padding for cell content (8px on each side + some extra)
    const sortIconWidth =
        24.0; // Extra space for sort indicator icon (16px icon + 4px gap + buffer)

    // Header texts
    final headers = [
      'Instrument',
      'Qty',
      'Avg Prc',
      'LTP',
      'Inv',
      'Cur Val',
      'Day P&L',
      'Day Chg',
      'P&L',
      'Net Chg',
    ];

    final minWidths = <int, double>{};

    // Calculate width for each column
    for (int col = 0; col < headers.length; col++) {
      double maxWidth = 0.0;

      // Measure header width and add space for sort icon
      final headerWidth = _measureTextWidth(headers[col], textStyle);
      maxWidth =
          headerWidth + sortIconWidth; // Add extra space for sort indicator

      // Measure widest value in this column
      for (final holding in holdings) {
        final exchTsym =
            holding.exchTsym?.isNotEmpty == true ? holding.exchTsym![0] : null;
        String cellText = '';

        switch (col) {
          case 0: // Instrument
            // Measure symbol + exchange separately (exchange uses smaller font)
            final symbol =
                (exchTsym?.tsym ?? 'N/A').replaceAll("-EQ", "").trim();
            final exchange = exchTsym?.exch ?? '';

            // Measure symbol with normal font
            final symbolWidth = _measureTextWidth(symbol, textStyle);

            // Measure exchange with smaller font (10px, matches rendering)
            final exchangeStyle = const TextStyle(fontSize: 10);
            final exchangeWidth = exchange.isNotEmpty
                ? _measureTextWidth(' $exchange', exchangeStyle)
                : 0.0;

            // Total width = symbol + exchange + space for Exit button + 3-dot menu
            // Exit button (~30px) + gap (6px) + 3-dot menu (~30px) = ~66px
            final totalWidth = symbolWidth + exchangeWidth + 66.0;

            if (totalWidth > maxWidth) {
              maxWidth = totalWidth;
            }
            continue; // Skip normal cellWidth calculation - already handled above
          case 1: // Net Qty
            final qty = holding.currentQty ?? 0;
            cellText = qty > 0 ? '+$qty' : '$qty';
            break;
          case 2: // Avg Price
            final avgPrice = double.tryParse(holding.avgPrc ?? '0') ?? 0.0;
            cellText = avgPrice.toStringAsFixed(2);
            break;
          case 3: // LTP
            final ltpValue = double.tryParse(exchTsym?.lp ?? '0') ?? 0.0;
            cellText = ltpValue.toStringAsFixed(2);
            break;
          case 4: // Invested
            cellText = ((holding.invested ?? '0.00') as String).toIndianFormat();
            break;
          case 5: // Current Value
            cellText = ((holding.currentValue ?? '0.00') as String).toIndianFormat();
            break;
          case 6: // Day P&L
            cellText = ((exchTsym?.oneDayChg ?? '0.00') as String).toIndianFormat();
            break;
          case 7: // Day Chg
            final dayPct = exchTsym?.perChange ?? '0.00';
            cellText = '+$dayPct%';
            break;
          case 8: // P&L (overall profit/loss value)
            cellText = ((exchTsym?.profitNloss ?? '0.00') as String).toIndianFormat();
            break;
          case 9: // Net Chg (overall change %)
            final pct = exchTsym?.pNlChng ?? '0.00';
            cellText = '+$pct%';
        }

        final cellWidth = _measureTextWidth(cellText, textStyle);
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }

      // Ensure minimum width for Instrument column to prevent excessive truncation
      if (col == 0) {
        const minInstrumentWidth = 160.0; // Needs space for Exit + 3-dot menu
        maxWidth =
            maxWidth < minInstrumentWidth ? minInstrumentWidth : maxWidth;
      }

      // Set minimum width (max of header/data + padding)
      minWidths[col] = maxWidth + padding;
    }

    return minWidths;
  }

  @override
  Widget build(BuildContext context) {
    final portfolioData = ref.watch(portfolioProvider);
    // Privacy Mode: position data (qty, avg, invested, current, P&L) is
    // masked; market data (LTP, Day Chg %) stays visible.
    final privacy = ref.watch(privacyProvider);
    final holdings = widget.isMtf
        ? (portfolioData.mtfHoldingsModel ?? [])
        : (portfolioData.holdingsModel ?? []);

    // Filter to show only stock holdings (not mutual funds)
    var stockHoldings = holdings.where((holding) {
      final exchTsym =
          holding.exchTsym?.isNotEmpty == true ? holding.exchTsym![0] : null;
      return exchTsym != null && exchTsym.exch != 'MF';
    }).toList();

    // Apply search filter if search query is provided
    final searchQuery = widget.searchQuery?.toLowerCase().trim() ?? '';
    if (searchQuery.isNotEmpty) {
      stockHoldings = stockHoldings.where((holding) {
        if (holding.exchTsym != null && holding.exchTsym!.isNotEmpty) {
          final exchTsym = holding.exchTsym![0];
          final symbol = exchTsym.tsym?.toLowerCase() ?? '';
          return symbol.contains(searchQuery);
        }
        return false;
      }).toList();
    }

    // Apply type filter (All, Stocks, Bonds)
    if (widget.filterType != 'All') {
      stockHoldings = stockHoldings.where((holding) {
        if (holding.exchTsym != null && holding.exchTsym!.isNotEmpty) {
          final exchTsym = holding.exchTsym![0];
          final exch = exchTsym.exch?.toUpperCase() ?? '';
          final tsym = exchTsym.tsym?.toUpperCase() ?? '';

          // Identify bonds by common patterns in trading symbol
          final isBond = tsym.contains('-GB') ||
              tsym.contains('-GS') ||
              tsym.contains('-N1') ||
              tsym.contains('-N2') ||
              tsym.contains('-N3') ||
              tsym.contains('SGB') ||
              tsym.contains('NCD') ||
              tsym.contains('BOND') ||
              exch == 'GSE'; // Government Securities Exchange

          if (widget.filterType == 'Stocks') {
            // Stocks: NSE, BSE equity instruments (not bonds)
            return (exch == 'NSE' || exch == 'BSE') && !isBond;
          } else if (widget.filterType == 'Bonds') {
            // Bonds: Bond instruments identified by patterns above
            return isBond;
          }
        }
        return false;
      }).toList();
    }

    // Sort holdings based on selected column
    if (_sortColumnIndex != null) {
      stockHoldings.sort((a, b) {
        final exchTsymA =
            a.exchTsym?.isNotEmpty == true ? a.exchTsym![0] : null;
        final exchTsymB =
            b.exchTsym?.isNotEmpty == true ? b.exchTsym![0] : null;

        int comparison = 0;
        switch (_sortColumnIndex) {
          case 0: // Instrument
            comparison = _formatInstrumentText(exchTsymA)
                .compareTo(_formatInstrumentText(exchTsymB));
            break;
          case 1: // Net Qty
            comparison = (a.currentQty ?? 0).compareTo(b.currentQty ?? 0);
            break;
          case 2: // Avg Price
            final avgPriceA = double.tryParse(a.avgPrc ?? '0') ?? 0.0;
            final avgPriceB = double.tryParse(b.avgPrc ?? '0') ?? 0.0;
            comparison = avgPriceA.compareTo(avgPriceB);
            break;
          case 3: // LTP
            final ltpA = double.tryParse(exchTsymA?.lp ?? '0') ?? 0.0;
            final ltpB = double.tryParse(exchTsymB?.lp ?? '0') ?? 0.0;
            comparison = ltpA.compareTo(ltpB);
            break;
          case 4: // Invested
            final investedA = double.tryParse(a.invested ?? '0') ?? 0.0;
            final investedB = double.tryParse(b.invested ?? '0') ?? 0.0;
            comparison = investedA.compareTo(investedB);
            break;
          case 5: // Current Value
            final currentValueA = double.tryParse(a.currentValue ?? '0') ?? 0.0;
            final currentValueB = double.tryParse(b.currentValue ?? '0') ?? 0.0;
            comparison = currentValueA.compareTo(currentValueB);
            break;
          case 6: // Day P&L
            final dayPnlA = double.tryParse(exchTsymA?.oneDayChg ?? '0') ?? 0.0;
            final dayPnlB = double.tryParse(exchTsymB?.oneDayChg ?? '0') ?? 0.0;
            comparison = dayPnlA.compareTo(dayPnlB);
            break;
          case 7: // Day Chg
            final dayPctA = double.tryParse(exchTsymA?.perChange ?? '0') ?? 0.0;
            final dayPctB = double.tryParse(exchTsymB?.perChange ?? '0') ?? 0.0;
            comparison = dayPctA.compareTo(dayPctB);
            break;
          case 8: // P&L
            final pnlA = double.tryParse(exchTsymA?.profitNloss ?? '0') ?? 0.0;
            final pnlB = double.tryParse(exchTsymB?.profitNloss ?? '0') ?? 0.0;
            comparison = pnlA.compareTo(pnlB);
            break;
          case 9: // Net Chg
            final pctA = double.tryParse(exchTsymA?.pNlChng ?? '0') ?? 0.0;
            final pctB = double.tryParse(exchTsymB?.pNlChng ?? '0') ?? 0.0;
            comparison = pctA.compareTo(pctB);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    // Show all holdings
    final displayHoldings = stockHoldings;

    // Show NoDataFound if no results after filtering
    if (displayHoldings.isEmpty) {
      final emptyTitleNoSearch = widget.isMtf ? "No MTF Holdings" : "No Stocks";
      final emptyTitleSearch =
          widget.isMtf ? "No MTF Holdings Found" : "No Stocks Found";
      final emptySubtitleNoSearch = widget.isMtf
          ? "You don't have any MTF holdings yet."
          : "You don't have any stock holdings yet.";
      final emptySubtitleSearch = widget.isMtf
          ? "No MTF holdings match your search \"$searchQuery\"."
          : "No stocks match your search \"$searchQuery\".";
      return shadcn.OutlinedContainer(
        child: NoDataFoundWeb(
          title: searchQuery.isNotEmpty ? emptyTitleSearch : emptyTitleNoSearch,
          subtitle:
              searchQuery.isNotEmpty ? emptySubtitleSearch : emptySubtitleNoSearch,
          primaryEnabled: false,
          secondaryEnabled: false,
        ),
      );
    }

    return shadcn.OutlinedContainer(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate minimum widths dynamically based on actual content
          final minWidths = _calculateMinWidths(displayHoldings, context);

          // Available width
          final availableWidth = constraints.maxWidth;

          // Step 1: Start with minimum widths (content-based, no wasted space)
          final columnWidths = <int, double>{};
          for (int i = 0; i < 10; i++) {
            columnWidths[i] = minWidths[i] ?? 100.0;
          }

          // Step 2: Calculate total minimum width needed
          final totalMinWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);

          // Step 3: Handle width adjustment based on available space
          if (totalMinWidth < availableWidth) {
            // Extra space available - distribute equally across all columns
            // Equal distribution ensures uniform gaps between columns
            final extraSpace = availableWidth - totalMinWidth;
            final extraPerColumn = extraSpace / 10;

            for (int i = 0; i < 10; i++) {
              columnWidths[i] = columnWidths[i]! + extraPerColumn;
            }
          } else if (totalMinWidth > availableWidth) {
            // Not enough space - shrink columns proportionally to eliminate scroll
            final excessWidth = totalMinWidth - availableWidth;

            // Define absolute minimum widths (cannot shrink below these)
            final absoluteMinWidths = <int, double>{
              0: 160.0, // Instrument (needs space for Exit + 3-dot menu)
              1: 50.0,  // Net Qty
              2: 65.0,  // Avg Price
              3: 80.0,  // LTP
              4: 70.0,  // Invested
              5: 80.0,  // Current Value
              6: 70.0,  // Day P&L
              7: 50.0,  // Day Chg
              8: 70.0,  // P&L
              9: 50.0,  // Net Chg
            };

            // Calculate how much each column can shrink
            final shrinkableAmounts = <int, double>{};
            double totalShrinkable = 0.0;

            for (int i = 0; i < 10; i++) {
              final currentWidth = columnWidths[i]!;
              final absoluteMin = absoluteMinWidths[i] ?? 50.0;
              final shrinkable = currentWidth - absoluteMin;
              if (shrinkable > 0) {
                shrinkableAmounts[i] = shrinkable;
                totalShrinkable += shrinkable;
              } else {
                shrinkableAmounts[i] = 0.0;
              }
            }

            // Shrink proportionally if we have enough shrinkable space
            if (totalShrinkable > 0) {
              // Calculate shrink factor (cap at 1.0 if excess > shrinkable)
              final shrinkFactor = excessWidth < totalShrinkable
                  ? excessWidth / totalShrinkable
                  : 1.0;

              for (int i = 0; i < 10; i++) {
                if (shrinkableAmounts[i]! > 0) {
                  final shrinkAmount = shrinkableAmounts[i]! * shrinkFactor;
                  columnWidths[i] = columnWidths[i]! - shrinkAmount;
                }
              }
            }
          }

          // Calculate total required width after adjustment
          final totalRequiredWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);

          // Only enable horizontal scroll if columns are at absolute minimum and still don't fit
          final needsHorizontalScroll = totalRequiredWidth > availableWidth;

          // Build table content
          Widget buildTableContent() {
            return Column(
              children: [
                // Fixed Header (synced with horizontal scroll)
                shadcn.Table(
                  columnWidths: {
                    0: shadcn.FixedTableSize(columnWidths[0]!),
                    1: shadcn.FixedTableSize(columnWidths[1]!),
                    2: shadcn.FixedTableSize(columnWidths[2]!),
                    3: shadcn.FixedTableSize(columnWidths[3]!),
                    4: shadcn.FixedTableSize(columnWidths[4]!),
                    5: shadcn.FixedTableSize(columnWidths[5]!),
                    6: shadcn.FixedTableSize(columnWidths[6]!),
                    7: shadcn.FixedTableSize(columnWidths[7]!),
                    8: shadcn.FixedTableSize(columnWidths[8]!),
                    9: shadcn.FixedTableSize(columnWidths[9]!),
                  },
                  defaultRowHeight: const shadcn.FixedTableSize(40),
                  rows: [
                    shadcn.TableHeader(
                      cells: [
                        buildHeaderCell('Instrument', 0),
                        buildHeaderCell('Qty', 1, true),
                        buildHeaderCell('Avg Prc', 2, true),
                        buildHeaderCell('LTP', 3, true),
                        buildHeaderCell('Inv', 4, true),
                        buildHeaderCell('Cur Val', 5, true),
                        buildHeaderCell('Day P&L', 6, true),
                        buildHeaderCell('Day Chg', 7, true),
                        buildHeaderCell('P&L', 8, true),
                        buildHeaderCell('Net Chg', 9, true),
                      ],
                    ),
                  ],
                ),
                // Scrollable Body (vertical scroll)
                Expanded(
                  child: RawScrollbar(
                    controller: _verticalScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    trackColor: resolveThemeColor(context,
                        dark: Colors.grey.withOpacity(0.1),
                        light: Colors.grey.withOpacity(0.1)),
                    thumbColor: resolveThemeColor(context,
                        dark: Colors.grey.withOpacity(0.3),
                        light: Colors.grey.withOpacity(0.3)),
                    thickness: 6,
                    radius: const Radius.circular(3),
                    interactive: true,
                    child: ListView.builder(
                      controller: _verticalScrollController,
                      itemCount: displayHoldings.length,
                      itemExtent: 42.0,
                      itemBuilder: (context, index) {
                        final holding = displayHoldings[index];
                        final exchTsym =
                            holding.exchTsym?.isNotEmpty == true
                                ? holding.exchTsym![0]
                                : null;
                        final token = exchTsym?.token ?? '';
                        final qty = holding.currentQty ?? 0;

                        return shadcn.Table(
                          key: ValueKey(
                              'row_${token}_${_sortColumnIndex}_$_sortAscending'),
                          columnWidths: {
                            0: shadcn.FixedTableSize(columnWidths[0]!),
                            1: shadcn.FixedTableSize(columnWidths[1]!),
                            2: shadcn.FixedTableSize(columnWidths[2]!),
                            3: shadcn.FixedTableSize(columnWidths[3]!),
                            4: shadcn.FixedTableSize(columnWidths[4]!),
                            5: shadcn.FixedTableSize(columnWidths[5]!),
                            6: shadcn.FixedTableSize(columnWidths[6]!),
                            7: shadcn.FixedTableSize(columnWidths[7]!),
                            8: shadcn.FixedTableSize(columnWidths[8]!),
                            9: shadcn.FixedTableSize(columnWidths[9]!),
                          },
                          defaultRowHeight: const shadcn.FixedTableSize(40),
                          rows: [
                            shadcn.TableRow(
                              cells: [
                                // Instrument with action buttons on hover
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 0,
                                  holding: holding,
                                  exchTsym: exchTsym,
                                  child: shadcn.ValueListenableBuilder(
                                      valueListenable: _hoveredRowIndex,
                                      builder: (context, hoveredIndex, _) {
                                        final isRowHovered =
                                            hoveredIndex == index;
                                        // No GestureDetector here - tap is handled by buildCellWithHover's onTap
                                        return SizedBox(
                                          width: double.infinity,
                                          height: double.infinity,
                                          // Row layout: text shrinks with ellipsis when buttons appear (no overlay)
                                          child: Row(
                                              children: [
                                                // Instrument name - Expanded so it shrinks when buttons appear
                                                Expanded(
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Builder(
                                                      builder: (ctx) {
                                                        // Get pledged qty to include in tooltip and RichText
                                                        final pledgedQty =
                                                            int.tryParse(holding
                                                                        .brkcolqty ??
                                                                    '0') ??
                                                                0;
                                                        final symbolText =
                                                            (exchTsym?.tsym ??
                                                                    'N/A')
                                                                .replaceAll(
                                                                    "-EQ", "")
                                                                .trim();
                                                        final exchangeText =
                                                            (exchTsym?.exch !=
                                                                        null &&
                                                                    exchTsym!
                                                                        .exch!
                                                                        .isNotEmpty)
                                                                ? ' ${exchTsym.exch}'
                                                                : '';

                                                        // Build tooltip message with pledged info
                                                        String tooltipMsg =
                                                            '$symbolText$exchangeText';
                                                        if (pledgedQty > 0) {
                                                          tooltipMsg +=
                                                              privacy.mask(
                                                                  '$pledgedQty',
                                                                  prefix:
                                                                      ' (Pledged: ',
                                                                  suffix: ')');
                                                        }

                                                        return Tooltip(
                                                          message: tooltipMsg,
                                                          child: RichText(
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            maxLines: 1,
                                                            softWrap: false,
                                                            text: TextSpan(
                                                              children: [
                                                                // Symbol (normal color, without -EQ)
                                                                TextSpan(
                                                                  text:
                                                                      symbolText,
                                                                  style:
                                                                      _getTextStyle(
                                                                          ctx),
                                                                ),
                                                                // Exchange (smaller font)
                                                                if (exchangeText
                                                                    .isNotEmpty)
                                                                  TextSpan(
                                                                    text:
                                                                        exchangeText,
                                                                    style: MyntWebTextStyles
                                                                        .para(
                                                                      ctx,
                                                                      darkColor:
                                                                          MyntColors
                                                                              .textSecondaryDark,
                                                                      lightColor:
                                                                          MyntColors
                                                                              .textSecondary,
                                                                      fontWeight:
                                                                          MyntFonts
                                                                              .medium,
                                                                    ).copyWith(
                                                                        fontSize:
                                                                            10),
                                                                  ),
                                                                // Lock icon + pledged qty (inside RichText so it truncates together)
                                                                if (pledgedQty >
                                                                    0) ...[
                                                                  // Space before lock icon (SizedBox for precise control)
                                                                  const WidgetSpan(
                                                                    child:
                                                                        SizedBox(
                                                                            width:
                                                                                4),
                                                                  ),
                                                                  WidgetSpan(
                                                                    alignment:
                                                                        PlaceholderAlignment
                                                                            .middle,
                                                                    child: Icon(
                                                                      Icons
                                                                          .lock,
                                                                      size: 14,
                                                                      color: MyntColors
                                                                          .secondary,
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text: privacy
                                                                        .mask(
                                                                            '$pledgedQty',
                                                                            prefix:
                                                                                ' '),
                                                                    style: MyntWebTextStyles
                                                                        .para(
                                                                      ctx,
                                                                      color: MyntColors
                                                                          .secondary,
                                                                      darkColor:
                                                                          MyntColors
                                                                              .secondary,
                                                                      lightColor:
                                                                          MyntColors
                                                                              .secondary,
                                                                      fontWeight:
                                                                          MyntFonts
                                                                              .medium,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                // Exit button + 3-dot options menu - siblings in Row (no overlay)
                                                if (isRowHovered ||
                                                    (_activePopoverController !=
                                                            null &&
                                                        _popoverRowIndex ==
                                                            index)) ...[
                                                  const SizedBox(width: 8),
                                                  // Exit button (only for holdings with qty)
                                                  if (qty > 0)
                                                    _buildExitButton(
                                                        holding, exchTsym),
                                                  if (qty > 0)
                                                    const SizedBox(width: 6),
                                                  _buildOptionsMenuButton(
                                                    holding,
                                                    exchTsym,
                                                    index,
                                                    qty,
                                                  ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }),
                                ),
                                // Net Qty
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 1,
                                  alignRight: true,
                                  holding: holding,
                                  exchTsym: exchTsym,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Show T1 badge for both POA (btstqty) and Non-POA (npoadt1qty) clients
                                        if (int.parse(holding.npoadt1qty ?? "0") > 0 ||
                                            (holding.btstqty != null && holding.btstqty != "0" && int.parse(holding.btstqty ?? "0") > 0)) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: resolveThemeColor(context,
                                                  dark: MyntColors.primaryDark.withValues(alpha: 0.15),
                                                  light: MyntColors.secondary.withValues(alpha: 0.1)),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              privacy.mask(
                                                  '${math.max(int.parse(holding.npoadt1qty ?? "0"), int.parse(holding.btstqty ?? "0"))}',
                                                  prefix: 'T1: '),
                                              style: MyntWebTextStyles.para(
                                                context,
                                                darkColor: MyntColors.primaryDark,
                                                lightColor: MyntColors.secondary,
                                                fontWeight: MyntFonts.medium,
                                              ).copyWith(fontSize: 10),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          privacy.mask('$qty'),
                                          style: _getTextStyle(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Avg Price
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 2,
                                  alignRight: true,
                                  holding: holding,
                                  exchTsym: exchTsym,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = privacy.mask((double.tryParse(holding.avgPrc ?? '0') ?? 0.0).toStringAsFixed(2));
                                      return Tooltip(
                                        message: value,
                                        child: Text(value, style: _getTextStyle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      );
                                    }),
                                  ),
                                ),
                                // LTP - with WebSocket updates
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 3,
                                  alignRight: true,
                                  holding: holding,
                                  exchTsym: exchTsym,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = exchTsym?.lp ?? '0.00';
                                      return Tooltip(
                                        message: value,
                                        child: Text(value, style: _getTextStyle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      );
                                    }),
                                  ),
                                ),
                                // Invested
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 4,
                                  alignRight: true,
                                  holding: holding,
                                  exchTsym: exchTsym,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = privacy.mask((holding.invested ?? '0.00').toIndianFormat());
                                      return Tooltip(
                                        message: value,
                                        child: Text(value, style: _getTextStyle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      );
                                    }),
                                  ),
                                ),
                                // Current Value - with WebSocket updates
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 5,
                                  alignRight: true,
                                  holding: holding,
                                  exchTsym: exchTsym,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = privacy.mask((holding.currentValue ?? '0.00').toIndianFormat());
                                      return Tooltip(
                                        message: value,
                                        child: Text(value, style: _getTextStyle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      );
                                    }),
                                  ),
                                ),
                                // Day P&L
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 6,
                                  alignRight: true,
                                  holding: holding,
                                  exchTsym: exchTsym,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(
                                      builder: (context) {
                                        final dayPnlValue = exchTsym?.oneDayChg ?? '0.00';
                                        final numValue = double.tryParse(dayPnlValue.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0;
                                        final displayValue = privacy.mask(dayPnlValue.toIndianFormat());
                                        return Tooltip(
                                          message: displayValue,
                                          child: Text(displayValue, style: _getTextStyle(context, color: _getValueColor(privacy.isPrivate ? 0.0 : numValue)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // Day Chg
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 7,
                                  alignRight: true,
                                  holding: holding,
                                  exchTsym: exchTsym,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(
                                      builder: (context) {
                                        final dayPctValue = exchTsym?.perChange ?? '0.00';
                                        final numValue = double.tryParse(dayPctValue) ?? 0.0;
                                        final displayValue = '${numValue >= 0 ? "+" : ""}$dayPctValue%';
                                        return Tooltip(
                                          message: displayValue,
                                          child: Text(displayValue, style: _getTextStyle(context, color: _getValueColor(numValue)).copyWith(fontSize: 12, fontWeight: FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // P&L (overall profit/loss value)
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 8,
                                  alignRight: true,
                                  holding: holding,
                                  exchTsym: exchTsym,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(
                                      builder: (context) {
                                        final pnlValue = exchTsym?.profitNloss ?? '0.00';
                                        final numValue = double.tryParse(pnlValue.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0;
                                        final displayValue = privacy.mask(pnlValue.toIndianFormat());
                                        return Tooltip(
                                          message: displayValue,
                                          child: Text(displayValue, style: _getTextStyle(context, color: _getValueColor(privacy.isPrivate ? 0.0 : numValue)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // Net Chg (overall change %)
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 9,
                                  alignRight: true,
                                  holding: holding,
                                  exchTsym: exchTsym,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(
                                      builder: (context) {
                                        final pctValue = exchTsym?.pNlChng ?? '0.00';
                                        final numValue = double.tryParse(pctValue) ?? 0.0;
                                        // Overall change % derives from the user's avg price, so it
                                        // is masked (sign hidden too), unlike the market Day Chg %.
                                        final displayValue = privacy.isPrivate
                                            ? '$kPrivacyMask%'
                                            : '${numValue >= 0 ? "+" : ""}$pctValue%';
                                        return Tooltip(
                                          message: displayValue,
                                          child: Text(displayValue, style: _getTextStyle(context, color: _getValueColor(privacy.isPrivate ? 0.0 : numValue)).copyWith(fontSize: 12, fontWeight: FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          }

          // Wrap in horizontal scroll if needed
          if (needsHorizontalScroll) {
            return RawScrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              trackColor: resolveThemeColor(context,
                  dark: Colors.grey.withOpacity(0.1),
                  light: Colors.grey.withOpacity(0.1)),
              thumbColor: resolveThemeColor(context,
                  dark: Colors.grey.withOpacity(0.3),
                  light: Colors.grey.withOpacity(0.3)),
              thickness: 6,
              radius: const Radius.circular(3),
              interactive: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalRequiredWidth,
                  child: buildTableContent(),
                ),
              ),
            );
          } else {
            return buildTableContent();
          }
        },
      ),
    );
  }

  Widget _buildPnLColumn(String pnlValue, String percentValue) {
    final numValue =
        double.tryParse(pnlValue.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0;
    final color = _getValueColor(numValue);
    final baseStyle = _getTextStyle(context, color: color);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          pnlValue.toIndianFormat(),
          textAlign: TextAlign.end,
          style: baseStyle,
        ),
        Text(
          '$percentValue%',
          textAlign: TextAlign.end,
          style: baseStyle.copyWith(
            fontSize: 10,
            color: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
            fontWeight: MyntFonts.medium,
          ),
        ),
      ],
    );
  }

  Widget _buildColoredText(String value) {
    // Check if the value contains a percentage in brackets
    if (value.contains('(') && value.contains(')')) {
      final parts = value.split('(');
      final mainValue = parts[0];
      final percentPart = '(${parts[1]}';

      final numValue =
          double.tryParse(mainValue.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0;
      final color = _getValueColor(numValue);
      final baseStyle = _getTextStyle(context, color: color);

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(text: mainValue, style: baseStyle),
            TextSpan(
              text: percentPart,
              style: baseStyle.copyWith(
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    final numValue = double.tryParse(value.replaceAll('%', '')) ?? 0.0;
    final color = _getValueColor(numValue);

    return Text(
      value,
      style: _getTextStyle(context, color: color),
    );
  }

  // Handler: Add holding (Buy more)
  Future<void> _handleAddHolding(dynamic holding, dynamic exchTsym) async {
    try {
      final scripData = ref.read(marketWatchProvider);
      await scripData.fetchScripInfo(
        exchTsym.token ?? "",
        exchTsym.exch ?? "",
        context,
        true,
      );

      if (scripData.scripInfoModel == null) {
        showResponsiveWarningMessage(
            context, "Unable to fetch scrip information");
        return;
      }

      final lotSize = scripData.scripInfoModel!.ls?.toString() ?? "1";

      OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: exchTsym.exch ?? "",
        tSym: exchTsym.tsym ?? "",
        isExit: false,
        token: exchTsym.token ?? "",
        transType: true,
        prd: holding.prd ?? "",
        lotSize: lotSize,
        ltp: exchTsym.lp ?? "0.00",
        perChange: exchTsym.perChange ?? "0.00",
        orderTpye: holding.sPrdtAli ?? '',
        holdQty: holding.currentQty?.toString() ?? '',
        isModify: false,
        raw: {},
      );

      ResponsiveNavigation.toPlaceOrderScreen(
        context: context,
        arguments: {
          "orderArg": orderArgs,
          "scripInfo": scripData.scripInfoModel!,
          "isBskt": "",
        },
      );
    } catch (e) {
      showResponsiveWarningMessage(
          context, "Error adding holding: ${e.toString()}");
    }
  }

  // Handler: Exit holding (Sell)
  Future<void> _handleExitHolding(dynamic holding, dynamic exchTsym) async {
    try {
      if (holding.saleableQty == null || holding.saleableQty == 0) {
        showResponsiveWarningMessage(
          context,
          'You are unable to exit because there are no sellable quantity.',
        );
        return;
      }

      final scripData = ref.read(marketWatchProvider);
      await scripData.fetchScripInfo(
        exchTsym.token ?? "",
        exchTsym.exch ?? "",
        context,
        true,
      );

      if (scripData.scripInfoModel == null) {
        showResponsiveWarningMessage(
            context, "Unable to fetch scrip information");
        return;
      }

      final lotSize = scripData.scripInfoModel!.ls?.toString() ?? "1";

      OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: exchTsym.exch ?? "",
        tSym: exchTsym.tsym ?? "",
        isExit: true,
        token: exchTsym.token ?? "",
        transType: false,
        prd: holding.prd ?? "",
        lotSize: lotSize,
        ltp: exchTsym.lp ?? "0.00",
        perChange: exchTsym.perChange ?? "0.00",
        orderTpye: holding.sPrdtAli ?? '',
        holdQty: holding.currentQty?.toString() ?? '',
        isModify: false,
        raw: {},
      );

      ResponsiveNavigation.toPlaceOrderScreen(
        context: context,
        arguments: {
          "orderArg": orderArgs,
          "scripInfo": scripData.scripInfoModel!,
          "isBskt": "",
        },
      );
    } catch (e) {
      showResponsiveWarningMessage(
          context, "Error exiting holding: ${e.toString()}");
    }
  }

  // Handler: Show holding detail sheet
  void _showHoldingDetail(dynamic holding, dynamic exchTsym) {
    if (exchTsym == null) return;

    // Save parent context to pass to sheet
    final parentCtx = context;

    shadcn.openSheet(
      context: context,
      barrierColor: Colors.transparent,
      builder: (sheetContext) {
        final screenWidth = MediaQuery.of(sheetContext).size.width;
        final sheetWidth = screenWidth < 1300 ? screenWidth * 0.3 : 480.0;
        return Container(
          width: sheetWidth,
          decoration: BoxDecoration(
            color: resolveThemeColor(
              context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: HoldingDetailScreenWeb(
            holding: holding,
            exchTsym: exchTsym,
            parentContext: parentCtx, // Pass parent context for navigation
          ),
        );
      },
      position: shadcn.OverlayPosition.end,
    );
  }

  // Handler: Chart tap (Show market depth)
  Future<void> _handleChartTap(dynamic holding, dynamic exchTsym) async {
    final scripData = ref.read(marketWatchProvider);
    await scripData.fetchScripQuoteIndex(
      exchTsym.token ?? "",
      exchTsym.exch ?? "",
      context,
    );

    final quots = scripData.getQuotes;
    if (quots != null) {
      DepthInputArgs depthArgs = DepthInputArgs(
        exch: quots.exch?.toString() ?? "",
        token: quots.token?.toString() ?? "",
        tsym: quots.tsym?.toString() ?? "",
        instname: quots.instname?.toString() ?? "",
        symbol: quots.symbol?.toString() ?? "",
        expDate: quots.expDate?.toString() ?? "",
        option: quots.option?.toString() ?? "",
      );
      scripData.scripdepthsize(false);
      await scripData.calldepthApis(context, depthArgs, "");
    }
  }

  // Build styled menu button matching profile dropdown
  shadcn.MenuButton _buildMenuButton({
    IconData? icon,
    Widget? iconWidget,
    required String title,
    required void Function(BuildContext) onPressed,
    required Color iconColor,
    required Color textColor,
  }) {
    return shadcn.MenuButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (iconWidget != null)
              iconWidget
            else if (icon != null)
              Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Text(
              title,
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.medium,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build Exit button (output icon with red/tertiary color) with tooltip
  Widget _buildExitButton(dynamic holding, dynamic exchTsym) {
    return Tooltip(
      message: 'Exit',
      child: GestureDetector(
        onTap: () {
          // Clear hover state before navigating to prevent stuck hover
          _hoveredRowIndex.value = null;
          _handleExitHolding(holding, exchTsym);
        },
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.textWhite,
                light: MyntColors.textWhite),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: resolveThemeColor(context,
                    dark: Colors.transparent,
                    light: Colors.grey),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: SvgPicture.asset(
            assets.exitPositionIcon,
            height: 16,
            width: 16,
            colorFilter: ColorFilter.mode(
              resolveThemeColor(context,
                  dark: MyntColors.lossDark,
                  light: MyntColors.tertiary),
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }

  // Build the 3-dot options menu button with shadcn dropdown
  Widget _buildOptionsMenuButton(
    dynamic holding,
    dynamic exchTsym,
    int rowIndex,
    int qty,
  ) {
    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          onTap: () {
            // Close any existing popover first
            _closePopover();

            // Build menu items
            List<shadcn.MenuItem> menuItems = [];
            final iconColor = resolveThemeColor(context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary);
            final textColor = resolveThemeColor(context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary);

            // Add option (only for holdings with qty > 0)
            if (qty > 0) {
              menuItems.add(
                _buildMenuButton(
                  icon: Icons.add_circle_outline,
                  title: 'Add',
                  iconColor: iconColor,
                  textColor: textColor,
                  onPressed: (ctx) {
                    _closePopover();
                    // Clear hover state before navigating to prevent stuck hover
                    _hoveredRowIndex.value = null;
                    _handleAddHolding(holding, exchTsym);
                  },
                ),
              );
            }

            // Add divider if we have action items
            if (menuItems.isNotEmpty) {
              menuItems.add(const shadcn.MenuDivider());
            }

            // Info option (always available)
            menuItems.add(
              _buildMenuButton(
                icon: Icons.info_outline,
                title: 'Info',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  // Clear hover state before showing detail to prevent stuck hover
                  _hoveredRowIndex.value = null;
                  _showHoldingDetail(holding, exchTsym);
                },
              ),
            );

            // Chart option (always available)
            menuItems.add(
              _buildMenuButton(
                iconWidget: SvgPicture.asset(
                  assets.chartnew,
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
                title: 'Chart',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  // Clear hover state before navigating to prevent stuck hover
                  _hoveredRowIndex.value = null;
                  _handleChartTap(holding, exchTsym);
                },
              ),
            );

            // Create a controller for this popover
            final controller = shadcn.PopoverController();
            _activePopoverController = controller;
            _popoverRowIndex = rowIndex;

            // Show the shadcn popover menu anchored to this button
            controller.show(
              context: buttonContext,
              alignment: Alignment.topRight,
              offset: const Offset(0, 4),
              builder: (ctx) {
                return MouseRegion(
                  onEnter: (_) {
                    _isHoveringDropdown = true;
                    _cancelPopoverCloseTimer();
                  },
                  onExit: (_) {
                    _isHoveringDropdown = false;
                    // Start delayed close
                    _startPopoverCloseTimer();
                  },
                  child: shadcn.DropdownMenu(
                    children: menuItems,
                  ),
                );
              },
            );

            // Force rebuild to show row highlight
            setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  // dark: MyntColors.primary.withValues(alpha: 0.1),
                  // light: MyntColors.primary.withValues(alpha: 0.1)),
                  dark: MyntColors.textWhite,
                  light: MyntColors.textWhite),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: resolveThemeColor(context,
                      dark: Colors.transparent,
                      light: Colors.grey),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.more_vert,
              size: 16,
             color: resolveThemeColor(context,
                  dark: MyntColors.textPrimary,
                  light: MyntColors.textPrimary),
            ),
          ),
        );
      },
    );
  }
}

// Stream-based WebSocket cells removed — holdings now uses provider-only path
// (portfolioProvider.updateHoldingValues → notifyListeners → ref.watch rebuild)
// This eliminates ~600-800 redundant stream callbacks/sec with 50 holdings

