# Chart Engine — Phase 16 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 6 new per-pane chart styles (Hollow, OHLC Bars, Line, Area, Heikin-Ashi, Renko) selectable from the Settings popup, plus visible-range High / Low markers (chip + dashed leader). Both fields persist per pane.

**Architecture:** Two new per-pane fields on `PaneState` (`candleStyle`, `showHighLowMarkers`). Plumbed through the existing bridge pattern — two new per-field encoders, two new message handlers in `chart-engine.js`, two new setters on the `Chart` class. Five simple styles share `bars[]` (render-only). Renko gets a dedicated `_renkoBricks[]` pipeline with ATR-based brick size, incremental tick updates, and a brick-size round-trip via a new `paneRenkoBrickSize` message back to Flutter so the Settings popup can show the live brick size as a subtitle.

**Tech Stack:** Flutter Web (Riverpod 3.x `Notifier`), `dart:html` postMessage bridge, vanilla JS / Canvas 2D inside an iframe at `/chart-engine/index.html`. No new dependencies.

**Project rules (CRITICAL — apply to every task):**

- **NO git commits anywhere.** User commits manually after testing. Skip every `git add` / `git commit` / `git push` step.
- Static gate after every code-touching task: `flutter analyze lib/screens/web/chart_engine` for Dart edits; `node --check web/chart-engine/<file>.js` for JS edits. Do not move on if either reports errors.
- Manual smoke checkpoints between groups — pause and let the user run them.
- No Jest / widget tests. The repo has no JS test harness for `chart.js` or `chart-engine.js`, and Dart widget tests aren't the norm in this codebase. Static gates + manual smoke are the verification.
- Riverpod 3.x — `Notifier` / `NotifierProvider`, never the legacy `StateNotifier` API.
- Mirror Phase 15's `instantOverride` pattern for the data-model work — it's the most recent example of the exact same shape.

**Files touched (high-level):**

| File | Purpose |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | Two new `PaneState` fields, sentinel `copyWith`, omit-default JSON, two notifier methods |
| `lib/screens/web/chart_engine/state/pane_runtime_status.dart` (NEW) | Transient notifier holding `Map<int, double> renkoBrickSizeByPane` so the popup can render the subtitle |
| `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart` | Two new encoders |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | Inbound `paneRenkoBrickSize` handler → write to the runtime status notifier. Outbound: extend `_pushSessionInner` with two new push-cache fields + emit the two new encoders. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | Two new rows at the top of the Settings popup: `_PaneChartStyleSection` dropdown + `_PaneHighLowMarkersSection` switch |
| `web/chart-engine/chart-engine.js` | Two new inbound message handlers; one new outbound callback wired into `new Chart({ notifyBrickSize })` |
| `web/chart-engine/chart.js` | Per-pane `candleStyle` + `showHighLowMarkers` state. New draw functions (`_drawCandlesHollow`, `_drawBarsOHLC`, `_drawLine`, `_drawArea`, `_drawCandlesHeikinAshi`). Renko pipeline (`_renkoBricks`, `_computeRenkoBrickSize`, `_rebuildRenko`, `_updateRenkoFromTick`, `_drawRenko`). H/L scanner + drawer (`_drawHighLowMarkers`). Style routing switch at the top of the current candle-draw block. Indicator series swap on Renko. Volume hide on Renko. Crosshair tooltip variant on Renko. Drawing hide-list on Renko. |

---

## Group A — Data model & persistence

Adds the per-pane fields, notifier methods, and a transient runtime-status notifier for the Renko brick size echo.

### Task A1: `PaneState.candleStyle` field + sentinel `copyWith`

**Files:**
- Modify: `lib/screens/web/chart_engine/state/chart_engine_store.dart` (`PaneState` class, ~line 196-264)

- [ ] **Step 1: Add the field, constructor param, and sentinel `copyWith`**

Modify the `PaneState` class. Add `candleStyle` next to `instantOverride`. Extend `copyWith` with a plain default parameter (no sentinel — empty string is not valid):

```dart
class PaneState {
  final ChartScrip? scrip;
  final int timeframeMinutes;
  final ChartOverlays overlays;
  final int qty;
  final List<IndicatorConfig> indicators;
  final String? instantOverride;
  // Phase 16 — one of: 'candles' (default), 'hollow', 'bars', 'line',
  // 'area', 'heikin-ashi', 'renko'. Unknown values are coerced to 'candles'
  // by fromJson so a typo in prefs can't poison the chart.
  final String candleStyle;

  const PaneState({
    this.scrip,
    this.timeframeMinutes = 1,
    this.overlays = const ChartOverlays(),
    this.qty = 1,
    this.indicators = const [],
    this.instantOverride,
    this.candleStyle = 'candles',
  });

  PaneState copyWith({
    Object? scrip = _sentinel,
    int? timeframeMinutes,
    ChartOverlays? overlays,
    int? qty,
    List<IndicatorConfig>? indicators,
    Object? instantOverride = _sentinel,
    String? candleStyle,
  }) =>
      PaneState(
        scrip: identical(scrip, _sentinel) ? this.scrip : scrip as ChartScrip?,
        timeframeMinutes: timeframeMinutes ?? this.timeframeMinutes,
        overlays: overlays ?? this.overlays,
        qty: qty ?? this.qty,
        indicators: indicators ?? this.indicators,
        instantOverride: identical(instantOverride, _sentinel)
            ? this.instantOverride
            : instantOverride as String?,
        candleStyle: candleStyle ?? this.candleStyle,
      );
```

- [ ] **Step 2: `toJson` omits-default + `fromJson` coerces unknown values**

Add to `toJson` (only emit when non-default, matching `instantOverride`):

```dart
Map<String, dynamic> toJson() => {
      if (scrip != null) 'scrip': scrip!.toJson(),
      'timeframeMinutes': timeframeMinutes,
      'overlays': overlays.toJson(),
      'qty': qty,
      'indicators': [for (final i in indicators) i.toJson()],
      if (instantOverride != null) 'instantOverride': instantOverride,
      if (candleStyle != 'candles') 'candleStyle': candleStyle,
    };
```

Replace the `return PaneState(...)` block at the end of `fromJson` to coerce unknown styles:

```dart
static const _validStyles = <String>{
  'candles', 'hollow', 'bars', 'line', 'area', 'heikin-ashi', 'renko',
};

static PaneState fromJson(Map<String, dynamic> j) {
  final rawOverride = j['instantOverride'];
  final String? override =
      (rawOverride == 'on' || rawOverride == 'off') ? rawOverride : null;
  final rawStyle = j['candleStyle'] as String?;
  final String style =
      (rawStyle != null && _validStyles.contains(rawStyle)) ? rawStyle : 'candles';
  return PaneState(
    scrip: j['scrip'] is Map
        ? ChartScrip.fromJson(j['scrip'] as Map<String, dynamic>)
        : null,
    timeframeMinutes: (j['timeframeMinutes'] as num?)?.toInt() ?? 1,
    overlays: j['overlays'] is Map
        ? ChartOverlays.fromJson(j['overlays'] as Map<String, dynamic>)
        : const ChartOverlays(),
    qty: (j['qty'] as num?)?.toInt() ?? 1,
    indicators: [
      for (final i in (j['indicators'] as List? ?? const []))
        IndicatorConfig.fromJson(i as Map<String, dynamic>),
    ],
    instantOverride: override,
    candleStyle: style,
  );
}
```

- [ ] **Step 3: Run static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

### Task A2: `PaneState.showHighLowMarkers` field

