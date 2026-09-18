import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'dart:html' as html;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mynt_plus/screens/web/profile/pledge/pledge_unpledge_screen.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mynt_plus/models/marketwatch_model/market_watch_scrip_model.dart';
import 'package:mynt_plus/provider/auth_provider.dart';
import 'package:mynt_plus/provider/bonds_provider.dart';
import 'package:mynt_plus/provider/option_flash_provider.dart';
import 'package:mynt_plus/screens/web/mutual_fund/mf_explore_screens_web.dart';
import 'package:mynt_plus/screens/web/mutual_fund/mf_all_best_funds_web.dart';
import 'package:mynt_plus/screens/web/mutual_fund/mf_stock_detail_screen_web.dart';
import 'package:mynt_plus/models/mf_model/mutual_fundmodel.dart';
import 'package:mynt_plus/screens/web/mutual_fund/mf_top_category_list_web.dart';
import 'package:mynt_plus/screens/web/mutual_fund/sip_calculator_screen_web.dart';
import 'package:mynt_plus/screens/web/mutual_fund/cagr_calculator_screen_web.dart';
import 'package:mynt_plus/screens/web/bonds/bonds_main_screen_web.dart';
// import 'package:mynt_plus/screens/web/chart/web_chart_overlay.dart'; // Commented out - using panel chart only
import 'package:mynt_plus/screens/web/chart/inline_chart_portal.dart';
import 'package:mynt_plus/screens/web/option_flash/option_flash_panel.dart';
import 'package:mynt_plus/screens/web/ordersbook/order_book_screen_web.dart';
import 'package:mynt_plus/screens/web/funds/secure_fund_web.dart';
import 'package:mynt_plus/screens/web/profile/profile_main_screen.dart';
import 'package:mynt_plus/screens/web/profile/trading_preferences_screen_web.dart';
import 'package:mynt_plus/screens/web/profile/nominee_screen_web.dart';
import 'package:mynt_plus/screens/web/profile/form_download_screen_web.dart';
import 'package:mynt_plus/screens/web/profile/profile_details_screen_web.dart';
import 'package:mynt_plus/screens/web/profile/profile_section_screen_web.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_shell.dart';
import 'package:mynt_plus/screens/web/strategy_builder/strategy_builder_screen.dart';
import 'package:mynt_plus/screens/web/webhook/webhook_tradingview_screen.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../locator/constant.dart';
import '../../../locator/locator.dart';
import '../../../locator/preference.dart';
import '../../../provider/index_list_provider.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/network_state_provider.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/portfolio_provider.dart';
import '../../../provider/privacy_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/user_profile_provider.dart';
// import '../../../provider/version_provider.dart'; // mobile-only store check
import '../../../provider/websocket_provider.dart';
import '../../../provider/webview_chart_provider.dart';
import '../../../provider/iop_provider.dart';
import '../../../provider/fund_provider.dart';
import '../../../provider/ledger_provider.dart';
import '../../../provider/stocks_provider.dart';
import '../../../provider/mf_provider.dart';
import '../../../provider/web_subscription_manager.dart';
import '../../../provider/dashboard_provider.dart';
import 'sharedWidget/build_update_banner.dart';
import 'profile/Reports/ca_events_screen_web.dart';
import 'profile/Reports/corporate_actions/corporate_actions_screen_web.dart';
import 'profile/Reports/client_master_screen_web.dart';
import '../../../res/res.dart';
import '../../../provider/accessibility_provider.dart';
import '../../../provider/sidebar_provider.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/web_colors.dart';

import '../../../sharedWidget/accessibility/accessibility_panel.dart';
import '../../../sharedWidget/internet_widget.dart';
import '../../../sharedWidget/functions.dart';
import '../../../utils/responsive_snackbar.dart';
import '../../../utils/rupee_convert_format.dart';
// import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'profile/Reports/reports_screen_web.dart';
import 'profile/Reports/ledger/ledger_screen_web.dart';
import 'profile/Reports/contract_note_screen_web.dart';
import 'profile/Reports/tradebook_screen_web.dart';
import 'profile/Reports/calenderPnl_screen.dart';
import 'profile/Reports/pdf_download_screen_web.dart';
import 'profile/Reports/position_screen.dart';
import 'profile/Reports/tax_pnl_screen_web.dart';
import 'profile/Reports/notional_pnl_screen_web.dart';
import 'profile/notification_screens/notification_screen_web.dart';

// import 'profile/settings_web.dart';
import 'splitter_widget.dart';
// import '../Mobile/market_watch/tv_chart/webview_chart.dart';
import 'market_watch/watchlist_screen_web.dart';
import 'holdings/holding_screen_web.dart';
import 'position/position_screen_web.dart';
import 'dashboard_screen_web.dart';
import 'all_strategies_screen_web.dart';
import 'all_algo_strategies_screen_web.dart';
import 'trade_action_screen_web.dart';
import 'portfolio_analysis_web.dart';
// import '../Mobile/order_book/order_book_screen.dart';
import 'market_watch/options/option_chain_ss_web.dart';
// import '../Mobile/desk_reports/pledge_unpledge_screen.dart';
// Removed CA Event and CP Action from panel screens

import 'mutual_fund/mf_nfo_screen_web.dart';
import 'ipo/ipo_main_screen_web.dart';
import '../Mobile/bonds/bonds_main_screen.dart';
import '../../../utils/custom_navigator.dart';
import '../../../routes/route_names.dart';
import '../../../routes/web_router.dart';
import '../../models/marketwatch_model/get_quotes.dart';
import '../../models/scanner_model/scan_explain.dart' show ExplainKey;
import 'scanner/scanner_shell_screen.dart';
import 'orderflow/orderflow_shell_screen.dart';
import 'market_watch/chart_with_depth_web.dart';
// import 'market_watch/scrip_tabs_manager.dart';

import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../res/mynt_web_text_styles.dart';
import 'market_watch/index/index_bottom_sheet_web.dart';
import 'home/widgets/app_bar/profile_dropdown.dart';
import 'home/widgets/portfolio_summary_ticker_strip.dart';
import 'home/widgets/app_bar/navigation_drawer_web.dart';
import '../../../res/responsive_extensions.dart';
import 'scalper/scalper_screen_web.dart';
import 'chart_engine/widgets/workspace/chart_workspace_screen.dart';
import 'collection_basket/basketlist_dashboard_web.dart';
import 'collection_basket/create_baskerscreen_web.dart' as basket_create;
import 'collection_basket/collection_basket_builder.dart';
import 'collection_basket/benchmark_backtest_web.dart';
import 'collection_basket/save_strategy_screen_web.dart';
import 'profile/refer/refer_screen_web.dart';
import 'profile/help_support/help_support_screen_web.dart';
import 'market_watch/tv_chart/chart_iframe_guard.dart';
import '../../../sharedWidget/dynamic_banner_widget.dart';
import '../../../models/banner_model/banner_model.dart';
import '../../../provider/banner_provider.dart';
import '../../../provider/text_nugget_provider.dart';
import '../../../widgets/text_nugget_widget.dart';
import '../../../models/text_nugget_model/text_nugget_model.dart';

/// Global ValueNotifier for ticker visibility - reactive updates across the app
final tickerVisibilityNotifier = ValueNotifier<bool>(true);

/// Initialize ticker visibility from preferences
void initTickerVisibility() {
  final Preferences pref = locator<Preferences>();
  tickerVisibilityNotifier.value = pref.isTickerVisible;
}

/// Toggle ticker visibility and save to preferences
Future<void> toggleTickerVisibility() async {
  final Preferences pref = locator<Preferences>();
  final newValue = !tickerVisibilityNotifier.value;
  await pref.setTickerVisible(newValue);
  tickerVisibilityNotifier.value = newValue;
}

/// Global ValueNotifier for watchlist (market watch) panel visibility.
/// Reactive updates across the app so the split layout collapses/expands live.
final watchlistVisibilityNotifier = ValueNotifier<bool>(true);

/// Initialize watchlist visibility from preferences
void initWatchlistVisibility() {
  final Preferences pref = locator<Preferences>();
  watchlistVisibilityNotifier.value = pref.isWatchlistVisible;
}

/// Toggle watchlist visibility and save to preferences
Future<void> toggleWatchlistVisibility() async {
  final Preferences pref = locator<Preferences>();
  final newValue = !watchlistVisibilityNotifier.value;
  await pref.setWatchlistVisible(newValue);
  watchlistVisibilityNotifier.value = newValue;
}

/// Screen type parameter enum - used for URL routing
/// Maps to internal ScreenType enum
enum ScreenTypeParam {
  dashboard,
  watchlist,
  holdings,
  positions,
  orderBook,
  funds,
  mutualFund,
  ipo,
  bond,
  scalper,
  myAccount,
  refer,
  helpSupport,
  notification,
  pledgeUnpledge,
  optionChain,
  reports,
  settings,
  tradeAction,
  portfolioAnalysis,
  strategyBuilder,
  tradingViewWebHook,
  basketDashboard,
  createBasketStrategy,
  benchmarkBacktest,
  saveBasketStrategy,
  profileDetails,
  caBuyback,
  instaOptions,
  scanner,
  orderflow,
  charts
}

/// Sub-page within the Scanner shell — drives the top tab bar + IndexedStack.
/// Order MUST match the IndexedStack children list in ScannerShellScreen.
enum ScannerSubPage {
  // Legacy tabs — no longer surfaced in the top tab bar. Kept commented so
  // they can be re-enabled if the old flows need to come back.
  // symbols,
  // scanners,
  // fundamentals,
  customScans,
  fundamentalsNew,
  // Keep new values LAST — the shell's IndexedStack maps `.index` to child
  // order, so inserting mid-list would misroute the existing tabs.
  scannersNew,
  // technicals,  // removed — chip-based tech scanner retired.
}

class CustomizableSplitHomeScreen extends ConsumerStatefulWidget {
  /// Optional initial panel to show in the right panel on startup
  /// Used by GoRouter for URL-based navigation
  final ScreenTypeParam? initialRightPanel;

  /// Digilocker callback params (from /profile?code=xxx&state=yyy redirect)
  final String? digilockerCode;
  final String? digilockerState;

  /// Optional initial Scanner sub-page (used when arriving via /scanner/<sub>).
  final ScannerSubPage? initialScannerSubPage;

  /// Optional initial Scan-Explanation args (used when arriving via
  /// /scanner/explain/{builtin|custom}/{id}/{ticker}).
  final ExplainKey? initialExplainArgs;

  const CustomizableSplitHomeScreen({
    super.key,
    this.initialRightPanel,
    this.digilockerCode,
    this.digilockerState,
    this.initialScannerSubPage,
    this.initialExplainArgs,
  });

  @override
  ConsumerState<CustomizableSplitHomeScreen> createState() =>
      _CustomizableSplitHomeScreenState();
}

