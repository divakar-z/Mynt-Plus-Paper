// ============================================================================
//  Orderflow footprint chart — vanilla JS / canvas
//  Self-contained: no build step, no deps. Loaded into a Flutter HtmlElementView
//  iframe. Parent (Flutter shell) sends symbol/timeframe via postMessage; we
//  read initial state from URL params.
// ============================================================================

'use strict';

// ---------------------------------------------------------------------------
// CONFIG
// ---------------------------------------------------------------------------
const params = new URLSearchParams(location.search);
const API_BASE = params.get('base') || 'http://192.168.5.47:8000';
const WS_BASE = API_BASE.replace(/^http/, 'ws');
const TIMEFRAME_MS = {
  '5s': 5000, '15s': 15000, '30s': 30000,
  '1m': 60000, '5m': 300000, '15m': 900000, '1h': 3600000,
};
const PRICE_STEP = {
  NIFTY: 1, BANKNIFTY: 1, SENSEX: 1,
  GOLD: 1, SILVER: 1, CRUDEOIL: 1, NATURALGAS: 0.1,
};
let SYMBOL = (params.get('sym') || 'NIFTY').toUpperCase();
let TIMEFRAME = params.get('tf') || '1m';
let THEME = (params.get('theme') || 'dark').toLowerCase(); // 'dark' | 'light'

// ---------------------------------------------------------------------------
// STATE
// ---------------------------------------------------------------------------
let candles = [];          // [{ ts, open, high, low, close, nodes: Map<price, {bid,ask}>, maxNode }]
let structure = {
  profile: { poc: null, val: null, vah: null, hvn_levels: [], lvn_levels: [], total_volume: 0 },
  imbalances: [],
  session_cd: 0,
};
let tickState = { lp: null, v: null, bb: null, ba: null, ft: null };
let aggState = { prevCumVol: null, prevPrice: null, prevMs: null };
let lastTickAt = 0;
let historyPackets = 0, historyApplied = 0, wsPackets = 0, wsApplied = 0;

// Per-candle CD is pure local cumulative delta starting at 0 from the first
// loaded candle — first candle's CD == its own Δ, subsequent candles add
// their Δ to the previous CD. No anchor to backend session_cd (which would
// inflate every candle by a hidden prefix the user can't see and break the
// intuition that "CD of candle N = sum of Δs of candles 0..N").

// Hover state for the crosshair + OHLC readout.
const hover = { x: null, y: null, inside: false };

// Overlay visibility — driven by the Settings popup in the Flutter shell.
// Defaults are ON; the shell re-pushes on each iframe-ready handshake.
const overlays = { imb: true, poc: true, va: true, vwap: true, grid: true };

// Render geometry & view (pan/zoom).
// Layout per candle column (left → right): [sell-cell] [centre-wick] [buy-cell].
// Each price level is its own *fixed-height* row — same approach as the React
// reference. cellW is the total column width; centerW/sideW are derived.
const view = {
  cellW: 110,          // total candle column width (gap included)
  colGap: 4,           // horizontal gap between adjacent candle columns
  rowH: 22,            // fixed price-row height
  leftPad: 8,
  topPad: 14,
  priceGutter: 64,     // right gutter for price labels
  footerGutter: 80,    // bottom gutter for time/V/Δ/CD/signal
  offsetX: 0,          // horizontal pan in px. +ve = view shifted right.
  offsetY: 0,          // vertical pan in px. +ve = view shifted down.
  autoFollow: true,    // snap to latest candle on next redraw
  autoFitY: true,      // recompute Y centring on next redraw
};

function colW() { return view.cellW - view.colGap; }
// Centre column (wick + body) — kept narrow so the side cells dominate the
// column. Was 20/110 which made the body too wide; 12/110 leaves more room
// for sell/buy labels.
function centerW() { return Math.max(8, Math.round(colW() * 12 / 110)); }
function sideW() { return Math.max(20, Math.floor((colW() - centerW()) / 2)); }

// ---------------------------------------------------------------------------
// COLOURS — two palettes, switched at runtime when Flutter posts the theme.
// ---------------------------------------------------------------------------
const PALETTES = {
  dark: {
    bg: '#0B0F14', topbarBg: '#0E141C', topbarBorder: '#1F2937',
    gridSoft: '#111827', gridStrong: '#1F2937',
    axisText: '#6B7280', axisTextStrong: '#D1D5DB',
    cellText: '#E2E8F0',
    buyBright: '#10B981', sellBright: '#EF4444',
    neutral: '#1F2937',
    poc: '#FBBF24', va: '#60A5FA',
    vwap: '#FACC15',           // yellow — running session VWAP line
    pocOutline: 'rgba(255,255,255,0.35)',
    valBand: 'rgba(251,191,36,0.06)',
    valStroke: 'rgba(251,191,36,0.45)',
    ltpStroke: 'rgba(251,191,36,0.6)',
    hint: '#374151',
    crosshair: 'rgba(203,213,225,0.55)',
    crosshairChip: '#1F2937',
    ohlcLabel: '#9CA3AF',
    ohlcValue: '#F3F4F6',
  },
  light: {
    bg: '#FFFFFF', topbarBg: '#F8FAFC', topbarBorder: '#E2E8F0',
    gridSoft: '#F1F5F9', gridStrong: '#CBD5E1',
    axisText: '#64748B', axisTextStrong: '#0F172A',
    cellText: '#0F172A',
    buyBright: '#16A34A', sellBright: '#DC2626',
    neutral: '#E2E8F0',
    poc: '#D97706', va: '#2563EB',
    vwap: '#CA8A04',           // deeper yellow on light bg for contrast
    pocOutline: 'rgba(15,23,42,0.35)',
    valBand: 'rgba(217,119,6,0.06)',
    valStroke: 'rgba(217,119,6,0.45)',
    ltpStroke: 'rgba(217,119,6,0.65)',
    hint: '#94A3B8',
    crosshair: 'rgba(71,85,105,0.55)',
    crosshairChip: '#0F172A',
    ohlcLabel: '#64748B',
    ohlcValue: '#0F172A',
  },
};
let C = PALETTES[THEME] || PALETTES.dark;

function applyTheme(name) {
  if (name !== 'light' && name !== 'dark') return;
  THEME = name;
  C = PALETTES[name];
  // The HTML/CSS chrome (#topbar etc.) switches via the .light class on <html>
  // — see style.css custom properties.
  document.documentElement.classList.toggle('light', name === 'light');
  scheduleRedraw();
}

// ---------------------------------------------------------------------------
// AGGREGATOR  (mirror of the algorithm in ORDERFLOW_API.md)
// ---------------------------------------------------------------------------
function bucketPrice(raw, step) { return Math.round(raw / step) * step; }
function bucketTime(ms, tfMs) { return ms - (ms % tfMs); }
const SESSION_GAP_MS = 5 * 60 * 1000;

function priceStep() { return PRICE_STEP[SYMBOL] ?? 1; }
function timeframeMs() { return TIMEFRAME_MS[TIMEFRAME] ?? 60000; }

