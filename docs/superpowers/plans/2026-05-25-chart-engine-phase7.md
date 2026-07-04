# Chart Engine — Phase 7 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two on-chart drawings (HLine, Trendline) per-scrip, persisted in chart-engine prefs. Top-bar tool button enters draw mode; HLine = 1 click, Trendline = 2 clicks. Hover existing drawing → `×` chip → click deletes. No drag-to-move yet.

**Architecture:** `ChartEngineSession.drawings: Map<scripKey, List<ChartDrawing>>` is the source of truth, persisted via the existing `chartEngineSessionV1` blob. Shell pushes the per-scrip list to each pane (via `setPaneDrawings`) whenever its scrip's drawings change. Tool selection from the top bar pushes `setDrawMode(kind)` to ALL panes; first commit anywhere ends draw mode for everyone. Iframe handles mousedown intercept for placement, renders lines + delete chips, posts `drawingCommitted` / `drawingDeleted` to Flutter.

**Tech Stack:** Flutter (Riverpod 3) + vanilla JS + Canvas 2D.

## Project conventions

- **No git commits.**
- **Static gates after every edit:** `flutter analyze lib/screens/web/chart_engine` (Dart) + `node --check web/chart-engine/<file>.js` (JS).
- **Spec reference:** `docs/superpowers/specs/2026-05-25-chart-engine-phase7-design.md`.
- **Reuse Phase 3-6 patterns:** `_overlayHits` hit-test pattern; `_pushedXxxJson` diff cache; `setActiveDrawTool` mirrors `setInstantOrders` pattern.

## File map

### Modified (Flutter)
| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | New `ChartDrawing` + `DrawingPoint` classes; `ChartEngineSession.drawings` field + JSON; `activeDrawTool` ephemeral field (NOT persisted; UI state only); notifier methods `addDrawing` / `removeDrawing` / `setActiveDrawTool`. |
| `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart` | `encodeSetPaneDrawings(paneId, list)` + `encodeSetDrawMode(kind)`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | `_pushedDrawingsJson` cache; per-pane push in `_pushSession`; inbound `drawingCommitted` + `drawingDeleted` handlers; outbound `setDrawMode` whenever `activeDrawTool` changes. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | New `_DrawButton` widget appended to top-bar `Wrap`. |

### Modified (JS)
| Path | What |
|---|---|
| `web/chart-engine/chart-engine.js` | `case 'setPaneDrawings'` + `case 'setDrawMode'` (broadcasts to all panes). |
| `web/chart-engine/chart.js` | `_drawings` + `_drawMode` + `_inProgressDrawing` + `_drawingHits` state; `setDrawings(list)` + `setDrawMode(kind)` methods; `_drawDrawings(plot, priceToY)` renderer; mousedown intercept for draw-mode placement (suppresses pan/overlay paths while drawing); mousemove redraw for trendline in-progress; hit-test for delete-chip; helper `_xToTs(x)` for trendline placement. |

No new files.

## Task ordering

1. **Group A — Data model + bridge plumbing.** State, encoders, JS handlers (placeholders).
2. **Group B — JS rendering + interaction.** Draw mode mousedown/mousemove; render lines + delete chips.
3. **Group C — Flutter top bar + shell wiring.** Top-bar Draw button, shell pushes, inbound handlers.
4. **Group D — Static gates + smoke.**

---

# Group A — Data model + bridge

### Task A1: ChartDrawing + DrawingPoint + session field

**Files:** `lib/screens/web/chart_engine/state/chart_engine_store.dart`

- [ ] **Step 1: Add the two classes ABOVE the existing `ChartScrip` class**

