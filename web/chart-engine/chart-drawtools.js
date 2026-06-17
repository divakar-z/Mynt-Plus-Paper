'use strict';

// ---------------------------------------------------------------------------
// chart-drawtools.js — the DRAWING_TOOLS registry (one entry per drawing tool:
// clicks + render(g,d) [+ expand]). Loaded AFTER chart-helpers.js (whose
// geometry/paint helpers the render fns call) and BEFORE chart.js (which reads
// DRAWING_TOOLS by name at draw time). Pure data — split out of chart.js.
// ---------------------------------------------------------------------------
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

// Dual-mode export — browser global AND node require() for a registry-integrity test.
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { DRAWING_TOOLS };
}