/** Returns 'applied' | 'skipped' | 'primed' | 'session'. */
function ingestTick(packet) {
  // Merge into running tick state (carry forward).
  const ts = packet.ts;
  const lp = packet.c ?? packet.lp;
  const v = packet.v;
  const bp1 = packet.bp1, sp1 = packet.sp1;
  const ft = packet.ft;
  if (lp !== undefined && lp !== null) tickState.lp = +lp;
  if (v !== undefined && v !== null) tickState.v = +v;
  if (bp1 !== undefined && bp1 !== null && +bp1 > 0) tickState.bb = +bp1;
  if (sp1 !== undefined && sp1 !== null && +sp1 > 0) tickState.ba = +sp1;
  if (ft !== undefined && ft !== null) tickState.ft = +ft;
  if (ts) tickState.symbol = ts;

  if (tickState.lp == null || tickState.v == null || tickState.ft == null) return 'skipped';
  const raw = tickState.lp;
  const cumVol = tickState.v;
  const tickMs = tickState.ft * 1000;

  if (aggState.prevCumVol == null) {
    aggState.prevCumVol = cumVol; aggState.prevPrice = raw; aggState.prevMs = tickMs;
    return 'primed';
  }
  if (aggState.prevMs != null && (tickMs - aggState.prevMs) > SESSION_GAP_MS) {
    aggState.prevCumVol = cumVol; aggState.prevPrice = raw; aggState.prevMs = tickMs;
    return 'session';
  }
  const dv = cumVol - aggState.prevCumVol;
  if (dv <= 0) {
    // Late-delivered tick (cumVol went backwards). DO NOT touch aggState —
    // moving prevCumVol backwards would make the next in-order tick's
    // `dv = nextCumVol - prevCumVol` over-count, attributing volume that
    // actually happened earlier to the wrong price/candle. That's the
    // bug that produced phantom high-volume cells (e.g. "2.7k @ 23590")
    // that didn't match the React reference.
    return 'skipped';
  }
  if (dv > 50000) {
    // Huge jump — almost certainly a brief disconnect / catch-up burst.
    // Reset the baseline to the current cumVol so the NEXT in-order tick
    // computes a sensible dv, but don't try to attribute the gap to any
    // single candle (we don't know how the missing trades were
    // distributed).
    aggState.prevCumVol = cumVol; aggState.prevPrice = raw; aggState.prevMs = tickMs;
    return 'skipped';
  }

  // Aggressor: quote rule, tick rule fallback.
  let isBuy;
  if (tickState.bb && tickState.ba) {
    if (raw >= tickState.ba) isBuy = true;
    else if (raw <= tickState.bb) isBuy = false;
    else isBuy = raw >= aggState.prevPrice;
  } else {
    isBuy = raw >= (aggState.prevPrice ?? raw);
  }

  const bucketMs = bucketTime(tickMs, timeframeMs());
  const price = bucketPrice(raw, priceStep());
  let c = candles.length ? candles[candles.length - 1] : null;
  if (c && bucketMs < c.ts) {
    // Tick belongs to a bucket we've already moved past (out-of-order ft).
    // Drop it without modifying aggState OR the current candle — folding
    // it into the live candle would corrupt its open/high/low/close and
    // node volumes with trades that actually happened earlier.
    return 'skipped';
  }
  if (!c || bucketMs > c.ts) {
    c = { ts: bucketMs, open: price, high: price, low: price, close: price, nodes: new Map(), maxNode: 0 };
    candles.push(c);
  }
  c.close = price;
  if (price > c.high) c.high = price;
  if (price < c.low) c.low = price;
  let n = c.nodes.get(price);
  if (!n) { n = { bid: 0, ask: 0 }; c.nodes.set(price, n); }
  if (isBuy) n.ask += dv; else n.bid += dv;
  const total = n.bid + n.ask;
  if (total > c.maxNode) c.maxNode = total;

  aggState.prevCumVol = cumVol; aggState.prevPrice = raw; aggState.prevMs = tickMs;
  lastTickAt = Date.now();
  return 'applied';
}

function nodeDelta(n) { return n.ask - n.bid; }
function candleDelta(c) { let d = 0; for (const n of c.nodes.values()) d += nodeDelta(n); return d; }
function candleTotal(c) { let t = 0; for (const n of c.nodes.values()) t += n.bid + n.ask; return t; }
function cumulativeDelta() { let r = 0; return candles.map(c => (r += candleDelta(c))); }

// ---------------------------------------------------------------------------
// NETWORK
// ---------------------------------------------------------------------------
async function loadHistory() {
  historyPackets = 0; historyApplied = 0;
  candles = [];
  tickState = { lp: null, v: null, bb: null, ba: null, ft: null };
  aggState = { prevCumVol: null, prevPrice: null, prevMs: null };
  // Re-fit Y on the new symbol's price range and re-anchor to the latest candle.
  view.autoFitY = true;
  view.autoFollow = true;
  view.offsetX = 0;
  view.offsetY = 0;
  lastPricesCacheKey = '';
  showOverlay(`Loading ${SYMBOL} history…`);
  try {
    const r = await fetch(`${API_BASE}/api/history/${SYMBOL}?limit=25000&offset=0`);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const j = await r.json();
    const packets = (j && j.data) || [];
    historyPackets = packets.length;
    for (const p of packets) {
      const res = ingestTick(p);
      if (res === 'applied') historyApplied++;
    }
    hideOverlay();
  } catch (e) {
    showOverlay(`Failed to load history for ${SYMBOL}`, String(e));
  }
  scheduleRedraw();
  updateTopbar();
}

async function loadStructure() {
  try {
    const r = await fetch(`${API_BASE}/api/trading/structure/${SYMBOL}`);
    if (!r.ok) return;
    const j = await r.json();
    if (j) {
      structure = {
        profile: j.profile || structure.profile,
        imbalances: j.imbalances || [],
        session_cd: j.session_cd ?? 0,
      };
      scheduleRedraw();
      updateTopbar();
    }
  } catch (_) { /* swallow — keep last good state */ }
}

// --- WebSocket with auto-reconnect ---------------------------------------
let ws = null;
let wsReconnectTimer = null;
function connectWS() {
  if (ws) try { ws.close(); } catch (_) {}
  try {
    ws = new WebSocket(`${WS_BASE}/ws/market-data`);
  } catch (e) {
    scheduleReconnect();
    return;
  }
  ws.onmessage = (e) => {
    wsPackets++;
    try {
      const packet = JSON.parse(e.data);
      // STRICT symbol filter — only feed our aggregator with packets that
      // explicitly carry our symbol tag. The old "carry forward when ts is
      // missing" branch let untagged packets (or packets from other
      // instruments) leak into the shared tickState (lp / v / ft), which
      // then poisoned the next ingested tick with foreign price data — the
      // visible symptom was every recent candle inheriting an inflated
      // high until the next /api/history refresh rebuilt them cleanly.
      const tag = packet.ts ? String(packet.ts).toUpperCase() : null;
      if (tag !== SYMBOL) {
        // Tagged packets for other symbols still prove the feed is alive.
        if (tag) lastTickAt = Date.now();
        return;
      }
      const res = ingestTick(packet);
      if (res === 'applied') {
        wsApplied++;
        scheduleRedraw();
      }
      updateTopbar();
    } catch (_) { /* malformed frame */ }
  };
  ws.onclose = ws.onerror = scheduleReconnect;
}
function scheduleReconnect() {
  if (wsReconnectTimer) return;
  wsReconnectTimer = setTimeout(() => { wsReconnectTimer = null; connectWS(); }, 3000);
}

