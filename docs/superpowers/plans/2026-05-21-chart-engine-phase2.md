# Chart Engine — Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the Phase 1 single-pane chart engine to support up to 6 panes in any of ~23 TradingView-style layouts, with click-to-focus active pane and persistent per-pane state via SharedPreferences.

**Architecture:** The Phase 1 iframe registry already supports N panes — Phase 2 mostly exercises those abstractions. The Flutter `ChartEngineSession` switches from a `Map<String, PaneState>` keyed `'main'` to a `List<PaneState>` indexed `0..N-1`, paired with a `ChartLayout` enum and `activePaneIndex`. A new `LayoutPicker` widget renders TradingView-style grouped icons. The JS engine reconciles its pane registry to the layout's pane count and applies CSS `grid-template-areas` for the layout.

**Tech Stack:** Flutter (Riverpod 3.x Notifier, dart:html, dart:ui_web, pointer_interceptor, shared_preferences); vanilla JS + Canvas 2D inside the iframe (no new deps).

---

## Project conventions

- **No git commits in plan steps.** User commits manually after testing the whole phase. Never include `git commit` / `git add` / `git push`.
- **Static gates after every code edit:** `flutter analyze lib/screens/web/chart_engine` for Dart; `node --check web/chart-engine/<file>.js` for JS. Don't move on if either reports errors.
- **Manual smoke checkpoints between groups** — pause and let the user verify before continuing.
- **Reference Phase 1 heavily.** Patterns reused verbatim:
  - JSON-string postMessage bridge (`chart_engine_bridge.dart`)
  - Popup widgets with `PointerInterceptor` + `onPopupVisibilityChanged` gate
  - Per-pane `Chart` class in `web/chart-engine/chart.js` (already instantiable N times)
  - Notifier/NotifierProvider state pattern (`chart_engine_store.dart`)
  - Pane registry in `web/chart-engine/chart-engine.js` (already a `Map<paneId, Chart>`)

## File map

### Created (Flutter)
| Path | Responsibility |
|---|---|
| `lib/screens/web/chart_engine/widgets/layout_picker.dart` | Layout picker button + popup with TradingView-style icon grid. `CustomPainter` renders each layout's glyph at 24×24 from its grid-areas string — no SVG assets needed. |

### Modified (Flutter)
| Path | What changes |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | `ChartLayout` enum (~23 values); `ChartEngineSession.panes` → `List<PaneState>`; add `layout` + `activePaneIndex`; setters change `String paneId` → `int index`; new `setLayout` + `setActivePane`; debounced `_persist` / one-shot `_restore` via `Preferences`; Phase 1 migration. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | Push `setLayout` + `setActivePane` to iframe on store changes; handle inbound `paneActivated` message; fan out per-pane state for N panes (not just `'main'`). |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | Insert `LayoutPicker` at the left of the `Wrap`; pickers now read from `session.active` (the active pane); callbacks pass `session.activePaneIndex` to setters. |
| `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart` | New encoders: `encodeSetLayout`, `encodeSetActivePane`. (`encodeSetPaneSymbol` etc. already take String paneId — call sites convert int → string.) |
| `lib/locator/preference.dart` | Add `setChartEngineSession(String json)` / `getChartEngineSession()` getter+setter pair, matching the existing typed-accessor pattern in this file. |

### Modified (JS — `web/chart-engine/`)
| Path | What changes |
|---|---|
| `chart-engine.js` | Handle `setLayout` (apply grid-template-areas/rows/columns, reconcile pane registry to new paneCount, destroy removed panes, create new panes with grid-area assignment); handle `setActivePane` (toggle `.active` class). |
| `chart.js` | `mousedown` handler posts `paneActivated` to parent BEFORE drag-mode classification; new `_drawPaneChip(plot)` called at the top of `_drawOhlc` showing `SYMBOL · TIMEFRAME` prefix. |
| `style.css` | Add `--accent` CSS variable per theme; `.pane.active { box-shadow: inset 0 0 0 2px var(--accent); }`. |

---

## Task ordering (high level)

