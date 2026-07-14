import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';

import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../refactored/services/order_action_handler.dart';

/// Separate screen widget for Executed Orders tab
class ExecutedOrdersScreen extends ConsumerStatefulWidget {
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;

  const ExecutedOrdersScreen({
    super.key,
    required this.horizontalScrollController,
    required this.verticalScrollController,
  });

  @override
  ConsumerState<ExecutedOrdersScreen> createState() =>
      _ExecutedOrdersScreenState();
}

class _ExecutedOrdersScreenState extends ConsumerState<ExecutedOrdersScreen> {
  // PERFORMANCE FIX: Use ValueNotifier for hover instead of setState
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);
  int? _sortColumnIndex;
  bool _sortAscending = true;
  bool _isProcessingCancel = false;
  bool _isProcessingModify = false;
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

  // Column definitions - 8 columns
  // Headers: Time | Type | Instrument | Product | Qty. | LTP | Avg. price | Status
  final List<String> _columns = [
    'Time',        // 0
    'Type',        // 1 - BUY/SELL (trantype)
    'Instrument',  // 2
    'Product',     // 3
    'Qty.',        // 4
    'LTP',         // 5
    'Avg. price',  // 6
    'Status',      // 7
  ];

  // Old column definitions (commented out)
  // final List<String> _columnsOld = [
  //   'Time',
  //   'Instrument',
  //   'Product',
  //   'Type',          // prctyp - LMT/MKT etc
  //   'Side',          // BUY/SELL
  //   'Qty',
  //   'Avg price',
  //   'LTP',
  //   'Price',
  //   'Trigger price',
  //   'Status',
  // ];

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    // Selective watches — only rebuild when relevant data changes
    final executedOrder = ref.watch(orderProvider.select((p) => p.executedOrder));
    final orderSearchItem = ref.watch(orderProvider.select((p) => p.orderSearchItem));
    final isLoading = ref.watch(orderProvider.select((p) => p.loading));
    final selectedTab = ref.watch(orderProvider.select((p) => p.selectedTab));
    final orderBook = ref.read(orderProvider);

    // Get executed orders (search or regular)
    // Only show search results if we're on the Executed Orders tab (index 1)
    final searchQuery = orderBook.orderSearchCtrl.text.trim();
    final isExecutedOrdersTab = selectedTab == 1;
    final orders = (searchQuery.isNotEmpty && isExecutedOrdersTab)
        ? (orderSearchItem ?? [])
        : (executedOrder ?? []);

    // Sort orders (only if not empty)
    final sortedOrders = orders.isNotEmpty ? _getSortedOrders(orders) : <OrderBookModel>[];

    return SizedBox.expand(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: shadcn.OutlinedContainer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate proportional column widths for 8 columns
              final availableWidth = constraints.maxWidth;

              // Minimum column widths to prevent overflow
              const minTimeWidth = 80.0;
              const minTypeWidth = 60.0;
              const minInstrumentWidth = 180.0;
              const minProductWidth = 70.0;
              const minQtyWidth = 80.0;
              const minLtpWidth = 80.0;
              const minAvgPriceWidth = 80.0;
              const minStatusWidth = 100.0;

              // Total minimum width required
              const totalMinWidth = minTimeWidth +
                  minTypeWidth +
                  minInstrumentWidth +
                  minProductWidth +
                  minQtyWidth +
                  minLtpWidth +
                  minAvgPriceWidth +
                  minStatusWidth;

              // Check if we need horizontal scroll
              final needsHorizontalScroll = availableWidth < totalMinWidth;
              final effectiveWidth = needsHorizontalScroll ? totalMinWidth : availableWidth;

              // Proportional widths for columns (total = 100%)
              // Time: 12%, Type: 8%, Instrument: 24%, Product: 8%, Qty: 12%, LTP: 11%, Avg. price: 12%, Status: 13%
              final timeWidth = (effectiveWidth * 0.12).clamp(minTimeWidth, double.infinity);
              final typeWidth = (effectiveWidth * 0.08).clamp(minTypeWidth, double.infinity);
              final instrumentWidth = (effectiveWidth * 0.24).clamp(minInstrumentWidth, double.infinity);
              final productWidth = (effectiveWidth * 0.08).clamp(minProductWidth, double.infinity);
              final qtyWidth = (effectiveWidth * 0.12).clamp(minQtyWidth, double.infinity);
              final ltpWidth = (effectiveWidth * 0.11).clamp(minLtpWidth, double.infinity);
              final avgPriceWidth = (effectiveWidth * 0.12).clamp(minAvgPriceWidth, double.infinity);
              final statusWidth = (effectiveWidth * 0.13).clamp(minStatusWidth, double.infinity);

              // Actual total width after clamping (may exceed totalMinWidth due to clamp bump-ups)
              final actualTotalWidth = timeWidth + typeWidth + instrumentWidth +
                  productWidth + qtyWidth + ltpWidth + avgPriceWidth + statusWidth;

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
                      // Fixed Header
                      shadcn.Table(
                        columnWidths: {
                          0: shadcn.FixedTableSize(timeWidth),
                          1: shadcn.FixedTableSize(typeWidth),
                          2: shadcn.FixedTableSize(instrumentWidth),
                          3: shadcn.FixedTableSize(productWidth),
                          4: shadcn.FixedTableSize(qtyWidth),
                          5: shadcn.FixedTableSize(ltpWidth),
                          6: shadcn.FixedTableSize(avgPriceWidth),
                          7: shadcn.FixedTableSize(statusWidth),
                        },
                        defaultRowHeight: const shadcn.FixedTableSize(40),
                        rows: [
                          shadcn.TableHeader(
                            cells: [
                              buildHeaderCell('Time', 0),
                              buildHeaderCell('Type', 1),
                              buildHeaderCell('Instrument', 2),
                              buildHeaderCell('Product', 3, true),
                              buildHeaderCell('Qty.', 4, true),
                              buildHeaderCell('LTP', 5, true),
                              buildHeaderCell('Avg. price', 6, true),
                              buildHeaderCell('Status', 7, true),
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
                                            ? "No executed orders match your search \"$searchQuery\"."
                                            : "You don't have any executed orders yet.",
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
                            itemBuilder: (context, index) {
                              final order = sortedOrders[index];
                              final uniqueId = order.norenordno?.toString() ?? order.token?.toString() ?? '';
                              final actionHandler = OrderActionHandler(ref: ref, context: context);
                              return shadcn.Table(
                                columnWidths: {
                                  0: shadcn.FixedTableSize(timeWidth),
                                  1: shadcn.FixedTableSize(typeWidth),
                                  2: shadcn.FixedTableSize(instrumentWidth),
                                  3: shadcn.FixedTableSize(productWidth),
                                  4: shadcn.FixedTableSize(qtyWidth),
                                  5: shadcn.FixedTableSize(ltpWidth),
                                  6: shadcn.FixedTableSize(avgPriceWidth),
                                  7: shadcn.FixedTableSize(statusWidth),
                                },
                                defaultRowHeight: const shadcn.FixedTableSize(40),
                                rows: [
                                  shadcn.TableRow(
                                    cells: [
                                      // Time (with seconds)
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 0,
                                        onTap: () => actionHandler.openOrderDetail(order),
                                        child: Text(
                                          _formatTime(order.norentm ?? '0.00'),
                                          style: _getTextStyle(context),
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                        ),
                                      ),
                                      // Type (BUY/SELL)
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 1,
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
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                        ),
                                      ),
                                      // Instrument with action buttons on hover
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 2,
                                        child: ValueListenableBuilder<int?>(
                                          valueListenable: _hoveredRowIndex,
                                          builder: (context, hoveredIndex, _) {
                                            final isHovered = hoveredIndex == index ||
                                                (_activePopoverController != null && _popoverRowIndex == index);
                                            return _buildInstrumentCell(
                                              order, theme, uniqueId, actionHandler, isHovered,
                                              rowIndex: index,
                                            );
                                          },
                                        ),
                                      ),
                                      // Product
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 3,
                                        alignRight: true,
                                        onTap: () => actionHandler.openOrderDetail(order),
                                        child: Text(
                                          order.sPrdtAli ?? order.prd ?? '',
                                          style: _getTextStyle(context),
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                        ),
                                      ),
                                      // Qty.
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 4,
                                        alignRight: true,
                                        onTap: () => actionHandler.openOrderDetail(order),
                                        child: Text(
                                          _formatQty(order),
                                          style: _getTextStyle(context),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // LTP
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 5,
                                        alignRight: true,
                                        onTap: () => actionHandler.openOrderDetail(order),
                                        child: _OrderBookLTPCell(
                                          token: order.token ?? '',
                                          initialLtp: _getValidLTP(order),
                                          order: order,
                                        ),
                                      ),
                                      // Avg. price
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 6,
                                        alignRight: true,
                                        onTap: () => actionHandler.openOrderDetail(order),
                                        child: Text(
                                          order.avgprc ?? '0.00',
                                          style: _getTextStyle(context),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Status
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 7,
                                        alignRight: true,
                                        onTap: () => actionHandler.openOrderDetail(order),
                                        child: Tooltip(
                                          message: (order.rejreason != null && order.rejreason!.isNotEmpty)
                                              ? order.rejreason!
                                              : _getStatusText(order),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(_getStatusText(order), context)
                                                  .withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _getStatusText(order).toUpperCase(),
                                              style: MyntWebTextStyles.para(
                                                context,
                                                color: _getStatusColor(_getStatusText(order), context),
                                                fontWeight: MyntFonts.medium,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              softWrap: false,
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
            },
          ),
        ),
      ),
    );
  }

  // Builds a cell with hover detection (matches positions pattern)
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    VoidCallback? onTap,
  }) {
    final isFirstColumn = columnIndex == 0; // Time column
    final isInstrumentColumn = columnIndex == 2; // Instrument column
    final isLastColumn = columnIndex == 7; // Status column

    // Match the cell padding logic
    EdgeInsets cellPadding;
    if (isFirstColumn) {
      cellPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    } else if (isInstrumentColumn) {
      cellPadding = const EdgeInsets.fromLTRB(16, 4, 4, 4);
    } else if (isLastColumn) {
      cellPadding = const EdgeInsets.fromLTRB(4, 4, 16, 4);
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

  // Builds a sortable header cell with sort indicator (matches holdings pattern)
  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0; // Time column
    final isInstrumentColumn = columnIndex == 2; // Instrument column
    final isLastColumn = columnIndex == 7; // Status column

    // Match the cell padding logic
    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6);
    } else if (isInstrumentColumn) {
      headerPadding = const EdgeInsets.fromLTRB(16, 6, 4, 6);
    } else if (isLastColumn) {
      headerPadding = const EdgeInsets.fromLTRB(4, 6, 16, 6);
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
    final displayText = _formatInstrumentText(order);

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
                  padding: EdgeInsets.only(right: isHovered ? 70.0 : 0.0),
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
            // Cancel button + 3-dot menu button (appears on hover)
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
                      // Cancel button (X icon) - only for pending/open orders
                      if (isPending)
                        _buildCancelButton(order, uniqueId, actionHandler),
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

  // Build Cancel button with X icon (tertiary/loss color) - matches positions Exit button
  Widget _buildCancelButton(
    OrderBookModel order,
    String uniqueId,
    OrderActionHandler actionHandler,
  ) {
    final isProcessing = _processingOrderToken == uniqueId && _isProcessingCancel;

    return GestureDetector(
      onTap: isProcessing
          ? null
          : () async {
              setState(() {
                _processingOrderToken = uniqueId;
              });
              await actionHandler.cancelOrder(
                order,
                onProcessingStateChanged: (processing) {
                  setState(() {
                    _isProcessingCancel = processing;
                    if (!processing) _processingOrderToken = null;
                  });
                },
              );
            },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: MyntColors.loss.withValues(alpha: 0.15),
              light: MyntColors.loss.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.close,
          size: 16,
          color: resolveThemeColor(context,
              dark: MyntColors.lossDark, light: MyntColors.loss),
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

  List<OrderBookModel> _getSortedOrders(List<OrderBookModel> orders) {
    if (_sortColumnIndex == null) return orders;

    final sorted = List<OrderBookModel>.from(orders);

    sorted.sort((a, b) {
      int comparison = 0;

      switch (_sortColumnIndex!) {
        case 0: // Time
          // Parse to a real DateTime — the raw "HH:mm:ss dd-MM-yyyy" string
          // compares by clock only and mis-orders across dates (AMO orders).
          final aDate = _tryParseOrderTime(a.norentm);
          final bDate = _tryParseOrderTime(b.norentm);
          if (aDate != null && bDate != null) {
            comparison = aDate.compareTo(bDate);
          } else if (aDate == null && bDate == null) {
            comparison = (a.norentm ?? '').compareTo(b.norentm ?? '');
          } else {
            comparison = aDate == null ? 1 : -1;
          }
          break;
        case 1: // Type (BUY/SELL)
          comparison = (a.trantype ?? '').compareTo(b.trantype ?? '');
          break;
        case 2: // Instrument
          comparison =
              (_formatInstrumentText(a)).compareTo(_formatInstrumentText(b));
          break;
        case 3: // Product
          comparison =
              (a.sPrdtAli ?? a.prd ?? '').compareTo(b.sPrdtAli ?? b.prd ?? '');
          break;
        case 4: // Qty
          comparison = (int.tryParse(a.qty ?? '0') ?? 0)
              .compareTo(int.tryParse(b.qty ?? '0') ?? 0);
          break;
        case 5: // LTP
          comparison = (double.tryParse(a.ltp ?? '0') ?? 0.0)
              .compareTo(double.tryParse(b.ltp ?? '0') ?? 0.0);
          break;
        case 6: // Avg price
          comparison = (double.tryParse(a.avgprc ?? '0') ?? 0.0)
              .compareTo(double.tryParse(b.avgprc ?? '0') ?? 0.0);
          break;
        case 7: // Status
          comparison = (a.status ?? '').compareTo(b.status ?? '');
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  String _formatInstrumentText(OrderBookModel order) {
    // Prefer the backend display name (DerivativeMaster) for derivatives.
    final master = order.masterName;
    if (master != null && master.isNotEmpty) return master;
    if (order.tsym != null && order.tsym!.isNotEmpty) {
      // Remove "-EQ" suffix and don't include exchange
      return order.tsym!.replaceAll("-EQ", "").trim();
    } else if (order.dname != null && order.dname!.isNotEmpty) {
      return order.dname!.replaceAll("-EQ", "").trim();
    }
    return 'N/A';
  }

  // Format Qty as "filledQty / totalQty" - for MCX, divide by lot size
  String _formatQty(OrderBookModel order) {
    final rawFilled = int.tryParse(order.fillshares ?? '0') ?? 0;
    final rawQty = int.tryParse(order.qty ?? '0') ?? 0;
    final lotSize = order.exch == 'MCX'
        ? (int.tryParse(order.ls ?? '1') ?? 1)
        : 1;
    final filledQty = rawFilled ~/ lotSize;
    final totalQty = rawQty ~/ lotSize;
    return '$filledQty / $totalQty';
  }

  String _getValidLTP(OrderBookModel order) {
    if (order.ltp != null && order.ltp != '0' && order.ltp != '0.00') {
      return order.ltp!;
    }
    return '0.00';
  }

  // COMMENTED OUT - Kept for reference
  // String _getValidPrice(OrderBookModel order) {
  //   if (order.prc != null && order.prc != '0' && order.prc != '0.00') {
  //     return order.prc!;
  //   }
  //   return '0.00';
  // }

  String _getStatusText(OrderBookModel order) {
    if (order.status == null) return 'N/A';

    final status = order.status!.toUpperCase();
    if (status == 'COMPLETE') return 'Executed';
    if (status == 'REJECTED') return 'Rejected';
    if (status == 'CANCELED' || status == 'CANCELLED') return 'Cancelled';
    if (status == 'OPEN') return 'Open';
    if (status == 'PENDING') return 'Pending';
    if (status == 'TRIGGER_PENDING') return 'Trigger Pending';

    return order.status!;
  }

  // Parses the API's "HH:mm:ss dd-MM-yyyy" order timestamp into a DateTime.
  // Returns null for empty/unexpected values so callers can fall back safely.
  DateTime? _tryParseOrderTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(' ');
    if (parts.length != 2) return null;
    final dateParts = parts[1].split('-');
    if (dateParts.length != 3) return null;
    return DateTime.tryParse(
        '${dateParts[2]}-${dateParts[1]}-${dateParts[0]} ${parts[0]}');
  }

  // Format time with seconds (e.g., "11:18:07")
  String _formatTime(String time) {
    if (time.isEmpty || time == '0.00') return 'N/A';

    // Try parsing "HH:mm:ss dd-MM-yyyy" format (API format) with seconds
    try {
      if (time.contains(':') && time.contains('-')) {
        // Format: "HH:mm:ss dd-MM-yyyy"
        final timePart = time.split(' ')[0]; // Get "HH:mm:ss"
        return timePart; // Return time with seconds as-is
      }
    } catch (e) {
      // Continue to fallback
    }

    // Fallback: Try parsing as simple time string (HHMMSS or HHMM)
    try {
      if (time.length >= 6 && !time.contains(':')) {
        // Format: "HHMMSS" to "HH:MM:SS"
        final hours = time.substring(0, 2);
        final minutes = time.substring(2, 4);
        final seconds = time.substring(4, 6);
        return '$hours:$minutes:$seconds';
      } else if (time.length >= 4 && !time.contains(':')) {
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

  Color _getStatusColor(String statusText, BuildContext context) {
    switch (statusText.toUpperCase()) {
      case 'EXECUTED':
      case 'COMPLETE':
        return resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
      case 'REJECTED':
      case 'CANCELLED':
      case 'CANCELED':
        return resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);
      case 'OPEN':
      case 'PENDING':
      case 'TRIGGER PENDING':
        return resolveThemeColor(context,
            dark: MyntColors.warning, light: MyntColors.warning);
      default:
        return resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary);
    }
  }
}

// Live LTP cell widget with websocket updates
class _OrderBookLTPCell extends ConsumerStatefulWidget {
  final String token;
  final String initialLtp;
  final OrderBookModel order;

  const _OrderBookLTPCell({
    required this.token,
    required this.initialLtp,
    required this.order,
  });

  @override
  ConsumerState<_OrderBookLTPCell> createState() => _OrderBookLTPCellState();
}

class _OrderBookLTPCellState extends ConsumerState<_OrderBookLTPCell> {
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

      // Check existing socket data first (token might already be subscribed via watchlist)
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