// ---------------------------------------------------------------------------
// CANVAS / RENDER
// ---------------------------------------------------------------------------
const canvas = document.getElementById('chart');
const wrap = document.getElementById('chart-wrap');
const ctx = canvas.getContext('2d', { alpha: false });
let dpr = window.devicePixelRatio || 1;

// Make the chart wrap focusable + grab focus on load so the parent Flutter
// HtmlElementView starts routing pointer events to us immediately. Without
// this, the iframe sometimes stays "inert" (no hover, no drag) until the
// user clicks a Flutter widget first — the focus shift "unsticks" the
// platform-view pointer routing.
wrap.tabIndex = -1;
window.addEventListener('load', () => {
  try { window.focus(); wrap.focus(); } catch (_) {}
});
// Belt-and-braces: when the cursor enters the iframe, take focus so any
// follow-on mousemove definitely reaches our listeners.
wrap.addEventListener('pointerenter', () => {
  try { window.focus(); wrap.focus(); } catch (_) {}
});

function resizeCanvas() {
  const w = wrap.clientWidth;
  const h = wrap.clientHeight;
  dpr = window.devicePixelRatio || 1;
  canvas.width = Math.floor(w * dpr);
  canvas.height = Math.floor(h * dpr);
  canvas.style.width = w + 'px';
  canvas.style.height = h + 'px';
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  scheduleRedraw();
}
window.addEventListener('resize', resizeCanvas);

let pendingFrame = false;
function scheduleRedraw() {
  if (pendingFrame) return;
  pendingFrame = true;
  requestAnimationFrame(() => { pendingFrame = false; draw(); });
}

// Plot rect (the area inside the gutters).
function plot() {
  const w = canvas.clientWidth, h = canvas.clientHeight;
  return {
    left: view.leftPad,
    top: view.topPad,
    right: w - view.priceGutter,
    bottom: h - view.footerGutter,
    width: w - view.priceGutter - view.leftPad,
    height: h - view.footerGutter - view.topPad,
  };
}

// ---------------------------------------------------------------------------
// PRICE LADDER
// Build a contiguous price ladder (highest at index 0) spanning every price
// that ever appears in any candle's nodes or wick. This matches the React
// reference's `allPrices` array and gives every price its own fixed-height
// row regardless of how dense the data is.
// ---------------------------------------------------------------------------
let allPrices = [];           // descending unique prices
let priceToRowIndex = new Map(); // price → row index (O(1) lookup)
let lastPricesCacheKey = '';

function rebuildPriceLadder() {
  if (!candles.length) {
    allPrices = []; priceToRowIndex = new Map(); return;
  }
  const step = priceStep();
  // Span the union of every candle's [low, high] in step increments — this
  // way every row exists even if no trade has happened there yet, so the
  // candle wick can pass through it.
  let lo = Infinity, hi = -Infinity;
  for (const c of candles) {
    if (c.low < lo) lo = c.low;
    if (c.high > hi) hi = c.high;
  }
  if (!isFinite(lo) || !isFinite(hi)) { allPrices = []; priceToRowIndex = new Map(); return; }
  const out = [];
  // Round to step boundary and walk top → bottom.
  const top = bucketPrice(hi, step);
  const bot = bucketPrice(lo, step);
  const decimals = step < 1 ? (String(step).split('.')[1] || '').length : 0;
  const round = (v) => decimals > 0 ? Number(v.toFixed(decimals)) : v;
  for (let v = top; v >= bot - step / 2; v -= step) {
    out.push(round(v));
  }
  allPrices = out;
  priceToRowIndex = new Map(out.map((p, i) => [p, i]));
}

function maybeRebuildLadder() {
  // Cheap cache key — number of candles + last candle's high/low/timestamp.
  if (!candles.length) { lastPricesCacheKey = ''; allPrices = []; priceToRowIndex = new Map(); return; }
  const last = candles[candles.length - 1];
  const key = `${candles.length}|${last.ts}|${last.high}|${last.low}`;
  if (key === lastPricesCacheKey) return;
  lastPricesCacheKey = key;
  rebuildPriceLadder();
}

// ---------------------------------------------------------------------------
// COORD HELPERS
// ---------------------------------------------------------------------------
// Candle column left edge in canvas X. Anchored so the newest candle's right
// edge sits at p.right when offsetX = 0. offsetX > 0 pans the grid right
// (revealing older candles on the left).
function candleColLeftX(i, p) {
  const N = candles.length;
  return p.right - view.cellW * (N - i) + view.offsetX;
}
function priceRowY(idx, p) {
  return p.top + idx * view.rowH + view.offsetY;
}

function visibleCandleRange(p) {
  if (!candles.length) return [0, -1];
  const N = candles.length;
  let first = 0;
  for (let i = 0; i < N; i++) {
    if (candleColLeftX(i, p) + view.cellW >= p.left) { first = i; break; }
  }
  let last = N - 1;
  for (let i = N - 1; i >= 0; i--) {
    if (candleColLeftX(i, p) <= p.right) { last = i; break; }
  }
  return [first, last];
}

function ensureAutoFitY(p) {
  if (!view.autoFitY || !allPrices.length || !candles.length) return;
  // Centre the latest candle's [low, high] in the plot.
  const last = candles[candles.length - 1];
  const step = priceStep();
  const decimals = step < 1 ? (String(step).split('.')[1] || '').length : 0;
  const round = (v) => decimals > 0 ? Number(v.toFixed(decimals)) : v;
  const hiP = round(bucketPrice(last.high, step));
  const loP = round(bucketPrice(last.low, step));
  const hiIdx = priceToRowIndex.get(hiP);
  const loIdx = priceToRowIndex.get(loP);
  if (hiIdx == null || loIdx == null) return;
  const midIdx = (hiIdx + loIdx) / 2;
  view.offsetY = (p.height / 2) - (midIdx * view.rowH) - view.rowH / 2;
  view.autoFitY = false;
}

function ensureAutoFollowX(p) {
  if (!view.autoFollow) return;
  view.offsetX = 0; // newest candle pinned to right edge
}


