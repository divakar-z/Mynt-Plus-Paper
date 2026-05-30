# Chart Engine — Phase 8 Design

**Date:** 2026-05-25
**Builds on:** Phases 1-7
**Scope summary:** Per-pane technical indicators. Phase 8 ships three: SMA, EMA, RSI. SMA/EMA draw as line overlays on the candle pane; RSI gets its own sub-pane below the candles (carves out a configurable fraction of the plot height). Add/remove indicators via the existing Settings popup. Configurable period per indicator; default colors per kind. Per-pane, persisted with the chart-engine session.

---

## 1. Goal

For each pane, the user can attach 0..N indicators:

| Kind | Render location | Inputs | Default period | Default color |
|---|---|---|---|---|
| SMA  | overlay on candle pane | close | 20 | `#3B82F6` (blue) |
| EMA  | overlay on candle pane | close | 20 | `#F59E0B` (amber) |
| RSI  | new sub-pane below candles | close | 14 | `#8B5CF6` (violet) |

Indicators are computed locally in the iframe from the candle array each time `_drawIndicators` runs (cheap — N candles × small constant).

Add via Settings popup → new "Indicators" section with `Add indicator` button. Each existing indicator shows a row with kind name, period input, color swatch, remove `×`.

---

## 2. Visual + interaction

### 2.1 Settings popup — Indicators section

Below the existing `Instant orders` block, add a third section:

```
─────────────────────────────────
Indicators                 [+ Add]

SMA · 20       [period: 20 ]  [×]
EMA · 20       [period: 20 ]  [×]
RSI · 14       [period: 14 ]  [×]
─────────────────────────────────
```

- Header row: `Indicators` label on left, `[+ Add]` outline button on right.
- Click `[+ Add]` → small inline menu (or dropdown) listing `SMA / EMA / RSI`. Pick → new indicator with that kind, default period, default color appended to `PaneState.indicators`.
- Each existing-indicator row: kind label (`SMA · 20`), tiny period text field (4 chars wide), `×` remove icon.
- Editing period in the text field commits on blur or Enter (int only, 1..999).

### 2.2 SMA / EMA on candle pane

Both render as a single line connecting the indicator's value for each visible candle:

- 1.5px solid line
- Color from `indicator.color`
- A small label chip at the right end with the indicator's kind+period (e.g. `SMA 20`), positioned just above the line at the rightmost candle's x

### 2.3 RSI sub-pane

When ≥1 RSI indicator is configured, the candle plot's `candleH` shrinks to make room for the RSI sub-pane below the volume sub-pane (if any). The RSI sub-pane:

- Occupies a fixed 18% of the inner plot height
- Drawn between the volume panel (if present) and the time gutter
- Shows a 0..100 scale with horizontal guidelines at 70 (overbought) and 30 (oversold), dashed in `palette.axisText`
- The RSI line drawn in the indicator's color
- Small label at top-left: `RSI 14` in muted text

If multiple RSI indicators are configured, ALL render in the SAME sub-pane (overlapping); each with its own color and label stacked vertically at the top-left.

### 2.4 Layout adjustment

The existing `_drawOhlc` plot-calculation block carves out `bottomGutter + topPad + volH` from total height. Phase 8 also subtracts `rsiH` (if any RSI indicator exists) before computing `candleH`:

```js
const rsiH = hasRsi ? Math.round(innerH * 0.18) : 0;
const candleH = innerH - volH - rsiH;
```

The RSI sub-pane sits at `y = volPlot.bottom + 1` (or `plot.bottom + 1` if no volume).

---

## 3. Data model

### 3.1 IndicatorConfig (Dart + JS parallel)

```dart
class IndicatorConfig {
  final String id;             // stable per-instance
  final String kind;           // 'sma' / 'ema' / 'rsi'
  final int period;            // 1..999
  final String color;          // hex string
  const IndicatorConfig({
    required this.id, required this.kind,
    required this.period, required this.color,
  });
  // toJson / fromJson
}
```

### 3.2 PaneState (NEW field)

`PaneState` gains:

```dart
final List<IndicatorConfig> indicators;  // default const []
```

Updated `copyWith` / `toJson` / `fromJson`. Indicators are per-pane (NOT per-scrip) — same pane keeps its indicators when the symbol changes. This matches TradingView convention.

### 3.3 Bridge message

```dart
String encodeSetPaneIndicators(String paneId, List<Map<String, Object?>> indicators);
```

