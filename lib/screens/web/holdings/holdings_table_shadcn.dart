import 'dart:async';
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/material.dart' as material show showDialog;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/global_font_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/ledger_provider.dart';
import '../../../res/web_colors.dart';
import '../../../res/global_font_web.dart' hide WebTextStyles;
import '../../../sharedWidget/snack_bar.dart';
import '../../../routes/route_names.dart';
import '../../../utils/responsive_navigation.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../models/order_book_model/order_book_model.dart';
import 'holding_detail_screen_web.dart';

/// Production-ready Shadcn Table implementation for Holdings Screen
/// Maintains all features from DataTable2:
/// - Horizontal + vertical scrolling
/// - Fixed first column (Instrument)
/// - Sortable columns with visual indicators
/// - Row/column hover effects
/// - WebSocket-driven cell updates
/// - Responsive column configuration
/// - Action buttons on row hover
/// - Search functionality
class HoldingsTableShadcn extends ConsumerStatefulWidget {
  final List<dynamic> holdings;
  final String searchQuery;
  final ThemesProvider theme;

  const HoldingsTableShadcn({
    super.key,
    required this.holdings,
    required this.searchQuery,
    required this.theme,
  });

  @override
  ConsumerState<HoldingsTableShadcn> createState() =>
      _HoldingsTableShadcnState();
}

class _HoldingsTableShadcnState extends ConsumerState<HoldingsTableShadcn> {
  // Sorting state
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Hover state - using ValueNotifier for performance
  final ValueNotifier<String?> _hoveredRowToken = ValueNotifier<String?>(null);
  final ValueNotifier<int?> _hoveredColumnIndex = ValueNotifier<int?>(null);

  // Prevent double-click from opening dialog twice
  bool _isDialogOpening = false;

  // Responsive breakpoints
  static const double _mobileBreakpoint = 768;
  static const double _tabletBreakpoint = 1024;
  static const double _desktopBreakpoint = 1440;

