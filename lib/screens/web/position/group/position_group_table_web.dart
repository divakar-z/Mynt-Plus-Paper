import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;

import '../../../../models/portfolio_model/position_book_model.dart';
import '../../../../provider/portfolio_provider.dart';
import '../../../../provider/privacy_provider.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../res/assets.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/snack_bar.dart';
import '../position_detail_screen_web.dart';

/// Table widget for displaying group positions (used inside expandable groups)
/// This is an alternative to the list view for web - shows positions in table format
class PositionGroupTable extends ConsumerStatefulWidget {
  final String groupSymbol;
  final List groupList;
  final bool isCustomGrp;

  const PositionGroupTable({
    super.key,
    required this.groupSymbol,
    required this.groupList,
    required this.isCustomGrp,
  });

  @override
  ConsumerState<PositionGroupTable> createState() => _PositionGroupTableState();
}

class _PositionGroupTableState extends ConsumerState<PositionGroupTable> {
  // Use ValueNotifier for hover to prevent full rebuilds
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);
  final Assets _assets = Assets();

  @override
  void dispose() {
    _hoveredRowIndex.dispose();
    super.dispose();
  }

  // Helper method for table cell text style
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

  // Get color for P&L values
  Color _getPnlColor(double value, BuildContext context) {
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

  // Get color for quantity
  Color _getQtyColor(int qty, BuildContext context) {
    if (qty > 0) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    } else if (qty < 0) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    }
    return resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
  }

  // Format instrument display text
  String _formatInstrument(Map<String, dynamic> position) {
    final symbol = position['symbol']?.toString() ?? '';
    final expDate = position['expDate']?.toString() ?? '';
    final option = position['option']?.toString() ?? '';

    String display = symbol;
    if (expDate.isNotEmpty && expDate != '-') {
      display += ' $expDate';
    }
    if (option.isNotEmpty) {
      display += ' $option';
    }
    return display.trim();
  }

  // Check if position is closed
  bool _isPositionClosed(Map<String, dynamic> position) {
    final qty = int.tryParse(position['qty']?.toString() ?? '0') ?? 0;
    final netQty = int.tryParse(position['netqty']?.toString() ?? position['qty']?.toString() ?? '0') ?? 0;
    return qty == 0 || netQty == 0;
  }

  // Build header cell
  shadcn.TableCell _buildHeaderCell(String label, bool alignRight) {
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          style: _getHeaderStyle(context),
        ),
      ),
    );
  }

  // Build data cell with hover support
  shadcn.TableCell _buildDataCell({
    required Widget child,
    required int rowIndex,
    required bool alignRight,
    required bool isClosed,
    Map<String, dynamic>? position,
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
        onEnter: (_) => _hoveredRowIndex.value = rowIndex,
        onExit: (_) => _hoveredRowIndex.value = null,
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredRowIndex,
          child: child,
          builder: (context, hoveredIndex, cachedChild) {
            final isRowHovered = hoveredIndex == rowIndex;

            Color? backgroundColor;
            if (isClosed) {
              backgroundColor = resolveThemeColor(context,
                  dark: MyntColors.textPrimary.withValues(alpha: 0.05),
                  light: const Color(0x8F121212).withValues(alpha: 0.03));
            } else if (isRowHovered) {
              backgroundColor = resolveThemeColor(context,
                  dark: MyntColors.primaryDark.withValues(alpha: 0.08),
                  light: MyntColors.primary.withValues(alpha: 0.08));
            }

            final container = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: backgroundColor,
              alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
              child: cachedChild,
            );

            // Make cell tappable if position data is provided
            if (position != null) {
              return GestureDetector(
                onTap: () => _showPositionDetail(position),
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

  // Remove a single position from a custom group.
  // Works off the group's own saved data, so a position that is no longer in
  // the position book (exited earlier, book not uploaded yet) can still be
  // removed — the Add Symbol dialog only lists live positions and cannot
  // reach those rows.
  Future<void> _removeFromGroup(Map<String, dynamic> groupItem) async {
    final tsym = groupItem['tsym']?.toString() ?? '';
    if (tsym.isEmpty) {
      showResponsiveWarningMessage(context, "Unable to remove this position");
      return;
    }
    await ref
        .read(portfolioProvider)
        .fetchDeleteGroupSymbol(widget.groupSymbol, context, tsym);
  }

  // Remove button revealed on row hover, styled like the Positions screen
  // hover actions (25x25, rounded 5).
  Widget _buildRemoveButton(Map<String, dynamic> groupItem) {
    final iconColor = resolveThemeColor(context,
        dark: MyntColors.errorDark, light: MyntColors.error);
    return Tooltip(
      message: 'Remove from group',
      child: SizedBox(
        width: 25,
        height: 25,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(5),
            splashColor: iconColor.withValues(alpha: 0.15),
            highlightColor: iconColor.withValues(alpha: 0.08),
            onTap: () => _removeFromGroup(groupItem),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: SvgPicture.asset(
                  _assets.trash,
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Show position detail sheet (same logic as GroupSymbolListItem)
  void _showPositionDetail(Map<String, dynamic> groupItem) async {
    final marketWatch = ref.read(marketWatchProvider);
    final positionBook = ref.read(portfolioProvider);
    final parentCtx = context;

    // Fetch linked scrip data
    await marketWatch.fetchLinkeScrip(
      "${groupItem['token']}",
      "${groupItem['exch']}",
      context,
    );

    // Fetch scrip quote
    await marketWatch.fetchScripQuote(
      "${groupItem['token']}",
      "${groupItem['exch']}",
      context,
    );

    // Handle NSE/BSE specific data
    if (groupItem['exch'] == "NSE" || groupItem['exch'] == "BSE") {
      await marketWatch.fetchTechData(
        context: context,
        exch: "${groupItem['exch']}",
        tradeSym: "${groupItem['tsym']}",
        lastPrc: "${groupItem['lp']}",
      );
    }

    if (!mounted) return;

    // Find the position in the position book
    PositionBookModel? foundPosition;
    try {
      final token = groupItem['token']?.toString();
      final tsym = groupItem['tsym']?.toString();
      final exch = groupItem['exch']?.toString();
      final prd = groupItem['prd']?.toString();

      foundPosition = positionBook.postionBookModel!.firstWhere(
        (pos) =>
            pos.token == token &&
            pos.tsym == tsym &&
            pos.exch == exch &&
            (prd == null || pos.prd == prd),
      );
    } catch (e) {
      if (positionBook.postionBookModel != null &&
          positionBook.postionBookModel!.isNotEmpty) {
        foundPosition = positionBook.postionBookModel!.first;
      }
    }

    if (foundPosition == null) {
      showResponsiveWarningMessage(context, "Position not found");
      return;
    }

    // Show detail sheet
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
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 5,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: PositionDetailScreenWeb(
            positionList: foundPosition!,
            parentContext: parentCtx,
          ),
        );
      },
      position: shadcn.OverlayPosition.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final positions = ref.watch(portfolioProvider);
    // Privacy Mode: qty, avg and P&L are masked; LTP stays visible.
    final privacy = ref.watch(privacyProvider);

    if (widget.groupList.isEmpty) {
      return const SizedBox.shrink();
    }

    // Define column headers
    // Columns: Product | Instrument | Qty | Avg | LTP | P&L
    final headers = ['Product', 'Instrument', 'Qty', 'Avg', 'LTP', 'P&L'];

    // Remove action is shown on hover inside the Instrument cell, and only for
    // custom groups — default groups are derived from the position book, so
    // there is no saved entry to remove.
    final showRemove = widget.isCustomGrp;

    // Use LayoutBuilder to get available width and distribute columns
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // Minimum widths for each column
        const minWidths = <int, double>{
          0: 70,   // Product
          1: 180,  // Instrument (needs more space)
          2: 80,   // Qty
          3: 90,   // Avg
          4: 80,   // LTP
          5: 100,  // P&L
        };

        // Calculate total minimum width
        final totalMinWidth = minWidths.values.fold<double>(0, (sum, w) => sum + w);

        // Calculate column widths based on available space
        final columnWidths = <int, shadcn.TableSize>{};

        if (availableWidth > totalMinWidth) {
          // Extra space available - distribute equally across all columns
          final extraSpace = availableWidth - totalMinWidth;
          final extraPerColumn = extraSpace / headers.length;

          for (int i = 0; i < headers.length; i++) {
            columnWidths[i] = shadcn.FixedTableSize(minWidths[i]! + extraPerColumn);
          }
        } else {
          // Use minimum widths
          for (int i = 0; i < headers.length; i++) {
            columnWidths[i] = shadcn.FixedTableSize(minWidths[i]!);
          }
        }

        return shadcn.Table(
      columnWidths: columnWidths,
      defaultRowHeight: const shadcn.FixedTableSize(40),
      rows: [
        // Header row
        shadcn.TableHeader(
          cells: headers.asMap().entries.map((entry) {
            final index = entry.key;
            final header = entry.value;
            final alignRight = index >= 2; // Qty, Avg, LTP, P&L are right-aligned
            return _buildHeaderCell(header, alignRight);
          }).toList(),
        ),
        // Data rows
        ...widget.groupList.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final groupItem = entry.value as Map<String, dynamic>;
          final isClosed = _isPositionClosed(groupItem);

          // Get values
          final product = groupItem['s_prdt_ali']?.toString() ?? 'N/A';
          final instrument = _formatInstrument(groupItem);
          final exchange = groupItem['exch']?.toString() ?? '';
          // For MCX, divide qty by lotSize for display
          final rawQty = int.tryParse(groupItem['qty']?.toString() ?? '0') ?? 0;
          final lotSize = double.tryParse(groupItem['ls']?.toString() ?? '1') ?? 1.0;
          final qty = exchange == 'MCX' ? (rawQty / lotSize).toInt() : rawQty;
          final qtyStr = privacy.mask(qty > 0 ? '+$qty' : '$qty');

          // Get average price based on day/net mode
          final avgPrice = privacy.mask(positions.isDay
              ? groupItem['avgPrc']?.toString() ?? '0.00'
              : positions.isNetPnl
                  ? (groupItem['netupldprc'] ?? groupItem['avgPrc'])?.toString() ?? '0.00'
                  : (groupItem['netavgprc'] ?? groupItem['avgPrc'])?.toString() ?? '0.00');

          final ltp = groupItem['lp']?.toString() ?? '0.00';

          // Get P&L based on net/mtm mode
          final pnlStr = privacy.mask(positions.isNetPnl
              ? (groupItem['profitNloss'] ?? groupItem['rpnl'])?.toString() ?? '0.00'
              : groupItem['mTm']?.toString() ?? '0.00');
          final pnlValue = privacy.isPrivate ? 0.0 : (double.tryParse(pnlStr) ?? 0.0);

          // Text color for closed positions
          final textColor = isClosed
              ? resolveThemeColor(context,
                  dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary)
              : null;

          return shadcn.TableRow(
            cells: [
              // Product cell
              _buildDataCell(
                rowIndex: rowIndex,
                alignRight: false,
                isClosed: isClosed,
                position: groupItem,
                child: Text(
                  product,
                  style: _getTextStyle(context,
                      color: textColor ??
                          resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary)),
                ),
              ),
              // Instrument cell
              _buildDataCell(
                rowIndex: rowIndex,
                alignRight: false,
                isClosed: isClosed,
                position: groupItem,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        instrument,
                        style: _getTextStyle(context, color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Remove action - appears on row hover, same pattern as the
                    // Positions screen action buttons.
                    if (showRemove)
                      ValueListenableBuilder<int?>(
                        valueListenable: _hoveredRowIndex,
                        builder: (context, hoveredIndex, _) {
                          final rowIsHovered = hoveredIndex == rowIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: rowIsHovered ? null : 0,
                            curve: Curves.easeInOut,
                            child: IgnorePointer(
                              ignoring: !rowIsHovered,
                              child: AnimatedOpacity(
                                opacity: rowIsHovered ? 1 : 0,
                                duration: const Duration(milliseconds: 140),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(width: 8),
                                    _buildRemoveButton(groupItem),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    // if (exchange.isNotEmpty) ...[
                    //   const SizedBox(width: 4),
                    //   Text(
                    //     exchange,
                    //     style: MyntWebTextStyles.para(
                    //       context,
                    //       darkColor: MyntColors.textSecondaryDark,
                    //       lightColor: MyntColors.textSecondary,
                    //       fontWeight: MyntFonts.medium,
                    //     ).copyWith(fontSize: 10),
                    //   ),
                    // ],
                  ],
                ),
              ),
              // Qty cell
              _buildDataCell(
                rowIndex: rowIndex,
                alignRight: true,
                isClosed: isClosed,
                position: groupItem,
                child: Tooltip(
                  message: qtyStr,
                  child: Text(
                    qtyStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _getTextStyle(context,
                        color: isClosed
                            ? textColor
                            : _getQtyColor(
                                privacy.isPrivate ? 0 : qty, context)),
                  ),
                ),
              ),
              // Avg cell
              _buildDataCell(
                rowIndex: rowIndex,
                alignRight: true,
                isClosed: isClosed,
                position: groupItem,
                child: Tooltip(
                  message: avgPrice,
                  child: Text(
                    avgPrice,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _getTextStyle(context, color: textColor),
                  ),
                ),
              ),
              // LTP cell
              _buildDataCell(
                rowIndex: rowIndex,
                alignRight: true,
                isClosed: isClosed,
                position: groupItem,
                child: Tooltip(
                  message: ltp,
                  child: Text(
                    ltp,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _getTextStyle(context, color: textColor),
                  ),
                ),
              ),
              // P&L cell
              _buildDataCell(
                rowIndex: rowIndex,
                alignRight: true,
                isClosed: isClosed,
                position: groupItem,
                child: Tooltip(
                  message: pnlStr,
                  child: Text(
                    pnlStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _getTextStyle(context,
                        color: isClosed ? textColor : _getPnlColor(pnlValue, context)),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
      },
    );
  }
}
