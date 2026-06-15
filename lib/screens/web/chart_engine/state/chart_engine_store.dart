import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/option_underlying_match.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All supported chart layouts. The enum NAME is the persistence id and the
/// postMessage value — keep stable across versions.
enum ChartLayout {
  single  (paneCount: 1, areas: '"a"',                       rows: '1fr',         columns: '1fr'),
  cols2   (paneCount: 2, areas: '"a b"',                     rows: '1fr',         columns: '1fr 1fr'),
  rows2   (paneCount: 2, areas: '"a" "b"',                   rows: '1fr 1fr',     columns: '1fr'),
  cols3   (paneCount: 3, areas: '"a b c"',                   rows: '1fr',         columns: '1fr 1fr 1fr'),
  rows3   (paneCount: 3, areas: '"a" "b" "c"',               rows: '1fr 1fr 1fr', columns: '1fr'),
  t1b2    (paneCount: 3, areas: '"a a" "b c"',               rows: '1fr 1fr',     columns: '1fr 1fr'),
  t2b1    (paneCount: 3, areas: '"a b" "c c"',               rows: '1fr 1fr',     columns: '1fr 1fr'),
  l1r2    (paneCount: 3, areas: '"a b" "a c"',               rows: '1fr 1fr',     columns: '1fr 1fr'),
  l2r1    (paneCount: 3, areas: '"a c" "b c"',               rows: '1fr 1fr',     columns: '1fr 1fr'),
  grid2x2 (paneCount: 4, areas: '"a b" "c d"',               rows: '1fr 1fr',     columns: '1fr 1fr'),
  cols4   (paneCount: 4, areas: '"a b c d"',                 rows: '1fr',         columns: '1fr 1fr 1fr 1fr'),
  rows4   (paneCount: 4, areas: '"a" "b" "c" "d"',           rows: '1fr 1fr 1fr 1fr', columns: '1fr'),
  t1b3    (paneCount: 4, areas: '"a a a" "b c d"',           rows: '1fr 1fr',     columns: '1fr 1fr 1fr'),
  t3b1    (paneCount: 4, areas: '"a b c" "d d d"',           rows: '1fr 1fr',     columns: '1fr 1fr 1fr'),
  l1r3    (paneCount: 4, areas: '"a b" "a c" "a d"',         rows: '1fr 1fr 1fr', columns: '1fr 1fr'),
  l3r1    (paneCount: 4, areas: '"a d" "b d" "c d"',         rows: '1fr 1fr 1fr', columns: '1fr 1fr'),
  t1b4    (paneCount: 5, areas: '"a a a a" "b c d e"',       rows: '1fr 1fr',     columns: '1fr 1fr 1fr 1fr'),
  t4b1    (paneCount: 5, areas: '"a b c d" "e e e e"',       rows: '1fr 1fr',     columns: '1fr 1fr 1fr 1fr'),
  l1r4    (paneCount: 5, areas: '"a b" "a c" "a d" "a e"',   rows: '1fr 1fr 1fr 1fr', columns: '1fr 1fr'),
  l4r1    (paneCount: 5, areas: '"a e" "b e" "c e" "d e"',   rows: '1fr 1fr 1fr 1fr', columns: '1fr 1fr'),
  t2b3    (paneCount: 5, areas: '"a a a b b b" "c c d d e e"', rows: '1fr 1fr',   columns: '1fr 1fr 1fr 1fr 1fr 1fr'),
  grid3x2 (paneCount: 6, areas: '"a b c" "d e f"',           rows: '1fr 1fr',     columns: '1fr 1fr 1fr'),
  grid2x3 (paneCount: 6, areas: '"a b" "c d" "e f"',         rows: '1fr 1fr 1fr', columns: '1fr 1fr');

  const ChartLayout({
    required this.paneCount,
    required this.areas,
    required this.rows,
    required this.columns,
  });

  final int paneCount;
  final String areas;    // CSS grid-template-areas
  final String rows;     // CSS grid-template-rows
  final String columns;  // CSS grid-template-columns

  /// Letter for the area at this pane index (0→a, 1→b, …, 5→f).
  String areaLetter(int paneIndex) =>
      String.fromCharCode('a'.codeUnitAt(0) + paneIndex);

  /// Stable id used in postMessage payloads + persistence.
  String get id => name;

  static ChartLayout? fromId(String id) {
    for (final l in ChartLayout.values) {
      if (l.id == id) return l;
    }
    return null;
  }
}

/// A single anchor point of a chart drawing.
class DrawingPoint {
  final double price;
  final int ts; // epoch seconds; ignored for hline
  const DrawingPoint({required this.price, required this.ts});

  Map<String, dynamic> toJson() => {'price': price, 'ts': ts};

  static DrawingPoint fromJson(Map<String, dynamic> j) => DrawingPoint(
        price: (j['price'] as num?)?.toDouble() ?? 0,
        ts: (j['ts'] as num?)?.toInt() ?? 0,
      );
}

/// User-placed on-chart drawing (Phase 7). HLine has 1 point, Trendline 2.
class ChartDrawing {
  final String id;
  final String kind; // 'hline' | 'trendline' | 'rect' | 'hray' | 'fib' | 'path'
  final String color;
  final List<DrawingPoint> points;
  // Per-drawing lock — when true, the drawing's drag-band and delete chip
  // are ignored in chart.js. Independent of the global `drawingsLocked` flag
  // (which locks everything).
  final bool locked;
  // Stroke width in px (1..4). Defaults to 1 so old persisted drawings still
  // render at the same look. Picked up by chart.js as ctx.lineWidth.
  final int thickness;
  const ChartDrawing({
    required this.id,
    required this.kind,
    required this.color,
    required this.points,
    this.locked = false,
    this.thickness = 1,
  });

  ChartDrawing copyWith({
    String? id,
    String? kind,
    String? color,
    List<DrawingPoint>? points,
    bool? locked,
    int? thickness,
  }) =>
      ChartDrawing(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        color: color ?? this.color,
        points: points ?? this.points,
        locked: locked ?? this.locked,
        thickness: thickness ?? this.thickness,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'color': color,
        'points': [for (final p in points) p.toJson()],
        if (locked) 'locked': true,
        if (thickness != 1) 'thickness': thickness,
      };

  static ChartDrawing fromJson(Map<String, dynamic> j) => ChartDrawing(
        id: j['id'] as String? ?? '',
        kind: j['kind'] as String? ?? 'hline',
        color: j['color'] as String? ?? '#3B82F6',
        points: [
          for (final p in (j['points'] as List? ?? const []))
            DrawingPoint.fromJson(p as Map<String, dynamic>),
        ],
        locked: j['locked'] as bool? ?? false,
        thickness: (j['thickness'] as num?)?.toInt().clamp(1, 4) ?? 1,
      );
}

/// Resolved scrip pushed to the chart engine when the user picks a symbol.
class ChartScrip {
  final String exch;
  final String token;
  final String tsym;
  final String dispName;
  final int ls;
  final double ti;
  /// Broker `instname` field. Used by the chart to detect non-tradable
  /// instruments (`UNDIND` / `INDEX` = index spot, `COM` = commodity).
  /// Empty string for legacy / unknown.
  final String instname;
  const ChartScrip({
    required this.exch,
    required this.token,
    required this.tsym,
    required this.dispName,
    required this.ls,
    required this.ti,
    this.instname = '',
  });

  Map<String, dynamic> toJson() => {
        'exch': exch,
        'token': token,
        'tsym': tsym,
        'dispName': dispName,
        'ls': ls,
        'ti': ti,
        'instname': instname,
      };

  static ChartScrip fromJson(Map<String, dynamic> j) => ChartScrip(
        exch: j['exch'] as String? ?? '',
        token: j['token'] as String? ?? '',
        tsym: j['tsym'] as String? ?? '',
        dispName: j['dispName'] as String? ?? '',
        ls: (j['ls'] as num?)?.toInt() ?? 1,
        ti: (j['ti'] as num?)?.toDouble() ?? 0.05,
        instname: j['instname'] as String? ?? '',
      );

