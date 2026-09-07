# Popout Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a view-only "pop out" detached chart window that reuses the existing chart engine, fed by the alternate `ws.zebull.in` websocket (not the app's primary Noren socket), with the session copied from the main window.

**Architecture:** A standalone same-origin page at `web/chart-popout/` (no Flutter) embeds the existing chart-engine **iframe verbatim** and drives it over the existing `postMessage` bridge via a JS "shell" (`popout-shell.js`) that plays the Flutter shell's role — but sources ticks from `wss://ws.zebull.in/NorenWS/` and history/search from the current session's `jKey`/`uid`. Each popout uses a per-window uid suffix (`_1`, `_2`, …) so its feed connection never collides with the app or other popouts.

**Tech Stack:** Vanilla JS + Canvas chart engine (existing), browser WebSocket, `fetch`, `localStorage`; Flutter/`dart:html` for the launcher button. Node + `assert` for unit tests (mirrors `web/chart-engine/aggregator.test.js`).

## Global Constraints

- **NO git commits or pushes** — the user commits manually after testing. Every task ends by running tests + a manual verification; do NOT run `git add/commit/push`.
- **Do NOT modify the chart engine** (`web/chart-engine/*.js`). The popout reuses it as-is over the existing bridge.
- **Feed WS:** `wss://ws.zebull.in/NorenWS/`. **Do not** use `wss://go.mynt.in/NorenWSWeb/`.
- **Socket-session mint:** `POST https://sess.mynt.in/generateSocketSession`, body `{uid:"<uid>_<n>_TA", src:"TV", source:"TV"}` → `{session}`. Connect uid = `<uid>_<n>_TA_TV`, source `TV`.
- **History:** `POST https://go.mynt.in/NorenWClientWeb/TPSeries`, body `jData={...}&jKey=<jKey>`. **Search:** `https://ws.mynt.in/search/SearchScrip`. Both use the current session's `jKey`+`uid`.
- **Secret handling:** `jKey`/`uid` come from `localStorage` (`flutter.clientSession`, `flutter.clientId`, JSON-encoded). Only non-secret config (`exch`,`token`,`tsym`,`tf`,`n`) goes in the URL.
- **Session expiry:** any REST reply with `stat:"Not_Ok"` and `emsg` containing "session" (case-insensitive), or a missing session, → show the blocking "Session expired" overlay and stop the feed. No auto re-login.
- **View-only:** send `setLiteMode(true)`; no trading, no order/position/alert overlays, single pane per popout.
- Design spec: `docs/superpowers/specs/2026-06-24-popout-chart-design.md`.

## Bridge contract (reference — do not change the engine)

Engine → shell (outbound, `postMessage` JSON `{type,value}`):
- `chart-engine-ready` — engine booted.
- `fetchHistory` — `value = {requestId, exch, token, tsym, interval, start, end, targetMinutes}`.
- `subscribe` / `unsubscribe` — `value = {exch, token, tsym}`.
- `paneSymbolApplied` — `value = {paneId, scrip}` (from `applyActiveSymbol`).

