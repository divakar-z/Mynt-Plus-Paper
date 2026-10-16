# Chart Engine — Phase 2 Design

**Status:** approved through brainstorming · ready for implementation plan
**Date:** 2026-05-21
**Builds on:** Phase 1 (single-pane chart embedded in iframe via HtmlElementView)
**Scope:** Multi-pane layouts (1 → 6 panes, ~23 layout templates) with persistent per-pane state, click-to-focus active pane, and a TradingView-style layout picker

---

## 1. Goals & non-goals

**Goal:** Extend the Phase 1 chart engine to host multiple independent chart panes in a user-selectable layout, with each pane carrying its own symbol / timeframe / overlay state. Active pane is highlighted; the existing Flutter top bar's pickers operate on that active pane. Layout and per-pane state persist across sessions via SharedPreferences.

**In scope:**

- ~23 layouts spanning 1–6 panes (full TradingView-style catalog).
- Layout picker widget in the Flutter top bar (icon grid grouped by pane count).
- Click any pane to make it active; active pane gets a visual highlight.
- Per-pane symbol + timeframe + overlay state (fully independent — no sync features).
- Per-pane "chip" inside each pane showing its current symbol · timeframe.
- Grow rule: new panes copy the active pane's state at the moment of layout change.
- Shrink rule: keep active pane first, then surviving panes in original order, drop the surplus.
- Persistence: SharedPreferences key `chart_engine_session_v1` (JSON). Restored on shell startup.
- Migration from Phase 1's single-pane `Map<String, PaneState>` keyed `'main'`.

**Non-goals:**

- Symbol or timeframe sync between panes ("Link symbols" toggle) — explicitly out per user spec.
- Per-pane top bar with its own pickers — only one shared top bar that controls the active pane.
- Server-side persistence of layouts — SharedPreferences for now; a backend endpoint comes in a later phase.
- Drag-to-resize pane splitters — layouts are fixed at the templates we ship (no continuous split-bar drag).
- Layout templates beyond what's listed in §3 — adding more is mechanical, just out of Phase 2's scope.
- Position / order overlays (Phase 3), quick-trade sidebar (Phase 4), drag-to-modify orders (Phase 5), drag-drop SL (Phase 6), indicators (Phase 7) — all deferred.

## 2. UX behaviour

### 2.1 Layout picker

- New icon button in the Flutter top bar (left side, before the Symbol picker). Icon shows the current layout's glyph.
- Click → opens a popup with rows grouped by pane count: row of 1-pane (just `single`), row of 2-pane options, … up through 6-pane.
- Each row shows the layouts of that pane-count as small icons (24×24 px each). Click an icon to apply that layout.
- The popup uses the same `PointerInterceptor` + iframe-pointer-events-gate pattern as the existing Symbol / Timeframe / Settings popups.
- Currently-selected layout's icon gets the same highlight treatment as a selected option in the Timeframe dropdown (blue background).

### 2.2 Active pane

- On initial load (or after restore from SharedPreferences), the active pane is the one whose `activePaneIndex` was saved. Default for a fresh install: pane index 0.
- Click anywhere on a pane's canvas → that pane becomes active.
- Active pane gets a 2px inside-shadow highlight in the theme's accent colour (light or dark equivalent).
- The Flutter top bar's Symbol / Timeframe / Settings pickers always operate on the active pane. Changing symbol on the active pane never affects other panes.

### 2.3 Per-pane chip