// ---------------------------------------------------------------------------
// FORMATTING
// ---------------------------------------------------------------------------
function fmtVol(v) {
  if (v < 1000) return '' + v;
  if (v < 100000) {
    const t = v / 1000;
    return (t < 10 ? t.toFixed(1) : Math.round(t)) + 'k';
  }
  const l = v / 100000;
  return (l < 10 ? l.toFixed(1) : Math.round(l)) + 'L';
}
function fmtTime(ms) {
  const utc = new Date(ms);
  const ist = new Date(utc.getTime() + (5 * 60 + 30) * 60 * 1000);
  const pad = n => String(n).padStart(2, '0');
  return pad(ist.getUTCHours()) + ':' + pad(ist.getUTCMinutes());
}
function fmtPrice(p) {
  return PRICE_STEP[SYMBOL] === 0.1 ? p.toFixed(1) : p.toFixed(0);
}

// ---------------------------------------------------------------------------
// DRAW
// ---------------------------------------------------------------------------
function draw() {
  const w = canvas.clientWidth, h = canvas.clientHeight;
  ctx.fillStyle = C.bg;
  ctx.fillRect(0, 0, w, h);

  const p = plot();
  maybeRebuildLadder();
  ensureAutoFollowX(p);
  ensureAutoFitY(p);

  drawGrid(p);
  drawCells(p);
  drawProfile(p);
  drawCrosshair(p);
  drawPriceAxis(p);
  drawFooter(p);
  drawOhlcReadout(p);
}

// Inverse of priceToYInterp — converts a screen Y inside the plot back to a
// price value (continuous; doesn't snap to priceStep).
function yToPriceInterp(y, p) {
  if (!allPrices.length) return null;
  const step = priceStep();
  const top = allPrices[0];
  const rowsFromTop = (y - p.top - view.offsetY - view.rowH / 2) / view.rowH;
  return top - rowsFromTop * step;
}

// Returns the candle index under screen X, or -1.
function candleAtX(x, p) {
  if (!candles.length) return -1;
  const N = candles.length;
  // candleColLeftX(i, p) = p.right - cellW*(N-i) + offsetX
  // x in column i ⇔ N - i = ceil((p.right + offsetX - x) / cellW)
  // → i = N - ceil((p.right + offsetX - x) / cellW)
  const fromRight = (p.right + view.offsetX - x) / view.cellW;
  const i = N - Math.ceil(fromRight);
  if (i < 0 || i >= N) return -1;
  return i;
}

function drawCrosshair(p) {
  if (!hover.inside || hover.x == null || hover.y == null) return;
  const x = hover.x, y = hover.y;
  ctx.save();
  ctx.beginPath(); ctx.rect(p.left, p.top, p.width, p.height); ctx.clip();
  ctx.strokeStyle = C.crosshair;
  ctx.lineWidth = 1;
  ctx.setLineDash([4, 4]);
  ctx.beginPath(); ctx.moveTo(x, p.top); ctx.lineTo(x, p.bottom); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(p.left, y); ctx.lineTo(p.right, y); ctx.stroke();
  ctx.setLineDash([]);
  ctx.restore();

  // Right-gutter price chip at the hover Y.
  const price = yToPriceInterp(y, p);
  if (price != null) {
    const txt = fmtPrice(price);
    ctx.font = '700 10px Geist, ui-sans-serif, system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    const tw = ctx.measureText(txt).width + 10;
    const h = 16;
    const cx = p.right + 2;
    const cy = clamp(y, p.top + h / 2, p.bottom - h / 2);
    ctx.fillStyle = C.crosshairChip;
    roundedRect(ctx, cx, cy - h / 2, Math.min(tw, view.priceGutter - 4), h, 3);
    ctx.fill();
    ctx.fillStyle = C.ohlcValue;
    ctx.textAlign = 'center';
    ctx.fillText(txt, cx + Math.min(tw, view.priceGutter - 4) / 2, cy);
  }

  // Footer chip with the hovered candle's time, just below the plot.
  const i = candleAtX(x, p);
  if (i >= 0) {
    const c = candles[i];
    const txt = fmtTime(c.ts);
    ctx.font = '700 10px Geist, ui-sans-serif, system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    const tw = ctx.measureText(txt).width + 12;
    const h = 16;
    const cx0 = clamp(x - tw / 2, p.left, p.right - tw);
    const cy0 = p.bottom + 2;
    ctx.fillStyle = C.crosshairChip;
    roundedRect(ctx, cx0, cy0, tw, h, 3);
    ctx.fill();
    ctx.fillStyle = C.ohlcValue;
    ctx.textAlign = 'center';
    ctx.fillText(txt, cx0 + tw / 2, cy0 + h / 2);
  }
}

// TradingView-style OHLC readout pinned to the top-left of the chart.
// Shows the hovered candle when the cursor is inside the plot, otherwise
// the latest (current) candle.
function drawOhlcReadout(p) {
  if (!candles.length) return;
  let idx = candles.length - 1;
  if (hover.inside && hover.x != null) {
    const hi = candleAtX(hover.x, p);
    if (hi >= 0) idx = hi;
  }
  const c = candles[idx];
  const up = c.close >= c.open;
  const dir = up ? C.buyBright : C.sellBright;
  const totalVol = candleTotal(c);
  const delta = candleDelta(c);

  // Build segments: [label, value, valueColor]
  const segs = [
    ['O', fmtPrice(c.open), dir],
    ['H', fmtPrice(c.high), dir],
    ['L', fmtPrice(c.low), dir],
    ['C', fmtPrice(c.close), dir],
    ['V', fmtVol(totalVol), C.ohlcValue],
    ['Δ', (delta >= 0 ? '+' : '') + delta,
        delta >= 0 ? C.buyBright : C.sellBright],
  ];
  ctx.save();
  ctx.font = '600 11px Geist, ui-sans-serif, system-ui, sans-serif';
  ctx.textBaseline = 'middle';
  let x = p.left + 8;
  const y = p.top + 12;
  for (const [label, value, color] of segs) {
    ctx.fillStyle = C.ohlcLabel;
    ctx.textAlign = 'left';
    ctx.fillText(label, x, y);
    x += ctx.measureText(label).width + 4;
    ctx.fillStyle = color;
    ctx.fillText(value, x, y);
    x += ctx.measureText(value).width + 12;
  }
  ctx.restore();
}

function drawGrid(p) {
  // Outer frame — always drawn (it's the plot boundary, not really a
  // gridline; the user-toggleable "gridlines" setting only covers the
  // horizontal row stride lines inside the plot).
  ctx.strokeStyle = C.gridStrong;
  ctx.lineWidth = 0.6;
  ctx.strokeRect(p.left + 0.5, p.top + 0.5, p.width - 1, p.height - 1);

  if (!overlays.grid) return;
  if (!allPrices.length) return;
  // Horizontal stride lines every N rows so the chart doesn't get noisy
  // when rowH is small.
  const stride = view.rowH >= 22 ? 1 : view.rowH >= 14 ? 2 : view.rowH >= 10 ? 4 : 8;
  ctx.strokeStyle = C.gridSoft;
  ctx.lineWidth = 0.5;
  for (let idx = 0; idx < allPrices.length; idx += stride) {
    const y = priceRowY(idx, p) + view.rowH;
    if (y < p.top || y > p.bottom) continue;
    ctx.beginPath(); ctx.moveTo(p.left, y); ctx.lineTo(p.right, y); ctx.stroke();
  }
}

