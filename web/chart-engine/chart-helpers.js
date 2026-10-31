'use strict';

// ---------------------------------------------------------------------------
// chart-helpers.js — pure, this-free helpers shared by the chart engine.
// Loaded BEFORE chart.js (cross-script names resolve at call time). Split out
// of chart.js so the math/geometry is unit-testable under node and chart.js
// stays focused. Behaviour is identical to the originals.
// ---------------------------------------------------------------------------
function _windowSecondsFor(minutes) {
  // Sensible default windows so the chart starts useful but doesn't
  // overfetch. All in seconds.
  if (minutes < 60) return 5 * 24 * 60 * 60;           // 5 days for intraday <1h
  if (minutes < 1440) return 60 * 24 * 60 * 60;        // 60 days for hourly
  if (minutes === 1440) return 2 * 365 * 24 * 60 * 60; // 2 years for daily
  if (minutes === 10080) return 5 * 365 * 24 * 60 * 60; // 5 years for weekly
  return 20 * 365 * 24 * 60 * 60;                       // 20 years for monthly+
}

function _newRequestId() {
  return 'req_' + Math.random().toString(36).slice(2) + '_' + Date.now();
}

// Hex → rgba string. Used by chip backgrounds to tint a panel with an
// indicator's own colour at low alpha — gives each chip a colour-coded
// background without overwhelming the chart behind it.
function _hexToRgba(hex, alpha) {
  let h = (hex || '').replace('#', '');
  if (h.length === 3) {
    h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
  }
  if (h.length !== 6) return 'rgba(75,85,99,' + alpha + ')';
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
}
// Long/short position render (shared by longpos/shortpos). dir = +1 long.
// Build the [entry, stop, target] point set for a position tool from the
// single clicked anchor (stop 1.5×ATR away, target at 2R). All three share the
// entry's time so they stack as draggable horizontal levels.
function _positionExpand(points, chart, dir) {
  const e = points && points[0];
  if (!e) return points;
  const bars = (chart && chart.candles) ? chart.candles : [];
  const idx = _nearestIndex(bars, e.ts);
  let atr = _wilderATR(bars, idx, 14);
  if (atr === undefined || !(atr > 0)) atr = Math.max(Math.abs(e.price) * 0.02, 1e-8);
  const stop = e.price - dir * 1.5 * atr;
  const target = e.price + dir * 2 * Math.abs(e.price - stop);
  return [
    { ts: e.ts, price: e.price },
    { ts: e.ts, price: stop },
    { ts: e.ts, price: target },
  ];
}

function _positionRender(g, d, dir) {
  const pts = d.points;
  const e = pts && pts[0];
  if (!e) return null;
  const x0 = g.tsToX(e.ts);
  const barSec = _barSec(g.candles);
  const x1 = g.tsToX(e.ts + 12 * barSec);
  const w = (Number.isFinite(x1) && x1 - x0 > 8) ? (x1 - x0) : 120;
  let stop, target;
  if (pts.length >= 3 && pts[1] && pts[2]) {
    // Stored (and independently draggable) stop / target levels.
    stop = pts[1].price;
    target = pts[2].price;
  } else {
    const idx = _nearestIndex(g.candles, e.ts);
    let atr = _wilderATR(g.candles, idx, 14);
    if (atr === undefined || !(atr > 0)) atr = Math.max(Math.abs(e.price) * 0.02, 1e-8);
    stop = e.price - dir * 1.5 * atr;
    target = e.price + dir * 2 * Math.abs(e.price - stop);
  }
  const riskBase = Math.abs(e.price - stop);
  const riskR = riskBase > 0 ? Math.abs(target - e.price) / riskBase : 0;
  const yE = g.priceToY(e.price), yS = g.priceToY(stop), yT = g.priceToY(target);
  const ctx = g.ctx;
  ctx.save();
  ctx.fillStyle = _hexToRgba(_SMART_RED, 0.12);
  ctx.fillRect(x0, Math.min(yE, yS), w, Math.abs(yS - yE));
  ctx.fillStyle = _hexToRgba(_SMART_GREEN, 0.12);
  ctx.fillRect(x0, Math.min(yE, yT), w, Math.abs(yT - yE));
  ctx.setLineDash([4, 3]); ctx.lineWidth = 1;
  ctx.strokeStyle = _SMART_RED;
  ctx.beginPath(); ctx.moveTo(x0, yS); ctx.lineTo(x0 + w, yS); ctx.stroke();
  ctx.strokeStyle = _SMART_GREEN;
  ctx.beginPath(); ctx.moveTo(x0, yT); ctx.lineTo(x0 + w, yT); ctx.stroke();
  ctx.restore();
  g.drawLine(x0, yE, x0 + w, yE);
  _drawNodeLabel(g.ctx, x0 + w, yE, 'Entry ' + e.price.toFixed(2), g.color, false);
  _drawNodeLabel(g.ctx, x0 + w, yT, 'Target ' + target.toFixed(2), _SMART_GREEN, false);
  _drawNodeLabel(g.ctx, x0 + w, yS, 'Stop ' + stop.toFixed(2), _SMART_RED, false);
  _drawNodeLabel(g.ctx, x0 + w / 2, Math.min(yT, yS) - 2, 'R:R ' + riskR.toFixed(1), g.color, true);
  const ys = [yE, yS, yT];
  return {
    endX: x0 + w, endY: yE,
    dragRect: g.isInProgress ? null
        : { x: x0, y: Math.min(...ys) - 4, w, h: Math.max(...ys) - Math.min(...ys) + 8 },
  };
}

// Axis-aligned bounding band (with a little vertical slack) around a segment,
// used as the translate hit-region for registry-drawn line tools.
function _bandRect(ax, ay, bx, by) {
  if (![ax, ay, bx, by].every(Number.isFinite)) return null;
  const minX = Math.min(ax, bx), maxX = Math.max(ax, bx);
  const minY = Math.min(ay, by), maxY = Math.max(ay, by);
  return { x: minX, y: minY - 4, w: maxX - minX, h: (maxY - minY) + 8 };
}

// Liang–Barsky parameter clip: the t-range over which the infinite line
// (px,py) + t·(dx,dy) lies inside the rectangle [L,R]×[T,B]. Returns [t0,t1]
// (t0 ≤ t1) or null if the line misses the rect (or has zero direction).
function _lineRectParams(px, py, dx, dy, L, T, R, B) {
  if (dx === 0 && dy === 0) return null;
  let t0 = -Infinity, t1 = Infinity;
  const p = [-dx, dx, -dy, dy];
  const q = [px - L, R - px, py - T, B - py];
  for (let i = 0; i < 4; i++) {
    if (p[i] === 0) {
      if (q[i] < 0) return null; // parallel and outside this edge
    } else {
      const r = q[i] / p[i];
      if (p[i] < 0) { if (r > t0) t0 = r; }
      else { if (r < t1) t1 = r; }
    }
  }
  if (t0 > t1) return null;
  return [t0, t1];
}

