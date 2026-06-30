import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/main.dart' show rootNavigatorKey;
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

/// Lifecycle states of the WebSocket connection.
///
/// Owned by [WebSocketProvider]. The legacy boolean flags
/// (`_wsConnected`, `_connecting`, `_reconnecting`) are kept as derived mirrors
/// of this state so existing readers continue to work — but the source of
/// truth is `_state`, mutated only via `_transitionTo()`.
enum SocketState {
  /// Idle — no channel, no pending work. Initial state and post-logout.
  disconnected,

  /// `WebSocketChannel.connect()` has been called; waiting for `ck` reply.
  connecting,

  /// Server replied `ck`; channel is open and probe timer is running.
  connected,

  /// A reconnect is scheduled. Backoff timer is armed.
  backoffWait,

  /// Network is offline (per `connectivity_plus`). No reconnect attempts
  /// until `Connectivity → wifi/mobile` event fires.
  zombie,
}

/// Indian market sessions used to choose how aggressively we probe for
/// liveness. During active equity hours the bar is tight (10s of silence
/// = suspicious); off-hours we probe rarely (60s).
enum MarketSession { equity, mcxRegular, mcxExtended, off }

class WebSocketProvider extends ChangeNotifier {
  final Ref ref;
  WebSocketProvider(this.ref);

  // Constants
  static const int _maxReconnectAttempts = 8; // Hard cap on reconnect attempts
  static const int _subscriptionTimeout = 10; // Subscription ack timeout

  // State management.
  // _wsConnected/_connecting/_reconnecting are derived mirrors of _state,
  // maintained by _transitionTo. Reads stay backward-compatible — writes
  // should always go through _transitionTo, not direct assignment.
  bool _wsConnected = false;
  bool _connecting = false;
  int _connectionCount = 0;
  bool _retryScreen = false;
  BuildContext? _context;
  bool _reconnecting = false;
  bool _reconnectionSuccess = false;

  // When true, UI should NOT show "Connection lost"/"Connected" toasts.
  // Set by WebSubscriptionManager during intentional tab-switch reconnects.
  bool _isTabSwitchReconnect = false;
  bool get isTabSwitchReconnect => _isTabSwitchReconnect;
  void setTabSwitchReconnect(bool value) {
    _isTabSwitchReconnect = value;
  }

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
  
  // Get cached LTP for a token. Used by mobile order_book.
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

