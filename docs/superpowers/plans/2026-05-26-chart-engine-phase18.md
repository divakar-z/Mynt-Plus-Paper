# Chart Engine — Phase 18 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Ship two independent per-pane features: (1) OI bars at option-chain strikes on supported index spot charts with hover-only tooltips, refreshing every 120s; (2) bar-close countdown extending the LTP chip downward.

**Architecture:** Two new bool fields on `PaneState`, one new transient Riverpod notifier for OI data, periodic fetcher in the shell, three new bridge messages, three new chart.js methods + hover tooltip + countdown extension to the existing LTP chip.

**Tech Stack:** Flutter Web + Riverpod 3.x, vanilla JS Canvas chart, postMessage bridge as JSON strings, `marketWatchProvider.api.getOptionChain` for option-chain data.

---

**Project constraints (apply to every task):**

- **NO git commits anywhere.** User commits manually.
- Static gate after every code-touching task: `flutter analyze lib/screens/web/chart_engine` for Dart; `node --check web/chart-engine/<file>.js` for JS.
- Manual smoke checkpoints (none required between tasks given size — single smoke at the end).
- **No tests.** No Jest harness, no Dart widget tests for this codebase. Static gates + manual smoke only. Subagents must NOT write tests.
- Riverpod 3.x — `Notifier` / `NotifierProvider`.
- Mirror Phase 16/17 patterns: sentinel-free `bool?` `copyWith`, omit-default JSON, per-pane diff-cache in `_pushSessionInner`, per-pane Setting bound via `ConsumerWidget`.

**Files touched (high-level):**

| File | Purpose |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | 2 new `PaneState` fields + 2 notifier methods |
| `lib/screens/web/chart_engine/state/chart_oi_data.dart` (NEW) | OI cache notifier |
| `lib/screens/web/chart_engine/state/option_underlying_match.dart` | Add `_kIndexOptionExchanges` map |
| `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart` | 3 new encoders |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | OI fetch loop + 3 new pushes + cache invalidation |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | 2 new Settings rows |
| `web/chart-engine/chart-engine.js` | 3 new inbound message handlers |
| `web/chart-engine/chart.js` | Constructor state, 3 new setters, OI bar render, hover tooltip, LTP-chip countdown, 1Hz timer + destroy clear |

---

## Group A — Data model + transient cache

### Task A1: `PaneState.showOptionChainOi` + `showBarCountdown` fields + notifier methods

**Files:**
- Modify: `lib/screens/web/chart_engine/state/chart_engine_store.dart`

- [ ] **Step 1: Add fields**

Insert into `PaneState` immediately after `showHighLowMarkers`:

```dart
// Phase 18 — show option-chain OI bars at strike prices on the underlying
// chart. Default OFF (fetching adds API load); user opts in per pane.
final bool showOptionChainOi;
// Phase 18 — show "time until current bar closes" countdown extension on
// the LTP chip. Default ON.
final bool showBarCountdown;
```

Constructor params (right after `this.showHighLowMarkers = true,`):
```dart
this.showOptionChainOi = false,
this.showBarCountdown = true,
```

`copyWith` params (right after `bool? showHighLowMarkers,`):
```dart
bool? showOptionChainOi,
bool? showBarCountdown,
```

`copyWith` body forwarding (right after `showHighLowMarkers: showHighLowMarkers ?? this.showHighLowMarkers,`):
```dart
showOptionChainOi: showOptionChainOi ?? this.showOptionChainOi,
showBarCountdown: showBarCountdown ?? this.showBarCountdown,
```

`toJson` omit-default guards (right after the `showHighLowMarkers` guard):
```dart
if (showOptionChainOi != false) 'showOptionChainOi': showOptionChainOi,
if (showBarCountdown != true) 'showBarCountdown': showBarCountdown,
```

`fromJson` parse + forward (mirror the `showHighLowMarkers` pattern):
```dart
final bool showOi = j['showOptionChainOi'] as bool? ?? false;
final bool showCd = j['showBarCountdown'] as bool? ?? true;
// ... and in the returned constructor call:
showOptionChainOi: showOi,
showBarCountdown: showCd,
```

- [ ] **Step 2: Add notifier methods**

In `ChartEngineSessionNotifier`, near `setPaneShowHighLowMarkers`:

```dart
/// Phase 18 — toggle the option-chain OI bars on one pane.
void setPaneShowOptionChainOi(int index, bool show) {
  if (index < 0 || index >= state.panes.length) return;
  final pane = state.panes[index];
  if (pane.showOptionChainOi == show) return;
  state = state.copyWithPane(
      index, pane.copyWith(showOptionChainOi: show));
  _schedulePersist();
}

/// Phase 18 — toggle the LTP bar-close countdown on one pane.
void setPaneShowBarCountdown(int index, bool show) {
  if (index < 0 || index >= state.panes.length) return;
  final pane = state.panes[index];
  if (pane.showBarCountdown == show) return;
  state = state.copyWithPane(
      index, pane.copyWith(showBarCountdown: show));
  _schedulePersist();
}
```

- [ ] **Step 3: Static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

### Task A2: `ChartOiData` notifier

**Files:**
- Create: `lib/screens/web/chart_engine/state/chart_oi_data.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One option-chain strike, normalized for chart-side render.
class ChartOiStrike {
  final double strike;
  final double callOi;
  final double putOi;
  final double callOiChgPct;
  final double putOiChgPct;
  const ChartOiStrike({
    required this.strike,
    required this.callOi,
    required this.putOi,
    required this.callOiChgPct,
    required this.putOiChgPct,
  });

  Map<String, Object?> toJson() => {
        'strike': strike,
        'callOi': callOi,
        'putOi': putOi,
        'callOiChgPct': callOiChgPct,
        'putOiChgPct': putOiChgPct,
      };
}

/// Transient (non-persisted) per-pane OI data fetched from the option-chain
/// API. Refreshed every 120s by the shell screen while a supported index
/// spot is shown with the "Show option-chain OI" toggle ON.
class ChartOiData {
  final Map<int, List<ChartOiStrike>> byPane;
  final Map<int, int> fetchedAtByPane; // epoch ms
  const ChartOiData({
    this.byPane = const {},
    this.fetchedAtByPane = const {},
  });

  ChartOiData copyWith({
    Map<int, List<ChartOiStrike>>? byPane,
    Map<int, int>? fetchedAtByPane,
  }) =>
      ChartOiData(
        byPane: byPane ?? this.byPane,
        fetchedAtByPane: fetchedAtByPane ?? this.fetchedAtByPane,
      );
}

class ChartOiDataNotifier extends Notifier<ChartOiData> {
  @override
  ChartOiData build() => const ChartOiData();

  void setForPane(int paneIndex, List<ChartOiStrike> strikes, int fetchedAt) {
    if (paneIndex < 0) return;
    final nextBy = Map<int, List<ChartOiStrike>>.from(state.byPane);
    nextBy[paneIndex] = strikes;
    final nextAt = Map<int, int>.from(state.fetchedAtByPane);
    nextAt[paneIndex] = fetchedAt;
    state = state.copyWith(byPane: nextBy, fetchedAtByPane: nextAt);
  }

  void clearForPane(int paneIndex) {
    if (!state.byPane.containsKey(paneIndex) &&
        !state.fetchedAtByPane.containsKey(paneIndex)) {
      return;
    }
    final nextBy = Map<int, List<ChartOiStrike>>.from(state.byPane)
      ..remove(paneIndex);
    final nextAt = Map<int, int>.from(state.fetchedAtByPane)
      ..remove(paneIndex);
    state = state.copyWith(byPane: nextBy, fetchedAtByPane: nextAt);
  }
}

final chartOiDataProvider =
    NotifierProvider<ChartOiDataNotifier, ChartOiData>(
  ChartOiDataNotifier.new,
);
```

- [ ] **Step 2: Static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

### Task A3: `option_underlying_match.dart` — add option-chain exchange map

**Files:**
- Modify: `lib/screens/web/chart_engine/state/option_underlying_match.dart`

- [ ] **Step 1: Add the map**

Inside the file, near `_kIndexUnderlyings`, add:

```dart
/// Maps each supported index underlying name to the exchange code used by
/// `getOptionChain` (NFO for NSE indices, BFO for BSE). MCX commodities
/// also have option chains but are out of scope for Phase 18.
const Map<String, String> _kIndexOptionExchanges = {
  'NIFTY':      'NFO',
  'BANKNIFTY':  'NFO',
  'FINNIFTY':   'NFO',
  'MIDCPNIFTY': 'NFO',
  'SENSEX':     'BFO',
};

/// Returns (underlyingName, optionChainExch) when [paneScrip] is a
/// supported index spot whose option chain we can fetch. Otherwise null.
({String underlying, String optionExch})? optionChainTargetForPane(
    ChartScrip paneScrip) {
  for (final entry in _kIndexUnderlyings.entries) {
    final us = entry.value;
    if (us.exch == paneScrip.exch && us.token == paneScrip.token) {
      final ex = _kIndexOptionExchanges[entry.key];
      if (ex == null) return null;
      return (underlying: entry.key, optionExch: ex);
    }
  }
  return null;
}
```

- [ ] **Step 2: Static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

## Group B — Bridge + shell push

### Task B1: 3 new bridge encoders

**Files:**
- Modify: `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart`

- [ ] **Step 1: Append**

After the existing `encodeSetPaneHighLowMarkers`:

```dart
String encodeSetPaneShowOptionChainOi(String paneId, bool show) =>
    jsonEncode({
      'type': 'setPaneShowOptionChainOi',
      'value': {'paneId': paneId, 'show': show},
    });

String encodeSetPaneShowBarCountdown(String paneId, bool show) =>
    jsonEncode({
      'type': 'setPaneShowBarCountdown',
      'value': {'paneId': paneId, 'show': show},
    });

String encodeSetPaneOiData(
        String paneId, List<Map<String, Object?>> strikes) =>
    jsonEncode({
      'type': 'setPaneOiData',
      'value': {'paneId': paneId, 'strikes': strikes},
    });
```

- [ ] **Step 2: Static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

### Task B2: Shell screen — push the two new flags + OI data + run the fetcher

