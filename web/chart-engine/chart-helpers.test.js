'use strict';

// Pure-helper unit tests. Run with: node web/chart-engine/chart-helpers.test.js
const assert = require('assert');
const h = require('./chart-helpers');

let pass = 0, fail = 0;
function t(name, fn) {
  try { fn(); console.log('  ✓', name); pass++; }
  catch (e) { console.log('  ✗', name, '\n    ', e.message); fail++; }
}

console.log('_hexToRgba');
t('expands + formats hex', () => assert.strictEqual(h._hexToRgba('#3B82F6', 0.5), 'rgba(59,130,246,0.5)'));
t('handles 3-digit hex', () => assert.strictEqual(h._hexToRgba('#fff', 1), 'rgba(255,255,255,1)'));
t('bad input → grey fallback', () => assert.strictEqual(h._hexToRgba('nope', 0.2), 'rgba(75,85,99,0.2)'));

console.log('_nearestIndex');
const bars = [{ ts: 10 }, { ts: 20 }, { ts: 30 }];
t('picks closest below', () => assert.strictEqual(h._nearestIndex(bars, 22), 1));
t('picks closest above', () => assert.strictEqual(h._nearestIndex(bars, 28), 2));
t('empty → -1', () => assert.strictEqual(h._nearestIndex([], 5), -1));

console.log('_lineRectParams (Liang-Barsky)');
t('diagonal through centre clips both sides', () =>
    assert.deepStrictEqual(h._lineRectParams(0, 0, 1, 1, -10, -10, 10, 10), [-10, 10]));
t('line missing the rect → null', () =>
    assert.strictEqual(h._lineRectParams(100, 100, 0, 1, -10, -10, 10, 10), null));

console.log('_bandRect / _bboxRect');
t('bandRect wraps a segment with slack', () => {
  const r = h._bandRect(0, 0, 10, 6);
  assert.deepStrictEqual(r, { x: 0, y: -4, w: 10, h: 14 });
});
t('bboxRect spans all points', () => {
  const r = h._bboxRect([2, 8, 5], [3, 9, 1]);
  assert.deepStrictEqual(r, { x: 2, y: -3, w: 6, h: 16 });
});

console.log('_wilderATR');
t('flat series → 0 ATR', () => {
  const flat = Array.from({ length: 20 }, () => ({ o: 100, h: 100, l: 100, c: 100, v: 0 }));
  assert.strictEqual(h._wilderATR(flat, 19, 14), 0);
});
t('too little history → undefined', () => {
  const few = Array.from({ length: 5 }, () => ({ o: 1, h: 2, l: 0, c: 1, v: 0 }));
  assert.strictEqual(h._wilderATR(few, 4, 14), undefined);
});

// Helper: epoch seconds for an IST wall-clock time (IST = UTC+5:30).
const ist = (y, mo, d, h, mi) => Math.floor(Date.UTC(y, mo, d, h, mi) / 1000) - 19800;

console.log('_nthSundayOfMonth');
t('2nd Sunday of March 2026 = 8', () => assert.strictEqual(h._nthSundayOfMonth(2026, 2, 2), 8));
t('1st Sunday of Nov 2026 = 1', () => assert.strictEqual(h._nthSundayOfMonth(2026, 10, 1), 1));

console.log('_usInDst (2026: DST = Mar 8 .. Nov 1)');
t('July is DST', () => assert.strictEqual(h._usInDst(ist(2026, 6, 15, 12, 0)), true));
t('January is not DST', () => assert.strictEqual(h._usInDst(ist(2026, 0, 15, 12, 0)), false));
t('Mar 7 not yet DST', () => assert.strictEqual(h._usInDst(ist(2026, 2, 7, 12, 0)), false));
t('Mar 8 is DST', () => assert.strictEqual(h._usInDst(ist(2026, 2, 8, 12, 0)), true));
t('Oct 31 still DST', () => assert.strictEqual(h._usInDst(ist(2026, 9, 31, 12, 0)), true));
t('Nov 1 DST over', () => assert.strictEqual(h._usInDst(ist(2026, 10, 1, 12, 0)), false));