  ChartScrip copyWith({
    String? exch,
    String? token,
    String? tsym,
    String? dispName,
    int? ls,
    double? ti,
    String? instname,
  }) =>
      ChartScrip(
        exch: exch ?? this.exch,
        token: token ?? this.token,
        tsym: tsym ?? this.tsym,
        dispName: dispName ?? this.dispName,
        ls: ls ?? this.ls,
        ti: ti ?? this.ti,
        instname: instname ?? this.instname,
      );
}

/// User-toggleable chart overlays for a pane. All default to on.
class ChartOverlays {
  final bool gridlines;
  final bool volume;
  const ChartOverlays({this.gridlines = true, this.volume = true});

  ChartOverlays copyWith({bool? gridlines, bool? volume}) => ChartOverlays(
        gridlines: gridlines ?? this.gridlines,
        volume: volume ?? this.volume,
      );

  Map<String, dynamic> toJson() =>
      {'gridlines': gridlines, 'volume': volume};

  static ChartOverlays fromJson(Map<String, dynamic> j) => ChartOverlays(
        gridlines: j['gridlines'] as bool? ?? true,
        volume: j['volume'] as bool? ?? true,
      );
}

/// Per-pane technical indicator (Phase 8). Period-driven; computed in the
/// iframe each draw against the pane's candles.
/// Default color (hex) for a newly-added indicator. Single source of truth
/// shared by the Flutter Indicators popover and the JS-driven add path.
String defaultIndicatorColor(String kind) {
  switch (kind) {
    case 'sma':      return '#3B82F6';
    case 'ema':      return '#F59E0B';
    case 'rsi':      return '#8B5CF6';
    case 'bb':       return '#8B5CF6';
    case 'vwap':     return '#06B6D4';
    case 'macd':     return '#3B82F6';
    case 'stoch':    return '#8B5CF6';
    case 'atr':      return '#10B981';
    case 'zlema':    return '#EC4899';
    case 'mcginley': return '#0EA5E9';
    case 'stochrsi': return '#A855F7';
    case 'squeeze':  return '#22D3EE';
    case 'efi':      return '#84CC16';
    case 'ribbon':   return '#3B82F6';
    case 'ichi':     return '#10B981';
    case 'vstop':    return '#22C55E';
    case 'wt':       return '#3B82F6';
    case 'crsi':     return '#8B5CF6';
    case 'ao':       return '#22C55E';
    case 'mfi':      return '#06B6D4';
    case 'obv':      return '#84CC16';
    case 'cmf':      return '#A855F7';
    case 'wr':       return '#F59E0B';
    case 'cisd':     return '#22C55E';
    case 'fvg':      return '#22C55E';
    case 'ob':       return '#22C55E';
    case 'liqsweep': return '#22C55E';
    case 'mss':      return '#22C55E';
  }
  return '#3B82F6';
}

/// Default period for a newly-added indicator. 0 = "no period" (used by
/// VWAP, OBV, AO, RIBBON — kinds with no scalar lookback).
int defaultIndicatorPeriod(String kind) {
  switch (kind) {
    case 'rsi':      return 14;
    case 'macd':     return 12;
    case 'stoch':    return 14;
    case 'atr':      return 14;
    case 'bb':       return 20;
    case 'vwap':     return 0;
    case 'zlema':    return 20;
    case 'mcginley': return 14;
    case 'stochrsi': return 14;
    case 'squeeze':  return 20;
    case 'efi':      return 13;
    case 'ribbon':   return 0;
    case 'ichi':     return 26;
    case 'vstop':    return 14;
    case 'wt':       return 10;
    case 'crsi':     return 3;
    case 'ao':       return 0;
    case 'mfi':      return 14;
    case 'obv':      return 0;
    case 'cmf':      return 20;
    case 'wr':       return 14;
    case 'cisd':     return 0;
    case 'fvg':      return 0;
    case 'ob':       return 14;
    case 'liqsweep': return 0;
    case 'mss':      return 0;
    default:         return 20;
  }
}

class IndicatorConfig {
  final String id;       // stable per-instance
  final String kind;     // 'sma' / 'ema' / 'rsi'
  final int period;      // clamp 1..999
  final String color;    // hex
  // Per-indicator hide toggle for the chip strip at top of the chart. When
  // true, the indicator is skipped during draw but stays in the config list
  // so the user can re-enable it without losing period/color settings.
  final bool hidden;
  // Line width in pixels — 1 (default), 2, or 3. Picked up by chart.js as
  // ctx.lineWidth for whichever stroke renders the indicator. Sub-pane
  // oscillators that draw multiple lines (BB, MACD, etc.) apply this
  // uniformly so the indicator reads cleanly.
  final int thickness;
  // Kind-specific parameter bag (Phase 26). Empty for single-`period` kinds
  // that pre-date the schema-driven settings dialog; chart.js falls back to
  // [period] when the key is absent so old persisted configs keep working.
  final Map<String, num> params;
  const IndicatorConfig({
    required this.id,
    required this.kind,
    required this.period,
    required this.color,
    this.hidden = false,
    this.thickness = 1,
    this.params = const {},
  });

  IndicatorConfig copyWith({
    int? period,
    String? color,
    bool? hidden,
    int? thickness,
    Map<String, num>? params,
  }) =>
      IndicatorConfig(
        id: id,
        kind: kind,
        period: period ?? this.period,
        color: color ?? this.color,
        hidden: hidden ?? this.hidden,
        thickness: thickness ?? this.thickness,
        params: params ?? this.params,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'period': period,
        'color': color,
        if (hidden) 'hidden': true,
        if (thickness != 1) 'thickness': thickness,
        if (params.isNotEmpty) 'params': {for (final e in params.entries) e.key: e.value},
      };

  static IndicatorConfig fromJson(Map<String, dynamic> j) {
    final rawParams = j['params'];
    final parsedParams = <String, num>{};
    if (rawParams is Map) {
      for (final entry in rawParams.entries) {
        final k = entry.key;
        final v = entry.value;
        if (k is String && v is num) parsedParams[k] = v;
      }
    }
    return IndicatorConfig(
      id: j['id'] as String? ?? '',
      kind: j['kind'] as String? ?? 'sma',
      period: (j['period'] as num?)?.toInt() ?? 20,
      color: j['color'] as String? ?? '#3B82F6',
      hidden: j['hidden'] as bool? ?? false,
      thickness: (j['thickness'] as num?)?.toInt().clamp(1, 4) ?? 1,
      params: parsedParams,
    );
  }
}

/// Per-pane state.
class PaneState {
  final ChartScrip? scrip;
  final int timeframeMinutes;
  final ChartOverlays overlays;
  final int qty;
  final List<IndicatorConfig> indicators;
  // Phase 15 — per-pane override for the global Instant orders flag.
  // 'on'  → force instant for this pane regardless of global.
  // 'off' → force confirm for this pane regardless of global.
  // null  → follow the session-level `instantOrders`.
  final String? instantOverride;
  // Phase 16 — one of: 'candles' (default), 'hollow', 'bars', 'line',
  // 'area', 'heikin-ashi', 'renko'. Unknown values are coerced to 'candles'
  // by fromJson so a typo in prefs can't poison the chart.
  final String candleStyle;
  // Phase 16 — show/hide the visible-range high/low price markers. Default ON.
  final bool showHighLowMarkers;
  // Phase 18 — show option-chain OI bars at strike prices on the underlying
  // chart. Default OFF (fetching adds API load); user opts in per pane.
  final bool showOptionChainOi;
  // Phase 18 — show "time until current bar closes" countdown extension on
  // the LTP chip. Default ON.
  final bool showBarCountdown;
  // Phase 20 — show classical-pivot Key Levels (PP, R1-R3, S1-S3). Default OFF.
  final bool showKeyLevels;
  // Phase 23 — pivot variant for the Key Levels overlay.
  // 'classical' (default), 'fibonacci', 'camarilla'.
  final String pivotVariant;
  // Phase 23 — drawing magnet (snap to nearest OHLC of the candle under cursor).
  final bool magnetEnabled;
  // Phase 23 — right-gutter volume profile histogram.
  final bool showVolumeProfile;
  // Phase 25 — auto-pattern detection overlay (HH/HL/LH/LL). Default OFF.
  final bool showAutoPattern;
  // Crosshair LINES on/off (the price/time chips always render). Default ON.
  final bool showCrosshairLines;
  const PaneState({
    this.scrip,
    this.timeframeMinutes = 1,
    this.overlays = const ChartOverlays(),
    this.qty = 1,
    this.indicators = const [],
    this.instantOverride,
    this.candleStyle = 'candles',
    this.showHighLowMarkers = true,
    this.showOptionChainOi = false,
    this.showBarCountdown = true,
    this.showKeyLevels = false,
    this.pivotVariant = 'classical',
    this.magnetEnabled = false,
    this.showVolumeProfile = false,
    this.showAutoPattern = false,
    this.showCrosshairLines = true,
  });

