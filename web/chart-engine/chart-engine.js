'use strict';

// ---------------------------------------------------------------------------
// Chart Engine — bootstrap + pane registry + Flutter message bridge
//
// Phase 1: registry holds exactly one pane keyed 'main'. The HTML host
// already provides a single grid cell (#layout). Phase 2 will grow the
// grid to N cells when 'setLayout' messages arrive.
// ---------------------------------------------------------------------------

const params = new URLSearchParams(location.search);
let THEME = (params.get('theme') || 'dark').toLowerCase();

const panes = new Map();           // paneId -> Chart instance
const tokenToPanes = new Map();    // exch|token -> Set<paneId>

function tokenKey(exch, token) { return exch + '|' + token; }

// ---------------------------------------------------------------------------
// Splitter / resize state — independent of the Flutter store; we keep the
// per-layout track ratios here in the iframe and persist them to
// localStorage so the user's resize survives reloads.
// ---------------------------------------------------------------------------
const RATIOS_KEY = 'chartEngineRatiosV1';
let _ratios = {};            // { 'cols2': { columns: [1,1], rows: [1] }, ... }
let _currentLayoutId = null;
let _currentRatios = { columns: [1], rows: [1] };
let _splitters = [];
let _layoutResizeObserver = null;

(function loadRatios() {
  try {
    const raw = localStorage.getItem(RATIOS_KEY);
    if (raw) _ratios = JSON.parse(raw) || {};
  } catch (_) { _ratios = {}; }
})();

function saveRatios() {
  try { localStorage.setItem(RATIOS_KEY, JSON.stringify(_ratios)); } catch (_) {}
}

function parseTrackList(s) {
  // Plan layouts always use `1fr` tokens; treat any non-fr token as 1.
  return (s || '').split(/\s+/).filter(Boolean).map((t) => {
    const m = t.match(/^([\d.]+)fr$/);
    return m ? parseFloat(m[1]) : 1;
  });
}

function formatTrackList(arr) {
  return arr.map((v) => v.toFixed(4) + 'fr').join(' ');
}

// ---------------------------------------------------------------------------
// Layout reconciliation
// ---------------------------------------------------------------------------
function applyLayout(spec) {
  const layout = document.getElementById('layout');

  // Track ratios — prefer persisted ratios for this layout id if shape matches.
  const defCols = parseTrackList(spec.columns);
  const defRows = parseTrackList(spec.rows);
  const saved = _ratios[spec.id];
  const ratios = {
    columns: (saved && saved.columns && saved.columns.length === defCols.length)
        ? saved.columns.slice() : defCols,
    rows: (saved && saved.rows && saved.rows.length === defRows.length)
        ? saved.rows.slice() : defRows,
  };
  _currentLayoutId = spec.id;
  _currentRatios = ratios;

  layout.style.gridTemplateAreas = spec.areas;
  layout.style.gridTemplateRows = formatTrackList(ratios.rows);
  layout.style.gridTemplateColumns = formatTrackList(ratios.columns);
  layout.style.display = 'grid';

  // Determine desired pane ids ('0'..paneCount-1) and area letters.
  const desired = [];
  for (let i = 0; i < spec.paneCount; i++) {
    desired.push({
      id: String(i),
      letter: String.fromCharCode('a'.charCodeAt(0) + i),
    });
  }

  // Destroy panes that are no longer desired.
  const desiredIds = new Set(desired.map((d) => d.id));
  for (const id of Array.from(panes.keys())) {
    if (!desiredIds.has(id)) {
      const chart = panes.get(id);
      chart._dragOverlay = null;
      try { chart.destroy(); } catch (_) {}
      panes.delete(id);
      const el = document.getElementById('pane-' + id);
      if (el && el.parentNode) el.parentNode.removeChild(el);
      // Clean tokenToPanes references.
      for (const [k, set] of Array.from(tokenToPanes.entries())) {
        if (set.has(id)) {
          set.delete(id);
          if (set.size === 0) tokenToPanes.delete(k);
        }
      }
    }
  }

  // Create or reuse panes in the desired order.
  for (const { id, letter } of desired) {
    let container = document.getElementById('pane-' + id);
    if (!container) {
      container = document.createElement('div');
      container.className = 'pane';
      container.id = 'pane-' + id;
      layout.appendChild(container);
    }
    container.style.gridArea = letter;
    if (!panes.has(id)) {
      panes.set(id, buildChart(container, id));
    }
  }

  rebuildSplitters(layout);
  ensureLayoutResizeObserver(layout);
}

