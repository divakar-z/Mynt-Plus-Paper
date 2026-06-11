import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import '../../../locator/locator.dart';
import '../../../locator/preference.dart';

/// Singleton manager for the web chart iframe.
/// Loads once when app starts, then just shows/hides and changes symbol via postMessage.
class WebChartManager {
  static final WebChartManager _instance = WebChartManager._internal();
  factory WebChartManager() => _instance;
  WebChartManager._internal();

  static const String viewType = 'web-chart-singleton';

  // Default token (NIFTY 50) used when iframe is created without a pending symbol
  static const String _defaultToken = '26000';

  html.IFrameElement? _iframe;
  bool _isRegistered = false;
  String? _currentToken;
  bool _isVisible = false;
  bool _isIframeCreated = false; // Track if iframe has been created and added to DOM
  bool? _currentDarkMode; // Track current dark mode to detect theme changes

  // Track if a user-selected symbol has been successfully loaded via URL
  // This helps detect when postMessage might fail (TradingView not ready)
  bool _hasLoadedUserSymbol = false;

  // Pending symbol to use when iframe is created (if changeSymbol called before iframe ready)
  Map<String, dynamic>? _pendingSymbol;

  // Callback to notify UI when visibility changes
  VoidCallback? onVisibilityChanged;

  bool get isVisible => _isVisible;
  String? get currentToken => _currentToken;

