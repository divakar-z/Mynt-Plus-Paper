import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/screens/web/orderflow/state/orderflow_store.dart';
import 'package:mynt_plus/screens/web/orderflow/widgets/orderflow_top_bar.dart';

/// Full-page Orderflow shell rendered inside the right panel of
/// CustomizableSplitHomeScreen.
///
/// The actual footprint chart lives in `web/footprint-chart/index.html` and is
/// embedded here via [HtmlElementView]. The Flutter side only owns the top
/// bar (symbol + timeframe + refresh) and drives the iframe via postMessage.
class OrderflowShellScreen extends ConsumerStatefulWidget {
  final String? initialSymbol;
  const OrderflowShellScreen({super.key, this.initialSymbol});

  @override
  ConsumerState<OrderflowShellScreen> createState() =>
      _OrderflowShellScreenState();
}

class _OrderflowShellScreenState extends ConsumerState<OrderflowShellScreen> {
  // viewType + iframeId must be UNIQUE per state instance. If we re-use a
  // single static viewType the factory closure from the first mount stays
  // pinned to that mount's disposed state (stale _iframeId, stale _store),
  // and the iframe on the second mount loads with broken wiring → blank
  // chart on remount. A fresh viewType per instance gets a fresh factory.
  late final String _viewType;
  late final OrderflowStore _store;
  late final String _iframeId;
  html.IFrameElement? _iframe;
  bool _iframeReady = false;
  // Theme last pushed to the iframe. We refresh on theme changes (which can
  // happen mid-session) by diffing this against the current themeProvider.
  String? _pushedTheme;

  @override
  void initState() {
    super.initState();
    _store = OrderflowStore(symbol: widget.initialSymbol ?? 'NIFTY');
    _store.addListener(_onStoreChanged);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    // The ID intentionally contains "chart-iframe" so existing dropdown menus
    // in the rest of the app (which call _disableAllChartIframes() against
    // any iframe whose id contains "chart-iframe") will also gate this one.
    _iframeId = 'orderflow-chart-iframe-$stamp';
    _viewType = 'orderflow-canvas-iframe-$stamp';
    _registerFactory();
    html.window.addEventListener('message', _onWindowMessage);
  }

  /// Toggle pointer events on our iframe. Called by the top bar before/after
  /// showing the symbol popup so clicks land on the Flutter overlay rather
  /// than getting swallowed by the iframe's DOM element.
  void setIframePointerEvents(bool enabled) {
    final el = html.document.getElementById(_iframeId);
    if (el is html.IFrameElement) {
      el.style.pointerEvents = enabled ? 'auto' : 'none';
    }
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _onWindowMessage);
    _store.removeListener(_onStoreChanged);
    _store.dispose();
    super.dispose();
  }

  void _registerFactory() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final el = html.IFrameElement()
        ..id = _iframeId
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#0B0F14'
        ..allow = 'autoplay'
        ..src = _iframeSrc();
      // !important so any wrapping Flutter pointer-interception layer can't
      // accidentally override it. Without this, the iframe sometimes
      // appears to be inert until the user clicks a Flutter widget first
      // (a known platform-view focus quirk).
      el.style.setProperty('pointer-events', 'auto', 'important');
      // Focus the iframe immediately after it lands in the DOM so its own
      // document starts receiving pointer events without the user needing
      // to click into the Flutter UI first. Focusing the IFrameElement
      // itself works cross-browser and doesn't need contentWindow access
      // (WindowBase has no .focus() in dart:html).
      el.onLoad.first.then((_) {
        try { el.focus(); } catch (_) {/* detached */}
      });
      _iframe = el;
      return el;
    });
  }

  String _iframeSrc() {
    final sym = Uri.encodeQueryComponent(_store.symbol);
    final tf = Uri.encodeQueryComponent(_store.timeframe.label);
    final theme = _currentThemeName();
    // Path is `/footprint-chart/...` rather than `/orderflow/...` to avoid
    // colliding with the Flutter `/orderflow` route — a refresh at the
    // Flutter route would otherwise resolve to the iframe's own index.html
    // (served as the directory index) and bypass Flutter entirely.
    return '/footprint-chart/index.html?sym=$sym&tf=$tf&theme=$theme';
  }

  String _currentThemeName() {
    final dark = ref.read(themeProvider).isDarkMode;
    return dark ? 'dark' : 'light';
  }

  void _onWindowMessage(html.Event event) {
    if (event is! html.MessageEvent) return;
    final raw = event.data;
    // The iframe posts JSON strings to avoid Dart/JS Map round-trip quirks.
    String? type;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['type'] is String) {
          type = decoded['type'] as String;
        }
      } catch (_) {
        return;
      }
    } else if (raw is Map && raw['type'] is String) {
      type = raw['type'] as String;
    }
    if (type == 'orderflow-ready') {
      _iframeReady = true;
      // Push current selection in case it changed between iframe boot
      // and the ready handshake.
      _post({'type': 'setSymbol', 'value': _store.symbol});
      _post({'type': 'setTimeframe', 'value': _store.timeframe.label});
      _post({'type': 'setOverlays', 'value': _store.overlays.toJson()});
      _pushTheme(force: true);
    }
  }

  void _pushTheme({bool force = false}) {
    final theme = _currentThemeName();
    if (!force && theme == _pushedTheme) return;
    _pushedTheme = theme;
    if (_iframeReady) {
      _post({'type': 'setTheme', 'value': theme});
    }
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {});
    if (_iframeReady) {
      _post({'type': 'setSymbol', 'value': _store.symbol});
      _post({'type': 'setTimeframe', 'value': _store.timeframe.label});
      _post({'type': 'setOverlays', 'value': _store.overlays.toJson()});
    }
  }

  void _post(Map<String, dynamic> message) {
    // Send as a JSON string — dart:html's structured-clone of a Dart Map
    // doesn't reliably surface as a plain JS object on the iframe side,
    // so the JS handler parses strings explicitly.
    final payload = jsonEncode(message);
    final el = html.document.getElementById(_iframeId);
    if (el is html.IFrameElement) {
      el.contentWindow?.postMessage(payload, '*');
      return;
    }
    _iframe?.contentWindow?.postMessage(payload, '*');
  }

  void _refresh() {
    _post({'type': 'refresh'});
  }

  @override
  Widget build(BuildContext context) {
    // Watch the theme so the iframe is told whenever the user toggles light/dark.
    ref.watch(themeProvider);
    // Push the new theme to the iframe after build completes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushTheme());
    final bg = ref.read(themeProvider).isDarkMode
        ? const Color(0xFF0B0F14)
        : const Color(0xFFFFFFFF);
    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderflowTopBar(
            store: _store,
            onRefresh: _refresh,
            onPopupVisibilityChanged: setIframePointerEvents,
          ),
          Expanded(
            child: HtmlElementView(viewType: _viewType),
          ),
        ],
      ),
    );
  }
}