  /// Phase-aware safe notify.
  ///
  /// Notifies listeners directly when the scheduler is idle (the common case
  /// for socket-message callbacks). When called from inside a build / layout /
  /// paint / mouse-tracker phase, defers to a post-frame callback AND schedules
  /// a frame so the deferred notify is guaranteed to fire — even on a fully
  /// idle browser tab where Flutter would not otherwise render a frame.
  ///
  /// This replaces the old pattern of wrapping every `_safeNotifyListeners()`
  /// call in `addPostFrameCallback + scheduleFrame`. The connection-success
  /// path used to skip the `scheduleFrame` half, which caused the
  /// "prices only update after I click" production bug — the post-frame
  /// callback would queue indefinitely on a backgrounded tab.
  void _safeNotifyListeners() {
    if (_isDisposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      try {
        notifyListeners();
      } catch (e) {
        log('WebSocket: notifyListeners error (likely disposed): $e');
      }
      return;
    }
    // Mid-build/layout/paint/mouse-tracker — defer to next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) return;
      try {
        notifyListeners();
      } catch (e) {
        log('WebSocket: deferred notifyListeners error: $e');
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  // Buffer for pending socket data updates - key: token, value: pending update data
  final Map<String, Map<String, dynamic>> _pendingSocketUpdates = {};

  // ─────────────────────────────────────────────────────────────────────────
  // SOCKET STATE MACHINE  (replaces scattered _wsConnected / _connecting /
  //                       _reconnecting writes — those flags are now derived
  //                       mirrors maintained by _transitionTo)
  // ─────────────────────────────────────────────────────────────────────────

  SocketState _state = SocketState.disconnected;
  SocketState get state => _state;

  /// Fixed backoff schedule. Replaces the old `2 × (count+1) × multiplier`
  /// formula that inflated to 16+ s after a few failures. Capped at 8 s so
  /// recovery time stays bounded even on sustained bad networks.
  static const List<Duration> _backoffSchedule = [
    Duration(milliseconds: 200),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 8),
    Duration(seconds: 8),
    Duration(seconds: 8),
  ];

  Duration _backoffForAttempt(int attempt) {
    if (attempt < 1) return _backoffSchedule.first;
    if (attempt > _backoffSchedule.length) return _backoffSchedule.last;
    return _backoffSchedule[attempt - 1];
  }

  /// Probe machinery — replaces the broken ping/pong path.
  /// The server doesn't pong, so we probe via a fresh subscribe to a symbol
  /// we already track. The server replies with `dk` (subscription confirmed)
  /// regardless of market hours — that reply is what proves the socket is
  /// alive. See `_pickProbeSymbol` for the symbol-selection rules.
  Timer? _probeTimer;
  Timer? _probeTimeoutTimer;
  DateTime? _lastInboundFrameTime;
  DateTime? _probeSentAt;

  /// Hard-coded fallback for the rare case of a logged-in user with zero
  /// active subscriptions (e.g. they're on a screen that displays no
  /// market data). NIFTY 50 token format per Mynt convention.
  static const String _probeFallbackSymbol = 'NSE|26000';

  /// Single point that mutates `_state`. All callers — connection handlers,
  /// reconnect, close, network listener — go through this. Each transition
  /// also synchronises the legacy boolean flags so existing readers
  /// (`wsConnected`, downstream `if (_connecting)`-style checks inside this
  /// class) keep working without per-site changes.
  ///
  /// Same-state re-entry is allowed for `backoffWait` only: when an attempt
  /// fails (`onError` / `onDone` while we're still in backoffWait), we need
  /// to schedule a fresh backoff cycle by re-running `_onEnterBackoffWait`.
  /// All other states are no-ops on same-state re-entry.
  void _transitionTo(SocketState next) {
    if (_state == next && next != SocketState.backoffWait) return;
    log('🔄 Socket state: $_state → $next');
    _state = next;
    switch (next) {
      case SocketState.disconnected:
        _wsConnected = false;
        _connecting = false;
        _reconnecting = false;
        _onEnterDisconnected();
        break;
      case SocketState.connecting:
        _wsConnected = false;
        _connecting = true;
        _reconnecting = false;
        // _onEnterConnecting work is already inside `establishConnection`;
        // it is the side effect of moving to this state and is invoked
        // explicitly from the caller (no auto-trigger here to avoid
        // recursion through establishConnection's own guards).
        break;
      case SocketState.connected:
        _wsConnected = true;
        _connecting = false;
        _reconnecting = false;
        _onEnterConnected();
        break;
      case SocketState.backoffWait:
        _wsConnected = false;
        _connecting = false;
        _reconnecting = true;
        _onEnterBackoffWait();
        break;
      case SocketState.zombie:
        _wsConnected = false;
        _connecting = false;
        _reconnecting = false;
        _onEnterZombie();
        break;
    }
    _safeNotifyListeners();
  }

  void _onEnterConnected() {
    _connectionCount = 0;
    _retryScreen = false;
    _lastInboundFrameTime = DateTime.now();
    // Probe is a web-specific concern — relies on web_subscription_manager
    // and is the workaround for browser-tab/visibility issues. Mobile uses
    // the OS-driven connectivity_plus signals which are reliable.
    if (kIsWeb) _startProbeTimer();
    // Tab-switch flow used to clear this flag from a 500 ms Future.delayed
    // BEFORE the reconnect actually completed. Move it to the success edge
    // so toast suppression matches reality.
    if (_isTabSwitchReconnect) _isTabSwitchReconnect = false;
  }

  void _onEnterBackoffWait() {
    _stopProbeTimer();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;

    _connectionCount++;
    if (_connectionCount > _maxReconnectAttempts) {
      log('❌ Socket: max reconnect attempts ($_maxReconnectAttempts) reached');
      _retryScreen = true;
      _transitionTo(SocketState.disconnected);
      return;
    }

    final delay = _backoffForAttempt(_connectionCount);
    log('⏱️  Socket: backoff $delay before attempt $_connectionCount');
    _reconnectBackoff?.cancel();
    _reconnectBackoff = Timer(delay, () {
      if (_isDisposed) return;
      // Network gate: if connectivity says we're offline, park in zombie
      // and wait for the connectivity listener to wake us.
      ConnectivityResult connStatus;
      try {
        connStatus = ref.read(networkStateProvider).connectionStatus;
      } catch (_) {
        connStatus = ConnectivityResult.wifi; // assume online on read failure
      }
      if (connStatus == ConnectivityResult.none) {
        _transitionTo(SocketState.zombie);
        return;
      }
      _attemptStateMachineConnect();
    });
  }

  void _onEnterDisconnected() {
    _stopProbeTimer();
    _reconnectBackoff?.cancel();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _onEnterZombie() {
    _stopProbeTimer();
    _reconnectBackoff?.cancel();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  /// Drives the connect attempt from the state machine. Mirrors the path
  /// the old `_attemptReconnection` used, but without the cascading
  /// `Future.delayed(500ms)` and inflating-backoff timer.
  ///
  /// CRITICAL: clear the legacy `_reconnecting` and `_connecting` mirrors
  /// before calling `establishConnection`. Otherwise its early-return guards
  /// see `_reconnecting=true` (set by `backoffWait` entry) and defer into a
  /// `Future.delayed(500ms)` whose closure does nothing for connect frames
  /// (channelInput is empty) — the connect attempt is silently dropped and
  /// no socket ever opens. This was flaw F9 in the design doc.
  void _attemptStateMachineConnect() {
    if (_isDisposed) return;
    if (_state == SocketState.connected) return;
    final ctx = _safeContext();
    if (ctx == null) {
      log('⚠️  Socket: no valid context for connect, aborting');
      return;
    }
    // Clear legacy mirrors. State machine still represents the truth; once
    // establishConnection sets _connecting=true and ck arrives,
    // _handleConnectionSuccess transitions us to connected.
    _reconnecting = false;
    _connecting = false;
    establishConnection(channelInput: '', task: 'c', context: ctx);
  }

  /// Public: external trigger for "the connection looks suspect, force a
  /// fresh attempt" (used by `WebSubscriptionManager` on tab return / user
  /// retry / network restore).
  void markZombie() {
    if (_state == SocketState.zombie) return;
    _transitionTo(SocketState.zombie);
  }

  /// Public: pause the probe timer. Used when the browser tab is hidden —
  /// browser throttles timers to ~1/min on background tabs, so the probe
  /// would either fire spuriously or get throttled into uselessness. We
  /// just stop it; the tab-visible handler triggers a fresh state cycle.
  void pauseProbe() => _stopProbeTimer();

  /// Public: restart probing if we are still in `connected` state.
  void resumeProbe() {
    if (_state == SocketState.connected) _startProbeTimer();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROBE & MARKET-HOURS HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  void _startProbeTimer() {
    _stopProbeTimer();
    // Tick every 5 s and check whether we have crossed the market-aware
    // probe threshold. Cheaper than scheduling-on-message since we'd have
    // to constantly cancel/recreate timers under heavy market data.
    _probeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_state != SocketState.connected) {
        _stopProbeTimer();
        return;
      }
      if (_lastInboundFrameTime == null) return;
      if (_probeSentAt != null) return; // already waiting for a probe reply
      final idle = DateTime.now().difference(_lastInboundFrameTime!);
      if (idle >= _probeThreshold()) _sendProbe();
    });
  }

  void _stopProbeTimer() {
    _probeTimer?.cancel();
    _probeTimer = null;
    _probeTimeoutTimer?.cancel();
    _probeTimeoutTimer = null;
    _probeSentAt = null;
  }

  String? _pickProbeSymbol() {
    // Prefer a symbol the user is already subscribed to — re-subscribing is
    // free (server replies `dk` either way) and doesn't create unwanted
    // server-side state.
    try {
      final manager = ref.read(webSubscriptionManagerProvider);
      if (manager.activeSubscriptions.isNotEmpty) {
        return manager.activeSubscriptions.first;
      }
    } catch (_) {}
    // Fallback: NIFTY 50. Only fires when the user has no active
    // subscriptions, which is rare (most screens subscribe on mount).
    return _probeFallbackSymbol;
  }

  void _sendProbe() {
    if (_state != SocketState.connected || _channel == null) return;
    final symbol = _pickProbeSymbol();
    if (symbol == null) return;
    log('🟡 Socket probe: re-subscribing $symbol to verify liveness');
    try {
      _channel!.sink.add(jsonEncode({"t": "d", "k": symbol}));
      _probeSentAt = DateTime.now();
      _probeTimeoutTimer = Timer(const Duration(seconds: 5), _onProbeTimeout);
    } catch (e) {
      log('🔴 Socket probe send failed: $e');
      _transitionTo(SocketState.backoffWait);
    }
  }

  void _onProbeTimeout() {
    if (_state != SocketState.connected) return;
    log('🔴 Socket probe timed out (>5s no reply) — connection appears dead');
    _probeSentAt = null;
    _transitionTo(SocketState.backoffWait);
  }

  /// Indian market session lookup. Hardcoded because this app is India-only.
  ///   Equity (NSE/BSE):     09:00 – 15:45 IST  weekdays
  ///   MCX evening session:  09:00 – 23:30 IST  (or 23:50 during US DST)
  MarketSession _currentSession() {
    final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final isWeekday = ist.weekday >= DateTime.monday && ist.weekday <= DateTime.friday;
    if (!isWeekday) return MarketSession.off;

    final mins = ist.hour * 60 + ist.minute;
    const equityStart = 9 * 60;
    const equityEnd = 15 * 60 + 45;
    final mcxEnd = _isUsDstActive(ist) ? (23 * 60 + 50) : (23 * 60 + 30);

    if (mins >= equityStart && mins < equityEnd) return MarketSession.equity;
    if (mins >= equityEnd && mins < mcxEnd) return MarketSession.mcxExtended;
    if (mins >= equityStart && mins < mcxEnd) return MarketSession.mcxRegular;
    return MarketSession.off;
  }

  /// US DST window: 2nd Sunday of March → 1st Sunday of November.
  /// Mynt commodity evening session shifts by 20 min based on this.
  bool _isUsDstActive(DateTime ist) {
    DateTime nthSunday(int year, int month, int n) {
      var d = DateTime(year, month, 1);
      while (d.weekday != DateTime.sunday) {
        d = d.add(const Duration(days: 1));
      }
      return d.add(Duration(days: 7 * (n - 1)));
    }
    final start = nthSunday(ist.year, 3, 2);
    final end = nthSunday(ist.year, 11, 1);
    return ist.isAfter(start) && ist.isBefore(end);
  }

  Duration _probeThreshold() {
    switch (_currentSession()) {
      case MarketSession.equity:
        return const Duration(seconds: 10);
      case MarketSession.mcxRegular:
      case MarketSession.mcxExtended:
        return const Duration(seconds: 30);
      case MarketSession.off:
        return const Duration(seconds: 60);
    }
  }

  /// Returns a usable BuildContext for snackbar / navigation calls. Falls
  /// back to the global `rootNavigatorKey` from main.dart when the cached
  /// `_context` has been disposed (e.g. screen unmounted while reconnect
  /// was in flight). Replaces the old "log and silently abort" failure
  /// mode in `_handleConnectionClosed`.
  BuildContext? _safeContext() {
    try {
      if (_context?.mounted == true) return _context;
    } catch (_) {}
    return rootNavigatorKey.currentContext;
  }

  /// Defensive sanitiser called from `_updateSocketData` and
  /// `_initializeTokenData`. The broker emits "0" / "0.00" defaults for
  /// price fields when it doesn't have real data (illiquid contracts,
  /// market-warmup window after reconnect). Letting these through writes
  /// `position.lp = 0` downstream and produces phantom P&L.
  ///
  /// We set the field to `null` (NOT remove the key) so consumers using
  /// `data.containsKey('lp')` continue to behave the same — they just
  /// see `null` as "no real value yet".
  static const _priceFields = ['lp', 'c', 'pc', 'o', 'h', 'l'];
  void _sanitizePriceFields(Map<String, dynamic> data) {
    for (final field in _priceFields) {
      final raw = data[field];
      if (raw == null) continue;
      final str = raw.toString();
      if (str.isEmpty || str == 'null' ||
          str == '0' || str == '0.0' || str == '0.00') {
        data[field] = null;
      }
    }
  }

  // ────── End of state machine / probe / sanitiser additions ──────

  void changeretryscreen(bool value) {
    _retryScreen = value;
    _safeNotifyListeners();
  }

  void changeconnectioncount() {
    _connectionCount = 0;
    _safeNotifyListeners();
  }

  /// Force-reset all connection state for a fresh session (e.g. after login).
  /// Used by auth_provider to make sure no stale state survives across logins.
  /// Bypasses the closeSocket guard that would normally prevent close during
  /// an in-progress connection attempt.
  void resetForNewSession() {
    log('🔄 WebSocket: resetForNewSession called');

    // Cancel subscription timers (state machine handles probe / backoff /
    // channel teardown via the disconnected entry handler).
    _subscriptionDebounce?.cancel();
    _subscriptionDebounce = null;
    for (var timer in _subscriptionTimers.values) {
      timer.cancel();
    }
    _subscriptionTimers.clear();

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError('Session reset');
    }

    _connectionCount = 0;
    _retryScreen = false;
    _isTabSwitchReconnect = false;
    _lastInboundFrameTime = null;

    // Clear subscriptions and data.
    _sentSubscriptions.clear();
    _pendingSubscriptions['t'] = [];
    _pendingSubscriptions['d'] = [];
    _socketDatas.clear();
    _ltpCache.clear();

    // Drive a clean teardown via the state machine.
    _transitionTo(SocketState.disconnected);

    log('✅ WebSocket: State reset complete');
  }