Pushed in `_pushSession` per pane with `_pushedIndicatorsJson: Map<int, String>` diff cache.

No inbound message — indicators are pure config; the iframe doesn't initiate changes.

### 3.4 Notifier methods

```dart
void addIndicator(int paneIndex, IndicatorConfig cfg);
void removeIndicator(int paneIndex, String id);
void updateIndicator(int paneIndex, String id, {int? period, String? color});
```

All call `_schedulePersist()`.

---

## 4. Computation (JS)

In `chart.js`:

```js
function computeSMA(candles, period) {
  // returns array (length = candles.length) where the first (period-1) are null
  // and the rest are the simple moving average of close.
}
function computeEMA(candles, period) {
  // standard EMA with smoothing factor = 2/(period+1).
}
function computeRSI(candles, period) {
  // classical Wilder smoothing.
}
```

Computed each draw — N ~ a few thousand candles, cheap. No memoization needed for Phase 8.

---

## 5. Edge cases

| Case | Behaviour |
|---|---|
| Pane has no candles | All indicators silently render nothing |
| Period > candle count | Indicator returns all-nulls → renders nothing |
| Multiple SMAs same period, different color | Both render — visible as one line if exact same values; user's choice |
| Period <1 or non-int | Clamped to 1..999 |
| Volume off + RSI on | RSI sub-pane takes its slot directly under candles |
| Volume on + RSI on | Order top→bottom: candles, volume, RSI, time-gutter |
| Indicator list change | `_pushedIndicatorsJson` diff cache triggers re-push; chart redraws |
| Symbol change | Indicators stay (per pane); they recompute against new candles |
| Layout change | Existing layout-cache-clear path also clears `_pushedIndicatorsJson` |

---

## 6. Files to create / modify

### Modified (Flutter)
| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | `IndicatorConfig` class; `PaneState.indicators` field + JSON; notifier `addIndicator` / `removeIndicator` / `updateIndicator`. |
| `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart` | `encodeSetPaneIndicators(paneId, list)`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | `_pushedIndicatorsJson` cache; per-pane push in `_pushSession`. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | New `Indicators` section in `_SettingsButton` popup with Add menu, per-indicator row (period field + × remove). |

### Modified (JS)
| Path | What |
|---|---|
| `web/chart-engine/chart-engine.js` | `case 'setPaneIndicators'` → `chart.setIndicators(list)`. |
| `web/chart-engine/chart.js` | `this._indicators = []`; `setIndicators(list)`; `_drawIndicators(plot, priceToY, lo, hi)` (SMA/EMA lines on candle pane); `_drawRsiSubPane(rsiPlot)` (RSI sub-pane); `computeSMA` / `computeEMA` / `computeRSI` helpers; layout adjustment in `draw()` to carve out `rsiH`. |

No new files.

---

## 7. Acceptance smoke

1. Open Settings → see new `Indicators` section below Instant orders. Empty list, just `[+ Add]` button.
2. Click `+ Add` → menu shows `SMA / EMA / RSI`. Pick `SMA` → row appears: `SMA · 20  [20]  [×]`. Blue line appears on the chart.
3. Click `+ Add` → `EMA` → amber line appears alongside SMA.
4. Click `+ Add` → `RSI` → chart's candle area shrinks; new sub-pane appears below volume with the RSI line, 30/70 dashed guides, label `RSI 14`.
5. Edit SMA period to `50` → line recomputes (smoother).
6. Click `×` on RSI row → sub-pane disappears; candle area expands back.
7. Reload tab → indicators persist.
8. Switch symbol → indicators stay attached to the pane; recompute on new candles.
9. Add a second pane via cols2 → its indicator list is independent (empty by default).
10. Toggle Volume off in Settings while RSI is on → RSI sub-pane stays; candles use the extra room.

If everything passes, Phase 8 is done.

---

## 8. Out of scope (Phase 8.1+)

- More indicators (MACD, Bollinger, Stochastic, ATR, VWAP, Ichimoku, etc.)
- Per-indicator color picker UI (defaults only)
- Multi-source (use high/low/HLC3 instead of close)
- Indicators on indicators (e.g., MA-of-RSI)
- Multiple RSI sub-panes (currently all share one)
- Draggable sub-pane height
- Sub-pane for MACD (would need a 2nd sub-pane slot)
- Alert from indicator (e.g., "alert when RSI crosses 30")