function drawCells(p) {
  if (!candles.length || !allPrices.length) return;
  const [firstC, lastC] = visibleCandleRange(p);
  if (firstC > lastC) return;

  const _colW = colW();
  const _centerW = centerW();
  const _sideW = sideW();
  const rowH = view.rowH;
  const showText = rowH >= 11 && _sideW >= 18;

  ctx.save();
  ctx.beginPath(); ctx.rect(p.left, p.top, p.width, p.height); ctx.clip();

  const step = priceStep();
  const decimals = step < 1 ? (String(step).split('.')[1] || '').length : 0;
  const round = (v) => decimals > 0 ? Number(v.toFixed(decimals)) : v;

  for (let i = firstC; i <= lastC; i++) {
    const c = candles[i];
    const colLeft = candleColLeftX(i, p);
    const sellLeft = colLeft;
    const centerLeft = colLeft + _sideW;
    const buyLeft = centerLeft + _centerW;

    const isBullish = c.close >= c.open;
    const wickCol = isBullish ? C.buyBright : C.sellBright;
    const bodyTop = Math.max(c.open, c.close);
    const bodyBot = Math.min(c.open, c.close);
    const cHi = round(bucketPrice(c.high, step));
    const cLo = round(bucketPrice(c.low, step));
    const bHi = round(bucketPrice(bodyTop, step));
    const bLo = round(bucketPrice(bodyBot, step));

    const hiIdx = priceToRowIndex.get(cHi);
    const loIdx = priceToRowIndex.get(cLo);
    const bHiIdx = priceToRowIndex.get(bHi);
    const bLoIdx = priceToRowIndex.get(bLo);
    const maxNode = c.maxNode || 1;

    // -- Wick (single continuous line) ----------------------------------
    if (hiIdx != null && loIdx != null) {
      const yTop = priceRowY(hiIdx, p);
      const yBot = priceRowY(loIdx, p) + rowH;
      const xMid = centerLeft + _centerW / 2;
      ctx.fillStyle = hexA(wickCol, 0.6);
      ctx.fillRect(Math.round(xMid - 1), Math.max(p.top, yTop), 2, Math.min(p.bottom, yBot) - Math.max(p.top, yTop));
    }

    // -- Body rect ------------------------------------------------------
    if (bHiIdx != null && bLoIdx != null) {
      const yTop = priceRowY(bHiIdx, p);
      const yBot = priceRowY(bLoIdx, p) + rowH;
      const bx = centerLeft + 2;
      const bw = _centerW - 4;
      const by = Math.max(p.top, yTop) + 1;
      const bh = Math.min(p.bottom, yBot) - by - 1;
      if (bh > 0 && bw > 0) {
        // Filled body for both bullish and bearish — the wick colour already
        // encodes direction.
        ctx.fillStyle = wickCol;
        ctx.fillRect(bx, by, bw, bh);
      }
    }

    // -- Per-row sell / buy cells --------------------------------------
    for (const [rawPrice, n] of c.nodes) {
      const price = round(rawPrice);
      const rowIdx = priceToRowIndex.get(price);
      if (rowIdx == null) continue;
      const rowTop = priceRowY(rowIdx, p);
      if (rowTop + rowH < p.top || rowTop > p.bottom) continue;

      const total = n.bid + n.ask;
      if (total <= 0) continue;
      const intensity = total / maxNode;
      // Floor at 0.35 so a tiny tail-volume cell is still clearly visible
      // (previously cells with <5% of the candle's max were so faint they
      // looked like empty rows, which made the data appear missing).
      const bgAlpha = 0.35 + intensity * 0.6;

      if (n.bid > 0) {
        ctx.fillStyle = hexA(C.sellBright, bgAlpha);
        ctx.fillRect(sellLeft, rowTop, _sideW, rowH);
      }
      if (n.ask > 0) {
        ctx.fillStyle = hexA(C.buyBright, bgAlpha);
        ctx.fillRect(buyLeft, rowTop, _sideW, rowH);
      }

      if (showText) {
        ctx.font = '500 11px Geist, ui-sans-serif, system-ui, sans-serif';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = C.cellText;
        const yMid = rowTop + rowH / 2;
        if (n.bid > 0) {
          ctx.textAlign = 'center';
          ctx.fillText(fmtVol(n.bid), sellLeft + _sideW / 2, yMid);
        }
        if (n.ask > 0) {
          ctx.textAlign = 'center';
          ctx.fillText(fmtVol(n.ask), buyLeft + _sideW / 2, yMid);
        }
      }

      // POC ring for the candle's biggest node.
      if (total === maxNode && maxNode > 0) {
        ctx.strokeStyle = C.pocOutline;
        ctx.lineWidth = 1;
        if (n.bid > 0) ctx.strokeRect(sellLeft + 0.5, rowTop + 0.5, _sideW - 1, rowH - 1);
        if (n.ask > 0) ctx.strokeRect(buyLeft + 0.5, rowTop + 0.5, _sideW - 1, rowH - 1);
      }
    }
  }

  // -- Imbalance highlights (purple border on stacked rows) -----------
  if (overlays.imb && structure.imbalances && structure.imbalances.length) {
    const tsToIdx = new Map();
    for (let i = 0; i < candles.length; i++) tsToIdx.set(candles[i].ts, i);
    ctx.strokeStyle = '#A855F7'; ctx.lineWidth = 1.5;
    for (const imb of structure.imbalances) {
      const ci = tsToIdx.get(imb.candle_ts);
      if (ci == null || ci < firstC || ci > lastC) continue;
      const hi = priceToRowIndex.get(round(bucketPrice(imb.high_price, step)));
      const lo = priceToRowIndex.get(round(bucketPrice(imb.low_price, step)));
      if (hi == null || lo == null) continue;
      const colLeft = candleColLeftX(ci, p);
      const yTop = priceRowY(hi, p);
      const yBot = priceRowY(lo, p) + rowH;
      const side = imb.side === 'BUY';
      const x = side ? colLeft + _sideW + _centerW : colLeft;
      ctx.strokeRect(x + 0.5, yTop + 0.5, _sideW - 1, yBot - yTop - 1);
    }
  }

  ctx.restore();
}

