# Chart Engine — Phase 5 Design

**Date:** 2026-05-22
**Builds on:** Phase 4 (interactive trading layer — bid/ask strip, qty selector, `+` menu, PlaceOrderScreen wiring)
**Scope summary:** Drag any pending order line (LMT, SL-MKT, SL-LMT trigger, SL-LMT limit) vertically to a new price → confirm dialog → `fetchModifyOrder` API call. Position avg-price lines stay read-only.

---

## 1. Goal

For order overlays (`kind` ∈ `{limit, sl, sl-l}`), pressing the mouse on the LINE (not the chip, not the close box) and dragging vertically repositions the line in real time. On release, a confirm dialog asks "Move … from X to Y?" — on confirm, the existing `orderProvider.fetchModifyOrder` is called with the only-changed field. On cancel or modify-rejection, the line snaps back (driven by the unchanged provider state, not by iframe rollback).

Position lines (`kind: 'position'`) are NOT draggable — the avg price is derived from past fills, modifying it has no semantic. Mousedown on a position line falls through to the existing pan-mode behaviour.

---

## 2. Visual + interaction spec

### 2.1 Drag lifecycle

| Phase | Cursor | What's drawn |
|---|---|---|
| Hover line | `ns-resize` | Line + chip + gutter price chip — same as Phase 3 |
| mousedown on line | `ns-resize` | Enter drag mode; pan/zoom suppressed |
| drag (mousemove) | `ns-resize` | Line follows cursor y (snapped to `scrip.ti`); chip text shows the NEW price; gutter chip shows the NEW price; original price NOT drawn separately |
| mouseup | `crosshair` (back to normal) | Drag mode released; `overlayDragEnded` posted to Flutter |
| Esc OR right-click during drag | `crosshair` | Cancel — drag mode released; NO message posted |

Drag distinguished from a stationary click: if mouseup occurs without any mousemove since mousedown (or with <2px total movement), treat as a regular click — open the detail popup (existing Phase 3 behaviour). Don't fire `overlayDragEnded` for a no-op click.

### 2.2 Hit-test scope for drag

Only `_overlayHits` entries with `action: 'open'` AND whose overlay kind is `{limit, sl, sl-l}` enter drag mode. The line band (the 6px-tall horizontal hit-test added in Phase 3) is the drag target. The CHIP body and the close `×` are NOT drag targets — they keep their existing click semantics.

### 2.3 Snap to tick

Each cursor y is converted to price via the existing `yToPrice` helper, then snapped:
```js
const snapped = Math.round(price / scrip.ti) * scrip.ti;
```
Then back to y via `priceToY(snapped)` for drawing. The chip displays `snapped.toFixed(2)`.

### 2.4 SL-LMT pair behaviour

| Drag target | Trigger updates | Limit updates |
|---|---|---|
| Trigger line (`id: sl-{ordNum}`) | newTrgPrc | newPrc = newTrgPrc + (oldPrc − oldTrgPrc) [preserves offset and sign] |
| Limit line (`id: sl-l-{ordNum}`) | unchanged | newPrc only |

For non-SL-LMT orders the limit/trigger updates collapse to just the one relevant field.

### 2.5 Cursor + drag-cancellation edges

- Mouse moves outside iframe during drag: window-level `mousemove`/`mouseup` listeners (already in place for pan) keep the drag tracked. Standard browser behaviour.
- Layout change (pane destroyed) during drag: `applyLayout` clears the destroyed pane's `_dragOverlay` state. No message sent.
- Symbol change mid-drag: not possible — symbol-set requires a click that ends the drag first.

---

## 3. Data model + message contract

### 3.1 New outbound message (Flutter → iframe)

None. This phase only consumes existing overlays.

### 3.2 New inbound message (iframe → Flutter)

```js
{
  type: 'overlayDragEnded',
  value: {
    paneId: '0',
    overlayId: 'sl-12345',           // matches the existing overlay id
    newPrice: 1357.20,                // post-snap price
    clientX: 824, clientY: 312,       // for dialog anchoring
  }
}
```

### 3.3 In-iframe state (chart.js)

Per-instance:
```js
this._dragOverlay = null;
// While dragging: { overlayId, action: 'modify', startY, startPrice }
```

When set, `_drawOverlays` overrides the dragged overlay's `price` with the live cursor-derived snapped price and skips the dot/chip drawing for the original position (the chip moves with the line).

### 3.4 ModifyOrderInput construction (Flutter side)

Copy every field from the original `OrderBookModel` verbatim; override only `prc` and/or `trgprc` per §2.4:

```dart
ModifyOrderInput(
  exch: o.exch ?? '',
  token: o.token ?? '',
  tsym: o.tsym ?? '',
  orderNum: o.norenordno ?? '',
  qty: o.qty ?? '0',
  dscqty: o.dscqty ?? '0',
  mktProt: o.mktProt ?? '',
  prctyp: o.prctyp ?? '',
  prd: o.prd ?? '',
  trantype: o.trantype ?? '',
  ret: o.ret ?? 'DAY',
  blprc: o.blprc ?? '',
  bpprc: o.bpprc ?? '',
  // The only two that change:
  prc:    newPrc.toStringAsFixed(2),
  trgprc: newTrgprc.toStringAsFixed(2),
)
```

If the original `OrderBookModel` doesn't expose some of those fields (`mktProt`, `dscqty`, `blprc`, `bpprc`, `ret`), fall back to empty strings — the modify endpoint accepts them.

