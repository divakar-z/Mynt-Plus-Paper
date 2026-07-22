import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/screens/web/ordersbook/mf/redeem_bottom_sheet_web.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../provider/mf_provider.dart';
import '../../../provider/privacy_provider.dart';
import '../../../provider/thems.dart';
import '../../../res/res.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import 'mf_hold_singlepage_web.dart';

class MfHoldNewScreenWeb extends ConsumerStatefulWidget {
  const MfHoldNewScreenWeb({super.key});

  @override
  ConsumerState<MfHoldNewScreenWeb> createState() => _MfHoldNewScreenState();
}

class _MfHoldNewScreenState extends ConsumerState<MfHoldNewScreenWeb> {
  // int? _hoveredRowIndex; // Commented out in original, now enabling it
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Popover state management for 3-dot dropdown menu
  shadcn.PopoverController? _activePopoverController;
  int? _popoverRowIndex;
  bool _isHoveringDropdown = false;
  Timer? _popoverCloseTimer;

  // Scroll controllers
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-load data when screen opens (demat endpoint — the old MF holdings
    // API is being decommissioned; the provider adapts the response into the
    // mfholdingnew shape this screen reads)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ref.read(mfProvider).fetchmfholdingnew();
      ref.read(mfProvider).fetchmfdematholding();
    });
    // Listen to hover changes for popover management
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
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _hoveredRowIndex.dispose();
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

  // Helper method to get theme-aware colors for positive/negative/neutral values
  Color _getCellColor(
      double value, BuildContext context, ThemesProvider theme) {
    if (value > 0) {
      return theme.isDarkMode ? MyntColors.profitDark : MyntColors.profit;
    }
    if (value < 0) {
      return theme.isDarkMode ? MyntColors.lossDark : MyntColors.loss;
    }
    return theme.isDarkMode
        ? MyntColors.textSecondaryDark
        : MyntColors.textSecondary;
  }

  // Helper method to build colored text for P&L values with percentage (stacked)
  Widget _buildPnLWithPercentage(
      String pnlValue, String percentValue, ThemesProvider theme) {
    // Privacy Mode: P&L and its percent are masked, colour neutralized.
    final privacy = ref.watch(privacyProvider);
    final numValue =
        privacy.isPrivate ? 0.0 : (double.tryParse(pnlValue) ?? 0.0);
    final color = _getCellColor(numValue, context, theme);
    final baseStyle = _getTextStyle(context, color: color);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(privacy.mask(pnlValue), textAlign: TextAlign.end, style: baseStyle),
        Text(
          privacy.mask(percentValue, suffix: '%'),
          textAlign: TextAlign.end,
          style: baseStyle.copyWith(
            fontSize: 10,
            color: theme.isDarkMode
                ? MyntColors.textPrimaryDark
                : MyntColors.textPrimary,
            fontWeight: MyntFonts.medium,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final mfData = ref.watch(mfProvider);
    final showSearch = mfData.showMfHoldingSearch;
    final searchText = mfData.mfHoldingSearchController.text;

    // Get the appropriate list based on search state
    final items = showSearch && searchText.isNotEmpty
        ? (mfData.mfHoldingSearchItems ?? [])
        : (mfData.mfholdingnew?.data ?? []);

    // Check if user has any holdings data at all (kept for reference or remove if strictly unused, but for now just fix the compilation error)
    // final hasHoldingsData = mfData.mfholdingnew?.data != null && mfData.mfholdingnew!.data!.isNotEmpty;

    return Scaffold(
      // backgroundColor: theme.isDarkMode
      //     ? const Color(0xFF121212)
      //     : const Color(0xFFF5F5F5),
      body: MyntLoaderOverlay(
        isLoading: mfData.holdstatload ?? false,
        child: RefreshIndicator(
          onRefresh: () async {
            // await mfData.fetchmfholdingnew();
            await mfData.fetchmfdematholding();
          },
          child: Column(
            children: [
              // Summary Cards - Horizontal row of 3 cards
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Invested Card
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        "Invested",
                        _formatValue(mfData.mfholdingnew?.summary?.invested),
                        theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Current Value Card
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        "Current Value",
                        mfData.mfholdingnew?.summary?.currentValue ?? "0.00",
                        theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Profit/Loss Card
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        "Profit/Loss",
                        _formatValue(
                            mfData.mfholdingnew?.summary?.absReturnValue),
                        theme,
                        valueColor: _getColorBasedOnValue(
                          mfData.mfholdingnew?.summary?.absReturnValue,
                          theme,
                        ),
                        percentage: _formatValue(mfData
                            .mfholdingnew?.summary?.absReturnPercent
                            ?.toString()),
                      ),
                    ),
                  ],
                ),
              ),

              // Table
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTableContent(context, theme, mfData, items),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build summary card widget
  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    ThemesProvider theme, {
    Color? valueColor,
    String? percentage,
  }) {
    // Privacy Mode: hide the amount and its profit/loss colour; the (%)
    // shell stays so the layout doesn't shift.
    final privacy = ref.watch(privacyProvider);
    if (privacy.isPrivate) {
      value = kPrivacyMask;
      percentage = percentage == null ? null : kPrivacyMask;
      valueColor = null;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // color: theme.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        color: theme.isDarkMode ? MyntColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              theme.isDarkMode ? MyntColors.transparent : MyntColors.divider,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: theme.isDarkMode
                  ? MyntColors.textPrimaryDark
                  : MyntColors.textPrimary,
              fontWeight: MyntFonts.medium,
            ),
          ),
          const SizedBox(height: 1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: MyntWebTextStyles.head(
                    context,
                    color: valueColor,
                    fontWeight: MyntFonts.medium,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (percentage != null) ...[
                const SizedBox(width: 6),
                Text(
                  '($percentage%)',
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    color: valueColor,
                    fontWeight: MyntFonts.medium,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Build table content using shadcn table
  Widget _buildTableContent(
    BuildContext context,
    ThemesProvider theme,
    MFProvider mfData,
    List items,
  ) {
    // Sort items if sort is active
    final sortedItems =
        _sortColumnIndex != null ? _getSortedItems(items) : items;

    return shadcn.OutlinedContainer(
      backgroundColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate minimum widths dynamically based on actual content
          final minWidths = _calculateMinWidths(sortedItems, context);

          // Available width
          final availableWidth = constraints.maxWidth;

          // Step 1: Start with minimum widths
          final columnWidths = <int, double>{};
          for (int i = 0; i < 7; i++) {
            columnWidths[i] = minWidths[i] ?? 100.0;
          }

          // Step 2: Calculate total minimum width needed
          final totalMinWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);

          // Step 3: If there's extra space, distribute it proportionally
          if (totalMinWidth < availableWidth) {
            final extraSpace = availableWidth - totalMinWidth;

            // Define growth factors
            const instrumentGrowthFactor = 2.0;
            const numericGrowthFactor = 1.0;

            final growthFactors = <int, double>{};
            double totalGrowthFactor = 0.0;

            for (int i = 0; i < 7; i++) {
              if (i == 0) {
                // Fund Name column
                growthFactors[i] = instrumentGrowthFactor;
                totalGrowthFactor += instrumentGrowthFactor;
              } else {
                // Numeric columns
                growthFactors[i] = numericGrowthFactor;
                totalGrowthFactor += numericGrowthFactor;
              }
            }

            // Distribute extra space proportionally
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

          // Calculate total required width
          final totalRequiredWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);

          // If total width exceeds available width, enable horizontal scrolling
          final needsHorizontalScroll = totalRequiredWidth > availableWidth;

          // Build table content
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
                  },
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  rows: [
                    shadcn.TableHeader(
                      cells: [
                        buildHeaderCell('Fund Name', 0),
                        buildHeaderCell('Units', 1, true),
                        buildHeaderCell('Avg NAV', 2, true),
                        buildHeaderCell('Current NAV', 3, true),
                        buildHeaderCell('Invested', 4, true),
                        buildHeaderCell('Current Value', 5, true),
                        buildHeaderCell('P&L', 6, true),
                      ],
                    ),
                  ],
                ),

                // Scrollable Body (List of Rows with Hover Overlay)
                Expanded(
                  child: sortedItems.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: NoDataFound(
                                  title: (mfData.mfholdingnew?.data != null &&
                                          mfData.mfholdingnew!.data!.isNotEmpty)
                                      ? "No results found"
                                      : "There's nothing here yet.",
                                  subtitle: (mfData.mfholdingnew?.data !=
                                              null &&
                                          mfData.mfholdingnew!.data!.isNotEmpty)
                                      ? "Try adjusting your search"
                                      : "Buy some funds to see them here.",
                                  primaryEnabled: false,
                                  secondaryEnabled: false,
                                ),
                              ),
                            ),
                          ),
                        )
                      : RawScrollbar(
                          controller: _verticalScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          trackColor: Colors.grey.withValues(alpha: 0.1),
                          thumbColor: Colors.grey.withValues(alpha: 0.3),
                          thickness: 6,
                          radius: const Radius.circular(3),
                          interactive: true,
                          child: ListView.builder(
                            controller: _verticalScrollController,
                            itemCount: sortedItems.length,
                            itemBuilder: (context, index) {
                              final item = sortedItems[index];
                              return MouseRegion(
                                onEnter: (_) => _hoveredRowIndex.value = index,
                                onExit: (_) => _hoveredRowIndex.value = null,
                                child: ValueListenableBuilder<int?>(
                                  valueListenable: _hoveredRowIndex,
                                  builder: (context, hoveredIndex, child) {
                                    final isHovered = hoveredIndex == index || _popoverRowIndex == index;
                                    return Container(
                                      color: isHovered
                                          ? resolveThemeColor(context,
                                              dark: MyntColors.primaryDark,
                                              light: MyntColors.primary,
                                            ).withValues(alpha: 0.08)
                                          : Colors.transparent,
                                      child: shadcn.Table(
                                        key: ValueKey('table_row_$index'),
                                        columnWidths: {
                                          0: shadcn.FixedTableSize(
                                              columnWidths[0]!),
                                          1: shadcn.FixedTableSize(
                                              columnWidths[1]!),
                                          2: shadcn.FixedTableSize(
                                              columnWidths[2]!),
                                          3: shadcn.FixedTableSize(
                                              columnWidths[3]!),
                                          4: shadcn.FixedTableSize(
                                              columnWidths[4]!),
                                          5: shadcn.FixedTableSize(
                                              columnWidths[5]!),
                                          6: shadcn.FixedTableSize(
                                              columnWidths[6]!),
                                        },
                                        defaultRowHeight:
                                            const shadcn.FixedTableSize(50),
                                        rows: [
                                          shadcn.TableRow(
                                            cells: [
                                              // Instrument with action button on hover
                                              buildCellWithHover(
                                                rowIndex: index,
                                                columnIndex: 0,
                                                child: ValueListenableBuilder<
                                                    int?>(
                                                  valueListenable:
                                                      _hoveredRowIndex,
                                                  builder: (context,
                                                      hoveredIndex, _) {
                                                    final isRowHovered =
                                                        hoveredIndex == index;
                                                    final avgQty =
                                                        double.tryParse(
                                                                item.avgQty ??
                                                                    '0') ??
                                                            0.0;

                                                    return GestureDetector(
                                                      onTap: () =>
                                                          _showHoldingDetail(
                                                              mfData, item),
                                                      behavior: HitTestBehavior
                                                          .opaque,
                                                      child: Row(
                                                        children: [
                                                          // Fund name - uses Expanded to properly truncate
                                                          Expanded(
                                                            child: Tooltip(
                                                              message: item.name ??
                                                                  'Unknown Fund',
                                                              child: Text(
                                                                item.name ??
                                                                    "Unknown Fund",
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                maxLines: 1,
                                                                softWrap: false,
                                                                style:
                                                                    _getTextStyle(
                                                                        context),
                                                              ),
                                                            ),
                                                          ),
                                                          // 3-dot dropdown menu - inline on the right
                                                          if (isRowHovered ||
                                                              _popoverRowIndex ==
                                                                  index) ...[
                                                            const SizedBox(
                                                                width: 8),
                                                            _buildOptionsMenuButton(
                                                              item: item,
                                                              rowIndex: index,
                                                              mfData: mfData,
                                                              hasUnits:
                                                                  avgQty > 0,
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              // Qty
                                              buildCellWithHover(
                                                rowIndex: index,
                                                columnIndex: 1,
                                                alignRight: true,
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _showHoldingDetail(
                                                          mfData, item),
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: Text(
                                                      ref
                                                          .watch(
                                                              privacyProvider)
                                                          .mask((double.tryParse(
                                                                      item.avgQty ??
                                                                          '0') ??
                                                                  0.0)
                                                              .toStringAsFixed(
                                                                  4)),
                                                      style: _getTextStyle(
                                                          context),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Avg NAV
                                              buildCellWithHover(
                                                rowIndex: index,
                                                columnIndex: 2,
                                                alignRight: true,
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _showHoldingDetail(
                                                          mfData, item),
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: Text(
                                                      ref
                                                          .watch(
                                                              privacyProvider)
                                                          .mask((double.tryParse(
                                                                      item.avgNav ??
                                                                          '0') ??
                                                                  0.0)
                                                              .toStringAsFixed(
                                                                  4)),
                                                      style: _getTextStyle(
                                                          context),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // NAV
                                              buildCellWithHover(
                                                rowIndex: index,
                                                columnIndex: 3,
                                                alignRight: true,
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _showHoldingDetail(
                                                          mfData, item),
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: Text(
                                                      (double.tryParse(
                                                                  item.curNav ??
                                                                      '0') ??
                                                              0.0)
                                                          .toStringAsFixed(4),
                                                      style: _getTextStyle(
                                                          context),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Invested
                                              buildCellWithHover(
                                                rowIndex: index,
                                                columnIndex: 4,
                                                alignRight: true,
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _showHoldingDetail(
                                                          mfData, item),
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: Text(
                                                      ref
                                                          .watch(
                                                              privacyProvider)
                                                          .mask((double.tryParse(
                                                                      item.investedValue ??
                                                                          '0') ??
                                                                  0.0)
                                                              .toStringAsFixed(
                                                                  2)),
                                                      style: _getTextStyle(
                                                          context),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Current Value
                                              buildCellWithHover(
                                                rowIndex: index,
                                                columnIndex: 5,
                                                alignRight: true,
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _showHoldingDetail(
                                                          mfData, item),
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: Text(
                                                      ref
                                                          .watch(
                                                              privacyProvider)
                                                          .mask((double.tryParse(
                                                                      item.currentValue ??
                                                                          '0') ??
                                                                  0.0)
                                                              .toStringAsFixed(
                                                                  2)),
                                                      style: _getTextStyle(
                                                          context),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // P&L with percentage
                                              buildCellWithHover(
                                                rowIndex: index,
                                                columnIndex: 6,
                                                alignRight: true,
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _showHoldingDetail(
                                                          mfData, item),
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: _buildPnLWithPercentage(
                                                      (double.tryParse(
                                                                  item.profitLoss ??
                                                                      '0') ??
                                                              0.0)
                                                          .toStringAsFixed(2),
                                                      (double.tryParse(
                                                                  item.changeprofitLoss
                                                                      ?.toString() ??
                                                                      '0') ??
                                                              0.0)
                                                          .toStringAsFixed(2),
                                                      theme,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          }

          // Horizontal scroll wrapper (if needed)
          if (needsHorizontalScroll) {
            return RawScrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              trackColor: Colors.grey.withValues(alpha: 0.1),
              thumbColor: Colors.grey.withValues(alpha: 0.3),
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
    );
  }

  // Build cell with hover
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    VoidCallback? onTap,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 6;

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
      child: ValueListenableBuilder<int?>(
        valueListenable: _hoveredRowIndex,
        builder: (context, hoveredIndex, _) {
          // Also highlight when popover is open for this row
          final isRowHovered = hoveredIndex == rowIndex || _popoverRowIndex == rowIndex;
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
                  ? resolveThemeColor(context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary,
                    ).withValues(alpha: 0.08)
                  : null,
              child: child,
            ),
          );
        },
      ),
    );
  }

  // Build header cell
  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 6;

    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding = const EdgeInsets.fromLTRB(16, 6, 8, 6);
    } else if (isLastColumn) {
      headerPadding = const EdgeInsets.fromLTRB(8, 6, 16, 6);
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
                  color: MyntColors.textSecondaryDark,
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
                  color: MyntColors.textSecondaryDark,
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

  // Calculate minimum column widths
  Map<int, double> _calculateMinWidths(List items, BuildContext context) {
    final textStyle = const TextStyle(fontSize: 14);
    const padding = 24.0;
    const sortIconWidth = 24.0;

    final headers = [
      'Fund Name',
      'Units',
      'Avg NAV',
      'Current NAV',
      'Invested',
      'Current Value',
      'P&L',
    ];

    final minWidths = <int, double>{};

    for (int col = 0; col < headers.length; col++) {
      double maxWidth =
          _measureTextWidth(headers[col], textStyle) + sortIconWidth;

      for (final item in items.take(5)) {
        String cellText = '';
        switch (col) {
          case 0:
            cellText = item.name ?? 'N/A';
            break;
          case 1:
            cellText =
                (double.tryParse(item.avgQty ?? '0') ?? 0.0).toStringAsFixed(4);
            break;
          case 2:
            cellText =
                (double.tryParse(item.avgNav ?? '0') ?? 0.0).toStringAsFixed(4);
            break;
          case 3:
            cellText =
                (double.tryParse(item.curNav ?? '0') ?? 0.0).toStringAsFixed(4);
            break;
          case 4:
            cellText = (double.tryParse(item.investedValue ?? '0') ?? 0.0)
                .toStringAsFixed(2);
            break;
          case 5:
            cellText = (double.tryParse(item.currentValue ?? '0') ?? 0.0)
                .toStringAsFixed(2);
            break;
          case 6:
            // P&L (with percentage - measure longest)
            final pnl = (double.tryParse(item.profitLoss ?? '0') ?? 0.0)
                .toStringAsFixed(2);
            final pct = (double.tryParse(item.changeprofitLoss?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
            final pnlWidth = _measureTextWidth(pnl, textStyle);
            final pctWidth =
                _measureTextWidth('$pct%', textStyle.copyWith(fontSize: 10));
            cellText = pnlWidth > pctWidth ? pnl : '$pct%';
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

  List _getSortedItems(List items) {
    if (_sortColumnIndex == null) return items;

    final sorted = List.from(items);
    sorted.sort((a, b) {
      int comparison = 0;

      switch (_sortColumnIndex!) {
        case 0: // Fund Name
          comparison = (a.name ?? '').compareTo(b.name ?? '');
          break;
        case 1: // Units
          comparison = (double.tryParse(a.avgQty ?? '0') ?? 0.0)
              .compareTo(double.tryParse(b.avgQty ?? '0') ?? 0.0);
          break;
        case 2: // Avg NAV
          comparison = (double.tryParse(a.avgNav ?? '0') ?? 0.0)
              .compareTo(double.tryParse(b.avgNav ?? '0') ?? 0.0);
          break;
        case 3: // Current NAV
          comparison = (double.tryParse(a.curNav ?? '0') ?? 0.0)
              .compareTo(double.tryParse(b.curNav ?? '0') ?? 0.0);
          break;
        case 4: // Invested
          comparison = (double.tryParse(a.investedValue ?? '0') ?? 0.0)
              .compareTo(double.tryParse(b.investedValue ?? '0') ?? 0.0);
          break;
        case 5: // Current Value
          comparison = (double.tryParse(a.currentValue ?? '0') ?? 0.0)
              .compareTo(double.tryParse(b.currentValue ?? '0') ?? 0.0);
          break;
        case 6: // P&L (sorts by P&L value, not percentage)
          comparison = (double.tryParse(a.profitLoss ?? '0') ?? 0.0)
              .compareTo(double.tryParse(b.profitLoss ?? '0') ?? 0.0);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  // Build 3-dot options menu button with dropdown
  Widget _buildOptionsMenuButton({
    required dynamic item,
    required int rowIndex,
    required MFProvider mfData,
    required bool hasUnits,
  }) {
    final theme = ref.watch(themeProvider);

    return Builder(
      builder: (buttonContext) {
        return MouseRegion(
          onEnter: (_) {
            _isHoveringDropdown = true;
            _cancelPopoverCloseTimer();
          },
          onExit: (_) {
            _isHoveringDropdown = false;
            _startPopoverCloseTimer();
          },
          child: GestureDetector(
            onTap: () {
              // Close any existing popover first
              if (_activePopoverController != null) {
                _closePopover();
              }

              // Create new controller and show popover
              final controller = shadcn.PopoverController();
              _activePopoverController = controller;
              _popoverRowIndex = rowIndex;

              // Build menu items
              final List<shadcn.MenuItem> menuItems = [
                if (hasUnits)
                  _buildMenuButton(
                    icon: Icons.money_off_outlined,
                    label: 'Redeem',
                    onPressed: () {
                      _closePopover();
                      _handleRedeem(mfData, item);
                    },
                    theme: theme,
                  ),
                _buildMenuButton(
                  icon: Icons.info_outline,
                  label: 'Details',
                  onPressed: () {
                    _closePopover();
                    _showHoldingDetail(mfData, item);
                  },
                  theme: theme,
                ),
              ];

              controller.show(
                context: buttonContext,
                builder: (popoverContext) {
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

              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MyntColors.textWhite,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode(  context)
                        ? Colors.transparent
                        : Colors.grey,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.more_vert,
                size: 18,
                color: theme.isDarkMode
                    ? MyntColors.textPrimary
                    : MyntColors.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }

  // Build individual menu button
  shadcn.MenuItem _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ThemesProvider theme,
  }) {
    return shadcn.MenuButton(
      leading: Icon(
        icon,
        size: 20,
        color: theme.isDarkMode
            ? MyntColors.textPrimaryDark
            : MyntColors.textPrimary,
      ),
      onPressed: (context) => onPressed(),
      child: SizedBox(
        width: 120,
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: theme.isDarkMode
                  ? MyntColors.textPrimaryDark
                  : MyntColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // Handler: Redeem mutual fund
  Future<void> _handleRedeem(MFProvider mfData, dynamic holding) async {
    // Set the holding data for redemption using the ISIN
    mfData.fetchmfholdsingpage(holding.iSIN ?? '');
    // Call the redeem evaluation function
    mfData.recdemevalu();
    // Show mobile redeem dialog
    showDialog(
      context: context,
      builder: (context) => RedemptionBottomSheetWeb(
        // holdingData: holding,
        // theme: ref.read(themeProvider),
      ),
    );
  }

  void _showHoldingDetail(MFProvider mfData, dynamic item) {
    if (item.iSIN != null) {
      mfData.fetchmfholdsingpage("${item.iSIN}");

      // Show as right side panel
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(dialogContext).size.width * 0.25,
                height: MediaQuery.of(dialogContext).size.height,
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(-2, 0),
                    ),
                  ],
                ),
                child: const mfholdsinlepageWeb(),
              ),
            ),
          );
        },
        transitionBuilder:
            (dialogContext, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      );
    }
  }

  String _formatValue(String? value) {
    return (value == null || value.isEmpty) ? "0.00" : value;
  }

  Color _getColorBasedOnValue(String? valueStr, ThemesProvider theme) {
    final value = double.tryParse(valueStr ?? "0") ?? 0;
    return value >= 0
        ? theme.isDarkMode
            ? colors.profitDark
            : colors.profitLight
        : theme.isDarkMode
            ? colors.lossDark
            : colors.lossLight;
  }
}
