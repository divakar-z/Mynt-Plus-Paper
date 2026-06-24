'use strict';

// ---------------------------------------------------------------------------
// chart-indicators.js — indicator compute + sub-pane rendering, plus the
// scan-explain and auto-pattern renderers (all sub-pane / overlay-adjacent).
// Loaded AFTER chart.js: the methods are authored as a throwaway mixin class
// (so they keep verbatim class-method syntax — no comma surgery) and copied
// onto Chart.prototype. Behaviour identical to the originals.
// ---------------------------------------------------------------------------
class _ChartIndicatorsMixin {
  // ----- Phase 8 — Indicator compute helpers ------------------------------
  // SMA / EMA / RSI all operate on the close series of `this.candles`.
  // Returned arrays are the same length as `this.candles`; leading entries
  // (before the indicator has enough history) are `null` so the renderer can
  // skip them without ambiguity.
  _computeSMA(period) {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (period <= 0 || n < period) return out;
    let sum = 0;
    for (let i = 0; i < n; i++) {
      sum += this.candles[i].c;
      if (i >= period) sum -= this.candles[i - period].c;
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }

  _computeEMA(period) {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (period <= 0 || n === 0) return out;
    const k = 2 / (period + 1);
    let ema = null;
    for (let i = 0; i < n; i++) {
      const c = this.candles[i].c;
      if (ema == null) ema = c;
      else ema = c * k + ema * (1 - k);
      if (i >= period - 1) out[i] = ema;
    }
    return out;
  }

  _computeRSI(period) {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (period <= 0 || n < period + 1) return out;
    let avgGain = 0, avgLoss = 0;
    for (let i = 1; i <= period; i++) {
      const ch = this.candles[i].c - this.candles[i - 1].c;
      if (ch >= 0) avgGain += ch;
      else avgLoss -= ch;
    }
    avgGain /= period;
    avgLoss /= period;
    const rs0 = avgLoss === 0 ? 100 : avgGain / avgLoss;
    out[period] = avgLoss === 0 ? 100 : 100 - 100 / (1 + rs0);
    for (let i = period + 1; i < n; i++) {
      const ch = this.candles[i].c - this.candles[i - 1].c;
      const g = ch > 0 ? ch : 0;
      const l = ch < 0 ? -ch : 0;
      avgGain = (avgGain * (period - 1) + g) / period;
      avgLoss = (avgLoss * (period - 1) + l) / period;
      const rs = avgLoss === 0 ? 100 : avgGain / avgLoss;
      out[i] = avgLoss === 0 ? 100 : 100 - 100 / (1 + rs);
    }
    return out;
  }

  // ---------- Phase 11 ----------

  // Accepts either a number (legacy) or an indicator-like object with
  // `{ params, period }` so the schema-driven dialog can override `length`
  // and `mult` without breaking older call sites.
  _computeBB(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const period = (arg && typeof arg === 'object')
        ? (+p.length || +arg.period || 20)
        : (+arg || 20);
    const STDDEV = +p.mult || 2;
    const n = this.candles.length;
    const mid = new Array(n).fill(null);
    const upper = new Array(n).fill(null);
    const lower = new Array(n).fill(null);
    if (period <= 1 || n < period) return { mid, upper, lower };
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

  // Accepts an indicator-like object so the schema-driven dialog can override
  // fast/slow/signal. Legacy `undefined` keeps TradingView defaults.
  _computeMACD(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const FAST = +p.fast || 12;
    const SLOW = +p.slow || 26;
    const SIGNAL = +p.signal || 9;
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
    return { macd, signal, hist, periods: { fast: FAST, slow: SLOW, signal: SIGNAL } };
  }

  // Accepts a number (legacy: kPeriod) OR an indicator-like object with
  // `{ params, period }`. Schema keys: kPeriod, dPeriod, smooth.
  // When `params` is absent we keep the original behaviour exactly:
  //   k = raw fast-stoch over `period`, d = SMA(k, 3).
  // With params present, k is first smoothed by `smooth` (when > 1),
  // then d = SMA(smoothedK, dPeriod).
  _computeStoch(arg) {
    const hasParams = !!(arg && typeof arg === 'object' &&
        arg.params && Object.keys(arg.params).length > 0);
    const p = hasParams ? arg.params : {};
    const period = (arg && typeof arg === 'object')
        ? (+p.kPeriod || +arg.period || 14)
        : (+arg || 14);
    const SMOOTH = hasParams ? (+p.smooth || 1) : 1; // legacy: no extra K smoothing
    const D_PERIOD = hasParams ? (+p.dPeriod || 3) : 3;
    const n = this.candles.length;
    const kRaw = new Array(n).fill(null);
    if (period <= 0 || n < period) return { k: kRaw, d: new Array(n).fill(null) };
    for (let i = period - 1; i < n; i++) {
      let lo = Infinity, hi = -Infinity;
      for (let j = i - period + 1; j <= i; j++) {
        if (this.candles[j].l < lo) lo = this.candles[j].l;
        if (this.candles[j].h > hi) hi = this.candles[j].h;
      }
      const range = hi - lo;
      kRaw[i] = range > 0 ? ((this.candles[i].c - lo) / range) * 100 : 50;
    }
    let kOut = kRaw;
    if (SMOOTH > 1) {
      kOut = new Array(n).fill(null);
      for (let i = 0; i < n; i++) {
        if (i < period - 1 + SMOOTH - 1) continue;
        let sum = 0;
        let count = 0;
        for (let j = i - SMOOTH + 1; j <= i; j++) {
          if (kRaw[j] != null) { sum += kRaw[j]; count++; }
        }
        if (count === SMOOTH) kOut[i] = sum / SMOOTH;
      }
    }
    const d = new Array(n).fill(null);
    for (let i = 0; i < n; i++) {
      let sum = 0;
      let count = 0;
      for (let j = i - D_PERIOD + 1; j <= i; j++) {
        if (j < 0) continue;
        if (kOut[j] != null) { sum += kOut[j]; count++; }
      }
      if (count === D_PERIOD) d[i] = sum / D_PERIOD;
    }
    return { k: kOut, d };
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

  // Phase 20 — Stochastic RSI: Stochastic of the RSI series, period default 14
  // on both legs. Returns array of {k, d} values aligned to candles (nulls for
  // the warm-up period). %K is the raw stoch; %D is its 3-period SMA.
  // Accepts a number (legacy: rsi length) OR an indicator-like object.
  // Schema keys: rsiLength, stochLength, kPeriod, dPeriod.
  _computeStochRsi(arg) {
    const hasParams = !!(arg && typeof arg === 'object' &&
        arg.params && Object.keys(arg.params).length > 0);
    const p = hasParams ? arg.params : {};
    const rsiLength = (arg && typeof arg === 'object')
        ? Math.max(1, (+p.rsiLength || +arg.period || 14) | 0)
        : Math.max(1, (+arg || 14) | 0);
    const stochLength = Math.max(1, (+p.stochLength || rsiLength) | 0);
    // Legacy: raw %K (kSmooth=1) + 3-SMA %D; only apply user K-smoothing when
    // the schema-driven dialog has written a non-empty params bag.
    const kSmooth = hasParams ? Math.max(1, (+p.kPeriod || 3) | 0) : 1;
    const dSmooth = Math.max(1, (+p.dPeriod || 3) | 0);
    const rsi = this._computeRSI(rsiLength);
    const raw = new Array(this.candles.length).fill(null);
    const window = [];
    for (let i = 0; i < rsi.length; i++) {
      const v = rsi[i];
      if (v == null || !isFinite(v)) { window.length = 0; continue; }
      window.push(v);
      if (window.length > stochLength) window.shift();
      if (window.length < stochLength) continue;
      let lo = Infinity, hi = -Infinity;
      for (const x of window) { if (x < lo) lo = x; if (x > hi) hi = x; }
      const denom = hi - lo;
      raw[i] = denom > 0 ? ((v - lo) / denom) * 100 : 50;
    }
    // %K = SMA(raw, kSmooth) — when kSmooth=1 this is a passthrough.
    const out = new Array(raw.length).fill(null);
    const kBuf = [];
    for (let i = 0; i < raw.length; i++) {
      const r = raw[i];
      if (r == null) { kBuf.length = 0; continue; }
      kBuf.push(r);
      if (kBuf.length > kSmooth) kBuf.shift();
      if (kBuf.length === kSmooth) {
        let s = 0; for (const x of kBuf) s += x; out[i] = s / kSmooth;
      }
    }
    // %D = SMA(%K, dSmooth)
    const smoothed = new Array(out.length).fill(null);
    const buf = [];
    for (let i = 0; i < out.length; i++) {
      const k = out[i];
      if (k == null) { buf.length = 0; smoothed[i] = null; continue; }
      buf.push(k);
      if (buf.length > dSmooth) buf.shift();
      if (buf.length === dSmooth) {
        let s = 0; for (const x of buf) s += x; smoothed[i] = s / dSmooth;
      } else {
        smoothed[i] = null;
      }
    }
    return out.map((k, i) => ({ k, d: smoothed[i] }));
  }

  // Phase 20 — Zero-Lag EMA: ZLEMA = EMA(2*src - EMA(src, n), n)
  _computeZLEMA(period) {
    const n = Math.max(1, period | 0);
    const k = 2 / (n + 1);
    const src = this.candles.map((c) => c.c);
    // First EMA pass
    const e1 = new Array(src.length);
    let prev = null;
    for (let i = 0; i < src.length; i++) {
      prev = prev == null ? src[i] : (src[i] * k + prev * (1 - k));
      e1[i] = prev;
    }
    // De-lagged input
    const dl = src.map((s, i) => 2 * s - e1[i]);
    // Second EMA pass
    const out = new Array(src.length);
    prev = null;
    for (let i = 0; i < dl.length; i++) {
      prev = prev == null ? dl[i] : (dl[i] * k + prev * (1 - k));
      out[i] = prev;
    }
    // First (n-1) values are warm-up; null them so they don't draw.
    for (let i = 0; i < Math.min(n - 1, out.length); i++) out[i] = null;
    return out;
  }

  // Phase 20 — McGinley Dynamic: adaptive moving average that responds faster
  // in trending markets, slower in choppy ones. MD = MD_prev + (C - MD_prev) /
  // (N * (C / MD_prev)^4). First value seeded from close.
  _computeMcGinley(period) {
    const n = Math.max(1, period | 0);
    const out = new Array(this.candles.length).fill(null);
    let md = null;
    for (let i = 0; i < this.candles.length; i++) {
      const c = this.candles[i].c;
      if (md == null) { md = c; out[i] = null; continue; }
      const ratio = c / md;
      const denom = n * Math.pow(ratio, 4);
      md = md + (c - md) / (denom || n);
      out[i] = md;
    }
    for (let i = 0; i < Math.min(n - 1, out.length); i++) out[i] = null;
    return out;
  }

  // Phase 20 — Elder's Force Index: (Close - PrevClose) * Volume.
  // Smoothed with EMA(period). Drawn as a sub-pane histogram around zero.
  _computeEFI(period) {
    const n = Math.max(1, period | 0);
    const raw = new Array(this.candles.length).fill(null);
    for (let i = 1; i < this.candles.length; i++) {
      const a = this.candles[i - 1];
      const b = this.candles[i];
      const v = b.v || 0;
      raw[i] = (b.c - a.c) * v;
    }
    // EMA smoothing
    const k = 2 / (n + 1);
    const out = new Array(raw.length).fill(null);
    let prev = null;
    for (let i = 0; i < raw.length; i++) {
      const r = raw[i];
      if (r == null) { out[i] = null; continue; }
      prev = prev == null ? r : (r * k + prev * (1 - k));
      out[i] = prev;
    }
    return out;
  }

  // Phase 20 — Squeeze Momentum (LazyBear simplified): BB inside KC = squeeze
  // ON (red/yellow dot), BB outside KC = squeeze OFF (green/blue dot). Momentum
  // histogram is linear regression of (close - midpoint) over the period.
  // Returns array of {mom, squeezeOn} per candle (null until warmed up).
  // Accepts a number (legacy: shared length for BB+KC) OR an indicator-like
  // object. Schema keys: bbLength, bbMult, kcLength, kcMult. When the two
  // lengths differ we use max(bbLength, kcLength) as the lookback window for
  // the momentum/linregress calc (same as the LazyBear reference).
  _computeSqueeze(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const baseLen = (arg && typeof arg === 'object')
        ? Math.max(1, (+arg.period || 20) | 0)
        : Math.max(1, (+arg || 20) | 0);
    const bbLength = Math.max(1, (+p.bbLength || baseLen) | 0);
    const kcLength = Math.max(1, (+p.kcLength || baseLen) | 0);
    const mult = +p.bbMult || 2;
    const kcMult = +p.kcMult || 1.5;
    const n = Math.max(bbLength, kcLength);
    const out = new Array(this.candles.length).fill(null);
    if (this.candles.length < n) return out;
    // Pre-compute true range for KC.
    const tr = new Array(this.candles.length).fill(0);
    for (let i = 0; i < this.candles.length; i++) {
      const c = this.candles[i];
      if (i === 0) { tr[i] = c.h - c.l; continue; }
      const pp = this.candles[i - 1];
      tr[i] = Math.max(c.h - c.l, Math.abs(c.h - pp.c), Math.abs(c.l - pp.c));
    }
    for (let i = n - 1; i < this.candles.length; i++) {
      // SMA + stddev for BB over bbLength
      let sumBB = 0;
      for (let j = i - bbLength + 1; j <= i; j++) sumBB += this.candles[j].c;
      const meanBB = sumBB / bbLength;
      let sumSq = 0;
      for (let j = i - bbLength + 1; j <= i; j++) {
        const d = this.candles[j].c - meanBB;
        sumSq += d * d;
      }
      const sd = Math.sqrt(sumSq / bbLength);
      const bbU = meanBB + mult * sd;
      const bbL = meanBB - mult * sd;
      // KC: SMA ± kcMult * ATR(kcLength)
      let sumKc = 0;
      for (let j = i - kcLength + 1; j <= i; j++) sumKc += this.candles[j].c;
      const meanKC = sumKc / kcLength;
      let sumTr = 0;
      for (let j = i - kcLength + 1; j <= i; j++) sumTr += tr[j];
      const atr = sumTr / kcLength;
      const kcU = meanKC + kcMult * atr;
      const kcL = meanKC - kcMult * atr;
      const squeezeOn = bbU < kcU && bbL > kcL;
      let hi = -Infinity, lo = Infinity;
      for (let j = i - n + 1; j <= i; j++) {
        if (this.candles[j].h > hi) hi = this.candles[j].h;
        if (this.candles[j].l < lo) lo = this.candles[j].l;
      }
      const mid = ((hi + lo) / 2 + meanBB) / 2;
      let sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for (let j = 0; j < n; j++) {
        const y = this.candles[i - n + 1 + j].c - mid;
        sumX += j; sumY += y; sumXY += j * y; sumX2 += j * j;
      }
      const denom = (n * sumX2 - sumX * sumX);
      const slope = denom !== 0 ? (n * sumXY - sumX * sumY) / denom : 0;
      const intercept = (sumY - slope * sumX) / n;
      const mom = slope * (n - 1) + intercept;
      out[i] = { mom, squeezeOn };
    }
    return out;
  }

  // Phase 22 — WaveTrend Oscillator (LazyBear). Returns {wt1, wt2} per candle
  // (nulls until warmed up). Period default 10 channel + ~21 average.
  _computeWaveTrend(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const baseLen = (arg && typeof arg === 'object')
        ? Math.max(1, (+arg.period || 10) | 0)
        : Math.max(1, (+arg || 10) | 0);
    const n = Math.max(1, (+p.channelLength || baseLen) | 0);
    const n2 = Math.max(1, (+p.averageLength || Math.round(n * 2.1)) | 0);
    const tp = this.candles.map((c) => (c.h + c.l + c.c) / 3);
    // ESA = EMA(tp, n)
    const k1 = 2 / (n + 1);
    const esa = new Array(tp.length);
    let prev = null;
    for (let i = 0; i < tp.length; i++) {
      prev = prev == null ? tp[i] : (tp[i] * k1 + prev * (1 - k1));
      esa[i] = prev;
    }
    // D = EMA(abs(tp - esa), n)
    const d = new Array(tp.length);
    prev = null;
    for (let i = 0; i < tp.length; i++) {
      const x = Math.abs(tp[i] - esa[i]);
      prev = prev == null ? x : (x * k1 + prev * (1 - k1));
      d[i] = prev;
    }
    // CI = (tp - esa) / (0.015 * d)
    const ci = tp.map((t, i) =>
        d[i] > 0 ? (t - esa[i]) / (0.015 * d[i]) : 0);
    // WT1 = EMA(ci, n2), WT2 = SMA(wt1, 4)
    const k2 = 2 / (n2 + 1);
    const wt1 = new Array(ci.length);
    prev = null;
    for (let i = 0; i < ci.length; i++) {
      prev = prev == null ? ci[i] : (ci[i] * k2 + prev * (1 - k2));
      wt1[i] = prev;
    }
    const wt2 = new Array(wt1.length).fill(null);
    for (let i = 3; i < wt1.length; i++) {
      wt2[i] = (wt1[i] + wt1[i-1] + wt1[i-2] + wt1[i-3]) / 4;
    }
    const out = wt1.map((v, i) => ({ wt1: v, wt2: wt2[i] }));
    for (let i = 0; i < Math.min(n + n2 - 1, out.length); i++) {
      out[i] = { wt1: null, wt2: null };
    }
    return out;
  }

  // Phase 22 — Connors RSI = (RSI(close,n) + RSI(streak,2) + PercentRank(roc,100)) / 3.
  // Default n=3. Returns array of numbers (or null while warming).
  _computeConnorsRSI(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const rsiLen = (arg && typeof arg === 'object')
        ? Math.max(1, (+p.rsiLength || +arg.period || 3) | 0)
        : Math.max(1, (+arg || 3) | 0);
    const streakLen = Math.max(1, (+p.streakLength || 2) | 0);
    const rocLen = Math.max(2, (+p.rocLength || 100) | 0);
    const close = this.candles.map((c) => c.c);
    const rsi1 = this._rsiOnSeries(close, rsiLen);
    const streak = new Array(close.length).fill(0);
    for (let i = 1; i < close.length; i++) {
      if (close[i] > close[i - 1]) streak[i] = streak[i - 1] >= 0 ? streak[i - 1] + 1 : 1;
      else if (close[i] < close[i - 1]) streak[i] = streak[i - 1] <= 0 ? streak[i - 1] - 1 : -1;
      else streak[i] = 0;
    }
    const rsi2 = this._rsiOnSeries(streak, streakLen);
    const roc = new Array(close.length).fill(0);
    for (let i = 1; i < close.length; i++) {
      const pp = close[i - 1];
      roc[i] = pp > 0 ? ((close[i] - pp) / pp) * 100 : 0;
    }
    const pct = new Array(close.length).fill(null);
    for (let i = 0; i < close.length; i++) {
      if (i < rocLen) continue;
      let count = 0;
      const cur = roc[i];
      for (let j = i - rocLen; j < i; j++) if (roc[j] < cur) count++;
      pct[i] = (count / rocLen) * 100;
    }
    const out = new Array(close.length).fill(null);
    for (let i = 0; i < close.length; i++) {
      if (rsi1[i] == null || rsi2[i] == null || pct[i] == null) continue;
      out[i] = (rsi1[i] + rsi2[i] + pct[i]) / 3;
    }
    return out;
  }

  // Internal helper — RSI on an arbitrary numeric series.
  _rsiOnSeries(src, n) {
    const out = new Array(src.length).fill(null);
    if (src.length < n + 1) return out;
    let avgU = 0, avgD = 0;
    for (let i = 1; i <= n; i++) {
      const d = src[i] - src[i - 1];
      if (d > 0) avgU += d; else avgD += -d;
    }
    avgU /= n; avgD /= n;
    out[n] = avgD === 0 ? 100 : 100 - 100 / (1 + avgU / avgD);
    for (let i = n + 1; i < src.length; i++) {
      const d = src[i] - src[i - 1];
      const u = d > 0 ? d : 0;
      const dn = d < 0 ? -d : 0;
      avgU = (avgU * (n - 1) + u) / n;
      avgD = (avgD * (n - 1) + dn) / n;
      out[i] = avgD === 0 ? 100 : 100 - 100 / (1 + avgU / avgD);
    }
    return out;
  }

  // Phase 22 — MA Ribbon: 8 EMAs at 5/10/20/30/40/50/60/80. Returns
  // { periods, lines } where lines is an array of 8 value arrays.
  _computeMaRibbon() {
    const periods = [5, 10, 20, 30, 40, 50, 60, 80];
    const src = this.candles.map((c) => c.c);
    const lines = periods.map((p) => {
      const k = 2 / (p + 1);
      const out = new Array(src.length).fill(null);
      let prev = null;
      for (let i = 0; i < src.length; i++) {
        prev = prev == null ? src[i] : (src[i] * k + prev * (1 - k));
        if (i >= p - 1) out[i] = prev;
      }
      return out;
    });
    return { periods, lines };
  }

  // Phase 22 — Ichimoku Cloud. Default conversion=9, base=26, span=52,
  // displacement=26. Returns {tenkan, kijun, spanA, spanB, chikou} arrays.
  _computeIchimoku(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const conv = Math.max(2, (+p.tenkan || 9) | 0);
    const base = Math.max(2, (+p.kijun || 26) | 0);
    const span = Math.max(2, (+p.senkouB || 52) | 0);
    const disp = Math.max(1, (+p.displacement || 26) | 0);
    const high  = this.candles.map((c) => c.h);
    const low   = this.candles.map((c) => c.l);
    const close = this.candles.map((c) => c.c);
    const N = close.length;
    const hh = (i, w) => { let m = -Infinity; for (let j = i - w + 1; j <= i; j++) if (j >= 0 && high[j] > m) m = high[j]; return m; };
    const ll = (i, w) => { let m =  Infinity; for (let j = i - w + 1; j <= i; j++) if (j >= 0 && low[j]  < m) m = low[j];  return m; };
    const tenkan = new Array(N).fill(null);
    const kijun  = new Array(N).fill(null);
    const spanA  = new Array(N).fill(null);
    const spanB  = new Array(N).fill(null);
    const chikou = new Array(N).fill(null);
    for (let i = 0; i < N; i++) {
      if (i >= conv - 1) tenkan[i] = (hh(i, conv) + ll(i, conv)) / 2;
      if (i >= base - 1) kijun[i]  = (hh(i, base) + ll(i, base)) / 2;
      if (tenkan[i] != null && kijun[i] != null && i + disp < N) {
        spanA[i + disp] = (tenkan[i] + kijun[i]) / 2;
      }
      if (i >= span - 1 && i + disp < N) {
        spanB[i + disp] = (hh(i, span) + ll(i, span)) / 2;
      }
      if (i + disp < N) chikou[i + disp] = close[i];
    }
    return { tenkan, kijun, spanA, spanB, chikou };
  }

  // Phase 22 — Volatility Stop (ATR-based trailing stop). When price is above
  // the stop, stop trails below; flips on close-cross. Returns {stop[], dir[]}.
  _computeVolStop(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const n = (arg && typeof arg === 'object')
        ? Math.max(1, (+p.length || +arg.period || 14) | 0)
        : Math.max(1, (+arg || 14) | 0);
    const mult = +p.multiplier || 2;
    const N = this.candles.length;
    if (N === 0) return { stop: [], dir: [] };
    // ATR
    const tr = new Array(N).fill(0);
    for (let i = 0; i < N; i++) {
      const c = this.candles[i];
      if (i === 0) { tr[i] = c.h - c.l; continue; }
      const p = this.candles[i - 1];
      tr[i] = Math.max(c.h - c.l, Math.abs(c.h - p.c), Math.abs(c.l - p.c));
    }
    const atr = new Array(N).fill(0);
    for (let i = 0; i < N; i++) {
      if (i < n) {
        let s = 0; for (let j = 0; j <= i; j++) s += tr[j];
        atr[i] = s / (i + 1);
      } else {
        atr[i] = (atr[i - 1] * (n - 1) + tr[i]) / n;
      }
    }
    const stop = new Array(N).fill(null);
    const dir = new Array(N).fill(null); // 1 = long-trailing-below, -1 = short-trailing-above
    let dDir = 1;
    let s = this.candles[0].c - mult * atr[0];
    stop[0] = s; dir[0] = dDir;
    for (let i = 1; i < N; i++) {
      const c = this.candles[i].c;
      const a = atr[i] * mult;
      if (dDir === 1) {
        const ns = Math.max(stop[i - 1] || -Infinity, c - a);
        if (c < ns) { dDir = -1; s = c + a; }
        else s = ns;
      } else {
        const ns = Math.min(stop[i - 1] || Infinity, c + a);
        if (c > ns) { dDir = 1; s = c - a; }
        else s = ns;
      }
      stop[i] = s; dir[i] = dDir;
    }
    return { stop, dir };
  }

  // ICT/SMC "Change in State of Delivery". A bullish CISD fires when a
  // bullish candle's body-close pierces the OPENING price of the most
  // recent bearish "delivery leg" (single bearish candle or consecutive
  // run of bearish candles). Bearish CISD is the symmetric inverse.
  // Wicks are explicitly ignored — only candle opens/closes matter
  // (the canonical doctrinal rule across every ICT-aligned source).
  //
  // Returns `{ events: [{i, kind:'bull'|'bear', level, endIdx, isStrict}] }`
  // where `endIdx` is the bar at which the line ends (invalidation by an
  // opposite-direction close past the level, or `i + expiryBars` expiry,
  // whichever is first). Strict mode filters: the opposing leg's first
  // candle must be at a swing pivot AND the triggering candle's body must
  // be >= `minBodyRatio` × its range.
  //
  // Sourced from a deep-research pass on 2026-05-30 verifying 19/25 claims
  // — see docs/superpowers/specs/2026-05-30-cisd-indicator-design.md.
  _computeCisd(ind) {
    const N = this.candles.length;
    if (N === 0) return { events: [] };
    const p = (ind && typeof ind === 'object') ? (ind.params || {}) : {};
    const strict = (+p.strictMode === 0) ? false : true;
    const pivotWidth = Math.max(1, (+p.pivotWidth || 2) | 0);
    const minBodyRatio = +p.minBodyRatio || (strict ? 0.65 : 0.50);
    const expiryBars = Math.max(1, (+p.expiryBars || 50) | 0);

    // Pre-compute per-candle direction (1=bull, -1=bear, 0=doji or zero-range).
    const dir = new Array(N);
    for (let i = 0; i < N; i++) {
      const c = this.candles[i];
      const range = c.h - c.l;
      if (range <= 0 || c.c === c.o) { dir[i] = 0; continue; }
      dir[i] = c.c > c.o ? 1 : -1;
    }

    // Single pass: walk candles, accumulate consecutive same-direction legs
    // (dojis are skipped — they don't break the current leg but don't
    // extend it either). Maintain the most-recently-COMPLETED opposing leg
    // for CISD detection; once a CISD fires for a leg, that leg's level is
    // "consumed" and we wait for a new opposing leg before the next CISD.
    const events = [];
    let curLeg = null;             // { startIdx, dir, firstOpen }
    let lastBearLeg = null;        // most recent completed bear leg (consumable)
    let lastBullLeg = null;        // most recent completed bull leg (consumable)

    const isSwingLow = (idx) => {
      // Idx must be a fractal swing low across ±pivotWidth bars. Right-side
      // confirmation: caller ensures idx + pivotWidth < N.
      const lo = this.candles[idx].l;
      for (let k = idx - pivotWidth; k <= idx + pivotWidth; k++) {
        if (k < 0 || k >= N || k === idx) continue;
        if (this.candles[k].l <= lo) return false;
      }
      return true;
    };
    const isSwingHigh = (idx) => {
      const hi = this.candles[idx].h;
      for (let k = idx - pivotWidth; k <= idx + pivotWidth; k++) {
        if (k < 0 || k >= N || k === idx) continue;
        if (this.candles[k].h >= hi) return false;
      }
      return true;
    };

    for (let i = 0; i < N; i++) {
      const c = this.candles[i];
      const d = dir[i];
      if (d === 0) continue;            // doji / zero-range → skip

      // Leg accumulation: either extend or rotate. When rotating, the
      // previously-active leg is published as the most-recent completed
      // leg of its direction.
      if (curLeg && curLeg.dir === d) {
        // Same-direction → extend (nothing to do; we only care about
        // firstOpen + dir which were set when the leg started).
      } else {
        if (curLeg) {
          if (curLeg.dir === 1) lastBullLeg = curLeg;
          else                  lastBearLeg = curLeg;
        }
        curLeg = { startIdx: i, dir: d, firstOpen: c.o, broken: false };
      }

      // CISD detection — body-close through the most recent opposing leg's
      // first.open. One event per opposing leg (broken-flag consumes it).
      const opposing = d === 1 ? lastBearLeg : lastBullLeg;
      if (!opposing || opposing.broken) continue;
      const level = opposing.firstOpen;
      const piercedBull = (d === 1 && c.c > level);
      const piercedBear = (d === -1 && c.c < level);
      if (!piercedBull && !piercedBear) continue;

      // Strict-mode filters: swing pivot at opposing leg's first candle +
      // displacement-grade body on the triggering candle.
      let isStrict = false;
      if (strict) {
        const pivotIdx = opposing.startIdx;
        // Right-side bars needed to confirm the pivot — if not yet present,
        // defer (don't emit yet; will re-evaluate on next frame via memo
        // invalidation when candles.length grows).
        if (pivotIdx + pivotWidth >= N) continue;
        const pivotOk = piercedBull ? isSwingLow(pivotIdx) : isSwingHigh(pivotIdx);
        if (!pivotOk) {
          // Pivot filter failed — consume the leg anyway so we don't
          // re-test it on every subsequent same-direction candle.
          opposing.broken = true;
          continue;
        }
        const range = c.h - c.l;
        const bodyRatio = range > 0 ? Math.abs(c.c - c.o) / range : 0;
        if (bodyRatio < minBodyRatio) {
          opposing.broken = true;
          continue;
        }
        isStrict = true;
      }

      // Determine when the line ends — first opposite-direction close past
      // the level, or expiry, whichever is first. Walk forward from i+1.
      let endIdx = Math.min(i + expiryBars, N - 1);
      for (let j = i + 1; j <= endIdx; j++) {
        const cj = this.candles[j];
        if (piercedBull && cj.c < level) { endIdx = j; break; }
        if (piercedBear && cj.c > level) { endIdx = j; break; }
      }

      events.push({
        i,
        kind: piercedBull ? 'bull' : 'bear',
        level,
        endIdx,
        isStrict,
      });
      opposing.broken = true;          // consume — no further CISD for this leg
    }
    return { events };
  }

  // ICT Fair Value Gap — 3-candle imbalance where candle[i-1] and candle[i+1]
  // don't overlap, leaving a price void around the middle (impulse) candle.
  //   Bullish: candle[i-1].h < candle[i+1].l  → gap [c[i-1].h, c[i+1].l]
  //   Bearish: candle[i-1].l > candle[i+1].h  → gap [c[i+1].h, c[i-1].l]
  // Mitigation = any subsequent candle's wick enters the gap. Strict mode
  // additionally requires the impulse candle's body / range >= minBodyRatio.
  _computeFvg(ind) {
    const N = this.candles.length;
    if (N < 3) return { gaps: [] };
    const p = (ind && typeof ind === 'object') ? (ind.params || {}) : {};
    const strict = (+p.strictMode === 1);
    const minBodyRatio = +p.minBodyRatio || 0.50;
    const extendBars = Math.max(1, (+p.extendBars || 30) | 0);

    const gaps = [];
    for (let i = 1; i < N - 1; i++) {
      const prev = this.candles[i - 1];
      const next = this.candles[i + 1];
      const mid = this.candles[i];
      let kind = null;
      let gapLow = 0;
      let gapHigh = 0;
      if (prev.h < next.l) {
        kind = 'bull';
        gapLow = prev.h;
        gapHigh = next.l;
      } else if (prev.l > next.h) {
        kind = 'bear';
        gapLow = next.h;
        gapHigh = prev.l;
      } else {
        continue;
      }
      if (strict) {
        const range = mid.h - mid.l;
        const bodyRatio = range > 0 ? Math.abs(mid.c - mid.o) / range : 0;
        if (bodyRatio < minBodyRatio) continue;
      }
      // Find mitigation — first candle after i+1 whose wick enters [gapLow,gapHigh].
      // Bullish gap is filled from above (a low touches/crosses gapHigh down to gapLow);
      // bearish from below (a high touches/crosses gapLow up to gapHigh). We treat
      // any wick intrusion as mitigation per the spec.
      let mitigatedAt = -1;
      const scanEnd = Math.min(N - 1, i + 1 + extendBars);
      for (let k = i + 2; k <= scanEnd; k++) {
        const ck = this.candles[k];
        if (kind === 'bull') {
          if (ck.l <= gapHigh) { mitigatedAt = k; break; }
        } else {
          if (ck.h >= gapLow) { mitigatedAt = k; break; }
        }
      }
      const endIdx = mitigatedAt >= 0 ? mitigatedAt : scanEnd;
      gaps.push({
        startIdx: i + 1,
        endIdx,
        kind,
        gapLow,
        gapHigh,
        mitigated: mitigatedAt >= 0,
      });
    }
    return { gaps };
  }

  // ICT/SMC Order Block — last opposing candle before an ATR-scaled impulse.
  // Walk forward; when candle i is a bullish impulse (close>open AND
  // abs(c-o)/ATR >= threshold), the OB is the most recent bearish candle
  // immediately preceding it (and vice-versa for bearish impulse). The
  // bearish/bullish RUN before the impulse is collapsed into one OB
  // (matches Lux/Inner-Circle implementations: the entire opposing leg's
  // extremes form the zone, not just the single touching bar).
  _computeOb(ind) {
    const N = this.candles.length;
    if (N < 3) return { blocks: [] };
    const p = (ind && typeof ind === 'object') ? (ind.params || {}) : {};
    const atrPeriod = Math.max(2, (+p.atrPeriod || 14) | 0);
    const threshold = +p.impulseThreshold || 1.5;
    const useBodyOnly = (+p.useBodyOnly === 0) ? false : true;
    const extendBars = Math.max(1, (+p.extendBars || 100) | 0);

    const atr = this._computeATR(atrPeriod);
    const blocks = [];
    for (let i = 1; i < N; i++) {
      const c = this.candles[i];
      const a = atr[i];
      if (a == null || a <= 0) continue;
      const body = Math.abs(c.c - c.o);
      if (body / a < threshold) continue;
      const impulseDir = c.c > c.o ? 1 : (c.c < c.o ? -1 : 0);
      if (impulseDir === 0) continue;
      // Walk back over the immediately-preceding opposing-direction run.
      const opposingDir = -impulseDir;
      let runStart = -1;
      let runEnd = -1;
      for (let k = i - 1; k >= 0; k--) {
        const ck = this.candles[k];
        const dk = ck.c > ck.o ? 1 : (ck.c < ck.o ? -1 : 0);
        if (dk === opposingDir) {
          if (runEnd < 0) runEnd = k;
          runStart = k;
          continue;
        }
        if (runEnd >= 0) break;        // run ended — stop scanning
        if (dk === 0) continue;         // skip dojis if no run yet
        break;                           // hit same-direction without finding a run
      }
      if (runStart < 0) continue;
      // Compute OB extremes across the run.
      let zoneHigh = -Infinity;
      let zoneLow = Infinity;
      for (let k = runStart; k <= runEnd; k++) {
        const ck = this.candles[k];
        if (useBodyOnly) {
          zoneHigh = Math.max(zoneHigh, ck.o, ck.c);
          zoneLow = Math.min(zoneLow, ck.o, ck.c);
        } else {
          zoneHigh = Math.max(zoneHigh, ck.h);
          zoneLow = Math.min(zoneLow, ck.l);
        }
      }
      // De-duplicate: if the previous OB shares the same run-end, skip
      // (chained impulses pointing at the same opposing leg shouldn't
      // emit multiple boxes).
      if (blocks.length > 0 && blocks[blocks.length - 1].sourceIdx === runEnd) {
        continue;
      }
      // Mitigation — for a bullish OB (zone below impulse), price re-enters
      // when a later candle's low crosses BELOW zoneHigh. Symmetric inverse
      // for bearish OBs.
      const kind = impulseDir === 1 ? 'bull' : 'bear';
      let mitigatedAt = -1;
      const scanEnd = Math.min(N - 1, i + extendBars);
      for (let k = i + 1; k <= scanEnd; k++) {
        const ck = this.candles[k];
        if (kind === 'bull') {
          if (ck.l <= zoneHigh) { mitigatedAt = k; break; }
        } else {
          if (ck.h >= zoneLow) { mitigatedAt = k; break; }
        }
      }
      const endIdx = mitigatedAt >= 0 ? mitigatedAt : scanEnd;
      blocks.push({
        sourceIdx: runEnd,
        impulseIdx: i,
        endIdx,
        kind,
        zoneHigh,
        zoneLow,
        mitigated: mitigatedAt >= 0,
      });
    }
    return { blocks };
  }

  // ICT Liquidity Sweep — a candle whose wick pierces a prior swing high/low
  // but whose close stays inside the swept level. Pivots are right-confirmed
  // fractals (need `pivotWidth` bars on the right before they're known); the
  // sweep itself happens any time after pivot confirmation. A pivot is
  // consumed by the first sweep so it doesn't keep emitting markers.
  _computeLiqSweep(ind) {
    const N = this.candles.length;
    if (N < 3) return { sweeps: [] };
    const p = (ind && typeof ind === 'object') ? (ind.params || {}) : {};
    const pivotWidth = Math.max(1, (+p.pivotWidth || 2) | 0);

    const isSwingHigh = (idx) => {
      const hi = this.candles[idx].h;
      for (let k = idx - pivotWidth; k <= idx + pivotWidth; k++) {
        if (k < 0 || k >= N || k === idx) continue;
        if (this.candles[k].h >= hi) return false;
      }
      return true;
    };
    const isSwingLow = (idx) => {
      const lo = this.candles[idx].l;
      for (let k = idx - pivotWidth; k <= idx + pivotWidth; k++) {
        if (k < 0 || k >= N || k === idx) continue;
        if (this.candles[k].l <= lo) return false;
      }
      return true;
    };

    const sweeps = [];
    const activeHighs = [];       // pivots awaiting a sweep; consumed once swept
    const activeLows = [];
    for (let i = 0; i < N; i++) {
      // Confirm pivots whose right side just completed.
      const confirmAt = i - pivotWidth;
      if (confirmAt >= pivotWidth) {
        if (isSwingHigh(confirmAt)) {
          activeHighs.push({ idx: confirmAt, level: this.candles[confirmAt].h });
        }
        if (isSwingLow(confirmAt)) {
          activeLows.push({ idx: confirmAt, level: this.candles[confirmAt].l });
        }
      }
      const c = this.candles[i];
      for (let k = activeHighs.length - 1; k >= 0; k--) {
        const pv = activeHighs[k];
        if (pv.idx >= i) continue;
        if (c.h > pv.level && c.c < pv.level) {
          sweeps.push({
            i, kind: 'bear', pivotIdx: pv.idx, level: pv.level,
          });
          activeHighs.splice(k, 1);
        }
      }
      for (let k = activeLows.length - 1; k >= 0; k--) {
        const pv = activeLows[k];
        if (pv.idx >= i) continue;
        if (c.l < pv.level && c.c > pv.level) {
          sweeps.push({
            i, kind: 'bull', pivotIdx: pv.idx, level: pv.level,
          });
          activeLows.splice(k, 1);
        }
      }
    }
    return { sweeps };
  }

  // ICT/SMC Market Structure — emit BOS / CHoCH / MSS labels when a candle
  // closes through the most-recent unbroken swing pivot. Current trend is
  // tracked across the pass: a same-direction break is BOS (continuation),
  // an opposite-direction break is CHoCH (and upgrades to MSS if the break
  // candle's body ratio clears `minBodyRatio`). A break also flips the
  // tracked trend so the NEXT opposite break is again a CHoCH/MSS.
  _computeMss(ind) {
    const N = this.candles.length;
    if (N < 5) return { events: [] };
    const p = (ind && typeof ind === 'object') ? (ind.params || {}) : {};
    const pivotWidth = Math.max(1, (+p.pivotWidth || 2) | 0);
    const minBodyRatio = +p.minBodyRatio || 0.65;

    const isSwingHigh = (idx) => {
      const hi = this.candles[idx].h;
      for (let k = idx - pivotWidth; k <= idx + pivotWidth; k++) {
        if (k < 0 || k >= N || k === idx) continue;
        if (this.candles[k].h >= hi) return false;
      }
      return true;
    };
    const isSwingLow = (idx) => {
      const lo = this.candles[idx].l;
      for (let k = idx - pivotWidth; k <= idx + pivotWidth; k++) {
        if (k < 0 || k >= N || k === idx) continue;
        if (this.candles[k].l <= lo) return false;
      }
      return true;
    };

    const events = [];
    const activeHighs = [];       // unbroken swing-high pivots
    const activeLows = [];
    let trend = 0;                // 1=bull, -1=bear, 0=undetermined
    for (let i = 0; i < N; i++) {
      const confirmAt = i - pivotWidth;
      if (confirmAt >= pivotWidth) {
        if (isSwingHigh(confirmAt)) {
          activeHighs.push({ idx: confirmAt, level: this.candles[confirmAt].h });
        }
        if (isSwingLow(confirmAt)) {
          activeLows.push({ idx: confirmAt, level: this.candles[confirmAt].l });
        }
      }
      const c = this.candles[i];
      const range = c.h - c.l;
      const bodyRatio = range > 0 ? Math.abs(c.c - c.o) / range : 0;

      // Bullish break — close above the most-recent unbroken swing high.
      // Walk newest-first; consume only the first one broken (pivots older
      // than the broken one stay active for chained breaks on later bars).
      for (let k = activeHighs.length - 1; k >= 0; k--) {
        const pv = activeHighs[k];
        if (pv.idx >= i) continue;
        if (c.c <= pv.level) continue;
        let label;
        if (trend === 1) {
          label = 'BOS';
        } else if (trend === -1) {
          label = bodyRatio >= minBodyRatio ? 'MSS' : 'CHoCH';
        } else {
          label = 'BOS';            // first-ever break — treat as continuation
        }
        events.push({
          i, kind: 'bull', label, pivotIdx: pv.idx, level: pv.level,
        });
        activeHighs.splice(k, 1);
        trend = 1;
        break;
      }
      // Bearish break — close below most-recent unbroken swing low.
      for (let k = activeLows.length - 1; k >= 0; k--) {
        const pv = activeLows[k];
        if (pv.idx >= i) continue;
        if (c.c >= pv.level) continue;
        let label;
        if (trend === -1) {
          label = 'BOS';
        } else if (trend === 1) {
          label = bodyRatio >= minBodyRatio ? 'MSS' : 'CHoCH';
        } else {
          label = 'BOS';
        }
        events.push({
          i, kind: 'bear', label, pivotIdx: pv.idx, level: pv.level,
        });
        activeLows.splice(k, 1);
        trend = -1;
        break;
      }
    }
    return { events };
  }

  // ----- Phase 8 — Renderers ----------------------------------------------
  // SMA / EMA draw as a single line on the candle pane. Each indicator gets
  // a small label chip at the latest data point so multiple SMAs at different
  // periods stay distinguishable.
  _drawIndicators(plot, lo, hi, priceToY) {
    if (this._indicators.length === 0 || this.candles.length === 0) return;
    // Phase 16 F2 — on Renko, indicators run on brick close-prices so that
    // they align with the rendered bricks instead of the underlying bar series.
    // We temporarily swap this.candles so that all internal compute helpers
    // (_computeSMA, _computeEMA, _computeRSI, …) and _visibleCandles() see the
    // brick-derived pseudo-candle array without any other code path being
    // affected (JS is single-threaded; no concurrent draw).
    const seriesBars = this.candleStyle === 'renko'
        ? this._renkoBricks.map((b) => ({
            c: b.closePrice, h: b.closePrice, l: b.closePrice,
            o: b.openPrice, ts: b.sourceBarTime, v: 0,
          }))
        : (this._isRebinnedStyle(this.candleStyle)
            && this._rebinnedStyle === this.candleStyle
            && this._rebinned.length > 0)
          // Phase 26 — rebinned styles already carry {o,h,l,c,v,ts}; run
          // indicators on those pseudo-candles so X aligns with the rebinned
          // series (same logic as the renko branch above).
          ? this._rebinned
          : this.candles;
    const _savedCandles = this.candles;
    this.candles = seriesBars;
    try {
      const visible = this._visibleCandles();
      if (visible.length === 0) return;
      const firstAbs = seriesBars.indexOf(visible[0]);
      const ctx = this.ctx;
      ctx.save();

      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind === 'bb') {
          const bands = this._computeBB(ind);
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
          // Right-axis value chips for all three bands so the user can read
          // the active BB envelope without crosshair-hovering.
          const lastIdx = firstAbs + visible.length - 1;
          this._drawIndicatorAxisChip(
              plot, priceToY, bands.upper[lastIdx], ind.color || '#8B5CF6');
          this._drawIndicatorAxisChip(
              plot, priceToY, bands.mid[lastIdx], ind.color || '#8B5CF6');
          this._drawIndicatorAxisChip(
              plot, priceToY, bands.lower[lastIdx], ind.color || '#8B5CF6');
          continue;
        }
        if (ind.kind === 'vwap') {
          const values = this._computeVWAP();
          ctx.strokeStyle = ind.color || '#06B6D4';
          // ind.thickness drives line width — fall back to 1.5 (pleasing
          // default on retina) when thickness is unset or equals 1.
          ctx.lineWidth = (ind.thickness && ind.thickness > 1) ? ind.thickness : 1.5;
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
          // Right-axis colored value chip — same pattern as the LTP chip,
          // matches the line's colour so the user can scan multiple lines.
          const last = values[firstAbs + visible.length - 1];
          this._drawIndicatorAxisChip(
              plot, priceToY, last, ind.color || '#06B6D4');
          continue;
        }
        // Sub-pane kinds are handled in _drawSubPanes — skip here.
        if (ind.kind === 'rsi' || ind.kind === 'macd' ||
            ind.kind === 'stoch' || ind.kind === 'atr' ||
            ind.kind === 'stochrsi' || ind.kind === 'squeeze' || ind.kind === 'efi') continue;
        if (ind.kind !== 'sma' && ind.kind !== 'ema') continue;
        const values = ind.kind === 'sma'
            ? this._computeSMA(ind.period)
            : this._computeEMA(ind.period);
        ctx.strokeStyle = ind.color || '#3B82F6';
        ctx.lineWidth = (ind.thickness && ind.thickness > 1) ? ind.thickness : 1.5;
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

        // Right-axis colored value chip showing the indicator's current
        // value, in its own colour. Replaces the old inline label that
        // floated next to the last candle — that info is already in the
        // chip strip at top.
        const lastAbs = firstAbs + visible.length - 1;
        this._drawIndicatorAxisChip(
            plot, priceToY, values[lastAbs], ind.color || '#3B82F6');
      }

      // Phase 20 — ZLEMA + McGinley render on candle pane like SMA/EMA.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'zlema' && ind.kind !== 'mcginley') continue;
        const values = ind.kind === 'zlema'
            ? this._computeZLEMA(ind.period)
            : this._computeMcGinley(ind.period);
        ctx.strokeStyle = ind.color || '#3B82F6';
        ctx.lineWidth = (ind.thickness && ind.thickness > 1) ? ind.thickness : 1.5;
        ctx.beginPath();
        let started = false;
        for (let i = 0; i < this.candles.length; i++) {
          const v = values[i];
          if (v == null || !isFinite(v) || v < lo || v > hi) {
            started = false;
            continue;
          }
          const x = this._candleXCenter(i, plot);
          const y = priceToY(v);
          if (!started) {
            ctx.moveTo(x, y);
            started = true;
          } else {
            ctx.lineTo(x, y);
          }
        }
        ctx.stroke();
        // Right-axis value chip for the most-recent visible value.
        let lastV = null;
        for (let i = this.candles.length - 1; i >= 0; i--) {
          const v = values[i];
          if (v != null && isFinite(v)) { lastV = v; break; }
        }
        this._drawIndicatorAxisChip(
            plot, priceToY, lastV, ind.color || '#3B82F6');
      }

      // Phase 22 — MA Ribbon: render 8 EMAs in a fading-color palette.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'ribbon') continue;
        const { periods, lines } = this._computeMaRibbon();
        const baseHue = 210; // blue family
        for (let li = 0; li < lines.length; li++) {
          const vals = lines[li];
          const lightness = 35 + li * 6; // 35..77
          this.ctx.strokeStyle = `hsl(${baseHue},70%,${lightness}%)`;
          this.ctx.lineWidth = 1;
          this.ctx.beginPath();
          let started = false;
          for (let i = 0; i < this.candles.length; i++) {
            const v = vals[i];
            if (v == null || !isFinite(v) || v < lo || v > hi) { started = false; continue; }
            const x = this._candleXCenter(i, plot);
            const y = priceToY(v);
            if (!started) { this.ctx.moveTo(x, y); started = true; }
            else this.ctx.lineTo(x, y);
          }
          this.ctx.stroke();
        }
        void periods;
      }

      // Phase 22 — Ichimoku Cloud: 5 lines + filled cloud between Senkou A/B.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'ichi') continue;
        const ic = this._computeIchimoku(ind);
        // Cloud fill
        this.ctx.save();
        this.ctx.beginPath();
        let firstX = null;
        for (let i = 0; i < ic.spanA.length; i++) {
          const a = ic.spanA[i], b = ic.spanB[i];
          if (a == null || b == null) continue;
          const x = this._candleXCenter(i, plot);
          if (firstX == null) { this.ctx.moveTo(x, priceToY(a)); firstX = x; }
          else this.ctx.lineTo(x, priceToY(a));
        }
        for (let i = ic.spanB.length - 1; i >= 0; i--) {
          const a = ic.spanA[i], b = ic.spanB[i];
          if (a == null || b == null) continue;
          const x = this._candleXCenter(i, plot);
          this.ctx.lineTo(x, priceToY(b));
        }
        this.ctx.closePath();
        this.ctx.fillStyle = 'rgba(34,197,94,0.10)';
        this.ctx.fill();
        this.ctx.restore();
        // Tenkan + Kijun + SpanA + SpanB lines
        const ichiSeries = [
          { vals: ic.tenkan, color: '#3B82F6', w: 1.25 },
          { vals: ic.kijun,  color: '#EF4444', w: 1.25 },
          { vals: ic.spanA,  color: '#10B981', w: 1   },
          { vals: ic.spanB,  color: '#F59E0B', w: 1   },
        ];
        for (const s of ichiSeries) {
          this.ctx.strokeStyle = s.color;
          this.ctx.lineWidth = s.w;
          this.ctx.beginPath();
          let started = false;
          for (let i = 0; i < s.vals.length; i++) {
            const v = s.vals[i];
            if (v == null || !isFinite(v)) { started = false; continue; }
            const x = this._candleXCenter(i, plot);
            const y = priceToY(v);
            if (!started) { this.ctx.moveTo(x, y); started = true; }
            else this.ctx.lineTo(x, y);
          }
          this.ctx.stroke();
        }
      }

