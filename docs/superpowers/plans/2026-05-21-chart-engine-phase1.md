# Chart Engine — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a fast vanilla-JS/Canvas candlestick chart embedded in the Flutter web app via `HtmlElementView` iframe, structurally designed to grow into multi-pane layouts and order/position overlays in later phases.

**Architecture:** Single iframe at `/chart-engine/` hosts an internal pane registry. Phase 1 = single pane (`paneId === 'main'`). Flutter owns the WebSocket subscription + tpseries API auth and forwards ticks to the iframe via `postMessage`. History via `getTPSeriesChart` with client-side aggregation into the target timeframe. Mirrors the orderflow chart's proven patterns: remount-safe view factory, JSON-string postMessage bridge, Geist font, light/dark theming.

**Tech Stack:** Vanilla JS + Canvas 2D inside the iframe; Flutter web + Riverpod + `dart:html` + `dart:ui_web` for the shell; existing `ApiExporter.getTPSeriesChart` + `searchScripForStrategyBuilder`; existing `websocketProvider` + `WebSubscriptionManager` for WS subscriptions.

---

## Project conventions

- **No git commits in plan steps.** User commits manually after testing the whole phase. Never include `git commit`, `git add`, or `git push` steps.
- **Static gates after every code edit:** `node --check web/chart-engine/<file>.js` for JS edits, `flutter analyze lib/screens/web/chart_engine` for Dart edits. Don't move on if either reports errors.
- **TDD where it makes sense:** `aggregator.js` has pure functions → has unit tests runnable via plain `node`. UI/canvas code has no useful unit test surface; correctness is verified at manual smoke checkpoints between groups.
- **Reference orderflow heavily.** The orderflow chart at `web/footprint-chart/` and `lib/screens/web/orderflow/` already solved 80% of the cross-cutting problems (remount, focus, theming, fonts, popup gating, label nice-stride). Tasks that mirror an orderflow pattern point to the exact file/line.

---

## File map

### Created (Flutter)
| Path | Responsibility |
|---|---|
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | Host widget. Owns `HtmlElementView`, view factory, postMessage bridge. |
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | `Notifier` holding `{symbol, timeframe, overlays}` per pane. Phase 1: one pane keyed `'main'`. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | Top bar: symbol type-ahead + timeframe dropdown + Settings popup. |
| `lib/screens/web/chart_engine/widgets/symbol_type_ahead.dart` | Debounced search using `searchScripForStrategyBuilder`. Reusable in later phases. |
| `lib/screens/web/chart_engine/widgets/timeframe_picker.dart` | Preset dropdown (1m → 1M) + "Custom…" tail item → small dialog. |
| `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart` | Pure functions for encoding/decoding the JSON-string postMessage payloads + WS tick forwarder helper. |

### Created (JS — `web/chart-engine/`)
| Path | Responsibility |
|---|---|
| `index.html` | Skeleton page: `<div id="root">` + script tag. |
| `style.css` | Theme CSS variables (light/dark via `html.light` class), `@font-face` for Geist, grid container styles. |
| `theme.js` | `PALETTES.{light,dark}` definitions + `applyTheme(name)` helper. |
| `aggregator.js` | Pure functions: `bucketCandles(source, targetMinutes)` for historical aggregation; `ingestTickIntoBucket(candles, tick, aggState, targetMs)` for live aggregation. |
| `aggregator.test.js` | `node`-runnable unit tests for the aggregator. |
| `chart.js` | `class Chart` (instance-per-pane). Owns one `<canvas>`, manages its own state, drawing, interaction. |
| `chart-engine.js` | Bootstrap. Pane registry (`Map<paneId, Chart>`). Token→panes routing for ticks. Message bridge. Layout grid renderer (Phase 1 = single pane). |

### Modified (Flutter)
| Path | What changes |
|---|---|
| `lib/screens/web/home/models/screen_type.dart` | Add `charts` enum value. |
| `lib/screens/web/customizable_split_home_screen.dart` | Add `charts` to the DUPLICATE `ScreenType` enum near line 5597 + `ScreenTypeParam.charts` + `_handleChartsTap()` + render case in `_buildScreenContent` + label case + URL case. |
| `lib/screens/web/home/utils/screen_utils.dart` | Add `charts` to switch statements. |
| `lib/screens/web/home/widgets/panels/panel_content_builder.dart` | Import + add `case ScreenType.charts: return const ChartEngineShellScreen();` |
| `lib/screens/web/window_based_home_screen.dart` | Add `charts` to switch statements (mirror orderflow). |
| `lib/screens/web/home/widgets/app_bar/navigation_drawer_web.dart` | Add `onChartsTap` callback + `showCharts` flag + drawer item under TRADE after Orderflow's slot. (Note: the user stashed the Orderflow drawer item — re-add it at the same time if the drawer file is back to pre-orderflow state.) |
| `lib/routes/web_router.dart` | Add `WebRoutes.charts = '/charts'` constant + `GoRoute` for `/charts`. |

### Not touched
- The existing TradingView iframe (`web_chart_manager.dart`, `inline_chart_portal.dart`) stays exactly as-is. The new chart is an additional destination, not a replacement.
- The orderflow chart at `web/footprint-chart/` stays exactly as-is.

---

## Task ordering (high level)

Build groups bottom-up so each group is independently testable:

1. **Group A — Iframe shell + handshake.** Foundation. End state: `/charts` route opens an empty iframe themed correctly; iframe posts `chart-engine-ready` and Flutter receives it.
2. **Group B — Aggregator + tests.** Pure logic, no UI. End state: `node aggregator.test.js` green.
3. **Group C — Symbol picker + history fetch + first paint.** End state: pick NIFTY → historical candles drawn.
4. **Group D — Live tick forwarding.** End state: rightmost candle updates live as ticks arrive.
5. **Group E — Pan/zoom/crosshair.** End state: chart is fully interactive.
6. **Group F — Top OHLC strip + price/time axes.** End state: chart looks production-ready.
7. **Group G — Volume panel + Settings popup + custom timeframe.** End state: feature-complete.
8. **Group H — Error overlays + stale pill + final analyzer pass.** End state: ready for user smoke.

---

# Group A — Iframe shell + handshake

End-state: opening `/charts` shows an empty themed iframe; the iframe's `chart-engine-ready` postMessage reaches Flutter; Flutter logs receipt to the browser console.

---

### Task A1: Create `web/chart-engine/index.html`

**Files:**
- Create: `web/chart-engine/index.html`

- [ ] **Step 1: Write the file**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Chart Engine</title>
  <link rel="stylesheet" href="style.css" />
</head>
<body>
  <div id="root">
    <div id="layout"></div>
    <div id="overlay" hidden>
      <div class="overlay-card">
        <div id="overlay-title">Loading…</div>
        <div id="overlay-detail" class="muted"></div>
      </div>
    </div>
  </div>
  <script src="theme.js"></script>
  <script src="aggregator.js"></script>
  <script src="chart.js"></script>
  <script src="chart-engine.js"></script>
</body>
</html>
```

- [ ] **Step 2: Verify the directory exists**

Run: `ls web/chart-engine/`
Expected: `index.html` listed.

---

### Task A2: Create `web/chart-engine/style.css`

**Files:**
- Create: `web/chart-engine/style.css`

- [ ] **Step 1: Write the file**

```css
/* Chart Engine — theme-aware. Mirror of web/footprint-chart/style.css. */

@font-face {
  font-family: 'Geist';
  src: url('/assets/fonts/Geist/Geist-Regular.ttf') format('truetype');
  font-weight: 400; font-style: normal; font-display: swap;
}
@font-face {
  font-family: 'Geist';
  src: url('/assets/fonts/Geist/Geist-Medium.ttf') format('truetype');
  font-weight: 500; font-style: normal; font-display: swap;
}
@font-face {
  font-family: 'Geist';
  src: url('/assets/fonts/Geist/Geist-SemiBold.ttf') format('truetype');
  font-weight: 600; font-style: normal; font-display: swap;
}
@font-face {
  font-family: 'Geist';
  src: url('/assets/fonts/Geist/Geist-Bold.ttf') format('truetype');
  font-weight: 700; font-style: normal; font-display: swap;
}

:root {
  --bg: #0B0F14;
  --text: #D1D5DB;
  --text-soft: #9CA3AF;
  --text-mute: #6B7280;
  --grid-soft: #111827;
  --grid-strong: #1F2937;
  --overlay-bg: rgba(11,15,20,0.94);
  --card-bg: #111827;
  --card-border: #1F2937;
}
html.light {
  --bg: #FFFFFF;
  --text: #0F172A;
  --text-soft: #475569;
  --text-mute: #64748B;
  --grid-soft: #F1F5F9;
  --grid-strong: #CBD5E1;
  --overlay-bg: rgba(248,250,252,0.94);
  --card-bg: #F1F5F9;
  --card-border: #E2E8F0;
}

* { box-sizing: border-box; }
html, body {
  margin: 0; padding: 0; height: 100%;
  background: var(--bg); color: var(--text);
  font-family: 'Geist', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  overflow: hidden;
}

#root { display: flex; flex-direction: column; height: 100vh; position: relative; }

/* Phase 1: single pane fills the whole layout. Phase 2 turns this into a
   CSS grid with multiple .pane children. */
#layout { flex: 1; display: grid; grid-template-columns: 1fr; grid-template-rows: 1fr; }

.pane {
  position: relative;
  display: flex;
  overflow: hidden;
  cursor: crosshair;
  outline: none;
}
.pane.dragging { cursor: grabbing; }
.pane.zoom-y { cursor: ns-resize; }
.pane.zoom-x { cursor: ew-resize; }
.pane canvas { display: block; width: 100%; height: 100%; }

#overlay {
  position: absolute; inset: 0;
  display: flex; align-items: center; justify-content: center;
  background: var(--overlay-bg);
  pointer-events: none;
  z-index: 10;
}
#overlay[hidden] { display: none; }
.overlay-card {
  padding: 14px 20px;
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: 8px;
  text-align: center;
  max-width: 460px;
}
#overlay-title { font-size: 13px; font-weight: 600; color: var(--text); }
#overlay-detail { margin-top: 4px; font-size: 11px; }
.muted { color: var(--text-mute); }
```

---

### Task A3: Create `web/chart-engine/theme.js`

**Files:**
- Create: `web/chart-engine/theme.js`

- [ ] **Step 1: Write the file**

```javascript
'use strict';

const PALETTES = {
  dark: {
    bg: '#0B0F14',
    gridSoft: '#111827',
    gridStrong: '#1F2937',
    axisText: '#6B7280',
    axisTextStrong: '#D1D5DB',
    bull: '#10B981',
    bear: '#EF4444',
    bullSoft: 'rgba(16,185,129,0.5)',
    bearSoft: 'rgba(239,68,68,0.5)',
    crosshair: 'rgba(203,213,225,0.55)',
    crosshairChip: '#1F2937',
    chipText: '#0B0F14',
    ohlcLabel: '#9CA3AF',
    ohlcValue: '#F3F4F6',
    statusLive: '#10B981',
    statusStale: '#EA580C',
  },
  light: {
    bg: '#FFFFFF',
    gridSoft: '#F1F5F9',
    gridStrong: '#CBD5E1',
    axisText: '#64748B',
    axisTextStrong: '#0F172A',
    bull: '#16A34A',
    bear: '#DC2626',
    bullSoft: 'rgba(22,163,74,0.5)',
    bearSoft: 'rgba(220,38,38,0.5)',
    crosshair: 'rgba(71,85,105,0.55)',
    crosshairChip: '#0F172A',
    chipText: '#FFFFFF',
    ohlcLabel: '#64748B',
    ohlcValue: '#0F172A',
    statusLive: '#16A34A',
    statusStale: '#CA8A04',
  },
};

let CURRENT_PALETTE = 'dark';

function getPalette() { return PALETTES[CURRENT_PALETTE] || PALETTES.dark; }

function applyTheme(name) {
  if (name !== 'light' && name !== 'dark') return;
  CURRENT_PALETTE = name;
  document.documentElement.classList.toggle('light', name === 'light');
}
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/theme.js`
Expected: no output (success).

---

### Task A4: Create `web/chart-engine/chart-engine.js` (bootstrap + handshake stub)

This is the bootstrap. Phase 1 only handles the handshake + theme + a stub `Chart` constructor call; subsequent groups fill in `setSymbol`/`setTimeframe`/`tick`/etc.

**Files:**
- Create: `web/chart-engine/chart-engine.js`

- [ ] **Step 1: Write the file**

```javascript
'use strict';

// ---------------------------------------------------------------------------
// Chart Engine — bootstrap + pane registry + Flutter message bridge
//
// Phase 1: registry holds exactly one pane keyed 'main'. The HTML host
// already provides a single grid cell (#layout). Phase 2 will grow the
// grid to N cells when 'setLayout' messages arrive.
// ---------------------------------------------------------------------------

const params = new URLSearchParams(location.search);
let THEME = (params.get('theme') || 'dark').toLowerCase();

const panes = new Map();           // paneId -> Chart instance
const tokenToPanes = new Map();    // exch|token -> Set<paneId>

function tokenKey(exch, token) { return exch + '|' + token; }