function drawProfile(p) {
  const pr = structure.profile;
  if (!pr || !allPrices.length) return;
  const step = priceStep();
  const decimals = step < 1 ? (String(step).split('.')[1] || '').length : 0;
  const round = (v) => decimals > 0 ? Number(v.toFixed(decimals)) : v;
  const rowY = (priceVal) => {
    const idx = priceToRowIndex.get(round(bucketPrice(priceVal, step)));
    if (idx == null) return null;
    return priceRowY(idx, p) + view.rowH / 2;
  };

  ctx.save();
  ctx.beginPath(); ctx.rect(p.left, p.top, p.width, p.height); ctx.clip();

  // Collected tags for the right edge of the chart so each overlay line is
  // labelled (POC / VAH / VAL / LTP / VWAP). Pushed in draw order, deduped
  // and laid out by drawOverlayTags() after the clip is released.
  const tags = [];

  // VA band — gated by overlays.va.
  const yVal = (overlays.va && pr.val != null) ? rowY(pr.val) : null;
  const yVah = (overlays.va && pr.vah != null) ? rowY(pr.vah) : null;
  if (yVal != null && yVah != null) {
    ctx.fillStyle = C.valBand;
    const yT = Math.min(yVal, yVah) - view.rowH / 2;
    const yB = Math.max(yVal, yVah) + view.rowH / 2;
    ctx.fillRect(p.left, yT, p.width, yB - yT);
    ctx.setLineDash([6, 4]);
    ctx.strokeStyle = C.valStroke; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(p.left, yT); ctx.lineTo(p.right, yT); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(p.left, yB); ctx.lineTo(p.right, yB); ctx.stroke();
    ctx.setLineDash([]);
    // yT is the top edge of the band → that's VAH. yB is the bottom → VAL.
    tags.push({ y: yT, label: 'VAH', price: pr.vah, color: C.valStroke });
    tags.push({ y: yB, label: 'VAL', price: pr.val, color: C.valStroke });
  }
  // POC — gated by overlays.poc.
  if (overlays.poc && pr.poc != null) {
    const y = rowY(pr.poc);
    if (y != null) {
      ctx.strokeStyle = C.poc; ctx.lineWidth = 1.6;
      ctx.beginPath(); ctx.moveTo(p.left, y); ctx.lineTo(p.right, y); ctx.stroke();
      tags.push({ y, label: 'POC', price: pr.poc, color: C.poc });
    }
  }
  // VWAP polyline — gated by overlays.vwap.
  if (overlays.vwap) drawVwapLine(p);
  // LTP marker — always on (last traded price isn't a toggleable indicator).
  const last = candles.length ? candles[candles.length - 1] : null;
  if (last) {
    const y = rowY(last.close);
    if (y != null) {
      ctx.strokeStyle = C.ltpStroke; ctx.lineWidth = 1;
      ctx.setLineDash([2, 3]);
      ctx.beginPath(); ctx.moveTo(p.left, y); ctx.lineTo(p.right, y); ctx.stroke();
      ctx.setLineDash([]);
      tags.push({ y, label: 'LTP', price: last.close, color: C.ltpStroke });
    }
  }
  // VWAP tag — only when the polyline is shown.
  if (overlays.vwap) {
    const vw = lastVwap();
    if (vw != null) {
      const y = priceToYInterp(vw, p);
      if (y != null) tags.push({ y, label: 'VWAP', price: vw, color: C.vwap });
    }
  }
  ctx.restore();

  drawOverlayTags(p, tags);
}

// Lay out the right-edge tags so overlapping lines don't smash on top of each
// other. Tags are sorted by Y, then nudged to keep at least one tag-height
// of vertical spacing.
function drawOverlayTags(p, tags) {
  if (!tags.length) return;
  // Drop tags outside the visible plot.
  const list = tags
      .filter(t => t.y >= p.top - 8 && t.y <= p.bottom + 8)
      .sort((a, b) => a.y - b.y);
  if (!list.length) return;
  const h = 16;
  // Anti-overlap pass.
  for (let i = 1; i < list.length; i++) {
    if (list[i].y < list[i - 1].y + h) list[i].y = list[i - 1].y + h;
  }
  // Tags sit JUST INSIDE the right edge of the chart (left of the gutter).
  ctx.save();
  ctx.font = '700 10px Geist, ui-sans-serif, system-ui, sans-serif';
  ctx.textBaseline = 'middle';
  for (const t of list) {
    const text = `${t.label} ${fmtPrice(t.price)}`;
    const tw = ctx.measureText(text).width + 10;
    const x = p.right - tw - 2;
    const y = Math.max(p.top + h / 2, Math.min(p.bottom - h / 2, t.y));
    // Pill background in the line's colour, white text on top so the tag
    // reads clearly against the alternating cells / VA band beneath.
    ctx.fillStyle = t.color;
    roundedRect(ctx, x, y - h / 2, tw, h, 4);
    ctx.fill();
    ctx.fillStyle = C.bg;
    ctx.textAlign = 'center';
    ctx.fillText(text, x + tw / 2, y);
  }
  ctx.restore();
}

function roundedRect(c, x, y, w, h, r) {
  const rr = Math.min(r, w / 2, h / 2);
  c.beginPath();
  c.moveTo(x + rr, y);
  c.lineTo(x + w - rr, y); c.quadraticCurveTo(x + w, y, x + w, y + rr);
  c.lineTo(x + w, y + h - rr); c.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
  c.lineTo(x + rr, y + h); c.quadraticCurveTo(x, y + h, x, y + h - rr);
  c.lineTo(x, y + rr); c.quadraticCurveTo(x, y, x + rr, y);
  c.closePath();
}

// VWAP — running session VWAP (HLC3 weighted by per-candle total volume).
// Returns one value per candle, accumulated from the first candle onward,
// matching the standard intraday "VWAP" indicator that draws as a curve
// following price.
let _vwapCacheKey = '';
let _vwapSeries = [];
function computeVwapSeries() {
  if (!candles.length) { _vwapSeries = []; _vwapCacheKey = ''; return _vwapSeries; }
  const last = candles[candles.length - 1];
  const key = `${candles.length}|${last.ts}|${last.close}|${last.maxNode}`;
  if (key === _vwapCacheKey) return _vwapSeries;
  const out = new Array(candles.length);
  let num = 0, den = 0;
  for (let i = 0; i < candles.length; i++) {
    const c = candles[i];
    let vol = 0;
    for (const n of c.nodes.values()) vol += n.bid + n.ask;
    const typical = (c.high + c.low + c.close) / 3;
    if (vol > 0) { num += typical * vol; den += vol; }
    out[i] = den > 0 ? num / den : null;
  }
  _vwapSeries = out;
  _vwapCacheKey = key;
  return out;
}
function lastVwap() {
  const s = computeVwapSeries();
  for (let i = s.length - 1; i >= 0; i--) {
    if (s[i] != null) return s[i];
  }
  return null;
}

// Map an arbitrary price (need not be on the ladder) to its Y coordinate
// by interpolating between rows. Used for the VWAP polyline whose values
// don't snap to priceStep.
function priceToYInterp(price, p) {
  if (!allPrices.length) return null;
  const step = priceStep();
  const top = allPrices[0];
  const rowsFromTop = (top - price) / step;
  return p.top + rowsFromTop * view.rowH + view.offsetY + view.rowH / 2;
}

