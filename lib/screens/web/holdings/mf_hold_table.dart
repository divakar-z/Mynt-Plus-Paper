import 'dart:async';
import 'package:flutter/material.dart'
    show
        InkWell,
        Icons,
        IconData,
        Icon,
        BoxDecoration,
        BorderRadius,
        TextPainter,
        TextSpan,
        TextStyle,
        TextDirection,
        GestureDetector,
        HitTestBehavior,
        Row,
        SizedBox,
        Text,
        Align,
        TextOverflow,
        TextAlign,
        Alignment,
        Container,
        SingleChildScrollView,
        Axis,
        Colors,
        LayoutBuilder,
        Center,
        BuildContext,
        Widget,
        ValueKey,
        EdgeInsets,
        Color,
        FontFeature,
        FontWeight,
        MainAxisAlignment,
        CrossAxisAlignment,
        MainAxisSize,
        MouseRegion,
        showDialog,
        ScrollController,
        Expanded,
        Column,
        WidgetsBinding,
        Padding,
        MediaQuery,
        Tooltip,
        BoxShadow,
        Offset,
        ValueNotifier,
        ValueListenableBuilder,
        RawScrollbar,
        Radius,
        Builder,
        Dialog,
        RoundedRectangleBorder,
        ClipRRect,
        FontWeight;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../provider/mf_provider.dart';
import '../../../provider/privacy_provider.dart';
import '../../../../provider/thems.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/no_data_found.dart';
import '../../../sharedWidget/mynt_loader.dart';
import 'mf_holding_detail_screen_web.dart';
import '../ordersbook/mf/redeem_bottom_sheet_web.dart';
import '../../../models/mf_model/mutual_fundmodel.dart';
import '../mutual_fund/mf_order_screen_web.dart';

// Shadcn Table for Mutual Funds Holdings
class MfTableExample extends ConsumerStatefulWidget {
  final String? searchQuery;

  const MfTableExample({super.key, this.searchQuery});

  @override
  ConsumerState<MfTableExample> createState() => _MfTableExampleState();
}

