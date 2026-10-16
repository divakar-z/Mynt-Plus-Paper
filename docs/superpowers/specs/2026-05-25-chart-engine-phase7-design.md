# Chart Engine — Phase 7 Design

**Date:** 2026-05-25
**Builds on:** Phases 1-6
**Scope summary:** Add two on-chart drawing primitives — horizontal line and trendline (two-point). Drawings are per-scrip (visible whenever that scrip is shown in any pane), persisted alongside the chart-engine session prefs. Top-bar tool button enters draw mode; placement is one or two clicks; existing drawings show a small `×` chip on hover for deletion. No drag-to-move in Phase 7 (defer).

---

## 1. Goal

For each scrip the user wants to mark up:

- **Horizontal line (HLine):** a single price, drawn as a solid line across the whole plot at that price. One placement click.
- **Trendline:** a sloped line through two points (price, timestamp). Two placement clicks.

Drawings render in every pane that's currently showing the same `exch+token`. Persist across reload via the existing `chartEngineSessionV1` prefs blob. Top-bar tool menu offers HLine / TrendLine. Existing drawings show a small `×` chip on hover; click `×` to delete.

Drag-to-move + colour pickers + more shapes are out of scope (Phase 7.1+).

---

## 2. Visual + interaction

### 2.1 Tool menu (top bar)

New `_DrawButton` widget appended to the top-bar `Wrap`, between `_SettingsButton` and `_InstantBadge`:

```
[Layout] Symbol [...] Timeframe [...] [⚙ Settings] [✏ Draw] [⚠ INSTANT]
```

- Default: outline button with a pencil-edit icon + "Draw" label.
- Click → small popup menu with two items:
  - `— Horizontal line` (icon: horizontal bar)
  - `╱ Trendline` (icon: diagonal slope)
- Pick one → enters draw mode for that tool. Button label changes to e.g. `Drawing: HLine` with a coloured background to indicate active mode. Esc key or click the button again exits draw mode.

### 2.2 Placement

While in draw mode:
- Cursor inside any chart pane: `crosshair` (same as default — no change). Optionally we'd want a subtle "pin" cursor but Phase 7 keeps it simple.
- Outside the pane, normal cursor.

**HLine (one click):**
- User clicks any pane → drawing is committed at the clicked price (snapped to scrip.ti). Time is unused for HLine. Draw mode exits automatically after one placement.

**TrendLine (two clicks):**
- First click → start point recorded; cursor now shows a tentative line from start to live cursor position.
- Second click → end point recorded; drawing committed. Draw mode exits.
- Esc during the in-progress trendline → cancels (no drawing committed).

### 2.3 Rendered drawing

- HLine: 1.5px solid line at the price, full plot width, colour = `#3B82F6` (default blue, can be made configurable later).
- TrendLine: 1.5px solid line between the two (price, ts) points, projected from the chart's `priceToY`/`tsToX`. If either point's ts is off-screen, the line is still drawn (canvas auto-clips at plot bounds via a clip region).

Each drawing has its own hit-test region (~6px-tall band along the line). On `mouseover`:
- Cursor becomes `pointer`.
- A small chip `[ × ]` appears at the right end of the drawing (mid-height for trendline, at line height for hline).

Click the `×` chip → drawing removed, persisted.

Multiple drawings at similar prices: chips stack vertically (greedy, same logic as Phase 3 overlay-chip stacking).

### 2.4 Mode exit

- Draw mode auto-exits after placement (HLine) or second click (TrendLine).
- Esc cancels mid-trendline OR exits draw mode.
- Click the `_DrawButton` while in mode → exits mode (without committing).
- Clicking the chart for any non-drawing reason (e.g., a `+` icon) is intercepted by existing handlers; in draw mode, those handlers are SUPPRESSED so the click drops a drawing instead.

---

## 3. Data model

### 3.1 Drawing record (JS + Dart parallel)

