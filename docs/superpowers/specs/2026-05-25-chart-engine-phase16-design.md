# Chart Engine — Phase 16 Design

**Date:** 2026-05-25
**Builds on:** Phases 1-15
**Scope summary:** Add 6 new candle/chart styles (Hollow, OHLC Bars, Line, Area, Heikin-Ashi, Renko) selectable per-pane from Settings, plus visible-range High / Low markers (colored chip + dashed leader, Style B from the visual brainstorm). Hybrid implementation — render-only for the 5 simple styles, dedicated transform pipeline for Renko only.

---

## 1. Goal

For each pane, surface a "Chart style" dropdown in the Settings popup with 7 options:

- **Candles** (default — already shipped)
- **Hollow Candles** — up = hollow, down = filled
- **OHLC Bars** — vertical H/L line with left-open / right-close ticks
- **Line** — close-only polyline
- **Area** — Line + gradient fill below
- **Heikin-Ashi** — smoothed candles using averaged OHLC
- **Renko** — time-independent bricks with ATR-based size

Add a "Show H / L markers" Switch (default ON) that draws colored chips with short dashed leaders at the highest and lowest visible candles. Both fields are per-pane and persist in the session JSON.

---

## 2. Visual

### 2.1 H / L marker style

Solid colored pill (green `#238636` for H, red `#da3633` for L) with white bold monospace text `H 1284.50` / `L 1198.20`, anchored to the highest wick top / lowest wick bottom via a short 2px dashed leader line in the matching color. Chip sits 14px outside the wick. Always 2 decimal places.

Clamped horizontally to `plot.left..plot.right`. If anchor is so close to `plot.top` that the chip would overflow above, push chip BELOW the wick instead (rare — only on heavily-zoomed views).

### 2.2 Settings popup

New rows at the top of the Settings popup (`_SettingsButton` in `chart_engine_top_bar.dart`):

```
┌────────────────────────────────────────┐
│ Chart style        [📊 Candles    ▾]  │  ← NEW row 1
│ Show H / L markers              [ ●] │  ← NEW row 2
│ ─────────────────────────────────────  │
│ Gridlines                       [ ●] │
│ Volume                          [ ○] │
│ Instant orders                  [ ●] │
│   ◐ Follow global  ○ Always  ○ Never │
│ Keyboard shortcuts          [ ○] ⓘ   │
│ ─────────────────────────────────────  │
│ Indicators                            │
│   …                                   │
└────────────────────────────────────────┘
```

- **Chart style** — `PopupMenuButton<String>` with 7 items. Each item: small leading icon, label, leading ✓ for current selection.
- When the active pane's style is `renko`, the row shows a subtitle chip `brick size: 4.50` read from a `renkoBrickSize` value the iframe pushes back on every recompute.
- **Show H / L markers** — `SwitchListTile`-style row, default ON.

Both bound to the **active pane** (`session.activePaneIndex`), matching the Phase 15 per-pane Instant override pattern. Switching active panes while popup is open → popup rebuilds with new pane's values (existing `ref.watch` infra).

### 2.3 No top-bar changes

No new chips, no new badges. Cleaner top bar; tradeoff is 2 clicks to change style (open Settings → pick).

---

## 3. Data model

`PaneState` gains:

```dart
final String candleStyle;        // 'candles' | 'hollow' | 'bars' | 'line' | 'area' | 'heikin-ashi' | 'renko'
final bool showHighLowMarkers;   // default: true
```

`copyWith` / `toJson` / `fromJson` updated using the sentinel pattern (same as `instantOverride`).

**Notifier methods on `ChartEngineSessionNotifier`:**

```dart
void setPaneCandleStyle(int index, String style);
void setPaneShowHighLowMarkers(int index, bool show);
```

Both call `_schedulePersist()` and emit a `pushSession` to the iframe.

**JSON omission policy** — both keys are omitted from `toJson` output when they equal the default (`'candles'` / `true`), matching how `instantOverride` works. Keeps the SharedPreferences blob tight; old payloads round-trip with defaults.

**Unknown values** — `fromJson` parser coerces unknown style strings to `'candles'` silently. No exception.

---

## 4. Architecture

### 4.1 Style routing in chart.js

Single switch at the top of `_drawBars` (renamed to `_drawSeries` for clarity):

```js
switch (this.candleStyle) {
  case 'line':        return this._drawLine();
  case 'area':        return this._drawArea();
  case 'bars':        return this._drawBars_OHLC();
  case 'hollow':      return this._drawCandles({hollow:true});
  case 'heikin-ashi': return this._drawCandles({heikinAshi:true});
  case 'renko':       return this._drawRenko();
  case 'candles':
  default:            return this._drawCandles({});
}
```

### 4.2 Simple styles (render-only, share `bars[]`)

All five reuse the existing raw OHLC `bars[]`. Indicators, overlays, drawings, crosshair — all untouched.

