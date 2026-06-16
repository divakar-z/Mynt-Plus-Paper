'use strict';

// ---------------------------------------------------------------------------
// Chart — one instance per pane. Owns a <canvas> in the given container,
// fetches its own history via the parent (which has API auth), aggregates
// live ticks routed in by chart-engine.js, draws the result.
//
// Phase 1 ships with stub method bodies for everything except boot. The
// remaining groups fill them in. This skeleton MUST stay constructable
// without errors so the handshake (chart-engine-ready) works even before
// data fetching exists.
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

// ---------------------------------------------------------------------------
// Drawing-tool registry (Phase 28).
//
// Historically every drawing tool was a hand-written `if (d.kind === 'x')`
// branch inside renderOne + the placement handler + the hit-test. That does
// not scale to the 60+ tools we are porting from the CandL library, so new
// tools are declared here as data: each entry owns its click-count and a pure
// `render(g, d)` that draws onto the canvas and returns the geometry the
// common code needs (`endX`/`endY` for the floating toolbar anchor, `dragRect`
// for the translate hit-band). The existing built-in kinds (hline, trendline,
// rect, fib, measure, path, hray) are still rendered by their original
// branches and will be migrated into this table in a later stage; until then
// renderOne consults this registry FIRST and falls back to the branches.
//
// The `g` (geometry) helper bag handed to every render fn:
//   g.ctx        — canvas 2D context (already saved/restored by the caller)
//   g.plot       — { left, top, right, bottom, width }
//   g.color      — resolved stroke colour
//   g.strokeW    — resolved stroke width (selection-aware)
//   g.isSelected, g.isInProgress
//   g.drawLine(ax,ay,bx,by) — white-halo + coloured stroke line helper
//   g.tsToX(ts)  — bar timestamp (sec) → x
//   g.priceToY(p)— price → y
//   g.hover      — { inside, x, y } live cursor (for in-progress previews)
//   g.lineParams(px,py,dx,dy) — Liang–Barsky param range [t0,t1] clipping the
//                  infinite line through (px,py)+t·(dx,dy) to the plot rect,
//                  or null when the line misses the rect entirely.
const DRAWING_TOOLS = {
  // ── Migrated built-ins (Phase 28 Stage 2) ───────────────────────────────────
  // These replace the original hand-written renderOne branches; behaviour is
  // identical, now expressed as registry entries.

  // Horizontal line — one click, full width at the price.
  hline: {
    clicks: 1,
    render(g, d) {
      const p = d.points[0];
      if (!p) return null;
      const y = g.priceToY(p.price);
      g.drawLine(g.plot.left, y, g.plot.right, y);
      return {
        endX: g.plot.right, endY: y,
        dragRect: g.isInProgress ? null
            : { x: g.plot.left, y: y - 4, w: g.plot.right - g.plot.left, h: 8 },
      };
    },
  },

  // Horizontal ray — one click, from the anchor's x to the right edge.
  hray: {
    clicks: 1,
    render(g, d) {
      const p = d.points[0];
      if (!p) return null;
      const y = g.priceToY(p.price);
      const xs = Math.max(g.plot.left, g.tsToX(p.ts));
      g.drawLine(xs, y, g.plot.right, y);
      return {
        endX: g.plot.right, endY: y,
        dragRect: g.isInProgress ? null
            : { x: xs, y: y - 4, w: g.plot.right - xs, h: 8 },
      };
    },
  },

  // Trendline — two clicks.
  trendline: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts), y1 = g.priceToY(p1.price);
      let x2, y2;
      const p2 = d.points[1];
      if (p2) { x2 = g.tsToX(p2.ts); y2 = g.priceToY(p2.price); }
      else if (g.hover.inside && g.hover.x != null) { x2 = g.hover.x; y2 = g.hover.y; }
      else return null;
      g.drawLine(x1, y1, x2, y2);
      return {
        endX: x2, endY: y2,
        dragRect: g.isInProgress ? null : _bandRect(x1, y1, x2, y2),
      };
    },
  },

  // Rectangle — two clicks; in-progress tracks the cursor in pixel space.
  rect: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts), y1 = g.priceToY(p1.price);
      let x2, y2;
      const p2 = d.points[1];
      if (p2) {
        if (g.isInProgress && g.hover.inside && g.hover.x != null) { x2 = g.hover.x; y2 = g.hover.y; }
        else { x2 = g.tsToX(p2.ts); y2 = g.priceToY(p2.price); }
      } else if (g.hover.inside && g.hover.x != null) { x2 = g.hover.x; y2 = g.hover.y; }
      else return null;
      if (![x1, y1, x2, y2].every(Number.isFinite)) return null;
      const rx = Math.min(x1, x2), ry = Math.min(y1, y2);
      const rw = Math.abs(x2 - x1), rh = Math.abs(y2 - y1);
      const ctx = g.ctx;
      ctx.strokeStyle = 'rgba(255,255,255,0.85)'; ctx.lineWidth = 4;
      ctx.strokeRect(rx, ry, rw, rh);
      ctx.strokeStyle = g.color; ctx.lineWidth = g.isSelected ? 2.5 : 2;
      ctx.strokeRect(rx, ry, rw, rh);
      return {
        endX: Math.max(x1, x2), endY: (y1 + y2) / 2,
        dragRect: g.isInProgress ? null : { x: rx, y: ry, w: rw, h: rh },
      };
    },
  },

  // Fibonacci retracement — two clicks; 7 ratio lines across the x range.
  fib: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts);
      let x2, p2Price;
      const p2 = d.points[1];
      if (p2) { x2 = g.tsToX(p2.ts); p2Price = p2.price; }
      else if (g.hover.inside && g.hover.x != null) { x2 = g.hover.x; p2Price = g.yToPrice(g.hover.y) ?? p1.price; }
      else return null;
      const xL = Math.min(x1, x2), xR = Math.max(x1, x2);
      const hi = Math.max(p1.price, p2Price), lo = Math.min(p1.price, p2Price);
      const range = hi - lo;
      if (range <= 0) return null;
      const ratios = [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0];
      const labels = ['0%', '23.6%', '38.2%', '50%', '61.8%', '78.6%', '100%'];
      const cs = ['#94A3B8', '#0EA5E9', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#94A3B8'];
      const ctx = g.ctx;
      ctx.save();
      ctx.font = '500 10px Geist, sans-serif';
      ctx.textBaseline = 'middle';
      ctx.textAlign = 'left';
      for (let i = 0; i < ratios.length; i++) {
        const fp = hi - range * ratios[i];
        const y = g.priceToY(fp);
        ctx.strokeStyle = cs[i];
        ctx.lineWidth = g.isSelected ? 1.5 : 1;
        ctx.setLineDash(i === 0 || i === ratios.length - 1 ? [] : [4, 4]);
        ctx.beginPath(); ctx.moveTo(xL, y); ctx.lineTo(xR, y); ctx.stroke();
        ctx.setLineDash([]);
        ctx.fillStyle = cs[i];
        ctx.fillText(labels[i] + '  ' + fp.toFixed(2), xL + 4, y - 6);
      }
      ctx.restore();
      return {
        endX: xR, endY: g.priceToY((hi + lo) / 2),
        dragRect: g.isInProgress ? null
            : { x: xL, y: g.priceToY(hi) - 4, w: xR - xL, h: g.priceToY(lo) - g.priceToY(hi) + 8 },
      };
    },
  },

  // Vertical line — one click, spans the full plot height at the bar's x.
  vline: {
    clicks: 1,
    render(g, d) {
      const p = d.points[0];
      if (!p) return null;
      const x = g.tsToX(p.ts);
      if (!Number.isFinite(x)) return null;
      g.drawLine(x, g.plot.top, x, g.plot.bottom);
      return {
        endX: x,
        endY: (g.plot.top + g.plot.bottom) / 2,
        dragRect: g.isInProgress ? null
            : { x: x - 4, y: g.plot.top, w: 8, h: g.plot.bottom - g.plot.top },
      };
    },
  },

  // Ray — two clicks; starts at p1, runs through p2 and extends to the plot
  // edge in that direction only.
  ray: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts);
      const y1 = g.priceToY(p1.price);
      let x2, y2;
      const p2 = d.points[1];
      if (p2) { x2 = g.tsToX(p2.ts); y2 = g.priceToY(p2.price); }
      else if (g.hover.inside && g.hover.x != null) { x2 = g.hover.x; y2 = g.hover.y; }
      else return null;
      const dx = x2 - x1, dy = y2 - y1;
      const range = g.lineParams(x1, y1, dx, dy);
      // Forward from p1 (t≥0) to the far edge; fall back to the raw segment.
      let ex = x2, ey = y2;
      if (range) {
        const tEnd = Math.max(range[0], range[1]);
        if (tEnd > 0) { ex = x1 + dx * tEnd; ey = y1 + dy * tEnd; }
      }
      g.drawLine(x1, y1, ex, ey);
      return {
        endX: ex, endY: ey,
        dragRect: g.isInProgress ? null : _bandRect(x1, y1, ex, ey),
      };
    },
  },

  // Extended line ("xline") — two clicks; the infinite line through both
  // anchors, clipped to the plot on both sides.
  xline: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts);
      const y1 = g.priceToY(p1.price);
      let x2, y2;
      const p2 = d.points[1];
      if (p2) { x2 = g.tsToX(p2.ts); y2 = g.priceToY(p2.price); }
      else if (g.hover.inside && g.hover.x != null) { x2 = g.hover.x; y2 = g.hover.y; }
      else return null;
      const dx = x2 - x1, dy = y2 - y1;
      const range = g.lineParams(x1, y1, dx, dy);
      let ax = x1, ay = y1, bx = x2, by = y2;
      if (range) {
        ax = x1 + dx * range[0]; ay = y1 + dy * range[0];
        bx = x1 + dx * range[1]; by = y1 + dy * range[1];
      }
      g.drawLine(ax, ay, bx, by);
      return {
        endX: Math.max(ax, bx), endY: (ay + by) / 2,
        dragRect: g.isInProgress ? null : _bandRect(ax, ay, bx, by),
      };
    },
  },

  // ── Shapes ───────────────────────────────────────────────────────────────

  // Arrow — two clicks; a line with a filled arrowhead at the second anchor.
  arrow: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts), y1 = g.priceToY(p1.price);
      let x2, y2;
      const p2 = d.points[1];
      if (p2) { x2 = g.tsToX(p2.ts); y2 = g.priceToY(p2.price); }
      else if (g.hover.inside && g.hover.x != null) { x2 = g.hover.x; y2 = g.hover.y; }
      else return null;
      g.drawLine(x1, y1, x2, y2);
      _drawArrowHead(g.ctx, x1, y1, x2, y2, g.color, 11);
      return {
        endX: Math.max(x1, x2), endY: (y1 + y2) / 2,
        dragRect: g.isInProgress ? null : _bandRect(x1, y1, x2, y2),
      };
    },
  },

  // Triangle — three clicks; filled closed polygon.
  triangle: {
    clicks: 3,
    render(g, d) {
      const pts = d.points;
      if (!pts || pts.length === 0) return null;
      const scr = pts.map((p) => ({ x: g.tsToX(p.ts), y: g.priceToY(p.price) }));
      if (g.isInProgress && scr.length < 3 && g.hover.inside && g.hover.x != null) {
        scr.push({ x: g.hover.x, y: g.hover.y });
      }
      if (scr.length < 2) return { endX: scr[0].x, endY: scr[0].y, dragRect: null };
      const ctx = g.ctx;
      if (scr.length >= 3) {
        ctx.save();
        ctx.fillStyle = _hexToRgba(g.color, 0.10);
        ctx.beginPath();
        ctx.moveTo(scr[0].x, scr[0].y);
        ctx.lineTo(scr[1].x, scr[1].y);
        ctx.lineTo(scr[2].x, scr[2].y);
        ctx.closePath();
        ctx.fill();
        ctx.restore();
      }
      for (let i = 0; i < scr.length - 1; i++) {
        g.drawLine(scr[i].x, scr[i].y, scr[i + 1].x, scr[i + 1].y);
      }
      if (scr.length >= 3) g.drawLine(scr[2].x, scr[2].y, scr[0].x, scr[0].y);
      const xs = scr.map((s) => s.x), ys = scr.map((s) => s.y);
      return {
        endX: Math.max(...xs), endY: Math.min(...ys),
        dragRect: g.isInProgress ? null : _bboxRect(xs, ys),
      };
    },
  },

  // Circle — two clicks; centre at p1, radius = pixel distance to p2.
  circle: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const cx = g.tsToX(p1.ts), cy = g.priceToY(p1.price);
      let ex, ey;
      const p2 = d.points[1];
      if (p2) { ex = g.tsToX(p2.ts); ey = g.priceToY(p2.price); }
      else if (g.hover.inside && g.hover.x != null) { ex = g.hover.x; ey = g.hover.y; }
      else return null;
      const r = Math.hypot(ex - cx, ey - cy);
      if (!Number.isFinite(r) || r <= 0) return { endX: cx, endY: cy, dragRect: null };
      const ctx = g.ctx;
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, 0.08);
      ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,0.85)'; ctx.lineWidth = 4;
      ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
      ctx.strokeStyle = g.color; ctx.lineWidth = g.strokeW;
      ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
      ctx.restore();
      return {
        endX: cx + r, endY: cy,
        dragRect: g.isInProgress ? null : { x: cx - r, y: cy - r, w: 2 * r, h: 2 * r },
      };
    },
  },

  // Arc — two clicks; upper half-ellipse spanning the anchors' bounding box.
  arc: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts), y1 = g.priceToY(p1.price);
      let x2, y2;
      const p2 = d.points[1];
      if (p2) { x2 = g.tsToX(p2.ts); y2 = g.priceToY(p2.price); }
      else if (g.hover.inside && g.hover.x != null) { x2 = g.hover.x; y2 = g.hover.y; }
      else return null;
      const cx = (x1 + x2) / 2, cy = (y1 + y2) / 2;
      const rx = Math.abs(x2 - x1) / 2, ry = Math.abs(y2 - y1) / 2;
      if (rx <= 0 || ry <= 0) { g.drawLine(x1, y1, x2, y2); return { endX: Math.max(x1, x2), endY: cy, dragRect: null }; }
      const ctx = g.ctx;
      const stroke = (w, c) => {
        ctx.strokeStyle = c; ctx.lineWidth = w;
        ctx.beginPath(); ctx.ellipse(cx, cy, rx, ry, 0, Math.PI, 2 * Math.PI); ctx.stroke();
      };
      stroke(4, 'rgba(255,255,255,0.85)');
      stroke(g.strokeW, g.color);
      return {
        endX: Math.max(x1, x2), endY: cy - ry,
        dragRect: g.isInProgress ? null : { x: cx - rx, y: cy - ry - 4, w: 2 * rx, h: ry + 8 },
      };
    },
  },

  // Curve — three clicks; quadratic Bézier (start, control, end).
  curve: {
    clicks: 3,
    render(g, d) {
      const pts = d.points;
      if (!pts || pts.length === 0) return null;
      const scr = pts.map((p) => ({ x: g.tsToX(p.ts), y: g.priceToY(p.price) }));
      if (g.isInProgress && scr.length < 3 && g.hover.inside && g.hover.x != null) {
        scr.push({ x: g.hover.x, y: g.hover.y });
      }
      if (scr.length < 2) return { endX: scr[0].x, endY: scr[0].y, dragRect: null };
      const ctx = g.ctx;
      const drawQ = (w, c) => {
        ctx.strokeStyle = c; ctx.lineWidth = w; ctx.lineCap = 'round';
        ctx.beginPath(); ctx.moveTo(scr[0].x, scr[0].y);
        if (scr.length >= 3) ctx.quadraticCurveTo(scr[1].x, scr[1].y, scr[2].x, scr[2].y);
        else ctx.lineTo(scr[1].x, scr[1].y);
        ctx.stroke();
      };
      drawQ(4, 'rgba(255,255,255,0.85)');
      drawQ(g.strokeW, g.color);
      const xs = scr.map((s) => s.x), ys = scr.map((s) => s.y);
      return {
        endX: Math.max(...xs), endY: scr[scr.length - 1].y,
        dragRect: g.isInProgress ? null : _bboxRect(xs, ys),
      };
    },
  },

  // Rotated rectangle — three clicks; p1→p2 is one edge, p3 sets the
  // perpendicular extent (and thus the opposite edge).
  rotrect: {
    clicks: 3,
    render(g, d) {
      const pts = d.points;
      if (!pts || pts.length < 1) return null;
      const a = { x: g.tsToX(pts[0].ts), y: g.priceToY(pts[0].price) };
      let b;
      if (pts.length >= 2) b = { x: g.tsToX(pts[1].ts), y: g.priceToY(pts[1].price) };
      else if (g.hover.inside && g.hover.x != null) b = { x: g.hover.x, y: g.hover.y };
      else return { endX: a.x, endY: a.y, dragRect: null };
      let third = null;
      if (pts.length >= 3) third = { x: g.tsToX(pts[2].ts), y: g.priceToY(pts[2].price) };
      else if (pts.length === 2 && g.hover.inside && g.hover.x != null) third = { x: g.hover.x, y: g.hover.y };
      if (!third) {
        g.drawLine(a.x, a.y, b.x, b.y);
        return { endX: Math.max(a.x, b.x), endY: (a.y + b.y) / 2, dragRect: null };
      }
      const vx = b.x - a.x, vy = b.y - a.y, len = Math.hypot(vx, vy) || 1;
      const nx = -vy / len, ny = vx / len;
      const off = (third.x - b.x) * nx + (third.y - b.y) * ny;
      const corners = [
        a, b,
        { x: b.x + nx * off, y: b.y + ny * off },
        { x: a.x + nx * off, y: a.y + ny * off },
      ];
      const ctx = g.ctx;
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, 0.08);
      ctx.beginPath(); ctx.moveTo(corners[0].x, corners[0].y);
      for (let i = 1; i < 4; i++) ctx.lineTo(corners[i].x, corners[i].y);
      ctx.closePath(); ctx.fill();
      ctx.restore();
      for (let i = 0; i < 4; i++) {
        g.drawLine(corners[i].x, corners[i].y, corners[(i + 1) % 4].x, corners[(i + 1) % 4].y);
      }
      const xs = corners.map((p) => p.x), ys = corners.map((p) => p.y);
      return {
        endX: Math.max(...xs), endY: Math.min(...ys),
        dragRect: g.isInProgress ? null : _bboxRect(xs, ys),
      };
    },
  },

  // ── Channels ─────────────────────────────────────────────────────────────

  // Parallel channel — p1→p2 is the base line, p3 sets the parallel offset;
  // the band between the two lines is lightly filled.
  channel: {
    clicks: 3,
    render(g, d) {
      const pts = d.points;
      if (!pts || pts.length < 1) return null;
      const a = { x: g.tsToX(pts[0].ts), y: g.priceToY(pts[0].price) };
      let b;
      if (pts.length >= 2) b = { x: g.tsToX(pts[1].ts), y: g.priceToY(pts[1].price) };
      else if (g.hover.inside && g.hover.x != null) b = { x: g.hover.x, y: g.hover.y };
      else return { endX: a.x, endY: a.y, dragRect: null };
      let third = null;
      if (pts.length >= 3) third = { x: g.tsToX(pts[2].ts), y: g.priceToY(pts[2].price) };
      else if (pts.length === 2 && g.hover.inside && g.hover.x != null) third = { x: g.hover.x, y: g.hover.y };
      if (!third) {
        g.drawLine(a.x, a.y, b.x, b.y);
        return {
          endX: Math.max(a.x, b.x), endY: (a.y + b.y) / 2,
          dragRect: g.isInProgress ? null : _bandRect(a.x, a.y, b.x, b.y),
        };
      }
      const vx = b.x - a.x, vy = b.y - a.y, len = Math.hypot(vx, vy) || 1;
      const nx = -vy / len, ny = vx / len;
      const off = (third.x - a.x) * nx + (third.y - a.y) * ny;
      const a2 = { x: a.x + nx * off, y: a.y + ny * off };
      const b2 = { x: b.x + nx * off, y: b.y + ny * off };
      const ctx = g.ctx;
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, 0.07);
      ctx.beginPath();
      ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y);
      ctx.lineTo(b2.x, b2.y); ctx.lineTo(a2.x, a2.y);
      ctx.closePath(); ctx.fill();
      ctx.restore();
      g.drawLine(a.x, a.y, b.x, b.y);
      g.drawLine(a2.x, a2.y, b2.x, b2.y);
      const xs = [a.x, b.x, a2.x, b2.x], ys = [a.y, b.y, a2.y, b2.y];
      return {
        endX: Math.max(...xs), endY: Math.min(...ys),
        dragRect: g.isInProgress ? null : _bboxRect(xs, ys),
      };
    },
  },

  // Linear regression channel — two clicks pick a time range; a least-squares
  // fit over the candles inside that range is drawn with ±2σ bands. Data-aware
  // (re-fits from candle closes, so it ignores vertical drags).
  regression: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      let t2;
      const p2 = d.points[1];
      if (p2) t2 = p2.ts;
      else if (g.hover.inside && g.hover.x != null) t2 = g.xToTs(g.hover.x);
      else return null;
      const lo = Math.min(p1.ts, t2), hi = Math.max(p1.ts, t2);
      const cs = (g.candles || []).filter((c) => c.ts >= lo && c.ts <= hi);
      if (cs.length < 2) {
        const xa = g.tsToX(p1.ts), xb = g.tsToX(t2), y = g.priceToY(p1.price);
        g.drawLine(xa, y, xb, y);
        return { endX: Math.max(xa, xb), endY: y, dragRect: null };
      }
      const n = cs.length;
      let sx = 0, sy = 0, sxx = 0, sxy = 0;
      for (let i = 0; i < n; i++) { const y = cs[i].c; sx += i; sy += y; sxx += i * i; sxy += i * y; }
      const denom = (n * sxx - sx * sx) || 1;
      const slope = (n * sxy - sx * sy) / denom;
      const intercept = (sy - slope * sx) / n;
      let ss = 0;
      for (let i = 0; i < n; i++) { const r = cs[i].c - (intercept + slope * i); ss += r * r; }
      const sd = Math.sqrt(ss / n);
      const k = 2;
      const fit0 = intercept, fitN = intercept + slope * (n - 1);
      const x0 = g.tsToX(cs[0].ts), xN = g.tsToX(cs[n - 1].ts);
      const y0 = g.priceToY(fit0), yN = g.priceToY(fitN);
      const yt0 = g.priceToY(fit0 + k * sd), ytN = g.priceToY(fitN + k * sd);
      const yb0 = g.priceToY(fit0 - k * sd), ybN = g.priceToY(fitN - k * sd);
      const ctx = g.ctx;
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, 0.06);
      ctx.beginPath();
      ctx.moveTo(x0, yt0); ctx.lineTo(xN, ytN);
      ctx.lineTo(xN, ybN); ctx.lineTo(x0, yb0);
      ctx.closePath(); ctx.fill();
      ctx.restore();
      g.drawLine(x0, y0, xN, yN);
      ctx.save();
      ctx.setLineDash([4, 4]); ctx.strokeStyle = g.color; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(x0, yt0); ctx.lineTo(xN, ytN); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(x0, yb0); ctx.lineTo(xN, ybN); ctx.stroke();
      ctx.restore();
      return {
        endX: Math.max(x0, xN), endY: (y0 + yN) / 2,
        dragRect: g.isInProgress ? null
            : { x: Math.min(x0, xN), y: Math.min(yt0, ytN) - 4,
                w: Math.abs(xN - x0), h: Math.abs(ybN - yt0) + 8 },
      };
    },
  },

  // Andrews' Pitchfork — three clicks: handle (p1) + two prongs (p2, p3). The
  // median runs from p1 through the midpoint of p2–p3; parallel tines pass
  // through p2 and p3. All three rays extend to the plot edge.
  pitchfork: {
    clicks: 3,
    render(g, d) {
      const pts = d.points;
      if (!pts || pts.length < 1) return null;
      const P = (p) => ({ x: g.tsToX(p.ts), y: g.priceToY(p.price) });
      const a = P(pts[0]);
      let b;
      if (pts.length >= 2) b = P(pts[1]);
      else if (g.hover.inside && g.hover.x != null) b = { x: g.hover.x, y: g.hover.y };
      else return { endX: a.x, endY: a.y, dragRect: null };
      let c;
      if (pts.length >= 3) c = P(pts[2]);
      else if (pts.length === 2 && g.hover.inside && g.hover.x != null) c = { x: g.hover.x, y: g.hover.y };
      else { g.drawLine(a.x, a.y, b.x, b.y); return { endX: Math.max(a.x, b.x), endY: (a.y + b.y) / 2, dragRect: null }; }
      const mid = { x: (b.x + c.x) / 2, y: (b.y + c.y) / 2 };
      const dx = mid.x - a.x, dy = mid.y - a.y;
      const extend = (px, py) => {
        const range = g.lineParams(px, py, dx, dy);
        if (!range) return { x: px, y: py };
        const t = Math.max(range[0], range[1]);
        return { x: px + dx * t, y: py + dy * t };
      };
      const medEnd = extend(a.x, a.y);
      g.drawLine(a.x, a.y, medEnd.x, medEnd.y);
      g.drawLine(b.x, b.y, c.x, c.y);
      const eb = extend(b.x, b.y), ec = extend(c.x, c.y);
      g.drawLine(b.x, b.y, eb.x, eb.y);
      g.drawLine(c.x, c.y, ec.x, ec.y);
      const xs = [a.x, b.x, c.x, medEnd.x, eb.x, ec.x];
      const ys = [a.y, b.y, c.y, medEnd.y, eb.y, ec.y];
      return {
        endX: Math.max(...xs), endY: medEnd.y,
        dragRect: g.isInProgress ? null : _bboxRect(xs, ys),
      };
    },
  },

  // ── Lines (extra) ──────────────────────────────────────────────────────────

  // Crosshair line — one click; full-width horizontal + full-height vertical.
  crossline: {
    clicks: 1,
    render(g, d) {
      const p = d.points[0];
      if (!p) return null;
      const x = g.tsToX(p.ts), y = g.priceToY(p.price);
      if (!Number.isFinite(x) || !Number.isFinite(y)) return null;
      g.drawLine(g.plot.left, y, g.plot.right, y);
      g.drawLine(x, g.plot.top, x, g.plot.bottom);
      return {
        endX: x, endY: y,
        dragRect: g.isInProgress ? null
            : { x: x - 4, y: g.plot.top, w: 8, h: g.plot.bottom - g.plot.top },
      };
    },
  },

  // Info line — a trendline annotated with Δprice / % / bars / angle.
  infoline: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts), y1 = g.priceToY(p1.price);
      const p2 = d.points[1];
      let x2, y2, price2, ts2;
      if (p2) { x2 = g.tsToX(p2.ts); y2 = g.priceToY(p2.price); price2 = p2.price; ts2 = p2.ts; }
      else if (g.hover.inside && g.hover.x != null) {
        x2 = g.hover.x; y2 = g.hover.y; price2 = g.yToPrice(y2); ts2 = g.xToTs(x2);
      } else return null;
      g.drawLine(x1, y1, x2, y2);
      const dP = price2 - p1.price;
      const pct = p1.price !== 0 ? (dP / p1.price) * 100 : 0;
      const barMs = (g.candles && g.candles.length > 1)
          ? (g.candles[1].ts - g.candles[0].ts) || 1 : 1;
      const bars = Math.round((ts2 - p1.ts) / barMs);
      const ang = Math.atan2(-(y2 - y1), (x2 - x1)) * 180 / Math.PI;
      const txt = (dP >= 0 ? '+' : '') + dP.toFixed(2) + ' (' + pct.toFixed(2) + '%)  '
          + bars + 'b  ' + ang.toFixed(0) + '°';
      _drawNodeLabel(g.ctx, (x1 + x2) / 2, (y1 + y2) / 2, txt, g.color, true);
      return {
        endX: Math.max(x1, x2), endY: (y1 + y2) / 2,
        dragRect: g.isInProgress ? null : _bandRect(x1, y1, x2, y2),
      };
    },
  },

  // Trend angle — a trendline with its slope angle called out.
  trendangle: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts), y1 = g.priceToY(p1.price);
      const p2 = d.points[1];
      let x2, y2;
      if (p2) { x2 = g.tsToX(p2.ts); y2 = g.priceToY(p2.price); }
      else if (g.hover.inside && g.hover.x != null) { x2 = g.hover.x; y2 = g.hover.y; }
      else return null;
      g.drawLine(x1, y1, x2, y2);
      // Reference horizontal + small arc at the origin.
      const ctx = g.ctx;
      ctx.save();
      ctx.setLineDash([3, 3]);
      ctx.strokeStyle = _hexToRgba(g.color, 0.6);
      ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x1 + 40, y1); ctx.stroke();
      const ang = Math.atan2(-(y2 - y1), (x2 - x1));
      ctx.setLineDash([]);
      ctx.beginPath(); ctx.arc(x1, y1, 22, 0, -ang, ang > 0); ctx.stroke();
      ctx.restore();
      _drawNodeLabel(g.ctx, x1 + 30, y1 - 16,
          (ang * 180 / Math.PI).toFixed(1) + '°', g.color, true);
      return {
        endX: Math.max(x1, x2), endY: (y1 + y2) / 2,
        dragRect: g.isInProgress ? null : _bandRect(x1, y1, x2, y2),
      };
    },
  },

  // ── Channels / forks (extra) ────────────────────────────────────────────────

  // Flat channel — two horizontal lines at the anchor prices, full width.
  channelflat: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const y1 = g.priceToY(p1.price);
      let y2;
      const p2 = d.points[1];
      if (p2) y2 = g.priceToY(p2.price);
      else if (g.hover.inside && g.hover.y != null) y2 = g.hover.y;
      else return null;
      const ctx = g.ctx;
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, 0.07);
      ctx.fillRect(g.plot.left, Math.min(y1, y2), g.plot.right - g.plot.left, Math.abs(y2 - y1));
      ctx.restore();
      g.drawLine(g.plot.left, y1, g.plot.right, y1);
      g.drawLine(g.plot.left, y2, g.plot.right, y2);
      return {
        endX: g.plot.right, endY: (y1 + y2) / 2,
        dragRect: g.isInProgress ? null
            : { x: g.plot.left, y: Math.min(y1, y2) - 4,
                w: g.plot.right - g.plot.left, h: Math.abs(y2 - y1) + 8 },
      };
    },
  },

  // ── Gann ─────────────────────────────────────────────────────────────────

  // Gann fan — fan of geometric-angle rays (1×1, 1×2, 2×1 …) from p1; p2 sets
  // the 1×1 unit box.
  gannfan: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts), y1 = g.priceToY(p1.price);
      let x2, y2;
      const p2 = d.points[1];
      if (p2) { x2 = g.tsToX(p2.ts); y2 = g.priceToY(p2.price); }
      else if (g.hover.inside && g.hover.x != null) { x2 = g.hover.x; y2 = g.hover.y; }
      else return null;
      const ux = x2 - x1, uy = y2 - y1; // 1×1 unit vector (signed)
      const ratios = [1 / 8, 1 / 4, 1 / 3, 1 / 2, 1, 2, 3, 4, 8];
      for (const r of ratios) {
        // price/time ratio r: dx = ux, dy = uy * r  (steeper as r grows)
        const dx = ux, dy = uy * r;
        const range = g.lineParams(x1, y1, dx, dy);
        if (!range) continue;
        const t = Math.max(range[0], range[1]);
        if (t <= 0) continue;
        const ex = x1 + dx * t, ey = y1 + dy * t;
        const main = Math.abs(r - 1) < 1e-9;
        if (main) {
          g.drawLine(x1, y1, ex, ey);
        } else {
          g.ctx.save();
          g.ctx.strokeStyle = _hexToRgba(g.color, 0.7);
          g.ctx.lineWidth = 1;
          g.ctx.beginPath(); g.ctx.moveTo(x1, y1); g.ctx.lineTo(ex, ey); g.ctx.stroke();
          g.ctx.restore();
        }
      }
      return {
        endX: Math.max(x1, x2), endY: y1,
        dragRect: g.isInProgress ? null : _bandRect(x1, y1, x2, y2),
      };
    },
  },

  // Gann box — a box subdivided by Gann ratios on both axes plus diagonals.
  gannbox: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts), y1 = g.priceToY(p1.price);
      let x2, y2;
      const p2 = d.points[1];
      if (p2) { x2 = g.tsToX(p2.ts); y2 = g.priceToY(p2.price); }
      else if (g.hover.inside && g.hover.x != null) { x2 = g.hover.x; y2 = g.hover.y; }
      else return null;
      const L = Math.min(x1, x2), R = Math.max(x1, x2);
      const T = Math.min(y1, y2), B = Math.max(y1, y2);
      const ratios = [0, 0.25, 0.382, 0.5, 0.618, 0.75, 1];
      const ctx = g.ctx;
      ctx.save();
      ctx.strokeStyle = _hexToRgba(g.color, 0.5);
      ctx.lineWidth = 1;
      for (const r of ratios) {
        const x = L + (R - L) * r, y = T + (B - T) * r;
        ctx.beginPath(); ctx.moveTo(x, T); ctx.lineTo(x, B); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(L, y); ctx.lineTo(R, y); ctx.stroke();
      }
      ctx.restore();
      g.drawLine(L, T, R, B);
      g.drawLine(L, B, R, T);
      return {
        endX: R, endY: T,
        dragRect: g.isInProgress ? null : { x: L, y: T - 4, w: R - L, h: (B - T) + 8 },
      };
    },
  },

  // ── Fibonacci family ───────────────────────────────────────────────────────

  // Fib extension — three clicks (A,B,C); levels projected from C as ratios of
  // the A→B leg.
  fibext: {
    clicks: 3,
    render(g, d) {
      const pts = d.points;
      if (!pts || pts.length < 2) {
        const p = pts && pts[0];
        if (!p) return null;
        return { endX: g.tsToX(p.ts), endY: g.priceToY(p.price), dragRect: null };
      }
      const a = pts[0], b = pts[1];
      let c;
      if (pts.length >= 3) c = pts[2];
      else if (g.hover.inside && g.hover.x != null) c = { ts: g.xToTs(g.hover.x), price: g.yToPrice(g.hover.y) };
      else c = b;
      const leg = b.price - a.price;
      const xL = g.tsToX(c.ts);
      const ctx = g.ctx;
      ctx.save();
      ctx.font = '500 10px Geist, sans-serif';
      ctx.textBaseline = 'middle';
      ctx.textAlign = 'left';
      let minY = Infinity, maxY = -Infinity;
      for (let i = 0; i < _FIB_EXT.length; i++) {
        const price = c.price + leg * _FIB_EXT[i];
        const y = g.priceToY(price);
        minY = Math.min(minY, y); maxY = Math.max(maxY, y);
        ctx.strokeStyle = _FIB_COLORS[i % _FIB_COLORS.length];
        ctx.lineWidth = g.isSelected ? 1.5 : 1;
        ctx.setLineDash(i === 0 ? [] : [4, 4]);
        ctx.beginPath(); ctx.moveTo(xL, y); ctx.lineTo(g.plot.right, y); ctx.stroke();
        ctx.setLineDash([]);
        ctx.fillStyle = _FIB_COLORS[i % _FIB_COLORS.length];
        ctx.fillText((_FIB_EXT[i] * 100).toFixed(1) + '%  ' + price.toFixed(2), xL + 4, y - 6);
      }
      ctx.restore();
      // The A→B→C guide.
      g.drawLine(g.tsToX(a.ts), g.priceToY(a.price), g.tsToX(b.ts), g.priceToY(b.price));
      g.drawLine(g.tsToX(b.ts), g.priceToY(b.price), xL, g.priceToY(c.price));
      return {
        endX: g.plot.right, endY: (minY + maxY) / 2,
        dragRect: g.isInProgress ? null
            : { x: xL, y: minY - 4, w: g.plot.right - xL, h: (maxY - minY) + 8 },
      };
    },
  },

  // Fib retracement (registry version — 2 clicks, full level set).
  fibchannel: {
    clicks: 3,
    render(g, d) {
      const pts = d.points;
      if (!pts || pts.length < 1) return null;
      const a = { x: g.tsToX(pts[0].ts), y: g.priceToY(pts[0].price) };
      let b;
      if (pts.length >= 2) b = { x: g.tsToX(pts[1].ts), y: g.priceToY(pts[1].price) };
      else if (g.hover.inside && g.hover.x != null) b = { x: g.hover.x, y: g.hover.y };
      else return { endX: a.x, endY: a.y, dragRect: null };
      let third;
      if (pts.length >= 3) third = { x: g.tsToX(pts[2].ts), y: g.priceToY(pts[2].price) };
      else if (pts.length === 2 && g.hover.inside && g.hover.x != null) third = { x: g.hover.x, y: g.hover.y };
      if (!third) { g.drawLine(a.x, a.y, b.x, b.y); return { endX: Math.max(a.x, b.x), endY: (a.y + b.y) / 2, dragRect: null }; }
      const vx = b.x - a.x, vy = b.y - a.y, len = Math.hypot(vx, vy) || 1;
      const nx = -vy / len, ny = vx / len;
      const base = (third.x - a.x) * nx + (third.y - a.y) * ny;
      const ctx = g.ctx;
      let minY = Infinity, maxY = -Infinity;
      for (let i = 0; i < _FIB_RETR.length; i++) {
        const off = base * _FIB_RETR[i];
        const ax = a.x + nx * off, ay = a.y + ny * off;
        const bx = b.x + nx * off, by = b.y + ny * off;
        minY = Math.min(minY, ay, by); maxY = Math.max(maxY, ay, by);
        ctx.save();
        ctx.strokeStyle = _FIB_COLORS[i % _FIB_COLORS.length];
        ctx.lineWidth = 1;
        ctx.setLineDash(i === 0 || i === _FIB_RETR.length - 1 ? [] : [4, 4]);
        ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(bx, by); ctx.stroke();
        ctx.restore();
      }
      const xs = [a.x, b.x], ys = [minY, maxY];
      return {
        endX: Math.max(a.x, b.x), endY: (minY + maxY) / 2,
        dragRect: g.isInProgress ? null : _bboxRect(xs, ys),
      };
    },
  },

  // Fib time zones — vertical lines at Fibonacci bar offsets; p1→p2 sets the
  // unit spacing.
  fibtimezone: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts);
      let x2;
      const p2 = d.points[1];
      if (p2) x2 = g.tsToX(p2.ts);
      else if (g.hover.inside && g.hover.x != null) x2 = g.hover.x;
      else return null;
      const unit = x2 - x1;
      if (Math.abs(unit) < 1) return { endX: x1, endY: g.plot.top, dragRect: null };
      const ctx = g.ctx;
      for (let i = 0; i < _FIB_TIME.length; i++) {
        const x = x1 + unit * _FIB_TIME[i];
        if (x < g.plot.left - 2 || x > g.plot.right + 2) continue;
        ctx.save();
        ctx.strokeStyle = _FIB_COLORS[i % _FIB_COLORS.length];
        ctx.lineWidth = 1;
        ctx.setLineDash(i === 0 ? [] : [4, 4]);
        ctx.beginPath(); ctx.moveTo(x, g.plot.top); ctx.lineTo(x, g.plot.bottom); ctx.stroke();
        ctx.restore();
      }
      return {
        endX: x1 + unit, endY: (g.plot.top + g.plot.bottom) / 2,
        dragRect: g.isInProgress ? null
            : { x: x1 - 4, y: g.plot.top, w: 8, h: g.plot.bottom - g.plot.top },
      };
    },
  },

  // Fib fan — fan of rays from p1 at Fibonacci ratios of the p1→p2 box.
  fibfan: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts), y1 = g.priceToY(p1.price);
      let x2, y2;
      const p2 = d.points[1];
      if (p2) { x2 = g.tsToX(p2.ts); y2 = g.priceToY(p2.price); }
      else if (g.hover.inside && g.hover.x != null) { x2 = g.hover.x; y2 = g.hover.y; }
      else return null;
      const dyTotal = y2 - y1, dxTotal = x2 - x1;
      for (let i = 0; i < _FIB_RETR.length; i++) {
        const r = _FIB_RETR[i];
        const dx = dxTotal, dy = dyTotal * r;
        const range = g.lineParams(x1, y1, dx, dy);
        if (!range) continue;
        const t = Math.max(range[0], range[1]);
        if (t <= 0) continue;
        const ex = x1 + dx * t, ey = y1 + dy * t;
        g.ctx.save();
        g.ctx.strokeStyle = _FIB_COLORS[i % _FIB_COLORS.length];
        g.ctx.lineWidth = 1;
        g.ctx.beginPath(); g.ctx.moveTo(x1, y1); g.ctx.lineTo(ex, ey); g.ctx.stroke();
        g.ctx.restore();
      }
      return {
        endX: Math.max(x1, x2), endY: (y1 + y2) / 2,
        dragRect: g.isInProgress ? null : _bandRect(x1, y1, x2, y2),
      };
    },
  },

  // Fib circles — concentric ellipses at Fibonacci radii around p1; p2 sets the
  // 100% radius.
  fibcircle: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const cx = g.tsToX(p1.ts), cy = g.priceToY(p1.price);
      let ex, ey;
      const p2 = d.points[1];
      if (p2) { ex = g.tsToX(p2.ts); ey = g.priceToY(p2.price); }
      else if (g.hover.inside && g.hover.x != null) { ex = g.hover.x; ey = g.hover.y; }
      else return null;
      const rx = Math.abs(ex - cx), ry = Math.abs(ey - cy);
      if (rx <= 0 || ry <= 0) return { endX: cx, endY: cy, dragRect: null };
      const ctx = g.ctx;
      const ratios = [0.382, 0.618, 1.0];
      for (let i = 0; i < ratios.length; i++) {
        ctx.save();
        ctx.strokeStyle = _FIB_COLORS[i % _FIB_COLORS.length];
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.ellipse(cx, cy, rx * ratios[i], ry * ratios[i], 0, 0, Math.PI * 2);
        ctx.stroke();
        ctx.restore();
      }
      return {
        endX: cx + rx, endY: cy,
        dragRect: g.isInProgress ? null : { x: cx - rx, y: cy - ry, w: 2 * rx, h: 2 * ry },
      };
    },
  },

  // ── Patterns (harmonic / wave / chart) ──────────────────────────────────────

  xabcd: { clicks: 5, render(g, d) { return _renderPolyPattern(g, d, ['X', 'A', 'B', 'C', 'D'], { fill: true }); } },
  cypher: { clicks: 5, render(g, d) { return _renderPolyPattern(g, d, ['X', 'A', 'B', 'C', 'D'], { fill: true }); } },
  abcd: { clicks: 4, render(g, d) { return _renderPolyPattern(g, d, ['A', 'B', 'C', 'D']); } },
  trianglepattern: { clicks: 5, render(g, d) { return _renderPolyPattern(g, d, ['A', 'B', 'C', 'D', 'E']); } },
  threedrives: { clicks: 7, render(g, d) { return _renderPolyPattern(g, d, ['0', 'A', '1', 'B', '2', 'C', '3']); } },
  elliottimpulse: { clicks: 6, render(g, d) { return _renderPolyPattern(g, d, ['0', '1', '2', '3', '4', '5']); } },
  elliottcorrection: { clicks: 4, render(g, d) { return _renderPolyPattern(g, d, ['0', 'A', 'B', 'C']); } },
  headshoulders: { clicks: 7, render(g, d) { return _renderPolyPattern(g, d, ['', 'LS', '', 'H', '', 'RS', '']); } },

  // ── Projection / measure ────────────────────────────────────────────────────

  // Price range — vertical measure of Δprice / % between two prices.
  pricerange: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts), y1 = g.priceToY(p1.price);
      let y2, price2;
      const p2 = d.points[1];
      if (p2) { y2 = g.priceToY(p2.price); price2 = p2.price; }
      else if (g.hover.inside && g.hover.y != null) { y2 = g.hover.y; price2 = g.yToPrice(y2); }
      else return null;
      const ctx = g.ctx;
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, price2 >= p1.price ? 0.08 : 0.08);
      ctx.fillRect(x1 - 30, Math.min(y1, y2), 60, Math.abs(y2 - y1));
      ctx.restore();
      g.drawLine(x1 - 30, y1, x1 + 30, y1);
      g.drawLine(x1 - 30, y2, x1 + 30, y2);
      const dP = price2 - p1.price;
      const pct = p1.price !== 0 ? (dP / p1.price) * 100 : 0;
      _drawNodeLabel(g.ctx, x1, (y1 + y2) / 2,
          (dP >= 0 ? '+' : '') + dP.toFixed(2) + ' (' + pct.toFixed(2) + '%)', g.color, false);
      return {
        endX: x1 + 30, endY: (y1 + y2) / 2,
        dragRect: g.isInProgress ? null
            : { x: x1 - 30, y: Math.min(y1, y2) - 4, w: 60, h: Math.abs(y2 - y1) + 8 },
      };
    },
  },

  // Date range — horizontal measure of bar/time span between two times.
  daterange: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const y = g.priceToY(p1.price);
      const x1 = g.tsToX(p1.ts);
      let x2, ts2;
      const p2 = d.points[1];
      if (p2) { x2 = g.tsToX(p2.ts); ts2 = p2.ts; }
      else if (g.hover.inside && g.hover.x != null) { x2 = g.hover.x; ts2 = g.xToTs(x2); }
      else return null;
      const ctx = g.ctx;
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, 0.08);
      ctx.fillRect(Math.min(x1, x2), y - 16, Math.abs(x2 - x1), 32);
      ctx.restore();
      g.drawLine(x1, y - 16, x1, y + 16);
      g.drawLine(x2, y - 16, x2, y + 16);
      const barMs = (g.candles && g.candles.length > 1) ? (g.candles[1].ts - g.candles[0].ts) || 1 : 1;
      const bars = Math.round((ts2 - p1.ts) / barMs);
      _drawNodeLabel(g.ctx, (x1 + x2) / 2, y, Math.abs(bars) + ' bars', g.color, false);
      return {
        endX: Math.max(x1, x2), endY: y,
        dragRect: g.isInProgress ? null
            : { x: Math.min(x1, x2), y: y - 18, w: Math.abs(x2 - x1), h: 36 },
      };
    },
  },

  // Date-&-price range — measure box reporting Δprice / % / bars together.
  dprange: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const x1 = g.tsToX(p1.ts), y1 = g.priceToY(p1.price);
      let x2, y2, price2, ts2;
      const p2 = d.points[1];
      if (p2) { x2 = g.tsToX(p2.ts); y2 = g.priceToY(p2.price); price2 = p2.price; ts2 = p2.ts; }
      else if (g.hover.inside && g.hover.x != null) {
        x2 = g.hover.x; y2 = g.hover.y; price2 = g.yToPrice(y2); ts2 = g.xToTs(x2);
      } else return null;
      const ctx = g.ctx;
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, 0.07);
      ctx.fillRect(Math.min(x1, x2), Math.min(y1, y2), Math.abs(x2 - x1), Math.abs(y2 - y1));
      ctx.strokeStyle = _hexToRgba(g.color, 0.7);
      ctx.lineWidth = 1;
      ctx.strokeRect(Math.min(x1, x2), Math.min(y1, y2), Math.abs(x2 - x1), Math.abs(y2 - y1));
      ctx.restore();
      const dP = price2 - p1.price;
      const pct = p1.price !== 0 ? (dP / p1.price) * 100 : 0;
      const barMs = (g.candles && g.candles.length > 1) ? (g.candles[1].ts - g.candles[0].ts) || 1 : 1;
      const bars = Math.round((ts2 - p1.ts) / barMs);
      _drawNodeLabel(g.ctx, (x1 + x2) / 2, (y1 + y2) / 2,
          (dP >= 0 ? '+' : '') + dP.toFixed(2) + ' (' + pct.toFixed(2) + '%)  ' + Math.abs(bars) + 'b',
          g.color, false);
      return {
        endX: Math.max(x1, x2), endY: Math.min(y1, y2),
        dragRect: g.isInProgress ? null
            : { x: Math.min(x1, x2), y: Math.min(y1, y2) - 4, w: Math.abs(x2 - x1), h: Math.abs(y2 - y1) + 8 },
      };
    },
  },

  // Forecast — three clicks: a base leg (p1→p2) and a projected leg (p2→p3),
  // the projection drawn dashed with a shaded cone.
  forecast: {
    clicks: 3,
    render(g, d) {
      const pts = d.points;
      if (!pts || pts.length < 1) return null;
      const a = { x: g.tsToX(pts[0].ts), y: g.priceToY(pts[0].price) };
      let b;
      if (pts.length >= 2) b = { x: g.tsToX(pts[1].ts), y: g.priceToY(pts[1].price) };
      else if (g.hover.inside && g.hover.x != null) b = { x: g.hover.x, y: g.hover.y };
      else return { endX: a.x, endY: a.y, dragRect: null };
      g.drawLine(a.x, a.y, b.x, b.y);
      let c;
      if (pts.length >= 3) c = { x: g.tsToX(pts[2].ts), y: g.priceToY(pts[2].price) };
      else if (pts.length === 2 && g.hover.inside && g.hover.x != null) c = { x: g.hover.x, y: g.hover.y };
      if (c) {
        const ctx = g.ctx;
        ctx.save();
        ctx.setLineDash([5, 4]);
        ctx.strokeStyle = g.color;
        ctx.lineWidth = g.strokeW;
        ctx.beginPath(); ctx.moveTo(b.x, b.y); ctx.lineTo(c.x, c.y); ctx.stroke();
        ctx.setLineDash([]);
        ctx.fillStyle = _hexToRgba(g.color, 0.08);
        const cone = Math.abs(c.y - b.y) * 0.4 + 8;
        ctx.beginPath();
        ctx.moveTo(b.x, b.y);
        ctx.lineTo(c.x, c.y - cone);
        ctx.lineTo(c.x, c.y + cone);
        ctx.closePath();
        ctx.fill();
        ctx.restore();
        _drawArrowHead(g.ctx, b.x, b.y, c.x, c.y, g.color, 10);
      }
      const xs = c ? [a.x, b.x, c.x] : [a.x, b.x];
      const ys = c ? [a.y, b.y, c.y] : [a.y, b.y];
      return {
        endX: Math.max(...xs), endY: Math.min(...ys),
        dragRect: g.isInProgress ? null : _bboxRect(xs, ys),
      };
    },
  },

  // Polyline — variable-point open path (double-click / Esc to finish), drawn
  // like the freehand path but with straight segments between explicit clicks.
  polyline: {
    clicks: -1,
    variable: true,
    render(g, d) {
      const pts = d.points;
      if (!pts || pts.length === 0) return null;
      const scr = pts.map((p) => ({ x: g.tsToX(p.ts), y: g.priceToY(p.price) }));
      if (g.isInProgress && g.hover.inside && g.hover.x != null) {
        scr.push({ x: g.hover.x, y: g.hover.y });
      }
      if (scr.length < 2) return { endX: scr[0].x, endY: scr[0].y, dragRect: null };
      for (let i = 0; i < scr.length - 1; i++) {
        g.drawLine(scr[i].x, scr[i].y, scr[i + 1].x, scr[i + 1].y);
      }
      const xs = scr.map((s) => s.x), ys = scr.map((s) => s.y);
      return {
        endX: scr[scr.length - 1].x, endY: scr[scr.length - 1].y,
        dragRect: g.isInProgress ? null : _bboxRect(xs, ys),
      };
    },
  },

  // ── Pitchfork variants ──────────────────────────────────────────────────────
  // Ported from CandL: Schiff (origin = mid(p0,p1)), Modified Schiff
  // (origin = mid(p0, mid(p1,p2))), Inside (origin = p0, tines at 0.25/0.75 of
  // the p1–p2 span). All head toward mid(p1,p2).
  pitchforkschiff: {
    clicks: 3,
    render(g, d) {
      const an = _forkAnchors(g, d);
      const partial = _forkPartial(g, an);
      if (partial) return partial;
      const target = _lerpPt(an.b, an.c, 0.5);
      return _drawForkInChart(g, _lerpPt(an.a, an.b, 0.5), an.b, an.c, target);
    },
  },
  pitchforkmod: {
    clicks: 3,
    render(g, d) {
      const an = _forkAnchors(g, d);
      const partial = _forkPartial(g, an);
      if (partial) return partial;
      const target = _lerpPt(an.b, an.c, 0.5);
      return _drawForkInChart(g, _lerpPt(an.a, target, 0.5), an.b, an.c, target);
    },
  },
  pitchforkinside: {
    clicks: 3,
    render(g, d) {
      const an = _forkAnchors(g, d);
      const partial = _forkPartial(g, an);
      if (partial) return partial;
      const target = _lerpPt(an.b, an.c, 0.5);
      return _drawForkInChart(g, an.a, _lerpPt(an.b, an.c, 0.25), _lerpPt(an.b, an.c, 0.75), target);
    },
  },

  // Disjoint channel — four clicks: edge p0→p1 and an independent edge p2→p3,
  // with the quad between them filled.
  channeldisjoint: {
    clicks: 4,
    render(g, d) {
      const pts = d.points;
      if (!pts || pts.length < 1) return null;
      const P = (p) => ({ x: g.tsToX(p.ts), y: g.priceToY(p.price) });
      const hov = (g.hover.inside && g.hover.x != null) ? { x: g.hover.x, y: g.hover.y } : null;
      const a = P(pts[0]);
      const b = pts[1] ? P(pts[1]) : hov;
      if (!b) return { endX: a.x, endY: a.y, dragRect: null };
      const c = pts[2] ? P(pts[2]) : (pts.length === 2 ? hov : null);
      const e = pts[3] ? P(pts[3]) : (pts.length === 3 ? hov : null);
      const ctx = g.ctx;
      if (c && e) {
        ctx.save();
        ctx.fillStyle = _hexToRgba(g.color, 0.07);
        ctx.beginPath();
        ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y);
        ctx.lineTo(e.x, e.y); ctx.lineTo(c.x, c.y);
        ctx.closePath(); ctx.fill();
        ctx.restore();
        g.drawLine(c.x, c.y, e.x, e.y);
      }
      g.drawLine(a.x, a.y, b.x, b.y);
      const ptsScr = [a, b]; if (c) ptsScr.push(c); if (e) ptsScr.push(e);
      const xs = ptsScr.map((p) => p.x), ys = ptsScr.map((p) => p.y);
      return {
        endX: Math.max(...xs), endY: Math.min(...ys),
        dragRect: g.isInProgress ? null : _bboxRect(xs, ys),
      };
    },
  },

  // ── Smart (data-aware) tools ────────────────────────────────────────────────

  // Long / Short position — one click sets the entry; the stop is 1.5×Wilder
  // ATR(14) away and the target at 2R. `expand` stores [entry, stop, target]
  // as three points so each level is an independently draggable handle.
  longpos: {
    clicks: 1,
    expand: (points, chart) => _positionExpand(points, chart, 1),
    render(g, d) { return _positionRender(g, d, 1); },
  },
  shortpos: {
    clicks: 1,
    expand: (points, chart) => _positionExpand(points, chart, -1),
    render(g, d) { return _positionRender(g, d, -1); },
  },

  // Anchored VWAP — one click anchors; cumulative volume-weighted mean of
  // typical price from the anchor forward, with ±1σ bands.
  avwap: {
    clicks: 1,
    render(g, d) {
      const p0 = d.points[0];
      if (!p0 || !g.candles || g.candles.length === 0) return null;
      const start = _nearestIndex(g.candles, p0.ts);
      if (start < 0) return null;
      const n = g.candles.length - start;
      const vwap = new Array(n), sd = new Array(n);
      let pv = 0, pv2 = 0, vol = 0, tpSum = 0;
      for (let k = 0; k < n; k++) {
        const c = g.candles[start + k];
        const tp = (c.h + c.l + c.c) / 3;
        const v = c.v > 0 ? c.v : 0;
        pv += tp * v; pv2 += tp * tp * v; vol += v; tpSum += tp;
        if (vol > 0) { const m = pv / vol; vwap[k] = m; sd[k] = Math.sqrt(Math.max(0, pv2 / vol - m * m)); }
        else { vwap[k] = tpSum / (k + 1); sd[k] = 0; }
      }
      const xs = new Array(n);
      for (let k = 0; k < n; k++) xs[k] = g.tsToX(g.candles[start + k].ts);
      const ctx = g.ctx;
      if (n > 1) {
        ctx.save();
        ctx.fillStyle = _hexToRgba(g.color, 0.08);
        ctx.beginPath();
        for (let k = 0; k < n; k++) { const y = g.priceToY(vwap[k] + sd[k]); k === 0 ? ctx.moveTo(xs[k], y) : ctx.lineTo(xs[k], y); }
        for (let k = n - 1; k >= 0; k--) { const y = g.priceToY(vwap[k] - sd[k]); ctx.lineTo(xs[k], y); }
        ctx.closePath(); ctx.fill();
        ctx.restore();
      }
      const trace = (off) => {
        ctx.save(); ctx.strokeStyle = _hexToRgba(g.color, 0.5); ctx.lineWidth = 1;
        ctx.beginPath();
        for (let k = 0; k < n; k++) { const y = g.priceToY(vwap[k] + off * sd[k]); k === 0 ? ctx.moveTo(xs[k], y) : ctx.lineTo(xs[k], y); }
        ctx.stroke(); ctx.restore();
      };
      trace(1); trace(-1);
      const main = (w, col) => {
        ctx.save(); ctx.strokeStyle = col; ctx.lineWidth = w;
        ctx.beginPath();
        for (let k = 0; k < n; k++) { const y = g.priceToY(vwap[k]); k === 0 ? ctx.moveTo(xs[k], y) : ctx.lineTo(xs[k], y); }
        ctx.stroke(); ctx.restore();
      };
      main(3, 'rgba(255,255,255,0.7)');
      main(g.strokeW, g.color);
      const x0 = xs[0], y0 = g.priceToY(vwap[0]);
      _drawNodeLabel(g.ctx, x0, y0, 'aVWAP', g.color, true);
      const yN = g.priceToY(vwap[n - 1]);
      return {
        endX: xs[n - 1], endY: yN,
        dragRect: g.isInProgress ? null
            : { x: x0 - 6, y: Math.min(y0, yN) - 18, w: 12, h: Math.abs(yN - y0) + 36 },
      };
    },
  },

  // Smart level — one click drops a self-scoring S/R zone; opacity grows with
  // the number of distinct times price has touched the zone.
  smartlevel: {
    clicks: 1,
    render(g, d) {
      const p0 = d.points[0];
      if (!p0) return null;
      const heightPct = 0.5;
      const half = Math.abs(p0.price) * heightPct / 200;
      const lo = p0.price - half, hi = p0.price + half;
      const yLo = g.priceToY(lo), yHi = g.priceToY(hi);
      const CLUSTER_GAP = 3;
      let touches = 0, lastTouch = -1 - CLUSTER_GAP;
      const cs = g.candles || [];
      for (let i = 0; i < cs.length; i++) {
        if (cs[i].l <= hi && cs[i].h >= lo) {
          if (i - lastTouch - 1 >= CLUSTER_GAP) touches++;
          lastTouch = i;
        }
      }
      const alpha = 0.06 + Math.min(touches, 8) / 8 * 0.18;
      const ctx = g.ctx;
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, alpha);
      ctx.fillRect(g.plot.left, Math.min(yLo, yHi), g.plot.right - g.plot.left, Math.abs(yHi - yLo));
      ctx.restore();
      const yMid = g.priceToY(p0.price);
      g.drawLine(g.plot.left, yMid, g.plot.right, yMid);
      _drawNodeLabel(g.ctx, g.plot.right - 60, yMid,
          touches + ' touch' + (touches === 1 ? '' : 'es'), g.color, true);
      return {
        endX: g.plot.right, endY: yMid,
        dragRect: g.isInProgress ? null
            : { x: g.plot.left, y: Math.min(yLo, yHi) - 2, w: g.plot.right - g.plot.left, h: Math.abs(yHi - yLo) + 4 },
      };
    },
  },

  // Volume X-ray — two clicks define a box; candle volume inside is bucketed
  // into 24 price rows drawn as a left-anchored histogram, POC highlighted.
  volxray: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      let ts2, price2;
      const p2 = d.points[1];
      if (p2) { ts2 = p2.ts; price2 = p2.price; }
      else if (g.hover.inside && g.hover.x != null) { ts2 = g.xToTs(g.hover.x); price2 = g.yToPrice(g.hover.y); }
      else return null;
      const tLo = Math.min(p1.ts, ts2), tHi = Math.max(p1.ts, ts2);
      const pLo = Math.min(p1.price, price2), pHi = Math.max(p1.price, price2);
      const ROWS = 24;
      const rows = new Array(ROWS).fill(0);
      const rowH = (pHi - pLo) / ROWS;
      let max = 0, poc = -1;
      const cs = g.candles || [];
      if (rowH > 0) {
        for (const c of cs) {
          if (c.ts < tLo || c.ts > tHi || !(c.v > 0)) continue;
          const lo = Math.max(c.l, pLo), hi = Math.min(c.h, pHi);
          if (hi < lo) continue;
          const range = c.h - c.l;
          if (range <= 0) {
            const r = Math.min(ROWS - 1, Math.max(0, Math.floor((c.c - pLo) / rowH)));
            rows[r] += c.v; continue;
          }
          const r0 = Math.min(ROWS - 1, Math.max(0, Math.floor((lo - pLo) / rowH)));
          const r1 = Math.min(ROWS - 1, Math.max(0, Math.ceil((hi - pLo) / rowH) - 1));
          for (let r = r0; r <= r1; r++) {
            const rLo = pLo + r * rowH;
            const overlap = Math.min(hi, rLo + rowH) - Math.max(lo, rLo);
            if (overlap > 0) rows[r] += c.v * (overlap / range);
          }
        }
        for (let r = 0; r < ROWS; r++) if (rows[r] > max) { max = rows[r]; poc = r; }
      }
      const xL = g.tsToX(tLo), xR = g.tsToX(tHi);
      const yT = g.priceToY(pHi), yB = g.priceToY(pLo);
      const ctx = g.ctx;
      ctx.save();
      ctx.strokeStyle = _hexToRgba(g.color, 0.5); ctx.lineWidth = 1;
      ctx.strokeRect(xL, yT, xR - xL, yB - yT);
      ctx.restore();
      const maxW = (xR - xL) * 0.9;
      for (let r = 0; r < ROWS && max > 0; r++) {
        const w = rows[r] / max * maxW;
        if (w <= 0) continue;
        const ryTop = g.priceToY(pLo + (r + 1) * rowH);
        const rh = Math.abs(g.priceToY(pLo + r * rowH) - ryTop);
        ctx.save();
        ctx.fillStyle = _hexToRgba(r === poc ? _SMART_GREEN : g.color, r === poc ? 0.5 : 0.28);
        ctx.fillRect(xL, ryTop, w, Math.max(1, rh - 1));
        ctx.restore();
      }
      if (poc >= 0) {
        const yPoc = g.priceToY(pLo + (poc + 0.5) * rowH);
        ctx.save();
        ctx.setLineDash([4, 4]); ctx.strokeStyle = _SMART_GREEN; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(xL, yPoc); ctx.lineTo(xR, yPoc); ctx.stroke();
        ctx.restore();
      }
      return {
        endX: xR, endY: yT,
        dragRect: g.isInProgress ? null : { x: xL, y: yT - 4, w: xR - xL, h: (yB - yT) + 8 },
      };
    },
  },

  // ── Annotations (text-bearing) ───────────────────────────────────────────────
  // Text content is entered via a Flutter dialog after placement (the shell
  // listens for these kinds on drawingCommitted) and round-trips in d.text.

  // Plain text label.
  text: {
    clicks: 1,
    render(g, d) {
      const p = d.points[0];
      if (!p) return null;
      const x = g.tsToX(p.ts), y = g.priceToY(p.price);
      const t = d.text || 'Text';
      const w = _drawText(g.ctx, x, y, t, g.color, 'left');
      return {
        endX: x + w, endY: y,
        dragRect: g.isInProgress ? null : { x: x - 2, y: y - 10, w: w + 4, h: 20 },
      };
    },
  },

  // Sticky note — tinted rounded box.
  note: {
    clicks: 1,
    render(g, d) {
      const p = d.points[0];
      if (!p) return null;
      const x = g.tsToX(p.ts), y = g.priceToY(p.price);
      const t = d.text || 'Note';
      const ctx = g.ctx;
      ctx.save();
      ctx.font = '600 11px Geist, sans-serif';
      const tw = ctx.measureText(t).width;
      ctx.restore();
      const w = tw + 16, h = 22, bx = x, by = y - h / 2;
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, 0.16);
      _roundRectPath(ctx, bx, by, w, h, 5); ctx.fill();
      ctx.strokeStyle = g.color; ctx.lineWidth = 1;
      _roundRectPath(ctx, bx, by, w, h, 5); ctx.stroke();
      ctx.restore();
      _drawText(g.ctx, bx + 8, y, t, g.color, 'left');
      return { endX: bx + w, endY: y, dragRect: g.isInProgress ? null : { x: bx, y: by, w, h } };
    },
  },

  // Speech-bubble comment sitting above the anchor with a tail to it.
  comment: {
    clicks: 1,
    render(g, d) {
      const p = d.points[0];
      if (!p) return null;
      const x = g.tsToX(p.ts), y = g.priceToY(p.price);
      const t = d.text || 'Comment';
      const ctx = g.ctx;
      ctx.save();
      ctx.font = '600 11px Geist, sans-serif';
      const tw = ctx.measureText(t).width;
      ctx.restore();
      const w = tw + 16, h = 22;
      const bx = x - w / 2, by = y - h - 12;
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, 0.16);
      _roundRectPath(ctx, bx, by, w, h, 6); ctx.fill();
      // tail
      ctx.beginPath();
      ctx.moveTo(x - 5, by + h); ctx.lineTo(x + 5, by + h); ctx.lineTo(x, by + h + 9);
      ctx.closePath(); ctx.fill();
      ctx.strokeStyle = g.color; ctx.lineWidth = 1;
      _roundRectPath(ctx, bx, by, w, h, 6); ctx.stroke();
      ctx.restore();
      _drawText(g.ctx, x, by + h / 2, t, g.color, 'center');
      return { endX: bx + w, endY: by, dragRect: g.isInProgress ? null : { x: bx, y: by, w, h: h + 12 } };
    },
  },

  // Callout — two clicks: p1 is the target, p2 the label box, joined by a
  // leader line.
  callout: {
    clicks: 2,
    render(g, d) {
      const p1 = d.points[0];
      if (!p1) return null;
      const tx = g.tsToX(p1.ts), ty = g.priceToY(p1.price);
      let bxc, byc;
      const p2 = d.points[1];
      if (p2) { bxc = g.tsToX(p2.ts); byc = g.priceToY(p2.price); }
      else if (g.hover.inside && g.hover.x != null) { bxc = g.hover.x; byc = g.hover.y; }
      else { return { endX: tx, endY: ty, dragRect: null }; }
      const t = d.text || 'Callout';
      const ctx = g.ctx;
      ctx.save();
      ctx.font = '600 11px Geist, sans-serif';
      const tw = ctx.measureText(t).width;
      ctx.restore();
      const w = tw + 16, h = 22, bx = bxc - w / 2, by = byc - h / 2;
      g.drawLine(tx, ty, bxc, byc);
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, 0.16);
      _roundRectPath(ctx, bx, by, w, h, 5); ctx.fill();
      ctx.strokeStyle = g.color; ctx.lineWidth = 1;
      _roundRectPath(ctx, bx, by, w, h, 5); ctx.stroke();
      ctx.restore();
      _drawText(g.ctx, bxc, byc, t, g.color, 'center');
      return {
        endX: Math.max(tx, bx + w), endY: Math.min(ty, by),
        dragRect: g.isInProgress ? null : _bboxRect([tx, bx, bx + w], [ty, by, by + h]),
      };
    },
  },

  // Price label — a tag pinned to the price with a left pointer.
  pricelabel: {
    clicks: 1,
    render(g, d) {
      const p = d.points[0];
      if (!p) return null;
      const x = g.tsToX(p.ts), y = g.priceToY(p.price);
      const t = d.text || p.price.toFixed(2);
      const ctx = g.ctx;
      ctx.save();
      ctx.font = '600 11px Geist, sans-serif';
      const tw = ctx.measureText(t).width;
      ctx.restore();
      const w = tw + 16, h = 20, bx = x + 7, by = y - h / 2;
      ctx.save();
      ctx.fillStyle = g.color;
      ctx.beginPath();
      ctx.moveTo(x, y); ctx.lineTo(bx, y - 5); ctx.lineTo(bx, y + 5);
      ctx.closePath(); ctx.fill();
      _roundRectPath(ctx, bx, by, w, h, 4); ctx.fill();
      ctx.restore();
      ctx.save();
      ctx.font = '600 11px Geist, sans-serif';
      ctx.textBaseline = 'middle'; ctx.textAlign = 'left';
      ctx.fillStyle = '#FFFFFF';
      ctx.fillText(t, bx + 8, y);
      ctx.restore();
      return { endX: bx + w, endY: y, dragRect: g.isInProgress ? null : { x, y: by, w: w + 7, h } };
    },
  },

  // Sign post — vertical pole from the bar up to a label box.
  signpost: {
    clicks: 1,
    render(g, d) {
      const p = d.points[0];
      if (!p) return null;
      const x = g.tsToX(p.ts), y = g.priceToY(p.price);
      const t = d.text || 'Sign';
      const topY = Math.max(g.plot.top + 14, y - 48);
      g.drawLine(x, y, x, topY);
      const ctx = g.ctx;
      ctx.save();
      ctx.font = '600 11px Geist, sans-serif';
      const tw = ctx.measureText(t).width;
      ctx.restore();
      const w = tw + 16, h = 20, bx = x - w / 2, by = topY - h;
      ctx.save();
      ctx.fillStyle = _hexToRgba(g.color, 0.9);
      _roundRectPath(ctx, bx, by, w, h, 4); ctx.fill();
      ctx.restore();
      ctx.save();
      ctx.font = '600 11px Geist, sans-serif';
      ctx.textBaseline = 'middle'; ctx.textAlign = 'center';
      ctx.fillStyle = '#FFFFFF';
      ctx.fillText(t, x, by + h / 2);
      ctx.restore();
      return {
        endX: x + w / 2, endY: by,
        dragRect: g.isInProgress ? null : { x: bx, y: by, w, h: (y - by) },
      };
    },
  },

  // ── Markers (no text) ────────────────────────────────────────────────────────

  // Up arrow below the point (bullish marker).
  arrowup: {
    clicks: 1,
    render(g, d) {
      const p = d.points[0];
      if (!p) return null;
      const x = g.tsToX(p.ts), y = g.priceToY(p.price);
      const ctx = g.ctx;
      ctx.save();
      ctx.fillStyle = g.color;
      ctx.beginPath();
      ctx.moveTo(x, y); ctx.lineTo(x - 7, y + 12); ctx.lineTo(x - 2.5, y + 12);
      ctx.lineTo(x - 2.5, y + 22); ctx.lineTo(x + 2.5, y + 22);
      ctx.lineTo(x + 2.5, y + 12); ctx.lineTo(x + 7, y + 12);
      ctx.closePath(); ctx.fill();
      ctx.restore();
      return { endX: x + 7, endY: y, dragRect: g.isInProgress ? null : { x: x - 8, y: y - 2, w: 16, h: 26 } };
    },
  },

  // Down arrow above the point (bearish marker).
  arrowdown: {
    clicks: 1,
    render(g, d) {
      const p = d.points[0];
      if (!p) return null;
      const x = g.tsToX(p.ts), y = g.priceToY(p.price);
      const ctx = g.ctx;
      ctx.save();
      ctx.fillStyle = g.color;
      ctx.beginPath();
      ctx.moveTo(x, y); ctx.lineTo(x - 7, y - 12); ctx.lineTo(x - 2.5, y - 12);
      ctx.lineTo(x - 2.5, y - 22); ctx.lineTo(x + 2.5, y - 22);
      ctx.lineTo(x + 2.5, y - 12); ctx.lineTo(x + 7, y - 12);
      ctx.closePath(); ctx.fill();
      ctx.restore();
      return { endX: x + 7, endY: y, dragRect: g.isInProgress ? null : { x: x - 8, y: y - 26, w: 16, h: 28 } };
    },
  },

  // Flag — pole + pennant.
  flag: {
    clicks: 1,
    render(g, d) {
      const p = d.points[0];
      if (!p) return null;
      const x = g.tsToX(p.ts), y = g.priceToY(p.price);
      const topY = y - 26;
      g.drawLine(x, y, x, topY);
      const ctx = g.ctx;
      ctx.save();
      ctx.fillStyle = g.color;
      ctx.beginPath();
      ctx.moveTo(x, topY); ctx.lineTo(x + 16, topY + 5); ctx.lineTo(x, topY + 10);
      ctx.closePath(); ctx.fill();
      ctx.restore();
      return { endX: x + 16, endY: topY, dragRect: g.isInProgress ? null : { x: x - 2, y: topY - 2, w: 20, h: (y - topY) + 4 } };
    },
  },
};

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

class Chart {
  constructor({ container, paneId, palette, requestHistory, subscribe, unsubscribe, notifyBrickSize }) {
    this._notifyBrickSize = typeof notifyBrickSize === 'function' ? notifyBrickSize : (() => {});
    this.container = container;
    this.paneId = paneId;
    this.palette = palette;
    // Two-layer palette: `_basePalette` holds the pristine theme; never
    // mutated by Customize overrides. `_customPalette` is the sparse map of
    // user-set overrides. Without separating these, repeated Customize
    // changes accumulate (e.g. picking red then back to green leaves red
    // applied because the previous merge's output became the new base).
    this._basePalette = palette;
    this._customPalette = {};
    this.requestHistory = requestHistory;
    this.subscribe = subscribe;
    this.unsubscribe = unsubscribe;

    // Selection
    this.scrip = null;           // { exch, token, tsym, dispName, ls, ti }
    this.timeframeMinutes = 1;
    this.qty = 1;                // per-pane order qty; pushed via setQty

    // Tradable flag — driven by GetSecurityInfo (`nontrd` key):
    //   - null  → API hasn't responded yet for this scrip; treat as tradable
    //   - true  → API explicitly says tradable (no `nontrd` key in response)
    //   - false → API says non-tradable (`nontrd:"1"`)
    // No more bid/ask heuristics or instname guessing — the API is the single
    // source of truth. Reset to null whenever a new scrip is set.
    this._scripTradable = null;

    // Phase 16 — chart style + H/L marker flag (mirror Flutter's PaneState).
    this.candleStyle = 'candles';
    this.showHighLowMarkers = true;
    this._haPrev = null;          // {haOpen, haClose} cached between bars
    this._renkoBricks = [];       // {idx, openPrice, closePrice, direction, sourceBarTime, sourceBarIndex}
    this._renkoBrickSize = 0;     // ATR-derived, pushed back via _notifyBrickSize
    // Phase 26 — rebinned pseudo-candle array for linebreak / kagi / range / pnf.
    // Each element mirrors a candle: {o,h,l,c,v,ts, direction, ...extra}. Built
    // by _rebuildRebinned() and consumed by the draw switch + _seriesLength().
    this._rebinned = [];
    this._rebinnedStyle = null;   // which style _rebinned was built for

    // Phase 18 — option-chain OI bars + LTP bar-close countdown.
    this.showOptionChainOi = false;
    this.showBarCountdown = true;
    // Phase 20 — classical pivot points (PP, R1-R3, S1-S3) computed from the
    // previous trading day's H/L/C of the loaded candles. Default OFF.
    this.showKeyLevels = false;
    // Phase 23.1 — pivot variant ('classical' | 'fibonacci' | 'camarilla').
    this.pivotVariant = 'classical';
    // Phase 23.2 — magnet snap-to-candle OHLC when drawing.
    this.magnetEnabled = false;
    // Phase 23.3 — drawing lock + hide-all session toggles.
    this.drawingsLocked = false;
    this.drawingsHidden = false;
    // Phase 23.4 — volume profile gutter histogram.
    this.showVolumeProfile = false;
    // Phase 25 — auto-pattern (swing pivot markers + HH/HL/LH/LL labels).
    this.showAutoPattern = false;
    // Crosshair LINES — when false, the vertical + horizontal dashed lines
    // are skipped but the right-axis price chip and bottom-axis time chip
    // still render under the cursor. Lets the user keep the value readout
    // without the visual clutter of full-span lines.
    this.showCrosshairLines = true;
    // Scan-explanation lite mode + payload. When `_liteMode` is true the
    // chart suppresses order/depth click dispatches (no plus, no bid/ask
    // tap-to-place). When `_explainPayload` is set, the render loop also
    // paints matched-bar shading and server-supplied indicator series.
    this._liteMode = false;
    this._explainPayload = null;
    this._oiData = []; // [{strike, callOi, putOi, callOiChgPct, putOiChgPct}]
    // 1Hz redraw so the countdown text updates each second without ticks.
    // Created on demand; toggled by _updateSecondTimer.
    this._secondTimer = null;

    // Data
    this.candles = [];           // aggregated target-timeframe candles
    this.tickState = { lp: null, v: null, ft: null, bid: null, ask: null, oi: null };
    this.aggState = { prevCumVol: null, prevPrice: null, prevMs: null };

    // View
    this.view = {
      cellW: 10,
      pricePerPx: null,          // null = auto-fit
      priceCenter: null,         // null = auto-fit
      offsetX: 0,
      autoFollow: true,
      autoFitY: true,
    };

    // Overlays
    this.overlays = { gridlines: true, volume: true };

    // Interaction state — populated by _attachInteraction().
    this.hover = { x: null, y: null, inside: false };
    this._dragMode = null;
    this._dragLastX = 0;
    this._dragLastY = 0;

    // Canvas
    this.canvas = document.createElement('canvas');
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d', { alpha: false });
    this.dpr = window.devicePixelRatio || 1;

    // History request bookkeeping
    this._pendingRequestId = null;
    // Infinite-scroll extend bookkeeping. Distinct from the full-load id so a
    // pan-triggered extend can't be cancelled by the full-load arrival check.
    this._pendingExtendId = null;
    this._extendBlockedUntil = 0;
    // Set to true when the server returns an empty page for an extend — there
    // is no more history before our earliest loaded candle, so stop pestering.
    this._noMoreHistory = false;

    // Live-tick freshness tracking (drives the "Stale" pill in the OHLC area)
    this._lastTickAt = 0;

    // Per-pane loading/error banner — drawn as a centered chip with a
    // semi-transparent dim over the chart, so other panes stay interactive.
    this._loadingTitle = null;
    this._loadingDetail = null;

    // Per-pane overlay state — horizontal lines for positions/orders/SLs.
    // Set via setOverlays(list); rendered in _drawOverlays during draw().
    this._overlays = [];
    // Phase 17.C — pending optimistic overlay drag-modify prices, keyed by
    // overlay id. Set on drag-end, cleared when the server's price matches
    // (within tick) or the entry expires. Patches `this._overlays[*].price`
    // at setPaneOverlays time so server roundtrips don't briefly flicker
    // the chip back to the pre-drag price.
    this._pendingOverlayMoves = new Map(); // id -> { price, expiresAt }
    this._overlayHits = []; // Recomputed each draw: { rect, action, overlayId }
    this._headerHits = []; // { rect, kind: 'bid'|'ask'|'qty' }
    this._plusHit = null; // { rect, price } or null
    // Phase 14.1 — keyboard shortcuts gate (pushed from Flutter via the
    // store; default OFF so the user opts in via Settings).
    this._shortcutsEnabled = false;
    // Drag-to-modify state. Non-null while the user is dragging an order
    // line: { overlayId, originalPrice, lastClientY, hasMoved }
    this._dragOverlay = null;
    // Pinned crosshair — set when the user clicks `+` so the dashed lines +
    // price chip stay at the click point while the popup is open. Cleared
    // by Flutter via `unpinCrosshair` after the popup dismisses, or by any
    // new mousedown inside the iframe.
    this._pinnedHover = null; // { x, y } in iframe-local px

    // Resizable sub-pane ratio — total sub-pane height as fraction of the
    // chart's inner height. Persisted in localStorage per pane id so user's
    // resize survives reloads. Clamp [0.10, 0.65] applied on read; per-pane
    // 60px minimum enforced at draw time.
    try {
      const raw = window.localStorage.getItem('chartEngineSubRatio_' + paneId);
      const parsed = parseFloat(raw);
      this._subPaneRatio = (isFinite(parsed) && parsed >= 0.10 && parsed <= 0.65)
          ? parsed
          : 0.20;
    } catch (_) {
      this._subPaneRatio = 0.20;
    }
    this._resizingSubPane = false;     // true while dragging the divider
    this._subDividerHover = false;     // for cursor swap
    this._subDividerY = null;          // last frame's divider Y for hit-test
    // Per-sub-pane manual Y view state, keyed by indicator id.
    // Each entry: { center: number|null, perPx: number|null }.
    // Both null = auto-fit (default); filled in on first vertical pan/zoom.
    this._subPaneView = {};
    // Last drawn subPlots array — cached so the mousedown / wheel / dblclick
    // handlers can hit-test which sub-pane the cursor is in without
    // recomputing the layout.
    this._lastSubPlots = [];

    // Phase 7 drawing state.
    this._drawings = [];            // committed drawings for current scrip
    this._drawMode = null;          // 'hline' / 'trendline' / 'rect' / null
    this._inProgressDrawing = null;
    // Transient one-shot measurement — { p1: {price,ts}, p2: {price,ts} }
    // or null. Set when the user completes the 2nd measure-tool click,
    // cleared on the next mousedown anywhere else or on tool change.
    this._activeMeasure = null; // { kind, color, points: [{price, ts}] }
    // Phase 31 — CandLlabs ghost projections (Echoes / Oracle). Anchored at the
    // last bar, sprouting rightward into future space. Ported from CandL's
    // ProjectionLine / ProjectionBand + setProjections auto-fit.
    this._projLines = [];           // [{ id, color, opacity, width, dashed, points:[{barOffset, price}] }]
    this._projBand = null;          // { color, opacity, upper:[{barOffset,price}], lower:[{barOffset,price}] }
    this._projSavedOffsetX = null;  // restore the user's pan when projections clear
    // Phase 30 — left gutter reserved for the floating drawing rail. The rail
    // toggles this (46 when shown, 0 when collapsed) so the header + candles
    // reclaim the space. Lite mode always uses 0 (no rail there).
    this._leftGutter = 46;
    this._drawingHits = [];         // [{ rect, drawingId, action: 'delete'|'drag', kind }]
    this._indicatorChipHits = [];   // [{ rect, indicatorId, action: 'toggleHide'|'delete' }]
    // Full-row rects for each indicator chip — used to (a) keep the row
    // icons visible while the cursor is anywhere over the row (the cursor
    // moving onto an icon shouldn't blink the icons out), and (b)
    // suppress the chart crosshair when over any chip area.
    this._indicatorRowRects = []; // [{ rect, indicatorId }]
    this._hoveredIndicatorRowId = null;
    // Collapse state for the indicator chip stack — persisted per pane id.
    // When collapsed only the header chip is shown so the chart area isn't
    // eaten by a tall column of chips when many indicators are active.
    try {
      // Default collapsed — matches TradingView UX. A single tiny "˅ N"
      // button stays out of the way; click expands to the full list.
      // Persisted per pane so the user's choice sticks.
      const raw = window.localStorage
          .getItem('chartEngineIndChipsCollapsed_' + paneId);
      this._indicatorChipsCollapsed = raw == null ? true : raw === '1';
    } catch (_) {
      this._indicatorChipsCollapsed = true;
    }

    // Phase 10 — selection + drag-to-move + color swatch palette.
    this._selectedDrawingId = null;
    this._dragDrawingId = null;
    this._dragDrawingStartPoints = null; // snapshot of points at drag start
    this._dragStartClientX = 0;
    this._dragStartClientY = 0;
    this._dragDrawingMoved = false;
    // Phase 30 — per-anchor handle editing (reshape / extend a single point).
    this._dragHandleId = null;     // drawingId whose handle is being dragged
    this._dragHandleIndex = -1;    // which point index
    this._dragHandleMoved = false;
    this._drawingHandleHits = [];  // [{ rect, drawingId, pointIndex }]
    this._colorSwatchHits = []; // [{ rect, color, drawingId }]
    // Per-toolbar popup state — { drawingId, kind: 'color'|'stroke', anchorX }
    // Set when the user clicks the color or stroke button; cleared on
    // subsequent click outside or on toggle.
    this._toolbarPopup = null;
    // Phase 19.2 — rect drag-to-draw state.
    this._rectDragging = false;
    this._rectAnchorClientX = 0;
    this._rectAnchorClientY = 0;

    // Phase 8 — per-pane technical indicators (SMA / EMA / RSI).
    this._indicators = []; // [{id, kind, period, color}]

    // Per-draw memoization of indicator compute functions. Each method is
    // wrapped at instantiation time so every call inside a single draw()
    // shares one result; the cache is reset at the start of every draw().
    // This eliminates the n×m factor of (panes × duplicate compute calls
    // for the same indicator) that was making multi-pane layouts hang.
    this._installComputeMemo();

    // Resize observation
    this._ro = new ResizeObserver(() => this.resize());
    this._ro.observe(this.container);
    this.resize();
    this._attachInteraction();

    // Periodic redraw so the staleness check transitions Live → Stale
    // even when no new ticks arrive. 5s cadence is fine since the
    // threshold is 120s.
    this._stalenessTicker = setInterval(() => {
      if (this._lastTickAt) this.scheduleRedraw();
    }, 5000);

    // Bucket advancement — thinly-traded options/commodities don't tick
    // every bar window, so the aggregator (which only fires on tick) leaves
    // the chart frozen on the last filled bar. Every 2s we check if the
    // current wall-clock bucket has moved past the last candle and, if so,
    // synthesise flat continuation bars (O=H=L=C=lastClose, V=0) up to the
    // current bucket. Real ticks arriving later still update C/H/L of the
    // synthesised current bar via the existing aggregator path.
    this._advanceBarsTicker = setInterval(() => {
      this._advanceEmptyBarsIfNeeded();
    }, 2000);

    this._updateSecondTimer();
  }

  // Wraps every heavy indicator compute method on this instance with a
  // memoizer that consults `_computeCache` (reset every draw). Same
  // method-name → same key → result is reused across all call sites
  // within a frame (`_drawIndicators` + `_drawSubPanes` + value chip +
  // hover overlay + range axis all ask for the same series and were
  // recomputing it independently before).
  _installComputeMemo() {
    const NAMES = [
      '_computeSMA', '_computeEMA', '_computeRSI', '_computeATR',
      '_computeBB', '_computeVWAP', '_computeMACD', '_computeStoch',
      '_computeStochRsi', '_computeZLEMA', '_computeMcGinley', '_computeEFI',
      '_computeSqueeze', '_computeWaveTrend', '_computeConnorsRSI',
      '_computeMaRibbon', '_computeIchimoku', '_computeVolStop',
      '_computeAO', '_computeMFI', '_computeOBV', '_computeCMF',
      '_computeWilliamsR', '_computeCisd', '_computeFvg', '_computeOb',
      '_computeLiqSweep', '_computeMss',
      // Phase 29 — added indicators.
      '_computeWMA', '_computeHMA', '_computeKeltner', '_computeDonchian',
      '_computeSuperTrend', '_computeCCI', '_computeROC', '_computeCVD',
      '_computeADX',
      // Added indicators — PSAR, VWMA, TRIX, Vortex, UO, DPO, PVT, A/D.
      '_computePSAR', '_computeVWMA', '_computeTRIX', '_computeVortex',
      '_computeUO', '_computeDPO', '_computePVT', '_computeAD',
    ];
    for (const name of NAMES) {
      const raw = Chart.prototype[name];
      if (typeof raw !== 'function') continue;
      this[name] = (...args) => {
        // No cache active (called outside a draw) → fall through.
        if (!this._computeCache) return raw.apply(this, args);
        // Candle state is part of the key so renko-swap (which mutates
        // this.candles INSIDE _drawIndicators / _drawSubPanes) doesn't
        // hand out stale results to the other drawer.
        const n = this.candles.length;
        const lastTs = n > 0 ? this.candles[n - 1].ts : 0;
        let argKey;
        if (args.length === 0) {
          argKey = '';
        } else if (args.length === 1 && typeof args[0] === 'object' &&
                   args[0] != null) {
          const a = args[0];
          argKey = (a.id || '') + '|' + (a.period || 0) + '|' +
              (a.params ? JSON.stringify(a.params) : '');
        } else {
          argKey = args.join(',');
        }
        const key = name + '@' + n + ':' + lastTs + '#' + argKey;
        if (this._computeCache.has(key)) return this._computeCache.get(key);
        const v = raw.apply(this, args);
        this._computeCache.set(key, v);
        return v;
      };
    }
  }

  // --- Public API (called by chart-engine.js) -----------------------------
  setSymbol(scrip) {
    const oldKey = this.scrip ? (this.scrip.exch + '|' + this.scrip.token) : null;
    const newKey = scrip.exch + '|' + scrip.token;
    if (oldKey === newKey) return;
    if (this.scrip) this.unsubscribe({ exch: this.scrip.exch, token: this.scrip.token });
    this.scrip = scrip;
    this._scripTradable = null;  // shell will push the API result via setScripTradable
    this._resetData();
    this._renkoBricks = [];
    this._renkoBrickSize = 0;
    this._rebinned = [];
    this._clearLabProjection();
    this._pendingOverlayMoves.clear();
    // _notifyBrickSize is re-emitted after the next history load completes.
    this._loadHistory();
  }

  // Driven by GetSecurityInfo. `tradable` is the boolean derived from the
  // response's `nontrd` key (absent → true, "1" → false). Posted by the
  // Flutter shell once per scrip.
  setScripTradable(tradable) {
    const next = tradable === true ? true : tradable === false ? false : null;
    if (this._scripTradable === next) return;
    this._scripTradable = next;
    this.scheduleRedraw();
  }

  setTimeframe(minutes) {
    if (minutes === this.timeframeMinutes) return;
    this.timeframeMinutes = minutes;
    this._resetData();
    this._renkoBricks = [];
    this._renkoBrickSize = 0;
    this._rebinned = [];
    this._clearLabProjection();
    this._pendingOverlayMoves.clear();
    // _notifyBrickSize is re-emitted after the next history load completes.
    if (this.scrip) this._loadHistory();
  }

  // ── Phase 31 — CandLlabs ghost projections ───────────────────────────────
  // The Lab panel computes future paths (Echoes / Oracle) and hands us
  // ProjectionLine[] + an optional ProjectionBand. We anchor them at the last
  // bar (barOffset 0 = now) and, on first set, pan left once so the projection
  // plus a little breathing room is visible (the user's pan is restored when
  // projections clear). Mirrors CandL's setProjections / drawProjections.
  setLabProjection(data) {
    if (!data || (!Array.isArray(data.lines) && !data.band)) {
      this._clearLabProjection();
      return;
    }
    this._projLines = Array.isArray(data.lines) ? data.lines : [];
    this._projBand = data.band || null;
    // Auto-fit: reveal future space for the longest projection + 3 bars.
    let maxOff = 0;
    for (const l of this._projLines) {
      for (const p of l.points) if (p.barOffset > maxOff) maxOff = p.barOffset;
    }
    if (this._projBand) {
      for (const p of this._projBand.upper) if (p.barOffset > maxOff) maxOff = p.barOffset;
      for (const p of this._projBand.lower) if (p.barOffset > maxOff) maxOff = p.barOffset;
    }
    const cw = this.view.cellW || 6;
    // offsetX shifts the series; more-negative reveals room on the right.
    const want = -(maxOff + 3) * cw + 0.5 * cw;
    if (this._projSavedOffsetX == null) this._projSavedOffsetX = this.view.offsetX || 0;
    if ((this.view.offsetX || 0) > want) this.view.offsetX = want;
    this.scheduleRedraw();
  }

  // Set the left gutter reserved for the drawing rail (px). The rail calls
  // this on collapse (0) / expand (46) so the chart content shifts with it.
  setLeftGutter(px) {
    const next = Math.max(0, +px || 0);
    if (next === this._leftGutter) return;
    this._leftGutter = next;
    this.scheduleRedraw();
  }

  _clearLabProjection() {
    if (this._projLines.length === 0 && !this._projBand &&
        this._projSavedOffsetX == null) return;
    if (this._projSavedOffsetX != null) {
      this.view.offsetX = this._projSavedOffsetX;
      this._projSavedOffsetX = null;
    }
    this._projLines = [];
    this._projBand = null;
    this.scheduleRedraw();
  }

  // Render ghost projections — translucent band first, then the ghost lines.
  // Drawn above candles/overlays but beneath drawings + crosshair.
  _drawLabProjection(plot, priceToY) {
    if (this._projLines.length === 0 && !this._projBand) return;
    const lastIndex = this._seriesLength() - 1;
    if (lastIndex < 0) return;
    const xAt = (off) => this._candleXCenter(lastIndex + off, plot);
    const ctx = this.ctx;
    ctx.save();
    ctx.beginPath();
    ctx.rect(plot.left, plot.top, plot.width, plot.height);
    ctx.clip();
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    const band = this._projBand;
    if (band && band.upper.length >= 2 && band.lower.length >= 2) {
      ctx.beginPath();
      for (let i = 0; i < band.upper.length; i++) {
        const p = band.upper[i];
        const x = xAt(p.barOffset), y = priceToY(p.price);
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      for (let i = band.lower.length - 1; i >= 0; i--) {
        const p = band.lower[i];
        ctx.lineTo(xAt(p.barOffset), priceToY(p.price));
      }
      ctx.closePath();
      ctx.globalAlpha = Math.min(1, Math.max(0, band.opacity));
      ctx.fillStyle = band.color;
      ctx.fill();
      ctx.globalAlpha = 1;
    }
    for (const line of this._projLines) {
      if (!line.points || line.points.length < 2) continue;
      ctx.beginPath();
      for (let i = 0; i < line.points.length; i++) {
        const p = line.points[i];
        const x = xAt(p.barOffset), y = priceToY(p.price);
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.globalAlpha = Math.min(1, Math.max(0, line.opacity));
      ctx.strokeStyle = line.color;
      ctx.lineWidth = line.width || 1;
      ctx.setLineDash(line.dashed ? [4, 3] : []);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
    ctx.setLineDash([]);
    ctx.restore();
  }

  // Lite mode — used by the scan-explanation host. Suppresses order/depth
  // click dispatches (the explain view is read-only) and is the gate for
  // the matched-bar shading + server indicator render branch in draw().
  setLiteMode(value) {
    const next = value === true;
    if (this._liteMode === next) return;
    this._liteMode = next;
    this.scheduleRedraw();
  }

  // Hands the chart a pre-baked explanation payload. Bars become the
  // candle series (replacing any history-load result); the indicators map,
  // matched mask, and column metadata feed the render branch in draw().
  // Server bars carry `date` strings; we synthesise epoch-ms timestamps
  // since the internal candle shape keys on `ts`. `ticker` becomes a
  // minimal pseudo-scrip so the few `this.scrip`-dependent render paths
  // (OHLC strip label, axis chips) don't see null.
  setExplanationData({ bars, indicators, matched, columns, ticker, displayName }) {
    const list = Array.isArray(bars) ? bars : [];
    this.candles = list.map((b) => {
      // Internal `ts` is in SECONDS (every aggregator + axis call multiplies
      // by 1000 to get ms — e.g. `_drawTimeAxis` does `c.ts * 1000`). Server
      // sends `date: "YYYY-MM-DD"` so we parse, divide, floor.
      const ts = (b && typeof b.date === 'string')
          ? Math.floor(Date.parse(b.date + 'T00:00:00Z') / 1000)
          : 0;
      const num = (v) => (typeof v === 'number' && isFinite(v))
          ? v
          : (Number(v) || 0);
      return {
        ts,
        o: num(b.open),
        h: num(b.high),
        l: num(b.low),
        c: num(b.close),
        v: num(b.volume),
      };
    });
    // Daily timeframe so `_drawTimeAxis` formats labels as "16 Apr" (its
    // `>= 1440` branch) instead of `hh:mm`, and so `_advanceEmptyBarsIfNeeded`
    // self-disables (its own >= 1440 guard).
    this.timeframeMinutes = 1440;
    this._explainPayload = {
      indicators: (indicators && typeof indicators === 'object') ? indicators : {},
      matched: Array.isArray(matched) ? matched : [],
      columns: Array.isArray(columns) ? columns : [],
    };
    // Explain mode IS lite mode — the lite-host's standalone setLiteMode
    // message races setLayout and lands before pane '0' exists, so this
    // is the reliable place to flip the flag for an explain chart.
    this._liteMode = true;
    // Decide which float columns render as main-pane overlays vs their
    // own sub-pane. Server provides a `sub_panel` hint, but for some
    // scanners that hint is wrong from the price scale's perspective:
    // a "volume > 5× SMA(volume,20)" scanner returns volume columns
    // with sub_panel=false, then the values (~50,000) sit completely
    // off the price-pane y-range (~200). Auto-promote any float column
    // whose magnitude exceeds 5× the candle price range to a sub-pane.
    let priceMax = 0;
    for (const c of this.candles) {
      const a = Math.max(Math.abs(c.h), Math.abs(c.l));
      if (a > priceMax) priceMax = a;
    }
    priceMax = priceMax > 0 ? priceMax : 1;
    const indicatorsObj = (indicators && typeof indicators === 'object')
        ? indicators
        : {};
    const isScaleMismatch = (col) => {
      const series = indicatorsObj[col.key];
      if (!Array.isArray(series)) return false;
      let maxAbs = 0;
      for (const v of series) {
        if (typeof v === 'number' && isFinite(v)) {
          const a = Math.abs(v);
          if (a > maxAbs) maxAbs = a;
        }
      }
      return maxAbs > priceMax * 5;
    };
    const subKeys = new Set();
    const allCols = Array.isArray(columns) ? columns : [];
    for (const c of allCols) {
      if (!c || c.kind !== 'float') continue;
      if (c.sub_panel === true || isScaleMismatch(c)) subKeys.add(c.key);
    }
    // Inject pseudo-indicators for sub-pane columns so the existing
    // sub-pane layout + axis + hover-overlay machinery handles them with
    // zero duplication. Kind='explain' is registered in SUB_KINDS and
    // routes through `_drawExplainSubPane` + `_subPaneRange`'s 'explain'
    // case. Replace (don't append) so navigating between explain views
    // doesn't pile pseudo-indicators on top of each other.
    const subCols = allCols.filter((c) => c && subKeys.has(c.key));
    this._indicators = subCols.map((c, i) => ({
      id: 'explain-' + (c.key || i),
      kind: 'explain',
      color: (typeof c.color_hint === 'string' && c.color_hint)
          ? c.color_hint
          : '#F59E0B',
      label: c.label || c.key || ('Indicator ' + (i + 1)),
      explainKey: c.key,
      hidden: false,
      params: {},
    }));
    // Stash the resolved sub-pane key set so `_drawExplainOverlays` can
    // skip these on the main pane (they're now drawn in their sub-pane).
    this._explainPayload.subKeys = subKeys;
    // Pseudo-scrip so existing render paths that read this.scrip (OHLC
    // strip header, axis price chips, etc.) don't see null. Daily bars on
    // NSE equities → tick size 0.05 is the safe default.
    const safeTicker = typeof ticker === 'string' ? ticker : '';
    const safeName = typeof displayName === 'string' && displayName
        ? displayName
        : (safeTicker || 'Explanation');
    this.scrip = {
      exch: 'NSE',
      token: '',
      tsym: safeTicker,
      dispName: safeName,
      ti: 0.05,
      ls: 1,
    };
    this._scripTradable = false; // suppresses the LTP plus button in lite mode
    // Fit-all + reset pan so the user lands on the full window. Without
    // this, a fresh explain payload would sit at the chart's previous
    // offset and look blank until the user manually fit-resets.
    this.view = {
      ...this.view,
      offsetX: 0,
      autoFollow: true,
      autoFitY: true,
      priceCenter: null,
      pricePerPx: null,
    };
    this.scheduleRedraw();
  }

  // Two-layer palette. setTheme replaces `_basePalette` with the theme's
  // built-in colours; the Customize tab overlays `_customPalette` on top.
  // setPalette accepts EITHER a full theme palette (old API — has
  // background `bg`, `crosshair`, etc) OR a sparse Customize-tab map
  // (keys like bullBody, bearBody, background, text, grid). We detect
  // which by checking for the full-theme `bg` field — if it exists it's
  // a base swap; otherwise it's a Customize overlay.
  setPalette(palette) {
    if (palette && typeof palette === 'object' && palette.bg !== undefined) {
      this._basePalette = palette;
    } else if (palette && typeof palette === 'object') {
      this._customPalette = palette;
    }
    this.palette = this._mergedPalette();
    this.scheduleRedraw();
  }

  // Compose the effective palette by overlaying Customize-tab overrides
  // onto the base theme. Empty / missing customize keys fall through to
  // the base so the user can re-show theme defaults by clearing a field.
  _mergedPalette() {
    const base = this._basePalette || this.palette || {};
    const cust = this._customPalette || {};
    const out = Object.assign({}, base);
    // Customize-tab key → palette key mapping. Empty strings are skipped.
    const pick = (v) => (typeof v === 'string' && v.length > 0) ? v : null;
    const bullBody = pick(cust.bullBody);
    const bearBody = pick(cust.bearBody);
    const bullWick = pick(cust.bullWick);
    const bearWick = pick(cust.bearWick);
    const background = pick(cust.background);
    const text = pick(cust.text);
    const grid = pick(cust.grid);
    const crosshair = pick(cust.crosshair);
    if (bullBody) { out.bull = bullBody; out.bullSoft = _hexToRgba(bullBody, 0.5); }
    if (bearBody) { out.bear = bearBody; out.bearSoft = _hexToRgba(bearBody, 0.5); }
    if (bullWick) out.bullWick = bullWick;
    if (bearWick) out.bearWick = bearWick;
    if (background) { out.bg = background; out.crosshairChip = background; }
    if (text) { out.axisText = text; out.axisTextStrong = text; out.ohlcValue = text; }
    if (grid) { out.gridSoft = grid; out.gridStrong = grid; }
    if (crosshair) out.crosshair = crosshair;
    return out;
  }

  setQty(qty) {
    const q = Number.isFinite(qty) ? Math.max(1, Math.trunc(qty)) : 1;
    if (q === this.qty) return;
    this.qty = q;
    this.scheduleRedraw();
  }

  // ── Public view controls (driven by the floating pane button bar) ──────
  // Same math as the wheel handler but exposed as discrete callable
  // actions so the chart-engine.js layer can wire HTML buttons to them.
  zoomIn() {
    this.view.cellW = Math.max(4, Math.min(60, this.view.cellW * 1.2));
    this.view.autoFollow = false;
    this.scheduleRedraw();
  }
  zoomOut() {
    this.view.cellW = Math.max(4, Math.min(60, this.view.cellW * 0.85));
    this.view.autoFollow = false;
    this.scheduleRedraw();
  }
  panLeft() {
    // Positive offsetX shifts the row right → older candles slide in
    // from the left edge (i.e. visual pan-left).
    this.view.offsetX = (this.view.offsetX || 0) + this.view.cellW * 5;
    this.view.autoFollow = false;
    this.scheduleRedraw();
  }
  panRight() {
    this.view.offsetX = (this.view.offsetX || 0) - this.view.cellW * 5;
    this.view.autoFollow = false;
    this.scheduleRedraw();
  }
  fitVisible() {
    // Re-fit Y axis to the currently visible candles without resetting X.
    this.view.priceCenter = null;
    this.view.pricePerPx = null;
    this.view.autoFitY = true;
    this.scheduleRedraw();
  }
  resetView() {
    // Full reset — most-recent candles, default zoom, auto Y fit.
    this.view.offsetX = 0;
    this.view.priceCenter = null;
    this.view.pricePerPx = null;
    this.view.autoFollow = true;
    this.view.autoFitY = true;
    this.scheduleRedraw();
  }

  setPaneOverlays(list) {
    const next = Array.isArray(list) ? list : [];
    if (this._pendingOverlayMoves.size > 0) {
      const now = Date.now();
      const tick = (this.scrip && this.scrip.ti && this.scrip.ti > 0) ? this.scrip.ti : 0.05;
      for (const ov of next) {
        const pending = this._pendingOverlayMoves.get(ov.id);
        if (!pending) continue;
        if (now > pending.expiresAt) {
          // Server didn't confirm in time — give up and accept server state.
          this._pendingOverlayMoves.delete(ov.id);
          continue;
        }
        if (typeof ov.price === 'number' &&
            Math.abs(ov.price - pending.price) < tick * 0.5) {
          // Server now reports our optimistic price — accept and clear.
          this._pendingOverlayMoves.delete(ov.id);
        } else if (typeof ov.price === 'number') {
          // Still mid-roundtrip — keep showing the optimistic price.
          ov.price = pending.price;
        }
      }
      // Drop any pending entries whose overlay no longer exists in the
      // server list (e.g. order cancelled while we were dragging — let it go).
      for (const id of Array.from(this._pendingOverlayMoves.keys())) {
        if (!next.some((ov) => ov.id === id)) {
          this._pendingOverlayMoves.delete(id);
        }
      }
    }
    this._overlays = next;
    this.scheduleRedraw();
  }

  // Phase 7 — replace the committed drawings for this pane's current scrip.
  setDrawings(list) {
    this._drawings = Array.isArray(list) ? list : [];
    this.scheduleRedraw();
  }

  // Phase 8 — replace the technical-indicator list for this pane.
  setIndicators(list) {
    this._indicators = Array.isArray(list) ? list : [];
    // Drop manual-view entries for indicators that no longer exist, so the
    // map doesn't accumulate stale ids across edits.
    if (this._subPaneView) {
      const liveIds = new Set(this._indicators.map((i) => i.id));
      for (const id of Object.keys(this._subPaneView)) {
        if (!liveIds.has(id)) delete this._subPaneView[id];
      }
    }
    this.scheduleRedraw();
  }

  // Phase 7 — toggle draw mode. Null exits; 'hline' / 'trendline' / 'rect' / 'hray' enters.
  // Phase 21 — extended to include 'fib' and 'path'.
  setDrawMode(kind) {
    // `measure` (ephemeral) and `path` (freehand polyline) keep bespoke
    // placement; every other tool is declared in the registry.
    const LEGACY = new Set(['measure', 'path']);
    const valid = LEGACY.has(kind) ||
        Object.prototype.hasOwnProperty.call(DRAWING_TOOLS, kind);
    const next = valid ? kind : null;
    this._drawMode = next;
    this._inProgressDrawing = null;
    // Picking a DIFFERENT tool clears the one-shot measurement, but
    // exiting to null (which happens AUTOMATICALLY right after Measure
    // commits via _exitDrawMode) must NOT — otherwise the user never gets
    // to see the measure they just placed. Click-outside on the canvas
    // (handled in the mousedown empty-area branch) is what dismisses it.
    if (next != null && next !== 'measure') {
      this._activeMeasure = null;
    }
    // Phase 20 — visual feedback: cursor becomes a crosshair while a draw
    // tool is active so the user knows they're in draw mode.
    try {
      if (this.canvas) {
        this.canvas.style.cursor = this._drawMode ? 'crosshair' : '';
      }
    } catch (_) {}
    this.scheduleRedraw();
  }

  // Auto-exit draw mode (after commit / cancel) AND tell Flutter so the
  // top-bar Draw button toggles off. Without this notification, Flutter
  // kept showing "Drawing: Rectangle" active while JS had already cleared
  // its draw mode — the next click on the canvas did nothing because the
  // tool was already disarmed, leaving the user stuck.
  _exitDrawMode() {
    this._drawMode = null;
    this._inProgressDrawing = null;
    try { if (this.canvas) this.canvas.style.cursor = ''; } catch (_) {}
    // Reuse the existing shell handler that clears `activeDrawTool` on
    // the Flutter side — same as ESC-from-inside-iframe.
    try {
      parent.postMessage(JSON.stringify({
        type: 'drawModeCancelled',
        value: { paneId: this.paneId },
      }), '*');
    } catch (_) {}
  }

  setShortcutsEnabled(enabled) {
    this._shortcutsEnabled = enabled === true;
  }

  unpinCrosshair() {
    if (!this._pinnedHover) return;
    this._pinnedHover = null;
    this.scheduleRedraw();
  }

  setOverlays(flags) {
    if (typeof flags.gridlines === 'boolean') this.overlays.gridlines = flags.gridlines;
    if (typeof flags.volume === 'boolean') this.overlays.volume = flags.volume;
    this.scheduleRedraw();
  }

  setCandleStyle(style) {
    const valid = new Set(['candles','hollow','bars','line','area','heikin-ashi',
      'renko','baseline','step','columns','hlcbars','highlow','hlcarea',
      'volcandles','linebreak','kagi','range','pnf']);
    const next = valid.has(style) ? style : 'candles';
    if (next === this.candleStyle) return;
    const wasRenko = this.candleStyle === 'renko';
    const wasRebin = this._isRebinnedStyle(this.candleStyle);
    this.candleStyle = next;
    // Always reset HA cache so it starts clean on the next draw.
    this._haPrev = null;
    if (next === 'renko') {
      if (typeof this._rebuildRenko === 'function') {
        this._rebuildRenko();
        this._notifyBrickSize(this._renkoBrickSize);
      } else {
        // Phase 16 transitional: F1 hasn't shipped yet — leave bricks empty,
        // tell Flutter we don't know the brick size.
        this._renkoBricks = [];
        this._renkoBrickSize = 0;
        this._notifyBrickSize(0);
      }
    } else {
      this._renkoBricks = [];
      this._renkoBrickSize = 0;
      if (wasRenko) this._notifyBrickSize(0); // tell Flutter to clear the subtitle
    }
    // Phase 26 — rebinned (non-renko) styles maintain their own pseudo-candle
    // array (this._rebinned). Rebuild it when switching INTO such a style,
    // and clear it otherwise so _seriesLength() falls back to raw candles.
    if (this._isRebinnedStyle(next)) {
      this._rebuildRebinned();
    } else {
      this._rebinned = [];
      this._rebinnedStyle = null;
    }
    // Switching to/from a rebinned style (or between rebinned types) changes the
    // column COUNT drastically — Range / P&F produce far more columns than the
    // raw candle count. The previous pan/zoom would then push the whole series
    // off-screen (looks blank). Reset the horizontal pan + re-enable auto-fit so
    // the latest columns are visible.
    if (wasRenko || wasRebin || this._isRebinnedStyle(next)) {
      this.view.offsetX = 0;
      this.view.priceCenter = null; // re-arm vertical auto-fit
    }
    this.scheduleRedraw();
  }

  setShowHighLowMarkers(show) {
    const v = show === true;
    if (v === this.showHighLowMarkers) return;
    this.showHighLowMarkers = v;
    this.scheduleRedraw();
  }

  // Phase 18 — option-chain OI bars + LTP bar-close countdown setters.
  setShowOptionChainOi(show) {
    const v = show === true;
    if (v === this.showOptionChainOi) return;
    this.showOptionChainOi = v;
    this.scheduleRedraw();
  }

  setShowBarCountdown(show) {
    const v = show === true;
    if (v === this.showBarCountdown) return;
    this.showBarCountdown = v;
    this._updateSecondTimer();
    this.scheduleRedraw();
  }

  setShowKeyLevels(show) {
    const v = show === true;
    if (v === this.showKeyLevels) return;
    this.showKeyLevels = v;
    this.scheduleRedraw();
  }

  // Phase 23.1 — pivot variant setter.
  setPivotVariant(variant) {
    const valid = new Set(['classical', 'fibonacci', 'camarilla']);
    const next = valid.has(variant) ? variant : 'classical';
    if (next === this.pivotVariant) return;
    this.pivotVariant = next;
    this.scheduleRedraw();
  }

  // Phase 23.2 — magnet snap setter.
  setMagnetEnabled(enabled) {
    const v = enabled === true;
    if (v === this.magnetEnabled) return;
    this.magnetEnabled = v;
    this.scheduleRedraw();
  }

  // Phase 23.3 — drawing lock + hide-all setters.
  setDrawingsLocked(locked) {
    const v = locked === true;
    if (v === this.drawingsLocked) return;
    this.drawingsLocked = v;
    this.scheduleRedraw();
  }

  setDrawingsHidden(hidden) {
    const v = hidden === true;
    if (v === this.drawingsHidden) return;
    this.drawingsHidden = v;
    this.scheduleRedraw();
  }

  // Phase 23.4 — volume profile setter.
  setShowVolumeProfile(show) {
    const v = show === true;
    if (v === this.showVolumeProfile) return;
    this.showVolumeProfile = v;
    this.scheduleRedraw();
  }

  // Phase 25 — auto-pattern (swing pivot markers + HH/HL/LH/LL labels) setter.
  setShowAutoPattern(show) {
    const v = show === true;
    if (v === this.showAutoPattern) return;
    this.showAutoPattern = v;
    this.scheduleRedraw();
  }

  setShowCrosshairLines(show) {
    const v = show !== false;  // default true if undefined
    if (v === this.showCrosshairLines) return;
    this.showCrosshairLines = v;
    this.scheduleRedraw();
  }

  setOiData(strikes) {
    this._oiData = Array.isArray(strikes) ? strikes : [];
    this.scheduleRedraw();
  }

  // Phase 25 — export the canvas as a PNG dataURL and post it to Flutter.
  takeScreenshot() {
    try {
      const dataUrl = this.canvas.toDataURL('image/png');
      const filename = (this.scrip ? this.scrip.dispName : 'chart')
          .replace(/[^a-zA-Z0-9_-]+/g, '_') + '_' +
          new Date().toISOString().slice(0, 19).replace(/[:-]/g, '') + '.png';
      parent.postMessage(JSON.stringify({
        type: 'chartScreenshot',
        value: { paneId: this.paneId, dataUrl, filename },
      }), '*');
    } catch (e) {
      // taintedCanvas should be impossible (everything is locally drawn) but
      // catch defensively.
    }
  }

  _updateSecondTimer() {
    // Only the countdown needs 1Hz redraws — OI data updates via Flutter push.
    const needsTimer = this.showBarCountdown;
    if (needsTimer && !this._secondTimer) {
      this._secondTimer = setInterval(() => this.scheduleRedraw(), 1000);
    } else if (!needsTimer && this._secondTimer) {
      clearInterval(this._secondTimer);
      this._secondTimer = null;
    }
  }

  ingestTick(packet) {
    if (!this.scrip) return;
    // packet is the raw WS payload forwarded by Flutter. Keys we use:
    //   lp (last price), v (cum volume), ft (epoch seconds).
    // Some packets carry partial updates — merge into our running tickState
    // before handing to the aggregator (same merge pattern as orderflow).
    const lp = packet.lp != null ? +packet.lp : null;
    const v = packet.v != null ? +packet.v : null;
    const ft = packet.ft != null ? +packet.ft : null;
    if (lp != null) this.tickState.lp = lp;
    if (v != null) this.tickState.v = v;
    if (ft != null) this.tickState.ft = ft;
    const bid = packet.bp1 != null ? +packet.bp1 : null;
    const ask = packet.sp1 != null ? +packet.sp1 : null;
    let bidAskChanged = false;
    if (bid != null && bid !== this.tickState.bid) { this.tickState.bid = bid; bidAskChanged = true; }
    if (ask != null && ask !== this.tickState.ask) { this.tickState.ask = ask; bidAskChanged = true; }
    if (bidAskChanged) this.scheduleRedraw();
    // Open interest — only present on futures/options touchline packets.
    // Drives the OI segment appended to the OHLC strip for futures.
    const oi = packet.oi != null ? +packet.oi : null;
    if (oi != null && oi !== this.tickState.oi) {
      this.tickState.oi = oi;
      this.scheduleRedraw();
    }
    // Phase 24 — `lp` is the only required field. Indices (NIFTY 50 / SENSEX)
    // don't carry `v` (no traded volume on a calculated index) and often
    // don't carry `ft` either. Without synthesised defaults the aggregator
    // never fires for indices and the chart shows a frozen LTP. Synthesise
    // `v=0` and `ft=now` so the bar's close updates from `lp` regardless.
    // Mark the tickState as `_lpOnly` so the aggregator bypasses its
    // volume-delta gate (which would otherwise skip every tick because
    // dv = 0 - 0 = 0 on every index tick).
    //
    // Phase 24.5 — broker sends `v: '0'` for indices (not null), so
    // `v == null` alone misses them. Treat `v === 0` the same as null —
    // both mean "no real volume on this instrument right now". Stocks at
    // session-open with v=0 briefly land in lpOnly mode too, which is
    // harmless (close updates either way; volume tracking just doesn't
    // accumulate until the first non-zero tick).
    if (this.tickState.lp == null) return;
    if (v == null || v === 0) {
      this.tickState.v = 0;
      this.tickState._lpOnly = true;
    } else {
      this.tickState._lpOnly = false;
    }
    if (this.tickState.ft == null) {
      this.tickState.ft = Math.floor(Date.now() / 1000);
    }
    // Skip ticks outside the exchange's trading hours so no out-of-session
    // candle is formed (pre-open, lunch, post-close, weekends). Bid/ask was
    // already updated above so the header strip still reflects the latest
    // book even when we're skipping aggregation.
    if (!this._isWithinTradingHours(this.tickState.ft)) return;
    const targetMs = this.timeframeMinutes * 60_000;
    const result = ingestTickIntoBucket(
        this.candles, this.tickState, this.aggState, targetMs);
    if (result === 'applied') {
      this._lastTickAt = Date.now();
      // Phase 26 — rebinned styles re-derive their pseudo-candle array from the
      // (now-updated) candles whenever a tick is applied. Cheap relative to the
      // redraw and keeps panning/scaling consistent with the raw series.
      if (this._isRebinnedStyle(this.candleStyle)) {
        this._rebuildRebinned();
      }
      this.scheduleRedraw();
    }
    // Renko tick update — use the same price that drives bar commits (tickState.lp).
    if (typeof this.tickState.lp === 'number') {
      this._updateRenkoFromTick(this.tickState.lp);
    }
  }

  onHistoryResult(requestId, candles) {
    // Extend reply — prepend instead of replace. Empty page = no more history.
    if (requestId === this._pendingExtendId) {
      this._pendingExtendId = null;
      if (!Array.isArray(candles) || candles.length === 0) {
        this._noMoreHistory = true;
        return;
      }
      const inSession = candles.filter(
          (c) => this._isWithinTradingHours(c.ts));
      const fresh = bucketCandles(inSession, this.timeframeMinutes);
      if (fresh.length === 0) {
        this._noMoreHistory = true;
        return;
      }
      const oldestExistingTs = this.candles.length > 0
          ? this.candles[0].ts
          : Infinity;
      const merged = fresh.filter((c) => c.ts < oldestExistingTs);
      if (merged.length === 0) {
        this._noMoreHistory = true;
        return;
      }
      // No offsetX compensation needed. The xCenter formula uses
      //   xCenter(i) = plot.right - (N - 1 - i + 0.5) * cellW + offsetX
      // i.e. position-from-the-right. Prepending M candles shifts every
      // existing absolute index by +M, and N grows by +M, so (N-1-i) is
      // unchanged for the existing candles. Touching offsetX here was the
      // bug — it visibly jumped the chart toward the newest bar each time
      // a top-up arrived.
      this.candles = merged.concat(this.candles);
      if (this.candleStyle === 'renko') {
        this._rebuildRenko();
        this._notifyBrickSize(this._renkoBrickSize);
      } else if (this._isRebinnedStyle(this.candleStyle)) {
        this._rebuildRebinned();
      }
      this.scheduleRedraw();
      return;
    }
    if (requestId !== this._pendingRequestId) return; // stale reply
    this._pendingRequestId = null;
    this._hideOverlay();
    if (!Array.isArray(candles) || candles.length === 0) {
      this._showOverlay('No history available');
      return;
    }
    // Filter out-of-session candles BEFORE bucketing — if the historical
    // feed returned any (rare for tpseries, common for some brokers), they'd
    // create gaps and confuse the time axis. Bucketing then collapses any
    // remaining same-bucket candles correctly.
    const inSession = candles.filter(
        (c) => this._isWithinTradingHours(c.ts));
    this.candles = bucketCandles(inSession, this.timeframeMinutes);
    this._noMoreHistory = false;  // fresh series — extend is allowed again
    if (this.candleStyle === 'renko') {
      this._rebuildRenko();
      this._notifyBrickSize(this._renkoBrickSize);
    } else if (this._isRebinnedStyle(this.candleStyle)) {
      this._rebuildRebinned();
    }
    this.scheduleRedraw();
    if (this.scrip) this.subscribe({ exch: this.scrip.exch, token: this.scrip.token });
  }

  // Pan-triggered extend. Fires when the leftmost visible candle is within
  // 20 bars of the array start, throttled to one in-flight at a time + a
  // 500ms cooldown. Asks for a window of older data starting from the
  // currently-oldest candle's ts going back by the same window the initial
  // load used.
  _maybeExtendHistory() {
    if (!this.scrip) return;
    if (this._noMoreHistory) return;
    if (this._pendingExtendId != null) return;
    if (this._pendingRequestId != null) return;
    if (Date.now() < this._extendBlockedUntil) return;
    if (this.candles.length === 0) return;

    const N = this._seriesLength();
    const W = this.view.cellW;
    const O = this.view.offsetX;
    const left = 8;
    const right = this.canvas.clientWidth - 64;
    const iMin = Math.max(0, Math.ceil(N - 0.5 - (right - left + O) / W));
    if (iMin > 20) return;  // still buffered — no need to fetch yet

    const oldestTs = this.candles[0].ts;
    const minutes = this.timeframeMinutes;
    const interval = SOURCE_INTERVAL_FOR_MINUTES(minutes);
    const windowSec = _windowSecondsFor(minutes);
    const endEpoch = oldestTs - 1;
    const startEpoch = endEpoch - windowSec;
    if (startEpoch <= 0 || endEpoch <= 0) return;

    this._pendingExtendId = _newRequestId();
    this._extendBlockedUntil = Date.now() + 500;
    this.requestHistory({
      requestId: this._pendingExtendId,
      exch: this.scrip.exch,
      token: this.scrip.token,
      tsym: this.scrip.tsym,
      interval,
      start: startEpoch,
      end: endEpoch,
      targetMinutes: minutes,
    });
  }

  onHistoryError(requestId, message) {
    if (requestId !== this._pendingRequestId) return;
    this._pendingRequestId = null;
    const name = this.scrip ? this.scrip.dispName : 'symbol';
    this._showOverlay('Could not load history for ' + name,
        String(message || 'Network error') + ' · click chart to retry');
    this.container.addEventListener('click', this._retryOnce, { once: true });
  }

  _retryOnce = () => {
    this._hideOverlay();
    this._loadHistory();
  };

  destroy() {
    if (this.scrip) this.unsubscribe({ exch: this.scrip.exch, token: this.scrip.token });
    this._ro.disconnect();
    clearInterval(this._stalenessTicker);
    clearInterval(this._advanceBarsTicker);
    if (this._secondTimer) { clearInterval(this._secondTimer); this._secondTimer = null; }
    if (this._loadHistoryScheduled) {
      clearTimeout(this._loadHistoryScheduled);
      this._loadHistoryScheduled = null;
    }
    this.container.removeChild(this.canvas);
  }

  // --- Internal helpers ---------------------------------------------------
  _resetData() {
    this.candles = [];
    this.tickState = { lp: null, v: null, ft: null, bid: null, ask: null, oi: null };
    this.aggState = { prevCumVol: null, prevPrice: null, prevMs: null };
    this.view.priceCenter = null;
    this.view.pricePerPx = null;
    this.view.offsetX = 0;
    this.view.autoFollow = true;
    this.view.autoFitY = true;
    this._pendingExtendId = null;
    this._extendBlockedUntil = 0;
    this._noMoreHistory = false;
  }

  _loadHistory() {
    // Coalesce rapid successive calls (e.g., setSymbol immediately followed by
    // setTimeframe during the shell's per-pane push pipeline) into a single
    // fetch. The macrotask delay (timeout 0) lets all synchronous setters run
    // first; we fire ONE history request with the final symbol + timeframe.
    if (this._loadHistoryScheduled) clearTimeout(this._loadHistoryScheduled);
    this._loadHistoryScheduled = setTimeout(() => {
      this._loadHistoryScheduled = null;
      this._loadHistoryNow();
    }, 0);
  }

  _loadHistoryNow() {
    if (!this.scrip) return;
    this._showOverlay('Loading ' + this.scrip.dispName + '…');
    const minutes = this.timeframeMinutes;
    const interval = SOURCE_INTERVAL_FOR_MINUTES(minutes);
    const endEpoch = Math.floor(Date.now() / 1000);
    const startEpoch = endEpoch - _windowSecondsFor(minutes);
    this._pendingRequestId = _newRequestId();
    this.requestHistory({
      requestId: this._pendingRequestId,
      exch: this.scrip.exch,
      token: this.scrip.token,
      tsym: this.scrip.tsym,
      interval,
      start: startEpoch,
      end: endEpoch,
      targetMinutes: minutes,
    });
  }

  _showOverlay(title, detail) {
    this._loadingTitle = title || '';
    this._loadingDetail = detail || '';
    this.scheduleRedraw();
  }
  _hideOverlay() {
    if (this._loadingTitle == null) return;
    this._loadingTitle = null;
    this._loadingDetail = null;
    this.scheduleRedraw();
  }

  resize() {
    const w = this.container.clientWidth;
    const h = this.container.clientHeight;
    if (w === 0 || h === 0) return;
    this.dpr = window.devicePixelRatio || 1;
    this.canvas.width = Math.floor(w * this.dpr);
    this.canvas.height = Math.floor(h * this.dpr);
    this.canvas.style.width = w + 'px';
    this.canvas.style.height = h + 'px';
    this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    // Setting canvas.width/height blanks the buffer. During splitter drag
    // ResizeObserver may fire many times per rAF tick, so a scheduled redraw
    // can leave the canvas momentarily black. Paint synchronously instead.
    this.draw();
  }

  _attachInteraction() {
    const wrap = this.container;
    wrap.addEventListener('mousedown', (e) => {
      // Notify parent so it can mark this pane as active. Fire on every
      // mousedown, even ones that don't end in a drag.
      try {
        parent.postMessage(
            JSON.stringify({ type: 'paneActivated', value: { paneId: this.paneId } }),
            '*');
      } catch (_) {}
      const rect = wrap.getBoundingClientRect();
      const x = e.clientX - rect.left, y = e.clientY - rect.top;

      // Any fresh mousedown inside the chart clears a pinned crosshair —
      // it'll be re-set below if this click was on the `+` icon.
      if (this._pinnedHover) {
        this._pinnedHover = null;
        this.scheduleRedraw();
      }

      // --- Indicator chip strip (top of chart): eye toggle + delete X ---
      // Checked first so chip clicks always win over chart pan/zoom.
      for (const h of this._indicatorChipHits) {
        const r = h.rect;
        if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
          e.preventDefault();
          e.stopPropagation();
          if (h.action === 'toggleCollapse') {
            this._indicatorChipsCollapsed = !this._indicatorChipsCollapsed;
            try {
              window.localStorage.setItem(
                  'chartEngineIndChipsCollapsed_' + this.paneId,
                  this._indicatorChipsCollapsed ? '1' : '0');
            } catch (_) {}
            this.scheduleRedraw();
            return;
          }
          if (h.action === 'toggleHide') {
            const ind = this._indicators.find((i) => i.id === h.indicatorId);
            if (!ind) return;
            ind.hidden = !ind.hidden;
            try {
              parent.postMessage(JSON.stringify({
                type: 'indicatorVisibilityToggled',
                value: {
                  paneId: this.paneId,
                  indicatorId: h.indicatorId,
                  hidden: ind.hidden,
                },
              }), '*');
            } catch (_) {}
          } else if (h.action === 'delete') {
            this._indicators = this._indicators
                .filter((i) => i.id !== h.indicatorId);
            try {
              parent.postMessage(JSON.stringify({
                type: 'indicatorRemoved',
                value: {
                  paneId: this.paneId,
                  indicatorId: h.indicatorId,
                },
              }), '*');
            } catch (_) {}
          } else if (h.action === 'openSettings') {
            try {
              parent.postMessage(JSON.stringify({
                type: 'indicatorSettingsRequested',
                value: {
                  paneId: this.paneId,
                  indicatorId: h.indicatorId,
                },
              }), '*');
            } catch (_) {}
          }
          this.scheduleRedraw();
          return;
        }
      }

      // --- Phase 10: color swatch click (selected-drawing palette) ---
      // Checked before delete chip + drag band so a swatch click always wins.
      for (const h of this._colorSwatchHits) {
        const r = h.rect;
        if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
          e.preventDefault();
          e.stopPropagation();
          try {
            parent.postMessage(JSON.stringify({
              type: 'drawingColorChanged',
              value: {
                paneId: this.paneId,
                drawingId: h.drawingId,
                color: h.color,
              },
            }), '*');
          } catch (_) {}
          // Optimistic local update for instant feedback.
          const d = this._drawings.find((dd) => dd.id === h.drawingId);
          if (d) d.color = h.color;
          // Color picked from the popup → close it.
          this._toolbarPopup = null;
          this.scheduleRedraw();
          return;
        }
      }

      // --- Phase 7: delete-chip hit on an existing drawing ---
      // Phase 23.3 — skip delete + drag hit-tests entirely when drawings locked.
      if (!this.drawingsLocked) {
        for (const h of this._drawingHits) {
          if (h.action !== 'delete') continue;
          const r = h.rect;
          if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
            const target = this._drawings.find((dd) => dd.id === h.drawingId);
            if (target && target.locked) {
              // Locked drawings ignore delete clicks — user must unlock first.
              e.preventDefault();
              e.stopPropagation();
              return;
            }
            e.preventDefault();
            e.stopPropagation();
            // Optimistically remove locally for instant feedback; Flutter will
            // re-push the canonical list on the next _pushSession tick.
            this._drawings = this._drawings.filter((d) => d.id !== h.drawingId);
            // Clear selection if it pointed at the deleted drawing.
            if (this._selectedDrawingId === h.drawingId) {
              this._selectedDrawingId = null;
            }
            try {
              parent.postMessage(JSON.stringify({
                type: 'drawingDeleted',
                value: { paneId: this.paneId, drawingId: h.drawingId },
              }), '*');
            } catch (_) {}
            this.scheduleRedraw();
            return;
          }
        }

        // --- Inline-toolbar: open Color popup ---
        for (const h of this._drawingHits) {
          if (h.action !== 'openColor') continue;
          const r = h.rect;
          if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
            e.preventDefault();
            e.stopPropagation();
            const open = this._toolbarPopup;
            if (open && open.drawingId === h.drawingId &&
                open.kind === 'color') {
              this._toolbarPopup = null;
            } else {
              this._toolbarPopup = {
                drawingId: h.drawingId,
                kind: 'color',
                anchorX: h.anchorX,
              };
            }
            this.scheduleRedraw();
            return;
          }
        }

        // --- Inline-toolbar: open Stroke popup ---
        for (const h of this._drawingHits) {
          if (h.action !== 'openStroke') continue;
          const r = h.rect;
          if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
            e.preventDefault();
            e.stopPropagation();
            const open = this._toolbarPopup;
            if (open && open.drawingId === h.drawingId &&
                open.kind === 'stroke') {
              this._toolbarPopup = null;
            } else {
              this._toolbarPopup = {
                drawingId: h.drawingId,
                kind: 'stroke',
                anchorX: h.anchorX,
              };
            }
            this.scheduleRedraw();
            return;
          }
        }

        // --- Inline-toolbar: set Thickness from stroke popup row ---
        for (const h of this._drawingHits) {
          if (h.action !== 'setThickness') continue;
          const r = h.rect;
          if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
            e.preventDefault();
            e.stopPropagation();
            const target =
                this._drawings.find((dd) => dd.id === h.drawingId);
            if (target) target.thickness = h.thickness;
            this._toolbarPopup = null;
            try {
              parent.postMessage(JSON.stringify({
                type: 'drawingThicknessChanged',
                value: {
                  paneId: this.paneId,
                  drawingId: h.drawingId,
                  thickness: h.thickness,
                },
              }), '*');
            } catch (_) {}
            this.scheduleRedraw();
            return;
          }
        }

        // --- Inline-toolbar: duplicate ---
        for (const h of this._drawingHits) {
          if (h.action !== 'duplicate') continue;
          const r = h.rect;
          if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
            e.preventDefault();
            e.stopPropagation();
            const src = this._drawings.find((dd) => dd.id === h.drawingId);
            if (!src) return;
            // Offset clone — 5 candles right + 0.5% price down so the copy
            // doesn't sit exactly on top of the original.
            const tsShift = (this.timeframeMinutes || 1) * 60 * 5;
            const priceShift = (src.points[0] && src.points[0].price)
                ? src.points[0].price * 0.005
                : 0;
            const clone = {
              id: 'd-' + Date.now().toString(36) + '-' +
                  Math.random().toString(36).slice(2, 8),
              kind: src.kind,
              color: src.color,
              points: src.points.map((p) => ({
                ts: (p.ts || 0) + tsShift,
                price: (p.price || 0) - priceShift,
              })),
              locked: false,
            };
            this._drawings.push(clone);
            this._selectedDrawingId = clone.id;
            try {
              parent.postMessage(JSON.stringify({
                type: 'drawingCommitted',
                value: { paneId: this.paneId, drawing: clone },
              }), '*');
            } catch (_) {}
            this.scheduleRedraw();
            return;
          }
        }

        // --- Inline-toolbar: lock toggle ---
        for (const h of this._drawingHits) {
          if (h.action !== 'lockToggle') continue;
          const r = h.rect;
          if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
            e.preventDefault();
            e.stopPropagation();
            const target = this._drawings.find((dd) => dd.id === h.drawingId);
            if (!target) return;
            const nextLocked = !target.locked;
            target.locked = nextLocked;
            try {
              parent.postMessage(JSON.stringify({
                type: 'drawingLockToggled',
                value: {
                  paneId: this.paneId,
                  drawingId: h.drawingId,
                  locked: nextLocked,
                },
              }), '*');
            } catch (_) {}
            this.scheduleRedraw();
            return;
          }
        }

        // --- Phase 30: anchor-handle hit → start single-point reshape ---
        // Checked BEFORE the body drag-band so grabbing an endpoint reshapes
        // (extends) the drawing instead of translating the whole thing.
        if (!this._drawMode) {
          for (const h of this._drawingHandleHits) {
            const r = h.rect;
            if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
              const target = this._drawings.find((dd) => dd.id === h.drawingId);
              if (target && !target.locked) {
                e.preventDefault();
                e.stopPropagation();
                this._selectedDrawingId = h.drawingId;
                this._dragHandleId = h.drawingId;
                this._dragHandleIndex = h.pointIndex;
                this._dragHandleMoved = false;
                this.scheduleRedraw();
                return;
              }
            }
          }
        }

        // --- Phase 10: drawing line-band hit → select + start drag-to-move ---
        // Only consider drag hits when we're NOT in draw-mode (placement) so
        // the user can still click on top of an existing drawing to add a new
        // one in the same area.
        if (!this._drawMode) {
          for (const h of this._drawingHits) {
            if (h.action !== 'drag') continue;
            const r = h.rect;
            if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
              e.preventDefault();
              e.stopPropagation();
              const target = this._drawings.find((dd) => dd.id === h.drawingId);
              const isLocked = target && target.locked;
              this._selectedDrawingId = h.drawingId;
              if (!isLocked) {
                this._dragDrawingId = h.drawingId;
                this._dragDrawingStartPoints = target
                    ? target.points.map((p) => ({ price: p.price, ts: p.ts }))
                    : null;
                this._dragStartClientX = e.clientX;
                this._dragStartClientY = e.clientY;
                this._dragDrawingMoved = false;
              }
              this.scheduleRedraw();
              return;
            }
          }
        }
      }

      // --- Phase 7: draw-mode placement (suppresses pan / overlay paths) ---
      if (this._drawMode) {
        e.preventDefault();
        e.stopPropagation();
        let price = this._snapPrice(this._yToPriceForDrag(y));
        let ts = this._xToTs(x);
        // Phase 23.2 — Magnet snap: when enabled, snap to the nearest OHLC
        // value of the candle under the cursor if within 8 pixels.
        if (this.magnetEnabled && this.candles.length > 0) {
          const candleIdx = this._candleAtX(x);
          if (candleIdx >= 0 && candleIdx < this.candles.length) {
            const mc = this.candles[candleIdx];
            ts = mc.ts;
            const targets = [
              { v: mc.o },
              { v: mc.h },
              { v: mc.l },
              { v: mc.c },
            ];
            let bestPrice = price;
            let bestDy = 8; // 8px threshold
            for (const t of targets) {
              const yForTarget = this._yForPriceForDrag(t.v);
              if (yForTarget == null) continue;
              const dy = Math.abs(yForTarget - y);
              if (dy < bestDy) { bestDy = dy; bestPrice = t.v; }
            }
            price = bestPrice;
          }
        }
        // Measure — 2-click, EPHEMERAL. Click 1 sets anchor; click 2 commits
        // a single measurement that stays on screen until the next click
        // anywhere on the chart clears it. NOT stored in the drawings list
        // (no Flutter persistence, no toolbar, no drag — TradingView style).
        if (this._drawMode === 'measure') {
          if (!this._inProgressDrawing) {
            this._inProgressDrawing = {
              kind: 'measure',
              points: [{ price, ts }],
            };
            this.scheduleRedraw();
            return;
          }
          this._activeMeasure = {
            p1: this._inProgressDrawing.points[0],
            p2: { price, ts },
          };
          this._exitDrawMode();
          this.scheduleRedraw();
          return;
        }
        // Phase 21.B — Path (multi-point polyline): each click appends a point.
        // Double-click or Esc commits; Esc with < 2 points cancels.
        if (this._drawMode === 'path') {
          if (!this._inProgressDrawing) {
            this._inProgressDrawing = {
              kind: 'path',
              color: '#3B82F6',
              points: [{ price, ts }],
            };
            this.scheduleRedraw();
            return;
          }
          // Subsequent clicks append to the path (cap at 32 points to avoid abuse).
          if (this._inProgressDrawing.points.length < 32) {
            this._inProgressDrawing.points.push({ price, ts });
          }
          this.scheduleRedraw();
          return;
        }
        // Phase 28 — generic placement for registry-driven tools. Single-click
        // tools (clicks≤1) commit immediately; multi-click tools accumulate
        // anchors and commit once `clicks` points are placed. The tool stays
        // active for repeat-draw, matching the built-in branches.
        const _impl = DRAWING_TOOLS[this._drawMode];
        if (_impl) {
          // Variable-point tools (polyline) accumulate anchors like `path`
          // and commit on double-click / Esc (handled elsewhere).
          if (_impl.variable) {
            if (!this._inProgressDrawing) {
              this._inProgressDrawing = {
                kind: this._drawMode,
                color: '#3B82F6',
                points: [{ price, ts }],
              };
            } else if (this._inProgressDrawing.points.length < 64) {
              this._inProgressDrawing.points.push({ price, ts });
            }
            this.scheduleRedraw();
            return;
          }
          const need = Math.max(1, _impl.clicks || 1);
          const commit = (points) => {
            // Tools with an `expand` hook (position tools) turn the placed
            // anchors into a richer point set (entry/stop/target) so each
            // level becomes an independently draggable handle.
            const finalPoints = (typeof _impl.expand === 'function')
                ? _impl.expand(points, this)
                : points;
            const drawing = {
              id: 'd-' + Date.now().toString(36) + '-' +
                  Math.random().toString(36).slice(2, 8),
              kind: this._drawMode,
              color: '#3B82F6',
              points: finalPoints,
            };
            try {
              parent.postMessage(JSON.stringify({
                type: 'drawingCommitted',
                value: { paneId: this.paneId, drawing },
              }), '*');
            } catch (_) {}
            this._inProgressDrawing = null;
            this.scheduleRedraw();
          };
          if (!this._inProgressDrawing) {
            if (need <= 1) { commit([{ price, ts }]); return; }
            this._inProgressDrawing = {
              kind: this._drawMode,
              color: '#3B82F6',
              points: [{ price, ts }],
            };
            this.scheduleRedraw();
            return;
          }
          this._inProgressDrawing.points.push({ price, ts });
          if (this._inProgressDrawing.points.length >= need) {
            commit(this._inProgressDrawing.points.slice());
          } else {
            this.scheduleRedraw();
          }
          return;
        }
      }

      // Overlay click intercept — open detail popup or close-confirm dialog
      // instead of starting a drag.
      const hit = this._overlayHitTest(x, y);
      if (hit) {
        e.preventDefault();
        e.stopPropagation();
        let msg = null;
        if (hit.kind === 'overlay') {
          if (hit.action === 'addOco') {
            // Attach a target + stop to the position — Flutter opens the
            // OCO dialog (reviewed, never instant).
            msg = {
              type: 'positionOcoRequested',
              value: { paneId: this.paneId, overlayId: hit.overlayId },
            };
          } else if (hit.action === 'close') {
            // Close-box click — fire the existing close-requested message
            // and we're done.
            msg = {
              type: 'overlayCloseRequested',
              value: {
                paneId: this.paneId,
                overlayId: hit.overlayId,
                clientX: e.clientX,
                clientY: e.clientY,
              },
            };
          } else {
            // 'open' hit — could be a click (→ detail popup) OR the start of
            // a drag-to-modify on an order line. We don't know yet; defer to
            // mouseup. For order overlays only, start a drag session that
            // we'll either commit (move>2px → modify) or fall through as a
            // click (move<=2px → detail popup).
            const ov = this._overlays.find((o) => o.id === hit.overlayId);
            const isDraggable =
                ov && (ov.kind === 'limit' || ov.kind === 'sl' ||
                       ov.kind === 'sl-l' || ov.kind === 'ocoTp' ||
                       ov.kind === 'ocoSl');
            if (isDraggable) {
              this._dragOverlay = {
                overlayId: hit.overlayId,
                originalPrice: ov.price,
                startClientY: e.clientY,
                lastClientY: e.clientY,
                hasMoved: false,
              };
              // Don't post anything yet AND don't enter pan mode — mousemove
              // will redraw with the dragged y; mouseup will emit either a
              // dragEnded (if moved) or a click (if not).
              return;
            }
            // Position overlays or any unexpected kind: behave like the
            // pre-Phase-5 click → detail popup.
            msg = {
              type: 'overlayClicked',
              value: {
                paneId: this.paneId,
                overlayId: hit.overlayId,
                clientX: e.clientX,
                clientY: e.clientY,
              },
            };
          }
        } else if (hit.kind === 'header') {
          if (hit.headerKind === 'bid' || hit.headerKind === 'ask') {
            msg = {
              type: hit.headerKind === 'bid' ? 'bidClicked' : 'askClicked',
              value: {
                paneId: this.paneId,
                price: hit.price,
                clientX: e.clientX,
                clientY: e.clientY,
              },
            };
          } else if (hit.headerKind === 'qty') {
            msg = {
              type: 'qtyChipClicked',
              value: {
                paneId: this.paneId,
                clientX: e.clientX,
                clientY: e.clientY,
              },
            };
          }
        } else if (hit.kind === 'plus') {
          msg = {
            type: 'plusClicked',
            value: {
              paneId: this.paneId,
              price: hit.price,
              clientX: e.clientX,
              clientY: e.clientY,
            },
          };
          // Pin the crosshair at the click point so the user can still see
          // their target price while the popup is open and their cursor has
          // moved away from the chart.
          this._pinnedHover = { x, y };
          this.scheduleRedraw();
        }
        if (msg && !this._liteMode) {
          // In lite mode the chart is read-only — suppress every
          // order/depth/overlay click dispatch (plus, bid/ask, qty chip,
          // overlay open, overlay close). The explain host doesn't pass
          // overlays in the first place, but defense in depth — a stray
          // hit from a residual overlay would still pop an order dialog.
          try { parent.postMessage(JSON.stringify(msg), '*'); } catch (_) {}
        }
        return;
      }

      // Sub-pane divider — start a vertical drag when clicked anywhere in
      // an 8-pixel hot zone around the divider line. Wider than the
      // visible 6px band so the user doesn't have to land exactly on the
      // handle. Without this, near-misses fell through to the sub-pane Y
      // pan and the user couldn't resize.
      if (this._subDividerY != null &&
          Math.abs(y - this._subDividerY) <= 8) {
        e.preventDefault();
        e.stopPropagation();
        this._resizingSubPane = true;
        wrap.style.cursor = 'ns-resize';
        return;
      }

      // Phase 10 — mousedown on empty plot area (no overlay / drawing / chip
      // hit reached us). Clear any active drawing selection, any open
      // toolbar popup, AND the one-shot measurement overlay. Click-outside
      // dismisses all three the way a real menu / measure tool does.
      if (this._selectedDrawingId || this._toolbarPopup ||
          this._activeMeasure) {
        this._selectedDrawingId = null;
        this._toolbarPopup = null;
        this._activeMeasure = null;
        this.scheduleRedraw();
      }

      // Sub-pane drag isolation — when the mousedown lands inside a
      // sub-pane, start a per-sub-pane 2D pan ('subYpan') so vertical
      // movement pans THAT sub-pane's price axis (not the main candle
      // pane's) while horizontal still slides the time axis. If we can't
      // resolve which sub-pane was hit (e.g. between two of them) OR draw
      // mode is active (don't accidentally draw across panes), fall back
      // to horizontal-only pan ('xpan').
      const inSubPane = this._subDividerY != null && y > this._subDividerY + 3;
      const hitSub = inSubPane ? this._hitSubPane(y) : null;
      const w = this.canvas.clientWidth;
      const inRightGutter = x >= w - 64;
      if (hitSub && !this._drawMode && inRightGutter) {
        // Mousedown on a sub-pane's right axis gutter → vertical drag
        // ZOOMS that sub-pane's value scale (squeeze / expand), same as
        // the main pane's zoom-y but isolated to the sub-pane.
        this._dragMode = 'subYzoom';
        this._dragSubInd = hitSub.id;
      } else if (hitSub && !this._drawMode) {
        this._dragMode = 'subYpan';
        this._dragSubInd = hitSub.id;
      } else if (inSubPane) {
        this._dragMode = 'xpan';
        this._dragSubInd = null;
      } else {
        this._dragMode = this._hitZone(x, y);
        this._dragSubInd = null;
      }
      this._dragLastX = e.clientX;
      this._dragLastY = e.clientY;
      wrap.classList.remove('dragging', 'zoom-y', 'zoom-x');
      if (this._dragMode === 'pan' || this._dragMode === 'xpan' ||
          this._dragMode === 'subYpan') {
        wrap.classList.add('dragging');
      }
      else if (this._dragMode === 'zoom-y' ||
               this._dragMode === 'subYzoom') wrap.classList.add('zoom-y');
      else if (this._dragMode === 'zoom-x') wrap.classList.add('zoom-x');
      this.view.autoFollow = false;
      this.view.autoFitY = false;
    });
    window.addEventListener('mouseup', () => {
      // Sub-pane resize release — persist the ratio.
      if (this._resizingSubPane) {
        this._resizingSubPane = false;
        try {
          window.localStorage.setItem(
              'chartEngineSubRatio_' + this.paneId,
              this._subPaneRatio.toFixed(4));
        } catch (_) {}
        wrap.style.cursor = '';
        this.scheduleRedraw();
        return;
      }
      // Phase 30 — anchor-handle reshape release. Persist the new points.
      if (this._dragHandleId != null) {
        if (this._dragHandleMoved) {
          const d = this._drawings.find((dd) => dd.id === this._dragHandleId);
          if (d) {
            try {
              parent.postMessage(JSON.stringify({
                type: 'drawingMoved',
                value: {
                  paneId: this.paneId,
                  drawingId: this._dragHandleId,
                  points: d.points,
                },
              }), '*');
            } catch (_) {}
          }
        }
        this._dragHandleId = null;
        this._dragHandleIndex = -1;
        this._dragHandleMoved = false;
        this.scheduleRedraw();
        return;
      }
      // Phase 10 — drawing drag release. If we moved >2px, post
      // drawingMoved with the new points so Flutter can persist them.
      if (this._dragDrawingId) {
        if (this._dragDrawingMoved) {
          const d = this._drawings.find(
              (dd) => dd.id === this._dragDrawingId);
          if (d) {
            try {
              parent.postMessage(JSON.stringify({
                type: 'drawingMoved',
                value: {
                  paneId: this.paneId,
                  drawingId: this._dragDrawingId,
                  points: d.points,
                },
              }), '*');
            } catch (_) {}
          }
        }
        this._dragDrawingId = null;
        this._dragDrawingStartPoints = null;
        this._dragDrawingMoved = false;
        this.scheduleRedraw();
        return;
      }
      // Phase 19.2 — rect drag-release: commit or cancel.
      if (this._rectDragging) {
        this._rectDragging = false;
        const ip = this._inProgressDrawing;
        if (ip && ip.points[1]) {
          // Compute pixel drag distance to detect degenerate (zero-size) rects.
          const dx = e.clientX - this._rectAnchorClientX;
          const dy = e.clientY - this._rectAnchorClientY;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist >= 4) {
            const drawing = {
              id: 'd-' + Date.now().toString(36) + '-' +
                  Math.random().toString(36).slice(2, 8),
              kind: 'rect',
              color: '#3B82F6',
              points: [ip.points[0], ip.points[1]],
            };
            try {
              parent.postMessage(JSON.stringify({
                type: 'drawingCommitted',
                value: { paneId: this.paneId, drawing },
              }), '*');
            } catch (_) {}
          }
        }
        this._exitDrawMode();
        this.scheduleRedraw();
        return;
      }
      // Drag-to-modify release.
      if (this._dragOverlay) {
        const drag = this._dragOverlay;
        this._dragOverlay = null;
        if (drag.hasMoved) {
          // Compute the new price from the final cursor y (snapped).
          const rect = wrap.getBoundingClientRect();
          const localY = drag.lastClientY - rect.top;
          // Convert y → price using a fresh plot. Easiest: defer to a small
          // helper so we don't re-derive `plot` here.
          const newPrice = this._yToPriceForDrag(localY);
          if (newPrice != null) {
            const snapped = this._snapPrice(newPrice);
            this._pendingOverlayMoves.set(drag.overlayId, {
              price: snapped,
              expiresAt: Date.now() + 3000,
            });
            try {
              parent.postMessage(JSON.stringify({
                type: 'overlayDragEnded',
                value: {
                  paneId: this.paneId,
                  overlayId: drag.overlayId,
                  newPrice: snapped,
                  clientX: 0, // not needed for modify dialog anchoring
                  clientY: 0,
                },
              }), '*');
            } catch (_) {}
          }
        } else {
          // No movement → treat as a click → open detail popup, same as the
          // pre-Phase-5 behaviour.
          try {
            parent.postMessage(JSON.stringify({
              type: 'overlayClicked',
              value: {
                paneId: this.paneId,
                overlayId: drag.overlayId,
                clientX: drag.startClientY, // these aren't precise but the popup uses iframeRect+offset
                clientY: drag.startClientY,
              },
            }), '*');
          } catch (_) {}
        }
        this.scheduleRedraw();
        return;
      }
      // Existing pan release path:
      if (this._dragMode) wrap.classList.remove('dragging', 'zoom-y', 'zoom-x');
      this._dragMode = null;
    });
    window.addEventListener('keydown', (e) => {
      // Phase 14.1 — chart shortcuts. Gated by `_shortcutsEnabled` (default
      // OFF; user opts in via Settings). Suppressed when typing in a form
      // field. Letter actions require Alt to avoid accidental triggers
      // while the cursor is over the chart. Number/timeframe keys still
      // fire bare (less risk; matches TradingView muscle memory).
      if (e.key !== 'Escape') {
        if (!this._shortcutsEnabled) return;
        const t = e.target;
        if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' ||
                  t.isContentEditable)) return;
        if (e.ctrlKey || e.metaKey) return; // leave OS shortcuts alone
        if (e.altKey) {
          // Letter actions: Alt+B / Alt+S / Alt+I.
          switch (e.key.toLowerCase()) {
            case 'b': e.preventDefault(); this._postQuickPlace('buy'); return;
            case 's': e.preventDefault(); this._postQuickPlace('sell'); return;
            case 'i': e.preventDefault(); this._postToggleInstant(); return;
          }
          return;
        }
        // No Alt — only number/timeframe keys fire.
        switch (e.key) {
          case '1': this._postTimeframe(1); return;
          case '5': this._postTimeframe(5); return;
          case '!': this._postTimeframe(15); return; // Shift+1
          case 'h': case 'H': this._postTimeframe(60); return;
          case 'd': case 'D': this._postTimeframe(1440); return;
          default: break;
        }
        return;
      }
      if (this._dragOverlay) {
        this._dragOverlay = null;
        this.scheduleRedraw();
      }
      // Phase 19.2 — Esc cancels an in-progress rect drag.
      if (this._rectDragging) {
        this._rectDragging = false;
        this._exitDrawMode();
        this.scheduleRedraw();
      }
      // Phase 10 — Esc also cancels an in-progress drawing-translate drag
      // and clears any drawing selection.
      if (this._dragDrawingId) {
        // Restore the original points so an in-flight translate visually
        // reverts on cancel.
        if (this._dragDrawingStartPoints) {
          const d = this._drawings.find(
              (dd) => dd.id === this._dragDrawingId);
          if (d) {
            d.points = this._dragDrawingStartPoints.map(
                (p) => ({ price: p.price, ts: p.ts }));
          }
        }
        this._dragDrawingId = null;
        this._dragDrawingStartPoints = null;
        this._dragDrawingMoved = false;
        this.scheduleRedraw();
      }
      if (this._dragHandleId != null) {
        this._dragHandleId = null;
        this._dragHandleIndex = -1;
        this._dragHandleMoved = false;
        this.scheduleRedraw();
      }
      if (this._selectedDrawingId) {
        this._selectedDrawingId = null;
        this.scheduleRedraw();
      }
      if (this._drawMode || this._inProgressDrawing) {
        // Phase 21.B / 28 — Path or any variable-point registry tool
        // (polyline) with ≥2 points commits on Esc; otherwise cancel.
        const _vimpl = DRAWING_TOOLS[this._drawMode];
        if ((this._drawMode === 'path' || (_vimpl && _vimpl.variable)) &&
            this._inProgressDrawing &&
            this._inProgressDrawing.points.length >= 2) {
          const drawing = {
            id: 'd-' + Date.now().toString(36) + '-' +
                Math.random().toString(36).slice(2, 8),
            kind: this._inProgressDrawing.kind,
            color: '#3B82F6',
            points: this._inProgressDrawing.points.slice(),
          };
          try {
            parent.postMessage(JSON.stringify({
              type: 'drawingCommitted',
              value: { paneId: this.paneId, drawing },
            }), '*');
          } catch (_) {}
        }
        this._exitDrawMode();
        this.scheduleRedraw();
      }
    });
    window.addEventListener('mousemove', (e) => {
      // Sub-pane divider drag takes priority over everything else — we want
      // the resize to be uninterruptible by stray hover / pan code paths.
      if (this._resizingSubPane) {
        const rect = wrap.getBoundingClientRect();
        const y = e.clientY - rect.top;
        const h = this.canvas.clientHeight;
        const topPad = 8;
        const bottomGutter = 24;
        const innerH = h - topPad - bottomGutter;
        if (innerH > 0) {
          // y is the new candle-area bottom. Total sub-pane height = bottom
          // of canvas (innerH + topPad) - y. Ratio = subTotal / innerH.
          const subTotal = (topPad + innerH) - y;
          const newRatio = Math.max(0.10, Math.min(0.65, subTotal / innerH));
          if (Math.abs(newRatio - this._subPaneRatio) > 0.002) {
            this._subPaneRatio = newRatio;
            this.scheduleRedraw();
          }
        }
        return;
      }
      // Phase 30 — reshape: drag a single anchor handle to the cursor.
      if (this._dragHandleId != null) {
        const rectH = wrap.getBoundingClientRect();
        const lx = e.clientX - rectH.left;
        const ly = e.clientY - rectH.top;
        const price = this._snapPrice(this._yToPriceForDrag(ly));
        const ts = this._xToTs(lx);
        const d = this._drawings.find((dd) => dd.id === this._dragHandleId);
        if (d && d.points && d.points[this._dragHandleIndex] != null &&
            price != null && ts != null) {
          this._dragHandleMoved = true;
          d.points[this._dragHandleIndex] = { price, ts };
          this.scheduleRedraw();
        }
        return;
      }
      // Phase 10 — drag-to-move a selected drawing. Takes precedence over
      // pan / overlay-drag / hover so the gesture is uninterrupted.
      if (this._dragDrawingId && this._dragDrawingStartPoints) {
        const dxPx = e.clientX - this._dragStartClientX;
        const dyPx = e.clientY - this._dragStartClientY;
        if (Math.abs(dxPx) > 2 || Math.abs(dyPx) > 2) {
          this._dragDrawingMoved = true;
        }
        // Convert pixel deltas to price + ts deltas. Price delta is derived
        // by inverting priceToY at the start- and current-y; ts delta uses
        // cellW (px/bar) × timeframeMinutes (s/bar).
        const rect = wrap.getBoundingClientRect();
        const startLocalY = this._dragStartClientY - rect.top;
        const curLocalY = e.clientY - rect.top;
        const startPrice = this._yToPriceForDrag(startLocalY);
        const curPrice = this._yToPriceForDrag(curLocalY);
        const dPrice = (curPrice != null && startPrice != null)
            ? (curPrice - startPrice)
            : 0;
        const dtSec = this.timeframeMinutes * 60;
        const cellW = this.view.cellW || 1;
        const dTs = Math.round((dxPx / cellW) * dtSec);
        const d = this._drawings.find(
            (dd) => dd.id === this._dragDrawingId);
        if (d) {
          d.points = this._dragDrawingStartPoints.map((p) => ({
            price: p.price + dPrice,
            ts: p.ts + dTs,
          }));
          this.scheduleRedraw();
        }
        return;
      }
      // Phase 19.2 — rect drag preview: update second corner while dragging.
      if (this._rectDragging && this._inProgressDrawing) {
        const rectCanvas = wrap.getBoundingClientRect();
        const rx = e.clientX - rectCanvas.left;
        const ry = e.clientY - rectCanvas.top;
        // Keep hover updated so the in-progress preview renderer can use
        // direct pixel coords (avoids ts-snap rounding to candle centers
        // which makes the rect look zero-width when corners are within one
        // cell-width of each other).
        this.hover.x = rx; this.hover.y = ry; this.hover.inside = true;
        const rPrice = this._snapPrice(this._yToPriceForDrag(ry));
        const rTs = this._xToTs(rx);
        this._inProgressDrawing.points[1] = { price: rPrice, ts: rTs };
        this.scheduleRedraw();
        return;
      }
      // Drag-to-modify takes precedence over normal mousemove (pan / hover).
      if (this._dragOverlay) {
        if (Math.abs(e.clientY - this._dragOverlay.startClientY) > 2) {
          this._dragOverlay.hasMoved = true;
        }
        this._dragOverlay.lastClientY = e.clientY;
        this.scheduleRedraw();
        return;
      }
      const rect = wrap.getBoundingClientRect();
      const x = e.clientX - rect.left, y = e.clientY - rect.top;
      const inside = x >= 0 && y >= 0 && x <= rect.width && y <= rect.height;
      if (!this._dragMode) {
        if (inside) {
          // Sub-pane divider hover — ns-resize cursor when within 8px of the
          // divider Y (same hit zone as the mousedown grab). Take priority
          // over the chip/crosshair branches.
          if (this._subDividerY != null &&
              Math.abs(y - this._subDividerY) <= 8) {
            wrap.style.cursor = 'ns-resize';
            if (!this._subDividerHover) {
              this._subDividerHover = true;
              this.scheduleRedraw();
            }
            return;
          } else if (this._subDividerHover) {
            this._subDividerHover = false;
            this.scheduleRedraw();
          }

          // Top header strip (symbol chip + OHLC line + bid/ask buttons)
          // sits at the very top of the canvas. Suppress the crosshair
          // when the cursor is over this strip so the dashed lines don't
          // bleed through the text/buttons. Header always starts at the
          // left of the plot area.
          const headerStripH = this.scrip ? 84 : (this.candles.length > 0 ? 40 : 24);
          const headerStripW = 300; // covers symbol + OHLC + bid/ask widths
          if (y < headerStripH && x >= 8 && x < 8 + headerStripW) {
            if (this.hover.inside) {
              this.hover.inside = false;
              this.hover.x = null;
              this.hover.y = null;
              this.scheduleRedraw();
            }
            return;
          }
          // Phase 7 — delete-chip cursor + in-progress trendline tracking.
          let drawingChipHover = false;
          for (const h of this._drawingHits) {
            const r = h.rect;
            if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
              drawingChipHover = true;
              break;
            }
          }
          // Indicator chip hover — extends across the entire row (label +
          // icon block), not just the eye/gear/× hit rects. Two reasons:
          //   1. So cursor moving from label area onto an icon doesn't
          //      flip the row's "hovered" state off and on (which would
          //      blink the icons out for one frame).
          //   2. So the chart crosshair stays suppressed across the whole
          //      chip column, not just over icon centroids.
          let indicatorChipHover = false;
          let indicatorRowId = null;
          if (!drawingChipHover) {
            // Full-row rects first (covers label + icons + spacing).
            for (const r of this._indicatorRowRects) {
              const rc = r.rect;
              if (x >= rc.x && x <= rc.x + rc.w &&
                  y >= rc.y && y <= rc.y + rc.h) {
                indicatorChipHover = true;
                indicatorRowId = r.indicatorId;
                break;
              }
            }
            // Plus the icon hit rects (covers the header collapse/expand
            // button + any future rect that isn't tied to a row).
            if (!indicatorChipHover) {
              for (const h of this._indicatorChipHits) {
                const r = h.rect;
                if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
                  indicatorChipHover = true;
                  break;
                }
              }
            }
          }
          if (this._hoveredIndicatorRowId !== indicatorRowId) {
            this._hoveredIndicatorRowId = indicatorRowId;
            this.scheduleRedraw();
          }
          if (drawingChipHover || indicatorChipHover) {
            wrap.style.cursor = 'pointer';
            // Suppress crosshair while over a UI chip so the dashed lines
            // don't render through the chip and make icons hard to read.
            if (this.hover.inside) {
              this.hover.inside = false;
              this.hover.x = null;
              this.hover.y = null;
              this.scheduleRedraw();
            }
            return;
          } else {
            const hit = this._overlayHitTest(x, y);
            if (hit) {
              wrap.style.cursor = 'pointer';
            } else {
              const z = this._hitZone(x, y);
              // When crosshair lines are off, use the default arrow inside
              // the chart area — the dashed lines were the only thing the
              // crosshair cursor was hinting at. Zoom edges keep their
              // resize cursors regardless.
              const baseCursor =
                  this.showCrosshairLines ? 'crosshair' : 'default';
              wrap.style.cursor = z === 'zoom-y' ? 'ns-resize'
                : z === 'zoom-x' ? 'ew-resize' : baseCursor;
            }
          }
          if (this.hover.x !== x || this.hover.y !== y || !this.hover.inside) {
            this.hover.x = x; this.hover.y = y; this.hover.inside = true;
            this.scheduleRedraw();
          } else if (this._inProgressDrawing) {
            // Same x/y reported (rare) — still schedule a redraw so the
            // tentative trendline keeps tracking.
            this.scheduleRedraw();
          }
        } else if (this.hover.inside) {
          this.hover.inside = false;
          this.scheduleRedraw();
        }
        return;
      }
      if (this.hover.inside) { this.hover.inside = false; }
      const dx = e.clientX - this._dragLastX;
      const dy = e.clientY - this._dragLastY;
      this._dragLastX = e.clientX;
      this._dragLastY = e.clientY;
      if (this._dragMode === 'pan') {
        // Free 2D pan. Horizontal motion shifts offsetX (slides candles).
        // Vertical motion shifts priceCenter (slides price scale). The
        // first vertical motion captures the current auto-fit values as
        // the manual baseline so the drag feels smooth instead of jumpy.
        this.view.offsetX += dx;
        if (dy !== 0) {
          if (this.view.priceCenter == null) this._snapshotYToManual();
          this.view.priceCenter += dy * this.view.pricePerPx;
        }
      } else if (this._dragMode === 'xpan') {
        // Horizontal-only pan — fallback when the drag started inside a
        // sub-pane but we couldn't resolve which one (or draw mode is on).
        // Vertical movement intentionally does nothing so the main candle
        // pane stays put.
        this.view.offsetX += dx;
      } else if (this._dragMode === 'subYpan') {
        // Per-sub-pane 2D pan. Horizontal still slides the time axis
        // together with candles. Vertical pans THIS sub-pane's value axis
        // only — leaves the main candle pane untouched. First vertical
        // motion snapshots the auto-fit center+perPx to manual so the
        // gesture starts from the current visual baseline.
        this.view.offsetX += dx;
        if (dy !== 0 && this._dragSubInd != null) {
          const sp = (this._lastSubPlots || [])
              .find((s) => s.id === this._dragSubInd);
          if (sp) {
            this._snapshotSubPaneViewToManual(sp);
            const view = this._subPaneView[sp.id];
            if (view && view.perPx != null) {
              // Drag DOWN (positive dy) raises the center so values
              // appear to move DOWN — same convention as the main pane.
              view.center += dy * view.perPx;
            }
          }
        }
      } else if (this._dragMode === 'subYzoom') {
        // Per-sub-pane Y-zoom (squeeze / expand) — same gesture as the
        // main pane's zoom-y but scoped to one sub-pane. Drag DOWN to
        // expand the value range (zoom out); drag UP to compress (zoom in).
        if (this._dragSubInd != null) {
          const sp = (this._lastSubPlots || [])
              .find((s) => s.id === this._dragSubInd);
          if (sp) {
            this._snapshotSubPaneViewToManual(sp);
            const view = this._subPaneView[sp.id];
            if (view && view.perPx != null) {
              view.perPx = Math.max(1e-12,
                  view.perPx * Math.exp(dy * 0.005));
            }
          }
        }
      } else if (this._dragMode === 'zoom-y') {
        if (this.view.priceCenter == null) this._snapshotYToManual();
        this.view.pricePerPx = Math.max(1e-6,
            this.view.pricePerPx * Math.exp(dy * 0.005));
      } else if (this._dragMode === 'zoom-x') {
        this.view.cellW = Math.max(4, Math.min(60,
            this.view.cellW + dx * 0.15));
      }
      this.scheduleRedraw();
    });
    wrap.addEventListener('wheel', (e) => {
      e.preventDefault();
      // Route Y-zoom to whichever pane the cursor is over. Plain wheel
      // (no shift) always pans the time axis (cellW) regardless of pane.
      const rectW = wrap.getBoundingClientRect();
      const wy = e.clientY - rectW.top;
      const sub = (this._subDividerY != null && wy > this._subDividerY + 3)
          ? this._hitSubPane(wy) : null;
      const factor = e.deltaY < 0 ? 1.1 : 1 / 1.1;
      if (e.shiftKey) {
        if (sub) {
          this._snapshotSubPaneViewToManual(sub);
          const view = this._subPaneView[sub.id];
          if (view && view.perPx != null) {
            // Inverse factor so wheel-up zooms IN (smaller perPx) — matches
            // the main pane's convention.
            view.perPx = Math.max(1e-12, view.perPx / factor);
          }
        } else {
          if (this.view.priceCenter == null) this._snapshotYToManual();
          this.view.pricePerPx = Math.max(1e-6, this.view.pricePerPx / factor);
          this.view.autoFitY = false;
        }
      } else {
        this.view.cellW = Math.max(4, Math.min(60, this.view.cellW * factor));
      }
      this.view.autoFollow = false;
      this.scheduleRedraw();
    }, { passive: false });
    wrap.addEventListener('dblclick', (e) => {
      // Phase 21.B / 28 — Path or any variable-point registry tool (polyline):
      // double-click commits the in-progress polyline when it has at least 2
      // points. Prevents the view-reset below from firing.
      const _dimpl = DRAWING_TOOLS[this._drawMode];
      if ((this._drawMode === 'path' || (_dimpl && _dimpl.variable)) &&
          this._inProgressDrawing &&
          this._inProgressDrawing.points.length >= 2) {
        const drawing = {
          id: 'd-' + Date.now().toString(36) + '-' +
              Math.random().toString(36).slice(2, 8),
          kind: this._inProgressDrawing.kind,
          color: '#3B82F6',
          points: this._inProgressDrawing.points.slice(),
        };
        try {
          parent.postMessage(JSON.stringify({
            type: 'drawingCommitted',
            value: { paneId: this.paneId, drawing },
          }), '*');
        } catch (_) {}
        this._exitDrawMode();
        this.scheduleRedraw();
        return;
      }
      // Sub-pane Y-axis reset stays on double-click — it's a per-sub-pane
      // shortcut that wouldn't fit a single global toolbar. Main-pane
      // reset moved to the floating control bar (zoomReset button); the
      // double-click main-pane reset was removed to avoid colliding with
      // it and to match TradingView's UX.
      const rectDc = wrap.getBoundingClientRect();
      const dcY = e.clientY - rectDc.top;
      if (this._subDividerY != null && dcY > this._subDividerY + 3) {
        const sub = this._hitSubPane(dcY);
        if (sub) {
          this._subPaneView[sub.id] = { center: null, perPx: null };
          this.scheduleRedraw();
          return;
        }
      }
    });
    wrap.addEventListener('mouseleave', () => {
      if (this.hover.inside) { this.hover.inside = false; this.scheduleRedraw(); }
      // Clear indicator-row hover too so icons fade out cleanly when
      // the cursor exits the pane (mouseleave skips the mousemove
      // recalculation that would otherwise nil this out).
      if (this._hoveredIndicatorRowId != null) {
        this._hoveredIndicatorRowId = null;
        this.scheduleRedraw();
      }
      // Phase 19.2 — cancel rect drag if the cursor leaves the chart.
      if (this._rectDragging) {
        this._rectDragging = false;
        this._exitDrawMode();
        this.scheduleRedraw();
      }
    });
  }

  _hitZone(x, y) {
    const w = this.canvas.clientWidth;
    const h = this.canvas.clientHeight;
    if (x >= w - 64) return 'zoom-y';   // right gutter
    if (y >= h - 24) return 'zoom-x';   // bottom gutter
    return 'pan';
  }

  // On the first manual Y interaction, capture the current auto-fit values so
  // subsequent drags are smooth and not snap-jumpy.
  _snapshotYToManual() {
    if (this.candles.length === 0) return;
    const visible = this._visibleCandles();
    if (visible.length === 0) return;
    let lo = Infinity, hi = -Infinity;
    for (const c of visible) { if (c.l < lo) lo = c.l; if (c.h > hi) hi = c.h; }
    if (!isFinite(lo) || !isFinite(hi)) return;
    const pad = (hi - lo) * 0.08 || 1;
    const plotH = this.canvas.clientHeight - 32; // approx plot height
    this.view.priceCenter = (lo + hi) / 2;
    this.view.pricePerPx = ((hi - lo) + 2 * pad) / plotH;
  }

  _visibleCandles() {
    if (this.candles.length === 0) return [];
    // Continuous pixel positioning. Single source of truth for candle X:
    //   xCenter(i) = plot.right - (N-1-i + 0.5) * cellW + offsetX
    // offsetX > 0 shifts the whole row right (drag-right → newest pushed
    // off-screen, older candles slide in from the left). offsetX < 0 shifts
    // the row left (newest stays anchored, blank space on the right).
    const N = this._seriesLength();
    const W = this.view.cellW;
    const O = this.view.offsetX;
    const left = 8;                              // plot.left
    const right = this.canvas.clientWidth - 64;  // plot.right
    // Solve xCenter(i) >= left and xCenter(i) <= right + cellW (a bit of
    // overshoot for partial-edge candles).
    const iMin = Math.max(0, Math.ceil(N - 0.5 - (right - left + O) / W));
    const iMax = Math.min(N - 1, Math.floor(N - 0.5 - O / W));
    if (iMax < iMin) return [];
    return this.candles.slice(iMin, iMax + 1);
  }

  _candleXCenter(absoluteIndex, plot) {
    const N = this._seriesLength();
    return plot.right - (N - 1 - absoluteIndex + 0.5) * this.view.cellW + this.view.offsetX;
  }

  // Inverse of _candleXCenter for the visible window: returns [first, last]
  // column indices (clamped to [0, count-1]) whose x falls inside the plot,
  // with a 1-column margin. Used by the rebinned/renko auto-fit so the y-axis
  // tracks the on-screen columns instead of the whole series.
  _visibleIndexRange(plot, count) {
    if (count <= 0) return [0, 0];
    const W = this.view.cellW || 1;
    const O = this.view.offsetX || 0;
    const base = count - 1 + 0.5;
    let last = Math.ceil(base + O / W) + 1;
    let first = Math.floor(base + (O - (plot.right - plot.left)) / W) - 1;
    if (first < 0) first = 0;
    if (last > count - 1) last = count - 1;
    if (first > last) { first = 0; last = count - 1; }
    return [first, last];
  }

  scheduleRedraw() {
    // Every redraw (pan / zoom / tick) is also a chance to top up older
    // candles if the user has scrolled close to the start of loaded data.
    // The method self-throttles + bails if not near the leftmost edge.
    this._maybeExtendHistory();
    if (this._frame) return;
    this._frame = requestAnimationFrame(() => {
      this._frame = null;
      this.draw();
    });
  }

  draw() {
    const w = this.canvas.clientWidth;
    const h = this.canvas.clientHeight;
    // Reset the right-axis chip slot ledger for this frame — indicator
    // chips consult it (via _allocAxisChipSlot) to avoid stacking on top
    // of one another or on top of the LTP / countdown chips.
    this._axisChipSlots = [];
    // Per-draw memo cache for indicator computations. Resets each frame
    // so live ticks always get fresh results, but within a single draw
    // the same SMA/EMA/RSI/... call is reused (the overlay drawer, the
    // axis label, the current-value chip, and the hover chip each ask for
    // the same series — pre-cache nukes the duplicate work).
    this._computeCache = new Map();
    this.ctx.fillStyle = this.palette.bg;
    this.ctx.fillRect(0, 0, w, h);
    if (this.candles.length === 0) {
      if (this._loadingTitle != null) this._drawLoadingBanner(w, h);
      return;
    }
    // Dim the chart contents when loading/error so the pane reads as
    // "disabled" (TradingView style) without a modal overlay blocking
    // other panes.
    const dimming = this._loadingTitle != null;
    if (dimming) this.ctx.globalAlpha = 0.35;

    // Carve out a volume panel at the bottom of the candle area when the
    // volume overlay is on. Otherwise candles take the full vertical
    // space (minus the bottom time gutter).
    const bottomGutter = 24;
    const rightGutter = 64;
    const topPad = 8;
    const innerH = h - topPad - bottomGutter;
    // Phase 18.1 — volume is rendered as a TRANSLUCENT OVERLAY at the
    // bottom of the candle plot (TradingView style) rather than a separate
    // panel. Volume no longer eats vertical space; bars are drawn with
    // reduced alpha so candles remain the dominant signal.
    const volH = this.overlays.volume ? Math.round(innerH * 0.22) : 0;
    const SUB_KINDS = new Set(['rsi', 'macd', 'stoch', 'atr', 'stochrsi', 'squeeze', 'efi', 'wt', 'crsi', 'ao', 'mfi', 'obv', 'cmf', 'wr', 'cci', 'roc', 'cvd', 'adx', 'trix', 'vortex', 'uo', 'dpo', 'pvt', 'ad', 'explain']);
    const subPaneIndicators =
        this._indicators.filter((i) => SUB_KINDS.has(i.kind) && !i.hidden);
    const subPaneCount = subPaneIndicators.length;
    // Source of truth is _subPaneTotalH so y↔price helpers and draw() agree
    // on the candle area extent (otherwise magnet snap + drag-modify drift).
    const subPaneTotalH = this._subPaneTotalH(innerH);
    // Candle area gets back the full innerH (minus sub-panes); volume
    // overlays the bottom slice of it.
    const candleH = innerH - subPaneTotalH;
    // Publish the sub-pane offset to CSS so the floating control bar
    // (`.pane-ctrl`) stays anchored to the bottom of the MAIN candle area
    // — not the bottom of the whole pane container, which would put it
    // inside the indicator sub-pane(s) when those are present.
    if (this._publishedSubH !== subPaneTotalH) {
      this._publishedSubH = subPaneTotalH;
      try {
        this.container.style.setProperty(
            '--main-chart-bottom', subPaneTotalH + 'px');
      } catch (_) {}
    }

    // Phase 30 — reserve a left gutter for the floating drawing rail so the
    // on-canvas header (symbol / OHLC) and candles aren't hidden underneath
    // it. Toggled by the rail (collapsed → 0). Lite mode has no rail.
    const railGutter = this._liteMode ? 0
        : (this._leftGutter != null ? this._leftGutter : 46);
    const plot = {
      left: 8 + railGutter, top: topPad,
      right: w - rightGutter,
      bottom: topPad + candleH,
    };
    plot.width = plot.right - plot.left;
    plot.height = plot.bottom - plot.top;

    // Volume region sits INSIDE plot, hugging the bottom edge — no gap, no
    // divider line.
    const volPlot = volH > 0 ? {
      left: plot.left, top: plot.bottom - volH,
      right: plot.right, bottom: plot.bottom,
    } : null;
    if (volPlot) {
      volPlot.width = volPlot.right - volPlot.left;
      volPlot.height = volPlot.bottom - volPlot.top;
    }

    // Phase 11 — sub-pane indicators (rsi/macd/stoch/atr) sit below volume
    // (or directly under candles if volume is off), each in its own slot.
    let subCursorY = (volPlot ? volPlot.bottom : plot.bottom) + 1;
    const subPaneH = subPaneCount > 0
        ? Math.floor(subPaneTotalH / subPaneCount)
        : 0;
    const subPlots = subPaneIndicators.map((ind) => {
      const r = {
        kind: ind.kind, period: ind.period, color: ind.color, id: ind.id,
        // Forward the schema-driven param bag so sub-pane compute helpers can
        // read kind-specific keys (fast/slow, bbLength/kcMult, …) the same
        // way overlay compute helpers do via the indicator object.
        params: ind.params || {},
        // Explain-mode metadata — used by `_drawExplainSubPane` to look up
        // the server's series and label. Harmless on other kinds.
        explainKey: ind.explainKey,
        label: ind.label,
        left: plot.left, top: subCursorY,
        right: plot.right, bottom: subCursorY + subPaneH,
        width: plot.right - plot.left, height: subPaneH,
      };
      subCursorY += subPaneH;
      return r;
    });

    const visible = this._visibleCandles();
    if (visible.length === 0) {
      if (dimming) this.ctx.globalAlpha = 1;
      if (this._loadingTitle != null) this._drawLoadingBanner(w, h);
      return;
    }

    let lo, hi;
    if (this.view.priceCenter == null) {
      // Auto-fit.
      lo = Infinity; hi = -Infinity;
      if (this.candleStyle === 'renko') {
        const bricks = this._renkoBricks;
        // Fit only the columns currently on screen (not all of history) so the
        // y-axis zooms to the visible action.
        const [first, last] = this._visibleIndexRange(plot, bricks.length);
        for (let i = first; i <= last; i++) {
          const v1 = bricks[i].openPrice;
          const v2 = bricks[i].closePrice;
          if (v1 < lo) lo = v1; if (v2 < lo) lo = v2;
          if (v1 > hi) hi = v1; if (v2 > hi) hi = v2;
        }
        // Guard against empty bricks (no bricks yet).
        if (hi === -Infinity) { lo = 0; hi = 1; }
      } else if (this._isRebinnedStyle(this.candleStyle)
          && this._rebinnedStyle === this.candleStyle
          && this._rebinned.length > 0) {
        // Phase 26/30 — auto-fit scans only the VISIBLE rebinned columns so the
        // y-axis follows the on-screen window (scanning the whole array made
        // recent columns squish into a sliver against the full-history range).
        const arr = this._rebinned;
        const [first, last] = this._visibleIndexRange(plot, arr.length);
        for (let i = first; i <= last; i++) {
          const b = arr[i];
          if (b.l < lo) lo = b.l; if (b.h > hi) hi = b.h;
        }
        if (hi === -Infinity) { lo = 0; hi = 1; }
      } else {
        for (const c of visible) { if (c.l < lo) lo = c.l; if (c.h > hi) hi = c.h; }
      }
      const pad = (hi - lo) * 0.08 || 1;
      lo -= pad; hi += pad;
    } else {
      const half = (plot.height / 2) * this.view.pricePerPx;
      lo = this.view.priceCenter - half;
      hi = this.view.priceCenter + half;
    }

    const priceToY = (p) => plot.top + plot.height * (hi - p) / (hi - lo);
    const yToPrice = (y) => hi - (y - plot.top) * (hi - lo) / plot.height;

    // Optional gridlines.
    if (this.overlays.gridlines) {
      this.ctx.strokeStyle = this.palette.gridSoft;
      this.ctx.lineWidth = 0.5;
      const labels = 8;
      for (let i = 1; i < labels; i++) {
        const y = plot.top + (plot.height * i) / labels;
        this.ctx.beginPath(); this.ctx.moveTo(plot.left, y); this.ctx.lineTo(plot.right, y); this.ctx.stroke();
      }
    }

    // Phase 16 — style routing.
    const firstVisibleAbs = this.candles.indexOf(visible[0]);
    switch (this.candleStyle) {
      case 'line':        this._drawLineSeries(visible, firstVisibleAbs, plot, priceToY); break;
      case 'area':        this._drawAreaSeries(visible, firstVisibleAbs, plot, priceToY); break;
      case 'bars':        this._drawBarsOHLC(visible, firstVisibleAbs, plot, priceToY); break;
      case 'hollow':      this._drawCandlesCore(visible, firstVisibleAbs, plot, priceToY, {hollow: true}); break;
      case 'heikin-ashi': this._drawCandlesCore(visible, firstVisibleAbs, plot, priceToY, {heikinAshi: true}); break;
      case 'renko':       this._drawRenko(plot, priceToY); break;
      // Phase 26 — additional simple styles (reuse visible candle slice).
      case 'baseline':    this._drawBaseline(visible, firstVisibleAbs, plot, priceToY); break;
      case 'step':        this._drawStepLine(visible, firstVisibleAbs, plot, priceToY); break;
      case 'columns':     this._drawColumns(visible, firstVisibleAbs, plot, priceToY); break;
      case 'hlcbars':     this._drawHlcBars(visible, firstVisibleAbs, plot, priceToY); break;
      case 'highlow':     this._drawHighLow(visible, firstVisibleAbs, plot, priceToY); break;
      case 'hlcarea':     this._drawHlcArea(visible, firstVisibleAbs, plot, priceToY); break;
      case 'volcandles':  this._drawVolCandles(visible, firstVisibleAbs, plot, priceToY); break;
      // Phase 26 — rebinned styles (draw their own pseudo-candle array, mirror renko).
      case 'linebreak':   this._drawRebinnedCandles(plot, priceToY, {}); break;
      case 'kagi':        this._drawKagi(plot, priceToY); break;
      case 'range':       this._drawRebinnedCandles(plot, priceToY, {}); break;
      case 'pnf':         this._drawPnf(plot, priceToY); break;
      case 'candles':
      default:            this._drawCandlesCore(visible, firstVisibleAbs, plot, priceToY, {}); break;
    }

    // Volume bars (optional panel below the candle plot).
    // Per-brick volume isn't meaningful on Renko (one brick spans fractions of
    // multiple bars), so the volume panel is hidden entirely on Renko. Same
    // logic applies to the other rebinned styles (linebreak/kagi/range/pnf):
    // the X axis is rebinned, so raw-candle volume bars wouldn't line up.
    if (volPlot && this.candleStyle !== 'renko'
        && !this._isRebinnedStyle(this.candleStyle)) {
      let maxV = 0;
      for (const c of visible) { if (c.v > maxV) maxV = c.v; }
      if (maxV > 0) {
        // Phase 18.1 — overlay volume on the bottom of the candle plot at
        // low alpha so it never competes with the candles. No divider line.
        this.ctx.save();
        this.ctx.globalAlpha = 0.32;
        for (let i = 0; i < visible.length; i++) {
          const c = visible[i];
          const absoluteIdx = firstVisibleAbs + i;
          const xCenter = this._candleXCenter(absoluteIdx, plot);
          const isBull = c.c >= c.o;
          this.ctx.fillStyle = isBull ? this.palette.bullSoft : this.palette.bearSoft;
          const barH = Math.max(1, (c.v / maxV) * volPlot.height);
          const bodyW = Math.max(1, this.view.cellW - 2);
          this.ctx.fillRect(
              Math.round(xCenter - bodyW / 2),
              volPlot.bottom - barH, bodyW, barH);
        }
        this.ctx.restore();
        // Max-volume label inside the plot at the top-left of the volume
        // overlay region — subtle scale reference, full opacity so it stays
        // readable on top of any candles in the same Y band.
        this.ctx.fillStyle = this.palette.axisText;
        this.ctx.font = '500 9px Geist, sans-serif';
        this.ctx.textAlign = 'left';
        this.ctx.textBaseline = 'top';
        this.ctx.fillText(
            'Vol ' + this._fmtVol(maxV), plot.left + 4, volPlot.top + 2);
      }
    }

    // Visible-range High/Low markers (Phase 16 F3). Drawn after candle bodies
    // so markers appear on top, but before LTP / overlay chips / crosshair so
    // user-actionable order chips remain the topmost layer. `visible` and
    // `firstVisibleAbs` are passed in so the scan covers only the on-screen
    // slice — re-deriving from view-state here would scan all loaded history.
    // Phase 20 — Key Levels (pivot S/R) drawn as background reference before
    // H/L markers and overlay chips.
    // Phase 30 — these overlays are computed against the REAL candle series and
    // positioned at real-candle x/price, so they don't map onto a rebinned axis
    // (Renko / Kagi / Line Break / Range / P&F), where the column count and
    // price binning differ. Suppress them there so they don't render detached
    // from the series.
    const _rebinAxis = this.candleStyle === 'renko'
        || this._isRebinnedStyle(this.candleStyle);
    if (!_rebinAxis) {
      this._drawKeyLevels(plot, lo, hi, priceToY);
    }
    // Phase 23.4 — Volume Profile gutter histogram (after key levels, before H/L markers).
    this._drawVolumeProfile(plot, lo, hi, priceToY);
    if (!_rebinAxis) {
      this._drawHighLowMarkers(plot, priceToY, visible, firstVisibleAbs);
      // Phase 25 — auto-pattern swing pivot markers + HH/HL/LH/LL labels.
      this._drawAutoPattern(plot, lo, hi, priceToY);
    }

    // Phase 18 — OI bars drawn before the LTP chip so they sit beneath it.
    this._drawOiBars(plot, lo, hi, priceToY);

    // LTP marker BEFORE the axis so the right-axis label area gets the
    // coloured chip on top of any overlapping nice-stride label. Skipped
    // in lite mode (the explain view has no live LTP and the bar-close
    // countdown of "0:00" on historical data is just noise).
    if (!this._liteMode) {
      this._drawLtpLine(plot, priceToY, lo, hi);
    }

    // Overlay lines + inline labels (gutter price chips moved AFTER axis below).
    this._drawOverlays(plot, lo, hi, priceToY);

    // Phase 8/11 — technical indicators. SMA/EMA/BB/VWAP overlay the candle
    // pane; RSI/MACD/STOCH/ATR render in their own stacked sub-panes below
    // the volume panel.
    this._drawIndicators(plot, lo, hi, priceToY);
    if (subPlots.length > 0) {
      this._drawSubPanes(subPlots);
      // Resizable divider: a 4px grab handle sitting between the candle
      // pane and the first sub-pane. Cursor swaps to ns-resize on hover.
      this._drawSubPaneDivider(plot, subPlots[0].top);
    } else {
      this._subDividerY = null;
    }

    // Scan-explanation overlays — matched-bar yellow shading + server
    // indicator lines/markers. Drawn after candles + local indicators so
    // the tint sits on top (subtle 12% alpha), with explain indicator
    // lines fully opaque on top of the tint.
    if (this._explainPayload) {
      this._drawExplainOverlays(plot, lo, hi, priceToY);
    }

    // Phase 31 — CandLlabs ghost projections (Echoes / Oracle). Above
    // candles/overlays, beneath user drawings + crosshair.
    this._drawLabProjection(plot, priceToY);

    // Phase 7 — user-placed drawings (HLines + Trendlines + in-progress).
    this._drawDrawings(plot, priceToY);
    // One-shot Measure overlay (transient — see `_activeMeasure`).
    this._drawActiveMeasure(plot, priceToY);

    // Magnet snap-target indicator — drawn on top of candles/drawings, under crosshair.
    this._drawMagnetTarget(plot, lo, hi, priceToY);

    // Right axis labels (nice-stride algorithm — mirror orderflow).
    this._drawPriceAxis(plot, lo, hi);

    // Phase 24 — overlay price chips (position strike, order, SL gutter chips)
    // drawn AFTER `_drawPriceAxis` so the standard nice-stride labels don't
    // overwrite the white-on-coloured chip text at overlapping price levels.
    this._drawOverlayPriceChips(plot, lo, hi, priceToY);

    // Crosshair — uses the live hover, OR the pinned position (kept while
    // a `+` popup is open so the user can still see what price they picked).
    // y snaps to the scrip's tick size so the horizontal line + price chip
    // always show a tradeable price (matching TradingView behaviour).
    const liveHover = this.hover.inside && this.hover.x != null;
    const chx = liveHover ? this.hover.x : (this._pinnedHover ? this._pinnedHover.x : null);
    const rawChy = liveHover ? this.hover.y : (this._pinnedHover ? this._pinnedHover.y : null);
    if (chx != null && rawChy != null) {
      const snappedPrice = this._snapPrice(yToPrice(rawChy));
      const chy = priceToY(snappedPrice);
      // When the cursor is in a sub-pane the main candle pane's price chip
      // would show a meaningless value AND overpaint the sub-pane's own
      // hover chip. Likewise, the horizontal crosshair line across the
      // candle pane is misleading there — the sub-pane draws its own
      // vertical crosshair in `_drawSubPaneHoverOverlay`.
      const inSubArea = this._subDividerY != null && rawChy > this._subDividerY + 3;
      if (this.showCrosshairLines) {
        this.ctx.strokeStyle = this.palette.crosshair;
        this.ctx.lineWidth = 1;
        this.ctx.setLineDash([4, 4]);
        this.ctx.beginPath();
        this.ctx.moveTo(chx, plot.top);
        this.ctx.lineTo(chx, plot.bottom);
        if (!inSubArea) {
          this.ctx.moveTo(plot.left, chy);
          this.ctx.lineTo(plot.right, chy);
        }
        this.ctx.stroke();
        this.ctx.setLineDash([]);
      }
      if (snappedPrice > 0 && !inSubArea) {
        this._drawChip(plot.right + 2, chy,
            snappedPrice.toFixed(this._priceDecimals()));
      }
    }
    this._drawPlusIcon(plot, lo, hi, priceToY, yToPrice);

    this._drawTimeAxis(plot, visible);

    // Time chip in bottom gutter — drawn AFTER the time axis so it sits on
    // top of (and hides) any axis label directly under the cursor.
    if (this.hover.inside && this.hover.x != null) {
      const tidx = this._candleAtX(this.hover.x);
      if (tidx >= 0) {
        let label;
        if (this.candleStyle === 'renko' && tidx < this._renkoBricks.length) {
          const b = this._renkoBricks[tidx];
          label = `Brick #${b.idx} · src ${this._fmtHoverTime(b.sourceBarTime)}`;
        } else if (this._isRebinnedStyle(this.candleStyle)
            && this._rebinnedStyle === this.candleStyle
            && tidx < this._rebinned.length) {
          // Phase 26 — rebinned styles map a hovered column to its source bar
          // time (ts is carried on each pseudo-candle).
          label = this._fmtHoverTime(this._rebinned[tidx].ts);
        } else if (tidx < this.candles.length) {
          label = this._fmtHoverTime(this.candles[tidx].ts);
        } else {
          label = '';
        }
        if (label) this._drawTimeChip(this.hover.x, this.canvas.clientHeight - 18, label);
      }
    }
    this._drawOhlc(plot);
    // Indicator chips (delete/hide/settings on each active indicator) +
    // staleness pill belong to the live trade view. Both are noise in
    // the read-only explain view.
    if (!this._liteMode) {
      this._drawIndicatorChips(plot);
      this._drawStalePill(plot);
    }

    // Reset alpha and draw the loading banner on top, full-opacity.
    if (dimming) {
      this.ctx.globalAlpha = 1;
      this._drawLoadingBanner(w, h);
    }
  }

  _drawLoadingBanner(w, h) {
    if (!this._loadingTitle) return;
    this.ctx.font = '600 12px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    this.ctx.textAlign = 'center';
    const padX = 14;
    const tw = this.ctx.measureText(this._loadingTitle).width + padX * 2;
    const tH = 28;
    const x = (w - tw) / 2;
    const y = h / 2 - tH / 2;
    this.ctx.fillStyle = this.palette.crosshairChip;
    this._roundedRect(x, y, tw, tH, 6);
    this.ctx.fill();
    this.ctx.fillStyle = this.palette.chipText;
    this.ctx.fillText(this._loadingTitle, w / 2, y + tH / 2);
  }

  _priceDecimals() {
    // Derive from the scrip's tick size so e.g. an option with ti=0.05 shows
    // two decimals and an index future with ti=0.05 the same, while a
    // currency option with ti=0.0025 shows four. Minimum of 2 keeps trailing
    // zeros so the eye doesn't see jumpy widths between "1300" and "1300.05".
    const ti = (this.scrip && this.scrip.ti) || 0.05;
    if (ti >= 1) return 0;
    const s = ti.toString();
    const dot = s.indexOf('.');
    const tiDp = dot === -1 ? 0 : (s.length - dot - 1);
    return Math.max(2, tiDp);
  }

  _drawChip(x, y, text) {
    this.ctx.font = '700 10px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    const tw = this.ctx.measureText(text).width + 10;
    this.ctx.fillStyle = this.palette.crosshairChip;
    this._roundedRect(x, y - 8, Math.min(tw, 60), 16, 3);
    this.ctx.fill();
    this.ctx.fillStyle = this.palette.chipText;
    this.ctx.textAlign = 'center';
    this.ctx.fillText(text, x + Math.min(tw, 60) / 2, y);
  }

  _drawTimeChip(x, yTop, text) {
    this.ctx.font = '700 10px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    const tw = this.ctx.measureText(text).width + 12;
    const left = x - tw / 2;
    this.ctx.fillStyle = this.palette.crosshairChip;
    this._roundedRect(left, yTop, tw, 16, 3);
    this.ctx.fill();
    this.ctx.fillStyle = this.palette.chipText;
    this.ctx.textAlign = 'center';
    this.ctx.fillText(text, x, yTop + 8);
  }

  _fmtHoverTime(ts) {
    const ist = new Date(ts * 1000 + 5.5 * 3600 * 1000);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    if (this.timeframeMinutes >= 1440) {
      return ist.getUTCDate() + ' ' + months[ist.getUTCMonth()] + ' ' + ist.getUTCFullYear();
    }
    const hh = String(ist.getUTCHours()).padStart(2, '0');
    const mm = String(ist.getUTCMinutes()).padStart(2, '0');
    return ist.getUTCDate() + ' ' + months[ist.getUTCMonth()] + ' ' + hh + ':' + mm;
  }

  _roundedRect(x, y, w, h, r) {
    const rr = Math.min(r, w / 2, h / 2);
    this.ctx.beginPath();
    this.ctx.moveTo(x + rr, y);
    this.ctx.lineTo(x + w - rr, y);
    this.ctx.quadraticCurveTo(x + w, y, x + w, y + rr);
    this.ctx.lineTo(x + w, y + h - rr);
    this.ctx.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
    this.ctx.lineTo(x + rr, y + h);
    this.ctx.quadraticCurveTo(x, y + h, x, y + h - rr);
    this.ctx.lineTo(x, y + rr);
    this.ctx.quadraticCurveTo(x, y, x + rr, y);
    this.ctx.closePath();
  }

  _drawPriceAxis(plot, lo, hi) {
    // Nice-stride label algorithm — pick a "round" stride that leaves
    // ~50px between labels (matches TradingView's density). Generic over
    // any range / tick size: a SENSEX swing of 12000 points works the
    // same as a NIFTY-options swing of 50 points.
    //
    // Old implementation hard-coded multipliers of `ti` up to 5000×ti,
    // which for SILVERMIC (ti=0.05) maxed the stride at 250 — far too
    // dense for a 12k-point range. The fraction-of-power-of-10 approach
    // here scales correctly to any magnitude.
    const range = hi - lo;
    if (range <= 0) return;
    const minPx = 50;
    const pxPerUnit = plot.height / range;
    const minStepUnits = minPx / pxPerUnit;
    // Smallest power of 10 that fits inside minStepUnits — then nudge up
    // through 1× / 2× / 2.5× / 5× / 10× until we clear the threshold.
    const baseExp = Math.floor(Math.log10(minStepUnits));
    const base = Math.pow(10, baseExp);
    let stride = base * 10;
    for (const f of [1, 2, 2.5, 5, 10]) {
      if (base * f >= minStepUnits) { stride = base * f; break; }
    }
    // When the symbol has a tick size, snap the stride to a multiple of
    // it so labels land on real tradable prices. Only kicks in when the
    // stride is already larger than ti (which is the normal case — when
    // the range is too tight for that, we'd see ti-level labels anyway).
    const ti = (this.scrip && this.scrip.ti && this.scrip.ti > 0)
        ? this.scrip.ti : 0;
    if (ti > 0 && stride > ti) {
      const snapped = Math.round(stride / ti) * ti;
      if (snapped > 0) stride = snapped;
    }
    const first = Math.ceil(lo / stride) * stride;
    // Skip the axis label whose price is closest to the LTP — the LTP chip
    // covers that slot and showing both creates a "ghost" double-render.
    const ltp = this.candles.length ? this.candles[this.candles.length - 1].c : null;
    this.ctx.fillStyle = this.palette.axisText;
    this.ctx.font = '500 10px Geist, sans-serif';
    this.ctx.textAlign = 'left';
    this.ctx.textBaseline = 'middle';
    for (let p = first; p <= hi; p += stride) {
      const y = plot.top + plot.height * (hi - p) / (hi - lo);
      if (y < plot.top - 6 || y > plot.bottom + 6) continue;
      if (ltp != null && Math.abs(p - ltp) < stride / 2) continue; // covered by LTP chip
      // Skip if an indicator value chip already occupies this Y slot —
      // without this the axis label paints OVER the chip and the user can
      // only read the gutter price, not the indicator value they came for.
      let covered = false;
      if (this._axisChipSlots) {
        for (const s of this._axisChipSlots) {
          if (y >= s.top - 2 && y <= s.bottom + 2) { covered = true; break; }
        }
      }
      if (covered) continue;
      // Decimals: enough to render `stride` precisely. e.g. stride 0.05
      // needs 2 dp, 0.5 needs 1 dp, 2.5 needs 1 dp, 5+ needs 0 dp.
      const decimals = stride >= 1
          ? 0
          : stride >= 0.1
              ? 1
              : stride >= 0.01
                  ? 2
                  : 4;
      this.ctx.fillText(p.toFixed(decimals), plot.right + 4, y);
    }
  }

  _drawBidAskQtyStrip(plot) {
    this._headerHits = [];
    if (!this.scrip) return;

    const ctx = this.ctx;
    // Non-tradable detection is now API-driven: GetSecurityInfo returns
    // `nontrd:"1"` for indices / commodity spot / anything not orderable.
    // The shell pushes that result via setScripTradable(); _scripTradable
    // is false iff the API said non-tradable, true otherwise (including
    // while the API is still in flight — we default to tradable so regular
    // instruments don't flash a non-tradable header on first render).
    const isNonTradable = this._scripTradable === false;
    const instname = (this.scrip && this.scrip.instname) || '';
    const lp = this.tickState.lp;
    const bid = isNonTradable ? lp : this.tickState.bid;
    const ask = isNonTradable ? lp : this.tickState.ask;
    const dp = this._priceDecimals();

    // Layout: bid (left, tall)   center-column (spread top, qty bottom)   ask (right, tall)
    const stripY = 40;
    const tallH = 38;        // bid/ask chip height — large, button-shaped
    const halfH = 18;        // each row of the centre column
    const halfGap = 2;       // vertical gap between spread row and qty row
    const padX = 12;         // bid/ask inner padding
    const innerPadX = 8;     // centre-column inner padding
    const gap = 8;           // gap between bid|centre|ask

    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';

    let x = plot.left + 4;

    // --- Bid chip (tall) ---
    ctx.font = '700 14px Geist, sans-serif';
    const bidText = bid != null ? bid.toFixed(dp) : '—';
    const bidW = Math.max(80, ctx.measureText(bidText).width + padX * 2);
    // Use lighter alpha for non-tradable so the chip reads as informational only.
    ctx.fillStyle = isNonTradable
        ? this._withAlpha(this.palette.short, 0.30)
        : this.palette.short;
    this._roundedRect(x, stripY, bidW, tallH, 5);
    ctx.fill();
    ctx.fillStyle = isNonTradable ? this.palette.axisText : '#FFFFFF';
    ctx.fillText(bidText, x + bidW / 2, stripY + tallH / 2);
    if (bid != null && !isNonTradable) {
      this._headerHits.push({
        rect: { x, y: stripY, w: bidW, h: tallH },
        kind: 'bid', price: bid,
      });
    }
    x += bidW + gap;

    // --- Centre column (spread on top, qty below) ---
    // For non-tradable: skip the qty chip entirely (no orders possible).
    if (isNonTradable) {
      // Just a small "INDEX" / "COM" label in the middle so the strip doesn't
      // collapse and the user understands why bid==ask==LTP.
      const tag = instname === 'COM' ? 'COM' : 'INDEX';
      ctx.font = '600 10px Geist, sans-serif';
      const tagW = Math.max(56, ctx.measureText(tag).width + innerPadX * 2);
      ctx.fillStyle = this.palette.axisText;
      ctx.fillText(tag, x + tagW / 2, stripY + tallH / 2);
      x += tagW + gap;
    } else {
      // Spread + qty for tradable instruments.
      let centreW = 0;
      let spreadText = '';
      if (bid != null && ask != null) {
        spreadText = (ask - bid).toFixed(dp);
      }
      ctx.font = '500 11px Geist, sans-serif';
      const spreadTextW = spreadText
          ? ctx.measureText(spreadText).width
          : 0;

      ctx.font = '600 12px Geist, sans-serif';
      const qtyText = String(this.qty);
      const qtyTextW = ctx.measureText(qtyText).width;

      centreW = Math.max(spreadTextW, qtyTextW) + innerPadX * 2;
      if (centreW < 56) centreW = 56;

      if (spreadText) {
        ctx.font = '500 11px Geist, sans-serif';
        ctx.fillStyle = (ask - bid) < 0
            ? this.palette.short
            : this.palette.axisText;
        ctx.fillText(
            spreadText, x + centreW / 2, stripY + halfH / 2);
      }

      const qtyY = stripY + halfH + halfGap;
      ctx.fillStyle = this.palette.crosshairChip;
      this._roundedRect(x, qtyY, centreW, halfH, 4);
      ctx.fill();
      ctx.strokeStyle = this.palette.axisText;
      ctx.lineWidth = 1;
      this._roundedRect(x, qtyY, centreW, halfH, 4);
      ctx.stroke();
      ctx.font = '600 12px Geist, sans-serif';
      ctx.fillStyle = '#FFFFFF';
      ctx.fillText(qtyText, x + centreW / 2, qtyY + halfH / 2);
      this._headerHits.push({
        rect: { x, y: qtyY, w: centreW, h: halfH },
        kind: 'qty',
      });
      x += centreW + gap;
    }

    // --- Ask chip (tall) ---
    ctx.font = '700 14px Geist, sans-serif';
    const askText = ask != null ? ask.toFixed(dp) : '—';
    const askW = Math.max(80, ctx.measureText(askText).width + padX * 2);
    ctx.fillStyle = isNonTradable
        ? this._withAlpha(this.palette.long, 0.30)
        : this.palette.long;
    this._roundedRect(x, stripY, askW, tallH, 5);
    ctx.fill();
    ctx.fillStyle = isNonTradable ? this.palette.axisText : '#FFFFFF';
    ctx.fillText(askText, x + askW / 2, stripY + tallH / 2);
    if (ask != null && !isNonTradable) {
      this._headerHits.push({
        rect: { x, y: stripY, w: askW, h: tallH },
        kind: 'ask', price: ask,
      });
    }
  }

  _drawPlusIcon(plot, lo, hi, priceToY, yToPrice) {
    this._plusHit = null;
    if (!this.scrip || !this.hover.inside || this.hover.x == null) return;
    if (this._dragMode) return;
    // Skip the click-to-order `+` icon when GetSecurityInfo flagged this
    // scrip as non-tradable (indices, commodity spot, etc).
    if (this._scripTradable === false) return;
    // Snap to the scrip's tick size so the icon sits on the same y as the
    // crosshair price chip — and the price posted to Flutter is already
    // tradeable (no need for Flutter to re-snap before placing the order).
    const snappedPrice = this._snapPrice(yToPrice(this.hover.y));
    const y = priceToY(snappedPrice);
    if (y < plot.top || y > plot.bottom) return;
    const size = 16;
    // Sit INSIDE the plot, with breathing room from BOTH the right gutter
    // (price chip) and the further-left close × of overlay chips. 12px inset
    // keeps the gutter price chip readable; the chip's close × lives ~50px
    // further left, so the + icon never overlays a close button.
    const x = plot.right - size - 12;
    const top = y - size / 2;
    // Suppress the + when an overlay chip's close-box sits at this y — they
    // share the right-edge real estate and would otherwise eat each other's
    // clicks.
    for (const h of this._overlayHits) {
      if (h.action !== 'close') continue;
      const r = h.rect;
      if (top < r.y + r.h && top + size > r.y) return;
    }
    const ctx = this.ctx;
    ctx.fillStyle = this.palette.long; // accent fill so it stands out on candles
    this._roundedRect(x, top, size, size, 3);
    ctx.fill();
    ctx.strokeStyle = '#FFFFFF';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    const cx = x + size / 2, cy = y;
    ctx.moveTo(cx - 4, cy);
    ctx.lineTo(cx + 4, cy);
    ctx.moveTo(cx, cy - 4);
    ctx.lineTo(cx, cy + 4);
    ctx.stroke();
    this._plusHit = {
      rect: { x, y: top, w: size, h: size },
      price: snappedPrice,
    };
  }

  _drawPaneChip(plot) {
    if (!this.scrip) return 0;
    const tf = this._formatTimeframeLabel(this.timeframeMinutes);
    const exch = this.scrip.exch ? ' · ' + this.scrip.exch : '';
    const text = (this.scrip.dispName || this.scrip.tsym || '') + ' · ' + tf + exch;
    // 14px bold for the symbol — visual anchor of the chart. Sits over
    // transparent background; render-order is fine because OHLC line 2
    // is below it.
    this.ctx.font = '700 14px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    this.ctx.fillStyle = this.palette.axisTextStrong;
    this.ctx.textAlign = 'left';
    this.ctx.fillText(text, plot.left + 4, 16);
    return this.ctx.measureText(text).width + 12;
  }

  _formatTimeframeLabel(m) {
    if (m % 1440 === 0) return (m / 1440) + 'D';
    if (m % 60 === 0) return (m / 60) + 'h';
    return m + 'm';
  }

  _drawOhlc(plot) {
    this.ctx.textBaseline = 'middle';
    const chipY = 16;   // Line 1 — SYMBOL · TIMEFRAME (bumped to match larger font)
    const ohlcY = 30;   // Line 2 — O H L C V — tucked just under the bigger symbol

    // No opaque background strip anymore — text reads directly over the
    // candles, TradingView-style. Symbol bumped to 14px so it's the
    // visual anchor of the chart.
    let chipText = '';
    if (this.scrip) {
      chipText = (this.scrip.dispName || this.scrip.tsym || '') +
          ' · ' + this._formatTimeframeLabel(this.timeframeMinutes);
    }

    const haveCandles = this.candles.length > 0;
    let idx = -1;
    let c, dir, segs;
    if (haveCandles) {
      idx = this.candles.length - 1;
      if (this.hover.inside && this.hover.x != null) {
        const hi = this._candleAtX(this.hover.x);
        if (hi >= 0) idx = hi;
      }
      c = this.candles[idx];
      dir = c.c >= c.o ? this.palette.bull : this.palette.bear;
      segs = [
        ['O', this._fmtPrice(c.o), dir],
        ['H', this._fmtPrice(c.h), dir],
        ['L', this._fmtPrice(c.l), dir],
        ['C', this._fmtPrice(c.c), dir],
        ['V', this._fmtVol(c.v), this.palette.ohlcValue],
      ];
      const instname = (this.scrip && this.scrip.instname) || '';
      if (instname.startsWith('FUT') && this.tickState.oi != null) {
        segs.push(['OI', this._fmtVol(this.tickState.oi), this.palette.ohlcValue]);
      }
    }

    if (!chipText && !haveCandles) return;

    // Line 1 — symbol chip (the existing helper handles tinted pill)
    this._drawPaneChip(plot);

    if (!haveCandles) return;

    // Line 2 — OHLC segments. Tighter spacing + a subtle alpha so they
    // don't dominate the chart but stay readable over busy candle areas.
    let x = plot.left + 4;
    this.ctx.font = '600 11px Geist, sans-serif';
    for (const [label, value, color] of segs) {
      this.ctx.fillStyle = this._withAlpha(this.palette.ohlcLabel, 0.85);
      this.ctx.textAlign = 'left';
      this.ctx.fillText(label, x, ohlcY);
      x += this.ctx.measureText(label).width + 4;
      this.ctx.fillStyle = color;
      this.ctx.fillText(value, x, ohlcY);
      x += this.ctx.measureText(value).width + 12;
    }
    // Bid/ask/qty strip is for active trading — and on a non-tradable
    // pseudo-scrip (explain mode) it falls into the "INDEX" placeholder
    // rendering with empty BID/ASK chips. Skip it entirely in lite mode.
    if (!this._liteMode) {
      this._drawBidAskQtyStrip(plot);
    }
  }

  // ── Indicator chip strip (top-of-chart) ───────────────────────────────────
  // Sahi-style row of compact chips, one per active indicator. Each chip:
  //   [colour square] [label] [eye/hide-eye] [×]
  // Sits below the OHLC strip (y=50). Hit areas are pushed into
  // `_indicatorChipHits` and consumed by the mousedown handler.
  _indicatorLabel(ind) {
    const k = (ind.kind || '').toUpperCase();
    // Indicators without a meaningful period — show just the kind label.
    const noPeriod = new Set(['AO', 'OBV', 'ICHI', 'RIBBON']);
    if (noPeriod.has(k)) return k;
    if (ind.period && ind.period > 0) return k + ' ' + ind.period;
    return k;
  }

  _drawIndicatorChips(plot) {
    this._indicatorChipHits = [];
    this._indicatorRowRects = [];
    if (!this._indicators || this._indicators.length === 0) return;
    const ctx = this.ctx;

    // List sits BELOW the OHLC + bid/ask header strip so it never
    // overlaps the BUY chip on tradable symbols.
    const haveCandles = this.candles.length > 0;
    const stripH = this.scrip ? 84 : (haveCandles ? 40 : 24);

    ctx.save();
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';

    // Theme-aware palette for the chips. Hardcoded dark-mode values
    // (slate-900 backings, slate-200 text) were unreadable in light mode
    // where the chart bg is pure white. These resolve to readable
    // contrasts in either mode.
    const isLight = (this._basePalette && this._basePalette.bg === '#FFFFFF');
    const chipBg = isLight ? 'rgba(248,250,252,0.96)' : 'rgba(15,23,42,0.78)';
    const chipBgHover = isLight ? '#F1F5F9' : 'rgba(15,23,42,0.97)';
    const chipBorder = isLight ? '#E2E8F0' : 'rgba(148,163,184,0.28)';
    const chipBorderHover = isLight ? '#94A3B8' : 'rgba(148,163,184,0.55)';
    const textActive = this.palette.axisTextStrong;
    const textMuted = this.palette.axisText;
    const iconActive = isLight ? '#475569' : '#CBD5E1';
    const iconDim = isLight ? '#94A3B8' : '#6B7280';

    let y = stripH + 6;

    // ── Collapsed pill — TradingView-style "˅ N" minimal button ─────────
    // Default state. Click to expand.
    if (this._indicatorChipsCollapsed) {
      const label = '˅ ' + this._indicators.length;
      ctx.font = '600 11px Geist, sans-serif';
      const labelW = ctx.measureText(label).width;
      const w = labelW + 16;
      const h = 22;
      const x = plot.left + 6;
      ctx.fillStyle = chipBg;
      this._roundedRect(x, y, w, h, 4);
      ctx.fill();
      ctx.strokeStyle = chipBorder;
      ctx.lineWidth = 1;
      this._roundedRect(x, y, w, h, 4);
      ctx.stroke();
      ctx.fillStyle = textActive;
      ctx.fillText(label, x + 8, y + h / 2);
      this._indicatorChipHits.push({
        rect: { x, y, w, h },
        action: 'toggleCollapse',
      });
      ctx.restore();
      return;
    }

    // ── Expanded — clean text list per TradingView ──────────────────────
    // Each row: [color dot] [name + period] [eye] [gear] [×]. Icons
    // appear only on row hover.
    const rowH = 18;
    const dotSize = 8;
    const labelGap = 8;
    const iconW = 16;
    const iconGap = 2;

    // Header "˄ Indicators" — click to collapse back.
    {
      const label = '˄ Indicators';
      ctx.font = '600 11px Geist, sans-serif';
      const lw = ctx.measureText(label).width;
      const hw = lw + 16;
      const hx = plot.left + 6;
      ctx.fillStyle = chipBg;
      this._roundedRect(hx, y, hw, 22, 4);
      ctx.fill();
      ctx.strokeStyle = chipBorder;
      ctx.lineWidth = 1;
      this._roundedRect(hx, y, hw, 22, 4);
      ctx.stroke();
      ctx.fillStyle = textActive;
      ctx.fillText(label, hx + 8, y + 11);
      this._indicatorChipHits.push({
        rect: { x: hx, y, w: hw, h: 22 },
        action: 'toggleCollapse',
      });
      y += 22 + 4;
    }

    ctx.font = '500 11px Geist, sans-serif';

    for (const ind of this._indicators) {
      const label = this._indicatorLabel(ind);
      const indColor = ind.color || '#3B82F6';
      const textColor = ind.hidden ? textMuted : textActive;

      const x = plot.left + 6;
      const labelW = ctx.measureText(label).width;
      const rowRight = x + dotSize + labelGap + labelW + labelGap +
          iconW * 3 + iconGap * 2 + 8;
      const rowW = rowRight - x;
      const rowHovered = this._hoveredIndicatorRowId === ind.id;
      this._indicatorRowRects.push({
        rect: { x, y, w: rowW, h: rowH },
        indicatorId: ind.id,
      });

      // Row backdrop — only painted on hover. At rest the row is just
      // dot + label over the chart (TradingView style). Hover gets a
      // solid backing + border so the icons have a clean surface to
      // target against.
      if (rowHovered) {
        ctx.fillStyle = chipBgHover;
        this._roundedRect(x, y, rowW, rowH, 4);
        ctx.fill();
        ctx.strokeStyle = chipBorderHover;
        ctx.lineWidth = 1;
        this._roundedRect(x, y, rowW, rowH, 4);
        ctx.stroke();
      }

      // Color dot — keeps the indicator's own color even when hidden
      // (dimmed to a slate so the row still reads as "this is the row
      // for indicator X" even after toggling visibility off).
      const dotX = x + 6;
      const dotY = y + (rowH - dotSize) / 2;
      ctx.fillStyle = ind.hidden ? iconDim : indColor;
      ctx.beginPath();
      ctx.roundRect(dotX, dotY, dotSize, dotSize, 2);
      ctx.fill();

      // Label
      const labelX = dotX + dotSize + labelGap;
      ctx.fillStyle = textColor;
      ctx.fillText(label, labelX, y + rowH / 2);

      // Icons render only on row hover — high contrast against the
      // solidified hover backing.
      const iconsStartX = labelX + labelW + labelGap;
      const iconY = y;
      const iconColor = ind.hidden ? iconDim : iconActive;

      const drawIcon = (ix, paint) => {
        const cx = ix + iconW / 2;
        const cy = y + rowH / 2;
        paint(cx, cy);
      };

      const eyeX = iconsStartX;
      const gearX = eyeX + iconW + iconGap;
      const xIconX = gearX + iconW + iconGap;

      if (rowHovered) {
        // Eye
        drawIcon(eyeX, (cx, cy) => {
          ctx.strokeStyle = iconColor;
          ctx.lineWidth = 1.4;
          if (ind.hidden) {
            ctx.beginPath();
            ctx.ellipse(cx, cy, 5, 3, 0, 0, Math.PI * 2);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(cx - 6, cy + 4);
            ctx.lineTo(cx + 6, cy - 4);
            ctx.stroke();
          } else {
            ctx.beginPath();
            ctx.ellipse(cx, cy, 5.5, 3, 0, 0, Math.PI * 2);
            ctx.stroke();
            ctx.fillStyle = iconColor;
            ctx.beginPath();
            ctx.arc(cx, cy, 1.4, 0, Math.PI * 2);
            ctx.fill();
          }
        });
        // Gear
        drawIcon(gearX, (cx, cy) => {
          ctx.strokeStyle = iconColor;
          ctx.fillStyle = iconColor;
          ctx.lineWidth = 1.4;
          const inner = 2.6;
          const outer = 4.6;
          for (let i = 0; i < 8; i++) {
            const a = (i * Math.PI) / 4;
            const dx = Math.cos(a);
            const dy = Math.sin(a);
            ctx.beginPath();
            ctx.moveTo(cx + dx * inner, cy + dy * inner);
            ctx.lineTo(cx + dx * outer, cy + dy * outer);
            ctx.stroke();
          }
          ctx.beginPath();
          ctx.arc(cx, cy, inner, 0, Math.PI * 2);
          ctx.fill();
          ctx.save();
          ctx.globalCompositeOperation = 'destination-out';
          ctx.beginPath();
          ctx.arc(cx, cy, 1.2, 0, Math.PI * 2);
          ctx.fill();
          ctx.restore();
        });
        // × — destructive accent. Theme-aware: red-600 in light mode for
        // strong contrast on white, lighter red in dark mode.
        drawIcon(xIconX, (cx, cy) => {
          const deleteColor = ind.hidden
              ? iconDim
              : (isLight ? '#DC2626' : '#F87171');
          ctx.strokeStyle = deleteColor;
          ctx.lineWidth = 1.6;
          const xs = 4;
          ctx.beginPath();
          ctx.moveTo(cx - xs, cy - xs);
          ctx.lineTo(cx + xs, cy + xs);
          ctx.moveTo(cx + xs, cy - xs);
          ctx.lineTo(cx - xs, cy + xs);
          ctx.stroke();
        });
      }
      // Hit rects pushed regardless — keeps clicks reliable even if the
      // icons aren't rendered yet on this exact frame.
      this._indicatorChipHits.push({
        rect: { x: eyeX, y: iconY, w: iconW, h: rowH },
        indicatorId: ind.id,
        action: 'toggleHide',
      });
      this._indicatorChipHits.push({
        rect: { x: gearX, y: iconY, w: iconW, h: rowH },
        indicatorId: ind.id,
        action: 'openSettings',
      });
      this._indicatorChipHits.push({
        rect: { x: xIconX, y: iconY, w: iconW, h: rowH },
        indicatorId: ind.id,
        action: 'delete',
      });

      y += rowH;
    }
    ctx.restore();
  }

  _drawStalePill(plot) {
    if (!this._lastTickAt) return;
    const ageSec = (Date.now() - this._lastTickAt) / 1000;
    if (ageSec < 120) return;
    const text = 'Stale (' + Math.round(ageSec) + 's)';
    this.ctx.font = '700 10px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    const tw = this.ctx.measureText(text).width + 12;
    // Right-of-OHLC strip, before the price gutter.
    const x = this.canvas.clientWidth - 64 - tw - 8;
    this.ctx.fillStyle = this.palette.statusStale;
    this._roundedRect(x, 6, tw, 16, 8);
    this.ctx.fill();
    this.ctx.fillStyle = this.palette.bg;
    this.ctx.textAlign = 'center';
    this.ctx.fillText(text, x + tw / 2, 14);
  }

  _candleAtX(x) {
    if (this._seriesLength() === 0) return -1;
    // Inverse of _candleXCenter: solve for i given x.
    //   xCenter(i) = R - (N-1-i+0.5)*W + O
    //   i = N - 0.5 - (R + O - xCenter) / W
    const N = this._seriesLength();
    const plotRight = this.canvas.clientWidth - 64;
    const i = Math.round(N - 0.5 - (plotRight + this.view.offsetX - x) / this.view.cellW);
    if (i < 0 || i >= N) return -1;
    return i;
  }

  // Phase 7 — map an x pixel to a timestamp (epoch seconds). Returns the
  // nearest candle's ts for x inside the candle range; extrapolates linearly
  // by `timeframeMinutes` for x off either edge.
  _xToTs(x) {
    if (this.candles.length === 0) return Math.floor(Date.now() / 1000);
    const N = this._seriesLength();
    const plotRight = this.canvas.clientWidth - 64;
    const iFloat = N - 0.5 - (plotRight + this.view.offsetX - x) / this.view.cellW;
    const idxFloor = Math.floor(iFloat);
    if (idxFloor >= 0 && idxFloor < N) return this.candles[idxFloor].ts;
    const dtSec = Math.max(1, this.timeframeMinutes * 60);
    if (idxFloor < 0) {
      return this.candles[0].ts + Math.round(idxFloor * dtSec);
    }
    return this.candles[N - 1].ts + Math.round((idxFloor - (N - 1)) * dtSec);
  }

  // Phase 7 — map a timestamp to an x pixel using the live view. Phase 19
  // bug fix: the previous implementation assumed every bar was exactly
  // `timeframeMinutes` apart, which broke after the trading-hours filter
  // started skipping weekends/after-hours — trendline and rectangle
  // endpoints landed in the wrong X column after commit. Fix: binary-search
  // for the candle with matching ts and project from its absolute index.
  // Off-edge ts still extrapolate linearly using `timeframeMinutes`.
  _tsToX(ts, plot) {
    const bars = this.candles;
    if (bars.length === 0) return plot.left;
    const dtSec = Math.max(1, this.timeframeMinutes * 60);
    // Before-the-first-bar extrapolation.
    if (ts <= bars[0].ts) {
      const delta = (ts - bars[0].ts) / dtSec;
      return this._candleXCenter(delta, plot);
    }
    // After-the-last-bar extrapolation.
    const lastIdx = bars.length - 1;
    if (ts >= bars[lastIdx].ts) {
      const delta = (ts - bars[lastIdx].ts) / dtSec;
      return this._candleXCenter(lastIdx + delta, plot);
    }
    // Binary search for the surrounding pair, then linear interp.
    let lo = 0, hi = lastIdx;
    while (lo + 1 < hi) {
      const mid = (lo + hi) >> 1;
      if (bars[mid].ts === ts) return this._candleXCenter(mid, plot);
      if (bars[mid].ts < ts) lo = mid;
      else hi = mid;
    }
    if (bars[lo].ts === ts) return this._candleXCenter(lo, plot);
    if (bars[hi].ts === ts) return this._candleXCenter(hi, plot);
    const a = bars[lo];
    const b = bars[hi];
    const frac = (ts - a.ts) / Math.max(1, b.ts - a.ts);
    return this._candleXCenter(lo + frac, plot);
  }

  _fmtPrice(p) { return p.toFixed(2); }
  _fmtVol(v) {
    if (v < 1000) return Math.round(v).toString();
    if (v < 100000) return (v / 1000).toFixed(v < 10000 ? 1 : 0) + 'k';
    return (v / 100000).toFixed(v < 1000000 ? 1 : 0) + 'L';
  }

  // ── Phase 16 draw helpers ────────────────────────────────────────────────

  _drawCandlesCore(visible, firstVisibleAbs, plot, priceToY, opts) {
    const hollow = !!opts.hollow;
    const heikinAshi = !!opts.heikinAshi;
    let haOpenPrev = null;
    let haClosePrev = null;
    // Seed HA from the bar BEFORE the visible window so the visible run looks
    // continuous when the user pans. When the window starts at history index
    // 0 there is no prior bar — leave prev null so the loop's own fallback
    // (`(c.o + c.c) / 2`) fires for the very first bar.
    if (heikinAshi && firstVisibleAbs > 0) {
      const seedIdx = firstVisibleAbs - 1;
      if (seedIdx < this.candles.length) {
        const s = this.candles[seedIdx];
        haOpenPrev = (s.o + s.c) / 2;
        haClosePrev = (s.o + s.h + s.l + s.c) / 4;
      }
    }
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      let o = c.o, h = c.h, l = c.l, cl = c.c;
      if (heikinAshi) {
        const haClose = (c.o + c.h + c.l + c.c) / 4;
        const haOpen  = haOpenPrev == null ? (c.o + c.c) / 2 : (haOpenPrev + haClosePrev) / 2;
        const haHigh  = Math.max(c.h, haOpen, haClose);
        const haLow   = Math.min(c.l, haOpen, haClose);
        o = haOpen; h = haHigh; l = haLow; cl = haClose;
        haOpenPrev = haOpen; haClosePrev = haClose;
      }
      const absoluteIdx = firstVisibleAbs + i;
      const xCenter = this._candleXCenter(absoluteIdx, plot);
      const isBull = cl >= o;
      const color = isBull ? this.palette.bull : this.palette.bear;
      // Wick.
      this.ctx.fillStyle = color;
      this.ctx.fillRect(Math.round(xCenter), priceToY(h), 1, priceToY(l) - priceToY(h));
      // Body.
      const bodyTop = Math.min(priceToY(o), priceToY(cl));
      const bodyBot = Math.max(priceToY(o), priceToY(cl));
      const bodyW = Math.max(1, this.view.cellW - 2);
      const bodyH = Math.max(1, bodyBot - bodyTop);
      if (hollow && isBull) {
        this.ctx.strokeStyle = color;
        this.ctx.lineWidth = 1.25;
        this.ctx.strokeRect(
            Math.round(xCenter - bodyW / 2) + 0.5,
            bodyTop + 0.5, bodyW - 1, Math.max(1, bodyH - 1));
      } else {
        this.ctx.fillStyle = color;
        this.ctx.fillRect(Math.round(xCenter - bodyW / 2), bodyTop, bodyW, bodyH);
      }
    }
    // Persist HA tail so the next draw() picks up where we left off (only
    // matters when style stays HA and the user nudges via tick).
    if (heikinAshi) this._haPrev = { haOpen: haOpenPrev, haClose: haClosePrev };
  }

  _drawBarsOHLC(visible, firstVisibleAbs, plot, priceToY) {
    const tickLen = Math.max(2, Math.floor(this.view.cellW / 2));
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const xCenter = Math.round(this._candleXCenter(firstVisibleAbs + i, plot));
      const isBull = c.c >= c.o;
      const color = isBull ? this.palette.bull : this.palette.bear;
      this.ctx.strokeStyle = color;
      this.ctx.lineWidth = 1.2;
      this.ctx.beginPath();
      // Vertical H..L.
      this.ctx.moveTo(xCenter + 0.5, priceToY(c.h));
      this.ctx.lineTo(xCenter + 0.5, priceToY(c.l));
      // Open tick LEFT.
      const yo = priceToY(c.o);
      this.ctx.moveTo(xCenter - tickLen + 0.5, yo);
      this.ctx.lineTo(xCenter + 0.5, yo);
      // Close tick RIGHT.
      const yc = priceToY(c.c);
      this.ctx.moveTo(xCenter + 0.5, yc);
      this.ctx.lineTo(xCenter + tickLen + 0.5, yc);
      this.ctx.stroke();
    }
  }

  _drawLineSeries(visible, firstVisibleAbs, plot, priceToY) {
    if (visible.length === 0) return;
    this.ctx.strokeStyle = this.palette.accent || this.palette.bull;
    this.ctx.lineWidth = 1.5;
    this.ctx.beginPath();
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const x = this._candleXCenter(firstVisibleAbs + i, plot);
      const y = priceToY(c.c);
      if (i === 0) this.ctx.moveTo(x, y);
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
  }

  _drawAreaSeries(visible, firstVisibleAbs, plot, priceToY) {
    if (visible.length === 0) return;
    const stroke = this.palette.accent || this.palette.bull;
    const xs = new Array(visible.length);
    const ys = new Array(visible.length);
    for (let i = 0; i < visible.length; i++) {
      xs[i] = this._candleXCenter(firstVisibleAbs + i, plot);
      ys[i] = priceToY(visible[i].c);
    }
    // Fill polygon.
    const grad = this.ctx.createLinearGradient(0, plot.top, 0, plot.bottom);
    grad.addColorStop(0, this._withAlpha(stroke, 0.35));
    grad.addColorStop(1, this._withAlpha(stroke, 0.02));
    this.ctx.fillStyle = grad;
    this.ctx.beginPath();
    this.ctx.moveTo(xs[0], plot.bottom);
    for (let i = 0; i < xs.length; i++) this.ctx.lineTo(xs[i], ys[i]);
    this.ctx.lineTo(xs[xs.length - 1], plot.bottom);
    this.ctx.closePath();
    this.ctx.fill();
    // Stroke on top.
    this.ctx.strokeStyle = stroke;
    this.ctx.lineWidth = 1.5;
    this.ctx.beginPath();
    for (let i = 0; i < xs.length; i++) {
      if (i === 0) this.ctx.moveTo(xs[i], ys[i]);
      else this.ctx.lineTo(xs[i], ys[i]);
    }
    this.ctx.stroke();
  }

  _withAlpha(hexOrRgba, a) {
    // Accept #RGB, #RRGGBB, or rgba(...) and return rgba with alpha override.
    const s = String(hexOrRgba || '').trim();
    if (s.startsWith('#')) {
      let r, g, b;
      if (s.length === 4) {
        r = parseInt(s[1] + s[1], 16);
        g = parseInt(s[2] + s[2], 16);
        b = parseInt(s[3] + s[3], 16);
      } else {
        r = parseInt(s.slice(1, 3), 16);
        g = parseInt(s.slice(3, 5), 16);
        b = parseInt(s.slice(5, 7), 16);
      }
      return `rgba(${r},${g},${b},${a})`;
    }
    const m = s.match(/^rgba?\(([^,]+),([^,]+),([^,]+)(?:,[^)]+)?\)$/);
    if (m) return `rgba(${m[1].trim()},${m[2].trim()},${m[3].trim()},${a})`;
    // Fallback — return as-is.
    return s;
  }

  _drawRenko(plot, priceToY) {
    const bricks = this._renkoBricks;
    if (!bricks || bricks.length === 0) return;
    // After Step 0, view.firstVisible / view.lastVisible are bounded by
    // _seriesLength() — i.e. the brick count when on Renko. Clamp anyway as
    // a belt-and-braces guard.
    const total = bricks.length;
    const firstVisible = Math.max(0,
        Math.floor(this.view.firstVisible != null ? this.view.firstVisible : 0));
    const lastVisible = Math.min(total - 1,
        Math.ceil(this.view.lastVisible != null ? this.view.lastVisible : total - 1));
    if (firstVisible > lastVisible) return;
    const bodyW = Math.max(1, this.view.cellW - 2);
    for (let i = firstVisible; i <= lastVisible; i++) {
      const b = bricks[i];
      const xCenter = this._candleXCenter(i, plot); // brick idx → X
      const color = b.direction === 'up' ? this.palette.bull : this.palette.bear;
      this.ctx.fillStyle = color;
      const yTop = Math.min(priceToY(b.openPrice), priceToY(b.closePrice));
      const yBot = Math.max(priceToY(b.openPrice), priceToY(b.closePrice));
      const h = Math.max(1, yBot - yTop);
      this.ctx.fillRect(
          Math.round(xCenter - bodyW / 2), yTop, bodyW, h);
    }
  }

  _seriesLength() {
    if (this.candleStyle === 'renko') return this._renkoBricks.length;
    if (this._isRebinnedStyle(this.candleStyle)
        && this._rebinnedStyle === this.candleStyle
        && this._rebinned.length > 0) {
      return this._rebinned.length;
    }
    return this.candles.length;
  }

  _isRebinnedStyle(style) {
    return style === 'linebreak' || style === 'kagi'
        || style === 'range' || style === 'pnf';
  }

  // ── Phase 16 F1 — Renko transform pipeline ───────────────────────────────

  _computeRenkoBrickSize() {
    const bars = this.candles;
    const ti = (this.scrip && this.scrip.ti) || 0.05;
    if (!bars || bars.length === 0) return ti;
    // Standard ATR(14). True Range = max(H-L, |H-prevC|, |L-prevC|).
    const period = 14;
    const n = Math.min(bars.length, period * 4); // window the ATR
    if (bars.length < period) {
      // Fallback: range / count.
      let hi = -Infinity, lo = Infinity;
      for (const c of bars) { if (c.h > hi) hi = c.h; if (c.l < lo) lo = c.l; }
      const r = (hi - lo) / Math.max(1, bars.length);
      return this._snapToTick(Math.max(ti, r), ti);
    }
    let trSum = 0; let trCount = 0;
    const start = bars.length - n;
    for (let i = Math.max(1, start); i < bars.length; i++) {
      const c = bars[i]; const p = bars[i - 1];
      const tr = Math.max(c.h - c.l, Math.abs(c.h - p.c), Math.abs(c.l - p.c));
      trSum += tr; trCount += 1;
    }
    const atr = trCount > 0 ? trSum / trCount : ti;
    return this._snapToTick(Math.max(ti, atr), ti);
  }

  _snapToTick(value, tick) {
    if (!isFinite(tick) || tick <= 0) return value;
    return Math.max(tick, Math.round(value / tick) * tick);
  }

  _rebuildRenko() {
    this._renkoBricks = [];
    const bars = this.candles;
    if (!bars || bars.length === 0) {
      this._renkoBrickSize = 0;
      return;
    }
    const size = this._computeRenkoBrickSize();
    this._renkoBrickSize = size;
    const first = bars[0];
    let last = {
      idx: 0,
      openPrice: first.c,
      closePrice: first.c,
      direction: 'up',
      sourceBarTime: first.ts,
      sourceBarIndex: 0,
    };
    this._renkoBricks.push(last);
    for (let i = 1; i < bars.length; i++) {
      last = this._appendBricksForPrice(bars[i].c, last, size, bars[i].ts, i);
    }
  }

  // Returns the new "last brick" after appending zero or more bricks driven
  // by `price`. Implements the classic Renko reversal rule (need 2*size in
  // the opposite direction to reverse).
  _appendBricksForPrice(price, last, size, sourceBarTime, sourceBarIndex) {
    if (!isFinite(price) || size <= 0) return last;
    let cur = last;
    while (true) {
      if (cur.direction === 'up') {
        if (price >= cur.closePrice + size) {
          const next = {
            idx: cur.idx + 1,
            openPrice: cur.closePrice,
            closePrice: cur.closePrice + size,
            direction: 'up',
            sourceBarTime, sourceBarIndex,
          };
          this._renkoBricks.push(next); cur = next; continue;
        }
        if (price <= cur.closePrice - 2 * size) {
          const next = {
            idx: cur.idx + 1,
            openPrice: cur.closePrice - size,
            closePrice: cur.closePrice - 2 * size,
            direction: 'down',
            sourceBarTime, sourceBarIndex,
          };
          this._renkoBricks.push(next); cur = next; continue;
        }
        break;
      } else { // 'down'
        if (price <= cur.closePrice - size) {
          const next = {
            idx: cur.idx + 1,
            openPrice: cur.closePrice,
            closePrice: cur.closePrice - size,
            direction: 'down',
            sourceBarTime, sourceBarIndex,
          };
          this._renkoBricks.push(next); cur = next; continue;
        }
        if (price >= cur.closePrice + 2 * size) {
          const next = {
            idx: cur.idx + 1,
            openPrice: cur.closePrice + size,
            closePrice: cur.closePrice + 2 * size,
            direction: 'up',
            sourceBarTime, sourceBarIndex,
          };
          this._renkoBricks.push(next); cur = next; continue;
        }
        break;
      }
    }
    return cur;
  }

  _updateRenkoFromTick(price) {
    if (this.candleStyle !== 'renko') return;
    if (!this._renkoBricks.length || this._renkoBrickSize <= 0) return;
    const last = this._renkoBricks[this._renkoBricks.length - 1];
    const newLast = this._appendBricksForPrice(
        price, last, this._renkoBrickSize,
        Math.floor(Date.now() / 1000),
        this.candles.length - 1);
    if (newLast !== last) this.scheduleRedraw();
  }

  // ── Phase 26 — additional chart styles ────────────────────────────────────

  // 1) Baseline — area split at a baseline (first visible close). Green
  //    fill+line above the baseline, red fill+line below it.
  _drawBaseline(visible, firstVisibleAbs, plot, priceToY) {
    if (visible.length === 0) return;
    const baseline = visible[0].c;
    const baseY = priceToY(baseline);
    const up = this.palette.bull;
    const down = this.palette.bear;
    const xs = new Array(visible.length);
    const ys = new Array(visible.length);
    for (let i = 0; i < visible.length; i++) {
      xs[i] = this._candleXCenter(firstVisibleAbs + i, plot);
      ys[i] = priceToY(visible[i].c);
    }
    // Build the close polyline once.
    const tracePath = () => {
      this.ctx.beginPath();
      for (let i = 0; i < xs.length; i++) {
        if (i === 0) this.ctx.moveTo(xs[i], ys[i]);
        else this.ctx.lineTo(xs[i], ys[i]);
      }
    };
    // Fill ABOVE baseline (green), clipped to the region above baseY.
    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.rect(plot.left, plot.top, plot.right - plot.left, baseY - plot.top);
    this.ctx.clip();
    this.ctx.fillStyle = this._withAlpha(up, 0.22);
    this.ctx.beginPath();
    this.ctx.moveTo(xs[0], baseY);
    for (let i = 0; i < xs.length; i++) this.ctx.lineTo(xs[i], ys[i]);
    this.ctx.lineTo(xs[xs.length - 1], baseY);
    this.ctx.closePath();
    this.ctx.fill();
    this.ctx.restore();
    // Fill BELOW baseline (red).
    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.rect(plot.left, baseY, plot.right - plot.left, plot.bottom - baseY);
    this.ctx.clip();
    this.ctx.fillStyle = this._withAlpha(down, 0.22);
    this.ctx.beginPath();
    this.ctx.moveTo(xs[0], baseY);
    for (let i = 0; i < xs.length; i++) this.ctx.lineTo(xs[i], ys[i]);
    this.ctx.lineTo(xs[xs.length - 1], baseY);
    this.ctx.closePath();
    this.ctx.fill();
    this.ctx.restore();
    // Stroke the line in two colours by clipping above/below the baseline.
    this.ctx.lineWidth = 1.5;
    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.rect(plot.left, plot.top, plot.right - plot.left, baseY - plot.top);
    this.ctx.clip();
    this.ctx.strokeStyle = up; tracePath(); this.ctx.stroke();
    this.ctx.restore();
    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.rect(plot.left, baseY, plot.right - plot.left, plot.bottom - baseY);
    this.ctx.clip();
    this.ctx.strokeStyle = down; tracePath(); this.ctx.stroke();
    this.ctx.restore();
    // Baseline reference line.
    this.ctx.strokeStyle = this.palette.gridSoft;
    this.ctx.lineWidth = 1;
    this.ctx.setLineDash([3, 3]);
    this.ctx.beginPath();
    this.ctx.moveTo(plot.left, baseY); this.ctx.lineTo(plot.right, baseY);
    this.ctx.stroke();
    this.ctx.setLineDash([]);
  }

  // 2) Step line — close drawn as horizontal steps (hold then jump).
  _drawStepLine(visible, firstVisibleAbs, plot, priceToY) {
    if (visible.length === 0) return;
    this.ctx.strokeStyle = this.palette.accent || this.palette.bull;
    this.ctx.lineWidth = 1.5;
    this.ctx.beginPath();
    let prevY = null;
    for (let i = 0; i < visible.length; i++) {
      const x = this._candleXCenter(firstVisibleAbs + i, plot);
      const y = priceToY(visible[i].c);
      if (i === 0) {
        this.ctx.moveTo(x, y);
      } else {
        // Horizontal hold from prev x to current x at the prev level, then
        // a vertical jump to the new level.
        this.ctx.lineTo(x, prevY);
        this.ctx.lineTo(x, y);
      }
      prevY = y;
    }
    this.ctx.stroke();
  }

  // 3) Columns — thin vertical bars baseline→close, coloured up/down vs the
  //    previous close. Baseline is the lowest visible close so bars read as
  //    a column histogram of the close series.
  _drawColumns(visible, firstVisibleAbs, plot, priceToY) {
    if (visible.length === 0) return;
    let minC = Infinity;
    for (const c of visible) if (c.c < minC) minC = c.c;
    const baseY = priceToY(minC);
    const bodyW = Math.max(1, Math.min(this.view.cellW - 2, 6));
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const prevC = i > 0 ? visible[i - 1].c
          : (firstVisibleAbs > 0 ? this.candles[firstVisibleAbs - 1].c : c.c);
      const isUp = c.c >= prevC;
      this.ctx.fillStyle = isUp ? this.palette.bull : this.palette.bear;
      const x = this._candleXCenter(firstVisibleAbs + i, plot);
      const yTop = priceToY(c.c);
      const h = Math.max(1, baseY - yTop);
      this.ctx.fillRect(Math.round(x - bodyW / 2), yTop, bodyW, h);
    }
  }

  // 4) HLC bars — high-low vertical + right close tick only (no open tick).
  _drawHlcBars(visible, firstVisibleAbs, plot, priceToY) {
    const tickLen = Math.max(2, Math.floor(this.view.cellW / 2));
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const xCenter = Math.round(this._candleXCenter(firstVisibleAbs + i, plot));
      const prevC = i > 0 ? visible[i - 1].c
          : (firstVisibleAbs > 0 ? this.candles[firstVisibleAbs - 1].c : c.o);
      const isUp = c.c >= prevC;
      this.ctx.strokeStyle = isUp ? this.palette.bull : this.palette.bear;
      this.ctx.lineWidth = 1.2;
      this.ctx.beginPath();
      this.ctx.moveTo(xCenter + 0.5, priceToY(c.h));
      this.ctx.lineTo(xCenter + 0.5, priceToY(c.l));
      const yc = priceToY(c.c);
      this.ctx.moveTo(xCenter + 0.5, yc);
      this.ctx.lineTo(xCenter + tickLen + 0.5, yc);
      this.ctx.stroke();
    }
  }

  // 5) High-Low — high-low vertical line only, coloured up/down vs prev close.
  _drawHighLow(visible, firstVisibleAbs, plot, priceToY) {
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const xCenter = Math.round(this._candleXCenter(firstVisibleAbs + i, plot));
      const prevC = i > 0 ? visible[i - 1].c
          : (firstVisibleAbs > 0 ? this.candles[firstVisibleAbs - 1].c : c.o);
      const isUp = c.c >= prevC;
      this.ctx.strokeStyle = isUp ? this.palette.bull : this.palette.bear;
      this.ctx.lineWidth = 1.4;
      this.ctx.beginPath();
      this.ctx.moveTo(xCenter + 0.5, priceToY(c.h));
      this.ctx.lineTo(xCenter + 0.5, priceToY(c.l));
      this.ctx.stroke();
    }
  }

  // 6) HLC area — translucent band between high & low + a close line.
  _drawHlcArea(visible, firstVisibleAbs, plot, priceToY) {
    if (visible.length === 0) return;
    const stroke = this.palette.accent || this.palette.bull;
    const xs = new Array(visible.length);
    const yh = new Array(visible.length);
    const yl = new Array(visible.length);
    const yc = new Array(visible.length);
    for (let i = 0; i < visible.length; i++) {
      xs[i] = this._candleXCenter(firstVisibleAbs + i, plot);
      yh[i] = priceToY(visible[i].h);
      yl[i] = priceToY(visible[i].l);
      yc[i] = priceToY(visible[i].c);
    }
    // Band polygon: highs left→right, then lows right→left.
    this.ctx.fillStyle = this._withAlpha(stroke, 0.16);
    this.ctx.beginPath();
    this.ctx.moveTo(xs[0], yh[0]);
    for (let i = 1; i < xs.length; i++) this.ctx.lineTo(xs[i], yh[i]);
    for (let i = xs.length - 1; i >= 0; i--) this.ctx.lineTo(xs[i], yl[i]);
    this.ctx.closePath();
    this.ctx.fill();
    // Close line on top.
    this.ctx.strokeStyle = stroke;
    this.ctx.lineWidth = 1.5;
    this.ctx.beginPath();
    for (let i = 0; i < xs.length; i++) {
      if (i === 0) this.ctx.moveTo(xs[i], yc[i]);
      else this.ctx.lineTo(xs[i], yc[i]);
    }
    this.ctx.stroke();
  }

  // 7) Volume candles — candles whose body width scales with volume relative
  //    to the visible rolling max. Wick stays 1px; only the body breathes.
  _drawVolCandles(visible, firstVisibleAbs, plot, priceToY) {
    let maxV = 0;
    for (const c of visible) if (c.v > maxV) maxV = c.v;
    const fullW = Math.max(1, this.view.cellW - 2);
    const minW = Math.max(1, fullW * 0.2);
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const absoluteIdx = firstVisibleAbs + i;
      const xCenter = this._candleXCenter(absoluteIdx, plot);
      const isBull = c.c >= c.o;
      const color = isBull ? this.palette.bull : this.palette.bear;
      // Wick.
      this.ctx.fillStyle = color;
      this.ctx.fillRect(Math.round(xCenter), priceToY(c.h), 1, priceToY(c.l) - priceToY(c.h));
      // Body width scaled by volume share.
      const frac = maxV > 0 ? (c.v / maxV) : 1;
      const bodyW = Math.max(minW, fullW * frac);
      const bodyTop = Math.min(priceToY(c.o), priceToY(c.c));
      const bodyBot = Math.max(priceToY(c.o), priceToY(c.c));
      const bodyH = Math.max(1, bodyBot - bodyTop);
      this.ctx.fillRect(Math.round(xCenter - bodyW / 2), bodyTop, bodyW, bodyH);
    }
  }

  // ── Phase 26 — rebinned styles (mirror the renko pipeline) ────────────────

  // Build this._rebinned for the current style. Each element is a pseudo-candle
  // {o,h,l,c,v,ts,direction} so the shared draw helpers + _seriesLength() work.
  _rebuildRebinned() {
    this._rebinned = [];
    this._rebinnedStyle = this.candleStyle;
    const bars = this.candles;
    if (!bars || bars.length === 0) return;
    switch (this.candleStyle) {
      case 'linebreak': this._rebinned = this._buildLineBreak(bars); break;
      case 'kagi':      this._rebinned = this._buildKagi(bars); break;
      case 'range':     this._rebinned = this._buildRange(bars); break;
      case 'pnf':       this._rebinned = this._buildPnf(bars); break;
      default:          this._rebinned = []; this._rebinnedStyle = null; break;
    }
  }

  // Three Line Break: a new line is drawn when the close exceeds the extreme
  // of the prior `lines` (3) lines; a reversal needs to exceed the extreme of
  // the last `lines` lines in the opposite direction. Otherwise no new line.
  _buildLineBreak(bars, lines = 3) {
    const out = [];
    let dir = 0; // +1 up, -1 down, 0 unset
    for (let i = 0; i < bars.length; i++) {
      const close = bars[i].c;
      const ts = bars[i].ts;
      if (out.length === 0) {
        // Seed from the first two distinct closes.
        if (i === 0) continue;
        const open = bars[0].c;
        if (close === open) continue;
        dir = close > open ? 1 : -1;
        out.push({
          o: open, c: close,
          h: Math.max(open, close), l: Math.min(open, close),
          v: 0, ts, direction: dir > 0 ? 'up' : 'down',
        });
        continue;
      }
      const last = out[out.length - 1];
      if (dir > 0) {
        if (close > last.c) {
          out.push(this._lbLine(last.c, close, ts, 'up'));
        } else {
          // Reversal needs to break the low of the last `lines` lines.
          const lookback = out.slice(Math.max(0, out.length - lines));
          let minLow = Infinity;
          for (const ln of lookback) if (ln.l < minLow) minLow = ln.l;
          if (close < minLow) {
            dir = -1;
            out.push(this._lbLine(last.l, close, ts, 'down'));
          }
        }
      } else {
        if (close < last.c) {
          out.push(this._lbLine(last.c, close, ts, 'down'));
        } else {
          const lookback = out.slice(Math.max(0, out.length - lines));
          let maxHigh = -Infinity;
          for (const ln of lookback) if (ln.h > maxHigh) maxHigh = ln.h;
          if (close > maxHigh) {
            dir = 1;
            out.push(this._lbLine(last.h, close, ts, 'up'));
          }
        }
      }
    }
    return out;
  }

  _lbLine(open, close, ts, direction) {
    return {
      o: open, c: close,
      h: Math.max(open, close), l: Math.min(open, close),
      v: 0, ts, direction,
    };
  }

  // Kagi: a continuous line that reverses only when price moves against the
  // current direction by at least `reversal` (default ~4% of price). Rendered
  // as pseudo-candles (one per leg); thick (yang) once price clears the prior
  // shoulder high, thin (yin) once it breaks the prior shoulder low. We encode
  // thickness in `direction` ('up' = yang/thick, 'down' = yin/thin) at draw
  // time via the leg's own trend, and store the leg endpoints in o/c.
  _buildKagi(bars) {
    if (bars.length < 2) return [];
    // Reversal threshold = ATR-based brick size (same scale as Renko), NOT a
    // fixed % of price — a 4% reversal on an intraday index is ~hundreds of
    // points, so the line almost never reverses and looks empty.
    const ti = (this.scrip && this.scrip.ti) || 0.05;
    const reversal = Math.max(ti, this._computeRenkoBrickSize());
    const out = [];
    let trend = 0; // +1 rising, -1 falling
    let anchor = bars[0].c; // start of the current leg
    let extreme = bars[0].c; // current leg extreme (high if rising, low if falling)
    let ts0 = bars[0].ts;
    for (let i = 1; i < bars.length; i++) {
      const p = bars[i].c;
      const ts = bars[i].ts;
      if (trend === 0) {
        if (p >= anchor + reversal) { trend = 1; extreme = p; }
        else if (p <= anchor - reversal) { trend = -1; extreme = p; }
        continue;
      }
      if (trend > 0) {
        if (p > extreme) { extreme = p; }
        else if (p <= extreme - reversal) {
          // Reversal down: close the rising leg, start a falling leg.
          out.push(this._kagiLeg(anchor, extreme, ts0, 'up'));
          anchor = extreme; extreme = p; trend = -1; ts0 = ts;
        }
      } else {
        if (p < extreme) { extreme = p; }
        else if (p >= extreme + reversal) {
          out.push(this._kagiLeg(anchor, extreme, ts0, 'down'));
          anchor = extreme; extreme = p; trend = 1; ts0 = ts;
        }
      }
    }
    // Flush the final in-progress leg.
    if (trend !== 0) {
      out.push(this._kagiLeg(anchor, extreme, ts0, trend > 0 ? 'up' : 'down'));
    }
    return out;
  }

  _kagiLeg(from, to, ts, direction) {
    return {
      o: from, c: to,
      h: Math.max(from, to), l: Math.min(from, to),
      v: 0, ts, direction,
    };
  }

  _medianClose(bars) {
    const cs = bars.map((b) => b.c).filter((v) => isFinite(v)).sort((a, b) => a - b);
    if (cs.length === 0) return 1;
    const mid = Math.floor(cs.length / 2);
    return cs.length % 2 ? cs[mid] : (cs[mid - 1] + cs[mid]) / 2;
  }

  // Range bars: a new bar is emitted each time price travels a fixed amount
  // (the range size) from the current bar's open. Size auto-derived from ATR
  // (reusing _computeRenkoBrickSize, which is ATR(14) snapped to tick).
  _buildRange(bars) {
    const size = this._computeRenkoBrickSize();
    if (!isFinite(size) || size <= 0) return [];
    const out = [];
    let cur = null;
    const start = (o, ts) => ({ o, h: o, l: o, c: o, v: 0, ts, direction: 'up' });
    for (let i = 0; i < bars.length; i++) {
      const b = bars[i];
      // Drive the range engine with H/L/C of each source bar so intrabar
      // travel still forms bars. Use close as the dominant driver.
      const prices = [b.o, (b.c >= b.o ? b.l : b.h), (b.c >= b.o ? b.h : b.l), b.c];
      for (const price of prices) {
        if (!isFinite(price)) continue;
        if (cur === null) { cur = start(price, b.ts); continue; }
        if (price > cur.h) cur.h = price;
        if (price < cur.l) cur.l = price;
        cur.c = price;
        cur.v += 0;
        while (cur.h - cur.l >= size) {
          // Close a bar spanning exactly `size` from the open in the travel
          // direction, then seed the next from the breakout level.
          const up = price >= cur.o;
          const close = up ? cur.o + size : cur.o - size;
          out.push({
            o: cur.o, c: close,
            h: up ? close : cur.h, l: up ? cur.l : close,
            v: 0, ts: b.ts, direction: up ? 'up' : 'down',
          });
          cur = start(close, b.ts);
        }
      }
    }
    if (cur && cur.h !== cur.l) {
      cur.direction = cur.c >= cur.o ? 'up' : 'down';
      out.push(cur);
    }
    return out;
  }

  // Point & Figure: X (up) / O (down) columns. Box size ~% of median price (or
  // ATR), reversal = 3 boxes. We rebin into pseudo-candles where each element
  // is a column spanning [low,high] with direction up (X) / down (O). The
  // dedicated drawer renders X/O glyphs across the column's box range.
  _buildPnf(bars, reversalBoxes = 3) {
    const box = this._computeRenkoBrickSize(); // ATR-snapped; reused as box size.
    if (!isFinite(box) || box <= 0) return [];
    const boxes = (p) => Math.floor(p / box); // box index for a price
    const out = [];
    let dir = 0;            // +1 X column, -1 O column
    let topBox = null;      // highest box filled in current X column
    let botBox = null;      // lowest box filled in current O column
    const pushCol = (lowBox, highBox, direction, ts) => {
      out.push({
        o: lowBox * box, c: highBox * box,
        l: lowBox * box, h: highBox * box,
        v: 0, ts, direction,
        boxSize: box, lowBox, highBox,
      });
    };
    for (let i = 0; i < bars.length; i++) {
      const b = bars[i];
      const hiB = boxes(b.h);
      const loB = boxes(b.l);
      if (dir === 0) {
        // Seed: prefer an up column.
        dir = 1; topBox = hiB; botBox = loB;
        continue;
      }
      if (dir > 0) {
        if (hiB > topBox) {
          topBox = hiB; // extend the X column
        } else if (loB <= topBox - reversalBoxes) {
          // Reverse down: close X column, open O column one box below the top.
          pushCol(botBox != null ? botBox : (topBox - (hiB - loB)), topBox, 'up',
              b.ts);
          dir = -1; botBox = loB; topBox = null;
        }
      } else {
        if (loB < botBox) {
          botBox = loB; // extend the O column
        } else if (hiB >= botBox + reversalBoxes) {
          pushCol(botBox, topBox != null ? topBox : (botBox + (hiB - loB)), 'down',
              b.ts);
          dir = 1; topBox = hiB; botBox = null;
        }
      }
    }
    // Flush the final column.
    if (dir > 0 && topBox != null) {
      pushCol(botBox != null ? botBox : topBox - 1, topBox, 'up',
          bars[bars.length - 1].ts);
    } else if (dir < 0 && botBox != null) {
      pushCol(botBox, topBox != null ? topBox : botBox + 1, 'down',
          bars[bars.length - 1].ts);
    }
    return out;
  }

  // Generic drawer for rebinned pseudo-candles (linebreak / range). Mirrors
  // _drawRenko: iterates this._rebinned by index using _candleXCenter(i).
  _drawRebinnedCandles(plot, priceToY, opts) {
    const arr = this._rebinned;
    if (!arr || arr.length === 0) return;
    const total = arr.length;
    const firstVisible = Math.max(0,
        Math.floor(this.view.firstVisible != null ? this.view.firstVisible : 0));
    const lastVisible = Math.min(total - 1,
        Math.ceil(this.view.lastVisible != null ? this.view.lastVisible : total - 1));
    if (firstVisible > lastVisible) return;
    const bodyW = Math.max(1, this.view.cellW - 2);
    for (let i = firstVisible; i <= lastVisible; i++) {
      const b = arr[i];
      const xCenter = this._candleXCenter(i, plot);
      const color = b.direction === 'up' ? this.palette.bull : this.palette.bear;
      this.ctx.fillStyle = color;
      const yTop = Math.min(priceToY(b.o), priceToY(b.c));
      const yBot = Math.max(priceToY(b.o), priceToY(b.c));
      const h = Math.max(1, yBot - yTop);
      this.ctx.fillRect(Math.round(xCenter - bodyW / 2), yTop, bodyW, h);
    }
  }

  // Kagi line drawer — connects leg endpoints with a stepped line. Thick when
  // the leg rises (yang), thin when it falls (yin); colour follows direction.
  _drawKagi(plot, priceToY) {
    const arr = this._rebinned;
    if (!arr || arr.length === 0) return;
    const total = arr.length;
    const firstVisible = Math.max(0,
        Math.floor(this.view.firstVisible != null ? this.view.firstVisible : 0));
    const lastVisible = Math.min(total - 1,
        Math.ceil(this.view.lastVisible != null ? this.view.lastVisible : total - 1));
    if (firstVisible > lastVisible) return;
    for (let i = firstVisible; i <= lastVisible; i++) {
      const b = arr[i];
      const x = this._candleXCenter(i, plot);
      const yFrom = priceToY(b.o);
      const yTo = priceToY(b.c);
      const isUp = b.direction === 'up';
      this.ctx.strokeStyle = isUp ? this.palette.bull : this.palette.bear;
      this.ctx.lineWidth = isUp ? 2.4 : 1.0; // yang thick, yin thin
      this.ctx.beginPath();
      // Horizontal connector from the previous leg's x, then the vertical leg.
      if (i > firstVisible) {
        const xPrev = this._candleXCenter(i - 1, plot);
        this.ctx.moveTo(xPrev, yFrom);
        this.ctx.lineTo(x, yFrom);
      } else {
        this.ctx.moveTo(x, yFrom);
      }
      this.ctx.lineTo(x, yTo);
      this.ctx.stroke();
    }
  }

  // Point & Figure drawer — renders X (up) / O (down) glyphs stacked across
  // each column's box range. One glyph per box between low and high.
  _drawPnf(plot, priceToY) {
    const arr = this._rebinned;
    if (!arr || arr.length === 0) return;
    const total = arr.length;
    const firstVisible = Math.max(0,
        Math.floor(this.view.firstVisible != null ? this.view.firstVisible : 0));
    const lastVisible = Math.min(total - 1,
        Math.ceil(this.view.lastVisible != null ? this.view.lastVisible : total - 1));
    if (firstVisible > lastVisible) return;
    const cellW = Math.max(2, this.view.cellW - 2);
    const half = cellW / 2;
    for (let i = firstVisible; i <= lastVisible; i++) {
      const b = arr[i];
      const x = this._candleXCenter(i, plot);
      const isUp = b.direction === 'up';
      const box = b.boxSize || (b.h - b.l) || 1;
      this.ctx.strokeStyle = isUp ? this.palette.bull : this.palette.bear;
      this.ctx.lineWidth = 1.4;
      // Iterate box rows from low to high (inclusive).
      for (let price = b.l; price <= b.h + 1e-9; price += box) {
        const yMid = priceToY(price + box / 2);
        const yTop = priceToY(price + box);
        const yBot = priceToY(price);
        if (isUp) {
          // X — two diagonals across the box cell.
          this.ctx.beginPath();
          this.ctx.moveTo(x - half, yBot); this.ctx.lineTo(x + half, yTop);
          this.ctx.moveTo(x - half, yTop); this.ctx.lineTo(x + half, yBot);
          this.ctx.stroke();
        } else {
          // O — an ellipse inscribed in the box cell.
          const ry = Math.abs(yBot - yTop) / 2 - 1;
          this.ctx.beginPath();
          this.ctx.ellipse(x, yMid, half, Math.max(1, ry), 0, 0, Math.PI * 2);
          this.ctx.stroke();
        }
      }
    }
  }

  // ── End Phase 26 draw helpers ─────────────────────────────────────────────

  // ── End Phase 16 draw helpers ─────────────────────────────────────────────

  _drawOverlays(plot, lo, hi, priceToY) {
    this._overlayHits = [];
    if (this._overlays.length === 0) return;

    const ctx = this.ctx;
    const dotR = 3;
    const chipH = 18;
    const chipPad = 6;
    const closeBoxW = 14;

    // First pass: compute the visible-y for each overlay; either inside the
    // plot, or clamped to a top/bottom caret position. While the user is
    // dragging an overlay, use the live cursor-derived snapped price for
    // that overlay so the line follows the mouse.
    const placements = [];
    let dragLivePrice = null;
    if (this._dragOverlay) {
      const wrap = this.container;
      const rect = wrap.getBoundingClientRect();
      const localY = this._dragOverlay.lastClientY - rect.top;
      const raw = this._yToPriceForDrag(localY);
      if (raw != null) dragLivePrice = this._snapPrice(raw);
    }
    for (const ov of this._overlays) {
      let effectivePrice = ov.price;
      if (this._dragOverlay && this._dragOverlay.overlayId === ov.id &&
          dragLivePrice != null) {
        effectivePrice = dragLivePrice;
      }
      const onScreen = effectivePrice >= lo && effectivePrice <= hi;
      const y = onScreen ? priceToY(effectivePrice)
          : (effectivePrice > hi ? plot.top + chipH / 2 : plot.bottom - chipH / 2);
      placements.push({ ov, y, onScreen, effectivePrice });
    }
    // Sort by y so vertical-stack collision logic is deterministic.
    placements.sort((a, b) => a.y - b.y);

    // Resolve label-chip vertical overlaps greedily.
    // Seed prevBottom at the top header strip's bottom so any chip whose
    // natural y would put it under the scrip/OHLC/bid-ask header gets
    // pushed down to sit just below the strip. The horizontal line itself
    // is still drawn at the true price `y` — only the chip moves.
    const haveCandles = this.candles.length > 0;
    const headerStripH = this.scrip ? 84 : (haveCandles ? 40 : 24);
    let prevBottom = headerStripH + 4;
    for (const p of placements) {
      const top = p.y - chipH / 2;
      const bottom = p.y + chipH / 2;
      if (top < prevBottom + 2) {
        const shifted = prevBottom + 2 + chipH / 2;
        p.chipY = shifted;
        prevBottom = shifted + chipH / 2;
      } else {
        p.chipY = p.y;
        prevBottom = bottom;
      }
    }

    // Second pass: draw line + dot, then label chip + close box.
    ctx.save();
    ctx.font = '700 11px Geist, sans-serif';
    ctx.textBaseline = 'middle';

    for (const p of placements) {
      const { ov, y, chipY, onScreen } = p;
      const color = this._overlayLineColor(ov);
      const dash = this._overlayDash(ov);
      const lineW = this._overlayLineWidth(ov);

      // Line — only when on-screen.
      if (onScreen) {
        ctx.strokeStyle = color;
        ctx.lineWidth = lineW;
        ctx.setLineDash(dash);
        ctx.beginPath();
        ctx.moveTo(plot.left, y);
        ctx.lineTo(plot.right, y);
        ctx.stroke();
        ctx.setLineDash([]);

        // Dot at the rightmost-candle x (approx = plot.right - cellW/2).
        const dotX = plot.right - this.view.cellW / 2;
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(dotX, y, dotR, 0, Math.PI * 2);
        ctx.fill();
      }

      // Build label text segments.
      const isAlert = ov.kind === 'alert';
      const isOptionStrike = ov.kind === 'optionStrike';
      const qtyText = (isAlert || isOptionStrike) ? '' : this._formatOverlayQty(ov.qty);
      const typeText = this._overlayTypeLabel(ov);
      const pnlText =
          (ov.kind === 'position' || isOptionStrike) ? this._formatOverlayPnl(ov.pnl)
          : (typeof ov.projectedPnl === 'number') ? this._formatOverlayPnl(ov.projectedPnl)
          : '';
      const optionStrikeText = isOptionStrike && typeof ov.optionLabel === 'string'
          ? ov.optionLabel : '';
      const segs = [];
      if (qtyText) segs.push(qtyText);
      if (optionStrikeText) segs.push(optionStrikeText);
      if (typeText) segs.push(typeText);
      if (pnlText) segs.push(pnlText);
      const labelText = segs.join('   ');
      const labelW = ctx.measureText(labelText).width;
      // Position chips carry a single "TP/SL" button before the close box
      // so the user can attach a target + stop to the position straight
      // from the chart. Clicking it posts positionOcoRequested; Flutter
      // opens a dialog to set both prices and places them as an OCO order
      // (one-cancels-other). Only real positions get it.
      const isPosition = ov.kind === 'position';
      const ocoBtnW = 42;
      const tpSlW = isPosition ? ocoBtnW : 0;
      const chipW = labelW + chipPad * 2 + tpSlW + closeBoxW;

      // Anchor the chip on the RIGHT side of the plot with a 20% gap from
      // the price axis — the line extends the full plot width AND passes
      // behind/past the chip; the chip sits where the user's eye is
      // (latest action) but stays well clear of the gutter `+` and price
      // chip.  chip right-edge = plot.right - 20% of plot width.
      const rightGapPct = 0.20;
      const chipLeft = Math.max(
          plot.left + 8,
          plot.right - chipW - plot.width * rightGapPct);
      const chipTop = chipY - chipH / 2;
      const accent = this._overlayLabelAccent(ov);

      // Chip background — solid line colour (TradingView convention) so the
      // chip pops in both themes and never looks transparent. Followed by a
      // 1px white outline so the chip visually detaches from the dashed
      // line passing behind/around it, and from any other overlay/chip it
      // sits next to.
      ctx.fillStyle = color;
      this._roundedRect(chipLeft, chipTop, chipW, chipH, 4);
      ctx.fill();
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 1;
      this._roundedRect(chipLeft, chipTop, chipW, chipH, 4);
      ctx.stroke();
      if (accent) {
        ctx.strokeStyle = accent;
        ctx.lineWidth = 1.5;
        this._roundedRect(chipLeft - 1, chipTop - 1, chipW + 2, chipH + 2, 5);
        ctx.stroke();
      }

      // Label text on the coloured chip — always white for contrast.
      ctx.fillStyle = '#FFFFFF';
      ctx.textAlign = 'left';
      ctx.fillText(labelText, chipLeft + chipPad, chipY);

      // Close box (× icon) — drawn as two lines, white on the coloured chip.
      const xBoxLeft = chipLeft + chipW - closeBoxW;
      const xCenterX = xBoxLeft + closeBoxW / 2;
      const xSize = 5;
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.moveTo(xCenterX - xSize / 2, chipY - xSize / 2);
      ctx.lineTo(xCenterX + xSize / 2, chipY + xSize / 2);
      ctx.moveTo(xCenterX + xSize / 2, chipY - xSize / 2);
      ctx.lineTo(xCenterX - xSize / 2, chipY + xSize / 2);
      ctx.stroke();

      // Position-only "TP/SL" button, between the label and close box:
      // [ 65 LONG +1,234 ] | TP/SL | × .
      if (isPosition) {
        const ocoLeft = chipLeft + chipW - closeBoxW - ocoBtnW;
        ctx.strokeStyle = 'rgba(255,255,255,0.45)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(ocoLeft, chipTop + 3);
        ctx.lineTo(ocoLeft, chipTop + chipH - 3);
        ctx.stroke();
        ctx.fillStyle = '#FFFFFF';
        ctx.font = '700 9px Geist, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('TP/SL', ocoLeft + ocoBtnW / 2, chipY);
        // Restore label font/alignment for subsequent overlays in the loop.
        ctx.font = '700 11px Geist, sans-serif';
        ctx.textAlign = 'left';
        this._overlayHits.push({
          rect: { x: ocoLeft, y: chipTop, w: ocoBtnW, h: chipH },
          action: 'addOco', overlayId: ov.id,
        });
      }

      // Hit-test rects: open = the chip's label area (excludes the SL/TP
      // buttons + close box); close = the close box.
      const openBodyW = chipW - closeBoxW - tpSlW;
      this._overlayHits.push({
        rect: { x: chipLeft, y: chipTop, w: openBodyW, h: chipH },
        action: 'open', overlayId: ov.id,
      });
      this._overlayHits.push({
        rect: { x: xBoxLeft, y: chipTop, w: closeBoxW, h: chipH },
        action: 'close', overlayId: ov.id,
      });

      // Also let users click on the line itself — both sides of the chip,
      // since the chip now sits in the middle of the plot.
      if (onScreen) {
        if (chipLeft > plot.left + 6) {
          this._overlayHits.push({
            rect: { x: plot.left, y: y - 3, w: chipLeft - plot.left, h: 6 },
            action: 'open', overlayId: ov.id,
          });
        }
        const rightStart = chipLeft + chipW;
        if (rightStart < plot.right - 6) {
          this._overlayHits.push({
            rect: { x: rightStart, y: y - 3,
                    w: plot.right - rightStart, h: 6 },
            action: 'open', overlayId: ov.id,
          });
        }
      }
    }

    // Phase 13: visual grouping bracket. When 2+ overlays sit in this pane
    // (always the same scrip), draw a thin vertical bar in the gutter
    // connecting all chip y-positions with small horizontal legs from each
    // chip's right edge to the bar. Makes it obvious that multiple lines
    // belong to the same instrument.
    if (placements.length >= 2) {
      const chipYs = placements.map((p) => p.chipY);
      const ys = chipYs.filter(Number.isFinite);
      if (ys.length >= 2) {
        const minY = Math.min(...ys);
        const maxY = Math.max(...ys);
        if (maxY - minY >= 4) {
          // Bar sits in the gutter just past the price chips (which end
          // around plot.right + 66 at chipW=64). 72px keeps it clear of
          // both the gutter price chip and the price axis numbers.
          const barX = plot.right + 72;
          ctx.strokeStyle = this.palette.axisText;
          ctx.lineWidth = 1;
          ctx.setLineDash([]);
          // Vertical bar.
          ctx.beginPath();
          ctx.moveTo(barX, minY);
          ctx.lineTo(barX, maxY);
          ctx.stroke();
          // Horizontal legs from each chip to the bar.
          // We don't have the chip's exact right edge here; approximate as
          // (plot.right + 66) — just past the gutter price chip column.
          const legStartX = plot.right + 66;
          for (const y of ys) {
            ctx.beginPath();
            ctx.moveTo(legStartX, y);
            ctx.lineTo(barX, y);
            ctx.stroke();
          }
        }
      }
    }

    ctx.restore();
  }

  _drawOverlayPriceChips(plot, lo, hi, priceToY) {
    if (this._overlays.length === 0) return;
    const ctx = this.ctx;
    ctx.save();
    ctx.font = '700 10px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    let dragLivePrice = null;
    if (this._dragOverlay) {
      const wrap = this.container;
      const rect = wrap.getBoundingClientRect();
      const localY = this._dragOverlay.lastClientY - rect.top;
      const raw = this._yToPriceForDrag(localY);
      if (raw != null) dragLivePrice = this._snapPrice(raw);
    }
    for (const ov of this._overlays) {
      let effective = ov.price;
      if (this._dragOverlay && this._dragOverlay.overlayId === ov.id &&
          dragLivePrice != null) {
        effective = dragLivePrice;
      }
      if (effective < lo || effective > hi) continue;
      const y = priceToY(effective);
      const text = effective.toFixed(2);
      const color = this._overlayLineColor(ov);
      const tw = ctx.measureText(text).width + 10;
      const chipW = Math.min(tw, 64);
      ctx.fillStyle = color;
      this._roundedRect(plot.right + 2, y - 8, chipW, 16, 3);
      ctx.fill();
      ctx.fillStyle = '#FFFFFF';
      ctx.textAlign = 'center';
      ctx.fillText(text, plot.right + 2 + chipW / 2, y);
    }
    ctx.restore();
  }

  // Phase 7 — render committed drawings (+ optional in-progress trendline
  // tracking the cursor). Also rebuilds `_drawingHits` for delete-chip
  // mousedown interception. Called from draw() after _drawOverlays.
  // Phase 10 — also rebuilds `_colorSwatchHits` for the per-drawing palette,
  // registers `action: 'drag'` line-band hits on committed drawings, and
  // thickens the line of the currently-selected drawing.
  _drawDrawings(plot, priceToY) {
    this._drawingHits = [];
    this._colorSwatchHits = [];
    this._drawingHandleHits = [];
    // Phase 23.3 — when all drawings are hidden, skip rendering but keep hit arrays empty.
    if (this.drawingsHidden) return;
    if (this._drawings.length === 0 && !this._inProgressDrawing) return;
    const ctx = this.ctx;
    const chipH = 16;

    const renderOne = (d, isInProgress) => {
      const color = d.color || '#3B82F6';
      const isSelected = !isInProgress && d.id === this._selectedDrawingId;
      ctx.save();
      ctx.setLineDash(isInProgress ? [4, 4] : []);

      let endX = plot.right;
      let endY = 0;
      // Geometry captured per-kind so we can register a drag-band hit below.
      // hline: full-width band at y. trendline: bbox-band along the line.
      // rect: full bounding box.
      let dragRect = null;
      // Draw helper — paints a subtle white halo first so the coloured line
      // stays visible over candles regardless of background. Phase 10:
      // selected drawings get a slightly thicker coloured stroke.
      // Per-drawing thickness (1..4) replaces the baseline 2px when > 1.
      const baseStroke = (d.thickness && d.thickness > 1) ? d.thickness : 2;
      const strokeW = isSelected ? baseStroke + 0.5 : baseStroke;
      const drawLine = (ax, ay, bx, by) => {
        if (!Number.isFinite(ax) || !Number.isFinite(ay) ||
            !Number.isFinite(bx) || !Number.isFinite(by)) return;
        ctx.strokeStyle = 'rgba(255,255,255,0.85)';
        ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.moveTo(ax, ay);
        ctx.lineTo(bx, by);
        ctx.stroke();
        ctx.strokeStyle = color;
        ctx.lineWidth = strokeW;
        ctx.beginPath();
        ctx.moveTo(ax, ay);
        ctx.lineTo(bx, by);
        ctx.stroke();
      };

      // Phase 28 — registry-driven tools render first. Each impl draws onto the
      // canvas and returns { endX, endY, dragRect }; the common post-render code
      // below (drag hit-band + selected floating toolbar) is shared with the
      // legacy branches. Unknown kinds fall through to the original if-chain.
      const _impl = DRAWING_TOOLS[d.kind];
      if (_impl && typeof _impl.render === 'function') {
        const g = {
          ctx,
          plot,
          color,
          strokeW,
          isSelected,
          isInProgress,
          drawLine,
          hover: this.hover,
          candles: this.candles,
          tsToX: (ts) => this._tsToX(ts, plot),
          xToTs: (xx) => this._xToTs(xx),
          priceToY,
          yToPrice: (yy) => this._yToPriceForDrag(yy),
          lineParams: (px, py, dx, dy) =>
              _lineRectParams(px, py, dx, dy,
                  plot.left, plot.top, plot.right, plot.bottom),
        };
        const r = _impl.render(g, d);
        if (!r) { ctx.restore(); return; }
        endX = Number.isFinite(r.endX) ? r.endX : plot.right;
        endY = Number.isFinite(r.endY) ? r.endY : 0;
        dragRect = r.dragRect || null;
      } else if (d.kind === 'path') {
        // Phase 21.B — Path: multi-point polyline. Single in-progress point
        // previews to cursor; 2+ points render the polyline and extend to cursor
        // while in progress.
        if (!d.points || d.points.length < 2) {
          // In-progress with 1 point + live cursor: preview a single segment.
          if (d.points && d.points.length === 1 && this.hover.inside &&
              this.hover.x != null) {
            const p = d.points[0];
            const x1 = this._tsToX(p.ts, plot);
            const y1 = priceToY(p.price);
            drawLine(x1, y1, this.hover.x, this.hover.y);
            endX = this.hover.x; endY = this.hover.y;
          } else {
            ctx.restore();
            return;
          }
        } else {
          const xs = [];
          const ys = [];
          for (const p of d.points) {
            xs.push(this._tsToX(p.ts, plot));
            ys.push(priceToY(p.price));
          }
          for (let i = 0; i < xs.length - 1; i++) {
            drawLine(xs[i], ys[i], xs[i + 1], ys[i + 1]);
          }
          // In-progress preview: extend from last point to cursor.
          if (isInProgress && this.hover.inside && this.hover.x != null) {
            drawLine(xs[xs.length - 1], ys[ys.length - 1],
                     this.hover.x, this.hover.y);
          }
          endX = xs[xs.length - 1];
          endY = ys[ys.length - 1];
          if (!isInProgress) {
            const minX = Math.min(...xs), maxX = Math.max(...xs);
            const minY = Math.min(...ys), maxY = Math.max(...ys);
            dragRect = { x: minX, y: minY - 4,
                         w: maxX - minX, h: maxY - minY + 8 };
          }
        }
      }
      ctx.restore();

      // Phase 10 — register a drag-band hit so mousedown on this drawing's
      // line starts a translate gesture. Registered BEFORE the delete chip
      // hit (which is push-ordered after) so chip-hit-test priority is fine
      // since mousedown checks chips first.
      if (!isInProgress && dragRect &&
          Number.isFinite(dragRect.x) && Number.isFinite(dragRect.y) &&
          Number.isFinite(dragRect.w) && Number.isFinite(dragRect.h)) {
        this._drawingHits.push({
          rect: dragRect,
          drawingId: d.id,
          action: 'drag',
          kind: d.kind,
        });
      }

      // Phase 30 — per-anchor edit handles. When a drawing is selected and not
      // locked, draw a draggable square at every anchor so the user can reshape
      // / extend it (drag an endpoint) instead of only translating the whole
      // shape. Skipped for `path`/`brush` (too many points) and `measure`.
      if (!isInProgress && isSelected && !d.locked &&
          d.kind !== 'path' && d.kind !== 'measure' &&
          Array.isArray(d.points)) {
        const hs = 4; // half-size of the handle square
        ctx.save();
        for (let pi = 0; pi < d.points.length; pi++) {
          const pt = d.points[pi];
          if (!pt) continue;
          const hx = this._tsToX(pt.ts, plot);
          const hy = priceToY(pt.price);
          if (!Number.isFinite(hx) || !Number.isFinite(hy)) continue;
          ctx.fillStyle = '#FFFFFF';
          ctx.strokeStyle = d.color || '#3B82F6';
          ctx.lineWidth = 1.5;
          ctx.beginPath();
          ctx.rect(hx - hs, hy - hs, hs * 2, hs * 2);
          ctx.fill();
          ctx.stroke();
          this._drawingHandleHits.push({
            rect: { x: hx - hs - 3, y: hy - hs - 3, w: hs * 2 + 6, h: hs * 2 + 6 },
            drawingId: d.id,
            pointIndex: pi,
          });
        }
        ctx.restore();
      }

      // Sahi-style floating toolbar — single row of equal-sized icon buttons
      // sitting on a dark rounded card with a subtle border + shadow. Two of
      // the buttons (color, stroke) open dropdown popups BELOW the toolbar
      // on click instead of fanning controls out inline.
      //
      // Layout: [⠿ drag] [■ color ▾] [▬ stroke ▾] [⎘ dup] [🔒 lock] [✕ del]
      if (!isInProgress && isSelected) {
        const tH = 28;                   // toolbar height
        const btn = 28;                  // square button hit area
        const inner = 4;                 // pad inside the toolbar card
        const btnCount = 6;
        const toolbarW = inner * 2 + btn * btnCount;
        const chipW = 14;
        const rightAnchor = plot.right - 60;
        let tX = endX < rightAnchor
            ? Math.max(plot.left + 4, endX - toolbarW - 4)
            : rightAnchor - toolbarW;
        if (tX < plot.left + 4) tX = plot.left + 4;
        const tY = Math.max(plot.top + 4, endY - chipH / 2 - tH - 4);
        const isLocked = d.locked === true;
        const dThickness = (d.thickness && d.thickness > 0) ? d.thickness : 1;

        // ── Card background (1px border + subtle shadow via double-draw) ──
        // Soft drop shadow first
        ctx.save();
        ctx.shadowColor = 'rgba(0,0,0,0.45)';
        ctx.shadowBlur = 10;
        ctx.shadowOffsetY = 2;
        ctx.fillStyle = '#0F172A';
        this._roundedRect(tX, tY, toolbarW, tH, 8);
        ctx.fill();
        ctx.restore();
        ctx.strokeStyle = 'rgba(255,255,255,0.08)';
        ctx.lineWidth = 1;
        this._roundedRect(tX, tY, toolbarW, tH, 8);
        ctx.stroke();

        // ── Helpers ─────────────────────────────────────────────────────
        const buttons = [];
        let bx = tX + inner;
        const by = tY;
        const stepX = () => { const out = bx; bx += btn; return out; };

        // 1) Drag handle — six dots in a 2x3 grid. Click+hold drags the
        // drawing around the chart (proxy for the line's drag-band, useful
        // for hlines/horizontals where there's no visible line region to
        // grab without zooming in).
        {
          const ax = stepX();
          ctx.fillStyle = 'rgba(255,255,255,0.75)';
          const cxg = ax + btn / 2;
          const cyg = by + tH / 2;
          for (let dy = -1; dy <= 1; dy++) {
            for (let dx = -1; dx <= 1; dx += 2) {
              ctx.beginPath();
              ctx.arc(cxg + dx * 1.8, cyg + dy * 3.2, 1.3, 0, Math.PI * 2);
              ctx.fill();
            }
          }
          this._drawingHits.push({
            rect: { x: ax, y: by, w: btn, h: tH },
            drawingId: d.id,
            action: 'drag',
            kind: d.kind,
          });
        }

        // 2) Color square + dropdown chevron
        {
          const ax = stepX();
          const swSize = 14;
          const swX = ax + (btn - swSize) / 2 - 3;
          const swY = by + (tH - swSize) / 2;
          ctx.fillStyle = d.color || '#3B82F6';
          this._roundedRect(swX, swY, swSize, swSize, 3);
          ctx.fill();
          ctx.strokeStyle = 'rgba(255,255,255,0.18)';
          ctx.lineWidth = 1;
          this._roundedRect(swX, swY, swSize, swSize, 3);
          ctx.stroke();
          // Chevron
          ctx.strokeStyle = 'rgba(255,255,255,0.5)';
          ctx.beginPath();
          ctx.moveTo(swX + swSize + 3, by + tH / 2 - 1);
          ctx.lineTo(swX + swSize + 6, by + tH / 2 + 2);
          ctx.lineTo(swX + swSize + 9, by + tH / 2 - 1);
          ctx.stroke();
          buttons.push({
            rect: { x: ax, y: by, w: btn, h: tH },
            action: 'openColor',
            anchorX: ax,
          });
        }

        // 3) Stroke width + dropdown chevron
        {
          const ax = stepX();
          // Tiny preview line at the indicator's color, thickness mirrored
          const cxg = ax + btn / 2 - 3;
          const cyg = by + tH / 2;
          ctx.strokeStyle = d.color || '#FFFFFF';
          ctx.lineWidth = dThickness;
          ctx.beginPath();
          ctx.moveTo(cxg - 6, cyg);
          ctx.lineTo(cxg + 4, cyg);
          ctx.stroke();
          ctx.strokeStyle = 'rgba(255,255,255,0.5)';
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.moveTo(cxg + 6, cyg - 1);
          ctx.lineTo(cxg + 9, cyg + 2);
          ctx.lineTo(cxg + 12, cyg - 1);
          ctx.stroke();
          buttons.push({
            rect: { x: ax, y: by, w: btn, h: tH },
            action: 'openStroke',
            anchorX: ax,
          });
        }

        // 4) Duplicate — two offset rounded squares
        {
          const ax = stepX();
          const cxg = ax + btn / 2;
          const cyg = by + tH / 2;
          ctx.strokeStyle = 'rgba(255,255,255,0.85)';
          ctx.lineWidth = 1.2;
          this._roundedRect(cxg - 4.5, cyg - 5, 7, 7, 1.5);
          ctx.stroke();
          this._roundedRect(cxg - 1.5, cyg - 2, 7, 7, 1.5);
          ctx.stroke();
          buttons.push({
            rect: { x: ax, y: by, w: btn, h: tH },
            action: 'duplicate',
          });
        }

        // 5) Lock / unlock — accent fill when locked
        {
          const ax = stepX();
          if (isLocked) {
            ctx.fillStyle = 'rgba(124,58,237,0.22)';
            this._roundedRect(ax + 3, by + 3, btn - 6, tH - 6, 5);
            ctx.fill();
          }
          const cxg = ax + btn / 2;
          const cyg = by + tH / 2 + 1;
          ctx.strokeStyle = isLocked ? '#C4B5FD' : 'rgba(255,255,255,0.85)';
          ctx.lineWidth = 1.3;
          // body
          this._roundedRect(cxg - 3.5, cyg - 1, 7, 5.5, 1.4);
          ctx.stroke();
          // shackle
          ctx.beginPath();
          ctx.arc(cxg, cyg - 1, 2.6, Math.PI,
              isLocked ? 0 : -Math.PI / 4);
          ctx.stroke();
          buttons.push({
            rect: { x: ax, y: by, w: btn, h: tH },
            action: 'lockToggle',
          });
        }

        // 6) Delete — destructive accent
        {
          const ax = stepX();
          const cxg = ax + btn / 2;
          const cyg = by + tH / 2;
          ctx.strokeStyle = '#F87171';
          ctx.lineWidth = 1.4;
          const xs = 4;
          ctx.beginPath();
          ctx.moveTo(cxg - xs, cyg - xs);
          ctx.lineTo(cxg + xs, cyg + xs);
          ctx.moveTo(cxg + xs, cyg - xs);
          ctx.lineTo(cxg - xs, cyg + xs);
          ctx.stroke();
          buttons.push({
            rect: { x: ax, y: by, w: btn, h: tH },
            action: 'delete',
          });
        }

        // Register button hits — toolbar buttons share the drawingHits list
        // so the existing mousedown dispatch picks them up.
        for (const b of buttons) {
          this._drawingHits.push({
            rect: b.rect,
            drawingId: d.id,
            action: b.action,
            anchorX: b.anchorX,
          });
        }

        // ── Dropdown popups (color / stroke) ────────────────────────────
        if (this._toolbarPopup &&
            this._toolbarPopup.drawingId === d.id) {
          const popY = tY + tH + 6;
          if (this._toolbarPopup.kind === 'color') {
            // 4×2 swatch grid
            const colors = ['#3B82F6', '#EF4444', '#22C55E', '#F59E0B',
                            '#8B5CF6', '#06B6D4', '#EC4899', '#FFFFFF'];
            const swPad = 8;
            const swSize = 22;
            const swGap = 6;
            const cols = 4;
            const rows = Math.ceil(colors.length / cols);
            const popW = swPad * 2 + cols * swSize + (cols - 1) * swGap;
            const popH = swPad * 2 + rows * swSize + (rows - 1) * swGap;
            let popX = this._toolbarPopup.anchorX - 4;
            if (popX + popW > plot.right - 4) popX = plot.right - 4 - popW;
            // Card
            ctx.save();
            ctx.shadowColor = 'rgba(0,0,0,0.5)';
            ctx.shadowBlur = 12;
            ctx.shadowOffsetY = 4;
            ctx.fillStyle = '#0F172A';
            this._roundedRect(popX, popY, popW, popH, 10);
            ctx.fill();
            ctx.restore();
            ctx.strokeStyle = 'rgba(255,255,255,0.08)';
            ctx.lineWidth = 1;
            this._roundedRect(popX, popY, popW, popH, 10);
            ctx.stroke();
            for (let i = 0; i < colors.length; i++) {
              const col = i % cols, row = Math.floor(i / cols);
              const cxg = popX + swPad + col * (swSize + swGap);
              const cyg = popY + swPad + row * (swSize + swGap);
              ctx.fillStyle = colors[i];
              this._roundedRect(cxg, cyg, swSize, swSize, 5);
              ctx.fill();
              const isCur = colors[i].toLowerCase() ===
                  (d.color || '').toLowerCase();
              if (isCur) {
                ctx.strokeStyle = '#FFFFFF';
                ctx.lineWidth = 2;
                this._roundedRect(cxg - 1, cyg - 1, swSize + 2, swSize + 2, 6);
                ctx.stroke();
              } else {
                ctx.strokeStyle = 'rgba(255,255,255,0.12)';
                ctx.lineWidth = 1;
                this._roundedRect(cxg, cyg, swSize, swSize, 5);
                ctx.stroke();
              }
              this._colorSwatchHits.push({
                rect: { x: cxg, y: cyg, w: swSize, h: swSize },
                color: colors[i],
                drawingId: d.id,
              });
            }
          } else if (this._toolbarPopup.kind === 'stroke') {
            // Vertical 1/2/3/4 px list
            const widths = [1, 2, 3, 4];
            const rowH = 28;
            const popW = 96;
            const popH = widths.length * rowH + 8;
            let popX = this._toolbarPopup.anchorX - 4;
            if (popX + popW > plot.right - 4) popX = plot.right - 4 - popW;
            ctx.save();
            ctx.shadowColor = 'rgba(0,0,0,0.5)';
            ctx.shadowBlur = 12;
            ctx.shadowOffsetY = 4;
            ctx.fillStyle = '#0F172A';
            this._roundedRect(popX, popY, popW, popH, 10);
            ctx.fill();
            ctx.restore();
            ctx.strokeStyle = 'rgba(255,255,255,0.08)';
            ctx.lineWidth = 1;
            this._roundedRect(popX, popY, popW, popH, 10);
            ctx.stroke();
            for (let i = 0; i < widths.length; i++) {
              const rowY = popY + 4 + i * rowH;
              const isCur = widths[i] === dThickness;
              if (isCur) {
                ctx.fillStyle = 'rgba(124,58,237,0.18)';
                this._roundedRect(popX + 4, rowY + 2, popW - 8, rowH - 4, 6);
                ctx.fill();
              }
              // Line preview
              ctx.strokeStyle = isCur ? '#FFFFFF' : 'rgba(255,255,255,0.8)';
              ctx.lineWidth = widths[i];
              ctx.beginPath();
              ctx.moveTo(popX + 14, rowY + rowH / 2);
              ctx.lineTo(popX + 50, rowY + rowH / 2);
              ctx.stroke();
              // Label
              ctx.fillStyle = isCur ? '#FFFFFF' : 'rgba(255,255,255,0.7)';
              ctx.font = '600 11px Geist, sans-serif';
              ctx.textBaseline = 'middle';
              ctx.textAlign = 'left';
              ctx.fillText(widths[i] + 'px', popX + 62, rowY + rowH / 2);
              this._drawingHits.push({
                rect: { x: popX, y: rowY, w: popW, h: rowH },
                drawingId: d.id,
                action: 'setThickness',
                thickness: widths[i],
              });
            }
          }
        }
      }
    };

    // Phase 16 F2 — on Renko, hide time-axis drawings (trendline, rect, fib,
    // channel, etc.). Only price-only drawings (hline) make sense when the
    // X axis is brick-indexed rather than time-indexed. Phase 26 — same applies
    // to all rebinned styles (linebreak/kagi/range/pnf): their X axis is
    // rebin-indexed, not time-indexed.
    const isRebinAxis = this.candleStyle === 'renko'
        || this._isRebinnedStyle(this.candleStyle);
    for (const d of this._drawings) {
      if (isRebinAxis && d.kind !== 'hline') continue;
      renderOne(d, false);
    }
    if (this._inProgressDrawing) {
      if (!isRebinAxis || this._inProgressDrawing.kind === 'hline') {
        renderOne(this._inProgressDrawing, true);
      }
    }
  }

  _overlayHitTest(x, y) {
    if (this._plusHit) {
      const r = this._plusHit.rect;
      if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
        return { kind: 'plus', price: this._plusHit.price };
      }
    }
    for (const h of this._headerHits) {
      const r = h.rect;
      if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
        return { kind: 'header', headerKind: h.kind, price: h.price };
      }
    }
    for (const h of this._overlayHits) {
      const r = h.rect;
      if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
        return { kind: 'overlay', overlayId: h.overlayId, action: h.action };
      }
    }
    return null;
  }

  // Re-derive the same sub-pane vertical budget that draw() uses so the
  // y→price helpers (used by drag-modify + magnet snap) place values at
  // the right pixel when sub-pane indicators are visible. WITHOUT this,
  // sub-pane height was treated as 0 → the candle area was over-tall →
  // magnet's _yForPriceForDrag returned a too-low Y, so the |dy| threshold
  // never fired and snap silently no-op'd.
  _subPaneTotalH(innerH) {
    // Must match the SUB_KINDS set in draw() — divergence breaks layout
    // math (draw() allocates sub-panes that this helper says don't exist
    // → magnet snap + sub-pane axis labels end up at wrong Y positions).
    const SUB_KINDS = new Set(['rsi', 'macd', 'stoch', 'atr', 'stochrsi',
        'squeeze', 'efi', 'wt', 'crsi', 'ao', 'mfi', 'obv', 'cmf', 'wr',
        'cci', 'roc', 'cvd', 'adx', 'trix', 'vortex', 'uo', 'dpo', 'pvt',
        'ad', 'explain']);
    const visibleSubs = this._indicators
        .filter((i) => SUB_KINDS.has(i.kind) && !i.hidden);
    if (visibleSubs.length === 0) return 0;
    // User-resized ratio drives the total height; clamped so each sub-pane
    // gets at least 60px and the candle pane keeps at least 35% of innerH.
    const minTotal = 60 * visibleSubs.length;
    const maxTotal = Math.round(innerH * 0.65);
    const fromRatio = Math.round(innerH * this._subPaneRatio);
    return Math.max(minTotal, Math.min(maxTotal, fromRatio));
  }

  // Returns the cached sub-plot whose vertical band contains y, or null.
  // Used by mousedown / wheel / dblclick to route per-sub-pane gestures.
  _hitSubPane(y) {
    if (!this._lastSubPlots || this._lastSubPlots.length === 0) return null;
    for (const sp of this._lastSubPlots) {
      if (y >= sp.top && y <= sp.bottom) return sp;
    }
    return null;
  }

  // y→price inverse used by drag-modify. Rebuilds the plot rect the same
  // way draw() does so the conversion matches exactly.
  _yToPriceForDrag(y) {
    if (this.candles.length === 0) return null;
    const h = this.canvas.clientHeight;
    const bottomGutter = 24;
    const topPad = 8;
    const innerH = h - topPad - bottomGutter;
    // Account for sub-panes that eat from the candle area — see _subPaneTotalH.
    const candleH = innerH - this._subPaneTotalH(innerH);
    const plotTop = topPad;
    const plotBottom = topPad + candleH;
    const plotHeight = plotBottom - plotTop;
    if (plotHeight <= 0) return null;
    // Use the same lo/hi that draw() would compute. Re-derive via the same
    // logic: if priceCenter is null, auto-fit visible candles.
    let lo, hi;
    if (this.view.priceCenter == null) {
      const visible = this._visibleCandles();
      if (visible.length === 0) return null;
      lo = Infinity; hi = -Infinity;
      for (const c of visible) { if (c.l < lo) lo = c.l; if (c.h > hi) hi = c.h; }
      const pad = (hi - lo) * 0.04;
      lo -= pad; hi += pad;
    } else {
      const half = (plotHeight / 2) * this.view.pricePerPx;
      lo = this.view.priceCenter - half;
      hi = this.view.priceCenter + half;
    }
    return hi - (y - plotTop) * (hi - lo) / plotHeight;
  }

  _snapPrice(price) {
    const ti = (this.scrip && this.scrip.ti && this.scrip.ti > 0) ? this.scrip.ti : 0.05;
    // Round once, then again via toFixed to scrub float-math residue
    // (e.g. 0.05 * 27047 == 1352.3499999998 instead of 1352.35).
    return parseFloat((Math.round(price / ti) * ti).toFixed(this._priceDecimals() + 2));
  }

  // Phase 23.2 — price→y inverse of _yToPriceForDrag. Returns null when the
  // price is outside the visible range or the plot cannot be determined.
  _yForPriceForDrag(price) {
    if (this.candles.length === 0) return null;
    const h = this.canvas.clientHeight;
    const bottomGutter = 24;
    const topPad = 8;
    const innerH = h - topPad - bottomGutter;
    const candleH = innerH - this._subPaneTotalH(innerH);
    const plotTop = topPad;
    const plotBottom = topPad + candleH;
    const plotHeight = plotBottom - plotTop;
    if (plotHeight <= 0) return null;
    let lo, hi;
    if (this.view.priceCenter == null) {
      const visible = this._visibleCandles();
      if (visible.length === 0) return null;
      lo = Infinity; hi = -Infinity;
      for (const c of visible) {
        if (c.l < lo) lo = c.l;
        if (c.h > hi) hi = c.h;
      }
      const pad = (hi - lo) * 0.04;
      lo -= pad; hi += pad;
    } else {
      const half = (plotHeight / 2) * this.view.pricePerPx;
      lo = this.view.priceCenter - half;
      hi = this.view.priceCenter + half;
    }
    if (price < lo || price > hi) return null;
    return plotTop + plotHeight * (hi - price) / (hi - lo);
  }

  // ---- Phase 14: keyboard shortcut helpers ----

  _postQuickPlace(side) {
    if (!this.scrip || !this.hover.inside || this.hover.x == null) return;
    // Block Alt+B / Alt+S on non-tradable scrips (GetSecurityInfo-driven).
    if (this._scripTradable === false) return;
    const raw = this._yToPriceForDrag(this.hover.y);
    if (raw == null) return;
    const price = this._snapPrice(raw);
    if (!Number.isFinite(price) || price <= 0) return;
    try {
      parent.postMessage(JSON.stringify({
        type: side === 'buy' ? 'keyBuyAtPrice' : 'keySellAtPrice',
        value: { paneId: this.paneId, price },
      }), '*');
    } catch (_) {}
  }

  _postToggleInstant() {
    try {
      parent.postMessage(JSON.stringify({
        type: 'keyToggleInstant',
        value: { paneId: this.paneId },
      }), '*');
    } catch (_) {}
  }

  _postTimeframe(minutes) {
    try {
      parent.postMessage(JSON.stringify({
        type: 'keyTimeframe',
        value: { paneId: this.paneId, minutes },
      }), '*');
    } catch (_) {}
  }

  /// Returns true if the given epoch-seconds timestamp falls within the
  /// scrip's exchange trading window. Used to suppress out-of-session candle
  /// formation (pre-market, lunch break, post-close, weekends).
  ///   NSE / NFO / BSE / BFO  → 09:15–15:30 IST, Mon–Fri
  ///   MCX                    → 09:00–23:30 IST, Mon–Fri
  /// All others default to "always in session" (safer than silently dropping
  /// data for unknown exchanges).
  _isWithinTradingHours(tsSec) {
    if (!Number.isFinite(tsSec) || tsSec <= 0) return true;
    if (!this.scrip) return true;
    const ist = new Date(tsSec * 1000 + 5.5 * 3600 * 1000);
    const dow = ist.getUTCDay(); // 0 = Sun, 6 = Sat
    if (dow === 0 || dow === 6) return false;
    const minutesIst = ist.getUTCHours() * 60 + ist.getUTCMinutes();
    const exch = this.scrip.exch;
    if (exch === 'MCX') {
      // 09:00 → 540, 23:30 → 1410
      return minutesIst >= 540 && minutesIst <= 1410;
    }
    if (exch === 'NSE' || exch === 'NFO' ||
        exch === 'BSE' || exch === 'BFO') {
      // 09:15 → 555, 15:30 → 930
      return minutesIst >= 555 && minutesIst <= 930;
    }
    return true;
  }

  // Periodic check (driven by _advanceBarsTicker). When the latest candle's
  // bucket has fully elapsed but no tick arrived to roll into the next one,
  // append flat continuation bars (O=H=L=C=lastClose, V=0) up to the
  // current wall-clock bucket. Skips daily+ timeframes (calendar-bucketed,
  // not modular) and out-of-session time so nothing forms overnight.
  _advanceEmptyBarsIfNeeded() {
    if (!this.scrip) return;
    if (this.timeframeMinutes >= 1440) return; // daily/weekly/monthly
    if (this.candles.length === 0) return;
    const nowSec = Math.floor(Date.now() / 1000);
    if (!this._isWithinTradingHours(nowSec)) return;
    const targetSec = this.timeframeMinutes * 60;
    const currentBucket = nowSec - (nowSec % targetSec);
    const last = this.candles[this.candles.length - 1];
    if (last.ts >= currentBucket) return;
    // Cap synthesis at 200 bars per call so a long-idle session doesn't
    // create thousands of empty bars in one tick.
    let nextBucket = last.ts + targetSec;
    let appended = 0;
    let lastClose = last.c;
    while (nextBucket <= currentBucket && appended < 200) {
      if (this._isWithinTradingHours(nextBucket)) {
        this.candles.push({
          ts: nextBucket,
          o: lastClose, h: lastClose, l: lastClose, c: lastClose, v: 0,
        });
        appended++;
      }
      nextBucket += targetSec;
    }
    if (appended > 0) this.scheduleRedraw();
  }

  _overlayLineColor(ov) {
    if (ov.kind === 'alert') return '#F59E0B';
    // Deeper violet so the right-axis price chip's white text stays readable
    // (the previous #A78BFA was too light — text-on-chip contrast washed out).
    if (ov.kind === 'optionStrike') return '#8B5CF6';
    if (ov.kind === 'tp' || ov.kind === 'ocoTp') return this.palette.bull;
    if (ov.kind === 'sl' || ov.kind === 'sl-l' || ov.kind === 'ocoSl') return this.palette.short;
    return ov.side === 'buy' ? this.palette.long : this.palette.short;
  }

  _overlayLabelAccent(ov) {
    // SL gets a 1px amber outline on the chip; everyone else gets none.
    return (ov.kind === 'sl' || ov.kind === 'sl-l') ? '#F59E0B' : null;
  }

  _overlayDash(ov) {
    if (ov.kind === 'position') return [];
    if (ov.kind === 'optionStrike') return [];
    if (ov.kind === 'alert') return [6, 4];
    if (ov.kind === 'limit' || ov.kind === 'tp' || ov.kind === 'ocoTp') return [6, 4];
    if (ov.kind === 'sl-l') return [4, 4];
    return [2, 3]; // sl / ocoSl
  }

  _overlayLineWidth(ov) {
    return ov.kind === 'position' ? 1.5 : 1;
  }

  _formatOverlayQty(qty) {
    // Unsigned — direction is conveyed by the chip colour (blue=long/buy,
    // red=short/sell), matching TradingView's convention.
    return String(Math.abs(Math.trunc(qty)));
  }

  _formatOverlayPnl(pnl) {
    if (pnl == null) return '';
    const sign = pnl >= 0 ? '+' : '−'; // unicode minus
    const abs = Math.abs(pnl);
    // Always 2 decimal points — user requested precision over compactness.
    // For ≥ ₹1L use the L abbreviation but still keep 2 decimals.
    if (abs < 100000) return sign + '₹' + abs.toFixed(2);
    return sign + '₹' + (abs / 100000).toFixed(2) + 'L';
  }

  _overlayTypeLabel(ov) {
    if (ov.kind === 'tp' || ov.kind === 'ocoTp') return 'TP';
    if (ov.kind === 'limit') return 'LMT';
    if (ov.kind === 'sl') return 'SL';
    if (ov.kind === 'sl-l') return 'SL-L';
    if (ov.kind === 'ocoSl') return 'SL';
    if (ov.kind === 'alert') return ov.side === 'buy' ? '↑ ALERT' : '↓ ALERT';
    return null; // position has no type label
  }

  // ── Phase 20 — Key Levels (classical pivot points) ────────────────────────

  // Returns null when there isn't enough data, otherwise an object with
  // PP / R1-R3 / S1-S3 derived from the PREVIOUS trading day's H/L/C.
  // "Previous day" = the most recent run of candles whose YYYY-MM-DD (IST)
  // is strictly less than the latest candle's date. Computation is purely
  // local to this.candles — no API call.
  _computeKeyLevels(variant) {
    const bars = this.candles;
    if (!bars || bars.length < 2) return null;
    const dateKey = (tsSec) => {
      const d = new Date((tsSec + 19800) * 1000);
      return d.getUTCFullYear() + '-' +
          String(d.getUTCMonth() + 1).padStart(2, '0') + '-' +
          String(d.getUTCDate()).padStart(2, '0');
    };
    const todayKey = dateKey(bars[bars.length - 1].ts);
    let prevKey = null;
    let prevEnd = -1;
    for (let i = bars.length - 1; i >= 0; i--) {
      const k = dateKey(bars[i].ts);
      if (k !== todayKey) { prevKey = k; prevEnd = i; break; }
    }
    if (prevKey == null || prevEnd < 0) return null;
    let prevStart = prevEnd;
    while (prevStart > 0 && dateKey(bars[prevStart - 1].ts) === prevKey) {
      prevStart--;
    }
    let h = -Infinity, l = Infinity;
    for (let i = prevStart; i <= prevEnd; i++) {
      if (bars[i].h > h) h = bars[i].h;
      if (bars[i].l < l) l = bars[i].l;
    }
    const c = bars[prevEnd].c;
    if (!isFinite(h) || !isFinite(l) || !isFinite(c)) return null;
    const pp = (h + l + c) / 3;
    const range = h - l;

    if (variant === 'fibonacci') {
      return {
        pp,
        r1: pp + 0.382 * range,
        r2: pp + 0.618 * range,
        r3: pp + 1.000 * range,
        s1: pp - 0.382 * range,
        s2: pp - 0.618 * range,
        s3: pp - 1.000 * range,
      };
    }
    if (variant === 'camarilla') {
      return {
        pp,
        r1: c + range * 1.1 / 12,
        r2: c + range * 1.1 / 6,
        r3: c + range * 1.1 / 4,
        s1: c - range * 1.1 / 12,
        s2: c - range * 1.1 / 6,
        s3: c - range * 1.1 / 4,
      };
    }
    // Default: classical
    return {
      pp,
      r1: 2 * pp - l,
      r2: pp + range,
      r3: h + 2 * (pp - l),
      s1: 2 * pp - h,
      s2: pp - range,
      s3: l - 2 * (h - pp),
    };
  }

  // Group `this.candles` into per-day spans (IST). Returns an array of
  // { date, startIdx, endIdx, h, l, c } in chronological order.
  _dailySpans() {
    const bars = this.candles;
    const dateKey = (tsSec) => {
      const d = new Date((tsSec + 19800) * 1000);
      return d.getUTCFullYear() + '-' +
          String(d.getUTCMonth() + 1).padStart(2, '0') + '-' +
          String(d.getUTCDate()).padStart(2, '0');
    };
    const spans = [];
    if (!bars || bars.length === 0) return spans;
    let cur = {
      date: dateKey(bars[0].ts),
      startIdx: 0,
      endIdx: 0,
      h: bars[0].h,
      l: bars[0].l,
      c: bars[0].c,
    };
    for (let i = 1; i < bars.length; i++) {
      const k = dateKey(bars[i].ts);
      if (k === cur.date) {
        cur.endIdx = i;
        if (bars[i].h > cur.h) cur.h = bars[i].h;
        if (bars[i].l < cur.l) cur.l = bars[i].l;
        cur.c = bars[i].c;
      } else {
        spans.push(cur);
        cur = {
          date: k,
          startIdx: i,
          endIdx: i,
          h: bars[i].h,
          l: bars[i].l,
          c: bars[i].c,
        };
      }
    }
    spans.push(cur);
    return spans;
  }

  _pivotsFor(variant, h, l, c) {
    if (!isFinite(h) || !isFinite(l) || !isFinite(c)) return null;
    const pp = (h + l + c) / 3;
    const range = h - l;
    if (variant === 'fibonacci') {
      return {
        pp,
        r1: pp + 0.382 * range, r2: pp + 0.618 * range, r3: pp + 1.000 * range,
        s1: pp - 0.382 * range, s2: pp - 0.618 * range, s3: pp - 1.000 * range,
      };
    }
    if (variant === 'camarilla') {
      return {
        pp,
        r1: c + range * 1.1 / 12, r2: c + range * 1.1 / 6, r3: c + range * 1.1 / 4,
        s1: c - range * 1.1 / 12, s2: c - range * 1.1 / 6, s3: c - range * 1.1 / 4,
      };
    }
    return {
      pp,
      r1: 2 * pp - l, r2: pp + range, r3: h + 2 * (pp - l),
      s1: 2 * pp - h, s2: pp - range, s3: l - 2 * (h - pp),
    };
  }

  _drawKeyLevels(plot, lo, hi, priceToY) {
    if (!this.showKeyLevels) return;
    const variant = this.pivotVariant || 'classical';
    const spans = this._dailySpans();
    if (spans.length < 2) return;  // need at least 1 prior day for any pivots
    const variantTag = variant === 'fibonacci' ? 'F'
        : variant === 'camarilla' ? 'C' : '';
    const colors = {
      r3: '#EF4444', r2: '#F87171', r1: '#FCA5A5',
      pp: '#FBBF24',
      s1: '#86EFAC', s2: '#4ADE80', s3: '#22C55E',
    };
    const labels = {
      r3: variantTag + 'R3', r2: variantTag + 'R2', r1: variantTag + 'R1',
      pp: 'PP',
      s1: variantTag + 'S1', s2: variantTag + 'S2', s3: variantTag + 'S3',
    };
    const order = ['r3', 'r2', 'r1', 'pp', 's1', 's2', 's3'];

    this.ctx.save();
    this.ctx.font = '600 9px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    this.ctx.textAlign = 'left';
    this.ctx.setLineDash([4, 4]);
    this.ctx.lineWidth = 1;
    // For each day (except the first), draw pivot lines spanning that day's
    // x-range, computed from the PRIOR day's H/L/C.
    for (let s = 1; s < spans.length; s++) {
      const prev = spans[s - 1];
      const cur = spans[s];
      const kl = this._pivotsFor(variant, prev.h, prev.l, prev.c);
      if (!kl) continue;
      // X span: left edge of the day's first candle to the right edge of its
      // last candle.
      const xLeft = this._candleXCenter(cur.startIdx, plot) - this.view.cellW / 2;
      const xRight = this._candleXCenter(cur.endIdx, plot) + this.view.cellW / 2;
      // Cull spans fully outside the plot.
      if (xRight < plot.left || xLeft > plot.right) continue;
      const x0 = Math.max(plot.left, xLeft);
      const x1 = Math.min(plot.right - 4, xRight);
      if (x1 <= x0) continue;
      for (const k of order) {
        const val = kl[k];
        if (!isFinite(val) || val < lo || val > hi) continue;
        const y = priceToY(val);
        this.ctx.strokeStyle = colors[k];
        this.ctx.beginPath();
        this.ctx.moveTo(x0, y);
        this.ctx.lineTo(x1, y);
        this.ctx.stroke();
        // Label at the day's left edge so each day's pivot lines are tagged.
        this.ctx.fillStyle = colors[k];
        this.ctx.fillText(labels[k], x0 + 4, y - 6);
      }
    }
    this.ctx.setLineDash([]);
    this.ctx.restore();
  }

  // ── Phase 16 F3 — Visible-range High/Low markers (Sahi-style) ────────────
  //
  // Scans the actual on-screen `visible` slice (passed in from draw() so we
  // don't have to re-derive scroll state) and annotates the highest + lowest
  // bar with a small filled dot at the exact price point plus the price text
  // just outside the wick. No chip background, no leader — a subtle marker
  // that matches the rest of the chart's axis-text styling.
  _drawHighLowMarkers(plot, priceToY, visible, firstVisibleAbs) {
    if (!this.showHighLowMarkers) return;
    if (!visible || visible.length < 2) return;
    const useClose = this.candleStyle === 'line' || this.candleStyle === 'area';
    let maxVal = -Infinity, minVal = Infinity;
    let maxRel = -1, minRel = -1;
    // Strict `>` / `<` so leftmost bar wins on ties — DO NOT change to `>=`.
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const hi = useClose ? c.c : c.h;
      const lo = useClose ? c.c : c.l;
      if (hi > maxVal) { maxVal = hi; maxRel = i; }
      if (lo < minVal) { minVal = lo; minRel = i; }
    }
    if (maxRel < 0 || minRel < 0) return;
    if (Math.abs(maxVal - minVal) < 1e-9) return;
    this._drawHLMarker(plot, priceToY, firstVisibleAbs + maxRel, maxVal, true);
    this._drawHLMarker(plot, priceToY, firstVisibleAbs + minRel, minVal, false);
  }

  _drawHLMarker(plot, priceToY, idx, value, isH) {
    const anchorX = this._candleXCenter(idx, plot);
    const anchorY = priceToY(value);
    if (anchorY < plot.top - 4 || anchorY > plot.bottom + 4) return;
    const color = this.palette.axisText;
    const decimals = this._priceDecimals();
    const text = value.toFixed(decimals);

    // Small filled dot at the exact price point.
    this.ctx.save();
    this.ctx.fillStyle = color;
    this.ctx.beginPath();
    this.ctx.arc(anchorX, anchorY, 2.5, 0, Math.PI * 2);
    this.ctx.fill();

    // Dotted leader line extending right from the dot, with the price text
    // off the end. Moving the text off the candle (instead of above/below the
    // wick) means it no longer collides with auto-pattern HH/HL/LH/LL labels
    // or the OHLC chip in the top-left.
    this.ctx.font = '600 10px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    this.ctx.textAlign = 'left';
    const leaderStart = anchorX + 5;
    const leaderLen = 28;
    let leaderEnd = leaderStart + leaderLen;
    const tw = this.ctx.measureText(text).width;
    // If the leader+text would bleed past the plot right edge, flip it to
    // extend LEFT of the dot instead.
    let textX = leaderEnd + 4;
    let flipped = false;
    if (textX + tw > plot.right - 4) {
      flipped = true;
      leaderEnd = anchorX - 5;
      const altStart = leaderEnd - leaderLen;
      textX = altStart - 4 - tw;
      // Stroke leader leftward
      this.ctx.strokeStyle = color;
      this.ctx.lineWidth = 1;
      this.ctx.setLineDash([2, 3]);
      this.ctx.beginPath();
      this.ctx.moveTo(altStart, anchorY);
      this.ctx.lineTo(leaderEnd, anchorY);
      this.ctx.stroke();
      this.ctx.setLineDash([]);
    } else {
      // Stroke leader rightward
      this.ctx.strokeStyle = color;
      this.ctx.lineWidth = 1;
      this.ctx.setLineDash([2, 3]);
      this.ctx.beginPath();
      this.ctx.moveTo(leaderStart, anchorY);
      this.ctx.lineTo(leaderEnd, anchorY);
      this.ctx.stroke();
      this.ctx.setLineDash([]);
    }
    this.ctx.fillStyle = color;
    this.ctx.fillText(text, flipped ? textX : (leaderEnd + 4), anchorY);
    this.ctx.restore();
  }

  // ── End Phase 16 F3 ───────────────────────────────────────────────────────

  // ── Phase 23.4 — Volume Profile gutter histogram ─────────────────────────

  _drawVolumeProfile(plot, lo, hi, priceToY) {
    if (!this.showVolumeProfile) return;
    const visible = this._visibleCandles();
    if (visible.length === 0) return;
    // 24 price bins between lo and hi.
    const bins = 24;
    const range = hi - lo;
    if (range <= 0) return;
    const buckets = new Array(bins).fill(0);
    let maxBucket = 0;
    for (const c of visible) {
      const mid = (c.h + c.l) / 2;
      const v = c.v || 0;
      if (v <= 0) continue;
      const idx = Math.max(0, Math.min(bins - 1,
          Math.floor((mid - lo) / range * bins)));
      buckets[idx] += v;
      if (buckets[idx] > maxBucket) maxBucket = buckets[idx];
    }
    if (maxBucket <= 0) return;
    const gutterRight = plot.right + 60; // sit RIGHT of price axis labels
    const gutterWidth = 60;
    const gutterLeft = gutterRight - gutterWidth;
    // Background tint so the profile reads as a distinct gutter.
    this.ctx.fillStyle = 'rgba(120,120,120,0.04)';
    this.ctx.fillRect(gutterLeft, plot.top, gutterWidth, plot.height);
    // Bars.
    const binH = plot.height / bins;
    for (let i = 0; i < bins; i++) {
      const v = buckets[i];
      if (v <= 0) continue;
      const len = (v / maxBucket) * (gutterWidth - 4);
      const binMid = lo + range * (i + 0.5) / bins;
      const y = priceToY(binMid);
      this.ctx.fillStyle = 'rgba(56, 189, 248, 0.45)'; // sky-400 alpha
      this.ctx.fillRect(gutterLeft + 2, y - binH * 0.4, len, binH * 0.8);
    }
  }

  // ── Sub-pane divider (drag-to-resize) ────────────────────────────────────
  _drawSubPaneDivider(plot, dividerY) {
    // dividerY is the top edge of the first sub-pane = bottom edge of the
    // candle area. We render a 6px-thick handle straddling that line with
    // a clearly visible 1px separator on both edges so the panes always
    // read as distinct regions.
    this._subDividerY = dividerY;
    const ctx = this.ctx;
    ctx.save();
    const hot = this._resizingSubPane || this._subDividerHover;
    // Soft fill band (the "grab plate")
    ctx.fillStyle = hot ? 'rgba(124,58,237,0.30)' : 'rgba(148,163,184,0.10)';
    ctx.fillRect(plot.left, dividerY - 3, plot.right - plot.left, 6);
    // Two crisp separator lines top + bottom of the band — these are the
    // actual border between candle pane and sub-pane.
    ctx.strokeStyle = hot ? '#A78BFA' : 'rgba(148,163,184,0.55)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(plot.left, dividerY - 3);
    ctx.lineTo(plot.right, dividerY - 3);
    ctx.moveTo(plot.left, dividerY + 3);
    ctx.lineTo(plot.right, dividerY + 3);
    ctx.stroke();
    // 5-dot grip handle in the centre — taller (3 rows × 2 cols) so it's
    // easier to spot.
    const cxg = (plot.left + plot.right) / 2;
    ctx.fillStyle = hot ? '#FFFFFF' : '#E5E7EB';
    for (const dx of [-2, 2]) {
      for (const dy of [-2, 0, 2]) {
        ctx.beginPath();
        ctx.arc(cxg + dx * 4, dividerY + dy, 1.3, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.restore();
  }

  // ── One-shot Measure overlay (transient) ─────────────────────────────────
  // Renders the in-progress preview (during the 2nd-click wait) AND the
  // committed-but-not-saved measurement (until cleared by next click).
  // Bar count uses ACTUAL candle indices between the two anchors — raw
  // (endTs - startTs) / barDuration over-counts by including session gaps.
  _drawActiveMeasure(plot, priceToY) {
    // Two render paths share the same logic — pull (p1, p2) from whichever
    // source exists.
    let p1 = null, p2 = null, isPreview = false;
    if (this._activeMeasure) {
      p1 = this._activeMeasure.p1;
      p2 = this._activeMeasure.p2;
    } else if (this._drawMode === 'measure' &&
               this._inProgressDrawing &&
               this._inProgressDrawing.kind === 'measure' &&
               this.hover.inside && this.hover.x != null) {
      p1 = this._inProgressDrawing.points[0];
      isPreview = true;
    }
    if (!p1) return;

    const ctx = this.ctx;
    const x1 = this._tsToX(p1.ts, plot);
    const y1 = priceToY(p1.price);
    let x2, y2, endPrice, endTs;
    if (p2) {
      x2 = this._tsToX(p2.ts, plot);
      y2 = priceToY(p2.price);
      endPrice = p2.price;
      endTs = p2.ts;
    } else {
      x2 = this.hover.x;
      y2 = this.hover.y;
      endPrice = this._yToPriceForDrag(y2) ?? p1.price;
      endTs = this._xToTs(x2);
    }
    if (!Number.isFinite(x1) || !Number.isFinite(y1) ||
        !Number.isFinite(x2) || !Number.isFinite(y2)) return;

    const dPrice = endPrice - p1.price;
    const isUp = dPrice >= 0;
    const tint = isUp ? (this.palette.bull || '#22C55E')
                      : (this.palette.bear || '#EF4444');
    const rx = Math.min(x1, x2);
    const ry = Math.min(y1, y2);
    const rw = Math.abs(x2 - x1);
    const rh = Math.abs(y2 - y1);

    ctx.save();
    // Tinted fill — slightly more transparent in preview so it doesn't
    // feel committed while the user is still picking the end point.
    ctx.fillStyle = _hexToRgba(tint, isPreview ? 0.10 : 0.18);
    ctx.fillRect(rx, ry, rw, rh);
    // Anchor + end price level lines
    ctx.strokeStyle = tint;
    ctx.lineWidth = 1.5;
    ctx.setLineDash(isPreview ? [4, 4] : []);
    ctx.beginPath();
    ctx.moveTo(rx, y1); ctx.lineTo(rx + rw, y1);
    ctx.moveTo(rx, y2); ctx.lineTo(rx + rw, y2);
    ctx.stroke();
    ctx.setLineDash([]);
    // Centre vertical with arrowhead at end
    const arrX = rx + rw / 2;
    ctx.beginPath();
    ctx.moveTo(arrX, y1);
    ctx.lineTo(arrX, y2);
    ctx.stroke();
    ctx.fillStyle = tint;
    ctx.beginPath();
    const ah = 7;
    if (isUp) {
      ctx.moveTo(arrX, y2);
      ctx.lineTo(arrX - ah / 2, y2 + ah);
      ctx.lineTo(arrX + ah / 2, y2 + ah);
    } else {
      ctx.moveTo(arrX, y2);
      ctx.lineTo(arrX - ah / 2, y2 - ah);
      ctx.lineTo(arrX + ah / 2, y2 - ah);
    }
    ctx.closePath();
    ctx.fill();

    // Bar count via candle indices — correct across session gaps.
    let bars = 0;
    if (this.candles.length > 0) {
      const i1 = this._candleAtX(x1);
      const i2 = this._candleAtX(x2);
      if (i1 >= 0 && i2 >= 0) {
        bars = Math.abs(i2 - i1);
      } else {
        const minutes = Math.max(1, this.timeframeMinutes || 1);
        bars = Math.max(0,
            Math.round(Math.abs(endTs - p1.ts) / (minutes * 60)));
      }
    }
    const pct = p1.price !== 0 ? (dPrice / p1.price) * 100 : 0;
    const sign = isUp ? '+' : '−';
    const absPrice = Math.abs(dPrice);
    const dp = this._priceDecimals();
    const label =
        `${sign}${absPrice.toFixed(dp)} (${sign}${Math.abs(pct).toFixed(2)}%)`;
    const sub = `${bars} bar${bars === 1 ? '' : 's'}`;

    ctx.font = '700 11px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';
    const labelW = Math.max(ctx.measureText(label).width,
                            ctx.measureText(sub).width) + 16;
    const boxX = Math.min(plot.right - labelW - 4,
        Math.max(plot.left + 4, arrX - labelW / 2));
    const boxY = isUp ? Math.max(plot.top + 4, y2 - 38)
                      : Math.min(plot.bottom - 40, y2 + 12);
    ctx.fillStyle = tint;
    this._roundedRect(boxX, boxY, labelW, 34, 6);
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(label, boxX + labelW / 2, boxY + 12);
    ctx.font = '500 10px Geist, sans-serif';
    ctx.fillText(sub, boxX + labelW / 2, boxY + 26);
    ctx.restore();
  }

  // ── Magnet target visual indicator ────────────────────────────────────────

  _drawMagnetTarget(plot, lo, hi, priceToY) {
    if (!this._drawMode || !this.magnetEnabled) return;
    if (!this.hover.inside || this.hover.x == null || this.hover.y == null) return;
    const candleIdx = this._candleAtX(this.hover.x);
    if (candleIdx < 0 || candleIdx >= this.candles.length) return;
    const c = this.candles[candleIdx];
    const targets = [
      { v: c.o, label: 'O' },
      { v: c.h, label: 'H' },
      { v: c.l, label: 'L' },
      { v: c.c, label: 'C' },
    ];
    let best = null;
    let bestDy = 8;
    for (const t of targets) {
      if (t.v < lo || t.v > hi) continue;
      const ty = priceToY(t.v);
      const dy = Math.abs(ty - this.hover.y);
      if (dy < bestDy) { bestDy = dy; best = t; }
    }
    if (!best) return;
    const tx = this._candleXCenter(candleIdx, plot);
    const ty = priceToY(best.v);
    // Snap target ring.
    this.ctx.save();
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.beginPath();
    this.ctx.arc(tx, ty, 4, 0, Math.PI * 2);
    this.ctx.fill();
    this.ctx.strokeStyle = '#22D3EE';
    this.ctx.lineWidth = 2;
    this.ctx.beginPath();
    this.ctx.arc(tx, ty, 4, 0, Math.PI * 2);
    this.ctx.stroke();
    // Small tooltip text to the right of the dot.
    this.ctx.font = '600 10px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    this.ctx.textAlign = 'left';
    this.ctx.fillStyle = '#22D3EE';
    this.ctx.fillText(`${best.label} ${best.v.toFixed(2)}`, tx + 8, ty);
    this.ctx.restore();
  }

  // ── Phase 18 — OI bars + hover tooltip + format helpers ──────────────────

  _drawOiBars(plot, lo, hi, priceToY) {
    if (!this.showOptionChainOi || !this._oiData || this._oiData.length === 0) return;
    // Filter to visible strikes; compute max OI for scaling.
    let maxOi = 0;
    const visible = [];
    for (const s of this._oiData) {
      if (typeof s.strike !== 'number') continue;
      if (s.strike < lo || s.strike > hi) continue;
      visible.push(s);
      const c = s.callOi || 0;
      const p = s.putOi || 0;
      if (c > maxOi) maxOi = c;
      if (p > maxOi) maxOi = p;
    }
    if (visible.length === 0 || maxOi <= 0) return;

    const barH = 4;
    const gap = 1;
    const barRight = plot.right - 8;
    const maxBarLen = Math.max(20, plot.width * 0.25);
    const ceColor = '#22D3EE'; // teal-cyan for CE
    const peColor = '#FB923C'; // orange for PE

    for (const s of visible) {
      const y = priceToY(s.strike);
      const ceLen = ((s.callOi || 0) / maxOi) * maxBarLen;
      const peLen = ((s.putOi || 0) / maxOi) * maxBarLen;
      // CE bar above the strike Y, PE bar below.
      this.ctx.fillStyle = ceColor;
      this.ctx.fillRect(barRight - ceLen, y - barH - gap / 2, ceLen, barH);
      this.ctx.fillStyle = peColor;
      this.ctx.fillRect(barRight - peLen, y + gap / 2, peLen, barH);
    }

    // Hover tooltip: only when cursor is over the bar strip and near a strike.
    if (this.hover.inside && this.hover.x != null && this.hover.y != null) {
      const stripLeft = barRight - maxBarLen;
      if (this.hover.x >= stripLeft && this.hover.x <= barRight) {
        // Find the nearest visible strike within a generous Y tolerance.
        const rowH = (barH * 2) + gap;
        const tol = Math.max(rowH * 2, 14);
        let best = null;
        let bestDy = Infinity;
        for (const s of visible) {
          const sy = priceToY(s.strike);
          const dy = Math.abs(sy - this.hover.y);
          if (dy < bestDy && dy <= tol) { bestDy = dy; best = s; }
        }
        if (best) this._drawOiHoverTooltip(plot, best);
      }
    }
  }

  _drawOiHoverTooltip(plot, s) {
    const padX = 8, padY = 6, lineH = 14;
    const lines = [
      `Strike:   ${this._fmtStrike(s.strike)}`,
      `Call OI:  ${this._fmtOi(s.callOi)}  ${this._fmtPct(s.callOiChgPct)}`,
      `Put OI:   ${this._fmtOi(s.putOi)}  ${this._fmtPct(s.putOiChgPct)}`,
    ];
    this.ctx.font = '500 11px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    this.ctx.textAlign = 'left';
    let maxW = 0;
    for (const l of lines) {
      const w = this.ctx.measureText(l).width;
      if (w > maxW) maxW = w;
    }
    const boxW = Math.ceil(maxW + padX * 2);
    const boxH = lines.length * lineH + padY * 2;
    // Position to the LEFT of the cursor by default; flip if no room.
    let bx = this.hover.x - boxW - 12;
    if (bx < plot.left + 4) bx = this.hover.x + 12;
    let by = this.hover.y - boxH / 2;
    if (by < plot.top + 4) by = plot.top + 4;
    if (by + boxH > plot.bottom - 4) by = plot.bottom - 4 - boxH;
    this.ctx.fillStyle = this.palette.crosshairChip || 'rgba(20,20,20,0.92)';
    this._roundedRect(bx, by, boxW, boxH, 4);
    this.ctx.fill();
    this.ctx.strokeStyle = 'rgba(255,255,255,0.15)';
    this.ctx.lineWidth = 1;
    this._roundedRect(bx, by, boxW, boxH, 4);
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.chipText || '#FFFFFF';
    for (let i = 0; i < lines.length; i++) {
      this.ctx.fillText(lines[i], bx + padX, by + padY + lineH * (i + 0.5));
    }
  }

  _fmtStrike(v) {
    if (typeof v !== 'number' || !isFinite(v)) return '';
    return v === Math.floor(v) ? String(v) : v.toFixed(2);
  }

  _fmtOi(v) {
    if (typeof v !== 'number' || !isFinite(v) || v <= 0) return '0';
    if (v >= 10000000) return (v / 10000000).toFixed(1) + 'Cr';
    if (v >= 100000) return (v / 100000).toFixed(1) + 'L';
    if (v >= 1000) return (v / 1000).toFixed(1) + 'K';
    return String(Math.round(v));
  }

  _fmtPct(v) {
    if (typeof v !== 'number' || !isFinite(v)) return '';
    const sign = v >= 0 ? '+' : '';
    return `(${sign}${v.toFixed(1)}%)`;
  }

  // ── End Phase 18 ──────────────────────────────────────────────────────────

  _drawLtpLine(plot, priceToY, lo, hi) {
    if (this.candles.length === 0) return;
    const last = this.candles[this.candles.length - 1];
    const ltp = last.c;
    if (ltp < lo || ltp > hi) return; // off-screen vertically (user panned away)
    const y = priceToY(ltp);
    // Dashed horizontal line across the plot.
    this.ctx.strokeStyle = this.palette.crosshair;
    this.ctx.lineWidth = 1;
    this.ctx.setLineDash([3, 3]);
    this.ctx.beginPath();
    this.ctx.moveTo(plot.left, y);
    this.ctx.lineTo(plot.right, y);
    this.ctx.stroke();
    this.ctx.setLineDash([]);
    // Price chip on the right axis, coloured by the latest candle's
    // direction so the live price reads at a glance.
    // Clamp chip's Y into the main plot so when LTP sits near the bottom
    // of the candle range the chip doesn't bleed into the sub-pane area
    // below (used to overlap with sub-pane axis labels / value chips).
    const up = last.c >= last.o;
    const color = up ? this.palette.bull : this.palette.bear;
    this.ctx.font = '700 10px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    const text = ltp.toFixed(this._priceDecimals());
    const tw = this.ctx.measureText(text).width + 10;
    const chipW = Math.min(tw, 60);
    // Reserve enough vertical room for the chip + 1px gap + countdown
    // sub-chip (13px) when it's enabled, so the whole LTP block stays
    // above plot.bottom.
    const cdEnabled = this.showBarCountdown &&
        this.candles.length > 0 &&
        typeof this.timeframeMinutes === 'number' &&
        this.timeframeMinutes > 0;
    const blockH = 16 + (cdEnabled ? 14 : 0);
    const cy = Math.max(plot.top + 8,
        Math.min(plot.bottom - 8 - (blockH - 16), y));
    this.ctx.fillStyle = color;
    this._roundedRect(plot.right + 2, cy - 8, chipW, 16, 3);
    this.ctx.fill();
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.textAlign = 'center';
    this.ctx.fillText(text, plot.right + 2 + chipW / 2, cy);
    this._registerAxisChipSlot(cy, 16);

    // Phase 18 — bar-close countdown directly under the LTP value, in a
    // continuous sub-chip below the existing one. Same fill colour so it
    // reads as a single 2-row chip.
    if (cdEnabled) {
      const lastBar = this.candles[this.candles.length - 1];
      const closeSec = (lastBar.ts || 0) + this.timeframeMinutes * 60;
      const nowSec = Math.floor(Date.now() / 1000);
      const left = Math.max(0, closeSec - nowSec);
      const mins = Math.floor(left / 60);
      const secs = left % 60;
      const cdText = mins + ':' + String(secs).padStart(2, '0');
      const subH = 13;
      const subY = cy - 8 + 16 + 1; // chip bottom + 1px gap
      this.ctx.fillStyle = color;
      this._roundedRect(plot.right + 2, subY, chipW, subH, 3);
      this.ctx.fill();
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.font = '500 9px Geist, sans-serif';
      this.ctx.textAlign = 'center';
      this.ctx.textBaseline = 'middle';
      this.ctx.fillText(cdText, plot.right + 2 + chipW / 2, subY + subH / 2);
      this._registerAxisChipSlot(subY + subH / 2, subH);
    }
  }

  _drawTimeAxis(plot, visible) {
    if (visible.length === 0) return;
    this.ctx.fillStyle = this.palette.axisText;
    this.ctx.font = '500 10px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    this.ctx.textAlign = 'center';
    const yAxis = this.canvas.clientHeight - 10;
    // Cadence: ~80px between labels. Keyed on the ABSOLUTE candle index so
    // the same candles stay labeled while panning — otherwise the modulus
    // shifts every frame and labels appear to jitter/flicker.
    const labelCadence = Math.max(1, Math.round(80 / this.view.cellW));
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const firstAbs = this.candles.indexOf(visible[0]);
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      if (absIdx % labelCadence !== 0) continue;
      const c = visible[i];
      const xCenter = this._candleXCenter(absIdx, plot);
      const ist = new Date(c.ts * 1000 + (5.5 * 3600 * 1000));
      let label;
      if (this.timeframeMinutes >= 1440) {
        label = ist.getUTCDate() + ' ' + months[ist.getUTCMonth()];
      } else {
        const hh = String(ist.getUTCHours()).padStart(2, '0');
        const mm = String(ist.getUTCMinutes()).padStart(2, '0');
        label = hh + ':' + mm;
        // Day prefix on candles that cross a midnight boundary in the
        // absolute series — checking absIdx-1 keeps the decision stable
        // across pans (independent of which candle happens to be visible[0]).
        if (absIdx > 0) {
          const prev = new Date(this.candles[absIdx - 1].ts * 1000 + (5.5 * 3600 * 1000));
          if (prev.getUTCDate() !== ist.getUTCDate() ||
              prev.getUTCMonth() !== ist.getUTCMonth()) {
            label = ist.getUTCDate() + '/' + (ist.getUTCMonth() + 1) + ' ' + label;
          }
        }
      }
      this.ctx.fillText(label, xCenter, yAxis);
    }
  }

  // ----- Phase 8 — Indicator compute helpers ------------------------------
  // SMA / EMA / RSI all operate on the close series of `this.candles`.
  // Returned arrays are the same length as `this.candles`; leading entries
  // (before the indicator has enough history) are `null` so the renderer can
  // skip them without ambiguity.
  _computeSMA(period) {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (period <= 0 || n < period) return out;
    let sum = 0;
    for (let i = 0; i < n; i++) {
      sum += this.candles[i].c;
      if (i >= period) sum -= this.candles[i - period].c;
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }

  _computeEMA(period) {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (period <= 0 || n === 0) return out;
    const k = 2 / (period + 1);
    let ema = null;
    for (let i = 0; i < n; i++) {
      const c = this.candles[i].c;
      if (ema == null) ema = c;
      else ema = c * k + ema * (1 - k);
      if (i >= period - 1) out[i] = ema;
    }
    return out;
  }

  _computeRSI(period) {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (period <= 0 || n < period + 1) return out;
    let avgGain = 0, avgLoss = 0;
    for (let i = 1; i <= period; i++) {
      const ch = this.candles[i].c - this.candles[i - 1].c;
      if (ch >= 0) avgGain += ch;
      else avgLoss -= ch;
    }
    avgGain /= period;
    avgLoss /= period;
    const rs0 = avgLoss === 0 ? 100 : avgGain / avgLoss;
    out[period] = avgLoss === 0 ? 100 : 100 - 100 / (1 + rs0);
    for (let i = period + 1; i < n; i++) {
      const ch = this.candles[i].c - this.candles[i - 1].c;
      const g = ch > 0 ? ch : 0;
      const l = ch < 0 ? -ch : 0;
      avgGain = (avgGain * (period - 1) + g) / period;
      avgLoss = (avgLoss * (period - 1) + l) / period;
      const rs = avgLoss === 0 ? 100 : avgGain / avgLoss;
      out[i] = avgLoss === 0 ? 100 : 100 - 100 / (1 + rs);
    }
    return out;
  }

  // ---------- Phase 11 ----------

  // Accepts either a number (legacy) or an indicator-like object with
  // `{ params, period }` so the schema-driven dialog can override `length`
  // and `mult` without breaking older call sites.
  _computeBB(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const period = (arg && typeof arg === 'object')
        ? (+p.length || +arg.period || 20)
        : (+arg || 20);
    const STDDEV = +p.mult || 2;
    const n = this.candles.length;
    const mid = new Array(n).fill(null);
    const upper = new Array(n).fill(null);
    const lower = new Array(n).fill(null);
    if (period <= 1 || n < period) return { mid, upper, lower };
    let sum = 0;
    let sumSq = 0;
    for (let i = 0; i < n; i++) {
      const c = this.candles[i].c;
      sum += c;
      sumSq += c * c;
      if (i >= period) {
        const out = this.candles[i - period].c;
        sum -= out;
        sumSq -= out * out;
      }
      if (i >= period - 1) {
        const m = sum / period;
        const variance = Math.max(0, sumSq / period - m * m);
        const sd = Math.sqrt(variance);
        mid[i] = m;
        upper[i] = m + STDDEV * sd;
        lower[i] = m - STDDEV * sd;
      }
    }
    return { mid, upper, lower };
  }

  _computeVWAP() {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (n === 0) return out;
    const DAY_SEC = 86400;
    let prevDay = null;
    let cumPV = 0;
    let cumV = 0;
    for (let i = 0; i < n; i++) {
      const c = this.candles[i];
      const day = Math.floor(c.ts / DAY_SEC);
      if (prevDay !== null && day !== prevDay) {
        cumPV = 0;
        cumV = 0;
      }
      prevDay = day;
      const typical = (c.h + c.l + c.c) / 3;
      cumPV += typical * c.v;
      cumV += c.v;
      out[i] = cumV > 0 ? cumPV / cumV : null;
    }
    return out;
  }

  // Accepts an indicator-like object so the schema-driven dialog can override
  // fast/slow/signal. Legacy `undefined` keeps TradingView defaults.
  _computeMACD(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const FAST = +p.fast || 12;
    const SLOW = +p.slow || 26;
    const SIGNAL = +p.signal || 9;
    const fast = this._computeEMA(FAST);
    const slow = this._computeEMA(SLOW);
    const n = this.candles.length;
    const macd = new Array(n).fill(null);
    for (let i = 0; i < n; i++) {
      if (fast[i] != null && slow[i] != null) macd[i] = fast[i] - slow[i];
    }
    // Signal = EMA of macd line (skipping the leading nulls).
    const signal = new Array(n).fill(null);
    let started = false;
    let ema = null;
    const k = 2 / (SIGNAL + 1);
    let countSinceStart = 0;
    for (let i = 0; i < n; i++) {
      const v = macd[i];
      if (v == null) continue;
      if (!started) { ema = v; started = true; countSinceStart = 1; }
      else { ema = v * k + ema * (1 - k); countSinceStart++; }
      if (countSinceStart >= SIGNAL) signal[i] = ema;
    }
    const hist = new Array(n).fill(null);
    for (let i = 0; i < n; i++) {
      if (macd[i] != null && signal[i] != null) hist[i] = macd[i] - signal[i];
    }
    return { macd, signal, hist, periods: { fast: FAST, slow: SLOW, signal: SIGNAL } };
  }

  // Accepts a number (legacy: kPeriod) OR an indicator-like object with
  // `{ params, period }`. Schema keys: kPeriod, dPeriod, smooth.
  // When `params` is absent we keep the original behaviour exactly:
  //   k = raw fast-stoch over `period`, d = SMA(k, 3).
  // With params present, k is first smoothed by `smooth` (when > 1),
  // then d = SMA(smoothedK, dPeriod).
  _computeStoch(arg) {
    const hasParams = !!(arg && typeof arg === 'object' &&
        arg.params && Object.keys(arg.params).length > 0);
    const p = hasParams ? arg.params : {};
    const period = (arg && typeof arg === 'object')
        ? (+p.kPeriod || +arg.period || 14)
        : (+arg || 14);
    const SMOOTH = hasParams ? (+p.smooth || 1) : 1; // legacy: no extra K smoothing
    const D_PERIOD = hasParams ? (+p.dPeriod || 3) : 3;
    const n = this.candles.length;
    const kRaw = new Array(n).fill(null);
    if (period <= 0 || n < period) return { k: kRaw, d: new Array(n).fill(null) };
    for (let i = period - 1; i < n; i++) {
      let lo = Infinity, hi = -Infinity;
      for (let j = i - period + 1; j <= i; j++) {
        if (this.candles[j].l < lo) lo = this.candles[j].l;
        if (this.candles[j].h > hi) hi = this.candles[j].h;
      }
      const range = hi - lo;
      kRaw[i] = range > 0 ? ((this.candles[i].c - lo) / range) * 100 : 50;
    }
    let kOut = kRaw;
    if (SMOOTH > 1) {
      kOut = new Array(n).fill(null);
      for (let i = 0; i < n; i++) {
        if (i < period - 1 + SMOOTH - 1) continue;
        let sum = 0;
        let count = 0;
        for (let j = i - SMOOTH + 1; j <= i; j++) {
          if (kRaw[j] != null) { sum += kRaw[j]; count++; }
        }
        if (count === SMOOTH) kOut[i] = sum / SMOOTH;
      }
    }
    const d = new Array(n).fill(null);
    for (let i = 0; i < n; i++) {
      let sum = 0;
      let count = 0;
      for (let j = i - D_PERIOD + 1; j <= i; j++) {
        if (j < 0) continue;
        if (kOut[j] != null) { sum += kOut[j]; count++; }
      }
      if (count === D_PERIOD) d[i] = sum / D_PERIOD;
    }
    return { k: kOut, d };
  }

  _computeATR(period) {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (period <= 0 || n < period + 1) return out;
    // True range per bar.
    const tr = new Array(n).fill(0);
    tr[0] = this.candles[0].h - this.candles[0].l;
    for (let i = 1; i < n; i++) {
      const c = this.candles[i];
      const pc = this.candles[i - 1].c;
      tr[i] = Math.max(c.h - c.l, Math.abs(c.h - pc), Math.abs(c.l - pc));
    }
    // Wilder smoothing — first ATR = average of first `period` TRs.
    let sum = 0;
    for (let i = 0; i < period; i++) sum += tr[i];
    out[period - 1] = sum / period;
    for (let i = period; i < n; i++) {
      out[i] = (out[i - 1] * (period - 1) + tr[i]) / period;
    }
    return out;
  }

  // Phase 20 — Stochastic RSI: Stochastic of the RSI series, period default 14
  // on both legs. Returns array of {k, d} values aligned to candles (nulls for
  // the warm-up period). %K is the raw stoch; %D is its 3-period SMA.
  // Accepts a number (legacy: rsi length) OR an indicator-like object.
  // Schema keys: rsiLength, stochLength, kPeriod, dPeriod.
  _computeStochRsi(arg) {
    const hasParams = !!(arg && typeof arg === 'object' &&
        arg.params && Object.keys(arg.params).length > 0);
    const p = hasParams ? arg.params : {};
    const rsiLength = (arg && typeof arg === 'object')
        ? Math.max(1, (+p.rsiLength || +arg.period || 14) | 0)
        : Math.max(1, (+arg || 14) | 0);
    const stochLength = Math.max(1, (+p.stochLength || rsiLength) | 0);
    // Legacy: raw %K (kSmooth=1) + 3-SMA %D; only apply user K-smoothing when
    // the schema-driven dialog has written a non-empty params bag.
    const kSmooth = hasParams ? Math.max(1, (+p.kPeriod || 3) | 0) : 1;
    const dSmooth = Math.max(1, (+p.dPeriod || 3) | 0);
    const rsi = this._computeRSI(rsiLength);
    const raw = new Array(this.candles.length).fill(null);
    const window = [];
    for (let i = 0; i < rsi.length; i++) {
      const v = rsi[i];
      if (v == null || !isFinite(v)) { window.length = 0; continue; }
      window.push(v);
      if (window.length > stochLength) window.shift();
      if (window.length < stochLength) continue;
      let lo = Infinity, hi = -Infinity;
      for (const x of window) { if (x < lo) lo = x; if (x > hi) hi = x; }
      const denom = hi - lo;
      raw[i] = denom > 0 ? ((v - lo) / denom) * 100 : 50;
    }
    // %K = SMA(raw, kSmooth) — when kSmooth=1 this is a passthrough.
    const out = new Array(raw.length).fill(null);
    const kBuf = [];
    for (let i = 0; i < raw.length; i++) {
      const r = raw[i];
      if (r == null) { kBuf.length = 0; continue; }
      kBuf.push(r);
      if (kBuf.length > kSmooth) kBuf.shift();
      if (kBuf.length === kSmooth) {
        let s = 0; for (const x of kBuf) s += x; out[i] = s / kSmooth;
      }
    }
    // %D = SMA(%K, dSmooth)
    const smoothed = new Array(out.length).fill(null);
    const buf = [];
    for (let i = 0; i < out.length; i++) {
      const k = out[i];
      if (k == null) { buf.length = 0; smoothed[i] = null; continue; }
      buf.push(k);
      if (buf.length > dSmooth) buf.shift();
      if (buf.length === dSmooth) {
        let s = 0; for (const x of buf) s += x; smoothed[i] = s / dSmooth;
      } else {
        smoothed[i] = null;
      }
    }
    return out.map((k, i) => ({ k, d: smoothed[i] }));
  }

  // Phase 20 — Zero-Lag EMA: ZLEMA = EMA(2*src - EMA(src, n), n)
  _computeZLEMA(period) {
    const n = Math.max(1, period | 0);
    const k = 2 / (n + 1);
    const src = this.candles.map((c) => c.c);
    // First EMA pass
    const e1 = new Array(src.length);
    let prev = null;
    for (let i = 0; i < src.length; i++) {
      prev = prev == null ? src[i] : (src[i] * k + prev * (1 - k));
      e1[i] = prev;
    }
    // De-lagged input
    const dl = src.map((s, i) => 2 * s - e1[i]);
    // Second EMA pass
    const out = new Array(src.length);
    prev = null;
    for (let i = 0; i < dl.length; i++) {
      prev = prev == null ? dl[i] : (dl[i] * k + prev * (1 - k));
      out[i] = prev;
    }
    // First (n-1) values are warm-up; null them so they don't draw.
    for (let i = 0; i < Math.min(n - 1, out.length); i++) out[i] = null;
    return out;
  }

  // Phase 20 — McGinley Dynamic: adaptive moving average that responds faster
  // in trending markets, slower in choppy ones. MD = MD_prev + (C - MD_prev) /
  // (N * (C / MD_prev)^4). First value seeded from close.
  _computeMcGinley(period) {
    const n = Math.max(1, period | 0);
    const out = new Array(this.candles.length).fill(null);
    let md = null;
    for (let i = 0; i < this.candles.length; i++) {
      const c = this.candles[i].c;
      if (md == null) { md = c; out[i] = null; continue; }
      const ratio = c / md;
      const denom = n * Math.pow(ratio, 4);
      md = md + (c - md) / (denom || n);
      out[i] = md;
    }
    for (let i = 0; i < Math.min(n - 1, out.length); i++) out[i] = null;
    return out;
  }

  // Phase 20 — Elder's Force Index: (Close - PrevClose) * Volume.
  // Smoothed with EMA(period). Drawn as a sub-pane histogram around zero.
  _computeEFI(period) {
    const n = Math.max(1, period | 0);
    const raw = new Array(this.candles.length).fill(null);
    for (let i = 1; i < this.candles.length; i++) {
      const a = this.candles[i - 1];
      const b = this.candles[i];
      const v = b.v || 0;
      raw[i] = (b.c - a.c) * v;
    }
    // EMA smoothing
    const k = 2 / (n + 1);
    const out = new Array(raw.length).fill(null);
    let prev = null;
    for (let i = 0; i < raw.length; i++) {
      const r = raw[i];
      if (r == null) { out[i] = null; continue; }
      prev = prev == null ? r : (r * k + prev * (1 - k));
      out[i] = prev;
    }
    return out;
  }

  // Phase 20 — Squeeze Momentum (LazyBear simplified): BB inside KC = squeeze
  // ON (red/yellow dot), BB outside KC = squeeze OFF (green/blue dot). Momentum
  // histogram is linear regression of (close - midpoint) over the period.
  // Returns array of {mom, squeezeOn} per candle (null until warmed up).
  // Accepts a number (legacy: shared length for BB+KC) OR an indicator-like
  // object. Schema keys: bbLength, bbMult, kcLength, kcMult. When the two
  // lengths differ we use max(bbLength, kcLength) as the lookback window for
  // the momentum/linregress calc (same as the LazyBear reference).
  _computeSqueeze(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const baseLen = (arg && typeof arg === 'object')
        ? Math.max(1, (+arg.period || 20) | 0)
        : Math.max(1, (+arg || 20) | 0);
    const bbLength = Math.max(1, (+p.bbLength || baseLen) | 0);
    const kcLength = Math.max(1, (+p.kcLength || baseLen) | 0);
    const mult = +p.bbMult || 2;
    const kcMult = +p.kcMult || 1.5;
    const n = Math.max(bbLength, kcLength);
    const out = new Array(this.candles.length).fill(null);
    if (this.candles.length < n) return out;
    // Pre-compute true range for KC.
    const tr = new Array(this.candles.length).fill(0);
    for (let i = 0; i < this.candles.length; i++) {
      const c = this.candles[i];
      if (i === 0) { tr[i] = c.h - c.l; continue; }
      const pp = this.candles[i - 1];
      tr[i] = Math.max(c.h - c.l, Math.abs(c.h - pp.c), Math.abs(c.l - pp.c));
    }
    for (let i = n - 1; i < this.candles.length; i++) {
      // SMA + stddev for BB over bbLength
      let sumBB = 0;
      for (let j = i - bbLength + 1; j <= i; j++) sumBB += this.candles[j].c;
      const meanBB = sumBB / bbLength;
      let sumSq = 0;
      for (let j = i - bbLength + 1; j <= i; j++) {
        const d = this.candles[j].c - meanBB;
        sumSq += d * d;
      }
      const sd = Math.sqrt(sumSq / bbLength);
      const bbU = meanBB + mult * sd;
      const bbL = meanBB - mult * sd;
      // KC: SMA ± kcMult * ATR(kcLength)
      let sumKc = 0;
      for (let j = i - kcLength + 1; j <= i; j++) sumKc += this.candles[j].c;
      const meanKC = sumKc / kcLength;
      let sumTr = 0;
      for (let j = i - kcLength + 1; j <= i; j++) sumTr += tr[j];
      const atr = sumTr / kcLength;
      const kcU = meanKC + kcMult * atr;
      const kcL = meanKC - kcMult * atr;
      const squeezeOn = bbU < kcU && bbL > kcL;
      let hi = -Infinity, lo = Infinity;
      for (let j = i - n + 1; j <= i; j++) {
        if (this.candles[j].h > hi) hi = this.candles[j].h;
        if (this.candles[j].l < lo) lo = this.candles[j].l;
      }
      const mid = ((hi + lo) / 2 + meanBB) / 2;
      let sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for (let j = 0; j < n; j++) {
        const y = this.candles[i - n + 1 + j].c - mid;
        sumX += j; sumY += y; sumXY += j * y; sumX2 += j * j;
      }
      const denom = (n * sumX2 - sumX * sumX);
      const slope = denom !== 0 ? (n * sumXY - sumX * sumY) / denom : 0;
      const intercept = (sumY - slope * sumX) / n;
      const mom = slope * (n - 1) + intercept;
      out[i] = { mom, squeezeOn };
    }
    return out;
  }

  // Phase 22 — WaveTrend Oscillator (LazyBear). Returns {wt1, wt2} per candle
  // (nulls until warmed up). Period default 10 channel + ~21 average.
  _computeWaveTrend(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const baseLen = (arg && typeof arg === 'object')
        ? Math.max(1, (+arg.period || 10) | 0)
        : Math.max(1, (+arg || 10) | 0);
    const n = Math.max(1, (+p.channelLength || baseLen) | 0);
    const n2 = Math.max(1, (+p.averageLength || Math.round(n * 2.1)) | 0);
    const tp = this.candles.map((c) => (c.h + c.l + c.c) / 3);
    // ESA = EMA(tp, n)
    const k1 = 2 / (n + 1);
    const esa = new Array(tp.length);
    let prev = null;
    for (let i = 0; i < tp.length; i++) {
      prev = prev == null ? tp[i] : (tp[i] * k1 + prev * (1 - k1));
      esa[i] = prev;
    }
    // D = EMA(abs(tp - esa), n)
    const d = new Array(tp.length);
    prev = null;
    for (let i = 0; i < tp.length; i++) {
      const x = Math.abs(tp[i] - esa[i]);
      prev = prev == null ? x : (x * k1 + prev * (1 - k1));
      d[i] = prev;
    }
    // CI = (tp - esa) / (0.015 * d)
    const ci = tp.map((t, i) =>
        d[i] > 0 ? (t - esa[i]) / (0.015 * d[i]) : 0);
    // WT1 = EMA(ci, n2), WT2 = SMA(wt1, 4)
    const k2 = 2 / (n2 + 1);
    const wt1 = new Array(ci.length);
    prev = null;
    for (let i = 0; i < ci.length; i++) {
      prev = prev == null ? ci[i] : (ci[i] * k2 + prev * (1 - k2));
      wt1[i] = prev;
    }
    const wt2 = new Array(wt1.length).fill(null);
    for (let i = 3; i < wt1.length; i++) {
      wt2[i] = (wt1[i] + wt1[i-1] + wt1[i-2] + wt1[i-3]) / 4;
    }
    const out = wt1.map((v, i) => ({ wt1: v, wt2: wt2[i] }));
    for (let i = 0; i < Math.min(n + n2 - 1, out.length); i++) {
      out[i] = { wt1: null, wt2: null };
    }
    return out;
  }

  // Phase 22 — Connors RSI = (RSI(close,n) + RSI(streak,2) + PercentRank(roc,100)) / 3.
  // Default n=3. Returns array of numbers (or null while warming).
  _computeConnorsRSI(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const rsiLen = (arg && typeof arg === 'object')
        ? Math.max(1, (+p.rsiLength || +arg.period || 3) | 0)
        : Math.max(1, (+arg || 3) | 0);
    const streakLen = Math.max(1, (+p.streakLength || 2) | 0);
    const rocLen = Math.max(2, (+p.rocLength || 100) | 0);
    const close = this.candles.map((c) => c.c);
    const rsi1 = this._rsiOnSeries(close, rsiLen);
    const streak = new Array(close.length).fill(0);
    for (let i = 1; i < close.length; i++) {
      if (close[i] > close[i - 1]) streak[i] = streak[i - 1] >= 0 ? streak[i - 1] + 1 : 1;
      else if (close[i] < close[i - 1]) streak[i] = streak[i - 1] <= 0 ? streak[i - 1] - 1 : -1;
      else streak[i] = 0;
    }
    const rsi2 = this._rsiOnSeries(streak, streakLen);
    const roc = new Array(close.length).fill(0);
    for (let i = 1; i < close.length; i++) {
      const pp = close[i - 1];
      roc[i] = pp > 0 ? ((close[i] - pp) / pp) * 100 : 0;
    }
    const pct = new Array(close.length).fill(null);
    for (let i = 0; i < close.length; i++) {
      if (i < rocLen) continue;
      let count = 0;
      const cur = roc[i];
      for (let j = i - rocLen; j < i; j++) if (roc[j] < cur) count++;
      pct[i] = (count / rocLen) * 100;
    }
    const out = new Array(close.length).fill(null);
    for (let i = 0; i < close.length; i++) {
      if (rsi1[i] == null || rsi2[i] == null || pct[i] == null) continue;
      out[i] = (rsi1[i] + rsi2[i] + pct[i]) / 3;
    }
    return out;
  }

  // Internal helper — RSI on an arbitrary numeric series.
  _rsiOnSeries(src, n) {
    const out = new Array(src.length).fill(null);
    if (src.length < n + 1) return out;
    let avgU = 0, avgD = 0;
    for (let i = 1; i <= n; i++) {
      const d = src[i] - src[i - 1];
      if (d > 0) avgU += d; else avgD += -d;
    }
    avgU /= n; avgD /= n;
    out[n] = avgD === 0 ? 100 : 100 - 100 / (1 + avgU / avgD);
    for (let i = n + 1; i < src.length; i++) {
      const d = src[i] - src[i - 1];
      const u = d > 0 ? d : 0;
      const dn = d < 0 ? -d : 0;
      avgU = (avgU * (n - 1) + u) / n;
      avgD = (avgD * (n - 1) + dn) / n;
      out[i] = avgD === 0 ? 100 : 100 - 100 / (1 + avgU / avgD);
    }
    return out;
  }

  // Phase 22 — MA Ribbon: 8 EMAs at 5/10/20/30/40/50/60/80. Returns
  // { periods, lines } where lines is an array of 8 value arrays.
  _computeMaRibbon() {
    const periods = [5, 10, 20, 30, 40, 50, 60, 80];
    const src = this.candles.map((c) => c.c);
    const lines = periods.map((p) => {
      const k = 2 / (p + 1);
      const out = new Array(src.length).fill(null);
      let prev = null;
      for (let i = 0; i < src.length; i++) {
        prev = prev == null ? src[i] : (src[i] * k + prev * (1 - k));
        if (i >= p - 1) out[i] = prev;
      }
      return out;
    });
    return { periods, lines };
  }

  // Phase 22 — Ichimoku Cloud. Default conversion=9, base=26, span=52,
  // displacement=26. Returns {tenkan, kijun, spanA, spanB, chikou} arrays.
  _computeIchimoku(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const conv = Math.max(2, (+p.tenkan || 9) | 0);
    const base = Math.max(2, (+p.kijun || 26) | 0);
    const span = Math.max(2, (+p.senkouB || 52) | 0);
    const disp = Math.max(1, (+p.displacement || 26) | 0);
    const high  = this.candles.map((c) => c.h);
    const low   = this.candles.map((c) => c.l);
    const close = this.candles.map((c) => c.c);
    const N = close.length;
    const hh = (i, w) => { let m = -Infinity; for (let j = i - w + 1; j <= i; j++) if (j >= 0 && high[j] > m) m = high[j]; return m; };
    const ll = (i, w) => { let m =  Infinity; for (let j = i - w + 1; j <= i; j++) if (j >= 0 && low[j]  < m) m = low[j];  return m; };
    const tenkan = new Array(N).fill(null);
    const kijun  = new Array(N).fill(null);
    const spanA  = new Array(N).fill(null);
    const spanB  = new Array(N).fill(null);
    const chikou = new Array(N).fill(null);
    for (let i = 0; i < N; i++) {
      if (i >= conv - 1) tenkan[i] = (hh(i, conv) + ll(i, conv)) / 2;
      if (i >= base - 1) kijun[i]  = (hh(i, base) + ll(i, base)) / 2;
      if (tenkan[i] != null && kijun[i] != null && i + disp < N) {
        spanA[i + disp] = (tenkan[i] + kijun[i]) / 2;
      }
      if (i >= span - 1 && i + disp < N) {
        spanB[i + disp] = (hh(i, span) + ll(i, span)) / 2;
      }
      if (i + disp < N) chikou[i + disp] = close[i];
    }
    return { tenkan, kijun, spanA, spanB, chikou };
  }

  // Phase 22 — Volatility Stop (ATR-based trailing stop). When price is above
  // the stop, stop trails below; flips on close-cross. Returns {stop[], dir[]}.
  _computeVolStop(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const n = (arg && typeof arg === 'object')
        ? Math.max(1, (+p.length || +arg.period || 14) | 0)
        : Math.max(1, (+arg || 14) | 0);
    const mult = +p.multiplier || 2;
    const N = this.candles.length;
    if (N === 0) return { stop: [], dir: [] };
    // ATR
    const tr = new Array(N).fill(0);
    for (let i = 0; i < N; i++) {
      const c = this.candles[i];
      if (i === 0) { tr[i] = c.h - c.l; continue; }
      const p = this.candles[i - 1];
      tr[i] = Math.max(c.h - c.l, Math.abs(c.h - p.c), Math.abs(c.l - p.c));
    }
    const atr = new Array(N).fill(0);
    for (let i = 0; i < N; i++) {
      if (i < n) {
        let s = 0; for (let j = 0; j <= i; j++) s += tr[j];
        atr[i] = s / (i + 1);
      } else {
        atr[i] = (atr[i - 1] * (n - 1) + tr[i]) / n;
      }
    }
    const stop = new Array(N).fill(null);
    const dir = new Array(N).fill(null); // 1 = long-trailing-below, -1 = short-trailing-above
    let dDir = 1;
    let s = this.candles[0].c - mult * atr[0];
    stop[0] = s; dir[0] = dDir;
    for (let i = 1; i < N; i++) {
      const c = this.candles[i].c;
      const a = atr[i] * mult;
      if (dDir === 1) {
        const ns = Math.max(stop[i - 1] || -Infinity, c - a);
        if (c < ns) { dDir = -1; s = c + a; }
        else s = ns;
      } else {
        const ns = Math.min(stop[i - 1] || Infinity, c + a);
        if (c > ns) { dDir = 1; s = c - a; }
        else s = ns;
      }
      stop[i] = s; dir[i] = dDir;
    }
    return { stop, dir };
  }

  // ICT/SMC "Change in State of Delivery". A bullish CISD fires when a
  // bullish candle's body-close pierces the OPENING price of the most
  // recent bearish "delivery leg" (single bearish candle or consecutive
  // run of bearish candles). Bearish CISD is the symmetric inverse.
  // Wicks are explicitly ignored — only candle opens/closes matter
  // (the canonical doctrinal rule across every ICT-aligned source).
  //
  // Returns `{ events: [{i, kind:'bull'|'bear', level, endIdx, isStrict}] }`
  // where `endIdx` is the bar at which the line ends (invalidation by an
  // opposite-direction close past the level, or `i + expiryBars` expiry,
  // whichever is first). Strict mode filters: the opposing leg's first
  // candle must be at a swing pivot AND the triggering candle's body must
  // be >= `minBodyRatio` × its range.
  //
  // Sourced from a deep-research pass on 2026-05-30 verifying 19/25 claims
  // — see docs/superpowers/specs/2026-05-30-cisd-indicator-design.md.
  _computeCisd(ind) {
    const N = this.candles.length;
    if (N === 0) return { events: [] };
    const p = (ind && typeof ind === 'object') ? (ind.params || {}) : {};
    const strict = (+p.strictMode === 0) ? false : true;
    const pivotWidth = Math.max(1, (+p.pivotWidth || 2) | 0);
    const minBodyRatio = +p.minBodyRatio || (strict ? 0.65 : 0.50);
    const expiryBars = Math.max(1, (+p.expiryBars || 50) | 0);

    // Pre-compute per-candle direction (1=bull, -1=bear, 0=doji or zero-range).
    const dir = new Array(N);
    for (let i = 0; i < N; i++) {
      const c = this.candles[i];
      const range = c.h - c.l;
      if (range <= 0 || c.c === c.o) { dir[i] = 0; continue; }
      dir[i] = c.c > c.o ? 1 : -1;
    }

    // Single pass: walk candles, accumulate consecutive same-direction legs
    // (dojis are skipped — they don't break the current leg but don't
    // extend it either). Maintain the most-recently-COMPLETED opposing leg
    // for CISD detection; once a CISD fires for a leg, that leg's level is
    // "consumed" and we wait for a new opposing leg before the next CISD.
    const events = [];
    let curLeg = null;             // { startIdx, dir, firstOpen }
    let lastBearLeg = null;        // most recent completed bear leg (consumable)
    let lastBullLeg = null;        // most recent completed bull leg (consumable)

    const isSwingLow = (idx) => {
      // Idx must be a fractal swing low across ±pivotWidth bars. Right-side
      // confirmation: caller ensures idx + pivotWidth < N.
      const lo = this.candles[idx].l;
      for (let k = idx - pivotWidth; k <= idx + pivotWidth; k++) {
        if (k < 0 || k >= N || k === idx) continue;
        if (this.candles[k].l <= lo) return false;
      }
      return true;
    };
    const isSwingHigh = (idx) => {
      const hi = this.candles[idx].h;
      for (let k = idx - pivotWidth; k <= idx + pivotWidth; k++) {
        if (k < 0 || k >= N || k === idx) continue;
        if (this.candles[k].h >= hi) return false;
      }
      return true;
    };

    for (let i = 0; i < N; i++) {
      const c = this.candles[i];
      const d = dir[i];
      if (d === 0) continue;            // doji / zero-range → skip

      // Leg accumulation: either extend or rotate. When rotating, the
      // previously-active leg is published as the most-recent completed
      // leg of its direction.
      if (curLeg && curLeg.dir === d) {
        // Same-direction → extend (nothing to do; we only care about
        // firstOpen + dir which were set when the leg started).
      } else {
        if (curLeg) {
          if (curLeg.dir === 1) lastBullLeg = curLeg;
          else                  lastBearLeg = curLeg;
        }
        curLeg = { startIdx: i, dir: d, firstOpen: c.o, broken: false };
      }

      // CISD detection — body-close through the most recent opposing leg's
      // first.open. One event per opposing leg (broken-flag consumes it).
      const opposing = d === 1 ? lastBearLeg : lastBullLeg;
      if (!opposing || opposing.broken) continue;
      const level = opposing.firstOpen;
      const piercedBull = (d === 1 && c.c > level);
      const piercedBear = (d === -1 && c.c < level);
      if (!piercedBull && !piercedBear) continue;

      // Strict-mode filters: swing pivot at opposing leg's first candle +
      // displacement-grade body on the triggering candle.
      let isStrict = false;
      if (strict) {
        const pivotIdx = opposing.startIdx;
        // Right-side bars needed to confirm the pivot — if not yet present,
        // defer (don't emit yet; will re-evaluate on next frame via memo
        // invalidation when candles.length grows).
        if (pivotIdx + pivotWidth >= N) continue;
        const pivotOk = piercedBull ? isSwingLow(pivotIdx) : isSwingHigh(pivotIdx);
        if (!pivotOk) {
          // Pivot filter failed — consume the leg anyway so we don't
          // re-test it on every subsequent same-direction candle.
          opposing.broken = true;
          continue;
        }
        const range = c.h - c.l;
        const bodyRatio = range > 0 ? Math.abs(c.c - c.o) / range : 0;
        if (bodyRatio < minBodyRatio) {
          opposing.broken = true;
          continue;
        }
        isStrict = true;
      }

      // Determine when the line ends — first opposite-direction close past
      // the level, or expiry, whichever is first. Walk forward from i+1.
      let endIdx = Math.min(i + expiryBars, N - 1);
      for (let j = i + 1; j <= endIdx; j++) {
        const cj = this.candles[j];
        if (piercedBull && cj.c < level) { endIdx = j; break; }
        if (piercedBear && cj.c > level) { endIdx = j; break; }
      }

      events.push({
        i,
        kind: piercedBull ? 'bull' : 'bear',
        level,
        endIdx,
        isStrict,
      });
      opposing.broken = true;          // consume — no further CISD for this leg
    }
    return { events };
  }

  // ICT Fair Value Gap — 3-candle imbalance where candle[i-1] and candle[i+1]
  // don't overlap, leaving a price void around the middle (impulse) candle.
  //   Bullish: candle[i-1].h < candle[i+1].l  → gap [c[i-1].h, c[i+1].l]
  //   Bearish: candle[i-1].l > candle[i+1].h  → gap [c[i+1].h, c[i-1].l]
  // Mitigation = any subsequent candle's wick enters the gap. Strict mode
  // additionally requires the impulse candle's body / range >= minBodyRatio.
  _computeFvg(ind) {
    const N = this.candles.length;
    if (N < 3) return { gaps: [] };
    const p = (ind && typeof ind === 'object') ? (ind.params || {}) : {};
    const strict = (+p.strictMode === 1);
    const minBodyRatio = +p.minBodyRatio || 0.50;
    const extendBars = Math.max(1, (+p.extendBars || 30) | 0);

    const gaps = [];
    for (let i = 1; i < N - 1; i++) {
      const prev = this.candles[i - 1];
      const next = this.candles[i + 1];
      const mid = this.candles[i];
      let kind = null;
      let gapLow = 0;
      let gapHigh = 0;
      if (prev.h < next.l) {
        kind = 'bull';
        gapLow = prev.h;
        gapHigh = next.l;
      } else if (prev.l > next.h) {
        kind = 'bear';
        gapLow = next.h;
        gapHigh = prev.l;
      } else {
        continue;
      }
      if (strict) {
        const range = mid.h - mid.l;
        const bodyRatio = range > 0 ? Math.abs(mid.c - mid.o) / range : 0;
        if (bodyRatio < minBodyRatio) continue;
      }
      // Find mitigation — first candle after i+1 whose wick enters [gapLow,gapHigh].
      // Bullish gap is filled from above (a low touches/crosses gapHigh down to gapLow);
      // bearish from below (a high touches/crosses gapLow up to gapHigh). We treat
      // any wick intrusion as mitigation per the spec.
      let mitigatedAt = -1;
      const scanEnd = Math.min(N - 1, i + 1 + extendBars);
      for (let k = i + 2; k <= scanEnd; k++) {
        const ck = this.candles[k];
        if (kind === 'bull') {
          if (ck.l <= gapHigh) { mitigatedAt = k; break; }
        } else {
          if (ck.h >= gapLow) { mitigatedAt = k; break; }
        }
      }
      const endIdx = mitigatedAt >= 0 ? mitigatedAt : scanEnd;
      gaps.push({
        startIdx: i + 1,
        endIdx,
        kind,
        gapLow,
        gapHigh,
        mitigated: mitigatedAt >= 0,
      });
    }
    return { gaps };
  }

  // ICT/SMC Order Block — last opposing candle before an ATR-scaled impulse.
  // Walk forward; when candle i is a bullish impulse (close>open AND
  // abs(c-o)/ATR >= threshold), the OB is the most recent bearish candle
  // immediately preceding it (and vice-versa for bearish impulse). The
  // bearish/bullish RUN before the impulse is collapsed into one OB
  // (matches Lux/Inner-Circle implementations: the entire opposing leg's
  // extremes form the zone, not just the single touching bar).
  _computeOb(ind) {
    const N = this.candles.length;
    if (N < 3) return { blocks: [] };
    const p = (ind && typeof ind === 'object') ? (ind.params || {}) : {};
    const atrPeriod = Math.max(2, (+p.atrPeriod || 14) | 0);
    const threshold = +p.impulseThreshold || 1.5;
    const useBodyOnly = (+p.useBodyOnly === 0) ? false : true;
    const extendBars = Math.max(1, (+p.extendBars || 100) | 0);

    const atr = this._computeATR(atrPeriod);
    const blocks = [];
    for (let i = 1; i < N; i++) {
      const c = this.candles[i];
      const a = atr[i];
      if (a == null || a <= 0) continue;
      const body = Math.abs(c.c - c.o);
      if (body / a < threshold) continue;
      const impulseDir = c.c > c.o ? 1 : (c.c < c.o ? -1 : 0);
      if (impulseDir === 0) continue;
      // Walk back over the immediately-preceding opposing-direction run.
      const opposingDir = -impulseDir;
      let runStart = -1;
      let runEnd = -1;
      for (let k = i - 1; k >= 0; k--) {
        const ck = this.candles[k];
        const dk = ck.c > ck.o ? 1 : (ck.c < ck.o ? -1 : 0);
        if (dk === opposingDir) {
          if (runEnd < 0) runEnd = k;
          runStart = k;
          continue;
        }
        if (runEnd >= 0) break;        // run ended — stop scanning
        if (dk === 0) continue;         // skip dojis if no run yet
        break;                           // hit same-direction without finding a run
      }
      if (runStart < 0) continue;
      // Compute OB extremes across the run.
      let zoneHigh = -Infinity;
      let zoneLow = Infinity;
      for (let k = runStart; k <= runEnd; k++) {
        const ck = this.candles[k];
        if (useBodyOnly) {
          zoneHigh = Math.max(zoneHigh, ck.o, ck.c);
          zoneLow = Math.min(zoneLow, ck.o, ck.c);
        } else {
          zoneHigh = Math.max(zoneHigh, ck.h);
          zoneLow = Math.min(zoneLow, ck.l);
        }
      }
      // De-duplicate: if the previous OB shares the same run-end, skip
      // (chained impulses pointing at the same opposing leg shouldn't
      // emit multiple boxes).
      if (blocks.length > 0 && blocks[blocks.length - 1].sourceIdx === runEnd) {
        continue;
      }
      // Mitigation — for a bullish OB (zone below impulse), price re-enters
      // when a later candle's low crosses BELOW zoneHigh. Symmetric inverse
      // for bearish OBs.
      const kind = impulseDir === 1 ? 'bull' : 'bear';
      let mitigatedAt = -1;
      const scanEnd = Math.min(N - 1, i + extendBars);
      for (let k = i + 1; k <= scanEnd; k++) {
        const ck = this.candles[k];
        if (kind === 'bull') {
          if (ck.l <= zoneHigh) { mitigatedAt = k; break; }
        } else {
          if (ck.h >= zoneLow) { mitigatedAt = k; break; }
        }
      }
      const endIdx = mitigatedAt >= 0 ? mitigatedAt : scanEnd;
      blocks.push({
        sourceIdx: runEnd,
        impulseIdx: i,
        endIdx,
        kind,
        zoneHigh,
        zoneLow,
        mitigated: mitigatedAt >= 0,
      });
    }
    return { blocks };
  }

  // ICT Liquidity Sweep — a candle whose wick pierces a prior swing high/low
  // but whose close stays inside the swept level. Pivots are right-confirmed
  // fractals (need `pivotWidth` bars on the right before they're known); the
  // sweep itself happens any time after pivot confirmation. A pivot is
  // consumed by the first sweep so it doesn't keep emitting markers.
  _computeLiqSweep(ind) {
    const N = this.candles.length;
    if (N < 3) return { sweeps: [] };
    const p = (ind && typeof ind === 'object') ? (ind.params || {}) : {};
    const pivotWidth = Math.max(1, (+p.pivotWidth || 2) | 0);

    const isSwingHigh = (idx) => {
      const hi = this.candles[idx].h;
      for (let k = idx - pivotWidth; k <= idx + pivotWidth; k++) {
        if (k < 0 || k >= N || k === idx) continue;
        if (this.candles[k].h >= hi) return false;
      }
      return true;
    };
    const isSwingLow = (idx) => {
      const lo = this.candles[idx].l;
      for (let k = idx - pivotWidth; k <= idx + pivotWidth; k++) {
        if (k < 0 || k >= N || k === idx) continue;
        if (this.candles[k].l <= lo) return false;
      }
      return true;
    };

    const sweeps = [];
    const activeHighs = [];       // pivots awaiting a sweep; consumed once swept
    const activeLows = [];
    for (let i = 0; i < N; i++) {
      // Confirm pivots whose right side just completed.
      const confirmAt = i - pivotWidth;
      if (confirmAt >= pivotWidth) {
        if (isSwingHigh(confirmAt)) {
          activeHighs.push({ idx: confirmAt, level: this.candles[confirmAt].h });
        }
        if (isSwingLow(confirmAt)) {
          activeLows.push({ idx: confirmAt, level: this.candles[confirmAt].l });
        }
      }
      const c = this.candles[i];
      for (let k = activeHighs.length - 1; k >= 0; k--) {
        const pv = activeHighs[k];
        if (pv.idx >= i) continue;
        if (c.h > pv.level && c.c < pv.level) {
          sweeps.push({
            i, kind: 'bear', pivotIdx: pv.idx, level: pv.level,
          });
          activeHighs.splice(k, 1);
        }
      }
      for (let k = activeLows.length - 1; k >= 0; k--) {
        const pv = activeLows[k];
        if (pv.idx >= i) continue;
        if (c.l < pv.level && c.c > pv.level) {
          sweeps.push({
            i, kind: 'bull', pivotIdx: pv.idx, level: pv.level,
          });
          activeLows.splice(k, 1);
        }
      }
    }
    return { sweeps };
  }

  // ICT/SMC Market Structure — emit BOS / CHoCH / MSS labels when a candle
  // closes through the most-recent unbroken swing pivot. Current trend is
  // tracked across the pass: a same-direction break is BOS (continuation),
  // an opposite-direction break is CHoCH (and upgrades to MSS if the break
  // candle's body ratio clears `minBodyRatio`). A break also flips the
  // tracked trend so the NEXT opposite break is again a CHoCH/MSS.
  _computeMss(ind) {
    const N = this.candles.length;
    if (N < 5) return { events: [] };
    const p = (ind && typeof ind === 'object') ? (ind.params || {}) : {};
    const pivotWidth = Math.max(1, (+p.pivotWidth || 2) | 0);
    const minBodyRatio = +p.minBodyRatio || 0.65;

    const isSwingHigh = (idx) => {
      const hi = this.candles[idx].h;
      for (let k = idx - pivotWidth; k <= idx + pivotWidth; k++) {
        if (k < 0 || k >= N || k === idx) continue;
        if (this.candles[k].h >= hi) return false;
      }
      return true;
    };
    const isSwingLow = (idx) => {
      const lo = this.candles[idx].l;
      for (let k = idx - pivotWidth; k <= idx + pivotWidth; k++) {
        if (k < 0 || k >= N || k === idx) continue;
        if (this.candles[k].l <= lo) return false;
      }
      return true;
    };

    const events = [];
    const activeHighs = [];       // unbroken swing-high pivots
    const activeLows = [];
    let trend = 0;                // 1=bull, -1=bear, 0=undetermined
    for (let i = 0; i < N; i++) {
      const confirmAt = i - pivotWidth;
      if (confirmAt >= pivotWidth) {
        if (isSwingHigh(confirmAt)) {
          activeHighs.push({ idx: confirmAt, level: this.candles[confirmAt].h });
        }
        if (isSwingLow(confirmAt)) {
          activeLows.push({ idx: confirmAt, level: this.candles[confirmAt].l });
        }
      }
      const c = this.candles[i];
      const range = c.h - c.l;
      const bodyRatio = range > 0 ? Math.abs(c.c - c.o) / range : 0;

      // Bullish break — close above the most-recent unbroken swing high.
      // Walk newest-first; consume only the first one broken (pivots older
      // than the broken one stay active for chained breaks on later bars).
      for (let k = activeHighs.length - 1; k >= 0; k--) {
        const pv = activeHighs[k];
        if (pv.idx >= i) continue;
        if (c.c <= pv.level) continue;
        let label;
        if (trend === 1) {
          label = 'BOS';
        } else if (trend === -1) {
          label = bodyRatio >= minBodyRatio ? 'MSS' : 'CHoCH';
        } else {
          label = 'BOS';            // first-ever break — treat as continuation
        }
        events.push({
          i, kind: 'bull', label, pivotIdx: pv.idx, level: pv.level,
        });
        activeHighs.splice(k, 1);
        trend = 1;
        break;
      }
      // Bearish break — close below most-recent unbroken swing low.
      for (let k = activeLows.length - 1; k >= 0; k--) {
        const pv = activeLows[k];
        if (pv.idx >= i) continue;
        if (c.c >= pv.level) continue;
        let label;
        if (trend === -1) {
          label = 'BOS';
        } else if (trend === 1) {
          label = bodyRatio >= minBodyRatio ? 'MSS' : 'CHoCH';
        } else {
          label = 'BOS';
        }
        events.push({
          i, kind: 'bear', label, pivotIdx: pv.idx, level: pv.level,
        });
        activeLows.splice(k, 1);
        trend = -1;
        break;
      }
    }
    return { events };
  }

  // ----- Phase 8 — Renderers ----------------------------------------------
  // SMA / EMA draw as a single line on the candle pane. Each indicator gets
  // a small label chip at the latest data point so multiple SMAs at different
  // periods stay distinguishable.
  _drawIndicators(plot, lo, hi, priceToY) {
    if (this._indicators.length === 0 || this.candles.length === 0) return;
    // Phase 16 F2 — on Renko, indicators run on brick close-prices so that
    // they align with the rendered bricks instead of the underlying bar series.
    // We temporarily swap this.candles so that all internal compute helpers
    // (_computeSMA, _computeEMA, _computeRSI, …) and _visibleCandles() see the
    // brick-derived pseudo-candle array without any other code path being
    // affected (JS is single-threaded; no concurrent draw).
    const seriesBars = this.candleStyle === 'renko'
        ? this._renkoBricks.map((b) => ({
            c: b.closePrice, h: b.closePrice, l: b.closePrice,
            o: b.openPrice, ts: b.sourceBarTime, v: 0,
          }))
        : (this._isRebinnedStyle(this.candleStyle)
            && this._rebinnedStyle === this.candleStyle
            && this._rebinned.length > 0)
          // Phase 26 — rebinned styles already carry {o,h,l,c,v,ts}; run
          // indicators on those pseudo-candles so X aligns with the rebinned
          // series (same logic as the renko branch above).
          ? this._rebinned
          : this.candles;
    const _savedCandles = this.candles;
    this.candles = seriesBars;
    try {
      const visible = this._visibleCandles();
      if (visible.length === 0) return;
      const firstAbs = seriesBars.indexOf(visible[0]);
      const ctx = this.ctx;
      ctx.save();

      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind === 'bb') {
          const bands = this._computeBB(ind);
          const drawSeries = (values, lineW) => {
            ctx.strokeStyle = ind.color || '#8B5CF6';
            ctx.lineWidth = lineW;
            ctx.beginPath();
            let started = false;
            for (let i = 0; i < visible.length; i++) {
              const absIdx = firstAbs + i;
              const v = values[absIdx];
              if (v == null) continue;
              const x = this._candleXCenter(absIdx, plot);
              const y = priceToY(v);
              if (!started) { ctx.moveTo(x, y); started = true; }
              else ctx.lineTo(x, y);
            }
            ctx.stroke();
          };
          drawSeries(bands.upper, 1);
          drawSeries(bands.mid, 1.5);
          drawSeries(bands.lower, 1);
          // Right-axis value chips for all three bands so the user can read
          // the active BB envelope without crosshair-hovering.
          const lastIdx = firstAbs + visible.length - 1;
          this._drawIndicatorAxisChip(
              plot, priceToY, bands.upper[lastIdx], ind.color || '#8B5CF6');
          this._drawIndicatorAxisChip(
              plot, priceToY, bands.mid[lastIdx], ind.color || '#8B5CF6');
          this._drawIndicatorAxisChip(
              plot, priceToY, bands.lower[lastIdx], ind.color || '#8B5CF6');
          continue;
        }
        if (ind.kind === 'vwap') {
          const values = this._computeVWAP();
          ctx.strokeStyle = ind.color || '#06B6D4';
          // ind.thickness drives line width — fall back to 1.5 (pleasing
          // default on retina) when thickness is unset or equals 1.
          ctx.lineWidth = (ind.thickness && ind.thickness > 1) ? ind.thickness : 1.5;
          ctx.beginPath();
          let started = false;
          for (let i = 0; i < visible.length; i++) {
            const absIdx = firstAbs + i;
            const v = values[absIdx];
            if (v == null) continue;
            const x = this._candleXCenter(absIdx, plot);
            const y = priceToY(v);
            if (!started) { ctx.moveTo(x, y); started = true; }
            else ctx.lineTo(x, y);
          }
          ctx.stroke();
          // Right-axis colored value chip — same pattern as the LTP chip,
          // matches the line's colour so the user can scan multiple lines.
          const last = values[firstAbs + visible.length - 1];
          this._drawIndicatorAxisChip(
              plot, priceToY, last, ind.color || '#06B6D4');
          continue;
        }
        // Sub-pane kinds are handled in _drawSubPanes — skip here.
        if (ind.kind === 'rsi' || ind.kind === 'macd' ||
            ind.kind === 'stoch' || ind.kind === 'atr' ||
            ind.kind === 'stochrsi' || ind.kind === 'squeeze' || ind.kind === 'efi') continue;
        if (ind.kind !== 'sma' && ind.kind !== 'ema') continue;
        const values = ind.kind === 'sma'
            ? this._computeSMA(ind.period)
            : this._computeEMA(ind.period);
        ctx.strokeStyle = ind.color || '#3B82F6';
        ctx.lineWidth = (ind.thickness && ind.thickness > 1) ? ind.thickness : 1.5;
        ctx.beginPath();
        let started = false;
        for (let i = 0; i < visible.length; i++) {
          const absIdx = firstAbs + i;
          const v = values[absIdx];
          if (v == null) continue;
          const x = this._candleXCenter(absIdx, plot);
          const y = priceToY(v);
          if (!started) { ctx.moveTo(x, y); started = true; }
          else ctx.lineTo(x, y);
        }
        ctx.stroke();

        // Right-axis colored value chip showing the indicator's current
        // value, in its own colour. Replaces the old inline label that
        // floated next to the last candle — that info is already in the
        // chip strip at top.
        const lastAbs = firstAbs + visible.length - 1;
        this._drawIndicatorAxisChip(
            plot, priceToY, values[lastAbs], ind.color || '#3B82F6');
      }

      // Phase 20 — ZLEMA + McGinley render on candle pane like SMA/EMA.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'zlema' && ind.kind !== 'mcginley') continue;
        const values = ind.kind === 'zlema'
            ? this._computeZLEMA(ind.period)
            : this._computeMcGinley(ind.period);
        ctx.strokeStyle = ind.color || '#3B82F6';
        ctx.lineWidth = (ind.thickness && ind.thickness > 1) ? ind.thickness : 1.5;
        ctx.beginPath();
        let started = false;
        for (let i = 0; i < this.candles.length; i++) {
          const v = values[i];
          if (v == null || !isFinite(v) || v < lo || v > hi) {
            started = false;
            continue;
          }
          const x = this._candleXCenter(i, plot);
          const y = priceToY(v);
          if (!started) {
            ctx.moveTo(x, y);
            started = true;
          } else {
            ctx.lineTo(x, y);
          }
        }
        ctx.stroke();
        // Right-axis value chip for the most-recent visible value.
        let lastV = null;
        for (let i = this.candles.length - 1; i >= 0; i--) {
          const v = values[i];
          if (v != null && isFinite(v)) { lastV = v; break; }
        }
        this._drawIndicatorAxisChip(
            plot, priceToY, lastV, ind.color || '#3B82F6');
      }

      // Phase 22 — MA Ribbon: render 8 EMAs in a fading-color palette.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'ribbon') continue;
        const { periods, lines } = this._computeMaRibbon();
        const baseHue = 210; // blue family
        for (let li = 0; li < lines.length; li++) {
          const vals = lines[li];
          const lightness = 35 + li * 6; // 35..77
          this.ctx.strokeStyle = `hsl(${baseHue},70%,${lightness}%)`;
          this.ctx.lineWidth = 1;
          this.ctx.beginPath();
          let started = false;
          for (let i = 0; i < this.candles.length; i++) {
            const v = vals[i];
            if (v == null || !isFinite(v) || v < lo || v > hi) { started = false; continue; }
            const x = this._candleXCenter(i, plot);
            const y = priceToY(v);
            if (!started) { this.ctx.moveTo(x, y); started = true; }
            else this.ctx.lineTo(x, y);
          }
          this.ctx.stroke();
        }
        void periods;
      }

      // Phase 22 — Ichimoku Cloud: 5 lines + filled cloud between Senkou A/B.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'ichi') continue;
        const ic = this._computeIchimoku(ind);
        // Cloud fill
        this.ctx.save();
        this.ctx.beginPath();
        let firstX = null;
        for (let i = 0; i < ic.spanA.length; i++) {
          const a = ic.spanA[i], b = ic.spanB[i];
          if (a == null || b == null) continue;
          const x = this._candleXCenter(i, plot);
          if (firstX == null) { this.ctx.moveTo(x, priceToY(a)); firstX = x; }
          else this.ctx.lineTo(x, priceToY(a));
        }
        for (let i = ic.spanB.length - 1; i >= 0; i--) {
          const a = ic.spanA[i], b = ic.spanB[i];
          if (a == null || b == null) continue;
          const x = this._candleXCenter(i, plot);
          this.ctx.lineTo(x, priceToY(b));
        }
        this.ctx.closePath();
        this.ctx.fillStyle = 'rgba(34,197,94,0.10)';
        this.ctx.fill();
        this.ctx.restore();
        // Tenkan + Kijun + SpanA + SpanB lines
        const ichiSeries = [
          { vals: ic.tenkan, color: '#3B82F6', w: 1.25 },
          { vals: ic.kijun,  color: '#EF4444', w: 1.25 },
          { vals: ic.spanA,  color: '#10B981', w: 1   },
          { vals: ic.spanB,  color: '#F59E0B', w: 1   },
        ];
        for (const s of ichiSeries) {
          this.ctx.strokeStyle = s.color;
          this.ctx.lineWidth = s.w;
          this.ctx.beginPath();
          let started = false;
          for (let i = 0; i < s.vals.length; i++) {
            const v = s.vals[i];
            if (v == null || !isFinite(v)) { started = false; continue; }
            const x = this._candleXCenter(i, plot);
            const y = priceToY(v);
            if (!started) { this.ctx.moveTo(x, y); started = true; }
            else this.ctx.lineTo(x, y);
          }
          this.ctx.stroke();
        }
      }

      // Phase 22 — Volatility Stop: dotted line in current trend color.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'vstop') continue;
        const vs = this._computeVolStop(ind);
        this.ctx.save();
        this.ctx.setLineDash([2, 2]);
        this.ctx.lineWidth = 1.25;
        let prevDir = null;
        let started = false;
        this.ctx.beginPath();
        for (let i = 0; i < vs.stop.length; i++) {
          const v = vs.stop[i];
          const d = vs.dir[i];
          if (v == null || !isFinite(v)) { started = false; prevDir = d; continue; }
          if (d !== prevDir && started) {
            this.ctx.stroke();
            this.ctx.beginPath();
            started = false;
          }
          this.ctx.strokeStyle = d === 1 ? '#22C55E' : '#EF4444';
          const x = this._candleXCenter(i, plot);
          const y = priceToY(v);
          if (!started) { this.ctx.moveTo(x, y); started = true; }
          else this.ctx.lineTo(x, y);
          prevDir = d;
        }
        this.ctx.stroke();
        this.ctx.setLineDash([]);
        this.ctx.restore();
      }

      // CISD — body-close break of opposing delivery leg's first.open.
      // Per event we draw: (1) a colored horizontal line at the break
      // level spanning [event.i .. event.endIdx], and (2) in strict mode
      // a filled triangle marker at the triggering candle (▲ below for
      // bullish, ▼ above for bearish). Max-lines pruning keeps the most
      // recent N visible (older events dropped from render, kept in the
      // compute output so memoization stays stable across frames).
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'cisd') continue;
        const { events } = this._computeCisd(ind);
        if (!events || events.length === 0) continue;
        const p = (ind.params || {});
        const maxLines = Math.max(1, (+p.maxLines || 10) | 0);
        const bullColor = ind.color || '#22C55E';
        const bearColor = '#EF4444';
        const lineW = (ind.thickness && ind.thickness > 1) ? ind.thickness : 1.5;
        const visible = events.slice(-maxLines);
        for (const ev of visible) {
          const color = ev.kind === 'bull' ? bullColor : bearColor;
          const x1 = this._candleXCenter(ev.i, plot);
          const x2 = this._candleXCenter(ev.endIdx, plot);
          const y = priceToY(ev.level);
          ctx.save();
          ctx.strokeStyle = color;
          ctx.lineWidth = lineW;
          ctx.beginPath();
          ctx.moveTo(x1, y);
          ctx.lineTo(x2, y);
          ctx.stroke();
          // Strict-mode marker — small filled triangle at the event candle.
          // Bullish ▲ sits below the candle's low; bearish ▼ above the high.
          if (ev.isStrict) {
            const evC = this.candles[ev.i];
            const size = 5;
            const cx = this._candleXCenter(ev.i, plot);
            const lowY = priceToY(evC.l);
            const highY = priceToY(evC.h);
            ctx.fillStyle = color;
            ctx.beginPath();
            if (ev.kind === 'bull') {
              const ty = lowY + 8;
              ctx.moveTo(cx, ty);
              ctx.lineTo(cx - size, ty + size * 1.5);
              ctx.lineTo(cx + size, ty + size * 1.5);
            } else {
              const ty = highY - 8;
              ctx.moveTo(cx, ty);
              ctx.lineTo(cx - size, ty - size * 1.5);
              ctx.lineTo(cx + size, ty - size * 1.5);
            }
            ctx.closePath();
            ctx.fill();
          }
          ctx.restore();
        }
      }

      // FVG — translucent rect for each gap, faded outline if mitigated.
      // Box spans candle (startIdx) → mitigation candle (or extendBars cap).
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'fvg') continue;
        const { gaps } = this._computeFvg(ind);
        if (!gaps || gaps.length === 0) continue;
        const p = (ind.params || {});
        const maxBoxes = Math.max(1, (+p.maxBoxes || 20) | 0);
        const showMitigated = (+p.showMitigated === 0) ? false : true;
        const bullColor = ind.color || '#22C55E';
        const bearColor = '#EF4444';
        const visible = gaps.slice(-maxBoxes);
        for (const g of visible) {
          if (g.mitigated && !showMitigated) continue;
          const color = g.kind === 'bull' ? bullColor : bearColor;
          const x1 = this._candleXCenter(g.startIdx, plot);
          const x2 = this._candleXCenter(g.endIdx, plot);
          const yHi = priceToY(g.gapHigh);
          const yLo = priceToY(g.gapLow);
          const top = Math.min(yHi, yLo);
          const bot = Math.max(yHi, yLo);
          const left = Math.min(x1, x2);
          const width = Math.max(1, Math.abs(x2 - x1));
          const height = Math.max(1, bot - top);
          ctx.save();
          if (g.mitigated) {
            ctx.fillStyle = _hexToRgba(color, 0.05);
            ctx.fillRect(left, top, width, height);
            ctx.strokeStyle = _hexToRgba(color, 0.35);
            ctx.lineWidth = 1;
            // Mitigated: only draw the boundary line (gap edge that price
            // closed through first — bullish=top, bearish=bottom).
            ctx.beginPath();
            const edgeY = g.kind === 'bull' ? top : bot;
            ctx.moveTo(left, edgeY);
            ctx.lineTo(left + width, edgeY);
            ctx.stroke();
          } else {
            ctx.fillStyle = _hexToRgba(color, 0.15);
            ctx.fillRect(left, top, width, height);
            ctx.strokeStyle = _hexToRgba(color, 0.6);
            ctx.lineWidth = 1;
            ctx.strokeRect(left + 0.5, top + 0.5, width - 1, height - 1);
          }
          ctx.restore();
        }
      }

      // Order Blocks — translucent rectangle on the OB zone, "OB" label
      // near the right edge when the box is wide enough to host text.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'ob') continue;
        const { blocks } = this._computeOb(ind);
        if (!blocks || blocks.length === 0) continue;
        const p = (ind.params || {});
        const maxBoxes = Math.max(1, (+p.maxBoxes || 10) | 0);
        const showMitigated = (+p.showMitigated === 1);
        const bullColor = ind.color || '#22C55E';
        const bearColor = '#EF4444';
        const visible = blocks.slice(-maxBoxes);
        for (const b of visible) {
          if (b.mitigated && !showMitigated) continue;
          const color = b.kind === 'bull' ? bullColor : bearColor;
          const x1 = this._candleXCenter(b.sourceIdx, plot);
          const x2 = this._candleXCenter(b.endIdx, plot);
          const yHi = priceToY(b.zoneHigh);
          const yLo = priceToY(b.zoneLow);
          const top = Math.min(yHi, yLo);
          const bot = Math.max(yHi, yLo);
          const left = Math.min(x1, x2);
          const width = Math.max(1, Math.abs(x2 - x1));
          const height = Math.max(1, bot - top);
          ctx.save();
          const fillA = b.mitigated ? 0.05 : 0.15;
          const strokeA = b.mitigated ? 0.35 : 0.6;
          ctx.fillStyle = _hexToRgba(color, fillA);
          ctx.fillRect(left, top, width, height);
          ctx.strokeStyle = _hexToRgba(color, strokeA);
          ctx.lineWidth = 1;
          ctx.strokeRect(left + 0.5, top + 0.5, width - 1, height - 1);
          if (width > 50 && height >= 14) {
            ctx.font = '700 10px Geist, sans-serif';
            ctx.textAlign = 'right';
            ctx.textBaseline = 'middle';
            ctx.fillStyle = _hexToRgba(color, 0.9);
            ctx.fillText('OB', left + width - 4, top + height / 2);
          }
          ctx.restore();
        }
      }

      // Liquidity Sweep — triangle marker at the sweeping candle pointing
      // AT the swept pivot. Optional dashed line traces back to the pivot.
      // Bullish (low pivot swept) → triangle below candle low pointing down;
      // bearish (high pivot swept) → triangle above candle high pointing up.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'liqsweep') continue;
        const { sweeps } = this._computeLiqSweep(ind);
        if (!sweeps || sweeps.length === 0) continue;
        const p = (ind.params || {});
        const maxMarkers = Math.max(1, (+p.maxMarkers || 20) | 0);
        const showLine = (+p.showSweepLine === 0) ? false : true;
        const bullColor = ind.color || '#22C55E';
        const bearColor = '#EF4444';
        const visible = sweeps.slice(-maxMarkers);
        for (const sw of visible) {
          const color = sw.kind === 'bull' ? bullColor : bearColor;
          const cx = this._candleXCenter(sw.i, plot);
          const evC = this.candles[sw.i];
          const lowY = priceToY(evC.l);
          const highY = priceToY(evC.h);
          ctx.save();
          if (showLine) {
            const px = this._candleXCenter(sw.pivotIdx, plot);
            const py = priceToY(sw.level);
            ctx.strokeStyle = _hexToRgba(color, 0.55);
            ctx.lineWidth = 1;
            ctx.setLineDash([3, 3]);
            ctx.beginPath();
            ctx.moveTo(px, py);
            ctx.lineTo(cx, py);
            ctx.stroke();
            ctx.setLineDash([]);
          }
          const size = 5;
          ctx.fillStyle = color;
          ctx.beginPath();
          if (sw.kind === 'bull') {
            const ty = lowY + 8;
            ctx.moveTo(cx, ty + size * 1.5);
            ctx.lineTo(cx - size, ty);
            ctx.lineTo(cx + size, ty);
          } else {
            const ty = highY - 8;
            ctx.moveTo(cx, ty - size * 1.5);
            ctx.lineTo(cx - size, ty);
            ctx.lineTo(cx + size, ty);
          }
          ctx.closePath();
          ctx.fill();
          ctx.restore();
        }
      }

      // MSS / BOS / CHoCH — small text label at the break candle plus an
      // optional dashed level line from the broken pivot. MSS additionally
      // renders a filled triangle marker (high-conviction). Colour reflects
      // the break direction (green for bullish, red for bearish) which
      // matches the new prevailing trend.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'mss') continue;
        const { events } = this._computeMss(ind);
        if (!events || events.length === 0) continue;
        const p = (ind.params || {});
        const maxLabels = Math.max(1, (+p.maxLabels || 15) | 0);
        const showLine = (+p.showBreakLine === 0) ? false : true;
        const bullColor = ind.color || '#22C55E';
        const bearColor = '#EF4444';
        const visible = events.slice(-maxLabels);
        for (const ev of visible) {
          const color = ev.kind === 'bull' ? bullColor : bearColor;
          const cx = this._candleXCenter(ev.i, plot);
          const evC = this.candles[ev.i];
          const lowY = priceToY(evC.l);
          const highY = priceToY(evC.h);
          ctx.save();
          if (showLine) {
            const px = this._candleXCenter(ev.pivotIdx, plot);
            const py = priceToY(ev.level);
            ctx.strokeStyle = _hexToRgba(color, 0.6);
            ctx.lineWidth = 1;
            ctx.setLineDash([4, 3]);
            ctx.beginPath();
            ctx.moveTo(px, py);
            ctx.lineTo(cx, py);
            ctx.stroke();
            ctx.setLineDash([]);
          }
          const isMss = ev.label === 'MSS';
          const isBull = ev.kind === 'bull';
          ctx.font = (isMss ? '700 ' : '600 ') + '10px Geist, sans-serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = isBull ? 'bottom' : 'top';
          ctx.fillStyle = color;
          const textY = isBull ? highY - 14 : lowY + 14;
          ctx.fillText(ev.label, cx, textY);
          if (isMss) {
            const size = 4;
            const ty = isBull ? highY - 4 : lowY + 4;
            ctx.beginPath();
            if (isBull) {
              ctx.moveTo(cx, ty);
              ctx.lineTo(cx - size, ty + size * 1.4);
              ctx.lineTo(cx + size, ty + size * 1.4);
            } else {
              ctx.moveTo(cx, ty);
              ctx.lineTo(cx - size, ty - size * 1.4);
              ctx.lineTo(cx + size, ty - size * 1.4);
            }
            ctx.closePath();
            ctx.fill();
          }
          ctx.restore();
        }
      }

      // Phase 29 — WMA / HMA: single-line overlays like SMA/EMA.
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'wma' && ind.kind !== 'hma') continue;
        const values = ind.kind === 'wma'
            ? this._computeWMA(ind.period)
            : this._computeHMA(ind.period);
        ctx.strokeStyle = ind.color || '#3B82F6';
        ctx.lineWidth = (ind.thickness && ind.thickness > 1) ? ind.thickness : 1.5;
        ctx.beginPath();
        let started = false;
        for (let i = 0; i < visible.length; i++) {
          const absIdx = firstAbs + i;
          const v = values[absIdx];
          if (v == null) continue;
          const x = this._candleXCenter(absIdx, plot);
          const y = priceToY(v);
          if (!started) { ctx.moveTo(x, y); started = true; }
          else ctx.lineTo(x, y);
        }
        ctx.stroke();
        this._drawIndicatorAxisChip(
            plot, priceToY, values[firstAbs + visible.length - 1],
            ind.color || '#3B82F6');
      }

      // Phase 29 — Keltner / Donchian: 3-line channels (mid + upper + lower).
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'keltner' && ind.kind !== 'donchian') continue;
        const bands = ind.kind === 'keltner'
            ? this._computeKeltner(ind)
            : this._computeDonchian(ind);
        const col = ind.color || '#06B6D4';
        const drawSeries = (vals, w) => {
          ctx.strokeStyle = col;
          ctx.lineWidth = w;
          ctx.beginPath();
          let started = false;
          for (let i = 0; i < visible.length; i++) {
            const absIdx = firstAbs + i;
            const v = vals[absIdx];
            if (v == null) continue;
            const x = this._candleXCenter(absIdx, plot);
            const y = priceToY(v);
            if (!started) { ctx.moveTo(x, y); started = true; }
            else ctx.lineTo(x, y);
          }
          ctx.stroke();
        };
        drawSeries(bands.upper, 1);
        drawSeries(bands.mid, 1.5);
        drawSeries(bands.lower, 1);
        const last = firstAbs + visible.length - 1;
        this._drawIndicatorAxisChip(plot, priceToY, bands.upper[last], col);
        this._drawIndicatorAxisChip(plot, priceToY, bands.mid[last], col);
        this._drawIndicatorAxisChip(plot, priceToY, bands.lower[last], col);
      }

      // Phase 29 — SuperTrend: solid line in the current trend colour, flips
      // green↔red on the close cross (like Volatility Stop but solid).
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'supertrend') continue;
        const st = this._computeSuperTrend(ind);
        ctx.save();
        ctx.lineWidth = (ind.thickness && ind.thickness > 1) ? ind.thickness : 2;
        let prevDir = null;
        let started = false;
        ctx.beginPath();
        for (let i = 0; i < st.st.length; i++) {
          const v = st.st[i];
          const d = st.dir[i];
          if (v == null || !isFinite(v)) { started = false; prevDir = d; continue; }
          if (d !== prevDir && started) {
            ctx.stroke();
            ctx.beginPath();
            started = false;
          }
          ctx.strokeStyle = d === 1 ? '#22C55E' : '#EF4444';
          const x = this._candleXCenter(i, plot);
          const y = priceToY(v);
          if (!started) { ctx.moveTo(x, y); started = true; }
          else ctx.lineTo(x, y);
          prevDir = d;
        }
        ctx.stroke();
        ctx.restore();
      }

      // VWMA: single-line volume-weighted MA overlay (like SMA/EMA).
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'vwma') continue;
        const values = this._computeVWMA(ind.period || 20);
        ctx.strokeStyle = ind.color || '#F59E0B';
        ctx.lineWidth = (ind.thickness && ind.thickness > 1) ? ind.thickness : 1.5;
        ctx.beginPath();
        let started = false;
        for (let i = 0; i < visible.length; i++) {
          const absIdx = firstAbs + i;
          const v = values[absIdx];
          if (v == null) continue;
          const x = this._candleXCenter(absIdx, plot);
          const y = priceToY(v);
          if (!started) { ctx.moveTo(x, y); started = true; }
          else ctx.lineTo(x, y);
        }
        ctx.stroke();
        this._drawIndicatorAxisChip(
            plot, priceToY, values[firstAbs + visible.length - 1],
            ind.color || '#F59E0B');
      }

      // Parabolic SAR: one trend-coloured dot per bar (green = SAR below
      // price / uptrend, red = SAR above price / downtrend).
      for (const ind of this._indicators) {
        if (ind.hidden) continue;
        if (ind.kind !== 'psar') continue;
        const ps = this._computePSAR(ind);
        const sar = ps.sar, dir = ps.dir;
        for (let i = 0; i < visible.length; i++) {
          const absIdx = firstAbs + i;
          const v = sar[absIdx];
          if (v == null || !isFinite(v)) continue;
          ctx.fillStyle = dir[absIdx] === 1 ? '#22C55E' : '#EF4444';
          ctx.beginPath();
          ctx.arc(this._candleXCenter(absIdx, plot), priceToY(v), 1.6, 0, Math.PI * 2);
          ctx.fill();
        }
      }

      ctx.restore();
    } finally {
      // Always restore the real bar series — even if an exception is thrown
      // mid-loop. JS is single-threaded, but an uncaught error here would
      // otherwise leave this.candles pointing at the brick-derived pseudo-array
      // for every subsequent draw frame.
      this.candles = _savedCandles;
    }
  }

  // Scan-explanation overlays. Renders three things on top of the main
  // candle pane:
  //   1. Yellow matched-bar shading — contiguous runs of `matched[i]===true`
  //      become a single translucent rect spanning the price-panel y-range.
  //   2. Float-kind server indicator lines (e.g. SMA, EMA, Senkou A/B). One
  //      stroke per column, color from `column.color_hint` when supplied.
  //      Sub-panel-flagged indicators (RSI/MACD/etc.) are skipped for v1
  //      and surface only in the predicate panel — the main pane can't
  //      display values on the wrong price scale.
  //   3. Boolean-kind markers — small dots above the high of each bar where
  //      the indicator series is truthy AND the predicate matched, so e.g.
  //      "Hammer formed" puts a marker exactly at the hammer bar.
  //   4. Enum-kind background bands deferred — the predicate panel surfaces
  //      the regime label, which is enough signal for v1.
  _drawExplainOverlays(plot, lo, hi, priceToY) {
    if (!this._explainPayload || this.candles.length === 0) return;
    const visible = this._visibleCandles();
    if (visible.length === 0) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;

    const ctx = this.ctx;
    ctx.save();

    const matched = this._explainPayload.matched || [];
    const indicators = this._explainPayload.indicators || {};
    const columns = this._explainPayload.columns || [];

    // (1) Matched-bar shading. Walk the visible range; emit one rect per
    // contiguous run of trues. Half a cell of padding on either side so
    // adjacent matches visually merge instead of looking like a striped
    // pattern. Drawn on top of candles with 12% alpha so candles stay
    // legible — TradingView/StockEdge use a similar amber tint.
    {
      const cellW = this.view.cellW;
      const half = cellW / 2;
      ctx.fillStyle = 'rgba(245,158,11,0.16)';
      let runStartIdx = -1;
      for (let i = 0; i <= visible.length; i++) {
        const absIdx = firstAbs + i;
        const isMatched = i < visible.length && matched[absIdx] === true;
        if (isMatched && runStartIdx < 0) {
          runStartIdx = absIdx;
        } else if (!isMatched && runStartIdx >= 0) {
          const xStart = this._candleXCenter(runStartIdx, plot) - half;
          const xEnd = this._candleXCenter(absIdx - 1, plot) + half;
          ctx.fillRect(xStart, plot.top, xEnd - xStart, plot.bottom - plot.top);
          runStartIdx = -1;
        }
      }
    }

    // (2) Float-kind server indicator lines on the main pane. Skip any
    // column that setExplanationData reclassified as a sub-pane (either
    // because the server said so or because its values are off the
    // price scale — see the `subKeys` set built there).
    const defaultPalette = [
      '#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#06B6D4',
    ];
    const subKeys = (this._explainPayload && this._explainPayload.subKeys)
        ? this._explainPayload.subKeys
        : new Set();
    let paletteIdx = 0;
    for (const col of columns) {
      if (!col || col.kind !== 'float') continue;
      if (subKeys.has(col.key)) continue;
      const series = indicators[col.key];
      if (!Array.isArray(series)) continue;
      const color = (typeof col.color_hint === 'string' && col.color_hint)
          ? col.color_hint
          : defaultPalette[paletteIdx++ % defaultPalette.length];
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      let started = false;
      for (let i = 0; i < visible.length; i++) {
        const absIdx = firstAbs + i;
        const raw = series[absIdx];
        const v = (typeof raw === 'number' && isFinite(raw)) ? raw : null;
        if (v == null) { started = false; continue; }
        const x = this._candleXCenter(absIdx, plot);
        const y = priceToY(v);
        if (!started) { ctx.moveTo(x, y); started = true; }
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
    }

    // (2.5) Enum-kind regime ribbon — e.g. SuperTrend direction
    // (1=Up green, -1=Down red). Rendered as a thin strip at the bottom
    // of the main pane (line-style indicator) rather than a full-pane
    // background wash, so candles stay the dominant signal. Each
    // contiguous run of the same enum value becomes a solid colored
    // segment in the strip.
    const enumColors = (value) => {
      if (value === 1 || value === 1.0) return '#16A34A';   // green-600 (up)
      if (value === -1 || value === -1.0) return '#DC2626';   // red-600 (down)
      if (value === 0 || value === 0.0) return '#94A3B8';     // slate-400 (neutral)
      return null;
    };
    const cellW = this.view.cellW;
    const halfCell = cellW / 2;
    // Stack ribbons just above the bottom gutter — one row per enum
    // column, 6px tall + 2px gap. Newest at the very bottom so volume
    // bars (which overlay the price pane's bottom region) stay visible.
    let ribbonRowY = plot.bottom - 6;
    for (const col of columns) {
      if (!col || col.kind !== 'enum') continue;
      const series = indicators[col.key];
      if (!Array.isArray(series)) continue;
      let runStartIdx = -1;
      let runValue = null;
      const flushRun = (endAbsIdxExclusive) => {
        if (runStartIdx < 0) return;
        const fill = enumColors(runValue);
        if (fill) {
          const xStart = this._candleXCenter(runStartIdx, plot) - halfCell;
          const xEnd = this._candleXCenter(endAbsIdxExclusive - 1, plot) + halfCell;
          ctx.fillStyle = fill;
          ctx.fillRect(xStart, ribbonRowY, xEnd - xStart, 6);
        }
        runStartIdx = -1;
        runValue = null;
      };
      for (let i = 0; i <= visible.length; i++) {
        const absIdx = firstAbs + i;
        const v = (i < visible.length) ? series[absIdx] : null;
        if (v == null || !isFinite(v)) {
          flushRun(absIdx);
          continue;
        }
        if (runStartIdx < 0) {
          runStartIdx = absIdx;
          runValue = v;
        } else if (v !== runValue) {
          flushRun(absIdx);
          runStartIdx = absIdx;
          runValue = v;
        }
      }
      // Tiny label to the left of the ribbon so the user knows what
      // the colors mean. Drawn at low opacity so it doesn't compete.
      ctx.save();
      ctx.font = '600 9px Geist, sans-serif';
      ctx.fillStyle = this._withAlpha(this.palette.axisText, 0.85);
      ctx.textBaseline = 'middle';
      ctx.textAlign = 'left';
      ctx.fillText(col.label || col.key || '', plot.left + 4, ribbonRowY + 3);
      ctx.restore();
      ribbonRowY -= 8; // next ribbon stacks above this one (6 + 2 gap)
    }

    // (3) Boolean-kind markers — small dot above the bar high.
    for (const col of columns) {
      if (!col || col.kind !== 'boolean') continue;
      const series = indicators[col.key];
      if (!Array.isArray(series)) continue;
      const color = (typeof col.color_hint === 'string' && col.color_hint)
          ? col.color_hint
          : '#F59E0B';
      ctx.fillStyle = color;
      for (let i = 0; i < visible.length; i++) {
        const absIdx = firstAbs + i;
        const raw = series[absIdx];
        const isTrue = raw === true || raw === 1 || raw === 1.0;
        if (!isTrue) continue;
        const c = visible[i];
        const x = this._candleXCenter(absIdx, plot);
        const y = priceToY(c.h) - 6;
        ctx.beginPath();
        ctx.arc(x, y, 3, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    ctx.restore();
  }

  // Draws one explain-mode sub-pane (RSI / MACD-line / CCI / ADX etc.).
  // Values come from `this._explainPayload.indicators[sp.explainKey]` —
  // pre-computed by the server, NOT from a local `_computeXxx`. Reference
  // lines are added for the common bounded oscillators (RSI: 30/70,
  // unbounded: zero line if range crosses).
  _drawExplainSubPane(sp) {
    const ctx = this.ctx;
    if (this.candles.length === 0) return;
    if (!this._explainPayload || !this._explainPayload.indicators) return;
    const series = this._explainPayload.indicators[sp.explainKey];
    if (!Array.isArray(series)) return;
    const range = this._subPaneEffectiveRange(sp);
    if (!range) return;
    const [yMin, yMax] = range;
    if (yMax === yMin) return;
    const yFor = (v) => sp.top + (yMax - v) * sp.height / (yMax - yMin);

    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(sp.left, sp.top, sp.width, sp.height);

    // Reference lines — overbought/oversold for RSI/MFI/Stoch (30/70),
    // bull/bear for ADX (25), zero line when range crosses zero (CCI etc).
    const key = (sp.explainKey || '').toLowerCase();
    const refs = [];
    if (key.startsWith('rsi') || key.startsWith('mfi') ||
        key.startsWith('stoch_')) {
      refs.push(30, 70);
    } else if (key.startsWith('adx')) {
      refs.push(25);
    }
    if (yMin < 0 && yMax > 0) refs.push(0);
    ctx.strokeStyle = this.palette.axisText;
    ctx.lineWidth = 1;
    ctx.setLineDash([3, 3]);
    for (const lvl of refs) {
      if (lvl < yMin || lvl > yMax) continue;
      const y = yFor(lvl);
      ctx.beginPath();
      ctx.moveTo(sp.left, y);
      ctx.lineTo(sp.right, y);
      ctx.stroke();
    }
    ctx.setLineDash([]);

    // Main line trace.
    const visible = this._visibleCandles();
    if (visible.length === 0) { ctx.restore(); return; }
    const firstAbs = this.candles.indexOf(visible[0]);
    ctx.strokeStyle = sp.color || '#F59E0B';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const raw = series[absIdx];
      const v = (typeof raw === 'number' && isFinite(raw)) ? raw : null;
      if (v == null) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(v);
      if (!started) { ctx.moveTo(x, y); started = true; }
      else ctx.lineTo(x, y);
    }
    ctx.stroke();

    // Top-left label so the user sees what the panel is showing.
    ctx.font = '600 10px Geist, sans-serif';
    ctx.fillStyle = sp.color || '#F59E0B';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(sp.label || sp.explainKey || 'Indicator',
        sp.left + 4, sp.top + 8);
    ctx.restore();
  }

  _drawSubPanes(subPlots) {
    if (subPlots.length === 0) { this._lastSubPlots = []; return; }
    // Cache for hit-tests (mousedown / wheel / dblclick).
    this._lastSubPlots = subPlots;
    // Phase 16 F2 (Fix C) — on Renko, sub-pane renderers must see brick-derived
    // pseudo-candles in this.candles so that _visibleCandles(), _computeRSI(),
    // _computeMACD(), etc. all operate on brick prices rather than raw bar data.
    // Same swap pattern as _drawIndicators, wrapped in try/finally so an
    // exception during rendering never leaks the swapped array to later frames.
    const seriesBars = this.candleStyle === 'renko'
        ? this._renkoBricks.map((b) => ({
            c: b.closePrice, h: b.closePrice, l: b.closePrice,
            o: b.openPrice, ts: b.sourceBarTime, v: 0,
          }))
        : (this._isRebinnedStyle(this.candleStyle)
            && this._rebinnedStyle === this.candleStyle
            && this._rebinned.length > 0)
          ? this._rebinned   // Phase 26 — see _drawIndicators note above.
          : this.candles;
    const _savedCandles = this.candles;
    this.candles = seriesBars;
    try {
      for (const sp of subPlots) {
        // Resolve manual Y view (if user has panned/zoomed this sub-pane) and
        // stash on sp so per-kind drawers can pick it up instead of their
        // own auto-fit math.
        const view = this._subPaneView[sp.id];
        if (view && view.center != null && view.perPx != null) {
          const half = (sp.height / 2) * view.perPx;
          sp.viewMin = view.center - half;
          sp.viewMax = view.center + half;
        } else {
          sp.viewMin = null;
          sp.viewMax = null;
        }
        // Clip the renderer output to the sub-pane's vertical band so a
        // user-panned view doesn't bleed the indicator line into the
        // candle pane above or another sub-pane below. Width matches the
        // candle plot exactly (sp.left..sp.right) — the right gutter where
        // axis labels live is OUTSIDE this clip so they remain visible.
        this.ctx.save();
        this.ctx.beginPath();
        this.ctx.rect(sp.left, sp.top, sp.width, sp.height);
        this.ctx.clip();
        switch (sp.kind) {
          case 'rsi':      this._drawRsiInPane(sp); break;
          case 'macd':     this._drawMacdInPane(sp); break;
          case 'stoch':    this._drawStochInPane(sp); break;
          case 'atr':      this._drawAtrInPane(sp); break;
          case 'stochrsi': this._drawStochRsiInPane(sp); break;
          case 'squeeze':  this._drawSqueezeInPane(sp); break;
          case 'efi':      this._drawEfiInPane(sp); break;
          case 'wt':       this._drawWaveTrendInPane(sp); break;
          case 'crsi':     this._drawConnorsRSIInPane(sp); break;
          case 'ao':       this._drawAoInPane(sp); break;
          case 'mfi':      this._drawMfiInPane(sp); break;
          case 'obv':      this._drawObvInPane(sp); break;
          case 'cmf':      this._drawCmfInPane(sp); break;
          case 'wr':       this._drawWilliamsRInPane(sp); break;
          case 'cci':      this._drawCciInPane(sp); break;
          case 'roc':      this._drawRocInPane(sp); break;
          case 'cvd':      this._drawCvdInPane(sp); break;
          case 'adx':      this._drawAdxInPane(sp); break;
          case 'trix':     this._drawTrixInPane(sp); break;
          case 'vortex':   this._drawVortexInPane(sp); break;
          case 'uo':       this._drawUoInPane(sp); break;
          case 'dpo':      this._drawDpoInPane(sp); break;
          case 'pvt':      this._drawPvtInPane(sp); break;
          case 'ad':       this._drawAdInPane(sp); break;
          case 'explain':  this._drawExplainSubPane(sp); break;
        }
        this.ctx.restore();
        // Right-axis labels — bounded oscillators get their static range;
        // unbounded ones (MACD/ATR/AO/OBV/EFI/Squeeze/WaveTrend) compute
        // a window-fit range from their values. Manual view overrides both.
        const range = this._subPaneEffectiveRange(sp);
        if (range) {
          // Latest-value chip ALWAYS visible on the right axis (like the
          // main pane's LTP chip). Drawn first so its Y range is registered
          // in the slot ledger before min/mid/max axis labels paint and
          // pick a non-colliding Y for themselves.
          this._drawSubPaneCurrentValueChip(sp, range[0], range[1]);
          this._drawSubPaneAxis(sp, range[0], range[1]);
          // Hover overlays — vertical crosshair line through the sub-pane
          // and a coloured value chip on the right axis at the hovered
          // candle (in addition to the always-on latest-value chip).
          this._drawSubPaneHoverOverlay(sp, range[0], range[1]);
        }
      }
    } finally {
      this.candles = _savedCandles;
    }
  }

  // Returns the effective [min, max] for a sub-pane — manual override if the
  // user has panned/zoomed it, otherwise the auto-fit range from data.
  _subPaneEffectiveRange(sp) {
    if (sp.viewMin != null && sp.viewMax != null && sp.viewMax > sp.viewMin) {
      return [sp.viewMin, sp.viewMax];
    }
    return this._subPaneRange(sp);
  }

  // Snapshot a sub-pane's current auto-fit range into its manual view state.
  // Called on the first vertical pan/zoom so the gesture starts from the
  // user's current visual baseline instead of snapping to a different
  // default scale.
  _snapshotSubPaneViewToManual(sp) {
    const view = this._subPaneView[sp.id] ||
        (this._subPaneView[sp.id] = { center: null, perPx: null });
    if (view.center != null && view.perPx != null) return;
    const range = this._subPaneRange(sp);
    if (!range || !isFinite(range[0]) || !isFinite(range[1]) ||
        range[1] === range[0]) {
      // Fallback for indicators with no data yet — pick a unit scale around 0.
      view.center = 0;
      view.perPx = 1 / Math.max(1, sp.height);
      return;
    }
    view.center = (range[0] + range[1]) / 2;
    view.perPx = (range[1] - range[0]) / Math.max(1, sp.height);
  }

  // Vertical crosshair line + per-sub-pane right-axis value chip at the
  // hovered candle. Without this, the sub-pane's right axis stays static
  // (just min/mid/max labels) and gives no hover feedback.
  _drawSubPaneHoverOverlay(sp, minVal, maxVal) {
    if (!this.hover.inside || this.hover.x == null) return;
    if (this.candles.length === 0) return;
    const idx = this._candleAtX(this.hover.x);
    if (idx < 0 || idx >= this.candles.length) return;
    const ctx = this.ctx;
    ctx.save();
    // Vertical line — same dashed style as the main crosshair, gated by the
    // same showCrosshairLines toggle.
    if (this.showCrosshairLines) {
      const x = this._candleXCenter(idx, sp);
      ctx.strokeStyle = this.palette.crosshair;
      ctx.lineWidth = 1;
      ctx.setLineDash([4, 4]);
      ctx.beginPath();
      ctx.moveTo(x, sp.top);
      ctx.lineTo(x, sp.bottom);
      ctx.stroke();
      ctx.setLineDash([]);
    }
    // Value at hover candle. Compute per-kind so the chip shows the
    // indicator's actual value (RSI 64.2, MACD 8.5, etc.).
    const v = this._subPaneValueAt(sp, idx);
    if (v == null || !isFinite(v)) { ctx.restore(); return; }
    if (maxVal === minVal) { ctx.restore(); return; }
    // Map v into the sub-pane's Y axis.
    const t = (maxVal - v) / (maxVal - minVal);
    const yClamp = Math.max(sp.top + 8, Math.min(sp.bottom - 8,
        sp.top + t * sp.height));
    // Chip — coloured like the indicator's line/series.
    const text = (Math.abs(v) < 10) ? v.toFixed(2) : v.toFixed(1);
    ctx.font = '700 10px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';
    const tw = Math.min(72, ctx.measureText(text).width + 10);
    ctx.fillStyle = sp.color || this.palette.crosshairChip;
    this._roundedRect(sp.right + 2, yClamp - 8, tw, 16, 3);
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(text, sp.right + 2 + tw / 2, yClamp);
    ctx.restore();
  }

  // Returns the scalar value the sub-pane displays at the given candle
  // index, or null if the kind has no scalar (multi-series like MACD —
  // we use the MACD line for the hover chip, not signal/histogram).
  _subPaneValueAt(sp, idx) {
    const k = sp.kind;
    if (k === 'rsi')      return (this._computeRSI(sp.period) || [])[idx];
    if (k === 'mfi')      return (this._computeMFI(sp.period) || [])[idx];
    if (k === 'cmf')      return (this._computeCMF(sp.period) || [])[idx];
    if (k === 'wr')       return (this._computeWilliamsR(sp.period) || [])[idx];
    if (k === 'cci')      return (this._computeCCI(sp.period || 20) || [])[idx];
    if (k === 'roc')      return (this._computeROC(sp.period || 9) || [])[idx];
    if (k === 'cvd')      return (this._computeCVD() || [])[idx];
    if (k === 'adx')      return ((this._computeADX(sp.period || 14) || {}).adx || [])[idx];
    if (k === 'trix')     return (this._computeTRIX(sp.period || 15) || [])[idx];
    if (k === 'vortex')   return ((this._computeVortex(sp.period || 14) || {}).viPlus || [])[idx];
    if (k === 'uo')       return (this._computeUO() || [])[idx];
    if (k === 'dpo')      return (this._computeDPO(sp.period || 20) || [])[idx];
    if (k === 'pvt')      return (this._computePVT() || [])[idx];
    if (k === 'ad')       return (this._computeAD() || [])[idx];
    if (k === 'atr')      return (this._computeATR(sp.period) || [])[idx];
    if (k === 'ao')       return (this._computeAO() || [])[idx];
    if (k === 'obv')      return (this._computeOBV() || [])[idx];
    if (k === 'efi')      return (this._computeEFI(sp.period || 13) || [])[idx];
    if (k === 'crsi')     return (this._computeConnorsRSI(sp.period || 3) || [])[idx];
    if (k === 'stoch') {
      const v = this._computeStoch(sp);
      return v && v.k ? v.k[idx] : null;
    }
    if (k === 'stochrsi') {
      const v = this._computeStochRsi(sp);
      return v && v.k ? v.k[idx] : null;
    }
    if (k === 'macd') {
      const v = this._computeMACD(sp);
      return v && v.macd ? v.macd[idx] : null;
    }
    if (k === 'wt') {
      const v = this._computeWaveTrend(sp);
      const x = v ? v[idx] : null;
      return (x && x.wt1 != null) ? x.wt1 : null;
    }
    if (k === 'squeeze') {
      const v = this._computeSqueeze(sp);
      const x = v ? v[idx] : null;
      return (x && x.mom != null) ? x.mom : null;
    }
    if (k === 'explain') {
      // Server-supplied series; no local compute. Drives the latest-value
      // chip on the right gutter + the hover-crosshair value chip.
      const series = (this._explainPayload &&
          this._explainPayload.indicators)
          ? this._explainPayload.indicators[sp.explainKey]
          : null;
      if (!Array.isArray(series)) return null;
      const v = series[idx];
      return (typeof v === 'number' && isFinite(v)) ? v : null;
    }
    return null;
  }

  // Returns [min, max] for a sub-pane's value range, or null if we can't
  // compute one. Bounded oscillators: hard-coded. Unbounded: scan the
  // values the indicator just used.
  _subPaneRange(sp) {
    switch (sp.kind) {
      case 'rsi':
      case 'stochrsi':
      case 'stoch':
      case 'mfi':
      case 'crsi':
        return [0, 100];
      case 'wr':
        return [-100, 0];
      case 'cmf':
        return [-1, 1];
      case 'cci': {
        const v = this._computeCCI(sp.period || 20);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        return (isFinite(lo) && isFinite(hi)) ? [Math.min(lo, -100), Math.max(hi, 100)] : null;
      }
      case 'roc': {
        const v = this._computeROC(sp.period || 9);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        if (!isFinite(lo) || !isFinite(hi)) return null;
        const mag = Math.max(Math.abs(lo), Math.abs(hi)) || 1;
        return [-mag, mag];
      }
      case 'cvd': {
        const v = this._computeCVD();
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'adx': {
        const r = this._computeADX(sp.period || 14);
        let hi = 0;
        for (const arr of [r.adx, r.plusDI, r.minusDI]) {
          for (const x of arr) { if (x != null && isFinite(x) && x > hi) hi = x; }
        }
        return [0, Math.max(50, hi)];
      }
      case 'uo':
        return [0, 100];
      case 'trix': {
        const v = this._computeTRIX(sp.period || 15);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'dpo': {
        const v = this._computeDPO(sp.period || 20);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'pvt': {
        const v = this._computePVT();
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'ad': {
        const v = this._computeAD();
        let lo = Infinity, hi = -Infinity;
        for (const x of v) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'vortex': {
        const r = this._computeVortex(sp.period || 14);
        let lo = Infinity, hi = -Infinity;
        for (const arr of [r.viPlus, r.viMinus]) {
          for (const x of arr) { if (x == null || !isFinite(x)) continue; if (x < lo) lo = x; if (x > hi) hi = x; }
        }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'wt':
        return [-100, 100];
      case 'macd': {
        const m = this._computeMACD(sp);
        if (!m) return null;
        let lo = Infinity, hi = -Infinity;
        for (const v of [...m.macd, ...m.signal, ...m.hist]) {
          if (v == null || !isFinite(v)) continue;
          if (v < lo) lo = v;
          if (v > hi) hi = v;
        }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'atr': {
        const v = this._computeATR(sp.period);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) {
          if (x == null || !isFinite(x)) continue;
          if (x < lo) lo = x;
          if (x > hi) hi = x;
        }
        return (isFinite(lo) && isFinite(hi)) ? [Math.min(0, lo), hi] : null;
      }
      case 'ao': {
        const v = this._computeAO();
        let lo = Infinity, hi = -Infinity;
        for (const x of v) {
          if (x == null || !isFinite(x)) continue;
          if (x < lo) lo = x;
          if (x > hi) hi = x;
        }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'obv': {
        const v = this._computeOBV();
        let lo = Infinity, hi = -Infinity;
        for (const x of v) {
          if (x == null || !isFinite(x)) continue;
          if (x < lo) lo = x;
          if (x > hi) hi = x;
        }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'efi': {
        const v = this._computeEFI(sp.period || 13);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) {
          if (x == null || !isFinite(x)) continue;
          if (x < lo) lo = x;
          if (x > hi) hi = x;
        }
        return (isFinite(lo) && isFinite(hi)) ? [lo, hi] : null;
      }
      case 'squeeze': {
        const v = this._computeSqueeze(sp);
        let lo = Infinity, hi = -Infinity;
        for (const x of v) {
          if (!x || x.mom == null || !isFinite(x.mom)) continue;
          if (x.mom < lo) lo = x.mom;
          if (x.mom > hi) hi = x.mom;
        }
        if (!isFinite(lo) || !isFinite(hi)) return null;
        // Squeeze histogram pivots around 0 — make the axis symmetric so
        // positive and negative bars are visually balanced.
        const mag = Math.max(Math.abs(lo), Math.abs(hi));
        return [-mag, mag];
      }
      case 'explain': {
        // Bounded oscillators that the explain view commonly drives —
        // pin to canonical ranges so the panel scale matches what users
        // see on other platforms (TradingView, Sahi). Anything else
        // auto-fits to the visible data so the line uses the full panel.
        const key = (sp.explainKey || '').toString().toLowerCase();
        if (key.startsWith('rsi') || key.startsWith('stoch_') ||
            key.startsWith('mfi') || key.startsWith('cci') ||
            key.startsWith('roc') || key.startsWith('momentum_score') ||
            key.startsWith('adx')) {
          // 0..100 covers RSI/MFI/Stoch/ADX. CCI/ROC frequently exceed
          // 100 — fall through to auto-fit for those.
          if (key.startsWith('rsi') || key.startsWith('stoch_') ||
              key.startsWith('mfi') || key.startsWith('adx')) {
            return [0, 100];
          }
        }
        const series = (this._explainPayload &&
            this._explainPayload.indicators)
            ? this._explainPayload.indicators[sp.explainKey]
            : null;
        if (!Array.isArray(series)) return null;
        let lo = Infinity, hi = -Infinity;
        for (const v of series) {
          if (v == null || !isFinite(v)) continue;
          if (v < lo) lo = v;
          if (v > hi) hi = v;
        }
        if (!isFinite(lo) || !isFinite(hi) || lo === hi) return null;
        const pad = (hi - lo) * 0.10;
        return [lo - pad, hi + pad];
      }
      default:
        return null;
    }
  }

  // Sahi-style colored value chip rendered on the right price axis, in the
  // indicator's own colour. Same shape as the LTP chip — gives the user a
  // current-value readout without crosshair-hovering. Anti-collision: chip
  // is shifted up/down in 18px increments until it doesn't overlap any
  // previously-placed chip (LTP, countdown, other indicators) in the
  // `_axisChipSlots` registry. Without this, multiple MAs at close prices
  // (SMA + EMA = ~₹2 apart on a 5m chart) stack on top of each other.
  _drawIndicatorAxisChip(plot, priceToY, value, color) {
    if (value == null || !isFinite(value)) return;
    const ctx = this.ctx;
    const y = priceToY(value);
    if (y < plot.top - 6 || y > plot.bottom + 6) return;
    const chipH = 16;
    const slot = this._allocAxisChipSlot(y, chipH, plot.top + 8, plot.bottom - 8);
    if (slot == null) return;  // ran out of free space; drop silently
    const cy = slot;
    const text = value.toFixed(this._priceDecimals());
    ctx.save();
    ctx.font = '700 10px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';
    const tw = Math.min(72, ctx.measureText(text).width + 10);
    ctx.fillStyle = color;
    this._roundedRect(plot.right + 2, cy - 8, tw, chipH, 3);
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(text, plot.right + 2 + tw / 2, cy);
    ctx.restore();
  }

  // Reserves a non-overlapping Y slot on the right axis for a chip of the
  // given height centred near `wantY`. Returns the centre Y to render at,
  // or null if no slot fits within [topClamp, bottomClamp]. Tracks state in
  // `this._axisChipSlots` which `draw()` resets each frame.
  _allocAxisChipSlot(wantY, chipH, topClamp, bottomClamp) {
    if (!this._axisChipSlots) this._axisChipSlots = [];
    const half = chipH / 2;
    // Try increasing-distance offsets: 0, +18, -18, +36, -36, …
    for (let step = 0; step <= 8; step++) {
      for (const dir of (step === 0 ? [1] : [1, -1])) {
        const tryY = wantY + dir * step * (chipH + 2);
        if (tryY - half < topClamp || tryY + half > bottomClamp) continue;
        const top = tryY - half, bottom = tryY + half;
        let clash = false;
        for (const s of this._axisChipSlots) {
          if (!(bottom <= s.top || top >= s.bottom)) { clash = true; break; }
        }
        if (!clash) {
          this._axisChipSlots.push({ top, bottom });
          return tryY;
        }
      }
    }
    return null;
  }

  // Registers an externally-painted chip (LTP, countdown) into the slot
  // ledger so subsequent indicator chips know to dodge it.
  _registerAxisChipSlot(centreY, chipH) {
    if (!this._axisChipSlots) this._axisChipSlots = [];
    const half = chipH / 2;
    this._axisChipSlots.push({ top: centreY - half, bottom: centreY + half });
  }

  // Always-on right-axis chip showing the LATEST value of the sub-pane's
  // primary series. Colour-matched to the indicator. Painted before the
  // axis labels so its Y slot is reserved in `_axisChipSlots` and the
  // labels dodge it instead of overlapping.
  _drawSubPaneCurrentValueChip(sp, minVal, maxVal) {
    if (!isFinite(minVal) || !isFinite(maxVal) || maxVal === minVal) return;
    if (this.candles.length === 0) return;
    const lastIdx = this.candles.length - 1;
    const v = this._subPaneValueAt(sp, lastIdx);
    if (v == null || !isFinite(v)) return;
    const ctx = this.ctx;
    const t = (maxVal - v) / (maxVal - minVal);
    const wantY = sp.top + t * sp.height;
    const cy = this._allocAxisChipSlot(wantY, 16, sp.top + 8, sp.bottom - 8);
    if (cy == null) return;
    const text = (Math.abs(v) < 10) ? v.toFixed(2) : v.toFixed(1);
    ctx.save();
    ctx.font = '700 10px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';
    const tw = Math.min(72, ctx.measureText(text).width + 10);
    ctx.fillStyle = sp.color || this.palette.crosshairChip;
    this._roundedRect(sp.right + 2, cy - 8, tw, 16, 3);
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(text, sp.right + 2 + tw / 2, cy);
    ctx.restore();
  }

  // Generic right-axis labels for sub-panes. Draws max / mid / min labels in
  // the 60px gutter right of the sub-pane, matching the main price-axis
  // gutter so the eye lines up vertically. Bounded indicators pass an
  // explicit [min, max]; unbounded ones (MACD/ATR/AO/OBV/EFI/Squeeze/WT)
  // compute their own range from the visible values and pass that in.
  // Labels are skipped if they'd collide with a chip already in the
  // axis-slot ledger (latest-value chip, hover chip).
  _drawSubPaneAxis(sp, minVal, maxVal) {
    if (!isFinite(minVal) || !isFinite(maxVal) || maxVal === minVal) return;
    const ctx = this.ctx;
    ctx.save();
    ctx.font = '600 9px Geist, sans-serif';
    ctx.fillStyle = this.palette.axisText;
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    const labelX = sp.right + 4;
    const span = Math.abs(maxVal - minVal);
    let decimals = 0;
    if (span < 1) decimals = 4;
    else if (span < 10) decimals = 2;
    else if (span < 100) decimals = 1;
    const mid = (minVal + maxVal) / 2;
    const labels = [
      { val: maxVal, y: sp.top + 6 },
      { val: mid,    y: sp.top + sp.height / 2 },
      { val: minVal, y: sp.bottom - 6 },
    ];
    const slots = this._axisChipSlots || [];
    for (const lb of labels) {
      let covered = false;
      for (const s of slots) {
        if (lb.y >= s.top - 2 && lb.y <= s.bottom + 2) { covered = true; break; }
      }
      if (covered) continue;
      ctx.fillText(lb.val.toFixed(decimals), labelX, lb.y);
    }
    ctx.restore();
  }

  _drawRsiInPane(sp) {
    const ctx = this.ctx;
    if (this.candles.length === 0) return;
    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(sp.left, sp.top, sp.width, sp.height);
    const yMin = sp.viewMin != null ? sp.viewMin : 0;
    const yMax = sp.viewMax != null ? sp.viewMax : 100;
    const yFor = (v) => sp.top + (yMax - v) * sp.height / (yMax - yMin);
    ctx.strokeStyle = this.palette.axisText;
    ctx.lineWidth = 1;
    ctx.setLineDash([3, 3]);
    for (const lvl of [30, 70]) {
      const y = yFor(lvl);
      ctx.beginPath();
      ctx.moveTo(sp.left, y);
      ctx.lineTo(sp.right, y);
      ctx.stroke();
    }
    ctx.setLineDash([]);
    ctx.strokeStyle = this.palette.gridSoft;
    const ymid = yFor(50);
    ctx.beginPath();
    ctx.moveTo(sp.left, ymid);
    ctx.lineTo(sp.right, ymid);
    ctx.stroke();
    const visible = this._visibleCandles();
    if (visible.length === 0) { ctx.restore(); return; }
    const firstAbs = this.candles.indexOf(visible[0]);
    const values = this._computeRSI(sp.period);
    ctx.strokeStyle = sp.color || '#8B5CF6';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null) continue;
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(v);
      if (!started) { ctx.moveTo(x, y); started = true; }
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
    ctx.font = '600 10px Geist, sans-serif';
    ctx.fillStyle = sp.color || '#8B5CF6';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(`RSI ${sp.period}`, sp.left + 4, sp.top + 8);
    ctx.restore();
  }

  _drawMacdInPane(sp) {
    const ctx = this.ctx;
    if (this.candles.length === 0) return;
    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(sp.left, sp.top, sp.width, sp.height);
    const macdResult = this._computeMACD(sp);
    const { macd, signal, hist } = macdResult;
    const pp = macdResult.periods || { fast: 12, slow: 26, signal: 9 };
    const visible = this._visibleCandles();
    if (visible.length === 0) { ctx.restore(); return; }
    const firstAbs = this.candles.indexOf(visible[0]);
    // Range from visible macd / signal / hist
    let lo = Infinity, hi = -Infinity;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      for (const arr of [macd, signal, hist]) {
        const v = arr[absIdx];
        if (v == null) continue;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    }
    if (!Number.isFinite(lo) || !Number.isFinite(hi)) { ctx.restore(); return; }
    const pad = (hi - lo) * 0.1 || 1;
    lo -= pad; hi += pad;
    if (sp.viewMin != null && sp.viewMax != null) { lo = sp.viewMin; hi = sp.viewMax; }
    const yFor = (v) => sp.top + (hi - v) * sp.height / (hi - lo);

    // Zero line dashed.
    if (lo < 0 && hi > 0) {
      ctx.strokeStyle = this.palette.axisText;
      ctx.lineWidth = 1;
      ctx.setLineDash([3, 3]);
      ctx.beginPath();
      const y0 = yFor(0);
      ctx.moveTo(sp.left, y0);
      ctx.lineTo(sp.right, y0);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // Histogram bars.
    const barW = Math.max(1, this.view.cellW - 2);
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = hist[absIdx];
      if (v == null) continue;
      const x = this._candleXCenter(absIdx, sp);
      const y0 = yFor(0);
      const yv = yFor(v);
      ctx.fillStyle = v >= 0
          ? 'rgba(16,185,129,0.6)' : 'rgba(239,68,68,0.6)';
      ctx.fillRect(x - barW / 2, Math.min(y0, yv),
          barW, Math.abs(yv - y0));
    }

    // MACD line + signal line.
    const drawLine = (arr, color, lw) => {
      ctx.strokeStyle = color;
      ctx.lineWidth = lw;
      ctx.beginPath();
      let started = false;
      for (let i = 0; i < visible.length; i++) {
        const absIdx = firstAbs + i;
        const v = arr[absIdx];
        if (v == null) continue;
        const x = this._candleXCenter(absIdx, sp);
        const y = yFor(v);
        if (!started) { ctx.moveTo(x, y); started = true; }
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
    };
    drawLine(macd, sp.color || '#3B82F6', 1.4);
    drawLine(signal, '#F59E0B', 1.4);

    ctx.font = '600 10px Geist, sans-serif';
    ctx.fillStyle = sp.color || '#3B82F6';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(`MACD ${pp.fast}/${pp.slow}/${pp.signal}`, sp.left + 4, sp.top + 8);
    ctx.restore();
  }

  _drawStochInPane(sp) {
    const ctx = this.ctx;
    if (this.candles.length === 0) return;
    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(sp.left, sp.top, sp.width, sp.height);
    const yMin = sp.viewMin != null ? sp.viewMin : 0;
    const yMax = sp.viewMax != null ? sp.viewMax : 100;
    const yFor = (v) => sp.top + (yMax - v) * sp.height / (yMax - yMin);
    ctx.strokeStyle = this.palette.axisText;
    ctx.lineWidth = 1;
    ctx.setLineDash([3, 3]);
    for (const lvl of [20, 80]) {
      const y = yFor(lvl);
      ctx.beginPath();
      ctx.moveTo(sp.left, y);
      ctx.lineTo(sp.right, y);
      ctx.stroke();
    }
    ctx.setLineDash([]);
    const { k, d } = this._computeStoch(sp);
    const visible = this._visibleCandles();
    if (visible.length === 0) { ctx.restore(); return; }
    const firstAbs = this.candles.indexOf(visible[0]);
    const drawLine = (arr, color) => {
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.4;
      ctx.beginPath();
      let started = false;
      for (let i = 0; i < visible.length; i++) {
        const absIdx = firstAbs + i;
        const v = arr[absIdx];
        if (v == null) continue;
        const x = this._candleXCenter(absIdx, sp);
        const y = yFor(v);
        if (!started) { ctx.moveTo(x, y); started = true; }
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
    };
    drawLine(k, sp.color || '#8B5CF6');
    drawLine(d, '#F59E0B');
    ctx.font = '600 10px Geist, sans-serif';
    ctx.fillStyle = sp.color || '#8B5CF6';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    {
      const sp_p = sp.params || {};
      const kP = +sp_p.kPeriod || sp.period || 14;
      const dP = +sp_p.dPeriod || 3;
      ctx.fillText(`STOCH ${kP}/${dP}`, sp.left + 4, sp.top + 8);
    }
    ctx.restore();
  }

  _drawAtrInPane(sp) {
    const ctx = this.ctx;
    if (this.candles.length === 0) return;
    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(sp.left, sp.top, sp.width, sp.height);
    const values = this._computeATR(sp.period);
    const visible = this._visibleCandles();
    if (visible.length === 0) { ctx.restore(); return; }
    const firstAbs = this.candles.indexOf(visible[0]);
    let lo = Infinity, hi = -Infinity;
    for (let i = 0; i < visible.length; i++) {
      const v = values[firstAbs + i];
      if (v == null) continue;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if (!Number.isFinite(lo) || !Number.isFinite(hi)) { ctx.restore(); return; }
    if (hi === lo) { hi += 0.5; lo -= 0.5; }
    if (sp.viewMin != null && sp.viewMax != null) { lo = sp.viewMin; hi = sp.viewMax; }
    const yFor = (v) => sp.top + (hi - v) * sp.height / (hi - lo);
    ctx.strokeStyle = sp.color || '#10B981';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null) continue;
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(v);
      if (!started) { ctx.moveTo(x, y); started = true; }
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
    ctx.font = '600 10px Geist, sans-serif';
    ctx.fillStyle = sp.color || '#10B981';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(`ATR ${sp.period}`, sp.left + 4, sp.top + 8);
    ctx.restore();
  }

  // Phase 20 — StochRSI sub-pane: %K (solid) + %D (dashed) bounded 0-100.
  _drawStochRsiInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeStochRsi(sp);
    const yMin = sp.viewMin != null ? sp.viewMin : 0;
    const yMax = sp.viewMax != null ? sp.viewMax : 100;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    // 80 / 20 reference lines.
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, yFor(80)); this.ctx.lineTo(sp.right, yFor(80));
    this.ctx.moveTo(sp.left, yFor(20)); this.ctx.lineTo(sp.right, yFor(20));
    this.ctx.stroke();
    // %K
    this.ctx.strokeStyle = sp.color || '#8B5CF6';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (!v || v.k == null || !isFinite(v.k)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(Math.max(0, Math.min(100, v.k)));
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    // %D
    this.ctx.strokeStyle = '#F59E0B';
    this.ctx.lineWidth = 1;
    this.ctx.setLineDash([3, 3]);
    this.ctx.beginPath();
    started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (!v || v.d == null || !isFinite(v.d)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(Math.max(0, Math.min(100, v.d)));
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.setLineDash([]);
    // Title label
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left';
    this.ctx.textBaseline = 'top';
    {
      const sp_p = sp.params || {};
      const rL = +sp_p.rsiLength || sp.period || 14;
      this.ctx.fillText('StochRSI ' + rL, sp.left + 4, sp.top + 2);
    }
  }

  // Phase 20 — Squeeze Momentum sub-pane: histogram of momentum + dot strip
  // for squeeze on/off at the zero baseline.
  _drawSqueezeInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeSqueeze(sp);
    // Find max |mom| in visible window for y-scaling — overridden by manual
    // view (which always renders symmetric around its center).
    let maxMom = 0;
    for (let i = 0; i < visible.length; i++) {
      const v = values[firstAbs + i];
      if (v && isFinite(v.mom) && Math.abs(v.mom) > maxMom) maxMom = Math.abs(v.mom);
    }
    if (maxMom <= 0) maxMom = 1;
    if (sp.viewMin != null && sp.viewMax != null) {
      maxMom = Math.max(Math.abs(sp.viewMin), Math.abs(sp.viewMax)) || 1;
    }
    const zeroY = sp.top + sp.height / 2;
    const bodyW = Math.max(1, this.view.cellW - 2);
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (!v) continue;
      const x = this._candleXCenter(absIdx, sp);
      const h = (v.mom / maxMom) * (sp.height / 2 - 2);
      const up = v.mom >= 0;
      // Momentum direction: rising or falling vs prev.
      const vPrev = values[absIdx - 1];
      const rising = vPrev && isFinite(vPrev.mom) ? v.mom > vPrev.mom : up;
      const color = up
          ? (rising ? '#22C55E' : '#86EFAC')
          : (rising ? '#FCA5A5' : '#EF4444');
      this.ctx.fillStyle = color;
      if (h >= 0) this.ctx.fillRect(Math.round(x - bodyW / 2), zeroY - h, bodyW, h);
      else this.ctx.fillRect(Math.round(x - bodyW / 2), zeroY, bodyW, -h);
      // Squeeze dot at zero line.
      this.ctx.fillStyle = v.squeezeOn ? '#EF4444' : '#3B82F6';
      this.ctx.beginPath();
      this.ctx.arc(x, zeroY, 1.5, 0, Math.PI * 2);
      this.ctx.fill();
    }
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, zeroY); this.ctx.lineTo(sp.right, zeroY);
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left';
    this.ctx.textBaseline = 'top';
    {
      const sp_p = sp.params || {};
      const bbL = +sp_p.bbLength || sp.period || 20;
      this.ctx.fillText('SQZ ' + bbL, sp.left + 4, sp.top + 2);
    }
  }

  // Phase 20 — Elder's Force Index sub-pane: signed histogram around zero.
  _drawEfiInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeEFI(sp.period || 13);
    let maxAbs = 0;
    for (let i = 0; i < visible.length; i++) {
      const v = values[firstAbs + i];
      if (v != null && isFinite(v) && Math.abs(v) > maxAbs) maxAbs = Math.abs(v);
    }
    if (maxAbs <= 0) maxAbs = 1;
    if (sp.viewMin != null && sp.viewMax != null) {
      maxAbs = Math.max(Math.abs(sp.viewMin), Math.abs(sp.viewMax)) || 1;
    }
    const zeroY = sp.top + sp.height / 2;
    const bodyW = Math.max(1, this.view.cellW - 2);
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) continue;
      const x = this._candleXCenter(absIdx, sp);
      const h = (v / maxAbs) * (sp.height / 2 - 2);
      this.ctx.fillStyle = v >= 0 ? '#22C55E' : '#EF4444';
      if (h >= 0) this.ctx.fillRect(Math.round(x - bodyW / 2), zeroY - h, bodyW, h);
      else this.ctx.fillRect(Math.round(x - bodyW / 2), zeroY, bodyW, -h);
    }
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, zeroY); this.ctx.lineTo(sp.right, zeroY);
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left';
    this.ctx.textBaseline = 'top';
    this.ctx.fillText('EFI ' + (sp.period || 13), sp.left + 4, sp.top + 2);
  }

  // Phase 22 — WaveTrend sub-pane: wt1 solid + wt2 dashed, 50/-50 reference lines.
  _drawWaveTrendInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeWaveTrend(sp);
    // Auto-scale Y to fit visible WT range.
    let lo = Infinity, hi = -Infinity;
    for (let i = 0; i < visible.length; i++) {
      const v = values[firstAbs + i];
      if (!v) continue;
      if (v.wt1 != null && isFinite(v.wt1)) { if (v.wt1 < lo) lo = v.wt1; if (v.wt1 > hi) hi = v.wt1; }
      if (v.wt2 != null && isFinite(v.wt2)) { if (v.wt2 < lo) lo = v.wt2; if (v.wt2 > hi) hi = v.wt2; }
    }
    if (!isFinite(lo) || !isFinite(hi) || lo === hi) { lo = -100; hi = 100; }
    const pad = (hi - lo) * 0.1;
    lo -= pad; hi += pad;
    if (sp.viewMin != null && sp.viewMax != null) { lo = sp.viewMin; hi = sp.viewMax; }
    const yFor = (v) => sp.top + sp.height - ((v - lo) / (hi - lo)) * sp.height;
    // 50 / -50 / 0 reference lines.
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, yFor(50)); this.ctx.lineTo(sp.right, yFor(50));
    this.ctx.moveTo(sp.left, yFor(-50)); this.ctx.lineTo(sp.right, yFor(-50));
    this.ctx.moveTo(sp.left, yFor(0)); this.ctx.lineTo(sp.right, yFor(0));
    this.ctx.stroke();
    // wt1
    this.ctx.strokeStyle = sp.color || '#3B82F6';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (!v || v.wt1 == null || !isFinite(v.wt1)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(v.wt1);
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    // wt2
    this.ctx.strokeStyle = '#F59E0B';
    this.ctx.lineWidth = 1;
    this.ctx.setLineDash([3, 3]);
    this.ctx.beginPath();
    started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (!v || v.wt2 == null || !isFinite(v.wt2)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(v.wt2);
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.setLineDash([]);
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    {
      const sp_p = sp.params || {};
      const cL = +sp_p.channelLength || sp.period || 10;
      this.ctx.fillText('WT ' + cL, sp.left + 4, sp.top + 2);
    }
  }

  // Phase 22 — Connors RSI sub-pane: single line bounded 0-100.
  _drawConnorsRSIInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeConnorsRSI(sp);
    const yMin = sp.viewMin != null ? sp.viewMin : 0;
    const yMax = sp.viewMax != null ? sp.viewMax : 100;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, yFor(70)); this.ctx.lineTo(sp.right, yFor(70));
    this.ctx.moveTo(sp.left, yFor(30)); this.ctx.lineTo(sp.right, yFor(30));
    this.ctx.stroke();
    this.ctx.strokeStyle = sp.color || '#8B5CF6';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(Math.max(0, Math.min(100, v)));
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    {
      const sp_p = sp.params || {};
      const rL = +sp_p.rsiLength || sp.period || 3;
      this.ctx.fillText('cRSI ' + rL, sp.left + 4, sp.top + 2);
    }
  }

  // ── Phase 25 — Compute helpers ────────────────────────────────────────────

  // Phase 25 — Awesome Oscillator: SMA(median, 5) - SMA(median, 34).
  // Returns histogram values (one per candle, null while warming).
  _computeAO() {
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < 34) return out;
    // Median price = (H + L) / 2
    const med = bars.map((b) => (b.h + b.l) / 2);
    for (let i = 33; i < bars.length; i++) {
      let s5 = 0, s34 = 0;
      for (let j = i - 4; j <= i; j++) s5 += med[j];
      for (let j = i - 33; j <= i; j++) s34 += med[j];
      out[i] = (s5 / 5) - (s34 / 34);
    }
    return out;
  }

  // Phase 25 — Money Flow Index: RSI-like 0-100 oscillator using
  // typical-price-weighted volume. Default period 14.
  _computeMFI(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < n + 1) return out;
    const tp = bars.map((b) => (b.h + b.l + b.c) / 3);
    for (let i = n; i < bars.length; i++) {
      let pos = 0, neg = 0;
      for (let j = i - n + 1; j <= i; j++) {
        const flow = tp[j] * (bars[j].v || 0);
        const prevTp = tp[j - 1];
        if (tp[j] > prevTp) pos += flow;
        else if (tp[j] < prevTp) neg += flow;
      }
      if (neg <= 0) { out[i] = 100; continue; }
      const ratio = pos / neg;
      out[i] = 100 - 100 / (1 + ratio);
    }
    return out;
  }

  // Phase 25 — On-Balance Volume: cumulative signed volume. Rising OBV with
  // price = healthy; divergence = caution.
  _computeOBV() {
    const bars = this.candles;
    const out = new Array(bars.length).fill(0);
    for (let i = 1; i < bars.length; i++) {
      const v = bars[i].v || 0;
      if (bars[i].c > bars[i - 1].c) out[i] = out[i - 1] + v;
      else if (bars[i].c < bars[i - 1].c) out[i] = out[i - 1] - v;
      else out[i] = out[i - 1];
    }
    return out;
  }

  // Phase 25 — Chaikin Money Flow: signed CLV-weighted volume / volume sum
  // over period. Range -1..+1.
  _computeCMF(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < n) return out;
    // CLV = ((C - L) - (H - C)) / (H - L)  if H != L else 0
    const mfv = bars.map((b) => {
      const r = b.h - b.l;
      if (r <= 0) return 0;
      const clv = ((b.c - b.l) - (b.h - b.c)) / r;
      return clv * (b.v || 0);
    });
    for (let i = n - 1; i < bars.length; i++) {
      let sumMfv = 0, sumV = 0;
      for (let j = i - n + 1; j <= i; j++) {
        sumMfv += mfv[j];
        sumV += (bars[j].v || 0);
      }
      out[i] = sumV > 0 ? sumMfv / sumV : 0;
    }
    return out;
  }

  // Phase 25 — Williams %R: 0 to -100 oscillator.
  // %R = (highestHigh(n) - close) / (highestHigh(n) - lowestLow(n)) * -100
  _computeWilliamsR(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < n) return out;
    for (let i = n - 1; i < bars.length; i++) {
      let hh = -Infinity, ll = Infinity;
      for (let j = i - n + 1; j <= i; j++) {
        if (bars[j].h > hh) hh = bars[j].h;
        if (bars[j].l < ll) ll = bars[j].l;
      }
      const r = hh - ll;
      out[i] = r > 0 ? ((hh - bars[i].c) / r) * -100 : -50;
    }
    return out;
  }

  // ── Phase 25 — Auto-pattern: swing pivot detection ────────────────────────

  // Phase 25 — find swing highs and lows in the candle series.
  // A swing high at index i = candles[i].h is the max of candles[i-N..i+N].
  // A swing low at index i = candles[i].l is the min of candles[i-N..i+N].
  // Returns an array of {idx, kind, price, label} sorted by idx, where
  // kind = 'H' (high) or 'L' (low), label = 'HH'/'HL'/'LH'/'LL' relative
  // to the previous swing of the SAME kind.
  _computeSwingPoints(window) {
    const N = Math.max(1, window | 0);
    const bars = this.candles;
    if (!bars || bars.length < N * 2 + 1) return [];
    const points = [];
    for (let i = N; i < bars.length - N; i++) {
      const c = bars[i];
      let isHigh = true;
      let isLow = true;
      for (let j = i - N; j <= i + N; j++) {
        if (j === i) continue;
        if (bars[j].h >= c.h) isHigh = false;
        if (bars[j].l <= c.l) isLow = false;
      }
      if (isHigh) {
        points.push({ idx: i, kind: 'H', price: c.h, label: '' });
      } else if (isLow) {
        points.push({ idx: i, kind: 'L', price: c.l, label: '' });
      }
    }
    // Label each point as HH/HL/LH/LL based on the previous same-kind point.
    let lastHigh = null;
    let lastLow = null;
    for (const p of points) {
      if (p.kind === 'H') {
        if (lastHigh != null) {
          p.label = p.price > lastHigh ? 'HH' : 'LH';
        }
        lastHigh = p.price;
      } else {
        if (lastLow != null) {
          p.label = p.price < lastLow ? 'LL' : 'HL';
        }
        lastLow = p.price;
      }
    }
    return points;
  }

  _drawAutoPattern(plot, lo, hi, priceToY) {
    if (!this.showAutoPattern) return;
    // 5-bar swing window — matches Bill Williams fractal convention used by
    // TradingView's "Fractals" / market-structure indicators. Smaller (3)
    // catches noise; larger (7+) misses meaningful swings on intraday TFs.
    const window = 5;
    const pts = this._computeSwingPoints(window);
    if (pts.length === 0) return;
    const ctx = this.ctx;
    ctx.save();
    ctx.font = '700 10px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';
    for (const p of pts) {
      // Skip the first pivot of each kind — it has no prior same-kind pivot
      // to compare against, so the empty label would render as a bare dot
      // with no context. Less informative than just omitting it.
      if (!p.label) continue;
      if (p.price < lo || p.price > hi) continue;
      const x = this._candleXCenter(p.idx, plot);
      const y = priceToY(p.price);
      const isHigh = p.kind === 'H';
      const color = isHigh ? (this.palette.bear || '#EF4444')
                           : (this.palette.bull || '#22C55E');

      // 1) Wick tick — a 2px short line at the exact pivot price so the
      // marker is anchored to the candle. Subtle, doesn't compete with
      // the label.
      ctx.strokeStyle = color;
      ctx.lineWidth = 2;
      ctx.beginPath();
      if (isHigh) {
        ctx.moveTo(x, y - 4);
        ctx.lineTo(x, y);
      } else {
        ctx.moveTo(x, y);
        ctx.lineTo(x, y + 4);
      }
      ctx.stroke();

      // 2) Solid colour pill — the indicator's bull/bear colour with
      // white bold text on top. No competing dark halo. Tiny vertical
      // gap from the wick tick so the label doesn't collide with the
      // candle body.
      const labelH = 16;
      const labelGap = 6;
      const ly = isHigh ? y - labelGap - labelH / 2
                        : y + labelGap + labelH / 2;
      const tw = Math.max(20, ctx.measureText(p.label).width + 8);
      const lx = x - tw / 2;
      const ltop = ly - labelH / 2;
      ctx.fillStyle = color;
      this._roundedRect(lx, ltop, tw, labelH, 4);
      ctx.fill();
      // Hairline darker border for definition on light backgrounds.
      ctx.strokeStyle = 'rgba(0,0,0,0.22)';
      ctx.lineWidth = 1;
      this._roundedRect(lx, ltop, tw, labelH, 4);
      ctx.stroke();
      ctx.fillStyle = '#FFFFFF';
      ctx.fillText(p.label, x, ly + 0.5);
    }
    ctx.restore();
  }

  // ── Phase 25 — Sub-pane renderers ─────────────────────────────────────────

  // Phase 25 — Awesome Oscillator: histogram of (SMA5 - SMA34) of median price.
  // Bar coloured green when rising vs prev, red when falling.
  _drawAoInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeAO();
    let maxAbs = 0;
    for (let i = 0; i < visible.length; i++) {
      const v = values[firstAbs + i];
      if (v != null && Math.abs(v) > maxAbs) maxAbs = Math.abs(v);
    }
    if (maxAbs <= 0) maxAbs = 1;
    if (sp.viewMin != null && sp.viewMax != null) {
      maxAbs = Math.max(Math.abs(sp.viewMin), Math.abs(sp.viewMax)) || 1;
    }
    const zeroY = sp.top + sp.height / 2;
    const bodyW = Math.max(1, this.view.cellW - 2);
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) continue;
      const prev = values[absIdx - 1];
      const rising = prev != null ? v > prev : v >= 0;
      this.ctx.fillStyle = rising ? '#22C55E' : '#EF4444';
      const x = this._candleXCenter(absIdx, sp);
      const h = (v / maxAbs) * (sp.height / 2 - 2);
      if (h >= 0) this.ctx.fillRect(Math.round(x - bodyW / 2), zeroY - h, bodyW, h);
      else this.ctx.fillRect(Math.round(x - bodyW / 2), zeroY, bodyW, -h);
    }
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, zeroY); this.ctx.lineTo(sp.right, zeroY);
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('AO', sp.left + 4, sp.top + 2);
  }

  // Phase 25 — Money Flow Index: 0-100 line in sub-pane with 80/20 reference.
  _drawMfiInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeMFI(sp.period || 14);
    const yMin = sp.viewMin != null ? sp.viewMin : 0;
    const yMax = sp.viewMax != null ? sp.viewMax : 100;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, yFor(80)); this.ctx.lineTo(sp.right, yFor(80));
    this.ctx.moveTo(sp.left, yFor(20)); this.ctx.lineTo(sp.right, yFor(20));
    this.ctx.stroke();
    this.ctx.strokeStyle = sp.color || '#06B6D4';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(Math.max(0, Math.min(100, v)));
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('MFI ' + (sp.period || 14), sp.left + 4, sp.top + 2);
  }

  // Phase 25 — OBV: cumulative signed volume. Auto-scaled line.
  _drawObvInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeOBV();
    let lo = Infinity, hi = -Infinity;
    for (let i = 0; i < visible.length; i++) {
      const v = values[firstAbs + i];
      if (v == null || !isFinite(v)) continue;
      if (v < lo) lo = v; if (v > hi) hi = v;
    }
    if (!isFinite(lo) || !isFinite(hi) || lo === hi) { lo = -1; hi = 1; }
    const pad = (hi - lo) * 0.1;
    lo -= pad; hi += pad;
    if (sp.viewMin != null && sp.viewMax != null) { lo = sp.viewMin; hi = sp.viewMax; }
    const yFor = (v) => sp.top + sp.height - ((v - lo) / (hi - lo)) * sp.height;
    this.ctx.strokeStyle = sp.color || '#84CC16';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(v);
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('OBV', sp.left + 4, sp.top + 2);
  }

  // Phase 25 — Chaikin Money Flow: -1..+1 line, zero reference.
  _drawCmfInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeCMF(sp.period || 20);
    // Default range [-1,1] symmetric; user manual view overrides.
    const yMin = sp.viewMin != null ? sp.viewMin : -1;
    const yMax = sp.viewMax != null ? sp.viewMax : 1;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, yFor(0)); this.ctx.lineTo(sp.right, yFor(0));
    this.ctx.stroke();
    this.ctx.strokeStyle = sp.color || '#A855F7';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(Math.max(-1, Math.min(1, v)));
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('CMF ' + (sp.period || 20), sp.left + 4, sp.top + 2);
  }

  // Phase 25 — Williams %R: -100..0 line, -20/-80 reference.
  _drawWilliamsRInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const values = this._computeWilliamsR(sp.period || 14);
    const yMin = sp.viewMin != null ? sp.viewMin : -100;
    const yMax = sp.viewMax != null ? sp.viewMax : 0;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(sp.left, yFor(-20)); this.ctx.lineTo(sp.right, yFor(-20));
    this.ctx.moveTo(sp.left, yFor(-80)); this.ctx.lineTo(sp.right, yFor(-80));
    this.ctx.stroke();
    this.ctx.strokeStyle = sp.color || '#F59E0B';
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const absIdx = firstAbs + i;
      const v = values[absIdx];
      if (v == null || !isFinite(v)) { started = false; continue; }
      const x = this._candleXCenter(absIdx, sp);
      const y = yFor(Math.max(-100, Math.min(0, v)));
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('%R ' + (sp.period || 14), sp.left + 4, sp.top + 2);
  }

  // ── Phase 29 — added indicators ──────────────────────────────────────────

  // Weighted moving average (linear weights n..1) over close.
  _computeWMA(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < n) return out;
    const denom = n * (n + 1) / 2;
    for (let i = n - 1; i < bars.length; i++) {
      let s = 0;
      for (let k = 0; k < n; k++) s += bars[i - k].c * (n - k);
      out[i] = s / denom;
    }
    return out;
  }

  // Generic linear-WMA over an arbitrary value array (used by HMA). Not
  // memoized (array arg) — callers are already memoized.
  _wmaArr(values, period) {
    const n = Math.max(1, period | 0);
    const out = new Array(values.length).fill(null);
    const denom = n * (n + 1) / 2;
    for (let i = n - 1; i < values.length; i++) {
      let s = 0, ok = true;
      for (let k = 0; k < n; k++) {
        const v = values[i - k];
        if (v == null || !isFinite(v)) { ok = false; break; }
        s += v * (n - k);
      }
      out[i] = ok ? s / denom : null;
    }
    return out;
  }

  // Hull MA: WMA(2·WMA(n/2) − WMA(n), √n).
  _computeHMA(period) {
    const n = Math.max(2, period | 0);
    const closes = this.candles.map((c) => c.c);
    const half = Math.max(1, Math.round(n / 2));
    const sq = Math.max(1, Math.round(Math.sqrt(n)));
    const w1 = this._wmaArr(closes, half);
    const w2 = this._wmaArr(closes, n);
    const raw = closes.map((_, i) =>
        (w1[i] != null && w2[i] != null) ? (2 * w1[i] - w2[i]) : null);
    return this._wmaArr(raw, sq);
  }

  // Keltner Channels: EMA mid ± mult·ATR.
  _computeKeltner(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const period = +p.length || +arg.period || 20;
    const mult = +p.mult || 2;
    const atrP = +p.atrLength || 10;
    const mid = this._computeEMA(period);
    const atr = this._computeATR(atrP);
    const N = this.candles.length;
    const upper = new Array(N).fill(null), lower = new Array(N).fill(null);
    for (let i = 0; i < N; i++) {
      if (mid[i] != null && atr[i] != null) {
        upper[i] = mid[i] + mult * atr[i];
        lower[i] = mid[i] - mult * atr[i];
      }
    }
    return { mid, upper, lower };
  }

  // Donchian Channels: rolling high / low / midline.
  _computeDonchian(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const period = +p.length || +arg.period || 20;
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const N = bars.length;
    const upper = new Array(N).fill(null), lower = new Array(N).fill(null), mid = new Array(N).fill(null);
    for (let i = n - 1; i < N; i++) {
      let hh = -Infinity, ll = Infinity;
      for (let j = i - n + 1; j <= i; j++) {
        if (bars[j].h > hh) hh = bars[j].h;
        if (bars[j].l < ll) ll = bars[j].l;
      }
      upper[i] = hh; lower[i] = ll; mid[i] = (hh + ll) / 2;
    }
    return { upper, lower, mid };
  }

  // SuperTrend: ATR-banded trend follower. Returns { st, dir } where
  // dir 1 = up (green), -1 = down (red); st is the active band level.
  _computeSuperTrend(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const period = +p.atrLength || +arg.period || 10;
    const mult = +p.mult || 3;
    const bars = this.candles;
    const N = bars.length;
    const atr = this._computeATR(period);
    const st = new Array(N).fill(null), dir = new Array(N).fill(null);
    let fu = null, fl = null, prevST = null, prevDir = 1;
    for (let i = 0; i < N; i++) {
      if (atr[i] == null) continue;
      const hl2 = (bars[i].h + bars[i].l) / 2;
      const bu = hl2 + mult * atr[i], bl = hl2 - mult * atr[i];
      const prevClose = i > 0 ? bars[i - 1].c : bars[i].c;
      const newFu = (fu == null) ? bu : ((bu < fu || prevClose > fu) ? bu : fu);
      const newFl = (fl == null) ? bl : ((bl > fl || prevClose < fl) ? bl : fl);
      const close = bars[i].c;
      let d, s;
      if (prevST == null) { d = close >= hl2 ? 1 : -1; s = d === 1 ? newFl : newFu; }
      else if (prevDir === 1) {
        if (close < newFl) { d = -1; s = newFu; } else { d = 1; s = newFl; }
      } else {
        if (close > newFu) { d = 1; s = newFl; } else { d = -1; s = newFu; }
      }
      fu = newFu; fl = newFl; prevST = s; prevDir = d;
      st[i] = s; dir[i] = d;
    }
    return { st, dir };
  }

  // Commodity Channel Index.
  _computeCCI(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < n) return out;
    const tp = bars.map((b) => (b.h + b.l + b.c) / 3);
    for (let i = n - 1; i < bars.length; i++) {
      let sum = 0;
      for (let j = i - n + 1; j <= i; j++) sum += tp[j];
      const sma = sum / n;
      let dev = 0;
      for (let j = i - n + 1; j <= i; j++) dev += Math.abs(tp[j] - sma);
      const mad = dev / n;
      out[i] = mad > 0 ? (tp[i] - sma) / (0.015 * mad) : 0;
    }
    return out;
  }

  // Rate of Change (%) vs the close `period` bars ago.
  _computeROC(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    for (let i = n; i < bars.length; i++) {
      const prev = bars[i - n].c;
      out[i] = prev !== 0 ? (bars[i].c / prev - 1) * 100 : null;
    }
    return out;
  }

  // Cumulative Volume Delta — signed by candle direction (no L2 tape).
  _computeCVD() {
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    let cum = 0;
    for (let i = 0; i < bars.length; i++) {
      const c = bars[i];
      const sgn = c.c > c.o ? 1 : c.c < c.o ? -1 : 0;
      cum += sgn * (c.v || 0);
      out[i] = cum;
    }
    return out;
  }

  // ADX / DMI (Wilder). Returns { adx, plusDI, minusDI }.
  _computeADX(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const len = bars.length;
    const adx = new Array(len).fill(null);
    const pdi = new Array(len).fill(null);
    const mdi = new Array(len).fill(null);
    if (len < 2 * n) return { adx, plusDI: pdi, minusDI: mdi };
    const tr = new Array(len).fill(0);
    const plusDM = new Array(len).fill(0);
    const minusDM = new Array(len).fill(0);
    for (let i = 1; i < len; i++) {
      const up = bars[i].h - bars[i - 1].h;
      const dn = bars[i - 1].l - bars[i].l;
      plusDM[i] = (up > dn && up > 0) ? up : 0;
      minusDM[i] = (dn > up && dn > 0) ? dn : 0;
      tr[i] = Math.max(
          bars[i].h - bars[i].l,
          Math.abs(bars[i].h - bars[i - 1].c),
          Math.abs(bars[i].l - bars[i - 1].c));
    }
    let trS = 0, pS = 0, mS = 0;
    for (let i = 1; i <= n; i++) { trS += tr[i]; pS += plusDM[i]; mS += minusDM[i]; }
    const dx = new Array(len).fill(null);
    for (let i = n; i < len; i++) {
      if (i > n) {
        trS = trS - trS / n + tr[i];
        pS = pS - pS / n + plusDM[i];
        mS = mS - mS / n + minusDM[i];
      }
      const pDI = trS > 0 ? 100 * pS / trS : 0;
      const mDI = trS > 0 ? 100 * mS / trS : 0;
      pdi[i] = pDI; mdi[i] = mDI;
      const sum = pDI + mDI;
      dx[i] = sum > 0 ? 100 * Math.abs(pDI - mDI) / sum : 0;
    }
    const adxStart = n + n - 1;
    if (adxStart < len) {
      let s = 0;
      for (let i = n; i <= adxStart; i++) s += dx[i] || 0;
      adx[adxStart] = s / n;
      for (let i = adxStart + 1; i < len; i++) {
        adx[i] = (adx[i - 1] * (n - 1) + (dx[i] || 0)) / n;
      }
    }
    return { adx, plusDI: pdi, minusDI: mdi };
  }

  // Shared single-line sub-pane renderer (background-less, mirrors %R style).
  _lineSubPane(sp, values, label, color, refLines) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    let yMin = sp.viewMin, yMax = sp.viewMax;
    if (yMin == null || yMax == null) {
      let lo = Infinity, hi = -Infinity;
      for (let i = 0; i < visible.length; i++) {
        const v = values[firstAbs + i];
        if (v != null && isFinite(v)) { if (v < lo) lo = v; if (v > hi) hi = v; }
      }
      if (!isFinite(lo) || !isFinite(hi)) return;
      const pad = (hi - lo) * 0.1 || 1;
      yMin = lo - pad; yMax = hi + pad;
    }
    if (yMax === yMin) yMax = yMin + 1;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    if (refLines && refLines.length) {
      this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
      this.ctx.lineWidth = 0.5;
      this.ctx.beginPath();
      for (const lv of refLines) {
        if (lv < yMin || lv > yMax) continue;
        const y = yFor(lv);
        this.ctx.moveTo(sp.left, y); this.ctx.lineTo(sp.right, y);
      }
      this.ctx.stroke();
    }
    this.ctx.strokeStyle = sp.color || color;
    this.ctx.lineWidth = 1.25;
    this.ctx.beginPath();
    let started = false;
    for (let i = 0; i < visible.length; i++) {
      const a = firstAbs + i;
      const v = values[a];
      if (v == null || !isFinite(v)) { started = false; continue; }
      const x = this._candleXCenter(a, sp);
      const y = yFor(v);
      if (!started) { this.ctx.moveTo(x, y); started = true; }
      else this.ctx.lineTo(x, y);
    }
    this.ctx.stroke();
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText(label, sp.left + 4, sp.top + 2);
  }

  _drawCciInPane(sp) {
    const period = sp.period || 20;
    this._lineSubPane(sp, this._computeCCI(period), 'CCI ' + period, '#3B82F6', [-100, 0, 100]);
  }

  _drawRocInPane(sp) {
    const period = sp.period || 9;
    this._lineSubPane(sp, this._computeROC(period), 'ROC ' + period, '#A855F7', [0]);
  }

  _drawCvdInPane(sp) {
    this._lineSubPane(sp, this._computeCVD(), 'CVD', '#06B6D4', [0]);
  }

  _drawTrixInPane(sp) {
    const period = sp.period || 15;
    this._lineSubPane(sp, this._computeTRIX(period), 'TRIX ' + period, '#A855F7', [0]);
  }

  _drawUoInPane(sp) {
    this._lineSubPane(sp, this._computeUO(), 'UO', '#3B82F6', [30, 50, 70]);
  }

  _drawDpoInPane(sp) {
    const period = sp.period || 20;
    this._lineSubPane(sp, this._computeDPO(period), 'DPO ' + period, '#EAB308', [0]);
  }

  _drawPvtInPane(sp) {
    this._lineSubPane(sp, this._computePVT(), 'PVT', '#06B6D4', [0]);
  }

  _drawAdInPane(sp) {
    this._lineSubPane(sp, this._computeAD(), 'A/D', '#10B981', [0]);
  }

  _drawAdxInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const period = sp.period || 14;
    const r = this._computeADX(period);
    const yMin = 0;
    const yMax = (sp.viewMax != null && sp.viewMax > 0) ? sp.viewMax : 50;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    // Reference line at 25 (trend threshold).
    this.ctx.strokeStyle = this.palette.gridSoft || 'rgba(120,120,120,0.25)';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    const y25 = yFor(25);
    this.ctx.moveTo(sp.left, y25); this.ctx.lineTo(sp.right, y25);
    this.ctx.stroke();
    const series = [
      { vals: r.plusDI, col: '#22C55E' },
      { vals: r.minusDI, col: '#EF4444' },
      { vals: r.adx, col: sp.color || '#3B82F6' },
    ];
    for (const s of series) {
      this.ctx.strokeStyle = s.col;
      this.ctx.lineWidth = 1.2;
      this.ctx.beginPath();
      let started = false;
      for (let i = 0; i < visible.length; i++) {
        const a = firstAbs + i;
        const v = s.vals[a];
        if (v == null || !isFinite(v)) { started = false; continue; }
        const x = this._candleXCenter(a, sp);
        const y = yFor(Math.max(yMin, Math.min(yMax, v)));
        if (!started) { this.ctx.moveTo(x, y); started = true; }
        else this.ctx.lineTo(x, y);
      }
      this.ctx.stroke();
    }
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('ADX ' + period + '  +DI / -DI', sp.left + 4, sp.top + 2);
  }

  // Vortex Indicator — two lines (VI+ green, VI- red). Mirrors _drawAdxInPane.
  _drawVortexInPane(sp) {
    const visible = this._visibleCandles();
    if (!visible.length) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    if (firstAbs < 0) return;
    const period = sp.period || 14;
    const r = this._computeVortex(period);
    let yMin = sp.viewMin, yMax = sp.viewMax;
    if (yMin == null || yMax == null) {
      let lo = Infinity, hi = -Infinity;
      for (const arr of [r.viPlus, r.viMinus]) {
        for (let i = 0; i < visible.length; i++) {
          const v = arr[firstAbs + i];
          if (v != null && isFinite(v)) { if (v < lo) lo = v; if (v > hi) hi = v; }
        }
      }
      if (!isFinite(lo) || !isFinite(hi)) return;
      const pad = (hi - lo) * 0.1 || 0.1;
      yMin = lo - pad; yMax = hi + pad;
    }
    if (yMax === yMin) yMax = yMin + 1;
    const yFor = (v) => sp.top + sp.height - ((v - yMin) / (yMax - yMin)) * sp.height;
    const series = [
      { vals: r.viPlus, col: '#22C55E' },
      { vals: r.viMinus, col: '#EF4444' },
    ];
    for (const s of series) {
      this.ctx.strokeStyle = s.col;
      this.ctx.lineWidth = 1.2;
      this.ctx.beginPath();
      let started = false;
      for (let i = 0; i < visible.length; i++) {
        const a = firstAbs + i;
        const v = s.vals[a];
        if (v == null || !isFinite(v)) { started = false; continue; }
        const x = this._candleXCenter(a, sp);
        const y = yFor(v);
        if (!started) { this.ctx.moveTo(x, y); started = true; }
        else this.ctx.lineTo(x, y);
      }
      this.ctx.stroke();
    }
    this.ctx.fillStyle = this.palette.axisText || '#94a3b8';
    this.ctx.font = '500 9px Geist, sans-serif';
    this.ctx.textAlign = 'left'; this.ctx.textBaseline = 'top';
    this.ctx.fillText('Vortex ' + period + '  VI+ / VI-', sp.left + 4, sp.top + 2);
  }

  // Volume-Weighted Moving Average: Σ(close·vol, n) / Σ(vol, n).
  _computeVWMA(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const out = new Array(bars.length).fill(null);
    if (bars.length < n) return out;
    for (let i = n - 1; i < bars.length; i++) {
      let pv = 0, vv = 0;
      for (let k = 0; k < n; k++) {
        const b = bars[i - k];
        const v = b.v || 0;
        pv += b.c * v;
        vv += v;
      }
      out[i] = vv > 0 ? pv / vv : null;
    }
    return out;
  }

  // Parabolic SAR (classic Wilder). AF starts at `accel`, steps by `accel`
  // on each new extreme up to `maxAccel`, flips when price penetrates the
  // SAR. Returns { sar, dir } where dir 1 = SAR below price (uptrend).
  _computePSAR(arg) {
    const p = (arg && typeof arg === 'object') ? (arg.params || {}) : {};
    const accel = +p.accel || 0.02;
    const maxAccel = +p.maxAccel || 0.2;
    const bars = this.candles;
    const N = bars.length;
    const sar = new Array(N).fill(null);
    const dir = new Array(N).fill(null);
    if (N < 2) return { sar, dir };
    // Seed: assume uptrend, EP = first high, SAR = first low.
    let up = true;
    let af = accel;
    let ep = bars[0].h;
    let sarVal = bars[0].l;
    sar[0] = sarVal;
    dir[0] = 1;
    for (let i = 1; i < N; i++) {
      let next = sarVal + af * (ep - sarVal);
      if (up) {
        // SAR can't exceed prior two lows.
        next = Math.min(next, bars[i - 1].l, bars[i >= 2 ? i - 2 : i - 1].l);
        if (bars[i].l < next) {
          // Flip to downtrend.
          up = false;
          sarVal = ep;
          ep = bars[i].l;
          af = accel;
        } else {
          sarVal = next;
          if (bars[i].h > ep) { ep = bars[i].h; af = Math.min(maxAccel, af + accel); }
        }
      } else {
        next = Math.max(next, bars[i - 1].h, bars[i >= 2 ? i - 2 : i - 1].h);
        if (bars[i].h > next) {
          // Flip to uptrend.
          up = true;
          sarVal = ep;
          ep = bars[i].h;
          af = accel;
        } else {
          sarVal = next;
          if (bars[i].l < ep) { ep = bars[i].l; af = Math.min(maxAccel, af + accel); }
        }
      }
      sar[i] = sarVal;
      dir[i] = up ? 1 : -1;
    }
    return { sar, dir };
  }

  // TRIX: 100 · 1-bar %change of EMA(EMA(EMA(close, n), n), n).
  _computeTRIX(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const N = bars.length;
    const out = new Array(N).fill(null);
    const ema = (src) => {
      const res = new Array(N).fill(null);
      const k = 2 / (n + 1);
      let prev = null, seeded = -1;
      for (let i = 0; i < N; i++) {
        const v = src[i];
        if (v == null || !isFinite(v)) continue;
        if (prev == null) { prev = v; seeded = i; }
        else prev = v * k + prev * (1 - k);
        if (i - seeded >= n - 1) res[i] = prev;
      }
      return res;
    };
    const closes = bars.map((b) => b.c);
    const e3 = ema(ema(ema(closes)));
    for (let i = 1; i < N; i++) {
      const prev = e3[i - 1];
      if (e3[i] != null && prev != null && prev !== 0) {
        out[i] = (e3[i] / prev - 1) * 100;
      }
    }
    return out;
  }

  // Vortex Indicator. VI+ = Σ(VM+, n)/Σ(TR, n), VI- = Σ(VM-, n)/Σ(TR, n).
  _computeVortex(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const N = bars.length;
    const viPlus = new Array(N).fill(null);
    const viMinus = new Array(N).fill(null);
    if (N < n + 1) return { viPlus, viMinus };
    const vmP = new Array(N).fill(0);
    const vmM = new Array(N).fill(0);
    const tr = new Array(N).fill(0);
    for (let i = 1; i < N; i++) {
      vmP[i] = Math.abs(bars[i].h - bars[i - 1].l);
      vmM[i] = Math.abs(bars[i].l - bars[i - 1].h);
      tr[i] = Math.max(
          bars[i].h - bars[i].l,
          Math.abs(bars[i].h - bars[i - 1].c),
          Math.abs(bars[i].l - bars[i - 1].c));
    }
    for (let i = n; i < N; i++) {
      let sP = 0, sM = 0, sT = 0;
      for (let j = i - n + 1; j <= i; j++) { sP += vmP[j]; sM += vmM[j]; sT += tr[j]; }
      if (sT > 0) { viPlus[i] = sP / sT; viMinus[i] = sM / sT; }
    }
    return { viPlus, viMinus };
  }

  // Ultimate Oscillator (Larry Williams). Weighted 7/14/28 BP/TR sums.
  _computeUO() {
    const bars = this.candles;
    const N = bars.length;
    const out = new Array(N).fill(null);
    if (N < 29) return out;
    const bp = new Array(N).fill(0);
    const tr = new Array(N).fill(0);
    for (let i = 1; i < N; i++) {
      const prevC = bars[i - 1].c;
      const minLC = Math.min(bars[i].l, prevC);
      bp[i] = bars[i].c - minLC;
      tr[i] = Math.max(bars[i].h, prevC) - minLC;
    }
    const sum = (arr, i, len) => { let s = 0; for (let j = i - len + 1; j <= i; j++) s += arr[j]; return s; };
    for (let i = 28; i < N; i++) {
      const t7 = sum(tr, i, 7), t14 = sum(tr, i, 14), t28 = sum(tr, i, 28);
      if (t7 <= 0 || t14 <= 0 || t28 <= 0) continue;
      const a7 = sum(bp, i, 7) / t7;
      const a14 = sum(bp, i, 14) / t14;
      const a28 = sum(bp, i, 28) / t28;
      out[i] = 100 * (4 * a7 + 2 * a14 + a28) / 7;
    }
    return out;
  }

  // Detrended Price Oscillator: close[i-(n/2+1)] - SMA(close, n)[i].
  _computeDPO(period) {
    const n = Math.max(1, period | 0);
    const bars = this.candles;
    const N = bars.length;
    const out = new Array(N).fill(null);
    const sma = this._computeSMA(n);
    const shift = Math.floor(n / 2) + 1;
    for (let i = 0; i < N; i++) {
      const j = i - shift;
      if (j < 0 || sma[i] == null) continue;
      out[i] = bars[j].c - sma[i];
    }
    return out;
  }

  // Price Volume Trend: cumulative prevPVT + ((close-prevClose)/prevClose)·vol.
  _computePVT() {
    const bars = this.candles;
    const N = bars.length;
    const out = new Array(N).fill(null);
    if (N === 0) return out;
    let cum = 0;
    out[0] = 0;
    for (let i = 1; i < N; i++) {
      const prevC = bars[i - 1].c;
      if (prevC !== 0) cum += ((bars[i].c - prevC) / prevC) * (bars[i].v || 0);
      out[i] = cum;
    }
    return out;
  }

  // Accumulation/Distribution: cumulative MFV. Guards high==low (adds 0).
  _computeAD() {
    const bars = this.candles;
    const N = bars.length;
    const out = new Array(N).fill(null);
    let cum = 0;
    for (let i = 0; i < N; i++) {
      const h = bars[i].h, l = bars[i].l, c = bars[i].c;
      const range = h - l;
      if (range > 0) cum += (((c - l) - (h - c)) / range) * (bars[i].v || 0);
      out[i] = cum;
    }
    return out;
  }
}
