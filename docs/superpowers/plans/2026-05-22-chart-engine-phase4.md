# Chart Engine — Phase 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make each chart pane an interactive trading surface. Add a bid/ask/qty header row, a hover `+` icon in the right gutter, a `+` action menu, and a qty selector — all 6 order-entry points open the existing `PlaceOrderScreenWeb` widget pre-filled with the right side / prctype / price / qty.

**Architecture:** Bid/ask comes from existing LTP packets (`bp1`/`sp1` on `tickState`). Qty is new persisted `PaneState.qty` (default = `scrip.ls`, resets on symbol-set). Header strip + `+` icon are JS canvas drawings with hit-test entries; clicks post new message types to Flutter. Flutter routes each click through a single `_openPlaceOrderScreen(...)` helper that calls `ResponsiveNavigation.toPlaceOrderScreen` with `fromChart: true` + a prefilled `OrderScreenArgs`. The PlaceOrderScreen IS the confirm — no custom dialogs.

**Tech Stack:** Flutter (Riverpod 3, dart:html, pointer_interceptor); vanilla JS + Canvas 2D inside iframe.

---

## Project conventions

- **No git commits in plan steps.** User commits manually after testing the whole phase.
- **Static gates after every code edit:** `flutter analyze lib/screens/web/chart_engine` for Dart; `node --check web/chart-engine/<file>.js` for JS. Don't move on if either reports errors.
- **Manual smoke checkpoints between groups** — pause and let the user verify.
- **Spec reference:** `docs/superpowers/specs/2026-05-22-chart-engine-phase4-design.md` is the source of truth for layout, colours, edge cases.
- **Existing widget reuse:** `PlaceOrderScreenWeb` (lib/screens/web/order/place_order_screen_web.dart) opened via `ResponsiveNavigation.toPlaceOrderScreen(context, arguments)` with the `fromChart: true` flag. Pre-fill via `OrderScreenArgs.raw` map keys `prctyp`, `qty`, `prc`. Plain fields: `exchange`, `token`, `tSym`, `prd`, `transType` (bool: true=BUY), `ltp` (pre-fills price field), `lotSize`.
- **Chip styling rule** (per `[[feedback-chips-solid-colored]]`): solid line-colour bg + white text; never transparent; ≥10px gap when two chips sit adjacent.

## File map

### Created (Flutter)
| Path | Responsibility |
|---|---|
| `lib/screens/web/chart_engine/state/place_order_prefill.dart` | Pure builder for `Map<String, dynamic>` arguments to `ResponsiveNavigation.toPlaceOrderScreen`. One function per entry-point variant. Unit-testable, no Flutter deps. |
| `lib/screens/web/chart_engine/widgets/qty_selector_popup.dart` | OverlayEntry-friendly popup with text input + ± buttons + multiplier presets + reset/last; commits via callback. |
| `lib/screens/web/chart_engine/widgets/plus_menu_popup.dart` | OverlayEntry-friendly action menu with 4 items, anchored at click coords. |

### Modified (Flutter)
| Path | What changes |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | New `int qty` field on `PaneState` (default 1; reset to `scrip.ls` on `setPaneSymbol`); `copyWith`/`toJson`/`fromJson` updated; new notifier method `setPaneQty(int index, int qty)` (clamps to multiple of `scrip.ls`). |
| `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart` | New encoder `encodeSetPaneQty(String paneId, int qty)`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | `_pushedQty` diff cache; per-pane push in `_pushSession`; new inbound handlers `bidClicked`/`askClicked`/`qtyChipClicked`/`plusClicked`; `_openPlaceOrderScreen` helper; popup OverlayEntry plumbing. |

### Modified (JS — `web/chart-engine/`)
| Path | What changes |
|---|---|
| `theme.js` | Add `long` + `short` palette colour constants in both themes. |
| `chart.js` | `this.qty` instance state; `tickState.bid`/`tickState.ask`; parse `bp1`/`sp1` in `ingestTick`; `setQty(qty)`; new `_drawBidAskQtyStrip(plot)` called from header path; `_drawPlusIcon(plot)` called from crosshair path; hit-test array extended for the 4 new clickable zones; refactor `_overlayLineColor` to read `palette.long`/`palette.short`. |
| `chart-engine.js` | `case 'setPaneQty'` handler that forwards to `chart.setQty(value.qty)`. |

---

## Task ordering (high level)

1. **Group A — Palette + bid/ask data.** Palette constants, refactor overlay colours, parse bp1/sp1. End state: existing Phase 3 overlays unchanged visually but read colour from the palette; tickState now carries bid/ask.
2. **Group B — Qty state + bridge plumbing.** PaneState.qty, bridge encoder, JS `setQty`. End state: qty flows from Flutter to iframe (no visible change yet).
3. **Group C — Bid/ask/qty header strip.** Render strip; hit-test for chip clicks. End state: strip visible; clicks post the right outbound messages.
4. **Group D — `+` icon + click.** Render in gutter on hover; hit-test; outbound message. End state: clicking `+` posts `plusClicked` with the price.
5. **Group E — Flutter popups + PlaceOrderScreen wiring.** Qty selector, `+` menu, prefill helper, shell handlers. End state: full UX works end-to-end.
6. **Group F — Static gates + smoke.**

---

# Group A — Palette + bid/ask data

End state: `palette.long`/`palette.short` available; Phase 3 overlay chips use them (no visible change); LTP packets carry bid/ask into `tickState`.

---

### Task A1: Add `long` + `short` palette constants

**Files:**
- Modify: `web/chart-engine/theme.js`

