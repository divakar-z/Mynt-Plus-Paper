import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../provider/order_provider.dart';
import '../../../models/order_book_model/order_book_model.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../provider/thems.dart';
import '../../../res/res.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/responsive.dart';
import '../../../locator/preference.dart';
import '../../../sharedWidget/no_data_found.dart';
import '../../../sharedWidget/snack_bar.dart';
import '../../../sharedWidget/common_search_fields_web.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../utils/responsive_navigation.dart';
import 'tv_chart/chart_iframe_guard.dart';

class SearchDialogWeb extends ConsumerStatefulWidget {
  final String wlName;
  final String isBasket;

  const SearchDialogWeb({
    super.key,
    required this.wlName,
    required this.isBasket,
  });

  @override
  ConsumerState<SearchDialogWeb> createState() => _SearchDialogWebState();
}

class _SearchDialogWebState extends ConsumerState<SearchDialogWeb>
    with TickerProviderStateMixin {
  late TabController _tabController;
  VoidCallback?
      _tabControllerListener; // Store listener reference for proper cleanup
  String _searchValue = "";
  int _tabCount = 5;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _tabScrollController = ScrollController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  Preferences pref = Preferences();

  // Debounce timer for search to prevent excessive API calls on rapid typing
  Timer? _searchDebounceTimer;
  static const _searchDebounceDuration = Duration(milliseconds: 300);
  late bool scripisAscending;
  late bool pricepisAscending;
  late bool perchangisAscending;

  // Hover state tracking for each list item
  final Map<int, bool> _hoveredItems = {};

  // Dragging state - COMMENTED OUT (draggable functionality disabled)
  // Offset? _position;
  // bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Clear previous search results when dialog opens.
    // Defer to avoid "Tried to modify a provider while the widget tree was building".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(marketWatchProvider).searchClear();
    });

    // Disable chart iframe pointer events when dialog opens
    _disableAllChartIframes();

    _tabCount = widget.isBasket == "Basket" ? 5 : 6;
    _tabController =
        TabController(length: _tabCount, vsync: this, initialIndex: 0);

    setState(() {
      scripisAscending = pref.isMWScripname ?? true;
      pricepisAscending = pref.isMWPrice ?? true;
      perchangisAscending = pref.isMWPerchang ?? true;
    });

    // Store listener reference for proper cleanup
    _tabControllerListener = () {
      if (_tabController.indexIsChanging) {
        ref.read(marketWatchProvider).searchClear();
        ref.read(marketWatchProvider).scripSearch(
            _searchValue, context, _tabController.index, widget.isBasket);
        _scrollToSelectedTab(_tabController.index);
      }
    };
    _tabController.addListener(_tabControllerListener!);

    // Add text controller listener to handle clear button and other text changes
    // Using debounce to prevent excessive API calls on rapid typing
    _textController.addListener(() {
      final currentText = _textController.text;
      if (currentText != _searchValue) {
        setState(() {
          _searchValue = currentText;
        });

        // Cancel previous debounce timer
        _searchDebounceTimer?.cancel();

        final searchScrip = ref.read(marketWatchProvider);
        if (currentText.isEmpty) {
          // Clear immediately without debounce
          searchScrip.searchClear();
        } else {
          // Debounce search API calls
          _searchDebounceTimer = Timer(_searchDebounceDuration, () {
            if (mounted && _searchValue == currentText) {
              searchScrip.scripSearch(
                  currentText, context, _tabController.index, widget.isBasket);
            }
          });
        }
      }
    });

    // Acquire chart iframe guard on init to prevent cursor bleed
    ChartIframeGuard.acquire();
    _disableAllChartIframes();

    // Request focus after dialog animation completes (web autofocus fix)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    });
  }

  // Directly disable all chart iframes and reset cursor (like chart's onExit)
  void _disableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
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
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'auto';
          iframe.style.cursor = '';
        }
      }
      html.document.body?.style.cursor = '';
    } catch (e) {
    }
  }

  @override
  void dispose() {
    // Cancel search debounce timer
    _searchDebounceTimer?.cancel();
    _tabScrollController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    // Remove listener before disposing to prevent memory leaks
    if (_tabControllerListener != null) {
      _tabController.removeListener(_tabControllerListener!);
      _tabControllerListener = null;
    }
    _tabController.dispose();
    _textController.dispose();
    // Re-enable chart iframe pointer events when dialog closes
    ChartIframeGuard.release();
    _enableAllChartIframes();
    super.dispose();
  }

  // Disable all chart iframes to allow dialog interaction
  // void _disableAllChartIframes() {
  //   try {
  //     final iframes = html.document.querySelectorAll('iframe');
  //     for (var iframe in iframes) {
  //       if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
  //         iframe.style.pointerEvents = 'none';
  //         iframe.style.cursor = 'default';
  //       }
  //     }
  //     html.document.body?.style.cursor = 'default';
  //   } catch (e) {
  //     debugPrint('Error disabling iframes: $e');
  //   }
  // }

  // // Re-enable all chart iframes
  // void _enableAllChartIframes() {
  //   try {
  //     final iframes = html.document.querySelectorAll('iframe');
  //     for (var iframe in iframes) {
  //       if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
  //         iframe.style.pointerEvents = 'auto';
  //         iframe.style.cursor = '';
  //       }
  //     }
  //     html.document.body?.style.cursor = '';
  //   } catch (e) {
  //     debugPrint('Error enabling iframes: $e');
  //   }
  // }

  void _scrollToSelectedTab(int index) {
    if (!_tabScrollController.hasClients) return;

    // Simplified scroll calculation for dynamic-width tabs
    // Each tab has padding (16*2) + text width + spacing (6*2) = approximately 50-150px depending on text
    // We'll use an average width estimate
    const double estimatedTabWidth =
        120.0; // Average width for tabs with padding
    final double viewportWidth =
        _tabScrollController.position.viewportDimension;
    final double targetOffset = (index * estimatedTabWidth) -
        (viewportWidth / 2) +
        (estimatedTabWidth / 2);
    final double scrollTo =
        targetOffset.clamp(0.0, _tabScrollController.position.maxScrollExtent);

    _tabScrollController.animateTo(
      scrollTo,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeProvider);
    final searchScrip = ref.watch(marketWatchProvider);

    // Set initial position to center if not set
    // if (_position == null) {
    //   final screenSize = MediaQuery.of(context).size;
    //   const dialogWidth = 800.0;
    //   const dialogHeight = 600.0;
    //   _position = Offset(
    //     (screenSize.width - dialogWidth) / 2,
    //     (screenSize.height - dialogHeight) / 2,
    //   );
    // }

    return Center(
      child: PointerInterceptor(
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
            child: GestureDetector(
              onTap: () {}, // Prevent tap from propagating to background
              child: shadcn.Card(
                borderRadius: BorderRadius.circular(8),
                padding: EdgeInsets.zero,
                child: Container(
                  width: context.responsive(
                    mobile: context.screenWidth * 0.95,
                    tablet: 500.0,
                    desktop: 560.0,
                  ),
                  constraints: BoxConstraints(
                    maxHeight: context.screenHeight * 0.75,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar Section
                      Container(
                        padding: const EdgeInsets.only(
                            left: 16, right: 8, top: 16, bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: MyntSearchTextField.withSmartClear(
                                controller: _textController,
                                focusNode: _searchFocusNode,
                                placeholder: 'Search stocks, indices, options',
                                leadingIcon: assets.searchIcon,
                                leadingIconHoverEffect: true,
                                autofocus: true,
                                inputFormatters: [
                                  UpperCaseTextFormatter(),
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z0-9& \-]')),
                                  TextInputFormatter.withFunction((oldValue, newValue) {
                                    if (newValue.text.startsWith(' ')) return oldValue;
                                    return newValue;
                                  }),
                                ],
                                // Note: Search is handled by _textController.addListener with debounce
                                // No onChanged here to avoid duplicate API calls
                              ),
                            ),
                            SizedBox(width: 10),
                            // Close dialog icon (always visible, outside search bar)

                            MyntCloseButton(
                              onPressed: () {
                                ref.read(marketWatchProvider).searchClear();
                                Navigator.of(context).pop();
                              },
                            )
                          ],
                        ),
                      ),
                      // Close dialog icon (always visible, outside search bar)

                      // const SizedBox(height: 10),
                      // Always show tabs and content area
                      _buildSearchTabs(ref, theme),

                      // Search Results or No Data
                      Expanded(
                        child: _buildSearchResults(searchScrip, theme),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTabs(WidgetRef ref, ThemesProvider theme) {
    final searchTabList =
        ref.read(marketWatchProvider).searchTabList.sublist(0, _tabCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: SingleChildScrollView(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Builder(
          builder: (context) {
            final currentTheme = shadcn.Theme.of(context);
            final isDark = isDarkMode(context);
            // Create a new ColorScheme based on the default, but with custom primary color
            final baseColorScheme = isDark
                ? shadcn.ColorSchemes.darkDefaultColor
                : shadcn.ColorSchemes.lightDefaultColor;

            // Create custom ColorScheme with theme-appropriate primary color
            final primaryColor = resolveThemeColor(
              context,
              dark: WebColors.primaryDark,
              light: WebColors.primary,
            );
            final customColorScheme = baseColorScheme.copyWith(
              primary: () => primaryColor,
            );

            return shadcn.Theme(
              data: shadcn.ThemeData(
                colorScheme: customColorScheme,
                radius: currentTheme.radius,
              ),
              child: shadcn.TabList(
                index: _tabController.index,
                onChanged: (value) {
                  if (_tabController.index != value) {
                    _tabController.animateTo(value);
                    _scrollToSelectedTab(value);
                  }
                },
                children: [
                  for (int index = 0; index < searchTabList.length; index++)
                    shadcn.TabItem(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        hitTestBehavior: HitTestBehavior.opaque,
                        child: Builder(
                          builder: (context) {
                            final isActive = index == _tabController.index;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Text(
                                searchTabList[index].text ?? '',
                                style: MyntWebTextStyles.body(
                                  context,
                                  // fontSize: WebFonts.subSize,
                                  fontWeight: isActive
                                      ? MyntFonts.bold
                                      : MyntFonts.medium,
                                  color: isActive
                                      ? resolveThemeColor(
                                          context,
                                          dark: WebColors.primaryDark,
                                          light: WebColors.primary,
                                        )
                                      : resolveThemeColor(
                                          context,
                                          dark: WebColors.textSecondaryDark,
                                          light: WebColors.textSecondary,
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchResults(
      MarketWatchProvider searchScrip, ThemesProvider theme) {
    if (searchScrip.allSearchScrip?.isEmpty ?? true) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: NoDataFoundWeb(
            
            title: _searchValue.length < 3
                ? "Start Searching"
                : "No Results Found",
            subtitle: _searchValue.isEmpty
                ? "Type to search for stocks, indices, or options."
                : _searchValue.length < 3
                    ? "Type at least 3 characters to see results"
                    : "No stocks match your search \"$_searchValue\".",
           
            secondaryEnabled: false,
          ),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
      child: RawScrollbar(
        controller: _scrollController,
        thumbVisibility: false,
        thickness: 6,
        radius: const Radius.circular(0),
        thumbColor: resolveThemeColor(
          context,
          dark: WebColors.scrollbarThumbDark,
          light: WebColors.scrollbarThumbLight,
        ),
        child: ListView.separated(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          itemCount: searchScrip.allSearchScrip!.length,
          separatorBuilder: (context, index) => Divider(
            height: 0,
            color: shadcn.Theme.of(context).colorScheme.border,
          ),
          itemBuilder: (BuildContext context, int index) {
            final scrip = searchScrip.allSearchScrip![index];

            return MouseRegion(
              onEnter: (_) => setState(() => _hoveredItems[index] = true),
              onExit: (_) => setState(() => _hoveredItems[index] = false),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
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
                  onTap: () async {
                    if (widget.isBasket == "Chart||Is") {
                      // Create DepthInputArgs from selected scrip to update header and scrip info
                      final depthArgs = DepthInputArgs(
                        exch: scrip.exch.toString(),
                        token: scrip.token.toString(),
                        tsym: scrip.tsym.toString(),
                        instname: scrip.instname ?? "",
                        symbol: scrip.symbol ?? scrip.tsym.toString(),
                        expDate: scrip.expDate ?? "",
                        option: scrip.option ?? "",
                        idx: scrip.idx,
                      );

                      // Update depth/scrip info panel and header
                      await searchScrip.calldepthApis(context, depthArgs, "");

                      // Update chart
                      searchScrip.setChartScript(
                        scrip.exch.toString(),
                        scrip.token.toString(),
                        scrip.tsym.toString(),
                      );

                      await searchScrip.searchClear();
                      Navigator.of(context).pop();
                    } else if (widget.isBasket == "Option||Is") {
                      // Create DepthInputArgs from selected scrip with isOption = true
                      final depthArgs = DepthInputArgs(
                        exch: scrip.exch.toString(),
                        token: scrip.token.toString(),
                        tsym: scrip.tsym.toString(),
                        instname: scrip.instname ?? "",
                        symbol: scrip.symbol ?? scrip.tsym.toString(),
                        expDate: scrip.expDate ?? "",
                        option: scrip.option ?? "",
                        isOption: true,
                        idx: scrip.idx,
                      );

                      // Update depth/scrip info panel and header
                      await searchScrip.calldepthApis(
                          context, depthArgs, "Option||Is");

                      searchScrip.setOptionScript(
                        context,
                        scrip.exch.toString(),
                        scrip.token.toString(),
                        scrip.tsym.toString(),
                      );
                      await searchScrip.searchClear();
                      Navigator.of(context).pop();
                    } else {
                      await searchScrip.calldepthApis(
                        context,
                        scrip,
                        widget.isBasket,
                      );
                      await searchScrip.searchClear();
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    color: (_hoveredItems[index] ?? false)
                        ? resolveThemeColor(
                            context,
                            dark: WebColors.primaryDark,
                            light: WebColors.primary,
                          ).withValues(alpha: 0.08)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        // Scrip Info
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Symbol name and option
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    (scrip.masterName?.isNotEmpty == true)
                                        ? scrip.masterName!
                                        : "${scrip.symbol?.isNotEmpty == true ? scrip.symbol : scrip.tsym}"
                                            .replaceAll("-EQ", "")
                                            .toUpperCase(),
                                    style: MyntWebTextStyles.symbol(
                                      context,
                                      color: resolveThemeColor(
                                        context,
                                        dark: WebColors.textPrimaryDark,
                                        light: WebColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (scrip.masterName == null &&
                                      scrip.option != null &&
                                      scrip.option.toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        "${scrip.option}",
                                        style: MyntWebTextStyles.symbol(
                                          context,
                                          color: resolveThemeColor(
                                            context,
                                            dark: WebColors.textPrimaryDark,
                                            light: WebColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (scrip.masterName == null &&
                                      scrip.expDate != null &&
                                      scrip.expDate.toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        " ${scrip.expDate}",
                                        style: MyntWebTextStyles.symbol(
                                          context,
                                          color: resolveThemeColor(
                                            context,
                                            dark: WebColors.textPrimaryDark,
                                            light: WebColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      '${scrip.exch}',
                                      style: MyntWebTextStyles.exch(
                                        context,
                                        color: resolveThemeColor(
                                          context,
                                          dark: WebColors.textSecondaryDark,
                                          light: WebColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Buy/Sell buttons for Basket mode - shown next to symbol
                                  if (widget.isBasket == "Basket") ...[
                                    const SizedBox(width: 8),
                                    IgnorePointer(
                                      ignoring:
                                          !(_hoveredItems[index] ?? false),
                                      child: AnimatedOpacity(
                                        opacity: (_hoveredItems[index] ?? false)
                                            ? 1.0
                                            : 0.0,
                                        duration:
                                            const Duration(milliseconds: 150),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Buy Button
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                onTap: () async {
                                                  await _handleBuySellClick(
                                                      context,
                                                      scrip,
                                                      true,
                                                      ref,
                                                      theme);
                                                },
                                                child: Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        shadcn.Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'B',
                                                      style: MyntWebTextStyles
                                                          .caption(
                                                        context,
                                                        color: shadcn.Theme.of(
                                                                context)
                                                            .colorScheme
                                                            .primaryForeground,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Sell Button
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                onTap: () async {
                                                  await _handleBuySellClick(
                                                      context,
                                                      scrip,
                                                      false,
                                                      ref,
                                                      theme);
                                                },
                                                child: Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        shadcn.Theme.of(context)
                                                            .colorScheme
                                                            .destructive,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'S',
                                                      style: MyntWebTextStyles
                                                          .caption(
                                                        context,
                                                        color: shadcn.Theme.of(
                                                                context)
                                                            .colorScheme
                                                            .destructiveForeground,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              // const SizedBox(height: 8),
                              // Exchange and additional info
                              // Row(
                              //   mainAxisAlignment: MainAxisAlignment.start,
                              //   children: [

                              // if (scrip.cname != null && scrip.cname.toString().isNotEmpty)
                              //   Padding(
                              //     padding: const EdgeInsets.only(left: 8),
                              //     child: Text(
                              //       "${scrip.cname}",
                              //       style: MyntWebTextStyles.caption(
                              //         isDarkTheme: theme.isDarkMode,
                              //         color: theme.isDarkMode
                              //             ? WebDarkColors.textSecondary
                              //             : WebColors.textSecondary,
                              //       ),
                              //       overflow: TextOverflow.ellipsis,
                              //     ),
                              //   ),
                              // ],
                              // ),
                            ],
                          ),
                        ),

                        // Save/Bookmark Icon for Watchlist mode
                        if (widget.isBasket != "Basket" &&
                            widget.isBasket != "Chart||Is" &&
                            widget.isBasket != "Option||Is" &&
                            searchScrip.isPreDefWLs != "Yes" &&
                            searchScrip.scrips.length < 50)
                          Builder(
                            builder: (context) {
                              // Use exarr from marketWatchProvider (already available during search)
                              // This avoids waiting for userProfileProvider.userDetailModel API call
                              // Note: searchScrip.exarr contains quoted strings like '"NSE"'
                              final isSegmentActive = searchScrip.exarr.contains('"${scrip.exch}"');

                              return Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  splashColor: Colors.grey.withOpacity(0.2),
                                  highlightColor: Colors.grey.withOpacity(0.1),
                                  onTap: () async {
                                    if (!isSegmentActive) {
                                      showResponsiveErrorMessage(
                                          context, "Segment is not active.");
                                    } else {
                                      if (searchScrip.isAdded![index]) {
                                        await searchScrip.isActiveAddBtn(
                                            false, index);
                                        await searchScrip.addDelMarketScrip(
                                          widget.wlName,
                                          "${scrip.exch}|${scrip.token}",
                                          context,
                                          false,
                                          false,
                                          false,
                                          false,
                                        );
                                      } else {
                                        await searchScrip.isActiveAddBtn(
                                            true, index);
                                        await searchScrip.addDelMarketScrip(
                                          widget.wlName,
                                          "${scrip.exch}|${scrip.token}",
                                          context,
                                          true,
                                          false,
                                          false,
                                          false,
                                        );

                                        try {
                                          final currentSort = ref
                                              .read(marketWatchProvider)
                                              .sortByWL;

                                          if (currentSort.isNotEmpty) {
                                            await ref
                                                .read(marketWatchProvider)
                                                .filterMWScrip(
                                                  sorting: currentSort,
                                                  wlName: widget.wlName,
                                                  context: context,
                                                );
                                          }

                                          scripisAscending = !scripisAscending;
                                          pref.setMWScrip(scripisAscending);

                                          pricepisAscending = !pricepisAscending;
                                          pref.setMWPrice(pricepisAscending);

                                          perchangisAscending =
                                              !perchangisAscending;
                                          pref.setMWPerchnage(perchangisAscending);
                                        } catch (e) {
                                        }
                                      }
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(7),
                                    child: !isSegmentActive
                                        ? SvgPicture.asset(
                                            assets.dInfo,
                                            color: Colors.red,
                                            height: 18,
                                            width: 18,
                                          )
                                        : SvgPicture.asset(
                                            searchScrip.isAdded![index]
                                                ? assets.bookmarkIcon
                                                : assets.bookmarkedIcon,
                                            color: searchScrip.isAdded![index]
                                                ? resolveThemeColor(
                                                    context,
                                                    dark: WebColors.primaryDark,
                                                    light: WebColors.primary,
                                                  )
                                                : resolveThemeColor(
                                                    context,
                                                    dark: WebColors.iconDark,
                                                    light: WebColors.icon,
                                                  ),
                                            height: 18,
                                            width: 18,
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Handle Buy/Sell click for basket mode
  Future<void> _handleBuySellClick(
    BuildContext context,
    dynamic scrip,
    bool isBuy,
    WidgetRef ref,
    ThemesProvider theme,
  ) async {
    try {
      final marketWatch = ref.read(marketWatchProvider);
      final orderProv = ref.read(orderProvider);

      // Check basket limit
      if (orderProv.bsktScripList.length >=
          orderProv.frezQtyOrderSliceMaxLimit) {
        showResponsiveErrorMessage(
          context,
          "Basket limit reached. Please create a new basket as you are exceeding the ${orderProv.frezQtyOrderSliceMaxLimit} item limit.",
        );
        return;
      }

      // Check if segment is active
      if (!marketWatch.exarr.contains('"${scrip.exch}"')) {
        showResponsiveErrorMessage(context, "Segment is not active.");
        return;
      }

      // Get root navigator context before closing dialog
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final rootContext = rootNavigator.context;

      // Create DepthInputArgs exactly like in normal selection flow
      final depthArgs = DepthInputArgs(
        exch: scrip.exch.toString(),
        token: scrip.token.toString(),
        tsym: scrip.tsym.toString(),
        instname: scrip.instname ?? "",
        symbol: scrip.symbol ?? scrip.tsym.toString(),
        expDate: scrip.expDate ?? "",
        option: scrip.option ?? "",
        idx: scrip.idx,
      );

      // Use calldepthApis to fetch data and update background views (Chart/Depth)
      // This ensures background stays in sync with what user is buying/selling
      await marketWatch.calldepthApis(context, depthArgs, "Basket");

      if (!context.mounted) return;

      // Get LTP and percentage change from depth data (getQuotes)
      final depthData = marketWatch.getQuotes;
      final ltp =
          depthData?.lp?.toString() ?? depthData?.c?.toString() ?? "0.00";
      final perChange = depthData?.pc?.toString() ?? "0.00";

      // Create OrderScreenArgs
      // Note: ScripNewValue doesn't have prd, lp, pc properties - we get those from fetched data
      OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: scrip.exch.toString(),
        tSym: scrip.tsym.toString(),
        isExit: false,
        token: scrip.token.toString(),
        transType: isBuy,
        lotSize: marketWatch.scripInfoModel?.ls?.toString() ?? "1",
        ltp: ltp,
        perChange: perChange,
        orderTpye: '',
        holdQty: '',
        isModify: false,
        prd:
            null, // prd is not available in search scrip model, will be set in order screen
        raw: {
          'exch': scrip.exch.toString(),
          'token': scrip.token.toString(),
          'tsym': scrip.tsym.toString(),
          'symbol': scrip.symbol?.toString() ?? scrip.tsym.toString(),
          'expDate': scrip.expDate?.toString() ?? '',
          'option': scrip.option?.toString() ?? '',
        },
      );

      // Close search dialog
      Navigator.of(context).pop();

      // Wait a bit to ensure dialog is closed
      await Future.delayed(const Duration(milliseconds: 150));

      // Navigate to order screen with basket context using root context
      await ResponsiveNavigation.toPlaceOrderScreen(
        context: rootContext,
        arguments: {
          "orderArg": orderArgs,
          "scripInfo": marketWatch.scripInfoModel!,
          "isBskt": "Basket",
        },
      );
    } catch (e, stackTrace) {
      if (context.mounted) {
        showResponsiveErrorMessage(
            context, "Failed to open order screen: ${e.toString()}");
      }
    }
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
