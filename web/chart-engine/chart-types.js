'use strict';

// ---------------------------------------------------------------------------
// chart-types.js — series & rebinned renderers — split out of chart.js. Methods are authored verbatim inside a
// throwaway mixin class (keeps class-method syntax, no edits) and copied onto
// Chart.prototype at load. Loaded AFTER chart.js. Behaviour identical.
// ---------------------------------------------------------------------------
class _ChartTypesMixin {
  // ── Phase 16 draw helpers ────────────────────────────────────────────────

  _drawCandlesCore(visible, firstVisibleAbs, plot, priceToY, opts) {
    const hollow = !!opts.hollow;
    const heikinAshi = !!opts.heikinAshi;
    let haOpenPrev = null;
    let haClosePrev = null;
    // Seed HA from the bar BEFORE the visible window so the visible run looks
    // continuous when the user pans. When the window starts at history index
    // 0 there is no prior bar — leave prev null so the loop's own fallback
    // (`(c.o + c.c) / 2`) fires for the very first bar.
    if (heikinAshi && firstVisibleAbs > 0) {
      const seedIdx = firstVisibleAbs - 1;
      if (seedIdx < this.candles.length) {
        const s = this.candles[seedIdx];
        haOpenPrev = (s.o + s.c) / 2;
        haClosePrev = (s.o + s.h + s.l + s.c) / 4;
      }
    }
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      let o = c.o, h = c.h, l = c.l, cl = c.c;
      if (heikinAshi) {
        const haClose = (c.o + c.h + c.l + c.c) / 4;
        const haOpen  = haOpenPrev == null ? (c.o + c.c) / 2 : (haOpenPrev + haClosePrev) / 2;
        const haHigh  = Math.max(c.h, haOpen, haClose);
        const haLow   = Math.min(c.l, haOpen, haClose);
        o = haOpen; h = haHigh; l = haLow; cl = haClose;
        haOpenPrev = haOpen; haClosePrev = haClose;
      }
      const absoluteIdx = firstVisibleAbs + i;
      const xCenter = this._candleXCenter(absoluteIdx, plot);
      const isBull = cl >= o;
      const color = isBull ? this.palette.bull : this.palette.bear;
      // Wick.
      this.ctx.fillStyle = color;
      this.ctx.fillRect(Math.round(xCenter), priceToY(h), 1, priceToY(l) - priceToY(h));
      // Body.
      const bodyTop = Math.min(priceToY(o), priceToY(cl));
      const bodyBot = Math.max(priceToY(o), priceToY(cl));
      const bodyW = Math.max(1, this.view.cellW - 2);
      const bodyH = Math.max(1, bodyBot - bodyTop);
      if (hollow && isBull) {
        this.ctx.strokeStyle = color;
        this.ctx.lineWidth = 1.25;
        this.ctx.strokeRect(
            Math.round(xCenter - bodyW / 2) + 0.5,
            bodyTop + 0.5, bodyW - 1, Math.max(1, bodyH - 1));
      } else {
        this.ctx.fillStyle = color;
        this.ctx.fillRect(Math.round(xCenter - bodyW / 2), bodyTop, bodyW, bodyH);
      }
    }
    // Persist HA tail so the next draw() picks up where we left off (only
    // matters when style stays HA and the user nudges via tick).
    if (heikinAshi) this._haPrev = { haOpen: haOpenPrev, haClose: haClosePrev };
  }

  _drawBarsOHLC(visible, firstVisibleAbs, plot, priceToY) {
    const tickLen = Math.max(2, Math.floor(this.view.cellW / 2));
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const xCenter = Math.round(this._candleXCenter(firstVisibleAbs + i, plot));
      const isBull = c.c >= c.o;
      const color = isBull ? this.palette.bull : this.palette.bear;
      this.ctx.strokeStyle = color;
      this.ctx.lineWidth = 1.2;
      this.ctx.beginPath();
      // Vertical H..L.
      this.ctx.moveTo(xCenter + 0.5, priceToY(c.h));
      this.ctx.lineTo(xCenter + 0.5, priceToY(c.l));
      // Open tick LEFT.
      const yo = priceToY(c.o);
      this.ctx.moveTo(xCenter - tickLen + 0.5, yo);
      this.ctx.lineTo(xCenter + 0.5, yo);
      // Close tick RIGHT.
      const yc = priceToY(c.c);
      this.ctx.moveTo(xCenter + 0.5, yc);
      this.ctx.lineTo(xCenter + tickLen + 0.5, yc);
      this.ctx.stroke();
    }
  }

  _drawLineSeries(visible, firstVisibleAbs, plot, priceToY) {
    if (visible.length === 0) return;
    this.ctx.strokeStyle = this.palette.accent || this.palette.bull;
    this.ctx.lineWidth = 1.5;
    this.ctx.beginPath();
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const x = this._candleXCenter(firstVisibleAbs + i, plot);
      const y = priceToY(c.c);
      if (i === 0) this.ctx.moveTo(x, y);
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
  }

  _drawAreaSeries(visible, firstVisibleAbs, plot, priceToY) {
    if (visible.length === 0) return;
    const stroke = this.palette.accent || this.palette.bull;
    const xs = new Array(visible.length);
    const ys = new Array(visible.length);
    for (let i = 0; i < visible.length; i++) {
      xs[i] = this._candleXCenter(firstVisibleAbs + i, plot);
      ys[i] = priceToY(visible[i].c);
    }
    // Fill polygon.
    const grad = this.ctx.createLinearGradient(0, plot.top, 0, plot.bottom);
    grad.addColorStop(0, this._withAlpha(stroke, 0.35));
    grad.addColorStop(1, this._withAlpha(stroke, 0.02));
    this.ctx.fillStyle = grad;
    this.ctx.beginPath();
    this.ctx.moveTo(xs[0], plot.bottom);
    for (let i = 0; i < xs.length; i++) this.ctx.lineTo(xs[i], ys[i]);
    this.ctx.lineTo(xs[xs.length - 1], plot.bottom);
    this.ctx.closePath();
    this.ctx.fill();
    // Stroke on top.
    this.ctx.strokeStyle = stroke;
    this.ctx.lineWidth = 1.5;
    this.ctx.beginPath();
    for (let i = 0; i < xs.length; i++) {
      if (i === 0) this.ctx.moveTo(xs[i], ys[i]);
      else this.ctx.lineTo(xs[i], ys[i]);
    }
    this.ctx.stroke();
  }

  _withAlpha(hexOrRgba, a) {
    // Accept #RGB, #RRGGBB, or rgba(...) and return rgba with alpha override.
    const s = String(hexOrRgba || '').trim();
    if (s.startsWith('#')) {
      let r, g, b;
      if (s.length === 4) {
        r = parseInt(s[1] + s[1], 16);
        g = parseInt(s[2] + s[2], 16);
        b = parseInt(s[3] + s[3], 16);
      } else {
        r = parseInt(s.slice(1, 3), 16);
        g = parseInt(s.slice(3, 5), 16);
        b = parseInt(s.slice(5, 7), 16);
      }
      return `rgba(${r},${g},${b},${a})`;
    }
    const m = s.match(/^rgba?\(([^,]+),([^,]+),([^,]+)(?:,[^)]+)?\)$/);
    if (m) return `rgba(${m[1].trim()},${m[2].trim()},${m[3].trim()},${a})`;
    // Fallback — return as-is.
    return s;
  }

  _drawRenko(plot, priceToY) {
    const bricks = this._renkoBricks;
    if (!bricks || bricks.length === 0) return;
    // After Step 0, view.firstVisible / view.lastVisible are bounded by
    // _seriesLength() — i.e. the brick count when on Renko. Clamp anyway as
    // a belt-and-braces guard.
    const total = bricks.length;
    const firstVisible = Math.max(0,
        Math.floor(this.view.firstVisible != null ? this.view.firstVisible : 0));
    const lastVisible = Math.min(total - 1,
        Math.ceil(this.view.lastVisible != null ? this.view.lastVisible : total - 1));
    if (firstVisible > lastVisible) return;
    const bodyW = Math.max(1, this.view.cellW - 2);
    for (let i = firstVisible; i <= lastVisible; i++) {
      const b = bricks[i];
      const xCenter = this._candleXCenter(i, plot); // brick idx → X
      const color = b.direction === 'up' ? this.palette.bull : this.palette.bear;
      this.ctx.fillStyle = color;
      const yTop = Math.min(priceToY(b.openPrice), priceToY(b.closePrice));
      const yBot = Math.max(priceToY(b.openPrice), priceToY(b.closePrice));
      const h = Math.max(1, yBot - yTop);
      this.ctx.fillRect(
          Math.round(xCenter - bodyW / 2), yTop, bodyW, h);
    }
  }

  _seriesLength() {
    if (this.candleStyle === 'renko') return this._renkoBricks.length;
    if (this._isRebinnedStyle(this.candleStyle)
        && this._rebinnedStyle === this.candleStyle
        && this._rebinned.length > 0) {
      return this._rebinned.length;
    }
    return this.candles.length;
  }

  _isRebinnedStyle(style) {
    return style === 'linebreak' || style === 'kagi'
        || style === 'range' || style === 'pnf';
  }

  // ── Phase 16 F1 — Renko transform pipeline ───────────────────────────────

  _computeRenkoBrickSize() {
    const bars = this.candles;
    const ti = (this.scrip && this.scrip.ti) || 0.05;
    if (!bars || bars.length === 0) return ti;
    // Standard ATR(14). True Range = max(H-L, |H-prevC|, |L-prevC|).
    const period = 14;
    const n = Math.min(bars.length, period * 4); // window the ATR
    if (bars.length < period) {
      // Fallback: range / count.
      let hi = -Infinity, lo = Infinity;
      for (const c of bars) { if (c.h > hi) hi = c.h; if (c.l < lo) lo = c.l; }
      const r = (hi - lo) / Math.max(1, bars.length);
      return this._snapToTick(Math.max(ti, r), ti);
    }
    let trSum = 0; let trCount = 0;
    const start = bars.length - n;
    for (let i = Math.max(1, start); i < bars.length; i++) {
      const c = bars[i]; const p = bars[i - 1];
      const tr = Math.max(c.h - c.l, Math.abs(c.h - p.c), Math.abs(c.l - p.c));
      trSum += tr; trCount += 1;
    }
    const atr = trCount > 0 ? trSum / trCount : ti;
    return this._snapToTick(Math.max(ti, atr), ti);
  }

  _snapToTick(value, tick) {
    if (!isFinite(tick) || tick <= 0) return value;
    return Math.max(tick, Math.round(value / tick) * tick);
  }

  _rebuildRenko() {
    this._renkoBricks = [];
    const bars = this.candles;
    if (!bars || bars.length === 0) {
      this._renkoBrickSize = 0;
      return;
    }
    const size = this._computeRenkoBrickSize();
    this._renkoBrickSize = size;
    const first = bars[0];
    let last = {
      idx: 0,
      openPrice: first.c,
      closePrice: first.c,
      direction: 'up',
      sourceBarTime: first.ts,
      sourceBarIndex: 0,
    };
    this._renkoBricks.push(last);
    for (let i = 1; i < bars.length; i++) {
      last = this._appendBricksForPrice(bars[i].c, last, size, bars[i].ts, i);
    }
  }

  // Returns the new "last brick" after appending zero or more bricks driven
  // by `price`. Implements the classic Renko reversal rule (need 2*size in
  // the opposite direction to reverse).
  _appendBricksForPrice(price, last, size, sourceBarTime, sourceBarIndex) {
    if (!isFinite(price) || size <= 0) return last;
    let cur = last;
    while (true) {
      if (cur.direction === 'up') {
        if (price >= cur.closePrice + size) {
          const next = {
            idx: cur.idx + 1,
            openPrice: cur.closePrice,
            closePrice: cur.closePrice + size,
            direction: 'up',
            sourceBarTime, sourceBarIndex,
          };
          this._renkoBricks.push(next); cur = next; continue;
        }
        if (price <= cur.closePrice - 2 * size) {
          const next = {
            idx: cur.idx + 1,
            openPrice: cur.closePrice - size,
            closePrice: cur.closePrice - 2 * size,
            direction: 'down',
            sourceBarTime, sourceBarIndex,
          };
          this._renkoBricks.push(next); cur = next; continue;
        }
        break;
      } else { // 'down'
        if (price <= cur.closePrice - size) {
          const next = {
            idx: cur.idx + 1,
            openPrice: cur.closePrice,
            closePrice: cur.closePrice - size,
            direction: 'down',
            sourceBarTime, sourceBarIndex,
          };
          this._renkoBricks.push(next); cur = next; continue;
        }
        if (price >= cur.closePrice + 2 * size) {
          const next = {
            idx: cur.idx + 1,
            openPrice: cur.closePrice + size,
            closePrice: cur.closePrice + 2 * size,
            direction: 'up',
            sourceBarTime, sourceBarIndex,
          };
          this._renkoBricks.push(next); cur = next; continue;
        }
        break;
      }
    }
    return cur;
  }

  _updateRenkoFromTick(price) {
    if (this.candleStyle !== 'renko') return;
    if (!this._renkoBricks.length || this._renkoBrickSize <= 0) return;
    const last = this._renkoBricks[this._renkoBricks.length - 1];
    const newLast = this._appendBricksForPrice(
        price, last, this._renkoBrickSize,
        Math.floor(Date.now() / 1000),
        this.candles.length - 1);
    if (newLast !== last) this.scheduleRedraw();
  }

  // ── Phase 26 — additional chart styles ────────────────────────────────────

  // 1) Baseline — area split at a baseline (first visible close). Green
  //    fill+line above the baseline, red fill+line below it.
  _drawBaseline(visible, firstVisibleAbs, plot, priceToY) {
    if (visible.length === 0) return;
    const baseline = visible[0].c;
    const baseY = priceToY(baseline);
    const up = this.palette.bull;
    const down = this.palette.bear;
    const xs = new Array(visible.length);
    const ys = new Array(visible.length);
    for (let i = 0; i < visible.length; i++) {
      xs[i] = this._candleXCenter(firstVisibleAbs + i, plot);
      ys[i] = priceToY(visible[i].c);
    }
    // Build the close polyline once.
    const tracePath = () => {
      this.ctx.beginPath();
      for (let i = 0; i < xs.length; i++) {
        if (i === 0) this.ctx.moveTo(xs[i], ys[i]);
        else this.ctx.lineTo(xs[i], ys[i]);
      }
    };
    // Fill ABOVE baseline (green), clipped to the region above baseY.
    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.rect(plot.left, plot.top, plot.right - plot.left, baseY - plot.top);
    this.ctx.clip();
    this.ctx.fillStyle = this._withAlpha(up, 0.22);
    this.ctx.beginPath();
    this.ctx.moveTo(xs[0], baseY);
    for (let i = 0; i < xs.length; i++) this.ctx.lineTo(xs[i], ys[i]);
    this.ctx.lineTo(xs[xs.length - 1], baseY);
    this.ctx.closePath();
    this.ctx.fill();
    this.ctx.restore();
    // Fill BELOW baseline (red).
    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.rect(plot.left, baseY, plot.right - plot.left, plot.bottom - baseY);
    this.ctx.clip();
    this.ctx.fillStyle = this._withAlpha(down, 0.22);
    this.ctx.beginPath();
    this.ctx.moveTo(xs[0], baseY);
    for (let i = 0; i < xs.length; i++) this.ctx.lineTo(xs[i], ys[i]);
    this.ctx.lineTo(xs[xs.length - 1], baseY);
    this.ctx.closePath();
    this.ctx.fill();
    this.ctx.restore();
    // Stroke the line in two colours by clipping above/below the baseline.
    this.ctx.lineWidth = 1.5;
    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.rect(plot.left, plot.top, plot.right - plot.left, baseY - plot.top);
    this.ctx.clip();
    this.ctx.strokeStyle = up; tracePath(); this.ctx.stroke();
    this.ctx.restore();
    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.rect(plot.left, baseY, plot.right - plot.left, plot.bottom - baseY);
    this.ctx.clip();
    this.ctx.strokeStyle = down; tracePath(); this.ctx.stroke();
    this.ctx.restore();
    // Baseline reference line.
    this.ctx.strokeStyle = this.palette.gridSoft;
    this.ctx.lineWidth = 1;
    this.ctx.setLineDash([3, 3]);
    this.ctx.beginPath();
    this.ctx.moveTo(plot.left, baseY); this.ctx.lineTo(plot.right, baseY);
    this.ctx.stroke();
    this.ctx.setLineDash([]);
  }

  // 2) Step line — close drawn as horizontal steps (hold then jump).
  _drawStepLine(visible, firstVisibleAbs, plot, priceToY) {
    if (visible.length === 0) return;
    this.ctx.strokeStyle = this.palette.accent || this.palette.bull;
    this.ctx.lineWidth = 1.5;
    this.ctx.beginPath();
    let prevY = null;
    for (let i = 0; i < visible.length; i++) {
      const x = this._candleXCenter(firstVisibleAbs + i, plot);
      const y = priceToY(visible[i].c);
      if (i === 0) {
        this.ctx.moveTo(x, y);
      } else {
        // Horizontal hold from prev x to current x at the prev level, then
        // a vertical jump to the new level.
        this.ctx.lineTo(x, prevY);
        this.ctx.lineTo(x, y);
      }
      prevY = y;
    }
    this.ctx.stroke();
  }

  // 3) Columns — thin vertical bars baseline→close, coloured up/down vs the
  //    previous close. Baseline is the lowest visible close so bars read as
  //    a column histogram of the close series.
  _drawColumns(visible, firstVisibleAbs, plot, priceToY) {
    if (visible.length === 0) return;
    let minC = Infinity;
    for (const c of visible) if (c.c < minC) minC = c.c;
    const baseY = priceToY(minC);
    const bodyW = Math.max(1, Math.min(this.view.cellW - 2, 6));
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const prevC = i > 0 ? visible[i - 1].c
          : (firstVisibleAbs > 0 ? this.candles[firstVisibleAbs - 1].c : c.c);
      const isUp = c.c >= prevC;
      this.ctx.fillStyle = isUp ? this.palette.bull : this.palette.bear;
      const x = this._candleXCenter(firstVisibleAbs + i, plot);
      const yTop = priceToY(c.c);
      const h = Math.max(1, baseY - yTop);
      this.ctx.fillRect(Math.round(x - bodyW / 2), yTop, bodyW, h);
    }
  }

  // 4) HLC bars — high-low vertical + right close tick only (no open tick).
  _drawHlcBars(visible, firstVisibleAbs, plot, priceToY) {
    const tickLen = Math.max(2, Math.floor(this.view.cellW / 2));
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const xCenter = Math.round(this._candleXCenter(firstVisibleAbs + i, plot));
      const prevC = i > 0 ? visible[i - 1].c
          : (firstVisibleAbs > 0 ? this.candles[firstVisibleAbs - 1].c : c.o);
      const isUp = c.c >= prevC;
      this.ctx.strokeStyle = isUp ? this.palette.bull : this.palette.bear;
      this.ctx.lineWidth = 1.2;
      this.ctx.beginPath();
      this.ctx.moveTo(xCenter + 0.5, priceToY(c.h));
      this.ctx.lineTo(xCenter + 0.5, priceToY(c.l));
      const yc = priceToY(c.c);
      this.ctx.moveTo(xCenter + 0.5, yc);
      this.ctx.lineTo(xCenter + tickLen + 0.5, yc);
      this.ctx.stroke();
    }
  }

  // 5) High-Low — high-low vertical line only, coloured up/down vs prev close.
  _drawHighLow(visible, firstVisibleAbs, plot, priceToY) {
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const xCenter = Math.round(this._candleXCenter(firstVisibleAbs + i, plot));
      const prevC = i > 0 ? visible[i - 1].c
          : (firstVisibleAbs > 0 ? this.candles[firstVisibleAbs - 1].c : c.o);
      const isUp = c.c >= prevC;
      this.ctx.strokeStyle = isUp ? this.palette.bull : this.palette.bear;
      this.ctx.lineWidth = 1.4;
      this.ctx.beginPath();
      this.ctx.moveTo(xCenter + 0.5, priceToY(c.h));
      this.ctx.lineTo(xCenter + 0.5, priceToY(c.l));
      this.ctx.stroke();
    }
  }

  // 6) HLC area — translucent band between high & low + a close line.
  _drawHlcArea(visible, firstVisibleAbs, plot, priceToY) {
    if (visible.length === 0) return;
    const stroke = this.palette.accent || this.palette.bull;
    const xs = new Array(visible.length);
    const yh = new Array(visible.length);
    const yl = new Array(visible.length);
    const yc = new Array(visible.length);
    for (let i = 0; i < visible.length; i++) {
      xs[i] = this._candleXCenter(firstVisibleAbs + i, plot);
      yh[i] = priceToY(visible[i].h);
      yl[i] = priceToY(visible[i].l);
      yc[i] = priceToY(visible[i].c);
    }
    // Band polygon: highs left→right, then lows right→left.
    this.ctx.fillStyle = this._withAlpha(stroke, 0.16);
    this.ctx.beginPath();
    this.ctx.moveTo(xs[0], yh[0]);
    for (let i = 1; i < xs.length; i++) this.ctx.lineTo(xs[i], yh[i]);
    for (let i = xs.length - 1; i >= 0; i--) this.ctx.lineTo(xs[i], yl[i]);
    this.ctx.closePath();
    this.ctx.fill();
    // Close line on top.
    this.ctx.strokeStyle = stroke;
    this.ctx.lineWidth = 1.5;
    this.ctx.beginPath();
    for (let i = 0; i < xs.length; i++) {
      if (i === 0) this.ctx.moveTo(xs[i], yc[i]);
      else this.ctx.lineTo(xs[i], yc[i]);
    }
    this.ctx.stroke();
  }

  // 7) Volume candles — candles whose body width scales with volume relative
  //    to the visible rolling max. Wick stays 1px; only the body breathes.
  _drawVolCandles(visible, firstVisibleAbs, plot, priceToY) {
    let maxV = 0;
    for (const c of visible) if (c.v > maxV) maxV = c.v;
    const fullW = Math.max(1, this.view.cellW - 2);
    const minW = Math.max(1, fullW * 0.2);
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const absoluteIdx = firstVisibleAbs + i;
      const xCenter = this._candleXCenter(absoluteIdx, plot);
      const isBull = c.c >= c.o;
      const color = isBull ? this.palette.bull : this.palette.bear;
      // Wick.
      this.ctx.fillStyle = color;
      this.ctx.fillRect(Math.round(xCenter), priceToY(c.h), 1, priceToY(c.l) - priceToY(c.h));
      // Body width scaled by volume share.
      const frac = maxV > 0 ? (c.v / maxV) : 1;
      const bodyW = Math.max(minW, fullW * frac);
      const bodyTop = Math.min(priceToY(c.o), priceToY(c.c));
      const bodyBot = Math.max(priceToY(c.o), priceToY(c.c));
      const bodyH = Math.max(1, bodyBot - bodyTop);
      this.ctx.fillRect(Math.round(xCenter - bodyW / 2), bodyTop, bodyW, bodyH);
    }
  }

  // ── Phase 26 — rebinned styles (mirror the renko pipeline) ────────────────

  // Build this._rebinned for the current style. Each element is a pseudo-candle
  // {o,h,l,c,v,ts,direction} so the shared draw helpers + _seriesLength() work.
  _rebuildRebinned() {
    this._rebinned = [];
    this._rebinnedStyle = this.candleStyle;
    const bars = this.candles;
    if (!bars || bars.length === 0) return;
    switch (this.candleStyle) {
      case 'linebreak': this._rebinned = this._buildLineBreak(bars); break;
      case 'kagi':      this._rebinned = this._buildKagi(bars); break;
      case 'range':     this._rebinned = this._buildRange(bars); break;
      case 'pnf':       this._rebinned = this._buildPnf(bars); break;
      default:          this._rebinned = []; this._rebinnedStyle = null; break;
    }
  }

  // Three Line Break: a new line is drawn when the close exceeds the extreme
  // of the prior `lines` (3) lines; a reversal needs to exceed the extreme of
  // the last `lines` lines in the opposite direction. Otherwise no new line.
  _buildLineBreak(bars, lines = 3) {
    const out = [];
    let dir = 0; // +1 up, -1 down, 0 unset
    for (let i = 0; i < bars.length; i++) {
      const close = bars[i].c;
      const ts = bars[i].ts;
      if (out.length === 0) {
        // Seed from the first two distinct closes.
        if (i === 0) continue;
        const open = bars[0].c;
        if (close === open) continue;
        dir = close > open ? 1 : -1;
        out.push({
          o: open, c: close,
          h: Math.max(open, close), l: Math.min(open, close),
          v: 0, ts, direction: dir > 0 ? 'up' : 'down',
        });
        continue;
      }
      const last = out[out.length - 1];
      if (dir > 0) {
        if (close > last.c) {
          out.push(this._lbLine(last.c, close, ts, 'up'));
        } else {
          // Reversal needs to break the low of the last `lines` lines.
          const lookback = out.slice(Math.max(0, out.length - lines));
          let minLow = Infinity;
          for (const ln of lookback) if (ln.l < minLow) minLow = ln.l;
          if (close < minLow) {
            dir = -1;
            out.push(this._lbLine(last.l, close, ts, 'down'));
          }
        }
      } else {
        if (close < last.c) {
          out.push(this._lbLine(last.c, close, ts, 'down'));
        } else {
          const lookback = out.slice(Math.max(0, out.length - lines));
          let maxHigh = -Infinity;
          for (const ln of lookback) if (ln.h > maxHigh) maxHigh = ln.h;
          if (close > maxHigh) {
            dir = 1;
            out.push(this._lbLine(last.h, close, ts, 'up'));
          }
        }
      }
    }
    return out;
  }

  _lbLine(open, close, ts, direction) {
    return {
      o: open, c: close,
      h: Math.max(open, close), l: Math.min(open, close),
      v: 0, ts, direction,
    };
  }

  // Kagi: a continuous line that reverses only when price moves against the
  // current direction by at least `reversal` (default ~4% of price). Rendered
  // as pseudo-candles (one per leg); thick (yang) once price clears the prior
  // shoulder high, thin (yin) once it breaks the prior shoulder low. We encode
  // thickness in `direction` ('up' = yang/thick, 'down' = yin/thin) at draw
  // time via the leg's own trend, and store the leg endpoints in o/c.
  _buildKagi(bars) {
    if (bars.length < 2) return [];
    // Reversal threshold = ATR-based brick size (same scale as Renko), NOT a
    // fixed % of price — a 4% reversal on an intraday index is ~hundreds of
    // points, so the line almost never reverses and looks empty.
    const ti = (this.scrip && this.scrip.ti) || 0.05;
    const reversal = Math.max(ti, this._computeRenkoBrickSize());
    const out = [];
    let trend = 0; // +1 rising, -1 falling
    let anchor = bars[0].c; // start of the current leg
    let extreme = bars[0].c; // current leg extreme (high if rising, low if falling)
    let ts0 = bars[0].ts;
    for (let i = 1; i < bars.length; i++) {
      const p = bars[i].c;
      const ts = bars[i].ts;
      if (trend === 0) {
        if (p >= anchor + reversal) { trend = 1; extreme = p; }
        else if (p <= anchor - reversal) { trend = -1; extreme = p; }
        continue;
      }
      if (trend > 0) {
        if (p > extreme) { extreme = p; }
        else if (p <= extreme - reversal) {
          // Reversal down: close the rising leg, start a falling leg.
          out.push(this._kagiLeg(anchor, extreme, ts0, 'up'));
          anchor = extreme; extreme = p; trend = -1; ts0 = ts;
        }
      } else {
        if (p < extreme) { extreme = p; }
        else if (p >= extreme + reversal) {
          out.push(this._kagiLeg(anchor, extreme, ts0, 'down'));
          anchor = extreme; extreme = p; trend = 1; ts0 = ts;
        }
      }
    }
    // Flush the final in-progress leg.
    if (trend !== 0) {
      out.push(this._kagiLeg(anchor, extreme, ts0, trend > 0 ? 'up' : 'down'));
    }
    return out;
  }

  _kagiLeg(from, to, ts, direction) {
    return {
      o: from, c: to,
      h: Math.max(from, to), l: Math.min(from, to),
      v: 0, ts, direction,
    };
  }

  _medianClose(bars) {
    const cs = bars.map((b) => b.c).filter((v) => isFinite(v)).sort((a, b) => a - b);
    if (cs.length === 0) return 1;
    const mid = Math.floor(cs.length / 2);
    return cs.length % 2 ? cs[mid] : (cs[mid - 1] + cs[mid]) / 2;
  }

  // Range bars: a new bar is emitted each time price travels a fixed amount
  // (the range size) from the current bar's open. Size auto-derived from ATR
  // (reusing _computeRenkoBrickSize, which is ATR(14) snapped to tick).
  _buildRange(bars) {
    const size = this._computeRenkoBrickSize();
    if (!isFinite(size) || size <= 0) return [];
    const out = [];
    let cur = null;
    const start = (o, ts) => ({ o, h: o, l: o, c: o, v: 0, ts, direction: 'up' });
    for (let i = 0; i < bars.length; i++) {
      const b = bars[i];
      // Drive the range engine with H/L/C of each source bar so intrabar
      // travel still forms bars. Use close as the dominant driver.
      const prices = [b.o, (b.c >= b.o ? b.l : b.h), (b.c >= b.o ? b.h : b.l), b.c];
      for (const price of prices) {
        if (!isFinite(price)) continue;
        if (cur === null) { cur = start(price, b.ts); continue; }
        if (price > cur.h) cur.h = price;
        if (price < cur.l) cur.l = price;
        cur.c = price;
        cur.v += 0;
        while (cur.h - cur.l >= size) {
          // Close a bar spanning exactly `size` from the open in the travel
          // direction, then seed the next from the breakout level.
          const up = price >= cur.o;
          const close = up ? cur.o + size : cur.o - size;
          out.push({
            o: cur.o, c: close,
            h: up ? close : cur.h, l: up ? cur.l : close,
            v: 0, ts: b.ts, direction: up ? 'up' : 'down',
          });
          cur = start(close, b.ts);
        }
      }
    }
    if (cur && cur.h !== cur.l) {
      cur.direction = cur.c >= cur.o ? 'up' : 'down';
      out.push(cur);
    }
    return out;
  }

  // Point & Figure: X (up) / O (down) columns. Box size ~% of median price (or
  // ATR), reversal = 3 boxes. We rebin into pseudo-candles where each element
  // is a column spanning [low,high] with direction up (X) / down (O). The
  // dedicated drawer renders X/O glyphs across the column's box range.
  _buildPnf(bars, reversalBoxes = 3) {
    const box = this._computeRenkoBrickSize(); // ATR-snapped; reused as box size.
    if (!isFinite(box) || box <= 0) return [];
    const boxes = (p) => Math.floor(p / box); // box index for a price
    const out = [];
    let dir = 0;            // +1 X column, -1 O column
    let topBox = null;      // highest box filled in current X column
    let botBox = null;      // lowest box filled in current O column
    const pushCol = (lowBox, highBox, direction, ts) => {
      out.push({
        o: lowBox * box, c: highBox * box,
        l: lowBox * box, h: highBox * box,
        v: 0, ts, direction,
        boxSize: box, lowBox, highBox,
      });
    };
    for (let i = 0; i < bars.length; i++) {
      const b = bars[i];
      const hiB = boxes(b.h);
      const loB = boxes(b.l);
      if (dir === 0) {
        // Seed: prefer an up column.
        dir = 1; topBox = hiB; botBox = loB;
        continue;
      }
      if (dir > 0) {
        if (hiB > topBox) {
          topBox = hiB; // extend the X column
        } else if (loB <= topBox - reversalBoxes) {
          // Reverse down: close X column, open O column one box below the top.
          pushCol(botBox != null ? botBox : (topBox - (hiB - loB)), topBox, 'up',
              b.ts);
          dir = -1; botBox = loB; topBox = null;
        }
      } else {
        if (loB < botBox) {
          botBox = loB; // extend the O column
        } else if (hiB >= botBox + reversalBoxes) {
          pushCol(botBox, topBox != null ? topBox : (botBox + (hiB - loB)), 'down',
              b.ts);
          dir = 1; topBox = hiB; botBox = null;
        }
      }
    }
    // Flush the final column.
    if (dir > 0 && topBox != null) {
      pushCol(botBox != null ? botBox : topBox - 1, topBox, 'up',
          bars[bars.length - 1].ts);
    } else if (dir < 0 && botBox != null) {
      pushCol(botBox, topBox != null ? topBox : botBox + 1, 'down',
          bars[bars.length - 1].ts);
    }
    return out;
  }

  // Generic drawer for rebinned pseudo-candles (linebreak / range). Mirrors
  // _drawRenko: iterates this._rebinned by index using _candleXCenter(i).
  _drawRebinnedCandles(plot, priceToY, opts) {
    const arr = this._rebinned;
    if (!arr || arr.length === 0) return;
    const total = arr.length;
    const firstVisible = Math.max(0,
        Math.floor(this.view.firstVisible != null ? this.view.firstVisible : 0));
    const lastVisible = Math.min(total - 1,
        Math.ceil(this.view.lastVisible != null ? this.view.lastVisible : total - 1));
    if (firstVisible > lastVisible) return;
    const bodyW = Math.max(1, this.view.cellW - 2);
    for (let i = firstVisible; i <= lastVisible; i++) {
      const b = arr[i];
      const xCenter = this._candleXCenter(i, plot);
      const color = b.direction === 'up' ? this.palette.bull : this.palette.bear;
      this.ctx.fillStyle = color;
      const yTop = Math.min(priceToY(b.o), priceToY(b.c));
      const yBot = Math.max(priceToY(b.o), priceToY(b.c));
      const h = Math.max(1, yBot - yTop);
      this.ctx.fillRect(Math.round(xCenter - bodyW / 2), yTop, bodyW, h);
    }
  }

  // Kagi line drawer — connects leg endpoints with a stepped line. Thick when
  // the leg rises (yang), thin when it falls (yin); colour follows direction.
  _drawKagi(plot, priceToY) {
    const arr = this._rebinned;
    if (!arr || arr.length === 0) return;
    const total = arr.length;
    const firstVisible = Math.max(0,
        Math.floor(this.view.firstVisible != null ? this.view.firstVisible : 0));
    const lastVisible = Math.min(total - 1,
        Math.ceil(this.view.lastVisible != null ? this.view.lastVisible : total - 1));
    if (firstVisible > lastVisible) return;
    for (let i = firstVisible; i <= lastVisible; i++) {
      const b = arr[i];
      const x = this._candleXCenter(i, plot);
      const yFrom = priceToY(b.o);
      const yTo = priceToY(b.c);
      const isUp = b.direction === 'up';
      this.ctx.strokeStyle = isUp ? this.palette.bull : this.palette.bear;
      this.ctx.lineWidth = isUp ? 2.4 : 1.0; // yang thick, yin thin
      this.ctx.beginPath();
      // Horizontal connector from the previous leg's x, then the vertical leg.
      if (i > firstVisible) {
        const xPrev = this._candleXCenter(i - 1, plot);
        this.ctx.moveTo(xPrev, yFrom);
        this.ctx.lineTo(x, yFrom);
      } else {
        this.ctx.moveTo(x, yFrom);
      }
      this.ctx.lineTo(x, yTo);
      this.ctx.stroke();
    }
  }

  // Point & Figure drawer — renders X (up) / O (down) glyphs stacked across
  // each column's box range. One glyph per box between low and high.
  _drawPnf(plot, priceToY) {
    const arr = this._rebinned;
    if (!arr || arr.length === 0) return;
    const total = arr.length;
    const firstVisible = Math.max(0,
        Math.floor(this.view.firstVisible != null ? this.view.firstVisible : 0));
    const lastVisible = Math.min(total - 1,
        Math.ceil(this.view.lastVisible != null ? this.view.lastVisible : total - 1));
    if (firstVisible > lastVisible) return;
    const cellW = Math.max(2, this.view.cellW - 2);
    const half = cellW / 2;
    for (let i = firstVisible; i <= lastVisible; i++) {
      const b = arr[i];
      const x = this._candleXCenter(i, plot);
      const isUp = b.direction === 'up';
      const box = b.boxSize || (b.h - b.l) || 1;
      this.ctx.strokeStyle = isUp ? this.palette.bull : this.palette.bear;
      this.ctx.lineWidth = 1.4;
      // Iterate box rows from low to high (inclusive).
      for (let price = b.l; price <= b.h + 1e-9; price += box) {
        const yMid = priceToY(price + box / 2);
        const yTop = priceToY(price + box);
        const yBot = priceToY(price);
        if (isUp) {
          // X — two diagonals across the box cell.
          this.ctx.beginPath();
          this.ctx.moveTo(x - half, yBot); this.ctx.lineTo(x + half, yTop);
          this.ctx.moveTo(x - half, yTop); this.ctx.lineTo(x + half, yBot);
          this.ctx.stroke();
        } else {
          // O — an ellipse inscribed in the box cell.
          const ry = Math.abs(yBot - yTop) / 2 - 1;
          this.ctx.beginPath();
          this.ctx.ellipse(x, yMid, half, Math.max(1, ry), 0, 0, Math.PI * 2);
          this.ctx.stroke();
        }
      }
    }
  }

  // ── End Phase 26 draw helpers ─────────────────────────────────────────────

  // ── End Phase 16 draw helpers ─────────────────────────────────────────────

}
for (const _k of Object.getOwnPropertyNames(_ChartTypesMixin.prototype)) {
  if (_k !== 'constructor') Chart.prototype[_k] = _ChartTypesMixin.prototype[_k];
}
