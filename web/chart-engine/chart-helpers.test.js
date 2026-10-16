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


// ── CPR Trend Checker (CPR + MAs) ─────────────────────────────────────────
console.log('Trend Checker');
const tcNear = (a, b, e) => Math.abs(a - b) < (e == null ? 0.0051 : e);
// Reference values read off a TradingView chart of the original study:
// NIFTY 50 on Fri 16 Oct 2026; the previous day (15 Oct) had H 23056.40,
// L 22637.40, C 22997.35.
t('levels match the TradingView chart values (R4/S4 = 2*R3-R2, 2*S3-S2)', () => {
  const L = h.tcLevels(23056.40, 22637.40, 22997.35);
  assert.ok(tcNear(L.high, 23056.40) && tcNear(L.low, 22637.40));
  assert.ok(tcNear(L.bc, 22846.90), 'BC ' + L.bc);
  assert.ok(tcNear(L.pivot, 22897.05), 'pivot ' + L.pivot);
  assert.ok(tcNear(L.tc, 22947.20), 'TC ' + L.tc);
  assert.ok(tcNear(L.r1, 23156.70) && tcNear(L.s1, 22737.70));
  assert.ok(tcNear(L.r2, 23316.05) && tcNear(L.s2, 22478.05));
  assert.ok(tcNear(L.r3, 23575.70) && tcNear(L.s3, 22318.70));
  assert.ok(tcNear(L.r4, 23835.35), 'R4 ' + L.r4);
  assert.ok(tcNear(L.s4, 22159.35), 'S4 ' + L.s4);
});

// Mon 28 Sep .. Fri 6 Nov 2026, one daily bar per weekday (05:30 IST stamp).
const tcDaily = [];
for (let dt = Date.UTC(2026, 8, 28), i = 0; dt <= Date.UTC(2026, 10, 6); dt += 86400000) {
  const dow = new Date(dt).getUTCDay();
  if (dow === 0 || dow === 6) continue;
  const d = new Date(dt);
  tcDaily.push({ ts: ist(2026, d.getUTCMonth(), d.getUTCDate(), 5, 30),
      o: 150, h: 200 + i, l: 100 - i, c: 150 + (i % 7), v: 1 });
  i++;
}
const tcOn = (mo, d) => tcDaily.filter((b) => {
  const x = new Date((b.ts + 19800) * 1000);
  return x.getUTCMonth() === mo && x.getUTCDate() === d;
})[0];
const tcBetween = (a, z) => tcDaily.filter((b) => b.ts >= ist(2026, a[0], a[1], 0, 0) && b.ts < ist(2026, z[0], z[1], 0, 0));
const tcBar = (mo, d, hh, mi) => ({ ts: ist(2026, mo, d, hh, mi), o: 1, h: 1, l: 1, c: 1, v: 0 });

t('daily levels come from the previous trading day (Monday uses Friday)', () => {
  const s = h.computeTcSeries([tcBar(9, 12, 9, 15), tcBar(9, 13, 10, 0)], tcDaily);
  const fri = tcOn(9, 9), mon = tcOn(9, 12);
  assert.ok(tcNear(s.d.high[0], fri.h) && tcNear(s.d.low[0], fri.l));
  assert.ok(tcNear(s.d.pivot[0], (fri.h + fri.l + fri.c) / 3));
  assert.ok(tcNear(s.d.high[1], mon.h));
});

t('weekly levels come from the previous completed week', () => {
  const wk = tcBetween([9, 5], [9, 12]);                       // 5-9 Oct
  const H = Math.max(...wk.map((b) => b.h)), L = Math.min(...wk.map((b) => b.l));
  const C = wk[wk.length - 1].c;
  const s = h.computeTcSeries([tcBar(9, 15, 10, 0)], tcDaily);   // Thu 15 Oct
  assert.ok(tcNear(s.w.high[0], H) && tcNear(s.w.low[0], L), 'PWH/PWL');
  assert.ok(tcNear(s.w.pivot[0], (H + L + C) / 3), 'weekly pivot');
  assert.ok(tcNear(s.w.r4[0], 2 * h.tcLevels(H, L, C).r3 - h.tcLevels(H, L, C).r2));
});

t('monthly levels come from the previous calendar month', () => {
  const mo = tcBetween([9, 1], [10, 1]);                       // October
  const H = Math.max(...mo.map((b) => b.h)), L = Math.min(...mo.map((b) => b.l));
  const C = mo[mo.length - 1].c;
  const s = h.computeTcSeries([tcBar(10, 4, 10, 0)], tcDaily);   // Wed 4 Nov
  assert.ok(tcNear(s.m.high[0], H) && tcNear(s.m.low[0], L), 'PMH/PML');
  assert.ok(tcNear(s.m.pivot[0], (H + L + C) / 3), 'monthly pivot');
});