- [ ] **Step 1: Add to the `dark` palette block**

Find the `dark: { ... }` object. Add directly after the `axisText` / `axisTextStrong` lines:

```javascript
    long: '#3B82F6',
    short: '#EF4444',
```

- [ ] **Step 2: Add to the `light` palette block**

Find the `light: { ... }` object. Add the equivalent:

```javascript
    long: '#2563EB',
    short: '#DC2626',
```

- [ ] **Step 3: Static check**

Run: `node --check web/chart-engine/theme.js`
Expected: no output.

---

### Task A2: Refactor `_overlayLineColor` + `_overlayLabelAccent` to use the palette

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Update `_overlayLineColor`**

Find the existing method:

```javascript
  _overlayLineColor(ov) {
    const side = ov.side === 'buy' ? 'long' : 'short';
    if (ov.kind === 'sl' || ov.kind === 'sl-l') return '#EF4444';
    return side === 'long' ? '#3B82F6' : '#EF4444';
  }
```

Replace with:

```javascript
  _overlayLineColor(ov) {
    if (ov.kind === 'sl' || ov.kind === 'sl-l') return this.palette.short;
    return ov.side === 'buy' ? this.palette.long : this.palette.short;
  }
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

(Phase 3 overlays should look identical — `palette.long` resolves to the same blue and `palette.short` to the same red as the previous literals.)

---

### Task A3: Parse `bp1` / `sp1` in `ingestTick`

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Initialise bid/ask on `tickState` in the constructor**

Find:

```javascript
    this.tickState = { lp: null, v: null, ft: null };
```

Replace with:

```javascript
    this.tickState = { lp: null, v: null, ft: null, bid: null, ask: null };
```

- [ ] **Step 2: Also reset bid/ask in `_resetData`**

Find:

```javascript
    this.tickState = { lp: null, v: null, ft: null };
```

(inside `_resetData()`)

Replace with:

```javascript
    this.tickState = { lp: null, v: null, ft: null, bid: null, ask: null };
```

- [ ] **Step 3: Parse `bp1` / `sp1` in `ingestTick`**

Find the existing block at the top of `ingestTick`:

```javascript
    const lp = packet.lp != null ? +packet.lp : null;
    const v = packet.v != null ? +packet.v : null;
    const ft = packet.ft != null ? +packet.ft : null;
    if (lp != null) this.tickState.lp = lp;
    if (v != null) this.tickState.v = v;
    if (ft != null) this.tickState.ft = ft;
```

Add directly after it:

```javascript
    const bid = packet.bp1 != null ? +packet.bp1 : null;
    const ask = packet.sp1 != null ? +packet.sp1 : null;
    let bidAskChanged = false;
    if (bid != null && bid !== this.tickState.bid) { this.tickState.bid = bid; bidAskChanged = true; }
    if (ask != null && ask !== this.tickState.ask) { this.tickState.ask = ask; bidAskChanged = true; }
    if (bidAskChanged) this.scheduleRedraw();
```

(This runs BEFORE the existing `lp/v/ft` early-return, so bid/ask updates are picked up even on ticks that don't carry the other fields.)

- [ ] **Step 4: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Smoke checkpoint — Group A

- [ ] Hard-reload. Existing Phase 3 chips look identical (palette refactor is a no-op visually).
- [ ] DevTools console while a chart is showing live ticks:
  ```js
  const w = document.querySelector('iframe').contentWindow;
  w.panes.get('0').tickState
  ```
  Should now include `bid` and `ask` populated to live values (after at least one tick has flowed in).

---

# Group B — Qty state + bridge plumbing

End state: `PaneState.qty` exists, persisted; Flutter pushes `setPaneQty` per pane; iframe stores it but doesn't render anything yet.

---

### Task B1: Add `qty` to `PaneState`

**Files:**
- Modify: `lib/screens/web/chart_engine/state/chart_engine_store.dart`

- [ ] **Step 1: Add the `qty` field**

Find the existing `PaneState` class. Add `qty` as a new final field with default 1, update the constructor, `copyWith`, `toJson`, `fromJson`:

```dart
class PaneState {
  final ChartScrip? scrip;
  final int timeframeMinutes;
  final ChartOverlays overlays;
  final int qty;
  const PaneState({
    this.scrip,
    this.timeframeMinutes = 1,
    this.overlays = const ChartOverlays(),
    this.qty = 1,
  });

  PaneState copyWith({
    Object? scrip = _sentinel,
    int? timeframeMinutes,
    ChartOverlays? overlays,
    int? qty,
  }) =>
      PaneState(
        scrip: identical(scrip, _sentinel) ? this.scrip : scrip as ChartScrip?,
        timeframeMinutes: timeframeMinutes ?? this.timeframeMinutes,
        overlays: overlays ?? this.overlays,
        qty: qty ?? this.qty,
      );

  Map<String, dynamic> toJson() => {
        if (scrip != null) 'scrip': scrip!.toJson(),
        'timeframeMinutes': timeframeMinutes,
        'overlays': overlays.toJson(),
        'qty': qty,
      };

