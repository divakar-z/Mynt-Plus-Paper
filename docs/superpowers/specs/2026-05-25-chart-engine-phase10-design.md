# Chart Engine — Phase 10 Design

**Date:** 2026-05-25
**Builds on:** Phases 1-9 (drawings exist as HLine + Trendline; Phase 9 TP/SL temporarily removed).
**Scope summary:** Three drawing polish features — (1) **drag-to-move** an existing drawing to a new position, (2) **rectangle** as a 3rd drawing kind, (3) **per-drawing color picker** that appears when a drawing is selected.

---

## 1. Goal

For the existing per-scrip drawings system (Phase 7), add:

- **Drag-to-move:** clicking on an existing drawing's line (not the delete `×`) selects it; dragging translates the whole drawing (HLine y, Trendline both points, Rectangle both corners). On release, the new points are persisted via a new `drawingMoved` outbound message.
- **Rectangle drawing kind:** added to the Draw menu. 2-click placement (1st = top-left corner, 2nd = bottom-right corner). Rendered as a 4-line stroked rectangle. Same delete-chip + drag-to-move behaviour as the other kinds.
- **Per-drawing color picker:** when a drawing is selected, a small horizontal swatch palette appears next to the delete `×` chip with 8 preset colors. Click a color → updates the drawing's `color` field, persisted via a new `drawingColorChanged` outbound message.

Selection is implicit on mousedown-without-drag, OR after a drag completes. Click on empty chart area / different drawing → deselect / re-select.

---

## 2. Visual + interaction

### 2.1 Selection state

- `_selectedDrawingId: string | null` per Chart instance.
- A drawing is selected when its delete chip + color palette are visible.
- Selection set by:
  - Mousedown on a drawing's line (the hit-band, NOT the delete `×`).
  - Successful drag completion (selected drawing stays selected after release).
- Cleared by:
  - Mousedown on empty plot area (not on any drawing).
  - Esc.
  - Layout change / pane destroy.

### 2.2 Selected drawing visual

- Line drawn 1.5px (vs 1px for unselected — already the case for HLine line width 1.5; bump trendline + rectangle to 1.5 when selected).
- Small **selection halo** under the line: 4px white halo (already added in Phase 7 for trendline; extend to all kinds).
- Delete chip always visible on selected (regardless of hover).

### 2.3 Drag

- On mousedown over a drawing's hit-band: record `_dragDrawingId`, `_dragDrawingStartPoints` (snapshot of current points), `_dragStartClientY` / `_dragStartClientX` (where the cursor was when drag started).
- mousemove with `_dragDrawingId` set: compute delta from start, translate all points by that delta (price-space delta for y, ts-space delta for x). Update local `_drawings` entry. scheduleRedraw.
- mouseup: if delta exceeded 2px threshold, post `drawingMoved` to Flutter with the new `points` array. Else treat as a click → toggle selection / open detail (no detail popup in Phase 10; just select). Clear `_dragDrawingId`.

### 2.4 Color picker

- Renders a small horizontal palette strip RIGHT NEXT TO the delete `×` chip when the drawing is selected.
- Strip contains 8 color swatches (each 14×14px) with 2px gap.
- Colors: blue `#3B82F6`, red `#EF4444`, green `#10B981`, amber `#F59E0B`, violet `#8B5CF6`, pink `#EC4899`, cyan `#06B6D4`, white `#FFFFFF`.
- Click a swatch → post `drawingColorChanged` to Flutter with `{paneId, drawingId, color}`.
- Currently-selected color has a thin white outline so it stands out.

### 2.5 Rectangle tool

- Added to the Draw menu (`Horizontal line`, `Trendline`, `Rectangle`).
- 2-click placement (same UX as Trendline):
  1. First click → start point recorded; tentative dashed rectangle follows cursor from start to live cursor.
  2. Second click → end point recorded; rectangle committed.
- Renderer: 4-line stroked rectangle from p1 to p2 (no fill, just outline). 1px or 1.5px line.

Esc cancels mid-placement.

---

## 3. Data model

### 3.1 Drawing kind `'rect'`

`ChartDrawing.kind` gains the value `'rect'`. `points` is 2 entries (the two corners). All existing storage/persistence paths handle this automatically.

### 3.2 New outbound bridge messages (iframe → Flutter)

```js
// User finished moving a drawing.
{ type: 'drawingMoved', value: { paneId, drawingId, points: [{price,ts},...] } }

// User picked a new color for the selected drawing.
{ type: 'drawingColorChanged', value: { paneId, drawingId, color: '#XXXXXX' } }
```

### 3.3 Notifier method (NEW)

```dart
void updateDrawing(String scripKey, String drawingId, {
  List<DrawingPoint>? points,
  String? color,
});
```

