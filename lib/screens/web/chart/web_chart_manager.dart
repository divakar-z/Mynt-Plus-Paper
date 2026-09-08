import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:js_interop';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../locator/locator.dart';
import '../../../locator/preference.dart';
import '../../../provider/websocket_provider.dart';

/// JS interop binding for the shared ScalperCharts bridge
/// (defined in `web/tv/chart_init.js`, loaded once into the parent page).
/// Shared with [ScalperChartManager] — same global, separate containers.
@JS('ScalperCharts')
extension type _ScalperChartsBridge._(JSObject _) implements JSObject {
  external void createChart(String containerId, JSObject options);
  external void changeSymbol(String containerId, String symbol);
  external void setDispName(String symbol, String dispName);
  external void seedSymbolData(String symbol, String exch, String token);
  external bool hasChart(String containerId);
  external void pushTick(String containerId, JSObject tickData);
  external void resetData(String containerId);
  external void removeChart(String containerId);
}

@JS('ScalperCharts')
external _ScalperChartsBridge? get _scalperChartsBridge;

/// Dart callback exposed to `chart_init.js` as the global
/// `window.onChartSymbolChanged`. The bridge calls it when TradingView
/// changes the chart's symbol on its own (e.g. the user loads a saved chart
/// layout for a different scrip) — a path that doesn't go through Dart's
/// [WebChartManager.changeSymbol].
@JS('onChartSymbolChanged')
external set _onChartSymbolChangedHook(JSFunction? f);

/// Singleton manager for the web TradingView chart.
///
/// Architecture (mirrors [ScalperChartManager]):
///   - No iframe. A `<div>` is registered via [ui_web.platformViewRegistry];
///     TradingView renders directly into that div.
///   - `charting_library.js` and `chart_init.js` are loaded as `<script>` tags
///     into the PARENT Flutter page (one-time, shared with the scalper).
///   - Dart talks to JS via `dart:js_interop` extension type — direct method
///     calls, no postMessage.
///   - Ticks come from [WebSocketProvider.socketDataStream] via [bindWebSocket]
///     — chart and watchlist share the same merged stream, so they can't drift.
///
/// Dev-mode note: Flutter's dev server sends `Content-Type: text/plain` for
/// the chart's CSS bundles, which breaks toolbar styling. In dev we serve
/// the `web/` folder via a separate static server:
///     `npx serve web --cors -l 8088`
/// In production [_baseUrl] is empty (real web server sets correct MIME).
/// Same convention as [ScalperChartManager].
class WebChartManager {
  static final WebChartManager _instance = WebChartManager._internal();
  factory WebChartManager() => _instance;
  WebChartManager._internal();

  /// View type used by [HtmlElementView] consumers
  /// ([web_chart_overlay], [inline_chart_portal], etc.).
  static const String viewType = 'web-chart-singleton';

  /// Port for the dev-mode static file server. Must match the scalper's port
  /// so a single `npx serve` covers both.
  static const int _devServerPort = 8088;

  String get _baseUrl => kDebugMode ? 'http://localhost:$_devServerPort' : '';
  String get _libraryPath => '$_baseUrl/tv/charting_library/';

  // ── Registration & loading ────────────────────────────────────────────
  bool _isRegistered = false;
  bool _libraryLoaded = false;
  bool _bridgeLoaded = false;
  bool _symbolHookRegistered = false;
  Completer<void>? _loadingCompleter;

  /// Container `<div>` ID assigned by the platform-view factory.
  /// Format: `web-chart-<viewId>`.
  String? _containerId;

  // ── Public-facing state (preserved API) ───────────────────────────────
  String? _currentSymbol;
  String? _currentExch;
  String? _currentToken;
  /// Decorative chart title for [_currentSymbol] (see [_resolveDispName]).
  String? _currentDispName;
  bool _currentDarkMode = false;
  bool _isVisible = false;

  bool get isVisible => _isVisible;
  String? get currentToken => _currentToken;

  /// Callback fired when visibility changes (preserved API).
  VoidCallback? onVisibilityChanged;

  /// Chart creation queued before container / bridge was ready. Applied via
  /// [_processPendingCreation] once both become available.
  Map<String, dynamic>? _pendingCreation;

  // ── WebSocket stream wiring ───────────────────────────────────────────
  StreamSubscription? _tickStreamSub;

  // ── Public API ────────────────────────────────────────────────────────

