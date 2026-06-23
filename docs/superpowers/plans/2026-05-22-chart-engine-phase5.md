# Chart Engine — Phase 5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make pending order lines (LMT, SL-MKT, SL-LMT trigger, SL-LMT limit) draggable vertically → confirm dialog → `orderProvider.fetchModifyOrder` API call with only the changed price field(s) updated. Position lines remain read-only.

**Architecture:** Drag state lives in `chart.js` per Chart instance. Mousedown on an order-line hit (not chip, not close) enters drag-modify mode, suppressing pan. Mousemove updates the drag (snapped to `scrip.ti`). Mouseup, if the cursor actually moved >2px, posts `overlayDragEnded {paneId, overlayId, newPrice, clientX, clientY}` to Flutter. Flutter shows an iframe-safe confirm dialog, then calls `fetchModifyOrder` with a `ModifyOrderInput` constructed by copying the original order's fields and overriding only `prc` / `trgprc` per the overlay kind. SL-LMT trigger drag also moves the limit by the same delta to preserve offset. No bridge encoders, no store changes.

**Tech Stack:** Flutter (Riverpod 3, pointer_interceptor) + vanilla JS + Canvas 2D.

---

## Project conventions

- **No git commits in plan steps.** User commits manually.
- **Static gates after every code edit:** `flutter analyze lib/screens/web/chart_engine` for Dart; `node --check web/chart-engine/<file>.js` for JS. Don't move on if either reports errors.
- **Manual smoke between groups** — pause and let the user verify.
- **Spec reference:** `docs/superpowers/specs/2026-05-22-chart-engine-phase5-design.md`.
- **Reuse Phase 3/4 patterns:** `_showIframeSafeDialog` (in `overlay_close_dialog.dart`) for the modify confirm dialog; existing `_overlayHitTest` + `_overlayHits` for hit detection; existing `priceToY`/`yToPrice` closures inside `draw()` for snapping math.
- **Chip styling rule** (`[[feedback-chips-solid-colored]]`) still applies if the plan adds any new chip.

## File map

### Modified (Flutter)
| Path | What changes |
|---|---|
| `lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart` | New `showModifyOrderDialog(...)` helper next to the existing two helpers; reuses `_showIframeSafeDialog`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | New `case 'overlayDragEnded'` in `_onWindowMessage`; new private method `_handleOverlayDragEnded(...)` that resolves the order from the id, computes new prc/trgprc per kind, shows the modify dialog. |

### Modified (JS)
| Path | What changes |
|---|---|
| `web/chart-engine/chart.js` | Per-instance `_dragOverlay` state; drag-detection + start in mousedown intercept; window-level mousemove + mouseup handlers that route through drag when active; `_drawOverlays` honours an active drag (renders dragged overlay at live snapped y); Esc-cancel; snap helper. |
| `web/chart-engine/chart-engine.js` | In `applyLayout`'s destroy loop, explicitly null `chart._dragOverlay` for destroyed panes (belt-and-braces). |

No new files. No bridge encoders. No store changes.

---

## Task ordering

1. **Group A — Drag detection + state in chart.js.** Start drag on mousedown on a draggable line. End drag on mouseup; emit message if moved.
2. **Group B — Drag rendering.** `_drawOverlays` uses drag state to render the dragged line at the live snapped y.
3. **Group C — Flutter dialog + API call.** Modify confirm + `fetchModifyOrder` wiring.
4. **Group D — Edge handling + smoke.** Esc cancel, layout-destroy cleanup, smoke.

---

# Group A — Drag detection + state

End state: mousedown on a draggable line enters drag mode (suppresses pan); mousemove tracks the cursor's snapped y; mouseup either emits `overlayDragEnded` (if moved >2px) or falls through to the existing click handler (for the detail popup).

---

### Task A1: Add `_dragOverlay` state + drag start in mousedown intercept

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Initialise state in the constructor**

Find the existing `this._plusHit = null;` line near the other overlay state fields. Add directly AFTER it:

```javascript
    // Drag-to-modify state. Non-null while the user is dragging an order
    // line: { overlayId, originalPrice, lastClientY, hasMoved }
    this._dragOverlay = null;
```

- [ ] **Step 2: Add a snap helper method**

Add directly BELOW `_overlayHitTest`:

```javascript
  _snapPrice(price) {
    const ti = (this.scrip && this.scrip.ti && this.scrip.ti > 0) ? this.scrip.ti : 0.05;
    return Math.round(price / ti) * ti;
  }
```

- [ ] **Step 3: Wire drag-start into the existing mousedown intercept**