Persists via `_schedulePersist()` same as `addDrawing` / `removeDrawing`.

### 3.4 No persistence model changes

`ChartDrawing` already has `color` (string) and `points` (list). The notifier method just replaces these fields on the matching drawing.

---

## 4. Architecture

### 4.1 chart.js

New per-instance state:

```js
this._selectedDrawingId = null;
this._dragDrawingId = null;
this._dragDrawingStartPoints = null;
this._dragStartClientX = 0;
this._dragStartClientY = 0;
this._dragDrawingMoved = false;
this._dragDrawingStartPriceY = null;  // for converting cursor y delta → price delta
this._colorSwatchHits = [];  // [{ rect, color, drawingId }]
```

New / extended renderers:

- `_drawDrawings` extended:
  - Renders rectangle kind (4 lines).
  - Renders selected drawing with thicker line.
  - Renders color swatch palette next to delete chip when selected.
  - Registers `_drawingHits` for line-band hit (action `drag`) and delete (action `delete`).
  - Registers `_colorSwatchHits` for each swatch.

- Mousedown intercept: extended to handle drawing-line hits → enter drag mode. Color swatch hit → post `drawingColorChanged`. (Delete chip hit handling unchanged.)

- Mousemove: while `_dragDrawingId` set, translate the drawing's points locally and scheduleRedraw.

- Mouseup: if drag moved >2px, post `drawingMoved` with new points. If not, treat as click → toggle selection.

- Keydown Esc: clear `_selectedDrawingId` + cancel drag.

### 4.2 chart-engine.js

No new handlers — the new outbound messages don't pass through `handleMessage`.

### 4.3 Flutter shell

New inbound cases:

```dart
case 'drawingMoved': {
  // Resolve paneIdx → scrip → scripKey, then call updateDrawing(...).
}
case 'drawingColorChanged': {
  // Same, with color.
}
```

### 4.4 Top bar

Draw popup menu adds a third item:

```
— Horizontal line
╱ Trendline
□ Rectangle      // NEW
```

---

## 5. Edge cases

| Case | Behaviour |
|---|---|
| Drag a HLine | Translates only the y (ts is fixed at 0 / irrelevant) |
| Drag a Trendline | Translates both endpoints by the same delta (parallel translation) |
| Drag a Rectangle | Translates both corners |
| Drag exits the plot area | Allowed; the drawing follows the cursor; on release, persisted at the new (possibly off-screen) coords |
| Delete chip clicked while drawing is selected | Drawing removed; selection cleared |
| Selection persists across redraws | Yes (re-rendered with selected styling each draw) |
| Symbol change while selection active | Selection cleared (drawings list replaced via setDrawings) |
| Layout change while drag in progress | Drag state cleared; selection cleared |
| Two drawings overlapping at same y | Click hits the topmost (last in array — most recent) |
| Color picker click outside the strip | Doesn't affect selection (handled by hit-test priority) |

---

## 6. Files to create / modify

### Modified (Flutter)
| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | Notifier method `updateDrawing(scripKey, drawingId, {points, color})`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | Inbound cases `drawingMoved` + `drawingColorChanged`. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | Add `Rectangle` item to Draw menu popup. |

### Modified (JS)
| Path | What |
|---|---|
| `web/chart-engine/chart.js` | Selection state; rect kind in renderer; drag handling; color swatch palette; mousedown / mousemove / mouseup intercepts; keydown Esc extended. |

No new files. No bridge encoders (only new inbound messages).

---

## 7. Acceptance smoke

1. Open `/charts`. Draw an HLine. Click on the line → selection halo + color swatches appear next to the × chip. Click empty area → deselect.
2. Click + drag the HLine up by 30px → on release, line settles at new price. Reload → persisted.
3. Click Trendline tool, place a trendline. Click + drag the middle of it → both endpoints move together.
4. Click Rectangle in Draw menu → click 2 corners → rectangle drawn.
5. Click + drag the rectangle → moves with cursor.
6. Click a drawing → color swatches appear. Click violet swatch → drawing turns violet. Reload → persisted.
7. Esc while a drawing is selected → deselected (halo + swatches gone).
8. Esc during in-progress rectangle placement → cancels.
9. Multi-pane with same symbol → drawings update everywhere.

---

## 8. Out of scope (Phase 10.1+)

- Fibonacci retracement, Ray, Trend channel, Ellipse, Text annotations
- Resize handles (drag individual endpoints, not just translate)
- Lock / unlock drawings
- Snap-to-candle-high/low while drawing or dragging
- Custom color picker (only the 8 presets in Phase 10)
- Drawing templates / favorites
- Copy-to-other-symbol