  /// Register the div platform-view factory and kick off library load.
  /// Safe to call multiple times — second call is a no-op.
  void initialize() {
    if (!_isRegistered) {
      _registerDivFactory();
      _isRegistered = true;
    }
    // Expose the JS->Dart symbol-change hook so saved-layout symbol switches
    // inside TradingView re-point the live tick stream. Idempotent.
    _registerSymbolChangeHook();
    // Fire-and-forget the script load — it will complete in the background
    // and process any pending chart creation via [_processPendingCreation].
    loadLibrary();
  }

  /// Load `charting_library.js` and `chart_init.js` into the parent page.
  /// Idempotent — second call is a no-op.
  Future<void> loadLibrary() async {
    if (_libraryLoaded && _bridgeLoaded) {
      _processPendingCreation();
      return;
    }
    if (_loadingCompleter != null) return _loadingCompleter!.future;
    _loadingCompleter = Completer<void>();

    try {
      if (!_libraryLoaded) {
        await _loadScript('$_baseUrl/tv/charting_library/charting_library.js');
        _libraryLoaded = true;
      }
      if (!_bridgeLoaded) {
        await _loadScript('$_baseUrl/tv/chart_init.js');
        _bridgeLoaded = true;
      }
      _loadingCompleter!.complete();
      _processPendingCreation();
    } catch (e) {
      _loadingCompleter!.completeError(e);
      _loadingCompleter = null;
      log('WebChartManager: library load failed: $e');
      rethrow;
    }
  }

  /// Bind a [WebSocketProvider] so ticks for the currently-charted scrip
  /// flow into the chart. Call from a Riverpod-aware context (e.g. the
  /// chart overlay's `initState` via `ref.read(websocketProvider)`).
  ///
  /// The stream fires at the throttle boundary with the merged state of
  /// `_socketDatas`. We pull the charted scrip's tick and forward.
  /// Safe to call multiple times — replaces any prior subscription.
  void bindWebSocket(WebSocketProvider wsProvider) {
    _tickStreamSub?.cancel();
    _tickStreamSub = wsProvider.socketDataStream.listen((socketDatas) {
      final token = _currentToken;
      if (token == null) return;
      final tickRaw = socketDatas[token];
      if (tickRaw == null) return;
      final tick = Map<String, dynamic>.from(tickRaw as Map);
      if (tick['lp'] == null) return;
      pushTick({
        'lp': tick['lp'].toString(),
        'v': (tick['v'] ?? '0').toString(),
        'ltt': (tick['ltt'] ?? '').toString(),
        'e': _currentExch ?? '',
        'token': token,
        // Today's running OHLC from the broker — EODChartData does NOT
        // return today's bar (most recent EOD row is the prior trading
        // day). The JS pushTick uses these to build today's daily candle
        // from scratch instead of collapsing into a flat single-tick at LP.
        'o': (tick['o'] ?? '0').toString(),
        'h': (tick['h'] ?? '0').toString(),
        'l': (tick['l'] ?? '0').toString(),
      });
    });
  }