class _CustomizableSplitHomeScreenState
    extends ConsumerState<CustomizableSplitHomeScreen>
    with WidgetsBindingObserver {
  late WebSocketProvider socketProvider;

  // Panel management
  final List<PanelConfig> _panels = [];
  // Arguments storage for panel-specific screens that require constructor params
  DepthInputArgs? _optionChainArgs;
  DepthInputArgs? _currentDepthArgs;
  String? _currentCollectionTitle; // Title for MF Collection screen
  String? _currentCollectionSubtitle; // Subtitle for MF Collection screen
  String? _currentCollectionIcon; // Icon for MF Collection screen
  String? _currentCategoryTitle; // Title for MF Category screen
  String? _currentCategorySubtitle; // Subtitle for MF Category screen
  String? _currentCategoryIcon; // Icon for MF Category screen
  MutualFundList? _currentMfStockData; // Data for MF Stock Detail screen
  final int _panelCount = 2; // Fixed to 2 panels
  bool _isInitialLoad = true; // Track if this is the initial load
  int _holdingsInitialTabIndex = 0; // Track initial tab for holdings screen
  // Bumped on every navigation into Holdings so the screen honours the
  // requested tab even when it is already open on another one.
  int _holdingsTabRequestId = 0;
  bool _isScalperMode = false; // When true, hides watchlist and shows scalper full-width
  bool _isChartsMode = false; // When true, hides watchlist body and shows chart workspace full-width with slim index strip on left

  // Scaffold key for drawer control
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Accessibility dropdown anchor + overlay
  final GlobalKey _a11yAnchorKey = GlobalKey();
  OverlayEntry? _a11yOverlay;

  // Measures the watchlist index-strip height so the absolutely-positioned
  // collapse toggle can center itself on the indices/search seam.
  final GlobalKey _watchlistIndexStripKey = GlobalKey();
  double _watchlistIndexStripHeight = 64;

  /// Breakpoint below which hamburger menu is shown
  static const double _mobileBreakpoint = 1200.0;

  /// Check if a screen is active in any panel (for drawer highlighting)
  bool _isScreenActiveInAnyPanel(String screenName) {
    // Map screen names to ScreenType
    final screenTypeMap = {
      'dashboard': ScreenType.dashboard,
      'positions': ScreenType.positions,
      'holdings': ScreenType.holdings,
      'orderBook': ScreenType.orderBook,
      'funds': ScreenType.funds,
      'ipo': ScreenType.ipo,
      'mutualFund': ScreenType.mutualFund,
      'tradeAction': ScreenType.tradeAction,
      'watchlist': ScreenType.watchlist,
    };

    final targetScreenType = screenTypeMap[screenName];
    if (targetScreenType == null) return false;

    for (final panel in _panels) {
      if (panel.screenType == targetScreenType) return true;
      if (panel.screens.isNotEmpty &&
          panel.activeScreenIndex >= 0 &&
          panel.activeScreenIndex < panel.screens.length &&
          panel.screens[panel.activeScreenIndex] == targetScreenType) {
        return true;
      }
    }
    return false;
  }

  // Disable all chart iframes to prevent cursor bleed when dropdown is open
  void _disableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'none';
          iframe.style.cursor = 'default';
        }
      }
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

  String? _fundsInitialAction; // Track initial action for funds screen

  // Track loading states for each screen type
  final Map<ScreenType, bool> _screenLoadingStates = {};

  // Store initial tab index for trade action screen
  int? _tradeActionTabIndex;

  // Track previous screens for each panel (for back navigation) - using a stack
  final Map<int, List<ScreenType>> _panelScreenHistory = {};

  // Cooldown for portfolio data fetching to prevent excessive API calls
  DateTime? _lastPortfolioFetch;
  static const _portfolioFetchCooldown = Duration(seconds: 30);

  // Track WebSocket connection state for snackbar notifications
  bool _wasDisconnected = false;
  bool _showedDisconnectSnackbar = false;
  bool _hasConnectedOnce = false; // Track if we've had first successful connection

  // Track ongoing API requests to prevent duplicate calls when user rapidly clicks the same screen
  // Key: screen identifier (e.g., 'holdings', 'positions')
  // This prevents duplicate API calls if user clicks the same screen multiple times rapidly
  // But allows fresh data fetch every time user switches between different screens
  final Set<String> _ongoingRequests = {};

  // Helper to check if a request is already in progress
  bool _isRequestInProgress(String requestKey) {
    return _ongoingRequests.contains(requestKey);
  }

  // Helper to mark request as started
  void _markRequestStarted(String requestKey) {
    _ongoingRequests.add(requestKey);
  }

  // Helper to mark request as completed
  void _markRequestCompleted(String requestKey) {
    _ongoingRequests.remove(requestKey);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize ticker visibility from preferences
    initTickerVisibility();

    // Initialize watchlist visibility from preferences
    initWatchlistVisibility();

    // Initialize with default panels
    _initializeDefaultPanels();

    // Register scaffold key for sidebar
    ref.read(sidebarProvider.notifier).setScaffoldKey(_scaffoldKey);

    // Set up callback for showing scrip depth info in panel
    ref
        .read(marketWatchProvider)
        .setOnShowScripDepthInfoInPanel(showScripDepthInfoInPanel);

    // Load saved layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedLayout();

      // Check session validity and load data on page refresh
      // This handles the case when user refreshes on /holdings, /positions, etc.
      _validateSessionAndLoadData();

      // Load banners and text nuggets
      ref.read(bannerProvider.notifier).loadBanners();
      ref.read(textNuggetProvider).loadTextNuggets();

      // Ensure index data is loaded (may not be loaded if session was restored)
      final indexProvider = ref.read(indexListProvider);
      if (indexProvider.defaultIndexList == null ||
          indexProvider.defaultIndexList?.indValues == null ||
          indexProvider.defaultIndexList!.indValues!.isEmpty) {
        indexProvider.getDeafultIndexList(context);
      }

      // Panels already initialized with defaults in initState(), no need to call _addDefaultScreens()
      // Mark initial load as complete and initialize default screens immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _isInitialLoad = false;
          // Initialize the default screens
          _initializeDefaultScreenData();

          // Apply initial panel from URL routing (GoRouter)
          _applyInitialRightPanel();
        }
      });

      // Initialize WebNavigationHelper for web navigation
      WebNavigationHelper.initialize(
        navigatorKey: GlobalKey<NavigatorState>(),
        navigateToScreen: (routeName, {arguments}) {
          if (routeName == "orderBook") {
            showOrderBookInPanel();
          } else if (routeName == "optionChain") {
            if (arguments is DepthInputArgs) {
              showOptionChainInPanel(arguments);
            }
          } else if (routeName == "pledgeAndUnpledge") {
            _handlePledgeUnpledgeTap();
          } else if (routeName == "corporateActions") {
            _handleCorporateActionsTap();
          } else if (routeName == "reports") {
            _handleReportsTap();
          } else if (routeName == "settings") {
            _handleSettingsTap();
          } else if (routeName == Routes.tradeActionScreen ||
              routeName == "tradeActionScreen") {
            final tabIndex = arguments is int ? arguments : null;
            showTradeActionInPanel(tabIndex: tabIndex);
            // caEvent and cpAction removed from panel navigation
          } else if (routeName == Routes.holdingscreen ||
              routeName == "HoldingScreen") {
            _handleHoldingsTap(
                initialTabIndex: arguments is int ? arguments : 0);
          } else if (routeName == Routes.mfmainscreen ||
              routeName == "mfMainScreen") {
            // Mutual Fund is the demat-backed tab at index 3; index 2 is the
            // retired MF tab, which renders no chip and no table.
            _handleHoldingsTap(initialTabIndex: 3);
          } else if (routeName == Routes.positionscreen ||
              routeName == "PositionScreen") {
            _handlePositionsTap();
          } else if (routeName == Routes.orderBook ||
              routeName == "orderBook") {
            showOrderBookInPanel();
          } else if (routeName == Routes.fundscreen ||
              routeName == "fundscreen") {
            _handleFundsTap(
                initialAction: arguments is String ? arguments : null);
          } else if (routeName == Routes.ipo ||
              routeName == "Ipo" ||
              routeName == "ipo") {
            _handleIPOTap();
          } else if (routeName == Routes.portfolioDashboard ||
              routeName == "portfolioAnalysis" ||
              routeName == "portfolioDashboard") {
            _handlePortfolioAnalysisTap();
          } else if (routeName == Routes.strategyBuilder ||
              routeName == "strategyBuilder") {
            _handleStrategyBuilderTap();
          } else if (routeName == Routes.scalperScreen ||
              routeName == "scalper") {
            _handleScalperTap();
          } else if (routeName == "charts") {
            _handleChartsTap();
          } else if (routeName == "tradingViewWebHook") {
            _handleWebHookTap();
          } else if (routeName == "mutualFund") {
            _handleMutualFundTap();
          } else if (routeName == "basketDashboard" ||
              routeName == Routes.basketScreen) {
            _handleBasketDashboardTap();
          } else if (routeName == Routes.createBasketStrategy ||
              routeName == "createBasketStrategy") {
            _replaceScreenInPanel(ScreenType.createBasketStrategy);
          } else if (routeName == Routes.benchmarkBacktestAnalysis ||
              routeName == "benchmarkBacktest") {
            _replaceScreenInPanel(ScreenType.benchmarkBacktest);
          } else if (routeName == Routes.saveStrategyScreen ||
              routeName == "saveBasketStrategy") {
            _replaceScreenInPanel(ScreenType.saveBasketStrategy);
          } else if (routeName == "refer") {
            _replaceScreenInPanel(ScreenType.refer);
          } else if (routeName == "mtfDetails") {
            _navigateToScreen(ScreenType.mtfDetails);
          } else if (routeName == "myAccount") {
            _navigateToScreen(ScreenType.myAccount);
          } else if (routeName == Routes.curatedStrategies ||
              routeName == "curatedStrategies") {
            _handleCuratedStrategiesTap();
          } else if (routeName == Routes.algoStrategies ||
              routeName == "algoStrategies") {
            _handleAlgoStrategiesTap();
          }
        },
        replaceScreen: (routeName, {arguments}) {
          if (routeName == "orderBook") {
            showOrderBookInPanel();
          } else if (routeName == "optionChain") {
            if (arguments is DepthInputArgs) {
              showOptionChainInPanel(arguments);
            }
          } else if (routeName == "pledgeAndUnpledge") {
            _handlePledgeUnpledgeTap();
          } else if (routeName == "corporateActions") {
            _handleCorporateActionsTap();
          } else if (routeName == "reports") {
            _handleReportsTap();
          } else if (routeName == "settings") {
            _handleSettingsTap();
          } else if (routeName == Routes.tradeActionScreen ||
              routeName == "tradeActionScreen") {
            final tabIndex = arguments is int ? arguments : null;
            showTradeActionInPanel(tabIndex: tabIndex);
            // caEvent and cpAction removed from panel navigation
          } else if (routeName == Routes.holdingscreen ||
              routeName == "HoldingScreen") {
            _handleHoldingsTap(
                initialTabIndex: arguments is int ? arguments : 0);
          } else if (routeName == Routes.mfmainscreen ||
              routeName == "mfMainScreen") {
            // Mutual Fund is the demat-backed tab at index 3; index 2 is the
            // retired MF tab, which renders no chip and no table.
            _handleHoldingsTap(initialTabIndex: 3);
          } else if (routeName == Routes.positionscreen ||
              routeName == "PositionScreen") {
            _handlePositionsTap();
          } else if (routeName == Routes.orderBook ||
              routeName == "orderBook") {
            showOrderBookInPanel();
          } else if (routeName == Routes.fundscreen ||
              routeName == "fundscreen") {
            _handleFundsTap(
                initialAction: arguments is String ? arguments : null);
          } else if (routeName == Routes.ipo ||
              routeName == "Ipo" ||
              routeName == "ipo") {
            _handleIPOTap();
          } else if (routeName == Routes.portfolioDashboard ||
              routeName == "portfolioAnalysis" ||
              routeName == "portfolioDashboard") {
            _handlePortfolioAnalysisTap();
          } else if (routeName == Routes.strategyBuilder ||
              routeName == "strategyBuilder") {
            _handleStrategyBuilderTap();
          } else if (routeName == Routes.scalperScreen ||
              routeName == "scalper") {
            _handleScalperTap();
          } else if (routeName == "charts") {
            _handleChartsTap();
          } else if (routeName == "tradingViewWebHook") {
            _handleWebHookTap();
          } else if (routeName == "mutualFund") {
            _handleMutualFundTap();
          } else if (routeName == "basketDashboard" ||
              routeName == Routes.basketScreen) {
            _handleBasketDashboardTap();
          } else if (routeName == Routes.createBasketStrategy ||
              routeName == "createBasketStrategy") {
            _replaceScreenInPanel(ScreenType.createBasketStrategy);
          } else if (routeName == Routes.benchmarkBacktestAnalysis ||
              routeName == "benchmarkBacktest") {
            _replaceScreenInPanel(ScreenType.benchmarkBacktest);
          } else if (routeName == Routes.saveStrategyScreen ||
              routeName == "saveBasketStrategy") {
            _replaceScreenInPanel(ScreenType.saveBasketStrategy);
          } else if (routeName == "refer") {
            _replaceScreenInPanel(ScreenType.refer);
          } else if (routeName == "mtfDetails") {
            _navigateToScreen(ScreenType.mtfDetails);
          } else if (routeName == "myAccount") {
            _navigateToScreen(ScreenType.myAccount);
          } else if (routeName == Routes.curatedStrategies ||
              routeName == "curatedStrategies") {
            _handleCuratedStrategiesTap();
          } else if (routeName == Routes.algoStrategies ||
              routeName == "algoStrategies") {
            _handleAlgoStrategiesTap();
          }
        },
        goBack: () {
          // Handle back navigation if needed
        },
      );

      // Set up browser back/forward navigation handler
      WebNavigationHelper.setOnBrowserNavigation((String urlPath) {
        _handleBrowserNavigation(urlPath);
      });
    });

    ref.read(networkStateProvider).networkStream();
    ref.read(marketWatchProvider).fToast.init(context);
    // Store-version check is mobile-only (compares against the strapi
    // Play Store number); on web the build-update banner covers updates.
    // ref.read(versionProvider).checkVersion(context);

    // Initialize websocket connection early to ensure real-time data is available
    if (mounted &&
        ref.read(networkStateProvider).connectionStatus !=
            ConnectivityResult.none) {
      _handleWebSocketConnections();
    }

    // Update subscription manager context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(webSubscriptionManagerProvider).updateContext(context);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    socketProvider = ref.read(websocketProvider);

    // Update subscription manager context whenever dependencies change
    ref.read(webSubscriptionManagerProvider).updateContext(context);
  }

  @override
  void dispose() {
    _subscriptionUpdateDebounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (ConstantName.timer != null) {
      ConstantName.timer!.cancel();
      ConstantName.timer = null;
    }
    _a11yOverlay?.remove();
    _a11yOverlay = null;
    socketProvider.closeSocket(false);
    ConstantName.chartwebViewController?.dispose();
    super.dispose();
  }

  void _initializeDefaultPanels() {
    _createPanelsForCount(_panelCount);
  }

  /// Validate session and load data on page refresh/direct URL access
  /// This handles the case when user refreshes on /holdings, /positions, etc.
  /// Without this, the app would show empty data on refresh
  Future<void> _validateSessionAndLoadData() async {
    if (!mounted) return;

    final pref = locator<Preferences>();
    final session = pref.clientSession;
    final clientId = pref.clientId;

    // Check if session exists
    if (session == null || session.isEmpty || clientId == null || clientId.isEmpty) {
      // No session - redirect to login
      if (mounted) {
        context.go(WebRoutes.login);
      }
      return;
    }

    // Check if data is already being loaded (from login flow)
    // This prevents duplicate initialLoadMethods calls
    final auth = ref.read(authProvider);
    if (auth.initLoad) {
      return;
    }

    // Check if data is already loaded (session was validated)
    // indexListProvider.checkSess is set after session validation in initialLoadMethods
    final indexProvider = ref.read(indexListProvider);
    if (indexProvider.checkSess != null && indexProvider.checkSess!.stat == "Ok") {
      return;
    }

    // Session exists but data not loaded - this is a page refresh scenario
    // Call initialLoadMethods to load all essential data
    if (mounted) {
      await ref.read(authProvider).initialLoadMethods(context, "");
    }
  }

  /// Apply the initial right panel from URL routing (GoRouter)
  /// This is called after panels are initialized to show the correct screen
  /// based on the URL path (e.g., /holdings, /orders, /positions)
  void _applyInitialRightPanel() {
    final initialPanel = widget.initialRightPanel;
    if (initialPanel == null) return;


    // Map ScreenTypeParam to the appropriate handler
    switch (initialPanel) {
      case ScreenTypeParam.holdings:
        _handleHoldingsTap(initialTabIndex: 0);
        break;
      case ScreenTypeParam.positions:
        _handlePositionsTap();
        break;
      case ScreenTypeParam.orderBook:
        showOrderBookInPanel();
        break;
      case ScreenTypeParam.funds:
        _handleFundsTap();
        break;
      case ScreenTypeParam.optionChain:
        // Option chain requires arguments, show default if none provided
        _replaceScreenInPanel(ScreenType.optionChain);
        break;
      case ScreenTypeParam.ipo:
        _handleIPOTap();
        break;
      case ScreenTypeParam.bond:
        _handleBondTap();
        break;
      case ScreenTypeParam.scalper:
        _handleScalperTap();
        break;
      case ScreenTypeParam.charts:
        _handleChartsTap();
        break;
      case ScreenTypeParam.myAccount:
        _navigateToScreen(ScreenType.myAccount);
        break;
      case ScreenTypeParam.refer:
        _navigateToScreen(ScreenType.refer);
        break;
      case ScreenTypeParam.helpSupport:
        _navigateToScreen(ScreenType.helpSupport);
        break;
      case ScreenTypeParam.notification:
        _navigateToScreen(ScreenType.notification);
        break;
      case ScreenTypeParam.pledgeUnpledge:
        _navigateToScreen(ScreenType.pledgeUnpledge);
        break;
      case ScreenTypeParam.mutualFund:
        _handleMutualFundTap();
        break;
      case ScreenTypeParam.reports:
        _handleReportsTap();
        break;
      case ScreenTypeParam.settings:
        _handleSettingsTap();
        break;
      case ScreenTypeParam.tradeAction:
        showTradeActionInPanel();
        break;
      case ScreenTypeParam.portfolioAnalysis:
        _handlePortfolioAnalysisTap();
        break;
      case ScreenTypeParam.strategyBuilder:
        _handleStrategyBuilderTap();
        break;
      case ScreenTypeParam.tradingViewWebHook:
        _handleWebHookTap();
        break;
      case ScreenTypeParam.basketDashboard:
        _handleBasketDashboardTap();
        break;
      case ScreenTypeParam.createBasketStrategy:
        _replaceScreenInPanel(ScreenType.createBasketStrategy);
        break;
      case ScreenTypeParam.benchmarkBacktest:
        _replaceScreenInPanel(ScreenType.benchmarkBacktest);
        break;
      case ScreenTypeParam.saveBasketStrategy:
        _replaceScreenInPanel(ScreenType.saveBasketStrategy);
        break;
      case ScreenTypeParam.profileDetails:
        _replaceScreenInPanel(ScreenType.profileDetails);
        break;
      case ScreenTypeParam.caBuyback:
        _handleCABuybackTap();
        break;
      case ScreenTypeParam.instaOptions:
        _handleInstaOptionsTap();
        break;
      case ScreenTypeParam.scanner:
        _replaceScreenInPanel(ScreenType.scanner);
        break;
      case ScreenTypeParam.orderflow:
        _replaceScreenInPanel(ScreenType.orderflow);
        break;
      case ScreenTypeParam.dashboard:
      case ScreenTypeParam.watchlist:
        // Default panels, no action needed
        break;
    }
  }

  void _createPanelsForCount(int count) {
    // Store existing screens before clearing
    List<ScreenType?> existingScreens = [];
    for (int i = 0; i < _panels.length; i++) {
      existingScreens.add(_panels[i].screenType);
    }

    _panels.clear();
    for (int i = 0; i < count; i++) {
      // Preserve existing screen if available, otherwise use default for each panel
      ScreenType? screenType;
      if (i < existingScreens.length && existingScreens[i] != null) {
        screenType = existingScreens[i];
      } else {
        // Set default screens: panel 0 = watchlist (left), panel 1 = dashboard (right)
        if (i == 0) {
          screenType = ScreenType.watchlist;
        } else if (i == 1) {
          screenType = ScreenType.dashboard;
        }
      }

      _panels.add(
        PanelConfig(
          id: 'panel_${i + 1}',
          screenType: screenType,
          screens: screenType != null ? [screenType] : [],
          activeScreenIndex: 0,
          width: 1.0, // Equal width for all panels
          height: 1.0, // Equal height for all panels
          isVisible: true,
          minWidth: 150.0,
          minHeight: 150.0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          currentWidth: 0.0, // Will be set when layout is built
          currentHeight: 0.0, // Will be set when layout is built
          enableHorizontalResize: true,
          enableVerticalResize: true,
        ),
      );
    }
  }

  Future<void> _loadSavedLayout() async {
    // Panels are already initialized with defaults in initState()
    // No need to reinitialize here - this ensures no flickering on first render
  }

  Future<void> _saveLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final layoutData = {
        'panelCount': _panelCount,
        'panels': _panels.map((p) => p.toJson()).toList(),
      };
      await prefs.setString('custom_split_layout', jsonEncode(layoutData));
    } catch (e) {
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Helper function to check if portfolio screens are active
    bool hasPortfolioScreen() {
      for (var panel in _panels) {
        if (panel.screenType == ScreenType.positions ||
            panel.screenType == ScreenType.holdings ||
            panel.screenType == ScreenType.orderBook ||
            panel.screenType == ScreenType.funds) {
          return true;
        }
      }
      return false;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        // Update subscription manager context on resume
        ref.read(webSubscriptionManagerProvider).updateContext(context);

        // Only fetch portfolio data if cooldown period has passed
        final now = DateTime.now();
        final shouldFetchPortfolio = hasPortfolioScreen() &&
            (_lastPortfolioFetch == null ||
                now.difference(_lastPortfolioFetch!) > _portfolioFetchCooldown);

        Future.microtask(() async {
          try {
            // Session validation removed - APIs return "Session Expired" errors
            // which are handled by ifSessionExpired(). This avoids unnecessary
            // DeleteMultiMWScrips API calls on every lifecycle resume.
            if (mounted && shouldFetchPortfolio) {
              // Only fetch data for ACTIVE screens (smart fetching)
              _lastPortfolioFetch = now;

              final futures = <Future>[];

              // Check each panel and only fetch data for active screens
              for (var panel in _panels) {
                if (panel.screenType == ScreenType.positions) {
                  futures.add(ref
                      .read(portfolioProvider)
                      .fetchPositionBook(context, false));
                } else if (panel.screenType == ScreenType.holdings) {
                  futures.add(
                      ref.read(portfolioProvider).fetchHoldings(context, ""));
                } else if (panel.screenType == ScreenType.orderBook) {
                  futures.add(
                      ref.read(orderProvider).fetchOrderBook(context, false));
                  // Note: Trade Book and SIP are lazy loaded, only fetch if already loaded
                  if (ref.read(orderProvider).tradeBook != null &&
                      ref.read(orderProvider).tradeBook!.isNotEmpty) {
                    futures
                        .add(ref.read(orderProvider).fetchTradeBook(context));
                  }
                }
              }

              if (futures.isNotEmpty) {
                await Future.wait(futures);
              }

              if (mounted) {
                setState(() {});
              }
            } else if (!shouldFetchPortfolio) {
            }
            _handleWebSocketConnections();
          } catch (e) {
          }
        });
        _handleChartData();
        if (mounted) {
          setState(() {});
        }
        break;
      case AppLifecycleState.inactive:
        if (hasPortfolioScreen()) {
          ref.read(portfolioProvider).cancelTimer();
        }
        final userProfile = ref.read(userProfileProvider);
        userProfile.setonloadChartdialog(false);
        break;
      case AppLifecycleState.paused:
        if (hasPortfolioScreen()) {
          ref.read(portfolioProvider).cancelTimer();
        }
        break;
      case AppLifecycleState.detached:
        if (hasPortfolioScreen()) {
          ref.read(portfolioProvider).cancelTimer();
        }
        final userProfile = ref.read(userProfileProvider);
        userProfile.setonloadChartdialog(false);
        break;
      case AppLifecycleState.hidden:
        if (hasPortfolioScreen()) {
          ref.read(portfolioProvider).cancelTimer();
        }
    }
  }

  void _handleWebSocketConnections() {
    if (!mounted) return;

    final websocket = ref.read(websocketProvider);

    if (websocket.connectioncount >= 5) {
      websocket.changeconnectioncount();
    }

    // Establish base WebSocket connection if not connected
    // Note: Subscriptions are now handled by WebSubscriptionManager
    if (!websocket.wsConnected) {
      // ALWAYS establish base connection first, even without symbols
      // This ensures WebSocket is connected before any subscriptions
      // Previously, if lastSubscribe was empty, connection was never established!
      websocket.establishConnection(
          channelInput: "",
          task: "c",
          context: context);
    }

    // Note: Removed direct subscription calls (requestMWScrip, requestWSHoldings, etc.)
    // WebSubscriptionManager now handles all screen-specific subscriptions
    // This prevents double subscriptions when screens are active
    if (ref.read(networkStateProvider).connectionStatus !=
        ConnectivityResult.none) {
      // WebSubscriptionManager will handle subscriptions based on active screens
      // Just ensure it's updated with current panel states
      _updateSubscriptionManagerForPanels();
    }
  }

  void _handleChartData() {
    if (!mounted) return;

    final userProfile = ref.read(userProfileProvider);
    final scriptInfo = ref.read(marketWatchProvider).getQuotes;

    if (userProfile.showchartof && scriptInfo?.exch != null) {
      ref.read(marketWatchProvider).setChartScript(scriptInfo!.exch.toString(),
          scriptInfo.token.toString(), scriptInfo.tsym.toString());
    } else if (userProfile.showchartof) {
      userProfile.setChartdialog(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set context for WebNavigationHelper to enable URL updates
    WebNavigationHelper.setContext(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        bool shouldExit = await showExitPopup();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            _buildMainScaffold(),
            // const WebChartOverlay(), // Commented out - using panel chart only
            const InlineChartPortal(), // Persistent chart that follows ChartWithDepthWeb's target
            const OptionFlashPanel(),
            const DynamicBannerWidget(
              screenType: BannerScreenType.homescreen,
              showImmediately: true,
            ),
            // Floating "new build available" pill, top-center above all panes
            const BuildUpdateBanner(),
            // DEBUG: Screen size overlay — remove after testing
            // Positioned(
            //   bottom: 8,
            //   right: 8,
            //   child: Builder(
            //     builder: (context) {
            //       final size = MediaQuery.of(context).size;
            //       return Container(
            //         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            //         decoration: BoxDecoration(
            //           color: Colors.black87,
            //           borderRadius: BorderRadius.circular(6),
            //         ),
            //         child: Text(
            //           '${size.width.toStringAsFixed(0)} × ${size.height.toStringAsFixed(0)}',
            //           style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            //         ),
            //       );
            //     },
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainScaffold() {
    return Consumer(
      builder: (context, ref, _) {
        final internet = ref.watch(networkStateProvider);
        // PERFORMANCE FIX: Use .select() to only watch connection status fields
        // Before: ref.watch(websocketProvider) - ENTIRE provider caused rebuilds every 500ms!
        // After: Only rebuild when connection status actually changes
        final connectionCount =
            ref.watch(websocketProvider.select((p) => p.connectioncount));
        final reconnectionSuccess =
            ref.watch(websocketProvider.select((p) => p.reconnectionSuccess));
        final wsConnected =
            ref.watch(websocketProvider.select((p) => p.wsConnected));
        final retryscreen =
            ref.watch(websocketProvider.select((p) => p.retryscreen));

        // WEB: Silent auto-reconnect with snackbar notifications instead of blocking overlay
        // Track disconnection state for snackbar notifications
        final isTabSwitchReconnect =
            ref.watch(websocketProvider.select((p) => p.isTabSwitchReconnect));
        final isDisconnected = (internet.connectionStatus == ConnectivityResult.none ||
                connectionCount >= 5) &&
            !reconnectionSuccess &&
            !wsConnected;

        if (isDisconnected && !_wasDisconnected) {
          // Just became disconnected - show snackbar and auto-reconnect
          // Skip toasts if this is an intentional tab-switch reconnect
          _wasDisconnected = true;
          _showedDisconnectSnackbar = false;
          if (!isTabSwitchReconnect) {
            Future.microtask(() {
              if (mounted && !_showedDisconnectSnackbar) {
                _showedDisconnectSnackbar = true;
                ResponsiveSnackBar.showWarning(
                  context,
                  'Connection lost. Reconnecting...',
                  duration: const Duration(seconds: 3),
                );
                // Trigger auto-reconnect
                ref.read(networkStateProvider).getContext(context);
                _handleWebSocketConnections();
              }
            });
          }
        } else if (!isDisconnected && _wasDisconnected) {
          // Just reconnected - show success snackbar and refresh data
          final wasActualReconnection = _hasConnectedOnce; // Only refresh if this is a real reconnection
          _wasDisconnected = false;
          _showedDisconnectSnackbar = false;
          _hasConnectedOnce = true; // Mark that we've connected at least once
          Future.microtask(() {
            if (mounted) {
              if (!isTabSwitchReconnect) {
                ResponsiveSnackBar.showSuccess(
                  context,
                  'Connected successfully',
                  duration: const Duration(seconds: 2),
                );
              }
              // Only refresh data after actual reconnection, not initial connection
              if (wasActualReconnection) {
                _refreshDataAfterReconnection();
              }
            }
          });
        } else if (!isDisconnected && !_hasConnectedOnce) {
          // First successful connection (not a reconnection)
          _hasConnectedOnce = true;
        }

        // Auto-reconnect when network is available but websocket disconnected
        if (internet.connectionStatus != ConnectivityResult.none &&
            !wsConnected &&
            retryscreen) {
          Future.microtask(() {
            if (mounted) {
              _handleWebSocketConnections();
              ref.read(websocketProvider).changeretryscreen(false);
              _handleReconnectionSuccess();
            }
          });
        }

        final theme = ref.watch(themeProvider);

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: resolveThemeColor(context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          drawerScrimColor: Colors.transparent, // Disable grey overlay
          endDrawer: Consumer(
            builder: (context, ref, _) {
              final sidebarContent = ref.watch(sidebarProvider);
              if (sidebarContent == null) return const SizedBox.shrink();
              // Width comes from whatever opened the panel. A conversation
              // needs more room than a column of label/value rows, and the
              // default is unchanged for everything that does not ask.
              final width = ref.read(sidebarProvider.notifier).width;
              return Drawer(
                width: width,
                backgroundColor: resolveThemeColor(context,
                    dark: MyntColors.cardDark, light: MyntColors.card),
                // The scrim is transparent on purpose, so the page behind stays
                // readable — which leaves nothing saying the panel sits above
                // it. A shadow and a left edge do that job instead, and work
                // whatever colour happens to be behind.
                elevation: 16,
                shadowColor: Colors.black.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                  side: BorderSide(
                    color: resolveThemeColor(context,
                        dark: MyntColors.borderMutedDark,
                        light: MyntColors.borderMuted),
                  ),
                ),
                child: sidebarContent,
              );
            },
          ),
          body: Column(
            children: [
              // _buildOldVersionBanner(),
              Expanded(child: _buildNewLayout(theme)),
            ],
          ),
        );
      },
    );
  }

  /// Banner to navigate to the old version of the app
  Widget _buildOldVersionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: const Color(0xFF1A1D21),
            light: const Color(0xFFF5F7FA)),
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: const Color(0xFF2A2D31),
                light: const Color(0xFFE8ECF0)),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          InkWell(
            onTap: () {
              html.window.open('https://zebu-feuat.web.app', '_blank');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mynt by Zebu Web — Old Version is Here!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary,)
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  /// Refresh data after WebSocket reconnection to avoid showing stale/zero data
  void _refreshDataAfterReconnection() {
    if (!mounted) return;


    // Refresh portfolio data (holdings, positions)
    final portfolio = ref.read(portfolioProvider);
    portfolio.fetchPositionBook(context, portfolio.isDay).then((_) {
      // After positions are fetched, refresh ticker subscriptions
      if (mounted) {
        final subscriptionManager = ref.read(webSubscriptionManagerProvider);
        subscriptionManager.refreshTickerSubscriptions(context);
      }
    });
    portfolio.fetchHoldings(context, "");

    // Refresh order book data
    final orders = ref.read(orderProvider);
    orders.fetchOrderBook(context, true); // websocCon = true since we're reconnecting

    // Refresh fund data
    final fund = ref.read(fundProvider);
    fund.fetchFunds(context);

    // Re-establish WebSocket subscriptions for active screens
    _updateSubscriptionManagerForPanels(forceRefresh: true);

    // Trigger UI refresh
    _handleReconnectionSuccess();
  }

  /// True when any panel currently shows the Scanner shell — the Scanner
  /// page renders full-width with no watchlist (same pattern as Scalper).
  bool get _isScannerActive {
    for (final panel in _panels) {
      if (panel.screenType == ScreenType.scanner) return true;
      if (panel.screens.isNotEmpty &&
          panel.activeScreenIndex >= 0 &&
          panel.activeScreenIndex < panel.screens.length &&
          panel.screens[panel.activeScreenIndex] == ScreenType.scanner) {
        return true;
      }
    }
    return false;
  }

  /// New layout: Watchlist full height on one side, AppBar + Content on other side
  /// Respects panel swap - checks which panel has watchlist
  /// In scalper mode: hides watchlist, shows AppBar + Scalper content full-width
  /// In scanner mode: hides watchlist, shows AppBar + Scanner shell full-width
  Widget _buildNewLayout(ThemesProvider theme) {
    // Scalper mode: full-width AppBar + Scalper content, no watchlist
    if (_isScalperMode) {
      return Column(
        children: [
          _buildRightSideAppBar(theme.isDarkMode),
          const Expanded(
            child: ScalperScreenWeb(embedded: true),
          ),
        ],
      );
    }

    // Scanner mode: full-width AppBar + Scanner shell, no watchlist
    if (_isScannerActive) {
      return Column(
        children: [
          _buildRightSideAppBar(theme.isDarkMode),
          Expanded(
            child: ScannerShellScreen(
              initialSubPage: widget.initialScannerSubPage,
              initialExplainArgs: widget.initialExplainArgs,
            ),
          ),
        ],
      );
    }

    // Charts mode: full-width chart workspace. Top app bar carries an indices strip
    // alongside the live-P&L ticker so we recover the watchlist column's space.
    // ChartWorkspaceScreen hosts its own right-tray (Watchlist/Positions/Holdings/Orders/DOM).
    if (_isChartsMode) {
      return Column(
        children: [
          _buildRightSideAppBar(theme.isDarkMode),
          Container(
            color: resolveThemeColor(context,
                dark: MyntColors.backgroundColorDark,
                light: MyntColors.backgroundColor),
            child: Row(
              children: [
                SizedBox(
                  width: 320,
                  child: _buildWatchlistIndexSlots(theme.isDarkMode),
                ),
                Container(
                    width: 1,
                    color: shadcn.Theme.of(context).colorScheme.border),
                // Old auto-scrolling position ticker:
                const Expanded(child: PortfolioTickerStrip()),
                // const Expanded(child: PortfolioSummaryTickerStrip()),
              ],
            ),
          ),
          const Expanded(child: ChartWorkspaceScreen()),
        ],
      );
    }

    // Calculate watchlist width (25% of screen)
    final screenWidth = MediaQuery.of(context).size.width;
    const double watchlistRatio = 0.25;
    final watchlistWidth = screenWidth * watchlistRatio;

    // Check if watchlist is in first panel (left) or second panel (right)
    bool watchlistOnLeft = _isWatchlistInPanel(0);
    bool watchlistOnRight = _isWatchlistInPanel(1);

    // Default: watchlist on left if not found in any panel
    if (!watchlistOnLeft && !watchlistOnRight) {
      watchlistOnLeft = true;
    }

    if (watchlistOnLeft) {
      // Watchlist on LEFT, Content on RIGHT
      return Row(
        children: [
          // Left side: Watchlist (full height) — collapsible to a thin rail
          ValueListenableBuilder<bool>(
            valueListenable: watchlistVisibilityNotifier,
            builder: (context, visible, _) {
              if (!visible) {
                return _buildWatchlistCollapsedRail(theme, onLeft: true);
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: watchlistWidth,
                    child: _buildWatchlistPanel(theme,
                        panelIndex: 0, onLeft: true),
                  ),
                  // Divider
                  Container(
                      width: 1,
                      color: shadcn.Theme.of(context).colorScheme.border),
                ],
              );
            },
          ),
          // Right side: AppBar + TextNugget + Ticker + Content
          Expanded(
            child: Column(
              children: [
                _buildRightSideAppBar(theme.isDarkMode),
                const AutoLoadTextNuggetWidget(
                  screenType: TextNuggetScreenType.homescreen,
                ),
                // Old auto-scrolling position ticker:
                // const PortfolioTickerStrip(),
                const PortfolioSummaryTickerStrip(),
                Expanded(
                  child: _buildContentPanel(theme, panelIndex: 1),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Watchlist on RIGHT, Content on LEFT
      return Row(
        children: [
          // Left side: AppBar + TextNugget + Ticker + Content
          Expanded(
            child: Column(
              children: [
                _buildRightSideAppBar(theme.isDarkMode),
                const AutoLoadTextNuggetWidget(
                  screenType: TextNuggetScreenType.homescreen,
                ),
                // Old auto-scrolling position ticker:
                // const PortfolioTickerStrip(),
                const PortfolioSummaryTickerStrip(),
                Expanded(
                  child: _buildContentPanel(theme, panelIndex: 0),
                ),
              ],
            ),
          ),
          // Right side: Watchlist (full height) — collapsible to a thin rail
          ValueListenableBuilder<bool>(
            valueListenable: watchlistVisibilityNotifier,
            builder: (context, visible, _) {
              if (!visible) {
                return _buildWatchlistCollapsedRail(theme, onLeft: false);
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Divider
                  Container(
                      width: 1,
                      color: shadcn.Theme.of(context).colorScheme.border),
                  SizedBox(
                    width: watchlistWidth,
                    child: _buildWatchlistPanel(theme,
                        panelIndex: 1, onLeft: false),
                  ),
                ],
              );
            },
          ),
        ],
      );
    }
  }

  /// Check if watchlist is in the specified panel
  bool _isWatchlistInPanel(int panelIndex) {
    if (panelIndex >= _panels.length) return false;
    final panel = _panels[panelIndex];

    // Check screenType
    if (panel.screenType == ScreenType.watchlist) return true;

    // Check active screen in screens list
    if (panel.screens.isNotEmpty &&
        panel.activeScreenIndex >= 0 &&
        panel.activeScreenIndex < panel.screens.length &&
        panel.screens[panel.activeScreenIndex] == ScreenType.watchlist) {
      return true;
    }

    // Check if any screen in the list is watchlist
    return panel.screens.contains(ScreenType.watchlist);
  }

  /// Build watchlist panel (full height) with index slots on top.
  /// [onLeft] controls which edge the collapse arrow points toward.
  Widget _buildWatchlistPanel(ThemesProvider theme,
      {required int panelIndex, bool onLeft = true}) {
    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      // Stack lets the collapse toggle float (absolutely positioned) over the
      // header without reflowing the indices row — it stays centered on the
      // indices/search seam and flush to the panel's outer edge.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              // Index slots row (toggle is rendered separately as an overlay).
              _buildWatchlistIndexSlots(theme.isDarkMode, measure: true),
              // Watchlist content
              Expanded(
                child: _getScreenForType(ScreenType.watchlist),
              ),
            ],
          ),
          // Absolutely-positioned collapse toggle: vertically centered on the
          // seam between the index strip and the search bar, hugging the outer
          // (divider-facing) edge.
          Positioned(
            top: _watchlistIndexStripHeight - 30,
            right: onLeft ? 0 : null,
            left: onLeft ? null : 0,
            child: _buildWatchlistCollapseButton(
              onLeft: onLeft,
              isDarkMode: theme.isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlistCollapseButton({
    required bool onLeft,
    required bool isDarkMode,
  }) {
    final scheme = shadcn.Theme.of(context).colorScheme;
    const radius = Radius.circular(10);
    final side = BorderSide(color: scheme.border);
    final borderRadius = onLeft
        ? const BorderRadius.only(topLeft: radius, bottomLeft: radius)
        : const BorderRadius.only(topRight: radius, bottomRight: radius);
    final border = onLeft
        ? Border(left: side, top: side, bottom: side)
        : Border(right: side, top: side, bottom: side);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: 'Hide watchlist',
        child: Material(
          color : const Color(0xFF0037B7),
          borderRadius: borderRadius,
          elevation: 1.5,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          child: InkWell(
            onTap: () => toggleWatchlistVisibility(),
            borderRadius: borderRadius,
            // hoverColor: scheme.accent,
            child: Container(
              width: 28,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: border,
              ),
              child: Icon(
                onLeft
                    ? shadcn.LucideIcons.chevronsLeft
                    : shadcn.LucideIcons.chevronsRight,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildWatchlistCollapsedRail(ThemesProvider theme,
      {required bool onLeft}) {
    final scheme = shadcn.Theme.of(context).colorScheme;
    final divider = Container(width: 1, color: scheme.border);
    final rail = Material(
      color: scheme.muted.withValues(alpha: 0.5),
      child: InkWell(
        onTap: () => toggleWatchlistVisibility(),
        child: SizedBox(
          width: 36,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Tooltip(
                message: 'Show watchlist',
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color : const Color(0xFF0037B7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: scheme.border),
                  ),
                  // Lucide for the same cache reason as the collapse button.
                  child: Icon(
                    onLeft
                        ? shadcn.LucideIcons.chevronsRight
                        : shadcn.LucideIcons.chevronsLeft,
                    size: 18,
                    color : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RotatedBox(
                  quarterTurns: onLeft ? 3 : 1,
                  child: Center(
                    child: Text(
                      'WATCHLIST',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.foreground,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: onLeft ? [rail, divider] : [divider, rail],
    );
  }

  /// Build index slots for watchlist panel (above search).
  /// [measure] attaches the strip-height probe used to position the floating
  /// collapse toggle (only the watchlist panel needs it, not charts mode).
  Widget _buildWatchlistIndexSlots(bool isDarkMode, {bool measure = false}) {
    return Consumer(
      builder: (context, ref, _) {
        final indexProvider = ref.watch(indexListProvider);
        final marketWatch = ref.read(marketWatchProvider);
        final theme = ref.watch(themeProvider);
        final indexValues = indexProvider.defaultIndexList?.indValues;
        if (measure) {
          // After layout, capture the strip height so the overlaid toggle can
          // center on the indices/search seam. Cheap: only setState on change.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final box = _watchlistIndexStripKey.currentContext
                ?.findRenderObject() as RenderBox?;
            final h = box?.size.height;
            if (h != null && mounted && (h - _watchlistIndexStripHeight).abs() > 0.5) {
              setState(() => _watchlistIndexStripHeight = h);
            }
          });
        }

        if (indexValues == null || indexValues.isEmpty) {
          return const SizedBox.shrink();
        }

        // Show only first 2 indices
        final displayIndices = indexValues.length >= 2
            ? indexValues.take(2).toList()
            : indexValues;

        return Container(
          key: measure ? _watchlistIndexStripKey : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.backgroundColorDark,
                light: MyntColors.backgroundColor),
            // border: Border(bottom: BorderSide(color: scheme.border)),
          ),
          child: Row(
            children: List.generate(
              displayIndices.length,
              (index) {
                final item = displayIndices[index];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < displayIndices.length - 1 ? 8 : 0,
                    ),
                    child: _AppBarIndexSlot(
                      indexItem: item,
                      indexPosition: index,
                      theme: theme,
                      marketWatch: marketWatch,
                      indexProvider: indexProvider,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Build content panel (below app bar)
  Widget _buildContentPanel(ThemesProvider theme, {required int panelIndex}) {
    if (panelIndex < _panels.length) {
      final panel = _panels[panelIndex];
      return Container(
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        child: panel.screens.isNotEmpty
            ? IndexedStack(
                index: panel.activeScreenIndex >= 0 &&
                        panel.activeScreenIndex < panel.screens.length
                    ? panel.activeScreenIndex
                    : 0,
                children: panel.screens.map((screenType) {
                  return _getScreenForType(screenType);
                }).toList(),
              )
            : (panel.screenType != null
                ? _getScreenForType(panel.screenType!)
                : _getScreenForType(ScreenType.dashboard)),
      );
    }
    // Default to dashboard if no panel configured
    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      child: _getScreenForType(ScreenType.dashboard),
    );
  }

  /// Open navigation drawer using shadcn drawer
  void _openShadcnDrawer(BuildContext context, {
    bool? showHome,
    bool? showPositions,
    bool? showHoldings,
    bool? showOrders,
    bool? showFunds,
    bool? showMutualFund,
    bool? showIPO,
    bool? showBonds,
    bool? showOptionZ,
    bool? showOptionFlash,
    bool? showScalper,
    bool? showScanner,
    bool? showCharts,
  }) {
    final theme = ref.read(themeProvider);
    final userProfile = ref.read(userProfileProvider);
    final userDetail = userProfile.userDetailModel;
    final clientDetail = userProfile.clientDetailModel;
    final Preferences pref = locator<Preferences>();
    final clientId = userDetail?.actid ?? clientDetail?.actid ?? pref.clientId ?? '';
    final userName = userDetail?.uname ?? '';

    shadcn.openDrawer(
      context: context,
      position: shadcn.OverlayPosition.left,
      transformBackdrop: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      draggable: true,
      showDragHandle: false,
      builder: (drawerContext) {
        return SizedBox(
          width: 300,
          child: NavigationDrawerWeb(
          isDarkMode: theme.isDarkMode,
          clientId: clientId,
          userName: userName,
          isScreenActive: (screenName) => _isScreenActiveInAnyPanel(screenName),
          onDashboardTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleDashboardTap();
          },
          onPositionsTap: () {
            shadcn.closeDrawer(drawerContext);
            _handlePositionsTap();
          },
          onHoldingsTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleHoldingsTap();
          },
          onOrderBookTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleOrderBookTap();
          },
          onFundsTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleFundsTap();
          },
          onIPOTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleIPOTap();
          },
          onSwapPanels: () {
            shadcn.closeDrawer(drawerContext);
            _handleSwapPanels();
          },
          onMutualFundTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleMutualFundTap();
          },
          onBondsTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleBondTap();
          },
          onOptionZTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleOptionZTap();
          },
          onOptionFlashTap: () {
            shadcn.closeDrawer(drawerContext);
            final optionFlash = ref.read(optionFlashProvider);
            if (optionFlash.isVisible) {
              optionFlash.closePanel();
            } else {
              optionFlash.showPanel(context);
            }
          },
          onScalperTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleScalperTap();
          },
          onScannerTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleScannerTap();
          },
          onOrderflowTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleOrderflowTap();
          },
          onChartsTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleChartsTap();
          },
          onStrategyBuilderTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleStrategyBuilderTap();
          },
          onInstaOptionsTap: () {
            shadcn.closeDrawer(drawerContext);
            _handleInstaOptionsTap();
          },
          onThemeToggle: () {
            shadcn.closeDrawer(drawerContext);
            ref.read(themeProvider.notifier).toggleTheme(
              themeMod: theme.isDarkMode ? 'Light' : 'Dark',
            );
          },
          onClose: () {
            shadcn.closeDrawer(drawerContext);
          },
          // Pass visibility flags - null means show all
          showHome: showHome,
          showPositions: showPositions,
          showHoldings: showHoldings,
          showOrders: showOrders,
          showFunds: showFunds,
          showMutualFund: showMutualFund,
          showIPO: showIPO,
          showBonds: showBonds,
          showOptionZ: showOptionZ,
          showOptionFlash: showOptionFlash,
          showScalper: showScalper,
          // Scanner / Orderflow / Charts hidden from the sidebar menu too, to
          // match the Options dropdown (features not ready for hosting).
          // Restore by putting the show* variables back / removing these.
          showScanner: showScanner,
          showOrderflow: false,
          showCharts: false,
        ),
        );
      },
    );
  }

  /// Build app bar for right side only - with responsive navigation
  Widget _buildRightSideAppBar(bool isDarkMode) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Accessibility widens the app-bar nav: a larger Font Size scale and the
    // OpenDyslexic dyslexia face both need more horizontal room per item, so
    // the fixed pixel breakpoints below would overflow the header off-screen.
    // Inflate the thresholds by roughly the same factor the text grows by, so
    // nav items collapse into the hamburger drawer a little earlier (they stay
    // reachable there) instead of spilling past the right edge. Watched so the
    // breakpoints recompute the moment the user toggles these options.
    final a11y = ref.watch(accessibilityProvider);
    // OpenDyslexic renders ~1.3x wider (wider glyphs + added letter spacing).
    final a11yNavFactor =
        a11y.textScale * (a11y.dyslexiaSupportEnabled ? 1.3 : 1.0);

    // Responsive breakpoints - Option 2 implementation
    final isMobileTablet = screenWidth < 900; // Full mobile/tablet mode

    // Left navigation - hide ALL at once when space is not available
    final showAllLeftNav =
        screenWidth >= 1650 * a11yNavFactor; // Show MF, IPO, Bonds, Options together

    // Right navigation - hide ALL at once (not one by one)
    // When left nav is visible: need more space, so hide right nav items earlier
    // When left nav is hidden: have more space, so can show right nav items longer
    final showAllRightNav = showAllLeftNav
        ? (screenWidth >= 1550 * a11yNavFactor)  // If left nav visible, need 1550px to show all right nav
        : (screenWidth >= 950 * a11yNavFactor);  // If left nav hidden, only need 950px to show all right nav

    // Determine which items to show in hamburger drawer
    // Desktop mode: Show only hidden items in drawer
    // Tablet/Mobile mode: Show all items in drawer
    final showHamburgerForHiddenItems = !isMobileTablet && (!showAllLeftNav || !showAllRightNav); // Desktop with any hidden items
    final showHamburger = isMobileTablet || showHamburgerForHiddenItems;

    return Container(
      height: context.responsive(mobile: 56.0, tablet: 60.0, desktop: 65.0),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        border: Border(
          bottom: BorderSide(
            color: shadcn.Theme.of(context).colorScheme.border,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.only(
          left: context.responsive(mobile: 12.0, tablet: 16.0, desktop: 20.0),
          right: context.responsive(mobile: 12.0, tablet: 14.0, desktop: 16.0),
          top: 6,
          bottom: 6,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Hamburger menu - shows when ANY item is hidden
            if (showHamburger)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Semantics(
                  button: true,
                  label: 'Open navigation menu',
                  excludeSemantics: true,
                  child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () {
                      // In mobile/tablet mode: show all items
                      // In desktop mode: show only hidden items
                      if (isMobileTablet) {
                        // Mobile/Tablet: show everything
                        _openShadcnDrawer(context);
                      } else {
                        // Desktop: show only hidden items
                        _openShadcnDrawer(
                          context,
                          showHome: false, // Home always visible in desktop
                          showPositions: !showAllRightNav, // Show if hidden (when showAllRightNav is false)
                          showHoldings: !showAllRightNav,
                          showOrders: !showAllRightNav,
                          showFunds: !showAllRightNav,
                          showMutualFund: !showAllLeftNav, // Show if left nav is hidden
                          showIPO: !showAllLeftNav,
                          showBonds: !showAllLeftNav,
                          showOptionZ: !showAllLeftNav, // Options dropdown hidden with left nav
                          showOptionFlash: !showAllLeftNav,
                          showScalper: !showAllLeftNav,
                          showScanner: !showAllLeftNav,
                          showCharts: !showAllLeftNav,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.menu,
                        color: isDarkMode
                            ? MyntColors.textPrimaryDark
                            : MyntColors.textPrimary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                ),
              ),

            // Logo section
            Semantics(
              image: true,
              label: 'Mynt by Zebu',
              excludeSemantics: true,
              child: RepaintBoundary(
                child: SvgPicture.asset(
                  assets.appLogoIcon,
                  width: context.responsive(mobile: 80.0, tablet: 90.0, desktop: 100.0),
                  height: 38,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Left navigation items - hide ALL at once when screen < 1500px
            if (!isMobileTablet && showAllLeftNav) ...[
              const SizedBox(width: 24),
              _buildShadcnNavItem('Mutual Fund', isDarkMode, ScreenType.mutualFund, () => _handleMutualFundTap()),
              const SizedBox(width: 4),
              _buildShadcnNavItem('IPO', isDarkMode, ScreenType.ipo, () => _handleIPOTap()),
              const SizedBox(width: 4),
              _buildShadcnNavItem('Bonds', isDarkMode, ScreenType.bond, () => _handleBondTap()),
              const SizedBox(width: 4),
              _buildTradingToolsMenu(isDarkMode),
            ],

            const Spacer(),

            // Right navigation - hide ALL at once
            if (!isMobileTablet && showAllRightNav) ...[
              // Home - always visible in desktop mode
              _buildShadcnNavItem('Home', isDarkMode, ScreenType.dashboard, () => _handleDashboardTap()),
              const SizedBox(width: 4),
              _buildShadcnNavItem('Positions', isDarkMode, ScreenType.positions, () => _handlePositionsTap()),
              const SizedBox(width: 4),
              _buildShadcnNavItem('Holdings', isDarkMode, ScreenType.holdings, () => _handleHoldingsTap()),
              const SizedBox(width: 4),
              _buildShadcnNavItem('Orders', isDarkMode, ScreenType.orderBook, () => _handleOrderBookTap()),
              const SizedBox(width: 4),
              _buildShadcnNavItem('Funds', isDarkMode, ScreenType.funds, () => _handleFundsTap()),
              const SizedBox(width: 20),
            ] else if (!isMobileTablet) ...[
              // When right nav is hidden, only show Home
              _buildShadcnNavItem('Home', isDarkMode, ScreenType.dashboard, () => _handleDashboardTap()),
              const SizedBox(width: 20),
            ],

            // Accessibility options (always visible)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: A11yIconButton(
                key: const ValueKey('a11y_icon_btn'),
                anchorKey: _a11yAnchorKey,
                isDarkMode: isDarkMode,
                active: ref.watch(accessibilityProvider).screenReaderEnabled,
                onTap: () => _toggleAccessibilityDropdown(isDarkMode),
              ),
            ),

            // Profile section (always visible)
            Semantics(
              button: true,
              label: 'Profile menu',
              child: RepaintBoundary(
                child: _buildProfileSection(isDarkMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAccessibilityDropdown(bool isDarkMode) {
    if (_a11yOverlay != null) {
      _closeAccessibilityDropdown();
      return;
    }
    if (_a11yAnchorKey.currentContext == null) return;
    _a11yOverlay = buildAccessibilityOverlay(
      context: context,
      anchorKey: _a11yAnchorKey,
      isDarkMode: isDarkMode,
      onClose: _closeAccessibilityDropdown,
    );
    Overlay.of(context, rootOverlay: true).insert(_a11yOverlay!);
  }

  void _closeAccessibilityDropdown() {
    _a11yOverlay?.remove();
    _a11yOverlay = null;
  }

  _buildAppBar(bool isDarkMode) {
    return PreferredSize(
      preferredSize:
          const Size.fromHeight(65), // Reduced height for compact design
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            // Clean minimal - white background
            color: resolveThemeColor(context,
                dark: MyntColors.backgroundColorDark,
                light: MyntColors.backgroundColor),
            // Subtle border at bottom
            border: Border(
              bottom: BorderSide(
                color: shadcn.Theme.of(context).colorScheme.border,
                width: 1,
              ),
            ),
            // Soft shadow for depth
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Container(
            padding:
                const EdgeInsets.only(left: 20, right: 16, top: 6, bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Logo section
                RepaintBoundary(
                  child: SvgPicture.asset(
                    assets.appLogoIcon,
                    width: 100,
                    height: 38,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 24),
                // Primary actions
                _buildNavItem('Mutual Fund', isDarkMode, ScreenType.mutualFund,
                    () => _handleMutualFundTap()),
                const SizedBox(width: 12),
                _buildNavItem('IPO', isDarkMode, ScreenType.ipo,
                    () => _handleIPOTap()),
                const SizedBox(width: 12),
                _buildNavItem('OptionZ', isDarkMode, ScreenType.tradeAction,
                    () => _handleOptionZTap()),
                    const SizedBox(width: 12),
            // Option Flash button
            Consumer(builder: (context, ref, _) {
              return _buildOptionFlashButton(isDarkMode, ref);
            }),

                const SizedBox(width: 12),
                _buildNavItem('StrBuilder', isDarkMode, ScreenType.strategyBuilder,
                    () => _handleStrategyBuilderTap()),


                const Spacer(),

                // Balance / Funds
                Consumer(builder: (context, ref, _) {
                  final funds = ref.watch(fundProvider);
                  final balance = funds.fundDetailModel?.avlMrg ?? "0.00";
                  return InkWell(
                    onTap: () => _handleFundsTap(),
                    child: Row(
                      children: [
                        Text(
                          "Balance: ",
                          style: MyntWebTextStyles.caption(
                            context,
                            fontWeight: MyntFonts.medium,
                            color: isDarkMode ? Colors.grey : Colors.grey[600],
                          ),
                        ),
                        Text(
                          "₹${getFormatter(value: double.parse(balance), v4d: false, noDecimal: false)}",
                          style: MyntWebTextStyles.body(
                            context,
                            fontWeight: MyntFonts.semiBold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(width: 24),
                
                // Right side items: Navigation → Profile (contains swap, theme, switch account in dropdown) → Index slots
                _buildNavigationScreens(isDarkMode),
                const SizedBox(width: 20),
                // Profile section (contains swap, theme toggle, switch account in dropdown)
                RepaintBoundary(
                  child: _buildProfileSection(isDarkMode),
                ),
                const SizedBox(width: 12),
                // Index slots section
                _buildAppBarIndexSlots(isDarkMode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomizableBody(ThemesProvider theme) {
    return Consumer(
      builder: (context, ref, _) {
        final internetStatus = ref.watch(networkStateProvider
            .select((internet) => internet.connectionStatus));
        final showChart = ref.watch(userProfileProvider
            .select((userProfile) => userProfile.showchartof));

        if ((internetStatus == ConnectivityResult.wifi ||
                internetStatus == ConnectivityResult.mobile) &&
            !showChart) {
          return _buildSplitView(theme);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSplitView(ThemesProvider theme) {
    return _buildGridContent(theme);
  }

  /// Calculate split ratio for watchlist - Fixed 75-25 split
  /// Watchlist always takes 25% of screen width for consistent UX
  ///
  /// [isLeftPanel] - true if watchlist is in left panel, false if in right panel
  double _getResponsiveWatchlistRatio(BuildContext context,
      {required bool isLeftPanel}) {
    // Fixed 25% for watchlist, 75% for main content
    const double watchlistRatio = 0.25;

    // Return appropriate ratio based on panel position
    // If watchlist is on left: return 0.25 (left panel = 25%, right panel = 75%)
    // If watchlist is on right: return 0.75 (left panel = 75%, right panel = 25%)
    return isLeftPanel ? watchlistRatio : (1.0 - watchlistRatio);
  }

  Widget _buildGridContent(ThemesProvider theme) {
    return _buildTwoPanels(theme);
  }

  Widget _buildTwoPanels(ThemesProvider theme) {
    // Check if watchlist is in any panel to determine split ratio
    bool hasWatchlistInFirstPanel = _panels.isNotEmpty &&
        (_panels[0].screenType == ScreenType.watchlist ||
            (_panels[0].screens.isNotEmpty &&
                _panels[0].activeScreenIndex >= 0 &&
                _panels[0].activeScreenIndex < _panels[0].screens.length &&
                _panels[0].screens[_panels[0].activeScreenIndex] ==
                    ScreenType.watchlist));

    bool hasWatchlistInSecondPanel = _panels.length > 1 &&
        (_panels[1].screenType == ScreenType.watchlist ||
            (_panels[1].screens.isNotEmpty &&
                _panels[1].activeScreenIndex >= 0 &&
                _panels[1].activeScreenIndex < _panels[1].screens.length &&
                _panels[1].screens[_panels[1].activeScreenIndex] ==
                    ScreenType.watchlist));

    // Determine split ratio based on watchlist position and screen size
    double splitRatio = 0.5; // Default 50/50
    bool enableResize = true; // Default to resizable

    if (hasWatchlistInFirstPanel) {
      // Watchlist is in left panel - calculate responsive width
      splitRatio = _getResponsiveWatchlistRatio(context, isLeftPanel: true);
      enableResize = false; // Disable resize to maintain fixed ratio
    } else if (hasWatchlistInSecondPanel) {
      // Watchlist is in right panel - calculate responsive width
      splitRatio = _getResponsiveWatchlistRatio(context, isLeftPanel: false);
      enableResize = false; // Disable resize to maintain fixed ratio
    }

    return SplitterWidget(
      child1: _buildResizableGridSlot(0, theme),
      child2: _buildResizableGridSlot(1, theme),
      direction: Axis.horizontal,
      initialSplitRatio: splitRatio,
      splitterSize: 0.0,
      splitterColor: null, // Let the splitter use theme colors
      enableResize: enableResize,
      onSplitChanged: () {
        _saveLayout();
      },
    );
  }

  // Build resizable grid slot
  Widget _buildResizableGridSlot(int index, ThemesProvider theme) {
    if (index >= _panels.length) {
      return Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.isDarkMode
              ? colors.colorGrey.withOpacity(0.1)
              : colors.colorGrey.withOpacity(0.05),
          // Removed border to eliminate thick border between layouts
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            color: Colors.grey,
            size: 32,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: _buildGridSlot(index, theme),
    );
  }

  // Build grid slot (empty slot that can be filled)
  Widget _buildGridSlot(int index, ThemesProvider theme) {
    if (index >= _panels.length) {
      return Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.isDarkMode
              ? colors.colorGrey.withOpacity(0.1)
              : colors.colorGrey.withOpacity(0.05),
          // Removed border to eliminate thick border between layouts
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            color: Colors.grey,
            size: 32,
          ),
        ),
      );
    }

    final panel = _panels[index];

    return Container(
      // margin: const EdgeInsets.all(0),
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      child: DragTarget<Object>(
        onAcceptWithDetails: (details) {
          final draggedData = details.data;
          if (draggedData is ScreenType) {
            setState(() {
              panel.screenType = draggedData;
              if (panel.screens.isEmpty) {
                panel.screens = [draggedData];
                panel.activeScreenIndex = 0;
              } else {
                panel.screens[panel.activeScreenIndex] = draggedData;
              }
            });
            _saveLayout();
          } else if (draggedData is PanelConfig && draggedData.id != panel.id) {
            _swapPanels(draggedData, panel);
            _saveLayout();
          }
        },
        onWillAcceptWithDetails: (details) {
          final data = details.data;
          if (data is ScreenType) {
            return true;
          } else if (data is PanelConfig && data.id != panel.id) {
            return true;
          }
          return false;
        },
        builder: (context, candidateData, rejectedData) {
          final isHighlighted = candidateData.isNotEmpty;
          final isPanelSwap =
              candidateData.isNotEmpty && candidateData.first is PanelConfig;
          final isScreenDrop =
              candidateData.isNotEmpty && candidateData.first is ScreenType;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              // color: isHighlighted
              //     ? (isPanelSwap
              //         ? colors.ltpgreen.withOpacity(0.15)
              //         : colors.colorBlue.withOpacity(0.15))
              //     : (theme.isDarkMode
              //         ? colors.colorGrey.withOpacity(0.1)
              //         : colors.colorGrey.withOpacity(0.05)),
              // Add single border based on panel position
              border: Border(
                right: index == 0
                    ? BorderSide(
                        color: shadcn.Theme.of(context).colorScheme.border,
                        width: 1,
                        // width: 1,
                      )
                    : BorderSide.none,
                left: index == 1
                    ? BorderSide(
                        color: shadcn.Theme.of(context).colorScheme.border,
                        width: 1,
                        // width: 1,
                      )
                    : BorderSide.none,
              ),
              boxShadow: isHighlighted
                  ? [
                      BoxShadow(
                        color: isPanelSwap
                            ? colors.ltpgreen.withOpacity(0.3)
                            : colors.colorBlue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                panel.screenType != null
                    ? _buildFilledSlot(panel, theme)
                    : _buildEmptySlot(theme),
                if (isScreenDrop && panel.screenType == null)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
                        ).withOpacity(0.1),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary,
                              ),
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Drop to add',
                              style: MyntWebTextStyles.caption(
                                context,
                                fontWeight: MyntFonts.semiBold,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.primaryDark,
                                  light: MyntColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Build empty slot
  Widget _buildEmptySlot(ThemesProvider theme) {
    return Container();
  }

  // Build filled slot with screen content
  Widget _buildFilledSlot(PanelConfig panel, ThemesProvider theme) {
    // Get the active screen or fallback to screenType for backward compatibility
    ScreenType? activeScreen;
    if (panel.screens.isNotEmpty &&
        panel.activeScreenIndex >= 0 &&
        panel.activeScreenIndex < panel.screens.length) {
      activeScreen = panel.screens[panel.activeScreenIndex];
    } else {
      activeScreen = panel.screenType;
    }

    return Stack(
      children: [
        // Screen content (not draggable) - no header padding
        Positioned(
          top: 0, // No header, so content starts at top
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRRect(
            child: panel.screens.isNotEmpty
                ? IndexedStack(
                    index: panel.activeScreenIndex >= 0 &&
                            panel.activeScreenIndex < panel.screens.length
                        ? panel.activeScreenIndex
                        : 0,
                    children: panel.screens.map((screenType) {
                      return _getScreenForType(screenType);
                    }).toList(),
                  )
                : (activeScreen != null
                    ? _getScreenForType(activeScreen)
                    : const SizedBox.shrink()),
          ),
        ),
      ],
    );
  }

  // Build logo section for app bar

  void _handleOptionZTap() async {
    final funds = ref.read(fundProvider);
    await funds.fetchHstoken(context);
    await funds.openOptionZInNewTab();
  }

  void _handleStrategyBuilderTap() {
    // Show Strategy Builder in panel instead of navigating to separate route
    _replaceScreenInPanel(ScreenType.strategyBuilder);
  }

  void _handleInstaOptionsTap() {
    _replaceScreenInPanel(ScreenType.instaOptions);
  }

  void _handleCuratedStrategiesTap() {
    // Show the Curated Strategies list in the panel like other full pages.
    _replaceScreenInPanel(ScreenType.curatedStrategies);
  }

  void _handleAlgoStrategiesTap() {
    // Show the Algo Strategies list in the panel like other full pages.
    _replaceScreenInPanel(ScreenType.allAlgoStrategies);
  }

  void _handleWebHookTap() {
    _replaceScreenInPanel(ScreenType.tradingViewWebHook);
  }

  void _handleBasketDashboardTap() {
    _replaceScreenInPanel(ScreenType.basketDashboard);
  }

  void _handleScalperTap() {
    setState(() => _isScalperMode = true);
    WebNavigationHelper.updateUrl(WebRoutes.scalper);
  }

  void _handleScannerTap({ScannerSubPage? initial}) {
    _replaceScreenInPanel(ScreenType.scanner);
    final path = initial == null
        ? WebRoutes.scanner
        : _scannerPath(initial);
    WebNavigationHelper.updateUrl(path);
  }

  void _handleOrderflowTap() {
    _replaceScreenInPanel(ScreenType.orderflow);
    WebNavigationHelper.updateUrl(WebRoutes.orderflow);
  }

  String _scannerPath(ScannerSubPage p) {
    switch (p) {
      // Legacy cases kept commented alongside the enum values — re-enable
      // together if the old tabs come back.
      // case ScannerSubPage.symbols:
      //   return WebRoutes.scannerSymbols;
      // case ScannerSubPage.scanners:
      //   return WebRoutes.scannerScanners;
      // case ScannerSubPage.fundamentals:
      //   return WebRoutes.scannerFundamentals;
      case ScannerSubPage.customScans:
        return WebRoutes.scannerCustom;
      case ScannerSubPage.fundamentalsNew:
        // Redesign scaffold — reuse the fundamentals route for now; a dedicated
        // route is added when this tab replaces the old Fundamentals screen.
        return WebRoutes.scannerFundamentals;
      case ScannerSubPage.scannersNew:
        // Dashboard redesign scaffold — reuse the scanners route for now.
        return WebRoutes.scannerScanners;
    }
  }

  void _handleChartsTap() {
    setState(() => _isChartsMode = true);
    WebNavigationHelper.updateUrl(WebRoutes.charts);
  }

  // Build navigation screens for app bar
  Widget _buildNavigationScreens(bool isDarkMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildShadcnNavItem('Home', isDarkMode, ScreenType.dashboard,
            () => _handleDashboardTap()),
        const SizedBox(width: 4),
        _buildShadcnNavItem('Positions', isDarkMode, ScreenType.positions,
            () => _handlePositionsTap()),
        const SizedBox(width: 4),
        _buildShadcnNavItem('Holdings', isDarkMode, ScreenType.holdings,
            () => _handleHoldingsTap()),
        const SizedBox(width: 4),
        _buildShadcnNavItem('Orders', isDarkMode, ScreenType.orderBook,
            () => _handleOrderBookTap()),
        const SizedBox(width: 4),
        _buildShadcnNavItem(
            'Funds', isDarkMode, ScreenType.funds, () => _handleFundsTap()),
      ],
    );
  }

  // Build individual navigation item
  Widget _buildNavItem(String title, bool isDarkMode, ScreenType screenType,
      VoidCallback onTap) {
    // In scalper mode, no other nav items should show as active
    bool isActive = false;
    if (!_isScalperMode) {
      for (int i = 0; i < _panels.length; i++) {
        final panel = _panels[i];
        if (panel.screenType == screenType ||
            (panel.screens.isNotEmpty &&
                panel.activeScreenIndex >= 0 &&
                panel.activeScreenIndex < panel.screens.length &&
                panel.screens[panel.activeScreenIndex] == screenType)) {
          isActive = true;
          break;
        }
      }
    }

    return _HoverableNavItem(
      title: title,
      isActive: isActive,
      onTap: () {
        // Exit scalper / charts mode when navigating to another screen
        if (_isScalperMode || _isChartsMode) {
          setState(() {
            _isScalperMode = false;
            _isChartsMode = false;
          });
        }
        onTap();
      },
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildOptionFlashButton(bool isDarkMode, WidgetRef ref) {
    final optionFlash = ref.watch(optionFlashProvider);
    final isActive = optionFlash.isVisible;

    return _HoverableNavItem(
      title: ' Option Flash',
      isActive: isActive,
      onTap: () {
        if (optionFlash.isVisible) {
          optionFlash.closePanel();
        } else {
          optionFlash.showPanel(context);
        }
      },
      isDarkMode: isDarkMode,
    );
  }

  // Build shadcn NavigationMenu for single nav items
  Widget _buildShadcnNavItem(String title, bool isDarkMode, ScreenType screenType,
      VoidCallback onTap) {
    // Check if this screen is currently active in any panel
    bool isActive = false;
    if (!_isScalperMode && !_isChartsMode) {
      for (int i = 0; i < _panels.length; i++) {
        final panel = _panels[i];
        if (panel.screenType == screenType ||
            (panel.screens.isNotEmpty &&
                panel.activeScreenIndex >= 0 &&
                panel.activeScreenIndex < panel.screens.length &&
                panel.screens[panel.activeScreenIndex] == screenType)) {
          isActive = true;
          break;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: shadcn.NavigationMenu(
        children: [
          shadcn.NavigationMenuItem(
            onPressed: onTap,
            child: Text(
              title,
              style: MyntWebTextStyles.body(
                context,
                fontWeight: isActive ? MyntFonts.bold : MyntFonts.semiBold,
                darkColor: isActive ? MyntColors.primaryDark : MyntColors.textPrimaryDark,
                lightColor: isActive ? MyntColors.primary : MyntColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build Trading Tools dropdown menu (click-based)
  Widget _buildTradingToolsMenu(bool isDarkMode) {
    return Consumer(
      builder: (context, ref, _) {
        final optionFlash = ref.watch(optionFlashProvider);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: shadcn.GhostButton(
            onPressed: () {
              shadcn.showDropdown(
                context: context,
                builder: (context) {
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
                        child: shadcn.DropdownMenu(
                    children: [
                      // OptionZ
                      shadcn.MenuButton(
                        onPressed: (context) {
                          _handleOptionZTap();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                shadcn.LucideIcons.chartBar,
                                size: 22,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.iconDark,
                                  light: MyntColors.icon,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'OptionZ',
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.medium,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Option Flash
                      shadcn.MenuButton(
                        onPressed: (context) {
                          if (optionFlash.isVisible) {
                            optionFlash.closePanel();
                          } else {
                            optionFlash.showPanel(context);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                shadcn.BootstrapIcons.lightning,
                                size: 22,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.iconDark,
                                  light: MyntColors.icon,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Option Flash',
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.medium,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Strategy Builder
                      shadcn.MenuButton(
                        onPressed: (context) {
                          _handleStrategyBuilderTap();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                shadcn.LucideIcons.draftingCompass,
                                size: 22,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.iconDark,
                                  light: MyntColors.icon,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Strategy Builder',
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.medium,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // InstaOptions Analytics
                      shadcn.MenuButton(
                        onPressed: (context) {
                          _handleInstaOptionsTap();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                shadcn.LucideIcons.activity,
                                size: 22,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.iconDark,
                                  light: MyntColors.icon,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'InstaOptions Analytics',
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.medium,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Scalper
                      shadcn.MenuButton(
                        onPressed: (context) {
                          _handleScalperTap();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.speed,
                                size: 22,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.iconDark,
                                  light: MyntColors.icon,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Scalper',
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.medium,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary,
                                ),
                              ),
                              // Scalper "Beta" badge removed — Scalper is no
                              // longer beta. Kept commented for easy rollback.
                              /*
                              const SizedBox(width: 4),
                              Transform.translate(
                                offset: const Offset(0, -6),
                                child: Text(
                                  'Beta',
                                  style: MyntWebTextStyles.caption(
                                    context,
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.primaryDark,
                                      light: MyntColors.primary,
                                    ),
                                    fontWeight: MyntFonts.semiBold,
                                  ).copyWith(fontSize: 10),
                                ),
                              ),
                              */
                            ],
                          ),
                        ),
                      ),
                      // Scanner is shown in the Options dropdown; Orderflow /
                      // Charts stay hidden below (line-commented). Restore them
                      // by un-commenting; handlers (_handleScannerTap etc.) remain.
                      // Scanner
                      shadcn.MenuButton(
                        onPressed: (context) {
                          _handleScannerTap();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                shadcn.LucideIcons.radar,
                                size: 22,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.iconDark,
                                  light: MyntColors.icon,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Scanner',
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: MyntFonts.medium,
                                  darkColor: MyntColors.textPrimaryDark,
                                  lightColor: MyntColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),


                      //  Orderflow — nested under Scanner in the Options menu
                      // shadcn.MenuButton(
                      //   onPressed: (context) {
                      //     _handleOrderflowTap();
                      //   },
                      //   child: Padding(
                      //     padding: const EdgeInsets.symmetric(vertical: 10),
                      //     child: Row(
                      //       children: [
                      //         Icon(
                      //           shadcn.LucideIcons.activity,
                      //           size: 22,
                      //           color: resolveThemeColor(
                      //             context,
                      //             dark: MyntColors.iconDark,
                      //             light: MyntColors.icon,
                      //           ),
                      //         ),
                      //         const SizedBox(width: 14),
                      //         Text(
                      //           'Orderflow',
                      //           style: MyntWebTextStyles.body(
                      //             context,
                      //             fontWeight: MyntFonts.medium,
                      //             darkColor: MyntColors.textPrimaryDark,
                      //             lightColor: MyntColors.textPrimary,
                      //           ),
                      //         ),
                      //         const SizedBox(width: 6),
                      //         Transform.translate(
                      //           offset: const Offset(0, -6),
                      //           child: Text(
                      //             'Beta',
                      //             style: MyntWebTextStyles.caption(
                      //               context,
                      //               color: resolveThemeColor(
                      //                 context,
                      //                 dark: MyntColors.primaryDark,
                      //                 light: MyntColors.primary,
                      //               ),
                      //               fontWeight: MyntFonts.semiBold,
                      //             ).copyWith(fontSize: 10),
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                      // Charts
                      // shadcn.MenuButton(
                      //   onPressed: (context) {
                      //     _handleChartsTap();
                      //   },
                      //   child: Padding(
                      //     padding: const EdgeInsets.symmetric(vertical: 10),
                      //     child: Row(
                      //       children: [
                      //         Icon(
                      //           shadcn.LucideIcons.chartLine,
                      //           size: 22,
                      //           color: resolveThemeColor(
                      //             context,
                      //             dark: MyntColors.iconDark,
                      //             light: MyntColors.icon,
                      //           ),
                      //         ),
                      //         const SizedBox(width: 14),
                      //         Text(
                      //           'Charts',
                      //           style: MyntWebTextStyles.body(
                      //             context,
                      //             fontWeight: MyntFonts.medium,
                      //             darkColor: MyntColors.textPrimaryDark,
                      //             lightColor: MyntColors.textPrimary,
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                      
                    ],
                  ),
                      ),
                    ),
                  );
                },
              ).future.whenComplete(() {
                // Backstop: the dropdown can close WITHOUT the MouseRegion's
                // onExit firing (tapping a menu item, click-away dismiss, or
                // Esc). When that happens the chart iframes were left at
                // pointer-events:none by onEnter/_disableAllChartIframes and
                // stayed unclickable until something else re-enabled them —
                // the intermittent "can't click / hover the chart" bug.
                // Restoring here guarantees the chart is interactive again
                // no matter how the menu was dismissed. showDropdown returns
                // an OverlayCompleter, whose `.future` resolves on close.
                ChartIframeGuard.release();
                _enableAllChartIframes();
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Options',
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: _isScalperMode ? MyntFonts.bold : MyntFonts.semiBold,
                    darkColor: _isScalperMode ? MyntColors.primaryDark : MyntColors.textPrimaryDark,
                    lightColor: _isScalperMode ? MyntColors.primary : MyntColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: resolveThemeColor(
                    context,
                    dark: _isScalperMode ? MyntColors.primaryDark : MyntColors.textPrimaryDark,
                    light: _isScalperMode ? MyntColors.primary : MyntColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build profile section for app bar
  Widget _buildProfileSection(bool isDarkMode) {
    return Consumer(
      builder: (context, ref, _) {
        final userProfile = ref.watch(userProfileProvider);
        final userDetail = userProfile.userDetailModel;
        final clientDetail = userProfile.clientDetailModel;
        final isDark = ref.watch(themeProvider).isDarkMode;

        // Get client ID with fallback to preferences
        final Preferences pref = locator<Preferences>();
        String clientId = userDetail?.actid ?? clientDetail?.actid ?? pref.clientId ?? '';

        return ProfileDropdown(
          isDarkMode: isDarkMode,
          clientId: clientId,
          onNavigateToScreen: (screenType) {
            _navigateToScreen(screenType);
          },
          onThemeToggle: () {
            ref.read(themeProvider.notifier).toggleTheme(
                  themeMod: isDark ? 'Light' : 'Dark',
                );
          },
          onSwapPanels: () {
            _handleSwapPanels();
          },
        );
      },
    );
  }

  // Navigate to a specific screen type in the main panel
  void _navigateToScreen(ScreenType screenType) {
    // Exit scalper / charts mode when navigating to any other screen — otherwise
    // the full-width view stays rendered regardless of panel state.
    if (_isScalperMode && screenType != ScreenType.scalper) {
      _isScalperMode = false;
    }
    if (_isChartsMode && screenType != ScreenType.charts) {
      _isChartsMode = false;
    }
    if (screenType == ScreenType.charts) {
      setState(() => _isChartsMode = true);
      return;
    }

    // Find the active panel (not watchlist) and switch to the new screen
    int targetPanelIndex = 0;
    for (int i = 0; i < _panels.length; i++) {
      if (_panels[i].screenType != ScreenType.watchlist &&
          !(_panels[i].screens.isNotEmpty &&
              _panels[i].screens.contains(ScreenType.watchlist))) {
        targetPanelIndex = i;
        break;
      }
    }

    // Save current screen for back navigation
    final currentScreen = _panels[targetPanelIndex].screenType;
    if (currentScreen != null) {
      _panelScreenHistory[targetPanelIndex] ??= [];
      _panelScreenHistory[targetPanelIndex]!.add(currentScreen);
    }

    setState(() {
      _panels[targetPanelIndex].screenType = screenType;
      _panels[targetPanelIndex].screens = [screenType];
      _panels[targetPanelIndex].activeScreenIndex = 0;
    });
    _saveLayout();
    _handleScreenTypeChange(screenType);
    // Keep URL in sync (no-op for screens that don't map to a route)
    _updateUrlForScreenType(screenType);
  }

  // Build index slots for app bar
  Widget _buildAppBarIndexSlots(bool isDarkMode) {
    return Consumer(
      builder: (context, ref, _) {
        final indexProvider = ref.watch(indexListProvider);
        final marketWatch = ref.read(marketWatchProvider);
        final theme = ref.watch(themeProvider);
        final indexValues = indexProvider.defaultIndexList?.indValues;

        if (indexValues == null || indexValues.isEmpty) {
          return const SizedBox.shrink();
        }

        // Calculate watchlist width (same as watchlist panel)
        final screenWidth = MediaQuery.of(context).size.width;
        const double watchlistRatio = 0.24; // 25% - same as watchlist panel
        final watchlistWidth = screenWidth * watchlistRatio;

        // Show only first 2 indices
        final displayIndices = indexValues.length >= 2
            ? indexValues.take(2).toList()
            : indexValues;

        return SizedBox(
          width: watchlistWidth, // Same width as watchlist panel
          child: Row(
            children: List.generate(
              displayIndices.length,
              (index) {
                if (index >= displayIndices.length) {
                  return const SizedBox.shrink();
                }
                final item = displayIndices[index];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < displayIndices.length - 1 ? 8 : 0,
                    ),
                    child: _AppBarIndexSlot(
                      indexItem: item,
                      indexPosition: index,
                      theme: theme,
                      marketWatch: marketWatch,
                      indexProvider: indexProvider,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _getScreenForType(ScreenType type) {
    switch (type) {
      case ScreenType.dashboard:
        return const DashboardScreenWeb();
      case ScreenType.watchlist:
        return const WatchListScreenWeb();
      case ScreenType.holdings:
        return Consumer(
          builder: (context, ref, _) {
            final isLoading =
                _screenLoadingStates[ScreenType.holdings] ?? false;
            final holdloader =
                ref.watch(portfolioProvider.select((p) => p.holdloader));
            final holdingsModel =
                ref.watch(portfolioProvider.select((p) => p.holdingsModel));
            // final hasData = holdingsModel != null && holdingsModel.isNotEmpty;

            // Show loader if local loading state is true, provider loading is true, or no data yet
            if (isLoading || holdloader) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                color: resolveThemeColor(context,
                    dark: MyntColors.backgroundColorDark,
                    light: MyntColors.backgroundColor),
                child: MyntLoader.branded(),
              );
            }
            return HoldingScreenWeb(
              listofHolding: holdingsModel ?? [],
              initialTabIndex: _holdingsInitialTabIndex,
              tabRequestId: _holdingsTabRequestId,
            );
          },
        );
      case ScreenType.positions:
        return Consumer(
          builder: (context, ref, _) {
            // ✅ Optimize: Only watch specific properties instead of entire provider
            final isLoading =
                _screenLoadingStates[ScreenType.positions] ?? false;
            final posloader =
                ref.watch(portfolioProvider.select((p) => p.posloader));
            final allPostionList =
                ref.watch(portfolioProvider.select((p) => p.allPostionList));

           

            // Show loader only when actively loading, not when no data exists
            if (isLoading || posloader) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                color: resolveThemeColor(context,
                    dark: MyntColors.backgroundColorDark,
                    light: MyntColors.backgroundColor),
                child: MyntLoader.branded(),
              );
            }
            return PositionScreenWeb(listofPosition: allPostionList);
          },
        );
      case ScreenType.orderBook:
        // Show OrderBookScreenWeb directly for instant response
        // It will handle its own loading states internally
        return const OrderBookScreenWeb();
      case ScreenType.funds:
        return _LazyFundScreen(initialAction: _fundsInitialAction);
      case ScreenType.mutualFund:
        return MFExploreScreensWeb(
          onNfoTap: () {
            // Show NFO screen in right panel (panel 2)
            _showScreenInRightPanel(ScreenType.mfNfo);
          },
          onStrategyTap: () {
            _handleBasketDashboardTap();
          },
          onCollectionTap: (title, subtitle, icon) {
            _showMfCollectionInPanel(title, subtitle, icon);
          },
          onCategoryTap: (title, subtitle, icon) {
            _showMfCategoryInPanel(title, subtitle, icon);
          },
          onSipCalculatorTap: () {
            _showScreenInRightPanel(ScreenType.sipCalculator);
          },
          onCagrCalculatorTap: () {
            _showScreenInRightPanel(ScreenType.cagrCalculator);
          },
          onFundTap: (mfData) => showMfStockDetailInPanel(mfData),
        );
      case ScreenType.ipo:
        return const IPOScreen(isIpo: true);
      case ScreenType.mfNfo:
        return MFNFOScreenWeb(
          onBack: _goBackInRightPanel,
        );
      case ScreenType.bond:
        return const BondsScreenWeb(isBonds: true,);
      case ScreenType.scripDepthInfo:
        return Consumer(
          builder: (context, ref, _) {
            final args = _currentDepthArgs;
            if (args == null) {
              // PERFORMANCE FIX: Use .select() to only watch getQuotes
              // Watching entire marketWatchProvider causes unnecessary rebuilds
              final quotes =
                  ref.watch(marketWatchProvider.select((p) => p.getQuotes));
              final fallback =
                  ChartArgs(exch: 'NSE', tsym: 'Nifty 50', token: '26000');
              final token = quotes?.token?.toString() ?? fallback.token;
              final exch = quotes?.exch ?? fallback.exch;
              return ChartWithDepthWeb(
                // Don't use dynamic key - it destroys/recreates the widget (and chart iframe)
                // Instead, let didUpdateWidget handle symbol changes via postMessage
                wlValue: DepthInputArgs(
                  exch: exch,
                  token: token,
                  tsym: quotes?.tsym ?? fallback.tsym,
                  instname: quotes?.instname ?? '',
                  symbol: quotes?.symbol ?? '',
                  expDate: quotes?.expDate ?? '',
                  option: quotes?.option ?? '',
                ),
              );
            }
            // Don't use dynamic key - let didUpdateWidget handle symbol changes via postMessage
            return ChartWithDepthWeb(
              wlValue: args,
            );
          },
        );
      case ScreenType.optionChain:
        if (_optionChainArgs != null) {
          return OptionChainSSWeb(wlValue: _optionChainArgs!);
        }
        return const SizedBox.shrink();
      case ScreenType.pledgeUnpledge:
        return const PledgenUnpledge(ddd: "DDDDD");
      case ScreenType.corporateActions:
        return CAEventsScreenWeb(onBack: _goBackInRightPanel);
      case ScreenType.caBuyback:
        return CorporateActionsScreenWeb(onBack: _goBackInRightPanel);
      case ScreenType.clientMaster:
        return ClientMasterScreenWeb(onBack: _goBackInRightPanel);
      case ScreenType.reports:
        return ReportsScreenWeb(
          onNavigateToScreen: (screenType) {
            if (screenType is ScreenType) {
              _showScreenInRightPanel(screenType);
              _handleScreenTypeChange(screenType);
            }
          },
        );
      case ScreenType.ledger:
        return LedgerScreenWeb(onBack: _goBackInRightPanel);
      case ScreenType.contractNote:
        return ContractNoteScreenWeb(onBack: _goBackInRightPanel);
      case ScreenType.settings:
        return const ProfileMainScreen(initialIndex: 3);
      case ScreenType.tradeAction:
        // Get tab index from stored state or use null for default
        final tabIndex = _tradeActionTabIndex;
        // Use a key based on tabIndex to force recreation when tab changes
        return TradeActionScreenWeb(
          key: ValueKey('tradeAction_$tabIndex'),
          initialTabIndex: tabIndex,
        );
      case ScreenType.portfolioAnalysis:
        return const PortfolioDashboardScreen();
      case ScreenType.mfCollection:
        return SaveTaxesScreenWeb(
          title: _currentCollectionTitle ?? "Collection",
          subtitle: _currentCollectionSubtitle ?? "",
          icon: _currentCollectionIcon ?? "",
          onBack: _handleMfCollectionBack,
          onFundTap: (mfData) => showMfStockDetailInPanel(mfData),
        );
      case ScreenType.mfCategory:
        return MFCategoryListScreenWeb(
          title: _currentCategoryTitle ?? "Category",
          subtitle: _currentCategorySubtitle ?? "",
          icon: _currentCategoryIcon ?? "",
          onBack: _handleMfCategoryBack,
          onFundTap: (mfData) => showMfStockDetailInPanel(mfData),
        );
      case ScreenType.sipCalculator:
        return MFSIPSCREENWeb(
          onBack: _goBackInRightPanel,
        );
      case ScreenType.cagrCalculator:
        return MFCAGRCALWeb(
          onBack: _goBackInRightPanel,
        );
      case ScreenType.mfStockDetail:
        if (_currentMfStockData != null) {
          return MFStockDetailScreenWeb(
            mfStockData: _currentMfStockData!,
            onBack: _goBackInRightPanel,
          );
        }
        return const SizedBox.shrink();
      case ScreenType.notification:
        return const NotificationScreenWeb();
      case ScreenType.strategyBuilder:
        return const StrategyBuilderPanelWeb();
      case ScreenType.scalper:
        return const ScalperScreenWeb(embedded: true);
      case ScreenType.charts:
        return const ChartWorkspaceScreen();
      case ScreenType.tradingViewWebHook:
        return const WebHookTradingViewScreen();
      case ScreenType.basketDashboard:
        return StrategyDashboardScreenWeb(
          onCreateStrategy: () {
            _showScreenInRightPanel(ScreenType.createBasketStrategy);
          },
          onLoadStrategy: (_) {
            _showScreenInRightPanel(ScreenType.createBasketStrategy);
          },
          onBacktestStrategy: (_, __) {
            _showScreenInRightPanel(ScreenType.benchmarkBacktest);
          },
        );
      case ScreenType.createBasketStrategy:
        return CollectionBasketBuilder(
          onBack: _goBackInRightPanel,
        );
      case ScreenType.benchmarkBacktest:
        return BenchMarkBacktestScreenWeb(
          onBack: _goBackInRightPanel,
          onCustomize: () {
            _showScreenInRightPanel(ScreenType.createBasketStrategy);
          },
        );
      case ScreenType.saveBasketStrategy:
        return SaveStrategyScreenWeb(
          isCreateFlow: true,
          onBack: _goBackInRightPanel,
          onBacktest: () {
            _showScreenInRightPanel(ScreenType.benchmarkBacktest);
          },
        );
      case ScreenType.refer:
        return const ReferScreenWeb();
      case ScreenType.helpSupport:
        return const HelpSupportScreenWeb();
      case ScreenType.tradebook:
        return TradebookScreenWeb(onBack: _goBackInRightPanel);
      case ScreenType.calendarPnl:
        return CalenderpnlScreen(onBack: _goBackInRightPanel);
      case ScreenType.reportPositions:
        return PositionScreen(ddd: "DDDDD", onBack: _goBackInRightPanel);
      case ScreenType.pdfDownload:
        return PdfDownloadScreenWeb(onBack: _goBackInRightPanel);
      case ScreenType.taxPnl:
        return TaxPnlScreenWeb(onBack: _goBackInRightPanel);
      case ScreenType.notionalPnl:
        return NotionalPnlScreenWeb(onBack: _goBackInRightPanel);
      case ScreenType.myAccount:
        return ProfileMainScreen(
          initialIndex: 0,
          onNavigateToScreen: (screenType) => _navigateToScreen(screenType),
        );
      case ScreenType.tradingPreferences:
        return TradingPreferencesScreenWeb(onBack: _goBackInRightPanel);
      case ScreenType.profileDetails:
        return ProfileDetailsScreenWeb(
          onBack: _goBackInRightPanel,
          digilockerCode: widget.digilockerCode,
          digilockerState: widget.digilockerState,
        );
      case ScreenType.bankDetails:
        return ProfileSectionScreenWeb(sectionTitle: 'Bank', onBack: _goBackInRightPanel);
      case ScreenType.depositoryDetails:
        return ProfileSectionScreenWeb(sectionTitle: 'Depository', onBack: _goBackInRightPanel);
      case ScreenType.mtfDetails:
        return ProfileSectionScreenWeb(sectionTitle: 'Margin Trading Facility (MTF)', onBack: _goBackInRightPanel);
      case ScreenType.nomineeDetails:
        return NomineeScreenWeb(onBack: _goBackInRightPanel);
      case ScreenType.formDownload:
        return FormDownloadScreenWeb(onBack: _goBackInRightPanel);
      case ScreenType.closureDetails:
        return ProfileSectionScreenWeb(sectionTitle: 'Closure', onBack: _goBackInRightPanel);
      case ScreenType.instaOptions:
        return const InstaOptionsShell();
      case ScreenType.scanner:
        return ScannerShellScreen(
          initialSubPage: widget.initialScannerSubPage,
          initialExplainArgs: widget.initialExplainArgs,
        );
      case ScreenType.orderflow:
        return const OrderflowShellScreen();
      case ScreenType.curatedStrategies:
        return AllStrategiesScreenWeb(onBack: _handleDashboardTap);
      case ScreenType.allAlgoStrategies:
        return AllAlgoStrategiesScreenWeb(onBack: _handleDashboardTap);
      // caEvent and cpAction removed
    }
  }

  String _getScreenTitle(ScreenType type) {
    switch (type) {
      case ScreenType.dashboard:
        return 'Dashboard';
      case ScreenType.watchlist:
        return 'Watchlist';
      case ScreenType.holdings:
        return 'Holdings';
      case ScreenType.positions:
        return 'Positions';
      case ScreenType.orderBook:
        return 'Order Book';
      case ScreenType.funds:
        return 'Funds';
      case ScreenType.mutualFund:
        return 'Mutual Fund';
      case ScreenType.ipo:
        return 'IPO';
      case ScreenType.mfNfo:
        return 'New Fund Offerings';
      case ScreenType.bond:
        return 'Bonds';
      case ScreenType.scripDepthInfo:
        return 'Chart View';
      case ScreenType.optionChain:
        return 'Option Chain';
      case ScreenType.pledgeUnpledge:
        return 'Pledge/Unpledge';
      case ScreenType.corporateActions:
        return 'Corporate Actions';
      case ScreenType.caBuyback:
        return 'Corporate Action';
      case ScreenType.clientMaster:
        return 'Client Master';
      case ScreenType.reports:
        return 'Reports';
      case ScreenType.ledger:
        return 'Ledger';
      case ScreenType.contractNote:
        return 'Contract Note';
      case ScreenType.settings:
        return 'Settings';
      case ScreenType.tradeAction:
        return 'Trade Action';
      case ScreenType.portfolioAnalysis:
        return 'Portfolio Analysis';
      case ScreenType.mfCollection:
        return 'Collections';

      case ScreenType.mfCategory:
        return 'Categories';
      case ScreenType.sipCalculator:
        return 'SIP Calculator';
      case ScreenType.cagrCalculator:
        return 'CAGR Calculator';
      case ScreenType.mfStockDetail:
        return 'Fund Details';
      case ScreenType.notification:
        return 'Notification';
      case ScreenType.strategyBuilder:
        return 'Strategy Builder';
      case ScreenType.scalper:
        return 'Scalper';
      case ScreenType.charts:
        return 'Charts';
      case ScreenType.tradingViewWebHook:
        return 'WebHook';
      case ScreenType.basketDashboard:
        return 'Baskets';
      case ScreenType.createBasketStrategy:
        return 'Create Strategy';
      case ScreenType.benchmarkBacktest:
        return 'Backtest Analysis';
      case ScreenType.saveBasketStrategy:
        return 'Save Strategy';
      case ScreenType.refer:
        return 'Refer & Earn';
      case ScreenType.helpSupport:
        return 'Help & Support';
      case ScreenType.tradebook:
        return 'Tradebook';
      case ScreenType.calendarPnl:
        return 'P&L Summary';
      case ScreenType.reportPositions:
        return 'Positions';
      case ScreenType.pdfDownload:
        return 'PDF Download';
      case ScreenType.taxPnl:
        return 'Tax P&L';
      case ScreenType.notionalPnl:
        return 'Notional P&L';
      case ScreenType.myAccount:
        return 'My Account';
      case ScreenType.tradingPreferences:
        return 'Trading Preferences';
      case ScreenType.profileDetails:
        return 'Profile Details';
      case ScreenType.bankDetails:
        return 'Bank';
      case ScreenType.depositoryDetails:
        return 'Depository';
      case ScreenType.mtfDetails:
        return 'Margin Trading Facility (MTF)';
      case ScreenType.nomineeDetails:
        return 'Nominee';
      case ScreenType.formDownload:
        return 'Form Download';
      case ScreenType.closureDetails:
        return 'Closure';
      case ScreenType.instaOptions:
        return 'InstaOptions Analytics';
      case ScreenType.scanner:
        return 'Scanner';
      case ScreenType.orderflow:
        return 'Orderflow';
      case ScreenType.curatedStrategies:
        return 'Strategies';
      case ScreenType.allAlgoStrategies:
        return 'Algo Strategies';
      // caEvent and cpAction removed
    }
  }

  IconData _getIconForScreenType(ScreenType type) {
    switch (type) {
      case ScreenType.dashboard:
        return Icons.dashboard;
      case ScreenType.watchlist:
        return Icons.list;
      case ScreenType.holdings:
        return Icons.inventory;
      case ScreenType.positions:
        return Icons.trending_up;
      case ScreenType.orderBook:
        return Icons.receipt;
      case ScreenType.funds:
        return Icons.account_balance;
      case ScreenType.mutualFund:
        return Icons.trending_up;
      case ScreenType.ipo:
        return Icons.public;
      case ScreenType.mfNfo:
        return Icons.card_giftcard;
      case ScreenType.bond:
        return Icons.account_balance;
      case ScreenType.scripDepthInfo:
        return Icons.analytics;
      case ScreenType.optionChain:
        return Icons.table_chart;
      case ScreenType.pledgeUnpledge:
        return Icons.security;
      case ScreenType.corporateActions:
        return Icons.business;
      case ScreenType.caBuyback:
        return Icons.business_center_outlined;
      case ScreenType.clientMaster:
        return Icons.description;
      case ScreenType.reports:
        return Icons.assessment;
      case ScreenType.ledger:
        return Icons.account_balance_wallet;
      case ScreenType.contractNote:
        return Icons.description;
      case ScreenType.settings:
        return Icons.settings;
      case ScreenType.tradeAction:
        return Icons.trending_up;
      case ScreenType.portfolioAnalysis:
        return Icons.pie_chart;
      case ScreenType.mfCollection:
        return Icons.collections_bookmark;

      case ScreenType.mfCategory:
        return Icons.category;
      case ScreenType.sipCalculator:
        return Icons.calculate;
      case ScreenType.cagrCalculator:
        return Icons.calculate;
      case ScreenType.mfStockDetail:
        return Icons.show_chart;
      case ScreenType.notification:
        return Icons.notifications_outlined;
      case ScreenType.strategyBuilder:
        return Icons.architecture;
      case ScreenType.scalper:
        return Icons.speed;
      case ScreenType.charts:
        return Icons.show_chart;
      case ScreenType.tradingViewWebHook:
        return Icons.webhook;
      case ScreenType.basketDashboard:
        return Icons.shopping_basket;
      case ScreenType.createBasketStrategy:
        return Icons.add_circle_outline;
      case ScreenType.benchmarkBacktest:
        return Icons.analytics;
      case ScreenType.saveBasketStrategy:
        return Icons.save;
      case ScreenType.refer:
        return Icons.card_giftcard;
      case ScreenType.helpSupport:
        return Icons.headset_mic_outlined;
      case ScreenType.tradebook:
        return Icons.receipt_long;
      case ScreenType.calendarPnl:
        return Icons.calendar_month;
      case ScreenType.reportPositions:
        return Icons.trending_up;
      case ScreenType.pdfDownload:
        return Icons.picture_as_pdf;
      case ScreenType.taxPnl:
        return Icons.receipt_long;
      case ScreenType.notionalPnl:
        return Icons.bar_chart;
      case ScreenType.myAccount:
        return Icons.person_outline;
      case ScreenType.tradingPreferences:
        return Icons.tune;
      case ScreenType.profileDetails:
        return Icons.person;
      case ScreenType.bankDetails:
        return Icons.account_balance;
      case ScreenType.depositoryDetails:
        return Icons.inventory;
      case ScreenType.mtfDetails:
        return Icons.trending_up;
      case ScreenType.nomineeDetails:
        return Icons.people;
      case ScreenType.formDownload:
        return Icons.download;
      case ScreenType.closureDetails:
        return Icons.cancel;
      case ScreenType.instaOptions:
        return Icons.candlestick_chart;
      case ScreenType.scanner:
        return Icons.radar;
      case ScreenType.orderflow:
        return Icons.show_chart;
      case ScreenType.curatedStrategies:
        return Icons.auto_awesome;
      case ScreenType.allAlgoStrategies:
        return Icons.smart_toy_outlined;
      // caEvent and cpAction removed
    }
  }

  String _getScreenTitleNullable(ScreenType? type) {
    if (type == null) return 'Empty';
    return _getScreenTitle(type);
  }

  IconData _getIconForScreenTypeNullable(ScreenType? type) {
    if (type == null) return Icons.add;
    return _getIconForScreenType(type);
  }

  void _swapPanels(PanelConfig draggedPanel, PanelConfig targetPanel) {
    setState(() {
      // Find the indices of both panels
      final draggedIndex = _panels.indexWhere((p) => p.id == draggedPanel.id);
      final targetIndex = _panels.indexWhere((p) => p.id == targetPanel.id);

      if (draggedIndex != -1 &&
          targetIndex != -1 &&
          draggedIndex != targetIndex) {
        // Check if watchlist is involved in the swap
        bool draggedHasWatchlist = _panels[draggedIndex].screenType ==
                ScreenType.watchlist ||
            (_panels[draggedIndex].screens.isNotEmpty &&
                _panels[draggedIndex].screens.contains(ScreenType.watchlist));
        bool targetHasWatchlist = _panels[targetIndex].screenType ==
                ScreenType.watchlist ||
            (_panels[targetIndex].screens.isNotEmpty &&
                _panels[targetIndex].screens.contains(ScreenType.watchlist));

        // Swap the screen types
        final tempScreenType = _panels[draggedIndex].screenType;
        _panels[draggedIndex].screenType = _panels[targetIndex].screenType;
        _panels[targetIndex].screenType = tempScreenType;

        // Swap the multiple screens structure
        final tempScreens =
            List<ScreenType>.from(_panels[draggedIndex].screens);
        final tempActiveScreenIndex = _panels[draggedIndex].activeScreenIndex;

        _panels[draggedIndex].screens =
            List<ScreenType>.from(_panels[targetIndex].screens);
        _panels[draggedIndex].activeScreenIndex =
            _panels[targetIndex].activeScreenIndex;

        _panels[targetIndex].screens = tempScreens;
        _panels[targetIndex].activeScreenIndex = tempActiveScreenIndex;

        // Also swap the panel properties to maintain consistency
        final tempWidth = _panels[draggedIndex].width;
        final tempHeight = _panels[draggedIndex].height;
        final tempVisible = _panels[draggedIndex].isVisible;

        _panels[draggedIndex].width = _panels[targetIndex].width;
        _panels[draggedIndex].height = _panels[targetIndex].height;
        _panels[draggedIndex].isVisible = _panels[targetIndex].isVisible;

        _panels[targetIndex].width = tempWidth;
        _panels[targetIndex].height = tempHeight;
        _panels[targetIndex].isVisible = tempVisible;

        // If watchlist was involved in the swap, ensure the non-watchlist panel is active
        if (draggedHasWatchlist || targetHasWatchlist) {
          // Find which panel doesn't have watchlist
          int nonWatchlistPanelIndex = -1;

          for (int i = 0; i < _panels.length; i++) {
            bool hasWatchlist = _panels[i].screenType == ScreenType.watchlist ||
                (_panels[i].screens.isNotEmpty &&
                    _panels[i].screens.contains(ScreenType.watchlist));

            if (!hasWatchlist &&
                (_panels[i].screenType != null ||
                    _panels[i].screens.isNotEmpty)) {
              nonWatchlistPanelIndex = i;
              break;
            }
          }

          // If we found a non-watchlist panel, ensure it's active
          if (nonWatchlistPanelIndex != -1 &&
              _panels[nonWatchlistPanelIndex].screens.isNotEmpty) {
            // Set the active screen to the first non-watchlist screen
            for (int i = 0;
                i < _panels[nonWatchlistPanelIndex].screens.length;
                i++) {
              if (_panels[nonWatchlistPanelIndex].screens[i] !=
                  ScreenType.watchlist) {
                _panels[nonWatchlistPanelIndex].activeScreenIndex = i;
                break;
              }
            }
          }
        }
      }
    });
  }

  // Handle swap button press - swaps the positions of both panels
  void _handleSwapPanels() {
    setState(() {
      // Make sure we have exactly 2 panels
      if (_panels.length == 2) {
        // Swap the screen types between the two panels
        final tempScreenType = _panels[0].screenType;
        _panels[0].screenType = _panels[1].screenType;
        _panels[1].screenType = tempScreenType;

        // Swap the multiple screens structure
        final tempScreens = List<ScreenType>.from(_panels[0].screens);
        final tempActiveScreenIndex = _panels[0].activeScreenIndex;

        _panels[0].screens = List<ScreenType>.from(_panels[1].screens);
        _panels[0].activeScreenIndex = _panels[1].activeScreenIndex;

        _panels[1].screens = tempScreens;
        _panels[1].activeScreenIndex = tempActiveScreenIndex;

        // Also swap the panel properties to maintain consistency
        final tempWidth = _panels[0].width;
        final tempHeight = _panels[0].height;
        final tempVisible = _panels[0].isVisible;

        _panels[0].width = _panels[1].width;
        _panels[0].height = _panels[1].height;
        _panels[0].isVisible = _panels[1].isVisible;

        _panels[1].width = tempWidth;
        _panels[1].height = tempHeight;
        _panels[1].isVisible = tempVisible;
      }
    });

    // Save the layout
    _saveLayout();
  }

  // Show add screen dialog
  void _showAddScreenDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer(
          builder: (context, ref, child) {
            final theme = ref.watch(themeProvider);
            return AlertDialog(
              backgroundColor: resolveThemeColor(context,
                  dark: MyntColors.backgroundColorDark,
                  light: MyntColors.backgroundColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.iconDark,
                          light: MyntColors.icon,
                        ),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add Screen',
                        style: MyntWebTextStyles.head(
                          context,
                          fontWeight: MyntFonts.bold,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: colors.colorGrey,
                      size: 24,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 300,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...ScreenType.values
                          .where((screenType) =>
                              screenType != ScreenType.watchlist)
                          .map((screenType) =>
                              _buildScreenOption(screenType, theme)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Build screen option in dialog
  Widget _buildScreenOption(ScreenType screenType, ThemesProvider theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // Find first empty panel or first panel if all are filled
          int targetIndex = _getFirstAvailablePanelIndex();

          setState(() {
            _panels[targetIndex].screenType = screenType;
            _panels[targetIndex].screens = [screenType];
            _panels[targetIndex].activeScreenIndex = 0;
          });
          _saveLayout();
          // Call the appropriate handler function for the new screen type
          _handleScreenTypeChange(screenType);
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.isDarkMode
                ? colors.colorGrey.withOpacity(0.1)
                : colors.colorGrey.withOpacity(0.05),
            border: Border.all(
              color: theme.isDarkMode
                  ? colors.colorGrey.withOpacity(0.2)
                  : colors.colorGrey.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForScreenType(screenType),
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary,
                  ),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getScreenTitle(screenType),
                  style: MyntWebTextStyles.body(
                    context,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.iconDark,
                  light: MyntColors.icon,
                ),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Get the first available panel index
  int _getFirstAvailablePanelIndex() {
    for (int i = 0; i < _panels.length; i++) {
      if (_panels[i].screenType == null && _panels[i].screens.isEmpty) {
        return i;
      }
    }
    return 0; // Return first panel if all are filled
  }

  // Handle screen type change - calls appropriate handler based on screen type
  void _handleScreenTypeChange(ScreenType screenType) {
    // Update subscription manager with active screen
    _updateSubscriptionManagerForPanels();

    // Cancel position polling timer when navigating away from reportPositions
    if (screenType != ScreenType.reportPositions) {
      ref.read(ledgerProvider).ccancelalltimes();
    }

    // Only call handlers if this is not the initial load
    if (_isInitialLoad) {
      return;
    }

    switch (screenType) {
      case ScreenType.dashboard:
        _handleDashboardTap();
        break;
      case ScreenType.watchlist:
        _handleWatchlistTap();
        break;
      case ScreenType.holdings:
        _handleHoldingsTap();
        break;
      case ScreenType.positions:
        _handlePositionsTap();
        break;
      case ScreenType.orderBook:
        _handleOrderBookTap();
        break;
      case ScreenType.funds:
        _handleFundsTap();
        break;
      case ScreenType.mutualFund:
        _handleMutualFundTap();
        break;
      case ScreenType.ipo:
        _handleIPOTap();
        break;
      case ScreenType.mfNfo:
        break;
      case ScreenType.bond:
        _handleBondTap();
        break;
      case ScreenType.scripDepthInfo:
        _handleScripDepthInfoTap();
        break;
      case ScreenType.optionChain:
        // Option chain shows derivatives data; pause other streams similar to scrip depth
        _handleScripDepthInfoTap();
        break;
      case ScreenType.pledgeUnpledge:
        _handlePledgeUnpledgeTap();
        break;
      case ScreenType.corporateActions:
        _handleCorporateActionsTap();
        break;
      case ScreenType.caBuyback:
        _handleCABuybackTap();
        break;
      case ScreenType.clientMaster:
        _addScreenAsPanelTab(ScreenType.clientMaster);
        break;
      case ScreenType.reports:
        _handleReportsTap();
        break;
      case ScreenType.ledger:
        _handleLedgerTap();
        break;
      case ScreenType.contractNote:
        break;
      case ScreenType.settings:
        _handleSettingsTap();
        break;
      case ScreenType.tradeAction:
        _handleTradeActionTap();
        break;
      case ScreenType.portfolioAnalysis:
        _handlePortfolioAnalysisTap();
        break;
      case ScreenType.notification:
        _handleNotificationTap();
        break;
      case ScreenType.mfCollection:
      case ScreenType.mfCategory:
      case ScreenType.sipCalculator:
      case ScreenType.cagrCalculator:
      case ScreenType.mfStockDetail:
      case ScreenType.strategyBuilder:
      case ScreenType.tradingViewWebHook:
      case ScreenType.basketDashboard:
      case ScreenType.createBasketStrategy:
      case ScreenType.benchmarkBacktest:
      case ScreenType.saveBasketStrategy:
        break;
      case ScreenType.scalper:
        setState(() => _isScalperMode = true);
        break;
      case ScreenType.charts:
        setState(() => _isChartsMode = true);
        break;
      case ScreenType.refer:
        break;
      case ScreenType.helpSupport:
        break;
      case ScreenType.tradebook:
        break;
      case ScreenType.calendarPnl:
        break;
      case ScreenType.reportPositions:
        ref.read(ledgerProvider).fetchposition(context);
        break;
      case ScreenType.pdfDownload:
        break;
      case ScreenType.taxPnl:
        break;
      case ScreenType.notionalPnl:
        break;
      case ScreenType.myAccount:
        break;
      case ScreenType.tradingPreferences:
        break;
      case ScreenType.profileDetails:
        break;
      case ScreenType.bankDetails:
        break;
      case ScreenType.depositoryDetails:
        break;
      case ScreenType.mtfDetails:
        break;
      case ScreenType.nomineeDetails:
        break;
      case ScreenType.formDownload:
        break;
      case ScreenType.closureDetails:
        break;
      case ScreenType.instaOptions:
        break;
      case ScreenType.scanner:
        _replaceScreenInPanel(ScreenType.scanner);
        break;
      case ScreenType.orderflow:
        _replaceScreenInPanel(ScreenType.orderflow);
        break;
      case ScreenType.curatedStrategies:
        _replaceScreenInPanel(ScreenType.curatedStrategies);
        break;
      case ScreenType.allAlgoStrategies:
        _replaceScreenInPanel(ScreenType.allAlgoStrategies);
        break;
      // caEvent and cpAction removed
    }
  }

  // Handle scrip depth info tap
  void _handleScripDepthInfoTap() async {
    final portfolio = ref.read(portfolioProvider);

    portfolio.cancelTimer();

    // Unsubscribe from other real-time data
    await portfolio.requestWSHoldings(context: context, isSubscribe: false);
    await portfolio.requestWSPosition(context: context, isSubscribe: false);
    await ref
        .read(orderProvider)
        .requestWSOrderBook(context: context, isSubscribe: false);
  }

  // Clean up websocket subscriptions and cache for a specific screen
  void _cleanupScreenResources(ScreenType? screenType) {
    if (screenType == null) return;

    // Check if widget is still mounted before cleanup
    if (!mounted) {
      return;
    }

    try {
      switch (screenType) {
        case ScreenType.holdings:
          if (mounted) {
            ref
                .read(portfolioProvider)
                .requestWSHoldings(context: context, isSubscribe: false);
          }
          _clearScreenCache(screenType);
          break;

        case ScreenType.positions:
          if (mounted) {
            ref
                .read(portfolioProvider)
                .requestWSPosition(context: context, isSubscribe: false);
          }
          _clearScreenCache(screenType);
          break;

        case ScreenType.orderBook:
          if (mounted) {
            // Unsubscribe from current active tab when leaving order book screen
            ref.read(orderProvider).unsubscribeFromCurrentTab(context);
          }
          break;

        case ScreenType.funds:
          _clearScreenCache(screenType);
          break;

        case ScreenType.scripDepthInfo:
          _clearScreenCache(screenType);
          break;

        case ScreenType.optionChain:
          _clearScreenCache(screenType);
          break;

        default:
          _clearScreenCache(screenType);
          break;
      }
    } catch (e) {}
  }

  // Clear cache for a specific screen type
  void _clearScreenCache(ScreenType? screenType) {
    if (screenType == null) return;

    try {
      final websocket = ref.read(websocketProvider);
      int removedCount = 0;

      // CRITICAL FIX: Build a set of protected tokens that should NOT be removed
      // These are tokens visible in other screens (watchlist, depth panel, etc.)
      final protectedTokens = <String>{};

      // Protect watchlist tokens - always visible in left panel
      final marketWatch = ref.read(marketWatchProvider);
      for (var scrip in marketWatch.scrips) {
        final token = scrip['token']?.toString();
        if (token != null && token.isNotEmpty) {
          protectedTokens.add(token);
        }
      }

      // Protect current depth symbol token
      if (_currentDepthArgs != null) {
        protectedTokens.add(_currentDepthArgs!.token);
      }

      // Protect holdings tokens if holdings panel is active elsewhere
      for (var panel in _panels) {
        if (panel.screenType == ScreenType.holdings) {
          final holdingsModel = ref.read(portfolioProvider).holdingsModel;
          if (holdingsModel != null) {
            for (var holding in holdingsModel) {
              for (var exchTsym in holding.exchTsym ?? []) {
                if (exchTsym.token != null) {
                  protectedTokens.add(exchTsym.token!);
                }
              }
            }
          }
        }
        // Protect positions tokens if positions panel is active elsewhere
        if (panel.screenType == ScreenType.positions) {
          final positionsList = ref.read(portfolioProvider).allPostionList;
          for (var position in positionsList) {
            if (position.token != null) {
              protectedTokens.add(position.token!);
            }
          }
        }
      }

      // Get tokens/data specific to this screen type and clear them
      // ONLY if they are not protected by other active screens
      switch (screenType) {
        case ScreenType.holdings:
          final holdingsModel = ref.read(portfolioProvider).holdingsModel;
          if (holdingsModel != null) {
            for (var holding in holdingsModel) {
              // Get tokens from ExchTsym list within each holding
              for (var exchTsym in holding.exchTsym ?? []) {
                if (exchTsym.token != null && exchTsym.token!.isNotEmpty) {
                  // Only remove if NOT protected by watchlist or other screens
                  if (!protectedTokens.contains(exchTsym.token) &&
                      websocket.socketDatas.containsKey(exchTsym.token)) {
                    websocket.socketDatas.remove(exchTsym.token);
                    removedCount++;
                  }
                }
              }
            }
          }
          break;

        case ScreenType.positions:
          final positionsList = ref.read(portfolioProvider).allPostionList;
          for (var position in positionsList) {
            if (position.token != null && position.token!.isNotEmpty) {
              // Only remove if NOT protected by watchlist or other screens
              if (!protectedTokens.contains(position.token) &&
                  websocket.socketDatas.containsKey(position.token)) {
                websocket.socketDatas.remove(position.token);
                removedCount++;
              }
            }
          }
          break;

        case ScreenType.orderBook:
          final orderProv = ref.read(orderProvider);
          // Collect all tokens from open orders, executed orders, trade book, and GTT
          final orderTokens = <String>{};
          for (var order in orderProv.openOrder ?? []) {
            if (order.token != null && order.token!.isNotEmpty) {
              orderTokens.add(order.token!);
            }
          }
          for (var order in orderProv.executedOrder ?? []) {
            if (order.token != null && order.token!.isNotEmpty) {
              orderTokens.add(order.token!);
            }
          }
          for (var trade in orderProv.tradeBook ?? []) {
            if (trade.token != null && trade.token!.isNotEmpty) {
              orderTokens.add(trade.token!);
            }
          }
          for (var gtt in orderProv.gttOrderBookModel ?? []) {
            final token = gtt.token?.toString();
            if (token != null && token.isNotEmpty) {
              orderTokens.add(token);
            }
          }
          // Remove non-protected order tokens from socketDatas
          for (var token in orderTokens) {
            if (!protectedTokens.contains(token) &&
                websocket.socketDatas.containsKey(token)) {
              websocket.socketDatas.remove(token);
              removedCount++;
            }
          }
          break;

        default:
          break;
      }

      if (removedCount > 0) {
      }
    } catch (e) {
    }
  }

  // Show ScripDepthInfo in a panel
  void showScripDepthInfoInPanel(dynamic watchListData) {
    // Accept DepthInputArgs and store as current selection
    if (watchListData is DepthInputArgs) {
      _currentDepthArgs = watchListData;
    }
    // Check if scrip details already exist in any panel
    for (int i = 0; i < _panels.length; i++) {
      final panel = _panels[i];
      bool hasScripDetails = panel.screenType == ScreenType.scripDepthInfo ||
          (panel.screens.isNotEmpty &&
              panel.screens.contains(ScreenType.scripDepthInfo));

      if (hasScripDetails) {
        // Scrip details already exist, switch to that panel instead of creating duplicate
        setState(() {
          _panels[i].activeScreenIndex =
              panel.screens.indexOf(ScreenType.scripDepthInfo);
          if (_panels[i].activeScreenIndex == -1) {
            _panels[i].activeScreenIndex = 0;
          }
        });
        _saveLayout();
        return; // Exit early to prevent duplicate
      }
    }

    // Find the best panel to replace with scrip depth (prefer non-watchlist panels)
    int targetPanelIndex = -1;

    // Find any non-watchlist panel to replace
    for (int i = 0; i < _panels.length; i++) {
      final panel = _panels[i];
      bool hasWatchlist = panel.screenType == ScreenType.watchlist ||
          (panel.screens.isNotEmpty &&
              panel.screens.contains(ScreenType.watchlist));

      // Use first non-watchlist panel
      if (!hasWatchlist) {
        targetPanelIndex = i;
        break;
      }
    }

    // If no suitable panel found, use left panel (index 0)
    if (targetPanelIndex == -1) {
      targetPanelIndex = 0;
    }

    // Replace the screen with ScripDepthInfo (don't add as tab)
    setState(() {
      // Store the previous screen type for cleanup if needed
      ScreenType? previousScreenType = _panels[targetPanelIndex].screenType;

      // Replace the entire screen with scrip depth info
      _panels[targetPanelIndex].screens = [ScreenType.scripDepthInfo];
      _panels[targetPanelIndex].activeScreenIndex = 0;
      _panels[targetPanelIndex].screenType = ScreenType.scripDepthInfo;

      // Clean up resources from the replaced screen
      if (previousScreenType != null &&
          previousScreenType != ScreenType.scripDepthInfo) {
        _cleanupScreenResources(previousScreenType);
      }
    });

    // Update subscription manager
    _updateSubscriptionManagerForPanels();

    _saveLayout();

    // Call the handler for the new screen type
    _handleScreenTypeChange(ScreenType.scripDepthInfo);
  }

  // Show OrderBook in a panel
  void showOrderBookInPanel() {
    // Check if order book already exists in any panel
    for (int i = 0; i < _panels.length; i++) {
      final panel = _panels[i];
      bool hasOrderBook = panel.screenType == ScreenType.orderBook ||
          (panel.screens.isNotEmpty &&
              panel.screens.contains(ScreenType.orderBook));

      if (hasOrderBook) {
        // Order book already exists, switch to that panel instead of creating duplicate
        setState(() {
          _panels[i].activeScreenIndex =
              panel.screens.indexOf(ScreenType.orderBook);
          if (_panels[i].activeScreenIndex == -1) {
            _panels[i].activeScreenIndex = 0;
          }
        });
        _saveLayout();
        return; // Exit early to prevent duplicate
      }
    }

    // Find the panel that doesn't have watchlist (prefer left panel)
    int targetPanelIndex = -1;
    for (int i = 0; i < _panels.length; i++) {
      final panel = _panels[i];
      bool hasWatchlist = panel.screenType == ScreenType.watchlist ||
          (panel.screens.isNotEmpty &&
              panel.screens.contains(ScreenType.watchlist));

      if (!hasWatchlist) {
        targetPanelIndex = i;
        break;
      }
    }

    // If no panel without watchlist found, use the left panel (index 0) - avoid right panel with watchlist
    if (targetPanelIndex == -1) {
      targetPanelIndex =
          0; // Always use left panel to avoid replacing watchlist
    }

    // Set the OrderBook screen in the target panel
    setState(() {
      _panels[targetPanelIndex].screenType = ScreenType.orderBook;
      _panels[targetPanelIndex].screens = [ScreenType.orderBook];
      _panels[targetPanelIndex].activeScreenIndex = 0;
    });

    // Update subscription manager
    _updateSubscriptionManagerForPanels();

    _saveLayout();

    // Call the handler for the new screen type
    _handleScreenTypeChange(ScreenType.orderBook);
  }

  // Show Trade Action in a panel
  void showTradeActionInPanel({int? tabIndex}) {
    // Check if trade action already exists in any panel
    for (int i = 0; i < _panels.length; i++) {
      final panel = _panels[i];
      bool hasTradeAction = panel.screenType == ScreenType.tradeAction ||
          (panel.screens.isNotEmpty &&
              panel.screens.contains(ScreenType.tradeAction));

      if (hasTradeAction) {
        // Trade action already exists, update the tab index and switch to that panel
        setState(() {
          _panels[i].activeScreenIndex =
              panel.screens.indexOf(ScreenType.tradeAction);
          if (_panels[i].activeScreenIndex == -1) {
            _panels[i].activeScreenIndex = 0;
          }
          // Update the tab index even if screen already exists
          _tradeActionTabIndex = tabIndex;
        });
        _saveLayout();
        // Force a rebuild to update the tab
        if (mounted) {
          setState(() {});
        }
        return; // Exit early to prevent duplicate
      }
    }

    // Find the panel that doesn't have watchlist (prefer left panel)
    int targetPanelIndex = -1;
    for (int i = 0; i < _panels.length; i++) {
      final panel = _panels[i];
      bool hasWatchlist = panel.screenType == ScreenType.watchlist ||
          (panel.screens.isNotEmpty &&
              panel.screens.contains(ScreenType.watchlist));

      if (!hasWatchlist) {
        targetPanelIndex = i;
        break;
      }
    }

    // If no panel without watchlist found, use the left panel (index 0) - avoid right panel with watchlist
    if (targetPanelIndex == -1) {
      targetPanelIndex =
          0; // Always use left panel to avoid replacing watchlist
    }

    // Set the Trade Action screen in the target panel
    setState(() {
      _panels[targetPanelIndex].screenType = ScreenType.tradeAction;
      _panels[targetPanelIndex].screens = [ScreenType.tradeAction];
      _panels[targetPanelIndex].activeScreenIndex = 0;
      // Store the tab index for the screen
      _tradeActionTabIndex = tabIndex;
    });

    // Update subscription manager
    _updateSubscriptionManagerForPanels();

    _saveLayout();

    // Call the handler for the new screen type
    _handleScreenTypeChange(ScreenType.tradeAction);
  }

  // Show Option Chain in a panel
  void showOptionChainInPanel(DepthInputArgs args) {
    // Check if already exists
    for (int i = 0; i < _panels.length; i++) {
      final panel = _panels[i];
      bool exists = panel.screenType == ScreenType.optionChain ||
          (panel.screens.isNotEmpty &&
              panel.screens.contains(ScreenType.optionChain));
      if (exists) {
        setState(() {
          _optionChainArgs = args;
          _panels[i].activeScreenIndex =
              panel.screens.indexOf(ScreenType.optionChain);
          if (_panels[i].activeScreenIndex == -1) {
            _panels[i].activeScreenIndex = 0;
          }
        });
        _saveLayout();
        return;
      }
    }
    int targetPanelIndex = -1;
    for (int i = 0; i < _panels.length; i++) {
      final panel = _panels[i];
      bool hasWatchlist = panel.screenType == ScreenType.watchlist ||
          (panel.screens.isNotEmpty &&
              panel.screens.contains(ScreenType.watchlist));
      if (!hasWatchlist) {
        targetPanelIndex = i;
        break;
      }
    }
    if (targetPanelIndex == -1) targetPanelIndex = _panels.length > 1 ? 1 : 0;
    setState(() {
      _optionChainArgs = args;
      _panels[targetPanelIndex].screenType = ScreenType.optionChain;
      _panels[targetPanelIndex].screens = [ScreenType.optionChain];
      _panels[targetPanelIndex].activeScreenIndex = 0;
    });

    // Update subscription manager
    _updateSubscriptionManagerForPanels();

    _saveLayout();
  }

  // caEvent and cpAction handlers removed

  // Initialize default screen data after initial load
  void _initializeDefaultScreenData() {
    if (_panels.length >= 2) {
      // Left panel should have watchlist - move any other screens to right panel
      if (_panels[0].screenType != null &&
          _panels[0].screenType != ScreenType.watchlist) {
        // Move the screen from left panel to right panel
        _panels[1].screenType = _panels[0].screenType;
        _panels[1].screens = List<ScreenType>.from(_panels[0].screens);
        _panels[1].activeScreenIndex = _panels[0].activeScreenIndex;

        // Clear left panel and set watchlist
        _panels[0].screenType = ScreenType.watchlist;
        _panels[0].screens = [ScreenType.watchlist];
        _panels[0].activeScreenIndex = 0;
      }

      // Initialize watchlist on left panel if it exists
      if (_panels[0].screenType == ScreenType.watchlist) {
        _handleWatchlistTap();
      }

      // Initialize the screen on the right panel (which is now the primary content panel)
      if (_panels[1].screenType != null) {
        if (_panels[1].screenType == ScreenType.dashboard) {
          _handleDashboardTap();
        } else if (_panels[1].screenType == ScreenType.watchlist) {
          _handleWatchlistTap();
        } else if (_panels[1].screenType == ScreenType.holdings) {
          _handleHoldingsTap();
        } else if (_panels[1].screenType == ScreenType.positions) {
          _handlePositionsTap();
        } else if (_panels[1].screenType == ScreenType.orderBook) {
          _handleOrderBookTap();
        } else if (_panels[1].screenType == ScreenType.funds) {
          _handleFundsTap();
        }
      }

      // NOTE: Don't call _updateSubscriptionManagerForPanels() here
      // Each screen handler (dashboard, holdings, etc.) calls it AFTER their async
      // data fetching completes. Calling it here causes a race condition where
      // subscriptions happen before data is ready (e.g., trade action stocks empty).

      // Ensure websocket connections are established for real-time data
      if (mounted &&
          ref.read(networkStateProvider).connectionStatus !=
              ConnectivityResult.none) {
        _handleWebSocketConnections();
      }

      // Always fetch positions for ticker header regardless of initial screen
      // Ticker needs live position P&L data on all screens
      _initializeTickerData();
    }
  }

  /// Initialize ticker data by fetching positions
  /// Called once on initial load to ensure ticker has data regardless of initial screen
  void _initializeTickerData() {
    // If positions screen or dashboard is active, positions are already being fetched
    // by their respective handlers. Only fetch if not already fetching.
    final rightPanelScreen = _panels.length > 1 ? _panels[1].screenType : null;
    if (rightPanelScreen == ScreenType.positions ||
        rightPanelScreen == ScreenType.dashboard) {
      // Positions will be fetched by the screen handler
      return;
    }

    // Fetch positions in background for ticker header
    Future.microtask(() async {
      if (!mounted) return;

      final portfolio = ref.read(portfolioProvider);

      // Only fetch if positions haven't been fetched yet
      if (portfolio.postionBookModel == null ||
          portfolio.postionBookModel!.isEmpty) {
        await portfolio.fetchPositionBook(context, false);

        // Subscribe ticker symbols after positions are fetched
        if (mounted) {
          final subscriptionManager = ref.read(webSubscriptionManagerProvider);
          subscriptionManager.subscribeTickerSymbols(context);
        }
      }
    });
  }

  // Debounce timer to prevent rapid subscription manager updates
  Timer? _subscriptionUpdateDebounceTimer;
  static const Duration _subscriptionUpdateDebounceDelay =
      Duration(milliseconds: 200);

  // Track last update to prevent duplicate calls
  Map<int, ScreenType?> _lastSubscriptionUpdate = {};

  // Update subscription manager based on current active panels (with debouncing)
  // Set forceRefresh=true to refresh subscriptions even if screen hasn't changed
  // (useful when data becomes available after initial load)
  void _updateSubscriptionManagerForPanels({bool forceRefresh = false}) {
    // For forceRefresh calls, execute immediately to avoid race conditions
    // where multiple handlers might cancel each other's debounced timers
    if (forceRefresh) {
      _performSubscriptionManagerUpdate(forceRefresh: true);
      return;
    }

    // Cancel any pending debounce timer
    _subscriptionUpdateDebounceTimer?.cancel();

    // Debounce the update to prevent rapid calls
    _subscriptionUpdateDebounceTimer =
        Timer(_subscriptionUpdateDebounceDelay, () {
      _performSubscriptionManagerUpdate(forceRefresh: forceRefresh);
    });
  }

  /// Actually perform the subscription manager update (called after debounce)
  /// Set forceRefresh=true to refresh subscriptions even if screen hasn't changed
  void _performSubscriptionManagerUpdate({bool forceRefresh = false}) {
    final subscriptionManager = ref.read(webSubscriptionManagerProvider);

    // Ensure WebSocket is connected before attempting subscriptions
    subscriptionManager.ensureConnected(context);

    // Update subscription manager for each panel
    for (int i = 0; i < _panels.length; i++) {
      final panel = _panels[i];
      ScreenType? activeScreen;

      if (panel.screens.isNotEmpty &&
          panel.activeScreenIndex >= 0 &&
          panel.activeScreenIndex < panel.screens.length) {
        activeScreen = panel.screens[panel.activeScreenIndex];
      } else {
        activeScreen = panel.screenType;
      }

      // Only update if the screen actually changed, OR if forceRefresh is true
      final lastScreen = _lastSubscriptionUpdate[i];
      if (forceRefresh || lastScreen != activeScreen) {
        // For force refresh, pass null as previous to trigger fresh subscription
        if (forceRefresh && lastScreen == activeScreen) {
          subscriptionManager.refreshCurrentScreen(i, activeScreen);
        } else {
          subscriptionManager.updateActiveScreen(i, activeScreen);
        }
        _lastSubscriptionUpdate[i] = activeScreen;
      }
    }
  }

  // Individual screen type handlers (based on home_screen.dart)
  void _handleDashboardTap() async {
    // Replace screen immediately for instant UI response
    _replaceScreenInPanel(ScreenType.dashboard);

    // Move all async operations to background to prevent blocking UI
    Future.microtask(() async {
      if (!mounted) return;

      final indexProvider = ref.read(indexListProvider);
      final stocksProvider = ref.read(stocksProvide);
      final portfolio = ref.read(portfolioProvider);

      portfolio.cancelTimer();

      // Ensure top indices are fetched before WebSubscriptionManager subscribes
      // Only fetch if not already available to avoid duplicate API calls
      if (indexProvider.topIndicesForDashboard == null && mounted) {
        await indexProvider.getTopIndicesForDashboard(context);
      }

      if (!mounted) return;

      // Fetch trade action data only if not already available
      // This prevents duplicate TopList API calls when clicking dashboard multiple times
      if (stocksProvider.topGainers.isEmpty &&
          stocksProvider.topLosers.isEmpty) {
        await stocksProvider.fetchTradeAction(
            "NSE", "NSEALL", "topG_L", "topG_L");
      }

      if (!mounted) return;

      if (stocksProvider.byValue.isEmpty && stocksProvider.byVolume.isEmpty) {
        await stocksProvider.fetchTradeAction(
            "NSE", "NSEALL", "mostActive", "mostActive");
      }

      if (!mounted) return;

      // Fetch holdings for dashboard stats with "Refresh" to trigger websocket subscription
      await portfolio.fetchHoldings(context, "Refresh");

      // Wait for WebSocket data to arrive and updateHoldingValues() to calculate profitNloss
      // for all holdings. Without this delay, pnlHoldCal() reads stale values because
      // the WebSocket stream broadcasts BEFORE updateHoldingValues() processes the data.
      await Future.delayed(const Duration(milliseconds: 500));

      // Calculate holdings totals after WebSocket data has been processed
      if (mounted) {
        portfolio.pnlHoldCal();
      }

      if (!mounted) return;

      // Fetch positions for dashboard stats and subscribe to WebSocket for live updates
      await portfolio.fetchPositionBook(context, false);
      // Subscribe position tokens to WebSocket for real-time price updates
      if (mounted) {
        portfolio.requestWSPosition(context: context, isSubscribe: true);
      }

      // Subscribe ticker symbols (positions) for persistent ticker header updates
      if (mounted) {
        final subscriptionManager = ref.read(webSubscriptionManagerProvider);
        subscriptionManager.subscribeTickerSymbols(context);
      }

      // Update subscription manager AFTER data is fetched
      // Use forceRefresh=true to ensure subscriptions are updated even if
      // the screen was already set (e.g., initial load where data wasn't ready)
      if (mounted) {
        _updateSubscriptionManagerForPanels(forceRefresh: true);
      }
    });
  }

  void _handleWatchlistTap() async {
    final portfolio = ref.read(portfolioProvider);
    portfolio.cancelTimer();

    // Unsubscribe positions when leaving dashboard/positions (non-blocking)
    portfolio.requestWSPosition(context: context, isSubscribe: false);

    // Ensure watchlist data is loaded before subscribing
    // This prevents the timing issue where subscription happens before data is ready
    Future.microtask(() async {
      if (!mounted) return;

      final marketWatch = ref.read(marketWatchProvider);

      // Fetch watchlist list if not available
      if (marketWatch.marketWatchlist == null ||
          (marketWatch.marketWatchlist?.values?.isEmpty ?? true)) {
        if (!mounted) return;
        await marketWatch.fetchMWList(context, true);
      }

      if (!mounted) return;

      // Fetch current watchlist scrips if not available
      final scrips = marketWatch.marketWatchScrip?.values;
      if (scrips == null || scrips.isEmpty) {
        final currentWL = marketWatch.wlName;
        if (currentWL.isNotEmpty && mounted) {
          await marketWatch.fetchMWScrip(currentWL, context);
        }
      }

      // Update subscription manager AFTER data is fetched
      // Use forceRefresh=true to ensure subscriptions are updated
      if (mounted) {
        _updateSubscriptionManagerForPanels(forceRefresh: true);
      }
    });
  }

  void _handleMutualFundTap() {
    // Replace screen immediately for instant UI response
    _replaceScreenInPanel(ScreenType.mutualFund);

    // Allow UI to update first, then do background work
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        if (!mounted) return;

        final portfolio = ref.read(portfolioProvider);
        portfolio.cancelTimer();

        // Unsubscribe positions when leaving dashboard/positions (non-blocking)
        portfolio.requestWSPosition(context: context, isSubscribe: false);

        // Call MF API methods to fetch data
        ref.read(mfProvider).fetchnewMFBestList();
        // ref.read(mfProvider).fetchMFCategoryList("Z", "Z");
        ref.read(mfProvider).fetchmfallcatnew();
        ref.read(mfProvider).fetchmfNFO(context);
      });
    });
  }

  // Check if there are any screens available to add to a panel
  bool _hasAvailableScreensToAdd(PanelConfig panel) {
    return ScreenType.values
        .where((screenType) => _shouldShowScreenOption(screenType, panel))
        .isNotEmpty;
  }

  void _replaceScreenInPanel(ScreenType screenType) {
    // Exit scalper / charts mode when switching to any other screen
    if (_isScalperMode && screenType != ScreenType.scalper) {
      _isScalperMode = false;
    }
    if (_isChartsMode && screenType != ScreenType.charts) {
      _isChartsMode = false;
    }

    int targetPanelIndex = -1;
    for (int i = 0; i < _panels.length; i++) {
      final panel = _panels[i];
      bool hasWatchlist = panel.screenType == ScreenType.watchlist ||
          (panel.screens.isNotEmpty &&
              panel.screens.contains(ScreenType.watchlist));

      if (!hasWatchlist) {
        targetPanelIndex = i;
        break;
      }
    }

    // If no panel without watchlist found, use the left panel (index 0)
    if (targetPanelIndex == -1) {
      targetPanelIndex = 0;
    }

    // WebSubscriptionManager handles smart unsubscription via _updateSubscriptionManagerForPanels()
    // called below — it protects shared tokens (watchlist, positions, holdings, ticker, etc.)
    // Do NOT clear _socketDatas here — the ticker needs position token data on all screens

    setState(() {
      _panels[targetPanelIndex].screenType = screenType;
      _panels[targetPanelIndex].screens = [screenType];
      _panels[targetPanelIndex].activeScreenIndex = 0;
    });

    // Update browser URL for web navigation
    _updateUrlForScreenType(screenType);

    // Update subscription manager
    _updateSubscriptionManagerForPanels();

    // Save layout in background (non-blocking)
    Future.microtask(() => _saveLayout());
  }

  /// Update browser URL based on the current screen type
  void _updateUrlForScreenType(ScreenType screenType) {
    String? urlPath;
    switch (screenType) {
      case ScreenType.holdings:
        urlPath = WebRoutes.holdings;
        break;
      case ScreenType.positions:
        urlPath = WebRoutes.positions;
        break;
      case ScreenType.orderBook:
        urlPath = WebRoutes.orders;
        break;
      case ScreenType.funds:
        urlPath = WebRoutes.funds;
        break;
      case ScreenType.ipo:
        urlPath = WebRoutes.ipo;
        break;
      case ScreenType.bond:
        urlPath = WebRoutes.bonds;
        break;
      case ScreenType.myAccount:
        urlPath = WebRoutes.myAccount;
        break;
      case ScreenType.refer:
        urlPath = WebRoutes.refer;
        break;
      case ScreenType.helpSupport:
        urlPath = WebRoutes.helpSupport;
        break;
      case ScreenType.settings:
        urlPath = WebRoutes.settings;
        break;
      case ScreenType.notification:
        urlPath = WebRoutes.notification;
        break;
      case ScreenType.pledgeUnpledge:
        urlPath = WebRoutes.pledge;
        break;
      case ScreenType.mutualFund:
        urlPath = WebRoutes.mutualFunds;
        break;
      case ScreenType.optionChain:
        urlPath = WebRoutes.optionChain;
        break;
      case ScreenType.portfolioAnalysis:
        urlPath = '/portfolio-analysis';
        break;
      case ScreenType.reports:
        urlPath = WebRoutes.reports;
        break;
      case ScreenType.caBuyback:
        urlPath = WebRoutes.caBuyback;
        break;
      case ScreenType.ledger:
        urlPath = '/ledger';
        break;
      case ScreenType.contractNote:
        urlPath = '/contract-note';
        break;
      case ScreenType.strategyBuilder:
        urlPath = WebRoutes.strategyBuilder;
        break;
      case ScreenType.charts:
        urlPath = WebRoutes.charts;
        break;
      case ScreenType.tradingViewWebHook:
        urlPath = WebRoutes.tradingViewWebHook;
        break;
      case ScreenType.basketDashboard:
        urlPath = WebRoutes.basketDashboard;
        break;
      case ScreenType.dashboard:
      case ScreenType.watchlist:
        urlPath = WebRoutes.home;
        break;
      case ScreenType.scanner:
        urlPath = WebRoutes.scanner;
        break;
      case ScreenType.orderflow:
        urlPath = WebRoutes.orderflow;
        break;
      default:
        // Don't update URL for other screen types (like scripDepthInfo, etc.)
        urlPath = null;
        break;
    }

    if (urlPath != null) {
      WebNavigationHelper.updateUrl(urlPath);
    }
  }

  // Add screen as a panel tab (only for profile screens)
  void _addScreenAsPanelTab(ScreenType screenType) {
    // Find the first available panel (preferably left panel)
    for (int i = 0; i < _panels.length; i++) {
      // Check if screen already exists in this panel
      bool alreadyExists = _panels[i].screens.contains(screenType);

      if (alreadyExists) {
        // Switch to existing tab
        setState(() {
          _panels[i].activeScreenIndex = _panels[i].screens.indexOf(screenType);
          _panels[i].screenType =
              screenType; // Update for backward compatibility
        });
        _saveLayout();
        return;
      }
    }

    // Screen doesn't exist, add to left panel (index 0)
    if (_panels.isNotEmpty) {
      setState(() {
        _panels[0].screens.add(screenType);
        _panels[0].activeScreenIndex = _panels[0].screens.length - 1;
        _panels[0].screenType = screenType; // Update for backward compatibility
      });
      _saveLayout();
      // Call the appropriate handler function for the new screen type
      _handleScreenTypeChange(screenType);
    }
  }

  void _handleOrderBookTap() async {
    // Replace screen immediately - no loading state needed
    // OrderBookScreenWeb will handle its own loading gracefully
    _replaceScreenInPanel(ScreenType.orderBook);

    // Move all async operations to background to prevent blocking UI
    Future.microtask(() async {
      if (!mounted) return;

      final portfolio = ref.read(portfolioProvider);
      portfolio.cancelTimer();

      // Unsubscribe positions when leaving dashboard/positions (non-blocking)
      portfolio.requestWSPosition(context: context, isSubscribe: false);

      final orderProviderRef = ref.read(orderProvider);

      // Check if request is already in progress (prevents duplicate calls on rapid clicks)
      if (_isRequestInProgress('order_book')) {
        return;
      }

      // Mark request as started
      _markRequestStarted('order_book');

      try {
        // Preserve current tab selection - don't reset to tab 0 unless this is first load
        final currentTab = orderProviderRef.selectedTab;

        // Only fetch Open + Executed orders on entry (same API).
        // Trade Book, GTT, SIP, Basket, Alerts load lazily on tab click.
        await orderProviderRef.fetchOrderBook(context, false);

        // SIP will be lazy loaded when user switches to that tab
        // This is handled in OrderProvider.changeTabIndex()

        // Order book handles its own tab-specific subscriptions
        if (mounted) {
          // Preserve the selected tab if user was previously on order book
          // Only reset to tab 0 if the current tab is out of bounds
          final tabToSelect = (currentTab >= 0 && currentTab <= 5) ? currentTab : 0;

          // Only change tab if different from current
          if (orderProviderRef.selectedTab != tabToSelect) {
            orderProviderRef.changeTabIndex(tabToSelect, context);
          }

          // Force WebSocket subscription for current tab's order tokens
          orderProviderRef.requestWSOrderBook(isSubscribe: true, context: context);
        }

        // Update subscription manager (order book is now SubscriptionType.none, so it won't subscribe)
        if (mounted) {
          _updateSubscriptionManagerForPanels();
        }
      } finally {
        // Always mark request as completed
        _markRequestCompleted('order_book');
      }
    });
  }

  void _handleIPOTap() async {
    // Set loading state immediately
    setState(() {
      _screenLoadingStates[ScreenType.ipo] = true;
    });

    // Replace screen immediately for instant UI response - this triggers setState synchronously
    _replaceScreenInPanel(ScreenType.ipo);

    // Allow UI to update first, then do background work
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() async {
        if (!mounted) return;

        final portfolio = ref.read(portfolioProvider);
        final ipoProvider = ref.read(ipoProvide);
        final authProvi = ref.read(authProvider);

        portfolio.cancelTimer();

        // Unsubscribe from other real-time data (non-blocking)
        portfolio.requestWSHoldings(context: context, isSubscribe: false);
        portfolio.requestWSPosition(context: context, isSubscribe: false);
        ref
            .read(orderProvider)
            .requestWSOrderBook(context: context, isSubscribe: false);

        // Fetch IPO data in the background (non-blocking)
        if (mounted) {
          authProvi.setIposAPicalls(context);
          ipoProvider.getipoorderbookmodel(context, true);

          // Clear loading state after data is fetched
          if (mounted) {
            setState(() {
              _screenLoadingStates[ScreenType.ipo] = false;
            });
          }
        }
      });
    });
  }

  void _handleBondTap() async {
    setState(() {
      _screenLoadingStates[ScreenType.bond] = true;
    });
    final portfolio = ref.read(portfolioProvider);
    _replaceScreenInPanel(ScreenType.bond);
    WidgetsBinding.instance.addPostFrameCallback((_) async{

    portfolio.cancelTimer();

    // Unsubscribe from other real-time data
    // await ref.read(marketWatchProvider).requestMWScrip(context: context, isSubscribe: false);
    await portfolio.requestWSHoldings(context: context, isSubscribe: false);
    await portfolio.requestWSPosition(context: context, isSubscribe: false);
    await ref
        .read(orderProvider)
        .requestWSOrderBook(context: context, isSubscribe: false);

    // Fetch Bond data in the background
    Future.microtask(() {
      if (mounted) {
        ref.read(bondsProvider).fetchAllBonds();
        if (mounted) {
          setState(() {
            _screenLoadingStates[ScreenType.bond] = false;
          });
        }
      }
    });
    });
  }

  /// Handle browser back/forward navigation
  /// Maps URL paths to screen handlers without adding new history entries
  void _handleBrowserNavigation(String urlPath) {
    if (!mounted) return;


    // Map URL path to screen type and navigate
    switch (urlPath) {
      case WebRoutes.holdings: // '/holdings'
        _handleHoldingsTap();
        break;
      case WebRoutes.positions: // '/positions'
        _handlePositionsTap();
        break;
      case WebRoutes.orders: // '/orders'
        _handleOrderBookTap();
        break;
      case WebRoutes.funds: // '/funds'
        _handleFundsTap();
        break;
      case WebRoutes.ipo: // '/ipo'
        _handleIPOTap();
        break;
      case WebRoutes.bonds: // '/bonds'
        _handleBondTap();
        break;
      case WebRoutes.scalper: // '/scalper'
        _handleScalperTap();
        break;
      case WebRoutes.charts: // '/charts'
        _handleChartsTap();
        break;
      case WebRoutes.myAccount: // '/my-account'
        _navigateToScreen(ScreenType.myAccount);
        break;
      case WebRoutes.refer: // '/refer'
        _navigateToScreen(ScreenType.refer);
        break;
      case WebRoutes.helpSupport: // '/help-support'
        _navigateToScreen(ScreenType.helpSupport);
        break;
      case WebRoutes.settings: // '/settings'
        _handleSettingsTap();
        break;
      case WebRoutes.notification: // '/notification'
        _navigateToScreen(ScreenType.notification);
        break;
      case WebRoutes.pledge: // '/pledge'
        _navigateToScreen(ScreenType.pledgeUnpledge);
        break;
      case WebRoutes.mutualFunds: // '/mutual-funds'
        _handleMutualFundTap();
        break;
      case WebRoutes.reports: // '/reports'
        _handleReportsTap();
        break;
      case WebRoutes.strategyBuilder: // '/strategy-builder'
        _handleStrategyBuilderTap();
        break;
      case WebRoutes.tradingViewWebHook: // '/tradingview-webhook'
        _handleWebHookTap();
        break;
      case WebRoutes.basketDashboard: // '/basket-dashboard'
        _handleBasketDashboardTap();
        break;
      case WebRoutes.optionChain: // '/option-chain'
        // Option chain requires arguments, navigate to dashboard instead
        _handleDashboardTap();
        break;
      case WebRoutes.strategyBuilder: // '/strategy-builder'
        _handleStrategyBuilderTap();
        break;
      case WebRoutes.home: // '/'
      default:
        _handleDashboardTap();
        break;
    }
  }

  // New handler methods for separate portfolio screens
  void _handleHoldingsTap({int initialTabIndex = 0}) async {
    // Set loading state immediately
    setState(() {
      _holdingsInitialTabIndex = initialTabIndex;
      _holdingsTabRequestId++;
      _screenLoadingStates[ScreenType.holdings] = true;
    });

    // Replace screen immediately for instant UI response
    _replaceScreenInPanel(ScreenType.holdings);

    // Move all async operations to background to prevent blocking UI
    Future.microtask(() async {
      if (!mounted) return;

      final portfolio = ref.read(portfolioProvider);
      portfolio.cancelTimer();

      // Unsubscribe positions when leaving dashboard/positions (non-blocking)
      portfolio.requestWSPosition(context: context, isSubscribe: false);

      // Check if request is already in progress (prevents duplicate calls on rapid clicks)
      if (_isRequestInProgress('holdings')) {
        if (mounted) {
          setState(() {
            _screenLoadingStates[ScreenType.holdings] = false;
          });
        }
        return;
      }

      // Mark request as started
      _markRequestStarted('holdings');

      try {
        // Fetch holdings data BEFORE WebSubscriptionManager subscribes
        // This ensures tokens are available for subscription
        // Always fetch fresh data when switching to Holdings
        await portfolio.fetchHoldings(context, "");

        // Update subscription manager AFTER data is fetched
        // This ensures tokens are available for subscription
        // Use forceRefresh=true to ensure subscriptions update even on initial load
        if (mounted) {
          _updateSubscriptionManagerForPanels(forceRefresh: true);

          // Clear loading state after data is fetched
          setState(() {
            _screenLoadingStates[ScreenType.holdings] = false;
          });
        }
      } finally {
        // Always mark request as completed
        _markRequestCompleted('holdings');
      }
    });
  }

  void _handlePositionsTap() async {
    // Set loading state immediately
    setState(() {
      _screenLoadingStates[ScreenType.positions] = true;
    });

    // Replace screen immediately for instant UI response
    _replaceScreenInPanel(ScreenType.positions);

    // Move all async operations to background to prevent blocking UI
    Future.microtask(() async {
      if (!mounted) return;

      final portfolio = ref.read(portfolioProvider);
      portfolio.cancelTimer();

      // Check if request is already in progress (prevents duplicate calls on rapid clicks)
      if (_isRequestInProgress('positions')) {
        if (mounted) {
          setState(() {
            _screenLoadingStates[ScreenType.positions] = false;
          });
        }
        return;
      }

      // Mark request as started
      _markRequestStarted('positions');

      try {
        // Fetch positions data BEFORE WebSubscriptionManager subscribes
        // This ensures tokens are available for subscription
        // Always fetch fresh data when switching to Positions
        await portfolio.fetchPositionBook(context, false);

        // Start position update timer
        if (mounted) {
          portfolio.timerfunc();

          // Subscribe ticker symbols (positions) for persistent ticker header updates
          final subscriptionManager = ref.read(webSubscriptionManagerProvider);
          subscriptionManager.subscribeTickerSymbols(context);

          // Update subscription manager AFTER data is fetched
          // This ensures tokens are available for subscription
          // Use forceRefresh=true to ensure subscriptions update even on initial load
          _updateSubscriptionManagerForPanels(forceRefresh: true);

          // Clear loading state after data is fetched
          setState(() {
            _screenLoadingStates[ScreenType.positions] = false;
          });
        }
      } finally {
        // Always mark request as completed
        _markRequestCompleted('positions');
      }
    });
  }

  void _handleFundsTap({String? initialAction}) async {
    // Set loading state immediately
    setState(() {
      _screenLoadingStates[ScreenType.funds] = true;
      _fundsInitialAction = initialAction;
    });

    // Replace screen immediately for instant UI response - this triggers setState synchronously
    _replaceScreenInPanel(ScreenType.funds);

    // Allow UI to update first, then do background work
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() async {
        if (!mounted) return;

        final portfolio = ref.read(portfolioProvider);
        final orderProviderRef = ref.read(orderProvider);
        final fundProviderRef = ref.read(fundProvider);

        portfolio.cancelTimer();

        // Unsubscribe from other real-time data (non-blocking)
        orderProviderRef.requestWSOrderBook(
            context: context, isSubscribe: false);
        portfolio.requestWSHoldings(context: context, isSubscribe: false);
        portfolio.requestWSPosition(context: context, isSubscribe: false);

        // Fetch funds data in the background (non-blocking)
        if (mounted) {
          await fundProviderRef.fetchFunds(context);

          // Clear loading state after data is fetched
          if (mounted) {
            setState(() {
              _screenLoadingStates[ScreenType.funds] = false;
            });
          }
        }
      });
    });
  }

  void _handlePledgeUnpledgeTap() async {
    // Add pledge/unpledge as a panel tab
    _addScreenAsPanelTab(ScreenType.pledgeUnpledge);

    final portfolio = ref.read(portfolioProvider);
    final reportsprovider = ref.read(ledgerProvider);

    portfolio.cancelTimer();

    // Unsubscribe from other real-time data
    // await ref.read(marketWatchProvider).requestMWScrip(context: context, isSubscribe: false);
    await portfolio.requestWSHoldings(context: context, isSubscribe: false);
    await portfolio.requestWSPosition(context: context, isSubscribe: false);
    await ref
        .read(orderProvider)
        .requestWSOrderBook(context: context, isSubscribe: false);

    // Fetch pledge/unpledge data
    if (reportsprovider.pledgeandunpledge == null) {
      await reportsprovider.getCurrentDate("pandu");
      reportsprovider.fetchpledgeandunpledge(context);
    }
  }

  // Handle CA Buyback / Takeover / OFS tap (Profile dropdown → "Corporate Action")
  void _handleCABuybackTap() async {
    _addScreenAsPanelTab(ScreenType.caBuyback);

    final portfolio = ref.read(portfolioProvider);
    final reportsprovider = ref.read(ledgerProvider);

    portfolio.cancelTimer();

    await portfolio.requestWSHoldings(context: context, isSubscribe: false);
    await portfolio.requestWSPosition(context: context, isSubscribe: false);
    await ref
        .read(orderProvider)
        .requestWSOrderBook(context: context, isSubscribe: false);

    if (reportsprovider.cpactiondata == null &&
        reportsprovider.cpactionloader != true) {
      reportsprovider.fetchcpactiondata(context);
    }
  }

  // Handle corporate actions tap
  void _handleCorporateActionsTap() async {
    // Add corporate actions as a panel tab
    _addScreenAsPanelTab(ScreenType.corporateActions);

    final portfolio = ref.read(portfolioProvider);
    final reportsprovider = ref.read(ledgerProvider);

    portfolio.cancelTimer();

    // Unsubscribe from other real-time data
    // await ref.read(marketWatchProvider).requestMWScrip(context: context, isSubscribe: false);
    await portfolio.requestWSHoldings(context: context, isSubscribe: false);
    await portfolio.requestWSPosition(context: context, isSubscribe: false);
    await ref
        .read(orderProvider)
        .requestWSOrderBook(context: context, isSubscribe: false);

    // Fetch corporate actions data
    if (reportsprovider.holdingsAllData == null ||
        reportsprovider.cpactiondata == null) {
      if (reportsprovider.cpactionloader != true) {
        if (reportsprovider.cpactiondata == null) {
          reportsprovider.fetchcpactiondata(context);
        }
      }
      if (reportsprovider.holdingsloading != true) {
        await reportsprovider.getCurrentDate('else');
        if (reportsprovider.holdingsAllData == null) {
          await reportsprovider.fetchholdingsData(
              reportsprovider.today, context);
        }
      }
    }
  }

  // Handle reports tap
  void _handleReportsTap() async {
    // Show reports in the right (content) panel. `_addScreenAsPanelTab` adds
    // to panel 0, but panel 0 is the watchlist panel and renders watchlist
    // regardless of its screens list — so the tab would be invisible.
    _replaceScreenInPanel(ScreenType.reports);

    final portfolio = ref.read(portfolioProvider);
    final reportsprovider = ref.read(ledgerProvider);

    portfolio.cancelTimer();

    // Unsubscribe from other real-time data
    // await ref.read(marketWatchProvider).requestMWScrip(context: context, isSubscribe: false);
    await portfolio.requestWSHoldings(context: context, isSubscribe: false);
    await portfolio.requestWSPosition(context: context, isSubscribe: false);
    await ref
        .read(orderProvider)
        .requestWSOrderBook(context: context, isSubscribe: false);

    // No API pre-fetching here — each report screen fetches its own data
    // when opened, with cache guards to prevent duplicates.

     if (reportsprovider.calenderpnlAllData == null) {
      await reportsprovider.getCurrentDate('else');
      reportsprovider.calendarProvider();
      reportsprovider.fetchcalenderpnldata(
          context, reportsprovider.startDate, reportsprovider.today, 'Equity');
    }
  }

  // Handle ledger tap — date context only, LedgerScreenWeb handles its own fetch
  void _handleLedgerTap() async {
    final reportsprovider = ref.read(ledgerProvider);
    await reportsprovider.getCurrentDate('else');
  }

  // Handle settings tap
  void _handleSettingsTap() async {
    // Show settings in the right (content) panel — panel 0 always renders
    // watchlist, so `_addScreenAsPanelTab` would add an invisible tab.
    _replaceScreenInPanel(ScreenType.settings);

    final portfolio = ref.read(portfolioProvider);

    portfolio.cancelTimer();

    // Unsubscribe from other real-time data
    // await ref.read(marketWatchProvider).requestMWScrip(context: context, isSubscribe: false);
    await portfolio.requestWSHoldings(context: context, isSubscribe: false);
    await portfolio.requestWSPosition(context: context, isSubscribe: false);
    await ref
        .read(orderProvider)
        .requestWSOrderBook(context: context, isSubscribe: false);
  }

  // Handle portfolio analysis tap
  void _handlePortfolioAnalysisTap() async {

    // Set loading state immediately
    setState(() {
      _screenLoadingStates[ScreenType.portfolioAnalysis] = true;
    });

    // Replace screen in panel (right panel) immediately for instant UI response
    _replaceScreenInPanel(ScreenType.portfolioAnalysis);

    // Move all async operations to background to prevent blocking UI
    Future.microtask(() async {
      if (!mounted) return;

      final portfolio = ref.read(portfolioProvider);
      final dashboard = ref.read(dashboardProvider);

      portfolio.cancelTimer();

      // Unsubscribe from other real-time data
      await portfolio.requestWSHoldings(context: context, isSubscribe: false);
      await portfolio.requestWSPosition(context: context, isSubscribe: false);
      await ref
          .read(orderProvider)
          .requestWSOrderBook(context: context, isSubscribe: false);

      // Fetch portfolio analysis data
      if (dashboard.portfolioAnalysis == null) {
        await dashboard.getPortfolioAnalysis();
      }

      // Clear loading state
      if (mounted) {
        setState(() {
          _screenLoadingStates[ScreenType.portfolioAnalysis] = false;
        });
      }
    });
  }

  // Handle notification tap
  void _handleNotificationTap() async {
    final portfolio = ref.read(portfolioProvider);
    portfolio.cancelTimer();
  }

  // Handle trade action tap
  void _handleTradeActionTap() async {
    final portfolio = ref.read(portfolioProvider);
    final stocksProvider = ref.read(stocksProvide);

    portfolio.cancelTimer();

    // Unsubscribe from other real-time data
    await portfolio.requestWSHoldings(context: context, isSubscribe: false);
    await portfolio.requestWSPosition(context: context, isSubscribe: false);
    await ref
        .read(orderProvider)
        .requestWSOrderBook(context: context, isSubscribe: false);

    // Check if request is already in progress (prevents duplicate calls on rapid clicks)
    if (_isRequestInProgress('trade_action')) {
      return;
    }

    // Mark request as started
    _markRequestStarted('trade_action');

    try {
      // Fetch trade action data before WebSubscriptionManager subscribes
      // This ensures tokens are available for subscription
      // Always fetch fresh data when switching to Trade Action
      await stocksProvider.fetchTradeAction(
          "NSE", "NSEALL", "topG_L", "topG_L");
      await stocksProvider.fetchTradeAction(
          "NSE", "NSEALL", "mostActive", "mostActive");

      // WebSubscriptionManager will handle subscription after data is fetched
      // via _updateSubscriptionManagerForPanels() which is called when screen is added
    } finally {
      // Always mark request as completed
      _markRequestCompleted('trade_action');
    }
  }

  // Show screen in right panel (for app bar navigation)
  void _showScreenInRightPanel(ScreenType screenType) {
    if (_panels.isEmpty) return;

    // Find the non-watchlist panel (prefer right panel for multi-panel layouts)
    int targetPanelIndex = -1;

    // For multi-panel layouts, search from the end (right panel first)
    if (_panels.length >= 2) {
      for (int i = _panels.length - 1; i >= 0; i--) {
        final panel = _panels[i];
        bool hasWatchlist = panel.screenType == ScreenType.watchlist ||
            (panel.screens.isNotEmpty &&
                panel.screens.contains(ScreenType.watchlist));

        if (!hasWatchlist) {
          targetPanelIndex = i;
          break;
        }
      }
    }

    // For single panel or if no non-watchlist found, use first panel
    if (targetPanelIndex == -1) {
      targetPanelIndex = 0;
    }

    // Save current screen type for back navigation (push to stack)
    final currentScreen = _panels[targetPanelIndex].screenType;
    if (currentScreen != null) {
      _panelScreenHistory[targetPanelIndex] ??= [];
      _panelScreenHistory[targetPanelIndex]!.add(currentScreen);
    }

    setState(() {
      _panels[targetPanelIndex].screenType = screenType;
      _panels[targetPanelIndex].screens = [screenType];
      _panels[targetPanelIndex].activeScreenIndex = 0;
    });

    // Defer layout save to allow UI to update first
    Future.microtask(() => _saveLayout());
  }

  // Go back to previous screen in the right panel
  void _goBackInRightPanel() {
    if (_panels.isEmpty) return;

    // Find the non-watchlist panel (prefer last panel for multi-panel, first for single)
    int targetPanelIndex = -1;

    // For multi-panel layouts, search from the end (right panel first)
    if (_panels.length >= 2) {
      for (int i = _panels.length - 1; i >= 0; i--) {
        final panel = _panels[i];
        bool hasWatchlist = panel.screenType == ScreenType.watchlist ||
            (panel.screens.isNotEmpty &&
                panel.screens.contains(ScreenType.watchlist));

        if (!hasWatchlist) {
          targetPanelIndex = i;
          break;
        }
      }
    }

    // For single panel or if no non-watchlist found, use first panel
    if (targetPanelIndex == -1) {
      targetPanelIndex = 0;
    }

    // Get the previous screen type from stack
    final historyStack = _panelScreenHistory[targetPanelIndex];
    if (historyStack != null && historyStack.isNotEmpty) {
      // Cancel position polling timer when leaving reportPositions via back button
      if (_panels[targetPanelIndex].screenType == ScreenType.reportPositions) {
        ref.read(ledgerProvider).ccancelalltimes();
      }
      final previousScreen = historyStack.removeLast(); // Pop from stack
      setState(() {
        _panels[targetPanelIndex].screenType = previousScreen;
        _panels[targetPanelIndex].screens = [previousScreen];
        _panels[targetPanelIndex].activeScreenIndex = 0;
      });
      // Defer layout save to allow UI to update first
      Future.microtask(() => _saveLayout());
    }
  }

  // Show MF Collection in right panel
  void _showMfCollectionInPanel(String title, String subtitle, String icon) {
    _currentCollectionTitle = title;
    _currentCollectionSubtitle = subtitle;
    _currentCollectionIcon = icon;
    _showScreenInRightPanel(ScreenType.mfCollection);
  }

  // Handle back navigation from MF Collection
  void _handleMfCollectionBack() {
    _goBackInRightPanel();
  }

  // Show MF Category in right panel
  void _showMfCategoryInPanel(String title, String subtitle, String icon) {
    _currentCategoryTitle = title;
    _currentCategorySubtitle = subtitle;
    _currentCategoryIcon = icon;
    _showScreenInRightPanel(ScreenType.mfCategory);
  }

  // Handle back navigation from MF Category
  void _handleMfCategoryBack() {
    _goBackInRightPanel();
  }

  // Show MF Stock Detail in right panel
  void showMfStockDetailInPanel(MutualFundList mfData) {
    _currentMfStockData = mfData;
    _showScreenInRightPanel(ScreenType.mfStockDetail);
  }

  void _showScreenInLeftPanel(ScreenType screenType) {
    if (_panels.isEmpty) return;

    // Find the panel that doesn't have watchlist (prefer left panel for non-watchlist screens)
    int targetPanelIndex = -1;
    for (int i = 0; i < _panels.length; i++) {
      final panel = _panels[i];
      bool hasWatchlist = panel.screenType == ScreenType.watchlist ||
          (panel.screens.isNotEmpty &&
              panel.screens.contains(ScreenType.watchlist));

      if (!hasWatchlist) {
        targetPanelIndex = i;
        break;
      }
    }

    // If no panel without watchlist found, use the left panel (index 0)
    if (targetPanelIndex == -1) {
      targetPanelIndex = 0;
    }

    setState(() {
      _panels[targetPanelIndex].screenType = screenType;
      _panels[targetPanelIndex].screens = [screenType];
      _panels[targetPanelIndex].activeScreenIndex = 0;
    });

    // Defer layout save to allow UI to update first
    Future.microtask(() => _saveLayout());
  }

  // Check if screen option should be shown (hide duplicates only)
  bool _shouldShowScreenOption(ScreenType screenType, PanelConfig panel) {
    // Allow all screen types including app bar screens to be added as tabs

    // Check if current panel has watchlist
    bool panelHasWatchlist = panel.screenType == ScreenType.watchlist ||
        (panel.screens.isNotEmpty &&
            panel.screens.contains(ScreenType.watchlist));

    // If panel has watchlist, only allow watchlist to be added (no other screens)
    if (panelHasWatchlist) {
      if (screenType != ScreenType.watchlist) {
        return false; // Don't allow other screens in watchlist panel
      }
      // If it's watchlist, check if watchlist already exists
      bool hasWatchlist = panel.screenType == ScreenType.watchlist ||
          (panel.screens.isNotEmpty &&
              panel.screens.contains(ScreenType.watchlist));
      if (hasWatchlist) {
        return false; // Don't allow duplicate watchlist
      }
    }

    // Check if screen already exists in current panel
    bool alreadyExistsInPanel = panel.screens.contains(screenType);

    // Check if screen already exists in any other panel (for watchlist and scrip details)
    bool alreadyExistsInOtherPanel = false;
    if (screenType == ScreenType.watchlist ||
        screenType == ScreenType.scripDepthInfo) {
      for (int i = 0; i < _panels.length; i++) {
        if (i != _panels.indexOf(panel)) {
          final otherPanel = _panels[i];
          bool hasScreen = otherPanel.screenType == screenType ||
              (otherPanel.screens.isNotEmpty &&
                  otherPanel.screens.contains(screenType));
          if (hasScreen) {
            alreadyExistsInOtherPanel = true;
            break;
          }
        }
      }
    }

    // Hide if already exists in current panel or other panels
    return !alreadyExistsInPanel && !alreadyExistsInOtherPanel;
  }

  void _handleReconnectionSuccess() {
    if (!mounted) return;
    setState(() {});
  }

  Future<bool> showExitPopup() async {
    if (ref.read(userProfileProvider).showchartof) {
      ref.read(userProfileProvider).setChartdialog(false);
      ref.read(chartUpdateProvider).changeOrientation('portrait');

      final mktwth = ref.read(marketWatchProvider);
      mktwth.chngDephBtn("Overview");
      mktwth.singlePageloader(true);
      mktwth.calldepthApis(context, mktwth.getQuotes, "");
      mktwth.singlePageloader(false);

      if (mounted) setState(() {});
      ref.read(marketWatchProvider).setChartScript('NSE', '26000', 'Nifty 50');
      return false;
    } else {
      return 
      //await showDialog(
      //         context: context,
      //         builder: (BuildContext context) {
      //           final theme = ref.read(themeProvider);
      //           return AlertDialog(
      //               backgroundColor: resolveThemeColor(context,
      //                   dark: MyntColors.backgroundColorDark,
      //                   light: MyntColors.backgroundColor),
      //               titlePadding:
      //                   const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      //               shape: const RoundedRectangleBorder(
      //                   borderRadius: BorderRadius.all(Radius.circular(8))),
      //               scrollable: true,
      //               contentPadding: const EdgeInsets.symmetric(
      //                 horizontal: 12,
      //                 vertical: 12,
      //               ),
      //               actionsPadding: const EdgeInsets.only(
      //                   bottom: 16, right: 16, left: 16, top: 8),
      //               insetPadding: const EdgeInsets.symmetric(
      //                   horizontal: 30, vertical: 12),
      //               title: Column(
      //                 children: [
      //                   Row(
      //                     mainAxisAlignment: MainAxisAlignment.end,
      //                     children: [
      //                       Material(
      //                         color: Colors.transparent,
      //                         shape: const CircleBorder(),
      //                         child: InkWell(
      //                           onTap: () async {
      //                             await Future.delayed(
      //                                 const Duration(milliseconds: 150));
      //                             Navigator.of(context).pop(false);
      //                           },
      //                           borderRadius: BorderRadius.circular(20),
      //                           splashColor: resolveThemeColor(
      //                             context,
      //                             dark: MyntColors.rippleDark,
      //                             light: MyntColors.rippleLight,
      //                           ),
      //                           highlightColor: resolveThemeColor(
      //                             context,
      //                             dark: MyntColors.highlightDark,
      //                             light: MyntColors.highlightLight,
      //                           ),
      //                           child: Padding(
      //                             padding: const EdgeInsets.all(6.0),
      //                             child: Icon(
      //                               Icons.close_rounded,
      //                               size: 22,
      //                               color: resolveThemeColor(
      //                                 context,
      //                                 dark: MyntColors.iconDark,
      //                                 light: MyntColors.icon,
      //                               ),
      //                             ),
      //                           ),
      //                         ),
      //                       ),
      //                     ],
      //                   ),
      //                   const SizedBox(height: 12),
      //                   SizedBox(
      //                     width: MediaQuery.of(context).size.width,
      //                     child: Center(
      //                       child: Text(
      //                         "Do you want to Exit the App?",
      //                         style: MyntWebTextStyles.body(
      //                           context,
      //                           color: resolveThemeColor(
      //                             context,
      //                             dark: MyntColors.textPrimaryDark,
      //                             light: MyntColors.textPrimary,
      //                           ),
      //                         ),
      //                       ),
      //                     ),
      //                   ),
      //                 ],
      //               ),
      //               actions: [
      //                 SizedBox(
      //                   width: double.infinity,
      //                   child: OutlinedButton(
      //                     onPressed: () => Navigator.of(context).pop(true),
      //                     style: OutlinedButton.styleFrom(
      //                       minimumSize: const Size(0, 45),
      //                       side: BorderSide(
      //                           color: shadcn.Theme.of(context)
      //                               .colorScheme
      //                               .border),
      //                       shape: RoundedRectangleBorder(
      //                         borderRadius: BorderRadius.circular(5),
      //                       ),
      //                       backgroundColor: resolveThemeColor(
      //                         context,
      //                         dark: MyntColors.primaryDark,
      //                         light: MyntColors.primary,
      //                       ),
      //                     ),
      //                     child: Text(
      //                       "Exit",
      //                       style: MyntWebTextStyles.title(
      //                         context,
      //                         fontWeight: MyntFonts.bold,
      //                         color: resolveThemeColor(
      //                           context,
      //                           dark: MyntColors.textPrimaryDark,
      //                           light: MyntColors.textPrimary,
      //                         ),
      //                       ),
      //                     ),
      //                   ),
      //                 ),
      //               ]);
      //         }) ??
          false;
    }
  }
}

// Panel configuration class
class PanelConfig {
  final String id;
  ScreenType? screenType; // Allow null for empty slots
  List<ScreenType> screens; // Multiple screens for tabbed interface
  int activeScreenIndex; // Index of currently active screen
  double width; // As percentage of screen width (0.0 to 1.0)
  double height; // As percentage of screen height (0.0 to 1.0)
  bool isVisible;

  // Resize constraints
  double minWidth; // Minimum width in pixels
  double minHeight; // Minimum height in pixels
  double maxWidth; // Maximum width in pixels
  double maxHeight; // Maximum height in pixels

  // Current actual size in pixels
  double currentWidth;
  double currentHeight;

  // Resize capabilities
  bool enableHorizontalResize;
  bool enableVerticalResize;

  PanelConfig({
    required this.id,
    this.screenType,
    this.screens = const [],
    this.activeScreenIndex = 0,
    required this.width,
    required this.height,
    this.isVisible = true,
    this.minWidth = 150.0,
    this.minHeight = 150.0,
    this.maxWidth = double.infinity,
    this.maxHeight = double.infinity,
    this.currentWidth = 0.0,
    this.currentHeight = 0.0,
    this.enableHorizontalResize = true,
    this.enableVerticalResize = true,
  });

  PanelConfig copyWith({
    String? id,
    ScreenType? screenType,
    List<ScreenType>? screens,
    int? activeScreenIndex,
    double? width,
    double? height,
    bool? isVisible,
    double? minWidth,
    double? minHeight,
    double? maxWidth,
    double? maxHeight,
    double? currentWidth,
    double? currentHeight,
    bool? enableHorizontalResize,
    bool? enableVerticalResize,
  }) {
    return PanelConfig(
      id: id ?? this.id,
      screenType: screenType ?? this.screenType,
      screens: screens ?? this.screens,
      activeScreenIndex: activeScreenIndex ?? this.activeScreenIndex,
      width: width ?? this.width,
      height: height ?? this.height,
      isVisible: isVisible ?? this.isVisible,
      minWidth: minWidth ?? this.minWidth,
      minHeight: minHeight ?? this.minHeight,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
      currentWidth: currentWidth ?? this.currentWidth,
      currentHeight: currentHeight ?? this.currentHeight,
      enableHorizontalResize:
          enableHorizontalResize ?? this.enableHorizontalResize,
      enableVerticalResize: enableVerticalResize ?? this.enableVerticalResize,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'screenType': screenType?.name,
      'screens': screens.map((s) => s.name).toList(),
      'activeScreenIndex': activeScreenIndex,
      'width': width,
      'height': height,
      'isVisible': isVisible,
      'minWidth': minWidth,
      'minHeight': minHeight,
      'maxWidth': maxWidth.isFinite
          ? maxWidth
          : 999999.0, // Convert infinity to a large number
      'maxHeight': maxHeight.isFinite
          ? maxHeight
          : 999999.0, // Convert infinity to a large number
      'currentWidth': currentWidth,
      'currentHeight': currentHeight,
      'enableHorizontalResize': enableHorizontalResize,
      'enableVerticalResize': enableVerticalResize,
    };
  }

  factory PanelConfig.fromJson(Map<String, dynamic> json) {
    return PanelConfig(
      id: json['id'],
      screenType: json['screenType'] != null
          ? ScreenType.values.firstWhere((e) => e.name == json['screenType'])
          : null,
      screens: (json['screens'] as List<dynamic>? ?? [])
          .map((s) => ScreenType.values.firstWhere((e) => e.name == s))
          .toList(),
      activeScreenIndex: json['activeScreenIndex'] ?? 0,
      width: json['width'].toDouble(),
      height: json['height']?.toDouble() ?? 0.5,
      isVisible: json['isVisible'] ?? true,
      minWidth: json['minWidth']?.toDouble() ?? 150.0,
      minHeight: json['minHeight']?.toDouble() ?? 150.0,
      maxWidth: (json['maxWidth']?.toDouble() ?? 999999.0) >= 999999.0
          ? double.infinity
          : json['maxWidth']?.toDouble() ?? double.infinity,
      maxHeight: (json['maxHeight']?.toDouble() ?? 999999.0) >= 999999.0
          ? double.infinity
          : json['maxHeight']?.toDouble() ?? double.infinity,
      currentWidth: json['currentWidth']?.toDouble() ?? 0.0,
      currentHeight: json['currentHeight']?.toDouble() ?? 0.0,
      enableHorizontalResize: json['enableHorizontalResize'] ?? true,
      enableVerticalResize: json['enableVerticalResize'] ?? true,
    );
  }
}

// Screen types enum
enum ScreenType {
  dashboard,
  watchlist,
  holdings,
  positions,
  orderBook,
  funds,
  mutualFund,
  ipo,
  bond,
  scripDepthInfo,
  optionChain,
  pledgeUnpledge,
  corporateActions,
  caBuyback,
  reports,
  settings,
  tradeAction,
  mfNfo,
  mfCollection,

  mfCategory,
  sipCalculator,
  cagrCalculator,
  mfStockDetail,
  notification,
  portfolioAnalysis,
  strategyBuilder,
  scalper,
  charts,
  tradingViewWebHook,
  basketDashboard,
  createBasketStrategy,
  benchmarkBacktest,
  saveBasketStrategy,
  refer,
  helpSupport,
  ledger,
  contractNote,
  tradebook,
  calendarPnl,
  clientMaster,
  reportPositions,
  pdfDownload,
  taxPnl,
  notionalPnl,
  myAccount,
  tradingPreferences,
  profileDetails,
  bankDetails,
  depositoryDetails,
  mtfDetails,
  nomineeDetails,
  formDownload,
  closureDetails,
  instaOptions,
  scanner,
  orderflow,
  curatedStrategies,
  allAlgoStrategies,
}

// Hoverable navigation item widget
class _HoverableNavItem extends StatefulWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _HoverableNavItem({
    required this.title,
    required this.isActive,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  State<_HoverableNavItem> createState() => _HoverableNavItemState();
}

class _HoverableNavItemState extends State<_HoverableNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.isDarkMode;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: widget.onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            widget.title,
            style: MyntWebTextStyles.body(
              context,
              fontWeight: widget.isActive ? MyntFonts.bold : MyntFonts.semiBold,
              color: widget.isActive
                  ? resolveThemeColor(
                      context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary,
                    )
                  : (_isHovered
                      ? resolveThemeColor(
                          context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
                        ).withOpacity(0.8)
                      : resolveThemeColor(
                          context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary,
                        )),
            ),
          ),
        ),
      ),
    );
  }
}

// Lazy loading wrapper for OrderBookScreenWeb to prevent blocking UI
class _LazyOrderBookScreen extends ConsumerStatefulWidget {
  const _LazyOrderBookScreen();

  @override
  ConsumerState<_LazyOrderBookScreen> createState() =>
      _LazyOrderBookScreenState();
}

class _LazyOrderBookScreenState extends ConsumerState<_LazyOrderBookScreen> {
  bool _shouldLoad = false;

  @override
  void initState() {
    super.initState();
    // Defer widget creation using microtask to allow UI to render first
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _shouldLoad = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);

    // Show loader only during initial widget load phase (first 300ms)
    // After that, show the screen immediately - it can handle empty/loading states internally
    if (!_shouldLoad) {
      return _buildOrderBookLoadingIndicator(theme.isDarkMode);
    }
    // Show screen immediately - OrderBookScreenWeb has its own loading handling
    return const OrderBookScreenWeb();
  }

  Widget _buildOrderBookLoadingIndicator(bool isDarkMode) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      child: MyntLoader.branded(),
    );
  }
}

// AppBar Index Slot Widget
class _AppBarIndexSlot extends ConsumerStatefulWidget {
  final dynamic indexItem;
  final int indexPosition;
  final ThemesProvider theme;
  final dynamic marketWatch;
  final dynamic indexProvider;

  const _AppBarIndexSlot({
    required this.indexItem,
    required this.indexPosition,
    required this.theme,
    required this.marketWatch,
    required this.indexProvider,
  });

  @override
  ConsumerState<_AppBarIndexSlot> createState() => _AppBarIndexSlotState();
}

class _AppBarIndexSlotState extends ConsumerState<_AppBarIndexSlot> {
  bool _isHovered = false;

  Future<void> _handleTap(BuildContext context) async {
    try {
      await widget.indexProvider.fetchIndexList("NSE", context);
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
      await widget.indexProvider.fetchIndexList("exit", context);
      await widget.marketWatch
          .requestMWScrip(context: context, isSubscribe: true);
    } catch (e) {
    }
  }

  Future<void> _handleIndexClick(BuildContext context) async {
    try {
      await widget.marketWatch.fetchScripQuoteIndex(
          widget.indexItem.token?.toString() ?? "",
          widget.indexItem.exch?.toString() ?? "",
          context);
      final quots = widget.marketWatch.getQuotes;
      if (quots == null) return;
      final depthArgs = DepthInputArgs(
          exch: quots.exch?.toString() ?? "",
          token: quots.token?.toString() ?? "",
          tsym: quots.tsym?.toString() ?? "",
          instname: quots.instname?.toString() ?? "",
          symbol: quots.symbol?.toString() ?? "",
          expDate: quots.expDate?.toString() ?? "",
          option: quots.option?.toString() ?? "");
      if (depthArgs.token.isNotEmpty && depthArgs.exch.isNotEmpty) {
        await widget.marketWatch.calldepthApis(context, depthArgs, "");
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _handleIndexClick(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered
                ? resolveThemeColor(
                    context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary,
                  ).withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(0),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.indexItem.idxname ?? "",
                    style: MyntWebTextStyles.symbol(
                      context,
                      fontWeight: FontWeight.w500,
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
                  _AppBarLivePriceWidget(
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
              if (_isHovered)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Material(
                    color: resolveThemeColor(
                      context,
                      dark: Colors.white.withOpacity(0.1),
                      light: Colors.black.withOpacity(0.05),
                    ),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => _handleTap(context),
                      customBorder: const CircleBorder(),
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
                          Icons.edit_outlined,
                          size: 14,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.iconDark,
                            light: MyntColors.icon,
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
    );
  }
}

// Live price widget for appbar index slots
class _AppBarLivePriceWidget extends ConsumerStatefulWidget {
  final String token;
  final String initialLtp;
  final String initialChange;
  final String initialPerChange;

  const _AppBarLivePriceWidget({
    super.key,
    required this.token,
    required this.initialLtp,
    required this.initialChange,
    required this.initialPerChange,
  });

  @override
  ConsumerState<_AppBarLivePriceWidget> createState() =>
      _AppBarLivePriceWidgetState();
}

class _AppBarLivePriceWidgetState
    extends ConsumerState<_AppBarLivePriceWidget> {
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
  void didUpdateWidget(_AppBarLivePriceWidget oldWidget) {
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
          if (hasChanged && mounted && !_isUpdatePending) {
            _isUpdatePending = true;
            _debouncer.run(() {
              if (mounted) {
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
    if (change == "null" || perChange == "null") {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      );
    }

    final double changeVal = double.tryParse(change.replaceAll(',', '')) ?? 0.0;
    final double perChangeVal =
        double.tryParse(perChange.replaceAll(',', '')) ?? 0.0;

    if (changeVal > 0 || perChangeVal > 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    } else if (changeVal < 0 || perChangeVal < 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final changeColor = _getChangeColor(_change, _perChange);
    // Use Wrap - stays on same line when space available, wraps when not
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text( 
      _ltp,
      style: MyntWebTextStyles.price(
        context,
        color: changeColor,
        fontWeight: MyntFonts.medium,
      ).copyWith(
        fontFeatures: [FontFeature.tabularFigures()],
      ),
        ),
        Text(
      "$_change ($_perChange%)",
      style: MyntWebTextStyles.exch(
        context,
        color: resolveThemeColor(
          context,
          dark: MyntColors.textSecondaryDark,
          light: MyntColors.textSecondary,
        ),
      ).copyWith(
        fontFeatures: [FontFeature.tabularFigures()],
      ),
        ),
      ],
    );
  }
}

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

// Lazy loading wrapper for SecureFundWeb to prevent blocking UI
class _LazyFundScreen extends ConsumerStatefulWidget {
  final String? initialAction;
  const _LazyFundScreen({this.initialAction});

  @override
  ConsumerState<_LazyFundScreen> createState() => _LazyFundScreenState();
}

class _LazyFundScreenState extends ConsumerState<_LazyFundScreen> {
  bool _shouldLoad = false;

  @override
  // ignore: must_call_super
  void didUpdateWidget(_LazyFundScreen oldWidget) {
    if (oldWidget.initialAction != widget.initialAction &&
        widget.initialAction != null) {
      // If action changes, we might want to trigger it again
      // For now, SecureFundWeb handles it in initState, so we don't need to do much here
      // unless we want to force re-initialization
    }
  }

  @override
  void initState() {
    super.initState();
    // Defer widget creation using microtask to allow UI to render first
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _shouldLoad = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final fund = ref.watch(fundProvider);

    // Show loader if widget not loaded yet or if fund data is not available
    if (!_shouldLoad || fund.fundDetailModel == null) {
      return _buildFundLoadingIndicator(theme.isDarkMode);
    }
    return SecureFundWeb(initialAction: widget.initialAction);
  }

  Widget _buildFundLoadingIndicator(bool isDarkMode) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      child: MyntLoader.branded(),
    );
  }
} 

/// Portfolio Ticker Strip Widget - Shows scrolling portfolio summary
/// Displays: Positions P&L, Holdings P&L, Available Fund
class PortfolioTickerStrip extends ConsumerStatefulWidget {
  const PortfolioTickerStrip({super.key});

  @override
  ConsumerState<PortfolioTickerStrip> createState() =>
      _PortfolioTickerStripState();
}

class _PortfolioTickerStripState extends ConsumerState<PortfolioTickerStrip>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late Timer _scrollTimer;
  bool _isHovered = false;
  static const double _scrollSpeed = 0.5;
  static const Duration _scrollInterval = Duration(milliseconds: 16);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _scrollTimer = Timer.periodic(_scrollInterval, (timer) {
      if (!_isHovered && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        if (currentScroll >= maxScroll) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(currentScroll + _scrollSpeed);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollTimer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use ValueListenableBuilder for reactive ticker visibility
    return ValueListenableBuilder<bool>(
      valueListenable: tickerVisibilityNotifier,
      builder: (context, isVisible, child) {
        if (!isVisible) {
          return const SizedBox.shrink();
        }
        return _buildTickerContent(context);
      },
    );
  }

  Widget _buildTickerContent(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final portfolio = ref.watch(portfolioProvider);
    final privacy = ref.watch(privacyProvider);
    // Commented out for future use - Holdings and Fund data
    // final fund = ref.watch(fundProvider);
    final isDarkMode = theme.isDarkMode;

    // Get position groups data
    final groupedBySymbol = portfolio.groupedBySymbol;
    final groupPositionSym = portfolio.groupPositionSym;

    // Get total P&L for display
    final totalPnL = double.tryParse(portfolio.totPnL) ?? 0.0;

    // Commented out for future use - Holdings and Fund data
    // final holdingsPnL = portfolio.totalPnlHolding;
    // final mfPnL = portfolio.mfTotalPnl;
    // final availableFund =
    //     double.tryParse(fund.fundDetailModel?.avlMrg ?? "0") ?? 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: resolveThemeColor(
            context,
            dark: const Color.fromARGB(0, 26, 26, 46),
            light: const Color(0xFFFAFAFA),
          ),
          border: isDarkMode
              ? Border(
                  bottom: BorderSide(
                    color: shadcn.Theme.of(context).colorScheme.border,
                    width: 1,
                  ),
                )
              : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Build ticker items from position groups
            final tickerItems = _buildPositionGroupTickerItems(
              groupedBySymbol: groupedBySymbol,
              groupPositionSym: groupPositionSym,
              totalPnL: totalPnL,
              isDarkMode: isDarkMode,
              isPrivate: privacy.isPrivate,
            );

            // If no positions, show empty state message
            if (tickerItems.isEmpty) {
              return Center(
                child: Text(
                  "No open positions",
                  style: MyntWebTextStyles.para(
                    context,
                    fontWeight: MyntFonts.medium,
                    color: isDarkMode
                        ? MyntColors.textSecondaryDark
                        : MyntColors.textSecondary,
                  ),
                ),
              );
            }

            // Check if content fits in available width
            // Approximate width per item: ~150px (symbol + value + divider)
            const double approxItemWidth = 150.0;
            final double contentWidth = approxItemWidth * tickerItems.length;
            final bool needsScrolling = contentWidth > constraints.maxWidth;

            if (!needsScrolling) {
              // Content fits - show centered, no scrolling
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 16),
                  ...tickerItems,
                  const SizedBox(width: 16),
                ],
              );
            }

            // Content overflows - show scrolling with duplicates
            return SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  ...tickerItems,
                  const SizedBox(width: 32),
                  ...tickerItems, // Duplicate for seamless scrolling
                  const SizedBox(width: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build ticker items from position groups (symbol name + P&L)
  List<Widget> _buildPositionGroupTickerItems({
    required Map groupedBySymbol,
    required List<String> groupPositionSym,
    required double totalPnL,
    required bool isDarkMode,
    required bool isPrivate,
  }) {
    final List<Widget> items = [];

    // First add Total P&L
    items.add(
      _TickerItem(
        label: "Total P&L",
        value: totalPnL,
        isDarkMode: isDarkMode,
        showAsAmount: true,
        isMasked: isPrivate,
        onTap: () {
          if (WebNavigationHelper.isAvailable) {
            WebNavigationHelper.navigateTo(Routes.positionscreen);
          }
        },
      ),
    );

    // Add divider after total if there are position groups
    if (groupPositionSym.isNotEmpty) {
      items.add(_tickerDivider(isDarkMode));
    }

    // Add each position group (excluding custom groups)
    for (int i = 0; i < groupPositionSym.length; i++) {
      final symbol = groupPositionSym[i];
      final groupData = groupedBySymbol[symbol];

      if (groupData == null) continue;

      // Skip custom groups - only show symbol-based groups
      final isCustomGrp = groupData['isCustomGrp'] ?? false;
      if (isCustomGrp) continue;

      final pnl = double.tryParse(groupData['totPnl'] ?? '0.0') ?? 0.0;

      // Get display name (use symbol name)
      final displayName = symbol;

      items.add(
        _TickerItem(
          label: displayName,
          value: pnl,
          isDarkMode: isDarkMode,
          showAsAmount: true,
          isMasked: isPrivate,
          onTap: () {
            if (WebNavigationHelper.isAvailable) {
              WebNavigationHelper.navigateTo(Routes.positionscreen);
            }
          },
        ),
      );

      // Add divider between items (but not after the last one)
      if (i < groupPositionSym.length - 1) {
        // Check if next item is not a custom group
        final nextSymbol = groupPositionSym[i + 1];
        final nextGroupData = groupedBySymbol[nextSymbol];
        final nextIsCustomGrp = nextGroupData?['isCustomGrp'] ?? false;
        if (!nextIsCustomGrp) {
          items.add(_tickerDivider(isDarkMode));
        }
      }
    }

    return items;
  }

  // Commented out for future use - Original ticker items with Holdings, MF, and Fund
  // List<Widget> _buildTickerItems({
  //   required double positionsPnL,
  //   required double holdingsPnL,
  //   required double mfPnL,
  //   required double availableFund,
  //   required bool isDarkMode,
  // }) {
  //   return [
  //     const SizedBox(width: 16),
  //     _TickerItem(
  //       label: "Positions P&L",
  //       value: positionsPnL,
  //       isDarkMode: isDarkMode,
  //       showAsAmount: true,
  //       onTap: () {
  //         if (WebNavigationHelper.isAvailable) {
  //           WebNavigationHelper.navigateTo(Routes.positionscreen);
  //         }
  //       },
  //     ),
  //     _tickerDivider(isDarkMode),
  //     _TickerItem(
  //       label: "Holdings P&L",
  //       value: holdingsPnL,
  //       isDarkMode: isDarkMode,
  //       showAsAmount: true,
  //       onTap: () {
  //         if (WebNavigationHelper.isAvailable) {
  //           WebNavigationHelper.navigateTo(Routes.holdingscreen);
  //         }
  //       },
  //     ),
  //     _tickerDivider(isDarkMode),
  //     _TickerItem(
  //       label: "Mutual Fund P&L",
  //       value: mfPnL,
  //       isDarkMode: isDarkMode,
  //       showAsAmount: true,
  //       onTap: () {
  //         if (WebNavigationHelper.isAvailable) {
  //           WebNavigationHelper.navigateTo(Routes.mfmainscreen);
  //         }
  //       },
  //     ),
  //     _tickerDivider(isDarkMode),
  //     _TickerItem(
  //       label: "Available Fund",
  //       value: availableFund,
  //       isDarkMode: isDarkMode,
  //       showAsAmount: true,
  //       onTap: () {
  //         if (WebNavigationHelper.isAvailable) {
  //           WebNavigationHelper.navigateTo(Routes.fundscreen);
  //         }
  //       },
  //     ),
  //     const SizedBox(width: 16),
  //   ];
  // }

  Widget _tickerDivider(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: 1,
      height: 16,
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.1),
    );
  }
}

class _TickerItem extends StatefulWidget {
  final String label;
  final double value;
  final bool isDarkMode;
  final bool showAsAmount;
  final bool isNeutral;
  // Privacy Mode: hides the amount (and its sign/colour) behind a mask.
  final bool isMasked;
  final VoidCallback? onTap;

  const _TickerItem({
    required this.label,
    required this.value,
    required this.isDarkMode,
    this.showAsAmount = false,
    this.isNeutral = false,
    this.isMasked = false,
    this.onTap,
  });

  @override
  State<_TickerItem> createState() => _TickerItemState();
}

class _TickerItemState extends State<_TickerItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.value >= 0;
    final displayValue = widget.showAsAmount
        ? _formatAmount(widget.value.abs())
        : widget.value.toStringAsFixed(2);

    Color valueColor;
    if (widget.isMasked || widget.isNeutral || widget.value == 0) {
      valueColor = widget.isDarkMode
          ? MyntColors.textPrimaryDark
          : MyntColors.textPrimary;
    } else {
      valueColor = isPositive
          ? (widget.isDarkMode ? MyntColors.profitDark : MyntColors.profit)
          : (widget.isDarkMode ? MyntColors.lossDark : MyntColors.loss);
    }

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered && widget.onTap != null
                ? (widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: MyntWebTextStyles.para(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: widget.isDarkMode
                      ? MyntColors.textPrimaryDark
                      : MyntColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.isMasked
                    ? kPrivacyMask
                    : (widget.showAsAmount
                        ? (isPositive ? displayValue : "-$displayValue")
                        : displayValue),
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    return amount.toIndianFormat();
  }
}