Find the existing block in the mousedown handler that branches on `hit.kind === 'overlay'`:

```javascript
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
```

Replace JUST the `if (hit.kind === 'overlay')` body with:

```javascript
        if (hit.kind === 'overlay') {
          // Close-box click — fire the existing close-requested message and
          // we're done.
          if (hit.action === 'close') {
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
                ov && (ov.kind === 'limit' || ov.kind === 'sl' || ov.kind === 'sl-l');
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
```

(The `header`/`plus` branches and everything after the `if (hit)` block stays unchanged.)

- [ ] **Step 4: Add mousemove + mouseup handling for drag**

Find the existing `window.addEventListener('mousemove', (e) => {` in `_attachInteraction`. At the very top of its handler body, add:

```javascript
      // Drag-to-modify takes precedence over normal mousemove (pan / hover).
      if (this._dragOverlay) {
        if (Math.abs(e.clientY - this._dragOverlay.startClientY) > 2) {
          this._dragOverlay.hasMoved = true;
        }
        this._dragOverlay.lastClientY = e.clientY;
        this.scheduleRedraw();
        return;
      }
```

Find the existing `window.addEventListener('mouseup', () => {`. Replace its body with:

```javascript
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
```

- [ ] **Step 5: Add the `_yToPriceForDrag` helper**

Add directly above `_snapPrice`:

```javascript
  // y→price inverse used by drag-modify. Rebuilds the plot rect the same
  // way draw() does so the conversion matches exactly.
  _yToPriceForDrag(y) {
    if (this.candles.length === 0) return null;
    const h = this.canvas.clientHeight;
    const bottomGutter = 24;
    const topPad = 8;
    const innerH = h - topPad - bottomGutter;
    const volH = this.overlays.volume ? Math.round(innerH * 0.22) : 0;
    const candleH = innerH - volH;
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
```

(This duplicates a few lines from `draw()` but keeps the drag math self-contained without restructuring draw().)

- [ ] **Step 6: Add Esc cancellation**

In `_attachInteraction`, after the existing `window.addEventListener('mouseup', ...)`, add:

```javascript
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this._dragOverlay) {
        this._dragOverlay = null;
        this.scheduleRedraw();
      }
    });
```

- [ ] **Step 7: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

# Group B — Drag rendering

End state: while `_dragOverlay` is set, the dragged overlay's line + chip render at the live cursor y (snapped) instead of its stored `ov.price`.

---

### Task B1: Override the dragged overlay's effective price in `_drawOverlays`

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Locate the loop that builds `placements`**

Find the block inside `_drawOverlays`:

```javascript
    // First pass: compute the visible-y for each overlay; either inside the
    // plot, or clamped to a top/bottom caret position.
    const placements = [];
    for (const ov of this._overlays) {
      const onScreen = ov.price >= lo && ov.price <= hi;
      const y = onScreen ? priceToY(ov.price)
          : (ov.price > hi ? plot.top + chipH / 2 : plot.bottom - chipH / 2);
      placements.push({ ov, y, onScreen });
    }
```

Replace with (uses the live-dragged price when an overlay is being dragged):

```javascript
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
```

- [ ] **Step 2: Use `effectivePrice` in the second pass (chip text)**

Find inside the second loop:

```javascript
      const qtyText = this._formatOverlayQty(ov.qty);
      const typeText = this._overlayTypeLabel(ov);
      const pnlText = ov.kind === 'position' ? this._formatOverlayPnl(ov.pnl) : '';
```

