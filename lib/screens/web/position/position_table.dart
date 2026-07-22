import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../../utils/rupee_convert_format.dart';
import 'package:flutter/material.dart'
    show
        InkWell,
        Icons,
        IconData,
        BorderRadius,
        Border,
        BorderSide,
        BlendMode,
        ColorFilter,
        Icon,
        BoxDecoration,
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
        showDialog,
        RichText,
        Tooltip,
        ValueNotifier,
        ValueListenableBuilder,
        MediaQuery,
        BoxShadow,
        Offset,
        RawScrollbar,
        Radius,
        Builder,
        ListView,
        NeverScrollableScrollPhysics;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;

import '../../../models/portfolio_model/position_book_model.dart';
import '../../../res/res.dart';
import '../../../provider/portfolio_provider.dart';
import '../../../provider/privacy_provider.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/thems.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/snack_bar.dart';
import '../../../sharedWidget/no_data_found.dart';
import '../../../utils/responsive_navigation.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../models/order_book_model/order_book_model.dart';
import 'position_detail_screen_web.dart';
import 'convert_position_dialogue_web.dart';

// Shadcn Table for Positions with WebSocket updates
class PositionTable extends ConsumerStatefulWidget {
  final String? searchQuery;
  final String filterType;

  const PositionTable({super.key, this.searchQuery, this.filterType = 'All'});

  @override
  ConsumerState<PositionTable> createState() => _PositionTableState();
}

class _PositionTableState extends ConsumerState<PositionTable> {
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