```dart
class ChartDrawing {
  final String id;                  // stable per drawing — uuid-ish
  final String kind;                // 'hline' or 'trendline'
  final String color;               // hex string e.g. '#3B82F6'
  final List<DrawingPoint> points;  // 1 for hline, 2 for trendline
  // toJson / fromJson omitted in this design summary
}

class DrawingPoint {
  final double price;
  final int ts;                     // epoch seconds; ignored for hline
}
```

### 3.2 Session-level field (NEW)

`ChartEngineSession.drawings` — `Map<String, List<ChartDrawing>>` keyed by `exch|token`. Added to `copyWith` / `toJson` / `fromJson`. Persists alongside layout / panes / instantOrders.

### 3.3 Bridge messages

Outbound (Flutter → iframe):
```dart
String encodeSetPaneDrawings(String paneId, List<Map<String, Object?>> drawings);
```

Pushed in `_pushSession` per-pane: looks up `session.drawings[scripKey]` for each pane's scrip, sends. Diff-cached via `_pushedDrawingsJson: Map<int, String>`.

Inbound (iframe → Flutter):
```js
// User clicked the chart while in draw mode and committed a drawing.
{ type: 'drawingCommitted', value: { paneId, drawing: { ... } } }
// User clicked the × chip on an existing drawing.
{ type: 'drawingDeleted', value: { paneId, drawingId } }
```

### 3.4 Draw mode

A pane-level state (per Chart instance in chart.js): `this._drawMode = null | { kind, points: [] }`. NOT pushed from Flutter — purely iframe state.

Flutter activates draw mode via a NEW outbound message:
```dart
String encodeSetDrawMode(String paneId, String? kind);
// 'hline' / 'trendline' / null (cancel)
```

Actually simpler: Flutter sends `setDrawMode(kind)` GLOBALLY (to ALL panes via chart-engine.js): when user picks a tool, ALL panes enter draw mode for that kind. First placement in any pane commits + exits all panes.

---

## 4. Architecture summary

### 4.1 Flutter side

- `ChartEngineSession.drawings` (NEW field, Map keyed by scripKey).
- Notifier methods: `addDrawing(scripKey, ChartDrawing)`, `removeDrawing(scripKey, drawingId)`.
- `_pushSession` pushes `setPaneDrawings(paneId, drawings)` per pane, looking up `session.drawings[scripKey]` for each pane's scrip.
- Top-bar `_DrawButton` widget; popup menu picks tool → `notifier.setActiveDrawTool(kind)` + `_post(encodeSetDrawMode(kind))`.
- Inbound `drawingCommitted` → `notifier.addDrawing(scripKey, drawing)` (which triggers `_pushSession` to re-push drawings to all panes showing that scrip).
- Inbound `drawingDeleted` → `notifier.removeDrawing(scripKey, drawingId)`.

### 4.2 JS side

- `chart-engine.js` adds `case 'setPaneDrawings'` → `chart.setDrawings(list)`.
- `chart-engine.js` adds `case 'setDrawMode'` → set `_drawMode` on ALL panes.
- `chart.js`:
  - `this._drawings = []` (current list)
  - `this._drawMode = null` (current draw mode)
  - `this._inProgressDrawing = null` (intermediate state during TrendLine first click)
  - `setDrawings(list)`: replace `_drawings`, redraw.
  - `setDrawMode(kind)`: set mode; clear in-progress; redraw.
  - `_drawDrawings(plot, priceToY)`: render each drawing (line + hover chip).
  - Mousedown interception: if `_drawMode != null`, compute clicked price (snapped) + ts (from x), commit accordingly (HLine immediately; TrendLine first click sets in-progress, second click commits). Post `drawingCommitted` to parent. Clear `_drawMode` after commit.
  - Mousemove during TrendLine in-progress: redraw tentative line from start to cursor.
  - Hit-test drawings (6px band): cursor `pointer`. If `×` chip area clicked → post `drawingDeleted` and remove from `_drawings` locally (Flutter will re-push the canonical list).

