'use strict';

// ---------------------------------------------------------------------------
// Aggregator — pure functions for rolling source candles + live ticks into
// target-timeframe candles.
//
// Source intervals expected from tpseries:
//   '1'  → 1-minute candles (used for any target < 60 minutes)
//   '5'  → 5-minute candles (used for 60 ≤ target < 1440 minutes)
//   '1D' → daily candles    (used for target ≥ 1440 minutes)
//
// Target minutes is whatever integer the user picked, including custom
// values like 7m, 45m, 90m.
// ---------------------------------------------------------------------------

const SOURCE_INTERVAL_FOR_MINUTES = (mins) => {
  if (mins < 60) return '1';
  if (mins < 1440) return '5';
  return '1D';
};

/**
 * Bucket source candles into target candles.
 * @param {Array<{ts:number,o:number,h:number,l:number,c:number,v:number}>} src
 *        Source candles in chronological order. `ts` is unix epoch SECONDS.
 * @param {number} targetMinutes
 * @returns {Array<{ts:number,o:number,h:number,l:number,c:number,v:number}>}
 *        Target candles in chronological order. `ts` is the bucket start
 *        unix epoch seconds.
 */
function bucketCandles(src, targetMinutes, exch) {
  if (!Array.isArray(src) || src.length === 0) return [];
  // Daily, weekly, monthly use calendar-aware bucketing (IST). Intraday anchors
  // each bucket to the exchange's SESSION OPEN (NSE 09:15 / MCX 09:00), not the
  // UTC epoch — otherwise a 1h bucket lands on the UTC hour (08:30 IST) instead
  // of the session open.
  if (targetMinutes >= 1440) {
    return _bucketCalendar(src, targetMinutes);
  }
  const targetSec = targetMinutes * 60;
  const openMin = _sessionOpenMinFor(exch);
  const out = [];
  let cur = null;
  for (const c of src) {
    const bucket = _intradayBucketStart(c.ts, targetSec, openMin);
    if (!cur || cur.ts !== bucket) {
      if (cur) out.push(cur);
      cur = { ts: bucket, o: c.o, h: c.h, l: c.l, c: c.c, v: c.v };
    } else {
      if (c.h > cur.h) cur.h = c.h;
      if (c.l < cur.l) cur.l = c.l;
      cur.c = c.c;
      cur.v += c.v;
    }
  }
  if (cur) out.push(cur);
  return out;
}

function _bucketCalendar(src, targetMinutes) {
  // 1440 = daily, 10080 = weekly (7d), 43200 = monthly (~30d).
  // For weekly we anchor to Monday in IST. For monthly we anchor to the
  // 1st of the month in IST.
  if (targetMinutes === 1440) {
    // Daily — assume source is 1D from tpseries; passthrough.
    return src.map((c) => ({ ts: c.ts, o: c.o, h: c.h, l: c.l, c: c.c, v: c.v }));
  }
  const out = [];
  let cur = null;
  for (const c of src) {
    const bucket = _calendarBucketStart(c.ts, targetMinutes);
    if (!cur || cur.ts !== bucket) {
      if (cur) out.push(cur);
      cur = { ts: bucket, o: c.o, h: c.h, l: c.l, c: c.c, v: c.v };
    } else {
      if (c.h > cur.h) cur.h = c.h;
      if (c.l < cur.l) cur.l = c.l;
      cur.c = c.c;
      cur.v += c.v;
    }
  }
  if (cur) out.push(cur);
  return out;
}

// IST = UTC+05:30 = +19800 seconds.
const IST_OFFSET = 5.5 * 3600;
function _weekStartIst(ts) {
  // Convert to IST, find Monday, convert back to UTC seconds.
  const istSec = ts + IST_OFFSET;
  const d = new Date(istSec * 1000);
  // getUTCDay: 0=Sun … 6=Sat. We want Monday=0, so daysSinceMonday = (day+6)%7.
  const daysSinceMonday = (d.getUTCDay() + 6) % 7;
  const istMidnight = istSec - (d.getUTCHours() * 3600 + d.getUTCMinutes() * 60 + d.getUTCSeconds());
  const istMondayMidnight = istMidnight - daysSinceMonday * 86400;
  return istMondayMidnight - IST_OFFSET;
}
function _monthStartIst(ts) {
  const istSec = ts + IST_OFFSET;
  const d = new Date(istSec * 1000);
  const istMonthStart = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1) / 1000;
  return istMonthStart - IST_OFFSET;
}

