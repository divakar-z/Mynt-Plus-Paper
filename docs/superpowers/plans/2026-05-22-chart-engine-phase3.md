# Chart Engine — Phase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-pane read-only horizontal lines for open positions, pending LMT orders, and SL trigger orders (with SL-LMT pair), inline label `[qty (pnl) ×]`, right-gutter price chip, click → detail popup, `×` → confirm dialog → cancel/square-off via existing provider methods.

**Architecture:** Flutter shell `ref.listen`s the legacy `portfolioProvider` + `orderProvider` (`ChangeNotifierProvider`s that already self-update via WS OM + LTP — no polling). For each pane it filters by `exch+token`, maps the rows into compact JSON overlays, and pushes diff-cached via a new `setPaneOverlays` postMessage. The iframe's `Chart` class renders lines + dots + labels + gutter chips on canvas (drawn AFTER candles but BEFORE crosshair/OHLC strip), hit-tests on mousemove + mousedown, and posts `overlayClicked` / `overlayCloseRequested` back to Flutter. Flutter shows a detail popup or a confirm dialog over the iframe via `PointerInterceptor`.

**Tech Stack:** Flutter (Riverpod 3 `ref.listen` on legacy providers, dart:html, pointer_interceptor); vanilla JS + Canvas 2D inside the iframe.

---

## Project conventions

- **No git commits in plan steps.** User commits manually after testing the whole phase.
- **Static gates after every code edit:** `flutter analyze lib/screens/web/chart_engine` for Dart; `node --check web/chart-engine/<file>.js` for JS. Don't move on if either reports errors.
- **Manual smoke checkpoints between groups** — pause and let the user verify before continuing.
- **Reference the spec heavily.** `docs/superpowers/specs/2026-05-22-chart-engine-phase3-design.md` is the source of truth for visual style + data model + edge-case behavior. Exact field-string values (`stat=='Ok'`, `prctyp=='LMT'/'SL-LMT'/'SL-MKT'`, `trantype=='B'/'S'`, excluded statuses `REJECTED`/`CANCELED`/`COMPLETE`/`INVALID_STATUS_TYPE`) MUST be used verbatim — they mirror `OrderProvider` lines 1483-1491.

## File map

### Created (Flutter)
| Path | Responsibility |
|---|---|
| `lib/screens/web/chart_engine/widgets/overlay_detail_popup.dart` | Floating Material card showing full details of a clicked overlay (position or order). `PointerInterceptor`-wrapped, dismisses on outside tap. No actions in Phase 3. |
| `lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart` | AlertDialog with Cancel/Confirm buttons; on confirm calls the right provider method (`fetchOrderCancel` for orders, `fetchExitPosition` for positions). |
| `lib/screens/web/chart_engine/state/overlay_payload.dart` | Pure functions that turn `PositionBookModel` / `OrderBookModel` rows into the `Map<String, Object?>` overlays the bridge ships. Unit-testable, no Flutter deps. |

### Modified (Flutter)
| Path | What changes |
|---|---|
| `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart` | Add `encodeSetPaneOverlays(String paneId, List<Map<String,Object?>> overlays)`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | Add `_pushedPaneOverlaysJson` cache; `ref.listen` on portfolio + order providers; per-pane overlay computation + push inside `_pushSession`; inbound `overlayClicked` / `overlayCloseRequested` handlers; popup + dialog plumbing. |

### Modified (JS — `web/chart-engine/`)
| Path | What changes |
|---|---|
| `chart.js` | New `setOverlays(list)` method + `_overlays = []` state; `_overlayHits = []` recomputed each draw; `_drawOverlays(plot, lo, hi, priceToY)`, `_drawOverlayPriceChips(plot, lo, hi, priceToY)`, `_overlayHitTest(x, y)`. Wire hit-test into `mousemove` (cursor) and `mousedown` (post + return). |
| `chart-engine.js` | New `case 'setPaneOverlays':` handler that looks up the pane and calls `chart.setOverlays(value.overlays)`. |

---

## Task ordering (high level)

1. **Group A — Bridge + JS engine plumbing.** New encoder, new JS handler, empty `setOverlays(list)` placeholder. End state: Flutter can post overlays; iframe accepts them (no visible effect yet).
2. **Group B — Render overlays in chart.js.** Lines, dots, inline labels, gutter chips, off-screen carets, overlap stacking. End state: hand-stubbed overlays render correctly (visual-only).
3. **Group C — Hit-test + clicks.** Cursor pointer on hover, mousedown intercept, post `overlayClicked` / `overlayCloseRequested`. End state: clicking a stubbed overlay fires the right outbound message (verify in DevTools).
4. **Group D — Flutter shell wiring.** Filter logic + diff cache + provider listens. End state: REAL overlays show on chart, refresh as orders/positions change.
5. **Group E — Detail popup + close-confirm dialog.** End state: full UX works.
6. **Group F — Final analyze + smoke.**

---

# Group A — Bridge + JS engine plumbing

