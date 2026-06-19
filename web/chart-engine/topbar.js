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

  // Flyout that opens to the RIGHT of an anchor (used by the left drawing
  // rail). Same close/outside-click machinery as openPopover, but positioned
  // beside the icon instead of below it.
  function openFlyoutRight(anchorEl, content) {
    const sameAnchorOpen = _openPopover != null && _openAnchor === anchorEl;
    _closeOpenPopover();
    if (sameAnchorOpen) return null;
    const pop = document.createElement('div');
    pop.className = 'tb-popover';
    pop.appendChild(content);
    pop.style.left = '-9999px';
    pop.style.top = '0';
    document.body.appendChild(pop);
    const popW = pop.offsetWidth, popH = pop.offsetHeight;
    const vw = document.documentElement.clientWidth;
    const vh = document.documentElement.clientHeight;
    const margin = 8;
    const rect = anchorEl.getBoundingClientRect();
    let left = rect.right + 6;
    if (left + popW + margin > vw) left = rect.left - popW - 6;
    if (left < margin) left = margin;
    let top = rect.top;
    if (top + popH + margin > vh) top = Math.max(margin, vh - popH - margin);
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
      const section = document.createElement('div');
      section.className = 'tb-layout-section';
      const sectionLbl = document.createElement('div');
      sectionLbl.className = 'tb-layout-section-label';
      sectionLbl.textContent = count === 1
          ? 'Single'
          : `${count} Panes`;
      section.appendChild(sectionLbl);
      const grid = document.createElement('div');
      grid.className = 'tb-layout-row-grid';
      for (const spec of groups.get(count)) {
        const tile = document.createElement('button');
        tile.type = 'button';
        tile.className = 'tb-layout-tile';
        if (spec.id === activeLayoutId) tile.classList.add('tb-layout-tile--on');
        const tc = document.createElement('canvas');
        tc.width = 28; tc.height = 28;
        tc.style.width = '28px'; tc.style.height = '28px';
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
      section.appendChild(grid);
      content.appendChild(section);
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
  // (Exchange is shown in the on-chart header — no separate badge here.)
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

  function longTimeframeLabel(min) {
    if (min < 60) return min + (min === 1 ? ' minute' : ' minutes');
    if (min < 1440) {
      const h = Math.floor(min / 60);
      return h + (h === 1 ? ' hour' : ' hours');
    }
    if (min === 10080) return '1 week';
    if (min === 43200) return '1 month';
    const d = Math.floor(min / 1440);
    return d + (d === 1 ? ' day' : ' days');
  }
  const TF_GROUPS = [
    { title: 'MINUTES', items: TIMEFRAMES.filter(t => t.minutes < 60) },
    { title: 'HOURS',
      items: TIMEFRAMES.filter(t => t.minutes >= 60 && t.minutes < 1440) },
    { title: 'DAYS', items: TIMEFRAMES.filter(t => t.minutes >= 1440) },
  ];
  const tfSectionExpanded = {
    MINUTES: true, HOURS: true, DAYS: true,
  };

  tfBtn.addEventListener('click', () => {
    const content = document.createElement('div');
    content.className = 'tb-list tb-tf-list';
    for (const g of TF_GROUPS) {
      const header = document.createElement('button');
      header.type = 'button';
      header.className = 'tb-list-section';
      const itemsWrap = document.createElement('div');
      itemsWrap.className = 'tb-list-section-items';
      function renderHeader() {
        const expanded = tfSectionExpanded[g.title];
        header.classList.toggle('tb-list-section--collapsed', !expanded);
        itemsWrap.style.display = expanded ? '' : 'none';
        const points = expanded ? '6 15 12 9 18 15' : '6 9 12 15 18 9';
        header.innerHTML = '<span class="tb-list-section-title">' + g.title
            + '</span><svg viewBox="0 0 24 24" width="12" height="12" '
            + 'fill="none" stroke="currentColor" stroke-width="2.2" '
            + 'stroke-linecap="round" stroke-linejoin="round" '
            + 'class="tb-list-section-icon">'
            + '<polyline points="' + points + '"/></svg>';
      }
      header.addEventListener('click', (ev) => {
        ev.stopPropagation();
        tfSectionExpanded[g.title] = !tfSectionExpanded[g.title];
        renderHeader();
      });
      renderHeader();
      content.appendChild(header);
      for (const t of g.items) {
        const row = document.createElement('button');
        row.type = 'button';
        row.className = 'tb-list-row tb-tf-row';
        if (t.minutes === activePaneState.timeframeMinutes) {
          row.classList.add('tb-list-row--on');
        }
        row.innerHTML = '<span class="tb-list-row-label">'
            + longTimeframeLabel(t.minutes) + '</span>';
        row.addEventListener('click', () => {
        _closeOpenPopover();
        if (t.minutes === activePaneState.timeframeMinutes) return;
        activePaneState.timeframeMinutes = t.minutes;
        repaintTimeframe();
        bridge.post('setActiveTimeframe', { minutes: t.minutes });
      });
        itemsWrap.appendChild(row);
      }
      content.appendChild(itemsWrap);
    }
    const pop = openPopover(tfBtn, content);
    pop.classList.add('tb-timeframe-popover');
  });
  root.appendChild(tfBtn);

  // ── Style picker (Candle / Hollow / Bars / Line / Area / Heikin Ashi) ──
  const _styleIcon = (paths) =>
      '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" '
      + 'stroke="currentColor" stroke-width="1.7" stroke-linecap="round" '
      + 'stroke-linejoin="round">' + paths + '</svg>';
  const STYLES = [
    { id: 'bars',        label: 'Bars', group: 'bars', svg: _styleIcon(
        '<path d="M7 5v14M7 9h3M7 14H4"/>'
        + '<path d="M17 7v14M17 11h3M17 16h-3"/>') },
    { id: 'candles',     label: 'Candles', group: 'bars', svg: _styleIcon(
        '<path d="M8 4v4M8 14v6M16 4v8M16 18v2"/>'
        + '<rect x="6" y="8" width="4" height="6" rx="1"/>'
        + '<rect x="14" y="12" width="4" height="6" rx="1"/>') },
    { id: 'hollow',      label: 'Hollow candles', group: 'bars',
      svg: _styleIcon(
        '<path d="M8 4v4M8 14v6M16 4v8M16 18v2"/>'
        + '<rect x="6" y="8" width="4" height="6" rx="1" fill="none"/>'
        + '<rect x="14" y="12" width="4" height="6" rx="1" fill="none"/>') },
    { id: 'line',        label: 'Line', group: 'line', svg: _styleIcon(
        '<path d="M4 16l5-6 4 3 7-8"/>') },
    { id: 'area',        label: 'Area', group: 'area', svg: _styleIcon(
        '<path d="M3 17l5-6 4 3 4-5 5 4v4H3z" fill="currentColor" '
        + 'fill-opacity="0.18"/>'
        + '<path d="M3 17l5-6 4 3 4-5 5 4"/>') },
    { id: 'heikin-ashi', label: 'Heikin Ashi', group: 'other',
      svg: _styleIcon(
        '<path d="M8 4v4M8 14v6M16 4v8M16 18v2"/>'
        + '<rect x="6" y="8" width="4" height="6" rx="1"/>'
        + '<rect x="14" y="12" width="4" height="6" rx="1" fill="none"/>') },
    { id: 'baseline',    label: 'Baseline', group: 'area', svg: _styleIcon(
        '<path d="M3 17l5-6 4 3 4-5 5 4v4H3z" fill="currentColor" '
        + 'fill-opacity="0.18"/>'
        + '<path d="M3 17l5-6 4 3 4-5 5 4"/>'
        + '<path d="M3 14h18" stroke-dasharray="2 2"/>') },
    { id: 'step',        label: 'Step line', group: 'line', svg: _styleIcon(
        '<path d="M3 18h4v-4h4v-3h4v-4h6"/>') },
    { id: 'columns',     label: 'Columns', group: 'bars', svg: _styleIcon(
        '<rect x="4" y="10" width="3" height="10" rx="0.5"/>'
        + '<rect x="10" y="6" width="3" height="14" rx="0.5"/>'
        + '<rect x="16" y="13" width="3" height="7" rx="0.5"/>') },
    { id: 'hlcbars',     label: 'HLC bars', group: 'bars', svg: _styleIcon(
        '<path d="M7 4v16M7 14h3"/>'
        + '<path d="M17 6v14M17 16h3"/>') },
    { id: 'highlow',     label: 'High-Low', group: 'bars', svg: _styleIcon(
        '<path d="M7 5v14"/>'
        + '<path d="M17 8v11"/>') },
    { id: 'hlcarea',     label: 'HLC area', group: 'area', svg: _styleIcon(
        '<path d="M3 16l5-5 4 2 4-4 5 3v6H3z" fill="currentColor" '
        + 'fill-opacity="0.18"/>'
        + '<path d="M3 8l5-3 4 2 4-3 5 2"/>'
        + '<path d="M3 16l5-5 4 2 4-4 5 3"/>') },
    { id: 'volcandles',  label: 'Volume candles', group: 'bars', svg: _styleIcon(
        '<path d="M8 4v4M8 14v6M16 7v3M16 16v3"/>'
        + '<rect x="5" y="8" width="6" height="6" rx="1"/>'
        + '<rect x="13" y="10" width="6" height="6" rx="1"/>') },
    { id: 'renko',       label: 'Renko', group: 'other', svg: _styleIcon(
        '<rect x="3" y="13" width="4" height="4" rx="0.5"/>'
        + '<rect x="8" y="10" width="4" height="4" rx="0.5"/>'
        + '<rect x="13" y="7" width="4" height="4" rx="0.5" fill="none"/>'
        + '<rect x="18" y="10" width="3" height="4" rx="0.5" fill="none"/>') },
    { id: 'linebreak',   label: 'Line Break', group: 'other', svg: _styleIcon(
        '<rect x="3" y="12" width="3" height="6" rx="0.5"/>'
        + '<rect x="7.5" y="8" width="3" height="10" rx="0.5"/>'
        + '<rect x="12" y="5" width="3" height="9" rx="0.5" fill="none"/>'
        + '<rect x="16.5" y="9" width="3" height="9" rx="0.5" fill="none"/>') },
    { id: 'kagi',        label: 'Kagi', group: 'other', svg: _styleIcon(
        '<path d="M4 18v-6h4v-6h4v8h4v-4h4" stroke-width="2"/>') },
    { id: 'range',       label: 'Range', group: 'other', svg: _styleIcon(
        '<path d="M6 4v4M6 14v6M14 4v8M14 18v2"/>'
        + '<rect x="4" y="8" width="4" height="6" rx="1"/>'
        + '<rect x="12" y="12" width="4" height="6" rx="1"/>'
        + '<path d="M20 6v12" stroke-dasharray="2 2"/>') },
    { id: 'pnf',         label: 'Point & Figure', group: 'other', svg: _styleIcon(
        '<path d="M4 6l3 3M7 6l-3 3"/>'
        + '<path d="M10 12l3 3M13 12l-3 3"/>'
        + '<circle cx="18" cy="8" r="1.6" fill="none"/>'
        + '<circle cx="18" cy="14" r="1.6" fill="none"/>') },
  ];
  const styleBtn = document.createElement('button');
  styleBtn.className = 'tb-chip tb-style';
  styleBtn.type = 'button';
  styleBtn.title = 'Chart style';
  // Icon reflects the currently selected style; falls back to the generic
  // candle glyph if the active style has no icon. Chevron is appended after.
  const _chevronSvg = '<svg viewBox="0 0 24 24" width="10" height="10" '
      + 'fill="none" stroke="currentColor" stroke-width="2.5" '
      + 'stroke-linecap="round" stroke-linejoin="round" '
      + 'class="tb-chevron"><polyline points="6 9 12 15 18 9"/></svg>';
  const _defaultStyleSvg = _styleIcon(
      '<path d="M8 4v4M8 14v6M16 4v8M16 18v2"/>'
      + '<rect x="6" y="8" width="4" height="6" rx="1"/>'
      + '<rect x="14" y="12" width="4" height="6" rx="1"/>');
  const repaintStyleBtn = () => {
    const cur = STYLES.find((s) => s.id === activePaneState.candleStyle);
    styleBtn.innerHTML = (cur && cur.svg ? cur.svg : _defaultStyleSvg)
        + _chevronSvg;
  };
  repaintStyleBtn();
  activePaneSubs.push(repaintStyleBtn);

  styleBtn.addEventListener('click', () => {
    const content = document.createElement('div');
    content.className = 'tb-list tb-style-list';
    const GROUP_ORDER = ['bars', 'line', 'area', 'other'];
    let prevGroup = null;
    for (const gid of GROUP_ORDER) {
      const items = STYLES.filter((s) => s.group === gid);
      if (!items.length) continue;
      if (prevGroup !== null) {
        const sep = document.createElement('div');
        sep.className = 'tb-list-divider';
        content.appendChild(sep);
      }
      prevGroup = gid;
      for (const s of items) {
        const row = document.createElement('button');
        row.type = 'button';
        row.className = 'tb-list-row tb-style-row';
        if (s.id === activePaneState.candleStyle) {
          row.classList.add('tb-list-row--on');
        }
        row.innerHTML = '<span class="tb-list-row-icon">' + s.svg + '</span>'
            + '<span class="tb-list-row-label">' + s.label + '</span>';
        row.addEventListener('click', () => {
          _closeOpenPopover();
          if (s.id === activePaneState.candleStyle) return;
          activePaneState.candleStyle = s.id;
          repaintStyleBtn();
          bridge.post('setActiveCandleStyle', { style: s.id });
        });
        content.appendChild(row);
      }
    }
    const pop = openPopover(styleBtn, content);
    pop.classList.add('tb-style-popover');
  });
  root.appendChild(styleBtn);

  // Cursor mode (Crosshair / Cursor) moved into the drawing rail's first
  // button — see buildDrawRail(). The chart's `showCrosshairLines` field is
  // still driven from there via `setActiveShowCrosshairLines`.

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
    repaintRail();
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
      // Info icon → hover (or click) reveals the full shortcuts list. Lives
      // here instead of a standalone "?" chip on the bar.
      const ksInfo = document.createElement('button');
      ksInfo.type = 'button';
      ksInfo.className = 'tb-row-info';
      ksInfo.setAttribute('aria-label', 'View keyboard shortcuts');
      ksInfo.innerHTML = '<svg viewBox="0 0 24 24" width="14" height="14" '
          + 'fill="none" stroke="currentColor" stroke-width="2" '
          + 'stroke-linecap="round" stroke-linejoin="round">'
          + '<circle cx="12" cy="12" r="10"/>'
          + '<line x1="12" y1="16" x2="12" y2="12"/>'
          + '<line x1="12" y1="8" x2="12.01" y2="8"/></svg>';
      ksInfo.addEventListener('mouseenter', () => _openShortcutsPopover(ksInfo));
      ksInfo.addEventListener('mouseleave', _scheduleCloseHelp);
      ksInfo.addEventListener('click', () => {
        if (_helpPop) _scheduleCloseHelp(); else _openShortcutsPopover(ksInfo);
      });
      const ksCtl = document.createElement('div');
      ksCtl.className = 'tb-row-ctl-group';
      ksCtl.appendChild(ksInfo);
      ksCtl.appendChild(_switch(keyboardShortcuts, (x) => {
        keyboardShortcuts = x;
        bridge.post('setKeyboardShortcutsState', { value: x });
      }));
      body.appendChild(_row('Keyboard shortcuts',
          'Alt+B/S, 1/5/H/D and more', ksCtl));
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
      + '<path d="M3 9.11011V14.8801C3 17.0001 3 17.0001 5 18.3501L10.5 21.5301C11.33 22.0101 12.68 22.0101 13.5 21.5301L19 18.3501C21 17.0001 21 17.0001 21 14.8901V9.11011C21 7.00011 21 7.00011 19 5.65011L13.5 2.47011C12.68 1.99011 11.33 1.99011 10.5 2.47011L5 5.65011C3 7.00011 3 7.00011 3 9.11011Z"/>'
      + '<path d="M12 15C13.6569 15 15 13.6569 15 12C15 10.3431 13.6569 9 12 9C10.3431 9 9 10.3431 9 12C9 13.6569 10.3431 15 12 15Z"/>'
      + '</svg>';

  settingsBtn.addEventListener('click', () => {
    const content = document.createElement('div');
    content.className = 'tb-settings-popover-content';
    const header = document.createElement('div');
    header.className = 'tb-od-header';
    const title = document.createElement('div');
    title.className = 'tb-popover-title';
    title.textContent = 'Settings';
    header.appendChild(title);
    const closeBtn = document.createElement('button');
    closeBtn.type = 'button';
    closeBtn.className = 'tb-od-close';
    closeBtn.setAttribute('aria-label', 'Close');
    closeBtn.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16" '
        + 'fill="none" stroke="currentColor" stroke-width="2" '
        + 'stroke-linecap="round" stroke-linejoin="round">'
        + '<path d="M6 6 L18 18 M18 6 L6 18"/></svg>';
    closeBtn.addEventListener('click', () => _closeOpenPopover());
    header.appendChild(closeBtn);
    content.appendChild(header);
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

  // ── Keyboard shortcuts help ─────────────────────────────────────────────
  // No longer a standalone "?" chip on the bar. The shortcuts list now lives
  // behind a small info button next to the "Keyboard shortcuts" toggle in
  // Settings (see _renderSettingsTab). _openShortcutsPopover(anchor) shows the
  // grouped list on hover, anchored to whatever element asked for it; a short
  // close delay lets the cursor travel from the icon into the popover.
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

  function _openShortcutsPopover(anchorEl) {
    if (_helpCloseTimer) { clearTimeout(_helpCloseTimer); _helpCloseTimer = null; }
    if (_helpPop) return;
    const pop = document.createElement('div');
    pop.className = 'tb-popover tb-help-popover';
    pop.appendChild(_buildShortcutsContent());
    // Keep it open while the cursor is over the popover itself.
    pop.addEventListener('mouseenter', () => {
      if (_helpCloseTimer) { clearTimeout(_helpCloseTimer); _helpCloseTimer = null; }
    });
    pop.addEventListener('mouseleave', _scheduleCloseHelp);
    // Measure off-screen, then place BESIDE the anchor and clamp to viewport.
    // Settings is a centred modal, so prefer opening to the RIGHT of the info
    // icon (into open screen space beside the modal) rather than over the
    // panel's toggles; fall back to the left if there's no room.
    pop.style.left = '-9999px';
    pop.style.top = '0';
    document.body.appendChild(pop);
    const rect = anchorEl.getBoundingClientRect();
    const popW = pop.offsetWidth;
    const popH = pop.offsetHeight;
    const vw = document.documentElement.clientWidth;
    const vh = document.documentElement.clientHeight;
    const margin = 8;
    let left = rect.right + 8;
    if (left + popW + margin > vw) left = rect.left - popW - 8;
    if (left < margin) left = Math.max(margin, vw - popW - margin);
    let top = rect.top + rect.height / 2 - popH / 2;
    if (top < margin) top = margin;
    if (top + popH + margin > vh) top = Math.max(margin, vh - popH - margin);
    pop.style.left = left + 'px';
    pop.style.top = top + 'px';
    _helpPop = pop;
  }

  function _scheduleCloseHelp() {
    if (_helpCloseTimer) clearTimeout(_helpCloseTimer);
    _helpCloseTimer = setTimeout(() => {
      if (_helpPop) { _helpPop.remove(); _helpPop = null; }
      _helpCloseTimer = null;
    }, 160);
  }

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

  // SL/TP defaults are hidden for now (TP/SL is handled via the position
  // OCO dialog instead). The 'slTp' render branch below is kept dormant so
  // the tab can be re-enabled by restoring its entry in `tabSpecs`.
  let odTab = 'qty';   // 'qty' | 'product'  (was: 'slTp' | 'qty' | 'product')

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

    const header = document.createElement('div');
    header.className = 'tb-od-header';
    const title = document.createElement('div');
    title.className = 'tb-popover-title';
    title.textContent = 'Order Defaults';
    header.appendChild(title);
    const closeBtn = document.createElement('button');
    closeBtn.type = 'button';
    closeBtn.className = 'tb-od-close';
    closeBtn.setAttribute('aria-label', 'Close');
    closeBtn.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16" '
        + 'fill="none" stroke="currentColor" stroke-width="2" '
        + 'stroke-linecap="round" stroke-linejoin="round">'
        + '<path d="M6 6 L18 18 M18 6 L6 18"/></svg>';
    closeBtn.addEventListener('click', () => _closeOpenPopover());
    header.appendChild(closeBtn);
    content.appendChild(header);
    const sub = document.createElement('div');
    sub.className = 'tb-popover-subtitle';
    sub.textContent = 'Applies to every new order placed from the chart';
    content.appendChild(sub);

    // Tabs.
    const tabs = document.createElement('div');
    tabs.className = 'tb-tabs';
    const tabSpecs = [
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
  // Tool icons rendered inline so the popover looks like a tool palette
  // rather than a plain text list (matches the in-house chart's TradingView-
  // inspired drawer).
  const _ICON_SVG = {
    trendline:
        '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" '
      + 'stroke="currentColor" stroke-width="1.7" stroke-linecap="round" '
      + 'stroke-linejoin="round">'
      + '<line x1="4" y1="20" x2="20" y2="4"/>'
      + '<circle cx="4" cy="20" r="1.8" fill="currentColor"/>'
      + '<circle cx="20" cy="4" r="1.8" fill="currentColor"/></svg>',
    hline:
        '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" '
      + 'stroke="currentColor" stroke-width="1.7" stroke-linecap="round">'
      + '<line x1="3" y1="12" x2="21" y2="12"/>'
      + '<circle cx="12" cy="12" r="1.8" fill="currentColor"/></svg>',
    hray:
        '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" '
      + 'stroke="currentColor" stroke-width="1.7" stroke-linecap="round" '
      + 'stroke-linejoin="round">'
      + '<line x1="4" y1="12" x2="21" y2="12"/>'
      + '<circle cx="4" cy="12" r="1.8" fill="currentColor"/>'
      + '<path d="M18 9l3 3-3 3"/></svg>',
    rect:
        '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" '
      + 'stroke="currentColor" stroke-width="1.7" stroke-linejoin="round">'
      + '<rect x="4" y="6" width="16" height="12" rx="1"/></svg>',
    fib:
        '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" '
      + 'stroke="currentColor" stroke-width="1.5" stroke-linecap="round">'
      + '<line x1="3" y1="5" x2="21" y2="5"/>'
      + '<line x1="3" y1="10" x2="21" y2="10"/>'
      + '<line x1="3" y1="14" x2="21" y2="14"/>'
      + '<line x1="3" y1="19" x2="21" y2="19"/></svg>',
    path:
        '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" '
      + 'stroke="currentColor" stroke-width="1.7" stroke-linecap="round" '
      + 'stroke-linejoin="round">'
      + '<polyline points="4,18 9,11 14,15 20,5"/>'
      + '<circle cx="4" cy="18" r="1.5" fill="currentColor"/>'
      + '<circle cx="9" cy="11" r="1.5" fill="currentColor"/>'
      + '<circle cx="14" cy="15" r="1.5" fill="currentColor"/>'
      + '<circle cx="20" cy="5" r="1.5" fill="currentColor"/></svg>',
    measure:
        '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" '
      + 'stroke="currentColor" stroke-width="1.7" stroke-linecap="round" '
      + 'stroke-linejoin="round">'
      + '<path d="M3 14l7 7 11-11-7-7z"/>'
      + '<path d="M8 9l2 2M11 6l2 2M14 12l2 2"/></svg>',
  };
  const DRAW_GROUPS = [
    {
      title: 'Lines',
      tools: [
        { kind: 'trendline', label: 'Trendline',        group: 'Lines' },
    { kind: 'ray',       label: 'Ray',              group: 'Lines' },
    { kind: 'xline',     label: 'Extended line',    group: 'Lines' },
        { kind: 'hline',     label: 'Horizontal line',  group: 'Lines' },
        { kind: 'hray',      label: 'Horizontal ray',   group: 'Lines' },
      ],
    },
    {
      title: 'Shapes',
      tools: [
        { kind: 'vline',     label: 'Vertical line',    group: 'Lines' },
    { kind: 'crossline', label: 'Cross line',       group: 'Lines' },
    { kind: 'infoline',  label: 'Info line',        group: 'Lines' },
    { kind: 'trendangle', label: 'Trend angle',     group: 'Lines' },
    { kind: 'channel',   label: 'Parallel channel', group: 'Channels' },
    { kind: 'channelflat', label: 'Flat channel',   group: 'Channels' },
    { kind: 'channeldisjoint', label: 'Disjoint channel', group: 'Channels' },
    { kind: 'regression', label: 'Regression channel', group: 'Channels' },
    { kind: 'pitchfork', label: 'Pitchfork',        group: 'Channels' },
    { kind: 'pitchforkschiff', label: 'Schiff pitchfork', group: 'Channels' },
    { kind: 'pitchforkmod', label: 'Modified Schiff', group: 'Channels' },
        { kind: 'pitchforkinside', label: 'Inside pitchfork', group: 'Channels' },
    { kind: 'gannfan',   label: 'Gann fan',         group: 'Gann' },
    { kind: 'gannbox',   label: 'Gann box',         group: 'Gann' },
    { kind: 'fib',       label: 'Fib retracement',  group: 'Fibonacci' },
      ],
    },
    {
      title: 'Tools',
      tools: [
        { kind: 'fibext',    label: 'Fib extension',    group: 'Fibonacci' },
    { kind: 'fibchannel', label: 'Fib channel',     group: 'Fibonacci' },
    { kind: 'fibtimezone', label: 'Fib time zones', group: 'Fibonacci' },
    { kind: 'fibfan',    label: 'Fib fan',          group: 'Fibonacci' },
    { kind: 'fibcircle', label: 'Fib circles',      group: 'Fibonacci' },
    { kind: 'xabcd',     label: 'XABCD',            group: 'Patterns' },
    { kind: 'cypher',    label: 'Cypher',           group: 'Patterns' },
    { kind: 'abcd',      label: 'ABCD',             group: 'Patterns' },
    { kind: 'trianglepattern', label: 'Triangle pattern', group: 'Patterns' },
    { kind: 'threedrives', label: 'Three drives',   group: 'Patterns' },
    { kind: 'elliottimpulse', label: 'Elliott impulse (1-5)', group: 'Patterns' },
    { kind: 'elliottcorrection', label: 'Elliott correction (ABC)', group: 'Patterns' },
        { kind: 'headshoulders', label: 'Head & shoulders', group: 'Patterns' },
    { kind: 'rect',      label: 'Rectangle',        group: 'Shapes' },
    { kind: 'rotrect',   label: 'Rotated rectangle', group: 'Shapes' },
    { kind: 'triangle',  label: 'Triangle',         group: 'Shapes' },
    { kind: 'circle',    label: 'Circle',           group: 'Shapes' },
    { kind: 'arc',       label: 'Arc',              group: 'Shapes' },
    { kind: 'arrow',     label: 'Arrow',            group: 'Shapes' },
    { kind: 'curve',     label: 'Curve',            group: 'Shapes' },
    { kind: 'polyline',  label: 'Polyline',         group: 'Shapes' },
    { kind: 'path',      label: 'Path (freehand)',  group: 'Shapes' },
    { kind: 'forecast',  label: 'Forecast',         group: 'Projection' },
    { kind: 'text',      label: 'Text',             group: 'Annotate' },
    { kind: 'note',      label: 'Note',             group: 'Annotate' },
    { kind: 'comment',   label: 'Comment',          group: 'Annotate' },
    { kind: 'callout',   label: 'Callout',          group: 'Annotate' },
    { kind: 'pricelabel', label: 'Price label',     group: 'Annotate' },
    { kind: 'signpost',  label: 'Sign post',        group: 'Annotate' },
    { kind: 'arrowup',   label: 'Arrow up',         group: 'Annotate' },
    { kind: 'arrowdown', label: 'Arrow down',       group: 'Annotate' },
    { kind: 'flag',      label: 'Flag',             group: 'Annotate' },
    { kind: 'longpos',   label: 'Long position',    group: 'Smart' },
    { kind: 'shortpos',  label: 'Short position',   group: 'Smart' },
    { kind: 'avwap',     label: 'Anchored VWAP',    group: 'Smart' },
    { kind: 'smartlevel', label: 'Smart level (S/R)', group: 'Smart' },
    { kind: 'volxray',   label: 'Volume profile',   group: 'Smart' },
    { kind: 'pricerange', label: 'Price range',     group: 'Measure' },
    { kind: 'daterange', label: 'Date range',       group: 'Measure' },
    { kind: 'dprange',   label: 'Date & price range', group: 'Measure' },
    { kind: 'measure',   label: 'Measure',          group: 'Measure' },
      ],
    },
  ];
  const DRAW_TOOLS = DRAW_GROUPS.flatMap((g) => g.tools);
  const DRAW_TOOL_SHORT = {
    trendline: 'Trendline',
    ray: 'Ray',
    xline: 'Ext. line',
    hline: 'HLine',
    hray: 'H.Ray',
    vline: 'VLine',
    crossline: 'Cross',
    infoline: 'Info line',
    trendangle: 'Trend angle',
    channel: 'Channel',
    channelflat: 'Flat channel',
    channeldisjoint: 'Disjoint ch.',
    regression: 'Regression',
    pitchfork: 'Pitchfork',
    pitchforkschiff: 'Schiff fork',
    pitchforkmod: 'Mod. Schiff',
    pitchforkinside: 'Inside fork',
    gannfan: 'Gann fan',
    gannbox: 'Gann box',
    fib: 'Fib',
    fibext: 'Fib ext.',
    fibchannel: 'Fib channel',
    fibtimezone: 'Fib time',
    fibfan: 'Fib fan',
    fibcircle: 'Fib circle',
    xabcd: 'XABCD',
    cypher: 'Cypher',
    abcd: 'ABCD',
    trianglepattern: 'Triangle',
    threedrives: '3 drives',
    elliottimpulse: 'Elliott 1-5',
    elliottcorrection: 'Elliott ABC',
    headshoulders: 'H&S',
    rect: 'Rectangle',
    rotrect: 'Rot. rect',
    triangle: 'Triangle',
    circle: 'Circle',
    arc: 'Arc',
    arrow: 'Arrow',
    curve: 'Curve',
    polyline: 'Polyline',
    path: 'Path',
    forecast: 'Forecast',
    text: 'Text',
    note: 'Note',
    comment: 'Comment',
    callout: 'Callout',
    pricelabel: 'Price label',
    signpost: 'Sign post',
    arrowup: 'Arrow up',
    arrowdown: 'Arrow down',
    flag: 'Flag',
    longpos: 'Long pos',
    shortpos: 'Short pos',
    avwap: 'aVWAP',
    smartlevel: 'Smart level',
    volxray: 'Vol profile',
    pricerange: 'Price range',
    daterange: 'Date range',
    dprange: 'Date+price',
    measure: 'Measure',
  };
  let drawTool = null;
  let drawLocked = false;
  let drawHidden = false;
  // Assigned by buildDrawRail(); no-op until the rail is built.
  let repaintRail = () => {};

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
    repaintRail();
  });
  bridge.on('setDrawingsLocked', (v) => {
    const next = !!(v && v.locked);
    if (next === drawLocked) return;
    drawLocked = next;
    if (_openPopover && _openPopover.dataset.kind === 'draw') {
      _repaintDrawBottomToolbar();
    }
    repaintRail();
  });
  bridge.on('setDrawingsHidden', (v) => {
    const next = !!(v && v.hidden);
    if (next === drawHidden) return;
    drawHidden = next;
    if (_openPopover && _openPopover.dataset.kind === 'draw') {
      _repaintDrawBottomToolbar();
    }
    repaintRail();
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
    // Otherwise open the picker popover. Layout mirrors the chart-style
    // dropdown: flush rows grouped by thin dividers, no section labels.
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

    // Tools are grouped (Lines / Shapes / Fibonacci / …) so the picker stays
    // legible as the catalogue grows past 60 tools. Group headers follow the
    // order tools first appear in DRAW_TOOLS.
    const _groupOrder = [];
    const _byGroup = {};
    for (const t of DRAW_TOOLS) {
      const grp = t.group || 'Tools';
      if (!_byGroup[grp]) { _byGroup[grp] = []; _groupOrder.push(grp); }
      _byGroup[grp].push(t);
    }
    const pickTool = (kind) => {
      drawTool = kind;
      repaintDrawButton();
      _closeOpenPopover();
      bridge.post('setActiveDrawTool', { kind });
    };
    for (const grp of _groupOrder) {
      const section = document.createElement('div');
      section.className = 'tb-popover-section-label';
      section.textContent = grp;
      content.appendChild(section);
      for (const t of _byGroup[grp]) {
        const row = document.createElement('button');
        row.type = 'button';
        row.className = 'tb-list-row';
        row.innerHTML = '<span class="tb-list-row-label">' + t.label + '</span>';
        row.addEventListener('click', () => pickTool(t.kind));
        content.appendChild(row);
      }
    }

    const bottomBar = document.createElement('div');
    bottomBar.className = 'tb-draw-actions';
    const _lockSvg =
        '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" '
      + 'stroke="currentColor" stroke-width="1.7" stroke-linecap="round" '
      + 'stroke-linejoin="round">'
      + '<rect x="5" y="11" width="14" height="9" rx="2"/>'
      + '<path d="M8 11V8a4 4 0 018 0v3"/></svg>';
    const _eyeSvg =
        '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" '
      + 'stroke="currentColor" stroke-width="1.7" stroke-linecap="round" '
      + 'stroke-linejoin="round">'
      + '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/>'
      + '<circle cx="12" cy="12" r="3"/></svg>';
    const _trashSvg =
        '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" '
      + 'stroke="currentColor" stroke-width="1.7" stroke-linecap="round" '
      + 'stroke-linejoin="round">'
      + '<path d="M4 7h16"/>'
      + '<path d="M9 7V5a2 2 0 012-2h2a2 2 0 012 2v2"/>'
      + '<path d="M6 7l1 13a2 2 0 002 2h6a2 2 0 002-2l1-13"/></svg>';
    bottomBar.innerHTML =
        '<button type="button" class="tb-draw-action" data-act="lock">'
          + '<span class="tb-draw-action-icon">' + _lockSvg + '</span>'
          + '<span class="tb-draw-action-label">' + (drawLocked ? 'Unlock' : 'Lock') + '</span>'
        + '</button>'
        + '<button type="button" class="tb-draw-action" data-act="hide">'
          + '<span class="tb-draw-action-icon">' + _eyeSvg + '</span>'
          + '<span class="tb-draw-action-label">' + (drawHidden ? 'Show' : 'Hide') + '</span>'
        + '</button>'
        + '<button type="button" class="tb-draw-action tb-draw-action--danger" data-act="trash">'
          + '<span class="tb-draw-action-icon">' + _trashSvg + '</span>'
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

  // The drawing tools now live in a floating left rail (buildDrawRail) instead
  // of this top-bar dropdown — drawBtn is kept only so its repaint helpers stay
  // valid, but it is no longer mounted in the top bar.

  // ── Left drawing rail ────────────────────────────────────────────────────
  // Full-height, flush-left, plain (TradingView-style) vertical toolbar. One
  // button per tool group; the button shows the group's LAST-USED tool icon and
  // a plain click re-arms it. A caret (revealed on hover) opens the group's
  // flyout list. Hovering shows a tooltip. Below a divider: magnet, lock, hide,
  // delete, collapse. Collapsed → a blue reopen tab. Replaces the top-bar Draw
  // dropdown.
  const _RAIL_ICONS = {
    Lines: '<path d="M4 20 L20 4"/>',
    Channels: '<path d="M3 17 L17 3" /><path d="M7 21 L21 7"/>',
    Gann: '<path d="M5 19 H19 M5 19 L19 12 M5 19 L19 5 M5 19 L12 5"/>',
    Fibonacci: '<path d="M4 6 H20 M4 10 H20 M4 14 H20 M4 18 H20"/>',
    Patterns: '<path d="M3 18 L8 8 L13 15 L18 5"/>',
    Shapes: '<rect x="4" y="6" width="15" height="13" rx="1"/>',
    Annotate: '<path d="M5 5 H19 M12 5 V19"/>',
    Projection: '<path d="M4 12 H17 M13 7 L18 12 L13 17"/>',
    Measure: '<rect x="3" y="9" width="18" height="6" rx="1"/><path d="M7 9 v3 M11 9 v4 M15 9 v3"/>',
    Smart: '<path d="M12 7 V20 M9 10 H15 M12 4 a2 2 0 1 0 0.01 0 M5 14 a7 7 0 0 0 14 0"/>',
  };
  const _ACT_ICONS = {
    cursor: '<path d="M12 3 V21 M3 12 H21"/>',
    magnet: '<path d="M6 4 v6 a6 6 0 0 0 12 0 V4 M6 4 h4 M14 4 h4"/>',
    unlock: '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11 V7 a4 4 0 0 1 8 0 v4"/>',
    lock: '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11 V7 a4 4 0 0 1 7 -2"/>',
    hide: '<path d="M2 12 s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
    unhide: '<path d="M3 3 L21 21"/><path d="M10.5 5.2 a10 10 0 0 1 11.5 6.8 a17 17 0 0 1 -3 4"/><path d="M6.5 6.5 a16 16 0 0 0 -4.5 5.5 a10 10 0 0 0 14 6"/><path d="M9.5 9.5 a3 3 0 0 0 4 4"/>',
    trash: '<path d="M4 7 h16 M9 7 V4 h6 v3 M6 7 l1 13 h10 l1-13"/>',
    collapse: '<path d="M14 6 L8 12 L14 18"/>',
    expand: '<path d="M10 6 L16 12 L10 18"/>',
  };
  // Per-tool icons so the group button can show whichever tool is selected
  // (TradingView behaviour). Missing kinds fall back to the group icon.
  const TOOL_ICONS = {
    // Lines
    trendline: '<path d="M4 20 L20 4"/>',
    ray: '<circle cx="5" cy="19" r="1.6"/><path d="M5 19 L21 3"/>',
    xline: '<path d="M2 22 L22 2"/>',
    hline: '<path d="M3 12 H21"/>',
    hray: '<circle cx="5" cy="12" r="1.6"/><path d="M5 12 H21"/>',
    vline: '<path d="M12 3 V21"/>',
    crossline: '<path d="M12 3 V21 M3 12 H21"/>',
    infoline: '<path d="M4 20 L20 4"/><path d="M14 6 h6 v5"/>',
    trendangle: '<path d="M4 20 H18 M4 20 L18 8"/>',
    // Channels
    channel: '<path d="M3 17 L17 3 M7 21 L21 7"/>',
    channelflat: '<path d="M3 8 H21 M3 16 H21"/>',
    channeldisjoint: '<path d="M3 16 L11 6 M13 18 L21 8"/>',
    regression: '<path d="M3 18 L21 8 M3 14 L21 4 M3 22 L21 12"/>',
    pitchfork: '<path d="M12 4 V20 M6 8 L12 4 L18 8 M6 8 V20 M18 8 V20"/>',
    pitchforkschiff: '<path d="M9 6 V20 M6 8 L12 6 L18 8 M6 8 V20 M18 8 V20"/>',
    pitchforkmod: '<path d="M10 7 V20 M6 8 L12 7 L18 8 M6 8 V20 M18 8 V20"/>',
    pitchforkinside: '<path d="M12 5 V20 M8 9 V19 M16 9 V19"/>',
    // Gann
    gannfan: '<path d="M5 19 H19 M5 19 L19 12 M5 19 L19 5 M5 19 L12 5"/>',
    gannbox: '<rect x="4" y="5" width="16" height="14"/><path d="M4 5 L20 19 M4 12 H20 M12 5 V19"/>',
    // Fibonacci
    fib: '<path d="M4 6 H20 M4 10 H20 M4 14 H20 M4 18 H20"/>',
    fibext: '<path d="M4 7 H20 M4 12 H20 M4 17 H20"/><path d="M17 4 L20 7"/>',
    fibchannel: '<path d="M4 8 L18 4 M5 13 L19 9 M6 18 L20 14"/>',
    fibtimezone: '<path d="M5 4 V20 M9 4 V20 M14 4 V20 M20 4 V20"/>',
    fibfan: '<path d="M5 19 L19 5 M5 19 L19 10 M5 19 L19 15"/>',
    fibcircle: '<circle cx="12" cy="12" r="4"/><circle cx="12" cy="12" r="8"/>',
    // Patterns
    xabcd: '<path d="M4 16 L9 6 L13 14 L17 7 L20 17"/>',
    cypher: '<path d="M4 16 L9 6 L13 14 L17 7 L20 17"/>',
    abcd: '<path d="M4 16 L9 6 L14 14 L20 5"/>',
    trianglepattern: '<path d="M4 18 L20 14 M4 6 L20 14"/>',
    threedrives: '<path d="M3 17 L7 9 L10 14 L14 7 L17 13 L21 5"/>',
    elliottimpulse: '<path d="M3 18 L7 8 L9 12 L14 5 L16 9 L21 3"/>',
    elliottcorrection: '<path d="M5 8 L10 16 L14 9 L19 15"/>',
    headshoulders: '<path d="M3 18 L6 12 L9 15 L12 6 L15 15 L18 12 L21 18"/>',
    // Shapes
    rect: '<rect x="4" y="6" width="15" height="13" rx="1"/>',
    rotrect: '<path d="M3 14 L10 5 L21 10 L14 19 Z"/>',
    triangle: '<path d="M12 5 L20 19 H4 Z"/>',
    circle: '<circle cx="12" cy="12" r="8"/>',
    arc: '<path d="M4 18 a8 8 0 0 1 16 0"/>',
    arrow: '<path d="M4 20 L20 4 M20 4 H14 M20 4 V10"/>',
    curve: '<path d="M4 18 Q12 2 20 18"/>',
    polyline: '<path d="M4 16 L9 8 L14 14 L20 6"/>',
    path: '<path d="M4 16 q3 -10 7 -4 q3 5 9 -4"/>',
    // Annotate
    text: '<path d="M5 6 H19 M12 6 V19"/>',
    note: '<rect x="4" y="6" width="16" height="12" rx="2"/><path d="M7 10 H17 M7 14 H13"/>',
    comment: '<path d="M4 6 H20 V15 H13 L9 19 V15 H4 Z"/>',
    callout: '<rect x="9" y="4" width="12" height="9" rx="2"/><path d="M11 13 L5 20"/>',
    pricelabel: '<path d="M3 12 L7 8 H21 V16 H7 Z"/>',
    signpost: '<path d="M12 21 V8 M6 5 H17 L20 8 L17 11 H6 Z"/>',
    arrowup: '<path d="M12 4 V20 M6 10 L12 4 L18 10"/>',
    arrowdown: '<path d="M12 4 V20 M6 14 L12 20 L18 14"/>',
    flag: '<path d="M6 21 V4 M6 4 H18 L15 8 L18 12 H6"/>',
    // Projection
    forecast: '<path d="M3 16 L9 10 L15 14 L21 5"/>',
    // Measure
    pricerange: '<path d="M12 4 V20 M8 4 H16 M8 20 H16"/>',
    daterange: '<path d="M4 12 H20 M4 8 V16 M20 8 V16"/>',
    dprange: '<rect x="5" y="6" width="14" height="12"/><path d="M5 6 L19 18"/>',
    measure: '<rect x="3" y="9" width="18" height="6" rx="1"/><path d="M7 9 v3 M11 9 v4 M15 9 v3"/>',
    // Smart
    longpos: '<rect x="5" y="5" width="14" height="6"/><rect x="5" y="13" width="14" height="6"/><path d="M9 8 H15"/>',
    shortpos: '<rect x="5" y="5" width="14" height="6"/><rect x="5" y="13" width="14" height="6"/><path d="M9 16 H15"/>',
    smartlevel: '<path d="M3 10 H21 M3 14 H21"/>',
    volxray: '<path d="M4 6 H12 M4 10 H16 M4 14 H9 M4 18 H14"/>',
    avwap: '<path d="M12 7 V20 M9 10 H15 M5 14 a7 7 0 0 0 14 0"/>',
  };
  function _railSvg(inner) {
    return '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" '
      + 'stroke="currentColor" stroke-width="1.6" stroke-linecap="round" '
      + 'stroke-linejoin="round">' + inner + '</svg>';
  }
  function buildDrawRail() {
    const layout = document.getElementById('layout');
    if (!layout) return;

    // Group tools (preserve DRAW_TOOLS order); build kind→group, kind→label.
    const order = [];
    const byGroup = {};
    const kindGroup = {};
    const labelOf = {};
    for (const t of DRAW_TOOLS) {
      const grp = t.group || 'Tools';
      if (!byGroup[grp]) { byGroup[grp] = []; order.push(grp); }
      byGroup[grp].push(t);
      kindGroup[t.kind] = grp;
      labelOf[t.kind] = t.label;
    }
    const iconFor = (kind) =>
        TOOL_ICONS[kind] || _RAIL_ICONS[kindGroup[kind]] || _RAIL_ICONS.Shapes;
    // Last-used tool per group, defaulting to the group's first tool so each
    // button shows a real tool icon and a plain click arms something sensible.
    const lastTool = {};
    for (const grp of order) lastTool[grp] = byGroup[grp][0].kind;

    const rail = document.createElement('div');
    rail.className = 'draw-rail';

    // Shared hover tooltip (positioned to the right of the hovered button).
    const tip = document.createElement('div');
    tip.className = 'draw-rail-tip';
    tip.hidden = true;
    document.body.appendChild(tip);
    const showTip = (el, text) => {
      if (!text) return;
      tip.textContent = text;
      tip.hidden = false;
      const r = el.getBoundingClientRect();
      tip.style.left = (r.right + 8) + 'px';
      tip.style.top = (r.top + r.height / 2 - tip.offsetHeight / 2) + 'px';
    };
    const hideTip = () => { tip.hidden = true; };

    const groupBtns = {};
    const groupIcons = {};
    const actBtns = {};

    // Hover-intent flyout control. Opening a group's tool list on hover (not
    // just a precise click on the tiny caret) makes the list easy to reach; a
    // short open delay avoids flicker while sweeping past buttons, and a short
    // close delay lets the cursor travel from the button into the flyout.
    // Leaving the rail/flyout — or the whole iframe (e.g. onto the watchlist) —
    // dismisses it so a flyout can't get stuck open.
    let _railOpenTimer = null;
    let _railCloseTimer = null;
    const _cancelRailOpen = () => {
      if (_railOpenTimer) { clearTimeout(_railOpenTimer); _railOpenTimer = null; }
    };
    const _cancelRailClose = () => {
      if (_railCloseTimer) { clearTimeout(_railCloseTimer); _railCloseTimer = null; }
    };
    const _isRailFlyoutOpen = (anchor) =>
        _openPopover != null && _openAnchor === anchor;
    const _scheduleRailOpen = (anchor, openFn) => {
      _cancelRailClose();
      if (_isRailFlyoutOpen(anchor)) return;
      _cancelRailOpen();
      _railOpenTimer = setTimeout(() => { _railOpenTimer = null; openFn(); }, 120);
    };
    const _scheduleRailClose = () => {
      _cancelRailOpen();
      _cancelRailClose();
      _railCloseTimer = setTimeout(() => {
        _railCloseTimer = null;
        if (_openPopover && _openPopover.dataset &&
            _openPopover.dataset.kind === 'draw-rail') _closeOpenPopover();
      }, 220);
    };
    const _attachFlyoutHover = (pop) => {
      if (!pop) return;
      pop.addEventListener('mouseenter', _cancelRailClose);
      pop.addEventListener('mouseleave', _scheduleRailClose);
    };
    // Moving the cursor out of the iframe (onto the Flutter watchlist / app
    // chrome) fires mouseleave on the document — close any open rail flyout.
    document.addEventListener('mouseleave', _scheduleRailClose);
    window.addEventListener('blur', () => {
      _cancelRailOpen();
      _cancelRailClose();
      if (_openPopover && _openPopover.dataset &&
          _openPopover.dataset.kind === 'draw-rail') _closeOpenPopover();
    });

    const setTool = (kind) => {
      drawTool = kind;
      if (kind && kindGroup[kind]) {
        const grp = kindGroup[kind];
        lastTool[grp] = kind;
        if (groupIcons[grp]) groupIcons[grp].innerHTML = _railSvg(iconFor(kind));
      }
      repaintDrawButton();
      _closeOpenPopover();
      repaintRail();
      bridge.post('setActiveDrawTool', { kind });
    };

    const openGroupFlyout = (grp, anchor) => {
      const content = document.createElement('div');
      content.className = 'tb-draw-popover-content';
      const title = document.createElement('div');
      title.className = 'tb-popover-section-label';
      title.textContent = grp;
      content.appendChild(title);
      for (const t of byGroup[grp]) {
        const row = document.createElement('button');
        row.type = 'button';
        row.className = 'tb-list-row draw-rail-row'
            + (t.kind === drawTool ? ' tb-list-row--active' : '');
        row.innerHTML =
            '<span class="draw-rail-row-ic">' + _railSvg(iconFor(t.kind)) + '</span>'
            + '<span class="tb-list-row-label">' + t.label + '</span>';
        row.addEventListener('click', () => setTool(t.kind));
        content.appendChild(row);
      }
      const pop = openFlyoutRight(anchor, content);
      if (pop) { pop.dataset.kind = 'draw-rail'; _attachFlyoutHover(pop); }
      return pop;
    };

    // Crosshair / Cursor mode control at the top (replaces the old top-bar
    // picker). The icon reflects the active pane's mode; clicking it leaves any
    // drawing tool (back to interaction); the caret opens a Crosshair/Cursor
    // flyout that toggles the chart's `showCrosshairLines`.
    const CURSOR_MODES = [
      { value: true, label: 'Crosshair', icon: '<path d="M12 3 V21 M3 12 H21"/>' },
      { value: false, label: 'Cursor', icon: '<path d="M5 3 L10 19 L12 12 L19 10 Z"/>' },
    ];
    const _cursorMode = () => CURSOR_MODES.find(
        (m) => m.value === activePaneState.showCrosshairLines) || CURSOR_MODES[0];
    const cursorBtn2 = document.createElement('button');
    cursorBtn2.type = 'button';
    cursorBtn2.className = 'draw-rail-btn draw-rail-cursor';
    const cursorIc = document.createElement('span');
    cursorIc.className = 'draw-rail-ic';
    cursorIc.innerHTML = _railSvg(_cursorMode().icon);
    const cursorCaret = document.createElement('span');
    cursorCaret.className = 'draw-rail-caret';
    cursorCaret.innerHTML = '<svg viewBox="0 0 24 24" width="10" height="10" '
        + 'fill="currentColor"><path d="M9 6 L15 12 L9 18 Z"/></svg>';
    cursorBtn2.appendChild(cursorIc);
    cursorBtn2.appendChild(cursorCaret);
    const repaintCursorRail = () => { cursorIc.innerHTML = _railSvg(_cursorMode().icon); };
    activePaneSubs.push(repaintCursorRail);
    const openCursorFlyout = () => {
      const content = document.createElement('div');
      content.className = 'tb-draw-popover-content';
      for (const m of CURSOR_MODES) {
        const row = document.createElement('button');
        row.type = 'button';
        row.className = 'tb-list-row draw-rail-row'
            + (m.value === activePaneState.showCrosshairLines ? ' tb-list-row--active' : '');
        row.innerHTML = '<span class="draw-rail-row-ic">' + _railSvg(m.icon) + '</span>'
            + '<span class="tb-list-row-label">' + m.label + '</span>';
        row.addEventListener('click', () => {
          _closeOpenPopover();
          if (m.value !== activePaneState.showCrosshairLines) {
            activePaneState.showCrosshairLines = m.value;
            repaintCursorRail();
            bridge.post('setActiveShowCrosshairLines', { value: m.value });
          }
        });
        content.appendChild(row);
      }
      const pop = openFlyoutRight(cursorBtn2, content);
      if (pop) { pop.dataset.kind = 'draw-rail'; _attachFlyoutHover(pop); }
      return pop;
    };
    // Body click → leave any drawing tool (back to interaction/cursor mode).
    // The caret opens the Crosshair/Cursor picker — same model as the groups.
    cursorBtn2.addEventListener('click', (e) => {
      if (cursorCaret.contains(e.target)) return;
      _cancelRailOpen();
      _closeOpenPopover();
      if (drawTool) setTool(null);
    });
    cursorCaret.addEventListener('mouseenter',
        () => _scheduleRailOpen(cursorBtn2, openCursorFlyout));
    cursorCaret.addEventListener('mouseleave', _scheduleRailClose);
    cursorCaret.addEventListener('click', (e) => {
      e.stopPropagation();
      _cancelRailOpen();
      if (_isRailFlyoutOpen(cursorBtn2)) { _closeOpenPopover(); return; }
      openCursorFlyout();
    });
    rail.appendChild(cursorBtn2);

    // Scrollable group area.
    const toolsWrap = document.createElement('div');
    toolsWrap.className = 'draw-rail-tools';
    for (const grp of order) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'draw-rail-btn draw-rail-group';
      const ic = document.createElement('span');
      ic.className = 'draw-rail-ic';
      ic.innerHTML = _railSvg(iconFor(lastTool[grp]));
      const caret = document.createElement('span');
      caret.className = 'draw-rail-caret';
      caret.innerHTML = '<svg viewBox="0 0 24 24" width="10" height="10" fill="currentColor">'
          + '<path d="M9 6 L15 12 L9 18 Z"/></svg>';
      btn.appendChild(ic);
      btn.appendChild(caret);
      // Click the icon body → re-arm this group's last-used tool directly (no
      // list). The caret is the only thing that opens the full list.
      btn.addEventListener('click', (e) => {
        if (caret.contains(e.target)) return;
        _cancelRailOpen();
        _closeOpenPopover();
        setTool(lastTool[grp]);
      });
      // Caret = list opener: hover (intent) or click reveals the group's tools;
      // picking one there re-arms it and becomes the new last-used.
      caret.addEventListener('mouseenter',
          () => _scheduleRailOpen(btn, () => openGroupFlyout(grp, btn)));
      caret.addEventListener('mouseleave', _scheduleRailClose);
      caret.addEventListener('click', (e) => {
        e.stopPropagation();
        _cancelRailOpen();
        if (_isRailFlyoutOpen(btn)) { _closeOpenPopover(); return; }
        openGroupFlyout(grp, btn);
      });
      groupBtns[grp] = btn;
      groupIcons[grp] = ic;
      toolsWrap.appendChild(btn);
    }
    rail.appendChild(toolsWrap);

    const sep = document.createElement('div');
    sep.className = 'draw-rail-sep';
    rail.appendChild(sep);

    const actBtn = (key, title, onClick, danger) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'draw-rail-btn' + (danger ? ' draw-rail-btn--danger' : '');
      b.innerHTML = '<span class="draw-rail-ic">' + _railSvg(_ACT_ICONS[key]) + '</span>';
      b.addEventListener('click', onClick);
      b.addEventListener('mouseenter', () => showTip(b, title));
      b.addEventListener('mouseleave', hideTip);
      return b;
    };
    const magnetBtn = actBtn('magnet', 'Magnet snap', () => {
      _patchView({ magnetEnabled: !viewState.magnetEnabled });
      repaintRail();
    });
    const lockBtn = actBtn('lock', 'Lock drawings', () => {
      drawLocked = !drawLocked;
      repaintRail();
      bridge.post('setDrawingsLocked', { value: drawLocked });
    });
    lockBtn.classList.add('draw-rail-btn--lock');
    const hideBtn = actBtn('hide', 'Hide drawings', () => {
      drawHidden = !drawHidden;
      repaintRail();
      bridge.post('setDrawingsHidden', { value: drawHidden });
    });
    const trashBtn = actBtn('trash', 'Delete all drawings', () => {
      _closeOpenPopover();
      bridge.post('clearDrawingsForActivePane', {});
    }, true);
    actBtns.magnet = magnetBtn; actBtns.lock = lockBtn; actBtns.hide = hideBtn;
    rail.appendChild(magnetBtn);
    rail.appendChild(lockBtn);
    rail.appendChild(hideBtn);
    rail.appendChild(trashBtn);

    const setGutter = (px) => {
      if (typeof window.__setChartLeftGutter === 'function') window.__setChartLeftGutter(px);
    };
    const collapseBtn = actBtn('collapse', 'Hide drawing toolbar', () => {
      _closeOpenPopover();
      hideTip();
      rail.hidden = true;
      reopen.hidden = false;
      setGutter(0); // chart reclaims the rail's space
    });
    collapseBtn.classList.add('draw-rail-collapse');
    rail.appendChild(collapseBtn);

    // Collapsed state: a blue tab pinned to the left edge.
    const reopen = document.createElement('button');
    reopen.type = 'button';
    reopen.className = 'draw-rail-reopen';
    reopen.innerHTML = _railSvg(_ACT_ICONS.expand);
    reopen.hidden = true;
    reopen.addEventListener('click', () => {
      rail.hidden = false; reopen.hidden = true; setGutter(40);
    });

    repaintRail = () => {
      const grp = drawTool ? kindGroup[drawTool] : null;
      for (const g of order) {
        groupBtns[g].classList.toggle('draw-rail-btn--active', g === grp);
      }
      cursorBtn2.classList.toggle('draw-rail-btn--active', !drawTool);
      actBtns.magnet.classList.toggle('draw-rail-btn--on', !!viewState.magnetEnabled);
      actBtns.lock.classList.toggle('draw-rail-btn--on', drawLocked);
      actBtns.hide.classList.toggle('draw-rail-btn--on', drawHidden);
      const lockIc = actBtns.lock.querySelector('.draw-rail-ic');
      if (lockIc) lockIc.innerHTML = _railSvg(_ACT_ICONS[drawLocked ? 'unlock' : 'lock']);
      const hideIc = actBtns.hide.querySelector('.draw-rail-ic');
      if (hideIc) hideIc.innerHTML = _railSvg(_ACT_ICONS[drawHidden ? 'unhide' : 'hide']);
    };
    repaintRail();

    layout.appendChild(rail);
    layout.appendChild(reopen);
  }
  buildDrawRail();

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
    { kind: 'supertrend', label: 'ST',   fullName: 'SuperTrend',                    category: 'trend' },
    { kind: 'wma',      label: 'WMA',    fullName: 'Weighted Moving Average',       category: 'trend' },
    { kind: 'hma',      label: 'HMA',    fullName: 'Hull Moving Average',           category: 'trend' },
    { kind: 'keltner',  label: 'KC',     fullName: 'Keltner Channels',             category: 'trend' },
    { kind: 'donchian', label: 'DC',     fullName: 'Donchian Channels',            category: 'trend' },
    { kind: 'cci',      label: 'CCI',    fullName: 'Commodity Channel Index',      category: 'momentum' },
    { kind: 'roc',      label: 'ROC',    fullName: 'Rate of Change',               category: 'momentum' },
    { kind: 'adx',      label: 'ADX',    fullName: 'Average Directional Index (DMI)', category: 'momentum' },
    { kind: 'cvd',      label: 'CVD',    fullName: 'Cumulative Volume Delta',       category: 'momentum' },
    { kind: 'psar',     label: 'PSAR',   fullName: 'Parabolic SAR',                category: 'trend' },
    { kind: 'vwma',     label: 'VWMA',   fullName: 'Volume-Weighted Moving Average', category: 'trend' },
    { kind: 'trix',     label: 'TRIX',   fullName: 'TRIX',                         category: 'momentum' },
    { kind: 'vortex',   label: 'VTX',    fullName: 'Vortex Indicator',            category: 'momentum' },
    { kind: 'uo',       label: 'UO',     fullName: 'Ultimate Oscillator',         category: 'momentum' },
    { kind: 'dpo',      label: 'DPO',    fullName: 'Detrended Price Oscillator',  category: 'momentum' },
    { kind: 'pvt',      label: 'PVT',    fullName: 'Price Volume Trend',          category: 'momentum' },
    { kind: 'ad',       label: 'A/D',    fullName: 'Accumulation/Distribution',   category: 'momentum' },
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
            + '<svg viewBox="0 0 24 24" width="14" height="14" '
            + 'fill="currentColor">'
            + '<path fill-rule="evenodd" clip-rule="evenodd" d="'
            + 'M20,5 C20.5523,5 21,5.44772 21,6 C21,6.55228 20.5523,7 20,7 L19.0001,7 '
            + 'L18.9975,7.07129 L18.0638,20.1425 C17.9891,21.1891 17.1182,22 16.0689,22 '
            + 'L7.93116,22 C6.88189,22 6.011,21.1891 5.93624,20.1425 L5.00258,7.07129 '
            + 'C5.00088,7.04738 5.00002,7.02361 5,7 L4,7 C3.44772,7 3,6.55228 3,6 '
            + 'C3,5.44772 3.44772,5 4,5 L20,5 Z M16.9975,7 L7.00259,7 L7.93116,20 '
            + 'L16.0689,20 L16.9975,7 Z M14,2 C14.5523,2 15,2.44772 15,3 C15,3.55228 '
            + '14.5523,4 14,4 L10,4 C9.44772,4 9,3.55228 9,3 C9,2.44772 9.44772,2 10,2 '
            + 'L14,2 Z"/></svg></button>';
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

  // ── The Lab (experimental analysis) ─────────────────────────────────────
  // A modal with three tools that run pure math (lab.js / window.CandlLab) on
  // the ACTIVE pane's candles read live via window.__activePaneCandles():
  //   • Echoes      — historical analogues of the recent shape + their base rate
  //   • Oracle      — moving-block bootstrap projection + target odds
  //   • Market Clock — per-UTC-hour / weekday activity profile
  // Everything is descriptive (base rates / simulations), never a forecast.
  const labBtn = document.createElement('button');
  labBtn.className = 'tb-chip tb-lab';
  labBtn.type = 'button';
  labBtn.title = 'The Lab — experimental analysis';
  labBtn.innerHTML = '<svg viewBox="0 0 24 24" width="14" height="14" '
      + 'fill="none" stroke="currentColor" stroke-width="2" '
      + 'stroke-linecap="round" stroke-linejoin="round">'
      + '<path d="M9 3h6M10 3v6.2L4.6 18A2 2 0 0 0 6.3 21h11.4a2 2 0 0 0 1.7-2.8L14 9.2V3"/>'
      + '<path d="M7.5 15h9"/></svg>'
      + '<span>Lab</span>';

  let labTab = 'echoes';   // 'echoes' | 'oracle' | 'clock'
  let _labOracleResult = null;   // cached Oracle run so the target input is live

  function _labFmtPct(v) {
    if (v === null || v === undefined || !Number.isFinite(v)) return '–';
    return (v >= 0 ? '+' : '') + v.toFixed(2) + '%';
  }

  function _labSection(label) {
    const el = document.createElement('div');
    el.className = 'tb-popover-section-label';
    el.textContent = label;
    return el;
  }

  function _labNote(text) {
    const el = document.createElement('div');
    el.className = 'tb-lab-note';
    el.textContent = text;
    return el;
  }

  function _labStatCard(label, value, tone) {
    const card = document.createElement('div');
    card.className = 'tb-lab-stat' + (tone ? ' tb-lab-stat--' + tone : '');
    card.innerHTML = '<div class="tb-lab-stat-val">' + _escape(value) + '</div>'
        + '<div class="tb-lab-stat-lbl">' + _escape(label) + '</div>';
    return card;
  }

  // ── Lab projection plumbing (push ghost paths to the active chart) ────────
  let _labPanel = null;
  let _echoWindow = 30, _echoHorizon = 24, _echoMatches = 20;
  let _oracleHorizon = 48, _oraclePaths = 500;
  let _clockMode = 'dir';   // 'vol' | 'dir' | 'volume'

  function _labChart() {
    return (typeof window.__activePaneChart === 'function')
        ? window.__activePaneChart() : null;
  }
  function _labClearProjection() {
    const ch = _labChart();
    if (ch && typeof ch.setLabProjection === 'function') ch.setLabProjection(null);
  }
  function _labPushProjection(data) {
    const ch = _labChart();
    if (ch && typeof ch.setLabProjection === 'function') ch.setLabProjection(data);
  }
  const _UP = '#26a69a', _DOWN = '#ef5350', _BAND = 'rgba(59,130,246,1)';

  // Build Oracle ghost lines (sample paths) + a p5–p95 band + median.
  function _oracleProjection(res, anchor) {
    const at = (pct) => anchor * (1 + pct / 100);
    const band = { color: _BAND, opacity: 0.12,
      upper: [{ barOffset: 0, price: anchor }], lower: [{ barOffset: 0, price: anchor }] };
    for (let t = 0; t < res.horizon; t++) {
      band.upper.push({ barOffset: t + 1, price: at(res.bandsPct[t].p95) });
      band.lower.push({ barOffset: t + 1, price: at(res.bandsPct[t].p5) });
    }
    const lines = [];
    for (let i = 0; i < res.samplePathsPct.length; i++) {
      const path = res.samplePathsPct[i];
      if (!path || !path.length) continue;
      const up = path[path.length - 1] >= 0;
      const pts = [{ barOffset: 0, price: anchor }];
      for (let t = 0; t < path.length; t++) pts.push({ barOffset: t + 1, price: at(path[t]) });
      lines.push({ id: 'op' + i, color: up ? _UP : _DOWN, opacity: 0.22, width: 0.75, points: pts });
    }
    const med = [{ barOffset: 0, price: anchor }];
    for (let t = 0; t < res.horizon; t++) med.push({ barOffset: t + 1, price: at(res.bandsPct[t].p50) });
    lines.push({ id: 'omed', color: '#3B82F6', opacity: 0.9, width: 1.5, dashed: true, points: med });
    return { lines, band };
  }

  // Build Echoes ghost lines (each match's aftermath) + a 10–90% band.
  function _echoProjection(scan, anchor) {
    const at = (pct) => anchor * (1 + pct / 100);
    const valid = scan.results.filter((r) =>
        r.aftermathPct && r.aftermathPct.every((v) => v != null && Number.isFinite(v)));
    const lines = [];
    for (let i = 0; i < valid.length; i++) {
      const a = valid[i].aftermathPct;
      const up = a[a.length - 1] >= 0;
      const pts = [{ barOffset: 0, price: anchor }];
      for (let t = 0; t < a.length; t++) pts.push({ barOffset: t + 1, price: at(a[t]) });
      lines.push({ id: 'ep' + i, color: up ? _UP : _DOWN, opacity: 0.4, width: 1, dashed: true, points: pts });
    }
    let band = null;
    if (valid.length >= 3) {
      const upper = [{ barOffset: 0, price: anchor }], lower = [{ barOffset: 0, price: anchor }];
      for (let t = 0; t < scan.horizon; t++) {
        const col = valid.map((r) => r.aftermathPct[t]).sort((x, y) => x - y);
        const lo = col[Math.floor(col.length * 0.1)];
        const hi = col[Math.floor(Math.min(col.length - 1, col.length * 0.9))];
        upper.push({ barOffset: t + 1, price: at(hi) });
        lower.push({ barOffset: t + 1, price: at(lo) });
      }
      band = { color: _BAND, opacity: 0.10, upper, lower };
    }
    return { lines, band };
  }

  // Tiny sparkline canvas of a normalized value series.
  function _labSparkline(values, color) {
    const w = 64, h = 22;
    const cv = document.createElement('canvas');
    cv.width = w * 2; cv.height = h * 2; cv.className = 'tb-lab-spark';
    cv.style.width = w + 'px'; cv.style.height = h + 'px';
    const ctx = cv.getContext('2d');
    ctx.scale(2, 2);
    const vals = values.filter((v) => v != null && Number.isFinite(v));
    if (vals.length >= 2) {
      let lo = Infinity, hi = -Infinity;
      for (const v of vals) { if (v < lo) lo = v; if (v > hi) hi = v; }
      const rng = (hi - lo) || 1;
      ctx.strokeStyle = color; ctx.lineWidth = 1; ctx.lineJoin = 'round';
      ctx.beginPath();
      for (let i = 0; i < vals.length; i++) {
        const x = (i / (vals.length - 1)) * (w - 2) + 1;
        const y = h - 2 - ((vals[i] - lo) / rng) * (h - 4);
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.stroke();
    }
    return cv;
  }

  function _labSelect(value, options, onChange) {
    const sel = document.createElement('select');
    sel.className = 'tb-lab-select';
    for (const o of options) {
      const opt = document.createElement('option');
      opt.value = String(o); opt.textContent = String(o);
      if (o === value) opt.selected = true;
      sel.appendChild(opt);
    }
    sel.addEventListener('change', () => onChange(parseInt(sel.value, 10)));
    return sel;
  }

  function _labField(label, control) {
    const f = document.createElement('div');
    f.className = 'tb-lab-field';
    const l = document.createElement('div');
    l.className = 'tb-lab-field-lbl';
    l.textContent = label;
    f.appendChild(l); f.appendChild(control);
    return f;
  }

  function _renderLabTab(pop) {
    const body = pop.querySelector('.tb-lab-body');
    if (!body) return;
    body.innerHTML = '';

    const candles = (typeof window.__activePaneCandles === 'function')
        ? window.__activePaneCandles() : [];
    if (!candles || candles.length < 50) {
      _labClearProjection();
      const empty = document.createElement('div');
      empty.className = 'tb-lab-empty';
      empty.textContent = 'Not enough data — load more history on the active pane.';
      body.appendChild(empty);
      return;
    }
    const Lab = window.CandlLab;
    if (!Lab) {
      const err = document.createElement('div');
      err.className = 'tb-lab-empty';
      err.textContent = 'Lab module failed to load.';
      body.appendChild(err);
      return;
    }

    if (labTab === 'echoes') _renderLabEchoes(body, candles, Lab);
    else if (labTab === 'oracle') _renderLabOracle(body, candles, Lab);
    else if (labTab === 'clock') { _labClearProjection(); _renderLabClock(body, candles, Lab); }
  }

  function _renderLabEchoes(body, candles, Lab) {
    const scan = Lab.buildEchoScan(candles, _echoWindow, _echoHorizon, _echoMatches);
    // Controls row — Window / Horizon / Matches + Rescan.
    const controls = document.createElement('div');
    controls.className = 'tb-lab-controls';
    controls.appendChild(_labField('Window',
        _labSelect(_echoWindow, [20, 30, 48, 64, 96], (v) => { _echoWindow = v; _renderLabTab(_labPanel); })));
    controls.appendChild(_labField('Horizon',
        _labSelect(_echoHorizon, [12, 24, 48, 72], (v) => { _echoHorizon = v; _renderLabTab(_labPanel); })));
    controls.appendChild(_labField('Matches',
        _labSelect(_echoMatches, [10, 20, 30, 50], (v) => { _echoMatches = v; _renderLabTab(_labPanel); })));
    const rescan = document.createElement('button');
    rescan.type = 'button'; rescan.className = 'tb-lab-btn'; rescan.textContent = 'Rescan';
    rescan.addEventListener('click', () => _renderLabTab(_labPanel));
    controls.appendChild(rescan);
    body.appendChild(controls);

    if (!scan || !scan.results.length) {
      _labClearProjection();
      body.appendChild(_labNote('No similar historical windows found.'));
      return;
    }
    const s = scan.stats;
    const upRate = s.count > 0 ? (s.upCount / s.count) * 100 : 0;
    body.appendChild(_labNote(
        scan.results.length + ' echoes · ' + upRate.toFixed(0) + '% closed higher after '
        + scan.horizon + ' bars · median ' + _labFmtPct(s.medianEndPct)
        + ' · best ' + _labFmtPct(s.bestEndPct) + ' / worst ' + _labFmtPct(s.worstEndPct)));

    // Push the ghost projection (each match's aftermath + envelope) to the chart.
    const anchor = candles[candles.length - 1].c;
    _labPushProjection(_echoProjection(scan, anchor));

    const closes = candles.map((c) => c.c);
    const list = document.createElement('div');
    list.className = 'tb-lab-elist';
    let rank = 0;
    for (const r of scan.results) {
      rank++;
      const endPct = r.aftermathPct ? r.aftermathPct[scan.horizon - 1] : null;
      const up = endPct != null && endPct >= 0;
      const row = document.createElement('div');
      row.className = 'tb-lab-erow';
      const idxEl = document.createElement('span');
      idxEl.className = 'tb-lab-erow-idx'; idxEl.textContent = String(rank);
      // Sparkline of the matched window's shape.
      const seg = closes.slice(r.match.startIndex, r.match.endIndex + 1);
      const spark = _labSparkline(seg, up ? _UP : _DOWN);
      const date = document.createElement('span');
      date.className = 'tb-lab-erow-date';
      date.textContent = new Date(r.matchTime * 1000).toLocaleDateString();
      const val = document.createElement('span');
      val.className = 'tb-lab-erow-val ' + (up ? 'tb-lab-up' : 'tb-lab-down');
      // CandL shows the similarity as a closeness %; approximate from distance.
      val.textContent = (endPct != null ? _labFmtPct(endPct) : '–');
      row.appendChild(idxEl);
      row.appendChild(spark);
      row.appendChild(date);
      row.appendChild(val);
      list.appendChild(row);
    }
    body.appendChild(list);
    body.appendChild(_labNote('Echoes is a historical base rate, not a forecast.'));
  }

  function _renderLabOracle(body, candles, Lab) {
    const controls = document.createElement('div');
    controls.className = 'tb-lab-controls';
    controls.appendChild(_labField('Horizon',
        _labSelect(_oracleHorizon, [24, 48, 96, 144], (v) => { _oracleHorizon = v; _renderLabTab(_labPanel); })));
    controls.appendChild(_labField('Paths',
        _labSelect(_oraclePaths, [250, 500, 1000, 2000], (v) => { _oraclePaths = v; _renderLabTab(_labPanel); })));
    const resim = document.createElement('button');
    resim.type = 'button'; resim.className = 'tb-lab-btn'; resim.textContent = 'Resimulate';
    resim.addEventListener('click', () => _renderLabTab(_labPanel));
    controls.appendChild(resim);
    body.appendChild(controls);

    _labOracleResult = Lab.buildOracle(candles, _oracleHorizon, _oraclePaths);
    const res = _labOracleResult;
    if (!res) {
      _labClearProjection();
      body.appendChild(_labNote('Need at least 200 candles to run a projection.'));
      return;
    }
    const band = res.bandsPct[res.horizon - 1];
    body.appendChild(_labNote(
        'Median outcome: ' + _labFmtPct(res.medianEndPct) + ' · 90% of futures end between '
        + _labFmtPct(band.p5) + ' and ' + _labFmtPct(band.p95)));

    // Push the spaghetti + percentile cone to the chart.
    const anchor = candles[candles.length - 1].c;
    _labPushProjection(_oracleProjection(res, anchor));

    // Target odds with quick ±5 / ±10 chips (price input like CandL).
    body.appendChild(_labSection('Target'));
    const tRow = document.createElement('div');
    tRow.className = 'tb-lab-odds-row';
    const input = document.createElement('input');
    input.type = 'number'; input.step = '0.01';
    input.value = (anchor * 1.0).toFixed(2);
    input.className = 'tb-lab-target-input';
    tRow.appendChild(input);
    body.appendChild(tRow);
    const quick = document.createElement('div');
    quick.className = 'tb-lab-quick';
    for (const q of [5, -5, 10, -10]) {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'tb-lab-chip';
      b.textContent = (q > 0 ? '+' : '') + q + '%';
      b.addEventListener('click', () => { input.value = (anchor * (1 + q / 100)).toFixed(2); paintOdds(); });
      quick.appendChild(b);
    }
    body.appendChild(quick);

    const oddsOut = document.createElement('div');
    oddsOut.className = 'tb-lab-odds-out';
    body.appendChild(oddsOut);
    const paintOdds = () => {
      const targetPrice = parseFloat(input.value);
      oddsOut.innerHTML = '';
      if (!Number.isFinite(targetPrice) || anchor <= 0) return;
      const targetPct = (targetPrice / anchor - 1) * 100;
      const odds = Lab.targetOdds(res, targetPct);
      const mk = (lbl, v) => {
        const r = document.createElement('div');
        r.className = 'tb-lab-odds-line';
        r.innerHTML = '<span>' + lbl + '</span><span class="tb-lab-odds-pct">'
            + v.toFixed(1) + '%</span>';
        return r;
      };
      oddsOut.appendChild(mk('Ends above target', odds.endAbovePct));
      oddsOut.appendChild(mk('Touches within ' + res.horizon + ' bars', odds.touchPct));
    };
    input.addEventListener('input', paintOdds);
    paintOdds();

    body.appendChild(_labNote(
        'Resampled from this asset’s real return history — odds, not prophecy. '
        + 'Not financial advice.'));
  }

  // Radial "Market Clock" — 24 hour wedges + weekday bars, with Volatility /
  // Direction / Volume modes. Mirrors CandL's rose. Hours are LOCAL time.
  function _renderLabClock(body, candles, Lab) {
    const clock = Lab.computeMarketClock(candles);

    const tabs = document.createElement('div');
    tabs.className = 'tb-lab-modes';
    const modes = [['vol', 'Volatility'], ['dir', 'Direction'], ['volume', 'Volume']];
    for (const [id, label] of modes) {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'tb-lab-mode' + (id === _clockMode ? ' tb-lab-mode--on' : '');
      b.textContent = label;
      b.addEventListener('click', () => { _clockMode = id; _renderLabTab(_labPanel); });
      tabs.appendChild(b);
    }
    body.appendChild(tabs);

    const metric = (bk) => _clockMode === 'vol' ? bk.meanAbsReturnPct
        : _clockMode === 'volume' ? bk.meanVolume
        : Math.abs(bk.meanReturnPct);
    const hours = clock.byHourUtc; // local-hour buckets (see lab.js)
    let peak = 0;
    for (const bk of hours) { const m = metric(bk); if (m > peak) peak = m; }
    if (!(peak > 0)) peak = 1;

    // ── Rose canvas ─────────────────────────────────────────────────────
    const size = 300;
    const cv = document.createElement('canvas');
    cv.width = size * 2; cv.height = size * 2;
    cv.style.width = size + 'px'; cv.style.height = size + 'px';
    cv.className = 'tb-lab-rose';
    const ctx = cv.getContext('2d');
    ctx.scale(2, 2);
    const cx = size / 2, cy = size / 2;
    const inner = 26, outer = size / 2 - 30;
    // Guide rings + cardinal labels (00 top, 06 right, 12 bottom, 18 left).
    ctx.strokeStyle = 'rgba(148,163,184,0.25)';
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.arc(cx, cy, outer, 0, Math.PI * 2); ctx.stroke();
    ctx.fillStyle = 'rgba(100,116,139,0.9)';
    ctx.font = '11px Geist, sans-serif';
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText('00', cx, cy - outer - 12);
    ctx.fillText('06', cx + outer + 14, cy);
    ctx.fillText('12', cx, cy + outer + 12);
    ctx.fillText('18', cx - outer - 14, cy);
    const wedge = (Math.PI * 2 / 24) * 0.82;
    for (let h = 0; h < 24; h++) {
      const bk = hours[h];
      const m = metric(bk);
      const r = inner + (m / peak) * (outer - inner);
      const a = (h / 24) * Math.PI * 2 - Math.PI / 2; // 00 at top, clockwise
      const up = bk.meanReturnPct >= 0;
      ctx.fillStyle = bk.samples === 0 ? 'rgba(148,163,184,0.25)'
          : (up ? 'rgba(38,166,154,0.85)' : 'rgba(239,83,80,0.85)');
      ctx.beginPath();
      ctx.moveTo(cx + Math.cos(a) * inner, cy + Math.sin(a) * inner);
      ctx.arc(cx, cy, r, a - wedge / 2, a + wedge / 2);
      ctx.lineTo(cx + Math.cos(a) * inner, cy + Math.sin(a) * inner);
      ctx.closePath();
      ctx.fill();
    }
    body.appendChild(cv);

    // ── Weekday bars ────────────────────────────────────────────────────
    const WD = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    let wpeak = 0;
    for (const bk of clock.byWeekdayUtc) { const m = metric(bk); if (m > wpeak) wpeak = m; }
    if (!(wpeak > 0)) wpeak = 1;
    const wk = document.createElement('div');
    wk.className = 'tb-lab-weekdays';
    // Mon-first ordering, like the screenshot.
    for (const d of [1, 2, 3, 4, 5, 6, 0]) {
      const bk = clock.byWeekdayUtc[d];
      const m = metric(bk);
      const up = bk.meanReturnPct >= 0;
      const col = document.createElement('div');
      col.className = 'tb-lab-wd';
      const barH = Math.max(3, (m / wpeak) * 54);
      col.innerHTML = '<div class="tb-lab-wd-bar" style="height:' + barH.toFixed(0) + 'px;'
          + 'background:' + (up ? 'rgba(38,166,154,0.85)' : 'rgba(239,83,80,0.85)') + '"></div>'
          + '<div class="tb-lab-wd-lbl">' + WD[d] + '</div>';
      wk.appendChild(col);
    }
    body.appendChild(wk);

    body.appendChild(_labNote('Based on ' + Math.round(clock.candleCount / 24)
        + ' days of data · hours shown in your local time'));
  }

  function _closeLabPanel() {
    if (!_labPanel) return;
    _labClearProjection();
    _labPanel.remove();
    _labPanel = null;
  }

  function _openLabPanel() {
    if (_labPanel) { _closeLabPanel(); return; } // toggle
    const card = document.createElement('div');
    card.className = 'tb-lab-panel';

    const head = document.createElement('div');
    head.className = 'tb-lab-head';
    const titleWrap = document.createElement('div');
    const title = document.createElement('span');
    title.className = 'tb-lab-title';
    title.textContent = labTab === 'echoes' ? 'Echoes'
        : labTab === 'oracle' ? 'Oracle' : 'Market clock';
    titleWrap.appendChild(title);
    head.appendChild(titleWrap);
    const closeBtn = document.createElement('button');
    closeBtn.type = 'button'; closeBtn.className = 'tb-lab-close'; closeBtn.innerHTML = '&times;';
    closeBtn.addEventListener('click', _closeLabPanel);
    head.appendChild(closeBtn);
    card.appendChild(head);

    const tabs = document.createElement('div');
    tabs.className = 'tb-tabs tb-lab-tabs';
    const tabSpecs = [
      { id: 'echoes', label: 'Echoes' },
      { id: 'oracle', label: 'Oracle' },
      { id: 'clock', label: 'Market Clock' },
    ];
    for (const t of tabSpecs) {
      const tab = document.createElement('button');
      tab.type = 'button';
      tab.className = 'tb-tab' + (t.id === labTab ? ' tb-tab--on' : '');
      tab.textContent = t.label;
      tab.addEventListener('click', () => {
        if (t.id === labTab) return;
        labTab = t.id;
        for (const el of tabs.querySelectorAll('.tb-tab')) el.classList.remove('tb-tab--on');
        tab.classList.add('tb-tab--on');
        title.textContent = labTab === 'echoes' ? 'Echoes'
            : labTab === 'oracle' ? 'Oracle' : 'Market clock';
        _renderLabTab(_labPanel);
      });
      tabs.appendChild(tab);
    }
    card.appendChild(tabs);

    const bodyEl = document.createElement('div');
    bodyEl.className = 'tb-lab-body';
    card.appendChild(bodyEl);

    document.body.appendChild(card);
    _labPanel = card;
    _renderLabTab(card);
  }

  labBtn.addEventListener('click', _openLabPanel);

  root.appendChild(labBtn);

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
  //   [Symbol] [Timeframe] [Style] [fx] [Cursor]
  //       ...flex spacer...
  //   [Layout] [INSTANT] [Order Defaults] [Snap] [Settings]
  // `appendChild` of an existing child MOVES it (doesn't create a duplicate);
  // the first right-group button gets `.tb-right-start` which applies
  // `margin-left: auto` for the flex spacer.
  // NOTE: `drawBtn` and `cursorBtn` are intentionally omitted — drawing tools
  // and the crosshair/cursor-mode picker both moved to the floating left rail
  // (buildDrawRail). drawBtn stays constructed (its repaint helpers are still
  // referenced) but is never mounted.
  const ORDER = [
    symWrap, tfBtn, styleBtn, fxBtn,
    layoutBtn, labBtn, badge, odBtn, snapBtn, settingsBtn,
  ];
  // Move the right-anchor class — Layout is now the first right-group
  // button instead of the INSTANT badge.
  badge.classList.remove('tb-right-start');
  layoutBtn.classList.add('tb-right-start');
  for (const el of ORDER) root.appendChild(el);
})();