// Filled arrowhead at (x2,y2) pointing along (x1,y1)→(x2,y2).
function _drawArrowHead(ctx, x1, y1, x2, y2, color, size) {
  const ang = Math.atan2(y2 - y1, x2 - x1);
  const a = size || 10;
  const spread = Math.PI / 7;
  ctx.save();
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(x2, y2);
  ctx.lineTo(x2 - a * Math.cos(ang - spread), y2 - a * Math.sin(ang - spread));
  ctx.lineTo(x2 - a * Math.cos(ang + spread), y2 - a * Math.sin(ang + spread));
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

// Bounding-box dragRect for a set of screen points (with vertical slack).
function _bboxRect(xs, ys) {
  const minX = Math.min(...xs), maxX = Math.max(...xs);
  const minY = Math.min(...ys), maxY = Math.max(...ys);
  if (![minX, maxX, minY, maxY].every(Number.isFinite)) return null;
  return { x: minX, y: minY - 4, w: maxX - minX, h: (maxY - minY) + 8 };
}

// A small pill label centred at (x,y) — used for pattern vertices and info
// readouts. `above` lifts it above the point.
function _drawNodeLabel(ctx, x, y, text, color, above) {
  if (!Number.isFinite(x) || !Number.isFinite(y)) return;
  ctx.save();
  ctx.font = '700 10px Geist, sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  const ly = above === false ? y : y - 13;
  const w = Math.max(16, ctx.measureText(text).width + 8);
  ctx.fillStyle = 'rgba(15,23,42,0.82)';
  _roundRectPath(ctx, x - w / 2, ly - 8, w, 16, 4);
  ctx.fill();
  ctx.strokeStyle = color;
  ctx.lineWidth = 1;
  _roundRectPath(ctx, x - w / 2, ly - 8, w, 16, 4);
  ctx.stroke();
  ctx.fillStyle = '#FFFFFF';
  ctx.fillText(text, x, ly);
  ctx.restore();
}

// Draw legible text with a white halo (so it reads over candles). Returns the
// measured text width. `align` defaults to 'left'.
function _drawText(ctx, x, y, t, color, align) {
  ctx.save();
  ctx.font = '600 12px Geist, sans-serif';
  ctx.textBaseline = 'middle';
  ctx.textAlign = align || 'left';
  ctx.lineJoin = 'round';
  ctx.strokeStyle = 'rgba(255,255,255,0.85)';
  ctx.lineWidth = 3;
  ctx.strokeText(t, x, y);
  ctx.fillStyle = color;
  ctx.fillText(t, x, y);
  const w = ctx.measureText(t).width;
  ctx.restore();
  return w;
}

// Rounded-rect path (module-level twin of the Chart method, for the helpers
// that draw outside a Chart instance).
function _roundRectPath(ctx, x, y, w, h, r) {
  const rr = Math.min(r, Math.abs(w) / 2, Math.abs(h) / 2);
  ctx.beginPath();
  ctx.moveTo(x + rr, y);
  ctx.arcTo(x + w, y, x + w, y + h, rr);
  ctx.arcTo(x + w, y + h, x, y + h, rr);
  ctx.arcTo(x, y + h, x, y, rr);
  ctx.arcTo(x, y, x + w, y, rr);
  ctx.closePath();
}

// Connect a sequence of anchors with the halo line, optionally close the
// polygon, and label each vertex. Shared by the harmonic / wave / chart
// patterns (XABCD, ABCD, Cypher, Elliott, Three Drives, Head & Shoulders…).
// `labels` length also defines how many anchors the shape expects, so the
// in-progress preview appends the live cursor as the next provisional vertex.
function _renderPolyPattern(g, d, labels, opts) {
  const o = opts || {};
  const pts = d.points;
  if (!pts || pts.length === 0) return null;
  const scr = pts.map((p) => ({ x: g.tsToX(p.ts), y: g.priceToY(p.price) }));
  if (g.isInProgress && scr.length < labels.length &&
      g.hover.inside && g.hover.x != null) {
    scr.push({ x: g.hover.x, y: g.hover.y });
  }
  if (scr.length >= 3 && o.fill) {
    g.ctx.save();
    g.ctx.fillStyle = _hexToRgba(g.color, 0.08);
    g.ctx.beginPath();
    g.ctx.moveTo(scr[0].x, scr[0].y);
    for (let i = 1; i < scr.length; i++) g.ctx.lineTo(scr[i].x, scr[i].y);
    g.ctx.closePath();
    g.ctx.fill();
    g.ctx.restore();
  }
  for (let i = 0; i < scr.length - 1; i++) {
    g.drawLine(scr[i].x, scr[i].y, scr[i + 1].x, scr[i + 1].y);
  }
  if (o.close && scr.length >= labels.length && scr.length >= 3) {
    g.drawLine(scr[scr.length - 1].x, scr[scr.length - 1].y, scr[0].x, scr[0].y);
  }
  for (let i = 0; i < scr.length && i < labels.length; i++) {
    if (labels[i]) _drawNodeLabel(g.ctx, scr[i].x, scr[i].y, labels[i], g.color, true);
  }
  const xs = scr.map((s) => s.x), ys = scr.map((s) => s.y);
  return {
    endX: Math.max(...xs), endY: Math.min(...ys),
    dragRect: g.isInProgress ? null : _bboxRect(xs, ys),
  };
}

// Canonical Fibonacci ratio sets reused by the Fib-family tools.
const _FIB_RETR = [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0];
const _FIB_EXT = [0, 0.382, 0.618, 1.0, 1.272, 1.618, 2.0, 2.618];
const _FIB_TIME = [0, 1, 2, 3, 5, 8, 13, 21, 34];
const _FIB_COLORS = ['#94A3B8', '#0EA5E9', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#94A3B8', '#EC4899', '#22D3EE'];

const _SMART_RED = '#ef5350';
const _SMART_GREEN = '#26a69a';

// Median candle spacing (sec) from the loaded candles; 1 when unknown.
function _barSec(candles) {
  if (!candles || candles.length < 2) return 1;
  return (candles[1].ts - candles[0].ts) || 1;
}

// Index of the candle nearest to ts (candles ascending by ts). -1 if empty.
function _nearestIndex(candles, ts) {
  if (!candles || candles.length === 0) return -1;
  let lo = 0, hi = candles.length - 1;
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (candles[mid].ts < ts) lo = mid + 1; else hi = mid;
  }
  // lo is first >= ts; pick whichever neighbour is closer.
  if (lo > 0 && Math.abs(candles[lo - 1].ts - ts) <= Math.abs(candles[lo].ts - ts)) return lo - 1;
  return lo;
}

// Wilder ATR over `period` ending at candle index `last` (inclusive).
// Returns undefined when there isn't enough history.
function _wilderATR(candles, last, period) {
  if (!candles || last < period) return undefined;
  let atr = 0;
  for (let i = last - period + 1; i <= last; i++) {
    const c = candles[i], prev = candles[i - 1];
    if (!prev) return undefined;
    const tr = Math.max(
        c.h - c.l,
        Math.abs(c.h - prev.c),
        Math.abs(c.l - prev.c));
    atr += tr;
  }
  return atr / period;
}

function _lerpPt(p, q, t) {
  return { x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t };
}

// Resolve a 3-anchor fork's screen points with live-cursor preview for the
// pending anchor. Returns { a, b, c } where b/c may be null while placing.
function _forkAnchors(g, d) {
  const pts = d.points;
  if (!pts || pts.length < 1) return null;
  const P = (p) => ({ x: g.tsToX(p.ts), y: g.priceToY(p.price) });
  const a = P(pts[0]);
  let b = null, c = null;
  if (pts.length >= 2) b = P(pts[1]);
  else if (g.hover.inside && g.hover.x != null) b = { x: g.hover.x, y: g.hover.y };
  if (pts.length >= 3) c = P(pts[2]);
  else if (pts.length === 2 && g.hover.inside && g.hover.x != null) c = { x: g.hover.x, y: g.hover.y };
  return { a, b, c };
}

// Draw a pitchfork from its median origin/target and the two tine anchors.
// Median + both tines are rays extended to the plot edge; the p1–p2 base is
// dashed and the band between the tines is lightly filled.
function _drawForkInChart(g, origin, b, c, target) {
  const dx = target.x - origin.x, dy = target.y - origin.y;
  const ext = (px, py) => {
    const range = g.lineParams(px, py, dx, dy);
    if (!range) return { x: px, y: py };
    const t = Math.max(range[0], range[1]);
    return { x: px + dx * t, y: py + dy * t };
  };
  const mEnd = ext(origin.x, origin.y);
  const bEnd = ext(b.x, b.y);
  const cEnd = ext(c.x, c.y);
  const ctx = g.ctx;
  ctx.save();
  ctx.fillStyle = _hexToRgba(g.color, 0.06);
  ctx.beginPath();
  ctx.moveTo(b.x, b.y); ctx.lineTo(bEnd.x, bEnd.y);
  ctx.lineTo(cEnd.x, cEnd.y); ctx.lineTo(c.x, c.y);
  ctx.closePath(); ctx.fill();
  ctx.setLineDash([4, 4]);
  ctx.strokeStyle = _hexToRgba(g.color, 0.7); ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(b.x, b.y); ctx.lineTo(c.x, c.y); ctx.stroke();
  ctx.restore();
  g.drawLine(b.x, b.y, bEnd.x, bEnd.y);
  g.drawLine(c.x, c.y, cEnd.x, cEnd.y);
  g.drawLine(origin.x, origin.y, mEnd.x, mEnd.y);
  const xs = [origin.x, b.x, c.x, mEnd.x, bEnd.x, cEnd.x];
  const ys = [origin.y, b.y, c.y, mEnd.y, bEnd.y, cEnd.y];
  return {
    endX: Math.max(...xs), endY: mEnd.y,
    dragRect: g.isInProgress ? null : _bboxRect(xs, ys),
  };
}

// Shared partial/edge handling for the fork variants: returns a result object
// when the fork isn't fully placeable yet (so the variant just builds origin/
// target from the anchors when this returns null).
function _forkPartial(g, an) {
  if (!an || !an.b) return an ? { endX: an.a.x, endY: an.a.y, dragRect: null } : null;
  if (!an.c) {
    g.drawLine(an.a.x, an.a.y, an.b.x, an.b.y);
    return {
      endX: Math.max(an.a.x, an.b.x), endY: (an.a.y + an.b.y) / 2,
      dragRect: null,
    };
  }
  return null;
}

// ── Session clock (pure) ─────────────────────────────────────────────────
// IST = UTC + 5:30. Convert epoch seconds to IST calendar parts via UTC
// getters on a shifted Date so there is no host-timezone dependence.
function _istParts(tsSec) {
  const d = new Date(tsSec * 1000 + 5.5 * 3600 * 1000);
  return {
    year: d.getUTCFullYear(),
    month: d.getUTCMonth(),          // 0-11
    date: d.getUTCDate(),
    dow: d.getUTCDay(),              // 0 = Sun .. 6 = Sat
    minuteOfDay: d.getUTCHours() * 60 + d.getUTCMinutes(),
  };
}

// IST calendar-day key for same-day comparisons (not for display).
function _istDayKey(tsSec) {
  const p = _istParts(tsSec);
  return p.year + '-' + p.month + '-' + p.date;
}

// Day-of-month (1-31) of the nth Sunday of a month. monthIndex is 0-11.
function _nthSundayOfMonth(year, monthIndex, n) {
  const firstDow = new Date(Date.UTC(year, monthIndex, 1)).getUTCDay();
  const firstSunday = 1 + ((7 - firstDow) % 7);
  return firstSunday + (n - 1) * 7;
}

// US daylight saving: 2nd Sunday of March → 1st Sunday of November.
// Day granularity in IST is plenty (MCX's two closes differ by 25 min).
function _usInDst(tsSec) {
  const p = _istParts(tsSec);
  if (p.month < 2 || p.month > 10) return false;        // Jan, Feb, Dec
  if (p.month > 2 && p.month < 10) return true;          // Apr..Oct
  if (p.month === 2) return p.date >= _nthSundayOfMonth(p.year, 2, 2);
  if (p.month === 10) return p.date < _nthSundayOfMonth(p.year, 10, 1);
  return false;
}

// Session bounds (IST minutes from midnight). closeMin is EXCLUSIVE.
// nulls => unmapped exchange => always-on (never gated, never "closed").
function _sessionBoundsFor(exch, tsSec) {
  if (exch === 'NSE' || exch === 'NFO' || exch === 'BSE' || exch === 'BFO') {
    return { openMin: 555, closeMin: 940 };              // 09:15–15:40 (matches TradingView chart)
  }
  if (exch === 'CDS' || exch === 'BCD') {
    return { openMin: 540, closeMin: 1020 };             // 09:00–17:00
  }
  if (exch === 'MCX') {
    return { openMin: 540, closeMin: _usInDst(tsSec) ? 1410 : 1435 }; // 23:30 / 23:55
  }
  return { openMin: null, closeMin: null };
}

// True when tsSec is inside the exchange session window (weekday + open<=m<close).
// Unmapped exchanges are always "in session".
function _isSessionWindowPure(exch, tsSec) {
  const b = _sessionBoundsFor(exch, tsSec);
  if (b.openMin == null) return true;
  const p = _istParts(tsSec);
  if (p.dow === 0 || p.dow === 6) return false;
  return p.minuteOfDay >= b.openMin && p.minuteOfDay < b.closeMin;
}


// ── CPR with Pivot Level Daily ──────────────────────────────────────────────
// Port of the TradingView custom study "CPR with Pivot Level Daily"
// (CPRwithPivotLevelDaily@tv-basicstudies-1). Every bar shows the levels made
// from the PREVIOUS trading day's official daily high / low / close, for bars
// in the last 30 days only (as the TradingView version did).
//
// The 13 plots in the study's metainfo order (later plots draw on top), with
// its default colours and visibility. Per-line settings live in the
// indicator's numeric params as `<key><field>`:
//   V visible 0/1 · C colour 0xRRGGBB · W width 1-4 · S line style index
//   T plot type index · P price line 0/1          — plus `precision` (index).
// Option orders MUST match indicator_schema.dart (cpr).
const CPR_PLOTS = [
  { key: 'pivot', title: 'Daily Central Pivot', color: '#F8AF85', visible: true },
  { key: 'high',  title: 'Prev Day High',       color: '#6CAC6E', visible: false },
  { key: 'low',   title: 'Prev Day Low',        color: '#EB2D2D', visible: false },
  { key: 'bc',    title: 'Daily Bottom Pivot',  color: '#9C50E4', visible: true },
  { key: 'tc',    title: 'Daily Top Pivot',     color: '#91A9F1', visible: true },
  { key: 's1',    title: 'Daily S1',            color: '#FF0000', visible: false },
  { key: 'r1',    title: 'Daily R1',            color: '#008000', visible: false },
  { key: 's2',    title: 'Daily S2',            color: '#FF0000', visible: false },
  { key: 'r2',    title: 'Daily R2',            color: '#008000', visible: false },
  { key: 's3',    title: 'Daily S3',            color: '#FF0000', visible: false },
  { key: 'r3',    title: 'Daily R3',            color: '#008000', visible: false },
  { key: 's4',    title: 'Daily S4',            color: '#FF0000', visible: false },
  { key: 'r4',    title: 'Daily R4',            color: '#008000', visible: false },
];
// TradingView's plot types for a line plot, in its Style-tab order. The study
// defaults every plot to Circles (its plottype 6), width 3, solid.
const CPR_PLOT_TYPES = ['line', 'linebr', 'step', 'stepbr', 'stepdiamond',
  'histogram', 'cross', 'area', 'areabr', 'columns', 'circles'];
const CPR_LINE_STYLES = ['solid', 'dotted', 'dashed'];
const _CPR_DEF_WIDTH = 3;
const _CPR_DEF_STYLE = 0;   // solid
const _CPR_DEF_TYPE = 10;   // circles
const _CPR_LOOKBACK_DAYS = 30;

function cprLevels(h, l, c) {
  const pivot = (h + l + c) / 3;
  const bc = (h + l) / 2;
  const tc = 2 * pivot - bc;
  const r1 = 2 * pivot - l;
  const r2 = pivot + h - l;
  const r3 = r1 + h - l;
  const r4 = r3 + r2 - r1;
  const s1 = 2 * pivot - h;
  const s2 = pivot - h + l;
  const s3 = s1 - h + l;
  const s4 = s3 + s2 - s1;
  return { pivot, high: h, low: l, bc, tc, s1, r1, s2, r2, s3, r3, s4, r4 };
}

// IST calendar day number (days since 1970-01-01 in IST).
function _cprIstDay(tsSec) {
  return Math.floor((tsSec + 19800) / 86400);
}

// One array per plot key, aligned to `candles`; NaN where a bar has no level
// (older than 30 days before `nowMs`, or no earlier daily bar). A bar's levels
// come from the latest daily bar dated BEFORE the bar's own IST day, so today
// uses the last completed day even if the daily data already holds a partial
// bar for today, and Monday uses Friday.
function computeCprSeries(candles, dailyBars, nowMs) {
  const n = Array.isArray(candles) ? candles.length : 0;
  const out = {};
  for (const p of CPR_PLOTS) out[p.key] = new Array(n).fill(NaN);
  if (!n || !Array.isArray(dailyBars) || dailyBars.length === 0) return out;
  const days = dailyBars
      .filter((b) => b && isFinite(b.ts) && isFinite(b.h) && isFinite(b.l) && isFinite(b.c))
      .map((b) => ({ day: _cprIstDay(b.ts), lv: cprLevels(+b.h, +b.l, +b.c) }))
      .sort((a, b) => a.day - b.day);
  const cutoffSec = nowMs / 1000 - _CPR_LOOKBACK_DAYS * 86400;
  let j = -1;   // latest daily bar with day < current candle's day
  for (let i = 0; i < n; i++) {
    const ts = candles[i].ts;
    const d = _cprIstDay(ts);
    while (j + 1 < days.length && days[j + 1].day < d) j++;
    if (ts < cutoffSec || j < 0) continue;
    const lv = days[j].lv;
    for (const p of CPR_PLOTS) out[p.key][i] = lv[p.key];
  }
  return out;
}

// Resolved style for one plot from the indicator's params (defaults when a
// key is missing — a freshly added CPR has an empty params map).
function cprPlotStyle(params, plot) {
  const p = params || {};
  const k = plot.key;
  const num = (field, def) => {
    const v = p[k + field];
    return (typeof v === 'number' && isFinite(v)) ? v : def;
  };
  const colorNum = num('C', parseInt(plot.color.slice(1), 16)) | 0;
  return {
    visible: num('V', plot.visible ? 1 : 0) >= 1,
    color: '#' + (colorNum & 0xFFFFFF).toString(16).toUpperCase().padStart(6, '0'),
    width: Math.max(1, Math.min(4, num('W', _CPR_DEF_WIDTH) | 0)),
    lineStyle: CPR_LINE_STYLES[num('S', _CPR_DEF_STYLE) | 0] || 'solid',
    plotType: CPR_PLOT_TYPES[num('T', _CPR_DEF_TYPE) | 0] || 'circles',
    priceLine: num('P', 0) >= 1,
  };
}

// Decimals for values: index 0 = "Default" (the study's precision 2), index
// k > 0 = k - 1 decimals (options Default, 0, 1, … 8).
function cprDecimals(params) {
  const i = (params && typeof params.precision === 'number') ? params.precision | 0 : 0;
  return i <= 0 ? 2 : Math.min(8, i - 1);
}


// ── CPR Trend Checker (CPR + MAs) ───────────────────────────────────────────
// Previous-period Central Pivot Range levels for the day, week and month, with
// up to five moving averages. Built from the public description and the
// settings screens of the TradingView study of this kind; the maths are the
// standard pivot formulas, checked against a TradingView chart (see the tests).
//
// All settings are numeric params (the persistence pipeline is Map<String,num>):
//   inputs   auto dOn pdOn wOn pwOn mOn pmOn            switches 0/1
//   a line   <key><V|C|O|W|S|T>   visible, colour 0xRRGGBB, opacity %, width,
//                                 line style index, plot type index
//   a band   <d|w|m>Band<V|C|O>
//   an MA    ma<i>On / Type / Src / Len / C / W         (i = 1..5)
//   output   labelsOn precision axisOn statusOn inputsOn
// Missing keys mean "default", so a saved indicator only needs the values the
// user changed. Option orders MUST match indicator_schema.dart.
const TC_GROUPS = [
  { id: 'd', pre: 'Daily',   hl: ['PDH', 'PDL'], short: 'D', color: '#2962FF', hlColor: '#000000' },
  { id: 'w', pre: 'Weekly',  hl: ['PWH', 'PWL'], short: 'W', color: '#C41D9D', hlColor: '#000000' },
  { id: 'm', pre: 'Monthly', hl: ['PMH', 'PML'], short: 'M', color: '#F58FD8', hlColor: '#000000' },
];
// Study order per group: PDH, PDL, CPR, BC, TC, R1, S1, R2, S2, R3, S3, R4, S4.
const TC_LINES = (() => {
  const out = [];
  for (const g of TC_GROUPS) {
    const hp = g.id === 'd' ? 'pd' : g.id === 'w' ? 'pw' : 'pm';
    const mk = (key, field, title, label, color, alpha, sw) =>
      out.push({ key, group: g.id, field, title, label, color, alpha, sw });
    mk(hp + 'h', 'high', g.hl[0], g.hl[0], g.hlColor, 100, 'hl');
    mk(hp + 'l', 'low', g.hl[1], g.hl[1], g.hlColor, 100, 'hl');
    mk(g.id + 'cpr', 'pivot', g.pre + ' CPR', g.pre + ' CPR', g.color, 50, 'cpr');
    mk(g.id + 'bc', 'bc', g.pre + ' BC', '', g.color, 0, 'cpr');
    mk(g.id + 'tc', 'tc', g.pre + ' TC', '', g.color, 0, 'cpr');
    for (const n of [1, 2, 3, 4]) {
      mk(g.id + 'r' + n, 'r' + n, g.pre + ' R' + n, g.short + '-R' + n, '#4CAF50', 100, 'cpr');
      mk(g.id + 's' + n, 's' + n, g.pre + ' S' + n, g.short + '-S' + n, '#FF5252', 100, 'cpr');
    }
  }
  return out;
})();
const TC_BANDS = TC_GROUPS.map((g) => ({
  key: g.id + 'Band', group: g.id, title: g.pre + ' CPR Band', color: g.color, alpha: 25,
}));
const TC_MA_TYPES = ['SMA', 'EMA', 'WMA', 'RMA', 'HMA', 'VWMA'];
const TC_MA_SOURCES = ['close', 'open', 'high', 'low', 'hl2', 'hlc3', 'ohlc4'];
const TC_MA_DEFAULTS = [
  { on: 0, len: 10,  color: '#F6C309' },
  { on: 0, len: 20,  color: '#157A11' },
  { on: 0, len: 50,  color: '#FC1A1A' },
  { on: 0, len: 100, color: '#160101' },
  { on: 0, len: 200, color: '#0C7DF6' },
];
const _TC_DEF_WIDTH = 1;
const _TC_DEF_TYPE = 10;     // circles
const _TC_MA_WIDTH = 2;

// The CPR levels from a period's high / low / close. R4 and S4 extend the
// R3/S3 spacing (2*R3-R2, 2*S3-S2) — what the TradingView chart shows.
function tcLevels(h, l, c) {
  const pivot = (h + l + c) / 3;
  const bc = (h + l) / 2;
  const tc = 2 * pivot - bc;
  const r1 = 2 * pivot - l;
  const s1 = 2 * pivot - h;
  const r2 = pivot + (h - l);
  const s2 = pivot - (h - l);
  const r3 = r1 + (h - l);
  const s3 = s1 - (h - l);
  const r4 = 2 * r3 - r2;
  const s4 = 2 * s3 - s2;
  return { high: h, low: l, pivot, bc, tc, r1, s1, r2, s2, r3, s3, r4, s4 };
}

const _TC_FIELDS = ['high', 'low', 'pivot', 'bc', 'tc', 'r1', 's1', 'r2', 's2', 'r3', 's3', 'r4', 's4'];

// IST day number (days since 1970-01-01 in IST), Monday-based week number,
// calendar month number.
function _tcDayIdx(tsSec) { return Math.floor((tsSec + 19800) / 86400); }
function _tcWeekIdx(dayIdx) { return Math.floor((dayIdx - 4) / 7); }   // 1970-01-05 is a Monday
function _tcMonthIdx(dayIdx) {
  const d = new Date(dayIdx * 86400000);
  return d.getUTCFullYear() * 12 + d.getUTCMonth();
}

// Daily bars -> periods { idx, h, l, c, lv } for each of d / w / m. The first
// week and month are dropped: the data may start in the middle of them, and a
// partial period would give wrong highs and lows.
function _tcPeriods(dailyBars) {
  const bars = (Array.isArray(dailyBars) ? dailyBars : [])
      .filter((b) => b && isFinite(b.ts) && isFinite(b.h) && isFinite(b.l) && isFinite(b.c))
      .slice().sort((a, b) => a.ts - b.ts);
  const group = (idxOf, dropFirst) => {
    const out = [];
    let cur = null;
    for (const b of bars) {
      const idx = idxOf(_tcDayIdx(b.ts));
      if (!cur || cur.idx !== idx) {
        cur = { idx, h: +b.h, l: +b.l, c: +b.c };
        out.push(cur);
      } else {
        if (b.h > cur.h) cur.h = +b.h;
        if (b.l < cur.l) cur.l = +b.l;
        cur.c = +b.c;
      }
    }
    if (dropFirst) out.shift();
    for (const p of out) p.lv = tcLevels(p.h, p.l, p.c);
    return out;
  };
  return {
    d: group((di) => di, false),
    w: group(_tcWeekIdx, true),
    m: group((di) => _tcMonthIdx(di), true),
  };
}

// For each candle, every group's levels from the period BEFORE the candle's own
// day / week / month, plus `seg` (the candle's own period id, to split drawing
// into one segment per period). NaN where there is no such period.
function computeTcSeries(candles, dailyBars) {
  const n = Array.isArray(candles) ? candles.length : 0;
  const per = _tcPeriods(dailyBars);
  const out = {};
  const keyOf = { d: (di) => di, w: _tcWeekIdx, m: _tcMonthIdx };
  for (const g of TC_GROUPS) {
    const o = { seg: new Array(n).fill(NaN) };
    for (const f of _TC_FIELDS) o[f] = new Array(n).fill(NaN);
    const periods = per[g.id];
    let j = -1;
    for (let i = 0; i < n; i++) {
      const key = keyOf[g.id](_tcDayIdx(candles[i].ts));
      o.seg[i] = key;
      while (j + 1 < periods.length && periods[j + 1].idx < key) j++;
      if (j < 0) continue;
      const lv = periods[j].lv;
      for (const f of _TC_FIELDS) o[f][i] = lv[f];
    }
    out[g.id] = o;
  }
  return out;
}

// Which level groups are on. `auto` picks the group from the chart timeframe
// (intraday: daily, daily chart: weekly, weekly and above: monthly) together
// with its previous high/low; otherwise the six switches decide.
function tcActiveGroups(params, timeframeMinutes) {
  const p = params || {};
  const sw = (k, def) => (typeof p[k] === 'number' ? p[k] >= 1 : def);
  if (sw('auto', false)) {
    const which = timeframeMinutes >= 10080 ? 'm' : timeframeMinutes >= 1440 ? 'w' : 'd';
    const o = {};
    for (const g of TC_GROUPS) o[g.id] = { cpr: g.id === which, hl: g.id === which };
    return o;
  }
  return {
    d: { cpr: sw('dOn', true), hl: sw('pdOn', true) },
    w: { cpr: sw('wOn', false), hl: sw('pwOn', false) },
    m: { cpr: sw('mOn', false), hl: sw('pmOn', false) },
  };
}

function _tcHex(n) { return '#' + (n & 0xFFFFFF).toString(16).toUpperCase().padStart(6, '0'); }
function _tcCss(hex, alpha) {
  if (alpha >= 1) return hex;
  const h2 = hex.replace('#', '');
  const r = parseInt(h2.slice(0, 2), 16), g = parseInt(h2.slice(2, 4), 16), b = parseInt(h2.slice(4, 6), 16);
  return 'rgba(' + r + ',' + g + ',' + b + ',' + (+alpha.toFixed(3)) + ')';
}

// Resolved style of one line from the params. `css` is the draw colour with the
// opacity applied; `color` the plain hex (used for labels and the legend, which
// stay readable even when the line itself is transparent).
function tcLineStyle(params, line) {
  const p = params || {};
  const num = (f, def) => {
    const v = p[line.key + f];
    return (typeof v === 'number' && isFinite(v)) ? v : def;
  };
  const color = _tcHex(num('C', parseInt(line.color.slice(1), 16)) | 0);
  const alpha = Math.max(0, Math.min(100, num('O', line.alpha))) / 100;
  return {
    visible: num('V', 1) >= 1,
    color,
    alpha,
    css: _tcCss(color, alpha),
    width: Math.max(1, Math.min(4, num('W', _TC_DEF_WIDTH) | 0)),
    lineStyle: CPR_LINE_STYLES[num('S', 0) | 0] || 'solid',
    plotType: CPR_PLOT_TYPES[num('T', _TC_DEF_TYPE) | 0] || 'circles',
    priceLine: false,
  };
}

function tcBandStyle(params, band) {
  const p = params || {};
  const num = (f, def) => {
    const v = p[band.key + f];
    return (typeof v === 'number' && isFinite(v)) ? v : def;
  };
  const color = _tcHex(num('C', parseInt(band.color.slice(1), 16)) | 0);
  const alpha = Math.max(0, Math.min(100, num('O', band.alpha))) / 100;
  return { visible: num('V', 1) >= 1, color, alpha, css: _tcCss(color, alpha) };
}

// Moving average i (1..5) settings.
function tcMaConfig(params, i) {
  const p = params || {};
  const d = TC_MA_DEFAULTS[i - 1];
  const num = (f, def) => {
    const v = p['ma' + i + f];
    return (typeof v === 'number' && isFinite(v)) ? v : def;
  };
  return {
    on: num('On', d.on) >= 1,
    type: TC_MA_TYPES[num('Type', 0) | 0] || 'SMA',
    src: TC_MA_SOURCES[num('Src', 0) | 0] || 'close',
    len: Math.max(1, Math.min(999, num('Len', d.len) | 0)),
    color: _tcHex(num('C', parseInt(d.color.slice(1), 16)) | 0),
    width: Math.max(1, Math.min(4, num('W', _TC_MA_WIDTH) | 0)),
  };
}

function _tcSrc(c, src) {
  switch (src) {
    case 1: return c.o;
    case 2: return c.h;
    case 3: return c.l;
    case 4: return (c.h + c.l) / 2;
    case 5: return (c.h + c.l + c.c) / 3;
    case 6: return (c.o + c.h + c.l + c.c) / 4;
    default: return c.c;
  }
}
function _tcSma(a, len) {
  const out = new Array(a.length).fill(NaN);
  let sum = 0, cnt = 0;
  for (let i = 0; i < a.length; i++) {
    if (isFinite(a[i])) { sum += a[i]; cnt++; } else { sum = 0; cnt = 0; continue; }
    if (cnt > len) sum -= a[i - len];
    if (cnt >= len) out[i] = sum / len;
  }
  return out;
}
function _tcEma(a, len, alpha) {
  const sma = _tcSma(a, len);
  const out = new Array(a.length).fill(NaN);
  let prev = NaN;
  for (let i = 0; i < a.length; i++) {
    if (isNaN(prev)) { if (isFinite(sma[i])) { prev = sma[i]; out[i] = prev; } continue; }
    prev = alpha * a[i] + (1 - alpha) * prev;
    out[i] = prev;
  }
  return out;
}
function _tcWma(a, len) {
  const out = new Array(a.length).fill(NaN);
  const den = len * (len + 1) / 2;
  for (let i = len - 1; i < a.length; i++) {
    let s = 0, ok = true;
    for (let k = 0; k < len; k++) {
      const v = a[i - len + 1 + k];
      if (!isFinite(v)) { ok = false; break; }
      s += v * (k + 1);
    }
    if (ok) out[i] = s / den;
  }
  return out;
}

// typeIdx / srcIdx index TC_MA_TYPES / TC_MA_SOURCES; NaN while warming up.
function tcMa(candles, typeIdx, srcIdx, len) {
  const n = Array.isArray(candles) ? candles.length : 0;
  const L = Math.max(1, len | 0);
  const src = new Array(n);
  for (let i = 0; i < n; i++) src[i] = _tcSrc(candles[i], srcIdx | 0);
  switch (TC_MA_TYPES[typeIdx | 0]) {
    case 'EMA': return _tcEma(src, L, 2 / (L + 1));
    case 'WMA': return _tcWma(src, L);
    case 'RMA': return _tcEma(src, L, 1 / L);
    case 'HMA': {
      const half = Math.max(1, Math.floor(L / 2));
      const a = _tcWma(src, half), b = _tcWma(src, L);
      const diff = src.map((_, i) => 2 * a[i] - b[i]);
      return _tcWma(diff, Math.max(1, Math.round(Math.sqrt(L))));
    }
    case 'VWMA': {
      const pv = src.map((s, i) => s * (candles[i].v || 0));
      const vol = candles.map((c) => c.v || 0);
      const num = _tcSma(pv, L), den = _tcSma(vol, L);
      return num.map((x, i) => (isFinite(x) && den[i] > 0 ? x / den[i] : NaN));
    }
    default: return _tcSma(src, L);
  }
}

// ── Trend Checker analytics + Future Trend Checker ───────────────────────────
// CPR type (relationship to the CPR before it), width class, ATR phase and the
// "read" of the two, as the TradingView studies of this kind show them in
// their tables and tags. The ATR phase compares a period's true range (high-low
// widened to the previous period's close) with the average true range of the
// last `len` periods of the same kind.
// Both studies are closed-source: the rules below were measured off them
// (docs/TREND_CHECKER_GP_SPEC.md) and the tests pin the measured values.

// Relationship ids: index into GP_RELATIONS.
const GP_RELATIONS = [
  { key: 'asc',  full: 'Ascending CPR',      short: 'ASC',       sym: '▲', next: 'Ascending',      bias: 'Bullish',      color: '#22AB94', soft: '#A5D6A7' },
  { key: 'desc', full: 'Descending CPR',     short: 'DESC',      sym: '▼', next: 'Descending',     bias: 'Bearish',      color: '#F05454', soft: '#EF9A9A' },
  { key: 'olh',  full: 'Overlapping Higher', short: 'OL Higher', sym: '△', next: 'Overlap Higher', bias: 'Mild Bullish', color: '#66C29A', soft: '#DCEDC8' },
  { key: 'oll',  full: 'Overlapping Lower',  short: 'OL Lower',  sym: '▽', next: 'Overlap Lower',  bias: 'Mild Bearish', color: '#F28C8C', soft: '#FFCDD2' },
  { key: 'out',  full: 'Outside CPR',        short: 'Outside',   sym: '⊙', next: 'Outside',        bias: 'Sideways',     color: '#C462D6', soft: '#E0E0E0' },
  { key: 'in',   full: 'Inside CPR',         short: 'Inside',    sym: '◆', next: 'Inside',         bias: 'Compression (wait for breakout)', color: '#7E8AA8', soft: '#E0E0E0' },
];
const GP_WIDTHS = ['Ultra Narrow', 'Narrow', 'Medium', 'Wide'];
const GP_PHASES = [
  { name: 'Contraction', arrow: '↓', color: '#BBDEFB' },
  { name: 'Normal',      arrow: '•', color: '#FFFFFF' },
  { name: 'Expansion',   arrow: '↑', color: '#FFCC80' },
];
// Read = GP_READS[width class][phase].
const GP_READS = [
  ['Strong Compression', 'Breakout watch',          'Stretched'],
  ['Strong Compression', 'Breakout watch',          'Stretched'],
  ['Compressed',         'Balanced - follow price', 'Stretched'],
  ['Compressed',         'Range day likely',        'Overstretched'],
];
const GP_READ_COLORS = {
  'Strong Compression': '#A5D6A7', 'Breakout watch': '#E0E0E0', 'Stretched': '#FFCC80',
  'Compressed': '#BBDEFB', 'Balanced - follow price': '#E0E0E0', 'Range day likely': '#E0E0E0',
  'Overstretched': '#FFA726',
};
// Width thresholds (% of pivot): Ultra Narrow <=, Narrow <=, Medium <=, per
// group, and the param keys that override them.
const GP_WIDTH_DEFAULTS = { d: [0.05, 0.1, 0.2], w: [0.125, 0.25, 0.5], m: [0.25, 0.5, 1] };

function _gpNum(p, key, def) {
  const v = p ? p[key] : undefined;
  return (typeof v === 'number' && isFinite(v)) ? v : def;
}

// Relationship of a CPR to the one before it ({ bc, tc, pivot } each).
function gpRelation(cur, prev) {
  const top = Math.max(cur.bc, cur.tc), bot = Math.min(cur.bc, cur.tc);
  const pt = Math.max(prev.bc, prev.tc), pb = Math.min(prev.bc, prev.tc);
  if (bot > pt) return 0;
  if (top < pb) return 1;
  if (top > pt && bot < pb) return 4;
  if (top < pt && bot > pb) return 5;
  return cur.pivot >= prev.pivot ? 2 : 3;
}

function gpWidthPct(lv) { return Math.abs(lv.tc - lv.bc) / lv.pivot * 100; }

// 0 Ultra Narrow .. 3 Wide; th = [ultra, narrow, medium] (inclusive limits).
function gpWidthClass(pct, th) {
  if (pct <= th[0]) return 0;
  if (pct <= th[1]) return 1;
  if (pct <= th[2]) return 2;
  return 3;
}

// 0 Contraction, 1 Normal, 2 Expansion.
function gpPhase(ratio, lo, hi) {
  if (!isFinite(ratio)) return 1;
  if (ratio < lo) return 0;
  if (ratio > hi) return 2;
  return 1;
}

// True range of each period: high-low, widened to the previous period's close.
function gpTrueRanges(list) {
  return list.map((q, j) => {
    const r = q.h - q.l;
    if (j === 0) return r;
    const pc = list[j - 1].c;
    return Math.max(r, Math.abs(q.h - pc), Math.abs(q.l - pc));
  });
}

// Average range ending at each index: SMA or Wilder (RMA, SMA-seeded) of the
// last `len` ranges, including the index itself (`include`) or ending one
// before it. NaN until there is enough history.
function gpAvgRanges(ranges, len, wilder, include) {
  const n = ranges.length;
  const L = Math.max(1, len | 0);
  const base = new Array(n).fill(NaN);
  if (wilder) {
    let prev = NaN;
    for (let i = 0; i < n; i++) {
      if (i + 1 < L) continue;
      if (isNaN(prev)) {
        let s = 0;
        for (let k = i - L + 1; k <= i; k++) s += ranges[k];
        prev = s / L;
      } else {
        prev = (prev * (L - 1) + ranges[i]) / L;
      }
      base[i] = prev;
    }
  } else {
    let s = 0;
    for (let i = 0; i < n; i++) {
      s += ranges[i];
      if (i >= L) s -= ranges[i - L];
      if (i + 1 >= L) base[i] = s / L;
    }
  }
  if (include) return base;
  const out = new Array(n).fill(NaN);
  for (let i = 1; i < n; i++) out[i] = base[i - 1];
  return out;
}

// Pine's "#.##": at most two decimals, no trailing zeros, no leading zero
// (".58", "1.1", "2").
function gpFmtRatio(x) {
  if (!isFinite(x)) return '';
  let s = (Math.round(x * 100) / 100).toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
  if (s.startsWith('0.')) s = s.slice(1);
  return s;
}
// "0.###" / "0.##" percentages: up to `dp` decimals, trailing zeros dropped.
function gpFmtPct(x, dp) {
  if (!isFinite(x)) return '';
  return (+x.toFixed(dp)).toString();
}

// Per-period analysis for the d / w / m groups. Entry j describes the CPR
// built from period j (shown during period j+1):
//   lv, widthPct, rel (vs the CPR from period j-1, -1 when unknown),
//   range (period j's true range), avg, ratio (range / avg), phase, streak
//   (consecutive contraction periods ending at j), virgin (the CPR from period
//   j-1 was never traded through during period j — its zone shows in j+1).
function gpAnalyse(dailyBars, params) {
  const p = params || {};
  const per = _tcPeriods(dailyBars);
  const len = _gpNum(p, 'atrLen', 14);
  const wilder = _gpNum(p, 'atrAvg', 0) >= 1;
  const include = _gpNum(p, 'atrInc', 1) >= 1;
  const lo = _gpNum(p, 'atrLo', 0.7), hi = _gpNum(p, 'atrHi', 1.3);
  const out = {};
  for (const g of TC_GROUPS) {
    const list = per[g.id];
    const th = gpThresholds(p, g.id);
    const ranges = gpTrueRanges(list);
    const avg = gpAvgRanges(ranges, len, wilder, include);
    let streak = 0;
    out[g.id] = list.map((q, j) => {
      const ratio = avg[j] > 0 ? ranges[j] / avg[j] : NaN;
      const phase = gpPhase(ratio, lo, hi);
      streak = phase === 0 ? streak + 1 : 0;
      const widthPct = gpWidthPct(q.lv);
      const prevLv = j > 0 ? list[j - 1].lv : null;
      let virgin = false;
      if (prevLv) {
        const top = Math.max(prevLv.bc, prevLv.tc), bot = Math.min(prevLv.bc, prevLv.tc);
        virgin = q.h < bot || q.l > top;
      }
      return {
        idx: q.idx, h: q.h, l: q.l, c: q.c, lv: q.lv,
        widthPct, widthClass: gpWidthClass(widthPct, th),
        rel: prevLv ? gpRelation(q.lv, prevLv) : -1,
        range: ranges[j], avg: avg[j], ratio, phase, streak, virgin,
      };
    });
  }
  return out;
}

function gpThresholds(params, group) {
  const d = GP_WIDTH_DEFAULTS[group];
  return [_gpNum(params, group + 'Un', d[0]), _gpNum(params, group + 'N', d[1]),
    _gpNum(params, group + 'M', d[2])];
}

function gpRead(widthClass, phase) { return GP_READS[widthClass][phase]; }

// Index of the analysis entry whose CPR is shown during the period holding
// `tsSec` (the latest period strictly before it), or -1.
function gpEntryFor(list, group, tsSec) {
  const di = _tcDayIdx(tsSec);
  const key = group === 'd' ? di : group === 'w' ? _tcWeekIdx(di) : _tcMonthIdx(di);
  let j = -1;
  for (let k = 0; k < list.length; k++) { if (list[k].idx < key) j = k; else break; }
  return j;
}

// ── Future Trend Checker ──
// NSE trading holidays the next-CPR date skips (TradingView study's default
// list; weekends are skipped too).
const GP_NSE_HOLIDAYS = [
  '2026-01-15', '2026-01-26', '2026-03-03', '2026-03-26', '2026-03-31', '2026-04-03',
  '2026-04-14', '2026-05-01', '2026-05-28', '2026-06-26', '2026-09-14', '2026-10-02',
  '2026-10-20', '2026-11-10', '2026-11-24', '2026-12-25',
];
const GP_ZONE_DEFAULTS = { d: [0.3, 0.5], w: [0.7, 1], m: [2, 3] };
const GP_GAP_DEFAULTS = { d: [0.1, 0.3], w: [0.25, 0.5], m: [0.5, 1] };
const GP_BAND_NAMES = ['Narrow', 'Normal', 'Wide'];
// Bars the next period's CPR spans right of the newest candle.
const _FT_SPAN = 16;

function _gpYmd(dayIdx) { return new Date(dayIdx * 86400000).toISOString().slice(0, 10); }
function gpIsTradingDay(dayIdx) {
  const wd = new Date(dayIdx * 86400000).getUTCDay();
  return wd !== 0 && wd !== 6 && GP_NSE_HOLIDAYS.indexOf(_gpYmd(dayIdx)) < 0;
}
// First trading day of the period after the one holding `dayIdx`.
function gpNextTradingDay(group, dayIdx) {
  let d = dayIdx + 1;
  if (group === 'w') { while (_tcWeekIdx(d) === _tcWeekIdx(dayIdx)) d++; }
  if (group === 'm') { while (_tcMonthIdx(d) === _tcMonthIdx(dayIdx)) d++; }
  for (let k = 0; k < 40 && !gpIsTradingDay(d); k++) d++;
  return d;
}
function gpFmtDay(dayIdx) {
  const d = new Date(dayIdx * 86400000);
  return d.getUTCDate() + ' ' + ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
    'Oct', 'Nov', 'Dec'][d.getUTCMonth()];
}

