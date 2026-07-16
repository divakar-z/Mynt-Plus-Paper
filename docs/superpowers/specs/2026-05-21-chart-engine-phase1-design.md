# Chart Engine — Phase 1 Design

**Status:** approved through brainstorming · ready for implementation plan
**Date:** 2026-05-21
**Scope:** Single-chart MVP that becomes the foundation for the full TradingView-style chart application (Phases 2–7)

---

## 1. Goals & non-goals

**Goal:** Ship a fast, lightweight candlestick chart application embedded in the
Flutter web app, structurally designed so Phases 2–6 (multi-chart layouts,
position/order overlays, drag-to-modify, quick-trade sidebar, drag-drop SL)
extend it without architectural rework.

**Phase 1 specifically delivers:**
- A single chart pane rendering OHLCV candles for any tradable symbol on any
  supported timeframe.
- Symbol picker (type-ahead in the chart's top bar) and timeframe picker
  (dropdown, supports custom input).
- History from the existing `getTPSeriesChart` API with client-side aggregation;
  live ticks from the existing `websocket_provider`, forwarded into the iframe
  via `postMessage`.
- Pan / zoom / crosshair / auto-follow, theme inheritance from Flutter, top
  OHLC strip, optional volume panel.

**Non-goals for Phase 1 (deferred to later phases):**
- Multi-pane layouts (Phase 2)
- Universal symbol mode across panes (Phase 2)
- Position / order overlays (Phase 3)
- Quick-trade sidebar, right-side order panel (Phase 4)
- Drag-to-modify orders, hovered "+" button price actions (Phase 5)
- Drag-and-drop SL chip from sidebar (Phase 6)
- Indicators / drawing tools / alerts (Phase 7+)
- Sub-minute timeframes (no tick-history API for arbitrary symbols)
- Replacing the existing TradingView iframe in the stock-detail / market-watch
  screens — that stays; this chart application is a new destination.

## 2. Architecture

**Topology:** single iframe at `/chart-engine/index.html`, served as a static
asset from `web/chart-engine/`. Inside the iframe runs `chart-engine.js` that
manages an internal **pane registry**. Phase 1 = the registry holds exactly one
pane; Phase 2 grows the registry to N panes laid out in a CSS grid. The host
HTML never has to change between phases — only the messages Flutter sends and
how many `Chart` instances live in the registry.

**Why a single iframe (Approach B from brainstorming) instead of one iframe per
chart:** the multi-chart future means up to 6 charts on screen. N independent
iframes = N bootstraps, N canvases, N pointer-routing handshakes with the
Flutter compositor. One iframe with an internal grid keeps the load constant
and means a single `postMessage` per tick regardless of how many panes display
that symbol — the iframe routes the tick to whichever panes care.

**Why iframe at all (not pure Flutter CustomPainter):** browser-native canvas
2D drawing is significantly faster than CanvasKit at this kind of streaming
update workload, and the existing orderflow chart proved the pattern.

**Flutter ↔ iframe boundary:**
- Flutter owns the WebSocket subscription. The iframe asks Flutter to
  subscribe/unsubscribe per token; Flutter forwards matching tick packets
  into the iframe via `postMessage`. No iframe ever opens its own WS.
- Flutter owns API auth. The iframe asks Flutter to fetch history; Flutter
  calls `ApiExporter.getTPSeriesChart` and posts the result back.
- The iframe owns rendering, aggregation, pan/zoom state, and theme application.

## 3. Components

### Flutter side — `lib/screens/web/chart_engine/`

- **`ChartEngineShellScreen`** — `ConsumerStatefulWidget`. Hosts the
  `HtmlElementView`, registers a unique view factory per state instance
  (same remount-safe pattern as orderflow's shell), owns the iframe ID, the
  `postMessage` bridge, and a `ChartEngineStore`.
- **`ChartEngineTopBar`** — type-ahead symbol picker, timeframe dropdown
  (1m → 1M + "Custom…"), Settings popup. Mirrors orderflow's top bar UX
  including the iframe-pointer-events-gate pattern for popups.
- **`ChartEngineStore`** (Notifier) — holds per-pane state: `{symbol,
  timeframe, overlays}`. Phase 1 layout is fixed to `.single`. Persisted in
  Riverpod so navigating away/back restores selection.
- **`SymbolTypeAhead`** — compact `Autocomplete` driven by
  `searchScripForStrategyBuilder`. Debounced 200ms. Returns the full
  resolved scrip object (`{exch, token, tsym, dispName, ls, ti}`).
- **`TimeframePicker`** — dropdown with the preset list plus a "Custom…" tail
  item that opens a tiny dialog asking for `{value, unit}`. Result stored as
  minutes.

### JS side — `web/chart-engine/`

- **`index.html`** — minimal: `<div id="root">` plus `<script src="chart-engine.js">`.
  Loads Geist `@font-face` from `/assets/fonts/Geist/...` exactly like the
  orderflow chart does.
- **`style.css`** — CSS variables for theme, grid container, status pill.
- **`chart-engine.js`** — boot, registry, message bridge, layout grid
  renderer. Owns a `Map<paneId, Chart>` and the `Map<token, Set<paneId>>`
  used to route ticks.
- **`chart.js`** — exports `class Chart`. Constructor takes `{container,
  dpr, palette, postRequest}`. Methods: `setSymbol(scrip)`,
  `setTimeframe(minutes)`, `setOverlays({...})`, `setTheme(name)`,
  `ingestTick(packet)`, `resize()`, `destroy()`. Each instance owns a
  `<canvas>` and is self-contained — multiple instances coexist in one
  document with no shared mutable state.
- **`aggregator.js`** — pure functions. `bucketCandles(source, targetMinutes,
  tzOffset)` rolls source candles into target candles; `ingestTickIntoBucket(c,
  tick, aggState)` mutates the rightmost candle of an array with the tick's
  price/volume. Same monotonic-cumVol and late-tick guards already proven in
  orderflow.
- **`theme.js`** — `PALETTES.{light,dark}` definitions and `applyTheme(name)`
  helper.

## 4. Message bridge

All messages JSON-stringified for the round-trip (Dart Map → JS Object via
structured clone is unreliable, learned from orderflow).

### Flutter → iframe

| Message | Payload | Meaning |
|---|---|---|
| `setLayout` | `'single' \| '2v' \| '2h' \| '3' \| '4' \| '6'` | Recreate panes for this layout. **Phase 1 always uses `'single'`** and the iframe defaults to single-pane on boot, so Flutter doesn't need to send this until Phase 2. |
| `setPaneSymbol` | `{paneId, scrip}` where `scrip = {exch, token, tsym, dispName, ls, ti}`. Phase 1 `paneId === 'main'`. | Switch the named pane to this symbol |
| `setPaneTimeframe` | `{paneId, minutes}` | Switch the named pane to this timeframe (minutes int) |
| `setTheme` | `'light' \| 'dark'` | Apply theme to all panes + chrome |
| `setOverlays` | `{paneId?, gridlines, volume}` | Apply overlay settings (paneId optional → all panes) |
| `tick` | `{token, packet}` | Forward a WS tick packet to whichever panes subscribe to `token` |
| `historyResult` | `{requestId, candles}` | Reply to a previous `fetchHistory` request |
| `historyError` | `{requestId, message}` | Failed fetchHistory |

### Iframe → Flutter

| Message | Payload | Meaning |
|---|---|---|
| `chart-engine-ready` | `{}` | Initial handshake; Flutter responds with `setLayout` + `setPaneSymbol`/`setPaneTimeframe`/`setTheme`/`setOverlays` |
| `fetchHistory` | `{requestId, exch, token, interval, start, end}` | Ask Flutter to call `getTPSeriesChart` |
| `subscribe` | `{exch, token}` | Ask Flutter to add this token to the WS subscription |
| `unsubscribe` | `{exch, token}` | Ref-counted unsubscribe |

## 5. Data flow

### History fetch (symbol or timeframe change)

1. User picks a scrip from the type-ahead; Flutter resolves it via
   `searchScripForStrategyBuilder` and pushes
   `setPaneSymbol({paneId:'main', scrip:{exch, token, tsym, dispName, ls, ti}})`.
2. The `Chart` instance computes:
   - **Source interval** for `getTPSeriesChart`: `1m` for target <60min,
     `5m` for 60min ≤ target <1D, `1D` for target ≥1D.
   - **Window**:
     - 1m–30m → last 5 trading days
     - 1h–4h → last 60 days
     - 1D → last 2 years
     - 1W → last 5 years
     - 1M → last 20 years
     - Capped to ≤ 2000 source candles regardless.
3. Iframe posts `fetchHistory` with a fresh `requestId`. Flutter calls
   `ApiExporter.getTPSeriesChart(exch, token, interval, start, end)` and posts
   back `historyResult` (or `historyError`).
4. `aggregator.bucketCandles(sourceCandles, targetMinutes)` produces target
   candles. For weekly / monthly, week starts Monday IST, month starts 1st IST
   (Date math, not modular bucketing).
5. Chart redraws; auto-fit Y / auto-follow X engage.

### Live tick flow

1. After history loads successfully, `Chart` posts `subscribe({exch, token})`.
   `chart-engine.js` updates its internal `tokenToPanes` map.
2. Flutter receives `subscribe`, refcounts the token, calls
   `WebSubscriptionManager.subscribe` if new.
3. Flutter's existing tick handler dispatches each incoming WS packet to the
   iframe via `tick({token, packet})` for any tokens that have at least one
   pane subscribed.
4. Inside the iframe, `chart-engine.js` looks up `tokenToPanes.get(token)` and
   calls `chart.ingestTick(packet)` on each subscriber.
5. `ingestTick` updates the in-progress (rightmost) candle, or appends a new
   candle if `packet.ft * 1000` falls in the next bucket. Same guards as
   orderflow: drop on `dv <= 0` (late delivery) without touching aggState; drop
   on `bucketMs < c.ts` (out-of-order ft) without polluting the live candle.
6. On symbol or timeframe change, the `Chart` posts `unsubscribe` for the old
   token before the new history fetch. Refcount lets two panes on the same
   symbol share one upstream subscription.

### Timeframe definitions

Preset picker order: `1m, 2m, 3m, 5m, 10m, 15m, 30m, 1h, 2h, 4h, 1D, 1W, 1M`.

"Custom…" opens a dialog with a number input + unit dropdown (m / h / D / W).
Min 1 minute; no upper cap. Stored as integer minutes (`1h = 60`, `1D =
1440`, `1W = 10080`, `1M = 43200` for aggregation math; calendar-correct
weekly/monthly bucketing uses Date math regardless).

## 6. Rendering & interaction

### Layout inside the pane

| Region | Size |
|---|---|
| Top OHLC strip | 24px |
| Candle plot | flex, fills remaining height |
| Volume panel (when on) | ~25% of plot height, below candle plot |
| Right price gutter | 64px |
| Bottom time gutter | 24px |

### Candles

Continuous price→Y mapping (not the discrete-row grid orderflow uses):

```
y = plot.top + plot.height * (visibleHi - price) / (visibleHi - visibleLo)
```

Each candle = `cellW` pixels wide (default 10px, draggable 4–60 via the bottom
gutter). Body = filled rect from `priceToY(open)` to `priceToY(close)`, full
`cellW − 1px` wide, green/red by direction. Wick = 1px line from
`priceToY(low)` to `priceToY(high)` centered. Doji = 1px horizontal tick.

### Axes

- **Y-axis (right gutter):**
  - Auto mode (default): fit visible candles' price range with 8% padding.
  - Manual mode: drag the right gutter vertically → adjusts `pricePerPx`,
    switches to manual.
  - Vertical pan in chart body shifts the center.
  - Double-click → reset to auto.
  - Labels use the same "nice stride" algorithm as orderflow (1, 2, 5, 10,
    25, 50 … × priceStep).
- **X-axis (bottom gutter):**
  - Auto-follow: right edge anchored to latest candle.
  - Drag bottom gutter horizontally → adjusts `cellW`. Wheel = same.
    Shift+wheel = price zoom.
  - Drag chart body = horizontal pan; pulling left disengages auto-follow
    and reveals older history.
  - Labels stride based on `cellW`: nice-minute boundaries (00, 15, 30, 45
    for intraday; date breaks on day rollover; date-only for daily+).

### Volume panel

When `overlays.volume` is on, occupies ~25% of plot height at the bottom of
the candle area (separated by 1px divider, above the time gutter). Bar height
= `(vol / maxVisibleVol) * panelHeight`, color matches the candle's direction
at 0.5 alpha (full alpha on hover). When off, candle plot expands to fill the
freed space. Toggle lives in the Settings popup.

### Top OHLC strip

Identical pattern to orderflow: `O 23764  H 23770  L 23766  C 23770  V 1.3k
Δ +4`. Tracks hovered candle if cursor is inside the plot; otherwise the
latest candle. `Δ` is plain `close − open` for that candle (no bid/ask
split — this isn't footprint).

### Crosshair

Dashed cursor lines on hover, right-gutter price chip at hover Y, bottom-
gutter time chip at hover X. Suppressed while a drag is in flight.

### Theme

`?theme=light|dark` URL query param + `setTheme` postMessage. CSS variables
on `html.light` for the iframe chrome (top OHLC strip, status pill, overlay
card). Canvas palettes swapped at runtime by reassigning the `C` reference
and triggering a redraw. Same exact pattern as orderflow.

### Settings popup (in the Flutter top bar)

Phase 1 contents:
- Gridlines toggle
- Volume panel toggle

(Future phases add: indicator list, drawing tools, alerts, more.)

## 7. Routing & navigation

- New route `/charts` registered in `lib/routes/web_router.dart` (plural
  because the route ultimately hosts the multi-chart layout in Phase 2).
- Drawer entry **"Charts"** under the **TRADE** section in
  `lib/screens/web/home/widgets/app_bar/navigation_drawer_web.dart`,
  placed after **Orderflow**. Use whichever Lucide chart icon resolves in
  this build (`lineChart`, `barChart3`, or `activity` — `candlestickChart`
  is NOT present, confirmed in the Orderflow drawer-entry work).
- The route's `GoRoute.builder` returns
  `CustomizableSplitHomeScreen(initialRightPanel: ScreenTypeParam.charts)`
  (new enum value), reusing the same right-panel-host pattern as orderflow
  and scanner.

## 8. Error handling

| Failure | Behaviour |
|---|---|
| `getTPSeriesChart` HTTP error | Iframe overlay card: "Could not load history for SYMBOL · Retry". Retry refires the `fetchHistory` postMessage. |
| `getTPSeriesChart` returns empty | Overlay: "No history available" (no Retry — legitimate state for illiquid/halted scrips). |
| Symbol search returns no matches | Type-ahead dropdown shows "No matches". Existing chart stays. |
| WS disconnect | Flutter's existing `websocket_provider` auto-reconnects + re-subscribes. Iframe shows a small "Stale" pill in the top OHLC strip if no tick in 120s. |
| Out-of-order ticks (`dv <= 0` or `bucketMs < c.ts`) | Drop the tick. Don't update `aggState`. Don't fold into the live candle. Identical guards to orderflow. |
| Iframe blank after Flutter remount | Unique `viewType` per state instance, fresh `_iframeId` per mount — same remount fix landed for orderflow. |

## 9. Testing

- **Static gate:** `node --check web/chart-engine/*.js` in CI;
  `flutter analyze lib/screens/web/chart_engine` clean.
- **Manual smoke checklist** (in PR description):
  1. Open `/charts` → default symbol **NIFTY** loads with history (Phase 1 default; user can change immediately via type-ahead).
  2. Type "RELI" → pick RELIANCE-EQ → see unsubscribe NIFTY + subscribe RELIANCE + new history.
  3. Switch timeframe 1m → 5m → 1h → 1D — aggregator re-buckets cleanly each time.
  4. Pick "Custom…" → enter 7m → see 7-minute candles.
  5. Drag chart body left → see older candles, auto-follow disengage.
  6. Drag right axis → vertical zoom changes pricePerPx.
  7. Drag bottom axis → horizontal zoom changes cellW.
  8. Double-click → resets to auto-fit + auto-follow.
  9. Toggle volume in Settings → panel appears/disappears, candle area resizes.
  10. Toggle Gridlines in Settings → horizontal grid lines toggle.
  11. Toggle the app theme → chart chrome + canvas palette switch.
  12. Navigate to /home and back to /charts → state restored from store.
  13. Hover → crosshair, price chip, time chip, OHLC strip updates to hovered candle.
- Widget tests skipped (the screen is an HtmlElementView host; mocking the
  iframe gains nothing).

## 10. Performance budget

- Canvas with `dpr`-aware sizing.
- One `requestAnimationFrame`-throttled `draw()` per change. Live tick
  ingestion only triggers a redraw when the in-progress candle's OHLC
  actually changed value (skip pure volume-only updates that don't move the
  visible candle shape — the volume panel can still pick them up on the next
  ~16ms tick).
- Default cellW=10 with a 1200px plot = ~120 visible candles. Drawing 120
  candles is well under 1ms; the live-tick path stays under 1ms.
- Memory: target 2000 source candles per pane, ~64 bytes per candle = ~128KB.
  At 6 panes (Phase 2) that's <1MB.

## 11. Open questions for later phases (NOT Phase 1)

These are tracked here so we don't re-discover them in Phase 2 brainstorming:

- **Layout switcher UI** — Flutter widget or in-iframe controls? (Phase 2)
- **Universal symbol mode UX** — toggle in top bar? Per-pane lock icon? (Phase 2)
- **Order line positioning during zoom** — pixel-accurate at every zoom level
  given the continuous Y scale? (Phase 5)
- **Tradable-symbol detection** — no `isTradable` field on the scrip model
  currently; need a heuristic (e.g. `exch ∈ {NSE,BSE,NFO,BFO,MCX,CDS}` AND
  `instname ∈ {EQ,FUT,...}`) or a new backend field. (Phase 4)
- **Drag-to-modify order semantics** — what happens during the drag if the
  WS pushes an updated price for that same order? (Phase 5)
