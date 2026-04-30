import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/provider/fund_provider.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/provider/network_state_provider.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/portfolio_provider.dart';
import 'package:mynt_plus/routes/app_routes.dart';
import 'package:mynt_plus/routes/route_names.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/core/api_link.dart';
import '../locator/constant.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import 'market_watch_provider.dart';
import 'notification_provider.dart';
import 'subscription_manager.dart';
import 'web_subscription_manager.dart';

final websocketProvider = ChangeNotifierProvider((ref) => WebSocketProvider(ref));

class WebSocketProvider extends ChangeNotifier {
  final Ref ref;
  WebSocketProvider(this.ref);

  // Constants
  static const int _maxReconnectAttempts = 8; // Increased for poor networks
  static const int _subscriptionTimeout = 10; // Increased timeout for slow networks
  static const Duration _reconnectDelay = Duration(seconds: 2);
  static const Duration _lowBandwidthPingInterval = Duration(seconds: 10); // Ping to keep connection alive

  // Network quality tracking
  Timer? _pingTimer;
  DateTime? _lastMessageTime;
  bool _isLowBandwidth = false;
  int _failedPingCount = 0;
  static const int _maxFailedPings = 3;

  // State management
  bool _wsConnected = false;
  bool _connecting = false;
  int _connectionCount = 0;
  bool _retryScreen = false;
  // Removed unused _wsMount field
  BuildContext? _context;
  bool _reconnecting = false; // Track if we're already in the reconnection process
  bool _reconnectionSuccess = false; // Track if we've successfully reconnected

  // When true, UI should NOT show "Connection lost"/"Connected" toasts.
  // Set by WebSubscriptionManager during intentional tab-switch reconnects.
  bool _isTabSwitchReconnect = false;
  bool get isTabSwitchReconnect => _isTabSwitchReconnect;
  void setTabSwitchReconnect(bool value) {
    _isTabSwitchReconnect = value;
  }
  
  // Track server-initiated closures to prevent reconnection loops
  DateTime? _lastServerClosure;
  int _consecutiveServerClosures = 0;
  static const int _maxConsecutiveClosures = 3; // Stop reconnecting after 3 consecutive closures
  static const Duration _serverClosureCooldown = Duration(seconds: 10); // Cooldown period

  // WebSocket and subscription management
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription; // Track stream subscription to prevent leaks
  Completer<void>? _connectionCompleter;
  final Map<String, Timer> _subscriptionTimers = {};
  final Map<String, dynamic> _socketDatas = {};
  final Map<String, String> _ltpCache = {}; // Cache for last known LTP values
  Timer? _holdStartTime;
  Timer? _reconnectBackoff; // Add backoff timer

  // Add StreamController
  final _socketDataController = StreamController<Map>.broadcast();
  Stream<Map> get socketDataStream => _socketDataController.stream;

  // Getters
  bool get wsConnected => _wsConnected;
  bool get retryScreen => _retryScreen;
  Map get socketDatas => _socketDatas;
  bool get reconnectionSuccess => _reconnectionSuccess;
  
  // Get cached LTP for a token
  String? getCachedLTP(String token) => _ltpCache[token];
  
  // Get best available LTP (socket > cache > fallback)
  String getBestLTP(String token, String fallbackLTP) {
    // First check if we have current socket data
    if (_socketDatas.containsKey(token) && _socketDatas[token]['lp'] != null) {
      final socketLTP = _socketDatas[token]['lp'].toString();
      if (socketLTP != "0.00" && socketLTP != "null") {
        return socketLTP;
      }
    }
    
    // Then check cached LTP
    final cachedLTP = _ltpCache[token];
    if (cachedLTP != null && cachedLTP != "0.00") {
      return cachedLTP;
    }
    
    // Finally fallback to provided value
    return fallbackLTP;
  }

  // Preferences
  final Preferences _pref = locator<Preferences>();

  /// Check if user is logged in with valid session
  bool _isUserLoggedIn() {
    try {
      final clientSession = _pref.clientSession;
      final clientId = _pref.clientId;
      final sessCheckValid = ConstantName.sessCheck;

      return (clientSession?.isNotEmpty ?? false) &&
             (clientId?.isNotEmpty ?? false) &&
             sessCheckValid;
    } catch (e) {
      log('WebSocket: Error checking user session: $e');
      return false;
    }
  }

  int get connectioncount => _connectionCount;

  bool get retryscreen => _retryScreen;

  bool wsmount = true;

  Timer? _debounceTimer; // Added debounce timer for throttling updates
  Timer? _throttleTimer; // Throttle timer for websocket data updates (330ms)
  bool _hasPendingUpdates = false; // Track if we have pending updates to notify

  // Track if provider is disposed to prevent "Trying to render a disposed EngineFlutterView" errors
  bool _isDisposed = false;

  /// Safely notify listeners, checking if provider is disposed first.
  /// Prevents "Trying to render a disposed EngineFlutterView" errors on web.
  void _safeNotifyListeners() {
    if (_isDisposed) {
      log('WebSocket: Skipping notifyListeners - provider is disposed');
      return;
    }
    try {
      notifyListeners();
    } catch (e) {
      log('WebSocket: Error in notifyListeners (likely disposed): $e');
    }
  }

  // Buffer for pending socket data updates - key: token, value: pending update data
  final Map<String, Map<String, dynamic>> _pendingSocketUpdates = {};

