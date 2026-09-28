import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/active_pane_symbol_request.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_oi_data.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_order_validation.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/indicator_schema.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/pane_runtime_status.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/overlay_payload.dart';
import 'package:mynt_plus/screens/web/chart_engine/utils/chart_engine_bridge.dart';
import 'package:mynt_plus/screens/web/chart_engine/utils/popout_feed_client.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/chart_engine_top_bar.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/models/marketwatch_model/alert_model/alert_pending_model.dart';
import 'package:mynt_plus/models/marketwatch_model/scrip_info.dart';
import 'package:mynt_plus/models/order_book_model/gtt_order_book.dart';
import 'package:mynt_plus/models/order_book_model/modify_order_model.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/order_book_model/place_gtt_order.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:mynt_plus/provider/auth_provider.dart';
import 'package:mynt_plus/provider/market_watch_provider.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/portfolio_provider.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/overlay_detail_popup.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/overlay_close_dialog.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/place_order_prefill.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/qty_selector_popup.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/plus_menu_popup.dart';
import 'package:mynt_plus/utils/responsive_navigation.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';

/// Metadata for a single option token subscribed via WebSocket for live OI.
class _OiTokenInfo {
  final double strike;
  final bool isCe;
  /// Previous-day OI (snapshot from chain fetch) — used as the denominator
  /// for computing OI-change % and as the fallback when no WS tick has
  /// arrived yet.
  final double poi;
  const _OiTokenInfo({
    required this.strike,
    required this.isCe,
    required this.poi,
  });
}

/// Annotation drawing tools that carry user text — placement triggers a
/// text-entry dialog (see `_promptDrawingText`).
// Price Label is intentionally NOT here: it auto-shows the price at its anchor
// and never prompts for or stores custom text.
const Set<String> _kTextDrawTools = {
  'text', 'note', 'callout', 'comment', 'signpost',
};

/// Full-page Chart Engine shell. Hosts the iframe at
/// `/chart-engine/index.html` and bridges Flutter state ↔ iframe via
/// postMessage. Mirrors the proven patterns from `OrderflowShellScreen`.
class ChartEngineShellScreen extends ConsumerStatefulWidget {
  /// When true, the Flutter top-bar row is skipped — the iframe's own
  /// HTML/JS top bar (Symbol search, Timeframe, INSTANT, indicators, etc.)
  /// owns all controls. Used by `EmbeddedChartView` to drop the now-empty
  /// Flutter chrome inside the symbol details screen.
  final bool embedded;

  /// When true, this shell hosts the detached `/chart-popout` window (a second
  /// Flutter instance). It feeds from [feed] (the alternate `ws.zebull.in`
  /// socket) instead of the shared `websocketProvider` — the main window owns
  /// the one allowed `go.mynt.in` socket, so the popout must never open it. The
  /// iframe also boots in `?popout=1` (order surfaces hidden) and order-book /
  /// GTT fetches are skipped.
  final bool popout;

  /// Popout-only live feed over the alternate socket. Non-null iff [popout].
  final PopoutFeedClient? feed;

  const ChartEngineShellScreen({
    super.key,
    this.embedded = false,
    this.popout = false,
    this.feed,
  });

  @override
  ConsumerState<ChartEngineShellScreen> createState() =>
      _ChartEngineShellScreenState();
}