### 4.3 Coordinate mapping

`tsToX` doesn't exist on chart.js yet (only `_candleXCenter`). Need a helper that maps a timestamp to an x-pixel based on the current view (offsetX, cellW, candle index). For drawings the ts maps to the nearest candle's x. If ts is between two candles, interpolate proportionally.

For an off-screen ts (e.g., trendline endpoint is past the right edge), the x can be outside `[plot.left, plot.right]`; clipping at the plot bounds is fine.

For HLine, ts is unused; y is `priceToY(price)` and x spans full plot.

---

## 5. Edge cases

| Case | Behaviour |
|---|---|
| Pane scrip is null | Don't render drawings; ignore commit |
| Symbol change while in draw mode | Draw mode persists across the change (you can place a drawing on the new symbol) |
| Layout change while in draw mode | Draw mode persists; new panes also enter draw mode via setDrawMode push |
| Same drawing in two panes showing same scrip | Both panes render it; click `×` in either pane → both panes drop it via Flutter's centralised list |
| Drawing ts is older than visible window | Drawing's start x is off-screen-left; only the visible portion is drawn (canvas clip) |
| Drawing price is off-screen | Same — clipped |
| User clicks a `+` icon while in draw mode | Draw mode wins (intercepted first); `+` does not open |
| User commits a trendline by clicking the same candle twice | Allowed; degenerate (zero-slope) trendline rendered |
| User has many drawings (>50) for one scrip | All rendered; performance impact negligible since canvas |

---

## 6. Files to create / modify

### Modified (Flutter)
| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | New `ChartDrawing` + `DrawingPoint` classes; `ChartEngineSession.drawings` field + toJson/fromJson; notifier `addDrawing` / `removeDrawing` / `setActiveDrawTool` (just stores nullable string for badge). |
| `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart` | `encodeSetPaneDrawings(paneId, list)` + `encodeSetDrawMode(kind)`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | `_pushedDrawingsJson` cache; per-pane push in `_pushSession`; inbound `drawingCommitted` + `drawingDeleted` handlers. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | New `_DrawButton` widget; emits `setDrawMode` outbound + records active tool in store. |

### Modified (JS)
| Path | What |
|---|---|
| `web/chart-engine/chart-engine.js` | `case 'setPaneDrawings'` + `case 'setDrawMode'` (applies to all panes). |
| `web/chart-engine/chart.js` | `_drawings` + `_drawMode` + `_inProgressDrawing` state; `setDrawings(list)` + `setDrawMode(kind)` methods; `_drawDrawings(plot, priceToY)`; mousedown intercept for draw mode; mousemove for trendline in-progress; hit-test for delete-chip. |

No new files.

---

## 7. Acceptance smoke

1. Open `/charts`. See new `[✏ Draw]` button in top bar.
2. Click Draw → popup: `Horizontal line`, `Trendline`.
3. Pick `Horizontal line` → button label changes to `Drawing: HLine`.
4. Click any pane at price 1360 → blue horizontal line drawn at 1360 (snapped to ti). Draw mode auto-exits.
5. Click Draw → pick `Trendline`. Click pane at one point → see tentative line following cursor. Click again at second point → trendline committed.
6. Hover over the HLine → small `×` chip appears at right end. Click × → line removed.
7. Switch to a second pane showing the same symbol → same drawings render.
8. Switch to a different symbol → drawings disappear; switch back → reappear.
9. Reload tab → drawings persist.
10. Esc during in-progress trendline → cancels.
11. Esc OR click Draw again while in mode → exits without placing.

If all green, Phase 7 is done.

---

## 8. Out of scope (Phase 7.1+)

- Drag-to-move drawings
- Per-drawing colour picker
- More shapes: rectangle, fib retracement, ray, channel
- Drawing labels / text annotations
- Lock/unlock drawings
- Copy-to-other-symbol
- Snap-to-LTP / snap-to-candle-high/low