  /// Clear the sent-subscriptions tracking so that the next connectTouchLine
  /// call will actually send symbols to the server instead of skipping them.
  /// Call this before re-subscribing after a forced reconnect.
  void clearSentSubscriptions() {
    _sentSubscriptions.clear();
  }

  void closeSocket(bool mounted, {bool force = false, bool preserveData = false}) {
    // Already closed — skip.
    if (_state == SocketState.disconnected && _channel == null && !_connecting) {
      log('ℹ️  WebSocket: Already closed, skipping');
      return;
    }

    // Don't close mid-connect unless forced (logout / session reset).
    // _connecting is the source of truth here — it's set by establishConnection
    // and covers both the initial-connect path (state stays disconnected) and
    // the state-machine driven path (state is backoffWait when establishConn
    // is called from _attemptStateMachineConnect, which clears _connecting=false
    // momentarily then establishConnection sets it true again).
    if (_connecting && !force) {
      log('⚠️  WebSocket: Preventing close during connection establishment');
      return;
    }

    final caller = StackTrace.current.toString().split('\n').skip(1).take(2).join(' | ');
    log('🔴 WebSocket: Closing connection (mounted: $mounted) caller: $caller');

    wsmount = mounted;

    // Cancel outstanding connection completer.
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError("WebSocket connection closed intentionally");
    }