// ---------------------------------------------------------------------------
// Splitters
// ---------------------------------------------------------------------------
function rebuildSplitters(layout) {
  for (const sp of _splitters) {
    if (sp.el && sp.el.parentNode) sp.el.parentNode.removeChild(sp.el);
  }
  _splitters = [];

  for (let i = 0; i < _currentRatios.columns.length - 1; i++) {
    const el = document.createElement('div');
    el.className = 'splitter col';
    layout.appendChild(el);
    const sp = { el, axis: 'columns', index: i };
    _splitters.push(sp);
    attachSplitterDrag(layout, sp);
  }
  for (let i = 0; i < _currentRatios.rows.length - 1; i++) {
    const el = document.createElement('div');
    el.className = 'splitter row';
    layout.appendChild(el);
    const sp = { el, axis: 'rows', index: i };
    _splitters.push(sp);
    attachSplitterDrag(layout, sp);
  }

  positionSplitters(layout);
}

function positionSplitters(layout) {
  const rect = layout.getBoundingClientRect();
  if (rect.width === 0 || rect.height === 0) return;
  const cs = window.getComputedStyle(layout);
  const gap = parseFloat(cs.columnGap || cs.gap || '0') || 0;
  const rowGap = parseFloat(cs.rowGap || cs.gap || '0') || 0;

  const colSum = _currentRatios.columns.reduce((a, b) => a + b, 0);
  const rowSum = _currentRatios.rows.reduce((a, b) => a + b, 0);
  const totalGapW = gap * Math.max(0, _currentRatios.columns.length - 1);
  const totalGapH = rowGap * Math.max(0, _currentRatios.rows.length - 1);
  const availW = rect.width - totalGapW;
  const availH = rect.height - totalGapH;

  // Cumulative x positions of column boundaries (at the centre of each gap).
  let cx = 0;
  const colBoundaries = [];
  for (let i = 0; i < _currentRatios.columns.length - 1; i++) {
    cx += (_currentRatios.columns[i] / colSum) * availW;
    colBoundaries.push(cx + gap / 2);
    cx += gap;
  }
  let ry = 0;
  const rowBoundaries = [];
  for (let i = 0; i < _currentRatios.rows.length - 1; i++) {
    ry += (_currentRatios.rows[i] / rowSum) * availH;
    rowBoundaries.push(ry + rowGap / 2);
    ry += rowGap;
  }

  const HIT = 8;  // hit-area thickness in px
  for (const sp of _splitters) {
    if (sp.axis === 'columns') {
      const x = colBoundaries[sp.index];
      sp.el.style.left = (x - HIT / 2) + 'px';
      sp.el.style.top = '0';
      sp.el.style.width = HIT + 'px';
      sp.el.style.height = rect.height + 'px';
    } else {
      const y = rowBoundaries[sp.index];
      sp.el.style.left = '0';
      sp.el.style.top = (y - HIT / 2) + 'px';
      sp.el.style.width = rect.width + 'px';
      sp.el.style.height = HIT + 'px';
    }
  }
}

