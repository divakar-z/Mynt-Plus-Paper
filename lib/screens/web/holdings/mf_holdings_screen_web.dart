import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:mynt_plus/res/global_font_web.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../../provider/mf_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/global_state_text.dart';
import '../../../../res/res.dart';
import '../../../../res/web_colors.dart';
import '../../../res/global_font_web.dart' hide WebTextStyles;
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import 'mf_holding_detail_screen_web.dart';
import '../ordersbook/mf/redeem_bottom_sheet_web.dart';

class MfHoldingsScreenWeb extends ConsumerStatefulWidget {
  final bool showSummaryCards;
  final String? searchQuery;

  const MfHoldingsScreenWeb({
    super.key,
    this.showSummaryCards = true,
    this.searchQuery,
  });

  @override
  ConsumerState<MfHoldingsScreenWeb> createState() =>
      _MfHoldingsScreenWebState();
}

class _MfHoldingsScreenWebState extends ConsumerState<MfHoldingsScreenWeb> {
  // ✅ Removed _searchQuery - use widget.searchQuery directly since parent uses ValueNotifier
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // ✅ Use ValueNotifier instead of setState to avoid rebuilding entire widget
  final ValueNotifier<String?> _hoveredRowToken = ValueNotifier<String?>(null);
  final ValueNotifier<int?> _hoveredColumnIndex = ValueNotifier<int?>(null);

  // Popover state management for 3-dot dropdown menu
  shadcn.PopoverController? _activePopoverController;
  String? _popoverRowId;
  bool _isHoveringDropdown = false;
  Timer? _popoverCloseTimer;