t('a period the daily data only partly covers gives no levels', () => {
  // Data starts Mon 28 Sep, so the first week and month are complete or not
  // knowable; the month of September is partial (28-30 only) and must not be
  // used as "previous month" for October bars.
  const s = h.computeTcSeries([tcBar(9, 6, 10, 0), tcBar(9, 15, 10, 0)], tcDaily);
  assert.ok(Number.isNaN(s.m.pivot[0]) && Number.isNaN(s.m.pivot[1]));
  const first = h.computeTcSeries([tcBar(8, 28, 10, 0)], tcDaily);
  assert.ok(Number.isNaN(first.w.pivot[0]) && Number.isNaN(first.d.pivot[0]));
});

t('a partial bar for today in the daily data is not used for today', () => {
  const s = h.computeTcSeries([tcBar(9, 15, 10, 0)], tcDaily);
  const wed = tcOn(9, 14);
  assert.ok(tcNear(s.d.high[0], wed.h) && tcNear(s.d.low[0], wed.l));
});

t('period id follows the candle\'s own day / week / month', () => {
  const s = h.computeTcSeries([tcBar(9, 12, 9, 15), tcBar(9, 12, 10, 0), tcBar(9, 13, 9, 15)], tcDaily);
  assert.strictEqual(s.d.seg[0], s.d.seg[1]);
  assert.notStrictEqual(s.d.seg[1], s.d.seg[2]);
  assert.strictEqual(s.w.seg[1], s.w.seg[2]);          // same week
  assert.strictEqual(s.m.seg[1], s.m.seg[2]);          // same month
});

t('empty or missing daily data gives all-NaN series', () => {
  const s = h.computeTcSeries([tcBar(9, 15, 10, 0)], []);
  assert.ok(Number.isNaN(s.d.pivot[0]) && Number.isNaN(s.w.pivot[0]) && Number.isNaN(s.m.pivot[0]));
  assert.strictEqual(h.computeTcSeries([], tcDaily).d.pivot.length, 0);
});

t('auto-select picks the group from the chart timeframe', () => {
  const a = (tf) => h.tcActiveGroups({ auto: 1 }, tf);
  assert.deepStrictEqual([a(5).d.cpr, a(5).w.cpr, a(5).m.cpr], [true, false, false]);
  assert.deepStrictEqual([a(1440).d.cpr, a(1440).w.cpr, a(1440).m.cpr], [false, true, false]);
  assert.deepStrictEqual([a(10080).d.cpr, a(10080).w.cpr, a(10080).m.cpr], [false, false, true]);
  assert.strictEqual(a(5).d.hl, true);
});

t('manual group switches default to Daily CPR + PDH/PDL only', () => {
  const g = h.tcActiveGroups({}, 5);
  assert.deepStrictEqual([g.d.cpr, g.d.hl, g.w.cpr, g.w.hl, g.m.cpr, g.m.hl],
      [true, true, false, false, false, false]);
  const g2 = h.tcActiveGroups({ wOn: 1, pmOn: 1, dOn: 0 }, 5);
  assert.deepStrictEqual([g2.d.cpr, g2.w.cpr, g2.m.hl, g2.d.hl], [false, true, true, true]);
});

t('line defaults: 39 lines in the study order; BC/TC are transparent', () => {
  assert.strictEqual(h.TC_LINES.length, 39);
  assert.deepStrictEqual(h.TC_LINES.slice(0, 7).map((l) => l.title),
      ['PDH', 'PDL', 'Daily CPR', 'Daily BC', 'Daily TC', 'Daily R1', 'Daily S1']);
  assert.deepStrictEqual(h.TC_LINES.slice(13, 15).map((l) => l.title), ['PWH', 'PWL']);
  assert.strictEqual(h.TC_LINES[39 - 1].title, 'Monthly S4');
  const bc = h.tcLineStyle({}, h.TC_LINES.find((l) => l.key === 'dbc'));
  assert.strictEqual(bc.alpha, 0);
  const r1 = h.tcLineStyle({}, h.TC_LINES.find((l) => l.key === 'dr1'));
  assert.strictEqual(r1.color, '#4CAF50');
  assert.strictEqual(r1.plotType, 'circles');
  const s1 = h.tcLineStyle({}, h.TC_LINES.find((l) => l.key === 'ds1'));
  assert.strictEqual(s1.color, '#FF5252');
});

