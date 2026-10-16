# Chart Engine — Phase 10 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Three drawing-polish features: (1) drag-to-move existing drawings, (2) Rectangle drawing kind, (3) per-drawing color picker (8 preset swatches).

**Architecture:** Selection + drag-translate live in `chart.js`. Two new outbound messages — `drawingMoved` and `drawingColorChanged` — route through the existing `_onWindowMessage` switch in the shell, calling a new `updateDrawing(scripKey, id, {...})` notifier method. Rectangle is a new `kind: 'rect'` with 2-point geometry. Color swatch palette renders next to the delete chip when a drawing is selected; click → post change.

## Project conventions

- **No git commits.**
- **Static gates after every edit:** `flutter analyze lib/screens/web/chart_engine` + `node --check web/chart-engine/chart.js`.
- **Spec reference:** `docs/superpowers/specs/2026-05-25-chart-engine-phase10-design.md`.
- **Reuse:** existing `_drawings` / `_drawingHits` arrays; existing `_yToPriceForDrag` / `_xToTs` / `_tsToX` helpers; existing `addDrawing` / `removeDrawing` notifier pattern.

## File map

### Modified (Flutter)
| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | `updateDrawing(scripKey, id, {points, color})` notifier method. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | Inbound cases `drawingMoved` + `drawingColorChanged`. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | Add `Rectangle` row to Draw menu popup. |

### Modified (JS)
| Path | What |
|---|---|
| `web/chart-engine/chart.js` | Selection state; rect kind in `_drawDrawings` renderer; drag handling in mousedown/mousemove/mouseup; color swatch palette + hit-test; rect placement in mousedown draw-mode block; Esc handling extended. |

No new files. No `chart-engine.js` changes (no new inbound messages).

## Task ordering

1. **Group A — Notifier + shell + bridge plumbing.**
2. **Group B — Rectangle kind + Draw menu.**
3. **Group C — Selection + drag-to-move.**
4. **Group D — Color swatch palette.**
5. **Group E — Static gates + smoke.**

---

# Group A — Notifier + shell handlers

### Task A1: `updateDrawing` notifier method

**Files:** `lib/screens/web/chart_engine/state/chart_engine_store.dart`

Inside `ChartEngineSessionNotifier`, near `addDrawing` / `removeDrawing`:

```dart
void updateDrawing(String scripKey, String drawingId, {
  List<DrawingPoint>? points,
  String? color,
}) {
  final next = Map<String, List<ChartDrawing>>.from(state.drawings);
  final list = List<ChartDrawing>.from(next[scripKey] ?? const []);
  final idx = list.indexWhere((d) => d.id == drawingId);
  if (idx < 0) return;
  final old = list[idx];
  list[idx] = ChartDrawing(
    id: old.id,
    kind: old.kind,
    color: color ?? old.color,
    points: points ?? old.points,
  );
  next[scripKey] = list;
  state = state.copyWith(drawings: next);
  _schedulePersist();
}
```

Static check: `flutter analyze lib/screens/web/chart_engine/state/chart_engine_store.dart`.

---

### Task A2: Inbound handlers in shell

**Files:** `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

In `_onWindowMessage` switch, alongside the existing `drawingCommitted` / `drawingDeleted` cases:

```dart
      case 'drawingMoved': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final did = v['drawingId'];
          final pts = v['points'];
          if (pid is String && did is String && pts is List) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final scrip = session.panes[idx].scrip;
                if (scrip != null) {
                  final parsed = <DrawingPoint>[
                    for (final p in pts)
                      if (p is Map)
                        DrawingPoint.fromJson(Map<String, dynamic>.from(p)),
                  ];
                  ref
                      .read(chartEngineSessionProvider.notifier)
                      .updateDrawing(
                          '${scrip.exch}|${scrip.token}', did, points: parsed);
                }
              }
            }
          }
        }
        break;
      }
      case 'drawingColorChanged': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final did = v['drawingId'];
          final color = v['color'];
          if (pid is String && did is String && color is String) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final scrip = session.panes[idx].scrip;
                if (scrip != null) {
                  ref
                      .read(chartEngineSessionProvider.notifier)
                      .updateDrawing(
                          '${scrip.exch}|${scrip.token}', did, color: color);
                }
              }
            }
          }
        }
        break;
      }