The chip text composition doesn't include the price (we drop price into the gutter chip + dot). So nothing to change in the chip. BUT — the gutter price chip's text DOES use `ov.price`. Find `_drawOverlayPriceChips`:

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
```

Replace with (also honour drag):

```javascript
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
```

(The closing logic with `_overlayLineColor(ov)`, `_roundedRect`, `_drawChip` etc. stays unchanged.)

- [ ] **Step 3: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

# Group C — Flutter dialog + API call

End state: `overlayDragEnded` triggers a modify confirm dialog; on confirm, `fetchModifyOrder` fires.

---

### Task C1: Add `showModifyOrderDialog` helper

**Files:**
- Modify: `lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart`

- [ ] **Step 1: Add the modify dialog helper**

Find the existing `showSquareOffDialog(...)` function. Add this NEW helper directly below it (uses the same `_showIframeSafeDialog`):

```dart
Future<void> showModifyOrderDialog({
  required BuildContext context,
  required WidgetRef ref,
  required OrderBookModel order,
  required double newPrice,
  double? newTriggerPrice, // SL-LMT trigger drag also updates limit; pass both
}) async {
  final tsym = order.tsym ?? '';
  final qty = order.qty ?? '';
  final side = order.trantype == 'B' ? 'BUY' : 'SELL';
  final type = order.prctyp ?? '';
  final oldPrice = type == 'SL-MKT'
      ? order.trgprc ?? '0'
      : (type == 'SL-LMT' && newTriggerPrice != null
          ? order.trgprc ?? '0'
          : order.prc ?? '0');
  final bodyText = newTriggerPrice != null
      ? 'Move $side $type $qty $tsym '
          'from $oldPrice to ${newTriggerPrice.toStringAsFixed(2)}? '
          'Limit price will move to ${newPrice.toStringAsFixed(2)} '
          'to preserve offset.'
      : 'Move $side $type $qty $tsym '
          'from $oldPrice to ${newPrice.toStringAsFixed(2)}?';
  return _showIframeSafeDialog<void>(
    context: context,
    child: AlertDialog(
      title: const Text('Modify order'),
      content: Text(bodyText),
      actions: [
        Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Keep'),
        )),
        Builder(builder: (ctx) => FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            final input = ModifyOrderInput(
              exch: order.exch ?? '',
              token: order.token ?? '',
              tsym: order.tsym ?? '',
              orderNum: order.norenordno ?? '',
              qty: order.qty ?? '0',
              dscqty: order.dscqty ?? '0',
              mktProt: order.mktProt ?? '',
              prctyp: order.prctyp ?? '',
              prd: order.prd ?? '',
              trantype: order.trantype ?? '',
              ret: order.ret ?? 'DAY',
              blprc: order.blprc ?? '',
              bpprc: order.bpprc ?? '',
              prc: newPrice.toStringAsFixed(2),
              trgprc: (newTriggerPrice ?? newPrice).toStringAsFixed(2),
            );
            await ref
                .read(orderProvider)
                .fetchModifyOrder(input, context);
          },
          child: const Text('Modify'),
        )),
      ],
    ),
  );
}
```

- [ ] **Step 2: Add missing import for `ModifyOrderInput`**

At the top of the file, add:

```dart
import 'package:mynt_plus/models/order_book_model/modify_order_model.dart';
```

(If the analyzer says it's already imported, skip this step.)

- [ ] **Step 3: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart 2>&1 | tail -8`
Expected: `No issues found!`

If any `OrderBookModel.*` field is missing (e.g., `mktProt`, `ret`, `blprc`, `bpprc`), grep the model file and either use the right field name or fall back to `''`. The plan above assumes those fields exist; the spec already noted they may need to fall back to empty strings.

---

### Task C2: Add `case 'overlayDragEnded'` + `_handleOverlayDragEnded` in the shell

**Files:**
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add the import for `showModifyOrderDialog`**

The existing `import 'package:mynt_plus/screens/web/chart_engine/widgets/overlay_close_dialog.dart';` already pulls in everything from that file. No new import needed.

- [ ] **Step 2: Add the inbound case**

In the existing `_onWindowMessage` switch, add a new case alongside the existing `overlayClicked` / `overlayCloseRequested`:

```dart
      case 'overlayDragEnded': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final ovId = v['overlayId'];
          final newPrice = (v['newPrice'] as num?)?.toDouble();
          if (pid is String && ovId is String && newPrice != null) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              _handleOverlayDragEnded(idx, ovId, newPrice);
            }
          }
        }
        break;
      }
```

- [ ] **Step 3: Add the handler method**

Add to the State class (near `_handleOverlayCloseRequested`):