**Files:**
- Modify: `lib/screens/web/chart_engine/state/chart_engine_store.dart` (`PaneState` class)

- [ ] **Step 1: Add the field, constructor param, `copyWith`, JSON round-trip**

Add `showHighLowMarkers` to the field list (next to `candleStyle`):

```dart
final String candleStyle;
// Phase 16 — toggles the visible-range H/L chip markers. Default ON.
final bool showHighLowMarkers;
```

Add to the constructor params:
```dart
this.candleStyle = 'candles',
this.showHighLowMarkers = true,
```

Add to `copyWith` (plain default — no sentinel; `bool?` already encodes "unchanged"):
```dart
String? candleStyle,
bool? showHighLowMarkers,
```
…
```dart
candleStyle: candleStyle ?? this.candleStyle,
showHighLowMarkers: showHighLowMarkers ?? this.showHighLowMarkers,
```

Extend `toJson` to omit-default:
```dart
if (candleStyle != 'candles') 'candleStyle': candleStyle,
if (showHighLowMarkers != true) 'showHighLowMarkers': showHighLowMarkers,
```

Extend `fromJson` (just before the closing `return PaneState(...)`):
```dart
final bool show = j['showHighLowMarkers'] as bool? ?? true;
```
And inside the constructor call:
```dart
candleStyle: style,
showHighLowMarkers: show,
```

- [ ] **Step 2: Run static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

### Task A3: Two notifier methods

**Files:**
- Modify: `lib/screens/web/chart_engine/state/chart_engine_store.dart` (`ChartEngineSessionNotifier`)

- [ ] **Step 1: Add both methods next to `setPaneInstantOverride`**

```dart
/// Phase 16 — set the per-pane chart style. Unknown values are coerced to
/// `'candles'` so callers can't poison persistence.
void setPaneCandleStyle(int index, String style) {
  if (index < 0 || index >= state.panes.length) return;
  const valid = <String>{
    'candles', 'hollow', 'bars', 'line', 'area', 'heikin-ashi', 'renko',
  };
  final normalized = valid.contains(style) ? style : 'candles';
  final pane = state.panes[index];
  if (pane.candleStyle == normalized) return;
  state = state.copyWithPane(index, pane.copyWith(candleStyle: normalized));
  _schedulePersist();
}

/// Phase 16 — toggle the visible-range H/L markers for one pane.
void setPaneShowHighLowMarkers(int index, bool show) {
  if (index < 0 || index >= state.panes.length) return;
  final pane = state.panes[index];
  if (pane.showHighLowMarkers == show) return;
  state = state.copyWithPane(
      index, pane.copyWith(showHighLowMarkers: show));
  _schedulePersist();
}
```

- [ ] **Step 2: Run static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

### Task A4: New `PaneRuntimeStatusNotifier` for Renko brick-size echo

**Files:**
- Create: `lib/screens/web/chart_engine/state/pane_runtime_status.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Transient (non-persisted) per-pane runtime status pushed FROM the iframe
/// back into Flutter. Today: just the live Renko brick size so the Settings
/// popup can render it as a subtitle under the chart-style dropdown.
class PaneRuntimeStatus {
  /// brickSize keyed by paneIndex; missing entry = unknown (e.g. pane isn't on Renko).
  final Map<int, double> renkoBrickSizeByPane;
  const PaneRuntimeStatus({this.renkoBrickSizeByPane = const {}});

  PaneRuntimeStatus copyWith({Map<int, double>? renkoBrickSizeByPane}) =>
      PaneRuntimeStatus(
          renkoBrickSizeByPane:
              renkoBrickSizeByPane ?? this.renkoBrickSizeByPane);
}

class PaneRuntimeStatusNotifier extends Notifier<PaneRuntimeStatus> {
  @override
  PaneRuntimeStatus build() => const PaneRuntimeStatus();

  void setRenkoBrickSize(int paneIndex, double brickSize) {
    if (paneIndex < 0) return;
    if (brickSize <= 0 || !brickSize.isFinite) return;
    final cur = state.renkoBrickSizeByPane[paneIndex];
    if (cur != null && (cur - brickSize).abs() < 1e-9) return;
    final next = Map<int, double>.from(state.renkoBrickSizeByPane);
    next[paneIndex] = brickSize;
    state = state.copyWith(renkoBrickSizeByPane: next);
  }

  void clearRenkoBrickSize(int paneIndex) {
    if (!state.renkoBrickSizeByPane.containsKey(paneIndex)) return;
    final next = Map<int, double>.from(state.renkoBrickSizeByPane)
      ..remove(paneIndex);
    state = state.copyWith(renkoBrickSizeByPane: next);
  }
}

final paneRuntimeStatusProvider =
    NotifierProvider<PaneRuntimeStatusNotifier, PaneRuntimeStatus>(
  PaneRuntimeStatusNotifier.new,
);
```

- [ ] **Step 2: Run static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

## Group B — Bridge encoders + shell screen push & echo handler

### Task B1: Add two outbound encoders

**Files:**
- Modify: `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart`

- [ ] **Step 1: Add both encoders next to `encodeSetShortcutsEnabled`**

```dart
String encodeSetPaneCandleStyle(String paneId, String style) =>
    jsonEncode({
      'type': 'setPaneCandleStyle',
      'value': {'paneId': paneId, 'style': style},
    });

String encodeSetPaneHighLowMarkers(String paneId, bool show) =>
    jsonEncode({
      'type': 'setPaneHighLowMarkers',
      'value': {'paneId': paneId, 'show': show},
    });
```

- [ ] **Step 2: Run static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

### Task B2: Extend `_pushSessionInner` with the two new pushes

**Files:**
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add the two cache fields next to the existing pushed-state caches**

Search for the existing per-pane cache declarations (`_pushedSymbolKey`, `_pushedTimeframe`, etc. — they sit near `_pushedShortcutsEnabled` on or around line 74). Add right next to them:

```dart
final Map<int, String> _pushedCandleStyle = {};
final Map<int, bool> _pushedShowHighLowMarkers = {};
```

- [ ] **Step 2: Invalidate the caches on layout change**

In `_pushSessionInner`, in the block that runs `_pushedSymbolKey.clear(); _pushedTimeframe.clear(); ...` after a layout change (around line 614-620), add:

```dart
_pushedCandleStyle.clear();
_pushedShowHighLowMarkers.clear();
```

- [ ] **Step 3: Push both fields per pane**

Inside the per-pane `for (var i = 0; i < session.panes.length; i++)` loop in `_pushSessionInner` (around line 624-651, alongside the existing `setPaneSymbol` / `setPaneTimeframe` / `setOverlays` / `setPaneQty` pushes), add at the bottom of that loop:

```dart
if (force || _pushedCandleStyle[i] != pane.candleStyle) {
  _pushedCandleStyle[i] = pane.candleStyle;
  _post(encodeSetPaneCandleStyle(i.toString(), pane.candleStyle));
}
if (force || _pushedShowHighLowMarkers[i] != pane.showHighLowMarkers) {
  _pushedShowHighLowMarkers[i] = pane.showHighLowMarkers;
  _post(encodeSetPaneHighLowMarkers(
      i.toString(), pane.showHighLowMarkers));
}
```

- [ ] **Step 4: Run static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

### Task B3: Inbound `paneRenkoBrickSize` handler