  void changeretryscreen(bool value) {
    _retryScreen = value;
    // Use post-frame callback to avoid modifying provider during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeNotifyListeners();
    });
  }

  void changeconnectioncount() {
    _connectionCount = 0;
    // Use post-frame callback to avoid modifying provider during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeNotifyListeners();
    });
  }

  void resetConnectionCount() {
    _connectionCount = 0;
    _reconnectionSuccess = true;

    // Use post-frame callback to avoid modifying provider during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeNotifyListeners();
    });

    // Reset reconnection success flag after a delay to allow UI to update
    Future.delayed(const Duration(seconds: 1), () {
      _reconnectionSuccess = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _safeNotifyListeners();
      });
    });
  }

  /// Force-reset all connection state for a fresh session (e.g. after login).
  /// This handles the case where session expired while the user was away,
  /// leaving _connecting/_reconnecting stuck as true. closeSocket() can't
  /// fix this because its guard `if (_connecting && !_wsConnected) return;`
  /// prevents cleanup during an in-progress connection attempt.
  void resetForNewSession() {
    log('🔄 WebSocket: resetForNewSession called');

    // Cancel all timers first
    _stopPingTimer();
    _reconnectBackoff?.cancel();
    _reconnectBackoff = null;
    _subscriptionDebounce?.cancel();
    _subscriptionDebounce = null;
    for (var timer in _subscriptionTimers.values) {
      timer.cancel();
    }
    _subscriptionTimers.clear();

    // Complete any pending connection completer
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError('Session reset');
    }

    // Close the channel if it exists
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;

    // Reset ALL flags
    _wsConnected = false;
    _connecting = false;
    _reconnecting = false;
    _connectionCount = 0;
    _consecutiveServerClosures = 0;
    _lastServerClosure = null;
    _retryScreen = false;
    _isLowBandwidth = false;
    _failedPingCount = 0;

    // Clear subscriptions and data
    _sentSubscriptions.clear();
    _pendingSubscriptions['t'] = [];
    _pendingSubscriptions['d'] = [];
    _socketDatas.clear();
    _ltpCache.clear();

    log('✅ WebSocket: State reset complete');
  }

  /// Clear the sent-subscriptions tracking so that the next connectTouchLine
  /// call will actually send symbols to the server instead of skipping them.
  /// Call this before re-subscribing after a forced reconnect.
  void clearSentSubscriptions() {
    _sentSubscriptions.clear();
  }

  void closeSocket(bool mounted, {bool force = false, bool preserveData = false}) {
    // Prevent closing if already closed to avoid unnecessary operations
    if (!_wsConnected && _channel == null && !_connecting) {
      log('ℹ️  WebSocket: Already closed, skipping');
      return;
    }

    // Prevent closing if socket is currently being established
    // UNLESS force=true (used by logout/session expiry to ensure clean state)
    if (_connecting && !_wsConnected && !force) {
      log('⚠️  WebSocket: Preventing close during connection establishment');
      return;
    }

    // Get stack trace to see who is calling closeSocket
    final stackTrace = StackTrace.current;
    final callerLines = stackTrace.toString().split('\n');
    // Find the actual caller (skip closeSocket itself)
    String callerInfo = 'Unknown';
    for (int i = 1; i < callerLines.length && i < 6; i++) {
      final line = callerLines[i].trim();
      if (!line.contains('closeSocket') && line.isNotEmpty) {
        callerInfo = line;
        break;
      }
    }

    log('🔴 WebSocket: Closing connection (mounted: $mounted)');
    log('   Caller: $callerInfo');

    wsmount = mounted;
    _wsConnected = false;
    _connecting = false;
    _reconnecting = false; // Reset reconnection flag to ensure we can reconnect properly

    // Stop ping timer
    _stopPingTimer();

    // Cancel any outstanding connection completion
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError("WebSocket connection closed intentionally");
    }

    // Cancel stream subscription BEFORE closing channel to prevent memory leaks
    _channelSubscription?.cancel();
    _channelSubscription = null;

    // Properly close channel
    _channel?.sink.close();
    _channel = null; // Set to null to ensure we create a new one on reconnect

    // Cancel all timers to prevent further reconnection attempts
    for (var timer in _subscriptionTimers.values) {
      timer.cancel();
    }
    _subscriptionTimers.clear();

    // Cancel backoff timer if it exists
    _reconnectBackoff?.cancel();
    _reconnectBackoff = null;

    // Cancel subscription debounce timer
    _subscriptionDebounce?.cancel();
    _subscriptionDebounce = null;

    // Clear sent subscriptions tracking to allow resubscription on reconnect
    _sentSubscriptions.clear();
    _pendingSubscriptions['t'] = [];
    _pendingSubscriptions['d'] = [];

    if (preserveData) {
      // Tab-switch reconnect: keep socket data and LTP cache so UI doesn't flash 0.0
      // Stale prices are better than no prices — new data will overwrite when it arrives
      log('Preserved socket data and LTP cache for tab-switch reconnect');
    } else {
      // Full close (logout/re-login): clear everything for fresh state
      // This fixes the issue where old token data prevents updateHoldingValues()
      // from being called on re-login (tokens already exist, so _updateSocketData()
      // is called instead of the new token path that calls updateHoldingValues())
      _socketDatas.clear();
      _ltpCache.clear();
      log('Cleared all WebSocket subscriptions tracking and socket data');
    }

    log('✅ WebSocket: Connection closed successfully');

    if (mounted) {
      // Use post-frame callback to avoid modifying provider during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _safeNotifyListeners();
      });
      // Schedule a frame so the post-frame callback fires even when idle
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  void websockConn(bool value) {
    _wsConnected = value;

    // Start ping timer if connected in potential low bandwidth
    if (value) {
      _startPingTimer();
    } else {
      _stopPingTimer();
    }

    // Use post-frame callback to avoid modifying provider during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeNotifyListeners();
    });
    // Schedule a frame so the post-frame callback fires even when idle
    WidgetsBinding.instance.scheduleFrame();
  }

  void _startSubscriptionTimer(String key, BuildContext context) {
    // Cancel any existing timer for this key to avoid duplicates
    _subscriptionTimers[key]?.cancel();

    // Only start timer if we're connected
    if (_wsConnected) {
      _subscriptionTimers[key] = Timer(
        const Duration(seconds: _subscriptionTimeout),
        () => _handleSubscriptionTimeout(key, context),
      );
    }
  }

  void _handleSubscriptionTimeout(String key, BuildContext context) {
    // **FIX: Check if provider is disposed before handling timeout**
    if (_isDisposed) {
      log('WebSocket: Skipping _handleSubscriptionTimeout - provider is disposed');
      return;
    }

    // Only increment counter if we're not already reconnecting
    if (!_reconnecting) {
      _connectionCount++;
    }
    _subscriptionTimers.remove(key);

    if (_connectionCount < _maxReconnectAttempts) {
      reconnect(context);
    }
  }

  void _startPingTimer() {
    _stopPingTimer();
    _lastMessageTime = DateTime.now();

    // Set up a timer to ping the server periodically to keep connection alive
    _pingTimer = Timer.periodic(_lowBandwidthPingInterval, (timer) {
      if (_wsConnected && _channel != null) {
        // If we haven't received a message in a while, send a ping
        final now = DateTime.now();
        if (_lastMessageTime != null && now.difference(_lastMessageTime!).inSeconds > _lowBandwidthPingInterval.inSeconds - 5) {
          _sendPing();
        }
      } else {
        _stopPingTimer();
      }
    });
  }

  void _sendPing() {
    // **FIX: Check if provider is disposed before sending ping**
    if (_isDisposed) {
      return;
    }

    try {
      if (_wsConnected && _channel != null) {
        // Send a lightweight ping message
        _channel!.sink.add(jsonEncode({"t": "h"})); // Heartbeat/ping message

        // Track failed pings
        _failedPingCount++;

        // If we've failed too many pings, try to reconnect
        if (_failedPingCount >= _maxFailedPings && !_reconnecting) {
          _isLowBandwidth = true;
          if (_context != null && !_isDisposed) {
            reconnect(_context!);
          }
        }
      }
    } catch (e) {
      // Handle ping failure
    }
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _failedPingCount = 0;
  }

  Future<void> establishConnection({
    required String channelInput,
    required String task,
    required BuildContext context,
  }) async {
    _context = context;

    // Save channel input for reconnection (only if it's a subscription request)
    if (task == "t" && channelInput.isNotEmpty) {
      ConstantName.lastSubscribe = channelInput;
    } else if (task == "d" && channelInput.isNotEmpty) {
      ConstantName.lastSubscribeDepth = channelInput;
    }

    // CRITICAL: Check and set _connecting flag FIRST to prevent race conditions
    // If already connected and we have a subscription request, process it
    if (_wsConnected && _channel != null) {
      log('ℹ️  WebSocket: Already connected, processing subscription');
      if (channelInput.isNotEmpty) {
        _handleSubscription(channelInput, task, context);
      }
      return;
    }

    // If connection already in progress, wait for it to complete
    if (_connecting) {
      log('⏳ WebSocket: Connection already in progress, waiting');
      try {
        // Use a shorter timeout for waiting on an existing connection attempt in low bandwidth
        final timeout = _isLowBandwidth ? const Duration(seconds: 20) : const Duration(seconds: 10);

        await _connectionCompleter?.future.timeout(timeout, onTimeout: () {
          throw TimeoutException('Connection attempt timed out');
        });

        // After connection completes, handle any subscription request
        if (_wsConnected && channelInput.isNotEmpty) {
          _handleSubscription(channelInput, task, context);
        }
      } catch (e) {
        log('⚠️  WebSocket: Waiting for connection timed out: $e');
        // **FIX: Check if provider is disposed before reconnecting from timeout**
        if (_connectionCount < _maxReconnectAttempts && !_reconnecting && !_isDisposed) {
          reconnect(context);
        }
      }
      return;
    }

    // Prevent duplicate connection attempts
    if (_reconnecting) {
      log('⏸️  WebSocket: Reconnection in progress, deferring');
      // Wait a bit and retry
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_wsConnected && !_connecting && channelInput.isNotEmpty) {
          _handleSubscription(channelInput, task, context);
        }
      });
      return;
    }

    // SET _connecting flag IMMEDIATELY to prevent race conditions
    // This must happen before any async operations or WebSocket channel creation
    _connecting = true;
    _connectionCompleter = Completer<void>();

    log('🟡 WebSocket: Attempting connection (attempt ${_connectionCount + 1})');

    // Double-check that channel doesn't already exist
    if (_channel != null) {
      log('⚠️  WebSocket: Closing existing channel before creating new one');
      try {
        _channel?.sink.close();
      } catch (e) {
        log('Error closing old channel: $e');
      }
      _channel = null;
    }

    try {
      // Connect with a timeout appropriate for network conditions
      final connectTimeout = _isLowBandwidth ? const Duration(seconds: 15) : const Duration(seconds: 10);

      final uri = Uri.parse(ApiLinks.wsURL);

      log('📡 WebSocket: Creating channel');

      // Create connection with timeout
      _channel = WebSocketChannel.connect(uri);

      // Set up a timeout for connection
      final timeoutTimer = Timer(connectTimeout, () {
        if (_connecting && (_channel == null || !_wsConnected)) {
          log('⏱️  WebSocket: Connection timeout');
          _handleConnectionError(TimeoutException('WebSocket connection timed out'), context);
        }
      });

      log('📤 WebSocket: Sending connection request');

      // Validate session before sending connection request
      final clientId = _pref.clientId ?? "";
      final clientSession = _pref.clientSession ?? "";
      
      if (clientId.isEmpty || clientSession.isEmpty) {
        log('❌ WebSocket: Invalid credentials');
        _handleConnectionError("Invalid credentials", context);
        return;
      }
      
      // Send connection request
      final connectionRequest = {
        "t": "c",
        "actid": clientId,
        "uid": clientId,
        "source": kIsWeb ? "WEB" : "MOBILE",
        "susertoken": clientSession,
      };
      
      // CRITICAL FIX: Set up stream listener BEFORE sending connection request
      // This prevents race condition where server responds before listener is ready
      // Previously, the listener was set up AFTER sink.add(), which could cause
      // the connection to close before we could receive the server's response

      // Cancel previous stream subscription first to prevent memory leaks
      await _channelSubscription?.cancel();
      _channelSubscription = null;

      log('👂 WebSocket: Setting up stream listener');

      // Create new stream subscription BEFORE sending request
      _channelSubscription = _channel!.stream.listen(
        _handleWebSocketMessage,
        onDone: () => _handleConnectionClosed(context),
        onError: (error) => _handleConnectionError(error, context),
        cancelOnError: false, // Keep listening even if there's an error
      );

      // Now send the connection request
      log('📤 WebSocket: Sending connection request');

      _channel!.sink.add(jsonEncode(connectionRequest));

      log('👂 WebSocket: Waiting for response');

      // Cancel timeout timer as we've successfully set up the connection
      timeoutTimer.cancel();
    } catch (error) {
      log('❌ WebSocket: Connection error: $error');
      _handleConnectionError(error, context);
    }
  }

  void _handleWebSocketMessage(dynamic event) {
    try {
      // Update last message time for ping tracking
      _lastMessageTime = DateTime.now();
      _failedPingCount = 0;

      final res = jsonDecode(event.toString());

      if (res['s']?.toString().toLowerCase() == "ok" && res['t']?.toString() == "ck") {
        log("🟢 WebSocket: ✅ Connected successfully");
        _handleConnectionSuccess();
      } else if (res['t']?.toString().toLowerCase() == "tf" || res['t']?.toString().toLowerCase() == "df") {
        // log("Socket Data: ${res.toString()}");
        _handleMarketData(res);
      } else if (res['t']?.toString().toLowerCase() == "tk" || res['t']?.toString().toLowerCase() == "dk") {
        // log("Socket Data: ${res.toString()}");
        _handleTokenData(res);
      } else if (res['t']?.toString().toLowerCase() == "om" && _context != null) {
        _handleOrderMessage(res);
      } else if (res['t']?.toString().toLowerCase() == "am" && _context != null) {
        _handleAlertMessage(res);
      } else if (res['t']?.toString().toLowerCase() == "h") {
        // Handle heartbeat/ping response
        _failedPingCount = 0;
      }

      // Throttle UI updates to 330ms intervals to improve performance
      _scheduleThrottledUpdate();
    } catch (e) {
      // Log parsing errors for debugging
      log("WebSocket message parsing error: $e");
    }
  }

  /// Schedules a throttled update to prevent excessive UI refreshes
  /// Updates are batched within a 500ms window to reduce CPU load with many subscriptions
  void _scheduleThrottledUpdate() {
    _hasPendingUpdates = true;

    // If throttle timer is already active, just mark that we have pending updates
    if (_throttleTimer?.isActive ?? false) {
      return;
    }

    // PERFORMANCE FIX: Increased throttle from 330ms to 500ms for web performance
    // This reduces updates from 3/sec to 2/sec, lowering CPU usage by ~33%
    // For web apps with many widgets, less frequent updates = smoother experience
    final throttleDuration = kIsWeb ? const Duration(milliseconds: 500) : const Duration(milliseconds: 300);
    _throttleTimer = Timer(throttleDuration, () {
      if (_hasPendingUpdates) {
        _hasPendingUpdates = false;

        // Apply all buffered updates to the main socket data
        _applyBufferedUpdates();

        // CRITICAL FIX: Always notify StreamBuilder listeners after applying updates
        // Previously, _socketDataController.add() was only called inside _updateSocketData
        // when hasUpdates=true. If no individual token had changes, StreamBuilders
        // would never get notified, causing UI to show stale data.
        _socketDataController.add(_socketDatas);

        // Use post-frame callback to avoid modifying provider during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _safeNotifyListeners();
        });
        // Schedule a frame so the post-frame callback fires even when idle
        WidgetsBinding.instance.scheduleFrame();
      }
    });
  }

  /// Applies all buffered socket data updates to the main _socketDatas map
  void _applyBufferedUpdates() {
    if (_pendingSocketUpdates.isEmpty) return;

    // Apply each buffered update
    for (final entry in _pendingSocketUpdates.entries) {
      final token = entry.key;
      final updateData = entry.value;

      // If this is a new token, initialize it
      if (!_socketDatas.containsKey(token)) {
        _socketDatas[token] = <String, dynamic>{};
        _initializeTokenData(token, updateData);

        // Notify stream of new token
        _socketDataController.add(_socketDatas);

        // Update portfolio if we have valid price data
        if (_socketDatas[token]['lp'] != null &&
            _socketDatas[token]['lp'] != '0' &&
            _socketDatas[token]['lp'] != '0.00') {
          ref.read(portfolioProvider).updateHoldingValues(token, _socketDatas[token]);
          // Also update position values for ticker header to show live P&L
          ref.read(portfolioProvider).updatePositionValues(token, _socketDatas[token]);
        }
      } else {
        // Update existing token data
        _updateSocketData(token, updateData);
      }
    }

    // Notify market watch provider with the updated data
    _notifyMarketWatchProvider();

    // NOTE: Don't call _safeNotifyListeners() here directly - it causes
    // "!_debugDuringDeviceUpdate is not true" assertion errors.
    // The caller (_scheduleThrottledUpdate) handles notification via
    // addPostFrameCallback which is safe from mouse tracker conflicts.

    // Clear the buffer after applying
    _pendingSocketUpdates.clear();
  }

  void _handleConnectionSuccess() {
    log('🟢 WebSocket: Connection established and ready');

    _wsConnected = true;
    _connecting = false;
    resetConnectionCount(); // Reset connection count properly
    _reconnecting = false;
    _retryScreen = false; // Ensure retry screen is not shown

    // Reset low bandwidth mode on successful connection
    _isLowBandwidth = false;

    // Reset consecutive server closures counter on successful connection
    _consecutiveServerClosures = 0;
    _lastServerClosure = null;

    // Start ping timer for connection monitoring
    _startPingTimer();

    // Cancel any backoff timer
    _reconnectBackoff?.cancel();
    _reconnectBackoff = null;

    if (!_connectionCompleter!.isCompleted) {
      _connectionCompleter?.complete();
    }

    // Send any pending subscriptions that were queued while connecting
    _sendPendingSubscriptionsAfterConnect();

    log('✅ WebSocket: All connection setup completed');

    // Notify listeners so WebSubscriptionManager can restore subscriptions.
    // scheduleFrame is required: without it, the post-frame callback never
    // fires when the tab was backgrounded — the notify is queued indefinitely,
    // WebSubscriptionManager's listener never wakes up, and subscriptions are
    // never re-sent, so prices only resume after a user click/scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeNotifyListeners();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Send any pending subscriptions after connection is established
  void _sendPendingSubscriptionsAfterConnect() {
    final pendingTouchline = _pendingSubscriptions['t'] ?? [];
    final pendingDepth = _pendingSubscriptions['d'] ?? [];

    log('📋 WebSocket: Pending - touchline: ${pendingTouchline.length}, depth: ${pendingDepth.length}');

    // Check for pending touchline subscriptions
    if (pendingTouchline.isNotEmpty) {
      log('📤 WebSocket: Sending pending touchline subscriptions');
      final symbols = pendingTouchline.toSet().toList();
      final batchInput = symbols.join('#');

      if (symbols.length <= 10) {
      }

      // Track as sent
      final subscriptionKeys = symbols.map((s) => "t:$s").toList();
      _sentSubscriptions.addAll(subscriptionKeys);

      // Clear pending
      _pendingSubscriptions['t'] = [];

      // Send to websocket
      _channel?.sink.add(jsonEncode({"t": "t", "k": batchInput}));
    }

    // Check for pending depth subscriptions
    if (pendingDepth.isNotEmpty) {
      log('📤 WebSocket: Sending pending depth subscriptions');
      final symbols = pendingDepth.toSet().toList();
      final batchInput = symbols.join('#');

      // Track as sent
      final subscriptionKeys = symbols.map((s) => "d:$s").toList();
      _sentSubscriptions.addAll(subscriptionKeys);

      // Clear pending
      _pendingSubscriptions['d'] = [];

      // Send to websocket
      _channel?.sink.add(jsonEncode({"t": "d", "k": batchInput}));
    }

    if (pendingTouchline.isEmpty && pendingDepth.isEmpty) {
    }
  }

  void _handleAlertMessage(Map<String, dynamic> res) {
    // **FIX: Check if provider is disposed before handling alert message**
    if (_isDisposed) return;

    // Show alert message in a SnackBar
    if (res['dmsg'] != null && _context != null) {
      // Display the alert message to the user
      if (kIsWeb) {
        ResponsiveSnackBar.showSuccess(_context!, res['dmsg'].toString());
      } else {
        successMessage(_context!, res['dmsg'].toString());
      }

      // Navigate to the alerts tab (tab index 6) when alert is triggered
      // This will take the user to the alerts tab even if they're on another screen
      try {
        ref.read(orderProvider).changeTabIndex(6, _context!);
      } catch (e) {
        log('WebSocket: Error in changeTabIndex (likely disposed): $e');
      }
    }

    // Update both pending alerts and triggered alerts
    if (_context != null && !_isDisposed) {
      try {
        // Fetch broker messages for triggered alerts
        ref.read(notificationprovider).fetchbrokermsg(_context!);

        // Fetch pending alerts to refresh the list
        ref.read(marketWatchProvider).fetchPendingAlert(_context!);
      } catch (e) {
        log('WebSocket: Error in alert updates (likely disposed): $e');
      }
    }
  }

  void _handleMarketData(Map<String, dynamic> res) {
    final key = res['tk']?.toString();
    if (key == null) return;

    // Buffer the update instead of applying immediately
    _bufferSocketUpdate(key, res);

    // Schedule throttled update to apply buffered changes
    _scheduleThrottledUpdate();
  }

  /// Buffers a socket data update to be applied later during throttle interval
  void _bufferSocketUpdate(String token, Map<String, dynamic> updateData) {
    // If we already have a pending update for this token, merge the new data
    if (_pendingSocketUpdates.containsKey(token)) {
      // Merge new data into existing buffered update
      _pendingSocketUpdates[token]!.addAll(updateData);
    } else {
      // Create a new buffered update entry
      _pendingSocketUpdates[token] = Map<String, dynamic>.from(updateData);
    }
  }

  void _handleTokenData(Map<String, dynamic> res) {
    final key = res['tk']?.toString();
    if (key == null) return;

    // Buffer the update instead of applying immediately
    _bufferSocketUpdate(key, res);

    // Schedule throttled update to apply buffered changes
    _scheduleThrottledUpdate();
  }

  void _handleOrderMessage(Map<String, dynamic> res) {
    if (_holdStartTime?.isActive ?? false) {
      _holdStartTime?.cancel();
    }

    // Show order status notification
    _showOrderStatusNotification(res);
    
    final status = res['status']?.toString().toUpperCase() ?? '';

    _holdStartTime = Timer(const Duration(milliseconds: 500), () {
      if (_context != null) {
        _refreshData(_context!, orderStatus: status);
      }
      _holdStartTime = null;
    });
  }

  /// Shows a snackbar notification based on order status from websocket message
  void _showOrderStatusNotification(Map<String, dynamic> res) {
    if (_context == null) return;

    final status = res['status']?.toString().toUpperCase() ?? '';
    final symbol = res['tsym']?.toString() ?? '';
    final tranType = res['trantype']?.toString().toUpperCase() == 'B' ? 'Buy' : 'Sell';
    final exchange = res['exch']?.toString() ?? '';

    if (status.isEmpty || symbol.isEmpty) return;

    String message;

    switch (status) {
      case 'COMPLETE':
        message = '$tranType order for $symbol ($exchange) executed successfully';
        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(_context!, message);
        } else {
          successMessage(_context!, message);
        }
        break;
      case 'REJECTED':
        // final rejectionReason = res['rejreason']?.toString() ?? res['reporttype']?.toString() ?? 'Order rejected';
        message = '$tranType order for $symbol ($exchange) rejected';
        if (kIsWeb) {
          ResponsiveSnackBar.showError(_context!, message);
        } else {
          warningMessage(_context!, message);
        }
        break;
      case 'OPEN':
        message = '$tranType order for $symbol ($exchange) placed successfully';
        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(_context!, message);
        } else {
          successMessage(_context!, message);
        }
        break;
      case 'PENDING':
        // Skip PENDING notification to avoid duplicate with OPEN
        break;
      case 'CANCELED':
        // Skip CANCELED notification - cancel action already shows success snackbar
        break;
      default:
        // For other statuses like TRIGGER_PENDING, etc.
        if (status.isNotEmpty) {
          message = '$tranType order for $symbol ($exchange): $status';
          if (kIsWeb) {
            // ResponsiveSnackBar.showInfo(_context!, message);
          } else {
            successMessage(_context!, message);
          }
        }
        break;
    }
  }

  void _refreshData(BuildContext context, {String orderStatus = ''}) {
    // **FIX: Check if provider is disposed before using ref.read()**
    // This prevents "provider[_addListener] is not a function" errors
    // that occur when reconnection timer fires after provider disposal
    if (_isDisposed) {
      log('WebSocket: Skipping _refreshData - provider is disposed');
      return;
    }

    // Log session info for debugging session issues
    final sessionForDebug = _pref.clientSession;
    final clientIdForDebug = _pref.clientId;
    log('🔄 WebSocket: _refreshData - clientId: $clientIdForDebug, session: ${sessionForDebug != null && sessionForDebug.isNotEmpty ? sessionForDebug.substring(0, sessionForDebug.length > 10 ? 10 : sessionForDebug.length) : "EMPTY"}...');

    try {
      ref.read(portfolioProvider).fetchHoldings(context, "");
      ref.read(orderProvider).fetchOrderBook(context, true);
      ref.read(orderProvider).fetchTradeBook(context);
      ref.read(orderProvider).fetchGTTOrderBook(context, "");
      ref.read(fundProvider).fetchFunds(context);

      
      if (orderStatus == 'COMPLETE') {
        ref.read(portfolioProvider).fetchPositionBook(context, false).then((_) {
          if (kIsWeb && !_isDisposed) {
            ref
                .read(webSubscriptionManagerProvider)
                .refreshTickerSubscriptions(context);
          }
        });
      }
    } catch (e) {
      log('WebSocket: Error in _refreshData (likely provider disposed): $e');
    }
  }

  void _updateSocketData(String key, Map<String, dynamic> res) {
    final data = _socketDatas[key];
    if (data == null) return;

    // Track if we've made meaningful updates that require UI refresh
    bool hasUpdates = false;

    // CRITICAL FIX: If this is a "dk" (depth key) message, ensure depth data is properly initialized
    // This handles the case where a symbol was first subscribed via touchline ("tk") and later
    // gets a depth subscription ("dk"). The depth-specific fields need to be initialized.
    if (res['t']?.toString().toLowerCase() == "dk") {
      _initializeDepthData(data, res);
      hasUpdates = true;
    }

    // Update only fields that are present in the new data and have changed
    for (final field in res.keys) {
      final value = res[field];

      // Skip update for null values
      if (value == null) continue;

      // For price fields, only update if new value is non-zero
      if (['lp', 'c', 'pc', 'o', 'h', 'l'].contains(field)) {
        final numValue = double.tryParse(value.toString()) ?? 0.0;
        if (numValue <= 0.0) continue;
      }

      // Only update if value is different from current
      if (data[field] != value) {
        data[field] = value;
        hasUpdates = true;
        
        // Cache LTP value for future use during refresh
        if (field == 'lp') {
          _ltpCache[key] = value.toString();
        }
      }
    }

    // Only calculate change if we have updates that would affect it
    // and both lp and close price are available
    if (hasUpdates && data["lp"] != null && data["c"] != null) {
      final lp = double.tryParse(data["lp"].toString()) ?? 0.00;
      final c = double.tryParse(data["c"].toString()) ?? 0.00;

      // Only calculate if both values are valid
      if (lp > 0.0 && c > 0.0) {
        // Calculate the change (price difference)
        final newChng = (lp - c).toStringAsFixed(2);

        // Only update if the change is actually different
        if (data["chng"] != newChng) {
          data["chng"] = newChng;

          // CRITICAL FIX: Only update pc from response if it's present
          // Otherwise calculate it from change and close price
          // This prevents pc from being set to null when df message doesn't include it
          if (res["pc"] != null) {
            data["pc"] = res["pc"];
          } else {
            // Calculate percentage change: (change / close) * 100
            final newPc = ((lp - c) / c * 100).toStringAsFixed(2);
            data["pc"] = newPc;
          }
          hasUpdates = true;
        }
      }
    }

    // Only notify listeners if we actually had meaningful changes
    if (hasUpdates) {
      // PERFORMANCE FIX: Create NEW Map reference so Riverpod's .select() can detect change
      // When using ref.watch(provider.select((p) => p.socketDatas[token])), Riverpod
      // compares references. Modifying Map in-place keeps same reference, so Riverpod
      // thinks nothing changed. Creating new Map ensures rebuild triggers.
      _socketDatas[key] = Map<String, dynamic>.from(data);

      _socketDataController.add(_socketDatas);

      // CRITICAL: Use post-frame callback to avoid mouse tracker assertion errors
      // ("!_debugDuringDeviceUpdate is not true"). Direct notifyListeners() during
      // frame rendering causes conflicts with Flutter's mouse tracking phase.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _safeNotifyListeners();
      });
      // Schedule a frame so the post-frame callback actually fires even when idle
      WidgetsBinding.instance.scheduleFrame();

      // Minimize portfolio recalculations by checking if this is a price update
      // and only update if we have valid price data
      if ((res.containsKey('lp') || res.containsKey('pc') || res.containsKey('c')) && data["lp"] != null && data["lp"] != "0" && data["lp"] != "0.00") {
        ref.read(portfolioProvider).updateHoldingValues(key, data);
        // Also update position values for ticker header to show live P&L
        ref.read(portfolioProvider).updatePositionValues(key, data);
      }
    }
  }

  void _initializeTokenData(String key, Map<String, dynamic> res) {
    final data = _socketDatas[key];

    // Initialize basic fields
    data["pc"] = res["pc"] ?? "0.00";
    data["ap"] = res["ap"] ?? "0.00";
    data["o"] = res["o"] ?? "0.00";
    data["h"] = res["h"] ?? "0.00";
    data["l"] = res["l"] ?? "0.00";
    data["c"] = res["c"] ?? "0.00";
    data["lp"] = res["lp"] ?? "0.00";
    
    // Cache initial LTP value
    if (res["lp"] != null && res["lp"] != "0.00") {
      _ltpCache[key] = res["lp"].toString();
    }
    
    data["v"] = res["v"] ?? "0.00";
    data["oi"] = res["oi"] ?? "0.00";
    data["toi"] = res["toi"] ?? "0.00";
    data["poi"] = res["poi"] ?? "0.00";

    // Initialize depth data if available
    if (res['t']?.toString().toLowerCase() == "dk") {
      _initializeDepthData(data, res);
    }

    // Calculate change
    data["chng"] =
        ((double.tryParse(data["lp"]?.toString() ?? '0.00') ?? 0.00) - (double.tryParse(data["c"]?.toString() ?? '0.00') ?? 0.00)).toStringAsFixed(2);
  }

  void _initializeDepthData(Map<String, dynamic> data, Map<String, dynamic> res) {
    // Initialize depth fields
    for (int i = 1; i <= 5; i++) {
      data["sp$i"] = res["sp$i"] ?? "0.00";
      data["sq$i"] = res["sq$i"] ?? "0";
      data["bp$i"] = res["bp$i"] ?? "0.00";
      data["bq$i"] = res["bq$i"] ?? "0";
    }

    data["tsq"] = res["tsq"] ?? "0.00";
    data["tbq"] = res["tbq"] ?? "0";
    data["52h"] = res["52h"] ?? "0.0";
    data["52l"] = res["52l"] ?? "0.0";
    data["ft"] = res["ft"] ?? "0.0";
    data["lc"] = res["lc"] ?? "0.0";
    data["uc"] = res["uc"] ?? "0.0";
    data["ltq"] = res["ltq"] ?? "0.0";
    data["ltt"] = res["ltt"] ?? "0.0";
  }

  void _handleSubscription(String channelInput, String task, BuildContext context) {
    // In low bandwidth mode, we filter out less critical subscriptions
    if (_isLowBandwidth && task.toLowerCase() != "u" && channelInput.contains(',')) {
      // If in low bandwidth mode, consider batching or prioritizing subscriptions
      // For example, we might only subscribe to the most important symbols
      final symbols = channelInput.split('#');
      // if (symbols.length > 10) {
      //   // If too many symbols, only subscribe to the first 10 in low bandwidth mode
      //   final prioritySymbols = symbols.take(10).join('#');
      channelInput = symbols.join('#');
      // }
    }

    if (task.toLowerCase() != "u" && task.toLowerCase() != 'ud' && !channelInput.startsWith('|')) {
      _startSubscriptionTimer(channelInput, context);
    }

    connectTouchLine(input: channelInput, task: task, context: context);
  }

  // Track recently sent subscriptions to prevent duplicates
  // Format: "taskType:symbol" (e.g., "t:NSE|1234" or "d:NSE|1234")
  // This allows the same symbol to have both touchline and depth subscriptions
  final Set<String> _sentSubscriptions = {};
  Set<String> get sentSubscriptions => Set.from(_sentSubscriptions);
  Timer? _subscriptionDebounce;
  final Map<String, List<String>> _pendingSubscriptions = {
    't': [],
    'd': [],
  };

  void connectTouchLine({
    required String task,
    required String input,
    required BuildContext context,
  }) {
    if (input.isEmpty) {
      return;
    }

    _context = context;

    // Update SubscriptionManager based on task type
    final subscriptionManager = ref.read(subscriptionManagerProvider);

    log("🔌 WebSocket: connectTouchLine called - task: '$task', input: '$input'");

    // Update context in subscription manager when actively used
    subscriptionManager.updateContext(context);

    if (task.toLowerCase() == "t" || task.toLowerCase() == "d") {
      // Subscribe tasks - add to subscription manager
      subscriptionManager.addSubscription(input);

      // Filter out already sent subscriptions for THIS task type
      // BUT: If socket data is missing for a "subscribed" token, we need to resubscribe
      // This handles the case where socket data was cleared (e.g., _clearScreenCache)
      // but _sentSubscriptions wasn't updated
      final taskKey = task.toLowerCase();
      final symbols = input.split('#').where((s) => s.isNotEmpty).toList();

      // Create task-specific subscription keys (e.g., "t:NSE|1234" or "d:NSE|1234")
      final List<String> newSymbols = [];
      final List<String> skippedSymbols = [];
      final List<String> resubscribedSymbols = [];

      for (final symbol in symbols) {
        final subscriptionKey = "$taskKey:$symbol";

        if (!_sentSubscriptions.contains(subscriptionKey)) {
          // Not in sent subscriptions - definitely needs subscription
          newSymbols.add(symbol);
        } else {
          // Already in sent subscriptions - check if socket data exists
          // Extract token from symbol (format: EXCH|TOKEN)
          final token = symbol.contains('|') ? symbol.split('|')[1] : symbol;
          final hasSocketData = _socketDatas.containsKey(token) || _socketDatas.containsKey(symbol);

          if (!hasSocketData) {
            // Socket data was cleared but subscription tracking wasn't updated
            // Need to resubscribe to get fresh data
            newSymbols.add(symbol);
            resubscribedSymbols.add(symbol);
          } else {
            // Has both subscription tracking and socket data - skip
            skippedSymbols.add(symbol);
          }
        }
      }

      // DEBUG: Log which symbols are being skipped (already subscribed with data)
      if (skippedSymbols.isNotEmpty) {
      }

      // Log resubscribed symbols (socket data was missing)
      if (resubscribedSymbols.isNotEmpty) {
      }

      if (newSymbols.isEmpty) {
        log("WebSocket: ℹ️ All ${symbols.length} symbols already subscribed for task '$taskKey', skipping");
        return;
      }

      final freshCount = newSymbols.length - resubscribedSymbols.length;
      log("WebSocket: ➕ Adding ${newSymbols.length} $taskKey subscriptions ($freshCount new, ${resubscribedSymbols.length} resubscribe, ${skippedSymbols.length} skipped)");
      if (newSymbols.length <= 10) {
        log("  Symbols to subscribe: ${newSymbols.join(', ')}");
      }

      // Add to pending batch
      _pendingSubscriptions[taskKey] = (_pendingSubscriptions[taskKey] ?? [])..addAll(newSymbols);

      // Store context for reconnection attempts
      _context = context;

      // Debounce the subscription to batch multiple rapid calls
      _subscriptionDebounce?.cancel();
      _subscriptionDebounce = Timer(const Duration(milliseconds: 200), () {
        _sendBatchedSubscriptions(taskKey, context);
      });

    } else if (task.toLowerCase() == "u" || task.toLowerCase() == "ud") {
      // Unsubscribe tasks - remove from subscription manager and tracking
      subscriptionManager.removeSubscription(input);
      final symbols = input.split('#').where((s) => s.isNotEmpty).toList();

      // Determine which task type to unsubscribe (touchline by default)
      final taskKey = task.toLowerCase() == "ud" ? "d" : "t";

      // DEBUG: Log before removing

      // Remove task-specific subscription keys
      int removedCount = 0;
      for (final symbol in symbols) {
        final key = "$taskKey:$symbol";
        if (_sentSubscriptions.contains(key)) {
          _sentSubscriptions.remove(key);
          removedCount++;
        }
      }


      log("WebSocket: ➖ Removed ${symbols.length} $taskKey subscriptions for task '$task'");
      if (symbols.length <= 10) {
        log("  Symbols: ${symbols.join(', ')}");
      }

      // Send unsubscribe immediately (no debouncing for unsubscribe)
      _sendToWebSocket(task, input);
    } else {
      // For other tasks (like connection), send immediately
      _sendToWebSocket(task, input);
    }
  }

  void _sendBatchedSubscriptions(String task, BuildContext context) {
    final pending = _pendingSubscriptions[task];
    if (pending == null || pending.isEmpty) return;

    // Store context for reconnection attempts
    _context = context;

    // Remove duplicates and create batch string
    final uniqueSymbols = pending.toSet().toList();
    final batchInput = uniqueSymbols.join('#');

    log("WebSocket: 📦 Batched $task request for ${uniqueSymbols.length} symbols");
    if (uniqueSymbols.length <= 10) {
      log("  Symbols: ${uniqueSymbols.join(', ')}");
    }

    // CRITICAL: Only mark as "sent" and clear pending if WebSocket is actually connected
    // Otherwise, keep in pending for _sendPendingSubscriptionsAfterConnect to handle
    if (_wsConnected && _channel != null) {
      // Track these as sent with task-specific keys (e.g., "t:NSE|1234")
      final subscriptionKeys = uniqueSymbols.map((s) => "$task:$s").toList();
      _sentSubscriptions.addAll(subscriptionKeys);

      log("WebSocket: 📝 Tracked ${subscriptionKeys.length} $task subscriptions");

      // Clear pending for this task ONLY after marking as sent
      _pendingSubscriptions[task] = [];

      // Send to websocket
      if (uniqueSymbols.length <= 5) {
      }
      log('📤 WebSocket: Sending $task request for ${uniqueSymbols.length} symbols');
      _channel?.sink.add(jsonEncode({"t": task, "k": batchInput}));
    } else {
      // WebSocket not ready - keep subscriptions in pending list
      // They will be sent by _sendPendingSubscriptionsAfterConnect when connection succeeds
      log('⏸️  WebSocket: Keeping $task subscriptions in pending until connected');
    }
  }

  void _sendToWebSocket(String task, String input) {
    if (_wsConnected && _channel != null) {
      final symbolCount = input.split('#').where((s) => s.isNotEmpty).length;
      if (symbolCount <= 5) {
      }
      log('📤 WebSocket: Sending $task request for $symbolCount symbols');
      _channel?.sink.add(jsonEncode({"t": task, "k": input}));
    } else {
      // If socket isn't ready yet, schedule a retry
      log('⚠️  WebSocket: Connection not ready, scheduling retry');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_wsConnected && _channel != null) {
          log('🔄 WebSocket: Retrying request after delay');
          _channel?.sink.add(jsonEncode({"t": task, "k": input}));
        } else if (!_connecting && !_reconnecting) {
          // Only attempt reconnection if not already connecting
          log('❌ WebSocket: Still not connected, attempting reconnection');
          if (_context != null && input.isNotEmpty) {
            establishConnection(
              channelInput: input,
              task: task,
              context: _context!,
            );
          }
        } else {
          log('⏸️  WebSocket: Connection already in progress, skipping');
        }
      });
    }
  }

  void _handleConnectionClosed(BuildContext context) {
    log('🔴 WebSocket: Connection closed by server');
    
    // Don't process if already reconnecting or if we're disposing
    if (_reconnecting) {
      log('⏸️  WebSocket: Already reconnecting, ignoring');
      return;
    }
    
    // Track server closures
    final now = DateTime.now();
    if (_lastServerClosure != null && 
        now.difference(_lastServerClosure!) < const Duration(seconds: 5)) {
      // Server closed connection again within 5 seconds - increment counter
      _consecutiveServerClosures++;
    } else {
      // Reset counter if enough time has passed
      _consecutiveServerClosures = 1;
    }
    _lastServerClosure = now;
    
    // Check if server keeps closing - stop reconnecting if too many consecutive closures
    if (_consecutiveServerClosures >= _maxConsecutiveClosures) {
      log('⛔ WebSocket: Too many consecutive server closures, stopping reconnection');
      
      // Reset after cooldown period
      Future.delayed(_serverClosureCooldown, () {
        _consecutiveServerClosures = 0;
      });
      
      // Only close if not already closed
      if (_wsConnected || _channel != null) {
        closeSocket(true);
      }
      return;
    }
    
    // Check if we're in cooldown period
    if (_lastServerClosure != null && 
        now.difference(_lastServerClosure!) < _serverClosureCooldown &&
        _consecutiveServerClosures > 1) {
      log('⏸️  WebSocket: In cooldown period, skipping reconnection');
      
      // Only close if not already closed
      if (_wsConnected || _channel != null) {
        closeSocket(true);
      }
      return;
    }
    
    // Check if there are active subscriptions before reconnecting
    // On web, skip this check because after page refresh, subscriptions haven't been added yet
    // but screens will subscribe once they mount - we just need to ensure socket is connected
    try {
      final subscriptionManager = ref.read(subscriptionManagerProvider);
      if (!subscriptionManager.hasActiveSubscriptions) {
        // On web, check if user is logged in - if so, still reconnect
        // because screens will add subscriptions after they mount
        if (kIsWeb) {
          final isLoggedIn = _isUserLoggedIn();
          if (isLoggedIn) {
            log('ℹ️  WebSocket: Web - No subscriptions but user logged in, reconnecting');
          } else {
            log('ℹ️  WebSocket: Web - No subscriptions, user not logged in, skipping');
            if (_wsConnected || _channel != null) {
              closeSocket(true);
            }
            return;
          }
        } else {
          // Mobile: keep existing behavior
          log('ℹ️  WebSocket: No active subscriptions, skipping reconnection');

          // Only close if not already closed
          if (_wsConnected || _channel != null) {
            closeSocket(true);
          }
          return;
        }
      }
    } catch (e) {
      // Subscription manager might not be available, continue with reconnection
      log('⚠️  WebSocket: Could not check subscriptions: $e');
    }
    
    if (!_reconnecting) {
      _connectionCount++;
      log('📊 WebSocket: Connection count: $_connectionCount');

      // Use post-frame callback to avoid modifying provider during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _safeNotifyListeners(); // Notify to update UI with new connection count
      });
      // Schedule a frame so the post-frame callback fires even when idle
      WidgetsBinding.instance.scheduleFrame();
    }

    // Only close if not already closed
    if (_wsConnected || _channel != null) {
      closeSocket(true);
    }

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter?.completeError("WebSocket connection closed.");
    }

    if (_connectionCount < _maxReconnectAttempts) {
      // Use longer delay if server has closed multiple times
      final delaySeconds = _consecutiveServerClosures > 1 ? 5 : 2;
      log('🔄 WebSocket: Scheduling reconnection in $delaySeconds seconds');

      Future.delayed(Duration(seconds: delaySeconds), () {
        // **FIX: Check if provider is disposed before reconnecting from Future.delayed**
        if (_isDisposed) {
          log('WebSocket: Skipping reconnect from _handleConnectionClosed - provider is disposed');
          return;
        }

        if (!_wsConnected && !_reconnecting) {
          // Use passed context if mounted, otherwise fall back to stored _context
          // This handles page refresh scenario where original context is no longer valid
          BuildContext? validContext;
          try {
            if (context.mounted) {
              validContext = context;
            }
          } catch (e) {
            // Context may throw if widget is disposed
          }

          // Fall back to stored context if passed context is not valid
          if (validContext == null && _context != null) {
            try {
              if (_context!.mounted) {
                validContext = _context;
              }
            } catch (e) {
              // Stored context may also be invalid
            }
          }

          if (validContext != null) {
            reconnect(validContext);
          } else {
            log('⚠️  WebSocket: No valid context for reconnection');
          }
        }
      });
    } else {
      log('❌ WebSocket: Max reconnection attempts reached');
    }
  }

  void _handleConnectionError(dynamic error, BuildContext context) {
    log('❌ WebSocket: Connection error: $error');
    
    if (!_reconnecting) {
      _connectionCount++;
      log('📊 WebSocket: Connection count: $_connectionCount');

      // Use post-frame callback to avoid modifying provider during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _safeNotifyListeners(); // Notify to update UI with new connection count
      });
      // Schedule a frame so the post-frame callback fires even when idle
      WidgetsBinding.instance.scheduleFrame();
    }

    closeSocket(true);

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter?.completeError(error);
    }

    if (_connectionCount < _maxReconnectAttempts) {
      log('🔄 WebSocket: Scheduling reconnection after error');
      // Use post-frame callback to avoid provider modification during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Use passed context if mounted, otherwise fall back to stored _context
        BuildContext? validContext;
        try {
          if (context.mounted) {
            validContext = context;
          }
        } catch (e) {
          // Context may throw if widget is disposed
        }

        // Fall back to stored context if passed context is not valid
        if (validContext == null && _context != null) {
          try {
            if (_context!.mounted) {
              validContext = _context;
            }
          } catch (e) {
            // Stored context may also be invalid
          }
        }

        if (validContext != null) {
          reconnect(validContext);
        } else {
          log('⚠️  WebSocket: No valid context for reconnection after error');
        }
      });
    } else {
      log('❌ WebSocket: Max reconnection attempts reached');
    }
  }

  void reconnect(BuildContext context) {
    // **FIX: Check if provider is disposed before reconnecting**
    if (_isDisposed) {
      log('WebSocket: Skipping reconnect - provider is disposed');
      return;
    }

    // Prevent multiple simultaneous reconnection attempts
    if (_reconnecting) {
      log('⏸️  WebSocket: Reconnection already in progress');
      return;
    }

    // If already connected, don't reconnect
    if (_wsConnected && _channel != null) {
      log('✅ WebSocket: Already connected, skipping reconnection');
      return;
    }
    
    // Get stack trace to see who is calling reconnect
    final stackTrace = StackTrace.current;
    final caller = stackTrace.toString().split('\n').take(3).join('\n');
    
    log('🔄 WebSocket: Initiating reconnection (attempt $_connectionCount)');
    log('   Caller: $caller');
    
    _reconnecting = true;

    // Cancel any existing backoff timer
    _reconnectBackoff?.cancel();

    // Use exponential backoff based on connection count
    // With longer delays for low bandwidth conditions
    final multiplier = _isLowBandwidth ? 2 : 1;
    final backoffDelay = Duration(seconds: _reconnectDelay.inSeconds * (_connectionCount + 1) * multiplier);

    // If retry screen is active, attempt immediate reconnection
    if (_retryScreen) {
      log('⚡ WebSocket: Immediate reconnection (retry screen)');
      _attemptReconnection(context);
    } else {
      // Check if we're connected to a network before scheduling reconnection
      ConnectivityResult connectionStatus;
      try {
        connectionStatus = ref.read(networkStateProvider).connectionStatus;
      } catch (e) {
        log('WebSocket: Error reading networkStateProvider in reconnect: $e');
        _reconnecting = false;
        return;
      }

      if (connectionStatus != ConnectivityResult.none) {
        log('⏱️  WebSocket: Scheduling reconnection in ${backoffDelay.inSeconds}s');
        _reconnectBackoff = Timer(backoffDelay, () {
          // **FIX: Check disposed before timer callback executes**
          if (_isDisposed) {
            log('WebSocket: Skipping reconnection timer callback - provider is disposed');
            return;
          }
          log('⏰ WebSocket: Backoff delay completed');
          _attemptReconnection(context);
        });
      } else {
        log('📵 WebSocket: No network, aborting reconnection');
        // Reset reconnecting flag if no network is available
        _reconnecting = false;
        // Use post-frame callback to avoid modifying provider during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _safeNotifyListeners();
        });
        // Schedule a frame so the post-frame callback fires even when idle
        WidgetsBinding.instance.scheduleFrame();
      }
    }
  }

  void _attemptReconnection(BuildContext context) {
    // **FIX: Check if provider is disposed before attempting reconnection**
    // This prevents "provider[_addListener] is not a function" errors
    if (_isDisposed) {
      log('WebSocket: Skipping _attemptReconnection - provider is disposed');
      _reconnecting = false;
      return;
    }

    // Check if already connected before attempting
    if (_wsConnected && _channel != null) {
      log('✅ WebSocket: Already connected, canceling reconnection');
      _reconnecting = false;
      return;
    }

    log('🔄 WebSocket: Attempting reconnection');

    ConnectivityResult connectionStatus;
    try {
      connectionStatus = ref.read(networkStateProvider).connectionStatus;
    } catch (e) {
      log('WebSocket: Error reading networkStateProvider (likely disposed): $e');
      _reconnecting = false;
      return;
    }

    if (connectionStatus != ConnectivityResult.none) {
      log('📶 WebSocket: Network available');
      
      // Reset retry screen flag as we're attempting reconnection
      _retryScreen = false;

      // Make sure we only try to refresh data once per reconnection attempt
      if (!_wsConnected) {
        if (currentRouteName != Routes.loginScreen){
          log('🔄 WebSocket: Refreshing data');
          _refreshData(context);
        }
      }
      

      log('🔌 WebSocket: Establishing base connection');

      // First establish a base connection if needed
      // Only if not already connecting
      if (!_connecting && !_wsConnected) {
        // CRITICAL FIX: Reset _reconnecting before calling establishConnection
        // Otherwise establishConnection sees _reconnecting=true and defers, causing a deadlock:
        //   1. reconnect() sets _reconnecting=true
        //   2. _attemptReconnection() calls establishConnection()
        //   3. establishConnection() sees _reconnecting=true and defers (returns without connecting)
        //   4. _reconnecting never gets reset, socket never connects
        // The _connecting flag already prevents duplicate connection attempts.
        _reconnecting = false;

        establishConnection(
          channelInput: "",
          task: "c",
          context: context,
        );
      } else {
        log('⏸️  WebSocket: Connection already in progress');
      }

      // After connection, subscribe to stored channels if they exist
      // Give a slight delay to ensure connection is established
      Future.delayed(const Duration(milliseconds: 500), () {
        // Check connection status after delay
        if (_wsConnected) {
          log('✅ WebSocket: Reconnection successful');

          // On web, WebSubscriptionManager handles subscription restoration via its listener
          // which is triggered by notifyListeners() in _handleConnectionSuccess
          if (kIsWeb) {
            log('   WebSubscriptionManager handles restoration on web');
          } else {
            // On mobile, restore from saved constants
            log('📡 WebSocket: Restoring subscriptions (mobile)');

            if (ConstantName.lastSubscribe.isNotEmpty) {
              log('   ➕ Restoring tick subscriptions');
              connectTouchLine(
                input: ConstantName.lastSubscribe,
                task: "t",
                context: context,
              );
            }

            if (ConstantName.lastSubscribeDepth.isNotEmpty) {
              log('   ➕ Restoring depth subscriptions');
              connectTouchLine(
                input: ConstantName.lastSubscribeDepth,
                task: "d",
                context: context,
              );
            }
          }
        } else if (_reconnecting) {
          // Connection still in progress or failed
          log('⏳ WebSocket: Connection pending');

          // Don't reset _reconnecting here - let it continue trying
          // The connection handler will set it to false on success/failure
          return;
        }

        // Reset reconnecting flag after attempt, regardless of success
        // The actual connection state is tracked by _wsConnected
        _reconnecting = false;
        log('🔄 WebSocket: Reconnection attempt completed');

        // Use post-frame callback to avoid modifying provider during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _safeNotifyListeners();
        });
        // Schedule a frame so the post-frame callback fires even when idle
        WidgetsBinding.instance.scheduleFrame();
      });
    } else {
      log('📵 WebSocket: No network, aborting reconnection');
      // Reset reconnecting flag if no network is available
      _reconnecting = false;
      // Use post-frame callback to avoid modifying provider during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _safeNotifyListeners();
      });
      // Schedule a frame so the post-frame callback fires even when idle
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  @override
  void dispose() {
    // Set disposed flag FIRST to prevent any pending callbacks from calling notifyListeners
    _isDisposed = true;

    log('🔴 WebSocket: Disposing provider');

    // Ensure all timers are canceled
    _stopPingTimer();
    _holdStartTime?.cancel();
    _reconnectBackoff?.cancel();
    _debounceTimer?.cancel(); // Cancel debounce timer
    _subscriptionDebounce?.cancel(); // Cancel subscription debounce timer
    _throttleTimer?.cancel(); // Cancel throttle timer (330ms)

    // Cancel all subscription timers
    for (var timer in _subscriptionTimers.values) {
      timer.cancel();
    }
    _subscriptionTimers.clear();

    // Cancel stream subscription to prevent memory leaks
    _channelSubscription?.cancel();
    _channelSubscription = null;

    // Close socket channel
    _channel?.sink.close();

    // Close data stream
    _socketDataController.close();

    // Clear subscription tracking
    _sentSubscriptions.clear();
    _pendingSubscriptions.clear();

    // Clear buffered socket updates
    _pendingSocketUpdates.clear();

    log('✅ WebSocket: Provider disposed');

    super.dispose();
  }

  // Method to notify the market watch provider of data updates
  void _notifyMarketWatchProvider() {
    try {
      // If we don't have any data, don't bother updating
      if (_socketDatas.isEmpty) return;

      // FIX: Remove debounce for critical LTP updates to ensure real-time prices
      // Directly send the updates to market watch provider
      try {
        // Safely check if the market watch provider is still available
        final marketWatchProv = ref.read(marketWatchProvider);

        // Check if the provider is already disposed
        if (marketWatchProv.disposed) {
          return;
        }

        // Send a copy of the data to prevent modification issues
        final dataCopy = Map<String, dynamic>.from(_socketDatas);
        marketWatchProv.updateSocketData(dataCopy);
      } catch (e) {
        // Silent catch - this can happen during app shutdown or page transitions
        // We don't want to crash the app if the provider is being disposed
      }
    } catch (e) {
    }
  }
}
