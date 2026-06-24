import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Pure encoders for the messages the shell posts into the iframe.
/// Keeping these as functions (not methods) makes them easy to unit-test
/// independently of the shell's `dart:html` host code.
String encodeSetTheme(String theme) =>
    jsonEncode({'type': 'setTheme', 'value': theme});

String encodeSetPaneSymbol(String paneId, Map<String, dynamic> scrip) =>
    jsonEncode({'type': 'setPaneSymbol', 'value': {'paneId': paneId, 'scrip': scrip}});

String encodeSetPaneTimeframe(String paneId, int minutes) =>
    jsonEncode({'type': 'setPaneTimeframe', 'value': {'paneId': paneId, 'minutes': minutes}});

String encodeSetOverlays(String paneId, Map<String, dynamic> overlays) =>
    jsonEncode({'type': 'setOverlays', 'value': {'paneId': paneId, ...overlays}});

String encodeHistoryResult(String requestId, List<Map<String, dynamic>> candles) =>
    jsonEncode({'type': 'historyResult', 'value': {'requestId': requestId, 'candles': candles}});

String encodeHistoryError(String requestId, String message) =>
    jsonEncode({'type': 'historyError', 'value': {'requestId': requestId, 'message': message}});

String encodeTick(String token, Map<String, dynamic> packet) =>
    jsonEncode({'type': 'tick', 'value': {'token': token, 'packet': packet}});

String encodeWsReconnected() =>
    jsonEncode({'type': 'wsReconnected'});

/// Ask the engine to apply [scrip] to its currently-active pane (the one with
/// the live `.pane.active` marker). The engine replies with `paneSymbolApplied`
/// carrying the exact paneId so the store can sync.
String encodeApplyActiveSymbol(Map<String, dynamic> scrip) =>
    jsonEncode({'type': 'applyActiveSymbol', 'value': {'scrip': scrip}});

String encodeSetLayout({
  required String id,
  required String areas,
  required String rows,
  required String columns,
  required int paneCount,
}) =>
    jsonEncode({
      'type': 'setLayout',
      'value': {
        'id': id,
        'areas': areas,
        'rows': rows,
        'columns': columns,
        'paneCount': paneCount,
      },
    });

String encodeSetActivePane(String paneId) =>
    jsonEncode({'type': 'setActivePane', 'value': {'paneId': paneId}});

String encodeSetPaneOverlays(
    String paneId, List<Map<String, Object?>> overlays) =>
    jsonEncode({
      'type': 'setPaneOverlays',
      'value': {'paneId': paneId, 'overlays': overlays},
    });

String encodeSetPaneQty(String paneId, int qty) =>
    jsonEncode({'type': 'setPaneQty', 'value': {'paneId': paneId, 'qty': qty}});

String encodeUnpinCrosshair(String paneId) =>
    jsonEncode({'type': 'unpinCrosshair', 'value': {'paneId': paneId}});

String encodeSetPaneDrawings(
        String paneId, List<Map<String, Object?>> drawings) =>
    jsonEncode({
      'type': 'setPaneDrawings',
      'value': {'paneId': paneId, 'drawings': drawings},
    });

String encodeSetDrawMode(String? kind) => jsonEncode({
      'type': 'setDrawMode',
      'value': {'kind': kind},
    });

String encodeSetShortcutsEnabled(bool enabled) => jsonEncode({
      'type': 'setShortcutsEnabled',
      'value': {'enabled': enabled},
    });

String encodeSetPaneCandleStyle(String paneId, String style) =>
    jsonEncode({
      'type': 'setPaneCandleStyle',
      'value': {'paneId': paneId, 'style': style},
    });

String encodeSetPaneHighLowMarkers(String paneId, bool show) =>
    jsonEncode({
      'type': 'setPaneHighLowMarkers',
      'value': {'paneId': paneId, 'show': show},
    });

String encodeSetPaneShowOptionChainOi(String paneId, bool show) =>
    jsonEncode({
      'type': 'setPaneShowOptionChainOi',
      'value': {'paneId': paneId, 'show': show},
    });

String encodeSetPaneShowBarCountdown(String paneId, bool show) =>
    jsonEncode({
      'type': 'setPaneShowBarCountdown',
      'value': {'paneId': paneId, 'show': show},
    });