console.log('_sessionBoundsFor');
t('NSE equity 555-930', () => assert.deepStrictEqual(
    h._sessionBoundsFor('NSE', ist(2026, 5, 18, 12, 0)), { openMin: 555, closeMin: 930 }));
t('CDS currency 540-1020', () => assert.deepStrictEqual(
    h._sessionBoundsFor('CDS', ist(2026, 5, 18, 12, 0)), { openMin: 540, closeMin: 1020 }));
t('MCX July close 23:30 (1410)', () => assert.strictEqual(
    h._sessionBoundsFor('MCX', ist(2026, 6, 18, 12, 0)).closeMin, 1410));
t('MCX January close 23:55 (1435)', () => assert.strictEqual(
    h._sessionBoundsFor('MCX', ist(2026, 0, 18, 12, 0)).closeMin, 1435));
t('unknown exchange -> nulls', () => assert.deepStrictEqual(
    h._sessionBoundsFor('XYZ', ist(2026, 5, 18, 12, 0)), { openMin: null, closeMin: null }));

console.log('_isSessionWindowPure (2026-06-18 is a Thursday; 06-20 a Saturday)');
t('NSE 09:14 before open', () => assert.strictEqual(h._isSessionWindowPure('NSE', ist(2026, 5, 18, 9, 14)), false));
t('NSE 09:15 open', () => assert.strictEqual(h._isSessionWindowPure('NSE', ist(2026, 5, 18, 9, 15)), true));
t('NSE 15:25 last valid', () => assert.strictEqual(h._isSessionWindowPure('NSE', ist(2026, 5, 18, 15, 25)), true));
t('NSE 15:29 still in', () => assert.strictEqual(h._isSessionWindowPure('NSE', ist(2026, 5, 18, 15, 29)), true));
t('NSE 15:30 EXCLUSIVE close', () => assert.strictEqual(h._isSessionWindowPure('NSE', ist(2026, 5, 18, 15, 30)), false));
t('NSE Saturday closed', () => assert.strictEqual(h._isSessionWindowPure('NSE', ist(2026, 5, 20, 12, 0)), false));
t('CDS 16:59 in', () => assert.strictEqual(h._isSessionWindowPure('CDS', ist(2026, 5, 18, 16, 59)), true));
t('CDS 17:00 EXCLUSIVE close', () => assert.strictEqual(h._isSessionWindowPure('CDS', ist(2026, 5, 18, 17, 0)), false));
t('MCX July 23:29 in', () => assert.strictEqual(h._isSessionWindowPure('MCX', ist(2026, 6, 16, 23, 29)), true));
t('MCX July 23:30 out', () => assert.strictEqual(h._isSessionWindowPure('MCX', ist(2026, 6, 16, 23, 30)), false));
t('MCX January 23:54 in', () => assert.strictEqual(h._isSessionWindowPure('MCX', ist(2026, 0, 16, 23, 54)), true));
t('MCX January 23:55 out', () => assert.strictEqual(h._isSessionWindowPure('MCX', ist(2026, 0, 16, 23, 55)), false));
t('unmapped always in session', () => assert.strictEqual(h._isSessionWindowPure('XYZ', ist(2026, 5, 20, 3, 0)), true));


// ── CPR with Pivot Level Daily ────────────────────────────────────────────
console.log('CPR');
const near = (a, b) => Math.abs(a - b) < 1e-9;
// Daily EOD bars are stamped 05:30 IST (00:00 UTC).
const dayBar = (mo, d, hi, lo, cl) => ({ ts: ist(2026, mo, d, 5, 30), o: lo, h: hi, l: lo, c: cl, v: 0 });
const daily = [
  dayBar(9, 9, 120, 100, 104),   // Fri 9 Oct
  dayBar(9, 12, 110, 90, 100),   // Mon 12 Oct
  dayBar(9, 13, 130, 110, 120),  // Tue 13 Oct
  dayBar(9, 14, 105, 95, 101),   // Wed 14 Oct
];
const nowMs = ist(2026, 9, 15, 12, 0) * 1000;   // Thu 15 Oct, 12:00 IST
const bar = (mo, d, hh, mi) => ({ ts: ist(2026, mo, d, hh, mi), o: 1, h: 1, l: 1, c: 1, v: 0 });