  PaneState copyWith({
    Object? scrip = _sentinel,
    int? timeframeMinutes,
    ChartOverlays? overlays,
    int? qty,
    List<IndicatorConfig>? indicators,
    Object? instantOverride = _sentinel,
    String? candleStyle,
    bool? showHighLowMarkers,
    bool? showOptionChainOi,
    bool? showBarCountdown,
    bool? showKeyLevels,
    String? pivotVariant,
    bool? magnetEnabled,
    bool? showVolumeProfile,
    bool? showAutoPattern,
    bool? showCrosshairLines,
  }) =>
      PaneState(
        scrip: identical(scrip, _sentinel) ? this.scrip : scrip as ChartScrip?,
        timeframeMinutes: timeframeMinutes ?? this.timeframeMinutes,
        overlays: overlays ?? this.overlays,
        qty: qty ?? this.qty,
        indicators: indicators ?? this.indicators,
        instantOverride: identical(instantOverride, _sentinel)
            ? this.instantOverride
            : instantOverride as String?,
        candleStyle: candleStyle ?? this.candleStyle,
        showHighLowMarkers: showHighLowMarkers ?? this.showHighLowMarkers,
        showOptionChainOi: showOptionChainOi ?? this.showOptionChainOi,
        showBarCountdown: showBarCountdown ?? this.showBarCountdown,
        showKeyLevels: showKeyLevels ?? this.showKeyLevels,
        pivotVariant: pivotVariant ?? this.pivotVariant,
        magnetEnabled: magnetEnabled ?? this.magnetEnabled,
        showVolumeProfile: showVolumeProfile ?? this.showVolumeProfile,
        showAutoPattern: showAutoPattern ?? this.showAutoPattern,
        showCrosshairLines:
            showCrosshairLines ?? this.showCrosshairLines,
      );

  Map<String, dynamic> toJson() => {
        if (scrip != null) 'scrip': scrip!.toJson(),
        'timeframeMinutes': timeframeMinutes,
        'overlays': overlays.toJson(),
        'qty': qty,
        'indicators': [for (final i in indicators) i.toJson()],
        if (instantOverride != null) 'instantOverride': instantOverride,
        if (candleStyle != 'candles') 'candleStyle': candleStyle,
        if (showHighLowMarkers != true) 'showHighLowMarkers': showHighLowMarkers,
        if (showOptionChainOi != false) 'showOptionChainOi': showOptionChainOi,
        if (showBarCountdown != true) 'showBarCountdown': showBarCountdown,
        if (showKeyLevels != false) 'showKeyLevels': showKeyLevels,
        if (pivotVariant != 'classical') 'pivotVariant': pivotVariant,
        if (magnetEnabled != false) 'magnetEnabled': magnetEnabled,
        if (showVolumeProfile != false) 'showVolumeProfile': showVolumeProfile,
        if (showAutoPattern != false) 'showAutoPattern': showAutoPattern,
        if (showCrosshairLines != true)
          'showCrosshairLines': showCrosshairLines,
      };

  // Phase 16 — Renko is intentionally excluded for now. The JS engine still
  // contains the Renko draw/transform code (kept as dead code, gated by
  // candleStyle), but the picker doesn't expose it. Any old persisted
  // 'renko' value is silently coerced to 'candles' by the absence here.
  static const _validStyles = <String>{
    'candles', 'hollow', 'bars', 'line', 'area', 'heikin-ashi',
  };

  static PaneState fromJson(Map<String, dynamic> j) {
    final rawOverride = j['instantOverride'];
    final String? override =
        (rawOverride == 'on' || rawOverride == 'off') ? rawOverride : null;
    final rawStyle = j['candleStyle'] as String?;
    final String style = (rawStyle != null && _validStyles.contains(rawStyle))
        ? rawStyle
        : 'candles';
    final bool show = j['showHighLowMarkers'] as bool? ?? true;
    final bool showOi = j['showOptionChainOi'] as bool? ?? false;
    final bool showCd = j['showBarCountdown'] as bool? ?? true;
    final bool showKl = j['showKeyLevels'] as bool? ?? false;
    final rawPivot = j['pivotVariant'] as String?;
    final String pivot = (rawPivot == 'fibonacci' || rawPivot == 'camarilla')
        ? rawPivot! : 'classical';
    final bool magnet = j['magnetEnabled'] as bool? ?? false;
    final bool showVp = j['showVolumeProfile'] as bool? ?? false;
    final bool showAp = j['showAutoPattern'] as bool? ?? false;
    final bool showXh = j['showCrosshairLines'] as bool? ?? true;
    return PaneState(
      scrip: j['scrip'] is Map
          ? ChartScrip.fromJson(j['scrip'] as Map<String, dynamic>)
          : null,
      timeframeMinutes: (j['timeframeMinutes'] as num?)?.toInt() ?? 1,
      overlays: j['overlays'] is Map
          ? ChartOverlays.fromJson(j['overlays'] as Map<String, dynamic>)
          : const ChartOverlays(),
      qty: (j['qty'] as num?)?.toInt() ?? 1,
      indicators: [
        for (final i in (j['indicators'] as List? ?? const []))
          IndicatorConfig.fromJson(i as Map<String, dynamic>),
      ],
      instantOverride: override,
      candleStyle: style,
      showHighLowMarkers: show,
      showOptionChainOi: showOi,
      showBarCountdown: showCd,
      showKeyLevels: showKl,
      pivotVariant: pivot,
      magnetEnabled: magnet,
      showVolumeProfile: showVp,
      showAutoPattern: showAp,
      showCrosshairLines: showXh,
    );
  }
}

const Object _sentinel = Object();

/// Full chart-engine session state. Phase 2: positional `List<PaneState>` +
/// layout enum + activePaneIndex.
class ChartEngineSession {
  final ChartLayout layout;
  final int activePaneIndex;
  final List<PaneState> panes;
  final bool instantOrders;
  final bool instantWarningAck;
  // Phase 7 — per-scrip drawings keyed by 'EXCH|TOKEN'.
  final Map<String, List<ChartDrawing>> drawings;
  // Phase 7 — currently selected draw tool ('hline' / 'trendline' / null).
  // NOT persisted (UI-only state; resets to null on hydrate).
  final String? activeDrawTool;
  // Phase 14.1 — keyboard shortcuts enabled (default OFF). When OFF, the
  // chart's keydown listener ignores everything except Esc.
  final bool keyboardShortcuts;
  // Phase 23 — global drawing lock (disables drawing drag/delete) and
  // drawing hide (suppresses render). Session-level, not per-pane —
  // applies to all drawings in all panes.
  final bool drawingsLocked;
  final bool drawingsHidden;

  const ChartEngineSession({
    this.layout = ChartLayout.single,
    this.activePaneIndex = 0,
    this.panes = const [PaneState()],
    this.instantOrders = false,
    this.instantWarningAck = false,
    this.drawings = const {},
    this.activeDrawTool,
    this.keyboardShortcuts = false,
    this.drawingsLocked = false,
    this.drawingsHidden = false,
  });

  PaneState get active => panes[activePaneIndex];

  /// Phase 15 — resolves the effective instant-orders flag for a given pane,
  /// honouring the per-pane override when set and falling back to the session
  /// global otherwise. Out-of-range indices fall back to the global flag.
  bool effectiveInstantFor(int paneIndex) {
    if (paneIndex < 0 || paneIndex >= panes.length) return instantOrders;
    final p = panes[paneIndex];
    if (p.instantOverride == 'on') return true;
    if (p.instantOverride == 'off') return false;
    return instantOrders;
  }