function attachSplitterDrag(layout, sp) {
  sp.el.addEventListener('mousedown', (e) => {
    e.preventDefault();
    e.stopPropagation();
    sp.el.classList.add('dragging');
    const startX = e.clientX, startY = e.clientY;
    const startA = _currentRatios[sp.axis][sp.index];
    const startB = _currentRatios[sp.axis][sp.index + 1];
    const total = startA + startB;
    const rect = layout.getBoundingClientRect();
    const cs = window.getComputedStyle(layout);
    const gap = parseFloat((sp.axis === 'columns' ? cs.columnGap : cs.rowGap) || cs.gap || '0') || 0;
    const tracks = _currentRatios[sp.axis];
    const totalGap = gap * Math.max(0, tracks.length - 1);
    const avail = (sp.axis === 'columns' ? rect.width : rect.height) - totalGap;
    const sumAll = tracks.reduce((a, b) => a + b, 0);
    const pairPx = (total / sumAll) * avail;

    const onMove = (ev) => {
      const delta = sp.axis === 'columns' ? ev.clientX - startX : ev.clientY - startY;
      if (pairPx <= 0) return;
      const ratioDelta = (delta / pairPx) * total;
      const minFr = 0.1;
      let newA = startA + ratioDelta;
      let newB = startB - ratioDelta;
      if (newA < minFr) { newA = minFr; newB = total - minFr; }
      if (newB < minFr) { newB = minFr; newA = total - minFr; }
      tracks[sp.index] = newA;
      tracks[sp.index + 1] = newB;
      if (sp.axis === 'columns') {
        layout.style.gridTemplateColumns = formatTrackList(tracks);
      } else {
        layout.style.gridTemplateRows = formatTrackList(tracks);
      }
      positionSplitters(layout);
    };
    const onUp = () => {
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onUp);
      sp.el.classList.remove('dragging');
      if (_currentLayoutId) {
        _ratios[_currentLayoutId] = {
          columns: _currentRatios.columns.slice(),
          rows: _currentRatios.rows.slice(),
        };
        saveRatios();
      }
    };
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
  });
}

function ensureLayoutResizeObserver(layout) {
  if (_layoutResizeObserver) return;
  _layoutResizeObserver = new ResizeObserver(() => positionSplitters(layout));
  _layoutResizeObserver.observe(layout);
}

function buildChart(container, paneId) {
  return new Chart({
    container,
    paneId,
    palette: getPalette(),
    requestHistory: (req) => postToParent({ type: 'fetchHistory', value: req }),
    subscribe: (sub) => {
      const key = tokenKey(sub.exch, sub.token);
      let set = tokenToPanes.get(key);
      if (!set) { set = new Set(); tokenToPanes.set(key, set); }
      if (!set.has(paneId)) {
        set.add(paneId);
        if (set.size === 1) postToParent({ type: 'subscribe', value: sub });
      }
    },
    unsubscribe: (sub) => {
      const key = tokenKey(sub.exch, sub.token);
      const set = tokenToPanes.get(key);
      if (!set) return;
      if (set.has(paneId)) {
        set.delete(paneId);
        if (set.size === 0) {
          tokenToPanes.delete(key);
          postToParent({ type: 'unsubscribe', value: sub });
        }
      }
    },
    // Phase 16 — Renko brick size echo. brickSize <= 0 / null means
    // "no longer renko" (Flutter will clear its cache for this pane).
    notifyBrickSize: (brickSize) => postToParent({
      type: 'paneRenkoBrickSize',
      value: { paneId, brickSize: brickSize == null ? 0 : brickSize },
    }),
  });
}

function applyActivePane(paneId) {
  for (const el of document.querySelectorAll('.pane')) {
    el.classList.toggle('active', el.id === 'pane-' + paneId);
  }
}

// ---------------------------------------------------------------------------
// Message bridge (iframe ⇄ Flutter parent)
//
// Outbound from iframe: ALWAYS a JSON string. Inbound from Flutter: accept
// both strings (preferred) and plain objects (defensive). See orderflow
// shell screen for the rationale (Dart Map ↔ JS Object round-trip is
// unreliable through dart:html postMessage).
// ---------------------------------------------------------------------------
function postToParent(message) {
  try { parent.postMessage(JSON.stringify(message), '*'); } catch (_) {}
}

