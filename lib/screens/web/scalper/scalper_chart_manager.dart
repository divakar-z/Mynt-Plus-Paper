import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import '../../../locator/locator.dart';
import '../../../locator/preference.dart';

/// JS interop binding for the ScalperCharts bridge (window.ScalperCharts)
@JS('ScalperCharts')
extension type _ScalperChartsBridge._(JSObject _) implements JSObject {
  external void createChart(String containerId, JSObject options);
  external void changeSymbol(String containerId, String symbol);
  external bool hasChart(String containerId);
  external void pushTick(String containerId, JSObject tickData);
  external void resetData(String containerId);
  external void removeChart(String containerId);
}

@JS('ScalperCharts')
external _ScalperChartsBridge? get _scalperChartsBridge;

/// Chart manager for the Scalper Screen using direct TradingView JS interop.
///
/// Instead of iframes, this creates div elements and initializes TradingView
/// widgets directly via JavaScript interop. This is the standard way to
/// integrate TradingView Charting Library in web apps.
///
/// Supports 3 charts: Index (center), Call option (left), Put option (right)
class ScalperChartManager {
  static final ScalperChartManager _instance = ScalperChartManager._internal();
  factory ScalperChartManager() => _instance;
  ScalperChartManager._internal();

  /// Port for the local static file server used during development.
  /// Start it with: npx serve web --cors -l 8088
  static const int _devServerPort = 8088;

  // View types for HtmlElementView registration
  static const String indexViewType = 'scalper-index-chart';
  static const String callViewType = 'scalper-call-chart';
  static const String putViewType = 'scalper-put-chart';
  static const String viewType = indexViewType;

  // Track registration status
  final Set<String> _registeredViewTypes = {};

  // Track container div IDs created by platform view factories
  final Map<String, String> _containerIds = {};

  // Current symbols for each chart (to avoid duplicate updates)
  String? _indexSymbol;
  String? _callSymbol;
  String? _putSymbol;

  // Track current theme state for each chart (needed to detect theme changes)
  final Map<String, bool> _chartThemes = {};

  // Pending chart creations (queued before library loads)
  final Map<String, Map<String, dynamic>> _pendingCreations = {};

  // Library loading state
  bool _libraryLoaded = false;
  bool _bridgeLoaded = false;
  Completer<void>? _loadingCompleter;

  /// Base URL for static files - uses separate server in debug mode
  /// because Flutter's dev server can't serve charting_library files correctly.
  String get _baseUrl => kDebugMode ? 'http://localhost:$_devServerPort' : '';

  /// Path to TradingView charting library for the widget's library_path option
  String get _libraryPath => '$_baseUrl/tv/charting_library/';