  static PaneState fromJson(Map<String, dynamic> j) => PaneState(
        scrip: j['scrip'] is Map
            ? ChartScrip.fromJson(j['scrip'] as Map<String, dynamic>)
            : null,
        timeframeMinutes: (j['timeframeMinutes'] as num?)?.toInt() ?? 1,
        overlays: j['overlays'] is Map
            ? ChartOverlays.fromJson(j['overlays'] as Map<String, dynamic>)
            : const ChartOverlays(),
        qty: (j['qty'] as num?)?.toInt() ?? 1,
      );
}
```

- [ ] **Step 2: Update `setPaneSymbol` on the notifier so qty resets to `scrip.ls`**

Find:

```dart
  void setPaneSymbol(int index, ChartScrip scrip) {
    if (index < 0 || index >= state.panes.length) return;
    state = state.copyWithPane(index, state.panes[index].copyWith(scrip: scrip));
    _schedulePersist();
  }
```

Replace with:

```dart
  void setPaneSymbol(int index, ChartScrip scrip) {
    if (index < 0 || index >= state.panes.length) return;
    final ls = scrip.ls > 0 ? scrip.ls : 1;
    state = state.copyWithPane(
        index, state.panes[index].copyWith(scrip: scrip, qty: ls));
    _schedulePersist();
  }
```

- [ ] **Step 3: Add `setPaneQty` setter**

Add to the notifier (next to `setPaneOverlays`):

```dart
  void setPaneQty(int index, int qty) {
    if (index < 0 || index >= state.panes.length) return;
    final pane = state.panes[index];
    final ls = pane.scrip?.ls != null && pane.scrip!.ls > 0 ? pane.scrip!.ls : 1;
    final stepped = ((qty / ls).round()).clamp(1, 1 << 30) * ls;
    if (stepped == pane.qty) return;
    state = state.copyWithPane(index, pane.copyWith(qty: stepped));
    _schedulePersist();
  }
```

- [ ] **Step 4: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/state/chart_engine_store.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task B2: Add `encodeSetPaneQty` to the bridge

**Files:**
- Modify: `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart`

- [ ] **Step 1: Append the encoder at the end of the file**

```dart
String encodeSetPaneQty(String paneId, int qty) =>
    jsonEncode({'type': 'setPaneQty', 'value': {'paneId': paneId, 'qty': qty}});
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/utils/chart_engine_bridge.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task B3: Add `setQty` to `Chart` + `case 'setPaneQty'` to chart-engine.js

**Files:**
- Modify: `web/chart-engine/chart.js`
- Modify: `web/chart-engine/chart-engine.js`

- [ ] **Step 1: Add `this.qty` in the constructor**

In `chart.js` constructor, find:

```javascript
    // Selection
    this.scrip = null;           // { exch, token, tsym, dispName, ls, ti }
    this.timeframeMinutes = 1;
```

Add directly after:

```javascript
    this.qty = 1;                // per-pane order qty; pushed via setQty
```

- [ ] **Step 2: Add the `setQty` instance method**

Place directly above `setPaneOverlays` in `chart.js`:

```javascript
  setQty(qty) {
    const q = Number.isFinite(qty) ? Math.max(1, Math.trunc(qty)) : 1;
    if (q === this.qty) return;
    this.qty = q;
    this.scheduleRedraw();
  }
```

- [ ] **Step 3: Add the `setPaneQty` case in chart-engine.js**

In the `handleMessage` switch, directly after the `case 'setPaneOverlays':` block, add:

```javascript
    case 'setPaneQty': {
      const { paneId, qty } = d.value || {};
      if (typeof paneId !== 'string' || typeof qty !== 'number') return;
      const chart = panes.get(paneId);
      if (chart) chart.setQty(qty);
      break;
    }
```

- [ ] **Step 4: Static checks**

Run:
```
node --check web/chart-engine/chart.js
node --check web/chart-engine/chart-engine.js
```
Both expected: no output.

---

### Task B4: Wire qty push into `_pushSession`

**Files:**
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add the diff cache field**

Next to the existing `_pushedSymbolKey` / `_pushedTimeframe` / `_pushedOverlaysJson` / `_pushedPaneOverlaysJson` maps:

```dart
final Map<int, int> _pushedQty = {};
```

- [ ] **Step 2: Clear it on layout change**

In `_pushSession`, locate the existing layout-change branch that clears the other per-pane caches:

```dart
    _pushedSymbolKey.clear();
    _pushedTimeframe.clear();
    _pushedOverlaysJson.clear();
    _pushedPaneOverlaysJson.clear();
```

Add:

```dart
    _pushedQty.clear();
```

- [ ] **Step 3: Push per pane**

Inside the per-pane loop in `_pushSession`, after the existing `setOverlays` push and BEFORE the overlay payload push (or anywhere in the per-pane body), add:

```dart
      if (force || _pushedQty[i] != pane.qty) {
        _pushedQty[i] = pane.qty;
        _post(encodeSetPaneQty(i.toString(), pane.qty));
      }
```

- [ ] **Step 4: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -5`
Expected: `No issues found!`

---

### Smoke checkpoint — Group B

- [ ] Hard-reload. Pick a symbol that has a lot size > 1 (e.g. NIFTY option). In DevTools:
  ```js
  document.querySelector('iframe').contentWindow.panes.get('0').qty
  ```
  Should equal the symbol's `ls`.
- [ ] Switch to a different symbol with a different `ls`. The above should now reflect the new `ls`.
- [ ] Reload tab → qty restored from prefs.

---

# Group C — Bid/ask/qty header strip

End state: row 3 visible below OHLC. Bid chip click, ask chip click, qty chip click all post the right outbound messages.

---

### Task C1: Add `_drawBidAskQtyStrip(plot)` + register new hit-test entries

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add a header-hits state container**

In the constructor, near `this._overlayHits`:

```javascript
    this._headerHits = []; // { rect, kind: 'bid'|'ask'|'qty' }
