# Trade from Chart Toggle — Design

**Status:** Approved — implementation pending
**Date:** 2026-06-02

## Goal

Add a "Trade from Chart" toggle button to the symbol details screen's
segment tab row. Toggles the chart area between two engines:

- **OFF (default):** existing TradingView portal (`WebChartManager`) — unchanged
- **ON:** in-house chart engine (`ChartEngineShellScreen`) embedded inline,
  with full top bar (Symbol search, Timeframe, INSTANT, indicators, draw,
  etc.), single-pane layout, and the right panel (`ScripDepthInfoWeb`) hidden

Per-session persistence via `localStorage` — sticks across page refreshes.
Default for new users: OFF.

## Architecture

```
ChartWithDepthWeb (existing — minimal edits)
├── Segment tab row
│   ├── Overview · Chart · Options · Stock Report  (existing pills)
│   └── [Trade from Chart] toggle pill              (NEW, on the right)
├── Content area (existing `_buildContentArea`)
│   ├── tradeFromChart=OFF → CompositedTransformTarget (TradingView portal)
│   └── tradeFromChart=ON  → EmbeddedChartView         (NEW)
│                            └── ChartEngineShellScreen(embedded:true)
└── ScripDepthInfoWeb panel  → auto-hidden when toggle ON
```

## Components

### 1. `tradeFromChartModeProvider`

New `Notifier<bool>` in
`lib/screens/web/market_watch/state/trade_from_chart_mode_provider.dart`.

- Hydrates from `SharedPreferences.getString('tradeFromChartMode')`
  (string "1"/"0" for consistency with our other persisted flags)
- `toggle()`: flips state, persists, AND if turning ON calls
  `ref.read(marketWatchProvider).setIsDepthVisibleWeb(false)` so the
  right panel auto-closes
- ~50 LoC

### 2. Toggle button widget

New pill button rendered after the last tab in `_buildSegmentedControl`
(or in a sibling Row to keep tab logic clean). Matches the existing pill
style (same padding, border-radius, hover treatment) so it doesn't look
foreign:

- Default (OFF) state: muted text + small candlestick icon, label "Trade
  from Chart"
- Active (ON) state: accent-filled background, white text, label still
  "Trade from Chart" (the fill IS the indicator that it's on)
- Tap → `ref.read(tradeFromChartModeProvider.notifier).toggle()`

### 3. `EmbeddedChartView`

New widget in
`lib/screens/web/market_watch/widgets/embedded_chart_view.dart`.

Responsibilities:
- Wraps `ChartEngineShellScreen(embedded: true)` and fills its parent
- **Symbol sync** (the critical bit): on first build AND whenever the
  details screen's `currentScrip` changes, push the scrip into the chart
  engine's pane 0:
  ```dart
  void _syncSymbol(ChartScrip scrip) {
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    // Force single-pane layout (per user decision — multi-pane is the
    // workspace's job, not the embedded details view)
    if (ref.read(chartEngineSessionProvider).layout != ChartLayout.single) {
      notifier.setLayout(ChartLayout.single);
    }
    notifier.setPaneSymbol(0, scrip);
  }
  ```
- Uses `ref.listen(marketWatchProvider.select(...))` for symbol changes
  (cheap, only fires on actual scrip change)
- ~80 LoC

### 4. `ChartEngineShellScreen` — `embedded` flag

Add optional `final bool embedded;` parameter (default `false`). When
`embedded: true`:
- Skip the outer full-screen layout assumptions (no extra padding /
  background fill — the parent owns layout)
- The HTML top bar inside the iframe still renders — that's exactly what
  makes it "Trade from Chart"
- Right tray is NOT this widget's concern (it's a sibling — handled by
  hiding `ScripDepthInfoWeb` in the parent)
- ~10-15 LoC change

### 5. `_buildContentArea` switch

In `chart_with_depth_web.dart`'s existing `_buildContentArea` method,
when the active tab is Overview (0) or Chart (1):