String encodeSetPaneShowKeyLevels(String paneId, bool show) =>
    jsonEncode({
      'type': 'setPaneShowKeyLevels',
      'value': {'paneId': paneId, 'show': show},
    });

String encodeSetPanePivotVariant(String paneId, String variant) =>
    jsonEncode({
      'type': 'setPanePivotVariant',
      'value': {'paneId': paneId, 'variant': variant},
    });

String encodeSetPaneMagnetEnabled(String paneId, bool enabled) =>
    jsonEncode({
      'type': 'setPaneMagnetEnabled',
      'value': {'paneId': paneId, 'enabled': enabled},
    });

String encodeSetPaneShowVolumeProfile(String paneId, bool show) =>
    jsonEncode({
      'type': 'setPaneShowVolumeProfile',
      'value': {'paneId': paneId, 'show': show},
    });

String encodeSetDrawingsLocked(bool locked) => jsonEncode({
      'type': 'setDrawingsLocked',
      'value': {'locked': locked},
    });

String encodeSetDrawingsHidden(bool hidden) => jsonEncode({
      'type': 'setDrawingsHidden',
      'value': {'hidden': hidden},
    });

String encodeSetPaneOiData(
        String paneId, List<Map<String, Object?>> strikes) =>
    jsonEncode({
      'type': 'setPaneOiData',
      'value': {'paneId': paneId, 'strikes': strikes},
    });

String encodeSetPaneIndicators(
        String paneId, List<Map<String, Object?>> indicators) =>
    jsonEncode({
      'type': 'setPaneIndicators',
      'value': {'paneId': paneId, 'indicators': indicators},
    });

String encodeSetPaneShowAutoPattern(String paneId, bool show) =>
    jsonEncode({
      'type': 'setPaneShowAutoPattern',
      'value': {'paneId': paneId, 'show': show},
    });

String encodeSetPaneShowCrosshairLines(String paneId, bool show) =>
    jsonEncode({
      'type': 'setPaneShowCrosshairLines',
      'value': {'paneId': paneId, 'show': show},
    });

String encodeTakeScreenshot(String paneId) =>
    jsonEncode({
      'type': 'takeScreenshot',
      'value': {'paneId': paneId},
    });

/// Decode a message from the iframe. Returns null if the payload isn't a
/// recognizable `{type, value}` object. Accepts both JSON strings and Maps.
Map<String, dynamic>? decodeIframeMessage(Object? raw) {
  if (raw is String) {
    try {
      final d = jsonDecode(raw);
      if (d is Map && d['type'] is String) return Map<String, dynamic>.from(d);
    } catch (_) { /* not JSON */ }
  }
  if (raw is Map && raw['type'] is String) return Map<String, dynamic>.from(raw);
  return null;
}

/// Post a JSON-string message to an iframe's contentWindow.
void postToIframe(html.IFrameElement iframe, String payload) {
  iframe.contentWindow?.postMessage(payload, '*');
}

String encodeSetChartPalette(Map<String, String> palette) =>
    jsonEncode({
      'type': 'setChartPalette',
      'value': {'palette': palette},
    });

String encodeSetScripTradable(String paneId, bool tradable) =>
    jsonEncode({
      'type': 'setScripTradable',
      'value': {'paneId': paneId, 'tradable': tradable},
    });

/// Fire-and-forget push of the current INSTANT-orders flag to the iframe.
/// Used both on bootstrap (initial sync) and whenever the flag changes for
/// any reason other than the JS-side badge (e.g. the Settings panel that
/// still lives in Flutter mirrors its switch through this).
String encodeSetInstantOrders(bool value) =>
    jsonEncode({
      'type': 'setInstantOrders',
      'value': {'value': value},
    });

/// One-shot push of the full layout catalog so the JS layout picker can
/// render its grid without re-implementing the enum. Each entry mirrors
/// the spec already sent piecewise via `setLayout`.
String encodeSetLayoutCatalog(List<Map<String, dynamic>> layouts) =>
    jsonEncode({
      'type': 'setLayoutCatalog',
      'value': {'layouts': layouts},
    });

/// Notifies the iframe which layout id is currently active. Sent on
/// bootstrap and whenever Flutter (or the JS picker via writeback) changes
/// it. Distinct from `setLayout` which carries the full grid spec; this
/// is just the id so the JS picker can highlight the current tile.
String encodeSetActiveLayoutId(String id) =>
    jsonEncode({
      'type': 'setActiveLayoutId',
      'value': {'id': id},
    });

