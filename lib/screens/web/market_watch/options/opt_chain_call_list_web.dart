// REMOVED: dart:async import - no longer using StreamSubscription!
// import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import '../../../../models/marketwatch_model/get_quotes.dart';
import '../../../../models/marketwatch_model/opt_chain_model.dart';
import '../../../../models/order_book_model/order_book_model.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../provider/order_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../../res/res.dart';
import '../../../../res/web_colors.dart';
import '../../../../res/global_font_web.dart';
import '../../../../sharedWidget/list_divider.dart';
import '../../../../utils/responsive_navigation.dart';
import '../../../../sharedWidget/snack_bar.dart';
import '../../../../utils/responsive_snackbar.dart';

class OptChainCallList extends StatelessWidget {
  final List<OptionValues>? callData;
  final bool isCallUp;
  final SwipeActionController? swipe;
  final bool showPriceView;
  final bool isBasketMode;
  // PERFORMANCE FIX: Pre-computed watchlist Set for O(1) lookups
  final Set<String> watchlistTokens;

  const OptChainCallList({
    super.key,
    this.callData,
    this.swipe,
    required this.isCallUp,
    required this.showPriceView,
    required this.isBasketMode,
    required this.watchlistTokens,
  });

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE FIX: Replace ListView.builder with Column to avoid shrinkWrap
    // shrinkWrap: true forces ListView to build ALL items immediately (no lazy loading)
    // Using Column with explicit children is more efficient for small lists
    final items = callData ?? [];
    final children = <Widget>[];

    for (int i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(const ListDivider());
      }
      children.add(_OptionChainCallRow(
        key: ValueKey('call-${items[i].token}'),
        option: items[i],
        swipe: swipe,
        index: i,
        showPriceView: showPriceView,
        isBasketMode: isBasketMode,
        watchlistTokens: watchlistTokens,
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: isCallUp ? children.reversed.toList() : children,
    );
  }
}

class _OptionChainCallRow extends ConsumerStatefulWidget {
  final OptionValues option;
  final SwipeActionController? swipe;
  final int index;
  final bool showPriceView;
  final bool isBasketMode;
  // PERFORMANCE FIX: Pre-computed watchlist Set for O(1) lookups
  final Set<String> watchlistTokens;

  const _OptionChainCallRow({
    super.key,
    required this.option,
    this.swipe,
    required this.index,
    required this.showPriceView,
    required this.isBasketMode,
    required this.watchlistTokens,
  });

  @override
  ConsumerState<_OptionChainCallRow> createState() => _OptionChainCallRowState();
}

class _OptionChainCallRowState extends ConsumerState<_OptionChainCallRow> {
  // PERFORMANCE FIX: Use ValueNotifier instead of setState for hover
  // setState causes full widget rebuild, ValueNotifier only rebuilds hover-dependent parts
  // This reduces event listener recreation and improves performance
  final _isHovered = ValueNotifier<bool>(false);

  // Static variable to track global maximum OI across all CALL options
  static double _globalMaxOI = 0.0;

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE FIX: Each card watches ONLY its own token with .select()
    // When token A updates, only card A rebuilds - NOT all 400 cards!
    // This is the key fix: Parent no longer watches entire socketDatas map
    final socketData = ref.watch(
      websocketProvider.select((p) => p.socketDatas[widget.option.token])
    );

    final scripData = ref.read(marketWatchProvider);
    final theme = ref.read(themeProvider);

    // Calculate values from websocket data (with fallbacks to option model)
    final lp = socketData?['lp']?.toString() ??
              widget.option.lp ??
              widget.option.close ??
              "0.00";
    final perChange = socketData?['pc']?.toString() ??
                     widget.option.perChange ??
                     "0.00";

    // Calculate OI values
    final currentOI = double.tryParse(socketData?['oi']?.toString() ??
                                     widget.option.oi ??
                                     "0") ?? 0.0;
    final oiLack = (currentOI / 100000).toStringAsFixed(2);

