// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../../../provider/iop_provider.dart';
import '../../../../../provider/thems.dart';
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../sharedWidget/functions.dart';
import '../../../../../sharedWidget/no_data_found.dart';
import '../../ipo_cancel_alert/cancel_alert_web.dart';
import '../ipo_orderbook_details/ipo_order_details_sheet_web.dart';

class OpenOrdersTable extends ConsumerStatefulWidget {
  final List<dynamic>? filteredOrders;

  const OpenOrdersTable({super.key, this.filteredOrders});

  @override
  ConsumerState<OpenOrdersTable> createState() => _OpenOrdersTableState();
}

class _OpenOrdersTableState extends ConsumerState<OpenOrdersTable> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String? _hoveredRowToken; // Track which row is being hovered
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Popover state management
  shadcn.PopoverController? _activePopoverController;
  String? _popoverRowId;
  bool _isHoveringDropdown = false;
  Timer? _popoverCloseTimer;

  @override
  void dispose() {
    _cancelPopoverCloseTimer();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _startPopoverCloseTimer() {
    _cancelPopoverCloseTimer();
    _popoverCloseTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_isHoveringDropdown && _hoveredRowToken != _popoverRowId) {
        _closePopover();
      }
    });
  }

  void _cancelPopoverCloseTimer() {
    _popoverCloseTimer?.cancel();
    _popoverCloseTimer = null;
  }

  void _closePopover() {
    _cancelPopoverCloseTimer();
    try {
      _activePopoverController?.close();
    } catch (_) {}
    final needsRebuild = _activePopoverController != null || _popoverRowId != null;
    _activePopoverController = null;
    _popoverRowId = null;
    _isHoveringDropdown = false;
    if (needsRebuild && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ipo = ref.watch(ipoProvide);
    final theme = ref.watch(themeProvider);
    final ordersToDisplay = widget.filteredOrders ?? ipo.openorder ?? [];

    // Apply sorting
    final sortedOrders = _getSortedOrders(ordersToDisplay);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Allocation: Name (25%), Date (25%), Amount (25%), Status (25%)
        final nameWidth = width * 0.25;
        final dateWidth = width * 0.25;
        final amountWidth = width * 0.25;
        final statusWidth = width * 0.25;

        final columnWidths = {
          0: shadcn.FixedTableSize(nameWidth),
          1: shadcn.FixedTableSize(dateWidth),
          2: shadcn.FixedTableSize(amountWidth),
          3: shadcn.FixedTableSize(statusWidth),
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.dividerDark,
                  light: MyntColors.divider,
                ),
                width: 1,
              ),
              borderRadius: BorderRadius.zero,
              color: theme.isDarkMode
                  ? Theme.of(context).colorScheme.surface
                  : Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Column(
                children: [
                  // Header
                  SizedBox(
                    height: 48,
                    child: Container(
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.cardDark,
                        light: MyntColors.listItemBg,
                      ),
                      child: shadcn.Table(
                        columnWidths: columnWidths,
                        defaultRowHeight: const shadcn.FixedTableSize(48),
                        rows: [
                          shadcn.TableHeader(
                            cells: [
                              _buildHeaderCell("Date", 0, theme,
                                  padding: const EdgeInsets.only(left: 16.0, right: 8.0)),
                              _buildHeaderCell("Stock name", 1, theme),
                              _buildHeaderCell("Amount", 2, theme,
                                  centered: true),
                              _buildHeaderCell("Status", 3, theme,
                                  centered: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Body
                  Expanded(
                    child: ordersToDisplay.isEmpty
                        ? const Center(
                            child: NoDataFoundWeb(secondaryEnabled: false))
                        : SingleChildScrollView(
                            child: shadcn.Table(
                              columnWidths: columnWidths,
                              defaultRowHeight: const shadcn.FixedTableSize(50),
                              rows: sortedOrders.asMap().entries.map((entry) {
                                return _buildShadcnRow(entry.value, entry.key, theme);
                              }).toList(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<dynamic> _getSortedOrders(List<dynamic> orders) {
    if (_sortColumnIndex == null) {
      return orders;
    }

    final sorted = List<dynamic>.from(orders);
    sorted.sort((a, b) {
      int comparison = 0;
      switch (_sortColumnIndex) {
        case 0: // Date
          final dateA = a.responseDatetime?.toString() ?? '';
          final dateB = b.responseDatetime?.toString() ?? '';
          comparison = dateA.compareTo(dateB);
          break;
        case 1: // Company Name
          // final nameA = a.companyName?.toString() ?? '';
          // final nameB = b.companyName?.toString() ?? '';
          final nameA = (a.companyName?.toString() ?? '').trim().toLowerCase();
          final nameB = (b.companyName?.toString() ?? '').trim().toLowerCase();
          comparison = nameA.compareTo(nameB);
          break;
        case 2: // Amount
          // Amount is a formatted string ("1,50,000"); text compare put
          // "9,000" above "15,000". Compare the number instead.
          // final amountA = _getInvestedAmount(a);
          // final amountB = _getInvestedAmount(b);
          final amountA = _amountValue(_getInvestedAmount(a));
          final amountB = _amountValue(_getInvestedAmount(b));
          comparison = amountA.compareTo(amountB);
          break;
        case 3: // Status
          final statusA = a.reponseStatus?.toString() ?? '';
          final statusB = b.reponseStatus?.toString() ?? '';
          comparison = statusA.compareTo(statusB);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
    return sorted;
  }

  // Header text style
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

  double _amountValue(String formatted) {
    return double.tryParse(formatted.replaceAll(RegExp(r'[^0-9.\-]'), '')) ??
        0.0;
  }

  void _onSortTable(int columnIndex, bool ascending) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = ascending;
      }
    });
  }

  Widget _buildSortArrow() {
    return Icon(
      _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
      size: 16,
      color: resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary),
    );
  }

  shadcn.TableCell _buildHeaderCell(
      String text, int sortIndex, ThemesProvider theme,
      {bool alignRight = false, bool centered = false, EdgeInsets? padding}) {
    Alignment alignment;
    if (centered) {
      alignment = Alignment.center;
    } else {
      alignment = alignRight ? Alignment.centerRight : Alignment.centerLeft;
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
      child: GestureDetector(
        // Whole header cell is tappable, not just the label text.
        behavior: HitTestBehavior.opaque,
        // onTap: sortIndex >= 0
        //     ? () => _onSortTable(sortIndex, !_sortAscending)
        //     : null,
        // A new column always starts ascending; same column again reverses.
        onTap: sortIndex >= 0 ? () => _onSortTable(sortIndex, true) : null,
        child: Container(
          alignment: alignment,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sort arrow on the sorted column, as in the Bonds table:
              // before the label when right-aligned, after it otherwise.
              if (alignRight && sortIndex >= 0 && _sortColumnIndex == sortIndex) ...[
                _buildSortArrow(),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: _getHeaderStyle(context),
              ),
              if (!alignRight && sortIndex >= 0 && _sortColumnIndex == sortIndex) ...[
                const SizedBox(width: 4),
                _buildSortArrow(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  shadcn.TableCell _buildShadcnCell({
    required Widget child,
    required String uniqueId,
    required bool rowIsHovered,
    required ThemesProvider theme,
    VoidCallback? onTap,
    bool alignRight = false,
    bool centered = false,
    EdgeInsets? padding,
  }) {
    Alignment alignment;
    if (centered) {
      alignment = Alignment.center;
    } else {
      alignment = alignRight ? Alignment.centerRight : Alignment.centerLeft;
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
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredRowToken = uniqueId),
        onExit: (_) => setState(() => _hoveredRowToken = null),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            color: rowIsHovered
                ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark, light: MyntColors.primary)
                    .withOpacity(theme.isDarkMode ? 0.06 : 0.10)
                : Colors.transparent,
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            width: double.infinity,
            height: double.infinity,
            child: Align(
              alignment: alignment,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetailsDialog(dynamic order) {
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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: IpoOrderDetailsSheetWeb(order: order),
        );
      },
      position: shadcn.OverlayPosition.end,
      barrierColor: Colors.transparent,
    );
  }

  // Build name cell with hover dropdown menu
  shadcn.TableCell _buildNameCellWithActions({
    required dynamic order,
    required String uniqueId,
    required bool rowIsHovered,
    required ThemesProvider theme,
    required String companyName,
    required bool canCancel,
  }) {
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
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _hoveredRowToken = uniqueId);
          if (_activePopoverController != null && _popoverRowId == uniqueId) {
            _cancelPopoverCloseTimer();
          }
        },
        onExit: (_) {
          setState(() => _hoveredRowToken = null);
          if (_activePopoverController != null && !_isHoveringDropdown) {
            _startPopoverCloseTimer();
          }
        },
        child: GestureDetector(
          onTap: () => _showOrderDetailsDialog(order),
          child: Container(
            color: rowIsHovered
                ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark, light: MyntColors.primary)
                    .withOpacity(theme.isDarkMode ? 0.06 : 0.10)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            width: double.infinity,
            height: double.infinity,
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Company name
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(right: rowIsHovered ? 40.0 : 0.0),
                      child: Text(
                        companyName,
                        style: MyntWebTextStyles.body(
                          context,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                          fontWeight: MyntFonts.medium,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  // Dropdown button on hover
                  if (rowIsHovered)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _buildOptionsMenuButton(
                          order: order,
                          uniqueId: uniqueId,
                          canCancel: canCancel,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build the 3-dot options menu button with shadcn dropdown
  Widget _buildOptionsMenuButton({
    required dynamic order,
    required String uniqueId,
    required bool canCancel,
  }) {
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

            // Cancel option (if allowed)
            if (canCancel) {
              menuItems.add(
                _buildMenuButton(
                  icon: Icons.cancel_outlined,
                  title: 'Cancel',
                  iconColor: resolveThemeColor(context,
                      dark: MyntColors.errorDark, light: MyntColors.tertiary),
                  textColor: textColor,
                  onPressed: (ctx) {
                    _closePopover();
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return IpoCancelAlert(ipocancel: order);
                      },
                    );
                  },
                ),
              );
              menuItems.add(const shadcn.MenuDivider());
            }

            // Info option
            menuItems.add(
              _buildMenuButton(
                icon: Icons.info_outline,
                title: 'Info',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  _showOrderDetailsDialog(order);
                },
              ),
            );

            // Create a controller for this popover
            final controller = shadcn.PopoverController();
            _activePopoverController = controller;
            _popoverRowId = uniqueId;

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
              size: 18,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimary,
                  light: MyntColors.textPrimary),
            ),
          ),
        );
      },
    );
  }

  // Helper method for building menu buttons
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

  Widget _buildHoverButton({
    String? label,
    IconData? icon,
    required Color color,
    Color? backgroundColor,
    required VoidCallback? onPressed,
    required ThemesProvider theme,
  }) {
    final isLongLabel = label != null && label.length > 1;
    return SizedBox(
      width: isLongLabel ? null : 25,
      height: 25,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: onPressed,
          child: Container(
            padding:
                isLongLabel ? const EdgeInsets.symmetric(horizontal: 8) : null,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 16, color: color)
                  : Text(
                      label ?? "",
                      style: MyntWebTextStyles.buttonSm(
                        context,
                        color: color,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Determines if an order can be cancelled.
  /// Only Pending orders can be cancelled (not Success orders).
  /// The order must also have the IPO bidding period still "Open".
  bool _canCancelOrder(dynamic order) {
    final orderStatus = order.reponseStatus?.toString().toLowerCase().trim();
    if (orderStatus != "new success") {
      // For any status other than "new success" (e.g., Pending), always allow cancellation.
      return true;
    }

    // For "new success" orders, we only allow cancellation if the bidding period is still open.
    // We proceed to the date/status check below.

    // Check if bidding start date exists and is not empty/null string
    final startDate = order.biddingstartdate?.toString().trim();
    if (startDate == null ||
        startDate.isEmpty ||
        startDate == "null" ||
        startDate == "") {
      // If dates are not available, default to showing button for pending orders
      // The backend will handle validation
      return true;
    }

    // Get the correct end date based on exchange type (BSE vs NSE)
    final endDateStr = order.type == "BSE"
        ? order.biddingendDate?.toString().trim()
        : order.biddingenddate?.toString().trim();

    if (endDateStr == null ||
        endDateStr.isEmpty ||
        endDateStr == "null" ||
        endDateStr == "") {
      // If dates are not available, default to showing button for pending orders
      return true;
    }

    // Check if the IPO bidding period is currently "Open"
    try {
      final status = modifyButtonStatus(
        startDate,
        endDateStr,
      );

      // Only allow cancellation if IPO bidding is still open
      return status == "Open";
    } catch (e) {
      // If there's an error parsing dates, default to showing the button for pending orders
      return true;
    }
  }

  shadcn.TableRow _buildShadcnRow(
      dynamic order, int index, ThemesProvider theme) {
    final orderToken = order.applicationNumber?.toString() ?? '';
    final uniqueId = '$orderToken$index';
    final isHovered = _hoveredRowToken == uniqueId;
    final isRowActive = isHovered || _popoverRowId == uniqueId;
    final canCancel = _canCancelOrder(order);
    final companyName = order.companyName?.toString() ?? '';

    return shadcn.TableRow(
      cells: [
        // Date
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: isRowActive,
          theme: theme,
          onTap: () => _showOrderDetailsDialog(order),
          padding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 8.0, bottom: 8.0),
          child: Text(
            order.responseDatetime?.toString() == "" ||
                    order.responseDatetime == null
                ? "----"
                : ipodateres(order.responseDatetime.toString()),
            style: MyntWebTextStyles.body(
              context,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary,
              ),
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        // Stock Name with dropdown
        _buildNameCellWithActions(
          order: order,
          uniqueId: uniqueId,
          rowIsHovered: isRowActive,
          theme: theme,
          companyName: companyName,
          canCancel: canCancel,
        ),
        // Amount
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: isRowActive,
          theme: theme,
          centered: true,
          onTap: () => _showOrderDetailsDialog(order),
          child: Text(
            _getInvestedAmount(order),
            style: MyntWebTextStyles.body(
              context,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary,
              ),
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        // Status
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: isRowActive,
          theme: theme,
          centered: true,
          onTap: () => _showOrderDetailsDialog(order),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (order.reponseStatus == "new success"
                      ? resolveThemeColor(
                          context,
                          dark: MyntColors.profitDark,
                          light: MyntColors.profit,
                        )
                      : MyntColors.pending)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              (order.reponseStatus == "new success" ? "Success" : "Pending")
                  .toUpperCase(),
              style: MyntWebTextStyles.bodySmall(
                context,
                color: order.reponseStatus == "new success"
                    ? resolveThemeColor(
                        context,
                        dark: MyntColors.profitDark,
                        light: MyntColors.profit,
                      )
                    : MyntColors.pending,
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getInvestedAmount(dynamic order) {
    if (order.bidDetail == null || order.bidDetail!.isEmpty) {
      return "0";
    }

    // Calculate max value from all bids
    List<String> stringList = [];
    for (var i = 0; i < order.bidDetail!.length; i++) {
      stringList.add(order.type == "BSE"
          ? (double.parse(order.bidDetail![i].rate ?? "0") *
                  double.parse(order.bidDetail![i].quantity ?? "0"))
              .toString()
          : order.bidDetail![i].amount?.toString() ?? "0");
    }

    if (stringList.isEmpty) {
      return "0";
    }

    String maxValue = stringList
        .reduce((curr, next) =>
            double.parse(curr) > double.parse(next) ? curr : next)
        .toString();
    return getFormatter(
        noDecimal: true, v4d: false, value: double.parse(maxValue));
  }
}
