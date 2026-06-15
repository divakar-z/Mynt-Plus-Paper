'use strict';

// ---------------------------------------------------------------------------
// Top bar — HTML controls injected into #top-bar inside the iframe.
//
// Migration strategy: per-control. Each control is its own small module
// (read state → render → wire events → post bridge messages → listen for
// Flutter-side updates). Flutter widgets are deleted as their JS twin
// ships, gated by a per-control feature flag on the Flutter side.
//
// First control (the spike): INSTANT toggle. Tests the full bridge —
// fire-and-forget for the OFF direction, request/reply for the ON
// direction (Flutter shows the warning-ack dialog).
// ---------------------------------------------------------------------------

(function initTopBar() {
  // Scan-explanation lite mode — the iframe URL carries `?lite=1`. Bail
  // immediately so we don't attach 1.6kloc of event listeners + render
  // the search / timeframe / fx / draw / INSTANT / Order-Defaults /
  // Snap / Settings chain on a read-only explain view. Reads the URL
  // directly because this IIFE runs before chart-engine.js's `boot()`
  // — any flag chart-engine.js sets at load-time isn't here yet.
  try {
    if (new URLSearchParams(window.location.search).get('lite') === '1') {
      return;
    }
  } catch (_) {}
  const root = document.getElementById('top-bar');
  if (!root) return;

  // ── Shared form-row builders ────────────────────────────────────────────
  // Each builder returns the row's DOM element. Caller wires the change
  // callback. The visual contract mirrors Flutter's RefinedRow (label +
  // optional description on the left, control on the right).
  function _row(label, description, controlEl) {
    const row = document.createElement('div');
    row.className = 'tb-form-row';
    const left = document.createElement('div');
    left.className = 'tb-form-row-text';
    const lbl = document.createElement('div');
    lbl.className = 'tb-form-row-label';
    lbl.textContent = label;
    left.appendChild(lbl);
    if (description) {
      const desc = document.createElement('div');
      desc.className = 'tb-form-row-desc';
      desc.textContent = description;
      left.appendChild(desc);
    }
    row.appendChild(left);
    const ctlWrap = document.createElement('div');
    ctlWrap.className = 'tb-form-row-ctl';
    ctlWrap.appendChild(controlEl);
    row.appendChild(ctlWrap);
    return row;
  }
  function _switch(value, onChange) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'tb-switch' + (value ? ' tb-switch--on' : '');
    btn.innerHTML = '<span class="tb-switch-thumb"></span>';
    btn.addEventListener('click', () => onChange(!value));
    return btn;
  }
  function _segmented(value, options, onChange) {
    const wrap = document.createElement('div');
    wrap.className = 'tb-segmented';
    for (const opt of options) {
      const seg = document.createElement('button');
      seg.type = 'button';
      seg.className = 'tb-segmented-opt' + (opt.value === value ? ' tb-segmented-opt--on' : '');
      seg.textContent = opt.label;
      seg.addEventListener('click', () => {
        if (opt.value === value) return;
        onChange(opt.value);
      });
      wrap.appendChild(seg);
    }
    return wrap;
  }
  function _numberStepper(value, { min = 1, max = 999999, step = 1, decimals = 0 } = {}, onChange) {
    const wrap = document.createElement('div');
    wrap.className = 'tb-stepper';
    const minus = document.createElement('button');
    minus.type = 'button';
    minus.className = 'tb-stepper-btn';
    minus.textContent = '−';
    const input = document.createElement('input');
    input.type = 'text';                       // text + inputmode=numeric for clean styling
    input.inputMode = decimals > 0 ? 'decimal' : 'numeric';
    input.className = 'tb-stepper-input';
    input.value = value.toFixed(decimals);
    const plus = document.createElement('button');
    plus.type = 'button';
    plus.className = 'tb-stepper-btn';
    plus.textContent = '+';
    function commit(n) {
      let v = Number.isFinite(n) ? n : value;
      if (v < min) v = min;
      if (v > max) v = max;
      // Round to `decimals` precision to avoid 0.30000000000004 drift.
      const factor = Math.pow(10, decimals);
      v = Math.round(v * factor) / factor;
      input.value = v.toFixed(decimals);
      if (v !== value) {
        value = v;
        onChange(v);
      }
    }
    minus.addEventListener('click', () => commit(value - step));
    plus.addEventListener('click', () => commit(value + step));
    input.addEventListener('blur', () => commit(parseFloat(input.value)));
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') input.blur();
    });
    wrap.appendChild(minus);
    wrap.appendChild(input);
    wrap.appendChild(plus);
    return wrap;
  }

  // ── Shared popover helpers ──────────────────────────────────────────────
  // Single-open invariant: opening a new popover/modal closes whatever
  // was open. `_openPopover` always points to the popover surface (the
  // element with `.tb-popover`) so dataset lookups + paint helpers work
  // regardless of whether it was opened anchored or as a centered modal.
  // `_openWrap` is the actual element to remove (popover OR modal
  // backdrop) and `_openKeyHandler` is the ESC handler attached to
  // modals only.
  let _openPopover = null;
  let _openWrap = null;
  let _openKeyHandler = null;
  let _openPopoverOutsideHandler = null;
  // Anchor element that owns the currently open anchored popover. Used so
  // clicking the SAME button again TOGGLES the popover closed instead of
  // re-opening it (the outside-mousedown handler ignores clicks on the
  // anchor, so without this the click handler would just rebuild it).
  let _openAnchor = null;
  function _closeOpenPopover() {
    if (!_openPopover) return;
    (_openWrap || _openPopover).remove();
    _openPopover = null;
    _openWrap = null;
    _openAnchor = null;
    if (_openPopoverOutsideHandler) {
      document.removeEventListener('mousedown', _openPopoverOutsideHandler, true);
      _openPopoverOutsideHandler = null;
    }
    if (_openKeyHandler) {
      document.removeEventListener('keydown', _openKeyHandler);
      _openKeyHandler = null;
    }
  }
  function openPopover(anchorEl, content) {
    // Toggle: if this anchor's popover is already open, a second click
    // closes it. Return a detached, never-inserted node so callers that
    // chain `.classList.add(...)` on the result stay harmless no-ops.
    const sameAnchorOpen = _openPopover != null && _openAnchor === anchorEl;
    _closeOpenPopover();
    if (sameAnchorOpen) return document.createElement('div');
    const pop = document.createElement('div');
    pop.className = 'tb-popover';
    pop.appendChild(content);
    const rect = anchorEl.getBoundingClientRect();
    // Append off-screen first so we can measure the popover's natural
    // width / height, THEN clamp it inside the viewport. Wide popovers
    // (Settings, Order Defaults) anchored to right-side buttons would
    // otherwise overflow the right edge.
    pop.style.left = '-9999px';
    pop.style.top = '0';
    document.body.appendChild(pop);
    const popW = pop.offsetWidth;
    const popH = pop.offsetHeight;
    const vw = document.documentElement.clientWidth;
    const vh = document.documentElement.clientHeight;
    const margin = 8;
    // Default: left-align with the anchor. If that would push past the
    // right edge, right-align with the anchor instead (so the popover
    // grows leftward from the button). Hard-clamp to viewport in case
    // the anchor itself is wider than the popover.
    let left = rect.left;
    if (left + popW + margin > vw) left = rect.right - popW;
    if (left + popW + margin > vw) left = vw - popW - margin;
    if (left < margin) left = margin;
    // Vertical: prefer below; flip above if it would overflow bottom.
    let top = rect.bottom + 4;
    if (top + popH + margin > vh && rect.top - popH - 4 >= margin) {
      top = rect.top - popH - 4;
    }
    pop.style.left = left + 'px';
    pop.style.top = top + 'px';
    _openPopover = pop;
    _openWrap = pop;
    _openAnchor = anchorEl;
    _openPopoverOutsideHandler = (e) => {
      if (pop.contains(e.target) || anchorEl.contains(e.target)) return;
      _closeOpenPopover();
    };
    document.addEventListener('mousedown', _openPopoverOutsideHandler, true);
    return pop;
  }

  // Centered modal — for popovers that are too large to anchor to a
  // single button without overflowing the viewport. Backdrop dims the
  // chart, click-outside or ESC closes. Returns the popover surface
  // (same shape as `openPopover`'s return value) so the caller's
  // `pop.dataset.kind = ...` / re-render helpers keep working.
  function openModal(content) {
    _closeOpenPopover();
    const backdrop = document.createElement('div');
    backdrop.className = 'tb-modal-backdrop';
    const pop = document.createElement('div');
    pop.className = 'tb-popover tb-modal';
    pop.appendChild(content);
    backdrop.appendChild(pop);
    document.body.appendChild(backdrop);
    backdrop.addEventListener('mousedown', (e) => {
      if (e.target === backdrop) _closeOpenPopover();
    });
    _openKeyHandler = (e) => {
      if (e.key === 'Escape') _closeOpenPopover();
    };
    document.addEventListener('keydown', _openKeyHandler);
    _openPopover = pop;
    _openWrap = backdrop;
    return pop;
  }

  // ── Per-active-pane state (Timeframe, Style) ────────────────────────────
  // Single source: `setActivePaneTopBarState` from Flutter. Each control
  // below reads from this snapshot and re-renders on update.
  let activePaneState = {
    timeframeMinutes: 1,
    candleStyle: 'candles',
    showCrosshairLines: true,
    indicators: [],   // [{id, kind, period, color, hidden, thickness, params}]
  };
  const activePaneSubs = [];
  bridge.on('setActivePaneTopBarState', (v) => {
    if (!v) return;
    if (typeof v.timeframeMinutes === 'number') {
      activePaneState.timeframeMinutes = v.timeframeMinutes;
    }
    if (typeof v.candleStyle === 'string') {
      activePaneState.candleStyle = v.candleStyle;
    }
    if (typeof v.showCrosshairLines === 'boolean') {
      activePaneState.showCrosshairLines = v.showCrosshairLines;
    }
    if (Array.isArray(v.indicators)) {
      activePaneState.indicators = v.indicators;
    }
    for (const sub of activePaneSubs) sub();
  });

  // ── Layout picker ───────────────────────────────────────────────────────
  // Renders a button with a mini-glyph of the current layout. Clicking
  // opens a popover grouped by pane count showing all layouts in the
  // catalog Flutter pushed via `setLayoutCatalog`. Picking one posts
  // `setActiveLayoutId` back to Flutter which routes through the existing
  // setLayout pipeline (catalog stays Flutter-owned).
  let layoutCatalog = [];                // [{id, paneCount, areas, ...}]
  let activeLayoutId = null;
  const layoutBtn = document.createElement('button');
  layoutBtn.className = 'tb-chip tb-layout';
  layoutBtn.type = 'button';
  layoutBtn.title = 'Layout';
  const layoutCanvas = document.createElement('canvas');
  layoutCanvas.width = 22; layoutCanvas.height = 22;
  layoutCanvas.style.width = '14px'; layoutCanvas.style.height = '14px';
  layoutBtn.appendChild(layoutCanvas);
  function paintLayoutGlyph(canvas, spec, color) {
    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    const w = canvas.width, h = canvas.height;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, w, h);
    ctx.strokeStyle = color;
    ctx.lineWidth = 1 * dpr;
    const rows = [];
    const re = /"([^"]+)"/g;
    let m;
    while ((m = re.exec(spec.areas)) !== null) {
      rows.push(m[1].trim().split(/\s+/));
    }
    if (rows.length === 0) return;
    const rowCount = rows.length;
    const colCount = rows[0].length;
    const cellW = w / colCount;
    const cellH = h / rowCount;
    const seen = new Map();
    for (let r = 0; r < rowCount; r++) {
      for (let c = 0; c < colCount; c++) {
        const letter = rows[r][c];
        const left = c * cellW, top = r * cellH;
        const right = (c + 1) * cellW, bottom = (r + 1) * cellH;
        const prev = seen.get(letter);
        if (!prev) seen.set(letter, { l: left, t: top, r: right, b: bottom });
        else {
          if (left < prev.l) prev.l = left;
          if (top < prev.t) prev.t = top;
          if (right > prev.r) prev.r = right;
          if (bottom > prev.b) prev.b = bottom;
        }
      }
    }
    for (const r of seen.values()) {
      ctx.strokeRect(r.l + 1, r.t + 1, r.r - r.l - 2, r.b - r.t - 2);
    }
  }

  function repaintLayoutButton() {
    const spec = layoutCatalog.find((l) => l.id === activeLayoutId)
        || layoutCatalog[0];
    if (!spec) return;
    paintLayoutGlyph(
        layoutCanvas, spec,
        getComputedStyle(layoutBtn).color);
  }

  function openLayoutPopover() {
    const content = document.createElement('div');
    content.className = 'tb-layout-popover-content';
    // Group catalog by paneCount.
    const groups = new Map();
    for (const l of layoutCatalog) {
      if (!groups.has(l.paneCount)) groups.set(l.paneCount, []);
      groups.get(l.paneCount).push(l);
    }
    const counts = Array.from(groups.keys()).sort((a, b) => a - b);
    for (const count of counts) {
      const row = document.createElement('div');
      row.className = 'tb-layout-row';
      const lbl = document.createElement('span');
      lbl.className = 'tb-layout-row-label';
      lbl.textContent = String(count);
      row.appendChild(lbl);
      const grid = document.createElement('div');
      grid.className = 'tb-layout-row-grid';
      for (const spec of groups.get(count)) {
        const tile = document.createElement('button');
        tile.type = 'button';
        tile.className = 'tb-layout-tile';
        if (spec.id === activeLayoutId) tile.classList.add('tb-layout-tile--on');
        const tc = document.createElement('canvas');
        tc.width = 32; tc.height = 22;
        tc.style.width = '32px'; tc.style.height = '22px';
        tile.appendChild(tc);
        tile.title = spec.id;
        tile.addEventListener('click', () => {
          activeLayoutId = spec.id;
          repaintLayoutButton();
          _closeOpenPopover();
          bridge.post('setActiveLayoutId', { id: spec.id });
        });
        grid.appendChild(tile);
        // Paint AFTER DOM insert so getComputedStyle has the colour.
        setTimeout(() => paintLayoutGlyph(
            tc, spec, getComputedStyle(tile).color), 0);
      }
      row.appendChild(grid);
      content.appendChild(row);
    }
    const pop = openPopover(layoutBtn, content);
    pop.classList.add('tb-layout-popover');
  }
  layoutBtn.addEventListener('click', openLayoutPopover);

  bridge.on('setLayoutCatalog', (v) => {
    if (!v || !Array.isArray(v.layouts)) return;
    layoutCatalog = v.layouts;
    repaintLayoutButton();
  });
  bridge.on('setActiveLayoutId', (v) => {
    if (!v || typeof v.id !== 'string') return;
    activeLayoutId = v.id;
    repaintLayoutButton();
  });
  root.appendChild(layoutBtn);

  // ── Symbol typeahead ────────────────────────────────────────────────────
  // 220px text input. Focus opens a result popover below; debounced search
  // routes through `bridge.request('searchSymbols', {q})` so the actual
  // network call + auth stays in Flutter for now (`getAuthHeaders` is a
  // future addition if we ever want JS to hit the broker directly).
  let symbolCurrent = null;          // {exch, token, tsym, dispName, ls, ti, instname}
  const symWrap = document.createElement('div');
  symWrap.className = 'tb-sym-wrap';
  const symInput = document.createElement('input');
  symInput.type = 'text';
  symInput.placeholder = 'Search symbol…';
  symInput.className = 'tb-sym-input';
  symInput.autocomplete = 'off';
  symInput.spellcheck = false;
  symWrap.appendChild(symInput);

  function _setSymbolValue(scrip) {
    symbolCurrent = scrip;
    if (document.activeElement !== symInput) {
      symInput.value = scrip ? (scrip.dispName || scrip.tsym || '') : '';
    }
  }
  bridge.on('setActivePaneSymbol', (v) => {
    _setSymbolValue(v && v.scrip ? v.scrip : null);
  });

  let symPopover = null;
  let symResults = [];
  let symLastQuery = '';            // query the current `symResults` reflect
  let symLoading = false;
  let symHighlight = -1;            // keyboard nav index
  let symDebounce = null;
  let symRequestSeq = 0;            // race-safety: latest query wins

  function _closeSymPopover() {
    if (!symPopover) return;
    symPopover.remove();
    symPopover = null;
    symHighlight = -1;
  }

  function _ensureSymPopover() {
    if (symPopover) return symPopover;
    const pop = document.createElement('div');
    pop.className = 'tb-popover tb-sym-popover';
    const rect = symInput.getBoundingClientRect();
    pop.style.left = rect.left + 'px';
    pop.style.top = (rect.bottom + 4) + 'px';
    pop.style.minWidth = rect.width + 'px';
    document.body.appendChild(pop);
    symPopover = pop;
    return pop;
  }

  function _paintSymPopover() {
    if (!symPopover) return;
    symPopover.innerHTML = '';
    const q = symInput.value.trim();
    if (symLoading) {
      const ld = document.createElement('div');
      ld.className = 'tb-sym-state';
      ld.textContent = 'Searching…';
      symPopover.appendChild(ld);
      return;
    }
    if (q.length < 2) {
      const hint = document.createElement('div');
      hint.className = 'tb-sym-state';
      hint.textContent = 'Type at least 2 characters to search';
      symPopover.appendChild(hint);
      return;
    }
    // Stale-guard: only render results whose query matches what's currently
    // in the input. Otherwise show the typing hint (catches the refocus
    // case where input was reset to the current symbol name but symResults
    // still holds the previous search).
    if (symLastQuery !== q) {
      const hint = document.createElement('div');
      hint.className = 'tb-sym-state';
      hint.textContent = 'Type to search';
      symPopover.appendChild(hint);
      return;
    }
    if (symResults.length === 0) {
      const empty = document.createElement('div');
      empty.className = 'tb-sym-state';
      empty.textContent = 'No matches';
      symPopover.appendChild(empty);
      return;
    }
    symResults.forEach((r, i) => {
      const row = document.createElement('button');
      row.type = 'button';
      row.className = 'tb-sym-row' + (i === symHighlight ? ' tb-sym-row--on' : '');
      const dn = (r.dname || r.tsym || '');
      const meta = ((r.exch || '') + (r.instname ? ' · ' + r.instname : ''));
      row.innerHTML = '<div class="tb-sym-row-main">'
          + '<div class="tb-sym-row-name">' + _escape(dn) + '</div>'
          + '<div class="tb-sym-row-meta">' + _escape(meta) + '</div>'
          + '</div>';
      // mousedown (not click) so the blur on the input doesn't fire before pick
      row.addEventListener('mousedown', (e) => {
        e.preventDefault();
        _pickSymbolResult(r);
      });
      row.addEventListener('mouseenter', () => {
        symHighlight = i;
        for (const el of symPopover.querySelectorAll('.tb-sym-row')) {
          el.classList.remove('tb-sym-row--on');
        }
        row.classList.add('tb-sym-row--on');
      });
      symPopover.appendChild(row);
    });
  }

  function _escape(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  function _pickSymbolResult(r) {
    const scrip = {
      exch:     r.exch || 'NSE',
      token:    r.token || '',
      tsym:     r.tsym || '',
      dispName: r.dname || r.tsym || r.symbol || '',
      ls:       parseInt(r.ls, 10) || 1,
      ti:       parseFloat(r.ti) || 0.05,
      instname: r.instname || '',
    };
    _setSymbolValue(scrip);
    symInput.value = scrip.dispName;
    symInput.blur();
    _closeSymPopover();
    bridge.post('setActivePaneSymbol', { scrip });
  }

  async function _runSearch(q) {
    const seq = ++symRequestSeq;
    const query = q.trim();
    if (query.length < 2) {
      symResults = [];
      symLastQuery = '';
      symLoading = false;
      _paintSymPopover();
      return;
    }
    symLoading = true;
    _paintSymPopover();
    try {
      const reply = await bridge.request('searchSymbols', { q: query });
      // Drop stale replies — only the latest query may paint.
      if (seq !== symRequestSeq) return;
      symResults = (reply && Array.isArray(reply.results)) ? reply.results : [];
      symLastQuery = query;
      symLoading = false;
      symHighlight = symResults.length > 0 ? 0 : -1;
      _paintSymPopover();
    } catch (_) {
      if (seq !== symRequestSeq) return;
      symResults = [];
      symLastQuery = '';
      symLoading = false;
      _paintSymPopover();
    }
  }

  symInput.addEventListener('focus', () => {
    _ensureSymPopover();
    _paintSymPopover();
    // Select-all so the user can start typing immediately.
    setTimeout(() => symInput.select(), 0);
  });
  symInput.addEventListener('blur', () => {
    // Defer close so a mousedown on a result lands first.
    setTimeout(() => {
      if (document.activeElement !== symInput) {
        _closeSymPopover();
        // Restore display name if user typed but didn't pick.
        if (symbolCurrent) {
          symInput.value = symbolCurrent.dispName || symbolCurrent.tsym || '';
        }
      }
    }, 150);
  });
  symInput.addEventListener('input', () => {
    _ensureSymPopover();
    // Immediate visual feedback while the debounce ticks — "Searching…"
    // for typed-enough queries, or the typing hint for <2 chars. Avoids
    // the brief "Type to search" stale-guard flash between keystrokes.
    if (symInput.value.trim().length >= 2) {
      symLoading = true;
    } else {
      symLoading = false;
      symResults = [];
      symLastQuery = '';
    }
    _paintSymPopover();
    if (symDebounce) clearTimeout(symDebounce);
    symDebounce = setTimeout(() => _runSearch(symInput.value), 200);
  });
  symInput.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown') {
      if (symResults.length === 0) return;
      symHighlight = (symHighlight + 1) % symResults.length;
      _paintSymPopover();
      e.preventDefault();
    } else if (e.key === 'ArrowUp') {
      if (symResults.length === 0) return;
      symHighlight = (symHighlight - 1 + symResults.length) % symResults.length;
      _paintSymPopover();
      e.preventDefault();
    } else if (e.key === 'Enter') {
      if (symHighlight >= 0 && symHighlight < symResults.length) {
        _pickSymbolResult(symResults[symHighlight]);
      }
      e.preventDefault();
    } else if (e.key === 'Escape') {
      symInput.blur();
      e.preventDefault();
    }
  });

  root.appendChild(symWrap);

  // ── Timeframe dropdown ──────────────────────────────────────────────────
  const TIMEFRAMES = [
    { label: '1m', minutes: 1 },
    { label: '2m', minutes: 2 },
    { label: '3m', minutes: 3 },
    { label: '5m', minutes: 5 },
    { label: '10m', minutes: 10 },
    { label: '15m', minutes: 15 },
    { label: '30m', minutes: 30 },
    { label: '1h', minutes: 60 },
    { label: '2h', minutes: 120 },
    { label: '4h', minutes: 240 },
    { label: '1D', minutes: 1440 },
    { label: '1W', minutes: 10080 },
    { label: '1M', minutes: 43200 },
  ];
  function timeframeLabel(min) {
    for (const t of TIMEFRAMES) if (t.minutes === min) return t.label;
    if (min % 1440 === 0) return (min / 1440) + 'D';
    if (min % 60 === 0) return (min / 60) + 'h';
    return min + 'm';
  }
  const tfBtn = document.createElement('button');
  tfBtn.className = 'tb-chip tb-timeframe';
  tfBtn.type = 'button';
  tfBtn.title = 'Timeframe';
  const tfLabel = document.createElement('span');
  tfLabel.className = 'tb-timeframe-label';
  tfBtn.appendChild(tfLabel);
  tfBtn.insertAdjacentHTML('beforeend',
      '<svg viewBox="0 0 24 24" width="10" height="10" '
      + 'fill="none" stroke="currentColor" stroke-width="2.5" '
      + 'stroke-linecap="round" stroke-linejoin="round" '
      + 'class="tb-chevron"><polyline points="6 9 12 15 18 9"/></svg>');
  function repaintTimeframe() {
    tfLabel.textContent = timeframeLabel(activePaneState.timeframeMinutes);
  }
  repaintTimeframe();
  activePaneSubs.push(repaintTimeframe);

  tfBtn.addEventListener('click', () => {
    const content = document.createElement('div');
    content.className = 'tb-list';
    for (const t of TIMEFRAMES) {
      const row = document.createElement('button');
      row.type = 'button';
      row.className = 'tb-list-row';
      if (t.minutes === activePaneState.timeframeMinutes) {
        row.classList.add('tb-list-row--on');
      }
      row.innerHTML = '<span class="tb-list-row-label">' + t.label
          + '</span><span class="tb-list-row-check">'
          + (t.minutes === activePaneState.timeframeMinutes ? '✓' : '')
          + '</span>';
      row.addEventListener('click', () => {
        _closeOpenPopover();
        if (t.minutes === activePaneState.timeframeMinutes) return;
        activePaneState.timeframeMinutes = t.minutes;
        repaintTimeframe();
        bridge.post('setActiveTimeframe', { minutes: t.minutes });
      });
      content.appendChild(row);
    }
    const pop = openPopover(tfBtn, content);
    pop.classList.add('tb-timeframe-popover');
  });
  root.appendChild(tfBtn);

  // ── Style picker (Candle / Hollow / Bars / Line / Area / Heikin Ashi) ──
  const STYLES = [
    { id: 'candles',     label: 'Candle' },
    { id: 'hollow',      label: 'Hollow Candle' },
    { id: 'bars',        label: 'OHLC Bars' },
    { id: 'line',        label: 'Line' },
    { id: 'area',        label: 'Area' },
    { id: 'heikin-ashi', label: 'Heikin Ashi' },
  ];
  const styleBtn = document.createElement('button');
  styleBtn.className = 'tb-chip tb-style';
  styleBtn.type = 'button';
  styleBtn.title = 'Chart style';
  // Compact "candlestick" SVG that doesn't change with style — same UX as
  // the Flutter button. The popover surfaces the label per style.
  styleBtn.innerHTML = '<svg viewBox="0 0 24 24" width="14" height="14" '
      + 'fill="none" stroke="currentColor" stroke-width="1.8" '
      + 'stroke-linecap="round" stroke-linejoin="round">'
      + '<path d="M8 4v4M8 14v6M16 4v8M16 18v2"/>'
      + '<rect x="6" y="8" width="4" height="6" rx="1"/>'
      + '<rect x="14" y="12" width="4" height="6" rx="1"/></svg>'
      + '<svg viewBox="0 0 24 24" width="10" height="10" '
      + 'fill="none" stroke="currentColor" stroke-width="2.5" '
      + 'stroke-linecap="round" stroke-linejoin="round" '
      + 'class="tb-chevron"><polyline points="6 9 12 15 18 9"/></svg>';

  styleBtn.addEventListener('click', () => {
    const content = document.createElement('div');
    content.className = 'tb-list';
    for (const s of STYLES) {
      const row = document.createElement('button');
      row.type = 'button';
      row.className = 'tb-list-row';
      if (s.id === activePaneState.candleStyle) {
        row.classList.add('tb-list-row--on');
      }
      row.innerHTML = '<span class="tb-list-row-label">' + s.label
          + '</span><span class="tb-list-row-check">'
          + (s.id === activePaneState.candleStyle ? '✓' : '')
          + '</span>';
      row.addEventListener('click', () => {
        _closeOpenPopover();
        if (s.id === activePaneState.candleStyle) return;
        activePaneState.candleStyle = s.id;
        bridge.post('setActiveCandleStyle', { style: s.id });
      });
      content.appendChild(row);
    }
    const pop = openPopover(styleBtn, content);
    pop.classList.add('tb-style-popover');
  });
  root.appendChild(styleBtn);

  // ── Cursor mode picker (Crosshair / Cursor) ────────────────────────────
  // Per-active-pane state. The chart's `showCrosshairLines` field controls
  // whether the full-height/width crosshair guide lines are drawn under
  // the cursor; "Cursor" mode shows only the floating LTP chip without
  // the guides. Sub-50-line control, simple two-option popover.
  const CURSOR_MODES = [
    { value: true,  label: 'Crosshair', svg:
        '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" '
        + 'stroke="currentColor" stroke-width="2" stroke-linecap="round" '
        + 'stroke-linejoin="round"><path d="M12 3v18M3 12h18"/></svg>' },
    { value: false, label: 'Cursor', svg:
        '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" '
        + 'stroke="currentColor" stroke-width="2" stroke-linecap="round" '
        + 'stroke-linejoin="round"><path d="M5 3l5 16 2-7 7-2z"/></svg>' },
  ];
  const cursorBtn = document.createElement('button');
  cursorBtn.className = 'tb-chip tb-cursor';
  cursorBtn.type = 'button';
  cursorBtn.title = 'Cursor mode';
  const cursorIconWrap = document.createElement('span');
  cursorIconWrap.className = 'tb-cursor-icon';
  cursorBtn.appendChild(cursorIconWrap);
  cursorBtn.insertAdjacentHTML('beforeend',
      '<svg viewBox="0 0 24 24" width="10" height="10" '
      + 'fill="none" stroke="currentColor" stroke-width="2.5" '
      + 'stroke-linecap="round" stroke-linejoin="round" '
      + 'class="tb-chevron"><polyline points="6 9 12 15 18 9"/></svg>');
  function repaintCursorButton() {
    const mode = CURSOR_MODES.find(
        (m) => m.value === activePaneState.showCrosshairLines)
        || CURSOR_MODES[0];
    cursorIconWrap.innerHTML = mode.svg;
  }
  repaintCursorButton();
  activePaneSubs.push(repaintCursorButton);

  cursorBtn.addEventListener('click', () => {
    const content = document.createElement('div');
    content.className = 'tb-list';
    for (const m of CURSOR_MODES) {
      const row = document.createElement('button');
      row.type = 'button';
      row.className = 'tb-list-row';
      if (m.value === activePaneState.showCrosshairLines) {
        row.classList.add('tb-list-row--on');
      }
      row.innerHTML = '<span class="tb-list-row-icon">' + m.svg + '</span>'
          + '<span class="tb-list-row-label">' + m.label + '</span>'
          + '<span class="tb-list-row-check">'
          + (m.value === activePaneState.showCrosshairLines ? '✓' : '')
          + '</span>';
      row.addEventListener('click', () => {
        _closeOpenPopover();
        if (m.value === activePaneState.showCrosshairLines) return;
        activePaneState.showCrosshairLines = m.value;
        repaintCursorButton();
        bridge.post('setActiveShowCrosshairLines', { value: m.value });
      });
      content.appendChild(row);
    }
    const pop = openPopover(cursorBtn, content);
    pop.classList.add('tb-cursor-popover');
  });
  root.appendChild(cursorBtn);

  // ── Color picker control ────────────────────────────────────────────────
  // Wraps a native <input type="color"> so picking opens the browser's
  // built-in picker but we present a styled colored square. Empty string
  // means "fall back to theme default"; the swatch shows a dashed border.
  // Reset button beside the swatch clears the field.
  function _colorPicker(value, defaultHex, onChange) {
    const wrap = document.createElement('div');
    wrap.className = 'tb-color';
    const swatch = document.createElement('button');
    swatch.type = 'button';
    swatch.className = 'tb-color-swatch'
        + (value ? '' : ' tb-color-swatch--empty');
    if (value) swatch.style.background = value;
    const hidden = document.createElement('input');
    hidden.type = 'color';
    hidden.value = value || (defaultHex || '#3B82F6');
    hidden.className = 'tb-color-input';
    swatch.appendChild(hidden);
    swatch.addEventListener('click', (e) => {
      // Don't double-trigger when the click reached the native input.
      if (e.target === hidden) return;
      hidden.click();
    });
    hidden.addEventListener('input', () => {
      onChange(hidden.value);
    });
    wrap.appendChild(swatch);
    const reset = document.createElement('button');
    reset.type = 'button';
    reset.className = 'tb-color-reset';
    reset.title = 'Reset';
    reset.textContent = '↻';
    reset.addEventListener('click', () => onChange(''));
    wrap.appendChild(reset);
    return wrap;
  }

  // ── Settings button + tabbed popover ────────────────────────────────────
  let viewState = {
    showHighLowMarkers: true, showOptionChainOi: false, showBarCountdown: true,
    showKeyLevels: false, pivotVariant: 'classical', showAutoPattern: true,
    magnetEnabled: false, showVolumeProfile: false, gridlines: true,
    volume: true,
  };
  let keyboardShortcuts = false;
  let paletteState = {
    bullBody: '#22C55E', bearBody: '#EF4444',
    bullWick: '#16A34A', bearWick: '#B91C1C',
    background: '', text: '', grid: '', sessionBreak: '', crosshair: '',
    defaults: {
      bullBody: '#22C55E', bearBody: '#EF4444',
      bullWick: '#16A34A', bearWick: '#B91C1C',
    },
  };
  bridge.on('setActivePaneViewState', (v) => {
    if (!v || typeof v !== 'object') return;
    viewState = Object.assign({}, viewState, v);
    if (_openPopover && _openPopover.dataset.kind === 'settings') {
      _renderSettingsTab(_openPopover);
    }
  });
  bridge.on('setKeyboardShortcutsState', (v) => {
    if (!v) return;
    keyboardShortcuts = !!v.value;
    if (_openPopover && _openPopover.dataset.kind === 'settings') {
      _renderSettingsTab(_openPopover);
    }
  });
  bridge.on('setChartPaletteState', (v) => {
    if (!v || typeof v !== 'object') return;
    paletteState = Object.assign({}, paletteState, v);
    if (_openPopover && _openPopover.dataset.kind === 'settings') {
      _renderSettingsTab(_openPopover);
    }
  });
  function _patchView(patch) {
    Object.assign(viewState, patch);
    bridge.post('updateActivePaneViewState', patch);
    if (_openPopover && _openPopover.dataset.kind === 'settings') {
      _renderSettingsTab(_openPopover);
    }
  }
  function _patchPalette(patch) {
    Object.assign(paletteState, patch);
    bridge.post('updateChartPalette', patch);
    if (_openPopover && _openPopover.dataset.kind === 'settings') {
      _renderSettingsTab(_openPopover);
    }
  }

  let settingsTab = 'view';   // 'view' | 'customize'

  function _renderSettingsTab(pop) {
    const body = pop.querySelector('.tb-settings-body');
    if (!body) return;
    body.innerHTML = '';
    if (settingsTab === 'view') {
      const v = viewState;
      body.appendChild(_row('High / Low markers',
          'Visible-range price extremes',
          _switch(v.showHighLowMarkers,
              (x) => _patchView({ showHighLowMarkers: x }))));
      body.appendChild(_row('Option-chain OI',
          'Open-interest bars at strikes',
          _switch(v.showOptionChainOi,
              (x) => _patchView({ showOptionChainOi: x }))));
      body.appendChild(_row('Bar countdown',
          'Time until current bar closes',
          _switch(v.showBarCountdown,
              (x) => _patchView({ showBarCountdown: x }))));
      body.appendChild(_row('Key levels (pivots)',
          'PP, R1–R3, S1–S3 from prev session',
          _switch(v.showKeyLevels,
              (x) => _patchView({ showKeyLevels: x }))));
      if (v.showKeyLevels) {
        body.appendChild(_row('Pivot variant',
            'Classical, Fibonacci or Camarilla',
            _segmented(v.pivotVariant, [
              { value: 'classical', label: 'Classical' },
              { value: 'fibonacci', label: 'Fibonacci' },
              { value: 'camarilla', label: 'Camarilla' },
            ], (x) => _patchView({ pivotVariant: x }))));
      }
      body.appendChild(_row('Auto-pattern',
          'HH / HL / LH / LL labels',
          _switch(v.showAutoPattern,
              (x) => _patchView({ showAutoPattern: x }))));
      body.appendChild(_row('Magnet',
          'Snap drawings to nearest O/H/L/C within 8px',
          _switch(v.magnetEnabled,
              (x) => _patchView({ magnetEnabled: x }))));
      body.appendChild(_row('Volume profile',
          'Right-gutter horizontal histogram',
          _switch(v.showVolumeProfile,
              (x) => _patchView({ showVolumeProfile: x }))));
      body.appendChild(_row('Gridlines',
          'Background reference grid',
          _switch(v.gridlines,
              (x) => _patchView({ gridlines: x }))));
      body.appendChild(_row('Volume sub-pane',
          'Below-chart volume bars',
          _switch(v.volume,
              (x) => _patchView({ volume: x }))));
      body.appendChild(_row('Keyboard shortcuts',
          'Alt+B/S, 1/5/H/D and more',
          _switch(keyboardShortcuts, (x) => {
            keyboardShortcuts = x;
            bridge.post('setKeyboardShortcutsState', { value: x });
          })));
    } else if (settingsTab === 'customize') {
      const p = paletteState;
      const d = paletteState.defaults || {};
      const sect = (label) => {
        const el = document.createElement('div');
        el.className = 'tb-popover-section-label';
        el.textContent = label;
        return el;
      };
      body.appendChild(sect('Candle colors'));
      body.appendChild(_row('Body — Up', null,
          _colorPicker(p.bullBody, d.bullBody, (x) => _patchPalette({ bullBody: x || d.bullBody }))));
      body.appendChild(_row('Body — Down', null,
          _colorPicker(p.bearBody, d.bearBody, (x) => _patchPalette({ bearBody: x || d.bearBody }))));
      body.appendChild(_row('Wick — Up', null,
          _colorPicker(p.bullWick, d.bullWick, (x) => _patchPalette({ bullWick: x || d.bullWick }))));
      body.appendChild(_row('Wick — Down', null,
          _colorPicker(p.bearWick, d.bearWick, (x) => _patchPalette({ bearWick: x || d.bearWick }))));
      body.appendChild(sect('Chart colors'));
      body.appendChild(_row('Background', 'Empty = theme default',
          _colorPicker(p.background, '#0B0F14', (x) => _patchPalette({ background: x }))));
      body.appendChild(_row('Text', 'Empty = theme default',
          _colorPicker(p.text, '#D1D5DB', (x) => _patchPalette({ text: x }))));
      body.appendChild(_row('Grid', 'Empty = theme default',
          _colorPicker(p.grid, '#1F2937', (x) => _patchPalette({ grid: x }))));
      body.appendChild(_row('Session break', 'Empty = theme default',
          _colorPicker(p.sessionBreak, '#374151', (x) => _patchPalette({ sessionBreak: x }))));
      body.appendChild(_row('Crosshair', 'Empty = theme default',
          _colorPicker(p.crosshair, '#9CA3AF', (x) => _patchPalette({ crosshair: x }))));
    }
  }

  const settingsBtn = document.createElement('button');
  settingsBtn.className = 'tb-chip tb-settings';
  settingsBtn.type = 'button';
  settingsBtn.title = 'Settings';
  settingsBtn.innerHTML = '<svg viewBox="0 0 24 24" width="14" height="14" '
      + 'fill="none" stroke="currentColor" stroke-width="2" '
      + 'stroke-linecap="round" stroke-linejoin="round">'
      + '<circle cx="12" cy="12" r="3"/>'
      + '<path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>';

  settingsBtn.addEventListener('click', () => {
    const content = document.createElement('div');
    content.className = 'tb-settings-popover-content';
    const title = document.createElement('div');
    title.className = 'tb-popover-title';
    title.textContent = 'Settings';
    content.appendChild(title);
    const sub = document.createElement('div');
    sub.className = 'tb-popover-subtitle';
    sub.textContent = 'Chart appearance and on-chart overlays';
    content.appendChild(sub);
    const tabs = document.createElement('div');
    tabs.className = 'tb-tabs';
    const tabSpecs = [
      { id: 'view',      label: 'View on chart' },
      { id: 'customize', label: 'Customize' },
    ];
    for (const t of tabSpecs) {
      const tab = document.createElement('button');
      tab.type = 'button';
      tab.className = 'tb-tab' + (t.id === settingsTab ? ' tb-tab--on' : '');
      tab.textContent = t.label;
      tab.addEventListener('click', () => {
        if (t.id === settingsTab) return;
        settingsTab = t.id;
        for (const el of tabs.querySelectorAll('.tb-tab')) {
          el.classList.remove('tb-tab--on');
        }
        tab.classList.add('tb-tab--on');
        _renderSettingsTab(_openPopover);
      });
      tabs.appendChild(tab);
    }
    content.appendChild(tabs);
    const body = document.createElement('div');
    body.className = 'tb-settings-body';
    content.appendChild(body);
    // Settings is large (380px + multi-tab body) and lives at the right
    // edge of the bar — anchoring to the button consistently overflows
    // the viewport. Opens as a centered modal instead.
    const pop = openModal(content);
    pop.classList.add('tb-settings-popover');
    pop.dataset.kind = 'settings';
    _renderSettingsTab(pop);
  });
  root.appendChild(settingsBtn);

  // ── Keyboard shortcuts help (?) ─────────────────────────────────────────
  // Icon-only "?" chip. On hover (or click) shows a popover listing every
  // chart keyboard shortcut, grouped. Hover-bridge: a short close delay so
  // moving the cursor from the button into the popover doesn't dismiss it.
  const helpBtn = document.createElement('button');
  helpBtn.className = 'tb-chip tb-help';
  helpBtn.type = 'button';
  helpBtn.title = 'Keyboard shortcuts';
  helpBtn.innerHTML = '<svg viewBox="0 0 24 24" width="14" height="14" '
      + 'fill="none" stroke="currentColor" stroke-width="2" '
      + 'stroke-linecap="round" stroke-linejoin="round">'
      + '<circle cx="12" cy="12" r="10"/>'
      + '<path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/>'
      + '<line x1="12" y1="17" x2="12.01" y2="17"/></svg>';

  let _helpPop = null;
  let _helpCloseTimer = null;

  function _buildShortcutsContent() {
    const wrap = document.createElement('div');
    wrap.className = 'tb-shortcuts';
    const title = document.createElement('div');
    title.className = 'tb-popover-title';
    title.textContent = 'Keyboard shortcuts';
    wrap.appendChild(title);
    const sub = document.createElement('div');
    sub.className = 'tb-popover-subtitle';
    sub.textContent = 'Enable shortcuts in Settings to use the trading + '
        + 'timeframe keys.';
    wrap.appendChild(sub);
    // [group heading] OR [keys, description]
    const rows = [
      ['Timeframes', null],
      ['1', '1 minute'],
      ['5', '5 minutes'],
      ['Shift + 1', '15 minutes'],
      ['H', '1 hour'],
      ['D', '1 day'],
      ['Trading', null],
      ['Alt + B', 'Quick buy'],
      ['Alt + S', 'Quick sell'],
      ['Alt + I', 'Toggle instant orders'],
      ['General', null],
      ['Esc', 'Cancel drawing / clear selection'],
    ];
    for (const [k, desc] of rows) {
      if (desc === null) {
        const h = document.createElement('div');
        h.className = 'tb-shortcuts-group';
        h.textContent = k;
        wrap.appendChild(h);
        continue;
      }
      const row = document.createElement('div');
      row.className = 'tb-shortcuts-row';
      const keys = document.createElement('span');
      keys.className = 'tb-kbd';
      keys.textContent = k;
      const label = document.createElement('span');
      label.className = 'tb-shortcuts-label';
      label.textContent = desc;
      row.appendChild(keys);
      row.appendChild(label);
      wrap.appendChild(row);
    }
    return wrap;
  }

  function _openHelp() {
    if (_helpCloseTimer) { clearTimeout(_helpCloseTimer); _helpCloseTimer = null; }
    if (_helpPop) return;
    const pop = document.createElement('div');
    pop.className = 'tb-popover tb-help-popover';
    pop.appendChild(_buildShortcutsContent());
    // Measure off-screen, then right-align to the button (it lives at the
    // right edge of the bar) and clamp inside the viewport.
    pop.style.left = '-9999px';
    pop.style.top = '0';
    document.body.appendChild(pop);
    const rect = helpBtn.getBoundingClientRect();
    const popW = pop.offsetWidth;
    const popH = pop.offsetHeight;
    const vw = document.documentElement.clientWidth;
    const vh = document.documentElement.clientHeight;
    const margin = 8;
    let left = rect.right - popW;
    if (left + popW + margin > vw) left = vw - popW - margin;
    if (left < margin) left = margin;
    let top = rect.bottom + 4;
    if (top + popH + margin > vh && rect.top - popH - 4 >= margin) {
      top = rect.top - popH - 4;
    }
    pop.style.left = left + 'px';
    pop.style.top = top + 'px';
    pop.addEventListener('mouseenter', () => {
      if (_helpCloseTimer) { clearTimeout(_helpCloseTimer); _helpCloseTimer = null; }
    });
    pop.addEventListener('mouseleave', _scheduleCloseHelp);
    _helpPop = pop;
  }

  function _scheduleCloseHelp() {
    if (_helpCloseTimer) clearTimeout(_helpCloseTimer);
    _helpCloseTimer = setTimeout(() => {
      if (_helpPop) { _helpPop.remove(); _helpPop = null; }
      _helpCloseTimer = null;
    }, 160);
  }

  helpBtn.addEventListener('mouseenter', _openHelp);
  helpBtn.addEventListener('mouseleave', _scheduleCloseHelp);
  // Click toggles too — covers touch + keyboard-focus users.
  helpBtn.addEventListener('click', () => {
    if (_helpPop) _scheduleCloseHelp();
    else _openHelp();
  });
  root.appendChild(helpBtn);

  // ── Order Defaults button + tabbed popover ──────────────────────────────
  // Flutter pushes the full bag via `setOrderDefaults`. Each field change
  // here posts `updateOrderDefaults: {field: value}` as a partial patch;
  // Flutter's dispatcher routes to the right setter on the notifier and
  // the mirror flows back.
  let orderDefaults = {
    autoStopLoss: false, slType: 'SL_LMT', slTrigger: 'points',
    slTriggerValue: 10.0, trailingSL: false, trailingMove: 1.0,
    trailingFor: 1.0, autoTakeProfit: false, tpType: 'TP_LMT',
    tpTriggerValue: 20.0,
    equityDefaultQty: 1, futuresDefaultQty: 1, optionsDefaultQty: 1,
    equityProduct: 'I', futuresProduct: 'I', optionsProduct: 'I',
  };
  bridge.on('setOrderDefaults', (v) => {
    if (!v || typeof v !== 'object') return;
    orderDefaults = Object.assign({}, orderDefaults, v);
    if (_openPopover && _openPopover.dataset.kind === 'orderDefaults') {
      _renderOrderDefaultsTab(_openPopover);
    }
  });
  function _patchOd(patch) {
    Object.assign(orderDefaults, patch);
    bridge.post('updateOrderDefaults', patch);
    if (_openPopover && _openPopover.dataset.kind === 'orderDefaults') {
      _renderOrderDefaultsTab(_openPopover);
    }
  }

  let odTab = 'slTp';   // 'slTp' | 'qty' | 'product'

  function _renderOrderDefaultsTab(pop) {
    const body = pop.querySelector('.tb-od-body');
    if (!body) return;
    body.innerHTML = '';
    const d = orderDefaults;
    if (odTab === 'slTp') {
      body.appendChild(_row('Auto Stop Loss',
          'Adds a stop-loss leg to every order',
          _switch(d.autoStopLoss, (v) => _patchOd({ autoStopLoss: v }))));
      body.appendChild(_row('SL Type',
          'Limit fires at price, Market fires immediately',
          _segmented(d.slType, [
            { value: 'SL_LMT', label: 'SL Limit' },
            { value: 'SL_MKT', label: 'SL Market' },
          ], (v) => _patchOd({ slType: v }))));
      body.appendChild(_row('SL Trigger',
          'How the trigger distance is measured',
          _segmented(d.slTrigger, [
            { value: 'points',  label: 'Points' },
            { value: 'percent', label: 'Percent' },
            { value: 'ticks',   label: 'Ticks' },
          ], (v) => _patchOd({ slTrigger: v }))));
      body.appendChild(_row('Trigger value',
          d.slTrigger === 'percent' ? 'Percent below entry'
              : d.slTrigger === 'ticks' ? 'Ticks below entry'
              : 'Points below entry',
          _numberStepper(d.slTriggerValue, {
            min: 0, max: 100000,
            step: d.slTrigger === 'percent' ? 0.5 : 1.0,
            decimals: d.slTrigger === 'percent' ? 1 : 0,
          }, (v) => _patchOd({ slTriggerValue: v }))));
      body.appendChild(_row('Trailing SL',
          'SL moves by X for every Y move in LTP',
          _switch(d.trailingSL, (v) => _patchOd({ trailingSL: v }))));
      if (d.trailingSL) {
        body.appendChild(_row('SL moves by',
            'Points the SL shifts per trigger',
            _numberStepper(d.trailingMove, { min: 0, max: 1000, step: 0.5, decimals: 1 },
                (v) => _patchOd({ trailingMove: v }))));
        body.appendChild(_row('For every',
            'LTP move that triggers the shift',
            _numberStepper(d.trailingFor, { min: 0, max: 1000, step: 0.5, decimals: 1 },
                (v) => _patchOd({ trailingFor: v }))));
      }
      body.appendChild(_row('Auto Take Profit',
          'Adds a take-profit leg to every order',
          _switch(d.autoTakeProfit, (v) => _patchOd({ autoTakeProfit: v }))));
      body.appendChild(_row('TP Type',
          'Limit fires at price, Market fires immediately',
          _segmented(d.tpType, [
            { value: 'TP_LMT', label: 'TP Limit' },
            { value: 'TP_MKT', label: 'TP Market' },
          ], (v) => _patchOd({ tpType: v }))));
      body.appendChild(_row('TP value',
          'Points above entry',
          _numberStepper(d.tpTriggerValue, { min: 0, max: 100000, step: 1, decimals: 0 },
              (v) => _patchOd({ tpTriggerValue: v }))));
    } else if (odTab === 'qty') {
      body.appendChild(_row('Equity',
          'Default quantity for equity orders',
          _numberStepper(d.equityDefaultQty, { min: 1, max: 100000, step: 1 },
              (v) => _patchOd({ equityDefaultQty: v }))));
      body.appendChild(_row('Futures',
          'Default lot count for futures orders',
          _numberStepper(d.futuresDefaultQty, { min: 1, max: 1000, step: 1 },
              (v) => _patchOd({ futuresDefaultQty: v }))));
      body.appendChild(_row('Options',
          'Default lot count for options orders',
          _numberStepper(d.optionsDefaultQty, { min: 1, max: 1000, step: 1 },
              (v) => _patchOd({ optionsDefaultQty: v }))));
    } else if (odTab === 'product') {
      body.appendChild(_row('Equity', 'Delivery or Intraday',
          _segmented(d.equityProduct, [
            { value: 'C', label: 'Delivery' },
            { value: 'I', label: 'Intraday' },
          ], (v) => _patchOd({ equityProduct: v }))));
      body.appendChild(_row('Futures', 'Normal or Intraday',
          _segmented(d.futuresProduct, [
            { value: 'M', label: 'Normal' },
            { value: 'I', label: 'Intraday' },
          ], (v) => _patchOd({ futuresProduct: v }))));
      body.appendChild(_row('Options', 'Normal or Intraday',
          _segmented(d.optionsProduct, [
            { value: 'M', label: 'Normal' },
            { value: 'I', label: 'Intraday' },
          ], (v) => _patchOd({ optionsProduct: v }))));
    }
  }

  const odBtn = document.createElement('button');
  odBtn.className = 'tb-chip tb-od';
  odBtn.type = 'button';
  odBtn.title = 'Order defaults';
  odBtn.innerHTML = '<svg viewBox="0 0 24 24" width="13" height="13" '
      + 'fill="none" stroke="currentColor" stroke-width="2" '
      + 'stroke-linecap="round" stroke-linejoin="round">'
      + '<path d="M3 6h18M3 12h18M3 18h18"/></svg>'
      + '<span>Order Defaults</span>';

  odBtn.addEventListener('click', () => {
    const content = document.createElement('div');
    content.className = 'tb-od-popover-content';

    const title = document.createElement('div');
    title.className = 'tb-popover-title';
    title.textContent = 'Order Defaults';
    content.appendChild(title);
    const sub = document.createElement('div');
    sub.className = 'tb-popover-subtitle';
    sub.textContent = 'Applies to every new order placed from the chart';
    content.appendChild(sub);

    // Tabs.
    const tabs = document.createElement('div');
    tabs.className = 'tb-tabs';
    const tabSpecs = [
      { id: 'slTp',    label: 'SL / TP' },
      { id: 'qty',     label: 'Quantity' },
      { id: 'product', label: 'Product Type' },
    ];
    for (const t of tabSpecs) {
      const tab = document.createElement('button');
      tab.type = 'button';
      tab.className = 'tb-tab' + (t.id === odTab ? ' tb-tab--on' : '');
      tab.textContent = t.label;
      tab.addEventListener('click', () => {
        if (t.id === odTab) return;
        odTab = t.id;
        for (const el of tabs.querySelectorAll('.tb-tab')) {
          el.classList.remove('tb-tab--on');
        }
        tab.classList.add('tb-tab--on');
        _renderOrderDefaultsTab(_openPopover);
      });
      tabs.appendChild(tab);
    }
    content.appendChild(tabs);

    const body = document.createElement('div');
    body.className = 'tb-od-body';
    content.appendChild(body);

    // Order Defaults is also large (420px) — open as a centered modal
    // so it doesn't overflow the right edge of the viewport. Matches
    // the Settings behavior.
    const pop = openModal(content);
    pop.classList.add('tb-od-popover');
    pop.dataset.kind = 'orderDefaults';
    _renderOrderDefaultsTab(pop);
  });

  root.appendChild(odBtn);

  // ── Draw button + popover ───────────────────────────────────────────────
  // Session-level state (NOT per-pane): activeDrawTool, drawingsLocked,
  // drawingsHidden. Flutter already pushes setDrawMode / setDrawingsLocked /
  // setDrawingsHidden via the diff-based _pushSession, so we just listen
  // here and post the same names back when the user clicks.
  const DRAW_TOOLS = [
    { kind: 'trendline', label: 'Trendline' },
    { kind: 'hline',     label: 'Horizontal line' },
    { kind: 'hray',      label: 'Horizontal ray' },
    { kind: 'rect',      label: 'Rectangle' },
    { kind: 'fib',       label: 'Fib retracement' },
    { kind: 'path',      label: 'Path (multi-point)' },
    { kind: 'measure',   label: 'Measure' },
  ];
  const DRAW_TOOL_SHORT = {
    trendline: 'Trendline',
    hline: 'HLine',
    hray: 'H.Ray',
    rect: 'Rectangle',
    fib: 'Fib',
    path: 'Path',
    measure: 'Measure',
  };
  let drawTool = null;
  let drawLocked = false;
  let drawHidden = false;

  const drawBtn = document.createElement('button');
  drawBtn.className = 'tb-chip tb-draw';
  drawBtn.type = 'button';
  drawBtn.title = 'Draw';
  drawBtn.innerHTML = '<svg viewBox="0 0 24 24" width="13" height="13" '
      + 'fill="none" stroke="currentColor" stroke-width="2" '
      + 'stroke-linecap="round" stroke-linejoin="round">'
      + '<path d="M12 19l7-7 3 3-7 7-3-3z"/>'
      + '<path d="M18 13l-1.5-7.5L2 2l3.5 14.5L13 18l5-5z"/>'
      + '<path d="M2 2l7.586 7.586"/>'
      + '<circle cx="11" cy="11" r="2"/></svg>'
      + '<span class="tb-draw-label">Draw</span>';
  const drawLabelEl = drawBtn.querySelector('.tb-draw-label');

  function repaintDrawButton() {
    const on = drawTool != null;
    drawBtn.classList.toggle('tb-draw--on', on);
    drawLabelEl.textContent = on
        ? ('Drawing: ' + (DRAW_TOOL_SHORT[drawTool] || drawTool))
        : 'Draw';
  }
  repaintDrawButton();

  bridge.on('setDrawMode', (v) => {
    const next = (v && typeof v.kind === 'string') ? v.kind : null;
    if (next === drawTool) return;
    drawTool = next;
    repaintDrawButton();
  });
  bridge.on('setDrawingsLocked', (v) => {
    const next = !!(v && v.locked);
    if (next === drawLocked) return;
    drawLocked = next;
    if (_openPopover && _openPopover.dataset.kind === 'draw') {
      _repaintDrawBottomToolbar();
    }
  });
  bridge.on('setDrawingsHidden', (v) => {
    const next = !!(v && v.hidden);
    if (next === drawHidden) return;
    drawHidden = next;
    if (_openPopover && _openPopover.dataset.kind === 'draw') {
      _repaintDrawBottomToolbar();
    }
  });

  function _repaintDrawBottomToolbar() {
    if (!_openPopover) return;
    const lockBtn = _openPopover.querySelector('.tb-draw-action[data-act="lock"]');
    if (lockBtn) {
      lockBtn.querySelector('.tb-draw-action-label').textContent =
          drawLocked ? 'Unlock' : 'Lock';
    }
    const hideBtn = _openPopover.querySelector('.tb-draw-action[data-act="hide"]');
    if (hideBtn) {
      hideBtn.querySelector('.tb-draw-action-label').textContent =
          drawHidden ? 'Show' : 'Hide';
    }
  }

  drawBtn.addEventListener('click', () => {
    // If a tool is active, the button acts as a one-tap cancel.
    if (drawTool != null) {
      drawTool = null;
      repaintDrawButton();
      bridge.post('setActiveDrawTool', { kind: null });
      return;
    }
    // Otherwise open the picker popover.
    const content = document.createElement('div');
    content.className = 'tb-draw-popover-content';

    const title = document.createElement('div');
    title.className = 'tb-popover-title';
    title.textContent = 'Draw';
    content.appendChild(title);
    const sub = document.createElement('div');
    sub.className = 'tb-popover-subtitle';
    sub.textContent = 'Pick a tool, then click on the chart';
    content.appendChild(sub);

    const section = document.createElement('div');
    section.className = 'tb-popover-section-label';
    section.textContent = 'Tools';
    content.appendChild(section);

    for (const t of DRAW_TOOLS) {
      const row = document.createElement('button');
      row.type = 'button';
      row.className = 'tb-list-row';
      row.innerHTML = '<span class="tb-list-row-label">' + t.label + '</span>';
      row.addEventListener('click', () => {
        drawTool = t.kind;
        repaintDrawButton();
        _closeOpenPopover();
        bridge.post('setActiveDrawTool', { kind: t.kind });
      });
      content.appendChild(row);
    }

    const divider = document.createElement('div');
    divider.className = 'tb-popover-divider';
    content.appendChild(divider);

    const bottomBar = document.createElement('div');
    bottomBar.className = 'tb-draw-actions';
    bottomBar.innerHTML =
        '<button type="button" class="tb-draw-action" data-act="lock">'
          + '<span class="tb-draw-action-icon">🔒</span>'
          + '<span class="tb-draw-action-label">' + (drawLocked ? 'Unlock' : 'Lock') + '</span>'
        + '</button>'
        + '<button type="button" class="tb-draw-action" data-act="hide">'
          + '<span class="tb-draw-action-icon">👁</span>'
          + '<span class="tb-draw-action-label">' + (drawHidden ? 'Show' : 'Hide') + '</span>'
        + '</button>'
        + '<button type="button" class="tb-draw-action tb-draw-action--danger" data-act="trash">'
          + '<span class="tb-draw-action-icon">🗑</span>'
          + '<span class="tb-draw-action-label">Trash</span>'
        + '</button>';
    bottomBar.querySelector('[data-act="lock"]').addEventListener('click', () => {
      const next = !drawLocked;
      drawLocked = next;
      _repaintDrawBottomToolbar();
      _closeOpenPopover();
      bridge.post('setDrawingsLocked', { value: next });
    });
    bottomBar.querySelector('[data-act="hide"]').addEventListener('click', () => {
      const next = !drawHidden;
      drawHidden = next;
      _repaintDrawBottomToolbar();
      _closeOpenPopover();
      bridge.post('setDrawingsHidden', { value: next });
    });
    bottomBar.querySelector('[data-act="trash"]').addEventListener('click', () => {
      _closeOpenPopover();
      bridge.post('clearDrawingsForActivePane', {});
    });
    content.appendChild(bottomBar);

    const pop = openPopover(drawBtn, content);
    pop.classList.add('tb-draw-popover');
    pop.dataset.kind = 'draw';
  });

  root.appendChild(drawBtn);

  // ── Indicators (fx) button + popover ────────────────────────────────────
  // Catalog is static client-side (matches the Flutter table). On pick we
  // post `addIndicatorByKind: {kind}` and Flutter applies the shared
  // default color + period; the new entry comes back via the active-pane
  // mirror so the picker's "Active" list refreshes automatically.
  const INDICATOR_CATALOG = [
    { kind: 'sma',      label: 'SMA',    fullName: 'Simple Moving Average',         category: 'trend' },
    { kind: 'ema',      label: 'EMA',    fullName: 'Exponential Moving Average',    category: 'trend' },
    { kind: 'bb',       label: 'BB',     fullName: 'Bollinger Bands',               category: 'trend' },
    { kind: 'vwap',     label: 'VWAP',   fullName: 'Volume Weighted Average Price', category: 'trend' },
    { kind: 'zlema',    label: 'ZLEMA',  fullName: 'Zero-Lag Exponential MA',       category: 'trend' },
    { kind: 'mcginley', label: 'MGD',    fullName: 'McGinley Dynamic',              category: 'trend' },
    { kind: 'ribbon',   label: 'RIBBON', fullName: 'EMA Ribbon (8 lines)',          category: 'trend' },
    { kind: 'ichi',     label: 'ICHI',   fullName: 'Ichimoku Cloud',                category: 'trend' },
    { kind: 'vstop',    label: 'VSTOP',  fullName: 'Volatility Stop (ATR trailing)', category: 'trend' },
    { kind: 'rsi',      label: 'RSI',    fullName: 'Relative Strength Index',       category: 'momentum' },
    { kind: 'macd',     label: 'MACD',   fullName: 'Moving Average Convergence',    category: 'momentum' },
    { kind: 'stoch',    label: 'STOCH',  fullName: 'Stochastic Oscillator',         category: 'momentum' },
    { kind: 'stochrsi', label: 'SRSI',   fullName: 'Stochastic RSI',                category: 'momentum' },
    { kind: 'squeeze',  label: 'SQZ',    fullName: 'Squeeze Momentum',              category: 'momentum' },
    { kind: 'efi',      label: 'EFI',    fullName: "Elder's Force Index",           category: 'momentum' },
    { kind: 'wt',       label: 'WT',     fullName: 'WaveTrend Oscillator',          category: 'momentum' },
    { kind: 'crsi',     label: 'CRSI',   fullName: 'Connors RSI',                   category: 'momentum' },
    { kind: 'ao',       label: 'AO',     fullName: 'Awesome Oscillator',            category: 'momentum' },
    { kind: 'mfi',      label: 'MFI',    fullName: 'Money Flow Index',              category: 'momentum' },
    { kind: 'obv',      label: 'OBV',    fullName: 'On-Balance Volume',             category: 'momentum' },
    { kind: 'cmf',      label: 'CMF',    fullName: 'Chaikin Money Flow',            category: 'momentum' },
    { kind: 'wr',       label: 'WR',     fullName: 'Williams %R',                   category: 'momentum' },
    { kind: 'atr',      label: 'ATR',    fullName: 'Average True Range',            category: 'volatility' },
    { kind: 'cisd',     label: 'CISD',   fullName: 'Change in State of Delivery',   category: 'momentum' },
    { kind: 'fvg',      label: 'FVG',    fullName: 'Fair Value Gap (ICT)',          category: 'momentum' },
    { kind: 'ob',       label: 'OB',     fullName: 'Order Block (ICT/SMC)',         category: 'momentum' },
    { kind: 'liqsweep', label: 'LIQ',    fullName: 'Liquidity Sweep (ICT)',         category: 'momentum' },
    { kind: 'mss',      label: 'MSS',    fullName: 'Market Structure (BOS/CHoCH/MSS)', category: 'momentum' },
  ];
  const INDICATOR_CATEGORIES = [
    { value: 'all',        label: 'All' },
    { value: 'trend',      label: 'Trend' },
    { value: 'momentum',   label: 'Momentum' },
    { value: 'volatility', label: 'Volatility' },
  ];

  const fxBtn = document.createElement('button');
  fxBtn.className = 'tb-chip tb-fx';
  fxBtn.type = 'button';
  fxBtn.title = 'Indicators';
  fxBtn.innerHTML = '<span class="tb-fx-icon">ƒx</span>';

  // Popover state lives outside the open handler so live mirror pushes can
  // re-render the Active list without closing.
  let fxState = { search: '', category: 'all' };

  function _renderFxList(pop) {
    const activeList = pop.querySelector('.tb-fx-active');
    const catalogList = pop.querySelector('.tb-fx-catalog');
    const sectionLabel = pop.querySelector('.tb-fx-catalog-label');
    if (!catalogList || !sectionLabel) return;

    const q = fxState.search.trim().toLowerCase();
    const filtered = INDICATOR_CATALOG.filter((c) => {
      if (fxState.category !== 'all' && c.category !== fxState.category) {
        return false;
      }
      if (!q) return true;
      return c.label.toLowerCase().includes(q)
          || c.kind.toLowerCase().includes(q)
          || c.fullName.toLowerCase().includes(q);
    });

    // Active section — present when activePaneState.indicators isn't empty.
    if (activeList) {
      const activeWrap = pop.querySelector('.tb-fx-active-wrap');
      if (activeWrap) {
        activeWrap.style.display =
            activePaneState.indicators.length === 0 ? 'none' : '';
      }
      activeList.innerHTML = '';
      for (const ind of activePaneState.indicators) {
        const row = document.createElement('div');
        row.className = 'tb-fx-active-row';
        row.innerHTML = '<span class="tb-fx-swatch" style="background:'
            + (ind.color || '#3B82F6') + '"></span>'
            + '<span class="tb-fx-active-name">' + (ind.kind || '').toUpperCase() + '</span>'
            + (ind.period > 0
                ? '<span class="tb-fx-active-period">' + ind.period + '</span>'
                : '')
            + '<button type="button" class="tb-fx-remove" title="Remove">'
            + '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" '
            + 'stroke="currentColor" stroke-width="2" stroke-linecap="round" '
            + 'stroke-linejoin="round">'
            + '<polyline points="3 6 5 6 21 6"/>'
            + '<path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>'
            + '<path d="M10 11v6M14 11v6"/></svg></button>';
        row.querySelector('.tb-fx-remove').addEventListener('click', () => {
          bridge.post('removeIndicatorById', { id: ind.id });
        });
        activeList.appendChild(row);
      }
    }

    // Catalog section.
    sectionLabel.textContent = filtered.length === 0
        ? 'No matches' : 'All indicators';
    catalogList.innerHTML = '';
    if (filtered.length === 0) {
      const empty = document.createElement('div');
      empty.className = 'tb-fx-empty';
      empty.textContent = 'Try a different search or category.';
      catalogList.appendChild(empty);
    } else {
      for (const c of filtered) {
        const row = document.createElement('button');
        row.type = 'button';
        row.className = 'tb-fx-catalog-row';
        row.innerHTML = '<div class="tb-fx-catalog-text">'
            + '<div class="tb-fx-catalog-label">' + c.label + '</div>'
            + '<div class="tb-fx-catalog-full">' + c.fullName + '</div>'
            + '</div>'
            + '<span class="tb-fx-catalog-add">+</span>';
        row.addEventListener('click', () => {
          bridge.post('addIndicatorByKind', { kind: c.kind });
          // Don't close — user can add several in a row.
        });
        catalogList.appendChild(row);
      }
    }
  }

  // Re-render the Active list while the popover is open and the mirror
  // pushes a new indicators array (post-add / post-remove).
  activePaneSubs.push(() => {
    if (_openPopover && _openPopover.dataset.kind === 'fx') {
      _renderFxList(_openPopover);
    }
  });

  fxBtn.addEventListener('click', () => {
    const content = document.createElement('div');
    content.className = 'tb-fx-popover-content';

    const title = document.createElement('div');
    title.className = 'tb-popover-title';
    title.textContent = 'Indicators';
    content.appendChild(title);
    const sub = document.createElement('div');
    sub.className = 'tb-popover-subtitle';
    sub.textContent = 'Add overlays and oscillators to the active pane';
    content.appendChild(sub);

    const searchWrap = document.createElement('div');
    searchWrap.className = 'tb-fx-search-wrap';
    const search = document.createElement('input');
    search.type = 'text';
    search.placeholder = 'Search indicators…';
    search.className = 'tb-fx-search';
    search.value = fxState.search;
    search.addEventListener('input', () => {
      fxState.search = search.value;
      _renderFxList(_openPopover);
    });
    searchWrap.appendChild(search);
    content.appendChild(searchWrap);

    const catRow = document.createElement('div');
    catRow.className = 'tb-fx-categories';
    for (const cat of INDICATOR_CATEGORIES) {
      const chip = document.createElement('button');
      chip.type = 'button';
      chip.className = 'tb-fx-cat-chip';
      if (cat.value === fxState.category) chip.classList.add('tb-fx-cat-chip--on');
      chip.textContent = cat.label;
      chip.addEventListener('click', () => {
        fxState.category = cat.value;
        for (const c of catRow.querySelectorAll('.tb-fx-cat-chip')) {
          c.classList.remove('tb-fx-cat-chip--on');
        }
        chip.classList.add('tb-fx-cat-chip--on');
        _renderFxList(_openPopover);
      });
      catRow.appendChild(chip);
    }
    content.appendChild(catRow);

    const activeWrap = document.createElement('div');
    activeWrap.className = 'tb-fx-active-wrap';
    const activeLabel = document.createElement('div');
    activeLabel.className = 'tb-popover-section-label';
    activeLabel.textContent = 'Active';
    activeWrap.appendChild(activeLabel);
    const activeList = document.createElement('div');
    activeList.className = 'tb-fx-active';
    activeWrap.appendChild(activeList);
    content.appendChild(activeWrap);

    const divider = document.createElement('div');
    divider.className = 'tb-popover-divider';
    content.appendChild(divider);

    const catalogLabel = document.createElement('div');
    catalogLabel.className = 'tb-popover-section-label tb-fx-catalog-label';
    catalogLabel.textContent = 'All indicators';
    content.appendChild(catalogLabel);
    const catalogList = document.createElement('div');
    catalogList.className = 'tb-fx-catalog';
    content.appendChild(catalogList);

    const pop = openPopover(fxBtn, content);
    pop.classList.add('tb-fx-popover');
    pop.dataset.kind = 'fx';
    _renderFxList(pop);
    // Autofocus the search field for keyboard-first add.
    setTimeout(() => search.focus(), 0);
  });

  root.appendChild(fxBtn);

  // ── Snap (screenshot) ───────────────────────────────────────────────────
  // Directly drives the active pane's takeScreenshot() — no Flutter round
  // trip to decide which pane (the iframe knows its own active state). The
  // chart.takeScreenshot impl still messages Flutter for the actual file
  // download (the anchor click). One-shot, no state.
  const snapBtn = document.createElement('button');
  snapBtn.className = 'tb-chip tb-snap';
  snapBtn.type = 'button';
  snapBtn.innerHTML = '<svg viewBox="0 0 24 24" width="14" height="14" '
      + 'fill="none" stroke="currentColor" stroke-width="2" '
      + 'stroke-linecap="round" stroke-linejoin="round">'
      + '<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>'
      + '<circle cx="12" cy="13" r="4"/></svg>';
  snapBtn.title = 'Screenshot active pane';
  snapBtn.addEventListener('click', () => {
    const chart = (window.chartEngine && window.chartEngine.activeChart());
    if (chart && typeof chart.takeScreenshot === 'function') {
      chart.takeScreenshot();
    }
  });
  root.appendChild(snapBtn);

  // ── INSTANT toggle ──────────────────────────────────────────────────────
  const INSTANT_KEY = 'chartEngineTopBarV1.instantOrders';
  let instantOn = (function () {
    try { return localStorage.getItem(INSTANT_KEY) === '1'; }
    catch (_) { return false; }
  })();

  const badge = document.createElement('button');
  badge.className = 'tb-chip tb-instant';
  badge.type = 'button';
  badge.innerHTML = '<span class="tb-instant-icon">⚠</span> INSTANT';
  badge.title = 'Skip confirmation for cancels, exits, drags';

  function paintInstant() {
    badge.classList.toggle('tb-instant--on', instantOn);
  }
  paintInstant();

  function persistInstant() {
    try { localStorage.setItem(INSTANT_KEY, instantOn ? '1' : '0'); }
    catch (_) {}
  }

  badge.addEventListener('click', async () => {
    if (instantOn) {
      // OFF direction — no gate. Fire-and-forget.
      instantOn = false;
      persistInstant();
      paintInstant();
      bridge.post('instantOrdersChanged', { value: false });
      return;
    }
    // ON direction — ask Flutter to run its warning-ack gate. If accepted,
    // we apply locally; if declined or it times out, we stay off.
    badge.disabled = true;
    try {
      const reply = await bridge.request('confirmInstantOrders', {});
      if (reply && reply.confirmed === true) {
        instantOn = true;
        persistInstant();
        paintInstant();
        bridge.post('instantOrdersChanged', { value: true });
      }
    } catch (_) {
      // Timeout / Flutter rejected — leave state untouched.
    } finally {
      badge.disabled = false;
    }
  });

  // Outside source of truth — Flutter pushes `setInstantOrders` on
  // bootstrap (initial sync) and whenever the provider state changes for
  // any reason other than this badge (e.g. user toggled it inside the
  // Settings panel that still lives in Flutter for now).
  bridge.on('setInstantOrders', (v) => {
    const next = !!(v && v.value);
    if (next === instantOn) return;
    instantOn = next;
    persistInstant();
    paintInstant();
  });

  root.appendChild(badge);

  // ── Final layout pass ───────────────────────────────────────────────────
  // Reorder children to the canonical sequence per user spec:
  //   [Symbol] [Timeframe] [Style] [fx] [Draw] [Cursor]
  //       ...flex spacer...
  //   [Layout] [INSTANT] [Order Defaults] [Snap] [Settings]
  // `appendChild` of an existing child MOVES it (doesn't create a duplicate);
  // the first right-group button gets `.tb-right-start` which applies
  // `margin-left: auto` for the flex spacer.
  const ORDER = [
    symWrap, tfBtn, styleBtn, fxBtn, drawBtn, cursorBtn,
    layoutBtn, badge, odBtn, snapBtn, settingsBtn, helpBtn,
  ];
  // Move the right-anchor class — Layout is now the first right-group
  // button instead of the INSTANT badge.
  badge.classList.remove('tb-right-start');
  layoutBtn.classList.add('tb-right-start');
  for (const el of ORDER) root.appendChild(el);
})();