/// Bundle of the active pane's per-pane top-bar state. Pushed on bootstrap,
/// on every active-pane switch, and whenever the active pane's relevant
/// fields change. The JS top bar uses this single message to keep its
/// per-pane controls (Timeframe, Style, Cursor mode, …) in sync — no need
/// to track per-pane state for the whole grid.
String encodeSetActivePaneTopBarState({
  required int timeframeMinutes,
  required String candleStyle,
  required bool showCrosshairLines,
  required List<Map<String, dynamic>> indicators,
}) =>
    jsonEncode({
      'type': 'setActivePaneTopBarState',
      'value': {
        'timeframeMinutes': timeframeMinutes,
        'candleStyle': candleStyle,
        'showCrosshairLines': showCrosshairLines,
        'indicators': indicators,
      },
    });

/// Reply to a JS-initiated `bridge.request(...)`. `replyId` is the
/// correlation id JS sent on the original message (as `replyTo`); JS uses
/// it to fulfil the matching promise.
String encodeReply(String replyId, Map<String, dynamic> payload) =>
    jsonEncode({
      'type': 'reply',
      'value': {'replyId': replyId, 'payload': payload},
    });

/// Pushes the full Order Defaults bag to the iframe. Sent on bootstrap and
/// whenever the Riverpod provider changes for any reason. JS owns the
/// popover UI but stays a read-through view of this Flutter state.
String encodeSetOrderDefaults(Map<String, dynamic> bag) =>
    jsonEncode({
      'type': 'setOrderDefaults',
      'value': bag,
    });

/// Pushes the active pane's "View on chart" Settings tab state to the JS
/// popover. Separate from `setActivePaneTopBarState` to keep both selectors
/// small (this one re-fires when any view toggle changes, which is more
/// often than Timeframe / Style / etc.).
String encodeSetActivePaneViewState(Map<String, dynamic> bag) =>
    jsonEncode({
      'type': 'setActivePaneViewState',
      'value': bag,
    });

/// Pushes the session-level keyboard-shortcuts flag for the Settings
/// popover's last toggle. Distinct from the existing `setShortcutsEnabled`
/// which targets the chart's key handler — same value, different consumer.
String encodeSetKeyboardShortcutsState(bool value) =>
    jsonEncode({
      'type': 'setKeyboardShortcutsState',
      'value': {'value': value},
    });

/// Pushes the full Customize palette bag (including blanks) so the JS
/// Settings popover renders the current values + "reset" affordances.
/// Distinct from `setChartPalette` which is consumed by the chart's
/// renderer — this targets the popover's input fields.
String encodeSetChartPaletteState(Map<String, dynamic> bag) =>
    jsonEncode({
      'type': 'setChartPaletteState',
      'value': bag,
    });

/// Pushes the active pane's current scrip so the JS Symbol typeahead can
/// render the chosen symbol's display name in its input field. Sent on
/// bootstrap and whenever the active pane switches or its symbol changes
/// (e.g. user picks from watchlist or option chain).
String encodeSetActivePaneSymbol(Map<String, dynamic>? scrip) =>
    jsonEncode({
      'type': 'setActivePaneSymbol',
      'value': {'scrip': scrip},
    });

/// Toggles the chart's "lite" mode for the explain view. In lite mode the
/// JS engine suppresses click handlers tied to ordering (plus button, bid /
/// ask click, qty chip) — the explain view is read-only.
String encodeSetLiteMode(bool value) => jsonEncode({
      'type': 'setLiteMode',
      'value': {'value': value},
    });

/// Hands the chart a pre-baked scan-explanation payload: bars, per-bar
/// boolean match mask, server-computed indicator series, and column
/// metadata (sub-panel placement + color hints). The chart renders these
/// directly without going through the normal data subscription or local
/// indicator pipeline.
String encodeSetExplanationData({
  required String paneId,
  required List<Map<String, dynamic>> bars,
  required Map<String, List<double?>> indicators,
  required List<bool> matched,
  required List<Map<String, dynamic>> columns,
  required String ticker,
  String? displayName,
}) =>
    jsonEncode({
      'type': 'setExplanationData',
      'value': {
        'paneId': paneId,
        'bars': bars,
        'indicators': indicators,
        'matched': matched,
        'columns': columns,
        'ticker': ticker,
        if (displayName != null) 'displayName': displayName,
      },
    });