**Files:**
- Modify: `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add new cache fields**

Near the existing `_pushedCandleStyle` / `_pushedShowHighLowMarkers` cluster:

```dart
final Map<int, bool> _pushedShowOptionChainOi = {};
final Map<int, bool> _pushedShowBarCountdown = {};
final Map<int, String> _pushedOiDataJson = {};
```

- [ ] **Step 2: Add imports**

```dart
import 'state/chart_oi_data.dart';
import 'state/option_underlying_match.dart';
```

(`option_underlying_match.dart` is already imported. Confirm — only add if absent.)

- [ ] **Step 3: Invalidate caches on layout change**

In the `if (force || session.layout.id != _pushedLayoutId)` block, append:

```dart
_pushedShowOptionChainOi.clear();
_pushedShowBarCountdown.clear();
_pushedOiDataJson.clear();
```

- [ ] **Step 4: Push the two new flags per pane**

Inside the per-pane for-loop (after the existing `setPaneHighLowMarkers` push):

```dart
if (force || _pushedShowOptionChainOi[i] != pane.showOptionChainOi) {
  _pushedShowOptionChainOi[i] = pane.showOptionChainOi;
  _post(encodeSetPaneShowOptionChainOi(
      i.toString(), pane.showOptionChainOi));
}
if (force || _pushedShowBarCountdown[i] != pane.showBarCountdown) {
  _pushedShowBarCountdown[i] = pane.showBarCountdown;
  _post(encodeSetPaneShowBarCountdown(
      i.toString(), pane.showBarCountdown));
}
```

- [ ] **Step 5: Push OI data per pane (gated by diff)**

After Step 4 (still inside the per-pane for-loop):

```dart
final oiData = ref.read(chartOiDataProvider);
final strikes = oiData.byPane[i] ?? const <ChartOiStrike>[];
final strikesPayload = [for (final s in strikes) s.toJson()];
final strikesJson = jsonEncode(strikesPayload);
if (force || _pushedOiDataJson[i] != strikesJson) {
  _pushedOiDataJson[i] = strikesJson;
  _post(encodeSetPaneOiData(i.toString(), strikesPayload));
}
```

- [ ] **Step 6: Add the OI fetch loop**

The shell has a Timer in `initState` for some periodic work — locate it. If none exists, add a `Timer.periodic(const Duration(seconds: 5), _maybeFetchOptionChain)` in `initState` and `cancel()` in `dispose`.

The loop body:

```dart
void _maybeFetchOptionChain(Timer _) {
  if (!_iframeReady) return;
  final session = ref.read(chartEngineSessionProvider);
  final oiData = ref.read(chartOiDataProvider);
  final oiNotifier = ref.read(chartOiDataProvider.notifier);
  final api = locator<ApiExporter>(); // or whatever the api accessor is
  final mwApi = api.marketWatchApi;   // exact path may differ — grep
  final now = DateTime.now().millisecondsSinceEpoch;
  const refreshMs = 120000;
  for (var i = 0; i < session.panes.length; i++) {
    final pane = session.panes[i];
    if (!pane.showOptionChainOi) {
      // Toggled off — clear cached strikes for this pane.
      if (oiData.byPane.containsKey(i)) {
        oiNotifier.clearForPane(i);
      }
      continue;
    }
    final scrip = pane.scrip;
    if (scrip == null) continue;
    final target = optionChainTargetForPane(scrip);
    if (target == null) continue;
    final last = oiData.fetchedAtByPane[i] ?? 0;
    if (now - last < refreshMs) continue;

    // Get the spot LTP — use marketWatchProvider.tickerData or equivalent
    // current-LTP source. If LTP is unknown, skip (try again next tick).
    final spotLtp = _currentSpotLtp(scrip);
    if (spotLtp == null || spotLtp <= 0) continue;

    // Fire-and-forget (mark fetched-at NOW to prevent spam during the
    // round-trip; we'll overwrite on success).
    oiNotifier.setForPane(
        i, oiData.byPane[i] ?? const <ChartOiStrike>[], now);
    // ignore: discarded_futures
    mwApi
        .getOptionChain(
            strPrc: spotLtp.toStringAsFixed(0),
            tradeSym: target.underlying,
            exchange: target.optionExch,
            context: context,
            numofStrike: '25')
        .then((res) {
      if (res == null || res.stat != 'Ok' || res.optValue == null) return;
      final parsed = <ChartOiStrike>[];
      for (final v in res.optValue!) {
        final strike = double.tryParse(v.strprc ?? '');
        if (strike == null || strike <= 0) continue;
        final oi = double.tryParse(v.oi ?? '0') ?? 0;
        final chgPct = double.tryParse(v.oiPerChng ?? '0') ?? 0;
        // optt == 'CE' → call; optt == 'PE' → put. The API returns each
        // (strike, optt) as a separate row. Coalesce into one per strike.
        final idx = parsed.indexWhere((s) => s.strike == strike);
        if (idx < 0) {
          parsed.add(ChartOiStrike(
            strike: strike,
            callOi: v.optt == 'CE' ? oi : 0,
            putOi:  v.optt == 'PE' ? oi : 0,
            callOiChgPct: v.optt == 'CE' ? chgPct : 0,
            putOiChgPct:  v.optt == 'PE' ? chgPct : 0,
          ));
        } else {
          final prev = parsed[idx];
          parsed[idx] = ChartOiStrike(
            strike: strike,
            callOi: v.optt == 'CE' ? oi : prev.callOi,
            putOi:  v.optt == 'PE' ? oi : prev.putOi,
            callOiChgPct: v.optt == 'CE' ? chgPct : prev.callOiChgPct,
            putOiChgPct:  v.optt == 'PE' ? chgPct : prev.putOiChgPct,
          );
        }
      }
      parsed.sort((a, b) => a.strike.compareTo(b.strike));
      ref
          .read(chartOiDataProvider.notifier)
          .setForPane(i, parsed, DateTime.now().millisecondsSinceEpoch);
    }).catchError((_) {
      // Silent best-effort; retry next tick.
    });
  }
}
```

- [ ] **Step 7: Add `_currentSpotLtp` helper**

Inside the state class. Look up the LTP via the existing tick-routing infrastructure. The simplest path: `marketWatchProvider.tickerData[scrip.token]?.lp` or the equivalent — grep `tickerData` / `getLastTick` in the codebase. Pseudocode:

```dart
double? _currentSpotLtp(ChartScrip scrip) {
  // Use whatever ticker-cache the codebase exposes for the (exch, token).
  // Example shape (verify by grep):
  final mw = ref.read(marketWatchProvider);
  final last = mw.lastTickFor(scrip.exch, scrip.token);
  if (last == null) return null;
  final lp = double.tryParse(last.lp ?? '');
  return (lp != null && lp > 0) ? lp : null;
}
```

If no such helper exists, fall back to the last candle's close from the chart's history cache — but the chart's history is iframe-side, not Dart-side. Acceptable fallback: skip until a tick arrives (just `return null;` for now, and the shell will retry on the next 5s tick).

- [ ] **Step 8: Ensure `ref.listen` on `chartOiDataProvider` triggers `_pushSession`**

Near the existing `ref.listen(portfolioProvider, ...)` / `ref.listen(orderProvider, ...)` block (around line 1252-1266), add:

```dart
ref.listen(chartOiDataProvider, (_, __) {
  if (_iframeReady) _pushSession();
});
```

- [ ] **Step 9: Static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

## Group C — Settings popup UI

### Task C1: `_PaneShowOptionChainOiSection` + `_PaneShowBarCountdownSection`

**Files:**
- Modify: `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`

- [ ] **Step 1: Append at the bottom of the file**

```dart
/// Phase 18 — toggles option-chain OI bars on the active pane.
class _PaneShowOptionChainOiSection extends ConsumerWidget {
  final int paneIndex;
  const _PaneShowOptionChainOiSection({required this.paneIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) {
      return const SizedBox.shrink();
    }
    final value = session.panes[paneIndex].showOptionChainOi;
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(children: [
        Expanded(
            child: Text('Show option-chain OI',
                style: MyntWebTextStyles.body(context))),
        Switch(
          value: value,
          onChanged: (v) =>
              notifier.setPaneShowOptionChainOi(paneIndex, v),
        ),
      ]),
    );
  }
}