    // Cancel subscription timers (separate from probe / backoff which the
    // state machine entry handler will cancel).
    for (var timer in _subscriptionTimers.values) {
      timer.cancel();
    }
    _subscriptionTimers.clear();
    _subscriptionDebounce?.cancel();
    _subscriptionDebounce = null;

    // Clear subscription tracking so the next connect re-sends everything.
    _sentSubscriptions.clear();
    _pendingSubscriptions['t'] = [];
    _pendingSubscriptions['d'] = [];

    if (preserveData) {
      // Tab-switch / reconnect-soon: keep socket data and LTP cache so UI
      // doesn't flash 0.00. New ticks will overwrite when they arrive.
      log('Preserved socket data and LTP cache');
    } else {
      // Full close (logout / re-login): clear everything for fresh state.
      _socketDatas.clear();
      _ltpCache.clear();
      log('Cleared socket data and LTP cache');
    }

    // Transition handles channel close, subscription cancel, probe stop,
    // backoff cancel, and notify.
    _transitionTo(SocketState.disconnected);

    log('✅ WebSocket: Connection closed successfully');
  }

  /// Legacy "set connection state" API. Today every caller passes `false`
  /// (auth_provider on logout × 3, network_state_provider on loss × 1).
  /// Routes through the state machine so the legacy flags stay in sync.
  void websockConn(bool value) {
    if (value) {
      // No production callers pass true today, but preserve semantic.
      _transitionTo(SocketState.connected);
    } else {
      _transitionTo(SocketState.disconnected);
    }
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
        await _connectionCompleter?.future
            .timeout(const Duration(seconds: 10), onTimeout: () {
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

    // Reconnect already in progress (state machine is in backoffWait).
    // For subscribe requests (channelInput non-empty), defer to
    // _handleSubscription which queues into _pendingSubscriptions — those
    // get drained by _sendPendingSubscriptionsAfterConnect when the
    // state machine reaches connected. For pure connect requests
    // (channelInput empty), the state machine will drive the connect itself.
    if (_reconnecting) {
      log('⏸️  WebSocket: Reconnection in progress, deferring');
      if (channelInput.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_isDisposed) return;
          // Always queue — _handleSubscription handles both connected
          // (sends immediately) and not-connected (queues into pending).
          _handleSubscription(channelInput, task, context);
        });
      }
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
      // Fixed connect timeout — bandwidth-aware doubling removed with the
      // _isLowBandwidth flag (driven by the broken ping path).
      final connectTimeout = const Duration(seconds: 10);

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
      // Drop stale messages from a closed channel. Stream subscription
      // cancellation is async — a buffered frame can arrive between
      // `_channelSubscription.cancel()` and the actual cancellation
      // taking effect. Without this guard, a stray `ck` reply after an
      // intentional close would falsely transition us to `connected`
      // even though `_channel` is already null.
      if (_isDisposed || _channel == null) return;

      // Stamp inbound time so the probe timer can detect "no traffic in N
      // seconds" and any in-flight probe gets cancelled (its reply arrived).
      _lastInboundFrameTime = DateTime.now();
      if (_probeSentAt != null) {
        _probeTimeoutTimer?.cancel();
        _probeTimeoutTimer = null;
        _probeSentAt = null;
      }

      final res = jsonDecode(event.toString());

      if (res['s']?.toString().toLowerCase() == "ok" && res['t']?.toString() == "ck") {
        log("🟢 WebSocket: ✅ Connected successfully");
        _handleConnectionSuccess();
      } else if (res['t']?.toString().toLowerCase() == "tf" || res['t']?.toString().toLowerCase() == "df") {
        _handleMarketData(res);
      } else if (res['t']?.toString().toLowerCase() == "tk" || res['t']?.toString().toLowerCase() == "dk") {
        _handleTokenData(res);
      } else if (res['t']?.toString().toLowerCase() == "om" && _context != null) {
        _handleOrderMessage(res);
      } else if (res['t']?.toString().toLowerCase() == "am" && _context != null) {
        _handleAlertMessage(res);
      }
      // Note: server doesn't send "h" heartbeat replies — handler removed.

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
    final throttleDuration =  const Duration(milliseconds: 300) ;
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

        // Phase-aware notify (handles both idle and mid-build cases internally).
        _safeNotifyListeners();
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

        // Update portfolio if we have valid price data. _initializeTokenData
        // now sanitises lp (sets to null if "0"/"0.00"), so a simple null
        // check is enough — no more inline string comparisons.
        if (_socketDatas[token]['lp'] != null) {
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

    // Cancel any pending backoff timer (no longer needed — we connected).
    _reconnectBackoff?.cancel();
    _reconnectBackoff = null;

    // Briefly flag success so UI can show a "connected" toast.
    _reconnectionSuccess = true;
    Future.delayed(const Duration(seconds: 1), () {
      _reconnectionSuccess = false;
      _safeNotifyListeners();
    });

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter?.complete();
    }

    // Single state transition handles: _wsConnected=true, _connecting=false,
    // _reconnecting=false, _retryScreen=false, _connectionCount=0,
    // _lastInboundFrameTime=now, probe timer started, tab-switch flag cleared.
    _transitionTo(SocketState.connected);

    // Send any pending subscriptions that were queued while connecting.
    _sendPendingSubscriptionsAfterConnect();

    log('✅ WebSocket: All connection setup completed');
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
      case 'TRIGGER_PENDING':
        // An SL order rests in TRIGGER_PENDING after BOTH place and modify, and the
        // websocket can't distinguish them (both end with a TriggerPending report).
        // So report the status neutrally, like the vendor, instead of "modified".
        message = '$tranType order for $symbol ($exchange) is Trigger Pending';
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
        // For other statuses, etc.
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

    // Sanitise price fields at ingest. Broker emits "0" / "0.00" defaults
    // for illiquid contracts and during reconnect warm-up. Stripping them
    // here (to null) is the single point of defense against phantom P&L.
    // Replaces the ad-hoc guards in position/portfolio/market_watch.
    _sanitizePriceFields(res);

    // Track if we've made meaningful updates that require UI refresh
    bool hasUpdates = false;

    // CRITICAL FIX: If this is a "dk" (depth key) message, ensure depth data is properly initialized
    // This handles the case where a symbol was first subscribed via touchline ("tk") and later
    // gets a depth subscription ("dk"). The depth-specific fields need to be initialized.
    if (res['t']?.toString().toLowerCase() == "dk") {
      _initializeDepthData(data, res);
      hasUpdates = true;
    }

    // Update only fields that are present in the new data and have changed.
    // Price-zero filtering already handled by _sanitizePriceFields above.
    for (final field in res.keys) {
      final value = res[field];

      // Skip update for null values (sanitiser may have nulled price fields).
      if (value == null) continue;

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

      // _safeNotifyListeners is phase-aware: direct notify when idle,
      // post-frame defer only when called from inside a build/layout phase.
      _safeNotifyListeners();

      // Minimize portfolio recalculations by checking if this is a price
      // update and only update if we have valid price data. _sanitizePriceFields
      // already nulled out "0"/"0.00" defaults — null check is sufficient.
      if ((res.containsKey('lp') || res.containsKey('pc') || res.containsKey('c')) &&
          data["lp"] != null) {
        ref.read(portfolioProvider).updateHoldingValues(key, data);
        // Also update position values for ticker header to show live P&L
        ref.read(portfolioProvider).updatePositionValues(key, data);
      }
    }
  }

  void _initializeTokenData(String key, Map<String, dynamic> res) {
    final data = _socketDatas[key];

    // Sanitise the inbound payload so any "0"/"0.00" defaults become null.
    _sanitizePriceFields(res);

    // Initialize basic fields. ap is intentionally not sanitised (it's an
    // average price, can legitimately be 0 on certain instruments).
    data["pc"] = res["pc"];
    data["ap"] = res["ap"] ?? "0.00";
    data["o"] = res["o"];
    data["h"] = res["h"];
    data["l"] = res["l"];
    data["c"] = res["c"];
    data["lp"] = res["lp"];

    // Cache initial LTP value (only when present after sanitisation).
    if (res["lp"] != null) {
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
    log('🔴 WebSocket: onDone fired');
    if (_isDisposed) return;

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter?.completeError("WebSocket connection closed.");
    }

    // Network is offline — wait for connectivity restore listener.
    if (_state == SocketState.zombie) return;

    // Post-logout / shutdown: state was reset to disconnected by closeSocket
    // and there is nobody to reconnect for. Skip silently.
    if (_state == SocketState.disconnected && !_isUserLoggedIn()) return;

    // Logged in but no subscriptions and no screens means no point reconnecting
    // (preserves the original "no active subs" early-return behavior).
    try {
      final subscriptionManager = ref.read(subscriptionManagerProvider);
      final hasMobileSubs = subscriptionManager.hasActiveSubscriptions;
      final hasWebSubs = kIsWeb
          ? ref.read(webSubscriptionManagerProvider).hasActiveSubscriptions
          : false;
      // On web we still reconnect when logged in even without active subs,
      // because screens about to mount need a live socket. On mobile the
      // legacy behavior was stricter — keep it.
      if (!kIsWeb && !hasMobileSubs && !hasWebSubs) {
        log('ℹ️  Mobile: No active subs, moving to disconnected');
        _transitionTo(SocketState.disconnected);
        return;
      }
    } catch (_) {/* fall through to reconnect attempt */}

    // Transitions:
    //   connected → backoffWait    : real server-side close, retry
    //   disconnected → backoffWait : initial-connect failure (state machine
    //                                hadn't transitioned yet), retry
    //   backoffWait → backoffWait  : failed reconnect attempt — same-state
    //                                re-entry schedules the next backoff cycle
    _transitionTo(SocketState.backoffWait);
  }

  void _handleConnectionError(dynamic error, BuildContext context) {
    log('❌ WebSocket: onError fired: $error');
    if (_isDisposed) return;

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter?.completeError(error);
    }

    // Network is offline — wait for connectivity restore listener.
    if (_state == SocketState.zombie) return;

    // Post-logout / shutdown: nobody to reconnect for.
    if (_state == SocketState.disconnected && !_isUserLoggedIn()) return;

    // All other cases (including disconnected+loggedIn for initial connect
    // failure) → schedule a backoff retry. Same-state re-entry handles the
    // case where we were already in backoffWait when the failure arrived.
    _transitionTo(SocketState.backoffWait);
  }

  /// External reconnect entry-point. Called by:
  ///   - sharedWidget reload buttons (UI)
  ///   - internet_widget recovery
  ///   - network_state_provider on connectivity change
  ///   - web_subscription_manager force-reconnect (tab return)
  ///
  /// Signature unchanged for backward compat with all 6 call sites. The
  /// passed context is cached for snackbar use; if it later goes stale,
  /// reconnect logic falls back to `rootNavigatorKey` via `_safeContext()`.
  void reconnect(BuildContext context) {
    if (_isDisposed) return;
    _context = context;

    // Already in flight or already connected — nothing to do.
    if (_state == SocketState.connecting ||
        _state == SocketState.backoffWait) {
      log('⏸️  Socket: reconnect requested but already attempting');
      return;
    }
    if (_state == SocketState.connected && _channel != null) {
      log('✅ Socket: reconnect requested but already connected');
      return;
    }

    log('🔄 Socket: external reconnect request from ${StackTrace.current.toString().split('\n').take(2).last.trim()}');

    // User-driven retry → reset attempt count so we get the fast initial
    // backoff (200 ms) instead of inheriting a stale 8 s.
    _connectionCount = 0;
    _retryScreen = false;

    // Refresh data on web only if not on login screen — preserves the old
    // _refreshData() side-effect from _attemptReconnection.
    if (currentRouteName != Routes.loginScreen) {
      _refreshData(context);
    }

    // Mobile-only: restore touchline / depth subs from the legacy globals.
    // Web restoration is handled by WebSubscriptionManager's listener which
    // wakes up via the notify in _handleConnectionSuccess.
    if (!kIsWeb) {
      if (ConstantName.lastSubscribe.isNotEmpty) {
        connectTouchLine(
          input: ConstantName.lastSubscribe,
          task: "t",
          context: context,
        );
      }
      if (ConstantName.lastSubscribeDepth.isNotEmpty) {
        connectTouchLine(
          input: ConstantName.lastSubscribeDepth,
          task: "d",
          context: context,
        );
      }
    }

    _transitionTo(SocketState.backoffWait);
  }

  @override
  void dispose() {
    // Set disposed flag FIRST to prevent any pending callbacks from calling notifyListeners
    _isDisposed = true;

    log('🔴 WebSocket: Disposing provider');

    // Ensure all timers are canceled
    _stopProbeTimer();
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
