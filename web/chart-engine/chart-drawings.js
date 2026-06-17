'use strict';

// ---------------------------------------------------------------------------
// chart-drawings.js — user drawing rendering — split out of chart.js. Methods are authored verbatim inside a
// throwaway mixin class (keeps class-method syntax, no edits) and copied onto
// Chart.prototype at load. Loaded AFTER chart.js. Behaviour identical.
// ---------------------------------------------------------------------------
class _ChartDrawingsMixin {
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

}
for (const _k of Object.getOwnPropertyNames(_ChartDrawingsMixin.prototype)) {
  if (_k !== 'constructor') Chart.prototype[_k] = _ChartDrawingsMixin.prototype[_k];
}
