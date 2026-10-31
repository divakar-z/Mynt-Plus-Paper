import 'dart:async';

import 'package:another_xlider/another_xlider.dart';
import 'package:another_xlider/models/handler.dart';
import 'package:another_xlider/models/tooltip/tooltip.dart';
import 'package:another_xlider/models/trackbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/market_watch/future_screen_web.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';

// import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'dart:html' as html;
import 'tv_chart/chart_iframe_guard.dart';
import 'package:mynt_plus/screens/web/market_watch/stock_report_web.dart';
import 'package:mynt_plus/screens/web/market_watch/scrip_detail_web.dart';
import 'package:mynt_plus/sharedWidget/list_divider.dart';
import 'package:mynt_plus/sharedWidget/hover_actions_web.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../locator/constant.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../models/marketwatch_model/market_watch_scrip_model.dart';
import '../../../models/order_book_model/order_book_model.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/portfolio_provider.dart';
import '../../../provider/order_provider.dart';

import '../../../res/res.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/responsive_extensions.dart';

import '../../../routes/route_names.dart';
import '../../../utils/cas_indicative.dart';
import '../../../utils/responsive_navigation.dart';
import '../../../utils/responsive_snackbar.dart';
import '../../web/order/quick_order_screen_web.dart';
import '../../../sharedWidget/no_data_found.dart';
import '../../../sharedWidget/mynt_loader.dart';
import '../../Mobile/market_watch/over_view/funtamental_data_widget.dart';
import 'position_holdings_card_web.dart';
import 'resizable_panel_splitter.dart';
// import 'set_alert_web.dart';

class ScripDepthInfoWeb extends ConsumerStatefulWidget {
  final DepthInputArgs wlValue;
  final String isBasket;
  final VoidCallback? onClose;
  // Futures row hover "chart" action — asks the host to switch to its Chart tab.
  final VoidCallback? onChartRequested;

  const ScripDepthInfoWeb({
    super.key,
    required this.wlValue,
    required this.isBasket,
    this.onClose,
    this.onChartRequested,
  });

  @override
  ConsumerState<ScripDepthInfoWeb> createState() => _ScripDepthInfoWebState();
}