t('line style reads params; opacity builds an rgba colour', () => {
  const ln = h.TC_LINES.find((l) => l.key === 'pdh');
  const st = h.tcLineStyle({ pdhC: 0x112233, pdhO: 50, pdhW: 3, pdhS: 2, pdhT: 0, pdhV: 0 }, ln);
  assert.strictEqual(st.color, '#112233');
  assert.strictEqual(st.visible, false);
  assert.strictEqual(st.width, 3);
  assert.strictEqual(st.lineStyle, 'dashed');
  assert.strictEqual(st.plotType, 'line');
  assert.strictEqual(st.css, 'rgba(17,34,51,0.5)');
});

t('moving average defaults: only MA #1 (SMA close 10) is on', () => {
  const m1 = h.tcMaConfig({}, 1), m2 = h.tcMaConfig({}, 2), m5 = h.tcMaConfig({}, 5);
  assert.deepStrictEqual([m1.on, m1.type, m1.src, m1.len, m1.color], [true, 'SMA', 'close', 10, '#F5BF00']);
  assert.deepStrictEqual([m2.on, m2.len, m2.color], [false, 20, '#178A17']);
  assert.deepStrictEqual([m5.on, m5.len, m5.color], [false, 200, '#1E7FFF']);
  const c = h.tcMaConfig({ ma3On: 1, ma3Type: 1, ma3Src: 5, ma3Len: 34, ma3C: 0xAABBCC }, 3);
  assert.deepStrictEqual([c.on, c.type, c.src, c.len, c.color], [true, 'EMA', 'hlc3', 34, '#AABBCC']);
});

const tcCl = [10, 12, 11, 13, 15, 14].map((c, i) => ({ ts: i, o: c, h: c + 1, l: c - 1, c, v: i + 1 }));
t('SMA', () => {
  const v = h.tcMa(tcCl, 0, 0, 3);
  assert.ok(Number.isNaN(v[0]) && Number.isNaN(v[1]));
  assert.ok(tcNear(v[2], 11, 1e-9) && tcNear(v[3], 12, 1e-9) && tcNear(v[4], 13, 1e-9) && tcNear(v[5], 14, 1e-9));
});
t('EMA is seeded with the SMA', () => {
  const v = h.tcMa(tcCl, 1, 0, 3);
  assert.ok(Number.isNaN(v[1]) && tcNear(v[2], 11, 1e-9));
  assert.ok(tcNear(v[3], 12, 1e-9) && tcNear(v[4], 13.5, 1e-9) && tcNear(v[5], 13.75, 1e-9));
});
t('WMA', () => {
  const v = h.tcMa(tcCl, 2, 0, 3);
  assert.ok(tcNear(v[2], 67 / 6, 1e-9) && tcNear(v[3], 73 / 6, 1e-9) && tcNear(v[5], 85 / 6, 1e-9));
});
t('RMA is seeded with the SMA, alpha 1/len', () => {
  const v = h.tcMa(tcCl, 3, 0, 3);
  assert.ok(tcNear(v[2], 11, 1e-9) && tcNear(v[3], (13 + 2 * 11) / 3, 1e-9));
  assert.ok(tcNear(v[4], (15 + 2 * ((13 + 22) / 3)) / 3, 1e-9));
});
t('HMA has no lag on a straight line', () => {
  const ramp = Array.from({ length: 40 }, (_, i) => ({ ts: i, o: i, h: i, l: i, c: i, v: 1 }));
  const v = h.tcMa(ramp, 4, 0, 9);
  assert.ok(Number.isNaN(v[0]));
  for (let i = 15; i < 40; i++) assert.ok(tcNear(v[i], i, 1e-9), 'i=' + i + ' ' + v[i]);
});
t('VWMA weights by volume', () => {
  const v = h.tcMa([{ ts: 0, o: 10, h: 10, l: 10, c: 10, v: 1 }, { ts: 1, o: 20, h: 20, l: 20, c: 20, v: 3 }], 5, 0, 2);
  assert.ok(tcNear(v[1], 17.5, 1e-9));
});
t('price sources', () => {
  const bar = [{ ts: 0, o: 10, h: 20, l: 4, c: 16, v: 1 }];
  const at = (src) => h.tcMa(bar, 0, src, 1)[0];
  assert.deepStrictEqual([at(0), at(1), at(2), at(3), at(4), at(5), at(6)],
      [16, 10, 20, 4, 12, (20 + 4 + 16) / 3, (10 + 20 + 4 + 16) / 4]);
});

console.log(`\n${pass} passed, ${fail} failed`);
if (fail > 0) process.exit(1);