```

Static check: `flutter analyze lib/screens/web/chart_engine`.

---

# Group B — Rectangle kind + Draw menu

### Task B1: Add Rectangle to Draw menu

**Files:** `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`

Find the Draw popup menu in `_DrawButtonState._buildMenu()` — it currently has two `InkWell` rows for `Horizontal line` and `Trendline`. Add a third:

```dart
InkWell(
  onTap: () => _pick('rect'),
  child: const Padding(
    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(children: [
      Icon(Icons.crop_square, size: 16),
      SizedBox(width: 10),
      Text('Rectangle'),
    ]),
  ),
),
```

Also update the label switch (`active == 'hline' ? 'Drawing: HLine' : 'Drawing: Trendline'`):

```dart
final label = active == null ? 'Draw'
    : active == 'hline' ? 'Drawing: HLine'
    : active == 'rect'  ? 'Drawing: Rectangle'
    : 'Drawing: Trendline';
```

Static check.

---

### Task B2: Rectangle in chart.js — placement + render

**Files:** `web/chart-engine/chart.js`

- [ ] **Step 1: Rectangle placement in mousedown draw-mode**

Find the existing draw-mode mousedown intercept that handles `hline` and `trendline`. Add a third kind handler for `rect`. Behaviour is identical to trendline (two-click) but committed kind is `'rect'`:

```javascript
        if (this._drawMode === 'rect') {
          if (!this._inProgressDrawing) {
            this._inProgressDrawing = {
              kind: 'rect',
              color: '#3B82F6',
              points: [{ price, ts }],
            };
            this.scheduleRedraw();
            return;
          }
          const drawing = {
            id: 'd-' + Date.now().toString(36) + '-' +
                Math.random().toString(36).slice(2, 8),
            kind: 'rect',
            color: '#3B82F6',
            points: [
              this._inProgressDrawing.points[0],
              { price, ts },
            ],
          };
          try {
            parent.postMessage(JSON.stringify({
              type: 'drawingCommitted',
              value: { paneId: this.paneId, drawing },
            }), '*');
          } catch (_) {}
          this._drawMode = null;
          this._inProgressDrawing = null;
          this.scheduleRedraw();
          return;
        }
```

Insert this branch BEFORE the existing trendline default-path (so HLine/Rect/Trendline all branch correctly).

- [ ] **Step 2: Rectangle in `_drawDrawings` renderer**

Find the `renderOne` inner function in `_drawDrawings`. It currently has branches for `'hline'` and `'trendline'`. Add a third for `'rect'`:

```javascript
      } else if (d.kind === 'rect') {
        const p1 = d.points[0];
        const p2 = d.points[1];
        if (!p1) { ctx.restore(); return; }
        const x1 = this._tsToX(p1.ts, plot);
        const y1 = priceToY(p1.price);
        let x2, y2;
        if (p2) {
          x2 = this._tsToX(p2.ts, plot);
          y2 = priceToY(p2.price);
        } else if (this.hover.inside && this.hover.x != null) {
          x2 = this.hover.x;
          y2 = this.hover.y;
        } else {
          ctx.restore();
          return;
        }
        endX = Math.max(x1, x2);
        endY = (y1 + y2) / 2;
        // 4-line stroked rectangle.
        if (Number.isFinite(x1) && Number.isFinite(y1) &&
            Number.isFinite(x2) && Number.isFinite(y2)) {
          // White halo
          ctx.strokeStyle = 'rgba(255,255,255,0.85)';
          ctx.lineWidth = 4;
          ctx.strokeRect(Math.min(x1, x2), Math.min(y1, y2),
              Math.abs(x2 - x1), Math.abs(y2 - y1));
          // Colored stroke
          ctx.strokeStyle = color;
          ctx.lineWidth = 2;
          ctx.strokeRect(Math.min(x1, x2), Math.min(y1, y2),
              Math.abs(x2 - x1), Math.abs(y2 - y1));
        }
      }
```

(Reuse the existing `drawLine` halo-pattern style for consistency with trendlines.)

Static check: `node --check web/chart-engine/chart.js`.

---

# Group C — Selection + drag-to-move

### Task C1: Selection state + drag tracking in chart.js

**Files:** `web/chart-engine/chart.js`

- [ ] **Step 1: Add state fields**

In the constructor, near `_drawings`:

```javascript
    this._selectedDrawingId = null;
    this._dragDrawingId = null;
    this._dragDrawingStartPoints = null;
    this._dragStartClientX = 0;
    this._dragStartClientY = 0;
    this._dragDrawingMoved = false;
    this._colorSwatchHits = []; // [{ rect, color, drawingId }]