  ChartEngineSession copyWith({
    ChartLayout? layout,
    int? activePaneIndex,
    List<PaneState>? panes,
    bool? instantOrders,
    bool? instantWarningAck,
    Map<String, List<ChartDrawing>>? drawings,
    Object? activeDrawTool = _sentinel,
    bool? keyboardShortcuts,
    bool? drawingsLocked,
    bool? drawingsHidden,
  }) =>
      ChartEngineSession(
        layout: layout ?? this.layout,
        activePaneIndex: activePaneIndex ?? this.activePaneIndex,
        panes: panes ?? this.panes,
        instantOrders: instantOrders ?? this.instantOrders,
        instantWarningAck: instantWarningAck ?? this.instantWarningAck,
        drawings: drawings ?? this.drawings,
        activeDrawTool: identical(activeDrawTool, _sentinel)
            ? this.activeDrawTool
            : activeDrawTool as String?,
        keyboardShortcuts: keyboardShortcuts ?? this.keyboardShortcuts,
        drawingsLocked: drawingsLocked ?? this.drawingsLocked,
        drawingsHidden: drawingsHidden ?? this.drawingsHidden,
      );

  ChartEngineSession copyWithPane(int index, PaneState next) {
    if (index < 0 || index >= panes.length) return this;
    final m = List<PaneState>.from(panes);
    m[index] = next;
    return copyWith(panes: m);
  }

  // ---------- Persistence ----------

  Map<String, dynamic> toJson() => {
        'version': 1,
        'layout': layout.id,
        'activePaneIndex': activePaneIndex,
        'panes': [for (final p in panes) p.toJson()],
        'instantOrders': instantOrders,
        'instantWarningAck': instantWarningAck,
        'drawings': {
          for (final e in drawings.entries)
            e.key: [for (final d in e.value) d.toJson()],
        },
        'keyboardShortcuts': keyboardShortcuts,
        if (drawingsLocked != false) 'drawingsLocked': drawingsLocked,
        if (drawingsHidden != false) 'drawingsHidden': drawingsHidden,
      };

  static ChartEngineSession fromJson(Map<String, dynamic> j) {
    final layout = ChartLayout.fromId(j['layout'] as String? ?? 'single') ??
        ChartLayout.single;
    final activePaneIndex = (j['activePaneIndex'] as num?)?.toInt() ?? 0;
    final rawPanes = (j['panes'] as List?) ?? const [];
    final parsedPanes = <PaneState>[
      for (final p in rawPanes) PaneState.fromJson(p as Map<String, dynamic>),
    ];
    // Pad / truncate so the on-disk count can't disagree with the layout.
    final panes = List<PaneState>.generate(
      layout.paneCount,
      (i) => i < parsedPanes.length ? parsedPanes[i] : const PaneState(),
    );
    final drawingsRaw =
        j['drawings'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final drawings = <String, List<ChartDrawing>>{
      for (final e in drawingsRaw.entries)
        e.key: [
          for (final d in (e.value as List? ?? const []))
            ChartDrawing.fromJson(d as Map<String, dynamic>),
        ],
    };
    return ChartEngineSession(
      layout: layout,
      activePaneIndex: activePaneIndex.clamp(0, panes.length - 1),
      panes: panes,
      instantOrders: j['instantOrders'] as bool? ?? false,
      instantWarningAck: j['instantWarningAck'] as bool? ?? false,
      drawings: drawings,
      // activeDrawTool intentionally not restored — UI-only state.
      keyboardShortcuts: j['keyboardShortcuts'] as bool? ?? false,
      drawingsLocked: j['drawingsLocked'] as bool? ?? false,
      drawingsHidden: j['drawingsHidden'] as bool? ?? false,
    );
  }
}

class ChartEngineSessionNotifier extends Notifier<ChartEngineSession> {
  Timer? _persistTimer;