---

## 4. Confirm dialog

Reuses the `_showIframeSafeDialog` helper from Phase 3's `overlay_close_dialog.dart`. Add a third helper:

```
Title:   Modify order
Body:    Move <BUY|SELL> <LMT|SL-MKT|SL-LMT> <qty> <tsym>
         from <oldPrice> to <newPrice>?

         <ONLY for SL-LMT trigger drag>:
         Limit price will move to <newLimit> to preserve offset.

Actions: [Keep] [Modify]
```

Confirm → `ref.read(orderProvider).fetchModifyOrder(input, context)` (provider handles its own toast + order-book refresh). Cancel → dismiss. No further action needed: the unchanged provider state means the chart re-renders the line at its original price.

---

## 5. Edge cases

| Case | Behaviour |
|---|---|
| User mousedowns on a line but releases without moving | Treated as a click → existing detail popup (Phase 3) |
| User drags below `lo` / above `hi` | Cursor follows; price computed for off-screen y; chip + ghost line still drawn at the cursor's clamped y |
| Modify API rejects | Provider's existing error toast surfaces; the chart line snaps back because provider state didn't change |
| Order completes / cancels mid-drag | The provider list update flows through `ref.listen`, `_pushSession` pushes new overlays without this order → iframe's next `setPaneOverlays` removes it. Live drag aborts on the next iframe redraw (drag state references an id that no longer exists). |
| Layout change mid-drag (rare — requires clicking layout picker which dismisses popups but doesn't fire mouseup on canvas) | `applyLayout`'s destroy loop also nukes drag state on destroyed panes |
| Drag on a position line | Falls through to existing pan behaviour (no drag-modify) |
| User drags the close `×` box | Existing close-confirm dialog fires; not a drag |
| Two overlays at identical prices | Both have the SAME y; first hit in `_overlayHits` wins — close-action sub-rect priority handles which one |
| SL-LMT trigger dragged above its limit (inverts the order) | The exchange's validation rejects on submit; we display the error toast. We do NOT pre-validate — exchange rules vary. |
| Drag handle clicked on a row where the `+` icon is also visible | `+` icon is already hidden on overlay rows (Phase 4 fix); no conflict |
| User holds mouse but moves <2px before releasing | Treated as click (detail popup) — threshold check in mouseup |

---

## 6. Files to create / modify

### Modified (Flutter)
| Path | What changes |
|---|---|
| `lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart` | Add `showModifyOrderDialog(...)` helper using existing `_showIframeSafeDialog`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | New `case 'overlayDragEnded'` → look up order from id → compute new prc/trgprc per kind → show modify dialog → on confirm call `fetchModifyOrder`. |

### Modified (JS)
| Path | What changes |
|---|---|
| `web/chart-engine/chart.js` | Per-instance `_dragOverlay` state; mousedown detects line-hit on draggable overlay and starts drag (preempts pan); mousemove updates drag; mouseup emits `overlayDragEnded` (or detail-popup click if no movement); `_drawOverlays` honours drag (renders the dragged line at the live snapped y); Esc handler cancels. |

### Modified (also potentially)
| Path | What changes |
|---|---|
| `web/chart-engine/chart-engine.js` | `applyLayout` already clears destroyed panes; add explicit `chart._dragOverlay = null` when destroying to be safe. |

No new files. No bridge encoders (only one new inbound message type, no outbound). No spec changes to other phases.

---

## 7. Acceptance smoke

1. Open `/charts` on a symbol with at least one open pending LMT order.
2. Hover over the LMT order's line (not the chip) → cursor turns into `ns-resize`.
3. Mousedown + drag the line up by ~30px → line follows cursor; chip + gutter chip show the NEW (snapped) price as you move.
4. Release → confirm dialog appears at the release point: `Move BUY LMT 5 RELIANCE-EQ from 1300.00 to 1305.00?` Click `Modify` → toast confirms; within ~1s, the line settles at the new price (re-pushed from the provider).
5. Same as above but click `Keep` → line snaps back to the original price.
6. Click on the line (no drag) → detail popup opens (existing Phase 3 behaviour).
7. Click the chip body → detail popup. Click the close `×` → close-confirm dialog. Both still work, unaffected.
8. With an SL-LMT order: drag the trigger line → both lines move together preserving offset. Confirm → both fields update via one API call. Reload → both lines at new positions.
9. Drag the SL-LMT limit line alone → only that line moves. Confirm → only `prc` updates.
10. Place a deliberately-bad modify (e.g., drag a sell LMT below the current market) → API rejects → existing error toast shows → line snaps back.
11. Two panes, same symbol, same order → drag the line in pane 0 → both panes' lines update after the provider push.
12. Try to drag a position line → no drag mode; instead the chart pans (existing behaviour).
13. During an active drag, press Esc → drag cancels with no API call.

If everything passes, Phase 5 is done.

---

## 8. Out of scope (Phase 6+)

- `+ TP` / `+ SL` from-position quick buttons (Phase 6).
- Drag chip body or close box for drag (only the line is the handle).
- Drag a position line (read-only; semantic mismatch).
- Drag-to-modify qty (vertical drag = price; qty stays).
- Instant-mode skip-confirm (separate small phase per `[[project-chart-instant-orders]]`).
- Multi-leg bracket-order sibling auto-updates.
- Drag preview ghost showing both old AND new line simultaneously.
- Snap to LTP / position avg / nearest order line.
- Mobile/touch drag gestures.