class _ScripDepthInfoWebState extends ConsumerState<ScripDepthInfoWeb>
    with AutomaticKeepAliveClientMixin {
  // IMPORTANT: initSize must always be >= 0.29 to satisfy DraggableScrollableSheet constraint
  // minChildSize = 0.28, so initialChildSize must be >= minChildSize
  // For Overview state, initSize is calculated dynamically to show only the header section
  double initSize = 0.95;
  ChartArgs? chartArgs;
  String regtoken = "";
  bool _isDisposed = false;
  final ScrollController _scrollController = ScrollController();
  bool _isBottomSheetExpanded = false;
  // Futures list hover actions: "exch|token" of the hovered row, and a guard
  // so a double-click on B/S doesn't open two order screens.
  final ValueNotifier<String?> _hoveredFutureKey = ValueNotifier<String?>(null);
  bool _futureOrderNavigating = false;

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating

  // Memoized text styles

  TextStyle _getTitleStyle(Color color) {
    return MyntWebTextStyles.para(
      context,
      color: color,
      fontWeight: MyntFonts.medium,
    );
  }

  TextStyle _getValueStyle(Color color) {
    return MyntWebTextStyles.bodySmall(
      context,
      color: color,
      fontWeight: MyntFonts.medium,
    );
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

  @override
  void initState() {
    super.initState();
    regtoken = widget.wlValue.token;
    _initializeSize();

    // Initialize state in a microtask to avoid build/layout conflicts
    Future.microtask(() {
      if (!_isDisposed) {
        ref.read(marketWatchProvider).chngDephBtn("Overview");

        // Reset futures expansion state when opening a new scrip
        if (ref.read(marketWatchProvider).isFuturesExpanded) {
          ref.read(marketWatchProvider).toggleFuturesExpansion();
        }

        FirebaseAnalytics.instance.logScreenView(
          screenName: 'Stock details',
          screenClass: 'ScripDepthInfo',
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant ScripDepthInfoWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the selected scrip changes, update token and reset relevant state
    if (oldWidget.wlValue.token != widget.wlValue.token ||
        oldWidget.wlValue.exch != widget.wlValue.exch) {
      regtoken = widget.wlValue.token;
      // Ensure Overview state and safe initial size for the new scrip
      Future.microtask(() async {
        if (!_isDisposed) {
          final scripInfo = ref.read(marketWatchProvider);

          // Handle futures re-subscription when scrip changes while futures is expanded
          if (scripInfo.isFuturesExpanded) {
            // Unsubscribe from old futures first
            await scripInfo.requestWSFut(context: context, isSubscribe: false);

            // Always fetch linked scrips for the new symbol to populate futures list
            // This is needed regardless of whether options exist, as futures might still be available
            await scripInfo.fetchLinkeScrip(
                widget.wlValue.token, widget.wlValue.exch, context);

            // Subscribe to new futures (if any exist for the new symbol)
            await scripInfo.requestWSFut(context: context, isSubscribe: true);
          }

          await scripInfo.chngDephBtn("Overview");
          setState(() {
            initSize = _getSafeInitialSize(0.35);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    _hoveredFutureKey.dispose();
    super.dispose();
  }

  // Helper method to calculate safe initial size
  double _getSafeInitialSize(double desiredSize) {
    // Ensure minSize is always > minChildSize (0.28) with proper buffer
    double minSize = 0.29;
    double safeSize = desiredSize < minSize ? minSize : desiredSize;

    // Double-check that the result is safe for DraggableScrollableSheet
    if (safeSize < 0.29) {
      safeSize = 0.29;
    }

    return safeSize;
  }

  // Calculate dynamic initial size based on content height
  double _calculateDynamicInitialSize(BuildContext context) {
    if (ref.read(marketWatchProvider).actDeptBtn != "Overview" ||
        ref.read(marketWatchProvider).scripsize == true) {
      return 0.75;
    }

    // Calculate the height needed for the header section (up to Chart and Options buttons)
    // This includes: CustomDragHandler + symbol info + buy/sell buttons + Chart/Options buttons
    double headerHeight = 0;

    // CustomDragHandler height
    headerHeight += 24; // Approximate height of drag handler

    // Symbol info section height
    headerHeight += 80; // Symbol text + price + change info

    // Buy/Sell buttons height
    headerHeight += 45; // Button height

    // Dividers
    headerHeight += 32; // Two dividers

    // Chart/Options buttons section
    headerHeight += 52; // Buttons with padding

    // Additional padding and margins
    headerHeight += 32; // Extra padding

    // Convert to screen height percentage
    double screenHeight = MediaQuery.of(context).size.height;
    double initialSize = headerHeight / screenHeight;

    // Ensure it's within bounds
    initialSize = initialSize.clamp(0.29, 0.99);

    return initialSize;
  }

  void _initializeSize() {
    setState(() {
      // For non-Overview states, use larger size
      if (ref.read(marketWatchProvider).actDeptBtn != "Overview" ||
          ref.read(marketWatchProvider).scripsize == true) {
        initSize = 0.75;
      } else {
        // For Overview state, we'll calculate this dynamically in build method
        // based on the actual content height of the header section
        initSize = 0.35; // This will be overridden in build method
      }

      // Ensure initSize is never less than minChildSize + buffer
      if (initSize < 0.29) {
        initSize = 0.29;
      }

      chartArgs = ChartArgs(
        exch: widget.wlValue.exch,
        tsym: widget.wlValue.tsym,
        token: widget.wlValue.token,
      );
    });
  }

  // Helper to check if a value is valid (non-null, non-empty, non-zero)
  bool _isValidValue(dynamic value) {
    if (value == null) return false;
    final strVal = value.toString();
    if (strVal.isEmpty || strVal == 'null') return false;
    // For numeric values, check if it's effectively zero
    final numVal = double.tryParse(strVal);
    if (numVal != null && numVal <= 0) return false;
    return true;
  }

  // Preprocess depth data - only update fields that have valid non-null, non-zero values
  // This preserves existing values from API when socket data has default "0.00" values
  void _processDepthData(GetQuotes depthData, Map<String, dynamic> socketData) {
    if (socketData['ap'] != null) depthData.ap = "${socketData['ap']}";
    // Strict guard for all price fields — rejects null and broker zero
    // defaults so stale "0.00" can never overwrite valid API data.
    if (_isValidValue(socketData['lp'])) depthData.lp = "${socketData['lp']}";
    if (_isValidValue(socketData['pc'])) depthData.pc = "${socketData['pc']}";
    if (_isValidValue(socketData['o'])) depthData.o = "${socketData['o']}";
    if (_isValidValue(socketData['l'])) depthData.l = "${socketData['l']}";
    if (_isValidValue(socketData['c'])) depthData.c = "${socketData['c']}";
    if (_isValidValue(socketData['chng'])) depthData.chng = "${socketData['chng']}";
    if (_isValidValue(socketData['h'])) depthData.h = "${socketData['h']}";
    if (socketData['poi'] != null) depthData.poi = "${socketData['poi']}";
    if (socketData['v'] != null) depthData.v = "${socketData['v']}";
    if (socketData['toi'] != null) depthData.toi = "${socketData['toi']}";
    // Ask prices (sell prices)
    if (socketData['sp1'] != null) depthData.sp1 = "${socketData['sp1']}";
    if (socketData['sp2'] != null) depthData.sp2 = "${socketData['sp2']}";
    if (socketData['sp3'] != null) depthData.sp3 = "${socketData['sp3']}";
    if (socketData['sp4'] != null) depthData.sp4 = "${socketData['sp4']}";
    if (socketData['sp5'] != null) depthData.sp5 = "${socketData['sp5']}";
    // Bid prices (buy prices)
    if (socketData['bp1'] != null) depthData.bp1 = "${socketData['bp1']}";
    if (socketData['bp2'] != null) depthData.bp2 = "${socketData['bp2']}";
    if (socketData['bp3'] != null) depthData.bp3 = "${socketData['bp3']}";
    if (socketData['bp4'] != null) depthData.bp4 = "${socketData['bp4']}";
    if (socketData['bp5'] != null) depthData.bp5 = "${socketData['bp5']}";
    // Ask quantities (sell quantities)
    if (socketData['sq1'] != null) depthData.sq1 = "${socketData['sq1']}";
    if (socketData['sq2'] != null) depthData.sq2 = "${socketData['sq2']}";
    if (socketData['sq3'] != null) depthData.sq3 = "${socketData['sq3']}";
    if (socketData['sq4'] != null) depthData.sq4 = "${socketData['sq4']}";
    if (socketData['sq5'] != null) depthData.sq5 = "${socketData['sq5']}";
    // Bid quantities (buy quantities)
    if (socketData['bq1'] != null) depthData.bq1 = "${socketData['bq1']}";
    if (socketData['bq2'] != null) depthData.bq2 = "${socketData['bq2']}";
    if (socketData['bq3'] != null) depthData.bq3 = "${socketData['bq3']}";
    if (socketData['bq4'] != null) depthData.bq4 = "${socketData['bq4']}";
    if (socketData['bq5'] != null) depthData.bq5 = "${socketData['bq5']}";
    // Totals and other fields
    if (socketData['tbq'] != null) depthData.tbq = "${socketData['tbq']}";
    if (socketData['tsq'] != null) depthData.tsq = "${socketData['tsq']}";
    // Use valid value check for 52-week high/low and circuit limits to preserve API values
    if (_isValidValue(socketData['52h'])) depthData.wk52H = "${socketData['52h']}";
    if (_isValidValue(socketData['52l'])) depthData.wk52L = "${socketData['52l']}";
    if (_isValidValue(socketData['lc'])) depthData.lc = "${socketData['lc']}";
    if (_isValidValue(socketData['uc'])) depthData.uc = "${socketData['uc']}";
    if (socketData['ltq'] != null) depthData.ltq = "${socketData['ltq']}";
    if (socketData['ltt'] != null) depthData.ltt = "${socketData['ltt']}";
    if (socketData['ft'] != null) depthData.ft = "${socketData['ft']}";
  }

  // Memoized row builder
  Widget _buildInfoRow(String title1, String value1, String title2,
      String value2, ThemesProvider theme) {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title1,
                style: _getTitleStyle(resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary))),
            SizedBox(height: context.responsive(mobile: 2.0, tablet: 3.0, desktop: 4.0)),
            Text(value1,
                style: _getValueStyle(resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary))),
            SizedBox(height: context.responsive(mobile: 2.0, tablet: 3.0, desktop: 4.0)),
            Divider(color: shadcn.Theme.of(context).colorScheme.border)
          ],
        ),
      ),
      SizedBox(width: context.responsive(mobile: 12.0, tablet: 18.0, desktop: 24.0)),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title2,
                style: _getTitleStyle(resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary))),
            SizedBox(height: context.responsive(mobile: 2.0, tablet: 3.0, desktop: 4.0)),
            Text(value2,
                style: _getValueStyle(resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary))),
            SizedBox(height: context.responsive(mobile: 2.0, tablet: 3.0, desktop: 4.0)),
            Divider(color: shadcn.Theme.of(context).colorScheme.border)
          ],
        ),
      )
    ]);
  }

  //new ui

  Widget _buildInfoRow1(
      String title1,
      String value1,
      String title2,
      String value2,
      String title3,
      String value3,
      String title4,
      String value4,
      ThemesProvider theme) {
    // Helper function to build a column or empty space
    Widget buildColumn(String title, String value, bool isEmpty) {
      if (isEmpty) {
        return const Expanded(child: SizedBox.shrink());
      }
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: MyntWebTextStyles.para(context,
                    fontWeight: MyntFonts.medium,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary))),
            SizedBox(height: context.responsive(mobile: 4.0, tablet: 5.0, desktop: 6.0)),
            Text(value,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary))),
            SizedBox(height: context.responsive(mobile: 2.0, tablet: 3.0, desktop: 4.0)),
            Divider(color: shadcn.Theme.of(context).colorScheme.border)
          ],
        ),
      );
    }

    // Check if columns are empty
    bool isCol1Empty = title1.isEmpty && value1.isEmpty;
    bool isCol2Empty = title2.isEmpty && value2.isEmpty;
    bool isCol3Empty = title3.isEmpty && value3.isEmpty;
    bool isCol4Empty = title4.isEmpty && value4.isEmpty;

    List<Widget> columns = [];

    // Add non-empty columns with appropriate spacing
    if (!isCol1Empty) {
      columns.add(buildColumn(title1, value1, false));
      if (!isCol2Empty || !isCol3Empty || !isCol4Empty) {
        columns.add(SizedBox(width: context.responsive(mobile: 8.0, tablet: 10.0, desktop: 12.0)));
      }
    }

    if (!isCol2Empty) {
      columns.add(buildColumn(title2, value2, false));
      if (!isCol3Empty || !isCol4Empty) {
        columns.add(SizedBox(width: context.responsive(mobile: 8.0, tablet: 10.0, desktop: 12.0)));
      }
    }

    if (!isCol3Empty) {
      columns.add(buildColumn(title3, value3, false));
      if (!isCol4Empty) {
        columns.add(SizedBox(width: context.responsive(mobile: 8.0, tablet: 10.0, desktop: 12.0)));
      }
    }

    if (!isCol4Empty) {
      columns.add(buildColumn(title4, value4, false));
    }

    return Row(children: columns);
  }

  // Memoized depth percentage builder
  Widget _buildDepthPercentage(String qty, String price, bool isBuy,
      MarketWatchProvider scripInfo, ThemesProvider theme) {
    final maxQty = isBuy ? scripInfo.maxBuyQty : scripInfo.maxSellQty;
    final barPercentage =
        (((int.tryParse(qty) ?? 0) / maxQty) * 100 / 100).clamp(0.0, 1.0);
    final color = isBuy ? MyntColors.profit : MyntColors.loss;

    return Stack(children: [
      Transform.flip(
        flipX: !isBuy,
        child: LinearPercentIndicator(
          lineHeight: 20.0,
          backgroundColor: resolveThemeColor(context,
              dark: MyntColors.searchBgDark, light: MyntColors.searchBg),
          percent: barPercentage,
          padding: const EdgeInsets.symmetric(horizontal: 0),
          progressColor: color.withOpacity(.2),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 1.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              " ${qty != "null" ? qty : '0'} ",
              style: _getTitleStyle(
                resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
              ),
            ),
            Text(
              " ${price != "null" ? price : '0.00'} ",
              style: _getTitleStyle(
                resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
              ),
            ),
          ],
        ),
      )
    ]);
  }

  /// Check if user has any position, holding, or open order for this token
  bool _hasPositionOrOrders(String token) {
    final portfolio = ref.read(portfolioProvider);
    final orderProv = ref.read(orderProvider);

    // Check positions
    final positions = portfolio.postionBookModel ?? [];
    final hasPosition = positions.any((pos) => pos.token == token);

    // Check holdings
    final holdings = portfolio.holdingsModel ?? [];
    final hasHolding = holdings.any((hold) {
      if (hold.exchTsym != null && hold.exchTsym!.isNotEmpty) {
        return hold.exchTsym!.any((exch) => exch.token == token);
      }
      return false;
    });

    // Check open orders
    final openOrders = orderProv.openOrder ?? [];
    final hasOrders = openOrders.any((order) => order.token == token);

    return hasPosition || hasHolding || hasOrders;
  }

  /// Get dynamic label for bottom panel - simple check
  String _getBottomPanelLabel(String token) {
    final positions = ref.read(portfolioProvider).postionBookModel ?? [];
    final hasPosition = positions.any((pos) => pos.token == token);
    return hasPosition ? "Positions & Orders" : "Holdings & Orders";
  }

  /// Build the fixed OHLC section (non-scrollable top section)
  Widget _buildFixedOHLCSection({
    required GetQuotes depthData,
    required ThemesProvider theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 20, top: 10, bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 300;
          if (isSmallScreen) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildInfoItem(theme, "Open", "${depthData.o != "null" ? depthData.o ?? 0.00 : '0.00'}")),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoItem(theme, "High", "${depthData.h != "null" ? depthData.h ?? 0.00 : '0.00'}")),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInfoItem(theme, "Low", "${depthData.l != "null" ? depthData.l ?? 0.00 : '0.00'}")),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoItem(theme, "P.Close", "${depthData.c != "null" ? depthData.c ?? 0.00 : '0.00'}")),
                  ],
                ),
              ],
            );
          } else {
            return _buildInfoRow1(
              "Open", "${depthData.o != "null" ? depthData.o ?? 0.00 : '0.00'}",
              "High", "${depthData.h != "null" ? depthData.h ?? 0.00 : '0.00'}",
              "Low", "${depthData.l != "null" ? depthData.l ?? 0.00 : '0.00'}",
              "P.Close", "${depthData.c != "null" ? depthData.c ?? 0.00 : '0.00'}",
              theme,
            );
          }
        },
      ),
    );
  }

  /// Build the scrollable market content (Bid/Ask, Avg Price, Volume, LTQ, etc.)
  /// Position/Holdings/Orders will be appended at the bottom in the main layout
  Widget _buildScrollableMarketContent({
    required MarketWatchProvider scripInfo,
    required GetQuotes depthData,
    required ThemesProvider theme,
  }) {
    final isIndexOrCommodity = widget.wlValue.instname == "UNDIND" ||
                               widget.wlValue.instname == "COM";

    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 20, top: 0, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Market Depth (Bid/Ask) section
          if (!isIndexOrCommodity) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Quantity", style: MyntWebTextStyles.para(context, fontWeight: MyntFonts.medium, color: resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary))),
                          Text("Bid", style: MyntWebTextStyles.para(context, fontWeight: MyntFonts.medium, color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildBidDepthPercentage("${depthData.bq1 ?? 0}", "${depthData.bp1 ?? 0.00}", scripInfo, theme),
                      const SizedBox(height: 6),
                      _buildBidDepthPercentage("${depthData.bq2 ?? 0}", "${depthData.bp2 ?? 0.00}", scripInfo, theme),
                      const SizedBox(height: 6),
                      _buildBidDepthPercentage("${depthData.bq3 ?? 0}", "${depthData.bp3 ?? 0.00}", scripInfo, theme),
                      const SizedBox(height: 6),
                      _buildBidDepthPercentage("${depthData.bq4 ?? 0}", "${depthData.bp4 ?? 0.00}", scripInfo, theme),
                      const SizedBox(height: 6),
                      _buildBidDepthPercentage("${depthData.bq5 ?? 0}", "${depthData.bp5 ?? 0.00}", scripInfo, theme),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Ask", style: MyntWebTextStyles.para(context, fontWeight: MyntFonts.medium, color: resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.tertiary))),
                          Text("Quantity", style: MyntWebTextStyles.para(context, fontWeight: MyntFonts.medium, color: resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildAskDepthPercentage("${depthData.sp1 ?? 0.00}", "${depthData.sq1 ?? 0}", scripInfo, theme),
                      const SizedBox(height: 6),
                      _buildAskDepthPercentage("${depthData.sp2 ?? 0.00}", "${depthData.sq2 ?? 0}", scripInfo, theme),
                      const SizedBox(height: 6),
                      _buildAskDepthPercentage("${depthData.sp3 ?? 0.00}", "${depthData.sq3 ?? 0}", scripInfo, theme),
                      const SizedBox(height: 6),
                      _buildAskDepthPercentage("${depthData.sp4 ?? 0.00}", "${depthData.sq4 ?? 0}", scripInfo, theme),
                      const SizedBox(height: 6),
                      _buildAskDepthPercentage("${depthData.sp5 ?? 0.00}", "${depthData.sq5 ?? 0}", scripInfo, theme),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text("${depthData.tbq != "null" ? depthData.tbq ?? 0 : '0'}", style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium, color: resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary))),
                    const SizedBox(width: 4),
                    Text("(${scripInfo.totBuyQtyPer.toStringAsFixed(2)}%)", style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium, color: resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary))),
                  ],
                ),
                Row(
                  children: [
                    Text("(${scripInfo.totSellQtyPer.toStringAsFixed(2)}%)", style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium, color: resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary))),
                    const SizedBox(width: 4),
                    Text("${depthData.tsq != "null" ? depthData.tsq ?? 0 : '0'}", style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium, color: resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary))),
                  ],
                ),
              ],
            ),
            if (scripInfo.totBuyQtyPer.toStringAsFixed(2) != "0.00" || scripInfo.totSellQtyPer.toStringAsFixed(2) != "0.00") ...[
              const SizedBox(height: 10),
              LinearPercentIndicator(
                lineHeight: 5.0,
                barRadius: const Radius.circular(4.0),
                backgroundColor: (scripInfo.totBuyQtyPer.toStringAsFixed(2) == "0.00" && scripInfo.totSellQtyPer.toStringAsFixed(2) == "0.00")
                    ? resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary)
                    : resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.tertiary),
                percent: scripInfo.totBuyQtyPerChng,
                padding: const EdgeInsets.symmetric(horizontal: 0),
                progressColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
              ),
              const SizedBox(height: 16),
            ],
          ],
          const SizedBox(height: 4),
          // Trading Info Section (Avg Price, Volume, LTQ, etc.)
          if (!isIndexOrCommodity) ...[
            const SizedBox(height: 12),
            Column(
              children: [
                _buildCasIndicativeRow(),
                data("Avg Price", "${depthData.ap ?? 0.00}", theme),
                data("Volume", "${depthData.v != "null" ? depthData.v ?? 0.00 : '0'}", theme),
                data("LTQ", "${depthData.ltq != "null" ? depthData.ltq ?? 0.00 : '0'}", theme),
                data("LTT", depthData.ltt != "null" ? (depthData.ltt ?? "--") : "--", theme),
                data("52 Weeks High-Low", "${(depthData.wk52H != "null" && depthData.wk52H != null) ? depthData.wk52H : 0.00} - ${(depthData.wk52L != "null" && depthData.wk52L != null) ? depthData.wk52L : 0.00}", theme),
                data("DPR", "${depthData.uc != "null" ? depthData.uc ?? 0.00 : '0.00'} - ${depthData.lc != "null" ? depthData.lc ?? 0.00 : '0.00'}", theme),
                if (depthData.seg != "EQT") ...[
                  data("Open Interest - OI", "${depthData.oi != "null" ? depthData.oi ?? 0.00 : '0'}", theme),
                  data("Change in OI", "${depthData.poi != "null" ? depthData.poi ?? 0.00 : '0'}", theme),
                ],
              ],
            ),
            // Returns grid
            if (scripInfo.returnsGridview.isNotEmpty) ...[
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  const itemWidth = 120.0;
                  const spacing = 12.0;
                  final availableWidth = constraints.maxWidth;
                  final itemsPerRow = ((availableWidth + spacing) / (itemWidth + spacing)).floor();
                  final calculatedWidth = itemsPerRow > 0 ? (availableWidth - (spacing * (itemsPerRow - 1))) / itemsPerRow : itemWidth;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 10,
                    children: List.generate(scripInfo.returnsGridview.length, (index) {
                      return SizedBox(
                        width: calculatedWidth.clamp(100.0, 150.0),
                        child: shadcn.Card(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${scripInfo.returnsGridview[index]['percent']}%",
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.medium,
                                  color: (scripInfo.returnsGridview[index]['percent'].toString().startsWith('-'))
                                      ? resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss)
                                      : (scripInfo.returnsGridview[index]['percent'].toString() != '0' && scripInfo.returnsGridview[index]['percent'].toString() != '0.00')
                                          ? resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit)
                                          : resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  "${scripInfo.returnsGridview[index]['duration']}",
                                  textAlign: TextAlign.center,
                                  style: MyntWebTextStyles.para(context, fontWeight: MyntFonts.medium, color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
          // Expandable Futures Section
          Column(
            children: [
              const ListDivider(),
              if (scripInfo.getOptionawait(widget.wlValue.exch, widget.wlValue.token))
                _buildExpandableFuturesSection(scripInfo, theme, depthData),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return RepaintBoundary(
      child: PopScope(
          canPop: true, // Allows back navigation
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return; // If system handled back, do nothing

            await ref.read(marketWatchProvider).chngDephBtn("Overview");

            // Initialize and cancel the timer
            ConstantName.charttimer =
                Timer.periodic(const Duration(milliseconds: 0), (timer) {});
            ConstantName.charttimer!.cancel();

            await ref
                .read(marketWatchProvider)
                .requestWSOptChain(context: context, isSubscribe: false);

            // Release the depth panel's claim through the owner registry. A
            // raw "ud" here bypassed it and cut the depth feed a chart or
            // Insta Options still showed for the same scrip.
            await ref
                .read(marketWatchProvider)
                .unsubscribeFromDepthData(context: context);

            if (ref.read(marketWatchProvider).actDeptBtn == "Chart") {
              // Additional logic if needed
            }

            Navigator.of(context).pop(); // Proceed with back navigation
          },
          child: SafeArea(
            child: Consumer(builder: (context, WidgetRef ref, _) {
              final depthData = ref.watch(marketWatchProvider).getQuotes!;
              final scripInfo = ref.watch(marketWatchProvider);
              final theme = ref.read(themeProvider);
              final instname = widget.wlValue.instname.toString() ?? "";
              final isIndexOrCommodity =
                  instname == "UNDIND" || instname == "COM";

              // PERFORMANCE FIX: Use ref.read() not ref.watch() for stream access
              // The stream itself is reactive - watching provider causes double rebuilds
              return StreamBuilder<Map>(
                  stream: ref.read(websocketProvider).socketDataStream,
                  builder: (context, snapshot) {
                    // CRITICAL FIX: Fall back to existing socket data if stream hasn't emitted yet
                    // Broadcast streams don't replay past events, so if data was emitted
                    // before this widget subscribed, snapshot.data would be null
                    final socketDatas = snapshot.data ?? ref.read(websocketProvider).socketDatas;

                    // Update depth data with WebSocket data if available.
                    // Only merge when the shared quote object actually belongs to
                    // the currently-selected scrip. During a symbol switch,
                    // `regtoken` flips to the new scrip immediately (widget
                    // rebuild) but `getQuotes` still holds the PREVIOUS scrip
                    // until its REST quote lands — merging the new scrip's ticks
                    // into the old object produced a mixed ladder (row 1 from one
                    // symbol, rows 2-5 from another). Gating on the token keeps
                    // every render consistent to a single scrip.
                    if (depthData.token?.toString() == regtoken &&
                        socketDatas.containsKey(regtoken)) {
                      _processDepthData(depthData, socketDatas[regtoken]);

                      if (scripInfo.actDeptBtn == "Overview") {
                        if ((depthData.exch == "NSE" ||
                                depthData.exch == "BSE") &&
                            (depthData.instname != "UNDIND")) {
                          scripInfo.techDataCalc("${depthData.lp}");
                        }
                        if (widget.wlValue.instname != "UNDIND" &&
                            widget.wlValue.instname != "COM") {
                          scripInfo.scripQtyCal();
                        }
                      }
                    }

                    // Calculate dynamic initial size for Overview state
                    if (scripInfo.actDeptBtn == "Overview") {
                      initSize = _calculateDynamicInitialSize(context);
                    }

                    // Ensure initSize is safe before building DraggableScrollableSheet
                    if (initSize < 0.29) {
                      initSize = 0.29;
                    }
                    return Scaffold(
                      body: Container(
                        decoration: BoxDecoration(
                          color: resolveThemeColor(context,
                              dark: MyntColors.backgroundColorDark,
                              light: MyntColors.backgroundColor),
                        ),
                        child: Column(
                          children: [
                            // Sticky header (outside the scrollable area)
                            if (scripInfo.actDeptBtn == "Overview")
                              // Container(
                              //   width: double.infinity,
                              //   padding: const EdgeInsets.symmetric(
                              //       horizontal: 10, vertical: 10),
                              //   decoration: const BoxDecoration(
                              //       // color:
                              //       //     const Color(0xffa3a3a3).withOpacity(0.2),
                              //       // border: Border.all(
                              //       //     color: theme.isDarkMode
                              //       //         ? WebDarkColors.divider
                              //       //         : MyntColors.divider),
                              //       ),
                              //   child: Row(
                              //     mainAxisAlignment: MainAxisAlignment.start,
                              //     children: [
                              //       // Text(
                              //       //   "Scrip info",
                              //       //   style: MyntWebTextStyles.body(context,
                              //       //       fontWeight: MyntFonts.bold),
                              //       // ),
                              //       // const Spacer(),
                              //       // Tooltip(
                              //       //   message: "Set Alert",
                              //       //   child: Material(
                              //       //     color: Colors.transparent,
                              //       //     shape: const CircleBorder(),
                              //       //     child: InkWell(
                              //       //       customBorder: const CircleBorder(),
                              //       //       splashColor: theme.isDarkMode
                              //       //           ? Colors.white.withOpacity(0.15)
                              //       //           : Colors.black.withOpacity(0.15),
                              //       //       highlightColor: theme.isDarkMode
                              //       //           ? Colors.white.withOpacity(0.08)
                              //       //           : Colors.black.withOpacity(0.08),
                              //       //       onTap: () {
                              //       //         showDialog(
                              //       //           context: context,
                              //       //           barrierDismissible: true,
                              //       //           builder: (BuildContext dialogContext) {
                              //       //             return SetAlertWeb(
                              //       //               depthdata: depthData,
                              //       //               wlvalue: widget.wlValue,
                              //       //             );
                              //       //           },
                              //       //         );
                              //       //       },
                              //       //       child: const Padding(
                              //       //         padding: EdgeInsets.all(6),
                              //       //         child: Icon(
                              //       //           Icons.notifications_none_outlined,
                              //       //           size: 20,
                              //       //         ),
                              //       //       ),
                              //       //     ),
                              //       //   ),
                              //       // ),
                              //     ],
                              //   ),
                              // ),
                            // if (scripInfo.actDeptBtn == "Overview" &&
                            //     !scripInfo.scripDepthloader &&
                            //     widget.wlValue.instname != "UNDIND" &&
                            //     widget.wlValue.instname != "COM")
                            //   Padding(
                            //     padding: const EdgeInsets.symmetric(
                            //         horizontal: 10, vertical: 10),
                            //     child: Row(
                            //       children: [
                            //         Expanded(
                            //           child: MyntButton(
                            //             label: "Buy",
                            //             backgroundColor: resolveThemeColor(
                            //                 context,
                            //                 dark: MyntColors.primary,
                            //                 light: MyntColors.primary),
                            //             onPressed: () async {
                            //               await placeOrderInput(scripInfo,
                            //                   context, depthData, true);
                            //             },
                            //           ),
                            //         ),
                            //         const SizedBox(width: 12),
                            //         Expanded(
                            //           child: MyntButton(
                            //             label: "Sell",
                            //             backgroundColor: resolveThemeColor(
                            //                 context,
                            //                 dark: MyntColors.tertiary,
                            //                 light: MyntColors.tertiary),
                            //             onPressed: () async {
                            //               await placeOrderInput(scripInfo,
                            //                   context, depthData, false);
                            //             },
                            //           ),
                            //         ),
                            //       ],
                            //     ),
                            //   ),
                            Expanded(
                              child: scripInfo.actDeptBtn == "Overview"
                                  // Resizable split view with grab handle for Market Info and Positions/Orders
                                  ? ResizablePanelSplitter(
                                      topSectionLabel: "Market Info",
                                      // Top panel: Market Info (OHLC + Bid/Ask + trading info)
                                      topChild: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // OHLC section
                                          _buildFixedOHLCSection(depthData: depthData, theme: theme),
                                          // Scrollable market data content
                                          _buildScrollableMarketContent(
                                            scripInfo: scripInfo,
                                            depthData: depthData,
                                            theme: theme,
                                          ),
                                        ],
                                      ),
                                      // Bottom panel: Positions & Orders
                                      bottomChild: PositionHoldingsCardWeb(
                                        token: widget.wlValue.token,
                                        exchange: widget.wlValue.exch,
                                        tsym: widget.wlValue.tsym,
                                      ),
                                      bottomSectionLabel: _getBottomPanelLabel(widget.wlValue.token),
                                      initialBottomHeight: 280.0,
                                      minTopHeight: 100.0,
                                      minBottomHeight: 60.0,
                                      maxBottomHeight: 600.0,
                                      // Only show bottom panel if user has positions/holdings/orders and not an index/commodity
                                      showBottomPanel: widget.wlValue.instname != "UNDIND" &&
                                          widget.wlValue.instname != "COM" &&
                                          _hasPositionOrOrders(widget.wlValue.token),
                                      onExpansionChanged: (isExpanded) {
                                        setState(() => _isBottomSheetExpanded = isExpanded);
                                      },
                                    )
                                  // Existing layout for other states (Fundamental, Chart, Future, Set Alert)
                                  : ScrollConfiguration(
                                      behavior: const MaterialScrollBehavior()
                                          .copyWith(scrollbars: false),
                                      child: RawScrollbar(
                                        controller: _scrollController,
                                        thumbVisibility: true,
                                        thickness: 6,
                                        radius: const Radius.circular(0),
                                        thumbColor: resolveThemeColor(context,
                                                dark: MyntColors.textSecondaryDark
                                                    .withOpacity(0.5),
                                                light: MyntColors.textSecondary)
                                            .withOpacity(0.5),
                                        child: SingleChildScrollView(
                                          controller: _scrollController,
                                          padding: EdgeInsets.zero,
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                          /*
                                      Symbol and price section (temporarily commented)
                                      Container(
                                          decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                              topRight: Radius.circular(16),
                                            ),
                                            color: theme.isDarkMode
                                                ? WebDarkColors.background
                                                : MyntColors.background,
                                            boxShadow: _hasScrolled
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.1),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    )
                                                  ]
                                                : [],
                                          ),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: <Widget>[
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 14),
                                                    child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          // ... symbol, info icon, ltp, change ...
                                                        ])),
                                      */

                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10),
                                            child: Column(children: [
                                              // Row(
                                              //     mainAxisAlignment:
                                              //         MainAxisAlignment
                                              //             .spaceBetween,
                                              //     children: [
                                              //       Row(children: [
                                              //         // CustomExchBadge(
                                              //         //     exch: widget
                                              //         //         .wlValue
                                              //         //         .exch),
                                              //         // Text(
                                              //         //     "  ${widget.wlValue.expDate}",
                                              //         //     style: textStyle(
                                              //         //         !theme.isDarkMode
                                              //         //             ? colors
                                              //         //                 .colorBlack
                                              //         //             : colors
                                              //         //                 .colorWhite,
                                              //         //         12,
                                              //         //         FontWeight
                                              //         //             .w600)),
                                              //         // SizedBox(
                                              //         //   width: 4,
                                              //         // ),
                                              //         TextWidget.paraText(
                                              //             text: "${(double.tryParse(depthData.chng ?? '0.00') ?? 0.00).toStringAsFixed(2)} (${(double.tryParse(depthData.pc ?? '0.00') ?? 0.00).toStringAsFixed(2)}%)",
                                              //             color:  !theme.isDarkMode
                                              //                     ? colors
                                              //                         .colorBlack
                                              //                     : colors
                                              //                         .colorWhite,
                                              //             theme: theme.isDarkMode,
                                              //             fw: 3)
                                              //       ]),
                                              //     ]),
                                              /*
                                                    if (!scripInfo.scripDepthloader &&
                                                        widget.wlValue.instname !=
                                                            "UNDIND" &&
                                                        widget.wlValue.instname !=
                                                            "COM")
                                                      scripInfo.actDeptBtn ==
                                                              "Set Alert"
                                                          ? Container()
                                                          : Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal: 0,
                                                                      vertical: 16),
                                                              child: Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Expanded(
                                                                        child:
                                                                            InkWell(
                                                                      onTap:
                                                                          () async {
                                                                        await placeOrderInput(
                                                                            scripInfo,
                                                                            context,
                                                                            depthData,
                                                                            true);
                                                                      },
                                                                      child:
                                                                          Container(
                                                                        height: 45,
                                                                        decoration: BoxDecoration(
                                                                            color: theme.isDarkMode
                                                                                ? WebDarkColors
                                                                                    .primary
                                                                                : MyntColors
                                                                                    .primary,
                                                                            borderRadius:
                                                                                BorderRadius.circular(
                                                                                    5)),
                                                                        child: Center(
                                                                            child: Text(
                                                                                "Buy",
                                                                                style: MyntWebTextStyles.sub(
                                                                                    isDarkTheme: theme.isDarkMode,
                                                                                    color: WebDarkColors.textPrimary,
                                                                                    fontWeight: MyntFonts.semiBold,
                                                                                   ))),
                                                                      ),
                                                                    )),
                                                                    const SizedBox(
                                                                        width: 16),
                                                                    Expanded(
                                                                      child: InkWell(
                                                                          onTap:
                                                                              () async {
                                                                            await placeOrderInput(
                                                                                scripInfo,
                                                                                context,
                                                                                depthData,
                                                                                false);
                                                                          },
                                                                          child: Container(
                                                                              height:
                                                                                  45,
                                                                              decoration: BoxDecoration(
                                                                                  color: WebDarkColors
                                                                                      .error,
                                                                                  borderRadius: BorderRadius.circular(
                                                                                      5)),
                                                                              child: Center(
                                                                                  child:
                                                                                      Text("Sell", style: MyntWebTextStyles.sub(isDarkTheme: theme.isDarkMode, color: WebDarkColors.textPrimary, fontWeight: MyntFonts.semiBold,))))),
                                                                    ),
                                                                  ])),
                              
                                                    if (!scripInfo.scripDepthloader &&
                                                        widget.wlValue.instname !=
                                                            "UNDIND" &&
                                                        widget.wlValue.instname !=
                                                            "COM")
                                                      const ListDivider(),
                                                    if (!scripInfo.scripDepthloader &&
                                                        widget.wlValue.instname !=
                                                            "UNDIND" &&
                                                        widget.wlValue.instname !=
                                                            "COM")
                                                      const ListDivider(),
                                                    */
                                              // Chart button above tabs - Now in Column layout
                                              // Container(
                                              //     padding: const EdgeInsets
                                              //         .symmetric(
                                              //         horizontal: 14,
                                              //         vertical: 8),
                                              //     child: Column(
                                              //         crossAxisAlignment:
                                              //             CrossAxisAlignment
                                              //                 .stretch,
                                              //         children: [

                                              //           if (scripInfo
                                              //               .getOptionawait(
                                              //                   widget.wlValue
                                              //                       .exch,
                                              //                   widget.wlValue
                                              //                       .token))
                                              //             const SizedBox(
                                              //                 height: 8),

                                              //           // Future Button (conditional)
                                              //           if (scripInfo
                                              //               .getOptionawait(
                                              //                   widget.wlValue
                                              //                       .exch,
                                              //                   widget.wlValue
                                              //                       .token))
                                              //             InkWell(
                                              //               onTap: () async {
                                              //                 scripInfo
                                              //                     .singlePageloader(
                                              //                         true);

                                              //                 await scripInfo.requestWSFut(
                                              //                     context:
                                              //                         context,
                                              //                     isSubscribe:
                                              //                         true);

                                              //                 if (mounted) {
                                              //                   await Navigator
                                              //                       .pushNamed(
                                              //                           context,
                                              //                           Routes
                                              //                               .futureScreen,
                                              //                           arguments: {
                                              //                         "depthdata":
                                              //                             depthData,
                                              //                         "wlvalue":
                                              //                             widget
                                              //                                 .wlValue
                                              //                       });
                                              //                 }

                                              //                 scripInfo
                                              //                     .singlePageloader(
                                              //                         false);
                                              //               },
                                              //               child: Container(
                                              //                 height: 36,
                                              //                 decoration: BoxDecoration(
                                              //                     color: theme
                                              //                             .isDarkMode
                                              //                         ? const Color(
                                              //                                 0xffB5C0CF)
                                              //                             .withOpacity(
                                              //                                 .15)
                                              //                         : const Color(
                                              //                             0xffF1F3F8),
                                              //                     borderRadius:
                                              //                         BorderRadius
                                              //                             .circular(
                                              //                                 8)),
                                              //                 child: Row(
                                              //                   mainAxisAlignment:
                                              //                       MainAxisAlignment
                                              //                           .center,
                                              //                   children: [
                                              //                     SvgPicture
                                              //                         .asset(
                                              //                       assets
                                              //                           .optChainIcon,
                                              //                       color: theme.isDarkMode
                                              //                           ? colors
                                              //                               .colorWhite
                                              //                           : colors
                                              //                               .colorBlack,
                                              //                       width: 16,
                                              //                       height: 16,
                                              //                     ),
                                              //                     const SizedBox(
                                              //                         width: 6),
                                              //                     Text(
                                              //                       "Future",
                                              //                       style: textStyle(
                                              //                           theme.isDarkMode
                                              //                               ? colors
                                              //                                   .colorWhite
                                              //                               : colors
                                              //                                   .colorBlack,
                                              //                           13,
                                              //                           FontWeight
                                              //                               .w500),
                                              //                     ),
                                              //                   ],
                                              //                 ),
                                              //               ),
                                              //             ),

                                              //           if (scripInfo
                                              //               .getOptionawait(
                                              //                   widget.wlValue
                                              //                       .exch,
                                              //                   widget.wlValue
                                              //                       .token))
                                              //             const SizedBox(
                                              //                 height: 8),

                                              //           // Fundamental Button (conditional)
                                              //           if (widget.wlValue
                                              //                       .exch ==
                                              //                   'NSE' ||
                                              //               widget.wlValue
                                              //                       .exch ==
                                              //                   'BSE')
                                              //             InkWell(
                                              //               onTap: () async {
                                              //                 if (_isDisposed)
                                              //                   return;

                                              //                 scripInfo
                                              //                     .singlePageloader(
                                              //                         true);

                                              //                 try {
                                              //                   // Pre-fetch data before navigation
                                              //                   if (scripInfo
                                              //                               .fundamentalData ==
                                              //                           null ||
                                              //                       scripInfo
                                              //                               .fundamentalData
                                              //                               ?.msg ==
                                              //                           "no data found") {
                                              //                     await scripInfo
                                              //                         .fetchFundamentalData(
                                              //                             tradeSym:
                                              //                                 "${widget.wlValue.exch}:${widget.wlValue.tsym}");
                                              //                   }

                                              //                   if (!mounted)
                                              //                     return;

                                              //                   if (scripInfo
                                              //                               .fundamentalData !=
                                              //                           null &&
                                              //                       scripInfo
                                              //                               .fundamentalData
                                              //                               ?.msg !=
                                              //                           "no data found") {
                                              //                     // Reset state before navigation
                                              //                     await scripInfo
                                              //                         .chngDephBtn(
                                              //                             "Overview");

                                              //                     await Navigator
                                              //                         .pushNamed(
                                              //                       context,
                                              //                       Routes
                                              //                           .fundamentalDetail,
                                              //                       arguments: {
                                              //                         "wlValue":
                                              //                             widget
                                              //                                 .wlValue,
                                              //                         "depthData":
                                              //                             depthData,
                                              //                       },
                                              //                     );

                                              //                     // Reset state after navigation
                                              //                     if (mounted &&
                                              //                         !_isDisposed) {
                                              //                       await scripInfo
                                              //                           .chngDephBtn(
                                              //                               "Overview");
                                              //                     }
                                              //                   } else {
                                              //                     if (!mounted)
                                              //                       return;
                                              //                     ScaffoldMessenger.of(
                                              //                             context)
                                              //                         .showSnackBar(
                                              //                       const SnackBar(
                                              //                         content: Text(
                                              //                             'No fundamental data available'),
                                              //                         duration: Duration(
                                              //                             seconds:
                                              //                                 2),
                                              //                       ),
                                              //                     );
                                              //                   }
                                              //                 } finally {
                                              //                   if (mounted &&
                                              //                       !_isDisposed) {
                                              //                     scripInfo
                                              //                         .singlePageloader(
                                              //                             false);
                                              //                   }
                                              //                 }
                                              //               },
                                              //               child: Container(
                                              //                 height: 36,
                                              //                 decoration: BoxDecoration(
                                              //                     color: theme
                                              //                             .isDarkMode
                                              //                         ? const Color(
                                              //                                 0xffB5C0CF)
                                              //                             .withOpacity(
                                              //                                 .15)
                                              //                         : const Color(
                                              //                             0xffF1F3F8),
                                              //                     borderRadius:
                                              //                         BorderRadius
                                              //                             .circular(
                                              //                                 8)),
                                              //                 child: Row(
                                              //                   mainAxisAlignment:
                                              //                       MainAxisAlignment
                                              //                           .center,
                                              //                   children: [
                                              //                     SvgPicture
                                              //                         .asset(
                                              //                       assets
                                              //                           .dInfo,
                                              //                       color: theme.isDarkMode
                                              //                           ? colors
                                              //                               .colorWhite
                                              //                           : colors
                                              //                               .colorBlack,
                                              //                       width: 16,
                                              //                       height: 16,
                                              //                     ),
                                              //                     const SizedBox(
                                              //                         width: 6),
                                              //                     Text(
                                              //                       "Fundamental",
                                              //                       style: textStyle(
                                              //                           theme.isDarkMode
                                              //                               ? colors
                                              //                                   .colorWhite
                                              //                               : colors
                                              //                                   .colorBlack,
                                              //                           13,
                                              //                           FontWeight
                                              //                               .w500),
                                              //                     ),
                                              //                   ],
                                              //                 ),
                                              //               ),
                                              //             ),

                                              //           if (widget.wlValue
                                              //                       .exch ==
                                              //                   'NSE' ||
                                              //               widget.wlValue
                                              //                       .exch ==
                                              //                   'BSE')
                                              //             const SizedBox(
                                              //                 height: 8),

                                              //           // Set Alert Button
                                              //         ])),

                                              // const SizedBox(height: 8),
                                              // Container(
                                              //     padding: const EdgeInsets.only(
                                              //         left: 14, top: 8, bottom: 8),
                                              //     height: 52,
                                              //     decoration: BoxDecoration(
                                              //         border: Border(
                                              //             bottom: BorderSide(
                                              //                 color: theme.isDarkMode
                                              //                     ? colors
                                              //                         .darkColorDivider
                                              //                     : colors.colorDivider,
                                              //                 width: 0),
                                              //             top: BorderSide(
                                              //                 color: theme.isDarkMode
                                              //                     ? colors
                                              //                         .darkColorDivider
                                              //                     : colors.colorDivider,
                                              //                 width: 0))),
                                              //     child: ListView.separated(
                                              //         scrollDirection: Axis.horizontal,
                                              //         itemCount:
                                              //             scripInfo.depthBtns.length,
                                              //         itemBuilder: (BuildContext context,
                                              //             int index) {
                                              //           return ElevatedButton(
                                              //               onPressed: () async {
                                              //                 scripInfo
                                              //                     .singlePageloader(true);

                                              //                 setState(() {
                                              //                   initSize =
                                              //                       scripInfo.depthBtns[
                                              //                               index]
                                              //                           [
                                              //                           'btnName'] ==
                                              //                       "Chart"
                                              //                   ? .40
                                              //                   : .99;

                                              //                   scripInfo.chngDephBtn(
                                              //                       scripInfo.depthBtns[
                                              //                               index]
                                              //                           [
                                              //                           'btnName']);
                                              //                 });

                                              //                 if (scripInfo.depthBtns[
                                              //                         index]['btnName'] ==
                                              //                     "Chart") {
                                              //                   Navigator.pop(context);

                                              //                   if (currentRouteName ==
                                              //                       Routes.searchScrip) {
                                              //                     scripInfo
                                              //                         .requestMWScrip(
                                              //                             context:
                                              //                                 context,
                                              //                             isSubscribe:
                                              //                                 true);
                                              //                     scripInfo.searchClear();
                                              //                     scripInfo
                                              //                         .setpageName("");
                                              //                     Navigator.pop(context);
                                              //                     currentRouteName =
                                              //                         'homeScreen';
                                              //                   }

                                              //                   userProfile
                                              //                       .setChartdialog(true);

                                              //                   scripInfo.setChartScript(
                                              //                       widget.wlValue.exch,
                                              //                       widget.wlValue.token,
                                              //                       widget.wlValue.tsym);
                                              //                 } else if (scripInfo
                                              //                             .depthBtns[
                                              //                         index]['btnName'] ==
                                              //                     "Option") {
                                              //                   scripInfo
                                              //                       .singlePageloader(
                                              //                           true);

                                              //                   // First set up the option script data
                                              //                   scripInfo.setOptionScript(
                                              //                       context,
                                              //                       widget.wlValue.exch,
                                              //                       widget.wlValue.token,
                                              //                       widget.wlValue.tsym);

                                              //                   // Wait a small amount of time to ensure data is processed
                                              //                   await Future.delayed(const Duration(milliseconds: 100));

                                              //                   // Then navigate to the option chain screen
                                              //                   if (mounted) {
                                              //                   Navigator.pop(context);
                                              //                   Navigator.pushNamed(
                                              //                       context,
                                              //                       Routes.optionChain,
                                              //                       arguments:
                                              //                           widget.wlValue);
                                              //                   }
                                              //                 } else if (scripInfo
                                              //                             .depthBtns[
                                              //                         index]['btnName'] ==
                                              //                     "Future") {
                                              //                   await scripInfo
                                              //                       .requestWSFut(
                                              //                           context: context,
                                              //                           isSubscribe:
                                              //                               true);
                                              //                 } else if (scripInfo
                                              //                         .actDeptBtn ==
                                              //                     "Overview") {
                                              //                   await ref.watch(
                                              //                           websocketProvider)
                                              //                       .establishConnection(
                                              //                           channelInput:
                                              //                               "${depthData.exch}|${depthData.token}",
                                              //                           task: "d",
                                              //                           context: context);
                                              //                 } else if (scripInfo
                                              //                         .actDeptBtn ==
                                              //                     "Fundamental") {
                                              //                   scripInfo.chngshareHold(
                                              //                       "Promoter Holding");
                                              //                 }

                                              //                 scripInfo.singlePageloader(
                                              //                     false);
                                              //               },
                                              //               style:
                                              //                   ElevatedButton.styleFrom(
                                              //                       elevation: 0,
                                              //                       padding: const EdgeInsets.symmetric(
                                              //                           horizontal: 12,
                                              //                           vertical: 0),
                                              //                       backgroundColor: theme
                                              //                               .isDarkMode
                                              //                           ? scripInfo.actDeptBtn ==
                                              //                                   scripInfo.depthBtns[index][
                                              //                                       'btnName']
                                              //                               ? colors
                                              //                                   .colorbluegrey
                                              //                               : const Color(
                                              //                                       0xffB5C0CF)
                                              //                                   .withOpacity(
                                              //                                       .15)
                                              //                           : scripInfo.actDeptBtn ==
                                              //                                   scripInfo.depthBtns[index]
                                              //                                       [
                                              //                                       'btnName']
                                              //                               ? const Color(
                                              //                                   0xff000000)
                                              //                               : const Color(
                                              //                                   0xffF1F3F8),
                                              //                       shape:
                                              //                           const StadiumBorder()),
                                              //               child: Row(children: [
                                              //                 SvgPicture.asset(
                                              //                   "${scripInfo.depthBtns[index]['imgPath']}",
                                              //                   color: theme.isDarkMode
                                              //                       ? Color(scripInfo
                                              //                                   .actDeptBtn ==
                                              //                               scripInfo.depthBtns[index]
                                              //                                   [
                                              //                                   'btnName']
                                              //                           ? 0xff000000
                                              //                           : 0xffffffff)
                                              //                       : Color(scripInfo
                                              //                                   .actDeptBtn ==
                                              //                               scripInfo.depthBtns[index]
                                              //                                   [
                                              //                                   'btnName']
                                              //                           ? 0xffffffff
                                              //                           : 0xff000000),
                                              //                 ),
                                              //                 const SizedBox(width: 8),
                                              //                 TextWidget.paraText(
                                              //                     text: "${scripInfo.depthBtns[index]['btnName']}",
                                              //                     color: theme.isDarkMode
                                              //                             ? Color(scripInfo.actDeptBtn == scripInfo.depthBtns[index]['btnName']
                                              //                                 ? 0xff000000
                                              //                                 : 0xffffffff)
                                              //                             : Color(scripInfo.actDeptBtn == scripInfo.depthBtns[index]['btnName']
                                              //                                 ? 0xffffffff
                                              //                                 : 0xff000000),
                                              //                     theme: theme.isDarkMode,
                                              //                     fw: 1)
                                              //               ]));
                                              //         },
                                              //         separatorBuilder:
                                              //             (BuildContext context,
                                              //                 int index) {
                                              //           return const SizedBox(width: 10);
                                              //         })),
                                            ]),
                                          ),
                                          if (scripInfo.scripDepthloader)
                                            Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.only(top: 120),
                                                child:
                                                    MyntLoader.simple(),
                                              ),
                                            ),
                                          const SizedBox.shrink(),
                                          /*
                                      Chart and Options buttons row (temporarily commented)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 8, bottom: 16),
                                        child: Row(
                                          children: [
                                            // Chart button ...
                                            // Options button ...
                                          ],
                                        ),
                                      ),
                                      */
                                          if (scripInfo.actDeptBtn ==
                                              "Overview") ...[
                                            // Position/Holdings card at the top
                                            if (widget.wlValue.instname !=
                                                    "UNDIND" &&
                                                widget.wlValue.instname !=
                                                    "COM")
                                              PositionHoldingsCardWeb(
                                                token: widget.wlValue.token,
                                                exchange: widget.wlValue.exch,
                                                tsym: widget.wlValue.tsym,
                                              ),
                                            Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 15,
                                                            right: 20,
                                                            top: 10,
                                                            bottom: 10),
                                                    child: Column(children: [
                                                      // Old 2-column layout - commented out
                                                      // _buildInfoRow(
                                                      //     "Open",
                                                      //     "${depthData.o != "null" ? depthData.o ?? 0.00 : '0.00'}",
                                                      //     "Close",
                                                      //     "${depthData.c != "null" ? depthData.c ?? 0.00 : '0.00'}",
                                                      //     theme),

                                                      // Responsive 4-column layout (2x2 on small screens)
                                                      LayoutBuilder(
                                                        builder: (context,
                                                            constraints) {
                                                          // Use 2x2 layout if width is less than 600px
                                                          final isSmallScreen =
                                                              constraints
                                                                      .maxWidth <
                                                                  300;

                                                          if (isSmallScreen) {
                                                            // 2 rows of 2 columns each
                                                            return Column(
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child:
                                                                          _buildInfoItem(
                                                                        theme,
                                                                        "Open",
                                                                        "${depthData.o != "null" ? depthData.o ?? 0.00 : '0.00'}",
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            12),
                                                                    Expanded(
                                                                      child:
                                                                          _buildInfoItem(
                                                                        theme,
                                                                        "High",
                                                                        "${depthData.h != "null" ? depthData.h ?? 0.00 : '0.00'}",
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                    height: 12),
                                                                Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child:
                                                                          _buildInfoItem(
                                                                        theme,
                                                                        "Low",
                                                                        "${depthData.l != "null" ? depthData.l ?? 0.00 : '0.00'}",
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            12),
                                                                    Expanded(
                                                                      child:
                                                                          _buildInfoItem(
                                                                        theme,
                                                                        "P.Close",
                                                                        "${depthData.c != "null" ? depthData.c ?? 0.00 : '0.00'}",
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            );
                                                          } else {
                                                            // 1 row of 4 columns for larger screens
                                                            return _buildInfoRow1(
                                                                "Open",
                                                                "${depthData.o != "null" ? depthData.o ?? 0.00 : '0.00'}",
                                                                "High",
                                                                "${depthData.h != "null" ? depthData.h ?? 0.00 : '0.00'}",
                                                                "Low",
                                                                "${depthData.l != "null" ? depthData.l ?? 0.00 : '0.00'}",
                                                                "P.Close",
                                                                "${depthData.c != "null" ? depthData.c ?? 0.00 : '0.00'}",
                                                                theme);
                                                          }
                                                        },
                                                      ),
                                                      const SizedBox(height: 4),
                                                      // Low-High section commented out since now included in 4-column layout above
                                                      // if (depthData.l != "null" &&
                                                      //     depthData.h !=
                                                      //         "null" &&
                                                      //     double.parse(depthData
                                                      //             .h
                                                      //             .toString()) >
                                                      //         0 &&
                                                      //     depthData.l !=
                                                      //         depthData
                                                      //             .h) ...[
                                                      //   Text("Low - High",
                                                      //       style: textStyle(
                                                      //           const Color(
                                                      //               0xff666666),
                                                      //           12,
                                                      //           FontWeight
                                                      //               .w500)),
                                                      //   const SizedBox(
                                                      //       height: 4),
                                                      //   lowHighBar(
                                                      //       "${depthData.l ?? 0.00}",
                                                      //       "${depthData.h ?? 0.00}",
                                                      //       "${depthData.lp ?? depthData.c ?? 0.00}",
                                                      //       theme),
                                                      //   const SizedBox(
                                                      //       height: 2),
                                                      //   Divider(
                                                      //       color: theme.isDarkMode
                                                      //           ? colors
                                                      //               .darkColorDivider
                                                      //           : colors
                                                      //               .colorDivider),
                                                      // ] else ...[
                                                      //   _buildInfoRow(
                                                      //       "Low",
                                                      //       "${depthData.l}",
                                                      //       "High",
                                                      //       "${depthData.h}",
                                                      //       theme),
                                                      // ],

                                                      // Keep the Low-High bar for visual representation
                                                      // if (depthData.l != "null" &&
                                                      //     depthData.h !=
                                                      //         "null" &&
                                                      //     double.parse(depthData
                                                      //             .h
                                                      //             .toString()) >
                                                      //         0 &&
                                                      //     depthData.l !=
                                                      //         depthData
                                                      //             .h) ...[
                                                      //   Text("Low - High",
                                                      //       style: textStyle(
                                                      //           const Color(
                                                      //               0xff666666),
                                                      //           12,
                                                      //           FontWeight
                                                      //               .w500)),
                                                      //   const SizedBox(
                                                      //       height: 4),
                                                      //   lowHighBar(
                                                      //       "${depthData.l ?? 0.00}",
                                                      //       "${depthData.h ?? 0.00}",
                                                      //       "${depthData.lp ?? depthData.c ?? 0.00}",
                                                      //       theme),
                                                      //   const SizedBox(
                                                      //       height: 2),
                                                      //   Divider(
                                                      //       color: theme.isDarkMode
                                                      //           ? colors
                                                      //               .darkColorDivider
                                                      //           : colors
                                                      //               .colorDivider),
                                                      // ],
                                                      // Removed old 52 WEEKS HIGH-LOW and DAILY PRICE RANGE section since it's now above
                                                      if (widget.wlValue
                                                                  .instname !=
                                                              "UNDIND" &&
                                                          widget.wlValue
                                                                  .instname !=
                                                              "COM") ...[
                                                        // Center(
                                                        //   child: TextWidget.titleText(
                                                        //       text:
                                                        //           "Market Depth",
                                                        //       theme: theme
                                                        //           .isDarkMode,
                                                        //       fw: 1),
                                                        // ),
                                                        // const SizedBox(
                                                        //     height:
                                                        //         10),
                                                        Row(children: [
                                                          Expanded(
                                                              child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .spaceBetween,
                                                                    children: [
                                                                      Text(
                                                                        "Quantity",
                                                                        style: MyntWebTextStyles.para(
                                                                            context,
                                                                            fontWeight: MyntFonts
                                                                                .medium,
                                                                            color: resolveThemeColor(context,
                                                                                dark: MyntColors.textSecondaryDark,
                                                                                light: MyntColors.textSecondary)),
                                                                      ),
                                                                      Text(
                                                                        "Bid",
                                                                        style: MyntWebTextStyles.para(
                                                                            context,
                                                                            fontWeight: MyntFonts
                                                                                .medium,
                                                                            color: resolveThemeColor(context,
                                                                                dark: MyntColors.primaryDark,
                                                                                light: MyntColors.primary)),
                                                                      )
                                                                    ]),
                                                                const SizedBox(
                                                                    height: 10),
                                                                _buildBidDepthPercentage(
                                                                    "${depthData.bq1 ?? 0}",
                                                                    "${depthData.bp1 ?? 0.00}",
                                                                    scripInfo,
                                                                    theme),
                                                                const SizedBox(
                                                                    height: 6),
                                                                _buildBidDepthPercentage(
                                                                    "${depthData.bq2 ?? 0}",
                                                                    "${depthData.bp2 ?? 0.00}",
                                                                    scripInfo,
                                                                    theme),
                                                                const SizedBox(
                                                                    height: 6),
                                                                _buildBidDepthPercentage(
                                                                    "${depthData.bq3 ?? 0}",
                                                                    "${depthData.bp3 ?? 0.00}",
                                                                    scripInfo,
                                                                    theme),
                                                                const SizedBox(
                                                                    height: 6),
                                                                _buildBidDepthPercentage(
                                                                    "${depthData.bq4 ?? 0}",
                                                                    "${depthData.bp4 ?? 0.00}",
                                                                    scripInfo,
                                                                    theme),
                                                                const SizedBox(
                                                                    height: 6),
                                                                _buildBidDepthPercentage(
                                                                    "${depthData.bq5 ?? 0}",
                                                                    "${depthData.bp5 ?? 0.00}",
                                                                    scripInfo,
                                                                    theme)
                                                              ])),
                                                          const SizedBox(
                                                              width: 20),
                                                          Expanded(
                                                              child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .spaceBetween,
                                                                    children: [
                                                                      Text(
                                                                        "Ask",
                                                                        style: MyntWebTextStyles.para(
                                                                            context,
                                                                            fontWeight:
                                                                                MyntFonts.medium,
                                                                            color: MyntColors.tertiary),
                                                                      ),
                                                                      Text(
                                                                        "Quantity",
                                                                        style: MyntWebTextStyles
                                                                            .para(
                                                                          context,
                                                                          fontWeight:
                                                                              MyntFonts.medium,
                                                                          color:
                                                                              resolveThemeColor(
                                                                            context,
                                                                            dark:
                                                                                MyntColors.textSecondaryDark,
                                                                            light:
                                                                                MyntColors.textSecondary,
                                                                          ),
                                                                        ),
                                                                      )
                                                                    ]),
                                                                const SizedBox(
                                                                    height: 10),
                                                                _buildAskDepthPercentage(
                                                                    "${depthData.sp1 ?? 0.00}",
                                                                    "${depthData.sq1 ?? 0}",
                                                                    scripInfo,
                                                                    theme),
                                                                const SizedBox(
                                                                    height: 6),
                                                                _buildAskDepthPercentage(
                                                                    "${depthData.sp2 ?? 0.00}",
                                                                    "${depthData.sq2 ?? 0}",
                                                                    scripInfo,
                                                                    theme),
                                                                const SizedBox(
                                                                    height: 6),
                                                                _buildAskDepthPercentage(
                                                                    "${depthData.sp3 ?? 0.00}",
                                                                    "${depthData.sq3 ?? 0}",
                                                                    scripInfo,
                                                                    theme),
                                                                const SizedBox(
                                                                    height: 6),
                                                                _buildAskDepthPercentage(
                                                                    "${depthData.sp4 ?? 0.00}",
                                                                    "${depthData.sq4 ?? 0}",
                                                                    scripInfo,
                                                                    theme),
                                                                const SizedBox(
                                                                    height: 6),
                                                                _buildAskDepthPercentage(
                                                                    "${depthData.sp5 ?? 0.00}",
                                                                    "${depthData.sq5 ?? 0}",
                                                                    scripInfo,
                                                                    theme)
                                                              ]))
                                                        ]),
                                                        const SizedBox(
                                                            height: 16),
                                                        Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Text(
                                                                    "${depthData.tbq != "null" ? depthData.tbq ?? 0 : '0'}",
                                                                    style:
                                                                        MyntWebTextStyles
                                                                            .body(
                                                                      context,
                                                                      fontWeight:
                                                                          MyntFonts
                                                                              .medium,
                                                                      color:
                                                                          resolveThemeColor(
                                                                        context,
                                                                        dark: MyntColors
                                                                            .textSecondaryDark,
                                                                        light: MyntColors
                                                                            .textSecondary,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                  Text(
                                                                    "(${scripInfo.totBuyQtyPer.toStringAsFixed(2)}%)",
                                                                    style:
                                                                        MyntWebTextStyles
                                                                            .body(
                                                                      context,
                                                                      fontWeight:
                                                                          MyntFonts
                                                                              .medium,
                                                                      color:
                                                                          resolveThemeColor(
                                                                        context,
                                                                        dark: MyntColors
                                                                            .textSecondaryDark,
                                                                        light: MyntColors
                                                                            .textSecondary,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              Row(
                                                                children: [
                                                                  Text(
                                                                    "(${scripInfo.totSellQtyPer.toStringAsFixed(2)}%)",
                                                                    style:
                                                                        MyntWebTextStyles
                                                                            .body(
                                                                      context,
                                                                      fontWeight:
                                                                          MyntFonts
                                                                              .medium,
                                                                      color:
                                                                          resolveThemeColor(
                                                                        context,
                                                                        dark: MyntColors
                                                                            .textSecondaryDark,
                                                                        light: MyntColors
                                                                            .textSecondary,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                  Text(
                                                                    "${depthData.tsq != "null" ? depthData.tsq ?? 0 : '0'}",
                                                                    style:
                                                                        MyntWebTextStyles
                                                                            .body(
                                                                      context,
                                                                      fontWeight:
                                                                          MyntFonts
                                                                              .medium,
                                                                      color:
                                                                          resolveThemeColor(
                                                                        context,
                                                                        dark: MyntColors
                                                                            .textSecondaryDark,
                                                                        light: MyntColors
                                                                            .textSecondary,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              )
                                                            ]),
                                                        (scripInfo.totBuyQtyPer
                                                                        .toStringAsFixed(
                                                                            2) ==
                                                                    "0.00" &&
                                                                scripInfo
                                                                        .totSellQtyPer
                                                                        .toStringAsFixed(
                                                                            2) ==
                                                                    "0.00")
                                                            ? const SizedBox()
                                                            : Column(
                                                                children: [
                                                                  const SizedBox(
                                                                      height:
                                                                          10),
                                                                  LinearPercentIndicator(

                                                                      // leading: Text(
                                                                      //     "${scripInfo.totBuyQtyPer.toStringAsFixed(2)}%",
                                                                      //     style: textStyle(
                                                                      //         theme.isDarkMode
                                                                      //             ? colors
                                                                      //                 .colorWhite
                                                                      //             : colors
                                                                      //                 .colorBlack,
                                                                      //         14,
                                                                      //         FontWeight
                                                                      //             .w500)),
                                                                      // trailing: Text(
                                                                      //     "${scripInfo.totSellQtyPer.toStringAsFixed(2)}%",
                                                                      //     style: textStyle(
                                                                      //         theme.isDarkMode
                                                                      //             ? colors
                                                                      //                 .colorWhite
                                                                      //             : colors
                                                                      //                 .colorBlack,
                                                                      //         14,
                                                                      //         FontWeight
                                                                      //             .w500)),
                                                                      lineHeight:
                                                                          5.0,
                                                                      barRadius:
                                                                          const Radius.circular(
                                                                              4.0), // Half of lineHeight for capsule shape
                                                                      backgroundColor: (scripInfo.totBuyQtyPer.toStringAsFixed(2) == "0.00" && scripInfo.totSellQtyPer.toStringAsFixed(2) == "0.00")
                                                                          ? resolveThemeColor(
                                                                              context,
                                                                              dark: MyntColors
                                                                                  .textSecondaryDark,
                                                                              light: MyntColors
                                                                                  .textSecondary)
                                                                          : resolveThemeColor(
                                                                              context,
                                                                              dark: MyntColors
                                                                                  .tertiary,
                                                                              light: MyntColors
                                                                                  .tertiary),
                                                                      percent: scripInfo
                                                                          .totBuyQtyPerChng,
                                                                      padding: const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              0),
                                                                      progressColor:
                                                                          MyntColors.primary),
                                                                  const SizedBox(
                                                                      height:
                                                                          16),
                                                                ],
                                                              ),
                                                      ],
                                                      const SizedBox(height: 4),
                                                      if ((widget.wlValue
                                                                  .instname !=
                                                              "UNDIND" &&
                                                          widget.wlValue
                                                                  .instname !=
                                                              "COM")) ...[
                                                        // Trading Info Section - Responsive layout with 300px breakpoint
                                                        const SizedBox(
                                                            height: 12),
                                                        Column(
                                                          children: [
                                                            _buildCasIndicativeRow(),
                                                            data(
                                                                "Avg Price",
                                                                "${depthData.ap ?? 0.00}",
                                                                theme),
                                                            data(
                                                                "Volume",
                                                                "${depthData.v != "null" ? depthData.v ?? 0.00 : '0'}",
                                                                theme),
                                                            data(
                                                                "LTQ",
                                                                "${depthData.ltq != "null" ? depthData.ltq ?? 0.00 : '0'}",
                                                                theme),
                                                            data(
                                                                "LTT",
                                                                depthData.ltt !=
                                                                        "null"
                                                                    ? (depthData
                                                                            .ltt ??
                                                                        "--")
                                                                    : "--",
                                                                theme),
                                                            data(
                                                                "52 Weeks High-Low",
                                                                "${(depthData.wk52H != "null" && depthData.wk52H != null) ? depthData.wk52H : 0.00} - ${(depthData.wk52L != "null" && depthData.wk52L != null) ? depthData.wk52L : 0.00}",
                                                                theme),
                                                            data(
                                                                "DPR",
                                                                "${depthData.uc != "null" ? depthData.uc ?? 0.00 : '0.00'} - ${depthData.lc != "null" ? depthData.lc ?? 0.00 : '0.00'}",
                                                                theme),
                                                            if (depthData.seg !=
                                                                "EQT") ...[
                                                              data(
                                                                  "Open Interest - OI",
                                                                  "${depthData.oi != "null" ? depthData.oi ?? 0.00 : '0'}",
                                                                  theme),
                                                              data(
                                                                  "Change in OI",
                                                                  "${depthData.poi != "null" ? depthData.poi ?? 0.00 : '0'}",
                                                                  theme),
                                                            ],
                                                          ],
                                                        ),
                                                        if (scripInfo
                                                            .returnsGridview
                                                            .isNotEmpty) ...[
                                                          // TextWidget.titleText(
                                                          //     text:
                                                          //         "Returns",
                                                          //     theme: theme
                                                          //         .isDarkMode,
                                                          //     fw: 1),
                                                          const SizedBox(
                                                              height: 16),
                                                          LayoutBuilder(
                                                            builder: (context,
                                                                constraints) {
                                                              // Calculate how many items can fit per row
                                                              // Each item: 120px width + 12px spacing
                                                              const itemWidth =
                                                                  120.0;
                                                              const spacing =
                                                                  12.0;
                                                              final availableWidth =
                                                                  constraints
                                                                      .maxWidth;
                                                              final itemsPerRow =
                                                                  ((availableWidth +
                                                                              spacing) /
                                                                          (itemWidth +
                                                                              spacing))
                                                                      .floor();
                                                              final calculatedWidth = itemsPerRow >
                                                                      0
                                                                  ? (availableWidth -
                                                                          (spacing *
                                                                              (itemsPerRow - 1))) /
                                                                      itemsPerRow
                                                                  : itemWidth;

                                                              return Wrap(
                                                                spacing:
                                                                    spacing,
                                                                runSpacing: 10,
                                                                children: List.generate(
                                                                    scripInfo
                                                                        .returnsGridview
                                                                        .length,
                                                                    (index) {
                                                                  return SizedBox(
                                                                      width: calculatedWidth.clamp(
                                                                          100.0,
                                                                          150.0), // Min 100px, Max 150px
                                                                      child: shadcn
                                                                          .Card(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                14,
                                                                            horizontal:
                                                                                8),
                                                                        child: Column(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.center,
                                                                            children: [
                                                                              Text(
                                                                                "${scripInfo.returnsGridview[index]['percent']}%",
                                                                                style: MyntWebTextStyles.body(
                                                                                  context,
                                                                                  fontWeight: MyntFonts.medium,
                                                                                  color: (scripInfo.returnsGridview[index]['percent'].toString().startsWith('-'))
                                                                                      ? resolveThemeColor(
                                                                                          context,
                                                                                          dark: MyntColors.lossDark,
                                                                                          light: MyntColors.loss,
                                                                                        )
                                                                                      : (scripInfo.returnsGridview[index]['percent'].toString() != '0' && scripInfo.returnsGridview[index]['percent'].toString() != '0.00')
                                                                                          ? resolveThemeColor(
                                                                                              context,
                                                                                              dark: MyntColors.profitDark,
                                                                                              light: MyntColors.profit,
                                                                                            )
                                                                                          : resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
                                                                                ),
                                                                              ),
                                                                              const SizedBox(height: 6),
                                                                              Center(
                                                                                  child: Text(
                                                                                "${scripInfo.returnsGridview[index]['duration']}",
                                                                                textAlign: TextAlign.center,
                                                                                style: MyntWebTextStyles.para(context, fontWeight: MyntFonts.medium, color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)),
                                                                              ))
                                                                            ]),
                                                                      ));
                                                                }),
                                                              );
                                                            },
                                                          ),
                                                          const SizedBox(
                                                              height: 12),
                                                        ]
                                                      ],

                                                      Column(
                                                        children: [
                                                          const ListDivider(),
                                                          // Expandable Futures Section
                                                          if (scripInfo.getOptionawait(
                                                              widget.wlValue.exch,
                                                              widget.wlValue.token))
                                                            _buildExpandableFuturesSection(
                                                              scripInfo,
                                                              theme,
                                                              depthData,
                                                            ),
                                                          // Stock Report and Scrip Info moved to header icons
                                                          // if (scripInfo.fundamentalData != null &&
                                                          //     scripInfo.fundamentalData?.msg != "no data found")
                                                          //   _buildAccordionItem(
                                                          //     context: context,
                                                          //     label: "Stock report",
                                                          //     onTap: () async {
                                                          //       try {
                                                          //         await scripInfo.fetchFundamentalData(
                                                          //           tradeSym: "${widget.wlValue.exch}:${widget.wlValue.tsym}",
                                                          //         );

                                                          //         if (!mounted) return;

                                                          //         if (scripInfo.fundamentalData != null &&
                                                          //             scripInfo.fundamentalData?.msg != "no data found") {
                                                          //           DepthInputArgs depthArgs = _createDepthArgs();
                                                          //           final depthData = scripInfo.getQuotes!;

                                                          //           if (mounted) {
                                                          //             showDialog(
                                                          //               context: context,
                                                          //               barrierDismissible: true,
                                                          //               builder: (BuildContext dialogContext) {
                                                          //                 return Center(
                                                          //                   child: shadcn.Card(
                                                          //                     borderRadius: BorderRadius.circular(12),
                                                          //                     child: Container(
                                                          //                       width: 700,
                                                          //                       constraints: const BoxConstraints(maxHeight: 800, minHeight: 400),
                                                          //                       child: Column(
                                                          //                         mainAxisSize: MainAxisSize.min,
                                                          //                         children: [
                                                          //                           Padding(
                                                          //                             padding: const EdgeInsets.all(16),
                                                          //                             child: Row(
                                                          //                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          //                               children: [
                                                          //                                 Text(
                                                          //                                   '${depthArgs.symbol.replaceAll("-EQ", "").toUpperCase()}${depthArgs.expDate} ${depthArgs.option} Stock Report',
                                                          //                                   style: MyntWebTextStyles.title(context),
                                                          //                                 ),
                                                          //                                 Material(
                                                          //                                   color: Colors.transparent,
                                                          //                                   shape: const CircleBorder(),
                                                          //                                   child: InkWell(
                                                          //                                     customBorder: const CircleBorder(),
                                                          //                                     splashColor: resolveThemeColor(
                                                          //                                       context,
                                                          //                                       dark: MyntColors.rippleDark,
                                                          //                                       light: MyntColors.rippleLight,
                                                          //                                     ),
                                                          //                                     highlightColor: resolveThemeColor(
                                                          //                                       context,
                                                          //                                       dark: MyntColors.highlightDark,
                                                          //                                       light: MyntColors.highlightLight,
                                                          //                                     ),
                                                          //                                     onTap: () => Navigator.of(context).pop(),
                                                          //                                     child: Padding(
                                                          //                                       padding: const EdgeInsets.all(8),
                                                          //                                       child: Icon(
                                                          //                                         Icons.close,
                                                          //                                         size: 20,
                                                          //                                         color: resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary),
                                                          //                                       ),
                                                          //                                     ),
                                                          //                                   ),
                                                          //                                 ),
                                                          //                               ],
                                                          //                             ),
                                                          //                           ),
                                                          //                           Expanded(
                                                          //                             child: ClipRRect(
                                                          //                               borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                                          //                               child: MediaQuery.removePadding(
                                                          //                                 context: context,
                                                          //                                 removeTop: true,
                                                          //                                 child: NewFundamentalScreen(
                                                          //                                   wlValue: depthArgs,
                                                          //                                   depthData: depthData,
                                                          //                                 ),
                                                          //                               ),
                                                          //                             ),
                                                          //                           ),
                                                          //                         ],
                                                          //                       ),
                                                          //                     ),
                                                          //                   ),
                                                          //                 );
                                                          //               },
                                                          //             );
                                                          //           }
                                                          //         }
                                                          //       } finally {}
                                                          //     },
                                                          //   ),
                                                          // // Scrip Info accordion item
                                                          // _buildAccordionItem(
                                                          //   context: context,
                                                          //   label: "Scrip info",
                                                          //   onTap: () async {
                                                          //     try {
                                                          //       // Fetch scrip info before showing dialog
                                                          //       await scripInfo.fetchScripInfo(
                                                          //         widget.wlValue.token,
                                                          //         widget.wlValue.exch,
                                                          //         context,
                                                          //       );

                                                          //       if (!mounted) return;

                                                          //       if (scripInfo.scripInfoModel != null) {
                                                          //         showGeneralDialog(
                                                          //           context: context,
                                                          //           barrierDismissible: true,
                                                          //           barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                                                          //           barrierColor: resolveThemeColor(
                                                          //             context,
                                                          //             dark: MyntColors.modalBarrierDark,
                                                          //             light: MyntColors.modalBarrierLight,
                                                          //           ),
                                                          //           transitionDuration: const Duration(milliseconds: 200),
                                                          //           pageBuilder: (context, animation, secondaryAnimation) {
                                                          //             return PointerInterceptor(
                                                          //               child: Center(
                                                          //                 child: const ScripDetailWeb(),
                                                          //               ),
                                                          //             );
                                                          //           },
                                                          //           transitionBuilder: (context, animation, secondaryAnimation, child) {
                                                          //             final curvedAnimation = CurvedAnimation(
                                                          //               parent: animation,
                                                          //               curve: Curves.easeOut,
                                                          //               reverseCurve: Curves.easeIn,
                                                          //             );

                                                          //             return FadeTransition(
                                                          //               opacity: curvedAnimation,
                                                          //               child: ScaleTransition(
                                                          //                 scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
                                                          //                 child: child,
                                                          //               ),
                                                          //             );
                                                          //           },
                                                          //         );
                                                          //       }
                                                          //     } catch (e) {
                                                          //       debugPrint('Error showing scrip info: $e');
                                                          //     }
                                                          //   },
                                                          // ),
                                                        ],
                                                      ),
                                                    ]),
                                                  )
                                                ])
                                          ] else if (scripInfo.actDeptBtn ==
                                              "Fundamental") ...[
                                            if (ref
                                                        .read(
                                                            marketWatchProvider)
                                                        .fundamentalData !=
                                                    null &&
                                                ref
                                                        .read(
                                                            marketWatchProvider)
                                                        .fundamentalData!
                                                        .msg
                                                        .toString() !=
                                                    "no data found") ...[
                                              const SizedBox(height: 10),
                                              const FundamentalDataWidget(),
                                            ] else ...[
                                              const NoDataFoundWeb()
                                            ]
                                          ] else if (scripInfo.actDeptBtn ==
                                              "Chart") ...[
                                            // ChartScreenWebView(
                                            //     chartArgs: chartArgs!, cHeight: 1.48)
                                          ] else if (scripInfo.actDeptBtn ==
                                              "Future") ...[
                                            Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                    color: resolveThemeColor(
                                                      context,
                                                      dark: MyntColors
                                                          .primaryDark,
                                                      light: MyntColors.primary,
                                                    ).withOpacity(0.05),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6)),
                                                child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      SvgPicture.asset(
                                                          assets.dInfo,
                                                          color: resolveThemeColor(
                                                              context,
                                                              dark: MyntColors
                                                                  .textSecondaryDark,
                                                              light: MyntColors
                                                                  .textSecondary)),
                                                      Text(
                                                        " Long press to add ${scripInfo.wlName}'s Watchlist",
                                                        style: MyntWebTextStyles.caption(
                                                            context,
                                                            color: resolveThemeColor(
                                                                context,
                                                                dark: MyntColors
                                                                    .textSecondaryDark,
                                                                light: MyntColors
                                                                    .textSecondary)),
                                                      )
                                                    ])),
                                            const FutureScreenWeb()
                                          ] else if (scripInfo.actDeptBtn ==
                                              "Set Alert") ...[
                                            // Set Alert is now shown as a dialog
                                            const SizedBox.shrink()
                                          ],
                                          if (!scripInfo.scripDepthloader)
                                            const SizedBox(height: 18),
                                        ]),
                                  ),
                                ),
                              ),
                            ),
                            // Divider(
                            //   height: 1,
                            //   thickness: 1.2,
                            //   color: theme.isDarkMode
                            //       ? colors.darkColorDivider
                            //       : colors.colorDivider,
                            // ),
                            // // Quick Order embedded below scrip info - takes only what it needs
                            // if (!isIndexOrCommodity)
                            //   Builder(builder: (context) {
                            //     final lotSize = _safeParseLotSize(
                            //         ref
                            //             .read(marketWatchProvider)
                            //             .scripInfoModel
                            //             ?.ls,
                            //         depthData.ls,
                            //         "1");
                            //     final orderArgs = OrderScreenArgs(
                            //       exchange: widget.wlValue.exch,
                            //       tSym: widget.wlValue.tsym,
                            //       isExit: false,
                            //       token: widget.wlValue.token,
                            //       transType: true,
                            //       lotSize: lotSize,
                            //       ltp: "${depthData.lp ?? depthData.c ?? 0.00}",
                            //       perChange: depthData.pc ?? "0.00",
                            //       orderTpye: '',
                            //       holdQty: '',
                            //       isModify: false,
                            //       raw: {},
                            //     );
                            //     return QuickOrderScreenWeb(
                            //       key: ValueKey(
                            //           "${orderArgs.exchange}|${orderArgs.token}"),
                            //       orderArg: orderArgs,
                            //       scripInfo: ref
                            //           .read(marketWatchProvider)
                            //           .scripInfoModel!,
                            //       embedded: true,
                            //     );
                            //   }),
                          ],
                        ),
                      ),
                    );
                  });
            }),
          )),
    );
  }

  String _safeParseLotSize(
      dynamic scripInfoLs, dynamic depthDataLs, String defaultValue) {
    // Try scripInfo first
    String scripInfoValue = _safeParseNumeric(scripInfoLs, "");
    if (scripInfoValue.isNotEmpty && scripInfoValue != defaultValue) {
      return scripInfoValue;
    }

    // Try depthData
    String depthDataValue = _safeParseNumeric(depthDataLs, "");
    if (depthDataValue.isNotEmpty && depthDataValue != defaultValue) {
      return depthDataValue;
    }

    return defaultValue;
  }

  String _safeParseNumeric(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;

    String stringValue = value.toString().trim();

    // Handle common invalid values
    if (stringValue.isEmpty ||
        stringValue == 'null' ||
        stringValue == '0.0' ||
        stringValue == '0' ||
        stringValue == 'NaN' ||
        stringValue == 'Infinity') {
      return defaultValue;
    }

    // Try to parse as double first, then int
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

  DepthInputArgs _createDepthArgs() {
    return DepthInputArgs(
      exch: widget.wlValue.exch.toString(),
      token: widget.wlValue.token.toString(),
      tsym: widget.wlValue.tsym.toString(),
      instname: widget.wlValue.instname.toString() ??
          widget.wlValue.symbol.toString(),
      symbol: widget.wlValue.symbol.toString(),
      expDate: widget.wlValue.expDate.toString() ?? "",
      option: widget.wlValue.option.toString() ?? "",
    );
  }

  Future<void> placeOrderInput(MarketWatchProvider scripInfo, BuildContext ctx,
      GetQuotes depthData, bool transType) async {
    await ref.read(marketWatchProvider).fetchScripInfo(
        widget.wlValue.token, widget.wlValue.exch, context, true);

    // **FIX: Use lot size from scripInfoModel if in basket mode, otherwise use existing logic**
    final lotSize = widget.isBasket == "BasketMode"
        ? ref.read(marketWatchProvider).scripInfoModel?.ls?.toString() ??
            depthData.ls ??
            "1"
        : (depthData.ls?.isNotEmpty == true
            ? depthData.ls
            : ref.read(marketWatchProvider).scripInfoModel?.ls.toString());

    OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: widget.wlValue.exch,
        tSym: widget.wlValue.tsym,
        isExit: false,
        token: widget.wlValue.token,
        transType: transType,
        lotSize: lotSize,
        ltp: "${depthData.lp ?? depthData.c ?? 0.00}",
        perChange: depthData.pc ?? "0.00",
        orderTpye: '',
        holdQty: '',
        isModify: false,
        raw: {});
    // Navigator.pop(ctx);
    ResponsiveNavigation.toPlaceOrderScreen(
      context: ctx,
      arguments: {
        "orderArg": orderArgs,
        "scripInfo": ref.read(marketWatchProvider).scripInfoModel!,
        "isBskt": widget.isBasket
      },
    );
  }

  Row lowHighBar(String low, String high, String value, ThemesProvider theme) {
    double? lowValue = double.tryParse(low);
    double? valueValue = double.tryParse(value);
    double? highValue = double.tryParse(high);

    double minValue = (lowValue != null && valueValue != null)
        ? (lowValue <= valueValue ? lowValue : valueValue)
        : 0.0; // Fallback if parsing fails

    double maxValue = (highValue != null && valueValue != null)
        ? (highValue >= valueValue ? highValue : valueValue)
        : 0.0; // Fallback if parsing fails

    List<double> valuesList =
        valueValue != null ? [valueValue] : [0.0]; // Fallback if parsing fails

    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(
        low,
        style: MyntWebTextStyles.para(context),
      ),
      SizedBox(
        width: MediaQuery.of(context).size.width / 1.8,
        child: FlutterSlider(
          handlerHeight: 20,
          handlerWidth: 12,
          handler: FlutterSliderHandler(
              child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                      decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.iconDark,
                            light: Colors.black,
                          )),
                      child: const Center(
                          child: Text(
                        ' ',
                        style: TextStyle(
                          color: Colors.transparent,
                        ),
                      ))))),
          tooltip: FlutterSliderTooltip(
            disabled: true,
          ),
          trackBar: FlutterSliderTrackBar(
            inactiveDisabledTrackBarColor:
                const Color(0xff666666).withOpacity(.2),
            activeDisabledTrackBarColor: theme.isDarkMode
                ? const Color.fromARGB(255, 36, 35, 35).withOpacity(.2)
                : const Color.fromARGB(255, 247, 246, 246).withOpacity(.2),
            activeTrackBarHeight: 4,
            inactiveTrackBarHeight: 4,
          ),
          min: minValue,
          max: minValue == maxValue ? maxValue + 1 : maxValue,
          values: valuesList,
          onDragging: null,
          jump: false,
          disabled: true,
        ),
      ),
      Text(
        high,
        style: MyntWebTextStyles.para(context),
      )
    ]);
  }

  // CAS (Closing Auction Session) indicative-price row — solid badge + label + value.
  Widget _buildCasIndicativeRow() {
    // Read the per-token indicative price from the websocket provider — it
    // retains the rare `ic` delta reliably, unlike the volatile socket map.
    final value = casIndicativeDisplay(
        ref.read(websocketProvider).indicativeClose(regtoken));
    // No indicative price (no auction / not eligible / not sent) — hide the row.
    if (value == '—') return const SizedBox.shrink();
    // Match the trading-info rows below (Avg Price, Volume, …): same spacing,
    // bottom divider only (no top line).
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal:
              context.responsive(mobile: 0.0, tablet: 0.0, desktop: 0.0)),
      child: Column(
        children: [
          SizedBox(
              height:
                  context.responsive(mobile: 6.0, tablet: 7.0, desktop: 8.0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Hover the badge to reveal the full form (same tooltip style
                  // as the dashboard card info tooltips, minus the `i` icon).
                  Tooltip(
                    message: 'Closing Auction Session',
                    waitDuration: const Duration(milliseconds: 200),
                    showDuration: const Duration(seconds: 6),
                    preferBelow: false,
                    verticalOffset: 12,
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 220),
                    decoration: BoxDecoration(
                      color: resolveThemeColor(context,
                          dark: const Color(0xFF252A33), light: Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    textStyle: MyntWebTextStyles.bodySmall(context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                        fontWeight: MyntFonts.regular),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: resolveThemeColor(context,
                            dark: MyntColors.secondary,
                            light: MyntColors.primary),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'CAS',
                        style: MyntWebTextStyles.body(context,
                            fontWeight: MyntFonts.semiBold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Indicative Close',
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.medium,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textSecondary)),
                  ),
                ],
              ),
              Text(
                value,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary)),
              ),
            ],
          ),
          SizedBox(
              height:
                  context.responsive(mobile: 8.0, tablet: 9.0, desktop: 10.0)),
          Divider(color: shadcn.Theme.of(context).colorScheme.border),
        ],
      ),
    );
  }

  // Ask side (Price on left, Qty on right)
  Widget _buildAskDepthPercentage(String price, String qty,
      MarketWatchProvider scripInfo, ThemesProvider theme) {
    return Stack(children: [
      // Transform.flip(
      //   flipX: true,
      //   child: LinearPercentIndicator(
      //     lineHeight: 20.0,
      //     backgroundColor:
      //         !theme.isDarkMode ? MyntColors.surface : WebDarkColors.surface,
      //     percent: barPercentage,
      //     padding: const EdgeInsets.symmetric(horizontal: 0),
      //     progressColor: color.withOpacity(.2),
      //     // barRadius: const Radius.circular(10.0), // Half of lineHeight for capsule shape
      //   ),
      // ),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              " ${price != "null" ? price : '0.00'} ",
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.medium,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.lossDark,
                    light: MyntColors.tertiary,
                  )),
            ),
            Text(
              " ${qty != "null" ? qty : '0'} ",
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.medium,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary,
                ),
              ),
            )
          ],
        ),
      )
    ]);
  }

  // Bid side (Qty on left, Price on right)
  Widget _buildBidDepthPercentage(String qty, String price,
      MarketWatchProvider scripInfo, ThemesProvider theme) {
    return Stack(children: [
      // LinearPercentIndicator(
      //   lineHeight: 20.0,
      //   backgroundColor:
      //       !theme.isDarkMode ? MyntColors.surface : WebDarkColors.surface,
      //   percent: barPercentage,
      //   padding: const EdgeInsets.symmetric(horizontal: 0),
      //   progressColor: color.withOpacity(.2),
      //   // barRadius: const Radius.circular(4), // Half of lineHeight for capsule shape
      // ),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              " ${qty != "null" ? qty : '0'} ",
              style: MyntWebTextStyles.body(
                context,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary,
                ),
                fontWeight: MyntFonts.medium,
              ),
            ),
            Text(
              " ${price != "null" ? price : '0.00'} ",
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.medium,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.primaryDark,
                  light: MyntColors.primary,
                ),
              ),
            ),
          ],
        ),
      )
    ]);
  }

  // Expandable Futures Section - inline list like mobile
  Widget _buildExpandableFuturesSection(MarketWatchProvider scripInfo,
      ThemesProvider theme, GetQuotes depthData) {
    return Column(
      children: [
        // Futures Header with expand/collapse
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              try {
                if (!scripInfo.isFuturesExpanded) {
                  // Only fetch data when expanding
                  if (scripInfo.getOptionawait(
                      widget.wlValue.exch, widget.wlValue.token)) {
                    await scripInfo.fetchScripInfo(
                        widget.wlValue.token, widget.wlValue.exch, context);
                    await scripInfo.fetchLinkeScrip(
                        widget.wlValue.token, widget.wlValue.exch, context);
                  }
                  await scripInfo.requestWSFut(
                      context: context, isSubscribe: true);
                } else {
                  // Unsubscribe when collapsing
                  await scripInfo.requestWSFut(
                      context: context, isSubscribe: false);
                }
                scripInfo.toggleFuturesExpansion();
              } catch (e) {
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.responsive(mobile: 12.0, tablet: 14.0, desktop: 16.0),
                vertical: context.responsive(mobile: 10.0, tablet: 11.0, desktop: 12.0)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Futures",
                    style: MyntWebTextStyles.para(context),
                  ),
                  AnimatedRotation(
                    turns: scripInfo.isFuturesExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.iconDark,
                        light: MyntColors.icon,
                      ),
                      size: context.responsive(mobile: 18.0, tablet: 19.0, desktop: 20.0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const ListDivider(),

        // Expandable Futures Content - Mobile style list
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: scripInfo.isFuturesExpanded
              ? _buildFuturesListContent(scripInfo, theme)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // Futures list content - similar to mobile FutureScreen
  Widget _buildFuturesListContent(
      MarketWatchProvider scripInfo, ThemesProvider theme) {
    if (scripInfo.fut == null || scripInfo.fut!.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(context.responsive(mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        child: Center(
          child: Text(
            "No futures data available",
            style: MyntWebTextStyles.body(
              context,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<Map>(
      stream: ref.read(websocketProvider).socketDataStream,
      builder: (context, snapshot) {
        // CRITICAL FIX: Fall back to existing socket data if stream hasn't emitted yet
        final socketDatas = snapshot.data ?? ref.read(websocketProvider).socketDatas;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Info banner removed — rows now have a hover bookmark (TC_208).
            // Container(
            //   padding: EdgeInsets.symmetric(
            //     vertical: context.responsive(mobile: 6.0, tablet: 7.0, desktop: 8.0),
            //     horizontal: context.responsive(mobile: 12.0, tablet: 14.0, desktop: 16.0)),
            //   decoration: BoxDecoration(
            //     color: resolveThemeColor(
            //       context,
            //       dark: MyntColors.primaryDark,
            //       light: MyntColors.primary,
            //     ).withOpacity(0.05),
            //   ),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       SvgPicture.asset(
            //         assets.dInfo,
            //         color: resolveThemeColor(
            //           context,
            //           dark: MyntColors.textSecondaryDark,
            //           light: MyntColors.textSecondary,
            //         ),
            //         width: context.responsive(mobile: 12.0, tablet: 13.0, desktop: 14.0),
            //         height: context.responsive(mobile: 12.0, tablet: 13.0, desktop: 14.0),
            //       ),
            //       SizedBox(width: context.responsive(mobile: 4.0, tablet: 5.0, desktop: 6.0)),
            //       Text(
            //         "Long press to add to ${scripInfo.wlName} Watchlist",
            //         style: MyntWebTextStyles.caption(
            //           context,
            //           color: resolveThemeColor(
            //             context,
            //             dark: MyntColors.textSecondaryDark,
            //             light: MyntColors.textSecondary,
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            // Futures list - sorted by expiry date ascending
            Builder(
              builder: (context) {
                // Sort futures by expiry date (ascending - nearest expiry first)
                final sortedFutures = List.from(scripInfo.fut!)..sort((a, b) {
                  final aDate = _parseExpiryDate(a.exd);
                  final bDate = _parseExpiryDate(b.exd);
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return aDate.compareTo(bDate);
                });

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedFutures.length,
                  separatorBuilder: (BuildContext context, int index) {
                    return const ListDivider();
                  },
                  itemBuilder: (BuildContext context, int index) {
                    var displayData = sortedFutures[index];

                // Update with socket data if available
                final tokenKey = displayData.token?.toString();
                if (tokenKey != null && socketDatas.containsKey(tokenKey)) {
                  final socketData = socketDatas[tokenKey];
                  final lp = socketData['lp']?.toString();
                  if (lp != null && lp != "null" && lp != "0" && lp != "0.00") {
                    displayData.ltp = lp;
                  }
                  final chng = socketData['chng']?.toString();
                  if (chng != null && chng != "null") {
                    displayData.change = chng;
                  }
                  final pc = socketData['pc']?.toString();
                  if (pc != null && pc != "null") {
                    displayData.perChange = pc;
                  }
                }

                    return _buildFutureListItem(
                        displayData, scripInfo, theme, index);
                  },
                );
              },
            ),
            const ListDivider(),
          ],
        );
      },
    );
  }

  /// Parse expiry date string (format: "DD-MMM-YY" like "28-APR-26") to DateTime
  DateTime? _parseExpiryDate(String? exd) {
    if (exd == null || exd.isEmpty) return null;
    try {
      final months = {
        'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
        'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
      };
      final parts = exd.toUpperCase().split('-');
      if (parts.length >= 3) {
        final day = int.tryParse(parts[0]) ?? 1;
        final month = months[parts[1]] ?? 1;
        var year = int.tryParse(parts[2]) ?? 26;
        // Convert 2-digit year to 4-digit (assume 20xx)
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
    } catch (e) {
    }
    return null;
  }

  // Individual future list item - mobile style
  Widget _buildFutureListItem(dynamic displayData,
      MarketWatchProvider scripInfo, ThemesProvider theme, int index) {
    final change = displayData.change?.toString() ?? "0.00";
    final perChange = displayData.perChange?.toString() ?? "0.00";
    final ltp = displayData.ltp ?? displayData.close ?? "0.00";

    // Determine price color based on change
    Color priceColor;
    if (change.startsWith("-") || perChange.startsWith('-')) {
      priceColor = resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else if (change == "null" ||
        perChange == "null" ||
        change == "0.00" ||
        perChange == "0.00") {
      priceColor = resolveThemeColor(
        context,
        dark: MyntColors.textPrimaryDark,
        light: MyntColors.textPrimary,
      );
    } else {
      priceColor = resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    }

    final futureKey = "${displayData.exch}|${displayData.token}";

    // Hover pill (B / S / chart / bookmark) like the option chain — long-press
    // to add wasn't discoverable (TC_208). Long-press is kept as well.
    return MouseRegion(
      onEnter: (_) => _hoveredFutureKey.value = futureKey,
      onExit: (_) {
        if (_hoveredFutureKey.value == futureKey) _hoveredFutureKey.value = null;
      },
      child: Stack(
        children: [
    // Row highlight on hover — same tint as watchlist rows.
    ValueListenableBuilder<String?>(
      valueListenable: _hoveredFutureKey,
      builder: (context, hoveredKey, child) => Container(
        color: hoveredKey == futureKey
            ? resolveThemeColor(context,
                    dark: MyntColors.primaryDark, light: MyntColors.primary)
                .withValues(alpha: 0.08)
            : Colors.transparent,
        child: child,
      ),
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: () async {
          if (scripInfo.isPreDefWLs == "Yes") {
            ResponsiveSnackBar.showWarning(context,
                "This is a pre-defined watchlist that cannot be edited!");
            return;
          }
          // isEdit/isOptionStike false -> provider shows the standard
          // 'Added to your watchlist' snackbar (TC_208), not the raw
          // Fluttertoast. Was: true, true, false, true.
          await scripInfo.addDelMarketScrip(
            scripInfo.wlName,
            "${displayData.exch}|${displayData.token}",
            context,
            true,
            false,
            false,
            false,
          );
        },
        onTap: () async {
          await Future.delayed(const Duration(milliseconds: 150));
          // Collapse futures section before navigating
          if (scripInfo.isFuturesExpanded) {
            scripInfo.toggleFuturesExpansion();
            await scripInfo.requestWSFut(context: context, isSubscribe: false);
          }
          if (mounted) {
            // Was calldepthApis(context, displayData, "") — the raw Futures
            // item has no `idx`, so calldepthApis threw and nothing opened.
            await scripInfo.calldepthApis(
                context, _futureDepthArgs(displayData), "");
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsive(mobile: 12.0, tablet: 14.0, desktop: 16.0),
            vertical: context.responsive(mobile: 10.0, tablet: 11.0, desktop: 12.0)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side - Symbol and exchange info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Symbol name
                    Row(
                      children: [
                        Text(
                          "${displayData.symbol ?? ''}",
                          style: MyntWebTextStyles.body(
                            context,
                            fontWeight: MyntFonts.medium,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                        ),
                        if (displayData.option != null &&
                            displayData.option!.isNotEmpty)
                          Text(
                            " ${displayData.option}",
                            style: MyntWebTextStyles.body(
                              context,
                              fontWeight: MyntFonts.medium,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: context.responsive(mobile: 2.0, tablet: 3.0, desktop: 4.0)),
                    // Exchange and expiry
                    Row(
                      children: [
                        Text(
                          "${displayData.exch ?? ''}",
                          style: MyntWebTextStyles.para(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary,
                            ),
                          ),
                        ),
                        if (displayData.expDate != null &&
                            displayData.expDate!.isNotEmpty)
                          Text(
                            " ${displayData.expDate}",
                            style: MyntWebTextStyles.para(
                              context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Right side - Price and change
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // LTP
                  Text(
                    "$ltp", // was "₹$ltp" — no rupee symbol on futures rows
                    style: MyntWebTextStyles.body(
                      context,
                      fontWeight: MyntFonts.medium,
                      color: priceColor,
                    ),
                  ),
                  SizedBox(height: context.responsive(mobile: 2.0, tablet: 3.0, desktop: 4.0)),
                  // Change and percent change
                  Text(
                    "${change == "null" ? "0.00" : double.tryParse(change)?.toStringAsFixed(2) ?? "0.00"} "
                    "(${perChange == "null" ? "0.00" : perChange}%)",
                    style: MyntWebTextStyles.para(
                      context,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    ),
          // Hover pill — same look and placement as watchlist rows.
          Positioned.fill(
            child: Center(
              child: ValueListenableBuilder<String?>(
                valueListenable: _hoveredFutureKey,
                builder: (context, hoveredKey, _) {
                  if (hoveredKey != futureKey) return const SizedBox.shrink();
                  return Container(
                    decoration: BoxDecoration(
                      color: resolveThemeColor(context,
                          dark: MyntColors.backgroundColorDark,
                          light: MyntColors.backgroundColor),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: HoverActionsContainer(
                    isVisible: true,
                    actions: [
                      HoverActionButton(
                        label: 'B',
                        color: Colors.white,
                        backgroundColor: resolveThemeColor(context,
                            dark: MyntColors.secondary, light: MyntColors.primary),
                        borderColor: resolveThemeColor(context,
                            dark: MyntColors.secondary, light: MyntColors.primary),
                        onPressed: () => _futurePlaceOrder(displayData, true),
                      ),
                      HoverActionButton(
                        label: 'S',
                        color: Colors.white,
                        backgroundColor: resolveThemeColor(context,
                            dark: MyntColors.errorDark, light: MyntColors.tertiary),
                        borderColor: resolveThemeColor(context,
                            dark: MyntColors.errorDark, light: MyntColors.tertiary),
                        onPressed: () => _futurePlaceOrder(displayData, false),
                      ),
                      HoverActionButton(
                        iconAsset: assets.chartnew,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimary, light: Colors.black),
                        backgroundColor: Colors.transparent,
                        onPressed: () => _futureOpenChart(displayData),
                      ),
                      // Watches the live watchlist so the icon fills as soon
                      // as the add succeeds.
                      Consumer(
                        builder: (context, ref, _) {
                          final isInWatchlist = ref.watch(
                              marketWatchProvider.select((p) => p.scrips.any(
                                  (e) => "${e['exch']}|${e['token']}" == futureKey)));
                          return HoverActionButton(
                            iconAsset: isInWatchlist
                                ? assets.bookmarkIcon
                                : assets.bookmarkLineIcon,
                            color: isInWatchlist
                                ? resolveThemeColor(context,
                                    dark: MyntColors.primaryDark,
                                    light: MyntColors.primary)
                                : resolveThemeColor(context,
                                    dark: MyntColors.textPrimary,
                                    light: Colors.black),
                            backgroundColor: Colors.transparent,
                            onPressed: () =>
                                _futureToggleWatchlist(displayData, isInWatchlist),
                          );
                        },
                      ),
                    ],
                  ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Futures row hover B / S — same flow as the Futures table
  /// (FutureScreenWeb._placeOrderInput): load the contract's scrip info, then
  /// open the place-order screen. The page's own Buy/Sell re-fetch their scrip
  /// info, so this doesn't leave the page pointing at the future.
  Future<void> _futurePlaceOrder(dynamic displayData, bool isBuy) async {
    if (_futureOrderNavigating) return;
    _futureOrderNavigating = true;
    try {
      final mw = ref.read(marketWatchProvider);
      await mw.fetchScripInfo(displayData.token?.toString() ?? "",
          displayData.exch?.toString() ?? "", context, true);
      if (!mounted) return;

      final scripInfoModel = mw.scripInfoModel;
      if (scripInfoModel == null) {
        ResponsiveSnackBar.showError(context, 'Unable to load scrip details');
        return;
      }

      final lotSize = (displayData.ls?.toString().isNotEmpty ?? false)
          ? displayData.ls.toString()
          : scripInfoModel.ls?.toString();

      final orderArgs = OrderScreenArgs(
        exchange: displayData.exch?.toString() ?? "",
        tSym: displayData.tsym?.toString() ?? "",
        isExit: false,
        token: displayData.token?.toString() ?? "",
        transType: isBuy,
        lotSize: lotSize,
        ltp: "${displayData.ltp ?? displayData.close ?? 0.00}",
        perChange: displayData.perChange?.toString() ?? "0.00",
        orderTpye: '',
        holdQty: '',
        isModify: false,
        raw: {},
      );

      ResponsiveNavigation.toPlaceOrderScreen(
        context: context,
        arguments: {
          "orderArg": orderArgs,
          "scripInfo": scripInfoModel,
          "isBskt": widget.isBasket,
        },
      );
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, 'Error placing order: $e');
      }
    } finally {
      // Short cool-down so a double-click can't open a second order screen.
      Future.delayed(const Duration(milliseconds: 500), () {
        _futureOrderNavigating = false;
      });
    }
  }

  /// calldepthApis needs DepthInputArgs, not the raw Futures item: it reads
  /// `raw.idx`, which Futures doesn't have, so the raw item throws.
  DepthInputArgs _futureDepthArgs(dynamic displayData) {
    return DepthInputArgs(
      exch: displayData.exch?.toString() ?? '',
      token: displayData.token?.toString() ?? '',
      tsym: displayData.tsym?.toString() ?? '',
      instname: displayData.instname?.toString() ?? '',
      symbol: displayData.symbol?.toString() ?? displayData.tsym?.toString() ?? '',
      expDate: displayData.expDate?.toString() ?? '',
      option: displayData.option?.toString() ?? '',
    );
  }

  /// Futures row hover chart — open the contract (same as tapping the row),
  /// then ask the host to switch to its Chart tab.
  Future<void> _futureOpenChart(dynamic displayData) async {
    final scripInfo = ref.read(marketWatchProvider);
    if (scripInfo.isFuturesExpanded) {
      scripInfo.toggleFuturesExpansion();
      await scripInfo.requestWSFut(context: context, isSubscribe: false);
    }
    if (!mounted) return;
    await scripInfo.calldepthApis(context, _futureDepthArgs(displayData), "");
    if (!mounted) return;
    widget.onChartRequested?.call();
  }

  /// Futures row hover bookmark — add/remove in the current watchlist. The
  /// provider shows the standard 'Added to / Removed from your watchlist' toast.
  Future<void> _futureToggleWatchlist(
      dynamic displayData, bool isInWatchlist) async {
    final scripInfo = ref.read(marketWatchProvider);
    if (scripInfo.isPreDefWLs == "Yes") {
      ResponsiveSnackBar.showWarning(
          context, "This is a pre-defined watchlist that cannot be edited!");
      return;
    }
    await scripInfo.addDelMarketScrip(
      scripInfo.wlName,
      "${displayData.exch}|${displayData.token}",
      context,
      !isInWatchlist,
      false,
      false,
      false,
    );
  }

  // Futures navigation section (legacy - kept for reference)
  Widget _buildFuturesSection(MarketWatchProvider scripInfo,
      ThemesProvider theme, GetQuotes depthData) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await Future.delayed(const Duration(milliseconds: 150));
              await scripInfo.requestWSFut(context: context, isSubscribe: true);
              scripInfo.toggleFuturesExpansion();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.responsive(mobile: 12.0, tablet: 14.0, desktop: 16.0),
                vertical: context.responsive(mobile: 6.0, tablet: 7.0, desktop: 8.0)),
              child: Column(
                children: [
                  SizedBox(height: context.responsive(mobile: 8.0, tablet: 10.0, desktop: 12.0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Futures",
                        style: MyntWebTextStyles.para(context),
                      ),
                      AnimatedRotation(
                        turns: scripInfo.isFuturesExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.chevron_right,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.iconDark,
                            light: MyntColors.icon,
                          ),
                          size: context.responsive(mobile: 18.0, tablet: 19.0, desktop: 20.0),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.responsive(mobile: 8.0, tablet: 10.0, desktop: 12.0)),
                ],
              ),
            ),
          ),
        ),
        const ListDivider(),

        // Expandable Futures Content
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: scripInfo.isFuturesExpanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ListDivider(),
                    Container(
                      padding: EdgeInsets.symmetric(vertical: context.responsive(mobile: 6.0, tablet: 7.0, desktop: 8.0)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            assets.dInfo,
                            color: resolveThemeColor(context,
                                dark: MyntColors.iconDark,
                                light: MyntColors.icon),
                          ),
                          Text(
                            " Long press to add ${scripInfo.wlName}'s Watchlist",
                            style: MyntWebTextStyles.caption(context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary)),
                          ),
                        ],
                      ),
                    ),
                    const FutureScreenWeb(),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // Fundamentals navigation section
  Widget _buildFundamentalsSection(ThemesProvider theme, GetQuotes depthData) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              if (_isDisposed) return;

              await Future.delayed(const Duration(milliseconds: 150));
              final scripInfo = ref.read(marketWatchProvider);
              scripInfo.singlePageloader(true);

              try {
                if (scripInfo.fundamentalData == null ||
                    scripInfo.fundamentalData?.msg == "no data found") {
                  await scripInfo.fetchFundamentalData(
                      tradeSym:
                          "${widget.wlValue.exch}:${widget.wlValue.tsym}");
                }

                if (!mounted) return;

                if (scripInfo.fundamentalData != null &&
                    scripInfo.fundamentalData?.msg != "no data found") {
                  await scripInfo.chngDephBtn("Overview");
                  await Navigator.pushNamed(
                    context,
                    Routes.fundamentalDetail,
                    arguments: {
                      "wlValue": widget.wlValue,
                      "depthData": depthData,
                    },
                  );
                  if (mounted && !_isDisposed) {
                    await scripInfo.chngDephBtn("Overview");
                  }
                }
              } finally {
                if (mounted && !_isDisposed) {
                  scripInfo.singlePageloader(false);
                }
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.responsive(mobile: 12.0, tablet: 14.0, desktop: 16.0)),
              child: Column(
                children: [
                  SizedBox(height: context.responsive(mobile: 8.0, tablet: 10.0, desktop: 12.0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Fundamentals",
                        style: MyntWebTextStyles.para(context),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: shadcn.Theme.of(context)
                            .colorScheme
                            .mutedForeground,
                        size: context.responsive(mobile: 18.0, tablet: 19.0, desktop: 20.0),
                      ),
                    ],
                  ),
                  SizedBox(height: context.responsive(mobile: 8.0, tablet: 10.0, desktop: 12.0)),
                ],
              ),
            ),
          ),
        ),
        const ListDivider(),
      ],
    );
  }

  Widget _buildAccordionItem({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.responsive(mobile: 12.0, tablet: 14.0, desktop: 16.0),
                vertical: context.responsive(mobile: 10.0, tablet: 11.0, desktop: 12.0)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: MyntWebTextStyles.para(context),
                  ),
                  if (showArrow)
                    Icon(
                      Icons.chevron_right,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.iconDark,
                        light: MyntColors.icon,
                      ),
                      size: context.responsive(mobile: 18.0, tablet: 19.0, desktop: 20.0),
                    ),
                ],
              ),
            ),
            const ListDivider(),
          ],
        ),
      ),
    );
  }

  // Info item widget for grid layout (similar to image 2 style)
  Widget _buildInfoItem(ThemesProvider theme, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.responsive(mobile: 0.0, tablet: 0.0, desktop: 0.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: MyntWebTextStyles.para(context,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary,
                )),
          ),
          SizedBox(height: context.responsive(mobile: 4.0, tablet: 5.0, desktop: 6.0)),
          Text(
            value,
            style: MyntWebTextStyles.body(context,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary,
                ),
                fontWeight: MyntFonts.medium),
          ),
          SizedBox(height: context.responsive(mobile: 2.0, tablet: 3.0, desktop: 4.0)),
          Divider(
            color: shadcn.Theme.of(context).colorScheme.border,
          ),
        ],
      ),
    );
  }

  // Add the data widget helper method
  Padding data(String name, String value, ThemesProvider theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.responsive(mobile: 0.0, tablet: 0.0, desktop: 0.0)),
      child: Column(
        children: [
          SizedBox(height: context.responsive(mobile: 6.0, tablet: 7.0, desktop: 8.0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textSecondary)),
              ),
              Text(
                value,
                style: MyntWebTextStyles.body(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                    fontWeight: MyntFonts.medium),
              ),
            ],
          ),
          SizedBox(height: context.responsive(mobile: 8.0, tablet: 9.0, desktop: 10.0)),
          Divider(
            color: shadcn.Theme.of(context).colorScheme.border,
          ),
        ],
      ),
    );
  }
}
