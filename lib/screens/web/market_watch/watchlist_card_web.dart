// REMOVED: dart:async import - no longer using StreamSubscription!
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/foundation.dart';
import 'package:mynt_plus/provider/web_subscription_manager.dart';
import 'package:mynt_plus/provider/web_subscription_manager.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart';
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart';
import 'package:mynt_plus/sharedWidget/hover_actions_web.dart';
import 'package:mynt_plus/screens/web/market_watch/future_screen_web.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../../routes/route_names.dart';
import '../../../utils/custom_navigator.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../models/order_book_model/order_book_model.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/res.dart';
import '../../../res/web_colors.dart';
import '../../../res/global_font_web.dart';
import '../../../res/responsive.dart';
import '../../../sharedWidget/snack_bar.dart';
import '../../../utils/responsive_navigation.dart';
import '../../../utils/responsive_snackbar.dart';
// import '../../Mobile/market_watch/edit_scrip.dart';
// import 'edit_scrip_web.dart';
import '../../Mobile/market_watch/new_fundamental_screen.dart';
import 'set_alert_web.dart';
import 'watchlist_screen_web.dart' show deleteModeProvider;
import '../chart_engine/state/active_pane_symbol_request.dart';
import '../chart_engine/state/chart_engine_store.dart' show ChartScrip;

// Provider to manage expanded watchlist item
final expandedWatchlistItemProvider =
    StateNotifierProvider<ExpandedWatchlistItemNotifier, String?>((ref) {
  return ExpandedWatchlistItemNotifier();
});

class ExpandedWatchlistItemNotifier extends StateNotifier<String?> {
  ExpandedWatchlistItemNotifier() : super(null);

  void setExpandedToken(String? token) {
    state = token;
  }
}

class WatchlistCardWeb extends ConsumerStatefulWidget {
  final dynamic watchListData;
  const WatchlistCardWeb({super.key, required this.watchListData});

  @override
  ConsumerState<WatchlistCardWeb> createState() => _WatchlistCardWebState();
}

class _WatchlistCardWebState extends ConsumerState<WatchlistCardWeb> {
  // Add navigation lock to prevent multiple navigation events
  bool _isNavigating = false;

