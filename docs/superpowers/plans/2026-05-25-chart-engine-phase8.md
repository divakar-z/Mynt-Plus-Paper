# Chart Engine — Phase 8 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-pane technical indicators (SMA, EMA, RSI). SMA + EMA = line overlays on candle pane; RSI = sub-pane below volume. Add/remove via Settings popup; per-indicator period editable; persisted.

**Architecture:** `PaneState.indicators: List<IndicatorConfig>` is the source of truth. Shell pushes per pane via `setPaneIndicators`. Iframe stores `_indicators` per Chart instance, computes values from `this.candles` each draw, renders overlays (SMA/EMA) + sub-pane (RSI). Layout calculations in `draw()` carve out 18% for RSI when present.

**Tech Stack:** Flutter (Riverpod 3) + vanilla JS + Canvas 2D.

## Project conventions

- **No git commits.**
- **Static gates after every edit:** `flutter analyze lib/screens/web/chart_engine` + `node --check web/chart-engine/<file>.js`.
- **Spec reference:** `docs/superpowers/specs/2026-05-25-chart-engine-phase8-design.md`.
- **Reuse patterns:** `PaneState.qty`-style field addition; `_pushedXxxJson` diff cache; the existing `_drawOhlc` plot-math block for layout adjustment.

## File map

| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | New `IndicatorConfig` class; `PaneState.indicators` field + JSON; notifier methods `addIndicator` / `removeIndicator` / `updateIndicator`. |
| `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart` | `encodeSetPaneIndicators(paneId, list)`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | `_pushedIndicatorsJson` cache; per-pane push in `_pushSession`; layout-change cache clear. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | `Indicators` section in `_SettingsButton` popup. |
| `web/chart-engine/chart-engine.js` | `case 'setPaneIndicators'`. |
| `web/chart-engine/chart.js` | `_indicators` state; `setIndicators(list)`; `_computeSMA` / `_computeEMA` / `_computeRSI`; `_drawIndicators(plot, lo, hi, priceToY)`; `_drawRsiSubPane(rsiPlot)`; layout adjustment in `draw()` to carve `rsiH`. |

No new files.

## Task ordering

1. **Group A — Data model + bridge.**
2. **Group B — JS compute + render.**
3. **Group C — Flutter Settings popup UI.**
4. **Group D — Static gates + smoke.**

---

# Group A — Data model + bridge

### Task A1: IndicatorConfig + PaneState field

**Files:** `lib/screens/web/chart_engine/state/chart_engine_store.dart`

- [ ] **Step 1: Add `IndicatorConfig` class above `PaneState`**

```dart
class IndicatorConfig {
  final String id;       // stable per-instance
  final String kind;     // 'sma' / 'ema' / 'rsi'
  final int period;      // clamp 1..999
  final String color;    // hex
  const IndicatorConfig({
    required this.id,
    required this.kind,
    required this.period,
    required this.color,
  });

  IndicatorConfig copyWith({int? period, String? color}) => IndicatorConfig(
        id: id, kind: kind,
        period: period ?? this.period,
        color: color ?? this.color,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'kind': kind, 'period': period, 'color': color};
  static IndicatorConfig fromJson(Map<String, dynamic> j) => IndicatorConfig(
        id: j['id'] as String? ?? '',
        kind: j['kind'] as String? ?? 'sma',
        period: (j['period'] as num?)?.toInt() ?? 20,
        color: j['color'] as String? ?? '#3B82F6',
      );
}
```

- [ ] **Step 2: Add `indicators` field to `PaneState`**

```dart
class PaneState {
  final ChartScrip? scrip;
  final int timeframeMinutes;
  final ChartOverlays overlays;
  final int qty;
  final List<IndicatorConfig> indicators; // NEW
  const PaneState({
    this.scrip,
    this.timeframeMinutes = 1,
    this.overlays = const ChartOverlays(),
    this.qty = 1,
    this.indicators = const [],
  });

  PaneState copyWith({
    Object? scrip = _sentinel,
    int? timeframeMinutes,
    ChartOverlays? overlays,
    int? qty,
    List<IndicatorConfig>? indicators,
  }) =>
      PaneState(
        scrip: identical(scrip, _sentinel) ? this.scrip : scrip as ChartScrip?,
        timeframeMinutes: timeframeMinutes ?? this.timeframeMinutes,
        overlays: overlays ?? this.overlays,
        qty: qty ?? this.qty,
        indicators: indicators ?? this.indicators,
      );

  Map<String, dynamic> toJson() => {
        if (scrip != null) 'scrip': scrip!.toJson(),
        'timeframeMinutes': timeframeMinutes,
        'overlays': overlays.toJson(),
        'qty': qty,
        'indicators': [for (final i in indicators) i.toJson()],
      };

  static PaneState fromJson(Map<String, dynamic> j) => PaneState(
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
      );
}
```

