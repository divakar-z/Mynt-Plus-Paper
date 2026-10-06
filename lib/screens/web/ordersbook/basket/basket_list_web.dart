import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/accessibility_provider.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/web_colors.dart' show WebDarkColors;
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:flutter/widgets.dart' as flutter;
import '../../../../models/order_book_model/order_book_model.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../provider/order_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../provider/websocket_provider.dart';

import '../../../../res/res.dart';
// import '../../../../res/web_colors.dart';
import '../../../../res/global_font_web.dart';
import '../../../../utils/rupee_convert_format.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart' as styles;
import '../../../../utils/responsive_snackbar.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../../sharedWidget/no_data_found.dart';
// import '../../../../sharedWidget/hover_actions_web.dart'; // Not used - using custom action buttons
import '../../../../sharedWidget/mynt_loader.dart';
import 'create_basket_web.dart';
// import '../../../web/market_watch/search_dialog_web.dart'; // Commented out - search bar integrated
import '../../../web/order/place_order_screen_web.dart';
import '../../market_watch/tv_chart/chart_iframe_guard.dart';
import '../../../../utils/overlay_manager.dart';
import 'dart:html' as html;
import 'package:pointer_interceptor/pointer_interceptor.dart';

class BasketList extends ConsumerStatefulWidget {
  const BasketList({super.key});

  @override
  ConsumerState<BasketList> createState() => _BasketListState();
}

