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

console.log(`\n${pass} passed, ${fail} failed`);
if (fail > 0) process.exit(1);
