# Chart Engine — Phase 11 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add 5 more indicator kinds — **BB** + **VWAP** as candle-pane overlays; **MACD** + **STOCH** + **ATR** as stacked sub-panes below the candles. Reuse Phase 8 plumbing; the only data-model change is more `kind` string values.

**Architecture:** All compute + render lives in `chart.js`. Layout logic in `draw()` generalizes Phase 8's single-RSI sub-pane to N stacked sub-panes (one per `rsi`/`macd`/`stoch`/`atr` indicator instance). Settings popup adds 5 chips to the Add menu.

## Project conventions

- **No git commits.**
- **Static gates after every edit:** `flutter analyze lib/screens/web/chart_engine` + `node --check web/chart-engine/chart.js`.
- **Spec reference:** `docs/superpowers/specs/2026-05-25-chart-engine-phase11-design.md`.
- **Reuse:** Phase 8's `IndicatorConfig` + `_indicators` array + `_pushedIndicatorsJson` cache + Settings popup `_IndicatorsSection` widget.

## File map

| Path | What |
|---|---|
| `web/chart-engine/chart.js` | New compute helpers `_computeBB`, `_computeVWAP`, `_computeMACD`, `_computeStoch`, `_computeATR`; `_drawIndicators` extended for `bb` + `vwap` overlays; `_drawRsiSubPane` generalised to `_drawSubPanes(subPlots)` with per-kind drawers (`_drawRsiInPane`, `_drawMacdInPane`, `_drawStochInPane`, `_drawAtrInPane`); layout in `draw()` handles N sub-panes. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | `_IndicatorsSection` Add menu shows 8 kinds (2 rows of 4); `_defaultColor` + `_defaultPeriod` extended. |

No new files. No `chart-engine.js` / `chart_engine_store.dart` / bridge changes.

## Task ordering

1. **Group A — JS compute helpers.**
2. **Group B — Overlay renderers (BB + VWAP).**
3. **Group C — Sub-pane layout + per-kind drawers.**
4. **Group D — Settings popup Add menu.**
5. **Group E — Static gates.**

---

# Group A — JS compute helpers

### Task A1: Add 5 compute methods to chart.js

**Files:** `web/chart-engine/chart.js`

Near the existing `_computeSMA` / `_computeEMA` / `_computeRSI`:

```javascript
  // ---------- Phase 11 ----------

  _computeBB(period) {
    const n = this.candles.length;
    const mid = new Array(n).fill(null);
    const upper = new Array(n).fill(null);
    const lower = new Array(n).fill(null);
    if (period <= 1 || n < period) return { mid, upper, lower };
    const STDDEV = 2;
    let sum = 0;
    let sumSq = 0;
    for (let i = 0; i < n; i++) {
      const c = this.candles[i].c;
      sum += c;
      sumSq += c * c;
      if (i >= period) {
        const out = this.candles[i - period].c;
        sum -= out;
        sumSq -= out * out;
      }
      if (i >= period - 1) {
        const m = sum / period;
        const variance = Math.max(0, sumSq / period - m * m);
        const sd = Math.sqrt(variance);
        mid[i] = m;
        upper[i] = m + STDDEV * sd;
        lower[i] = m - STDDEV * sd;
      }
    }
    return { mid, upper, lower };
  }

  _computeVWAP() {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (n === 0) return out;
    const DAY_SEC = 86400;
    let prevDay = null;
    let cumPV = 0;
    let cumV = 0;
    for (let i = 0; i < n; i++) {
      const c = this.candles[i];
      const day = Math.floor(c.ts / DAY_SEC);
      if (prevDay !== null && day !== prevDay) {
        cumPV = 0;
        cumV = 0;
      }
      prevDay = day;
      const typical = (c.h + c.l + c.c) / 3;
      cumPV += typical * c.v;
      cumV += c.v;
      out[i] = cumV > 0 ? cumPV / cumV : null;
    }
    return out;
  }

  _computeMACD() {
    const FAST = 12, SLOW = 26, SIGNAL = 9;
    const fast = this._computeEMA(FAST);
    const slow = this._computeEMA(SLOW);
    const n = this.candles.length;
    const macd = new Array(n).fill(null);
    for (let i = 0; i < n; i++) {
      if (fast[i] != null && slow[i] != null) macd[i] = fast[i] - slow[i];
    }
    // Signal = EMA of macd line (skipping the leading nulls).
    const signal = new Array(n).fill(null);
    let started = false;
    let ema = null;
    const k = 2 / (SIGNAL + 1);
    let countSinceStart = 0;
    for (let i = 0; i < n; i++) {
      const v = macd[i];
      if (v == null) continue;
      if (!started) { ema = v; started = true; countSinceStart = 1; }
      else { ema = v * k + ema * (1 - k); countSinceStart++; }
      if (countSinceStart >= SIGNAL) signal[i] = ema;
    }
    const hist = new Array(n).fill(null);
    for (let i = 0; i < n; i++) {
      if (macd[i] != null && signal[i] != null) hist[i] = macd[i] - signal[i];
    }
    return { macd, signal, hist };
  }

  _computeStoch(period) {
    const SMOOTH = 3;
    const n = this.candles.length;
    const k = new Array(n).fill(null);
    if (period <= 0 || n < period) return { k, d: new Array(n).fill(null) };
    for (let i = period - 1; i < n; i++) {
      let lo = Infinity, hi = -Infinity;
      for (let j = i - period + 1; j <= i; j++) {
        if (this.candles[j].l < lo) lo = this.candles[j].l;
        if (this.candles[j].h > hi) hi = this.candles[j].h;
      }
      const range = hi - lo;
      k[i] = range > 0 ? ((this.candles[i].c - lo) / range) * 100 : 50;
    }
    // %D = SMA of %K over SMOOTH bars (skip nulls).
    const d = new Array(n).fill(null);
    for (let i = 0; i < n; i++) {
      if (i < period - 1 + SMOOTH - 1) continue;
      let sum = 0;
      let count = 0;
      for (let j = i - SMOOTH + 1; j <= i; j++) {
        if (k[j] != null) { sum += k[j]; count++; }
      }
      if (count === SMOOTH) d[i] = sum / SMOOTH;
    }
    return { k, d };
  }

  _computeATR(period) {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (period <= 0 || n < period + 1) return out;
    // True range per bar.
    const tr = new Array(n).fill(0);
    tr[0] = this.candles[0].h - this.candles[0].l;
    for (let i = 1; i < n; i++) {
      const c = this.candles[i];
      const pc = this.candles[i - 1].c;
      tr[i] = Math.max(c.h - c.l, Math.abs(c.h - pc), Math.abs(c.l - pc));
    }
    // Wilder smoothing — first ATR = average of first `period` TRs.
    let sum = 0;
    for (let i = 0; i < period; i++) sum += tr[i];
    out[period - 1] = sum / period;
    for (let i = period; i < n; i++) {
      out[i] = (out[i - 1] * (period - 1) + tr[i]) / period;
    }
    return out;
  }
```

Static check: `node --check web/chart-engine/chart.js`.

---

# Group B — Overlay renderers (BB + VWAP)

### Task B1: Extend `_drawIndicators` for `bb` and `vwap`

**Files:** `web/chart-engine/chart.js`

Inside `_drawIndicators` (after the existing `sma`/`ema` branch), add:

```javascript
      if (ind.kind === 'bb') {
        const bands = this._computeBB(ind.period);
        const drawSeries = (values, lineW) => {
          ctx.strokeStyle = ind.color || '#8B5CF6';
          ctx.lineWidth = lineW;
          ctx.beginPath();
          let started = false;
          for (let i = 0; i < visible.length; i++) {
            const absIdx = firstAbs + i;
            const v = values[absIdx];
            if (v == null) continue;
            const x = this._candleXCenter(absIdx, plot);
            const y = priceToY(v);
            if (!started) { ctx.moveTo(x, y); started = true; }
            else ctx.lineTo(x, y);
          }
          ctx.stroke();
        };
        drawSeries(bands.upper, 1);
        drawSeries(bands.mid, 1.5);
        drawSeries(bands.lower, 1);
        continue;
      }
      if (ind.kind === 'vwap') {
        const values = this._computeVWAP();
        ctx.strokeStyle = ind.color || '#06B6D4';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        let started = false;
        for (let i = 0; i < visible.length; i++) {
          const absIdx = firstAbs + i;
          const v = values[absIdx];
          if (v == null) continue;
          const x = this._candleXCenter(absIdx, plot);
          const y = priceToY(v);
          if (!started) { ctx.moveTo(x, y); started = true; }
          else ctx.lineTo(x, y);
        }
        ctx.stroke();
        // Label chip near right edge.
        const last = values[firstAbs + visible.length - 1];
        if (last != null) {
          ctx.font = '600 10px Geist, sans-serif';
          ctx.textBaseline = 'middle';
          ctx.textAlign = 'left';
          const text = 'VWAP';
          const tw = ctx.measureText(text).width + 8;
          const lx = this._candleXCenter(firstAbs + visible.length - 1, plot);
          const ly = priceToY(last);
          ctx.fillStyle = ind.color || '#06B6D4';
          this._roundedRect(lx + 4, ly - 8, tw, 16, 3);
          ctx.fill();
          ctx.fillStyle = '#FFFFFF';
          ctx.fillText(text, lx + 8, ly);
        }
        continue;
      }
      // Sub-pane kinds are handled in _drawSubPanes — skip here.
      if (ind.kind === 'rsi' || ind.kind === 'macd' ||
          ind.kind === 'stoch' || ind.kind === 'atr') continue;
```