// Bucket start for a daily-or-longer timeframe — the ONE rule shared by the
// history (_bucketCalendar) and live ticks (ingestTickIntoBucket), so a tick
// always lands in the bar the history built. Week = Monday 00:00 IST, month =
// the 1st 00:00 IST, anything else (daily) = whole multiples from the epoch;
// daily EOD bars are stamped 00:00 UTC (05:30 IST), which this keeps.
// Live ticks used plain epoch multiples for weeks and months too: epoch weeks
// start on Thursdays and 30-day blocks on arbitrary dates, so today's ticks
// opened a second bar ("8 Oct" next to the week of 5 Oct, "4 Oct" next to
// October) instead of updating the current one.
function _calendarBucketStart(tsSec, targetMinutes) {
  if (targetMinutes === 10080) return _weekStartIst(tsSec);
  if (targetMinutes === 43200) return _monthStartIst(tsSec);
  const p = targetMinutes * 60;
  return Math.floor(tsSec / p) * p;
}

// When the daily-or-longer bar that starts at `startSec` closes: the next
// month's 1st for monthly (months are 28–31 days, not 30), else start + width.
function _calendarBucketEnd(startSec, targetMinutes) {
  if (targetMinutes === 43200) {
    const d = new Date((startSec + IST_OFFSET) * 1000);
    return Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1) / 1000 - IST_OFFSET;
  }
  return startSec + targetMinutes * 60;
}

// Session open (IST minutes from midnight) per exchange — mirrors
// chart-helpers.js `_sessionBoundsFor`. Used to anchor intraday buckets to the
// session open. null → unknown exchange → fall back to plain epoch-modular
// bucketing (previous behaviour).
function _sessionOpenMinFor(exch) {
  if (exch === 'NSE' || exch === 'NFO' || exch === 'BSE' || exch === 'BFO') return 555; // 09:15
  if (exch === 'CDS' || exch === 'BCD') return 540;   // 09:00
  if (exch === 'MCX' || exch === 'NCOM') return 540;  // 09:00
  return null;
}

// Intraday bucket start (epoch seconds) for a candle/tick at `tsSec`, anchored
// to the exchange's session open for THAT bar's IST day — so a 1h NSE bucket
// starts at 09:15 (not the UTC-hour boundary, which is 08:30 IST because IST is
// UTC+5:30). Falls back to plain epoch-modular when the exchange has no known
// session (openMin null). `tsSec` before the open (pre-open, already filtered
// upstream) clamps to the open.
function _intradayBucketStart(tsSec, targetSec, openMin) {
  if (openMin == null) return tsSec - (tsSec % targetSec);
  const istSec = tsSec + IST_OFFSET;
  const istMidnightUtc = (istSec - (istSec % 86400)) - IST_OFFSET;
  const sessionOpenUtc = istMidnightUtc + openMin * 60;
  if (tsSec < sessionOpenUtc) return sessionOpenUtc;
  return sessionOpenUtc + Math.floor((tsSec - sessionOpenUtc) / targetSec) * targetSec;
}

/**
 * Apply a live tick to the last candle of `candles`, or append a new candle
 * if the tick falls in the next bucket.
 *
 * Mutates `candles` and `aggState`. Returns:
 *   'applied'  — tick was integrated into a candle
 *   'skipped'  — tick was dropped (late delivery / out-of-order ft / dv<=0 / dv too large)
 *   'primed'   — first tick; baseline set without producing a trade
 *
 * tick = { lp:number, v:number (cum), ft:number (epoch seconds) }
 * targetMs = target candle width in milliseconds
 */