class _MfTableExampleState extends ConsumerState<MfTableExample> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);

  // Track the popover controller to close it when row is unhovered
  shadcn.PopoverController? _activePopoverController;

  // Track which row the popover belongs to
  int? _popoverRowIndex;

  // Track if mouse is hovering over the dropdown menu
  bool _isHoveringDropdown = false;

  // Timer for delayed popover close (allows mouse to move from row to dropdown)
  Timer? _popoverCloseTimer;

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

  @override
  void initState() {
    super.initState();
    // Fetch mutual fund holdings data when screen initializes
    // (old MF holdings API decommissioned — demat endpoint is the source)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ref.read(mfProvider).fetchmfholdingnew();
      ref.read(mfProvider).fetchmfdematholding();
    });

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
    super.dispose();
  }

  // Builds a cell with hover detection that covers the entire cell including padding
  // Pass holding data for automatic row tap handling (centralized - no duplication)
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    dynamic holding, // Pass holding data for automatic row tap handling
  }) {
    final isFirstColumn = columnIndex == 0; // Fund Name column
    final isLastColumn = columnIndex == 7; // Chg column

    // Match the cell padding logic - Fund Name column has more left, minimal right
    // Last column mirrors this - minimal left, more right
    EdgeInsets cellPadding;
    if (isFirstColumn) {
      // Fund Name column - more left, minimal right (for overlay buttons)
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
          if (_activePopoverController != null &&
              _popoverRowIndex == rowIndex) {
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
                  ? resolveThemeColor(
                      context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary,
                    ).withValues(alpha: 0.08)
                  : null,
              alignment: alignRight ? Alignment.topRight : null,
              child: cachedChild,
            );

            // Automatically wrap with GestureDetector for row tap when holding data is provided
            if (holding != null) {
              return GestureDetector(
                onTap: () {
                  _hoveredRowIndex.value = null;
                  _showHoldingDetail(holding);
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
  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0; // Fund Name column
    final isLastColumn = columnIndex == 7; // Chg column

    // Match the cell padding logic - Fund Name column has more left, minimal right
    // Last column mirrors this - minimal left, more right
    EdgeInsets headerPadding;
    if (isFirstColumn) {
      // Fund Name column - more left, minimal right
      headerPadding = const EdgeInsets.fromLTRB(16, 6, 4, 6);
    } else if (isLastColumn) {
      // Last column - minimal left, more right
      headerPadding = const EdgeInsets.fromLTRB(4, 6, 16, 6);
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
    final textStyle = const TextStyle(fontSize: 14);
    const padding = 24.0;
    const sortIconWidth =
        24.0; // Extra space for sort indicator icon (16px icon + 4px gap + buffer)

    // Header texts
    final headers = [
      'Fund Name',
      'Units',
      'Avg NAV',
      'Cur NAV',
      'Inv',
      'Cur Val',
      'P&L',
      'Chg',
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
        String cellText = '';

        switch (col) {
          case 0: // Fund Name
            cellText = holding.name ?? 'N/A';
            break;
          case 1: // Units
            // cellText = holding.avgQty ?? '0';
            final nav = double.tryParse(holding.avgQty ?? '0') ?? 0.0;
            cellText = nav.toStringAsFixed(4);
            break;
          case 2: // Avg NAV
            final nav = double.tryParse(holding.avgNav ?? '0') ?? 0.0;
            cellText = nav.toStringAsFixed(4);
            break;
          case 3: // Current NAV
            final nav = double.tryParse(holding.curNav ?? '0') ?? 0.0;
            cellText = nav.toStringAsFixed(4);
            break;
          case 4: // Invested
            final invested =
                double.tryParse(holding.investedValue ?? '0') ?? 0.0;
            cellText = invested.toStringAsFixed(2);
            break;
          case 5: // Current Value
            final currentValue =
                double.tryParse(holding.currentValue ?? '0') ?? 0.0;
            cellText = currentValue.toStringAsFixed(2);
            break;
          case 6: // P&L
            final pnl = double.tryParse(holding.profitLoss ?? '0') ?? 0.0;
            cellText = pnl.toStringAsFixed(2);
            break;
          case 7: // Chg %
            final pct = double.tryParse(holding.changeprofitLoss ?? '0') ?? 0.0;
            cellText = '${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(2)}%';
            break;
        }

        final cellWidth = _measureTextWidth(cellText, textStyle);
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }

      // For Fund Name column, ensure minimum width to prevent excessive truncation
      if (headers[col] == 'Fund Name') {
        const minFundNameWidth = 150.0;
        maxWidth = maxWidth < minFundNameWidth ? minFundNameWidth : maxWidth;
      }

      // Set minimum width (max of header/data + padding)
      minWidths[col] = maxWidth + padding;
    }

    return minWidths;
  }

  // Helper method to build colored text for P&L values with percentage (stacked)
  Widget _buildPnLWithPercentage(String pnlValue, String percentValue) {
    final numValue = double.tryParse(pnlValue) ?? 0.0;
    final color = _getCellColor(numValue, context);
    final baseStyle = _getTextStyle(context, color: color);

    return Tooltip(
      message: '$pnlValue ($percentValue%)',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(pnlValue,
              textAlign: TextAlign.end,
              style: baseStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(
            '$percentValue%',
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  // Handler: Show holding detail sheet
  void _showHoldingDetail(dynamic holding) {
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
          child: MfHoldingDetailScreenWeb(
            holding: holding,
          ),
        );
      },
      position: shadcn.OverlayPosition.end,
    );
  }

  // Handler: Redeem mutual fund
  Future<void> _handleRedeem(dynamic holding) async {
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

  // Handler: Add (place order) for mutual fund
  Future<void> _handleAdd(dynamic holding) async {
    final mf = ref.read(mfProvider);

    // Build MutualFundList directly from holding fields
    // Holdings model keys don't align with MutualFundList.fromJson keys
    MutualFundList mfItem = MutualFundList(
      iSIN: holding.iSIN,
      schemeCode: holding.sCHEMECODE,
      schemeName: holding.name,
      name: holding.name,
      minimumPurchaseAmount: holding.minimumPurchaseAmount,
      sIPFLAG: 'Y',
    );

    // Pre-fill amount from holding's minimum purchase amount
    String amt = holding.minimumPurchaseAmount ?? '500';
    mf.invAmt.text = amt.split('.').first;
    mf.installmentAmt.text = amt.split('.').first;

    // Set order type
    mf.chngOrderType('One-time');
    mf.orderchangetitle('One-time');

    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.30).clamp(380.0, 500.0);

    // Show order dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = ref.read(themeProvider).isDarkMode;
        return Dialog(
          backgroundColor: isDark
              ? MyntColors.backgroundColorDark
              : MyntColors.backgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: dialogWidth,
            child: MFOrderScreenWeb(mfData: mfItem, isAdditional: true),
          ),
        );
      },
    );
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
    dynamic holding,
    int rowIndex,
    double avgQty,
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

            // Redeem option — units to redeem AND the Redemption_Allowed gate.
            if (avgQty > 0 && holding.isRedemptionAllowed) {
              menuItems.add(
                _buildMenuButton(
                  icon: shadcn.LucideIcons.gift,
                  title: 'Redeem',
                  iconColor: iconColor,
                  textColor: textColor,
                  onPressed: (ctx) {
                    _closePopover();
                    // Clear hover state before navigating to prevent stuck hover
                    _hoveredRowIndex.value = null;
                    _handleRedeem(holding);
                  },
                ),
              );
            }

            // Add (place order) option — gated on Purchase_Allowed.
            if (holding.isPurchaseAllowed) {
              menuItems.add(
                _buildMenuButton(
                  icon: Icons.add,
                  title: 'Add',
                  iconColor: iconColor,
                  textColor: textColor,
                  onPressed: (ctx) {
                    _closePopover();
                    _hoveredRowIndex.value = null;
                    _handleAdd(holding);
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
                  _showHoldingDetail(holding);
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
                      dark: Colors.transparent, light: Colors.grey),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.more_vert,
              size: 16,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimary, light: MyntColors.textPrimary),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mfData = ref.watch(mfProvider);
    // Privacy Mode: units, avg NAV, invested, current and P&L are masked;
    // the fund's current NAV is market data and stays visible.
    final privacy = ref.watch(privacyProvider);

    // Show loading indicator while fetching data
    if (mfData.holdstatload ?? false) {
      return Center(child: MyntLoader.simple());
    }

    final holdings = mfData.mfholdingnew?.data ?? [];

    // Apply search filter if search query is provided
    var filteredHoldings = holdings;
    final searchQuery = widget.searchQuery?.toLowerCase().trim() ?? '';
    if (searchQuery.isNotEmpty) {
      filteredHoldings = holdings.where((holding) {
        final name = holding.name?.toLowerCase() ?? '';
        return name.contains(searchQuery);
      }).toList();
    }

    // Sort holdings based on selected column
    if (_sortColumnIndex != null) {
      filteredHoldings.sort((a, b) {
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
          case 6: // P&L (sorts by P&L value, not percentage)
            final aPnL = double.tryParse(a.profitLoss ?? '0') ?? 0;
            final bPnL = double.tryParse(b.profitLoss ?? '0') ?? 0;
            comparison = aPnL.compareTo(bPnL);
            break;
          case 7: // Chg %
            final aChg = double.tryParse(a.changeprofitLoss ?? '0') ?? 0;
            final bChg = double.tryParse(b.changeprofitLoss ?? '0') ?? 0;
            comparison = aChg.compareTo(bChg);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    final displayHoldings = filteredHoldings;

    // Show NoDataFound if no results after filtering
    if (displayHoldings.isEmpty) {
      return shadcn.OutlinedContainer(
        child: NoDataFoundWeb(
          title: searchQuery.isNotEmpty
              ? "No Mutual Funds Found"
              : "No Mutual Funds",
          subtitle: searchQuery.isNotEmpty
              ? "No mutual funds match your search \"$searchQuery\"."
              : "You don't have any mutual fund holdings yet.",
          primaryEnabled: false,
          secondaryEnabled: false,
        ),
      );
    }

    return shadcn.OutlinedContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate minimum widths dynamically based on actual content
          final minWidths = _calculateMinWidths(displayHoldings, context);

          // Available width
          final availableWidth = constraints.maxWidth;

          // Step 1: Start with minimum widths (content-based, no wasted space)
          final columnWidths = <int, double>{};
          for (int i = 0; i < 8; i++) {
            columnWidths[i] = minWidths[i] ?? 100.0;
          }

          // Step 2: Calculate total minimum width needed
          final totalMinWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);

          // Step 3: If there's extra space, distribute equally across all columns
          if (totalMinWidth < availableWidth) {
            final extraSpace = availableWidth - totalMinWidth;
            final extraPerColumn = extraSpace / 8;

            for (int i = 0; i < 8; i++) {
              columnWidths[i] = columnWidths[i]! + extraPerColumn;
            }
          } else if (totalMinWidth > availableWidth) {
            // Step 3b: If content exceeds available width, shrink proportionally
            final excessWidth = totalMinWidth - availableWidth;

            // Define absolute minimum widths (cannot go below these)
            final absoluteMinWidths = <int, double>{
              0: 120.0, // Fund Name (needs space for 3-dot menu)
              1: 60.0, // Units
              2: 70.0, // Avg NAV
              3: 70.0, // Cur NAV
              4: 60.0, // Inv
              5: 70.0, // Cur Val
              6: 60.0, // P&L
              7: 50.0, // Chg
            };

            // Calculate how much each column can shrink
            final shrinkableAmounts = <int, double>{};
            double totalShrinkable = 0.0;

            for (int i = 0; i < 8; i++) {
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

            // Distribute the shrinkage proportionally
            if (totalShrinkable > 0) {
              final shrinkRatio =
                  (excessWidth / totalShrinkable).clamp(0.0, 1.0);
              for (int i = 0; i < 8; i++) {
                if (shrinkableAmounts[i]! > 0) {
                  final shrinkAmount = shrinkableAmounts[i]! * shrinkRatio;
                  columnWidths[i] = columnWidths[i]! - shrinkAmount;
                }
              }
            }
          }

          // Calculate total required width
          final totalRequiredWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);

          // Create scroll controllers for synchronized scrolling
          final horizontalScrollController = ScrollController();
          final verticalScrollController = ScrollController();

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
                  },
                  defaultRowHeight: const shadcn.FixedTableSize(40),
                  rows: [
                    shadcn.TableHeader(
                      cells: [
                        buildHeaderCell('Fund Name', 0),
                        buildHeaderCell('Units', 1, true),
                        buildHeaderCell('Avg NAV', 2, true),
                        buildHeaderCell('Cur NAV', 3, true),
                        buildHeaderCell('Inv', 4, true),
                        buildHeaderCell('Cur Val', 5, true),
                        buildHeaderCell('P&L', 6, true),
                        buildHeaderCell('Chg', 7, true),
                      ],
                    ),
                  ],
                ),
                // Scrollable Body (vertical scroll)
                Expanded(
                  child: RawScrollbar(
                    controller: verticalScrollController,
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
                      controller: verticalScrollController,
                      scrollDirection: Axis.vertical,
                      child: shadcn.Table(
                        key: ValueKey(
                            'table_${_sortColumnIndex}_$_sortAscending'),
                        columnWidths: {
                          0: shadcn.FixedTableSize(columnWidths[0]!),
                          1: shadcn.FixedTableSize(columnWidths[1]!),
                          2: shadcn.FixedTableSize(columnWidths[2]!),
                          3: shadcn.FixedTableSize(columnWidths[3]!),
                          4: shadcn.FixedTableSize(columnWidths[4]!),
                          5: shadcn.FixedTableSize(columnWidths[5]!),
                          6: shadcn.FixedTableSize(columnWidths[6]!),
                          7: shadcn.FixedTableSize(columnWidths[7]!),
                        },
                        defaultRowHeight: const shadcn.FixedTableSize(40),
                        rows: [
                          // Data Rows
                          ...displayHoldings.asMap().entries.map((entry) {
                            final index = entry.key;
                            final holding = entry.value;
                            final avgQty =
                                double.tryParse(holding.avgQty ?? '0') ?? 0.0;

                            return shadcn.TableRow(
                              cells: [
                                // Fund Name with action button on hover - Make clickable for row tap
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 0,
                                  holding: holding,
                                  child: ValueListenableBuilder<int?>(
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
                                            // Fund name - Expanded so it shrinks when buttons appear
                                            Expanded(
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Tooltip(
                                                  message:
                                                      holding.name ?? 'N/A',
                                                  child: Text(
                                                    holding.name ?? 'N/A',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    softWrap: false,
                                                    style:
                                                        _getTextStyle(context),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // 3-dot options menu - appears on hover
                                            if (isRowHovered ||
                                                (_activePopoverController !=
                                                        null &&
                                                    _popoverRowIndex ==
                                                        index)) ...[
                                              const SizedBox(width: 8),
                                              _buildOptionsMenuButton(
                                                holding,
                                                index,
                                                avgQty,
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Units - Make clickable for row tap
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 1,
                                  alignRight: true,
                                  holding: holding,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = privacy.mask(
                                          (double.tryParse(
                                                      holding.avgQty ?? '0') ??
                                                  0.0)
                                              .toStringAsFixed(4));
                                      return Tooltip(
                                        message: value,
                                        child: Text(value,
                                            style: _getTextStyle(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      );
                                    }),
                                  ),
                                ),
                                // Avg NAV - Make clickable for row tap
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 2,
                                  alignRight: true,
                                  holding: holding,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = privacy.mask(
                                          (double.tryParse(
                                                      holding.avgNav ?? '0') ??
                                                  0.0)
                                              .toStringAsFixed(4));
                                      return Tooltip(
                                        message: value,
                                        child: Text(value,
                                            style: _getTextStyle(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      );
                                    }),
                                  ),
                                ),
                                // Current NAV - Make clickable for row tap
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 3,
                                  alignRight: true,
                                  holding: holding,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = (double.tryParse(
                                                  holding.curNav ?? '0') ??
                                              0.0)
                                          .toStringAsFixed(4);
                                      return Tooltip(
                                        message: value,
                                        child: Text(value,
                                            style: _getTextStyle(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      );
                                    }),
                                  ),
                                ),
                                // Invested - Make clickable for row tap
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 4,
                                  alignRight: true,
                                  holding: holding,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = privacy.mask(
                                          (double.tryParse(
                                                      holding.investedValue ??
                                                          '0') ??
                                                  0.0)
                                              .toStringAsFixed(2));
                                      return Tooltip(
                                        message: value,
                                        child: Text(value,
                                            style: _getTextStyle(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      );
                                    }),
                                  ),
                                ),
                                // Current Value - Make clickable for row tap
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 5,
                                  alignRight: true,
                                  holding: holding,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = privacy.mask(
                                          (double.tryParse(
                                                      holding.currentValue ??
                                                          '0') ??
                                                  0.0)
                                              .toStringAsFixed(2));
                                      return Tooltip(
                                        message: value,
                                        child: Text(value,
                                            style: _getTextStyle(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      );
                                    }),
                                  ),
                                ),
                                // P&L
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 6,
                                  alignRight: true,
                                  holding: holding,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final pnlNum = double.tryParse(
                                              holding.profitLoss ?? '0') ??
                                          0.0;
                                      final value = privacy
                                          .mask(pnlNum.toStringAsFixed(2));
                                      final color = _getCellColor(
                                          privacy.isPrivate ? 0.0 : pnlNum,
                                          context);
                                      return Tooltip(
                                        message: value,
                                        child: Text(value,
                                            style: _getTextStyle(context,
                                                color: color),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      );
                                    }),
                                  ),
                                ),
                                // Chg %
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 7,
                                  alignRight: true,
                                  holding: holding,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final pctNum = double.tryParse(
                                              holding.changeprofitLoss ??
                                                  '0') ??
                                          0.0;
                                      final displayValue = privacy.isPrivate
                                          ? '$kPrivacyMask%'
                                          : '${pctNum >= 0 ? "+" : ""}${pctNum.toStringAsFixed(2)}%';
                                      final color = _getCellColor(
                                          privacy.isPrivate ? 0.0 : pctNum,
                                          context);
                                      return Tooltip(
                                        message: displayValue,
                                        child: Text(displayValue,
                                            style: _getTextStyle(context,
                                                    color: color)
                                                .copyWith(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w400),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Wrap with scrollbars - horizontal on the outside
          return RawScrollbar(
            controller: horizontalScrollController,
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
              controller: horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalRequiredWidth,
                child: buildTableContent(),
              ),
            ),
          );
        },
      ),
    );
  }
}
