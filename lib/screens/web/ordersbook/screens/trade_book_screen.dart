import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart'
    hide DataTable, DataColumn, DataRow, DataCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:mynt_plus/models/order_book_model/trade_book_model.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import '../refactored/utils/cell_formatters.dart';
import 'trade_detail_screen_web.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';

/// Separate screen widget for Trade Book tab
class TradeBookScreen extends ConsumerStatefulWidget {
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;

  const TradeBookScreen({
    super.key,
    required this.horizontalScrollController,
    required this.verticalScrollController,
  });

  @override
  ConsumerState<TradeBookScreen> createState() => _TradeBookScreenState();
}

class _TradeBookScreenState extends ConsumerState<TradeBookScreen> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  // PERFORMANCE FIX: Use ValueNotifier for hover instead of setState
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);

  // Track the popover controller to close it when row is unhovered
  shadcn.PopoverController? _activePopoverController;

  // Track which row the popover belongs to
  int? _popoverRowIndex;

  // Track if mouse is hovering over the dropdown menu
  bool _isHoveringDropdown = false;

  // Timer for delayed popover close (allows mouse to move from row to dropdown)
  Timer? _popoverCloseTimer;

  // Prevent double-click from opening sheet twice
  bool _isSheetOpening = false;

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
    final needsRebuild = _activePopoverController != null || _popoverRowIndex != null;
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

  // Helper method to get appropriate text style for table cells
  // 14px, weight 500, MyntColors for text
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

  // Helper method for header text style
  // 14px, weight 600, MyntColors for text
  TextStyle _getHeaderStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableHeader(
      context,
      color: color,
      darkColor: color ?? MyntColors.textSecondaryDark,
      lightColor: color ?? MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  // Format trade qty - for MCX, divide by lot size
  String _formatTradeQty(dynamic trade) {
    final rawFilled = int.tryParse(trade.fillshares?.toString() ?? trade.flqty?.toString() ?? '0') ?? 0;
    final rawQty = int.tryParse(trade.qty?.toString() ?? '0') ?? 0;
    final lotSize = trade.exch == 'MCX'
        ? (int.tryParse(trade.ls?.toString() ?? '1') ?? 1)
        : 1;
    final filledQty = rawFilled ~/ lotSize;
    final totalQty = rawQty ~/ lotSize;
    return '$filledQty / $totalQty';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final orderBook = ref
        .watch(orderProvider); // Changed to watch to rebuild on search changes

    // Get trades (search or regular)
    // Only show search results if we're on the Trade Book tab (index 2)
    final searchQuery = orderBook.orderSearchCtrl.text.trim();
    final isTradeBookTab = orderBook.selectedTab == 2;
    final trades = (searchQuery.isNotEmpty && isTradeBookTab)
        ? (orderBook.tradeBooksearch ?? [])
        : (orderBook.tradeBook ?? []);

    // Sort trades (only if not empty)
    final sortedTrades = trades.isNotEmpty ? _getSortedTrades(trades) : <TradeBookModel>[];

    // NEW TABLE LAYOUT: 8 columns - Trade ID, Fill time, Type, Instrument, Product, Qty., LTP, Avg. Price
    // Always show header, even when no data
    return SizedBox.expand(
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: shadcn.OutlinedContainer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Available width
              final availableWidth = constraints.maxWidth;

              // Proportional widths for columns (total = 100%)
              // Trade ID: 10%, Fill time: 10%, Type: 8%, Instrument: 25%, Product: 12%, Qty: 12%, LTP: 11%, Avg Price: 12%
              final tradeIdWidth = availableWidth * 0.10;
              final fillTimeWidth = availableWidth * 0.10;
              final typeWidth = availableWidth * 0.08;
              final instrumentWidth = availableWidth * 0.25; // 25% for instrument - wider to show full names
              final productWidth = availableWidth * 0.12;
              final qtyWidth = availableWidth * 0.12;
              final ltpWidth = availableWidth * 0.11;
              final avgPriceWidth = availableWidth * 0.12;

              // Build table content
              Widget buildTableContent() {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 0,
                    maxHeight: constraints.maxHeight.isFinite &&
                            constraints.maxHeight > 0
                        ? constraints.maxHeight
                        : double.infinity,
                  ),
                  child: Column(
                    children: [
                      // Fixed Header - 8 columns with proportional widths (always visible)
                      shadcn.Table(
                        columnWidths: {
                          0: shadcn.FixedTableSize(tradeIdWidth),
                          1: shadcn.FixedTableSize(fillTimeWidth),
                          2: shadcn.FixedTableSize(typeWidth),
                          3: shadcn.FixedTableSize(instrumentWidth),
                          4: shadcn.FixedTableSize(productWidth),
                          5: shadcn.FixedTableSize(qtyWidth),
                          6: shadcn.FixedTableSize(ltpWidth),
                          7: shadcn.FixedTableSize(avgPriceWidth),
                        },
                        defaultRowHeight: const shadcn.FixedTableSize(40),
                        rows: [
                          shadcn.TableHeader(
                            cells: [
                              buildHeaderCell('Trade ID', 0),
                              buildHeaderCell('Fill time', 1),
                              buildHeaderCell('Type', 2),
                              buildHeaderCell('Instrument', 3),
                              buildHeaderCell('Product', 4),
                              buildHeaderCell('Qty', 5, true),
                              buildHeaderCell('LTP', 6, true),
                              buildHeaderCell('Avg Prc', 7, true),
                            ],
                          ),
                        ],
                      ),
                      // Scrollable Body (vertical scroll) - shows loader/no data/table rows
                      Expanded(
                        child: sortedTrades.isEmpty
                            ? (orderBook.loading
                                ? Center(child: MyntLoader.simple())
                                : Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: NoDataFoundWeb(
                                        title: searchQuery.isNotEmpty ? "No Trades Found" : "No Trades",
                                        subtitle: searchQuery.isNotEmpty
                                            ? "No trades match your search \"$searchQuery\"."
                                            : "You don't have any trades yet.",
                                        primaryEnabled: false,
                                        secondaryEnabled: false,
                                      ),
                                    ),
                                  ))
                            : RawScrollbar(
                          controller: _verticalScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          trackColor: resolveThemeColor(context,
                              dark: Colors.grey.withValues(alpha: 0.1),
                              light: Colors.grey.withValues(alpha: 0.1)),
                          thumbColor: resolveThemeColor(context,
                              dark: Colors.grey.withValues(alpha: 0.3),
                              light: Colors.grey.withValues(alpha: 0.3)),
                          thickness: 6,
                          radius: const Radius.circular(3),
                          interactive: true,
                          child: ListView.builder(
                            controller: _verticalScrollController,
                            itemCount: sortedTrades.length,
                            itemExtent: 42.0,
                            itemBuilder: (context, index) {
                              final trade = sortedTrades[index];
                              return shadcn.Table(
                                columnWidths: {
                                  0: shadcn.FixedTableSize(tradeIdWidth),
                                  1: shadcn.FixedTableSize(fillTimeWidth),
                                  2: shadcn.FixedTableSize(typeWidth),
                                  3: shadcn.FixedTableSize(instrumentWidth),
                                  4: shadcn.FixedTableSize(productWidth),
                                  5: shadcn.FixedTableSize(qtyWidth),
                                  6: shadcn.FixedTableSize(ltpWidth),
                                  7: shadcn.FixedTableSize(avgPriceWidth),
                                },
                                defaultRowHeight: const shadcn.FixedTableSize(40),
                                rows: [
                                  shadcn.TableRow(
                                    cells: [
                                      // Column 0: Trade ID
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 0,
                                        onTap: () => _showTradeDetail(trade),
                                        child: Text(
                                          trade.flid?.toString() ?? 'N/A',
                                          style: _getTextStyle(context),
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                        ),
                                      ),
                                      // Column 1: Fill time
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 1,
                                        onTap: () => _showTradeDetail(trade),
                                        child: Text(
                                          _formatFillTime(trade.norentm ?? 'N/A'),
                                          style: _getTextStyle(context),
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                        ),
                                      ),
                                      // Column 2: Type (BUY/SELL)
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 2,
                                        onTap: () => _showTradeDetail(trade),
                                        child: Text(
                                          trade.trantype == "S" ? "SELL" : "BUY",
                                          style: _getTextStyle(
                                            context,
                                            color: trade.trantype == "S"
                                                ? resolveThemeColor(context,
                                                    dark: MyntColors.errorDark, light: MyntColors.loss)
                                                : resolveThemeColor(context,
                                                    dark: MyntColors.profitDark, light: MyntColors.profit),
                                          ),
                                        ),
                                      ),
                                      // Column 3: Instrument - with hover menu
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 3,
                                        child: ValueListenableBuilder<int?>(
                                          valueListenable: _hoveredRowIndex,
                                          builder: (context, hoveredIndex, _) {
                                            final isHovered = hoveredIndex == index ||
                                                (_activePopoverController != null && _popoverRowIndex == index);
                                            return _buildInstrumentCell(
                                              trade, theme, isHovered,
                                              rowIndex: index,
                                            );
                                          },
                                        ),
                                      ),
                                      // Column 4: Product
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 4,
                                        onTap: () => _showTradeDetail(trade),
                                        child: Text(
                                          trade.sPrdtAli ?? trade.prd ?? '',
                                          style: _getTextStyle(context),
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                        ),
                                      ),
                                      // Column 5: Qty.
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 5,
                                        alignRight: true,
                                        onTap: () => _showTradeDetail(trade),
                                        child: Builder(builder: (context) {
                                          final value = _formatTradeQty(trade);
                                          return Tooltip(
                                            message: value,
                                            child: Text(value, style: _getTextStyle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          );
                                        }),
                                      ),
                                      // Column 6: LTP
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 6,
                                        alignRight: true,
                                        onTap: () => _showTradeDetail(trade),
                                        child: _TradeLTPCell(
                                          token: trade.token ?? '',
                                          initialLtp: trade.avgprc ?? '0.00',
                                        ),
                                      ),
                                      // Column 7: Avg. Price
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 7,
                                        alignRight: true,
                                        onTap: () => _showTradeDetail(trade),
                                        child: Builder(builder: (context) {
                                          final value = trade.avgprc?.toString() ?? 'N/A';
                                          return Tooltip(
                                            message: value,
                                            child: Text(value, style: _getTextStyle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          );
                                        }),
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
                  ),
                );
              }

              // No horizontal scroll needed with equal width columns
              return buildTableContent();
            },
          ),
        ),
      ),
    );

    // OLD TABLE LAYOUT (9 columns: Time, Instrument, Product, Type, Side, Qty, Price, Value, Order No) - COMMENTED OUT
    // return shadcn.OutlinedContainer(
    //   child: LayoutBuilder(
    //     builder: (context, constraints) {
    //       // Calculate minimum widths dynamically based on actual content
    //       final minWidths = _calculateMinWidths(sortedTrades, context);
    //
    //       // Available width
    //       final availableWidth = constraints.maxWidth;
    //
    //       // Step 1: Start with minimum widths (content-based, no wasted space)
    //       final columnWidths = <int, double>{};
    //       for (int i = 0; i < 9; i++) {
    //         columnWidths[i] = minWidths[i] ?? 100.0;
    //       }
    //
    //       // Step 2: Calculate total minimum width needed
    //       final totalMinWidth = columnWidths.values
    //           .fold<double>(0.0, (sum, width) => sum + width);
    //
    //       // Step 3: If there's extra space, distribute it proportionally
    //       // This prevents unnecessary horizontal scroll while using available space efficiently
    //       if (totalMinWidth < availableWidth) {
    //         final extraSpace = availableWidth - totalMinWidth;
    //
    //         // Define which columns can grow and their growth priorities
    //         const instrumentGrowthFactor =
    //             2.0; // Instrument can grow 2x more than numeric
    //         const textGrowthFactor = 1.2;
    //         const numericGrowthFactor = 1.0;
    //
    //         // Calculate growth factors for each column
    //         final growthFactors = <int, double>{};
    //         double totalGrowthFactor = 0.0;
    //
    //         for (int i = 0; i < 9; i++) {
    //           // Column 0: Time
    //           // Column 1: Instrument
    //           // Columns 2, 3, 4, 8: Text columns (Product, Type, Side, Order no)
    //           // Rest: Numeric columns
    //           if (i == 1) {
    //             growthFactors[i] = instrumentGrowthFactor;
    //             totalGrowthFactor += instrumentGrowthFactor;
    //           } else if (i == 2 || i == 3 || i == 4 || i == 8) {
    //             growthFactors[i] = textGrowthFactor;
    //             totalGrowthFactor += textGrowthFactor;
    //           } else {
    //             growthFactors[i] = numericGrowthFactor;
    //             totalGrowthFactor += numericGrowthFactor;
    //           }
    //         }
    //
    //         // Distribute extra space proportionally
    //         if (totalGrowthFactor > 0) {
    //           for (int i = 0; i < 9; i++) {
    //             if (growthFactors[i]! > 0) {
    //               final extraForThisColumn =
    //                   (extraSpace * growthFactors[i]!) / totalGrowthFactor;
    //               columnWidths[i] = columnWidths[i]! + extraForThisColumn;
    //             }
    //           }
    //         }
    //       }
    //
    //       // Calculate total required width
    //       final totalRequiredWidth = columnWidths.values
    //           .fold<double>(0.0, (sum, width) => sum + width);
    //
    //       // If total width exceeds available width, enable horizontal scrolling
    //       final needsHorizontalScroll = totalRequiredWidth > availableWidth;
    //
    //       // Build table content
    //       Widget buildTableContent() {
    //         return Column(
    //           children: [
    //             // Fixed Header
    //             shadcn.Table(
    //               columnWidths: {
    //                 0: shadcn.FixedTableSize(columnWidths[0]!),
    //                 1: shadcn.FixedTableSize(columnWidths[1]!),
    //                 2: shadcn.FixedTableSize(columnWidths[2]!),
    //                 3: shadcn.FixedTableSize(columnWidths[3]!),
    //                 4: shadcn.FixedTableSize(columnWidths[4]!),
    //                 5: shadcn.FixedTableSize(columnWidths[5]!),
    //                 6: shadcn.FixedTableSize(columnWidths[6]!),
    //                 7: shadcn.FixedTableSize(columnWidths[7]!),
    //                 8: shadcn.FixedTableSize(columnWidths[8]!),
    //               },
    //               defaultRowHeight: const shadcn.FixedTableSize(40),
    //               rows: [
    //                 shadcn.TableHeader(
    //                   cells: [
    //                     buildHeaderCell('Time', 0),
    //                     buildHeaderCell('Instrument', 1),
    //                     buildHeaderCell('Product', 2),
    //                     buildHeaderCell('Type', 3),
    //                     buildHeaderCell('Side', 4),
    //                     buildHeaderCell('Qty', 5, true),
    //                     buildHeaderCell('Price', 6, true),
    //                     buildHeaderCell('Value', 7, true),
    //                     buildHeaderCell('Order No', 8, true),
    //                   ],
    //                 ),
    //               ],
    //             ),
    //             // Scrollable Body
    //             Expanded(
    //               child: RawScrollbar(
    //                 controller: _verticalScrollController,
    //                 thumbVisibility: true,
    //                 trackVisibility: true,
    //                 trackColor: resolveThemeColor(context,
    //                     dark: Colors.grey.withValues(alpha: 0.1),
    //                     light: Colors.grey.withValues(alpha: 0.1)),
    //                 thumbColor: resolveThemeColor(context,
    //                     dark: Colors.grey.withValues(alpha: 0.3),
    //                     light: Colors.grey.withValues(alpha: 0.3)),
    //                 thickness: 6,
    //                 radius: const Radius.circular(3),
    //                 interactive: true,
    //                 child: SingleChildScrollView(
    //                   controller: _verticalScrollController,
    //                   scrollDirection: Axis.vertical,
    //                   child: shadcn.Table(
    //                     key: ValueKey(
    //                         'table_${_sortColumnIndex}_$_sortAscending'),
    //                     columnWidths: {
    //                       0: shadcn.FixedTableSize(columnWidths[0]!),
    //                       1: shadcn.FixedTableSize(columnWidths[1]!),
    //                       2: shadcn.FixedTableSize(columnWidths[2]!),
    //                       3: shadcn.FixedTableSize(columnWidths[3]!),
    //                       4: shadcn.FixedTableSize(columnWidths[4]!),
    //                       5: shadcn.FixedTableSize(columnWidths[5]!),
    //                       6: shadcn.FixedTableSize(columnWidths[6]!),
    //                       7: shadcn.FixedTableSize(columnWidths[7]!),
    //                       8: shadcn.FixedTableSize(columnWidths[8]!),
    //                     },
    //                     defaultRowHeight: const shadcn.FixedTableSize(40),
    //                     rows: sortedTrades.asMap().entries.map((entry) {
    //                       final index = entry.key;
    //                       final trade = entry.value;
    //
    //                       return shadcn.TableRow(
    //                         cells: [
    //                           buildCellWithHover(
    //                             rowIndex: index,
    //                             columnIndex: 0,
    //                             onTap: () => _showTradeDetail(trade),
    //                             child: Text(
    //                               _formatTime(trade.norentm ?? 'N/A'),
    //                               style: _getTextStyle(context),
    //                             ),
    //                           ),
    //                           buildCellWithHover(
    //                             rowIndex: index,
    //                             columnIndex: 1,
    //                             onTap: () => _showTradeDetail(trade),
    //                             child: _buildOldInstrumentCell(trade, theme),
    //                           ),
    //                           // Product
    //                           buildCellWithHover(
    //                             rowIndex: index,
    //                             columnIndex: 2,
    //                             onTap: () => _showTradeDetail(trade),
    //                             child: Text(
    //                               trade.sPrdtAli ?? trade.prd ?? '',
    //                               style: _getTextStyle(context),
    //                             ),
    //                           ),
    //                           // Type
    //                           buildCellWithHover(
    //                             rowIndex: index,
    //                             columnIndex: 3,
    //                             onTap: () => _showTradeDetail(trade),
    //                             child: Text(
    //                               trade.prctyp ?? '',
    //                               style: _getTextStyle(context),
    //                             ),
    //                           ),
    //                           // Side
    //                           buildCellWithHover(
    //                             rowIndex: index,
    //                             columnIndex: 4,
    //                             onTap: () => _showTradeDetail(trade),
    //                             child: Text(
    //                               trade.trantype == "S" ? "SELL" : "BUY",
    //                               style: _getTextStyle(
    //                                 context,
    //                                 color: trade.trantype == "S"
    //                                     ? resolveThemeColor(context,
    //                                         dark: MyntColors.lossDark,
    //                                         light: MyntColors.loss)
    //                                     : resolveThemeColor(context,
    //                                         dark: MyntColors.profitDark,
    //                                         light: MyntColors.profit),
    //                               ),
    //                             ),
    //                           ),
    //                           // Qty
    //                           buildCellWithHover(
    //                             rowIndex: index,
    //                             columnIndex: 5,
    //                             alignRight: true,
    //                             onTap: () => _showTradeDetail(trade),
    //                             child: Text(
    //                               trade.qty?.toString() ?? 'N/A',
    //                               style: _getTextStyle(context),
    //                             ),
    //                           ),
    //                           // Price
    //                           buildCellWithHover(
    //                             rowIndex: index,
    //                             columnIndex: 6,
    //                             alignRight: true,
    //                             onTap: () => _showTradeDetail(trade),
    //                             child: Text(
    //                               trade.avgprc?.toString() ?? 'N/A',
    //                               style: _getTextStyle(context),
    //                             ),
    //                           ),
    //                           // Value
    //                           buildCellWithHover(
    //                             rowIndex: index,
    //                             columnIndex: 7,
    //                             alignRight: true,
    //                             onTap: () => _showTradeDetail(trade),
    //                             child: Text(
    //                               CellFormatters.calculateTradeValue(trade),
    //                               style: _getTextStyle(context),
    //                             ),
    //                           ),
    //                           // Order No
    //                           buildCellWithHover(
    //                             rowIndex: index,
    //                             columnIndex: 8,
    //                             alignRight: true,
    //                             onTap: () => _showTradeDetail(trade),
    //                             child: Text(
    //                               trade.flid?.toString() ?? 'N/A',
    //                               style: _getTextStyle(context),
    //                             ),
    //                           ),
    //                         ],
    //                       );
    //                     }).toList(),
    //                   ),
    //                 ),
    //               ),
    //             ),
    //           ],
    //         );
    //       }
    //
    //       // Horizontal scroll wrapper (if needed)
    //       if (needsHorizontalScroll) {
    //         return Scrollbar(
    //           controller: _horizontalScrollController,
    //           thumbVisibility: true,
    //           trackVisibility: true,
    //           interactive: true,
    //           child: SingleChildScrollView(
    //             controller: _horizontalScrollController,
    //             scrollDirection: Axis.horizontal,
    //             child: SizedBox(
    //               width: totalRequiredWidth,
    //               child: buildTableContent(),
    //             ),
    //           ),
    //         );
    //       }
    //
    //       return buildTableContent();
    //     },
    //   ),
    // );
  }

  // Builds a cell with hover detection (matches positions pattern)
  // 8 columns: Trade ID, Fill time, Type, Instrument, Product, Qty., LTP, Avg. Price
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    VoidCallback? onTap,
  }) {
    final isFirstColumn = columnIndex == 0; // Trade ID column
    final isInstrumentColumn = columnIndex == 3; // Instrument column (index 3 now)
    final isLastColumn = columnIndex == 7; // Avg. Price column (index 7 now)

    // Match the cell padding logic - Instrument column has more left, minimal right
    // Last column mirrors this - minimal left, more right
    EdgeInsets cellPadding;
    if (isFirstColumn) {
      // First column - symmetric padding
      cellPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    } else if (isInstrumentColumn) {
      // Instrument column - more left, minimal right (for overlay buttons)
      cellPadding = const EdgeInsets.fromLTRB(16, 4, 4, 4);
    } else if (isLastColumn) {
      // Last column - minimal left, more right
      cellPadding = const EdgeInsets.fromLTRB(4, 4, 16, 4);
    } else {
      // Other columns - symmetric padding
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
                (_activePopoverController != null && _popoverRowIndex == rowIndex);

            return GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                padding: cellPadding,
                alignment:
                    alignRight ? Alignment.centerRight : Alignment.centerLeft,
                // Watchlist-style hover background
                color: isRowHovered
                    ? resolveThemeColor(
                        context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary,
                      ).withValues(alpha: 0.08)
                    : Colors.transparent,
                child: cachedChild,
              ),
            );
          },
        ),
      ),
    );
  }

  // Builds a sortable header cell
  // 8 columns: Trade ID, Fill time, Type, Instrument, Product, Qty., LTP, Avg. Price
  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0; // Trade ID column
    final isInstrumentColumn = columnIndex == 3; // Instrument column (index 3 now)
    final isLastColumn = columnIndex == 7; // Avg. Price column (index 7 now)

    // Match the cell padding logic - Instrument column has more left, minimal right
    // Last column mirrors this - minimal left, more right
    EdgeInsets headerPadding;
    if (isFirstColumn) {
      // First column - symmetric padding
      headerPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6);
    } else if (isInstrumentColumn) {
      // Instrument column - more left, minimal right
      headerPadding = const EdgeInsets.fromLTRB(16, 6, 4, 6);
    } else if (isLastColumn) {
      // Last column - minimal left, more right
      headerPadding = const EdgeInsets.fromLTRB(4, 6, 16, 6);
    } else {
      // Other columns - symmetric padding
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
          width: double.infinity,
          height: double.infinity,
          padding: headerPadding,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: resolveThemeColor(
              context,
              dark: MyntColors.cardDark,
              light: MyntColors.listItemBg,
            ),
          ),
          child: Row(
            mainAxisAlignment:
                alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (alignRight && _sortColumnIndex == columnIndex)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: shadcn.Theme.of(context).colorScheme.mutedForeground,
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
                  color: shadcn.Theme.of(context).colorScheme.mutedForeground,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Format fill time to show HH:mm:ss format
  String _formatFillTime(String time) {
    if (time.isEmpty || time == '0.00' || time == 'N/A') return 'N/A';

    try {
      // Check if time is in "HH:mm:ss dd-MM-yyyy" format
      if (time.contains(':') && time.contains('-')) {
        final timePart = time.split(' ')[0]; // Get "HH:mm:ss" part
        return timePart; // Returns time with seconds
      }

      // Fallback: If time is in "HHMMSS" or "HHMM" format
      if (time.length >= 6) {
        // Format: "HHMMSS" to "HH:MM:SS"
        final hours = time.substring(0, 2);
        final minutes = time.substring(2, 4);
        final seconds = time.substring(4, 6);
        return '$hours:$minutes:$seconds';
      } else if (time.length >= 4) {
        // Format: "HHMM" to "HH:MM:00"
        final hours = time.substring(0, 2);
        final minutes = time.substring(2, 4);
        return '$hours:$minutes:00';
      }
    } catch (e) {
      // If parsing fails, return as is
    }

    return time;
  }

  // OLD: Format time for display (commented out - replaced by _formatFillTime)
  // String _formatTime(String time) {
  //   if (time.isEmpty || time == '0.00' || time == 'N/A') return 'N/A';
  //
  //   // Try using CellFormatters first (expects "HH:mm:ss dd-MM-yyyy" format)
  //   final formatted = CellFormatters.formatTime(time);
  //   if (formatted.isNotEmpty) {
  //     // Extract just the time part (hh:mm a) from "dd MMM yyyy, hh:mm a"
  //     final parts = formatted.split(', ');
  //     if (parts.length == 2) {
  //       return parts[1]; // Return "hh:mm a" part
  //     }
  //     return formatted;
  //   }
  //
  //   // Fallback: If formatDateTime failed, try parsing as simple time string (HHMMSS or HHMM)
  //   try {
  //     if (time.length >= 6) {
  //       // Format: "HHMMSS" to "HH:MM:SS"
  //       final hours = time.substring(0, 2);
  //       final minutes = time.substring(2, 4);
  //       final seconds = time.substring(4, 6);
  //       return '$hours:$minutes:$seconds';
  //     } else if (time.length >= 4) {
  //       // Format: "HHMM" to "HH:MM"
  //       final hours = time.substring(0, 2);
  //       final minutes = time.substring(2, 4);
  //       return '$hours:$minutes';
  //     }
  //   } catch (e) {
  //     // If parsing fails, return as is
  //   }
  //
  //   return time;
  // }

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

  // OLD: Calculate minimum column widths dynamically (commented out - using equal widths now)
  // Map<int, double> _calculateMinWidths(
  //     List<TradeBookModel> trades, BuildContext context) {
  //   // Use fixed font size for measurement (table text is not responsive, only buttons are)
  //   final textStyle = const TextStyle(fontSize: 14, fontFamily: 'Geist');
  //   const padding = 24.0;
  //   const sortIconWidth = 24.0;
  //
  //   final headers = [
  //     'Time',
  //     'Instrument',
  //     'Product',
  //     'Type',
  //     'Side',
  //     'Qty',
  //     'Price',
  //     'Value',
  //     'Order No',
  //   ];
  //   final minWidths = <int, double>{};
  //
  //   for (int col = 0; col < headers.length; col++) {
  //     double maxWidth = 0.0;
  //     final headerWidth = _measureTextWidth(headers[col], textStyle);
  //     maxWidth = headerWidth + sortIconWidth;
  //
  //     for (final trade in trades.take(5)) {
  //       String cellText = '';
  //       switch (col) {
  //         case 0:
  //           cellText = _formatFillTime(trade.norentm ?? 'N/A');
  //           break;
  //         case 1:
  //           // For Instrument column, measure symbol + exchange separately
  //           final displayText = CellFormatters.formatTradeInstrumentText(trade);
  //           final exchange = trade.exch ?? '';
  //           final exchangeText = exchange.isNotEmpty ? ' $exchange' : '';
  //
  //           // Measure symbol with normal font
  //           final symbolWidth = _measureTextWidth(displayText, textStyle);
  //
  //           // Measure exchange with smaller font (10px, matches rendering)
  //           final exchangeStyle =
  //               const TextStyle(fontSize: 10, fontFamily: 'Geist');
  //           final exchangeWidth = exchangeText.isNotEmpty
  //               ? _measureTextWidth(exchangeText, exchangeStyle)
  //               : 0.0;
  //
  //           final totalWidth = symbolWidth +
  //               exchangeWidth +
  //               (exchangeText.isNotEmpty ? 4.0 : 0.0);
  //           if (totalWidth > maxWidth) maxWidth = totalWidth;
  //           continue;
  //         case 2:
  //           cellText = trade.sPrdtAli ?? trade.prd ?? '';
  //           break;
  //         case 3:
  //           cellText = trade.prctyp ?? '';
  //           break;
  //         case 4:
  //           cellText = trade.trantype == "S" ? "SELL" : "BUY";
  //           break;
  //         case 5:
  //           cellText = trade.qty?.toString() ?? 'N/A';
  //           break;
  //         case 6:
  //           cellText = trade.avgprc?.toString() ?? 'N/A';
  //           break;
  //         case 7:
  //           cellText = CellFormatters.calculateTradeValue(trade);
  //           break;
  //         case 8:
  //           cellText = trade.flid?.toString() ?? 'N/A';
  //           break;
  //       }
  //
  //       final cellWidth = _measureTextWidth(cellText, textStyle);
  //       if (cellWidth > maxWidth) {
  //         maxWidth = cellWidth;
  //       }
  //     }
  //
  //     // Ensure minimum widths to prevent truncation for important columns
  //     if (headers[col] == 'Instrument') {
  //       const minInstrumentWidth = 150.0;
  //       maxWidth =
  //           maxWidth < minInstrumentWidth ? minInstrumentWidth : maxWidth;
  //     } else if (headers[col] == 'Time') {
  //       // Ensure Time column has enough width to show full time (e.g., "12:57 PM" or "11:14 AM")
  //       const minTimeWidth = 90.0;
  //       maxWidth = maxWidth < minTimeWidth ? minTimeWidth : maxWidth;
  //     } else if (headers[col] == 'Order no') {
  //       // Ensure Order number column has enough width to show full order number
  //       const minOrderNoWidth = 120.0;
  //       maxWidth = maxWidth < minOrderNoWidth ? minOrderNoWidth : maxWidth;
  //     }
  //
  //     minWidths[col] = maxWidth + padding;
  //   }
  //
  //   return minWidths;
  // }
  //
  // double _measureTextWidth(String text, TextStyle style) {
  //   final textPainter = TextPainter(
  //     text: TextSpan(text: text, style: style),
  //     textDirection: TextDirection.ltr,
  //     maxLines: 1,
  //   );
  //   textPainter.layout();
  //   return textPainter.width;
  // }

  // Sort trades based on 8 columns: Trade ID, Fill time, Type, Instrument, Product, Qty., Avg. Price, LTP
  List<TradeBookModel> _getSortedTrades(List<TradeBookModel> trades) {
    if (_sortColumnIndex == null) return trades;

    final sorted = List<TradeBookModel>.from(trades);
    sorted.sort((a, b) {
      int comparison = 0;

      switch (_sortColumnIndex!) {
        case 0: // Trade ID
          comparison = (a.flid ?? '').compareTo(b.flid ?? '');
          break;
        case 1: // Fill time
          comparison = (a.norentm ?? '').compareTo(b.norentm ?? '');
          break;
        case 2: // Type (BUY/SELL)
          comparison = (a.trantype ?? '').compareTo(b.trantype ?? '');
          break;
        case 3: // Instrument
          comparison = CellFormatters.formatTradeInstrumentText(a)
              .compareTo(CellFormatters.formatTradeInstrumentText(b));
          break;
        case 4: // Product
          comparison =
              (a.sPrdtAli ?? a.prd ?? '').compareTo(b.sPrdtAli ?? b.prd ?? '');
          break;
        case 5: // Qty.
          comparison = (int.tryParse(a.qty ?? '0') ?? 0)
              .compareTo(int.tryParse(b.qty ?? '0') ?? 0);
          break;
        case 6: // LTP (using avgprc as fallback since LTP comes from websocket)
          comparison = (double.tryParse(a.avgprc ?? '0') ?? 0)
              .compareTo(double.tryParse(b.avgprc ?? '0') ?? 0);
          break;
        case 7: // Avg. Price
          comparison = (double.tryParse(a.avgprc ?? '0') ?? 0)
              .compareTo(double.tryParse(b.avgprc ?? '0') ?? 0);
          break;
        // OLD column cases (commented out):
        // case 7: // Trade value
        //   final aValue = (double.tryParse(a.avgprc ?? '0') ?? 0) *
        //       (int.tryParse(a.qty ?? '0') ?? 0);
        //   final bValue = (double.tryParse(b.avgprc ?? '0') ?? 0) *
        //       (int.tryParse(b.qty ?? '0') ?? 0);
        //   comparison = aValue.compareTo(bValue);
        //   break;
        // case 8: // Order no
        //   comparison = (a.flid ?? '').compareTo(b.flid ?? '');
        //   break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  Widget _buildInstrumentCell(
    TradeBookModel trade,
    ThemesProvider theme,
    bool isHovered, {
    int? rowIndex,
  }) {
    // Format instrument using CellFormatters to include strike price and expiry date
    final displayText = CellFormatters.formatTradeInstrumentText(trade);
    final exchange = trade.exch ?? '';

    return GestureDetector(
      onTap: () => _showTradeDetail(trade),
      behavior: HitTestBehavior.deferToChild,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Instrument name - full width, can be partially covered by buttons
            Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message:
                    '$displayText${exchange.isNotEmpty ? ' $exchange' : ''}',
                child: Padding(
                  padding: EdgeInsets.only(right: isHovered ? 40.0 : 0.0),
                  child: RichText(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                    text: TextSpan(
                      children: [
                        // Symbol (14px, 500)
                        TextSpan(
                          text: displayText.isNotEmpty ? displayText : 'N/A',
                          style: _getTextStyle(context),
                        ),
                        // Exchange (10px, 500, muted color) - matching positions table style
                        if (exchange.isNotEmpty)
                          TextSpan(
                            text: ' $exchange',
                            style: MyntWebTextStyles.para(
                              context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary,
                              fontWeight: MyntFonts.medium,
                            ).copyWith(fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 3-dot menu button (appears on hover)
            if (isHovered)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildOptionsMenuButton(
                    trade,
                    rowIndex: rowIndex,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper to build menu item matching positions dropdown style
  shadcn.MenuButton _buildMenuButton({
    required IconData icon,
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

  // Build the 3-dot options menu button with shadcn dropdown
  Widget _buildOptionsMenuButton(
    TradeBookModel trade, {
    int? rowIndex,
  }) {
    final iconColor = resolveThemeColor(context,
        dark: MyntColors.iconDark, light: MyntColors.icon);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          onTap: () {
            // Build menu items
            List<shadcn.MenuItem> menuItems = [];

            // Repeat option
            menuItems.add(
              _buildMenuButton(
                icon: Icons.replay,
                title: 'Repeat',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  // TODO: Implement repeat trade functionality
                },
              ),
            );

            // Add divider before info
            menuItems.add(const shadcn.MenuDivider());

            // Info option
            menuItems.add(
              _buildMenuButton(
                icon: Icons.info_outline,
                title: 'Info',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  _showTradeDetail(trade);
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
                    // Start delayed close - gives time for mouse to move back to row
                    _startPopoverCloseTimer();
                  },
                  child: shadcn.DropdownMenu(
                    children: menuItems,
                  ),
                );
              },
            );
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
              fontWeight: FontWeight.bold,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimary,
                  light: MyntColors.textPrimary),
            ),
          ),
        );
      },
    );
  }

  // OLD: Simple instrument cell without hover menu (commented out)
  // Widget _buildOldInstrumentCell(TradeBookModel trade, ThemesProvider theme) {
  //   // Format instrument using CellFormatters to include strike price and expiry date
  //   final displayText = CellFormatters.formatTradeInstrumentText(trade);
  //   final exchange = trade.exch ?? '';
  //
  //   return RichText(
  //     overflow: TextOverflow.ellipsis,
  //     maxLines: 1,
  //     text: TextSpan(
  //       children: [
  //         // Symbol with strike price (normal color, fixed 14px)
  //         TextSpan(
  //           text: displayText.isNotEmpty ? displayText : 'N/A',
  //           style: _getTextStyle(context),
  //         ),
  //         // Exchange (mutedForeground color, smaller font, fixed 10px) - matching positions table style
  //         if (exchange.isNotEmpty)
  //           TextSpan(
  //             text: ' $exchange',
  //             style: MyntWebTextStyles.para(
  //               context,
  //               darkColor: MyntColors.textSecondaryDark,
  //               lightColor: MyntColors.textSecondary,
  //               fontWeight: MyntFonts.medium,
  //             ).copyWith(fontSize: 10),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  // Show trade detail using shadcn sheet
  void _showTradeDetail(TradeBookModel trade) {
    // Prevent double-click from opening sheet twice
    if (_isSheetOpening) return;
    _isSheetOpening = true;

    shadcn.openSheet(
      context: context,
      builder: (sheetContext) {
        final screenWidth = MediaQuery.of(sheetContext).size.width;
        final sheetWidth = screenWidth < 1500 ? screenWidth * 0.3 : 480.0;
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
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 5,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: TradeDetailScreenWeb(
            trade: trade,
            parentContext: context,
          ),
        );
      },
      position: shadcn.OverlayPosition.end,
      barrierColor: Colors.transparent,
    ).then((_) {
      // Reset flag when sheet closes
      _isSheetOpening = false;
    });
  }
}

// LTP Cell with WebSocket updates for Trade Book
class _TradeLTPCell extends ConsumerStatefulWidget {
  final String token;
  final String initialLtp;

  const _TradeLTPCell({
    required this.token,
    required this.initialLtp,
  });

  @override
  ConsumerState<_TradeLTPCell> createState() => _TradeLTPCellState();
}

class _TradeLTPCellState extends ConsumerState<_TradeLTPCell> {
  late String ltp;
  StreamSubscription? _subscription;
  bool _didSetupSubscription = false;

  @override
  void initState() {
    super.initState();
    ltp = widget.initialLtp;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didSetupSubscription && widget.token.isNotEmpty) {
      _didSetupSubscription = true;

      // Check existing socket data first (tokens may already be subscribed via watchlist)
      final existingData = ref.read(websocketProvider).socketDatas;
      if (existingData.containsKey(widget.token)) {
        final existingLtp = existingData[widget.token]['lp']?.toString();
        if (existingLtp != null &&
            existingLtp != '0.00' &&
            existingLtp != 'null' &&
            existingLtp != '0') {
          ltp = existingLtp;
        }
      }

      // Subscribe for future updates
      Future.microtask(() {
        if (!mounted) return;

        _subscription =
            ref.read(websocketProvider).socketDataStream.listen((data) {
          if (!mounted || !data.containsKey(widget.token)) return;

          final newLtp = data[widget.token]['lp']?.toString();
          if (newLtp != null &&
              newLtp != ltp &&
              newLtp != 'null' &&
              newLtp != '' &&
              newLtp != '0' &&
              newLtp != '0.0' &&
              newLtp != '0.00') {
            setState(() => ltp = newLtp);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: ltp,
      child: Text(
        ltp,
        style: MyntWebTextStyles.tableCell(
          context,
          darkColor: MyntColors.textPrimaryDark,
          lightColor: MyntColors.textPrimary,
          fontWeight: MyntFonts.medium,
        ).copyWith(
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
