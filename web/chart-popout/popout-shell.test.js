'use strict';
const assert = require('assert');
const { isSessionExpired, feedUid, connectUid } = require('./popout-shell.js');
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
console.log(`${pass} passed · ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