function _gpBand(pct, lim) { return pct <= lim[0] ? 0 : pct <= lim[1] ? 1 : 2; }

// Next-period CPR for one group from the CURRENT period's high / low / close.
// `cur` = { h, l, c, dayIdx }: the live period (today / this week / this
// month so far); `list` = gpAnalyse(...)[group] (its last entries give the
// current CPR and the range history). Returns null without enough data.
function gpFuture(group, list, cur, params) {
  if (!cur || !isFinite(cur.h) || !isFinite(cur.l) || !isFinite(cur.c)) return null;
  const p = params || {};
  const lv = tcLevels(cur.h, cur.l, cur.c);
  const di = cur.dayIdx;
  const key = group === 'd' ? di : group === 'w' ? _tcWeekIdx(di) : _tcMonthIdx(di);
  // History strictly before the current period, then the current one.
  const hist = list.filter((q) => q.idx < key);
  const nowCpr = hist.length ? hist[hist.length - 1].lv : null;
  const ranges = gpTrueRanges(hist.concat([{ h: cur.h, l: cur.l, c: cur.c }]));
  const avg = gpAvgRanges(ranges, _gpNum(p, 'atrLen', 14), _gpNum(p, 'atrAvg', 0) >= 1,
      _gpNum(p, 'atrInc', 1) >= 1);
  const a = avg[avg.length - 1];
  const ratio = a > 0 ? ranges[ranges.length - 1] / a : NaN;
  const P = lv.pivot;
  const top = Math.max(lv.bc, lv.tc), bot = Math.min(lv.bc, lv.tc);
  const widthPct = gpWidthPct(lv);
  const zone = [_gpNum(p, group + 'Zn', GP_ZONE_DEFAULTS[group][0]),
    _gpNum(p, group + 'Zm', GP_ZONE_DEFAULTS[group][1])];
  const gap = [_gpNum(p, group + 'Gn', GP_GAP_DEFAULTS[group][0]),
    _gpNum(p, group + 'Gm', GP_GAP_DEFAULTS[group][1])];
  const upPct = (Math.max(lv.r1, lv.high) - top) / P * 100;
  const dnPct = (bot - Math.min(lv.s1, lv.low)) / P * 100;
  const r1Gap = Math.abs(lv.r1 - lv.high) / P * 100;
  const s1Gap = Math.abs(lv.s1 - lv.low) / P * 100;
  return {
    lv, widthPct, widthClass: gpWidthClass(widthPct, gpThresholds(p, group)),
    upPct, upBand: _gpBand(upPct, zone), dnPct, dnBand: _gpBand(dnPct, zone),
    r1Gap, r1Band: _gpBand(r1Gap, gap), s1Gap, s1Band: _gpBand(s1Gap, gap),
    rel: nowCpr ? gpRelation(lv, nowCpr) : -1,
    ratio, phase: gpPhase(ratio, _gpNum(p, 'atrLo', 0.7), _gpNum(p, 'atrHi', 1.3)),
    nextDay: gpNextTradingDay(group, di),
  };
}

