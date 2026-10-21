import 'dart:async';
import 'dart:developer';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'websocket_provider.dart';
import 'market_watch_provider.dart';
import 'portfolio_provider.dart';
import 'index_list_provider.dart';
import 'stocks_provider.dart';
import 'watchlist_oc_provider.dart';
import '../locator/constant.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../screens/web/customizable_split_home_screen.dart';
import 'package:mynt_plus/main.dart' show getNavigatorContext;

/// Web-specific subscription manager that tracks active screens across multiple panels
/// and manages websocket subscriptions accordingly
class WebSubscriptionManager extends ChangeNotifier with WidgetsBindingObserver {
  final Ref ref;
  
  WebSubscriptionManager(this.ref) {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  // Track active screens per panel (panel index -> ScreenType)
  final Map<int, ScreenType?> _activeScreens = {};

  // Track subscriptions per screen type (ScreenType -> Set of symbols)
  final Map<ScreenType, Set<String>> _screenSubscriptions = {};

  // Track which symbols are currently subscribed via websocket (for deduplication)
  final Set<String> _currentWebSocketSubscriptions = {};

  // MASTER LIST: Track ALL subscribed symbols (used for reconnection)
  // This persists across screen changes and is used to resend all subscriptions on reconnect
  final Set<String> _activeSubscriptions = <String>{};

  // TICKER SUBSCRIPTIONS: Persistent subscriptions for ticker header (positions)
  // These symbols are NEVER unsubscribed while user is logged in, ensuring ticker always updates
  final Set<String> _tickerSubscriptions = <String>{};

  // Track which screens need which subscription types
  Map<ScreenType, SubscriptionType> _screenSubscriptionTypes = {};
  
  // App lifecycle tracking
  AppLifecycleState _currentState = AppLifecycleState.resumed;
  DateTime? _lastPauseTime;
  bool _wasDisconnectedInBackground = false;

  // Browser tab visibility tracking
  DateTime? _tabHiddenTime;
  // How long the tab must be hidden before we force-reconnect on return
  static const Duration _staleConnectionThreshold = Duration(seconds: 5);
  
  // Network tracking
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  ConnectivityResult _lastNetworkStatus = ConnectivityResult.mobile;

  // WebSocket state tracking for reconnection
  bool _lastKnownWsConnected = false;
  VoidCallback? _wsProviderListener;
  
  // Context management
  BuildContext? _lastValidContext;
  
  // Getters
  Map<int, ScreenType?> get activeScreens => Map.from(_activeScreens);
  Map<ScreenType, Set<String>> get screenSubscriptions => Map.from(_screenSubscriptions);
  AppLifecycleState get currentState => _currentState;

  // Master subscription list getters (like mobile)
  Set<String> get activeSubscriptions => Set.from(_activeSubscriptions);
  int get subscriptionCount => _activeSubscriptions.length;
  bool get hasActiveSubscriptions => _activeSubscriptions.isNotEmpty;

  // Ticker subscription getters
  Set<String> get tickerSubscriptions => Set.from(_tickerSubscriptions);
  int get tickerSubscriptionCount => _tickerSubscriptions.length;
  bool get hasTickerSubscriptions => _tickerSubscriptions.isNotEmpty;
  
  void _init() {
    // Initialize subscription types for each screen
    _initializeSubscriptionTypes();

    // Listen to browser tab visibility changes
    // This is CRITICAL for web: Flutter's AppLifecycleState does NOT reliably fire
    // on browser tab switches. Without this, the app won't know when to reconnect
    // after the user switches tabs and comes back.
    html.document.addEventListener('visibilitychange', _onBrowserVisibilityChange);

    // Listen to network changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      // connectivity_plus 7.0.0 returns List<ConnectivityResult>
      // Take the first result or check if any connection is available
      final result = results.isNotEmpty
          ? (results.contains(ConnectivityResult.none)
              ? ConnectivityResult.none
              : results.first)
          : ConnectivityResult.none;
      _handleNetworkChange(result);
    });

    // Listen to websocket connection state changes
    // This ensures subscriptions are restored after websocket reconnects (e.g., after page refresh)
    _setupWebSocketListener();