```dart
final tradeFromChart = ref.watch(tradeFromChartModeProvider);
if (tradeFromChart) {
  final currentScrip = _scripFromMarketWatch();  // builds ChartScrip from mw
  return EmbeddedChartView(scrip: currentScrip);
}
// else: existing CompositedTransformTarget portal path — unchanged
```

`_scripFromMarketWatch` is a small helper that builds the chart-engine's
`ChartScrip` from `marketWatchProvider`'s current scrip-info-model.
Maps the broker fields (exch / token / tsym / dispName / ls / ti /
instname).

## Data flow

```
User clicks "Trade from Chart" pill
  ↓ tradeFromChartModeProvider.toggle()
  ↓ writes localStorage + sets isDepthVisible=false
  ↓ Riverpod notify → ChartWithDepthWeb rebuilds
  ↓ _buildContentArea takes the tradeFromChart=true branch
  ↓ EmbeddedChartView mounts
  ↓ on first build: setPaneSymbol(0, currentScrip), setLayout(single)
  ↓ iframe loads → existing chart engine machinery (history fetch, WS
    subscribe, render) takes over

User switches symbol from search/watchlist
  ↓ marketWatchProvider state updates
  ↓ EmbeddedChartView's ref.listen fires
  ↓ setPaneSymbol(0, newScrip) → chart engine reloads
```

## Edge cases & decisions

| Case | Decision |
|---|---|
| User on Overview tab, toggles ON | In-house chart replaces the portal target. Overview tab now shows in-house chart (same as Chart tab does). |
| User on Options/Stock Report tab, toggles ON | State changes; takes effect when they switch back to Overview/Chart. |
| Symbol switches while ON | `ref.listen` fires → `setPaneSymbol(0, newScrip)` → chart engine reloads with new symbol. |
| Depth panel open, then toggle ON | Depth panel auto-closes via `setIsDepthVisibleWeb(false)`. |
| Toggle OFF | Depth panel does NOT auto-reopen (user can reopen manually). Existing portal returns. |
| Multiple browser tabs | localStorage syncs naturally — other tabs pick up the change on next navigation/rebuild. |
| Chart engine session already has multi-pane layout from /chart-engine workspace | **Force `ChartLayout.single` when entering embedded mode.** Per user decision: multi-pane is the workspace's job; if user wants multi-pane they go to /chart-engine. The session's prior multi-pane layout is *replaced* (not preserved across modes — keeping it simple). |
| Toggle off while embedded chart is mid-history-fetch | iframe gets unmounted (widget tree change). WS subs are cleaned up by the existing shell's `_handleUnsubscribe` path. No leak. |
| Multiple iframes (workspace open in another tab + embedded here) | Independent iframe instances. They don't share state at the JS layer. Each has its own session subscription via the Dart bridge. |

## Default behavior

- New users: toggle OFF (TradingView default, unchanged behavior)
- After first toggle ON: persisted, sticks across reloads
- After first toggle OFF post-ON: persisted as OFF, sticks

## Files touched

| File | Change |
|---|---|
| `lib/screens/web/market_watch/state/trade_from_chart_mode_provider.dart` | NEW — `Notifier<bool>` with SharedPreferences persistence |
| `lib/screens/web/market_watch/widgets/embedded_chart_view.dart` | NEW — wraps `ChartEngineShellScreen(embedded:true)` + symbol sync |
| `lib/screens/web/market_watch/chart_with_depth_web.dart` | MODIFY — add toggle pill to segment row, branch in `_buildContentArea` |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | MODIFY — add optional `embedded` parameter, gate full-screen-only chrome |

## What's NOT in scope

- Adjusting the in-house chart engine itself (already complete)
- Changing the TradingView portal path
- Migrating any of the indicators
- Per-symbol toggle persistence (out per user decision — global toggle is enough)
- Multi-pane layout in embedded mode (out per user decision)

## Static gates

- `flutter analyze lib/screens/web` clean
- `flutter analyze lib/screens/web/chart_engine` clean
- No JS changes — `node --check` not needed for this work
