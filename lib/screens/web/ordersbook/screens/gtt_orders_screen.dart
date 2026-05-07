import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart'
    show
        InkWell,
        Icons,
        IconData,
        VoidCallback,
        Icon,
        TextPainter,
        TextSpan,
        TextStyle,
        TextDirection,
        GestureDetector,
        HitTestBehavior,
        Row,
        SizedBox,
        Colors,
        Widget,
        BuildContext,
        Builder,
        Color,
        EdgeInsets,
        Alignment,
        MainAxisAlignment,
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
        ValueKey,
        Padding,
        LayoutBuilder,
        Center,
        BorderRadius,
        BoxDecoration,
        MainAxisSize,
        Dialog,
        Material,
        Navigator,
        TextButton,
        showDialog,
        RoundedRectangleBorder,
        TextAlign,
        Stack,
        LinearGradient,
        Clip,
        Tooltip,
        RichText,
        Positioned,
        BoxShadow,
        Offset,
        FontWeight,
        Radius,
        RawScrollbar,
        ListView,
        MediaQuery,
        ValueNotifier,
        ValueListenableBuilder;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn
    hide Colors, Tooltip;
import 'package:mynt_plus/models/order_book_model/gtt_order_book.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/provider/market_watch_provider.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/hover_actions_web.dart';
import '../refactored/utils/cell_formatters.dart';
import '../gtt_order_book_detail_screen_web.dart';
import '../modify_gtt_web.dart';

/// Separate screen widget for GTT Orders tab
class GttOrdersScreen extends ConsumerStatefulWidget {
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;

  const GttOrdersScreen({
    super.key,
    required this.horizontalScrollController,
    required this.verticalScrollController,
  });

  @override
  ConsumerState<GttOrdersScreen> createState() => _GttOrdersScreenState();
}