  @override
  ChartEngineSession build() {
    // Hydrate from SharedPreferences on first build. Fall back to the
    // default on ANY error so a corrupted prefs entry can't brick the
    // chart engine.
    final raw = locator<Preferences>().getChartEngineSession();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return _healStaleQty(ChartEngineSession.fromJson(decoded));
        }
      } catch (_) {
        // fall through to default
      }
    }
    return const ChartEngineSession();
  }

  /// Sessions persisted before the family-detection fix in [setPaneSymbol]
  /// stored qty=1 for option/future panes whose ChartScrip had an empty
  /// `instname`. Heal those on restore so the user doesn't have to re-pick
  /// every symbol to get the correct lot-multiplied qty.
  ChartEngineSession _healStaleQty(ChartEngineSession session) {
    final defaults = ref.read(orderDefaultsProvider);
    final healed = <PaneState>[];
    var changed = false;
    for (final pane in session.panes) {
      final scrip = pane.scrip;
      if (scrip == null || scrip.ls <= 1 || pane.qty >= scrip.ls) {
        healed.add(pane);
        continue;
      }
      // qty < ls on a lot-sized instrument is the symptom of the old bug.
      final instname = scrip.instname.toUpperCase();
      final isOption = instname.startsWith('OPT') ||
          parseOptionTsym(scrip.tsym) != null;
      final isFuture = instname.startsWith('FUT') || (!isOption);
      final lots = isOption
          ? defaults.optionsDefaultQty
          : isFuture
              ? defaults.futuresDefaultQty
              : 1;
      final newQty = (lots <= 0 ? 1 : lots) * scrip.ls;
      healed.add(pane.copyWith(qty: newQty));
      changed = true;
    }
    if (!changed) return session;
    return session.copyWith(panes: healed);
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 200), _persist);
  }

  Future<void> _persist() async {
    try {
      final json = jsonEncode(state.toJson());
      await locator<Preferences>().setChartEngineSession(json);
    } catch (_) {
      // Persistence is best-effort; never block the UI.
    }
  }

  /// Backfills the pane's scrip metadata (`ls`, `ti`) when the broker's
  /// GetSecurityInfo response lands AFTER `setPaneSymbol`. Some entry
  /// paths (EmbeddedChartView's `DepthInputArgs`, raw search picks, …)
  /// don't carry lot size, so the scrip lands with the conservative
  /// `ls=1`/`ti=0.05` defaults — qty then collapses to 1 even for
  /// option/future contracts. When the real values arrive, this method
  /// patches the scrip and re-runs the family-aware qty computation so
  /// the user sees correct lot-multiplied qty within the API's round-trip.
  void backfillPaneScripMetadata(int index, {int? ls, double? ti}) {
    if (index < 0 || index >= state.panes.length) return;
    final pane = state.panes[index];
    final scrip = pane.scrip;
    if (scrip == null) return;
    final newLs = (ls != null && ls > 0) ? ls : scrip.ls;
    final newTi = (ti != null && ti > 0) ? ti : scrip.ti;
    if (newLs == scrip.ls && newTi == scrip.ti) return;
    // Recompute qty only when ls changed AND the current qty matches the
    // initial computation for the OLD ls (i.e. the user hasn't manually
    // tweaked qty since). Avoids stomping user edits.
    final defaults = ref.read(orderDefaultsProvider);
    final instname = scrip.instname.toUpperCase();
    final isOption = instname.startsWith('OPT') ||
        parseOptionTsym(scrip.tsym) != null;
    final isFuture = instname.startsWith('FUT') ||
        (!isOption && newLs > 1);
    int? nextQty;
    if (newLs != scrip.ls) {
      final oldLs = scrip.ls > 0 ? scrip.ls : 1;
      final oldExpectedQty = isOption
          ? defaults.optionsDefaultQty * oldLs
          : isFuture
              ? defaults.futuresDefaultQty * oldLs
              : defaults.equityDefaultQty;
      if (pane.qty == oldExpectedQty || pane.qty == oldLs) {
        nextQty = isOption
            ? defaults.optionsDefaultQty * newLs
            : isFuture
                ? defaults.futuresDefaultQty * newLs
                : defaults.equityDefaultQty;
        if (nextQty <= 0) nextQty = newLs;
      }
    }
    final patched = scrip.copyWith(ls: newLs, ti: newTi);
    state = state.copyWithPane(
        index,
        pane.copyWith(
          scrip: patched,
          qty: nextQty ?? pane.qty,
        ));
    _schedulePersist();
  }

  void setPaneSymbol(int index, ChartScrip scrip) {
    if (index < 0 || index >= state.panes.length) return;
    final ls = scrip.ls > 0 ? scrip.ls : 1;
    // Initial qty for the new symbol respects Order Defaults → Trade
    // Quantity (per instrument family). Futures/options multiply by lot
    // size so the user's "2 lots" setting becomes 2*ls units; equity is
    // a raw share count (no lot multiplier).
    //
    // Family detection: prefer the broker's `instname` when present, but
    // fall back to parsing the tsym + the lot size, because several entry
    // paths (top-bar typeahead, watchlist, saved-session restore) yield
    // ChartScrips with an empty `instname` even for derivatives. Without
    // the fallback those land in the equity branch and qty silently
    // collapses to `equityDefaultQty` (usually 1).
    final defaults = ref.read(orderDefaultsProvider);
    final instname = scrip.instname.toUpperCase();
    final isOption = instname.startsWith('OPT') ||
        parseOptionTsym(scrip.tsym) != null;
    final isFuture = instname.startsWith('FUT') ||
        // Lot size > 1 with a non-option tsym ≈ a futures/derivative
        // contract on this broker. Stocks are always ls=1.
        (!isOption && ls > 1);
    int initialQty;
    if (isOption) {
      initialQty = defaults.optionsDefaultQty * ls;
    } else if (isFuture) {
      initialQty = defaults.futuresDefaultQty * ls;
    } else {
      initialQty = defaults.equityDefaultQty;
    }
    if (initialQty <= 0) initialQty = ls;
    state = state.copyWithPane(
        index, state.panes[index].copyWith(scrip: scrip, qty: initialQty));
    _schedulePersist();
  }

  void setPaneTimeframe(int index, int minutes) {
    if (index < 0 || index >= state.panes.length) return;
    state = state.copyWithPane(
        index, state.panes[index].copyWith(timeframeMinutes: minutes));
    _schedulePersist();
  }

  void setPaneOverlays(int index, ChartOverlays overlays) {
    if (index < 0 || index >= state.panes.length) return;
    state = state.copyWithPane(
        index, state.panes[index].copyWith(overlays: overlays));
    _schedulePersist();
  }

  void setInstantOrders(bool enabled) {
    if (enabled == state.instantOrders) return;
    state = state.copyWith(instantOrders: enabled);
    _schedulePersist();
  }

  void markInstantWarningAck() {
    if (state.instantWarningAck) return;
    state = state.copyWith(instantWarningAck: true);
    _schedulePersist();
  }

  void setKeyboardShortcuts(bool enabled) {
    if (enabled == state.keyboardShortcuts) return;
    state = state.copyWith(keyboardShortcuts: enabled);
    _schedulePersist();
  }

  /// Phase 15 — set the per-pane instant override. `override` must be
  /// `'on'`, `'off'` or `null` (= follow global). Invalid string values are
  /// coerced to `null` so callers can't poison persistence.
  void setPaneInstantOverride(int index, String? override) {
    if (index < 0 || index >= state.panes.length) return;
    final String? normalized =
        (override == 'on' || override == 'off') ? override : null;
    final pane = state.panes[index];
    if (pane.instantOverride == normalized) return;
    state = state.copyWithPane(
        index, pane.copyWith(instantOverride: normalized));
    _schedulePersist();
  }

  /// Phase 16 — set the per-pane chart style. Unknown values are coerced to
  /// `'candles'` so callers can't poison persistence.
  void setPaneCandleStyle(int index, String style) {
    if (index < 0 || index >= state.panes.length) return;
    final normalized =
        PaneState._validStyles.contains(style) ? style : 'candles';
    final pane = state.panes[index];
    if (pane.candleStyle == normalized) return;
    state = state.copyWithPane(index, pane.copyWith(candleStyle: normalized));
    _schedulePersist();
  }

  /// Phase 16 — set the visible-range H/L markers visibility for one pane.
  void setPaneShowHighLowMarkers(int index, bool show) {
    if (index < 0 || index >= state.panes.length) return;
    final pane = state.panes[index];
    if (pane.showHighLowMarkers == show) return;
    state = state.copyWithPane(
        index, pane.copyWith(showHighLowMarkers: show));
    _schedulePersist();
  }

  /// Phase 18 — toggle the option-chain OI bars on one pane.
  void setPaneShowOptionChainOi(int index, bool show) {
    if (index < 0 || index >= state.panes.length) return;
    final pane = state.panes[index];
    if (pane.showOptionChainOi == show) return;
    state = state.copyWithPane(
        index, pane.copyWith(showOptionChainOi: show));
    _schedulePersist();
  }

  /// Phase 18 — toggle the LTP bar-close countdown on one pane.
  void setPaneShowBarCountdown(int index, bool show) {
    if (index < 0 || index >= state.panes.length) return;
    final pane = state.panes[index];
    if (pane.showBarCountdown == show) return;
    state = state.copyWithPane(
        index, pane.copyWith(showBarCountdown: show));
    _schedulePersist();
  }

  /// Phase 20 — toggle classical-pivot Key Levels on one pane.
  void setPaneShowKeyLevels(int index, bool show) {
    if (index < 0 || index >= state.panes.length) return;
    final pane = state.panes[index];
    if (pane.showKeyLevels == show) return;
    state = state.copyWithPane(
        index, pane.copyWith(showKeyLevels: show));
    _schedulePersist();
  }

  /// Phase 23 — set the pivot variant for the Key Levels overlay on one pane.
  void setPanePivotVariant(int index, String variant) {
    if (index < 0 || index >= state.panes.length) return;
    const valid = <String>{'classical', 'fibonacci', 'camarilla'};
    final n = valid.contains(variant) ? variant : 'classical';
    final pane = state.panes[index];
    if (pane.pivotVariant == n) return;
    state = state.copyWithPane(index, pane.copyWith(pivotVariant: n));
    _schedulePersist();
  }

  /// Phase 23 — toggle drawing magnet (snap to nearest OHLC) on one pane.
  void setPaneMagnetEnabled(int index, bool enabled) {
    if (index < 0 || index >= state.panes.length) return;
    final pane = state.panes[index];
    if (pane.magnetEnabled == enabled) return;
    state = state.copyWithPane(index, pane.copyWith(magnetEnabled: enabled));
    _schedulePersist();
  }

  /// Phase 25 — toggle the auto-pattern (HH/HL/LH/LL) overlay on one pane.
  void setPaneShowAutoPattern(int index, bool show) {
    if (index < 0 || index >= state.panes.length) return;
    final pane = state.panes[index];
    if (pane.showAutoPattern == show) return;
    state = state.copyWithPane(index, pane.copyWith(showAutoPattern: show));
    _schedulePersist();
  }

  /// Toggle the crosshair LINES (vertical+horizontal dashed lines under the
  /// cursor). The right-axis price chip and bottom-axis time chip always
  /// render — this only suppresses the spanning lines.
  void setPaneShowCrosshairLines(int index, bool show) {
    if (index < 0 || index >= state.panes.length) return;
    final pane = state.panes[index];
    if (pane.showCrosshairLines == show) return;
    state =
        state.copyWithPane(index, pane.copyWith(showCrosshairLines: show));
    _schedulePersist();
  }

  /// Phase 23 — toggle the right-gutter volume profile histogram on one pane.
  void setPaneShowVolumeProfile(int index, bool show) {
    if (index < 0 || index >= state.panes.length) return;
    final pane = state.panes[index];
    if (pane.showVolumeProfile == show) return;
    state = state.copyWithPane(index, pane.copyWith(showVolumeProfile: show));
    _schedulePersist();
  }

  /// Phase 23 — lock all drawings in all panes (disables drag/delete).
  void setDrawingsLocked(bool locked) {
    if (state.drawingsLocked == locked) return;
    state = state.copyWith(drawingsLocked: locked);
    _schedulePersist();
  }

  /// Phase 23 — hide all drawings in all panes (suppresses render).
  void setDrawingsHidden(bool hidden) {
    if (state.drawingsHidden == hidden) return;
    state = state.copyWith(drawingsHidden: hidden);
    _schedulePersist();
  }

  /// Phase 23 — trash all drawings for the active pane's scrip (if any).
  /// If you want global "trash all panes", iterate panes; we go per-scrip
  /// because drawings are keyed by scrip key and that matches user intent.
  void clearDrawingsForActivePane() {
    final active = state.activePaneIndex;
    if (active < 0 || active >= state.panes.length) return;
    final scrip = state.panes[active].scrip;
    if (scrip == null) return;
    final scripKey = '${scrip.exch}|${scrip.token}';
    if (!state.drawings.containsKey(scripKey)) return;
    final next = Map<String, List<ChartDrawing>>.from(state.drawings)
      ..remove(scripKey);
    state = state.copyWith(drawings: next);
    _schedulePersist();
  }

  void setPaneQty(int index, int qty) {
    if (index < 0 || index >= state.panes.length) return;
    final pane = state.panes[index];
    final ls = pane.scrip?.ls != null && pane.scrip!.ls > 0 ? pane.scrip!.ls : 1;
    final stepped = ((qty / ls).round()).clamp(1, 1 << 30) * ls;
    if (stepped == pane.qty) return;
    state = state.copyWithPane(index, pane.copyWith(qty: stepped));
    _schedulePersist();
  }

  void setActivePane(int index) {
    if (index < 0 || index >= state.panes.length) return;
    if (index == state.activePaneIndex) return;
    state = state.copyWith(activePaneIndex: index);
    _schedulePersist();
  }

  void setActiveDrawTool(String? kind) {
    if (kind == state.activeDrawTool) return;
    state = state.copyWith(activeDrawTool: kind);
    // Intentionally NOT persisted — UI-only state.
  }

  void addDrawing(String scripKey, ChartDrawing d) {
    final next = Map<String, List<ChartDrawing>>.from(state.drawings);
    final list = List<ChartDrawing>.from(next[scripKey] ?? const []);
    list.add(d);
    next[scripKey] = list;
    state = state.copyWith(drawings: next);
    _schedulePersist();
  }

  void addIndicator(int paneIndex, IndicatorConfig cfg) {
    if (paneIndex < 0 || paneIndex >= state.panes.length) return;
    final pane = state.panes[paneIndex];
    final next = List<IndicatorConfig>.from(pane.indicators)..add(cfg);
    state = state.copyWithPane(paneIndex, pane.copyWith(indicators: next));
    _schedulePersist();
  }

  void removeIndicator(int paneIndex, String id) {
    if (paneIndex < 0 || paneIndex >= state.panes.length) return;
    final pane = state.panes[paneIndex];
    final next = List<IndicatorConfig>.from(pane.indicators)
      ..removeWhere((i) => i.id == id);
    state = state.copyWithPane(paneIndex, pane.copyWith(indicators: next));
    _schedulePersist();
  }

  void updateIndicator(int paneIndex, String id,
      {int? period,
      String? color,
      bool? hidden,
      int? thickness,
      Map<String, num>? params}) {
    if (paneIndex < 0 || paneIndex >= state.panes.length) return;
    final pane = state.panes[paneIndex];
    final next = [
      for (final i in pane.indicators)
        i.id == id
            ? i.copyWith(
                period: period,
                color: color,
                hidden: hidden,
                thickness: thickness,
                params: params,
              )
            : i,
    ];
    state = state.copyWithPane(paneIndex, pane.copyWith(indicators: next));
    _schedulePersist();
  }

  void removeDrawing(String scripKey, String drawingId) {
    final next = Map<String, List<ChartDrawing>>.from(state.drawings);
    final list = List<ChartDrawing>.from(next[scripKey] ?? const []);
    list.removeWhere((d) => d.id == drawingId);
    if (list.isEmpty) {
      next.remove(scripKey);
    } else {
      next[scripKey] = list;
    }
    state = state.copyWith(drawings: next);
    _schedulePersist();
  }

  /// Phase 10 — replace `points` and/or `color` on an existing drawing.
  /// Used for drag-to-move and the per-drawing color picker.
  void updateDrawing(
    String scripKey,
    String drawingId, {
    List<DrawingPoint>? points,
    String? color,
    bool? locked,
    int? thickness,
  }) {
    final next = Map<String, List<ChartDrawing>>.from(state.drawings);
    final list = List<ChartDrawing>.from(next[scripKey] ?? const []);
    final idx = list.indexWhere((d) => d.id == drawingId);
    if (idx < 0) return;
    final old = list[idx];
    list[idx] = old.copyWith(
      color: color ?? old.color,
      points: points ?? old.points,
      locked: locked ?? old.locked,
      thickness: thickness ?? old.thickness,
    );
    next[scripKey] = list;
    state = state.copyWith(drawings: next);
    _schedulePersist();
  }

  void setLayout(ChartLayout next) {
    if (next == state.layout) return;
    final cur = state.panes;
    final activeIdx = state.activePaneIndex;
    final n = next.paneCount;
    final newPanes = <PaneState>[];
    int newActive;

    if (n >= cur.length) {
      newPanes.addAll(cur);
      for (var i = cur.length; i < n; i++) {
        newPanes.add(cur[activeIdx]);
      }
      newActive = activeIdx;
    } else {
      newPanes.add(cur[activeIdx]);
      for (var i = 0; i < cur.length; i++) {
        if (i == activeIdx) continue;
        if (newPanes.length >= n) break;
        newPanes.add(cur[i]);
      }
      newActive = 0;
    }

    state = state.copyWith(
      layout: next,
      panes: newPanes,
      activePaneIndex: newActive,
    );
    _schedulePersist();
  }
}