      // Phase 22 — Volatility Stop: dotted line in current trend color.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'vstop') continue;
        const vs = this._computeVolStop(ind);
        this.ctx.save();
        this.ctx.setLineDash([2, 2]);
        this.ctx.lineWidth = 1.25;
        let prevDir = null;
        let started = false;
        this.ctx.beginPath();
        for (let i = 0; i < vs.stop.length; i++) {
          const v = vs.stop[i];
          const d = vs.dir[i];
          if (v == null || !isFinite(v)) { started = false; prevDir = d; continue; }
          if (d !== prevDir && started) {
            this.ctx.stroke();
            this.ctx.beginPath();
            started = false;
          }
          this.ctx.strokeStyle = d === 1 ? '#22C55E' : '#EF4444';
          const x = this._candleXCenter(i, plot);
          const y = priceToY(v);
          if (!started) { this.ctx.moveTo(x, y); started = true; }
          else this.ctx.lineTo(x, y);
          prevDir = d;
        }
        this.ctx.stroke();
        this.ctx.setLineDash([]);
        this.ctx.restore();
      }

      // CISD — body-close break of opposing delivery leg's first.open.
      // Per event we draw: (1) a colored horizontal line at the break
      // level spanning [event.i .. event.endIdx], and (2) in strict mode
      // a filled triangle marker at the triggering candle (▲ below for
      // bullish, ▼ above for bearish). Max-lines pruning keeps the most
      // recent N visible (older events dropped from render, kept in the
      // compute output so memoization stays stable across frames).
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'cisd') continue;
        const { events } = this._computeCisd(ind);
        if (!events || events.length === 0) continue;
        const p = (ind.params || {});
        const maxLines = Math.max(1, (+p.maxLines || 10) | 0);
        const bullColor = ind.color || '#22C55E';
        const bearColor = '#EF4444';
        const lineW = (ind.thickness && ind.thickness > 1) ? ind.thickness : 1.5;
        const visible = events.slice(-maxLines);
        for (const ev of visible) {
          const color = ev.kind === 'bull' ? bullColor : bearColor;
          const x1 = this._candleXCenter(ev.i, plot);
          const x2 = this._candleXCenter(ev.endIdx, plot);
          const y = priceToY(ev.level);
          ctx.save();
          ctx.strokeStyle = color;
          ctx.lineWidth = lineW;
          ctx.beginPath();
          ctx.moveTo(x1, y);
          ctx.lineTo(x2, y);
          ctx.stroke();
          // Strict-mode marker — small filled triangle at the event candle.
          // Bullish ▲ sits below the candle's low; bearish ▼ above the high.
          if (ev.isStrict) {
            const evC = this.candles[ev.i];
            const size = 5;
            const cx = this._candleXCenter(ev.i, plot);
            const lowY = priceToY(evC.l);
            const highY = priceToY(evC.h);
            ctx.fillStyle = color;
            ctx.beginPath();
            if (ev.kind === 'bull') {
              const ty = lowY + 8;
              ctx.moveTo(cx, ty);
              ctx.lineTo(cx - size, ty + size * 1.5);
              ctx.lineTo(cx + size, ty + size * 1.5);
            } else {
              const ty = highY - 8;
              ctx.moveTo(cx, ty);
              ctx.lineTo(cx - size, ty - size * 1.5);
              ctx.lineTo(cx + size, ty - size * 1.5);
            }
            ctx.closePath();
            ctx.fill();
          }
          ctx.restore();
        }
      }

      // FVG — translucent rect for each gap, faded outline if mitigated.
      // Box spans candle (startIdx) → mitigation candle (or extendBars cap).
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'fvg') continue;
        const { gaps } = this._computeFvg(ind);
        if (!gaps || gaps.length === 0) continue;
        const p = (ind.params || {});
        const maxBoxes = Math.max(1, (+p.maxBoxes || 20) | 0);
        const showMitigated = (+p.showMitigated === 0) ? false : true;
        const bullColor = ind.color || '#22C55E';
        const bearColor = '#EF4444';
        const visible = gaps.slice(-maxBoxes);
        for (const g of visible) {
          if (g.mitigated && !showMitigated) continue;
          const color = g.kind === 'bull' ? bullColor : bearColor;
          const x1 = this._candleXCenter(g.startIdx, plot);
          const x2 = this._candleXCenter(g.endIdx, plot);
          const yHi = priceToY(g.gapHigh);
          const yLo = priceToY(g.gapLow);
          const top = Math.min(yHi, yLo);
          const bot = Math.max(yHi, yLo);
          const left = Math.min(x1, x2);
          const width = Math.max(1, Math.abs(x2 - x1));
          const height = Math.max(1, bot - top);
          ctx.save();
          if (g.mitigated) {
            ctx.fillStyle = _hexToRgba(color, 0.05);
            ctx.fillRect(left, top, width, height);
            ctx.strokeStyle = _hexToRgba(color, 0.35);
            ctx.lineWidth = 1;
            // Mitigated: only draw the boundary line (gap edge that price
            // closed through first — bullish=top, bearish=bottom).
            ctx.beginPath();
            const edgeY = g.kind === 'bull' ? top : bot;
            ctx.moveTo(left, edgeY);
            ctx.lineTo(left + width, edgeY);
            ctx.stroke();
          } else {
            ctx.fillStyle = _hexToRgba(color, 0.15);
            ctx.fillRect(left, top, width, height);
            ctx.strokeStyle = _hexToRgba(color, 0.6);
            ctx.lineWidth = 1;
            ctx.strokeRect(left + 0.5, top + 0.5, width - 1, height - 1);
          }
          ctx.restore();
        }
      }

      // Order Blocks — translucent rectangle on the OB zone, "OB" label
      // near the right edge when the box is wide enough to host text.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'ob') continue;
        const { blocks } = this._computeOb(ind);
        if (!blocks || blocks.length === 0) continue;
        const p = (ind.params || {});
        const maxBoxes = Math.max(1, (+p.maxBoxes || 10) | 0);
        const showMitigated = (+p.showMitigated === 1);
        const bullColor = ind.color || '#22C55E';
        const bearColor = '#EF4444';
        const visible = blocks.slice(-maxBoxes);
        for (const b of visible) {
          if (b.mitigated && !showMitigated) continue;
          const color = b.kind === 'bull' ? bullColor : bearColor;
          const x1 = this._candleXCenter(b.sourceIdx, plot);
          const x2 = this._candleXCenter(b.endIdx, plot);
          const yHi = priceToY(b.zoneHigh);
          const yLo = priceToY(b.zoneLow);
          const top = Math.min(yHi, yLo);
          const bot = Math.max(yHi, yLo);
          const left = Math.min(x1, x2);
          const width = Math.max(1, Math.abs(x2 - x1));
          const height = Math.max(1, bot - top);
          ctx.save();
          const fillA = b.mitigated ? 0.05 : 0.15;
          const strokeA = b.mitigated ? 0.35 : 0.6;
          ctx.fillStyle = _hexToRgba(color, fillA);
          ctx.fillRect(left, top, width, height);
          ctx.strokeStyle = _hexToRgba(color, strokeA);
          ctx.lineWidth = 1;
          ctx.strokeRect(left + 0.5, top + 0.5, width - 1, height - 1);
          if (width > 50 && height >= 14) {
            ctx.font = '700 10px Geist, sans-serif';
            ctx.textAlign = 'right';
            ctx.textBaseline = 'middle';
            ctx.fillStyle = _hexToRgba(color, 0.9);
            ctx.fillText('OB', left + width - 4, top + height / 2);
          }
          ctx.restore();
        }
      }

      // Liquidity Sweep — triangle marker at the sweeping candle pointing
      // AT the swept pivot. Optional dashed line traces back to the pivot.
      // Bullish (low pivot swept) → triangle below candle low pointing down;
      // bearish (high pivot swept) → triangle above candle high pointing up.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'liqsweep') continue;
        const { sweeps } = this._computeLiqSweep(ind);
        if (!sweeps || sweeps.length === 0) continue;
        const p = (ind.params || {});
        const maxMarkers = Math.max(1, (+p.maxMarkers || 20) | 0);
        const showLine = (+p.showSweepLine === 0) ? false : true;
        const bullColor = ind.color || '#22C55E';
        const bearColor = '#EF4444';
        const visible = sweeps.slice(-maxMarkers);
        for (const sw of visible) {
          const color = sw.kind === 'bull' ? bullColor : bearColor;
          const cx = this._candleXCenter(sw.i, plot);
          const evC = this.candles[sw.i];
          const lowY = priceToY(evC.l);
          const highY = priceToY(evC.h);
          ctx.save();
          if (showLine) {
            const px = this._candleXCenter(sw.pivotIdx, plot);
            const py = priceToY(sw.level);
            ctx.strokeStyle = _hexToRgba(color, 0.55);
            ctx.lineWidth = 1;
            ctx.setLineDash([3, 3]);
            ctx.beginPath();
            ctx.moveTo(px, py);
            ctx.lineTo(cx, py);
            ctx.stroke();
            ctx.setLineDash([]);
          }
          const size = 5;
          ctx.fillStyle = color;
          ctx.beginPath();
          if (sw.kind === 'bull') {
            const ty = lowY + 8;
            ctx.moveTo(cx, ty + size * 1.5);
            ctx.lineTo(cx - size, ty);
            ctx.lineTo(cx + size, ty);
          } else {
            const ty = highY - 8;
            ctx.moveTo(cx, ty - size * 1.5);
            ctx.lineTo(cx - size, ty);
            ctx.lineTo(cx + size, ty);
          }
          ctx.closePath();
          ctx.fill();
          ctx.restore();
        }
      }

      // MSS / BOS / CHoCH — small text label at the break candle plus an
      // optional dashed level line from the broken pivot. MSS additionally
      // renders a filled triangle marker (high-conviction). Colour reflects
      // the break direction (green for bullish, red for bearish) which
      // matches the new prevailing trend.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'mss') continue;
        const { events } = this._computeMss(ind);
        if (!events || events.length === 0) continue;
        const p = (ind.params || {});
        const maxLabels = Math.max(1, (+p.maxLabels || 15) | 0);
        const showLine = (+p.showBreakLine === 0) ? false : true;
        const bullColor = ind.color || '#22C55E';
        const bearColor = '#EF4444';
        const visible = events.slice(-maxLabels);
        for (const ev of visible) {
          const color = ev.kind === 'bull' ? bullColor : bearColor;
          const cx = this._candleXCenter(ev.i, plot);
          const evC = this.candles[ev.i];
          const lowY = priceToY(evC.l);
          const highY = priceToY(evC.h);
          ctx.save();
          if (showLine) {
            const px = this._candleXCenter(ev.pivotIdx, plot);
            const py = priceToY(ev.level);
            ctx.strokeStyle = _hexToRgba(color, 0.6);
            ctx.lineWidth = 1;
            ctx.setLineDash([4, 3]);
            ctx.beginPath();
            ctx.moveTo(px, py);
            ctx.lineTo(cx, py);
            ctx.stroke();
            ctx.setLineDash([]);
          }
          const isMss = ev.label === 'MSS';
          const isBull = ev.kind === 'bull';
          ctx.font = (isMss ? '700 ' : '600 ') + '10px Geist, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = isBull ? 'bottom' : 'top';
          ctx.fillStyle = color;
          const textY = isBull ? highY - 14 : lowY + 14;
          ctx.fillText(ev.label, cx, textY);
          if (isMss) {
            const size = 4;
            const ty = isBull ? highY - 4 : lowY + 4;
            ctx.beginPath();
            if (isBull) {
              ctx.moveTo(cx, ty);
              ctx.lineTo(cx - size, ty + size * 1.4);
              ctx.lineTo(cx + size, ty + size * 1.4);
            } else {
              ctx.moveTo(cx, ty);
              ctx.lineTo(cx - size, ty - size * 1.4);
              ctx.lineTo(cx + size, ty - size * 1.4);
            }
            ctx.closePath();
            ctx.fill();
          }
          ctx.restore();
        }
      }

      // Phase 29 — WMA / HMA: single-line overlays like SMA/EMA.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'wma' && ind.kind !== 'hma') continue;
        const values = ind.kind === 'wma'
            ? this._computeWMA(ind.period)
            : this._computeHMA(ind.period);
        ctx.strokeStyle = ind.color || '#3B82F6';
        ctx.lineWidth = (ind.thickness && ind.thickness > 1) ? ind.thickness : 1.5;
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
        this._drawIndicatorAxisChip(
            plot, priceToY, values[firstAbs + visible.length - 1],
            ind.color || '#3B82F6');
      }

      // Phase 29 — Keltner / Donchian: 3-line channels (mid + upper + lower).
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'keltner' && ind.kind !== 'donchian') continue;
        const bands = ind.kind === 'keltner'
            ? this._computeKeltner(ind)
            : this._computeDonchian(ind);
        const col = ind.color || '#06B6D4';
        const drawSeries = (vals, w) => {
          ctx.strokeStyle = col;
          ctx.lineWidth = w;
          ctx.beginPath();
          let started = false;
          for (let i = 0; i < visible.length; i++) {
            const absIdx = firstAbs + i;
            const v = vals[absIdx];
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
        const last = firstAbs + visible.length - 1;
        this._drawIndicatorAxisChip(plot, priceToY, bands.upper[last], col);
        this._drawIndicatorAxisChip(plot, priceToY, bands.mid[last], col);
        this._drawIndicatorAxisChip(plot, priceToY, bands.lower[last], col);
      }

      // Phase 29 — SuperTrend: solid line in the current trend colour, flips
      // green↔red on the close cross (like Volatility Stop but solid).
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'supertrend') continue;
        const st = this._computeSuperTrend(ind);
        ctx.save();
        ctx.lineWidth = (ind.thickness && ind.thickness > 1) ? ind.thickness : 2;
        let prevDir = null;
        let started = false;
        ctx.beginPath();
        for (let i = 0; i < st.st.length; i++) {
          const v = st.st[i];
          const d = st.dir[i];
          if (v == null || !isFinite(v)) { started = false; prevDir = d; continue; }
          if (d !== prevDir && started) {
            ctx.stroke();
            ctx.beginPath();
            started = false;
          }
          ctx.strokeStyle = d === 1 ? '#22C55E' : '#EF4444';
          const x = this._candleXCenter(i, plot);
          const y = priceToY(v);
          if (!started) { ctx.moveTo(x, y); started = true; }
          else ctx.lineTo(x, y);
          prevDir = d;
        }
        ctx.stroke();
        ctx.restore();
      }

      // VWMA: single-line volume-weighted MA overlay (like SMA/EMA).
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'vwma') continue;
        const values = this._computeVWMA(ind.period || 20);
        ctx.strokeStyle = ind.color || '#F59E0B';
        ctx.lineWidth = (ind.thickness && ind.thickness > 1) ? ind.thickness : 1.5;
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
        this._drawIndicatorAxisChip(
            plot, priceToY, values[firstAbs + visible.length - 1],
            ind.color || '#F59E0B');
      }

      // Parabolic SAR: one trend-coloured dot per bar (green = SAR below
      // price / uptrend, red = SAR above price / downtrend).
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'psar') continue;
        const ps = this._computePSAR(ind);
        const sar = ps.sar, dir = ps.dir;
        for (let i = 0; i < visible.length; i++) {
          const absIdx = firstAbs + i;
          const v = sar[absIdx];
          if (v == null || !isFinite(v)) continue;
          ctx.fillStyle = dir[absIdx] === 1 ? '#22C55E' : '#EF4444';
          ctx.beginPath();
          ctx.arc(this._candleXCenter(absIdx, plot), priceToY(v), 1.6, 0, Math.PI * 2);
          ctx.fill();
        }
      }

      ctx.restore();
    } finally {
      // Always restore the real bar series — even if an exception is thrown
      // mid-loop. JS is single-threaded, but an uncaught error here would
      // otherwise leave this.candles pointing at the brick-derived pseudo-array
      // for every subsequent draw frame.
      this.candles = _savedCandles;
    }
  }

  // Scan-explanation overlays. Renders three things on top of the main
  // candle pane:
  //   1. Yellow matched-bar shading — contiguous runs of `matched[i]===true`
  //      become a single translucent rect spanning the price-panel y-range.
  //   2. Float-kind server indicator lines (e.g. SMA, EMA, Senkou A/B). One
  //      stroke per column, color from `column.color_hint` when supplied.
  //      Sub-panel-flagged indicators (RSI/MACD/etc.) are skipped for v1
  //      and surface only in the predicate panel — the main pane can't
  //      display values on the wrong price scale.
  //   3. Boolean-kind markers — small dots above the high of each bar where
  //      the indicator series is truthy AND the predicate matched, so e.g.
  //      "Hammer formed" puts a marker exactly at the hammer bar.
  //   4. Enum-kind background bands deferred — the predicate panel surfaces
  //      the regime label, which is enough signal for v1.
  _drawExplainOverlays(plot, lo, hi, priceToY) {
    if (!this._explainPayload || this.candles.length === 0) return;
    const visible = this._visibleCandles();
    if (visible.length === 0) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;

    const ctx = this.ctx;
    ctx.save();

    const matched = this._explainPayload.matched || [];
    const indicators = this._explainPayload.indicators || {};
    const columns = this._explainPayload.columns || [];

    // (1) Matched-bar shading. Walk the visible range; emit one rect per
    // contiguous run of trues. Half a cell of padding on either side so
    // adjacent matches visually merge instead of looking like a striped
    // pattern. Drawn on top of candles with 12% alpha so candles stay
    // legible — TradingView/StockEdge use a similar amber tint.
    {
      const cellW = this.view.cellW;
      const half = cellW / 2;
      ctx.fillStyle = 'rgba(245,158,11,0.16)';
      let runStartIdx = -1;
      for (let i = 0; i <= visible.length; i++) {
        const absIdx = firstAbs + i;
        const isMatched = i < visible.length && matched[absIdx] === true;
        if (isMatched && runStartIdx < 0) {
          runStartIdx = absIdx;
        } else if (!isMatched && runStartIdx >= 0) {
          const xStart = this._candleXCenter(runStartIdx, plot) - half;
          const xEnd = this._candleXCenter(absIdx - 1, plot) + half;
          ctx.fillRect(xStart, plot.top, xEnd - xStart, plot.bottom - plot.top);
          runStartIdx = -1;
        }
      }
    }

    // (2) Float-kind server indicator lines on the main pane. Skip any
    // column that setExplanationData reclassified as a sub-pane (either
    // because the server said so or because its values are off the
    // price scale — see the `subKeys` set built there).
    const defaultPalette = [
      '#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#06B6D4',
    ];
    const subKeys = (this._explainPayload && this._explainPayload.subKeys)
        ? this._explainPayload.subKeys
        : new Set();
    let paletteIdx = 0;
    for (const col of columns) {
      if (!col || col.kind !== 'float') continue;
      if (subKeys.has(col.key)) continue;
      const series = indicators[col.key];
      if (!Array.isArray(series)) continue;
      const color = (typeof col.color_hint === 'string' && col.color_hint)
          ? col.color_hint
          : defaultPalette[paletteIdx++ % defaultPalette.length];
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      let started = false;
      for (let i = 0; i < visible.length; i++) {
        const absIdx = firstAbs + i;
        const raw = series[absIdx];
        const v = (typeof raw === 'number' && isFinite(raw)) ? raw : null;
        if (v == null) { started = false; continue; }
        const x = this._candleXCenter(absIdx, plot);
        const y = priceToY(v);
        if (!started) { ctx.moveTo(x, y); started = true; }
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
    }

    // (2.5) Enum-kind regime ribbon — e.g. SuperTrend direction
    // (1=Up green, -1=Down red). Rendered as a thin strip at the bottom
    // of the main pane (line-style indicator) rather than a full-pane
    // background wash, so candles stay the dominant signal. Each
    // contiguous run of the same enum value becomes a solid colored
    // segment in the strip.
    const enumColors = (value) => {
      if (value === 1 || value === 1.0) return '#16A34A';   // green-600 (up)
      if (value === -1 || value === -1.0) return '#DC2626';   // red-600 (down)
      if (value === 0 || value === 0.0) return '#94A3B8';     // slate-400 (neutral)
      return null;
    };
    const cellW = this.view.cellW;
    const halfCell = cellW / 2;
    // Stack ribbons just above the bottom gutter — one row per enum
    // column, 6px tall + 2px gap. Newest at the very bottom so volume
    // bars (which overlay the price pane's bottom region) stay visible.
    let ribbonRowY = plot.bottom - 6;
    for (const col of columns) {
      if (!col || col.kind !== 'enum') continue;
      const series = indicators[col.key];
      if (!Array.isArray(series)) continue;
      let runStartIdx = -1;
      let runValue = null;
      const flushRun = (endAbsIdxExclusive) => {
        if (runStartIdx < 0) return;
        const fill = enumColors(runValue);
        if (fill) {
          const xStart = this._candleXCenter(runStartIdx, plot) - halfCell;
          const xEnd = this._candleXCenter(endAbsIdxExclusive - 1, plot) + halfCell;
          ctx.fillStyle = fill;
          ctx.fillRect(xStart, ribbonRowY, xEnd - xStart, 6);
        }
        runStartIdx = -1;
        runValue = null;
      };
      for (let i = 0; i <= visible.length; i++) {
        const absIdx = firstAbs + i;
        const v = (i < visible.length) ? series[absIdx] : null;
        if (v == null || !isFinite(v)) {
          flushRun(absIdx);
          continue;
        }
        if (runStartIdx < 0) {
          runStartIdx = absIdx;
          runValue = v;
        } else if (v !== runValue) {
          flushRun(absIdx);
          runStartIdx = absIdx;
          runValue = v;
        }
      }
      // Tiny label to the left of the ribbon so the user knows what
      // the colors mean. Drawn at low opacity so it doesn't compete.
      ctx.save();
      ctx.font = '600 9px Geist, sans-serif';
      ctx.fillStyle = this._withAlpha(this.palette.axisText, 0.85);
      ctx.textBaseline = 'middle';
      ctx.textAlign = 'left';
      ctx.fillText(col.label || col.key || '', plot.left + 4, ribbonRowY + 3);
      ctx.restore();
      ribbonRowY -= 8; // next ribbon stacks above this one (6 + 2 gap)
    }

    // (3) Boolean-kind markers — small dot above the bar high.
    for (const col of columns) {
      if (!col || col.kind !== 'boolean') continue;
      const series = indicators[col.key];
      if (!Array.isArray(series)) continue;
      const color = (typeof col.color_hint === 'string' && col.color_hint)
          ? col.color_hint
          : '#F59E0B';
      ctx.fillStyle = color;
      for (let i = 0; i < visible.length; i++) {
        const absIdx = firstAbs + i;
        const raw = series[absIdx];
        const isTrue = raw === true || raw === 1 || raw === 1.0;
        if (!isTrue) continue;
        const c = visible[i];
        const x = this._candleXCenter(absIdx, plot);
        const y = priceToY(c.h) - 6;
        ctx.beginPath();
        ctx.arc(x, y, 3, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    ctx.restore();
  }

  // Draws one explain-mode sub-pane (RSI / MACD-line / CCI / ADX etc.).
  // Values come from `this._explainPayload.indicators[sp.explainKey]` —
  // pre-computed by the server, NOT from a local `_computeXxx`. Reference
  // lines are added for the common bounded oscillators (RSI: 30/70,
  // unbounded: zero line if range crosses).
  _drawExplainSubPane(sp) {
    const ctx = this.ctx;
    if (this.candles.length === 0) return;
    if (!this._explainPayload || !this._explainPayload.indicators) return;
    const series = this._explainPayload.indicators[sp.explainKey];
    if (!Array.isArray(series)) return;
    const range = this._subPaneEffectiveRange(sp);
    if (!range) return;
    const [yMin, yMax] = range;
    if (yMax === yMin) return;
    const yFor = (v) => sp.top + (yMax - v) * sp.height / (yMax - yMin);

    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(sp.left, sp.top, sp.width, sp.height);

    // Reference lines — overbought/oversold for RSI/MFI/Stoch (30/70),
    // bull/bear for ADX (25), zero line when range crosses zero (CCI etc).
    const key = (sp.explainKey || '').toLowerCase();
    const refs = [];
    if (key.startsWith('rsi') || key.startsWith('mfi') ||
        key.startsWith('stoch_')) {
      refs.push(30, 70);
    } else if (key.startsWith('adx')) {
      refs.push(25);
    }
    if (yMin < 0 && yMax > 0) refs.push(0);
    ctx.strokeStyle = this.palette.axisText;
    ctx.lineWidth = 1;
    ctx.setLineDash([3, 3]);
    for (const lvl of refs) {
      if (lvl < yMin || lvl > yMax) continue;
      const y = yFor(lvl);
      ctx.beginPath();
      ctx.moveTo(sp.left, y);
      ctx.lineTo(sp.right, y);
      ctx.stroke();
    }
    ctx.setLineDash([]);

    // Main line trace.
    const visible = this._visibleCandles();
    if (visible.length === 0) { ctx.restore(); return; }
    const firstAbs = this.candles.indexOf(visible[0]);
    ctx.strokeStyle = sp.color || '#F59E0B';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const raw = series[absIdx];
      const v = (typeof raw === 'number' && isFinite(raw)) ? raw : null;
      if (v == null) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(v);
      if (!started) { ctx.moveTo(x, y); started = true; }
      else ctx.lineTo(x, y);
    }
    ctx.stroke();

    // Top-left label so the user sees what the panel is showing.
    ctx.font = '600 10px Geist, sans-serif';
    ctx.fillStyle = sp.color || '#F59E0B';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(sp.label || sp.explainKey || 'Indicator',
        sp.left + 4, sp.top + 8);
    ctx.restore();
  }

  _drawSubPanes(subPlots) {
    if (subPlots.length === 0) { this._lastSubPlots = []; return; }
    // Cache for hit-tests (mousedown / wheel / dblclick).
    this._lastSubPlots = subPlots;
    // Phase 16 F2 (Fix C) — on Renko, sub-pane renderers must see brick-derived
    // pseudo-candles in this.candles so that _visibleCandles(), _computeRSI(),
    // _computeMACD(), etc. all operate on brick prices rather than raw bar data.
    // Same swap pattern as _drawIndicators, wrapped in try/finally so an
    // exception during rendering never leaks the swapped array to later frames.
    const seriesBars = this.candleStyle === 'renko'
        ? this._renkoBricks.map((b) => ({
            c: b.closePrice, h: b.closePrice, l: b.closePrice,
            o: b.openPrice, ts: b.sourceBarTime, v: 0,
          }))
        : (this._isRebinnedStyle(this.candleStyle)
            && this._rebinnedStyle === this.candleStyle
            && this._rebinned.length > 0)
          ? this._rebinned   // Phase 26 — see _drawIndicators note above.
          : this.candles;
    const _savedCandles = this.candles;
    this.candles = seriesBars;
    try {
      for (const sp of subPlots) {
        // Resolve manual Y view (if user has panned/zoomed this sub-pane) and
        // stash on sp so per-kind drawers can pick it up instead of their
        // own auto-fit math.
        const view = this._subPaneView[sp.id];
        if (view && view.center != null && view.perPx != null) {
          const half = (sp.height / 2) * view.perPx;
          sp.viewMin = view.center - half;
          sp.viewMax = view.center + half;
        } else {
          sp.viewMin = null;
          sp.viewMax = null;
        }
        // Clip the renderer output to the sub-pane's vertical band so a
        // user-panned view doesn't bleed the indicator line into the
        // candle pane above or another sub-pane below. Width matches the
        // candle plot exactly (sp.left..sp.right) — the right gutter where
        // axis labels live is OUTSIDE this clip so they remain visible.
        this.ctx.save();
        this.ctx.beginPath();
        this.ctx.rect(sp.left, sp.top, sp.width, sp.height);
        this.ctx.clip();
        switch (sp.kind) {
          case 'rsi':      this._drawRsiInPane(sp); break;
          case 'macd':     this._drawMacdInPane(sp); break;
          case 'stoch':    this._drawStochInPane(sp); break;
          case 'atr':      this._drawAtrInPane(sp); break;
          case 'stochrsi': this._drawStochRsiInPane(sp); break;
          case 'squeeze':  this._drawSqueezeInPane(sp); break;
          case 'efi':      this._drawEfiInPane(sp); break;
          case 'wt':       this._drawWaveTrendInPane(sp); break;
          case 'crsi':     this._drawConnorsRSIInPane(sp); break;
          case 'ao':       this._drawAoInPane(sp); break;
          case 'mfi':      this._drawMfiInPane(sp); break;
          case 'obv':      this._drawObvInPane(sp); break;
          case 'cmf':      this._drawCmfInPane(sp); break;
          case 'wr':       this._drawWilliamsRInPane(sp); break;
          case 'cci':      this._drawCciInPane(sp); break;
          case 'roc':      this._drawRocInPane(sp); break;
          case 'cvd':      this._drawCvdInPane(sp); break;
          case 'adx':      this._drawAdxInPane(sp); break;
          case 'trix':     this._drawTrixInPane(sp); break;
          case 'vortex':   this._drawVortexInPane(sp); break;
          case 'uo':       this._drawUoInPane(sp); break;
          case 'dpo':      this._drawDpoInPane(sp); break;
          case 'pvt':      this._drawPvtInPane(sp); break;
          case 'ad':       this._drawAdInPane(sp); break;
          case 'explain':  this._drawExplainSubPane(sp); break;
        }
        this.ctx.restore();
        // Right-axis labels — bounded oscillators get their static range;
        // unbounded ones (MACD/ATR/AO/OBV/EFI/Squeeze/WaveTrend) compute
        // a window-fit range from their values. Manual view overrides both.
        const range = this._subPaneEffectiveRange(sp);
        if (range) {
          // Latest-value chip ALWAYS visible on the right axis (like the
          // main pane's LTP chip). Drawn first so its Y range is registered
          // in the slot ledger before min/mid/max axis labels paint and
          // pick a non-colliding Y for themselves.
          this._drawSubPaneCurrentValueChip(sp, range[0], range[1]);
          this._drawSubPaneAxis(sp, range[0], range[1]);
          // Hover overlays — vertical crosshair line through the sub-pane
          // and a coloured value chip on the right axis at the hovered
          // candle (in addition to the always-on latest-value chip).
          this._drawSubPaneHoverOverlay(sp, range[0], range[1]);
        }
      }
    } finally {
      this.candles = _savedCandles;
    }
  }

  // Returns the effective [min, max] for a sub-pane — manual override if the
  // user has panned/zoomed it, otherwise the auto-fit range from data.
  _subPaneEffectiveRange(sp) {
    if (sp.viewMin != null && sp.viewMax != null && sp.viewMax > sp.viewMin) {
      return [sp.viewMin, sp.viewMax];
    }
    return this._subPaneRange(sp);
  }

  // Snapshot a sub-pane's current auto-fit range into its manual view state.
  // Called on the first vertical pan/zoom so the gesture starts from the
  // user's current visual baseline instead of snapping to a different
  // default scale.
  _snapshotSubPaneViewToManual(sp) {
    const view = this._subPaneView[sp.id] ||
        (this._subPaneView[sp.id] = { center: null, perPx: null });
    if (view.center != null && view.perPx != null) return;
    const range = this._subPaneRange(sp);
    if (!range || !isFinite(range[0]) || !isFinite(range[1]) ||
        range[1] === range[0]) {
      // Fallback for indicators with no data yet — pick a unit scale around 0.
      view.center = 0;
      view.perPx = 1 / Math.max(1, sp.height);
      return;
    }
    view.center = (range[0] + range[1]) / 2;
    view.perPx = (range[1] - range[0]) / Math.max(1, sp.height);
  }

  // Vertical crosshair line + per-sub-pane right-axis value chip at the
  // hovered candle. Without this, the sub-pane's right axis stays static
  // (just min/mid/max labels) and gives no hover feedback.
  _drawSubPaneHoverOverlay(sp, minVal, maxVal) {
    if (!this.hover.inside || this.hover.x == null) return;
    if (this.candles.length === 0) return;
    const idx = this._candleAtX(this.hover.x);
    if (idx < 0 || idx >= this.candles.length) return;
    const ctx = this.ctx;
    ctx.save();
    // Vertical line — same dashed style as the main crosshair, gated by the
    // same showCrosshairLines toggle.
    if (this.showCrosshairLines) {
      const x = this._candleXCenter(idx, sp);
      ctx.strokeStyle = this.palette.crosshair;
      ctx.lineWidth = 1;
      ctx.setLineDash([4, 4]);
      ctx.beginPath();
      ctx.moveTo(x, sp.top);
      ctx.lineTo(x, sp.bottom);
      ctx.stroke();
      ctx.setLineDash([]);
    }
    // Value at hover candle. Compute per-kind so the chip shows the
    // indicator's actual value (RSI 64.2, MACD 8.5, etc.).
    const v = this._subPaneValueAt(sp, idx);
    if (v == null || !isFinite(v)) { ctx.restore(); return; }
    if (maxVal === minVal) { ctx.restore(); return; }
    // Map v into the sub-pane's Y axis.
    const t = (maxVal - v) / (maxVal - minVal);
    const yClamp = Math.max(sp.top + 8, Math.min(sp.bottom - 8,
        sp.top + t * sp.height));
    // Chip — coloured like the indicator's line/series.
    const text = (Math.abs(v) < 10) ? v.toFixed(2) : v.toFixed(1);
    ctx.font = '700 10px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';
    const tw = Math.min(72, ctx.measureText(text).width + 10);
    ctx.fillStyle = sp.color || this.palette.crosshairChip;
    this._roundedRect(sp.right + 2, yClamp - 8, tw, 16, 3);
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(text, sp.right + 2 + tw / 2, yClamp);
    ctx.restore();
  }

  // Returns the scalar value the sub-pane displays at the given candle
  // index, or null if the kind has no scalar (multi-series like MACD —
  // we use the MACD line for the hover chip, not signal/histogram).
  _subPaneValueAt(sp, idx) {
    const k = sp.kind;
    if (k === 'rsi')      return (this._computeRSI(sp.period) || [])[idx];
    if (k === 'mfi')      return (this._computeMFI(sp.period) || [])[idx];
    if (k === 'cmf')      return (this._computeCMF(sp.period) || [])[idx];
    if (k === 'wr')       return (this._computeWilliamsR(sp.period) || [])[idx];
    if (k === 'cci')      return (this._computeCCI(sp.period || 20) || [])[idx];
    if (k === 'roc')      return (this._computeROC(sp.period || 9) || [])[idx];
    if (k === 'cvd')      return (this._computeCVD() || [])[idx];
    if (k === 'adx')      return ((this._computeADX(sp.period || 14) || {}).adx || [])[idx];
    if (k === 'trix')     return (this._computeTRIX(sp.period || 15) || [])[idx];
    if (k === 'vortex')   return ((this._computeVortex(sp.period || 14) || {}).viPlus || [])[idx];
    if (k === 'uo')       return (this._computeUO() || [])[idx];
    if (k === 'dpo')      return (this._computeDPO(sp.period || 20) || [])[idx];
    if (k === 'pvt')      return (this._computePVT() || [])[idx];
    if (k === 'ad')       return (this._computeAD() || [])[idx];
    if (k === 'atr')      return (this._computeATR(sp.period) || [])[idx];
    if (k === 'ao')       return (this._computeAO() || [])[idx];
    if (k === 'obv')      return (this._computeOBV() || [])[idx];
    if (k === 'efi')      return (this._computeEFI(sp.period || 13) || [])[idx];
    if (k === 'crsi')     return (this._computeConnorsRSI(sp.period || 3) || [])[idx];
    if (k === 'stoch') {
      const v = this._computeStoch(sp);
      return v && v.k ? v.k[idx] : null;
    }
    if (k === 'stochrsi') {
      const v = this._computeStochRsi(sp);
      return v && v.k ? v.k[idx] : null;
    }
    if (k === 'macd') {
      const v = this._computeMACD(sp);
      return v && v.macd ? v.macd[idx] : null;
    }
    if (k === 'wt') {
      const v = this._computeWaveTrend(sp);
      const x = v ? v[idx] : null;
      return (x && x.wt1 != null) ? x.wt1 : null;
    }
    if (k === 'squeeze') {
      const v = this._computeSqueeze(sp);
      const x = v ? v[idx] : null;
      return (x && x.mom != null) ? x.mom : null;
    }
    if (k === 'explain') {
      // Server-supplied series; no local compute. Drives the latest-value
      // chip on the right gutter + the hover-crosshair value chip.
      const series = (this._explainPayload &&
          this._explainPayload.indicators)
          ? this._explainPayload.indicators[sp.explainKey]
          : null;
      if (!Array.isArray(series)) return null;
      const v = series[idx];
      return (typeof v === 'number' && isFinite(v)) ? v : null;
    }
    return null;
  }

  // Returns [min, max] for a sub-pane's value range, or null if we can't
  // compute one. Bounded oscillators: hard-coded. Unbounded: scan the
  // values the indicator just used.
  _subPaneRange(sp) {
    switch (sp.kind) {
      case 'rsi':
      case 'stochrsi':
      case 'stoch':
      case 'mfi':
      case 'crsi':
        return [0, 100];
      case 'wr':
        return [-100, 0];
      case 'cmf':
        return [-1, 1];
      case 'cci': {
        const v = this._computeCCI(sp.period || 20);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        return (isFinite(lo) && isFinite(hi)) ? [Math.min(lo, -100), Math.max(hi, 100)] : null;
      }
      case 'roc': {
        const v = this._computeROC(sp.period || 9);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        if (!isFinite(lo) || !isFinite(hi)) return null;
        const mag = Math.max(Math.abs(lo), Math.abs(hi)) || 1;
        return [-mag, mag];
      }
      case 'cvd': {
        const v = this._computeCVD();
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'adx': {
        const r = this._computeADX(sp.period || 14);
        let hi = 0;
        for (const arr of [r.adx, r.plusDI, r.minusDI]) {
          for (const x of arr) { if (x != null && isFinite(x) && x > hi) hi = x; }
        }
        return [0, Math.max(50, hi)];
      }
      case 'uo':
        return [0, 100];
      case 'trix': {
        const v = this._computeTRIX(sp.period || 15);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'dpo': {
        const v = this._computeDPO(sp.period || 20);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'pvt': {
        const v = this._computePVT();
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'ad': {
        const v = this._computeAD();
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'vortex': {
        const r = this._computeVortex(sp.period || 14);
        let lo = Infinity, hi = -Infinity;
        for (const arr of [r.viPlus, r.viMinus]) {
          for (const x of arr) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'wt':
        return [-100, 100];
      case 'macd': {
        const m = this._computeMACD(sp);
        if (!m) return null;
        let lo = Infinity, hi = -Infinity;
        for (const v of [...m.macd, ...m.signal, ...m.hist]) {
          if (v == null || !isFinite(v)) continue;
          if (v < lo) lo = v;
          if (v > hi) hi = v;
        }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'atr': {
        const v = this._computeATR(sp.period);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) {
          if (x == null || !isFinite(x)) continue;
          if (x < lo) lo = x;
          if (x > hi) hi = x;
        }
        return (isFinite(lo) && isFinite(hi)) ? [Math.min(0, lo), hi] : null;
      }
      case 'ao': {
        const v = this._computeAO();
        let lo = Infinity, hi = -Infinity;
        for (const x of v) {
          if (x == null || !isFinite(x)) continue;
          if (x < lo) lo = x;
          if (x > hi) hi = x;
        }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'obv': {
        const v = this._computeOBV();
        let lo = Infinity, hi = -Infinity;
        for (const x of v) {
          if (x == null || !isFinite(x)) continue;
          if (x < lo) lo = x;
          if (x > hi) hi = x;
        }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'efi': {
        const v = this._computeEFI(sp.period || 13);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) {
          if (x == null || !isFinite(x)) continue;
          if (x < lo) lo = x;
          if (x > hi) hi = x;
        }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'squeeze': {
        const v = this._computeSqueeze(sp);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) {
          if (!x || x.mom == null || !isFinite(x.mom)) continue;
          if (x.mom < lo) lo = x.mom;
          if (x.mom > hi) hi = x.mom;
        }
        if (!isFinite(lo) || !isFinite(hi)) return null;
        // Squeeze histogram pivots around 0 — make the axis symmetric so
        // positive and negative bars are visually balanced.
        const mag = Math.max(Math.abs(lo), Math.abs(hi));
        return [-mag, mag];
      }
      case 'explain': {
        // Bounded oscillators that the explain view commonly drives —
        // pin to canonical ranges so the panel scale matches what users
        // see on other platforms (TradingView, Sahi). Anything else
        // auto-fits to the visible data so the line uses the full panel.
        const key = (sp.explainKey || '').toString().toLowerCase();
        if (key.startsWith('rsi') || key.startsWith('stoch_') ||
            key.startsWith('mfi') || key.startsWith('cci') ||
            key.startsWith('roc') || key.startsWith('momentum_score') ||
            key.startsWith('adx')) {
          // 0..100 covers RSI/MFI/Stoch/ADX. CCI/ROC frequently exceed
          // 100 — fall through to auto-fit for those.
          if (key.startsWith('rsi') || key.startsWith('stoch_') ||
              key.startsWith('mfi') || key.startsWith('adx')) {
            return [0, 100];
          }
        }
        const series = (this._explainPayload &&
            this._explainPayload.indicators)
            ? this._explainPayload.indicators[sp.explainKey]
            : null;
        if (!Array.isArray(series)) return null;
        let lo = Infinity, hi = -Infinity;
        for (const v of series) {
          if (v == null || !isFinite(v)) continue;
          if (v < lo) lo = v;
          if (v > hi) hi = v;
        }
        if (!isFinite(lo) || !isFinite(hi) || lo === hi) return null;
        const pad = (hi - lo) * 0.10;
        return [lo - pad, hi + pad];
      }
      default:
        return null;
    }
  }

  // Sahi-style colored value chip rendered on the right price axis, in the
  // indicator's own colour. Same shape as the LTP chip — gives the user a
  // current-value readout without crosshair-hovering. Anti-collision: chip
  // is shifted up/down in 18px increments until it doesn't overlap any
  // previously-placed chip (LTP, countdown, other indicators) in the
  // `_axisChipSlots` registry. Without this, multiple MAs at close prices
  // (SMA + EMA = ~₹2 apart on a 5m chart) stack on top of each other.
  _drawIndicatorAxisChip(plot, priceToY, value, color) {
    if (value == null || !isFinite(value)) return;
    const ctx = this.ctx;
    const y = priceToY(value);
    if (y < plot.top - 6 || y > plot.bottom + 6) return;
    const chipH = 16;
    const slot = this._allocAxisChipSlot(y, chipH, plot.top + 8, plot.bottom - 8);
    if (slot == null) return;  // ran out of free space; drop silently
    const cy = slot;
    const text = value.toFixed(this._priceDecimals());
    ctx.save();
    ctx.font = '700 10px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';
    const tw = Math.min(72, ctx.measureText(text).width + 10);
    ctx.fillStyle = color;
    this._roundedRect(plot.right + 2, cy - 8, tw, chipH, 3);
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(text, plot.right + 2 + tw / 2, cy);
    ctx.restore();
  }

  // Reserves a non-overlapping Y slot on the right axis for a chip of the
  // given height centred near `wantY`. Returns the centre Y to render at,
  // or null if no slot fits within [topClamp, bottomClamp]. Tracks state in
  // `this._axisChipSlots` which `draw()` resets each frame.
  _allocAxisChipSlot(wantY, chipH, topClamp, bottomClamp) {
    if (!this._axisChipSlots) this._axisChipSlots = [];
    const half = chipH / 2;
    // Try increasing-distance offsets: 0, +18, -18, +36, -36, …
    for (let step = 0; step <= 8; step++) {
      for (const dir of (step === 0 ? [1] : [1, -1])) {
        const tryY = wantY + dir * step * (chipH + 2);
        if (tryY - half < topClamp || tryY + half > bottomClamp) continue;
        const top = tryY - half, bottom = tryY + half;
        let clash = false;
        for (const s of this._axisChipSlots) {
          if (!(bottom <= s.top || top >= s.bottom)) { clash = true; break; }
        }
        if (!clash) {
          this._axisChipSlots.push({ top, bottom });
          return tryY;
        }
      }
    }
    return null;
  }

  // Registers an externally-painted chip (LTP, countdown) into the slot
  // ledger so subsequent indicator chips know to dodge it.
  _registerAxisChipSlot(centreY, chipH) {
    if (!this._axisChipSlots) this._axisChipSlots = [];
    const half = chipH / 2;
    this._axisChipSlots.push({ top: centreY - half, bottom: centreY + half });
  }

  // Always-on right-axis chip showing the LATEST value of the sub-pane's
  // primary series. Colour-matched to the indicator. Painted before the
  // axis labels so its Y slot is reserved in `_axisChipSlots` and the
  // labels dodge it instead of overlapping.
  _drawSubPaneCurrentValueChip(sp, minVal, maxVal) {
    if (!isFinite(minVal) || !isFinite(maxVal) || maxVal === minVal) return;
    if (this.candles.length === 0) return;
    const lastIdx = this.candles.length - 1;
    const v = this._subPaneValueAt(sp, lastIdx);
    if (v == null || !isFinite(v)) return;
    const ctx = this.ctx;
    const t = (maxVal - v) / (maxVal - minVal);
    const wantY = sp.top + t * sp.height;
    const cy = this._allocAxisChipSlot(wantY, 16, sp.top + 8, sp.bottom - 8);
    if (cy == null) return;
    const text = (Math.abs(v) < 10) ? v.toFixed(2) : v.toFixed(1);
    ctx.save();
    ctx.font = '700 10px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';
    const tw = Math.min(72, ctx.measureText(text).width + 10);
    ctx.fillStyle = sp.color || this.palette.crosshairChip;
    this._roundedRect(sp.right + 2, cy - 8, tw, 16, 3);
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(text, sp.right + 2 + tw / 2, cy);
    ctx.restore();
  }

  // Generic right-axis labels for sub-panes. Draws max / mid / min labels in
  // the 60px gutter right of the sub-pane, matching the main price-axis
  // gutter so the eye lines up vertically. Bounded indicators pass an
  // explicit [min, max]; unbounded ones (MACD/ATR/AO/OBV/EFI/Squeeze/WT)
  // compute their own range from the visible values and pass that in.
  // Labels are skipped if they'd collide with a chip already in the
  // axis-slot ledger (latest-value chip, hover chip).
  _drawSubPaneAxis(sp, minVal, maxVal) {
    if (!isFinite(minVal) || !isFinite(maxVal) || maxVal === minVal) return;
    const ctx = this.ctx;
    ctx.save();
    ctx.font = '600 9px Geist, sans-serif';
    ctx.fillStyle = this.palette.axisText;
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    const labelX = sp.right + 4;
    const span = Math.abs(maxVal - minVal);
    let decimals = 0;
    if (span < 1) decimals = 4;
    else if (span < 10) decimals = 2;
    else if (span < 100) decimals = 1;
    const mid = (minVal + maxVal) / 2;
    const labels = [
      { val: maxVal, y: sp.top + 6 },
      { val: mid,    y: sp.top + sp.height / 2 },
      { val: minVal, y: sp.bottom - 6 },
    ];
    const slots = this._axisChipSlots || [];
    for (const lb of labels) {
      let covered = false;
      for (const s of slots) {
        if (lb.y >= s.top - 2 && lb.y <= s.bottom + 2) { covered = true; break; }
      }
      if (covered) continue;
      ctx.fillText(lb.val.toFixed(decimals), labelX, lb.y);
    }
    ctx.restore();
  }

  _drawRsiInPane(sp) {
    const ctx = this.ctx;
    if (this.candles.length === 0) return;
    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(sp.left, sp.top, sp.width, sp.height);
    const yMin = sp.viewMin != null ? sp.viewMin : 0;
    const yMax = sp.viewMax != null ? sp.viewMax : 100;
    const yFor = (v) => sp.top + (yMax - v) * sp.height / (yMax - yMin);
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
    const macdResult = this._computeMACD(sp);
    const { macd, signal, hist } = macdResult;
    const pp = macdResult.periods || { fast: 12, slow: 26, signal: 9 };
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
    if (sp.viewMin != null && sp.viewMax != null) { lo = sp.viewMin; hi = sp.viewMax; }
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
    ctx.fillText(`MACD ${pp.fast}/${pp.slow}/${pp.signal}`, sp.left + 4, sp.top + 8);
    ctx.restore();
  }

  _drawStochInPane(sp) {
    const ctx = this.ctx;
    if (this.candles.length === 0) return;
    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(sp.left, sp.top, sp.width, sp.height);
    const yMin = sp.viewMin != null ? sp.viewMin : 0;
    const yMax = sp.viewMax != null ? sp.viewMax : 100;
    const yFor = (v) => sp.top + (yMax - v) * sp.height / (yMax - yMin);
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
    const { k, d } = this._computeStoch(sp);
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
    {
      const sp_p = sp.params || {};
      const kP = +sp_p.kPeriod || sp.period || 14;
      const dP = +sp_p.dPeriod || 3;
      ctx.fillText(`STOCH ${kP}/${dP}`, sp.left + 4, sp.top + 8);
    }
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
    if (sp.viewMin != null && sp.viewMax != null) { lo = sp.viewMin; hi = sp.viewMax; }
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

  // Phase 20 — StochRSI sub-pane: %K (solid) + %D (dashed) bounded 0-100.
  _drawStochRsiInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeStochRsi(sp);
    const yMin = sp.viewMin != null ? sp.viewMin : 0;
    const yMax = sp.viewMax != null ? sp.viewMax : 100;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    // 80 / 20 reference lines.
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, yFor(80)); this.ctx.lineTo(sp.right, yFor(80));
    this.ctx.moveTo(sp.left, yFor(20)); this.ctx.lineTo(sp.right, yFor(20));
    this.ctx.stroke();
    // %K
    this.ctx.strokeStyle = sp.color || '#8B5CF6';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (!v || v.k == null || !isFinite(v.k)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(Math.max(0, Math.min(100, v.k)));
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    // %D
    this.ctx.strokeStyle = '#F59E0B';
    this.ctx.lineWidth = 1;
    this.ctx.setLineDash([3, 3]);
    this.ctx.beginPath();
    started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (!v || v.d == null || !isFinite(v.d)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(Math.max(0, Math.min(100, v.d)));
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.setLineDash([]);
    // Title label
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left';
    this.ctx.textBaseline = 'top';
    {
      const sp_p = sp.params || {};
      const rL = +sp_p.rsiLength || sp.period || 14;
      this.ctx.fillText('StochRSI ' + rL, sp.left + 4, sp.top + 2);
    }
  }

  // Phase 20 — Squeeze Momentum sub-pane: histogram of momentum + dot strip
  // for squeeze on/off at the zero baseline.
  _drawSqueezeInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeSqueeze(sp);
    // Find max |mom| in visible window for y-scaling — overridden by manual
    // view (which always renders symmetric around its center).
    let maxMom = 0;
    for (let i = 0; i < visible.length; i++) {
      const v = values[firstAbs + i];
      if (v && isFinite(v.mom) && Math.abs(v.mom) > maxMom) maxMom = Math.abs(v.mom);
    }
    if (maxMom <= 0) maxMom = 1;
    if (sp.viewMin != null && sp.viewMax != null) {
      maxMom = Math.max(Math.abs(sp.viewMin), Math.abs(sp.viewMax)) || 1;
    }
    const zeroY = sp.top + sp.height / 2;
    const bodyW = Math.max(1, this.view.cellW - 2);
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (!v) continue;
      const x = this._candleXCenter(absIdx, sp);
      const h = (v.mom / maxMom) * (sp.height / 2 - 2);
      const up = v.mom >= 0;
      // Momentum direction: rising or falling vs prev.
      const vPrev = values[absIdx - 1];
      const rising = vPrev && isFinite(vPrev.mom) ? v.mom > vPrev.mom : up;
      const color = up
          ? (rising ? '#22C55E' : '#86EFAC')
          : (rising ? '#FCA5A5' : '#EF4444');
      this.ctx.fillStyle = color;
      if (h >= 0) this.ctx.fillRect(Math.round(x - bodyW / 2), zeroY - h, bodyW, h);
      else this.ctx.fillRect(Math.round(x - bodyW / 2), zeroY, bodyW, -h);
      // Squeeze dot at zero line.
      this.ctx.fillStyle = v.squeezeOn ? '#EF4444' : '#3B82F6';
      this.ctx.beginPath();
      this.ctx.arc(x, zeroY, 1.5, 0, Math.PI * 2);
      this.ctx.fill();
    }
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, zeroY); this.ctx.lineTo(sp.right, zeroY);
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left';
    this.ctx.textBaseline = 'top';
    {
      const sp_p = sp.params || {};
      const bbL = +sp_p.bbLength || sp.period || 20;
      this.ctx.fillText('SQZ ' + bbL, sp.left + 4, sp.top + 2);
    }
  }

  // Phase 20 — Elder's Force Index sub-pane: signed histogram around zero.
  _drawEfiInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeEFI(sp.period || 13);
    let maxAbs = 0;
    for (let i = 0; i < visible.length; i++) {
      const v = values[firstAbs + i];
      if (v != null && isFinite(v) && Math.abs(v) > maxAbs) maxAbs = Math.abs(v);
    }
    if (maxAbs <= 0) maxAbs = 1;
    if (sp.viewMin != null && sp.viewMax != null) {
      maxAbs = Math.max(Math.abs(sp.viewMin), Math.abs(sp.viewMax)) || 1;
    }
    const zeroY = sp.top + sp.height / 2;
    const bodyW = Math.max(1, this.view.cellW - 2);
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) continue;
      const x = this._candleXCenter(absIdx, sp);
      const h = (v / maxAbs) * (sp.height / 2 - 2);
      this.ctx.fillStyle = v >= 0 ? '#22C55E' : '#EF4444';
      if (h >= 0) this.ctx.fillRect(Math.round(x - bodyW / 2), zeroY - h, bodyW, h);
      else this.ctx.fillRect(Math.round(x - bodyW / 2), zeroY, bodyW, -h);
    }
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, zeroY); this.ctx.lineTo(sp.right, zeroY);
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left';
    this.ctx.textBaseline = 'top';
    this.ctx.fillText('EFI ' + (sp.period || 13), sp.left + 4, sp.top + 2);
  }

  // Phase 22 — WaveTrend sub-pane: wt1 solid + wt2 dashed, 50/-50 reference lines.
  _drawWaveTrendInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeWaveTrend(sp);
    // Auto-scale Y to fit visible WT range.
    let lo = Infinity, hi = -Infinity;
    for (let i = 0; i < visible.length; i++) {
      const v = values[firstAbs + i];
      if (!v) continue;
      if (v.wt1 != null && isFinite(v.wt1)) { if (v.wt1 < lo) lo = v.wt1; if (v.wt1 > hi) hi = v.wt1; }
      if (v.wt2 != null && isFinite(v.wt2)) { if (v.wt2 < lo) lo = v.wt2; if (v.wt2 > hi) hi = v.wt2; }
    }
    if (!isFinite(lo) || !isFinite(hi) || lo === hi) { lo = -100; hi = 100; }
    const pad = (hi - lo) * 0.1;
    lo -= pad; hi += pad;
    if (sp.viewMin != null && sp.viewMax != null) { lo = sp.viewMin; hi = sp.viewMax; }
    const yFor = (v) => sp.top + sp.height - ((v - lo) / (hi - lo)) * sp.height;
    // 50 / -50 / 0 reference lines.
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, yFor(50)); this.ctx.lineTo(sp.right, yFor(50));
    this.ctx.moveTo(sp.left, yFor(-50)); this.ctx.lineTo(sp.right, yFor(-50));
    this.ctx.moveTo(sp.left, yFor(0)); this.ctx.lineTo(sp.right, yFor(0));
    this.ctx.stroke();
    // wt1
    this.ctx.strokeStyle = sp.color || '#3B82F6';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (!v || v.wt1 == null || !isFinite(v.wt1)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(v.wt1);
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    // wt2
    this.ctx.strokeStyle = '#F59E0B';
    this.ctx.lineWidth = 1;
    this.ctx.setLineDash([3, 3]);
    this.ctx.beginPath();
    started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (!v || v.wt2 == null || !isFinite(v.wt2)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(v.wt2);
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.setLineDash([]);
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    {
      const sp_p = sp.params || {};
      const cL = +sp_p.channelLength || sp.period || 10;
      this.ctx.fillText('WT ' + cL, sp.left + 4, sp.top + 2);
    }
  }

  // Phase 22 — Connors RSI sub-pane: single line bounded 0-100.
  _drawConnorsRSIInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeConnorsRSI(sp);
    const yMin = sp.viewMin != null ? sp.viewMin : 0;
    const yMax = sp.viewMax != null ? sp.viewMax : 100;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, yFor(70)); this.ctx.lineTo(sp.right, yFor(70));
    this.ctx.moveTo(sp.left, yFor(30)); this.ctx.lineTo(sp.right, yFor(30));
    this.ctx.stroke();
    this.ctx.strokeStyle = sp.color || '#8B5CF6';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(Math.max(0, Math.min(100, v)));
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    {
      const sp_p = sp.params || {};
      const rL = +sp_p.rsiLength || sp.period || 3;
      this.ctx.fillText('cRSI ' + rL, sp.left + 4, sp.top + 2);
    }
  }

  // ── Phase 25 — Compute helpers ────────────────────────────────────────────

  // Phase 25 — Awesome Oscillator: SMA(median, 5) - SMA(median, 34).
  // Returns histogram values (one per candle, null while warming).
  _computeAO() {
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < 34) return out;
    // Median price = (H + L) / 2
    const med = bars.map((b) => (b.h + b.l) / 2);
    for (let i = 33; i < bars.length; i++) {
      let s5 = 0, s34 = 0;
      for (let j = i - 4; j <= i; j++) s5 += med[j];
      for (let j = i - 33; j <= i; j++) s34 += med[j];
      out[i] = (s5 / 5) - (s34 / 34);
    }
    return out;
  }

  // Phase 25 — Money Flow Index: RSI-like 0-100 oscillator using
  // typical-price-weighted volume. Default period 14.
  _computeMFI(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < n + 1) return out;
    const tp = bars.map((b) => (b.h + b.l + b.c) / 3);
    for (let i = n; i < bars.length; i++) {
      let pos = 0, neg = 0;
      for (let j = i - n + 1; j <= i; j++) {
        const flow = tp[j] * (bars[j].v || 0);
        const prevTp = tp[j - 1];
        if (tp[j] > prevTp) pos += flow;
        else if (tp[j] < prevTp) neg += flow;
      }
      if (neg <= 0) { out[i] = 100; continue; }
      const ratio = pos / neg;
      out[i] = 100 - 100 / (1 + ratio);
    }
    return out;
  }

  // Phase 25 — On-Balance Volume: cumulative signed volume. Rising OBV with
  // price = healthy; divergence = caution.
  _computeOBV() {
    const bars = this.candles;
    const out = new Array(bars.length).fill(0);
    for (let i = 1; i < bars.length; i++) {
      const v = bars[i].v || 0;
      if (bars[i].c > bars[i - 1].c) out[i] = out[i - 1] + v;
      else if (bars[i].c < bars[i - 1].c) out[i] = out[i - 1] - v;
      else out[i] = out[i - 1];
    }
    return out;
  }

  // Phase 25 — Chaikin Money Flow: signed CLV-weighted volume / volume sum
  // over period. Range -1..+1.
  _computeCMF(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < n) return out;
    // CLV = ((C - L) - (H - C)) / (H - L)  if H != L else 0
    const mfv = bars.map((b) => {
      const r = b.h - b.l;
      if (r <= 0) return 0;
      const clv = ((b.c - b.l) - (b.h - b.c)) / r;
      return clv * (b.v || 0);
    });
    for (let i = n - 1; i < bars.length; i++) {
      let sumMfv = 0, sumV = 0;
      for (let j = i - n + 1; j <= i; j++) {
        sumMfv += mfv[j];
        sumV += (bars[j].v || 0);
      }
      out[i] = sumV > 0 ? sumMfv / sumV : 0;
    }
    return out;
  }

  // Phase 25 — Williams %R: 0 to -100 oscillator.
  // %R = (highestHigh(n) - close) / (highestHigh(n) - lowestLow(n)) * -100
  _computeWilliamsR(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < n) return out;
    for (let i = n - 1; i < bars.length; i++) {
      let hh = -Infinity, ll = Infinity;
      for (let j = i - n + 1; j <= i; j++) {
        if (bars[j].h > hh) hh = bars[j].h;
        if (bars[j].l < ll) ll = bars[j].l;
      }
      const r = hh - ll;
      out[i] = r > 0 ? ((hh - bars[i].c) / r) * -100 : -50;
    }
    return out;
  }

  // ── Phase 25 — Auto-pattern: swing pivot detection ────────────────────────

  // Phase 25 — find swing highs and lows in the candle series.
  // A swing high at index i = candles[i].h is the max of candles[i-N..i+N].
  // A swing low at index i = candles[i].l is the min of candles[i-N..i+N].
  // Returns an array of {idx, kind, price, label} sorted by idx, where
  // kind = 'H' (high) or 'L' (low), label = 'HH'/'HL'/'LH'/'LL' relative
  // to the previous swing of the SAME kind.
  _computeSwingPoints(window) {
    const N = Math.max(1, window | 0);
    const bars = this.candles;
    if (!bars || bars.length < N * 2 + 1) return [];
    const points = [];
    for (let i = N; i < bars.length - N; i++) {
      const c = bars[i];
      let isHigh = true;
      let isLow = true;
      for (let j = i - N; j <= i + N; j++) {
        if (j === i) continue;
        if (bars[j].h >= c.h) isHigh = false;
        if (bars[j].l <= c.l) isLow = false;
      }
      if (isHigh) {
        points.push({ idx: i, kind: 'H', price: c.h, label: '' });
      } else if (isLow) {
        points.push({ idx: i, kind: 'L', price: c.l, label: '' });
      }
    }
    // Label each point as HH/HL/LH/LL based on the previous same-kind point.
    let lastHigh = null;
    let lastLow = null;
    for (const p of points) {
      if (p.kind === 'H') {
        if (lastHigh != null) {
          p.label = p.price > lastHigh ? 'HH' : 'LH';
        }
        lastHigh = p.price;
      } else {
        if (lastLow != null) {
          p.label = p.price < lastLow ? 'LL' : 'HL';
        }
        lastLow = p.price;
      }
    }
    return points;
  }

  _drawAutoPattern(plot, lo, hi, priceToY) {
    if (!this.showAutoPattern) return;
    // 5-bar swing window — matches Bill Williams fractal convention used by
    // TradingView's "Fractals" / market-structure indicators. Smaller (3)
    // catches noise; larger (7+) misses meaningful swings on intraday TFs.
    const window = 5;
    const pts = this._computeSwingPoints(window);
    if (pts.length === 0) return;
    const ctx = this.ctx;
    ctx.save();
    ctx.font = '700 10px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';
    for (const p of pts) {
      // Skip the first pivot of each kind — it has no prior same-kind pivot
      // to compare against, so the empty label would render as a bare dot
      // with no context. Less informative than just omitting it.
      if (!p.label) continue;
      if (p.price < lo || p.price > hi) continue;
      const x = this._candleXCenter(p.idx, plot);
      const y = priceToY(p.price);
      const isHigh = p.kind === 'H';
      const color = isHigh ? (this.palette.bear || '#EF4444')
                           : (this.palette.bull || '#22C55E');

      // 1) Wick tick — a 2px short line at the exact pivot price so the
      // marker is anchored to the candle. Subtle, doesn't compete with
      // the label.
      ctx.strokeStyle = color;
      ctx.lineWidth = 2;
      ctx.beginPath();
      if (isHigh) {
        ctx.moveTo(x, y - 4);
        ctx.lineTo(x, y);
      } else {
        ctx.moveTo(x, y);
        ctx.lineTo(x, y + 4);
      }
      ctx.stroke();

      // 2) Solid colour pill — the indicator's bull/bear colour with
      // white bold text on top. No competing dark halo. Tiny vertical
      // gap from the wick tick so the label doesn't collide with the
      // candle body.
      const labelH = 16;
      const labelGap = 6;
      const ly = isHigh ? y - labelGap - labelH / 2
                        : y + labelGap + labelH / 2;
      const tw = Math.max(20, ctx.measureText(p.label).width + 8);
      const lx = x - tw / 2;
      const ltop = ly - labelH / 2;
      ctx.fillStyle = color;
      this._roundedRect(lx, ltop, tw, labelH, 4);
      ctx.fill();
      // Hairline darker border for definition on light backgrounds.
      ctx.strokeStyle = 'rgba(0,0,0,0.22)';
      ctx.lineWidth = 1;
      this._roundedRect(lx, ltop, tw, labelH, 4);
      ctx.stroke();
      ctx.fillStyle = '#FFFFFF';
      ctx.fillText(p.label, x, ly + 0.5);
    }
    ctx.restore();
  }

  // ── Phase 25 — Sub-pane renderers ─────────────────────────────────────────

  // Phase 25 — Awesome Oscillator: histogram of (SMA5 - SMA34) of median price.
  // Bar coloured green when rising vs prev, red when falling.
  _drawAoInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeAO();
    let maxAbs = 0;
    for (let i = 0; i < visible.length; i++) {
      const v = values[firstAbs + i];
      if (v != null && Math.abs(v) > maxAbs) maxAbs = Math.abs(v);
    }
    if (maxAbs <= 0) maxAbs = 1;
    if (sp.viewMin != null && sp.viewMax != null) {
      maxAbs = Math.max(Math.abs(sp.viewMin), Math.abs(sp.viewMax)) || 1;
    }
    const zeroY = sp.top + sp.height / 2;
    const bodyW = Math.max(1, this.view.cellW - 2);
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) continue;
      const prev = values[absIdx - 1];
      const rising = prev != null ? v > prev : v >= 0;
      this.ctx.fillStyle = rising ? '#22C55E' : '#EF4444';
      const x = this._candleXCenter(absIdx, sp);
      const h = (v / maxAbs) * (sp.height / 2 - 2);
      if (h >= 0) this.ctx.fillRect(Math.round(x - bodyW / 2), zeroY - h, bodyW, h);
      else this.ctx.fillRect(Math.round(x - bodyW / 2), zeroY, bodyW, -h);
    }
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, zeroY); this.ctx.lineTo(sp.right, zeroY);
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('AO', sp.left + 4, sp.top + 2);
  }

  // Phase 25 — Money Flow Index: 0-100 line in sub-pane with 80/20 reference.
  _drawMfiInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeMFI(sp.period || 14);
    const yMin = sp.viewMin != null ? sp.viewMin : 0;
    const yMax = sp.viewMax != null ? sp.viewMax : 100;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, yFor(80)); this.ctx.lineTo(sp.right, yFor(80));
    this.ctx.moveTo(sp.left, yFor(20)); this.ctx.lineTo(sp.right, yFor(20));
    this.ctx.stroke();
    this.ctx.strokeStyle = sp.color || '#06B6D4';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(Math.max(0, Math.min(100, v)));
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('MFI ' + (sp.period || 14), sp.left + 4, sp.top + 2);
  }

  // Phase 25 — OBV: cumulative signed volume. Auto-scaled line.
  _drawObvInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeOBV();
    let lo = Infinity, hi = -Infinity;
    for (let i = 0; i < visible.length; i++) {
      const v = values[firstAbs + i];
      if (v == null || !isFinite(v)) continue;
      if (v < lo) lo = v; if (v > hi) hi = v;
    }
    if (!isFinite(lo) || !isFinite(hi) || lo === hi) { lo = -1; hi = 1; }
    const pad = (hi - lo) * 0.1;
    lo -= pad; hi += pad;
    if (sp.viewMin != null && sp.viewMax != null) { lo = sp.viewMin; hi = sp.viewMax; }
    const yFor = (v) => sp.top + sp.height - ((v - lo) / (hi - lo)) * sp.height;
    this.ctx.strokeStyle = sp.color || '#84CC16';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(v);
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('OBV', sp.left + 4, sp.top + 2);
  }

  // Phase 25 — Chaikin Money Flow: -1..+1 line, zero reference.
  _drawCmfInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeCMF(sp.period || 20);
    // Default range [-1,1] symmetric; user manual view overrides.
    const yMin = sp.viewMin != null ? sp.viewMin : -1;
    const yMax = sp.viewMax != null ? sp.viewMax : 1;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, yFor(0)); this.ctx.lineTo(sp.right, yFor(0));
    this.ctx.stroke();
    this.ctx.strokeStyle = sp.color || '#A855F7';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(Math.max(-1, Math.min(1, v)));
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('CMF ' + (sp.period || 20), sp.left + 4, sp.top + 2);
  }

  // Phase 25 — Williams %R: -100..0 line, -20/-80 reference.
  _drawWilliamsRInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeWilliamsR(sp.period || 14);
    const yMin = sp.viewMin != null ? sp.viewMin : -100;
    const yMax = sp.viewMax != null ? sp.viewMax : 0;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, yFor(-20)); this.ctx.lineTo(sp.right, yFor(-20));
    this.ctx.moveTo(sp.left, yFor(-80)); this.ctx.lineTo(sp.right, yFor(-80));
    this.ctx.stroke();
    this.ctx.strokeStyle = sp.color || '#F59E0B';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(Math.max(-100, Math.min(0, v)));
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('%R ' + (sp.period || 14), sp.left + 4, sp.top + 2);
  }

  // ── Phase 29 — added indicators ──────────────────────────────────────────

  // Weighted moving average (linear weights n..1) over close.
  _computeWMA(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < n) return out;
    const denom = n * (n + 1) / 2;
    for (let i = n - 1; i < bars.length; i++) {
      let s = 0;
      for (let k = 0; k < n; k++) s += bars[i - k].c * (n - k);
      out[i] = s / denom;
    }
    return out;
  }

  // Generic linear-WMA over an arbitrary value array (used by HMA). Not
  // memoized (array arg) — callers are already memoized.
  _wmaArr(values, period) {
    const n = Math.max(1, period | 0);
    const out = new Array(values.length).fill(null);
    const denom = n * (n + 1) / 2;
    for (let i = n - 1; i < values.length; i++) {
      let s = 0, ok = true;
      for (let k = 0; k < n; k++) {
        const v = values[i - k];
        if (v == null || !isFinite(v)) { ok = false; break; }
        s += v * (n - k);
      }
      out[i] = ok ? s / denom : null;
    }
    return out;
  }

  // Hull MA: WMA(2·WMA(n/2) − WMA(n), √n).
  _computeHMA(period) {
    const n = Math.max(2, period | 0);
    const closes = this.candles.map((c) => c.c);
    const half = Math.max(1, Math.round(n / 2));
    const sq = Math.max(1, Math.round(Math.sqrt(n)));
    const w1 = this._wmaArr(closes, half);
    const w2 = this._wmaArr(closes, n);
    const raw = closes.map((_, i) =>
        (w1[i] != null && w2[i] != null) ? (2 * w1[i] - w2[i]) : null);
    return this._wmaArr(raw, sq);
  }

  // Keltner Channels: EMA mid ± mult·ATR.
  _computeKeltner(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const period = +p.length || +arg.period || 20;
    const mult = +p.mult || 2;
    const atrP = +p.atrLength || 10;
    const mid = this._computeEMA(period);
    const atr = this._computeATR(atrP);
    const N = this.candles.length;
    const upper = new Array(N).fill(null), lower = new Array(N).fill(null);
    for (let i = 0; i < N; i++) {
      if (mid[i] != null && atr[i] != null) {
        upper[i] = mid[i] + mult * atr[i];
        lower[i] = mid[i] - mult * atr[i];
      }
    }
    return { mid, upper, lower };
  }

  // Donchian Channels: rolling high / low / midline.
  _computeDonchian(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const period = +p.length || +arg.period || 20;
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const N = bars.length;
    const upper = new Array(N).fill(null), lower = new Array(N).fill(null), mid = new Array(N).fill(null);
    for (let i = n - 1; i < N; i++) {
      let hh = -Infinity, ll = Infinity;
      for (let j = i - n + 1; j <= i; j++) {
        if (bars[j].h > hh) hh = bars[j].h;
        if (bars[j].l < ll) ll = bars[j].l;
      }
      upper[i] = hh; lower[i] = ll; mid[i] = (hh + ll) / 2;
    }
    return { upper, lower, mid };
  }

  // SuperTrend: ATR-banded trend follower. Returns { st, dir } where
  // dir 1 = up (green), -1 = down (red); st is the active band level.
  _computeSuperTrend(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const period = +p.atrLength || +arg.period || 10;
    const mult = +p.mult || 3;
    const bars = this.candles;
    const N = bars.length;
    const atr = this._computeATR(period);
    const st = new Array(N).fill(null), dir = new Array(N).fill(null);
    let fu = null, fl = null, prevST = null, prevDir = 1;
    for (let i = 0; i < N; i++) {
      if (atr[i] == null) continue;
      const hl2 = (bars[i].h + bars[i].l) / 2;
      const bu = hl2 + mult * atr[i], bl = hl2 - mult * atr[i];
      const prevClose = i > 0 ? bars[i - 1].c : bars[i].c;
      const newFu = (fu == null) ? bu : ((bu < fu || prevClose > fu) ? bu : fu);
      const newFl = (fl == null) ? bl : ((bl > fl || prevClose < fl) ? bl : fl);
      const close = bars[i].c;
      let d, s;
      if (prevST == null) { d = close >= hl2 ? 1 : -1; s = d === 1 ? newFl : newFu; }
      else if (prevDir === 1) {
        if (close < newFl) { d = -1; s = newFu; } else { d = 1; s = newFl; }
      } else {
        if (close > newFu) { d = 1; s = newFl; } else { d = -1; s = newFu; }
      }
      fu = newFu; fl = newFl; prevST = s; prevDir = d;
      st[i] = s; dir[i] = d;
    }
    return { st, dir };
  }

  // Commodity Channel Index.
  _computeCCI(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < n) return out;
    const tp = bars.map((b) => (b.h + b.l + b.c) / 3);
    for (let i = n - 1; i < bars.length; i++) {
      let sum = 0;
      for (let j = i - n + 1; j <= i; j++) sum += tp[j];
      const sma = sum / n;
      let dev = 0;
      for (let j = i - n + 1; j <= i; j++) dev += Math.abs(tp[j] - sma);
      const mad = dev / n;
      out[i] = mad > 0 ? (tp[i] - sma) / (0.015 * mad) : 0;
    }
    return out;
  }

  // Rate of Change (%) vs the close `period` bars ago.
  _computeROC(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    for (let i = n; i < bars.length; i++) {
      const prev = bars[i - n].c;
      out[i] = prev !== 0 ? (bars[i].c / prev - 1) * 100 : null;
    }
    return out;
  }

  // Cumulative Volume Delta — signed by candle direction (no L2 tape).
  _computeCVD() {
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    let cum = 0;
    for (let i = 0; i < bars.length; i++) {
      const c = bars[i];
      const sgn = c.c > c.o ? 1 : c.c < c.o ? -1 : 0;
      cum += sgn * (c.v || 0);
      out[i] = cum;
    }
    return out;
  }

  // ADX / DMI (Wilder). Returns { adx, plusDI, minusDI }.
  _computeADX(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const len = bars.length;
    const adx = new Array(len).fill(null);
    const pdi = new Array(len).fill(null);
    const mdi = new Array(len).fill(null);
    if (len < 2 * n) return { adx, plusDI: pdi, minusDI: mdi };
    const tr = new Array(len).fill(0);
    const plusDM = new Array(len).fill(0);
    const minusDM = new Array(len).fill(0);
    for (let i = 1; i < len; i++) {
      const up = bars[i].h - bars[i - 1].h;
      const dn = bars[i - 1].l - bars[i].l;
      plusDM[i] = (up > dn && up > 0) ? up : 0;
      minusDM[i] = (dn > up && dn > 0) ? dn : 0;
      tr[i] = Math.max(
          bars[i].h - bars[i].l,
          Math.abs(bars[i].h - bars[i - 1].c),
          Math.abs(bars[i].l - bars[i - 1].c));
    }
    let trS = 0, pS = 0, mS = 0;
    for (let i = 1; i <= n; i++) { trS += tr[i]; pS += plusDM[i]; mS += minusDM[i]; }
    const dx = new Array(len).fill(null);
    for (let i = n; i < len; i++) {
      if (i > n) {
        trS = trS - trS / n + tr[i];
        pS = pS - pS / n + plusDM[i];
        mS = mS - mS / n + minusDM[i];
      }
      const pDI = trS > 0 ? 100 * pS / trS : 0;
      const mDI = trS > 0 ? 100 * mS / trS : 0;
      pdi[i] = pDI; mdi[i] = mDI;
      const sum = pDI + mDI;
      dx[i] = sum > 0 ? 100 * Math.abs(pDI - mDI) / sum : 0;
    }
    const adxStart = n + n - 1;
    if (adxStart < len) {
      let s = 0;
      for (let i = n; i <= adxStart; i++) s += dx[i] || 0;
      adx[adxStart] = s / n;
      for (let i = adxStart + 1; i < len; i++) {
        adx[i] = (adx[i - 1] * (n - 1) + (dx[i] || 0)) / n;
      }
    }
    return { adx, plusDI: pdi, minusDI: mdi };
  }

  // Shared single-line sub-pane renderer (background-less, mirrors %R style).
  _lineSubPane(sp, values, label, color, refLines) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    let yMin = sp.viewMin, yMax = sp.viewMax;
    if (yMin == null || yMax == null) {
      let lo = Infinity, hi = -Infinity;
      for (let i = 0; i < visible.length; i++) {
        const v = values[firstAbs + i];
        if (v != null && isFinite(v)) { if (v < lo) lo = v; if (v > hi) hi = v; }
      }
      if (!isFinite(lo) || !isFinite(hi)) return;
      const pad = (hi - lo) * 0.1 || 1;
      yMin = lo - pad; yMax = hi + pad;
    }
    if (yMax === yMin) yMax = yMin + 1;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    if (refLines && refLines.length) {
      this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
      this.ctx.lineWidth = 0.5;
      this.ctx.beginPath();
      for (const lv of refLines) {
        if (lv < yMin || lv > yMax) continue;
        const y = yFor(lv);
        this.ctx.moveTo(sp.left, y); this.ctx.lineTo(sp.right, y);
      }
      this.ctx.stroke();
    }
    this.ctx.strokeStyle = sp.color || color;
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const a = firstAbs + i;
      const v = values[a];
      if (v == null || !isFinite(v)) { started = false; continue; }
      const x = this._candleXCenter(a, sp);
      const y = yFor(v);
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText(label, sp.left + 4, sp.top + 2);
  }

  _drawCciInPane(sp) {
    const period = sp.period || 20;
    this._lineSubPane(sp, this._computeCCI(period), 'CCI ' + period, '#3B82F6', [-100, 0, 100]);
  }

  _drawRocInPane(sp) {
    const period = sp.period || 9;
    this._lineSubPane(sp, this._computeROC(period), 'ROC ' + period, '#A855F7', [0]);
  }

  _drawCvdInPane(sp) {
    this._lineSubPane(sp, this._computeCVD(), 'CVD', '#06B6D4', [0]);
  }

  _drawTrixInPane(sp) {
    const period = sp.period || 15;
    this._lineSubPane(sp, this._computeTRIX(period), 'TRIX ' + period, '#A855F7', [0]);
  }

  _drawUoInPane(sp) {
    this._lineSubPane(sp, this._computeUO(), 'UO', '#3B82F6', [30, 50, 70]);
  }

  _drawDpoInPane(sp) {
    const period = sp.period || 20;
    this._lineSubPane(sp, this._computeDPO(period), 'DPO ' + period, '#EAB308', [0]);
  }

  _drawPvtInPane(sp) {
    this._lineSubPane(sp, this._computePVT(), 'PVT', '#06B6D4', [0]);
  }

  _drawAdInPane(sp) {
    this._lineSubPane(sp, this._computeAD(), 'A/D', '#10B981', [0]);
  }

  _drawAdxInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const period = sp.period || 14;
    const r = this._computeADX(period);
    const yMin = 0;
    const yMax = (sp.viewMax != null && sp.viewMax > 0) ? sp.viewMax : 50;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    // Reference line at 25 (trend threshold).
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    const y25 = yFor(25);
    this.ctx.moveTo(sp.left, y25); this.ctx.lineTo(sp.right, y25);
    this.ctx.stroke();
    const series = [
      { vals: r.plusDI, col: '#22C55E' },
      { vals: r.minusDI, col: '#EF4444' },
      { vals: r.adx, col: sp.color || '#3B82F6' },
    ];
    for (const s of series) {
      this.ctx.strokeStyle = s.col;
      this.ctx.lineWidth = 1.2;
      this.ctx.beginPath();
      let started = false;
      for (let i = 0; i < visible.length; i++) {
        const a = firstAbs + i;
        const v = s.vals[a];
        if (v == null || !isFinite(v)) { started = false; continue; }
        const x = this._candleXCenter(a, sp);
        const y = yFor(Math.max(yMin, Math.min(yMax, v)));
        if (!started) { this.ctx.moveTo(x, y); started = true; }
        else this.ctx.lineTo(x, y);
      }
      this.ctx.stroke();
    }
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('ADX ' + period + '  +DI / -DI', sp.left + 4, sp.top + 2);
  }

  // Vortex Indicator — two lines (VI+ green, VI- red). Mirrors _drawAdxInPane.
  _drawVortexInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const period = sp.period || 14;
    const r = this._computeVortex(period);
    let yMin = sp.viewMin, yMax = sp.viewMax;
    if (yMin == null || yMax == null) {
      let lo = Infinity, hi = -Infinity;
      for (const arr of [r.viPlus, r.viMinus]) {
        for (let i = 0; i < visible.length; i++) {
          const v = arr[firstAbs + i];
          if (v != null && isFinite(v)) { if (v < lo) lo = v; if (v > hi) hi = v; }
        }
      }
      if (!isFinite(lo) || !isFinite(hi)) return;
      const pad = (hi - lo) * 0.1 || 0.1;
      yMin = lo - pad; yMax = hi + pad;
    }
    if (yMax === yMin) yMax = yMin + 1;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    const series = [
      { vals: r.viPlus, col: '#22C55E' },
      { vals: r.viMinus, col: '#EF4444' },
    ];
    for (const s of series) {
      this.ctx.strokeStyle = s.col;
      this.ctx.lineWidth = 1.2;
      this.ctx.beginPath();
      let started = false;
      for (let i = 0; i < visible.length; i++) {
        const a = firstAbs + i;
        const v = s.vals[a];
        if (v == null || !isFinite(v)) { started = false; continue; }
        const x = this._candleXCenter(a, sp);
        const y = yFor(v);
        if (!started) { this.ctx.moveTo(x, y); started = true; }
        else this.ctx.lineTo(x, y);
      }
      this.ctx.stroke();
    }
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('Vortex ' + period + '  VI+ / VI-', sp.left + 4, sp.top + 2);
  }

  // Volume-Weighted Moving Average: Σ(close·vol, n) / Σ(vol, n).
  _computeVWMA(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < n) return out;
    for (let i = n - 1; i < bars.length; i++) {
      let pv = 0, vv = 0;
      for (let k = 0; k < n; k++) {
        const b = bars[i - k];
        const v = b.v || 0;
        pv += b.c * v;
        vv += v;
      }
      out[i] = vv > 0 ? pv / vv : null;
    }
    return out;
  }

  // Parabolic SAR (classic Wilder). AF starts at `accel`, steps by `accel`
  // on each new extreme up to `maxAccel`, flips when price penetrates the
  // SAR. Returns { sar, dir } where dir 1 = SAR below price (uptrend).
  _computePSAR(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const accel = +p.accel || 0.02;
    const maxAccel = +p.maxAccel || 0.2;
    const bars = this.candles;
    const N = bars.length;
    const sar = new Array(N).fill(null);
    const dir = new Array(N).fill(null);
    if (N < 2) return { sar, dir };
    // Seed: assume uptrend, EP = first high, SAR = first low.
    let up = true;
    let af = accel;
    let ep = bars[0].h;
    let sarVal = bars[0].l;
    sar[0] = sarVal;
    dir[0] = 1;
    for (let i = 1; i < N; i++) {
      let next = sarVal + af * (ep - sarVal);
      if (up) {
        // SAR can't exceed prior two lows.
        next = Math.min(next, bars[i - 1].l, bars[i >= 2 ? i - 2 : i - 1].l);
        if (bars[i].l < next) {
          // Flip to downtrend.
          up = false;
          sarVal = ep;
          ep = bars[i].l;
          af = accel;
        } else {
          sarVal = next;
          if (bars[i].h > ep) { ep = bars[i].h; af = Math.min(maxAccel, af + accel); }
        }
      } else {
        next = Math.max(next, bars[i - 1].h, bars[i >= 2 ? i - 2 : i - 1].h);
        if (bars[i].h > next) {
          // Flip to uptrend.
          up = true;
          sarVal = ep;
          ep = bars[i].h;
          af = accel;
        } else {
          sarVal = next;
          if (bars[i].l < ep) { ep = bars[i].l; af = Math.min(maxAccel, af + accel); }
        }
      }
      sar[i] = sarVal;
      dir[i] = up ? 1 : -1;
    }
    return { sar, dir };
  }

  // TRIX: 100 · 1-bar %change of EMA(EMA(EMA(close, n), n), n).
  _computeTRIX(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const N = bars.length;
    const out = new Array(N).fill(null);
    const ema = (src) => {
      const res = new Array(N).fill(null);
      const k = 2 / (n + 1);
      let prev = null, seeded = -1;
      for (let i = 0; i < N; i++) {
        const v = src[i];
        if (v == null || !isFinite(v)) continue;
        if (prev == null) { prev = v; seeded = i; }
        else prev = v * k + prev * (1 - k);
        if (i - seeded >= n - 1) res[i] = prev;
      }
      return res;
    };
    const closes = bars.map((b) => b.c);
    const e3 = ema(ema(ema(closes)));
    for (let i = 1; i < N; i++) {
      const prev = e3[i - 1];
      if (e3[i] != null && prev != null && prev !== 0) {
        out[i] = (e3[i] / prev - 1) * 100;
      }
    }
    return out;
  }

  // Vortex Indicator. VI+ = Σ(VM+, n)/Σ(TR, n), VI- = Σ(VM-, n)/Σ(TR, n).
  _computeVortex(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const N = bars.length;
    const viPlus = new Array(N).fill(null);
    const viMinus = new Array(N).fill(null);
    if (N < n + 1) return { viPlus, viMinus };
    const vmP = new Array(N).fill(0);
    const vmM = new Array(N).fill(0);
    const tr = new Array(N).fill(0);
    for (let i = 1; i < N; i++) {
      vmP[i] = Math.abs(bars[i].h - bars[i - 1].l);
      vmM[i] = Math.abs(bars[i].l - bars[i - 1].h);
      tr[i] = Math.max(
          bars[i].h - bars[i].l,
          Math.abs(bars[i].h - bars[i - 1].c),
          Math.abs(bars[i].l - bars[i - 1].c));
    }
    for (let i = n; i < N; i++) {
      let sP = 0, sM = 0, sT = 0;
      for (let j = i - n + 1; j <= i; j++) { sP += vmP[j]; sM += vmM[j]; sT += tr[j]; }
      if (sT > 0) { viPlus[i] = sP / sT; viMinus[i] = sM / sT; }
    }
    return { viPlus, viMinus };
  }

  // Ultimate Oscillator (Larry Williams). Weighted 7/14/28 BP/TR sums.
  _computeUO() {
    const bars = this.candles;
    const N = bars.length;
    const out = new Array(N).fill(null);
    if (N < 29) return out;
    const bp = new Array(N).fill(0);
    const tr = new Array(N).fill(0);
    for (let i = 1; i < N; i++) {
      const prevC = bars[i - 1].c;
      const minLC = Math.min(bars[i].l, prevC);
      bp[i] = bars[i].c - minLC;
      tr[i] = Math.max(bars[i].h, prevC) - minLC;
    }
    const sum = (arr, i, len) => { let s = 0; for (let j = i - len + 1; j <= i; j++) s += arr[j]; return s; };
    for (let i = 28; i < N; i++) {
      const t7 = sum(tr, i, 7), t14 = sum(tr, i, 14), t28 = sum(tr, i, 28);
      if (t7 <= 0 || t14 <= 0 || t28 <= 0) continue;
      const a7 = sum(bp, i, 7) / t7;
      const a14 = sum(bp, i, 14) / t14;
      const a28 = sum(bp, i, 28) / t28;
      out[i] = 100 * (4 * a7 + 2 * a14 + a28) / 7;
    }
    return out;
  }

  // Detrended Price Oscillator: close[i-(n/2+1)] - SMA(close, n)[i].
  _computeDPO(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const N = bars.length;
    const out = new Array(N).fill(null);
    const sma = this._computeSMA(n);
    const shift = Math.floor(n / 2) + 1;
    for (let i = 0; i < N; i++) {
      const j = i - shift;
      if (j < 0 || sma[i] == null) continue;
      out[i] = bars[j].c - sma[i];
    }
    return out;
  }

  // Price Volume Trend: cumulative prevPVT + ((close-prevClose)/prevClose)·vol.
  _computePVT() {
    const bars = this.candles;
    const N = bars.length;
    const out = new Array(N).fill(null);
    if (N === 0) return out;
    let cum = 0;
    out[0] = 0;
    for (let i = 1; i < N; i++) {
      const prevC = bars[i - 1].c;
      if (prevC !== 0) cum += ((bars[i].c - prevC) / prevC) * (bars[i].v || 0);
      out[i] = cum;
    }
    return out;
  }

  // Accumulation/Distribution: cumulative MFV. Guards high==low (adds 0).
  _computeAD() {
    const bars = this.candles;
    const N = bars.length;
    const out = new Array(N).fill(null);
    let cum = 0;
    for (let i = 0; i < N; i++) {
      const h = bars[i].h, l = bars[i].l, c = bars[i].c;
      const range = h - l;
      if (range > 0) cum += (((c - l) - (h - c)) / range) * (bars[i].v || 0);
      out[i] = cum;
    }
    return out;
  }
}
for (const _k of Object.getOwnPropertyNames(_ChartIndicatorsMixin.prototype)) {
  if (_k !== 'constructor') Chart.prototype[_k] = _ChartIndicatorsMixin.prototype[_k];
}