```dart
void _handleOverlayDragEnded(int paneIndex, String overlayId, double newPrice) {
  final session = ref.read(chartEngineSessionProvider);
  if (paneIndex < 0 || paneIndex >= session.panes.length) return;
  final scrip = session.panes[paneIndex].scrip;
  if (scrip == null) return;

  // Resolve overlayId → underlying OrderBookModel. IDs are prefixed:
  //   ord-<num>   → LMT
  //   sl-<num>    → SL-MKT or SL-LMT (trigger)
  //   sl-l-<num>  → SL-LMT (limit only)
  String? kindPrefix;
  String? orderNum;
  if (overlayId.startsWith('sl-l-')) {
    kindPrefix = 'sl-l';
    orderNum = overlayId.substring('sl-l-'.length);
  } else if (overlayId.startsWith('ord-')) {
    kindPrefix = 'ord';
    orderNum = overlayId.substring('ord-'.length);
  } else if (overlayId.startsWith('sl-')) {
    kindPrefix = 'sl';
    orderNum = overlayId.substring('sl-'.length);
  }
  if (orderNum == null) return;

  final orders = ref.read(orderProvider).orderBookModel ?? const [];
  OrderBookModel? order;
  for (final o in orders) {
    if (o.norenordno == orderNum) { order = o; break; }
  }
  if (order == null) return;

  // For SL-LMT trigger drag, preserve the limit/trigger offset.
  double? newTrigger;
  double finalNewPrice = newPrice;
  if (kindPrefix == 'sl' && (order.prctyp == 'SL-LMT')) {
    final oldTrg = double.tryParse(order.trgprc ?? '0') ?? 0;
    final oldLim = double.tryParse(order.prc ?? '0') ?? 0;
    final offset = oldLim - oldTrg;
    newTrigger = newPrice;
    finalNewPrice = newPrice + offset;
  } else if (kindPrefix == 'sl' && order.prctyp == 'SL-MKT') {
    // SL-MKT: only trgprc changes.
    newTrigger = newPrice;
    // finalNewPrice is unused on the server for SL-MKT but the input still
    // requires `prc`; copy the existing.
    finalNewPrice = double.tryParse(order.prc ?? '0') ?? 0;
  }
  // kindPrefix == 'ord' (LMT) and kindPrefix == 'sl-l' (SL-LMT limit only):
  // only `prc` changes; newTrigger stays null → dialog body shows the
  // simpler "from→to" copy and ModifyOrderInput.trgprc falls back to prc.

  showModifyOrderDialog(
    context: context,
    ref: ref,
    order: order,
    newPrice: finalNewPrice,
    newTriggerPrice: newTrigger,
  );
}
```

- [ ] **Step 4: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -8`
Expected: `No issues found!`

(If `OrderBookModel.mktProt` / `dscqty` / `ret` etc. don't exist as named fields, the analyzer will flag them. Grep the model file and either use the correct name or remove that override — the existing call sites for modify show which fields are always present.)

---

# Group D — Edge handling + smoke

---

### Task D1: Clear drag state on pane destroy in chart-engine.js

**Files:**
- Modify: `web/chart-engine/chart-engine.js`

- [ ] **Step 1: In `applyLayout`'s destroy loop, null `_dragOverlay`**

Find the destroy block in `applyLayout`:

```javascript
  for (const id of Array.from(panes.keys())) {
    if (!desiredIds.has(id)) {
      const chart = panes.get(id);
      try { chart.destroy(); } catch (_) {}
      panes.delete(id);
```

Add `chart._dragOverlay = null;` directly before `chart.destroy()`:

```javascript
  for (const id of Array.from(panes.keys())) {
    if (!desiredIds.has(id)) {
      const chart = panes.get(id);
      chart._dragOverlay = null;
      try { chart.destroy(); } catch (_) {}
      panes.delete(id);
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart-engine.js`
Expected: no output.

---

### Task D2: Final static gates

- [ ] **Step 1: Flutter analyze**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -10`
Expected: `No issues found!`

- [ ] **Step 2: JS syntax**

Run: `node --check web/chart-engine/chart-engine.js web/chart-engine/chart.js web/chart-engine/aggregator.js web/chart-engine/theme.js 2>&1`
Expected: no output.

- [ ] **Step 3: Aggregator tests still pass**

Run: `node web/chart-engine/aggregator.test.js 2>&1 | tail -3`
Expected: `15 passed · 0 failed`.

---

### Task D3: Manual smoke (from spec §7)

Hard-reload and execute the 13-step smoke list in `docs/superpowers/specs/2026-05-22-chart-engine-phase5-design.md`. If everything passes, Phase 5 is done.

---

## Notes for the executing engineer

- **Do not commit.** User commits manually.
- **No bridge encoders, no store changes** — Phase 5 is purely chart.js + shell wiring + a new dialog helper.
- **`_yToPriceForDrag` duplicates a tiny bit of `draw()`'s plot math** — this is intentional to keep the drag self-contained; don't refactor draw().
- **Pause and ask** if:
  - `OrderBookModel` lacks `mktProt` / `ret` / `dscqty` / `blprc` / `bpprc` as fields with those exact names — grep the model and report.
  - `ModifyOrderInput` constructor signature differs from the spec — match the actual class.
  - `fetchModifyOrder`'s context parameter is positional/named differently — call it the way existing callers do (`lib/screens/web/order/modify_place_order_web_screen.dart` is the canonical example).
- **SL-LMT trigger drag** is the trickiest case — verify the offset preservation logic by dragging both ways (up AND down) and confirming the limit follows.