**Files:**
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` (`_onWindowMessage`, around line 165-460)

- [ ] **Step 1: Import the runtime-status provider**

Add to the imports block at the top of the file (mirroring existing `chart_engine_store.dart` import):

```dart
import 'state/pane_runtime_status.dart';
```

- [ ] **Step 2: Add the message case**

In `_onWindowMessage`'s `switch (msg['type'])`, add a new case (place it near `keyTimeframe` to keep keyboard / status pushes grouped):

```dart
case 'paneRenkoBrickSize': {
  final v = msg['value'];
  if (v is! Map) return;
  final paneIdStr = v['paneId'];
  final brickRaw = v['brickSize'];
  if (paneIdStr is! String) return;
  final idx = int.tryParse(paneIdStr);
  if (idx == null) return;
  final brick = (brickRaw is num) ? brickRaw.toDouble() : double.nan;
  if (!brick.isFinite || brick <= 0) {
    ref
        .read(paneRuntimeStatusProvider.notifier)
        .clearRenkoBrickSize(idx);
  } else {
    ref
        .read(paneRuntimeStatusProvider.notifier)
        .setRenkoBrickSize(idx, brick);
  }
  return;
}
```

- [ ] **Step 3: Run static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

## Group C — Settings popup UI

Adds the "Chart style" dropdown row and "Show H / L markers" Switch row at the top of the popup, both bound to the active pane.

### Task C1: `_PaneChartStyleSection` widget

**Files:**
- Modify: `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`

- [ ] **Step 1: Add the import**

Add at the top of the file (near the existing `state/chart_engine_store.dart` import):

```dart
import '../state/pane_runtime_status.dart';
```

- [ ] **Step 2: Add the widget**

Append at the bottom of the file (next to the existing `_PaneInstantOverrideSection` / `_OverrideButton` widgets):

```dart
/// Phase 16 — per-pane chart-style dropdown. Sits at the top of the Settings
/// popup. When the active pane's style is 'renko', a subtitle shows the live
/// brick size pushed back by chart.js via `paneRenkoBrickSize`.
class _PaneChartStyleSection extends ConsumerWidget {
  final int paneIndex;
  const _PaneChartStyleSection({required this.paneIndex});

  static const _items = <_StyleItem>[
    _StyleItem('candles',     'Candles',         Icons.candlestick_chart),
    _StyleItem('hollow',      'Hollow Candles',  Icons.crop_square),
    _StyleItem('bars',        'OHLC Bars',       Icons.bar_chart),
    _StyleItem('line',        'Line',            Icons.show_chart),
    _StyleItem('area',        'Area',            Icons.area_chart),
    _StyleItem('heikin-ashi', 'Heikin-Ashi',     Icons.view_week),
    _StyleItem('renko',       'Renko',           Icons.view_module),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) {
      return const SizedBox.shrink();
    }
    final current = session.panes[paneIndex].candleStyle;
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    final brickSize = ref
        .watch(paneRuntimeStatusProvider)
        .renkoBrickSizeByPane[paneIndex];
    final mute = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final selected = _items.firstWhere(
      (it) => it.id == current,
      orElse: () => _items.first,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
                child: Text('Chart style',
                    style: MyntWebTextStyles.body(context))),
            PopupMenuButton<String>(
              tooltip: '',
              initialValue: current,
              onSelected: (v) =>
                  notifier.setPaneCandleStyle(paneIndex, v),
              itemBuilder: (_) => [
                for (final it in _items)
                  PopupMenuItem<String>(
                    value: it.id,
                    child: Row(children: [
                      Icon(it.icon, size: 16,
                          color: it.id == current
                              ? resolveThemeColor(context,
                                  dark: MyntColors.primaryDark,
                                  light: MyntColors.primary)
                              : mute),
                      const SizedBox(width: 8),
                      Text(it.label),
                      if (it.id == current) ...[
                        const Spacer(),
                        const SizedBox(width: 8),
                        const Icon(Icons.check, size: 14),
                      ],
                    ]),
                  ),
              ],
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(selected.icon, size: 14, color: mute),
                const SizedBox(width: 6),
                Text(selected.label,
                    style: MyntWebTextStyles.body(context)),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down, size: 16, color: mute),
              ]),
            ),
          ]),
          if (current == 'renko' && brickSize != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                'brick size: ${brickSize.toStringAsFixed(2)}',
                style: MyntWebTextStyles.caption(context, color: mute),
              ),
            ),
        ],
      ),
    );
  }
}