class _BasketListState extends ConsumerState<BasketList> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  // ✅ Use ValueNotifier instead of setState to avoid rebuilding entire widget
  final ValueNotifier<String?> _hoveredRowIndex = ValueNotifier<String?>(null);
  final ValueNotifier<int?> _hoveredColumnIndex = ValueNotifier<int?>(null);
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  bool _isDeleting = false;

  // Track the popover controller to close it when row is unhovered
  shadcn.PopoverController? _activePopoverController;

  // Track which row the popover belongs to
  String? _popoverRowIndex;

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
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _hoveredRowIndex.dispose();
    _hoveredColumnIndex.dispose();
    super.dispose();
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

  // Helper method to ensure Geist font is always applied
  TextStyle _geistTextStyle(
      {Color? color, double? fontSize, FontWeight? fontWeight}) {
    return TextStyle(
      fontFamily: dyslexiaFontOr('Geist'),
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  TextStyle _getHeaderStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableHeader(
      context,
      color: color,
      darkColor: color ?? styles.MyntColors.textSecondaryDark,
      lightColor: color ?? styles.MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  // Builds a cell with hover detection
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    VoidCallback? onTap,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 2;
    final horizontalPadding = isFirstColumn || isLastColumn ? 16.0 : 8.0;

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
        onEnter: (_) => _hoveredRowIndex.value = '$rowIndex',
        onExit: (_) => _hoveredRowIndex.value = null,
        child: ValueListenableBuilder<String?>(
          valueListenable: _hoveredRowIndex,
          builder: (context, hoveredRowId, _) {
            Widget cellContent = Container(
              width: double.infinity,
              height: double.infinity,
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: 4),
              alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: hoveredRowId == '$rowIndex'
                    ? resolveThemeColor(
                        context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary,
                      ).withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: child,
            );

            // Wrap with GestureDetector if onTap is provided
            if (onTap != null) {
              cellContent = GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: cellContent,
              );
            }

            return cellContent;
          },
        ),
      ),
    );
  }

  // Builds a sortable header cell
  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 2;
    final horizontalPadding = isFirstColumn || isLastColumn ? 16.0 : 6.0;

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
        onTap: () => _onSortTable(columnIndex, true),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding:
              EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 6),
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

  // Calculate minimum column widths dynamically
  Map<int, double> _calculateMinWidths(
      List<dynamic> baskets, BuildContext context) {
    final textStyle = TextStyle(fontSize: 14, fontFamily: dyslexiaFontOr('Geist'));
    const padding = 24.0;
    const sortIconWidth = 24.0;

    final headers = [
      'Basket Name',
      'Items',
      'Created Date',
    ];
    final minWidths = <int, double>{};

    for (int col = 0; col < headers.length; col++) {
      double maxWidth = 0.0;
      final headerWidth = _measureTextWidth(headers[col], textStyle);
      maxWidth = headerWidth + sortIconWidth;

      for (final basket in baskets.take(5)) {
        final basketMap = basket as Map<String, dynamic>;
        String cellText = '';
        switch (col) {
          case 0: // Basket Name
            cellText = (basketMap['bsketName'] ?? 'N/A').toString();
            break;
          case 1: // Items
            cellText = (basketMap['curLength'] ?? 0).toString();
            break;
          case 2: // Created Date
            cellText = (basketMap['createdDate'] ?? '').toString();
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

  double _measureTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: _geistTextStyle(fontSize: 14)),
      textDirection: flutter.TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();
    return textPainter.width;
  }

  bool _isNumericColumn(String header) {
    switch (header) {
      case 'Items':
        return true;
      case 'Basket Name':
      case 'Created Date':
        return false;
      default:
        return false;
    }
  }

  List<dynamic> _getFilteredBaskets(List<dynamic> baskets) {
    final orderBook = ref.read(orderProvider);
    final searchQuery = orderBook.orderSearchCtrl.text.toUpperCase();

    if (searchQuery.isEmpty) {
      return baskets;
    }

    return baskets.where((basket) {
      final basketName = (basket['bsketName'] ?? '').toString().toUpperCase();
      return basketName.contains(searchQuery);
    }).toList();
  }

  int _getBasketColumnIndexForHeader(String header) {
    switch (header) {
      case 'Basket Name':
        return 0;
      case 'Items':
        return 1;
      case 'Created Date':
        return 2;
      default:
        return -1;
    }
  }

  List<dynamic> _getSortedBaskets(List<dynamic> baskets) {
    if (_sortColumnIndex == null) return baskets;
    final sorted = [...baskets];
    int c = _sortColumnIndex!;
    bool asc = _sortAscending;

    sorted.sort((a, b) {
      int comparison = 0;
      switch (c) {
        case 0: // Basket Name
          comparison = ((a as Map)['bsketName'] ?? '')
              .toString()
              .compareTo(((b as Map)['bsketName'] ?? '').toString());
          break;
        case 1: // Items
          final aItems =
              int.tryParse(((a as Map)['curLength'] ?? 0).toString()) ?? 0;
          final bItems =
              int.tryParse(((b as Map)['curLength'] ?? 0).toString()) ?? 0;
          comparison = aItems.compareTo(bItems);
          break;
        case 2: // Created Date
          comparison = ((a as Map)['createdDate'] ?? '')
              .toString()
              .compareTo(((b as Map)['createdDate'] ?? '').toString());
          break;
      }
      return asc ? comparison : -comparison;
    });
    return sorted;
  }

  Widget _buildBasketNameCell(
    Map<String, dynamic> basket,
    ThemesProvider theme,
    String uniqueId,
    int index,
    bool isRowHovered,
  ) {
    final bsktName = basket['bsketName'] ?? 'N/A';
    final colorScheme = shadcn.Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _handleBasketTap(context, basket),
      behavior: HitTestBehavior.deferToChild,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Basket icon and name - full width, can be partially covered by buttons
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(right: isRowHovered ? 70.0 : 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      assets.basketdashboard,
                      width: 10,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        colorScheme.mutedForeground,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        bsktName,
                        style: MyntWebTextStyles.tableCell(
                          context,
                          fontWeight: MyntFonts.medium,
                        ).copyWith(fontFeatures: [FontFeature.tabularFigures()]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Delete button + 3-dot menu button (appears on hover)
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
                      // Delete button (X icon)
                      _buildDeleteButton(basket, index),
                      const SizedBox(width: 6),
                      // 3-dot menu button
                      _buildBasketOptionsMenuButton(
                        basket,
                        uniqueId,
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

  // Build Delete button with X icon (tertiary/loss color)
  Widget _buildDeleteButton(
    Map<String, dynamic> basket,
    int index,
  ) {
    return GestureDetector(
      onTap: _isDeleting
          ? null
          : () => _handleDeleteBasket(context, basket, index),
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
  Widget _buildBasketOptionsMenuButton(
    Map<String, dynamic> basket,
    String uniqueId,
  ) {
    final iconColor = resolveThemeColor(context,
        dark: styles.MyntColors.iconDark, light: styles.MyntColors.icon);
    final textColor = resolveThemeColor(context,
        dark: styles.MyntColors.textPrimaryDark, light: styles.MyntColors.textPrimary);

    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          onTap: () {
            // Build menu items
            List<shadcn.MenuItem> menuItems = [];

            // Info option
            menuItems.add(
              _buildMenuButton(
                icon: Icons.info_outline,
                title: 'Info',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  _handleBasketTap(context, basket);
                },
              ),
            );

            // Create a controller for this popover
            final controller = shadcn.PopoverController();
            _activePopoverController = controller;
            _popoverRowIndex = uniqueId;

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
                  dark: styles.MyntColors.textPrimary,
                  light: styles.MyntColors.textPrimary),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextCell(
    String text,
    ThemesProvider theme,
    Alignment alignment,
  ) {
    return Align(
      alignment: alignment,
      child: Text(
        text,
        style: MyntWebTextStyles.tableCell(
          context,
          fontWeight: MyntFonts.medium,
        ).copyWith(fontFeatures: [FontFeature.tabularFigures()]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildBasketSortIcon(int columnIndex, ThemesProvider theme) {
    if (_sortColumnIndex == columnIndex) {
      return Icon(
        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
        size: 16,
        color: theme.isDarkMode ? MyntColors.secondary : MyntColors.primary,
      );
    } else {
      return Icon(
        Icons.unfold_more,
        size: 16,
        color: theme.isDarkMode ? MyntColors.secondary : MyntColors.secondary,
      );
    }
  }

  Widget _buildBasketTable(ThemesProvider theme, List<dynamic> baskets) {
    // Sort baskets - handle empty case for showing header always
    final sortedBaskets = baskets.isNotEmpty
        ? _getSortedBaskets(baskets)
        : <dynamic>[];

    return SizedBox.expand(
      child: shadcn.OutlinedContainer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate minimum widths dynamically based on actual content
            final minWidths = _calculateMinWidths(sortedBaskets, context);

            // Available width
            final availableWidth = constraints.maxWidth;

            // Step 1: Start with minimum widths (content-based, no wasted space)
            final columnWidths = <int, double>{};
            for (int i = 0; i < 3; i++) {
              columnWidths[i] = minWidths[i] ?? 100.0;
            }

            // Step 2: Calculate total minimum width needed
            final totalMinWidth = columnWidths.values
                .fold<double>(0.0, (sum, width) => sum + width);

            // Step 3: If there's extra space, distribute it proportionally
            if (totalMinWidth < availableWidth) {
              final extraSpace = availableWidth - totalMinWidth;

              const basketNameGrowthFactor = 1.0;
              const textGrowthFactor = 1.0;
              const numericGrowthFactor = 1.0;

              final growthFactors = <int, double>{};
              double totalGrowthFactor = 0.0;

              for (int i = 0; i < 3; i++) {
                if (i == 0) {
                  // Basket Name
                  growthFactors[i] = basketNameGrowthFactor;
                  totalGrowthFactor += basketNameGrowthFactor;
                } else if (i == 2) {
                  // Created Date
                  growthFactors[i] = textGrowthFactor;
                  totalGrowthFactor += textGrowthFactor;
                } else {
                  // Items
                  growthFactors[i] = numericGrowthFactor;
                  totalGrowthFactor += numericGrowthFactor;
                }
              }

              if (totalGrowthFactor > 0) {
                for (int i = 0; i < 3; i++) {
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
                  // Fixed Header
                  shadcn.Table(
                    columnWidths: {
                      0: shadcn.FixedTableSize(columnWidths[0]!),
                      1: shadcn.FixedTableSize(columnWidths[1]!),
                      2: shadcn.FixedTableSize(columnWidths[2]!),
                    },
                    defaultRowHeight: const shadcn.FixedTableSize(40),
                    rows: [
                      shadcn.TableHeader(
                        cells: [
                          buildHeaderCell('Basket Name', 0),
                          buildHeaderCell('Items', 1),
                          buildHeaderCell('Created Date', 2),
                        ],
                      ),
                    ],
                  ),
                  // Scrollable Body - shows empty state or table rows
                  Expanded(
                    child: sortedBaskets.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: NoDataFoundWeb(
                                title: "No Baskets",
                                subtitle: "You don't have any baskets yet.",
                                primaryEnabled: false,
                                secondaryEnabled: false,
                              ),
                            ),
                          )
                        : Scrollbar(
                            controller: _verticalScrollController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            interactive: true,
                            child: SingleChildScrollView(
                              controller: _verticalScrollController,
                              scrollDirection: Axis.vertical,
                              child: ValueListenableBuilder<String?>(
                                valueListenable: _hoveredRowIndex,
                                builder: (context, hoveredRowId, _) {
                                  return shadcn.Table(
                                    key: ValueKey(
                                        'table_${_sortColumnIndex}_$_sortAscending'),
                                    columnWidths: {
                                      0: shadcn.FixedTableSize(columnWidths[0]!),
                                      1: shadcn.FixedTableSize(columnWidths[1]!),
                                      2: shadcn.FixedTableSize(columnWidths[2]!),
                                    },
                                    defaultRowHeight: const shadcn.FixedTableSize(40),
                                    rows: sortedBaskets.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final basket =
                                          entry.value as Map<String, dynamic>;
                                      final uniqueId = '$index';
                                      final isRowHovered = hoveredRowId == uniqueId;

                                      return shadcn.TableRow(
                                        cells: [
                                          buildCellWithHover(
                                            rowIndex: index,
                                            columnIndex: 0,
                                            onTap: () =>
                                                _handleBasketTap(context, basket),
                                            child: _buildBasketNameCell(basket, theme,
                                                uniqueId, index, isRowHovered),
                                          ),
                                          buildCellWithHover(
                                            rowIndex: index,
                                            columnIndex: 1,
                                            onTap: () =>
                                                _handleBasketTap(context, basket),
                                            child: _buildTextCell(
                                              (basket['curLength'] ?? 0).toString(),
                                              theme,
                                              Alignment.centerLeft,
                                            ),
                                          ),
                                          buildCellWithHover(
                                            rowIndex: index,
                                            columnIndex: 2,
                                            onTap: () =>
                                                _handleBasketTap(context, basket),
                                            child: _buildTextCell(
                                              basket['createdDate']?.toString() ?? '',
                                              theme,
                                              Alignment.centerLeft,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                ],
              );
            }

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
      ),
    );
  }

  Future<void> _handleDeleteBasket(
      BuildContext context, Map<String, dynamic> basket, int index) async {
    final bsktName = basket['bsketName'] ?? '';
    final basketProvider = ref.read(orderProvider);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = ref.read(themeProvider);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: theme.isDarkMode
                  ? MyntColors.dialogDark
                  : MyntColors.dialog,
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
                    border: Border(
                      bottom: BorderSide(
                        color: theme.isDarkMode
                            ? MyntColors.dividerDark
                            : MyntColors.divider,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Delete Basket',
                        style: MyntWebTextStyles.title(
                          context,
                          color: theme.isDarkMode
                              ? MyntColors.textPrimaryDark
                              : MyntColors.textPrimary,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: theme.isDarkMode
                                  ? MyntColors.textSecondaryDark
                                  : MyntColors.textSecondary,
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
                      // Confirmation text with basket name in quotes
                      Text(
                        'Are you sure you want to delete "${bsktName.toString().toUpperCase()}"?',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.body(
                          context,
                          color: theme.isDarkMode
                              ? MyntColors.textPrimaryDark
                              : MyntColors.textPrimary,
                        ),
                      ),

                      // Red Delete button
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
                          child: _isDeleting
                              ? MyntLoader.inline(
                                  color: Colors.white,
                                  strokeWidth: 2.0,
                                )
                              : Text(
                                  'Delete',
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

    if (shouldDelete == true) {
      setState(() => _isDeleting = true);
      await basketProvider.removeBasket(index);
      if (mounted) {
        setState(() => _isDeleting = false);
        ResponsiveSnackBar.showSuccess(
          context,
          'Basket "${bsktName.toString().toUpperCase()}" deleted successfully',
        );
      }
    }
  }

  Future<void> _handleBasketTap(
      BuildContext context, Map<String, dynamic> basket) async {
    final bsktName = basket['bsketName'] ?? '';
    final basketProvider = ref.read(orderProvider);

    await basketProvider.fetchBasketMargin();
    await basketProvider.chngBsktName(bsktName, context, true);

    // Client ask: basket window floats like the place-order window — no dim,
    // page behind stays usable, draggable, stays until closed.
    if (context.mounted) {
      _BasketWindow.show(context, bsktName);
    }
  }

  // Previous modal dialog (dimmed backdrop), kept for rollback:
    // if (context.mounted) {
    //   final colorScheme = shadcn.Theme.of(context).colorScheme;
    //   // Offset from the centred position; kept for this open only.
    //   Offset dragOffset = Offset.zero;
    //   showDialog(
    //     context: context,
    //     barrierDismissible: true,
    //     builder: (BuildContext context) {
    //       return StatefulBuilder(builder: (context, setDialogState) {
    //       final screen = MediaQuery.of(context).size;
    //       return Transform.translate(
    //         offset: dragOffset,
    //         child: Dialog(
    //         backgroundColor: Colors.transparent,
    //         elevation: 0,
    //         child: Container(
    //           constraints: BoxConstraints(
    //             maxWidth: MediaQuery.of(context).size.width * 0.6,
    //             maxHeight: MediaQuery.of(context).size.height * 0.8,
    //           ),
    //           decoration: BoxDecoration(
    //             color: colorScheme.popover,
    //             borderRadius: BorderRadius.circular(6),
    //             border: Border.all(
    //               color: colorScheme.border,
    //               width: 1,
    //             ),
    //             boxShadow: [
    //               BoxShadow(
    //                 color: Colors.black.withOpacity(0.1),
    //                 blurRadius: 8,
    //                 offset: const Offset(0, 4),
    //               ),
    //             ],
    //           ),
    //           child: ClipRRect(
    //             borderRadius: BorderRadius.circular(6),
    //             child: BasketScripList(
    //               bsktName: bsktName,
    //               onDrag: (delta) => setDialogState(() {
    //                 // Keep the header reachable on screen.
    //                 final next = dragOffset + delta;
    //                 dragOffset = Offset(
    //                   next.dx.clamp(-screen.width * 0.45, screen.width * 0.45),
    //                   next.dy.clamp(-screen.height * 0.1, screen.height * 0.8),
    //                 );
    //               }),
    //             ),
    //           ),
    //         ),
    //         ),
    //       );
    //       });
    //     },
    //   );
    // }

  @override
  Widget build(BuildContext context) {
    // Watch basket provider to rebuild when basket data changes
    final basket = ref.watch(orderProvider);
    final theme = ref.watch(themeProvider);

    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.isDarkMode
                    ? MyntColors.secondary
                    : WebColors.primary,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Material(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(5),
                  splashColor: Colors.white.withOpacity(0.2),
                  highlightColor: Colors.white.withOpacity(0.1),
                  onTap: () {
                    Future.delayed(const Duration(milliseconds: 150), () {
                      showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (BuildContext context) {
                          final theme = ref.read(themeProvider);
                          return Dialog(
                            backgroundColor: theme.isDarkMode
                                ? MyntColors.backgroundColorDark
                                : MyntColors.backgroundColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const SizedBox(
                              width: 400,
                              child: CreateBasket(),
                            ),
                          );
                        },
                      );
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Text(
                      "Create Basket",
                      style: WebTextStyles.buttonMd(
                        isDarkTheme: theme.isDarkMode,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        basket.isBasketLoading
            ? SizedBox(
                height: 400, child: Center(child: MyntLoader.simple()))
            : Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: _buildBasketTable(
                                theme, basket.bsktList.isEmpty
                                    ? []
                                    : _getFilteredBaskets(basket.bsktList)),
                          ),
                        );
                      },
                    ),
                  ),
      ],
    );
  }
}

class BasketScripList extends ConsumerStatefulWidget {
  final String bsktName;
  /// Drag the dialog by its header (client ask: movable basket window).
  final ValueChanged<Offset>? onDrag;
  /// Closes the floating basket window; null = page route (pop).
  final VoidCallback? onClose;
  const BasketScripList(
      {super.key, required this.bsktName, this.onDrag, this.onClose});

  @override
  ConsumerState<BasketScripList> createState() => _BasketScripListState();
}

class _BasketScripListState extends ConsumerState<BasketScripList>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tabScrollController = ScrollController();
  final ScrollController _searchScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  String _searchValue = "";
  late TabController _tabController;
  VoidCallback?
      _tabControllerListener; // Store listener reference for proper cleanup
  final int _tabCount = 5; // For basket mode
  final Map<int, bool> _hoveredItems = {}; // For Buy/Sell button hover
  // ✅ Use ValueNotifier instead of setState to avoid rebuilding entire widget
  final ValueNotifier<String?> _hoveredRowIndex = ValueNotifier<String?>(null);
  final ValueNotifier<int?> _hoveredColumnIndex = ValueNotifier<int?>(null);
  int? _sortColumnIndex;
  bool _sortAscending = true;
  // TC_324.2: ticked rows by ORIGINAL basket index (table can be sorted).
  // Sent rows can be ticked to delete only (Kite style).
  final Set<int> _selected = {};

  /// True once any row has been sent; rows are then placed one by one or by
  /// selection. A fresh basket keeps the single Place Order.
  bool _isSentMode(OrderProvider p) =>
      _hasOrdersPlacedInBasket(widget.bsktName, p) ||
      p.isBasketPlaced(p.selectedBsktName) ||
      p.bsktScripList.any((e) => e['orderStatus'] != null);

  List<int> _selectedUnsent(OrderProvider p) => [
        for (final i in _selected)
          if (i < p.bsktScripList.length &&
              p.bsktScripList[i]['orderStatus'] == null)
            i
      ];

  Widget _buildRowCheckbox(
      {required bool value, required ValueChanged<bool> onChanged}) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Checkbox(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        activeColor: resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary),
      ),
    );
  }

  void _closeWindow() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  String get _currentBasketName {
    final p = ref.read(orderProvider);
    return p.selectedBsktName.isEmpty ? widget.bsktName : p.selectedBsktName;
  }

  Future<void> _deleteSelected() async {
    final indices = _selected.toList();
    if (indices.isEmpty) return;
    final ok = await _confirmDelete(
      'Delete Scripts',
      indices.length == 1
          ? 'Are you sure you want to delete 1 script?'
          : 'Are you sure you want to delete ${indices.length} scripts?',
    );
    if (ok != true || !mounted) return;
    setState(() => _selected.clear());
    final basket = ref.read(orderProvider);
    await basket.removeBsktScrips(indices, _currentBasketName);
    await basket.fetchBasketMargin();
  }

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _tabCount, vsync: this, initialIndex: 0);
    // Store listener reference for proper cleanup
    _tabControllerListener = () {
      if (_tabController.indexIsChanging && _searchValue.isNotEmpty) {
        final marketWatch = ref.read(marketWatchProvider);
        marketWatch.searchClear();
        marketWatch.scripSearch(
            _searchValue, context, _tabController.index, "Basket");
      }
    };
    _tabController.addListener(_tabControllerListener!);
  }

  // Builds a cell with hover detection
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    required int totalColumns,
    bool alignRight = false,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == totalColumns - 1;

    EdgeInsets cellPadding;
    if (isFirstColumn) {
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
        onEnter: (_) => _hoveredRowIndex.value = 'basket_$rowIndex',
        onExit: (_) => _hoveredRowIndex.value = null,
        child: ValueListenableBuilder<String?>(
          valueListenable: _hoveredRowIndex,
          child: child,
          builder: (context, hoveredId, cachedChild) {
            final isRowHovered = hoveredId == 'basket_$rowIndex';

            Color? backgroundColor;
            if (isRowHovered) {
              backgroundColor = resolveThemeColor(context,
                  dark: styles.MyntColors.primaryDark.withOpacity(0.08),
                  light: styles.MyntColors.primary.withOpacity(0.08));
            }

            return Container(
              padding: cellPadding,
              color: backgroundColor,
              alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
              child: cachedChild,
            );
          },
        ),
      ),
    );
  }

  // Builds a sortable header cell with sort indicator
  shadcn.TableCell buildHeaderCell(
      String label, int columnIndex, ThemesProvider theme, int totalColumns,
      [bool alignRight = false, Widget? leading]) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == totalColumns - 1;

    // Vertical padding 6 matches the positions table header — 12 left only
    // ~16px for the label inside the 40px header row and clipped it.
    EdgeInsets headerPadding;
    if (isFirstColumn) {
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
        onTap: () => _onSortTable(columnIndex, true),
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
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 6)],
              if (alignRight && _sortColumnIndex == columnIndex)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: resolveThemeColor(context,
                      dark: styles.MyntColors.textSecondaryDark,
                      light: styles.MyntColors.textSecondary),
                ),
              if (alignRight && _sortColumnIndex == columnIndex)
                const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: MyntWebTextStyles.tableHeader(
                    context,
                    darkColor: styles.MyntColors.textSecondaryDark,
                    lightColor: styles.MyntColors.textSecondary,
                    fontWeight: MyntFonts.semiBold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!alignRight && _sortColumnIndex == columnIndex)
                const SizedBox(width: 4),
              if (!alignRight && _sortColumnIndex == columnIndex)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: resolveThemeColor(context,
                      dark: styles.MyntColors.textSecondaryDark,
                      light: styles.MyntColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabScrollController.dispose();
    _searchScrollController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    // Remove listener before disposing to prevent memory leaks
    if (_tabControllerListener != null) {
      _tabController.removeListener(_tabControllerListener!);
      _tabControllerListener = null;
    }
    _tabController.dispose();
    _hoveredRowIndex.dispose();
    _hoveredColumnIndex.dispose();
    super.dispose();
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

  bool _isNumericColumnBasketItems(String header) {
    if (header == 'Qty.' ||
        header == 'Price' ||
        header == 'LTP' ||
        header == 'Status' ||
        header == 'Product / Type') return true;
    return false;
  }

  List<Map<String, dynamic>> _getSortedBasketScripts(
      List<Map<String, dynamic>> items) {
    if (_sortColumnIndex == null) return items;
    final sorted = [...items];
    int c = _sortColumnIndex!;
    bool asc = _sortAscending;

    int cmp<T extends Comparable<T>>(T? a, T? b) {
      if (a == null && b == null) return 0;
      if (a == null) return -1;
      if (b == null) return 1;
      return a.compareTo(b);
    }

    num parseNum(String? v) => double.tryParse(v ?? '') ?? 0;

    sorted.sort((a, b) {
      int r = 0;
      switch (c) {
        case 0: // Instrument
          final aSymbol = '${a['symbol'] ?? ''}';
          final bSymbol = '${b['symbol'] ?? ''}';
          r = cmp<String>(aSymbol, bSymbol);
          break;
        case 1: // Type (Buy/Sell)
          r = cmp<String>(a["trantype"]?.toString(), b["trantype"]?.toString());
          break;
        case 2: // Product / Type
          r = cmp<String>(a['prd']?.toString(), b['prd']?.toString());
          if (r == 0) {
            r = cmp<String>(
                a['prctype']?.toString(), b['prctype']?.toString());
          }
          break;
        case 3: // Qty.
          final aQty = int.tryParse(a["qty"]?.toString() ?? "0") ?? 0;
          final bQty = int.tryParse(b["qty"]?.toString() ?? "0") ?? 0;
          r = aQty.compareTo(bQty);
          break;
        case 4: // LTP
          // LTP is dynamic, but we can sort by the 'lp' value if present in the raw item data
          final aLtp = parseNum(a["lp"]?.toString());
          final bLtp = parseNum(b["lp"]?.toString());
          r = cmp<num>(aLtp, bLtp);
          break;
        case 5: // Price
          final aPrice = parseNum(a["prc"]?.toString());
          final bPrice = parseNum(b["prc"]?.toString());
          r = cmp<num>(aPrice, bPrice);
          break;
        case 6: // Status
          r = cmp<String>(
              a['orderStatus']?.toString(), b['orderStatus']?.toString());
          break;
      }
      return asc ? r : -r;
    });
    return sorted;
  }

  /// Checks if the basket contains scripts from multiple exchanges
  bool _hasMultipleExchanges(List scriptList) {
    if (scriptList.isEmpty) return false;

    // Extract all exchanges from the basket scripts
    Set<String> exchanges = {};
    for (var script in scriptList) {
      if (script['exch'] != null) {
        exchanges.add(script['exch'].toString());
      }
    }

    // If there's more than one unique exchange, return true
    return exchanges.length > 1;
  }

  /// Checks if the current basket has any orders placed
  bool _hasOrdersPlacedInBasket(
      String basketName, OrderProvider orderProvider) {
    // Check if this basket has any order tracking
    return orderProvider.basketOrderIds.containsKey(basketName) &&
        orderProvider.basketOrderIds[basketName]!.isNotEmpty;
  }

  Widget _buildSearchResults(WidgetRef ref, ThemesProvider theme) {
    final searchScrip = ref.watch(marketWatchProvider);

    // Filter out index instruments (idx == 'YES') - they cannot be traded
    final filteredResults = searchScrip.allSearchScrip
        ?.where((scrip) => scrip.idx?.toUpperCase() != 'YES')
        .toList();

    if (filteredResults?.isEmpty ?? true) {
      return Container(
        decoration: BoxDecoration(
          color: theme.isDarkMode
              ? MyntColors.backgroundColorDark
              : MyntColors.backgroundColor,
        ),
        child: const Center(
          child: NoDataFound(
            title: "No Results Found",
            subtitle: "Try searching with a different keyword.",
            primaryEnabled: false,
            secondaryEnabled: false,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: resolveThemeColor(
          context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor,
        ),
      ),
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
        child: RawScrollbar(
          controller: _searchScrollController,
          thumbVisibility: true,
          thickness: 6,
          radius: const Radius.circular(0),
          thumbColor: resolveThemeColor(
            context,
            dark: WebColors.textSecondaryDark.withOpacity(0.5),
            light: WebColors.textSecondary.withOpacity(0.5),
          ),
          child: ListView.separated(
            controller: _searchScrollController,
            physics: const BouncingScrollPhysics(),
            itemCount: filteredResults!.length,
            separatorBuilder: (context, index) => Divider(
              height: 0,
              color: resolveThemeColor(
                context,
                dark: WebColors.dividerDark,
                light: WebColors.divider,
              ),
            ),
            itemBuilder: (BuildContext context, int index) {
              final scrip = filteredResults[index];

              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredItems[index] = true),
                onExit: (_) => setState(() => _hoveredItems[index] = false),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    splashColor: theme.isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                    highlightColor: theme.isDarkMode
                        ? Colors.white.withOpacity(0.02)
                        : Colors.black.withOpacity(0.02),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: Row(
                        children: [
                          // Scrip Info
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Symbol name and option
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      (scrip.masterName?.isNotEmpty == true)
                                          ? scrip.masterName!
                                          : "${scrip.symbol?.isNotEmpty == true ? scrip.symbol : scrip.tsym}"
                                              .replaceAll("-EQ", "")
                                              .toUpperCase(),
                                      style: WebTextStyles.symbolList(
                                        isDarkTheme: theme.isDarkMode,
                                        color: theme.isDarkMode
                                            ? MyntColors.textPrimaryDark
                                            : WebColors.textPrimary,
                                      ),
                                    ),
                                    if (scrip.masterName == null &&
                                        scrip.option != null &&
                                        scrip.option.toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Text(
                                          "${scrip.option}",
                                          style: WebTextStyles.symbolList(
                                            isDarkTheme: theme.isDarkMode,
                                            color: theme.isDarkMode
                                                ? WebDarkColors.textPrimary
                                                : WebColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    if (scrip.masterName == null &&
                                        scrip.expDate != null &&
                                        scrip.expDate.toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Text(
                                          " ${scrip.expDate}",
                                          style: WebTextStyles.symbolList(
                                            isDarkTheme: theme.isDarkMode,
                                            color: theme.isDarkMode
                                                ? WebDarkColors.textPrimary
                                                : WebColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        '${scrip.exch}',
                                        style: WebTextStyles.exchText(
                                            isDarkTheme: theme.isDarkMode,
                                            color: theme.isDarkMode
                                                ? WebDarkColors.textSecondary
                                                : WebColors.textSecondary),
                                      ),
                                    ),
                                    // Buy/Sell buttons for Basket mode - shown next to symbol
                                    const SizedBox(width: 8),
                                    IgnorePointer(
                                      ignoring:
                                          !(_hoveredItems[index] ?? false),
                                      child: AnimatedOpacity(
                                        opacity: (_hoveredItems[index] ?? false)
                                            ? 1.0
                                            : 0.0,
                                        duration:
                                            const Duration(milliseconds: 150),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Buy Button
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                onTap: () async {
                                                  await _handleBuySellClick(
                                                      context,
                                                      scrip,
                                                      true,
                                                      ref,
                                                      theme);
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: theme.isDarkMode ? MyntColors.secondary : MyntColors.primary.withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12.0,
                                                      vertical: 6.0),
                                                  child: Text(
                                                    'BUY',
                                                    style:
                                                        WebTextStyles.buttonSm(
                                                      isDarkTheme:
                                                          theme.isDarkMode,
                                                      color: theme.isDarkMode ? MyntColors.textWhite : MyntColors.primary,
                                                      fontWeight:
                                                          WebFonts.semiBold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Sell Button
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                onTap: () async {
                                                  await _handleBuySellClick(
                                                      context,
                                                      scrip,
                                                      false,
                                                      ref,
                                                      theme);
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: theme.isDarkMode ? MyntColors.errorDark : MyntColors.tertiary.withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12.0,
                                                      vertical: 6.0),
                                                  child: Text(
                                                    'SELL',
                                                    style:
                                                        WebTextStyles.buttonSm(
                                                      isDarkTheme:
                                                          theme.isDarkMode,
                                                      color: theme.isDarkMode ? MyntColors.textWhite : MyntColors.tertiary,
                                                      fontWeight:
                                                          WebFonts.semiBold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Handle Buy/Sell click for basket mode
  Future<void> _handleBuySellClick(
    BuildContext context,
    dynamic scrip,
    bool isBuy,
    WidgetRef ref,
    ThemesProvider theme,
  ) async {
    try {
      final marketWatch = ref.read(marketWatchProvider);
      final orderProv = ref.read(orderProvider);

      // Check basket limit
      if (orderProv.bsktScripList.length >=
          orderProv.frezQtyOrderSliceMaxLimit) {
        ResponsiveSnackBar.showWarning(
          context,
          "Basket is full. Maximum ${orderProv.frezQtyOrderSliceMaxLimit} items allowed per basket.",
        );
        return;
      }

      // Check if segment is active
      if (!marketWatch.exarr.contains('"${scrip.exch}"')) {
        ResponsiveSnackBar.showError(context, "Segment is not active.");
        return;
      }

      // Fetch scrip info first
      await marketWatch.fetchScripInfo(
        scrip.token.toString(),
        scrip.exch.toString(),
        context,
        true,
      );

      if (!context.mounted) return;

      // Check if scrip info was fetched
      if (marketWatch.scripInfoModel == null) {
        ResponsiveSnackBar.showError(
            context, "Failed to fetch scrip information.");
        return;
      }

      // Fetch depth data (getQuotes) to get LTP and percentage change
      await marketWatch.fetchScripQuote(
        scrip.token.toString(),
        scrip.exch.toString(),
        context,
      );

      if (!context.mounted) return;

      // Get LTP and percentage change from depth data (getQuotes)
      final depthData = marketWatch.getQuotes;
      final ltp =
          depthData?.lp?.toString() ?? depthData?.c?.toString() ?? "0.00";
      final perChange = depthData?.pc?.toString() ?? "0.00";

      // Create OrderScreenArgs
      OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: scrip.exch.toString(),
        tSym: scrip.tsym.toString(),
        isExit: false,
        token: scrip.token.toString(),
        transType: isBuy,
        lotSize: marketWatch.scripInfoModel?.ls?.toString() ?? "1",
        ltp: ltp,
        perChange: perChange,
        orderTpye: '',
        holdQty: '',
        isModify: false,
        prd: null,
        raw: {
          'exch': scrip.exch.toString(),
          'token': scrip.token.toString(),
          'tsym': scrip.tsym.toString(),
          'symbol': scrip.symbol?.toString() ?? scrip.tsym.toString(),
          'expDate': scrip.expDate?.toString() ?? '',
          'option': scrip.option?.toString() ?? '',
          'trantype': isBuy ? 'B' : 'S',
          'qty': marketWatch.scripInfoModel?.ls?.toString() ?? '1',
        },
      );

      // Clear search
      marketWatch.searchClear();
      _searchController.clear();
      setState(() {
        _searchValue = "";
      });

      // Show order screen as draggable dialog using showDraggable method
      // This uses Overlay.of(context) which works from within the dialog
      if (context.mounted) {
        PlaceOrderScreenWeb.showDraggable(
          context: context,
          orderArg: orderArgs,
          scripInfo: marketWatch.scripInfoModel!,
          isBasket: "Basket",
        );
      }
    } catch (e, stackTrace) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(
            context, "Failed to open order screen: ${e.toString()}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final theme = ref.read(themeProvider);
    final basket = ref.watch(orderProvider);
    // TC_324.2: Kite-style row placing once any row has been sent.
    final sentMode = _isSentMode(basket);
    _selected.removeWhere((i) => i >= basket.bsktScripList.length);
    final toPlace = _selectedUnsent(basket);
    final isPlacing =
        basket.basketOverallStatus[basket.selectedBsktName] == 'placing';

    // Calculate margins
    final preTradeMargin = basket.bsktScripList.isEmpty ||
            basket.bsktOrderMargin == null
        ? "0.00"
        : basket.bsktOrderMargin!.basketMargin.toIndianFormat();

    final postTradeMargin = basket.bsktScripList.isEmpty ||
            basket.bsktOrderMargin == null
        ? "0.00"
        : basket.bsktOrderMargin!.postTradeMargin.toIndianFormat();

    return Material(
      color: theme.isDarkMode
          ? styles.MyntColors.backgroundColorDark
          : styles.MyntColors.backgroundColor,
      child: Stack(
        children: [
          Column(
            children: [
              // 1. Header: "Basket order" + Close — drag handle for the dialog
              MouseRegion(
                cursor: widget.onDrag != null
                    ? SystemMouseCursors.move
                    : MouseCursor.defer,
                child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: widget.onDrag == null
                    ? null
                    : (d) => widget.onDrag!(d.delta),
                child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.isDarkMode
                          ? WebDarkColors.divider
                          : WebColors.divider,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Basket order",
                      style: WebTextStyles.custom(
                        fontSize: 14,
                        isDarkTheme: theme.isDarkMode,
                        color: theme.isDarkMode
                            ? WebDarkColors.textPrimary
                            : WebColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: _closeWindow,
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: theme.isDarkMode
                            ? WebDarkColors.iconSecondary
                            : WebColors.iconSecondary,
                      ),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
                ),
              ),

              // 2. Toolbar: Name Section + Search Bar
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Basket Name Section
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.isDarkMode
                            ? WebDarkColors.surface
                            : const Color(0xfff5f5f5), // Light gray bg
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        basket.selectedBsktName.isEmpty
                            ? widget.bsktName
                            : basket.selectedBsktName,
                        style: WebTextStyles.custom(
                          fontSize: 13,
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textPrimary
                              : WebColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action Icons (Edit/Delete Basket Placeholder)
                    _buildBasketHoverButton(
                      icon: Icons.edit_outlined,
                      color: resolveThemeColor(
                        context,
                        dark: styles.MyntColors.textSecondaryDark,
                        light: styles.MyntColors.textSecondary,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (BuildContext context) {
                            final theme = ref.read(themeProvider);
                            return Dialog(
                              backgroundColor: resolveThemeColor(
                                context,
                                dark: MyntColors.backgroundColorDark,
                                light: MyntColors.backgroundColor,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: SizedBox(
                                width: 400,
                                child: CreateBasket(
                                  initialName: basket.selectedBsktName.isEmpty
                                      ? widget.bsktName
                                      : basket.selectedBsktName,
                                  isEdit: true,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      theme: theme,
                    ),
                    const SizedBox(width: 4),
                    _buildBasketHoverButton(
                      icon: Icons.delete_outline,
                      color: resolveThemeColor(
                        context,
                        dark: styles.MyntColors.textSecondaryDark,
                        light: styles.MyntColors.textSecondary,
                      ),
                      onPressed: () => _handleDeleteBasket(theme),
                      theme: theme,
                    ),

                    const Spacer(),

                    // TC_324.2: delete ticked rows (Kite "Delete (N)").
                    if (sentMode && _selected.isNotEmpty) ...[
                      TextButton.icon(
                        onPressed: isPlacing ? null : _deleteSelected,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: resolveThemeColor(context,
                              dark: styles.MyntColors.lossDark,
                              light: styles.MyntColors.loss),
                        ),
                        label: Text(
                          "Delete (${_selected.length})",
                          style: MyntWebTextStyles.body(
                            context,
                            fontWeight: MyntFonts.medium,
                            color: resolveThemeColor(context,
                                dark: styles.MyntColors.lossDark,
                                light: styles.MyntColors.loss),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Search Bar
                    Container(
                      width: 450,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.isDarkMode
                            ? MyntColors.inputBgDark
                            : const Color(0xfff5f5f5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: WebTextStyles.formInput(
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textPrimary
                              : WebColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5), // Centered vertically
                          border: InputBorder.none,
                          hintText: "Search script",
                          hintStyle: WebTextStyles.custom(
                              fontSize: 14,
                              isDarkTheme: theme.isDarkMode,
                              color: theme.isDarkMode
                                  ? WebDarkColors.textSecondary
                                  : WebColors.textSecondary,
                              fontWeight: FontWeight.normal),
                          prefixIcon: Icon(Icons.search,
                              size: 18,
                              color: resolveThemeColor(
                                context,
                                dark: styles.MyntColors.textSecondaryDark,
                                light: styles.MyntColors.textSecondary,
                              )),
                          suffixIcon: _searchValue.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _hoveredItems.clear();
                                    setState(() {
                                      _searchValue = "";
                                    });
                                    ref.read(marketWatchProvider).searchClear();
                                  },
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: resolveThemeColor(
                                      context,
                                      dark: styles.MyntColors.textSecondaryDark,
                                      light: styles.MyntColors.textSecondary,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        onChanged: (value) async {
                          _hoveredItems.clear();
                          setState(() {
                            _searchValue = value.toUpperCase();
                          });
                          final marketWatch = ref.read(marketWatchProvider);
                          if (value.isEmpty) {
                            marketWatch.searchClear();
                          } else {
                            marketWatch.scripSearch(value.toUpperCase(),
                                context, _tabController.index, "Basket");
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Table Content
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: basket.bsktScripList.isEmpty
                      ? NoDataFoundWeb(secondaryEnabled: false)
                      : Builder(
                          builder: (context) {
                            // Process basket items to extract symbol info
                            // IMPORTANT: Create deep copy to avoid mutating original data
                            final processedItems = basket.bsktScripList
                                .map((item) => Map<String, dynamic>.from(item))
                                .toList();
                            for (int i = 0; i < processedItems.length; i++) {
                              processedItems[i]['_originalIndex'] = i;
                              if (processedItems[i]['exch'] == "BFO" &&
                                  processedItems[i]["dname"] != "null") {
                                List<String> splitVal = processedItems[i]
                                        ["dname"]
                                    .toString()
                                    .split(" ");
                                processedItems[i]['symbol'] = splitVal[0];
                                processedItems[i]['expDate'] =
                                    "${splitVal[1]} ${splitVal[2]}";
                                processedItems[i]['option'] =
                                    splitVal.length > 4
                                        ? "${splitVal[3]} ${splitVal[4]}"
                                        : splitVal[3];
                              } else {
                                Map spilitSymbol = spilitTsym(
                                    value: "${processedItems[i]['tsym']}");
                                processedItems[i]['symbol'] =
                                    "${spilitSymbol["symbol"]}";
                                processedItems[i]['expDate'] =
                                    "${spilitSymbol["expDate"]}";
                                processedItems[i]['option'] =
                                    "${spilitSymbol["option"]}";
                              }
                            }

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final screenWidth = constraints.maxWidth;

                                // Define headers and fixed widths for shadcn.Table
                                final basket = ref.read(orderProvider);
                                final count = basket.bsktScripList.length;
                                final maxCount =
                                    basket.frezQtyOrderSliceMaxLimit;

                                final headers = [
                                  'Instrument ($count / $maxCount)',
                                  'Type',
                                  'Product / Type',
                                  'Qty.',
                                  'LTP',
                                  'Price',
                                  'Status',
                                ];

                                // Instrument column gets 2x width, others share remaining space equally
                                // Total units: 2 (instrument) + 6 (other columns) = 8 units
                                final unitWidth = screenWidth / 8;
                                final instrumentWidth = unitWidth * 2; // 2 units for Instrument
                                final otherColumnWidth = unitWidth; // 1 unit each for other columns

                                // Build column widths map
                                final columnWidths = <int, shadcn.FixedTableSize>{};
                                for (int i = 0; i < headers.length; i++) {
                                  columnWidths[i] = shadcn.FixedTableSize(
                                    i == 0 ? instrumentWidth : otherColumnWidth
                                  );
                                }

                                final sortedItems =
                                    _getSortedBasketScripts(processedItems);

                                // Build the shadcn Table (no horizontal scroll needed with equal widths)
                                return Column(
                                  children: [
                                    // Header
                                    shadcn.Table(
                                      columnWidths: columnWidths,
                                      defaultRowHeight:
                                          const shadcn.FixedTableSize(40),
                                      rows: [
                                        shadcn.TableHeader(
                                          cells: headers
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            final index = entry.key;
                                            final label = entry.value;
                                            final isNumeric =
                                                _isNumericColumnBasketItems(
                                                    label);
                                            // TC_324.2: select-all beside Instrument once rows are sent.
                                            final selectAll = index == 0 &&
                                                    sentMode
                                                ? _buildRowCheckbox(
                                                    value: sortedItems.isNotEmpty &&
                                                        _selected.length ==
                                                            sortedItems.length,
                                                    onChanged: (v) => setState(() {
                                                      _selected.clear();
                                                      if (v) {
                                                        _selected.addAll(List.generate(
                                                            sortedItems.length,
                                                            (i) => i));
                                                      }
                                                    }),
                                                  )
                                                : null;
                                            return buildHeaderCell(label,
                                                index, theme, headers.length, isNumeric, selectAll);
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                    // Body
                                    Expanded(
                                      child: RawScrollbar(
                                        controller: _verticalScrollController,
                                        thumbVisibility: true,
                                        thickness: 6,
                                        radius: const Radius.circular(3),
                                        child: SingleChildScrollView(
                                          controller: _verticalScrollController,
                                          child: shadcn.Table(
                                            columnWidths: columnWidths,
                                            defaultRowHeight:
                                                const shadcn.FixedTableSize(40),
                                            rows: sortedItems
                                                .asMap()
                                                .entries
                                                .map((rowEntry) {
                                              final rowIndex = rowEntry.key;
                                              final item = rowEntry.value;
                                              final originalIndex =
                                                  item['_originalIndex']
                                                      as int;
                                              final uniqueId =
                                                  'basket_$originalIndex';

                                              return shadcn.TableRow(
                                                cells: headers
                                                    .asMap()
                                                    .entries
                                                    .map((colEntry) {
                                                  final colIndex =
                                                      colEntry.key;
                                                  final headerLabel =
                                                      colEntry.value;
                                                  final isNumeric =
                                                      _isNumericColumnBasketItems(
                                                          headerLabel);

                                                  return buildCellWithHover(
                                                    rowIndex: rowIndex,
                                                    columnIndex: colIndex,
                                                    totalColumns: headers.length,
                                                    alignRight: isNumeric,
                                                    child: GestureDetector(
                                                      behavior:
                                                          HitTestBehavior.opaque,
                                                      onTap: () async {
                                                        // Handle row tap logic
                                                        await ref
                                                            .read(
                                                                marketWatchProvider)
                                                            .fetchScripInfo(
                                                                "${item['token']}",
                                                                '${item['exch']}',
                                                                context,
                                                                true);
                                                        if (!context.mounted)
                                                          return;

                                                        // Stamp the row position and price type on the COPY that is
                                                        // passed to the edit dialog — the dialog's save removes the
                                                        // row at raw['index'], so it must travel with this map.
                                                        item['index'] =
                                                            originalIndex;
                                                        item['prctyp'] =
                                                            item['prctype'];

                                                        final ltp = item['lp']
                                                                ?.toString() ??
                                                            "0.00";
                                                        final perChange = item['pc']
                                                                ?.toString() ??
                                                            "0.00";

                                                        OrderScreenArgs orderArgs =
                                                            OrderScreenArgs(
                                                                exchange:
                                                                    '${item['exch']}',
                                                                tSym:
                                                                    '${item['tsym']}',
                                                                isExit: false,
                                                                token:
                                                                    "${item['token']}",
                                                                transType: item[
                                                                        'trantype'] ==
                                                                    'B',
                                                                lotSize: ref
                                                                    .read(
                                                                        marketWatchProvider)
                                                                    .scripInfoModel
                                                                    ?.ls
                                                                    .toString(),
                                                                ltp: ltp,
                                                                perChange:
                                                                    perChange,
                                                                orderTpye: '',
                                                                holdQty: '',
                                                                isModify: true,
                                                                prd: item['prd']
                                                                    ?.toString(),
                                                                raw: item);

                                                        final scripInfo = ref
                                                            .read(
                                                                marketWatchProvider)
                                                            .scripInfoModel;
                                                        if (scripInfo != null) {
                                                          PlaceOrderScreenWeb
                                                              .showDraggable(
                                                            context: context,
                                                            orderArg: orderArgs,
                                                            scripInfo: scripInfo,
                                                            isBasket:
                                                                'BasketEdit',
                                                          );
                                                        }
                                                      },
                                                      child:
                                                          _buildBasketCellWidget(
                                                        headerLabel,
                                                        item,
                                                        originalIndex,
                                                        theme,
                                                        uniqueId,
                                                        sentMode: sentMode,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                ),
              ),

              // 4. Footer: Warning + Margins + Action Buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Multi-segment warning bar
                  if (_hasMultipleExchanges(basket.bsktScripList))
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: BoxDecoration(
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.warningDark.withOpacity(0.1),
                          light: MyntColors.warning.withOpacity(0.1),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: theme.isDarkMode
                                ? WebDarkColors.divider
                                : WebColors.divider,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.warningDark,
                              light: MyntColors.warning,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Basket should contain orders of only 1 segment",
                            style: WebTextStyles.custom(
                              fontSize: 12,
                              isDarkTheme: theme.isDarkMode,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.warningDark,
                                light: MyntColors.warning,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Margins + Action Buttons row
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: theme.isDarkMode
                              ? WebDarkColors.divider
                              : WebColors.divider,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Margin Info
                        Flexible(
                          child: Row(
                            children: [
                              Text(
                                "Basket Margin: ",
                                style: WebTextStyles.custom(
                                    fontSize: 13,
                                    isDarkTheme: theme.isDarkMode,
                                    color: theme.isDarkMode
                                        ? WebDarkColors.textPrimary
                                        : WebColors.textPrimary,
                                    fontWeight: FontWeight.w400),
                              ),
                              Text(
                                "₹$preTradeMargin",
                                style: WebTextStyles.custom(
                                    fontSize: 13,
                                    isDarkTheme: theme.isDarkMode,
                                    color: theme.isDarkMode
                                        ? WebDarkColors.textPrimary
                                        : WebColors.textPrimary,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 24),
                              Text(
                                "Post Trade Margin: ",
                                style: WebTextStyles.custom(
                                    fontSize: 13,
                                    isDarkTheme: theme.isDarkMode,
                                    color: theme.isDarkMode
                                        ? WebDarkColors.textPrimary
                                        : WebColors.textPrimary,
                                    fontWeight: FontWeight.w400),
                              ),
                              Text(
                                "₹$postTradeMargin",
                                style: WebTextStyles.custom(
                                    fontSize: 13,
                                    isDarkTheme: theme.isDarkMode,
                                    color: theme.isDarkMode
                                        ? WebDarkColors.textPrimary
                                        : WebColors.textPrimary,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),

                    // Refresh Button
                    IconButton(
                      onPressed: () async {
                        await basket.fetchBasketMargin();
                      },
                      icon: Icon(
                        Icons.refresh,
                        size: 22,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary,
                        ),
                      ),
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 16),

                    // TC_324.2: "Place Selected (N)" — only ticked rows not yet sent.
                    if (sentMode && toPlace.isNotEmpty) ...[
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: isPlacing ||
                                  _hasMultipleExchanges(basket.bsktScripList)
                              ? null
                              : () async {
                                  setState(() => _selected.removeAll(toPlace));
                                  await basket.placeBasketItems(
                                      context, toPlace);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.isDarkMode
                                ? MyntColors.secondary
                                : MyntColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5)),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            elevation: 0,
                          ),
                          child: Text(
                            isPlacing
                                ? "Placing..."
                                : "Place Selected (${toPlace.length})",
                            style: WebTextStyles.custom(
                                fontSize: 13,
                                isDarkTheme: theme.isDarkMode,
                                color: MyntColors.backgroundColor,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Place Order / Reset Orders Button
                    SizedBox(
                      height: 36,
                      // TC_324.2: any sent row keeps Reset, so a whole-basket
                      // Place Order can never re-send old rows.
                      child: sentMode
                          // Reset Orders - Outlined style matching the image
                          ? OutlinedButton(
                              onPressed: basket.bsktScripList.isEmpty
                                  ? null
                                  : () {
                                      setState(() => _selected.clear());
                                      basket.resetBasketOrderTracking(
                                          widget.bsktName);
                                      ResponsiveSnackBar.showSuccess(context,
                                          "Basket reset. You can place orders again.");
                                    },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.primaryDark,
                                    light: MyntColors.primary,
                                  ),
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5)),
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                              ),
                              child: Text(
                                "Reset Orders",
                                style: WebTextStyles.custom(
                                    fontSize: 13,
                                    isDarkTheme: theme.isDarkMode,
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.primaryDark,
                                      light: MyntColors.primary,
                                    ),
                                    fontWeight: FontWeight.w600),
                              ),
                            )
                          // Place Order - Primary filled style
                          : ElevatedButton(
                              onPressed: basket.bsktScripList.isEmpty ||
                                      _hasMultipleExchanges(basket.bsktScripList)
                                  ? null
                                  : () async {
                                      await basket.placeBasketOrder(context,
                                          navigateToOrderBook: false);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.isDarkMode
                                    ? MyntColors.secondary
                                    : MyntColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5)),
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                elevation: 0,
                              ),
                              child: Text(
                                "Place Order",
                                style: WebTextStyles.custom(
                                    fontSize: 13,
                                    isDarkTheme: theme.isDarkMode,
                                    color: MyntColors.backgroundColor,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              ],
              ),
            ],
          ),

          // Search Results Overlay
          if (_searchValue.isNotEmpty)
            Positioned(
              top: 110, // Header(50) + Toolbar(60)
              right: 16, // Padding of Toolbar
              width: 450, // Width of Search Bar
              height: 400,
              child: MouseRegion(
                onExit: (_) {
                  if (_hoveredItems.isNotEmpty) {
                    setState(() => _hoveredItems.clear());
                  }
                },
                child: Container(
                decoration: BoxDecoration(
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.backgroundColorDark,
                      light: MyntColors.backgroundColor,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: theme.isDarkMode
                          ? WebDarkColors.divider
                          : WebColors.divider,
                    )),
                child: Column(
                  children: [
                    // Use existing search tabs if needed, or hide them for 'simple' search
                    // Image 0 doesn't show tabs, but functionality might require them.
                    // Keeping tabs for functionality but styling them minimal if possible.
                    // For now, simpler: just results.
                    Expanded(
                      child: _buildSearchResults(ref, theme),
                    ),
                  ],
                ),
              ),
              ),
            ),
        ],
      ),
    );
  }

  String formatToTimeOnly(String rawDate) {
    try {
      final dateTime = DateFormat("dd MMM yyyy, hh:mm a").parse(rawDate);
      return DateFormat("hh:mm a").format(dateTime);
    } catch (e) {
      return ''; // or return rawDate if you want fallback
    }
  }

  // Helper methods for individual item status indicators



  Widget _buildBasketCellWidget(
    String column,
    Map<String, dynamic> item,
    int originalIndex,
    ThemesProvider theme,
    String uniqueId, {
    bool sentMode = false,
  }) {
    if (column.startsWith('Instrument')) {
      final cell = _BasketInstrumentCell(
        item: item,
        originalIndex: originalIndex,
        theme: theme,
        uniqueId: uniqueId,
        hoveredRowIndex: _hoveredRowIndex,
        onDelete: (item, index, theme) =>
            _handleDeleteBasketScript(item, index, theme),
        onCopy: (item, index, theme) =>
            _handleCopyBasketScript(item, index, theme),
        onEdit: (item, index, theme) =>
            _handleEditBasketScript(item, index, theme),
      );
      if (!sentMode) return cell;
      // TC_324.2: tick box (sent rows: delete only).
      return Row(
        children: [
          _buildRowCheckbox(
            value: _selected.contains(originalIndex),
            onChanged: (v) => setState(() {
              v ? _selected.add(originalIndex) : _selected.remove(originalIndex);
            }),
          ),
          const SizedBox(width: 6),
          Expanded(child: cell),
        ],
      );
    }

    switch (column) {
      case 'Type':
        final trantype = item["trantype"]?.toString();
        final isBuy = trantype != "S";
        final color = isBuy ? resolveThemeColor(context, dark: styles.MyntColors.profitDark, light: styles.MyntColors.profit)  : resolveThemeColor(context, dark: styles.MyntColors.lossDark, light: styles.MyntColors.loss);
        return SizedBox.expand(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: isBuy ? "BUY" : "SELL",
              child: Text(
                isBuy ? "BUY" : "SELL",
                style: MyntWebTextStyles.tableCell(
                  context,
                  color: color,
                  darkColor: color,
                  lightColor: color,
                  fontWeight: MyntFonts.semiBold,
                ).copyWith(fontFeatures: [FontFeature.tabularFigures()]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      case 'Product / Type':
        String product = "CNC";
        switch (item["prd"]) {
          case "I":
            product = "MIS";
            break;
          case "C":
            product = "CNC";
            break;
          case "M":
            product = "NRML";
            break;
          case "H":
            product = "CO";
            break;
          case "B":
            product = "BO";
            break;
        }
        // Show the stored order price type as-is (LMT / MKT / SL-LMT / SL-MKT)
        final priceTypeLabel = item["prctype"]?.toString() ?? "LMT";
        final productType = "$product / $priceTypeLabel";
        return SizedBox.expand(
          child: Align(
            alignment: Alignment.centerRight,
            child: Tooltip(
              message: productType,
              child: Text(
                productType,
                style: MyntWebTextStyles.tableCell(
                  context,
                  fontWeight: MyntFonts.medium,
                ).copyWith(fontFeatures: [FontFeature.tabularFigures()]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      case 'Qty.':
        final rawQty = int.tryParse(item["qty"]?.toString() ?? '0') ?? 0;
        final ls = int.tryParse(item["ls"]?.toString() ?? '1') ?? 1;
        // For MCX, display qty as lots (divide by lot size) to match place order screen
        final totalQty = item["exch"] == 'MCX' && ls > 1
            ? (rawQty ~/ ls).toString()
            : rawQty.toString();
        return SizedBox.expand(
          child: Align(
            alignment: Alignment.centerRight,
            child: Tooltip(
              message: totalQty,
              child: Text(
                totalQty,
                style: MyntWebTextStyles.tableCell(
                  context,
                  fontWeight: MyntFonts.medium,
                ).copyWith(fontFeatures: [FontFeature.tabularFigures()]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      case 'LTP':
        return SizedBox.expand(
          child: Align(
            alignment: Alignment.centerRight,
            child: _BasketLtpCell(
              item: item,
              theme: theme,
            ),
          ),
        );
      case 'Price':
        final price = item["prc"]?.toString() ?? '0.00';
        final basketPrcType = item["prctype"]?.toString() ?? 'LMT';
        final trigger = item["trgprc"]?.toString() ?? '';
        // height 1.1 keeps the two-line price + trigger within the 40px row
        final priceStyle = MyntWebTextStyles.tableCell(
          context,
          fontWeight: MyntFonts.medium,
        ).copyWith(height: 1.1, fontFeatures: [FontFeature.tabularFigures()]);
        final trigColor = resolveThemeColor(context,
            dark: styles.MyntColors.textSecondaryDark,
            light: styles.MyntColors.textSecondary);
        final trigStyle = MyntWebTextStyles.tableCell(
          context,
          color: trigColor,
          darkColor: trigColor,
          lightColor: trigColor,
          fontWeight: MyntFonts.medium,
        ).copyWith(
            fontSize: 11,
            height: 1.1,
            fontFeatures: [FontFeature.tabularFigures()]);

        Widget priceContent;
        String tooltipText;
        if (basketPrcType == 'SL-MKT') {
          // Executes at market once triggered — MKT on top, trigger below
          tooltipText = 'MKT  Trig. $trigger';
          priceContent = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MKT',
                style: priceStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                'Trig. $trigger',
                style: trigStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        } else if (basketPrcType == 'SL-LMT') {
          tooltipText = '$price  Trig. $trigger';
          priceContent = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                price,
                style: priceStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                'Trig. $trigger',
                style: trigStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        } else if (basketPrcType == 'MKT') {
          tooltipText = 'MKT';
          priceContent = Text(
            tooltipText,
            style: priceStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        } else {
          tooltipText = price;
          priceContent = Text(
            price,
            style: priceStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        return SizedBox.expand(
          child: Align(
            alignment: Alignment.centerRight,
            child: Tooltip(
              message: tooltipText,
              child: priceContent,
            ),
          ),
        );
      case 'Status':
        // TC_324.2: unsent row in a sent basket — no badge (was a misleading
        // 'PENDING'); users tick it and use Place Selected. Per-row Place dropped.
        if (item["orderStatus"] == null && sentMode) {
          return const SizedBox.shrink();
        }
        // if (item["orderStatus"] == null && sentMode) {
        //   final basket = ref.read(orderProvider);
        //   final isPlacing =
        //       basket.basketOverallStatus[basket.selectedBsktName] == 'placing';
        //   return SizedBox.expand(
        //     child: Align(
        //       alignment: Alignment.centerRight,
        //       child: SizedBox(
        //         height: 28,
        //         child: MyntPrimaryButton(
        //           label: "Place",
        //           size: MyntButtonSize.small,
        //           padding: const EdgeInsets.symmetric(horizontal: 14),
        //           onPressed: isPlacing ||
        //                   _hasMultipleExchanges(basket.bsktScripList)
        //               ? null
        //               : () => basket.placeBasketItems(context, [originalIndex]),
        //         ),
        //       ),
        //     ),
        //   );
        // }
        final orderStatus = item["orderStatus"]?.toString().toUpperCase() ?? 'PENDING';
        // TC_324.1 sibling: FAILED/REJECTED badge shows the reason on hover.
        final reason = item["rejectionReason"]?.toString().trim() ?? '';
        final statusTooltip =
            (orderStatus == 'FAILED' || orderStatus == 'REJECTED') &&
                    reason.isNotEmpty
                ? reason
                : orderStatus;
        Color statusColor;
        if (orderStatus == 'PLACED') {
          statusColor = resolveThemeColor(
            context,
            dark: styles.MyntColors.profitDark,
            light: styles.MyntColors.profit,
          );
        } else if (orderStatus == 'FAILED' || orderStatus == 'REJECTED') {
          statusColor = resolveThemeColor(
            context,
            dark: styles.MyntColors.lossDark,
            light: styles.MyntColors.loss,
          );
        } else {
          statusColor = styles.MyntColors.warning;
        }
        return SizedBox.expand(
          child: Align(
            alignment: Alignment.centerRight,
            child: Tooltip(
              message: statusTooltip,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  orderStatus,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                  style: MyntWebTextStyles.para(
                    context,
                    color: statusColor,
                    fontWeight: MyntFonts.medium,
                  ),
                ),
              ),
            ),
          ),
        );
      // case 'Actions':
      //   return SizedBox.expand(
      //     child: Align(
      //       alignment: Alignment.centerRight,
      //       child: Row(
      //         mainAxisSize: MainAxisSize.min,
      //         mainAxisAlignment: MainAxisAlignment.end,
      //         children: [
      //           // Copy
      //           _buildBasketHoverButton(
      //           icon: Icons.copy_outlined,
      //           color: resolveThemeColor(
      //             context,
      //             dark: MyntColors.textSecondaryDark,
      //             light: MyntColors.textSecondary,
      //           ),
      //           onPressed: () async {
      //             await ref.read(marketWatchProvider).fetchScripInfo(
      //                 "${item['token']}", '${item['exch']}', context, true);

      //             if (!context.mounted) return;

      //             final ltp = item['lp']?.toString() ?? "0.00";
      //             final perChange = item['pc']?.toString() ?? "0.00";

      //             OrderScreenArgs orderArgs = OrderScreenArgs(
      //                 exchange: '${item['exch']}',
      //                 tSym: '${item['tsym']}',
      //                 isExit: false,
      //                 token: "${item['token']}",
      //                 transType: item['trantype'] == 'B',
      //                 lotSize: ref
      //                     .read(marketWatchProvider)
      //                     .scripInfoModel
      //                     ?.ls
      //                     .toString(),
      //                 ltp: ltp,
      //                 perChange: perChange,
      //                 orderTpye: '',
      //                 holdQty: '',
      //                 isModify: false, // Copy as new order
      //                 prd: item['prd']?.toString(),
      //                 raw: item);

      //             final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
      //             if (scripInfo == null) {
      //               ResponsiveSnackBar.showError(
      //                   context, 'Unable to fetch scrip information');
      //               return;
      //             }

      //             PlaceOrderScreenWeb.showDraggable(
      //               context: context,
      //               orderArg: orderArgs,
      //               scripInfo: scripInfo,
      //               isBasket: 'Basket', // Add to basket
      //             );
      //           },
      //           theme: theme,
      //         ),
      //         const SizedBox(width: 4),
      //         // Edit
      //         _buildBasketHoverButton(
      //           icon: Icons.edit_outlined,
      //           color: resolveThemeColor(
      //             context,
      //             dark: MyntColors.textSecondaryDark,
      //             light: MyntColors.textSecondary,
      //           ),
      //           onPressed: () async {
      //             // Trigger edit mode
      //             await ref.read(marketWatchProvider).fetchScripInfo(
      //                 "${item['token']}", '${item['exch']}', context, true);

      //             if (!context.mounted) return;

      //             final ltp = item['lp']?.toString() ?? "0.00";
      //             final perChange = item['pc']?.toString() ?? "0.00";

      //             OrderScreenArgs orderArgs = OrderScreenArgs(
      //                 exchange: '${item['exch']}',
      //                 tSym: '${item['tsym']}',
      //                 isExit: false,
      //                 token: "${item['token']}",
      //                 transType: item['trantype'] == 'B' ? true : false,
      //                 lotSize: ref
      //                     .read(marketWatchProvider)
      //                     .scripInfoModel
      //                     ?.ls
      //                     .toString(),
      //                 ltp: ltp,
      //                 perChange: perChange,
      //                 orderTpye: '',
      //                 holdQty: '',
      //                 isModify: true,
      //                 prd: item['prd']?.toString(),
      //                 raw: item);

      //             final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
      //             if (scripInfo == null) {
      //               ResponsiveSnackBar.showError(
      //                   context, 'Unable to fetch scrip information');
      //               return;
      //             }

      //             PlaceOrderScreenWeb.showDraggable(
      //               context: context,
      //               orderArg: orderArgs,
      //               scripInfo: scripInfo,
      //               isBasket: 'BasketEdit',
      //             );
      //           },
      //           theme: theme,
      //         ),
      //         const SizedBox(width: 4),
      //         // Delete
      //         _buildBasketHoverButton(
      //           icon: Icons.delete_outline,
      //           color: styles.MyntColors.loss,
      //           onPressed: () =>
      //               _handleDeleteBasketScript(item, originalIndex, theme),
      //           theme: theme,
      //         ),
      //         ],
      //       ),
      //     ),
      //   );
      default:
        return const SizedBox.shrink();
    }
  }


  Widget _buildBasketHoverButton({
    String? label,
    IconData? icon,
    required Color color,
    Color? backgroundColor,
    Color? borderColor,
    double? borderRadius,
    required VoidCallback? onPressed,
    required ThemesProvider theme,
  }) {
    final borderRadiusValue = borderRadius ?? 5.0;
    return SizedBox(
      height: 28,
      width: label == null && icon != null ? 28 : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          splashColor: color.withOpacity(0.15),
          highlightColor: color.withOpacity(0.08),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadiusValue),
              border: borderColor != null
                  ? Border.all(
                      color: borderColor,
                      width: 1,
                    )
                  : null,
            ),
            child: Center(
              child: icon != null
                  ? Icon(
                      icon,
                      size: 16,
                      color: color,
                    )
                  : Text(
                      label ?? "",
                      style: WebTextStyles.custom(
                        fontSize: 11,
                        isDarkTheme: theme.isDarkMode,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCopyBasketScript(
      Map<String, dynamic> item, int index, ThemesProvider theme) async {
    await ref.read(marketWatchProvider).fetchScripInfo(
        "${item['token']}", '${item['exch']}', context, true);

    if (!context.mounted) return;

    final ltp = item['lp']?.toString() ?? "0.00";
    final perChange = item['pc']?.toString() ?? "0.00";

    OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: '${item['exch']}',
        tSym: '${item['tsym']}',
        isExit: false,
        token: "${item['token']}",
        transType: item['trantype'] == 'B',
        lotSize: ref
            .read(marketWatchProvider)
            .scripInfoModel
            ?.ls
            .toString(),
        ltp: ltp,
        perChange: perChange,
        orderTpye: '',
        holdQty: '',
        isModify: false, // Copy as new order
        prd: item['prd']?.toString(),
        raw: item);

    final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
    if (scripInfo == null) {
      ResponsiveSnackBar.showError(
          context, 'Unable to fetch scrip information');
      return;
    }

    PlaceOrderScreenWeb.showDraggable(
      context: context,
      orderArg: orderArgs,
      scripInfo: scripInfo,
      isBasket: 'Basket', // Add to basket
    );
  }

  Future<void> _handleEditBasketScript(
      Map<String, dynamic> item, int index, ThemesProvider theme) async {
    await ref.read(marketWatchProvider).fetchScripInfo(
        "${item['token']}", '${item['exch']}', context, true);

    if (!context.mounted) return;

    // Stamp the row position and price type so the edit dialog's save
    // removes the correct row (raw['index']) instead of falling back to 0.
    item['index'] = index;
    item['prctyp'] = item['prctype'];

    final ltp = item['lp']?.toString() ?? "0.00";
    final perChange = item['pc']?.toString() ?? "0.00";

    OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: '${item['exch']}',
        tSym: '${item['tsym']}',
        isExit: false,
        token: "${item['token']}",
        transType: item['trantype'] == 'B' ? true : false,
        lotSize: ref
            .read(marketWatchProvider)
            .scripInfoModel
            ?.ls
            .toString(),
        ltp: ltp,
        perChange: perChange,
        orderTpye: '',
        holdQty: '',
        isModify: true,
        prd: item['prd']?.toString(),
        raw: item);

    final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
    if (scripInfo == null) {
      ResponsiveSnackBar.showError(
          context, 'Unable to fetch scrip information');
      return;
    }

    PlaceOrderScreenWeb.showDraggable(
      context: context,
      orderArg: orderArgs,
      scripInfo: scripInfo,
      isBasket: 'BasketEdit',
    );
  }

  Future<void> _handleDeleteBasketScript(
      Map<String, dynamic> item, int index, ThemesProvider theme) async {
    // Show confirmation dialog
    final symbol = DerivativeMaster.nameFor(
            item['exch']?.toString(), item['token']?.toString()) ??
        (item['symbol']?.replaceAll("-EQ", "") ?? 'N/A');
    final shouldDelete = await _confirmDelete(
        'Delete Script', 'Are you sure you want to delete "$symbol"?');

    if (shouldDelete == true && mounted) {
      final basket = ref.read(orderProvider);
      setState(() => _selected.clear());
      // TC_324.2: removeBsktScrips re-saves row statuses after the index shift.
      await basket.removeBsktScrips([index], _currentBasketName);
      await basket.fetchBasketMargin();
    }
  }

  /// Delete confirmation used by single-row and ticked-rows delete.
  Future<bool?> _confirmDelete(String title, String message) {
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
                    border: Border(
                      bottom: BorderSide(
                        color: resolveThemeColor(
                          context,
                          dark: styles.MyntColors.dividerDark,
                          light: styles.MyntColors.divider,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: MyntWebTextStyles.title(
                          context,
                          color: resolveThemeColor(context,
                              dark: styles.MyntColors.textPrimaryDark,
                              light: styles.MyntColors.textPrimary),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: resolveThemeColor(context,
                                  dark: styles.MyntColors.textSecondaryDark,
                                  light: styles.MyntColors.textSecondary),
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
                        message,
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.body(
                          context,
                          color: resolveThemeColor(context,
                              dark: styles.MyntColors.textPrimaryDark,
                              light: styles.MyntColors.textPrimary),
                        ),
                      ),

                      // Red Delete button
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: resolveThemeColor(context,
                                dark: styles.MyntColors.errorDark,
                                light: styles.MyntColors.tertiary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Delete',
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

  Future<void> _handleDeleteBasket(ThemesProvider theme) async {
    final basketProvider = ref.read(orderProvider);
    final bsktName = basketProvider.selectedBsktName.isEmpty
        ? widget.bsktName
        : basketProvider.selectedBsktName;

    final shouldDelete = await showDialog<bool>(
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
                // Header with title and close button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Delete Basket',
                        style: MyntWebTextStyles.title(
                          context,
                          color: resolveThemeColor(context,
                              dark: styles.MyntColors.textPrimaryDark,
                              light: styles.MyntColors.textPrimary),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          child: Icon(
                            Icons.close,
                            size: 24,
                            color: resolveThemeColor(context,
                                dark: styles.MyntColors.textSecondaryDark,
                                light: styles.MyntColors.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Border separator
                Container(
                  height: 1,
                  color: resolveThemeColor(context,
                      dark: WebColors.dividerDark,
                      light: WebColors.divider),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Confirmation text
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: 'Are you sure you want to delete ',
                          style: MyntWebTextStyles.body(
                            context,
                            color: resolveThemeColor(context,
                                dark: styles.MyntColors.textPrimaryDark,
                                light: styles.MyntColors.textPrimary),
                          ),
                          children: [
                            TextSpan(
                              text: '"${bsktName.toUpperCase()}"',
                              style: MyntWebTextStyles.body(
                                context,
                                color: resolveThemeColor(context,
                                    dark: styles.MyntColors.textPrimaryDark,
                                    light: styles.MyntColors.textPrimary),
                              ),
                            ),
                            TextSpan(
                              text: '?',
                              style: MyntWebTextStyles.body(
                                context,
                                color: resolveThemeColor(context,
                                    dark: styles.MyntColors.textPrimaryDark,
                                    light: styles.MyntColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Red Delete button
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.tertiary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Delete',
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

    if (shouldDelete == true) {
      // Find index of basket
      final index = basketProvider.bsktList
          .indexWhere((element) => element['bsketName'].toString() == bsktName);
      if (index != -1) {
        await basketProvider.removeBasket(index);
        if (mounted) {
          _closeWindow();
        }
      }
    }
  }
}

// Isolated widget for Basket Instrument Cell with real-time LTP and hover actions
class _BasketInstrumentCell extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;
  final int originalIndex;
  final ThemesProvider theme;
  final String uniqueId;
  final ValueNotifier<String?> hoveredRowIndex;
  final Function(Map<String, dynamic>, int, ThemesProvider) onDelete;
  final Function(Map<String, dynamic>, int, ThemesProvider)? onCopy;
  final Function(Map<String, dynamic>, int, ThemesProvider)? onEdit;

  const _BasketInstrumentCell({
    required this.item,
    required this.originalIndex,
    required this.theme,
    required this.uniqueId,
    required this.hoveredRowIndex,
    required this.onDelete,
    this.onCopy,
    this.onEdit,
  });

  @override
  ConsumerState<_BasketInstrumentCell> createState() =>
      _BasketInstrumentCellState();
}

class _BasketInstrumentCellState extends ConsumerState<_BasketInstrumentCell> {
  late String ltp;
  late String pc;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _updateValues();

    final token = widget.item['token']?.toString();
    if (token != null) {
      _subscription =
          ref.read(websocketProvider).socketDataStream.listen((data) {
        if (!mounted || !data.containsKey(token)) return;

        bool changed = false;
        final newLtp = data[token]['lp']?.toString();
        if (newLtp != null && newLtp != ltp && newLtp != 'null') {
          ltp = newLtp;
          // Update model for sorting consistency
          widget.item['lp'] = newLtp;
          changed = true;
        }

        final newPc = data[token]['pc']?.toString();
        if (newPc != null && newPc != pc && newPc != 'null') {
          pc = newPc;
          // Update model for consistency
          widget.item['pc'] = newPc;
          changed = true;
        }

        if (changed) {
          setState(() {});
        }
      });
    }
  }

  @override
  void didUpdateWidget(_BasketInstrumentCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item != oldWidget.item) {
      _updateValues();
    }
  }

  void _updateValues() {
    ltp = widget.item['lp']?.toString() ?? '0.00';
    pc = widget.item['pc']?.toString() ?? '0.00%';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // Build action button with open orders table style (white bg, shadow)
  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
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
          icon,
          size: 16,
          color: iconColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tsym = widget.item['tsym']?.toString() ?? widget.item['symbol']?.toString() ?? '';
    // Prefer the backend display name (DerivativeMaster) for derivatives.
    final master = DerivativeMaster.nameFor(
        widget.item['exch']?.toString(), widget.item['token']?.toString());
    final displayText = master ?? tsym.replaceAll("-EQ", "").trim();
    final exch = widget.item['exch']?.toString() ?? '';

    return SizedBox.expand(
      child: ValueListenableBuilder<String?>(
        valueListenable: widget.hoveredRowIndex,
        builder: (context, hoveredId, _) {
          final isRowHovered = hoveredId == widget.uniqueId;

          return Stack(
            children: [
              // Instrument name and exchange
              Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: '$displayText${exch.isNotEmpty ? ' $exch' : ''}',
                  child: Padding(
                    padding: EdgeInsets.only(right: isRowHovered ? 100.0 : 0.0),
                    child: RichText(
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: displayText,
                            style: MyntWebTextStyles.tableCell(
                              context,
                              fontWeight: MyntFonts.semiBold,
                            ).copyWith(fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                          if (exch.isNotEmpty)
                            TextSpan(
                              text: ' $exch',
                              style: MyntWebTextStyles.para(
                                context,
                                darkColor: styles.MyntColors.textSecondaryDark,
                                lightColor: styles.MyntColors.textSecondary,
                                fontWeight: MyntFonts.medium,
                              ).copyWith(fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Hover actions - open orders table style
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
                        // Copy button
                        _buildActionButton(
                          icon: Icons.copy_outlined,
                          iconColor: resolveThemeColor(
                            context,
                            dark: styles.MyntColors.textPrimary,
                            light: styles.MyntColors.textSecondary,
                          ),
                          onPressed: widget.onCopy != null
                              ? () => widget.onCopy!(widget.item, widget.originalIndex, widget.theme)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        // Edit button
                        _buildActionButton(
                          icon: Icons.edit_outlined,
                          iconColor: resolveThemeColor(
                            context,
                            dark: styles.MyntColors.textPrimary,
                            light: styles.MyntColors.textSecondary,
                          ),
                          onPressed: widget.onEdit != null
                              ? () => widget.onEdit!(widget.item, widget.originalIndex, widget.theme)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        // Delete button
                        _buildActionButton(
                          icon: Icons.delete_outline,
                          iconColor: styles.MyntColors.loss,
                          onPressed: () => widget.onDelete(widget.item, widget.originalIndex, widget.theme),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BasketLtpCell extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;
  final ThemesProvider theme;

  const _BasketLtpCell({
    required this.item,
    required this.theme,
  });

  @override
  ConsumerState<_BasketLtpCell> createState() => _BasketLtpCellState();
}

class _BasketLtpCellState extends ConsumerState<_BasketLtpCell> {
  String ltp = "0.00";
  String pc = "0.00";
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _updateValues();
    _subscribeToWebSocket();
  }

  @override
  void didUpdateWidget(_BasketLtpCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item['token'] != oldWidget.item['token']) {
      _subscription?.cancel();
      _updateValues();
      _subscribeToWebSocket();
    }
  }

  void _subscribeToWebSocket() {
    final token = widget.item['token']?.toString();
    if (token != null) {
      _subscription =
          ref.read(websocketProvider).socketDataStream.listen((data) {
        if (!mounted || !data.containsKey(token)) return;

        bool changed = false;
        final newLtp = data[token]['lp']?.toString();
        if (newLtp != null && newLtp != ltp && newLtp != 'null') {
          ltp = newLtp;
          widget.item['lp'] = newLtp;
          changed = true;
        }

        final newPc = data[token]['pc']?.toString();
        if (newPc != null && newPc != pc && newPc != 'null') {
          pc = newPc;
          widget.item['pc'] = newPc;
          changed = true;
        }

        if (changed) {
          setState(() {});
        }
      });
    }
  }

  void _updateValues() {
    ltp = widget.item['lp']?.toString() ?? "0.00";
    pc = widget.item['pc']?.toString() ?? "0.00";
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "$ltp",
      child: Text(
        "$ltp",
        style: MyntWebTextStyles.tableCell(
          context,
          darkColor: styles.MyntColors.textPrimaryDark,
          lightColor: styles.MyntColors.textPrimary,
          fontWeight: MyntFonts.medium,
        ).copyWith(fontFeatures: [FontFeature.tabularFigures()]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}


/// Floating basket window (client ask): behaves like the place-order window —
/// no dimmed backdrop, page behind stays usable, draggable by the header,
/// stays open until closed. One basket window at a time.
class _BasketWindow {
  _BasketWindow._();

  static OverlayEntry? _entry;

  static void show(BuildContext context, String bsktName) {
    close();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => _DraggableBasketWindow(bsktName: bsktName, onClose: close),
    );
    _entry = entry;
    // Closed on logout / session expiry / account switch. Not via
    // OverlayManager.register — that would close the basket whenever an
    // order window opens from it.
    OverlayManager.registerSheetCloser(close);
    overlay.insert(entry);
  }

  static void close() {
    OverlayManager.unregisterSheetCloser(close);
    final entry = _entry;
    _entry = null;
    try {
      if (entry != null && entry.mounted) entry.remove();
    } catch (_) {}
  }
}

class _DraggableBasketWindow extends StatefulWidget {
  final String bsktName;
  final VoidCallback onClose;
  const _DraggableBasketWindow({required this.bsktName, required this.onClose});

  @override
  State<_DraggableBasketWindow> createState() => _DraggableBasketWindowState();
}

class _DraggableBasketWindowState extends State<_DraggableBasketWindow> {
  Offset? _position; // null = centred on first build
  double _maxX = 0;
  double _maxY = 0;
  bool _guardHeld = false;

  // Several pointer moves can land in one frame — accumulate every delta onto
  // the live position (using the last drawn position dropped most of them,
  // so the window lagged the mouse). Clamped so the window stays on screen.
  void _onDrag(Offset delta) {
    final next = (_position ?? Offset.zero) + delta;
    setState(() => _position = Offset(
          next.dx.clamp(0.0, _maxX),
          next.dy.clamp(0.0, _maxY),
        ));
  }

  // Chart iframes sit above Flutter and steal mouse events — same guard as
  // the place-order window. Does NOT touch the body cursor: resetting it on
  // every hover wiped out Flutter's move cursor on the header.
  void _setChartIframes(bool enabled) {
    try {
      for (final iframe in html.document.querySelectorAll('iframe')) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = enabled ? 'auto' : 'none';
        }
      }
    } catch (_) {}
  }

  void _onEnter() {
    if (!_guardHeld) {
      ChartIframeGuard.acquire();
      _guardHeld = true;
    }
    _setChartIframes(false);
  }

  void _onExit() {
    if (_guardHeld) {
      ChartIframeGuard.release();
      _guardHeld = false;
    }
    _setChartIframes(true);
  }

  @override
  void dispose() {
    if (_guardHeld) _onExit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final colorScheme = shadcn.Theme.of(context).colorScheme;
    // Same size as the old dialog's max constraints.
    final width = screen.width * 0.6;
    final height = screen.height * 0.8;
    _maxX = (screen.width - width).clamp(0.0, double.infinity);
    _maxY = (screen.height - height).clamp(0.0, double.infinity);
    _position ??= Offset(_maxX / 2, _maxY / 2);
    // Re-clamp on browser resize.
    final pos = Offset(
        _position!.dx.clamp(0.0, _maxX), _position!.dy.clamp(0.0, _maxY));

    return Stack(
      children: [
        Positioned(
          left: pos.dx,
          top: pos.dy,
          width: width,
          height: height,
          child: PointerInterceptor(
            child: MouseRegion(
              onEnter: (_) => _onEnter(),
              onExit: (_) => _onExit(),
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.popover,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colorScheme.border, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    // Own navigator so the window's popups (delete confirm,
                    // edit name) open inside it instead of under it.
                    child: Navigator(
                      onGenerateRoute: (_) => PageRouteBuilder(
                        transitionDuration: Duration.zero,
                        pageBuilder: (_, __, ___) => BasketScripList(
                          bsktName: widget.bsktName,
                          onClose: widget.onClose,
                          onDrag: _onDrag,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
