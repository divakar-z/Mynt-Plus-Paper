import 'dart:async';
import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'dart:html' as html;
import 'tv_chart/chart_iframe_guard.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/thems.dart';
import '../../../res/res.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/responsive.dart';
import '../../../sharedWidget/list_divider.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../sharedWidget/common_text_fields_web.dart';
import '../../../sharedWidget/common_search_fields_web.dart';
import 'my_stocks/stocks_screen_web.dart';
import 'my_positions/positions_screen_web.dart';
import 'watchlist_card_web.dart';
import 'search_dialog_web.dart';
import 'edit_scrip_web.dart';
import '../../../utils/responsive_snackbar.dart';
import '../../../provider/websocket_provider.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import 'index/index_bottom_sheet_web.dart';
import 'option_chain_panel_web.dart';
import '../../../provider/watchlist_oc_provider.dart';
import '../chart_engine/state/chart_engine_store.dart';
import '../chart_engine/state/active_pane_symbol_request.dart';

// Provider to manage delete mode state
final deleteModeProvider =
    StateNotifierProvider<DeleteModeNotifier, bool>((ref) {
  return DeleteModeNotifier();
});

class DeleteModeNotifier extends StateNotifier<bool> {
  DeleteModeNotifier() : super(false);

  void setDeleteMode(bool isActive) {
    state = isActive;
  }
}

class MockMarketWatchlist {
  final List<String> values;
  MockMarketWatchlist({required this.values});
}

class WatchListScreenWeb extends StatefulWidget {
  const WatchListScreenWeb({super.key});

  @override
  State<WatchListScreenWeb> createState() => _WatchListScreenWebState();
}

