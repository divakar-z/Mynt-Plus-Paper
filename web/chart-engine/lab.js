'use strict';

// ---------------------------------------------------------------------------
// The Lab — experimental market-analysis math.
//
// Pure functions only. No DOM, no bridge, no chart state. Everything here
// takes plain arrays / candle objects ({o,h,l,c,v,ts}; ts in epoch SECONDS)
// and returns plain data the UI layer (topbar.js) renders. Keeping it pure
// makes the math testable and the three "tools" (Echoes / Oracle / Market
// Clock) independent of how the chart engine stores candles.
//
//   window.CandlLab = {
//     zNormalize, findSimilar, buildEchoScan,
//     buildOracle, targetOdds, computeMarketClock,
//   }
// ---------------------------------------------------------------------------

(function initCandlLab() {
  // ── z-normalisation ──────────────────────────────────────────────────────
  // (v - mean) / populationStd. A flat / degenerate window (std <= 0) or any
  // non-finite input collapses to all-zeros so downstream euclidean distance
  // stays finite and a dead-flat segment never "matches" everything.
  function zNormalize(values) {
    const n = values.length;
    const out = new Array(n).fill(0);
    if (n === 0) return out;
    let sum = 0;
    for (let i = 0; i < n; i++) {
      const v = values[i];
      if (!Number.isFinite(v)) return out.fill(0);
      sum += v;
    }
    const mean = sum / n;
    let varSum = 0;
    for (let i = 0; i < n; i++) {
      const d = values[i] - mean;
      varSum += d * d;
    }
    const std = Math.sqrt(varSum / n);
    if (!(std > 0) || !Number.isFinite(std)) return out.fill(0);
    for (let i = 0; i < n; i++) out[i] = (values[i] - mean) / std;
    return out;
  }

  // ── similarity search ────────────────────────────────────────────────────
  // Slide a query-length window across `haystackCloses` (stride 1). Distance
  // is the euclidean distance between the z-normalised query and each
  // z-normalised window. The query is normalised once; each window is
  // normalised on the fly from a rolling sum / sum-of-squares. Floating sums
  // drift over long series, so we recompute the window sums from scratch every
  // 1024 windows.
  //
  // Returns the best `k` matches, greedily: take the global best distance
  // first, then the next best whose START is at least `minGap` away from every
  // already-taken start, and so on. Windows whose END index lands inside the
  // last `excludeTail` indices are skipped (so we don't "find" the present
  // inside itself, or overlap the look-ahead horizon).
  function findSimilar(haystackCloses, query, opts) {
    opts = opts || {};
    const k = opts.k;
    const m = query.length;
    const minGap = (typeof opts.minGap === 'number') ? opts.minGap : m;
    const excludeTail = opts.excludeTail || 0;
    const N = haystackCloses.length;
    if (!(k >= 1) || m < 2) return [];

    const lastUsableEnd = N - 1 - excludeTail; // window END must be <= this
    const windowCount = N - m + 1;
    if (windowCount < 1 || lastUsableEnd < m - 1) return [];

    const zq = zNormalize(query);

    // Rolling sums for the current window [start, start+m).
    let sum = 0;
    let sumSq = 0;
    const recompute = (start) => {
      sum = 0; sumSq = 0;
      for (let i = start; i < start + m; i++) {
        const v = haystackCloses[i];
        sum += v;
        sumSq += v * v;
      }
    };

    const candidates = []; // {startIndex, endIndex, distance}
    for (let start = 0; start < windowCount; start++) {
      const end = start + m - 1;
      // Refresh sums every 1024 windows (and on the first), else roll.
      if (start === 0 || start % 1024 === 0) {
        recompute(start);
      } else {
        const out = haystackCloses[start - 1];
        const inc = haystackCloses[end];
        sum += inc - out;
        sumSq += inc * inc - out * out;
      }
      if (end > lastUsableEnd) continue;

      const mean = sum / m;
      const variance = sumSq / m - mean * mean;
      let dist;
      if (!(variance > 0) || !Number.isFinite(variance)) {
        dist = Infinity; // flat / degenerate window never wins
      } else {
        const std = Math.sqrt(variance);
        let acc = 0;
        let finite = true;
        for (let i = 0; i < m; i++) {
          const zw = (haystackCloses[start + i] - mean) / std;
          if (!Number.isFinite(zw)) { finite = false; break; }
          const d = zw - zq[i];
          acc += d * d;
        }
        dist = finite ? Math.sqrt(acc) : Infinity;
      }
      candidates.push({ startIndex: start, endIndex: end, distance: dist });
    }

    // Greedy best-first with the minGap separation constraint.
    candidates.sort((a, b) => a.distance - b.distance);
    const taken = [];
    for (const cand of candidates) {
      if (!Number.isFinite(cand.distance)) break; // rest are Infinity too
      let ok = true;
      for (const t of taken) {
        if (Math.abs(cand.startIndex - t.startIndex) < minGap) { ok = false; break; }
      }
      if (!ok) continue;
      taken.push(cand);
      if (taken.length >= k) break;
    }
    return taken;
  }

  // ── Echoes — historical analogue scan ────────────────────────────────────
  // "When the last `windowLen` bars looked like this before, what happened in
  // the next `horizon` bars?" Returns the matches + their forward returns plus
  // base-rate stats. NOT a forecast — a base rate over past analogues.
  function buildEchoScan(candles, windowLen, horizon, k) {
    if (windowLen < 2 || horizon < 1 || k < 1) return null;
    if (!candles || candles.length < windowLen * 3) return null;

    const closes = candles.map((c) => c.c);
    const query = closes.slice(closes.length - windowLen);

    const matches = findSimilar(closes, query, {
      k,
      minGap: windowLen,
      excludeTail: windowLen + horizon,
    });

    const results = [];
    for (const match of matches) {
      const end = match.endIndex;
      const base = closes[end];
      const aftermathPct = new Array(horizon).fill(null);
      for (let off = 1; off <= horizon; off++) {
        const idx = end + off;
        if (idx < closes.length) {
          aftermathPct[off - 1] = (closes[idx] / base - 1) * 100;
        }
      }
      results.push({
        match,
        matchTime: candles[end].ts,
        aftermathPct,
      });
    }

    // Stats over matches whose full aftermath exists (no nulls).
    const endPcts = [];
    for (const r of results) {
      const last = r.aftermathPct[horizon - 1];
      if (last !== null && Number.isFinite(last)) endPcts.push(last);
    }
    let stats;
    if (endPcts.length > 0) {
      const sorted = endPcts.slice().sort((a, b) => a - b);
      stats = {
        count: endPcts.length,
        upCount: endPcts.filter((p) => p > 0).length,
        medianEndPct: _median(sorted),
        bestEndPct: sorted[sorted.length - 1],
        worstEndPct: sorted[0],
        horizon,
      };
    } else {
      stats = {
        count: 0, upCount: 0, medianEndPct: 0,
        bestEndPct: 0, worstEndPct: 0, horizon,
      };
    }

    const q0 = query[0];
    const queryClosePct = query.map((v) => (v / q0 - 1) * 100);

    return { windowLen, horizon, results, stats, queryClosePct };
  }

  // ── Oracle — moving-block bootstrap projection ───────────────────────────
  // Resample the symbol's own close-to-close LOG returns in contiguous blocks
  // (preserving short-run autocorrelation) to simulate many plausible forward
  // paths. Returns the path matrix (flat Float32Array), per-offset percentile
  // bands, the median end %, and a thinned sample of full paths for drawing.
  function buildOracle(candles, horizon, nPaths, blockLen) {
    blockLen = (typeof blockLen === 'number') ? blockLen : 12;
    if (horizon < 1 || nPaths < 1 || blockLen < 1) return null;
    if (!candles || candles.length < 200) return null;

    // Close-to-close log returns over clean (finite, > 0) closes.
    const returns = [];
    let prev = null;
    for (let i = 0; i < candles.length; i++) {
      const c = candles[i].c;
      if (!Number.isFinite(c) || c <= 0) { prev = null; continue; }
      if (prev !== null) returns.push(Math.log(c / prev));
      prev = c;
    }
    const nReturns = returns.length;
    if (nReturns < blockLen) return null;

    const maxStart = nReturns - blockLen; // inclusive uniform range [0, maxStart]
    const pathsPct = new Float32Array(nPaths * horizon);
    for (let p = 0; p < nPaths; p++) {
      let cum = 0;          // cumulative log return
      let t = 0;            // offsets filled so far
      const base = p * horizon;
      while (t < horizon) {
        const start = Math.floor(Math.random() * (maxStart + 1));
        const blockEnd = Math.min(blockLen, horizon - t);
        for (let b = 0; b < blockEnd; b++) {
          cum += returns[start + b];
          pathsPct[base + t] = (Math.exp(cum) - 1) * 100;
          t++;
        }
      }
    }

    // Per-offset percentile bands. Sort each column once.
    const bandsPct = new Array(horizon);
    const col = new Float64Array(nPaths);
    for (let t = 0; t < horizon; t++) {
      for (let p = 0; p < nPaths; p++) col[p] = pathsPct[p * horizon + t];
      const sorted = Array.prototype.slice.call(col).sort((a, b) => a - b);
      bandsPct[t] = {
        p5: _percentile(sorted, 5),
        p25: _percentile(sorted, 25),
        p50: _percentile(sorted, 50),
        p75: _percentile(sorted, 75),
        p95: _percentile(sorted, 95),
      };
    }
    const medianEndPct = bandsPct[horizon - 1].p50;

    // ~120 evenly-strided full paths as number[][] for drawing.
    const sampleCount = Math.min(120, nPaths);
    const stride = Math.max(1, Math.floor(nPaths / sampleCount));
    const samplePathsPct = [];
    for (let p = 0; p < nPaths && samplePathsPct.length < sampleCount; p += stride) {
      const base = p * horizon;
      const path = new Array(horizon);
      for (let t = 0; t < horizon; t++) path[t] = pathsPct[base + t];
      samplePathsPct.push(path);
    }

    return { horizon, nPaths, pathsPct, bandsPct, medianEndPct, samplePathsPct };
  }

  // ── targetOdds — read odds off an Oracle result ──────────────────────────
  // endAbovePct: share of paths whose FINAL bar clears the target.
  // touchPct: share of paths that reach the target at ANY offset (>= for a
  // positive target, <= for a negative one).
  function targetOdds(result, targetPct) {
    if (!result || !result.pathsPct || !(result.nPaths >= 1)) {
      return { endAbovePct: 0, touchPct: 0 };
    }
    const { pathsPct, nPaths, horizon } = result;
    const up = targetPct >= 0;
    let endAbove = 0;
    let touched = 0;
    for (let p = 0; p < nPaths; p++) {
      const base = p * horizon;
      const endVal = pathsPct[base + horizon - 1];
      if (up ? endVal >= targetPct : endVal <= targetPct) endAbove++;
      let hit = false;
      for (let t = 0; t < horizon; t++) {
        const v = pathsPct[base + t];
        if (up ? v >= targetPct : v <= targetPct) { hit = true; break; }
      }
      if (hit) touched++;
    }
    return {
      endAbovePct: (endAbove / nPaths) * 100,
      touchPct: (touched / nPaths) * 100,
    };
  }

  // ── Market Clock — when does this symbol move? ────────────────────────────
  // Bucket every candle by UTC hour (0-23) and UTC weekday (0=Sun) and report
  // the average bar magnitude / direction / volume per bucket. ts is in
  // SECONDS, so ×1000 before constructing the Date.
  function computeMarketClock(candles) {
    const mkBuckets = (n) => {
      const arr = new Array(n);
      for (let i = 0; i < n; i++) {
        arr[i] = { _absSum: 0, _retSum: 0, _volSum: 0, samples: 0 };
      }
      return arr;
    };
    const byHourUtc = mkBuckets(24);
    const byWeekdayUtc = mkBuckets(7);

    let candleCount = 0;
    let fromTime = null;
    let toTime = null;

    for (const c of candles) {
      const o = c.o, cl = c.c, v = c.v, ts = c.ts;
      if (!Number.isFinite(o) || !Number.isFinite(cl) || !Number.isFinite(v)) continue;
      if (o === 0) continue;
      const ret = (cl / o - 1) * 100;
      if (!Number.isFinite(ret)) continue;
      const d = new Date(ts * 1000);
      // Local time — the clock is for "when does this market move for ME".
      const h = d.getHours();
      const wd = d.getDay();

      const hb = byHourUtc[h];
      hb._absSum += Math.abs(ret); hb._retSum += ret; hb._volSum += v; hb.samples++;
      const wb = byWeekdayUtc[wd];
      wb._absSum += Math.abs(ret); wb._retSum += ret; wb._volSum += v; wb.samples++;

      candleCount++;
      if (fromTime === null || ts < fromTime) fromTime = ts;
      if (toTime === null || ts > toTime) toTime = ts;
    }

    const finalize = (arr) => arr.map((b) => ({
      meanAbsReturnPct: b.samples > 0 ? b._absSum / b.samples : 0,
      meanReturnPct: b.samples > 0 ? b._retSum / b.samples : 0,
      meanVolume: b.samples > 0 ? b._volSum / b.samples : 0,
      samples: b.samples,
    }));

    return {
      byHourUtc: finalize(byHourUtc),
      byWeekdayUtc: finalize(byWeekdayUtc),
      candleCount,
      fromTime,
      toTime,
    };
  }

  // ── shared helpers ────────────────────────────────────────────────────────
  function _median(sorted) {
    const n = sorted.length;
    if (n === 0) return 0;
    const mid = n >> 1;
    return (n % 2 === 1) ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  // Type-7 (Excel / R default) percentile with linear interpolation. `sorted`
  // must already be ascending. `p` is 0-100.
  function _percentile(sorted, p) {
    const n = sorted.length;
    if (n === 0) return 0;
    if (n === 1) return sorted[0];
    const rank = (p / 100) * (n - 1);
    const lo = Math.floor(rank);
    const hi = Math.ceil(rank);
    if (lo === hi) return sorted[lo];
    const frac = rank - lo;
    return sorted[lo] + (sorted[hi] - sorted[lo]) * frac;
  }

  window.CandlLab = {
    zNormalize,
    findSimilar,
    buildEchoScan,
    buildOracle,
    targetOdds,
    computeMarketClock,
  };
})();
