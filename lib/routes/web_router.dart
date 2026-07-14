import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/scanner_model/scan_explain.dart' show ExplainKey, ExplainScope;
import '../screens/web/customizable_split_home_screen.dart';
// ScannerSubPage is re-exported via the import above (no separate file).
import '../screens/splash_screen.dart';
import '../screens/web/authentication/login/login_web.dart';
import '../screens/web/oauth/oauth_login_screen.dart';
import '../screens/web/public/pnl_insights_screen.dart';
import '../utils/custom_navigator.dart';
import '../main.dart' show registerWebNavigatorKey;

/// GoRouter for web - enables URL synchronization with browser
/// Only used when kIsWeb is true
///
/// This router handles URL-based navigation for the web app:
/// - `/splash` → Splash screen (entry point)
/// - `/login` → Login screen
/// - `/` → Main dashboard (after login)
/// - `/holdings` → Holdings screen in right panel
/// - `/positions` → Positions screen in right panel
/// - `/orders` → Order book in right panel
/// - `/funds` → Funds screen in right panel
/// - `/option-chain` → Option chain in right panel

/// Route paths for web
class WebRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/';
  static const String holdings = '/holdings';
  static const String positions = '/positions';
  static const String orders = '/orders';
  static const String funds = '/funds';
  static const String optionChain = '/option-chain';
  static const String ipo = '/ipo';
  static const String bonds = '/bonds';
  static const String mutualFunds = '/mutual-funds';
  static const String reports = '/reports';
  static const String profile = '/profile';
  static const String myAccount = '/my-account';
  static const String portfolioAnalysis = '/portfolio-analysis';
  static const String strategyBuilder = '/strategy-builder';
  static const String instaOptions = '/insta-options';
  static const String scalper = '/scalper';
  static const String charts = '/charts';
  static const String tradingViewWebHook = '/tradingview-webhook';
  static const String basketDashboard = '/basket-dashboard';
  static const String pledge = '/pledge';
  static const String caBuyback = '/corporate-actions';
  static const String refer = '/refer';
  static const String helpSupport = '/help-support';
  static const String settings = '/settings';
  static const String notification = '/notification';
  static const String oauthAuthorize = '/OAuthlogin/authorize/oauth';
  static const String dailyPnl = '/dailypnl';
  static const String scanner = '/scanner';
  static const String scannerSymbols = '/scanner/symbols';
  static const String scannerScanners = '/scanner/scanners';
  static const String scannerFundamentals = '/scanner/fundamentals';
  static const String scannerCustom = '/scanner/custom';
  /// Scan-explanation deep links. `:code` is the built-in scanner code
  /// (`RSI14_OVERSOLD` etc.); `:cid` is the saved custom scan numeric id.
  static const String scannerExplainBuiltin =
      '/scanner/explain/builtin/:code/:ticker';
  static const String scannerExplainCustom =
      '/scanner/explain/custom/:cid/:ticker';
  static const String orderflow = '/orderflow';
}

/// Global GoRouter instance for web
/// Access via context.go() or context.push() methods
late final GoRouter webRouter;

/// Navigator key for web - used for showing dialogs from sheets/overlays
final GlobalKey<NavigatorState> webNavigatorKey = GlobalKey<NavigatorState>();

