# Chart Engine — Phase 11 Design

**Date:** 2026-05-25
**Builds on:** Phases 1-10 (Phase 8 added SMA/EMA/RSI infrastructure)
**Scope summary:** Add 5 more indicator kinds — **Bollinger Bands (BB)** and **VWAP** as candle-pane overlays; **MACD**, **Stochastic (STOCH)**, and **ATR** as sub-pane indicators stacked below the candles. Configuration kept minimal: one period field per indicator (multi-param defaults are hardcoded).

---

## 1. Goal

Extend the existing `IndicatorConfig` system (Phase 8) with 5 new kinds:

| Kind | Render | Default config | Color |
|---|---|---|---|
| `bb`    | overlay (3 lines: upper, mid, lower) | period 20, stddev 2 | violet |
| `vwap`  | overlay (1 line, session-anchored) | (no period) | cyan |
| `macd`  | sub-pane (MACD line + signal line + histogram) | fast 12, slow 26, signal 9 | blue/orange/grey |
| `stoch` | sub-pane (%K + %D + 20/80 guides) | period 14, smooth 3 | violet/amber |
| `atr`   | sub-pane (single line) | period 14 | green |

Multi-parameter indicators (BB, MACD, Stoch) use hardcoded secondary params for Phase 11; only the primary `period` field is editable. UI for full multi-param config is Phase 11.1+.

---

## 2. Visual

### 2.1 Candle-pane overlays (BB, VWAP)

Drawn in `_drawIndicators` next to SMA/EMA. Each draws its colored line(s) over the candle area with a labeled chip at the rightmost candle.

- **BB:** three lines — upper (period 20 SMA + 2σ), mid (period 20 SMA), lower (period 20 SMA − 2σ). All in the indicator's color (violet). Mid drawn solid; upper/lower drawn slightly thinner (1px vs 1.5px).
- **VWAP:** single line from session anchor (first candle of the visible series, or the first candle whose date differs from previous — TradingView resets VWAP daily). Color cyan. Period field ignored.

### 2.2 Sub-pane indicators (MACD, STOCH, ATR)

Each sub-pane indicator gets its own slot below the volume panel. If multiple sub-pane indicators are active, they stack vertically. Each takes equal share of the reserved sub-pane area (min 60px per slot; if total exceeds 50% of plot height, the candle plot is the one that shrinks).

Sub-pane drawing per kind:

- **MACD:** MACD line (blue) + signal line (orange) + histogram (grey bars, positive above zero / negative below). Zero line dashed grey.
- **STOCH:** %K line (violet) + %D line (amber). 20 / 80 dashed guides.
- **ATR:** single line (green). No guides.

Top-left label per sub-pane: `MACD 12/26/9`, `STOCH 14/3`, `ATR 14`.

### 2.3 Settings popup — Add menu

Current Add menu has 3 items: `SMA / EMA / RSI`. Phase 11 adds 5 more, listed in this order:

```
SMA  EMA  BB   VWAP
RSI  MACD STOCH ATR
```

(4 per row, 2 rows.)

### 2.4 Settings popup — per-indicator row

Existing rows already show kind name + period input + remove `×`. No changes — period defaults to the kind's primary period (BB 20, MACD 12, STOCH 14, ATR 14, VWAP ignored).

For multi-param kinds (BB stddev=2, MACD slow=26 signal=9, STOCH smooth=3), values are hardcoded in chart.js for Phase 11.

---

## 3. Data model

### 3.1 Reused IndicatorConfig

No changes to the existing `IndicatorConfig` class. Kinds added as new string values:

```
'sma' | 'ema' | 'rsi'  (Phase 8 — existing)
'bb' | 'vwap'           (Phase 11 — candle-pane overlays)
'macd' | 'stoch' | 'atr' (Phase 11 — sub-pane)
```

No bridge changes (the existing `encodeSetPaneIndicators` already pushes the full list).

### 3.2 Hardcoded secondary params

In chart.js compute helpers:

```js
const BB_STDDEV = 2;
const MACD_FAST = 12;
const MACD_SLOW = 26;
const MACD_SIGNAL = 9;
const STOCH_SMOOTH = 3;
```

VWAP has no params (resets on session/day boundary).

---

## 4. Architecture

### 4.1 chart.js compute helpers (NEW)

```js
_computeBB(period)    // returns { mid: [...], upper: [...], lower: [...] }
_computeVWAP()        // returns array (length = candles.length); resets per day
_computeMACD()        // returns { macd: [...], signal: [...], hist: [...] }
_computeStoch(period) // returns { k: [...], d: [...] }
_computeATR(period)   // returns [...]  (Wilder smoothed)
```

### 4.2 `_drawIndicators` — extended

Inside the existing for-loop, branch:

- `kind === 'sma' || kind === 'ema'`: existing path
- `kind === 'bb'`: draw 3 lines (mid + upper + lower) using `_computeBB(period)`
- `kind === 'vwap'`: draw 1 line using `_computeVWAP()`

Sub-pane indicators (rsi/macd/stoch/atr) are SKIPPED here — they're rendered by `_drawSubPanes`.

### 4.3 `_drawRsiSubPane` → generalized to `_drawSubPanes`