final chartEngineSessionProvider =
    NotifierProvider<ChartEngineSessionNotifier, ChartEngineSession>(
  ChartEngineSessionNotifier.new,
);

// ─── Phase 25 — Screenshot request signal ────────────────────────────────────

/// Carries a screenshot request from the top bar to the shell screen.
/// `requestId` increments on every call so listeners can detect a new request
/// even when `paneIndex` does not change.
class ScreenshotRequest {
  final int? paneIndex;
  final int requestId;
  const ScreenshotRequest({this.paneIndex, this.requestId = 0});
}

class ScreenshotRequestNotifier extends Notifier<ScreenshotRequest> {
  @override
  ScreenshotRequest build() => const ScreenshotRequest();

  void request(int paneIndex) {
    state = ScreenshotRequest(
      paneIndex: paneIndex,
      requestId: state.requestId + 1,
    );
  }
}

final screenshotRequestProvider =
    NotifierProvider<ScreenshotRequestNotifier, ScreenshotRequest>(
  ScreenshotRequestNotifier.new,
);

// ─── Phase 26 — Order defaults (SL/TP, Quantity, Product type) ────────────────
//
// Lives in its OWN prefs key so the much-larger session blob (panes, drawings,
// indicators) doesn't get rewritten every time the user nudges a default. The
// chart engine reads these defaults when constructing PlaceOrderInput from the
// +/Buy/Sell paths.

const String _orderDefaultsPrefsKey = 'chartEngineOrderDefaultsV1';

/// Allowed SL/TP order types. Kept as strings so JSON round-trip is trivial.
const Set<String> _kValidSlTypes = {'SL_LMT', 'SL_MKT'};
const Set<String> _kValidTpTypes = {'TP_LMT', 'TP_MKT'};
const Set<String> _kValidSlTriggers = {'points', 'percent', 'ticks'};
const Set<String> _kValidEquityProducts = {'C', 'I'};
const Set<String> _kValidFnoProducts = {'M', 'I'};

class OrderDefaults {
  // SL/TP defaults
  final bool autoStopLoss;
  final String slType;          // 'SL_LMT' | 'SL_MKT'
  final String slTrigger;       // 'points' | 'percent' | 'ticks'
  final double slTriggerValue;
  final bool trailingSL;
  final double trailingMove;    // SL moves by this for every `trailingFor` move in LTP
  final double trailingFor;
  final bool autoTakeProfit;
  final String tpType;          // 'TP_LMT' | 'TP_MKT'
  final double tpTriggerValue;

  // Trade Quantity defaults — separate qty per instrument family
  final int equityDefaultQty;
  final int futuresDefaultQty; // lot count, not lot size
  final int optionsDefaultQty; // lot count

  // Product Type defaults
  final String equityProduct;   // 'C' (Delivery) | 'I' (Intraday)
  final String futuresProduct;  // 'M' (Normal)   | 'I' (Intraday)
  final String optionsProduct;  // 'M' (Normal)   | 'I' (Intraday)