```

- [ ] **Step 2: Register line-band hit (drag target) in `_drawDrawings`**

After computing line geometry per drawing (HLine y, trendline x1/y1/x2/y2, rect corners), register a hit-band entry. Currently `_drawingHits` only has delete-chip entries. Add line hits with action `'drag'`:

For HLine:
```javascript
this._drawingHits.push({
  rect: { x: plot.left, y: endY - 4, w: plot.right - plot.left, h: 8 },
  drawingId: d.id, action: 'drag', kind: 'hline',
});
```

For Trendline (band along the line — approximate as a wider rect spanning the bounding box for simplicity):
```javascript
const minX = Math.min(x1, x2), maxX = Math.max(x1, x2);
const minY = Math.min(y1, y2), maxY = Math.max(y1, y2);
this._drawingHits.push({
  rect: { x: minX, y: minY - 4, w: maxX - minX, h: (maxY - minY) + 8 },
  drawingId: d.id, action: 'drag', kind: 'trendline',
});
```

For Rectangle (border-only — registering the full bbox is acceptable; user can click anywhere inside to drag):
```javascript
this._drawingHits.push({
  rect: { x: Math.min(x1, x2), y: Math.min(y1, y2),
          w: Math.abs(x2 - x1), h: Math.abs(y2 - y1) },
  drawingId: d.id, action: 'drag', kind: 'rect',
});
```

Insert these registrations AFTER the line/dot/halo render but BEFORE the delete-chip render.

- [ ] **Step 3: Selected drawing visual treatment**

In the renderer, when `d.id === this._selectedDrawingId`, draw a slightly thicker line (lineWidth +0.5) and make sure the delete chip is always visible (currently always visible per Phase 7 — no change). For trendline / rect, the halo already provides visual distinction.

- [ ] **Step 4: Mousedown handling — drag start, selection**

Find the existing mousedown intercept block. Currently it has a section for drawing delete-chip hits (action `'delete'`). Right BEFORE that section, add a check for color swatch hits (Group D will populate `_colorSwatchHits`):

```javascript
      // --- Phase 10: color swatch click (selected-drawing palette) ---
      for (const h of this._colorSwatchHits) {
        const r = h.rect;
        if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
          e.preventDefault(); e.stopPropagation();
          try {
            parent.postMessage(JSON.stringify({
              type: 'drawingColorChanged',
              value: { paneId: this.paneId,
                       drawingId: h.drawingId, color: h.color },
            }), '*');
          } catch (_) {}
          return;
        }
      }
```

After the delete-chip block, add a check for drag-band hits:

```javascript
      // --- Phase 10: drawing line-band hit → start drag-to-move ---
      for (const h of this._drawingHits) {
        if (h.action !== 'drag') continue;
        const r = h.rect;
        if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
          e.preventDefault(); e.stopPropagation();
          this._selectedDrawingId = h.drawingId;
          this._dragDrawingId = h.drawingId;
          const d = this._drawings.find((dd) => dd.id === h.drawingId);
          this._dragDrawingStartPoints = d
              ? d.points.map((p) => ({ price: p.price, ts: p.ts }))
              : null;
          this._dragStartClientX = e.clientX;
          this._dragStartClientY = e.clientY;
          this._dragDrawingMoved = false;
          this.scheduleRedraw();
          return;
        }
      }
      // Mousedown on empty plot area → deselect.
      if (!this._dragMode && !this._inProgressDrawing) {
        if (this._selectedDrawingId) {
          this._selectedDrawingId = null;
          this.scheduleRedraw();
        }
      }