class _ChartEngineShellScreenState
    extends ConsumerState<ChartEngineShellScreen> {
  // Unique per state instance — critical for remount safety. Reusing a
  // static viewType across instances pins the factory closure to the first
  // (disposed) state and leaves new mounts wired to dead state.
  late final String _viewType;
  late final String _iframeId;
  html.IFrameElement? _iframe;
  bool _iframeReady = false;
  String? _pushedTheme;
  // Remember what we last pushed per pane so we don't spam postMessage
  // when other store fields change.
  String? _pushedLayoutId;
  String? _pushedActivePaneId;
  final Map<int, String> _pushedSymbolKey = {};
  final Map<int, String> _pushedTradableKey = {};
  // Per-shell cache of GetSecurityInfo `nontrd` result, keyed by
  // `exch|token`. Cannot rely on marketWatchProvider.storeQuotes — its
  // scrip-info write path is buggy (uses `storeQuotes[token]?['s'] = …`
  // without first initializing `storeQuotes[token] = {}`, so the assignment
  // silently no-ops when the map entry doesn't exist).
  final Map<String, bool> _tradableCache = {};
  // Per-shell cache of the scrip's lot size + tick size from GetSecurityInfo,
  // keyed by `exch|token`. Re-applied on every symbol switch (even a cache hit)
  // so the lot-multiplied qty self-heals each time — not just the first time we
  // see the scrip. Without this, re-selecting a futures/commodity with a
  // lot-less scrip left qty=1 and the order was rejected.
  final Map<String, ({int? ls, double? ti, int? frz})> _scripMetaCache = {};
  final Map<int, int> _pushedTimeframe = {};
  final Map<int, String> _pushedOverlaysJson = {};
  final Map<int, String> _pushedPaneOverlaysJson = {};
  final Map<int, int> _pushedQty = {};
  // Phase 7 — diff caches for drawings + active draw tool.
  final Map<int, String> _pushedDrawingsJson = {};
  String? _pushedDrawTool;
  bool _hasPushedDrawTool = false;
  // Phase 14.1 — diff cache for the keyboard-shortcuts toggle. `_hasPushed`
  // flag distinguishes "never pushed" from "pushed false" so the first
  // disable still reaches the iframe.
  bool? _pushedShortcutsEnabled;
  // Phase 8 — diff cache for per-pane technical indicators.
  final Map<int, String> _pushedIndicatorsJson = {};
  // Phase 16 — diff caches for per-pane candle style + high/low markers.
  final Map<int, String> _pushedCandleStyle = {};
  final Map<int, bool> _pushedShowHighLowMarkers = {};
  // Phase 18 — diff caches for OI toggle, bar-countdown toggle, OI data.
  final Map<int, bool> _pushedShowOptionChainOi = {};
  final Map<int, bool> _pushedShowBarCountdown = {};
  final Map<int, String> _pushedOiDataJson = {};
  // Phase 20 — diff cache for the key-levels toggle.
  final Map<int, bool> _pushedShowKeyLevels = {};
  // Phase 23 — diff caches for pivot variant, magnet, volume profile.
  final Map<int, String> _pushedPivotVariant = {};
  final Map<int, bool> _pushedMagnetEnabled = {};
  final Map<int, bool> _pushedShowVolumeProfile = {};
  // Phase 25 — diff cache for auto-pattern (HH/HL/LH/LL) toggle.
  final Map<int, bool> _pushedShowAutoPattern = {};
  // Crosshair lines on/off — chips always render, only the dashed spans gate.
  final Map<int, bool> _pushedShowCrosshairLines = {};
  bool? _pushedDrawingsLocked;
  bool? _pushedDrawingsHidden;
  final Set<String> _subscribedKeys = {}; // 'EXCH|TOKEN' format
  // Tracks the last observed WS connection state. On any false→true
  // transition (broker reconnected after a drop, tab returned from
  // background, etc.) we re-issue establishConnection for every key in
  // `_subscribedKeys` — the WS provider clears `_sentSubscriptions` on
  // reset, so without this nudge the chart silently stops receiving
  // ticks even though our local set still thinks it's subscribed.
  bool _lastWsConnected = false;
  VoidCallback? _wsListener;
  // Stream subscription on `socketDataStream` covers index ticks
  // that the ChangeNotifier `addListener` path doesn't reliably wake on
  // (NIFTY 50 / SENSEX spot updates were stale because their `hasUpdates`
  // gate in the WS provider sometimes suppresses `notifyListeners` while
  // still pushing the stream). Every working live-tick consumer in the app
  // (watchlist, option chain, futures) uses the stream — we follow suit.
  StreamSubscription? _wsStreamSub;
  // 1s poll-forward fallback — guarantees the chart receives the latest
  // socketDatas for subscribed tokens at least once per second regardless of
  // WS provider notify gating.
  Timer? _tickPollTimer;
  // Phase 18 — periodic OI fetch timer.
  Timer? _oiFetchTimer;
  // TEMP diagnostic — set true to trace the OI fetch path (toggle/scrip per
  // pane + getLinkedScrip outcome) in the browser console. Remove once the
  // SENSEX/SILVER no-OI cause is confirmed.
  static const bool _kOiDebug = false;
  // Expiry (getLinkedScrip) fetch control, keyed by scrip 'exch|token'.
  // `_linkedScripCheckedAt`: last attempt (ms) → throttle re-fetches to once
  // per 5 min (live OI flows via WS, so frequent expiry re-fetch is wasteful).
  final Map<String, int> _linkedScripCheckedAt = {};
  // Scrips whose getLinkedScrip returned NO chain, with WHEN (epoch ms). Skipped
  // for a long TTL (15 min) rather than forever, so a transient empty (e.g. an
  // index like SENSEX queried before its chain is available) doesn't disable OI
  // permanently — while still not spamming the server.
  final Map<String, int> _noOptionChainAt = {};
  // Task 3 — per-pane option-token subscription map for WS-based OI delivery.
  final Map<int, Map<String, _OiTokenInfo>> _oiSubs = {};
  // Last OI scripKey seen per pane. Detects a symbol switch in a pane so we can
  // wipe the previous symbol's stale OI state (strikes, fetch timestamp, expiry,
  // throttles) — otherwise the prior symbol's recent fetch timestamp makes Step 2
  // think the new symbol's chain is still "fresh" and it never refetches.
  final Map<int, String> _oiPaneScripKey = {};
  OverlayEntry? _overlayDetailEntry;
  OverlayEntry? _qtyPopupEntry;
  OverlayEntry? _plusMenuEntry;
  final Map<String, int> _lastQtyByScrip = {}; // exch|token → last committed qty
  bool _hitRegionPrimed = false;
  // `addEventListener` / `removeEventListener` require the SAME function
  // reference to pair an add with its remove. Dart's `this.method` tearoff
  // creates a fresh closure on every access — so `removeEventListener` in
  // dispose would silently fail and the listener would leak, leaving a
  // dangling `ref` from this State instance that throws "Using ref when a
  // widget is about to or has been unmounted" on every subsequent iframe
  // message. Cache the tearoff once so add/remove pair correctly.
  void Function(html.Event)? _windowMessageRef;

  @override
  void initState() {
    super.initState();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    _iframeId = 'chart-engine-chart-iframe-$stamp';
    _viewType = 'chart-engine-view-$stamp';
    _registerFactory();
    _windowMessageRef = _onWindowMessage;
    html.window.addEventListener('message', _windowMessageRef);
    // Phase 18 — periodic OI refresh check. Fires every 5s; the body itself
    // gates by its own freshness window so most ticks are no-ops.
    _oiFetchTimer = Timer.periodic(
        const Duration(seconds: 5), _maybeFetchOptionChain);
    // 1s tick poll-forward fallback — guarantees the chart sees the latest
    // socketDatas at least once per second regardless of WS notify gating.
    _tickPollTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => _wsForwardAll());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.popout) {
        // POPOUT: never touch the shared websocketProvider — the MAIN window
        // owns the single allowed go.mynt.in Noren socket, and a second
        // connection with the same uid would kick it. Drive ticks from the
        // alternate ws.zebull.in feed instead. The engine's per-token
        // subscribe requests route to `_feed.subscribe` (see _handleSubscribe)
        // and each tick posts straight into the iframe. No GTT/order book —
        // the popout is view-only (order handlers are gated off, ?popout=1).
        final feed = widget.feed;
        if (feed != null) {
          feed.onTick = (token, packet) {
            if (!mounted) return;
            _post(encodeTick(token, packet));
          };
          feed.start();
        }
        return;
      }
      final ws = ref.read(websocketProvider);
      // All three paths funnel into a microtask-coalesced wrapper so a
      // burst of notifies (very common: ChangeNotifier fires once per WS
      // packet, the stream emits once for the same packet) results in a
      // single forward pass. Critical when many panes are open — without
      // coalescing the shell was iterating every subscribed key 5-10×
      // per second, posting 30+ messages/sec to the iframe per pane.
      _wsListener = _wsForwardCoalesced;
      ws.addListener(_wsListener!);
      _wsStreamSub =
          ws.socketDataStream.listen((_) => _wsForwardCoalesced());
      // Phase 27 — pull the GTT/OCO book once so placed TP/SL brackets
      // render on the chart. `initLoad` keeps it from switching the order
      // window tab or toggling WS subscriptions. The shell already listens
      // to orderProvider, so the resulting notify re-pushes the overlays.
      ref.read(orderProvider).fetchGTTOrderBook(context, 'initLoad');
    });
  }

  bool _forwardScheduled = false;
  void _wsForwardCoalesced() {
    if (_forwardScheduled) return;
    _forwardScheduled = true;
    scheduleMicrotask(() {
      _forwardScheduled = false;
      _wsForwardAll();
    });
  }

  @override
  void dispose() {
    _oiFetchTimer?.cancel();
    _tickPollTimer?.cancel();
    // Popout: tear down the alternate feed socket (heartbeat, watchdog,
    // reconnect timers) so the closed window leaves no live connection.
    widget.feed?.stop();
    _dismissAllPopups();
    if (_windowMessageRef != null) {
      html.window.removeEventListener('message', _windowMessageRef);
      _windowMessageRef = null;
    }
    if (_wsListener != null) {
      try { ref.read(websocketProvider).removeListener(_wsListener!); } catch (_) {}
    }
    _wsStreamSub?.cancel();
    _wsStreamSub = null;
    // Flutter Web's HtmlElementView occasionally leaves the iframe
    // element in the DOM after the widget unmounts — a "ghost" iframe
    // that keeps intercepting pointer events. When this shell is used
    // as the embedded chart inside the details screen and the user
    // toggles back to TradingView, that ghost iframe sits on top of
    // the TradingView portal and makes it look unresponsive. Force-
    // remove the element on dispose to kill that hit region.
    try {
      final el = html.document.getElementById(_iframeId);
      el?.remove();
    } catch (_) {}
    _iframe = null;
    super.dispose();
  }

  /// Forwards the latest WS tick cache to the chart iframe for every
  /// subscribed token, then refreshes WS-based OI for any active pane.
  /// Called from three paths: WS ChangeNotifier, socketDataStream, and the
  /// 1s poll-forward timer — all converge here so a single implementation
  /// covers every delivery mechanism.
  void _wsForwardAll() {
    if (!mounted) return;
    // Popout drives ticks from the alternate feed (see initState); the shared
    // socket is off-limits here, so the 1s poll-forward is a no-op.
    if (widget.popout) return;
    if (_subscribedKeys.isEmpty && _oiSubs.isEmpty) return;
    final ws = ref.read(websocketProvider);
    // Reconnect detection — re-subscribe everything when WS comes back up.
    // The WS provider clears `_sentSubscriptions` on disconnect, so on a
    // fresh reconnect there are no live subscriptions even though our
    // local `_subscribedKeys` set says there should be.
    final nowConnected = ws.wsConnected;
    if (nowConnected && !_lastWsConnected) {
      _resubscribeAll();
      _post(encodeWsReconnected());
    }
    _lastWsConnected = nowConnected;
    final data = ws.socketDatas;
    for (final key in _subscribedKeys) {
      final parts = key.split('|');
      if (parts.length != 2) continue;
      final exch = parts[0];
      final token = parts[1];
      final entry = data[token];
      if (entry is! Map) continue;
      // Only forward when there's a meaningful payload (lp, v, or
      // bid/ask present). `bp1`/`sp1` come down on touchline ticks
      // alongside lp and feed the chart's bid/ask header strip.
      final packet = <String, dynamic>{
        'exch': exch,
        if (entry['lp'] != null) 'lp': entry['lp'],
        if (entry['v'] != null) 'v': entry['v'],
        if (entry['ft'] != null) 'ft': entry['ft'],
        if (entry['bp1'] != null) 'bp1': entry['bp1'],
        if (entry['sp1'] != null) 'sp1': entry['sp1'],
        // Day OHLC from the touchline feed — needed to form TODAY's
        // daily/weekly/monthly bar correctly (EOD history ends yesterday, so
        // the live bar must use the real session open/high/low, not the
        // LTP-at-open). `o`/`h`/`l` are today's; `c` here is the previous close.
        if (entry['o'] != null) 'o': entry['o'],
        if (entry['h'] != null) 'h': entry['h'],
        if (entry['l'] != null) 'l': entry['l'],
        // Previous close + day change / % — the idle chart header shows
        // "LTP  ±change (±%)" for the day while no candle is hovered.
        if (entry['c'] != null) 'c': entry['c'],
        if (entry['chng'] != null) 'chng': entry['chng'],
        if (entry['pc'] != null) 'pc': entry['pc'],
      };
      if (packet.length <= 1) continue;
      _post(encodeTick(token, packet));
    }
    _refreshOiFromWs();
  }

  /// Derives live OI for each pane's subscribed option tokens from
  /// `ws.socketDatas` and pushes updated [ChartOiStrike] lists via
  /// [chartOiDataProvider]. Called at the end of every [_wsForwardAll] tick.
  void _refreshOiFromWs() {
    if (_oiSubs.isEmpty) return;
    final ws = ref.read(websocketProvider);
    final oiNotifier = ref.read(chartOiDataProvider.notifier);
    for (final paneEntry in _oiSubs.entries) {
      final paneIdx = paneEntry.key;
      final tokenMap = paneEntry.value;
      if (tokenMap.isEmpty) continue;
      final byStrike = <double, ChartOiStrike>{};
      for (final t in tokenMap.entries) {
        final token = t.key;
        final info = t.value;
        final socketEntry = ws.socketDatas[token];
        double oi = info.poi; // fall back to snapshot if no tick yet
        double poi = info.poi; // previous-day OI — prefer the live WS value
        if (socketEntry is Map) {
          final rawOi = socketEntry['oi'];
          if (rawOi is num) {
            oi = rawOi.toDouble();
          } else if (rawOi is String) {
            oi = double.tryParse(rawOi) ?? oi;
          }
          final rawPoi = socketEntry['poi'];
          if (rawPoi is num) {
            poi = rawPoi.toDouble();
          } else if (rawPoi is String) {
            poi = double.tryParse(rawPoi) ?? poi;
          }
        }
        final chgPct = poi > 0 ? ((oi - poi) / poi) * 100 : 0.0;
        final prev = byStrike[info.strike];
        byStrike[info.strike] = ChartOiStrike(
          strike: info.strike,
          callOi: info.isCe ? oi : (prev?.callOi ?? 0),
          putOi: info.isCe ? (prev?.putOi ?? 0) : oi,
          callOiChgPct:
              info.isCe ? chgPct : (prev?.callOiChgPct ?? 0),
          putOiChgPct:
              info.isCe ? (prev?.putOiChgPct ?? 0) : chgPct,
          callPoi: info.isCe ? poi : (prev?.callPoi ?? 0),
          putPoi: info.isCe ? (prev?.putPoi ?? 0) : poi,
        );
      }
      final list = byStrike.values.toList()
        ..sort((a, b) => a.strike.compareTo(b.strike));
      oiNotifier.setForPane(
          paneIdx, list, DateTime.now().millisecondsSinceEpoch);
    }
  }

  void _registerFactory() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final el = html.IFrameElement()
        ..id = _iframeId
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        // Theme-aware base so the pre-paint iframe surface doesn't flash a
        // near-black panel behind the light-mode chart.
        ..style.backgroundColor =
            ref.read(themeProvider).isDarkMode ? '#0B0F14' : '#FFFFFF'
        ..allow = 'autoplay'
        ..src = '/chart-engine/index.html?theme=${_currentThemeName()}'
            '${widget.popout ? '&popout=1' : ''}';
      el.style.setProperty('pointer-events', 'auto', 'important');
      el.onLoad.first.then((_) {
        try { el.focus(); } catch (_) {}
        // Flutter Web's HtmlElementView computes its platform-view hit
        // region during the first layout pass — which happens BEFORE the
        // iframe finishes loading async. Without nudging Flutter to redo
        // that layout, the chart appears unresponsive until the user clicks
        // any other widget (which forces a rebuild). A no-op setState
        // re-registers the hit region with the correct iframe geometry.
        if (mounted) setState(() {});
      });
      _iframe = el;
      return el;
    });
  }

  String _currentThemeName() =>
      ref.read(themeProvider).isDarkMode ? 'dark' : 'light';

  void _onWindowMessage(html.Event event) {
    try {
      _onWindowMessageInner(event);
    } catch (e, st) {
      // The browser's `addEventListener` callback is not allowed to throw —
      // any sync exception here surfaces as an "Uncaught Error" in console
      // and breaks the iframe message bridge for that tick. Catch + log so
      // a single bad message doesn't cascade into a dead chart.
      // ignore: avoid_print
      print('chart-engine _onWindowMessage error: $e\n$st');
    }
  }

  void _onWindowMessageInner(html.Event event) {
    if (!mounted) return;
    if (event is! html.MessageEvent) return;
    final msg = decodeIframeMessage(event.data);
    if (msg == null) return;
    switch (msg['type']) {
      case 'chart-engine-ready':
        _iframeReady = true;
        _pushAll(force: true);
        // Drop the branded load overlay now that the iframe is up and the
        // chart's own symbol/loading state takes over.
        if (mounted) setState(() {});
        break;
      case 'fetchHistory':
        _handleFetchHistory(msg['value']);
        break;
      case 'subscribe':
        _handleSubscribe(msg['value']);
        break;
      case 'unsubscribe':
        _handleUnsubscribe(msg['value']);
        break;
      case 'paneActivated':
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          if (pid is String) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              ref.read(chartEngineSessionProvider.notifier).setActivePane(idx);
            }
          }
        }
        break;
      case 'paneSymbolApplied': {
        // Engine applied a watchlist pick to its active pane — sync the store
        // for that exact pane (persistence, overlays, OI fetch). The re-push
        // from this is a no-op in the engine (oldKey===newKey).
        final v = msg['value'];
        if (v is Map && v['scrip'] is Map) {
          final idx = int.tryParse(v['paneId']?.toString() ?? '');
          if (idx != null) {
            ref.read(chartEngineSessionProvider.notifier).setPaneSymbol(
                idx,
                ChartScrip.fromJson(
                    Map<String, dynamic>.from(v['scrip'] as Map)));
          }
        }
        break;
      }
      case 'overlayClicked': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final ovId = v['overlayId'];
          final cx = (v['clientX'] as num?)?.toDouble() ?? 0;
          final cy = (v['clientY'] as num?)?.toDouble() ?? 0;
          if (pid is String && ovId is String) {
            final idx = int.tryParse(pid);
            if (idx != null) _showOverlayDetail(idx, ovId, cx, cy);
          }
        }
        break;
      }
      case 'overlayCloseRequested': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final ovId = v['overlayId'];
          if (pid is String && ovId is String) {
            final idx = int.tryParse(pid);
            if (idx != null) _handleOverlayCloseRequested(idx, ovId);
          }
        }
        break;
      }
      case 'positionOcoRequested': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final ovId = v['overlayId'];
          if (pid is String && ovId is String) {
            final idx = int.tryParse(pid);
            if (idx != null) _handlePositionOcoRequested(idx, ovId);
          }
        }
        break;
      }
      case 'overlayDragEnded': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final ovId = v['overlayId'];
          final newPrice = (v['newPrice'] as num?)?.toDouble();
          if (pid is String && ovId is String && newPrice != null) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              _handleOverlayDragEnded(idx, ovId, newPrice);
            }
          }
        }
        break;
      }
      case 'bidClicked':
      case 'askClicked': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final price = (v['price'] as num?)?.toDouble();
          if (pid is String && price != null) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final pane = session.panes[idx];
                if (pane.scrip != null) {
                  _openPlaceOrderScreen(
                    scrip: pane.scrip!,
                    qty: pane.qty,
                    kind: msg['type'] == 'bidClicked'
                        ? OrderPrefillKind.sellLimit
                        : OrderPrefillKind.buyLimit,
                    price: price,
                  );
                }
              }
            }
          }
        }
        break;
      }
      case 'qtyChipClicked': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final cx = (v['clientX'] as num?)?.toDouble() ?? 0;
          final cy = (v['clientY'] as num?)?.toDouble() ?? 0;
          if (pid is String) {
            final idx = int.tryParse(pid);
            if (idx != null) _openQtyPopup(idx, cx, cy);
          }
        }
        break;
      }
      case 'plusClicked': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final price = (v['price'] as num?)?.toDouble();
          final cx = (v['clientX'] as num?)?.toDouble() ?? 0;
          final cy = (v['clientY'] as num?)?.toDouble() ?? 0;
          if (pid is String && price != null) {
            final idx = int.tryParse(pid);
            if (idx != null) _openPlusMenu(idx, price, cx, cy);
          }
        }
        break;
      }
      case 'drawingCommitted': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final draw = v['drawing'];
          if (pid is String && draw is Map) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final scrip = session.panes[idx].scrip;
                if (scrip != null) {
                  final scripKey = '${scrip.exch}|${scrip.token}';
                  final drawing = ChartDrawing.fromJson(
                      Map<String, dynamic>.from(draw));
                  final n = ref.read(chartEngineSessionProvider.notifier);
                  n.addDrawing(scripKey, drawing);
                  // Exit draw mode after a single placement.
                  n.setActiveDrawTool(null);
                  // Annotation tools prompt for their text right after
                  // placement; cancelling removes the just-added drawing.
                  if (_kTextDrawTools.contains(drawing.kind) &&
                      drawing.text.isEmpty) {
                    _promptDrawingText(scripKey, drawing.id);
                  }
                }
              }
            }
          }
        }
        break;
      }
      case 'drawingMoved': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final did = v['drawingId'];
          final pts = v['points'];
          if (pid is String && did is String && pts is List) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final scrip = session.panes[idx].scrip;
                if (scrip != null) {
                  final parsed = <DrawingPoint>[
                    for (final p in pts)
                      if (p is Map)
                        DrawingPoint.fromJson(Map<String, dynamic>.from(p)),
                  ];
                  ref
                      .read(chartEngineSessionProvider.notifier)
                      .updateDrawing(
                          '${scrip.exch}|${scrip.token}', did,
                          points: parsed);
                }
              }
            }
          }
        }
        break;
      }
      case 'drawingColorChanged': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final did = v['drawingId'];
          final color = v['color'];
          if (pid is String && did is String && color is String) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final scrip = session.panes[idx].scrip;
                if (scrip != null) {
                  ref
                      .read(chartEngineSessionProvider.notifier)
                      .updateDrawing(
                          '${scrip.exch}|${scrip.token}', did, color: color);
                }
              }
            }
          }
        }
        break;
      }
      case 'indicatorVisibilityToggled': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final iid = v['indicatorId'];
          final hidden = v['hidden'];
          if (pid is String && iid is String && hidden is bool) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              ref
                  .read(chartEngineSessionProvider.notifier)
                  .updateIndicator(idx, iid, hidden: hidden);
            }
          }
        }
        break;
      }
      case 'indicatorRemoved': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final iid = v['indicatorId'];
          if (pid is String && iid is String) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              ref
                  .read(chartEngineSessionProvider.notifier)
                  .removeIndicator(idx, iid);
            }
          }
        }
        break;
      }
      case 'indicatorSettingsRequested': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final iid = v['indicatorId'];
          if (pid is String && iid is String) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              // ignore: discarded_futures
              _openIndicatorSettings(idx, iid);
            }
          }
        }
        break;
      }
      case 'drawingThicknessChanged': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final did = v['drawingId'];
          final t = v['thickness'];
          if (pid is String && did is String && t is num) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final scrip = session.panes[idx].scrip;
                if (scrip != null) {
                  ref
                      .read(chartEngineSessionProvider.notifier)
                      .updateDrawing('${scrip.exch}|${scrip.token}', did,
                          thickness: t.toInt().clamp(1, 4));
                }
              }
            }
          }
        }
        break;
      }
      case 'drawingLockToggled': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final did = v['drawingId'];
          final lockedRaw = v['locked'];
          if (pid is String && did is String && lockedRaw is bool) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final scrip = session.panes[idx].scrip;
                if (scrip != null) {
                  ref
                      .read(chartEngineSessionProvider.notifier)
                      .updateDrawing(
                          '${scrip.exch}|${scrip.token}', did,
                          locked: lockedRaw);
                }
              }
            }
          }
        }
        break;
      }
      case 'drawingDeleted': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final did = v['drawingId'];
          if (pid is String && did is String) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final scrip = session.panes[idx].scrip;
                if (scrip != null) {
                  ref
                      .read(chartEngineSessionProvider.notifier)
                      .removeDrawing('${scrip.exch}|${scrip.token}', did);
                }
              }
            }
          }
        }
        break;
      }
      case 'drawingTextEditRequested': {
        // Double-clicked a text annotation → re-open the text dialog seeded
        // with its current value.
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final did = v['drawingId'];
          if (pid is String && did is String) {
            _editDrawingText(pid, did);
          }
        }
        break;
      }
      case 'chartScreenshot': {
        final v = msg['value'];
        if (v is Map) {
          final dataUrl = v['dataUrl'];
          final filenameRaw = v['filename'];
          if (dataUrl is String && dataUrl.isNotEmpty) {
            final filename = (filenameRaw is String && filenameRaw.isNotEmpty)
                ? filenameRaw
                : 'chart.png';
            // Trigger a browser download by creating an anchor with the
            // data URL and clicking it. Same pattern other web exporters
            // in this codebase (PDF / CSV download helpers) use.
            final anchor = html.AnchorElement(href: dataUrl)
              ..download = filename
              ..style.display = 'none';
            html.document.body?.append(anchor);
            anchor.click();
            anchor.remove();
          }
        }
        break;
      }
      case 'drawModeCancelled': {
        // Iframe-initiated cancel (e.g., Esc inside the chart).
        ref
            .read(chartEngineSessionProvider.notifier)
            .setActiveDrawTool(null);
        break;
      }
      // ── HTML top bar bridge ──────────────────────────────────────────
      case 'instantOrdersChanged': {
        // Fire-and-forget from the JS top bar's INSTANT chip. Mirror into
        // the Riverpod session so place-order logic + the (legacy) Flutter
        // Settings switch stay in sync.
        final v = msg['value'];
        if (v is Map && v['value'] is bool) {
          ref
              .read(chartEngineSessionProvider.notifier)
              .setInstantOrders(v['value'] as bool);
        }
        break;
      }
      case 'confirmInstantOrders': {
        // Request from the JS top bar's INSTANT chip ON path. Show the
        // existing warning-ack dialog (if the user hasn't acked yet) and
        // reply with `{confirmed: bool}` so JS knows whether to apply.
        final replyTo = msg['replyTo'];
        if (replyTo is! String) break;
        // ignore: discarded_futures
        _handleConfirmInstantOrders(replyTo);
        break;
      }
      case 'setActiveLayoutId': {
        // JS layout picker → Flutter. Resolve the id against the enum and
        // delegate to the existing setLayout path (which then pushes the
        // full spec back via the existing `setLayout` message).
        final v = msg['value'];
        if (v is Map && v['id'] is String) {
          final layout = ChartLayout.fromId(v['id'] as String);
          if (layout != null) {
            ref
                .read(chartEngineSessionProvider.notifier)
                .setLayout(layout);
          }
        }
        break;
      }
      case 'setActiveTimeframe': {
        // JS timeframe dropdown → Flutter. Applies to the active pane.
        final v = msg['value'];
        if (v is Map && v['minutes'] is num) {
          final session = ref.read(chartEngineSessionProvider);
          ref.read(chartEngineSessionProvider.notifier).setPaneTimeframe(
              session.activePaneIndex, (v['minutes'] as num).toInt());
        }
        break;
      }
      case 'setActiveCandleStyle': {
        // JS style picker → Flutter. Applies to the active pane.
        final v = msg['value'];
        if (v is Map && v['style'] is String) {
          final session = ref.read(chartEngineSessionProvider);
          ref.read(chartEngineSessionProvider.notifier).setPaneCandleStyle(
              session.activePaneIndex, v['style'] as String);
        }
        break;
      }
      case 'setActiveDrawTool': {
        // JS draw popover → Flutter. `kind` is null when the user toggled
        // the active tool off (clicked the highlighted Draw button).
        final v = msg['value'];
        if (v is Map) {
          final kind = v['kind'];
          ref
              .read(chartEngineSessionProvider.notifier)
              .setActiveDrawTool(kind is String ? kind : null);
        }
        break;
      }
      case 'setDrawingsLocked': {
        final v = msg['value'];
        if (v is Map && v['value'] is bool) {
          ref
              .read(chartEngineSessionProvider.notifier)
              .setDrawingsLocked(v['value'] as bool);
        }
        break;
      }
      case 'setDrawingsHidden': {
        final v = msg['value'];
        if (v is Map && v['value'] is bool) {
          ref
              .read(chartEngineSessionProvider.notifier)
              .setDrawingsHidden(v['value'] as bool);
        }
        break;
      }
      case 'clearDrawingsForActivePane': {
        ref
            .read(chartEngineSessionProvider.notifier)
            .clearDrawingsForActivePane();
        break;
      }
      case 'setActiveShowCrosshairLines': {
        // JS cursor-mode picker → Flutter. Applies to the active pane.
        final v = msg['value'];
        if (v is Map && v['value'] is bool) {
          final session = ref.read(chartEngineSessionProvider);
          ref
              .read(chartEngineSessionProvider.notifier)
              .setPaneShowCrosshairLines(
                  session.activePaneIndex, v['value'] as bool);
        }
        break;
      }
      case 'addIndicatorByKind': {
        // JS indicators popover → Flutter. Builds an IndicatorConfig with
        // the shared default color + period for this kind, and a fresh id.
        final v = msg['value'];
        if (v is Map && v['kind'] is String) {
          final kind = v['kind'] as String;
          final session = ref.read(chartEngineSessionProvider);
          final id = 'i-${DateTime.now().microsecondsSinceEpoch
              .toRadixString(36)}';
          ref.read(chartEngineSessionProvider.notifier).addIndicator(
                session.activePaneIndex,
                IndicatorConfig(
                  id: id,
                  kind: kind,
                  period: defaultIndicatorPeriod(kind),
                  color: defaultIndicatorColor(kind),
                ),
              );
        }
        break;
      }
      case 'removeIndicatorById': {
        // JS indicators popover → Flutter. Removes by id from active pane.
        final v = msg['value'];
        if (v is Map && v['id'] is String) {
          final session = ref.read(chartEngineSessionProvider);
          ref
              .read(chartEngineSessionProvider.notifier)
              .removeIndicator(session.activePaneIndex, v['id'] as String);
        }
        break;
      }
      case 'updateOrderDefaults': {
        // JS Order Defaults popover → Flutter. Accepts a patch object
        // with one or more known field names; each maps to a specific
        // setter on the notifier. Unknown keys are ignored.
        final v = msg['value'];
        if (v is Map) _applyOrderDefaultsPatch(v);
        break;
      }
      case 'updateActivePaneViewState': {
        // JS Settings → View on chart tab. Patch object of per-pane view
        // toggles. Routes to the matching setPaneShow* setter for active.
        final v = msg['value'];
        if (v is Map) _applyActivePaneViewPatch(v);
        break;
      }
      case 'setKeyboardShortcutsState': {
        // JS Settings tab toggle for keyboard shortcuts (session-level).
        final v = msg['value'];
        if (v is Map && v['value'] is bool) {
          ref
              .read(chartEngineSessionProvider.notifier)
              .setKeyboardShortcuts(v['value'] as bool);
        }
        break;
      }
      case 'updateChartPalette': {
        // JS Settings → Customize tab. Patch object of palette fields.
        final v = msg['value'];
        if (v is Map) _applyChartPalettePatch(v);
        break;
      }
      case 'searchSymbols': {
        // JS Symbol typeahead → Flutter (request/reply). Runs the same
        // search API the Flutter typeahead used; replies with serialized
        // result rows the JS popover renders directly.
        final replyTo = msg['replyTo'];
        if (replyTo is! String) break;
        final v = msg['value'];
        final q = (v is Map ? v['q'] : '') as String? ?? '';
        // ignore: discarded_futures
        _handleSearchSymbols(replyTo, q);
        break;
      }
      case 'setActivePaneSymbol': {
        // JS Symbol typeahead pick → Flutter. Applies to the active pane.
        final v = msg['value'];
        if (v is Map && v['scrip'] is Map) {
          final scrip = ChartScrip.fromJson(
              Map<String, dynamic>.from(v['scrip'] as Map));
          final session = ref.read(chartEngineSessionProvider);
          ref
              .read(chartEngineSessionProvider.notifier)
              .setPaneSymbol(session.activePaneIndex, scrip);
        }
        break;
      }
      // ---- Phase 14: keyboard shortcuts ----
      case 'keyBuyAtPrice':
      case 'keySellAtPrice': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final price = (v['price'] as num?)?.toDouble();
          if (pid is String && price != null) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final pane = session.panes[idx];
                final scrip = pane.scrip;
                if (scrip != null) {
                  // ignore: discarded_futures
                  _openPlaceOrderScreen(
                    scrip: scrip,
                    qty: pane.qty,
                    kind: msg['type'] == 'keyBuyAtPrice'
                        ? OrderPrefillKind.buyLimit
                        : OrderPrefillKind.sellLimit,
                    price: price,
                    paneIndex: idx,
                  );
                }
              }
            }
          }
        }
        break;
      }
      case 'keyToggleInstant': {
        // Wrap in a microtask so the switch body stays sync — the warning
        // dialog (when needed) and the toggle both happen inside the
        // async helper.
        // ignore: discarded_futures
        _toggleInstantFromKeyboard();
        break;
      }
      case 'keyTimeframe': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final minutes = (v['minutes'] as num?)?.toInt();
          if (pid is String && minutes != null) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              ref
                  .read(chartEngineSessionProvider.notifier)
                  .setPaneTimeframe(idx, minutes);
            }
          }
        }
        break;
      }
      case 'paneRenkoBrickSize': {
        final v = msg['value'];
        if (v is! Map) break;
        final paneIdStr = v['paneId'];
        final brickRaw = v['brickSize'];
        if (paneIdStr is! String) break;
        final idx = int.tryParse(paneIdStr);
        if (idx == null) break;
        final brick = (brickRaw is num) ? brickRaw.toDouble() : double.nan;
        if (!brick.isFinite || brick <= 0) {
          ref
              .read(paneRuntimeStatusProvider.notifier)
              .clearRenkoBrickSize(idx);
        } else {
          ref
              .read(paneRuntimeStatusProvider.notifier)
              .setRenkoBrickSize(idx, brick);
        }
        break;
      }
    }
  }

  Future<void> _openIndicatorSettings(int paneIdx, String indicatorId) async {
    if (!mounted) return;
    final session = ref.read(chartEngineSessionProvider);
    if (paneIdx < 0 || paneIdx >= session.panes.length) return;
    final pane = session.panes[paneIdx];
    final cfg = pane.indicators.firstWhere(
      (i) => i.id == indicatorId,
      orElse: () =>
          const IndicatorConfig(id: '', kind: '', period: 0, color: ''),
    );
    if (cfg.id.isEmpty) return;
    // Disable iframe pointer events while the modal is open — otherwise the
    // iframe captures clicks that should land on the dialog, making controls
    // un-interactive, and lets the crosshair render through the dialog area.
    _setIframePointerEvents(false);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => _IndicatorSettingsDialog(
          paneIndex: paneIdx,
          indicatorId: indicatorId,
        ),
      );
    } finally {
      _setIframePointerEvents(true);
    }
  }

  Future<void> _toggleInstantFromKeyboard() async {
    final session = ref.read(chartEngineSessionProvider);
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    final next = !session.instantOrders;
    if (next && !session.instantWarningAck) {
      final ok = await showInstantWarningDialog(context: context);
      if (!ok) return;
      notifier.markInstantWarningAck();
    }
    notifier.setInstantOrders(next);
  }

  /// Builds the active pane's "View on chart" bag for the JS Settings
  /// popover. Returns an empty map when no pane is mounted yet.
  Map<String, dynamic> _activePaneViewBag() {
    final session = ref.read(chartEngineSessionProvider);
    if (session.panes.isEmpty) return <String, dynamic>{};
    final p = session.active;
    return {
      'showHighLowMarkers': p.showHighLowMarkers,
      'showOptionChainOi':  p.showOptionChainOi,
      'showBarCountdown':   p.showBarCountdown,
      'showKeyLevels':      p.showKeyLevels,
      'pivotVariant':       p.pivotVariant,
      'showAutoPattern':    p.showAutoPattern,
      'magnetEnabled':      p.magnetEnabled,
      'showVolumeProfile':  p.showVolumeProfile,
      'gridlines':          p.overlays.gridlines,
      'volume':             p.overlays.volume,
    };
  }

  /// Builds the Customize-tab palette bag for the JS Settings popover.
  /// Includes empty-string fields (theme fallback) — distinct from the
  /// `toWire()` shape consumed by the chart renderer which omits them.
  Map<String, dynamic> _chartPaletteBag(ChartPalette p) {
    return {
      'bullBody':     p.bullBody,
      'bearBody':     p.bearBody,
      'bullWick':     p.bullWick,
      'bearWick':     p.bearWick,
      'background':   p.background,
      'text':         p.text,
      'grid':         p.grid,
      'sessionBreak': p.sessionBreak,
      'crosshair':    p.crosshair,
      // Defaults the JS reset affordance compares against.
      'defaults': {
        'bullBody': ChartPalette.dBullBody,
        'bearBody': ChartPalette.dBearBody,
        'bullWick': ChartPalette.dBullWick,
        'bearWick': ChartPalette.dBearWick,
      },
    };
  }

  /// Dispatcher for the JS Settings → View on chart tab. Each known field
  /// name routes to the matching per-pane setter on the session notifier.
  void _applyActivePaneViewPatch(Map<dynamic, dynamic> patch) {
    final session = ref.read(chartEngineSessionProvider);
    final n = ref.read(chartEngineSessionProvider.notifier);
    final i = session.activePaneIndex;
    if (i < 0 || i >= session.panes.length) return;
    patch.forEach((key, value) {
      switch (key) {
        case 'showHighLowMarkers':  if (value is bool)   n.setPaneShowHighLowMarkers(i, value); break;
        case 'showOptionChainOi':   if (value is bool)   n.setPaneShowOptionChainOi(i, value);  break;
        case 'showBarCountdown':    if (value is bool)   n.setPaneShowBarCountdown(i, value);   break;
        case 'showKeyLevels':       if (value is bool)   n.setPaneShowKeyLevels(i, value);      break;
        case 'pivotVariant':        if (value is String) n.setPanePivotVariant(i, value);       break;
        case 'showAutoPattern':     if (value is bool)   n.setPaneShowAutoPattern(i, value);    break;
        case 'magnetEnabled':       if (value is bool)   n.setPaneMagnetEnabled(i, value);      break;
        case 'showVolumeProfile':   if (value is bool)   n.setPaneShowVolumeProfile(i, value);  break;
        case 'gridlines': if (value is bool) {
          final cur = session.panes[i].overlays;
          n.setPaneOverlays(i, cur.copyWith(gridlines: value));
        } break;
        case 'volume': if (value is bool) {
          final cur = session.panes[i].overlays;
          n.setPaneOverlays(i, cur.copyWith(volume: value));
        } break;
      }
    });
  }

  /// Dispatcher for the JS Settings → Customize tab. Each known key maps
  /// to one of [ChartPaletteNotifier]'s setters. Empty strings clear the
  /// override (palette falls back to the active theme's defaults).
  void _applyChartPalettePatch(Map<dynamic, dynamic> patch) {
    final n = ref.read(chartPaletteProvider.notifier);
    patch.forEach((key, value) {
      if (value is! String) return;
      switch (key) {
        case 'bullBody':     n.setBullBody(value); break;
        case 'bearBody':     n.setBearBody(value); break;
        case 'bullWick':     n.setBullWick(value); break;
        case 'bearWick':     n.setBearWick(value); break;
        case 'background':   n.setBackground(value); break;
        case 'text':         n.setText(value); break;
        case 'grid':         n.setGrid(value); break;
        case 'sessionBreak': n.setSessionBreak(value); break;
        case 'crosshair':    n.setCrosshair(value); break;
      }
    });
  }

  /// Dispatcher for the JS Order Defaults popover's `updateOrderDefaults`
  /// patch messages. Each known field name routes to the matching setter
  /// on [OrderDefaultsNotifier]. Unknown keys are ignored so future JS
  /// builds can ship new fields without breaking older Flutter builds.
  void _applyOrderDefaultsPatch(Map<dynamic, dynamic> patch) {
    final n = ref.read(orderDefaultsProvider.notifier);
    patch.forEach((key, value) {
      switch (key) {
        case 'autoStopLoss':    if (value is bool)   n.setAutoStopLoss(value);     break;
        case 'slType':          if (value is String) n.setSlType(value);            break;
        case 'slTrigger':       if (value is String) n.setSlTrigger(value);         break;
        case 'slTriggerValue':  if (value is num)    n.setSlTriggerValue(value.toDouble()); break;
        case 'trailingSL':      if (value is bool)   n.setTrailingSL(value);        break;
        case 'trailingMove':    if (value is num)    n.setTrailingMove(value.toDouble()); break;
        case 'trailingFor':     if (value is num)    n.setTrailingFor(value.toDouble()); break;
        case 'autoTakeProfit':  if (value is bool)   n.setAutoTakeProfit(value);    break;
        case 'tpType':          if (value is String) n.setTpType(value);            break;
        case 'tpTriggerValue':  if (value is num)    n.setTpTriggerValue(value.toDouble()); break;
        case 'equityDefaultQty':  if (value is num) n.setEquityDefaultQty(value.toInt()); break;
        case 'futuresDefaultQty': if (value is num) n.setFuturesDefaultQty(value.toInt()); break;
        case 'optionsDefaultQty': if (value is num) n.setOptionsDefaultQty(value.toInt()); break;
        case 'equityProduct':   if (value is String) n.setEquityProduct(value);     break;
        case 'futuresProduct':  if (value is String) n.setFuturesProduct(value);    break;
        case 'optionsProduct':  if (value is String) n.setOptionsProduct(value);    break;
      }
    });
  }

  /// Reply path for the JS top bar's INSTANT chip ON click. Shows the
  /// warning-ack dialog when needed; replies `{confirmed: bool}` so the
  /// JS chip knows whether to flip its visual state. JS itself fires the
  /// follow-up `instantOrdersChanged: true` once it sees `confirmed: true`,
  /// which is what actually flips the Riverpod provider — keeping the
  /// "JS owns the chip" invariant clean.
  /// Reply path for the JS Symbol typeahead. Runs the same scrip search the
  /// Flutter typeahead used and replies with `{results: [...]}` where each
  /// row is the JSON shape of a `ScripNewValue` (exch/token/tsym/dname/ls/
  /// ti/instname/symbol). JS renders these directly without re-parsing.
  Future<void> _handleSearchSymbols(String replyId, String q) async {
    final query = q.trim();
    if (query.length < 2) {
      _post(encodeReply(replyId, {'results': const []}));
      return;
    }
    try {
      final resp = await locator<ApiExporter>().searchScripForStrategyBuilder(
        searchText: query,
        exchanges: const ['NSE', 'BSE', 'NFO', 'BFO', 'MCX', 'CDS'],
      );
      if (!mounted) return;
      final rows = (resp.values ?? const [])
          .map((v) => {
                'exch':     v.exch,
                'token':    v.token,
                'tsym':     v.tsym,
                // Prefer the DerivativeMaster decorative name so the JS
                // typeahead shows (and picks) a human-readable contract name;
                // falls back to the trading symbol (tsym) first, then dname,
                // when the contract isn't in the master (indices / equities).
                // Trim the "-EQ" suffix so equities read "TCS" not "TCS-EQ".
                'dname':    (v.masterName ?? v.tsym ?? v.dname)
                    ?.replaceAll('-EQ', ''),
                'symbol':   v.symbol,
                'ls':       v.ls,
                'ti':       v.ti,
                'instname': v.instname,
              })
          .toList();
      _post(encodeReply(replyId, {'results': rows}));
    } catch (e) {
      _post(encodeReply(replyId, {'results': const [], 'error': '$e'}));
    }
  }

  Future<void> _handleConfirmInstantOrders(String replyId) async {
    final session = ref.read(chartEngineSessionProvider);
    bool confirmed = true;
    if (!session.instantWarningAck) {
      final ok = await showInstantWarningDialog(context: context);
      if (!mounted) return;
      confirmed = ok;
      if (ok) {
        ref.read(chartEngineSessionProvider.notifier).markInstantWarningAck();
      }
    }
    _post(encodeReply(replyId, {'confirmed': confirmed}));
  }

  Future<void> _handleFetchHistory(dynamic value) async {
    if (value is! Map) return;
    final requestId = value['requestId'] as String?;
    final exch = value['exch'] as String?;
    final token = value['token'] as String?;
    final tsym = value['tsym'] as String?;
    final interval = value['interval'] as String?;
    final start = (value['start'] as num?)?.toInt();
    final end = (value['end'] as num?)?.toInt();
    if (requestId == null || exch == null || token == null ||
        interval == null || start == null || end == null) {
      return;
    }
    try {
      final candles = <Map<String, dynamic>>[];
      // Kick the in-progress-candle fetch off NOW, in parallel with the
      // history call below, and await it only after history has been parsed.
      // Doing it sequentially would add its latency to the history response,
      // and the engine's onHistoryResult replaces the whole candle array
      // without checking the request id — so a slower response makes it more
      // likely that a stale result for the PREVIOUS symbol lands after a fast
      // symbol switch and overwrites the new one. Parallel keeps the response
      // time (and that race window) as it is today.
      //
      // Only intraday: int.tryParse('1D') is null, so daily/weekly/monthly
      // skip it. Only when the requested window reaches the current candle —
      // scroll-back requests ask for older windows that never contain it.
      final stepSec = (int.tryParse(interval) ?? 0) * 60;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final candleStart = stepSec > 0 ? (nowSec ~/ stepSec) * stepSec : 0;
      final liveFuture = (stepSec > 0 && end >= nowSec - stepSec)
          ? locator<ApiExporter>().getLiveCandle(
              exchange: exch,
              token: token,
              interval: interval,
              candleStartEpoch: candleStart,
            )
          : null;
      // Daily (and anything aggregated from daily — weekly / monthly) uses
      // the EODChartData endpoint; it returns much longer history reliably
      // than tpseries' intraday-tuned 1D path. Intraday (1m / 5m) stays on
      // tpseries.
      if (interval == '1D' && tsym != null && tsym.isNotEmpty) {
        final rows =
            await locator<ApiExporter>().getEODChartDataRange(
          tsym: tsym,
          exch: exch,
          fromEpoch: start,
          toEpoch: end,
        );
        for (final d in rows) {
          candles.add({
            'ts': d.ssboe,
            'o': d.into,
            'h': d.inth,
            'l': d.intl,
            'c': d.intc,
            'v': d.intv,
          });
        }
      } else {
        final resp = await locator<ApiExporter>().getTPSeriesChart(
          exchange: exch,
          token: token,
          interval: interval,
          startEpoch: start,
          endEpoch: end,
        );
        final raw = resp.data ?? const [];
        for (final d in raw) {
          final ts = int.tryParse(d.ssboe ?? '');
          final o = double.tryParse(d.into ?? '');
          final h = double.tryParse(d.inth ?? '');
          final l = double.tryParse(d.intl ?? '');
          final c = double.tryParse(d.intc ?? '');
          final v = double.tryParse(d.intv ?? '') ?? 0;
          if (ts == null || o == null || h == null || l == null || c == null) {
            continue;
          }
          candles.add({'ts': ts, 'o': o, 'h': h, 'l': l, 'c': c, 'v': v});
        }
      }
      // Merge the in-progress candle (started in parallel above). tpseries
      // returns only CLOSED candles, so a chart opened at 10:10:10 arrives
      // missing the 10 seconds already elapsed in the 10:10 candle — a visible
      // gap until the next tick, and that tick can only set the close (the
      // elapsed open/high/low are gone).
      if (liveFuture != null) {
        final live = await liveFuture;
        final ts = int.tryParse(live?.ssboe ?? '');
        final o = double.tryParse(live?.into ?? '');
        final h = double.tryParse(live?.inth ?? '');
        final l = double.tryParse(live?.intl ?? '');
        final c = double.tryParse(live?.intc ?? '');
        if (ts != null && o != null && h != null && l != null && c != null) {
          // Replace rather than append — the closed-candle call may already
          // have returned this slot, and the live copy is the fresher one.
          candles.removeWhere((e) => e['ts'] == ts);
          candles.add({
            'ts': ts,
            'o': o,
            'h': h,
            'l': l,
            'c': c,
            'v': double.tryParse(live?.intv ?? '') ?? 0,
          });
        }
      }
      // Normalize to oldest-first regardless of source.
      candles.sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));
      _post(encodeHistoryResult(requestId, candles));
    } catch (e) {
      _post(encodeHistoryError(requestId, e.toString()));
    }
  }

  /// Re-issue WS subscriptions for every key in `_subscribedKeys`. Used on
  /// reconnect — the WS provider drops `_sentSubscriptions` whenever the
  /// socket resets, so its dedup logic will let these requests through
  /// instead of silently skipping them. OI tokens are re-picked up by the
  /// next periodic option-chain refresh, so they don't need explicit
  /// reattachment here.
  void _resubscribeAll() {
    if (!mounted) return;
    // Popout has no shared socket to re-subscribe; the alternate feed client
    // re-sends its own tracked SubSet on every reconnect ack.
    if (widget.popout) return;
    final ws = ref.read(websocketProvider);
    for (final key in _subscribedKeys) {
      ws.establishConnection(channelInput: key, task: 't', context: context);
      ws.establishConnection(channelInput: key, task: 'd', context: context);
    }
  }

  void _handleSubscribe(dynamic value) {
    if (value is! Map) return;
    final exch = value['exch'] as String?;
    final token = value['token'] as String?;
    if (exch == null || token == null) return;
    if (widget.popout) {
      // Route to the alternate ws.zebull.in feed — the main socket is
      // off-limits in popout. The feed client dedups + primes on ack, so we
      // skip the _subscribedKeys tracking and socketDatas prime below.
      widget.feed?.subscribe(exch, token);
      return;
    }
    final key = '$exch|$token';
    if (_subscribedKeys.contains(key)) return;
    _subscribedKeys.add(key);
    final ws = ref.read(websocketProvider);
    // Touchline ('t') gives lp/v/ft which the candle aggregator needs.
    ws.establishConnection(
      channelInput: key,
      task: 't',
      context: context,
    );
    // Depth ('d') reliably populates bp1/sp1/bq1/sq1 in socketDatas[token].
    // Touchline alone doesn't always carry bid/ask on every broker/exchange,
    // and the bid/ask header strip needs them. Both subs share the same
    // socketDatas entry — fields merge — so the iframe sees both LTP and
    // bid/ask through the existing forwarder.
    ws.establishConnection(
      channelInput: key,
      task: 'd',
      context: context,
    );
    // Phase 18.2 — prime the iframe with whatever the WS already has for
    // this token. The WS listener only fires on FUTURE updates, so a token
    // that the app already had cached (e.g. NIFTY 50 because the watchlist
    // subscribed earlier) would otherwise leave the chart frozen on its
    // historical close until the next real tick. Forward existing fields
    // synchronously.
    final entry = ws.socketDatas[token];
    if (entry is Map) {
      final packet = <String, dynamic>{
        'exch': exch,
        if (entry['lp'] != null) 'lp': entry['lp'],
        if (entry['v'] != null) 'v': entry['v'],
        if (entry['ft'] != null) 'ft': entry['ft'],
        if (entry['bp1'] != null) 'bp1': entry['bp1'],
        if (entry['sp1'] != null) 'sp1': entry['sp1'],
        // Day OHLC from the touchline feed — needed to form TODAY's
        // daily/weekly/monthly bar correctly (EOD history ends yesterday, so
        // the live bar must use the real session open/high/low, not the
        // LTP-at-open). `o`/`h`/`l` are today's; `c` here is the previous close.
        if (entry['o'] != null) 'o': entry['o'],
        if (entry['h'] != null) 'h': entry['h'],
        if (entry['l'] != null) 'l': entry['l'],
        // Previous close + day change / % — the idle chart header shows
        // "LTP  ±change (±%)" for the day while no candle is hovered.
        if (entry['c'] != null) 'c': entry['c'],
        if (entry['chng'] != null) 'chng': entry['chng'],
        if (entry['pc'] != null) 'pc': entry['pc'],
      };
      if (packet.length > 1) _post(encodeTick(token, packet));
    }
  }

  void _handleUnsubscribe(dynamic value) {
    if (value is! Map) return;
    final exch = value['exch'] as String?;
    final token = value['token'] as String?;
    if (exch == null || token == null) return;
    if (widget.popout) {
      widget.feed?.unsubscribe(exch, token);
      return;
    }
    final key = '$exch|$token';
    if (!_subscribedKeys.contains(key)) return;
    // Remove from our forwarding set — the WS listener will stop posting ticks
    // for this token to the iframe. We deliberately do NOT issue 'u' on the
    // underlying WS: the same token may still be needed by other parts of
    // the app (watchlists, holdings, ticker bar) which share the single
    // app-wide subscription. The downside is a tiny per-symbol bandwidth
    // overhead for symbols the chart no longer needs; the WS-level cleanup
    // belongs in WebSubscriptionManager, not us.
    _subscribedKeys.remove(key);
  }

  void _pushAll({bool force = false}) {
    try {
      _pushTheme(force: force);
    } catch (e, st) {
      // ignore: avoid_print
      print('chart-engine _pushTheme error: $e\n$st');
    }
    _pushSession(force: force);
    // Push the persisted customize-tab palette so the iframe boots with
    // the user's saved colours instead of theme defaults.
    if (_iframeReady) {
      try {
        final pal = ref.read(chartPaletteProvider);
        _post(encodeSetChartPalette(pal.toWire()));
      } catch (_) {}
      // Initial sync of the JS top bar's per-control state. Add one line
      // here per migrated control.
      try {
        final session = ref.read(chartEngineSessionProvider);
        _post(encodeSetInstantOrders(session.instantOrders));
        // Layout picker — push the full catalog once + the current id.
        _post(encodeSetLayoutCatalog([
          for (final l in ChartLayout.values)
            {
              'id': l.id,
              'paneCount': l.paneCount,
              'areas': l.areas,
              'rows': l.rows,
              'columns': l.columns,
            },
        ]));
        _post(encodeSetActiveLayoutId(session.layout.id));
        // Order Defaults — initial bag for the JS popover.
        _post(encodeSetOrderDefaults(
            ref.read(orderDefaultsProvider).toJson()));
        // Settings popover — initial bags for View / Customize / shortcuts.
        _post(encodeSetActivePaneViewState(_activePaneViewBag()));
        _post(encodeSetKeyboardShortcutsState(session.keyboardShortcuts));
        _post(encodeSetChartPaletteState(
            _chartPaletteBag(ref.read(chartPaletteProvider))));
        // Symbol typeahead — current active pane scrip.
        if (session.panes.isNotEmpty) {
          final scrip = session.active.scrip;
          _post(encodeSetActivePaneSymbol(scrip?.toJson()));
        }
        // Per-pane (active pane) top-bar state for Timeframe + Style +
        // Cursor mode + Indicators.
        if (session.panes.isNotEmpty) {
          final p = session.active;
          _post(encodeSetActivePaneTopBarState(
            timeframeMinutes: p.timeframeMinutes,
            candleStyle: p.candleStyle,
            showCrosshairLines: p.showCrosshairLines,
            indicators: [for (final i in p.indicators) i.toJson()],
          ));
        }
      } catch (_) {}
    }
  }

  void _pushTheme({bool force = false}) {
    if (!_iframeReady) return;
    final theme = _currentThemeName();
    if (!force && theme == _pushedTheme) return;
    _pushedTheme = theme;
    _post(encodeSetTheme(theme));
  }

  void _pushSession({bool force = false}) {
    if (!_iframeReady) return;
    try {
      _pushSessionInner(force: force);
    } catch (e, st) {
      // Defensive: never let a transient state inconsistency (e.g. a position
      // closed mid-tick, scrip becoming null, overlay payload serialisation
      // failing) bubble into the Flutter render tree and white-screen the
      // chart. Log to console and skip this push; next tick retries.
      // ignore: avoid_print
      print('chart-engine _pushSession error: $e\n$st');
    }
  }

  void _pushSessionInner({bool force = false}) {
    final session = ref.read(chartEngineSessionProvider);

    // Layout — push first so the iframe creates the panes before per-pane
    // state arrives.
    if (force || session.layout.id != _pushedLayoutId) {
      _pushedLayoutId = session.layout.id;
      _post(encodeSetLayout(
        id: session.layout.id,
        areas: session.layout.areas,
        rows: session.layout.rows,
        columns: session.layout.columns,
        paneCount: session.layout.paneCount,
      ));
      // Layout change recreates panes — invalidate per-pane cache.
      _pushedSymbolKey.clear();
      _pushedTradableKey.clear();
      _pushedTimeframe.clear();
      _pushedOverlaysJson.clear();
      _pushedPaneOverlaysJson.clear();
      _pushedQty.clear();
      _pushedDrawingsJson.clear();
      _pushedIndicatorsJson.clear();
      _pushedCandleStyle.clear();
      _pushedShowHighLowMarkers.clear();
      _pushedShowOptionChainOi.clear();
      _pushedShowBarCountdown.clear();
      _pushedOiDataJson.clear();
      _pushedShowKeyLevels.clear();
      _pushedPivotVariant.clear();
      _pushedMagnetEnabled.clear();
      _pushedShowVolumeProfile.clear();
      _pushedShowAutoPattern.clear();
      _pushedShowCrosshairLines.clear();
    }

    // Per-pane state.
    for (var i = 0; i < session.panes.length; i++) {
      final pane = session.panes[i];
      if (pane.scrip != null) {
        final key = '${pane.scrip!.exch}|${pane.scrip!.token}';
        if (force || _pushedSymbolKey[i] != key) {
          _pushedSymbolKey[i] = key;
          _post(encodeSetPaneSymbol(i.toString(), pane.scrip!.toJson()));
          // Symbol changed → previous tradable result is stale.
          _pushedTradableKey.remove(i);
          // Symbol changed → the chart wiped its OI (setSymbol → _resetData),
          // and the OI for the new symbol hasn't been re-fetched yet. Drop the
          // OI dedup so the new symbol's strikes are guaranteed to re-push once
          // fetched, instead of being suppressed as "unchanged".
          _pushedOiDataJson.remove(i);
          // Prefetch the full ScripInfoModel so PlaceOrderScreen has real
          // quote data when the user later opens the order popup. Cached
          // in marketWatchProvider.storeQuotes so this is a cheap no-op on
          // repeat pushes for the same symbol. Also drives the
          // setScripTradable push via _pushTradableFromInfo.
          _prefetchScripInfo(i, pane.scrip!);
        }
      }
      if (force || _pushedTimeframe[i] != pane.timeframeMinutes) {
        _pushedTimeframe[i] = pane.timeframeMinutes;
        _post(encodeSetPaneTimeframe(i.toString(), pane.timeframeMinutes));
      }
      final overlaysJson = jsonEncode(pane.overlays.toJson());
      if (force || _pushedOverlaysJson[i] != overlaysJson) {
        _pushedOverlaysJson[i] = overlaysJson;
        _post(encodeSetOverlays(i.toString(), pane.overlays.toJson()));
      }
      if (force || _pushedQty[i] != pane.qty) {
        _pushedQty[i] = pane.qty;
        _post(encodeSetPaneQty(i.toString(), pane.qty));
      }
      if (force || _pushedCandleStyle[i] != pane.candleStyle) {
        _pushedCandleStyle[i] = pane.candleStyle;
        _post(encodeSetPaneCandleStyle(i.toString(), pane.candleStyle));
      }
      if (force || _pushedShowHighLowMarkers[i] != pane.showHighLowMarkers) {
        _pushedShowHighLowMarkers[i] = pane.showHighLowMarkers;
        _post(encodeSetPaneHighLowMarkers(
            i.toString(), pane.showHighLowMarkers));
      }
      // Phase 18 — OI toggle + bar-countdown toggle.
      if (force || _pushedShowOptionChainOi[i] != pane.showOptionChainOi) {
        _pushedShowOptionChainOi[i] = pane.showOptionChainOi;
        _post(encodeSetPaneShowOptionChainOi(
            i.toString(), pane.showOptionChainOi));
      }
      if (force || _pushedShowBarCountdown[i] != pane.showBarCountdown) {
        _pushedShowBarCountdown[i] = pane.showBarCountdown;
        _post(encodeSetPaneShowBarCountdown(
            i.toString(), pane.showBarCountdown));
      }
      // Phase 20 — key-levels toggle.
      if (force || _pushedShowKeyLevels[i] != pane.showKeyLevels) {
        _pushedShowKeyLevels[i] = pane.showKeyLevels;
        _post(encodeSetPaneShowKeyLevels(
            i.toString(), pane.showKeyLevels));
      }
      // Phase 23 — pivot variant, magnet, volume profile, multi-TF minutes.
      if (force || _pushedPivotVariant[i] != pane.pivotVariant) {
        _pushedPivotVariant[i] = pane.pivotVariant;
        _post(encodeSetPanePivotVariant(i.toString(), pane.pivotVariant));
      }
      if (force || _pushedMagnetEnabled[i] != pane.magnetEnabled) {
        _pushedMagnetEnabled[i] = pane.magnetEnabled;
        _post(encodeSetPaneMagnetEnabled(i.toString(), pane.magnetEnabled));
      }
      if (force || _pushedShowVolumeProfile[i] != pane.showVolumeProfile) {
        _pushedShowVolumeProfile[i] = pane.showVolumeProfile;
        _post(encodeSetPaneShowVolumeProfile(
            i.toString(), pane.showVolumeProfile));
      }
      // Phase 25 — auto-pattern (HH/HL/LH/LL) toggle.
      if (force || _pushedShowAutoPattern[i] != pane.showAutoPattern) {
        _pushedShowAutoPattern[i] = pane.showAutoPattern;
        _post(encodeSetPaneShowAutoPattern(
            i.toString(), pane.showAutoPattern));
      }
      // Crosshair lines toggle — defaults true, gates only the dashed lines.
      if (force ||
          _pushedShowCrosshairLines[i] != pane.showCrosshairLines) {
        _pushedShowCrosshairLines[i] = pane.showCrosshairLines;
        _post(encodeSetPaneShowCrosshairLines(
            i.toString(), pane.showCrosshairLines));
      }
    }

    // Per-pane position/order overlays.
    final positions =
        ref.read(portfolioProvider).postionBookModel ?? const [];
    final orders = ref.read(orderProvider).orderBookModel ?? const [];
    final alerts =
        ref.read(marketWatchProvider).alertPendingModel ?? const [];
    final ocoOrders =
        ref.read(orderProvider).gttOrderBookModel ?? const [];
    for (var i = 0; i < session.panes.length; i++) {
      final pane = session.panes[i];
      final overlays = overlaysForPane(
        scrip: pane.scrip,
        positions: positions,
        orders: orders,
        alerts: alerts,
        ocoOrders: ocoOrders,
      );
      final json = jsonEncode(overlays);
      if (force || _pushedPaneOverlaysJson[i] != json) {
        _pushedPaneOverlaysJson[i] = json;
        _post(encodeSetPaneOverlays(i.toString(), overlays));
      }
    }

    // Phase 7 — per-pane drawings. Look up the per-scrip list and push the
    // resolved drawings to each pane independently so two panes showing the
    // same scrip both render the same set.
    for (var i = 0; i < session.panes.length; i++) {
      final scrip = session.panes[i].scrip;
      final scripKey = scrip == null ? null : '${scrip.exch}|${scrip.token}';
      final drawings = scripKey == null
          ? const <ChartDrawing>[]
          : (session.drawings[scripKey] ?? const <ChartDrawing>[]);
      final payload = [for (final d in drawings) d.toJson()];
      final drawingsJson = jsonEncode(payload);
      if (force || _pushedDrawingsJson[i] != drawingsJson) {
        _pushedDrawingsJson[i] = drawingsJson;
        _post(encodeSetPaneDrawings(i.toString(), payload));
      }
    }

    // Phase 8 — per-pane technical indicators. Pushed independently of
    // drawings so a symbol change (which clears drawings) leaves the
    // indicator list intact.
    for (var i = 0; i < session.panes.length; i++) {
      final pane = session.panes[i];
      final payload = [for (final ind in pane.indicators) ind.toJson()];
      final indicatorsJson = jsonEncode(payload);
      if (force || _pushedIndicatorsJson[i] != indicatorsJson) {
        _pushedIndicatorsJson[i] = indicatorsJson;
        _post(encodeSetPaneIndicators(i.toString(), payload));
      }
    }

    // Phase 18 — per-pane OI strikes. Reads from chartOiDataProvider, which is
    // populated by the periodic OI fetch loop (`_maybeFetchOptionChain`).
    final oiData = ref.read(chartOiDataProvider);
    for (var i = 0; i < session.panes.length; i++) {
      final strikes = oiData.byPane[i] ?? const <ChartOiStrike>[];
      final payload = [for (final s in strikes) s.toJson()];
      final json = jsonEncode(payload);
      if (force || _pushedOiDataJson[i] != json) {
        _pushedOiDataJson[i] = json;
        _post(encodeSetPaneOiData(i.toString(), payload));
      }
    }

    // Phase 7 — global draw mode. Broadcasts to all panes via chart-engine.js.
    final tool = session.activeDrawTool;
    if (force || !_hasPushedDrawTool || _pushedDrawTool != tool) {
      _pushedDrawTool = tool;
      _hasPushedDrawTool = true;
      _post(encodeSetDrawMode(tool));
    }

    // Phase 14.1 — push keyboard-shortcuts toggle.
    final shortcuts = session.keyboardShortcuts;
    if (force || _pushedShortcutsEnabled != shortcuts) {
      _pushedShortcutsEnabled = shortcuts;
      _post(encodeSetShortcutsEnabled(shortcuts));
    }

    // Active pane highlight.
    final activeId = session.activePaneIndex.toString();
    if (force || _pushedActivePaneId != activeId) {
      _pushedActivePaneId = activeId;
      _post(encodeSetActivePane(activeId));
    }

    // Phase 23 — session-level drawings lock/hide. Pushed after per-pane loop.
    if (force || _pushedDrawingsLocked != session.drawingsLocked) {
      _pushedDrawingsLocked = session.drawingsLocked;
      _post(encodeSetDrawingsLocked(session.drawingsLocked));
    }
    if (force || _pushedDrawingsHidden != session.drawingsHidden) {
      _pushedDrawingsHidden = session.drawingsHidden;
      _post(encodeSetDrawingsHidden(session.drawingsHidden));
    }

    // Kick the OI fetch loop synchronously after every push so a
    // just-toggled "Show option-chain OI" doesn't wait up to 5s for the next
    // periodic tick. The fetcher's own freshness gate prevents spam.
    _maybeFetchOptionChain(null);
  }

  void _showOverlayDetail(
      int paneIndex, String overlayId, double iframeX, double iframeY) {
    _dismissOverlayDetail();
    final session = ref.read(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) return;
    final scrip = session.panes[paneIndex].scrip;
    if (scrip == null) return;

    // Resolve overlayId back to a source object.
    // Note: `optStrike-` overlays (Phase 17.A — option position surfaced on
    // the underlying chart) have no detail popup. Tapping the chip body is a
    // silent no-op; only the close × is meaningful and is routed via
    // `_handleOverlayCloseRequested`. Leaving them to fall through the
    // `else` branch returns no match and exits cleanly — no special-case
    // needed here, but don't "clean up" by adding one expecting a popup.
    OverlayDetailData? data;
    if (overlayId.startsWith('pos-')) {
      final positions =
          ref.read(portfolioProvider).postionBookModel ?? const [];
      for (final p in positions) {
        if (p.exch == scrip.exch &&
            p.token == scrip.token &&
            (int.tryParse(p.netqty ?? '0') ?? 0) != 0) {
          data = OverlayDetailData.position(p);
          break;
        }
      }
    } else {
      final id = overlayId.replaceFirst(RegExp(r'^(ord|sl-l|sl)-'), '');
      final orders = ref.read(orderProvider).orderBookModel ?? const [];
      for (final o in orders) {
        if (o.norenordno == id) {
          data = OverlayDetailData.order(o);
          break;
        }
      }
    }
    if (data == null) return;

    // Convert iframe-local coords to app coords using the iframe's rect.
    final el = html.document.getElementById(_iframeId);
    double iframeLeft = 0;
    double iframeTop = 0;
    if (el is html.IFrameElement) {
      final r = el.getBoundingClientRect();
      iframeLeft = r.left.toDouble();
      iframeTop = r.top.toDouble();
    }
    final anchor = Offset(iframeLeft + iframeX + 12, iframeTop + iframeY + 12);

    final resolved = data;
    _overlayDetailEntry = OverlayEntry(
      builder: (_) => OverlayDetailPopup(
        anchor: anchor,
        data: resolved,
        onDismiss: _dismissOverlayDetail,
      ),
    );
    Overlay.of(context).insert(_overlayDetailEntry!);
  }

  void _dismissOverlayDetail() {
    _overlayDetailEntry?.remove();
    _overlayDetailEntry = null;
  }

  int? _pinnedCrosshairPane;

  void _dismissAllPopups() {
    _dismissOverlayDetail();
    _qtyPopupEntry?.remove(); _qtyPopupEntry = null;
    if (_plusMenuEntry != null) {
      _plusMenuEntry!.remove();
      _plusMenuEntry = null;
      // If a `+` popup was open the iframe still has a pinned crosshair —
      // release it now so the user sees the live crosshair again.
      if (_pinnedCrosshairPane != null && _iframeReady) {
        _post(encodeUnpinCrosshair(_pinnedCrosshairPane.toString()));
      }
      _pinnedCrosshairPane = null;
    }
  }

  Offset _iframeToApp(double clientX, double clientY) {
    final el = html.document.getElementById(_iframeId);
    if (el is! html.IFrameElement) return Offset(clientX, clientY);
    final r = el.getBoundingClientRect();
    return Offset(r.left.toDouble() + clientX + 4,
        r.top.toDouble() + clientY + 4);
  }

  /// Fire-and-forget GetSecurityInfo lookup for `nontrd`. Pushes the
  /// resulting tradable boolean to the iframe so non-tradable scrips
  /// (indices, commodity spot) lose their bid/ask quote, `+` order icon,
  /// and Alt+B/S shortcut. Cache-aware via `_tradableCache`. Failures are
  /// silent — chart defaults to tradable until the API responds.
  void _prefetchScripInfo(int paneIndex, ChartScrip scrip) {
    final key = '${scrip.exch}|${scrip.token}';
    final cached = _tradableCache[key];
    if (cached != null) {
      _pushTradable(paneIndex, key, cached);
      // Re-apply the cached lot/tick metadata so the qty self-heals on EVERY
      // switch back to this symbol, not just the first time. (This used to
      // early-return, skipping the backfill — so a futures/commodity
      // re-selected with a lot-less scrip kept qty=1 and got rejected.)
      final meta = _scripMetaCache[key];
      if (meta != null &&
          ((meta.ls != null && meta.ls! > 0) ||
              (meta.ti != null && meta.ti! > 0))) {
        ref
            .read(chartEngineSessionProvider.notifier)
            .backfillPaneScripMetadata(paneIndex, ls: meta.ls, ti: meta.ti);
        // Also correct the ENGINE's copy of the tick (setPaneSymbol seeded it
        // once and won't re-push) so the axis/snap tick matches ChartScrip.ti.
        _post(encodeSetScripMeta('$paneIndex', ti: meta.ti, ls: meta.ls));
      }
      return;
    }
    // Call the API directly. GetSecurityInfo reports tradable status via
    // the `nontrd` key: absent → tradable, "1" → non-tradable
    // (indices, commodity spot, etc).
    final api = locator<ApiExporter>();
    // ignore: discarded_futures
    api.getScripInfo(scrip.token, scrip.exch).then((info) {
      if (!mounted) return;
      if (info.stat != 'Ok') return;
      final tradable = info.nontrd != '1';
      _tradableCache[key] = tradable;
      _pushTradable(paneIndex, key, tradable);
      // Backfill lot size + tick size. Several entry paths (EmbeddedChartView,
      // raw search picks, some watchlist rows missing `ls`) land with the
      // conservative ls=1/ti=0.05 defaults; without this the qty stays
      // at 1 even for option/future contracts.
      final lotSize = int.tryParse(info.ls ?? '');
      final tickSize = double.tryParse(info.ti ?? '');
      final freezeQty = int.tryParse(info.frzqty ?? '');
      _scripMetaCache[key] = (ls: lotSize, ti: tickSize, frz: freezeQty);
      if ((lotSize != null && lotSize > 0) ||
          (tickSize != null && tickSize > 0)) {
        ref
            .read(chartEngineSessionProvider.notifier)
            .backfillPaneScripMetadata(paneIndex,
                ls: lotSize, ti: tickSize);
        // Also correct the ENGINE's copy of the tick (setPaneSymbol seeded it
        // once and won't re-push) so the axis/snap tick matches ChartScrip.ti.
        _post(encodeSetScripMeta('$paneIndex', ti: tickSize, ls: lotSize));
      }
    }).catchError((_) {});
  }

  /// Freeze quantity (in units) for a scrip, from the GetSecurityInfo cache,
  /// fetched on demand if not already known. Returns 0 when unknown (caller
  /// then skips slicing and places a single order). Used by instant orders to
  /// split large quantities into freeze-qty-bounded child orders.
  Future<int> _freezeQtyFor(ChartScrip scrip) async {
    final key = '${scrip.exch}|${scrip.token}';
    final cached = _scripMetaCache[key];
    if (cached != null && cached.frz != null && cached.frz! > 0) {
      return cached.frz!;
    }
    try {
      final info = await locator<ApiExporter>().getScripInfo(
          scrip.token, scrip.exch);
      if (info.stat == 'Ok') {
        final frz = int.tryParse(info.frzqty ?? '');
        final ls = int.tryParse(info.ls ?? '');
        final ti = double.tryParse(info.ti ?? '');
        _scripMetaCache[key] = (ls: ls, ti: ti, frz: frz);
        if (frz != null && frz > 0) return frz;
      }
    } catch (_) {}
    return 0;
  }

  void _pushTradable(int paneIndex, String key, bool tradable) {
    if (_pushedTradableKey[paneIndex] == key) return;
    _pushedTradableKey[paneIndex] = key;
    _post(encodeSetScripTradable(paneIndex.toString(), tradable));
  }

  ScripInfoModel? _cachedScripInfo(ChartScrip scrip) {
    final s = ref.read(marketWatchProvider).storeQuotes[scrip.token]?['s'];
    return s is ScripInfoModel ? s : null;
  }

  Future<void> _openPlaceOrderScreen({
    required ChartScrip scrip,
    required int qty,
    required OrderPrefillKind kind,
    double? price,
    int? paneIndex,
  }) async {
    final session = ref.read(chartEngineSessionProvider);

    // Phase 15 — when the caller knows which pane initiated the request, use
    // the per-pane effective instant flag. Callers that don't supply a pane
    // index (back-compat) fall back to the session-level global.
    final bool effectiveInstant = paneIndex == null
        ? session.instantOrders
        : session.effectiveInstantFor(paneIndex);

    // INSTANT MODE: skip the screen for non-blank kinds and place directly.
    if (effectiveInstant &&
        kind != OrderPrefillKind.blank &&
        price != null) {
      // ── Circuit / trigger validation (parity with PlaceOrderScreenWeb) ─────
      // The instant path used to fire straight to the API with NO circuit/LTP/
      // trigger checks. Gate it exactly like the regular order screen; block +
      // toast on any violation. Fetch scrip info once if not already cached so
      // the circuit band is available.
      var vInfo = _cachedScripInfo(scrip);
      if (vInfo == null) {
        try {
          await ref
              .read(marketWatchProvider)
              .fetchScripInfo(scrip.token, scrip.exch, context, false);
        } catch (_) {}
        if (!mounted) return;
        vInfo = _cachedScripInfo(scrip) ??
            ref.read(marketWatchProvider).scripInfoModel;
      }
      final isBuyKind = kind == OrderPrefillKind.buyLimit ||
          kind == OrderPrefillKind.buyStopMkt ||
          kind == OrderPrefillKind.buyStopLmt;
      final isSlMktKind = kind == OrderPrefillKind.buyStopMkt ||
          kind == OrderPrefillKind.sellStopMkt;
      final isSlLmtKind = kind == OrderPrefillKind.buyStopLmt ||
          kind == OrderPrefillKind.sellStopLmt;
      final vPrctype = isSlMktKind
          ? 'SL-MKT'
          : (isSlLmtKind ? 'SL-LMT' : 'LMT');
      // For SL orders the click price is the TRIGGER; the SL-LMT limit is
      // trigger ± ti (identical to buildPlaceOrderInput). Plain limit uses price.
      final vTrigger = (isSlMktKind || isSlLmtKind) ? price : null;
      final vLimit = isSlMktKind
          ? null
          : (isSlLmtKind
              ? (isBuyKind ? price + scrip.ti : price - scrip.ti)
              : price);
      final vErr = validateChartOrder(
        isBuy: isBuyKind,
        prctype: vPrctype,
        price: vLimit,
        trigger: vTrigger,
        uc: vInfo?.uc,
        lc: vInfo?.lc,
        ltp: _currentSpotLtp(scrip),
      );
      if (vErr != null) {
        ResponsiveSnackBar.showWarning(context, vErr);
        return;
      }

      final deviceInfo = ref.read(authProvider).deviceInfo;
      final defaults = ref.read(orderDefaultsProvider);
      // Freeze-qty slicing: the exchange rejects an order whose quantity
      // exceeds the instrument's freeze qty unless it is split into child
      // orders of <= freeze qty. The normal popup path already slices; instant
      // mode must do the same headlessly. Per-slice qty is lot-aligned and
      // bounded by the freeze qty (same formula the popup uses).
      final lot = scrip.ls > 0 ? scrip.ls : 1;
      final freeze = await _freezeQtyFor(scrip);
      if (!mounted) return;
      int perSlice = freeze > 1 ? (freeze ~/ lot) * lot : 0;
      if (perSlice < lot) perSlice = lot;
      if (freeze > 0 && qty > perSlice) {
        final full = qty ~/ perSlice;
        final rem = qty % perSlice;
        final sliceCount = full + (rem > 0 ? 1 : 0);
        final maxSlices = ref.read(orderProvider).frezQtyOrderSliceMaxLimit;
        if (sliceCount > maxSlices) {
          ResponsiveSnackBar.showWarning(
              context,
              'Order needs $sliceCount slices (max $maxSlices). '
              'Reduce quantity or use the order window.');
          return;
        }
        final sliceQtys = <int>[
          for (var i = 0; i < full; i++) perSlice,
          if (rem > 0) rem,
        ];
        final inputs = [
          for (final q in sliceQtys)
            buildPlaceOrderInput(
              scrip: scrip,
              qty: q,
              kind: kind,
              price: price,
              deviceInfo: deviceInfo,
              orderDefaults: defaults,
            ),
        ];
        await ref.read(orderProvider).placeInstantSlices(context, inputs);
        return;
      }
      final input = buildPlaceOrderInput(
        scrip: scrip,
        qty: qty,
        kind: kind,
        price: price,
        deviceInfo: deviceInfo,
        // Honor the user's Product Type default (intraday/delivery/normal)
        // instead of always firing CNC/NRML.
        orderDefaults: defaults,
      );
      await ref.read(orderProvider).fetchPlaceOrder(context, input, false);
      return;
    }

    var realInfo = _cachedScripInfo(scrip);
    if (realInfo == null) {
      // Cache miss — fetch synchronously before opening so the screen has
      // real quote data on first render.
      try {
        await ref
            .read(marketWatchProvider)
            .fetchScripInfo(scrip.token, scrip.exch, context, false);
      } catch (_) {
        // ignore; fall through with realInfo = null → synthetic fallback
      }
      if (!mounted) return;
      realInfo = _cachedScripInfo(scrip) ??
          ref.read(marketWatchProvider).scripInfoModel;
    }
    // Point the shared `getQuotes` at THIS scrip before opening, mirroring the
    // watchlist Buy path (fetchScripInfo + fetchScripQuote). The order popup's
    // Market-Info panel dereferences `marketWatchProvider.getQuotes!` for its
    // base quote + static fields, and overlays live O/H/L/Bid/Ask/Vol from
    // `socketDatas[token]` — which the chart already populates via its own
    // pane subscription (_handleSubscribe subscribes both 't' and 'd'). The
    // missing piece was this getQuotes fetch, so F&O popups showed 0s. It is a
    // pure data fetch (no WS subscribe/unsubscribe) so it can't disturb the
    // chart's iframe subscription, and it's cheap when the quote is cached.
    try {
      await ref
          .read(marketWatchProvider)
          .fetchScripQuote(scrip.token, scrip.exch, context);
    } catch (_) {
      // Best-effort; the popup still opens with static/prefill data.
    }
    if (!mounted) return;
    final args = buildOrderScreenArgs(
      scrip: scrip,
      qty: qty,
      kind: kind,
      price: price,
      realScripInfo: realInfo,
      // Real live LTP so the screen validates the trigger against the actual
      // last-traded price (not the order's own price) and shows it correctly.
      liveLtp: _currentSpotLtp(scrip),
      // Drives the Bracket-Order pre-fill when the user has auto-SL + TP on.
      orderDefaults: ref.read(orderDefaultsProvider),
    );
    await ResponsiveNavigation.toPlaceOrderScreen(
        context: context, arguments: args);
  }

  void _openQtyPopup(int paneIdx, double cx, double cy) {
    _dismissAllPopups();
    final session = ref.read(chartEngineSessionProvider);
    if (paneIdx < 0 || paneIdx >= session.panes.length) return;
    final pane = session.panes[paneIdx];
    final scrip = pane.scrip;
    if (scrip == null) return;
    final key = '${scrip.exch}|${scrip.token}';
    final anchor = _iframeToApp(cx, cy);

    _qtyPopupEntry = OverlayEntry(
      builder: (_) => QtySelectorPopup(
        anchor: anchor,
        initialQty: pane.qty,
        lotSize: scrip.ls > 0 ? scrip.ls : 1,
        lastUsed: _lastQtyByScrip[key],
        onCommit: (q) {
          ref.read(chartEngineSessionProvider.notifier).setPaneQty(paneIdx, q);
          _lastQtyByScrip[key] = q;
        },
        onDismiss: () { _qtyPopupEntry?.remove(); _qtyPopupEntry = null; },
      ),
    );
    Overlay.of(context).insert(_qtyPopupEntry!);
  }

  void _openPlusMenu(int paneIdx, double price, double cx, double cy) {
    _dismissAllPopups();
    final session = ref.read(chartEngineSessionProvider);
    if (paneIdx < 0 || paneIdx >= session.panes.length) return;
    final pane = session.panes[paneIdx];
    final scrip = pane.scrip;
    if (scrip == null) return;
    final anchor = _iframeToApp(cx, cy);

    _pinnedCrosshairPane = paneIdx;

    void closeMenu() {
      _plusMenuEntry?.remove();
      _plusMenuEntry = null;
      // Tell the iframe to release its pinned crosshair so the next hover
      // tick goes back to live crosshair behavior.
      _post(encodeUnpinCrosshair(paneIdx.toString()));
      _pinnedCrosshairPane = null;
    }

    // Live LTP for buy-side / sell-side menu branching. Prefer the
    // websocket cache (most recent tick) over the model snapshot.
    final wsEntry = ref.read(websocketProvider).socketDatas[scrip.token];
    double? liveLtp;
    if (wsEntry is Map) {
      final raw = wsEntry['lp'] ?? wsEntry['ltp'];
      liveLtp = raw is num ? raw.toDouble() : double.tryParse('$raw');
    }
    _plusMenuEntry = OverlayEntry(
      builder: (_) => PlusMenuPopup(
        anchor: anchor,
        symbol: scrip.tsym,
        qty: pane.qty,
        price: price,
        ti: scrip.ti,
        ltp: liveLtp,
        onPick: (kind) {
          closeMenu();
          _openPlaceOrderScreen(
            scrip: scrip,
            qty: pane.qty,
            kind: kind,
            price: kind == OrderPrefillKind.blank ? null : price,
            paneIndex: paneIdx,
          );
        },
        onSetAlert: () {
          closeMenu();
          _handleAlertSetRequested(paneIdx, price);
        },
        onDismiss: closeMenu,
      ),
    );
    Overlay.of(context).insert(_plusMenuEntry!);
  }

  /// Re-push the current (unchanged) overlays for [paneIndex] so a REJECTED
  /// drag snaps the line back to its stored price — the JS holds the dragged
  /// line optimistically (`_pendingOverlayMoves`) until an overlay push
  /// overwrites it.
  void _snapBackOverlays(int paneIndex) {
    final session = ref.read(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) return;
    _post(encodeSetOverlays(
        paneIndex.toString(), session.panes[paneIndex].overlays.toJson()));
  }

  void _handleOverlayDragEnded(int paneIndex, String overlayId, double newPrice) {
    final session = ref.read(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) return;
    final scrip = session.panes[paneIndex].scrip;
    if (scrip == null) return;

    // Alert line drag → ModifyAlert with the new price, keeping the same
    // condition (ai_t). fetchmodifyalert refreshes the pending list + toasts
    // and does NOT Navigator.pop, so it's safe from the chart. The optimistic
    // _pendingOverlayMoves in JS holds the line until the refresh re-pushes it.
    if (overlayId.startsWith('alert-')) {
      final alId = overlayId.substring('alert-'.length);
      final alerts =
          ref.read(marketWatchProvider).alertPendingModel ?? const [];
      AlertPendingModel? alert;
      for (final a in alerts) {
        if (a.alId == alId) { alert = a; break; }
      }
      if (alert == null) return;
      // ignore: discarded_futures
      ref.read(marketWatchProvider).fetchmodifyalert(
            alert.exch ?? '',
            alert.tsym ?? '',
            newPrice.toStringAsFixed(2),
            alert.aiT ?? '',
            alert.alId ?? '',
            context,
          );
      return;
    }

    // OCO bracket legs (ocoTp-<alId> / ocoSl-<alId>) — drag modifies a single
    // leg via ModifyOCO, replaying the other leg untouched.
    if (overlayId.startsWith('ocoTp-') || overlayId.startsWith('ocoSl-')) {
      final isTp = overlayId.startsWith('ocoTp-');
      final alId = overlayId.substring(isTp ? 'ocoTp-'.length : 'ocoSl-'.length);
      final gtt = _findOcoByAlId(alId);
      if (gtt == null) return;
      // ── Validate the dragged leg BEFORE the confirm (circuit + LTP-direction).
      // The OCO's exit side gives the position direction: exit SELL → long
      // (Target above LTP, Stop below), exit BUY → short (mirrored). Dragging a
      // long's Target below the LTP used to be wrongly accepted; block + snap.
      final exitTrantype = gtt.placeOrderParams?.trantype ??
          gtt.placeOrderParamsLeg2?.trantype ??
          gtt.trantype ??
          'S';
      final legInfo = _cachedScripInfo(scrip);
      final legErr = validateChartOcoLeg(
        isTp: isTp,
        isLong: exitTrantype == 'S',
        price: newPrice,
        uc: legInfo?.uc,
        lc: legInfo?.lc,
        ltp: _currentSpotLtp(scrip),
      );
      if (legErr != null) {
        ResponsiveSnackBar.showWarning(context, legErr);
        _snapBackOverlays(paneIndex);
        return;
      }
      // ignore: discarded_futures
      showOcoLegModifyDialog(
        context: context,
        ref: ref,
        gtt: gtt,
        isTpLeg: isTp,
        newPrice: newPrice,
      );
      return;
    }

    // Resolve overlayId → underlying OrderBookModel. IDs are prefixed:
    //   ord-<num>   → LMT
    //   sl-<num>    → SL-MKT or SL-LMT (trigger)
    //   sl-l-<num>  → SL-LMT (limit only)
    String? kindPrefix;
    String? orderNum;
    if (overlayId.startsWith('sl-l-')) {
      kindPrefix = 'sl-l';
      orderNum = overlayId.substring('sl-l-'.length);
    } else if (overlayId.startsWith('ord-')) {
      kindPrefix = 'ord';
      orderNum = overlayId.substring('ord-'.length);
    } else if (overlayId.startsWith('sl-')) {
      kindPrefix = 'sl';
      orderNum = overlayId.substring('sl-'.length);
    }
    if (orderNum == null) return;

    final orders = ref.read(orderProvider).orderBookModel ?? const [];
    OrderBookModel? order;
    for (final o in orders) {
      if (o.norenordno == orderNum) { order = o; break; }
    }
    if (order == null) return;

    // For SL-LMT trigger drag, preserve the limit/trigger offset.
    double? newTrigger;
    double finalNewPrice = newPrice;
    if (kindPrefix == 'sl' && order.prctyp == 'SL-LMT') {
      // Dragging the TRIGGER line of an SL-LMT — move ONLY the trigger; keep
      // the limit (`prc`) where it was so the other (sl-l) line stays put.
      newTrigger = newPrice;
      finalNewPrice = double.tryParse(order.prc ?? '0') ?? newPrice;
    } else if (kindPrefix == 'sl-l' && order.prctyp == 'SL-LMT') {
      // Dragging the LIMIT line — move ONLY the limit; keep the original
      // trigger so the sl (trigger) line stays put.
      newTrigger = double.tryParse(order.trgprc ?? '0') ?? newPrice;
      finalNewPrice = newPrice;
    } else if (kindPrefix == 'sl' && order.prctyp == 'SL-MKT') {
      // SL-MKT: only trgprc changes.
      newTrigger = newPrice;
      // finalNewPrice is unused on the server for SL-MKT but the input still
      // requires `prc`; copy the existing.
      finalNewPrice = double.tryParse(order.prc ?? '0') ?? 0;
    }
    // kindPrefix == 'ord' (LMT): only `prc` changes; newTrigger stays null →
    // ModifyOrderInput.trgprc falls back to prc.

    // ── Circuit / trigger validation (parity with PlaceOrderScreenWeb) ────────
    // Gate the dragged value exactly like the order screen; on violation toast
    // + snap the line back (re-push overlays) and send NO modify. Applies to
    // BOTH the instant and confirm paths below.
    final dragInfo = _cachedScripInfo(scrip);
    final dragErr = validateChartOrder(
      isBuy: order.trantype == 'B',
      prctype: order.prctyp ?? '',
      price: finalNewPrice,
      trigger: newTrigger,
      uc: dragInfo?.uc,
      lc: dragInfo?.lc,
      ltp: _currentSpotLtp(scrip),
    );
    if (dragErr != null) {
      ResponsiveSnackBar.showWarning(context, dragErr);
      _snapBackOverlays(paneIndex);
      return;
    }

    if (session.effectiveInstantFor(paneIndex)) {
      // Same ModifyOrderInput construction as showModifyOrderDialog.
      final input = ModifyOrderInput(
        exch: order.exch ?? '',
        token: order.token ?? '',
        tsym: order.tsym ?? '',
        orderNum: order.norenordno ?? '',
        qty: order.qty ?? '0',
        dscqty: order.dscqty ?? '0',
        mktProt: order.mktProtection ?? '',
        prctyp: order.prctyp ?? '',
        prd: order.prd ?? '',
        trantype: order.trantype ?? '',
        ret: order.ret ?? 'DAY',
        blprc: order.blprc ?? '',
        bpprc: order.bpprc ?? '',
        prc: finalNewPrice.toStringAsFixed(2),
        trgprc: (newTrigger ?? finalNewPrice).toStringAsFixed(2),
      );
      // ignore: discarded_futures
      ref.read(orderProvider).fetchModifyOrder(input, context);
      return;
    }

    showModifyOrderDialog(
      context: context,
      ref: ref,
      order: order,
      newPrice: finalNewPrice,
      newTriggerPrice: newTrigger,
    );
  }

  Future<void> _handleAlertSetRequested(int paneIndex, double price) async {
    final session = ref.read(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) return;
    final scrip = session.panes[paneIndex].scrip;
    if (scrip == null) return;
    final mw = ref.read(marketWatchProvider);
    final socketEntry = ref.read(websocketProvider).socketDatas[scrip.token];
    final ltpStr = socketEntry is Map ? socketEntry['lp']?.toString() : null;
    final ltp = double.tryParse(ltpStr ?? '');
    if (ltp == null || ltp <= 0) return;
    final alertType = price > ltp ? 'LTP_A' : 'LTP_B';
    // Both `fetchSetAlert` and `fetchSetAlertWeb` on marketWatchProvider
    // Navigator.pop the calling context (and the web variant also routes
    // to /orderBook). From the chart context those pops blank the chart.
    // Call the underlying API directly + refresh the list + show our own
    // toast — bypasses the navigation side-effects entirely.
    try {
      final api = locator<ApiExporter>();
      final result = await api.getSetAlert(
          scrip.exch, scrip.tsym, price.toStringAsFixed(2), alertType, '');
      if (result.stat == 'OI created') {
        await mw.fetchPendingAlert(context);
        if (!mounted) return;
        ResponsiveSnackBar.showSuccess(context, 'Alert created successfully');
      } else {
        if (!mounted) return;
        ResponsiveSnackBar.showWarning(
            context, result.emsg ?? 'Alert not created');
      }
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showWarning(context, 'Alert request failed');
    }
  }

  /// Add a TP + SL exit for an existing POSITION as an OCO (one-cancels-
  /// other) order: a target LIMIT leg and a stop SL-MKT leg, both on the
  /// opposite side of the position. The user sets both prices in a dialog
  /// (pre-filled from the position avg); when one leg fills the broker
  /// cancels the other.
  Future<void> _handlePositionOcoRequested(
      int paneIndex, String overlayId) async {
    final session = ref.read(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) return;
    final scrip = session.panes[paneIndex].scrip;
    if (scrip == null) return;
    if (!overlayId.startsWith('pos-')) return;

    final positions =
        ref.read(portfolioProvider).postionBookModel ?? const [];
    String exch = '';
    String tsym = '';
    String prd = '';
    int netqty = 0;
    double avg = 0;
    for (final p in positions) {
      if (p.exch == scrip.exch &&
          p.token == scrip.token &&
          (int.tryParse(p.netqty ?? '0') ?? 0) != 0) {
        exch = p.exch ?? '';
        tsym = p.tsym ?? scrip.tsym;
        prd = p.prd ?? '';
        netqty = int.tryParse(p.netqty ?? '0') ?? 0;
        avg = double.tryParse(p.netavgprc ?? '') ?? 0;
        break;
      }
    }
    if (exch.isEmpty || netqty == 0 || avg <= 0) return;
    final isLong = netqty > 0;
    final qtyAbs = netqty.abs();
    final ti = scrip.ti > 0 ? scrip.ti : 0.05;
    double snap(double v) => (v / ti).round() * ti;

    // The OCO legs are LTP-triggered GTT conditions, so the broker rejects
    // ("Invalid Condition") any bracket that doesn't straddle the CURRENT
    // price. Anchor the prefill to the live LTP (fallback to avg) and the
    // dialog validates against it — not the entry avg, which for options
    // can sit far from the live price.
    double ltp = avg;
    try {
      final entry = ref.read(websocketProvider).socketDatas[scrip.token];
      if (entry is Map && entry['lp'] != null) {
        final v = double.tryParse(entry['lp'].toString());
        if (v != null && v > 0) ltp = v;
      }
    } catch (_) {}

    // Target above LTP / stop below LTP for a long; mirrored for a short.
    final tpInit = snap(isLong ? ltp * 1.02 : ltp * 0.98);
    final slInit = snap(isLong ? ltp * 0.98 : ltp * 1.02);

    // Circuit band for the OCO card's UC/LC validation (TC_523/524). Cache hit
    // when the chart already warmed the scrip info; else one quick fetch.
    var ocoInfo = _cachedScripInfo(scrip);
    if (ocoInfo == null) {
      try {
        await ref
            .read(marketWatchProvider)
            .fetchScripInfo(scrip.token, scrip.exch, context, false);
      } catch (_) {}
      if (!mounted) return;
      ocoInfo = _cachedScripInfo(scrip) ??
          ref.read(marketWatchProvider).scripInfoModel;
    }

    final result = await showOcoTpSlDialog(
      context: context,
      tsym: tsym,
      isLong: isLong,
      ltp: ltp,
      tpInit: tpInit,
      slInit: slInit,
      ti: ti,
      uc: ocoInfo?.uc,
      lc: ocoInfo?.lc,
    );
    if (result == null || !mounted) return;

    // Exit side is opposite the position: long → SELL, short → BUY. BOTH
    // legs are plain LMT orders — the OCO triggers come from the oivariable
    // conditions (d1/d2), not from per-leg SL triggers. Matches the broker's
    // accepted format (verified against a working request). Leg 1 = target,
    // leg 2 = stop; `d` is the trigger level and `prc` the limit (same here).
    final input = PlaceOcoOrderInput(
      exch: exch,
      tsym: tsym,
      validity: 'GTT',
      trantype: isLong ? 'S' : 'B',
      ret: 'DAY',
      remarks: '',
      qty1: qtyAbs.toString(),
      prctyp1: 'LMT',
      prc1: result.tp.toStringAsFixed(2),
      trgprc1: '',
      prd1: prd,
      d1: result.tp.toStringAsFixed(2),
      qty2: qtyAbs.toString(),
      prctyp2: 'LMT',
      prc2: result.sl.toStringAsFixed(2),
      trgprc2: '',
      prd2: prd,
      d2: result.sl.toStringAsFixed(2),
      alid: '',
    );
    await ref.read(orderProvider).placeOCOOrder(input, context);
  }

  /// Prompts for an annotation's text right after it is placed. Empty / cancel
  /// removes the just-added drawing; otherwise the text is saved (which
  /// re-pushes the drawing to the iframe via `_pushSession`).
  Future<void> _promptDrawingText(String scripKey, String drawingId) async {
    final value = await showDrawingTextDialog(context: context);
    if (!mounted) return;
    final n = ref.read(chartEngineSessionProvider.notifier);
    if (value == null || value.isEmpty) {
      n.removeDrawing(scripKey, drawingId);
    } else {
      n.updateDrawing(scripKey, drawingId, text: value);
    }
  }

  /// Re-edit an existing text annotation (double-click). Seeds the dialog with
  /// the current text; on cancel the drawing is KEPT as-is (unlike placement,
  /// which removes an empty one).
  Future<void> _editDrawingText(String paneId, String drawingId) async {
    final idx = int.tryParse(paneId);
    if (idx == null) return;
    final session = ref.read(chartEngineSessionProvider);
    if (idx < 0 || idx >= session.panes.length) return;
    final scrip = session.panes[idx].scrip;
    if (scrip == null) return;
    final scripKey = '${scrip.exch}|${scrip.token}';
    final list = session.drawings[scripKey] ?? const <ChartDrawing>[];
    ChartDrawing? target;
    for (final d in list) {
      if (d.id == drawingId) {
        target = d;
        break;
      }
    }
    if (target == null) return;
    final value = await showDrawingTextDialog(
        context: context, initial: target.text, title: 'Edit text');
    if (!mounted || value == null) return; // cancel → keep existing text
    ref
        .read(chartEngineSessionProvider.notifier)
        .updateDrawing(scripKey, drawingId, text: value);
  }

  /// Resolves a placed OCO bracket by its alert id from the GTT book.
  GttOrderBookModel? _findOcoByAlId(String alId) {
    if (alId.isEmpty) return null;
    final gtts = ref.read(orderProvider).gttOrderBookModel ?? const [];
    for (final g in gtts) {
      if (g.alId == alId && g.placeOrderParamsLeg2 != null) return g;
    }
    return null;
  }

  Future<void> _handleOverlayCloseRequested(
      int paneIndex, String overlayId) async {
    final session = ref.read(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) return;
    final scrip = session.panes[paneIndex].scrip;
    if (scrip == null) return;

    // OCO bracket close (× on either leg) cancels the whole bracket.
    if (overlayId.startsWith('ocoTp-') || overlayId.startsWith('ocoSl-')) {
      final isTp = overlayId.startsWith('ocoTp-');
      final alId = overlayId.substring(isTp ? 'ocoTp-'.length : 'ocoSl-'.length);
      final gtt = _findOcoByAlId(alId);
      if (gtt == null) return;
      // ignore: discarded_futures
      showOcoCancelDialog(context: context, ref: ref, gtt: gtt);
      return;
    }

    // Phase 17.A — close × on an `optionStrike` overlay (option position
    // surfaced on its underlying-index chart). The overlay ID embeds the
    // OPTION's exch+token so we square-off the right scrip, not the
    // underlying. Honors per-pane Instant override exactly like 'pos-'.
    if (overlayId.startsWith('optStrike-')) {
      final rest = overlayId.substring('optStrike-'.length);
      final dashIdx = rest.indexOf('-');
      if (dashIdx <= 0) return;
      final optExch = rest.substring(0, dashIdx);
      final optToken = rest.substring(dashIdx + 1);
      if (optExch.isEmpty || optToken.isEmpty) return;
      final positions =
          ref.read(portfolioProvider).postionBookModel ?? const [];
      for (final p in positions) {
        if (p.exch != optExch || p.token != optToken) continue;
        if ((int.tryParse(p.netqty ?? '0') ?? 0) == 0) continue;
        if (session.effectiveInstantFor(paneIndex)) {
          final ls = int.tryParse(p.ls ?? '1') ?? 1;
          final frz = int.tryParse(p.frzqty ?? '0') ?? 0;
          final frzqty = ls > 0 ? (frz ~/ ls) * ls : frz;
          final deviceInfo = ref.read(authProvider).deviceInfo;
          final channel = defaultTargetPlatform == TargetPlatform.android
              ? '${deviceInfo["brand"]}'
              : '${deviceInfo["model"]}';
          final qtyInt = int.tryParse(p.netqty ?? '0') ?? 0;
          final input = PlaceOrderInput(
            exch: p.exch ?? '',
            tsym: p.tsym ?? '',
            qty: (p.netqty ?? '0').replaceAll('-', ''),
            prc: '0',
            prctype: 'MKT',
            trantype: qtyInt < 0 ? 'B' : 'S',
            prd: p.prd ?? '',
            ret: 'DAY',
            trgprc: '',
            blprc: '',
            bpprc: '',
            dscqty: '',
            amo: isAmoTime(p.exch ?? '') ? 'Yes' : '',
            trailprc: '',
            mktProt: '',
            channel: channel,
            frzqty: frzqty,
          );
          // multipleexit:true suppresses the Navigator.pop fetchExitPosition
          // would otherwise issue, which would blank the chart screen.
          // ignore: discarded_futures
          ref
              .read(portfolioProvider)
              .fetchExitPosition(context, input, true, true);
          return;
        }
        showSquareOffDialog(context: context, ref: ref, position: p);
        return;
      }
      return;
    }

    if (overlayId.startsWith('alert-')) {
      final alertId = overlayId.substring('alert-'.length);
      final alerts =
          ref.read(marketWatchProvider).alertPendingModel ?? const [];
      AlertPendingModel? alert;
      for (final a in alerts) {
        if (a.alId == alertId) {
          alert = a;
          break;
        }
      }
      if (alert != null) {
        final cancelled = await showAlertCancelDialog(
            context: context, ref: ref, alert: alert);
        if (cancelled && mounted) {
          ResponsiveSnackBar.showSuccess(context, 'Alert Cancelled');
        }
      }
      return;
    }

    if (overlayId.startsWith('pos-')) {
      final positions =
          ref.read(portfolioProvider).postionBookModel ?? const [];
      for (final p in positions) {
        if (p.exch == scrip.exch &&
            p.token == scrip.token &&
            (int.tryParse(p.netqty ?? '0') ?? 0) != 0) {
          if (session.effectiveInstantFor(paneIndex)) {
            // Instant: skip dialog, build the same PlaceOrderInput
            // showSquareOffDialog builds and fire square-off directly.
            final ls = int.tryParse(p.ls ?? '1') ?? 1;
            final frz = int.tryParse(p.frzqty ?? '0') ?? 0;
            final frzqty = ls > 0 ? (frz ~/ ls) * ls : frz;
            final deviceInfo = ref.read(authProvider).deviceInfo;
            final channel = defaultTargetPlatform == TargetPlatform.android
                ? '${deviceInfo["brand"]}'
                : '${deviceInfo["model"]}';
            final qtyInt = int.tryParse(p.netqty ?? '0') ?? 0;
            final input = PlaceOrderInput(
              exch: p.exch ?? '',
              tsym: p.tsym ?? '',
              qty: (p.netqty ?? '0').replaceAll('-', ''),
              prc: '0',
              prctype: 'MKT',
              trantype: qtyInt < 0 ? 'B' : 'S',
              prd: p.prd ?? '',
              ret: 'DAY',
              trgprc: '',
              blprc: '',
              bpprc: '',
              dscqty: '',
              amo: isAmoTime(p.exch ?? '') ? 'Yes' : '',
              trailprc: '',
              mktProt: '',
              channel: channel,
              frzqty: frzqty,
            );
            // ignore: discarded_futures
            // multipleexit=true to suppress the Navigator.pop(context) that
            // fetchExitPosition issues on success — it assumes the caller is
            // an order/exit screen that needs dismissing. From the chart
            // context that pop would close the chart screen itself
            // (blank-screen bug). We handle our own UI state, so skip it.
            ref
                .read(portfolioProvider)
                .fetchExitPosition(context, input, true, true);
            return;
          }
          showSquareOffDialog(context: context, ref: ref, position: p);
          return;
        }
      }
    } else {
      final id = overlayId.replaceFirst(RegExp(r'^(ord|sl-l|sl)-'), '');
      final orders = ref.read(orderProvider).orderBookModel ?? const [];
      for (final o in orders) {
        if (o.norenordno == id) {
          if (session.effectiveInstantFor(paneIndex)) {
            // Instant: skip dialog, fire cancel directly. loop=true shows the
            // "Order Cancelled" toast + refresh (web path doesn't pop a route).
            // ignore: discarded_futures
            ref
                .read(orderProvider)
                .fetchOrderCancel(o.norenordno.toString(), context, true);
            return;
          }
          showCloseOrderDialog(context: context, ref: ref, order: o);
          return;
        }
      }
    }
  }

  void _setIframePointerEvents(bool enabled) {
    final el = html.document.getElementById(_iframeId);
    if (el is html.IFrameElement) {
      el.style.pointerEvents = enabled ? 'auto' : 'none';
    }
  }

  /// Reads the latest LTP for a scrip from the shared WS tick cache.
  /// Returns null if no tick has arrived yet (fetcher will retry next cycle).
  double? _currentSpotLtp(ChartScrip scrip) {
    final ws = ref.read(websocketProvider);
    final entry = ws.socketDatas[scrip.token];
    if (entry is! Map) return null;
    final raw = entry['lp'];
    double? v;
    if (raw is num) {
      v = raw.toDouble();
    } else if (raw is String) {
      v = double.tryParse(raw);
    }
    if (v == null || v <= 0) return null;
    return v;
  }

  /// Runs every 5s. 2-step option-chain fetch:
  ///   Step 1: `getLinkedScrip` → pick nearest expiry by date → cache in
  ///           `chartOptionExpiryProvider`. Fires only when cache is missing
  ///           or stale (different scrip). A 2s guard prevents hammering.
  ///   Step 2: `getOptionChain` with the cached expiry's `tsym`. Fires only
  ///           after 120s since last fetch (unchanged cadence).
  void _maybeFetchOptionChain(Timer? _) {
    if (!mounted || !_iframeReady) return;
    // Popout is view-only over the alternate feed: the option-chain OI path
    // subscribes tokens on the shared socket, which the popout must not open.
    if (widget.popout) return;
    final session = ref.read(chartEngineSessionProvider);
    final oiData = ref.read(chartOiDataProvider);
    final oiNotifier = ref.read(chartOiDataProvider.notifier);
    final expiryCache = ref.read(chartOptionExpiryProvider);
    final expiryNotifier = ref.read(chartOptionExpiryProvider.notifier);
    final now = DateTime.now().millisecondsSinceEpoch;
    // WS now drives live OI; chain re-fetch is only a sanity sync to pick up
    // new strikes as ATM moves. 10 minutes between full re-fetches.
    const refreshMs = 600000;

    for (var i = 0; i < session.panes.length; i++) {
      final pane = session.panes[i];
      if (!pane.showOptionChainOi) {
        // Toggled off — drop any cached strikes, expiry, and WS OI subs.
        if (oiData.byPane.containsKey(i)) {
          oiNotifier.clearForPane(i);
        }
        if (expiryCache.nearestByPane.containsKey(i)) {
          expiryNotifier.clearForPane(i);
        }
        _oiSubs.remove(i);
        continue;
      }
      final scrip = pane.scrip;
      if (scrip == null) {
        if (oiData.byPane.containsKey(i)) oiNotifier.clearForPane(i);
        if (expiryCache.nearestByPane.containsKey(i)) {
          expiryNotifier.clearForPane(i);
        }
        _oiSubs.remove(i);
        continue;
      }
      // No index-only gate anymore — `getLinkedScrip` decides. If the
      // scrip has no linked option chain (cash equity, FX, etc.), step 1
      // returns an empty `optExp` and the cache stays empty, which is the
      // natural "no OI strip" state. This is what makes the strip show up
      // for commodity futures like NATURALGAS25JUN26 / CRUDEOIL30MAY26 /
      // GOLD as well as the original index spots.

      final scripKey = '${scrip.exch}|${scrip.token}';

      // Symbol switched in this pane since the last cycle? Wipe the prior
      // symbol's stale OI state so the new symbol fetches immediately. Without
      // this, `fetchedAtByPane[i]` still holds the previous symbol's recent
      // timestamp, so Step 2 reports "chain-fresh" and never refetches — the
      // pane keeps showing the old symbol's strikes (off-screen at the new
      // price), i.e. no OI after a switch.
      if (_oiPaneScripKey[i] != scripKey) {
        _oiPaneScripKey[i] = scripKey;
        oiNotifier.clearForPane(i);        // drop stale strikes + fetchedAt
        expiryNotifier.clearForPane(i);    // force Step 1 to re-resolve expiry
        _linkedScripCheckedAt.remove(scripKey); // allow an immediate re-link
        _noOptionChainAt.remove(scripKey); // re-check; don't inherit stale "no chain"
        _oiSubs.remove(i);                 // drop old option-token WS subs
        if (_kOiDebug) debugPrint('[OI] pane=$i $scripKey symbol-change reset');
        continue; // next cycle (ms away) proceeds with clean state
      }

      final cachedExpiry = expiryCache.nearestByPane[i];
      final cachedScripKey = expiryCache.scripKeyByPane[i];

      // Skip scrips recently found to have no chain — but re-check after the
      // TTL so a transient empty doesn't disable OI forever (e.g. SENSEX).
      final noChainAt = _noOptionChainAt[scripKey];
      if (noChainAt != null && now - noChainAt < 900000) {
        if (_kOiDebug) {
          debugPrint('[OI] pane=$i $scripKey SKIP no-chain TTL '
              '(${((now - noChainAt) / 1000).round()}s ago)');
        }
        continue;
      }

      // ── Step 1: fetch expiry list if not cached for this scrip ─────────
      // Fire-and-continue; the next tick sees the cache and proceeds to Step 2.
      // Throttled to once per 5 min PER SCRIP (keyed by scripKey, so a symbol
      // switch isn't blocked) — live OI flows via WS, no need to re-fetch the
      // expiry list often.
      if (cachedExpiry == null || cachedScripKey != scripKey) {
        final lastLinkedAt = _linkedScripCheckedAt[scripKey] ?? 0;
        if (now - lastLinkedAt < 300000) continue;
        _linkedScripCheckedAt[scripKey] = now;
        if (_kOiDebug) {
          debugPrint('[OI] pane=$i $scripKey -> getLinkedScrip(...)');
        }
        // ignore: discarded_futures
        locator<ApiExporter>()
            .getLinkedScrip(scrip.token, scrip.exch)
            .then((linked) {
          if (!mounted) return;
          if (_kOiDebug) {
            debugPrint('[OI] pane=$i $scripKey getLinkedScrip <- '
                'stat=${linked.stat} optExp=${linked.optExp?.length ?? -1}');
          }
          if (linked.stat != 'Ok' ||
              linked.optExp == null ||
              linked.optExp!.isEmpty) {
            // No option chain right now — remember WHEN so we re-check after
            // the TTL (handles indices whose chain wasn't ready on first ask)
            // instead of disabling OI permanently.
            _noOptionChainAt[scripKey] = now;
            return;
          }
          final sorted = [...linked.optExp!]
            ..sort((a, b) => _parseExpiryDate(a.exd ?? '')
                .compareTo(_parseExpiryDate(b.exd ?? '')));
          final pick = sorted.first;
          final tsym = pick.tsym ?? '';
          if (tsym.isEmpty) return;
          ref.read(chartOptionExpiryProvider.notifier).setForPane(
                i,
                ChartOptionExpiry(
                  tsym: tsym,
                  exd: pick.exd ?? '',
                  exch: pick.exch ?? '',
                ),
                scripKey,
              );
          // fetchedAtByPane is intentionally NOT stamped here — leave it at 0
          // so the next cycle fires the chain fetch immediately after the expiry
          // cache is populated.
        }).catchError((e) {
          if (_kOiDebug) debugPrint('[OI] pane=$i $scripKey getLinkedScrip ERR $e');
        });
        continue;
      }

      // ── Step 2: fetch chain with the cached expiry's tsym ──────────────
      final lastAt = oiData.fetchedAtByPane[i] ?? 0;
      if (now - lastAt < refreshMs) continue;
      final spotLtp = _currentSpotLtp(scrip);
      if (spotLtp == null) {
        if (_kOiDebug) {
          debugPrint('[OI] pane=$i $scripKey Step2 SKIP spotLtp==null '
              '(token=${scrip.token} not in socketDatas or no lp)');
        }
        continue;
      }
      if (_kOiDebug) {
        debugPrint('[OI] pane=$i $scripKey Step2 -> getOptionChain '
            'strPrc=${spotLtp.toStringAsFixed(0)} tsym=${cachedExpiry.tsym} '
            'exch=${cachedExpiry.exch}');
      }

      // Stamp fetched-at NOW so concurrent ticks don't re-fire.
      oiNotifier.setForPane(
          i, oiData.byPane[i] ?? const <ChartOiStrike>[], now);

      // ignore: discarded_futures
      locator<ApiExporter>()
          .getOptionChain(
              strPrc: spotLtp.toStringAsFixed(0),
              tradeSym: cachedExpiry.tsym,
              exchange: cachedExpiry.exch,
              context: context,
              numofStrike: '25')
          .then((res) {
        if (!mounted) return;
        if (_kOiDebug) {
          debugPrint('[OI] pane=$i $scripKey getOptionChain <- '
              'res=${res == null ? 'null' : 'stat=${res.stat} '
                  'optValue=${res.optValue?.length ?? -1}'}');
        }
        if (res == null || res.stat != 'Ok' || res.optValue == null) return;
        // Build initial snapshot and subscribe each option token via WS.
        final ws = ref.read(websocketProvider);
        final tokenMap = <String, _OiTokenInfo>{};
        final byStrike = <double, ChartOiStrike>{};
        for (final v in res.optValue!) {
          final strike = double.tryParse(v.strprc ?? '');
          if (strike == null || strike <= 0) continue;
          final oi = double.tryParse(v.oi ?? '0') ?? 0;
          final poi = double.tryParse(v.poi ?? '0') ?? 0;
          final chg = double.tryParse(v.oiPerChng ?? '0') ?? 0;
          final isCe = v.optt == 'CE';
          final t = v.token;
          final ex = v.exch;
          // Populate initial snapshot for the iframe.
          final prev = byStrike[strike];
          byStrike[strike] = ChartOiStrike(
            strike: strike,
            callOi: isCe ? oi : (prev?.callOi ?? 0),
            putOi: isCe ? (prev?.putOi ?? 0) : oi,
            callOiChgPct: isCe ? chg : (prev?.callOiChgPct ?? 0),
            putOiChgPct: isCe ? (prev?.putOiChgPct ?? 0) : chg,
            callPoi: isCe ? poi : (prev?.callPoi ?? 0),
            putPoi: isCe ? (prev?.putPoi ?? 0) : poi,
          );
          // Subscribe token for WS-based live OI updates.
          if (t != null && ex != null) {
            tokenMap[t] = _OiTokenInfo(strike: strike, isCe: isCe, poi: poi);
            ws.establishConnection(
              channelInput: '$ex|$t',
              task: 't',
              context: context,
            );
          }
        }
        _oiSubs[i] = tokenMap;
        // Push the initial snapshot immediately; WS ticks will refine it.
        final parsed = byStrike.values.toList()
          ..sort((a, b) => a.strike.compareTo(b.strike));
        ref
            .read(chartOiDataProvider.notifier)
            .setForPane(i, parsed, DateTime.now().millisecondsSinceEpoch);
      }).catchError((e) {
        // Silent — retry on the next 10-min cycle.
        if (_kOiDebug) debugPrint('[OI] pane=$i $scripKey getOptionChain ERR $e');
      });
    }
  }

  /// Parses Indian expiry date format "DD-MMM-YYYY" into a [DateTime].
  /// Copied verbatim from `watchlist_oc_provider.dart`.
  DateTime _parseExpiryDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        const monthMap = {
          'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4,
          'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8,
          'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
        };
        final month = monthMap[parts[1].toUpperCase()] ?? 1;
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime.now();
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
    ref.watch(themeProvider);
    ref.watch(chartEngineSessionProvider);
    // Push session changes (symbol / layout / qty / active pane …) to the
    // iframe AS SOON AS they happen. Without this, a pane symbol change only
    // reached the chart when some OTHER provider (portfolio/order/marketWatch)
    // next ticked — so during a quiet period or after market close, switching
    // a pane's symbol updated the store but never reached the iframe.
    ref.listen(chartEngineSessionProvider, (_, __) {
      if (_iframeReady) _pushSession();
    });
    // Watchlist pick → apply to the engine's live active pane. Forward each
    // distinct request (seq bumps even for the same symbol) so re-picking a
    // symbol already shown elsewhere still lands on the focused pane.
    ref.listen(activePaneSymbolRequestProvider, (prev, next) {
      if (!_iframeReady) return;
      if (next.scrip == null) return;
      if (prev != null && prev.seq == next.seq) return;
      _post(encodeApplyActiveSymbol(next.scrip!));
    });
    ref.listen(portfolioProvider, (_, __) {
      if (_iframeReady) _pushSession();
      // No auto-dismiss of popups — `portfolioProvider.notifyListeners()`
      // fires on every LP tick (positions update LTP), and killing the
      // user's open detail popup / qty selector / + menu on each tick
      // makes them unusable. If the underlying order/position vanishes
      // the popup's data goes stale — that's tolerable; user dismisses
      // manually.
    });
    ref.listen(orderProvider, (_, __) {
      if (_iframeReady) _pushSession();
    });
    ref.listen(marketWatchProvider, (_, __) {
      if (_iframeReady) _pushSession();
    });
    ref.listen(chartOiDataProvider, (_, __) {
      if (_iframeReady) _pushSession();
    });
    ref.listen(chartOptionExpiryProvider, (_, __) {
      if (_iframeReady) _pushSession();
    });
    // Snap button → ScreenshotRequestNotifier bumps a counter. We post
    // `takeScreenshot` to the iframe for the requested pane each time the
    // counter changes — the iframe replies with `chartScreenshot` (data
    // URL) which `_onWindowMessageInner` turns into a file download.
    ref.listen(screenshotRequestProvider, (prev, next) {
      if (!_iframeReady) return;
      if (next.paneIndex == null) return;
      if (prev != null && prev.requestId == next.requestId) return;
      _post(encodeTakeScreenshot(next.paneIndex.toString()));
    });
    // Customize tab → palette changes flow into the iframe as a single
    // setChartPalette message. Empty-string fields are sent through so the
    // JS side can fall back to its theme defaults for those keys.
    ref.listen(chartPaletteProvider, (prev, next) {
      if (!_iframeReady) return;
      _post(encodeSetChartPalette(next.toWire()));
    });
    // Mirror the Riverpod INSTANT flag into the JS top bar chip. Fires on
    // every session-level change — including ones the JS chip itself
    // caused. The JS side dedups (no-op when value === current).
    ref.listen(
        chartEngineSessionProvider.select((s) => s.instantOrders),
        (prev, next) {
      if (!_iframeReady) return;
      if (prev == next) return;
      _post(encodeSetInstantOrders(next));
    });
    // Mirror the active layout id into the JS layout picker. The full
    // setLayout (with areas/rows/columns) is still emitted by _pushSession
    // — this is just the id badge for the picker's "current" highlight.
    ref.listen(
        chartEngineSessionProvider.select((s) => s.layout.id),
        (prev, next) {
      if (!_iframeReady) return;
      if (prev == next) return;
      _post(encodeSetActiveLayoutId(next));
    });
    // Order Defaults — single push of the full bag on any change. The JS
    // popover renders from this mirror; field changes flow back via the
    // `updateOrderDefaults` patch message.
    ref.listen(orderDefaultsProvider, (prev, next) {
      // BUG A — a per-family Trade Quantity change must reseed every pane's
      // qty. setPaneSymbol seeds it only once (at symbol-set time), so an
      // already-shown symbol (e.g. GOLDM futures, lot 100) stayed at the old
      // qty when the user later changed the default. Recompute with the same
      // family logic; the resulting session change re-pushes encodeSetPaneQty
      // via the chartEngineSessionProvider listener above. Run before the
      // _iframeReady guard so state stays correct even if the change lands
      // while the iframe is (re)loading.
      if (prev == null ||
          prev.equityDefaultQty != next.equityDefaultQty ||
          prev.futuresDefaultQty != next.futuresDefaultQty ||
          prev.optionsDefaultQty != next.optionsDefaultQty) {
        ref
            .read(chartEngineSessionProvider.notifier)
            .reseedQtyFromDefaults(next);
      }
      if (!_iframeReady) return;
      if (prev == next) return;
      _post(encodeSetOrderDefaults(next.toJson()));
    });
    // Settings → View on chart — active pane's view toggles. Selector
    // hashes every relevant field so any toggle re-fires; selector is
    // separate from setActivePaneTopBarState to keep that one small.
    ref.listen(
        chartEngineSessionProvider.select((s) {
          if (s.panes.isEmpty) return null;
          final p = s.active;
          return '${s.activePaneIndex}|${p.showHighLowMarkers}'
              '|${p.showOptionChainOi}|${p.showBarCountdown}'
              '|${p.showKeyLevels}|${p.pivotVariant}|${p.showAutoPattern}'
              '|${p.magnetEnabled}|${p.showVolumeProfile}'
              '|${p.overlays.gridlines}|${p.overlays.volume}';
        }),
        (prev, next) {
      if (!_iframeReady) return;
      if (prev == next || next == null) return;
      _post(encodeSetActivePaneViewState(_activePaneViewBag()));
    });
    // Settings → keyboardShortcuts (session-level).
    ref.listen(
        chartEngineSessionProvider.select((s) => s.keyboardShortcuts),
        (prev, next) {
      if (!_iframeReady) return;
      if (prev == next) return;
      _post(encodeSetKeyboardShortcutsState(next));
    });
    // Settings → Customize tab — palette state (Settings popover input
    // fields). Distinct from `chartPaletteProvider` listener above which
    // ships the same payload to the chart renderer.
    ref.listen(chartPaletteProvider, (prev, next) {
      if (!_iframeReady) return;
      if (prev == next) return;
      _post(encodeSetChartPaletteState(_chartPaletteBag(next)));
    });
    // Symbol typeahead — active pane's current scrip. Fires on active
    // pane switch and on symbol change for whichever pane is active.
    ref.listen(
        chartEngineSessionProvider.select((s) {
          if (s.panes.isEmpty) return null;
          final scrip = s.active.scrip;
          return scrip == null
              ? '${s.activePaneIndex}|'
              : '${s.activePaneIndex}|${scrip.exch}|${scrip.token}';
        }),
        (prev, next) {
      if (!_iframeReady) return;
      if (prev == next) return;
      final scrip = ref.read(chartEngineSessionProvider).active.scrip;
      _post(encodeSetActivePaneSymbol(scrip?.toJson()));
    });
    // Per-pane top-bar state (Timeframe + Style) for the *active* pane,
    // bundled into one message so the JS top bar has a single subscription
    // point. Fires on active-pane switch and on any change to the active
    // pane's relevant fields.
    ref.listen(
        chartEngineSessionProvider.select((s) {
          if (s.panes.isEmpty) return null;
          final p = s.active;
          // Include a stable hash of the indicators list so add/remove
          // (and per-indicator settings tweaks) re-fire the push.
          final indHash = p.indicators
              .map((i) => '${i.id}:${i.kind}:${i.period}:${i.color}'
                  ':${i.hidden}:${i.thickness}')
              .join(',');
          return '${s.activePaneIndex}|${p.timeframeMinutes}|${p.candleStyle}'
              '|${p.showCrosshairLines}|$indHash';
        }),
        (prev, next) {
      if (!_iframeReady) return;
      if (prev == next || next == null) return;
      final p = ref.read(chartEngineSessionProvider).active;
      _post(encodeSetActivePaneTopBarState(
        timeframeMinutes: p.timeframeMinutes,
        candleStyle: p.candleStyle,
        showCrosshairLines: p.showCrosshairLines,
        indicators: [for (final i in p.indicators) i.toJson()],
      ));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushAll());
    final bg = ref.read(themeProvider).isDarkMode
        ? const Color(0xFF0B0F14)
        : const Color(0xFFFFFFFF);
    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The Flutter top-bar is now mostly empty (all its controls
          // migrated to the iframe's HTML top bar). Skipped in embedded
          // mode so the symbol details screen doesn't carry a dead strip.
          if (!widget.embedded)
            ChartEngineTopBar(
                onPopupVisibilityChanged: _setIframePointerEvents),
          Expanded(
            child: Stack(
              children: [
                MouseRegion(
                  opaque: false,
                  // First cursor entry into the chart area forces a setState ->
                  // Flutter re-runs layout -> the HtmlElementView's platform-view
                  // hit region is recomputed with the iframe's actual geometry.
                  // This unblocks the "chart unresponsive until you click another
                  // widget" Flutter Web quirk without consuming any user click.
                  onEnter: (_) {
                    if (!_hitRegionPrimed) {
                      _hitRegionPrimed = true;
                      if (mounted) setState(() {});
                    }
                  },
                  child: HtmlElementView(viewType: _viewType),
                ),
                // Opaque Mynt-logo loader covering the blank iframe flash until
                // the chart engine signals it's up (`chart-engine-ready`). The
                // chart's own symbol/candle loading takes over after that.
                if (!_iframeReady)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: bg,
                        child: Center(
                          child: SizedBox(
                            width: 90,
                            height: 90,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: SvgPicture.asset(
                                    'assets/icon/MYNT App Logo_v2.svg',
                                    width: 72,
                                    height: 72,
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 5,
                                    // Follow the theme accent instead of the
                                    // default dark indicator color, which reads
                                    // as a black ring on the white light-mode bg.
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      resolveThemeColor(context,
                                          dark: MyntColors.primaryDark,
                                          light: MyntColors.primaryDark),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Indicator Settings Dialog (Sahi-grade refinement) ──────────────────────
//
// Vertical-list dialog with header / body rows / gradient footer. Three
// design rules:
//   1. Every row = [label + description on the left, control on the right].
//   2. Controls are wide enough to feel tactile (44px tall steppers,
//      28px swatches) but never compete with the label hierarchy.
//   3. The Done button is the single primary action — gradient, full
//      width, 48px tall. Cancel is dismissive (back arrow in header).

const List<String> _kIndicatorPalette = [
  '#3B82F6', '#EF4444', '#22C55E', '#F59E0B', '#8B5CF6',
  '#06B6D4', '#EC4899', '#84CC16', '#FFFFFF', '#FBBF24',
];

// Kinds that take a meaningful integer period (length of the MA / oscillator
// window). Volume-driven indicators (OBV, AO) and composite oscillators with
// no user-facing length (Ichimoku, MA Ribbon) are deliberately excluded so
// the dialog doesn't show a control that does nothing.
const Set<String> _kKindsWithPeriod = {
  'sma', 'ema', 'rsi', 'bb', 'macd', 'stoch', 'atr',
  'zlema', 'mcginley', 'stochrsi', 'squeeze', 'efi',
  'vstop', 'wt', 'crsi', 'mfi', 'cmf', 'wr',
  // Phase 29 — single-period additions (supertrend/keltner use schemas).
  'wma', 'hma', 'donchian', 'cci', 'roc', 'adx',
  // Added indicators with a single scalar lookback (psar uses a schema;
  // pvt/ad have no period).
  'trix', 'vortex', 'uo', 'dpo', 'vwma',
};

String _humanKind(String kind) {
  switch (kind) {
    case 'sma':      return 'Simple Moving Average';
    case 'ema':      return 'Exponential Moving Average';
    case 'rsi':      return 'Relative Strength Index';
    case 'bb':       return 'Bollinger Bands';
    case 'vwap':     return 'Volume-Weighted Average Price';
    case 'macd':     return 'MACD';
    case 'stoch':    return 'Stochastic Oscillator';
    case 'atr':      return 'Average True Range';
    case 'zlema':    return 'Zero-Lag EMA';
    case 'mcginley': return 'McGinley Dynamic';
    case 'stochrsi': return 'Stochastic RSI';
    case 'squeeze':  return 'Squeeze Momentum';
    case 'efi':      return "Elder's Force Index";
    case 'ribbon':   return 'Moving Average Ribbon';
    case 'ichi':     return 'Ichimoku Cloud';
    case 'vstop':    return 'Volatility Stop';
    case 'wt':       return 'WaveTrend Oscillator';
    case 'crsi':     return 'Connors RSI';
    case 'ao':       return 'Awesome Oscillator';
    case 'mfi':      return 'Money Flow Index';
    case 'obv':      return 'On-Balance Volume';
    case 'cmf':      return 'Chaikin Money Flow';
    case 'wr':       return 'Williams %R';
  }
  return kind.toUpperCase();
}

Color _hexToColor(String hex) =>
    Color(int.parse(hex.replaceAll('#', '0xff')));

class _IndicatorSettingsDialog extends ConsumerStatefulWidget {
  final int paneIndex;
  final String indicatorId;
  const _IndicatorSettingsDialog({
    required this.paneIndex,
    required this.indicatorId,
  });

  @override
  ConsumerState<_IndicatorSettingsDialog> createState() =>
      _IndicatorSettingsDialogState();
}

class _IndicatorSettingsDialogState
    extends ConsumerState<_IndicatorSettingsDialog> {
  // Schema-driven param store. Each entry is keyed by `IndicatorParam.key`;
  // for legacy single-`period` kinds the only entry is `'period'`.
  final Map<String, num> _values = {};
  String _color = '#3B82F6';
  int _thickness = 1;
  bool _colorOpen = false;

  @override
  void initState() {
    super.initState();
    final cfg = _findCfg();
    if (cfg != null) {
      _color = cfg.color;
      _thickness = cfg.thickness;
      _seedValues(cfg);
    }
  }

  void _seedValues(IndicatorConfig cfg) {
    _values.clear();
    final schema = schemaFor(cfg.kind);
    if (schema != null) {
      // Legacy-period back-compat: when the persisted cfg has no `params`
      // map, route the old `cfg.period` to whichever schema key represents
      // the same concept (BB→length, Stoch→kPeriod, …). Falls back to the
      // 'period' key when no explicit mapping is declared.
      final legacyKey = cfg.params.isEmpty
          ? (schema.legacyPeriodKey ?? 'period')
          : null;
      for (final p in schema.params) {
        final fromParams = cfg.params[p.key];
        if (fromParams != null) {
          _values[p.key] = fromParams;
        } else if (legacyKey != null && p.key == legacyKey) {
          _values[p.key] = cfg.period;
        } else {
          _values[p.key] = p.defaultValue;
        }
      }
      return;
    }
    // Unknown kind: keep the legacy 'period' bag so the generic Period row
    // (used by `_kKindsWithPeriod` fallback) reads from the same store.
    if (_kKindsWithPeriod.contains(cfg.kind.toLowerCase())) {
      _values['period'] = cfg.period;
    }
  }

  IndicatorConfig? _findCfg() {
    final session = ref.read(chartEngineSessionProvider);
    if (widget.paneIndex < 0 || widget.paneIndex >= session.panes.length) {
      return null;
    }
    final pane = session.panes[widget.paneIndex];
    for (final i in pane.indicators) {
      if (i.id == widget.indicatorId) return i;
    }
    return null;
  }

  void _save() {
    final cfg = _findCfg();
    if (cfg == null) {
      Navigator.of(context).pop();
      return;
    }
    // Single-param kinds writing `period` must keep `IndicatorConfig.period`
    // in sync so chart.js code paths that still read `ind.period` directly
    // (and the diff caches) see the new value.
    final periodFromValues = _values['period'];
    final int nextPeriod =
        periodFromValues != null ? periodFromValues.toInt() : cfg.period;
    ref.read(chartEngineSessionProvider.notifier).updateIndicator(
          widget.paneIndex,
          widget.indicatorId,
          period: nextPeriod.clamp(1, 999),
          color: _color,
          thickness: _thickness,
          params: Map<String, num>.from(_values),
        );
    Navigator.of(context).pop();
  }

  void _delete() {
    ref
        .read(chartEngineSessionProvider.notifier)
        .removeIndicator(widget.paneIndex, widget.indicatorId);
    Navigator.of(context).pop();
  }

  // Picks the control for a schema param: dropdown for enums, switch for
  // booleans, stepper for plain numbers. All three read/write the same numeric
  // `_values` store (enum = option index, bool = 0/1).
  Widget _paramControl(IndicatorParam p) {
    if (p.isEnum) {
      return _ParamDropdown(
        param: p,
        value: _values[p.key] ?? p.defaultValue,
        onChanged: (v) => setState(() => _values[p.key] = v),
      );
    }
    if (p.isBool) {
      return _ParamSwitch(
        value: (_values[p.key] ?? p.defaultValue) >= 1,
        onChanged: (v) => setState(() => _values[p.key] = v ? 1 : 0),
      );
    }
    return _ParamStepper(
      value: _values[p.key] ?? p.defaultValue,
      param: p,
      onChanged: (v) => setState(() => _values[p.key] = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _findCfg();
    if (cfg == null) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Indicator no longer exists'),
        ),
      );
    }

    final surface = resolveThemeColor(context,
        dark: MyntColors.overlayBgDark, light: MyntColors.overlayBg);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final divider = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.secondary, light: MyntColors.primary);

    final schema = schemaFor(cfg.kind);
    final params = schema?.params ?? const <IndicatorParam>[];
    final useGenericPeriod = schema == null &&
        _kKindsWithPeriod.contains(cfg.kind.toLowerCase());
    final kindLabel = cfg.kind.toUpperCase();
    final humanLabel = schema?.displayName ?? _humanKind(cfg.kind.toLowerCase());
    // Header value chip: single-param kinds (or legacy ones with a single
    // period) show the value next to the kind label; multi-param kinds drop
    // it to avoid the header becoming a parameter dump.
    final bool showHeaderValue =
        (schema == null && useGenericPeriod) || params.length == 1;
    final num? headerValue = showHeaderValue
        ? (schema == null ? cfg.period : _values[params.first.key])
        : null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 18, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _hexToColor(_color),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                headerValue == null
                                    ? kindLabel
                                    : '$kindLabel  ·  ${_fmtNum(headerValue, params.isNotEmpty ? params.first : null)}',
                                style: MyntWebTextStyles.head(context,
                                    fontWeight: MyntFonts.semiBold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(humanLabel,
                              style: MyntWebTextStyles.caption(context,
                                  darkColor: MyntColors.textSecondaryDark,
                                  lightColor: MyntColors.textSecondary)),
                        ],
                      ),
                    ),
                    // Close (×) — what users intuitively reach for in the
                    // top-right corner. Delete moved to the footer (below)
                    // as an explicit text button so it's never confused
                    // with "close the dialog".
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      icon: Icon(Icons.close, size: 18, color: muted),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: divider, thickness: 1),

              // Schema-driven param rows (or single generic Period row for
              // legacy kinds that aren't in the schema registry yet).
              if (schema != null)
                for (final p in params) ...[
                  _SettingsRow(
                    label: p.label,
                    description: p.description,
                    control: _paramControl(p),
                  ),
                ]
              else if (useGenericPeriod) ...[
                _SettingsRow(
                  label: 'Period',
                  description: 'Length parameter',
                  control: _ParamStepper(
                    value: _values['period'] ?? cfg.period,
                    param: const IndicatorParam(
                      key: 'period', label: 'Period',
                      description: 'Length parameter',
                      defaultValue: 14, min: 1, max: 999,
                    ),
                    onChanged: (v) => setState(() => _values['period'] = v),
                  ),
                ),
              ],

              _SettingsRow(
                label: 'Color',
                description: 'Line color for this indicator',
                control: _ColorButton(
                  color: _color,
                  open: _colorOpen,
                  onTap: () => setState(() => _colorOpen = !_colorOpen),
                ),
              ),
              if (_colorOpen)
                _ColorPaletteRow(
                  selected: _color,
                  onPick: (hex) => setState(() {
                    _color = hex;
                    _colorOpen = false;
                  }),
                ),

              _SettingsRow(
                label: 'Thickness',
                description: 'Line width in pixels',
                control: _ThicknessSegmented(
                  value: _thickness,
                  accent: accent,
                  onChanged: (v) => setState(() => _thickness = v),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(children: [
                  // Expanded(
                  //   child: ElevatedButton(
                  //     onPressed: _delete,
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: resolveThemeColor(context,
                  //           dark: MyntColors.errorDark,
                  //           light: MyntColors.tertiary),
                  //       foregroundColor: Colors.white,
                  //       elevation: 0,
                  //       minimumSize: const Size.fromHeight(48),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(8),
                  //       ),
                  //     ),
                  //     child: const Text(
                  //       'Delete',
                  //       style: TextStyle(
                  //         color: Colors.white,
                  //         fontWeight: FontWeight.w700,
                  //         fontSize: 14,
                  //         letterSpacing: 0.4,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: resolveThemeColor(context,
                            dark: MyntColors.secondary,
                            light: MyntColors.primary),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtNum(num v, IndicatorParam? p) {
  if (p != null && !p.isInt) {
    return v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }
  return v.toInt().toString();
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String description;
  final Widget control;
  const _SettingsRow({
    required this.label,
    required this.description,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.semiBold)),
                const SizedBox(height: 2),
                Text(description,
                    style: MyntWebTextStyles.caption(context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          control,
        ],
      ),
    );
  }
}

class _ParamStepper extends StatefulWidget {
  final num value;
  final IndicatorParam param;
  final ValueChanged<num> onChanged;
  const _ParamStepper({
    required this.value,
    required this.param,
    required this.onChanged,
  });

  @override
  State<_ParamStepper> createState() => _ParamStepperState();
}

class _ParamStepperState extends State<_ParamStepper> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _format(widget.value));
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _ParamStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.value != widget.value) {
      final txt = _format(widget.value);
      if (_ctrl.text != txt) _ctrl.text = txt;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit(_ctrl.text);
  }

  num _clamp(num v) {
    if (v < widget.param.min) return widget.param.min;
    if (v > widget.param.max) return widget.param.max;
    return v;
  }

  num _normalize(num v) {
    if (widget.param.isInt) return v.toInt();
    final stepInv = 1 / widget.param.step;
    return (v * stepInv).round() / stepInv;
  }

  String _format(num v) {
    if (widget.param.isInt) return v.toInt().toString();
    final fixed = v.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  void _commit(String raw) {
    final parsed = num.tryParse(raw.trim());
    if (parsed == null) {
      _ctrl.text = _format(widget.value);
      return;
    }
    final next = _normalize(_clamp(parsed));
    _ctrl.text = _format(next);
    if (next != widget.value) widget.onChanged(next);
  }

  void _bump(num delta) {
    final base = num.tryParse(_ctrl.text.trim()) ?? widget.value;
    final next = _normalize(_clamp(base + delta));
    _ctrl.text = _format(next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.inputBgDark, light: MyntColors.inputBg);
    final stroke = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final iconColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Container(
      width: 124,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: stroke, width: 1),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            color: iconColor,
            onTap: () => _bump(-widget.param.step),
          ),
          Expanded(
            child: Center(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.numberWithOptions(
                    decimal: !widget.param.isInt),
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: _commit,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            color: iconColor,
            onTap: () => _bump(widget.param.step),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StepButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// Dropdown control for enum params. Displays the selected option's label and
// opens a menu; stores the chosen option INDEX back through [onChanged].
class _ParamDropdown extends StatelessWidget {
  final IndicatorParam param;
  final num value; // selected option index
  final ValueChanged<num> onChanged;
  const _ParamDropdown({
    required this.param,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = param.options ?? const <IndicatorOption>[];
    if (options.isEmpty) return const SizedBox.shrink();
    final idx = value.toInt().clamp(0, options.length - 1);
    final bg = resolveThemeColor(context,
        dark: MyntColors.inputBgDark, light: MyntColors.inputBg);
    final stroke = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final surface = resolveThemeColor(context,
        dark: MyntColors.overlayBgDark, light: MyntColors.overlayBg);
    final accent = resolveThemeColor(context,
        dark: MyntColors.secondary, light: MyntColors.primary);
    return PopupMenuButton<int>(
      tooltip: '',
      initialValue: idx,
      color: surface,
      elevation: 8,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: stroke, width: 1),
      ),
      onSelected: (i) {
        if (i != idx) onChanged(i);
      },
      itemBuilder: (context) => [
        for (int i = 0; i < options.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    options[i].label,
                    style: i == idx
                        ? MyntWebTextStyles.body(context,
                            fontWeight: MyntFonts.semiBold)
                        : MyntWebTextStyles.body(context),
                  ),
                ),
                if (i == idx) Icon(Icons.check, size: 16, color: accent),
              ],
            ),
          ),
      ],
      child: Container(
        width: 168,
        height: 36,
        padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: stroke, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                options[idx].label,
                overflow: TextOverflow.ellipsis,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: muted),
          ],
        ),
      ),
    );
  }
}

