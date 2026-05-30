import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_oi_data.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/indicator_schema.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/pane_runtime_status.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/overlay_payload.dart';
import 'package:mynt_plus/screens/web/chart_engine/utils/chart_engine_bridge.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/chart_engine_top_bar.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/models/marketwatch_model/alert_model/alert_pending_model.dart';
import 'package:mynt_plus/models/marketwatch_model/scrip_info.dart';
import 'package:mynt_plus/models/order_book_model/modify_order_model.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';
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

/// Full-page Chart Engine shell. Hosts the iframe at
/// `/chart-engine/index.html` and bridges Flutter state ↔ iframe via
/// postMessage. Mirrors the proven patterns from `OrderflowShellScreen`.
class ChartEngineShellScreen extends ConsumerStatefulWidget {
  const ChartEngineShellScreen({super.key});

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
  // Task 2 fix — separate throttle map for linkedScrips retries (2s gate).
  // Kept independent of chartOiDataProvider.fetchedAtByPane which gates
  // the chain-fetch step only.
  final Map<int, int> _linkedScripsAtByPane = {};
  // Task 3 — per-pane option-token subscription map for WS-based OI delivery.
  final Map<int, Map<String, _OiTokenInfo>> _oiSubs = {};
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
    super.dispose();
  }

  /// Forwards the latest WS tick cache to the chart iframe for every
  /// subscribed token, then refreshes WS-based OI for any active pane.
  /// Called from three paths: WS ChangeNotifier, socketDataStream, and the
  /// 1s poll-forward timer — all converge here so a single implementation
  /// covers every delivery mechanism.
  void _wsForwardAll() {
    if (!mounted) return;
    if (_subscribedKeys.isEmpty && _oiSubs.isEmpty) return;
    final ws = ref.read(websocketProvider);
    // Reconnect detection — re-subscribe everything when WS comes back up.
    // The WS provider clears `_sentSubscriptions` on disconnect, so on a
    // fresh reconnect there are no live subscriptions even though our
    // local `_subscribedKeys` set says there should be.
    final nowConnected = ws.wsConnected;
    if (nowConnected && !_lastWsConnected) {
      _resubscribeAll();
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
        if (socketEntry is Map) {
          final raw = socketEntry['oi'];
          if (raw is num) {
            oi = raw.toDouble();
          } else if (raw is String) {
            oi = double.tryParse(raw) ?? oi;
          }
        }
        final chgPct =
            info.poi > 0 ? ((oi - info.poi) / info.poi) * 100 : 0.0;
        final prev = byStrike[info.strike];
        byStrike[info.strike] = ChartOiStrike(
          strike: info.strike,
          callOi: info.isCe ? oi : (prev?.callOi ?? 0),
          putOi: info.isCe ? (prev?.putOi ?? 0) : oi,
          callOiChgPct:
              info.isCe ? chgPct : (prev?.callOiChgPct ?? 0),
          putOiChgPct:
              info.isCe ? (prev?.putOiChgPct ?? 0) : chgPct,
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
        ..style.backgroundColor = '#0B0F14'
        ..allow = 'autoplay'
        ..src = '/chart-engine/index.html?theme=${_currentThemeName()}';
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
      case 'positionTpRequested':
      case 'positionSlRequested': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final ovId = v['overlayId'];
          if (pid is String && ovId is String) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              _handlePositionTpSlRequested(
                  idx, ovId, msg['type'] == 'positionTpRequested');
            }
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
                'dname':    v.dname,
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
      };
      if (packet.length > 1) _post(encodeTick(token, packet));
    }
  }

  void _handleUnsubscribe(dynamic value) {
    if (value is! Map) return;
    final exch = value['exch'] as String?;
    final token = value['token'] as String?;
    if (exch == null || token == null) return;
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
    for (var i = 0; i < session.panes.length; i++) {
      final pane = session.panes[i];
      final overlays = overlaysForPane(
        scrip: pane.scrip,
        positions: positions,
        orders: orders,
        alerts: alerts,
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
    }).catchError((_) {});
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
      final deviceInfo = ref.read(authProvider).deviceInfo;
      final input = buildPlaceOrderInput(
        scrip: scrip,
        qty: qty,
        kind: kind,
        price: price,
        deviceInfo: deviceInfo,
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
    final args = buildOrderScreenArgs(
      scrip: scrip,
      qty: qty,
      kind: kind,
      price: price,
      realScripInfo: realInfo,
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

  void _handleOverlayDragEnded(int paneIndex, String overlayId, double newPrice) {
    final session = ref.read(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) return;
    final scrip = session.panes[paneIndex].scrip;
    if (scrip == null) return;

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
    if (kindPrefix == 'sl' && (order.prctyp == 'SL-LMT')) {
      final oldTrg = double.tryParse(order.trgprc ?? '0') ?? 0;
      final oldLim = double.tryParse(order.prc ?? '0') ?? 0;
      final offset = oldLim - oldTrg;
      newTrigger = newPrice;
      finalNewPrice = newPrice + offset;
    } else if (kindPrefix == 'sl' && order.prctyp == 'SL-MKT') {
      // SL-MKT: only trgprc changes.
      newTrigger = newPrice;
      // finalNewPrice is unused on the server for SL-MKT but the input still
      // requires `prc`; copy the existing.
      finalNewPrice = double.tryParse(order.prc ?? '0') ?? 0;
    }
    // kindPrefix == 'ord' (LMT) and kindPrefix == 'sl-l' (SL-LMT limit only):
    // only `prc` changes; newTrigger stays null → dialog body shows the
    // simpler "from→to" copy and ModifyOrderInput.trgprc falls back to prc.

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

  Future<void> _handlePositionTpSlRequested(
      int paneIndex, String overlayId, bool isTp) async {
    final session = ref.read(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) return;
    final scrip = session.panes[paneIndex].scrip;
    if (scrip == null) return;
    if (!overlayId.startsWith('pos-')) return;

    // Resolve position from the providers (mirrors
    // _handleOverlayCloseRequested for positions).
    final positions =
        ref.read(portfolioProvider).postionBookModel ?? const [];
    PositionBookModel? position;
    for (final p in positions) {
      if (p.exch == scrip.exch &&
          p.token == scrip.token &&
          (int.tryParse(p.netqty ?? '0') ?? 0) != 0) {
        position = p;
        break;
      }
    }
    if (position == null) return;

    final qtyInt = int.tryParse(position.netqty ?? '0') ?? 0;
    if (qtyInt == 0) return;
    final isLong = qtyInt > 0;
    final qtyAbs = qtyInt.abs();
    final avg = double.tryParse(position.netavgprc ?? '') ?? 0;
    if (avg <= 0) return;

    // TP/SL always opens PlaceOrderScreen so the user can review/adjust the
    // pre-filled price and qty before submitting. Even in Instant mode we
    // skip the bypass — opening new exposure deserves a deliberate
    // confirmation; instant only applies to cancel / square-off / drag-
    // modify / quick-place from `+` menu (existing exposure or explicit
    // user gesture).
    var realInfo = _cachedScripInfo(scrip);
    if (realInfo == null) {
      try {
        await ref
            .read(marketWatchProvider)
            .fetchScripInfo(scrip.token, scrip.exch, context, false);
      } catch (_) {}
      if (!mounted) return;
      realInfo = _cachedScripInfo(scrip) ??
          ref.read(marketWatchProvider).scripInfoModel;
    }
    final args = buildTpSlOrderScreenArgs(
      scrip: scrip,
      qty: qtyAbs,
      isLong: isLong,
      isTp: isTp,
      avg: avg,
      realScripInfo: realInfo,
    );
    await ResponsiveNavigation.toPlaceOrderScreen(
        context: context, arguments: args);
  }

  void _handleOverlayCloseRequested(int paneIndex, String overlayId) {
    final session = ref.read(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) return;
    final scrip = session.panes[paneIndex].scrip;
    if (scrip == null) return;

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
            amo: '',
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
        showAlertCancelDialog(context: context, ref: ref, alert: alert);
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
              amo: '',
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
            // Instant: skip dialog, fire cancel directly.
            // ignore: discarded_futures
            ref
                .read(orderProvider)
                .fetchOrderCancel(o.norenordno.toString(), context, false);
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
      final cachedExpiry = expiryCache.nearestByPane[i];
      final cachedScripKey = expiryCache.scripKeyByPane[i];

      // ── Step 1: fetch expiry list if cache is absent or stale ──────────
      // Fire-and-return; next 5s tick will see the cache and proceed to Step 2.
      // Uses _linkedScripsAtByPane (NOT fetchedAtByPane) as the 2s throttle so
      // the chain-fetch gate (fetchedAtByPane) is NOT poisoned by this stamp.
      if (cachedExpiry == null || cachedScripKey != scripKey) {
        final lastLinkedAt = _linkedScripsAtByPane[i] ?? 0;
        if (now - lastLinkedAt < 2000) continue;
        _linkedScripsAtByPane[i] = now;
        // ignore: discarded_futures
        locator<ApiExporter>()
            .getLinkedScrip(scrip.token, scrip.exch)
            .then((linked) {
          if (!mounted) return;
          if (linked.stat != 'Ok' ||
              linked.optExp == null ||
              linked.optExp!.isEmpty) {
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
        }).catchError((_) {});
        continue;
      }

      // ── Step 2: fetch chain with the cached expiry's tsym ──────────────
      final lastAt = oiData.fetchedAtByPane[i] ?? 0;
      if (now - lastAt < refreshMs) continue;
      final spotLtp = _currentSpotLtp(scrip);
      if (spotLtp == null) continue;

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
      }).catchError((_) {
        // Silent — retry on the next 10-min cycle.
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
          ChartEngineTopBar(onPopupVisibilityChanged: _setIframePointerEvents),
          Expanded(
            child: MouseRegion(
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final divider =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

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
            borderRadius: BorderRadius.circular(14),
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
                    const EdgeInsets.fromLTRB(20, 18, 12, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.arrow_back, size: 18, color: muted),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                    control: _ParamStepper(
                      value: _values[p.key] ?? p.defaultValue,
                      param: p,
                      onChanged: (v) => setState(() => _values[p.key] = v),
                    ),
                  ),
                  Divider(height: 1, color: divider, thickness: 1),
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
                Divider(height: 1, color: divider, thickness: 1),
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
              Divider(height: 1, color: divider, thickness: 1),

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
                  // Destructive secondary — text-only, red, clearly labeled
                  // so it's never confused with "close". Sits left so the
                  // visual weight matches the primary Done on the right.
                  TextButton.icon(
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline,
                        size: 16,
                        color: resolveThemeColor(context,
                            dark: MyntColors.lossDark,
                            light: MyntColors.loss)),
                    label: Text('Remove',
                        style: TextStyle(
                          color: resolveThemeColor(context,
                              dark: MyntColors.lossDark,
                              light: MyntColors.loss),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        )),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GradientPrimaryButton(
                      label: 'Done',
                      onPressed: _save,
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

class _ParamStepper extends StatelessWidget {
  final num value;
  final IndicatorParam param;
  final ValueChanged<num> onChanged;
  const _ParamStepper({
    required this.value,
    required this.param,
    required this.onChanged,
  });

  num _clamp(num v) {
    if (v < param.min) return param.min;
    if (v > param.max) return param.max;
    return v;
  }

  num _normalize(num v) {
    if (param.isInt) return v.toInt();
    // Round to step precision to avoid float drift (0.1 + 0.1 + … = 0.30000004).
    final stepInv = 1 / param.step;
    return (v * stepInv).round() / stepInv;
  }

  String _format(num v) {
    if (param.isInt) return v.toInt().toString();
    // Show one decimal for typical 0.1-step floats; strip trailing zero.
    final fixed = v.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2030) : const Color(0xFFF8FAFC);
    final stroke =
        isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);
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
            onTap: () => onChanged(_normalize(_clamp(value - param.step))),
          ),
          Expanded(
            child: Center(
              child: Text(_format(value),
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.semiBold)),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            color: iconColor,
            onTap: () => onChanged(_normalize(_clamp(value + param.step))),
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

class _ColorButton extends StatelessWidget {
  final String color;
  final bool open;
  final VoidCallback onTap;
  const _ColorButton(
      {required this.color, required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stroke =
        isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ringIdle = isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2030) : const Color(0xFFF8FAFC);
    final stroke =
        isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);

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
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF7C3AED), Color(0xFFEC4899), Color(0xFFF59E0B)],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED)
                    .withValues(alpha: _hover ? 0.45 : 0.28),
                blurRadius: _hover ? 22 : 14,
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
