import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../../models/order_book_model/order_book_model.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../provider/order_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../../res/res.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../../sharedWidget/snack_bar.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import '../../../../sharedWidget/list_divider.dart';
import '../../../../sharedWidget/no_data_found_web.dart';
import '../../../../sharedWidget/common_buttons_web.dart';
import '../../../../utils/rupee_convert_format.dart';
import '../../../../utils/responsive_navigation.dart';
import '../../ordersbook/basket/create_basket_web.dart';

/// A sidebar widget for basket management in option chain.
/// Appears on the right side when basket mode is enabled.
class BasketSidebarWeb extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  /// Static width of the sidebar
  static const double sidebarWidth = 360;

  const BasketSidebarWeb({
    super.key,
    required this.onClose,
  });

  @override
  ConsumerState<BasketSidebarWeb> createState() => _BasketSidebarWebState();
}

class _BasketSidebarWebState extends ConsumerState<BasketSidebarWeb> {
  @override
  void initState() {
    super.initState();
    // Ensure WebSocket subscriptions are established
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureBasketWebSocketSubscription();
    });
  }

  void _ensureBasketWebSocketSubscription() async {
    final orderProv = ref.read(orderProvider);
    if (orderProv.selectedBsktName.isNotEmpty &&
        orderProv.bsktScripList.isNotEmpty) {
      await orderProv.chngBsktName(orderProv.selectedBsktName, context, true);
      if (kDebugMode) {
      }
    }
  }

  /// Checks if the basket contains scripts from multiple exchanges
  bool _hasMultipleExchanges(List scriptList) {
    if (scriptList.isEmpty) return false;
    Set<String> exchanges = {};
    for (var script in scriptList) {
      if (script['exch'] != null) {
        exchanges.add(script['exch'].toString());
      }
    }
    return exchanges.length > 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final orderProv = ref.watch(orderProvider);
    // Watch WebSocket data to get fresh LTP for basket items
    final socketDatas = ref.watch(websocketProvider).socketDatas;

    // Sidebar content with static width
    return Container(
      width: BasketSidebarWeb.sidebarWidth,
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        border: Border(
          left: BorderSide(
            color: shadcn.Theme.of(context).colorScheme.border,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(theme, orderProv),
          const ListDivider(),

          // Margins section
          if (orderProv.selectedBsktName.isNotEmpty &&
              orderProv.bsktScripList.isNotEmpty)
            _buildMarginsSection(theme, orderProv),

          // Content
          orderProv.bsktList.isEmpty
              ? _buildCreateBasketView(theme, orderProv)
              : _buildBasketContent(theme, orderProv, socketDatas),

          // Multi-exchange warning
          if (orderProv.bsktScripList.isNotEmpty &&
              _hasMultipleExchanges(orderProv.bsktScripList))
            _buildMultiExchangeWarning(),

          // Place Order Button
          if (orderProv.selectedBsktName.isNotEmpty &&
              orderProv.bsktScripList.isNotEmpty)
            _buildPlaceOrderButton(theme, orderProv),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemesProvider theme, OrderProvider orderProv) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderProv.selectedBsktName.isNotEmpty
                      ? orderProv.selectedBsktName
                      : "No Basket Selected",
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.semiBold,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary,
                      )),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4),
                if (orderProv.selectedBsktName.isNotEmpty)
                  Text(
                    "(${orderProv.bsktScripList.length})",
                    style: MyntWebTextStyles.body(
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
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Switch basket icon
              if (orderProv.bsktList.length > 1)
                _buildIconButton(
                  icon: Icons.swap_horiz,
                  tooltip: "Switch Basket",
                  onTap: () => _showBasketSelector(context),
                ),

              // Refresh margin icon
              if (orderProv.selectedBsktName.isNotEmpty &&
                  orderProv.bsktScripList.isNotEmpty)
                _buildIconButton(
                  icon: Icons.refresh,
                  tooltip: "Refresh Margin",
                  onTap: () => orderProv.fetchBasketMargin(),
                ),

              // Add basket icon
              _buildIconButton(
                icon: Icons.add_circle_outline,
                tooltip: "Create new Basket",
                onTap: () => _showCreateBasket(context),
              ),

              // Close sidebar icon
              _buildIconButton(
                icon: Icons.close,
                tooltip: "Close",
                onTap: widget.onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () async {
          await Future.delayed(const Duration(milliseconds: 100));
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        splashColor: resolveThemeColor(
          context,
          dark: MyntColors.rippleDark,
          light: MyntColors.rippleLight,
        ),
        highlightColor: resolveThemeColor(
          context,
          dark: MyntColors.highlightDark,
          light: MyntColors.highlightLight,
        ),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Icon(
              icon,
              size: 20,
              color: resolveThemeColor(
                context,
                dark: MyntColors.iconDark,
                light: MyntColors.icon,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarginsSection(ThemesProvider theme, OrderProvider orderProv) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pre Trade Margin",
                style: MyntWebTextStyles.para(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: shadcn.Theme.of(context).colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                orderProv.bsktScripList.isEmpty ||
                        orderProv.bsktOrderMargin == null
                    ? "0.00"
                    : orderProv.bsktOrderMargin!.basketMargin.toIndianFormat(),
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  color: shadcn.Theme.of(context).colorScheme.foreground,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Post Trade Margin",
                style: MyntWebTextStyles.para(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: shadcn.Theme.of(context).colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                orderProv.bsktScripList.isEmpty ||
                        orderProv.bsktOrderMargin == null
                    ? "0.00"
                    : orderProv.bsktOrderMargin!.postTradeMargin.toIndianFormat(),
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  color: shadcn.Theme.of(context).colorScheme.foreground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiExchangeWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: resolveThemeColor(
          context,
          dark: MyntColors.lossDark,
          light: MyntColors.loss,
        ).withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: resolveThemeColor(
              context,
              dark: MyntColors.lossDark,
              light: MyntColors.loss,
            ),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Basket should contain orders of only 1 segment",
              style: MyntWebTextStyles.caption(
                context,
                fontWeight: MyntFonts.medium,
                darkColor: MyntColors.lossDark,
                lightColor: MyntColors.loss,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateBasketView(ThemesProvider theme, OrderProvider orderProvider) {
    return Expanded(
      child: NoDataFoundWeb(
        title: "No Baskets Found",
        subtitle: "Create a basket to start adding options contracts for trading.",
        assetIcon: assets.documentIcon,
        iconSize: 80,
        primaryLabel: "Create Basket",
        primaryEnabled: true,
        onPrimary: () => _showCreateBasket(context),
        secondaryEnabled: false,
      ),
    );
  }

  Widget _buildBasketContent(ThemesProvider theme, OrderProvider orderProvider, Map socketDatas) {
    // If no basket is selected, show basket selector
    if (orderProvider.selectedBsktName.isEmpty) {
      return Expanded(
        child: NoDataFoundWeb(
          title: "No Basket Selected",
          subtitle: "Choose a basket to view and manage your options contracts.",
          assetIcon: assets.documentIcon,
          iconSize: 80,
          primaryLabel: "Choose Basket",
          primaryEnabled: true,
          onPrimary: () => _showBasketSelector(context),
          secondaryEnabled: false,
        ),
      );
    }

    // If basket is selected but empty
    if (orderProvider.bsktScripList.isEmpty) {
      return Expanded(
        child: NoDataFoundWeb(
          title: "Basket is Empty",
          subtitle: "Click on options to add them to basket",
          assetIcon: assets.documentIcon,
          iconSize: 80,
          primaryEnabled: false,
          secondaryEnabled: false,
        ),
      );
    }

    // Basket items list
    return Expanded(
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
        child: RawScrollbar(
          thumbVisibility: false,
          thickness: 6,
          radius: const Radius.circular(0),
          thumbColor: resolveThemeColor(
            context,
            dark: MyntColors.scrollbarThumbDark,
            light: MyntColors.scrollbarThumbLight,
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: orderProvider.bsktScripList.length,
            separatorBuilder: (_, __) => const ListDivider(),
            itemBuilder: (context, index) {
          final script = Map<String, dynamic>.from(orderProvider.bsktScripList[index]);

          // Process script data for display
          if (script['exch'] == "BFO" && script["dname"] != "null") {
            List<String> splitVal = script["dname"].toString().split(" ");
            script['symbol'] = splitVal[0];
            // BFO: keep dname's day+month, append the year from the tsym. (TC_440)
            script['expDate'] =
                bfoExpiryWithYear(splitVal, script['tsym']?.toString());
            script['option'] =
                splitVal.length > 4 ? "${splitVal[3]} ${splitVal[4]}" : splitVal[3];
          } else {
            Map spilitSymbol = spilitTsym(value: "${script['tsym']}");
            script['symbol'] = "${spilitSymbol["symbol"]}";
            script['expDate'] = "${spilitSymbol["expDate"]}";
            script['option'] = "${spilitSymbol["option"]}";
          }

          return _buildScriptCard(theme, script, index, orderProvider, socketDatas);
        },
          ),
        ),
      ),
    );
  }

  Widget _buildScriptCard(
      ThemesProvider theme, Map script, int index, OrderProvider orderProv, Map socketDatas) {
    // **FIX: Get fresh LTP from WebSocket data instead of stale script['lp']**
    final token = script['token']?.toString();
    final socketData = token != null ? socketDatas[token] : null;
    final freshLtp = socketData?['lp']?.toString() ?? script['lp']?.toString() ?? '0.00';
    return InkWell(
      onTap: () => _handleBasketItemTap(index, script, orderProv),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Symbol and status/delete
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          script['symbol'].toString().replaceAll("-EQ", ""),
                          style: MyntWebTextStyles.symbol(context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              )),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        " ${script['expDate']} ${script['option']}",
                        style: MyntWebTextStyles.symbol(context,
                            color: resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              )),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status badge
                    if (script['orderStatus'] != null)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              _getItemStatusColor(script['orderStatus']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getItemStatusText(script['orderStatus']),
                          style: MyntWebTextStyles.para(
                            context,
                            fontWeight: MyntFonts.medium,
                            color: _getItemStatusColor(script['orderStatus']),
                          ),
                        ),
                      ),
                    // Delete button
                    if (script['orderStatus'] == null ||
                        !_isOrderPlaced(script['orderStatus']))
                      Material(
                        color: Colors.transparent,
                        shape:CircleBorder(),
                        child: InkWell(
                          onTap: () async {
                              await orderProv.removeBsktScrip(index, orderProv.selectedBsktName);
                              await orderProv.fetchBasketMargin();
                              showResponsiveSuccess(context, "Removed from basket");
                            },
                          //  _deleteScript(index, script, orderProv),
                          // borderRadius: BorderRadius.circular(4),/
                          customBorder: CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.lossDark,
                                light: MyntColors.loss,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: Exchange, order type, price type, LTP
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${script["exch"]} · ${script["ordType"]} · ${script["prctype"]}",
                  style: MyntWebTextStyles.exch(
                    context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                  ),
                ),
                Text(
                  "LTP $freshLtp",
                  style: MyntWebTextStyles.exch(
                    context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 3: Buy/Sell, qty, price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      script["trantype"] == "S" ? "SELL" : "BUY",
                      style: MyntWebTextStyles.exch(
                        context,
                        fontWeight: MyntFonts.semiBold,
                        darkColor: script["trantype"] == "S" ? MyntColors.lossDark : MyntColors.primaryDark,
                        lightColor: script["trantype"] == "S" ? MyntColors.loss : MyntColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      () {
                        final rawQty = int.tryParse(script["qty"]?.toString() ?? '0') ?? 0;
                        final ls = int.tryParse(script["ls"]?.toString() ?? '1') ?? 1;
                        final displayQty = script["exch"] == 'MCX' && ls > 1
                            ? (rawQty ~/ ls).toString()
                            : rawQty.toString();
                        return "${script["dscqty"]} / $displayQty";
                      }(),
                      style: MyntWebTextStyles.exch(
                        context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (script["prctype"] != "MKT")
                  Text(
                    "${script['prc'] ?? '0.00'}",
                    style: MyntWebTextStyles.exch(
                      context,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary,
                    ),
                  ),
              ],
            ),

            // Rejection reason
            if (script['rejectionReason'] != null &&
                script['orderStatus'] == 'failed')
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.lossDark,
                    light: MyntColors.loss,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.lossDark,
                        light: MyntColors.loss,
                      ),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        script['rejectionReason'],
                        style: MyntWebTextStyles.caption(
                          context,
                          darkColor: MyntColors.lossDark,
                          lightColor: MyntColors.loss,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceOrderButton(ThemesProvider theme, OrderProvider orderProv) {
    final hasMultipleExchanges = _hasMultipleExchanges(orderProv.bsktScripList);
    final basketStatus =
        orderProv.basketOverallStatus[orderProv.selectedBsktName] ?? '';
    final isBasketPlaced = orderProv.isBasketPlaced(orderProv.selectedBsktName);

    // Show reset button if basket has been placed
    if (isBasketPlaced) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: double.infinity,
          height : 45, 
          child: MyntOutlinedButton(
            label: "Reset Orders",
            size: MyntButtonSize.large,
            isFullWidth: true,
            onPressed: () {
              orderProv.resetBasketOrderTracking(orderProv.selectedBsktName);
              showResponsiveSuccess(context, "Basket reset. You can place orders again.");
            },
          ),
        ),
      );
    }
    // Place order button
    return Padding(
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        height : 45, 
        child: MyntPrimaryButton(
          label: basketStatus == 'placing' ? "Placing..." : "Place Order",
          size: MyntButtonSize.large,
          isFullWidth: true,
          isLoading: basketStatus == 'placing',
          onPressed: hasMultipleExchanges
              ? null
              : basketStatus == 'placing'
                  ? null
                  : () async {
                      await orderProv.placeBasketOrder(context,
                          navigateToOrderBook: false);
                    },
          backgroundColor: hasMultipleExchanges ? Colors.grey : null,
        ),
      ),
    );
  }

  // Helper methods
  Color _getItemStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary);
      case 'complete':
        return resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
      case 'rejected':
      case 'canceled':
      case 'failed':
        return resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);
      case 'open':
      case 'partial':
      case 'trigger_pending':
        return resolveThemeColor(context,
            dark: MyntColors.warning, light: MyntColors.warning);
      default:
        return resolveThemeColor(context,
            dark: MyntColors.iconDark, light: MyntColors.icon);
    }
  }

  String _getItemStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return 'PLACED';
      case 'complete':
        // return 'EXECUTED';
        return 'COMPLETE';
      case 'rejected':
        return 'REJECTED';
      case 'canceled':
        return 'CANCELLED';
      case 'failed':
        return 'FAILED';
      case 'open':
        return 'OPEN';
      case 'partial':
        return 'PARTIAL';
      case 'trigger_pending':
        return 'PENDING';
      default:
        return status.toUpperCase();
    }
  }

  bool _isOrderPlaced(String status) {
    return !['pending', 'draft', 'preparing'].contains(status.toLowerCase());
  }

  void _handleBasketItemTap(int index, Map script, OrderProvider orderProvider) {
    String? orderStatus = script['orderStatus'];
    if (orderStatus != null && _isOrderPlaced(orderStatus)) {
      // Navigate to order book if order is placed
      // _navigateToOrderBook(orderProvider, orderStatus);
    } else {
      // Edit if not placed
      _editScript(index, script, orderProvider);
    }
  }

  void _editScript(int index, Map script, OrderProvider orderProv) async {
    await ref.read(marketWatchProvider).fetchScripInfo(
          "${script['token']}",
          '${script['exch']}',
          context,
          true,
        );

    script['index'] = index;
    script['prctyp'] = script['prctype'];

    if (script['prd'] == null || script['prd'].toString().isEmpty) {
      final ordType = script['ordType']?.toString();
      if (ordType == 'MIS') {
        script['prd'] = 'I';
      } else if (ordType == 'CNC') {
        script['prd'] = 'C';
      } else if (ordType == 'NRML') {
        script['prd'] = 'M';
      }
    }

    final ltp = script['lp']?.toString() ?? "0.00";
    final perChange = script['pc']?.toString() ?? "0.00";

    OrderScreenArgs orderArgs = OrderScreenArgs(
      exchange: '${script['exch']}',
      tSym: '${script['tsym']}',
      isExit: false,
      token: "${script['token']}",
      transType: script['trantype'] == 'B' ? true : false,
      lotSize: ref.read(marketWatchProvider).scripInfoModel?.ls.toString(),
      ltp: ltp,
      perChange: perChange,
      orderTpye: '',
      holdQty: '',
      isModify: true,
      prd: script['prd']?.toString(),
      raw: script,
    );

    ResponsiveNavigation.toPlaceOrderScreen(context: context, arguments: {
      "orderArg": orderArgs,
      "scripInfo": ref.read(marketWatchProvider).scripInfoModel!,
      "isBskt": 'BasketEdit'
    });
  }

  void _deleteScript(int index, Map script, OrderProvider orderProv) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: resolveThemeColor(
        context,
        dark: MyntColors.modalBarrierDark,
        light: MyntColors.modalBarrierLight,
      ),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: Container(
              width: 400,
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.dialogDark,
                  light: MyntColors.dialog,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: shadcn.Theme.of(context).colorScheme.border,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Remove from Basket',
                          style: MyntWebTextStyles.title(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                        ),
                        MyntCloseButton(
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Are you sure you want to remove "${script['symbol']?.toString().replaceAll("-EQ", "")} ${script['expDate']} ${script['option']}"?',
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.body(
                              context,
                              fontWeight: FontWeight.w500,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          MyntButton(
                            type: MyntButtonType.primary,
                            size: MyntButtonSize.large,
                            label: 'Remove',
                            isFullWidth: true,
                            backgroundColor: resolveThemeColor(
                              context,
                              dark: MyntColors.errorDark,
                              light: MyntColors.tertiary,
                            ),
                            onPressed: () async {
                              await orderProv.removeBsktScrip(index, orderProv.selectedBsktName);
                              await orderProv.fetchBasketMargin();
                              Navigator.pop(context);
                              showResponsiveSuccess(context, "Removed from basket");
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  void _showCreateBasket(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: resolveThemeColor(dialogContext,
                dark: MyntColors.backgroundColorDark,
                light: MyntColors.backgroundColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const CreateBasket(),
        ),
      ),
    ).then((_) async {
      await ref.read(orderProvider).getBasketName();
      _ensureBasketWebSocketSubscription();
    });
  }

  void _showBasketSelector(BuildContext context) {
    final orderProv = ref.read(orderProvider);
    final theme = ref.read(themeProvider);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final Map<int, bool> dialogHoveredItems = {};
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 450),
            decoration: BoxDecoration(
              color: resolveThemeColor(dialogContext,
                  dark: MyntColors.backgroundColorDark,
                  light: MyntColors.backgroundColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button (matching create basket style)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  // margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: resolveThemeColor(dialogContext,
                            dark: MyntColors.dividerDark,
                            light: MyntColors.divider),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Select Basket",
                        style: MyntWebTextStyles.title(
                          dialogContext,
                          fontWeight: MyntFonts.semiBold,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          splashColor: theme.isDarkMode
                              ? Colors.white.withOpacity(.15)
                              : Colors.black.withOpacity(.15),
                          highlightColor: theme.isDarkMode
                              ? Colors.white.withOpacity(.08)
                              : Colors.black.withOpacity(.08),
                          onTap: () => Navigator.of(dialogContext).pop(),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: resolveThemeColor(dialogContext,
                                  dark: MyntColors.iconDark,
                                  light: MyntColors.icon),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Basket List
                Flexible(
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior()
                        .copyWith(scrollbars: false),
                    child: RawScrollbar(
                      thumbVisibility: false,
                      thickness: 6,
                      radius: const Radius.circular(0),
                      thumbColor: resolveThemeColor(
                        dialogContext,
                        dark: MyntColors.scrollbarThumbDark,
                        light: MyntColors.scrollbarThumbLight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 10),
                        child: StatefulBuilder(
                          builder: (context, setDialogState) {
                            return ListView.builder(
                              shrinkWrap: true,
                              itemCount: orderProv.bsktList.length,
                              itemBuilder: (itemContext, index) {
                            final basket = orderProv.bsktList[index];
                            final basketName = basket['bsketName'].toString();
                            final isSelected = basketName == orderProv.selectedBsktName;

                            return MouseRegion(
                              onEnter: (_) => setDialogState(() =>
                                  dialogHoveredItems[index] = true),
                              onExit: (_) => setDialogState(() =>
                                  dialogHoveredItems[index] = false),
                              child: InkWell(
                                onTap: () async {
                                  Navigator.pop(dialogContext);
                                  await orderProv.chngBsktName(basketName, context, true);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(
                                      14),
                                  color: (dialogHoveredItems[index] ?? false)
                                      ? resolveThemeColor(
                                          itemContext,
                                          dark: MyntColors.primaryDark,
                                          light: MyntColors.primary,
                                        ).withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  child: Row(
                                    children: [
                                      Icon(
                                        shadcn.LucideIcons.shoppingBasket,
                                        size: 20,
                                        color: isSelected
                                            ? resolveThemeColor(itemContext,
                                                dark: MyntColors.primaryDark,
                                                light: MyntColors.primary)
                                            : resolveThemeColor(itemContext,
                                                dark: MyntColors.iconDark,
                                                light: MyntColors.icon),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          basketName,
                                          style: MyntWebTextStyles.body(
                                            itemContext,
                                            fontWeight: isSelected
                                                ? MyntFonts.semiBold
                                                : MyntFonts.medium,
                                            darkColor: isSelected
                                                ? MyntColors.primaryDark
                                                : MyntColors.textPrimaryDark,
                                            lightColor: isSelected
                                                ? MyntColors.primary
                                                : MyntColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "${basket['curLength']}/${basket['max']}",
                                        style: MyntWebTextStyles.para(
                                          itemContext,
                                          color: resolveThemeColor(
                                            itemContext,
                                            dark: MyntColors.textSecondaryDark,
                                            light: MyntColors.textSecondary,
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
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
