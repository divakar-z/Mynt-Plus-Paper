import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../../../models/order_book_model/order_book_model.dart';
import '../../../res/res.dart';
import '../../../models/portfolio_model/holdings_model.dart';
import '../../../models/portfolio_model/position_book_model.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/portfolio_provider.dart';
import '../../../provider/privacy_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../utils/responsive_navigation.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import '../order/modify_place_order_web_screen.dart';
import 'tv_chart/chart_iframe_guard.dart';

/// A card that displays position or holdings information for the current symbol
/// at the top of the depth screen. Shows P&L, quantity, and exit buttons.
class PositionHoldingsCardWeb extends ConsumerStatefulWidget {
  final String token;
  final String exchange;
  final String tsym;

  const PositionHoldingsCardWeb({
    super.key,
    required this.token,
    required this.exchange,
    required this.tsym,
  });

  @override
  ConsumerState<PositionHoldingsCardWeb> createState() =>
      _PositionHoldingsCardWebState();
}

class _PositionHoldingsCardWebState
    extends ConsumerState<PositionHoldingsCardWeb> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProviderRef);
    final socketDatas = ref.watch(websocketProvider).socketDatas;
    final theme = ref.read(themeProvider);
    final orderProv = ref.watch(orderProvider);

    // Find position for this token
    final position = _findPositionByToken(portfolio, widget.token);
    // Find holding for this token
    final holding = _findHoldingByToken(portfolio, widget.token);
    // Find open orders for this token
    final openOrders = _findOpenOrdersByToken(orderProv, widget.token);

    // If neither position nor holding nor orders exist, return empty
    if (position == null && holding == null && openOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build tab data - only 2 tabs: (Position OR Holdings) + Open Orders
    final List<_TabItem> allTabs = [];

    // First tab: Position if exists, otherwise Holdings if exists
    if (position != null) {
      allTabs.add(_TabItem(
        label: "Positions",
        count: 1,
        hasData: true,
        content: _buildPositionCard(position, socketDatas, theme),
      ));
    } else if (holding != null) {
      allTabs.add(_TabItem(
        label: "Holdings",
        count: 1,
        hasData: true,
        content: _buildHoldingsCard(holding, socketDatas, theme),
      ));
    }

    // Second tab: Open Orders (always shown)
    allTabs.add(_TabItem(
      label: "Open Orders",
      count: openOrders.length,
      hasData: openOrders.isNotEmpty,
      content: openOrders.isNotEmpty
          ? _buildOpenOrdersSection(openOrders, socketDatas, theme)
          : _buildNoDataMessage("No open orders"),
    ));

    // Reset selected tab index if out of bounds
    if (_selectedTabIndex >= allTabs.length) {
      _selectedTabIndex = 0;
    }

    return Column(
      children: [
        // Tab bar - shows 2 tabs dynamically
        _buildTabBar(allTabs),
        // Tab content
        allTabs[_selectedTabIndex].content,
      ],
    );
  }

  /// Build "No data" message for empty tabs
  Widget _buildNoDataMessage(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          message,
          style: MyntWebTextStyles.para(
            context,
            color: resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary),
          ),
        ),
      ),
    );
  }

  /// Build the tab bar with underline style (like Open/Executed/Trade tabs)
  /// Build the tab bar with pill style (matching Orders Book tabs)
  Widget _buildTabBar(List<_TabItem> tabs) {
    final theme = ref.read(themeProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = _selectedTabIndex == index;

          final textColor = isSelected
              ? resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary)
              : resolveThemeColor(context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary);

          return GestureDetector(
            onTap: () => setState(() => _selectedTabIndex = index),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? (theme.isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab.label,
                    style: MyntWebTextStyles.body(
                      context,
                      fontWeight:
                          isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                      color: textColor,
                    ),
                  ),
                  if (tab.count > 0) ...[
                    const SizedBox(width: 4),
                    Transform.translate(
                      offset: const Offset(0, -6),
                      child: Text(
                        "${tab.count}",
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          fontWeight:
                              isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                          color: textColor,
                        ).copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Find position by token from the position book
  PositionBookModel? _findPositionByToken(
      PortfolioProvider provider, String token) {
    final positions = provider.postionBookModel ?? [];
    for (final pos in positions) {
      if (pos.token == token) {
        return pos;
      }
    }
    return null;
  }

  /// Find holding by token from the holdings list
  HoldingsModel? _findHoldingByToken(
      PortfolioProvider provider, String token) {
    final holdings = provider.holdingsModel ?? [];
    for (final hold in holdings) {
      if (hold.exchTsym != null && hold.exchTsym!.isNotEmpty) {
        final holdToken = hold.exchTsym![0].token;
        if (holdToken == token) {
          return hold;
        }
      }
    }
    return null;
  }

  /// Find open orders for this token
  List<OrderBookModel> _findOpenOrdersByToken(
      OrderProvider provider, String token) {
    final openOrders = provider.openOrder ?? [];
    return openOrders.where((order) => order.token == token).toList();
  }

  /// Get fresh LTP from WebSocket data
  double _getFreshLtp(Map socketDatas, String? token, String? fallbackLtp) {
    if (token == null) return double.tryParse(fallbackLtp ?? '0') ?? 0;

    final socketData = socketDatas[token];
    if (socketData != null && socketData['lp'] != null) {
      return double.tryParse(socketData['lp'].toString()) ?? 0;
    }
    return double.tryParse(fallbackLtp ?? '0') ?? 0;
  }

  /// Calculate P&L percentage for position
  double _calculatePnlPercent(
      double ltp, double avgPrice, bool isLong, double pnl) {
    if (avgPrice == 0) return 0;

    // Calculate percentage based on price movement
    // For long: profit when ltp > avgPrice
    // For short: profit when ltp < avgPrice
    if (isLong) {
      return ((ltp - avgPrice) / avgPrice) * 100;
    } else {
      return ((avgPrice - ltp) / avgPrice) * 100;
    }
  }

  Widget _buildPositionCard(
      PositionBookModel position, Map socketDatas, ThemesProvider theme) {
    final ltp = _getFreshLtp(socketDatas, position.token, position.lp);
    final avgPrice = double.tryParse(position.avgPrc ?? '0') ?? 0;
    // Use netqty to determine long/short
    final netQty = int.tryParse(position.netqty ?? '0') ?? 0;
    // For MCX, divide quantity by lot size
    final lotSize = position.exch == 'MCX'
        ? (int.tryParse(position.ls ?? '1') ?? 1)
        : 1;
    final absQty = (netQty.abs()) ~/ lotSize;

    // Use pre-calculated P&L from provider (accounts for lot size, multiplier, etc.)
    final pnl = double.tryParse(position.profitNloss ?? '0') ?? 0;
    final isProfit = pnl >= 0;

    // Determine position type based on netqty
    final isLong = netQty > 0;
    final isZeroQty = netQty == 0;

    // Get symbol name
    final symbolName = position.tsym?.replaceAll("-EQ", "") ?? '';

    // Get product type
    final productType = position.sPrdtAli ?? position.prd ?? '';

    // Dynamic color based on position type: blue for buy/long, red for sell/short, neutral for zero
    final positionColor = isZeroQty
        ? resolveThemeColor(context,
            dark: MyntColors.textPrimaryDark,
            light: MyntColors.textPrimary)
        : isLong
            ? resolveThemeColor(context,
                dark: MyntColors.primaryDark,
                light: MyntColors.primary)
            : resolveThemeColor(context,
                dark: MyntColors.lossDark,
                light: MyntColors.loss);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Symbol name | Exit icon button (only for open positions)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Symbol name - muted for closed positions
                  Expanded(
                    child: Text(
                      symbolName,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: MyntFonts.semiBold,
                        color: isZeroQty
                            ? resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary)
                            : resolveThemeColor(context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Exit icon button - only show if position is open (not closed)
                  if (!isZeroQty) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: "Exit",
                      child: InkWell(
                        onTap: () => _exitPosition(position, ltp),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: resolveThemeColor(context,
                                    dark: MyntColors.lossDark,
                                    light: MyntColors.loss)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.output,
                            size: 18,
                            color: resolveThemeColor(context,
                                dark: MyntColors.lossDark,
                                light: MyntColors.loss),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
        
              // Row 2: QTY X AVG X.XX | P&L value
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // QTY and AVG info - QTY value has dynamic color
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "QTY ",
                          style: MyntWebTextStyles.para(
                            context,
                            fontWeight: MyntFonts.medium,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ),
                        TextSpan(
                          // Privacy Mode: qty (with its long/short sign and
                          // colour) is hidden.
                          text: ref.watch(privacyProvider).mask(
                              "${absQty == 0 ? '' : isLong ? '+' : '-'}$absQty",
                              suffix: " "),
                          style: MyntWebTextStyles.para(
                            context,
                            fontWeight: MyntFonts.medium,
                            color: ref.watch(privacyProvider).isPrivate
                                ? resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary)
                                : positionColor,
                          ),
                        ),
                        TextSpan(
                          text: ref.watch(privacyProvider).mask(
                              avgPrice.toStringAsFixed(2),
                              prefix: "AVG "),
                          style: MyntWebTextStyles.para(
                            context,
                            fontWeight: MyntFonts.medium,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // P&L value only (no percentage)
                  Text(
                    ref.watch(privacyProvider).mask(pnl.toStringAsFixed(2)),
                    style: MyntWebTextStyles.body(
                      context,
                      fontWeight: MyntFonts.semiBold,
                      color: ref.watch(privacyProvider).isPrivate
                          ? resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary)
                          : isProfit
                              ? resolveThemeColor(context,
                                  dark: MyntColors.profitDark,
                                  light: MyntColors.profit)
                              : resolveThemeColor(context,
                                  dark: MyntColors.lossDark,
                                  light: MyntColors.loss),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
        
              // Row 3: Product type | LTP value
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Product type
                  Text(
                    productType,
                    style: MyntWebTextStyles.para(
                      context,
                      fontWeight: MyntFonts.medium,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary),
                    ),
                  ),
                  // LTP value
                  Text(
                    "LTP ${ltp.toStringAsFixed(2)}",
                    style: MyntWebTextStyles.para(
                      context,
                      fontWeight: MyntFonts.medium,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildHoldingsCard(
      HoldingsModel holding, Map socketDatas, ThemesProvider theme) {
    // Get the exchange tsym that matches our token
    ExchTsym? matchingExch;
    for (final exch in holding.exchTsym ?? []) {
      if (exch.token == widget.token) {
        matchingExch = exch;
        break;
      }
    }

    if (matchingExch == null) return const SizedBox.shrink();

    final ltp =
        _getFreshLtp(socketDatas, matchingExch.token, matchingExch.lp);
    final avgPrice = double.tryParse(holding.avgPrc ?? '0') ?? 0;
    // Use currentQty for display (total holdings), saleableQty is for selling
    final currentQty = holding.currentQty ?? 0;
    final saleableQty = holding.saleableQty ?? 0;
    // currentQty already includes T1 (max of btstqty/npoadt1qty) from the provider.
    final int totalQty = currentQty;

    // Show card if there's any holding (totalQty > 0)
    if (totalQty <= 0) return const SizedBox.shrink();

    // Use pre-calculated P&L from provider (more accurate)
    final pnl = double.tryParse(matchingExch.profitNloss ?? '0') ?? 0;
    final pnlPercent = double.tryParse(matchingExch.pNlChng ?? '0') ?? 0;
    final isProfit = pnl >= 0;

    // Get symbol name
    final symbolName = matchingExch.tsym?.replaceAll("-EQ", "") ?? '';

    // Calculate investment value
    final investmentValue = totalQty * avgPrice;

    // Get LTP percentage change (daily change)
    final ltpPercentChange = double.tryParse(matchingExch.perChange ?? '0') ?? 0;
    final isLtpPositive = ltpPercentChange >= 0;

    // P&L color
    final pnlColor = isProfit
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Symbol name | Exit icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Symbol name
              Expanded(
                child: Text(
                  symbolName,
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Exit icon button - always red with tooltip
              Tooltip(
                message: "Exit",
                child: InkWell(
                  onTap: () => _exitHolding(holding, matchingExch!, ltp, saleableQty),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: resolveThemeColor(context,
                              dark: MyntColors.lossDark,
                              light: MyntColors.loss)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.output,
                      size: 18,
                      color: resolveThemeColor(context,
                          dark: MyntColors.lossDark,
                          light: MyntColors.loss),
                    ),
                  ),
                ),
              ),
              // OLD UI - P&L value with percentage on Row 1
              // Text(
              //   "${pnl.toStringAsFixed(2)} (${pnlPercent.toStringAsFixed(2)}%)",
              //   style: MyntWebTextStyles.body(
              //     context,
              //     fontWeight: MyntFonts.semiBold,
              //     color: pnlColor,
              //   ),
              // ),
              // const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 4),

          // Row 2: QTY X AVG X.XX | P&L value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // QTY and AVG
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "QTY ",
                      style: MyntWebTextStyles.para(
                        context,
                        fontWeight: MyntFonts.medium,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                      ),
                    ),
                    TextSpan(
                      text: ref
                          .watch(privacyProvider)
                          .mask("+$currentQty", suffix: " "),
                      style: MyntWebTextStyles.para(
                        context,
                        fontWeight: MyntFonts.medium,
                        color: resolveThemeColor(context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary), // Blue for holdings (buy)
                      ),
                    ),
                    TextSpan(
                      text: ref.watch(privacyProvider).mask(
                          avgPrice.toStringAsFixed(2),
                          prefix: "AVG "),
                      style: MyntWebTextStyles.para(
                        context,
                        fontWeight: MyntFonts.medium,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              // P&L value (no percentage)
              Text(
                ref.watch(privacyProvider).mask(pnl.toStringAsFixed(2)),
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  color: ref.watch(privacyProvider).isPrivate
                      ? resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary)
                      : pnlColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Row 3: INV X.XX | LTP X.XX
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Investment value
              Text(
                ref.watch(privacyProvider).mask(
                    investmentValue.toStringAsFixed(2),
                    prefix: "INV "),
                style: MyntWebTextStyles.para(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ),
              // LTP value (no percentage)
              Text(
                "LTP ${ltp.toStringAsFixed(2)}",
                style: MyntWebTextStyles.para(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ),
              // OLD UI - LTP with percentage
              // Text(
              //   "LTP ${ltp.toStringAsFixed(2)} (${isLtpPositive ? '' : ''}${ltpPercentChange.toStringAsFixed(2)}%)",
              //   style: MyntWebTextStyles.para(
              //     context,
              //     fontWeight: MyntFonts.medium,
              //     color: resolveThemeColor(context,
              //         dark: MyntColors.textSecondaryDark,
              //         light: MyntColors.textSecondary),
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build open orders section showing pending orders for this symbol
  Widget _buildOpenOrdersSection(
      List<OrderBookModel> orders, Map socketDatas, ThemesProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...orders.map((order) => _buildOrderRow(order, socketDatas, theme)),
      ],
    );

    // OLD UI - Container with yellow border and OPEN ORDERS header
    // return Container(
    //   margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    //   padding: const EdgeInsets.all(12),
    //   decoration: BoxDecoration(
    //     color: shadcn.Theme.of(context).colorScheme.card,
    //     borderRadius: BorderRadius.circular(8),
    //     border: Border.all(
    //       color: resolveThemeColor(context,
    //               dark: MyntColors.warning, light: MyntColors.warning)
    //           .withValues(alpha: 0.3),
    //       width: 1,
    //     ),
    //   ),
    //   child: Column(
    //     crossAxisAlignment: CrossAxisAlignment.start,
    //     children: [
    //       // Header: Open Orders label
    //       Row(
    //         children: [
    //           Container(
    //             padding:
    //                 const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    //             decoration: BoxDecoration(
    //               color: resolveThemeColor(context,
    //                       dark: MyntColors.warning,
    //                       light: MyntColors.warning)
    //                   .withValues(alpha: 0.15),
    //               borderRadius: BorderRadius.circular(4),
    //             ),
    //             child: Text(
    //               "OPEN ORDERS",
    //               style: MyntWebTextStyles.para(
    //                 context,
    //                 fontWeight: MyntFonts.semiBold,
    //                 color: resolveThemeColor(context,
    //                     dark: MyntColors.warning,
    //                     light: MyntColors.warning),
    //               ),
    //             ),
    //           ),
    //           const SizedBox(width: 8),
    //           Text(
    //             "${orders.length}",
    //             style: MyntWebTextStyles.para(
    //               context,
    //               fontWeight: MyntFonts.medium,
    //               color: resolveThemeColor(context,
    //                   dark: MyntColors.textSecondaryDark,
    //                   light: MyntColors.textSecondary),
    //             ),
    //           ),
    //         ],
    //       ),
    //       const SizedBox(height: 12),
    //
    //       // List of orders
    //       ...orders.map((order) => _buildOrderRow(order, socketDatas, theme)),
    //     ],
    //   ),
    // );
  }

  /// Build individual order row with cancel/edit buttons
  Widget _buildOrderRow(
      OrderBookModel order, Map socketDatas, ThemesProvider theme) {
    final isBuy = order.trantype == "B";
    // For MCX, divide quantity by lot size
    final rawQty = int.tryParse(order.qty ?? "0") ?? 0;
    final filledQty = int.tryParse(order.fillshares ?? "0") ?? 0;
    final lotSize = order.exch == 'MCX'
        ? (int.tryParse(order.ls ?? '1') ?? 1)
        : 1;
    final qty = (rawQty ~/ lotSize).toString();
    final filled = (filledQty ~/ lotSize).toString();
    final price = order.prc ?? "0";
    final triggerPrice = order.trgprc ?? "";
    final priceType = order.prctyp ?? "";
    final product = order.sPrdtAli ?? order.prd ?? "";
    final ltp = _getFreshLtp(socketDatas, order.token, order.ltp);
    final fullOrderTime = order.norentm ?? "";
    // Extract only time (HH:MM:SS or HH:MM AM/PM) from orderTime, remove date if present
    final orderTime = fullOrderTime.contains(' ')
        ? fullOrderTime.split(' ').last
        : fullOrderTime;

    // Get symbol name
    final symbolName = order.tsym?.replaceAll("-EQ", "") ?? '';

    // BUY/SELL color - Blue for buy, Red for sell
    final transactionColor = isBuy
        ? resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary)
        : resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Symbol name | Cancel button (X icon, red)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Symbol name
              Expanded(
                child: Text(
                  symbolName,
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Modify button (pencil icon) - primary/blue
              Tooltip(
                message: "Modify",
                child: InkWell(
                  onTap: () => _modifyOrder(order),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: resolveThemeColor(context,
                              dark: MyntColors.primaryDark,
                              light: MyntColors.primary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Cancel button (X icon) - always red
              Tooltip(
                message: "Cancel",
                child: InkWell(
                  onTap: () => _cancelOrder(order),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: resolveThemeColor(context,
                              dark: MyntColors.lossDark,
                              light: MyntColors.loss)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: resolveThemeColor(context,
                          dark: MyntColors.lossDark,
                          light: MyntColors.loss),
                    ),
                  ),
                ),
              ),
              // OLD UI - Direction badge
              // Container(
              //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              //   decoration: BoxDecoration(
              //     color: isBuy
              //         ? resolveThemeColor(context,
              //                 dark: MyntColors.profitDark,
              //                 light: MyntColors.profit)
              //             .withValues(alpha: 0.12)
              //         : resolveThemeColor(context,
              //                 dark: MyntColors.lossDark,
              //                 light: MyntColors.loss)
              //             .withValues(alpha: 0.12),
              //     borderRadius: BorderRadius.circular(4),
              //   ),
              //   child: Text(
              //     isBuy ? "BUY" : "SELL",
              //     style: MyntWebTextStyles.para(
              //       context,
              //       fontWeight: MyntFonts.semiBold,
              //       color: isBuy
              //           ? resolveThemeColor(context,
              //               dark: MyntColors.profitDark,
              //               light: MyntColors.profit)
              //           : resolveThemeColor(context,
              //               dark: MyntColors.lossDark,
              //               light: MyntColors.loss),
              //     ),
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 4),

          // Row 2: Exchange - Product - PriceType - Time | Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Exchange - Product - PriceType - Time info
              Expanded(
                child: Text(
                  "${order.exch ?? ''} - $product - $priceType${orderTime.isNotEmpty ? ' - $orderTime' : ''}",
                  style: MyntWebTextStyles.para(
                    context,
                    fontWeight: MyntFonts.medium,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Price value
              Text(
                price,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Row 3: BUY/SELL filled/total (colored) | LTP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // BUY/SELL filled/total
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: isBuy ? "BUY " : "SELL ",
                      style: MyntWebTextStyles.para(
                        context,
                        fontWeight: MyntFonts.semiBold,
                        color: transactionColor,
                      ),
                    ),
                    TextSpan(
                      text: "$filled/$qty",
                      style: MyntWebTextStyles.para(
                        context,
                        fontWeight: MyntFonts.semiBold,
                        color: transactionColor,
                      ),
                    ),
                  ],
                ),
              ),
              // LTP value
              Text(
                "LTP ${ltp.toStringAsFixed(2)}",
                style: MyntWebTextStyles.para(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ),
            ],
          ),

          // OLD UI - Row 3: Qty @ Price | Action buttons
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     // Qty and Trigger info
          //     Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Text(
          //           "Qty: $qty @ $price",
          //           style: MyntWebTextStyles.para(
          //             context,
          //             fontWeight: MyntFonts.semiBold,
          //             color: resolveThemeColor(context,
          //                 dark: MyntColors.textPrimaryDark,
          //                 light: MyntColors.textPrimary),
          //           ),
          //         ),
          //         if (triggerPrice.isNotEmpty && triggerPrice != "0.00")
          //           Text(
          //             "Trg: $triggerPrice",
          //             style: MyntWebTextStyles.para(
          //               context,
          //               color: resolveThemeColor(context,
          //                   dark: MyntColors.textSecondaryDark,
          //                   light: MyntColors.textSecondary),
          //             ),
          //           ),
          //       ],
          //     ),
          //
          //     // Action buttons
          //     Row(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         // Edit button
          //         IconButton(
          //           onPressed: () => _modifyOrder(order),
          //           icon: Icon(
          //             Icons.edit_outlined,
          //             size: 18,
          //             color: resolveThemeColor(context,
          //                 dark: MyntColors.primaryDark,
          //                 light: MyntColors.primary),
          //           ),
          //           tooltip: "Modify Order",
          //           padding: const EdgeInsets.all(4),
          //           constraints:
          //               const BoxConstraints(minWidth: 32, minHeight: 32),
          //         ),
          //         const SizedBox(width: 4),
          //         // Cancel button
          //         IconButton(
          //           onPressed: () => _cancelOrder(order),
          //           icon: Icon(
          //             Icons.close_rounded,
          //             size: 18,
          //             color: resolveThemeColor(context,
          //                 dark: MyntColors.lossDark, light: MyntColors.loss),
          //           ),
          //           tooltip: "Cancel Order",
          //           padding: const EdgeInsets.all(4),
          //           constraints:
          //               const BoxConstraints(minWidth: 32, minHeight: 32),
          //         ),
          //       ],
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }


  Future<void> _exitPosition(PositionBookModel position, double ltp) async {
    final netQty = int.tryParse(position.netqty ?? '0') ?? 0;

    // Fetch scrip info for order
    await ref.read(marketWatchProvider).fetchScripInfo(
          widget.token,
          widget.exchange,
          context,
          true,
        );

    final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
    if (scripInfo == null) return;

    // For long position, we sell; for short position, we buy
    final orderArgs = OrderScreenArgs(
      exchange: widget.exchange,
      tSym: widget.tsym,
      isExit: true,
      token: widget.token,
      transType: netQty < 0 ? true : false, // Buy if short, Sell if long
      prd: position.prd ?? "",
      lotSize: position.ls ?? "1",
      ltp: ltp.toStringAsFixed(2),
      perChange: position.perChange ?? "0.00",
      orderTpye: '',
      holdQty: netQty.abs().toString(),
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
  }

  Future<void> _exitHolding(
      HoldingsModel holding, ExchTsym exchTsym, double ltp, int saleableQty) async {
    // Check if there's sellable quantity available
    if (saleableQty <= 0) {
      // Show error message like holdings page does
      showResponsiveErrorMessage(
        context,
        "No sellable quantity available. Shares may be pledged, under delivery, or used as collateral.",
      );
      return;
    }

    // Fetch scrip info for order
    await ref.read(marketWatchProvider).fetchScripInfo(
          widget.token,
          widget.exchange,
          context,
          true,
        );

    final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
    if (scripInfo == null) return;

    // For holdings, we always sell
    final orderArgs = OrderScreenArgs(
      exchange: widget.exchange,
      tSym: widget.tsym,
      isExit: true,
      token: widget.token,
      transType: false, // Sell
      prd: holding.prd ?? "C", // CNC for holdings
      lotSize: exchTsym.ls ?? "1",
      ltp: ltp.toStringAsFixed(2),
      perChange: exchTsym.perChange ?? "0.00",
      orderTpye: '',
      holdQty: saleableQty.toString(),
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
  }

  /// Disable all chart iframes to allow pointer events on dialog
  void _disableAllChartIframes() {
    if (!kIsWeb) return;
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'none';
        }
      }
      html.document.body?.style.cursor = 'default';
    } catch (e) {
    }
  }

  /// Enable all chart iframes after dialog is closed
  void _enableAllChartIframes() {
    if (!kIsWeb) return;
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'auto';
        }
      }
    } catch (e) {
    }
  }

  /// Cancel an open order
  Future<void> _cancelOrder(OrderBookModel order) async {
    final symbol = order.tsym?.replaceAll("-EQ", "") ?? 'N/A';

    // Show confirmation dialog with iframe handling (same style as orders screen)
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
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
              child: Dialog(
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
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
                              'Cancel Order',
                              style: MyntWebTextStyles.title(
                                context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  ChartIframeGuard.release();
                                  _enableAllChartIframes();
                                  Navigator.of(dialogContext).pop(false);
                                },
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

                      // Content area
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Confirmation text with symbol in quotes
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

                            // Red Cancel button
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: TextButton(
                                onPressed: () {
                                  ChartIframeGuard.release();
                                  _enableAllChartIframes();
                                  Navigator.of(dialogContext).pop(true);
                                },
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
              ),
            ),
          ),
        );
      },
    );

    // Ensure iframes are re-enabled after dialog closes
    ChartIframeGuard.release();
    _enableAllChartIframes();

    if (shouldCancel != true || !mounted) return;

    // Cancel the order
    await ref.read(orderProvider).fetchOrderCancel(
          "${order.norenordno}",
          context,
          true,
        );
  }

  /// Modify an open order
  Future<void> _modifyOrder(OrderBookModel order) async {
    // Fetch scrip info for order
    await ref.read(marketWatchProvider).fetchScripInfo(
          order.token ?? widget.token,
          order.exch ?? widget.exchange,
          context,
          true,
        );

    final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
    if (scripInfo == null) {
      showResponsiveErrorMessage(context, "Unable to fetch scrip information");
      return;
    }

    // Create order args for modify
    final orderArgs = OrderScreenArgs(
      exchange: order.exch ?? widget.exchange,
      tSym: order.tsym ?? widget.tsym,
      isExit: false,
      token: order.token ?? widget.token,
      transType: order.trantype == "B",
      prd: order.prd ?? "",
      lotSize: order.ls ?? "1",
      ltp: order.ltp ?? "0.00",
      perChange: order.perChange ?? "0.00",
      orderTpye: order.prctyp ?? "",
      holdQty: order.qty ?? "",
      isModify: true,
      raw: order.toJson(),
    );

    // Show modify dialog
    ModifyPlaceOrderScreenWeb.showDraggable(
      context: context,
      modifyOrderArgs: order,
      scripInfo: scripInfo,
      orderArg: orderArgs,
      initialPosition: Offset(
        MediaQuery.of(context).size.width / 2 - 200,
        MediaQuery.of(context).size.height / 2 - 200,
      ),
    );
  }
}

/// Provider ref alias for cleaner code
final portfolioProviderRef = portfolioProvider;

/// Helper class for tab items
class _TabItem {
  final String label;
  final int count;
  final bool hasData;
  final Widget content;

  _TabItem({
    required this.label,
    required this.count,
    required this.hasData,
    required this.content,
  });
}
