// Futures screen with shadcn.Table implementation
// Converted from DataTable2 to shadcn.Table pattern following hold_table.dart

import 'package:flutter/material.dart'
    show
        InkWell,
        Icons,
        VoidCallback,
        BorderRadius,
        Icon,
        BoxDecoration,
        TextPainter,
        TextSpan,
        TextStyle,
        TextDirection,
        Row,
        MainAxisSize,
        SizedBox,
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
        AnimatedOpacity,
        ScrollController,
        SingleChildScrollView,
        Scrollbar,
        Column,
        LayoutBuilder,
        ValueKey,
        IconData,
        Padding,
        Tooltip,
        Stack,
        LinearGradient,
        BoxConstraints,
        Clip,
        MediaQuery,
        Builder,
        Visibility,
        Navigator,
        Center,
        StreamBuilder,
        Listener,
        debugPrint,
        Colors,
        Material,
        Border;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'dart:html' as html;

import 'tv_chart/chart_iframe_guard.dart';

import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../models/order_book_model/order_book_model.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';

import '../../../utils/responsive_navigation.dart';
import '../../../utils/responsive_snackbar.dart';

import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';

class FutureScreenWeb extends ConsumerStatefulWidget {
  const FutureScreenWeb({super.key});

  @override
  ConsumerState<FutureScreenWeb> createState() => _FutureScreenWebState();
}

class _FutureScreenWebState extends ConsumerState<FutureScreenWeb> {
  int? _hoveredRowIndex;
  bool _isNavigating = false;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Scroll controllers
  late ScrollController _verticalScrollController;
  late ScrollController _horizontalScrollController;

