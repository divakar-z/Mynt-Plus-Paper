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