Make sure `firstAbs` + `visible` are computed once at the top of `_drawIndicators` (existing code already does this for sma/ema). If `visible.length === 0`, early-return as the existing code does.

Static check.

---

# Group C — Sub-pane layout + per-kind drawers

### Task C1: Generalize `_drawRsiSubPane` → `_drawSubPanes` + 4 per-kind drawers

**Files:** `web/chart-engine/chart.js`

- [ ] **Step 1: Update layout block in `draw()`**

Find the existing block:

```javascript
    const hasRsi = this._indicators.some((i) => i.kind === 'rsi');
    const rsiH = hasRsi ? Math.round(innerH * 0.18) : 0;
    const candleH = innerH - volH - rsiH;
```

Replace with:

```javascript
    const SUB_KINDS = new Set(['rsi', 'macd', 'stoch', 'atr']);
    const subPaneIndicators =
        this._indicators.filter((i) => SUB_KINDS.has(i.kind));
    const subPaneCount = subPaneIndicators.length;
    let subPaneTotalH = 0;
    if (subPaneCount > 0) {
      const perPane = Math.max(60, Math.round(innerH * 0.18));
      subPaneTotalH = Math.min(perPane * subPaneCount,
          Math.round(innerH * 0.5));
    }
    const candleH = innerH - volH - subPaneTotalH;
```

Find the existing block:

```javascript
    const rsiTop = (volPlot ? volPlot.bottom : plot.bottom) + 1;
    const rsiPlot = hasRsi ? { ... } : null;
    ...
    if (rsiPlot) this._drawRsiSubPane(rsiPlot);
```

Replace with:

```javascript
    let subCursorY = (volPlot ? volPlot.bottom : plot.bottom) + 1;
    const subPaneH = subPaneCount > 0
        ? Math.floor(subPaneTotalH / subPaneCount)
        : 0;
    const subPlots = subPaneIndicators.map((ind) => {
      const r = {
        kind: ind.kind, period: ind.period, color: ind.color, id: ind.id,
        left: plot.left, top: subCursorY,
        right: plot.right, bottom: subCursorY + subPaneH,
        width: plot.right - plot.left, height: subPaneH,
      };
      subCursorY += subPaneH;
      return r;
    });
```

Find the call site near where `_drawRsiSubPane(rsiPlot)` was. Replace with:

```javascript
    if (subPlots.length > 0) this._drawSubPanes(subPlots);
```

- [ ] **Step 2: Replace `_drawRsiSubPane` with `_drawSubPanes` + per-kind drawers**

Delete the body of the existing `_drawRsiSubPane` method. Replace its declaration with:

```javascript
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

  _drawRsiInPane(sp) {
    const ctx = this.ctx;
    if (this.candles.length === 0) return;
    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(sp.left, sp.top, sp.width, sp.height);
    const yFor = (v) => sp.top + (100 - v) * sp.height / 100;
    ctx.strokeStyle = this.palette.axisText;
    ctx.lineWidth = 1;
    ctx.setLineDash([3, 3]);
    for (const lvl of [30, 70]) {
      const y = yFor(lvl);
      ctx.beginPath();
      ctx.moveTo(sp.left, y);
      ctx.lineTo(sp.right, y);
      ctx.stroke();
    }
    ctx.setLineDash([]);
    ctx.strokeStyle = this.palette.gridSoft;
    const ymid = yFor(50);
    ctx.beginPath();
    ctx.moveTo(sp.left, ymid);
    ctx.lineTo(sp.right, ymid);
    ctx.stroke();
    const visible = this._visibleCandles();
    if (visible.length === 0) { ctx.restore(); return; }
    const firstAbs = this.candles.indexOf(visible[0]);
    const values = this._computeRSI(sp.period);
    ctx.strokeStyle = sp.color || '#8B5CF6';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null) continue;
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(v);
      if (!started) { ctx.moveTo(x, y); started = true; }
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
    ctx.font = '600 10px Geist, sans-serif';
    ctx.fillStyle = sp.color || '#8B5CF6';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(`RSI ${sp.period}`, sp.left + 4, sp.top + 8);
    ctx.restore();
  }

  _drawMacdInPane(sp) {
    const ctx = this.ctx;
    if (this.candles.length === 0) return;
    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(sp.left, sp.top, sp.width, sp.height);
    const { macd, signal, hist } = this._computeMACD();
    const visible = this._visibleCandles();
    if (visible.length === 0) { ctx.restore(); return; }
    const firstAbs = this.candles.indexOf(visible[0]);
    // Range from visible macd / signal / hist
    let lo = Infinity, hi = -Infinity;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      for (const arr of [macd, signal, hist]) {
        const v = arr[absIdx];
        if (v == null) continue;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    }
    if (!Number.isFinite(lo) || !Number.isFinite(hi)) { ctx.restore(); return; }
    const pad = (hi - lo) * 0.1 || 1;
    lo -= pad; hi += pad;
    const yFor = (v) => sp.top + (hi - v) * sp.height / (hi - lo);

    // Zero line dashed.
    if (lo < 0 && hi > 0) {
      ctx.strokeStyle = this.palette.axisText;
      ctx.lineWidth = 1;
      ctx.setLineDash([3, 3]);
      ctx.beginPath();
      const y0 = yFor(0);
      ctx.moveTo(sp.left, y0);
      ctx.lineTo(sp.right, y0);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // Histogram bars.
    const barW = Math.max(1, this.view.cellW - 2);
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = hist[absIdx];
      if (v == null) continue;
      const x = this._candleXCenter(absIdx, sp);
      const y0 = yFor(0);
      const yv = yFor(v);
      ctx.fillStyle = v >= 0
          ? 'rgba(16,185,129,0.6)' : 'rgba(239,68,68,0.6)';
      ctx.fillRect(x - barW / 2, Math.min(y0, yv),
          barW, Math.abs(yv - y0));
    }

    // MACD line + signal line.
    const drawLine = (arr, color, lw) => {
      ctx.strokeStyle = color;
      ctx.lineWidth = lw;
      ctx.beginPath();
      let started = false;
      for (let i = 0; i < visible.length; i++) {
        const absIdx = firstAbs + i;
        const v = arr[absIdx];
        if (v == null) continue;
        const x = this._candleXCenter(absIdx, sp);
        const y = yFor(v);
        if (!started) { ctx.moveTo(x, y); started = true; }
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
    };
    drawLine(macd, sp.color || '#3B82F6', 1.4);
    drawLine(signal, '#F59E0B', 1.4);

    ctx.font = '600 10px Geist, sans-serif';
    ctx.fillStyle = sp.color || '#3B82F6';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText('MACD 12/26/9', sp.left + 4, sp.top + 8);
    ctx.restore();
  }

  _drawStochInPane(sp) {
    const ctx = this.ctx;
    if (this.candles.length === 0) return;
    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(sp.left, sp.top, sp.width, sp.height);
    const yFor = (v) => sp.top + (100 - v) * sp.height / 100;
    ctx.strokeStyle = this.palette.axisText;
    ctx.lineWidth = 1;
    ctx.setLineDash([3, 3]);
    for (const lvl of [20, 80]) {
      const y = yFor(lvl);
      ctx.beginPath();
      ctx.moveTo(sp.left, y);
      ctx.lineTo(sp.right, y);
      ctx.stroke();
    }
    ctx.setLineDash([]);
    const { k, d } = this._computeStoch(sp.period);
    const visible = this._visibleCandles();
    if (visible.length === 0) { ctx.restore(); return; }
    const firstAbs = this.candles.indexOf(visible[0]);
    const drawLine = (arr, color) => {
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.4;
      ctx.beginPath();
      let started = false;
      for (let i = 0; i < visible.length; i++) {
        const absIdx = firstAbs + i;
        const v = arr[absIdx];
        if (v == null) continue;
        const x = this._candleXCenter(absIdx, sp);
        const y = yFor(v);
        if (!started) { ctx.moveTo(x, y); started = true; }
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
    };
    drawLine(k, sp.color || '#8B5CF6');
    drawLine(d, '#F59E0B');
    ctx.font = '600 10px Geist, sans-serif';
    ctx.fillStyle = sp.color || '#8B5CF6';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(`STOCH ${sp.period}/3`, sp.left + 4, sp.top + 8);
    ctx.restore();
  }

  _drawAtrInPane(sp) {
    const ctx = this.ctx;
    if (this.candles.length === 0) return;
    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(sp.left, sp.top, sp.width, sp.height);
    const values = this._computeATR(sp.period);
    const visible = this._visibleCandles();
    if (visible.length === 0) { ctx.restore(); return; }
    const firstAbs = this.candles.indexOf(visible[0]);
    let lo = Infinity, hi = -Infinity;
    for (let i = 0; i < visible.length; i++) {
      const v = values[firstAbs + i];
      if (v == null) continue;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if (!Number.isFinite(lo) || !Number.isFinite(hi)) { ctx.restore(); return; }
    if (hi === lo) { hi += 0.5; lo -= 0.5; }
    const yFor = (v) => sp.top + (hi - v) * sp.height / (hi - lo);
    ctx.strokeStyle = sp.color || '#10B981';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null) continue;
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(v);
      if (!started) { ctx.moveTo(x, y); started = true; }
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
    ctx.font = '600 10px Geist, sans-serif';
    ctx.fillStyle = sp.color || '#10B981';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(`ATR ${sp.period}`, sp.left + 4, sp.top + 8);
    ctx.restore();
  }
```