  const OrderDefaults({
    this.autoStopLoss = false,
    this.slType = 'SL_LMT',
    this.slTrigger = 'points',
    this.slTriggerValue = 10.0,
    this.trailingSL = false,
    this.trailingMove = 1.0,
    this.trailingFor = 1.0,
    this.autoTakeProfit = false,
    this.tpType = 'TP_LMT',
    this.tpTriggerValue = 20.0,
    this.equityDefaultQty = 1,
    this.futuresDefaultQty = 1,
    this.optionsDefaultQty = 1,
    this.equityProduct = 'I',
    this.futuresProduct = 'I',
    this.optionsProduct = 'I',
  });

  OrderDefaults copyWith({
    bool? autoStopLoss,
    String? slType,
    String? slTrigger,
    double? slTriggerValue,
    bool? trailingSL,
    double? trailingMove,
    double? trailingFor,
    bool? autoTakeProfit,
    String? tpType,
    double? tpTriggerValue,
    int? equityDefaultQty,
    int? futuresDefaultQty,
    int? optionsDefaultQty,
    String? equityProduct,
    String? futuresProduct,
    String? optionsProduct,
  }) =>
      OrderDefaults(
        autoStopLoss: autoStopLoss ?? this.autoStopLoss,
        slType: slType ?? this.slType,
        slTrigger: slTrigger ?? this.slTrigger,
        slTriggerValue: slTriggerValue ?? this.slTriggerValue,
        trailingSL: trailingSL ?? this.trailingSL,
        trailingMove: trailingMove ?? this.trailingMove,
        trailingFor: trailingFor ?? this.trailingFor,
        autoTakeProfit: autoTakeProfit ?? this.autoTakeProfit,
        tpType: tpType ?? this.tpType,
        tpTriggerValue: tpTriggerValue ?? this.tpTriggerValue,
        equityDefaultQty: equityDefaultQty ?? this.equityDefaultQty,
        futuresDefaultQty: futuresDefaultQty ?? this.futuresDefaultQty,
        optionsDefaultQty: optionsDefaultQty ?? this.optionsDefaultQty,
        equityProduct: equityProduct ?? this.equityProduct,
        futuresProduct: futuresProduct ?? this.futuresProduct,
        optionsProduct: optionsProduct ?? this.optionsProduct,
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'autoStopLoss': autoStopLoss,
        'slType': slType,
        'slTrigger': slTrigger,
        'slTriggerValue': slTriggerValue,
        'trailingSL': trailingSL,
        'trailingMove': trailingMove,
        'trailingFor': trailingFor,
        'autoTakeProfit': autoTakeProfit,
        'tpType': tpType,
        'tpTriggerValue': tpTriggerValue,
        'equityDefaultQty': equityDefaultQty,
        'futuresDefaultQty': futuresDefaultQty,
        'optionsDefaultQty': optionsDefaultQty,
        'equityProduct': equityProduct,
        'futuresProduct': futuresProduct,
        'optionsProduct': optionsProduct,
      };

  static OrderDefaults fromJson(Map<String, dynamic> j) {
    String enumOr(dynamic raw, Set<String> valid, String fallback) {
      if (raw is String && valid.contains(raw)) return raw;
      return fallback;
    }

    double doubleOr(dynamic raw, double fallback) {
      if (raw is num) return raw.toDouble();
      return fallback;
    }

    int intOr(dynamic raw, int fallback) {
      if (raw is num) {
        final v = raw.toInt();
        return v < 1 ? 1 : v;
      }
      return fallback;
    }

    return OrderDefaults(
      autoStopLoss: j['autoStopLoss'] as bool? ?? false,
      slType: enumOr(j['slType'], _kValidSlTypes, 'SL_LMT'),
      slTrigger: enumOr(j['slTrigger'], _kValidSlTriggers, 'points'),
      slTriggerValue: doubleOr(j['slTriggerValue'], 10.0),
      trailingSL: j['trailingSL'] as bool? ?? false,
      trailingMove: doubleOr(j['trailingMove'], 1.0),
      trailingFor: doubleOr(j['trailingFor'], 1.0),
      autoTakeProfit: j['autoTakeProfit'] as bool? ?? false,
      tpType: enumOr(j['tpType'], _kValidTpTypes, 'TP_LMT'),
      tpTriggerValue: doubleOr(j['tpTriggerValue'], 20.0),
      equityDefaultQty: intOr(j['equityDefaultQty'], 1),
      futuresDefaultQty: intOr(j['futuresDefaultQty'], 1),
      optionsDefaultQty: intOr(j['optionsDefaultQty'], 1),
      equityProduct: enumOr(j['equityProduct'], _kValidEquityProducts, 'I'),
      futuresProduct: enumOr(j['futuresProduct'], _kValidFnoProducts, 'I'),
      optionsProduct: enumOr(j['optionsProduct'], _kValidFnoProducts, 'I'),
    );
  }
}

class OrderDefaultsNotifier extends Notifier<OrderDefaults> {
  Timer? _persistTimer;

  @override
  OrderDefaults build() {
    final raw = locator<Preferences>()
        .sharedPreferences
        ?.getString(_orderDefaultsPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return OrderDefaults.fromJson(decoded);
        }
      } catch (_) {
        // fall through to default — corrupt prefs must never brick the chart
      }
    }
    return const OrderDefaults();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 250), _persist);
  }

  Future<void> _persist() async {
    try {
      final json = jsonEncode(state.toJson());
      await locator<Preferences>().setString(_orderDefaultsPrefsKey, json);
    } catch (_) {
      // Persistence is best-effort; never block the UI.
    }
  }

  // ── SL/TP setters ─────────────────────────────────────────────────────────

  void setAutoStopLoss(bool value) {
    if (value == state.autoStopLoss) return;
    state = state.copyWith(autoStopLoss: value);
    _schedulePersist();
  }

  void setSlType(String value) {
    final n = _kValidSlTypes.contains(value) ? value : 'SL_LMT';
    if (n == state.slType) return;
    state = state.copyWith(slType: n);
    _schedulePersist();
  }

  void setSlTrigger(String value) {
    final n = _kValidSlTriggers.contains(value) ? value : 'points';
    if (n == state.slTrigger) return;
    state = state.copyWith(slTrigger: n);
    _schedulePersist();
  }

  void setSlTriggerValue(double value) {
    final clamped = value < 0 ? 0.0 : value;
    if (clamped == state.slTriggerValue) return;
    state = state.copyWith(slTriggerValue: clamped);
    _schedulePersist();
  }

  void setTrailingSL(bool value) {
    if (value == state.trailingSL) return;
    state = state.copyWith(trailingSL: value);
    _schedulePersist();
  }

  void setTrailingMove(double value) {
    final clamped = value < 0 ? 0.0 : value;
    if (clamped == state.trailingMove) return;
    state = state.copyWith(trailingMove: clamped);
    _schedulePersist();
  }

  void setTrailingFor(double value) {
    final clamped = value < 0 ? 0.0 : value;
    if (clamped == state.trailingFor) return;
    state = state.copyWith(trailingFor: clamped);
    _schedulePersist();
  }

  void setAutoTakeProfit(bool value) {
    if (value == state.autoTakeProfit) return;
    state = state.copyWith(autoTakeProfit: value);
    _schedulePersist();
  }

  void setTpType(String value) {
    final n = _kValidTpTypes.contains(value) ? value : 'TP_LMT';
    if (n == state.tpType) return;
    state = state.copyWith(tpType: n);
    _schedulePersist();
  }

  void setTpTriggerValue(double value) {
    final clamped = value < 0 ? 0.0 : value;
    if (clamped == state.tpTriggerValue) return;
    state = state.copyWith(tpTriggerValue: clamped);
    _schedulePersist();
  }

  // ── Quantity setters ──────────────────────────────────────────────────────

  void setEquityDefaultQty(int value) {
    final clamped = value < 1 ? 1 : value;
    if (clamped == state.equityDefaultQty) return;
    state = state.copyWith(equityDefaultQty: clamped);
    _schedulePersist();
  }

  void setFuturesDefaultQty(int value) {
    final clamped = value < 1 ? 1 : value;
    if (clamped == state.futuresDefaultQty) return;
    state = state.copyWith(futuresDefaultQty: clamped);
    _schedulePersist();
  }

  void setOptionsDefaultQty(int value) {
    final clamped = value < 1 ? 1 : value;
    if (clamped == state.optionsDefaultQty) return;
    state = state.copyWith(optionsDefaultQty: clamped);
    _schedulePersist();
  }

  // ── Product type setters ──────────────────────────────────────────────────

  void setEquityProduct(String value) {
    final n = _kValidEquityProducts.contains(value) ? value : 'I';
    if (n == state.equityProduct) return;
    state = state.copyWith(equityProduct: n);
    _schedulePersist();
  }

  void setFuturesProduct(String value) {
    final n = _kValidFnoProducts.contains(value) ? value : 'I';
    if (n == state.futuresProduct) return;
    state = state.copyWith(futuresProduct: n);
    _schedulePersist();
  }

  void setOptionsProduct(String value) {
    final n = _kValidFnoProducts.contains(value) ? value : 'I';
    if (n == state.optionsProduct) return;
    state = state.copyWith(optionsProduct: n);
    _schedulePersist();
  }
}