```dart
class DrawingPoint {
  final double price;
  final int ts; // epoch seconds; ignored for hline
  const DrawingPoint({required this.price, required this.ts});

  Map<String, dynamic> toJson() => {'price': price, 'ts': ts};
  static DrawingPoint fromJson(Map<String, dynamic> j) => DrawingPoint(
        price: (j['price'] as num?)?.toDouble() ?? 0,
        ts: (j['ts'] as num?)?.toInt() ?? 0,
      );
}

class ChartDrawing {
  final String id;
  final String kind; // 'hline' | 'trendline'
  final String color;
  final List<DrawingPoint> points;
  const ChartDrawing({
    required this.id,
    required this.kind,
    required this.color,
    required this.points,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'color': color,
        'points': [for (final p in points) p.toJson()],
      };
  static ChartDrawing fromJson(Map<String, dynamic> j) => ChartDrawing(
        id: j['id'] as String? ?? '',
        kind: j['kind'] as String? ?? 'hline',
        color: j['color'] as String? ?? '#3B82F6',
        points: [
          for (final p in (j['points'] as List? ?? const []))
            DrawingPoint.fromJson(p as Map<String, dynamic>),
        ],
      );
}
```

- [ ] **Step 2: Add `drawings` + `activeDrawTool` to `ChartEngineSession`**

Update the class — add the two fields with defaults, update constructor, copyWith, toJson, fromJson. `activeDrawTool` is NOT persisted (UI-only state; reset on reload).

```dart
class ChartEngineSession {
  final ChartLayout layout;
  final int activePaneIndex;
  final List<PaneState> panes;
  final bool instantOrders;
  final bool instantWarningAck;
  final Map<String, List<ChartDrawing>> drawings; // NEW — keyed by 'EXCH|TOKEN'
  final String? activeDrawTool;                   // NEW — 'hline'/'trendline'/null

  const ChartEngineSession({
    this.layout = ChartLayout.single,
    this.activePaneIndex = 0,
    this.panes = const [PaneState()],
    this.instantOrders = false,
    this.instantWarningAck = false,
    this.drawings = const {},
    this.activeDrawTool,
  });

  // copyWith — add the new params
  ChartEngineSession copyWith({
    ChartLayout? layout,
    int? activePaneIndex,
    List<PaneState>? panes,
    bool? instantOrders,
    bool? instantWarningAck,
    Map<String, List<ChartDrawing>>? drawings,
    Object? activeDrawTool = _sentinel,
  }) =>
      ChartEngineSession(
        layout: layout ?? this.layout,
        activePaneIndex: activePaneIndex ?? this.activePaneIndex,
        panes: panes ?? this.panes,
        instantOrders: instantOrders ?? this.instantOrders,
        instantWarningAck: instantWarningAck ?? this.instantWarningAck,
        drawings: drawings ?? this.drawings,
        activeDrawTool: identical(activeDrawTool, _sentinel)
            ? this.activeDrawTool
            : activeDrawTool as String?,
      );
```

Update toJson: add `'drawings': { for (final e in drawings.entries) e.key: [for (final d in e.value) d.toJson()] }`. Skip `activeDrawTool` (ephemeral).

Update fromJson: parse the `drawings` map back; `activeDrawTool` stays null on hydrate.

```dart
  Map<String, dynamic> toJson() => {
        'version': 1,
        'layout': layout.id,
        'activePaneIndex': activePaneIndex,
        'panes': [for (final p in panes) p.toJson()],
        'instantOrders': instantOrders,
        'instantWarningAck': instantWarningAck,
        'drawings': {
          for (final e in drawings.entries)
            e.key: [for (final d in e.value) d.toJson()],
        },
      };

  static ChartEngineSession fromJson(Map<String, dynamic> j) {
    // ... existing layout / panes hydration unchanged ...
    final drawingsRaw = j['drawings'] as Map<String, dynamic>? ?? const {};
    final drawings = <String, List<ChartDrawing>>{
      for (final e in drawingsRaw.entries)
        e.key: [
          for (final d in (e.value as List? ?? const []))
            ChartDrawing.fromJson(d as Map<String, dynamic>),
        ],
    };
    return ChartEngineSession(
      layout: layout,
      activePaneIndex: activePaneIndex.clamp(0, panes.length - 1),
      panes: panes,
      instantOrders: j['instantOrders'] as bool? ?? false,
      instantWarningAck: j['instantWarningAck'] as bool? ?? false,
      drawings: drawings,
      // activeDrawTool intentionally not restored
    );
  }
```

