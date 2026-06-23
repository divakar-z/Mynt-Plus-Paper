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
        const tH = 28;                   // toolbar height (pill)
        const btn = 28;                  // square button hit area
        const inner = 4;                 // pad inside the toolbar card
        // Text-bearing annotations get an extra "edit text" (pencil) button.
        // (Price Label is excluded — it auto-shows the price, no editable text.)
        const TEXT_KINDS = { text: 1, note: 1, callout: 1, comment: 1,
                             signpost: 1 };
        const isTextKind = !!TEXT_KINDS[d.kind];
        const btnCount = isTextKind ? 7 : 6;
        const strokeBtnExtra = 14;       // extra width for "Npx" label
        const toolbarW = inner * 2 + btn * btnCount + strokeBtnExtra;
        const chipW = 14;
        const rightAnchor = plot.right - 60;
        let tX = endX < rightAnchor
            ? Math.max(plot.left + 4, endX - toolbarW - 4)
            : rightAnchor - toolbarW;
        if (tX < plot.left + 4) tX = plot.left + 4;
        const tY = Math.max(plot.top + 4, endY - chipH / 2 - tH - 4);
        const isLocked = d.locked === true;
        const dThickness = (d.thickness && d.thickness > 0) ? d.thickness : 1;
        const isLightTb = (this._basePalette && this._basePalette.bg === '#FFFFFF');
        const tbBg = isLightTb ? '#FFFFFF' : '#1B2027';
        const tbBorder = isLightTb ? '#E5E7EB' : 'rgba(255,255,255,0.10)';
        const tbIcon = isLightTb ? '#1F2937' : 'rgba(255,255,255,0.88)';
        const tbIconMute = isLightTb ? '#9CA3AF' : 'rgba(255,255,255,0.45)';

        const tbRadius = 4;
        if (isLightTb) {
          const shadowLayers = [
            { blur: 1, offY: 1, alpha: 0.04 },
            { blur: 4, offY: 2, alpha: 0.06 },
            { blur: 16, offY: 8, alpha: 0.08 },
          ];
          for (const s of shadowLayers) {
            ctx.save();
            ctx.shadowColor = 'rgba(0,0,0,' + s.alpha + ')';
            ctx.shadowBlur = s.blur;
            ctx.shadowOffsetY = s.offY;
            ctx.fillStyle = tbBg;
            this._roundedRect(tX, tY, toolbarW, tH, tbRadius);
            ctx.fill();
            ctx.restore();
          }
        } else {
          ctx.save();
          ctx.shadowColor = 'rgba(0,0,0,0.45)';
          ctx.shadowBlur = 10;
          ctx.shadowOffsetY = 2;
          ctx.fillStyle = tbBg;
          this._roundedRect(tX, tY, toolbarW, tH, tbRadius);
          ctx.fill();
          ctx.restore();
        }
        ctx.strokeStyle = tbBorder;
        ctx.lineWidth = 1;
        this._roundedRect(tX, tY, toolbarW, tH, tbRadius);
        ctx.stroke();

        // ── Helpers ─────────────────────────────────────────────────────
        const buttons = [];
        let bx = tX + inner;
        const by = tY;
        const stepX = () => { const out = bx; bx += btn; return out; };

        // 1) Drag handle — six dots in a 2x3 grid.
        {
          const ax = stepX();
          ctx.fillStyle = tbIconMute;
          const cxg = ax + btn / 2;
          const cyg = by + tH / 2;
          for (let dy = -1; dy <= 1; dy++) {
            for (let dx = -1; dx <= 1; dx += 2) {
              ctx.beginPath();
              ctx.arc(cxg + dx * 2.2, cyg + dy * 4, 1.4, 0, Math.PI * 2);
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

        // 2) Color square (no chevron — clicking opens the picker)
        {
          const ax = stepX();
          const swSize = 14;
          const swX = ax + (btn - swSize) / 2;
          const swY = by + (tH - swSize) / 2;
          ctx.fillStyle = d.color || '#3B82F6';
          this._roundedRect(swX, swY, swSize, swSize, 3);
          ctx.fill();
          ctx.strokeStyle = isLightTb ? 'rgba(15,23,42,0.18)' : 'rgba(255,255,255,0.18)';
          ctx.lineWidth = 1;
          this._roundedRect(swX, swY, swSize, swSize, 3);
          ctx.stroke();
          buttons.push({
            rect: { x: ax, y: by, w: btn, h: tH },
            action: 'openColor',
            anchorX: ax,
          });
        }

        // 3) Stroke width preview — short line + "Npx" label
        {
          const ax = stepX();
          const sBtn = btn + strokeBtnExtra;
          const lineX0 = ax + 5;
          const lineX1 = ax + 16;
          const cyg = by + tH / 2;
          ctx.strokeStyle = tbIcon;
          ctx.lineWidth = Math.max(dThickness, 1.5);
          ctx.lineCap = 'round';
          ctx.beginPath();
          ctx.moveTo(lineX0, cyg);
          ctx.lineTo(lineX1, cyg);
          ctx.stroke();
          ctx.fillStyle = tbIcon;
          ctx.font = '600 11px Geist, sans-serif';
          ctx.textAlign = 'left';
          ctx.textBaseline = 'middle';
          ctx.fillText(dThickness + 'px', lineX1 + 4, cyg + 0.5);
          buttons.push({
            rect: { x: ax, y: by, w: sBtn, h: tH },
            action: 'openStroke',
            anchorX: ax,
          });
          bx += strokeBtnExtra;
        }

        // 3.5) Edit text — pencil (only for text-bearing annotations). Clicking
        //      re-opens the text dialog seeded with the current value.
        if (isTextKind) {
          const ax = stepX();
          const cxg = ax + btn / 2;
          const cyg = by + tH / 2;
          const iconPx = 16;
          const pencilD =
              'M11.5 2.5 a1.414 1.414 0 0 1 2 2 L5.5 12.5 L2.5 13.5 L3.5 10.5 Z';
          const nibD = 'M10 4 l2 2';
          ctx.save();
          ctx.translate(cxg - iconPx / 2, cyg - iconPx / 2);
          ctx.scale(iconPx / 16, iconPx / 16);
          ctx.strokeStyle = tbIcon;
          ctx.lineWidth = 1;
          ctx.lineCap = 'round';
          ctx.lineJoin = 'round';
          ctx.stroke(new Path2D(pencilD));
          ctx.stroke(new Path2D(nibD));
          ctx.restore();
          buttons.push({
            rect: { x: ax, y: by, w: btn, h: tH },
            action: 'editText',
          });
        }

        // 4) Duplicate — charm-icons clone glyph (stroked, viewBox 16)
        {
          const ax = stepX();
          const cxg = ax + btn / 2;
          const cyg = by + tH / 2;
          const iconPx = 16;
          const cloneD = 'M11.25 4.25 V1.75 H1.75 V11.25 H4.25 M4.75 4.75 V14.25 H14.25 V4.75 Z';
          ctx.save();
          ctx.translate(cxg - iconPx / 2, cyg - iconPx / 2);
          ctx.scale(iconPx / 16, iconPx / 16);
          ctx.strokeStyle = tbIcon;
          ctx.lineWidth = 1;
          ctx.lineCap = 'round';
          ctx.lineJoin = 'round';
          ctx.stroke(new Path2D(cloneD));
          ctx.restore();
          buttons.push({
            rect: { x: ax, y: by, w: btn, h: tH },
            action: 'duplicate',
          });
        }

        // 5) Lock / unlock — charm-icons style stroke (viewBox 16); black
        //    active bg when locked
        {
          const ax = stepX();
          const cxg = ax + btn / 2;
          const cyg = by + tH / 2;
          const iconPx = 16;
          // Body rounded rect + shackle. Locked: full arc. Unlocked: left
          // leg + partial arc that lifts away from the body.
          const lockBodyD = 'M3.25 6.75 H12.75 V13.75 H3.25 Z';
          const lockedShackleD =
              'M4.75 6.75 V5.25 A3.25 3.25 0 0 1 11.25 5.25 V6.75';
          const unlockedShackleD =
              'M4.75 6.75 V5.25 A3.25 3.25 0 0 1 10.75 3.75';
          const activeBg = isLightTb ? '#121212' : '#FFFFFF';
          const activeFg = isLightTb ? '#FFFFFF' : '#121212';
          if (isLocked) {
            ctx.fillStyle = activeBg;
            this._roundedRect(ax + 3, by + 3, btn - 6, tH - 6, 5);
            ctx.fill();
          }
          ctx.save();
          ctx.translate(cxg - iconPx / 2, cyg - iconPx / 2);
          ctx.scale(iconPx / 16, iconPx / 16);
          ctx.strokeStyle = isLocked ? activeFg : tbIcon;
          ctx.lineWidth = 1;
          ctx.lineCap = 'round';
          ctx.lineJoin = 'round';
          ctx.stroke(new Path2D(lockBodyD));
          ctx.stroke(new Path2D(isLocked ? lockedShackleD : unlockedShackleD));
          ctx.restore();
          buttons.push({
            rect: { x: ax, y: by, w: btn, h: tH },
            action: 'lockToggle',
          });
        }

        // 6) Delete — MingCute trash, line/outline variant (viewBox 24)
        {
          const ax = stepX();
          const cxg = ax + btn / 2;
          const cyg = by + tH / 2;
          const iconPx = 16;
          const trashPathD =
              'M3 6 H21 '
              + 'M8 6 V4 a2 2 0 0 1 2 -2 h4 a2 2 0 0 1 2 2 v2 '
              + 'M19 6 l-1 14 a2 2 0 0 1 -2 2 H8 a2 2 0 0 1 -2 -2 L5 6';
          ctx.save();
          ctx.translate(cxg - iconPx / 2, cyg - iconPx / 2);
          ctx.scale(iconPx / 24, iconPx / 24);
          ctx.strokeStyle = tbIcon;
          ctx.lineWidth = 1.5;
          ctx.lineCap = 'round';
          ctx.lineJoin = 'round';
          ctx.stroke(new Path2D(trashPathD));
          ctx.restore();
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
            ctx.shadowColor = isLightTb ? 'rgba(15,23,42,0.14)' : 'rgba(0,0,0,0.5)';
            ctx.shadowBlur = isLightTb ? 22 : 12;
            ctx.shadowOffsetY = isLightTb ? 6 : 4;
            ctx.fillStyle = tbBg;
            this._roundedRect(popX, popY, popW, popH, 10);
            ctx.fill();
            ctx.restore();
            ctx.strokeStyle = tbBorder;
            ctx.lineWidth = 1;
            this._roundedRect(popX, popY, popW, popH, 10);
            ctx.stroke();
            for (let i = 0; i < colors.length; i++) {
              const col = i % cols, row = Math.floor(i / cols);
              const cxg = popX + swPad + col * (swSize + swGap);
              const cyg = popY + swPad + row * (swSize + swGap);
              ctx.fillStyle = colors[i];
              this._roundedRect(cxg, cyg, swSize, swSize, 3);
              ctx.fill();
              const isCur = colors[i].toLowerCase() ===
                  (d.color || '').toLowerCase();
              if (isCur) {
                ctx.strokeStyle = isLightTb ? '#111827' : '#FFFFFF';
                ctx.lineWidth = 2;
                this._roundedRect(cxg - 1, cyg - 1, swSize + 2, swSize + 2, 4);
                ctx.stroke();
              } else {
                ctx.strokeStyle = isLightTb ? 'rgba(15,23,42,0.15)' : 'rgba(255,255,255,0.12)';
                ctx.lineWidth = 1;
                this._roundedRect(cxg, cyg, swSize, swSize, 3);
                ctx.stroke();
              }
              this._colorSwatchHits.push({
                rect: { x: cxg, y: cyg, w: swSize, h: swSize },
                color: colors[i],
                drawingId: d.id,
              });
            }
          } else if (this._toolbarPopup.kind === 'stroke') {
            // Vertical 1/2/3/4 px list — matches the chart-style dropdown UI
            // (full-width inverted active row, no inset corners).
            const widths = [1, 2, 3, 4];
            const rowH = 28;
            const popW = 80;
            const padY = 4;
            const popH = widths.length * rowH + padY * 2;
            let popX = this._toolbarPopup.anchorX - 4;
            if (popX + popW > plot.right - 4) popX = plot.right - 4 - popW;
            ctx.save();
            ctx.shadowColor = isLightTb ? 'rgba(15,23,42,0.14)' : 'rgba(0,0,0,0.5)';
            ctx.shadowBlur = isLightTb ? 22 : 12;
            ctx.shadowOffsetY = isLightTb ? 6 : 4;
            ctx.fillStyle = tbBg;
            this._roundedRect(popX, popY, popW, popH, 4);
            ctx.fill();
            ctx.restore();
            ctx.strokeStyle = tbBorder;
            ctx.lineWidth = 1;
            this._roundedRect(popX, popY, popW, popH, 4);
            ctx.stroke();
            const activeRowBg = isLightTb ? '#111827' : '#FFFFFF';
            const activeRowFg = isLightTb ? '#FFFFFF' : '#111827';
            // Clip subsequent row paints to the popup's rounded shape so the
            // full-width active row inherits the popup's outer corner radius.
            ctx.save();
            this._roundedRect(popX, popY, popW, popH, 4);
            ctx.clip();
            for (let i = 0; i < widths.length; i++) {
              const rowY = popY + padY + i * rowH;
              const isCur = widths[i] === dThickness;
              if (isCur) {
                ctx.fillStyle = activeRowBg;
                ctx.fillRect(popX, rowY, popW, rowH);
              }
              // Line preview
              ctx.strokeStyle = isCur ? activeRowFg : tbIcon;
              ctx.lineWidth = widths[i];
              ctx.lineCap = 'round';
              ctx.beginPath();
              ctx.moveTo(popX + 10, rowY + rowH / 2);
              ctx.lineTo(popX + 34, rowY + rowH / 2);
              ctx.stroke();
              // Label
              ctx.fillStyle = isCur ? activeRowFg : tbIcon;
              ctx.font = '600 11px Geist, sans-serif';
              ctx.textBaseline = 'middle';
              ctx.textAlign = 'left';
              ctx.fillText(widths[i] + 'px', popX + 44, rowY + rowH / 2);
              this._drawingHits.push({
                rect: { x: popX, y: rowY, w: popW, h: rowH },
                drawingId: d.id,
                action: 'setThickness',
                thickness: widths[i],
              });
            }
            ctx.restore();
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