Static check: `node --check web/chart-engine/chart.js`.

---

# Group D — Settings popup Add menu

### Task D1: Add 5 new kinds to `_IndicatorsSection`

**Files:** `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`

In `_IndicatorsSectionState`:

- [ ] **Step 1: Extend `_defaultColor` switch**

```dart
  String _defaultColor(String kind) {
    switch (kind) {
      case 'sma':   return '#3B82F6';
      case 'ema':   return '#F59E0B';
      case 'rsi':   return '#8B5CF6';
      case 'bb':    return '#8B5CF6';
      case 'vwap':  return '#06B6D4';
      case 'macd':  return '#3B82F6';
      case 'stoch': return '#8B5CF6';
      case 'atr':   return '#10B981';
    }
    return '#3B82F6';
  }
```

- [ ] **Step 2: Extend `_defaultPeriod`**

```dart
  int _defaultPeriod(String kind) {
    switch (kind) {
      case 'rsi':   return 14;
      case 'macd':  return 12;   // primary (fast); slow=26 hardcoded
      case 'stoch': return 14;
      case 'atr':   return 14;
      case 'bb':    return 20;
      case 'vwap':  return 0;    // unused
      default:      return 20;   // sma / ema
    }
  }
```

- [ ] **Step 3: Update Add menu chips**

Find the existing Wrap of menu kinds. Replace:

```dart
for (final k in ['sma', 'ema', 'rsi'])
```

with:

```dart
for (final k in const ['sma', 'ema', 'bb', 'vwap', 'rsi', 'macd', 'stoch', 'atr'])
```

Static check: `flutter analyze lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`.

---

# Group E — Static gates + smoke

- [ ] `flutter analyze lib/screens/web/chart_engine` → No issues
- [ ] `node --check web/chart-engine/chart.js web/chart-engine/chart-engine.js web/chart-engine/aggregator.js web/chart-engine/theme.js` → no output
- [ ] `node web/chart-engine/aggregator.test.js` → 15 passed

Then spec §7's 11-step smoke.

---

## Notes

- **Layout invariant** — when computing sub-pane heights, ensure `candleH ≥ 0` and reasonable. If `subPaneTotalH > innerH`, candles get squashed but everything still renders.
- **VWAP day boundary** — uses UTC day (`floor(ts / 86400)`). For IST sessions this is one day off from local but consistent. Acceptable for Phase 11.
- **MACD signal warm-up** — first ~35 bars (slow + signal) won't have values; expected.
- **Pause and ask** only if a referenced method differs from the existing pattern.
