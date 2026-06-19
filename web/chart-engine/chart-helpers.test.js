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

console.log(`\n${pass} passed, ${fail} failed`);
if (fail > 0) process.exit(1);