1. **Group A — Data model + persistence.** Refactor `ChartEngineSession` to List + Layout + activeIndex. Add `Preferences` getter/setter. Hook into the notifier. End state: pane setters work by index; reload restores state.
2. **Group B — Layout picker UI.** New `LayoutPicker` widget with CustomPaint icons. Integrate into top bar. End state: clicking a layout posts `setLayout` to iframe (but iframe doesn't yet visually change).
3. **Group C — JS engine layout handling.** Update `chart-engine.js` + `style.css` to apply layouts and active highlight. End state: changing layouts re-arranges the visible panes; new panes appear with copied state.
4. **Group D — Click-to-focus.** `chart.js` mousedown posts `paneActivated`; shell handles it. End state: click any pane → active border moves.
5. **Group E — Top bar wiring + per-pane chip.** Top bar reads/writes active pane; chart shows pane chip (`SYMBOL · TIMEFRAME`). End state: full UX works.
6. **Group F — Final analyze + smoke.** Persistence round-trip + manual smoke checklist.

---

# Group A — Data model + persistence

End state: `ChartEngineSession` is index-based with layout enum and persistence. Reloading the page restores layout + per-pane state. Phase 1's old `'main'`-keyed prefs (if present) are migrated to a single-element List.

---

### Task A1: Add `ChartLayout` enum + layout metadata

**Files:**
- Modify: `lib/screens/web/chart_engine/state/chart_engine_store.dart`

- [ ] **Step 1: Insert the enum + metadata helpers** ABOVE the existing `ChartScrip` class

Add this block at the top of the file (between the `import` and `class ChartScrip`):

```dart
/// All supported chart layouts. The enum NAME is the persistence id and the
/// postMessage value — keep stable across versions.
enum ChartLayout {
  single  (paneCount: 1, areas: '"a"',                       rows: '1fr',         columns: '1fr'),
  cols2   (paneCount: 2, areas: '"a b"',                     rows: '1fr',         columns: '1fr 1fr'),
  rows2   (paneCount: 2, areas: '"a" "b"',                   rows: '1fr 1fr',     columns: '1fr'),
  cols3   (paneCount: 3, areas: '"a b c"',                   rows: '1fr',         columns: '1fr 1fr 1fr'),
  rows3   (paneCount: 3, areas: '"a" "b" "c"',               rows: '1fr 1fr 1fr', columns: '1fr'),
  t1b2    (paneCount: 3, areas: '"a a" "b c"',               rows: '1fr 1fr',     columns: '1fr 1fr'),
  t2b1    (paneCount: 3, areas: '"a b" "c c"',               rows: '1fr 1fr',     columns: '1fr 1fr'),
  l1r2    (paneCount: 3, areas: '"a b" "a c"',               rows: '1fr 1fr',     columns: '1fr 1fr'),
  l2r1    (paneCount: 3, areas: '"a c" "b c"',               rows: '1fr 1fr',     columns: '1fr 1fr'),
  grid2x2 (paneCount: 4, areas: '"a b" "c d"',               rows: '1fr 1fr',     columns: '1fr 1fr'),
  cols4   (paneCount: 4, areas: '"a b c d"',                 rows: '1fr',         columns: '1fr 1fr 1fr 1fr'),
  rows4   (paneCount: 4, areas: '"a" "b" "c" "d"',           rows: '1fr 1fr 1fr 1fr', columns: '1fr'),
  t1b3    (paneCount: 4, areas: '"a a a" "b c d"',           rows: '1fr 1fr',     columns: '1fr 1fr 1fr'),
  t3b1    (paneCount: 4, areas: '"a b c" "d d d"',           rows: '1fr 1fr',     columns: '1fr 1fr 1fr'),
  l1r3    (paneCount: 4, areas: '"a b" "a c" "a d"',         rows: '1fr 1fr 1fr', columns: '1fr 1fr'),
  l3r1    (paneCount: 4, areas: '"a d" "b d" "c d"',         rows: '1fr 1fr 1fr', columns: '1fr 1fr'),
  t1b4    (paneCount: 5, areas: '"a a a a" "b c d e"',       rows: '1fr 1fr',     columns: '1fr 1fr 1fr 1fr'),
  t4b1    (paneCount: 5, areas: '"a b c d" "e e e e"',       rows: '1fr 1fr',     columns: '1fr 1fr 1fr 1fr'),
  l1r4    (paneCount: 5, areas: '"a b" "a c" "a d" "a e"',   rows: '1fr 1fr 1fr 1fr', columns: '1fr 1fr'),
  l4r1    (paneCount: 5, areas: '"a e" "b e" "c e" "d e"',   rows: '1fr 1fr 1fr 1fr', columns: '1fr 1fr'),
  t2b3    (paneCount: 5, areas: '"a a a b b b" "c c d d e e"', rows: '1fr 1fr',   columns: '1fr 1fr 1fr 1fr 1fr 1fr'),
  grid3x2 (paneCount: 6, areas: '"a b c" "d e f"',           rows: '1fr 1fr',     columns: '1fr 1fr 1fr'),
  grid2x3 (paneCount: 6, areas: '"a b" "c d" "e f"',         rows: '1fr 1fr 1fr', columns: '1fr 1fr');

  const ChartLayout({
    required this.paneCount,
    required this.areas,
    required this.rows,
    required this.columns,
  });

  final int paneCount;
  final String areas;    // CSS grid-template-areas
  final String rows;     // CSS grid-template-rows
  final String columns;  // CSS grid-template-columns

  /// Letter for the area at this pane index (0→a, 1→b, …, 5→f).
  String areaLetter(int paneIndex) =>
      String.fromCharCode('a'.codeUnitAt(0) + paneIndex);

  /// Stable id used in postMessage payloads + persistence.
  String get id => name;

  static ChartLayout? fromId(String id) {
    for (final l in ChartLayout.values) {
      if (l.id == id) return l;
    }
    return null;
  }
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/state/chart_engine_store.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task A2: Convert `ChartEngineSession` to List-based panes + layout

**Files:**
- Modify: `lib/screens/web/chart_engine/state/chart_engine_store.dart`

- [ ] **Step 1: Replace the existing `ChartEngineSession` class**

Find:

```dart
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
```

Replace with:

```dart
class ChartEngineSession {
  final ChartLayout layout;
  final int activePaneIndex;
  final List<PaneState> panes;

  const ChartEngineSession({
    this.layout = ChartLayout.single,
    this.activePaneIndex = 0,
    this.panes = const [PaneState()],
  });

  PaneState get active => panes[activePaneIndex];

  ChartEngineSession copyWith({
    ChartLayout? layout,
    int? activePaneIndex,
    List<PaneState>? panes,
  }) =>
      ChartEngineSession(
        layout: layout ?? this.layout,
        activePaneIndex: activePaneIndex ?? this.activePaneIndex,
        panes: panes ?? this.panes,
      );

  ChartEngineSession copyWithPane(int index, PaneState next) {
    if (index < 0 || index >= panes.length) return this;
    final m = List<PaneState>.from(panes);
    m[index] = next;
    return copyWith(panes: m);
  }

  // ---------- Persistence ----------

  Map<String, dynamic> toJson() => {
        'version': 1,
        'layout': layout.id,
        'activePaneIndex': activePaneIndex,
        'panes': [for (final p in panes) p.toJson()],
      };

  static ChartEngineSession fromJson(Map<String, dynamic> j) {
    final layout = ChartLayout.fromId(j['layout'] as String? ?? 'single') ??
        ChartLayout.single;
    final activePaneIndex = (j['activePaneIndex'] as num?)?.toInt() ?? 0;
    final rawPanes = (j['panes'] as List?) ?? const [];
    final parsedPanes = <PaneState>[
      for (final p in rawPanes) PaneState.fromJson(p as Map<String, dynamic>),
    ];
    // Pad/truncate to layout.paneCount so the on-disk state can't claim a
    // count that disagrees with the layout.
    final panes = List<PaneState>.generate(
      layout.paneCount,
      (i) => i < parsedPanes.length ? parsedPanes[i] : const PaneState(),
    );
    return ChartEngineSession(
      layout: layout,
      activePaneIndex: activePaneIndex.clamp(0, panes.length - 1),
      panes: panes,
    );
  }
}
```

- [ ] **Step 2: Add `toJson` / `fromJson` to `ChartScrip`, `ChartOverlays`, `PaneState`**

`ChartScrip.toJson` already exists. Add `fromJson` factory to it. Replace the existing `ChartScrip` class with:

```dart
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

  static ChartScrip fromJson(Map<String, dynamic> j) => ChartScrip(
        exch: j['exch'] as String? ?? '',
        token: j['token'] as String? ?? '',
        tsym: j['tsym'] as String? ?? '',
        dispName: j['dispName'] as String? ?? '',
        ls: (j['ls'] as num?)?.toInt() ?? 1,
        ti: (j['ti'] as num?)?.toDouble() ?? 0.05,
      );
}
```

Replace `ChartOverlays` with (adds `fromJson`):

```dart
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

  static ChartOverlays fromJson(Map<String, dynamic> j) => ChartOverlays(
        gridlines: j['gridlines'] as bool? ?? true,
        volume: j['volume'] as bool? ?? true,
      );
}
```

Replace `PaneState` with (adds `toJson` / `fromJson`):

```dart
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

  Map<String, dynamic> toJson() => {
        if (scrip != null) 'scrip': scrip!.toJson(),
        'timeframeMinutes': timeframeMinutes,
        'overlays': overlays.toJson(),
      };

  static PaneState fromJson(Map<String, dynamic> j) => PaneState(
        scrip: j['scrip'] is Map
            ? ChartScrip.fromJson(j['scrip'] as Map<String, dynamic>)
            : null,
        timeframeMinutes: (j['timeframeMinutes'] as num?)?.toInt() ?? 1,
        overlays: j['overlays'] is Map
            ? ChartOverlays.fromJson(j['overlays'] as Map<String, dynamic>)
            : const ChartOverlays(),
      );
}
```

- [ ] **Step 3: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/state/chart_engine_store.dart 2>&1 | tail -5`
Expected: `No issues found!` (Existing references to `.main` and string-keyed setters in the notifier will be fixed in Task A3.)