class _WatchListScreenWebState extends State<WatchListScreenWeb>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _tabScrollController = ScrollController();
  late final SwipeActionController _swipeController;
  late final PageController _pageController;

  final TextEditingController _searchController = TextEditingController();
  final List<String> _lastTabNames = [];

  /// Get responsive tab width based on watchlist panel width
  /// Uses centralized ResponsiveSizes utility
  double _getResponsiveTabWidth(BuildContext context) {
    return ResponsiveSizes.tabWidth(context);
  }

  Timer? _scrollDebounce;
  String _lastWatchlistName = '';
  int _currentPageIndex = 0;
  bool _isUserScrolling = false;
  bool _isDisposed = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _wasOCExpanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Wrap in try-catch since Firebase may not be initialized yet (async init after runApp)
    try {
      FirebaseAnalytics.instance.logScreenView(
        screenName: 'Watchlist screen web',
        screenClass: 'WatchList_screen_web',
      );
    } catch (e) {
    }

    _swipeController = SwipeActionController(
      selectedIndexPathsChangeCallback: (changed, selected, currentCount) =>
          _safeSetState(() {}),
    );

    _tabScrollController.addListener(_handleTabScroll);
  }

  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      // Initialize PageController with stored page index from provider
      final marketWatch =
          ProviderScope.containerOf(context).read(marketWatchProvider);
      _pageController =
          PageController(initialPage: marketWatch.currentWatchlistPageIndex);
      _currentPageIndex = marketWatch.currentWatchlistPageIndex;

      _isInitialized = true;

      // Initialize immediately with stored data
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) {
          _initializeWithStoredData();
        }
      });

      // Load additional data in background
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensurePredefinedWatchlistsLoaded();
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollDebounce?.cancel();
    _tabScrollController.dispose();
    _pageController.dispose();
    _swipeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Initialize immediately with existing data - no loader needed
  void _initializeWithStoredData() {
    if (_isDisposed || !mounted) return;

    // Set tab scroll position to the stored page index
    _scrollToSelectedTab(_currentPageIndex, force: true);

    // Note: _ensurePredefinedWatchlistsLoaded() is already called from didChangeDependencies
    // No need to call it again here to avoid duplicate API calls

    _safeSetState(() {});
  }

  void _handleTabScroll() {
    if (_isDisposed || !_tabScrollController.hasClients) return;

    if (_tabScrollController.position.isScrollingNotifier.value) {
      _isUserScrolling = true;
    } else {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!_isDisposed) _isUserScrolling = false;
      });
    }

    final canScrollLeft = _tabScrollController.offset > 1.0;
    final canScrollRight = _tabScrollController.offset <
        (_tabScrollController.position.maxScrollExtent - 1.0);

    if (canScrollLeft != _canScrollLeft || canScrollRight != _canScrollRight) {
      _safeSetState(() {
        _canScrollLeft = canScrollLeft;
        _canScrollRight = canScrollRight;
      });
    }

    if (!_tabScrollController.position.isScrollingNotifier.value) {
      _safeSetState(() {});
    }
  }

  void _scrollTabs({required bool left}) {
    if (!_tabScrollController.hasClients || _isDisposed) return;

    final scrollAmount = _tabScrollController.position.viewportDimension * 0.8;
    final target = left
        ? (_tabScrollController.offset - scrollAmount)
            .clamp(0.0, _tabScrollController.position.maxScrollExtent)
        : (_tabScrollController.offset + scrollAmount)
            .clamp(0.0, _tabScrollController.position.maxScrollExtent);

    _tabScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToSelectedTab(int index, {bool force = false}) {
    if (!_tabScrollController.hasClients || _isDisposed) return;
    if (!force && _isUserScrolling) return;

    final viewW = _tabScrollController.position.viewportDimension;
    final max = _tabScrollController.position.maxScrollExtent;
    final tabWidth = _getResponsiveTabWidth(context);

    final target = (index * tabWidth) - (viewW / 2) + (tabWidth / 2);
    final offset = target.clamp(0.0, max);

    if ((_tabScrollController.offset - offset).abs() < 1.0) return;

    _tabScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToWatchlistTab(WidgetRef ref, String wlName) {
    final list =
        ref.read(marketWatchProvider.select((p) => p.marketWatchlist))?.values;
    if (list == null) return;

    final idx = list.indexOf(wlName);
    if (idx == -1) return;

    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 50), () {
      if (!_isDisposed) _scrollToSelectedTab(idx, force: true);
    });
  }

  /// Background loading - doesn't block UI
  Future<void> _ensurePredefinedWatchlistsLoaded() async {
    if (_isDisposed || !mounted) return;

    try {
      final marketWatch =
          ProviderScope.containerOf(context).read(marketWatchProvider);
      final current = marketWatch.wlName;

      // Only fetch if predefined data not already loaded
      if (marketWatch.preDefinedMWlist == null) {
        await marketWatch.fetchPreDefMWScrip(context);
        if (!mounted) return;
      }

      const predefined = ['Nifty50', 'Niftybank', 'Sensex', 'My Stocks'];

      if (predefined.contains(current) && marketWatch.scrips.isEmpty) {
        await marketWatch.fetchMWScrip(current, context);
        if (!mounted) return;
        await marketWatch.changeWLScrip(current, context);
        if (!mounted) return;
      }

      for (final name in predefined) {
        if (!mounted) return;
        if (name == current) continue;
        final cached = marketWatch.marketWatchScripData[name];
        if (cached == null || jsonDecode(cached).isEmpty) {
          await marketWatch.fetchMWScrip(name, context);
          if (!mounted) return;
        }
      }

      if (!mounted) return;
      await marketWatch.requestMWScrip(context: context, isSubscribe: true);
    } catch (e) {
    }
  }

  Future<void> _handlePageChanged(int pageIndex, WidgetRef ref) async {
    if (_isDisposed || !mounted) return;

    final marketWatch = ref.read(marketWatchProvider);
    final watchList = marketWatch.marketWatchlist;

    if (watchList?.values == null || pageIndex >= watchList!.values!.length) {
      return;
    }

    final newWatchlistName = watchList.values![pageIndex];

    _currentPageIndex = pageIndex;

    // Save the current page index to provider for persistence
    marketWatch.setCurrentWatchlistPageIndex(pageIndex);

    _scrollToSelectedTab(pageIndex, force: true);

    try {
      await marketWatch.requestMWScrip(context: context, isSubscribe: false);
      if (!mounted) return;

      final predefined = marketWatch.preDefWL;
      final isPredefined = predefined.contains(newWatchlistName);

      await marketWatch.changeWlName(
          newWatchlistName, isPredefined ? 'Yes' : 'No');
      if (!mounted) return;
      await marketWatch.changeWLScrip(newWatchlistName, context);
      if (!mounted) return;

      await marketWatch.requestMWScrip(context: context, isSubscribe: true);
    } catch (e) {
    }
  }

  Future<void> _handleTabTap(String name, int index, WidgetRef ref) async {
    if (_currentPageIndex == index) return;

    _currentPageIndex = index;

    // Save the current page index to provider for persistence
    ref.read(marketWatchProvider).setCurrentWatchlistPageIndex(index);

    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }

    await _handlePageChanged(index, ref);
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
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer(builder: (ctx, ref, _) {
      final wlName = ref.watch(marketWatchProvider.select((p) => p.wlName));
      final watchList =
          ref.watch(marketWatchProvider.select((p) => p.marketWatchlist));
      final isPreDef =
          ref.watch(marketWatchProvider.select((p) => p.isPreDefWLs));
      final sortBy = ref.watch(marketWatchProvider.select((p) => p.sortByWL));
      final providerPageIndex = ref.watch(
          marketWatchProvider.select((p) => p.currentWatchlistPageIndex));
      // Note: Theme is read directly from shadcn.Theme.of(context) throughout this widget

      // Listen for page index changes from provider (e.g., from bottom sheet)
      if (providerPageIndex != _currentPageIndex &&
          _pageController.hasClients) {
        _currentPageIndex = providerPageIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients && !_isDisposed) {
            _pageController.jumpToPage(providerPageIndex);
          }
        });
      }

      final names = watchList?.values?.cast<String>() ?? [];
      if (!_listsEqual(names, _lastTabNames)) {
        _lastTabNames
          ..clear()
          ..addAll(names);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            _scrollToWatchlistTab(ref, wlName);
            _handleTabScroll();
          },
        );
      }

      if (_lastWatchlistName != wlName) {
        _lastWatchlistName = wlName;

        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            _scrollToWatchlistTab(ref, wlName);
            _handleTabScroll();
          },
        );
      }

      // Watch delete mode state from provider
      final showDeleteMode = ref.watch(deleteModeProvider);

      // Watch option chain panel expanded state
      final isOCExpanded =
          ref.watch(watchlistOCProvider.select((p) => p.isExpanded));

      // Restore PageView position when OC panel collapses
      if (_wasOCExpanded && !isOCExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients && !_isDisposed) {
            _pageController.jumpToPage(_currentPageIndex);
          }
        });
      }
      _wasOCExpanded = isOCExpanded;

      return SafeArea(
        child: Container(
          color: resolveThemeColor(context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          child: Column(
            children: [
              if (!isOCExpanded) ...[
                _buildSearchBar(context, ref, wlName, isPreDef,
                    watchList?.values?.length ?? 0),
                _buildWatchlistTabs(ref, wlName, watchList),
                Expanded(
                  child: showDeleteMode
                      ? EditScripWeb(
                          wlName: wlName,
                          showInDialog: false,
                        )
                      : _buildPageView(ref, watchList, sortBy),
                ),
              ],
              if (isOCExpanded)
                const Expanded(child: OptionChainPanelWeb())
              else
                const OptionChainPanelWeb(),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPageView(WidgetRef ref, dynamic watchList, String sortBy) {
    // Show immediately even if watchList is null initially
    if (watchList?.values == null) {
      return const SizedBox.shrink(); // No loader, just empty space
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: watchList.values.length,
      onPageChanged: (index) {
        if (index != _currentPageIndex) {
          _handlePageChanged(index, ref);
        }
      },
      itemBuilder: (context, index) {
        final pageName = watchList.values[index];

        return KeyedSubtree(
          key: ValueKey('${pageName}_$index'),
          child: Consumer(
            builder: (context, ref, _) {
              // PERFORMANCE FIX: Use .select() to watch ONLY specific fields
              // Before: ref.watch(marketWatchProvider) - ANY change triggers rebuild
              // After: Only rebuild when wlName, scrips, or marketWatchScripData changes
              // This prevents socket data updates from rebuilding the entire watchlist
              final wlName =
                  ref.watch(marketWatchProvider.select((p) => p.wlName));
              final scrips =
                  ref.watch(marketWatchProvider.select((p) => p.scrips));
              final marketWatchScripData = ref.watch(
                  marketWatchProvider.select((p) => p.marketWatchScripData));

              // Get data immediately - no async waiting
              List pageScrips = [];
              if (index == _currentPageIndex && pageName == wlName) {
                pageScrips = scrips;
              } else {
                final cachedData = marketWatchScripData[pageName];
                if (cachedData != null) {
                  try {
                    pageScrips = jsonDecode(cachedData);
                  } catch (e) {
                    pageScrips = [];
                  }
                }
              }

              return RefreshIndicator(
                onRefresh: () async {
                  // Use ref.read() for method calls - doesn't affect rebuilds
                  await ref
                      .read(marketWatchProvider)
                      .fetchMWScrip(pageName, context);
                },
                child: _buildPageContent(ref, pageName, pageScrips, sortBy),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPageContent(
      WidgetRef ref, String pageName, List scrips, String sortBy) {
    if (pageName == 'My Stocks') {
      return const StocksScreenWeb();
    }

    if (pageName == 'My Positions') {
      return const PositionsScreenWeb();
    }

    if (scrips.isEmpty) {
      return _buildEmptyState(ref.read(marketWatchProvider));
    }

    return _buildWatchlistView(scrips, sortBy, pageName, ref);
  }

  Widget _buildSearchBar(
    BuildContext context,
    WidgetRef ref,
    String wlName,
    String isPreDef,
    int scripLen,
  ) {
    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      padding: const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 0),
      child: Row(
        children: [
          // Menu button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MyntIconButton(
              iconAsset: assets.hamMenu,
              color: resolveThemeColor(context,
                  dark: MyntColors.iconDark, light: MyntColors.icon),
              size: MyntButtonSize.medium,
              onPressed: () => _showWatchlistDialog(context, ref, wlName),
            ),
          ),
          // Search bar
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      _showSearchDialog(context, ref, wlName);
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IgnorePointer(
                        ignoring: true,
                        child: MyntSearchTextField(
                          controller: TextEditingController(),
                          placeholder: 'Search & add',
                          leadingIcon: assets.searchIcon,
                          enabled: false,
                          leadingIconHoverEffect: false,
                        ),
                      ),
                    ),
                  ),
                ),
                if (isPreDef != 'Yes' && scripLen > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Builder(
                      builder: (buttonContext) {
                        return MyntIconButton(
                          iconAsset: assets.searchFilter,
                          color: resolveThemeColor(context,
                              dark: MyntColors.iconDark,
                              light: MyntColors.icon),
                          size: MyntButtonSize.small,
                          onPressed: () async {
                            await Future.delayed(
                                const Duration(milliseconds: 150));
                            _showFilterPopup(buttonContext, ref);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlistTabs(
    WidgetRef ref,
    String wlName,
    dynamic watchList,
  ) {
    if (watchList?.values == null) return const SizedBox.shrink();

    final tabs = watchList.values.cast<String>();
    final currentIndex = tabs.indexOf(wlName);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 40,
      alignment: Alignment.bottomCenter,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: resolveThemeColor(
                    context,
                    dark: Colors.white.withOpacity(0.1),
                    light: Colors.black.withOpacity(0.05),
                  ),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap:
                        // _canScrollLeft ? () => _scrollTabs(left: true) : null,
                        () => _scrollTabs(left: true),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.chevron_left,
                        size: 20,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.iconDark,
                          light: MyntColors.icon,
                        ).withValues(alpha: _canScrollLeft ? 1.0 : 0.3),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ScrollConfiguration(
                  behavior: DragScrollBehavior(),
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
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
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
                            index: currentIndex >= 0 ? currentIndex : 0,
                            onChanged: (value) {
                              if (value < tabs.length) {
                                _handleTabTap(tabs[value], value, ref);
                                _scrollToSelectedTab(value, force: true);
                              }
                            },
                            children: [
                              for (var i = 0; i < tabs.length; i++)
                                shadcn.TabItem(
                                  child: Builder(
                                    builder: (context) {
                                      final isActive = i == currentIndex;
                                      return Text(
                                        _formatTabName(tabs[i]),
                                        style: MyntWebTextStyles.body(
                                          context,
                                          color: isActive
                                              ? resolveThemeColor(
                                                  context,
                                                  dark: MyntColors.primaryDark,
                                                  light: MyntColors.primary,
                                                )
                                              : resolveThemeColor(
                                                  context,
                                                  dark: MyntColors
                                                      .textSecondaryDark,
                                                  light:
                                                      MyntColors.textSecondary,
                                                ),
                                          fontWeight: isActive
                                              ? MyntFonts.bold
                                              : MyntFonts.medium,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: resolveThemeColor(
                    context,
                    dark: Colors.white.withOpacity(0.1),
                    light: Colors.black.withOpacity(0.05),
                  ),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap:
                        // _canScrollRight ? () => _scrollTabs(left: false) : null,
                        () => _scrollTabs(left: false),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.iconDark,
                          light: MyntColors.icon,
                        ).withValues(alpha: _canScrollRight ? 1.0 : 0.3),
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

  Widget _buildEmptyState(MarketWatchProvider mw) {
    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // CustomTextBtnWeb(
              //   label: 'Add Symbol',
              //   icon: assets.addCircleIcon,
              //   onPress: () {
              //     mw.requestMWScrip(context: context, isSubscribe: false);
              //     showDialog(
              //       context: context,
              //       barrierColor: Colors.transparent,
              //       builder: (BuildContext context) {
              //         return SearchDialogWeb(
              //           wlName: mw.wlName,
              //           isBasket: "Watchlist",
              //         );
              //       },
              //     );
              //   },
              // ),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    mw.requestMWScrip(context: context, isSubscribe: false);

                    showGeneralDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: MaterialLocalizations.of(context)
                          .modalBarrierDismissLabel,
                      barrierColor: Colors.black.withOpacity(0.3),
                      transitionDuration: const Duration(milliseconds: 200),
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return SearchDialogWeb(
                          wlName: mw.wlName,
                          isBasket: "Watchlist",
                        );
                      },
                      transitionBuilder:
                          (context, animation, secondaryAnimation, child) {
                        final curvedAnimation = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                          reverseCurve: Curves.easeIn,
                        );

                        return FadeTransition(
                          opacity: curvedAnimation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.95, end: 1.0)
                                .animate(curvedAnimation),
                            child: child,
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors
                          .grey.shade200, // adjust to match your custom widget
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          assets.addCircleIcon,
                          height: 18,
                          width: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Add Stock',
                          style: MyntWebTextStyles.body(context,
                            color: resolveThemeColor(context,
                              dark: MyntColors.textPrimary,
                              light: MyntColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                'No stocks in the watchlist',
                style: MyntWebTextStyles.bodyMedium(
                  context,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 300,
                child: Text(
                  'Use the search box above to find and add stocks, indices, futures or options.',
                  textAlign: TextAlign.center,
                  style: MyntWebTextStyles.para(
                    context,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWatchlistView(List scrips, String sortBy, String wlName, WidgetRef ref) {
    final marketWatch = ref.read(marketWatchProvider);
    final isPreDef = marketWatch.isPreDefWLs == "Yes";

    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      child: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.transparent,
        ),
        child: ReorderableListView.builder(
          key: ValueKey('${scrips.length}_$sortBy'),
          itemCount: scrips.length,
          buildDefaultDragHandles: false, // Custom drag - click and move to reorder
          padding: const EdgeInsets.only(
              right: 12.0,
              bottom: 8.0),
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final double elevation = Tween<double>(begin: 0, end: 12)
                    .animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    ))
                    .value;
                return Material(
                  elevation: elevation,
                  color: resolveThemeColor(context,
                      dark: MyntColors.backgroundColorDark,
                      light: MyntColors.backgroundColor),
                  borderRadius: BorderRadius.circular(8),
                  shadowColor: Colors.black26,
                  child: child,
                );
              },
              child: child,
            );
          },
          onReorder: isPreDef
              ? (_, __) {} // No-op for pre-defined watchlists
              : (oldIndex, newIndex) {
                  // Call the provider's reOrderList method
                  marketWatch.reOrderList(
                    context: context,
                    oldIndex: oldIndex,
                    newIndex: newIndex,
                    wlName: wlName,
                  );
                },
          itemBuilder: (_, i) {
            final child = Column(
              key: ValueKey('${scrips[i]['token']}_$i'),
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: WatchlistCardWeb(watchListData: scrips[i]),
                ),
                if (i < scrips.length - 1) const ListDivider(),
              ],
            );

            // Wrap with drag listener for non-predefined watchlists (click+move to drag)
            if (isPreDef) {
              return child;
            }

            return ReorderableDragStartListener(
              key: ValueKey('drag_${scrips[i]['token']}_$i'),
              index: i,
              child: child,
            );
          },
        ),
      ),
    );
  }

  String _formatTabName(String v) {
    if (v == 'My Stocks') return 'Holdings';
    if (v == 'My Positions') return 'Positions';
    if (v == 'Nifty50') return 'Nifty 50';
    if (v == 'Niftybank') return 'Nifty Bank';
    if (v == 'Sensex') return 'Sensex';
    return v.isEmpty
        ? ''
        : v.length <= 12 // Increased length limit for web
            ? '${v[0].toUpperCase()}${v.substring(1)}'
            : '${v.substring(0, 11)}..';
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _showFilterPopup(BuildContext context, WidgetRef ref) {
    final marketWatch = ref.read(marketWatchProvider);
    final currentSort = marketWatch.sortByWL;

    shadcn.showPopover(
      context: context,
      alignment: Alignment.bottomCenter,
      offset: const Offset(0, 4),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(context).borderRadiusLg,
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
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterMenuItem(
                    context,
                    'Scrip Name',
                    'scrip',
                    currentSort,
                    ref,
                  ),
                  _buildFilterMenuItem(
                    context,
                    'LTP',
                    'price',
                    currentSort,
                    ref,
                  ),
                  _buildFilterMenuItem(
                    context,
                    'Perc.Change',
                    'perchng',
                    currentSort,
                    ref,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterMenuItem(
    BuildContext context,
    String title,
    String value,
    String currentSort,
    WidgetRef ref,
  ) {
    // Determine if this option is currently active and its direction
    bool isActive = false;
    bool isAscending = false;

    if (value == "scrip") {
      isActive = currentSort.contains("Scrip");
      isAscending = currentSort.contains("A to Z");
    } else if (value == "price") {
      isActive = currentSort.contains("Price");
      isAscending = currentSort.contains("Low to High");
    } else if (value == "perchng") {
      isActive = currentSort.contains("Per.Chng");
      isAscending = currentSort.contains("Low to High");
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          shadcn.closeOverlay(context);
          _handleFilterSelection(value, ref);
        },
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
              // Text on the left
              Expanded(
                child: Text(
                  title,
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight:
                        isActive ? MyntFonts.semiBold : MyntFonts.medium,
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
              // Reserve space for icon on the right (always 18px + 8px spacing)
              SizedBox(
                width: 26, // 18px icon + 8px spacing
                child: isActive
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const SizedBox(width: 8),
                          Icon(
                            isAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 18,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.primaryDark,
                              light: MyntColors.primary,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleFilterSelection(String filterType, WidgetRef ref) {
    final marketWatch = ref.read(marketWatchProvider);
    String sortingValue = "";

    // Get current sort state to determine direction
    final currentSort = marketWatch.sortByWL;

    if (filterType == "scrip") {
      // Toggle between A to Z and Z to A
      if (currentSort.contains("Scrip - A to Z")) {
        sortingValue = "Scrip - Z to A";
      } else {
        sortingValue = "Scrip - A to Z";
      }
    } else if (filterType == "price") {
      // Toggle between Low to High and High to Low
      if (currentSort.contains("Price - Low to High")) {
        sortingValue = "Price - High to Low";
      } else {
        sortingValue = "Price - Low to High";
      }
    } else if (filterType == "perchng") {
      // Toggle between Low to High and High to Low
      if (currentSort.contains("Per.Chng - Low to High")) {
        sortingValue = "Per.Chng - High to Low";
      } else {
        sortingValue = "Per.Chng - Low to High";
      }
    }

    // Apply the sort using the same method as the original filter
    marketWatch.getSortByWL(sortingValue);
    marketWatch.filterMWScrip(
        sorting: sortingValue, wlName: marketWatch.wlName, context: context);
  }

  void _showWatchlistDialog(
      BuildContext context, WidgetRef ref, String currentWLName) {
    final marketWatch = ref.read(marketWatchProvider);
    final watchlist = marketWatch.marketWatchlist!.values!;
    final preDefWl = marketWatch.preDefWL;

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
        final Map<int, bool> dialogHoveredItems = {};
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
              child: Center(
                  child: shadcn.Card(
                borderRadius: BorderRadius.circular(8),
                padding: EdgeInsets.zero,
                child: Container(
                  width: 500,
                  constraints: const BoxConstraints(maxHeight: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  shadcn.Theme.of(context).colorScheme.border,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Watchlist',
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
                          padding: const EdgeInsets.only(
                              top: 10, bottom: 10, left: 0, right: 0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                           
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 6, right: 10, left: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    MyntIconTextButton(
                                      label: 'New Watchlist',
                                      iconAsset: assets.addCircleIcon,
                                      onPressed: () {
                                        final customCount =
                                            watchlist.length - preDefWl.length;
                                        if (customCount >= 10) {
                                          ResponsiveSnackBar.showWarning(
                                            context,
                                            "Maximum watchlist limit reached, you can create up to 10 watchlist",
                                          );
                                          return;
                                        }
                                        Navigator.of(context).pop();
                                        _showCreateWatchlistDialog(
                                            context, ref);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Flexible(
                                child: ScrollConfiguration(
                                  behavior: const MaterialScrollBehavior()
                                      .copyWith(scrollbars: false),
                                  child: RawScrollbar(
                                    thumbVisibility: false,
                                    thickness: 6,
                                    radius: const Radius.circular(0),
                                    thumbColor: resolveThemeColor(
                                      context,
                                      dark: MyntColors.scrollbarThumbDark,
                                      light: MyntColors.scrollbarThumbLight,
                                    ),
                                    child: StatefulBuilder(
                                        builder: (context, setDialogState) {
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        // padding:
                                        //     const EdgeInsets.only(right: 4),
                                        itemCount: watchlist.length,
                                        itemBuilder: (context, index) {
                                          final watchlistName =
                                              watchlist[index];
                                          final isPredefined =
                                              preDefWl.contains(watchlistName);

                                          return MouseRegion(
                                            onEnter: (_) => setDialogState(() =>
                                                dialogHoveredItems[index] =
                                                    true),
                                            onExit: (_) => setDialogState(() =>
                                                dialogHoveredItems[index] =
                                                    false),
                                            child: InkWell(
                                              onTap: () async {
                                                Navigator.of(context).pop();
                                                if (watchlistName !=
                                                    currentWLName) {
                                                  await _handleWatchlistSelection(
                                                      watchlistName, ref);
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.only(
                                                    top: 8,
                                                    bottom: 8,
                                                    left: 14,
                                                    right: 10),
                                                color: (dialogHoveredItems[
                                                            index] ??
                                                        false)
                                                    ? resolveThemeColor(
                                                        context,
                                                        dark: MyntColors
                                                            .primaryDark,
                                                        light:
                                                            MyntColors.primary,
                                                      ).withValues(alpha: 0.08)
                                                    : Colors.transparent,
                                                child: Row(
                                                  children: [
                                                    Radio<String>(
                                                      value: watchlistName,
                                                      groupValue: currentWLName,
                                                      onChanged: (value) async {
                                                        Navigator.of(context)
                                                            .pop();
                                                        if (value != null &&
                                                            value !=
                                                                currentWLName) {
                                                          await _handleWatchlistSelection(
                                                              value, ref);
                                                        }
                                                      },
                                                      activeColor:
                                                          resolveThemeColor(
                                                        context,
                                                        dark: MyntColors
                                                            .primaryDark,
                                                        light:
                                                            MyntColors.primary,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        _formatWatchlistName(
                                                            watchlistName),
                                                        style: MyntWebTextStyles
                                                            .body(
                                                          context,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              resolveThemeColor(
                                                            context,
                                                            dark: MyntColors
                                                                .textPrimaryDark,
                                                            light: MyntColors
                                                                .textPrimary,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    if (!isPredefined) ...[
                                                      MyntIconButton(
                                                        icon:
                                                            Icons.edit_outlined,
                                                        size: MyntButtonSize
                                                            .medium,
                                                        color:
                                                            resolveThemeColor(
                                                          context,
                                                          dark: MyntColors
                                                              .iconDark,
                                                          light:
                                                              MyntColors.icon,
                                                        ),
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                          _showEditWatchlistDialog(
                                                              context,
                                                              ref,
                                                              watchlistName);
                                                        },
                                                      ),
                                                      MyntIconButton(
                                                        icon: Icons
                                                            .delete_outline_outlined,
                                                        size: MyntButtonSize
                                                            .medium,
                                                        color:
                                                            resolveThemeColor(
                                                          context,
                                                          dark: MyntColors
                                                              .lossDark,
                                                          light:
                                                              MyntColors.loss,
                                                        ),
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                          _showDeleteWatchlistDialog(
                                                              context,
                                                              ref,
                                                              watchlistName);
                                                        },
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
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
            scale:
                Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  String _formatWatchlistName(String name) {
    if (name.isEmpty) return name;

    switch (name) {
      case "My Stocks":
        return "Holdings";
      case "Nifty50":
        return "Nifty 50";
      case "Niftybank":
        return "Nifty Bank";
      default:
        return "${name[0].toUpperCase()}${name.substring(1)}";
    }
  }

  Future<void> _handleWatchlistSelection(
      String watchlistName, WidgetRef ref) async {
    if (!mounted) return;
    final marketWatch = ref.read(marketWatchProvider);

    try {
      await marketWatch.requestMWScrip(context: context, isSubscribe: false);
      if (!mounted) return;

      final predefined = marketWatch.preDefWL;
      final isPredefined = predefined.contains(watchlistName);

      await marketWatch.changeWlName(
          watchlistName, isPredefined ? 'Yes' : 'No');
      if (!mounted) return;
      await marketWatch.changeWLScrip(watchlistName, context);
      if (!mounted) return;

      await marketWatch.requestMWScrip(context: context, isSubscribe: true);

      // Update the page controller to show the selected watchlist
      final watchList = marketWatch.marketWatchlist;
      if (watchList?.values != null) {
        final watchlists = watchList!.values!.cast<String>();
        final newIndex = watchlists.indexOf(watchlistName);
        if (newIndex != -1) {
          _currentPageIndex = newIndex;
          marketWatch.setCurrentWatchlistPageIndex(newIndex);
          if (_pageController.hasClients) {
            _pageController.jumpToPage(newIndex);
          }
        }
      }
    } catch (e) {
    }
  }

  void _showEditWatchlistDialog(
      BuildContext context, WidgetRef ref, String watchlistName) {
    final TextEditingController controller =
        TextEditingController(text: watchlistName);
    final FocusNode focusNode = FocusNode();

    String? errorText;

    // Request focus after dialog animation completes (web autofocus fix)
    // For edit dialog, position cursor at end instead of selecting all text
    Future.delayed(const Duration(milliseconds: 250), () {
      focusNode.requestFocus();
      // Wait for focus to fully establish before setting cursor position
      // This prevents the default "select all" behavior on web
      Future.delayed(const Duration(milliseconds: 50), () {
        if (controller.text.isNotEmpty) {
          controller.selection = TextSelection.collapsed(
            offset: controller.text.length,
          );
        }
      });
    });

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
              child: Center(
                  child: shadcn.Card(
                borderRadius: BorderRadius.circular(8),
                padding: EdgeInsets.zero,
                child: Container(
                  width: 400,
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  shadcn.Theme.of(context).colorScheme.border,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Edit Watchlist',
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
                      // Content. Wrapped in StatefulBuilder so the inline
                      // error state (empty-name validation) can live within
                      // the dialog without bubbling up to the parent screen.
                      Flexible(
                        child: StatefulBuilder(
                          builder: (context, setDialogState) {
                            void clearError() {
                              if (errorText != null) {
                                setDialogState(() => errorText = null);
                              }
                            }
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MyntFormTextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    placeholder: 'Enter watchlist name',
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z0-9 ]'),
                                      ),
                                    ],
                                    onChanged: (_) => clearError(),
                                  ),
                                  if (errorText != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      errorText!,
                                      style: MyntWebTextStyles.para(
                                        context,
                                        color: resolveThemeColor(
                                          context,
                                          dark: MyntColors.lossDark,
                                          light: MyntColors.loss,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  MyntPrimaryButton(
                                    size: MyntButtonSize.large,
                                    label: 'Save',
                                    isFullWidth: true,
                                    onPressed: () async {
                                      final newName = controller.text.trim();
                                      if (newName.isEmpty) {
                                        // Client-side validation → inline
                                        // red error per the established
                                        // error-display pattern (toasts are
                                        // reserved for backend errors).
                                        setDialogState(() {
                                          errorText =
                                              'Watchlist name cannot be empty';
                                        });
                                        return;
                                      }
                                      if (newName != watchlistName) {
                                        // Capture the screen's context BEFORE popping
                                        // the dialog. The dialog's `context` becomes
                                        // stale after pop, and passing it into the
                                        // async provider call hits the Navigator
                                        // _debugLocked assertion during finalizeTree.
                                        final screenContext = this.context;
                                        Navigator.of(context).pop();
                                        if (!mounted) return;
                                        await _handleWatchlistRename(
                                            watchlistName,
                                            newName,
                                            ref,
                                            screenContext);
                                      } else {
                                        // Save clicked without renaming — no
                                        // API call (nothing changed at the
                                        // broker). Close the dialog silently;
                                        // a "renamed successfully" toast would
                                        // be misleading because nothing was
                                        // actually renamed.
                                        Navigator.of(context).pop();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              )),
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
            scale:
                Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  void _showDeleteWatchlistDialog(
      BuildContext context, WidgetRef ref, String watchlistName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
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
              child: Center(
                  child: shadcn.Card(
                borderRadius: BorderRadius.circular(8),
                padding: EdgeInsets.zero,
                child: Container(
                  width: 400,
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: resolveThemeColor(context,
                        dark: MyntColors.dialogDark,
                        light: MyntColors.dialog),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  shadcn.Theme.of(context).colorScheme.border,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Delete Watchlist',
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
                                'Are you sure you want to delete "${_formatWatchlistName(watchlistName)}"?',
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
                                label: 'Delete',
                                isFullWidth: true,
                                backgroundColor: resolveThemeColor(
                                  context,
                                  dark: MyntColors.errorDark,
                                  light: MyntColors.tertiary,
                                ),
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await _handleWatchlistDelete(
                                      watchlistName, ref);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
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
            scale:
                Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  void _showCreateWatchlistDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController controller = TextEditingController();
    final FocusNode focusNode = FocusNode();
  
    String? errorText;

    // Request focus after dialog animation completes (web autofocus fix)
    Future.delayed(const Duration(milliseconds: 250), () {
      focusNode.requestFocus();
    });

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
              child: Center(
                  child: shadcn.Card(
                borderRadius: BorderRadius.circular(8),
                padding: EdgeInsets.zero,
                child: Container(
                  width: 400,
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  shadcn.Theme.of(context).colorScheme.border,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'New Watchlist',
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
                      // Content. Wrapped in StatefulBuilder so the inline
                      // error state (empty-name validation) can live within
                      // the dialog without bubbling up to the parent screen.
                      Flexible(
                        child: StatefulBuilder(
                          builder: (context, setDialogState) {
                            void clearError() {
                              if (errorText != null) {
                                setDialogState(() => errorText = null);
                              }
                            }
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MyntFormTextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    placeholder: 'Enter watchlist name',
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z0-9 ]'),
                                      ),
                                    ],
                                    onChanged: (_) => clearError(),
                                  ),
                                  if (errorText != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      errorText!,
                                      style: MyntWebTextStyles.para(
                                        context,
                                        color: resolveThemeColor(
                                          context,
                                          dark: MyntColors.lossDark,
                                          light: MyntColors.loss,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  MyntPrimaryButton(
                                    size: MyntButtonSize.large,
                                    label: 'Create',
                                    isFullWidth: true,
                                    onPressed: () async {
                                      final name = controller.text.trim();
                                      if (name.isEmpty) {
                                        // Client-side validation → inline
                                        // red error per the established
                                        // error-display pattern (toasts are
                                        // reserved for backend errors).
                                        setDialogState(() {
                                          errorText =
                                              'Watchlist name cannot be empty';
                                        });
                                        return;
                                      }
                                      Navigator.of(context).pop();
                                      await _handleWatchlistCreate(name, ref);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              )),
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
            scale:
                Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _handleWatchlistRename(String oldName, String newName,
      WidgetRef ref, BuildContext dialogContext) async {
    if (!mounted) return;
    final marketWatch = ref.read(marketWatchProvider);
    try {
      await marketWatch.fetchWatchListRename(oldName, newName, dialogContext);
    } catch (e) {
    }
  }

  Future<void> _handleWatchlistDelete(
      String watchlistName, WidgetRef ref) async {
    if (!mounted) return;
    final marketWatch = ref.read(marketWatchProvider);
    try {
      await marketWatch.deleteWatchList(watchlistName, context);
    } catch (e) {
    }
  }

  Future<void> _handleWatchlistCreate(String name, WidgetRef ref) async {
    if (!mounted) return;
    final marketWatch = ref.read(marketWatchProvider);
    try {
      await marketWatch.addWatchList(name, context);
    } catch (e) {
    }
  }

  void _showSearchDialog(BuildContext context, WidgetRef ref, String wlName) {
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
        return SearchDialogWeb(
          wlName: wlName,
          isBasket: "Watchlist",
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
            scale:
                Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}

// Index slot widget for watchlist screen with hover edit icon
class _WatchlistIndexSlotWeb extends ConsumerStatefulWidget {
  final dynamic indexItem;
  final int indexPosition;
  final ThemesProvider theme;
  final dynamic marketWatch;
  final dynamic indexProvider;

  const _WatchlistIndexSlotWeb({
    required this.indexItem,
    required this.indexPosition,
    required this.theme,
    required this.marketWatch,
    required this.indexProvider,
  });

  @override
  ConsumerState<_WatchlistIndexSlotWeb> createState() =>
      _WatchlistIndexSlotWebState();
}

class _WatchlistIndexSlotWebState
    extends ConsumerState<_WatchlistIndexSlotWeb> {
  bool _isHovered = false;

  Future<void> _handleTap(BuildContext context) async {
    if (!mounted) return;
    try {
      // Fetch index list before opening bottom sheet
      await widget.indexProvider.fetchIndexList("NSE", context);
      if (!mounted) return;

      // Open the bottom sheet dialog
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: IndexBottomSheetWeb(
              defaultIndex: widget.indexItem,
              indexPosition: widget.indexPosition,
            ),
          );
        },
      );

      // Clean up after dialog closes
      if (!mounted) return;
      await widget.indexProvider.fetchIndexList("exit", context);
      if (!mounted) return;
      await widget.marketWatch
          .requestMWScrip(context: context, isSubscribe: true);
    } catch (e) {
    }
  }

  Future<void> _handleIndexClick(BuildContext context) async {
    if (!mounted) return;
    try {
      // First, safely fetch the quote data
      await widget.marketWatch.fetchScripQuoteIndex(
          widget.indexItem.token?.toString() ?? "",
          widget.indexItem.exch?.toString() ?? "",
          context);
      if (!mounted) return;

      final quots = widget.marketWatch.getQuotes;

      // Make sure we have valid quote data before proceeding
      if (quots == null) {
        return;
      }

      // Create DepthInputArgs with null safety
      final depthArgs = DepthInputArgs(
          exch: quots.exch?.toString() ?? "",
          token: quots.token?.toString() ?? "",
          tsym: quots.tsym?.toString() ?? "",
          instname: quots.instname?.toString() ?? "",
          symbol: quots.symbol?.toString() ?? "",
          expDate: quots.expDate?.toString() ?? "",
          option: quots.option?.toString() ?? "");

      // Call depth APIs with the safely constructed arguments
      if (depthArgs.token.isNotEmpty && depthArgs.exch.isNotEmpty) {
        await widget.marketWatch.calldepthApis(context, depthArgs, "");
      }

      // Apply the picked symbol to the chart's CURRENTLY-focused pane. Routed
      // through the engine (which reads its live `.pane.active` marker at apply
      // time) rather than Flutter's `activePaneIndex`, so a pick reliably lands
      // on the focused pane — including re-picking a symbol already shown in
      // another pane. Harmless when no chart/iframe is mounted (the shell's
      // listener no-ops). ls/ti unknown here; the engine's GetSecurityInfo
      // fetch backfills the real lot/tick.
      if (!mounted) return;
      if (depthArgs.token.isNotEmpty && depthArgs.exch.isNotEmpty) {
        ref.read(activePaneSymbolRequestProvider.notifier).request(
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcn.Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _handleIndexClick(context),
        child: shadcn.Card(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              // Main content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Index name
                  Text(
                    widget.indexItem.idxname ?? "",
                    style: MyntWebTextStyles.symbol(
                      context,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Live price widget - fixed font size for consistency
                  _WatchlistLivePriceWidget(
                    key: ValueKey('price_${widget.indexItem.token ?? ""}'),
                    token: widget.indexItem.token?.toString() ?? "",
                    initialLtp: (widget.indexItem.ltp == null ||
                            widget.indexItem.ltp == "null")
                        ? "0.00"
                        : widget.indexItem.ltp?.toString() ?? "0.00",
                    initialChange: (widget.indexItem.change == null ||
                            widget.indexItem.change == "null")
                        ? "0.00"
                        : widget.indexItem.change?.toString() ?? "0.00",
                    initialPerChange: (widget.indexItem.perChange == null ||
                            widget.indexItem.perChange == "null")
                        ? "0.00"
                        : widget.indexItem.perChange?.toString() ?? "0.00",
                  ),
                ],
              ),
              // Edit icon on hover
              if (_isHovered)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      splashColor:
                          shadcn.Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(.15)
                              : Colors.black.withOpacity(.15),
                      highlightColor:
                          shadcn.Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(.08)
                              : Colors.black.withOpacity(.08),
                      onTap: () => _handleTap(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: shadcn.Theme.of(context).colorScheme.card,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: shadcn.Theme.of(context)
                              .colorScheme
                              .mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Live price widget for watchlist index slots
class _WatchlistLivePriceWidget extends ConsumerStatefulWidget {
  final String token;
  final String initialLtp;
  final String initialChange;
  final String initialPerChange;

  const _WatchlistLivePriceWidget({
    super.key,
    required this.token,
    required this.initialLtp,
    required this.initialChange,
    required this.initialPerChange,
  });

  @override
  ConsumerState<_WatchlistLivePriceWidget> createState() =>
      _WatchlistLivePriceWidgetState();
}

class _WatchlistLivePriceWidgetState
    extends ConsumerState<_WatchlistLivePriceWidget> {
  late String _ltp;
  late String _change;
  late String _perChange;
  StreamSubscription? _subscription;
  bool _isUpdatePending = false;
  final _debouncer = _Debouncer(milliseconds: 300);
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _ltp = widget.initialLtp == "null" ? "0.00" : widget.initialLtp;
    _change = widget.initialChange == "null" ? "0.00" : widget.initialChange;
    _perChange =
        widget.initialPerChange == "null" ? "0.00" : widget.initialPerChange;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _setupSocketListener();
      _isInitialized = true;
    }
  }

  @override
  void didUpdateWidget(_WatchlistLivePriceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _ltp = widget.initialLtp == "null" ? "0.00" : widget.initialLtp;
      _change = widget.initialChange == "null" ? "0.00" : widget.initialChange;
      _perChange =
          widget.initialPerChange == "null" ? "0.00" : widget.initialPerChange;
      _subscription?.cancel();
      _isInitialized = false;
      _setupSocketListener();
      _isInitialized = true;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _debouncer.cancel();
    super.dispose();
  }

  void _setupSocketListener() {
    if (widget.token.isEmpty) return;

    final websocket =
        ProviderScope.containerOf(context).read(websocketProvider);

    final existingData = websocket.socketDatas[widget.token];
    if (existingData != null) {
      _updateFromSocketData(existingData);
    }

    _subscription = websocket.socketDataStream.listen((data) {
      if (data.containsKey(widget.token)) {
        final socketData = data[widget.token];
        if (socketData != null) {
          final hasChanged = _updateFromSocketData(socketData);
          // ✅ Data is stored in local state, individual widgets can read from it
          // Only rebuild if absolutely necessary (e.g., for UI state changes)
          if (hasChanged && mounted && !_isUpdatePending) {
            _isUpdatePending = true;
            _debouncer.run(() {
              if (mounted) {
                // ✅ Keep setState for now as this widget manages its own display state
                // Consider using ValueNotifier if this becomes a performance issue
                setState(() {});
                _isUpdatePending = false;
              }
            });
          }
        }
      }
    });
  }

  bool _updateFromSocketData(dynamic data) {
    bool hasChanged = false;
    final newLtp = data['lp']?.toString() ?? "0.00";
    if (newLtp != "null" && newLtp != _ltp) {
      _ltp = newLtp;
      hasChanged = true;
    }
    final newChange = data['chng']?.toString() ?? "0.00";
    if (newChange != "null" && newChange != _change) {
      _change = newChange;
      hasChanged = true;
    }
    final newPerChange = data['pc']?.toString() ?? "0.00";
    if (newPerChange != "null" && newPerChange != _perChange) {
      _perChange = newPerChange;
      hasChanged = true;
    }
    return hasChanged;
  }

  Color _getChangeColor(String change, String perChange) {
    // final colorScheme = shadcn.Theme.of(context).colorScheme;
    if (change.startsWith("-") || perChange.startsWith('-')) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else if ((change == "null" || perChange == "null") ||
        (change == "0.00" || perChange == "0.00")) {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final changeColor = _getChangeColor(_change, _perChange);
    // Use Wrap for responsive layout - wraps to next line when no space
    return RepaintBoundary(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4, // Space between items on same line
        runSpacing: 2, // Space between lines when wrapped
        children: [
          Text(
            _ltp,
            style: _getTextStyle(
              changeColor,
              13,
              1,
            ),
          ),
          Text(
            "$_change ($_perChange%)",
            style: _getTextStyle(
              resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
              13,
              1,
            ),
          ),
        ],
      ),
    );
  }

  // Cache for text styles - match default_index_list_web.dart
  static final Map<String, TextStyle> _textStyleCache = {};

  TextStyle _getTextStyle(Color color, double size, [int? fw]) {
    final key = '${color.value}|$size|${fw ?? "null"}';
    return _textStyleCache.putIfAbsent(
      key,
      () => MyntWebTextStyles.priceChange(
        context,
        color: color,
      ),
    );
  }
}

// Debouncer helper class for throttling updates
class _Debouncer {
  final int milliseconds;
  Timer? _timer;

  _Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void cancel() {
    _timer?.cancel();
  }
}

class DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