  /// Initialize the iframe (call once when app starts)
  void initialize() {
    if (_isRegistered) return;

    final prefs = locator<Preferences>();

    try {
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          // Check if there's a pending symbol change - use that URL instead of default
          String initialUrl;
          if (_pendingSymbol != null) {
            initialUrl = _buildUrl(
              exch: _pendingSymbol!['exch'],
              token: _pendingSymbol!['token'],
              tsym: _pendingSymbol!['tsym'],
              isDarkMode: _pendingSymbol!['isDarkMode'],
              prefs: prefs,
            );
            _currentToken = _pendingSymbol!['token'];
            _currentDarkMode = _pendingSymbol!['isDarkMode'];
            // Mark that a user-selected symbol was loaded (via URL, not postMessage)
            _hasLoadedUserSymbol = true;
            // NOTE: Don't clear _pendingSymbol - keep it so subsequent iframes
            // also use the correct symbol (multiple HtmlElementView widgets may exist)
          } else {
            // Default to Nifty 50
            initialUrl = _buildUrl(
              exch: 'NSE',
              token: _defaultToken,
              tsym: 'Nifty 50',
              isDarkMode: false,
              prefs: prefs,
            );
            _currentToken = _defaultToken;
            _currentDarkMode = false;
          }

          _iframe = html.IFrameElement()
            ..id = 'web-chart-iframe-$viewId'  // Unique ID per iframe
            ..style.border = 'none'
            ..style.height = '100%'
            ..style.width = '100%'
            ..style.pointerEvents = 'auto'
            ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
            ..src = initialUrl;

          // Mark iframe as created so changeSymbol knows the DOM is ready
          _isIframeCreated = true;

          return _iframe!;
        },
      );
      _isRegistered = true;
    } catch (e) {
    }
  }

  /// Show the chart overlay
  void show() {
    if (!_isVisible) {
      _isVisible = true;
      onVisibilityChanged?.call();
    }
  }

  /// Hide the chart overlay
  void hide() {
    if (_isVisible) {
      _isVisible = false;
      onVisibilityChanged?.call();
    }
  }

  /// Change symbol - uses postMessage for instant updates, URL reload as fallback
  /// IMPORTANT: In production, multiple HtmlElementView widgets may create separate
  /// iframe instances. We must send postMessage to ALL chart iframes, not just one.
  void changeSymbol({
    required String exch,
    required String token,
    required String tsym,
    required bool isDarkMode,
  }) {
    // Skip if same token and same theme (but NOT if we haven't successfully loaded a user symbol yet)
    // This prevents skipping when we failed to load the first symbol due to timing issues
    // Also allow through when dark mode changed (theme toggle)
    if (token == _currentToken && _hasLoadedUserSymbol && isDarkMode == _currentDarkMode) {
      return;
    }

    // Check if we're changing from the default NIFTY 50 token or retrying a failed load
    // In this case, TradingView may not be ready to receive postMessage,
    // so we should use URL reload to ensure the symbol loads correctly
    final isFirstUserSymbol = !_hasLoadedUserSymbol;
    final previousToken = _currentToken;


    // ALWAYS store as pending symbol - this ensures any NEW iframe created
    // (e.g., when panel renders ChartScreenWebViews) will use the correct symbol
    _pendingSymbol = {
      'exch': exch,
      'token': token,
      'tsym': tsym,
      'isDarkMode': isDarkMode,
    };

    // Find ALL chart iframes in the document (not just the stored reference)
    // This fixes production issue where multiple HtmlElementView widgets exist
    final allChartIframes = _findAllChartIframes();

    if (allChartIframes.isEmpty) {
      // Iframe might not be in DOM yet - will use pending symbol when created
      // DON'T update _currentToken here - we haven't actually changed the symbol
      if (!_isIframeCreated) {
      } else {
        // Try to find iframe using stored reference if available
        if (_iframe != null) {
          final prefs = locator<Preferences>();
          final newUrl = _buildUrl(
            exch: exch,
            token: token,
            tsym: tsym,
            isDarkMode: isDarkMode,
            prefs: prefs,
          );
          try {
            _iframe!.src = newUrl;
            _currentToken = token;
            _currentDarkMode = isDarkMode;
            _hasLoadedUserSymbol = true;
          } catch (e) {
          }
        }
      }
      return;
    }

    // For the first user-selected symbol (or retry after failed load),
    // use URL reload instead of postMessage to ensure it loads correctly
    // (TradingView may not be ready to receive postMessage yet)
    if (isFirstUserSymbol) {
      _reloadAllIframesWithUrl(allChartIframes, exch, token, tsym, isDarkMode);
      _currentToken = token;
      _currentDarkMode = isDarkMode;
      _hasLoadedUserSymbol = true;
      return;
    }

    // Update token and theme now that we're about to change it
    _currentToken = token;
    _currentDarkMode = isDarkMode;

    // Use postMessage for subsequent symbol changes (faster, no reload)
    int successCount = 0;
    for (final iframe in allChartIframes) {
      try {
        final contentWindow = iframe.contentWindow;
        if (contentWindow != null) {
          // Send as JSON string - dart:html Map serialization may not work cross-origin
          // The TradingView page needs to JSON.parse this
          final jsonMessage =
              '{"action":"changeScript","exch":"$exch","token":"$token","tsym":"$tsym","dark":"${isDarkMode.toString()}"}';
          contentWindow.postMessage(jsonMessage, '*');
          successCount++;
        }
      } catch (e) {
      }
    }


    // If postMessage failed for all iframes, fallback to URL reload
    if (successCount == 0 && allChartIframes.isNotEmpty) {
      _reloadAllIframesWithUrl(allChartIframes, exch, token, tsym, isDarkMode);
    }
  }

  /// Find all chart iframes in the document
  List<html.IFrameElement> _findAllChartIframes() {
    final iframes = <html.IFrameElement>[];
    try {
      final elements = html.document.querySelectorAll('iframe');
      for (final element in elements) {
        if (element is html.IFrameElement) {
          // Match iframes created by this manager (id starts with 'web-chart-iframe-')
          if (element.id.startsWith('web-chart-iframe-')) {
            iframes.add(element);
          }
        }
      }
    } catch (e) {
    }
    return iframes;
  }

  /// Reload all chart iframes with new URL
  void _reloadAllIframesWithUrl(
    List<html.IFrameElement> iframes,
    String exch,
    String token,
    String tsym,
    bool isDarkMode,
  ) {
    final prefs = locator<Preferences>();
    final newUrl = _buildUrl(
      exch: exch,
      token: token,
      tsym: tsym,
      isDarkMode: isDarkMode,
      prefs: prefs,
    );

    for (final iframe in iframes) {
      try {
        iframe.src = newUrl;
      } catch (e) {
      }
    }
  }

  /// Show chart with a specific symbol
  void showWithSymbol({
    required String exch,
    required String token,
    required String tsym,
    required bool isDarkMode,
  }) {
    changeSymbol(exch: exch, token: token, tsym: tsym, isDarkMode: isDarkMode);
    show();
  }


  String _buildUrl({
    required String exch,
    required String token,
    required String tsym,
    required bool isDarkMode,
    required Preferences prefs,
  }) {
    // Add timestamp for cache-busting to ensure fresh load when symbol changes
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return "https://zebu-feuat.web.app/tv?src=web&symbol=$tsym&user=${prefs.clientId}&usession=${prefs.clientSession}&token=$token&exch=$exch&dark=$isDarkMode&_t=$timestamp";
  }
}

/// Global instance for easy access
final webChartManager = WebChartManager();
