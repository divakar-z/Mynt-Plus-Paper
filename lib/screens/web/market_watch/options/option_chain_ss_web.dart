import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/provider/accessibility_provider.dart';
import 'package:mynt_plus/screens/web/market_watch/options/option_chain_row_web.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import '../../../../models/marketwatch_model/opt_chain_model.dart';
import 'package:mynt_plus/screens/web/ordersbook/basket/create_basket_web.dart';
import '../../../../../provider/websocket_provider.dart';
import '../../../../models/marketwatch_model/get_quotes.dart';
import '../../../../models/order_book_model/order_book_model.dart';
import '../../../../provider/index_list_provider.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../provider/order_provider.dart';
import '../../../../provider/portfolio_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/global_state_text.dart';
import '../../../../res/res.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../../utils/rupee_convert_format.dart';
import '../../../../sharedWidget/custom_drag_handler.dart';
import '../../../../utils/responsive_navigation.dart';
import '../../../../sharedWidget/list_divider.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../../sharedWidget/snack_bar.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import 'basket_sidebar_web.dart';

class OptionChainSSWeb extends ConsumerStatefulWidget {
  final DepthInputArgs wlValue;
  final Function(bool)?
      onBasketModeChanged; // Callback to notify parent of basket mode changes
  final Function(VoidCallback)?
      onToggleCallbackReady; // Callback to provide toggle function to parent
  final VoidCallback?
      onChartRequested; // Notify parent to switch its right-panel to the Chart tab
  // final String isBasket;

  const OptionChainSSWeb({
    super.key,
    required this.wlValue,
    this.onBasketModeChanged,
    this.onToggleCallbackReady,
    this.onChartRequested,
    // required this.isBasket
  });

  @override
  ConsumerState<OptionChainSSWeb> createState() => _OptionChainSSState();
}

class _OptionChainSSState extends ConsumerState<OptionChainSSWeb> {
  String regtoken = "";
  bool showPriceView = true; // true for Price, false for OI
  bool isBasketMode = false; // true for Basket mode, false for normal mode

  // PERFORMANCE FIX: Timer removed! Each row now uses ref.watch() with .select()
  // to reactively update only when its own token data changes.
  // This eliminates 120 rebuilds/min that caused 100% CPU.

  // Expose basket mode state and toggle method for parent widget
  void toggleBasketMode() async {
    // Add delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 150));

    setState(() {
      isBasketMode = !isBasketMode;
    });

    // Notify parent of basket mode change
    widget.onBasketModeChanged?.call(isBasketMode);

    // Load basket data when enabling basket mode
    if (isBasketMode) {
      final orderProv = ref.read(orderProvider);
      await orderProv.getBasketName();

      // If there's a selected basket, ensure WebSocket subscription
      if (orderProv.selectedBsktName.isNotEmpty) {
        await orderProv.chngBsktName(
          orderProv.selectedBsktName,
          context,
          true, // isOpt = true to prevent navigation
        );
      }
    }
  }

  final ScrollController _mainScrollController = ScrollController();
  final GlobalKey _strikePriceKey = GlobalKey();

  late SwipeActionController swipecontroller;

