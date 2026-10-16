/// PERFORMANCE OPTIMIZED: Single virtualized row containing [Call | Strike | Put]
/// This widget is used with ListView.builder to achieve lazy loading of option chain rows.
/// Only visible rows (~20) are built at a time instead of all 200+.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';
import '../../../../models/marketwatch_model/get_quotes.dart';
import '../../../../models/marketwatch_model/opt_chain_model.dart';
import '../../../../models/order_book_model/order_book_model.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../provider/order_provider.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../../res/res.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/snack_bar.dart';
import '../../../../utils/responsive_navigation.dart';
import '../../../../utils/responsive_snackbar.dart';
import '../../../../sharedWidget/hover_actions_web.dart';

/// Data class representing a single strike price row
class StrikeRowData {
  final String strikePrice;
  final bool isATM;
  final OptionValues? callOption;
  final OptionValues? putOption;

  const StrikeRowData({
    required this.strikePrice,
    required this.isATM,
    this.callOption,
    this.putOption,
  });
}

/// Combined option chain row widget for virtualization
/// Contains [Call Cell | Strike Price | Put Cell] in a single row
class OptionChainRowWeb extends ConsumerStatefulWidget {
  final StrikeRowData rowData;
  final Set<String> watchlistTokens;
  final bool showPriceView;
  final bool isBasketMode;
  final SwipeActionController? swipeController;
  final int index;
  final GlobalKey? atmKey; // Key to mark ATM row for scrolling
  final void Function(OptionValues option)? onChartRequested;

  const OptionChainRowWeb({
    super.key,
    required this.rowData,
    required this.watchlistTokens,
    required this.showPriceView,
    required this.isBasketMode,
    this.swipeController,
    required this.index,
    this.atmKey,
    this.onChartRequested,
  });

  @override
  ConsumerState<OptionChainRowWeb> createState() => _OptionChainRowWebState();
}

class _OptionChainRowWebState extends ConsumerState<OptionChainRowWeb> {
  // PERFORMANCE: Use ValueNotifier for hover - no setState rebuilds
  final _isCallHovered = ValueNotifier<bool>(false);
  final _isPutHovered = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isCallHovered.dispose();
    _isPutHovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE FIX: Each row watches ONLY its own token with .select()
    // When token A updates, only row A rebuilds - NOT all 200+ rows!
    // This replaces the 500ms timer that caused 100% CPU with 120 full rebuilds/min
    final callSocketData = widget.rowData.callOption != null
        ? ref.watch(websocketProvider
            .select((p) => p.socketDatas[widget.rowData.callOption!.token]))
        : null;
    final putSocketData = widget.rowData.putOption != null
        ? ref.watch(websocketProvider
            .select((p) => p.socketDatas[widget.rowData.putOption!.token]))
        : null;