Replace the existing single-RSI `_drawRsiSubPane(rsiPlot)` with a list-driven `_drawSubPanes(subPlots)` where `subPlots` is an array of `{ kind, period, color, id, rect }`. Each entry gets its own drawing routine:

```js
_drawSubPanes(subPlots) {
  for (const sp of subPlots) {
    switch (sp.kind) {
      case 'rsi':   this._drawRsiInPane(sp); break;
      case 'macd':  this._drawMacdInPane(sp); break;
      case 'stoch': this._drawStochInPane(sp); break;
      case 'atr':   this._drawAtrInPane(sp); break;
    }
  }
}
```

### 4.4 Layout — N sub-panes

Current Phase 8 carve-out:

```js
const hasRsi = this._indicators.some((i) => i.kind === 'rsi');
const rsiH = hasRsi ? Math.round(innerH * 0.18) : 0;
const candleH = innerH - volH - rsiH;
```

Generalize:

```js
const subKinds = new Set(['rsi', 'macd', 'stoch', 'atr']);
const subPaneIndicators = this._indicators.filter((i) => subKinds.has(i.kind));
const subPaneCount = subPaneIndicators.length;
const subPaneTotalH = subPaneCount > 0
    ? Math.min(Math.round(innerH * 0.5), Math.max(60 * subPaneCount, Math.round(innerH * 0.18 * subPaneCount)))
    : 0;
const candleH = innerH - volH - subPaneTotalH;
```

Then compute each sub-pane's rect:

```js
const subPaneH = subPaneCount > 0 ? subPaneTotalH / subPaneCount : 0;
let cursorY = (volPlot ? volPlot.bottom : plot.bottom) + 1;
const subPlots = subPaneIndicators.map((ind) => {
  const r = { kind: ind.kind, period: ind.period, color: ind.color, id: ind.id,
              rect: { left: plot.left, top: cursorY, right: plot.right,
                      bottom: cursorY + subPaneH,
                      width: plot.right - plot.left, height: subPaneH } };
  cursorY += subPaneH;
  return r;
});
```

Multiple instances of the same kind (e.g. two RSIs) get separate sub-panes — simpler than Phase 8's "share one sub-pane" approach.

### 4.5 Flutter — Settings popup menu

In `_IndicatorsSection`, extend the menu loop:

```dart
const kinds = ['sma', 'ema', 'bb', 'vwap', 'rsi', 'macd', 'stoch', 'atr'];
```

Update `_defaultColor` + `_defaultPeriod` per kind.

---

## 5. Edge cases

| Case | Behaviour |
|---|---|
| Candle count < indicator period | Indicator returns all-nulls; renders nothing |
| Multiple sub-pane indicators | Each gets its own slot, stacked vertically |
| Volume off + multiple sub-panes | Sub-panes take volume's old space |
| VWAP day boundary detection | Reset whenever `floor(ts / 86400) != prev` — daily reset (IST agnostic) |
| BB stddev=0 (degenerate) | Upper = lower = mid; render as single line |
| MACD signal not ready (first 26+9 bars) | Renders only after `slow + signal` bars |
| ATR first bar | Initialized to TR1; standard Wilder smoothing |
| Indicator removed mid-render | Provider push removes it; next draw skips |

---

## 6. Files

### Modified (Flutter)
| Path | What |
|---|---|
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | `_IndicatorsSection` adds 5 new kind chips in the Add menu + their default period/color. |

### Modified (JS)
| Path | What |
|---|---|
| `web/chart-engine/chart.js` | 5 new compute helpers; `_drawIndicators` extended for bb/vwap; `_drawRsiSubPane` generalized to `_drawSubPanes` + new per-kind sub-pane drawers (`_drawRsiInPane`, `_drawMacdInPane`, `_drawStochInPane`, `_drawAtrInPane`); layout logic in `draw()` handles N sub-panes. |

No new files. No bridge changes.

---

## 7. Acceptance smoke

1. Open `/charts`. Open Settings → Indicators → Add menu now shows 8 kinds in 2 rows.
2. Add `BB` → 3 violet lines render on the candle pane (mid solid, upper/lower thinner).
3. Add `VWAP` → cyan line from the start of the visible session.
4. Add `MACD` → new sub-pane below volume with MACD/signal lines + histogram + zero line.
5. Add `STOCH` → another sub-pane below MACD with %K/%D + 20/80 guides.
6. Add `ATR` → another sub-pane with single ATR line.
7. With all 3 sub-panes active, candles shrink but stay readable; each sub-pane has ≥60px height.
8. Remove RSI → its sub-pane disappears; candles expand.
9. Edit MACD period to 26 → recomputes (slower MACD line).
10. Reload tab → all 5 indicators persist with their colors + periods.
11. Toggle theme → all colors adapt (or stay constant per kind — palette-based later).

---

## 8. Out of scope (Phase 11.1+)

- Per-multi-param config UI (BB stddev, MACD slow/signal, STOCH smooth)
- Indicator color picker (uses defaults only)
- Custom indicator presets
- More indicators (Ichimoku, Parabolic SAR, Keltner, Donchian, Awesome Osc, …)
- Indicator alerts ("alert when RSI crosses 30")
- Anchored VWAP (user-picked anchor)
- Show/hide indicators without removing
- Drag sub-pane height