---

### Task A3: Update `ChartEngineSessionNotifier` (int index setters + setLayout + setActivePane)

**Files:**
- Modify: `lib/screens/web/chart_engine/state/chart_engine_store.dart`

- [ ] **Step 1: Replace the existing notifier**

Find and replace the entire `ChartEngineSessionNotifier` class with:

```dart
class ChartEngineSessionNotifier extends Notifier<ChartEngineSession> {
  @override
  ChartEngineSession build() => const ChartEngineSession();

  void setPaneSymbol(int index, ChartScrip scrip) {
    if (index < 0 || index >= state.panes.length) return;
    state = state.copyWithPane(index, state.panes[index].copyWith(scrip: scrip));
  }

  void setPaneTimeframe(int index, int minutes) {
    if (index < 0 || index >= state.panes.length) return;
    state = state.copyWithPane(
        index, state.panes[index].copyWith(timeframeMinutes: minutes));
  }

  void setPaneOverlays(int index, ChartOverlays overlays) {
    if (index < 0 || index >= state.panes.length) return;
    state = state.copyWithPane(
        index, state.panes[index].copyWith(overlays: overlays));
  }

  void setActivePane(int index) {
    if (index < 0 || index >= state.panes.length) return;
    if (index == state.activePaneIndex) return;
    state = state.copyWith(activePaneIndex: index);
  }

  /// Apply a new layout. Grow rule: new panes copy the active pane's state.
  /// Shrink rule: active pane is kept first, then surviving panes in
  /// original order, surplus is discarded.
  void setLayout(ChartLayout next) {
    if (next == state.layout) return;
    final cur = state.panes;
    final activeIdx = state.activePaneIndex;
    final n = next.paneCount;
    final newPanes = <PaneState>[];
    int newActive;

    if (n >= cur.length) {
      // Grow — keep all existing in order, copy active to fill the rest.
      newPanes.addAll(cur);
      for (var i = cur.length; i < n; i++) {
        newPanes.add(cur[activeIdx]);
      }
      newActive = activeIdx;
    } else {
      // Shrink — active first, then others in original order, take first N.
      newPanes.add(cur[activeIdx]);
      for (var i = 0; i < cur.length; i++) {
        if (i == activeIdx) continue;
        if (newPanes.length >= n) break;
        newPanes.add(cur[i]);
      }
      newActive = 0; // formerly-active is now at slot 0
    }

    state = state.copyWith(
      layout: next,
      panes: newPanes,
      activePaneIndex: newActive,
    );
  }
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -15`
Expected: Errors only in `chart_engine_top_bar.dart` and `chart_engine_shell_screen.dart` (they still call `.main` and string-keyed setters from Phase 1). Tasks A4–E1 fix those. The store file itself should be clean.

If the store has errors, fix before moving on.

---

### Task A4: Add `Preferences` getter+setter for the chart engine session JSON

**Files:**
- Modify: `lib/locator/preference.dart`

- [ ] **Step 1: Find a location for the new methods**

Open the file. Find a block of similarly-shaped `setString` setters (around line 32 — `setAppTheme`). Add the new setter near them.

- [ ] **Step 2: Add the constant key**

Search for an existing private key constant (e.g. `static const String _clientId = 'clientId';` near the end of the class, or look for a `_userAppTheme` style). Add a new constant inside the class:

```dart
static const String _chartEngineSession = 'chartEngineSessionV1';
```

If the existing keys are top-level `String _userAppTheme = '...';`, follow whichever style is already in this file (be consistent).

- [ ] **Step 3: Add the typed accessors**

Add these two methods anywhere inside the `Preferences` class (convention: near `setAppTheme`):

```dart
Future setChartEngineSession(String json) async {
  await _prefInstance!.setString(_chartEngineSession, json);
}

String? getChartEngineSession() =>
    _prefInstance?.getString(_chartEngineSession);
```

- [ ] **Step 4: Static check**

Run: `flutter analyze lib/locator/preference.dart 2>&1 | tail -5`
Expected: `No issues found!` (or pre-existing warnings unrelated to our change).

---

### Task A5: Wire debounced persistence + restore into the notifier

**Files:**
- Modify: `lib/screens/web/chart_engine/state/chart_engine_store.dart`

- [ ] **Step 1: Add imports + helpers**

At the very top of the file, add:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
```

(Keep the existing `flutter_riverpod` import.)

- [ ] **Step 2: Update the notifier to persist + restore**

Find the `ChartEngineSessionNotifier` class. Replace its body with:

```dart
class ChartEngineSessionNotifier extends Notifier<ChartEngineSession> {
  Timer? _persistTimer;