    // Every raw touchline "u" anywhere in the app is checked against what is
    // on screen before it goes out (WebSocketProvider._touchlineReleasable).
    try {
      ref.read(websocketProvider).touchlineProtection =
          (source) => _protectedSymbols(source: source);
    } catch (e) {
      log('WebSubscriptionManager: could not register touchline protection: $e');
    }
  }

  /// Handle browser tab visibility changes (visibilitychange event).
  /// This fires reliably on tab switch, unlike Flutter's AppLifecycleState on web.
  void _onBrowserVisibilityChange(html.Event event) {
    final isVisible = html.document.visibilityState == 'visible';

    if (!isVisible) {
      // Tab is being hidden — record time and pause the probe so it doesn't
      // fire (or queue up) under browser timer-throttling. Probe restarts
      // automatically when the state machine re-enters `connected` after
      // the tab returns and triggers a reconnect.
      _tabHiddenTime = DateTime.now();
      try { ref.read(websocketProvider).pauseProbe(); } catch (_) {}
      log('WebSubscriptionManager: Browser tab hidden');
      return;
    }

    // Tab is becoming visible again
    log('WebSubscriptionManager: Browser tab visible again');

    if (!_isUserLoggedIn()) return;

    final wasHiddenFor = _tabHiddenTime != null
        ? DateTime.now().difference(_tabHiddenTime!)
        : Duration.zero;

    _tabHiddenTime = null;

    // If tab was hidden long enough for the connection to go stale, force full restore.
    if (wasHiddenFor >= _staleConnectionThreshold) {
      log('WebSubscriptionManager: Forcing reconnect after tab was hidden for ${wasHiddenFor.inSeconds}s');
      _forceReconnectAndResubscribe();
    } else {
      // Short switch — just verify connection is alive and resume probing.
      final wsProvider = ref.read(websocketProvider);
      if (!wsProvider.wsConnected) {
        _forceReconnectAndResubscribe();
      } else {
        wsProvider.resumeProbe();
      }
    }
  }

  /// Force close the WebSocket, reconnect, and re-subscribe only what's currently needed.
  /// Rebuilds the master list from active screens + ticker to avoid accumulating stale symbols.
  /// This ensures every visible screen gets fresh data after returning from a background tab.
  bool _isForceReconnecting = false;

  void _forceReconnectAndResubscribe() {
    if (!_isUserLoggedIn()) return;

    // Prevent duplicate calls (e.g., visibilitychange + AppLifecycleState both firing)
    if (_isForceReconnecting) return;
    _isForceReconnecting = true;

    final wsProvider = ref.read(websocketProvider);
    final context = _getValidContext();

    // Rebuild the master list from what's actually needed right now
    // instead of using the accumulated list which may have stale symbols.
    final freshSymbols = _rebuildActiveSymbols();
    _activeSubscriptions
      ..clear()
      ..addAll(freshSymbols);

    // Clear ALL subscription tracking so nothing blocks re-sends:
    //  1. WebSubscriptionManager dedup + per-screen tracking
    _currentWebSocketSubscriptions.clear();
    //     Per-screen tracking is what protects a screen's scrips from other
    //     screens' "u" and what a later screen change releases — so it is
    //     recomputed from what each active screen shows now, not just wiped
    //     (wiping left every screen unprotected until its next change).
    _screenSubscriptions.clear();
    for (final screenType in _activeScreens.values) {
      if (screenType == null) continue;
      final subType = _screenSubscriptionTypes[screenType] ?? SubscriptionType.none;
      if (subType == SubscriptionType.none) continue;
      try {
        _screenSubscriptions[screenType] = _getSymbolsForScreen(screenType, subType);
      } catch (_) {}
    }
    //  2. WebSocketProvider's _sentSubscriptions
    wsProvider.clearSentSubscriptions();

    // Suppress "Connection lost"/"Connected" toasts. The flag is now cleared
    // by WebSocketProvider._onEnterConnected when the reconnect actually
    // succeeds (instead of the old 500 ms Future.delayed that fired before
    // the connection completed and missed late toasts).
    wsProvider.setTabSwitchReconnect(true);

    // Force close. force=true bypasses the _connecting guard.
    // preserveData=true keeps stale prices visible during the brief reconnect
    // window — better than 0.00 flashes that would mislead traders.
    wsProvider.closeSocket(true, force: true, preserveData: true);

    // No artificial delay before reconnect: the state machine's first-attempt
    // backoff is already 200 ms, which serves the same "give close time to
    // settle" purpose without an extra Future.delayed cascade.
    if (context != null) {
      wsProvider.reconnect(context);
    }
    _isForceReconnecting = false;
  }

  /// Rebuild the set of symbols actually needed right now from ALL sources.
  /// This includes active screens, ticker, and providers that bypass the subscription manager
  /// (option chain, futures, depth, watchlist OC). Nothing should be left out.
  Set<String> _rebuildActiveSymbols() {
    final symbols = <String>{};

    // 1. Gather symbols from all currently active screens (managed by WebSubscriptionManager)
    for (final screenType in _activeScreens.values) {
      if (screenType == null) continue;
      final subType = _screenSubscriptionTypes[screenType] ?? SubscriptionType.none;
      if (subType == SubscriptionType.none) continue;

      try {
        final screenSymbols = _getSymbolsForScreen(screenType, subType);
        symbols.addAll(screenSymbols);
      } catch (e) {
        log('WebSubscriptionManager: Error getting symbols for $screenType during rebuild: $e');
      }
    }

    // 2. Always include ticker subscriptions (positions in header - must always be live)
    symbols.addAll(_tickerSubscriptions);

    // 3. Gather symbols from providers that bypass WebSubscriptionManager
    //    These call websocketProvider.establishConnection() directly
    try {
      final mwProvider = ref.read(marketWatchProvider);

      // 3a/3b. The option chain and futures list are NOT taken from the
      //        market-watch models here: those models stay loaded after their
      //        page closes, so a tab return re-subscribed a closed page's 40
      //        strikes and futures. Both lists are owned touchline now
      //        ('option-chain' / 'futures') and come back through
      //        WebSocketProvider's owner registry while the page is open.

      // 3c. Depth symbol - bypasses manager via subscribeToDepthData
      final depthSymbol = mwProvider.currentDepthSymbol;
      if (depthSymbol != null && depthSymbol.isNotEmpty) {
        symbols.add(depthSymbol);
      }
    } catch (e) {
      log('WebSubscriptionManager: Error getting market watch symbols during rebuild: $e');
    }

    // 3d. Watchlist OC provider tokens (sidebar option chain panel)
    try {
      final ocProvider = ref.read(watchlistOCProvider);
      // Include the index symbol and subscribed option tokens
      if (ocProvider.isExpanded) {
        final selectedSym = ocProvider.selectedSymbol;
        symbols.add('${selectedSym.exch}|${selectedSym.token}');

        for (final c in ocProvider.callOptions) {
          if (c.exch != null && c.token != null) symbols.add('${c.exch}|${c.token}');
        }
        for (final p in ocProvider.putOptions) {
          if (p.exch != null && p.token != null) symbols.add('${p.exch}|${p.token}');
        }
      }
    } catch (e) {
      log('WebSubscriptionManager: Error getting watchlist OC symbols during rebuild: $e');
    }

    // 3e. Always include index symbols (shown in header bar across all screens)
    symbols.addAll(_getIndexSymbols());

    // 3f. The watchlist sidebar is on screen whatever the main panels show.
    //     Without this, a tab return with no panel set to "watchlist" left the
    //     sidebar's rows frozen. (Positions, holdings, the order book and other
    //     feature lists come back through WebSocketProvider's owner registry.)
    symbols.addAll(_getWatchlistSymbols());

    return symbols;
  }

  /// Set up listener for websocket connection state changes
  void _setupWebSocketListener() {
    try {
      final wsProvider = ref.read(websocketProvider);
      _lastKnownWsConnected = wsProvider.wsConnected;

      _wsProviderListener = () {
        _handleWebSocketStateChange();
      };

      wsProvider.addListener(_wsProviderListener!);
      log('WebSubscriptionManager: WebSocket listener set up');
    } catch (e) {
      log('WebSubscriptionManager: Error setting up websocket listener: $e');
    }
  }

  // Pending subscription queue - subscriptions waiting for WebSocket to be ready
  final List<_PendingSubscription> _pendingSubscriptionQueue = [];
  Timer? _retryTimer;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  /// Handle websocket connection state changes (fired on every notify
  /// from WebSocketProvider — gated to the false→true edge so we only act
  /// when a fresh connection becomes available).
  ///
  /// The old code distinguished "initial connection" from "reconnect" via a
  /// one-shot `_isInitialConnection` flag. The state machine + clean master
  /// list make that distinction unnecessary: an empty master list naturally
  /// no-ops `_sendAllSubscriptionsFromMasterList`, and screens populate the
  /// list as they fetch data and subscribe.
  void _handleWebSocketStateChange() {
    try {
      final wsProvider = ref.read(websocketProvider);
      final isNowConnected = wsProvider.wsConnected;

      if (!_lastKnownWsConnected && isNowConnected) {
        log('WebSubscriptionManager: WebSocket connected');

        // Clear deduplication tracking (NOT the master list!)
        _currentWebSocketSubscriptions.clear();

        // Drain any pending subscriptions queued while the socket was down.
        if (_pendingSubscriptionQueue.isNotEmpty) {
          _processPendingSubscriptions();
        }

        if (!_isUserLoggedIn()) {
          _lastKnownWsConnected = isNowConnected;
          return;
        }

        // Re-send the full master list. Microtask (vs old 100 ms Future.delayed)
        // fires immediately after the current event-loop turn — same safety,
        // no arbitrary delay.
        if (_activeSubscriptions.isNotEmpty) {
          Future.microtask(() {
            if (ref.read(websocketProvider).wsConnected) {
              _sendAllSubscriptionsFromMasterList();
            }
          });
        } else if (_activeScreens.isNotEmpty) {
          // No master list yet but screens are active — try the per-screen
          // restore path. This covers the rare case where a reconnect happens
          // before any screen has populated the master list.
          Future.microtask(() {
            if (ref.read(websocketProvider).wsConnected) {
              _restoreActiveSubscriptions();
            }
          });
        }

        // Depth ("d") is restored by WebSocketProvider's depth-owner registry
        // on every new socket — for the depth panel, each chart and Insta
        // Options alike — so it is not re-sent from here any more.
      }

      _lastKnownWsConnected = isNowConnected;
    } catch (e) {
      log('WebSubscriptionManager: Error handling websocket state change: $e');
    }
  }

  /// Check and reconnect WebSocket if disconnected
  /// Call this when navigating to a new page to ensure connection is active
  Future<void> ensureConnected(BuildContext context) async {
    if (!_isUserLoggedIn()) return;

    try {
      final wsProvider = ref.read(websocketProvider);

      if (!wsProvider.wsConnected) {
        log('WebSubscriptionManager: Triggering reconnection');

        // Update context for future use
        updateContext(context);

        // Trigger reconnection
        wsProvider.reconnect(context);
      } else {
        // Socket is connected - check if we have subscriptions that need to be sent
        if (_activeSubscriptions.isNotEmpty && _currentWebSocketSubscriptions.isEmpty) {
          log('WebSubscriptionManager: Restoring subscriptions after connection check');
          _sendAllSubscriptionsFromMasterList();
        }
      }
    } catch (e) {
      log('WebSubscriptionManager: Error in ensureConnected: $e');
    }
  }

  /// Force reconnection and resubscription
  /// Use this when WebSocket seems stuck and not receiving data
  Future<void> forceReconnect(BuildContext context) async {
    if (!_isUserLoggedIn()) return;


    try {
      final wsProvider = ref.read(websocketProvider);

      // Close existing connection
      wsProvider.closeSocket(true);

      // Clear local tracking (but NOT the master list - we need it for restoration)
      _currentWebSocketSubscriptions.clear();

      // Wait a moment for cleanup
      await Future.delayed(const Duration(milliseconds: 300));

      // Update context
      updateContext(context);

      // Reconnect
      wsProvider.reconnect(context);

    } catch (e) {
      log('WebSubscriptionManager: Error in forceReconnect: $e');
    }
  }

  /// Check if WebSocket is ready for subscriptions
  bool _isWebSocketReady() {
    try {
      final wsProvider = ref.read(websocketProvider);
      return wsProvider.wsConnected;
    } catch (e) {
      return false;
    }
  }

  /// Queue a subscription for later if WebSocket isn't ready
  void _queueSubscription(ScreenType screenType, Set<String> symbols, int retryCount) {
    // Remove any existing pending subscription for this screen
    _pendingSubscriptionQueue.removeWhere((p) => p.screenType == screenType);

    _pendingSubscriptionQueue.add(_PendingSubscription(
      screenType: screenType,
      symbols: symbols,
      retryCount: retryCount,
      timestamp: DateTime.now(),
    ));


    // Start retry timer if not already running
    _startRetryTimer();
  }

  /// Start retry timer to process pending subscriptions
  void _startRetryTimer() {
    if (_retryTimer?.isActive == true) return;

    _retryTimer = Timer.periodic(_retryDelay, (_) {
      if (_pendingSubscriptionQueue.isEmpty) {
        _retryTimer?.cancel();
        _retryTimer = null;
        return;
      }

      if (_isWebSocketReady()) {
        _processPendingSubscriptions();
      }
    });
  }

  /// Process all pending subscriptions
  void _processPendingSubscriptions() {
    if (_pendingSubscriptionQueue.isEmpty) return;

    final toProcess = List<_PendingSubscription>.from(_pendingSubscriptionQueue);
    _pendingSubscriptionQueue.clear();

    for (final pending in toProcess) {
      if (pending.retryCount >= _maxRetries) {
        continue;
      }

      // Try to subscribe
      _subscribeToScreenWithSymbols(pending.screenType, pending.symbols, pending.retryCount + 1);
    }
  }

  /// Subscribe to a screen with specific symbols (used for retry)
  Future<void> _subscribeToScreenWithSymbols(ScreenType screenType, Set<String> symbols, int retryCount) async {
    if (!_isUserLoggedIn()) return;

    // Check WebSocket readiness
    if (!_isWebSocketReady()) {
      _queueSubscription(screenType, symbols, retryCount);
      return;
    }

    final context = _getValidContext();
    if (context == null) {
      log('WebSubscriptionManager: No valid context for subscription');
      // Queue for retry with context
      _queueSubscription(screenType, symbols, retryCount);
      return;
    }

    if (symbols.isEmpty) {
      return;
    }

    // Filter out already subscribed symbols
    final newSymbols = symbols.where((s) => !_currentWebSocketSubscriptions.contains(s)).toSet();

    if (newSymbols.isEmpty) {
      _screenSubscriptions[screenType] = symbols;
      return;
    }


    try {
      final wsProvider = ref.read(websocketProvider);
      final symbolString = newSymbols.join('#');

      wsProvider.connectTouchLine(
        task: "t",
        input: symbolString,
        context: context,
      );

      _currentWebSocketSubscriptions.addAll(newSymbols);
      _activeSubscriptions.addAll(newSymbols);
      _screenSubscriptions[screenType] = symbols;

    } catch (e) {
      // Queue for retry
      if (retryCount < _maxRetries) {
        _queueSubscription(screenType, symbols, retryCount);
      }
    }
  }

  /// Send ALL subscriptions from master list directly to websocket
  /// This is used on reconnection to restore all subscriptions at once
  void _sendAllSubscriptionsFromMasterList() {
    if (_activeSubscriptions.isEmpty) {
      log('WebSubscriptionManager: No subscriptions in master list to send');
      return;
    }

    final context = _getValidContext();
    if (context == null) {
      log('WebSubscriptionManager: No valid context for sending subscriptions');
      return;
    }


    try {
      final wsProvider = ref.read(websocketProvider);

      // Send subscriptions in batches of 50 to avoid overwhelming the server
      final subscriptionList = _activeSubscriptions.toList();
      const batchSize = 50;
      int totalBatches = (subscriptionList.length / batchSize).ceil();

      log('WebSubscriptionManager: Sending $totalBatches batches of up to $batchSize symbols each');

      for (int i = 0; i < subscriptionList.length; i += batchSize) {
        final endIndex = (i + batchSize < subscriptionList.length)
            ? i + batchSize
            : subscriptionList.length;

        final batch = subscriptionList.sublist(i, endIndex);
        final batchString = batch.join('#');
        final batchNum = (i ~/ batchSize) + 1;


        // Send directly via websocket - touchline for web (depth panel keeps its own "d")
        wsProvider.connectTouchLine(
          task: "t",
          input: batchString,
          context: context,
        );

        // Track as currently subscribed
        _currentWebSocketSubscriptions.addAll(batch);
      }


    } catch (e) {
      log('WebSubscriptionManager: Error sending subscriptions from master list: $e');
    }
  }


  // ---------------- Order-window market depth (Task #9168) ----------------
  //
  // The order window's depth panel needs its own depth ("d") feed: the
  // Overview's is a single slot (MarketWatchProvider.currentDepthSymbol) and
  // taking it would stop the Overview. It holds the feed through the
  // WebSocketProvider depth-owner registry, so:
  // - a feed another owner (Overview, chart engine, Insta Options) already
  //   holds is only read, and is never released while they still show it;
  // - the panel keeps a feed alive when the Overview closes first, and the
  //   registry sends "ud" only when the last owner lets go;
  // - the registry re-sends every owned feed after a reconnect, which is what
  //   the old _restoreDepthSubscription did for the panel's symbols.
  // Several panels can show the same scrip (the ref-count below), but the
  // registry sees one owner per scrip.
  static const String _orderDepthOwner = 'order-depth';

  /// "EXCH|TOKEN" -> number of open depth panels showing it.
  final Map<String, int> _orderDepthRefs = {};

  Set<String> get orderDepthSymbols => _orderDepthRefs.keys.toSet();

  void acquireOrderDepth(String symbol, BuildContext context) {
    if (symbol.isEmpty) return;
    final count = (_orderDepthRefs[symbol] ?? 0) + 1;
    _orderDepthRefs[symbol] = count;
    if (count > 1) return;
    ref.read(websocketProvider).acquireDepth(_orderDepthOwner, [symbol], context);
  }

  void releaseOrderDepth(String symbol) {
    if (symbol.isEmpty || !_orderDepthRefs.containsKey(symbol)) return;
    final count = _orderDepthRefs[symbol]! - 1;
    if (count > 0) {
      _orderDepthRefs[symbol] = count;
      return;
    }
    _orderDepthRefs.remove(symbol);
    try {
      ref.read(websocketProvider).releaseDepth(
          _orderDepthOwner, [symbol], _getValidContext());
    } catch (e) {
      log('WebSubscriptionManager: Error releasing order depth $symbol: $e');
    }
  }

  /// Initialize which subscription type each screen needs
  void _initializeSubscriptionTypes() {
    _screenSubscriptionTypes = {
      ScreenType.dashboard: SubscriptionType.marketWatch,
      ScreenType.watchlist: SubscriptionType.marketWatch,
      ScreenType.holdings: SubscriptionType.holdings,
      ScreenType.positions: SubscriptionType.positions,
      ScreenType.orderBook: SubscriptionType.none, // Order book handles its own tab-specific subscriptions
      ScreenType.funds: SubscriptionType.none,
      ScreenType.mutualFund: SubscriptionType.none,
      ScreenType.ipo: SubscriptionType.none,
      ScreenType.bond: SubscriptionType.none,
      // scripDepthInfo handles its own subscription via setIsDepthVisibleWeb
      // Setting to none prevents unsubscribing other panels' symbols when depth opens
      ScreenType.scripDepthInfo: SubscriptionType.none,
      ScreenType.optionChain: SubscriptionType.marketWatch,
      ScreenType.pledgeUnpledge: SubscriptionType.none,
      ScreenType.corporateActions: SubscriptionType.none,
      ScreenType.caBuyback: SubscriptionType.none,
      ScreenType.reports: SubscriptionType.none,
      ScreenType.settings: SubscriptionType.none,
      ScreenType.tradeAction: SubscriptionType.marketWatch,
    };
  }
  
  // Debounce timers to prevent rapid screen updates - ONE PER PANEL
  // Using a Map ensures each panel's subscription is processed independently
  // This fixes the bug where only the last panel's subscription was processed
  final Map<int, Timer> _updateDebounceTimers = {};
  // Track pending screen changes so we can complete them if needed
  final Map<int, _PendingScreenChange> _pendingScreenChanges = {};
  static const Duration _updateDebounceDelay = Duration(milliseconds: 300);

  /// Update active screen for a panel (with debouncing to prevent rapid calls)
  void updateActiveScreen(int panelIndex, ScreenType? screenType) {
    final previousScreen = _activeScreens[panelIndex];

    // Early return if no actual change
    if (previousScreen == screenType) {
      return; // No change - skip unnecessary processing
    }

    // Cancel any pending debounce timer FOR THIS PANEL ONLY
    _updateDebounceTimers[panelIndex]?.cancel();

    // Track the pending screen change so we can complete it if needed
    _pendingScreenChanges[panelIndex] = _PendingScreenChange(
      panelIndex: panelIndex,
      previousScreen: previousScreen,
      newScreen: screenType,
    );

    // Debounce the update for this specific panel
    _updateDebounceTimers[panelIndex] = Timer(_updateDebounceDelay, () {
      _pendingScreenChanges.remove(panelIndex);
      _performScreenUpdate(panelIndex, previousScreen, screenType);
      // Clean up timer reference after execution
      _updateDebounceTimers.remove(panelIndex);
    });
  }

  /// Refresh subscriptions for the current screen (when data becomes available after initial load)
  /// This bypasses the "no change" check and re-subscribes with fresh data
  void refreshCurrentScreen(int panelIndex, ScreenType? screenType) {
    if (screenType == null) return;

    log('WebSubscriptionManager: Refreshing subscriptions for $screenType');

    // Re-subscribe to get fresh symbols (data may have been fetched since initial load)
    _subscribeToScreen(screenType);
  }

  /// Actually perform the screen update (called after debounce)
  void _performScreenUpdate(int panelIndex, ScreenType? previousScreen, ScreenType? screenType) {
    log('WebSubscriptionManager: Panel $panelIndex screen changed from $previousScreen to $screenType');

    // CRITICAL FIX: Before unsubscribing, complete ALL pending subscription timers
    // This ensures _screenSubscriptions is fully populated for all panels
    // Without this, the unsubscribe check may think no other panel needs the symbols
    _completePendingSubscriptionTimers(excludePanelIndex: panelIndex);

    // Unsubscribe from previous screen if it exists
    if (previousScreen != null) {
      _unsubscribeFromScreen(previousScreen);
    }

    // Update active screen
    if (screenType != null) {
      _activeScreens[panelIndex] = screenType;
      _subscribeToScreen(screenType);
    } else {
      _activeScreens.remove(panelIndex);
    }

    notifyListeners();
  }

  /// Complete all pending subscription timers immediately (except for the excluded panel)
  /// This ensures _screenSubscriptions is fully populated before any unsubscription logic runs
  void _completePendingSubscriptionTimers({int? excludePanelIndex}) {
    final pendingPanels = _pendingScreenChanges.keys.toList();

    for (final panelIdx in pendingPanels) {
      if (panelIdx == excludePanelIndex) continue; // Skip the panel being changed

      final pending = _pendingScreenChanges[panelIdx];
      final timer = _updateDebounceTimers[panelIdx];

      if (pending != null && timer != null && timer.isActive) {
        timer.cancel();

        // For initial subscriptions (previousScreen is null), we just need to subscribe
        // For screen changes, we'd do the full update - but during initial load,
        // previousScreen is typically null, so we just subscribe the new screen
        final screenToSubscribe = pending.newScreen;
        if (screenToSubscribe != null && !_screenSubscriptions.containsKey(screenToSubscribe)) {
          _activeScreens[panelIdx] = screenToSubscribe;
          _subscribeToScreen(screenToSubscribe);
        }
      }

      _updateDebounceTimers.remove(panelIdx);
      _pendingScreenChanges.remove(panelIdx);
    }
  }
  
  /// Subscribe to a screen's data
  Future<void> _subscribeToScreen(ScreenType screenType) async {
    if (!_isUserLoggedIn()) {
      log('WebSubscriptionManager: Not subscribing - user not logged in');
      return;
    }

    final subscriptionType = _screenSubscriptionTypes[screenType] ?? SubscriptionType.none;

    if (subscriptionType == SubscriptionType.none) {
      return; // Screen doesn't need subscriptions
    }

    // Check WebSocket readiness BEFORE getting symbols
    if (!_isWebSocketReady()) {
      // Queue empty set - will be filled when retry happens
      _queueSubscription(screenType, {}, 0);
      return;
    }

    final context = _getValidContext();
    if (context == null) {
      log('WebSubscriptionManager: No valid context for subscription');
      return;
    }

    log('WebSubscriptionManager: Subscribing to $screenType (type: $subscriptionType)');

    try {
      // For dashboard, ensure top indices are fetched first
      if (screenType == ScreenType.dashboard) {
        final indexProvider = ref.read(indexListProvider);
        // Ensure top indices are available
        if (indexProvider.topIndicesForDashboard == null) {
          await indexProvider.getTopIndicesForDashboard(context);
        }
      }
      
      // For trade action, ensure trade action data is fetched first
      if (screenType == ScreenType.tradeAction) {
        final stocksProvider = ref.read(stocksProvide);
        // Ensure trade action data is available
        if (stocksProvider.topGainers.isEmpty && stocksProvider.topLosers.isEmpty) {
          await stocksProvider.fetchTradeAction("NSE", "NSEALL", "topG_L", "topG_L");
          await stocksProvider.fetchTradeAction("NSE", "NSEALL", "mostActive", "mostActive");
        }
      }
      
      // Note: Order book handles its own tab-specific subscriptions via changeTabIndex
      // No need to fetch data here as it's handled in _handleOrderBookTap

      // Get symbols that need subscription for this screen
      Set<String> symbolsToSubscribe = _getSymbolsForScreen(screenType, subscriptionType);

      if (symbolsToSubscribe.isEmpty) {
        log('WebSubscriptionManager: No symbols to subscribe for $screenType');
        return;
      }

      // Filter out symbols that are already subscribed
      final newSymbols = symbolsToSubscribe.where((symbol) =>
        !_currentWebSocketSubscriptions.contains(symbol)
      ).toSet();

      if (newSymbols.isEmpty) {
        if (symbolsToSubscribe.length <= 10) {
        }
        // Still track these symbols for this screen even if already subscribed
        // This ensures proper cleanup when screen is removed
        _screenSubscriptions[screenType] = symbolsToSubscribe;
        log('WebSubscriptionManager: All symbols for $screenType already subscribed');
        return;
      }

      if (newSymbols.length <= 10) {
      }
      log('WebSubscriptionManager: Subscribing to ${newSymbols.length} new symbols for $screenType');

      // Final WebSocket check before sending
      if (!_isWebSocketReady()) {
        _queueSubscription(screenType, symbolsToSubscribe, 0);
        return;
      }

      // Subscribe via websocket provider (which handles the subscription manager integration)
      final wsProvider = ref.read(websocketProvider);
      final symbolString = newSymbols.join('#');

      // Use connectTouchLine which properly tracks subscriptions - touchline for web
      wsProvider.connectTouchLine(
        task: "t",
        input: symbolString,
        context: context,
      );

      // Track these symbols as subscribed (for deduplication)
      _currentWebSocketSubscriptions.addAll(newSymbols);

      // ADD TO MASTER LIST (for reconnection)
      _activeSubscriptions.addAll(newSymbols);


      // Store symbols per screen type for cleanup later
      _screenSubscriptions[screenType] = symbolsToSubscribe;


    } catch (e) {
      log('WebSubscriptionManager: Error subscribing to $screenType: $e');
      // Queue for retry on error
      final symbols = _getSymbolsForScreen(screenType, _screenSubscriptionTypes[screenType] ?? SubscriptionType.none);
      if (symbols.isNotEmpty) {
        _queueSubscription(screenType, symbols, 0);
      }
    }
  }

  /// Get symbols that need subscription for a screen type
  Set<String> _getSymbolsForScreen(ScreenType screenType, SubscriptionType subscriptionType) {
    Set<String> symbols = {};

    try {
      switch (subscriptionType) {
        case SubscriptionType.marketWatch:
          if (screenType == ScreenType.dashboard) {
            // Dashboard needs top indices, default indices, and trade action stocks
            final indexProvider = ref.read(indexListProvider);

            // Get top indices tokens (8 specific indices for dashboard)
            indexProvider.requestTopIndicesToken();
            final topIndicesToken = indexProvider.topIndicesToken;
            if (topIndicesToken.isNotEmpty) {
              // Parse tokens from string format "exch|token#exch|token#..."
              final tokens = topIndicesToken.split('#').where((t) => t.isNotEmpty && t.trim().isNotEmpty);
              symbols.addAll(tokens);
            }

            // Get default indices tokens (Nifty, Sensex, etc.)
            indexProvider.requestdefaultIndex();
            final defaultTokens = indexProvider.indexToken;
            if (defaultTokens.isNotEmpty) {
              // Parse tokens from string format "exch|token#exch|token#..."
              final tokens = defaultTokens.split('#').where((t) => t.isNotEmpty && t.trim().isNotEmpty);
              symbols.addAll(tokens);
            }

            // Add trade action stocks for "Today's trade action" section
            final stocksProvider = ref.read(stocksProvide);

            // Top gainers (first 5 shown in dashboard)
            for (var stock in stocksProvider.topGainers.take(5)) {
              if (stock.exch != null && stock.token != null) {
                symbols.add('${stock.exch}|${stock.token}');
              }
            }

            // Top losers (first 5 shown in dashboard)
            for (var stock in stocksProvider.topLosers.take(5)) {
              if (stock.exch != null && stock.token != null) {
                symbols.add('${stock.exch}|${stock.token}');
              }
            }

            // Volume breakout (first 5 shown in dashboard)
            for (var stock in stocksProvider.byVolume.take(5)) {
              if (stock.exch != null && stock.token != null) {
                symbols.add('${stock.exch}|${stock.token}');
              }
            }

            // Most active (first 5 shown in dashboard)
            for (var stock in stocksProvider.byValue.take(5)) {
              if (stock.exch != null && stock.token != null) {
                symbols.add('${stock.exch}|${stock.token}');
              }
            }
          } else if (screenType == ScreenType.tradeAction) {
            // Trade action needs all trade action stocks (all tabs combined)
            final stocksProvider = ref.read(stocksProvide);
            
            // Get all trade action stocks from all tabs
            final allTradeActionStocks = <String>{};
            
            // Top gainers
            for (var stock in stocksProvider.topGainers) {
              if (stock.exch != null && stock.token != null) {
                allTradeActionStocks.add('${stock.exch}|${stock.token}');
              }
            }
            
            // Top losers
            for (var stock in stocksProvider.topLosers) {
              if (stock.exch != null && stock.token != null) {
                allTradeActionStocks.add('${stock.exch}|${stock.token}');
              }
            }
            
            // Volume breakout
            for (var stock in stocksProvider.byVolume) {
              if (stock.exch != null && stock.token != null) {
                allTradeActionStocks.add('${stock.exch}|${stock.token}');
              }
            }
            
            // Most active
            for (var stock in stocksProvider.byValue) {
              if (stock.exch != null && stock.token != null) {
                allTradeActionStocks.add('${stock.exch}|${stock.token}');
              }
            }
            
            symbols.addAll(allTradeActionStocks);
          } else if (screenType == ScreenType.optionChain) {
            // Option chain needs all call/put option tokens from the current chain
            final mwProvider = ref.read(marketWatchProvider);
            final optChain = mwProvider.optionChainModel;
            if (optChain?.optValue != null) {
              for (var option in optChain!.optValue!) {
                if (option.exch != null && option.token != null) {
                  symbols.add('${option.exch}|${option.token}');
                }
              }
            }
          } else {
            // For watchlist and other marketWatch screens, use current watchlist scrips
            final mwProvider = ref.read(marketWatchProvider);
            final currentScrips = mwProvider.scrips;
            for (var scrip in currentScrips) {
              final exch = scrip['exch']?.toString();
              final token = scrip['token']?.toString();
              if (exch != null && token != null && exch.isNotEmpty && token.isNotEmpty) {
                symbols.add('$exch|$token');
              }
            }
          }
          break;

        case SubscriptionType.holdings:
          // Get symbols from holdings
          final portfolio = ref.read(portfolioProvider);
          final holdings = portfolio.holdingsModel ?? [];
          for (var holding in holdings) {
            // Holdings have exchTsym list containing the exchange and token
            final exchTsymList = holding.exchTsym ?? [];
            for (var exchTsym in exchTsymList) {
              if (exchTsym.exch != null && exchTsym.token != null) {
                symbols.add('${exchTsym.exch}|${exchTsym.token}');
              }
            }
          }
          break;

        case SubscriptionType.positions:
          // Get symbols from positions
          final portfolio = ref.read(portfolioProvider);
          final positions = portfolio.postionBookModel ?? [];
          for (var position in positions) {
            if (position.exch != null && position.token != null) {
              symbols.add('${position.exch}|${position.token}');
            }
          }
          break;

        case SubscriptionType.orderBook:
          // Order book handles its own tab-specific subscriptions via changeTabIndex
          // Return empty set as WebSubscriptionManager doesn't manage order book subscriptions
          break;

        case SubscriptionType.none:
          break;
      }
    } catch (e) {
      log('WebSubscriptionManager: Error getting symbols for $screenType: $e');
    }

    return symbols;
  }

  /// Get current watchlist symbols (symbols visible in watchlist panel)
  Set<String> _getWatchlistSymbols() {
    final symbols = <String>{};
    try {
      final mwProvider = ref.read(marketWatchProvider);

      // Get symbols from the current watchlist scrips
      final scrips = mwProvider.scrips;
      for (var scrip in scrips) {
        final exch = scrip['exch']?.toString();
        final token = scrip['token']?.toString();
        if (exch != null && token != null && exch.isNotEmpty && token.isNotEmpty) {
          symbols.add('$exch|$token');
        }
      }
    } catch (e) {
      log('WebSubscriptionManager: Error getting watchlist symbols: $e');
    }
    return symbols;
  }

  /// Get current index symbols (top indices and default indices)
  Set<String> _getIndexSymbols() {
    final symbols = <String>{};
    try {
      final indexProvider = ref.read(indexListProvider);

      // Add top indices (dashboard)
      final topIndices = indexProvider.topIndicesForDashboard?.indValues ?? [];
      for (var index in topIndices) {
        if (index.exch != null && index.token != null) {
          symbols.add('${index.exch}|${index.token}');
        }
      }

      // Add default indices
      final defaultIndices = indexProvider.defaultIndexList?.indValues ?? [];
      for (var index in defaultIndices) {
        if (index.exch != null && index.token != null) {
          symbols.add('${index.exch}|${index.token}');
        }
      }
    } catch (e) {
      log('WebSubscriptionManager: Error getting index symbols: $e');
    }
    return symbols;
  }

  /// Subscribe to ticker symbols (positions) - these persist across screen changes
  /// Call this after positions data is fetched to ensure ticker always shows live data
  Future<void> subscribeTickerSymbols(BuildContext context) async {
    if (!_isUserLoggedIn()) {
      log('WebSubscriptionManager: Not subscribing ticker - user not logged in');
      return;
    }

    // Check WebSocket readiness
    if (!_isWebSocketReady()) {
      return;
    }


    try {
      // Get position symbols for ticker
      final portfolio = ref.read(portfolioProvider);
      final positions = portfolio.postionBookModel ?? [];

      final newTickerSymbols = <String>{};
      for (var position in positions) {
        if (position.exch != null && position.token != null) {
          newTickerSymbols.add('${position.exch}|${position.token}');
        }
      }

      if (newTickerSymbols.isEmpty) {
        return;
      }

      // Find symbols that need to be subscribed (not already in master list)
      final symbolsToSubscribe = newTickerSymbols.where((symbol) =>
        !_currentWebSocketSubscriptions.contains(symbol)
      ).toSet();

      // Update ticker subscriptions tracking
      _tickerSubscriptions.clear();
      _tickerSubscriptions.addAll(newTickerSymbols);

      if (symbolsToSubscribe.isEmpty) {
        return;
      }

      if (symbolsToSubscribe.length <= 10) {
      }

      // Subscribe via websocket
      final wsProvider = ref.read(websocketProvider);
      final symbolString = symbolsToSubscribe.join('#');

      wsProvider.connectTouchLine(
        task: "t",
        input: symbolString,
        context: context,
      );

      // Track subscriptions
      _currentWebSocketSubscriptions.addAll(symbolsToSubscribe);
      _activeSubscriptions.addAll(symbolsToSubscribe);


    } catch (e) {
      log('WebSubscriptionManager: Error subscribing ticker symbols: $e');
    }
  }

  /// Refresh ticker subscriptions when positions data changes
  /// Call this after positions are fetched/refreshed
  Future<void> refreshTickerSubscriptions(BuildContext context) async {
    await subscribeTickerSymbols(context);
  }

  /// Get current ticker (position) symbols
  Set<String> _getTickerSymbols() {
    final symbols = <String>{};
    try {
      final portfolio = ref.read(portfolioProvider);
      final positions = portfolio.postionBookModel ?? [];
      for (var position in positions) {
        if (position.exch != null && position.token != null) {
          symbols.add('${position.exch}|${position.token}');
        }
      }
    } catch (e) {
      log('WebSubscriptionManager: Error getting ticker symbols: $e');
    }
    return symbols;
  }

  /// Unsubscribe from a screen's data
  Future<void> _unsubscribeFromScreen(ScreenType screenType) async {
    final context = _getValidContext();
    if (context == null) {
      log('WebSubscriptionManager: No valid context for unsubscription');
      return;
    }

    final subscriptionType = _screenSubscriptionTypes[screenType] ?? SubscriptionType.none;

    if (subscriptionType == SubscriptionType.none) {
      return; // Screen doesn't have subscriptions
    }


    // Get symbols that were subscribed for this screen
    final screenSymbols = _screenSubscriptions[screenType];
    if (screenSymbols == null || screenSymbols.isEmpty) {
      log('WebSubscriptionManager: No symbols tracked for $screenType, skipping unsubscribe');
      return;
    }

    // Everything still on screen elsewhere (one shared definition).
    final symbolsStillNeeded = _protectedSymbols(exceptScreen: screenType);

    // Find symbols that can be unsubscribed (not needed by any other screen)
    final symbolsToUnsubscribe = screenSymbols.where((symbol) =>
      !symbolsStillNeeded.contains(symbol)
    ).toSet();

    if (symbolsToUnsubscribe.isEmpty) {
      log('WebSubscriptionManager: All symbols for $screenType still needed by other screens');
      return;
    }

    if (symbolsToUnsubscribe.length <= 10) {
    }
    log('WebSubscriptionManager: Unsubscribing from ${symbolsToUnsubscribe.length} symbols for $screenType');

    try {
      // Unsubscribe via websocket provider
      final wsProvider = ref.read(websocketProvider);
      final symbolString = symbolsToUnsubscribe.join('#');

      // Screens subscribe via touchline ("t"), so tear down with "u"
      wsProvider.connectTouchLine(
        task: "u", // Unsubscribe touchline task
        input: symbolString,
        context: context,
        protectionChecked: true,
      );

      // Remove these symbols from our tracking (deduplication)
      _currentWebSocketSubscriptions.removeAll(symbolsToUnsubscribe);

      // REMOVE FROM MASTER LIST (for reconnection)
      _activeSubscriptions.removeAll(symbolsToUnsubscribe);


      // Clear the screen's subscription record
      _screenSubscriptions.remove(screenType);

      log('WebSubscriptionManager: Successfully unsubscribed from $screenType');
    } catch (e) {
      log('WebSubscriptionManager: Error unsubscribing from $screenType: $e');
    }
  }

  /// Update watchlist subscriptions when switching between watchlist tabs
  /// This properly unsubscribes old watchlist symbols and subscribes to new ones
  /// while protecting symbols used by other screens
  Future<void> updateWatchlistSubscriptions({
    required Set<String> oldSymbols,
    required Set<String> newSymbols,
    required BuildContext context,
  }) async {

    // Symbols other screens still show — the watchlist's own (old tab) symbols
    // are what we are replacing, so they are not protected here.
    final protectedSymbols = _protectedSymbols(
        exceptScreen: ScreenType.watchlist, includeWatchlist: false);

    // Find symbols to unsubscribe (in old but not in new, and not protected)
    final symbolsToUnsubscribe = oldSymbols.where((symbol) =>
      !newSymbols.contains(symbol) && !protectedSymbols.contains(symbol)
    ).toSet();

    // Find symbols to subscribe (in new but not currently subscribed)
    final symbolsToSubscribe = newSymbols.where((symbol) =>
      !_currentWebSocketSubscriptions.contains(symbol)
    ).toSet();


    final wsProvider = ref.read(websocketProvider);

    // Unsubscribe old symbols
    if (symbolsToUnsubscribe.isNotEmpty) {
      if (symbolsToUnsubscribe.length <= 10) {
      }

      try {
        final symbolString = symbolsToUnsubscribe.join('#');
        wsProvider.connectTouchLine(
          task: "u",
          input: symbolString,
          context: context,
          protectionChecked: true,
        );

        // Remove from tracking
        _currentWebSocketSubscriptions.removeAll(symbolsToUnsubscribe);
        _activeSubscriptions.removeAll(symbolsToUnsubscribe);
      } catch (e) {
      }
    }

    // Subscribe to new symbols
    if (symbolsToSubscribe.isNotEmpty) {
      if (symbolsToSubscribe.length <= 10) {
      }

      try {
        final symbolString = symbolsToSubscribe.join('#');
        wsProvider.connectTouchLine(
          task: "t",
          input: symbolString,
          context: context,
        );

        // Add to tracking
        _currentWebSocketSubscriptions.addAll(symbolsToSubscribe);
        _activeSubscriptions.addAll(symbolsToSubscribe);
      } catch (e) {
      }
    }

    // Update the watchlist screen subscription record with new symbols
    _screenSubscriptions[ScreenType.watchlist] = newSymbols;

  }

  /// Get current watchlist symbols as a set (for use in updateWatchlistSubscriptions)
  Set<String> getCurrentWatchlistSymbols() {
    return _screenSubscriptions[ScreenType.watchlist] ?? {};
  }

  /// Every touchline scrip something on screen still shows. The ONE definition
  /// used by screen teardown, watchlist tab switches, unsubscribeTokens, and —
  /// through WebSocketProvider.touchlineProtection — every raw "u" anywhere in
  /// the app (Option Flash, Scalper, strategy builder, …). There used to be
  /// three hand-copied lists that had drifted apart.
  ///
  /// [exceptScreen]: the screen being torn down (its own symbols are what is
  /// being released). [source] 'futures' / 'optionChain' releases its own list.
  /// [includeWatchlist]: false for a watchlist tab switch (old tab's symbols).
  Set<String> _protectedSymbols({
    ScreenType? exceptScreen,
    String source = 'unknown',
    bool includeWatchlist = true,
  }) {
    final protectedSymbols = <String>{};
    try {
      // Every screen's tracked subscriptions.
      for (final entry in _screenSubscriptions.entries) {
        if (entry.key != exceptScreen) protectedSymbols.addAll(entry.value);
      }
      // Watchlist rows on screen.
      if (includeWatchlist) protectedSymbols.addAll(_getWatchlistSymbols());
      // Depth panel scrip.
      final marketWatch = ref.read(marketWatchProvider);
      final depthSymbol = marketWatch.currentDepthSymbol;
      if (depthSymbol != null && depthSymbol.isNotEmpty) {
        protectedSymbols.add(depthSymbol);
      }
      // Indices (dashboard + header).
      protectedSymbols.addAll(_getIndexSymbols());
      // Holdings + positions.
      final portfolio = ref.read(portfolioProvider);
      for (final holding in portfolio.holdingsModel ?? []) {
        for (final exchTsym in holding.exchTsym ?? []) {
          if (exchTsym.exch != null && exchTsym.token != null) {
            protectedSymbols.add('${exchTsym.exch}|${exchTsym.token}');
          }
        }
      }
      for (final position in portfolio.postionBookModel ?? []) {
        if (position.exch != null && position.token != null) {
          protectedSymbols.add('${position.exch}|${position.token}');
        }
      }
      // Futures list / option chain: protected by their touchline owners
      // ('futures' / 'option-chain') while their page is open. Their models
      // stay loaded after it closes, so protecting from the models kept a
      // closed page's strikes subscribed. [source] is still accepted.
      // Ticker header (positions) — always live.
      protectedSymbols.addAll(_tickerSubscriptions);
      // Symbols shown in the order window's depth panel.
      protectedSymbols.addAll(_orderDepthRefs.keys);
    } catch (e) {
      log('WebSubscriptionManager: Error collecting protected symbols: $e');
    }
    return protectedSymbols;
  }

  /// Unsubscribe specific tokens (for option chain, futures symbol changes)
  /// This method checks for protected symbols before unsubscribing
  /// Protected symbols: watchlist, depth, holdings, positions, indices, other active screens
  ///
  /// [bypassProtection] skips the protected-symbol filter entirely. Used only by
  /// the depth teardown when the whole single-stock page is disposed: the depth
  /// ("d") feed is genuinely no longer displayed anywhere, and a depth "ud"
  /// does NOT affect the touchline ("t") feed the watchlist/holdings still use.
  Future<void> unsubscribeTokens({
    required Set<String> tokensToCheck,
    required BuildContext context,
    String source = 'unknown',
    bool bypassProtection = false,
  }) async {
    if (tokensToCheck.isEmpty) {
      return;
    }


    final protectedSymbols = _protectedSymbols(source: source);

    // Find tokens that can be unsubscribed (not protected). When the page is
    // being torn down, bypassProtection releases the depth feed unconditionally
    // (touchline protections don't apply to a depth "ud").
    // final tokensToUnsubscribe = bypassProtection
    //     ? tokensToCheck.toSet()
    //     : tokensToCheck.where((token) =>
    //         !protectedSymbols.contains(token)
    //       ).toSet();
    // Except a depth feed the order window's panel is still showing: that one
    // is kept, and the panel releases it when it closes.
    final Set<String> tokensToUnsubscribe;
    if (bypassProtection) {
      final heldByOrderDepth = source == 'depth'
          ? tokensToCheck.where(_orderDepthRefs.containsKey).toSet()
          : <String>{};
      tokensToUnsubscribe = tokensToCheck.difference(heldByOrderDepth);
    } else {
      tokensToUnsubscribe = tokensToCheck
          .where((token) => !protectedSymbols.contains(token))
          .toSet();
    }

    if (tokensToUnsubscribe.isEmpty) {
      return;
    }

    if (tokensToUnsubscribe.length <= 10) {
    }

    try {
      // Unsubscribe via websocket provider
      final wsProvider = ref.read(websocketProvider);
      final symbolString = tokensToUnsubscribe.join('#');

      // Only the depth panel (source 'depth') subscribes via the depth feed
      // ("d") and must be torn down with "ud". Every other web source now
      // subscribes via touchline ("t"), so it unsubscribes with "u".
      wsProvider.connectTouchLine(
        task: source == 'depth' ? "ud" : "u",
        input: symbolString,
        context: context,
        protectionChecked: true,
      );

      // Remove from tracking — touchline only. A depth "ud" releases just the
      // depth feed and leaves the touchline subscription live on the socket,
      // so the scrip must stay in the touchline restore list. Removing it here
      // silently dropped it from the next reconnect: the watchlist row and
      // header ticker of every scrip the user had opened and left froze.
      if (source != 'depth') {
        _currentWebSocketSubscriptions.removeAll(tokensToUnsubscribe);
        _activeSubscriptions.removeAll(tokensToUnsubscribe);
      }


    } catch (e) {
      log('WebSubscriptionManager: Error unsubscribing tokens for $source: $e');
    }
  }

  /// Update context for future use
  void updateContext(BuildContext context) {
    _lastValidContext = context;
    log('WebSubscriptionManager: Context updated');
  }
  
  /// Get a valid context
  BuildContext? _getValidContext() {
    // The last context a screen handed us, as long as it is still mounted.
    // This used to expire after 30 minutes regardless — and with no fallback,
    // every restore after that (master list, screen subscribe, the tab-return
    // reconnect) silently aborted: after half an hour without a focus or
    // resize event, a socket drop brought back only the owner-registered
    // feeds, and the watchlist, indices and ticker stayed frozen.
    try {
      if (_lastValidContext != null && _lastValidContext!.mounted) {
        return _lastValidContext;
      }
    } catch (e) {
      log('WebSubscriptionManager: Recent context is no longer valid: $e');
    }
    // Fall back to the app navigator — always mounted on web.
    try {
      return getNavigatorContext();
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final previousState = _currentState;
    _currentState = state;
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _handleAppGoingToBackground();
        break;
        
      case AppLifecycleState.resumed:
        _handleAppResumed(previousState);
        break;
        
      case AppLifecycleState.inactive:
        break;
    }
  }
  
  void _handleAppGoingToBackground() {
    _lastPauseTime = DateTime.now();
    log('WebSubscriptionManager: App going to background');
    
    final wsProvider = ref.read(websocketProvider);
    _wasDisconnectedInBackground = !wsProvider.wsConnected;
  }
  
  void _handleAppResumed(AppLifecycleState previousState) {
    log('WebSubscriptionManager: App resumed from $previousState');

    // On web, the browser visibilitychange handler (_onBrowserVisibilityChange)
    // is more reliable for detecting tab switches. However, AppLifecycleState.resumed
    // can still fire in some cases (e.g., window minimize/restore), so handle it too.
    // Use the same force-reconnect approach to ensure all screens get fresh data.
    if (_shouldReconnect()) {
      log('WebSubscriptionManager: Reconnection needed, forcing full reconnect');
      _forceReconnectAndResubscribe();
    } else if (_activeSubscriptions.isNotEmpty && _currentWebSocketSubscriptions.isEmpty) {
      // Connection appears alive but no subscriptions tracked - re-send from master list
      log('WebSubscriptionManager: Connection alive but subscriptions lost, restoring from master list');
      _sendAllSubscriptionsFromMasterList();
    } else {
      log('WebSubscriptionManager: WebSocket still connected, no reconnection needed');
    }
  }
  
  void _handleNetworkChange(ConnectivityResult result) {
    log('WebSubscriptionManager: Network changed from $_lastNetworkStatus to $result');

    final wasConnected = _lastNetworkStatus != ConnectivityResult.none;
    final isNowConnected = result != ConnectivityResult.none;

    _lastNetworkStatus = result;

    final wsProvider = ref.read(websocketProvider);

    // NETWORK LOSS: mark socket as zombie so the state machine knows not to
    // attempt reconnects until network returns. Previously the socket would
    // sit in a "still connected" state with the underlying TCP dead until
    // the (now-removed) ping path detected it ~30 s later.
    if (wasConnected && !isNowConnected) {
      log('WebSubscriptionManager: Network lost, marking socket zombie');
      wsProvider.markZombie();
      return;
    }

    // NETWORK RESTORE: force a fresh reconnect rather than just re-subscribing
    // on the existing channel. The browser may report online before the channel
    // actually recovers — sending subscribes on a zombie channel was the old
    // failure mode.
    if (!wasConnected && isNowConnected && _isUserLoggedIn()) {
      log('WebSubscriptionManager: Network restored, forcing fresh reconnect');
      _forceReconnectAndResubscribe();
    }
  }
  
  bool _shouldReconnect() {
    if (!_isUserLoggedIn()) {
      return false;
    }
    
    final wsProvider = ref.read(websocketProvider);
    
    // Reconnect if websocket is disconnected and we have active screens
    if (!wsProvider.wsConnected && _activeScreens.isNotEmpty) {
      return true;
    }
    
    // If websocket was disconnected when we went to background
    if (_wasDisconnectedInBackground && _activeScreens.isNotEmpty) {
      return true;
    }
    
    return false;
  }
  
  /// Restore subscriptions for all active screens
  Future<void> _restoreActiveSubscriptions() async {
    if (!_isUserLoggedIn()) {
      log('WebSubscriptionManager: Session invalid, aborting restoration');
      return;
    }

    if (_activeScreens.isEmpty) {
      log('WebSubscriptionManager: No active screens to restore');
      return;
    }

    final context = _getValidContext();
    if (context == null) {
      log('WebSubscriptionManager: No valid context for restoration');
      return;
    }

    log('WebSubscriptionManager: Restoring subscriptions for ${_activeScreens.length} active screens');

    // Clear current tracking since we're doing a full restore
    _currentWebSocketSubscriptions.clear();
    _screenSubscriptions.clear();

    // Restore subscriptions for each active screen
    for (final screenType in _activeScreens.values) {
      if (screenType != null) {
        await _subscribeToScreen(screenType);
      }
    }
  }
  
  /// Check if user is logged in with valid session
  bool _isUserLoggedIn() {
    try {
      final Preferences pref = locator<Preferences>();
      
      final clientSession = pref.clientSession;
      final clientId = pref.clientId;
      final sessCheckValid = ConstantName.sessCheck;
      
      final isLoggedIn = (clientSession?.isNotEmpty ?? false) && 
                        (clientId?.isNotEmpty ?? false) && 
                        sessCheckValid;
      
      if (!isLoggedIn) {
        log('WebSubscriptionManager: User session invalid - clearing active screens');
        _activeScreens.clear();
      }
      
      return isLoggedIn;
    } catch (e) {
      log('WebSubscriptionManager: Error checking user session: $e');
      return false;
    }
  }
  
  /// Clear all active screens and subscriptions
  void clearAll() {
    log('WebSubscriptionManager: Clearing all active screens');

    final context = _getValidContext();
    if (context != null) {
      // Unsubscribe all tracked websocket subscriptions
      if (_currentWebSocketSubscriptions.isNotEmpty) {
        try {
          final wsProvider = ref.read(websocketProvider);
          final symbolString = _currentWebSocketSubscriptions.join('#');

          log('WebSubscriptionManager: Unsubscribing from ${_currentWebSocketSubscriptions.length} symbols');

          wsProvider.connectTouchLine(
            task: "u", // Unsubscribe touchline for web
            input: symbolString,
            context: context,
            protectionChecked: true,
          );
        } catch (e) {
          log('WebSubscriptionManager: Error during clearAll unsubscribe: $e');
        }
      }
    }

    _activeScreens.clear();
    _screenSubscriptions.clear();
    _currentWebSocketSubscriptions.clear();
    _activeSubscriptions.clear(); // Clear master list on logout
    _tickerSubscriptions.clear(); // Clear ticker subscriptions on logout
    notifyListeners();
  }

  /// Get debug info
  Map<String, dynamic> getDebugInfo() {
    return {
      'activeScreens': _activeScreens.map((k, v) => MapEntry(k.toString(), v?.toString())),
      'screenSubscriptions': _screenSubscriptions.map((k, v) => MapEntry(k.toString(), v.length.toString())),
      'currentWebSocketSubscriptions': _currentWebSocketSubscriptions.length,
      'activeSubscriptions (master list)': _activeSubscriptions.length,
      'tickerSubscriptions': _tickerSubscriptions.length,
      'tickerSymbols': _tickerSubscriptions.toList(),
      'websocketSymbols': _currentWebSocketSubscriptions.toList(),
      'masterListSymbols': _activeSubscriptions.toList(),
      'currentState': _currentState.toString(),
      'lastPauseTime': _lastPauseTime?.toIso8601String(),
      'wasDisconnectedInBackground': _wasDisconnectedInBackground,
      'lastNetworkStatus': _lastNetworkStatus.toString(),
    };
  }
  
  @override
  void dispose() {
    // Remove browser visibility listener
    html.document.removeEventListener('visibilitychange', _onBrowserVisibilityChange);

    // Cancel all per-panel debounce timers
    for (final timer in _updateDebounceTimers.values) {
      timer.cancel();
    }
    _updateDebounceTimers.clear();

    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();

    // Remove websocket listener
    if (_wsProviderListener != null) {
      try {
        ref.read(websocketProvider).removeListener(_wsProviderListener!);
      } catch (e) {
        log('WebSubscriptionManager: Error removing websocket listener: $e');
      }
    }

    _activeScreens.clear();
    _screenSubscriptions.clear();
    _currentWebSocketSubscriptions.clear();
    _activeSubscriptions.clear(); // Clear master list
    _tickerSubscriptions.clear(); // Clear ticker subscriptions
    _pendingSubscriptionQueue.clear();
    _pendingScreenChanges.clear();
    super.dispose();
  }
}

/// Pending subscription waiting for WebSocket to be ready
class _PendingSubscription {
  final ScreenType screenType;
  final Set<String> symbols;
  final int retryCount;
  final DateTime timestamp;

  _PendingSubscription({
    required this.screenType,
    required this.symbols,
    required this.retryCount,
    required this.timestamp,
  });
}

/// Pending screen change waiting to be processed (used to fast-track subscriptions)
class _PendingScreenChange {
  final int panelIndex;
  final ScreenType? previousScreen;
  final ScreenType? newScreen;

  _PendingScreenChange({
    required this.panelIndex,
    required this.previousScreen,
    required this.newScreen,
  });
}

/// Subscription types that different screens need
enum SubscriptionType {
  none,
  marketWatch,
  holdings,
  positions,
  orderBook,
}

/// Provider for WebSubscriptionManager
final webSubscriptionManagerProvider = ChangeNotifierProvider<WebSubscriptionManager>((ref) {
  return WebSubscriptionManager(ref);
});

