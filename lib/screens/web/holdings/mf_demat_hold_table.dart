import 'package:flutter/material.dart'
    show
        InkWell,
        Icons,
        Icon,
        TextPainter,
        TextSpan,
        TextStyle,
        TextDirection,
        MouseRegion,
        Row,
        SizedBox,
        Text,
        Align,
        TextOverflow,
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
        ScrollController,
        Expanded,
        Column,
        WidgetsBinding,
        Tooltip,
        ValueNotifier,
        ValueListenableBuilder,
        RawScrollbar,
        Radius,
        Builder;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../provider/mf_provider.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/mynt_loader.dart';

/// Read-only holdings table for the "Mutual Fund Beta" tab.
///
/// Visually mirrors [MfTableExample] (same 8 columns, sortable headers, hover
/// highlight, scrollbars, tooltips, P&L coloring) but is backed by the demat
/// holdings model ([MfDematHolding]). Row-tap detail and the Redeem/Add menu
/// are intentionally omitted: the demat endpoint doesn't carry the scheme code /
/// minimum purchase amount / transactions those flows require.
class MfDematTableExample extends ConsumerStatefulWidget {
  final String? searchQuery;

  const MfDematTableExample({super.key, this.searchQuery});

  @override
  ConsumerState<MfDematTableExample> createState() =>
      _MfDematTableExampleState();
}