// Switch control for boolean params (stored as 0/1).
class _ParamSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ParamSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = resolveThemeColor(context,
        dark: MyntColors.secondary, light: MyntColors.primary);
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: accent,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ColorButton extends StatelessWidget {
  final String color;
  final bool open;
  final VoidCallback onTap;
  const _ColorButton(
      {required this.color, required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stroke = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
          decoration: BoxDecoration(
            border: Border.all(color: stroke, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _hexToColor(color),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPaletteRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onPick;
  const _ColorPaletteRow({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final hex in _kIndicatorPalette)
            _SwatchTile(
              hex: hex,
              selected: hex.toLowerCase() == selected.toLowerCase(),
              onTap: () => onPick(hex),
            ),
        ],
      ),
    );
  }
}

class _SwatchTile extends StatefulWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;
  const _SwatchTile(
      {required this.hex, required this.selected, required this.onTap});

  @override
  State<_SwatchTile> createState() => _SwatchTileState();
}

class _SwatchTileState extends State<_SwatchTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final ringIdle = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final size = 28.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _hexToColor(widget.hex),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.selected
                  ? Colors.white
                  : (_hover
                      ? Colors.white.withValues(alpha: 0.4)
                      : ringIdle),
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: _hexToColor(widget.hex).withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _ThicknessSegmented extends StatelessWidget {
  final int value;
  final Color accent;
  final ValueChanged<int> onChanged;
  const _ThicknessSegmented({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.inputBgDark, light: MyntColors.inputBg);
    final stroke = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    Widget seg(int v) {
      final sel = v == value;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              height: 32,
              decoration: BoxDecoration(
                color: sel ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: SizedBox(
                  width: 26,
                  child: Container(
                    height: v.toDouble(),
                    decoration: BoxDecoration(
                      color: sel
                          ? Colors.white
                          : resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 156,
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: stroke, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [seg(1), seg(2), seg(3)]),
    );
  }
}

class _GradientPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  const _GradientPrimaryButton(
      {required this.label, required this.onPressed});

  @override
  State<_GradientPrimaryButton> createState() =>
      _GradientPrimaryButtonState();
}

class _GradientPrimaryButtonState extends State<_GradientPrimaryButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 48,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: _hover ? 0.32 : 0.18),
                blurRadius: _hover ? 18 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          transform: Matrix4.identity()
            ..scaleByDouble(
              _down ? 0.985 : (_hover ? 1.005 : 1.0),
              _down ? 0.985 : (_hover ? 1.005 : 1.0),
              1.0,
              1.0,
            ),
          transformAlignment: Alignment.center,
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