  // Prevent double-click from opening overlay twice
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
  TextStyle _getHeaderStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableHeader(
      context,
      color: color,
      darkColor: color ?? MyntColors.textSecondaryDark,
      lightColor: color ?? MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  // Helper method to format instrument display text (without exchange - exchange shown separately)
  String _formatInstrumentText(PositionBookModel position) {
    // Priority 0: backend display name from the DerivativeMaster (derivatives).
    final master = position.masterName;
    if (master != null && master.isNotEmpty) return master;

    // Priority 1: Use dname (display name) if available
    if (position.dname != null && position.dname!.isNotEmpty) {
      return position.dname!.replaceAll("-EQ", "").trim();
    }

    // Priority 2: Use tsym if dname is not available
    if (position.tsym != null && position.tsym!.isNotEmpty) {
      return position.tsym!.replaceAll("-EQ", "").trim();
    }

    // Fallback: build from components if both are not available
    final symbol = (position.symbol ?? '').replaceAll("-EQ", "").trim();
    final expDate = position.expDate ?? '';
    final option = position.option ?? '';

    // Build display text: symbol + expDate + option (no exchange - shown separately in UI)
    String displayText = symbol;
    if (expDate.isNotEmpty) {
      displayText += expDate;
    }
    if (option.isNotEmpty) {
      displayText += option;
    }
    return displayText;
  }

  // Builds a cell with hover detection
  // Pass position data for automatic row tap handling (centralized - no duplication)
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    bool isClosed = false,
    dynamic position, // Pass position data for automatic row tap handling
  }) {
    final isFirstColumn = columnIndex == 0; // Select checkbox column
    final isInstrumentColumn = columnIndex == 2; // Instrument column (now index 2)
    final isLastColumn = columnIndex == 6; // P&L is now last column

    // Match the cell padding logic - Instrument column has more left, minimal right
    // Last column mirrors this - minimal left, more right
    // Select column (checkbox) uses symmetric padding
    EdgeInsets cellPadding;
    if (isFirstColumn) {
      // Select column - symmetric padding for checkbox
      cellPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4);
    } else if (isInstrumentColumn) {
      // Instrument column - more left, minimal right (for 3-dot menu)
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
          // This handles case where value was already null (no listener trigger)
          if (_activePopoverController != null && !_isHoveringDropdown) {
            _startPopoverCloseTimer();
          }
        },
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredRowIndex,
          // PERFORMANCE FIX: Pass child to the 'child' parameter so it's cached
          // and NOT rebuilt when hover changes. Only the Container color changes.
          child: child,
          builder: (context, hoveredIndex, cachedChild) {
            // Row is hovered if mouse is over it OR if its dropdown menu is open
            final isRowHovered = hoveredIndex == rowIndex ||
                (_activePopoverController != null && _popoverRowIndex == rowIndex);

            // Background color logic: No hover effect for closed positions
            Color? backgroundColor;
            if (isClosed) {
              // Closed positions: show muted background, no hover effect
              backgroundColor = resolveThemeColor(context,
                  dark: MyntColors.textPrimary.withValues(alpha: 0.05),
                  light: const Color(0x8F121212).withValues(alpha: 0.03));
            } else if (isRowHovered) {
              // Open positions: show hover effect only
              backgroundColor = resolveThemeColor(context,
                  dark: MyntColors.primaryDark.withValues(alpha: 0.08),
                  light: MyntColors.primary.withValues(alpha: 0.08));
            }

            final container = Container(
              padding: cellPadding,
              color: backgroundColor,
              alignment: alignRight ? Alignment.topRight : null,
              child: cachedChild, // Use cached child - won't rebuild on hover!
            );

            // Automatically wrap with GestureDetector for row tap when position data is provided
            if (position != null) {
              return GestureDetector(
                onTap: () {
                  _hoveredRowIndex.value = null;
                  _showPositionDetail(position);
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
  Color _getCellColor(double value, BuildContext context) {
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
  shadcn.TableCell buildHeaderCell(
      String label, int columnIndex, ThemesProvider theme,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0; // Select checkbox column
    final isInstrumentColumn = columnIndex == 2; // Instrument column (now index 2)
    final isLastColumn = columnIndex == 6; // P&L is now last column

    // Match the cell padding logic - Instrument column has more left, minimal right
    // Last column mirrors this - minimal left, more right
    // Select column (checkbox) uses symmetric padding
    EdgeInsets headerPadding;
    if (isFirstColumn) {
      // Select column - symmetric padding for checkbox
      headerPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
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

  // Get column index for header
  int _getColumnIndexForHeader(String header) {
    switch (header) {
      case 'Select':
        return 0;
      case 'Product':
        return 1;
      case 'Instrument':
        return 2;
      case 'Qty':
        return 3;
      case 'Act Avg':
        return 4;
      case 'LTP':
        return 5;
      case 'P&L':
        return 6;
      default:
        return -1;
    }
  }

  // Check if column is numeric
  bool _isNumericColumn(String header) {
    return header != 'Select' && header != 'Product' && header != 'Instrument';
  }

  // Format position quantity - for MCX, divide by lot size
  String _formatPositionQty(PositionBookModel position) {
    // Use netqty as the source (raw quantity from API)
    final rawQty = int.tryParse(position.netqty?.toString() ?? '0') ?? 0;
    final lotSize = position.exch == 'MCX'
        ? (int.tryParse(position.ls?.toString() ?? '1') ?? 1)
        : 1;
    final qty = rawQty ~/ lotSize;
    return qty > 0 ? '+$qty' : '$qty';
  }

  // Check if position is closed
  bool _isPositionClosed(PositionBookModel position) {
    final netqty = int.tryParse(position.netqty ?? '0') ?? 0;
    return netqty == 0;
  }

  // Get position text color
  // Get quantity color
  Color _getQtyColor(String qty, BuildContext context) {
    final numQty = int.tryParse(qty) ?? 0;
    if (numQty > 0) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    } else if (numQty < 0) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    } else {
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    }
  }

  // Filter and sort positions
  List<PositionBookModel> _getFilteredPositions(
      List<PositionBookModel> positions) {
    List<PositionBookModel> filtered = positions.toList();

    // Apply search filter
    final searchQuery = widget.searchQuery?.toLowerCase().trim() ?? '';
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((position) {
        // Match the displayed contract name (master/dname/tsym) and its
        // parsed parts so expiry ("JUL", "24 JUL 26") and strike/option
        // ("270 CE") searches work, not just the underlying symbol.
        final searchable = [
          position.masterName,
          position.dname,
          position.tsym,
          position.symbol,
          position.expDate,
          position.option,
          position.exch,
        ];
        return searchable.any(
            (field) => (field ?? '').toLowerCase().contains(searchQuery));
      }).toList();
    }

    // Apply product filter
    if (widget.filterType != 'All') {
      filtered = filtered.where((position) {
        return position.sPrdtAli == widget.filterType;
      }).toList();
    }

    // Apply sorting
    if (_sortColumnIndex != null) {
      filtered.sort((a, b) {
        int comparison = 0;
        switch (_sortColumnIndex) {
          case 1: // Product
            comparison = (a.sPrdtAli ?? '').compareTo(b.sPrdtAli ?? '');
            break;
          case 2: // Instrument
            // Compare the displayed contract name (master/dname/tsym) — the
            // parsed symbol alone ties for every contract of one underlying.
            comparison = _formatInstrumentText(a)
                .compareTo(_formatInstrumentText(b));
            break;
          case 3: // Qty
            comparison = (int.tryParse(a.qty ?? '0') ?? 0)
                .compareTo(int.tryParse(b.qty ?? '0') ?? 0);
            break;
          case 4: // Act Avg Price
            comparison = (double.tryParse(a.avgPrc ?? '0') ?? 0)
                .compareTo(double.tryParse(b.avgPrc ?? '0') ?? 0);
            break;
          case 5: // LTP
            comparison = (double.tryParse(a.lp ?? '0') ?? 0)
                .compareTo(double.tryParse(b.lp ?? '0') ?? 0);
            break;
          case 6: // P&L
            comparison = (double.tryParse(a.profitNloss ?? '0') ?? 0)
                .compareTo(double.tryParse(b.profitNloss ?? '0') ?? 0);
            break;
          // Commented out columns - data available in Position Details sheet
          // case 7: // MTM
          //   comparison = (double.tryParse(a.mTm ?? '0') ?? 0)
          //       .compareTo(double.tryParse(b.mTm ?? '0') ?? 0);
          //   break;
          // case 8: // Avg Price
          //   comparison = (double.tryParse(a.avgPrc ?? '0') ?? 0)
          //       .compareTo(double.tryParse(b.avgPrc ?? '0') ?? 0);
          //   break;
          // case 9: // Buy Qty
          //   comparison = (int.tryParse(a.daybuyqty ?? '0') ?? 0)
          //       .compareTo(int.tryParse(b.daybuyqty ?? '0') ?? 0);
          //   break;
          // case 10: // Sell Qty
          //   comparison = (int.tryParse(a.daysellqty ?? '0') ?? 0)
          //       .compareTo(int.tryParse(b.daysellqty ?? '0') ?? 0);
          //   break;
          // case 11: // Buy Avg
          //   comparison = (double.tryParse(a.daybuyavgprc ?? '0') ?? 0)
          //       .compareTo(double.tryParse(b.daybuyavgprc ?? '0') ?? 0);
          //   break;
          // case 12: // Sell Avg
          //   comparison = (double.tryParse(a.daysellavgprc ?? '0') ?? 0)
          //       .compareTo(double.tryParse(b.daysellavgprc ?? '0') ?? 0);
          //   break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    return filtered;
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
      List<PositionBookModel> positions, BuildContext context) {
    // Use fixed font size for measurement (table text is not responsive, only buttons are)
    final textStyle = const TextStyle(fontSize: 14, fontFamily: 'Geist');
    const padding = 16.0; // Reduced from 24.0 for tighter layout
    const sortIconWidth = 24.0;

    // Header texts - Essential columns for responsive layout (Product first, then Instrument)
    final headers = [
      'Select',
      'Product',
      'Instrument',
      'Qty',
      'Act Avg',
      'LTP',
      'P&L',
    ];

    final minWidths = <int, double>{};

    for (int col = 0; col < headers.length; col++) {
      double maxWidth = 0.0;
      final header = headers[col];

      // Special handling for Select column (checkbox)
      if (header == 'Select') {
        // Checkbox size (18px) + padding on both sides (12px each) + safety margin = 70px minimum
        minWidths[col] = 70.0;
        continue;
      }

      // Measure header width and add space for sort icon
      final headerWidth = _measureTextWidth(header, textStyle);
      maxWidth = headerWidth + sortIconWidth;

      // Measure widest value in this column
      for (final position in positions) {
        String cellText = '';

        switch (header) {
          case 'Product':
            cellText = position.sPrdtAli ?? 'N/A';
            break;
          case 'Instrument':
            // For Instrument column, measure symbol + exchange separately
            // since exchange uses smaller font
            final symbolText = _formatInstrumentText(position);
            final exchangeText = (position.exch != null &&
                    position.exch!.isNotEmpty &&
                    (position.expDate == null || position.expDate!.isEmpty))
                ? ' ${position.exch}'
                : '';

            // Measure symbol with normal font
            final symbolWidth = _measureTextWidth(symbolText, textStyle);

            // Measure exchange with smaller font (fixed 12px, matches rendering)
            final exchangeStyle =
                const TextStyle(fontSize: 12, fontFamily: 'Geist');
            final exchangeWidth = exchangeText.isNotEmpty
                ? _measureTextWidth(exchangeText, exchangeStyle)
                : 0.0;

            // Total width = symbol + exchange + 4px gap + space for 3-dot menu
            final totalWidth = symbolWidth +
                exchangeWidth +
                (exchangeText.isNotEmpty ? 4.0 : 0.0) +
                40.0; // Extra space for 3-dot menu button
            if (totalWidth > maxWidth) {
              maxWidth = totalWidth;
            }
            // Skip normal cellWidth calculation for Instrument - already handled above
            continue;
          case 'Qty':
            cellText = _formatPositionQty(position);
            break;
          case 'Act Avg':
            cellText = position.avgPrc ?? '0.00';
            break;
          case 'LTP':
            cellText = position.lp ?? '0.00';
            break;
          case 'P&L':
            cellText = (position.profitNloss ?? '0.00').toIndianFormat();
            break;
          // Commented out columns - data available in Position Details sheet
          // case 'MTM':
          //   cellText = position.mTm ?? '0.00';
          //   break;
          // case 'Avg Price':
          //   cellText = position.avgPrc ?? '0.00';
          //   break;
          // case 'Buy Qty':
          //   cellText = position.daybuyqty ?? '0';
          //   break;
          // case 'Sell Qty':
          //   cellText = position.daysellqty ?? '0';
          //   break;
          // case 'Buy Avg':
          //   cellText = position.daybuyavgprc ?? '0.00';
          //   break;
          // case 'Sell Avg':
          //   cellText = position.daysellavgprc ?? '0.00';
          //   break;
        }

        final cellWidth = _measureTextWidth(cellText, textStyle);
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }

      // For instrument column, no need to reserve space for buttons
      // Buttons will overlay on the right side, covering only half the text
      // Text can use full width, buttons appear on hover as overlay
      // Ensure minimum width to prevent excessive truncation
      if (header == 'Instrument') {
        const minInstrumentWidth = 150.0;
        maxWidth =
            maxWidth < minInstrumentWidth ? minInstrumentWidth : maxWidth;
      }

      minWidths[col] = maxWidth + padding;
    }

    return minWidths;
  }

  @override
  Widget build(BuildContext context) {
    final portfolioData = ref.watch(portfolioProvider);
    final positions = portfolioData.allPostionList.isNotEmpty
        ? portfolioData.allPostionList
        : portfolioData.openPosition ?? [];


    final theme = ref.read(themeProvider);
    final positionBook = ref.read(portfolioProvider);

    // Filter and sort positions
    final filteredPositions = _getFilteredPositions(positions);

    if (filteredPositions.isEmpty) {
      return shadcn.OutlinedContainer(
        child: NoDataFoundWeb(
          title: widget.searchQuery?.isNotEmpty == true
              ? "No Positions Found"
              : "No Positions",
          subtitle: widget.searchQuery?.isNotEmpty == true
              ? "No positions match your search \"${widget.searchQuery}\"."
              : "You don't have any positions yet.",
          primaryEnabled: false,
          secondaryEnabled: false,
        ),
      );
    }

    // Define essential columns for responsive layout (Product first, then Instrument)
    final headers = [
      'Select',
      'Product',
      'Instrument',
      'Qty',
      'Act Avg',
      'LTP',
      'P&L',
    ];

    return shadcn.OutlinedContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate minimum widths dynamically based on actual content
          final minWidths = _calculateMinWidths(filteredPositions, context);

          // Available width
          final availableWidth = constraints.maxWidth;

          // Step 1: Start with minimum widths (content-based, no wasted space)
          final columnWidths = <int, double>{};
          for (int i = 0; i < headers.length; i++) {
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
            final extraPerColumn = extraSpace / headers.length;

            for (int i = 0; i < headers.length; i++) {
              columnWidths[i] = columnWidths[i]! + extraPerColumn;
            }
          } else if (totalMinWidth > availableWidth) {
            // Not enough space - shrink columns proportionally to eliminate scroll
            final excessWidth = totalMinWidth - availableWidth;

            // Define absolute minimum widths (cannot shrink below these)
            final absoluteMinWidths = <int, double>{
              0: 50.0,  // Select (checkbox)
              1: 50.0,  // Product (CNC/MIS/NRML)
              2: 120.0, // Instrument (needs space for 3-dot menu)
              3: 45.0,  // Qty
              4: 65.0,  // Act Avg Price
              5: 80.0,  // LTP
              6: 55.0,  // P&L
            };

            // Calculate how much each column can shrink
            final shrinkableAmounts = <int, double>{};
            double totalShrinkable = 0.0;

            for (int i = 0; i < headers.length; i++) {
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

              for (int i = 0; i < headers.length; i++) {
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

          // Calculate total P&L once (runs when filteredPositions changes, not on scroll)
          final totalPnl = filteredPositions.fold<double>(
            0.0,
            (sum, position) => sum + (double.tryParse(position.profitNloss ?? '0') ?? 0.0),
          );

          // Build table content
          Widget buildTableContent() {
            return Column(
              children: [
                // Fixed Header (synced with horizontal scroll)
                shadcn.Table(
                  columnWidths: columnWidths.map((index, width) {
                    return MapEntry(index, shadcn.FixedTableSize(width));
                  }),
                  defaultRowHeight: const shadcn.FixedTableSize(40),
                  rows: [
                    shadcn.TableHeader(
                      cells: headers.map((header) {
                        final columnIndex = _getColumnIndexForHeader(header);
                        final isNumeric = _isNumericColumn(header);

                        // Special handling for Select column
                        if (header == 'Select') {
                          return _buildSelectHeaderCell(
                              theme, positionBook, filteredPositions);
                        }

                        return buildHeaderCell(
                            header, columnIndex, theme, isNumeric);
                      }).toList(),
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
                      itemCount: filteredPositions.length,
                      itemExtent: 42.0,
                      itemBuilder: (context, index) {
                        final position = filteredPositions[index];
                        final isClosed = _isPositionClosed(position);

                        return shadcn.Table(
                          key: ValueKey(
                              'row_${position.token}_${_sortColumnIndex}_$_sortAscending'),
                          columnWidths: columnWidths.map((idx, width) {
                            return MapEntry(idx, shadcn.FixedTableSize(width));
                          }),
                          defaultRowHeight: const shadcn.FixedTableSize(40),
                          rows: [
                            shadcn.TableRow(
                              cells: headers.map((header) {
                                final columnIndex =
                                    _getColumnIndexForHeader(header);
                                final isNumeric = _isNumericColumn(header);

                                // Make cells clickable except Select (checkbox) and Instrument (has buttons)
                                final isClickable =
                                    header != 'Select' && header != 'Instrument';

                                // PERFORMANCE FIX: Only Instrument column needs hover state for showing buttons
                                // Other columns (MTM, P&L, LTP, etc.) should NOT rebuild on hover
                                if (header == 'Instrument') {
                                  // Instrument column: needs hover state to show/hide action buttons
                                  return buildCellWithHover(
                                    rowIndex: index,
                                    columnIndex: columnIndex,
                                    alignRight: isNumeric,
                                    isClosed: isClosed,
                                    position: position,
                                    child: ValueListenableBuilder<int?>(
                                      valueListenable: _hoveredRowIndex,
                                      builder: (context, hoveredIndex, _) {
                                        // Row is hovered if mouse is over it OR if its dropdown menu is open
                                        final isRowHovered = hoveredIndex == index ||
                                            (_activePopoverController != null && _popoverRowIndex == index);
                                        return _buildCellContent(
                                          context,
                                          header,
                                          position,
                                          theme,
                                          isClosed,
                                          isRowHovered,
                                          positionBook,
                                          rowIndex: index,
                                        );
                                      },
                                    ),
                                  );
                                } else {
                                  // All other columns: do NOT listen to hover state
                                  // This prevents MTM, P&L, LTP cells from rebuilding on hover
                                  return buildCellWithHover(
                                    rowIndex: index,
                                    columnIndex: columnIndex,
                                    alignRight: isNumeric,
                                    isClosed: isClosed,
                                    // Pass position for clickable cells (not Select column)
                                    position: isClickable ? position : null,
                                    child: _buildCellContent(
                                      context,
                                      header,
                                      position,
                                      theme,
                                      isClosed,
                                      false, // Not hover-dependent
                                      positionBook,
                                    ),
                                  );
                                }
                              }).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                // Fixed Total Row (outside scrollable area)
                _buildFixedTotalFooter(context, headers, columnWidths, totalPnl),
              ],
            );
          }

          // Always use the same widget tree structure to prevent
          // "ScrollController attached to more than one ScrollPosition"
          // errors caused by LayoutBuilder toggling between different trees.
          // When horizontal scroll isn't needed, just disable the physics.
          return RawScrollbar(
            controller: needsHorizontalScroll ? _horizontalScrollController : null,
            thumbVisibility: needsHorizontalScroll,
            trackVisibility: needsHorizontalScroll,
            trackColor: resolveThemeColor(context,
                dark: Colors.grey.withOpacity(0.1),
                light: Colors.grey.withOpacity(0.1)),
            thumbColor: resolveThemeColor(context,
                dark: Colors.grey.withOpacity(0.3),
                light: Colors.grey.withOpacity(0.3)),
            thickness: needsHorizontalScroll ? 6 : 0,
            radius: const Radius.circular(3),
            interactive: needsHorizontalScroll,
            child: SingleChildScrollView(
              controller: needsHorizontalScroll ? _horizontalScrollController : null,
              scrollDirection: Axis.horizontal,
              physics: needsHorizontalScroll
                  ? null
                  : const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: needsHorizontalScroll ? totalRequiredWidth : availableWidth,
                child: buildTableContent(),
              ),
            ),
          );
        },
      ),
    );
  }

  // Build select header cell with checkbox
  shadcn.TableCell _buildSelectHeaderCell(
    ThemesProvider theme,
    PortfolioProvider positionBook,
    List<PositionBookModel> filteredPositions,
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
      child: Consumer(
        builder: (context, ref, child) {
          final isExitAllPosition =
              ref.watch(portfolioProvider.select((p) => p.isExitAllPosition));
          // Only enable if there are open (non-closed) positions
          final hasOpenPositions = filteredPositions.any((p) {
            final qty = int.tryParse(p.qty ?? '0') ?? 0;
            return qty != 0;
          });
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            alignment: Alignment.centerLeft,
            child: shadcn.Checkbox(
              state: isExitAllPosition
                  ? shadcn.CheckboxState.checked
                  : shadcn.CheckboxState.unchecked,
              onChanged: hasOpenPositions
                  ? (state) {
                      positionBook.selectExitAllPosition(
                          state == shadcn.CheckboxState.checked);
                    }
                  : null,
              enabled: hasOpenPositions,
              activeColor: resolveThemeColor(
                context,
                dark: MyntColors.secondary,
                light: MyntColors.primary,
              ),
              borderRadius: BorderRadius.circular(4),
              size: 18,
            ),
          );
        },
      ),
    );
  }

  // Build cell content based on column
  Widget _buildCellContent(
    BuildContext context,
    String header,
    PositionBookModel position,
    ThemesProvider theme,
    bool isClosed,
    bool isRowHovered,
    PortfolioProvider positionBook, {
    int? rowIndex,
  }) {
    final isNumeric = _isNumericColumn(header);
    final alignment = isNumeric ? Alignment.centerRight : Alignment.centerLeft;
    final textColor = isClosed
        ? resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary)
        : null;

    switch (header) {
      case 'Select':
        return _buildCheckboxCell(position, theme, isClosed, positionBook);
      case 'Product':
        return _buildProductCell(context, position, isClosed, textColor);
      case 'Instrument':
        return _buildInstrumentCell(
            context, position, theme, isClosed, isRowHovered, positionBook,
            rowIndex: rowIndex);
      case 'Qty':
        // Privacy Mode: qty (with its long/short sign and colour) is hidden.
        final privacy = ref.watch(privacyProvider);
        final formattedQty = privacy.mask(_formatPositionQty(position));
        return Align(
          alignment: alignment,
          child: Tooltip(
            message: formattedQty,
            child: Text(
              formattedQty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _getTextStyle(context,
                  color: isClosed
                      ? textColor
                      : (privacy.isPrivate
                          ? _getCellColor(0.0, context)
                          : _getQtyColor(formattedQty, context))),
            ),
          ),
        );
      case 'Act Avg':
        final avgValue =
            ref.watch(privacyProvider).mask(position.avgPrc ?? '0.00');
        return Align(
          alignment: alignment,
          child: Tooltip(
            message: avgValue,
            child: Text(
              avgValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _getTextStyle(context, color: textColor),
            ),
          ),
        );
      case 'LTP':
        // Just display provider value - provider already updates from WebSocket
        final ltpValue = position.lp ?? '0.00';
        return Align(
          alignment: alignment,
          child: Tooltip(
            message: ltpValue,
            child: Text(
              ltpValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _getTextStyle(context, color: textColor),
            ),
          ),
        );
      case 'P&L':
        // Just display provider value - positionCal() already calculates correctly
        final pnlPrivacy = ref.watch(privacyProvider);
        final pnlValue = position.profitNloss ?? '0.00';
        final displayPnl = pnlPrivacy.mask(pnlValue.toIndianFormat());
        return Align(
          alignment: alignment,
          child: Tooltip(
            message: displayPnl,
            child: Text(
              displayPnl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _getTextStyle(context,
                  color: _getCellColor(
                      pnlPrivacy.isPrivate
                          ? 0.0
                          : (double.tryParse(pnlValue) ?? 0.0),
                      context)),
            ),
          ),
        );
      // Commented out columns - data available in Position Details sheet
      // case 'MTM':
      //   // Just display provider value - positionCal() already calculates correctly
      //   final mtmValue = position.mTm ?? '0.00';
      //   return Align(
      //     alignment: alignment,
      //     child: Text(
      //       mtmValue,
      //       style: _getTextStyle(context,
      //           color: _getCellColor(double.tryParse(mtmValue) ?? 0.0, context)),
      //     ),
      //   );
      // case 'Avg Price':
      //   return Align(
      //     alignment: alignment,
      //     child: Text(
      //       position.avgPrc ?? '0.00',
      //       style: _getTextStyle(context, color: textColor),
      //     ),
      //   );
      // case 'Buy Qty':
      //   return Align(
      //     alignment: alignment,
      //     child: Text(
      //       position.daybuyqty ?? '0',
      //       style: _getTextStyle(context, color: textColor),
      //     ),
      //   );
      // case 'Sell Qty':
      //   return Align(
      //     alignment: alignment,
      //     child: Text(
      //       position.daysellqty ?? '0',
      //       style: _getTextStyle(context, color: textColor),
      //     ),
      //   );
      // case 'Buy Avg':
      //   return Align(
      //     alignment: alignment,
      //     child: Text(
      //       position.daybuyavgprc ?? '0.00',
      //       style: _getTextStyle(context, color: textColor),
      //     ),
      //   );
      // case 'Sell Avg':
      //   return Align(
      //     alignment: alignment,
      //     child: Text(
      //       position.daysellavgprc ?? '0.00',
      //       style: _getTextStyle(context, color: textColor),
      //     ),
      //   );
      default:
        return const SizedBox.shrink();
    }
  }

  // Build fixed total P&L footer (outside scrollable area)
  Widget _buildFixedTotalFooter(
    BuildContext context,
    List<String> headers,
    Map<int, double> columnWidths,
    double totalPnl,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark,
                light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: shadcn.Table(
        columnWidths: columnWidths.map((index, width) {
          return MapEntry(index, shadcn.FixedTableSize(width));
        }),
        defaultRowHeight: const shadcn.FixedTableSize(40),
        rows: [
          shadcn.TableRow(
            cells: headers.map((header) {
              final columnIndex = _getColumnIndexForHeader(header);
              final isLastColumn = columnIndex == 6; // P&L column
              final isLTPColumn = columnIndex == 5; // LTP column - show "Total" label here

              // Cell padding matching other cells
              EdgeInsets cellPadding;
              if (columnIndex == 0) {
                cellPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4);
              } else if (columnIndex == 2) {
                cellPadding = const EdgeInsets.fromLTRB(16, 4, 4, 4);
              } else if (isLastColumn) {
                cellPadding = const EdgeInsets.fromLTRB(4, 4, 16, 4);
              } else {
                cellPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
              }

              Widget cellContent;
              if (isLTPColumn) {
                // Show "Total" label in LTP column (right-aligned)
                cellContent = Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total',
                    style: _getHeaderStyle(context).copyWith(
                      fontWeight: MyntFonts.semiBold,
                    ),
                  ),
                );
              } else if (isLastColumn) {
                // Show total P&L value
                final privacy = ref.watch(privacyProvider);
                final displayTotal = privacy.mask(totalPnl.toIndianFormat());
                cellContent = Align(
                  alignment: Alignment.centerRight,
                  child: Tooltip(
                    message: displayTotal,
                    child: Text(
                      displayTotal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _getTextStyle(context,
                          color: _getCellColor(
                              privacy.isPrivate ? 0.0 : totalPnl,
                              context)).copyWith(
                        fontWeight: MyntFonts.semiBold,
                      ),
                    ),
                  ),
                );
              } else {
                // Empty cell for other columns
                cellContent = const SizedBox.shrink();
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
                child: Padding(
                  padding: cellPadding,
                  child: cellContent,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Build checkbox cell
  Widget _buildCheckboxCell(
    PositionBookModel position,
    ThemesProvider theme,
    bool isClosed,
    PortfolioProvider positionBook,
  ) {
    return Consumer(
      builder: (context, ref, child) {
        final openPositions =
            ref.watch(portfolioProvider.select((p) => p.openPosition ?? []));
        // Match by both token AND product to differentiate same-symbol positions with different products (MIS vs NRML)
        final positionIndex = openPositions.indexWhere(
            (p) => p.token == position.token && p.sPrdtAli == position.sPrdtAli);
        // Closed positions should never show as selected (even if same token as open position)
        final isSelected = isClosed
            ? false
            : (positionIndex >= 0
                ? (openPositions[positionIndex].isExitSelection ?? false)
                : (position.isExitSelection ?? false));

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
              onChanged: isClosed
                  ? null
                  : (state) {
                      if (positionIndex >= 0) {
                        positionBook.selectExitPosition(positionIndex);
                      }
                    },
              enabled: !isClosed,
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

  // Build product cell - simple text with subtle colors
  Widget _buildProductCell(
    BuildContext context,
    PositionBookModel position,
    bool isClosed,
    Color? textColor,
  ) {
    final product = position.sPrdtAli ?? 'N/A';

    // Use secondary text color for all products - clean and subtle
    final productTextColor = isClosed
        ? (textColor ?? resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary))
        : resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary);

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        product,
        style: _getTextStyle(context, color: productTextColor),
      ),
    );
  }

  // Build instrument cell with 3-dot menu on hover
  Widget _buildInstrumentCell(
    BuildContext context,
    PositionBookModel position,
    ThemesProvider theme,
    bool isClosed,
    bool isRowHovered,
    PortfolioProvider positionBook, {
    int? rowIndex,
  }) {
    final colorScheme = shadcn.Theme.of(context).colorScheme;
    final textColor =
        isClosed ? colorScheme.mutedForeground : colorScheme.foreground;

    // No GestureDetector here - tap is handled by buildCellWithHover's onTap (covers entire cell including padding)
    // Buttons (Exit, 3-dot menu) have their own GestureDetectors and will handle their own taps
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      // Row layout: text shrinks with ellipsis when buttons appear (no overlay)
      child: Row(
          children: [
            // Instrument name - Expanded so it shrinks when buttons appear
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message:
                      '${_formatInstrumentText(position)}${position.exch != null && position.exch!.isNotEmpty && (position.expDate == null || position.expDate!.isEmpty) ? ' ${position.exch}' : ''}',
                  child: RichText(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _formatInstrumentText(position),
                          style: _getTextStyle(context, color: textColor),
                        ),
                        // Exchange (smaller font) - show for equity stocks
                        if (position.exch != null &&
                            position.exch!.isNotEmpty &&
                            (position.expDate == null ||
                                position.expDate!.isEmpty))
                          TextSpan(
                            text: ' ${position.exch}',
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
            // Exit button + 3-dot menu button - siblings in Row (no overlay)
            if (isRowHovered) ...[
              const SizedBox(width: 8),
              // Exit button (only for exitable positions)
              if (!isClosed &&
                  position.qty != "0" &&
                  position.sPrdtAli != "BO" &&
                  position.sPrdtAli != "CO" &&
                  !positionBook.isDay)
                _buildExitButton(context, position),
              if (!isClosed &&
                  position.qty != "0" &&
                  position.sPrdtAli != "BO" &&
                  position.sPrdtAli != "CO" &&
                  !positionBook.isDay)
                const SizedBox(width: 6),
              // 3-dot menu button
              _buildOptionsMenuButton(context, position, isClosed, positionBook, rowIndex: rowIndex),
          ],
        ],
      ),
    );
  }

  // Build Exit button with Icons.output icon (tertiary color) and tooltip
  Widget _buildExitButton(BuildContext context, PositionBookModel position) {
    return Tooltip(
      message: 'Exit',
      child: GestureDetector(
        onTap: () {
          // Clear hover state before navigating to prevent stuck hover
          _hoveredRowIndex.value = null;
          _handleExitPosition(position);
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
            Icons.output,
            size: 16,
            color: resolveThemeColor(context,
                dark: MyntColors.lossDark,
                light: MyntColors.tertiary),
          ),
        ),
      ),
    );
  }

  // Helper to build menu item matching profile dropdown style
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

  // Build the 3-dot options menu button with shadcn dropdown
  Widget _buildOptionsMenuButton(
    BuildContext context,
    PositionBookModel position,
    bool isClosed,
    PortfolioProvider positionBook, {
    int? rowIndex,
  }) {
    final iconColor = resolveThemeColor(context, dark: MyntColors.iconDark, light: MyntColors.icon);
    final textColor = resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          onTap: () {
            // Build menu items dynamically based on position state
            List<shadcn.MenuItem> menuItems = [];

            // Add option (for both open and closed positions, not BO/CO, not day positions)
            if (position.sPrdtAli != "BO" &&
                position.sPrdtAli != "CO" &&
                !positionBook.isDay) {
              menuItems.add(
                _buildMenuButton(
                  icon: Icons.add_circle_outline,
                  title: 'Add',
                  iconColor: iconColor,
                  textColor: textColor,
                  onPressed: (ctx) {
                    _closePopover();
                    _hoveredRowIndex.value = null;
                    _handleAddPosition(position);
                  },
                ),
              );
            }

            // Convert option (only for open positions)
            if (!isClosed && position.qty != "0") {
              menuItems.add(
                _buildMenuButton(
                  icon: Icons.swap_horiz,
                  title: 'Convert',
                  iconColor: iconColor,
                  textColor: textColor,
                  onPressed: (ctx) {
                    _closePopover();
                    _hoveredRowIndex.value = null;
                    _handleConvertPosition(position);
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
                  _hoveredRowIndex.value = null;
                  _showPositionDetail(position);
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
                  _hoveredRowIndex.value = null;
                  _handleChartTap(position);
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

  // Show position detail - Using shadcn.openSheet like holdings
  void _showPositionDetail(PositionBookModel position) {
    // Prevent double-click from opening overlay twice
    if (_isSheetOpening) return;
    _isSheetOpening = true;

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
          child: PositionDetailScreenWeb(
            positionList: position,
            parentContext: parentCtx, // Pass parent context for navigation
          ),
        );
      },
      position: shadcn.OverlayPosition.end,
    ).then((_) {
      // Reset flag when sheet closes
      _isSheetOpening = false;
    });
  }
  // Handle chart tap
  Future<void> _handleChartTap(PositionBookModel position) async {
    final scripData = ref.read(marketWatchProvider);
    await scripData.fetchScripQuoteIndex(
      position.token ?? "",
      position.exch ?? "",
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

  // Handle exit position
  Future<void> _handleExitPosition(PositionBookModel position) async {
    try {
      final scripData = ref.read(marketWatchProvider);
      await scripData.fetchScripInfo(
        position.token ?? "",
        position.exch ?? "",
        context,
        true,
      );

      if (scripData.scripInfoModel == null) {
        showResponsiveWarningMessage(
            context, "Unable to fetch scrip information");
        return;
      }

      final netQty = int.tryParse(position.netqty ?? "0") ?? 0;
      OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: position.exch ?? "",
        tSym: position.tsym ?? "",
        isExit: true,
        token: position.token ?? "",
        transType: netQty < 0 ? true : false,
        prd: position.prd ?? "",
        lotSize: position.netqty ?? "",
        ltp: position.lp ?? "0.00",
        perChange: position.perChange ?? "0.00",
        orderTpye: '',
        holdQty: position.netqty ?? '',
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
          context, "Error exiting position: ${e.toString()}");
    }
  }

  // Handle add position
  Future<void> _handleAddPosition(PositionBookModel position) async {
    try {
      final scripData = ref.read(marketWatchProvider);
      await scripData.fetchScripInfo(
        position.token ?? "",
        position.exch ?? "",
        context,
        true,
      );

      if (scripData.scripInfoModel == null) {
        showResponsiveWarningMessage(
            context, "Unable to fetch scrip information");
        return;
      }

      final lotSize = scripData.scripInfoModel!.ls?.toString() ?? "1";
      final netQty = int.tryParse(position.netqty ?? "0") ?? 0;

      OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: position.exch ?? "",
        tSym: position.tsym ?? "",
        isExit: false,
        token: position.token ?? "",
        transType: netQty < 0 ? false : true,
        prd: position.prd ?? "",
        lotSize: lotSize,
        ltp: position.lp ?? "0.00",
        perChange: position.perChange ?? "0.00",
        orderTpye: '',
        holdQty: position.netqty ?? '',
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
          context, "Error adding position: ${e.toString()}");
    }
  }

  // Handle convert position
  void _handleConvertPosition(PositionBookModel position) {
    _closePopover(); // Close the dropdown menu first
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return ConvertPositionDialogueWeb(convertPosition: position);
      },
    );
  }
}

// LTP, P&L, MTM cells now just display provider values directly
// No custom WebSocket cells needed - provider already handles updates