class _GttOrdersScreenState extends ConsumerState<GttOrdersScreen> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  // PERFORMANCE FIX: Use ValueNotifier for hover instead of setState
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);
  bool _isProcessingCancel = false;
  bool _isProcessingModify = false;
  String? _processingOrderToken;

  // Scroll controllers - must be in state to persist across rebuilds
  late ScrollController _verticalScrollController;
  late ScrollController _horizontalScrollController;

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

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final orderBook = ref
        .watch(orderProvider); // Changed to watch to rebuild on search changes

    final showTriggered = orderBook.showTriggeredGtt;

    // Get GTT orders (search or regular)
    // Only show search results if we're on the GTT Orders tab (index 3)
    final searchQuery = orderBook.orderSearchCtrl.text.trim();
    final isGttOrdersTab = orderBook.selectedTab == 3;

    final List<GttOrderBookModel> gttOrders;
    if (showTriggered) {
      gttOrders = orderBook.triggeredGttOrders ?? [];
    } else {
      gttOrders = (searchQuery.isNotEmpty && isGttOrdersTab)
          ? (orderBook.gttOrderBookSearch ?? [])
          : (orderBook.gttOrderBookModel ?? []);
    }

    // Sort GTT orders - handle empty case for showing header always
    final sortedOrders = gttOrders.isNotEmpty
        ? _getSortedGttOrders(gttOrders)
        : <GttOrderBookModel>[];

    return Column(
      children: [
        // Pending / Triggered toggle bar
        _buildGttToggleBar(context, orderBook),
        Expanded(child: shadcn.OutlinedContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate minimum widths dynamically based on actual content
          final minWidths = _calculateMinWidths(sortedOrders, context);

          // Available width
          final availableWidth = constraints.maxWidth;

          // Step 1: Start with minimum widths (content-based, no wasted space)
          // 7 columns: Created on, Instrument, Type, Trigger, LTP, Qty., Status
          final columnWidths = <int, double>{};
          for (int i = 0; i < 7; i++) {
            columnWidths[i] = minWidths[i] ?? 100.0;
          }

          // Step 2: Calculate total minimum width needed
          final totalMinWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);

          // Step 3: If there's extra space, distribute it proportionally
          // 7 columns: Created on, Instrument, Type, Trigger, LTP, Qty., Status
          if (totalMinWidth < availableWidth) {
            final extraSpace = availableWidth - totalMinWidth;

            const instrumentGrowthFactor = 2.0; // Instrument can grow 2x more than numeric
            const textGrowthFactor = 1.2;
            const numericGrowthFactor = 1.0;

            final growthFactors = <int, double>{};
            double totalGrowthFactor = 0.0;

            for (int i = 0; i < 7; i++) {
              if (i == 1) {
                // Instrument
                growthFactors[i] = instrumentGrowthFactor;
                totalGrowthFactor += instrumentGrowthFactor;
              } else if (i == 0 || i == 2 || i == 6) {
                // Created on, Type, Status
                growthFactors[i] = textGrowthFactor;
                totalGrowthFactor += textGrowthFactor;
              } else {
                // Trigger, LTP, Qty.
                growthFactors[i] = numericGrowthFactor;
                totalGrowthFactor += numericGrowthFactor;
              }
            }

            if (totalGrowthFactor > 0) {
              for (int i = 0; i < 7; i++) {
                if (growthFactors[i]! > 0) {
                  final extraForThisColumn =
                      (extraSpace * growthFactors[i]!) / totalGrowthFactor;
                  columnWidths[i] = columnWidths[i]! + extraForThisColumn;
                }
              }
            }
          }

          final totalRequiredWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);
          final needsHorizontalScroll = totalRequiredWidth > availableWidth;

          Widget buildTableContent() {
            return Column(
              children: [
                // Fixed Header - 7 columns: Created on, Instrument, Type, Trigger, LTP, Qty., Status
                shadcn.Table(
                  columnWidths: {
                    0: shadcn.FixedTableSize(columnWidths[0]!),
                    1: shadcn.FixedTableSize(columnWidths[1]!),
                    2: shadcn.FixedTableSize(columnWidths[2]!),
                    3: shadcn.FixedTableSize(columnWidths[3]!),
                    4: shadcn.FixedTableSize(columnWidths[4]!),
                    5: shadcn.FixedTableSize(columnWidths[5]!),
                    6: shadcn.FixedTableSize(columnWidths[6]!),
                  },
                  defaultRowHeight: const shadcn.FixedTableSize(40),
                  rows: [
                    shadcn.TableHeader(
                      cells: [
                        buildHeaderCell('Created on', 0),
                        buildHeaderCell('Instrument', 1),
                        buildHeaderCell('Type', 2),
                        buildHeaderCell('Trigger', 3, true),
                        buildHeaderCell('LTP', 4, true),
                        buildHeaderCell('Qty.', 5, true),
                        buildHeaderCell('Status', 6,true),
                      ],
                    ),
                  ],
                ),
                // Scrollable Body - 7 columns: Created on, Instrument, Type, Trigger, LTP, Qty., Status
                Expanded(
                  child: sortedOrders.isEmpty
                      ? (orderBook.loading
                          ? Center(child: MyntLoader.simple())
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: NoDataFoundWeb(
                                  title: showTriggered
                                      ? "No Triggered GTT Orders"
                                      : (searchQuery.isNotEmpty
                                          ? "No GTT Orders Found"
                                          : "No GTT Orders"),
                                  subtitle: showTriggered
                                      ? "You don't have any triggered GTT orders yet."
                                      : (searchQuery.isNotEmpty
                                          ? "No GTT orders match your search \"$searchQuery\"."
                                          : "You don't have any GTT orders yet."),
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
                            itemCount: sortedOrders.length,
                            itemExtent: 42.0,
                            itemBuilder: (context, index) {
                              final gttOrder = sortedOrders[index];
                              return shadcn.Table(
                                columnWidths: {
                                  0: shadcn.FixedTableSize(columnWidths[0]!),
                                  1: shadcn.FixedTableSize(columnWidths[1]!),
                                  2: shadcn.FixedTableSize(columnWidths[2]!),
                                  3: shadcn.FixedTableSize(columnWidths[3]!),
                                  4: shadcn.FixedTableSize(columnWidths[4]!),
                                  5: shadcn.FixedTableSize(columnWidths[5]!),
                                  6: shadcn.FixedTableSize(columnWidths[6]!),
                                },
                                defaultRowHeight: const shadcn.FixedTableSize(40),
                                rows: [
                                  shadcn.TableRow(
                                    cells: [
                                      // Created on (date)
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 0,
                                        onTap: () => _showGttOrderDetail(gttOrder),
                                        child: Text(
                                          _formatCreatedDate(gttOrder),
                                          style: _getTextStyle(context),
                                        ),
                                      ),
                                      // Instrument
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 1,
                                        onTap: () => _showGttOrderDetail(gttOrder),
                                        child: ValueListenableBuilder<int?>(
                                          valueListenable: _hoveredRowIndex,
                                          builder: (context, hoveredIndex, _) {
                                            final isRowHovered = hoveredIndex == index ||
                                                (_activePopoverController != null && _popoverRowIndex == index);
                                            return _buildInstrumentCell(
                                                gttOrder, theme, isRowHovered,
                                                rowIndex: index);
                                          },
                                        ),
                                      ),
                                      // Type (SINGLE/OCO + BUY/SELL badges)
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 2,
                                        onTap: () => _showGttOrderDetail(gttOrder),
                                        child: _buildTypeCell(gttOrder),
                                      ),
                                      // Trigger (with percentage)
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 3,
                                        alignRight: true,
                                        onTap: () => _showGttOrderDetail(gttOrder),
                                        child: _buildTriggerCell(gttOrder),
                                      ),
                                      // LTP
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 4,
                                        alignRight: true,
                                        onTap: () => _showGttOrderDetail(gttOrder),
                                        child: _buildLTPCell(gttOrder, theme),
                                      ),
                                      // Qty.
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 5,
                                        alignRight: true,
                                        onTap: () => _showGttOrderDetail(gttOrder),
                                        child: Text(
                                          '${gttOrder.qty ?? 0}',
                                          style: _getTextStyle(context),
                                        ),
                                      ),
                                      // Status
                                      buildCellWithHover(
                                        rowIndex: index,
                                        columnIndex: 6,
                                        alignRight: true,
                                        onTap: () => _showGttOrderDetail(gttOrder),
                                        child: _buildStatusCell(gttOrder, theme),
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

          if (needsHorizontalScroll) {
            return RawScrollbar(
              controller: _horizontalScrollController,
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
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalRequiredWidth,
                  child: buildTableContent(),
                ),
              ),
            );
          }

          return buildTableContent();
        },
      ),
    )),
      ],
    );
  }

  /// Toggle bar for Pending / Triggered GTT orders
  Widget _buildGttToggleBar(BuildContext context, OrderProvider orderBook) {
    final showTriggered = orderBook.showTriggeredGtt;
    final theme = shadcn.Theme.of(context);
    final isDark = isDarkMode(context);

    Widget buildToggleButton(String label, bool isActive, VoidCallback onTap) {
      return MouseRegion(
        cursor: shadcn.SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: MyntWebTextStyles.body(
                context,
                fontWeight: isActive ? MyntFonts.semiBold : MyntFonts.medium,
              ).copyWith(
                color: isActive
                    ? theme.colorScheme.foreground
                    : theme.colorScheme.mutedForeground,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(right: 16, bottom: 6),
      child: Row(
        children: [
          buildToggleButton(
            'Pending',
            !showTriggered,
            () => ref.read(orderProvider).toggleTriggeredGtt(false, context),
          ),
          const SizedBox(width: 8),
          buildToggleButton(
            'Triggered',
            showTriggered,
            () => ref.read(orderProvider).toggleTriggeredGtt(true, context),
          ),
        ],
      ),
    );
  }

  // Builds a cell with hover detection
  // 7 columns: Created on, Instrument, Type, Trigger, LTP, Qty., Status
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    VoidCallback? onTap,
  }) {
    final isFirstColumn = columnIndex == 0; // Created on column
    final isInstrumentColumn = columnIndex == 1; // Instrument column
    final isLastColumn = columnIndex == 6; // Status column (7 columns, index 6)

    // Match the cell padding logic
    EdgeInsets cellPadding;
    if (isFirstColumn) {
      // First column - more left padding
      cellPadding = const EdgeInsets.fromLTRB(16, 4, 8, 4);
    } else if (isInstrumentColumn) {
      // Instrument column - symmetric padding
      cellPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    } else if (isLastColumn) {
      // Last column - more right padding
      cellPadding = const EdgeInsets.fromLTRB(8, 4, 16, 4);
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
        onEnter: (_) => _hoveredRowIndex.value = rowIndex,
        onExit: (_) => _hoveredRowIndex.value = null,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ValueListenableBuilder<int?>(
            valueListenable: _hoveredRowIndex,
            builder: (context, hoveredIndex, _) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                padding: cellPadding,
                alignment:
                    alignRight ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: hoveredIndex == rowIndex
                      ? resolveThemeColor(
                          context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
                        ).withValues(alpha: 0.08)
                      : Colors.transparent,
                ),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }

  // Builds a sortable header cell
  // 7 columns: Created on, Instrument, Type, Trigger, LTP, Qty., Status
  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0; // Created on column
    final isLastColumn = columnIndex == 6; // Status column (7 columns, index 6)

    // Match the cell padding logic
    EdgeInsets headerPadding;
    if (isFirstColumn) {
      // First column - more left padding
      headerPadding = const EdgeInsets.fromLTRB(16, 6, 8, 6);
    } else if (isLastColumn) {
      // Last column - more right padding
      headerPadding = const EdgeInsets.fromLTRB(8, 6, 16, 6);
    } else {
      // Other columns - symmetric padding
      headerPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
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

  // Calculate minimum column widths dynamically
  // 7 columns: Created on, Instrument, Type, Trigger, LTP, Qty., Status
  Map<int, double> _calculateMinWidths(
      List<GttOrderBookModel> gttOrders, BuildContext context) {
    // Use fixed font size for measurement (table text is not responsive, only buttons are)
    final textStyle = const TextStyle(fontSize: 14, fontFamily: 'Geist');
    const padding = 24.0;
    const sortIconWidth = 24.0;

    final headers = [
      'Created on',
      'Instrument',
      'Type',
      'Trigger',
      'LTP',
      'Qty.',
      'Status',
    ];
    final minWidths = <int, double>{};

    for (int col = 0; col < headers.length; col++) {
      double maxWidth = 0.0;
      final headerWidth = _measureTextWidth(headers[col], textStyle);
      maxWidth = headerWidth + sortIconWidth;

      for (final order in gttOrders.take(5)) {
        String cellText = '';
        switch (col) {
          case 0: // Created on
            cellText = _formatCreatedDate(order);
            break;
          case 1: // Instrument
            final symbol = (order.tsym ?? '').replaceAll("-EQ", "").trim();
            final exchange = order.exch ?? '';
            final exchangeText = exchange.isNotEmpty ? ' $exchange' : '';
            final symbolWidth = _measureTextWidth(symbol, textStyle);
            final exchangeStyle =
                const TextStyle(fontSize: 10, fontFamily: 'Geist');
            final exchangeWidth = exchangeText.isNotEmpty
                ? _measureTextWidth(exchangeText, exchangeStyle)
                : 0.0;
            final totalWidth = symbolWidth +
                exchangeWidth +
                (exchangeText.isNotEmpty ? 4.0 : 0.0);
            if (totalWidth > maxWidth) {
              maxWidth = totalWidth;
            }
            continue;
          case 2: // Type (SINGLE / BUY or OCO / SELL format)
            cellText = 'SINGLE / SELL'; // Approximate width
            break;
          case 3: // Trigger (with percentage)
            cellText = '${order.d ?? '0.00'} 100%';
            break;
          case 4: // LTP
            cellText = CellFormatters.getValidLTPForGtt(order);
            break;
          case 5: // Qty.
            cellText = (order.qty ?? 0).toString();
            break;
          case 6: // Status
            cellText = CellFormatters.getGttStatusText(
                order.gttOrderCurrentStatus?.toUpperCase() ?? '');
            break;
        }

        final cellWidth = _measureTextWidth(cellText, textStyle);
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }

      // Ensure minimum widths for specific columns
      if (headers[col] == 'Instrument') {
        const minInstrumentWidth = 150.0;
        maxWidth = maxWidth < minInstrumentWidth ? minInstrumentWidth : maxWidth;
      }

      minWidths[col] = maxWidth + padding;
    }

    return minWidths;
  }

  double _measureTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();
    return textPainter.width;
  }

  // Sort GTT orders based on 7 columns: Created on, Instrument, Type, Trigger, LTP, Qty., Status
  List<GttOrderBookModel> _getSortedGttOrders(List<GttOrderBookModel> orders) {
    if (_sortColumnIndex == null) return orders;

    final sorted = List<GttOrderBookModel>.from(orders);
    sorted.sort((a, b) {
      int comparison = 0;

      switch (_sortColumnIndex!) {
        case 0: // Created on - compare dates
          comparison = (a.ordDate ?? a.norentm ?? '')
              .compareTo(b.ordDate ?? b.norentm ?? '');
          break;
        case 1: // Instrument - compare symbol first, then exchange
          final aSymbol = (a.tsym ?? '').replaceAll("-EQ", "").trim();
          final bSymbol = (b.tsym ?? '').replaceAll("-EQ", "").trim();
          comparison = aSymbol.compareTo(bSymbol);
          if (comparison == 0) {
            comparison = (a.exch ?? '').compareTo(b.exch ?? '');
          }
          break;
        case 2: // Type - compare order type (SINGLE/OCO) then side (BUY/SELL)
          final aIsOco = a.placeOrderParamsLeg2 != null;
          final bIsOco = b.placeOrderParamsLeg2 != null;
          comparison = aIsOco.toString().compareTo(bIsOco.toString());
          if (comparison == 0) {
            comparison = (a.trantype ?? '').compareTo(b.trantype ?? '');
          }
          break;
        case 3: // Trigger - numeric comparison
          final aTrigger = double.tryParse(a.d ?? '0') ?? 0.0;
          final bTrigger = double.tryParse(b.d ?? '0') ?? 0.0;
          comparison = aTrigger.compareTo(bTrigger);
          break;
        case 4: // LTP - numeric comparison
          final aLtp = double.tryParse(a.ltp ?? '0') ?? 0.0;
          final bLtp = double.tryParse(b.ltp ?? '0') ?? 0.0;
          comparison = aLtp.compareTo(bLtp);
          break;
        case 5: // Qty.
          comparison = (a.qty ?? 0).compareTo(b.qty ?? 0);
          break;
        case 6: // Status
          comparison = (a.gttOrderCurrentStatus ?? '')
              .compareTo(b.gttOrderCurrentStatus ?? '');
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  Widget _buildInstrumentCell(
      GttOrderBookModel gttOrder, ThemesProvider theme, bool isRowHovered,
      {int? rowIndex}) {
    final status = gttOrder.gttOrderCurrentStatus?.toUpperCase() ?? '';
    final isPending = status == 'PENDING' || status == 'TRIGGER_PENDING';
    final uniqueId = '${gttOrder.alId ?? ''}_${gttOrder.tsym ?? ''}';
    // Format instrument: remove "-EQ" and show symbol + exchange separately
    final symbol = gttOrder.tsym ?? '';
    final displayText = symbol.replaceAll("-EQ", "").trim();

    return GestureDetector(
      onTap: () => _showGttOrderDetail(gttOrder),
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
                    '$displayText${gttOrder.exch != null && gttOrder.exch!.isNotEmpty ? ' ${gttOrder.exch}' : ''}',
                child: Padding(
                  padding: EdgeInsets.only(right: isRowHovered ? 105.0 : 0.0),
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
                        if (gttOrder.exch != null && gttOrder.exch!.isNotEmpty)
                          TextSpan(
                            text: ' ${gttOrder.exch}',
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
            if (isRowHovered)
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
                        _buildModifyButton(gttOrder, uniqueId),
                      if (isPending)
                        const SizedBox(width: 6),
                      // Cancel button (X icon) - only for pending orders
                      if (isPending)
                        _buildCancelButton(gttOrder, uniqueId),
                      if (isPending)
                        const SizedBox(width: 6),
                      // 3-dot menu button
                      _buildOptionsMenuButton(
                        gttOrder,
                        uniqueId,
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
    GttOrderBookModel gttOrder,
    String uniqueId,
  ) {
    final isProcessing = _processingOrderToken == uniqueId && _isProcessingCancel;

    return GestureDetector(
      onTap: isProcessing
          ? null
          : () async {
              setState(() {
                _processingOrderToken = uniqueId;
                _isProcessingCancel = true;
              });
              await _handleCancelGttOrder(gttOrder);
              if (mounted) {
                setState(() {
                  _isProcessingCancel = false;
                  _processingOrderToken = null;
                });
              }
            },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              // dark: MyntColors.loss.withValues(alpha: 0.15),
              // light: MyntColors.loss.withValues(alpha: 0.1)),
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
    GttOrderBookModel gttOrder,
    String uniqueId,
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
                _isProcessingModify = true;
              });
              await _handleModifyGttOrder(gttOrder);
              if (mounted) {
                setState(() {
                  _isProcessingModify = false;
                  _processingOrderToken = null;
                });
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
    GttOrderBookModel gttOrder,
    String uniqueId,
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
                            _isProcessingModify = true;
                          });
                          await _handleModifyGttOrder(gttOrder);
                          if (mounted) {
                            setState(() {
                              _isProcessingModify = false;
                              _processingOrderToken = null;
                            });
                          }
                        },
                ),
              );
            }

            // Add divider before info
            if (isPending) {
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
                  _showGttOrderDetail(gttOrder);
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

  Widget _buildLTPCell(GttOrderBookModel gttOrder, ThemesProvider theme) {
    if (gttOrder.token == null || gttOrder.token!.isEmpty) {
      return Text(
        CellFormatters.getValidLTPForGtt(gttOrder),
        style: _getTextStyle(context),
      );
    } else {
      return _GttLTPCell(
        token: gttOrder.token!,
        initialLtp: CellFormatters.getValidLTPForGtt(gttOrder),
      );
    }
  }

  Widget _buildStatusCell(GttOrderBookModel gttOrder, ThemesProvider theme) {
    final status = gttOrder.gttOrderCurrentStatus?.toUpperCase() ?? '';
    final statusText = CellFormatters.getGttStatusText(status);

    // Use MyntColors for status
    Color statusColor;
    if (status == 'EXECUTED') {
      statusColor = resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    } else if (status == 'REJECTED' ||
        status == 'CANCELLED' ||
        status == 'CANCELED') {
      statusColor = resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    } else if (status == 'PENDING' || status == 'TRIGGER_PENDING') {
      statusColor = resolveThemeColor(context,
          dark: MyntColors.warning, light: MyntColors.warning);
    } else {
      statusColor = resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusText.toUpperCase(),
        style: MyntWebTextStyles.para(
          context,
          color: statusColor,
          fontWeight: MyntFonts.medium,
        ),
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  // Format created date from norentm or ordDate - returns date only (YYYY-MM-DD)
  String _formatCreatedDate(GttOrderBookModel gttOrder) {
    // Try norentm first (format: "YYYY-MM-DDTHH:mm:ss" or "HH:mm:ss dd-MM-yyyy")
    if (gttOrder.norentm != null && gttOrder.norentm!.isNotEmpty) {
      try {
        final norentm = gttOrder.norentm!;

        // Handle "YYYY-MM-DDTHH:mm:ss" format (ISO format with T separator)
        if (norentm.contains('T')) {
          return norentm.split('T')[0]; // Returns "YYYY-MM-DD"
        }

        // Handle "HH:mm:ss dd-MM-yyyy" format
        if (norentm.contains(' ')) {
          final parts = norentm.split(' ');
          if (parts.length >= 2) {
            // Convert "dd-MM-yyyy" to "yyyy-MM-dd"
            final dateParts = parts[1].split('-');
            if (dateParts.length == 3) {
              return '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}';
            }
            return parts[1];
          }
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    // Fallback to ordDate
    if (gttOrder.ordDate != null && gttOrder.ordDate!.isNotEmpty) {
      final ordDate = gttOrder.ordDate!;
      // Handle if ordDate also has time component
      if (ordDate.contains('T')) {
        return ordDate.split('T')[0];
      }
      return ordDate;
    }

    return 'N/A';
  }

  // Build Type cell with "SINGLE / BUY" or "OCO / SELL" format
  Widget _buildTypeCell(GttOrderBookModel gttOrder) {
    // Determine if SINGLE or OCO based on placeOrderParamsLeg2
    final isOco = gttOrder.placeOrderParamsLeg2 != null;
    final orderType = isOco ? 'OCO' : 'SINGLE';
    final isBuy = gttOrder.trantype == 'B';
    final sideText = isBuy ? 'BUY' : 'SELL';

    // Get side color - green for BUY, red for SELL
    final sideColor = isBuy
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);

    return RichText(
      text: TextSpan(
        children: [
          // Order type (SINGLE/OCO) - normal text color
          TextSpan(
            text: orderType,
            style: _getTextStyle(context),
          ),
          // Separator
          TextSpan(
            text: ' / ',
            style: _getTextStyle(context),
          ),
          // Side (BUY/SELL) - colored
          TextSpan(
            text: sideText,
            style: _getTextStyle(context, color: sideColor),
          ),
        ],
      ),
    );
  }

  // Build Trigger cell with value and percentage
  Widget _buildTriggerCell(GttOrderBookModel gttOrder) {
    final triggerValue = gttOrder.d ?? '0.00';

    // Calculate percentage from LTP if available
    String percentageText = '';
    try {
      final trigger = double.tryParse(triggerValue) ?? 0.0;
      final ltp = double.tryParse(gttOrder.ltp ?? '0') ?? 0.0;

      if (ltp > 0 && trigger > 0) {
        final percentage = ((trigger - ltp) / ltp * 100).abs();
        percentageText = '${percentage.toStringAsFixed(0)}%';
      }
    } catch (e) {
      // Ignore calculation errors
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          triggerValue,
          style: _getTextStyle(context),
        ),
        if (percentageText.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            percentageText,
            style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
              fontWeight: MyntFonts.medium,
            ),
          ),
        ],
      ],
    );
  }

  void _showGttOrderDetail(GttOrderBookModel gttOrder) {
    // Prevent double-click from opening sheet twice
    if (_isSheetOpening) return;
    _isSheetOpening = true;

    // Responsive width calculation
    shadcn.openSheet(
      context: context,
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
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 5,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: GttOrderBookDetailScreenWeb(
            gttOrder: gttOrder,
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

  Future<void> _handleCancelGttOrder(GttOrderBookModel gttOrder) async {
    // Show confirmation dialog first
    final shouldCancel = await _showCancelGttOrderDialog(gttOrder);

    if (shouldCancel != true) {
      return;
    }

    try {
      // Cancel the GTT order
      await ref
          .read(orderProvider)
          .cancelGttOrder(gttOrder.alId ?? '', context);

      // Refresh GTT order book after successful cancel
      await ref.read(orderProvider).fetchGTTOrderBook(context, "");

      // Note: Success snackbar is already shown by cancelGttOrder in provider
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
            context, 'Failed to cancel GTT order: ${e.toString()}');
      }
    }
  }

  Future<bool?> _showCancelGttOrderDialog(
      GttOrderBookModel gttOrderData) async {
    final symbol = gttOrderData.tsym?.replaceAll("-EQ", "") ?? 'N/A';

    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.dialogDark, light: MyntColors.dialog),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row with title and close button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: shadcn.Border(
                      bottom: shadcn.BorderSide(
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cancel GTT Order',
                        style: MyntWebTextStyles.title(
                          context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const shadcn.CircleBorder(),
                        child: InkWell(
                          customBorder: const shadcn.CircleBorder(),
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.textSecondaryDark,
                                  light: MyntColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content area
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Confirmation text with symbol in quotes
                      Text(
                        'Are you sure you want to cancel "$symbol"?',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.body(
                          context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary),
                        ),
                      ),

                      // Red Cancel button
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.tertiary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: MyntWebTextStyles.buttonMd(
                              context,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleModifyGttOrder(GttOrderBookModel gttOrder) async {
    try {
      // Fetch scrip info first
      await ref.read(marketWatchProvider).fetchScripInfo(
            "${gttOrder.token}",
            '${gttOrder.exch}',
            context,
            true,
          );

      if (!mounted) return;

      final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
      if (scripInfo == null) {
        ResponsiveSnackBar.showError(
            context, 'Unable to fetch scrip information');
        return;
      }

      // Show modify GTT order screen as draggable dialog
      ModifyGttWeb.showDraggable(
        context: context,
        gttOrderBook: gttOrder,
        scripInfo: scripInfo,
      );
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
            context, 'Failed to open modify GTT order: ${e.toString()}');
      }
    }
  }
}

// LTP Cell with WebSocket updates for GTT
class _GttLTPCell extends ConsumerStatefulWidget {
  final String token;
  final String initialLtp;

  const _GttLTPCell({required this.token, required this.initialLtp});

  @override
  ConsumerState<_GttLTPCell> createState() => _GttLTPCellState();
}

class _GttLTPCellState extends ConsumerState<_GttLTPCell> {
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