  @override
  void dispose() {
    _hoveredRowToken.dispose();
    _hoveredColumnIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Get responsive column configuration
    final responsiveConfig = _getResponsiveHoldingColumns(screenWidth);
    final headers = List<String>.from(responsiveConfig['headers'] as List);
    final columnMinWidth =
        Map<String, double>.from(responsiveConfig['columnMinWidth'] as Map);

    // Calculate table height
    const padding = 32.0;
    const headerHeight = 120.0;
    const tabsAndSearchHeight = 100.0;
    const spacing = 24.0 + 16.0;
    const bottomMargin = 20.0;
    final tableHeight = screenHeight -
        padding -
        headerHeight -
        tabsAndSearchHeight -
        spacing -
        bottomMargin;
    final maxHeight = screenHeight * 0.75;
    final calculatedHeight = tableHeight > maxHeight
        ? maxHeight
        : (tableHeight > 400 ? tableHeight : 400.0);

    // Get filtered and sorted holdings
    final filteredHoldings = _getFilteredAndSortedHoldings();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        height: calculatedHeight,
        decoration: BoxDecoration(
          border: Border.all(
            color: ShadcnDarkColors.border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
          color: ShadcnDarkColors.background,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ScrollableClient(
              // Enable diagonal scrolling for panning in both directions
              diagonalDragBehavior: DiagonalDragBehavior.free,
              builder: (context, offset, viewportSize, child) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 1200, // Minimum table width
                    height: constraints.maxHeight,
                    child: Column(
                      children: [
                        // Header Row
                        _buildHeaderRow(headers, columnMinWidth, screenWidth),

                        // Divider
                        Container(
                          height: 1,
                          color: ShadcnDarkColors.border,
                        ),

                        // Data Rows
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children:
                                  filteredHoldings.asMap().entries.map((entry) {
                                final holding = entry.value;
                                return _buildDataRow(holding, entry.key,
                                    headers, columnMinWidth, screenWidth);
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Build table header row with sortable columns
  Widget _buildHeaderRow(List<String> headers,
      Map<String, double> columnMinWidth, double screenWidth) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: ShadcnDarkColors.background,
        border: Border(
          bottom: BorderSide(
            color: ShadcnDarkColors.border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: headers.asMap().entries.map((entry) {
          final index = entry.key;
          final header = entry.value;
          final isNumeric = _isNumericColumn(header);
          final columnIndex = _getColumnIndexForHeader(header);
          final minWidth = columnMinWidth[header] ?? 120.0;

          return Container(
            width: minWidth,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ValueListenableBuilder<int?>(
              valueListenable: _hoveredColumnIndex,
              builder: (context, hoveredIndex, child) {
                final isHovered = hoveredIndex == columnIndex;

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => _hoveredColumnIndex.value = columnIndex,
                  onExit: (_) => _hoveredColumnIndex.value = null,
                  child: GestureDetector(
                    onTap: () => _onManualSort(columnIndex),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isHovered
                            ? ShadcnDarkColors.popover.withOpacity(0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisAlignment: isNumeric
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              header,
                              style: WebTextStyles.tableHeader(
                                isDarkTheme: true,
                                color: ShadcnDarkColors.neutral,
                              ),
                              textAlign:
                                  isNumeric ? TextAlign.right : TextAlign.left,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _sortColumnIndex == columnIndex
                                ? (_sortAscending
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward)
                                : Icons.unfold_more,
                            size: 16,
                            color: _sortColumnIndex == columnIndex
                                ? ShadcnDarkColors.foreground
                                : ShadcnDarkColors.neutral.withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Build individual data row with hover effects and action buttons
  Widget _buildDataRow(
    dynamic holding,
    int index,
    List<String> headers,
    Map<String, double> columnMinWidth,
    double screenWidth,
  ) {
    final exchTsym = holding.exchTsym != null && holding.exchTsym!.isNotEmpty
        ? holding.exchTsym![0]
        : null;
    final token = exchTsym?.token ?? '';
    final uniqueId = '$token$index';

    return ValueListenableBuilder<String?>(
      valueListenable: _hoveredRowToken,
      builder: (context, hoveredToken, child) {
        final isHovered = hoveredToken == uniqueId;

        return MouseRegion(
          onEnter: (_) => _hoveredRowToken.value = uniqueId,
          onExit: (_) => _hoveredRowToken.value = null,
          child: GestureDetector(
            onTap: () => _showHoldingDetail(holding),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color:
                    isHovered ? ShadcnDarkColors.popover : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: ShadcnDarkColors.border,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: headers.map((header) {
                  final minWidth = columnMinWidth[header] ?? 120.0;
                  final isNumeric = _isNumericColumn(header);

                  return Container(
                    width: minWidth,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    alignment: isNumeric
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: _buildCellContent(
                      header,
                      holding,
                      exchTsym,
                      uniqueId,
                      token,
                      isHovered,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build cell content - static or dynamic based on column type
  Widget _buildCellContent(
    String column,
    dynamic holding,
    dynamic exchTsym,
    String uniqueId,
    String token,
    bool isRowHovered,
  ) {
    switch (column) {
      case 'Instrument':
        return _buildInstrumentCell(holding, exchTsym, uniqueId, isRowHovered);

      case 'Net Qty':
        final qty = holding.currentQty ?? 0;
        // T1 qty: npoadt1qty for Non-POA clients, btstqty for POA clients
        final t1Qty = int.parse(holding.npoadt1qty ?? "0") + int.parse(holding.btstqty ?? "0");
        final qtyText = qty > 0 ? '+$qty' : '$qty';
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (t1Qty > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: ShadcnDarkColors.mutedForeground.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'T1: $t1Qty',
                  style: WebTextStyles.custom(
                    fontSize: 10,
                    isDarkTheme: true,
                    color: ShadcnDarkColors.mutedForeground,
                    fontWeight: WebFonts.medium,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              qtyText,
              style: WebTextStyles.custom(
                fontSize: 13,
                isDarkTheme: true,
                color: _getQtyColor(qty),
                fontWeight: WebFonts.medium,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        );

      case 'Avg Price':
        final avgPrc = holding.avgPrc != null && holding.avgPrc!.isNotEmpty
            ? holding.avgPrc!
            : '0.00';
        return Text(avgPrc, textAlign: TextAlign.right);

      case 'Invested':
        return Text(holding.invested ?? '0.00', textAlign: TextAlign.right);

      // Dynamic columns with WebSocket updates
      case 'LTP':
        if (token.isEmpty) {
          return Text(exchTsym?.lp ?? '0.00', textAlign: TextAlign.right);
        }
        return _LTPCell(
          token: token,
          initialLtp: exchTsym?.lp ?? '0.00',
        );

      case 'Current Value':
        if (token.isEmpty) {
          return Text(holding.currentValue ?? '0.00',
              textAlign: TextAlign.right);
        }
        // Include npoadt1qty (Non-POA T1 holdings) in financial calculations
        final int curValTotalQty = (holding.currentQty ?? 0) + int.parse(holding.npoadt1qty ?? "0");
        return _CurrentValueCell(
          token: token,
          qty: curValTotalQty,
          initialValue: holding.currentValue ?? '0.00',
        );

      case 'Day P&L':
        if (token.isEmpty) {
          return _buildColoredText(exchTsym?.oneDayChg ?? '0.00');
        }
        return _DayPnLCell(
          token: token,
          initialValue: exchTsym?.oneDayChg ?? '0.00',
        );

      case 'Day %':
        if (token.isEmpty) {
          return _buildColoredText('${exchTsym?.perChange ?? '0.00'}%');
        }
        return _DayPercentCell(
          token: token,
          initialValue: exchTsym?.perChange ?? '0.00',
        );

      case 'Overall P&L':
        if (token.isEmpty) {
          return _buildColoredText(exchTsym?.profitNloss ?? '0.00');
        }
        // Include npoadt1qty (Non-POA T1 holdings) in financial calculations
        final int pnlTotalQty = (holding.currentQty ?? 0) + int.parse(holding.npoadt1qty ?? "0");
        return _OverallPnLCell(
          token: token,
          qty: pnlTotalQty,
          avgPrice: double.tryParse(holding.avgPrc ?? '0') ?? 0.0,
          rpnl: double.tryParse(holding.rpnl ?? '0') ?? 0.0,
          initialValue: exchTsym?.profitNloss ?? '0.00',
        );

      case 'Overall %':
        if (token.isEmpty) {
          return _buildColoredText('${exchTsym?.pNlChng ?? '0.00'}%');
        }
        return _OverallPercentCell(
          token: token,
          avgPrice: double.tryParse(holding.avgPrc ?? '0') ?? 0.0,
          initialValue: exchTsym?.pNlChng ?? '0.00',
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// Build instrument cell with action buttons on hover
  Widget _buildInstrumentCell(
    dynamic holding,
    dynamic exchTsym,
    String uniqueId,
    bool isRowHovered,
  ) {
    if (exchTsym == null) {
      return const Text('N/A');
    }

    final displayText = '${exchTsym.tsym ?? ''} ${exchTsym.exch ?? ''}';

    return Row(
      children: [
        // Instrument name
        Expanded(
          child: Text(
            displayText,
            style: WebTextStyles.custom(
              fontSize: 13,
              isDarkTheme: true,
              color: ShadcnDarkColors.foreground,
              fontWeight: WebFonts.medium,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Action buttons - appear on hover
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: isRowHovered ? null : 0,
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: !isRowHovered,
            child: AnimatedOpacity(
              opacity: isRowHovered ? 1 : 0,
              duration: const Duration(milliseconds: 140),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 8),
                  if ((holding.currentQty ?? 0) > 0) ...{
                    _buildHoverButton(
                      label: 'Add',
                      color: Colors.white,
                      backgroundColor: WebDarkColors.primary,
                      onPressed: () => _handleAddHolding(holding, exchTsym),
                    ),
                    const SizedBox(width: 6),
                  },
                  if ((holding.currentQty ?? 0) > 0) ...{
                    _buildHoverButton(
                      label: 'Exit',
                      color: Colors.white,
                      backgroundColor: WebDarkColors.tertiary,
                      onPressed: () => _handleExitHolding(holding, exchTsym),
                    ),
                    const SizedBox(width: 6),
                  },
                  _buildHoverButton(
                    icon: Icons.bar_chart,
                    color: Colors.black,
                    backgroundColor: Colors.white,
                    onPressed: () => _handleChartTap(holding, exchTsym),
                  ),
                  const SizedBox(width: 6),
                  _buildHoverButton(
                    label: 'Pledge',
                    color: Colors.black,
                    backgroundColor: Colors.white,
                    onPressed: _handlePledgeUnpledge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Helper: Build hover action button
  Widget _buildHoverButton({
    String? label,
    IconData? icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    final isLongLabel = label != null && label.length > 1;

    return SizedBox(
      width: isLongLabel ? null : 25,
      height: 25,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          splashColor: color.withOpacity(0.15),
          highlightColor: color.withOpacity(0.08),
          onTap: onPressed,
          child: Container(
            padding:
                isLongLabel ? const EdgeInsets.symmetric(horizontal: 8) : null,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 16, color: color)
                  : Text(
                      label ?? "",
                      style: WebTextStyles.buttonXs(
                        isDarkTheme: widget.theme.isDarkMode,
                        color: color,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper: Build colored text for P&L values
  Widget _buildColoredText(String value) {
    return Text(
      value,
      style: WebTextStyles.custom(
        fontSize: 13,
        isDarkTheme: true,
        color: _getValueColor(value),
        fontWeight: WebFonts.medium,
      ),
      textAlign: TextAlign.right,
    );
  }

  // ==================== RESPONSIVE CONFIGURATION ====================

  Map<String, dynamic> _getResponsiveHoldingColumns(double screenWidth) {
    if (screenWidth < _mobileBreakpoint) {
      return {
        'headers': ['Instrument', 'Net Qty', 'LTP', 'Day P&L', 'Overall P&L'],
        'columnMinWidth': {
          'Instrument': 280.0,
          'Net Qty': 120.0,
          'LTP': 110.0,
          'Day P&L': 130.0,
          'Overall P&L': 140.0,
        },
      };
    } else if (screenWidth < _tabletBreakpoint) {
      return {
        'headers': [
          'Instrument',
          'Net Qty',
          'Avg Price',
          'LTP',
          'Current Value',
          'Day P&L',
          'Overall P&L'
        ],
        'columnMinWidth': {
          'Instrument': 280.0,
          'Net Qty': 110.0,
          'Avg Price': 120.0,
          'LTP': 100.0,
          'Current Value': 165.0,
          'Day P&L': 120.0,
          'Overall P&L': 155.0,
        },
      };
    } else if (screenWidth < _desktopBreakpoint) {
      return {
        'headers': [
          'Instrument',
          'Net Qty',
          'Avg Price',
          'LTP',
          'Invested',
          'Current Value',
          'Day P&L',
          'Overall P&L',
          'Overall %'
        ],
        'columnMinWidth': {
          'Instrument': 280.0,
          'Net Qty': 110.0,
          'Avg Price': 120.0,
          'LTP': 100.0,
          'Invested': 120.0,
          'Current Value': 165.0,
          'Day P&L': 120.0,
          'Overall P&L': 155.0,
          'Overall %': 110.0,
        },
      };
    } else {
      return {
        'headers': [
          'Instrument',
          'Net Qty',
          'Avg Price',
          'LTP',
          'Invested',
          'Current Value',
          'Day P&L',
          'Day %',
          'Overall P&L',
          'Overall %'
        ],
        'columnMinWidth': {
          'Instrument': 300.0,
          'Net Qty': 120.0,
          'Avg Price': 130.0,
          'LTP': 110.0,
          'Invested': 130.0,
          'Current Value': 220.0,
          'Day P&L': 150.0,
          'Day %': 110.0,
          'Overall P&L': 165.0,
          'Overall %': 120.0,
        },
      };
    }
  }

  // ==================== SORTING & FILTERING ====================

  List<dynamic> _getFilteredAndSortedHoldings() {
    List<dynamic> holdings = widget.holdings;

    // Apply search filter
    if (widget.searchQuery.isNotEmpty) {
      holdings = holdings.where((holding) {
        if (holding.exchTsym != null && holding.exchTsym!.isNotEmpty) {
          final exchTsym = holding.exchTsym![0];
          final symbol = exchTsym.tsym?.toLowerCase() ?? '';
          final exch = exchTsym.exch?.toLowerCase() ?? '';
          final searchLower = widget.searchQuery.toLowerCase();
          return symbol.contains(searchLower) || exch.contains(searchLower);
        }
        return false;
      }).toList();
    }

    // Apply sorting
    if (_sortColumnIndex != null) {
      holdings.sort((a, b) {
        int comparison = _compareHoldings(a, b, _sortColumnIndex!);
        return _sortAscending ? comparison : -comparison;
      });
    }

    return holdings;
  }

  int _compareHoldings(dynamic a, dynamic b, int columnIndex) {
    switch (columnIndex) {
      case 0: // Instrument
        final aExchTsym =
            a.exchTsym?.isNotEmpty == true ? a.exchTsym![0] : null;
        final bExchTsym =
            b.exchTsym?.isNotEmpty == true ? b.exchTsym![0] : null;
        return (aExchTsym?.tsym ?? '').compareTo(bExchTsym?.tsym ?? '');

      case 1: // Net Qty
        final aQty = int.tryParse(a.currentQty?.toString() ?? '0') ?? 0;
        final bQty = int.tryParse(b.currentQty?.toString() ?? '0') ?? 0;
        return aQty.compareTo(bQty);

      case 2: // Avg Price
        final aExchTsym =
            a.exchTsym?.isNotEmpty == true ? a.exchTsym![0] : null;
        final bExchTsym =
            b.exchTsym?.isNotEmpty == true ? b.exchTsym![0] : null;
        final aPrice = double.tryParse(aExchTsym?.close ?? '0') ?? 0;
        final bPrice = double.tryParse(bExchTsym?.close ?? '0') ?? 0;
        return aPrice.compareTo(bPrice);

      case 3: // LTP
        final aExchTsym =
            a.exchTsym?.isNotEmpty == true ? a.exchTsym![0] : null;
        final bExchTsym =
            b.exchTsym?.isNotEmpty == true ? b.exchTsym![0] : null;
        final aLtp = double.tryParse(aExchTsym?.lp ?? '0') ?? 0;
        final bLtp = double.tryParse(bExchTsym?.lp ?? '0') ?? 0;
        return aLtp.compareTo(bLtp);

      case 4: // Invested
        final aInvested = double.tryParse(a.invested ?? '0') ?? 0;
        final bInvested = double.tryParse(b.invested ?? '0') ?? 0;
        return aInvested.compareTo(bInvested);

      case 5: // Current Value
        final aValue = double.tryParse(a.currentValue ?? '0') ?? 0;
        final bValue = double.tryParse(b.currentValue ?? '0') ?? 0;
        return aValue.compareTo(bValue);

      case 6: // Day P&L
        final aExchTsym =
            a.exchTsym?.isNotEmpty == true ? a.exchTsym![0] : null;
        final bExchTsym =
            b.exchTsym?.isNotEmpty == true ? b.exchTsym![0] : null;
        final aDayPnL = double.tryParse(aExchTsym?.oneDayChg ?? '0') ?? 0;
        final bDayPnL = double.tryParse(bExchTsym?.oneDayChg ?? '0') ?? 0;
        return aDayPnL.compareTo(bDayPnL);

      case 7: // Day %
        final aExchTsym =
            a.exchTsym?.isNotEmpty == true ? a.exchTsym![0] : null;
        final bExchTsym =
            b.exchTsym?.isNotEmpty == true ? b.exchTsym![0] : null;
        final aDayPercent = double.tryParse(aExchTsym?.perChange ?? '0') ?? 0;
        final bDayPercent = double.tryParse(bExchTsym?.perChange ?? '0') ?? 0;
        return aDayPercent.compareTo(bDayPercent);

      case 8: // Overall P&L
        final aExchTsym =
            a.exchTsym?.isNotEmpty == true ? a.exchTsym![0] : null;
        final bExchTsym =
            b.exchTsym?.isNotEmpty == true ? b.exchTsym![0] : null;
        final aOverallPnL = double.tryParse(aExchTsym?.profitNloss ?? '0') ?? 0;
        final bOverallPnL = double.tryParse(bExchTsym?.profitNloss ?? '0') ?? 0;
        return aOverallPnL.compareTo(bOverallPnL);

      case 9: // Overall %
        final aExchTsym =
            a.exchTsym?.isNotEmpty == true ? a.exchTsym![0] : null;
        final bExchTsym =
            b.exchTsym?.isNotEmpty == true ? b.exchTsym![0] : null;
        final aOverallPercent = double.tryParse(aExchTsym?.pNlChng ?? '0') ?? 0;
        final bOverallPercent = double.tryParse(bExchTsym?.pNlChng ?? '0') ?? 0;
        return aOverallPercent.compareTo(bOverallPercent);

      default:
        return 0;
    }
  }

  void _onManualSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  // ==================== HELPER METHODS ====================

  int _getColumnIndexForHeader(String header) {
    switch (header) {
      case 'Instrument':
        return 0;
      case 'Net Qty':
        return 1;
      case 'Avg Price':
        return 2;
      case 'LTP':
        return 3;
      case 'Invested':
        return 4;
      case 'Current Value':
        return 5;
      case 'Day P&L':
        return 6;
      case 'Day %':
        return 7;
      case 'Overall P&L':
        return 8;
      case 'Overall %':
        return 9;
      default:
        return -1;
    }
  }

  bool _isNumericColumn(String header) {
    return header != 'Instrument';
  }

  Color _getValueColor(String value) {
    final numValue = double.tryParse(value.replaceAll('%', '')) ?? 0.0;
    if (numValue > 0) return ShadcnDarkColors.success;
    if (numValue < 0) return ShadcnDarkColors.error;
    return ShadcnDarkColors.neutral;
  }

  Color _getQtyColor(int qty) {
    if (qty > 0) return ShadcnDarkColors.success;
    if (qty < 0) return ShadcnDarkColors.error;
    return ShadcnDarkColors.neutral;
  }

  void _showHoldingDetail(dynamic holding) {
    // Prevent double-click from opening dialog twice
    if (_isDialogOpening) return;

    final exchTsym = holding.exchTsym != null && holding.exchTsym!.isNotEmpty
        ? holding.exchTsym![0]
        : null;

    if (exchTsym == null) return;

    _isDialogOpening = true;

    material.showDialog(
      context: context,
      builder: (context) => HoldingDetailScreenWeb(
        holding: holding,
        exchTsym: exchTsym,
      ),
    ).then((_) {
      // Reset flag when dialog closes
      _isDialogOpening = false;
    });
  }

  // ==================== ACTION HANDLERS ====================

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

      final scripInfo = scripData.scripInfoModel!;
      final lotSize =
          exchTsym.ls?.toString() ?? scripInfo.ls?.toString() ?? "1";

      OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: exchTsym.exch ?? "",
        tSym: exchTsym.tsym ?? "",
        isExit: true,
        token: '',
        transType: false,
        prd: holding.prd ?? "",
        lotSize: lotSize,
        ltp: exchTsym.lp ?? "0.00",
        perChange: exchTsym.perChange ?? "0.00",
        orderTpye: holding.sPrdtAli ?? '',
        holdQty: holding.saleableQty?.toString() ?? '',
        isModify: false,
        raw: {},
      );

      ResponsiveNavigation.toPlaceOrderScreen(
        context: context,
        arguments: {
          "orderArg": orderArgs,
          "scripInfo": scripInfo,
          "isBskt": "",
        },
      );
    } catch (e) {
      showResponsiveWarningMessage(
          context, "Error exiting holding: ${e.toString()}");
    }
  }

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

  void _handlePledgeUnpledge() async {
    final ledgerdate = ref.read(ledgerProvider);
    if (ledgerdate.pledgeandunpledge == null) {
      await ledgerdate.getCurrentDate("pandu");
      ledgerdate.fetchpledgeandunpledge(context);
    }
    Navigator.pushNamed(context, Routes.pledgeandun, arguments: "DDDDD");
  }
}

// ==================== ISOLATED CELL WIDGETS WITH WEBSOCKET ====================

/// Isolated LTP Cell - Only rebuilds when LTP changes via WebSocket
class _LTPCell extends ConsumerStatefulWidget {
  final String token;
  final String initialLtp;

  const _LTPCell({required this.token, required this.initialLtp});

  @override
  ConsumerState<_LTPCell> createState() => _LTPCellState();
}

class _LTPCellState extends ConsumerState<_LTPCell> {
  late String ltp;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    ltp = widget.initialLtp;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newLtp = data[widget.token]['lp']?.toString();
      if (newLtp != null &&
          newLtp != ltp &&
          newLtp != '0.00' &&
          newLtp != 'null') {
        setState(() => ltp = newLtp);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(ltp, textAlign: TextAlign.right);
  }
}

/// Isolated Current Value Cell
class _CurrentValueCell extends ConsumerStatefulWidget {
  final String token;
  final int qty;
  final String initialValue;

  const _CurrentValueCell({
    required this.token,
    required this.qty,
    required this.initialValue,
  });

  @override
  ConsumerState<_CurrentValueCell> createState() => _CurrentValueCellState();
}

class _CurrentValueCellState extends ConsumerState<_CurrentValueCell> {
  late String currentValue;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    currentValue = widget.initialValue;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newLtp = data[widget.token]['lp']?.toString();
      if (newLtp != null && newLtp != '0.00' && newLtp != 'null') {
        final ltp = double.tryParse(newLtp) ?? 0.0;
        final newValue = (ltp * widget.qty).toStringAsFixed(2);
        if (newValue != currentValue) {
          setState(() => currentValue = newValue);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(currentValue, textAlign: TextAlign.right);
  }
}

/// Isolated Day P&L Cell
class _DayPnLCell extends ConsumerStatefulWidget {
  final String token;
  final String initialValue;

  const _DayPnLCell({
    required this.token,
    required this.initialValue,
  });

  @override
  ConsumerState<_DayPnLCell> createState() => _DayPnLCellState();
}

class _DayPnLCellState extends ConsumerState<_DayPnLCell> {
  late String dayPnL;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    dayPnL = widget.initialValue;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newValue = data[widget.token]['chng']?.toString();
      if (newValue != null && newValue != dayPnL && newValue != 'null') {
        setState(() => dayPnL = newValue);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Color _getValueColor(String value) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) return ShadcnDarkColors.success;
    if (numValue < 0) return ShadcnDarkColors.error;
    return ShadcnDarkColors.neutral;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      dayPnL,
      style: WebTextStyles.custom(
        fontSize: 13,
        isDarkTheme: true,
        color: _getValueColor(dayPnL),
        fontWeight: WebFonts.medium,
      ),
      textAlign: TextAlign.right,
    );
  }
}

/// Isolated Day % Cell
class _DayPercentCell extends ConsumerStatefulWidget {
  final String token;
  final String initialValue;

  const _DayPercentCell({
    required this.token,
    required this.initialValue,
  });

  @override
  ConsumerState<_DayPercentCell> createState() => _DayPercentCellState();
}

class _DayPercentCellState extends ConsumerState<_DayPercentCell> {
  late String dayPercent;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    dayPercent = widget.initialValue;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newValue = data[widget.token]['pc']?.toString();
      if (newValue != null && newValue != dayPercent && newValue != 'null') {
        setState(() => dayPercent = newValue);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Color _getValueColor(String value) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) return ShadcnDarkColors.success;
    if (numValue < 0) return ShadcnDarkColors.error;
    return ShadcnDarkColors.neutral;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$dayPercent%',
      style: WebTextStyles.custom(
        fontSize: 13,
        isDarkTheme: true,
        color: _getValueColor(dayPercent),
        fontWeight: WebFonts.medium,
      ),
      textAlign: TextAlign.right,
    );
  }
}

/// Isolated Overall P&L Cell
class _OverallPnLCell extends ConsumerStatefulWidget {
  final String token;
  final int qty;
  final double avgPrice;
  final double rpnl;
  final String initialValue;

  const _OverallPnLCell({
    required this.token,
    required this.qty,
    required this.avgPrice,
    required this.rpnl,
    required this.initialValue,
  });

  @override
  ConsumerState<_OverallPnLCell> createState() => _OverallPnLCellState();
}

class _OverallPnLCellState extends ConsumerState<_OverallPnLCell> {
  late String overallPnL;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    overallPnL = widget.initialValue;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newLtp = data[widget.token]['lp']?.toString();
      if (newLtp != null && newLtp != '0.00' && newLtp != 'null') {
        final ltp = double.tryParse(newLtp) ?? 0.0;
        // Mirror PortfolioProvider._updateDerivedValues: total per-row P&L is
        // unrealized + realized. Sold rows (qty=0) keep showing rpnl instead
        // of flickering to 0 on each tick.
        final newPnL =
            (((ltp - widget.avgPrice) * widget.qty) + widget.rpnl)
                .toStringAsFixed(2);
        if (newPnL != overallPnL) {
          setState(() => overallPnL = newPnL);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Color _getValueColor(String value) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) return ShadcnDarkColors.success;
    if (numValue < 0) return ShadcnDarkColors.error;
    return ShadcnDarkColors.neutral;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      overallPnL,
      style: WebTextStyles.custom(
        fontSize: 13,
        isDarkTheme: true,
        color: _getValueColor(overallPnL),
        fontWeight: WebFonts.medium,
      ),
      textAlign: TextAlign.right,
    );
  }
}

/// Isolated Overall % Cell
class _OverallPercentCell extends ConsumerStatefulWidget {
  final String token;
  final double avgPrice;
  final String initialValue;

  const _OverallPercentCell({
    required this.token,
    required this.avgPrice,
    required this.initialValue,
  });

  @override
  ConsumerState<_OverallPercentCell> createState() =>
      _OverallPercentCellState();
}

class _OverallPercentCellState extends ConsumerState<_OverallPercentCell> {
  late String overallPercent;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    overallPercent = widget.initialValue;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newLtp = data[widget.token]['lp']?.toString();
      if (newLtp != null && newLtp != '0.00' && newLtp != 'null') {
        final ltp = double.tryParse(newLtp) ?? 0.0;
        final newPercent = widget.avgPrice > 0
            ? (((ltp - widget.avgPrice) / widget.avgPrice) * 100)
                .toStringAsFixed(2)
            : '0.00';
        if (newPercent != overallPercent) {
          setState(() => overallPercent = newPercent);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Color _getValueColor(String value) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) return ShadcnDarkColors.success;
    if (numValue < 0) return ShadcnDarkColors.error;
    return ShadcnDarkColors.neutral;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$overallPercent%',
      style: WebTextStyles.custom(
        fontSize: 13,
        isDarkTheme: true,
        color: _getValueColor(overallPercent),
        fontWeight: WebFonts.medium,
      ),
      textAlign: TextAlign.right,
    );
  }
}