- [ ] **Step 3: Notifier methods**

```dart
void addIndicator(int paneIndex, IndicatorConfig cfg) {
  if (paneIndex < 0 || paneIndex >= state.panes.length) return;
  final pane = state.panes[paneIndex];
  final next = List<IndicatorConfig>.from(pane.indicators)..add(cfg);
  state = state.copyWithPane(paneIndex, pane.copyWith(indicators: next));
  _schedulePersist();
}

void removeIndicator(int paneIndex, String id) {
  if (paneIndex < 0 || paneIndex >= state.panes.length) return;
  final pane = state.panes[paneIndex];
  final next = List<IndicatorConfig>.from(pane.indicators)
    ..removeWhere((i) => i.id == id);
  state = state.copyWithPane(paneIndex, pane.copyWith(indicators: next));
  _schedulePersist();
}

void updateIndicator(int paneIndex, String id, {int? period, String? color}) {
  if (paneIndex < 0 || paneIndex >= state.panes.length) return;
  final pane = state.panes[paneIndex];
  final next = [
    for (final i in pane.indicators)
      i.id == id ? i.copyWith(period: period, color: color) : i,
  ];
  state = state.copyWithPane(paneIndex, pane.copyWith(indicators: next));
  _schedulePersist();
}
```

- [ ] **Step 4: Static check**

`flutter analyze lib/screens/web/chart_engine/state/chart_engine_store.dart`.

---

### Task A2: Bridge encoder

**Files:** `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart`

Append:

```dart
String encodeSetPaneIndicators(
        String paneId, List<Map<String, Object?>> indicators) =>
    jsonEncode({
      'type': 'setPaneIndicators',
      'value': {'paneId': paneId, 'indicators': indicators},
    });
```

Static check.

---

### Task A3: chart-engine.js handler

**Files:** `web/chart-engine/chart-engine.js`

In `handleMessage` switch (alongside `setPaneDrawings`):

```javascript
    case 'setPaneIndicators': {
      const { paneId, indicators } = d.value || {};
      if (typeof paneId !== 'string' || !Array.isArray(indicators)) return;
      const chart = panes.get(paneId);
      if (chart) chart.setIndicators(indicators);
      break;
    }
```

Static check.

---

# Group B — JS compute + render

### Task B1: chart.js state + setIndicators + compute helpers

**Files:** `web/chart-engine/chart.js`

In the constructor, near `_drawings`:

```javascript
    this._indicators = []; // [{id, kind, period, color}]
```

Add the setter (near `setDrawings`):

```javascript
  setIndicators(list) {
    this._indicators = Array.isArray(list) ? list : [];
    this.scheduleRedraw();
  }
```

Add compute helpers at the bottom of the class (or as instance methods):

```javascript
  _computeSMA(period) {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (period <= 0 || n < period) return out;
    let sum = 0;
    for (let i = 0; i < n; i++) {
      sum += this.candles[i].c;
      if (i >= period) sum -= this.candles[i - period].c;
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }

  _computeEMA(period) {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (period <= 0 || n === 0) return out;
    const k = 2 / (period + 1);
    let ema = null;
    for (let i = 0; i < n; i++) {
      const c = this.candles[i].c;
      if (ema == null) ema = c;
      else ema = c * k + ema * (1 - k);
      if (i >= period - 1) out[i] = ema;
    }
    return out;
  }

  _computeRSI(period) {
    const n = this.candles.length;
    const out = new Array(n).fill(null);
    if (period <= 0 || n < period + 1) return out;
    let avgGain = 0, avgLoss = 0;
    for (let i = 1; i <= period; i++) {
      const ch = this.candles[i].c - this.candles[i - 1].c;
      if (ch >= 0) avgGain += ch;
      else avgLoss -= ch;
    }
    avgGain /= period;
    avgLoss /= period;
    const rs0 = avgLoss === 0 ? 100 : avgGain / avgLoss;
    out[period] = avgLoss === 0 ? 100 : 100 - 100 / (1 + rs0);
    for (let i = period + 1; i < n; i++) {
      const ch = this.candles[i].c - this.candles[i - 1].c;
      const g = ch > 0 ? ch : 0;
      const l = ch < 0 ? -ch : 0;
      avgGain = (avgGain * (period - 1) + g) / period;
      avgLoss = (avgLoss * (period - 1) + l) / period;
      const rs = avgLoss === 0 ? 100 : avgGain / avgLoss;
      out[i] = avgLoss === 0 ? 100 : 100 - 100 / (1 + rs);
    }
    return out;
  }
```