  /// Change (or initially create) the chart's symbol.
  ///
  /// Same signature as the previous manager so existing callers
  /// (market_watch_provider, thems.dart, chart_with_depth_web) work
  /// unchanged. Internally routes to create / change / theme-recreate
  /// based on current state.
  void changeSymbol({
    required String exch,
    required String token,
    required String tsym,
    required bool isDarkMode,
    // Decorative/display name (from DerivativeMaster) used for the chart
    // title. Optional — falls back to [tsym] when null/empty so existing
    // callers keep working unchanged.
    String? decorativeName,
  }) {
    final newSymbol = '$exch:$tsym';
    final dispName =
        _resolveDispName(tsym: tsym, decorativeName: decorativeName);

    final containerId = _containerId;
    if (containerId == null || !_bridgeLoaded) {
      // Queue until container + bridge both ready.
      _currentExch = exch;
      _currentToken = token;
      _currentSymbol = newSymbol;
      _currentDarkMode = isDarkMode;
      _currentDispName = dispName;
      _pendingCreation = {'symbol': newSymbol, 'isDarkMode': isDarkMode};
      return;
    }

    final bridge = _scalperChartsBridge;
    if (bridge == null) {
      // Bridge global isn't installed yet (chart_init.js race) — queue.
      _currentExch = exch;
      _currentToken = token;
      _currentSymbol = newSymbol;
      _currentDarkMode = isDarkMode;
      _currentDispName = dispName;
      _pendingCreation = {'symbol': newSymbol, 'isDarkMode': isDarkMode};
      return;
    }

    final chartExists = bridge.hasChart(containerId);
    final themeChanged = chartExists && _currentDarkMode != isDarkMode;
    final symbolChanged = newSymbol != _currentSymbol;

    _currentExch = exch;
    _currentToken = token;
    _currentSymbol = newSymbol;
    _currentDarkMode = isDarkMode;
    _currentDispName = dispName;

    // Register the title BEFORE any create/change so the bridge's
    // resolveSymbol reads it on the way in — it only runs once per symbol.
    try {
      bridge.setDispName(newSymbol, dispName);
    } catch (e) {
      log('WebChartManager: setDispName error: $e');
    }

    // Seed the authoritative exch + token for the same reason. createChart
    // carries them as initialToken/initialExch, but the changeSymbol path
    // below passes the symbol string alone — leaving the bridge's
    // resolveSymbol to look the token up via be.mynt.in/getSymbolinfo, which
    // returns `{}` for derivatives (NFO/BFO/MCX). That empty result degraded
    // to token:"" in GetSecurityInfo AND TPSeries, so every watchlist switch
    // to an option/future drew a blank chart. Seeding also skips that lookup
    // round-trip entirely for the symbols it *does* resolve.
    try {
      bridge.seedSymbolData(newSymbol, exch, token);
    } catch (e) {
      log('WebChartManager: seedSymbolData error: $e');
    }

    if (!chartExists) {
      _createChartInternal(newSymbol, isDarkMode);
    } else if (themeChanged) {
      // TradingView's style overrides alone aren't enough on theme flip —
      // must destroy and recreate. Same as mobile's _handleThemeChange.
      bridge.removeChart(containerId);
      _createChartInternal(newSymbol, isDarkMode);
    } else if (symbolChanged) {
      bridge.changeSymbol(containerId, newSymbol);
    }
  }

  /// Final display name shown as the chart title. Prefers the decorative name
  /// (from DerivativeMaster) and falls back to [tsym] when it's null/empty.
  /// Any "-EQ" suffix is trimmed so the title reads "SENSEXETF" instead of
  /// "SENSEXETF-EQ". Ported from the pre-migration iframe manager (d3b903c9).
  String _resolveDispName({
    required String tsym,
    String? decorativeName,
  }) {
    var name = (decorativeName == null || decorativeName.isEmpty)
        ? tsym
        : decorativeName;
    name = name.replaceAll('-EQ', '');
    return name.trim();
  }

  /// Push a single tick to the chart. Called from [bindWebSocket]'s stream
  /// listener (or directly by callers if they manage their own stream).
  void pushTick(Map<String, dynamic> tickData) {
    final containerId = _containerId;
    if (containerId == null || !_bridgeLoaded) return;
    final bridge = _scalperChartsBridge;
    if (bridge == null) return;
    try {
      bridge.pushTick(containerId, tickData.jsify() as JSObject);
    } catch (_) {
      // Silently swallow tick errors to avoid flooding logs.
    }
  }

  /// Force the chart to re-fetch bars. Call on tab visibility return.
  void resetData() {
    final containerId = _containerId;
    if (containerId == null || !_bridgeLoaded) return;
    final bridge = _scalperChartsBridge;
    if (bridge == null) return;
    try {
      bridge.resetData(containerId);
    } catch (e) {
      log('WebChartManager: resetData error: $e');
    }
  }

  /// Remove the chart widget and release its JS resources.
  void removeChart() {
    final containerId = _containerId;
    if (containerId == null || !_bridgeLoaded) return;
    final bridge = _scalperChartsBridge;
    if (bridge == null) return;
    try {
      bridge.removeChart(containerId);
    } catch (e) {
      log('WebChartManager: removeChart error: $e');
    }
  }

  // ── Visibility (preserved API) ────────────────────────────────────────

  void show() {
    if (!_isVisible) {
      _isVisible = true;
      onVisibilityChanged?.call();
    }
  }

  void hide() {
    if (_isVisible) {
      _isVisible = false;
      onVisibilityChanged?.call();
    }
  }