```

- [ ] **Step 2: Add the strip method**

Add directly ABOVE `_drawPaneChip` in `chart.js`:

```javascript
  _drawBidAskQtyStrip(plot) {
    this._headerHits = [];
    if (!this.scrip) return;

    const ctx = this.ctx;
    const bid = this.tickState.bid;
    const ask = this.tickState.ask;
    const dp = this._priceDecimals();
    const stripY = 46;     // top of strip
    const chipH = 18;
    const padX = 6;
    const gap = 6;

    ctx.font = '700 11px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';

    let x = plot.left + 4;

    // --- Bid chip ---
    const bidText = bid != null ? bid.toFixed(dp) : '—';
    const bidW = ctx.measureText(bidText).width + padX * 2;
    ctx.fillStyle = this.palette.short;
    this._roundedRect(x, stripY, bidW, chipH, 3);
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(bidText, x + padX, stripY + chipH / 2);
    if (bid != null) {
      this._headerHits.push({
        rect: { x, y: stripY, w: bidW, h: chipH },
        kind: 'bid', price: bid,
      });
    }
    x += bidW + gap;

    // --- Spread text ---
    if (bid != null && ask != null) {
      const spread = (ask - bid);
      const spreadText = spread.toFixed(dp);
      ctx.font = '500 11px Geist, sans-serif';
      ctx.fillStyle = spread < 0 ? this.palette.short : this.palette.axisText;
      ctx.fillText(spreadText, x, stripY + chipH / 2);
      x += ctx.measureText(spreadText).width + gap;
    }

    // --- Qty chip ---
    ctx.font = '600 11px Geist, sans-serif';
    const qtyText = String(this.qty);
    const qtyW = ctx.measureText(qtyText).width + padX * 2;
    // Solid card-bg colour with a thin border, white text (matches the chip
    // rule even though "qty" isn't a directional category).
    ctx.fillStyle = this.palette.crosshairChip;
    this._roundedRect(x, stripY, qtyW, chipH, 3);
    ctx.fill();
    ctx.strokeStyle = this.palette.axisText;
    ctx.lineWidth = 1;
    this._roundedRect(x, stripY, qtyW, chipH, 3);
    ctx.stroke();
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(qtyText, x + padX, stripY + chipH / 2);
    this._headerHits.push({
      rect: { x, y: stripY, w: qtyW, h: chipH },
      kind: 'qty',
    });
    x += qtyW + gap;

    // --- Ask chip ---
    ctx.font = '700 11px Geist, sans-serif';
    const askText = ask != null ? ask.toFixed(dp) : '—';
    const askW = ctx.measureText(askText).width + padX * 2;
    ctx.fillStyle = this.palette.long;
    this._roundedRect(x, stripY, askW, chipH, 3);
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(askText, x + padX, stripY + chipH / 2);
    if (ask != null) {
      this._headerHits.push({
        rect: { x, y: stripY, w: askW, h: chipH },
        kind: 'ask', price: ask,
      });
    }
  }
```

- [ ] **Step 3: Add the strip's opaque bg + call from `_drawOhlc`**

In `_drawOhlc`, find the section that fills the OHLC strip's opaque background:

```javascript
    const stripH = haveCandles ? 40 : 24;
    const stripW = Math.max(chipW, ohlcW) + 8;
    this.ctx.fillStyle = this.palette.bg;
    this.ctx.fillRect(plot.left, 0, stripW, stripH);
```

Replace with (taller strip when the scrip is set so the bid/ask row has an opaque bg too):

```javascript
    const stripH = this.scrip ? 64 : (haveCandles ? 40 : 24);
    const stripW = Math.max(chipW, ohlcW, 220) + 8; // 220 covers the bid/ask strip when OHLC is short
    this.ctx.fillStyle = this.palette.bg;
    this.ctx.fillRect(plot.left, 0, stripW, stripH);
```

Then at the end of `_drawOhlc`, after the OHLC drawing loop, add:

```javascript
    this._drawBidAskQtyStrip(plot);