  bool _isExpiryToday(String? expDateStr) {
    if (expDateStr == null || expDateStr.isEmpty) return false;

    try {
      // Parse the expiry date format "11 NOV 25"
      final parts = expDateStr.trim().split(' ');
      if (parts.length != 3) return false;

      final day = int.tryParse(parts[0]);
      if (day == null) return false;

      final monthStr = parts[1].toUpperCase();
      final yearStr = parts[2];

      // Map month abbreviations to numbers
      const months = {
        'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
        'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
      };

      final month = months[monthStr];
      if (month == null) return false;

      // Parse year (assuming 2-digit year)
      final year = int.tryParse('20$yearStr');
      if (year == null) return false;

      final expDate = DateTime(year, month, day);
      final today = DateTime.now();

      return expDate.year == today.year &&
             expDate.month == today.month &&
             expDate.day == today.day;
    } catch (e) {
      return false;
    }
  }
  // PERFORMANCE FIX: Use ValueNotifier for hover instead of setState
  final ValueNotifier<bool> _isHovered = ValueNotifier<bool>(false);
  // bool _isExpanded = false;
  bool _isMenuOpen = false;
  final GlobalKey _menuButtonKey = GlobalKey();

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeProvider);
    final marketWatch = ref.read(marketWatchProvider);
    // CRITICAL FIX: Use ref.read instead of ref.watch for getQuotes
    // Using ref.watch here caused ALL watchlist cards to rebuild when ANY symbol was clicked
    // because getQuotes is updated for the clicked symbol. This caused symbol #2 to briefly
    // show 0.00 during the rebuild cascade before socket data was re-read.
    // The LTP/change display uses websocketProvider.socketDatas[token] directly, not getQuotes.
    // getQuotes is only needed for action callbacks (Buy/Sell), so ref.read is appropriate.
    final depthData = ref.read(marketWatchProvider).getQuotes!;

    // final expandedToken = ref.watch(expandedWatchlistItemProvider);

    // Check if this card is expanded
    // _isExpanded = expandedToken == widget.watchListData['token']?.toString();

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          MouseRegion(
            onEnter: (_) => _isHovered.value = true,
            onExit: (_) => _isHovered.value = false,
            child: ValueListenableBuilder<bool>(
              valueListenable: _isHovered,
              builder: (context, isHovered, _) => InkWell(
                // Increased border radius for web
                splashColor: theme.isDarkMode
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.15),
                highlightColor: theme.isDarkMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.08),
                // onLongPress: () {
                //   if (marketWatch.isPreDefWLs == "Yes") {
                //     showResponsiveWarningMessage(context,
                //         "This is a pre-defined watchlist that cannot be edited!");
                //   } else {
                //     ref
                //         .read(marketWatchProvider)
                //         .requestMWScrip(context: context, isSubscribe: false);
                //     Navigator.push(
                //         context,
                //         MaterialPageRoute(
                //             builder: (context) =>
                //                 EditScrip(wlName: marketWatch.wlName)));
                //   }
                // },
                onTap: () async {
                  // Clicking the list item opens the chart
                  if (_isNavigating) return;
                  // // Increased border radius for web
                  // splashColor: theme.isDarkMode
                  //     ? Colors.white.withOpacity(0.15)
                  //     : Colors.black.withOpacity(0.15),
                  // highlightColor: theme.isDarkMode
                  //     ? Colors.white.withOpacity(0.08)
                  //     : Colors.black.withOpacity(0.08),
                  // onLongPress: () {
                  //   if (marketWatch.isPreDefWLs == "Yes") {
                  //     showResponsiveWarningMessage(context,
                  //         "This is a pre-defined watchlist that cannot be edited!");
                  //   } else {
                  //     ref
                  //         .read(marketWatchProvider)
                  //         .requestMWScrip(context: context, isSubscribe: false);
                  //     Navigator.push(
                  //         context,
                  //         MaterialPageRoute(
                  //             builder: (context) =>
                  //                 EditScrip(wlName: marketWatch.wlName)));
                  //   }
                  // },
                  // Clicking the list item opens the chart

                  try {
                    setState(() {
                      _isNavigating = true;
                    });

                    // Depth visibility is managed by chart_with_depth_web.dart based on current tab:
                    // - Overview tab: shows depth automatically
                    // - Chart/Options tab: preserves current depth state (respects user's hide action)

                    // Create proper DepthInputArgs object
                    DepthInputArgs depthArgs = DepthInputArgs(
                        exch: widget.watchListData["exch"].toString(),
                        token: widget.watchListData["token"].toString(),
                        tsym: widget.watchListData["tsym"].toString(),
                        instname:
                            widget.watchListData["instname"]?.toString() ??
                                widget.watchListData["symbol"].toString(),
                        symbol: widget.watchListData["symbol"].toString(),
                        expDate:
                            widget.watchListData["expDate"]?.toString() ?? "",
                        option:
                            widget.watchListData["option"]?.toString() ?? "");
                    // Create proper DepthInputArgs object

                    // Call depth APIs which handles everything including tab management
                    marketWatch.scripdepthsize(false);
                    await marketWatch.calldepthApis(context, depthArgs, "");

                    // Apply the picked symbol to the chart's CURRENTLY-focused
                    // pane via the engine (it reads its live `.pane.active` marker
                    // at apply time) — same robust path as the index strip. This
                    // is an EXPLICIT "apply now" signal, so it works even when the
                    // picked symbol equals the details symbol or one already shown
                    // in another pane (e.g. focus the 2nd pane and pick SENSEX
                    // while the 1st pane is SENSEX) — cases the embedded-chart
                    // symbol mirror dedups away. Harmless when no chart is mounted.
                    if (mounted &&
                        depthArgs.token.isNotEmpty &&
                        depthArgs.exch.isNotEmpty) {
                      ref
                          .read(activePaneSymbolRequestProvider.notifier)
                          .request(
                            ChartScrip(
                              exch: depthArgs.exch,
                              token: depthArgs.token,
                              tsym: depthArgs.tsym,
                              dispName: depthArgs.tsym,
                              ls: 1,
                              ti: 0.05,
                              instname: depthArgs.instname,
                            ).toJson(),
                          );
                    }
                  } catch (e) {
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
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Main content container
                    Container(
                      color: isHovered
                          ? resolveThemeColor(
                              context,
                              dark: MyntColors.primaryDark,
                              light: MyntColors.primary,
                            ).withValues(alpha: 0.08)
                          : resolveThemeColor(context,
                              dark: MyntColors.backgroundColorDark,
                              light: MyntColors.backgroundColor),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // First row: Symbol name | LTP
                          SizedBox(
                            height: 24,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Left: Symbol name and option
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        widget.watchListData["symbol"]
                                            .toString()
                                            .replaceAll("-EQ", "")
                                            .toUpperCase(),
                                        style: MyntWebTextStyles.symbol(
                                          context,
                                          color: resolveThemeColor(
                                            context,
                                            dark: MyntColors.textPrimaryDark,
                                            light: MyntColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (widget.watchListData["option"]
                                          .toString()
                                          .isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 4),
                                          child: Text(
                                            "${widget.watchListData["option"]}",
                                            style: MyntWebTextStyles.symbol(
                                              context,
                                              color: resolveThemeColor(
                                                context,
                                                dark:
                                                    MyntColors.textPrimaryDark,
                                                light: MyntColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ),

                                             if (widget.watchListData["weekly"] != null &&
                                          widget.watchListData["weekly"].toString().isNotEmpty &&
                                          widget.watchListData["weekly"].toString() != "null")
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color:  resolveThemeColor(
                                  context,
                                  dark: Color(0XFFF1F3F8),
                                  light: Color(0XFFF1F3F8),
                                ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.searchBgDark.withOpacity(0.3),
                                  light: MyntColors.searchBg.withOpacity(0.3),
                                ),
                                width: 1,
                              ),
                            ),
                                          child: Text(
                                          widget.watchListData["weekly"]?.toString() ?? "",
                                              // .toString()
                                              // .replaceAll("-EQ", "")
                                              // .toUpperCase(),
                                          style: MyntWebTextStyles.para(
                                            context,
                                            fontWeight: MyntFonts.medium,
                                            color: resolveThemeColor(
                                              context,
                                              dark: MyntColors.textPrimary ,
                                              light: MyntColors.textPrimary,
                                            ),
                                          ),
                                                                                ),
                                        ),


                                    ],
                                  ),
                                ),
                                // Right: LTP only
                                RepaintBoundary(
                                  child: _LTPWidgetWeb(
                                      token: widget.watchListData['token'],
                                      initialData: widget.watchListData),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 24,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${widget.watchListData["exch"]} ',
                                      style: MyntWebTextStyles.exch(
                                        context,
                                        fontWeight: FontWeight.w500,
                                        color: resolveThemeColor(
                                          context,
                                          dark: MyntColors.textSecondaryDark,
                                          light: MyntColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    if (widget.watchListData['expDate']
                                        .toString()
                                        .isNotEmpty)
                                      Text(
                                        "${widget.watchListData['expDate']}",
                                        style: MyntWebTextStyles.exch(
                                          context,
                                          fontWeight: FontWeight.w500,
                                          color: resolveThemeColor(
                                            context,
                                            dark: MyntColors.textSecondaryDark,
                                            light: MyntColors.textSecondary,
                                          ),
                                        ),
                                      ),
if (_isExpiryToday(widget.watchListData['expDate'])) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color:  resolveThemeColor(
                                  context,
                                  dark: MyntColors.overlayBgDark,
                                  light: MyntColors.overlayBg,
                                ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.searchBgDark.withOpacity(0.3),
                                  light: MyntColors.searchBg.withOpacity(0.3),
                                ),
                                width: 1,
                              ),
                            ),
                        child:

                         Text(
                                        "Expiry",
                                        style: MyntWebTextStyles.exch(
                                          context,
                                          fontWeight: FontWeight.w500,
                                          color: resolveThemeColor(
                                            context,
                                            dark: MyntColors.primaryDark,
                                            light: MyntColors.primary,
                                          ),
                                        ),
                                      ),
                        
                        
                       
                      ),
                    ],

                                    if (widget.watchListData['holdingQty'] !=
                                            null &&
                                        widget.watchListData['holdingQty']
                                            .toString()
                                            .isNotEmpty &&
                                        widget.watchListData['holdingQty'] !=
                                            "null") ...[
                                      SvgPicture.asset(assets.suitcase,
                                          height: 16,
                                          width: 16,
                                          color : resolveThemeColor(context,
                                          dark: MyntColors.primaryDark,
                                          light: MyntColors.primary.withOpacity(0.8)
                                          )),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${widget.watchListData['holdingQty']}",
                                        style: MyntWebTextStyles.exch(
                                          context,
                                          fontWeight: FontWeight.w500,
                                           color: resolveThemeColor(context,
                                            dark: MyntColors.primaryDark,
                                            light: MyntColors.primary)
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                                // Spacer
                                const Spacer(),
                                // Right: Price change only
                                RepaintBoundary(
                                  child: _PriceChangeWidgetWeb(
                                      token: widget.watchListData['token'],
                                      initialData: widget.watchListData),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Overlay action buttons - positioned absolutely
                    if (isHovered || _isMenuOpen)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: Center(
                          child: Builder(
                            builder: (context) {
                              // Check if this is an index or commodity
                              final instname = widget.watchListData["instname"]
                                      ?.toString() ??
                                  "";
                              final isIndexOrCommodity =
                                  instname == "UNDIND" || instname == "COM";
                              final bool isPredefined =
                                  marketWatch.isPreDefWLs == "Yes";

                              return Container(
                                decoration: BoxDecoration(
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.backgroundColorDark,
                                    light: MyntColors.backgroundColor,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: HoverActionsContainer(
                                  isVisible: true,
                                  actions: [
                                    // Only show Buy/Sell buttons if not index or commodity
                                    if (!isIndexOrCommodity) ...[
                                      HoverActionButton(
                                        label: 'B',
                                        color: Colors.white,
                                        backgroundColor: resolveThemeColor(
                                          context,
                                          dark: MyntColors.secondary,
                                          light: MyntColors.primary,
                                        ),
                                        borderColor: resolveThemeColor(
                                          context,
                                          dark: MyntColors.secondary,
                                          light: MyntColors.primary,
                                        ),
                                        onPressed: () async {
                                          try {
                                            await _placeOrderInput(
                                                context, depthData, true);
                                          } catch (e) {
                                          }
                                        },
                                      ),
                                      HoverActionButton(
                                        label: 'S',
                                        color: Colors.white,
                                        backgroundColor: resolveThemeColor(
                                          context,
                                          dark: MyntColors.errorDark,
                                          light: MyntColors.tertiary,
                                        ),
                                        borderColor: resolveThemeColor(
                                          context,
                                          dark: MyntColors.errorDark,
                                          light: MyntColors.tertiary,
                                        ),
                                        onPressed: () async {
                                          try {
                                            await _placeOrderInput(
                                                context, depthData, false);
                                          } catch (e) {
                                          }
                                        },
                                      ),
                                    ],
                                    HoverActionButton(
                                      iconAsset: assets.depthIcon,
                                      color: resolveThemeColor(
                                        context,
                                        dark: MyntColors.textPrimary,
                                        light: Colors.black,
                                      ),
                                      backgroundColor: Colors.transparent,
                                      onPressed: () async {
                                        if (_isNavigating) return;

                                        ref
                                            .read(expandedWatchlistItemProvider
                                                .notifier)
                                            .setExpandedToken(null);

                                        try {
                                          setState(() {
                                            _isNavigating = true;
                                          });

                                          DepthInputArgs depthArgs =
                                              DepthInputArgs(
                                            exch: widget.watchListData["exch"]
                                                .toString(),
                                            token: widget.watchListData["token"]
                                                .toString(),
                                            tsym: widget.watchListData["tsym"]
                                                .toString(),
                                            instname: widget
                                                    .watchListData["instname"]
                                                    ?.toString() ??
                                                widget.watchListData["symbol"]
                                                    .toString(),
                                            symbol: widget
                                                .watchListData["symbol"]
                                                .toString(),
                                            expDate: widget
                                                    .watchListData["expDate"]
                                                    ?.toString() ??
                                                "",
                                            option: widget
                                                    .watchListData["option"]
                                                    ?.toString() ??
                                                "",
                                          );

                                          marketWatch.scripdepthsize(false);
                                          // Call depth APIs first to set active tab
                                          await marketWatch.calldepthApis(
                                              context, depthArgs, "");

                                          // Set depth visible AFTER calldepthApis completes
                                          // Pass depth args directly to ensure correct token/exch/tsym are used
                                          // This triggers lazy load of depth data with proper context
                                          await ref
                                              .read(marketWatchProvider)
                                              .setIsDepthVisibleWeb(
                                                true,
                                                context: context,
                                                exch: depthArgs.exch,
                                                token: depthArgs.token,
                                                tsym: depthArgs.tsym,
                                              );
                                        } catch (e) {
                                        } finally {
                                          if (mounted) {
                                            Future.delayed(
                                                const Duration(
                                                    milliseconds: 500), () {
                                              if (mounted) {
                                                setState(() {
                                                  _isNavigating = false;
                                                });
                                              }
                                            });
                                          }
                                        }
                                      },
                                    ),
                                    // Delete button (only for non-predefined watchlists)
                                    if (!isPredefined)
                                      HoverActionButton(
                                        iconAsset: assets.trash,
                                        color: resolveThemeColor(
                                          context,
                                          dark: MyntColors.textPrimary,
                                          light: Colors.black,
                                        ),
                                        backgroundColor: Colors.transparent,
                                        onPressed: () async {
                                          try {
                                            final String exch = widget
                                                    .watchListData["exch"]
                                                    ?.toString() ??
                                                "";
                                            final String token = widget
                                                    .watchListData["token"]
                                                    ?.toString() ??
                                                "";
                                            final String input =
                                                "$exch|$token#";

                                            if (_isNavigating) return;
                                            setState(() {
                                              _isNavigating = true;
                                            });

                                            await ref
                                                .read(marketWatchProvider)
                                                .addDelMarketScrip(
                                                    marketWatch.wlName,
                                                    input,
                                                    context,
                                                    false,
                                                    false,
                                                    false,
                                                    false);
                                            if (mounted) {
                                              showResponsiveSuccess(context,
                                                  'Scrip removed from watchlist');
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              showResponsiveError(context,
                                                  'Failed to delete scrip');
                                            }
                                          } finally {
                                            if (mounted) {
                                              Future.delayed(
                                                  const Duration(
                                                      milliseconds: 400), () {
                                                if (mounted) {
                                                  setState(() {
                                                    _isNavigating = false;
                                                  });
                                                }
                                              });
                                            }
                                          }
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
              ),
            ),
          ),
          // Expandable content section
          // if (_isExpanded)
          //   AnimatedSize(
          //     duration: const Duration(milliseconds: 300),
          //     curve: Curves.easeInOut,
          //     child: Container(
          //       width: double.infinity,
          //       // color: theme.isDarkMode ? MyntColors.surfaceVariant : MyntColors.surfaceVariant,
          //       padding: const EdgeInsets.fromLTRB(16, 16, 28,
          //           16), // Extra right padding to prevent scrollbar overlap
          //       child: _buildExpandedContent(depthData, theme),
          //     ),
          //   ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(GetQuotes depthData, ThemesProvider theme) {
    // Get current token for this specific card
    final currentToken = widget.watchListData['token']?.toString() ?? "";

    return StreamBuilder<dynamic>(
      // PERFORMANCE FIX: Use ref.read() for stream access - stream itself is reactive
      stream: ref.read(websocketProvider).socketDataStream,
      builder: (context, snapshot) {
        Map<String, dynamic> socketData;

        if (snapshot.hasData) {
          final socketDatas = Map<String, dynamic>.from(snapshot.data as Map);
          socketData = socketDatas.containsKey(currentToken)
              ? Map<String, dynamic>.from(
                  socketDatas[currentToken] as Map? ?? {})
              : <String, dynamic>{};
        } else {
          final existingSocketData = ref.read(websocketProvider).socketDatas;
          socketData = existingSocketData.containsKey(currentToken)
              ? Map<String, dynamic>.from(
                  existingSocketData[currentToken] ?? {})
              : <String, dynamic>{};
        }

        // Priority: Socket data → Watchlist data → Default
        final open = socketData['o']?.toString() ??
            widget.watchListData['open']?.toString() ??
            '0.00';
        final high = socketData['h']?.toString() ??
            widget.watchListData['high']?.toString() ??
            '0.00';
        final low = socketData['l']?.toString() ??
            widget.watchListData['low']?.toString() ??
            '0.00';
        final close = socketData['c']?.toString() ??
            widget.watchListData['close']?.toString() ??
            '0.00';
        final volume = socketData['v']?.toString() ??
            widget.watchListData['volume']?.toString() ??
            '0';
        final avgPrice = socketData['ap']?.toString() ?? '0.00';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Open, High, Low, Prev Close in grid format (always shown)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(theme, "Open", open),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoItem(theme, "High", high),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(theme, "Low", low),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoItem(theme, "Prev Close", close),
                    ),
                  ],
                ),
              ],
            ),
            // Market Depth Section (only for non-index/non-commodity)
            if (widget.watchListData['instname']?.toString() != "UNDIND" &&
                widget.watchListData['instname']?.toString() != "COM") ...[
              const SizedBox(height: 16),
              _buildMarketDepthSection(socketData, theme),
              const SizedBox(height: 16),
            ],

            // Trading Info Section
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(theme, "Avg Price", avgPrice),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoItem(theme, "Volume", volume),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                          theme,
                          "LTQ",
                          socketData['ltq']?.toString() ??
                              widget.watchListData['ltq']?.toString() ??
                              "0"),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoItem(
                          theme,
                          "LTT",
                          socketData['ltt']?.toString() ??
                              widget.watchListData['ltt']?.toString() ??
                              "--"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Open Interest (only for futures/options, not equity)
                if (depthData.seg != "EQT") ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                            theme,
                            "Open Interest",
                            socketData['oi']?.toString() ??
                                widget.watchListData['oi']?.toString() ??
                                "0"),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoItem(
                            theme,
                            "Change in OI",
                            socketData['poi']?.toString() ??
                                widget.watchListData['poi']?.toString() ??
                                "0"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 52 Week High-Low
                _buildInfoItem(theme, "52 Weeks High-Low",
                    "${socketData['52h']?.toString() ?? widget.watchListData['52h']?.toString() ?? "0.00"} - ${socketData['52l']?.toString() ?? widget.watchListData['52l']?.toString() ?? "0.00"}"),
                const SizedBox(height: 12),

                // Daily Price Range (DPR)
                _buildInfoItem(theme, "DPR",
                    "${socketData['uc']?.toString() ?? widget.watchListData['uc']?.toString() ?? "0.00"} - ${socketData['lc']?.toString() ?? widget.watchListData['lc']?.toString() ?? "0.00"}"),
              ],
            ),
          ],
        );
      },
    );
  }

  // Market Depth Section with Bid/Ask data
  Widget _buildMarketDepthSection(
      Map<String, dynamic> socketData, ThemesProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Market Depth Header
        // Text(
        //   "Market Depth",
        //   style: WebTextStyles.title(
        //     isDarkTheme: theme.isDarkMode,
        //     color: theme.isDarkMode ? MyntColors.textPrimary : MyntColors.textPrimary,
        //     fontWeight: WebFonts.medium,
        //   ),
        // ),
        // const SizedBox(height: 12),

        Row(
          children: [
            // Bid Side
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Quantity",
                          style: WebTextStyles.para(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? MyntColors.textSecondary
                                : MyntColors.textSecondary,
                            fontWeight: WebFonts.regular,
                          ),
                        ),
                        Text(
                          "Bid",
                          style: WebTextStyles.para(
                            isDarkTheme: theme.isDarkMode,
                            color: MyntColors.secondary,
                            fontWeight: WebFonts.regular,
                          ),
                        )
                      ]),
                  const SizedBox(height: 8),
                  _buildDepthRow(socketData['bq1']?.toString() ?? "0",
                      socketData['bp1']?.toString() ?? "0.00", theme),
                  _buildDepthRow(socketData['bq2']?.toString() ?? "0",
                      socketData['bp2']?.toString() ?? "0.00", theme),
                  _buildDepthRow(socketData['bq3']?.toString() ?? "0",
                      socketData['bp3']?.toString() ?? "0.00", theme),
                  _buildDepthRow(socketData['bq4']?.toString() ?? "0",
                      socketData['bp4']?.toString() ?? "0.00", theme),
                  _buildDepthRow(socketData['bq5']?.toString() ?? "0",
                      socketData['bp5']?.toString() ?? "0.00", theme),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Ask Side
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Ask",
                          style: WebTextStyles.para(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? MyntColors.loss
                                : MyntColors.loss,
                            fontWeight: WebFonts.regular,
                          ),
                        ),
                        Text(
                          "Quantity",
                          style: WebTextStyles.para(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? MyntColors.textSecondary
                                : MyntColors.textSecondary,
                            fontWeight: WebFonts.regular,
                          ),
                        )
                      ]),
                  const SizedBox(height: 8),
                  _buildDepthRow(socketData['sp1']?.toString() ?? "0.00",
                      socketData['sq1']?.toString() ?? "0", theme,
                      isAsk: true),
                  _buildDepthRow(socketData['sp2']?.toString() ?? "0.00",
                      socketData['sq2']?.toString() ?? "0", theme,
                      isAsk: true),
                  _buildDepthRow(socketData['sp3']?.toString() ?? "0.00",
                      socketData['sq3']?.toString() ?? "0", theme,
                      isAsk: true),
                  _buildDepthRow(socketData['sp4']?.toString() ?? "0.00",
                      socketData['sq4']?.toString() ?? "0", theme,
                      isAsk: true),
                  _buildDepthRow(socketData['sp5']?.toString() ?? "0.00",
                      socketData['sq5']?.toString() ?? "0", theme,
                      isAsk: true),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Total Quantities
        _buildTotalQuantities(socketData, theme),
      ],
    );
  }

  // Helper to build total quantities with percentages
  Widget _buildTotalQuantities(
      Map<String, dynamic> socketData, ThemesProvider theme) {
    final scripInfo = ref.read(marketWatchProvider);
    final tbq = socketData['tbq']?.toString() ?? "0";
    final tsq = socketData['tsq']?.toString() ?? "0";

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  tbq,
                  style: WebTextStyles.sub(
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? MyntColors.textSecondary
                        : MyntColors.textSecondary,
                    fontWeight: WebFonts.regular,
                    letterSpacing: 0.0,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "(${scripInfo.totBuyQtyPer.toStringAsFixed(2)}%)",
                  style: WebTextStyles.para(
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? MyntColors.textSecondary
                        : MyntColors.textSecondary,
                    fontWeight: WebFonts.regular,
                    letterSpacing: 0.0,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  "(${scripInfo.totSellQtyPer.toStringAsFixed(2)}%)",
                  style: WebTextStyles.para(
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? MyntColors.textSecondary
                        : MyntColors.textSecondary,
                    fontWeight: WebFonts.regular,
                    letterSpacing: 0.0,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  tsq,
                  style: WebTextStyles.sub(
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? MyntColors.textSecondary
                        : MyntColors.textSecondary,
                    fontWeight: WebFonts.regular,
                    letterSpacing: 0.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (scripInfo.totBuyQtyPer.toStringAsFixed(2) != "0.00" ||
            scripInfo.totSellQtyPer.toStringAsFixed(2) != "0.00")
          Column(
            children: [
              const SizedBox(height: 10),
              LinearPercentIndicator(
                lineHeight: 5.0,
                barRadius: const Radius.circular(4.0),
                backgroundColor:
                    theme.isDarkMode ? MyntColors.error : MyntColors.error,
                percent: scripInfo.totBuyQtyPerChng,
                padding: const EdgeInsets.symmetric(horizontal: 0),
                progressColor:
                    theme.isDarkMode ? MyntColors.primary : MyntColors.primary,
              ),
            ],
          ),
      ],
    );
  }

  // Helper to build market depth rows
  Widget _buildDepthRow(String value1, String value2, ThemesProvider theme,
      {bool isAsk = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isAsk ? value1 : value1, // Price for ask, Qty for bid
            style: WebTextStyles.para(
              isDarkTheme: theme.isDarkMode,
              color: isAsk
                  ? (theme.isDarkMode ? MyntColors.loss : MyntColors.loss)
                  : (theme.isDarkMode
                      ? MyntColors.textSecondary
                      : MyntColors.textSecondary),
              fontWeight: WebFonts.regular,
            ),
          ),
          Text(
            isAsk ? value2 : value2, // Qty for ask, Price for bid
            style: WebTextStyles.para(
              isDarkTheme: theme.isDarkMode,
              color: isAsk
                  ? (theme.isDarkMode
                      ? MyntColors.textSecondary
                      : MyntColors.textSecondary)
                  : (theme.isDarkMode
                      ? MyntColors.secondary
                      : MyntColors.secondary),
              fontWeight: WebFonts.regular,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketDepth(ThemesProvider theme, MarketWatchProvider scripInfo,
      GetQuotes depthData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Quantity",
                          style: WebTextStyles.para(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? MyntColors.textSecondary
                                : MyntColors.textSecondary,
                            fontWeight: WebFonts.regular,
                          ),
                        ),
                        Text(
                          "Bid",
                          style: WebTextStyles.para(
                            isDarkTheme: theme.isDarkMode,
                            color: MyntColors.secondary,
                            fontWeight: WebFonts.regular,
                          ),
                        )
                      ]),
                  const SizedBox(height: 6),
                  _buildBidDepthRow("${depthData.bq1 ?? 0}",
                      "${depthData.bp1 ?? 0.00}", theme),
                  const SizedBox(height: 4),
                  _buildBidDepthRow("${depthData.bq2 ?? 0}",
                      "${depthData.bp2 ?? 0.00}", theme),
                  const SizedBox(height: 4),
                  _buildBidDepthRow("${depthData.bq3 ?? 0}",
                      "${depthData.bp3 ?? 0.00}", theme),
                  const SizedBox(height: 4),
                  _buildBidDepthRow("${depthData.bq4 ?? 0}",
                      "${depthData.bp4 ?? 0.00}", theme),
                  const SizedBox(height: 4),
                  _buildBidDepthRow("${depthData.bq5 ?? 0}",
                      "${depthData.bp5 ?? 0.00}", theme)
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Ask",
                          style: WebTextStyles.para(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? MyntColors.error
                                : MyntColors.error,
                            fontWeight: WebFonts.regular,
                            letterSpacing: 0.0,
                          ),
                        ),
                        Text(
                          "Quantity",
                          style: WebTextStyles.para(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? MyntColors.textSecondary
                                : MyntColors.textSecondary,
                            fontWeight: WebFonts.regular,
                            letterSpacing: 0.0,
                          ),
                        )
                      ]),
                  const SizedBox(height: 6),
                  _buildAskDepthRow("${depthData.sp1 ?? 0.00}",
                      "${depthData.sq1 ?? 0}", theme),
                  const SizedBox(height: 4),
                  _buildAskDepthRow("${depthData.sp2 ?? 0.00}",
                      "${depthData.sq2 ?? 0}", theme),
                  const SizedBox(height: 4),
                  _buildAskDepthRow("${depthData.sp3 ?? 0.00}",
                      "${depthData.sq3 ?? 0}", theme),
                  const SizedBox(height: 4),
                  _buildAskDepthRow("${depthData.sp4 ?? 0.00}",
                      "${depthData.sq4 ?? 0}", theme),
                  const SizedBox(height: 4),
                  _buildAskDepthRow("${depthData.sp5 ?? 0.00}",
                      "${depthData.sq5 ?? 0}", theme)
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(
            children: [
              Text(
                "${depthData.tbq != "null" ? depthData.tbq ?? 0 : '0'}",
                style: WebTextStyles.para(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? MyntColors.textSecondary
                      : MyntColors.textSecondary,
                  fontWeight: WebFonts.regular,
                ),
              ),
              const SizedBox(
                width: 4,
              ),
              Text(
                "(${scripInfo.totBuyQtyPer.toStringAsFixed(2)}%)",
                style: WebTextStyles.para(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? MyntColors.textSecondary
                      : MyntColors.textSecondary,
                  fontWeight: WebFonts.regular,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                "(${scripInfo.totSellQtyPer.toStringAsFixed(2)}%)",
                style: WebTextStyles.para(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? MyntColors.textSecondary
                      : MyntColors.textSecondary,
                  fontWeight: WebFonts.regular,
                  letterSpacing: 0.0,
                ),
              ),
              const SizedBox(
                width: 4,
              ),
              Text(
                "${depthData.tsq != "null" ? depthData.tsq ?? 0 : '0'}",
                style: WebTextStyles.para(
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? MyntColors.textSecondary
                      : MyntColors.textSecondary,
                  fontWeight: WebFonts.regular,
                  letterSpacing: 0.0,
                ),
              ),
            ],
          )
        ]),
        (scripInfo.totBuyQtyPer.toStringAsFixed(2) == "0.00" &&
                scripInfo.totSellQtyPer.toStringAsFixed(2) == "0.00")
            ? const SizedBox()
            : Column(
                children: [
                  const SizedBox(height: 10),
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
                      lineHeight: 5.0,
                      barRadius: const Radius.circular(
                          4.0), // Half of lineHeight for capsule shape
                      backgroundColor:
                          (scripInfo.totBuyQtyPer.toStringAsFixed(2) ==
                                      "0.00" &&
                                  scripInfo.totSellQtyPer.toStringAsFixed(2) ==
                                      "0.00")
                              ? theme.isDarkMode
                                  ? MyntColors.textSecondary
                                  : MyntColors.textSecondary
                              : theme.isDarkMode
                                  ? MyntColors.error
                                  : MyntColors.error,
                      percent: scripInfo.totBuyQtyPerChng,
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      progressColor: theme.isDarkMode
                          ? MyntColors.primary
                          : MyntColors.primary),
                  const SizedBox(height: 16),
                ],
              ),
      ],
    );
  }

  Widget _buildBidDepthRow(String qty, String price, ThemesProvider theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          " ${qty != "null" ? qty : '0'} ",
          style: WebTextStyles.para(
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode
                ? MyntColors.textSecondary
                : MyntColors.textSecondary,
          ),
        ),
        Text(
          " ${price != "null" ? price : '0.00'} ",
          style: WebTextStyles.para(
            isDarkTheme: theme.isDarkMode,
            color:
                theme.isDarkMode ? MyntColors.secondary : MyntColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAskDepthRow(String price, String qty, ThemesProvider theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          " ${price != "null" ? price : '0.00'} ",
          style: WebTextStyles.para(
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode ? MyntColors.error : MyntColors.error,
          ),
        ),
        Text(
          " ${qty != "null" ? qty : '0'} ",
          style: WebTextStyles.para(
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode
                ? MyntColors.textSecondary
                : MyntColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(ThemesProvider theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: WebTextStyles.para(
              isDarkTheme: theme.isDarkMode,
              color: theme.isDarkMode
                  ? MyntColors.textSecondary
                  : MyntColors.textSecondary,
              fontWeight: WebFonts.regular,
              letterSpacing: 0.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: WebTextStyles.sub(
              isDarkTheme: theme.isDarkMode,
              color: theme.isDarkMode
                  ? MyntColors.textPrimary
                  : MyntColors.textPrimary,
              fontWeight: WebFonts.regular,
              letterSpacing: 0.0,
            ),
          ),
          const SizedBox(height: 4),
          Divider(
            color: theme.isDarkMode ? MyntColors.divider : MyntColors.divider,
          ),
        ],
      ),
    );
  }

  Widget _buildThreeDotsMenu({
    required ThemesProvider theme,
    required bool hasFutures,
    required bool hasFundamentals,
    required bool hasOptions,
    required String exch,
    required String token,
    required GetQuotes depthData,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Material(
        key: _menuButtonKey,
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          splashColor: theme.isDarkMode
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.15),
          highlightColor: theme.isDarkMode
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.08),
          onTap: () {
            setState(() {
              _isMenuOpen = true;
            });

            // Use GlobalKey to get the correct render box position
            final RenderBox? button =
                _menuButtonKey.currentContext?.findRenderObject() as RenderBox?;
            if (button == null || !button.attached) return;

            final RenderBox overlay =
                Overlay.of(context).context.findRenderObject() as RenderBox;

            // Get the button's position in overlay coordinates
            final Offset buttonTopLeft = button.localToGlobal(
              Offset.zero,
              ancestor: overlay,
            );
            final Offset buttonBottomRight = button.localToGlobal(
              button.size.bottomRight(Offset.zero),
              ancestor: overlay,
            );

            // Position menu below the button, with menu's top-right aligned to button's bottom-right
            // Calculate with a small offset for spacing
            const double menuSpacing = 4.0; // Small gap between button and menu
            final RelativeRect position = RelativeRect.fromLTRB(
              buttonTopLeft
                  .dx, // Left edge starts from button left (menu can extend left)
              buttonBottomRight.dy +
                  menuSpacing, // Menu top is below button bottom with spacing
              overlay.size.width -
                  buttonBottomRight
                      .dx, // Menu right edge aligns with button right edge
              overlay.size.height -
                  buttonBottomRight.dy -
                  200, // Leave room for menu height
            );

            showMenu<String>(
              context: context,
              position: position,
              color: resolveThemeColor(context,
                  dark: MyntColors.backgroundColorDark,
                  light: MyntColors.backgroundColor),
              elevation: 8,
              shape: const RoundedRectangleBorder(
                  // borderRadius: BorderRadius.circular(),
                  ),
              items: [
                if (hasFutures)
                  PopupMenuItem<String>(
                    value: 'futures',
                    child: Row(
                      children: [
                        Text(
                          'Futures',
                          style: WebTextStyles.bodySmall(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? MyntColors.textPrimary
                                : MyntColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hasFundamentals)
                  PopupMenuItem<String>(
                    value: 'fundamentals',
                    child: Text(
                      'Fundamentals',
                      style: WebTextStyles.bodySmall(
                        isDarkTheme: false,
                        color: MyntColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (hasOptions)
                  PopupMenuItem<String>(
                    value: 'options',
                    child: Text(
                      'Options Chain',
                      style: WebTextStyles.bodySmall(
                        isDarkTheme: false,
                        color: MyntColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                PopupMenuItem<String>(
                  value: 'setAlert',
                  child: Text(
                    'Set Alert',
                    style: WebTextStyles.bodySmall(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? MyntColors.textPrimary
                          : MyntColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'deleteMultiple',
                  child: Text(
                    'Delete Multiple',
                    style: WebTextStyles.bodySmall(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? MyntColors.textPrimary
                          : MyntColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ).then((value) {
              setState(() {
                _isMenuOpen = false;
              });
              if (value != null) {
                _handleMenuAction(value, depthData, exch, token);
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              // border: Border.all(
              //   color: theme.isDarkMode
              //       ? MyntColors.border
              //       : MyntColors.border,
              //   width: 1,
              // ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Transform.rotate(
                angle: 1.5708, // 90 degrees in radians (π/2)
                child: SvgPicture.asset(
                  assets.threedots,
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(
                    theme.isDarkMode
                        ? MyntColors.textSecondaryDark
                        : MyntColors.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(
      String action, GetQuotes depthData, String exch, String token) async {
    if (_isNavigating) return;

    final marketWatch = ref.read(marketWatchProvider);
    final theme = ref.read(themeProvider);

    try {
      setState(() {
        _isNavigating = true;
      });

      if (action == 'futures') {
        // Load futures data first
        marketWatch.singlePageloader(true);

        try {
          // Fetch linked scripts (this loads futures data)
          // await marketWatch.fetchScripQuote(token, exch, context);
          // await marketWatch.fetchScripQuoteIndex(token, exch, context);
          if (marketWatch.getOptionawait(exch, token)) {
            await marketWatch.fetchScripInfo(token, exch, context);
            await marketWatch.fetchLinkeScrip(token, exch, context);
            // Request futures WebSocket data
          }
          await marketWatch.requestWSFut(context: context, isSubscribe: true);

          if (!mounted) return;

          // Open only futures screen in a dialog
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext dialogContext) {
              return Dialog(
                backgroundColor: resolveThemeColor(context,
                    dark: MyntColors.backgroundColorDark,
                    light: MyntColors.backgroundColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  width: context.responsive(
                    mobile: context.screenWidth * 0.95,
                    tablet: 550.0,
                    desktop: 600.0,
                  ),
                  constraints: BoxConstraints(
                    maxHeight: context.screenHeight * 0.4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, top: 10, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Futures',
                              style: WebTextStyles.title(
                                isDarkTheme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? MyntColors.textPrimary
                                    : MyntColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
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
                                onTap: () {
                                  // Unsubscribe from futures WebSocket
                                  marketWatch.requestWSFut(
                                      context: context, isSubscribe: false);
                                  Navigator.of(context).pop();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: theme.isDarkMode
                                        ? MyntColors.textSecondaryDark
                                        : MyntColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Info message
                      // Container(
                      //   padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      //   decoration: BoxDecoration(
                      //     color: theme.isDarkMode
                      //         ? MyntColors.primary.withOpacity(0.1)
                      //         : MyntColors.primary.withOpacity(0.1),
                      //     borderRadius: BorderRadius.circular(6),
                      //   ),
                      //   child: Row(
                      //     mainAxisAlignment: MainAxisAlignment.center,
                      //     children: [
                      //       Icon(
                      //         Icons.info_outline,
                      //         size: 16,
                      //         color: theme.isDarkMode
                      //             ? MyntColors.primary
                      //             : MyntColors.primary,
                      //       ),
                      //       const SizedBox(width: 8),
                      //       Text(
                      //         'Long press to add ${marketWatch.wlName}\'s Watchlist',
                      //         style: WebTextStyles.para(
                      //           isDarkTheme: theme.isDarkMode,
                      //           color: theme.isDarkMode
                      //               ? MyntColors.primary
                      //               : MyntColors.primary,
                      //           fontWeight: FontWeight.w500,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      // const SizedBox(height: 8),
                      // Futures content - Use IntrinsicHeight to size to content
                      Consumer(
                        builder: (context, ref, _) {
                          return const FutureScreenWeb();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        } finally {
          if (mounted) {
            marketWatch.singlePageloader(false);
          }
        }
      } else if (action == 'fundamentals') {
        // Open fundamentals in a dialog
        marketWatch.singlePageloader(true);

        try {
          // Always fetch fresh fundamental data for the current scrip
          await marketWatch.fetchFundamentalData(
            tradeSym: "$exch:${widget.watchListData["tsym"]?.toString() ?? ""}",
          );

          if (!mounted) return;

          if (marketWatch.fundamentalData != null &&
              marketWatch.fundamentalData?.msg != "no data found") {
            // Create DepthInputArgs and get depth data
            DepthInputArgs depthArgs = _createDepthArgs();
            final depthData = marketWatch.getQuotes!;

            // Show as dialog
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (BuildContext dialogContext) {
                  return Dialog(
                    backgroundColor: resolveThemeColor(context,
                        dark: MyntColors.backgroundColorDark,
                        light: MyntColors.backgroundColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      width: context.responsive(
                        mobile: context.screenWidth * 0.95,
                        tablet: 600.0,
                        desktop: 700.0,
                      ),
                      constraints: BoxConstraints(
                        maxHeight: context.screenHeight * 0.8,
                        minHeight: 400,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${depthArgs.symbol.replaceAll("-EQ", "").toUpperCase()}${depthArgs.expDate} ${depthArgs.option} Stock Report',
                                  style: WebTextStyles.title(
                                    isDarkTheme: theme.isDarkMode,
                                    color: theme.isDarkMode
                                        ? MyntColors.textPrimary
                                        : MyntColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
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
                                    onTap: () => Navigator.of(context).pop(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.close,
                                        size: 20,
                                        color: theme.isDarkMode
                                            ? MyntColors.textSecondaryDark
                                            : MyntColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Content without AppBar
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                              child: MediaQuery.removePadding(
                                context: context,
                                removeTop: true,
                                child: NewFundamentalScreen(
                                  wlValue: depthArgs,
                                  depthData: depthData,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          }
        } finally {
          if (mounted) {
            marketWatch.singlePageloader(false);
          }
        }
      } else if (action == 'options') {
        // Open Options Chain
        try {
          // Setup option script
          final tsym = widget.watchListData["tsym"]?.toString() ?? "";
          marketWatch.setOptionScript(context, exch, token, tsym);

          // Wait for setup to complete
          await Future.delayed(const Duration(milliseconds: 150));

          if (!mounted) return;

          // Navigate to options chain
          final DepthInputArgs wlValue = _createDepthArgs();
          if (kIsWeb && WebNavigationHelper.isAvailable) {
            WebNavigationHelper.navigateTo("optionChain", arguments: wlValue);
          } else {
            await Navigator.pushNamed(context, Routes.optionChainWeb,
                arguments: wlValue);
          }
        } catch (e) {
          if (mounted) {
            showResponsiveError(context, 'Failed to open Options Chain');
          }
        }
      } else if (action == 'setAlert') {
        try {
          // Reset state before showing dialog
          await marketWatch.chngDephBtn("Overview");

          if (!mounted) return;

          // Get depth data from provider and create depth args
          final depthData = marketWatch.getQuotes!;
          final depthArgs = _createDepthArgs();

          // Show Set Alert dialog
          _showSetAlertDialog(context, depthData, depthArgs);

          // Reset state after dialog is closed
          if (mounted) {
            await marketWatch.chngDephBtn("Overview");
          }
        } catch (e) {
          if (mounted) {
            showResponsiveError(
              context,
              'Failed to open Set Alert screen',
            );
          }
        }
      } else if (action == 'deleteMultiple') {
        try {
          // Enable delete mode in the watchlist screen
          ref.read(deleteModeProvider.notifier).setDeleteMode(true);
        } catch (e) {
          if (mounted) {
            showResponsiveError(
              context,
              'Failed to open Delete Multiple screen',
            );
          }
        }
      }
    } catch (e) {
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

  // Helper to create DepthInputArgs from watchlist data
  DepthInputArgs _createDepthArgs() {
    return DepthInputArgs(
      exch: widget.watchListData["exch"].toString(),
      token: widget.watchListData["token"].toString(),
      tsym: widget.watchListData["tsym"].toString(),
      instname: widget.watchListData["instname"]?.toString() ??
          widget.watchListData["symbol"].toString(),
      symbol: widget.watchListData["symbol"].toString(),
      expDate: widget.watchListData["expDate"]?.toString() ?? "",
      option: widget.watchListData["option"]?.toString() ?? "",
    );
  }

  void _showSetAlertDialog(
      BuildContext context, GetQuotes depthData, DepthInputArgs depthArgs) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return SetAlertWeb(
          depthdata: depthData,
          wlvalue: depthArgs,
        );
      },
    );
  }

  // Helper method to safely parse numeric values
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

  // Helper method to safely parse lot size
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

  Future<void> _placeOrderInput(
      BuildContext ctx, GetQuotes depthData, bool transType) async {
    try {
      // Prevent multiple simultaneous calls
      if (_isNavigating) return;

      setState(() {
        _isNavigating = true;
      });

      final currentToken = widget.watchListData['token']?.toString() ?? "";
      final currentExch = widget.watchListData['exch']?.toString() ?? "";
      final currentTsym = widget.watchListData['tsym']?.toString() ?? "";


      // Update chart/depth view to show this stock before opening order screen
      final subscriptionManager = ref.read(webSubscriptionManagerProvider);
      
      if (subscriptionManager.activeScreens.values.any((s) => s == ScreenType.scripDepthInfo)) {
  final depthArgs = DepthInputArgs(
    token: currentToken,
    exch: currentExch,
    tsym: currentTsym,
    instname: widget.watchListData['instname']?.toString() ??
        widget.watchListData['symbol']?.toString() ??
        "",
    symbol: widget.watchListData['symbol']?.toString() ?? "",
    expDate: widget.watchListData['expDate']?.toString() ?? "",
    option: widget.watchListData['option']?.toString() ?? "",
    isOption: false,
  );
  
  final marketWatch = ref.read(marketWatchProvider);
  marketWatch.scripdepthsize(false);
  await marketWatch.calldepthApis(context, depthArgs, "");
  
  // Also update chart script
  marketWatch.setChartScript(currentExch, currentToken, currentTsym);
}

      // OPTIMIZED: Fetch scripInfo and quotes in PARALLEL (saves ~300ms)
      // linkedScrips loaded in background after order screen opens
      final marketWatch = ref.read(marketWatchProvider);
      await Future.wait([
        marketWatch.fetchScripInfo(currentToken, currentExch, context, true),
        marketWatch.fetchScripQuote(currentToken, currentExch, context),
      ]);

      // Ensure scripInfo is loaded before proceeding
      final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
      if (scripInfo == null) {
        throw Exception('Failed to load scrip information');
      }

      // Get fresh quote data after fetchScripQuote
      final freshQuoteData = ref.read(marketWatchProvider).getQuotes;

      // Also check websocket data for the current token as it has the most up-to-date LTP
      final wsProvider = ref.read(websocketProvider);
      final socketData = wsProvider.socketDatas[currentToken];

      // Priority: Websocket data > Fresh quote data > Watchlist data > Stale depthData
      String? ltp;
      String? perChange;

      // Helper function to check if a value is valid
      bool isValidPrice(String? value) {
        if (value == null || value.isEmpty) return false;
        final normalized = value.trim();
        return normalized != '0' &&
            normalized != '0.0' &&
            normalized != '0.00' &&
            normalized != 'null' &&
            normalized != 'NaN' &&
            normalized != 'Infinity';
      }

      // Try websocket data first (most up-to-date)
      if (socketData != null) {
        final wsLtp = socketData['lp']?.toString();
        final wsPc = socketData['pc']?.toString();
        if (isValidPrice(wsLtp)) {
          ltp = wsLtp;
          perChange = wsPc;
        }
      }

      // Fallback to fresh quote data
      if (!isValidPrice(ltp) && freshQuoteData != null) {
        final quoteLtp = freshQuoteData.lp ?? freshQuoteData.c;
        if (isValidPrice(quoteLtp)) {
          ltp = quoteLtp;
          perChange = freshQuoteData.pc;
        }
      }

      // Fallback to watchlist data
      if (!isValidPrice(ltp)) {
        final wlLtp = widget.watchListData['ltp']?.toString();
        if (isValidPrice(wlLtp)) {
          ltp = wlLtp;
          perChange = widget.watchListData['perChange']?.toString();
        }
      }

      // Final fallback to depthData (stale but better than nothing)
      if (!isValidPrice(ltp)) {
        final depthLtp = depthData.lp ?? depthData.c;
        if (isValidPrice(depthLtp)) {
          ltp = depthLtp;
          perChange = depthData.pc;
        }
      }


      // Use exact lot size logic from reference implementation
      final isBasketMode = widget.watchListData['isBasket']?.toString() ?? "";
      final lotSize = isBasketMode == "BasketMode"
          ? _safeParseLotSize(
              scripInfo.ls, freshQuoteData?.ls ?? depthData.ls, "1")
          : _safeParseLotSize(
              freshQuoteData?.ls ?? depthData.ls, scripInfo.ls, "1");

      // Use safe parsing for price values with fresh data
      final safeLtp = _safeParseNumeric(ltp, "0.00");
      final safePerChange = _safeParseNumeric(perChange, "0.00");


      // If we still don't have valid LTP data after all fallbacks, show error
      if (safeLtp == "0.00" || safeLtp.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Price data not available yet. Please wait a moment and try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }


      OrderScreenArgs orderArgs = OrderScreenArgs(
          exchange: widget.watchListData['exch']?.toString() ?? "",
          tSym: widget.watchListData['tsym']?.toString() ?? "",
          isExit: false,
          token: widget.watchListData['token']?.toString() ?? "",
          transType: transType,
          lotSize: lotSize,
          ltp: safeLtp,
          perChange: safePerChange,
          orderTpye: '',
          holdQty: '',
          isModify: false,
          raw: {});

      // Open order screen immediately - no artificial delay needed
      ResponsiveNavigation.toPlaceOrderScreen(
        context: context,
        arguments: {
          "orderArg": orderArgs,
          "scripInfo": scripInfo,
          "isBskt": isBasketMode
        },
      );

      // BACKGROUND: Fetch linkedScrips for exchange switch button (non-blocking)
      // This updates the exchange list after order screen is already open
      ref.read(marketWatchProvider).fetchLinkeScrip(currentToken, currentExch, context);
    } catch (e) {
      // Show error to user
      if (mounted) {
        ResponsiveSnackBar.showError(
            context, 'Error placing order: ${e.toString()}');
      }
    } finally {
      // Reset navigation state after a delay
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

class _PriceDataWidgetWeb extends ConsumerStatefulWidget {
  final String token;
  final Map<String, dynamic> initialData;

  const _PriceDataWidgetWeb({
    required this.token,
    required this.initialData,
  });

  @override
  ConsumerState<_PriceDataWidgetWeb> createState() =>
      _PriceDataWidgetWebState();
}

class _PriceDataWidgetWebState extends ConsumerState<_PriceDataWidgetWeb> {
  // PERFORMANCE FIX: No more stream subscriptions or cached values!
  // Using Riverpod's reactive system - data is fetched fresh in build()

  // Helper method to safely format price values
  String _safeFormatPrice(String value) {
    if (value == 'null' ||
        value.isEmpty ||
        value == '0.0' ||
        value == 'NaN' ||
        value == 'Infinity') {
      return '0.00';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE FIX: Watch ONLY this token's data using Riverpod's selective watching
    // This prevents unnecessary rebuilds when other tokens update
    final socketData = ref.watch(websocketProvider
        .select((provider) => provider.socketDatas[widget.token]));

    // Calculate values fresh from socket data or fall back to initial data
    final ltp = socketData?['lp']?.toString() ??
        widget.initialData['ltp']?.toString() ??
        '0.00';
    final change = socketData?['chng']?.toString() ??
        widget.initialData['change']?.toString() ??
        '0.00';
    final perChange = socketData?['pc']?.toString() ??
        widget.initialData['perChange']?.toString() ??
        '0.00';

    // Don't read theme on every rebuild - cache it once per build
    final theme = ref.read(themeProvider);

    // Format price values and handle invalid data
    final displayLtp = _safeFormatPrice(ltp);
    final displayChange = _safeFormatPrice(change);
    final displayPerChange = _safeFormatPrice(perChange);

    final changeColor =
        displayChange.startsWith("-") || displayPerChange.startsWith('-')
            ? theme.isDarkMode
                ? MyntColors.loss
                : MyntColors.loss
            : (displayChange == "0.00" || displayPerChange == "0.00")
                ? theme.isDarkMode
                    ? MyntColors.textSecondary
                    : MyntColors.textSecondary
                : theme.isDarkMode
                    ? MyntColors.profit
                    : MyntColors.profit;

    // Build the UI with web-optimized text styles
    return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            displayLtp,
            style: WebTextStyles.priceWatch(
              isDarkTheme: theme.isDarkMode,
              color: theme.isDarkMode
                  ? MyntColors.textPrimary
                  : MyntColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8), // Adjusted spacing to match Vue project
          Text(
            "$displayChange ($displayPerChange%)",
            style: WebTextStyles.pricePercent(
              isDarkTheme: theme.isDarkMode,
              color: changeColor,
            ),
          ),
        ]);
  }
}

// Widget for LTP only (used in first row)
class _LTPWidgetWeb extends ConsumerStatefulWidget {
  final String token;
  final Map<String, dynamic> initialData;

  const _LTPWidgetWeb({
    required this.token,
    required this.initialData,
  });

  @override
  ConsumerState<_LTPWidgetWeb> createState() => _LTPWidgetWebState();
}

class _LTPWidgetWebState extends ConsumerState<_LTPWidgetWeb> {
  // PERFORMANCE FIX: No more stream subscriptions or cached values!
  // Using Riverpod's reactive system - data is fetched fresh in build()

  String _safeFormatPrice(String value) {
    if (value == 'null' ||
        value.isEmpty ||
        value == '0.0' ||
        value == 'NaN' ||
        value == 'Infinity') {
      return '0.00';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE FIX: Watch ONLY this token's data using Riverpod's selective watching
    final socketData = ref.watch(websocketProvider
        .select((provider) => provider.socketDatas[widget.token]));

    // Calculate values fresh from socket data or fall back to initial data
    final ltp = socketData?['lp']?.toString() ??
        widget.initialData['ltp']?.toString() ??
        '0.00';
    final change = socketData?['chng']?.toString() ??
        widget.initialData['change']?.toString() ??
        '0.00';
    final perChange = socketData?['pc']?.toString() ??
        widget.initialData['perChange']?.toString() ??
        '0.00';

    final displayLtp = _safeFormatPrice(ltp);
    final displayChange = _safeFormatPrice(change);
    final displayPerChange = _safeFormatPrice(perChange);

    final changeColor =
        displayChange.startsWith("-") || displayPerChange.startsWith('-')
            ? resolveThemeColor(
                context,
                dark: MyntColors.lossDark,
                light: MyntColors.loss,
              )
            : (displayChange == "0.00" || displayPerChange == "0.00")
                ? resolveThemeColor(
                    context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary,
                  )
                : resolveThemeColor(
                    context,
                    dark: MyntColors.profitDark,
                    light: MyntColors.profit,
                  );

    return Text(
      displayLtp,
      style: MyntWebTextStyles.price(
        context,
        color: changeColor,
      ),
    );
  }
}

// Widget for Price Change only (used in second row)
class _PriceChangeWidgetWeb extends ConsumerStatefulWidget {
  final String token;
  final Map<String, dynamic> initialData;

  const _PriceChangeWidgetWeb({
    required this.token,
    required this.initialData,
  });

  @override
  ConsumerState<_PriceChangeWidgetWeb> createState() =>
      _PriceChangeWidgetWebState();
}

class _PriceChangeWidgetWebState extends ConsumerState<_PriceChangeWidgetWeb> {
  // PERFORMANCE FIX: No more stream subscriptions or cached values!
  // Using Riverpod's reactive system - data is fetched fresh in build()

  String _safeFormatPrice(String value) {
    if (value == 'null' ||
        value.isEmpty ||
        value == '0.0' ||
        value == 'NaN' ||
        value == 'Infinity') {
      return '0.00';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE FIX: Watch ONLY this token's data using Riverpod's selective watching
    final socketData = ref.watch(websocketProvider
        .select((provider) => provider.socketDatas[widget.token]));

    // Calculate values fresh from socket data or fall back to initial data
    final change = socketData?['chng']?.toString() ??
        widget.initialData['change']?.toString() ??
        '0.00';
    final perChange = socketData?['pc']?.toString() ??
        widget.initialData['perChange']?.toString() ??
        '0.00';

    final displayChange = _safeFormatPrice(change);
    final displayPerChange = _safeFormatPrice(perChange);

    // final changeColor =
    //     displayChange.startsWith("-") || displayPerChange.startsWith('-')
    //         ? resolveThemeColor(context,
    //             dark: MyntColors.lossDark, light: MyntColors.loss)
    //         : (displayChange == "0.00" || displayPerChange == "0.00")
    //             ? resolveThemeColor(context,
    //                 dark: MyntColors.textSecondaryDark,
    //                 light: MyntColors.textSecondary)
    //             : resolveThemeColor(context,
    //                 dark: MyntColors.profitDark, light: MyntColors.profit);

    return Text(
      "$displayChange ($displayPerChange%)",
      style: MyntWebTextStyles.priceChange(
        context,
        color: resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary),
      ),
    );
  }
}