// ---------------------------------------------------------------------------
// Pane lifecycle
// ---------------------------------------------------------------------------
function ensurePane(paneId) {
  if (panes.has(paneId)) return panes.get(paneId);
  // Phase 1: a single .pane fills #layout. Phase 2 replaces this with a
  // proper grid-cell allocator.
  const layout = document.getElementById('layout');
  layout.innerHTML = '';
  const container = document.createElement('div');
  container.className = 'pane';
  container.id = 'pane-' + paneId;
  layout.appendChild(container);
  const chart = new Chart({
    container,
    paneId,
    palette: getPalette(),
    requestHistory: (req) => postToParent({ type: 'fetchHistory', value: req }),
    subscribe: (sub) => {
      const key = tokenKey(sub.exch, sub.token);
      let set = tokenToPanes.get(key);
      if (!set) { set = new Set(); tokenToPanes.set(key, set); }
      if (!set.has(paneId)) {
        set.add(paneId);
        if (set.size === 1) postToParent({ type: 'subscribe', value: sub });
      }
    },
    unsubscribe: (sub) => {
      const key = tokenKey(sub.exch, sub.token);
      const set = tokenToPanes.get(key);
      if (!set) return;
      if (set.has(paneId)) {
        set.delete(paneId);
        if (set.size === 0) {
          tokenToPanes.delete(key);
          postToParent({ type: 'unsubscribe', value: sub });
        }
      }
    },
  });
  panes.set(paneId, chart);
  return chart;
}

// ---------------------------------------------------------------------------
// Message bridge (iframe ⇄ Flutter parent)
//
// Outbound from iframe: ALWAYS a JSON string. Inbound from Flutter: accept
// both strings (preferred) and plain objects (defensive). See orderflow
// shell screen for the rationale (Dart Map ↔ JS Object round-trip is
// unreliable through dart:html postMessage).
// ---------------------------------------------------------------------------
function postToParent(message) {
  try { parent.postMessage(JSON.stringify(message), '*'); } catch (_) {}
}

window.addEventListener('message', (e) => {
  let d = e.data;
  if (typeof d === 'string') {
    try { d = JSON.parse(d); } catch (_) { return; }
  }
  if (!d || typeof d !== 'object' || typeof d.type !== 'string') return;
  handleMessage(d);
});