End state: Flutter side has an encoder for `setPaneOverlays`; iframe accepts the message and stores the list on the pane (but doesn't render anything yet).

---

### Task A1: Add `encodeSetPaneOverlays` to the bridge

**Files:**
- Modify: `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart`

- [ ] **Step 1: Append the new encoder at the bottom of the file**

```dart
String encodeSetPaneOverlays(
    String paneId, List<Map<String, Object?>> overlays) =>
    jsonEncode({
      'type': 'setPaneOverlays',
      'value': {'paneId': paneId, 'overlays': overlays},
    });
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/utils/chart_engine_bridge.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task A2: Add `_overlays` state + `setOverlays(list)` to `Chart` in chart.js

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Initialize state in the constructor**

Find the existing per-pane loading state block (the one added in Phase 2):

```javascript
    // Per-pane loading/error banner — drawn as a centered chip with a
    // semi-transparent dim over the chart, so other panes stay interactive.
    this._loadingTitle = null;
    this._loadingDetail = null;
```

Add directly AFTER it:

```javascript
    // Per-pane overlay state — horizontal lines for positions/orders/SLs.
    // Set via setOverlays(list); rendered in _drawOverlays during draw().
    this._overlays = [];
    this._overlayHits = []; // Recomputed each draw: { rect, action, overlayId }
```

- [ ] **Step 2: Add the `setOverlays` instance method**

Find the existing `setOverlays(flags)` method on the `Chart` class — it currently handles `gridlines`/`volume` overlay flags. **Important:** the existing method is per-pane *overlay flags* (booleans for gridlines/volume); we are NOT replacing it. Add a new SEPARATELY-NAMED method:

```javascript
  setPaneOverlays(list) {
    this._overlays = Array.isArray(list) ? list : [];
    this.scheduleRedraw();
  }
```

Place it directly above the existing `setOverlays(flags)` method.

- [ ] **Step 3: Static check**

Run: `node --check web/chart-engine/chart.js 2>&1`
Expected: no output.

---

### Task A3: Add `setPaneOverlays` case in chart-engine.js

**Files:**
- Modify: `web/chart-engine/chart-engine.js`

- [ ] **Step 1: Add the case to `handleMessage`'s switch**

Find the existing `case 'setOverlays':` block in `handleMessage`. Add this case directly AFTER it:

```javascript
    case 'setPaneOverlays': {
      const { paneId, overlays } = d.value || {};
      if (typeof paneId !== 'string' || !Array.isArray(overlays)) return;
      const chart = panes.get(paneId);
      if (chart) chart.setPaneOverlays(overlays);
      break;
    }
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart-engine.js 2>&1`
Expected: no output.

---

### Smoke checkpoint — Group A

- [ ] No visible UI change. From DevTools console while on `/charts`:
  ```js
  document.querySelector('iframe').contentWindow.postMessage(
      JSON.stringify({type:'setPaneOverlays',value:{paneId:'0',overlays:[{id:'x',kind:'position',side:'buy',qty:5,price:100,pnl:0,pnlPct:0}]}}), '*');
  document.querySelector('iframe').contentWindow.panes.get('0')._overlays.length === 1
  ```
  Should return `true`. Confirms the message round-trips and the chart instance stores the overlay.

---

# Group B — Render overlays in chart.js

End state: when overlays are present, lines + dots + inline labels + right-gutter price chips render correctly. Hit-test rects populated for Group C.

---

### Task B1: Add color/style helpers

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add helpers directly ABOVE the existing `_drawLtpLine` method**

```javascript
  _overlayLineColor(ov) {
    const side = ov.side === 'buy' ? 'long' : 'short';
    if (ov.kind === 'sl' || ov.kind === 'sl-l') return '#EF4444';
    return side === 'long' ? '#3B82F6' : '#EF4444';
  }

  _overlayLabelAccent(ov) {
    // SL gets a 1px amber outline on the chip; everyone else gets none.
    return (ov.kind === 'sl' || ov.kind === 'sl-l') ? '#F59E0B' : null;
  }

  _overlayDash(ov) {
    if (ov.kind === 'position') return [];
    if (ov.kind === 'limit') return [6, 4];
    if (ov.kind === 'sl-l') return [4, 4];
    return [2, 3]; // sl
  }

  _overlayLineWidth(ov) {
    return ov.kind === 'position' ? 1.5 : 1;
  }

  _formatOverlayQty(qty) {
    // Signed integer with sign even for positive (so direction reads from the
    // label even when the colour is overlooked).
    return (qty >= 0 ? '+' : '') + Math.trunc(qty);
  }

  _formatOverlayPnl(pnl) {
    if (pnl == null) return '';
    const sign = pnl >= 0 ? '+' : '−'; // unicode minus
    const abs = Math.abs(pnl);
    if (abs < 1000) return sign + '₹' + abs.toFixed(0);
    if (abs < 100000) return sign + '₹' + (abs / 1000).toFixed(1) + 'k';
    return sign + '₹' + (abs / 100000).toFixed(1) + 'L';
  }
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Task B2: Implement `_drawOverlays`

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add the method directly ABOVE the helpers from B1**

```javascript
  _drawOverlays(plot, lo, hi, priceToY) {
    this._overlayHits = [];
    if (this._overlays.length === 0) return;

    const ctx = this.ctx;
    const dotR = 3;
    const chipH = 18;
    const chipPad = 6;
    const closeBoxW = 14;

    // First pass: compute the visible-y for each overlay; either inside the
    // plot, or clamped to a top/bottom caret position.
    const placements = [];
    for (const ov of this._overlays) {
      const onScreen = ov.price >= lo && ov.price <= hi;
      const y = onScreen ? priceToY(ov.price)
          : (ov.price > hi ? plot.top + chipH / 2 : plot.bottom - chipH / 2);
      placements.push({ ov, y, onScreen });
    }
    // Sort by y so vertical-stack collision logic is deterministic.
    placements.sort((a, b) => a.y - b.y);

    // Resolve label-chip vertical overlaps greedily.
    let prevBottom = -Infinity;
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
      const qtyText = this._formatOverlayQty(ov.qty);
      const pnlText = ov.kind === 'position' ? this._formatOverlayPnl(ov.pnl) : '';
      const segs = [qtyText];
      if (pnlText) segs.push(pnlText);
      const labelText = segs.join('  ');
      const labelW = ctx.measureText(labelText).width;
      const chipW = labelW + chipPad * 2 + closeBoxW;

      const chipLeft = plot.right - chipW - 2;
      const chipTop = chipY - chipH / 2;
      const accent = this._overlayLabelAccent(ov);

      // Chip background.
      ctx.fillStyle = this.palette.crosshairChip;
      this._roundedRect(chipLeft, chipTop, chipW, chipH, 4);
      ctx.fill();
      if (accent) {
        ctx.strokeStyle = accent;
        ctx.lineWidth = 1;
        this._roundedRect(chipLeft, chipTop, chipW, chipH, 4);
        ctx.stroke();
      }

      // Label text.
      ctx.fillStyle = color;
      ctx.textAlign = 'left';
      ctx.fillText(labelText, chipLeft + chipPad, chipY);

      // Close box (× icon) — drawn as two lines.
      const xBoxLeft = chipLeft + chipW - closeBoxW;
      const xCenterX = xBoxLeft + closeBoxW / 2;
      const xSize = 5;
      ctx.strokeStyle = this.palette.axisText;
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.moveTo(xCenterX - xSize / 2, chipY - xSize / 2);
      ctx.lineTo(xCenterX + xSize / 2, chipY + xSize / 2);
      ctx.moveTo(xCenterX + xSize / 2, chipY - xSize / 2);
      ctx.lineTo(xCenterX - xSize / 2, chipY + xSize / 2);
      ctx.stroke();

      // Hit-test rects: open = the whole chip excluding the close box;
      // close = the close box.
      this._overlayHits.push({
        rect: { x: chipLeft, y: chipTop, w: chipW - closeBoxW, h: chipH },
        action: 'open', overlayId: ov.id,
      });
      this._overlayHits.push({
        rect: { x: xBoxLeft, y: chipTop, w: closeBoxW, h: chipH },
        action: 'close', overlayId: ov.id,
      });

      // Also let users click on the line itself (only on-screen, away from chip).
      if (onScreen) {
        this._overlayHits.push({
          rect: { x: plot.left, y: y - 3, w: chipLeft - plot.left, h: 6 },
          action: 'open', overlayId: ov.id,
        });
      }
    }

    ctx.restore();
  }
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Task B3: Implement `_drawOverlayPriceChips` (right-gutter)

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add the method directly BELOW `_drawOverlays`**

```javascript
  _drawOverlayPriceChips(plot, lo, hi, priceToY) {
    if (this._overlays.length === 0) return;
    const ctx = this.ctx;
    ctx.save();
    ctx.font = '700 10px Geist, sans-serif';
    ctx.textBaseline = 'middle';
    for (const ov of this._overlays) {
      if (ov.price < lo || ov.price > hi) continue; // off-screen handled in _drawOverlays
      const y = priceToY(ov.price);
      const text = ov.price.toFixed(2);
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
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Task B4: Wire `_drawOverlays` + `_drawOverlayPriceChips` into `draw()`

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Find the existing draw sequence**

In `draw()`, locate the block:

```javascript
    // LTP marker BEFORE the axis so the right-axis label area gets the
    // coloured chip on top of any overlapping nice-stride label.
    this._drawLtpLine(plot, priceToY, lo, hi);

    // Right axis labels (nice-stride algorithm — mirror orderflow).
    this._drawPriceAxis(plot, lo, hi);
```

- [ ] **Step 2: Insert overlay calls between the LTP line and the right-axis labels**

Change that block to:

```javascript
    // LTP marker BEFORE the axis so the right-axis label area gets the
    // coloured chip on top of any overlapping nice-stride label.
    this._drawLtpLine(plot, priceToY, lo, hi);

    // Overlay lines + inline labels + gutter price chips (positions/orders/SLs).
    this._drawOverlays(plot, lo, hi, priceToY);
    this._drawOverlayPriceChips(plot, lo, hi, priceToY);

    // Right axis labels (nice-stride algorithm — mirror orderflow).
    this._drawPriceAxis(plot, lo, hi);
```

The overlay LINES draw before the axis labels (so axis labels stay on top), but the overlay PRICE CHIPS draw before too — and they're opaque, so they cover the per-tick axis label at the same y (intentional, mirrors LTP chip behavior).

- [ ] **Step 3: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Smoke checkpoint — Group B

- [ ] DevTools console:
  ```js
  const w = document.querySelector('iframe').contentWindow;
  w.postMessage(JSON.stringify({type:'setPaneOverlays', value:{paneId:'0', overlays:[
    {id:'p1', kind:'position', side:'buy',  qty: 20, price: 1356.80, pnl: 220,   pnlPct: 0.81},
    {id:'o1', kind:'limit',    side:'sell', qty: 10, price: 1370.00, pnl: null,  pnlPct: null},
    {id:'s1', kind:'sl',       side:'sell', qty:  5, price: 1340.00, pnl: null,  pnlPct: null},
  ]}}), '*');
  ```
  Should see: blue solid line w/ `+20  +₹220 ×` chip at 1356.80; red dashed line w/ `-10 ×` at 1370; red dotted line w/ amber-outlined chip `+5 ×` at 1340. Each line has a right-gutter price chip matching the line colour.
- [ ] Move mouse over the chip area — visual is correct but cursor doesn't change yet (Group C).

---

# Group C — Hit-test + clicks

End state: hovering a line/label changes the cursor to a pointer; clicking emits the right outbound message to the parent.

---

### Task C1: Cursor pointer on overlay hover

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add the hit-test helper**

Directly BELOW `_drawOverlayPriceChips`:

```javascript
  _overlayHitTest(x, y) {
    for (const h of this._overlayHits) {
      const r = h.rect;
      if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
        return { overlayId: h.overlayId, action: h.action };
      }
    }
    return null;
  }
```

- [ ] **Step 2: Wire into mousemove for cursor**

In `_attachInteraction`, find the existing `window.addEventListener('mousemove', ...)` body — specifically the block that computes `z = this._hitZone(x, y)` and assigns `wrap.style.cursor`. The structure looks like:

```javascript
        if (inside) {
          const z = this._hitZone(x, y);
          wrap.style.cursor = z === 'pan' ? 'crosshair'
            : z === 'zoom-x' ? 'ew-resize' : 'crosshair';
```

Change to check overlays first (overlay hit beats chart-zone cursor):

```javascript
        if (inside) {
          const hit = this._overlayHitTest(x, y);
          if (hit) {
            wrap.style.cursor = 'pointer';
          } else {
            const z = this._hitZone(x, y);
            wrap.style.cursor = z === 'pan' ? 'crosshair'
              : z === 'zoom-x' ? 'ew-resize' : 'crosshair';
          }
```

(The closing braces and the rest of the block stay as-is. Only the cursor-assignment line changes — replace it with the if/else above.)

- [ ] **Step 3: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Task C2: Intercept mousedown to fire `overlayClicked` / `overlayCloseRequested`

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add the intercept at the very top of the existing mousedown handler**

In `_attachInteraction`, find the existing `wrap.addEventListener('mousedown', (e) => { ... });`. The handler currently starts with the `paneActivated` postMessage block we added in Phase 2 Group D. Find this:

```javascript
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
      this._dragMode = this._hitZone(x, y);
```

Modify so that overlay clicks intercept BEFORE the dragMode classification. Insert the overlay hit-test block AFTER the `x`/`y` computation but BEFORE the `_dragMode` assignment:

```javascript
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

      // Overlay click intercept — open detail popup or close-confirm dialog
      // instead of starting a drag.
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

      this._dragMode = this._hitZone(x, y);
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Smoke checkpoint — Group C

- [ ] DevTools console: open the message listener:
  ```js
  window.addEventListener('message', (e) => {
    try { const d = JSON.parse(e.data); if (d.type?.startsWith('overlay')) console.log('GOT', d); } catch (_) {}
  });
  ```
- [ ] Re-run the Group B stub overlay setter. Click the body of a chip (left of the `×`) → `overlayClicked` logged. Click the `×` box → `overlayCloseRequested` logged. Click ON the line away from the chip → `overlayClicked` logged.
- [ ] Hover the chip / line → cursor is a pointer. Hover anywhere else → cursor is the existing crosshair / pan cursor.

---

# Group D — Flutter shell wiring

End state: real overlays appear from the providers; refresh as the underlying lists change; iframe receives them only when the per-pane JSON differs from the last push.

---

### Task D1: Create `overlay_payload.dart` (pure mapping functions)

**Files:**
- Create: `lib/screens/web/chart_engine/state/overlay_payload.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';

/// Open-orders predicate — mirrors `OrderProvider` lines 1483-1491.
bool isOpenOrder(OrderBookModel o) =>
    o.stat == 'Ok' &&
    o.status != 'REJECTED' &&
    o.status != 'CANCELED' &&
    o.status != 'COMPLETE' &&
    o.status != 'INVALID_STATUS_TYPE';

/// Computes the chart-overlay list for a single pane, given its scrip and the
/// current positions + orders. Returns an empty list when scrip is null.
List<Map<String, Object?>> overlaysForPane({
  required ChartScrip? scrip,
  required List<PositionBookModel> positions,
  required List<OrderBookModel> orders,
}) {
  if (scrip == null) return const [];
  final exch = scrip.exch;
  final token = scrip.token;
  final out = <Map<String, Object?>>[];

  for (final p in positions) {
    if (p.exch != exch || p.token != token) continue;
    final qty = int.tryParse(p.netqty ?? '0') ?? 0;
    if (qty == 0) continue;
    final avg = double.tryParse(p.netavgprc ?? '') ?? 0;
    final pnl = double.tryParse(p.mTm ?? '') ?? 0;
    final pnlPct = (avg > 0 && qty != 0) ? (pnl / (avg * qty.abs())) * 100 : 0.0;
    out.add({
      'id': 'pos-$exch-$token',
      'kind': 'position',
      'side': qty > 0 ? 'buy' : 'sell',
      'qty': qty,
      'price': avg,
      'pnl': pnl,
      'pnlPct': pnlPct,
    });
  }

  for (final o in orders) {
    if (o.exch != exch || o.token != token) continue;
    if (!isOpenOrder(o)) continue;
    final id = o.norenordno ?? '';
    final isBuy = o.trantype == 'B';
    final qtyRaw = int.tryParse(o.qty ?? '0') ?? 0;
    final signedQty = isBuy ? qtyRaw : -qtyRaw;
    final prctyp = o.prctyp ?? '';
    if (prctyp == 'LMT') {
      final price = double.tryParse(o.prc ?? '') ?? 0;
      out.add({
        'id': 'ord-$id',
        'kind': 'limit',
        'side': isBuy ? 'buy' : 'sell',
        'qty': signedQty,
        'price': price,
      });
    } else if (prctyp == 'SL-MKT' || prctyp == 'SL-LMT') {
      final trg = double.tryParse(o.trgprc ?? '') ?? 0;
      out.add({
        'id': 'sl-$id',
        'kind': 'sl',
        'side': isBuy ? 'buy' : 'sell',
        'qty': signedQty,
        'price': trg,
      });
      if (prctyp == 'SL-LMT') {
        final lim = double.tryParse(o.prc ?? '') ?? 0;
        out.add({
          'id': 'sl-l-$id',
          'kind': 'sl-l',
          'side': isBuy ? 'buy' : 'sell',
          'qty': signedQty,
          'price': lim,
        });
      }
    }
  }

  return out;
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/state/overlay_payload.dart 2>&1 | tail -5`
Expected: `No issues found!`

(If the import paths for `OrderBookModel` / `PositionBookModel` differ, fix the import path and re-run. The plan-writing exploration confirmed `lib/models/order_book_model/order_book_model.dart` and `lib/models/portfolio_model/position_book_model.dart`.)

---

### Task D2: Wire overlay push + `ref.listen` in the shell

**Files:**
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add imports**

At the top of the file, in the import block, add:

```dart
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/portfolio_provider.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/overlay_payload.dart';
```

- [ ] **Step 2: Add the per-pane diff cache field**

Next to the existing `_pushedSymbolKey` / `_pushedTimeframe` / `_pushedOverlaysJson` maps, add:

```dart
final Map<int, String> _pushedPaneOverlaysJson = {};
```

- [ ] **Step 3: Push overlays inside `_pushSession`**

Inside `_pushSession({bool force = false})`, after the existing per-pane `setOverlays` push block but BEFORE the `setActivePane` push at the end, add:

```dart
    // Per-pane position/order overlays.
    final positions =
        ref.read(portfolioProvider).postionBookModel ?? const [];
    final orders = ref.read(orderProvider).orderBookModel ?? const [];
    for (var i = 0; i < session.panes.length; i++) {
      final pane = session.panes[i];
      final overlays = overlaysForPane(
        scrip: pane.scrip,
        positions: positions,
        orders: orders,
      );
      final json = jsonEncode(overlays);
      if (force || _pushedPaneOverlaysJson[i] != json) {
        _pushedPaneOverlaysJson[i] = json;
        _post(encodeSetPaneOverlays(i.toString(), overlays));
      }
    }
```

- [ ] **Step 4: Clear the overlay cache when layout changes**

In `_pushSession`, locate the existing layout-change branch (the one that clears `_pushedSymbolKey` / `_pushedTimeframe` / `_pushedOverlaysJson`). Add the new map to the clearing:

```dart
    _pushedSymbolKey.clear();
    _pushedTimeframe.clear();
    _pushedOverlaysJson.clear();
    _pushedPaneOverlaysJson.clear(); // <-- add this line
```

- [ ] **Step 5: Add `ref.listen` for portfolio + order providers in `build`**

In the `build(BuildContext context, WidgetRef ref)` method, near the top, add:

```dart
    ref.listen(portfolioProvider, (_, __) {
      if (_iframeReady) _pushSession();
    });
    ref.listen(orderProvider, (_, __) {
      if (_iframeReady) _pushSession();
    });
```

(Place them after any existing `ref.listen`/`ref.watch` calls, but before the return Widget tree.)

- [ ] **Step 6: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -10`
Expected: `No issues found!`

---

### Smoke checkpoint — Group D

- [ ] Open `/charts`. If you have an existing open position in NIFTY (the default symbol), a solid blue or red line should now appear at the average price with `[±qty ±₹pnl ×]`. Right-gutter chip shows the exact avg price in the same colour.
- [ ] Place a LMT order from another tab → switch back to `/charts` → dashed line appears at the order price within ~1s of the OM WS update.
- [ ] Change the pane's symbol to one you have no position/order in → all lines clear.
- [ ] Add a second pane via `cols2` pointing at the same symbol → both panes render the same overlays.

---

# Group E — Detail popup + close-confirm dialog

End state: clicking a line opens a Material card with full details; clicking `×` opens a confirm dialog and on confirm calls the right provider method.

---

### Task E1: Create the detail popup widget

**Files:**
- Create: `lib/screens/web/chart_engine/widgets/overlay_detail_popup.dart`

- [ ] **Step 1: Write the widget**

```dart
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

class OverlayDetailPopup extends StatelessWidget {
  final Offset anchor; // top-left of the card in app coordinates
  final OverlayDetailData data;
  final VoidCallback onDismiss;

  const OverlayDetailPopup({
    super.key,
    required this.anchor,
    required this.data,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final border = resolveThemeColor(context,
        dark: MyntColors.borderDark, light: MyntColors.border);
    final rows = data.rows();

    final screen = MediaQuery.of(context).size;
    const w = 260.0;
    // Clamp to viewport.
    final left = anchor.dx.clamp(8.0, screen.width - w - 8.0);
    final top = anchor.dy.clamp(8.0, screen.height - 220.0);

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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.title(),
                      style: MyntWebTextStyles.caption(context,
                          fontWeight: MyntFonts.semiBold)),
                  const SizedBox(height: 8),
                  for (final r in rows) _row(context, r.$1, r.$2),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: MyntWebTextStyles.caption(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary))),
          ),
          Expanded(
              child: Text(value, style: MyntWebTextStyles.body(context))),
        ],
      ),
    );
  }
}

/// Sealed-ish union of what the popup can display.
abstract class OverlayDetailData {
  String title();
  List<(String, String)> rows();
  factory OverlayDetailData.position(PositionBookModel p) =
      _PositionDetail;
  factory OverlayDetailData.order(OrderBookModel o) = _OrderDetail;
}

class _PositionDetail implements OverlayDetailData {
  final PositionBookModel p;
  _PositionDetail(this.p);
  @override
  String title() => 'Position · ${p.tsym ?? ''}';
  @override
  List<(String, String)> rows() => [
        ('Symbol', p.tsym ?? '—'),
        ('Exchange', p.exch ?? '—'),
        ('Qty (net)', p.netqty ?? '—'),
        ('Avg price', p.netavgprc ?? '—'),
        ('LTP', p.lp ?? '—'),
        ('Product', p.prd ?? '—'),
        ('MTM', p.mTm ?? '—'),
        ('Realised', p.rpnl ?? '—'),
      ];
}

class _OrderDetail implements OverlayDetailData {
  final OrderBookModel o;
  _OrderDetail(this.o);
  @override
  String title() => 'Order · ${o.tsym ?? ''}';
  @override
  List<(String, String)> rows() => [
        ('Symbol', o.tsym ?? '—'),
        ('Exchange', o.exch ?? '—'),
        ('Side', o.trantype == 'B' ? 'BUY' : (o.trantype == 'S' ? 'SELL' : '—')),
        ('Type', o.prctyp ?? '—'),
        ('Product', o.prd ?? '—'),
        ('Qty', o.qty ?? '—'),
        ('Price', o.prc ?? '—'),
        if ((o.trgprc ?? '').isNotEmpty) ('Trigger', o.trgprc!),
        ('Status', o.status ?? '—'),
        ('Order ID', o.norenordno ?? '—'),
      ];
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/widgets/overlay_detail_popup.dart 2>&1 | tail -8`
Expected: `No issues found!`

(If `MyntColors.borderDark` / `MyntColors.border` or `MyntColors.textSecondaryDark` / `MyntColors.textSecondary` don't exist with those exact names, grep the file `lib/res/mynt_web_color_styles.dart` for the closest equivalents and fix. Same for `MyntFonts.semiBold` in `mynt_web_text_styles.dart`.)

---

### Task E2: Create the close-confirm dialog

**Files:**
- Create: `lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart`

- [ ] **Step 1: Write the dialog helper**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';
import 'package:mynt_plus/api/order_input/place_order_input.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/portfolio_provider.dart';

Future<void> showCloseOrderDialog({
  required BuildContext context,
  required WidgetRef ref,
  required OrderBookModel order,
}) async {
  final tsym = order.tsym ?? '';
  final qty = order.qty ?? '';
  final type = order.prctyp ?? '';
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel order'),
      content: Text('Cancel $type order for $qty $tsym?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Keep'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await ref
                .read(orderProvider)
                .fetchOrderCancel(order.norenordno.toString(), context, false);
          },
          child: const Text('Cancel order'),
        ),
      ],
    ),
  );
}

Future<void> showSquareOffDialog({
  required BuildContext context,
  required WidgetRef ref,
  required PositionBookModel position,
}) async {
  final tsym = position.tsym ?? '';
  final qty = position.netqty ?? '';
  final qtyInt = int.tryParse(qty) ?? 0;
  final side = qtyInt < 0 ? 'BUY' : 'SELL';
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Square off position'),
      content: Text('Place a MARKET $side for ${qty.replaceAll('-', '')} $tsym '
          'to close this position?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Keep'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            final input = PlaceOrderInput(
              exch: position.exch ?? '',
              tsym: position.tsym ?? '',
              qty: (position.netqty ?? '0').replaceAll('-', ''),
              prc: '0',
              prctype: 'MKT',
              trantype: qtyInt < 0 ? 'B' : 'S',
              prd: position.prd ?? '',
              ret: 'DAY',
              trgprc: '',
              blprc: '',
              bpprc: '',
              dscqty: '',
              amo: '',
              trailprc: '',
              mktProt: '',
            );
            await ref.read(portfolioProvider).fetchExitPosition(
                context, input, true, false);
          },
          child: const Text('Square off'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart 2>&1 | tail -8`
Expected: `No issues found!`

(If the `PlaceOrderInput` import path is different — grep `lib/api` for the file — fix and re-run. Constructor parameter order/required-ness must match the actual class; if analyzer complains about missing/extra fields, mirror the constructor exactly as it is in `portfolio_provider.dart` lines 1689-1711.)

---

### Task E3: Wire popup + dialog into the shell screen

**Files:**
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:mynt_plus/screens/web/chart_engine/widgets/overlay_detail_popup.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/overlay_close_dialog.dart';
```

- [ ] **Step 2: Add state for the active popup**

Next to the existing state fields in the State class:

```dart
OverlayEntry? _overlayDetailEntry;

void _showOverlayDetail(int paneIndex, String overlayId, double iframeX, double iframeY) {
  _dismissOverlayDetail();
  final session = ref.read(chartEngineSessionProvider);
  if (paneIndex < 0 || paneIndex >= session.panes.length) return;
  final scrip = session.panes[paneIndex].scrip;
  if (scrip == null) return;

  // Resolve overlayId back to a source object.
  OverlayDetailData? data;
  if (overlayId.startsWith('pos-')) {
    final positions = ref.read(portfolioProvider).postionBookModel ?? const [];
    for (final p in positions) {
      if (p.exch == scrip.exch && p.token == scrip.token &&
          (int.tryParse(p.netqty ?? '0') ?? 0) != 0) {
        data = OverlayDetailData.position(p);
        break;
      }
    }
  } else {
    final id = overlayId.replaceFirst(RegExp(r'^(ord|sl-l|sl)-'), '');
    final orders = ref.read(orderProvider).orderBookModel ?? const [];
    for (final o in orders) {
      if (o.norenordno == id) { data = OverlayDetailData.order(o); break; }
    }
  }
  if (data == null) return;

  // Convert iframe-local coords to app coords using the iframe's rect.
  final iframeRect =
      (_iframeKey.currentContext?.findRenderObject() as RenderBox?)
          ?.localToGlobal(Offset.zero);
  final anchor = Offset(
    (iframeRect?.dx ?? 0) + iframeX + 12,
    (iframeRect?.dy ?? 0) + iframeY + 12,
  );

  _overlayDetailEntry = OverlayEntry(
    builder: (_) => OverlayDetailPopup(
      anchor: anchor,
      data: data!,
      onDismiss: _dismissOverlayDetail,
    ),
  );
  Overlay.of(context).insert(_overlayDetailEntry!);
}

void _dismissOverlayDetail() {
  _overlayDetailEntry?.remove();
  _overlayDetailEntry = null;
}

void _handleOverlayCloseRequested(int paneIndex, String overlayId) {
  final session = ref.read(chartEngineSessionProvider);
  if (paneIndex < 0 || paneIndex >= session.panes.length) return;
  final scrip = session.panes[paneIndex].scrip;
  if (scrip == null) return;

  if (overlayId.startsWith('pos-')) {
    final positions = ref.read(portfolioProvider).postionBookModel ?? const [];
    for (final p in positions) {
      if (p.exch == scrip.exch && p.token == scrip.token &&
          (int.tryParse(p.netqty ?? '0') ?? 0) != 0) {
        showSquareOffDialog(context: context, ref: ref, position: p);
        return;
      }
    }
  } else {
    final id = overlayId.replaceFirst(RegExp(r'^(ord|sl-l|sl)-'), '');
    final orders = ref.read(orderProvider).orderBookModel ?? const [];
    for (final o in orders) {
      if (o.norenordno == id) {
        showCloseOrderDialog(context: context, ref: ref, order: o);
        return;
      }
    }
  }
}
```

**Note on `_iframeKey`:** the shell already has a `GlobalKey` for the iframe element (used by Phase 2's click-to-focus). If it isn't a `GlobalKey<State>`-typed key, fall back to `MediaQuery.of(context).size` for anchoring (slightly less precise but works). Grep for `iframeKey` / `htmlElementKey` in the shell first.

- [ ] **Step 3: Handle the new inbound messages**

In the existing `_onWindowMessage` switch (next to the Phase 2 `case 'paneActivated':`), add:

```dart
      case 'overlayClicked': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final ovId = v['overlayId'];
          final cx = (v['clientX'] as num?)?.toDouble() ?? 0;
          final cy = (v['clientY'] as num?)?.toDouble() ?? 0;
          if (pid is String && ovId is String) {
            final idx = int.tryParse(pid);
            if (idx != null) _showOverlayDetail(idx, ovId, cx, cy);
          }
        }
        break;
      }
      case 'overlayCloseRequested': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final ovId = v['overlayId'];
          if (pid is String && ovId is String) {
            final idx = int.tryParse(pid);
            if (idx != null) _handleOverlayCloseRequested(idx, ovId);
          }
        }
        break;
      }
```

- [ ] **Step 4: Dismiss popup on dispose**

In the existing `dispose` method, add at the top:

```dart
    _dismissOverlayDetail();
```

- [ ] **Step 5: Auto-dismiss popup when the underlying overlay disappears**

In the `ref.listen` block we added in D2 for `orderProvider` and `portfolioProvider`, append the dismiss logic so a stale popup pointing at a now-cancelled order self-closes:

```dart
    ref.listen(orderProvider, (_, __) {
      if (_iframeReady) _pushSession();
      _dismissOverlayDetail(); // best-effort: caller can re-open if needed
    });
    ref.listen(portfolioProvider, (_, __) {
      if (_iframeReady) _pushSession();
      _dismissOverlayDetail();
    });
```

(Simpler than tracking which overlay the popup is showing and selectively dismissing — list changes are rare enough that re-clicking is fine.)

- [ ] **Step 6: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -10`
Expected: `No issues found!`

---

### Smoke checkpoint — Group E

- [ ] Click the body of a position chip → detail card pops up next to the click point with `Symbol / Exchange / Qty / Avg / LTP / Product / MTM / Realised`. Click outside → dismisses.
- [ ] Click the `×` on a LMT order chip → confirm dialog `Cancel LMT order for N TSYM?` → Confirm → order cancels, chip disappears within a second (WS OM update).
- [ ] Click the `×` on a position chip → confirm dialog explaining MARKET square-off → Confirm → square-off MARKET order fires, position chip disappears on fill.
- [ ] Click a SL line / chip → detail popup shows the SL order details with `Trigger` row populated.
- [ ] During an active popup, navigate away from `/charts` → popup dismisses cleanly with the screen.

---

# Group F — Final analyze + smoke

End state: every code path is statically clean; the full §7 spec smoke list passes.

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

### Task F2: Phase 3 manual smoke (from spec §7)

Hard-reload the browser tab and execute the 11-step smoke list in `docs/superpowers/specs/2026-05-22-chart-engine-phase3-design.md`. If everything passes, Phase 3 is done.

---

## Notes for the executing engineer

- **Do not commit at any point.** User commits manually after testing.
- **Hard-reload the browser tab** after every JS change.
- **`overlayClicked` and `overlayCloseRequested` are NEW message types** — Phase 2 listeners don't know about them. The shell's switch in `_onWindowMessage` must add cases (Task E3 Step 3). If they're missed, clicking just no-ops with no error.
- **The two providers we `ref.listen` on are `ChangeNotifierProvider`s** (legacy). `ref.listen(portfolioProvider, ...)` works directly because Riverpod 3 supports this for `ChangeNotifierProvider`. The callback receives `(previous, next)` of the `ChangeNotifier` itself; we don't read either — we just re-push.
- **Diff cache is keyed by `int` (pane index)** — same convention as `_pushedSymbolKey` etc. Don't switch to string keys.
- **Pause and ask** if:
  - `PlaceOrderInput`'s constructor signature differs from the snippet in E2 (e.g., extra required params) — match the actual class.
  - `MyntColors`/`MyntFonts`/`MyntWebTextStyles` names differ — grep `lib/res/` for the closest equivalents.
  - The shell's iframe key is not a `GlobalKey<State>` — fall back to viewport-anchored popup placement.
  - `_iframeReady` is the wrong gate name in the shell — grep the existing `_pushSession` calls to confirm the right gate.