  void showWithSymbol({
    required String exch,
    required String token,
    required String tsym,
    required bool isDarkMode,
    String? decorativeName,
  }) {
    changeSymbol(
      exch: exch,
      token: token,
      tsym: tsym,
      isDarkMode: isDarkMode,
      decorativeName: decorativeName,
    );
    show();
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /// Install [_handleChartSymbolChanged] as the global JS callback the chart
  /// bridge invokes on an in-chart symbol switch. Runs once.
  void _registerSymbolChangeHook() {
    if (_symbolHookRegistered) return;
    _symbolHookRegistered = true;
    try {
      _onChartSymbolChangedHook = ((JSString payload) {
        _handleChartSymbolChanged(payload.toDart);
      }).toJS;
    } catch (e) {
      _symbolHookRegistered = false;
      log('WebChartManager: failed to register symbol-change hook: $e');
    }
  }

  /// Called from `chart_init.js` (web) when TradingView changes the symbol
  /// outside Dart's control — currently only a saved-layout load (TV's header
  /// search box is disabled on web). Re-points the shared-socket tick filter
  /// ([_currentToken]/[_currentExch]/[_currentSymbol]) so live price follows
  /// the displayed scrip. The echo of a Dart-initiated change is ignored
  /// (symbol already current).
  void _handleChartSymbolChanged(String payloadJson) {
    try {
      final map = jsonDecode(payloadJson) as Map<String, dynamic>;
      final symbol = (map['symbol'] as String?)?.trim() ?? '';
      final exch = (map['exch'] as String?)?.trim() ?? '';
      final token = (map['token'] as String?)?.trim() ?? '';

      // Echo of a change we initiated via changeSymbol() — already applied.
      if (symbol.isEmpty || symbol == _currentSymbol) return;
      // No token means we can't filter the socket stream; skip rather than
      // forward the previous scrip's ticks under the new symbol.
      if (token.isEmpty) {
        log('WebChartManager: external symbol change to $symbol has no token; '
            'live price will not follow until the scrip is re-selected.');
        return;
      }

      _currentSymbol = symbol;
      if (exch.isNotEmpty) _currentExch = exch;
      _currentToken = token;
      log('WebChartManager: external symbol change -> $symbol (token $token)');
    } catch (e) {
      log('WebChartManager: onChartSymbolChanged parse error: $e');
    }
  }

  void _registerDivFactory() {
    try {
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          final containerId = 'web-chart-$viewId';
          final div = html.DivElement()
            ..id = containerId
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.overflow = 'hidden';
          _containerId = containerId;

          // After Flutter mounts the new div, handle two cases:
          //   1. Pending creation queued before container / bridge was ready.
          //   2. Remount (hot reload, navigation away+back, theme change) —
          //      singleton state survives but the old container is gone;
          //      recreate the chart on the new div using the last symbol.
          // Same pattern as ScalperChartManager.
          Future.delayed(const Duration(milliseconds: 200), () {
            if (_pendingCreation != null) {
              _processPendingCreation();
            } else if (_bridgeLoaded && _currentSymbol != null) {
              _createChartInternal(_currentSymbol!, _currentDarkMode);
            }
          });

          return div;
        },
      );
      log('WebChartManager: platform view factory registered');
    } catch (e) {
      log('WebChartManager: initialize error: $e');
    }
  }

  Future<void> _loadScript(String src) {
    final existing = html.document.querySelector('script[src="$src"]');
    if (existing != null) return Future.value();

    final completer = Completer<void>();
    final script = html.ScriptElement()
      ..src = src
      ..type = 'text/javascript';
    script.onLoad.listen((_) => completer.complete());
    script.onError.listen((_) => completer.completeError('Failed to load: $src'));
    html.document.head!.append(script);
    return completer.future;
  }

  void _createChartInternal(String symbol, bool isDarkMode) {
    final containerId = _containerId;
    if (containerId == null || !_bridgeLoaded) return;
    final bridge = _scalperChartsBridge;
    if (bridge == null) return;

    final prefs = locator<Preferences>();

    try {
      bridge.createChart(
        containerId,
        <String, dynamic>{
          'symbol': symbol,
          'user': prefs.clientId ?? '',
          'usession': prefs.clientSession ?? '',
          'dark': isDarkMode,
          'resolution': '5',
          'libraryPath': _libraryPath,
          'minimal': false,
          if (_currentToken != null) 'initialToken': _currentToken,
          if (_currentExch != null) 'initialExch': _currentExch,
          if (_currentDispName != null) 'dispname': _currentDispName,
        }.jsify() as JSObject,
      );
    } catch (e) {
      log('WebChartManager: createChart error: $e');
    }
  }

  void _processPendingCreation() {
    if (_pendingCreation == null) return;
    if (_containerId == null || !_bridgeLoaded) return;

    final pending = _pendingCreation!;
    _pendingCreation = null;
    _createChartInternal(
      pending['symbol'] as String,
      pending['isDarkMode'] as bool,
    );
  }
}

/// Global instance for easy access. Preserved from old manager.
final webChartManager = WebChartManager();