class _StyleItem {
  final String id;
  final String label;
  final IconData icon;
  const _StyleItem(this.id, this.label, this.icon);
}
```

- [ ] **Step 3: Run static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

### Task C2: `_PaneHighLowMarkersSection` widget

**Files:**
- Modify: `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`

- [ ] **Step 1: Add the widget**

Append next to `_PaneChartStyleSection`:

```dart
/// Phase 16 — toggles visible-range H/L chip markers for the active pane.
class _PaneHighLowMarkersSection extends ConsumerWidget {
  final int paneIndex;
  const _PaneHighLowMarkersSection({required this.paneIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) {
      return const SizedBox.shrink();
    }
    final value = session.panes[paneIndex].showHighLowMarkers;
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(children: [
        Expanded(
            child: Text('Show H / L markers',
                style: MyntWebTextStyles.body(context))),
        Switch(
          value: value,
          onChanged: (v) =>
              notifier.setPaneShowHighLowMarkers(paneIndex, v),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 2: Run static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

### Task C3: Insert both rows at the top of the Settings popup

**Files:**
- Modify: `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` (`_SettingsButtonState._build`, around line 141-260)

- [ ] **Step 1: Insert the two rows at the top of the popup `Column`**

The popup's `Column.children` currently opens with a "Indicators" header `Padding(...)` (around line 145-150) followed by `_ToggleRow('Gridlines', ...)`. Replace the leading section so the new rows sit ABOVE the existing "Indicators" header:

```dart
child: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    // Phase 16 — chart style + H/L markers (per-pane).
    Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Text('Display',
          style: MyntWebTextStyles.caption(context,
              fontWeight: MyntFonts.semiBold)),
    ),
    _PaneChartStyleSection(paneIndex: activeIdx),
    _PaneHighLowMarkersSection(paneIndex: activeIdx),
    const SizedBox(height: 6),
    const Divider(height: 1),
    const SizedBox(height: 6),
    // Existing block follows unchanged.
    Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Text('Indicators',
          style: MyntWebTextStyles.caption(context,
              fontWeight: MyntFonts.semiBold)),
    ),
    _ToggleRow(
      label: 'Gridlines',
      value: overlays.gridlines,
      onChanged: (v) => notifier.setPaneOverlays(
          activeIdx, overlays.copyWith(gridlines: v)),
    ),
    // … rest of the existing children unchanged …
```

(Leave all subsequent rows — Gridlines / Volume / Instant orders / `_PaneInstantOverrideSection` / Keyboard shortcuts / `_IndicatorsSection` — untouched. Don't reorder anything below.)

- [ ] **Step 2: Run static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

### Smoke checkpoint α (after Group C — UI plumbing only, no chart-style rendering yet)

**Pause here.** Wait for the user to run this manually before continuing to Group D.

What to verify manually:
1. `flutter run -d chrome --web-port 8080`, navigate to `/charts`.
2. Open the Settings popup on the default pane. Confirm the new "Display" section appears at the top with "Chart style" (showing "Candles") and "Show H / L markers" (Switch ON by default).
3. Pick each of the 7 styles from the dropdown. The popup should close and the chart will still render as standard candles for now (no draw-side change yet), but the dropdown label should update to the picked style and re-opening Settings should show the new value selected.
4. Toggle "Show H / L markers" off → on. No visual change in chart yet (intentional).
5. Reload tab → the picked style + marker flag should persist (verify by re-opening Settings on the same pane).
6. Switch to `cols2` → confirm each pane shows its own (independent) values when Settings is opened from each pane's active state.

Anything broken at this point is a Group A-C plumbing issue (popup binding, persistence, push pipeline cache). Do not advance.

---

## Group D — `chart-engine.js` plumbing

Routes both new fields into each pane's `Chart` instance and wires the brick-size echo callback.

### Task D1: Two inbound message handlers

**Files:**
- Modify: `web/chart-engine/chart-engine.js` (`handleMessage` switch, around line 319-446)

- [ ] **Step 1: Add both case branches**

Place them next to `setPaneTimeframe` / `setPaneOverlays` to keep per-pane setters grouped (around line 346-368):

```js
case 'setPaneCandleStyle': {
  const { paneId, style } = d.value || {};
  if (typeof paneId !== 'string' || typeof style !== 'string') return;
  const chart = panes.get(paneId);
  if (chart) chart.setCandleStyle(style);
  break;
}
case 'setPaneHighLowMarkers': {
  const { paneId, show } = d.value || {};
  if (typeof paneId !== 'string' || typeof show !== 'boolean') return;
  const chart = panes.get(paneId);
  if (chart) chart.setShowHighLowMarkers(show);
  break;
}
```

- [ ] **Step 2: Wire the brick-size echo callback into `buildChart`**

Locate `function buildChart(container, paneId)` (around line 262-290). Add a 5th callback in the constructor opts:

```js
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
    // Phase 16 — Renko brick size echo. brickSize <= 0 / null means
    // "no longer renko" (Flutter will clear its cache for this pane).
    notifyBrickSize: (brickSize) => postToParent({
      type: 'paneRenkoBrickSize',
      value: { paneId, brickSize: brickSize == null ? 0 : brickSize },
    }),
  });
}
```

- [ ] **Step 3: Run static gate**

Run: `node --check web/chart-engine/chart-engine.js`
Expected: silent (no syntax errors).

---

## Group E — `chart.js` simple styles + style routing

The five render-only styles, plus the routing switch and per-pane state for both Phase 16 fields.

### Task E1: Constructor state + setters

**Files:**
- Modify: `web/chart-engine/chart.js` (`Chart` constructor + setters around line 27-205)

- [ ] **Step 1: Add the constructor params + defaults**

Extend the constructor signature and store the new callback + field defaults. Find:

```js
constructor({ container, paneId, palette, requestHistory, subscribe, unsubscribe }) {
```

Change to:

```js
constructor({ container, paneId, palette, requestHistory, subscribe, unsubscribe, notifyBrickSize }) {
  this._notifyBrickSize = typeof notifyBrickSize === 'function' ? notifyBrickSize : (() => {});
```

Then, near the existing `this.qty = 1;` initialiser (around line 39), add:

```js
// Phase 16 — chart style + H/L marker flag (mirror Flutter's PaneState).
this.candleStyle = 'candles';
this.showHighLowMarkers = true;
this._haPrev = null;          // {haOpen, haClose} cached between bars
this._renkoBricks = [];       // {idx, openPrice, closePrice, direction, sourceBarTime, sourceBarIndex}
this._renkoBrickSize = 0;     // ATR-derived, pushed back via _notifyBrickSize
```

- [ ] **Step 2: Add the two setters next to `setOverlays`**

Append after `setOverlays(flags)` (around line 198-202):

```js
setCandleStyle(style) {
  const valid = new Set(['candles','hollow','bars','line','area','heikin-ashi','renko']);
  const next = valid.has(style) ? style : 'candles';
  if (next === this.candleStyle) return;
  const wasRenko = this.candleStyle === 'renko';
  this.candleStyle = next;
  // Always reset HA cache so it starts clean on the next draw.
  this._haPrev = null;
  if (next === 'renko') {
    this._rebuildRenko();
    this._notifyBrickSize(this._renkoBrickSize);
  } else {
    this._renkoBricks = [];
    this._renkoBrickSize = 0;
    if (wasRenko) this._notifyBrickSize(0); // tell Flutter to clear the subtitle
  }
  this.scheduleRedraw();
}

setShowHighLowMarkers(show) {
  const v = show === true;
  if (v === this.showHighLowMarkers) return;
  this.showHighLowMarkers = v;
  this.scheduleRedraw();
}
```

- [ ] **Step 3: Run static gate**

Run: `node --check web/chart-engine/chart.js`
Expected: silent.

---

### Task E2: Style routing switch + simple-style draw helpers

**Files:**
- Modify: `web/chart-engine/chart.js` — replace the candle-draw block inside `draw()` (currently inline at lines ~1076-1091, immediately after the gridlines block and before the volume block)

- [ ] **Step 1: Replace the inline candle loop with a routing call**

Replace the existing block:

```js
// Candles. Find the visible candles' absolute index range once so we
// don't `indexOf` per candle.
const firstVisibleAbs = this.candles.indexOf(visible[0]);
for (let i = 0; i < visible.length; i++) {
  const c = visible[i];
  const absoluteIdx = firstVisibleAbs + i;
  const xCenter = this._candleXCenter(absoluteIdx, plot);
  const isBull = c.c >= c.o;
  const color = isBull ? this.palette.bull : this.palette.bear;
  this.ctx.fillStyle = color;
  this.ctx.fillRect(Math.round(xCenter), priceToY(c.h), 1, priceToY(c.l) - priceToY(c.h));
  const bodyTop = Math.min(priceToY(c.o), priceToY(c.c));
  const bodyBot = Math.max(priceToY(c.o), priceToY(c.c));
  const bodyW = Math.max(1, this.view.cellW - 2);
  this.ctx.fillRect(Math.round(xCenter - bodyW / 2), bodyTop, bodyW, Math.max(1, bodyBot - bodyTop));
}
```

with:

```js
// Phase 16 — style routing.
const firstVisibleAbs = this.candles.indexOf(visible[0]);
switch (this.candleStyle) {
  case 'line':        this._drawLineSeries(visible, firstVisibleAbs, plot, priceToY); break;
  case 'area':        this._drawAreaSeries(visible, firstVisibleAbs, plot, priceToY); break;
  case 'bars':        this._drawBarsOHLC(visible, firstVisibleAbs, plot, priceToY); break;
  case 'hollow':      this._drawCandlesCore(visible, firstVisibleAbs, plot, priceToY, {hollow: true}); break;
  case 'heikin-ashi': this._drawCandlesCore(visible, firstVisibleAbs, plot, priceToY, {heikinAshi: true}); break;
  case 'renko':       this._drawRenko(plot, priceToY); break;
  case 'candles':
  default:            this._drawCandlesCore(visible, firstVisibleAbs, plot, priceToY, {}); break;
}
```

- [ ] **Step 2: Add the `_drawCandlesCore` helper**

Append below the `draw()` function (anywhere alphabetical-ish — group with `_drawIndicators` / `_drawOverlays`). This handles standard, hollow, AND heikin-ashi paths in one routine:

```js
_drawCandlesCore(visible, firstVisibleAbs, plot, priceToY, opts) {
  const hollow = !!opts.hollow;
  const heikinAshi = !!opts.heikinAshi;
  let haOpenPrev = null;
  let haClosePrev = null;
  // Seed HA from the bar BEFORE the visible window so the visible run looks
  // continuous when the user pans.
  if (heikinAshi) {
    const seedIdx = Math.max(0, firstVisibleAbs - 1);
    if (seedIdx < this.candles.length) {
      const s = this.candles[seedIdx];
      haOpenPrev = (s.o + s.c) / 2;
      haClosePrev = (s.o + s.h + s.l + s.c) / 4;
    }
  }
  for (let i = 0; i < visible.length; i++) {
    const c = visible[i];
    let o = c.o, h = c.h, l = c.l, cl = c.c;
    if (heikinAshi) {
      const haClose = (c.o + c.h + c.l + c.c) / 4;
      const haOpen  = haOpenPrev == null ? (c.o + c.c) / 2 : (haOpenPrev + haClosePrev) / 2;
      const haHigh  = Math.max(c.h, haOpen, haClose);
      const haLow   = Math.min(c.l, haOpen, haClose);
      o = haOpen; h = haHigh; l = haLow; cl = haClose;
      haOpenPrev = haOpen; haClosePrev = haClose;
    }
    const absoluteIdx = firstVisibleAbs + i;
    const xCenter = this._candleXCenter(absoluteIdx, plot);
    const isBull = cl >= o;
    const color = isBull ? this.palette.bull : this.palette.bear;
    // Wick.
    this.ctx.fillStyle = color;
    this.ctx.fillRect(Math.round(xCenter), priceToY(h), 1, priceToY(l) - priceToY(h));
    // Body.
    const bodyTop = Math.min(priceToY(o), priceToY(cl));
    const bodyBot = Math.max(priceToY(o), priceToY(cl));
    const bodyW = Math.max(1, this.view.cellW - 2);
    const bodyH = Math.max(1, bodyBot - bodyTop);
    if (hollow && isBull) {
      this.ctx.strokeStyle = color;
      this.ctx.lineWidth = 1.25;
      this.ctx.strokeRect(
          Math.round(xCenter - bodyW / 2) + 0.5,
          bodyTop + 0.5, bodyW - 1, Math.max(1, bodyH - 1));
    } else {
      this.ctx.fillStyle = color;
      this.ctx.fillRect(Math.round(xCenter - bodyW / 2), bodyTop, bodyW, bodyH);
    }
  }
  // Persist HA tail so the next draw() picks up where we left off (only
  // matters when style stays HA and the user nudges via tick).
  if (heikinAshi) this._haPrev = { haOpen: haOpenPrev, haClose: haClosePrev };
}
```

- [ ] **Step 3: Add `_drawBarsOHLC`**

```js
_drawBarsOHLC(visible, firstVisibleAbs, plot, priceToY) {
  const tickLen = Math.max(2, Math.floor(this.view.cellW / 2));
  for (let i = 0; i < visible.length; i++) {
    const c = visible[i];
    const xCenter = Math.round(this._candleXCenter(firstVisibleAbs + i, plot));
    const isBull = c.c >= c.o;
    const color = isBull ? this.palette.bull : this.palette.bear;
    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = 1.2;
    this.ctx.beginPath();
    // Vertical H..L.
    this.ctx.moveTo(xCenter + 0.5, priceToY(c.h));
    this.ctx.lineTo(xCenter + 0.5, priceToY(c.l));
    // Open tick LEFT.
    const yo = priceToY(c.o);
    this.ctx.moveTo(xCenter - tickLen + 0.5, yo);
    this.ctx.lineTo(xCenter + 0.5, yo);
    // Close tick RIGHT.
    const yc = priceToY(c.c);
    this.ctx.moveTo(xCenter + 0.5, yc);
    this.ctx.lineTo(xCenter + tickLen + 0.5, yc);
    this.ctx.stroke();
  }
}
```

- [ ] **Step 4: Add `_drawLineSeries` and `_drawAreaSeries`**

```js
_drawLineSeries(visible, firstVisibleAbs, plot, priceToY) {
  if (visible.length === 0) return;
  this.ctx.strokeStyle = this.palette.accent || this.palette.bull;
  this.ctx.lineWidth = 1.5;
  this.ctx.beginPath();
  for (let i = 0; i < visible.length; i++) {
    const c = visible[i];
    const x = this._candleXCenter(firstVisibleAbs + i, plot);
    const y = priceToY(c.c);
    if (i === 0) this.ctx.moveTo(x, y);
    else this.ctx.lineTo(x, y);
  }
  this.ctx.stroke();
}

_drawAreaSeries(visible, firstVisibleAbs, plot, priceToY) {
  if (visible.length === 0) return;
  const stroke = this.palette.accent || this.palette.bull;
  // Build the line path.
  const xs = new Array(visible.length);
  const ys = new Array(visible.length);
  for (let i = 0; i < visible.length; i++) {
    xs[i] = this._candleXCenter(firstVisibleAbs + i, plot);
    ys[i] = priceToY(visible[i].c);
  }
  // Fill polygon.
  const grad = this.ctx.createLinearGradient(0, plot.top, 0, plot.bottom);
  grad.addColorStop(0, this._withAlpha(stroke, 0.35));
  grad.addColorStop(1, this._withAlpha(stroke, 0.02));
  this.ctx.fillStyle = grad;
  this.ctx.beginPath();
  this.ctx.moveTo(xs[0], plot.bottom);
  for (let i = 0; i < xs.length; i++) this.ctx.lineTo(xs[i], ys[i]);
  this.ctx.lineTo(xs[xs.length - 1], plot.bottom);
  this.ctx.closePath();
  this.ctx.fill();
  // Stroke on top.
  this.ctx.strokeStyle = stroke;
  this.ctx.lineWidth = 1.5;
  this.ctx.beginPath();
  for (let i = 0; i < xs.length; i++) {
    if (i === 0) this.ctx.moveTo(xs[i], ys[i]);
    else this.ctx.lineTo(xs[i], ys[i]);
  }
  this.ctx.stroke();
}
```

- [ ] **Step 5: Add the `_withAlpha` helper (next to `_drawAreaSeries`)**

```js
_withAlpha(hexOrRgba, a) {
  // Accept #RGB, #RRGGBB, or rgba(...) and return rgba with alpha override.
  const s = String(hexOrRgba || '').trim();
  if (s.startsWith('#')) {
    let r, g, b;
    if (s.length === 4) {
      r = parseInt(s[1] + s[1], 16);
      g = parseInt(s[2] + s[2], 16);
      b = parseInt(s[3] + s[3], 16);
    } else {
      r = parseInt(s.slice(1, 3), 16);
      g = parseInt(s.slice(3, 5), 16);
      b = parseInt(s.slice(5, 7), 16);
    }
    return `rgba(${r},${g},${b},${a})`;
  }
  const m = s.match(/^rgba?\(([^,]+),([^,]+),([^,]+)(?:,[^)]+)?\)$/);
  if (m) return `rgba(${m[1].trim()},${m[2].trim()},${m[3].trim()},${a})`;
  // Fallback — return as-is.
  return s;
}
```

- [ ] **Step 6: Add a stub `_drawRenko` (real impl in Group F)**

```js
_drawRenko(plot, priceToY) {
  // Filled in by Task F2 below. Stubbed here so the style switch in Task E2
  // is syntactically clean.
}
```

- [ ] **Step 7: Run static gate**

Run: `node --check web/chart-engine/chart.js`
Expected: silent.

---

### Smoke checkpoint β (after Group E)

**Pause here.** Wait for the user.

What to verify manually:
1. Reload `/charts`. Default pane still renders Candles correctly (no visual regression).
2. Switch through Candles / Hollow / Bars / Line / Area / Heikin-Ashi via the Settings dropdown. Each renders correctly:
   - **Hollow** — up candles outlined (no fill), down candles filled.
   - **Bars** — single vertical lines with left-open / right-close ticks. No bodies.
   - **Line** — single accent-coloured polyline through closes.
   - **Area** — line + gradient fill below.
   - **Heikin-Ashi** — visibly smoother runs, no sudden reversals one-bar.
3. Live tick updates each style without stutter or visual artefact.
4. cols2 with `[Candles, Heikin-Ashi]` → independent visuals per pane.
5. **Renko** → at this point should render nothing (just blank candle area) — that's expected (stub). Switch back to Candles and confirm it returns correctly.

If anything is broken in the five simple styles, fix it now before moving on — Group F's tests assume the simple paths are solid.

---

## Group F — `chart.js` Renko pipeline + H/L markers + tail rules

### Task F1: ATR + brick rebuild

**Files:**
- Modify: `web/chart-engine/chart.js` (Renko helpers)

- [ ] **Step 1: Add `_computeRenkoBrickSize`**

```js
_computeRenkoBrickSize() {
  const bars = this.candles;
  const ti = (this.symbol && this.symbol.ti) || 0.05;
  if (!bars || bars.length === 0) return ti;
  // Standard ATR(14). True Range = max(H-L, |H-prevC|, |L-prevC|).
  const period = 14;
  const n = Math.min(bars.length, period * 4); // window the ATR
  if (bars.length < period) {
    // Fallback: range / count.
    let hi = -Infinity, lo = Infinity;
    for (const c of bars) { if (c.h > hi) hi = c.h; if (c.l < lo) lo = c.l; }
    const r = (hi - lo) / Math.max(1, bars.length);
    return this._snapToTick(Math.max(ti, r), ti);
  }
  let trSum = 0; let trCount = 0;
  const start = bars.length - n;
  for (let i = Math.max(1, start); i < bars.length; i++) {
    const c = bars[i]; const p = bars[i - 1];
    const tr = Math.max(c.h - c.l, Math.abs(c.h - p.c), Math.abs(c.l - p.c));
    trSum += tr; trCount += 1;
  }
  const atr = trCount > 0 ? trSum / trCount : ti;
  return this._snapToTick(Math.max(ti, atr), ti);
}

_snapToTick(value, tick) {
  if (!isFinite(tick) || tick <= 0) return value;
  return Math.max(tick, Math.round(value / tick) * tick);
}
```

- [ ] **Step 2: Add `_rebuildRenko`**

```js
_rebuildRenko() {
  this._renkoBricks = [];
  const bars = this.candles;
  if (!bars || bars.length === 0) {
    this._renkoBrickSize = 0;
    return;
  }
  const size = this._computeRenkoBrickSize();
  this._renkoBrickSize = size;
  const first = bars[0];
  let last = {
    idx: 0,
    openPrice: first.c,
    closePrice: first.c,
    direction: 'up',
    sourceBarTime: first.ts,
    sourceBarIndex: 0,
  };
  this._renkoBricks.push(last);
  for (let i = 1; i < bars.length; i++) {
    last = this._appendBricksForPrice(bars[i].c, last, size, bars[i].ts, i);
  }
}

// Returns the new "last brick" after appending zero or more bricks driven
// by `price`. Implements the classic Renko reversal rule (need 2*size in
// the opposite direction to reverse).
_appendBricksForPrice(price, last, size, sourceBarTime, sourceBarIndex) {
  if (!isFinite(price) || size <= 0) return last;
  let cur = last;
  // Forward in current direction.
  while (true) {
    if (cur.direction === 'up') {
      if (price >= cur.closePrice + size) {
        const next = {
          idx: cur.idx + 1,
          openPrice: cur.closePrice,
          closePrice: cur.closePrice + size,
          direction: 'up',
          sourceBarTime, sourceBarIndex,
        };
        this._renkoBricks.push(next); cur = next; continue;
      }
      if (price <= cur.closePrice - 2 * size) {
        const next = {
          idx: cur.idx + 1,
          openPrice: cur.closePrice - size,
          closePrice: cur.closePrice - 2 * size,
          direction: 'down',
          sourceBarTime, sourceBarIndex,
        };
        this._renkoBricks.push(next); cur = next; continue;
      }
      break;
    } else { // 'down'
      if (price <= cur.closePrice - size) {
        const next = {
          idx: cur.idx + 1,
          openPrice: cur.closePrice,
          closePrice: cur.closePrice - size,
          direction: 'down',
          sourceBarTime, sourceBarIndex,
        };
        this._renkoBricks.push(next); cur = next; continue;
      }
      if (price >= cur.closePrice + 2 * size) {
        const next = {
          idx: cur.idx + 1,
          openPrice: cur.closePrice + size,
          closePrice: cur.closePrice + 2 * size,
          direction: 'up',
          sourceBarTime, sourceBarIndex,
        };
        this._renkoBricks.push(next); cur = next; continue;
      }
      break;
    }
  }
  return cur;
}
```

- [ ] **Step 3: Add `_updateRenkoFromTick`**

```js
_updateRenkoFromTick(price) {
  if (this.candleStyle !== 'renko') return;
  if (!this._renkoBricks.length || this._renkoBrickSize <= 0) return;
  const last = this._renkoBricks[this._renkoBricks.length - 1];
  const newLast = this._appendBricksForPrice(
      price, last, this._renkoBrickSize,
      Math.floor(Date.now() / 1000),
      this.candles.length - 1);
  if (newLast !== last) this.scheduleRedraw();
}
```

- [ ] **Step 4: Hook into `setSymbol` / `setTimeframe` / `setBars` / `onHistoryResult`**

Search for the places that mutate `this.candles` (the `setBars` path inside `onHistoryResult` and inside `ingestTick` when an old bar bucket commits). Wherever a code path finishes loading or replacing the full `this.candles` array, append:

```js
if (this.candleStyle === 'renko') {
  this._rebuildRenko();
  this._notifyBrickSize(this._renkoBrickSize);
}
```

In `setSymbol(scrip)` (around line 133) and `setTimeframe(minutes)` (around line 143) — both clear/reset `this.candles` and request fresh history — also reset:
```js
this._renkoBricks = [];
this._renkoBrickSize = 0;
// notifyBrickSize is re-emitted after the next history load completes.
```

- [ ] **Step 5: Hook the tick update into `ingestTick`**

Locate `ingestTick(packet)` around line 204-234. After the existing `if (result....)` / `scheduleRedraw()` logic (i.e. once a tick price is settled into the current or new bar), call:

```js
if (typeof packet.ltp === 'number') {
  this._updateRenkoFromTick(packet.ltp);
}
```

(Use whatever the existing variable is in `ingestTick` for the tick price — confirm against the code around line 204-234 when implementing.)

- [ ] **Step 6: Run static gate**

Run: `node --check web/chart-engine/chart.js`
Expected: silent.

---

### Task F2: Renko draw + indicator series swap + volume hide + crosshair variant + drawing hide-list

**Files:**
- Modify: `web/chart-engine/chart.js`

> **Coordinate-system note for this task:** The chart's scroll/zoom state (`view.firstVisible`, `view.lastVisible`, `view.cellW`) and the X-projection helper `_candleXCenter(absIdx, plot)` are bar-indexed today (they assume `this.candles.length` is the series length). For Renko we want them to operate on brick indices instead. The smallest-blast-radius approach: introduce a helper `_seriesLength()` that returns the active series length and ensure the scroll computation reads from it. Below, `_drawRenko` derives its visible window directly from `this._renkoBricks.length` clamped against the same `view.firstVisible/lastVisible` semantics. Step 0 unifies the series-length lookup; if more places in the file deref `this.candles.length` for view math, fix them with the same helper.

- [ ] **Step 0: Add `_seriesLength()` helper and apply it to the scroll/zoom math**

Add the helper:

```js
_seriesLength() {
  return this.candleStyle === 'renko'
      ? this._renkoBricks.length
      : this.candles.length;
}
```

Then grep within `chart.js` for `this.candles.length` and inspect each call site:

- **Scroll / zoom / auto-scroll / view-clamping math** (anywhere a `firstVisible`, `lastVisible`, `pricePerPx`, `cellW`, or auto-scroll-to-end calculation reads `this.candles.length`) → replace with `this._seriesLength()`.
- **History / tick ingest / data mutation paths** (e.g. `this.candles.length === 0` early-outs, `this.candles[this.candles.length - 1]` to find the latest bar, history backfill bookkeeping) → leave alone. These manage bar data, not view state.

Sanity check: after this edit, switching from Candles to Renko on a fresh symbol should not require any tweak to `view.firstVisible/lastVisible` because the same numbers continue to clamp correctly against whichever series is active.

- [ ] **Step 1: Replace the stub `_drawRenko` from Task E2 with the real implementation**

```js
_drawRenko(plot, priceToY) {
  const bricks = this._renkoBricks;
  if (!bricks || bricks.length === 0) return;
  // After Step 0, view.firstVisible / view.lastVisible are bounded by
  // _seriesLength() — i.e. the brick count when on Renko. Clamp anyway as
  // a belt-and-braces guard.
  const total = bricks.length;
  const firstVisible = Math.max(0,
      Math.floor(this.view.firstVisible != null ? this.view.firstVisible : 0));
  const lastVisible = Math.min(total - 1,
      Math.ceil(this.view.lastVisible != null ? this.view.lastVisible : total - 1));
  if (firstVisible > lastVisible) return;
  const bodyW = Math.max(1, this.view.cellW - 2);
  for (let i = firstVisible; i <= lastVisible; i++) {
    const b = bricks[i];
    const xCenter = this._candleXCenter(i, plot); // brick idx → X
    const color = b.direction === 'up' ? this.palette.bull : this.palette.bear;
    this.ctx.fillStyle = color;
    const yTop = Math.min(priceToY(b.openPrice), priceToY(b.closePrice));
    const yBot = Math.max(priceToY(b.openPrice), priceToY(b.closePrice));
    const h = Math.max(1, yBot - yTop);
    this.ctx.fillRect(
        Math.round(xCenter - bodyW / 2), yTop, bodyW, h);
  }
}
```

> Note: also update the autoscale-Y block inside `draw()` (around lines 1050-1054 — the `for (const c of visible)` that builds `lo`/`hi` from bar `c.l`/`c.h`) so it scans `this._renkoBricks` close prices when `this.candleStyle === 'renko'`. Without this, the Y range will be wrong and bricks will fall off-plot. Smallest change: introduce a `visibleSeries` local at the top of `draw()` immediately after the existing `visible` declaration that points at either the visible-bar slice or the visible-brick slice, and use it for the autoscale loop. Keep the `visible` (bar) slice intact for everything else (it's used by the simple style draws and the volume panel guard).

- [ ] **Step 2: Hide the volume panel on Renko**

Find the existing volume draw block in `draw()` (around lines 1093-1124, `if (volPlot) { ... }`). Wrap the entire block:

```js
if (volPlot && this.candleStyle !== 'renko') {
  // … existing volume drawing code …
}
```

- [ ] **Step 3: Swap the indicator series on Renko**

Find `_drawIndicators(plot, lo, hi, priceToY)` (around line 2515). At the top of the function, replace the variable that holds the input series. Currently the function reads `this.candles.map(c => c.c)` or iterates `this.candles` directly. Wrap the source selection:

```js
_drawIndicators(plot, lo, hi, priceToY) {
  const seriesBars = this.candleStyle === 'renko'
      ? this._renkoBricks.map((b) => ({ c: b.closePrice, h: b.closePrice, l: b.closePrice, o: b.openPrice, ts: b.sourceBarTime, v: 0 }))
      : this.candles;
  // … existing implementation, but every reference to `this.candles` inside
  // _drawIndicators must be replaced with `seriesBars`. Pay particular
  // attention to the visible-window slicing and the SMA / EMA / RSI loops.
}
```

(When implementing, grep within `_drawIndicators` for every `this.candles` reference and replace with `seriesBars`. Likewise replace any `this.view.firstVisible`/`lastVisible` indexing if it dereferences `this.candles` — Renko indices map directly so just use the same indices against `seriesBars`.)

- [ ] **Step 4: Hide time-axis drawings on Renko, keep price-only ones**

Find `_drawDrawings(plot, priceToY)` (around line 1867). The function iterates a list of `{kind, points}` items. At the top:

```js
_drawDrawings(plot, priceToY) {
  const isRenko = this.candleStyle === 'renko';
  // Existing iteration — for each drawing:
  //   if (isRenko && drawing.kind !== 'hline') continue;
  //   (today we have 'hline' and 'trendline'; trendline is time-axis-dependent so it hides.
  //    Future kinds 'rect' / 'fib' also hide.)
}
```

- [ ] **Step 5: Crosshair variant for Renko**

In `draw()` (around lines 1146-1182) the existing crosshair block draws the chip with `snappedPrice.toFixed(...)` and then a time chip at `_drawTimeChip(...)` showing the candle time. For Renko, replace the time chip text when the hovered index is a Renko brick. Find `_drawTimeChip(...)` near line 1178 and switch the text source:

```js
// Existing:
if (this.hover.inside && this.hover.x != null) {
  const tidx = this._candleAtX(this.hover.x);
  if (tidx >= 0) {
    let label;
    if (this.candleStyle === 'renko' && tidx < this._renkoBricks.length) {
      const b = this._renkoBricks[tidx];
      label = `Brick #${b.idx} · src ${this._fmtHoverTime(b.sourceBarTime)}`;
    } else {
      label = this._fmtHoverTime(this.candles[tidx].ts);
    }
    this._drawTimeChip(this.hover.x, this.canvas.clientHeight - 18, label);
  }
}
```

- [ ] **Step 6: Run static gate**

Run: `node --check web/chart-engine/chart.js`
Expected: silent.

---

### Task F3: Visible-range H / L markers

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add `_drawHighLowMarkers`**

Append near `_drawLtpLine` / `_drawOverlays`:

```js
_drawHighLowMarkers(plot, priceToY) {
  if (!this.showHighLowMarkers) return;
  const isRenko = this.candleStyle === 'renko';
  // Pick the visible source array + the "extreme" extractor.
  let visibleCount = 0;
  let maxVal = -Infinity, minVal = Infinity;
  let maxIdx = -1, minIdx = -1;
  if (isRenko) {
    const bricks = this._renkoBricks;
    if (!bricks.length) return;
    const first = Math.max(0, Math.floor(this.view.firstVisible || 0));
    const last = Math.min(bricks.length - 1,
        Math.ceil(this.view.lastVisible != null ? this.view.lastVisible : bricks.length - 1));
    for (let i = first; i <= last; i++) {
      const v = bricks[i].closePrice;
      if (v > maxVal) { maxVal = v; maxIdx = i; }
      if (v < minVal) { minVal = v; minIdx = i; }
      visibleCount++;
    }
  } else {
    const bars = this.candles;
    if (!bars.length) return;
    const useClose = this.candleStyle === 'line' || this.candleStyle === 'area';
    const first = Math.max(0, Math.floor(this.view.firstVisible || 0));
    const last = Math.min(bars.length - 1,
        Math.ceil(this.view.lastVisible != null ? this.view.lastVisible : bars.length - 1));
    for (let i = first; i <= last; i++) {
      const c = bars[i];
      const hi = useClose ? c.c : c.h;
      const lo = useClose ? c.c : c.l;
      if (hi > maxVal) { maxVal = hi; maxIdx = i; }
      if (lo < minVal) { minVal = lo; minIdx = i; }
      visibleCount++;
    }
  }
  if (visibleCount < 2 || maxIdx < 0 || minIdx < 0) return;
  if (Math.abs(maxVal - minVal) < 1e-9) return;
  this._drawHLChip(plot, priceToY, maxIdx, maxVal, 'H', this.palette.bull);
  this._drawHLChip(plot, priceToY, minIdx, minVal, 'L', this.palette.bear);
}

_drawHLChip(plot, priceToY, idx, value, prefix, fill) {
  const anchorX = this._candleXCenter(idx, plot);
  const anchorY = priceToY(value);
  const decimals = this._priceDecimals();
  const text = `${prefix} ${value.toFixed(decimals)}`;
  this.ctx.font = '700 10px Geist, sans-serif';
  this.ctx.textBaseline = 'middle';
  this.ctx.textAlign = 'left';
  const tw = this.ctx.measureText(text).width;
  const padX = 5, padY = 2, leader = 8, gap = 14;
  const chipW = Math.ceil(tw + padX * 2);
  const chipH = 14;
  const isH = prefix === 'H';
  // Place above wick for H, below for L. Clamp into plot vertically.
  let chipY = isH ? anchorY - gap - chipH / 2 : anchorY + gap - chipH / 2;
  if (chipY < plot.top + 2) chipY = anchorY + gap - chipH / 2;             // overflow: flip
  if (chipY + chipH > plot.bottom - 2) chipY = anchorY - gap - chipH / 2;  // overflow: flip
  // Clamp X.
  let chipX = anchorX - chipW / 2;
  if (chipX < plot.left + 2) chipX = plot.left + 2;
  if (chipX + chipW > plot.right - 2) chipX = plot.right - 2 - chipW;
  // Leader.
  this.ctx.strokeStyle = fill;
  this.ctx.lineWidth = 1;
  this.ctx.setLineDash([2, 2]);
  this.ctx.beginPath();
  if (isH) {
    this.ctx.moveTo(anchorX + 0.5, anchorY);
    this.ctx.lineTo(anchorX + 0.5, anchorY - leader);
  } else {
    this.ctx.moveTo(anchorX + 0.5, anchorY);
    this.ctx.lineTo(anchorX + 0.5, anchorY + leader);
  }
  this.ctx.stroke();
  this.ctx.setLineDash([]);
  // Chip.
  this.ctx.fillStyle = fill;
  this._roundedRect(chipX, chipY, chipW, chipH, 2);
  this.ctx.fill();
  this.ctx.fillStyle = '#ffffff';
  this.ctx.fillText(text, chipX + padX, chipY + chipH / 2 + 0.5);
}
```

- [ ] **Step 2: Call the new function from `draw()`**

In `draw()`, after the candle/style switch block from Task E2 but BEFORE `_drawLtpLine(plot, priceToY, lo, hi)` (around line 1128), add:

```js
this._drawHighLowMarkers(plot, priceToY);
```

(Z-order: drawn AFTER the candles/bricks so the chips are visible, BEFORE LTP / overlays / order chips so user-actionable order chips remain on top.)

- [ ] **Step 3: Run static gate**

Run: `node --check web/chart-engine/chart.js`
Expected: silent.

---

## Group G — Final smoke verification

### Smoke checkpoint γ (final)

**Pause here.** Wait for the user.

Run through the full Phase 16 acceptance from the spec:

1. Open `/charts` default → still Candles, H/L chip markers visible (green at top, red at bottom).
2. Settings popup → "Chart style" dropdown + "Show H / L markers" Switch sit at the top, above the existing Gridlines / Volume / Instant orders rows.
3. Cycle through all 7 styles. Each renders correctly; the dropdown label updates.
4. On Renko:
   - X-axis is brick index (timestamps non-uniform — that's correct).
   - EMA(20) follows brick closes (add it via the Indicators section to verify).
   - Settings dropdown subtitle "brick size: X.XX" appears below the dropdown when Renko is selected. Disappears when switched away.
   - Volume panel disappears.
   - Trendline drawn on Candles is hidden; horizontal line stays.
   - Crosshair tooltip in the time strip shows "Brick #N · src HH:MM:SS".
5. Pan / zoom on any style → H / L chips re-anchor to new visible extremes within the same frame.
6. Toggle "Show H / L markers" off → chips disappear; on → reappear.
7. Drag-modify an open order chip while on Heikin-Ashi and on Renko → drag still works; order chip still pinned correctly.
8. cols2, pane 0 = Candles, pane 1 = Renko → fully independent. Pane 1's Settings shows the Renko subtitle; pane 0's doesn't.
9. Reload tab → style + H/L flag persist per pane.
10. Live tick during Renko → new bricks append, auto-scroll keeps latest in view.
11. Switch from Renko → Candles → indicators re-bind to bars without artefacts; H/L markers re-snap to wicks instead of closes.

If anything is broken, capture the symptom + reproduction steps and fix targeted — do not blanket-revert.

---

## Spec coverage map

| Spec section / requirement | Implementing task(s) |
|---|---|
| § 1 Goal — 7 style choices in Settings | C1, C3 |
| § 1 Goal — H/L Switch in Settings | C2, C3 |
| § 2.1 H/L marker visual style | F3 |
| § 2.2 Settings popup new rows at top | C3 |
| § 2.2 Renko brick-size subtitle | C1 (Flutter) + B3 (inbound handler) + D1 step 2 (callback) + F1 (`_notifyBrickSize` calls) |
| § 2.3 No top-bar changes | (none — explicitly NOT touched) |
| § 3 `PaneState.candleStyle` field + sentinel | A1 |
| § 3 `PaneState.showHighLowMarkers` field | A2 |
| § 3 Notifier methods | A3 |
| § 3 JSON omit-default + unknown-coerce | A1 step 2, A2 step 1 |
| § 4.1 Style routing switch | E2 step 1 |
| § 4.2 Hollow / Bars / Line / Area / HA draw funcs | E2 steps 2-4 |
| § 4.3 Renko brick model + size + build + tick update + draw | F1, F2 |
| § 4.3 Indicators on Renko (`_indicatorSeries` swap) | F2 step 3 |
| § 4.3 Volume hide | F2 step 2 |
| § 4.3 Crosshair on Renko | F2 step 5 |
| § 4.4 Visible-range H/L markers (chip + leader, clamp, hide rules) | F3 |
| § 4.5 No new bridge protocol — per-field encoders | B1, D1 step 1 |
| § 4.5 `renkoBrickSize` round-trip | A4 (notifier) + B3 (handler) + D1 step 2 (callback) + F1 (push site) |
| § 5 edge cases (drawings on Renko hide-list, persistence defaults, etc.) | F2 step 4 (drawings hide), A1/A2 (persistence defaults), F1/F2 (tick / scroll-back) |
| § 6 file list | (all files listed at top of this plan map 1:1) |
| § 7 acceptance smoke | Smoke checkpoint γ |
