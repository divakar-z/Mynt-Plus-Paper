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
    window.addEventListener('message', (e) => {
      let d = e.data; if (typeof d === 'string') { try { d = JSON.parse(d); } catch (_) { return; } }
      if (!d || !d.type) return;
      if (d.type === 'chart-engine-ready') {
        console.log('[popout] engine ready', params);
        return;
      }
      if (d.type === 'fetchHistory') {
        const value = d.value || {};
        _tpseries(value)
          .then((candles) => post('historyResult', { requestId: value.requestId, candles }))
          .catch((err) => post('historyError', { requestId: value.requestId, message: String(err) }));
      }
    });

    // Session bootstrap: block with the expiry overlay if no session is present.
    const { uid, jKey } = readSession();
    if (!uid || !jKey) {
      showExpired();
    } else {
      window.__popout.session = { uid, jKey };
    }
  }

  // Expose for browser global scope (no module system in iframe) and node tests.
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { isSessionExpired, feedUid, connectUid, readSession, showExpired, parseTpseries };
  }
})();