- [ ] **Step 3: Notifier methods**

Add to `ChartEngineSessionNotifier`:

```dart
void setActiveDrawTool(String? kind) {
  if (kind == state.activeDrawTool) return;
  state = state.copyWith(activeDrawTool: kind);
  // NOT persisted — but UI rebuilds.
}

void addDrawing(String scripKey, ChartDrawing d) {
  final next = Map<String, List<ChartDrawing>>.from(state.drawings);
  final list = List<ChartDrawing>.from(next[scripKey] ?? const []);
  list.add(d);
  next[scripKey] = list;
  state = state.copyWith(drawings: next);
  _schedulePersist();
}

void removeDrawing(String scripKey, String drawingId) {
  final next = Map<String, List<ChartDrawing>>.from(state.drawings);
  final list = List<ChartDrawing>.from(next[scripKey] ?? const []);
  list.removeWhere((d) => d.id == drawingId);
  if (list.isEmpty) {
    next.remove(scripKey);
  } else {
    next[scripKey] = list;
  }
  state = state.copyWith(drawings: next);
  _schedulePersist();
}
```

- [ ] **Step 4: Static check**

`flutter analyze lib/screens/web/chart_engine/state/chart_engine_store.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task A2: Bridge encoders

**Files:** `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart`

Append at the bottom:

```dart
String encodeSetPaneDrawings(
        String paneId, List<Map<String, Object?>> drawings) =>
    jsonEncode({
      'type': 'setPaneDrawings',
      'value': {'paneId': paneId, 'drawings': drawings},
    });

String encodeSetDrawMode(String? kind) => jsonEncode({
      'type': 'setDrawMode',
      'value': {'kind': kind},
    });
```

Static check: `flutter analyze lib/screens/web/chart_engine/utils/chart_engine_bridge.dart`.

---

### Task A3: chart-engine.js handlers

**Files:** `web/chart-engine/chart-engine.js`

In the `handleMessage` switch, add (alongside `setPaneQty`, `unpinCrosshair`):

```javascript
    case 'setPaneDrawings': {
      const { paneId, drawings } = d.value || {};
      if (typeof paneId !== 'string' || !Array.isArray(drawings)) return;
      const chart = panes.get(paneId);
      if (chart) chart.setDrawings(drawings);
      break;
    }
    case 'setDrawMode': {
      const { kind } = d.value || {};
      // null/undefined = exit draw mode. Broadcast to every pane.
      for (const chart of panes.values()) chart.setDrawMode(kind || null);
      break;
    }
```

Static check: `node --check web/chart-engine/chart-engine.js`.

---

# Group B — JS rendering + interaction

### Task B1: chart.js state + setters

**Files:** `web/chart-engine/chart.js`

In the constructor, alongside other overlay state (near `_pinnedHover`):

```javascript
    // Phase 7 drawing state.
    this._drawings = [];           // committed drawings for current scrip
    this._drawMode = null;         // 'hline' / 'trendline' / null
    this._inProgressDrawing = null; // { kind, points: [{price, ts}] } for trendline mid-placement
    this._drawingHits = [];        // [{ rect, drawingId, action: 'delete'|'select' }]
```

Add the two setter methods (alongside `setPaneOverlays`):

```javascript
  setDrawings(list) {
    this._drawings = Array.isArray(list) ? list : [];
    this.scheduleRedraw();
  }

  setDrawMode(kind) {
    this._drawMode = (kind === 'hline' || kind === 'trendline') ? kind : null;
    this._inProgressDrawing = null;
    this.scheduleRedraw();
  }