```

- [ ] **Step 4: Extend `_overlayHitTest` to also check `_headerHits`**

Find `_overlayHitTest` and modify it to check header hits FIRST (header hits take priority over overlay hits since they're in different areas):

```javascript
  _overlayHitTest(x, y) {
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
```

Note: the return shape changed — it now has a `kind` discriminator. Callers (cursor logic in mousemove, and the click intercept in mousedown) must be updated accordingly in the next step.

- [ ] **Step 5: Update mousemove cursor logic for the new hit shape**

Find the existing mousemove block where the cursor is set when an overlay hit is detected:

```javascript
          const hit = this._overlayHitTest(x, y);
          if (hit) {
            wrap.style.cursor = 'pointer';
          } else {
            const z = this._hitZone(x, y);
            wrap.style.cursor = z === 'zoom-y' ? 'ns-resize'
              : z === 'zoom-x' ? 'ew-resize' : 'crosshair';
          }
```

Leave it — the truthy check still works correctly because both `header` and `overlay` hits set cursor to pointer.

- [ ] **Step 6: Update mousedown intercept for the new hit shape**

Find the existing overlay click intercept in `_attachInteraction`'s mousedown handler:

```javascript
      const ovHit = this._overlayHitTest(x, y);
      if (ovHit) {
        e.preventDefault();
        e.stopPropagation();
        const msgType = ovHit.action === 'close'
            ? 'overlayCloseRequested' : 'overlayClicked';
        try {
          parent.postMessage(JSON.stringify({
            type: msgType,
            value: {
              paneId: this.paneId,
              overlayId: ovHit.overlayId,
              clientX: e.clientX,
              clientY: e.clientY,
            },
          }), '*');
        } catch (_) {}
        return;
      }
```

Replace with (branches on kind):

```javascript
      const hit = this._overlayHitTest(x, y);
      if (hit) {
        e.preventDefault();
        e.stopPropagation();
        let msg = null;
        if (hit.kind === 'overlay') {
          msg = {
            type: hit.action === 'close' ? 'overlayCloseRequested' : 'overlayClicked',
            value: {
              paneId: this.paneId,
              overlayId: hit.overlayId,
              clientX: e.clientX,
              clientY: e.clientY,
            },
          };
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
        }
        if (msg) {
          try { parent.postMessage(JSON.stringify(msg), '*'); } catch (_) {}
        }
        return;
      }
```

- [ ] **Step 7: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Smoke checkpoint — Group C (visual only — handlers added in Group E)

- [ ] Hard-reload. The 3rd header row is visible with bid (red), spread (grey text), qty (dark with border), ask (blue/green) chips.
- [ ] DevTools console: register a message listener and click the qty chip → see `qtyChipClicked`. Click bid → `bidClicked` with price. Click ask → `askClicked` with price.
- [ ] Hover the qty chip → cursor → pointer.

---

# Group D — `+` icon in right gutter

End state: hovering inside the plot shows a `+` icon at the cursor y in the right gutter; click posts `plusClicked`.

---

### Task D1: Add `_drawPlusIcon(plot)` + extend hit-test

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add a plus-hit state container**

In the constructor, near `this._headerHits`:

```javascript
    this._plusHit = null; // { rect, price } or null
```

- [ ] **Step 2: Add the draw method**

Add directly BELOW `_drawBidAskQtyStrip`:

```javascript
  _drawPlusIcon(plot, lo, hi, priceToY, yToPrice) {
    this._plusHit = null;
    if (!this.scrip || !this.hover.inside || this.hover.x == null) return;
    if (this._dragMode) return;
    const y = this.hover.y;
    if (y < plot.top || y > plot.bottom) return;
    const size = 16;
    const x = plot.right + 8;
    const top = y - size / 2;
    const ctx = this.ctx;
    ctx.fillStyle = this.palette.crosshairChip;
    this._roundedRect(x, top, size, size, 3);
    ctx.fill();
    ctx.strokeStyle = this.palette.axisText;
    ctx.lineWidth = 1;
    this._roundedRect(x, top, size, size, 3);
    ctx.stroke();
    ctx.strokeStyle = this.palette.axisTextStrong;
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
      price: yToPrice(y),
    };
  }
```

- [ ] **Step 3: Call from `draw()` after the crosshair price chip**

In `draw()`, find the crosshair block — specifically the section after the price chip is drawn:

```javascript
      // Price chip in right gutter.
      const price = yToPrice(this.hover.y);
      if (price > 0) this._drawChip(plot.right + 2, this.hover.y,
          price.toFixed(this._priceDecimals()));
    }
```

Add directly after the closing `}`:

```javascript
    this._drawPlusIcon(plot, lo, hi, priceToY, yToPrice);
```

- [ ] **Step 4: Extend `_overlayHitTest` to also check `_plusHit`**

Find `_overlayHitTest`. Add at the very top (before the header hits loop):

```javascript
    if (this._plusHit) {
      const r = this._plusHit.rect;
      if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
        return { kind: 'plus', price: this._plusHit.price };
      }
    }
```

- [ ] **Step 5: Update mousedown intercept for `plus` kind**

In the mousedown handler block from Task C1 Step 6, add a new branch inside the `if (hit)` block:

```javascript
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
        }
```

(Insert it after the `header` branch and before the closing of `if (hit)`.)

- [ ] **Step 6: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Smoke checkpoint — Group D (visual only — handler added in Group E)

- [ ] Hard-reload. Hover anywhere in the plot → `+` icon appears at cursor y in the right gutter (just to the right of `plot.right`).
- [ ] Move cursor → `+` follows.
- [ ] DevTools console: click `+` → see `plusClicked` logged with the price at the cursor.

---

# Group E — Flutter popups + PlaceOrderScreen wiring

End state: clicks on bid/ask/qty/`+`/`+ menu items` all open the right popup or PlaceOrderScreen.

---

### Task E1: Create the prefill helper

**Files:**
- Create: `lib/screens/web/chart_engine/state/place_order_prefill.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';

/// Variants of an order pre-fill — used by the chart-overlay layer when
/// opening the existing `PlaceOrderScreenWeb` from a chip / menu item.
enum OrderPrefillKind {
  buyLimit,
  sellLimit,
  buyStopMkt,
  sellStopMkt,
  buyStopLmt,
  sellStopLmt,
  blank, // "Create new order…" — symbol + qty only, no side / type / price
}