  @override
  void initState() {
    super.initState();
    // Fetch mutual fund holdings data when screen initializes
    // (old MF holdings API decommissioned — demat endpoint is the source)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ref.read(mfProvider).fetchmfholdingnew();
      ref.read(mfProvider).fetchmfdematholding();
    });
    // Add listener for hover changes to manage popover
    _hoveredRowToken.addListener(_onHoverChanged);
  }

  // Listener for hover changes to manage popover closing
  void _onHoverChanged() {
    final currentHoveredId = _hoveredRowToken.value;
    // If we have an active popover and the user hovers over a different row
    if (_popoverRowId != null &&
        currentHoveredId != null &&
        currentHoveredId != _popoverRowId &&
        !_isHoveringDropdown) {
      _startPopoverCloseTimer();
    }
  }

  void _startPopoverCloseTimer() {
    _cancelPopoverCloseTimer();
    _popoverCloseTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_isHoveringDropdown && _hoveredRowToken.value != _popoverRowId) {
        _closePopover();
      }
    });
  }

  void _cancelPopoverCloseTimer() {
    _popoverCloseTimer?.cancel();
    _popoverCloseTimer = null;
  }

  void _closePopover() {
    _activePopoverController?.close();
    _activePopoverController = null;
    _popoverRowId = null;
    _isHoveringDropdown = false;
  }

  // ✅ REMOVED: didUpdateWidget - no longer needed since we use widget.searchQuery directly

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _hoveredRowToken.dispose();
    _hoveredColumnIndex.dispose();
    _hoveredRowToken.removeListener(_onHoverChanged);
    _popoverCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mfData = ref.watch(mfProvider);
    final theme = ref.read(themeProvider);

    if (mfData.holdstatload ?? false) {
      return Center(child: MyntLoader.simple());
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: RefreshIndicator(
        onRefresh: () async {
          // await mfData.fetchmfholdingnew();
          await mfData.fetchmfdematholding();
        },
        child: widget.showSummaryCards
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Summary Cards Section
                    _buildSummaryCards(theme, mfData),
                    const SizedBox(height: 24),
                    // Main Content Area - Expanded to fill remaining space
                    Expanded(
                      child: _buildMainContent(theme, mfData),
                    ),
                  ],
                ),
              )
            : SizedBox.expand(
                child: _buildMainContent(theme, mfData),
              ),
      ),
    );
  }

  Widget _buildSummaryCards(ThemesProvider theme, MFProvider mfData) {
    final summary = mfData.mfholdingnew?.summary;
    final investedValue = _formatValue(summary?.invested);
    final currentValue = _formatValue(summary?.currentValue);
    final absReturnValue = _formatValue(summary?.absReturnValue);
    final absReturnPercent =
        _formatValue(summary?.absReturnPercent?.toString());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.isDarkMode
            ? colors.kColorLightGreyDarkTheme
            : colors.kColorLightGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.isDarkMode ? colors.dividerDark : colors.dividerLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main stats row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Invested',
                  investedValue,
                  _getStatValueColor(investedValue, theme),
                  theme,
                ),
              ),
              _buildDivider(theme),
              Expanded(
                child: _buildStatItem(
                  'Current Value',
                  currentValue,
                  _getStatValueColor(currentValue, theme),
                  theme,
                ),
              ),
              _buildDivider(theme),
              Expanded(
                child: _buildStatItem(
                  'Returns',
                  absReturnValue,
                  _getValueColor(absReturnValue, theme),
                  theme,
                ),
              ),
              _buildDivider(theme),
              Expanded(
                child: _buildStatItem(
                  'Percentage',
                  '$absReturnPercent%',
                  _getValueColor(absReturnPercent, theme),
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, Color valueColor, ThemesProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TextWidget.subText(
          text: label,
          theme: false,
          color: const Color(0xFF6B7280), // Dark grey
          fw: 2,
        ),
        const SizedBox(height: 8),
        TextWidget.headText(
          text: value,
          theme: false,
          color: valueColor,
          fw: 2,
        ),
      ],
    );
  }

  Widget _buildDivider(ThemesProvider theme) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFE5E7EB), // Light grey divider
    );
  }

  Widget _buildMainContent(ThemesProvider theme, MFProvider mfData) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Bar - only show when standalone (with summary cards)
          if (widget.showSummaryCards) _buildActionBar(theme, mfData),

          // Table - Expanded to fill remaining space
          Expanded(
            child: _buildHoldingsTable(theme, mfData),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(ThemesProvider theme, MFProvider mfData) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.isDarkMode ? WebDarkColors.divider : WebColors.divider,
          ),
        ),
      ),
      child: const Row(
        children: [
          // Spacer to push search and refresh to the right

          SizedBox(width: 8),
        ],
      ),
    );
  }

  // Responsive breakpoints
  static const double _mobileBreakpoint = 768;
  static const double _tabletBreakpoint = 1024;

  // Helper method to get responsive column configuration
  Map<String, dynamic> _getResponsiveMfHoldingColumns(double screenWidth) {
    if (screenWidth < _mobileBreakpoint) {
      // Mobile: Show only essential columns
      return {
        'headers': ['Fund Name', 'Units', 'Current NAV', 'P&L', 'P&L %'],
        'columnMinWidth': {
          'Fund Name': 250,
          'Units': 100,
          'Current NAV': 120,
          'P&L': 110,
          'P&L %': 100,
        },
      };
    } else if (screenWidth < _tabletBreakpoint) {
      // Tablet: Show most columns
      return {
        'headers': [
          'Fund Name',
          'Units',
          'Avg NAV',
          'Current NAV',
          'Current Value',
          'P&L',
          'P&L %'
        ],
        'columnMinWidth': {
          'Fund Name': 250,
          'Units': 95,
          'Avg NAV': 110,
          'Current NAV': 120,
          'Current Value': 130,
          'P&L': 110,
          'P&L %': 100,
        },
      };
    } else {
      // Desktop: Full columns with optimal widths
      return {
        'headers': [
          'Fund Name',
          'Units',
          'Avg NAV',
          'Current NAV',
          'Invested',
          'Current Value',
          'P&L',
          'P&L %'
        ],
        'columnMinWidth': {
          'Fund Name': 300,
          'Units': 100,
          'Avg NAV': 110,
          'Current NAV': 125,
          'Invested': 120,
          'Current Value': 140,
          'P&L': 110,
          'P&L %': 100,
        },
      };
    }
  }

  Widget _buildHoldingsTable(ThemesProvider theme, MFProvider mfData) {
    final filteredHoldings = _getFilteredHoldings(mfData);

    if (filteredHoldings.isEmpty) {
      return const SizedBox(
        height: 400,
        child: Center(child: NoDataFoundWeb()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available height
        final screenHeight = MediaQuery.of(context).size.height;
        final padding =
            widget.showSummaryCards ? 32.0 : 0.0; // Top and bottom padding
        final headerHeight =
            widget.showSummaryCards ? 120.0 : 0.0; // Summary cards height
        final actionBarHeight =
            widget.showSummaryCards ? 60.0 : 0.0; // Action bar height
        final spacing =
            widget.showSummaryCards ? 24.0 : 0.0; // Spacing between sections
        const bottomMargin = 20.0; // Bottom margin
        final tableHeight = screenHeight -
            padding -
            headerHeight -
            actionBarHeight -
            spacing -
            bottomMargin;

        // Ensure we don't exceed 75% of screen height
        final maxHeight = screenHeight * 0.75;
        final calculatedHeight = tableHeight > maxHeight
            ? maxHeight
            : (tableHeight > 400 ? tableHeight : 400.0);

        // Get screen width for responsive design
        final screenWidth = MediaQuery.of(context).size.width;

        // Get responsive column configuration
        final responsiveConfig = _getResponsiveMfHoldingColumns(screenWidth);
        final headers = List<String>.from(responsiveConfig['headers'] as List);
        final columnMinWidth =
            Map<String, double>.from(responsiveConfig['columnMinWidth'] as Map);

        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Container(
            height: calculatedHeight.toDouble(),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.isDarkMode
                    ? WebDarkColors.divider
                    : WebColors.divider,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
              color: theme.isDarkMode ? WebDarkColors.background : Colors.white,
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                scrollbarTheme: ScrollbarThemeData(
                  // Make both scrollbars always visible
                  thumbVisibility: WidgetStateProperty.all(true),
                  trackVisibility: WidgetStateProperty.all(true),

                  // Consistent thickness for both horizontal and vertical
                  thickness: WidgetStateProperty.all(6.0),
                  crossAxisMargin: 0.0,
                  mainAxisMargin: 0.0,

                  // Consistent radius
                  radius: const Radius.circular(3),

                  // Consistent colors for both scrollbars
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    return theme.isDarkMode
                        ? WebDarkColors.textSecondary.withOpacity(0.3)
                        : WebColors.textSecondary.withOpacity(0.3);
                  }),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    return theme.isDarkMode
                        ? WebDarkColors.divider.withOpacity(0.1)
                        : WebColors.divider.withOpacity(0.1);
                  }),

                  trackBorderColor: WidgetStateProperty.all(Colors.transparent),
                  minThumbLength: 48.0,
                ),
              ),
              child: DataTable2(
                columnSpacing: 12,
                horizontalMargin: 12,
                minWidth: 1100,
                sortColumnIndex: null, // Disable DataTable2's sort indicators
                sortAscending: true,
                fixedLeftColumns: 1, // Fix the first column (Fund Name)
                fixedColumnsColor: theme.isDarkMode
                    ? WebDarkColors.backgroundSecondary.withOpacity(0.8)
                    : WebColors.backgroundSecondary.withOpacity(0.8),
                showBottomBorder: true,
                horizontalScrollController: _horizontalScrollController,
                scrollController: _verticalScrollController,
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(
                  theme.isDarkMode
                      ? WebDarkColors.primary
                      : WebColors.primary.withOpacity(0.05),
                ),
                headingTextStyle: WebTextStyles.tableHeader(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? WebDarkColors.textPrimary
                      : WebColors.textPrimary,
                ),
                dataTextStyle: WebTextStyles.custom(
                  fontSize: 13,
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? WebDarkColors.textPrimary
                      : WebColors.textPrimary,
                  fontWeight: WebFonts.medium,
                ),
                border: TableBorder(
                  top: BorderSide(
                    color: theme.isDarkMode
                        ? WebDarkColors.divider
                        : WebColors.divider,
                    width: 1,
                  ),
                  bottom: BorderSide(
                    color: theme.isDarkMode
                        ? WebDarkColors.divider
                        : WebColors.divider,
                    width: 1,
                  ),
                  horizontalInside: BorderSide(
                    color: theme.isDarkMode
                        ? WebDarkColors.divider
                        : WebColors.divider,
                    width: 1,
                  ),
                  // Remove vertical lines
                ),
                columns:
                    _buildDataTable2Columns(headers, columnMinWidth, theme),
                rows: _buildDataTable2Rows(filteredHoldings, headers, theme),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to determine column alignment based on content type
  bool _isNumericColumn(String header) {
    return header !=
        'Fund Name'; // All columns except Fund Name contain numeric data
  }

  int _getColumnIndexForHeader(String header) {
    switch (header) {
      case 'Fund Name':
        return 0;
      case 'Units':
        return 1;
      case 'Avg NAV':
        return 2;
      case 'Current NAV':
        return 3;
      case 'Invested':
        return 4;
      case 'Current Value':
        return 5;
      case 'P&L':
        return 6;
      case 'P&L %':
        return 7;
      default:
        return -1;
    }
  }

  List<DataColumn2> _buildDataTable2Columns(
    List<String> headers,
    Map<String, double> columnMinWidth,
    ThemesProvider theme,
  ) {
    return headers.map((header) {
      final columnIndex = _getColumnIndexForHeader(header);
      final isFundName = header == 'Fund Name';
      final isNumeric = _isNumericColumn(header);

      return DataColumn2(
        label: SizedBox.expand(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => _hoveredColumnIndex.value = columnIndex,
            onExit: (_) => _hoveredColumnIndex.value = null,
            child: Tooltip(
              message: 'Sort by $header',
              child: GestureDetector(
                onTap: () => _onManualSort(columnIndex),
                behavior: HitTestBehavior.opaque,
                child: ValueListenableBuilder<int?>(
                  valueListenable: _hoveredColumnIndex,
                  builder: (context, hoveredIndex, child) {
                    return Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: hoveredIndex == columnIndex
                            ? (theme.isDarkMode
                                ? WebDarkColors.primary.withOpacity(0.1)
                                : WebColors.primary.withOpacity(0.05))
                            : Colors.transparent,
                      ),
                      alignment: isNumeric
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 12.0),
                      child: _buildSortableHeaderContent(
                          header, isNumeric, theme, columnIndex),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        size: isFundName ? ColumnSize.L : ColumnSize.S,
        fixedWidth: isFundName ? 300.0 : null,
        onSort: null, // Disable DataTable2's onSort
      );
    }).toList();
  }

  List<DataRow2> _buildDataTable2Rows(
    List<dynamic> holdings,
    List<String> headers,
    ThemesProvider theme,
  ) {
    return holdings.asMap().entries.map((entry) {
      final index = entry.key;
      final holding = entry.value;
      final holdingId = holding.name ?? '';
      final uniqueId = '$holdingId$index';

      return DataRow2(
        onTap: () => _showHoldingDetail(holding),
        color: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.hovered) ||
              _hoveredRowToken.value == uniqueId) {
            return theme.isDarkMode
                ? WebDarkColors.primary.withOpacity(0.06)
                : WebColors.primary.withOpacity(0.10);
          }
          return Colors.transparent;
        }),
        cells: headers.map((header) {
          final isNumeric = _isNumericColumn(header);
          return DataCell(
            MouseRegion(
              onEnter: (_) => _hoveredRowToken.value = uniqueId,
              onExit: (_) => _hoveredRowToken.value = null,
              child: SizedBox.expand(
                child: Container(
                  alignment:
                      isNumeric ? Alignment.centerRight : Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 12.0),
                  child: _buildDataTable2CellContent(
                      header, holding, theme, uniqueId),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }).toList();
  }

  Widget _buildDataTable2CellContent(
    String column,
    dynamic holding,
    ThemesProvider theme,
    String uniqueId,
  ) {
    switch (column) {
      case 'Fund Name':
        return _buildFundNameCellContent(
          holding,
          theme,
          uniqueId,
        );
      case 'Units':
        final units = double.tryParse(holding.avgQty ?? '0') ?? 0.0;
        return Text(
          units.toStringAsFixed(2),
          style: WebTextStyles.custom(
            fontSize: 13,
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode
                ? WebDarkColors.textPrimary
                : WebColors.textPrimary,
            fontWeight: WebFonts.medium,
          ),
          textAlign: TextAlign.right,
        );
      case 'Avg NAV':
        final avgNav = double.tryParse(holding.avgNav ?? '0') ?? 0.0;
        return Text(
          avgNav.toStringAsFixed(2),
          style: WebTextStyles.custom(
            fontSize: 13,
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode
                ? WebDarkColors.textPrimary
                : WebColors.textPrimary,
            fontWeight: WebFonts.medium,
          ),
          textAlign: TextAlign.right,
        );
      case 'Current NAV':
        final curNav = double.tryParse(holding.curNav ?? '0') ?? 0.0;
        return Text(
          curNav.toStringAsFixed(2),
          style: WebTextStyles.custom(
            fontSize: 13,
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode
                ? WebDarkColors.textPrimary
                : WebColors.textPrimary,
            fontWeight: WebFonts.medium,
          ),
          textAlign: TextAlign.right,
        );
      case 'Invested':
        final invested = double.tryParse(holding.investedValue ?? '0') ?? 0.0;
        return Text(
          invested.toStringAsFixed(2),
          style: WebTextStyles.custom(
            fontSize: 13,
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode
                ? WebDarkColors.textPrimary
                : WebColors.textPrimary,
            fontWeight: WebFonts.medium,
          ),
          textAlign: TextAlign.right,
        );
      case 'Current Value':
        final currentVal = double.tryParse(holding.currentValue ?? '0') ?? 0.0;
        return Text(
          currentVal.toStringAsFixed(2),
          style: WebTextStyles.custom(
            fontSize: 13,
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode
                ? WebDarkColors.textPrimary
                : WebColors.textPrimary,
            fontWeight: WebFonts.medium,
          ),
          textAlign: TextAlign.right,
        );
      case 'P&L':
        final pnl = double.tryParse(holding.profitLoss ?? '0') ?? 0.0;
        final pnlStr = pnl.toStringAsFixed(2);
        return Text(
          pnlStr,
          style: WebTextStyles.custom(
            fontSize: 13,
            isDarkTheme: theme.isDarkMode,
            color: _getValueColor(pnlStr, theme),
            fontWeight: WebFonts.medium,
          ),
          textAlign: TextAlign.right,
        );
      case 'P&L %':
        final pnlPercent =
            double.tryParse(holding.changeprofitLoss ?? '0') ?? 0.0;
        final pnlPercentStr = pnlPercent.toStringAsFixed(2);
        return Text(
          '$pnlPercentStr%',
          style: WebTextStyles.custom(
            fontSize: 13,
            isDarkTheme: theme.isDarkMode,
            color: _getValueColor(pnlPercentStr, theme),
            fontWeight: WebFonts.medium,
          ),
          textAlign: TextAlign.right,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFundNameCellContent(
    dynamic holding,
    ThemesProvider theme,
    String uniqueId,
  ) {
    final holdingName = holding.name ?? 'N/A';
    final avgQty = double.tryParse(holding.avgQty ?? '0') ?? 0.0;

    // ✅ Use ValueListenableBuilder to avoid rebuilding entire table on hover
    return ValueListenableBuilder<String?>(
      valueListenable: _hoveredRowToken,
      builder: (context, hoveredToken, child) {
        final rowIsHovered = hoveredToken == uniqueId;
        final showDropdown = rowIsHovered || _popoverRowId == uniqueId;

        return Row(
          children: [
            // ✅ Fund name - always visible, takes available space
            Expanded(
              child: Tooltip(
                message: holdingName,
                waitDuration: const Duration(milliseconds: 500),
                child: Text(
                  holdingName,
                  style: WebTextStyles.custom(
                    fontSize: 13,
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? WebDarkColors.textPrimary
                        : WebColors.textPrimary,
                    fontWeight: WebFonts.medium,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // ✅ 3-dot dropdown menu - appears on hover
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: showDropdown ? null : 0,
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !showDropdown,
                child: AnimatedOpacity(
                  opacity: showDropdown ? 1 : 0,
                  duration: const Duration(milliseconds: 140),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      _buildOptionsMenuButton(
                        holding: holding,
                        theme: theme,
                        uniqueId: uniqueId,
                        hasUnits: avgQty > 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionsMenuButton({
    required dynamic holding,
    required ThemesProvider theme,
    required String uniqueId,
    required bool hasUnits,
  }) {
    return MouseRegion(
      onEnter: (_) {
        _isHoveringDropdown = true;
        _cancelPopoverCloseTimer();
      },
      onExit: (_) {
        _isHoveringDropdown = false;
        _startPopoverCloseTimer();
      },
      child: Builder(
        builder: (buttonContext) {
          return GestureDetector(
            onTap: () {
              // Close any existing popover
              _closePopover();

              // Create new controller
              final controller = shadcn.PopoverController();
              _activePopoverController = controller;
              _popoverRowId = uniqueId;

              // Build menu items
              List<shadcn.MenuItem> menuItems = [];

              // Redeem option - needs units AND the Redemption_Allowed gate
              if (hasUnits && holding.isRedemptionAllowed) {
                menuItems.add(
                  _buildMenuButton(
                    icon: Icons.currency_exchange,
                    title: 'Redeem',
                    onPressed: (ctx) async {
                      _closePopover();
                      await _handleRedeem(ctx, holding);
                    },
                  ),
                );
              }

              // Details option
              menuItems.add(
                _buildMenuButton(
                  icon: Icons.info_outline,
                  title: 'Details',
                  onPressed: (ctx) {
                    _closePopover();
                    _showHoldingDetail(holding);
                  },
                ),
              );

              // Show the dropdown menu
              controller.show(
                context: buttonContext,
                builder: (ctx) {
                  return MouseRegion(
                    onEnter: (_) {
                      _isHoveringDropdown = true;
                      _cancelPopoverCloseTimer();
                    },
                    onExit: (_) {
                      _isHoveringDropdown = false;
                      _startPopoverCloseTimer();
                    },
                    child: shadcn.DropdownMenu(
                      children: menuItems,
                    ),
                  );
                },
                alignment: Alignment.topRight,
                offset: const Offset(0, 4),
              );
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.isDarkMode
                    ? WebDarkColors.backgroundSecondary
                    : WebColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: theme.isDarkMode
                      ? WebDarkColors.divider
                      : WebColors.divider,
                ),
              ),
              child: Icon(
                Icons.more_vert,
                size: 16,
                color: theme.isDarkMode
                    ? WebDarkColors.textPrimary
                    : WebColors.textPrimary,
              ),
            ),
          );
        },
      ),
    );
  }

  shadcn.MenuItem _buildMenuButton({
    required IconData icon,
    required String title,
    Color? iconColor,
    Color? textColor,
    required Function(BuildContext) onPressed,
  }) {
    return shadcn.MenuButton(
      leading: Icon(
        icon,
        size: 16,
        color: iconColor,
      ),
      onPressed: (ctx) => onPressed(ctx),
      child: Text(
        title,
        style: TextStyle(
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildSortableHeaderContent(
      String header, bool isNumeric, ThemesProvider theme, int columnIndex) {
    final isCurrentlySorted = _sortColumnIndex == columnIndex;

    // Determine which icon to show
    IconData sortIcon;
    if (isCurrentlySorted) {
      sortIcon = _sortAscending ? Icons.arrow_upward : Icons.arrow_downward;
    } else {
      sortIcon = Icons.unfold_more;
    }

    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment:
          isNumeric ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                isNumeric ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  header,
                  style: WebTextStyles.tableHeader(
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? WebDarkColors.textPrimary
                        : WebColors.textPrimary,
                  ),
                  textAlign: isNumeric ? TextAlign.right : TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                sortIcon,
                size: 16,
                color: isCurrentlySorted
                    ? (theme.isDarkMode
                        ? WebDarkColors.primary
                        : WebColors.primary)
                    : (theme.isDarkMode
                        ? WebDarkColors.textSecondary.withOpacity(0.6)
                        : WebColors.textSecondary.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<dynamic> _getFilteredHoldings(MFProvider mfData) {
    List<dynamic> holdings = mfData.mfholdingnew?.data ?? [];

    // Apply search filter - use widget.searchQuery directly
    final searchQuery = widget.searchQuery ?? '';
    if (searchQuery.isNotEmpty) {
      holdings = holdings.where((holding) {
        final name = holding.name?.toLowerCase() ?? '';
        final searchLower = searchQuery.toLowerCase();
        return name.contains(searchLower);
      }).toList();
    }

    // Apply sorting
    if (_sortColumnIndex != null) {
      holdings.sort((a, b) {
        int comparison = 0;

        switch (_sortColumnIndex) {
          case 0: // Fund Name
            comparison = (a.name ?? '').compareTo(b.name ?? '');
            break;
          case 1: // Units
            final aQty = double.tryParse(a.avgQty ?? '0') ?? 0;
            final bQty = double.tryParse(b.avgQty ?? '0') ?? 0;
            comparison = aQty.compareTo(bQty);
            break;
          case 2: // Avg NAV
            final aNav = double.tryParse(a.avgNav ?? '0') ?? 0;
            final bNav = double.tryParse(b.avgNav ?? '0') ?? 0;
            comparison = aNav.compareTo(bNav);
            break;
          case 3: // Current NAV
            final aCurNav = double.tryParse(a.curNav ?? '0') ?? 0;
            final bCurNav = double.tryParse(b.curNav ?? '0') ?? 0;
            comparison = aCurNav.compareTo(bCurNav);
            break;
          case 4: // Invested
            final aInvested = double.tryParse(a.investedValue ?? '0') ?? 0;
            final bInvested = double.tryParse(b.investedValue ?? '0') ?? 0;
            comparison = aInvested.compareTo(bInvested);
            break;
          case 5: // Current Value
            final aValue = double.tryParse(a.currentValue ?? '0') ?? 0;
            final bValue = double.tryParse(b.currentValue ?? '0') ?? 0;
            comparison = aValue.compareTo(bValue);
            break;
          case 6: // P&L
            final aPnL = double.tryParse(a.profitLoss ?? '0') ?? 0;
            final bPnL = double.tryParse(b.profitLoss ?? '0') ?? 0;
            comparison = aPnL.compareTo(bPnL);
            break;
          case 7: // P&L %
            final aPnLPercent = double.tryParse(a.changeprofitLoss ?? '0') ?? 0;
            final bPnLPercent = double.tryParse(b.changeprofitLoss ?? '0') ?? 0;
            comparison = aPnLPercent.compareTo(bPnLPercent);
            break;
        }

        return _sortAscending ? comparison : -comparison;
      });
    }

    return holdings;
  }

  Color _getValueColor(String value, ThemesProvider theme) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) {
      return theme.isDarkMode
          ? WebDarkColors.success
          : WebColors.success; // Green
    } else if (numValue < 0) {
      return theme.isDarkMode ? WebDarkColors.error : WebColors.error; // Red
    } else {
      return theme.isDarkMode
          ? WebDarkColors.textSecondary
          : WebColors.textSecondary; // Grey
    }
  }

  Color _getStatValueColor(String value, ThemesProvider theme) {
    // Extract numeric value from string (remove any text like percentages)
    final cleanValue = value.replaceAll(RegExp(r'[^\d.-]'), '');
    final numValue = double.tryParse(cleanValue) ?? 0.0;

    if (numValue > 0) {
      return theme.isDarkMode
          ? WebDarkColors.success
          : WebColors.success; // Green
    } else if (numValue < 0) {
      return theme.isDarkMode ? WebDarkColors.error : WebColors.error; // Red
    } else {
      return theme.isDarkMode
          ? WebDarkColors.textPrimary
          : WebColors.textPrimary; // Grey
    }
  }

  String _formatValue(String? value) {
    if (value == null || value.isEmpty) return "0.00";
    final numValue = double.tryParse(value);
    if (numValue == null) return "0.00";
    return numValue.toStringAsFixed(2);
  }

  void _showHoldingDetail(dynamic holding) {
    showDialog(
      context: context,
      builder: (context) => MfHoldingDetailScreenWeb(
        holding: holding,
      ),
    );
  }

  Future<void> _handleRedeem(BuildContext context, dynamic holding) async {
    final mfData = ref.read(mfProvider);
    // Set the holding data for redemption using the ISIN
    mfData.fetchmfholdsingpage(holding.iSIN ?? '');
    // Call the redeem evaluation function
    mfData.recdemevalu();
    // Show web redeem dialog
    showDialog(
      context: context,
      builder: (context) => const RedemptionBottomSheetWeb(),
    );
  }

  void _onManualSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        // Same column clicked - toggle sort direction
        _sortAscending = !_sortAscending;
      } else {
        // Different column clicked - set as new sort column with ascending
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }
}