  @override
  void initState() {
    super.initState();
    _verticalScrollController = ScrollController();
    _horizontalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // Directly disable all chart iframes and reset cursor (like chart's onExit)
  void _disableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement &&
            iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'none';
          // Reset cursor style to prevent cursor bleeding
          iframe.style.cursor = 'default';
        }
      }
      // Also reset cursor on document body to ensure it's reset globally
      html.document.body?.style.cursor = 'default';
    } catch (e) {
    }
  }

  void _enableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement &&
            iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'auto';
          iframe.style.cursor = '';
        }
      }
      html.document.body?.style.cursor = '';
    } catch (e) {
    }
  }

  // Helper method to get appropriate text style for table cells (matching position_table.dart)
  TextStyle _getTextStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.body(
      context,
      color: color,
      darkColor: color ?? MyntColors.textPrimaryDark,
      lightColor: color ?? MyntColors.textPrimary,
      fontWeight: MyntFonts.medium,
    );
  }

  // Helper method for header text style (matching position_table.dart)
  TextStyle _getHeaderStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.body(
      context,
      color: color,
      darkColor: color ?? MyntColors.textSecondaryDark,
      lightColor: color ?? MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  // Helper widget to build consistent hover buttons (matching watchlist_card_web.dart)
  Widget _buildHoverButton({
    String? label,
    IconData? icon,
    required Color color,
    Color? backgroundColor,
    Color? borderColor,
    double? borderRadius,
    required VoidCallback? onPressed,
  }) {
    final isLongLabel = label != null && label.length > 1;
    final borderRadiusValue = borderRadius ?? 5.0;

    return SizedBox(
      width: isLongLabel ? null : 25,
      height: 25,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          splashColor: color.withValues(alpha: 0.15),
          highlightColor: color.withValues(alpha: 0.08),
          onTap: onPressed,
          child: Container(
            padding:
                isLongLabel ? const EdgeInsets.symmetric(horizontal: 8) : null,
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

  // Builds a bordered cell
  shadcn.TableCell buildCell(Widget child, [bool alignRight = false]) {
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
      child: Container(
        padding: const EdgeInsets.all(8),
        alignment: alignRight ? Alignment.topRight : null,
        child: child,
      ),
    );
  }

  // Builds a cell with hover detection
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 3;

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
        onEnter: (_) => setState(() => _hoveredRowIndex = rowIndex),
        onExit: (_) => setState(() => _hoveredRowIndex = null),
        child: Container(
          padding: cellPadding,
          alignment: alignRight ? Alignment.topRight : null,
          child: child,
        ),
      ),
    );
  }

  // Builds a sortable header cell with sort indicator
  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 3;

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
      text: TextSpan(
          text: text,
          style: MyntWebTextStyles.para(
            context,
            color: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
            fontWeight: MyntFonts.semiBold,
          )),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();
    return textPainter.width;
  }

  // Calculate minimum column widths dynamically based on header and data
  Map<int, double> _calculateMinWidths(
      List<dynamic> futures, BuildContext context) {
    const padding = 24.0;
    const sortIconWidth = 24.0;

    final headers = ['Symbol', 'LTP', 'Change', 'Change %'];
    final minWidths = <int, double>{};

    for (int col = 0; col < headers.length; col++) {
      double maxWidth = 0.0;

      final headerWidth = _measureTextWidth(headers[col], const TextStyle());
      maxWidth = headerWidth + sortIconWidth;

      for (final future in futures) {
        String cellText = '';

        switch (col) {
          case 0: // Symbol
            cellText = future.tsym?.toString() ?? '';
            break;
          case 1: // LTP
            cellText = future.ltp ?? future.close ?? '0.00';
            break;
          case 2: // Change
            cellText = _getChangeValue(future);
            break;
          case 3: // Change %
            cellText = '${_getPerChangeValue(future)}%';
            break;
        }

        final cellWidth = _measureTextWidth(cellText, const TextStyle());
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }

      // Symbol column needs extra space for action buttons
      // Buttons will overlay on the right side, covering only half the text
      // Text can use full width, buttons appear on hover as overlay

      // Set minimum width (max of header/data + padding)
      minWidths[col] = maxWidth + padding;
    }

    return minWidths;
  }

  @override
  Widget build(BuildContext context) {
    final future = ref.watch(marketWatchProvider);
    final theme = ref.read(themeProvider);

    if (future.fut == null || future.fut!.isEmpty) {
      return Center(
        child: Text(
          "No futures data available",
          style: _getTextStyle(
            context,
            color: resolveThemeColor(
              context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.textSecondary,
            ),
          ),
        ),
      );
    }

    // Sort futures based on selected column
    List<dynamic> sortedFutures = List.from(future.fut!);
    if (_sortColumnIndex != null) {
      sortedFutures.sort((a, b) {
        int comparison = 0;
        switch (_sortColumnIndex) {
          case 0: // Symbol
            comparison =
                (a.tsym?.toString() ?? '').compareTo(b.tsym?.toString() ?? '');
            break;
          case 1: // LTP
            final ltpA = double.tryParse(a.ltp ?? a.close ?? '0') ?? 0.0;
            final ltpB = double.tryParse(b.ltp ?? b.close ?? '0') ?? 0.0;
            comparison = ltpA.compareTo(ltpB);
            break;
          case 2: // Change
            final changeA = double.tryParse(a.change ?? '0') ?? 0.0;
            final changeB = double.tryParse(b.change ?? '0') ?? 0.0;
            comparison = changeA.compareTo(changeB);
            break;
          case 3: // Change %
            final perChangeA = double.tryParse(a.perChange ?? '0') ?? 0.0;
            final perChangeB = double.tryParse(b.perChange ?? '0') ?? 0.0;
            comparison = perChangeA.compareTo(perChangeB);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    return StreamBuilder<Map>(
      stream: ref.watch(websocketProvider).socketDataStream,
      builder: (context, snapshot) {
        final socketDatas = snapshot.data ?? {};

        return PointerInterceptor(
          child: MouseRegion(
            cursor: SystemMouseCursors.basic,
            onEnter: (_) {
              ChartIframeGuard.acquire();
              _disableAllChartIframes();
            },
            onHover: (_) {
              _disableAllChartIframes();
            },
            onExit: (_) {
              ChartIframeGuard.release();
              _enableAllChartIframes();
            },
            child: Listener(
              onPointerMove: (_) {
                _disableAllChartIframes();
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: shadcn.OutlinedContainer(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate minimum widths dynamically
                      final minWidths =
                          _calculateMinWidths(sortedFutures, context);

                      // Available width
                      final availableWidth = constraints.maxWidth;

                      // Start with minimum widths
                      final columnWidths = <int, double>{};
                      for (int i = 0; i < 4; i++) {
                        columnWidths[i] = minWidths[i] ?? 100.0;
                      }

                      // Calculate total minimum width needed
                      final totalMinWidth = columnWidths.values
                          .fold<double>(0.0, (sum, width) => sum + width);

                      // If there's extra space, distribute it proportionally
                      if (totalMinWidth < availableWidth) {
                        final extraSpace = availableWidth - totalMinWidth;

                        const symbolGrowthFactor = 2.0;
                        const numericGrowthFactor = 1.0;

                        final growthFactors = <int, double>{};
                        double totalGrowthFactor = 0.0;

                        for (int i = 0; i < 4; i++) {
                          if (i == 0) {
                            growthFactors[i] = symbolGrowthFactor;
                            totalGrowthFactor += symbolGrowthFactor;
                          } else {
                            growthFactors[i] = numericGrowthFactor;
                            totalGrowthFactor += numericGrowthFactor;
                          }
                        }

                        if (totalGrowthFactor > 0) {
                          for (int i = 0; i < 4; i++) {
                            if (growthFactors[i]! > 0) {
                              final extraForThisColumn =
                                  (extraSpace * growthFactors[i]!) /
                                      totalGrowthFactor;
                              columnWidths[i] =
                                  columnWidths[i]! + extraForThisColumn;
                            }
                          }
                        }
                      }

                      // Calculate total required width
                      final totalRequiredWidth = columnWidths.values
                          .fold<double>(0.0, (sum, width) => sum + width);

                      // If total width exceeds available width, enable horizontal scrolling
                      final needsHorizontalScroll =
                          totalRequiredWidth > availableWidth;

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
                              },
                              defaultRowHeight: const shadcn.FixedTableSize(40),
                              rows: [
                                shadcn.TableHeader(
                                  cells: [
                                    buildHeaderCell('Symbol', 0),
                                    buildHeaderCell('LTP', 1, true),
                                    buildHeaderCell('Change', 2, true),
                                    buildHeaderCell('Change %', 3, true),
                                  ],
                                ),
                              ],
                            ),
                            // Scrollable Body
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
                                    key: ValueKey(
                                        'futures_table_${_sortColumnIndex}_$_sortAscending'),
                                    columnWidths: {
                                      0: shadcn.FixedTableSize(
                                          columnWidths[0]!),
                                      1: shadcn.FixedTableSize(
                                          columnWidths[1]!),
                                      2: shadcn.FixedTableSize(
                                          columnWidths[2]!),
                                      3: shadcn.FixedTableSize(
                                          columnWidths[3]!),
                                    },
                                    defaultRowHeight:
                                        const shadcn.FixedTableSize(40),
                                    rows: [
                                      // Data Rows
                                      ...sortedFutures
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final index = entry.key;
                                        var displayData = entry.value;
                                        final tokenKey =
                                            displayData.token?.toString();

                                        // Update with socket data if available
                                        if (tokenKey != null &&
                                            socketDatas.containsKey(tokenKey)) {
                                          final socketData =
                                              socketDatas[tokenKey];

                                          final lp = socketData['lp']
                                                  ?.toString() ??
                                              socketData['ltp']?.toString() ??
                                              socketData['last_price']
                                                  ?.toString();
                                          if (lp != null &&
                                              lp != "null" &&
                                              lp != "0" &&
                                              lp != "0.00" &&
                                              lp.isNotEmpty) {
                                            try {
                                              final ltpValue = double.parse(lp);
                                              if (ltpValue > 0) {
                                                displayData.ltp = lp;
                                              }
                                            } catch (e) {
                                              // Keep original value
                                            }
                                          }

                                          final chng = socketData['chng']
                                                  ?.toString() ??
                                              socketData['change']?.toString();
                                          if (chng != null &&
                                              chng != "null" &&
                                              chng.isNotEmpty &&
                                              chng != "0" &&
                                              chng != "0.0" &&
                                              chng != "0.00") {
                                            try {
                                              displayData.change = chng;
                                            } catch (e) {}
                                          }

                                          final pc =
                                              socketData['pc']?.toString() ??
                                                  socketData['per_change']
                                                      ?.toString();
                                          if (pc != null &&
                                              pc != "null" &&
                                              pc.isNotEmpty &&
                                              pc != "0" &&
                                              pc != "0.0" &&
                                              pc != "0.00") {
                                            try {
                                              displayData.perChange = pc;
                                            } catch (e) {}
                                          }
                                        }

                                        final isRowHovered =
                                            _hoveredRowIndex == index;
                                        final displayText =
                                            displayData.tsym?.toString() ?? '';

                                        return shadcn.TableRow(
                                          cells: [
                                            // Symbol cell with action buttons on hover
                                            buildCellWithHover(
                                              rowIndex: index,
                                              columnIndex: 0,
                                              child: SizedBox(
                                                width: double.infinity,
                                                height: double.infinity,
                                                child: Stack(
                                                  clipBehavior: Clip.hardEdge,
                                                  children: [
                                                    // Symbol name
                                                    Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Tooltip(
                                                        message: displayText,
                                                        child: Padding(
                                                          padding: EdgeInsets.only(
                                                              right:
                                                                  isRowHovered
                                                                      ? 8.0
                                                                      : 0.0),
                                                          child: Text(
                                                            displayText,
                                                            style:
                                                                _getTextStyle(
                                                                    context),
                                                            overflow: isRowHovered
                                                                ? TextOverflow
                                                                    .ellipsis
                                                                : TextOverflow
                                                                    .visible,
                                                            maxLines: 1,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    // Action buttons on hover
                                                    Visibility(
                                                      visible: isRowHovered,
                                                      maintainSize: false,
                                                      maintainAnimation: false,
                                                      maintainState: false,
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: LayoutBuilder(
                                                            builder: (context,
                                                                constraints) {
                                                          // Responsive max width based on screen size
                                                          final screenWidth =
                                                              MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width;
                                                          final isSmallScreen =
                                                              screenWidth < 768;
                                                          final isVerySmallScreen =
                                                              screenWidth < 480;
                                                          final responsiveMaxWidth =
                                                              isVerySmallScreen
                                                                  ? 120.0
                                                                  : (isSmallScreen
                                                                      ? 160.0
                                                                      : 200.0);

                                                          // Use available width, but cap at responsive max to prevent overflow
                                                          final maxButtonWidth =
                                                              constraints
                                                                  .maxWidth
                                                                  .clamp(0.0,
                                                                      responsiveMaxWidth);

                                                          return AnimatedOpacity(
                                                            opacity:
                                                                isRowHovered
                                                                    ? 1
                                                                    : 0,
                                                            duration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        140),
                                                            child: Container(
                                                              constraints:
                                                                  BoxConstraints(
                                                                      maxWidth:
                                                                          maxButtonWidth),
                                                              decoration:
                                                                  BoxDecoration(
                                                                gradient:
                                                                    LinearGradient(
                                                                  begin: Alignment
                                                                      .centerLeft,
                                                                  end: Alignment
                                                                      .centerRight,
                                                                  colors: [
                                                                    shadcn.Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .background
                                                                        .withValues(
                                                                            alpha:
                                                                                0.0),
                                                                    shadcn.Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .background
                                                                        .withValues(
                                                                            alpha:
                                                                                0.95),
                                                                  ],
                                                                ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 8),
                                                              child: _buildActionButtons(
                                                                  context,
                                                                  displayData,
                                                                  future,
                                                                  theme,
                                                                  isRowHovered),
                                                            ),
                                                          );
                                                        }),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // LTP cell
                                            buildCellWithHover(
                                              rowIndex: index,
                                              columnIndex: 1,
                                              alignRight: true,
                                              child: Text(
                                                displayData.ltp != null &&
                                                        displayData.ltp !=
                                                            "null"
                                                    ? "${displayData.ltp}"
                                                    : displayData.close !=
                                                                null &&
                                                            displayData.close !=
                                                                "null"
                                                        ? "${displayData.close}"
                                                        : '0.00',
                                                style: _getTextStyle(
                                                  context,
                                                  color: _getPriceColor(
                                                      displayData, theme),
                                                ),
                                              ),
                                            ),
                                            // Change cell
                                            buildCellWithHover(
                                              rowIndex: index,
                                              columnIndex: 2,
                                              alignRight: true,
                                              child: Text(
                                                _getChangeValue(displayData),
                                                style: _getTextStyle(
                                                  context,
                                                  color: _getChangeColor(
                                                      displayData, theme),
                                                ),
                                              ),
                                            ),
                                            // Change % cell
                                            buildCellWithHover(
                                              rowIndex: index,
                                              columnIndex: 3,
                                              alignRight: true,
                                              child: Text(
                                                '${_getPerChangeValue(displayData)}%',
                                                style: _getTextStyle(
                                                  context,
                                                  color: _getChangeColor(
                                                      displayData, theme),
                                                ),
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

                      // Wrap in horizontal scroll if needed
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
                      } else {
                        return buildTableContent();
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    dynamic displayData,
    MarketWatchProvider future,
    ThemesProvider theme,
    bool isHovered,
  ) {
    // Determine if scrip already exists in current watchlist
    final String key = "${displayData.exch}|${displayData.token}";
    final bool isInWatchlist = ref
        .read(marketWatchProvider)
        .scrips
        .any((e) => "${e['exch']}|${e['token']}" == key);

    return Builder(
      builder: (buttonContext) {
        final screenWidth = MediaQuery.of(buttonContext).size.width;
        final isSmallScreen = screenWidth < 768;
        final buttonSpacing = isSmallScreen ? 4.0 : 6.0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Buy Button
            _buildHoverButton(
              label: 'B',
              color: Colors.white,
              backgroundColor: resolveThemeColor(
                context,
                dark: MyntColors.primaryDark,
                light: MyntColors.primary,
              ),
              onPressed: () async {
                try {
                  await _placeOrderInput(context, displayData, true, future);
                } catch (e) {
                }
              },
            ),
            SizedBox(width: buttonSpacing),
            // Sell Button
            _buildHoverButton(
              label: 'S',
              color: Colors.white,
              backgroundColor: resolveThemeColor(
                context,
                dark: MyntColors.tertiary,
                light: MyntColors.tertiary,
              ),
              onPressed: () async {
                try {
                  await _placeOrderInput(context, displayData, false, future);
                } catch (e) {
                }
              },
            ),
            SizedBox(width: buttonSpacing),
            // Chart Button
            // _buildHoverButton(
            //   icon: Icons.bar_chart,
            //   color: Colors.black,
            //   backgroundColor: Colors.white,
            //   borderColor: shadcn.Theme.of(context).colorScheme.border,
            //   onPressed: () {
            //     Navigator.pop(context);
            //     ref
            //         .read(marketWatchProvider)
            //         .calldepthApis(context, displayData, "");
            //   },
            // ),
            // SizedBox(width: buttonSpacing),
            // Save Button (Add to watchlist)
            _buildHoverButton(
              icon: isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
              color: isInWatchlist
                  ? resolveThemeColor(
                      context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary,
                    )
                  : resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
              backgroundColor: Colors.white,
              borderColor: shadcn.Theme.of(context).colorScheme.border,
              onPressed: () async {
                final bool add = !isInWatchlist;
                final success = await future.addDelMarketScrip(
                  future.wlName,
                  key,
                  context,
                  add,
                  true,
                  false,
                  false,
                );
                if (success && mounted) {
                  if (add) {
                    ResponsiveSnackBar.showSuccess(
                        context, 'Added to your watchlist "${future.wlName}"');
                  } else {
                    ResponsiveSnackBar.showSuccess(
                        context, 'Removed from your watchlist "${future.wlName}"');
                  }
                  setState(() {});
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _getChangeValue(dynamic displayData) {
    final change = displayData.change?.toString();
    if (change != null && change != "null" && change.isNotEmpty) {
      return (double.tryParse(change)?.toStringAsFixed(2) ?? "0.00");
    }
    return "0.00";
  }

  String _getPerChangeValue(dynamic displayData) {
    final perChange = displayData.perChange?.toString();
    if (perChange != null && perChange != "null" && perChange.isNotEmpty) {
      return (double.tryParse(perChange)?.toStringAsFixed(2) ?? "0.00");
    }
    return "0.00";
  }

  Color _getPriceColor(dynamic displayData, ThemesProvider theme) {
    final change = displayData.change?.toString() ?? "0.00";
    final perChange = displayData.perChange?.toString() ?? "0.00";

    if (change.startsWith("-") || perChange.startsWith('-')) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else if (change == "null" ||
        perChange == "null" ||
        change == "0.00" ||
        perChange == "0.00") {
      return resolveThemeColor(
        context,
        dark: MyntColors.textPrimaryDark,
        light: MyntColors.textPrimary,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    }
  }

  Color _getChangeColor(dynamic displayData, ThemesProvider theme) {
    final change = displayData.change?.toString() ?? "0.00";
    final perChange = displayData.perChange?.toString() ?? "0.00";

    if (change == "null" ||
        perChange == "null" ||
        change == "0.00" ||
        perChange == "0.00") {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.textPrimaryDark,
        light: MyntColors.textPrimary,
      );
    }
  }

  // Helper method to safely parse numeric values
  String _safeParseNumeric(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;

    String stringValue = value.toString().trim();

    if (stringValue.isEmpty ||
        stringValue == 'null' ||
        stringValue == '0.0' ||
        stringValue == '0' ||
        stringValue == 'NaN' ||
        stringValue == 'Infinity') {
      return defaultValue;
    }

    try {
      double.parse(stringValue);
      return stringValue;
    } catch (e) {
      try {
        int.parse(stringValue);
        return stringValue;
      } catch (e) {
        return defaultValue;
      }
    }
  }

  // Helper method to safely parse lot size
  String _safeParseLotSize(
      dynamic scripInfoLs, dynamic depthDataLs, String defaultValue) {
    String scripInfoValue = _safeParseNumeric(scripInfoLs, "");
    if (scripInfoValue.isNotEmpty && scripInfoValue != defaultValue) {
      return scripInfoValue;
    }

    String depthDataValue = _safeParseNumeric(depthDataLs, "");
    if (depthDataValue.isNotEmpty && depthDataValue != defaultValue) {
      return depthDataValue;
    }

    return defaultValue;
  }

  Future<void> _placeOrderInput(BuildContext ctx, dynamic displayData,
      bool transType, MarketWatchProvider future) async {
    try {
      if (_isNavigating) return;

      setState(() {
        _isNavigating = true;
      });

      await ref.read(marketWatchProvider).fetchScripInfo(
          displayData.token?.toString() ?? "",
          displayData.exch?.toString() ?? "",
          context,
          true);

      final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
      if (scripInfo == null) {
        throw Exception('Failed to load scrip information');
      }

      final depthData = ref.read(marketWatchProvider).getQuotes ?? GetQuotes();

      final lotSize = _safeParseLotSize(depthData.ls, scripInfo.ls, "1");

      final safeLtp = _safeParseNumeric(
          displayData.ltp ?? displayData.close ?? depthData.lp, "0.00");
      final safePerChange =
          _safeParseNumeric(displayData.perChange ?? depthData.pc, "0.00");

      OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: displayData.exch?.toString() ?? "",
        tSym: displayData.tsym?.toString() ?? "",
        isExit: false,
        token: displayData.token?.toString() ?? "",
        transType: transType,
        lotSize: lotSize,
        ltp: safeLtp,
        perChange: safePerChange,
        orderTpye: '',
        holdQty: '',
        isModify: false,
        raw: {},
      );

      await Future.delayed(const Duration(milliseconds: 150));

      ResponsiveNavigation.toPlaceOrderScreen(
        context: context,
        arguments: {
          "orderArg": orderArgs,
          "scripInfo": scripInfo,
          "isBskt": ""
        },
      );
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          'Error placing order: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isNavigating = false;
            });
          }
        });
      }
    }
  }
}