class _MfDematTableExampleState extends ConsumerState<MfDematTableExample> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    // Fetch beta (demat) holdings when the table first mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mfProvider).fetchmfdematholding();
    });
  }

  @override
  void dispose() {
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

  // Builds a cell with hover highlight covering the entire cell including padding
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
  }) {
    final isFirstColumn = columnIndex == 0; // Fund Name column
    final isLastColumn = columnIndex == 7; // Chg column

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
        onEnter: (_) => _hoveredRowIndex.value = rowIndex,
        onExit: (_) => _hoveredRowIndex.value = null,
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredRowIndex,
          child: child,
          builder: (context, hoveredIndex, cachedChild) {
            final isRowHovered = hoveredIndex == rowIndex;
            return Container(
              padding: cellPadding,
              color: isRowHovered
                  ? resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary)
                      .withValues(alpha: 0.08)
                  : null,
              alignment: alignRight ? Alignment.topRight : null,
              child: cachedChild,
            );
          },
        ),
      ),
    );
  }

  // Builds a sortable header cell with sort indicator
  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0; // Fund Name column
    final isLastColumn = columnIndex == 7; // Chg column

    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding = const EdgeInsets.fromLTRB(16, 6, 4, 6);
    } else if (isLastColumn) {
      headerPadding = const EdgeInsets.fromLTRB(4, 6, 16, 6);
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
    const sortIconWidth = 24.0;

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

    for (int col = 0; col < headers.length; col++) {
      double maxWidth = 0.0;

      final headerWidth = _measureTextWidth(headers[col], textStyle);
      maxWidth = headerWidth + sortIconWidth;

      for (final holding in holdings) {
        String cellText = '';

        switch (col) {
          case 0: // Fund Name
            cellText = holding.scripName ?? 'N/A';
            break;
          case 1: // Units
            final units = double.tryParse(holding.totalUnits ?? '0') ?? 0.0;
            cellText = units.toStringAsFixed(4);
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
            final pct =
                double.tryParse(holding.changeprofitLoss ?? '0') ?? 0.0;
            cellText = '${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(2)}%';
            break;
        }

        final cellWidth = _measureTextWidth(cellText, textStyle);
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }

      if (headers[col] == 'Fund Name') {
        const minFundNameWidth = 150.0;
        maxWidth = maxWidth < minFundNameWidth ? minFundNameWidth : maxWidth;
      }

      minWidths[col] = maxWidth + padding;
    }

    return minWidths;
  }

  @override
  Widget build(BuildContext context) {
    final mfData = ref.watch(mfProvider);

    // Show loading indicator while fetching data
    if (mfData.dematHoldLoad) {
      return Center(child: MyntLoader.simple());
    }

    final holdings = mfData.mfDematHolding?.data ?? [];

    // Apply search filter if search query is provided
    var filteredHoldings = holdings;
    final searchQuery = widget.searchQuery?.toLowerCase().trim() ?? '';
    if (searchQuery.isNotEmpty) {
      filteredHoldings = holdings.where((holding) {
        final name = holding.scripName?.toLowerCase() ?? '';
        return name.contains(searchQuery);
      }).toList();
    }

    // Sort holdings based on selected column
    if (_sortColumnIndex != null) {
      filteredHoldings.sort((a, b) {
        int comparison = 0;
        switch (_sortColumnIndex) {
          case 0: // Fund Name
            comparison = (a.scripName ?? '').compareTo(b.scripName ?? '');
            break;
          case 1: // Units
            final aQty = double.tryParse(a.totalUnits ?? '0') ?? 0;
            final bQty = double.tryParse(b.totalUnits ?? '0') ?? 0;
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
          final minWidths = _calculateMinWidths(displayHoldings, context);

          final availableWidth = constraints.maxWidth;

          final columnWidths = <int, double>{};
          for (int i = 0; i < 8; i++) {
            columnWidths[i] = minWidths[i] ?? 100.0;
          }

          final totalMinWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);

          if (totalMinWidth < availableWidth) {
            final extraSpace = availableWidth - totalMinWidth;
            final extraPerColumn = extraSpace / 8;

            for (int i = 0; i < 8; i++) {
              columnWidths[i] = columnWidths[i]! + extraPerColumn;
            }
          } else if (totalMinWidth > availableWidth) {
            final excessWidth = totalMinWidth - availableWidth;

            final absoluteMinWidths = <int, double>{
              0: 120.0, // Fund Name
              1: 60.0, // Units
              2: 70.0, // Avg NAV
              3: 70.0, // Cur NAV
              4: 60.0, // Inv
              5: 70.0, // Cur Val
              6: 60.0, // P&L
              7: 50.0, // Chg
            };

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

          final totalRequiredWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);

          final horizontalScrollController = ScrollController();
          final verticalScrollController = ScrollController();

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
                // Scrollable Body
                Expanded(
                  child: RawScrollbar(
                    controller: verticalScrollController,
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
                      controller: verticalScrollController,
                      scrollDirection: Axis.vertical,
                      child: shadcn.Table(
                        key: ValueKey(
                            'demat_table_${_sortColumnIndex}_$_sortAscending'),
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
                          ...displayHoldings.asMap().entries.map((entry) {
                            final index = entry.key;
                            final holding = entry.value;

                            return shadcn.TableRow(
                              cells: [
                                // Fund Name
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 0,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Tooltip(
                                      message: holding.scripName ?? 'N/A',
                                      child: Text(
                                        holding.scripName ?? 'N/A',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        softWrap: false,
                                        style: _getTextStyle(context),
                                      ),
                                    ),
                                  ),
                                ),
                                // Units
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 1,
                                  alignRight: true,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = (double.tryParse(
                                                  holding.totalUnits ?? '0') ??
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
                                // Avg NAV
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 2,
                                  alignRight: true,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = (double.tryParse(
                                                  holding.avgNav ?? '0') ??
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
                                // Current NAV
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 3,
                                  alignRight: true,
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
                                // Invested
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 4,
                                  alignRight: true,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = (double.tryParse(
                                                  holding.investedValue ??
                                                      '0') ??
                                              0.0)
                                          .toStringAsFixed(2);
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
                                // Current Value
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 5,
                                  alignRight: true,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final value = (double.tryParse(
                                                  holding.currentValue ??
                                                      '0') ??
                                              0.0)
                                          .toStringAsFixed(2);
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
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final pnlNum = double.tryParse(
                                              holding.profitLoss ?? '0') ??
                                          0.0;
                                      final value = pnlNum.toStringAsFixed(2);
                                      final color =
                                          _getCellColor(pnlNum, context);
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
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Builder(builder: (context) {
                                      final pctNum = double.tryParse(
                                              holding.changeprofitLoss ??
                                                  '0') ??
                                          0.0;
                                      final displayValue =
                                          '${pctNum >= 0 ? "+" : ""}${pctNum.toStringAsFixed(2)}%';
                                      final color =
                                          _getCellColor(pctNum, context);
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

          return RawScrollbar(
            controller: horizontalScrollController,
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