```

Static check.

---

### Task B2: chart.js renderer + helpers

**Files:** `web/chart-engine/chart.js`

Add `_xToTs(x)` helper (mirror of `_candleAtX` but returns the ts of the nearest candle's timestamp; for off-screen, extrapolate by `cellW`):

```javascript
  _xToTs(x) {
    if (this.candles.length === 0) return Math.floor(Date.now() / 1000);
    const N = this.candles.length;
    const plotRight = this.canvas.clientWidth - 64;
    const i = N - 0.5 - (plotRight + this.view.offsetX - x) / this.view.cellW;
    const idxFloor = Math.floor(i);
    if (idxFloor >= 0 && idxFloor < N) return this.candles[idxFloor].ts;
    // Off-screen — extrapolate from edge candle's ts + per-bar seconds.
    const dtSec = this.timeframeMinutes * 60;
    if (idxFloor < 0) return this.candles[0].ts + Math.round(idxFloor * dtSec);
    return this.candles[N - 1].ts + Math.round((idxFloor - (N - 1)) * dtSec);
  }
```

Add `_tsToX(ts, plot)` helper:

```javascript
  _tsToX(ts, plot) {
    if (this.candles.length === 0) return plot.left;
    // Find nearest candle index by ts (binary-ish).
    const N = this.candles.length;
    const dtSec = Math.max(1, this.timeframeMinutes * 60);
    // Linear approximation from first/last candle.
    const idxFloat = (ts - this.candles[0].ts) / dtSec;
    return this._candleXCenter(idxFloat, plot);
  }
```

Note: `_candleXCenter` may need a small adjustment to accept a fractional `idxFloat`. If it currently uses integer math, allow fractional gracefully.

Add `_drawDrawings(plot, priceToY)`:

```javascript
  _drawDrawings(plot, priceToY) {
    this._drawingHits = [];
    if (this._drawings.length === 0 && !this._inProgressDrawing) return;
    const ctx = this.ctx;
    const chipH = 16, padX = 4;

    const renderOne = (d, isInProgress) => {
      const color = d.color || '#3B82F6';
      ctx.save();
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.5;
      ctx.setLineDash(isInProgress ? [4, 4] : []);

      let endX = plot.right, endY = 0;
      if (d.kind === 'hline') {
        const p = d.points[0];
        if (!p) { ctx.restore(); return; }
        const y = priceToY(p.price);
        endY = y;
        ctx.beginPath();
        ctx.moveTo(plot.left, y);
        ctx.lineTo(plot.right, y);
        ctx.stroke();
      } else if (d.kind === 'trendline') {
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
          ctx.restore(); return;
        }
        endX = x2;
        endY = y2;
        ctx.beginPath();
        ctx.moveTo(x1, y1);
        ctx.lineTo(x2, y2);
        ctx.stroke();
      }
      ctx.restore();

      if (!isInProgress) {
        // Delete chip at end of line (clamped to plot width).
        const chipW = 14;
        const chipX = Math.min(endX - chipW - 4, plot.right - chipW - 4);
        const chipY = endY - chipH / 2;
        ctx.fillStyle = '#1F2937';
        this._roundedRect(chipX, chipY, chipW, chipH, 3);
        ctx.fill();
        ctx.strokeStyle = '#FFFFFF';
        ctx.lineWidth = 1;
        ctx.beginPath();
        const cx = chipX + chipW / 2, cy = endY;
        const s = 4;
        ctx.moveTo(cx - s/2, cy - s/2); ctx.lineTo(cx + s/2, cy + s/2);
        ctx.moveTo(cx + s/2, cy - s/2); ctx.lineTo(cx - s/2, cy + s/2);
        ctx.stroke();

        // Hit-test rect for delete.
        this._drawingHits.push({
          rect: { x: chipX, y: chipY, w: chipW, h: chipH },
          drawingId: d.id, action: 'delete',
        });
      }
    };

    for (const d of this._drawings) renderOne(d, false);
    if (this._inProgressDrawing) renderOne(this._inProgressDrawing, true);
  }
