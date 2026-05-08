import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart'
    hide DataTable, DataColumn, DataRow, DataCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';

import '../refactored/services/order_action_handler.dart';
import '../refactored/utils/cell_formatters.dart';

/// Open Orders tab using shadcn DataTable
class OpenOrdersScreen extends ConsumerStatefulWidget {
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;

  const OpenOrdersScreen({
    super.key,
    required this.horizontalScrollController,
    required this.verticalScrollController,
  });

  @override
  ConsumerState<OpenOrdersScreen> createState() => _OpenOrdersScreenState();
}

class _OpenOrdersScreenState extends ConsumerState<OpenOrdersScreen> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  // PERFORMANCE FIX: Use ValueNotifier for hover instead of setState
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);
  bool _isProcessingCancel = false;
  bool _isProcessingModify = false;
  bool _isProcessingExit = false;
  String? _processingOrderToken;
  Offset _modifyDialogPosition = const Offset(100, 100);

  // Track the popover controller to close it when row is unhovered
  shadcn.PopoverController? _activePopoverController;

  // Track which row the popover belongs to
  int? _popoverRowIndex;

  // Track if mouse is hovering over the dropdown menu
  bool _isHoveringDropdown = false;

  // Timer for delayed popover close (allows mouse to move from row to dropdown)
  Timer? _popoverCloseTimer;

  @override
  void initState() {
    super.initState();
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

  // Format order qty - for MCX, divide by lot size
  String _formatOrderQty(OrderBookModel order) {
    final rawFilled = int.tryParse(order.fillshares ?? '0') ?? 0;
    final rawQty = int.tryParse(order.qty ?? '0') ?? 0;
    final lotSize = order.exch == 'MCX'
        ? (int.tryParse(order.ls ?? '1') ?? 1)
        : 1;
    final filledQty = rawFilled ~/ lotSize;
    final totalQty = rawQty ~/ lotSize;
    return '$filledQty / $totalQty';
  }

  // Builds a cell with hover detection (matches positions pattern)
  // 9 columns: Select, Time, Type, Instrument, Product, Qty., LTP, Price, Status
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    VoidCallback? onTap,
  }) {
    final isSelectColumn = columnIndex == 0; // Select checkbox column
    final isTimeColumn = columnIndex == 1; // Time column
    final isInstrumentColumn = columnIndex == 3; // Instrument column
    final isLastColumn = columnIndex == 8; // Status column

    // Match the cell padding logic - Instrument column has more left, minimal right
    // Last column mirrors this - minimal left, more right
    EdgeInsets cellPadding;
    if (isSelectColumn) {
      cellPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    } else if (isTimeColumn) {
      // Time column - symmetric padding
      cellPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4);
    } else if (isInstrumentColumn) {
      // Instrument column - more left, minimal right (for overlay buttons)
      cellPadding = const EdgeInsets.fromLTRB(12, 4, 4, 4);
    } else if (isLastColumn) {
      // Last column - minimal left, more right
      cellPadding = const EdgeInsets.fromLTRB(4, 4, 12, 4);
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
      child: ClipRect(
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
      ),
    );
  }

  // Builds a sortable header cell
  // 9 columns: Select, Time, Type, Instrument, Product, Qty., LTP, Price, Status
  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isSelectColumn = columnIndex == 0; // Select checkbox column
    final isTimeColumn = columnIndex == 1; // Time column
    final isInstrumentColumn = columnIndex == 3; // Instrument column
    final isLastColumn = columnIndex == 8; // Status column

    // Match the cell padding logic - consistent with data cells
    EdgeInsets headerPadding;
    if (isSelectColumn) {
      headerPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    } else if (isTimeColumn) {
      // Time column - symmetric padding
      headerPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    } else if (isInstrumentColumn) {
      // Instrument column - more left, minimal right
      headerPadding = const EdgeInsets.fromLTRB(12, 6, 4, 6);
    } else if (isLastColumn) {
      // Last column - minimal left, more right
      headerPadding = const EdgeInsets.fromLTRB(4, 6, 12, 6);
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
      child: ClipRect(
        child: InkWell(
          onTap: () => _onSort(columnIndex),
          child: Container(
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
              mainAxisSize: MainAxisSize.min,
              children: [
                if (alignRight && _sortColumnIndex == columnIndex)
                  Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: shadcn.Theme.of(context).colorScheme.mutedForeground,
                  ),
                if (alignRight && _sortColumnIndex == columnIndex)
                  const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: _getHeaderStyle(context),
                    overflow: TextOverflow.ellipsis,
                  ),
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

  // Helper method to format time with seconds (HH:mm:ss)
  String _formatTime(String time) {
    if (time.isEmpty || time == '0.00') return 'N/A';

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

  Color _getStatusColor(String status) {
    final statusUpper = status.toUpperCase();

    if (statusUpper.contains('COMPLETE') || statusUpper.contains('FILLED')) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    } else if (statusUpper.contains('REJECT') ||
        statusUpper.contains('CANCEL')) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    } else if (statusUpper.contains('PENDING') ||
        statusUpper.contains('OPEN')) {
      return resolveThemeColor(context,
          dark: MyntColors.warning, light: MyntColors.warning);
    }
    return resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
  }

  // Commented out - using equal width columns now
  // // Calculate minimum column widths dynamically based on header and data
  // // 8 columns: Time, Type, Instrument, Product, Qty., LTP, Price, Status
  // Map<int, double> _calculateMinWidths(
  //     List<OrderBookModel> orders, BuildContext context) {
  //   // Use fixed font size for measurement (table text is not responsive, only buttons are)
  //   final textStyle = const TextStyle(fontSize: 14, fontFamily: 'Geist');
  //   const padding = 24.0; // Padding for cell content
  //   const sortIconWidth = 24.0; // Extra space for sort indicator icon
  //
  //   // 8 columns: Time, Type, Instrument, Product, Qty., LTP, Price, Status
  //   final headers = [
  //     'Time',
  //     'Type',
  //     'Instrument',
  //     'Product',
  //     'Qty.',
  //     'LTP',
  //     'Price',
  //     'Status',
  //   ];
  //   final minWidths = <int, double>{};
  //
  //   // Calculate width for each column
  //   for (int col = 0; col < headers.length; col++) {
  //     double maxWidth = 0.0;
  //
  //     // Measure header width and add space for sort icon
  //     final headerWidth = _measureTextWidth(headers[col], textStyle);
  //     maxWidth = headerWidth + sortIconWidth;
  //
  //     // Measure widest value in this column (sample first 5 rows for performance)
  //     for (final order in orders.take(5)) {
  //       String cellText = '';
  //       switch (col) {
  //         case 0: // Time
  //           cellText = _formatTime(order.norentm ?? '0.00');
  //           break;
  //         case 1: // Type (BUY/SELL)
  //           cellText = order.trantype == "S" ? "SELL" : "BUY";
  //           break;
  //         case 2: // Instrument
  //           final symbol = (order.tsym ?? '').replaceAll("-EQ", "").trim();
  //           final exchange = order.exch ?? '';
  //           final exchangeText = exchange.isNotEmpty ? ' $exchange' : '';
  //           final symbolWidth = _measureTextWidth(symbol, textStyle);
  //           final exchangeStyle =
  //               const TextStyle(fontSize: 10, fontFamily: 'Geist');
  //           final exchangeWidth = exchangeText.isNotEmpty
  //               ? _measureTextWidth(exchangeText, exchangeStyle)
  //               : 0.0;
  //           final totalWidth = symbolWidth +
  //               exchangeWidth +
  //               (exchangeText.isNotEmpty ? 4.0 : 0.0);
  //           if (totalWidth > maxWidth) {
  //             maxWidth = totalWidth;
  //           }
  //           continue;
  //         case 3: // Product
  //           cellText = order.sPrdtAli ?? order.prd ?? '';
  //           break;
  //         case 4: // Qty.
  //           cellText = order.qty?.toString() ?? '0';
  //           break;
  //         case 5: // LTP
  //           cellText = CellFormatters.getValidLTP(order);
  //           break;
  //         case 6: // Price
  //           cellText = CellFormatters.getValidPrice(order);
  //           break;
  //         case 7: // Status
  //           cellText = CellFormatters.getStatusText(order);
  //           break;
  //       }
  //
  //       final cellWidth = _measureTextWidth(cellText, textStyle);
  //       if (cellWidth > maxWidth) {
  //         maxWidth = cellWidth;
  //       }
  //     }
  //
  //     if (headers[col] == 'Instrument') {
  //       const minInstrumentWidth = 150.0;
  //       maxWidth =
  //           maxWidth < minInstrumentWidth ? minInstrumentWidth : maxWidth;
  //     }
  //
  //     minWidths[col] = maxWidth + padding;
  //   }
  //
  //   return minWidths;
  // }
  //
  // // Helper method to measure text width dynamically
  // double _measureTextWidth(String text, TextStyle style) {
  //   final textPainter = TextPainter(
  //     text: TextSpan(text: text, style: style),
  //     textDirection: TextDirection.ltr,
  //     maxLines: 1,
  //   );
  //   textPainter.layout();
  //   return textPainter.width;
  // }

  // Sort orders based on 8 columns: Time, Type, Instrument, Product, Qty., LTP, Price, Status
  List<OrderBookModel> _getSortedOrders(List<OrderBookModel> orders) {
    if (_sortColumnIndex == null) return orders;

    final sorted = List<OrderBookModel>.from(orders);
    sorted.sort((a, b) {
      int comparison = 0;

      switch (_sortColumnIndex) {
        case 0: // Time
          comparison = (a.norentm ?? '').compareTo(b.norentm ?? '');
          break;
        case 1: // Type (BUY/SELL)
          comparison = (a.trantype ?? '').compareTo(b.trantype ?? '');
          break;
        case 2: // Instrument
          comparison = (a.tsym ?? '').compareTo(b.tsym ?? '');
          break;
        case 3: // Product
          comparison =
              (a.sPrdtAli ?? a.prd ?? '').compareTo(b.sPrdtAli ?? b.prd ?? '');
          break;
        case 4: // Qty.
          comparison = (int.tryParse(a.qty ?? '0') ?? 0)
              .compareTo(int.tryParse(b.qty ?? '0') ?? 0);
          break;
        case 5: // LTP
          comparison = (double.tryParse(a.ltp ?? '0') ?? 0)
              .compareTo(double.tryParse(b.ltp ?? '0') ?? 0);
          break;
        case 6: // Price
          comparison = (double.tryParse(a.prc ?? '0') ?? 0)
              .compareTo(double.tryParse(b.prc ?? '0') ?? 0);
          break;
        case 7: // Status
          comparison = (CellFormatters.getStatusText(a))
              .compareTo(CellFormatters.getStatusText(b));
          break;
        // Old column cases (commented out):
        // case 3: // Type (Price type)
        //   comparison = (a.prctyp ?? '').compareTo(b.prctyp ?? '');
        //   break;
        // case 6: // Avg price
        //   comparison = (double.tryParse(a.avgprc ?? '0') ?? 0)
        //       .compareTo(double.tryParse(b.avgprc ?? '0') ?? 0);
        //   break;
        // case 9: // Trigger price
        //   comparison = (double.tryParse(a.trgprc ?? '0') ?? 0)
        //       .compareTo(double.tryParse(b.trgprc ?? '0') ?? 0);
        //   break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    // Selective watches — only rebuild when relevant data changes
    final openOrder = ref.watch(orderProvider.select((p) => p.openOrder));
    final orderSearchItem = ref.watch(orderProvider.select((p) => p.orderSearchItem));
    final isLoading = ref.watch(orderProvider.select((p) => p.loading));
    final selectedTab = ref.watch(orderProvider.select((p) => p.selectedTab));
    final orderBook = ref.read(orderProvider);

    // Get orders (search or regular)
    // Only show search results if we're on the Open Orders tab (index 0)
    final searchQuery = orderBook.orderSearchCtrl.text.trim();
    final isOpenOrdersTab = selectedTab == 0;
    final orders = (searchQuery.isNotEmpty && isOpenOrdersTab)
        ? (orderSearchItem ?? [])
        : (openOrder ?? []);

    // Sort orders (only if not empty)
    final sortedOrders = orders.isNotEmpty ? _getSortedOrders(orders) : <OrderBookModel>[];

    // Return shadcn Table with proper structure
    // 9 columns: Select, Time, Type, Instrument, Product, Qty., LTP, Price, Status
    return shadcn.OutlinedContainer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Available width
            final availableWidth = constraints.maxWidth;
        
            // Minimum column widths to prevent overflow
            const minSelectWidth = 50.0;
            const minTimeWidth = 80.0;
            const minTypeWidth = 60.0;
            const minInstrumentWidth = 180.0;
            const minProductWidth = 70.0;
            const minQtyWidth = 80.0;
            const minLtpWidth = 80.0;
            const minPriceWidth = 80.0;
            const minStatusWidth = 100.0;
        
            // Total minimum width required
            const totalMinWidth = minSelectWidth +
                minTimeWidth +
                minTypeWidth +
                minInstrumentWidth +
                minProductWidth +
                minQtyWidth +
                minLtpWidth +
                minPriceWidth +
                minStatusWidth;
        
            // Check if we need horizontal scroll
            final needsHorizontalScroll = availableWidth < totalMinWidth;
            final effectiveWidth = needsHorizontalScroll ? totalMinWidth : availableWidth;
        
            // Proportional widths for columns (total = 100%)
            // Select: 4%, Time: 10%, Type: 6%, Instrument: 24%, Product: 8%, Qty: 10%, LTP: 12%, Price: 12%, Status: 14%
            final selectWidth = (effectiveWidth * 0.04).clamp(minSelectWidth, double.infinity);
            final timeWidth = (effectiveWidth * 0.10).clamp(minTimeWidth, double.infinity);
            final typeWidth = (effectiveWidth * 0.06).clamp(minTypeWidth, double.infinity);
            final instrumentWidth = (effectiveWidth * 0.24).clamp(minInstrumentWidth, double.infinity);
            final productWidth = (effectiveWidth * 0.08).clamp(minProductWidth, double.infinity);
            final qtyWidth = (effectiveWidth * 0.10).clamp(minQtyWidth, double.infinity);
            final ltpWidth = (effectiveWidth * 0.12).clamp(minLtpWidth, double.infinity);
            final priceWidth = (effectiveWidth * 0.12).clamp(minPriceWidth, double.infinity);
            final statusWidth = (effectiveWidth * 0.14).clamp(minStatusWidth, double.infinity);
        
            // Actual total width after clamping (may exceed totalMinWidth due to clamp bump-ups)
            final actualTotalWidth = selectWidth + timeWidth + typeWidth +
                instrumentWidth + productWidth + qtyWidth + ltpWidth +
                priceWidth + statusWidth;
        
            // Old dynamic width calculation (commented out):
            // final minWidths = _calculateMinWidths(sortedOrders, context);
            // final columnWidths = <int, double>{};
            // for (int i = 0; i < 11; i++) {
            //   columnWidths[i] = minWidths[i] ?? 100.0;
            // }
            // ... proportional distribution logic ...
        
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
                    // Fixed Header - 9 columns with proportional widths
                    shadcn.Table(
                      columnWidths: {
                        0: shadcn.FixedTableSize(selectWidth),
                        1: shadcn.FixedTableSize(timeWidth),
                        2: shadcn.FixedTableSize(typeWidth),
                        3: shadcn.FixedTableSize(instrumentWidth),
                        4: shadcn.FixedTableSize(productWidth),
                        5: shadcn.FixedTableSize(qtyWidth),
                        6: shadcn.FixedTableSize(ltpWidth),
                        7: shadcn.FixedTableSize(priceWidth),
                        8: shadcn.FixedTableSize(statusWidth),
                      },
                      defaultRowHeight: const shadcn.FixedTableSize(40),
                      rows: [
                        shadcn.TableHeader(
                          cells: [
                            _buildSelectHeaderCell(orderBook, sortedOrders),
                            buildHeaderCell('Time', 1),
                            buildHeaderCell('Type', 2),
                            buildHeaderCell('Instrument', 3),
                            buildHeaderCell('Product', 4, true),
                            buildHeaderCell('Qty.', 5, true),
                            buildHeaderCell('LTP', 6, true),
                            buildHeaderCell('Price', 7, true),
                            buildHeaderCell('Status', 8, true),
                          ],
                        ),
                      ],
                    ),
                    // Scrollable Body (vertical scroll) - shows loader/no data/table rows
                    Expanded(
                      child: sortedOrders.isEmpty
                          ? (isLoading
                              ? Center(child: MyntLoader.simple())
                              : Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: NoDataFoundWeb(
                                      title: searchQuery.isNotEmpty ? "No Orders Found" : "No Orders",
                                      subtitle: searchQuery.isNotEmpty
                                          ? "No orders match your search \"$searchQuery\"."
                                          : "You don't have any open orders yet.",
                                      primaryEnabled: false,
                                      secondaryEnabled: false,
                                    ),
                                  ),
                                ))
                          : RawScrollbar(
                        controller: widget.verticalScrollController,
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
                          controller: widget.verticalScrollController,
                          itemCount: sortedOrders.length,
                          itemExtent: 42.0,
                          itemBuilder: (context, i) {
                            final order = sortedOrders[i];
                            final uniqueId = order.norenordno?.toString() ?? order.token?.toString() ?? '';
                            final isPending = order.status == "PENDING" || order.status == "OPEN" || order.status == "TRIGGER_PENDING";
                            final actionHandler = OrderActionHandler(ref: ref, context: context);
                            return shadcn.Table(
                              columnWidths: {
                                0: shadcn.FixedTableSize(selectWidth),
                                1: shadcn.FixedTableSize(timeWidth),
                                2: shadcn.FixedTableSize(typeWidth),
                                3: shadcn.FixedTableSize(instrumentWidth),
                                4: shadcn.FixedTableSize(productWidth),
                                5: shadcn.FixedTableSize(qtyWidth),
                                6: shadcn.FixedTableSize(ltpWidth),
                                7: shadcn.FixedTableSize(priceWidth),
                                8: shadcn.FixedTableSize(statusWidth),
                              },
                              defaultRowHeight: const shadcn.FixedTableSize(40),
                              rows: [
                                shadcn.TableRow(
                                  cells: [
                                    // Column 0: Select checkbox
                                    buildCellWithHover(
                                      rowIndex: i,
                                      columnIndex: 0,
                                      child: _buildCheckboxCell(order, orderBook, i, isPending),
                                    ),
                                    // Column 1: Time
                                    buildCellWithHover(
                                      rowIndex: i,
                                      columnIndex: 1,
                                      onTap: () => actionHandler.openOrderDetail(order),
                                      child: Text(
                                        _formatTime(order.norentm ?? '0.00'),
                                        style: _getTextStyle(context),
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                      ),
                                    ),
                                    // Column 2: Type (BUY/SELL)
                                    buildCellWithHover(
                                      rowIndex: i,
                                      columnIndex: 2,
                                      onTap: () => actionHandler.openOrderDetail(order),
                                      child: Text(
                                        order.trantype == "S" ? "SELL" : "BUY",
                                        style: _getTextStyle(
                                          context,
                                          color: order.trantype == "S"
                                              ? resolveThemeColor(context,
                                                  dark: MyntColors.lossDark, light: MyntColors.loss)
                                              : resolveThemeColor(context,
                                                  dark: MyntColors.profitDark, light: MyntColors.profit),
                                        ),
                                      ),
                                    ),
                                    // Column 3: Instrument
                                    buildCellWithHover(
                                      rowIndex: i,
                                      columnIndex: 3,
                                      child: ValueListenableBuilder<int?>(
                                        valueListenable: _hoveredRowIndex,
                                        builder: (context, hoveredIndex, _) {
                                          final isHovered = hoveredIndex == i ||
                                              (_activePopoverController != null && _popoverRowIndex == i);
                                          return _buildInstrumentCell(
                                            order, theme, uniqueId, actionHandler, isHovered,
                                            rowIndex: i,
                                          );
                                        },
                                      ),
                                    ),
                                    // Column 4: Product
                                    buildCellWithHover(
                                      rowIndex: i,
                                      columnIndex: 4,
                                      alignRight: true,
                                      onTap: () => actionHandler.openOrderDetail(order),
                                      child: Text(
                                        order.sPrdtAli ?? order.prd ?? '',
                                        style: _getTextStyle(context),
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                      ),
                                    ),
                                    // Column 5: Qty.
                                    buildCellWithHover(
                                      rowIndex: i,
                                      columnIndex: 5,
                                      alignRight: true,
                                      onTap: () => actionHandler.openOrderDetail(order),
                                      child: Text(
                                        _formatOrderQty(order),
                                        style: _getTextStyle(context),
                                      ),
                                    ),
                                    // Column 6: LTP
                                    buildCellWithHover(
                                      rowIndex: i,
                                      columnIndex: 6,
                                      alignRight: true,
                                      onTap: () => actionHandler.openOrderDetail(order),
                                      child: _OrderLTPCell(
                                        token: order.token ?? '',
                                        initialLtp: CellFormatters.getValidLTP(order),
                                        trantype: order.trantype ?? 'B',
                                        orderPrice: order.prc ?? '0',
                                      ),
                                    ),
                                    // Column 7: Price
                                    buildCellWithHover(
                                      rowIndex: i,
                                      columnIndex: 7,
                                      alignRight: true,
                                      onTap: () => actionHandler.openOrderDetail(order),
                                      child: Text(
                                        CellFormatters.getValidPrice(order),
                                        style: _getTextStyle(context),
                                      ),
                                    ),
                                    // Column 8: Status
                                    buildCellWithHover(
                                      rowIndex: i,
                                      columnIndex: 8,
                                      alignRight: true,
                                      onTap: () => actionHandler.openOrderDetail(order),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(CellFormatters.getStatusText(order))
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          CellFormatters.getStatusText(order).toUpperCase(),
                                          style: MyntWebTextStyles.para(
                                            context,
                                            color: _getStatusColor(CellFormatters.getStatusText(order)),
                                            fontWeight: MyntFonts.medium,
                                          ),
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
                ),
              );
            }
        
            // Add horizontal scroll when table is wider than available space
            if (needsHorizontalScroll) {
              return RawScrollbar(
                controller: widget.horizontalScrollController,
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
                child: SingleChildScrollView(
                  controller: widget.horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: actualTotalWidth,
                    child: buildTableContent(),
                  ),
                ),
              );
            }
        
            return buildTableContent();
        
            // Old horizontal scroll wrapper (commented out):
            // final totalRequiredWidth = columnWidths.values
            //     .fold<double>(0.0, (sum, width) => sum + width);
            // final needsHorizontalScroll = totalRequiredWidth > availableWidth;
            // if (needsHorizontalScroll) {
            //   return RawScrollbar(
            //     controller: widget.horizontalScrollController,
            //     thumbVisibility: true,
            //     trackVisibility: true,
            //     trackColor: resolveThemeColor(context,
            //         dark: Colors.grey.withValues(alpha: 0.1),
            //         light: Colors.grey.withValues(alpha: 0.1)),
            //     thumbColor: resolveThemeColor(context,
            //         dark: Colors.grey.withValues(alpha: 0.3),
            //         light: Colors.grey.withValues(alpha: 0.3)),
            //     thickness: 6,
            //     radius: const Radius.circular(3),
            //     interactive: true,
            //     child: SingleChildScrollView(
            //       controller: widget.horizontalScrollController,
            //       scrollDirection: Axis.horizontal,
            //       child: SizedBox(
            //         width: totalRequiredWidth,
            //         child: buildTableContent(),
            //       ),
            //     ),
            //   );
            // }
          },
        ),
      );
    
  }

  Widget _buildInstrumentCell(
    OrderBookModel order,
    ThemesProvider theme,
    String uniqueId,
    OrderActionHandler actionHandler,
    bool isHovered, {
    int? rowIndex,
  }) {
    final isPending = order.status == "PENDING" ||
        order.status == "OPEN" ||
        order.status == "TRIGGER_PENDING";

    // Format instrument: remove "-EQ" and don't include exchange
    final symbol = order.tsym ?? '';
    final displayText = symbol.replaceAll("-EQ", "").trim();

    return GestureDetector(
      onTap: () => actionHandler.openOrderDetail(order),
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
                    '$displayText${order.exch != null && order.exch!.isNotEmpty ? ' ${order.exch}' : ''}',
                child: Padding(
                  padding: EdgeInsets.only(right: isHovered ? 105.0 : 0.0),
                  child: RichText(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                    text: TextSpan(
                      children: [
                        // Symbol (14px, 500)
                        TextSpan(
                          text: displayText,
                          style: _getTextStyle(context),
                        ),
                        // Exchange (10px, 500, muted color) - matching positions table style
                        if (order.exch != null && order.exch!.isNotEmpty)
                          TextSpan(
                            text: ' ${order.exch}',
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
            // Cancel/Exit button + 3-dot menu button (appears on hover)
            if (isHovered)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Modify button
                      if (isPending)
                        _buildModifyButton(order, uniqueId, actionHandler),
                      if (isPending)
                        const SizedBox(width: 6),
                      // Cancel/Exit button (X icon) - only for pending/open orders
                      if (isPending)
                        _buildCancelExitButton(order, uniqueId, actionHandler),
                      if (isPending)
                        const SizedBox(width: 6),
                      // 3-dot menu button
                      _buildOptionsMenuButton(
                        order,
                        uniqueId,
                        actionHandler,
                        isPending,
                        rowIndex: rowIndex,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build Cancel/Exit button with X icon (tertiary/loss color)
  Widget _buildCancelExitButton(
    OrderBookModel order,
    String uniqueId,
    OrderActionHandler actionHandler,
  ) {
    final isBOCO = (order.sPrdtAli == "BO" || order.sPrdtAli == "CO") &&
        order.snonum != null;
    final isProcessing = _processingOrderToken == uniqueId &&
        (isBOCO ? _isProcessingExit : _isProcessingCancel);

    return GestureDetector(
      onTap: isProcessing
          ? null
          : () async {
              setState(() {
                _processingOrderToken = uniqueId;
              });
              if (isBOCO) {
                // Exit BO/CO order
                await actionHandler.exitBOCOOrder(
                  order,
                  onProcessingStateChanged: (processing) {
                    setState(() {
                      _isProcessingExit = processing;
                      if (!processing) _processingOrderToken = null;
                    });
                  },
                );
              } else {
                // Cancel regular order
                await actionHandler.cancelOrder(
                  order,
                  onProcessingStateChanged: (processing) {
                    setState(() {
                      _isProcessingCancel = processing;
                      if (!processing) _processingOrderToken = null;
                    });
                  },
                );
              }
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
        child: Icon(
          Icons.close,
          size: 16,
           fontWeight: FontWeight.bold,
          color: resolveThemeColor(context,
              dark: MyntColors.lossDark, light: MyntColors.loss),
        ),
      ),
    );
  }

  // Build Modify button with edit icon
  Widget _buildModifyButton(
    OrderBookModel order,
    String uniqueId,
    OrderActionHandler actionHandler,
  ) {
    final isProcessing =
        _processingOrderToken == uniqueId && _isProcessingModify;

    return GestureDetector(
      onTap: isProcessing
          ? null
          : () async {
              // Close menu if open
              _closePopover();
              setState(() {
                _processingOrderToken = uniqueId;
              });
              await actionHandler.modifyOrder(
                order,
                onProcessingStateChanged: (processing) {
                  setState(() {
                    _isProcessingModify = processing;
                    if (!processing) _processingOrderToken = null;
                  });
                },
                modifyDialogPosition: _modifyDialogPosition,
                onPositionChanged: (pos) {
                  _modifyDialogPosition = pos;
                },
              );
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
        child: Icon(
          Icons.edit_outlined,
          size: 16,
          color: resolveThemeColor(context,
              dark: MyntColors.primaryDark, light: MyntColors.primary),
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
    OrderBookModel order,
    String uniqueId,
    OrderActionHandler actionHandler,
    bool isPending, {
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
            // Build menu items dynamically based on order state
            List<shadcn.MenuItem> menuItems = [];

            // Modify option (only for pending orders)
            if (isPending) {
              final isProcessing =
                  _processingOrderToken == uniqueId && _isProcessingModify;
              menuItems.add(
                _buildMenuButton(
                  icon: Icons.edit_outlined,
                  title: 'Modify',
                  iconColor: iconColor,
                  textColor: textColor,
                  onPressed: isProcessing
                      ? (_) {}
                      : (ctx) async {
                          _closePopover();
                          setState(() {
                            _processingOrderToken = uniqueId;
                          });
                          await actionHandler.modifyOrder(
                            order,
                            onProcessingStateChanged: (processing) {
                              setState(() {
                                _isProcessingModify = processing;
                                if (!processing) _processingOrderToken = null;
                              });
                            },
                            modifyDialogPosition: _modifyDialogPosition,
                            onPositionChanged: (pos) {
                              _modifyDialogPosition = pos;
                            },
                          );
                        },
                ),
              );
            }

            // Repeat option (always available)
            menuItems.add(
              _buildMenuButton(
                icon: Icons.replay,
                title: 'Repeat',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  actionHandler.repeatOrder(order);
                },
              ),
            );

            // Add divider before info
            menuItems.add(const shadcn.MenuDivider());

            // Info option (always available)
            menuItems.add(
              _buildMenuButton(
                icon: Icons.info_outline,
                title: 'Info',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  actionHandler.openOrderDetail(order);
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

  // Build select header cell with checkbox
  shadcn.TableCell _buildSelectHeaderCell(
    OrderProvider orderBook,
    List<OrderBookModel> filteredOrders,
  ) {
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
      child: ClipRect(
        child: Consumer(
          builder: (context, ref, child) {
            final isExitAllOrder =
                ref.watch(orderProvider.select((p) => p.isExitAllOrder));
            final hasPendingOrders = filteredOrders.any((o) {
              final status = o.status?.toUpperCase() ?? '';
              return status == 'PENDING' ||
                  status == 'OPEN' ||
                  status == 'TRIGGER_PENDING';
            });
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.cardDark,
                  light: MyntColors.listItemBg,
                ),
              ),
              child: shadcn.Theme(
                data: shadcn.Theme.of(context).copyWith(
                  colorScheme: () {
                    return shadcn.Theme.of(context).colorScheme.copyWith(
                      border: () => resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark.withValues(alpha: 0.3),
                          light: MyntColors.textSecondary.withValues(alpha: 0.3)),
                    );
                  },
                ),
                child: shadcn.Checkbox(
                  state: isExitAllOrder
                      ? shadcn.CheckboxState.checked
                      : shadcn.CheckboxState.unchecked,
                  onChanged: hasPendingOrders
                      ? (state) {
                          orderBook.selectExitAllOrders(
                              state == shadcn.CheckboxState.checked);
                        }
                      : null,
                  enabled: hasPendingOrders,
                  activeColor: resolveThemeColor(
                    context,
                    dark: MyntColors.secondary,
                    light: MyntColors.primary,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  size: 18,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Build checkbox cell for each row
  Widget _buildCheckboxCell(
    OrderBookModel order,
    OrderProvider orderBook,
    int index,
    bool isPending,
  ) {
    return Consumer(
      builder: (context, ref, child) {
        final orderBook = ref.watch(orderProvider);
        final openOrders = orderBook.openOrder ?? [];
        final orderIndex = openOrders.indexWhere(
            (o) => o.norenordno == order.norenordno);
        final isSelected = orderIndex >= 0
            ? (openOrders[orderIndex].isExitSelection ?? false)
            : (order.isExitSelection ?? false);

        return Align(
          alignment: Alignment.centerLeft,
          child: shadcn.Theme(
            data: shadcn.Theme.of(context).copyWith(
              colorScheme: () {
                return shadcn.Theme.of(context).colorScheme.copyWith(
                  border: () => resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark.withValues(alpha: 0.3),
                      light: MyntColors.textSecondary.withValues(alpha: 0.3)),
                );
              },
            ),
            child: shadcn.Checkbox(
              state: isSelected
                  ? shadcn.CheckboxState.checked
                  : shadcn.CheckboxState.unchecked,
              onChanged: !isPending
                  ? null
                  : (state) {
                      if (orderIndex >= 0) {
                        orderBook.selectExitOrder(orderIndex);
                      }
                    },
              enabled: isPending,
              activeColor: resolveThemeColor(
                context,
                dark: MyntColors.secondary,
                light: MyntColors.primary,
              ),
              borderRadius: BorderRadius.circular(4),
              size: 18,
            ),
          ),
        );
      },
    );
  }
}

// Action button widget

// LTP Cell with WebSocket updates (default text color)
class _OrderLTPCell extends ConsumerStatefulWidget {
  final String token;
  final String initialLtp;
  final String trantype;
  final String orderPrice;

  const _OrderLTPCell({
    required this.token,
    required this.initialLtp,
    required this.trantype,
    required this.orderPrice,
  });

  @override
  ConsumerState<_OrderLTPCell> createState() => _OrderLTPCellState();
}

class _OrderLTPCellState extends ConsumerState<_OrderLTPCell> {
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
    return Text(
      ltp,
      style: MyntWebTextStyles.tableCell(
        context,
        darkColor: MyntColors.textPrimaryDark,
        lightColor: MyntColors.textPrimary,
        fontWeight: MyntFonts.medium,
      ),
    );
  }
}