Static check.

---

### Task B2: Layout adjustment for RSI sub-pane + renderers

**Files:** `web/chart-engine/chart.js`

In `draw()`, modify the plot calculation block. Find:

```javascript
    const bottomGutter = 24;
    const rightGutter = 64;
    const topPad = 8;
    const innerH = h - topPad - bottomGutter;
    const volH = this.overlays.volume ? Math.round(innerH * 0.22) : 0;
    const candleH = innerH - volH;

    const plot = {
      left: 8, top: topPad,
      right: w - rightGutter,
      bottom: topPad + candleH,
    };
```

Modify to carve out RSI height:

```javascript
    const bottomGutter = 24;
    const rightGutter = 64;
    const topPad = 8;
    const innerH = h - topPad - bottomGutter;
    const volH = this.overlays.volume ? Math.round(innerH * 0.22) : 0;
    const hasRsi = this._indicators.some((i) => i.kind === 'rsi');
    const rsiH = hasRsi ? Math.round(innerH * 0.18) : 0;
    const candleH = innerH - volH - rsiH;

    const plot = {
      left: 8, top: topPad,
      right: w - rightGutter,
      bottom: topPad + candleH,
    };
```

Find the existing `volPlot` block:

```javascript
    const volPlot = volH > 0 ? {
      left: plot.left, top: plot.bottom + 1,
      right: plot.right, bottom: plot.bottom + volH,
    } : null;
```

Add `rsiPlot` after it:

```javascript
    const rsiTop = (volPlot ? volPlot.bottom : plot.bottom) + 1;
    const rsiPlot = hasRsi ? {
      left: plot.left, top: rsiTop,
      right: plot.right, bottom: rsiTop + rsiH,
    } : null;
    if (rsiPlot) {
      rsiPlot.width = rsiPlot.right - rsiPlot.left;
      rsiPlot.height = rsiPlot.bottom - rsiPlot.top;
    }
```

After the existing `_drawOverlays(plot, lo, hi, priceToY)` call (or near where overlays render), add:

```javascript
    this._drawIndicators(plot, lo, hi, priceToY);
    if (rsiPlot) this._drawRsiSubPane(rsiPlot);
```

(SMA/EMA overlays sit on the candle pane; RSI sub-pane gets its own draw.)

Now add the two render methods:

```javascript
  _drawIndicators(plot, lo, hi, priceToY) {
    if (this._indicators.length === 0 || this.candles.length === 0) return;
    const visible = this._visibleCandles();
    if (visible.length === 0) return;
    const firstAbs = this.candles.indexOf(visible[0]);
    const ctx = this.ctx;
    ctx.save();

    for (const ind of this._indicators) {
      if (ind.kind !== 'sma' && ind.kind !== 'ema') continue;
      const values = ind.kind === 'sma'
          ? this._computeSMA(ind.period)
          : this._computeEMA(ind.period);
      ctx.strokeStyle = ind.color || '#3B82F6';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      let started = false;
      for (let i = 0; i < visible.length; i++) {
        const absIdx = firstAbs + i;
        const v = values[absIdx];
        if (v == null) continue;
        const x = this._candleXCenter(absIdx, plot);
        const y = priceToY(v);
        if (!started) { ctx.moveTo(x, y); started = true; }
        else ctx.lineTo(x, y);
      }
      ctx.stroke();

      // Label chip near right edge.
      const label = `${ind.kind.toUpperCase()} ${ind.period}`;
      ctx.font = '600 10px Geist, sans-serif';
      ctx.textBaseline = 'middle';
      ctx.textAlign = 'left';
      const tw = ctx.measureText(label).width + 8;
      const lastVisIdx = visible.length - 1;
      const lastAbs = firstAbs + lastVisIdx;
      const lastV = values[lastAbs];
      if (lastV != null) {
        const lx = this._candleXCenter(lastAbs, plot);
        const ly = priceToY(lastV);
        ctx.fillStyle = ind.color || '#3B82F6';
        this._roundedRect(lx + 4, ly - 8, tw, 16, 3);
        ctx.fill();
        ctx.fillStyle = '#FFFFFF';
        ctx.fillText(label, lx + 8, ly);
      }
    }
    ctx.restore();
  }

  _drawRsiSubPane(rsiPlot) {
    const ctx = this.ctx;
    const rsis = this._indicators.filter((i) => i.kind === 'rsi');
    if (rsis.length === 0 || this.candles.length === 0) return;

    // Background line for clarity (above + below the candle/volume areas).
    ctx.save();
    ctx.fillStyle = this.palette.bg;
    ctx.fillRect(rsiPlot.left, rsiPlot.top, rsiPlot.width, rsiPlot.height);

    // 30 / 70 dashed guides.
    const yFor = (v) => rsiPlot.top + (100 - v) * rsiPlot.height / 100;
    ctx.strokeStyle = this.palette.axisText;
    ctx.lineWidth = 1;
    ctx.setLineDash([3, 3]);
    for (const lvl of [30, 70]) {
      const y = yFor(lvl);
      ctx.beginPath();
      ctx.moveTo(rsiPlot.left, y);
      ctx.lineTo(rsiPlot.right, y);
      ctx.stroke();
    }
    ctx.setLineDash([]);
    // 50 mid-line in lighter.
    ctx.strokeStyle = this.palette.gridSoft;
    ctx.beginPath();
    const ymid = yFor(50);
    ctx.moveTo(rsiPlot.left, ymid);
    ctx.lineTo(rsiPlot.right, ymid);
    ctx.stroke();

    // RSI lines.
    const visible = this._visibleCandles();
    if (visible.length === 0) { ctx.restore(); return; }
    const firstAbs = this.candles.indexOf(visible[0]);

    let labelY = rsiPlot.top + 8;
    for (const ind of rsis) {
      const values = this._computeRSI(ind.period);
      ctx.strokeStyle = ind.color || '#8B5CF6';
      ctx.lineWidth = 1.4;
      ctx.beginPath();
      let started = false;
      for (let i = 0; i < visible.length; i++) {
        const absIdx = firstAbs + i;
        const v = values[absIdx];
        if (v == null) continue;
        const x = this._candleXCenter(absIdx, rsiPlot);
        const y = yFor(v);
        if (!started) { ctx.moveTo(x, y); started = true; }
        else ctx.lineTo(x, y);
      }
      ctx.stroke();

      // Top-left label.
      ctx.font = '600 10px Geist, sans-serif';
      ctx.fillStyle = ind.color || '#8B5CF6';
      ctx.textBaseline = 'middle';
      ctx.textAlign = 'left';
      ctx.fillText(`RSI ${ind.period}`, rsiPlot.left + 4, labelY);
      labelY += 14;
    }
    ctx.restore();
  }
```

Static check: `node --check web/chart-engine/chart.js`.

---

# Group C — Flutter Settings popup UI

### Task C1: Add Indicators section to Settings popup

**Files:** `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`

In `_SettingsButton`'s popup builder, after the Instant orders block, append a new `Indicators` section:

```dart
                    const SizedBox(height: 6),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    _IndicatorsSection(paneIndex: activeIdx),
```

Add the `_IndicatorsSection` widget below the `_ToggleRow` class:

```dart
class _IndicatorsSection extends ConsumerStatefulWidget {
  final int paneIndex;
  const _IndicatorsSection({required this.paneIndex});

  @override
  ConsumerState<_IndicatorsSection> createState() =>
      _IndicatorsSectionState();
}

class _IndicatorsSectionState extends ConsumerState<_IndicatorsSection> {
  bool _menuOpen = false;

  String _newId() =>
      'i-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  String _defaultColor(String kind) {
    switch (kind) {
      case 'sma': return '#3B82F6';
      case 'ema': return '#F59E0B';
      case 'rsi': return '#8B5CF6';
    }
    return '#3B82F6';
  }

  int _defaultPeriod(String kind) => kind == 'rsi' ? 14 : 20;

  void _add(String kind) {
    setState(() => _menuOpen = false);
    ref.read(chartEngineSessionProvider.notifier).addIndicator(
          widget.paneIndex,
          IndicatorConfig(
            id: _newId(),
            kind: kind,
            period: _defaultPeriod(kind),
            color: _defaultColor(kind),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(chartEngineSessionProvider);
    if (widget.paneIndex < 0 || widget.paneIndex >= session.panes.length) {
      return const SizedBox.shrink();
    }
    final inds = session.panes[widget.paneIndex].indicators;
    final mute = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
                child: Text('Indicators',
                    style: MyntWebTextStyles.caption(context,
                        fontWeight: MyntFonts.semiBold))),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: const Size(0, 26),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => setState(() => _menuOpen = !_menuOpen),
              child: const Text('+ Add', style: TextStyle(fontSize: 11)),
            ),
          ]),
          if (_menuOpen)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 6, children: [
                for (final k in ['sma', 'ema', 'rsi'])
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 0),
                      minimumSize: const Size(0, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _add(k),
                    child: Text(k.toUpperCase(),
                        style: const TextStyle(fontSize: 10)),
                  ),
              ]),
            ),
          const SizedBox(height: 4),
          for (final ind in inds) _IndicatorRow(
            paneIndex: widget.paneIndex,
            config: ind,
            mute: mute,
          ),
          if (inds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('None',
                  style: MyntWebTextStyles.caption(context, color: mute)),
            ),
        ],
      ),
    );
  }
}

class _IndicatorRow extends ConsumerStatefulWidget {
  final int paneIndex;
  final IndicatorConfig config;
  final Color mute;
  const _IndicatorRow(
      {required this.paneIndex, required this.config, required this.mute});

  @override
  ConsumerState<_IndicatorRow> createState() => _IndicatorRowState();
}

class _IndicatorRowState extends ConsumerState<_IndicatorRow> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.config.period.toString());
  }

  @override
  void didUpdateWidget(_IndicatorRow old) {
    super.didUpdateWidget(old);
    if (widget.config.period.toString() != _ctl.text) {
      _ctl.text = widget.config.period.toString();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _commit() {
    final v = int.tryParse(_ctl.text) ?? widget.config.period;
    final clamped = v.clamp(1, 999);
    ref.read(chartEngineSessionProvider.notifier).updateIndicator(
          widget.paneIndex,
          widget.config.id,
          period: clamped,
        );
    _ctl.text = clamped.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
              color: Color(int.parse(widget.config.color.replaceAll('#', '0xff'))),
              borderRadius: BorderRadius.circular(2)),
        ),
        Expanded(
          child: Text(
              '${widget.config.kind.toUpperCase()} · ${widget.config.period}',
              style: MyntWebTextStyles.body(context)),
        ),
        SizedBox(
          width: 44,
          height: 24,
          child: TextField(
            controller: _ctl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _commit(),
            onTapOutside: (_) => _commit(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 14),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: () => ref
              .read(chartEngineSessionProvider.notifier)
              .removeIndicator(widget.paneIndex, widget.config.id),
        ),
      ]),
    );
  }
}
```

Static check: `flutter analyze lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart`.

---

### Task C2: Shell push for indicators

**Files:** `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

Add cache field near other `_pushedXxx`:

```dart
final Map<int, String> _pushedIndicatorsJson = {};
```

Inside `_pushSession` per-pane loop, after the drawings push:

```dart
      final indicatorsJson = jsonEncode([for (final i in pane.indicators) i.toJson()]);
      if (force || _pushedIndicatorsJson[i] != indicatorsJson) {
        _pushedIndicatorsJson[i] = indicatorsJson;
        _post(encodeSetPaneIndicators(i.toString(),
            [for (final ind in pane.indicators) ind.toJson()]));
      }
```

In the layout-change cache-clear block, add:

```dart
    _pushedIndicatorsJson.clear();
```

Static check: `flutter analyze lib/screens/web/chart_engine`.

---

# Group D — Static gates + smoke

### Task D1: Final gates

- `flutter analyze lib/screens/web/chart_engine` → No issues
- `node --check web/chart-engine/chart-engine.js web/chart-engine/chart.js web/chart-engine/aggregator.js web/chart-engine/theme.js` → no output
- `node web/chart-engine/aggregator.test.js` → 15 passed

### Task D2: Manual smoke

Spec §7's 10-step list.

---

## Notes for the executing engineer

- **Do not commit.**
- **`_candleXCenter` fractional index**: already accepts a fractional index (verified in Phase 7). Use as-is.
- **Color parsing**: `Color(int.parse(hex.replaceAll('#', '0xff')))` — works for 6-digit hex. If a hex has alpha (8 digits), strip the leading `#` and prefix `0x` directly.
- **Pause and ask** only if a referenced class/method doesn't exist by the exact name.