Shell → engine (inbound):
- `setTheme` — `value = {name:'dark'|'light'}` (mirror `encodeSetTheme` in `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart`).
- `setLayout` — create panes (mirror the Flutter shell's single-pane layout).
- `setPaneSymbol` — `value = {paneId, scrip:{exch,token,tsym,dispName,ls,ti,instname}}`.
- `setPaneTimeframe` — `value = {paneId, minutes:<int>}`.
- `setLiteMode` — `value = {value:true}`.
- `historyResult` — `value = {requestId, candles:[{ts,o,h,l,c,v}]}` (`ts` = epoch **seconds**).
- `historyError` — `value = {requestId, message}`.
- `tick` — `value = {token, packet:{exch, lp, v, ft, bp1, sp1, o, h, l}}` (`ft` = epoch seconds; `v`/`ft` may be synthesized for lp-only feeds).

Canonical init + push sequence to mirror: `_pushSessionForce` / `_pushSession`, `_wsForwardAll`, and `onHistoryResult` handling in `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`, reduced to one pane + lite mode.

Feed wire protocol (`ws.zebull.in`, reference `d:/Vijay/Indicate/sidecar/ticks.py`):
- Connect: `{t:"c", uid:"<uid>_<n>_TA_TV", actid:"<uid>_<n>_TA_TV", source:"TV", susertoken:<session>}`; ack `t:"ck"`.
- Subscribe touchline: `{t:"t", k:"<exch>|<token>#..."}`; unsubscribe: `{t:"u", k:"<exch>|<token>#..."}`.
- Tick frames: `t` in `{tf,tk,df,dk}`, `tk`=token, `lp`=last, `bp1`/`sp1`=bid/ask; deltas omit unchanged fields.

---

### Task 1: Popout page scaffold + hosting + engine iframe boot

**Files:**
- Create: `web/chart-popout/index.html`
- Create: `web/chart-popout/popout-shell.js` (stub: iframe host + ready log only)
- Modify: `firebase.json` (add `/chart-popout/**` rewrite, before the `**` catch-all)

**Interfaces:**
- Produces: a page at `/chart-popout/` that reads URL params, mounts a `<iframe id="pop-chart" src="/chart-engine/index.html">`, waits for `chart-engine-ready`, and exposes `window.__popout = { post(type,value), params }` where `post` does `iframe.contentWindow.postMessage(JSON.stringify({type,value}), '*')` and `params` = parsed URL query (`exch,token,tsym,tf,n`).

- [ ] **Step 1: Create `web/chart-popout/index.html`** — theme bootstrap copied from `web/lite/index.html` head (reads `flutter.userAppTheme`), full-viewport `<iframe id="pop-chart" src="/chart-engine/index.html" style="border:0;position:fixed;inset:0;width:100vw;height:100vh">`, and `<script src="popout-shell.js"></script>` at the end of body.

- [ ] **Step 2: Create `web/chart-popout/popout-shell.js` stub**

```javascript
'use strict';
(function () {
  const iframe = document.getElementById('pop-chart');
  const params = Object.fromEntries(new URLSearchParams(location.search));
  function post(type, value) {
    try { iframe.contentWindow.postMessage(JSON.stringify({ type, value }), '*'); } catch (_) {}
  }
  window.__popout = { post, params };
  window.addEventListener('message', (e) => {
    let d = e.data; if (typeof d === 'string') { try { d = JSON.parse(d); } catch (_) { return; } }
    if (!d || d.type !== 'chart-engine-ready') return;
    console.log('[popout] engine ready', params);
  });
})();
```

- [ ] **Step 3: Add firebase rewrite** — in `firebase.json` `hosting.rewrites`, ADD as the FIRST entry (before `{"source":"**","destination":"/index.html"}`):

```json
{ "source": "/chart-popout/**", "destination": "/chart-popout/index.html" }
```

- [ ] **Step 4: Verify** — `node --check web/chart-popout/popout-shell.js` (JS OK) and `node -e "JSON.parse(require('fs').readFileSync('firebase.json','utf8'))"` (valid). Manual: run the web app locally, open `/chart-popout/?exch=NSE&token=26000&tsym=NIFTY&tf=5&n=1`; the chart-engine iframe loads and the console logs `[popout] engine ready`. (No data yet — that's later tasks.) No commit.

---

### Task 2: Session bootstrap + session-expiry overlay

**Files:**
- Modify: `web/chart-popout/popout-shell.js`
- Create: `web/chart-popout/popout-shell.test.js`

**Interfaces:**
- Produces (all on `window.__popout`):
  - `readSession()` → `{uid, jKey}` reading `localStorage['flutter.clientId']`/`['flutter.clientSession']` (JSON-parse each; empty string if absent). 
  - `isSessionExpired(resp)` → `true` when `resp` (object, or first element if array) has `stat === 'Not_Ok'` and `String(emsg).toLowerCase().includes('session')`.
  - `feedUid(baseUid, n)` → `` `${baseUid}_${n}_TA` `` and `connectUid(baseUid, n)` → `` `${baseUid}_${n}_TA_TV` ``.
  - `showExpired()` → overlays a blocking full-screen "Session expired — sign in again in the main window" panel and sets `window.__popout.expired = true`.

- [ ] **Step 1: Write failing tests** in `web/chart-popout/popout-shell.test.js` — require the pure helpers via a small export shim (see Step 3) and assert:

```javascript
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
```

- [ ] **Step 2: Run tests, verify FAIL** — `node web/chart-popout/popout-shell.test.js` → fails (functions not exported).

- [ ] **Step 3: Implement** the helpers in `popout-shell.js`. Add pure functions and a dual-export footer so node can require them (mirror `aggregator.js`'s `if (typeof module !== 'undefined' && module.exports)` pattern), guarding all DOM access behind `typeof document !== 'undefined'`:

```javascript
function isSessionExpired(resp) {
  const o = Array.isArray(resp) ? (resp[0] || {}) : (resp || {});
  return o.stat === 'Not_Ok' && String(o.emsg || '').toLowerCase().includes('session');
}
function feedUid(baseUid, n) { return `${baseUid}_${n}_TA`; }
function connectUid(baseUid, n) { return `${baseUid}_${n}_TA_TV`; }
function _lsJson(key) {
  try { const r = localStorage.getItem(key); return r == null ? '' : (JSON.parse(r) ?? ''); }
  catch (_) { return ''; }
}
function readSession() { return { uid: _lsJson('flutter.clientId'), jKey: _lsJson('flutter.clientSession') }; }
// showExpired(): create a fixed, full-screen div (see spec §6 copy), set window.__popout.expired = true.
```

Footer: `if (typeof module !== 'undefined' && module.exports) module.exports = { isSessionExpired, feedUid, connectUid };`

- [ ] **Step 4: Wire bootstrap** — on script load, `const {uid, jKey} = readSession(); if (!uid || !jKey) showExpired();` else store on `window.__popout.session`.

- [ ] **Step 5: Run tests, verify PASS** — `node web/chart-popout/popout-shell.test.js` → `5 passed · 0 failed`. Manual: open the popout with a valid session (chart iframe still empty), then with `localStorage.removeItem('flutter.clientSession')` → the "Session expired" overlay shows. No commit.

---

### Task 3: History via TPSeries

**Files:**
- Modify: `web/chart-popout/popout-shell.js`, `web/chart-popout/popout-shell.test.js`

**Interfaces:**
- Consumes: `readSession()`, `isSessionExpired()`, `showExpired()`, `window.__popout.post`.
- Produces: `parseTpseries(rows)` → `[{ts,o,h,l,c,v}]` oldest→newest (`ts=int(ssboe)`, `o=into,h=inth,l=intl,c=intc,v=intv||0`, skipping rows without `stat:'Ok'`); and a `message` handler for `fetchHistory` that POSTs TPSeries and replies `historyResult`/`historyError`.

- [ ] **Step 1: Write failing test** for `parseTpseries` in `popout-shell.test.js`:

```javascript
const { parseTpseries } = require('./popout-shell.js');
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
```

- [ ] **Step 2: Run, verify FAIL** — `node web/chart-popout/popout-shell.test.js`.

- [ ] **Step 3: Implement** `parseTpseries` (sort ascending by `ts`; `Number()` the OHLCV; `v = Number(r.intv) || 0`) and add it to the module exports. Add the `fetchHistory` handler:

```javascript
async function _tpseries(req) {
  const { uid, jKey } = window.__popout.session;
  const j = { uid, exch: req.exch, token: String(req.token),
              st: String(req.start), et: String(req.end), intrv: req.interval };
  const body = 'jData=' + encodeURIComponent(JSON.stringify(j)) + '&jKey=' + encodeURIComponent(jKey);
  const res = await fetch('https://go.mynt.in/NorenWClientWeb/TPSeries',
    { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body });
  const data = await res.json();
  if (isSessionExpired(data)) { showExpired(); throw new Error('session'); }
  return parseTpseries(Array.isArray(data) ? data : []);
}
// in the message handler: case 'fetchHistory' -> _tpseries(value)
//   .then(candles => post('historyResult', { requestId: value.requestId, candles }))
//   .catch(err => post('historyError', { requestId: value.requestId, message: String(err) }));
```

- [ ] **Step 4: Run tests, verify PASS.** Manual: open the popout for a liquid symbol during/after market hours → historical candles render (fed by TPSeries). No commit.

---

### Task 4: Live feed — socket-session mint, connect, tick normalize + forward

**Files:**
- Modify: `web/chart-popout/popout-shell.js`, `web/chart-popout/popout-shell.test.js`

**Interfaces:**
- Consumes: `feedUid`, `connectUid`, `readSession`, `isSessionExpired`, `showExpired`, `post`.
- Produces: `normalizeTick(frame, nowSec)` → `{token, packet:{exch?,lp,v,ft,bp1,sp1}}` or `null` (bare touchline → packet with `v:0, ft:nowSec` synthesized; merges nothing — Task 5 owns the book); `mintSocketToken(baseUid,n)` (async → session string or `''`); and a `FeedClient` object (`connect()`, `send(obj)`, `close()`, `onTick`, `onOpenAck`) — connection lifecycle lands in Task 5, this task only proves connect + first ticks flow.

- [ ] **Step 1: Write failing test** for `normalizeTick`:

```javascript
const { normalizeTick } = require('./popout-shell.js');
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
```

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Implement** `normalizeTick` (accept `t` in `{tf,tk,df,dk}`; require `tk` and `lp!=null/''`; `lp=Number`, `bp1/sp1 = Number|undefined`, `v:0`, `ft:nowSec`), add to exports. Implement `mintSocketToken`:

```javascript
async function mintSocketToken(baseUid, n) {
  try {
    const res = await fetch('https://sess.mynt.in/generateSocketSession',
      { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ uid: feedUid(baseUid, n), src: 'TV', source: 'TV' }) });
    const j = await res.json();
    return (j && j.session) ? j.session : '';
  } catch (_) { return ''; }
}
```

Implement a minimal `FeedClient` that opens `new WebSocket('wss://ws.zebull.in/NorenWS/')`, on open sends the connect message (`{t:'c', uid:connectUid(baseUid,n), actid:connectUid(baseUid,n), source:'TV', susertoken:<token>}`), on message parses JSON: if `t==='ck'` call `onOpenAck()`, else `normalizeTick` → `onTick(packet)`. Wire `onTick` to `post('tick', {token, packet})`.

- [ ] **Step 4: Run tests, verify PASS.** Manual: open the popout; after history loads, the last candle updates live from `ws.zebull.in` (watch the LTP tick). No commit.

---

### Task 5: Subscription relay + reconnection discipline

**Files:**
- Modify: `web/chart-popout/popout-shell.js`, `web/chart-popout/popout-shell.test.js`

**Interfaces:**
- Consumes: `FeedClient`, `mintSocketToken`, `normalizeTick`.
- Produces: a `SubSet` manager `{add(key), remove(key), has(key), all()}` (dedup; `key` = `"exch|token"`); and a `FeedManager` that owns exactly one live `FeedClient`, relays engine `subscribe`/`unsubscribe` to the feed, re-subscribes `SubSet.all()` on (re)connect, force-closes+reconnects on close/error/stall, and drops frames from a non-current socket.

- [ ] **Step 1: Write failing tests** for `SubSet`:

```javascript
const { SubSet } = require('./popout-shell.js');
t('SubSet dedups and lists', () => {
  const s = new SubSet();
  s.add('NSE|26000'); s.add('NSE|26000'); s.add('MCX|1');
  assert.deepStrictEqual(s.all().sort(), ['MCX|1', 'NSE|26000']);
  s.remove('NSE|26000');
  assert.strictEqual(s.has('NSE|26000'), false);
  assert.deepStrictEqual(s.all(), ['MCX|1']);
});
```

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Implement** `SubSet` (wraps a `Set`) + `FeedManager`:
  - Relay: on engine `subscribe {exch,token}` → `SubSet.add`; if socket up, `send({t:'t', k:"exch|token"})`. On `unsubscribe` → `SubSet.remove`; if up, `send({t:'u', k:"exch|token"})`.
  - Connect: `mintSocketToken` → new `FeedClient`; on `onOpenAck` → `send({t:'t', k: SubSet.all().join('#')})` if non-empty.
  - Single socket: keep a `_gen` counter; each `FeedClient` captures its `gen`; ignore `onTick`/`onOpenAck` if `gen !== _gen`. `reconnect()` increments `_gen`, closes the old client, backs off (1s→cap 15s), then connects.
  - Stall watchdog: `setInterval` 2s; if last tick > 10s and socket open → `reconnect()`.
  - `onclose`/`onerror` from the current socket → `reconnect()`.
  - Add `SubSet` to module exports (for the test).

- [ ] **Step 4: Wire** the shell's `message` handler: route engine `subscribe`/`unsubscribe` into `FeedManager`; start `FeedManager` after `chart-engine-ready` + valid session.

- [ ] **Step 5: Run tests, verify PASS.** Manual: (a) open two popouts on different symbols → both stream live AND the main app keeps streaming (distinct `_n`); (b) in devtools, `window.__popout` — kill the socket (`.close()` the underlying WS) → it reconnects and the current symbol resumes; (c) block the network ~15s → stall watchdog reconnects. No commit.

---

### Task 6: Symbol search (independent symbol control)

**Files:**
- Modify: `web/chart-popout/index.html` (add a search input + results dropdown), `web/chart-popout/popout-shell.js`

**Interfaces:**
- Consumes: `readSession`, `isSessionExpired`, `showExpired`, `post`, `FeedManager`.
- Produces: `searchScrip(query)` → array of `{exch,token,tsym,dispName}`; and a UI handler that, on pick, posts `setPaneSymbol {paneId:'<the pane id>', scrip}` (the engine then emits `unsubscribe` old + `subscribe` new, which `FeedManager` relays) and re-requests history automatically (engine does this on `setSymbol`).

- [ ] **Step 1: Add the search box** to `index.html` — a top-left overlay `<input id="pop-search">` + `<div id="pop-results">` styled minimally (position:fixed, above the iframe).

- [ ] **Step 2: Implement `searchScrip`** in `popout-shell.js`:

```javascript
async function searchScrip(query) {
  const { uid, jKey } = window.__popout.session;
  const j = { uid, stext: query };
  const body = 'jData=' + encodeURIComponent(JSON.stringify(j)) + '&jKey=' + encodeURIComponent(jKey);
  const res = await fetch('https://ws.mynt.in/search/SearchScrip',
    { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body });
  const data = await res.json();
  if (isSessionExpired(data)) { showExpired(); return []; }
  return (data.values || []).map(v => ({ exch: v.exch, token: v.token, tsym: v.tsym, dispName: v.dname || v.tsym }));
}
```

(Confirm the SearchScrip request/response field names against `lib/api/market_watch_api.dart` `searchScrip*` and adjust `stext`/`values`/`dname` to match the app's usage.)

- [ ] **Step 3: Wire the UI** — debounce input (300ms) → `searchScrip` → render results; on click, `post('setPaneSymbol', {paneId, scrip:{exch,token,tsym,dispName,ls:1,ti:0.05,instname:''}})`, clear results. (Lot/tick are placeholders; the popout is view-only so exact `ls`/`ti` don't affect rendering.)

- [ ] **Step 4: Verify** — `node --check`. Manual: type a symbol in the popout search → results appear → pick one → chart switches symbol, history reloads (Task 3), live ticks switch to the new token (Task 5 relays the engine's unsubscribe/subscribe). No commit.

---

### Task 7: Flutter "Pop out" launcher + slot allocation

**Files:**
- Create: `lib/screens/web/chart_engine/utils/popout_launcher.dart`
- Modify: the chart toolbar widget that hosts the camera/settings actions (e.g. `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`) — add a "Pop out" icon button.

**Interfaces:**
- Consumes: `chartEngineSessionProvider` (active pane's `scrip` + `timeframeMinutes`).
- Produces: `openPopoutForPane({required ChartScrip scrip, required int timeframeMinutes})` — allocates the lowest-free `n` via a `localStorage` registry, builds the URL, and `window.open`s it.

- [ ] **Step 1: Implement `popout_launcher.dart`**:

```dart
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';

const _slotsKey = 'popoutSlots';

int _allocSlot() {
  List slots;
  try { slots = (json.decode(html.window.localStorage[_slotsKey] ?? '[]') as List); }
  catch (_) { slots = []; }
  var n = 1;
  final used = slots.map((e) => (e as num).toInt()).toSet();
  while (used.contains(n)) n++;
  used.add(n);
  html.window.localStorage[_slotsKey] = json.encode(used.toList()..sort());
  return n;
}

void openPopoutForPane({required ChartScrip scrip, required int timeframeMinutes}) {
  final n = _allocSlot();
  final qs = Uri(queryParameters: {
    'exch': scrip.exch, 'token': scrip.token, 'tsym': scrip.tsym,
    'tf': '$timeframeMinutes', 'n': '$n',
  }).query;
  html.window.open('/chart-popout/?$qs', 'mynt_popout_$n');
}
```

- [ ] **Step 2: Add slot-free on unload** in `web/chart-popout/popout-shell.js` — on `beforeunload`, read `popoutSlots`, remove `params.n`, write back (best-effort try/catch).

- [ ] **Step 3: Add the "Pop out" button** to the chart top bar — an icon button whose `onTap` reads the active pane from `chartEngineSessionProvider` and calls `openPopoutForPane(scrip: pane.scrip!, timeframeMinutes: pane.timeframeMinutes)` (guard `pane.scrip != null`).

- [ ] **Step 4: Verify** — `flutter analyze lib/screens/web/chart_engine/utils/popout_launcher.dart` (no errors). Manual: click "Pop out" on a chart → a new window opens on that symbol/timeframe; open a second → it gets `n=2` and streams independently; close the first → its slot frees (check `localStorage.popoutSlots`). No commit.

---

## Self-Review

**Spec coverage:** §1 architecture → Task 1; §2 files → Tasks 1–7; §3 session/config → Tasks 1–2; §4 feed/reconnect/subs → Tasks 4–5; §5 history/search → Tasks 3,6; §6 session-expiry → Task 2 (+ used in 3,4,6); §7 lifecycle/`_N` → Tasks 2,7; §8 out-of-scope → enforced (lite mode Task 1/5, no order code anywhere); §9 testing → each task's unit + manual steps. All covered.

**Placeholder scan:** none — every code step has real code; the two "confirm against existing app" notes (SearchScrip fields, setTheme) point to exact source files, not TODOs.

**Type consistency:** `feedUid`/`connectUid`/`isSessionExpired`/`parseTpseries`/`normalizeTick`/`SubSet`/`FeedManager`/`FeedClient` names are used consistently across tasks; bridge message types match the engine contract listed above (`fetchHistory`,`historyResult`,`tick`,`subscribe`,`unsubscribe`,`setPaneSymbol`,`setPaneTimeframe`,`setLiteMode`,`chart-engine-ready`).

## Open items to confirm during implementation (from spec risks)
1. `generateSocketSession` accepts the `_<n>_TA` uid and returns a distinct session per popout (2-popout manual test).
2. Browser CORS for `sess.mynt.in/generateSocketSession` (TPSeries/SearchScrip already browser-called by the app).
3. Exact `flutter.clientSession`/`flutter.clientId` JSON encoding, and SearchScrip request/response field names (`stext`/`values`/`dname`).
4. The single-pane `paneId` the engine assigns (mirror the Flutter shell's layout init) for `setPaneSymbol`/`setPaneTimeframe`.