t('levels follow the TradingView formulas (prev H/L/C)', () => {
  const L = h.cprLevels(120, 100, 104);
  assert.ok(near(L.pivot, 108) && near(L.bc, 110) && near(L.tc, 106));
  assert.ok(near(L.high, 120) && near(L.low, 100));
  assert.ok(near(L.r1, 116) && near(L.r2, 128) && near(L.r3, 136) && near(L.r4, 148));
  assert.ok(near(L.s1, 96) && near(L.s2, 88) && near(L.s3, 76) && near(L.s4, 68));
});

t('each candle uses the PREVIOUS trading day; Monday uses Friday', () => {
  const candles = [bar(9, 12, 9, 15), bar(9, 13, 10, 0)];
  const s = h.computeCprSeries(candles, daily, nowMs);
  assert.ok(near(s.pivot[0], 108));          // Mon 12 <- Fri 9 (120/100/104)
  assert.ok(near(s.pivot[1], 100));          // Tue 13 <- Mon 12 (110/90/100)
  assert.ok(near(s.high[1], 110) && near(s.low[1], 90));
});

t('today (no daily bar yet) uses the last completed day', () => {
  const s = h.computeCprSeries([bar(9, 15, 9, 15), bar(9, 15, 11, 30)], daily, nowMs);
  const wed = h.cprLevels(105, 95, 101);
  assert.ok(near(s.pivot[0], wed.pivot) && near(s.pivot[1], wed.pivot));
  assert.ok(near(s.r1[1], wed.r1) && near(s.s4[1], wed.s4));
});

t('a partial bar for today in the daily data does not change today\'s levels', () => {
  const withToday = daily.concat([dayBar(9, 15, 999, 1, 500)]);
  const s = h.computeCprSeries([bar(9, 15, 10, 0)], withToday, nowMs);
  assert.ok(near(s.pivot[0], h.cprLevels(105, 95, 101).pivot));
});

t('bars older than 30 days, or with no previous day, have no levels', () => {
  const s = h.computeCprSeries([bar(8, 1, 10, 0), bar(9, 9, 10, 0)], daily, nowMs);
  assert.ok(Number.isNaN(s.pivot[0]));   // 1 Sep: older than 30 days
  assert.ok(Number.isNaN(s.pivot[1]));   // Fri 9 Oct: no earlier daily bar loaded
});

t('daily data out of order is handled', () => {
  const s = h.computeCprSeries([bar(9, 13, 10, 0)], daily.slice().reverse(), nowMs);
  assert.ok(near(s.pivot[0], 100));
});

t('plot style defaults match the TradingView metainfo', () => {
  const pv = h.cprPlotStyle({}, h.CPR_PLOTS.find((p) => p.key === 'pivot'));
  assert.deepStrictEqual(pv, { visible: true, color: '#F8AF85', width: 3,
    lineStyle: 'solid', plotType: 'circles', priceLine: false });
  const r4 = h.cprPlotStyle({}, h.CPR_PLOTS.find((p) => p.key === 'r4'));
  assert.strictEqual(r4.visible, false);
  assert.strictEqual(r4.color, '#008000');
  assert.deepStrictEqual(h.CPR_PLOTS.filter((p) => p.visible).map((p) => p.key), ['pivot', 'bc', 'tc']);
  assert.strictEqual(h.CPR_PLOTS.length, 13);
});

t('plot style reads the per-line params', () => {
  const st = h.cprPlotStyle({ bcV: 0, bcC: 0x112233, bcW: 1, bcS: 2, bcT: 0, bcP: 1 },
      h.CPR_PLOTS.find((p) => p.key === 'bc'));
  assert.deepStrictEqual(st, { visible: false, color: '#112233', width: 1,
    lineStyle: 'dashed', plotType: 'line', priceLine: true });
});

t('precision: Default = 2 decimals, else the chosen digits', () => {
  assert.strictEqual(h.cprDecimals({}), 2);
  assert.strictEqual(h.cprDecimals({ precision: 0 }), 2);
  assert.strictEqual(h.cprDecimals({ precision: 1 }), 0);
  assert.strictEqual(h.cprDecimals({ precision: 5 }), 4);
});

console.log(`\n${pass} passed, ${fail} failed`);
if (fail > 0) process.exit(1);