  @override
  ChartEngineSession build() {
    // Hydrate from SharedPreferences on first build. Fall back to the
    // default on ANY error so a corrupted prefs entry can't brick the
    // chart engine.
    final raw = locator<Preferences>().getChartEngineSession();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return ChartEngineSession.fromJson(decoded);
        }
      } catch (_) {
        // fall through to default
      }
    }
    return const ChartEngineSession();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 200), _persist);
  }

  Future<void> _persist() async {
    try {
      final json = jsonEncode(state.toJson());
      await locator<Preferences>().setChartEngineSession(json);
    } catch (_) {
      // Persistence is best-effort; never block the UI.
    }
  }

  void setPaneSymbol(int index, ChartScrip scrip) {
    if (index < 0 || index >= state.panes.length) return;
    state = state.copyWithPane(index, state.panes[index].copyWith(scrip: scrip));
    _schedulePersist();
  }

  void setPaneTimeframe(int index, int minutes) {
    if (index < 0 || index >= state.panes.length) return;
    state = state.copyWithPane(
        index, state.panes[index].copyWith(timeframeMinutes: minutes));
    _schedulePersist();
  }

  void setPaneOverlays(int index, ChartOverlays overlays) {
    if (index < 0 || index >= state.panes.length) return;
    state = state.copyWithPane(
        index, state.panes[index].copyWith(overlays: overlays));
    _schedulePersist();
  }

  void setActivePane(int index) {
    if (index < 0 || index >= state.panes.length) return;
    if (index == state.activePaneIndex) return;
    state = state.copyWith(activePaneIndex: index);
    _schedulePersist();
  }

  void setLayout(ChartLayout next) {
    if (next == state.layout) return;
    final cur = state.panes;
    final activeIdx = state.activePaneIndex;
    final n = next.paneCount;
    final newPanes = <PaneState>[];
    int newActive;

    if (n >= cur.length) {
      newPanes.addAll(cur);
      for (var i = cur.length; i < n; i++) {
        newPanes.add(cur[activeIdx]);
      }
      newActive = activeIdx;
    } else {
      newPanes.add(cur[activeIdx]);
      for (var i = 0; i < cur.length; i++) {
        if (i == activeIdx) continue;
        if (newPanes.length >= n) break;
        newPanes.add(cur[i]);
      }
      newActive = 0;
    }

    state = state.copyWith(
      layout: next,
      panes: newPanes,
      activePaneIndex: newActive,
    );
    _schedulePersist();
  }
}
```

- [ ] **Step 3: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/state/chart_engine_store.dart 2>&1 | tail -5`
Expected: `No issues found!`

(Top bar + shell still call `.main` / String setters — Tasks A6 + E1 fix those.)

---

### Task A6: Patch Phase 1 call sites (`.main` and string-key setters) so analyze passes