/// Initialize the web router
/// Call this in main() before runApp() when kIsWeb is true
void initializeWebRouter() {
  // Register webNavigatorKey with main.dart's helper functions
  // This allows getNavigatorKey()/getNavigatorContext() to work on web
  registerWebNavigatorKey(() => webNavigatorKey);

  webRouter = GoRouter(
    navigatorKey: webNavigatorKey,
    initialLocation: WebRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    // Token-based auto-login entry. Links of the form
    //   /?uid=<clientId>&token=<noren-session>
    // must run through Splash (which validates the session via checkAutoLogin),
    // not render the home route ('/') directly. main.dart has already persisted
    // uid/token to prefs by the time this runs; redirecting to /splash also drops
    // the session token from the browser address bar / history.
    redirect: (context, state) {
      final q = state.uri.queryParameters;
      final hasAutoLogin = (q['uid']?.trim().isNotEmpty ?? false) &&
          (q['token']?.trim().isNotEmpty ?? false);
      if (hasAutoLogin) return WebRoutes.splash;
      return null;
    },
    routes: [
      // Splash screen - entry point
      GoRoute(
        path: WebRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Login screen (web-specific)
      GoRoute(
        path: WebRoutes.login,
        builder: (context, state) => const LoginScreenWeb(),
      ),

      // Main home/dashboard route
      GoRoute(
        path: WebRoutes.home,
        builder: (context, state) => const CustomizableSplitHomeScreen(),
      ),

      // Holdings screen
      GoRoute(
        path: WebRoutes.holdings,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.holdings,
        ),
      ),

      // Positions screen
      GoRoute(
        path: WebRoutes.positions,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.positions,
        ),
      ),

      // Orders/Order book screen
      GoRoute(
        path: WebRoutes.orders,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.orderBook,
        ),
      ),

      // Funds screen
      GoRoute(
        path: WebRoutes.funds,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.funds,
        ),
      ),

      // Option chain screen
      GoRoute(
        path: WebRoutes.optionChain,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.optionChain,
        ),
      ),

      // IPO screen
      GoRoute(
        path: WebRoutes.ipo,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.ipo,
        ),
      ),

      // Bonds screen
      GoRoute(
        path: WebRoutes.bonds,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.bond,
        ),
      ),

      // Mutual Funds screen
      GoRoute(
        path: WebRoutes.mutualFunds,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.mutualFund,
        ),
      ),

      // Reports screen
      GoRoute(
        path: WebRoutes.reports,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.reports,
        ),
      ),

      // Portfolio Analysis screen
      GoRoute(
        path: WebRoutes.portfolioAnalysis,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.portfolioAnalysis,
        ),
      ),

      // My Account screen
      GoRoute(
        path: WebRoutes.myAccount,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.myAccount,
        ),
      ),

      // Strategy Builder screen - wrapped in home screen for session validation & web layout
      GoRoute(
        path: WebRoutes.strategyBuilder,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.strategyBuilder,
        ),
      ),

      // InstaOptions Analytics — 9 read-only OI/analytics sub-screens in one right panel
      GoRoute(
        path: WebRoutes.instaOptions,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.instaOptions,
        ),
      ),

      // TradingView WebHook screen
      GoRoute(
        path: WebRoutes.tradingViewWebHook,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.tradingViewWebHook,
        ),
      ),

      // Basket Dashboard screen
      GoRoute(
        path: WebRoutes.basketDashboard,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.basketDashboard,
        ),
      ),

      // Scalper screen - embedded in home layout (full-width, watchlist hidden)
      GoRoute(
        path: WebRoutes.scalper,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.scalper,
        ),
      ),
      // Chart Engine — multi-chart application (Phase 1 = single pane)
      GoRoute(
        path: WebRoutes.charts,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.charts,
        ),
      ),
      // Pledge & Unpledge — embedded in home layout
      GoRoute(
        path: WebRoutes.pledge,
       builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.pledgeUnpledge,
        ),
      ),

      // Corporate Actions (Buyback / Delisting / Takeover / OFS)
      GoRoute(
        path: WebRoutes.caBuyback,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.caBuyback,
        ),
      ),

      // Refer
      GoRoute(
        path: WebRoutes.refer,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.refer,
        ),
      ),

      // Help & Support
      GoRoute(
        path: WebRoutes.helpSupport,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.helpSupport,
        ),
      ),

      // Settings
      GoRoute(
        path: WebRoutes.settings,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.settings,
        ),
      ),

      // Notification
      GoRoute(
        path: WebRoutes.notification,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.notification,
        ),
      ),

      // OAuth login screen - partner apps direct users here with ?client_id=<id>
      GoRoute(
        path: WebRoutes.oauthAuthorize,
        builder: (context, state) => OAuthLoginScreen(
          clientId: state.uri.queryParameters['client_id'],
        ),
      ),

      // Public PnL viewer — opened by anyone with a share link.
      // No session required; renders standalone (no trading shell).
      GoRoute(
        path: WebRoutes.dailyPnl,
        builder: (context, state) => PnlInsightsScreen(
          ucode: state.uri.queryParameters['ucode'],
        ),
      ),

      // Profile details screen (also handles Digilocker callback with ?code=&state=)
      GoRoute(
        path: WebRoutes.profile,
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          final stateParam = state.uri.queryParameters['state'];
          return CustomizableSplitHomeScreen(
            initialRightPanel: ScreenTypeParam.profileDetails,
            digilockerCode: code,
            digilockerState: stateParam,
          );
        },
      ),

      // Scanner shell + 4 sub-page deep links
      GoRoute(
        path: WebRoutes.scanner,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.scanner,
        ),
      ),
      // Legacy scanner sub-page URLs — the underlying enum values are
      // commented out (Symbols / Scanners / Fundamentals tabs retired), so
      // these routes now redirect to the closest active tab so existing
      // bookmarks continue to work.
      GoRoute(
        path: WebRoutes.scannerSymbols,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.scanner,
          initialScannerSubPage: ScannerSubPage.scannersNew,
        ),
      ),
      GoRoute(
        path: WebRoutes.scannerScanners,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.scanner,
          initialScannerSubPage: ScannerSubPage.scannersNew,
        ),
      ),
      GoRoute(
        path: WebRoutes.scannerFundamentals,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.scanner,
          initialScannerSubPage: ScannerSubPage.fundamentalsNew,
        ),
      ),
      GoRoute(
        path: WebRoutes.scannerCustom,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.scanner,
          initialScannerSubPage: ScannerSubPage.customScans,
        ),
      ),
      GoRoute(
        path: WebRoutes.scannerExplainBuiltin,
        builder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          final ticker = state.pathParameters['ticker'] ?? '';
          return CustomizableSplitHomeScreen(
            initialRightPanel: ScreenTypeParam.scanner,
            initialScannerSubPage: ScannerSubPage.scannersNew,
            initialExplainArgs: ExplainKey(
              scope: ExplainScope.builtin,
              id: code,
              ticker: ticker,
            ),
          );
        },
      ),
      GoRoute(
        path: WebRoutes.scannerExplainCustom,
        builder: (context, state) {
          final cid = state.pathParameters['cid'] ?? '';
          final ticker = state.pathParameters['ticker'] ?? '';
          return CustomizableSplitHomeScreen(
            initialRightPanel: ScreenTypeParam.scanner,
            initialScannerSubPage: ScannerSubPage.customScans,
            initialExplainArgs: ExplainKey(
              scope: ExplainScope.custom,
              id: cid,
              ticker: ticker,
            ),
          );
        },
      ),

      // Orderflow footprint chart
      GoRoute(
        path: WebRoutes.orderflow,
        builder: (context, state) => const CustomizableSplitHomeScreen(
          initialRightPanel: ScreenTypeParam.orderflow,
        ),
      ),
    ],

    // Handle unknown routes - redirect to home
    errorBuilder: (context, state) => const CustomizableSplitHomeScreen(),
  );
}

/// Extension to update URL without full navigation
/// Use this to sync URL when panel navigation happens internally
extension WebRouterExtension on BuildContext {
  /// Update browser URL and ADD to history stack (enables back button)
  /// Uses WebNavigationHelper which handles platform differences
  void updateWebUrl(String path) {
    if (kIsWeb) {
      WebNavigationHelper.updateUrl(path);
    }
  }

  /// Replace current URL without adding to history
  /// Use this for URL updates that shouldn't be back-navigable
  void replaceWebUrl(String path) {
    if (kIsWeb) {
      WebNavigationHelper.replaceUrl(path);
    }
  }

  /// Get current route path
  String get currentPath {
    if (kIsWeb) {
      return WebNavigationHelper.getCurrentPath();
    }
    return GoRouterState.of(this).uri.path;
  }
}