  @override
  void initState() {
    regtoken = widget.wlValue.token;
    FirebaseAnalytics.instance.logScreenView(
      screenName: 'Stock details OC',
      screenClass: 'Option chain',
    );

    swipecontroller = SwipeActionController(selectedIndexPathsChangeCallback:
        (changedIndexPaths, selected, currentCount) {
      setState(() {});
    });
    super.initState();

    // PERFORMANCE FIX: Timer REMOVED to fix 100% CPU issue
    // Each OptionChainRowWeb now uses ref.watch() with .select() for reactive updates
    // Only rows whose token data changes will rebuild (instead of ALL rows every 500ms)

    // Provide toggle callback to parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onToggleCallbackReady?.call(toggleBasketMode);
    });

    // Import the classes to reset global max OI
    // Reset global max OI values when opening option chain
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Reset both call and put global max OI values
      if (kDebugMode) {
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        _scrollToCurrentStrikePrice();
      });
    });
  }

  void _scrollToCurrentStrikePrice() {
    // Use a longer delay to ensure the widget tree is fully built and laid out
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_strikePriceKey.currentContext != null) {
        Scrollable.ensureVisible(
          _strikePriceKey.currentContext!,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
        );
      } else {
        // If context not found on first try, attempt once more with longer delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          if (_strikePriceKey.currentContext != null) {
            Scrollable.ensureVisible(
              _strikePriceKey.currentContext!,
              alignment: 0.5,
              duration: const Duration(milliseconds: 300),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // Timer removed - no longer needed
    if (kDebugMode) {
    }
    // Basket mode lives here; reset the parent's header icon when this chain goes away
    // (tab switch / scrip without options). Deferred: parent can't setState mid-unmount.
    if (isBasketMode) {
      final notifyParent = widget.onBasketModeChanged;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => notifyParent?.call(false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await ref
            .read(marketWatchProvider)
            .calldepthApis(context, widget.wlValue, "");
        await ref
            .read(marketWatchProvider)
            .requestWSOptChain(context: context, isSubscribe: false);
        // Underlying index is subscribed via touchline ("t") now, so tear it
        // down with "u" (depth "ud" is reserved for the market-depth panel).
        await ref.read(websocketProvider).establishConnection(
              channelInput: "${widget.wlValue.exch}|${widget.wlValue.token}",
              task: "u",
              context: context,
            );
        Navigator.pop(context);
      },
      child: Scaffold(
        // appBar: AppBar(
        //   // leading: Consumer(builder: (context, ref, _) {
        //   //   final theme = ref.read(themeProvider);
        //   //   return Material(
        //   //     color: Colors.transparent,
        //   //     shape: const CircleBorder(),
        //   //     clipBehavior: Clip.hardEdge,
        //   //     child: InkWell(
        //   //       customBorder: const CircleBorder(),
        //   //       splashColor: Colors.grey.withOpacity(0.4),
        //   //       highlightColor: Colors.grey.withOpacity(0.2),
        //   //       onTap: () async {
        //   //         // Add delay for visual feedback
        //   //         await Future.delayed(const Duration(milliseconds: 150));

        //   //         final wsProvider = ref.read(websocketProvider);
        //   //         final scripInfo = ref.read(marketWatchProvider);
        //   //         final currentContext = context;
        //   //         Navigator.pop(context);
        //   //         await scripInfo.calldepthApis(
        //   //             currentContext, scripInfo.getQuotes!, "");
        //   //         await scripInfo.requestWSOptChain(
        //   //             context: currentContext, isSubscribe: false);
        //   //         await wsProvider.establishConnection(
        //   //           channelInput:
        //   //               "${widget.wlValue.exch}|${widget.wlValue.token}",
        //   //           task: "ud",
        //   //           context: currentContext,
        //   //         );
        //   //       },
        //   //       child: Container(
        //   //         width: 40,
        //   //         height: 40,
        //   //         alignment: Alignment.center,
        //   //         child: Icon(
        //   //           Icons.arrow_back_ios_outlined,
        //   //           size: 18,
        //   //           color: theme.isDarkMode
        //   //               ? colors.textSecondaryDark
        //   //               : colors.textSecondaryLight,
        //   //         ),
        //   //       ),
        //   //     ),
        //   //   );
        //   // }),
        //   // leadingWidth: 48,
        //  toolbarHeight: 40,
        //   elevation: 0,
        //   title: _NewAppBarTitle(
        //     wlValue: widget.wlValue,
        //     showPriceView: showPriceView,
        //     isBasketMode: isBasketMode,
        //     onToggleView: () async {
        //       // Add delay for visual feedback
        //       await Future.delayed(const Duration(milliseconds: 150));
        //       setState(() {
        //         showPriceView = !showPriceView;
        //       });
        //     },
        //     onToggleBasketMode: () async {
        //       // Add delay for visual feedback
        //       await Future.delayed(const Duration(milliseconds: 150));

        //       // Show the basket bottom sheet

        //       setState(() {
        //         isBasketMode = !isBasketMode;
        //       });

        //       // Load basket data when enabling basket mode
        //       if (isBasketMode) {
        //         final orderProv = ref.read(orderProvider);
        //         await orderProv.getBasketName();

        //         // If there's a selected basket, ensure WebSocket subscription
        //         if (orderProv.selectedBsktName.isNotEmpty) {
        //           await orderProv.chngBsktName(orderProv.selectedBsktName,
        //               context, true // isOpt = true to prevent navigation
        //               );
        //         }
        //       }
        //     },
        //     scrollToStrikePrice: _scrollToCurrentStrikePrice,
        //   ),
        // ),
        body: SafeArea(
          child: Row(
            children: [
              // Main option chain content (expands to fill available space)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Column headers
                    _ColumnHeaders(
                      scrollToStrikePrice: _scrollToCurrentStrikePrice,
                      showPriceView: showPriceView,
                      onToggleView: () async {
                        await Future.delayed(const Duration(milliseconds: 150));
                        setState(() {
                          showPriceView = !showPriceView;
                        });
                      },
                    ),

                    // Option chain data - main content
                    Expanded(
                      child: _OptionChainContent(
                        strikePriceKey: _strikePriceKey,
                        mainScrollController: _mainScrollController,
                        swipecontroller: swipecontroller,
                        showPriceView: showPriceView,
                        isBasketMode: isBasketMode,
                        onChartRequested: widget.onChartRequested,
                      ),
                    ),
                  ],
                ),
              ),

              // Basket sidebar (animated slide-in from right)
              ClipRect(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: isBasketMode ? BasketSidebarWeb.sidebarWidth : 0,
                  child: isBasketMode
                      ? BasketSidebarWeb(
                          onClose: toggleBasketMode,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// New App Bar Title with Symbol, Expiry Dropdown, and Search with Price/OI toggle
class _NewAppBarTitle extends ConsumerWidget {
  final DepthInputArgs wlValue;
  final bool showPriceView;
  final bool isBasketMode;
  final VoidCallback onToggleView;
  final VoidCallback onToggleBasketMode;
  final VoidCallback scrollToStrikePrice;

  const _NewAppBarTitle({
    required this.wlValue,
    required this.showPriceView,
    required this.isBasketMode,
    required this.onToggleView,
    required this.onToggleBasketMode,
    required this.scrollToStrikePrice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // REMOVED: Dead code - scripInfo was watched but never used (returns const Row)
    // final scripInfo = ref.watch(marketWatchProvider);
    final theme = ref.read(themeProvider);

    return const Row(
      children: [
        // Symbol Name and Expiry Dropdown
        // Row(
        //   children: [
        //     Text(
        //       wlValue.tsym.toUpperCase(),
        //       style: WebTextStyles.custom(
        //         fontSize: 13,
        //         isDarkTheme: theme.isDarkMode,
        //         color: theme.isDarkMode
        //             ? WebDarkColors.textPrimary
        //             : WebColors.textPrimary,
        //         fontWeight: FontWeight.w700,
        //       ),
        //     ),
        //     const SizedBox(width: 8),
        //     Theme(
        //       data: Theme.of(context).copyWith(
        //         popupMenuTheme: PopupMenuThemeData(
        //           shape: RoundedRectangleBorder(
        //             borderRadius: BorderRadius.circular(8),
        //           ),
        //         ),
        //       ),
        //       child: DropdownButtonHideUnderline(
        //         child: DropdownButton<String>(
        //           value: scripInfo.selectedExpDate,
        //           isExpanded: false,
        //           isDense: true,
        //           dropdownColor: theme.isDarkMode
        //               ? WebDarkColors.surface
        //               : WebColors.surface,
        //           icon: Icon(
        //             Icons.arrow_drop_down,
        //             color:
        //                 theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textPrimary,
        //             size: 20,
        //           ),
        //           style: WebTextStyles.custom(
        //             fontSize: 13,
        //             isDarkTheme: theme.isDarkMode,
        //             color: theme.isDarkMode
        //                 ? WebDarkColors.textPrimary
        //                 : WebColors.textPrimary,
        //             fontWeight: FontWeight.w700,
        //           ),
        //           items: scripInfo.sortDate.map((String date) {
        //             return DropdownMenuItem<String>(
        //               value: date,
        //               child: Text(
        //                 date.replaceAll("-", " "),
        //                 style: WebTextStyles.custom(
        //                   fontSize: 13,
        //                   isDarkTheme: theme.isDarkMode,
        //                   color: theme.isDarkMode
        //                       ? WebDarkColors.textPrimary
        //                       : WebColors.textPrimary,
        //                       fontWeight: FontWeight.w700,
        //                 ),
        //               ),
        //             );
        //           }).toList(),
        //           onChanged: (String? newValue) async {
        //             if (newValue != null) {
        //               for (var i = 0; i < scripInfo.optExp!.length; i++) {
        //                 if (newValue == scripInfo.optExp![i].exd) {
        //                   scripInfo.selecTradSym("${scripInfo.optExp![i].tsym}");
        //                   scripInfo.optExch("${scripInfo.optExp![i].exch}");
        //                 }
        //               }
        //               scripInfo.selecexpDate(newValue);

        //               await ref.read(marketWatchProvider).fetchOPtionChain(
        //                   context: context,
        //                   exchange: scripInfo.optionExch!,
        //                   numofStrike: scripInfo.numStrike,
        //                   strPrc: scripInfo.optionStrPrc,
        //                   tradeSym: scripInfo.selectedTradeSym!);

        //               Future.delayed(const Duration(milliseconds: 300), () {
        //                 scrollToStrikePrice();
        //               });
        //             }
        //           },
        //         ),
        //       ),
        //     ),
        //   ],
        // ),

        // const Spacer(),

        // Price/OI Toggle Button
        // Material(
        //   color: Colors.transparent, // Important to allow ripple to show
        //   child: InkWell(
        //     borderRadius:
        //         BorderRadius.circular(4), // Optional: match container shape
        //     splashColor: theme.isDarkMode
        //         ? colors.splashColorDark
        //         : colors.splashColorLight,
        //     highlightColor:
        //         theme.isDarkMode ? colors.highlightDark : colors.highlightLight,
        //     onTap: onToggleView,
        //     child: Container(
        //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        //       child: TextWidget.subText(
        //         text: showPriceView ? "Price" : "OI",
        //         color: theme.isDarkMode
        //             ? colors.secondaryDark
        //             : colors.secondaryLight,
        //         theme: theme.isDarkMode,
        //       ),
        //     ),
        //   ),
        // ),

        // const SizedBox(width: 4),

        // Basket Toggle Icon
        // InkWell(
        //   borderRadius: BorderRadius.circular(20),
        //   splashColor: theme.isDarkMode
        //       ? Colors.white.withOpacity(0.1)
        //       : Colors.black.withOpacity(0.1),
        //   highlightColor:
        //       theme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        //   onTap: onToggleBasketMode,
        //   child: Padding(
        //     padding: const EdgeInsets.all(8),
        //     child: Icon(
        //       isBasketMode
        //           ? Icons.shopping_basket
        //           : Icons.shopping_basket_outlined,
        //       size: 18,
        //       color: isBasketMode
        //           ?  WebColors.primary
        //           : (theme.isDarkMode ? WebDarkColors.iconSecondary : WebColors.iconSecondary),
        //     ),
        //   ),
        // ),

        // const SizedBox(width: 4),

        // // Search Icon
        // InkWell(
        //   borderRadius: BorderRadius.circular(20),
        //   splashColor: theme.isDarkMode
        //       ? Colors.white.withOpacity(0.1)
        //       : Colors.black.withOpacity(0.1),
        //   highlightColor:
        //       theme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        //   onTap: () async {
        //     // Add delay for visual feedback
        //     await Future.delayed(const Duration(milliseconds: 150));

        //     showDialog(
        //       context: context,
        //       barrierColor: Colors.transparent,
        //       builder: (BuildContext context) {
        //         return SearchDialogWeb(
        //           wlName: ref.read(marketWatchProvider).wlName,
        //           isBasket: "Option||Replace",
        //         );
        //       },
        //     );
        //   },
        //   child: Padding(
        //     padding: const EdgeInsets.all(8),
        //     child: SvgPicture.asset(
        //       assets.searchIcon,
        //       width: 18,
        //       height: 18,
        //     ),
        //   ),
        // )
      ],
    );
  }
}

// Helper function to avoid duplicating the showStrikeCountSelector code
void _showStrikeCountSelector(
    BuildContext context,
    WidgetRef ref,
    MarketWatchProvider scripInfo,
    ThemesProvider theme,
    VoidCallback scrollToStrikePrice) {
  showModalBottomSheet(
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      context: context,
      builder: (context) => SafeArea(
            child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  color: resolveThemeColor(context,
                      dark: MyntColors.backgroundColorDark,
                      light: MyntColors.backgroundColor),
                  border: Border(
                    top: BorderSide(
                        color: shadcn.Theme.of(context).colorScheme.border),
                    left: BorderSide(
                      color: shadcn.Theme.of(context).colorScheme.border,
                    ),
                    right: BorderSide(
                      color: shadcn.Theme.of(context).colorScheme.border,
                    ),
                  ),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // const CustomDragHandler(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Select Number of Strike",
                                style: MyntWebTextStyles.title(context,
                                    fontWeight: MyntFonts.semiBold)),
                            Material(
                              color: Colors.transparent,
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () async {
                                  await Future.delayed(
                                      const Duration(milliseconds: 150));
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(20),
                                splashColor: shadcn.Theme.of(context)
                                    .colorScheme
                                    .accent
                                    .withOpacity(0.15),
                                highlightColor: shadcn.Theme.of(context)
                                    .colorScheme
                                    .accent
                                    .withOpacity(0.08),
                                child: Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 22,
                                    color: shadcn.Theme.of(context)
                                        .colorScheme
                                        .mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        color: shadcn.Theme.of(context).colorScheme.border,
                        height: 0,
                      ),
                      Flexible(
                          child: ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              physics: const ClampingScrollPhysics(),
                              itemBuilder: (context, index) {
                                return ListTile(
                                    onTap: () async {
                                      scripInfo.selecNumStrike(
                                          scripInfo.numStrikes[index]);

                                      // First close the modal
                                      Navigator.pop(context);

                                      // Then fetch data with the new strike count
                                      await ref
                                          .read(marketWatchProvider)
                                          .fetchOPtionChain(
                                              context: context,
                                              exchange: scripInfo.optionExch!,
                                              numofStrike:
                                                  scripInfo.numStrikes[index],
                                              strPrc: scripInfo.optionStrPrc,
                                              tradeSym:
                                                  scripInfo.selectedTradeSym!);

                                      // Use a longer delay to ensure data is loaded and widgets are built
                                      Future.delayed(
                                          const Duration(milliseconds: 500),
                                          () {
                                        if (context.mounted) {
                                          // Use the callback to main screen's scroll method
                                          scrollToStrikePrice();
                                        }
                                      });
                                    },
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 0),
                                    dense: true,
                                    title: Text(scripInfo.numStrikes[index],
                                        style: MyntWebTextStyles.body(
                                          context,
                                          color: scripInfo.numStrike ==
                                                  scripInfo.numStrikes[index]
                                              ? shadcn.Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : shadcn.Theme.of(context)
                                                  .colorScheme
                                                  .mutedForeground,
                                          fontWeight: scripInfo.numStrike ==
                                                  scripInfo.numStrikes[index]
                                              ? MyntFonts.semiBold
                                              : MyntFonts.regular,
                                        )),
                                    trailing: SvgPicture.asset(theme.isDarkMode
                                        ? scripInfo.numStrike ==
                                                scripInfo.numStrikes[index]
                                            ? assets.darkActProductIcon
                                            : assets.darkProductIcon
                                        : scripInfo.numStrike ==
                                                scripInfo.numStrikes[index]
                                            ? assets.actProductIcon
                                            : assets.productIcon));
                              },
                              separatorBuilder: (context, index) {
                                return const ListDivider();
                              },
                              shrinkWrap: true,
                              itemCount: scripInfo.numStrikes.length))
                    ])),
          ));
}

// Helper function to show strikes dropdown using shadcn.showPopover (matching watchlist filter style)
void _showStrikesDropdown(
    BuildContext context,
    WidgetRef ref,
    MarketWatchProvider scripInfo,
    ThemesProvider theme,
    VoidCallback scrollToStrikePrice) {
  final numStrikes = scripInfo.numStrikes;
  final numStrike = scripInfo.numStrike;

  shadcn.showPopover(
    context: context,
    alignment: Alignment.bottomCenter,
    offset: const Offset(0, 4),
    overlayBarrier: shadcn.OverlayBarrier(
      borderRadius: shadcn.Theme.of(context).borderRadiusLg,
    ),
    builder: (popoverContext) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: shadcn.Theme.of(popoverContext).borderRadiusLg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: shadcn.ModalContainer(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 150,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: numStrikes.map((String value) {
                  final isSelected = value == numStrike;
                  return _buildStrikeMenuItem(
                    popoverContext,
                    value,
                    isSelected,
                    () async {
                      shadcn.closeOverlay(popoverContext);
                      scripInfo.selecNumStrike(value);
                      await scripInfo.fetchOPtionChain(
                        context: context,
                        exchange: scripInfo.optionExch!,
                        numofStrike: value,
                        strPrc: scripInfo.optionStrPrc,
                        tradeSym: scripInfo.selectedTradeSym!,
                      );

                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (context.mounted) {
                          scrollToStrikePrice();
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildStrikeMenuItem(
  BuildContext context,
  String title,
  bool isActive,
  VoidCallback onTap,
) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: isActive ? MyntFonts.semiBold : MyntFonts.medium,
                  color: isActive
                      ? resolveThemeColor(
                          context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
                        )
                      : resolveThemeColor(
                          context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary,
                        ),
                ),
              ),
            ),
            if (isActive)
              Icon(
                Icons.check,
                size: 18,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.primaryDark,
                  light: MyntColors.primary,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// Widget for column headers - updated to ConsumerWidget
class _ColumnHeaders extends ConsumerWidget {
  final VoidCallback scrollToStrikePrice;
  final bool showPriceView;
  final VoidCallback onToggleView;

  const _ColumnHeaders({
    required this.scrollToStrikePrice,
    required this.showPriceView,
    required this.onToggleView,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PERFORMANCE FIX: Watch only specific fields instead of entire provider
    final numStrikes =
        ref.watch(marketWatchProvider.select((p) => p.numStrikes));
    final numStrike = ref.watch(marketWatchProvider.select((p) => p.numStrike));

    // Use ref.read() for everything else
    final scripInfo = ref.read(marketWatchProvider);
    final theme = ref.read(themeProvider);

    return RepaintBoundary(
      child: Container(
        // padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        // color: resolveThemeColor(context,
        //     dark: MyntColors.backgroundColorDark,
        //     light: MyntColors.backgroundColor),
        child: Column(
          children: [
            // Main header row with blue background
            Container(
              height: 35,
              decoration: BoxDecoration(
                // color: resolveThemeColor(context,
                //     dark: Color(0xFFF1F3F8),
                //     light: MyntColors.primary.withValues(alpha: 0.07)),
                    border: Border(
                      bottom: BorderSide(
                        color: resolveThemeColor(context,
                            dark: MyntColors.dividerDark,
                            light: MyntColors.primary.withValues(alpha: 0.07)),
                      ),
                    ),
              ),
              child: Row(
                children: [
                  // CALLS header
                  Expanded(
                    flex: 6,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "CALL",
                          style: MyntWebTextStyles.body(context,
                              fontWeight: MyntFonts.medium,
                              color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                  // STRIKES header - MOVED TO SECONDARY HEADER
                  // SizedBox(
                  //   width: 150,
                  //   child: Builder(
                  //     builder: (context) => Material(
                  //       color: Colors.transparent,
                  //       child: InkWell(
                  //         onTap: () => _showStrikesDropdown(context, ref,
                  //             scripInfo, theme, scrollToStrikePrice),
                  //         borderRadius: BorderRadius.circular(5),
                  //         child: Padding(
                  //           padding: const EdgeInsets.all(6.0),
                  //           child: Row(
                  //             mainAxisAlignment: MainAxisAlignment.center,
                  //             children: [
                  //               Text(
                  //                 "STRIKES",
                  //                 style: MyntWebTextStyles.body(context,
                  //                     fontWeight: MyntFonts.medium),
                  //               ),
                  //               const SizedBox(width: 6),
                  //               Icon(
                  //                 Icons.arrow_drop_down,
                  //                 size: 20,
                  //                 color: shadcn.Theme.of(context)
                  //                     .colorScheme
                  //                     .mutedForeground,
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  Container(
                    width: 150,
                    alignment: Alignment.center,
                    child: Text(
                      "STRIKES",
                      style: MyntWebTextStyles.body(context,
                          fontWeight: MyntFonts.medium,
                          color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)),
                    ),
                  ),
                  // PUTS header
                  Expanded(
                    flex: 6,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "PUT",
                          style: MyntWebTextStyles.body(context,
                              fontWeight: MyntFonts.medium,
                              color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // const SizedBox(height: 8),
            // Sub-header row for Price and OI
            // Row(
            //   children: [
            //     Expanded(
            //       flex: 6,
            //       child: Padding(
            //         padding: const EdgeInsets.symmetric(horizontal: 8),
            //         child: Row(
            //           mainAxisAlignment: MainAxisAlignment.spaceAround,
            //           children: [
            //             _buildSubHeader(context, ref, "Price", theme),
            //             _buildSubHeader(context, ref, "OI", theme),
            //           ],
            //         ),
            //       ),
            //     ),
            //     const SizedBox(width: 150),
            //     Expanded(
            //       flex: 6,
            //       child: Padding(
            //         padding: const EdgeInsets.symmetric(horizontal: 8),
            //         child: Row(
            //           mainAxisAlignment: MainAxisAlignment.spaceAround,
            //           children: [
            //             _buildSubHeader(context, ref, "Price", theme),
            //             _buildSubHeader(context, ref, "OI", theme),
            //           ],
            //         ),
            //       ),
            //     ),
            //   ],
            // ),
            Container(
              // color: resolveThemeColor(context,
              //     dark: Color(0xFFF1F3F8),
              //     light: Color(0xFFF1F3F8)),

              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: resolveThemeColor(context,
                        dark: MyntColors.dividerDark,
                        light: MyntColors.primary.withValues(alpha: 0.07)),
                  ),
                ),
              ),
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // CALLS sub-headers: OI/(OI ch) | LTP/(CH)
                  Expanded(
                    flex: 6,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStackedSubHeader(
                              context, ref, "OI", "OI ch", theme),
                        ),
                        Expanded(
                          child: _buildStackedSubHeader(
                              context, ref, "LTP", "CH", theme),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 150),
                  // PUTS sub-headers: LTP/(CH) | OI/(OI ch)
                  Expanded(
                    flex: 6,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStackedSubHeader(
                              context, ref, "LTP", "CH", theme),
                        ),
                        Expanded(
                          child: _buildStackedSubHeader(
                              context, ref, "OI", "OI ch", theme),
                        ),
                      ],
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

  Widget _buildStackedSubHeader(BuildContext context, WidgetRef ref,
      String topText, String bottomText, ThemesProvider theme) {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            topText,
            style: MyntWebTextStyles.para(
              context,
              fontWeight: MyntFonts.medium,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            "($bottomText)",
            style: MyntWebTextStyles.para(
              context,
              fontWeight: MyntFonts.regular,
              color: resolveThemeColor(context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Widget for predefined watchlist banner (conditional)
class _PreDefinedWatchlistBanner extends ConsumerWidget {
  const _PreDefinedWatchlistBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PERFORMANCE FIX: Watch only the specific field we need
    final isPreDefWLs =
        ref.watch(marketWatchProvider.select((p) => p.isPreDefWLs));
    final theme = ref.read(themeProvider);

    if (isPreDefWLs == "Yes") {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                    dark: MyntColors.primaryDark, light: MyntColors.primary)
                .withValues(alpha: 0.1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SvgPicture.asset(assets.dInfo, color: MyntColors.primary),
            Text(
              " Long press to add Watchlist / Swipe to Trade",
              style: MyntWebTextStyles.bodySmall(context,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary,
                  )),
            ),
          ])),
    );
  }
}

// Widget for the main option chain content
class _OptionChainContent extends ConsumerStatefulWidget {
  final GlobalKey strikePriceKey;
  final ScrollController mainScrollController;
  final SwipeActionController swipecontroller;
  final bool showPriceView;
  final bool isBasketMode;
  final VoidCallback? onChartRequested;

  const _OptionChainContent({
    required this.strikePriceKey,
    required this.mainScrollController,
    required this.swipecontroller,
    required this.showPriceView,
    required this.isBasketMode,
    this.onChartRequested,
  });

  @override
  ConsumerState<_OptionChainContent> createState() =>
      _OptionChainContentState();
}

class _OptionChainContentState extends ConsumerState<_OptionChainContent> {
  // Track if initial scroll to ATM has been done (prevents scroll reset on every rebuild)
  bool _hasScrolledInitially = false;
  // Track the last numStrike to detect when strike selection changes
  int? _lastNumStrike;

  @override
  Widget build(BuildContext context) {
    // CRITICAL FIX: Use .select() to watch ONLY the specific fields we need
    // This prevents rebuilding the entire option chain when socket data updates
    final isLoad = ref.watch(marketWatchProvider.select((p) => p.isLoad));
    final optChainCallUP =
        ref.watch(marketWatchProvider.select((p) => p.optChainCallUP));
    final optChainPutUp =
        ref.watch(marketWatchProvider.select((p) => p.optChainPutUp));
    final optChainCallDown =
        ref.watch(marketWatchProvider.select((p) => p.optChainCallDown));
    final optChainPutDown =
        ref.watch(marketWatchProvider.select((p) => p.optChainPutDown));
    final depthData =
        ref.watch(marketWatchProvider.select((p) => p.getQuotes))!;

    // Watch numStrike to detect when strike selection changes
    final numStrike = ref.watch(marketWatchProvider.select((p) => p.numStrike));

    // Reset scroll flag when strike selection changes (e.g., "Near 5" -> "All")
    // This ensures scroll to ATM happens after changing strike count
    // Note: numStrike can be "5", "10", "15", or "All" - use hashCode for "All"
    final currentNumStrike = numStrike == "All" ? -1 : (int.tryParse(numStrike) ?? 0);
    if (_lastNumStrike != null && currentNumStrike != _lastNumStrike) {
      _hasScrolledInitially = false;
    }
    _lastNumStrike = currentNumStrike;

    // PERFORMANCE FIX: Do NOT watch socketDatas at parent level!
    // When parent watches entire socketDatas map, ANY token update causes:
    //   Parent rebuild → passes new map to children → ALL 400 cards rebuild
    // Instead, each card watches ONLY its own token with .select()
    // This way, token A update → only card A rebuilds (not all 400)

    // Use ref.read() for providers that don't affect rebuilds
    final scripInfo = ref.read(marketWatchProvider);
    final theme = ref.read(themeProvider);

    // PERFORMANCE FIX: Create watchlist token Set ONCE here, pass down to children
    // This replaces expensive .any() O(n) iterations in each of 200+ option cards
    // with O(1) Set.contains() lookups - reduces 10,000+ iterations to ~200
    final watchlistTokens = scripInfo.scrips
        .map((scrip) => "${scrip['exch']}|${scrip['token']}")
        .toSet();

    // Determine if data is fully loaded
    // Note: scripDepthloader is excluded because it's set when updating depth panel,
    // not when reloading option chain data
    // FIX: Don't require ALL lists to have data - API may return strikes only on one side of LTP
    // Just check if we have ANY option data (from either UP or DOWN lists)
    final bool hasCallData = optChainCallUP.isNotEmpty || optChainCallDown.isNotEmpty;
    final bool hasPutData = optChainPutUp.isNotEmpty || optChainPutDown.isNotEmpty;
    final bool isLoading = isLoad || (!hasCallData && !hasPutData);

    if (isLoading) {
      // Re-arm the ATM scroll so the reloaded chain (e.g. new scrip) re-centres once
      _hasScrolledInitially = false;
      // Create a timeout to handle cases where loading gets stuck
      return FutureBuilder(
          future: Future.delayed(const Duration(seconds: 5)),
          builder: (context, snapshot) {
            // If the timeout completes and we're still loading, show a retry option
            if (snapshot.connectionState == ConnectionState.done) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextWidget.subText(
                      text: "Data loading is taking longer than expected",
                      color: const Color(0xff666666),
                      theme: false,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        // Reset loading state
                        ref.read(marketWatchProvider).singlePageloader(true);

                        // Retry fetching data
                        if (scripInfo.oactiveTab != null) {
                          ref.read(marketWatchProvider).setOptionScript(
                                context,
                                scripInfo.oactiveTab!.exch.toString(),
                                scripInfo.oactiveTab!.token.toString(),
                                scripInfo.oactiveTab!.tsym.toString(),
                              );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff0037B7),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: TextWidget.paraText(
                          text: "Retry",
                          color: Colors.white,
                          theme: false,
                          fw: 0),
                    ),
                  ],
                ),
              );
            }

            // Show loading indicator while waiting
            return Center(
                child: MyntLoader.simple());
          });
    }

    // PERFORMANCE OPTIMIZATION: Build strike-based data structure for virtualization
    // This replaces the old Column-based layout with ListView.builder
    // Only ~20 visible rows are built instead of all 200+

    // Step 1: Build Maps for O(1) lookup of call/put options by strike price
    final Map<String, OptionValues> callOptionsMap = {};
    final Map<String, OptionValues> putOptionsMap = {};
    final Set<String> strikeSet = {};

    // Add UP data (above ATM)
    for (final call in optChainCallUP) {
      final strike = call.strprc ?? '';
      if (strike.isNotEmpty) {
        callOptionsMap[strike] = call;
        strikeSet.add(strike);
      }
    }
    for (final put in optChainPutUp) {
      final strike = put.strprc ?? '';
      if (strike.isNotEmpty) {
        putOptionsMap[strike] = put;
        strikeSet.add(strike);
      }
    }

    // Add DOWN data (below ATM)
    for (final call in optChainCallDown) {
      final strike = call.strprc ?? '';
      if (strike.isNotEmpty) {
        callOptionsMap[strike] = call;
        strikeSet.add(strike);
      }
    }
    for (final put in optChainPutDown) {
      final strike = put.strprc ?? '';
      if (strike.isNotEmpty) {
        putOptionsMap[strike] = put;
        strikeSet.add(strike);
      }
    }

    // Step 2: Sort strikes numerically
    final sortedStrikes = strikeSet.toList()
      ..sort((a, b) =>
          (double.tryParse(a) ?? 0).compareTo(double.tryParse(b) ?? 0));

    // Step 3: Determine ATM strike based on LIVE LTP (closest strike to current price)
    // Get live LTP from websocket for the UNDERLYING token (following mobile pattern)
    // Mobile uses: depthData.undTk ?? depthData.token for the underlying token
    // IMPORTANT: WebSocket stores data with just token number (e.g., "26000"), NOT "NSE|26000"
    final underlyingToken = depthData.undTk ?? depthData.token ?? '';

    // CRITICAL FIX: Watch ONLY the underlying token's LTP STRING to trigger rebuilds
    // Using .select() with a primitive String (not Map) ensures Riverpod detects changes
    // because Strings are compared by value, while Maps are compared by reference
    // This makes the LTP line POSITION update in real-time as the market moves
    final optionStrPrc = scripInfo.optionStrPrc;
    final underlyingLtpStr = ref.watch(websocketProvider.select(
        (p) => p.socketDatas[underlyingToken]?['lp']?.toString() ?? optionStrPrc));

    // Parse the LTP value for calculations
    // Fallback to optionStrPrc which is set by fetchStikePrc() (underlying's initial LTP)
    final liveLtp = double.tryParse(underlyingLtpStr) ?? 0;

    // Find the closest strike to live LTP (this is the true ATM)
    String atmStrike = '';
    double minDiff = double.infinity;
    for (final strike in sortedStrikes) {
      final strikePrice = double.tryParse(strike) ?? 0;
      final diff = (strikePrice - liveLtp).abs();
      if (diff < minDiff) {
        minDiff = diff;
        atmStrike = strike;
      }
    }

    // Fallback to old logic if no strikes match
    if (atmStrike.isEmpty) {
      if (optChainCallUP.isNotEmpty) {
        atmStrike = optChainCallUP.last.strprc ?? '';
      } else if (optChainCallDown.isNotEmpty) {
        atmStrike = optChainCallDown.first.strprc ?? '';
      }
    }

    // Calculate LTP line position: find the index where LTP falls between strikes
    // The line appears between the strike just below LTP and the strike just above LTP
    int ltpLineIndex = -1;
    for (int i = 0; i < sortedStrikes.length - 1; i++) {
      final currentStrike = double.tryParse(sortedStrikes[i]) ?? 0;
      final nextStrike = double.tryParse(sortedStrikes[i + 1]) ?? 0;
      if (liveLtp >= currentStrike && liveLtp < nextStrike) {
        ltpLineIndex = i + 1; // Insert line after current strike row
        break;
      }
    }
    // Edge cases: LTP below all strikes or above all strikes
    if (ltpLineIndex == -1 && sortedStrikes.isNotEmpty) {
      final firstStrike = double.tryParse(sortedStrikes.first) ?? 0;
      final lastStrike = double.tryParse(sortedStrikes.last) ?? 0;
      if (liveLtp < firstStrike) {
        ltpLineIndex = 0; // Line at the very top
      } else if (liveLtp >= lastStrike) {
        ltpLineIndex = sortedStrikes.length; // Line at the very bottom
      }
    }

    // Step 4: Build StrikeRowData list
    final strikeRowData = sortedStrikes.map((strike) {
      return StrikeRowData(
        strikePrice: strike,
        isATM: strike == atmStrike,
        callOption: callOptionsMap[strike],
        putOption: putOptionsMap[strike],
      );
    }).toList();

    // Calculate total item count including the LTP line
    // The LTP line is inserted at ltpLineIndex position
    final bool showLtpLine = ltpLineIndex >= 0 && liveLtp > 0;
    final int totalItemCount = strikeRowData.length + (showLtpLine ? 1 : 0);

    // Find ATM index for initial scroll position (accounting for LTP line)
    int atmIndex = strikeRowData.indexWhere((row) => row.isATM);
    if (showLtpLine && atmIndex >= ltpLineIndex) {
      atmIndex += 1; // Account for LTP line before ATM
    }

    // Step 5: Schedule scroll to LTP line position on initial load or after strike change
    // This centers the view on the current market price position
    if (ltpLineIndex >= 0 && !_hasScrolledInitially) {
      _hasScrolledInitially = true;
      // Delay scroll by 1 second to ensure data is fully loaded and rendered
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && widget.mainScrollController.hasClients) {
          // Note: itemExtent is 56, center LTP line in viewport
          final targetOffset =
              ltpLineIndex * 56.0 - (MediaQuery.of(context).size.height / 3);
          widget.mainScrollController.jumpTo(targetOffset.clamp(
              0.0, widget.mainScrollController.position.maxScrollExtent));
        }
      });
    }

    // VIRTUALIZED LIST: Only visible rows (~20) are built at a time!
    return RawScrollbar(
      controller: widget.mainScrollController,
      thumbVisibility: true,
      thickness: 6,
      radius: const Radius.circular(0),
      thumbColor: resolveThemeColor(context,
              dark: MyntColors.textSecondaryDark.withValues(alpha: 0.5),
              light: MyntColors.textSecondary)
          .withValues(alpha: 0.5),
      child: Column(
        children: [
          // Virtualized option chain list with dynamic LTP line
          Expanded(
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
              child: ListView.builder(
                controller: widget.mainScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: totalItemCount,
                itemExtent: 56, // Fixed height for better scroll performance
                itemBuilder: (context, index) {
                  // Check if this index is the LTP line position
                  if (showLtpLine && index == ltpLineIndex) {
                    return _LtpCenterLine(
                      key: const ValueKey('ltp-center-line'),
                      fallbackLtp: liveLtp,
                      underlyingToken: underlyingToken,
                    );
                  }

                  // Adjust data index if we're past the LTP line
                  final dataIndex = showLtpLine && index > ltpLineIndex
                      ? index - 1
                      : index;

                  // Safety check for valid index
                  if (dataIndex < 0 || dataIndex >= strikeRowData.length) {
                    return const SizedBox.shrink();
                  }

                  final rowData = strikeRowData[dataIndex];
                  return OptionChainRowWeb(
                    key: ValueKey('row-${rowData.strikePrice}'),
                    rowData: rowData,
                    watchlistTokens: watchlistTokens,
                    showPriceView: widget.showPriceView,
                    isBasketMode: widget.isBasketMode,
                    swipeController: widget.swipecontroller,
                    index: dataIndex,
                    atmKey: rowData.isATM ? widget.strikePriceKey : null,
                    onChartRequested: widget.onChartRequested == null
                        ? null
                        : (_) => widget.onChartRequested!.call(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic LTP center line widget that shows the current underlying price
/// This line appears between strike rows and updates in real-time via StreamBuilder
class _LtpCenterLine extends ConsumerWidget {
  final double fallbackLtp;
  /// Token number for the underlying (e.g., "26000" for NIFTY)
  final String underlyingToken;

  const _LtpCenterLine({
    super.key,
    required this.fallbackLtp,
    required this.underlyingToken,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use StreamBuilder to get real-time updates (same pattern as header)
    return StreamBuilder<Map>(
      stream: ref.read(websocketProvider).socketDataStream,
      builder: (context, snapshot) {
        // CRITICAL FIX: Fall back to existing socket data if stream hasn't emitted yet
        final socketDatas = snapshot.data ?? ref.read(websocketProvider).socketDatas;

        // Get live LTP from websocket using token number, fallback to passed value
        double liveLtp = fallbackLtp;
        if (socketDatas.containsKey(underlyingToken)) {
          final socketData = socketDatas[underlyingToken];
          final wsLtp = socketData['lp']?.toString();
          if (wsLtp != null && wsLtp != "null" && wsLtp != "0") {
            liveLtp = double.tryParse(wsLtp) ?? fallbackLtp;
          }
        }

        // Format LTP with appropriate decimal places
        final formattedLtp = liveLtp.toStringAsFixed(2);

        return Container(
          height: 56, // Match row height
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // Left line (Calls side)
              Expanded(
                flex: 6,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        resolveThemeColor(
                          context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Center LTP badge
              Container(
                width: 150, // Match strike price column width
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.secondary,
                      light: MyntColors.primary,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.secondary,
                          light: MyntColors.primary,
                        ).withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // LTP value
                      Text(
                        formattedLtp,
                        style: MyntWebTextStyles.body(
                          context,
                          fontWeight: MyntFonts.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right line (Puts side)
              Expanded(
                flex: 6,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        resolveThemeColor(
                          context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Widget for the buy/sell action buttons
class _ActionButtons extends ConsumerWidget {
  final DepthInputArgs wlValue;

  const _ActionButtons({
    required this.wlValue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PERFORMANCE FIX: Watch only the specific fields we need
    final scripDepthloader =
        ref.watch(marketWatchProvider.select((p) => p.scripDepthloader));
    final depthData =
        ref.watch(marketWatchProvider.select((p) => p.getQuotes))!;
    final actDeptBtn =
        ref.watch(marketWatchProvider.select((p) => p.actDeptBtn));

    final theme = ref.read(themeProvider);

    // Determine if we should show buttons
    if (scripDepthloader ||
        depthData.instname == "UNDIND" ||
        depthData.instname == "COM" ||
        actDeptBtn == "Set Alert") {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Container(
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: shadcn.Theme.of(context).colorScheme.border))),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: InkWell(
              onTap: () async {
                await _placeOrderInput(context, ref, wlValue, depthData, true);
              },
              child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary,
                      ),
                      borderRadius: BorderRadius.circular(5)),
                  child: Center(
                    child: Text("BUY",
                        style: MyntWebTextStyles.body(context,
                            fontWeight: MyntFonts.semiBold,
                            color: Colors.white)),
                  )),
            )),
            const SizedBox(width: 18),
            Expanded(
                child: InkWell(
                    onTap: () async {
                      await _placeOrderInput(
                          context, ref, wlValue, depthData, false);
                    },
                    child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.lossDark,
                              light: MyntColors.loss,
                            ),
                            borderRadius: BorderRadius.circular(5)),
                        child: Center(
                          child: Text("SELL",
                              style: MyntWebTextStyles.body(context,
                                  fontWeight: MyntFonts.semiBold,
                                  color: Colors.white)),
                        ))))
          ])),
    );
  }
}

// Global helper function
Future<void> _placeOrderInput(BuildContext context, WidgetRef ref,
    DepthInputArgs wlValue, GetQuotes depthData, bool transType) async {
  await ref
      .read(marketWatchProvider)
      .fetchScripInfo(wlValue.token, wlValue.exch, context, true);

  // Get the updated scripInfo after fetchScripInfo to ensure we have the correct lot size
  final scripInfoModel = ref.read(marketWatchProvider).scripInfoModel!;

  OrderScreenArgs orderArgs = OrderScreenArgs(
      exchange: wlValue.exch,
      tSym: wlValue.tsym,
      isExit: false,
      token: wlValue.token,
      transType: transType,
      // Use lot size from the updated scripInfoModel instead of potentially stale depthData
      lotSize: scripInfoModel.ls ?? depthData.ls,
      ltp: "${depthData.lp ?? depthData.c ?? 0.00}",
      perChange: depthData.pc ?? "0.00",
      orderTpye: '',
      holdQty: '',
      isModify: false,
      // Pass lot size in raw data as backup
      raw: {"correctLotSize": scripInfoModel.ls ?? depthData.ls});

  Navigator.pop(context);
  ResponsiveNavigation.toPlaceOrderScreen(context: context, arguments: {
    "orderArg": orderArgs,
    "scripInfo": scripInfoModel,
    "isBskt": "Basket"
  });
}

// Enhanced Basket Bottom Sheet Widget with full BasketScripList functionality
class _BasketBottomSheet extends ConsumerStatefulWidget {
  const _BasketBottomSheet();

  @override
  ConsumerState<_BasketBottomSheet> createState() => _BasketBottomSheetState();
}

class _BasketBottomSheetState extends ConsumerState<_BasketBottomSheet>
    with TickerProviderStateMixin {
  double _sheetHeight = 260.0;
  final double _minHeight = 260.0;
  late double _maxHeight;
  bool _isExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maxHeight = MediaQuery.of(context).size.height * 0.8;
  }

  @override
  void initState() {
    super.initState();
    // Ensure WebSocket subscriptions are established when basket bottom sheet is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureBasketWebSocketSubscription();
    });
  }

  void _ensureBasketWebSocketSubscription() async {
    final orderProv = ref.read(orderProvider);
    // if (kDebugMode) {
    //   print("=== BASKET WEBSOCKET DEBUG ===");
    //   print("Selected basket: ${orderProv.selectedBsktName}");
    //   print("Basket items count: ${orderProv.bsktScripList.length}");
    //   print("Basket items: ${orderProv.bsktScripList.map((item) => "${item['tsym']}|${item['token']}").join(', ')}");
    //   print("==============================");
    // }

    if (orderProv.selectedBsktName.isNotEmpty &&
        orderProv.bsktScripList.isNotEmpty) {
      // Re-establish WebSocket subscription for current basket to ensure live updates
      await orderProv.chngBsktName(orderProv.selectedBsktName, context, true);

      if (kDebugMode) {
      }
    }
  }

  /// Checks if the basket contains scripts from multiple exchanges
  bool _hasMultipleExchanges(List scriptList) {
    if (scriptList.isEmpty) return false;

    // Extract all exchanges from the basket scripts
    Set<String> exchanges = {};
    for (var script in scriptList) {
      if (script['exch'] != null) {
        exchanges.add(script['exch'].toString());
      }
    }

    // If there's more than one unique exchange, return true
    return exchanges.length > 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final orderProv = ref.watch(orderProvider);

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _sheetHeight =
              (_sheetHeight - details.delta.dy).clamp(_minHeight, _maxHeight);
        });
      },
      onPanEnd: (details) {
        // Calculate the threshold height (30% of max height)
        double thresholdHeight = _maxHeight * 0.3;

        setState(() {
          if (_sheetHeight < thresholdHeight) {
            // Snap to minimum if below threshold
            _sheetHeight = _minHeight;
            _isExpanded = false;
          } else {
            // Keep the sheet at the current height where user released it
            // Don't force snap to max - respect user's intended position
            _isExpanded = _sheetHeight >
                _maxHeight * 0.7; // Update expanded state based on position
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _sheetHeight,
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          border: Border(
            top: BorderSide(
              color: shadcn.Theme.of(context).colorScheme.border,
            ),
            left: BorderSide(
              color: shadcn.Theme.of(context).colorScheme.border,
            ),
            right: BorderSide(
              color: shadcn.Theme.of(context).colorScheme.border,
            ),
          ),
        ),
        child: Column(
          children: [
            // Fixed header section
            const CustomDragHandler(),

            // Header with current basket name and action icons
            _buildBasketHeader(theme, orderProv),
            const ListDivider(),

            // Scrollable content section
            if (orderProv.selectedBsktName.isNotEmpty &&
                orderProv.bsktScripList.isNotEmpty)
              _buildMarginsSection(theme, orderProv),
            // Content

            orderProv.bsktList.isEmpty
                ? _buildCreateBasketView(theme, orderProv)
                : _buildBasketContent(theme, orderProv),

            // Exchange validation warning (if needed)

            // Place Order Button (if basket has items and is valid)

            if (orderProv.bsktScripList.isNotEmpty &&
                _hasMultipleExchanges(orderProv.bsktScripList))
              _buildMultiExchangeWarning(),
            if (orderProv.selectedBsktName.isNotEmpty &&
                orderProv.bsktScripList.isNotEmpty)
              _buildPlaceOrderButton(theme, orderProv),
          ],
        ),
      ),
    );
  }

  Widget _buildBasketHeader(ThemesProvider theme, OrderProvider orderProv) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderProv.selectedBsktName.isNotEmpty
                      ? orderProv.selectedBsktName
                      : "No Basket Selected",
                  style: MyntWebTextStyles.title(context,
                      fontWeight: MyntFonts.semiBold,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary,
                      )),
                ),
                const SizedBox(height: 4),
                if (orderProv.selectedBsktName.isNotEmpty)
                  Text(
                    "${orderProv.bsktScripList.length} items",
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
            children: [
              // Switch basket icon
              if (orderProv.bsktList.length > 1)
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () async {
                      await Future.delayed(const Duration(milliseconds: 100));
                      _showBasketSelector(context);
                    },
                    borderRadius: BorderRadius.circular(20),
                    splashColor: theme.isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                    highlightColor: theme.isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.swap_horiz,
                        size: 24,
                        color: resolveThemeColor(context,
                            dark: MyntColors.iconDark, light: MyntColors.icon),
                      ),
                    ),
                  ),
                ),

              // Refresh basket margin icon
              if (orderProv.selectedBsktName.isNotEmpty &&
                  orderProv.bsktScripList.isNotEmpty)
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () async {
                      await Future.delayed(const Duration(milliseconds: 100));
                      await orderProv.fetchBasketMargin();
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
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.refresh,
                        size: 22,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),

              // Add basket icon

              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () async {
                    await Future.delayed(const Duration(milliseconds: 100));
                    _showCreateBasket(context);
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
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.add_circle_outline,
                      size: 22,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
                style: TextStyle(
                  fontFamily: dyslexiaFontOr('Geist'),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: shadcn.Theme.of(context).colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                orderProv.bsktScripList.isEmpty ||
                        orderProv.bsktOrderMargin == null
                    ? "0.00"
                    : orderProv.bsktOrderMargin!.basketMargin.toIndianFormat(),
                style: TextStyle(
                  fontFamily: dyslexiaFontOr('Geist'),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
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
                style: TextStyle(
                  fontFamily: dyslexiaFontOr('Geist'),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: shadcn.Theme.of(context).colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                orderProv.bsktScripList.isEmpty ||
                        orderProv.bsktOrderMargin == null
                    ? "0.00"
                    : orderProv.bsktOrderMargin!.postTradeMargin.toIndianFormat(),
                style: TextStyle(
                  fontFamily: dyslexiaFontOr('Geist'),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
    final theme = ref.read(themeProvider);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: resolveThemeColor(
          context,
          dark: MyntColors.lossDark,
          light: MyntColors.loss,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Basket should contain orders of only 1 segment",
            style: TextStyle(
              fontFamily: dyslexiaFontOr('Geist'),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateBasketView(
      ThemesProvider theme, OrderProvider orderProvider) {
    return Center(

      child: 
      NoDataFoundWeb(
        title: "No Data Found",
        subtitle: "Create Basket",
        onPrimary: () {
          _showCreateBasket(context);

          
        },
      ),
      // Column(

      //   mainAxisAlignment: MainAxisAlignment.center,
      //   children: [
      //     Column(
      //       children: [
      //         SvgPicture.asset(assets.noDatafound,
      //             color: const Color(0xff777777)),
      //         const SizedBox(height: 2),
      //         Text("No Data Found",
      //             style: TextStyle(
      //               fontFamily: 'Geist',
      //               fontSize: 13,
      //               fontWeight: FontWeight.w500,
      //               color: shadcn.Theme.of(context).colorScheme.mutedForeground,
      //             )),
      //         //       SizedBox(height: 16),
      //         // TextWidget.subText(
      //         //   text: "No baskets found",
      //         //   theme: theme.isDarkMode,
      //         //   color: colors.colorGrey,
      //         // ),
      //         const SizedBox(height: 16),
      //         ElevatedButton(
      //           onPressed: () => _showCreateBasket(context),
      //           style: ElevatedButton.styleFrom(
      //             backgroundColor: resolveThemeColor(
      //               context,
      //               dark: MyntColors.primaryDark,
      //               light: MyntColors.primary,
      //             ),
      //             padding:
      //                 const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      //           ),
      //           child: TextWidget.subText(
      //             text: "Create Basket",
      //             color: Colors.white,
      //             theme: false,
      //           ),
      //         ),
      //       ],
      //     ),
      //   ],
      // ),
    );
  }

  Widget _buildBasketContent(
      ThemesProvider theme, OrderProvider orderProvider) {
    // If no basket is selected, show basket selector
    if (orderProvider.selectedBsktName.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                assets.noDatafound,
                color: const Color(0xff777777),
              ),
              const SizedBox(height: 2),
              TextWidget.subText(
                  text: "No Basket Selected",
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary,
                  ),
                  fw: 0,
                  theme: theme.isDarkMode),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showBasketSelector(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: resolveThemeColor(
                    context,
                    dark: MyntColors.primary,
                    light: MyntColors.primary,
                  ),
                  minimumSize: const Size(0, 45),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: TextWidget.subText(
                  text: "Choose Basket",
                  color: Colors.white,
                  theme: false,
                  fw: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If basket is selected but empty
    if (orderProvider.bsktScripList.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                assets.noDatafound,
                color: const Color(0xff777777),
              ),
              const SizedBox(height: 2),
              TextWidget.subText(
                text: "Basket is empty",
                theme: theme.isDarkMode,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary,
                ),
                fw: 0,
              ),
              const SizedBox(height: 8),
              TextWidget.subText(
                text: "Tap on options above to add them to basket",
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary,
                ),
                fw: 0,
                theme: theme.isDarkMode,
              ),
            ],
          ),
        ),
      );
    }

    // PERFORMANCE FIX: Removed StreamBuilder that was rebuilding entire list every 500ms
    // Socket data updates are now handled more efficiently through provider notifications
    return Expanded(
      child: SingleChildScrollView(
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orderProvider.bsktScripList.length,
          separatorBuilder: (_, __) => const ListDivider(),
          itemBuilder: (context, index) {
            final script = orderProvider.bsktScripList[index];

            // Process script data for display
            if (script['exch'] == "BFO" && script["dname"] != "null") {
              List<String> splitVal = script["dname"].toString().split(" ");
              script['symbol'] = splitVal[0];
              // BFO: keep dname's day+month, append the year from the tsym. (TC_440)
              script['expDate'] =
                  bfoExpiryWithYear(splitVal, script['tsym']?.toString());
              script['option'] = splitVal.length > 4
                  ? "${splitVal[3]} ${splitVal[4]}"
                  : splitVal[3];
            } else {
              Map spilitSymbol = spilitTsym(value: "${script['tsym']}");
              script['symbol'] = "${spilitSymbol["symbol"]}";
              script['expDate'] = "${spilitSymbol["expDate"]}";
              script['option'] = "${spilitSymbol["option"]}";
            }

            return InkWell(
              onTap: () => _handleBasketItemTap(index, script, orderProvider),
              onLongPress: () => _deleteScript(index, script, orderProvider),
              child: _buildScriptCard(theme, script, index),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScriptCard(ThemesProvider theme, Map script, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  TextWidget.subText(
                    text: script['symbol'].toString().replaceAll("-EQ", ""),
                    theme: theme.isDarkMode,
                    textOverflow: TextOverflow.ellipsis,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary,
                    ),
                  ),
                  TextWidget.subText(
                    text: " ${script['expDate']} ",
                    theme: theme.isDarkMode,
                    textOverflow: TextOverflow.ellipsis,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary,
                    ),
                  ),
                  TextWidget.subText(
                    text: " ${script['option']} ",
                    theme: theme.isDarkMode,
                    textOverflow: TextOverflow.ellipsis,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (script['orderStatus'] != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getItemStatusColor(script['orderStatus'])
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    // border: Border.all(
                    //     color: _getItemStatusColor(script['orderStatus'])),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextWidget.paraText(
                        text: _getItemStatusText(script['orderStatus']),
                        theme: theme.isDarkMode,
                        color: _getItemStatusColor(script['orderStatus']),
                      ),
                      if (script['avgPrice'] != null)
                        TextWidget.paraText(
                          text: " @ ₹${script['avgPrice']}",
                          theme: theme.isDarkMode,
                          color: _getItemStatusColor(script['orderStatus']),
                        ),
                      // Add navigation hint for placed orders
                      if (_isOrderPlaced(script['orderStatus'])) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: _getItemStatusColor(script['orderStatus']),
                          size: 10,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // CustomExchBadge(exch: "${script["exch"]}"),

                  TextWidget.paraText(
                    text:
                        "${script["exch"]} - ${script["ordType"]} - ${script["prctype"]} - ${formatToTimeOnly(script["date"])}",
                    theme: false,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  TextWidget.paraText(
                    text: " LTP ${script['lp']?.toString() ?? "0.00"}",
                    theme: false,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                  ),
                ],
              ),
              // TextWidget.paraText(
              //   text: " (${script['pc']?.toString() ?? "0.00"}%)",
              //   theme: false,
              //   color: script['pc']?.toString().startsWith("-") ?? false
              //       ? colors.darkred
              //       : script['pc']?.toString() == "0.00"
              //           ? colors.ltpgrey
              //           : colors.ltpgreen,
              //   fw: 0,
              // ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  TextWidget.paraText(
                    text: script["trantype"] == "S" ? "SELL" : "BUY",
                    theme: false,
                    color: script["trantype"] == "S"
                        ? resolveThemeColor(
                            context,
                            dark: MyntColors.lossDark,
                            light: MyntColors.loss,
                          )
                        : resolveThemeColor(
                            context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary,
                          ),
                    fw: 0,
                  ),
                  const SizedBox(width: 8),
                  TextWidget.paraText(
                    text: "${script["dscqty"]}/${script["qty"]}",
                    theme: theme.isDarkMode,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (script["prctype"] != "MKT")
                Row(
                  children: [
                    TextWidget.paraText(
                      text: "${script['prc'] ?? 0.00}",
                      theme: false,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Order Status Display (if available)

          // Show rejection reason separately if needed
          if (script['rejectionReason'] != null &&
              script['orderStatus'] == 'failed')
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.lossDark,
                  light: MyntColors.loss,
                ).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.lossDark,
                    light: MyntColors.loss,
                  ),
                ),
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
                    child: TextWidget.captionText(
                      text: script['rejectionReason'],
                      theme: theme.isDarkMode,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.lossDark,
                        light: MyntColors.loss,
                      ),
                      textOverflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceOrderButton(ThemesProvider theme, OrderProvider orderProv) {
    final hasMultipleExchanges = _hasMultipleExchanges(orderProv.bsktScripList);
    final basketStatus =
        orderProv.basketOverallStatus[orderProv.selectedBsktName] ?? '';
    final isBasketPlaced = orderProv.isBasketPlaced(orderProv.selectedBsktName);

    // Show order status if basket has been placed
    if (isBasketPlaced) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Order Status Display
            // Container(
            //   width: double.infinity,
            //   padding: const EdgeInsets.all(12),
            //   margin: const EdgeInsets.only(bottom: 8),
            //   decoration: BoxDecoration(
            //     color: _getStatusColor(basketStatus).withOpacity(0.1),
            //     borderRadius: BorderRadius.circular(8),
            //     border: Border.all(color: _getStatusColor(basketStatus)),
            //   ),
            //   child: Column(
            //     children: [
            //       // Row(
            //       //   mainAxisAlignment: MainAxisAlignment.center,
            //       //   children: [
            //       //     Icon(
            //       //       _getStatusIcon(basketStatus),
            //       //       color: _getStatusColor(basketStatus),
            //       //       size: 16,
            //       //     ),
            //       //     const SizedBox(width: 8),
            //       //     TextWidget.subText(
            //       //       text: _getStatusText(basketStatus),
            //       //       theme: theme.isDarkMode,
            //       //       color: _getStatusColor(basketStatus),
            //       //       fw: 1,
            //       //     ),
            //       //   ],
            //       // ),
            //       if (basketStatus == 'partially_placed' || basketStatus == 'partially_completed')
            //         const SizedBox(height: 4),
            //       if (basketStatus == 'partially_placed' || basketStatus == 'partially_completed')
            //         TextWidget.subText(
            //           text: _getPartialStatusDetails(orderProv),
            //           theme: theme.isDarkMode,
            //           color: colors.colorGrey,
            //         ),
            //     ],
            //   ),
            // ),
            // Reset Button

            SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    orderProv
                        .resetBasketOrderTracking(orderProv.selectedBsktName);
                    showResponsiveSuccess(
                        context, "Basket reset. You can place orders again.");
                  },
                  label: TextWidget.subText(
                    text: "Reset Orders",
                    theme: false,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary,
                    ),
                    fw: 2,
                  ),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 45),
                      side: BorderSide(
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
                        ),
                      ),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(5)))),
                )),
          ],
        ),
      );
    }

    // Original place order button
    return Container(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: hasMultipleExchanges
              ? Colors.grey
              : resolveThemeColor(
                  context,
                  dark: MyntColors.primaryDark,
                  light: MyntColors.primary,
                ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: InkWell(
          onTap: hasMultipleExchanges
              ? null

              // () {
              //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              //       content: const Text(
              //         "Cannot place order: Basket should contain orders from only 1 segment",
              //       ),
              //       backgroundColor: colors.darkred,
              //       duration: const Duration(seconds: 3),
              //     ));
              //   }
              : basketStatus == 'placing'
                  ? null // Disable button while placing
                  : () async {
                      await orderProv.placeBasketOrder(context,
                          navigateToOrderBook: false);
                    },
          child: Center(
            child: basketStatus == 'placing'
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MyntLoader.inline(),
                      const SizedBox(width: 8),
                      TextWidget.subText(
                        text: "Placing...",
                        theme: false,
                        color: Colors.white,
                        fw: 2,
                      ),
                    ],
                  )
                : TextWidget.subText(
                    text: "Place Order",
                    theme: false,
                    color: Colors.white,
                    fw: 2,
                  ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final theme = ref.read(themeProvider);
    switch (status) {
      case 'placing':
        return resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary);
      case 'placed':
      case 'completed':
        return resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
      case 'partially_placed':
      case 'partially_completed':
      case 'partially_filled':
        return resolveThemeColor(context,
            dark: MyntColors.warning, light: MyntColors.warning);
      case 'failed':
        return resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);
      default:
        return resolveThemeColor(context,
            dark: MyntColors.iconDark, light: MyntColors.icon);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'placing':
        return Icons.schedule;
      case 'placed':
      case 'completed':
        return Icons.check_circle;
      case 'partially_placed':
      case 'partially_completed':
      case 'partially_filled':
        return Icons.warning;
      case 'failed':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'placing':
        return 'Placing Orders...';
      case 'placed':
        return 'Orders Placed Successfully';
      case 'completed':
        return 'All Orders Completed';
      case 'partially_placed':
        return 'Partially Placed';
      case 'partially_completed':
        return 'Partially Completed';
      case 'partially_filled':
        return 'Partially Filled';
      case 'failed':
        return 'Order Placement Failed';
      default:
        return 'Unknown Status';
    }
  }

  String _getPartialStatusDetails(OrderProvider orderProv) {
    final orderIds = orderProv.basketOrderIds[orderProv.selectedBsktName] ?? [];
    final totalOrders = orderProv.bsktScripList.length;
    final successfulOrders = orderIds.length;

    if (orderIds.isNotEmpty) {
      return '$successfulOrders of $totalOrders orders processed';
    }
    return '';
  }

  // Helper methods for individual item status indicators
  Color _getItemStatusColor(String status) {
    final theme = ref.read(themeProvider);
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

  IconData _getItemStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Icons.send;
      case 'complete':
        return Icons.check_circle;
      case 'rejected':
      case 'canceled':
      case 'failed':
        return Icons.cancel;
      case 'open':
      case 'partial':
      case 'trigger_pending':
        return Icons.schedule;
      default:
        return Icons.info_outline;
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
        return 'PARTIALLY FILLED';
      case 'trigger_pending':
        return 'TRIGGER PENDING';
      default:
        return status.toUpperCase(); // Show actual status from order book
    }
  }

  // Handle tap on basket items - navigate to order book if placed, edit if not placed
  void _handleBasketItemTap(
      int index, Map script, OrderProvider orderProvider) {
    String? orderStatus = script['orderStatus'];

    // If order is placed/completed/etc, navigate to order book
    if (orderStatus != null && _isOrderPlaced(orderStatus)) {
      // _navigateToOrderBook(orderProvider, orderStatus);
    } else {
      // If order not placed yet, allow editing
      _editScript(index, script, orderProvider);
    }
  }

  // Check if order is placed (any status other than null or initial states)
  bool _isOrderPlaced(String status) {
    return !['pending', 'draft', 'preparing'].contains(status.toLowerCase());
  }

  // Navigate to order book in portfolio screen
  void _navigateToOrderBook(OrderProvider orderProvider, String orderStatus) {
    Navigator.pop(context);
    Navigator.pop(context);
    ref.read(indexListProvider).bottomMenu(2, context);
    ref.read(portfolioProvider).changeTabIndex(2);

    // print("orderStatusboi: $orderStatus");

    if (orderStatus == 'COMPLETE' || orderStatus == 'REJECTED') {
      orderProvider.changeTabIndex(1, context);
    } else {
      orderProvider.changeTabIndex(0, context);
    }

    // Show success message
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: const Text("Navigating to Order Book to view order details"),
    //     backgroundColor: colors.ltpgreen,
    //     duration: const Duration(seconds: 2),
    //   ),
    // );
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

    // **FIX: Ensure prd field is correctly preserved for basket edit**
    // The prd field should already be correct from when the item was saved to basket
    // Only set prd if it's missing, but don't overwrite existing correct values
    if (script['prd'] == null || script['prd'].toString().isEmpty) {
      // Fallback mapping from ordType to prd if prd is missing
      final ordType = script['ordType']?.toString();
      if (ordType == 'MIS') {
        script['prd'] = 'I'; // Intraday
      } else if (ordType == 'CNC') {
        script['prd'] = 'C'; // Delivery
      } else if (ordType == 'NRML') {
        script['prd'] = 'M'; // Carryforward
      }
    }

    // Ensure lp and pc values are not null for OrderScreenArgs
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
      // **FIX: Set prd field in OrderScreenArgs for proper order type initialization**
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = ref.read(themeProvider);
        return AlertDialog(
          backgroundColor: theme.isDarkMode
              ? const Color(0xFF121212)
              : const Color(0xFFF1F3F8),
          titlePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          scrollable: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          actionsPadding:
              const EdgeInsets.only(bottom: 16, right: 16, left: 16, top: 8),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          title: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () async {
                        await Future.delayed(const Duration(milliseconds: 150));
                        Navigator.pop(context);
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
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TextWidget.subText(
                            text:
                                "Are you sure you want to delete this basket Scrip ${script['symbol']?.toString().replaceAll("-EQ", "")}",
                            theme: theme.isDarkMode,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textPrimary,
                            ),
                            align: TextAlign.center),
                      ]))
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await orderProv.removeBsktScrip(
                      index, orderProv.selectedBsktName);
                  await orderProv.fetchBasketMargin();
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 45),
                  side: BorderSide(
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.outlinedBorderDark,
                      light: MyntColors.outlinedBorder,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  backgroundColor: resolveThemeColor(
                    context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary,
                  ),
                ),
                child: TextWidget.titleText(
                  text: "Yes",
                  theme: theme.isDarkMode,
                  color: Colors.white,
                  fw: 2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateBasket(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const CreateBasket(),
    ).then((_) async {
      // Refresh basket data after creating basket
      await ref.read(orderProvider).getBasketName();

      // Ensure WebSocket subscriptions are refreshed
      _ensureBasketWebSocketSubscription();
    });
  }

  String formatToTimeOnly(String rawDate) {
    try {
      final dateTime = DateFormat("dd MMM yyyy, hh:mm a").parse(rawDate);
      return DateFormat("hh:mm a").format(dateTime);
    } catch (e) {
      return ''; // or return rawDate if you want fallback
    }
  }

  void _showBasketSelector(BuildContext context) {
    final orderProv = ref.read(orderProvider);
    final theme = ref.read(themeProvider);
    showModalBottomSheet(
      context: context,
      // isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          color: resolveThemeColor(context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          border: Border(
            top: BorderSide(
              color: shadcn.Theme.of(context).colorScheme.border,
            ),
            left: BorderSide(
              color: shadcn.Theme.of(context).colorScheme.border,
            ),
            right: BorderSide(
              color: shadcn.Theme.of(context).colorScheme.border,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const CustomDragHandler(),
              // const SizedBox(height: 8),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextWidget.titleText(
                      text: "Select Basket",
                      theme: ref.read(themeProvider).isDarkMode,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary,
                      ),
                      fw: 1,
                    ),
                    const ListDivider(),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () async {
                          await Future.delayed(
                              const Duration(milliseconds: 150));
                          Navigator.pop(context);
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
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Icon(
                            Icons.close_rounded,
                            size: 22,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                color: shadcn.Theme.of(context).colorScheme.border,
                height: 0,
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: orderProv.bsktList.length,
                  separatorBuilder: (_, __) => const ListDivider(),
                  itemBuilder: (context, index) {
                    final basket = orderProv.bsktList[index];
                    final basketName = basket['bsketName'].toString();
                    final isDark = ref.read(themeProvider).isDarkMode;

                    return ListTile(
                      minLeadingWidth: 25,
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            assets.basketdashboard,
                            color: isDark
                                ? colors.textSecondaryDark
                                : colors.textSecondaryLight,
                          ),
                        ],
                      ),
                      title: Container(
                        margin: EdgeInsets.only(
                          right: MediaQuery.of(context).size.width * 0.1,
                        ),
                        child: TextWidget.subText(
                          text: basketName,
                          theme: isDark,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                          textOverflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextWidget.paraText(
                          text:
                              "${basket['curLength']} / ${basket['max']} items",
                          theme: isDark,
                          textOverflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary,
                          ),
                        ),
                      ),
                      trailing: basketName == orderProv.selectedBsktName
                          ? Icon(
                              Icons.check,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.profitDark,
                                light: MyntColors.profit,
                              ),
                            )
                          : null,
                      onTap: () async {
                        await orderProv.chngBsktName(basketName, context, true);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),

              // ...orderProv.bsktList.map<Widget>((basket) {
              //   final basketName = basket['bsketName'].toString();
              //   return ListTile(
              //     title: TextWidget.subText(
              //       text: basketName,
              //       theme: ref.read(themeProvider).isDarkMode,
              //       color: ref.read(themeProvider).isDarkMode
              //           ? colors.colorWhite
              //           : colors.colorBlack,
              //     ),
              //     subtitle: TextWidget.paraText(
              //       text: "${basket['curLength']} / ${basket['max']} items",
              //       theme: ref.read(themeProvider).isDarkMode,
              //       color: colors.colorGrey,
              //     ),
              //     trailing: basketName == orderProv.selectedBsktName
              //         ? Icon(Icons.check, color: colors.ltpgreen)
              //         : null,
              //     onTap: () async {
              //       await orderProv.chngBsktName(basketName, context, true);
              //       Navigator.pop(context);
              //     },
              //   );
              // }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