  /// Load the TradingView charting library and chart bridge scripts.
  /// Must be called before creating any charts.
  Future<void> loadLibrary() async {
    if (_libraryLoaded && _bridgeLoaded) {
      // Library already loaded (e.g. returning to scalper screen).
      // Process any pending chart creations that were queued.
      _createPendingCharts();
      return;
    }

    // Prevent multiple concurrent loads
    if (_loadingCompleter != null) {
      return _loadingCompleter!.future;
    }
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

      // Create any charts that were requested before the library loaded
      _createPendingCharts();
    } catch (e) {
      _loadingCompleter!.completeError(e);
      _loadingCompleter = null;
      rethrow;
    }
  }

  /// Create charts that were requested before the library finished loading
  void _createPendingCharts() {
    for (final entry in _pendingCreations.entries) {
      final chartId = entry.key;
      final data = entry.value;
      if (_containerIds.containsKey(chartId)) {
        createChart(
          chartId: chartId,
          symbol: data['symbol'] as String,
          isDarkMode: data['isDarkMode'] as bool? ?? false,
        );
      }
    }
    _pendingCreations.clear();
  }

  /// Load a JavaScript file dynamically
  Future<void> _loadScript(String src) {
    // Check if already loaded
    final existing = html.document.querySelector('script[src="$src"]');
    if (existing != null) return Future.value();

    final completer = Completer<void>();
    final script = html.ScriptElement()
      ..src = src
      ..type = 'text/javascript';

    script.onLoad.listen((_) => completer.complete());
    script.onError.listen((_) {
      completer.completeError('Failed to load: $src');
    });

    html.document.head!.append(script);
    return completer.future;
  }

  /// Initialize view factories that create div elements for charts.
  /// Call this in initState before rendering HtmlElementView widgets.
  void initialize() {
    _registerDivFactory(indexViewType, 'index');
    _registerDivFactory(callViewType, 'call');
    _registerDivFactory(putViewType, 'put');
  }

  /// Register a platform view factory that creates a div element
  void _registerDivFactory(String viewTypeName, String chartId) {
    if (_registeredViewTypes.contains(viewTypeName)) return;

    try {
      ui_web.platformViewRegistry.registerViewFactory(
        viewTypeName,
        (int viewId) {
          final containerId = 'scalper-$chartId-$viewId';
          final div = html.DivElement()
            ..id = containerId
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.overflow = 'hidden';

          _containerIds[chartId] = containerId;

          // After Flutter adds the div to the DOM, recreate charts.
          // This handles two cases:
          // 1. Pending creation queued before bridge loaded
          // 2. Remount (embedded mode) — symbol still set, need chart on new div
          if (_bridgeLoaded) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (_pendingCreations.containsKey(chartId)) {
                final data = _pendingCreations.remove(chartId)!;
                createChart(
                  chartId: chartId,
                  symbol: data['symbol'] as String,
                  isDarkMode: data['isDarkMode'] as bool? ?? false,
                );
              } else {
                // Remount case: symbol is still set from before, recreate chart
                final existingSymbol = _getCurrentSymbol(chartId);
                if (existingSymbol != null) {
                  createChart(
                    chartId: chartId,
                    symbol: existingSymbol,
                    isDarkMode: false, // Will be overridden by next changeChart call
                  );
                }
              }
            });
          }

          return div;
        },
      );
      _registeredViewTypes.add(viewTypeName);
    } catch (e) {
    }
  }

  /// Create a TradingView chart on the div for the given chart type.
  /// The JS bridge polls for the div to appear in DOM, so this can be
  /// called immediately after the widget renders.
  void createChart({
    required String chartId,
    required String symbol,
    required bool isDarkMode,
  }) {
    final containerId = _containerIds[chartId];
    if (containerId == null) {
      return;
    }

    if (!_bridgeLoaded) {
      return;
    }

    final prefs = locator<Preferences>();

    try {
      final bridge = _scalperChartsBridge;
      if (bridge == null) {
        return;
      }

      bridge.createChart(
        containerId,
        <String, dynamic>{
          'symbol': symbol,
          'user': prefs.clientId,
          'usession': prefs.clientSession,
          'dark': isDarkMode,
          'resolution': '5',
          'libraryPath': _libraryPath,
        }.jsify() as JSObject,
      );

      _setCurrentSymbol(chartId, symbol);
      _chartThemes[chartId] = isDarkMode; // Store the theme state
    } catch (e) {
    }
  }

  /// Change symbol on an existing chart. If chart doesn't exist yet, creates it.
  void _changeChart({
    required String chartId,
    required String symbol,
    required bool isDarkMode,
  }) {
    final containerId = _containerIds[chartId];
    if (containerId == null || !_bridgeLoaded) {
      // Store for later when container/bridge is ready
      _setCurrentSymbol(chartId, symbol);
      _pendingCreations[chartId] = {'symbol': symbol, 'isDarkMode': isDarkMode};
      return;
    }

    try {
      final bridge = _scalperChartsBridge;
      if (bridge == null) return;

      final chartExists = bridge.hasChart(containerId);
      final currentSymbol = _getCurrentSymbol(chartId);
      final currentTheme = _chartThemes[chartId];
      final themeChanged = currentTheme != null && currentTheme != isDarkMode;

      if (!chartExists) {
        // No chart on this container — create it (handles remount with new div)
        createChart(chartId: chartId, symbol: symbol, isDarkMode: isDarkMode);
      } else if (themeChanged) {
        // Theme changed - recreate chart with new theme
        bridge.removeChart(containerId);
        createChart(chartId: chartId, symbol: symbol, isDarkMode: isDarkMode);
      } else if (symbol != currentSymbol) {
        // Only symbol changed - just update symbol
        bridge.changeSymbol(containerId, symbol);
      } else {
        // No changes needed
        return;
      }

      _setCurrentSymbol(chartId, symbol);
    } catch (e) {
    }
  }

  // ── Public API ─────────────────────────────────────────────────────

  /// Push a real-time tick to update a chart's current candle.
  /// Called when WebSocket data arrives for a subscribed symbol.
  /// The JS bridge handles candle bucketing, OHLCV computation, and
  /// calls the TradingView subscribeBars callback automatically.
  void pushTick({
    required String chartId,
    required Map<String, dynamic> tickData,
  }) {
    final containerId = _containerIds[chartId];
    if (containerId == null || !_bridgeLoaded) return;

    try {
      final bridge = _scalperChartsBridge;
      if (bridge == null) return;

      bridge.pushTick(containerId, tickData.jsify() as JSObject);
    } catch (_) {
      // Silently ignore tick errors to avoid flooding logs
    }
  }

  /// Reset chart data — forces TradingView to re-fetch bars from the datafeed.
  /// Use after returning from tab switch / system sleep to fill candle gaps.
  void resetData({required String chartId}) {
    final containerId = _containerIds[chartId];
    if (containerId == null || !_bridgeLoaded) return;

    try {
      final bridge = _scalperChartsBridge;
      if (bridge == null) return;

      bridge.resetData(containerId);
    } catch (e) {
    }
  }

  /// Fully tear down and recreate all 3 charts (index, call, put) using
  /// each chart's currently-selected symbol and theme. Use this for the
  /// manual Refresh button — guarantees a clean datafeed, fresh history,
  /// fresh subscription record, and fresh lastBar.
  ///
  /// Trade-off: discards user's per-chart timeframe / indicators / drawings.
  /// That's acceptable for an explicit refresh; not acceptable for an
  /// automatic tab-return.
  void recreateAllCharts() {
    for (final chartId in const ['index', 'call', 'put']) {
      final containerId = _containerIds[chartId];
      if (containerId == null || !_bridgeLoaded) continue;

      final symbol = _getCurrentSymbol(chartId);
      if (symbol == null) continue;

      final isDark = _chartThemes[chartId] ?? false;

      try {
        final bridge = _scalperChartsBridge;
        if (bridge == null) continue;

        if (bridge.hasChart(containerId)) {
          bridge.removeChart(containerId);
        }
        createChart(chartId: chartId, symbol: symbol, isDarkMode: isDark);
      } catch (_) {
      }
    }
  }

  /// Change index chart symbol
  void changeSymbol({
    required String exch,
    required String token,
    required String tsym,
    required bool isDarkMode,
  }) {
    _changeChart(chartId: 'index', symbol: tsym, isDarkMode: isDarkMode);
  }

  /// Change call option chart symbol
  void changeCallSymbol({
    required String exch,
    required String token,
    required String tsym,
    required bool isDarkMode,
  }) {
    _changeChart(chartId: 'call', symbol: tsym, isDarkMode: isDarkMode);
  }

  /// Change put option chart symbol
  void changePutSymbol({
    required String exch,
    required String token,
    required String tsym,
    required bool isDarkMode,
  }) {
    _changeChart(chartId: 'put', symbol: tsym, isDarkMode: isDarkMode);
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String? _getCurrentSymbol(String chartId) {
    switch (chartId) {
      case 'index':
        return _indexSymbol;
      case 'call':
        return _callSymbol;
      case 'put':
        return _putSymbol;
      default:
        return null;
    }
  }

  void _setCurrentSymbol(String chartId, String symbol) {
    switch (chartId) {
      case 'index':
        _indexSymbol = symbol;
        break;
      case 'call':
        _callSymbol = symbol;
        break;
      case 'put':
        _putSymbol = symbol;
        break;
    }
  }

  /// Reset state when leaving the scalper screen
  void reset() {
    for (final entry in _containerIds.entries) {
      try {
        final bridge = _scalperChartsBridge;
        if (bridge != null) {
          bridge.removeChart(entry.value);
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    }

    _containerIds.clear();
    _pendingCreations.clear();
    _chartThemes.clear(); // Clear theme tracking
    _indexSymbol = null;
    _callSymbol = null;
    _putSymbol = null;
  }
}

/// Global instance for easy access
final scalperChartManager = ScalperChartManager();
