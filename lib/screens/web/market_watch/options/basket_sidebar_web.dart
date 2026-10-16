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
  static const double sidebarWidth = 400; // was 360 — user: slightly wider

  const BasketSidebarWeb({
    super.key,
    required this.onClose,
  });

  @override
  ConsumerState<BasketSidebarWeb> createState() => _BasketSidebarWebState();
}

class _BasketSidebarWebState extends ConsumerState<BasketSidebarWeb> {
  // TC_324.2: ticked rows (Kite style). Sent rows can be ticked to delete only.
  final Set<int> _selected = {};
  String _selectedForBasket = '';

  /// True once any row of this basket has been sent. Rows are then placed
  /// one by one / by selection; a fresh basket keeps the single Place Order.
  bool _isSentMode(OrderProvider p) =>
      p.isBasketPlaced(p.selectedBsktName) ||
      p.bsktScripList.any((e) => e['orderStatus'] != null);

  /// Rows the Place button would send now: ticked unsent rows, else every
  /// unsent row once something was sent, else the whole fresh basket. The
  /// one-segment rule is checked on these only, so a PLACED row from another
  /// segment no longer blocks the rest.
  List _rowsToSend(OrderProvider p) {
    final ticked = _selectedUnsent(p);
    if (ticked.isNotEmpty) return [for (final i in ticked) p.bsktScripList[i]];
    if (_isSentMode(p)) {
      return p.bsktScripList.where((e) => e['orderStatus'] == null).toList();
    }
    return p.bsktScripList;
  }

  List<int> _selectedUnsent(OrderProvider p) => [
        for (final i in _selected)
          if (i < p.bsktScripList.length &&
              p.bsktScripList[i]['orderStatus'] == null)
            i
      ];

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
  // TC_263: mixed segments are allowed in one basket (vendor and Kite
  // allow it; basket margin verified against the vendor on 12 Oct 2026 for
  // NSE+NFO, BSE+NSE+BFO and NSE+NFO+MCX). Returning false removes the
  // "only 1 segment" warning and the Place block. Old check kept below.
  bool _hasMultipleExchanges(List scriptList) => false;
  // bool _hasMultipleExchanges(List scriptList) {
  //   if (scriptList.isEmpty) return false;
  //   Set<String> exchanges = {};
  //   for (var script in scriptList) {
  //     if (script['exch'] != null) {
  //       exchanges.add(script['exch'].toString());
  //     }
  //   }
  //   return exchanges.length > 1;
  // }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final orderProv = ref.watch(orderProvider);
    // Watch WebSocket data to get fresh LTP for basket items
    final socketDatas = ref.watch(websocketProvider).socketDatas;