function handleMessage(d) {
  switch (d.type) {
    case 'setTheme':
      if (typeof d.value === 'string') {
        applyTheme(d.value);
        for (const chart of panes.values()) chart.setPalette(getPalette());
      }
      break;
    case 'setPaneSymbol': {
      const { paneId, scrip } = d.value || {};
      if (!paneId || !scrip) return;
      ensurePane(paneId).setSymbol(scrip);
      break;
    }
    case 'setPaneTimeframe': {
      const { paneId, minutes } = d.value || {};
      if (!paneId || typeof minutes !== 'number') return;
      ensurePane(paneId).setTimeframe(minutes);
      break;
    }
    case 'setOverlays': {
      const { paneId, ...flags } = d.value || {};
      if (paneId) {
        if (panes.has(paneId)) panes.get(paneId).setOverlays(flags);
      } else {
        for (const chart of panes.values()) chart.setOverlays(flags);
      }
      break;
    }
    case 'historyResult': {
      const { requestId, candles } = d.value || {};
      for (const chart of panes.values()) chart.onHistoryResult(requestId, candles);
      break;
    }
    case 'historyError': {
      const { requestId, message } = d.value || {};
      for (const chart of panes.values()) chart.onHistoryError(requestId, message);
      break;
    }
    case 'tick': {
      const { token, packet } = d.value || {};
      if (!token || !packet) return;
      // token here is just the bare token; for routing we keyed by exch|token.
      // Flutter sends both via packet.exch when available, falling back to a
      // scan across registered tokens for this bare token.
      const exch = packet.exch;
      let key = exch ? tokenKey(exch, token) : null;
      let targets = key ? tokenToPanes.get(key) : null;
      if (!targets) {
        // Fallback: any pane subscribed to this token (regardless of exch).
        targets = new Set();
        for (const [k, set] of tokenToPanes.entries()) {
          if (k.endsWith('|' + token)) for (const id of set) targets.add(id);
        }
      }
      for (const id of targets) {
        const chart = panes.get(id);
        if (chart) chart.ingestTick(packet);
      }
      break;
    }
    default:
      // Unknown message types are silently ignored (forward-compat with later phases).
      break;
  }
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------
function boot() {
  applyTheme(THEME);
  // Phase 1: pre-create the 'main' pane so the canvas exists before the
  // first setSymbol arrives. Background colour avoids a flash of unstyled
  // content.
  ensurePane('main');
  postToParent({ type: 'chart-engine-ready' });
}

window.addEventListener('load', boot);

// Make the body focusable so the parent's HtmlElementView starts routing
// pointer events into us immediately. Same fix as the orderflow chart.
document.body.tabIndex = -1;
window.addEventListener('load', () => {
  try { window.focus(); document.body.focus(); } catch (_) {}
});
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart-engine.js`
Expected: no output (success).

Note: this file references `Chart` (defined in `chart.js`, Task C2). For now `Chart` is undefined at runtime, which is fine — it's only called from `ensurePane`, which is only called from `boot()` AFTER `chart.js` is loaded.

---

### Task A5: Create `web/chart-engine/chart.js` — stub class

**Files:**
- Create: `web/chart-engine/chart.js`

This is the stub. Group C fills out history rendering; Group D fills out `ingestTick`; Group E fills out interaction; Group F-G fill out axes/OHLC/volume.

- [ ] **Step 1: Write the file**

```javascript
'use strict';

// ---------------------------------------------------------------------------
// Chart — one instance per pane. Owns a <canvas> in the given container,
// fetches its own history via the parent (which has API auth), aggregates
// live ticks routed in by chart-engine.js, draws the result.
//
// Phase 1 ships with stub method bodies for everything except boot. The
// remaining groups fill them in. This skeleton MUST stay constructable
// without errors so the handshake (chart-engine-ready) works even before
// data fetching exists.
// ---------------------------------------------------------------------------
class Chart {
  constructor({ container, paneId, palette, requestHistory, subscribe, unsubscribe }) {
    this.container = container;
    this.paneId = paneId;
    this.palette = palette;
    this.requestHistory = requestHistory;
    this.subscribe = subscribe;
    this.unsubscribe = unsubscribe;

    // Selection
    this.scrip = null;           // { exch, token, tsym, dispName, ls, ti }
    this.timeframeMinutes = 1;

    // Data
    this.candles = [];           // aggregated target-timeframe candles
    this.tickState = { lp: null, v: null, ft: null };
    this.aggState = { prevCumVol: null, prevPrice: null, prevMs: null };

    // View
    this.view = {
      cellW: 10,
      pricePerPx: null,          // null = auto-fit
      priceCenter: null,         // null = auto-fit
      offsetX: 0,
      autoFollow: true,
      autoFitY: true,
    };

    // Overlays
    this.overlays = { gridlines: true, volume: true };

    // Canvas
    this.canvas = document.createElement('canvas');
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d', { alpha: false });
    this.dpr = window.devicePixelRatio || 1;

    // History request bookkeeping
    this._pendingRequestId = null;

    // Resize observation
    this._ro = new ResizeObserver(() => this.resize());
    this._ro.observe(this.container);
    this.resize();
  }

  // --- Public API (called by chart-engine.js) -----------------------------
  setSymbol(scrip) {
    const oldKey = this.scrip ? (this.scrip.exch + '|' + this.scrip.token) : null;
    const newKey = scrip.exch + '|' + scrip.token;
    if (oldKey === newKey) return;
    if (this.scrip) this.unsubscribe({ exch: this.scrip.exch, token: this.scrip.token });
    this.scrip = scrip;
    this._resetData();
    this._loadHistory();
  }

  setTimeframe(minutes) {
    if (minutes === this.timeframeMinutes) return;
    this.timeframeMinutes = minutes;
    this._resetData();
    if (this.scrip) this._loadHistory();
  }

  setPalette(palette) {
    this.palette = palette;
    this.scheduleRedraw();
  }

  setOverlays(flags) {
    if (typeof flags.gridlines === 'boolean') this.overlays.gridlines = flags.gridlines;
    if (typeof flags.volume === 'boolean') this.overlays.volume = flags.volume;
    this.scheduleRedraw();
  }

  ingestTick(packet) {
    // Filled in Group D.
  }

  onHistoryResult(requestId, candles) {
    // Filled in Group C.
  }

  onHistoryError(requestId, message) {
    // Filled in Group H.
  }

  destroy() {
    if (this.scrip) this.unsubscribe({ exch: this.scrip.exch, token: this.scrip.token });
    this._ro.disconnect();
    this.container.removeChild(this.canvas);
  }

  // --- Internal helpers ---------------------------------------------------
  _resetData() {
    this.candles = [];
    this.tickState = { lp: null, v: null, ft: null };
    this.aggState = { prevCumVol: null, prevPrice: null, prevMs: null };
    this.view.priceCenter = null;
    this.view.pricePerPx = null;
    this.view.offsetX = 0;
    this.view.autoFollow = true;
    this.view.autoFitY = true;
  }

  _loadHistory() {
    // Filled in Group C.
  }

  resize() {
    const w = this.container.clientWidth;
    const h = this.container.clientHeight;
    if (w === 0 || h === 0) return;
    this.dpr = window.devicePixelRatio || 1;
    this.canvas.width = Math.floor(w * this.dpr);
    this.canvas.height = Math.floor(h * this.dpr);
    this.canvas.style.width = w + 'px';
    this.canvas.style.height = h + 'px';
    this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    this.scheduleRedraw();
  }

  scheduleRedraw() {
    if (this._frame) return;
    this._frame = requestAnimationFrame(() => {
      this._frame = null;
      this.draw();
    });
  }

  draw() {
    // Filled progressively in Groups C → F.
    const w = this.canvas.clientWidth;
    const h = this.canvas.clientHeight;
    this.ctx.fillStyle = this.palette.bg;
    this.ctx.fillRect(0, 0, w, h);
  }
}
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output (success).

---

### Task A6: Create `web/chart-engine/aggregator.js` — stub

This file exists only so `index.html`'s script tag resolves. Group B fills it out.

**Files:**
- Create: `web/chart-engine/aggregator.js`

- [ ] **Step 1: Write the file**

```javascript
'use strict';
// Aggregator — implemented in Group B.
function bucketCandles() { return []; }
function ingestTickIntoBucket() { return 'skipped'; }
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/aggregator.js`
Expected: no output.

---

### Task A7: Create `lib/screens/web/chart_engine/state/chart_engine_store.dart`

**Files:**
- Create: `lib/screens/web/chart_engine/state/chart_engine_store.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolved scrip pushed to the chart engine when the user picks a symbol.
class ChartScrip {
  final String exch;
  final String token;
  final String tsym;
  final String dispName;
  final int ls;
  final double ti;
  const ChartScrip({
    required this.exch,
    required this.token,
    required this.tsym,
    required this.dispName,
    required this.ls,
    required this.ti,
  });

  Map<String, dynamic> toJson() => {
        'exch': exch,
        'token': token,
        'tsym': tsym,
        'dispName': dispName,
        'ls': ls,
        'ti': ti,
      };
}

/// User-toggleable chart overlays for a pane. All default to on.
class ChartOverlays {
  final bool gridlines;
  final bool volume;
  const ChartOverlays({this.gridlines = true, this.volume = true});

  ChartOverlays copyWith({bool? gridlines, bool? volume}) => ChartOverlays(
        gridlines: gridlines ?? this.gridlines,
        volume: volume ?? this.volume,
      );

  Map<String, dynamic> toJson() =>
      {'gridlines': gridlines, 'volume': volume};
}

/// Per-pane state for Phase 1. Only one pane ('main') is used; the model
/// already accommodates multiple panes so Phase 2 doesn't need a rewrite.
class PaneState {
  final ChartScrip? scrip;
  final int timeframeMinutes;
  final ChartOverlays overlays;
  const PaneState({
    this.scrip,
    this.timeframeMinutes = 1,
    this.overlays = const ChartOverlays(),
  });

  PaneState copyWith({
    Object? scrip = _sentinel,
    int? timeframeMinutes,
    ChartOverlays? overlays,
  }) =>
      PaneState(
        scrip: identical(scrip, _sentinel) ? this.scrip : scrip as ChartScrip?,
        timeframeMinutes: timeframeMinutes ?? this.timeframeMinutes,
        overlays: overlays ?? this.overlays,
      );
}

const Object _sentinel = Object();

/// Full chart-engine session state. Phase 1: panes is always
/// {'main': PaneState(...)}. Phase 2 grows the map and adds a layout enum.
class ChartEngineSession {
  final Map<String, PaneState> panes;
  const ChartEngineSession({this.panes = const {'main': PaneState()}});

  PaneState get main => panes['main']!;

  ChartEngineSession copyWithPane(String paneId, PaneState next) {
    final m = Map<String, PaneState>.from(panes);
    m[paneId] = next;
    return ChartEngineSession(panes: m);
  }
}

class ChartEngineSessionNotifier extends Notifier<ChartEngineSession> {
  @override
  ChartEngineSession build() => const ChartEngineSession();

  void setPaneSymbol(String paneId, ChartScrip scrip) {
    final pane = state.panes[paneId];
    if (pane == null) return;
    state = state.copyWithPane(paneId, pane.copyWith(scrip: scrip));
  }

  void setPaneTimeframe(String paneId, int minutes) {
    final pane = state.panes[paneId];
    if (pane == null) return;
    state = state.copyWithPane(paneId, pane.copyWith(timeframeMinutes: minutes));
  }

  void setPaneOverlays(String paneId, ChartOverlays overlays) {
    final pane = state.panes[paneId];
    if (pane == null) return;
    state = state.copyWithPane(paneId, pane.copyWith(overlays: overlays));
  }
}

final chartEngineSessionProvider =
    NotifierProvider<ChartEngineSessionNotifier, ChartEngineSession>(
  ChartEngineSessionNotifier.new,
);
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/state/chart_engine_store.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task A8: Create `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart`

Pure helpers for encoding postMessage payloads + a stub WS forwarder we'll fill out in Group D.

**Files:**
- Create: `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart`

- [ ] **Step 1: Write the file**

```dart
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Pure encoders for the messages the shell posts into the iframe.
/// Keeping these as functions (not methods) makes them easy to unit-test
/// independently of the shell's `dart:html` host code.
String encodeSetTheme(String theme) =>
    jsonEncode({'type': 'setTheme', 'value': theme});

String encodeSetPaneSymbol(String paneId, Map<String, dynamic> scrip) =>
    jsonEncode({'type': 'setPaneSymbol', 'value': {'paneId': paneId, 'scrip': scrip}});

String encodeSetPaneTimeframe(String paneId, int minutes) =>
    jsonEncode({'type': 'setPaneTimeframe', 'value': {'paneId': paneId, 'minutes': minutes}});

String encodeSetOverlays(String paneId, Map<String, dynamic> overlays) =>
    jsonEncode({'type': 'setOverlays', 'value': {'paneId': paneId, ...overlays}});

String encodeHistoryResult(String requestId, List<Map<String, dynamic>> candles) =>
    jsonEncode({'type': 'historyResult', 'value': {'requestId': requestId, 'candles': candles}});

String encodeHistoryError(String requestId, String message) =>
    jsonEncode({'type': 'historyError', 'value': {'requestId': requestId, 'message': message}});

String encodeTick(String token, Map<String, dynamic> packet) =>
    jsonEncode({'type': 'tick', 'value': {'token': token, 'packet': packet}});

/// Decode a message from the iframe. Returns null if the payload isn't a
/// recognizable `{type, value}` object. Accepts both JSON strings and Maps.
Map<String, dynamic>? decodeIframeMessage(Object? raw) {
  if (raw is String) {
    try {
      final d = jsonDecode(raw);
      if (d is Map && d['type'] is String) return Map<String, dynamic>.from(d);
    } catch (_) { /* not JSON */ }
  }
  if (raw is Map && raw['type'] is String) return Map<String, dynamic>.from(raw);
  return null;
}

/// Post a JSON-string message to an iframe's contentWindow.
void postToIframe(html.IFrameElement iframe, String payload) {
  iframe.contentWindow?.postMessage(payload, '*');
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/utils/chart_engine_bridge.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task A9: Create `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` — placeholder

Placeholder for Group A; the real pickers come in Group C / G.

**Files:**
- Create: `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// Placeholder top bar for Phase 1 Group A. Replaced in Group C / G with
/// the real symbol type-ahead + timeframe picker + settings popup.
class ChartEngineTopBar extends StatelessWidget {
  const ChartEngineTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
      ),
      child: Text('Chart Engine (Phase 1 Group A — handshake only)',
          style: MyntWebTextStyles.body(context)),
    );
  }
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task A10: Create `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

This is THE host. Same remount-safe pattern as `orderflow_shell_screen.dart` — unique viewType per state instance, pointer-events fix, focus on load, JSON-string postMessage.

**Files:**
- Create: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Write the file**

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';
import 'package:mynt_plus/screens/web/chart_engine/utils/chart_engine_bridge.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/chart_engine_top_bar.dart';

/// Full-page Chart Engine shell. Hosts the iframe at
/// `/chart-engine/index.html` and bridges Flutter state ↔ iframe via
/// postMessage. Mirrors the proven patterns from `OrderflowShellScreen`.
class ChartEngineShellScreen extends ConsumerStatefulWidget {
  const ChartEngineShellScreen({super.key});

  @override
  ConsumerState<ChartEngineShellScreen> createState() =>
      _ChartEngineShellScreenState();
}

class _ChartEngineShellScreenState
    extends ConsumerState<ChartEngineShellScreen> {
  // Unique per state instance — critical for remount safety. Reusing a
  // static viewType across instances pins the factory closure to the first
  // (disposed) state and leaves new mounts wired to dead state.
  late final String _viewType;
  late final String _iframeId;
  html.IFrameElement? _iframe;
  bool _iframeReady = false;
  String? _pushedTheme;
  // Remember what we last pushed per pane so we don't spam postMessage
  // when other store fields change.
  String? _pushedSymbolKey;
  int? _pushedTimeframe;
  String? _pushedOverlaysJson;

  @override
  void initState() {
    super.initState();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    _iframeId = 'chart-engine-iframe-$stamp';
    _viewType = 'chart-engine-view-$stamp';
    _registerFactory();
    html.window.addEventListener('message', _onWindowMessage);
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _onWindowMessage);
    super.dispose();
  }

  void _registerFactory() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final el = html.IFrameElement()
        ..id = _iframeId
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#0B0F14'
        ..allow = 'autoplay'
        ..src = '/chart-engine/index.html?theme=${_currentThemeName()}';
      el.style.setProperty('pointer-events', 'auto', 'important');
      el.onLoad.first.then((_) {
        try { el.focus(); } catch (_) {}
      });
      _iframe = el;
      return el;
    });
  }

  String _currentThemeName() =>
      ref.read(themeProvider).isDarkMode ? 'dark' : 'light';

  void _onWindowMessage(html.Event event) {
    if (event is! html.MessageEvent) return;
    final msg = decodeIframeMessage(event.data);
    if (msg == null) return;
    switch (msg['type']) {
      case 'chart-engine-ready':
        _iframeReady = true;
        _pushAll(force: true);
        break;
      case 'fetchHistory':
        // Filled in Group C.
        break;
      case 'subscribe':
        // Filled in Group D.
        break;
      case 'unsubscribe':
        // Filled in Group D.
        break;
    }
  }

  void _pushAll({bool force = false}) {
    _pushTheme(force: force);
    _pushPane(force: force);
  }

  void _pushTheme({bool force = false}) {
    if (!_iframeReady) return;
    final theme = _currentThemeName();
    if (!force && theme == _pushedTheme) return;
    _pushedTheme = theme;
    _post(encodeSetTheme(theme));
  }

  void _pushPane({bool force = false}) {
    if (!_iframeReady) return;
    final pane = ref.read(chartEngineSessionProvider).main;
    if (pane.scrip != null) {
      final key = '${pane.scrip!.exch}|${pane.scrip!.token}';
      if (force || key != _pushedSymbolKey) {
        _pushedSymbolKey = key;
        _post(encodeSetPaneSymbol('main', pane.scrip!.toJson()));
      }
    }
    if (force || pane.timeframeMinutes != _pushedTimeframe) {
      _pushedTimeframe = pane.timeframeMinutes;
      _post(encodeSetPaneTimeframe('main', pane.timeframeMinutes));
    }
    final overlaysJson = jsonEncode(pane.overlays.toJson());
    if (force || overlaysJson != _pushedOverlaysJson) {
      _pushedOverlaysJson = overlaysJson;
      _post(encodeSetOverlays('main', pane.overlays.toJson()));
    }
  }

  void _post(String payload) {
    final el = html.document.getElementById(_iframeId);
    if (el is html.IFrameElement) {
      postToIframe(el, payload);
      return;
    }
    if (_iframe != null) postToIframe(_iframe!, payload);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    ref.watch(chartEngineSessionProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushAll());
    final bg = ref.read(themeProvider).isDarkMode
        ? const Color(0xFF0B0F14)
        : const Color(0xFFFFFFFF);
    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ChartEngineTopBar(),
          Expanded(child: HtmlElementView(viewType: _viewType)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -10`
Expected: `No issues found!`

---

### Task A11: Wire routing + drawer (multi-file)

**Files:**
- Modify: `lib/routes/web_router.dart`
- Modify: `lib/screens/web/home/models/screen_type.dart`
- Modify: `lib/screens/web/customizable_split_home_screen.dart` (the duplicate `ScreenType` near line 5597, plus `ScreenTypeParam`, plus a `_handleChartsTap`, plus the render switch case, plus the label case, plus the URL case)
- Modify: `lib/screens/web/home/utils/screen_utils.dart`
- Modify: `lib/screens/web/home/widgets/panels/panel_content_builder.dart`
- Modify: `lib/screens/web/window_based_home_screen.dart`
- Modify: `lib/screens/web/home/widgets/app_bar/navigation_drawer_web.dart`

- [ ] **Step 1: Add the route constant in `lib/routes/web_router.dart`**

Find the `WebRoutes` class and add after the `orderflow` constant:

```dart
static const String charts = '/charts';
```

- [ ] **Step 2: Add the `GoRoute` for `/charts`**

Find the `GoRoute` for `WebRoutes.orderflow` (around line 334) and add immediately after it:

```dart
// Multi-chart application
GoRoute(
  path: WebRoutes.charts,
  builder: (context, state) => const CustomizableSplitHomeScreen(
    initialRightPanel: ScreenTypeParam.charts,
  ),
),
```

- [ ] **Step 3: Add `charts` to `lib/screens/web/home/models/screen_type.dart`**

Find the `ScreenType` enum and add `charts` after `orderflow`.

- [ ] **Step 4: Add `charts` to the duplicate `ScreenType` enum in `customizable_split_home_screen.dart`**

Search for the SECOND `enum ScreenType` declaration in that file (the duplicate around line 5597). Add `charts` after `orderflow` to BOTH the top-of-file enum import re-export AND this duplicate.

- [ ] **Step 5: Add `charts` to `ScreenTypeParam` enum**

In the same file, find `enum ScreenTypeParam` and add `charts`.

- [ ] **Step 6: Add `_handleChartsTap`**

Find `_handleOrderflowTap` (around line 2205) and add right after it:

```dart
void _handleChartsTap() {
  _replaceScreenInPanel(ScreenType.charts);
  WebNavigationHelper.updateUrl(WebRoutes.charts);
}
```

- [ ] **Step 7: Add render case + label case + URL case in `customizable_split_home_screen.dart`**

Find the `ScreenType.orderflow` render case (around line 3037) and add immediately after:

```dart
case ScreenType.charts:
  return const ChartEngineShellScreen();
```

Find the label case (around line 3152) and add:

```dart
case ScreenType.charts:
  return 'Charts';
```

Find the URL case (around line 4595) and add:

```dart
case ScreenType.charts:
  urlPath = WebRoutes.charts;
  break;
```

Find any other `case ScreenType.orderflow:` in the same file and add a sibling `case ScreenType.charts:` if the switch is exhaustive (Dart will warn at analyze time if you miss one — fix until clean).

Also add at the top of the file:

```dart
import 'chart_engine/chart_engine_shell_screen.dart';
```

- [ ] **Step 8: Handle ScreenTypeParam**

Find `ScreenTypeParam.orderflow` (around line 738) and add the parallel case for `charts`:

```dart
case ScreenTypeParam.charts:
  _replaceScreenInPanel(ScreenType.charts);
```

- [ ] **Step 9: Add `charts` case in `panel_content_builder.dart`**

Add import:

```dart
import 'package:mynt_plus/screens/web/chart_engine/chart_engine_shell_screen.dart';
```

In the build switch, after `case ScreenType.orderflow:`:

```dart
case ScreenType.charts:
  return const ChartEngineShellScreen();
```

- [ ] **Step 10: Add `charts` case in `screen_utils.dart` switches**

Open `lib/screens/web/home/utils/screen_utils.dart`. Anywhere there's a switch on `ScreenType` that covers `orderflow`, add a parallel `charts` case (typically just returning a label string or icon — mirror what `orderflow` does).

- [ ] **Step 11: Add `charts` case in `window_based_home_screen.dart`**

Same idea: wherever `ScreenType.orderflow` appears, add a parallel `ScreenType.charts` arm.

- [ ] **Step 12: Add drawer entry**

Open `lib/screens/web/home/widgets/app_bar/navigation_drawer_web.dart`. The user may have stashed prior changes that included an Orderflow drawer entry — if absent now, re-add Orderflow AND Charts together. Otherwise just add Charts after Orderflow.

Add a `final VoidCallback? onChartsTap;` field and `this.onChartsTap` constructor param + `final bool? showCharts;` field and `this.showCharts` constructor param.

Extend the TRADE-section visibility guard to include `(showCharts ?? (onChartsTap != null))`.

Insert after the Orderflow drawer item:

```dart
if ((showCharts ?? (onChartsTap != null)) && onChartsTap != null)
  _buildDrawerItem(
    context: context,
    title: 'Charts',
    icon: shadcn.LucideIcons.lineChart,
    screenName: 'charts',
    onTap: onChartsTap!,
  ),
```

- [ ] **Step 13: Wire `onChartsTap` in the drawer construction**

In `customizable_split_home_screen.dart`, find the `NavigationDrawerWeb(...)` constructor call (around line 1500-1560) and add inside it:

```dart
onChartsTap: () {
  shadcn.closeDrawer(drawerContext);
  _handleChartsTap();
},
```

- [ ] **Step 14: Static check**

Run: `flutter analyze lib/screens/web/chart_engine lib/screens/web/customizable_split_home_screen.dart lib/screens/web/home/widgets/app_bar/navigation_drawer_web.dart lib/routes/web_router.dart 2>&1 | tail -10`
Expected: `No issues found!`. Fix any "case missing" warnings by adding the parallel `charts` case to whichever switch the analyzer points to.

---

### Smoke Checkpoint — Group A

- [ ] Run `flutter run -d chrome --web-port 8080`.
- [ ] In the browser, open `http://localhost:8080/#/charts` (or click Charts in the drawer).
- [ ] **Expected:** the right panel shows the placeholder top bar text and an iframe area filled with the chart background colour (dark or light per app theme).
- [ ] **Open DevTools console.** Verify a `chart-engine-ready` event arrives (you'll see no log by default — to verify, temporarily add `console.log('ready', d)` inside `handleMessage` in `chart-engine.js`. Remove the log after confirming.)
- [ ] Toggle the app theme. The iframe background colour switches (the body bg follows `--bg`).
- [ ] Navigate to /home then back to /charts. Iframe re-mounts cleanly (no white screen, no errors in console).

---

# Group B — Aggregator + unit tests

End-state: `node web/chart-engine/aggregator.test.js` exits 0 with green output.

---

### Task B1: Implement `web/chart-engine/aggregator.js`

**Files:**
- Modify: `web/chart-engine/aggregator.js` (replace the stub)

- [ ] **Step 1: Replace the file contents**

```javascript
'use strict';

// ---------------------------------------------------------------------------
// Aggregator — pure functions for rolling source candles + live ticks into
// target-timeframe candles.
//
// Source intervals expected from tpseries:
//   '1'  → 1-minute candles (used for any target < 60 minutes)
//   '5'  → 5-minute candles (used for 60 ≤ target < 1440 minutes)
//   '1D' → daily candles    (used for target ≥ 1440 minutes)
//
// Target minutes is whatever integer the user picked, including custom
// values like 7m, 45m, 90m.
// ---------------------------------------------------------------------------

const SOURCE_INTERVAL_FOR_MINUTES = (mins) => {
  if (mins < 60) return '1';
  if (mins < 1440) return '5';
  return '1D';
};

/**
 * Bucket source candles into target candles.
 * @param {Array<{ts:number,o:number,h:number,l:number,c:number,v:number}>} src
 *        Source candles in chronological order. `ts` is unix epoch SECONDS.
 * @param {number} targetMinutes
 * @returns {Array<{ts:number,o:number,h:number,l:number,c:number,v:number}>}
 *        Target candles in chronological order. `ts` is the bucket start
 *        unix epoch seconds.
 */
function bucketCandles(src, targetMinutes) {
  if (!Array.isArray(src) || src.length === 0) return [];
  // Daily, weekly, monthly use calendar-aware bucketing (IST). Everything
  // else uses modular bucketing on the second.
  if (targetMinutes >= 1440) {
    return _bucketCalendar(src, targetMinutes);
  }
  const targetSec = targetMinutes * 60;
  const out = [];
  let cur = null;
  for (const c of src) {
    const bucket = c.ts - (c.ts % targetSec);
    if (!cur || cur.ts !== bucket) {
      if (cur) out.push(cur);
      cur = { ts: bucket, o: c.o, h: c.h, l: c.l, c: c.c, v: c.v };
    } else {
      if (c.h > cur.h) cur.h = c.h;
      if (c.l < cur.l) cur.l = c.l;
      cur.c = c.c;
      cur.v += c.v;
    }
  }
  if (cur) out.push(cur);
  return out;
}

function _bucketCalendar(src, targetMinutes) {
  // 1440 = daily, 10080 = weekly (7d), 43200 = monthly (~30d).
  // For weekly we anchor to Monday in IST. For monthly we anchor to the
  // 1st of the month in IST.
  if (targetMinutes === 1440) {
    // Daily — assume source is 1D from tpseries; passthrough.
    return src.map((c) => ({ ts: c.ts, o: c.o, h: c.h, l: c.l, c: c.c, v: c.v }));
  }
  const out = [];
  let cur = null;
  for (const c of src) {
    const bucket = (targetMinutes === 10080)
      ? _weekStartIst(c.ts)
      : (targetMinutes === 43200)
        ? _monthStartIst(c.ts)
        : c.ts - (c.ts % (targetMinutes * 60));
    if (!cur || cur.ts !== bucket) {
      if (cur) out.push(cur);
      cur = { ts: bucket, o: c.o, h: c.h, l: c.l, c: c.c, v: c.v };
    } else {
      if (c.h > cur.h) cur.h = c.h;
      if (c.l < cur.l) cur.l = c.l;
      cur.c = c.c;
      cur.v += c.v;
    }
  }
  if (cur) out.push(cur);
  return out;
}

// IST = UTC+05:30 = +19800 seconds.
const IST_OFFSET = 5.5 * 3600;
function _weekStartIst(ts) {
  // Convert to IST, find Monday, convert back to UTC seconds.
  const istSec = ts + IST_OFFSET;
  const d = new Date(istSec * 1000);
  // getUTCDay: 0=Sun … 6=Sat. We want Monday=0, so daysSinceMonday = (day+6)%7.
  const daysSinceMonday = (d.getUTCDay() + 6) % 7;
  const istMidnight = istSec - (d.getUTCHours() * 3600 + d.getUTCMinutes() * 60 + d.getUTCSeconds());
  const istMondayMidnight = istMidnight - daysSinceMonday * 86400;
  return istMondayMidnight - IST_OFFSET;
}
function _monthStartIst(ts) {
  const istSec = ts + IST_OFFSET;
  const d = new Date(istSec * 1000);
  const istMonthStart = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1) / 1000;
  return istMonthStart - IST_OFFSET;
}

/**
 * Apply a live tick to the last candle of `candles`, or append a new candle
 * if the tick falls in the next bucket.
 *
 * Mutates `candles` and `aggState`. Returns:
 *   'applied'  — tick was integrated into a candle
 *   'skipped'  — tick was dropped (late delivery / out-of-order ft / dv<=0 / dv too large)
 *   'primed'   — first tick; baseline set without producing a trade
 *
 * tick = { lp:number, v:number (cum), ft:number (epoch seconds) }
 * targetMs = target candle width in milliseconds
 */
function ingestTickIntoBucket(candles, tick, aggState, targetMs) {
  if (tick.lp == null || tick.v == null || tick.ft == null) return 'skipped';
  const raw = +tick.lp;
  const cumVol = +tick.v;
  const tickMs = +tick.ft * 1000;

  if (aggState.prevCumVol == null) {
    aggState.prevCumVol = cumVol;
    aggState.prevPrice = raw;
    aggState.prevMs = tickMs;
    return 'primed';
  }
  const dv = cumVol - aggState.prevCumVol;
  if (dv <= 0) return 'skipped';        // late delivery — don't touch aggState
  if (dv > 50000) {                     // huge jump — reset baseline
    aggState.prevCumVol = cumVol;
    aggState.prevPrice = raw;
    aggState.prevMs = tickMs;
    return 'skipped';
  }

  const bucketSec = Math.floor(tickMs / targetMs) * (targetMs / 1000);
  let c = candles.length ? candles[candles.length - 1] : null;
  if (c && bucketSec < c.ts) return 'skipped';   // out-of-order ft — drop
  if (!c || bucketSec > c.ts) {
    c = { ts: bucketSec, o: raw, h: raw, l: raw, c: raw, v: 0 };
    candles.push(c);
  }
  c.c = raw;
  if (raw > c.h) c.h = raw;
  if (raw < c.l) c.l = raw;
  c.v += dv;

  aggState.prevCumVol = cumVol;
  aggState.prevPrice = raw;
  aggState.prevMs = tickMs;
  return 'applied';
}

// Expose for browser global scope (no module system in iframe).
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { bucketCandles, ingestTickIntoBucket, SOURCE_INTERVAL_FOR_MINUTES };
}
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/aggregator.js`
Expected: no output.

---

### Task B2: Write `web/chart-engine/aggregator.test.js`

**Files:**
- Create: `web/chart-engine/aggregator.test.js`

- [ ] **Step 1: Write the file**

```javascript
'use strict';

const assert = require('assert');
const { bucketCandles, ingestTickIntoBucket, SOURCE_INTERVAL_FOR_MINUTES } =
    require('./aggregator');

let pass = 0, fail = 0;
function t(name, fn) {
  try { fn(); console.log('  ✓', name); pass++; }
  catch (e) { console.log('  ✗', name, '\n    ', e.message); fail++; }
}

console.log('SOURCE_INTERVAL_FOR_MINUTES');
t('returns "1" for <60', () => assert.strictEqual(SOURCE_INTERVAL_FOR_MINUTES(1), '1'));
t('returns "1" for 30',  () => assert.strictEqual(SOURCE_INTERVAL_FOR_MINUTES(30), '1'));
t('returns "5" for 60',  () => assert.strictEqual(SOURCE_INTERVAL_FOR_MINUTES(60), '5'));
t('returns "5" for 240', () => assert.strictEqual(SOURCE_INTERVAL_FOR_MINUTES(240), '5'));
t('returns "1D" for 1440', () => assert.strictEqual(SOURCE_INTERVAL_FOR_MINUTES(1440), '1D'));

console.log('bucketCandles');
t('empty input → empty output', () => {
  assert.deepStrictEqual(bucketCandles([], 5), []);
});

t('rolls 5x 1m into 1x 5m', () => {
  const src = [
    { ts: 0,   o: 100, h: 102, l: 99,  c: 101, v: 10 },
    { ts: 60,  o: 101, h: 103, l: 100, c: 102, v: 20 },
    { ts: 120, o: 102, h: 105, l: 101, c: 104, v: 30 },
    { ts: 180, o: 104, h: 106, l: 103, c: 105, v: 40 },
    { ts: 240, o: 105, h: 107, l: 102, c: 106, v: 50 },
  ];
  const out = bucketCandles(src, 5);
  assert.strictEqual(out.length, 1);
  assert.deepStrictEqual(out[0], { ts: 0, o: 100, h: 107, l: 99, c: 106, v: 150 });
});

t('starts new bucket at boundary', () => {
  const src = [
    { ts: 0,   o: 100, h: 100, l: 100, c: 100, v: 1 },
    { ts: 300, o: 200, h: 200, l: 200, c: 200, v: 2 },
  ];
  const out = bucketCandles(src, 5);
  assert.strictEqual(out.length, 2);
  assert.strictEqual(out[0].ts, 0);
  assert.strictEqual(out[1].ts, 300);
});

t('passes daily through unchanged', () => {
  const src = [
    { ts: 86400, o: 1, h: 2, l: 0, c: 1, v: 10 },
    { ts: 172800, o: 1, h: 2, l: 0, c: 1, v: 20 },
  ];
  assert.deepStrictEqual(bucketCandles(src, 1440), src);
});

console.log('ingestTickIntoBucket');
t('primes on first tick', () => {
  const candles = [];
  const state = { prevCumVol: null, prevPrice: null, prevMs: null };
  const r = ingestTickIntoBucket(candles, { lp: 100, v: 1000, ft: 60 }, state, 60_000);
  assert.strictEqual(r, 'primed');
  assert.strictEqual(candles.length, 0);
  assert.strictEqual(state.prevCumVol, 1000);
});

t('applies a normal tick', () => {
  const candles = [];
  const state = { prevCumVol: 1000, prevPrice: 100, prevMs: 60_000 };
  const r = ingestTickIntoBucket(candles, { lp: 101, v: 1050, ft: 61 }, state, 60_000);
  assert.strictEqual(r, 'applied');
  assert.strictEqual(candles.length, 1);
  assert.strictEqual(candles[0].v, 50);
  assert.strictEqual(candles[0].c, 101);
});

t('appends new candle when crossing bucket boundary', () => {
  const candles = [{ ts: 60, o: 100, h: 100, l: 100, c: 100, v: 10 }];
  const state = { prevCumVol: 1000, prevPrice: 100, prevMs: 60_000 };
  const r = ingestTickIntoBucket(candles, { lp: 102, v: 1050, ft: 121 }, state, 60_000);
  assert.strictEqual(r, 'applied');
  assert.strictEqual(candles.length, 2);
  assert.strictEqual(candles[1].ts, 120);
});

t('drops late tick (dv <= 0) without touching aggState', () => {
  const candles = [{ ts: 60, o: 100, h: 100, l: 100, c: 100, v: 10 }];
  const state = { prevCumVol: 1050, prevPrice: 101, prevMs: 90_000 };
  const r = ingestTickIntoBucket(candles, { lp: 100, v: 1000, ft: 80 }, state, 60_000);
  assert.strictEqual(r, 'skipped');
  assert.strictEqual(state.prevCumVol, 1050); // unchanged
});

t('drops tick into past bucket without polluting current candle', () => {
  const candles = [{ ts: 120, o: 100, h: 100, l: 100, c: 100, v: 5 }];
  const state = { prevCumVol: 1050, prevPrice: 100, prevMs: 121_000 };
  const r = ingestTickIntoBucket(candles, { lp: 99, v: 1100, ft: 60 }, state, 60_000);
  assert.strictEqual(r, 'skipped');
  assert.strictEqual(candles[0].l, 100);   // unchanged
  assert.strictEqual(candles[0].v, 5);     // unchanged
});

t('resets baseline on huge jump (dv > 50k) without applying', () => {
  const candles = [{ ts: 60, o: 100, h: 100, l: 100, c: 100, v: 10 }];
  const state = { prevCumVol: 1000, prevPrice: 100, prevMs: 60_000 };
  const r = ingestTickIntoBucket(candles, { lp: 200, v: 99999, ft: 90 }, state, 60_000);
  assert.strictEqual(r, 'skipped');
  assert.strictEqual(state.prevCumVol, 99999); // baseline reset
  assert.strictEqual(candles[0].v, 10);        // candle unchanged
});

console.log();
console.log(`${pass} passed · ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
```

- [ ] **Step 2: Run the tests**

Run: `node web/chart-engine/aggregator.test.js`
Expected: all green, `N passed · 0 failed`, exit 0.

---

# Group C — Symbol picker + history fetch + first paint

End-state: type-ahead picks a symbol → iframe asks Flutter for history → Flutter calls `getTPSeriesChart` → iframe aggregates and draws candles.

---

### Task C1: Build `lib/screens/web/chart_engine/widgets/symbol_type_ahead.dart`

**Files:**
- Create: `lib/screens/web/chart_engine/widgets/symbol_type_ahead.dart`

- [ ] **Step 1: Write the file**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/marketwatch_model/search_scrip_new_model.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';

/// Debounced inline symbol search. Uses
/// `searchScripForStrategyBuilder` (proper jsonEncoded `fil:["NSE"]`) and
/// shows results in an Overlay anchored to the field. PointerInterceptor
/// + onPopupVisibilityChanged keeps the popup clickable above the chart
/// iframe — same gating pattern proven in OrderflowTopBar.
class SymbolTypeAhead extends StatefulWidget {
  final ChartScrip? current;
  final ValueChanged<ChartScrip> onPicked;
  final ValueChanged<bool> onPopupVisibilityChanged;
  const SymbolTypeAhead({
    super.key,
    required this.current,
    required this.onPicked,
    required this.onPopupVisibilityChanged,
  });

  @override
  State<SymbolTypeAhead> createState() => _SymbolTypeAheadState();
}

class _SymbolTypeAheadState extends State<SymbolTypeAhead> {
  final LayerLink _link = LayerLink();
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  OverlayEntry? _entry;
  Timer? _debounce;
  List<ScripNewValue> _results = const [];
  bool _loading = false;

  static const _exchanges = ['NSE', 'BSE', 'NFO', 'BFO', 'MCX', 'CDS'];

  @override
  void initState() {
    super.initState();
    _ctl.text = widget.current?.dispName ?? '';
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant SymbolTypeAhead old) {
    super.didUpdateWidget(old);
    if (widget.current != old.current && !_focus.hasFocus) {
      _ctl.text = widget.current?.dispName ?? '';
    }
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _openDropdown();
      _ctl.selection =
          TextSelection(baseOffset: 0, extentOffset: _ctl.text.length);
    } else {
      // Defer close so a tap on a result lands first.
      Future.delayed(const Duration(milliseconds: 100), _closeDropdown);
    }
  }

  void _openDropdown() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
  }

  void _closeDropdown() {
    _entry?.remove();
    _entry = null;
    widget.onPopupVisibilityChanged(true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctl.dispose();
    if (_entry != null) {
      _entry!.remove();
      widget.onPopupVisibilityChanged(true);
    }
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() { _results = const []; _loading = false; });
      _entry?.markNeedsBuild();
      return;
    }
    setState(() { _loading = true; });
    _entry?.markNeedsBuild();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final resp = await locator<ApiExporter>().searchScripForStrategyBuilder(
          searchText: text.trim(),
          exchanges: _exchanges,
        );
        if (!mounted) return;
        setState(() {
          _results = resp.values ?? const [];
          _loading = false;
        });
        _entry?.markNeedsBuild();
      } catch (_) {
        if (!mounted) return;
        setState(() { _results = const []; _loading = false; });
        _entry?.markNeedsBuild();
      }
    });
  }

  void _pick(ScripNewValue v) {
    final scrip = ChartScrip(
      exch: v.exch ?? 'NSE',
      token: v.token ?? '',
      tsym: v.tsym ?? '',
      dispName: v.dname ?? v.tsym ?? v.symbol ?? '',
      ls: int.tryParse(v.ls ?? '') ?? 1,
      ti: double.tryParse(v.ti ?? '') ?? 0.05,
    );
    widget.onPicked(scrip);
    _ctl.text = scrip.dispName;
    _focus.unfocus();
    _closeDropdown();
  }

  Widget _buildOverlay(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final hover = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return Positioned(
      width: 320,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: const Offset(0, 38),
        child: PointerInterceptor(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 380),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  : (_results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _ctl.text.trim().length < 2
                                ? 'Type at least 2 characters to search'
                                : 'No matches',
                            style: MyntWebTextStyles.caption(context),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final r = _results[i];
                            return InkWell(
                              onTap: () => _pick(r),
                              hoverColor: hover,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(r.dname ?? r.tsym ?? '',
                                            style: MyntWebTextStyles.body(context,
                                                fontWeight: MyntFonts.semiBold)),
                                        const SizedBox(height: 2),
                                        Text(
                                            '${r.exch ?? ''} · ${r.instname ?? ''}',
                                            style: MyntWebTextStyles.caption(context)),
                                      ],
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          },
                        )),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    return CompositedTransformTarget(
      link: _link,
      child: SizedBox(
        width: 220,
        child: TextField(
          controller: _ctl,
          focusNode: _focus,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search symbol…',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: border),
            ),
          ),
          style: MyntWebTextStyles.body(context),
          onChanged: _onChanged,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/widgets/symbol_type_ahead.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task C2: Build `lib/screens/web/chart_engine/widgets/timeframe_picker.dart`

**Files:**
- Create: `lib/screens/web/chart_engine/widgets/timeframe_picker.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// Preset timeframes (label → minutes). The "Custom…" entry opens a small
/// dialog so users can enter any positive integer minutes value.
const Map<String, int> kPresetTimeframes = {
  '1m': 1,
  '2m': 2,
  '3m': 3,
  '5m': 5,
  '10m': 10,
  '15m': 15,
  '30m': 30,
  '1h': 60,
  '2h': 120,
  '4h': 240,
  '1D': 1440,
  '1W': 10080,
  '1M': 43200,
};

/// Returns the human label for an integer minute count, falling back to
/// "<n>m" / "<n>h" / "<n>D" formats for custom values.
String formatTimeframeLabel(int minutes) {
  for (final e in kPresetTimeframes.entries) {
    if (e.value == minutes) return e.key;
  }
  if (minutes % 1440 == 0) return '${minutes ~/ 1440}D';
  if (minutes % 60 == 0) return '${minutes ~/ 60}h';
  return '${minutes}m';
}

class TimeframePicker extends StatefulWidget {
  final int valueMinutes;
  final ValueChanged<int> onChanged;
  final ValueChanged<bool> onPopupVisibilityChanged;
  const TimeframePicker({
    super.key,
    required this.valueMinutes,
    required this.onChanged,
    required this.onPopupVisibilityChanged,
  });

  @override
  State<TimeframePicker> createState() => _TimeframePickerState();
}

class _TimeframePickerState extends State<TimeframePicker> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _open() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    widget.onPopupVisibilityChanged(true);
  }

  @override
  void dispose() {
    if (_entry != null) {
      _entry!.remove();
      widget.onPopupVisibilityChanged(true);
    }
    super.dispose();
  }

  Future<void> _pickCustom() async {
    _close();
    final ctl = TextEditingController();
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom timeframe'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Minutes (e.g. 7 for 7m, 90 for 90m)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(ctl.text.trim());
              if (n != null && n > 0) Navigator.pop(ctx, n);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (picked != null) widget.onChanged(picked);
  }

  Widget _buildOverlay(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final hover = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
      ),
      Positioned(
        width: 140,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(0, 38),
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
                    for (final e in kPresetTimeframes.entries)
                      InkWell(
                        onTap: () { widget.onChanged(e.value); _close(); },
                        hoverColor: hover,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Row(children: [
                            Expanded(child: Text(e.key, style: MyntWebTextStyles.body(context))),
                            if (e.value == widget.valueMinutes)
                              Icon(shadcn.LucideIcons.check, size: 14,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.primaryDark,
                                      light: MyntColors.primary)),
                          ]),
                        ),
                      ),
                    const Divider(height: 1),
                    InkWell(
                      onTap: _pickCustom,
                      hoverColor: hover,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Text('Custom…',
                            style: MyntWebTextStyles.body(context,
                                fontWeight: MyntFonts.semiBold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    return CompositedTransformTarget(
      link: _link,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _entry == null ? _open() : _close(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(formatTimeframeLabel(widget.valueMinutes),
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold)),
            const SizedBox(width: 6),
            Icon(shadcn.LucideIcons.chevronDown, size: 14),
          ]),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/widgets/timeframe_picker.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task C3: Replace the placeholder top bar with the real one

**Files:**
- Modify: `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` (full rewrite)

- [ ] **Step 1: Replace the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/symbol_type_ahead.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/timeframe_picker.dart';

class ChartEngineTopBar extends ConsumerWidget {
  final ValueChanged<bool> onPopupVisibilityChanged;
  const ChartEngineTopBar({super.key, required this.onPopupVisibilityChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final pane = ref.watch(chartEngineSessionProvider).main;
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Symbol', style: MyntWebTextStyles.caption(context)),
            const SizedBox(width: 8),
            SymbolTypeAhead(
              current: pane.scrip,
              onPicked: (s) => notifier.setPaneSymbol('main', s),
              onPopupVisibilityChanged: onPopupVisibilityChanged,
            ),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Timeframe', style: MyntWebTextStyles.caption(context)),
            const SizedBox(width: 8),
            TimeframePicker(
              valueMinutes: pane.timeframeMinutes,
              onChanged: (m) => notifier.setPaneTimeframe('main', m),
              onPopupVisibilityChanged: onPopupVisibilityChanged,
            ),
          ]),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Wire the top bar's `onPopupVisibilityChanged` into the shell**

In `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`:

Add a method:

```dart
void _setIframePointerEvents(bool enabled) {
  final el = html.document.getElementById(_iframeId);
  if (el is html.IFrameElement) {
    el.style.pointerEvents = enabled ? 'auto' : 'none';
  }
}
```

Replace the `const ChartEngineTopBar()` line in `build` with:

```dart
ChartEngineTopBar(onPopupVisibilityChanged: _setIframePointerEvents),
```

- [ ] **Step 3: Update the iframe ID to include `chart-iframe` substring**

In `_registerFactory`, change the iframe ID line to:

```dart
..id = _iframeId  // already contains "chart-iframe" — see initState
```

And in `initState`, change `_iframeId` assignment to:

```dart
_iframeId = 'chart-engine-chart-iframe-$stamp';
```

This way the existing app-wide `_disableAllChartIframes()` helpers (used by profile dropdown etc.) automatically gate it too.

- [ ] **Step 4: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task C4: Fill in `Chart._loadHistory` + `Chart.onHistoryResult` + `Chart.draw` (history-only)

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add helpers + replace `_loadHistory`, `onHistoryResult`, `draw`**

Edit `chart.js`. At the top of the file (above the `class Chart` declaration), add:

```javascript
function _windowSecondsFor(minutes) {
  // Sensible default windows so the chart starts useful but doesn't
  // overfetch. All in seconds.
  if (minutes < 60) return 5 * 24 * 60 * 60;           // 5 days for intraday <1h
  if (minutes < 1440) return 60 * 24 * 60 * 60;        // 60 days for hourly
  if (minutes === 1440) return 2 * 365 * 24 * 60 * 60; // 2 years for daily
  if (minutes === 10080) return 5 * 365 * 24 * 60 * 60; // 5 years for weekly
  return 20 * 365 * 24 * 60 * 60;                       // 20 years for monthly+
}

function _newRequestId() {
  return 'req_' + Math.random().toString(36).slice(2) + '_' + Date.now();
}
```

Replace `Chart.prototype._loadHistory` (the method body) — i.e. find `_loadHistory() {` inside the class and replace its body with:

```javascript
_loadHistory() {
  if (!this.scrip) return;
  this._showOverlay('Loading ' + this.scrip.dispName + '…');
  const minutes = this.timeframeMinutes;
  const interval = SOURCE_INTERVAL_FOR_MINUTES(minutes);
  const endEpoch = Math.floor(Date.now() / 1000);
  const startEpoch = endEpoch - _windowSecondsFor(minutes);
  this._pendingRequestId = _newRequestId();
  this.requestHistory({
    requestId: this._pendingRequestId,
    exch: this.scrip.exch,
    token: this.scrip.token,
    interval,
    start: startEpoch,
    end: endEpoch,
    targetMinutes: minutes,
  });
}
```

Replace `onHistoryResult` body:

```javascript
onHistoryResult(requestId, candles) {
  if (requestId !== this._pendingRequestId) return; // stale reply
  this._pendingRequestId = null;
  this._hideOverlay();
  if (!Array.isArray(candles) || candles.length === 0) {
    this._showOverlay('No history available');
    return;
  }
  this.candles = bucketCandles(candles, this.timeframeMinutes);
  this.scheduleRedraw();
  if (this.scrip) this.subscribe({ exch: this.scrip.exch, token: this.scrip.token });
}
```

Add `_showOverlay` / `_hideOverlay` helpers in the class:

```javascript
_showOverlay(title, detail) {
  const overlay = document.getElementById('overlay');
  const t = document.getElementById('overlay-title');
  const d = document.getElementById('overlay-detail');
  if (overlay && t) {
    t.textContent = title || '';
    if (d) d.textContent = detail || '';
    overlay.hidden = false;
  }
}
_hideOverlay() {
  const overlay = document.getElementById('overlay');
  if (overlay) overlay.hidden = true;
}
```

Replace `draw()` body with history-only candle drawing:

```javascript
draw() {
  const w = this.canvas.clientWidth;
  const h = this.canvas.clientHeight;
  this.ctx.fillStyle = this.palette.bg;
  this.ctx.fillRect(0, 0, w, h);
  if (this.candles.length === 0) return;

  const plot = { left: 8, top: 8, right: w - 64, bottom: h - 24 };
  plot.width = plot.right - plot.left;
  plot.height = plot.bottom - plot.top;

  // Visible candles (auto-follow always on at this stage).
  const N = this.candles.length;
  const visibleN = Math.min(N, Math.floor(plot.width / this.view.cellW));
  const firstIdx = Math.max(0, N - visibleN);
  const visible = this.candles.slice(firstIdx);

  // Y range from visible candles + 8% padding.
  let lo = Infinity, hi = -Infinity;
  for (const c of visible) { if (c.l < lo) lo = c.l; if (c.h > hi) hi = c.h; }
  if (!isFinite(lo) || !isFinite(hi)) return;
  const pad = (hi - lo) * 0.08 || 1;
  lo -= pad; hi += pad;
  const priceToY = (p) => plot.top + plot.height * (hi - p) / (hi - lo);

  // Candles.
  for (let i = 0; i < visible.length; i++) {
    const c = visible[i];
    const xCenter = plot.right - (visible.length - i - 0.5) * this.view.cellW;
    const isBull = c.c >= c.o;
    const color = isBull ? this.palette.bull : this.palette.bear;
    // Wick
    this.ctx.fillStyle = color;
    this.ctx.fillRect(Math.round(xCenter), priceToY(c.h), 1, priceToY(c.l) - priceToY(c.h));
    // Body
    const bodyTop = Math.min(priceToY(c.o), priceToY(c.c));
    const bodyBot = Math.max(priceToY(c.o), priceToY(c.c));
    const bodyW = Math.max(1, this.view.cellW - 2);
    this.ctx.fillRect(Math.round(xCenter - bodyW / 2), bodyTop, bodyW, Math.max(1, bodyBot - bodyTop));
  }

  // Right axis (minimal).
  this.ctx.fillStyle = this.palette.axisText;
  this.ctx.font = '10px Geist, sans-serif';
  this.ctx.textAlign = 'left';
  this.ctx.textBaseline = 'middle';
  const labels = 6;
  for (let i = 0; i <= labels; i++) {
    const p = hi - (hi - lo) * i / labels;
    const y = priceToY(p);
    this.ctx.fillText(p.toFixed(2), plot.right + 4, y);
  }
}
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Task C5: Wire `fetchHistory` in the Flutter shell

**Files:**
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
```

- [ ] **Step 2: Handle `fetchHistory` in `_onWindowMessage`**

Replace the `case 'fetchHistory':` arm with:

```dart
case 'fetchHistory':
  _handleFetchHistory(msg['value']);
  break;
```

Add the method:

```dart
Future<void> _handleFetchHistory(dynamic value) async {
  if (value is! Map) return;
  final requestId = value['requestId'] as String?;
  final exch = value['exch'] as String?;
  final token = value['token'] as String?;
  final interval = value['interval'] as String?;
  final start = (value['start'] as num?)?.toInt();
  final end = (value['end'] as num?)?.toInt();
  if (requestId == null || exch == null || token == null ||
      interval == null || start == null || end == null) return;
  try {
    final resp = await locator<ApiExporter>().getTPSeriesChart(
      exchange: exch,
      token: token,
      interval: interval,
      startEpoch: start,
      endEpoch: end,
    );
    // TpSeries returns oldest-first or newest-first depending on backend;
    // normalize to oldest-first by sorting on ts.
    final raw = resp.data ?? const [];
    final candles = <Map<String, dynamic>>[];
    for (final d in raw) {
      final ts = int.tryParse(d.ssboe ?? '');
      final o = double.tryParse(d.into ?? '');
      final h = double.tryParse(d.inth ?? '');
      final l = double.tryParse(d.intl ?? '');
      final c = double.tryParse(d.intc ?? '');
      final v = double.tryParse(d.intv ?? '') ?? 0;
      if (ts == null || o == null || h == null || l == null || c == null) continue;
      candles.add({'ts': ts, 'o': o, 'h': h, 'l': l, 'c': c, 'v': v});
    }
    candles.sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));
    _post(encodeHistoryResult(requestId, candles));
  } catch (e) {
    _post(encodeHistoryError(requestId, e.toString()));
  }
}
```

- [ ] **Step 3: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -5`
Expected: `No issues found!`

---

### Smoke Checkpoint — Group C

- [ ] Run `flutter run -d chrome --web-port 8080`.
- [ ] Navigate to `/charts`.
- [ ] Click the symbol search field. Type "RELI". A dropdown appears with matches.
- [ ] Click "RELIANCE-EQ" (or the first NSE EQ entry).
- [ ] **Expected:** loading overlay appears briefly, then a green/red candle chart fills the iframe area with ~120 visible 1m candles. Right-side price labels visible.
- [ ] Open the timeframe picker, choose "5m". Chart re-fetches and re-renders with 5m candles aggregated from 1m source.
- [ ] Choose "1h". Chart re-fetches with `interval=5` source.
- [ ] Choose "1D". Chart re-fetches with `interval=1D` source.
- [ ] Choose Custom… → enter `7`. Chart re-fetches and aggregates into 7m candles.

---

# Group D — Live tick forwarding

End-state: the rightmost candle's H/L/C tick visibly with each tick. Switching symbols correctly unsubscribes the previous + subscribes the new.

---

### Task D1: Implement `Chart.ingestTick`

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Replace `ingestTick` body**

```javascript
ingestTick(packet) {
  if (!this.scrip) return;
  // packet is the raw WS payload forwarded by Flutter. Keys we use:
  //   lp (last price), v (cum volume), ft (epoch seconds).
  // Some packets carry partial updates — merge into our running tickState
  // before handing to the aggregator (same merge pattern as orderflow).
  const lp = packet.lp != null ? +packet.lp : null;
  const v = packet.v != null ? +packet.v : null;
  const ft = packet.ft != null ? +packet.ft : null;
  if (lp != null) this.tickState.lp = lp;
  if (v != null) this.tickState.v = v;
  if (ft != null) this.tickState.ft = ft;
  if (this.tickState.lp == null || this.tickState.v == null || this.tickState.ft == null) return;
  const targetMs = this.timeframeMinutes * 60_000;
  const result = ingestTickIntoBucket(
      this.candles, this.tickState, this.aggState, targetMs);
  if (result === 'applied') this.scheduleRedraw();
}
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Task D2: Implement WS subscribe/unsubscribe in the Flutter shell

**Files:**
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:mynt_plus/provider/websocket_provider.dart';
```

- [ ] **Step 2: Track subscribed tokens + WS listener**

Add fields to the state class:

```dart
final Set<String> _subscribedKeys = {}; // 'EXCH|TOKEN'
VoidCallback? _wsListener;
```

In `initState`, after `_registerFactory()`:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  final ws = ref.read(webSocketProvider);
  _wsListener = () {
    if (_subscribedKeys.isEmpty) return;
    final data = ws.socketDatas;
    for (final key in _subscribedKeys) {
      final token = key.split('|').last;
      final exch = key.split('|').first;
      final entry = data[token];
      if (entry is! Map) continue;
      // Only forward when there's a meaningful payload (lp or v present)
      final packet = <String, dynamic>{
        'exch': exch,
        if (entry['lp'] != null) 'lp': entry['lp'],
        if (entry['v'] != null) 'v': entry['v'],
        if (entry['ft'] != null) 'ft': entry['ft'],
      };
      if (packet.length <= 1) continue;
      _post(encodeTick(token, packet));
    }
  };
  ws.addListener(_wsListener!);
});
```

In `dispose`, before `super.dispose()`:

```dart
if (_wsListener != null) {
  try { ref.read(webSocketProvider).removeListener(_wsListener!); } catch (_) {}
}
```

- [ ] **Step 3: Handle subscribe/unsubscribe messages**

Replace the `case 'subscribe':` arm:

```dart
case 'subscribe':
  _handleSubscribe(msg['value']);
  break;
case 'unsubscribe':
  _handleUnsubscribe(msg['value']);
  break;
```

Add methods:

```dart
void _handleSubscribe(dynamic value) {
  if (value is! Map) return;
  final exch = value['exch'] as String?;
  final token = value['token'] as String?;
  if (exch == null || token == null) return;
  final key = '$exch|$token';
  if (_subscribedKeys.contains(key)) return;
  _subscribedKeys.add(key);
  // Fire-and-forget subscribe via the existing WS provider.
  final ws = ref.read(webSocketProvider);
  ws.establishConnection(
    channelInput: key,
    task: 't',
    context: context,
  );
}

void _handleUnsubscribe(dynamic value) {
  if (value is! Map) return;
  final exch = value['exch'] as String?;
  final token = value['token'] as String?;
  if (exch == null || token == null) return;
  final key = '$exch|$token';
  if (!_subscribedKeys.contains(key)) return;
  _subscribedKeys.remove(key);
  final ws = ref.read(webSocketProvider);
  // The WS provider takes 'u' as the unsubscribe task; channelInput format
  // is the same EXCH|TOKEN we used to subscribe.
  ws.establishConnection(
    channelInput: key,
    task: 'u',
    context: context,
  );
}
```

- [ ] **Step 4: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -5`
Expected: `No issues found!`

---

### Smoke Checkpoint — Group D

- [ ] Run `flutter run -d chrome --web-port 8080` during market hours (or with a live test feed).
- [ ] Navigate to `/charts`, pick a liquid symbol (NIFTY index or RELIANCE-EQ), timeframe `1m`.
- [ ] **Expected:** the rightmost candle's high/low/close updates every few seconds as ticks arrive. The Y range auto-fits if price moves outside.
- [ ] Switch to BANKNIFTY. The chart re-fetches, and only BANKNIFTY ticks update the new live candle (no leakage from the previous subscription).
- [ ] Open DevTools Network → WS frame inspector. Verify `EXCH|TOKEN` subscribe and unsubscribe frames are sent at the right times.

---

# Group E — Interaction (pan, zoom, crosshair)

End-state: the chart is fully interactive — drag to pan, drag right axis to zoom Y, drag bottom axis to zoom X, mouse wheel = zoom X / shift+wheel = zoom Y, double-click recenters, crosshair follows the cursor with price + time chips.

---

### Task E1: Add the `.pane` interaction layer in `chart.js`

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add interaction state fields in the `Chart` constructor**

Inside the constructor, after `this.view = ...`, add:

```javascript
this.hover = { x: null, y: null, inside: false };
this._dragMode = null;
this._dragLastX = 0;
this._dragLastY = 0;
this._attachInteraction();
```

- [ ] **Step 2: Add the `_attachInteraction` method**

Add inside the class (anywhere — convention says after `resize`):

```javascript
_attachInteraction() {
  const wrap = this.container;
  wrap.addEventListener('mousedown', (e) => {
    const rect = wrap.getBoundingClientRect();
    const x = e.clientX - rect.left, y = e.clientY - rect.top;
    this._dragMode = this._hitZone(x, y);
    this._dragLastX = e.clientX;
    this._dragLastY = e.clientY;
    wrap.classList.remove('dragging', 'zoom-y', 'zoom-x');
    if (this._dragMode === 'pan') wrap.classList.add('dragging');
    else if (this._dragMode === 'zoom-y') wrap.classList.add('zoom-y');
    else if (this._dragMode === 'zoom-x') wrap.classList.add('zoom-x');
    this.view.autoFollow = false;
    this.view.autoFitY = false;
  });
  window.addEventListener('mouseup', () => {
    if (this._dragMode) wrap.classList.remove('dragging', 'zoom-y', 'zoom-x');
    this._dragMode = null;
  });
  window.addEventListener('mousemove', (e) => {
    const rect = wrap.getBoundingClientRect();
    const x = e.clientX - rect.left, y = e.clientY - rect.top;
    const inside = x >= 0 && y >= 0 && x <= rect.width && y <= rect.height;
    if (!this._dragMode) {
      if (inside) {
        const z = this._hitZone(x, y);
        wrap.style.cursor = z === 'zoom-y' ? 'ns-resize'
          : z === 'zoom-x' ? 'ew-resize' : 'crosshair';
        if (this.hover.x !== x || this.hover.y !== y || !this.hover.inside) {
          this.hover.x = x; this.hover.y = y; this.hover.inside = true;
          this.scheduleRedraw();
        }
      } else if (this.hover.inside) {
        this.hover.inside = false;
        this.scheduleRedraw();
      }
      return;
    }
    if (this.hover.inside) { this.hover.inside = false; }
    const dx = e.clientX - this._dragLastX;
    const dy = e.clientY - this._dragLastY;
    this._dragLastX = e.clientX;
    this._dragLastY = e.clientY;
    if (this._dragMode === 'pan') {
      this.view.offsetX += dx;
      // Vertical pan in price units (auto mode → manual on first drag).
      if (this.view.priceCenter == null) {
        this._snapshotYToManual();
      }
      this.view.priceCenter += dy * this.view.pricePerPx;
    } else if (this._dragMode === 'zoom-y') {
      if (this.view.priceCenter == null) this._snapshotYToManual();
      this.view.pricePerPx = Math.max(1e-6,
          this.view.pricePerPx * Math.exp(dy * 0.005));
    } else if (this._dragMode === 'zoom-x') {
      this.view.cellW = Math.max(4, Math.min(60,
          this.view.cellW + dx * 0.15));
    }
    this.scheduleRedraw();
  });
  wrap.addEventListener('wheel', (e) => {
    e.preventDefault();
    const factor = e.deltaY < 0 ? 1.1 : 1 / 1.1;
    if (e.shiftKey) {
      if (this.view.priceCenter == null) this._snapshotYToManual();
      this.view.pricePerPx = Math.max(1e-6, this.view.pricePerPx / factor);
      this.view.autoFitY = false;
    } else {
      this.view.cellW = Math.max(4, Math.min(60, this.view.cellW * factor));
    }
    this.view.autoFollow = false;
    this.scheduleRedraw();
  }, { passive: false });
  wrap.addEventListener('dblclick', () => {
    this.view.offsetX = 0;
    this.view.priceCenter = null;
    this.view.pricePerPx = null;
    this.view.autoFollow = true;
    this.view.autoFitY = true;
    this.scheduleRedraw();
  });
  wrap.addEventListener('mouseleave', () => {
    if (this.hover.inside) { this.hover.inside = false; this.scheduleRedraw(); }
  });
}

_hitZone(x, y) {
  const w = this.canvas.clientWidth;
  const h = this.canvas.clientHeight;
  if (x >= w - 64) return 'zoom-y';   // right gutter
  if (y >= h - 24) return 'zoom-x';   // bottom gutter
  return 'pan';
}

// On the first manual Y interaction, capture the current auto-fit values so
// subsequent drags are smooth and not snap-jumpy.
_snapshotYToManual() {
  if (this.candles.length === 0) return;
  const visible = this._visibleCandles();
  if (visible.length === 0) return;
  let lo = Infinity, hi = -Infinity;
  for (const c of visible) { if (c.l < lo) lo = c.l; if (c.h > hi) hi = c.h; }
  if (!isFinite(lo) || !isFinite(hi)) return;
  const pad = (hi - lo) * 0.08 || 1;
  const plotH = this.canvas.clientHeight - 32; // approx plot height
  this.view.priceCenter = (lo + hi) / 2;
  this.view.pricePerPx = ((hi - lo) + 2 * pad) / plotH;
}
```

- [ ] **Step 3: Add `_visibleCandles` helper**

```javascript
_visibleCandles() {
  if (this.candles.length === 0) return [];
  const w = this.canvas.clientWidth - 72; // minus right gutter + left pad
  const visibleN = Math.max(1, Math.floor(w / this.view.cellW));
  // offsetX shifts the visible window (positive = older candles visible).
  const shift = Math.max(0, Math.round(this.view.offsetX / this.view.cellW));
  const end = Math.max(visibleN, this.candles.length - shift);
  const start = Math.max(0, end - visibleN);
  return this.candles.slice(start, end);
}
```

- [ ] **Step 4: Rewrite `draw()` to use manual/auto Y + visible window**

Replace the body of `draw()`:

```javascript
draw() {
  const w = this.canvas.clientWidth;
  const h = this.canvas.clientHeight;
  this.ctx.fillStyle = this.palette.bg;
  this.ctx.fillRect(0, 0, w, h);
  if (this.candles.length === 0) return;

  const plot = { left: 8, top: 8, right: w - 64, bottom: h - 24 };
  plot.width = plot.right - plot.left;
  plot.height = plot.bottom - plot.top;

  const visible = this._visibleCandles();
  if (visible.length === 0) return;

  let lo, hi;
  if (this.view.priceCenter == null) {
    // Auto-fit.
    lo = Infinity; hi = -Infinity;
    for (const c of visible) { if (c.l < lo) lo = c.l; if (c.h > hi) hi = c.h; }
    const pad = (hi - lo) * 0.08 || 1;
    lo -= pad; hi += pad;
  } else {
    const half = (plot.height / 2) * this.view.pricePerPx;
    lo = this.view.priceCenter - half;
    hi = this.view.priceCenter + half;
  }

  const priceToY = (p) => plot.top + plot.height * (hi - p) / (hi - lo);
  const yToPrice = (y) => hi - (y - plot.top) * (hi - lo) / plot.height;

  // Optional gridlines.
  if (this.overlays.gridlines) {
    this.ctx.strokeStyle = this.palette.gridSoft;
    this.ctx.lineWidth = 0.5;
    const labels = 8;
    for (let i = 1; i < labels; i++) {
      const y = plot.top + (plot.height * i) / labels;
      this.ctx.beginPath(); this.ctx.moveTo(plot.left, y); this.ctx.lineTo(plot.right, y); this.ctx.stroke();
    }
  }

  // Candles.
  for (let i = 0; i < visible.length; i++) {
    const c = visible[i];
    const xCenter = plot.right - (visible.length - i - 0.5) * this.view.cellW;
    const isBull = c.c >= c.o;
    const color = isBull ? this.palette.bull : this.palette.bear;
    this.ctx.fillStyle = color;
    this.ctx.fillRect(Math.round(xCenter), priceToY(c.h), 1, priceToY(c.l) - priceToY(c.h));
    const bodyTop = Math.min(priceToY(c.o), priceToY(c.c));
    const bodyBot = Math.max(priceToY(c.o), priceToY(c.c));
    const bodyW = Math.max(1, this.view.cellW - 2);
    this.ctx.fillRect(Math.round(xCenter - bodyW / 2), bodyTop, bodyW, Math.max(1, bodyBot - bodyTop));
  }

  // Right axis labels (nice-stride algorithm — mirror orderflow).
  this._drawPriceAxis(plot, lo, hi);

  // Crosshair.
  if (this.hover.inside && this.hover.x != null) {
    this.ctx.strokeStyle = this.palette.crosshair;
    this.ctx.lineWidth = 1;
    this.ctx.setLineDash([4, 4]);
    this.ctx.beginPath();
    this.ctx.moveTo(this.hover.x, plot.top);
    this.ctx.lineTo(this.hover.x, plot.bottom);
    this.ctx.moveTo(plot.left, this.hover.y);
    this.ctx.lineTo(plot.right, this.hover.y);
    this.ctx.stroke();
    this.ctx.setLineDash([]);
    // Price chip in right gutter.
    const price = yToPrice(this.hover.y);
    if (price > 0) this._drawChip(plot.right + 2, this.hover.y,
        price.toFixed(this._priceDecimals()));
  }
}

_priceDecimals() {
  return (this.scrip && this.scrip.ti && this.scrip.ti < 1) ? 2 : 2;
}

_drawChip(x, y, text) {
  this.ctx.font = '700 10px Geist, sans-serif';
  this.ctx.textBaseline = 'middle';
  const tw = this.ctx.measureText(text).width + 10;
  this.ctx.fillStyle = this.palette.crosshairChip;
  this._roundedRect(x, y - 8, Math.min(tw, 60), 16, 3);
  this.ctx.fill();
  this.ctx.fillStyle = this.palette.chipText;
  this.ctx.textAlign = 'center';
  this.ctx.fillText(text, x + Math.min(tw, 60) / 2, y);
}

_roundedRect(x, y, w, h, r) {
  const rr = Math.min(r, w / 2, h / 2);
  this.ctx.beginPath();
  this.ctx.moveTo(x + rr, y);
  this.ctx.lineTo(x + w - rr, y);
  this.ctx.quadraticCurveTo(x + w, y, x + w, y + rr);
  this.ctx.lineTo(x + w, y + h - rr);
  this.ctx.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
  this.ctx.lineTo(x + rr, y + h);
  this.ctx.quadraticCurveTo(x, y + h, x, y + h - rr);
  this.ctx.lineTo(x, y + rr);
  this.ctx.quadraticCurveTo(x, y, x + rr, y);
  this.ctx.closePath();
}

_drawPriceAxis(plot, lo, hi) {
  // Nice-stride label algorithm — pick the smallest "nice" multiplier of
  // the symbol's tick size that leaves ~30px between labels.
  const step = (this.scrip && this.scrip.ti && this.scrip.ti > 0) ? this.scrip.ti : 0.05;
  const minPx = 30;
  const range = hi - lo;
  const pxPerUnit = plot.height / range;
  const minStepUnits = minPx / pxPerUnit;
  const niceMultipliers = [1, 2, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000];
  let stride = step * niceMultipliers[niceMultipliers.length - 1];
  for (const m of niceMultipliers) {
    if (m * step >= minStepUnits) { stride = m * step; break; }
  }
  const first = Math.ceil(lo / stride) * stride;
  this.ctx.fillStyle = this.palette.axisText;
  this.ctx.font = '500 10px Geist, sans-serif';
  this.ctx.textAlign = 'left';
  this.ctx.textBaseline = 'middle';
  for (let p = first; p <= hi; p += stride) {
    const y = plot.top + plot.height * (hi - p) / (hi - lo);
    if (y < plot.top - 6 || y > plot.bottom + 6) continue;
    this.ctx.fillText(p.toFixed(stride < 1 ? 2 : 0), plot.right + 4, y);
  }
}
```

- [ ] **Step 5: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Smoke Checkpoint — Group E

- [ ] Navigate to `/charts`, pick NIFTY 1m, wait for history.
- [ ] **Pan:** click and drag the chart body left → older candles appear.
- [ ] **Reset:** double-click anywhere → auto-follow re-engages, latest candle pinned to the right.
- [ ] **Zoom X:** drag the bottom 24px of the chart left/right → candles get narrower/wider.
- [ ] **Zoom Y:** drag the right 64px of the chart up/down → price range expands/contracts.
- [ ] **Wheel:** scroll the wheel → cellW changes. Shift+wheel → Y zoom.
- [ ] **Crosshair:** move the mouse over the chart → dashed cursor lines, price chip in the right gutter at the hover Y.
- [ ] **Cursor:** cursor changes shape over the right gutter (ns-resize) and bottom gutter (ew-resize).

---

# Group F — Top OHLC strip + axes polish

End-state: top OHLC strip shows the hovered (or latest) candle; bottom time axis labels visible at appropriate cadence; price axis labels styled.

---

### Task F1: Add top OHLC strip to `draw()`

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add `_drawOhlc` method**

```javascript
_drawOhlc(plot) {
  if (this.candles.length === 0) return;
  let idx = this.candles.length - 1;
  if (this.hover.inside && this.hover.x != null) {
    const hi = this._candleAtX(this.hover.x);
    if (hi >= 0) idx = hi;
  }
  const c = this.candles[idx];
  const up = c.c >= c.o;
  const dir = up ? this.palette.bull : this.palette.bear;
  const delta = c.c - c.o;
  const segs = [
    ['O', this._fmtPrice(c.o), dir],
    ['H', this._fmtPrice(c.h), dir],
    ['L', this._fmtPrice(c.l), dir],
    ['C', this._fmtPrice(c.c), dir],
    ['V', this._fmtVol(c.v), this.palette.ohlcValue],
    ['Δ', (delta >= 0 ? '+' : '') + delta.toFixed(2),
        delta >= 0 ? this.palette.bull : this.palette.bear],
  ];
  this.ctx.font = '600 11px Geist, sans-serif';
  this.ctx.textBaseline = 'middle';
  let x = plot.left + 4;
  const y = 14;
  for (const [label, value, color] of segs) {
    this.ctx.fillStyle = this.palette.ohlcLabel;
    this.ctx.textAlign = 'left';
    this.ctx.fillText(label, x, y);
    x += this.ctx.measureText(label).width + 4;
    this.ctx.fillStyle = color;
    this.ctx.fillText(value, x, y);
    x += this.ctx.measureText(value).width + 12;
  }
}

_candleAtX(x) {
  if (this.candles.length === 0) return -1;
  const visible = this._visibleCandles();
  if (visible.length === 0) return -1;
  const plot = { left: 8, right: this.canvas.clientWidth - 64 };
  const xRel = x - plot.right;
  const offsetIdx = Math.floor(xRel / this.view.cellW) + visible.length;
  const visIdx = Math.max(0, Math.min(visible.length - 1, offsetIdx));
  return this.candles.indexOf(visible[visIdx]);
}

_fmtPrice(p) { return p.toFixed(2); }
_fmtVol(v) {
  if (v < 1000) return Math.round(v).toString();
  if (v < 100000) return (v / 1000).toFixed(v < 10000 ? 1 : 0) + 'k';
  return (v / 100000).toFixed(v < 1000000 ? 1 : 0) + 'L';
}
```

- [ ] **Step 2: Call `_drawOhlc` from `draw()`**

At the bottom of `draw()` (after the crosshair drawing), add:

```javascript
this._drawOhlc(plot);
```

- [ ] **Step 3: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Task F2: Add bottom time axis

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add `_drawTimeAxis` method**

```javascript
_drawTimeAxis(plot, visible) {
  if (visible.length === 0) return;
  this.ctx.fillStyle = this.palette.axisText;
  this.ctx.font = '500 10px Geist, sans-serif';
  this.ctx.textBaseline = 'middle';
  this.ctx.textAlign = 'center';
  const yAxis = this.canvas.clientHeight - 10;
  // Cadence: ~80px between labels.
  const labelCadence = Math.max(1, Math.round(80 / this.view.cellW));
  let prevDay = null;
  for (let i = 0; i < visible.length; i++) {
    if (i % labelCadence !== 0) continue;
    const c = visible[i];
    const xCenter = plot.right - (visible.length - i - 0.5) * this.view.cellW;
    const date = new Date(c.ts * 1000);
    // IST display.
    const ist = new Date(date.getTime() + (5.5 * 3600 * 1000));
    const dayKey = ist.getUTCDate() + '/' + ist.getUTCMonth();
    let label;
    if (this.timeframeMinutes >= 1440) {
      label = ist.getUTCDate() + ' ' +
          ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][ist.getUTCMonth()];
    } else {
      const hh = String(ist.getUTCHours()).padStart(2, '0');
      const mm = String(ist.getUTCMinutes()).padStart(2, '0');
      label = hh + ':' + mm;
      if (dayKey !== prevDay && prevDay != null) {
        label = ist.getUTCDate() + '/' + (ist.getUTCMonth() + 1) + ' ' + label;
      }
    }
    prevDay = dayKey;
    this.ctx.fillText(label, xCenter, yAxis);
  }
}
```

- [ ] **Step 2: Call `_drawTimeAxis` from `draw()`**

Before `this._drawOhlc(plot)`, add:

```javascript
this._drawTimeAxis(plot, visible);
```

- [ ] **Step 3: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Smoke Checkpoint — Group F

- [ ] Reload `/charts`. Pick NIFTY 5m.
- [ ] **Top:** OHLC strip reads `O H L C V Δ` in the top-left. Hover a candle → values update to that candle's. Move away → returns to latest.
- [ ] **Bottom:** time labels every ~80px showing IST `HH:MM`. Date prefix appears at day breaks.
- [ ] Switch to 1D. Time labels become `dd Mon`.
- [ ] **Right axis:** price labels at nice round numbers (e.g. 23500, 23550, 23600 for NIFTY).

---

# Group G — Volume panel + Settings popup + custom-timeframe wiring

End-state: Settings popup with Gridlines + Volume toggles works; volume bars render in a panel below the candle area when on; custom timeframe dialog produces correct candles.

---

### Task G1: Add volume panel rendering

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Restructure `draw()` to use a volume panel**

Replace the plot rect computation:

```javascript
const w = this.canvas.clientWidth;
const h = this.canvas.clientHeight;
this.ctx.fillStyle = this.palette.bg;
this.ctx.fillRect(0, 0, w, h);
if (this.candles.length === 0) return;

const bottomGutter = 24;
const rightGutter = 64;
const topPad = 24;
const volH = this.overlays.volume ? Math.round((h - topPad - bottomGutter) * 0.22) : 0;
const candleH = (h - topPad - bottomGutter) - volH;

const plot = {
  left: 8, top: topPad,
  right: w - rightGutter,
  bottom: topPad + candleH,
};
plot.width = plot.right - plot.left;
plot.height = plot.bottom - plot.top;

const volPlot = volH > 0 ? {
  left: plot.left, top: plot.bottom + 1,
  right: plot.right, bottom: plot.bottom + volH,
} : null;
if (volPlot) {
  volPlot.width = volPlot.right - volPlot.left;
  volPlot.height = volPlot.bottom - volPlot.top;
}
```

After the candle drawing loop, add:

```javascript
if (volPlot) {
  let maxV = 0;
  for (const c of visible) { if (c.v > maxV) maxV = c.v; }
  if (maxV > 0) {
    for (let i = 0; i < visible.length; i++) {
      const c = visible[i];
      const xCenter = plot.right - (visible.length - i - 0.5) * this.view.cellW;
      const isBull = c.c >= c.o;
      this.ctx.fillStyle = isBull ? this.palette.bullSoft : this.palette.bearSoft;
      const barH = Math.max(1, (c.v / maxV) * volPlot.height);
      const bodyW = Math.max(1, this.view.cellW - 2);
      this.ctx.fillRect(
          Math.round(xCenter - bodyW / 2),
          volPlot.bottom - barH, bodyW, barH);
    }
    // Divider line.
    this.ctx.strokeStyle = this.palette.gridStrong;
    this.ctx.lineWidth = 1;
    this.ctx.beginPath();
    this.ctx.moveTo(plot.left, plot.bottom + 0.5);
    this.ctx.lineTo(plot.right, plot.bottom + 0.5);
    this.ctx.stroke();
  }
}
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Task G2: Add a Settings popup to the top bar

Similar pattern to `OrderflowTopBar`'s settings popup (Gridlines + Volume toggles, compact Switch via Transform.scale).

**Files:**
- Modify: `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`

- [ ] **Step 1: Add the popup widget at the bottom of the file**

```dart
class _SettingsButton extends StatefulWidget {
  final ChartOverlays overlays;
  final ValueChanged<ChartOverlays> onChanged;
  final ValueChanged<bool> onPopupVisibilityChanged;
  const _SettingsButton({
    required this.overlays,
    required this.onChanged,
    required this.onPopupVisibilityChanged,
  });

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _open() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _build);
    Overlay.of(context).insert(_entry!);
  }
  void _close() {
    _entry?.remove();
    _entry = null;
    widget.onPopupVisibilityChanged(true);
  }
  @override
  void dispose() {
    if (_entry != null) {
      _entry!.remove();
      widget.onPopupVisibilityChanged(true);
    }
    super.dispose();
  }

  Widget _build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close),
        ),
      ),
      Positioned(
        width: 220,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(-180, 38),
          child: PointerInterceptor(
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                      child: Text('Indicators',
                          style: MyntWebTextStyles.caption(context,
                              fontWeight: MyntFonts.semiBold)),
                    ),
                    _ToggleRow(
                      label: 'Gridlines',
                      value: widget.overlays.gridlines,
                      onChanged: (v) => widget.onChanged(
                          widget.overlays.copyWith(gridlines: v)),
                    ),
                    _ToggleRow(
                      label: 'Volume',
                      value: widget.overlays.volume,
                      onChanged: (v) => widget.onChanged(
                          widget.overlays.copyWith(volume: v)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: TextButton.icon(
        icon: const Icon(shadcn.LucideIcons.settings, size: 14),
        label: const Text('Settings'),
        onPressed: () => _entry == null ? _open() : _close(),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: MyntWebTextStyles.body(context))),
          SizedBox(
            height: 24,
            child: Transform.scale(
              scale: 0.7,
              alignment: Alignment.centerRight,
              child: Switch(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 2: Add `pointer_interceptor` import + place the Settings button in the row**

At the top of `chart_engine_top_bar.dart`:

```dart
import 'package:pointer_interceptor/pointer_interceptor.dart';
```

In `build`, add to the `Wrap.children`:

```dart
_SettingsButton(
  overlays: pane.overlays,
  onChanged: (o) => notifier.setPaneOverlays('main', o),
  onPopupVisibilityChanged: onPopupVisibilityChanged,
),
```

- [ ] **Step 3: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -5`
Expected: `No issues found!`

---

### Smoke Checkpoint — Group G

- [ ] Reload `/charts`. Pick NIFTY 1m.
- [ ] **Volume default:** volume bars visible in the bottom ~22% of the chart, green/red matching candle direction.
- [ ] Click Settings → toggle **Volume off**. Volume panel disappears; candles expand to fill the freed space. Toggle on again → reappears.
- [ ] Toggle **Gridlines off**. Horizontal gridlines disappear. Toggle on → reappear.
- [ ] **Custom timeframe:** open Timeframe picker → Custom… → enter `7` → chart re-fetches and draws 7m candles.
- [ ] Navigate away to /home and back to /charts. Overlay state, selected symbol, and timeframe restored (Riverpod store).

---

# Group H — Error overlays + stale pill + final polish

End-state: error states are handled gracefully; final `flutter analyze` and `node --check` are clean; full smoke checklist from the spec passes.

---

### Task H1: Error overlay handling

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Replace `onHistoryError` body**

```javascript
onHistoryError(requestId, message) {
  if (requestId !== this._pendingRequestId) return;
  this._pendingRequestId = null;
  const name = this.scrip ? this.scrip.dispName : 'symbol';
  this._showOverlay('Could not load history for ' + name,
      String(message || 'Network error') + ' · click chart to retry');
  this.container.addEventListener('click', this._retryOnce, { once: true });
}

_retryOnce = () => {
  this._hideOverlay();
  this._loadHistory();
};
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Task H2: Stale pill in the top OHLC area

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Track `_lastTickAt` + add `_drawStalePill`**

In the constructor:

```javascript
this._lastTickAt = 0;
```

In `ingestTick`, after `result === 'applied'`:

```javascript
this._lastTickAt = Date.now();
```

Add the method:

```javascript
_drawStalePill(plot) {
  if (!this._lastTickAt) return;
  const ageSec = (Date.now() - this._lastTickAt) / 1000;
  if (ageSec < 120) return;
  const text = 'Stale (' + Math.round(ageSec) + 's)';
  this.ctx.font = '700 10px Geist, sans-serif';
  this.ctx.textBaseline = 'middle';
  const tw = this.ctx.measureText(text).width + 12;
  this.ctx.fillStyle = this.palette.statusStale;
  this._roundedRect(this.canvas.clientWidth - 64 - tw - 8, 6, tw, 16, 8);
  this.ctx.fill();
  this.ctx.fillStyle = this.palette.bg;
  this.ctx.textAlign = 'center';
  this.ctx.fillText(text, this.canvas.clientWidth - 64 - tw - 8 + tw / 2, 14);
}
```

Call from `draw()` after `_drawOhlc`:

```javascript
this._drawStalePill(plot);
```

Set up a 5-second redraw ticker in the constructor so the staleness check runs even when no ticks arrive:

```javascript
this._stalenessTicker = setInterval(() => {
  if (this._lastTickAt) this.scheduleRedraw();
}, 5000);
```

And in `destroy`:

```javascript
clearInterval(this._stalenessTicker);
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart.js`
Expected: no output.

---

### Task H3: Final analyzer pass

- [ ] **Step 1: Static check (Flutter)**

Run: `flutter analyze lib/screens/web/chart_engine lib/screens/web/customizable_split_home_screen.dart lib/screens/web/home/widgets/app_bar/navigation_drawer_web.dart lib/routes/web_router.dart 2>&1 | tail -10`
Expected: `No issues found!`

- [ ] **Step 2: Static check (JS)**

Run: `node --check web/chart-engine/chart-engine.js web/chart-engine/chart.js web/chart-engine/aggregator.js web/chart-engine/theme.js`
Expected: no output for each.

- [ ] **Step 3: Aggregator tests**

Run: `node web/chart-engine/aggregator.test.js`
Expected: all green.

---

### Final Smoke Checkpoint — full spec section 9 checklist

Run `flutter run -d chrome --web-port 8080` and step through:

- [ ] Open `/charts` → see NIFTY (or whichever last selection was stored) with historical candles drawn.
- [ ] Type "RELI" in the symbol box → see autocomplete dropdown → pick RELIANCE-EQ → chart re-fetches and renders.
- [ ] Switch timeframes: 1m → 5m → 1h → 1D — each re-fetches and re-buckets cleanly.
- [ ] Pick **Custom…** → enter `7` → see 7-minute candles.
- [ ] Drag chart body left → older candles appear, auto-follow disengages.
- [ ] Drag right axis → vertical zoom changes pricePerPx; price labels update.
- [ ] Drag bottom axis → horizontal zoom changes cellW.
- [ ] Double-click → resets to auto-fit + auto-follow.
- [ ] Toggle Volume in Settings → panel appears/disappears, candle area resizes.
- [ ] Toggle Gridlines → horizontal grid lines toggle.
- [ ] Toggle the app theme (light/dark) from elsewhere in the app → chart chrome + canvas palette switch in real time.
- [ ] Navigate to /home and back to /charts → state restored from store; no white screen on remount.
- [ ] Hover → crosshair, price chip, OHLC strip updates to hovered candle.
- [ ] **Live ticks (market hours):** rightmost candle's H/L/C update visibly every few seconds.
- [ ] Wait 2+ minutes with no ticks → "Stale" pill appears in the top-right.

---

## Notes for the executing engineer

- **Do not commit at any point.** The user reviews and commits the whole phase manually after a full smoke pass.
- **Reference orderflow heavily.** Patterns this plan reuses verbatim:
  - Unique view factory per state instance: `lib/screens/web/orderflow/orderflow_shell_screen.dart`
  - `pointer-events: auto !important` + `el.onLoad.first.then((_) => el.focus())`: same file
  - JSON-string postMessage: same file's `_post` / `_onWindowMessage`
  - Geist `@font-face` + light/dark CSS variables: `web/footprint-chart/style.css`
  - Popup with `PointerInterceptor` + iframe-pointer-gate: `lib/screens/web/orderflow/widgets/orderflow_top_bar.dart`
  - Compact `Switch` row with `Transform.scale(0.7)`: same file
  - `node aggregator.test.js` pattern: standalone, no Jest needed
- **Hot reload won't pick up JS file changes inside `web/chart-engine/`.** Hard-reload the browser tab after each JS change.
- **Pause and ask** if you hit any of these:
  - The duplicate `ScreenType` enum in `customizable_split_home_screen.dart` doesn't exist anymore — the codebase may have refactored.
  - `webSocketProvider` doesn't accept `task: 'u'` for unsubscribe — find the right unsubscribe code path.
  - `searchScripForStrategyBuilder` returns differently than expected.