**Files:**
- Modify: `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

This is a minimal interim patch — Tasks B/E will replace this with the real active-pane wiring. The goal is just to get analyze clean now so we can land Group A.

- [ ] **Step 1: Open `chart_engine_top_bar.dart`**

Find references to `pane`, `.main`, `setPaneSymbol('main'`, `setPaneTimeframe('main'`, `setPaneOverlays('main'`. Replace each as follows:

- `ref.watch(chartEngineSessionProvider).main` → `ref.watch(chartEngineSessionProvider).active`
- `notifier.setPaneSymbol('main', s)` → `notifier.setPaneSymbol(ref.read(chartEngineSessionProvider).activePaneIndex, s)`
- `notifier.setPaneTimeframe('main', m)` → `notifier.setPaneTimeframe(ref.read(chartEngineSessionProvider).activePaneIndex, m)`
- `notifier.setPaneOverlays('main', o)` → `notifier.setPaneOverlays(ref.read(chartEngineSessionProvider).activePaneIndex, o)`

For the `_SettingsButton` invocation (which currently reads `pane.overlays`), keep the existing pattern but the pane comes from `.active`.

- [ ] **Step 2: Open `chart_engine_shell_screen.dart`**

Find references to `session.main` or `.panes['main']`. Replace:

- `ref.read(chartEngineSessionProvider).main` → `ref.read(chartEngineSessionProvider).active`

In `_pushPane()` change the symbol/timeframe/overlay pushes to use `'0'` instead of `'main'` for the postMessage `paneId` (the iframe doesn't have `'main'` panes any more after Group C; for now this preserves Phase 1 behaviour through the interim because the iframe still calls `ensurePane('main')` until Group C lands):

Actually, to avoid breaking the iframe contract mid-refactor, keep using `'main'` here for one more task — Task C2 will switch the iframe to integer paneIds at the same time as Flutter starts emitting them. So for THIS task: change `.main` → `.active` only, leave the `'main'` literal in the postMessage payloads alone.

- [ ] **Step 3: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -10`
Expected: `No issues found!`

If something still references a removed identifier, grep for it and fix.

---

### Smoke Checkpoint — Group A

- [ ] Run `flutter run -d chrome --web-port 8080`.
- [ ] Open `/charts`. The chart should behave EXACTLY as Phase 1 did (single pane, NIFTY 1m default, all interactions working).
- [ ] Pick a different symbol (e.g. RELIANCE-EQ) → chart updates.
- [ ] Reload the browser tab → the chart re-opens on RELIANCE-EQ (state restored from SharedPreferences).
- [ ] Open DevTools → Application → Local Storage → confirm a `chartEngineSessionV1` key exists with the JSON we wrote.
- [ ] In DevTools, set that key's value to garbage (`{"foo":1}`) and reload → app starts fresh on single-pane NIFTY 1m and the key is overwritten with valid JSON.

If anything is broken, fix before continuing.

---

# Group B — Layout picker UI

End state: a layout picker button appears on the left of the top bar. Clicking it opens a popup with grouped icons. Clicking a layout icon updates the store and posts `setLayout` to the iframe (iframe ignores it until Group C). The store's grow/shrink rules apply correctly.

---

### Task B1: Create `lib/screens/web/chart_engine/widgets/layout_picker.dart`

**Files:**
- Create: `lib/screens/web/chart_engine/widgets/layout_picker.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';

/// Layout picker — button with the current-layout glyph; popup shows all
/// available layouts grouped by pane count (1, 2, 3, 4, 5, 6).
class LayoutPicker extends ConsumerStatefulWidget {
  final ValueChanged<bool> onPopupVisibilityChanged;
  const LayoutPicker({super.key, required this.onPopupVisibilityChanged});

  @override
  ConsumerState<LayoutPicker> createState() => _LayoutPickerState();
}

class _LayoutPickerState extends ConsumerState<LayoutPicker> {
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
    final current = ref.read(chartEngineSessionProvider).layout;
    final notifier = ref.read(chartEngineSessionProvider.notifier);

    // Group all layouts by paneCount (1..6).
    final groups = <int, List<ChartLayout>>{};
    for (final l in ChartLayout.values) {
      groups.putIfAbsent(l.paneCount, () => []).add(l);
    }
    final orderedCounts = groups.keys.toList()..sort();

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
        width: 280,
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
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final count in orderedCounts)
                      _Row(
                        label: count.toString(),
                        layouts: groups[count]!,
                        current: current,
                        onPicked: (l) {
                          notifier.setLayout(l);
                          _close();
                        },
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
    final current = ref.watch(chartEngineSessionProvider).layout;
    final border = shadcn.Theme.of(context).colorScheme.border;
    return CompositedTransformTarget(
      link: _link,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _entry == null ? _open() : _close(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(painter: _LayoutGlyph(current, _glyphColor(context))),
          ),
        ),
      ),
    );
  }
}

Color _glyphColor(BuildContext ctx) => resolveThemeColor(ctx,
    dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
Color _accent(BuildContext ctx) => resolveThemeColor(ctx,
    dark: MyntColors.primaryDark, light: MyntColors.primary);

class _Row extends StatelessWidget {
  final String label;
  final List<ChartLayout> layouts;
  final ChartLayout current;
  final ValueChanged<ChartLayout> onPicked;
  const _Row({
    required this.label,
    required this.layouts,
    required this.current,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(children: [
        SizedBox(
          width: 16,
          child: Text(label,
              style: TextStyle(
                fontSize: 11,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
              )),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final l in layouts)
                _Icon(
                  layout: l,
                  selected: l == current,
                  onTap: () => onPicked(l),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Icon extends StatelessWidget {
  final ChartLayout layout;
  final bool selected;
  final VoidCallback onTap;
  const _Icon({
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 32,
        height: 28,
        decoration: BoxDecoration(
          color: selected
              ? _accent(context).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? _accent(context) : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: CustomPaint(
          painter: _LayoutGlyph(layout,
              selected ? _accent(context) : _glyphColor(context)),
        ),
      ),
    );
  }
}

/// Parses a layout's grid-template-areas string and paints a miniature of
/// the layout. Each unique area letter is rendered as one cell with a
/// 1-pixel inner gap.
class _LayoutGlyph extends CustomPainter {
  final ChartLayout layout;
  final Color color;
  _LayoutGlyph(this.layout, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Parse areas: e.g. '"a a" "b c"' → [['a','a'],['b','c']]
    final rows = <List<String>>[];
    final raw = layout.areas;
    final quoted = RegExp(r'"([^"]+)"').allMatches(raw);
    for (final m in quoted) {
      rows.add(m.group(1)!.trim().split(RegExp(r'\s+')));
    }
    if (rows.isEmpty) return;
    final rowCount = rows.length;
    final colCount = rows[0].length;
    final cellW = size.width / colCount;
    final cellH = size.height / rowCount;

    // For each unique letter, find its bounding box in the grid and draw
    // one stroked rectangle.
    final seen = <String, Rect>{};
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        final letter = rows[r][c];
        final left = c * cellW;
        final top = r * cellH;
        final right = (c + 1) * cellW;
        final bottom = (r + 1) * cellH;
        final existing = seen[letter];
        if (existing == null) {
          seen[letter] = Rect.fromLTRB(left, top, right, bottom);
        } else {
          seen[letter] = Rect.fromLTRB(
            existing.left < left ? existing.left : left,
            existing.top < top ? existing.top : top,
            existing.right > right ? existing.right : right,
            existing.bottom > bottom ? existing.bottom : bottom,
          );
        }
      }
    }

    for (final rect in seen.values) {
      // Inset by 0.5 so the stroke sits on a pixel boundary, and add a 1px
      // gap between cells.
      final inset = rect.deflate(1.0);
      canvas.drawRect(inset, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutGlyph old) =>
      old.layout != layout || old.color != color;
}
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/widgets/layout_picker.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task B2: Integrate `LayoutPicker` into the top bar

**Files:**
- Modify: `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`

- [ ] **Step 1: Add the import**

At the top of the file:

```dart
import 'package:mynt_plus/screens/web/chart_engine/widgets/layout_picker.dart';
```

- [ ] **Step 2: Insert `LayoutPicker` as the first child of the `Wrap`**

Find the `children: [` of the `Wrap` inside `build`. Add this as the FIRST entry (before the Symbol Row):

```dart
LayoutPicker(onPopupVisibilityChanged: onPopupVisibilityChanged),
```

The Wrap children sequence becomes:
```dart
children: [
  LayoutPicker(onPopupVisibilityChanged: onPopupVisibilityChanged),
  Row(... Symbol …),
  Row(... Timeframe …),
  _SettingsButton(...),
],
```

- [ ] **Step 3: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -5`
Expected: `No issues found!`

---

### Smoke Checkpoint — Group B

- [ ] Hard-reload the browser tab.
- [ ] On `/charts`, see a small icon button on the left of the top bar showing a single rectangle (the `single` layout glyph).
- [ ] Click it → popup opens with rows labelled 1, 2, 3, 4, 5, 6 each showing layout icons.
- [ ] Hover any icon → highlight.
- [ ] Click `cols2` (2-pane row, left icon) → popup closes.
- [ ] **Nothing visible changes in the chart yet** — the iframe doesn't handle `setLayout` until Group C. But:
  - DevTools → React/Flutter Inspector → confirm `chartEngineSessionProvider` now has `layout: ChartLayout.cols2` and `panes.length == 2`.
  - Reload the page → the picker icon reflects `cols2`, indicating persistence works.
- [ ] Click `single` to reset.

---

# Group C — JS engine layout handling

End state: iframe applies layouts by rearranging the CSS grid and creating/destroying `Chart` instances. Active pane highlight works.

---

### Task C1: Add `encodeSetLayout` + `encodeSetActivePane` to the bridge

**Files:**
- Modify: `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart`

- [ ] **Step 1: Add two new encoders**

Add at the end of the file (after the last `encode*` function):

```dart
String encodeSetLayout({
  required String id,
  required String areas,
  required String rows,
  required String columns,
  required int paneCount,
}) =>
    jsonEncode({
      'type': 'setLayout',
      'value': {
        'id': id,
        'areas': areas,
        'rows': rows,
        'columns': columns,
        'paneCount': paneCount,
      },
    });

String encodeSetActivePane(String paneId) =>
    jsonEncode({'type': 'setActivePane', 'value': {'paneId': paneId}});
```

- [ ] **Step 2: Static check**

Run: `flutter analyze lib/screens/web/chart_engine/utils/chart_engine_bridge.dart 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task C2: Update shell screen to push layout + active pane + N-pane state

**Files:**
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Replace the tracking fields**

Find the existing per-pane tracking fields:

```dart
String? _pushedSymbolKey;
int? _pushedTimeframe;
String? _pushedOverlaysJson;
```

Replace with maps so we can track N panes:

```dart
String? _pushedLayoutId;
String? _pushedActivePaneId;
final Map<int, String> _pushedSymbolKey = {};
final Map<int, int> _pushedTimeframe = {};
final Map<int, String> _pushedOverlaysJson = {};
```

- [ ] **Step 2: Add the `paneActivated` inbound handler**

Find the `switch (msg['type'])` in `_onWindowMessage`. Add a new case:

```dart
case 'paneActivated':
  final v = msg['value'];
  if (v is Map) {
    final pid = v['paneId'];
    if (pid is String) {
      final idx = int.tryParse(pid);
      if (idx != null) {
        ref.read(chartEngineSessionProvider.notifier).setActivePane(idx);
      }
    }
  }
  break;
```

- [ ] **Step 3: Replace `_pushPane` with `_pushSession`**

Find `_pushAll` and the existing `_pushPane`. Replace `_pushPane` entirely with:

```dart
void _pushSession({bool force = false}) {
  if (!_iframeReady) return;
  final session = ref.read(chartEngineSessionProvider);

  // Layout — push first so the iframe creates the panes before per-pane
  // state arrives.
  if (force || session.layout.id != _pushedLayoutId) {
    _pushedLayoutId = session.layout.id;
    _post(encodeSetLayout(
      id: session.layout.id,
      areas: session.layout.areas,
      rows: session.layout.rows,
      columns: session.layout.columns,
      paneCount: session.layout.paneCount,
    ));
    // Layout change recreates panes — invalidate per-pane cache.
    _pushedSymbolKey.clear();
    _pushedTimeframe.clear();
    _pushedOverlaysJson.clear();
  }

  // Per-pane state.
  for (var i = 0; i < session.panes.length; i++) {
    final pane = session.panes[i];
    if (pane.scrip != null) {
      final key = '${pane.scrip!.exch}|${pane.scrip!.token}';
      if (force || _pushedSymbolKey[i] != key) {
        _pushedSymbolKey[i] = key;
        _post(encodeSetPaneSymbol(i.toString(), pane.scrip!.toJson()));
      }
    }
    if (force || _pushedTimeframe[i] != pane.timeframeMinutes) {
      _pushedTimeframe[i] = pane.timeframeMinutes;
      _post(encodeSetPaneTimeframe(i.toString(), pane.timeframeMinutes));
    }
    final overlaysJson = jsonEncode(pane.overlays.toJson());
    if (force || _pushedOverlaysJson[i] != overlaysJson) {
      _pushedOverlaysJson[i] = overlaysJson;
      _post(encodeSetOverlays(i.toString(), pane.overlays.toJson()));
    }
  }

  // Active pane highlight.
  final activeId = session.activePaneIndex.toString();
  if (force || _pushedActivePaneId != activeId) {
    _pushedActivePaneId = activeId;
    _post(encodeSetActivePane(activeId));
  }
}
```

Update `_pushAll` to call `_pushSession`:

```dart
void _pushAll({bool force = false}) {
  _pushTheme(force: force);
  _pushSession(force: force);
}
```

Find any remaining references to the old `_pushPane()` and delete them. The `build()` method's `addPostFrameCallback` already calls `_pushAll`, which now dispatches the new logic.

- [ ] **Step 4: Static check**

Run: `flutter analyze lib/screens/web/chart_engine 2>&1 | tail -5`
Expected: `No issues found!`

---

### Task C3: Update `chart-engine.js` to handle `setLayout` + `setActivePane` + use integer paneIds

**Files:**
- Modify: `web/chart-engine/chart-engine.js`

- [ ] **Step 1: Replace the boot/default pane creation**

Find `function boot()` and the call to `ensurePane('main')`. Replace `boot` with:

```javascript
function boot() {
  applyTheme(THEME);
  // No default pane — wait for the first setLayout from Flutter.
  // (Flutter's shell ALWAYS posts setLayout on the ready handshake.)
  postToParent({ type: 'chart-engine-ready' });
}
```

- [ ] **Step 2: Replace the `setLayout` message handler stub**

Inside `handleMessage`, find the existing `case 'setLayout':` (if present) or add it to the switch. Make sure the case body is:

```javascript
case 'setLayout': {
  const v = d.value || {};
  if (typeof v.paneCount !== 'number' || v.paneCount < 1) return;
  applyLayout(v);
  break;
}
case 'setActivePane': {
  const v = d.value || {};
  if (typeof v.paneId !== 'string') return;
  applyActivePane(v.paneId);
  break;
}
```

- [ ] **Step 3: Replace `ensurePane` and add the layout reconciler**

Delete the current `ensurePane(paneId)` function. Add this block in its place:

```javascript
// ---------------------------------------------------------------------------
// Layout reconciliation
// ---------------------------------------------------------------------------
function applyLayout(spec) {
  const layout = document.getElementById('layout');
  layout.style.gridTemplateAreas = spec.areas;
  layout.style.gridTemplateRows = spec.rows;
  layout.style.gridTemplateColumns = spec.columns;
  layout.style.display = 'grid';

  // Determine desired pane ids ('0'..paneCount-1) and area letters.
  const desired = [];
  for (let i = 0; i < spec.paneCount; i++) {
    desired.push({
      id: String(i),
      letter: String.fromCharCode('a'.charCodeAt(0) + i),
    });
  }

  // Destroy panes that are no longer desired.
  const desiredIds = new Set(desired.map((d) => d.id));
  for (const id of Array.from(panes.keys())) {
    if (!desiredIds.has(id)) {
      const chart = panes.get(id);
      try { chart.destroy(); } catch (_) {}
      panes.delete(id);
      const el = document.getElementById('pane-' + id);
      if (el && el.parentNode) el.parentNode.removeChild(el);
      // Clean tokenToPanes references.
      for (const [k, set] of Array.from(tokenToPanes.entries())) {
        if (set.has(id)) {
          set.delete(id);
          if (set.size === 0) tokenToPanes.delete(k);
        }
      }
    }
  }

  // Create or reuse panes in the desired order.
  for (const { id, letter } of desired) {
    let container = document.getElementById('pane-' + id);
    if (!container) {
      container = document.createElement('div');
      container.className = 'pane';
      container.id = 'pane-' + id;
      layout.appendChild(container);
    }
    container.style.gridArea = letter;
    if (!panes.has(id)) {
      panes.set(id, buildChart(container, id));
    }
  }
}

function buildChart(container, paneId) {
  return new Chart({
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
}

function applyActivePane(paneId) {
  for (const el of document.querySelectorAll('.pane')) {
    el.classList.toggle('active', el.id === 'pane-' + paneId);
  }
}
```

- [ ] **Step 4: Update `setPaneSymbol`, `setPaneTimeframe`, `setOverlays` handlers to look up panes by id without auto-creating**

Find each existing case in `handleMessage` and replace:

```javascript
case 'setPaneSymbol': {
  const { paneId, scrip } = d.value || {};
  if (!paneId || !scrip) return;
  const chart = panes.get(paneId);
  if (chart) chart.setSymbol(scrip);
  break;
}
case 'setPaneTimeframe': {
  const { paneId, minutes } = d.value || {};
  if (!paneId || typeof minutes !== 'number') return;
  const chart = panes.get(paneId);
  if (chart) chart.setTimeframe(minutes);
  break;
}
case 'setOverlays': {
  const { paneId, ...flags } = d.value || {};
  if (paneId) {
    const chart = panes.get(paneId);
    if (chart) chart.setOverlays(flags);
  } else {
    for (const chart of panes.values()) chart.setOverlays(flags);
  }
  break;
}
```

The key change: panes are NEVER auto-created here. The layout reconciler is the only thing that creates panes. If a per-pane message arrives for a non-existent pane (race condition), it's silently dropped.

- [ ] **Step 5: Static check**

Run: `node --check web/chart-engine/chart-engine.js 2>&1`
Expected: no output.

---

### Task C4: Add `--accent` CSS variable + `.pane.active` highlight

**Files:**
- Modify: `web/chart-engine/style.css`

- [ ] **Step 1: Add the accent variable to both themes**

Find the `:root { ... }` block. Add inside it:

```css
  --accent: #3B82F6;
```

Find the `html.light { ... }` block. Add inside it:

```css
  --accent: #2563EB;
```

- [ ] **Step 2: Add the `.pane.active` highlight**

Find the `.pane { ... }` block. Add this rule directly after it:

```css
.pane.active {
  box-shadow: inset 0 0 0 2px var(--accent);
}
```

No static check needed for CSS — visual smoke catches errors.

---

### Smoke Checkpoint — Group C

- [ ] Hard-reload the browser tab.
- [ ] Open `/charts`. Single-pane NIFTY 1m loads as before.
- [ ] Click the layout picker → pick `cols2` → see 2 panes side-by-side, both NIFTY 1m (the second copies the active).
- [ ] Pick `grid2x2` → 4 panes appear, all NIFTY 1m.
- [ ] Pick `l1r2` → 3 panes in asymmetric layout (left tall, right 2 stacked).
- [ ] Pick `single` → 4 panes collapse to 1, the active pane (top-left, since we haven't implemented click-to-focus yet) survives.
- [ ] Reload the tab → layout persists.

If a layout looks visually broken (e.g. asymmetric one), check the grid-template-areas string in the enum.

---

# Group D — Click-to-focus

End state: clicking a pane highlights it with the accent border. The top bar's pickers now operate on the newly-active pane.

---

### Task D1: `chart.js` — post `paneActivated` on mousedown

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add `parent.postMessage` at the top of the mousedown handler**

Find `_attachInteraction`. Inside it, find the existing `wrap.addEventListener('mousedown', (e) => {` line. Right inside the handler body, BEFORE any other logic, add:

```javascript
      // Notify parent so it can mark this pane as active. Fire on every
      // mousedown, even ones that don't end in a drag.
      try {
        parent.postMessage(
            JSON.stringify({ type: 'paneActivated', value: { paneId: this.paneId } }),
            '*');
      } catch (_) {}
```

The handler now starts:

```javascript
    wrap.addEventListener('mousedown', (e) => {
      try {
        parent.postMessage(
            JSON.stringify({ type: 'paneActivated', value: { paneId: this.paneId } }),
            '*');
      } catch (_) {}
      const rect = wrap.getBoundingClientRect();
      // ... existing logic continues
```

- [ ] **Step 2: Static check**

Run: `node --check web/chart-engine/chart.js 2>&1`
Expected: no output.

---

### Smoke Checkpoint — Group D

- [ ] Hard-reload the browser tab.
- [ ] On `/charts`, switch to a multi-pane layout (e.g. `cols2`).
- [ ] Click the right pane → its border lights up blue (accent), the left pane loses its highlight.
- [ ] In the top bar, change the Symbol to RELIANCE-EQ → **only the right pane changes**; the left pane stays NIFTY.
- [ ] Click the left pane → highlight moves; subsequent symbol changes affect the left pane only.

If clicking a pane doesn't move the active border, check DevTools console for `paneActivated` postMessage flow.

---

# Group E — Per-pane chip in chart

End state: each pane's OHLC strip is prefixed with `SYMBOL · TIMEFRAME` so the user can identify panes at a glance without hovering.

---

### Task E1: `chart.js` — add `_drawPaneChip` and call it from `_drawOhlc`

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add the chip method**

Find `_drawOhlc` in the `Chart` class. Add this new method directly ABOVE it:

```javascript
  _drawPaneChip(plot) {
    if (!this.scrip) return 0;
    const tf = this._formatTimeframeLabel(this.timeframeMinutes);
    const text = (this.scrip.dispName || this.scrip.tsym || '') + ' · ' + tf;
    this.ctx.font = '700 11px Geist, sans-serif';
    this.ctx.textBaseline = 'middle';
    this.ctx.fillStyle = this.palette.axisTextStrong;
    this.ctx.textAlign = 'left';
    this.ctx.fillText(text, plot.left + 4, 14);
    return this.ctx.measureText(text).width + 12;
  }

  _formatTimeframeLabel(m) {
    if (m % 1440 === 0) return (m / 1440) + 'D';
    if (m % 60 === 0) return (m / 60) + 'h';
    return m + 'm';
  }
```

- [ ] **Step 2: Modify `_drawOhlc` to offset by the chip width**

Find the start of the existing `_drawOhlc(plot)` body. Replace the `let x = plot.left + 4;` initialization to push past the chip:

Before:
```javascript
    let x = plot.left + 4;
    const y = 14;
```

After:
```javascript
    let x = plot.left + 4 + this._drawPaneChip(plot);
    const y = 14;
```

- [ ] **Step 3: Update the OHLC opaque-background fill to cover the chip too**

Find the existing background fill in `_drawOhlc`:

```javascript
    let totalW = 0;
    for (const [label, value] of segs) {
      totalW += this.ctx.measureText(label).width + 4;
      totalW += this.ctx.measureText(value).width + 12;
    }
    this.ctx.fillStyle = this.palette.bg;
    this.ctx.fillRect(plot.left, 0, totalW + 8, 24);
```

Replace with (now measures the chip text too, BEFORE drawing the chip):

```javascript
    // Measure first: chip (if any) + OHLC labels/values.
    let totalW = 0;
    if (this.scrip) {
      this.ctx.font = '700 11px Geist, sans-serif';
      const chipText = (this.scrip.dispName || this.scrip.tsym || '') +
          ' · ' + this._formatTimeframeLabel(this.timeframeMinutes);
      totalW += this.ctx.measureText(chipText).width + 12;
    }
    this.ctx.font = '600 11px Geist, sans-serif';
    for (const [label, value] of segs) {
      totalW += this.ctx.measureText(label).width + 4;
      totalW += this.ctx.measureText(value).width + 12;
    }
    this.ctx.fillStyle = this.palette.bg;
    this.ctx.fillRect(plot.left, 0, totalW + 8, 24);
```

(The font reset between the two measure passes ensures each `measureText` is using the right font.)

- [ ] **Step 4: Static check**

Run: `node --check web/chart-engine/chart.js 2>&1`
Expected: no output.

---

### Smoke Checkpoint — Group E (also Phase 2 final UX smoke)

- [ ] Hard-reload the browser tab.
- [ ] On `/charts`, switch to `grid2x2`. Each pane's OHLC strip is now prefixed with `NIFTY · 1m` (or whatever its current symbol+timeframe).
- [ ] Click pane 3 (bottom-right) → it becomes active. Change symbol to BANKNIFTY → only pane 3 updates; its chip now reads `BANKNIFTY · 1m`.
- [ ] Click pane 0 → its chip reads `NIFTY · 1m`. Change timeframe to 5m → only pane 0's chip + chart update; chip reads `NIFTY · 5m`.
- [ ] Change pane 0 timeframe to `1D` → chip reads `NIFTY · 1D`. Custom timeframe `45` → chip reads `NIFTY · 45m`.

---

# Group F — Final analyze + Phase 2 smoke

End state: every code path passes static checks and the full spec §7 smoke list passes.

---

### Task F1: Static gates

- [ ] **Step 1: Flutter analyze**

Run: `flutter analyze lib/screens/web/chart_engine lib/locator/preference.dart 2>&1 | tail -10`
Expected: `No issues found!`

- [ ] **Step 2: JS syntax checks**

Run: `node --check web/chart-engine/chart-engine.js web/chart-engine/chart.js web/chart-engine/aggregator.js web/chart-engine/theme.js 2>&1`
Expected: no output for any of the four files.

- [ ] **Step 3: Aggregator tests still green**

Run: `node web/chart-engine/aggregator.test.js 2>&1 | tail -3`
Expected: `15 passed · 0 failed`.

---

### Task F2: Phase 2 manual smoke (from spec §7)

Hard-reload the browser tab and execute end-to-end:

- [ ] Open `/charts` → see single-pane NIFTY 1m (or last-saved layout).
- [ ] Layout picker shows ~23 layout icons grouped 1/2/3/4/5/6 by row.
- [ ] Click `cols2` → 2 side-by-side panes both showing NIFTY 1m.
- [ ] Click the right pane → border lights blue. Change Symbol to RELIANCE-EQ → right pane updates, left pane stays NIFTY.
- [ ] Click `grid2x2` → 4 panes (left 2 still NIFTY+RELIANCE in slots 0+1, slots 2+3 copy active pane).
- [ ] Click `single` → only the active pane survives.
- [ ] Click `l1r2` → asymmetric layout (left tall, right 2 stacked).
- [ ] Each pane's chip shows correct `SYMBOL · TIMEFRAME`.
- [ ] Reload the browser tab → layout + per-pane symbols + active pane restore exactly.
- [ ] DevTools → Application → Local Storage → manually corrupt the `chartEngineSessionV1` value to `{"bad":1}` → reload → app starts fresh single-pane NIFTY + bad data overwritten.
- [ ] Toggle app theme → all panes' canvases AND the active-pane highlight colour update.
- [ ] Navigate to /home and back to /charts → state intact, no white flash.
- [ ] Live ticks (during market hours) update every pane showing that symbol.

If everything passes, Phase 2 is done.

---

## Notes for the executing engineer

- **Do not commit at any point.** User reviews and commits the whole phase manually.
- **Run JS files through `node --check` after EVERY edit.** A typo in `chart-engine.js` can break the whole iframe with no visible UI error.
- **Hard-reload the browser tab** after every JS change — Flutter hot reload doesn't pick up changes in `web/chart-engine/`.
- **`paneActivated` fires on every mousedown** — including the start of a drag. That's intentional: the click-to-focus and the drag-pan are independent gestures, just sharing a mousedown.
- **The default `paneCount: 1` layout** means a fresh user (no prefs) starts in `single`. Migration from Phase 1's `'main'`-keyed prefs is implicit: the old format will fail JSON-decode against the new schema, fall through to default, and overwrite. That's the chosen behaviour (no per-symbol bridge needed).
- **Pause and ask** if you hit any of these:
  - `Preferences` doesn't expose the SharedPreferences instance the way Task A4 assumes — the existing code in that file shows the pattern.
  - A layout icon glyph renders incorrectly — the `_LayoutGlyph` parser may need tweaks for the asymmetric layouts (e.g. `t2b3` which uses a 6-column grid). Hand-test by setting that layout's icon in isolation.
  - The user's existing chart layout from a previous session isn't restored after Task A5 — check that `Preferences.init()` was called before the chart engine builds (it normally runs in `main.dart` during app startup).
