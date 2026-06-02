# CISD Indicator — Design

**Status:** Approved — implementation pending
**Author:** Claude (with Prem)
**Date:** 2026-05-30

## Goal

Add a **CISD (Change in State of Delivery)** indicator to the in-house chart
engine. CISD is an ICT/SMC price-action concept that marks the precise candle
where price commits to a new direction by closing through the opening price
of the most recent opposing "delivery leg" (a single or consecutive run of
same-color candles).

Ships with two modes:
- **Permissive** — every CISD is detected and drawn (high-frequency visual)
- **Strict** — only CISDs that occur at a swing-pivot AND meet a displacement
  threshold (body-to-range ratio) are drawn, plus ▲/▼ buy/sell markers

## Background / canonical rules

Sourced from a deep-research pass on 2026-05-30 (19/25 verified claims),
citing innercircletrader.net and the most-used TradingView community
implementations: LuxAlgo, EmpArchitect, AlgoAlpha, FibAlgo. The
"ATR(14) × 1.5 is the standard displacement default" claim was REFUTED
0-3 across sources — no canonical multiplier exists; we ship a
body-to-range ratio filter instead (which has consensus defaults).

### Definition

A **delivery leg** is a single candle OR a maximal consecutive run of
same-color candles. Its "reference open" is the **FIRST candle's open** in
the run (per LuxAlgo + innercircletrader.net consensus).

A **bullish CISD** fires on candle `c` when:
1. The most recent prior delivery leg was bearish (run of red candles)
2. `c` is a green candle
3. `c.close > priorBearishLeg.firstCandle.open`

**Bearish CISD** is the symmetric inverse (close < prior bullish leg's open).

### THE wick rule (most-cited, doctrinal)

> **Wicks are ignored. Only candle opens and closes matter.** A wick poke
> through the opposing leg's open is NOT a CISD. Only a body close counts.

This is the canonical distinction between CISD (body-based) and MSS (which
can be wick-based). Strict implementations follow this without exception.

### Strict mode adds two filters

**Filter 1: Swing context** — the opposing leg's first candle must sit at a
fractal swing pivot:
- Bullish CISD: the bearish leg's first candle is at a **swing low** (its low
  is the lowest within ±N bars)
- Bearish CISD: the bullish leg's first candle is at a **swing high**

Pivot width `N` defaults to 2 (5-candle fractal: 2 left + center + 2 right).
The canonical ICT default is 1 (3-candle), but the strict path uses 2 for
noise reduction. Configurable.

**Filter 2: Displacement** — the candle that fires the CISD must have a
strong body:

```
bodyRatio = abs(close - open) / (high - low)   // 0..1
displacement = bodyRatio >= minBodyRatio
```

Default `minBodyRatio = 0.65` (strict) / `0.50` (permissive). Configurable.

Dojis (open == close, range > 0) have `bodyRatio = 0` and never qualify as
displacement candles. Range-0 candles (rare, gap or print error) are skipped
entirely.

## Architecture

CISD slots into the existing indicator framework:
1. **Catalog entry** — new `'cisd'` entry in the JS `INDICATOR_CATALOG` and
   the Flutter `_catalog` table (both with full name and category)
2. **Compute function** — `_computeCisd(ind)` in `chart.js` returns the
   per-candle list of CISD events
3. **Default params** — `defaultIndicatorColor('cisd')`,
   `defaultIndicatorPeriod('cisd')` in `chart_engine_store.dart`
4. **Schema** — `indicator_schema.dart` gets a `'cisd'` entry exposing the
   configurable params (mode, pivot width, min body ratio, max lines,
   expiry bars, bullish color, bearish color)
5. **Rendering** — chart.js draws lines + markers in the existing
   `_drawIndicators` path

No changes to the bridge protocol — CISD piggy-backs on the existing
indicator add/remove/settings flows already wired through `addIndicator`,
`removeIndicator`, and the per-indicator settings dialog.

## Components

### 1. Compute function (`web/chart-engine/chart.js`)

