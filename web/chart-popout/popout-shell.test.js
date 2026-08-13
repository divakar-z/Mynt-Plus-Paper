'use strict';
const assert = require('assert');
const { isSessionExpired, feedUid, connectUid, parseTpseries, normalizeTick } = require('./popout-shell.js');
let pass = 0, fail = 0;
const t = (n, f) => { try { f(); console.log('  ✓', n); pass++; } catch (e) { console.log('  ✗', n, e.message); fail++; } };

t('detects session-expired object', () =>
  assert.strictEqual(isSessionExpired({ stat: 'Not_Ok', emsg: 'Session Expired : Invalid Session Key' }), true));
t('detects it inside an array', () =>
  assert.strictEqual(isSessionExpired([{ stat: 'Not_Ok', emsg: 'session gone' }]), true));
t('ok reply is not expired', () =>
  assert.strictEqual(isSessionExpired({ stat: 'Ok' }), false));
t('non-session Not_Ok is not expired', () =>
  assert.strictEqual(isSessionExpired({ stat: 'Not_Ok', emsg: 'Invalid token' }), false));
t('feedUid/connectUid build the suffix', () => {
  assert.strictEqual(feedUid('ZP00172', 2), 'ZP00172_2_TA');
  assert.strictEqual(connectUid('ZP00172', 2), 'ZP00172_2_TA_TV');
});
t('parses TPSeries rows oldest->newest', () => {
  const out = parseTpseries([
    { stat: 'Ok', ssboe: '200', into: '2', inth: '3', intl: '1', intc: '2', intv: '5' },
    { stat: 'Ok', ssboe: '100', into: '1', inth: '2', intl: '0', intc: '1', intv: '4' },
    { stat: 'Not_Ok' },
  ]);
  assert.strictEqual(out.length, 2);
  assert.strictEqual(out[0].ts, 100);
  assert.deepStrictEqual(out[1], { ts: 200, o: 2, h: 3, l: 1, c: 2, v: 5 });
});
t('normalizes a touchline tick, synth v/ft', () => {
  const out = normalizeTick({ t: 'tf', tk: '26000', lp: '25000.5', bp1: '25000', sp1: '25001' }, 1700);
  assert.strictEqual(out.token, '26000');
  assert.strictEqual(out.packet.lp, 25000.5);
  assert.strictEqual(out.packet.v, 0);
  assert.strictEqual(out.packet.ft, 1700);
  assert.strictEqual(out.packet.bp1, 25000);
});
t('ignores non-feed frames', () =>
  assert.strictEqual(normalizeTick({ t: 'ck' }, 1700), null));
t('ignores feed frame without lp', () =>
  assert.strictEqual(normalizeTick({ t: 'tf', tk: '1' }, 1700), null));

console.log(`${pass} passed · ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