    return RepaintBoundary(
      key: widget.atmKey,
      child: Row(
        children: [
          // CALL cell (flex: 6)
          Expanded(
            flex: 6,
            child: _buildCallCell(callSocketData),
          ),
          // STRIKE price cell (fixed width: 150)
          _buildStrikeCell(),
          // PUT cell (flex: 6)
          Expanded(
            flex: 6,
            child: _buildPutCell(putSocketData),
          ),
        ],
      ),
    );
  }

  Widget _buildCallCell(Map<String, dynamic>? socketData) {
    final option = widget.rowData.callOption;
    if (option == null) {
      return const SizedBox.shrink(); 
    }

    // Calculate values from websocket data (with fallbacks)
    final lp =
        socketData?['lp']?.toString() ?? option.lp ?? option.close ?? "0.00";
    final perChange =
        socketData?['pc']?.toString() ?? option.perChange ?? "0.00";
    final currentOI =
        double.tryParse(socketData?['oi']?.toString() ?? option.oi ?? "0") ??
            0.0;
    final oiLack = (currentOI / 100000).toStringAsFixed(2);

    // Calculate OI percentage change
    // Use option.poi as fallback when socket data doesn't have poi yet (during symbol switch)
    final poi = double.tryParse(socketData?['poi']?.toString() ?? option.poi ?? "0") ?? 0.0;
    String oiPerChng = "0.00";
    if (poi > 0) {
      oiPerChng = (((currentOI - poi) / poi) * 100).toStringAsFixed(2);
    }
    // Don't show 100% when poi is 0 - we just don't have the data yet

    final changeColor = perChange.startsWith("-")
        ? resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss)
        : (perChange == "0.00" || perChange == "0.0"
            ? resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary)
            : resolveThemeColor(context,
                dark: MyntColors.profitDark, light: MyntColors.profit));

    // Check watchlist status
    final scripToken = "${option.exch}|${option.token}";
    final isInWatchlist = widget.watchlistTokens.contains(scripToken);

    // PERFORMANCE: MouseRegion for hover, ValueListenableBuilder for minimal rebuilds
    return MouseRegion(
      onEnter: (_) => _isCallHovered.value = true,
      onExit: (_) => _isCallHovered.value = false,
        child: ValueListenableBuilder<bool>(
          valueListenable: _isCallHovered,
          builder: (context, isHovered, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              color: isHovered
                  ? resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary)
                      .withOpacity(0.10)
                  : Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Data row - CALLS: OI/(OI ch) | LTP/(CH)
                  // PERFORMANCE: Keep data visible while showing actions
                  Row(
                    children: [
                      // OI column with OI% below
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              oiLack,
                              textAlign: TextAlign.center,
                              style: MyntWebTextStyles.body(
                                context,
                                fontWeight: FontWeight.w500,
                                color: (oiLack == "0.00" || oiLack == "0.0")
                                    ? resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary)
                                    : resolveThemeColor(context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "(${oiPerChng == "NaN" ? "0.00" : oiPerChng}%)",
                              textAlign: TextAlign.center,
                              style: MyntWebTextStyles.para(
                                context,
                                fontWeight: FontWeight.w400,
                                color: (oiPerChng == "0.00" || oiPerChng == "0.0")
                                    ? resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary)
                                    : (oiPerChng.startsWith("-"))
                                        ? resolveThemeColor(context,
                                            dark: MyntColors.lossDark,
                                            light: MyntColors.loss)
                                        : resolveThemeColor(context,
                                            dark: MyntColors.profitDark,
                                            light: MyntColors.profit),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // LTP column with CH% below
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              lp,
                              textAlign: TextAlign.center,
                              style: MyntWebTextStyles.body(
                                context,
                                fontWeight: FontWeight.w500,
                                color: (lp == "0.00" || lp == "0.0")
                                    ? resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary)
                                    : resolveThemeColor(context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary),
                              ),
                            ),
                            Text(
                              "($perChange%)",
                              textAlign: TextAlign.center,
                              style: MyntWebTextStyles.para(
                                context,
                                fontWeight: FontWeight.w400,
                                color: changeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Hover buttons
                  HoverActionsContainer(
                    isVisible: isHovered,
                    actions: [
                      HoverActionButton.buy(
                        context: context,
                        onPressed: () => _placeOrder(option, true),
                      ),
                      HoverActionButton.sell(
                        context: context,
                        onPressed: () => _placeOrder(option, false),
                      ),
                      HoverActionButton.icon(
                        context: context,
                        iconAsset: assets.chartnew,
                        onPressed: () => _handleChartTap(option),
                      ),
                      HoverActionButton.icon(
                        context: context,
                        iconAsset: isInWatchlist
                            ? assets.bookmarkIcon
                            : assets.bookmarkLineIcon,
                        iconColor: isInWatchlist
                            ? resolveThemeColor(context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary)
                            : null,
                        onPressed: () => _handleSaveToWatchlist(option),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
    );

  }

  Widget _buildStrikeCell() {
    return SizedBox(
      width: 150,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.symmetric(
            vertical: BorderSide(
              color: resolveThemeColor(context,
                  dark: MyntColors.dividerDark, light: MyntColors.divider),
              width: 0.5,
            ),
          ),
        ),
        child: Text(
          widget.rowData.strikePrice,
          style: MyntWebTextStyles.body(
            context,
            fontWeight: FontWeight.w500,
            color: resolveThemeColor(context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildPutCell(Map<String, dynamic>? socketData) {
    final option = widget.rowData.putOption;
    if (option == null) {
      return const SizedBox.shrink();
    }

    // Calculate values from websocket data (with fallbacks)
    final lp =
        socketData?['lp']?.toString() ?? option.lp ?? option.close ?? "0.00";
    final perChange =
        socketData?['pc']?.toString() ?? option.perChange ?? "0.00";
    final currentOI =
        double.tryParse(socketData?['oi']?.toString() ?? option.oi ?? "0") ??
            0.0;
    final oiLack = (currentOI / 100000).toStringAsFixed(2);

    // Calculate OI percentage change
    // Use option.poi as fallback when socket data doesn't have poi yet (during symbol switch)
    final poi = double.tryParse(socketData?['poi']?.toString() ?? option.poi ?? "0") ?? 0.0;
    String oiPerChng = "0.00";
    if (poi > 0) {
      oiPerChng = (((currentOI - poi) / poi) * 100).toStringAsFixed(2);
    }
    // Don't show 100% when poi is 0 - we just don't have the data yet

    final changeColor = perChange.startsWith("-")
        ? resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss)
        : (perChange == "0.00" || perChange == "0.0"
            ? resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary)
            : resolveThemeColor(context,
                dark: MyntColors.profitDark, light: MyntColors.profit));

    // Check watchlist status
    final scripToken = "${option.exch}|${option.token}";
    final isInWatchlist = widget.watchlistTokens.contains(scripToken);

    // PERFORMANCE: MouseRegion for hover, ValueListenableBuilder for minimal rebuilds
    return MouseRegion(
      onEnter: (_) => _isPutHovered.value = true,
      onExit: (_) => _isPutHovered.value = false,
        child: ValueListenableBuilder<bool>(
          valueListenable: _isPutHovered,
          builder: (context, isHovered, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              color: isHovered
                  ? resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary)
                      .withOpacity(0.15)
                  : Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Data row - PUTS: LTP/(CH) | OI/(OI ch)
                  // PERFORMANCE: Keep data visible while showing actions
                  Row(
                    children: [
                      // LTP column with CH% below
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              lp,
                              textAlign: TextAlign.center,
                              style: MyntWebTextStyles.body(
                                context,
                                fontWeight: FontWeight.w500,
                                color: (lp == "0.00" || lp == "0.0")
                                    ? resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary)
                                    : resolveThemeColor(context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary),
                              ),
                            ),
                            Text(
                              "($perChange%)",
                              textAlign: TextAlign.center,
                              style: MyntWebTextStyles.bodySmall(
                                context,
                                fontWeight: FontWeight.w400,
                                color: changeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // OI column with OI% below
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              oiLack,
                              textAlign: TextAlign.center,
                              style: MyntWebTextStyles.body(
                                context,
                                fontWeight: FontWeight.w500,
                                color: (oiLack == "0.00" || oiLack == "0.0")
                                    ? resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary)
                                    : resolveThemeColor(context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary),
                              ),
                            ),
                            Text(
                              "(${oiPerChng == "NaN" ? "0.00" : oiPerChng}%)",
                              textAlign: TextAlign.center,
                              style: MyntWebTextStyles.bodySmall(
                                context,
                                fontWeight: FontWeight.w400,
                                color: (oiPerChng == "0.00" || oiPerChng == "0.0")
                                    ? resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary)
                                    : (oiPerChng.startsWith("-"))
                                        ? resolveThemeColor(context,
                                            dark: MyntColors.lossDark,
                                            light: MyntColors.loss)
                                        : resolveThemeColor(context,
                                            dark: MyntColors.profitDark,
                                            light: MyntColors.profit),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Hover buttons
                  HoverActionsContainer(
                    isVisible: isHovered,
                    actions: [
                      HoverActionButton.sell(
                        context: context,
                        onPressed: () => _placeOrder(option, false),
                      ),
                      HoverActionButton.buy(
                        context: context,
                        onPressed: () => _placeOrder(option, true),
                      ),
                      HoverActionButton.icon(
                        context: context,
                        iconAsset: assets.chartnew,
                        onPressed: () => _handleChartTap(option),
                      ),
                      HoverActionButton.icon(
                        context: context,
                        iconAsset: isInWatchlist
                            ? assets.bookmarkIcon
                            : assets.bookmarkLineIcon,
                        iconColor: isInWatchlist
                            ? resolveThemeColor(context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary)
                            : null,
                        onPressed: () => _handleSaveToWatchlist(option),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
    );
  }

  // void _handleCellTap(OptionValues option, bool isCall) {
  //   if (option.tsym?.contains("|||") ?? false) {
  //     showResponsiveWarningMessage(context, "Symbol not available for trading");
  //     return;
  //   }
  //
  //   if (widget.isBasketMode) {
  //     _handleBasketModeTap(option);
  //   } else {
  //     _handleTap(option, isCall);
  //   }
  // }

  // void _handleTap(OptionValues option, bool isCall) async {
  //   final scripData = ref.read(marketWatchProvider);
  //
  //   await scripData.fetchScripQuoteIndex(
  //     "${option.token}",
  //     "${option.exch}",
  //     context,
  //   );
  //   final quots = scripData.getQuotes;
  //   if (quots != null) {
  //     DepthInputArgs depthArgs = DepthInputArgs(
  //       exch: quots.exch.toString(),
  //       token: quots.token.toString(),
  //       tsym: quots.tsym.toString(),
  //       instname: quots.instname.toString(),
  //       symbol: quots.symbol.toString(),
  //       expDate: quots.expDate.toString(),
  //       option: quots.option.toString(),
  //     );
  //     scripData.scripdepthsize(false);
  //     await scripData.calldepthApis(context, depthArgs, "");
  //   }
  // }

  // Future<void> _handleBasketModeTap(OptionValues option) async {
  //   final scripData = ref.read(marketWatchProvider);
  //   final orderProv = ref.read(orderProvider);
  //
  //   // Check if a basket is selected
  //   if (orderProv.selectedBsktName.isEmpty) {
  //     showResponsiveErrorMessage(context, "Please select a basket");
  //     return;
  //   }
  //
  //   // Preserve current symbol context before basket operations
  //   scripData.preserveContextForBasket();
  //
  //   await scripData.fetchScripQuoteIndex(
  //     "${option.token}",
  //     "${option.exch}",
  //     context,
  //   );
  //   final quots = scripData.getQuotes;
  //
  //   if (quots != null) {
  //     DepthInputArgs depthArgs = DepthInputArgs(
  //       exch: quots.exch.toString(),
  //       token: quots.token.toString(),
  //       tsym: quots.tsym.toString(),
  //       instname: quots.instname.toString(),
  //       symbol: quots.symbol.toString(),
  //       expDate: quots.expDate.toString(),
  //       option: quots.option.toString(),
  //     );
  //
  //     await scripData.calldepthApis(context, depthArgs, "BasketMode");
  //
  //     // Restore original symbol context after basket operations
  //     scripData.restoreContextFromBasket();
  //   }
  // }

  Future<void> _placeOrder(OptionValues option, bool isBuy) async {
    final scripData = ref.read(marketWatchProvider);
    final orderProv = ref.read(orderProvider);

    // In basket mode, check if a basket is selected
    if (widget.isBasketMode) {
      if (orderProv.selectedBsktName.isEmpty) {
        showResponsiveErrorMessage(context, "Please select a basket first");
        return;
      }
    }

    await scripData.fetchScripInfo(
      option.token.toString(),
      option.exch.toString(),
      context,
      true,
    );

    // Use lot size from scripInfoModel if option data doesn't have it
    final lotSize = option.ls?.isNotEmpty == true
        ? option.ls
        : scripData.scripInfoModel?.ls.toString();

    OrderScreenArgs orderArgs = OrderScreenArgs(
      exchange: option.exch.toString(),
      tSym: option.tsym.toString(),
      isExit: false,
      token: option.token.toString(),
      transType: isBuy,
      lotSize: lotSize,
      ltp: "${option.lp ?? option.close ?? 0.00}",
      perChange: option.perChange ?? "0.00",
      orderTpye: '',
      holdQty: '',
      isModify: false,
      raw: {},
    );

    ResponsiveNavigation.toPlaceOrderScreen(
      context: context,
      arguments: {
        "orderArg": orderArgs,
        "scripInfo": scripData.scripInfoModel!,
        // Pass "BasketMode" when in basket mode to show "Add to Basket" button
        "isBskt": widget.isBasketMode ? "BasketMode" : "",
      },
    );
  }


  Future<void> _handleChartTap(OptionValues option) async {
    if (option.tsym?.contains("|||") ?? false) {
      showResponsiveWarningMessage(context, "Symbol not available for trading");
      return;
    }

    final marketWatch = ref.read(marketWatchProvider);

    final depthArgs = DepthInputArgs(
      exch: option.exch?.toString() ?? '',
      token: option.token?.toString() ?? '',
      tsym: option.tsym?.toString() ?? '',
      instname: '',
      symbol: option.symbol?.toString() ?? option.tsym?.toString() ?? '',
      expDate: option.expDate?.toString() ?? '',
      option: option.option?.toString() ?? '',
      isOption: true,
    );

    marketWatch.scripdepthsize(false);
    await marketWatch.calldepthApis(context, depthArgs, "");

    if (!mounted) return;
    widget.onChartRequested?.call(option);
  }

  Future<void> _handleSaveToWatchlist(OptionValues option) async {
    final scripData = ref.read(marketWatchProvider);

    if (scripData.isPreDefWLs == "Yes") {
      showResponsiveWarningMessage(
          context, "This is a pre-defined watchlist that cannot be edited!");
      return;
    }

    final scripToken = "${option.exch}|${option.token}";
    final isCurrentlyInWatchlist = scripData.scrips
        .any((scrip) => "${scrip['exch']}|${scrip['token']}" == scripToken);

    if (isCurrentlyInWatchlist) {
      // Delete from watchlist
      final success = await scripData.addDelMarketScrip(
        scripData.wlName,
        scripToken,
        context,
        false, // delete
        true,
        false,
        false, // Set isOptionStike to false to prevent provider's Fluttertoast
      );
      if (success && mounted) {
        ResponsiveSnackBar.showSuccess(
            context, 'Removed from your watchlist "${scripData.wlName}"');
      }
    } else {
      // Add to watchlist - touchline for web (watchlist tile only needs LTP;
      // depth is reserved for the market-depth panel)
      ref.read(websocketProvider).establishConnection(
            channelInput: scripToken,
            task: "t",
            context: context,
          );

      final success = await scripData.addDelMarketScrip(
        scripData.wlName,
        scripToken,
        context,
        true, // add
        true,
        false,
        false, // Set isOptionStike to false to prevent provider's Fluttertoast
      );
      if (success && mounted) {
        ResponsiveSnackBar.showSuccess(context, 'Added to your watchlist "${scripData.wlName}"');
      }
    }
  }
}