function ingestTickIntoBucket(candles, tick, aggState, targetMs, exch) {
  if (tick.lp == null || tick.v == null || tick.ft == null) return 'skipped';
  const raw = +tick.lp;
  const cumVol = +tick.v;
  const tickMs = +tick.ft * 1000;
  // Phase 24.2 — index mode: when the broker doesn't deliver `v`/`ft` (true
  // for NIFTY 50, SENSEX, etc.), `ingestTick` in chart.js sets `_lpOnly` and
  // synthesises v=0 + ft=now. The volume-delta gate below would otherwise
  // skip every tick (dv = 0 - 0 = 0). Bypass volume tracking entirely in
  // that mode and aggregate purely from lp + ft.
  const lpOnly = tick._lpOnly === true;
  // `priceOnly` starts equal to lpOnly, but is also switched on for a
  // depth-sourced tick that moved the price with NO volume delta (see the
  // dv===0 branch below). Such a tick updates OHLC but credits no volume.
  let priceOnly = lpOnly;

  if (!lpOnly) {
    if (aggState.prevCumVol == null) {
      // First tick: set the volume baseline but DON'T skip the bar. Fall
      // through to form/update the candle now — the volume delta is 0 on this
      // tick, but OHLC comes from price + the day fields, so today's bar
      // appears immediately (from the cached WS open/high/low + LTP at chart
      // open) instead of waiting for the next tick. Volume accrues from the
      // 2nd tick onward.
      aggState.prevCumVol = cumVol;
    } else {
      const dv = cumVol - aggState.prevCumVol;
      // dv < 0   → cumulative volume went backwards: a stale/out-of-order
      //            delivery. Never touch the bar.
      // dv === 0 → this frame reported no NEW trades. On brokers where the
      //            live `lp` rides depth (`df`) frames that don't re-send `v`,
      //            the last price keeps moving while `v` stays frozen — so a
      //            dv===0 tick whose PRICE changed is a genuine price update we
      //            must still apply (close/high/low) with no volume to credit,
      //            exactly like lpOnly. A dv===0 tick at the SAME price is a
      //            true duplicate — skip it to avoid redraw churn. Without this,
      //            a touchline ('t') eviction (leaving a depth-only feed) froze
      //            the candle while lp was still live and the Stale pill climbed.
      if (dv < 0) return 'skipped';
      if (dv === 0) {
        if (raw === aggState.prevPrice) return 'skipped';
        priceOnly = true;
      } else if (dv > 50000) {            // huge jump — reset baseline
        aggState.prevCumVol = cumVol;
        aggState.prevPrice = raw;
        aggState.prevMs = tickMs;
        return 'skipped';
      }
    }
  }

  const targetSec = targetMs / 1000;
  // Live ticks must land in the SAME bucket the history was bucketed into:
  // intraday anchors to the session open, daily+ uses the calendar rule
  // bucketCandles uses (Monday weeks, calendar months).
  const bucketSec = (targetMs < 86400000)
      ? _intradayBucketStart(tickMs / 1000, targetSec, _sessionOpenMinFor(exch))
      : _calendarBucketStart(tickMs / 1000, targetMs / 60000);
  // Daily/weekly/monthly: TODAY's bar isn't in the EOD history (which ends
  // yesterday), so it's built from live ticks. Seed/maintain it from the
  // broker's true day OHLC (tick.dayOpen/High/Low) — using the first tick's lp
  // as "open" showed the LTP-at-open, not the real session open. For weekly/
  // monthly only high/low get widened by today's extremes; the open stays the
  // bucket's first-day open (so we only override `o` for the 1-day timeframe).
  const isDailyPlus = targetMs >= 86400000;
  const isDaily = targetMs === 86400000;
  const dO = tick.dayOpen, dH = tick.dayHigh, dL = tick.dayLow;
  const applyDayExtremes = (bar) => {
    if (!isDailyPlus) return;
    if (typeof dH === 'number' && dH > bar.h) bar.h = dH;
    if (typeof dL === 'number' && dL < bar.l) bar.l = dL;
    if (isDaily && typeof dO === 'number') bar.o = dO;
  };
  let c = candles.length ? candles[candles.length - 1] : null;
  if (c && bucketSec < c.ts) {
    // Out-of-order tick. In lpOnly mode (indices), the synthesised ft is
    // `Date.now()` which can lag the server-bucketed history by minutes
    // (clock skew). Dropping every such tick would freeze the LTP forever.
    // Instead, update the existing latest bar's close so the chart still
    // tracks live price even if we can't accurately bucket the timestamp.
    if (priceOnly) {
      c.c = raw;
      if (raw > c.h) c.h = raw;
      if (raw < c.l) c.l = raw;
      applyDayExtremes(c);
      aggState.prevPrice = raw;
      aggState.prevMs = tickMs;
      return 'applied';
    }
    return 'skipped';
  }
  if (!c || bucketSec > c.ts) {
    if (isDailyPlus && typeof dO === 'number') {
      c = { ts: bucketSec, o: dO,
            h: Math.max(typeof dH === 'number' ? dH : raw, raw),
            l: Math.min(typeof dL === 'number' ? dL : raw, raw),
            c: raw, v: 0 };
    } else {
      c = { ts: bucketSec, o: raw, h: raw, l: raw, c: raw, v: 0 };
    }
    candles.push(c);
  }
  c.c = raw;
  if (raw > c.h) c.h = raw;
  if (raw < c.l) c.l = raw;
  applyDayExtremes(c);
  if (!priceOnly) {
    c.v += (cumVol - aggState.prevCumVol);
    aggState.prevCumVol = cumVol;
    aggState.prevPrice = raw;
    aggState.prevMs = tickMs;
  } else {
    // No volume to credit — but still advance the price/time markers so
    // any future non-lpOnly tick reseeds cleanly.
    aggState.prevPrice = raw;
    aggState.prevMs = tickMs;
  }
  return 'applied';
}

// Expose for browser global scope (no module system in iframe).
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { bucketCandles, ingestTickIntoBucket, SOURCE_INTERVAL_FOR_MINUTES,
    _calendarBucketEnd };
}