```

Call `_drawDrawings(plot, priceToY)` from `draw()` AFTER `_drawOverlays` but BEFORE the crosshair:

Find:
```javascript
    // LTP marker BEFORE the axis...
    this._drawLtpLine(plot, priceToY, lo, hi);

    // Overlay lines + inline labels + gutter price chips (positions/orders/SLs).
    this._drawOverlays(plot, lo, hi, priceToY);
```

After `_drawOverlays(...)`, insert:
```javascript
    this._drawDrawings(plot, priceToY);
```

Static check: `node --check web/chart-engine/chart.js`.

---

### Task B3: chart.js mousedown intercept for draw mode + delete chip

**Files:** `web/chart-engine/chart.js`

In `_attachInteraction`'s mousedown handler, BEFORE the existing overlay-hit/_overlayHitTest block, add a check for draw mode and for drawing delete-chip hits:

```javascript
      // --- Phase 7: drawing delete chip hit ---
      for (const h of this._drawingHits) {
        const r = h.rect;
        if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
          e.preventDefault(); e.stopPropagation();
          // Remove locally for instant feedback; Flutter will re-push the
          // canonical list which should match.
          this._drawings = this._drawings.filter(d => d.id !== h.drawingId);
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

      // --- Phase 7: draw-mode placement ---
      if (this._drawMode) {
        e.preventDefault(); e.stopPropagation();
        // Determine clicked price + ts using existing plot math.
        // We need a freshly computed plot — call a small helper.
        const price = this._snapPrice(this._yToPriceForDrag(y));
        const ts = this._xToTs(x);
        if (this._drawMode === 'hline') {
          const drawing = {
            id: 'd-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8),
            kind: 'hline',
            color: '#3B82F6',
            points: [{ price, ts }],
          };
          try {
            parent.postMessage(JSON.stringify({
              type: 'drawingCommitted',
              value: { paneId: this.paneId, drawing },
            }), '*');
          } catch (_) {}
          // Optimistically clear draw mode locally; Flutter's setDrawMode(null) push will reinforce.
          this._drawMode = null;
          this._inProgressDrawing = null;
          this.scheduleRedraw();
          return;
        }
        // Trendline
        if (!this._inProgressDrawing) {
          this._inProgressDrawing = {
            kind: 'trendline',
            color: '#3B82F6',
            points: [{ price, ts }],
          };
          this.scheduleRedraw();
          return;
        }
        // Second click — commit
        const drawing = {
          id: 'd-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8),
          kind: 'trendline',
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

Also in mousemove handler (top of the function body):

```javascript
      // Phase 7: trendline in-progress — redraw to track cursor.
      if (this._inProgressDrawing) this.scheduleRedraw();
```

In the existing keydown listener (Phase 5 Esc cancel), extend to also cancel draw mode / in-progress:

```javascript
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        if (this._dragOverlay) {
          this._dragOverlay = null;
          this.scheduleRedraw();
        }
        if (this._drawMode || this._inProgressDrawing) {
          this._drawMode = null;
          this._inProgressDrawing = null;
          this.scheduleRedraw();
          // Notify parent so the Draw button can exit active state.
          try {
            parent.postMessage(JSON.stringify({
              type: 'drawModeCancelled',
              value: { paneId: this.paneId },
            }), '*');
          } catch (_) {}
        }
      }
    });
```

Mousemove cursor: if `_drawMode`, set cursor to `crosshair` (already default — no change needed). If hovering over a delete chip, cursor `pointer`. The existing overlay-hit cursor logic handles this if we extend `_overlayHitTest`-style check:

Add a simple cursor branch in mousemove (before `_overlayHitTest`):

```javascript
          for (const h of this._drawingHits) {
            const r = h.rect;
            if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
              wrap.style.cursor = 'pointer';
              return; // skip rest of mousemove cursor logic
            }
          }
```

(Insert in the spot inside the `if (inside)` block, before the existing `_overlayHitTest` cursor work.)

Static check: `node --check web/chart-engine/chart.js`.

---

# Group C — Flutter top bar + shell wiring

### Task C1: `_DrawButton` widget in top bar

**Files:** `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`

Add a `_DrawButton` ConsumerWidget that:
- Reads `session.activeDrawTool` from the provider.
- Renders a button labeled `Draw` (or `Drawing: HLine`/`Drawing: Trendline` when active).
- On click: if no active tool, opens a small popup with two items (HLine, TrendLine); on selection sets `setActiveDrawTool(kind)`. If already active, calls `setActiveDrawTool(null)` (toggles off).

```dart
class _DrawButton extends ConsumerStatefulWidget {
  const _DrawButton();
  @override
  ConsumerState<_DrawButton> createState() => _DrawButtonState();
}

class _DrawButtonState extends ConsumerState<_DrawButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _openMenu() {
    if (_entry != null) return;
    _entry = OverlayEntry(builder: (_) => _buildMenu());
    Overlay.of(context).insert(_entry!);
  }

  void _closeMenu() {
    _entry?.remove();
    _entry = null;
  }

  void _pick(String kind) {
    _closeMenu();
    ref.read(chartEngineSessionProvider.notifier).setActiveDrawTool(kind);
  }

  @override
  void dispose() { _closeMenu(); super.dispose(); }

  Widget _buildMenu() {
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque, onTap: _closeMenu),
        ),
      ),
      Positioned(
        width: 180,
        child: CompositedTransformFollower(
          link: _link, showWhenUnlinked: false,
          offset: const Offset(0, 38),
          child: PointerInterceptor(
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: bg, border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(8)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  InkWell(
                    onTap: () => _pick('hline'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Icon(Icons.horizontal_rule, size: 16),
                        SizedBox(width: 10),
                        Text('Horizontal line'),
                      ]),
                    ),
                  ),
                  InkWell(
                    onTap: () => _pick('trendline'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Icon(Icons.trending_up, size: 16),
                        SizedBox(width: 10),
                        Text('Trendline'),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(chartEngineSessionProvider
        .select((s) => s.activeDrawTool));
    final label = active == null ? 'Draw' :
        active == 'hline' ? 'Drawing: HLine' : 'Drawing: Trendline';
    final isActive = active != null;
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return CompositedTransformTarget(
      link: _link,
      child: TextButton.icon(
        icon: const Icon(shadcn.LucideIcons.pencil, size: 14),
        label: Text(label),
        style: TextButton.styleFrom(
          backgroundColor: isActive ? accent : null,
          foregroundColor: isActive ? Colors.white : null,
        ),
        onPressed: () {
          if (isActive) {
            ref.read(chartEngineSessionProvider.notifier).setActiveDrawTool(null);
          } else {
            _openMenu();
          }
        },
      ),
    );
  }
}
```

Append `const _DrawButton(),` to the top-bar `Wrap`'s children list, BETWEEN `_SettingsButton(...)` and `_InstantBadge(...)`.

Static check: `flutter analyze lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`.

If `shadcn.LucideIcons.pencil` doesn't exist, use `Icons.edit` or any pencil icon available.

---

### Task C2: Shell wiring — push drawings + push setDrawMode + handle inbound

**Files:** `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add diff caches**

Near other `_pushedXxx` fields:

```dart
final Map<int, String> _pushedDrawingsJson = {};
String? _pushedDrawTool;
```

- [ ] **Step 2: Push per-pane drawings in `_pushSession`**

Inside the per-pane loop, after the existing overlay push:

```dart
      final scrip = pane.scrip;
      final scripKey = scrip == null ? null : '${scrip.exch}|${scrip.token}';
      final drawings = scripKey == null
          ? const <ChartDrawing>[]
          : (session.drawings[scripKey] ?? const <ChartDrawing>[]);
      final drawingsJson = jsonEncode([for (final d in drawings) d.toJson()]);
      if (force || _pushedDrawingsJson[i] != drawingsJson) {
        _pushedDrawingsJson[i] = drawingsJson;
        _post(encodeSetPaneDrawings(i.toString(),
            [for (final d in drawings) d.toJson()]));
      }
```

- [ ] **Step 3: Push setDrawMode globally when `activeDrawTool` changes**

After the per-pane loop, before the `setActivePane` push:

```dart
    final tool = session.activeDrawTool;
    if (force || _pushedDrawTool != tool) {
      _pushedDrawTool = tool;
      _post(encodeSetDrawMode(tool));
    }
```

- [ ] **Step 4: Add layout-change clear (same place as other caches)**

In the layout-change branch of `_pushSession` that clears `_pushedSymbolKey` etc., add:

```dart
    _pushedDrawingsJson.clear();
```

(Drawings are per-scrip not per-pane, but the cache is per-pane index. Clear on layout change to ensure new panes get fresh data.)

- [ ] **Step 5: Inbound handlers**

In `_onWindowMessage` switch, add three new cases:

```dart
      case 'drawingCommitted': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final draw = v['drawing'];
          if (pid is String && draw is Map) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final scrip = session.panes[idx].scrip;
                if (scrip != null) {
                  final scripKey = '${scrip.exch}|${scrip.token}';
                  final drawing = ChartDrawing.fromJson(
                      Map<String, dynamic>.from(draw));
                  ref
                      .read(chartEngineSessionProvider.notifier)
                      .addDrawing(scripKey, drawing);
                  // Exit draw mode after one commit.
                  ref
                      .read(chartEngineSessionProvider.notifier)
                      .setActiveDrawTool(null);
                }
              }
            }
          }
        }
        break;
      }
      case 'drawingDeleted': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final did = v['drawingId'];
          if (pid is String && did is String) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              final session = ref.read(chartEngineSessionProvider);
              if (idx >= 0 && idx < session.panes.length) {
                final scrip = session.panes[idx].scrip;
                if (scrip != null) {
                  ref
                      .read(chartEngineSessionProvider.notifier)
                      .removeDrawing('${scrip.exch}|${scrip.token}', did);
                }
              }
            }
          }
        }
        break;
      }
      case 'drawModeCancelled': {
        // Iframe-initiated cancel (e.g., Esc key in draw mode).
        ref
            .read(chartEngineSessionProvider.notifier)
            .setActiveDrawTool(null);
        break;
      }
```

Static check: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -10`.

---

# Group D — Static gates + smoke

### Task D1: Final gates

- [ ] `flutter analyze lib/screens/web/chart_engine` → No issues.
- [ ] `node --check web/chart-engine/chart-engine.js web/chart-engine/chart.js web/chart-engine/aggregator.js web/chart-engine/theme.js` → no output.
- [ ] `node web/chart-engine/aggregator.test.js` → 15 passed.

### Task D2: Manual smoke

Spec §7's 11-step list.

---

## Notes for the executing engineer

- **Do not commit.**
- **`_candleXCenter` fractional index** — if the existing function uses integer math, change it to accept a double (just remove any explicit int cast). Trendline x positioning relies on this.
- **`_yToPriceForDrag` reuse** — Phase 5 added this helper. The draw-mode placement also needs y→price; reuse the same helper.
- **`shadcn.LucideIcons.pencil`** — if that exact icon constant doesn't exist, use `Icons.edit` from Material.
- **Pause and ask** only if the existing classes/methods being extended have a signature mismatch that can't be inferred from context.
