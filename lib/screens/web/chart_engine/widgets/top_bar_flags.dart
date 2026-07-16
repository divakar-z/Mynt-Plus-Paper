/// Per-control feature flags for the Flutter chart engine top bar.
///
/// As each control migrates to the HTML/JS top bar inside the iframe
/// (`web/chart-engine/topbar.js` + per-control modules), flip the matching
/// flag here to `true`. The Flutter widget for that control then renders
/// `SizedBox.shrink()` so the two implementations never both show.
///
/// Migration order:
///   1) [kJsInstantBadge]        — spike, exercises the bridge protocol
///   2) [kJsSnapButton]          — single-shot, no state
///   3) [kJsLayoutPicker]        — popover + persistence
///   4) [kJsTimeframeDropdown]   — popover + persistence
///   5) [kJsStylePicker]
///   6) [kJsDrawToolbar]
///   7) [kJsCursorMode]
///   8) [kJsIndicatorsButton]
///   9) [kJsOrderDefaults]
///  10) [kJsSettings]
///  11) [kJsSymbolTypeAhead]     — last; needs API search + keyboard nav
///
/// Once every flag is true, the entire Flutter [ChartEngineTopBar] widget
/// can be deleted and the iframe owns the bar end-to-end.
class TopBarFlags {
  TopBarFlags._();

  /// Spike control. The INSTANT chip is rendered by `topbar.js` inside the
  /// iframe and clicks route through the bridge (`confirmInstantOrders`
  /// request + `instantOrdersChanged` fire-and-forget).
  static const bool kJsInstantBadge = true;

  /// Snap (screenshot) — drives `chart.takeScreenshot()` on the active
  /// pane directly via `window.chartEngine.activeChart()`. The existing
  /// Flutter `chartScreenshot` download path is reused unchanged.
  static const bool kJsSnapButton = true;

  /// Layout picker — JS owns the popover UI; Flutter still owns the catalog
  /// (pushed once via `setLayoutCatalog`) and the active layout id
  /// (mirrored via `setActiveLayoutId` in both directions).
  static const bool kJsLayoutPicker = true;
  /// Timeframe dropdown — reads the active pane's timeframe from the
  /// `setActivePaneTopBarState` mirror; writes back via `setActiveTimeframe`.
  static const bool kJsTimeframeDropdown = true;

  /// Style picker (Candle / Hollow / Bars / Line / Area / Heikin Ashi) —
  /// reads `candleStyle` from the same per-active-pane mirror; writes
  /// back via `setActiveCandleStyle`.
  static const bool kJsStylePicker = true;
  /// Draw button + tools popover + bottom toolbar (Lock/Hide/Trash). The
  /// JS button highlights when a tool is active and acts as a one-tap
  /// cancel, mirroring the Flutter widget. Lock/Hide state mirrors the
  /// existing `setDrawingsLocked` / `setDrawingsHidden` Flutter→JS pushes.
  static const bool kJsDrawToolbar = true;
  /// Cursor-mode picker (Crosshair / Cursor) — controls the active pane's
  /// `showCrosshairLines` field. Per-active-pane state via the same
  /// `setActivePaneTopBarState` mirror used by Timeframe + Style.
  /// (Replaces the planned "kJsPlusMenu" entry — the Flutter widget that
  /// shows the `+` icon when crosshair is on IS the cursor-mode button.)
  static const bool kJsCursorMode = true;
  /// Indicators (fx) popover with search + categories + active list +
  /// catalog. JS posts `addIndicatorByKind` / `removeIndicatorById` to
  /// Flutter; the active pane's indicator list comes back via the
  /// `setActivePaneTopBarState` mirror. Per-indicator settings dialog
  /// (the cog on the chart's top-of-pane chip) still lives in Flutter
  /// via the existing `indicatorSettingsRequested` message.
  static const bool kJsIndicatorsButton = true;
  /// Order Defaults popover (tabs: SL/TP, Quantity, Product Type). JS owns
  /// the UI; Flutter pushes the full `OrderDefaults` bag via
  /// `setOrderDefaults` and accepts patch updates via `updateOrderDefaults`.
  /// Persistence stays in `OrderDefaultsNotifier` (Riverpod + SharedPrefs).
  static const bool kJsOrderDefaults = true;
  /// Settings popover (tabs: View on chart, Customize). View tab mirrors
  /// the active pane's per-pane toggles via `setActivePaneViewState`;
  /// Customize tab mirrors the palette via `setChartPaletteState`. Both
  /// post patch messages back. The Flutter Chart-type tab is dropped —
  /// duplicate of the JS Style picker button.
  static const bool kJsSettings = true;
  /// Symbol typeahead input. JS owns the input + popover + debouncing +
  /// keyboard nav; the actual scrip-search API stays in Flutter and is
  /// reached via `bridge.request('searchSymbols', {q})`. Picking a scrip
  /// posts `setActivePaneSymbol: {scrip}` which routes through the same
  /// `setPaneSymbol` notifier the watchlist / option chain panels use.
  static const bool kJsSymbolTypeAhead = true;
}