- **Hollow** — `ctx.strokeRect` (no fill) when `close >= open`; existing wick + bear-body path unchanged.
- **Bars (OHLC)** — vertical line at bar x from H to L; horizontal tick LEFT at `open` y; horizontal tick RIGHT at `close` y. Tick length = half candle width. Color = bullish/bearish by close vs open.
- **Line** — `ctx.lineTo` through `close` of every visible bar. Stroke = theme primary, 1.5px width. No wicks, no bodies.
- **Area** — Same path as Line + fill polygon down to plot bottom with vertical linear gradient (theme primary alpha 0.4 → 0). Stroke on top.
- **Heikin-Ashi** — Computed inline per bar; cached `_haPrev` between bars (reset on `setBars` and on style-switch AWAY from `heikin-ashi`):
  ```
  haClose = (O + H + L + C) / 4
  haOpen  = prev ? (prevHaOpen + prevHaClose) / 2 : (O + C) / 2
  haHigh  = max(H, haOpen, haClose)
  haLow   = min(L, haOpen, haClose)
  ```
  Drawn exactly like candles using `(haOpen, haHigh, haLow, haClose)`. Indicators still run on raw `bars[]` (TradingView's behaviour).

### 4.3 Renko pipeline (dedicated transform)

Bricks live in `this._renkoBricks = []` on the Chart instance.

**Brick model:**
```js
{ idx, openPrice, closePrice, direction, sourceBarTime, sourceBarIndex }
```

**Brick size:** ATR(14) of `this.bars`, snapped to tick size. Computed in `_computeRenkoBrickSize()`. Fallback: `(maxHigh - minLow) / bars.length` when `bars.length < 14`. Re-pushed to Flutter as `renkoBrickSize` so the Settings subtitle can display it.

**Build (`_rebuildRenko()`)** — runs on style-switch INTO `renko`, on `setBars`, and on "load more history" backfill:

```
size = _computeRenkoBrickSize()
brick0 = { closePrice: bars[0].close, openPrice: bars[0].close, direction:'up', idx:0,
           sourceBarTime: bars[0].time, sourceBarIndex: 0 }
push brick0
for each bar in bars[1..]:
  diff = bar.close - last.closePrice
  if last.direction == 'up' && diff >= size:
    add N up-bricks where N = floor(diff / size)
  else if last.direction == 'up' && diff <= -2*size:
    add 1 down-brick (reverse) at closePrice - size; continue if diff still exceeds
  // symmetric for down-direction
```

2×size reversal rule matches TradingView default.

**Tick update (`_updateRenkoFromTick(price)`)** — called from existing per-tick handler. O(1) common case:

```
diff = price - last.closePrice
if last.direction == 'up' && diff >= size: append up-brick(s)
else if last.direction == 'up' && diff <= -2*size: append reverse down-brick(s)
// symmetric
```

Auto-scroll keeps latest brick in view like normal.

**Draw (`_drawRenko()`)** — for each visible brick: filled rect `(idx*W, plotY(openPrice))` → `((idx+1)*W - gap, plotY(closePrice))`. Green for up, red for down. No wicks.

**X-axis on Renko** — labels show `sourceBarTime` of every Nth visible brick (non-uniform spacing — that's expected and matches TradingView).

**Indicators on Renko** — run against `_renkoBricks.map(b => b.closePrice)` instead of `bars.map(b => b.close)`. Indicator code already takes a generic series — just swap which array is passed in. Switching back to a time-axis style re-binds indicators to `bars[]` automatically.

**Volume row** — hidden on Renko panes (per-brick volume isn't meaningful).

**Crosshair on Renko** — tooltip shows `Brick #N · src 14:25:30 · O / C` instead of OHLC.

### 4.4 Visible-range H / L markers

New `_drawHighLowMarkers(ctx)` called AFTER candles/bricks but BEFORE order chips and crosshair (z-order: order chips can cover markers; markers don't block orders).

```
scan visible bars [firstVisible..lastVisible]:
  track maxHigh + index, minLow + index
  (For Line/Area: use bar.close instead of bar.high/bar.low)
  (For Renko: scan _renkoBricks visible range, use closePrice)
draw H chip:
  anchorX = barCenterX(maxIdx)
  anchorY = priceToY(maxHigh)
  chipY   = anchorY - 14
  dashed line: (anchorX, anchorY) → (anchorX, anchorY - 8), color #56d364
  rounded rect chip (radius 2, pad 3×6), fill #238636, white bold text "H 1284.50"
  clamp chipX to plot.left..plot.right
draw L chip (mirrored, fill #da3633, color #f85149)
hide conditions:
  pane.showHighLowMarkers === false
  visible bar count < 2
  maxHigh === minLow (flat)
```

Re-scanned every `draw()` call (pan/zoom/tick/resize). Negligible cost — one loop over ~200 visible bars.

Tie-breaking: leftmost bar wins.

### 4.5 No bridge / postMessage changes

Both new fields ride the existing `pushSession` payload. `chart-engine.js` already shallow-merges into each `Chart` instance. We add `candleStyle` and `showHighLowMarkers` to whatever consumer code reads them in `chart.js`. The `renkoBrickSize` value back to Flutter rides the existing `paneStatus` push (or a new lightweight one — implementation detail for the plan).

---

## 5. Edge cases

| Case | Behaviour |
|---|---|
| Drawings on Renko panes | Horizontal line / horizontal ray → drawn (price-only, no time). Trendline / rectangle / fib → hidden on Renko (time anchor meaningless). Switching back restores them. |
| Overlays (orders/positions) on Renko | Drawn normally — anchored to price Y, chip pinned to right of plot. Drag-modify still works. |
| Volume row on Renko | Hidden. |
| Tick stream on Renko | `_updateRenkoFromTick(price)` appends 0..N bricks per tick. Auto-scroll keeps latest brick visible. |
| Loading more history (scroll-back) | `_rebuildRenko()` re-runs on expanded `bars[]`. ATR recomputes. Brick indices renumber. |
| Indicators on Renko | Run against `_renkoBricks` close series. Re-bind to `bars[]` on style-switch out. |
| HA cache reset | `_haPrev` cleared on `setBars` AND on style-switch away from `heikin-ashi`. |
| Crosshair on Renko | Shows `Brick #N · src time · O / C`. |
| Flat visible range | H == L → both markers skipped. |
| Trading-hours filter | Applied at `bars[]` level; Renko inherits since it builds from bars. |
| Old session JSON | Missing `candleStyle` → `'candles'`. Missing `showHighLowMarkers` → `true`. No migration. |
| Unknown style string | Coerced to `'candles'` silently. |
| Multi-pane independence | Each pane carries own `candleStyle` + `showHighLowMarkers`. cols2 with `[Candles, Heikin-Ashi]` works out of the box. |

---

## 6. Files

| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | Add `candleStyle` and `showHighLowMarkers` to `PaneState` + `copyWith` / `toJson` / `fromJson` (sentinel pattern, omit-default). Notifier methods `setPaneCandleStyle(int, String)` and `setPaneShowHighLowMarkers(int, bool)`. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | Two new rows at the top of the Settings popup: "Chart style" `PopupMenuButton<String>` (7 items, leading icons, current-selection ✓, Renko subtitle showing brick size) + "Show H / L markers" `SwitchListTile`-style row. Both bound to active pane. |
| `web/chart-engine/chart-engine.js` | Plumb `candleStyle` and `showHighLowMarkers` from session payload into each pane's `Chart` instance. Forward `renkoBrickSize` back to Flutter via existing status push. |
| `web/chart-engine/chart.js` | New draw functions: `_drawHollow` (option flag in `_drawCandles`), `_drawBars_OHLC`, `_drawLine`, `_drawArea`, `_drawCandles({heikinAshi:true})` path with `_haPrev` cache. Renko: `_renkoBricks[]`, `_computeRenkoBrickSize`, `_rebuildRenko`, `_updateRenkoFromTick`, `_drawRenko`. H/L markers: `_drawHighLowMarkers`. Style switch at top of `_drawSeries`. Indicator series swap for Renko (`_indicatorSeries()` returns either `bars` closes or `_renkoBricks` closes). Volume hide on Renko. Crosshair tooltip variant for Renko. Drawing hide-list on Renko (trendline / rectangle / fib only). |

No bridge changes (no new postMessage types). No new dependencies. No backend changes.

---

## 7. Acceptance smoke

1. Open `/charts` default → still Candles, H/L markers visible.
2. Settings popup → see "Chart style" dropdown + "Show H / L markers" Switch at top.
3. Cycle through all 7 styles on a single pane → visuals match the picker mockups.
4. On Renko → x-axis is brick index, EMA(20) follows brick closes, brick-size subtitle appears in Settings.
5. Pan / zoom → H/L chips track new visible extremes.
6. Toggle "Show H / L markers" off → chips disappear; on → reappear.
7. Drag-modify order while on Heikin-Ashi and on Renko → still works.
8. Add a trendline on Candles → switch to Renko → trendline hides; back to Candles → trendline returns.
9. `cols2` layout, pane 0 = Candles, pane 1 = Renko → independent. Pane 1's Settings shows Renko subtitle, pane 0 doesn't.
10. Reload tab → style + H/L flag persist per pane.
11. Live tick during Renko → new bricks append, auto-scroll keeps latest in view.
12. Switch from Renko → Candles → indicators re-bind to bars without artifacts.

---

## 8. Out of scope (Phase 16.1+)

- **Custom candle colors** (per-element bull/bear/wick/grid pickers — Sahi has this; deferred)
- **Line/Area source picker** (Open / HL2 / HLC3 / OHLC4 — currently Close only)
- **Renko fixed brick size override** (ATR-auto only in Phase 16)
- **Range bars, Kagi, Point & Figure** chart types (advanced, niche)
- **Brick-size recompute frequency UI** (recomputes on data change; no manual trigger)
- **High/Low markers for ALL-TIME extremes** (visible-range only)
- **Day H / Day L horizontal lines** (different concept — could be a separate phase)