final orderDefaultsProvider =
    NotifierProvider<OrderDefaultsNotifier, OrderDefaults>(
  OrderDefaultsNotifier.new,
);

// ─── Chart palette (Settings → Customize) ────────────────────────────────────

/// User-tunable chart palette. Hex strings (e.g. `'#22C55E'`); empty string
/// means "follow the theme default" — the iframe sees an absent key and
/// applies its own resolved colour. Persisted independently of the chart
/// engine session so resetting layout/panes never wipes the user's palette.
class ChartPalette {
  // Defaults exposed as constants so the Customize tab can render a
  // "reset this row" affordance without re-typing the literals.
  static const String dBullBody = '#22C55E';
  static const String dBearBody = '#EF4444';
  static const String dBullWick = '#16A34A';
  static const String dBearWick = '#B91C1C';

  final String bullBody;
  final String bearBody;
  final String bullWick;
  final String bearWick;
  final String background;
  final String text;
  final String grid;
  final String sessionBreak;
  final String crosshair;

  const ChartPalette({
    this.bullBody = dBullBody,
    this.bearBody = dBearBody,
    this.bullWick = dBullWick,
    this.bearWick = dBearWick,
    this.background = '',
    this.text = '',
    this.grid = '',
    this.sessionBreak = '',
    this.crosshair = '',
  });

  ChartPalette copyWith({
    String? bullBody,
    String? bearBody,
    String? bullWick,
    String? bearWick,
    String? background,
    String? text,
    String? grid,
    String? sessionBreak,
    String? crosshair,
  }) =>
      ChartPalette(
        bullBody: bullBody ?? this.bullBody,
        bearBody: bearBody ?? this.bearBody,
        bullWick: bullWick ?? this.bullWick,
        bearWick: bearWick ?? this.bearWick,
        background: background ?? this.background,
        text: text ?? this.text,
        grid: grid ?? this.grid,
        sessionBreak: sessionBreak ?? this.sessionBreak,
        crosshair: crosshair ?? this.crosshair,
      );

  /// Emit only fields that differ from defaults; empty strings (theme
  /// fallback) are also omitted. Keeps persisted JSON minimal and makes
  /// future schema additions backwards-compatible.
  Map<String, dynamic> toJson() => {
        if (bullBody != dBullBody) 'bullBody': bullBody,
        if (bearBody != dBearBody) 'bearBody': bearBody,
        if (bullWick != dBullWick) 'bullWick': bullWick,
        if (bearWick != dBearWick) 'bearWick': bearWick,
        if (background.isNotEmpty) 'background': background,
        if (text.isNotEmpty) 'text': text,
        if (grid.isNotEmpty) 'grid': grid,
        if (sessionBreak.isNotEmpty) 'sessionBreak': sessionBreak,
        if (crosshair.isNotEmpty) 'crosshair': crosshair,
      };

  /// Build the wire-format map shipped into the iframe. Same shape as
  /// [toJson] but the values are guaranteed `String` and empty fields are
  /// dropped so the JS side can `key in palette` check for explicit values.
  Map<String, String> toWire() => {
        if (bullBody != dBullBody) 'bullBody': bullBody,
        if (bearBody != dBearBody) 'bearBody': bearBody,
        if (bullWick != dBullWick) 'bullWick': bullWick,
        if (bearWick != dBearWick) 'bearWick': bearWick,
        if (background.isNotEmpty) 'background': background,
        if (text.isNotEmpty) 'text': text,
        if (grid.isNotEmpty) 'grid': grid,
        if (sessionBreak.isNotEmpty) 'sessionBreak': sessionBreak,
        if (crosshair.isNotEmpty) 'crosshair': crosshair,
      };

  static ChartPalette fromJson(Map<String, dynamic> j) => ChartPalette(
        bullBody: (j['bullBody'] as String?) ?? dBullBody,
        bearBody: (j['bearBody'] as String?) ?? dBearBody,
        bullWick: (j['bullWick'] as String?) ?? dBullWick,
        bearWick: (j['bearWick'] as String?) ?? dBearWick,
        background: (j['background'] as String?) ?? '',
        text: (j['text'] as String?) ?? '',
        grid: (j['grid'] as String?) ?? '',
        sessionBreak: (j['sessionBreak'] as String?) ?? '',
        crosshair: (j['crosshair'] as String?) ?? '',
      );

  bool get isDefault =>
      bullBody == dBullBody &&
      bearBody == dBearBody &&
      bullWick == dBullWick &&
      bearWick == dBearWick &&
      background.isEmpty &&
      text.isEmpty &&
      grid.isEmpty &&
      sessionBreak.isEmpty &&
      crosshair.isEmpty;
}

class ChartPaletteNotifier extends Notifier<ChartPalette> {
  Timer? _persistTimer;
  // Cached SharedPreferences instance. `Preferences.init()` runs at app
  // boot so the first `getInstance()` await resolves immediately (it just
  // returns the package's cached singleton).
  static SharedPreferences? _cachedPrefs;
  static const String _key = 'chartEnginePaletteV1';

  @override
  ChartPalette build() {
    // Synchronous return so the UI gets the persisted palette on first frame
    // when prefs are already cached; otherwise the default ships first and
    // [_asyncHydrate] updates state once SharedPreferences resolves.
    final cached = _cachedPrefs;
    if (cached != null) return _decode(cached.getString(_key));
    _asyncHydrate();
    return const ChartPalette();
  }

  Future<void> _asyncHydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPrefs ??= prefs;
      final loaded = _decode(prefs.getString(_key));
      if (!loaded.isDefault) state = loaded;
    } catch (_) {
      // Hydration is best-effort — keep default on failure.
    }
  }

  ChartPalette _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const ChartPalette();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return ChartPalette.fromJson(decoded);
    } catch (_) { /* fall through */ }
    return const ChartPalette();
  }

  void setBullBody(String hex) {
    state = state.copyWith(bullBody: hex);
    _schedulePersist();
  }

  void setBearBody(String hex) {
    state = state.copyWith(bearBody: hex);
    _schedulePersist();
  }

  void setBullWick(String hex) {
    state = state.copyWith(bullWick: hex);
    _schedulePersist();
  }

  void setBearWick(String hex) {
    state = state.copyWith(bearWick: hex);
    _schedulePersist();
  }

  void setBackground(String hex) {
    state = state.copyWith(background: hex);
    _schedulePersist();
  }

  void setText(String hex) {
    state = state.copyWith(text: hex);
    _schedulePersist();
  }

  void setGrid(String hex) {
    state = state.copyWith(grid: hex);
    _schedulePersist();
  }

  void setSessionBreak(String hex) {
    state = state.copyWith(sessionBreak: hex);
    _schedulePersist();
  }

  void setCrosshair(String hex) {
    state = state.copyWith(crosshair: hex);
    _schedulePersist();
  }

  void resetToDefault() {
    state = const ChartPalette();
    _persistNow();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 250), _persistNow);
  }

  Future<void> _persistNow() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs ??= prefs;
      if (state.isDefault) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, jsonEncode(state.toJson()));
      }
    } catch (_) {
      // Persistence is best-effort; never block the UI.
    }
  }
}

final chartPaletteProvider =
    NotifierProvider<ChartPaletteNotifier, ChartPalette>(
  ChartPaletteNotifier.new,
);
