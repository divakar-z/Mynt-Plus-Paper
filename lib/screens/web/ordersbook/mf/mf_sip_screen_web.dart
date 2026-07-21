import 'dart:async';
import 'package:flutter/material.dart' show InkWell, Icons, IconData, Icon, TextPainter, TextSpan, TextStyle, TextDirection, GestureDetector, HitTestBehavior, Row, SizedBox, Widget, BuildContext, Color, Colors, EdgeInsets, Alignment, MainAxisAlignment, MainAxisSize, TextOverflow, Axis, FontWeight, Container, MouseRegion, Expanded, Align, Text, ScrollController, SingleChildScrollView, Scrollbar, Column, LayoutBuilder, ValueKey, Padding, BoxDecoration, BorderRadius, Border, showDialog, ValueNotifier, ValueListenableBuilder, Stack, Positioned, Clip, Tooltip, MediaQuery, BoxShadow, Offset, Center;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/accessibility_provider.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;

import '../../../../provider/mf_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../provider/order_provider.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import '../../../../res/web_colors.dart';
import 'mf_sip_detail_screen_web.dart';
import 'sip_pause_dialogue_web.dart';
import 'sip_cancel_dialogue_web.dart';
import '../../../../models/mf_model/sip_mf_list_model.dart';

class MFSipdetScreenWeb extends ConsumerStatefulWidget {
  const MFSipdetScreenWeb({super.key});

  @override
  ConsumerState<MFSipdetScreenWeb> createState() => _MFSipdetScreenWebState();
}

