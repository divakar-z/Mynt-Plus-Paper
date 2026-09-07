// Hosts the in-house chart engine iframe in a stripped-down "lite" mode
// for the scan-explanation screen. No top bar, no right tray, no orders,
// no WebSocket subscriptions, no history fetches — the entire payload
// (bars + indicators + matched mask) is pushed in a single message right
// after the engine signals it's ready.
//
// Why a separate host instead of `liteMode: true` on the full shell:
// the full shell is ~3500 lines, threaded through ChartEngineSession +
// WS provider + order overlays + OI + top-bar plumbing. Bolting a lite
// flag onto every code path would scatter conditionals everywhere and
// risk regressing the production trade view. This host is ~200 lines
// and reuses the iframe + bridge encoders verbatim.

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/scanner_model/scan_explain.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/screens/web/chart_engine/utils/chart_engine_bridge.dart';

class LiteChartIframeHost extends ConsumerStatefulWidget {
  final ScanExplainResponse response;
  const LiteChartIframeHost({super.key, required this.response});

  @override
  ConsumerState<LiteChartIframeHost> createState() =>
      _LiteChartIframeHostState();
}

class _LiteChartIframeHostState extends ConsumerState<LiteChartIframeHost> {
  late final String _iframeId;
  late final String _viewType;
  html.IFrameElement? _iframe;
  void Function(html.Event)? _windowMessageRef;
  bool _iframeReady = false;
  String _currentThemeName = '';

  @override
  void initState() {
    super.initState();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    _iframeId = 'lite-chart-engine-iframe-$stamp';
    _viewType = 'lite-chart-engine-view-$stamp';
    _registerFactory();
    _windowMessageRef = _onWindowMessage;
    html.window.addEventListener('message', _windowMessageRef);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = ref.read(themeProvider).isDarkMode ? 'dark' : 'light';
    if (_currentThemeName != theme) {
      _currentThemeName = theme;
      if (_iframeReady) _post(encodeSetTheme(theme));
    }
  }

  @override
  void didUpdateWidget(covariant LiteChartIframeHost old) {
    super.didUpdateWidget(old);
    // If the upstream response changes (e.g. user reruns or the cache
    // returns a different payload), re-push so the chart reflects the
    // new bars/indicators without needing a full remount.
    if (_iframeReady && !identical(old.response, widget.response)) {
      _pushExplanation();
    }
  }

  @override
  void dispose() {
    if (_windowMessageRef != null) {
      html.window.removeEventListener('message', _windowMessageRef);
      _windowMessageRef = null;
    }
    // Same ghost-iframe guard as the full shell — Flutter Web's
    // HtmlElementView occasionally leaves the iframe element in the DOM
    // after the widget unmounts, which keeps intercepting pointer events
    // and makes whatever Flutter widget is now on top look unresponsive.
    try {
      html.document.getElementById(_iframeId)?.remove();
    } catch (_) {}
    _iframe = null;
    super.dispose();
  }

  void _registerFactory() {
    final initialTheme =
        ref.read(themeProvider).isDarkMode ? 'dark' : 'light';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final el = html.IFrameElement()
        ..id = _iframeId
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#FFFFFF'
        ..allow = 'autoplay'
        // `lite=1` tells chart-engine.js / topbar.js to skip the HTML top
        // bar entirely so the explain view shows nothing but the chart.
        ..src = '/chart-engine/index.html?theme=$initialTheme&lite=1';
      el.style.setProperty('pointer-events', 'auto', 'important');
      el.onLoad.first.then((_) {
        try { el.focus(); } catch (_) {}
        // No-op setState to re-trigger Flutter's hit-region calculation —
        // same fix as the full shell. Without it the iframe sometimes
        // doesn't get pointer events until the user clicks any other
        // widget once.
        if (mounted) setState(() {});
      });
      _iframe = el;
      return el;
    });
  }

  void _onWindowMessage(html.Event event) {
    if (!mounted) return;
    if (event is! html.MessageEvent) return;
    final msg = decodeIframeMessage(event.data);
    if (msg == null) return;
    // No `event.source` filter — the full chart shell also takes every
    // message off `window`; trying to be more selective here broke
    // chart-engine-ready arriving before the iframe.contentWindow
    // reference settled. The `_post` calls below use the iframe's own
    // contentWindow so outgoing messages stay scoped to this host.
    switch (msg['type']) {
      case 'chart-engine-ready':
        _iframeReady = true;
        _bootstrap();
        break;
      case 'fetchHistory':
        // setExplanationData pre-loads candles directly, so we should
        // never see a history request here. Defensive: if one fires
        // (e.g. a phantom resize-extend), reply empty so the engine
        // doesn't hang waiting on a response.
        final v = msg['value'];
        if (v is Map) {
          final reqId = v['requestId'];
          if (reqId is String) _post(encodeHistoryResult(reqId, const []));
        }
        break;
      // subscribe / unsubscribe / overlayClicked / drawingCommitted /
      // paneActivated / takeScreenshot etc. → silently ignored. The
      // explain view is read-only; the lite-mode guard in chart.js
      // already prevents the order/depth dispatches that could matter.
    }
  }

  void _bootstrap() {
    final theme = _currentThemeName.isEmpty
        ? (ref.read(themeProvider).isDarkMode ? 'dark' : 'light')
        : _currentThemeName;
    _post(encodeSetTheme(theme));
    _post(encodeSetLiteMode(true));
    // Single pane — area 'a', id '0'. chart-engine.js's applyLayout
    // constructs panes with stringified integer ids ('0', '1', ...) and
    // area letters starting at 'a' (see applyLayout in chart-engine.js).
    _post(encodeSetLayout(
      id: 'single-explain',
      areas: '"a"',
      rows: '1fr',
      columns: '1fr',
      paneCount: 1,
    ));
    _pushExplanation();
  }

  void _pushExplanation() {
    final r = widget.response;
    final bars = <Map<String, dynamic>>[
      for (final b in r.bars)
        {
          'date': b.date,
          'open': b.open,
          'high': b.high,
          'low': b.low,
          'close': b.close,
          'volume': b.volume,
        },
    ];
    final columns = <Map<String, dynamic>>[
      for (final c in r.columns)
        {
          'key': c.key,
          'label': c.label,
          'kind': _columnKindWire(c.kind),
          'sub_panel': c.subPanel,
          'color_hint': c.colorHint,
        },
    ];
    _post(encodeSetExplanationData(
      paneId: '0',
      bars: bars,
      indicators: r.indicators,
      matched: r.matched,
      columns: columns,
      ticker: r.ticker,
      // The chart's top-left symbol strip shows this — it must be the
      // SYMBOL, not the scanner name (the scanner name already heads the
      // page). Same convention as the trade chart.
      displayName: r.ticker,
    ));
  }

  void _post(String payload) {
    final el = html.document.getElementById(_iframeId);
    if (el is html.IFrameElement) {
      postToIframe(el, payload);
      return;
    }
    if (_iframe != null) postToIframe(_iframe!, payload);
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

String _columnKindWire(ExplainColumnKind k) {
  switch (k) {
    case ExplainColumnKind.float:
      return 'float';
    case ExplainColumnKind.boolean:
      return 'boolean';
    case ExplainColumnKind.enumKind:
      return 'enum';
  }
}