```

- [ ] **Step 5: Mousemove — translate during drag**

In the existing `mousemove` window listener, near the top (before existing pan logic), add:

```javascript
      if (this._dragDrawingId && this._dragDrawingStartPoints) {
        const dxPx = e.clientX - this._dragStartClientX;
        const dyPx = e.clientY - this._dragStartClientY;
        if (Math.abs(dxPx) > 2 || Math.abs(dyPx) > 2) this._dragDrawingMoved = true;
        // Convert pixel deltas to price + ts deltas.
        // For ts: use cellW (px per bar) and timeframeMinutes*60 (sec per bar).
        const rect = wrap.getBoundingClientRect();
        const lp = this.candles.length ? this.candles[0] : null;
        if (lp) {
          // Price delta: invert priceToY around any anchor — use existing
          // _yToPriceForDrag at two points (the start and current y in
          // local coords) and subtract.
          const startLocalY = this._dragStartClientY - rect.top;
          const curLocalY = e.clientY - rect.top;
          const startPrice = this._yToPriceForDrag(startLocalY);
          const curPrice = this._yToPriceForDrag(curLocalY);
          const dPrice = (curPrice != null && startPrice != null)
              ? (curPrice - startPrice) : 0;
          const dtSec = this.timeframeMinutes * 60;
          const dTs = Math.round((dxPx / this.view.cellW) * dtSec);
          const d = this._drawings.find(
              (dd) => dd.id === this._dragDrawingId);
          if (d) {
            d.points = this._dragDrawingStartPoints.map((p) => ({
              price: p.price + dPrice,
              ts: p.ts + dTs,
            }));
            this.scheduleRedraw();
          }
        }
        return;
      }
```

- [ ] **Step 6: Mouseup — commit drag**

In the mouseup handler, before the existing pan-release path:

```javascript
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
        return;
      }
```

- [ ] **Step 7: Esc clears selection + drag**

In the existing keydown Esc handler (which already clears `_dragOverlay` / `_drawMode`), add:

```javascript
        if (this._dragDrawingId) {
          this._dragDrawingId = null;
          this._dragDrawingStartPoints = null;
          this._dragDrawingMoved = false;
          this.scheduleRedraw();
        }
        if (this._selectedDrawingId) {
          this._selectedDrawingId = null;
          this.scheduleRedraw();
        }
```

Static check: `node --check web/chart-engine/chart.js`.

---

# Group D — Color swatch palette

### Task D1: Render color palette next to selected drawing's delete chip

**Files:** `web/chart-engine/chart.js`

In `_drawDrawings`, AFTER the delete chip render block, add a swatch palette when `d.id === this._selectedDrawingId`:

```javascript
        if (d.id === this._selectedDrawingId) {
          const colors = ['#3B82F6', '#EF4444', '#10B981', '#F59E0B',
                          '#8B5CF6', '#EC4899', '#06B6D4', '#FFFFFF'];
          const swatchSize = 14;
          const gap = 2;
          // Strip starts immediately right of the delete chip.
          let sx = chipX + chipW + 6;
          const sy = chipY;
          for (const c of colors) {
            ctx.fillStyle = c;
            this._roundedRect(sx, sy, swatchSize, swatchSize, 2);
            ctx.fill();
            // Outline for the currently-selected color.
            ctx.strokeStyle = c.toLowerCase() === (d.color || '').toLowerCase()
                ? '#FFFFFF' : 'rgba(0,0,0,0.4)';
            ctx.lineWidth = c.toLowerCase() === (d.color || '').toLowerCase()
                ? 2 : 1;
            this._roundedRect(sx, sy, swatchSize, swatchSize, 2);
            ctx.stroke();
            this._colorSwatchHits.push({
              rect: { x: sx, y: sy, w: swatchSize, h: swatchSize },
              color: c, drawingId: d.id,
            });
            sx += swatchSize + gap;
          }
        }
```

(Make sure `this._colorSwatchHits = []` is reset at the TOP of `_drawDrawings` — alongside `this._drawingHits = []`.)

Static check: `node --check web/chart-engine/chart.js`.

---

# Group E — Static gates + smoke

### Task E1: Final gates

- [ ] `flutter analyze lib/screens/web/chart_engine` → No issues
- [ ] `node --check web/chart-engine/chart.js web/chart-engine/chart-engine.js web/chart-engine/aggregator.js web/chart-engine/theme.js` → no output
- [ ] `node web/chart-engine/aggregator.test.js` → 15 passed

### Task E2: Manual smoke

Spec §7's 9-step list.

---

## Notes for the executing engineer

- **Do not commit.**
- **`_colorSwatchHits` reset** must be done at the top of `_drawDrawings` (alongside `_drawingHits = []`); otherwise stale swatch hits from the previous frame would still register clicks.
- **Drag deselection edge** — clicking on empty area should clear selection. Place the deselect check AFTER the line-band hit loop so it only fires if no hit matched.
- **Pause and ask** only on signature mismatches that can't be inferred from existing patterns.