/// Builds the `arguments` Map for `ResponsiveNavigation.toPlaceOrderScreen`.
///
/// `price` is interpreted as: limit price for *Limit kinds, trigger price for
/// *StopMkt kinds, trigger price for *StopLmt kinds (the corresponding
/// limit price uses `price - ti` for sell / `price + ti` for buy).
Map<String, dynamic> buildOrderScreenArgs({
  required ChartScrip scrip,
  required int qty,
  required OrderPrefillKind kind,
  double? price,
}) {
  String? prctyp;
  bool? isBuy;
  double? prc;
  double? trgprc;
  switch (kind) {
    case OrderPrefillKind.buyLimit:
      prctyp = 'LMT'; isBuy = true; prc = price;
      break;
    case OrderPrefillKind.sellLimit:
      prctyp = 'LMT'; isBuy = false; prc = price;
      break;
    case OrderPrefillKind.buyStopMkt:
      prctyp = 'SL-MKT'; isBuy = true; trgprc = price;
      break;
    case OrderPrefillKind.sellStopMkt:
      prctyp = 'SL-MKT'; isBuy = false; trgprc = price;
      break;
    case OrderPrefillKind.buyStopLmt:
      prctyp = 'SL-LMT'; isBuy = true; trgprc = price;
      prc = price != null ? price + scrip.ti : null;
      break;
    case OrderPrefillKind.sellStopLmt:
      prctyp = 'SL-LMT'; isBuy = false; trgprc = price;
      prc = price != null ? price - scrip.ti : null;
      break;
    case OrderPrefillKind.blank:
      // No side, no type, no price — open the form blank-ish.
      break;
  }

  final raw = <String, dynamic>{
    if (prctyp != null) 'prctyp': prctyp,
    'qty': qty.toString(),
    if (prc != null) 'prc': prc.toStringAsFixed(2),
    if (trgprc != null) 'trgprc': trgprc.toStringAsFixed(2),
  };

  return {
    'orderArg': {
      'exchange': scrip.exch,
      'token': scrip.token,
      'tSym': scrip.tsym,
      if (isBuy != null) 'transType': isBuy,
      if (prc != null) 'ltp': prc.toStringAsFixed(2),
      if (prc == null && trgprc != null) 'ltp': trgprc.toStringAsFixed(2),
      'lotSize': scrip.ls.toString(),
      'raw': raw,
    },
    'scripInfo': {
      'exch': scrip.exch,
      'token': scrip.token,
      'tsym': scrip.tsym,
      'dispName': scrip.dispName,
      'ls': scrip.ls,
      'ti': scrip.ti,
    },
    'isBskt': 'false',
    'fromChart': true,
  };
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/state/place_order_prefill.dart 2>&1 | tail -5`
Expected: `No issues found!`

(Note: the `orderArg` and `scripInfo` shapes are passed as `Map`s — the receiving widget's `ResponsiveNavigation.toPlaceOrderScreen` is responsible for converting them to `OrderScreenArgs` / `ScripInfoModel`. If during plan-execution the receiver expects a typed model instead of a `Map`, switch to constructing those types directly here.)

---

### Task E2: Create the qty selector popup

**Files:**
- Create: `lib/screens/web/chart_engine/widgets/qty_selector_popup.dart`

- [ ] **Step 1: Write the widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

class QtySelectorPopup extends StatefulWidget {
  final Offset anchor;        // top-left in app coords
  final int initialQty;
  final int lotSize;
  final int? lastUsed;        // most-recent committed qty for this scrip; null if none
  final ValueChanged<int> onCommit;
  final VoidCallback onDismiss;

  const QtySelectorPopup({
    super.key,
    required this.anchor,
    required this.initialQty,
    required this.lotSize,
    required this.onCommit,
    required this.onDismiss,
    this.lastUsed,
  });

  @override
  State<QtySelectorPopup> createState() => _QtySelectorPopupState();
}

class _QtySelectorPopupState extends State<QtySelectorPopup> {
  late final TextEditingController _ctl;
  late int _qty;
  final List<int> _multipliers = const [1, 5, 25, 100, 500, 1000];

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty;
    _ctl = TextEditingController(text: _qty.toString());
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  int _roundToLot(int v) {
    final ls = widget.lotSize > 0 ? widget.lotSize : 1;
    final stepped = ((v / ls).round()).clamp(1, 1 << 30) * ls;
    return stepped;
  }

  void _commit(int v) {
    final r = _roundToLot(v);
    setState(() {
      _qty = r;
      _ctl.text = r.toString();
    });
    widget.onCommit(r);
  }

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final screen = MediaQuery.of(context).size;
    const w = 240.0;
    final left = widget.anchor.dx.clamp(8.0, screen.width - w - 8.0);
    final top = widget.anchor.dy.clamp(8.0, screen.height - 320.0);

    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
          ),
        ),
      ),
      Positioned(
        left: left,
        top: top,
        width: w,
        child: PointerInterceptor(
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Quantity',
                      style: MyntWebTextStyles.caption(context,
                          fontWeight: MyntFonts.semiBold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _ctl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (s) {
                      final v = int.tryParse(s) ?? _qty;
                      _commit(v);
                      widget.onDismiss();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _commit(_qty - widget.lotSize),
                        child: const Text('−'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _commit(_qty + widget.lotSize),
                        child: const Text('+'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in _multipliers)
                        OutlinedButton(
                          onPressed: () => _commit(m * widget.lotSize),
                          child: Text(m.toString()
                              + (widget.lotSize == 1 ? '' : '×')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _commit(widget.lotSize),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextButton(
                        onPressed: widget.lastUsed == null
                            ? null
                            : () => _commit(widget.lastUsed!),
                        child: const Text('Last'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/widgets/qty_selector_popup.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task E3: Create the `+` menu popup

**Files:**
- Create: `lib/screens/web/chart_engine/widgets/plus_menu_popup.dart`

- [ ] **Step 1: Write the widget**

```dart
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/place_order_prefill.dart';

class PlusMenuPopup extends StatelessWidget {
  final Offset anchor;
  final String symbol;
  final int qty;
  final double price;
  final ValueChanged<OrderPrefillKind> onPick;
  final VoidCallback onDismiss;

  const PlusMenuPopup({
    super.key,
    required this.anchor,
    required this.symbol,
    required this.qty,
    required this.price,
    required this.onPick,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final long = resolveThemeColor(context,
        dark: const Color(0xFF3B82F6), light: const Color(0xFF2563EB));
    final short = resolveThemeColor(context,
        dark: const Color(0xFFEF4444), light: const Color(0xFFDC2626));

    final screen = MediaQuery.of(context).size;
    const w = 340.0;
    final left = anchor.dx.clamp(8.0, screen.width - w - 8.0);
    final top = anchor.dy.clamp(8.0, screen.height - 220.0);

    final priceStr = price.toStringAsFixed(2);

    Widget item(String label, IconData icon, Color color, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label, style: MyntWebTextStyles.body(context))),
          ]),
        ),
      );
    }

    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
      ),
      Positioned(
        left: left,
        top: top,
        width: w,
        child: PointerInterceptor(
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  item('Buy $qty $symbol @ $priceStr limit',
                      Icons.arrow_upward, long,
                      () { onPick(OrderPrefillKind.buyLimit); }),
                  item('Sell $qty $symbol @ $priceStr stop',
                      Icons.arrow_downward, short,
                      () { onPick(OrderPrefillKind.sellStopMkt); }),
                  item('Sell $qty $symbol @ $priceStr stop, '
                      '${(price - 0.05).toStringAsFixed(2)} limit',
                      Icons.arrow_downward, short,
                      () { onPick(OrderPrefillKind.sellStopLmt); }),
                  const Divider(height: 1),
                  item('Create new order…',
                      Icons.add_circle_outline,
                      resolveThemeColor(context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary),
                      () { onPick(OrderPrefillKind.blank); }),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
```

Note: the `0.05` offset in the SL-LMT item label is a display approximation; the actual `prc` is computed inside `buildOrderScreenArgs` using `scrip.ti`. If the discrepancy bothers you visually, pass `scrip.ti` into the popup and use it for the label too.

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/widgets/plus_menu_popup.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task E4: Wire the inbound handlers + popup plumbing in the shell

**Files:**
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:mynt_plus/screens/web/chart_engine/state/place_order_prefill.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/qty_selector_popup.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/plus_menu_popup.dart';
```

Also add the navigation import (the existing app's ResponsiveNavigation entry — verify the import path during execution; grep `ResponsiveNavigation` from a known caller like the watchlist screen):

```dart
// e.g.:
import 'package:mynt_plus/routes/responsive_navigation.dart';
```

- [ ] **Step 2: Add popup state + helpers**

Near the existing `_overlayDetailEntry`:

```dart
OverlayEntry? _qtyPopupEntry;
OverlayEntry? _plusMenuEntry;
final Map<String, int> _lastQtyByScrip = {}; // exch|token → last committed qty

void _dismissAllPopups() {
  _dismissOverlayDetail();
  _qtyPopupEntry?.remove(); _qtyPopupEntry = null;
  _plusMenuEntry?.remove(); _plusMenuEntry = null;
}

Offset _iframeToApp(double clientX, double clientY) {
  final el = html.document.getElementById(_iframeId);
  if (el == null) return Offset(clientX, clientY);
  final r = el.getBoundingClientRect();
  return Offset(r.left + clientX + 4, r.top + clientY + 4);
}
```

(Adjust `html.document` import / `_iframeId` to match the existing shell — Phase 3 introduced these.)

Replace `_dismissOverlayDetail()` call in `dispose` with `_dismissAllPopups()`. Likewise in the `ref.listen` for portfolio/order (which currently dismisses the detail popup on any change).

- [ ] **Step 3: Add `_openPlaceOrderScreen` helper**

```dart
Future<void> _openPlaceOrderScreen({
  required ChartScrip scrip,
  required int qty,
  required OrderPrefillKind kind,
  double? price,
}) async {
  final args = buildOrderScreenArgs(
      scrip: scrip, qty: qty, kind: kind, price: price);
  await ResponsiveNavigation.toPlaceOrderScreen(
      context: context, arguments: args);
}
```

(If the `ResponsiveNavigation` method has a different signature in this codebase — e.g. it's a static method on a different class — grep `toPlaceOrderScreen` to find the actual entry point. Match it.)

- [ ] **Step 4: Add the inbound handlers**

In `_onWindowMessage` switch, add the four new cases:

```dart
      case 'bidClicked':
      case 'askClicked': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final price = (v['price'] as num?)?.toDouble();
          if (pid is String && price != null) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final pane = session.panes[idx];
                if (pane.scrip != null) {
                  _openPlaceOrderScreen(
                    scrip: pane.scrip!,
                    qty: pane.qty,
                    kind: msg['type'] == 'bidClicked'
                        ? OrderPrefillKind.sellLimit
                        : OrderPrefillKind.buyLimit,
                    price: price,
                  );
                }
              }
            }
          }
        }
        break;
      }
      case 'qtyChipClicked': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final cx = (v['clientX'] as num?)?.toDouble() ?? 0;
          final cy = (v['clientY'] as num?)?.toDouble() ?? 0;
          if (pid is String) {
            final idx = int.tryParse(pid);
            if (idx != null) _openQtyPopup(idx, cx, cy);
          }
        }
        break;
      }
      case 'plusClicked': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final price = (v['price'] as num?)?.toDouble();
          final cx = (v['clientX'] as num?)?.toDouble() ?? 0;
          final cy = (v['clientY'] as num?)?.toDouble() ?? 0;
          if (pid is String && price != null) {
            final idx = int.tryParse(pid);
            if (idx != null) _openPlusMenu(idx, price, cx, cy);
          }
        }
        break;
      }
```

- [ ] **Step 5: Implement `_openQtyPopup` and `_openPlusMenu`**

Add to the State class:

```dart
void _openQtyPopup(int paneIdx, double cx, double cy) {
  _dismissAllPopups();
  final session = ref.read(chartEngineSessionProvider);
  if (paneIdx < 0 || paneIdx >= session.panes.length) return;
  final pane = session.panes[paneIdx];
  final scrip = pane.scrip;
  if (scrip == null) return;
  final key = '${scrip.exch}|${scrip.token}';
  final anchor = _iframeToApp(cx, cy);

  _qtyPopupEntry = OverlayEntry(
    builder: (_) => QtySelectorPopup(
      anchor: anchor,
      initialQty: pane.qty,
      lotSize: scrip.ls > 0 ? scrip.ls : 1,
      lastUsed: _lastQtyByScrip[key],
      onCommit: (q) {
        ref.read(chartEngineSessionProvider.notifier).setPaneQty(paneIdx, q);
        _lastQtyByScrip[key] = q;
      },
      onDismiss: () { _qtyPopupEntry?.remove(); _qtyPopupEntry = null; },
    ),
  );
  Overlay.of(context).insert(_qtyPopupEntry!);
}

void _openPlusMenu(int paneIdx, double price, double cx, double cy) {
  _dismissAllPopups();
  final session = ref.read(chartEngineSessionProvider);
  if (paneIdx < 0 || paneIdx >= session.panes.length) return;
  final pane = session.panes[paneIdx];
  final scrip = pane.scrip;
  if (scrip == null) return;
  final anchor = _iframeToApp(cx, cy);

  _plusMenuEntry = OverlayEntry(
    builder: (_) => PlusMenuPopup(
      anchor: anchor,
      symbol: scrip.tsym,
      qty: pane.qty,
      price: price,
      onPick: (kind) {
        _plusMenuEntry?.remove(); _plusMenuEntry = null;
        _openPlaceOrderScreen(
          scrip: scrip, qty: pane.qty, kind: kind,
          price: kind == OrderPrefillKind.blank ? null : price,
        );
      },
      onDismiss: () { _plusMenuEntry?.remove(); _plusMenuEntry = null; },
    ),
  );
  Overlay.of(context).insert(_plusMenuEntry!);
}
```

- [ ] **Step 6: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -10`
Expected: `No issues found!`

---

### Smoke checkpoint — Group E

- [ ] Hard-reload. Click the qty chip → qty popup appears under the chip. Type a number, press Enter → chip updates with rounded value. Tap a multiplier → chip updates.
- [ ] Click bid chip → `PlaceOrderScreenWeb` opens pre-filled: SELL, LMT, price = bid, qty = pane qty.
- [ ] Click ask chip → same but BUY.
- [ ] Hover plot → `+` icon in gutter. Click → menu opens. Click "Buy ... limit" → place-order screen opens with BUY/LMT/price prefill.
- [ ] Click "Create new order" → place-order screen opens with symbol+qty pre-filled, no side/price.

---

# Group F — Static gates + Phase 4 smoke

End state: every code path is statically clean; spec §7 smoke list passes.

---

### Task F1: Static gates

- [ ] **Step 1: Flutter analyze**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -10`
Expected: `No issues found!`

- [ ] **Step 2: JS syntax checks**

Run: `node --check web/chart-engine/chart-engine.js web/chart-engine/chart.js web/chart-engine/aggregator.js web/chart-engine/theme.js 2>&1`
Expected: no output.

- [ ] **Step 3: Aggregator tests still green**

Run: `node web/chart-engine/aggregator.test.js 2>&1 | tail -3`
Expected: `15 passed · 0 failed`.

---

### Task F2: Phase 4 manual smoke (spec §7)

Hard-reload and execute the 13-step smoke list in `docs/superpowers/specs/2026-05-22-chart-engine-phase4-design.md`. If everything passes, Phase 4 is done.

---

## Notes for the executing engineer

- **Do not commit at any point.** User commits manually.
- **`PlaceOrderScreenWeb` pre-fill format** — Step E1's Map shape is the best guess from the explore. If the actual `ResponsiveNavigation.toPlaceOrderScreen` expects typed `OrderScreenArgs` / `ScripInfoModel` instances rather than `Map`s, switch E1 to construct those types directly. Grep `toPlaceOrderScreen(` from a known caller (e.g. the watchlist) to see the canonical call shape.
- **`html` import + `_iframeId`** — Phase 3 added the iframe-rect helper using `html.document.getElementById(_iframeId)`. Reuse the exact same pattern for the popup anchoring; don't duplicate.
- **`_dismissAllPopups`** must be called from `dispose` AND from the existing portfolio/order `ref.listen` that already calls `_dismissOverlayDetail`. Replace those calls so all chart popups dismiss together when state changes.
- **Per-scrip last-qty memo** (`_lastQtyByScrip`) is intentionally NOT persisted — it's a session-level memory only.
- **Pause and ask** if:
  - `ResponsiveNavigation.toPlaceOrderScreen` doesn't exist with that name — grep the existing call sites to find the canonical entry point.
  - `OrderScreenArgs` requires fields that aren't obvious from the explore — match the actual class.
  - The `0.05` ti offset in `_openPlusMenu`'s Sell SL-LMT preview label looks wrong for the symbol the user tested with — pass `scrip.ti` into the popup and use it for the label.
