import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/iop_provider.dart';
import '../../../provider/stocks_provider.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/res.dart';
import 'ipo_orderbook_screen/ipo_order_book_main_screen_web.dart';
import 'upcoming/ipo_upcoming_web.dart';
import 'main_sme_list/main_sme_list_web.dart';
import '../../../sharedWidget/common_search_fields_web.dart';

class IpoExploreScreens extends ConsumerStatefulWidget {
  final ThemesProvider theme;
  final int? initialTabIndex;
  final Function(bool)? onBoundaryReached;
  const IpoExploreScreens({
    super.key,
    required this.theme,
    this.initialTabIndex,
    this.onBoundaryReached,
  });

  @override
  ConsumerState<IpoExploreScreens> createState() => _ExploreScreensState();
}

class _ExploreScreensState extends ConsumerState<IpoExploreScreens>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int selectedTab = 0;
  ProviderSubscription<int>? _tabSub;
  final ScrollController _tabScrollController = ScrollController();

  // TC_30: the search field's X button only empties the text box; it never
  // calls onClear. Watch the box and reset the IPO search when it goes empty.
  late final TextEditingController _searchController;
  String _lastSearchText = '';

  void _onSearchTextChanged() {
    final text = _searchController.text;
    if (text.isEmpty && _lastSearchText.isNotEmpty) {
      _lastSearchText = text;
      ref.read(ipoProvide).clearCommonIpoSearch();
      return;
    }
    _lastSearchText = text;
  }

  // TC_220: Upcoming tab gets its own search box (same as Holdings: one box
  // per tab, filter follows the text, so X/backspace also reset it). It feeds
  // the existing Upcoming filter via setIpoSearchQuery.
  final TextEditingController _upcomingSearchController =
      TextEditingController();

  void _onUpcomingSearchChanged() {
    final ipo = ref.read(ipoProvide);
    if (ipo.ipocommonsearchcontroller.text != _upcomingSearchController.text) {
      ipo.setIpoSearchQuery(_upcomingSearchController.text);
    }
  }

  // My Bids gets its own box the same way; it feeds the existing open/closed
  // bids filter through the same query.
  final TextEditingController _bidsSearchController = TextEditingController();

  void _onBidsSearchChanged() {
    final ipo = ref.read(ipoProvide);
    if (ipo.ipocommonsearchcontroller.text != _bidsSearchController.text) {
      ipo.setIpoSearchQuery(_bidsSearchController.text);
    }
  }

  // When the query is cleared from inside My Bids (Open / Close orders
  // switch), empty the box too so text and list stay in step.
  late final TextEditingController _ipoQueryController;

  void _onIpoQueryChanged() {
    if (_ipoQueryController.text.isEmpty) {
      if (_bidsSearchController.text.isNotEmpty) _bidsSearchController.clear();
      if (_upcomingSearchController.text.isNotEmpty) {
        _upcomingSearchController.clear();
      }
    }
  }

  // Switching tabs clears every IPO search (as Holdings does), whether by
  // click, swipe or a tab change from elsewhere.
  void _clearIpoSearches() {
    ref.read(ipoProvide).clearCommonIpoSearch();
    _upcomingSearchController.clear();
    _bidsSearchController.clear();
    ref.read(ipoProvide).setIpoSearchQuery("");
  }

  @override
  void initState() {
    super.initState();
    _searchController = ref.read(stocksProvide).searchController;
    _lastSearchText = _searchController.text;
    _searchController.addListener(_onSearchTextChanged);
    _upcomingSearchController.addListener(_onUpcomingSearchChanged);
    _bidsSearchController.addListener(_onBidsSearchChanged);
    _ipoQueryController = ref.read(ipoProvide).ipocommonsearchcontroller;
    _ipoQueryController.addListener(_onIpoQueryChanged);
    _tabController = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTabIndex ?? 0);
    selectedTab = widget.initialTabIndex ?? 0;

    // Bug fix: placing or cancelling a bid sets My Bids as the tab in the
    // provider, but this screen only read it when first opened, so it stayed
    // on the current tab. Follow later changes too.
    _tabSub = ref.listenManual<int>(
        ipoProvide.select((p) => p.selectedTab), (prev, next) {
      if (!mounted || next == selectedTab) return;
      setState(() => selectedTab = next);
      _tabController.animateTo(next);
    });

    _tabController.animation!.addListener(() {
      final newIndex = _tabController.animation!.value.round();
      if (selectedTab != newIndex) {
        setState(() {
          selectedTab = newIndex;
        });
        _clearIpoSearches();
        ref.read(ipoProvide).setSelectedTab(newIndex);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final providerTab = ref.read(ipoProvide).selectedTab;
        if (providerTab != selectedTab) {
          setState(() {
            selectedTab = providerTab;
          });
          _clearIpoSearches();
          _tabController.animateTo(providerTab);
        }
      }
    });
  }

  @override
  void dispose() {
    _tabSub?.close();
    _searchController.removeListener(_onSearchTextChanged);
    _upcomingSearchController.removeListener(_onUpcomingSearchChanged);
    _upcomingSearchController.dispose();
    _bidsSearchController.removeListener(_onBidsSearchChanged);
    _ipoQueryController.removeListener(_onIpoQueryChanged);
    _bidsSearchController.dispose();
    _tabController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final explore = ref.watch(authProvider);
    final theme = ref.watch(themeProvider);
    final ipo = ref.watch(ipoProvide);

    return MyntLoaderOverlay(
      isLoading: explore.loading,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tabs and Search Bar Section
            _buildTabsAndSearchBar(theme, ipo),
            const SizedBox(height: 4),
            // Content based on selected tab
            Expanded(
              child: _CustomTabBarView(
                controller: _tabController,
                onBoundaryReached: widget.onBoundaryReached,
                children: const [
                  MainSmeListCard(),
                  UpcomingIpo(),
                  IpoOrderbookMainScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsAndSearchBar(ThemesProvider theme, IPOProvider ipo) {
    return Container(
      padding: const EdgeInsets.only(bottom: 4, left: 0, right: 16, top: 0),
      decoration: const BoxDecoration(
          // border: Border(
          //   bottom: BorderSide(
          //     color: theme.isDarkMode ? WebDarkColors.divider : WebColors.divider,
          //   ),
          // ),
          ),
      child: Row(
        children: [
          // Segmented Control Tabs on the left
          _buildSegmentedControl(theme),
          // Spacer to push search to the right
          const Spacer(),
          // Search Bar
          if (selectedTab == 0) ...[
            SizedBox(
              width: 400,
              child: MyntSearchTextField.withSmartClear(
                controller: ref.read(stocksProvide).searchController,
                placeholder: 'Search IPO',
                leadingIcon: assets.searchIcon,
                onChanged: (value) {
                  // ipo.searchCommonIpo(value, context);
                  ipo.searchCommonIpo(value, context, minChars: 1);
                },
                onClear: () {
                  ref.read(stocksProvide).searchController.clear();
                  ipo.clearCommonIpoSearch();
                },
              ),
            ),
            const SizedBox(width: 16),
          ],
          if (selectedTab == 1) ...[
            SizedBox(
              width: 400,
              child: MyntSearchTextField.withSmartClear(
                controller: _upcomingSearchController,
                placeholder: 'Search upcoming IPO',
                leadingIcon: assets.searchIcon,
                onClear: () => _upcomingSearchController.clear(),
              ),
            ),
            const SizedBox(width: 16),
          ],
          if (selectedTab == 2) ...[
            SizedBox(
              width: 400,
              child: MyntSearchTextField.withSmartClear(
                controller: _bidsSearchController,
                placeholder: 'Search my bids',
                leadingIcon: assets.searchIcon,
                onClear: () => _bidsSearchController.clear(),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(ThemesProvider theme) {
    final tabs = ref
        .read(ipoProvide)
        .tablistitems
        .map((item) => item['title'].toString())
        .toList();

    return SizedBox(
      height: 45,
      child: SingleChildScrollView(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int index = 0; index < tabs.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildSegmentedTab(
                  tabs[index],
                  index,
                  selectedTab == index,
                  theme,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedTab(
    String title,
    int index,
    bool isSelected,
    ThemesProvider theme,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          setState(() {
            selectedTab = index;
          });
          _tabController.animateTo(index);
          // ref.read(ipoProvide).clearCommonIpoSearch();
          // ref.read(ipoProvide).setIpoSearchQuery("");
          _clearIpoSearches();
          FocusScope.of(context).unfocus();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: isSelected
                ? Border(
                    bottom: BorderSide(
                      color: resolveThemeColor(context,
                          dark: MyntColors.primaryDark, light: MyntColors.primary),
                      width: 2.0,
                    ),
                  )
                : const Border(
                    bottom: BorderSide(
                      color: Colors.transparent,
                      width: 2.0,
                    ),
                  ),
          ),
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.body(
              context,
              color: isSelected
                  ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark, light: MyntColors.primary)
                  : resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
      ),
    );
  }
}

// Custom TabBarView that handles edge swipe gestures to parent tabs
class _CustomTabBarView extends StatefulWidget {
  final TabController controller;
  final List<Widget> children;
  final Function(bool)? onBoundaryReached;

  const _CustomTabBarView({
    required this.controller,
    required this.children,
    this.onBoundaryReached,
  });

  @override
  State<_CustomTabBarView> createState() => _CustomTabBarViewState();
}

class _CustomTabBarViewState extends State<_CustomTabBarView> {
  late PageController _pageController;
  final bool _isExternalTabChange = false;

  // Track pointer events for edge swipes
  double _startX = 0;
  double _startY = 0;
  double _currentX = 0;
  double _currentY = 0;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.controller.index);

    // Listen to internal tab controller changes (sync with page)
    widget.controller.addListener(() {
      if (_isExternalTabChange) {
        return; // Avoid sync during external tab transition
      }

      final currentPage = _pageController.page?.round();
      final newIndex = widget.controller.index;

      if (_pageController.hasClients && currentPage != newIndex) {
        // Use jumpToPage for distant tabs to avoid scrolling through all intermediate tabs
        // Use animateToPage only for adjacent tabs (distance of 1)
        final distance = (currentPage! - newIndex).abs();
        if (distance > 1) {
          _pageController.jumpToPage(newIndex);
        } else {
          _pageController.animateToPage(
            newIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.ease,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        _startX = event.position.dx;
        _startY = event.position.dy;
        _currentX = _startX;
        _currentY = _startY;
        _isTracking = true;
      },
      onPointerMove: (PointerMoveEvent event) {
        if (_isTracking) {
          _currentX = event.position.dx;
          _currentY = event.position.dy;
        }
      },
      onPointerUp: (PointerUpEvent event) {
        if (!_isTracking) return;
        _isTracking = false;

        final deltaX = _currentX - _startX;
        final deltaY = _currentY - _startY;
        final currentPage = _pageController.page?.round() ?? 0;

        // Only process if horizontal movement is greater than vertical
        if (deltaX.abs() <= deltaY.abs()) return;

        // Minimum distance for edge swipe
        const minDistance = 50.0;

        // Right swipe from first tab (Open) -> notify parent to go to previous tab (Mutual Fund)
        if (deltaX > minDistance && currentPage == 0) {
          if (widget.onBoundaryReached != null) {
            widget
                .onBoundaryReached!(true); // true = previous tab (Mutual Fund)
          }
        }

        // Left swipe from last tab (My Bids) -> notify parent to go to next tab (Bond)
        if (deltaX < -minDistance &&
            currentPage == widget.children.length - 1) {
          if (widget.onBoundaryReached != null) {
            widget.onBoundaryReached!(false); // false = next tab (Bond)
          }
        }
      },
      onPointerCancel: (PointerCancelEvent event) {
        _isTracking = false;
      },
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.children.length,
        onPageChanged: (index) {
          // Jump directly to the tapped tab without animation
          widget.controller.animateTo(index);
        },
        itemBuilder: (context, index) => widget.children[index],
      ),
    );
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