```js
// Returns { events: Array<{i, kind, level, isStrict}>, byIndex: Map<i, event> }
// Memoized via the existing _installComputeMemo() wrapper.
_computeCisd(ind) {
  const candles = this.candles;
  const p = ind.params || {};
  const mode = p.mode || 'strict';                     // 'strict' | 'permissive'
  const pivotWidth = p.pivotWidth ?? 2;                // bars each side
  const minBody = p.minBodyRatio ?? (mode === 'strict' ? 0.65 : 0.50);
  const expiryBars = p.expiryBars ?? 50;               // line lifetime

  // 1) Walk candles, group consecutive same-color into delivery legs.
  // 2) For each candle c (skip dojis), check whether c.close pierces the
  //    previous opposing leg's first.open. Emit a candidate event with
  //    the body-ratio and the break level.
  // 3) Strict mode: drop events whose opposing-leg first-candle isn't a
  //    swing pivot OR whose bodyRatio < minBody.
  // 4) Return events with absolute candle indices.
}
```

**Performance:** O(n) single pass. Compute is memoized per-frame via the
existing `_installComputeMemo` (no new perf machinery needed).

### 2. Rendering (`_drawIndicators` extension)

For each CISD event:
- **Horizontal break line** from event candle's `x` to event-x + `expiryBars`
  cells (or until invalidated by an opposite-direction close past the line)
  - Bullish: green (default `#22C55E`)
  - Bearish: red (default `#EF4444`)
  - 1px solid by default; thickness honors the indicator's `thickness` field
- **Marker** at event candle (strict mode only):
  - ▲ below candle (offset = 0.5 × ATR(14)) for bullish
  - ▼ above candle for bearish
  - Filled, indicator color

Invalidation rule: a level is removed (line ends) when a candle closes
PAST the line in the opposite direction. E.g., a bullish CISD line at
price L is invalidated when a candle closes < L.

Max lines visible = 10 (oldest pruned first), per EmpArchitect default.

### 3. Schema (`indicator_schema.dart`)

CISD entry in the schema map:

```dart
'cisd': IndicatorSchema(
  kind: 'cisd',
  fields: [
    IndicatorField.enum_('mode',
      label: 'Mode',
      options: ['strict', 'permissive'],
      defaultValue: 'strict',
      description: 'Strict requires swing-pivot + displacement; '
                   'Permissive flags every state change.'),
    IndicatorField.int_('pivotWidth',
      label: 'Pivot width',
      min: 1, max: 10,
      defaultValue: 2,
      description: 'Bars on each side of a swing pivot (strict only).'),
    IndicatorField.double_('minBodyRatio',
      label: 'Min body ratio',
      min: 0.1, max: 0.95, step: 0.05,
      defaultValue: 0.65,
      description: 'Displacement filter: body / total range.'),
    IndicatorField.int_('expiryBars',
      label: 'Level lifetime',
      min: 5, max: 500,
      defaultValue: 50,
      description: 'Bars a CISD line lives before auto-expiring.'),
    IndicatorField.int_('maxLines',
      label: 'Max visible lines',
      min: 1, max: 50,
      defaultValue: 10,
      description: 'Oldest lines are pruned when this is exceeded.'),
    IndicatorField.color('bullColor',
      label: 'Bullish color',
      defaultValue: '#22C55E'),
    IndicatorField.color('bearColor',
      label: 'Bearish color',
      defaultValue: '#EF4444'),
  ],
)
```

If the schema doesn't currently support `enum_` / `color` field kinds, the
implementation adds them (small, localized additions).

### 4. Catalog wiring

**Flutter `_catalog`** (in `chart_engine_top_bar.dart`):
```dart
_IndicatorCatalogEntry('cisd', 'CISD', 'Change in State of Delivery',
    _IndicatorCategory.momentum),
```

**JS `INDICATOR_CATALOG`** (in `topbar.js`):
```js
{ kind: 'cisd', label: 'CISD', fullName: 'Change in State of Delivery',
  category: 'momentum' },
```

**Defaults** (in `chart_engine_store.dart`):
```dart
case 'cisd': return '#22C55E';   // bullish default; bear uses bearColor param
case 'cisd': return 0;           // CISD has no scalar period
```

## Data flow