function drawVwapLine(p) {
  const vw = computeVwapSeries();
  if (!vw.length || !candles.length) return;
  const [first, last] = visibleCandleRange(p);
  if (first > last) return;
  ctx.save();
  ctx.beginPath(); ctx.rect(p.left, p.top, p.width, p.height); ctx.clip();
  ctx.strokeStyle = C.vwap;
  ctx.lineWidth = 1.6;
  ctx.lineJoin = 'round';
  ctx.lineCap = 'round';
  ctx.beginPath();
  let started = false;
  // Extend one candle past the visible range on each side so the line meets
  // the plot edge instead of being clipped to a column boundary.
  const start = Math.max(0, first - 1);
  const end = Math.min(candles.length - 1, last + 1);
  for (let i = start; i <= end; i++) {
    const v = vw[i];
    if (v == null) { started = false; continue; }
    const x = candleColLeftX(i, p) + view.cellW / 2;
    const y = priceToYInterp(v, p);
    if (y == null) { started = false; continue; }
    if (!started) { ctx.moveTo(x, y); started = true; }
    else { ctx.lineTo(x, y); }
  }
  ctx.stroke();
  ctx.restore();
}

function drawPriceAxis(p) {
  const w = canvas.clientWidth, h = canvas.clientHeight;
  ctx.fillStyle = C.bg;
  ctx.fillRect(p.right, 0, view.priceGutter, h);
  ctx.strokeStyle = C.gridStrong; ctx.lineWidth = 0.6;
  ctx.beginPath(); ctx.moveTo(p.right + 0.5, p.top); ctx.lineTo(p.right + 0.5, p.bottom); ctx.stroke();

  if (!allPrices.length) return;
  const rowH = view.rowH;
  // Label cadence — pick the smallest "nice" multiple of priceStep that
  // leaves at least ~18px between consecutive labels, so as the user zooms
  // out the prices group into clean buckets (1, 2, 5, 10, 25, 50, 100, …)
  // anchored to round-number boundaries — instead of every row reading a
  // jittery 23582, 23583, 23584 stack.
  const step = priceStep();
  const stride = niceLabelStride(rowH, step);
  const ltp = candles.length ? bucketPrice(candles[candles.length - 1].close, step) : null;
  const poc = structure.profile && structure.profile.poc;
  ctx.font = '500 10px Geist, ui-sans-serif, system-ui, sans-serif';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  for (let idx = 0; idx < allPrices.length; idx++) {
    const price = allPrices[idx];
    // Snap-to-round: only label prices that fall on the chosen stride
    // (e.g. with stride=5 you see 23580, 23585, 23590, not the rows in
    // between). Floating-point safe comparison via Math.round.
    if (Math.round(price / stride) * stride !== price) continue;
    const y = priceRowY(idx, p) + rowH / 2;
    if (y < p.top - 6 || y > p.bottom + 6) continue;
    const isLtp = ltp != null && price === ltp;
    const isPoc = poc != null && Math.abs(price - poc) < step / 2;
    ctx.fillStyle = isLtp ? C.poc : isPoc ? C.poc : C.axisText;
    ctx.fillText(fmtPrice(price), p.right + 6, y);
  }
}

// Pick a "nice" stride (in priceStep units) so labels stay ~18px apart.
// Sequence is 1·step, 2·step, 5·step, 10·step, … which gives well-known
// chart axis spacing (1, 2, 5, 10, 25, 50, 100 …).
function niceLabelStride(rowH, step) {
  const minPx = 18;
  const minStrideInSteps = Math.max(1, Math.ceil(minPx / rowH));
  const niceMultipliers = [1, 2, 5, 10, 25, 50, 100, 250, 500, 1000];
  for (const m of niceMultipliers) {
    if (m >= minStrideInSteps) return m * step;
  }
  return niceMultipliers[niceMultipliers.length - 1] * step;
}

function drawFooter(p) {
  if (!candles.length) return;
  ctx.fillStyle = C.bg;
  ctx.fillRect(0, p.bottom, canvas.clientWidth, canvas.clientHeight - p.bottom);
  ctx.strokeStyle = C.gridStrong; ctx.lineWidth = 0.6;
  ctx.beginPath(); ctx.moveTo(p.left, p.bottom + 0.5); ctx.lineTo(p.right, p.bottom + 0.5); ctx.stroke();

  // CD per candle = running sum of candle deltas starting at 0. Closed
  // candles' values are intrinsically static (their deltas are fixed); only
  // the live candle's CD ticks as new aggressors arrive.
  const cds = cumulativeDelta();
  const [first, last] = visibleCandleRange(p);
  const yTime = p.bottom + 12;
  const yVol = p.bottom + 26;
  const yDelta = p.bottom + 40;
  const yCd = p.bottom + 54;

  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.save();
  ctx.beginPath(); ctx.rect(p.left, p.bottom, p.width, canvas.clientHeight - p.bottom); ctx.clip();
  for (let i = first; i <= last; i++) {
    const c = candles[i];
    const cx = candleColLeftX(i, p) + view.cellW / 2;
    ctx.fillStyle = C.axisText; ctx.font = '500 10px Geist, ui-sans-serif, system-ui, sans-serif';
    ctx.fillText(fmtTime(c.ts), cx, yTime);
    const tot = candleTotal(c);
    ctx.fillStyle = C.axisTextStrong; ctx.font = '500 9px Geist, ui-sans-serif, system-ui, sans-serif';
    ctx.fillText('V ' + fmtVol(tot), cx, yVol);
    const d = candleDelta(c);
    ctx.fillStyle = d >= 0 ? C.buyBright : C.sellBright;
    ctx.font = '700 10px Geist, ui-sans-serif, system-ui, sans-serif';
    ctx.fillText((d >= 0 ? '+' : '') + d, cx, yDelta);
    const cd = cds[i];
    ctx.fillStyle = cd >= 0 ? C.buyBright : C.sellBright;
    ctx.font = '600 10px Geist, ui-sans-serif, system-ui, sans-serif';
    ctx.fillText('CD ' + (cd >= 0 ? '+' : '') + cd, cx, yCd);
  }
  ctx.restore();
}

// ---- Utilities ----------------------------------------------------------
function hexA(hex, a) {
  const h = hex.replace('#', '');
  const r = parseInt(h.substring(0, 2), 16);
  const g = parseInt(h.substring(2, 4), 16);
  const b = parseInt(h.substring(4, 6), 16);
  return `rgba(${r},${g},${b},${a})`;
}
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

// ---------------------------------------------------------------------------
// INPUT — drag-pan on body, drag-zoom on axes, wheel zoom, dblclick recentre
// ---------------------------------------------------------------------------
let dragMode = null;
let dragLastX = 0, dragLastY = 0;

function hitZone(x, y) {
  const p = plot();
  if (x >= p.right) return 'zoom-y';
  if (y >= p.bottom) return 'zoom-x';
  return 'pan';
}

