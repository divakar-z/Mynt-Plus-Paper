'use strict';

const assert = require('assert');
const { bucketCandles, ingestTickIntoBucket, SOURCE_INTERVAL_FOR_MINUTES } =
    require('./aggregator');

let pass = 0, fail = 0;
function t(name, fn) {
  try { fn(); console.log('  ✓', name); pass++; }
  catch (e) { console.log('  ✗', name, '\n    ', e.message); fail++; }
}

console.log('SOURCE_INTERVAL_FOR_MINUTES');
t('returns "1" for <60', () => assert.strictEqual(SOURCE_INTERVAL_FOR_MINUTES(1), '1'));
t('returns "1" for 30',  () => assert.strictEqual(SOURCE_INTERVAL_FOR_MINUTES(30), '1'));
t('returns "5" for 60',  () => assert.strictEqual(SOURCE_INTERVAL_FOR_MINUTES(60), '5'));
t('returns "5" for 240', () => assert.strictEqual(SOURCE_INTERVAL_FOR_MINUTES(240), '5'));
t('returns "1D" for 1440', () => assert.strictEqual(SOURCE_INTERVAL_FOR_MINUTES(1440), '1D'));

console.log('bucketCandles');
t('empty input → empty output', () => {
  assert.deepStrictEqual(bucketCandles([], 5), []);
});

t('rolls 5x 1m into 1x 5m', () => {
  const src = [
    { ts: 0,   o: 100, h: 102, l: 99,  c: 101, v: 10 },
    { ts: 60,  o: 101, h: 103, l: 100, c: 102, v: 20 },
    { ts: 120, o: 102, h: 105, l: 101, c: 104, v: 30 },
    { ts: 180, o: 104, h: 106, l: 103, c: 105, v: 40 },
    { ts: 240, o: 105, h: 107, l: 102, c: 106, v: 50 },
  ];
  const out = bucketCandles(src, 5);
  assert.strictEqual(out.length, 1);
  assert.deepStrictEqual(out[0], { ts: 0, o: 100, h: 107, l: 99, c: 106, v: 150 });
});

t('starts new bucket at boundary', () => {
  const src = [
    { ts: 0,   o: 100, h: 100, l: 100, c: 100, v: 1 },
    { ts: 300, o: 200, h: 200, l: 200, c: 200, v: 2 },
  ];
  const out = bucketCandles(src, 5);
  assert.strictEqual(out.length, 2);
  assert.strictEqual(out[0].ts, 0);
  assert.strictEqual(out[1].ts, 300);
});

t('passes daily through unchanged', () => {
  const src = [
    { ts: 86400, o: 1, h: 2, l: 0, c: 1, v: 10 },
    { ts: 172800, o: 1, h: 2, l: 0, c: 1, v: 20 },
  ];
  assert.deepStrictEqual(bucketCandles(src, 1440), src);
});

console.log('ingestTickIntoBucket');
t('first tick forms the bar (v=0) and sets the volume baseline', () => {
  const candles = [];
  const state = { prevCumVol: null, prevPrice: null, prevMs: null };
  const r = ingestTickIntoBucket(candles, { lp: 100, v: 1000, ft: 60 }, state, 60_000);
  // The first tick now forms today's bar immediately (volume delta is 0) so the
  // candle appears without waiting for the next tick. Volume accrues from #2.
  assert.strictEqual(r, 'applied');
  assert.strictEqual(candles.length, 1);
  assert.strictEqual(candles[0].o, 100);
  assert.strictEqual(candles[0].c, 100);
  assert.strictEqual(candles[0].v, 0);
  assert.strictEqual(state.prevCumVol, 1000);
});

t('daily bar seeds OHLC from the WS day fields, not the tick lp', () => {
  const candles = [];
  const state = { prevCumVol: null, prevPrice: null, prevMs: null };
  // Daily timeframe (1440 min). lp=270 but the day opened at 278.15 with a
  // 281.5 high / 274.65 low — the bar must use those, not lp, for o/h/l.
  const r = ingestTickIntoBucket(
      candles,
      { lp: 270, v: 1000, ft: 1781840700, dayOpen: 278.15, dayHigh: 281.5, dayLow: 274.65 },
      state,
      1440 * 60_000);
  assert.strictEqual(r, 'applied');
  assert.strictEqual(candles.length, 1);
  assert.strictEqual(candles[0].o, 278.15); // session open, not lp
  assert.strictEqual(candles[0].h, 281.5);  // day high
  assert.strictEqual(candles[0].l, 270);    // min(dayLow 274.65, lp 270) = 270
  assert.strictEqual(candles[0].c, 270);    // close = lp
});

t('applies a normal tick', () => {
  const candles = [];
  const state = { prevCumVol: 1000, prevPrice: 100, prevMs: 60_000 };
  const r = ingestTickIntoBucket(candles, { lp: 101, v: 1050, ft: 61 }, state, 60_000);
  assert.strictEqual(r, 'applied');
  assert.strictEqual(candles.length, 1);
  assert.strictEqual(candles[0].v, 50);
  assert.strictEqual(candles[0].c, 101);
});

t('appends new candle when crossing bucket boundary', () => {
  const candles = [{ ts: 60, o: 100, h: 100, l: 100, c: 100, v: 10 }];
  const state = { prevCumVol: 1000, prevPrice: 100, prevMs: 60_000 };
  const r = ingestTickIntoBucket(candles, { lp: 102, v: 1050, ft: 121 }, state, 60_000);
  assert.strictEqual(r, 'applied');
  assert.strictEqual(candles.length, 2);
  assert.strictEqual(candles[1].ts, 120);
});

t('drops late tick (dv <= 0) without touching aggState', () => {
  const candles = [{ ts: 60, o: 100, h: 100, l: 100, c: 100, v: 10 }];
  const state = { prevCumVol: 1050, prevPrice: 101, prevMs: 90_000 };
  const r = ingestTickIntoBucket(candles, { lp: 100, v: 1000, ft: 80 }, state, 60_000);
  assert.strictEqual(r, 'skipped');
  assert.strictEqual(state.prevCumVol, 1050); // unchanged
});

t('drops tick into past bucket without polluting current candle', () => {
  const candles = [{ ts: 120, o: 100, h: 100, l: 100, c: 100, v: 5 }];
  const state = { prevCumVol: 1050, prevPrice: 100, prevMs: 121_000 };
  const r = ingestTickIntoBucket(candles, { lp: 99, v: 1100, ft: 60 }, state, 60_000);
  assert.strictEqual(r, 'skipped');
  assert.strictEqual(candles[0].l, 100);   // unchanged
  assert.strictEqual(candles[0].v, 5);     // unchanged
});

t('resets baseline on huge jump (dv > 50k) without applying', () => {
  const candles = [{ ts: 60, o: 100, h: 100, l: 100, c: 100, v: 10 }];
  const state = { prevCumVol: 1000, prevPrice: 100, prevMs: 60_000 };
  const r = ingestTickIntoBucket(candles, { lp: 200, v: 99999, ft: 90 }, state, 60_000);
  assert.strictEqual(r, 'skipped');
  assert.strictEqual(state.prevCumVol, 99999); // baseline reset
  assert.strictEqual(candles[0].v, 10);        // candle unchanged
});

console.log();
console.log(`${pass} passed · ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