class _MFSipdetScreenWebState extends ConsumerState<MFSipdetScreenWeb> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  // PERFORMANCE FIX: Use ValueNotifier for hover instead of setState
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);
  bool _hasInitialized = false;

  // Tab state
  int _selectedTabIndex = 0;

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

  // Order book scroll controllers
  late ScrollController _orderBookVerticalScrollController;
  late ScrollController _orderBookHorizontalScrollController;

  // Order book sorting state
  int? _orderBookSortColumnIndex;
  bool _orderBookSortAscending = true;

  @override
  void initState() {
    super.initState();
    _verticalScrollController = ScrollController();
    _horizontalScrollController = ScrollController();
    _orderBookVerticalScrollController = ScrollController();
    _orderBookHorizontalScrollController = ScrollController();

    // Listen to hover changes to close popover when row is unhovered
    _hoveredRowIndex.addListener(_onHoverChanged);

    // Only fetch data once when widget is first created
    if (!_hasInitialized) {
      Future.microtask(() {
        if (mounted && !_hasInitialized) {
          _hasInitialized = true;
          ref.read(mfProvider).fetchmfsiplist();
          ref.read(mfProvider).fetchmfsipnotlivelist();
        }
      });
    }
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
    _orderBookVerticalScrollController.dispose();
    _orderBookHorizontalScrollController.dispose();
    super.dispose();
  }

  // Helper method to ensure Geist font is always applied
  TextStyle _geistTextStyle({Color? color, double? fontSize, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: dyslexiaFontOr('Geist'),
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  // Builds a cell with hover detection (matches holdings pattern)
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    bool isOrderBook = false,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = isOrderBook ? columnIndex == 8 : columnIndex == 5;

    // Match the cell padding logic - first column has more left, minimal right
    EdgeInsets cellPadding;
    if (isFirstColumn) {
      cellPadding = const EdgeInsets.fromLTRB(16, 8, 4, 8);
    } else if (isLastColumn) {
      cellPadding = const EdgeInsets.fromLTRB(4, 8, 16, 8);
    } else {
      cellPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
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
          if (!isOrderBook) {
            _hoveredRowIndex.value = rowIndex;
            // Cancel any pending close if re-entering the popover's row
            if (_activePopoverController != null && _popoverRowIndex == rowIndex) {
              _cancelPopoverCloseTimer();
            }
          }
        },
        onExit: (_) {
          if (!isOrderBook) {
            _hoveredRowIndex.value = null;
            // If popover is open and not hovering dropdown, start close timer
            if (_activePopoverController != null && !_isHoveringDropdown) {
              _startPopoverCloseTimer();
            }
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
              onTap: () {
                if (isOrderBook) {
                  _openOrderBookSipDetail(_sortedOrderBookSipDetails(_getOrderBookSipDetails())[rowIndex]);
                } else {
                  _openSipDetail(_sortedSipDetails(_getSipDetails())[rowIndex]);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: cellPadding,
                color: isRowHovered && !isOrderBook
                    ? shadcn.Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                    : null,
                alignment: alignRight ? Alignment.topRight : null,
                child: cachedChild,
              ),
            );
          },
        ),
      ),
    );
  }

  // Builds a sortable header cell
  shadcn.TableCell buildHeaderCell(String label, int columnIndex, [bool alignRight = false, bool isOrderBook = false]) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = isOrderBook ? columnIndex == 8 : columnIndex == 5;
    final horizontalPadding = isFirstColumn || isLastColumn ? 16.0 : 6.0;

    final sortColumnIndex = isOrderBook ? _orderBookSortColumnIndex : _sortColumnIndex;
    final sortAscending = isOrderBook ? _orderBookSortAscending : _sortAscending;

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
        onTap: () => isOrderBook ? _onOrderBookSort(columnIndex) : _onSort(columnIndex),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 6),
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (alignRight && sortColumnIndex == columnIndex)
                Icon(
                  sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: shadcn.Theme.of(context).colorScheme.mutedForeground,
                ),
              if (alignRight && sortColumnIndex == columnIndex) const SizedBox(width: 4),
              Text(
                label,
                style: _geistTextStyle(
                  color: shadcn.Theme.of(context).colorScheme.foreground,
                ),
              ),
              if (!alignRight && sortColumnIndex == columnIndex) const SizedBox(width: 4),
              if (!alignRight && sortColumnIndex == columnIndex)
                Icon(
                  sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
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

  void _onOrderBookSort(int columnIndex) {
    setState(() {
      if (_orderBookSortColumnIndex == columnIndex) {
        _orderBookSortAscending = !_orderBookSortAscending;
      } else {
        _orderBookSortColumnIndex = columnIndex;
        _orderBookSortAscending = true;
      }
    });
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

  // Get SIP details list (Active SIPs)
  List<dynamic> _getSipDetails() {
    final mf = ref.watch(mfProvider);
    final orderBook = ref.watch(orderProvider);
    final isSearching = orderBook.orderSearchCtrl.text.isNotEmpty;
    return isSearching
        ? (mf.mfSipSearch ?? [])
        : (mf.mfsiporderlist?.data ?? []);
  }

  // Get SIP Order Book list (non-live/historical)
  List<dynamic> _getOrderBookSipDetails() {
    final mf = ref.watch(mfProvider);
    return mf.mfnotlivesiporderlist?.data ?? [];
  }

  // Calculate minimum column widths dynamically based on header and data
  Map<int, double> _calculateMinWidths(List<dynamic> sipDetails, BuildContext context) {
      final textStyle = const TextStyle(fontSize: 14);
      const padding = 24.0; // Padding for cell content
      const sortIconWidth = 24.0; // Extra space for sort indicator icon

      final headers = ['Scheme', 'SIP Reg No', 'Amount', 'Frequency', 'Next Installment', 'Status'];
      final minWidths = <int, double>{};

      // Calculate width for each column
      for (int col = 0; col < headers.length; col++) {
        double maxWidth = 0.0;

        // Measure header width and add space for sort icon
        final headerWidth = _measureTextWidth(headers[col], textStyle);
        maxWidth = headerWidth + sortIconWidth;

        // Measure widest value in this column (sample first 5 rows for performance)
        for (final sipDetail in sipDetails.take(5)) {
          String cellText = '';
          switch (col) {
            case 0: // Scheme
              cellText = sipDetail.name ?? 'N/A';
              break;
            case 1: // SIP Reg No
              cellText = sipDetail.sIPRegnNo ?? '';
              break;
            case 2: // Amount
              final amount = sipDetail.installmentAmount?.toString() ?? '0';
              cellText = double.tryParse(amount)?.toStringAsFixed(2) ?? amount;
              break;
            case 3: // Frequency
              cellText = sipDetail.frequencyType ?? '';
              break;
            case 4: // Next Installment
              cellText = sipDetail.NextSIPDate ?? '';
              break;
            case 5: // Status
              cellText = (sipDetail.status ?? '').toUpperCase();
              break;
          }

          final cellWidth = _measureTextWidth(cellText, textStyle);
          if (cellWidth > maxWidth) {
            maxWidth = cellWidth;
          }
        }

        // Set minimum width (max of header/data + padding)
        minWidths[col] = maxWidth + padding;
      }

      return minWidths;
    }

  // Calculate minimum column widths for Order Book
  Map<int, double> _calculateOrderBookMinWidths(List<dynamic> sipDetails, BuildContext context) {
    final textStyle = const TextStyle(fontSize: 14);
    const padding = 24.0;
    const sortIconWidth = 24.0;

    final headers = ['SIP Register Date', 'Start Date', 'End Date', 'Next SIP Date', 'Fund name', 'Frequency Type', 'Installment amt', 'SIP Register No.', 'Status'];
    final minWidths = <int, double>{};

    for (int col = 0; col < headers.length; col++) {
      double maxWidth = 0.0;

      final headerWidth = _measureTextWidth(headers[col], textStyle);
      maxWidth = headerWidth + sortIconWidth;

      for (final sipDetail in sipDetails.take(5)) {
        String cellText = '';
        switch (col) {
          case 0: // SIP Register Date
            cellText = sipDetail.sIPRegDate ?? '';
            break;
          case 1: // Start Date
            cellText = sipDetail.startDate ?? '';
            break;
          case 2: // End Date
            cellText = sipDetail.endDate ?? '';
            break;
          case 3: // Next SIP Date
            cellText = sipDetail.NextSIPDate ?? '';
            break;
          case 4: // Fund name
            cellText = sipDetail.name ?? 'N/A';
            break;
          case 5: // Frequency Type
            cellText = sipDetail.frequencyType ?? '';
            break;
          case 6: // Installment amt
            final amount = sipDetail.installmentAmount?.toString() ?? '0';
            cellText = double.tryParse(amount)?.toStringAsFixed(2) ?? amount;
            break;
          case 7: // SIP Register No.
            cellText = sipDetail.sIPRegnNo ?? '';
            break;
          case 8: // Status
            cellText = (sipDetail.status ?? '').toUpperCase();
            break;
        }

        final cellWidth = _measureTextWidth(cellText, textStyle);
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }

      minWidths[col] = maxWidth + padding;
    }

    return minWidths;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final mfData = ref.watch(mfProvider);

    // Show loader while data is being fetched
    if (mfData.bestmfloader == true) {
      return const Center(
        child: MyntLoader(size: MyntLoaderSize.large),
      );
    }

    return Column(
      children: [
        // Tab Bar
        _buildTabBar(theme),
        const SizedBox(height: 16),
        // Content based on selected tab
        Expanded(
          child: _selectedTabIndex == 0
              ? _buildActiveSipsContent(theme)
              : _buildSipOrderBookContent(theme),
        ),
      ],
    );
  }

  Widget _buildTabBar(ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildTabButton("Active SIP's", 0, theme),
          const SizedBox(width: 12),
          _buildTabButton("SIP Order Book", 1, theme),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, ThemesProvider theme) {
    final isSelected = _selectedTabIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (theme.isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade100)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(
                  color: theme.isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade300,
                  width: 1,
                )
              : null,
        ),
        child: Text(
          title,
          style: _geistTextStyle(
            color: isSelected
                ? (theme.isDarkMode ? Colors.white : Colors.black87)
                : (theme.isDarkMode
                    ? WebDarkColors.textSecondary
                    : WebColors.textSecondary),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSipsContent(ThemesProvider theme) {
    final sipDetails = _getSipDetails();

    if (sipDetails.isEmpty) {
      return const SizedBox(
        height: 400,
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: NoDataFoundWeb(),
          ),
        ),
      );
    }

    final sortedSipDetails = _sortedSipDetails(sipDetails);

    // Build data rows
    final dataRows = <shadcn.TableRow>[];
    for (var i = 0; i < sortedSipDetails.length; i++) {
      final sipDetail = sortedSipDetails[i];
      final colorScheme = shadcn.Theme.of(context).colorScheme;

      dataRows.add(
        shadcn.TableRow(
          cells: [
            // Scheme - Make clickable for row tap with 3-dot menu on hover
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 0,
              child: ValueListenableBuilder<int?>(
                valueListenable: _hoveredRowIndex,
                builder: (context, hoveredIndex, _) {
                  final isRowHovered = hoveredIndex == i ||
                      (_activePopoverController != null && _popoverRowIndex == i);
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // Scheme name - full width
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Tooltip(
                          message: sipDetail.name ?? 'N/A',
                          child: Padding(
                            padding: EdgeInsets.only(right: isRowHovered ? 40.0 : 0.0),
                            child: Text(
                              sipDetail.name ?? 'N/A',
                              style: _geistTextStyle(
                                color: colorScheme.foreground,
                              ),
                              overflow: isRowHovered ? TextOverflow.ellipsis : TextOverflow.visible,
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                      // 3-dot options menu - positioned on the right
                      if ((isRowHovered) && _shouldShowSipActions(sipDetail))
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _buildOptionsMenuButton(
                              sipDetail,
                              i,
                              theme,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            // SIP Reg No - Make clickable for row tap
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 1,
              alignRight: true,
              child: Text(
                sipDetail.sIPRegnNo ?? '',
                style: _geistTextStyle(
                  color: colorScheme.foreground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Amount - Make clickable for row tap
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 2,
              alignRight: true,
              child: Text(
                double.tryParse((sipDetail.installmentAmount?.toString() ?? '0'))?.toStringAsFixed(2) ?? (sipDetail.installmentAmount?.toString() ?? '0'),
                style: _geistTextStyle(
                  color: colorScheme.foreground,
                ),
              ),
            ),
            // Frequency - Make clickable for row tap
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 3,
              child: Text(
                sipDetail.frequencyType ?? '',
                style: _geistTextStyle(
                  color: colorScheme.foreground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Next Installment - Make clickable for row tap
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 4,
              alignRight: true,
              child: Text(
                sipDetail.NextSIPDate ?? '',
                style: _geistTextStyle(
                  color: colorScheme.foreground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Status - Make clickable for row tap
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 5,
              child: Text(
                (sipDetail.status ?? '').toUpperCase(),
                style: _geistTextStyle(
                  color: _getStatusColor(sipDetail.status ?? ''),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Return shadcn Table with proper structure
    return shadcn.OutlinedContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate minimum widths dynamically based on actual content
          final minWidths = _calculateMinWidths(sortedSipDetails, context);

          // Available width
          final availableWidth = constraints.maxWidth;

          // Step 1: Start with minimum widths (content-based, no wasted space)
          final columnWidths = <int, double>{};
          for (int i = 0; i < 6; i++) {
            columnWidths[i] = minWidths[i] ?? 100.0;
          }

          // Step 2: Calculate total minimum width needed
          final totalMinWidth = columnWidths.values.fold<double>(0.0, (sum, width) => sum + width);

          // Step 3: If there's extra space, distribute it proportionally
          if (totalMinWidth < availableWidth) {
            final extraSpace = availableWidth - totalMinWidth;

            // Define which columns can grow and their growth priorities
            const schemeGrowthFactor = 2.5; // Scheme gets more growth
            const textGrowthFactor = 1.2; // Text columns get medium growth
            const numericGrowthFactor = 1.0; // Numeric columns get less growth

            // Calculate growth factors for each column
            final growthFactors = <int, double>{};
            double totalGrowthFactor = 0.0;

            for (int i = 0; i < 6; i++) {
              if (i == 0) {
                // Column 0: Scheme
                growthFactors[i] = schemeGrowthFactor;
                totalGrowthFactor += schemeGrowthFactor;
              } else if (i == 3 || i == 5) {
                // Columns 3, 5: Text columns (Frequency, Status)
                growthFactors[i] = textGrowthFactor;
                totalGrowthFactor += textGrowthFactor;
              } else {
                // Columns 1, 2, 4: Numeric columns (SIP Reg No, Amount, Next Installment)
                growthFactors[i] = numericGrowthFactor;
                totalGrowthFactor += numericGrowthFactor;
              }
            }

            // Distribute extra space proportionally
            if (totalGrowthFactor > 0) {
              for (int i = 0; i < 6; i++) {
                if (growthFactors[i]! > 0) {
                  final extraForThisColumn = (extraSpace * growthFactors[i]!) / totalGrowthFactor;
                  columnWidths[i] = columnWidths[i]! + extraForThisColumn;
                }
              }
            }
          }

          // Calculate total required width
          final totalRequiredWidth = columnWidths.values.fold<double>(0.0, (sum, width) => sum + width);

          // If total width exceeds available width, enable horizontal scrolling
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
                  },
                  defaultRowHeight: const shadcn.FixedTableSize(40),
                  rows: [
                    shadcn.TableHeader(
                      cells: [
                        buildHeaderCell('Scheme', 0),
                        buildHeaderCell('SIP Reg No', 1, true),
                        buildHeaderCell('Amount', 2, true),
                        buildHeaderCell('Frequency', 3),
                        buildHeaderCell('Next Installment', 4, true),
                        buildHeaderCell('Status', 5),
                      ],
                    ),
                  ],
                ),
                // Scrollable Body (vertical scroll)
                Expanded(
                  child: Scrollbar(
                    controller: _verticalScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      scrollDirection: Axis.vertical,
                      child: shadcn.Table(
                        key: ValueKey('table_${_sortColumnIndex}_$_sortAscending'),
                        columnWidths: {
                          0: shadcn.FixedTableSize(columnWidths[0]!),
                          1: shadcn.FixedTableSize(columnWidths[1]!),
                          2: shadcn.FixedTableSize(columnWidths[2]!),
                          3: shadcn.FixedTableSize(columnWidths[3]!),
                          4: shadcn.FixedTableSize(columnWidths[4]!),
                          5: shadcn.FixedTableSize(columnWidths[5]!),
                        },
                        defaultRowHeight: const shadcn.FixedTableSize(40),
                        rows: dataRows,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Horizontal scroll wrapper (if needed)
          if (needsHorizontalScroll) {
            return Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
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
    );
  }

  Widget _buildSipOrderBookContent(ThemesProvider theme) {
    final sipDetails = _getOrderBookSipDetails();

    if (sipDetails.isEmpty) {
      return const SizedBox(
        height: 400,
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: NoDataFoundWeb(),
          ),
        ),
      );
    }

    final sortedSipDetails = _sortedOrderBookSipDetails(sipDetails);

    // Build data rows
    final dataRows = <shadcn.TableRow>[];
    for (var i = 0; i < sortedSipDetails.length; i++) {
      final sipDetail = sortedSipDetails[i];
      final colorScheme = shadcn.Theme.of(context).colorScheme;

      dataRows.add(
        shadcn.TableRow(
          cells: [
            // SIP Register Date
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 0,
              isOrderBook: true,
              child: Text(
                sipDetail.sIPRegDate ?? '',
                style: _geistTextStyle(color: colorScheme.foreground),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Start Date
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 1,
              isOrderBook: true,
              child: Text(
                sipDetail.startDate ?? '',
                style: _geistTextStyle(color: colorScheme.foreground),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // End Date
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 2,
              isOrderBook: true,
              child: Text(
                sipDetail.endDate ?? '',
                style: _geistTextStyle(color: colorScheme.foreground),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Next SIP Date
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 3,
              isOrderBook: true,
              child: Text(
                sipDetail.NextSIPDate ?? '',
                style: _geistTextStyle(color: colorScheme.foreground),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Fund name
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 4,
              isOrderBook: true,
              child: Text(
                sipDetail.name ?? 'N/A',
                style: _geistTextStyle(color: colorScheme.foreground),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Frequency Type
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 5,
              isOrderBook: true,
              child: Text(
                sipDetail.frequencyType ?? '',
                style: _geistTextStyle(color: colorScheme.foreground),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Installment amt
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 6,
              alignRight: true,
              isOrderBook: true,
              child: Text(
                double.tryParse((sipDetail.installmentAmount?.toString() ?? '0'))?.toStringAsFixed(2) ?? (sipDetail.installmentAmount?.toString() ?? '0'),
                style: _geistTextStyle(color: colorScheme.foreground),
              ),
            ),
            // SIP Register No.
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 7,
              isOrderBook: true,
              child: Text(
                sipDetail.sIPRegnNo ?? '',
                style: _geistTextStyle(color: colorScheme.foreground),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Status
            buildCellWithHover(
              rowIndex: i,
              columnIndex: 8,
              isOrderBook: true,
              child: Text(
                (sipDetail.status ?? '').toUpperCase(),
                style: _geistTextStyle(
                  color: _getStatusColor(sipDetail.status ?? ''),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Return shadcn Table with proper structure
    return shadcn.OutlinedContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minWidths = _calculateOrderBookMinWidths(sortedSipDetails, context);

          final availableWidth = constraints.maxWidth;

          final columnWidths = <int, double>{};
          for (int i = 0; i < 9; i++) {
            columnWidths[i] = minWidths[i] ?? 100.0;
          }

          final totalMinWidth = columnWidths.values.fold<double>(0.0, (sum, width) => sum + width);

          if (totalMinWidth < availableWidth) {
            final extraSpace = availableWidth - totalMinWidth;

            final growthFactors = <int, double>{
              0: 1.0, // SIP Register Date
              1: 1.0, // Start Date
              2: 1.0, // End Date
              3: 1.0, // Next SIP Date
              4: 2.5, // Fund name - gets more growth
              5: 1.2, // Frequency Type
              6: 1.0, // Installment amt
              7: 1.0, // SIP Register No.
              8: 1.2, // Status
            };

            double totalGrowthFactor = growthFactors.values.fold(0.0, (a, b) => a + b);

            if (totalGrowthFactor > 0) {
              for (int i = 0; i < 9; i++) {
                final extraForThisColumn = (extraSpace * growthFactors[i]!) / totalGrowthFactor;
                columnWidths[i] = columnWidths[i]! + extraForThisColumn;
              }
            }
          }

          final totalRequiredWidth = columnWidths.values.fold<double>(0.0, (sum, width) => sum + width);
          final needsHorizontalScroll = totalRequiredWidth > availableWidth;

          Widget buildTableContent() {
            return Column(
              children: [
                // Fixed Header
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
                  },
                  defaultRowHeight: const shadcn.FixedTableSize(40),
                  rows: [
                    shadcn.TableHeader(
                      cells: [
                        buildHeaderCell('SIP Register Date', 0, false, true),
                        buildHeaderCell('Start Date', 1, false, true),
                        buildHeaderCell('End Date', 2, false, true),
                        buildHeaderCell('Next SIP Date', 3, false, true),
                        buildHeaderCell('Fund name', 4, false, true),
                        buildHeaderCell('Frequency Type', 5, false, true),
                        buildHeaderCell('Installment amt', 6, true, true),
                        buildHeaderCell('SIP Register No.', 7, false, true),
                        buildHeaderCell('Status', 8, false, true),
                      ],
                    ),
                  ],
                ),
                // Scrollable Body
                Expanded(
                  child: Scrollbar(
                    controller: _orderBookVerticalScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    child: SingleChildScrollView(
                      controller: _orderBookVerticalScrollController,
                      scrollDirection: Axis.vertical,
                      child: shadcn.Table(
                        key: ValueKey('orderbook_table_${_orderBookSortColumnIndex}_$_orderBookSortAscending'),
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
                        },
                        defaultRowHeight: const shadcn.FixedTableSize(40),
                        rows: dataRows,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          if (needsHorizontalScroll) {
            return Scrollbar(
              controller: _orderBookHorizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                controller: _orderBookHorizontalScrollController,
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
    );
  }

  List<dynamic> _sortedSipDetails(List<dynamic> sipDetails) {
    if (_sortColumnIndex == null) return sipDetails;
    final sorted = List<dynamic>.from(sipDetails);
    int c = _sortColumnIndex!;
    bool asc = _sortAscending;

    int cmp<T extends Comparable>(T? a, T? b) {
      if (a == null && b == null) return 0;
      if (a == null) return -1;
      if (b == null) return 1;
      return a.compareTo(b);
    }

    num parseNum(String? v) => double.tryParse(v ?? '') ?? 0;

    sorted.sort((a, b) {
      int r = 0;
      switch (c) {
        case 0: // Scheme
          r = cmp<String>(a.name, b.name);
          break;
        case 1: // SIP Reg No
          r = cmp<String>(a.sIPRegnNo, b.sIPRegnNo);
          break;
        case 2: // Amount
          r = cmp<num>(parseNum(a.installmentAmount?.toString()),
              parseNum(b.installmentAmount?.toString()));
          break;
        case 3: // Frequency
          r = cmp<String>(a.frequencyType, b.frequencyType);
          break;
        case 4: // Next Installment
          r = cmp<String>(a.NextSIPDate, b.NextSIPDate);
          break;
        case 5: // Status
          r = cmp<String>(a.status, b.status);
          break;
      }
      return asc ? r : -r;
    });
    return sorted;
  }

  List<dynamic> _sortedOrderBookSipDetails(List<dynamic> sipDetails) {
    if (_orderBookSortColumnIndex == null) return sipDetails;
    final sorted = List<dynamic>.from(sipDetails);
    int c = _orderBookSortColumnIndex!;
    bool asc = _orderBookSortAscending;

    int cmp<T extends Comparable>(T? a, T? b) {
      if (a == null && b == null) return 0;
      if (a == null) return -1;
      if (b == null) return 1;
      return a.compareTo(b);
    }

    num parseNum(String? v) => double.tryParse(v ?? '') ?? 0;

    sorted.sort((a, b) {
      int r = 0;
      switch (c) {
        case 0: // SIP Register Date
          r = cmp<String>(a.sIPRegDate, b.sIPRegDate);
          break;
        case 1: // Start Date
          r = cmp<String>(a.startDate, b.startDate);
          break;
        case 2: // End Date
          r = cmp<String>(a.endDate, b.endDate);
          break;
        case 3: // Next SIP Date
          r = cmp<String>(a.NextSIPDate, b.NextSIPDate);
          break;
        case 4: // Fund name
          r = cmp<String>(a.name, b.name);
          break;
        case 5: // Frequency Type
          r = cmp<String>(a.frequencyType, b.frequencyType);
          break;
        case 6: // Installment amt
          r = cmp<num>(parseNum(a.installmentAmount?.toString()),
              parseNum(b.installmentAmount?.toString()));
          break;
        case 7: // SIP Register No.
          r = cmp<String>(a.sIPRegnNo, b.sIPRegnNo);
          break;
        case 8: // Status
          r = cmp<String>(a.status, b.status);
          break;
      }
      return asc ? r : -r;
    });
    return sorted;
  }

  Color _getStatusColor(String status) {
    final colorScheme = shadcn.Theme.of(context).colorScheme;
    final statusLower = status.toLowerCase();

    if (statusLower == 'active' || statusLower == 'running' || statusLower == 'live') {
      return colorScheme.chart2;
    } else if (statusLower == 'stopped' || statusLower == 'cancelled' || statusLower == 'rejected') {
      return colorScheme.destructive;
    } else {
      return colorScheme.chart1;
    }
  }

  void _openSipDetail(Xsip sipDetail) {
    // Open detail sheet (matching pattern from other order detail screens)
    shadcn.openSheet(
      context: context,
      builder: (sheetContext) => MFSipDetailScreenWeb(
        sipData: sipDetail,
      ),
      position: shadcn.OverlayPosition.end,
    );
  }

  void _openOrderBookSipDetail(dynamic sipDetail) {
    // Open detail sheet for order book SIP
    shadcn.openSheet(
      context: context,
      builder: (sheetContext) => MFSipDetailScreenWeb(
        sipData: sipDetail,
      ),
      position: shadcn.OverlayPosition.end,
    );
  }

  bool _shouldShowSipActions(dynamic sipDetail) {
    final status = (sipDetail.status ?? '').toUpperCase();
    return status == "ACTIVE" || status == "RUNNING";
  }

  // Build styled menu button matching profile dropdown
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
              style: _geistTextStyle(
                fontWeight: FontWeight.w500,
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
    dynamic sipDetail,
    int rowIndex,
    ThemesProvider theme,
  ) {
    return shadcn.Builder(
      builder: (buttonContext) {
        return GestureDetector(
          onTap: () {
            // Close any existing popover first
            _closePopover();

            // Build menu items
            List<shadcn.MenuItem> menuItems = [];
            final colorScheme = shadcn.Theme.of(context).colorScheme;
            final iconColor = colorScheme.foreground;
            final textColor = colorScheme.foreground;

            // Pause SIP option
            menuItems.add(
              _buildMenuButton(
                icon: Icons.pause_circle_outline,
                title: 'Pause SIP',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SipPauseDialogueWeb(sipData: sipDetail);
                    },
                  );
                },
              ),
            );

            // Cancel SIP option
            menuItems.add(
              _buildMenuButton(
                icon: Icons.cancel_outlined,
                title: 'Cancel SIP',
                iconColor: colorScheme.destructive,
                textColor: colorScheme.destructive,
                onPressed: (ctx) {
                  _closePopover();
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SipCancelDialogueWeb(sipData: sipDetail);
                    },
                  );
                },
              ),
            );

            // Add divider before details
            menuItems.add(const shadcn.MenuDivider());

            // Details option
            menuItems.add(
              _buildMenuButton(
                icon: Icons.info_outline,
                title: 'Details',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  _openSipDetail(sipDetail);
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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: shadcn.Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.more_vert,
              size: 18,
              color: shadcn.Theme.of(context).colorScheme.foreground,
            ),
          ),
        );
      },
    );
  }

}