    // Calculate OI percentage change
    // Use widget.option.poi as fallback when socket data doesn't have poi yet (during symbol switch)
    final poi = double.tryParse(socketData?['poi']?.toString() ?? widget.option.poi ?? "0") ?? 0.0;
    String oiPerChng = "0.00";
    if (poi > 0) {
      oiPerChng = (((currentOI - poi) / poi) * 100).toStringAsFixed(2);
    }
    // Don't show 100% when poi is 0 - we just don't have the data yet

    // Update global max OI
    if (currentOI > _globalMaxOI) {
      _globalMaxOI = currentOI;
    }

    // PERFORMANCE FIX: O(1) Set lookup instead of O(n) .any() iteration
    // This reduces 50+ iterations per card to a single hash lookup
    final scripToken = "${widget.option.exch}|${widget.option.token}";
    final isInWatchlist = widget.watchlistTokens.contains(scripToken);

    return RepaintBoundary(
      child: SwipeActionCell(
        isDraggable: widget.option.tsym!.contains("|||") ? false : true,
        fullSwipeFactor: 0.7,
        controller: widget.swipe,
        index: widget.index,
        key: ValueKey(widget.option.token),
        leadingActions: [
          SwipeAction(
            performsFirstActionWithFullSwipe: true,
            title: "SELL",
            color: Color(theme.isDarkMode ? 0xfffbbbb6 : 0xfffee8e7),
            style: _getActionStyle(colors.darkred),
            onTap: (handler) async {
              await placeOrderInput(scripData, context, widget.option, false, isBasketMode: widget.isBasketMode);
              handler(false);
            },
          ),
        ],
        trailingActions: [
          SwipeAction(
            performsFirstActionWithFullSwipe: true,
            title: "BUY",
            color: Color(theme.isDarkMode ? 0xffcaedc4 : 0xffedf9eb),
            style: _getActionStyle(colors.ltpgreen),
            onTap: (handler) async {
              await placeOrderInput(scripData, context, widget.option, true, isBasketMode: widget.isBasketMode);
              handler(false);
            },
          ),
        ],
        // PERFORMANCE FIX: Use ValueNotifier for hover - no setState rebuilds
        child: MouseRegion(
          onEnter: (_) => _isHovered.value = true,
          onExit: (_) => _isHovered.value = false,
          child: InkWell(
            onTap: () => {
              widget.option.tsym!.contains("|||")
                  ? _symbolenotFound(context)
                  : widget.isBasketMode
                    ? _handleBasketModeTap(context, widget.option)
                    : _handleTap(context, widget.option)
            },
            // PERFORMANCE FIX: Only hover-dependent UI rebuilds via ValueListenableBuilder
            child: ValueListenableBuilder<bool>(
              valueListenable: _isHovered,
              builder: (context, isHovered, child) {
                return Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  color: isHovered
                      ? (theme.isDarkMode
                          ? MyntColors.primary
                          : MyntColors.primary)
                          .withOpacity(0.15)
                      : Colors.transparent,
                  child: _buildCompleteDataRow(theme, scripData, lp, perChange, oiLack, oiPerChng, currentOI, isInWatchlist, isHovered),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteDataRow(ThemesProvider theme, MarketWatchProvider scripData,
      String lp, String perChange, String oiLack, String oiPerChng, double currentOI, bool isInWatchlist, bool isHovered) {
    final changeColor = perChange.startsWith("-")
        ? (theme.isDarkMode ? MyntColors.loss : MyntColors.loss)
        : (perChange == "0.00" || perChange == "0.0"
            ? (theme.isDarkMode ? MyntColors.textSecondary : MyntColors.textSecondary)
            : (theme.isDarkMode ? MyntColors.profit : MyntColors.profit));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // CALLS column order: OI(ch), OI, CH, LTP (reversed from PUTS)
        Row(
                children: [
                  // OI column - shows OI(ch), OI
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "${oiPerChng == "NaN" ? "0.00" : oiPerChng}%",
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.medium,
                                  color: (oiPerChng.startsWith("-"))
                                      ? resolveThemeColor(
                                          context,
                                          dark: MyntColors.lossDark,
                                          light: MyntColors.loss,
                                        )
                                      : resolveThemeColor(
                                          context,
                                          dark: MyntColors.profitDark,
                                          light: MyntColors.profit,
                                        ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                oiLack,
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
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Price column - shows CH, LTP
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "$perChange%",
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.medium,
                                  color: changeColor,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                lp,
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
                            ),
                          ],
                        ),
                        // const SizedBox(height: 2),
                        // // Green bar for call OI
                        // Align(
                        //   alignment: Alignment.centerLeft,
                        //   child: Container(
                        //     height: 2,
                        //     width: MediaQuery.of(context).size.width * 0.12 * 
                        //         (_currentOI > 0 && _globalMaxOI > 0 
                        //             ? (_currentOI / _globalMaxOI).clamp(0.0, 1.0) 
                        //             : 0.0),
                        //     decoration: BoxDecoration(
                        //       color: theme.isDarkMode ? MyntColors.profit : MyntColors.profit,
                        //       borderRadius: BorderRadius.circular(1),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
        // Buttons positioned on top - aligned to right edge of CALLS column
        if (isHovered)
          Positioned(
            top: 0,
            right: 8,
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHoverButton(
                    label: 'B',
                    color: Colors.white,
                    backgroundColor: theme.isDarkMode ? MyntColors.primary : MyntColors.primary,
                    onPressed: () async {
                      await placeOrderInput(scripData, context, widget.option, true, isBasketMode: widget.isBasketMode);
                    },
                    theme: theme,
                  ),
                  const SizedBox(width: 6),
                  _buildHoverButton(
                    label: 'S',
                    color: Colors.white,
                    backgroundColor: theme.isDarkMode ? MyntColors.tertiary : MyntColors.tertiary,
                    onPressed: () async {
                      await placeOrderInput(scripData, context, widget.option, false, isBasketMode: widget.isBasketMode);
                    },
                    theme: theme,
                  ),
                  const SizedBox(width: 6),
                  _buildHoverButton(
                    icon: Icons.bar_chart,
                    color: Colors.black,
                    backgroundColor: Colors.white,
                    borderRadius: 5.0,
                    onPressed: () async {
                      await _handleChartTap(context, widget.option);
                    },
                    theme: theme,
                  ),
                  const SizedBox(width: 6),
                  _buildHoverButton(
                    svgIcon: isInWatchlist ? assets.bookmarkIcon : assets.bookmarkedIcon,
                    color: isInWatchlist
                        ? (theme.isDarkMode ? MyntColors.primary : MyntColors.primary)
                        : (theme.isDarkMode ? MyntColors.textSecondary : MyntColors.textSecondary),
                    backgroundColor: Colors.white,
                    borderRadius: 5.0,
                    onPressed: () async {
                      await _handleSaveToWatchlist(context, widget.option);
                    },
                    theme: theme,
                  ),
                ],
              ),
          ),
      ],
    );
  }

  Widget _buildDataCell(String value, ThemesProvider theme, {bool isPrimary = false, Color? color}) {
    final displayValue = value == "0.00" || value == "0" ? "0.00" : value;
    final textColor = color ?? (isPrimary 
        ? (theme.isDarkMode ? MyntColors.textPrimary : MyntColors.textPrimary)
        : (theme.isDarkMode ? MyntColors.textSecondary : MyntColors.textSecondary));

    return Text(
      displayValue,
      style: isPrimary 
          ? WebTextStyles.tableDataCompact(
              isDarkTheme: theme.isDarkMode,
              color: textColor,
            )
          : WebTextStyles.tableDataCompact(
              isDarkTheme: theme.isDarkMode,
              color: textColor,
            ),
      textAlign: TextAlign.start,
    );
  }

  Widget _buildHoverButton({
    String? label,
    IconData? icon,
    String? svgIcon,
    required Color color,
    Color? backgroundColor,
    Color? borderColor,
    double? borderRadius,
    required VoidCallback? onPressed,
    required ThemesProvider theme,
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
          splashColor: color.withOpacity(0.15),
          highlightColor: color.withOpacity(0.08),
          onTap: onPressed,
          child: Container(
            padding: isLongLabel ? const EdgeInsets.symmetric(horizontal: 8) : null,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadiusValue),
              border: borderColor != null
                  ? Border.all(
                      color: borderColor,
                      width: 1.3,
                    )
                  : null,
            ),
            child: Center(
              child: svgIcon != null
                  ? SvgPicture.asset(
                      svgIcon,
                      height: 16,
                      width: 16,
                      color: color,
                    )
                  : icon != null
                      ? Icon(
                          icon,
                          size: 16,
                          color: color,
                          weight: 400,
                        )
                      : Text(
                          label ?? "",
                          style: WebTextStyles.buttonXs(
                            isDarkTheme: theme.isDarkMode,
                            color: color,
                          ),
                        ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleChartTap(BuildContext context, OptionValues option) async {
    final scripData = ProviderScope.containerOf(context).read(marketWatchProvider);
    
    await scripData.fetchScripQuoteIndex(
      "${option.token}",
      "${option.exch}",
      context,
    );
    final quots = scripData.getQuotes;
    if (quots != null) {
      DepthInputArgs depthArgs = DepthInputArgs(
        exch: quots.exch.toString(),
        token: quots.token.toString(),
        tsym: quots.tsym.toString(),
        instname: quots.instname.toString(),
        symbol: quots.symbol.toString(),
        expDate: quots.expDate.toString(),
        option: quots.option.toString(),
      );
      scripData.scripdepthsize(false);
      await scripData.calldepthApis(context, depthArgs, "");
    }
  }

  // REMOVED: _checkIfInWatchlist() - no longer needed!
  // Watchlist status is calculated fresh in build() method

  Future<void> _handleSaveToWatchlist(BuildContext context, OptionValues option) async {
    final provider = ProviderScope.containerOf(context);
    final scripData = provider.read(marketWatchProvider);

    if (scripData.isPreDefWLs == "Yes") {
      showResponsiveWarningMessage(context, "This is a pre-defined watchlist that cannot be edited!");
      return;
    }

    final scripToken = "${option.exch}|${option.token}";
    final isCurrentlyInWatchlist = scripData.scrips.any((scrip) => 
      "${scrip['exch']}|${scrip['token']}" == scripToken
    );

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
        ResponsiveSnackBar.showSuccess(context, 'Removed from your watchlist "${scripData.wlName}"');
        setState(() {});
      }
    } else {
      // Add to watchlist - touchline for web (watchlist tile only needs LTP;
      // depth is reserved for the market-depth panel)
      provider.read(websocketProvider).establishConnection(
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
        setState(() {});
      }
    }

    // No need to manually update watchlist status - Riverpod handles it automatically!
  }

  // REMOVED: Old _buildOIData and _buildPriceData methods
  // Data is now passed directly as parameters to _buildCompleteDataRow

  void _symbolenotFound(BuildContext context) {
    showResponsiveWarningMessage(context, "Scrip Not founded");
  }

  void _handleLongPress(BuildContext context, OptionValues option) {
    final provider = ProviderScope.containerOf(context);
    final scripData = provider.read(marketWatchProvider);

    if (scripData.isPreDefWLs == "Yes") {
      Fluttertoast.showToast(
        msg: "This is a pre-defined watchlist that cannot be Added!",
        timeInSecForIosWeb: 2,
        backgroundColor: colors.colorBlack,
        textColor: colors.colorWhite,
        fontSize: 14.0,
      );
    } else {
      // Touchline for web (watchlist tile only needs LTP; depth is reserved
      // for the market-depth panel)
      provider.read(websocketProvider).establishConnection(
            channelInput: "${option.exch}|${option.token}",
            task: "t",
            context: context,
          );
      scripData.addDelMarketScrip(
        scripData.wlName,
        "${option.exch}|${option.token}",
        context,
        true,
        true,
        false,
        true,
      );
    }
  }

  Future<void> _handleTap(BuildContext context, OptionValues option) async {
    final provider = ProviderScope.containerOf(context);
    final scripData = provider.read(marketWatchProvider);

    await scripData.fetchScripQuoteIndex(
      "${option.token}",
      "${option.exch}",
      context,
    );
    final quots = scripData.getQuotes;
    DepthInputArgs depthArgs = DepthInputArgs(
      exch: quots!.exch.toString(),
      token: quots.token.toString(),
      tsym: quots.tsym.toString(),
      instname: quots.instname.toString(),
      symbol: quots.symbol.toString(),
      expDate: quots.expDate.toString(),
      option: quots.option.toString(),
    );
    // Navigator.pop(context);
    await scripData.calldepthApis(context, depthArgs, "");
  }

  Future<void> _handleBasketModeTap(BuildContext context, OptionValues option) async {
    final provider = ProviderScope.containerOf(context);
    final scripData = provider.read(marketWatchProvider);
    final orderProv = provider.read(orderProvider);

    // Check if a basket is selected
    if (orderProv.selectedBsktName.isEmpty) {
      showResponsiveErrorMessage(context, "Please select a basket");
      return;
    }

    // Preserve current symbol context before basket operations
    scripData.preserveContextForBasket();

    await scripData.fetchScripQuoteIndex(
      "${option.token}",
      "${option.exch}",
      context,
    );
    final quots = scripData.getQuotes;
    
    if (quots != null) {
      DepthInputArgs depthArgs = DepthInputArgs(
        exch: quots.exch.toString(),
        token: quots.token.toString(),
        tsym: quots.tsym.toString(),
        instname: quots.instname.toString(),
        symbol: quots.symbol.toString(),
        expDate: quots.expDate.toString(),
        option: quots.option.toString(),
      );
      
      await scripData.calldepthApis(context, depthArgs, "BasketMode");

      // Restore original symbol context after basket operations
      scripData.restoreContextFromBasket();
    }
  }

  static final Map<Color, TextStyle> _actionStyleCache = {};

  static TextStyle _getActionStyle(Color color) {
    return _actionStyleCache.putIfAbsent(
      color,
      () => WebTextStyles.head(
        isDarkTheme: false,
        color: color,
        fontWeight: WebFonts.regular,
      ),
    );
  }

  // REMOVED: _getTextStyle and _getPercentageStyle - no longer needed with new reactive pattern
}

Future<void> placeOrderInput(
  MarketWatchProvider scripInfo,
  BuildContext context,
  OptionValues depthData,
  bool transType, {
  bool isBasketMode = false,
}) async {
  // Obtain a WidgetRef from the context
  final container = ProviderScope.containerOf(context);

  // In basket mode, check if a basket is selected
  if (isBasketMode) {
    final orderProv = container.read(orderProvider);
    if (orderProv.selectedBsktName.isEmpty) {
      showResponsiveErrorMessage(context, "Please select a basket first");
      return;
    }
  }

  await container.read(marketWatchProvider).fetchScripInfo(
        depthData.token.toString(),
        depthData.exch.toString(),
        context,
        true,
      );

  // **FIX: Use lot size from scripInfoModel if option data doesn't have it**
  final lotSize = depthData.ls?.isNotEmpty == true
      ? depthData.ls
      : container.read(marketWatchProvider).scripInfoModel?.ls.toString();

  OrderScreenArgs orderArgs = OrderScreenArgs(
    exchange: depthData.exch.toString(),
    tSym: depthData.tsym.toString(),
    isExit: false,
    token: depthData.token.toString(),
    transType: transType,
    lotSize: lotSize,
    ltp: "${depthData.lp ?? depthData.close ?? 0.00}",
    perChange: depthData.perChange ?? "0.00",
    orderTpye: '',
    holdQty: '',
    isModify: false,
    raw: {},
  );
  ResponsiveNavigation.toPlaceOrderScreen(
    context: context,
    arguments: {
      "orderArg": orderArgs,
      "scripInfo": container.read(marketWatchProvider).scripInfoModel!,
      // Pass "BasketMode" when in basket mode to show "Add to Basket" button
      "isBskt": isBasketMode ? "BasketMode" : "",
    },
  );
}