window.addEventListener('message', (e) => {
  let d = e.data;
  if (typeof d === 'string') {
    try { d = JSON.parse(d); } catch (_) { return; }
  }
  if (!d || typeof d !== 'object' || typeof d.type !== 'string') return;
  handleMessage(d);
});

function handleMessage(d) {
  switch (d.type) {
    case 'setTheme':
      if (typeof d.value === 'string') {
        applyTheme(d.value);
        for (const chart of panes.values()) chart.setPalette(getPalette());
      }
      break;
    case 'setLayout': {
      const v = d.value || {};
      if (typeof v.paneCount !== 'number' || v.paneCount < 1) return;
      applyLayout(v);
      break;
    }
    case 'setActivePane': {
      const v = d.value || {};
      if (typeof v.paneId !== 'string') return;
      applyActivePane(v.paneId);
      break;
    }
    case 'setPaneSymbol': {
      const { paneId, scrip } = d.value || {};
      if (!paneId || !scrip) return;
      const chart = panes.get(paneId);
      if (chart) chart.setSymbol(scrip);
      break;
    }
    case 'setScripTradable': {
      const { paneId, tradable } = d.value || {};
      if (typeof paneId !== 'string' || typeof tradable !== 'boolean') return;
      const chart = panes.get(paneId);
      if (chart) chart.setScripTradable(tradable);
      break;
    }
    case 'setPaneTimeframe': {
      const { paneId, minutes } = d.value || {};
      if (!paneId || typeof minutes !== 'number') return;
      const chart = panes.get(paneId);
      if (chart) chart.setTimeframe(minutes);
      break;
    }
    case 'setOverlays': {
      const { paneId, ...flags } = d.value || {};
      if (paneId) {
        const chart = panes.get(paneId);
        if (chart) chart.setOverlays(flags);
      } else {
        for (const chart of panes.values()) chart.setOverlays(flags);
      }
      break;
    }
    case 'setPaneOverlays': {
      const { paneId, overlays } = d.value || {};
      if (typeof paneId !== 'string' || !Array.isArray(overlays)) return;
      const chart = panes.get(paneId);
      if (chart) chart.setPaneOverlays(overlays);
      break;
    }
    case 'setPaneQty': {
      const { paneId, qty } = d.value || {};
      if (typeof paneId !== 'string' || typeof qty !== 'number') return;
      const chart = panes.get(paneId);
      if (chart) chart.setQty(qty);
      break;
    }
    case 'unpinCrosshair': {
      const { paneId } = d.value || {};
      if (typeof paneId !== 'string') return;
      const chart = panes.get(paneId);
      if (chart) chart.unpinCrosshair();
      break;
    }
    case 'setPaneDrawings': {
      const { paneId, drawings } = d.value || {};
      if (typeof paneId !== 'string' || !Array.isArray(drawings)) return;
      const chart = panes.get(paneId);
      if (chart) chart.setDrawings(drawings);
      break;
    }
    case 'setPaneIndicators': {
      const { paneId, indicators } = d.value || {};
      if (typeof paneId !== 'string' || !Array.isArray(indicators)) return;
      const chart = panes.get(paneId);
      if (chart) chart.setIndicators(indicators);
      break;
    }
    case 'setPaneCandleStyle': {
      const { paneId, style } = d.value || {};
      if (typeof paneId !== 'string' || typeof style !== 'string') return;
      const chart = panes.get(paneId);
      if (chart) chart.setCandleStyle(style);
      break;
    }
    case 'setPaneHighLowMarkers': {
      const { paneId, show } = d.value || {};
      if (typeof paneId !== 'string' || typeof show !== 'boolean') return;
      const chart = panes.get(paneId);
      if (chart) chart.setShowHighLowMarkers(show);
      break;
    }
    case 'setPaneShowOptionChainOi': {
      const { paneId, show } = d.value || {};
      if (typeof paneId !== 'string' || typeof show !== 'boolean') return;
      const chart = panes.get(paneId);
      if (chart) chart.setShowOptionChainOi(show);
      break;
    }
    case 'setPaneShowBarCountdown': {
      const { paneId, show } = d.value || {};
      if (typeof paneId !== 'string' || typeof show !== 'boolean') return;
      const chart = panes.get(paneId);
      if (chart) chart.setShowBarCountdown(show);
      break;
    }
    case 'setPaneShowKeyLevels': {
      const { paneId, show } = d.value || {};
      if (typeof paneId !== 'string' || typeof show !== 'boolean') return;
      const chart = panes.get(paneId);
      if (chart) chart.setShowKeyLevels(show);
      break;
    }
    case 'setPanePivotVariant': {
      const { paneId, variant } = d.value || {};
      if (typeof paneId !== 'string' || typeof variant !== 'string') return;
      const chart = panes.get(paneId);
      if (chart) chart.setPivotVariant(variant);
      break;
    }
    case 'setPaneMagnetEnabled': {
      const { paneId, enabled } = d.value || {};
      if (typeof paneId !== 'string' || typeof enabled !== 'boolean') return;
      const chart = panes.get(paneId);
      if (chart) chart.setMagnetEnabled(enabled);
      break;
    }
    case 'setPaneShowVolumeProfile': {
      const { paneId, show } = d.value || {};
      if (typeof paneId !== 'string' || typeof show !== 'boolean') return;
      const chart = panes.get(paneId);
      if (chart) chart.setShowVolumeProfile(show);
      break;
    }
    case 'setDrawingsLocked': {
      const { locked } = d.value || {};
      const flag = locked === true;
      for (const chart of panes.values()) chart.setDrawingsLocked(flag);
      break;
    }
    case 'setDrawingsHidden': {
      const { hidden } = d.value || {};
      const flag = hidden === true;
      for (const chart of panes.values()) chart.setDrawingsHidden(flag);
      break;
    }
    case 'setPaneOiData': {
      const { paneId, strikes } = d.value || {};
      if (typeof paneId !== 'string' || !Array.isArray(strikes)) return;
      const chart = panes.get(paneId);
      if (chart) chart.setOiData(strikes);
      break;
    }
    case 'setDrawMode': {
      const { kind } = d.value || {};
      // null/undefined = exit draw mode. Broadcast to every pane so the user
      // can start drawing in whichever pane they click first.
      for (const chart of panes.values()) chart.setDrawMode(kind || null);
      break;
    }
    case 'setShortcutsEnabled': {
      const { enabled } = d.value || {};
      const flag = enabled === true;
      for (const chart of panes.values()) chart.setShortcutsEnabled(flag);
      break;
    }
    case 'historyResult': {
      const { requestId, candles } = d.value || {};
      for (const chart of panes.values()) chart.onHistoryResult(requestId, candles);
      break;
    }
    case 'historyError': {
      const { requestId, message } = d.value || {};
      for (const chart of panes.values()) chart.onHistoryError(requestId, message);
      break;
    }
    case 'tick': {
      const { token, packet } = d.value || {};
      if (!token || !packet) return;
      // token here is just the bare token; for routing we keyed by exch|token.
      // Flutter sends both via packet.exch when available, falling back to a
      // scan across registered tokens for this bare token.
      const exch = packet.exch;
      let key = exch ? tokenKey(exch, token) : null;
      let targets = key ? tokenToPanes.get(key) : null;
      if (!targets) {
        // Fallback: any pane subscribed to this token (regardless of exch).
        targets = new Set();
        for (const [k, set] of tokenToPanes.entries()) {
          if (k.endsWith('|' + token)) for (const id of set) targets.add(id);
        }
      }
      for (const id of targets) {
        const chart = panes.get(id);
        if (chart) chart.ingestTick(packet);
      }
      break;
    }
    case 'setPaneShowAutoPattern': {
      const { paneId, show } = d.value || {};
      if (typeof paneId !== 'string' || typeof show !== 'boolean') return;
      const chart = panes.get(paneId);
      if (chart) chart.setShowAutoPattern(show);
      break;
    }
    case 'setPaneShowCrosshairLines': {
      const { paneId, show } = d.value || {};
      if (typeof paneId !== 'string' || typeof show !== 'boolean') return;
      const chart = panes.get(paneId);
      if (chart) chart.setShowCrosshairLines(show);
      break;
    }
    case 'takeScreenshot': {
      const { paneId } = d.value || {};
      if (typeof paneId !== 'string') return;
      const chart = panes.get(paneId);
      if (chart) chart.takeScreenshot();
      break;
    }
    case 'setChartPalette': {
      const { palette } = d.value || {};
      if (palette && typeof palette === 'object') {
        // Broadcast to every pane so all charts share the same palette
        // (per-pane palette would be a separate phase).
        for (const chart of panes.values()) {
          if (typeof chart.setPalette === 'function') {
            chart.setPalette(palette);
          }
        }
      }
      break;
    }
    default:
      // Unknown message types are silently ignored (forward-compat with later phases).
      break;
  }
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------
function boot() {
  applyTheme(THEME);
  // No default pane — wait for the first setLayout from Flutter.
  // (Flutter's shell ALWAYS posts setLayout on the ready handshake.)
  postToParent({ type: 'chart-engine-ready' });
}

window.addEventListener('load', boot);

// Make the body focusable so the parent's HtmlElementView starts routing
// pointer events into us immediately. Same fix as the orderflow chart.
document.body.tabIndex = -1;

function _grabFocus() {
  // Don't steal focus when an interactive element already has it — the
  // top-bar Symbol typeahead lives inside this same iframe and any
  // `document.body.focus()` call below would blur it, killing keystrokes
  // and closing the result popover as the user moves the mouse around.
  // Inputs, textareas and contentEditable surfaces all qualify.
  try {
    const ae = document.activeElement;
    if (ae && ae !== document.body) {
      const tag = ae.tagName;
      if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
      if (ae.isContentEditable) return;
    }
    window.focus();
    document.body.focus();
  } catch (_) {}
}

window.addEventListener('load', _grabFocus);

// Re-grab focus whenever the cursor enters the iframe — Flutter Web's
// HtmlElementView occasionally leaves the iframe out of the hit region
// after the first paint, and this nudges focus back so wheel/keyboard
// events get delivered inside the chart without needing an explicit click.
document.addEventListener('mouseenter', _grabFocus, true);

// Belt-and-braces for the "cursor was already over the chart at load time"
// case where no mouseenter fires. The first mousemove inside the iframe
// also triggers focus, then deregisters itself to avoid churn.
function _firstMoveFocus() {
  _grabFocus();
  document.removeEventListener('mousemove', _firstMoveFocus, true);
  document.removeEventListener('pointerover', _firstMoveFocus, true);
}
document.addEventListener('mousemove', _firstMoveFocus, true);
document.addEventListener('pointerover', _firstMoveFocus, true);

// Final fallback: actively re-grab focus on a short timer for the first
// 3 seconds after load. Covers race conditions where the iframe loads
// before Flutter has hooked up the HtmlElementView's pointer-hit region.
let _focusPollCount = 0;
const _focusPoll = setInterval(() => {
  _grabFocus();
  _focusPollCount += 1;
  if (_focusPollCount >= 6) clearInterval(_focusPoll); // 6 × 500ms = 3s
}, 500);

// ---------------------------------------------------------------------------
// Public surface for the HTML top bar (`topbar.js` + per-control modules).
// Keep this thin — only what the top bar genuinely needs. Anything broader
// belongs in the bridge protocol.
// ---------------------------------------------------------------------------
window.chartEngine = {
  /// Looks up the currently active pane via the DOM marker that
  /// `applyActivePane` sets. Returns null when nothing is active (e.g.
  /// before the first `setActivePane` message arrives).
  activeChart() {
    const el = document.querySelector('.pane.active');
    if (!el || !el.id || !el.id.startsWith('pane-')) return null;
    return panes.get(el.id.slice('pane-'.length)) || null;
  },
};