// Dual-mode export — browser global (script tag) AND node require() for tests.
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    _windowSecondsFor, _newRequestId, _hexToRgba,
    _bandRect, _bboxRect, _lineRectParams, _roundRectPath, _lerpPt,
    _barSec, _nearestIndex, _wilderATR,
    _FIB_RETR, _FIB_EXT, _FIB_TIME, _FIB_COLORS, _SMART_RED, _SMART_GREEN,
    _drawArrowHead, _drawNodeLabel, _drawText, _renderPolyPattern,
    _positionExpand, _positionRender, _forkAnchors, _drawForkInChart, _forkPartial,
    _istParts, _istDayKey, _nthSundayOfMonth, _usInDst,
    _sessionBoundsFor, _isSessionWindowPure,
    CPR_PLOTS, CPR_PLOT_TYPES, CPR_LINE_STYLES, cprLevels, computeCprSeries,
    cprPlotStyle, cprDecimals,
    TC_GROUPS, TC_LINES, TC_BANDS, TC_MA_TYPES, TC_MA_SOURCES, TC_MA_DEFAULTS,
    tcLevels, computeTcSeries, tcActiveGroups, tcLineStyle, tcBandStyle, tcMaConfig, tcMa,
    GP_RELATIONS, GP_WIDTHS, GP_PHASES, GP_READS, GP_READ_COLORS, GP_WIDTH_DEFAULTS,
    GP_NSE_HOLIDAYS, GP_ZONE_DEFAULTS, GP_GAP_DEFAULTS, GP_BAND_NAMES,
    gpRelation, gpWidthPct, gpWidthClass, gpPhase, gpTrueRanges, gpAvgRanges, gpFmtRatio, gpFmtPct,
    gpAnalyse, gpThresholds, gpRead, gpEntryFor, gpIsTradingDay, gpNextTradingDay, gpFmtDay, gpFuture,
  };
}
