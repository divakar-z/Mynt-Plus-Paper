import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/accessibility_provider.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors, Tooltip;
import 'package:mynt_plus/models/order_book_model/sip_order_book.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/res/web_colors.dart' as web;
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/functions.dart';
import '../sip_order_detail_screen_web.dart';
import '../create_sip_dialog_web.dart';
import '../modify_sip_dialog_web.dart';

/// Separate screen widget for SIP Orders tab
class SipOrdersScreenWeb extends ConsumerStatefulWidget {
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;

  const SipOrdersScreenWeb({
    super.key,
    required this.horizontalScrollController,
    required this.verticalScrollController,
  });

  @override
  ConsumerState<SipOrdersScreenWeb> createState() => _SipOrdersScreenWebState();
}

class _SipOrdersScreenWebState extends ConsumerState<SipOrdersScreenWeb> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);
  bool _isProcessingCancel = false;
  String? _processingOrderId;

  late ScrollController _verticalScrollController;
  late ScrollController _horizontalScrollController;

  shadcn.PopoverController? _activePopoverController;
  int? _popoverRowIndex;
  bool _isHoveringDropdown = false;
  Timer? _popoverCloseTimer;
  bool _isSheetOpening = false;

  @override
  void initState() {
    super.initState();
    _verticalScrollController = ScrollController();
    _horizontalScrollController = ScrollController();
    _hoveredRowIndex.addListener(_onHoverChanged);
  }

  void _onHoverChanged() {
    if (_activePopoverController != null) {
      final currentHover = _hoveredRowIndex.value;
      if (currentHover == _popoverRowIndex) {
        _cancelPopoverCloseTimer();
        return;
      }
      if (_isHoveringDropdown) {
        _cancelPopoverCloseTimer();
        return;
      }
      _startPopoverCloseTimer();
    }
  }

  void _startPopoverCloseTimer() {
    _cancelPopoverCloseTimer();
    _popoverCloseTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_isHoveringDropdown && _hoveredRowIndex.value != _popoverRowIndex) {
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
    final needsRebuild = _activePopoverController != null || _popoverRowIndex != null;
    _activePopoverController = null;
    _popoverRowIndex = null;
    _isHoveringDropdown = false;
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

  TextStyle _getHeaderStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableHeader(
      context,
      color: color,
      darkColor: color ?? MyntColors.textSecondaryDark,
      lightColor: color ?? MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  String _getFrequencyText(String? frequency) {
    switch (frequency) {
      case '0':
        return 'Daily';
      case '1':
        return 'Weekly';
      case '2':
        return 'Fortnightly';
      case '3':
        return 'Monthly';
      default:
        return frequency ?? 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final orderBook = ref.watch(orderProvider);

    final searchQuery = orderBook.orderSipSearchCtrl.text.trim();
    final isSipOrdersTab = orderBook.selectedTab == 4; // SIP tab index
    final sipOrders = (searchQuery.isNotEmpty && isSipOrdersTab)
        ? (orderBook.siporderBookSearch ?? [])
        : (orderBook.siporderBookModel?.sipDetails ?? []);

    final sortedOrders = sipOrders.isNotEmpty
        ? _getSortedSipOrders(sipOrders)
        : <SipDetails>[];

    return Column(
      children: [
        // Header with Create SIP button
        _buildScreenHeader(context),
        // Table content
        Expanded(
          child: shadcn.OutlinedContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minWidths = _calculateMinWidths(sortedOrders, context);
          final availableWidth = constraints.maxWidth;

          // 6 columns: Name, Exchange, Frequency, Start Date, Due Date, Pending
          final columnWidths = <int, double>{};
          for (int i = 0; i < 6; i++) {
            columnWidths[i] = minWidths[i] ?? 100.0;
          }

          final totalMinWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);

          if (totalMinWidth < availableWidth) {
            final extraSpace = availableWidth - totalMinWidth;
            const nameGrowthFactor = 2.0;
            const textGrowthFactor = 1.2;
            const numericGrowthFactor = 1.0;

            final growthFactors = <int, double>{};
            double totalGrowthFactor = 0.0;

            for (int i = 0; i < 6; i++) {
              if (i == 0) {
                // Name
                growthFactors[i] = nameGrowthFactor;
                totalGrowthFactor += nameGrowthFactor;
              } else if (i == 1 || i == 2 || i == 3 || i == 4) {
                // Exchange, Frequency, Start Date, Due Date
                growthFactors[i] = textGrowthFactor;
                totalGrowthFactor += textGrowthFactor;
              } else {
                // Pending
                growthFactors[i] = numericGrowthFactor;
                totalGrowthFactor += numericGrowthFactor;
              }
            }

            if (totalGrowthFactor > 0) {
              for (int i = 0; i < 6; i++) {
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
                    3: shadcn.FixedTableSize(columnWidths[3]!),
                    4: shadcn.FixedTableSize(columnWidths[4]!),
                    5: shadcn.FixedTableSize(columnWidths[5]!),
                  },
                  defaultRowHeight: const shadcn.FixedTableSize(40),
                  rows: [
                    shadcn.TableHeader(
                      cells: [
                        buildHeaderCell('Name', 0),
                        buildHeaderCell('Exchange', 1),
                        buildHeaderCell('Frequency', 2),
                        buildHeaderCell('Start Date', 3),
                        buildHeaderCell('Due Date', 4),
                        buildHeaderCell('Pending', 5, true),
                      ],
                    ),
                  ],
                ),
                // Scrollable Body
                Expanded(
                  child: sortedOrders.isEmpty
                      ? (orderBook.loading
                          ? Center(child: MyntLoader.simple())
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: NoDataFoundWeb(
                                  title: searchQuery.isNotEmpty
                                      ? "No SIP Orders Found"
                                      : "No SIP Orders",
                                  subtitle: searchQuery.isNotEmpty
                                      ? "No SIP orders match your search \"$searchQuery\"."
                                      : "You don't have any SIP orders yet.",
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
                          child: SingleChildScrollView(
                            controller: _verticalScrollController,
                            scrollDirection: Axis.vertical,
                            child: shadcn.Table(
                              key: ValueKey(
                                  'sip_table_${_sortColumnIndex}_$_sortAscending'),
                              columnWidths: {
                                0: shadcn.FixedTableSize(columnWidths[0]!),
                                1: shadcn.FixedTableSize(columnWidths[1]!),
                                2: shadcn.FixedTableSize(columnWidths[2]!),
                                3: shadcn.FixedTableSize(columnWidths[3]!),
                                4: shadcn.FixedTableSize(columnWidths[4]!),
                                5: shadcn.FixedTableSize(columnWidths[5]!),
                              },
                              defaultRowHeight: const shadcn.FixedTableSize(40),
                              rows: sortedOrders.asMap().entries.map((entry) {
                                final index = entry.key;
                                final sipOrder = entry.value;

                                return shadcn.TableRow(
                                  cells: [
                                    // Name
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 0,
                                      onTap: () => _showSipOrderDetail(sipOrder),
                                      child: ValueListenableBuilder<int?>(
                                        valueListenable: _hoveredRowIndex,
                                        builder: (context, hoveredIndex, _) {
                                          final isRowHovered = hoveredIndex == index ||
                                              (_activePopoverController != null &&
                                                  _popoverRowIndex == index);
                                          return _buildNameCell(
                                              sipOrder, theme, isRowHovered,
                                              rowIndex: index);
                                        },
                                      ),
                                    ),
                                    // Exchange
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 1,
                                      onTap: () => _showSipOrderDetail(sipOrder),
                                      child: Builder(builder: (context) {
                                        final value = sipOrder.scrips?.isNotEmpty == true
                                            ? (sipOrder.scrips![0].exch ?? 'N/A')
                                            : 'N/A';
                                        return Tooltip(
                                          message: value,
                                          child: Text(value, style: _getTextStyle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        );
                                      }),
                                    ),
                                    // Frequency
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 2,
                                      onTap: () => _showSipOrderDetail(sipOrder),
                                      child: Builder(builder: (context) {
                                        final value = _getFrequencyText(sipOrder.frequency);
                                        return Tooltip(
                                          message: value,
                                          child: Text(value, style: _getTextStyle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        );
                                      }),
                                    ),
                                    // Start Date
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 3,
                                      onTap: () => _showSipOrderDetail(sipOrder),
                                      child: Builder(builder: (context) {
                                        final value = duedateformate(value: sipOrder.startDate ?? '');
                                        return Tooltip(
                                          message: value,
                                          child: Text(value, style: _getTextStyle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        );
                                      }),
                                    ),
                                    // Due Date
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 4,
                                      onTap: () => _showSipOrderDetail(sipOrder),
                                      child: Builder(builder: (context) {
                                        final value = duedateformate(value: sipOrder.internal?.dueDate ?? '');
                                        return Tooltip(
                                          message: value,
                                          child: Text(value, style: _getTextStyle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        );
                                      }),
                                    ),
                                    // Pending Period
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 5,
                                      alignRight: true,
                                      onTap: () => _showSipOrderDetail(sipOrder),
                                      child: Builder(builder: (context) {
                                        final value = sipOrder.endPeriod ?? 'N/A';
                                        return Tooltip(
                                          message: value,
                                          child: Text(value, style: _getTextStyle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        );
                                      }),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
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
    ),
        ),
      ],
    );
  }

  /// Builds the header row with Create SIP button (matches basket design)
  Widget _buildScreenHeader(BuildContext context) {
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
                    : web.WebColors.primary,
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
                  onTap: () => _openCreateSipDialog(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Text(
                      "Create SIP",
                      style: MyntWebTextStyles.buttonMd(
                        context,
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
      ],
    );
  }

  /// Opens the Create SIP dialog as a popup dialog
  void _openCreateSipDialog() {
    final theme = ref.read(themeProvider);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: theme.isDarkMode
              ? MyntColors.backgroundColorDark
              : MyntColors.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: const SizedBox(
            width: 580,
            height: 720,
            child: CreateSipDialogWeb(),
          ),
        );
      },
    );
  }

  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    VoidCallback? onTap,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 7;

    EdgeInsets cellPadding;
    if (isFirstColumn) {
      cellPadding = const EdgeInsets.fromLTRB(16, 4, 8, 4);
    } else if (isLastColumn) {
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

  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 7;

    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding = const EdgeInsets.fromLTRB(16, 6, 8, 6);
    } else if (isLastColumn) {
      headerPadding = const EdgeInsets.fromLTRB(8, 6, 16, 6);
    } else {
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

  Map<int, double> _calculateMinWidths(
      List<SipDetails> sipOrders, BuildContext context) {
    final textStyle = TextStyle(fontSize: 14, fontFamily: dyslexiaFontOr('Geist'));
    const padding = 24.0;
    const sortIconWidth = 24.0;

    final headers = [
      'Name',
      'Exchange',
      'Frequency',
      'Start Date',
      'Due Date',
      'Pending',
    ];
    final minWidths = <int, double>{};

    for (int col = 0; col < headers.length; col++) {
      double maxWidth = 0.0;
      final headerWidth = _measureTextWidth(headers[col], textStyle);
      maxWidth = headerWidth + sortIconWidth;

      for (final order in sipOrders.take(5)) {
        String cellText = '';
        switch (col) {
          case 0: // Name
            cellText = order.sipName ?? '';
            break;
          case 1: // Exchange
            cellText = order.scrips?.isNotEmpty == true
                ? (order.scrips![0].exch ?? '')
                : '';
            break;
          case 2: // Frequency
            cellText = _getFrequencyText(order.frequency);
            break;
          case 3: // Start Date
            cellText = duedateformate(value: order.startDate ?? '');
            break;
          case 4: // Due Date
            cellText = duedateformate(value: order.internal?.dueDate ?? '');
            break;
          case 5: // Pending
            cellText = order.endPeriod ?? '';
            break;
        }

        final cellWidth = _measureTextWidth(cellText, textStyle);
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }

      if (headers[col] == 'Name') {
        const minNameWidth = 150.0;
        const maxNameWidth = 200.0;
        maxWidth = maxWidth < minNameWidth ? minNameWidth : maxWidth;
        if (maxWidth > maxNameWidth) maxWidth = maxNameWidth;
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

  List<SipDetails> _getSortedSipOrders(List<SipDetails> orders) {
    if (_sortColumnIndex == null) return orders;

    final sorted = List<SipDetails>.from(orders);
    sorted.sort((a, b) {
      int comparison = 0;

      switch (_sortColumnIndex!) {
        case 0: // Name
          comparison = (a.sipName ?? '').compareTo(b.sipName ?? '');
          break;
        case 1: // Exchange
          final aExch = a.scrips?.isNotEmpty == true ? (a.scrips![0].exch ?? '') : '';
          final bExch = b.scrips?.isNotEmpty == true ? (b.scrips![0].exch ?? '') : '';
          comparison = aExch.compareTo(bExch);
          break;
        case 2: // LTP
          final aLtp = double.tryParse(
                  a.scrips?.isNotEmpty == true ? (a.scrips![0].ltp ?? '0') : '0') ??
              0.0;
          final bLtp = double.tryParse(
                  b.scrips?.isNotEmpty == true ? (b.scrips![0].ltp ?? '0') : '0') ??
              0.0;
          comparison = aLtp.compareTo(bLtp);
          break;
        case 3: // Change %
          final aChange = double.tryParse(a.scrips?.isNotEmpty == true
                      ? (a.scrips![0].perChange ?? '0')
                      : '0') ??
              0.0;
          final bChange = double.tryParse(b.scrips?.isNotEmpty == true
                      ? (b.scrips![0].perChange ?? '0')
                      : '0') ??
              0.0;
          comparison = aChange.compareTo(bChange);
          break;
        case 4: // Frequency
          comparison = (a.frequency ?? '').compareTo(b.frequency ?? '');
          break;
        case 5: // Start Date
          comparison = (a.startDate ?? '').compareTo(b.startDate ?? '');
          break;
        case 6: // Due Date
          comparison = (a.internal?.dueDate ?? '')
              .compareTo(b.internal?.dueDate ?? '');
          break;
        case 7: // Pending
          final aPending = int.tryParse(a.endPeriod ?? '0') ?? 0;
          final bPending = int.tryParse(b.endPeriod ?? '0') ?? 0;
          comparison = aPending.compareTo(bPending);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  Widget _buildNameCell(
      SipDetails sipOrder, ThemesProvider theme, bool isRowHovered,
      {int? rowIndex}) {
    final sipId = sipOrder.internal?.sipId ?? '';
    final displayText = sipOrder.sipName ?? 'N/A';

    return GestureDetector(
      onTap: () => _showSipOrderDetail(sipOrder),
      behavior: HitTestBehavior.deferToChild,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: displayText,
                child: Padding(
                  padding: EdgeInsets.only(right: isRowHovered ? 106.0 : 0.0),
                  child: Text(
                    displayText,
                    style: _getTextStyle(context),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
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
                      _buildModifyButton(sipOrder, sipId),
                      const SizedBox(width: 6),
                      _buildCancelButton(sipOrder, sipId),
                      const SizedBox(width: 6),
                      _buildOptionsMenuButton(sipOrder, sipId, rowIndex: rowIndex),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModifyButton(SipDetails sipOrder, String sipId) {
    return GestureDetector(
      onTap: () => _handleModifySipOrder(sipOrder),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: MyntColors.textWhite, light: MyntColors.textWhite),
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
          Icons.edit_outlined,
          size: 16,
          color: resolveThemeColor(context,
              dark: MyntColors.primaryDark, light: MyntColors.primary),
        ),
      ),
    );
  }

  Future<void> _handleModifySipOrder(SipDetails sipOrder) async {
    final theme = ref.read(themeProvider);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: theme.isDarkMode
              ? MyntColors.backgroundColorDark
              : MyntColors.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            width: 580,
            height: 720,
            child: ModifySipDialogWeb(sipDetails: sipOrder),
          ),
        );
      },
    );
  }

  Widget _buildCancelButton(SipDetails sipOrder, String sipId) {
    final isProcessing = _processingOrderId == sipId && _isProcessingCancel;

    return GestureDetector(
      onTap: isProcessing
          ? null
          : () async {
              setState(() {
                _processingOrderId = sipId;
                _isProcessingCancel = true;
              });
              await _handleCancelSipOrder(sipOrder);
              if (mounted) {
                setState(() {
                  _isProcessingCancel = false;
                  _processingOrderId = null;
                });
              }
            },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: MyntColors.textWhite, light: MyntColors.textWhite),
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
          Icons.close,
          size: 16,
          color: resolveThemeColor(context,
              dark: MyntColors.lossDark, light: MyntColors.loss),
        ),
      ),
    );
  }

  Widget _buildOptionsMenuButton(SipDetails sipOrder, String sipId,
      {int? rowIndex}) {
    final iconColor = resolveThemeColor(context,
        dark: MyntColors.iconDark, light: MyntColors.icon);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          onTap: () {
            List<shadcn.MenuItem> menuItems = [];

            menuItems.add(
              shadcn.MenuButton(
                onPressed: (ctx) {
                  _closePopover();
                  _showSipOrderDetail(sipOrder);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: iconColor),
                      const SizedBox(width: 10),
                      Text(
                        'Info',
                        style: MyntWebTextStyles.body(
                          context,
                          fontWeight: MyntFonts.medium,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            final controller = shadcn.PopoverController();
            _activePopoverController = controller;
            _popoverRowIndex = rowIndex;

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
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.textWhite, light: MyntColors.textWhite),
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

  void _showSipOrderDetail(SipDetails sipOrder) {
    if (_isSheetOpening) return;
    _isSheetOpening = true;

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
          child: SipOrderDetailScreenWeb(
            sipOrder: sipOrder,
            parentContext: context,
          ),
        );
      },
      position: shadcn.OverlayPosition.end,
      barrierColor: Colors.transparent,
    ).then((_) {
      _isSheetOpening = false;
    });
  }

  Future<void> _handleCancelSipOrder(SipDetails sipOrder) async {
    final shouldCancel = await _showCancelSipOrderDialog(sipOrder);

    if (shouldCancel != true) return;

    try {
      await ref
          .read(orderProvider)
          .fetchSipOrderCancel(sipOrder.internal?.sipId ?? '', context);
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
            context, 'Failed to cancel SIP order: ${e.toString()}');
      }
    }
  }

  Future<bool?> _showCancelSipOrderDialog(SipDetails sipOrder) async {
    final symbol = sipOrder.sipName ?? 'N/A';

    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.backgroundColorDark, light: colors.colorWhite),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                        'Cancel SIP Order',
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
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
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
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: resolveThemeColor(context,
                                dark: MyntColors.errorDark,
                                light: MyntColors.tertiary),
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
}
