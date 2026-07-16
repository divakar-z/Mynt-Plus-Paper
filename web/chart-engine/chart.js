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
    // Recent-window refresh bookkeeping (tab-visible / WS-reconnect heal).
    this._pendingRefreshId = null;
    this._refreshBlockedUntil = 0;
    // Epoch sec to re-pull FROM on the next heal refresh. Set when the tab goes
    // hidden / the socket reconnects so the refetch covers the whole gap (incl.
    // a hole BELOW the newest candle, which a last-real-candle anchor misses).
    this._healFromSec = null;
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
    this._leftGutter = 40;
    this._drawingHits = [];         // [{ rect, drawingId, action: 'delete'|'drag', kind }]
    this._indicatorChipHits = [];   // [{ rect, indicatorId, action: 'toggleHide'|'delete' }]
    // Full-row rects for each indicator chip — used to (a) keep the row
    // icons visible while the cursor is anywhere over the row (the cursor
    // moving onto an icon shouldn't blink the icons out), and (b)
    // suppress the chart crosshair when over any chip area.
    this._indicatorRowRects = []; // [{ rect, indicatorId }]
    this._hoveredIndicatorRowId = null;
    // Symbol chip (top-left SYMBOL · TF · EXCH) hover state 
    this._symbolChipRect = null;
    this._hoveredSymbolChip = false;
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
      this._updateSecondTimer();
    }, 2000);

    this._updateSecondTimer();

    // Heal the candle stream when the tab comes back to the foreground.
    this._onVisibility = () => {
      if (document.visibilityState === 'hidden') {
        // Record when we lost the foreground. Background tabs throttle timers
        // and may drop ticks, so bars can be missed — including a hole below
        // the newest bar. On return we re-pull FROM here so the merge refills
        // the whole gap, not just the tail.
        this._healFromSec = Math.floor(Date.now() / 1000);
      } else if (document.visibilityState === 'visible') {
        // A backgrounded tab SUSPENDS requestAnimationFrame, so the handle in
        // this._frame never fired and scheduleRedraw()'s `if (this._frame) return`
        // guard is now stuck truthy — the chart would otherwise stay frozen
        // FOREVER on return (ticks keep arriving and mutating candles, but every
        // redraw bails at the guard). Cancel the dead handle, clear the guard,
        // and force ONE synchronous repaint so the chart updates the instant we
        // return; the next tick's scheduleRedraw() then re-arms a normal rAF.
        if (this._frame) {
          cancelAnimationFrame(this._frame);
          this._frame = null;
        }
        this.draw();
        this._refreshRecent('visible');
      }
    };
    document.addEventListener('visibilitychange', this._onVisibility);
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
    // The 1Hz redraw drives the bar countdown — only needed while the session
    // is live (after close the countdown is hidden, so the timer can stop).
    const needsTimer = this.showBarCountdown && this._isSessionLive();
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
    // Day OHLC (today's session open/high/low) from the touchline feed — the
    // aggregator uses these to seed today's daily/weekly/monthly bar with the
    // real session open instead of the LTP-at-open. Keep the last known value.
    if (packet.o != null) this.tickState.dayOpen = +packet.o;
    if (packet.h != null) this.tickState.dayHigh = +packet.h;
    if (packet.l != null) this.tickState.dayLow = +packet.l;
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
    // Build/advance bars ONLY within the exchange's trading window. Outside it
    // — post-close heartbeats (indices keep ticking the closing value), the
    // post-market session (trades at the close price), depth-only updates, or
    // any after-hours print — ticks must NOT touch candles. The header LTP/bid/
    // ask above already updated, so the last price still shows. Special-session
    // (Muhurat / budget) bars are backfilled from the server by _refreshRecent,
    // not formed live.
    const _ftSec = this.tickState.ft;
    if (!this._isSessionWindow(_ftSec)) return;
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
    // Recent-window refresh — merge-replace the tail (incl. synth bars) with
    // server data. Pan/zoom preserved (xCenter is position-from-right; we only
    // touch the tail).
    if (requestId === this._pendingRefreshId) {
      this._pendingRefreshId = null;
      if (!Array.isArray(candles) || candles.length === 0) return;
      const fresh = bucketCandles(
          this._sessionFilterIntraday(candles), this.timeframeMinutes);
      if (fresh.length === 0) return;
      // Union merge by ts: keep EVERY existing candle and overlay the fetched
      // ones (server wins for overlapping buckets). A plain head+fresh splice
      // dropped any candle past fresh's last ts — so a short/stale refetch on
      // tab-return wiped bars we already had, leaving a gap. Union can't lose
      // candles and fills any hole inside the refetched span.
      const byTs = new Map();
      for (const c of this.candles) byTs.set(c.ts, c);
      for (const c of fresh) byTs.set(c.ts, c);
      this.candles = Array.from(byTs.values()).sort((a, b) => a.ts - b.ts);
      this._noMoreHistory = false;
      if (this.candleStyle === 'renko') {
        this._rebuildRenko();
        this._notifyBrickSize(this._renkoBrickSize);
      } else if (this._isRebinnedStyle(this.candleStyle)) {
        this._rebuildRebinned();
      }
      this.scheduleRedraw();
      return;
    }
    // Extend reply — prepend instead of replace. Empty page = no more history.
    if (requestId === this._pendingExtendId) {
      this._pendingExtendId = null;
      if (!Array.isArray(candles) || candles.length === 0) {
        this._noMoreHistory = true;
        return;
      }
      const fresh = bucketCandles(
          this._sessionFilterIntraday(candles), this.timeframeMinutes);
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
      // No history from the API — for ANY timeframe (daily+ index series like
      // SENSEX, OR intraday when the feed returns an empty window). Don't block
      // with "No history available": start empty and let live WS ticks build
      // the current bar. Daily/weekly/monthly seed it from the WS day-OHLC;
      // intraday forms the current 1/5-min bucket from incoming ticks. Matches
      // TradingView, which shows just the forming bar when history is absent.
      // A later _refreshRecent (tab-return / reconnect) backfills real bars once
      // at least one live candle exists. Still subscribe so ticks arrive.
      this.candles = [];
      this._noMoreHistory = true; // nothing older to fetch
      this.scheduleRedraw();
      if (this.scrip) {
        this.subscribe({ exch: this.scrip.exch, token: this.scrip.token });
      }
      return;
    }
    // Drop pre-open / post-close intraday bars (e.g. a 09:10 pre-open candle)
    // so the series starts at the real session open; daily+ bars pass through.
    // Bucketing then collapses any same-bucket candles correctly.
    this.candles = bucketCandles(
        this._sessionFilterIntraday(candles), this.timeframeMinutes);
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

  // Refetch the recent window after the tab was backgrounded or the socket
  // reconnected, replacing locally-synthesized/approximated tail bars with the
  // server's real OHLC. Correlated by request id (like the extend path), so no
  // bridge changes are needed. Throttled + single-in-flight.
  _refreshRecent(reason) {
    if (!this.scrip) return;
    if (this.timeframeMinutes >= 1440) return;     // daily+: extend covers it
    if (this.candles.length === 0) return;
    if (this._pendingRefreshId != null) return;
    if (this._pendingRequestId != null) return;    // initial load in flight
    if (Date.now() < this._refreshBlockedUntil) return;
    // Anchor at the last REAL (non-synth) candle so synth bars get replaced.
    let i = this.candles.length - 1;
    while (i > 0 && this.candles[i]._synth) i--;
    let startTs = this.candles[i].ts;
    const nowSec = Math.floor(Date.now() / 1000);
    const bucketSec = this.timeframeMinutes * 60;
    // Healing a hidden-tab / reconnect gap: while away, bars are missed (and a
    // partial refetch left holes). Re-pull the ENTIRE current trading day so the
    // union merge refills everything. If we were away since before today's open
    // (e.g. overnight), reach back to when we went hidden instead.
    if (this._healFromSec != null) {
      const sessOpen = this._sessionOpenTodaySec(nowSec);
      let healStart =
          (sessOpen != null) ? sessOpen : (this._healFromSec - bucketSec);
      if (this._healFromSec - bucketSec < healStart) {
        healStart = this._healFromSec - bucketSec;
      }
      startTs = Math.min(startTs, healStart);
      this._healFromSec = null;
    }
    if (startTs <= 0) return;
    if (nowSec - startTs < bucketSec) return; // nothing new yet
    this._pendingRefreshId = _newRequestId();
    this._refreshBlockedUntil = Date.now() + 3000;
    this.requestHistory({
      requestId: this._pendingRefreshId,
      exch: this.scrip.exch,
      token: this.scrip.token,
      tsym: this.scrip.tsym,
      interval: SOURCE_INTERVAL_FOR_MINUTES(this.timeframeMinutes),
      start: startTs,
      end: nowSec,
      targetMinutes: this.timeframeMinutes,
    });
  }

  onWsReconnected() {
    // A reconnect implies a dropped-tick gap of unknown length — heal a
    // generous recent window (30 min) so any holes from the outage refill.
    const back = Math.floor(Date.now() / 1000) - 30 * 60;
    this._healFromSec =
        this._healFromSec == null ? back : Math.min(this._healFromSec, back);
    this._refreshRecent('reconnect');
  }

  onHistoryError(requestId, message) {
    if (requestId === this._pendingRefreshId) {
      this._pendingRefreshId = null;
      return; // a refresh failing is non-fatal — next trigger retries
    }
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
    if (this._onVisibility) {
      document.removeEventListener('visibilitychange', this._onVisibility);
      this._onVisibility = null;
    }
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
    // Drop the previous symbol's option-chain OI bars so they don't linger on
    // the new symbol until its own OI is fetched + pushed.
    this._oiData = [];
    // Clear any in-progress drawing and the transient one-shot measurement so
    // they don't linger on the new symbol's chart until the next click.
    this._inProgressDrawing = null;
    this._activeMeasure = null;
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

        // --- Inline-toolbar: edit text (annotation drawings) ---
        for (const h of this._drawingHits) {
          if (h.action !== 'editText') continue;
          const r = h.rect;
          if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
            e.preventDefault();
            e.stopPropagation();
            try {
              parent.postMessage(JSON.stringify({
                type: 'drawingTextEditRequested',
                value: { paneId: this.paneId, drawingId: h.drawingId },
              }), '*');
            } catch (_) {}
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
                       ov.kind === 'ocoSl' || ov.kind === 'alert');
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
          const headerStripH = this.scrip ? 88 : (this.candles.length > 0 ? 40 : 24);
          const headerStripW = 300; // covers symbol + OHLC + bid/ask widths
          // Also treat a hover directly over any interactive header chip
          // (bid/ask/qty buttons or the symbol chip) as "in the header". Their
          // widths/positions shift with price magnitude and the left gutter, so
          // the fixed strip box above can miss the BUY/SELL buttons — which left
          // them showing the crosshair cursor instead of a clickable pointer.
          const _overHeaderChip =
              (this._headerHits || []).some((h) => h.rect &&
                  x >= h.rect.x && x <= h.rect.x + h.rect.w &&
                  y >= h.rect.y && y <= h.rect.y + h.rect.h) ||
              (!!this._symbolChipRect &&
                  x >= this._symbolChipRect.x &&
                  x <= this._symbolChipRect.x + this._symbolChipRect.w &&
                  y >= this._symbolChipRect.y &&
                  y <= this._symbolChipRect.y + this._symbolChipRect.h);
          if ((y < headerStripH && x >= 8 && x < 8 + headerStripW) ||
              _overHeaderChip) {
            // Pointer cursor when hovering interactive bid/ask/qty chips
            // inside the header strip — everything else stays default.
            let headerInteractiveHover = false;
            let headerHoverKind = null;
            for (const h of this._headerHits) {
              const r = h.rect;
              if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
                headerInteractiveHover = true;
                headerHoverKind = h.kind;
                break;
              }
            }
            // Symbol chip hover — same translucent backing as indicator rows.
            let symbolChipHover = false;
            if (this._symbolChipRect) {
              const r = this._symbolChipRect;
              if (x >= r.x && x <= r.x + r.w &&
                  y >= r.y && y <= r.y + r.h) {
                symbolChipHover = true;
              }
            }
            if (this._hoveredSymbolChip !== symbolChipHover) {
              this._hoveredSymbolChip = symbolChipHover;
              this.scheduleRedraw();
            }
            wrap.style.cursor = (headerInteractiveHover || symbolChipHover)
                ? 'pointer'
                : 'default';
            if (this._hoveredHeaderKind !== headerHoverKind) {
              this._hoveredHeaderKind = headerHoverKind;
              this.scheduleRedraw();
            }
            if (this.hover.inside) {
              this.hover.inside = false;
              this.hover.x = null;
              this.hover.y = null;
              this.scheduleRedraw();
            }
            return;
          } else if (this._hoveredHeaderKind) {
            this._hoveredHeaderKind = null;
            this.scheduleRedraw();
          } else if (this._hoveredSymbolChip) {
            this._hoveredSymbolChip = false;
            this.scheduleRedraw();
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
      // Leaving the chart must always drop the crosshair — including a pinned
      // one. The pin (set by a `+` order-at-price click) is only useful while a
      // popup is open over the chart; in instant mode there's no popup, so it
      // would otherwise linger at the click point after the cursor moves away.
      if (this._pinnedHover) { this._pinnedHover = null; this.scheduleRedraw(); }
      // Clear indicator-row hover too so icons fade out cleanly when
      // the cursor exits the pane (mouseleave skips the mousemove
      // recalculation that would otherwise nil this out).
      if (this._hoveredIndicatorRowId != null) {
        this._hoveredIndicatorRowId = null;
        this.scheduleRedraw();
      }
      // Same for the bid/ask header chips — clear their hover overlay.
      if (this._hoveredHeaderKind) {
        this._hoveredHeaderKind = null;
        this.scheduleRedraw();
      }
      // Symbol chip hover too.
      if (this._hoveredSymbolChip) {
        this._hoveredSymbolChip = false;
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
    // plot.left MUST include the drawing-rail gutter (Phase 30) — otherwise the
    // visible slice starts at x=8, under the open rail, and the leftmost 2-3
    // candles (and their high/low) render hidden beneath it. Mirror the same
    // railGutter computation used to build `plot` in draw().
    const railGutter = this._liteMode
        ? 0
        : (this._leftGutter != null ? this._leftGutter : 40);
    const left = 8 + railGutter;                 // plot.left (incl. rail gutter)
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

  // Keep the horizontal pan within bounds so at least a slice of the series
  // is always on screen — prevents panning the candles fully off either edge
  // (which left the pane blank). MARGIN is the min px of series kept visible.
  _clampOffsetX(plot) {
    const N = this._seriesLength();
    if (N <= 0) return;
    const W = this.view.cellW || 1;
    const plotW = plot.right - plot.left;
    const MARGIN = Math.min(plotW * 0.4, 120);
    // newest column x = plot.right - 0.5W + offsetX  ≥ plot.left + MARGIN
    const minOffset = (plot.left + MARGIN) - (plot.right - 0.5 * W);
    // oldest column x = plot.right - (N-0.5)W + offsetX  ≤ plot.right - MARGIN
    const maxOffset = (N - 0.5) * W - MARGIN;
    if (minOffset > maxOffset) return; // whole series fits — nothing to clamp
    let o = this.view.offsetX || 0;
    if (o < minOffset) o = minOffset;
    if (o > maxOffset) o = maxOffset;
    this.view.offsetX = o;
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
        : (this._leftGutter != null ? this._leftGutter : 40);
    const plot = {
      left: 8 + railGutter, top: topPad,
      right: w - rightGutter,
      bottom: topPad + candleH,
    };
    plot.width = plot.right - plot.left;
    plot.height = plot.bottom - plot.top;

    // Phase 30 — clamp the horizontal pan so the series can never be scrolled
    // entirely off-screen (which left the pane blank). Skipped while a Lab
    // projection is active — those intentionally pan far right to show the
    // ghost paths in future space.
    if (this._projLines.length === 0 && !this._projBand) {
      this._clampOffsetX(plot);
    }

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

    // Clip every series-area paint (gridlines, candles, volume) to x ≥ plot.left
    // so a boundary candle/wick/volume bar whose body half-width extends left of
    // plot.left can't render under the open drawing rail. Full canvas height +
    // right side stay untouched (axis labels live at x > plot.right). Restored
    // after the volume block; later overlays are positioned at xCenter ≥ plot.left.
    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.rect(plot.left, 0, this.canvas.clientWidth - plot.left,
        this.canvas.clientHeight);
    this.ctx.clip();

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

    // End of the series-area left-clip (gridlines + candles + volume).
    this.ctx.restore();

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
    // Phase 23.4 — Volume Profile gutter histogram (before H/L markers).
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
        this._drawChip(plot.right, chy,
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
      if (this._isClosed()) this._drawMarketClosedChip(plot);
      else this._drawStalePill(plot);
    }

    // Reset alpha and draw the loading banner on top, full-opacity.
    if (dimming) {
      this.ctx.globalAlpha = 1;
      this._drawLoadingBanner(w, h);
    }
  }

  _drawLoadingBanner(w, h) {
    if (!this._loadingTitle) return;
    // Plain circular spinner — matches MyntLoader.simple() from the app:
    // a CircularProgressIndicator-style arc in the primary brand color.
    const ctx = this.ctx;
    const cx = w / 2;
    const cy = h / 2;
    const radius = 18;
    const stroke = 3;
    const t = (typeof performance !== 'undefined' ? performance.now() : Date.now()) / 1000;
    const start = (t * Math.PI * 1.6) % (Math.PI * 2);
    const sweep = Math.PI * 1.25;
    // Track ring (subtle)
    ctx.lineWidth = stroke;
    ctx.lineCap = 'round';
    ctx.strokeStyle = this._withAlpha(this.palette.axisText, 0.18);
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.stroke();
    // Active arc in primary color
    ctx.strokeStyle = this.palette.long;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, start, start + sweep);
    ctx.stroke();
    // Keep animating until the loader is dismissed.
    if (this._loadingTitle != null) {
      if (!this._frame) {
        this._frame = requestAnimationFrame(() => {
          this._frame = null;
          this.draw();
        });
      }
    }
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

  // `gutterLeft` is plot.right (the price-axis gutter's left edge). The chip is
  // capped to the gutter width and centred within it so it never overflows /
  // clips against the canvas edge.
  _drawChip(gutterLeft, y, text) {
    this.ctx.font = '500 11px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    const gutter = Math.max(0, this.canvas.clientWidth - gutterLeft);
    const tw = this.ctx.measureText(text).width + 20;
    const chipW = Math.min(tw, Math.max(40, gutter - 6));
    const x = gutterLeft + Math.max(2, (gutter - chipW) / 2);
    const chipH = 22;
    this.ctx.fillStyle = this.palette.crosshairChip;
    this._roundedRect(x, y - chipH / 2, chipW, chipH, 3);
    this.ctx.fill();
    this.ctx.fillStyle = this.palette.chipText;
    this.ctx.textAlign = 'center';
    this.ctx.fillText(text, x + chipW / 2, y);
  }

  _drawTimeChip(x, yTop, text) {
    this.ctx.font = '500 11px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    const tw = this.ctx.measureText(text).width + 22;
    const left = x - tw / 2;
    const chipH = 22;
    this.ctx.fillStyle = this.palette.crosshairChip;
    this._roundedRect(left, yTop, tw, chipH, 3);
    this.ctx.fill();
    this.ctx.fillStyle = this.palette.chipText;
    this.ctx.textAlign = 'center';
    this.ctx.fillText(text, x, yTop + chipH / 2);
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
    const ltp = this._ltpLevel();
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
    // Responsive shrink: narrow panes (multi-pane layouts) scale the strip
    // down so it doesn't overflow the chart. Push the strip below when the
    // OHLC cluster wrapped onto a second row.
    const paneW = plot.right - plot.left;
    const scale = paneW < 280 ? 0.72 : (paneW < 380 ? 0.84 : 1);
    const stripY = (this._ohlcWrapped ? 62 : 44);
    const tallH = Math.round(42 * scale);
    const halfH = Math.round(20 * scale);
    const halfGap = 2;
    const padX = Math.max(6, Math.round(10 * scale));
    const innerPadX = Math.max(8, Math.round(12 * scale));
    const gap = Math.max(6, Math.round(10 * scale));
    const minSideW = Math.round(82 * scale);
    const fPrice = Math.max(11, Math.round(14 * scale));
    const fLabel = Math.max(9, Math.round(11 * scale));
    const fQty = Math.max(10, Math.round(12 * scale));
    const fSpread = Math.max(9, Math.round(11 * scale));
    const priceTextDy = -Math.round(tallH * 0.14);
    const labelTextDy = Math.round(tallH * 0.24);
    const hovered = this._hoveredHeaderKind || null;

    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';

    let x = plot.left + 12;

    // --- Bid chip (tall) ---
    ctx.font = `700 ${fPrice}px Geist, sans-serif`;
    const bidText = bid != null ? bid.toFixed(dp) : '—';
    const bidW = Math.max(minSideW, ctx.measureText(bidText).width + padX * 2);
    // Solid red fill matching the global "S" (sell) button color pattern.
    // Disabled (non-tradable / index): flat solid color
    ctx.fillStyle = isNonTradable
        ? (this.palette.shortDisabled || this.palette.short)
        : this.palette.short;
    this._roundedRect(x, stripY, bidW, tallH, 6);
    ctx.fill();
    // Hover overlay — white wash so the button visibly reacts to the cursor.
    if (!isNonTradable && hovered === 'bid') {
      ctx.fillStyle = 'rgba(255,255,255,0.14)';
      this._roundedRect(x, stripY, bidW, tallH, 6);
      ctx.fill();
    }
    ctx.fillStyle = '#FFFFFF';
    ctx.font = `500 ${fPrice}px Geist, sans-serif`;
    ctx.fillText(bidText, x + bidW / 2, stripY + tallH / 2 + priceTextDy);
    ctx.font = `500 ${fLabel}px Geist, sans-serif`;
    ctx.fillText('SELL', x + bidW / 2, stripY + tallH / 2 + labelTextDy);
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
      ctx.font = `600 ${Math.max(9, Math.round(10 * scale))}px Geist, sans-serif`;
      const tagW = Math.max(Math.round(56 * scale), ctx.measureText(tag).width + innerPadX * 2);
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
      ctx.font = `500 ${fSpread}px Geist, sans-serif`;
      const spreadTextW = spreadText
          ? ctx.measureText(spreadText).width
          : 0;

      ctx.font = `600 ${fQty}px Geist, sans-serif`;
      const qtyText = String(this.qty);
      const qtyTextW = ctx.measureText(qtyText).width;

      centreW = Math.max(spreadTextW, qtyTextW) + innerPadX * 2;
      const minCentreW = Math.round(56 * scale);
      if (centreW < minCentreW) centreW = minCentreW;

      if (spreadText) {
        ctx.fillStyle = this._withAlpha(this.palette.bg, 0.8);
        this._roundedRect(x, stripY, centreW, halfH, 4);
        ctx.fill();
        ctx.font = `500 ${fSpread}px Geist, sans-serif`;
        ctx.fillStyle = (ask - bid) < 0
            ? this.palette.short
            : this.palette.axisText;
        ctx.fillText(
            spreadText, x + centreW / 2, stripY + halfH / 2);
      }

      const qtyY = stripY + halfH + halfGap;
      // White (theme bg) qty chip with a subtle border
      ctx.fillStyle = this.palette.bg;
      this._roundedRect(x, qtyY, centreW, halfH, 4);
      ctx.fill();
      ctx.strokeStyle = this._withAlpha(this.palette.axisText, 0.55);
      ctx.lineWidth = 1;
      this._roundedRect(x, qtyY, centreW, halfH, 4);
      ctx.stroke();
      ctx.font = `600 ${fQty}px Geist, sans-serif`;
      ctx.fillStyle = this.palette.axisTextStrong;
      ctx.fillText(qtyText, x + centreW / 2, qtyY + halfH / 2);
      this._headerHits.push({
        rect: { x, y: qtyY, w: centreW, h: halfH },
        kind: 'qty',
      });
      x += centreW + gap;
    }

    // --- Ask chip (tall) ---
    ctx.font = `700 ${fPrice}px Geist, sans-serif`;
    const askText = ask != null ? ask.toFixed(dp) : '—';
    const askW = Math.max(minSideW, ctx.measureText(askText).width + padX * 2);
    // Solid blue fill matching the global "B" (buy) button color pattern.
    // Disabled (non-tradable / index): flat solid color
    ctx.fillStyle = isNonTradable
        ? (this.palette.longDisabled || this.palette.long)
        : this.palette.long;
    this._roundedRect(x, stripY, askW, tallH, 6);
    ctx.fill();
    // Hover overlay — white wash so the button visibly reacts to the cursor.
    if (!isNonTradable && hovered === 'ask') {
      ctx.fillStyle = 'rgba(255,255,255,0.14)';
      this._roundedRect(x, stripY, askW, tallH, 6);
      ctx.fill();
    }
    ctx.fillStyle = '#FFFFFF';
    ctx.font = `500 ${fPrice}px Geist, sans-serif`;
    ctx.fillText(askText, x + askW / 2, stripY + tallH / 2 + priceTextDy);
    ctx.font = `500 ${fLabel}px Geist, sans-serif`;
    ctx.fillText('BUY', x + askW / 2, stripY + tallH / 2 + labelTextDy);
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
    this._roundedRect(x, top, size, size, 1000);
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
    const name = this.scrip.dispName || this.scrip.tsym || '';
    const exch = this.scrip.exch || '';
    // 14px bold for the symbol — visual anchor of the chart. Sits over
    // transparent background; render-order is fine because OHLC line 2
    // is below it.
    this.ctx.font = '700 14px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    this.ctx.textAlign = 'left';
    const padLeft = 12;
    const chipY = 18;
    const gap = 5;
    const dotColor = this._withAlpha(this.palette.axisText, 0.55);
    const mutedColor = this._withAlpha(this.palette.axisText, 0.75);
    const segments = [
      { font: '500 14px Geist, sans-serif',
        color: this.palette.axisTextStrong, text: name },
      { font: '600 14px Geist, sans-serif',
        color: this.palette.axisTextStrong, text: '·' },
      { font: '500 14px Geist, sans-serif',
        color: this.palette.axisTextStrong, text: tf },
    ];
    if (exch) {
      segments.push({ font: '600 14px Geist, sans-serif',
        color: this.palette.axisTextStrong, text: '·' });
      segments.push({ font: '500 14px Geist, sans-serif',
        color: this.palette.axisTextStrong, text: exch });
    }
    let totalW = 0;
    for (const s of segments) {
      this.ctx.font = s.font;
      s.w = this.ctx.measureText(s.text).width;
      totalW += s.w;
    }
    totalW += gap * (segments.length - 1);
    // Solid background pad so candles don't bleed through the chip text.
    // On hover the chip switches to the same translucent backing + border
    // used by the indicator legend rows.
    const bgPadX = 6;
    const bgH = 22;
    const bgY = chipY - bgH / 2;
    const bgX = plot.left + padLeft - bgPadX;
    const bgW = totalW + bgPadX * 2;
    this._symbolChipRect = { x: bgX, y: bgY, w: bgW, h: bgH };
    const isLight = (this._basePalette && this._basePalette.bg === '#FFFFFF');
    const hovered = this._hoveredSymbolChip;
    const chipBgHover = isLight
        ? 'rgba(248,250,252,0.85)'
        : 'rgba(33,38,45,0.96)';
    const chipBorderHover = isLight
        ? '#E2E8F0'
        : '#30363D';
    this.ctx.fillStyle = hovered
        ? (isLight ? '#FFFFFF' : '#21262D')
        : this._withAlpha(this.palette.bg, 0.8);
    if (this.ctx.roundRect) {
      this.ctx.beginPath();
      this.ctx.roundRect(bgX, bgY, bgW, bgH, 4);
      this.ctx.fill();
      if (hovered) {
        this.ctx.strokeStyle = chipBorderHover;
        this.ctx.lineWidth = 1;
        this.ctx.beginPath();
        this.ctx.roundRect(bgX, bgY, bgW, bgH, 4);
        this.ctx.stroke();
      }
    } else {
      this.ctx.fillRect(bgX, bgY, bgW, bgH);
    }
    let x = plot.left + padLeft;
    for (let i = 0; i < segments.length; i++) {
      const s = segments[i];
      this.ctx.font = s.font;
      this.ctx.fillStyle = s.color;
      this.ctx.fillText(s.text, x, chipY);
      x += s.w + (i < segments.length - 1 ? gap : 0);
    }
    return (x - (plot.left + padLeft)) + padLeft + 4;
  }

  _formatTimeframeLabel(m) {
    if (m % 1440 === 0) return (m / 1440) + 'D';
    if (m % 60 === 0) return (m / 60) + 'h';
    return m + 'm';
  }

  _drawOhlc(plot) {
    this.ctx.textBaseline = 'middle';
    const chipY = 18;   // Single header row — SYMBOL · TF · O H L C V
    const ohlcY = 18;   // OHLC drawn inline next to the symbol chip

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
    }

    if (!chipText && !haveCandles) return;

    // Single header row — symbol chip first, then OHLC inline right after.
    const chipW = this._drawPaneChip(plot);

    if (!haveCandles) return;

    // OHLC segments — placed inline next to the symbol on the same row.
    // `chipW` already includes the 12px left inset + a 4px trailing margin,
    // so we just add a small extra gap so OHLC reads as a separate cluster.
    this.ctx.textAlign = 'left';
    // Pre-measure each segment so we can pad a solid background behind the
    // whole cluster (keeps candles from bleeding through the values).
    let ohlcTotalW = 0;
    const ohlcLaid = [];
    for (const [label, value, color] of segs) {
      this.ctx.font = '500 11px Geist, sans-serif';
      const lw = this.ctx.measureText(label).width;
      this.ctx.font = '600 11px Geist, sans-serif';
      const vw = this.ctx.measureText(value).width;
      ohlcLaid.push({ label, value, color, lw, vw });
      ohlcTotalW += lw + 5 + vw + 14;
    }
    if (ohlcLaid.length) ohlcTotalW -= 14;  // trailing gap shouldn't pad bg
    const ohlcBgPadX = 6;
    const ohlcBgH = 22;
    // Responsive wrap: if the inline OHLC cluster would overflow the pane's
    // right edge, drop it onto a second row aligned under the symbol chip.
    const inlineStartX = plot.left + chipW + 8;
    const wouldOverflow =
        inlineStartX + ohlcTotalW + ohlcBgPadX > plot.right - 4;
    this._ohlcWrapped = wouldOverflow;
    const ohlcStartX = wouldOverflow ? (plot.left + 12) : inlineStartX;
    const ohlcRowY = wouldOverflow ? (ohlcY + 20) : ohlcY;
    const ohlcBgY = ohlcRowY - ohlcBgH / 2;
    const ohlcBgX = ohlcStartX - ohlcBgPadX;
    const ohlcBgW = ohlcTotalW + ohlcBgPadX * 2;
    this.ctx.fillStyle = this._withAlpha(this.palette.bg, 0.8);
    if (this.ctx.roundRect) {
      this.ctx.beginPath();
      this.ctx.roundRect(ohlcBgX, ohlcBgY, ohlcBgW, ohlcBgH, 3);
      this.ctx.fill();
    } else {
      this.ctx.fillRect(ohlcBgX, ohlcBgY, ohlcBgW, ohlcBgH);
    }
    let x = ohlcStartX;
    for (const seg of ohlcLaid) {
      this.ctx.font = '500 11px Geist, sans-serif';
      this.ctx.fillStyle = this._withAlpha(this.palette.ohlcLabel, 0.95);
      this.ctx.fillText(seg.label, x, ohlcRowY);
      x += seg.lw + 5;
      this.ctx.font = '600 11px Geist, sans-serif';
      this.ctx.fillStyle = seg.color;
      this.ctx.fillText(seg.value, x, ohlcRowY);
      x += seg.vw + 14;
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

  // Inline params string: any numeric values from ind.params, space-separated.
  _indicatorParamsLabel(ind) {
    const parts = [];
    const p = ind.params || {};
    for (const key of Object.keys(p)) {
      const v = p[key];
      if (typeof v === 'number' && Number.isFinite(v)) parts.push(String(v));
    }
    return parts.join(' ');
  }

  // Latest computed value for indicators that draw a single overlay line.
  // Returns null for indicators whose value isn't easily a single number
  // (RSI/MACD/BB/etc.) — those just show kind+params in the legend.
  _indicatorLastValue(ind) {
    if (!this.candles.length) return null;
    if (ind.kind === 'sma') {
      const v = this._computeSMA(ind.period);
      return v && v.length ? v[v.length - 1] : null;
    }
    if (ind.kind === 'ema') {
      const v = this._computeEMA(ind.period);
      return v && v.length ? v[v.length - 1] : null;
    }
    if (ind.kind === 'zlema') {
      const v = this._computeZLEMA(ind.period);
      return v && v.length ? v[v.length - 1] : null;
    }
    if (ind.kind === 'mcginley') {
      const v = this._computeMcGinley(ind.period);
      return v && v.length ? v[v.length - 1] : null;
    }
    return null;
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
    // Dark-mode palette mirrors the scalper tab — listItemBg #161B22
    // (with ~92% alpha so the chart doesn't bleed through), dividerDark
    // #30363D for borders, and a slightly raised #21262D for hover.
    const chipBg = isLight ? 'rgba(248,250,252,0.96)' : 'rgba(22,27,34,0.92)';
    const chipBgHover = isLight ? 'rgba(248,250,252,0.85)' : 'rgba(33,38,45,0.96)';
    const chipBorder = isLight ? '#E2E8F0' : '#30363D';
    const chipBorderHover = isLight ? '#E2E8F0' : '#30363D';
    const surfaceFill = isLight ? '#FFFFFF' : '#161B22';
    const surfaceFillHover = isLight ? '#FFFFFF' : '#21262D';
    const chevronStroke = isLight ? '#475569' : '#C9D1D9';
    const textActive = this.palette.axisTextStrong;
    const textMuted = this.palette.axisText;
    const iconActive = isLight ? '#475569' : '#FFFFFF';
    const iconDim = isLight ? '#94A3B8' : '#9CA3AF';

    // Extra gap below the SELL/BID-ASK strip so the legend doesn't crowd
    // the trading chips. Larger when the trading strip is present.
    const headerGap = this.scrip ? 22 : 10;
    let y = stripH + headerGap;

    // ── Collapsed pill — TradingView-style "˅ N" minimal button ─────────
    // Default state. Click to expand.
    if (this._indicatorChipsCollapsed) {
      const countLabel = String(this._indicators.length);
      ctx.font = '600 11px Geist, sans-serif';
      const numW = ctx.measureText(countLabel).width;
      const chevW = 10;
      const gap = 6;
      const padX = 8;
      const w = padX + chevW + gap + numW + padX;
      const h = 24;
      const x = plot.left + 6;
      ctx.fillStyle = surfaceFill;
      this._roundedRect(x, y, w, h, 4);
      ctx.fill();
      ctx.strokeStyle = chipBorder;
      ctx.lineWidth = 1;
      this._roundedRect(x, y, w, h, 4);
      ctx.stroke();
      // Chevron-down icon — matches indicator-row icon weight (1.4, round)
      const chevCx = x + padX + chevW / 2;
      const chevCy = y + h / 2;
      ctx.strokeStyle = chevronStroke;
      ctx.lineWidth = 1.4;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.beginPath();
      ctx.moveTo(chevCx - 4, chevCy - 2);
      ctx.lineTo(chevCx, chevCy + 2);
      ctx.lineTo(chevCx + 4, chevCy - 2);
      ctx.stroke();
      // Count text
      ctx.fillStyle = chevronStroke;
      ctx.fillText(countLabel, x + padX + chevW + gap, y + h / 2);
      this._indicatorChipHits.push({
        rect: { x, y, w, h },
        action: 'toggleCollapse',
      });
      ctx.restore();
      return;
    }

    // ── Expanded — clean text list per TradingView ──────────────────────
    // Each row: [color dot] [name + period + value] [eye] [target]
    // [trash]. Icons appear only on row hover. The collapse header is
    // rendered AFTER the rows so it sits at the bottom of the strip.
    const rowH = 24;
    const dotSize = 8;
    const labelGap = 8;
    const iconW = 18;
    const iconGap = 4;
    const rowPadX = 8;

    ctx.font = '500 11px Geist, sans-serif';

    for (const ind of this._indicators) {
      const kindLabel = (ind.kind || '').toUpperCase();
      const paramsLabel = ind.period && ind.period > 0
          ? String(ind.period)
          : this._indicatorParamsLabel(ind);
      const lastVal = this._indicatorLastValue(ind);
      const valLabel = lastVal != null ? this._fmtPrice(lastVal) : '';
      const indColor = ind.color || '#3B82F6';
      const textColor = ind.hidden ? textMuted : textActive;
      const paramsColor = ind.hidden ? iconDim : textMuted;
      const valColor = ind.hidden ? iconDim : indColor;

      // Inline measurement — kind + " " + params + " " + value
      const kindW = ctx.measureText(kindLabel).width;
      const sp = 5;
      const paramsW = paramsLabel
          ? ctx.measureText(paramsLabel).width + sp
          : 0;
      const valW = valLabel
          ? ctx.measureText(valLabel).width + sp
          : 0;
      const labelW = kindW + paramsW + valW;

      const x = plot.left + 6;
      const rowRight = x + rowPadX + dotSize + labelGap + labelW + labelGap +
          iconW * 3 + iconGap * 2 + rowPadX;
      const rowW = rowRight - x;
      const rowHovered = this._hoveredIndicatorRowId === ind.id;
      this._indicatorRowRects.push({
        rect: { x, y, w: rowW, h: rowH },
        indicatorId: ind.id,
      });

      // Row backdrop — at rest, a solid chart-bg pad sits behind just the
      // dot + label cluster so candles don't bleed through the text. On
      // hover the full row (including icons) gets the chip backing + border.
      if (rowHovered) {
        ctx.fillStyle = surfaceFillHover;
        this._roundedRect(x, y, rowW, rowH, 4);
        ctx.fill();
        ctx.strokeStyle = chipBorderHover;
        ctx.lineWidth = 1;
        this._roundedRect(x, y, rowW, rowH, 4);
        ctx.stroke();
      } else {
        const labelBgW = rowPadX + dotSize + labelGap + labelW + rowPadX;
        ctx.fillStyle = chipBg;
        this._roundedRect(x, y, labelBgW, rowH, 4);
        ctx.fill();
      }

      // Color dot — keeps the indicator's own color even when hidden
      // (dimmed to a slate so the row still reads as "this is the row
      // for indicator X" even after toggling visibility off).
      const dotX = x + rowPadX;
      const dotY = y + (rowH - dotSize) / 2;
      ctx.fillStyle = ind.hidden ? iconDim : indColor;
      ctx.beginPath();
      ctx.roundRect(dotX, dotY, dotSize, dotSize, 2);
      ctx.fill();

      // Inline label: KIND (strong) + params (muted) + value (indicator color)
      let lx = dotX + dotSize + labelGap;
      ctx.fillStyle = textColor;
      ctx.fillText(kindLabel, lx, y + rowH / 2);
      lx += kindW;
      if (paramsLabel) {
        lx += sp;
        ctx.fillStyle = paramsColor;
        ctx.fillText(paramsLabel, lx, y + rowH / 2);
        lx += paramsW - sp;
      }
      if (valLabel) {
        lx += sp;
        ctx.fillStyle = valColor;
        ctx.fillText(valLabel, lx, y + rowH / 2);
      }

      // Icons render only on row hover — high contrast against the
      // solidified hover backing.
      const iconsStartX = (dotX + dotSize + labelGap) + labelW + labelGap;
      const iconY = y;
      const iconColor = ind.hidden ? iconDim : iconActive;

      const drawIcon = (ix, paint) => {
        const cx = ix + iconW / 2;
        const cy = y + rowH / 2;
        paint(cx, cy);
      };

      const eyeX = iconsStartX;
      const targetX = eyeX + iconW + iconGap;
      const trashX = targetX + iconW + iconGap;

      if (rowHovered) {
        // Lucide SVG icons rendered via Path2D on a 24-unit viewBox, scaled
        // to a 16px glyph centered in the 18px icon cell.
        const iconPx = 16;
        const drawSvg = (cx, cy, paths, color) => {
          ctx.save();
          ctx.translate(cx - iconPx / 2, cy - iconPx / 2);
          ctx.scale(iconPx / 24, iconPx / 24);
          ctx.strokeStyle = color;
          ctx.lineWidth = 2;
          ctx.lineCap = 'round';
          ctx.lineJoin = 'round';
          for (const d of paths) ctx.stroke(new Path2D(d));
          ctx.restore();
        };

        // Eye — teenyicons (filled, 15×15 viewBox). Inline Path2D so the
        // color follows the theme and there's no async asset load.
        const eyePathD =
          'M0.5 7.5L0.0357612 7.31431C-0.0119204 7.43351 -0.0119204 7.56649 0.0357612 7.68569L0.5 7.5ZM14.5 7.5L14.9642 7.6857C15.0119 7.56649 15.0119 7.43351 14.9642 7.3143L14.5 7.5ZM7.49998 12C5.18597 12 3.56111 10.8483 2.49664 9.66552C1.96405 9.07375 1.57811 8.48029 1.32563 8.03474C1.19968 7.81247 1.10772 7.62838 1.04797 7.50164C1.01811 7.4383 0.996349 7.3894 0.98246 7.35735C0.975517 7.34133 0.970545 7.32953 0.967517 7.32225C0.966003 7.31861 0.964975 7.3161 0.96443 7.31477C0.964157 7.3141 0.964005 7.31372 0.963973 7.31364C0.963958 7.3136 0.963972 7.31364 0.964016 7.31375C0.964038 7.31381 0.964094 7.31394 0.964105 7.31397C0.964168 7.31413 0.964239 7.31431 0.5 7.5C0.0357612 7.68569 0.0358471 7.68591 0.0359408 7.68614C0.0359823 7.68625 0.036084 7.6865 0.0361671 7.68671C0.0363335 7.68712 0.0365311 7.68761 0.0367599 7.68818C0.0372175 7.68931 0.0377999 7.69075 0.0385076 7.69248C0.0399231 7.69595 0.0418401 7.70062 0.0442628 7.70644C0.0491078 7.71808 0.0559773 7.73436 0.0649031 7.75495C0.0827516 7.79614 0.108844 7.85467 0.143439 7.92805C0.212592 8.07474 0.315944 8.28128 0.455611 8.52776C0.734381 9.01971 1.16093 9.67625 1.75334 10.3345C2.93886 11.6517 4.814 13 7.49998 13V12ZM0.5 7.5C0.964239 7.68569 0.964168 7.68587 0.964105 7.68603C0.964094 7.68606 0.964038 7.68619 0.964016 7.68625C0.963972 7.68636 0.963958 7.6864 0.963973 7.68636C0.964005 7.68628 0.964157 7.6859 0.96443 7.68523C0.964975 7.6839 0.966003 7.68139 0.967517 7.67775C0.970545 7.67047 0.975517 7.65867 0.98246 7.64265C0.996349 7.6106 1.01811 7.5617 1.04797 7.49836C1.10772 7.37162 1.19968 7.18753 1.32563 6.96526C1.57811 6.51971 1.96405 5.92625 2.49664 5.33448C3.56111 4.15173 5.18597 3 7.49998 3V2C4.814 2 2.93886 3.34827 1.75334 4.66552C1.16093 5.32375 0.734381 5.98029 0.455611 6.47224C0.315944 6.71872 0.212592 6.92526 0.143439 7.07195C0.108844 7.14533 0.0827516 7.20386 0.0649031 7.24505C0.0559773 7.26564 0.0491078 7.28192 0.0442628 7.29356C0.0418401 7.29938 0.0399231 7.30405 0.0385076 7.30752C0.0377999 7.30925 0.0372175 7.31069 0.0367599 7.31182C0.0365311 7.31239 0.0363335 7.31288 0.0361671 7.31329C0.036084 7.3135 0.0359823 7.31375 0.0359408 7.31386C0.0358471 7.31409 0.0357612 7.31431 0.5 7.5ZM7.49998 3C9.814 3 11.4389 4.15173 12.5033 5.33448C13.0359 5.92625 13.4219 6.51971 13.6744 6.96526C13.8003 7.18754 13.8923 7.37162 13.952 7.49837C13.9819 7.5617 14.0037 7.6106 14.0175 7.64265C14.0245 7.65868 14.0295 7.67048 14.0325 7.67775C14.034 7.68139 14.035 7.6839 14.0356 7.68524C14.0358 7.6859 14.036 7.68628 14.036 7.68636C14.036 7.6864 14.036 7.68636 14.036 7.68625C14.036 7.6862 14.0359 7.68606 14.0359 7.68603C14.0358 7.68587 14.0358 7.6857 14.5 7.5C14.9642 7.3143 14.9642 7.31409 14.9641 7.31385C14.964 7.31375 14.9639 7.3135 14.9638 7.31329C14.9637 7.31288 14.9635 7.31239 14.9632 7.31182C14.9628 7.31069 14.9622 7.30925 14.9615 7.30752C14.9601 7.30405 14.9582 7.29938 14.9557 7.29356C14.9509 7.28192 14.944 7.26564 14.9351 7.24504C14.9172 7.20385 14.8912 7.14533 14.8566 7.07195C14.7874 6.92526 14.6841 6.71871 14.5444 6.47224C14.2656 5.98029 13.8391 5.32375 13.2466 4.66552C12.0611 3.34827 10.186 2 7.49998 2V3ZM14.5 7.5C14.0358 7.3143 14.0358 7.31413 14.0359 7.31397C14.0359 7.31394 14.036 7.3138 14.036 7.31375C14.036 7.31364 14.036 7.3136 14.036 7.31364C14.036 7.31372 14.0358 7.3141 14.0356 7.31476C14.035 7.3161 14.034 7.31861 14.0325 7.32225C14.0295 7.32952 14.0245 7.34132 14.0175 7.35735C14.0037 7.3894 13.9819 7.4383 13.952 7.50163C13.8923 7.62838 13.8003 7.81246 13.6744 8.03474C13.4219 8.48029 13.0359 9.07375 12.5033 9.66552C11.4389 10.8483 9.814 12 7.49998 12V13C10.186 13 12.0611 11.6517 13.2466 10.3345C13.8391 9.67625 14.2656 9.01971 14.5444 8.52776C14.6841 8.28129 14.7874 8.07474 14.8566 7.92805C14.8912 7.85467 14.9172 7.79615 14.9351 7.75496C14.944 7.73436 14.9509 7.71808 14.9557 7.70644C14.9582 7.70062 14.9601 7.69595 14.9615 7.69248C14.9622 7.69075 14.9628 7.68931 14.9632 7.68818C14.9635 7.68761 14.9637 7.68712 14.9638 7.68671C14.9639 7.6865 14.964 7.68625 14.9641 7.68615C14.9642 7.68591 14.9642 7.6857 14.5 7.5ZM7.5 9C6.67157 9 6 8.32843 6 7.5H5C5 8.88071 6.11929 10 7.5 10V9ZM9 7.5C9 8.32843 8.32843 9 7.5 9V10C8.88071 10 10 8.88071 10 7.5H9ZM7.5 6C8.32843 6 9 6.67157 9 7.5H10C10 6.11929 8.88071 5 7.5 5V6ZM7.5 5C6.11929 5 5 6.11929 5 7.5H6C6 6.67157 6.67157 6 7.5 6V5Z';
        drawIcon(eyeX, (cx, cy) => {
          ctx.save();
          ctx.translate(cx - iconPx / 2, cy - iconPx / 2);
          ctx.scale(iconPx / 15, iconPx / 15);
          ctx.fillStyle = iconColor;
          ctx.fill(new Path2D(eyePathD));
          if (ind.hidden) {
            ctx.strokeStyle = iconColor;
            ctx.lineWidth = 1.5;
            ctx.lineCap = 'round';
            ctx.beginPath();
            ctx.moveTo(2, 2);
            ctx.lineTo(13, 13);
            ctx.stroke();
          }
          ctx.restore();
        });

        // Settings — Iconsax (hex shield + center circle). Stroke 1.5 in
        // the 24-viewBox to match the original asset.
        const settingsPaths = [
          'M3 9.11011V14.8801C3 17.0001 3 17.0001 5 18.3501L10.5 21.5301C11.33 22.0101 12.68 22.0101 13.5 21.5301L19 18.3501C21 17.0001 21 17.0001 21 14.8901V9.11011C21 7.00011 21 7.00011 19 5.65011L13.5 2.47011C12.68 1.99011 11.33 1.99011 10.5 2.47011L5 5.65011C3 7.00011 3 7.00011 3 9.11011Z',
          'M12 15C13.6569 15 15 13.6569 15 12C15 10.3431 13.6569 9 12 9C10.3431 9 9 10.3431 9 12C9 13.6569 10.3431 15 12 15Z',
        ];
        drawIcon(targetX, (cx, cy) => {
          ctx.save();
          ctx.translate(cx - iconPx / 2, cy - iconPx / 2);
          ctx.scale(iconPx / 24, iconPx / 24);
          ctx.strokeStyle = iconColor;
          ctx.lineWidth = 1.5;
          ctx.lineCap = 'round';
          ctx.lineJoin = 'round';
          for (const d of settingsPaths) ctx.stroke(new Path2D(d));
          ctx.restore();
        });

        // Trash — MingCute "delete" (filled, evenodd). Uses iconColor so
        // it matches the eye + settings glyphs.
        const trashPathD =
          'M20,5 C20.5523,5 21,5.44772 21,6 C21,6.55228 20.5523,7 20,7 L19.0001,7 L18.9975,7.07129 L18.0638,20.1425 C17.9891,21.1891 17.1182,22 16.0689,22 L7.93116,22 C6.88189,22 6.011,21.1891 5.93624,20.1425 L5.00258,7.07129 C5.00088,7.04738 5.00002,7.02361 5,7 L4,7 C3.44772,7 3,6.55228 3,6 C3,5.44772 3.44772,5 4,5 L20,5 Z M16.9975,7 L7.00259,7 L7.93116,20 L16.0689,20 L16.9975,7 Z M14,2 C14.5523,2 15,2.44772 15,3 C15,3.55228 14.5523,4 14,4 L10,4 C9.44772,4 9,3.55228 9,3 C9,2.44772 9.44772,2 10,2 L14,2 Z';
        drawIcon(trashX, (cx, cy) => {
          ctx.save();
          ctx.translate(cx - iconPx / 2, cy - iconPx / 2);
          ctx.scale(iconPx / 24, iconPx / 24);
          ctx.fillStyle = iconColor;
          ctx.fill(new Path2D(trashPathD), 'evenodd');
          ctx.restore();
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
        rect: { x: targetX, y: iconY, w: iconW, h: rowH },
        indicatorId: ind.id,
        action: 'openSettings',
      });
      this._indicatorChipHits.push({
        rect: { x: trashX, y: iconY, w: iconW, h: rowH },
        indicatorId: ind.id,
        action: 'delete',
      });

      y += rowH;
    }

    // ── Footer chevron-up chip — sits BELOW the rows. Click to collapse.
    {
      y += 4;
      const hw = 24;
      const hh = 24;
      const hx = plot.left + 6;
      ctx.fillStyle = surfaceFill;
      this._roundedRect(hx, y, hw, hh, 4);
      ctx.fill();
      ctx.strokeStyle = chipBorder;
      ctx.lineWidth = 1;
      this._roundedRect(hx, y, hw, hh, 4);
      ctx.stroke();
      // Chevron-up icon — matches indicator-row icon weight (1.4, round)
      const cx = hx + hw / 2;
      const cy = y + hh / 2;
      ctx.strokeStyle = chevronStroke;
      ctx.lineWidth = 1.4;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.beginPath();
      ctx.moveTo(cx - 4, cy + 2);
      ctx.lineTo(cx, cy - 2);
      ctx.lineTo(cx + 4, cy + 2);
      ctx.stroke();
      this._indicatorChipHits.push({
        rect: { x: hx, y, w: hw, h: hh },
        action: 'toggleCollapse',
      });
    }
    ctx.restore();
  }

  _drawStalePill(plot) {
    if (this._isClosed()) return;   // "closed" is shown by _drawMarketClosedChip
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

  // Small unobtrusive chip in the same top-right spot as the stale pill,
  // shown only when the session is closed and we have candles to freeze on.
  _drawMarketClosedChip(plot) {
    if (this.candles.length === 0) return;
    const text = 'Market closed';
    this.ctx.font = '700 10px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    const tw = this.ctx.measureText(text).width + 14;
    const x = this.canvas.clientWidth - 64 - tw - 8;
    this.ctx.fillStyle = this._withAlpha(this.palette.axisText, 0.16);
    this._roundedRect(x, 6, tw, 16, 8);
    this.ctx.fill();
    this.ctx.fillStyle = this.palette.axisText;
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

  // ── Session clock (instance wrappers over the pure helpers) ───────────────
  // True when tsSec is inside this scrip's exchange session window
  // (weekday, open<=m<close, EXCLUSIVE close). Unmapped exchanges → always-on.
  _isSessionWindow(tsSec) {
    if (!Number.isFinite(tsSec) || tsSec <= 0) return true;
    const exch = this.scrip ? this.scrip.exch : null;
    if (!exch) return true;
    return _isSessionWindowPure(exch, tsSec);
  }

  // Has the server/feed given us data for *today* (IST)? Distinguishes a real
  // trading day (incl. special/Muhurat/budget sessions) from a holiday/weekend.
  _hasSessionDataToday() {
    const nowSec = Math.floor(Date.now() / 1000);
    const todayKey = _istDayKey(nowSec);
    if (this._lastTickAt &&
        _istDayKey(Math.floor(this._lastTickAt / 1000)) === todayKey) return true;
    const n = this.candles.length;
    if (n > 0 && _istDayKey(this.candles[n - 1].ts) === todayKey) return true;
    return false;
  }

  // "Closed" decision — strict trading-window timings.
  //  - within the session window: closed only on a weekday holiday (no data
  //    for today at all).
  //  - outside the session window: closed. Candles never form/update outside
  //    the window; any special-session (Muhurat / budget) bars are backfilled
  //    by the server refetch (_refreshRecent), not formed live.
  // Unmapped exchanges are never "closed" (always-on).
  _isClosed() {
    const exch = this.scrip ? this.scrip.exch : null;
    if (!exch) return false;
    const nowSec = Math.floor(Date.now() / 1000);
    if (_sessionBoundsFor(exch, nowSec).openMin == null) return false;
    if (this._isSessionWindow(nowSec)) {
      // Within market hours: "closed" only means a weekday holiday — we HAVE
      // prior candles but none for today. With NO data loaded yet (empty
      // history + no tick), the chart is just loading today's bar from the
      // live feed; don't flash "Market closed".
      if (this.candles.length === 0 && !this._lastTickAt) return false;
      return !this._hasSessionDataToday();
    }
    return true;
  }

  _isSessionLive() { return !this._isClosed(); }

  // Epoch sec of TODAY's session open (IST) for this scrip's exchange, or null
  // for an unmapped/always-on exchange. Used by the heal refresh to re-pull the
  // full trading day after the tab was backgrounded.
  _sessionOpenTodaySec(nowSec) {
    const exch = this.scrip ? this.scrip.exch : null;
    if (!exch) return null;
    const b = _sessionBoundsFor(exch, nowSec);
    if (b.openMin == null) return null;
    const p = _istParts(nowSec);
    const secWithinMin = nowSec % 60;
    const istMidnight = nowSec - p.minuteOfDay * 60 - secWithinMin;
    return istMidnight + b.openMin * 60;
  }

  // Drop out-of-session INTRADAY candles (pre-open like 09:10, post-close, or
  // weekend) from server history so the chart starts exactly at the session
  // open. Daily/weekly/monthly bars are day-boundary stamped, so the intraday
  // session-window check doesn't apply — return them unchanged.
  _sessionFilterIntraday(candles) {
    if (!Array.isArray(candles)) return candles;
    if (this.timeframeMinutes >= 1440) return candles;
    // Keep only in-session buckets (drops pre-open like 09:10, post-close and
    // weekend bars). `_isSessionWindow` returns true for unmapped exchanges so
    // those pass through untouched.
    return candles.filter((c) => this._isSessionWindow(c.ts));
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
    if (!this._isSessionLive()) return;        // closed/holiday → never fabricate
    const nowSec = Math.floor(Date.now() / 1000);
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
      // EXCLUSIVE close: _isSessionWindow blocks the post-close bucket
      // (e.g. the 15:30 bucket on NSE), so no stale bar forms after close.
      if (this._isSessionWindow(nextBucket)) {
        this.candles.push({
          ts: nextBucket,
          o: lastClose, h: lastClose, l: lastClose, c: lastClose, v: 0,
          _synth: true,
        });
        appended++;
      }
      nextBucket += targetSec;
    }
    if (appended > 0) this.scheduleRedraw();
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
    // Change = current OI − previous-day OI (poi). Shown as absolute change +
    // % in brackets, e.g. "2.2Cr  +12.3L (+0.6%)". When poi is unknown (0) the
    // change is omitted rather than reported as the whole OI.
    const sgn = (n) => (n >= 0 ? '+' : '-') + this._fmtOi(Math.abs(n));
    const chgText = (oi, poi, pctFallback) => {
      if (poi > 0) {
        const chg = (oi || 0) - poi;
        return `  ${sgn(chg)} ${this._fmtPct((chg / poi) * 100)}`;
      }
      // No previous-day OI available — at least show the server's % change.
      if (typeof pctFallback === 'number' && pctFallback !== 0) {
        return `  ${this._fmtPct(pctFallback)}`;
      }
      return '';
    };
    const lines = [
      `Strike:   ${this._fmtStrike(s.strike)}`,
      `Call OI:  ${this._fmtOi(s.callOi)}${chgText(s.callOi, s.callPoi, s.callOiChgPct)}`,
      `Put OI:   ${this._fmtOi(s.putOi)}${chgText(s.putOi, s.putPoi, s.putOiChgPct)}`,
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

  // Price level the live-price line/chip sits at. In Heikin-Ashi mode the
  // candle bodies are HA-transformed, so the line must track the last bar's
  // HA close (o+h+l+c)/4 rather than the raw close — otherwise it floats off
  // the candles. Every other style uses the raw close.
  _ltpLevel() {
    if (this.candles.length === 0) return null;
    const last = this.candles[this.candles.length - 1];
    return this.candleStyle === 'heikin-ashi'
        ? (last.o + last.h + last.l + last.c) / 4
        : last.c;
  }

  _drawLtpLine(plot, priceToY, lo, hi) {
    if (this.candles.length === 0) return;
    const last = this.candles[this.candles.length - 1];
    const ltp = this._ltpLevel();
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
    const up = this.candleStyle === 'heikin-ashi' && this._haPrev
        ? ltp >= this._haPrev.haOpen
        : last.c >= last.o;
    const color = up ? this.palette.bull : this.palette.bear;
    this.ctx.font = '500 11px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    const text = ltp.toFixed(this._priceDecimals());
    // Keep the chip inside the right price-axis gutter and centred within it,
    // instead of left-anchoring at plot.right with a fixed 84px width — that
    // overflowed the 64px gutter and clipped the chip against the canvas edge.
    const gutter = Math.max(0, this.canvas.clientWidth - plot.right);
    const tw = this.ctx.measureText(text).width + 20;
    const chipW = Math.min(tw, Math.max(40, gutter - 6));
    const chipX = plot.right + Math.max(2, (gutter - chipW) / 2);
    const chipH = 22;
    // Reserve enough vertical room for the chip + 1px gap + countdown
    // sub-chip when it's enabled, so the whole LTP block stays
    // above plot.bottom.
    const cdEnabled = this.showBarCountdown &&
        this._isSessionLive() &&
        this.candles.length > 0 &&
        typeof this.timeframeMinutes === 'number' &&
        this.timeframeMinutes > 0;
    const subH = 16;
    const blockH = chipH + (cdEnabled ? subH : 0);
    const cy = Math.max(plot.top + 8,
        Math.min(plot.bottom - 8 - (blockH - chipH), y));
    this.ctx.fillStyle = color;
    this._roundedRect(chipX, cy - chipH / 2, chipW, chipH, 3);
    this.ctx.fill();
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.textAlign = 'center';
    this.ctx.fillText(text, chipX + chipW / 2, cy);
    this._registerAxisChipSlot(cy, chipH);

    // Phase 18 — bar-close countdown directly under the LTP value, in a
    // continuous sub-chip below the existing one. Same fill colour so it
    // reads as a single 2-row chip.
    // Skip the countdown once the last bar's own close time has passed — a
    // frozen "0:00" must never linger (e.g. just after close, before the chart
    // flips to the "Market closed" state).
    const _cdLeft = cdEnabled
        ? ((this.candles[this.candles.length - 1].ts || 0) +
            this.timeframeMinutes * 60) - Math.floor(Date.now() / 1000)
        : 0;
    if (cdEnabled && _cdLeft > 0) {
      const left = _cdLeft;
      const mins = Math.floor(left / 60);
      const secs = left % 60;
      const cdText = mins + ':' + String(secs).padStart(2, '0');
      const subY = cy - chipH / 2 + chipH - 3; // overlap rounded corners so the two chips read as one
      this.ctx.fillStyle = color;
      this._roundedRect(chipX, subY, chipW, subH, 3);
      this.ctx.fill();
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.font = '500 10px Geist, sans-serif';
      this.ctx.textAlign = 'center';
      this.ctx.textBaseline = 'middle';
      this.ctx.fillText(cdText, chipX + chipW / 2, subY + subH / 2);
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
      // The labels are center-aligned and drawn after the series clip is
      // released, so a label near the left edge spills under the drawing rail
      // (and one near the right spills into the price axis). Skip those.
      if (xCenter < plot.left + 16 || xCenter > plot.right - 8) continue;
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

}
