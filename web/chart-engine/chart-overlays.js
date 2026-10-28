'use strict';

// ---------------------------------------------------------------------------
// chart-overlays.js — overlays, key levels, H/L, volume profile — split out of chart.js. Methods are authored verbatim inside a
// throwaway mixin class (keeps class-method syntax, no edits) and copied onto
// Chart.prototype at load. Loaded AFTER chart.js. Behaviour identical.
// ---------------------------------------------------------------------------
class _ChartOverlaysMixin {
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
      // Off-screen orders are NOT shown as a clamped chip floating at the top/
      // bottom edge — skip them so a line/chip appears only when its price is
      // actually in view. Scroll to the level to see (and act on) the order.
      if (effectivePrice < lo || effectivePrice > hi) continue;
      const y = priceToY(effectivePrice);
      placements.push({ ov, y, onScreen: true, effectivePrice });
    }
    // Sort by y so vertical-stack collision logic is deterministic.
    placements.sort((a, b) => a.y - b.y);

    // Resolve label-chip vertical overlaps greedily. Seed at the plot top (NOT
    // below the header) so a chip whose line sits near the top still renders ON
    // its line instead of floating down into open space below the OHLC strip.
    // Only genuine chip-to-chip overlaps are nudged; the line is always drawn
    // at the true price `y`.
    let prevBottom = plot.top;
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
      // Remember chip geometry so the parent/child connector pass (below) can
      // link paired lines (e.g. an SL-LMT's trigger + limit chips).
      p.chipLeft = chipLeft;
      p.chipW = chipW;
      p.color = color;
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

      // Also let users click on — and DRAG — the line itself, both sides of the
      // chip. The grab band is thin (6px) for a mouse, but finger-sized on touch
      // (window.__chartTouch, set by mobile_touch.js): a 6px band is impossible
      // to hit with a finger, so a touch-drag missed the line and PANNED the
      // chart instead ("can't drag the line to modify"). Wider band = grabbable.
      if (onScreen) {
        const lineBandH = window.__chartTouch ? 24 : 6;
        const lineBandY = y - lineBandH / 2;
        if (chipLeft > plot.left + 6) {
          this._overlayHits.push({
            rect: { x: plot.left, y: lineBandY,
                    w: chipLeft - plot.left, h: lineBandH },
            action: 'open', overlayId: ov.id,
          });
        }
        const rightStart = chipLeft + chipW;
        if (rightStart < plot.right - 6) {
          this._overlayHits.push({
            rect: { x: rightStart, y: lineBandY,
                    w: plot.right - rightStart, h: lineBandH },
            action: 'open', overlayId: ov.id,
          });
        }
      }
    }

    // Connector: link a child overlay to its parent (e.g. an SL-LMT's limit
    // line to its trigger line) with a thin vertical bracket on the LEFT of
    // their two chips, so the pair reads as one order rather than two
    // unrelated lines.
    if (placements.length >= 2) {
      const byId = new Map();
      for (const p of placements) byId.set(p.ov.id, p);
      for (const p of placements) {
        const parent = p.ov.parentId ? byId.get(p.ov.parentId) : null;
        if (!parent) continue;
        if (!Number.isFinite(p.chipY) || !Number.isFinite(parent.chipY)) continue;
        if (p.chipLeft == null || parent.chipLeft == null) continue;
        const x = Math.min(p.chipLeft, parent.chipLeft) - 4;
        ctx.strokeStyle = p.color || this._overlayLineColor(p.ov);
        ctx.lineWidth = 1.5;
        ctx.setLineDash([]);
        ctx.beginPath();
        ctx.moveTo(x, p.chipY);
        ctx.lineTo(x, parent.chipY);
        ctx.moveTo(x, p.chipY);
        ctx.lineTo(p.chipLeft, p.chipY);
        ctx.moveTo(x, parent.chipY);
        ctx.lineTo(parent.chipLeft, parent.chipY);
        ctx.stroke();
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
          // The price pills fill the right gutter (plot.right + 2 → canvas
          // edge), so a bar "past" them falls off-canvas — which is why the
          // old plot.right + 72 was never visible. Sit the bar INSIDE the plot's
          // right edge with legs reaching out to the pills' left edge. Pulled in
          // ~18px so the bracket is clearly visible and not crushed against the
          // price axis.
          const barX = plot.right - 18;
          const legEndX = plot.right + 2; // left edge of the price pills
          ctx.strokeStyle = this.palette.axisText;
          ctx.lineWidth = 1;
          ctx.setLineDash([]);
          // Vertical bar.
          ctx.beginPath();
          ctx.moveTo(barX, minY);
          ctx.lineTo(barX, maxY);
          ctx.stroke();
          // Horizontal legs from the bar out to each chip.
          for (const y of ys) {
            ctx.beginPath();
            ctx.moveTo(barX, y);
            ctx.lineTo(legEndX, y);
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
  _overlayLineColor(ov) {
    if (ov.kind === 'alert') return '#F59E0B';
    // Deeper violet so the right-axis price chip's white text stays readable
    // (the previous #A78BFA was too light — text-on-chip contrast washed out).
    if (ov.kind === 'optionStrike') return '#8B5CF6';
    // OCO bracket legs are coloured by ROLE (not side): the target reads GREEN
    // (profit-taking exit) and the stop reads RED, regardless of long/short — so
    // the two legs are never the same colour (by-side made both red on a long).
    if (ov.kind === 'ocoTp' || ov.kind === 'tp') return this.palette.bull;
    if (ov.kind === 'ocoSl') return this.palette.short;
    // Every OTHER tradable line by its ORDER SIDE — buy = long/blue, sell =
    // short/red. A buy order (e.g. an SL covering a short position) must read
    // blue, not red; for those the TP/SL role is shown by the label + dash style.
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
    if (ov.kind === 'ocoSl') return [2, 2]; // OCO stop leg: red DOTTED (BRD)
    return [2, 3]; // sl
  }

  _overlayLineWidth(ov) {
    return ov.kind === 'position' ? 1.5 : 1;
  }

  _formatOverlayQty(qty) {
    // Signed — a short / sell shows a leading minus (e.g. "-1250") so the
    // direction is explicit in the label, not only conveyed by colour.
    const n = Math.trunc(qty);
    return (n < 0 ? '-' : '') + Math.abs(n);
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

  // Pivot level formulas. `o` (prior open) is only needed by DeMark. Variant
  // strings match indicator_schema.dart PIVOT option order (classical /
  // fibonacci / camarilla / woodie / demark). DeMark returns only pp/r1/s1.
  _pivotsFor(variant, h, l, c, o) {
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
    if (variant === 'woodie') {
      const wp = (h + l + 2 * c) / 4;
      return {
        pp: wp,
        r1: 2 * wp - l, r2: wp + range, r3: h + 2 * (wp - l),
        s1: 2 * wp - h, s2: wp - range, s3: l - 2 * (h - wp),
      };
    }
    if (variant === 'demark') {
      const open = isFinite(o) ? o : c;
      let x;
      if (c < open) x = h + 2 * l + c;
      else if (c > open) x = 2 * h + l + c;
      else x = h + l + 2 * c;
      return { pp: x / 4, r1: x / 2 - l, s1: x / 2 - h };
    }
    return {
      pp,
      r1: 2 * pp - l, r2: pp + range, r3: h + 2 * (pp - l),
      s1: 2 * pp - h, s2: pp - range, s3: l - 2 * (h - pp),
    };
  }

  // Group this.candles into per-period spans (IST) for the pivot indicator. tf
  // 'weekly' groups Mon–Sun; otherwise per calendar day. Shape
  // { startIdx, endIdx, o, h, l, c } — `o` is carried for DeMark.
  _pivotSpans(tf) {
    const bars = this.candles;
    const spans = [];
    if (!bars || bars.length === 0) return spans;
    const DAY_MS = 86400000;
    const keyFn = (tf === 'weekly')
      ? (tsSec) => {
          const d = new Date((tsSec + 19800) * 1000);
          const mid = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
          const isoDow = (new Date(mid).getUTCDay() + 6) % 7; // Mon=0
          return String(mid - isoDow * DAY_MS);
        }
      : (tsSec) => {
          const d = new Date((tsSec + 19800) * 1000);
          return d.getUTCFullYear() + '-' +
              String(d.getUTCMonth() + 1).padStart(2, '0') + '-' +
              String(d.getUTCDate()).padStart(2, '0');
        };
    let cur = null;
    for (let i = 0; i < bars.length; i++) {
      const k = keyFn(bars[i].ts);
      if (cur && k === cur.key) {
        cur.endIdx = i;
        if (bars[i].h > cur.h) cur.h = bars[i].h;
        if (bars[i].l < cur.l) cur.l = bars[i].l;
        cur.c = bars[i].c;
      } else {
        if (cur) spans.push(cur);
        cur = {
          key: k, startIdx: i, endIdx: i,
          o: bars[i].o, h: bars[i].h, l: bars[i].l, c: bars[i].c,
        };
      }
    }
    if (cur) spans.push(cur);
    return spans;
  }

  // Pivot Points overlay indicator (fx menu). Each period's levels come from
  // the PRIOR period's OHLC. variant/timeframe/labels/prices from ind.params
  // (index order matches indicator_schema.dart). Single color = ind.color,
  // width = ind.thickness. Called from _drawIndicators.
  _drawPivotsIndicator(ind, plot, lo, hi, priceToY) {
    const p = ind.params || {};
    const variant = ['classical', 'fibonacci', 'camarilla', 'woodie', 'demark'][(+p.variant | 0)] || 'classical';
    const tf = ['daily', 'weekly'][(+p.pivotTimeframe | 0)] || 'daily';
    const showLabels = p.showLabels == null ? true : (+p.showLabels >= 1);
    const showPrices = p.showPrices == null ? true : (+p.showPrices >= 1);
    const spans = this._pivotSpans(tf);
    if (spans.length < 2) return;
    const color = ind.color || '#F59E0B';
    const width = (ind.thickness && ind.thickness > 0) ? ind.thickness : 1;
    const tag = variant === 'fibonacci' ? 'F' : variant === 'camarilla' ? 'C'
        : variant === 'woodie' ? 'W' : variant === 'demark' ? 'D' : '';
    const labels = {
      r3: tag + 'R3', r2: tag + 'R2', r1: tag + 'R1',
      pp: tag ? tag + 'P' : 'PP',
      s1: tag + 'S1', s2: tag + 'S2', s3: tag + 'S3',
    };
    const order = ['r3', 'r2', 'r1', 'pp', 's1', 's2', 's3'];
    const dp = this._priceDecimals();
    const ctx = this.ctx;
    ctx.save();
    ctx.font = '600 9px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.setLineDash([4, 4]);
    ctx.lineWidth = width;
    ctx.strokeStyle = color;
    ctx.fillStyle = color;
    for (let s = 1; s < spans.length; s++) {
      const prev = spans[s - 1];
      const cur = spans[s];
      const kl = this._pivotsFor(variant, prev.h, prev.l, prev.c, prev.o);
      if (!kl) continue;
      const xLeft = this._candleXCenter(cur.startIdx, plot) - this.view.cellW / 2;
      const xRight = this._candleXCenter(cur.endIdx, plot) + this.view.cellW / 2;
      if (xRight < plot.left || xLeft > plot.right) continue;
      const x0 = Math.max(plot.left, xLeft);
      const x1 = Math.min(plot.right - 4, xRight);
      if (x1 <= x0) continue;
      for (const k of order) {
        const val = kl[k];
        if (val == null || !isFinite(val) || val < lo || val > hi) continue;
        const y = priceToY(val);
        ctx.beginPath();
        ctx.moveTo(x0, y);
        ctx.lineTo(x1, y);
        ctx.stroke();
        if (showLabels || showPrices) {
          let txt = showLabels ? labels[k] : '';
          if (showPrices) txt += (txt ? ' ' : '') + val.toFixed(dp);
          if (txt) ctx.fillText(txt, x0 + 4, y - 6);
        }
      }
    }
    ctx.setLineDash([]);
    ctx.restore();
  }

  // ── CPR with Pivot Level Daily ──────────────────────────────────────────
  // Previous-day levels come from OFFICIAL daily bars (the EOD endpoint, as
  // TradingView's version used), not from this chart's intraday candles —
  // NSE's official close is not the last trade. Fetched once per symbol per
  // IST day through the normal history request (interval '1D'); the reply is
  // routed by its own request id in onHistoryResult.
  // Calendar days of daily bars the active indicators need: CPR 60 (30 days of
  // levels plus the day before), the Trend Checkers 520 (the monthly ATR phase
  // averages 14 full months, with a partial month dropped at the start).
  // 0 = none.
  _levelsDailyDays() {
    let need = 0;
    for (const i of this._indicators) {
      if (i.kind === 'cpr') need = Math.max(need, 60);
      else if (i.kind === 'tcheck' || i.kind === 'ftcheck') need = Math.max(need, 520);
    }
    return need;
  }

  // 1 once the session has closed (plus a few minutes for the official close
  // to settle), else 0 — the daily bars are fetched again then, so today's
  // bar carries the official close.
  _levelsPhase(nowSec) {
    const b = _sessionBoundsFor(this.scrip.exch, nowSec);
    if (b.closeMin == null) return 0;
    return _istParts(nowSec).minuteOfDay >= b.closeMin + 5 ? 1 : 0;
  }

  _ensureCprDaily() {
    if (!this.scrip) return;
    const need = this._levelsDailyDays();
    if (!need) return;
    const key = this.scrip.exch + '|' + this.scrip.token;
    const nowSec = Math.floor(Date.now() / 1000);
    const today = _cprIstDay(nowSec);
    const d = this._cprDaily;
    const phase = this._levelsPhase(nowSec);
    if (d && d.key === key && d.day === today && (d.days || 60) >= need
        && (d.phase || 0) >= phase) return;
    if (this._pendingCprDailyId && this._pendingCprDailyKey === key) return;
    if (this._cprDailyRetryKey === key && Date.now() < this._cprDailyRetryAt) return;
    this._pendingCprDailyId = _newRequestId();
    this._pendingCprDailyKey = key;
    this._pendingCprDailyDays = need;
    this.requestHistory({
      requestId: this._pendingCprDailyId,
      exch: this.scrip.exch,
      token: this.scrip.token,
      tsym: this.scrip.tsym,
      interval: '1D',
      // 30 days of levels need the trading day before the oldest of them —
      // 60 calendar days covers weekends and long holiday runs.
      start: nowSec - need * 86400,
      end: nowSec,
      targetMinutes: 1440,
    });
  }

  _onCprDailyResult(candles) {
    const key = this._pendingCprDailyKey;
    this._pendingCprDailyId = null;
    this._pendingCprDailyKey = null;
    const bars = Array.isArray(candles)
        ? candles.filter((c) => c && isFinite(c.ts) && isFinite(c.h) && isFinite(c.l) && isFinite(c.c))
        : [];
    const nowSec = Math.floor(Date.now() / 1000);
    const phase = this.scrip ? this._levelsPhase(nowSec) : 0;
    this._cprDaily = { key, day: _cprIstDay(nowSec), stamp: Date.now(), bars,
        days: this._pendingCprDailyDays || 60, phase, afterClose: phase === 1 };
    this._cprCache = null;
    this._tcCache = null;
    this._gpCache = null;
    this.scheduleRedraw();
  }

  _onCprDailyError() {
    this._cprDailyRetryKey = this._pendingCprDailyKey;
    this._cprDailyRetryAt = Date.now() + 60000;
    this._pendingCprDailyId = null;
    this._pendingCprDailyKey = null;
  }

  // Level series aligned to this.candles (which is the renko / rebinned
  // stand-in while indicators draw). Cached until the bars or daily data change.
  _cprSeries() {
    const bars = this.candles;
    const d = this._cprDaily;
    const scripKey = this.scrip ? this.scrip.exch + '|' + this.scrip.token : '';
    const daily = (d && d.key === scripKey) ? d.bars : null;
    const key = bars.length + '|' + (bars.length ? bars[0].ts + ':' + bars[bars.length - 1].ts : '')
        + '|' + (daily ? d.stamp : 0);
    const c = this._cprCache;
    if (c && c.key === key && c.bars === bars) return c.series;
    const series = computeCprSeries(bars, daily, Date.now());
    this._cprCache = { key, bars, series };
    return series;
  }

  // Visible levels at the newest bar, in the study's plot order and its own
  // precision — the legend's values (TradingView's status line).
  _cprLegendValues(ind) {
    if (!this.candles.length) return [];
    const series = this._cprSeries();
    const params = ind.params || {};
    const dp = cprDecimals(params);
    const i = this.candles.length - 1;
    const out = [];
    for (const pl of CPR_PLOTS) {
      const v = series[pl.key][i];
      const st = cprPlotStyle(params, pl);
      if (st.visible && isFinite(v)) out.push({ v, color: st.color, dp });
    }
    return out;
  }

  // Widen a candle-fit price range by the visible CPR levels over the visible
  // candles, so autoscale keeps them on screen (TradingView's autoscale
  // includes study plots).
  _cprFitRange(visible, lo, hi) {
    const uses = (i) => (i.kind === 'cpr' || i.kind === 'tcheck' || i.kind === 'ftcheck') && !i.hidden;
    if (!visible.length || !this._indicators.some(uses)) {
      return { lo, hi };
    }
    const a = this.candles.indexOf(visible[0]);
    if (a < 0) return { lo, hi };
    const b = a + visible.length - 1;
    for (const ind of this._indicators) {
      if (!uses(ind)) continue;
      const r = ind.kind === 'cpr' ? this._cprRange(ind, a, b)
          : ind.kind === 'ftcheck' ? this._ftRange(ind, a, b) : this._tcRange(ind, a, b);
      if (r) { if (r.lo < lo) lo = r.lo; if (r.hi > hi) hi = r.hi; }
    }
    return { lo, hi };
  }

  // Newest finite value of a plot (today's level) — drives the price line and
  // the price-axis label, as TradingView's last-value label does.
  _cprLastValue(vals) {
    for (let i = vals.length - 1; i >= 0; i--) {
      if (isFinite(vals[i])) return vals[i];
    }
    return NaN;
  }

  // Min/max of the VISIBLE plots over candles [a..b], so autoscale keeps them
  // on screen (TradingView's autoscale includes study plots).
  _cprRange(ind, a, b) {
    const series = this._cprSeries();
    const params = ind.params || {};
    let lo = Infinity, hi = -Infinity;
    for (const pl of CPR_PLOTS) {
      if (!cprPlotStyle(params, pl).visible) continue;
      const vals = series[pl.key];
      for (let i = Math.max(0, a); i <= b && i < vals.length; i++) {
        const v = vals[i];
        if (!isFinite(v)) continue;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    }
    return hi === -Infinity ? null : { lo, hi };
  }

  _drawCprIndicator(ind, plot, lo, hi, priceToY, firstAbs, lastAbs) {
    this._ensureCprDaily();
    const n = this.candles.length;
    if (!n) return;
    const series = this._cprSeries();
    const params = ind.params || {};
    const dp = cprDecimals(params);
    const i0 = Math.max(0, firstAbs - 1);
    const i1 = Math.min(n - 1, lastAbs + 1);
    // Histogram / columns / area fill down to the study's histogramBase (1).
    const baseY = Math.min(plot.bottom, Math.max(plot.top, priceToY(1)));
    const ctx = this.ctx;
    const labels = [];
    ctx.save();
    ctx.beginPath();
    ctx.rect(plot.left, plot.top, plot.right - plot.left, plot.bottom - plot.top);
    ctx.clip();
    for (const pl of CPR_PLOTS) {
      const st = cprPlotStyle(params, pl);
      if (!st.visible) continue;
      const vals = series[pl.key];
      this._drawCprPlot(vals, i0, i1, st, plot, priceToY, baseY);
      const last = this._cprLastValue(vals);
      if (!isFinite(last)) continue;
      if (st.priceLine && last >= lo && last <= hi) {
        const y = Math.round(priceToY(last)) + 0.5;
        ctx.save();
        ctx.strokeStyle = st.color;
        ctx.lineWidth = 1;
        ctx.setLineDash([2, 2]);
        ctx.beginPath();
        ctx.moveTo(plot.left, y);
        ctx.lineTo(plot.right, y);
        ctx.stroke();
        ctx.restore();
      }
      labels.push({ v: last, color: st.color });
    }
    ctx.restore();
    // Price-axis labels sit outside the plot clip. Highest first, each pushed
    // below the previous one, so levels a few paise apart stay in price order.
    labels.sort((a, b) => b.v - a.v);
    let prevY = null;
    for (const lb of labels) {
      let y = priceToY(lb.v);
      if (prevY != null && y < prevY + 18) y = prevY + 18;
      const drawn = this._drawIndicatorAxisChip(plot, priceToY, lb.v, lb.color, dp, y);
      if (drawn != null) prevY = drawn;
    }
  }

  // One plot in one of TradingView's plot types. Lines bridge missing values
  // unless the type is "with breaks"; markers draw at every bar centre.
  _drawCprPlot(vals, i0, i1, st, plot, priceToY, baseY) {
    const ctx = this.ctx;
    const w = st.width;
    const t = st.plotType;
    const X = (i) => this._candleXCenter(i, plot);
    ctx.save();
    ctx.strokeStyle = st.color;
    ctx.fillStyle = st.color;
    ctx.lineWidth = w;
    ctx.lineJoin = 'round';
    if (t === 'circles') {
      const r = Math.max(1, w * 0.9);
      for (let i = i0; i <= i1; i++) {
        const v = vals[i];
        if (!isFinite(v)) continue;
        ctx.beginPath();
        ctx.arc(X(i), priceToY(v), r, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
      return;
    }
    if (t === 'cross') {
      const a = w + 2;
      ctx.lineWidth = Math.max(1, w / 2);
      ctx.beginPath();
      for (let i = i0; i <= i1; i++) {
        const v = vals[i];
        if (!isFinite(v)) continue;
        const x = X(i), y = priceToY(v);
        ctx.moveTo(x - a, y); ctx.lineTo(x + a, y);
        ctx.moveTo(x, y - a); ctx.lineTo(x, y + a);
      }
      ctx.stroke();
      ctx.restore();
      return;
    }
    if (t === 'histogram') {
      ctx.beginPath();
      for (let i = i0; i <= i1; i++) {
        const v = vals[i];
        if (!isFinite(v)) continue;
        const x = X(i);
        ctx.moveTo(x, baseY); ctx.lineTo(x, priceToY(v));
      }
      ctx.stroke();
      ctx.restore();
      return;
    }
    if (t === 'columns') {
      const bw = Math.max(1, this.view.cellW * 0.6);
      ctx.globalAlpha = 0.5;
      for (let i = i0; i <= i1; i++) {
        const v = vals[i];
        if (!isFinite(v)) continue;
        const y = priceToY(v);
        ctx.fillRect(X(i) - bw / 2, Math.min(y, baseY), bw, Math.abs(baseY - y));
      }
      ctx.restore();
      return;
    }
    // Line family: line, linebr, step, stepbr, stepdiamond, area, areabr.
    const breaks = t === 'linebr' || t === 'stepbr' || t === 'areabr';
    const step = t === 'step' || t === 'stepbr' || t === 'stepdiamond';
    const area = t === 'area' || t === 'areabr';
    // Runs of connected points (a run ends at a missing value only with breaks).
    const runs = [];
    let run = null;
    for (let i = i0; i <= i1; i++) {
      const v = vals[i];
      if (!isFinite(v)) {
        if (breaks && run) { runs.push(run); run = null; }
        continue;
      }
      if (!run) run = [];
      run.push({ x: X(i), y: priceToY(v), v });
    }
    if (run) runs.push(run);
    const trace = (pts) => {
      ctx.moveTo(pts[0].x, pts[0].y);
      for (let k = 1; k < pts.length; k++) {
        if (step) ctx.lineTo(pts[k].x, pts[k - 1].y);
        ctx.lineTo(pts[k].x, pts[k].y);
      }
    };
    if (area) {
      ctx.globalAlpha = 0.18;
      for (const pts of runs) {
        ctx.beginPath();
        trace(pts);
        ctx.lineTo(pts[pts.length - 1].x, baseY);
        ctx.lineTo(pts[0].x, baseY);
        ctx.closePath();
        ctx.fill();
      }
      ctx.globalAlpha = 1;
    }
    ctx.setLineDash(st.lineStyle === 'dotted' ? [w, w * 1.6]
        : st.lineStyle === 'dashed' ? [w * 4, w * 2.5] : []);
    for (const pts of runs) {
      ctx.beginPath();
      if (pts.length === 1) {
        // A lone point still shows (a 1-bar run), as a short tick.
        ctx.moveTo(pts[0].x - w, pts[0].y);
        ctx.lineTo(pts[0].x + w, pts[0].y);
      } else {
        trace(pts);
      }
      ctx.stroke();
    }
    if (t === 'stepdiamond') {
      ctx.setLineDash([]);
      const a = w + 2;
      for (const pts of runs) {
        for (let k = 0; k < pts.length; k++) {
          if (k > 0 && pts[k].v === pts[k - 1].v) continue;
          const p = pts[k];
          ctx.beginPath();
          ctx.moveTo(p.x, p.y - a); ctx.lineTo(p.x + a, p.y);
          ctx.lineTo(p.x, p.y + a); ctx.lineTo(p.x - a, p.y);
          ctx.closePath();
          ctx.fill();
        }
      }
    }
    ctx.restore();
  }

  // ── CPR Trend Checker (CPR + MAs) ───────────────────────────────────────
  // Levels come from the previous day / week / month of the OFFICIAL daily
  // bars (shared with the CPR indicator's fetch, see _ensureCprDaily). Lines
  // are drawn one segment per period, so a level never joins the next
  // period's. Moving averages run on the chart's own candles.

  // Level series aligned to this.candles (the renko / rebinned stand-in while
  // indicators draw). Cached until the bars or the daily data change.
  _tcSeries() {
    const bars = this.candles;
    const d = this._cprDaily;
    const scripKey = this.scrip ? this.scrip.exch + '|' + this.scrip.token : '';
    const daily = (d && d.key === scripKey) ? d.bars : null;
    const key = bars.length + '|' + (bars.length ? bars[0].ts + ':' + bars[bars.length - 1].ts : '')
        + '|' + (daily ? d.stamp : 0);
    const c = this._tcCache;
    if (c && c.key === key && c.bars === bars) return c.series;
    const series = computeTcSeries(bars, daily);
    this._tcCache = { key, bars, series };
    return series;
  }

  // Moving averages of one indicator, cached per settings and bar set.
  _tcMaSeries(ind) {
    const bars = this.candles;
    const out = [];
    if (!bars.length) return out;
    const last = bars[bars.length - 1];
    this._tcMaCache = this._tcMaCache || {};
    for (let i = 1; i <= 5; i++) {
      const cfg = tcMaConfig(ind.params, i);
      if (!cfg.on) continue;
      const typeIdx = TC_MA_TYPES.indexOf(cfg.type), srcIdx = TC_MA_SOURCES.indexOf(cfg.src);
      const key = ind.id + ':' + i + ':' + typeIdx + ':' + srcIdx + ':' + cfg.len + ':' +
          bars.length + ':' + bars[0].ts + ':' + last.ts + ':' + last.c + ':' + last.v;
      let hit = this._tcMaCache[ind.id + ':' + i];
      if (!hit || hit.key !== key) {
        hit = { key, vals: tcMa(bars, typeIdx, srcIdx, cfg.len) };
        this._tcMaCache[ind.id + ':' + i] = hit;
      }
      out.push({ i, cfg, vals: hit.vals });
    }
    return out;
  }

  // The level lines currently shown: group switch on AND the line's own
  // visibility on, with the values series for each.
  _tcShownLines(ind) {
    const groups = tcActiveGroups(ind.params, this.timeframeMinutes);
    const series = this._tcSeries();
    const out = [];
    for (const line of TC_LINES) {
      const g = groups[line.group];
      if (!(line.sw === 'hl' ? g.hl : g.cpr)) continue;
      const st = tcLineStyle(ind.params, line);
      if (!st.visible) continue;
      out.push({ line, st, vals: series[line.group][line.field], seg: series[line.group].seg });
    }
    return out;
  }

  // Legend values at the newest bar, in the study's order: the levels, then
  // the moving averages. A line whose own colour is fully transparent still
  // shows its value (BC and TC are transparent by default).
  _tcLegendValues(ind) {
    const p = ind.params || {};
    if (typeof p.statusOn === 'number' && p.statusOn < 1) return [];
    if (!this.candles.length) return [];
    const i = this.candles.length - 1;
    const dp = cprDecimals(p);
    const out = [];
    for (const s of this._tcShownLines(ind)) {
      const v = s.vals[i];
      if (isFinite(v)) out.push({ v, color: s.st.color, dp });
    }
    for (const m of this._tcMaSeries(ind)) {
      const v = m.vals[i];
      if (isFinite(v)) out.push({ v, color: m.cfg.color, dp });
    }
    return out;
  }

  // The inputs shown beside the name when "inputs in status line" is on:
  // each moving average that is switched on, e.g. "SMA 10".
  _tcInputsLabel(ind) {
    const p = ind.params || {};
    if (typeof p.inputsOn === 'number' && p.inputsOn < 1) return '';
    const parts = [];
    for (let i = 1; i <= 5; i++) {
      const c = tcMaConfig(p, i);
      if (c.on) parts.push(c.type + ' ' + c.len);
    }
    return parts.join(' ');
  }

  // Min / max over candles [a..b] of everything shown, so autoscale keeps the
  // levels and averages on screen (TradingView's autoscale includes them).
  _tcRange(ind, a, b) {
    let lo = Infinity, hi = -Infinity;
    const eat = (vals) => {
      for (let i = Math.max(0, a); i <= b && i < vals.length; i++) {
        const v = vals[i];
        if (!isFinite(v)) continue;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    };
    for (const s of this._tcShownLines(ind)) eat(s.vals);
    for (const m of this._tcMaSeries(ind)) eat(m.vals);
    return hi === -Infinity ? null : { lo, hi };
  }

  _drawTcheckIndicator(ind, plot, lo, hi, priceToY, firstAbs, lastAbs) {
    this._ensureCprDaily();
    const n = this.candles.length;
    if (!n) return;
    const p = ind.params || {};
    const i0 = Math.max(0, firstAbs - 1);
    const i1 = Math.min(n - 1, lastAbs + 1);
    const dp = cprDecimals(p);
    const ctx = this.ctx;
    const X = (i) => this._candleXCenter(i, plot);
    const baseY = Math.min(plot.bottom, Math.max(plot.top, priceToY(1)));
    const series = this._tcSeries();
    const groups = tcActiveGroups(p, this.timeframeMinutes);
    const shown = this._tcShownLines(ind);
    // One [start, end] candle range per period within the visible slice.
    const segsOf = (seg) => {
      const out = [];
      let s = i0;
      for (let i = i0 + 1; i <= i1 + 1; i++) {
        if (i > i1 || seg[i] !== seg[s]) { out.push([s, i - 1]); s = i; }
      }
      return out;
    };
    ctx.save();
    ctx.beginPath();
    ctx.rect(plot.left, plot.top, plot.right - plot.left, plot.bottom - plot.top);
    ctx.clip();

    // 1. CPR bands (BC..TC), one rectangle per period, under the lines.
    for (const band of TC_BANDS) {
      if (!groups[band.group].cpr) continue;
      const bs = tcBandStyle(p, band);
      if (!bs.visible || bs.alpha <= 0) continue;
      const o = series[band.group];
      ctx.fillStyle = bs.css;
      for (const [a, z] of segsOf(o.seg)) {
        const top = o.tc[a], bot = o.bc[a];
        if (!isFinite(top) || !isFinite(bot)) continue;
        const x0 = X(a) - this.view.cellW / 2, x1 = X(z) + this.view.cellW / 2;
        const y0 = priceToY(Math.max(top, bot)), y1 = priceToY(Math.min(top, bot));
        ctx.fillRect(x0, y0, x1 - x0, Math.max(1, y1 - y0));
      }
    }

    // 2. Level lines, one segment per period. A fully transparent line draws
    // nothing (its value still shows in the legend and on the price scale).
    for (const s of shown) {
      if (s.st.alpha <= 0) continue;
      const st = Object.assign({}, s.st, { color: s.st.css });
      for (const [a, z] of segsOf(s.seg)) {
        if (!isFinite(s.vals[a])) continue;
        this._drawCprPlot(s.vals, a, z, st, plot, priceToY, baseY);
      }
    }

    // 3. Moving averages on top.
    const mas = this._tcMaSeries(ind);
    for (const m of mas) {
      ctx.save();
      ctx.strokeStyle = m.cfg.color;
      ctx.lineWidth = m.cfg.width;
      ctx.lineJoin = 'round';
      ctx.beginPath();
      let on = false;
      for (let i = i0; i <= i1; i++) {
        const v = m.vals[i];
        if (!isFinite(v)) { on = false; continue; }
        if (!on) { ctx.moveTo(X(i), priceToY(v)); on = true; } else ctx.lineTo(X(i), priceToY(v));
      }
      ctx.stroke();
      ctx.restore();
    }

    // 4. Pane labels just right of the newest bar (room is made by _futureBars).
    if (!(typeof p.labelsOn === 'number' && p.labelsOn < 1)) {
      ctx.font = '600 9px Geist, sans-serif';
      ctx.textBaseline = 'middle';
      // Room right of the newest bar exists only where the engine reserves it
      // (_futureBars); otherwise the labels sit against the plot's right edge.
      const room = typeof this._futureBars === 'function';
      ctx.textAlign = room ? 'left' : 'right';
      const lx = room ? X(n - 1) + this.view.cellW * 1.4 : plot.right - 4;
      for (const s of shown) {
        if (!s.line.label) continue;
        const v = s.vals[n - 1];
        if (!isFinite(v) || v < lo || v > hi) continue;
        ctx.fillStyle = s.st.color;
        ctx.fillText(s.line.label, lx, priceToY(v));
      }
    }
    ctx.restore();

    // Tags, Virgin CPR zones, the CPR summary and the Market Pulse table.
    this._drawTcExtras(ind, plot, lo, hi, priceToY, i0, i1, segsOf, series, groups);

    // 5. Price-scale labels, highest first and each pushed below the previous
    // one so levels a few points apart stay in price order.
    if (!(typeof p.axisOn === 'number' && p.axisOn < 1)) {
      const chips = [];
      for (const s of shown) {
        const v = s.vals[n - 1];
        if (isFinite(v)) chips.push({ v, color: s.st.color });
      }
      for (const m of mas) {
        const v = m.vals[n - 1];
        if (isFinite(v)) chips.push({ v, color: m.cfg.color });
      }
      chips.sort((a, b) => b.v - a.v);
      let prevY = null;
      for (const c of chips) {
        let y = priceToY(c.v);
        if (prevY != null && y < prevY + 18) y = prevY + 18;
        const drawn = this._drawIndicatorAxisChip(plot, priceToY, c.v, c.color, dp, y);
        if (drawn != null) prevY = drawn;
      }
    }
  }


  // ── Trend Checker analytics + Future Trend Checker ──────────────────────
  // CPR type / width / ATR phase per period (gpAnalyse on the official daily
  // bars), drawn as Trend Checker's tags, Virgin CPR zones, the summary under
  // the pivot label and the Market Pulse table; Future Trend Checker projects
  // the NEXT period's CPR from the current one and shows its trend table.

  // Analysis per group, cached per daily data and the settings it reads.
  _gpAnalysis(params) {
    const d = this._cprDaily;
    const scripKey = this.scrip ? this.scrip.exch + '|' + this.scrip.token : '';
    const daily = (d && d.key === scripKey) ? d.bars : null;
    if (!daily) return null;
    const p = params || {};
    const keys = ['atrLen', 'atrAvg', 'atrInc', 'atrLo', 'atrHi', 'dUn', 'dN', 'dM',
      'wUn', 'wN', 'wM', 'mUn', 'mN', 'mM'];
    const key = d.stamp + '|' + keys.map((k) => p[k]).join(',');
    this._gpCache = this._gpCache || {};
    const hit = this._gpCache[key];
    if (hit) return hit;
    const a = gpAnalyse(daily, p);
    this._gpCache = { [key]: a };
    return a;
  }

  // Black lines and text are invisible on the dark theme: draw them in the
  // axis text colour there instead.
  _gpInk(color) {
    if (color !== '#000000') return color;
    const bg = (this.palette && this.palette.bg) || '#FFFFFF';
    const m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/i.exec(bg);
    const dark = m && (parseInt(m[1], 16) + parseInt(m[2], 16) + parseInt(m[3], 16)) < 3 * 96;
    return dark ? ((this.palette && this.palette.axisText) || '#D1D4DC') : color;
  }

  // Table in a corner of the plot. rows: arrays of { t, bg, fg, bold }; the
  // first row is the header. Positions: 0 top right, 1 top left, 2 bottom
  // right, 3 bottom left, 4 middle right. size: 0 tiny, 1 small, 2 normal.
  _gpTable(plot, rows, pos, size, title) {
    if (!rows.length) return;
    const ctx = this.ctx;
    const fs = [8, 9.5, 11][Math.max(0, Math.min(2, size | 0))];
    const rowH = Math.round(fs * 1.75);
    const padX = Math.round(fs * 0.6);
    ctx.save();
    ctx.font = '500 ' + fs + 'px Geist, sans-serif';
    const cols = rows.reduce((m, r) => Math.max(m, r.length), 0);
    const colW = new Array(cols).fill(0);
    for (const r of rows) {
      r.forEach((c, k) => {
        ctx.font = (c.bold ? '700 ' : '500 ') + fs + 'px Geist, sans-serif';
        colW[k] = Math.max(colW[k], ctx.measureText(c.t || '').width + padX * 2);
      });
    }
    const tableW = colW.reduce((s, w) => s + w, 0);
    const titleH = title ? rowH : 0;
    const tableH = titleH + rows.length * rowH;
    const m = 8;
    const p = pos | 0;
    const x0 = (p === 1 || p === 3) ? plot.left + m : plot.right - m - tableW;
    // Top positions start below the chart's status badges ("Market closed").
    const y0 = p === 4 ? (plot.top + plot.bottom - tableH) / 2
        : (p === 2 || p === 3) ? plot.bottom - m - tableH : plot.top + m + 18;
    ctx.textBaseline = 'middle';
    if (title) {
      ctx.fillStyle = '#E8E8E8';
      ctx.fillRect(x0, y0, tableW, rowH);
      ctx.fillStyle = '#131722';
      ctx.font = '600 ' + fs + 'px Geist, sans-serif';
      ctx.textAlign = 'left';
      ctx.fillText(title, x0 + padX, y0 + rowH / 2);
    }
    rows.forEach((r, ri) => {
      let x = x0;
      const y = y0 + titleH + ri * rowH;
      r.forEach((c, k) => {
        ctx.fillStyle = c.bg || '#FFFFFF';
        ctx.fillRect(x, y, colW[k], rowH);
        ctx.strokeStyle = 'rgba(0,0,0,0.12)';
        ctx.lineWidth = 1;
        ctx.strokeRect(x + 0.5, y + 0.5, colW[k] - 1, rowH - 1);
        ctx.fillStyle = c.fg || '#131722';
        ctx.font = (c.bold ? '700 ' : '500 ') + fs + 'px Geist, sans-serif';
        ctx.textAlign = k === 0 ? 'left' : 'center';
        ctx.fillText(c.t || '', k === 0 ? x + padX : x + colW[k] / 2, y + rowH / 2);
        x += colW[k];
      });
    });
    ctx.strokeStyle = 'rgba(0,0,0,0.25)';
    ctx.strokeRect(x0 + 0.5, y0 + 0.5, tableW - 1, tableH - 1);
    ctx.restore();
  }

  // Rounded label box (tags, the next CPR's pill). Returns its height.
  _gpPill(x, y, lines, bg, fg, align) {
    const ctx = this.ctx;
    ctx.save();
    ctx.font = '500 9px Geist, sans-serif';
    const w = lines.reduce((m, s) => Math.max(m, ctx.measureText(s).width), 0) + 10;
    const h = lines.length * 11 + 4;
    const x0 = align === 'right' ? x - w : x;
    ctx.fillStyle = bg;
    _roundRectPath(ctx, x0, y, w, h, 3);
    ctx.fill();
    ctx.fillStyle = fg;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    lines.forEach((s, k) => ctx.fillText(s, x0 + 5, y + 3 + k * 11));
    ctx.restore();
    return h;
  }

  // The analysis entry behind each candle of one group, and the period id.
  _gpEntryIndex(list, group, i) {
    return gpEntryFor(list, group, this.candles[i].ts);
  }

  // Trend Checker extras, drawn after its levels: Virgin CPR zones, backtest
  // tags, then the CPR summary and the Market Pulse table.
  _drawTcExtras(ind, plot, lo, hi, priceToY, i0, i1, segsOf, series, groups) {
    const p = ind.params || {};
    const an = this._gpAnalysis(p);
    if (!an) return;
    const ctx = this.ctx;
    const n = this.candles.length;
    const X = (i) => this._candleXCenter(i, plot);
    const half = this.view.cellW / 2;
    const on = (k, def) => (typeof p[k] === 'number' ? p[k] >= 1 : def);
    ctx.save();
    ctx.beginPath();
    ctx.rect(plot.left, plot.top, plot.right - plot.left, plot.bottom - plot.top);
    ctx.clip();
    for (const g of TC_GROUPS) {
      if (!groups[g.id].cpr) continue;
      const list = an[g.id];
      for (const [a, z] of segsOf(series[g.id].seg)) {
        const j = this._gpEntryIndex(list, g.id, a);
        if (j < 0) continue;
        const e = list[j];
        // Virgin CPR: the CPR before this one was never traded through, so it
        // stays a zone for this whole period.
        if (on('virginOn', true) && e.virgin && j > 0) {
          const v = list[j - 1].lv;
          const yTop = priceToY(Math.max(v.bc, v.tc)), yBot = priceToY(Math.min(v.bc, v.tc));
          const x0 = X(a) - half, x1 = X(z) + half;
          const hgt = Math.max(6, yBot - yTop);
          ctx.fillStyle = _tcCss(g.color, 0.14);
          ctx.fillRect(x0, yTop, x1 - x0, hgt);
          ctx.setLineDash([3, 3]);
          ctx.strokeStyle = _tcCss(g.color, 0.6);
          ctx.lineWidth = 1;
          ctx.strokeRect(x0 + 0.5, yTop + 0.5, x1 - x0 - 1, hgt - 1);
          ctx.setLineDash([]);
          ctx.fillStyle = g.color;
          ctx.font = '500 9px Geist, sans-serif';
          ctx.textAlign = 'right';
          ctx.textBaseline = 'middle';
          ctx.fillText('Virgin CPR', x1 - 4, yTop + hgt / 2);
        }
        // Backtest tag at the start of the period.
        if (on('tagOn', false) && isFinite(e.lv.pivot) && e.rel >= 0) {
          const r = GP_RELATIONS[e.rel];
          const ph = GP_PHASES[e.phase];
          const lines = [];
          if ((p.tagStyle | 0) === 1) {
            let s = r.sym + ' ' + r.short;
            if (on('tagW', true)) s += ' · ' + GP_WIDTHS[e.widthClass];
            if (on('tagA', true)) s += ' · ATR ' + ph.arrow;
            lines.push(s);
          } else {
            lines.push(r.sym + ' ' + r.full + (on('tagW', true) ? ' · ' + GP_WIDTHS[e.widthClass] : ''));
            if (on('tagA', true)) lines.push('ATR ' + ph.name);
          }
          const top = Math.max(e.lv.bc, e.lv.tc), bot = Math.min(e.lv.bc, e.lv.tc);
          const pos = p.tagPos | 0;
          const above = pos === 1 || (pos === 0 && this.candles[a].c < e.lv.pivot);
          const h = lines.length * 11 + 4;
          const y = above ? priceToY(top) - h - 4 : priceToY(bot) + 4;
          this._gpPill(X(a) - half + 2, y, lines, 'rgba(255,236,204,0.92)', '#3A2E1A');
        }
      }
    }
    ctx.restore();

    // CPR summary under the newest pivot label: width, ATR phase, CPR type.
    const labelsOn = !(typeof p.labelsOn === 'number' && p.labelsOn < 1);
    if (labelsOn && on('sumOn', true)) {
      const room = typeof this._futureBars === 'function';
      const lx = room ? X(n - 1) + this.view.cellW * 1.4 : plot.right - 4;
      ctx.save();
      ctx.font = '600 9px Geist, sans-serif';
      ctx.textAlign = room ? 'left' : 'right';
      ctx.textBaseline = 'middle';
      for (const g of TC_GROUPS) {
        if (!groups[g.id].cpr) continue;
        const list = an[g.id];
        const j = this._gpEntryIndex(list, g.id, n - 1);
        const v = series[g.id].pivot[n - 1];
        if (j < 0 || !isFinite(v) || v < lo || v > hi) continue;
        const e = list[j];
        const pline = TC_LINES.find((l) => l.key === g.id + 'cpr');
        const st = tcLineStyle(p, pline);
        if (!st.visible) continue;
        const lines = [GP_WIDTHS[e.widthClass] + ' CPR', 'ATR ' + GP_PHASES[e.phase].name];
        if (e.rel >= 0) lines.push(GP_RELATIONS[e.rel].full);
        ctx.fillStyle = st.color;
        lines.forEach((s, k) => ctx.fillText(s, lx, priceToY(v) + 10 * (k + 1)));
      }
      ctx.restore();
    }

    // Market Pulse: one row per level group shown.
    if (on('pulseOn', true)) {
      const cols = [on('pulseType', true), on('pulseWidth', true), on('pulseAtr', true),
        on('pulseRead', true)];
      const rowsData = [];
      let anyVirgin = false;
      for (const g of TC_GROUPS) {
        if (!groups[g.id].cpr) continue;
        const list = an[g.id];
        const j = this._gpEntryIndex(list, g.id, n - 1);
        if (j < 0) continue;
        const e = list[j];
        if (e.virgin) anyVirgin = true;
        rowsData.push({ g, e });
      }
      if (rowsData.length) {
        const head = [{ t: 'TF', bg: '#F0F0F0' }];
        if (cols[0]) head.push({ t: 'CPR Type', bg: '#F0F0F0' });
        if (cols[1]) head.push({ t: 'Width', bg: '#F0F0F0' });
        if (cols[2]) head.push({ t: 'ATR Phase', bg: '#F0F0F0' });
        if (anyVirgin) head.push({ t: 'Virgin CPR', bg: '#F0F0F0' });
        if (cols[3]) head.push({ t: 'Read', bg: '#F0F0F0' });
        const bg = _tcHex(_gpNum(p, 'pulseBg', 0xFFFFFF) | 0);
        const fg = _tcHex(_gpNum(p, 'pulseTx', 0x000000) | 0);
        const unit = { d: 'days', w: 'weeks', m: 'months' };
        const rows = [head];
        for (const { g, e } of rowsData) {
          const r = e.rel >= 0 ? GP_RELATIONS[e.rel] : null;
          const ph = GP_PHASES[e.phase];
          const read = gpRead(e.widthClass, e.phase);
          const row = [{ t: g.pre, bg, fg }];
          if (cols[0]) row.push(r ? { t: r.sym + ' ' + r.short, bg: r.color, fg: '#FFFFFF', bold: true } : { t: '—', bg, fg });
          if (cols[1]) {
            row.push({ t: GP_WIDTHS[e.widthClass] + ' ' + gpFmtPct(e.widthPct, 3) + '%',
              bg: ['#C5B3F6', '#D9CCF8', '#ECECEC', '#FFCC80'][e.widthClass], fg: '#131722' });
          }
          if (cols[2]) {
            const streak = e.phase === 0 && e.streak >= 2 ? ' · ' + e.streak + ' ' + unit[g.id] : '';
            row.push({ t: ph.arrow + ' ' + ph.name + ' ' + gpFmtRatio(e.ratio) + 'x' + streak,
              bg: e.phase === 1 ? bg : ph.color, fg: e.phase === 1 ? fg : '#131722' });
          }
          if (anyVirgin) {
            row.push(e.virgin ? { t: '✓ Zone live', bg: '#FFF59D', fg: '#131722' } : { t: '—', bg, fg });
          }
          if (cols[3]) row.push({ t: read, bg: GP_READ_COLORS[read] || bg, fg: '#131722' });
          rows.push(row);
        }
        this._gpTable(plot, rows, p.pulsePos | 0, _gpNum(p, 'pulseSize', 1),
            'Trend Checker by GP · Market Pulse');
      }
    }
  }

  // ── Future Trend Checker ──
  // Which groups are on: Auto picks one from the chart timeframe (intraday:
  // day, daily chart: week, weekly and above: month), Manual uses the switches.
  _ftGroups(p, tf) {
    const sw = (k, def) => (typeof p[k] === 'number' ? p[k] >= 1 : def);
    if ((p.mode | 0) === 0) {
      const which = tf >= 10080 ? 'm' : tf >= 1440 ? 'w' : 'd';
      const hl = sw('autoHl', true);
      const o = {};
      for (const g of TC_GROUPS) o[g.id] = { cpr: g.id === which, hl: g.id === which && hl };
      return o;
    }
    return {
      d: { cpr: sw('dOn', true), hl: sw('pdOn', true) },
      w: { cpr: sw('wOn', false), hl: sw('pwOn', false) },
      m: { cpr: sw('mOn', false), hl: sw('pmOn', false) },
    };
  }

  // The current period's high / low / close for a group, live: the official
  // daily bars before the newest candle's day plus today from the chart's own
  // candles (intraday) or the newest daily candle. After the close the
  // official daily bar's close wins (NSE's close is not the last trade).
  _ftCurrent(group) {
    const n = this.candles.length;
    const d = this._cprDaily;
    if (!n || !d) return null;
    const last = this.candles[n - 1];
    const di = _tcDayIdx(last.ts);
    const tf = this.timeframeMinutes;
    let today = null;
    if (tf < 1440) {
      for (let i = n - 1; i >= 0 && _tcDayIdx(this.candles[i].ts) === di; i--) {
        const c = this.candles[i];
        if (!today) today = { h: c.h, l: c.l, c: last.c };
        if (c.h > today.h) today.h = c.h;
        if (c.l < today.l) today.l = c.l;
      }
    } else if (tf === 1440) {
      today = { h: last.h, l: last.l, c: last.c };
    }
    const eod = d.bars.find((b) => _tcDayIdx(b.ts) === di);
    if (eod) {
      if (!today) today = { h: eod.h, l: eod.l, c: eod.c };
      else {
        today.h = Math.max(today.h, eod.h);
        today.l = Math.min(today.l, eod.l);
        if (d.afterClose) today.c = eod.c;
      }
    }
    if (!today) return null;
    const keyOf = group === 'd' ? (x) => x : group === 'w' ? _tcWeekIdx : _tcMonthIdx;
    const key = keyOf(di);
    const cur = { h: today.h, l: today.l, c: today.c, dayIdx: di };
    for (const b of d.bars) {
      const bd = _tcDayIdx(b.ts);
      if (bd >= di || keyOf(bd) !== key) continue;
      if (b.h > cur.h) cur.h = b.h;
      if (b.l < cur.l) cur.l = b.l;
    }
    return cur;
  }

  _ftFutureMap(ind) {
    const p = ind.params || {};
    const an = this._gpAnalysis(p);
    if (!an) return {};
    const groups = this._ftGroups(p, this.timeframeMinutes);
    const out = {};
    for (const g of TC_GROUPS) {
      if (!groups[g.id].cpr) continue;
      const f = gpFuture(g.id, an[g.id], this._ftCurrent(g.id), p);
      if (f) out[g.id] = f;
    }
    return out;
  }

  // Today's levels as plotted values (same series as Trend Checker), for the
  // legend, autoscale and the price-scale labels.
  _ftShownLines(ind) {
    const p = ind.params || {};
    const groups = this._ftGroups(p, this.timeframeMinutes);
    const series = this._tcSeries();
    const out = [];
    for (const line of TC_LINES) {
      const g = groups[line.group];
      if (!(line.sw === 'hl' ? g.hl : g.cpr)) continue;
      out.push({ line, color: line.sw === 'hl' ? '#000000' : line.color,
        vals: series[line.group][line.field], seg: series[line.group].seg });
    }
    return out;
  }

  _ftLegendValues(ind) {
    if (!this.candles.length) return [];
    const i = this.candles.length - 1;
    const out = [];
    for (const s of this._ftShownLines(ind)) {
      const v = s.vals[i];
      if (isFinite(v)) out.push({ v, color: this._gpInk(s.color), dp: 2 });
    }
    return out;
  }

  _ftRange(ind, a, b) {
    let lo = Infinity, hi = -Infinity;
    for (const s of this._ftShownLines(ind)) {
      for (let i = Math.max(0, a); i <= b && i < s.vals.length; i++) {
        const v = s.vals[i];
        if (!isFinite(v)) continue;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    }
    return hi === -Infinity ? null : { lo, hi };
  }

  _drawFtcheckIndicator(ind, plot, lo, hi, priceToY, firstAbs, lastAbs) {
    this._ensureCprDaily();
    const n = this.candles.length;
    if (!n) return;
    const p = ind.params || {};
    const ctx = this.ctx;
    const X = (i) => this._candleXCenter(i, plot);
    const baseY = Math.min(plot.bottom, Math.max(plot.top, priceToY(1)));
    const i0 = Math.max(0, firstAbs - 1);
    const i1 = Math.min(n - 1, lastAbs + 1);
    const todayW = Math.max(1, Math.min(4, _gpNum(p, 'todayW', 2) | 0));
    const nextW = Math.max(1, Math.min(4, _gpNum(p, 'nextW', 2) | 0));
    ctx.save();
    ctx.beginPath();
    ctx.rect(plot.left, plot.top, plot.right - plot.left, plot.bottom - plot.top);
    ctx.clip();

    // 1. Today's levels, one segment per period.
    for (const s of this._ftShownLines(ind)) {
      const st = { color: this._gpInk(s.color), width: todayW, lineStyle: 'solid',
        plotType: 'circles', priceLine: false };
      let a = i0;
      for (let i = i0 + 1; i <= i1 + 1; i++) {
        if (i > i1 || s.seg[i] !== s.seg[a]) {
          if (isFinite(s.vals[a])) this._drawCprPlot(s.vals, a, i - 1, st, plot, priceToY, baseY);
          a = i;
        }
      }
    }

    // 2. Next period's CPR in the empty room right of the newest bar, with
    // level names and prices, and the date it applies to on the pivot.
    const fut = this._ftFutureMap(ind);
    const groups = this._ftGroups(p, this.timeframeMinutes);
    // Engines without that room (no _futureBars) draw against the right edge,
    // with the names to the left of the lines.
    const room = typeof this._futureBars === 'function' ? this._futureBars() : 0;
    const labelLeft = !room;
    const xa = room ? X(n - 1) + this.view.cellW : plot.right - 64;
    const xb = room ? X(n - 1) + this.view.cellW * (_FT_SPAN + 1) : plot.right - 4;
    const names = !(typeof p.namesOn === 'number' && p.namesOn < 1);
    const nextName = { d: 'Next Day', w: 'Next Week', m: 'Next Month' };
    for (const g of TC_GROUPS) {
      const f = fut[g.id];
      if (!f) continue;
      const pre = g.short;
      const levels = [
        ['r4', '#4CAF50', pre + ' R4'], ['r3', '#4CAF50', pre + ' R3'], ['r2', '#4CAF50', pre + ' R2'],
        ['r1', '#4CAF50', pre + ' R1'], ['tc', g.color, ''], ['pivot', g.color, pre + ' CPR'],
        ['bc', g.color, ''], ['s1', '#FF5252', pre + ' S1'], ['s2', '#FF5252', pre + ' S2'],
        ['s3', '#FF5252', pre + ' S3'], ['s4', '#FF5252', pre + ' S4'],
      ];
      if (groups[g.id].hl) {
        levels.push(['high', '#000000', g.hl[0]], ['low', '#000000', g.hl[1]]);
      }
      for (const [k, color, label] of levels) {
        const v = f.lv[k];
        if (!isFinite(v)) continue;
        const y = priceToY(v);
        const ink = this._gpInk(color);
        ctx.save();
        ctx.strokeStyle = ink;
        ctx.lineWidth = nextW;
        ctx.lineCap = 'round';
        ctx.setLineDash([0.1, nextW * 2.5]);
        ctx.beginPath();
        ctx.moveTo(xa, y);
        ctx.lineTo(xb, y);
        ctx.stroke();
        ctx.restore();
        if (!names || !label) continue;
        // Prices on the label are rounded to the tick, as TradingView prints them.
        const ti = (this.scrip && this.scrip.ti > 0) ? this.scrip.ti : 0.05;
        const txt = label + ' ' + (Math.round(v / ti) * ti).toFixed(2);
        if (k === 'pivot') {
          const date = (p.nextOn === undefined || p.nextOn >= 1)
              ? ' · ' + nextName[g.id] + ' · ' + gpFmtDay(f.nextDay) : '';
          this._gpPill(labelLeft ? xa - 6 : xb + 6, y - 7, [txt + date],
              'rgba(209,196,233,0.95)', '#1A1A2E', labelLeft ? 'right' : 'left');
        } else {
          ctx.save();
          ctx.fillStyle = ink;
          ctx.font = '500 9px Geist, sans-serif';
          ctx.textAlign = labelLeft ? 'right' : 'left';
          ctx.textBaseline = 'middle';
          ctx.fillText(txt, labelLeft ? xa - 6 : xb + 6, y);
          ctx.restore();
        }
      }
    }
    ctx.restore();

    // 3. Trend table: one column per group shown.
    if (!(typeof p.tableOn === 'number' && p.tableOn < 1)) {
      const ids = TC_GROUPS.filter((g) => fut[g.id]).map((g) => g.id);
      if (ids.length) {
        const pct = !(typeof p.pctOn === 'number' && p.pctOn < 1);
        const band = ['#C8E6C9', '#BBDEFB', '#FFE0B2'];
        const wbg = ['#C8E6C9', '#C8E6C9', '#BBDEFB', '#FFE0B2'];
        const hl = (g) => ({ d: ['PDH', 'PDL'], w: ['PWH', 'PWL'], m: ['PMH', 'PML'] })[g];
        const lbl = (base, k) => base + ids.map((g) => hl(g)[k]).join('/');
        const gap = (k) => (k ? 'S1 ↔ ' : 'R1 ↔ ') + ids.map((g) => hl(g)[k]).join('/');
        const L = (t) => ({ t, bg: '#C9C9C9', fg: '#131722' });
        const pc = (x) => (pct ? ' ' + gpFmtPct(x, 2) + '%' : '');
        const rows = [[L('Next CPR')].concat(ids.map((g) => ({ t: { d: 'Day', w: 'Week', m: 'Month' }[g], bg: '#C9C9C9' })))];
        const row = (label, cell) => rows.push([L(label)].concat(ids.map((g) => cell(fut[g]))));
        row('CPR Width', (f) => ({ t: GP_WIDTHS[f.widthClass] + pc(f.widthPct), bg: wbg[f.widthClass] }));
        row(lbl('CPR → R1/', 0), (f) => ({ t: GP_BAND_NAMES[f.upBand] + pc(f.upPct), bg: band[f.upBand] }));
        row(lbl('CPR → S1/', 1), (f) => ({ t: GP_BAND_NAMES[f.dnBand] + pc(f.dnPct), bg: band[f.dnBand] }));
        row(gap(0), (f) => ({ t: GP_BAND_NAMES[f.r1Band] + pc(f.r1Gap), bg: band[f.r1Band] }));
        row(gap(1), (f) => ({ t: GP_BAND_NAMES[f.s1Band] + pc(f.s1Gap), bg: band[f.s1Band] }));
        row('Relationship', (f) => (f.rel >= 0
            ? { t: GP_RELATIONS[f.rel].next, bg: GP_RELATIONS[f.rel].soft } : { t: '—' }));
        row('Bias', (f) => (f.rel >= 0
            ? { t: GP_RELATIONS[f.rel].bias, bg: GP_RELATIONS[f.rel].soft } : { t: '—' }));
        row('ATR Phase', (f) => ({ t: GP_PHASES[f.phase].arrow + ' ' + GP_PHASES[f.phase].name + ' '
            + gpFmtRatio(f.ratio) + 'x', bg: f.phase === 1 ? '#EEEEEE' : GP_PHASES[f.phase].color }));
        this._gpTable(plot, rows, p.tablePos | 0, _gpNum(p, 'tableSize', 1), '');
      }
    }

    // 4. Price-scale labels for today's levels.
    const chips = [];
    for (const s of this._ftShownLines(ind)) {
      const v = s.vals[n - 1];
      if (isFinite(v)) chips.push({ v, color: this._gpInk(s.color) });
    }
    chips.sort((a, b) => b.v - a.v);
    let prevY = null;
    for (const c of chips) {
      let y = priceToY(c.v);
      if (prevY != null && y < prevY + 18) y = prevY + 18;
      const drawn = this._drawIndicatorAxisChip(plot, priceToY, c.v, c.color, 2, y);
      if (drawn != null) prevY = drawn;
    }
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

}
for (const _k of Object.getOwnPropertyNames(_ChartOverlaysMixin.prototype)) {
  if (_k !== 'constructor') Chart.prototype[_k] = _ChartOverlaysMixin.prototype[_k];
}