wrap.addEventListener('mousedown', (e) => {
  const rect = wrap.getBoundingClientRect();
  const x = e.clientX - rect.left, y = e.clientY - rect.top;
  dragMode = hitZone(x, y);
  dragLastX = e.clientX; dragLastY = e.clientY;
  wrap.classList.remove('dragging', 'zoom-y', 'zoom-x');
  if (dragMode === 'pan') wrap.classList.add('dragging');
  else if (dragMode === 'zoom-y') wrap.classList.add('zoom-y');
  else if (dragMode === 'zoom-x') wrap.classList.add('zoom-x');
  view.autoFollow = false;
  view.autoFitY = false;
});
window.addEventListener('mouseup', () => {
  dragMode = null;
  wrap.classList.remove('dragging', 'zoom-y', 'zoom-x');
});
window.addEventListener('mousemove', (e) => {
  const rect = wrap.getBoundingClientRect();
  const x = e.clientX - rect.left, y = e.clientY - rect.top;
  const inside = x >= 0 && y >= 0 && x <= rect.width && y <= rect.height;
  // Track hover position for the crosshair + OHLC readout. Only update
  // while NOT dragging — during a drag the cursor moves but the chart
  // body is being repositioned, so a stale crosshair is more confusing
  // than useful.
  if (!dragMode) {
    if (inside) {
      const z = hitZone(x, y);
      wrap.style.cursor = z === 'zoom-y'
          ? 'ns-resize'
          : z === 'zoom-x' ? 'ew-resize' : 'crosshair';
      const p = plot();
      const inPlot = x >= p.left && x <= p.right && y >= p.top && y <= p.bottom;
      if (inPlot) {
        if (hover.x !== x || hover.y !== y || !hover.inside) {
          hover.x = x; hover.y = y; hover.inside = true;
          scheduleRedraw();
        }
      } else if (hover.inside) {
        hover.inside = false; scheduleRedraw();
      }
    } else if (hover.inside) {
      hover.inside = false; scheduleRedraw();
    }
    return;
  }
  // Drag in progress — hide the crosshair to keep the screen calm.
  if (hover.inside) { hover.inside = false; scheduleRedraw(); }
  const dx = e.clientX - dragLastX;
  const dy = e.clientY - dragLastY;
  dragLastX = e.clientX; dragLastY = e.clientY;
  if (dragMode === 'pan') {
    view.offsetX += dx;
    view.offsetY += dy;
  } else if (dragMode === 'zoom-y') {
    // Drag UP on the price axis = taller rows (zoom in vertically).
    // Multiplier kept low so a small drag doesn't whip the chart through
    // its whole zoom range.
    view.rowH = clamp(view.rowH - dy * 0.15, 4, 60);
  } else if (dragMode === 'zoom-x') {
    // Drag RIGHT on the time axis = wider columns (zoom in horizontally).
    view.cellW = clamp(view.cellW + dx * 0.6, 30, 260);
  }
  scheduleRedraw();
});

wrap.addEventListener('mouseleave', () => {
  if (hover.inside) { hover.inside = false; scheduleRedraw(); }
});

wrap.addEventListener('wheel', (e) => {
  e.preventDefault();
  const factor = e.deltaY < 0 ? 1.1 : 1 / 1.1;
  if (e.shiftKey) {
    view.rowH = clamp(view.rowH * factor, 6, 60);
  } else {
    view.cellW = clamp(view.cellW * factor, 30, 260);
  }
  view.autoFollow = false;
  view.autoFitY = false;
  scheduleRedraw();
}, { passive: false });

// Double-click → recentre + re-enable auto-follow / auto-fit.
wrap.addEventListener('dblclick', () => {
  view.offsetX = 0;
  view.offsetY = 0;
  view.autoFollow = true;
  view.autoFitY = true;
  scheduleRedraw();
});

// ---------------------------------------------------------------------------
// TOPBAR UPDATES
// ---------------------------------------------------------------------------
const elSym = document.getElementById('sym');
const elTf = document.getElementById('tf');
const elStatus = document.getElementById('status');
const elCounters = document.getElementById('counters');
const overlay = document.getElementById('overlay');
const overlayTitle = document.getElementById('overlay-title');
const overlayDetail = document.getElementById('overlay-detail');

function showOverlay(title, detail) {
  overlay.hidden = false;
  overlayTitle.textContent = title || '';
  overlayDetail.textContent = detail || '';
}
function hideOverlay() { overlay.hidden = true; }

function updateTopbar() {
  elSym.textContent = SYMBOL;
  elTf.textContent = TIMEFRAME;
  elCounters.textContent = `${candles.length} candles · sess Δ ${structure.session_cd >= 0 ? '+' : ''}${structure.session_cd}`;
  const ageSec = lastTickAt ? (Date.now() - lastTickAt) / 1000 : 9999;
  let cls = 'status status-offline', label = 'Offline';
  if (lastTickAt) {
    if (ageSec <= 10) { cls = 'status status-live'; label = 'Live'; }
    else if (ageSec <= 120) { cls = 'status status-quiet'; label = 'Quiet'; }
    else { cls = 'status status-stale'; label = 'Market closed'; }
  } else if (ws && ws.readyState === 1) {
    cls = 'status status-quiet'; label = 'Connecting…';
  }
  elStatus.className = cls;
  elStatus.textContent = label;
}
setInterval(updateTopbar, 1000);

// ---------------------------------------------------------------------------
// PARENT MESSAGE BRIDGE  (Flutter shell → iframe)
// ---------------------------------------------------------------------------
window.addEventListener('message', (e) => {
  // Accept both plain objects (from JS callers) and JSON strings (from the
  // Flutter shell — dart:html postMessage doesn't round-trip Dart Maps
  // cleanly, so the Flutter side sends a JSON string).
  let d = e.data;
  if (typeof d === 'string') {
    try { d = JSON.parse(d); } catch (_) { return; }
  }
  if (!d || typeof d !== 'object') return;
  if (d.type === 'setSymbol' && typeof d.value === 'string' && d.value !== SYMBOL) {
    SYMBOL = d.value.toUpperCase();
    bootstrap();
  } else if (d.type === 'setTimeframe' && typeof d.value === 'string' && d.value !== TIMEFRAME) {
    TIMEFRAME = d.value;
    bootstrap();
  } else if (d.type === 'setTheme' && typeof d.value === 'string') {
    applyTheme(d.value);
  } else if (d.type === 'setOverlays' && d.value && typeof d.value === 'object') {
    if (typeof d.value.imb === 'boolean') overlays.imb = d.value.imb;
    if (typeof d.value.poc === 'boolean') overlays.poc = d.value.poc;
    if (typeof d.value.va === 'boolean') overlays.va = d.value.va;
    if (typeof d.value.vwap === 'boolean') overlays.vwap = d.value.vwap;
    if (typeof d.value.grid === 'boolean') overlays.grid = d.value.grid;
    scheduleRedraw();
  } else if (d.type === 'refresh') {
    loadStructure();
  }
});

// ---------------------------------------------------------------------------
// BOOTSTRAP
// ---------------------------------------------------------------------------
async function bootstrap() {
  applyTheme(THEME);
  resizeCanvas();
  updateTopbar();
  await loadHistory();
  await loadStructure();
  connectWS();
  setInterval(loadStructure, 3000);
  scheduleRedraw();
  // Notify parent we're ready (Flutter listens for this). Send as a JSON
  // string for the same reason the inbound side accepts strings — Dart's
  // postMessage receiver gets a plain string here without any cross-boundary
  // type confusion.
  try { parent.postMessage('{"type":"orderflow-ready"}', '*'); } catch (_) {}
}

bootstrap();