    // Selection belongs to one basket; drop stale indices after deletes.
    if (_selectedForBasket != orderProv.selectedBsktName) {
      _selected.clear();
      _selectedForBasket = orderProv.selectedBsktName;
    }
    _selected.removeWhere((i) => i >= orderProv.bsktScripList.length);

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
              _hasMultipleExchanges(_rowsToSend(orderProv)))
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
    // The basket margin API rejects some baskets (e.g. more than 20 rows);
    // show "Not available" with its reason instead of a misleading 0.00.
    final marginError = orderProv.bsktScripList.isNotEmpty &&
            orderProv.bsktOrderMargin?.stat != null &&
            orderProv.bsktOrderMargin!.stat != 'Ok'
        ? (orderProv.bsktOrderMargin!.emsg ?? 'Margin not available')
        : null;
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
              Tooltip(
                message: marginError ?? "",
                child: Text(
                  marginError != null
                      ? "Not available"
                      : orderProv.bsktScripList.isEmpty ||
                              orderProv.bsktOrderMargin == null
                          ? "0.00"
                          : orderProv.bsktOrderMargin!.basketMargin.toIndianFormat(),
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    color: shadcn.Theme.of(context).colorScheme.foreground,
                  ),
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
              Tooltip(
                message: marginError ?? "",
                child: Text(
                  marginError != null
                      ? "Not available"
                      : orderProv.bsktScripList.isEmpty ||
                              orderProv.bsktOrderMargin == null
                          ? "0.00"
                          : orderProv.bsktOrderMargin!.postTradeMargin.toIndianFormat(),
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    color: shadcn.Theme.of(context).colorScheme.foreground,
                  ),
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
          subtitle: "Hover over a strike, click Buy or Sell, then Add to Basket",
          assetIcon: assets.documentIcon,
          iconSize: 80,
          primaryEnabled: false,
          secondaryEnabled: false,
        ),
      );
    }

    // Basket items list
    final sentMode = _isSentMode(orderProvider);
    return Expanded(
      child: Column(
        children: [
          // TC_324.2: Select all + Delete (N) line, shown only while rows are ticked.
          if (_selected.isNotEmpty) ...[
            _buildSelectionBar(orderProvider),
            const ListDivider(),
          ],
          Expanded(child: _buildItemsList(theme, orderProvider, socketDatas, sentMode)),
        ],
      ),
    );
  }

  /// TC_324.2: "Select all" + "Delete (N)" line above the list (Kite style),
  /// shown only while rows are ticked.
  Widget _buildSelectionBar(OrderProvider orderProv) {
    final total = orderProv.bsktScripList.length;
    final allTicked = total > 0 && _selected.length == total;
    final isPlacing =
        orderProv.basketOverallStatus[orderProv.selectedBsktName] == 'placing';
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 16, top: 2, bottom: 2),
      child: Row(
        children: [
          _buildRowCheckbox(
            value: allTicked,
            onChanged: (v) => setState(() {
              _selected.clear();
              if (v) _selected.addAll(List.generate(total, (i) => i));
            }),
          ),
          const SizedBox(width: 4),
          Text(
            "Select all",
            style: MyntWebTextStyles.para(
              context,
              color: shadcn.Theme.of(context).colorScheme.mutedForeground,
            ),
          ),
          const Spacer(),
          if (_selected.isNotEmpty)
            InkWell(
              onTap: isPlacing ? null : () => _deleteSelected(orderProv),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: resolveThemeColor(context,
                          dark: MyntColors.lossDark, light: MyntColors.loss),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Delete (${_selected.length})",
                      style: MyntWebTextStyles.para(
                        context,
                        fontWeight: MyntFonts.medium,
                        color: resolveThemeColor(context,
                            dark: MyntColors.lossDark, light: MyntColors.loss),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRowCheckbox(
      {required bool value, required ValueChanged<bool> onChanged}) {
    return SizedBox(
      width: 32,
      height: 32,
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

  Future<void> _deleteSelected(OrderProvider orderProv) async {
    final indices = _selected.toList();
    setState(() => _selected.clear());
    await orderProv.removeBsktScrips(indices, orderProv.selectedBsktName);
    await orderProv.fetchBasketMargin();
    if (mounted) {
      showResponsiveSuccess(context,
          indices.length == 1 ? "Removed from basket" : "${indices.length} items removed from basket");
    }
  }

  Widget _buildItemsList(ThemesProvider theme, OrderProvider orderProvider,
      Map socketDatas, bool sentMode) {
    return ScrollConfiguration(
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

          return _buildScriptCard(
              theme, script, index, orderProvider, socketDatas, sentMode);
        },
          ),
        ),
    );
  }

  Widget _buildScriptCard(ThemesProvider theme, Map script, int index,
      OrderProvider orderProv, Map socketDatas, bool sentMode) {
    // **FIX: Get fresh LTP from WebSocket data instead of stale script['lp']**
    final token = script['token']?.toString();
    final socketData = token != null ? socketDatas[token] : null;
    final freshLtp = socketData?['lp']?.toString() ?? script['lp']?.toString() ?? '0.00';
    final isPlacing =
        orderProv.basketOverallStatus[orderProv.selectedBsktName] == 'placing';
    return InkWell(
      onTap: () => _handleBasketItemTap(index, script, orderProv),
      child: Container(
        padding: EdgeInsets.only(
            left: 8, right: 16, top: 12, bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // One flow (user): tick box on every row from the start; sent rows
            // can be ticked to delete only.
            ...[
              _buildRowCheckbox(
                value: _selected.contains(index),
                onChanged: (v) => setState(() {
                  v ? _selected.add(index) : _selected.remove(index);
                }),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: _buildScriptCardBody(
                  script, index, orderProv, freshLtp, sentMode, isPlacing),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScriptCardBody(Map script, int index, OrderProvider orderProv,
      String freshLtp, bool sentMode, bool isPlacing) {
    return Column(
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
                      // TC_324.1: hover a FAILED/REJECTED badge for the reason,
                      // same as the Executed orders status cell. Empty message
                      // = no tooltip.
                      Tooltip(
                        message: _isRejectedStatus(script['orderStatus'])
                            ? (script['rejectionReason']?.toString().trim() ?? '')
                            : '',
                        child: Container(
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
                      ),
                    // TC_324.2: per-row Place dropped — tick rows, use Place Selected (user, Kite-like).
//                     if (script['orderStatus'] == null && sentMode)
//                       SizedBox(
//                         height: 26,
//                         child: MyntPrimaryButton(
//                           label: "Place",
//                           size: MyntButtonSize.small,
//                           padding: const EdgeInsets.symmetric(horizontal: 12),
//                           onPressed: isPlacing ||
//                                   _hasMultipleExchanges(orderProv.bsktScripList)
//                               ? null
//                               : () => orderProv.placeBasketItems(context, [index]),
//                         ),
//                       ),
                    // Delete button — retired (user: one flow; delete via tick +
                    // Delete (N)). Kept for rollback.
                    if (false &&
                        (script['orderStatus'] == null ||
                            !_isOrderPlaced(script['orderStatus'])))
                      Material(
                        color: Colors.transparent,
                        shape:CircleBorder(),
                        child: InkWell(
                          onTap: () async {
                              if (sentMode) {
                                // Re-saves row statuses after the index shift.
                                setState(() => _selected.clear());
                                await orderProv.removeBsktScrips([index], orderProv.selectedBsktName);
                              } else {
                                await orderProv.removeBsktScrip(index, orderProv.selectedBsktName);
                              }
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

            // Rejection reason — TC_324.1: moved to the status badge tooltip (Kite style).
//             if (script['rejectionReason'] != null &&
//                 script['orderStatus'] == 'failed')
//               Container(
//                 margin: const EdgeInsets.only(top: 6),
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: resolveThemeColor(
//                     context,
//                     dark: MyntColors.lossDark,
//                     light: MyntColors.loss,
//                   ).withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(
//                       Icons.error_outline,
//                       color: resolveThemeColor(
//                         context,
//                         dark: MyntColors.lossDark,
//                         light: MyntColors.loss,
//                       ),
//                       size: 12,
//                     ),
//                     const SizedBox(width: 4),
//                     Expanded(
//                       child: Text(
//                         script['rejectionReason'],
//                         style: MyntWebTextStyles.caption(
//                           context,
//                           darkColor: MyntColors.lossDark,
//                           lightColor: MyntColors.loss,
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
          ],
    );
  }

  Widget _buildPlaceOrderButton(ThemesProvider theme, OrderProvider orderProv) {
    final hasMultipleExchanges = _hasMultipleExchanges(_rowsToSend(orderProv));
    final basketStatus =
        orderProv.basketOverallStatus[orderProv.selectedBsktName] ?? '';
    // TC_324.2: any sent row (not only the overall flag) keeps the sent footer,
    // so a whole-basket Place Order can never re-send old rows.
    final isBasketPlaced = _isSentMode(orderProv);

    // One flow (user): ticked rows -> "Place Selected (N)"; nothing ticked ->
    // "Place Order" for every row not sent yet. Sent rows are never re-sent.
    // "Reset Orders" sits beside it once anything has been sent.
    final isPlacing = basketStatus == 'placing';
    final toPlace = _selectedUnsent(orderProv);
    final onlySentTicked = _selected.isNotEmpty && toPlace.isEmpty;
    final unsent = [
      for (int i = 0; i < orderProv.bsktScripList.length; i++)
        if (orderProv.bsktScripList[i]['orderStatus'] == null) i
    ];
    // Ticked rows that are all sent used to fall back to "every unsent row",
    // placing rows the user had not ticked. Now the button waits for a
    // placeable tick (same as the Orders page basket).
    final primary = Tooltip(
      message: onlySentTicked
          ? "Selected rows are already sent. Reset Orders to place them again."
          : "",
      child: SizedBox(
      height: 45,
      child: MyntPrimaryButton(
        label: isPlacing
            ? "Placing..."
            : toPlace.isNotEmpty
                ? "Place Selected (${toPlace.length})"
                : "Place Order",
        size: MyntButtonSize.large,
        isFullWidth: true,
        isLoading: isPlacing,
        onPressed: hasMultipleExchanges || isPlacing || onlySentTicked
            ? null
            : () async {
                // A basket may hold at most 20 orders; older baskets can
                // still have more.
                final extra =
                    orderProv.bsktScripList.length - orderProv.basketMaxOrders;
                if (extra > 0) {
                  showResponsiveWarning(context,
                      "A basket can have up to ${orderProv.basketMaxOrders} orders. Delete $extra ${extra == 1 ? 'order' : 'orders'} to place.");
                  return;
                }
                if (toPlace.isNotEmpty) {
                  setState(() => _selected.removeAll(toPlace));
                  await orderProv.placeBasketItems(context, toPlace);
                } else if (!isBasketPlaced) {
                  // Fresh basket: original whole-basket path.
                  await orderProv.placeBasketOrder(context,
                      navigateToOrderBook: false);
                } else {
                  await orderProv.placeBasketItems(context, unsent);
                }
              },
        // MyntPrimaryButton has no disabled look, so grey it by hand.
        backgroundColor:
            hasMultipleExchanges || onlySentTicked ? Colors.grey : null,
      ),
    ),
    );
    final reset = SizedBox(
      height: 45,
      child: MyntOutlinedButton(
        label: "Reset Orders",
        size: MyntButtonSize.large,
        isFullWidth: true,
        onPressed: () {
          setState(() => _selected.clear());
          orderProv.resetBasketOrderTracking(orderProv.selectedBsktName);
          showResponsiveSuccess(context, "Basket reset. You can place orders again.");
        },
      ),
    );
    final showPrimary = toPlace.isNotEmpty || unsent.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: !isBasketPlaced
          ? SizedBox(width: double.infinity, child: primary)
          : !showPrimary
              ? SizedBox(width: double.infinity, child: reset)
              : Row(
                  children: [
                    Expanded(child: primary),
                    const SizedBox(width: 8),
                    Expanded(child: reset),
                  ],
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

  bool _isRejectedStatus(String status) {
    final s = status.toLowerCase();
    return s == 'failed' || s == 'rejected';
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
                                        "${basket['curLength']}/${ref.read(orderProvider).basketMaxOrders}",
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
