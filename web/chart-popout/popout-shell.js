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
    const body = 'jData=' + encodeURIComponent(JSON.stringify(j)) + '&jKey=' + encodeURIComponent(jKey);
    const res = await fetch('https://go.mynt.in/NorenWClientWeb/TPSeries',
      { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body });
    const data = await res.json();
    if (isSessionExpired(data)) { showExpired(); throw new Error('session'); }
    return parseTpseries(Array.isArray(data) ? data : []);
  }

  // Pure: maps raw SearchScrip `values[]` rows to the shape the engine's
  // setPaneSymbol `scrip` wants. Real ls/ti/instname now come from the
  // response (not placeholders) with safe numeric fallbacks.
  function mapScripValues(values) {
    return (Array.isArray(values) ? values : []).map((v) => ({
      exch: v.exch,
      token: v.token,
      tsym: v.tsym,
      dispName: v.dname || v.tsym,
      ls: Number(v.ls) || 1,
      ti: Number(v.ti) || 0.05,
      instname: v.instname || '',
    }));
  }

  async function searchScrip(query) {
    const { uid, jKey } = window.__popout.session;
    const j = { uid, stext: query };
    const body = 'jData=' + encodeURIComponent(JSON.stringify(j)) + '&jKey=' + encodeURIComponent(jKey);
    const res = await fetch('https://go.mynt.in/NorenWClientWeb/SearchScrip',
      { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body });
    const data = await res.json();
    if (isSessionExpired(data)) { showExpired(); return []; }
    return mapScripValues(data.values);
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
            if (self._watchdog) { clearInterval(self._watchdog); self._watchdog = null; }
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
      if (this.client) { this.client.close(); }
      const wait = this._backoff;
      this._backoff = Math.min(this._backoff * 2, 15000);
      const self = this;
      setTimeout(function () {
        if (gen !== self._gen) return; // superseded by a newer reconnect
        self._open();
      }, wait);
    };

    let feedManager = null;

    window.addEventListener('message', (e) => {
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
        post('setLiteMode', { value: true });
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

    // Symbol search UI: debounced input -> searchScrip -> clickable results.
    // On pick, post setPaneSymbol — the engine emits unsubscribe old +
    // subscribe new on its own (FeedManager relays via the message
    // listener above); this handler does not touch feedManager directly.
    (function wireSearchUi() {
      const searchInput = document.getElementById('pop-search');
      const resultsEl = document.getElementById('pop-results');
      if (!searchInput || !resultsEl) return;
      let debounceTimer = null;
      // Monotonic sequence guard: the 300ms debounce only prevents
      // overlapping TIMERS, not overlapping in-flight requests. If an
      // older query's response resolves after a newer one, drop it so the
      // dropdown never shows results for a stale/narrower query.
      let searchSeq = 0;

      function hideResults() {
        resultsEl.innerHTML = '';
        resultsEl.style.display = 'none';
      }

      function renderResults(list) {
        resultsEl.innerHTML = '';
        if (!list || !list.length) { hideResults(); return; }
        list.forEach((scrip) => {
          const row = document.createElement('div');
          row.className = 'pop-result-row';
          row.textContent = scrip.dispName + ' · ' + scrip.exch;
          row.addEventListener('click', () => {
            post('setPaneSymbol', { paneId: '0', scrip });
            searchInput.value = '';
            hideResults();
          });
          resultsEl.appendChild(row);
        });
        resultsEl.style.display = 'block';
      }

      searchInput.addEventListener('input', () => {
        const q = searchInput.value.trim();
        if (debounceTimer) clearTimeout(debounceTimer);
        if (!q) { searchSeq += 1; hideResults(); return; }
        debounceTimer = setTimeout(() => {
          if (window.__popout.expired) return;
          const mySeq = ++searchSeq;
          searchScrip(q)
            .then((list) => { if (mySeq === searchSeq) renderResults(list); })
            .catch(() => { if (mySeq === searchSeq) hideResults(); });
        }, 300);
      });

      document.addEventListener('click', (e) => {
        if (e.target !== searchInput && !resultsEl.contains(e.target)) hideResults();
      });
    })();
  }

  // Expose for browser global scope (no module system in iframe) and node tests.
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
      isSessionExpired, feedUid, connectUid, readSession, showExpired, parseTpseries,
      normalizeTick, mintSocketToken, createFeedClient, SubSet, mapScripValues, searchScrip,
    };
  }
})();