1. User opens fx → picks "CISD" → JS posts `addIndicatorByKind: {kind: 'cisd'}`
2. Flutter handler creates `IndicatorConfig(kind: 'cisd', period: 0, color: '#22C55E', params: {})`
3. State mirror pushes back to JS via `setActivePaneTopBarState`
4. chart.js's `_drawIndicators` sees a `cisd` indicator → calls `_computeCisd(ind)`
5. Render walks events, emits lines + markers
6. User clicks settings cog → existing `indicatorSettingsRequested` flow opens
   the Flutter settings dialog (schema-driven), edits flow back as
   `updateIndicatorParams` which the existing path already handles

## Edge cases & decisions

| Case | Decision | Rationale |
|---|---|---|
| Doji (open == close, range > 0) | Skip when building delivery legs (no direction) | No source addresses dojis; safest is to skip |
| Range-zero candle (high == low) | Skip entirely | bodyRatio undefined |
| Gap candle at session boundary | Reset delivery leg accumulator | Conservative; avoids cross-session false legs |
| Multi-candle leg open | Use **FIRST candle's open** | LuxAlgo + innercircletrader.net consensus |
| Untriggered CISD level expiry | 50 bars default, configurable | AlgoAlpha exposes "Expiry Bars"; 50 is a sensible mid-range |
| Invalidation | Close past the line in opposite direction | Standard among community scripts |
| Pivot at chart edge (no right-side bars yet) | Hold event back until pivot confirmed (`pivotWidth` bars after) | Avoids repainting; matches all community scripts |
| Permissive mode pivot/displacement | Skipped — every state change emitted | Definition of permissive mode |

## Default parameters (shipping)

| Param | Default | Range | Rationale |
|---|---|---|---|
| mode | `strict` | strict / permissive | Strict is the useful entry signal |
| pivotWidth | 2 | 1–10 | 5-candle fractal; canonical ICT (3) + 1 buffer |
| minBodyRatio | 0.65 | 0.10–0.95 | EmpArchitect / FibAlgo strict default |
| expiryBars | 50 | 5–500 | Mid-range; long enough to remain useful, short enough to declutter |
| maxLines | 10 | 1–50 | EmpArchitect default |
| bullColor | #22C55E | hex | Standard green |
| bearColor | #EF4444 | hex | Standard red |

## What's NOT in scope (deferred)

- **Liquidity-sweep gate** (AlgoAlpha-style "▲/▼ only after a swing was
  swept" filter). Architecturally compatible — would slot in as an additional
  filter step in `_computeCisd`. Left as a follow-up toggle once we see how
  the strict-mode output looks in practice.
- **Alerts/notifications** when CISD fires. The existing chart engine has
  no alert pipeline for indicator events; revisit when alerts are added
  broadly.
- **MTF (multi-timeframe) CISD overlay**. Today's indicators are
  single-timeframe; same applies here.
- **Backtesting / win-rate stats**. Out of chart scope.

## Testing

- Unit-style: nothing planned — the existing chart engine doesn't have a JS
  test harness for compute functions (`aggregator.test.js` is the only test
  file and is bucketing-specific). The CISD compute is small + memoized;
  manual smoke is sufficient.
- Manual smoke on real symbols (NIFTY, NATURALGAS) across 1m / 5m / 1h
  timeframes:
  - Verify lines appear at correct prices (visually check vs. recent legs)
  - Toggle strict ↔ permissive; verify density changes
  - Verify wick-only piercings do NOT trigger
  - Verify markers only render in strict mode
  - Verify invalidation when price closes past a line

## Static gates

- `flutter analyze lib/screens/web/chart_engine` clean
- `node --check web/chart-engine/chart.js` clean

## Files touched

| File | Change |
|---|---|
| `web/chart-engine/chart.js` | Add `_computeCisd`; extend `_drawIndicators` for CISD line + marker rendering |
| `web/chart-engine/topbar.js` | Add `cisd` to `INDICATOR_CATALOG` |
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | Add `cisd` cases to `defaultIndicatorColor` / `defaultIndicatorPeriod` |
| `lib/screens/web/chart_engine/state/indicator_schema.dart` | Add `cisd` schema entry (and color/enum field kinds if missing) |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | Add `cisd` to the legacy `_catalog` (cosmetic — picker is JS now) |