- Drawn by the chart engine in the canvas, top-left of each pane, BEFORE the OHLC strip text.
- Format: `SYMBOL · TIMEFRAME` (e.g. `NIFTY · 1m`). Same font / size / colour as the OHLC label colour.
- For dummy / no-symbol panes (only possible briefly during layout grow before the new pane's state has loaded), shows `—` until populated.

### 2.4 Layout grow (e.g. 1 → 3 panes)

1. New panes get a deep copy of the active pane's state (scrip + timeframeMinutes + overlays).
2. `activePaneIndex` stays the same (since the active pane is preserved at its existing index).
3. Each new pane individually fetches its own history (the symbol is the same as the active pane, but the request is fired by each `Chart` instance independently).

### 2.5 Layout shrink (e.g. 4 → 2 panes)

1. Build the keep-order list: `[panes[activeIndex], …other panes in original index order]`.
2. Take the first N of that list (where N = new layout's pane count).
3. The new `activePaneIndex` is 0 (the formerly-active pane is now at index 0).
4. Surplus panes' state is discarded; their iframe `Chart` instances are destroyed (calls `chart.destroy()` which fires `unsubscribe`).

### 2.6 Persistence

- Storage: SharedPreferences, key `chart_engine_session_v1`, JSON value.
- Saved on every store mutation (debounced 200ms).
- Restored on the first `build()` of the shell screen (in `initState`).
- Schema version field for forward-compat; on unrecognised version, fall back to default + overwrite.

## 3. Layout catalog

Each layout maps to a CSS `grid-template-areas` string (single source of truth for the visual). The pane index is the alphabetical order of the area letter (`a`=0, `b`=1, `c`=2, `d`=3, `e`=4, `f`=5).

| Enum value | Panes | `grid-template-areas` | `grid-template-rows` | `grid-template-columns` |
|---|---|---|---|---|
| `single` | 1 | `"a"` | `1fr` | `1fr` |
| `cols2` | 2 | `"a b"` | `1fr` | `1fr 1fr` |
| `rows2` | 2 | `"a" "b"` | `1fr 1fr` | `1fr` |
| `cols3` | 3 | `"a b c"` | `1fr` | `1fr 1fr 1fr` |
| `rows3` | 3 | `"a" "b" "c"` | `1fr 1fr 1fr` | `1fr` |
| `t1b2` | 3 | `"a a" "b c"` | `1fr 1fr` | `1fr 1fr` |
| `t2b1` | 3 | `"a b" "c c"` | `1fr 1fr` | `1fr 1fr` |
| `l1r2` | 3 | `"a b" "a c"` | `1fr 1fr` | `1fr 1fr` |
| `l2r1` | 3 | `"a c" "b c"` | `1fr 1fr` | `1fr 1fr` |
| `grid2x2` | 4 | `"a b" "c d"` | `1fr 1fr` | `1fr 1fr` |
| `cols4` | 4 | `"a b c d"` | `1fr` | `1fr 1fr 1fr 1fr` |
| `rows4` | 4 | `"a" "b" "c" "d"` | `1fr 1fr 1fr 1fr` | `1fr` |
| `t1b3` | 4 | `"a a a" "b c d"` | `1fr 1fr` | `1fr 1fr 1fr` |
| `t3b1` | 4 | `"a b c" "d d d"` | `1fr 1fr` | `1fr 1fr 1fr` |
| `l1r3` | 4 | `"a b" "a c" "a d"` | `1fr 1fr 1fr` | `1fr 1fr` |
| `l3r1` | 4 | `"a d" "b d" "c d"` | `1fr 1fr 1fr` | `1fr 1fr` |
| `t1b4` | 5 | `"a a a a" "b c d e"` | `1fr 1fr` | `1fr 1fr 1fr 1fr` |
| `t4b1` | 5 | `"a b c d" "e e e e"` | `1fr 1fr` | `1fr 1fr 1fr 1fr` |
| `l1r4` | 5 | `"a b" "a c" "a d" "a e"` | `1fr 1fr 1fr 1fr` | `1fr 1fr` |
| `l4r1` | 5 | `"a e" "b e" "c e" "d e"` | `1fr 1fr 1fr 1fr` | `1fr 1fr` |
| `t2b3` | 5 | `"a a b b b" "c c d d e"` | hand-tuned | hand-tuned (use `t2b3` template literal below) |
| `grid3x2` | 6 | `"a b c" "d e f"` | `1fr 1fr` | `1fr 1fr 1fr` |
| `grid2x3` | 6 | `"a b" "c d" "e f"` | `1fr 1fr 1fr` | `1fr 1fr` |

For `t2b3` and similar asymmetric 5-pane layouts that don't fit cleanly into a 2×N grid, use uneven row/column fractions:

```css
/* t2b3 example: top 2 panes (1:1), bottom 3 panes (1:1:1), rows 1:1 */
grid-template-areas: "a a a b b b" "c c d d e e";
grid-template-rows: 1fr 1fr;
grid-template-columns: 1fr 1fr 1fr 1fr 1fr 1fr;
```

(Use a 6-column track so 2 above and 3 below align cleanly.)

If any layout in this table proves visually awkward when implemented, swap to a hand-tuned `grid-template` string; the enum value stays the same.

## 4. Architecture changes

### 4.1 Flutter side

**`lib/screens/web/chart_engine/state/chart_engine_store.dart` — extended:**

- New `enum ChartLayout` with all values from §3. Each value has:
  - `int get paneCount`
  - `String get gridAreas` (the CSS `grid-template-areas` value)
  - `String get gridRows` (the CSS `grid-template-rows` value)
  - `String get gridColumns` (the CSS `grid-template-columns` value)
  - `String get id` (the enum name as a string — used as the postMessage value and as the persistence string)
- `ChartEngineSession` rewritten:
  - `final ChartLayout layout`
  - `final int activePaneIndex`
  - `final List<PaneState> panes` (replaces the old `Map<String, PaneState>`)
  - `PaneState get active => panes[activePaneIndex]`
- `ChartEngineSessionNotifier` adds:
  - `setLayout(ChartLayout next)` — applies grow / shrink rules per §2.4 / §2.5.
  - `setActivePane(int index)` — clamps to `[0, panes.length-1]`.
  - **Existing setter signatures change** from `String paneId` (Phase 1: hardcoded `'main'`) to `int index`: `setPaneSymbol(int index, ChartScrip)`, `setPaneTimeframe(int index, int minutes)`, `setPaneOverlays(int index, ChartOverlays)`. Call sites in `ChartEngineTopBar` (the symbol/timeframe/settings popups) update to pass `session.activePaneIndex`.
  - On every mutation: trigger a debounced save via `_schedulePersist()`.
- Persistence:
  - `_schedulePersist()` — `Timer` that fires after 200ms idle, calls `_persist()`.
  - `_persist()` — serialises `ChartEngineSession` to JSON, writes via `locator<Preferences>().write(_kKey, json)`. Same `Preferences` wrapper used elsewhere in the app.
  - `_restore()` — called from `build()` once (first call). Reads the prefs key, parses JSON, validates version, applies to state. On any parse failure: log + fall back to default.
  - Phase 1 migration: if the prefs key contains an older shape (e.g. `Map<String, ...>` with key `'main'`), convert to single-element `List<PaneState>` with `layout: ChartLayout.single`.

**`lib/screens/web/chart_engine/chart_engine_shell_screen.dart` — extended:**

- Push `setLayout` to iframe whenever `session.layout` changes (was hardcoded).
- Push `setActivePane` to iframe whenever `session.activePaneIndex` changes.
- The diff-and-push pattern for per-pane state extends to a loop over `0..N-1` panes; we already cache last-pushed values per index via maps.
- Handles new inbound message `paneActivated` — calls `setActivePane(index)` on the notifier.
- On the iframe-ready handshake: fan out the FULL persisted state (layout + activePane + every pane) before the user does anything.

**`lib/screens/web/chart_engine/widgets/layout_picker.dart` — new file:**

- `LayoutPicker` widget. `ConsumerWidget`.
- Trigger: a button in the top bar showing the current layout's icon glyph.
- Popup: a `Card`-styled container with rows grouped by pane count:
  - Row "1": just the `single` layout's icon.
  - Row "2": cols2, rows2 icons.
  - Row "3": cols3, rows3, t1b2, t2b1, l1r2, l2r1 icons.
  - Row "4": grid2x2, cols4, rows4, t1b3, t3b1, l1r3, l3r1 icons.
  - Row "5": t1b4, t4b1, l1r4, l4r1, t2b3 icons.
  - Row "6": grid3x2, grid2x3 icons.
- Icon rendering: each layout's glyph is just a 24×24 `CustomPaint` that draws the same grid-areas at scale (no SVG assets needed — `CustomPainter` parses the areas string and draws cells). This keeps the file count down and means new layouts get their icon automatically.
- Selected layout icon gets a blue background (consistent with the Timeframe picker's current-value highlight).
- Uses `PointerInterceptor` + `onPopupVisibilityChanged` like every other popup in the top bar.

**`lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` — extended:**

- New `LayoutPicker` widget added as the first child of the `Wrap`.
- Symbol picker / Timeframe picker / Settings popup now read from `session.active` (the active pane's state) instead of `session.main`.
- Their callbacks call `setPaneSymbol(session.activePaneIndex, …)` etc. instead of using a hardcoded `'main'` key.

### 4.2 JS side

**`web/chart-engine/chart-engine.js` — extended:**

- Pane registry already keyed by paneId. Phase 2 uses stringified integer IDs (`'0'`, `'1'`, …) instead of `'main'`.
- New message handler `setLayout`:
  - Apply CSS class on `#layout` element (e.g. `layout.className = 'grid grid-' + value`).
  - Apply `grid-template-areas`, `grid-template-rows`, `grid-template-columns` as inline styles (sent by Flutter in the message payload so JS doesn't need a duplicated template table). Payload: `{type:'setLayout', value: {id, areas, rows, columns, paneCount}}`.
  - Compute the desired pane IDs `['0', '1', ..., paneCount-1]`.
  - Destroy `Chart` instances whose paneId isn't in the new set (calls `chart.destroy()`).
  - Create the layout grid: for each paneId in the new set, ensure a `<div class="pane" id="pane-{id}" style="grid-area: {areaLetter}"></div>` exists in `#layout`. Reuse existing pane DOM where possible.
  - For each new pane, instantiate a new `Chart` and add to registry. Existing panes are left untouched.
- New message handler `setActivePane`:
  - Remove `.active` class from every `.pane`.
  - Add `.active` class to `#pane-{id}`.
- Click-on-pane handler:
  - In each pane's `Chart._attachInteraction`, the existing `mousedown` listener already detects `'pan'` mode. Add a `parent.postMessage(JSON.stringify({type: 'paneActivated', value: { paneId: this.paneId }}), '*')` call at the top of `mousedown` (BEFORE drag-mode classification, so even a no-move click activates the pane).
- `tokenToPanes` map's cleanup pass: when a pane is destroyed, remove its paneId from every set in `tokenToPanes`; if a set goes empty, drop the entry (we already do this implicitly via `Chart.destroy()` → `unsubscribe()`).

**`web/chart-engine/chart.js` — extended:**

- New `_drawPaneChip(plot)` method called at the very top of `_drawOhlc` (so the chip sits BEFORE the OHLC labels in the same strip).
  - Content: `SYMBOL · TIMEFRAME` (e.g. `NIFTY · 1m` via `formatTimeframeLabel(this.timeframeMinutes)` — same helper as the Flutter top bar uses; here we duplicate it in JS).
  - Style: same `palette.ohlcLabel` colour + same font as the OHLC labels.
  - Returns the width consumed so `_drawOhlc` can offset its own text.

**`web/chart-engine/style.css` — extended:**

- New `--accent` CSS variable on each theme:
  - Dark: `#3B82F6` (blue)
  - Light: `#2563EB` (darker blue)
- `.pane.active { box-shadow: inset 0 0 0 2px var(--accent); }`
- `#layout` grid styles applied dynamically via JS `style.gridTemplateAreas`/etc.; no per-layout CSS class needed since the template comes from JS.
- Pane container css already exists from Phase 1 (`.pane { position: relative; … }`).

## 5. Message bridge (deltas vs Phase 1)

All inherited from Phase 1; new types listed.

### Flutter → iframe (new)

| Message | Payload | Meaning |
|---|---|---|
| `setLayout` | `{id, areas, rows, columns, paneCount}` | Switch layout. iframe recreates pane registry to match `paneCount`, applies grid template. |
| `setActivePane` | `{paneId}` | Switch active pane visual highlight. |

### iframe → Flutter (new)

| Message | Payload | Meaning |
|---|---|---|
| `paneActivated` | `{paneId}` | A user click on the pane requested focus. Flutter updates `activePaneIndex`. |

### Existing messages, semantics

- `setPaneSymbol`, `setPaneTimeframe`, `setOverlays` — already paneId-keyed in Phase 1. No change to wire format, just used per-pane now.
- `subscribe` / `unsubscribe` — already per-pane (each pane reports its own subscriptions; Flutter forwards ticks based on `tokenToPanes` set membership in the iframe).
- `tick` — already routed by token; Phase 2 just means a tick may fan out to MULTIPLE panes if they share a symbol.

## 6. Edge cases

- **Pane on a non-tradable / unknown symbol after restore** (e.g. instrument expired): pane's `_loadHistory` fetches → empty result → `_showOverlay('No history available')` on that pane only. Other panes unaffected. User can change the symbol via the top bar after clicking that pane.
- **Restore corrupted JSON** (e.g. manual prefs tampering or older incompatible version): wrap `jsonDecode` + version check + per-field type validation in try/catch. On ANY failure, log a warning, fall back to default single-pane NIFTY, and overwrite prefs with the default so next load is clean.
- **Layout change while a pane has a pending history fetch:** if that pane survives the layout change, its pending request still resolves correctly. If the pane is DESTROYED (e.g. shrink dropped it), `chart.destroy()` clears `_pendingRequestId = null`, so the stale `historyResult` is dropped by the existing `requestId !== _pendingRequestId` guard.
- **Click on a pane in the middle of a drag** (drag started over pane A, then mouse drifted into pane B before mouseup): treat as a continuation of the original drag, NOT as activation of pane B. The `paneActivated` post happens on `mousedown` only, not `mousemove`, so this works automatically.
- **`setLayout` arriving while a tick is being processed:** the tick has already routed to whichever paneIds were live at that microsecond. If the receiving pane is destroyed between the post and the ingest, the message handler in `chart-engine.js` checks `panes.has(paneId)` before invoking `chart.ingestTick`. Safe.
- **Rapid-fire layout changes** (user clicking many layout icons fast): each `setLayout` is idempotent — applies the new grid + reconciles the registry. Worst case: a few stale layout messages process in quick succession; the LATEST always wins because each one rebuilds the registry to the message's `paneCount`.

## 7. Testing

- **Static gates:** `flutter analyze lib/screens/web/chart_engine` clean. `node --check web/chart-engine/*.js` clean.
- **Persistence round-trip test (Dart unit test):** instantiate `ChartEngineSession`, save → restore → assert equality across all enum/value fields. (Optional but cheap.)
- **Manual smoke checklist** (in PR description):
  1. Open `/charts` → see single-pane NIFTY 1m (default fresh state).
  2. Click the layout picker → see ~23 layout icons grouped 1/2/3/4/5/6 by row.
  3. Click `cols2` → see 2 side-by-side panes both showing NIFTY 1m.
  4. Click the right pane → its border highlights blue. Change Symbol to RELIANCE → right pane updates, left pane stays NIFTY.
  5. Click `grid2x2` → see 4 panes (left 2 still NIFTY+RELIANCE in slots 0+1, slots 2+3 copy the active pane).
  6. Change layout back to `single` → only the active pane survives.
  7. Click `l1r2` → see asymmetric layout (left tall, right top/bottom).
  8. Verify per-pane chip in each pane shows correct `SYMBOL · TIMEFRAME`.
  9. Reload the browser tab → layout + per-pane symbols + active pane restore exactly.
  10. Open DevTools → manually corrupt the SharedPreferences key value → reload → app starts at default + overwrites the bad data (verify no crash).
  11. Switch app theme → all panes' canvases AND the active-pane highlight colour update in real time.
  12. Navigate to /home and back to /charts → state intact.
  13. Live ticks (market hours) update the live candle in EVERY pane that shows that symbol.

## 8. Open questions for later phases (NOT Phase 2)

- **Drag-to-resize splitters** between panes — could be added as a Phase 2.5 if asked, but Phase 2 ships with fixed-fraction layouts.
- **Symbol sync ("link symbols") toggle** — explicitly out of scope; can be added later as an opt-in mode without breaking the per-pane-independent default.
- **Per-pane indicator overlays** (Phase 7) — when added, each pane needs its own `overlays.indicators` list in `PaneState`. The current `overlays: ChartOverlays` only carries `gridlines` + `volume`.
- **Server-side layout persistence** — current SharedPreferences scheme is intentionally a stop-gap. A backend endpoint `GET/PUT /user/chart-layout` later can replace `_persist`/`_restore` with no other call-site changes.
- **Layout copy-paste / sharing** (e.g. "load my colleague's NIFTY+BANKNIFTY+SENSEX setup") — out of scope but the JSON format is sharable as-is.
