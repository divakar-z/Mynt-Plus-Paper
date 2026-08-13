'use strict';
(function () {
  function isSessionExpired(resp) {
    const o = Array.isArray(resp) ? (resp[0] || {}) : (resp || {});
    return o.stat === 'Not_Ok' && String(o.emsg || '').toLowerCase().includes('session');
  }
  function feedUid(baseUid, n) { return `${baseUid}_${n}_TA`; }
  function connectUid(baseUid, n) { return `${baseUid}_${n}_TA_TV`; }
  function _lsJson(key) {
    try {
      const r = localStorage.getItem(key);
      return r == null ? '' : (JSON.parse(r) ?? '');
    } catch (_) { return ''; }
  }
  function readSession() { return { uid: _lsJson('flutter.clientId'), jKey: _lsJson('flutter.clientSession') }; }

  function parseTpseries(rows) {
    return (Array.isArray(rows) ? rows : [])
      .filter((r) => r && r.stat === 'Ok')
      .map((r) => ({
        ts: parseInt(r.ssboe, 10),
        o: Number(r.into),
        h: Number(r.inth),
        l: Number(r.intl),
        c: Number(r.intc),
        v: Number(r.intv) || 0,
      }))
      .sort((a, b) => a.ts - b.ts);
  }

  async function _tpseries(req) {
    const { uid, jKey } = window.__popout.session;
    const j = { uid, exch: req.exch, token: String(req.token),
                st: String(req.start), et: String(req.end), intrv: req.interval };
    // Match the app verbatim (market_watch_api.getTPSeriesChart): raw JSON in
    // jData (NOT url-encoded) + Content-Type application/json (Noren quirk —
    // the body is jData=<rawjson>&jKey=<key> yet the header says json).
    const body = 'jData=' + JSON.stringify(j) + '&jKey=' + jKey;
    const res = await fetch('https://go.mynt.in/NorenWClientWeb/TPSeries',
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body });
    const data = await res.json();
    if (isSessionExpired(data)) { showExpired(); throw new Error('session'); }
    return parseTpseries(Array.isArray(data) ? data : []);
  }

  // Symbol search for the engine's native topbar (loopback host). The
  // topbar's `searchSymbols` bridge request expects RAW Noren SearchScrip
  // `values[]` rows back (it reads `dname`/`exch`/`token`/`tsym`/`ls`/`ti`/
  // `instname`/`symbol` directly off each row) — do NOT remap them.
  async function searchScripRaw(query) {
    const { uid, jKey } = window.__popout.session;
    const j = { uid, stext: query };
    // Match the app verbatim (market_watch_api.getSearchScrip): raw JSON in
    // jData + Content-Type application/json.
    const body = 'jData=' + JSON.stringify(j) + '&jKey=' + jKey;
    const res = await fetch('https://go.mynt.in/NorenWClientWeb/SearchScrip',
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body });
    const data = await res.json();
    if (isSessionExpired(data)) { showExpired(); return []; }
    return data.values || [];
  }

  // Pure: translates a topbar outbound bridge message into the engine's
  // inbound `{type, value}` shape (a "loopback host" — the popout has no
  // Flutter host to round-trip through, so it answers the topbar itself).
  // paneId is always '0' (single-pane popout). Returns null for anything
  // not mapped here (indicators/settings-gear stay deferred; search is
  // handled separately via the reply protocol; layout is hidden in the
  // popout topbar).
  function topbarToEngine(type, value) {
    const v = value || {};
    switch (type) {
      case 'setActivePaneSymbol':        return { type: 'setPaneSymbol',            value: { paneId: '0', scrip: v.scrip } };
      case 'setActiveTimeframe':         return { type: 'setPaneTimeframe',         value: { paneId: '0', minutes: Number(v.minutes) } };
      case 'setActiveCandleStyle':       return { type: 'setPaneCandleStyle',       value: { paneId: '0', style: String(v.style) } };
      case 'setActiveShowCrosshairLines':return { type: 'setPaneShowCrosshairLines',value: { paneId: '0', show: v.value === true } };
      case 'setActiveDrawTool':          return { type: 'setDrawMode',              value: { kind: v.kind != null ? v.kind : null } };
      case 'setDrawingsLocked':          return { type: 'setDrawingsLocked',        value: { locked: v.value === true } };
      case 'setDrawingsHidden':          return { type: 'setDrawingsHidden',        value: { hidden: v.value === true } };
      case 'clearDrawingsForActivePane': return { type: 'setPaneDrawings',          value: { paneId: '0', drawings: [] } };
      case 'updateChartPalette':         return { type: 'setChartPalette',          value: { palette: v } };
      default: return null;
    }
  }

  function normalizeTick(frame, nowSec) {
    if (!frame || !['tf', 'tk', 'df', 'dk'].includes(frame.t)) return null;
    if (frame.tk == null || frame.lp == null || frame.lp === '') return null;
    const packet = {
      lp: Number(frame.lp),
      v: 0,
      ft: nowSec,
      bp1: frame.bp1 != null ? Number(frame.bp1) : undefined,
      sp1: frame.sp1 != null ? Number(frame.sp1) : undefined,
    };
    const exch = frame.exch != null ? frame.exch : frame.e;
    if (exch != null) packet.exch = exch;
    return { token: String(frame.tk), packet };
  }

  async function mintSocketToken(baseUid, n) {
    try {
      const res = await fetch('https://sess.mynt.in/generateSocketSession',
        { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ uid: feedUid(baseUid, n), src: 'TV', source: 'TV' }) });
      const j = await res.json();
      return (j && j.session) ? j.session : '';
    } catch (_) { return ''; }
  }

  function createFeedClient(baseUid, n, token) {
    const client = { onTick: null, onOpenAck: null, onClose: null, onError: null, _ws: null };
    client.connect = function () {
      const ws = new WebSocket('wss://ws.zebull.in/NorenWS/');
      client._ws = ws;
      ws.onopen = function () {
        client.send({
          t: 'c',
          uid: connectUid(baseUid, n),
          actid: connectUid(baseUid, n),
          source: 'TV',
          susertoken: token,
        });
      };
      ws.onmessage = function (evt) {
        let frame;
        try { frame = JSON.parse(evt.data); } catch (_) { return; }
        if (frame && frame.t === 'ck') {
          if (client.onOpenAck) client.onOpenAck();
          return;
        }
        const result = normalizeTick(frame, Math.floor(Date.now() / 1000));
        if (result && client.onTick) client.onTick(result);
      };
      ws.onclose = function () {
        if (client.onClose) client.onClose();
      };
      ws.onerror = function (err) {
        if (client.onError) client.onError(err);
      };
    };
    client.send = function (obj) {
      try { client._ws && client._ws.send(JSON.stringify(obj)); } catch (_) {}
    };
    client.close = function () {
      try { client._ws && client._ws.close(); } catch (_) {}
    };
    return client;
  }

  // SubSet: dedup tracker of "exch|token" subscription keys. Pure — no DOM/timers.
  function SubSet() {
    this._set = new Set();
  }
  SubSet.prototype.add = function (key) { this._set.add(key); };
  SubSet.prototype.remove = function (key) { this._set.delete(key); };
  SubSet.prototype.has = function (key) { return this._set.has(key); };
  SubSet.prototype.all = function () { return Array.from(this._set); };

  function showExpired() {
    if (typeof document === 'undefined') return;
    try {
      const div = document.createElement('div');
      div.id = 'popout-session-expired';
      div.style.cssText = 'position:fixed;inset:0;z-index:2147483647;background:#0b0b0f;color:#fff;' +
        'display:flex;align-items:center;justify-content:center;font:16px/1.4 sans-serif;text-align:center;padding:24px;';
      div.textContent = 'Session expired — sign in again in the main window';
      document.body.appendChild(div);
    } catch (_) {}
    window.__popout = window.__popout || {};
    window.__popout.expired = true;
    // Stop the feed too (spec §6) — an expired session means the popout is
    // done fetching; the watchdog/reconnect loop must not keep running
    // (and possibly re-minting) against a dead session.
    if (window.__popout && window.__popout.feed && typeof window.__popout.feed.stop === 'function') {
      window.__popout.feed.stop();
    }
  }

  if (typeof document !== 'undefined') {
    const iframe = document.getElementById('pop-chart');
    const params = Object.fromEntries(new URLSearchParams(location.search));
    function post(type, value) {
      try { iframe.contentWindow.postMessage(JSON.stringify({ type, value }), '*'); } catch (_) {}
    }
    window.__popout = { post, params };

    // FeedManager: the SINGLE owner of the live FeedClient. Relays engine
    // subscribe/unsubscribe, re-subscribes the tracked set on (re)connect,
    // and force-reconnects on close/error/stall. Browser-only (WebSocket via
    // createFeedClient, setInterval, Date.now); not node-requirable.
    function FeedManager(baseUid, n) {
      this.baseUid = baseUid;
      this.n = n;
      this.subs = new SubSet();
      this.client = null;
      this._gen = 0;
      this._up = false; // true once the current client has acked ('ck')
      this._backoff = 1000; // ms; doubles per consecutive failure, cap 15000
      this._lastTickAt = 0;
      this._watchdog = null;
      this._emptyMintCount = 0;
      this._heartbeat = null; // {t:'h'} ping every 5s while connected
    }
    FeedManager.prototype.start = function () {
      if (!this._watchdog) {
        const self = this;
        this._watchdog = setInterval(function () {
          if (self._up && self._lastTickAt && (Date.now() - self._lastTickAt > 10000)) {
            self.reconnect();
          }
        }, 2000);
      }
      this._open();
    };
    FeedManager.prototype.subscribe = function (exch, token) {
      const key = `${exch}|${token}`;
      this.subs.add(key);
      if (this._up && this.client) this.client.send({ t: 't', k: key });
    };
    FeedManager.prototype.unsubscribe = function (exch, token) {
      const key = `${exch}|${token}`;
      this.subs.remove(key);
      if (this._up && this.client) this.client.send({ t: 'u', k: key });
    };
    // Opens a brand-new generation immediately (no backoff delay). Used by
    // start() and, after a backoff wait, by reconnect().
    FeedManager.prototype._open = function () {
      this._gen += 1;
      const gen = this._gen;
      this._up = false;
      if (this.client) { this.client.close(); }
      const self = this;
      mintSocketToken(this.baseUid, this.n).then(function (token) {
        if (gen !== self._gen) return; // superseded by a newer generation
        if (!token) {
          self._emptyMintCount += 1;
          if (self._emptyMintCount >= 3) {
            self.stop();
            showExpired();
            return;
          }
          self.reconnect();
          return;
        }
        self._emptyMintCount = 0;
        const client = createFeedClient(self.baseUid, self.n, token);
        client.onTick = function (result) {
          if (gen !== self._gen) return;
          self._lastTickAt = Date.now();
          post('tick', { token: result.token, packet: result.packet });
        };
        client.onOpenAck = function () {
          if (gen !== self._gen) return;
          self._up = true;
          self._backoff = 1000;
          self._lastTickAt = Date.now();
          const all = self.subs.all();
          if (all.length) client.send({ t: 't', k: all.join('#') });
          // Heartbeat: Noren closes an idle socket quickly, so ping every 5s.
          if (self._heartbeat) clearInterval(self._heartbeat);
          self._heartbeat = setInterval(function () {
            if (gen === self._gen && self._up && self.client) self.client.send({ t: 'h' });
          }, 5000);
        };
        client.onClose = function () {
          if (gen !== self._gen) return;
          self._up = false;
          self.reconnect();
        };
        client.onError = function () {
          if (gen !== self._gen) return;
          self._up = false;
          self.reconnect();
        };
        self.client = client;
        client.connect();
      }).catch(function () {
        if (gen === self._gen) self.reconnect();
      });
    };
    // reconnect(): bumps generation (invalidating the dying client's
    // callbacks), closes it (close-before-connect), then re-opens after the
    // current backoff, doubling backoff (capped 15s) for next time.
    FeedManager.prototype.reconnect = function () {
      this._gen += 1;
      const gen = this._gen;
      this._up = false;
      if (this._heartbeat) { clearInterval(this._heartbeat); this._heartbeat = null; }
      if (this.client) { this.client.close(); }
      const wait = this._backoff;
      this._backoff = Math.min(this._backoff * 2, 15000);
      const self = this;
      setTimeout(function () {
        if (gen !== self._gen) return; // superseded by a newer reconnect
        self._open();
      }, wait);
    };
    // stop(): permanent teardown — clears the watchdog, closes the current
    // client, and bumps the generation so any in-flight open()/reconnect()
    // continuation is a no-op. Reuses the same teardown the 3-strike
    // empty-mint path in _open() already performs before calling
    // showExpired(); that path now calls stop() too instead of duplicating it.
    FeedManager.prototype.stop = function () {
      this._gen += 1;
      if (this._watchdog) { clearInterval(this._watchdog); this._watchdog = null; }
      if (this._heartbeat) { clearInterval(this._heartbeat); this._heartbeat = null; }
      if (this.client) { this.client.close(); this.client = null; }
      this._up = false;
    };

    let feedManager = null;

    window.addEventListener('message', (e) => {
      // Only trust messages from the engine iframe itself — an unrelated
      // window/extension posting into this popout should never be able to
      // drive the boot handshake or feed relay.
      if (iframe && e.source !== iframe.contentWindow) return;
      let d = e.data; if (typeof d === 'string') { try { d = JSON.parse(d); } catch (_) { return; } }
      if (!d || !d.type) return;
      if (d.type === 'chart-engine-ready') {
        console.log('[popout] engine ready', params);
        // Initial boot handshake — mirrors the app's lite host
        // (lib/screens/web/chart_engine/widgets/lite_chart_iframe_host.dart
        // _bootstrap), plus this popout's own per-pane symbol/timeframe from
        // the URL params. The engine applies setPaneSymbol and emits
        // fetchHistory (Task 3) + subscribe (Task 5 relays) on its own.
        const theme = document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
        post('setTheme', theme);
        // NOTE: no setLiteMode here — the iframe src carries `?popout=1`
        // (see index.html), which the engine reads at module top and
        // applies to every pane as it's created. Posting setLiteMode would
        // both be a no-op (panes are empty when this handshake runs) and
        // semantically wrong for popout (plain lite hides the indicator
        // chips/drawing rail the popout is supposed to keep).
        // Single pane — area 'a', id '0'. Mirrors lite_chart_iframe_host.dart's
        // _bootstrap encodeSetLayout call verbatim (chart-engine.js's
        // applyLayout constructs panes with stringified integer ids
        // ('0', '1', ...) and area letters starting at 'a').
        post('setLayout', {
          id: 'single-explain',
          areas: '"a"',
          rows: '1fr',
          columns: '1fr',
          paneCount: 1,
        });
        post('setPaneSymbol', {
          paneId: '0',
          scrip: {
            exch: params.exch,
            token: params.token,
            tsym: params.tsym,
            dispName: params.tsym,
            ls: 1,
            ti: 0.05,
            instname: '',
          },
        });
        post('setPaneTimeframe', { paneId: '0', minutes: Number(params.tf) || 5 });
        // Mirror the boot state into the engine's native topbar too, so it
        // shows the right timeframe/symbol instead of its own defaults
        // (the topbar has no Flutter host to sync from in the popout).
        post('setActivePaneTopBarState', {
          timeframeMinutes: Number(params.tf) || 5,
          candleStyle: 'candles',
          showCrosshairLines: true,
          indicators: [],
        });
        post('setActivePaneSymbol', {
          scrip: { exch: params.exch, token: params.token, tsym: params.tsym, dispName: params.tsym, ls: 1, ti: 0.05, instname: '' },
        });
        if (feedManager) feedManager.start();
        return;
      }
      if (d.type === 'fetchHistory') {
        const value = d.value || {};
        _tpseries(value)
          .then((candles) => post('historyResult', { requestId: value.requestId, candles }))
          .catch((err) => post('historyError', { requestId: value.requestId, message: String(err) }));
        return;
      }
      if (d.type === 'subscribe') {
        const value = d.value || {};
        if (feedManager && value.exch != null && value.token != null) {
          feedManager.subscribe(value.exch, value.token);
        }
        return;
      }
      if (d.type === 'unsubscribe') {
        const value = d.value || {};
        if (feedManager && value.exch != null && value.token != null) {
          feedManager.unsubscribe(value.exch, value.token);
        }
        return;
      }
      // Symbol search (reply protocol): the topbar's `searchSymbols` is a
      // request carrying `d.replyTo` and expects a `{type:'reply', value:
      // {replyId, payload}}` message posted back into the iframe.
      if (d.type === 'searchSymbols') {
        const q = (d.value && d.value.q) || '';
        searchScripRaw(q)
          .then((results) => post('reply', { replyId: d.replyTo, payload: { results } }))
          .catch(() => post('reply', { replyId: d.replyTo, payload: { results: [] } }));
        return;
      }
      // Loopback host: translate any other mapped topbar outbound message
      // into the engine's inbound message and relay it straight into the
      // iframe (the popout has no Flutter host to round-trip through).
      const mapped = topbarToEngine(d.type, d.value);
      if (mapped) { post(mapped.type, mapped.value); return; }
    });

    // Free this popout's slot when the window/tab closes, so a later
    // popout can reuse the lowest-free `n` again. Best-effort — never
    // block unload on storage errors.
    window.addEventListener('beforeunload', () => {
      try {
        const n = Number(params.n);
        if (!n) return;
        const slots = (JSON.parse(localStorage.getItem('popoutSlots') || '[]') || [])
          .map(Number)
          .filter((x) => x !== n);
        localStorage.setItem('popoutSlots', JSON.stringify(slots));
      } catch (_) {}
    });

    // Session bootstrap: block with the expiry overlay if no session is present.
    const { uid, jKey } = readSession();
    if (!uid || !jKey) {
      showExpired();
    } else {
      window.__popout.session = { uid, jKey };
      const n = params.n != null ? params.n : 1;
      feedManager = new FeedManager(uid, n);
      window.__popout.feed = feedManager;
    }
  }

  // Expose for browser global scope (no module system in iframe) and node tests.
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
      isSessionExpired, feedUid, connectUid, readSession, showExpired, parseTpseries,
      normalizeTick, mintSocketToken, createFeedClient, SubSet, searchScripRaw, topbarToEngine,
    };
  }
})();