/// Phase 18 — toggles the bar-close countdown row on the LTP chip.
class _PaneShowBarCountdownSection extends ConsumerWidget {
  final int paneIndex;
  const _PaneShowBarCountdownSection({required this.paneIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) {
      return const SizedBox.shrink();
    }
    final value = session.panes[paneIndex].showBarCountdown;
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(children: [
        Expanded(
            child: Text('Show bar countdown',
                style: MyntWebTextStyles.body(context))),
        Switch(
          value: value,
          onChanged: (v) =>
              notifier.setPaneShowBarCountdown(paneIndex, v),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 2: Insert into Settings popup**

In `_SettingsButtonState._build`, find the existing `_PaneHighLowMarkersSection(paneIndex: activeIdx)` line. Add the two new sections IMMEDIATELY AFTER it (still BEFORE the SizedBox/Divider/SizedBox that separates the Display section from "Indicators"):

```dart
_PaneHighLowMarkersSection(paneIndex: activeIdx),
_PaneShowOptionChainOiSection(paneIndex: activeIdx),   // NEW
_PaneShowBarCountdownSection(paneIndex: activeIdx),    // NEW
const SizedBox(height: 6),
const Divider(height: 1),
const SizedBox(height: 6),
```

- [ ] **Step 3: Static gate**

Run: `flutter analyze lib/screens/web/chart_engine`
Expected: `No issues found!`

---

## Group D — JS plumbing

### Task D1: 3 new inbound handlers in `chart-engine.js`

**Files:**
- Modify: `web/chart-engine/chart-engine.js`

- [ ] **Step 1: Add 3 case branches**

In the `handleMessage(d)` switch, next to the existing `setPaneCandleStyle` / `setPaneHighLowMarkers` cases (around lines 404-417):

```js
case 'setPaneShowOptionChainOi': {
  const { paneId, show } = d.value || {};
  if (typeof paneId !== 'string' || typeof show !== 'boolean') return;
  const chart = panes.get(paneId);
  if (chart) chart.setShowOptionChainOi(show);
  break;
}
case 'setPaneShowBarCountdown': {
  const { paneId, show } = d.value || {};
  if (typeof paneId !== 'string' || typeof show !== 'boolean') return;
  const chart = panes.get(paneId);
  if (chart) chart.setShowBarCountdown(show);
  break;
}
case 'setPaneOiData': {
  const { paneId, strikes } = d.value || {};
  if (typeof paneId !== 'string' || !Array.isArray(strikes)) return;
  const chart = panes.get(paneId);
  if (chart) chart.setOiData(strikes);
  break;
}
```

- [ ] **Step 2: Static gate**

Run: `node --check web/chart-engine/chart-engine.js`
Expected: silent.

---

## Group E — chart.js rendering

### Task E1: Constructor state + 3 setters + 1Hz timer

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Constructor state**

After the existing Phase 16 instance fields (look for `this.candleStyle = 'candles';`), add:

```js
// Phase 18 — option-chain OI bars + LTP bar-close countdown.
this.showOptionChainOi = false;
this.showBarCountdown = true;
this._oiData = []; // [{strike, callOi, putOi, callOiChgPct, putOiChgPct}, ...]
// 1Hz redraw so the countdown text updates each second even without ticks.
// Only created when at least one pane needs it; toggled by setters.
this._secondTimer = null;
```

- [ ] **Step 2: Add 3 setters**

Near `setShowHighLowMarkers` (or wherever the Phase 16 setters live):

```js
setShowOptionChainOi(show) {
  const v = show === true;
  if (v === this.showOptionChainOi) return;
  this.showOptionChainOi = v;
  this._updateSecondTimer();
  this.scheduleRedraw();
}

setShowBarCountdown(show) {
  const v = show === true;
  if (v === this.showBarCountdown) return;
  this.showBarCountdown = v;
  this._updateSecondTimer();
  this.scheduleRedraw();
}

setOiData(strikes) {
  this._oiData = Array.isArray(strikes) ? strikes : [];
  this.scheduleRedraw();
}

_updateSecondTimer() {
  const needsTimer = this.showBarCountdown; // OI doesn't tick; only countdown does
  if (needsTimer && !this._secondTimer) {
    this._secondTimer = setInterval(() => this.scheduleRedraw(), 1000);
  } else if (!needsTimer && this._secondTimer) {
    clearInterval(this._secondTimer);
    this._secondTimer = null;
  }
}
```

- [ ] **Step 3: Initialize the timer on construct**

At the end of the constructor (after the existing initialization), call:
```js
this._updateSecondTimer();
```

- [ ] **Step 4: Clear timer on `destroy`**

In the existing `destroy()` method (around line 270), add:
```js
if (this._secondTimer) { clearInterval(this._secondTimer); this._secondTimer = null; }
```

- [ ] **Step 5: Static gate**

Run: `node --check web/chart-engine/chart.js`
Expected: silent.

---

### Task E2: `_drawOiBars` + hover tooltip

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Add the renderer**

Append near `_drawOverlays` / `_drawHighLowMarkers`:

```js
_drawOiBars(plot, lo, hi, priceToY) {
  if (!this.showOptionChainOi || !this._oiData || this._oiData.length === 0) return;
  // Filter to visible strikes; compute max OI for scaling.
  let maxOi = 0;
  const visible = [];
  for (const s of this._oiData) {
    if (s.strike < lo || s.strike > hi) continue;
    visible.push(s);
    if (s.callOi > maxOi) maxOi = s.callOi;
    if (s.putOi > maxOi) maxOi = s.putOi;
  }
  if (visible.length === 0 || maxOi <= 0) return;

  const barH = 4;
  const gap = 1;
  const barRight = plot.right - 8;
  const maxBarLen = Math.max(20, plot.width * 0.25);
  const ceColor = '#22D3EE';
  const peColor = '#FB923C';

  for (const s of visible) {
    const y = priceToY(s.strike);
    const ceLen = (s.callOi / maxOi) * maxBarLen;
    const peLen = (s.putOi / maxOi) * maxBarLen;
    // CE on top, PE on bottom of the strike Y.
    this.ctx.fillStyle = ceColor;
    this.ctx.fillRect(barRight - ceLen, y - barH - gap / 2, ceLen, barH);
    this.ctx.fillStyle = peColor;
    this.ctx.fillRect(barRight - peLen, y + gap / 2, peLen, barH);
  }

  // Hover tooltip: only if cursor is over the bar strip and near a strike.
  if (this.hover.inside && this.hover.x != null && this.hover.y != null) {
    const stripLeft = barRight - maxBarLen;
    if (this.hover.x >= stripLeft && this.hover.x <= barRight) {
      // Find nearest visible strike within the row height tolerance.
      const rowH = (barH * 2) + gap; // total CE+PE row
      const tol = Math.max(rowH, 12);
      let best = null;
      let bestDy = Infinity;
      for (const s of visible) {
        const sy = priceToY(s.strike);
        const dy = Math.abs(sy - this.hover.y);
        if (dy < bestDy && dy <= tol) { bestDy = dy; best = s; }
      }
      if (best) this._drawOiHoverTooltip(plot, best);
    }
  }
}

_drawOiHoverTooltip(plot, s) {
  const padX = 8, padY = 6, lineH = 14;
  const lines = [
    `Strike:   ${this._fmtStrike(s.strike)}`,
    `Call OI:  ${this._fmtOi(s.callOi)}  ${this._fmtPct(s.callOiChgPct)}`,
    `Put OI:   ${this._fmtOi(s.putOi)}  ${this._fmtPct(s.putOiChgPct)}`,
  ];
  this.ctx.font = '500 11px Geist, sans-serif';
  let maxW = 0;
  for (const l of lines) {
    const w = this.ctx.measureText(l).width;
    if (w > maxW) maxW = w;
  }
  const boxW = Math.ceil(maxW + padX * 2);
  const boxH = lines.length * lineH + padY * 2;
  // Position to the LEFT of the cursor by default; flip if no room.
  let bx = this.hover.x - boxW - 12;
  if (bx < plot.left + 4) bx = this.hover.x + 12;
  let by = this.hover.y - boxH / 2;
  if (by < plot.top + 4) by = plot.top + 4;
  if (by + boxH > plot.bottom - 4) by = plot.bottom - 4 - boxH;
  // Background.
  this.ctx.fillStyle = this.palette.crosshairChip || 'rgba(20,20,20,0.92)';
  this._roundedRect(bx, by, boxW, boxH, 4);
  this.ctx.fill();
  this.ctx.strokeStyle = 'rgba(255,255,255,0.15)';
  this.ctx.lineWidth = 1;
  this._roundedRect(bx, by, boxW, boxH, 4);
  this.ctx.stroke();
  // Text.
  this.ctx.fillStyle = this.palette.chipText || '#FFFFFF';
  this.ctx.textBaseline = 'middle';
  this.ctx.textAlign = 'left';
  for (let i = 0; i < lines.length; i++) {
    this.ctx.fillText(lines[i], bx + padX, by + padY + lineH * (i + 0.5));
  }
}

_fmtStrike(v) {
  return v === Math.floor(v) ? String(v) : v.toFixed(2);
}

_fmtOi(v) {
  if (!isFinite(v) || v <= 0) return '0';
  if (v >= 10000000) return (v / 10000000).toFixed(1) + 'Cr';
  if (v >= 100000) return (v / 100000).toFixed(1) + 'L';
  if (v >= 1000) return (v / 1000).toFixed(1) + 'K';
  return String(Math.round(v));
}

_fmtPct(v) {
  if (!isFinite(v)) return '';
  const sign = v >= 0 ? '+' : '';
  return `(${sign}${v.toFixed(1)}%)`;
}
```

- [ ] **Step 2: Call from `draw()`**

In `draw()`, after `_drawOverlays`/`_drawOverlayPriceChips` but BEFORE `_drawLtpLine`:

```js
this._drawOiBars(plot, lo, hi, priceToY);
```

(The OI bars and the LTP chip don't compete for the same Y region, but order matters for the crosshair tooltip — OI tooltip should render before the crosshair price label so it isn't covered.)

- [ ] **Step 3: Static gate**

Run: `node --check web/chart-engine/chart.js`
Expected: silent.

---

### Task E3: LTP-chip countdown extension

**Files:**
- Modify: `web/chart-engine/chart.js`

- [ ] **Step 1: Read the existing `_drawLtpLine` body**

Find `_drawLtpLine(plot, priceToY, lo, hi)` (around line 2244). The function currently draws the LTP horizontal line + a rounded chip at the right axis showing the last price.

- [ ] **Step 2: Compute countdown + extend the chip**

After the existing chip is drawn, append:

```js
// Phase 18 — bar-close countdown directly under the LTP value, sharing
// the same chip background. Hidden when the toggle is off or no bars.
if (this.showBarCountdown &&
    this.candles && this.candles.length > 0 &&
    this.timeframeMinutes > 0) {
  const lastBar = this.candles[this.candles.length - 1];
  const closeSec = lastBar.ts + this.timeframeMinutes * 60;
  const nowSec = Math.floor(Date.now() / 1000);
  const left = Math.max(0, closeSec - nowSec);
  const mins = Math.floor(left / 60);
  const secs = left % 60;
  const text = mins + ':' + String(secs).padStart(2, '0');
  // The existing chip is at y +/- chipH/2 with width chipW. We need to
  // know those values to draw the second row inside the same chip.
  // Easiest path: redraw an enlarged chip that contains BOTH lines.
  // For minimum churn we draw a SEPARATE smaller chip directly below
  // the existing one (visually continuous since both use the same fill).
  // ↓ Implementation: read the chip geometry from local vars in the
  //   existing block above (you may need to hoist `chipY`, `chipW`,
  //   `chipH`, `chipFill` to method-scope so this block can reuse them).
  // Pseudocode for the second row:
  //   const subH = 14;
  //   ctx.fillStyle = chipFill;
  //   this._roundedRect(chipLeft, chipY + chipH/2 + 1, chipW, subH, 3);
  //   ctx.fill();
  //   ctx.fillStyle = '#FFFFFF';
  //   ctx.font = '500 10px Geist, sans-serif';
  //   ctx.textAlign = 'center';
  //   ctx.textBaseline = 'middle';
  //   ctx.fillText(text, chipLeft + chipW/2, chipY + chipH/2 + 1 + subH/2);
}
```

Implementer notes:
- The exact insertion requires hoisting the existing chip's geometry (`chipLeft`, `chipY`, `chipW`, `chipH`, fill color) so the new sub-chip can be positioned. The current code likely scopes them to the chip-draw block; pull them out into method-local `let` vars.
- If the original chip is anchored at the right axis (e.g. `chipLeft = plot.right + 2`), the new sub-chip uses the same `chipLeft` and `chipW`.
- If the original chip's color depends on direction (bullish vs bearish), the sub-chip should match.
- Use `padStart(2, '0')` for the seconds zero-pad.

- [ ] **Step 3: Static gate**

Run: `node --check web/chart-engine/chart.js`
Expected: silent.

---

## Group F — Smoke checkpoint

Manual; user runs after Group E lands.

What to verify:
1. NIFTY spot pane, Settings → toggle "Show option-chain OI" ON. Within ~5s bars appear at strikes inside the visible Y range.
2. Hover a bar row → tooltip shows `Strike / Call OI / Put OI` with values + % change.
3. Move mouse outside the strip → tooltip disappears; crosshair price label still works.
4. Wait 120s → bars refresh (visible via Network tab → new `GetOptionChain` POST).
5. Toggle OFF → bars vanish; no further fetches.
6. Switch pane to BANKNIFTY → bars repopulate after first fetch.
7. cols2: pane 0 = NIFTY OI ON, pane 1 = NIFTY OI OFF → only pane 0 fetches.
8. Bar countdown: visible by default under the LTP. Verify it ticks each second. After candle close it jumps to `tf-1:59`.
9. Toggle "Show bar countdown" OFF → countdown vanishes, LTP chip back to single line.
10. Reload tab → both per-pane toggle states persist.
11. Phase 16 + 17 features (candle styles, H/L markers, drag-modify, TP/SL pnl, option-strike overlay) all still work.

---

## Spec coverage map

| Spec section | Implementing task |
|---|---|
| §3.1 PaneState fields + notifier methods | A1 |
| §3.2 ChartOiData notifier | A2 |
| §4.1 Underlying → option-chain exch map | A3 |
| §4.1 Fetch loop | B2 step 6-7 |
| §4.2 Bridge encoders | B1 |
| §4.2 Shell pushes | B2 step 4-5 |
| §4.2 chart-engine.js handlers | D1 |
| §4.3 chart.js OI bars + hover | E1, E2 |
| §4.4 LTP countdown | E1, E3 |
| §4.5 Settings UI | C1 |
| §5 edge cases | A2 / B2 (clear-on-toggle-off, skip-when-no-ltp), E1 (timer destroy) |
| §7 smoke | Group F |
