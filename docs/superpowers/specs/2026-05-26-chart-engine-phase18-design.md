# Chart Engine — Phase 18 Design

**Date:** 2026-05-26
**Builds on:** Phases 1-17 (all shipped)
**Scope summary:** Two independent visual features for the underlying-index chart:
1. **OI bars at strike prices** — horizontal CE/PE bars at each option-chain strike, drawn inside the plot extending leftward from the right edge. Hover anywhere on the bar row shows a small tooltip with `Strike / Call OI / Put OI`. Auto-fetches the option chain every 120s while the pane shows a supported index spot. Per-pane Settings toggle, default OFF.
2. **LTP bar-close countdown** — countdown timer `M:SS` rendered directly under the LTP price chip (extends the existing chip vertically). Updates every second. Per-pane Settings toggle, default ON.

---

## 1. Goal

**18.A — OI bars:** Surface live option-chain OI on the underlying index chart so the trader can see CE/PE accumulation at each strike without leaving the chart. Matches Sahi's "OI Profile" pattern from the user's screenshot.

**18.B — LTP countdown:** Display time remaining until the current candle closes, useful for scalpers timing entries/exits to bar closes.

Both features are per-pane (independent toggles), both ride the existing chart-engine bridge, both are visual-only (no new server APIs beyond what already exists in `market_watch_api.dart`).

---

## 2. Visual

### 2.1 OI bars

For each strike returned by the option-chain API (typically 25 strikes around ATM), draw at the strike's price-Y inside the plot:

```
                                              ╔═══════════╗
                                              ║ CE ▓▓▓▓▓▓ ║  ← strike Y (centered)
                                              ║ PE ▓▓     ║
                                              ╚═══════════╝
                                                          ↑ plot.right - 8px
```

- **Two thin horizontal bars stacked vertically at the strike's Y**
  - CE bar (teal `#22D3EE` or `palette.bull`-derived) — top
  - PE bar (orange `#FB923C` or `palette.bear`-derived) — bottom
  - Bar height: 4px each with 1px gap (total 9px per strike row)
- **Length proportional to OI** relative to the max OI across visible strikes
  - Max bar length: 25% of plot width
  - Right edge: anchored at `plot.right - 8px` (clearance from the price-axis chip area)
- **No inline labels** — values revealed on hover only

Strike rows that fall outside the current visible Y range are skipped. Strikes returned by the API but not in the visible price range don't render at all.

### 2.2 Hover tooltip

When the crosshair is within the OI bar zone (a strip from `plot.right - 25%-of-plot-width` to `plot.right - 8px`):
- Find the strike whose Y is closest to the cursor Y (within a 9px tolerance — the row height)
- Render a small dark tooltip near the cursor:

```
┌──────────────────────────┐
│ Strike:    23950         │
│ Call OI:   1.9Cr  (+3%)  │
│ Put OI:    53.2L  (-1%)  │
└──────────────────────────┘
```

- Tooltip uses the existing `_drawChip`-style background + `palette.crosshairChip` fill
- Numbers formatted in Indian style: `<100K` → raw integer; `100K-1Cr` → `X.XL` (lakhs); `≥1Cr` → `X.XCr` (crores)
- % change uses `oiPerChng` from the API; sign + percent
- If hover is anywhere on the chart EXCEPT the OI strip → no OI tooltip (the existing crosshair price label still draws)

### 2.3 LTP countdown — Style A

The existing LTP chip (rendered by `_drawLtpLine`) gets a second line below the price:

```
   ┌────────┐
   │ 23044  │    ← existing LTP value (palette.bull/bear by direction)
   │ 0:23   │    ← NEW countdown, smaller font, same chip
   └────────┘
```

- Chip vertical height grows by ~12px to fit the countdown row
- Format: `M:SS` (e.g. `0:23`, `1:05`, `14:59`)
- Countdown source: `(lastBar.ts + timeframeMinutes*60) - now()` clamped to ≥0
- Updates every second via a 1Hz timer on the Chart instance (cleared in `destroy`)
- Hide condition: `showBarCountdown === false` on the pane

When countdown reaches 0, the value clamps to `0:00` and stays there until the next bar arrives (which advances `lastBar.ts`). Edge case: on a fresh chart with no bars, no countdown shown.

### 2.4 Settings popup

Two new rows added to the existing "Display" section (just below `Show H / L markers`):

```
┌────────────────────────────────────────┐
│ Chart style        [📊 Candles    ▾]  │
│ Show H / L markers              [ ●] │
│ Show option-chain OI            [ ○] │  ← NEW (default OFF)
│ Show bar countdown              [ ●] │  ← NEW (default ON)
│ ─────────────────────────────────────  │
│ Gridlines                       [ ●] │
│ ...                                    │
```

Both bound to the active pane.

---

## 3. Data model

### 3.1 PaneState additions

```dart
final bool showOptionChainOi;  // default: false
final bool showBarCountdown;   // default: true
```

Same omit-default JSON pattern as Phase 15/16 fields. `copyWith` extended with plain `bool?` params.

Notifier methods:
```dart
void setPaneShowOptionChainOi(int index, bool show);
void setPaneShowBarCountdown(int index, bool show);
```

### 3.2 Transient OI cache notifier

New file: `lib/screens/web/chart_engine/state/chart_oi_data.dart`

```dart
class ChartOiStrike {
  final double strike;
  final double callOi;
  final double putOi;
  final double callOiChgPct;
  final double putOiChgPct;
  // ... const ctor + fromJson-like factory ...
}

class ChartOiData {
  final Map<int, List<ChartOiStrike>> byPane;  // paneIdx → strikes
  final Map<int, int> fetchedAtByPane;          // paneIdx → epoch ms
  const ChartOiData({this.byPane = const {}, this.fetchedAtByPane = const {}});
  ChartOiData copyWith({...}) => ...;
}

class ChartOiDataNotifier extends Notifier<ChartOiData> {
  @override ChartOiData build() => const ChartOiData();
  void setForPane(int idx, List<ChartOiStrike> strikes) { ... }
  void clearForPane(int idx) { ... }
}

final chartOiDataProvider =
    NotifierProvider<ChartOiDataNotifier, ChartOiData>(
  ChartOiDataNotifier.new);
```

No persistence (refetched on every chart open).

---

## 4. Architecture

### 4.1 OI fetch loop

The shell screen owns a periodic fetcher:

- On `_pushSession` or on every periodic tick (existing 1Hz tick path is acceptable):
  - For each pane:
    - If `pane.showOptionChainOi == true`
    - AND `pane.scrip` matches a supported underlying (reuse Phase 17.A's `_kIndexUnderlyings` map)
    - AND `(now - chartOiData.fetchedAtByPane[i]) >= 120_000` (120s refresh window)
    - → call `marketWatchProvider.api.getOptionChain(strPrc: <current spot LTP>, tradeSym: <NIFTY>, exchange: 'NFO' or 'BFO', numofStrike: '25')` directly (not via the provider's `fetchOptionChain` to avoid global state pollution)
    - On success: parse `optValue[]` into `ChartOiStrike` list and write to `chartOiDataProvider.setForPane(i, ...)`. Set `fetchedAtByPane[i] = now`.
    - On error: log + retry on next tick (no toast — silent best-effort)

Exchange map (option chain `exch` param): NIFTY/BANKNIFTY/FINNIFTY/MIDCPNIFTY → `NFO`; SENSEX → `BFO`. Add to `option_underlying_match.dart` as a second const map keyed by the same underlying names.

Current spot LTP source: `pane.scrip` is the index spot. Its LTP can come from `marketWatchProvider.tickerData[token]` or similar. If LTP is unknown (e.g. first-load before a tick), use the previous-close fallback OR skip this fetch (try again next tick). Decision: **skip** — cleaner than seeding with stale data.

When the user toggles OFF / switches symbol / removes the pane:
- Toggle OFF → call `chartOiDataProvider.clearForPane(i)`. Stop fetching.
- Symbol change → bridge already invalidates per-pane caches; mirror this for OI data (clear + reset fetched-at).
- Pane removed (layout change) → clear all out-of-range entries on next push.

### 4.2 Push OI data to iframe

New bridge encoder + message handler:

```dart
String encodeSetPaneOiData(String paneId, List<Map<String, Object?>> strikes) =>
    jsonEncode({
      'type': 'setPaneOiData',
      'value': {'paneId': paneId, 'strikes': strikes},
    });
```

Strike payload (per entry):
```js
{
  strike: 23950,
  callOi: 19000000,      // raw OI (number of units)
  putOi: 5320000,
  callOiChgPct: 3.2,     // % change in OI
  putOiChgPct: -1.0,
}
```

Shell pushes on every `_pushSessionInner` (gated by diff-cache: only post when the strikes list actually changes — JSON-stringify cache like other per-pane fields).

JS side (`chart-engine.js`) adds:
```js
case 'setPaneOiData': {
  const { paneId, strikes } = d.value || {};
  if (typeof paneId !== 'string' || !Array.isArray(strikes)) return;
  const chart = panes.get(paneId);
  if (chart) chart.setOiData(strikes);
  break;
}
```

And the show-flag is part of the existing per-pane field push (new encoder `encodeSetPaneShowOptionChainOi` and `encodeSetPaneShowBarCountdown` — mirrors `encodeSetPaneHighLowMarkers`).

### 4.3 Chart.js — OI bar render

New methods:
- `setOiData(strikes)` — store on the instance, schedule redraw
- `setShowOptionChainOi(show)` — flag setter
- `setShowBarCountdown(show)` — flag setter
- `_drawOiBars(plot, lo, hi, priceToY)` — renders the bars
- `_drawOiHoverTooltip(plot, lo, hi, priceToY)` — renders the hover tooltip if cursor is within the OI strip

Render algorithm:
```
if !showOptionChainOi || _oiData.length === 0: return
maxOi = max over visible strikes of max(callOi, putOi)
if maxOi <= 0: return
maxBarLen = plot.width * 0.25
barRight = plot.right - 8
barH = 4
gap = 1
for each strike in _oiData:
  if strike < lo || strike > hi: continue  // outside visible Y
  y = priceToY(strike)
  // CE bar (top): teal, length = (callOi/maxOi) * maxBarLen
  // PE bar (bottom): orange, length = (putOi/maxOi) * maxBarLen
```

Hover tooltip:
- Triggered inside `draw()` after the OI bars are drawn, BEFORE the LTP chip
- If `this.hover.inside && this.hover.x > (barRight - maxBarLen) && this.hover.x < barRight`:
  - Find strike with min `|priceToY(strike) - hover.y|` within 9px
  - Render tooltip just left of the cursor (or to the right if there's no room left) with formatted CE/PE OI + % change

Z-order: OI bars are drawn after candles + indicators + drawings (Phase 7+) but BEFORE the LTP chip, order chips, and crosshair. The crosshair Y line still draws across the bars (slightly overlapping is fine).

### 4.4 Chart.js — LTP countdown

In the existing `_drawLtpLine(plot, priceToY, lo, hi)`:
- Compute `secsToClose = max(0, (lastBar.ts + this.timeframeMinutes*60) - Math.floor(Date.now()/1000))`
- After drawing the existing LTP chip, if `this.showBarCountdown && secsToClose >= 0`:
  - Extend the chip's height by `12px`
  - Draw second text line `M:SS` inside the extended chip, smaller font (9-10px), same text color

Format: `Math.floor(secs/60) + ':' + String(secs % 60).padStart(2, '0')`.

Update cadence: the chart already redraws on every WS tick and on a 1Hz auto-redraw timer (verify by reading current code; if no such timer exists, add one in the constructor that calls `scheduleRedraw()` every 1000ms when `showBarCountdown` is true, and `clearInterval` it in `destroy`).

### 4.5 Settings popup UI

Two new ConsumerWidget rows added to `chart_engine_top_bar.dart` near `_PaneHighLowMarkersSection`:

- `_PaneShowOptionChainOiSection` — Switch row labeled `Show option-chain OI` bound to `pane.showOptionChainOi`
- `_PaneShowBarCountdownSection` — Switch row labeled `Show bar countdown` bound to `pane.showBarCountdown`

Both insert into the popup's Display section (just after `_PaneHighLowMarkersSection`).

---

## 5. Edge cases

| Case | Behaviour |
|---|---|
| Pane shows non-supported scrip (e.g. RELIANCE stock) | Toggle is visible but no data fetched; OI bars never render. |
| Pane LTP is unknown (first load, no tick yet) | Skip the fetch; retry on next tick. |
| API returns empty / error | Silent best-effort; existing data retained; retry after 120s. |
| User toggles ON when OFF | Immediate fetch on the next tick (not waiting 120s from a fake "0" fetched-at). |
| User toggles OFF | Clear cache for that pane; bars disappear. |
| Layout shrink (pane removed) | Clear orphan entries on next push. |
| Symbol change on the same pane | Clear OI cache for that pane; refetch when the new scrip's LTP is known. |
| Multiple panes on same underlying | Each pane fetches independently. Acceptable — API hits are cheap; future opt: shared cache. |
| Bar countdown on a fresh chart with no candles | Don't render the countdown line. |
| Bar countdown when `Date.now() > lastBar.ts + tf*60` | Clamp to `0:00`. Stays at `0:00` until the next bar arrives. |
| 1Hz redraw timer leak | `destroy()` must clear the interval. |

---

## 6. Files

| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | Add `showOptionChainOi` + `showBarCountdown` to `PaneState`. Two new notifier methods. |
| `lib/screens/web/chart_engine/state/chart_oi_data.dart` | NEW: `ChartOiStrike`, `ChartOiData`, `ChartOiDataNotifier`, `chartOiDataProvider`. |
| `lib/screens/web/chart_engine/state/option_underlying_match.dart` | Add `_kIndexOptionExchanges` map (underlying → 'NFO' / 'BFO'). |
| `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart` | Three new encoders: `encodeSetPaneOiData`, `encodeSetPaneShowOptionChainOi`, `encodeSetPaneShowBarCountdown`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | OI fetch loop + push to iframe + push the two new flags. Diff-cache for OI JSON. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | Two new Settings rows. |
| `web/chart-engine/chart-engine.js` | Three new message handlers (`setPaneOiData`, `setPaneShowOptionChainOi`, `setPaneShowBarCountdown`). |
| `web/chart-engine/chart.js` | Constructor state (`_oiData`, `showOptionChainOi`, `showBarCountdown`, 1Hz interval). Setters. `_drawOiBars` + `_drawOiHoverTooltip` + LTP-chip countdown extension. `destroy` clears interval. |

No persistence beyond the 2 new boolean flags. No API changes.

---

## 7. Acceptance smoke

1. Open `/charts` with a NIFTY spot pane. Open Settings → toggle "Show option-chain OI" ON. Within ~2s, CE/PE bars appear at strikes inside the visible Y range.
2. Hover the mouse over one of the bar rows → tooltip appears with `Strike / Call OI / Put OI / change %`.
3. Move the mouse outside the bar strip → tooltip disappears, normal crosshair behaviour resumes.
4. Wait ~120s → bars refresh (you can verify with Network tab showing a new `GetOptionChain` POST).
5. Toggle OFF → bars disappear; fetches stop.
6. Switch the same pane to BANKNIFTY → bars appear with BANKNIFTY's strikes after the next fetch.
7. Switch the pane to a non-supported scrip (e.g. RELIANCE) → no bars, no errors.
8. cols2: pane 0 = NIFTY with OI ON, pane 1 = NIFTY with OI OFF → only pane 0 fetches/renders.
9. Bar countdown: by default, the LTP chip shows `0:XX` ticking down. Verify it changes every second. Wait for a candle to close → countdown jumps to `tf-1:59`.
10. Toggle "Show bar countdown" OFF → countdown disappears, chip shrinks back to single line.
11. Reload tab → both per-pane flags persist.
12. Existing flows (drag-modify, position close, alerts, indicators, drawings) unaffected.

---

## 8. Out of scope (Phase 18.1+)

- OI bars on option charts themselves (the option's strike line on its own chart) — irrelevant; the strike is implicit
- OI bars on futures of the underlying — deferred (same scope question as 17.A)
- Stock-option OI (RELIANCE, TCS, etc.) — deferred (lookup map needs stock-to-NFO mapping)
- Shared OI cache across panes on the same underlying — current per-pane fetch is fine
- OI bar tap → open option chain in a side panel — out of scope
- Configurable strike count (currently hardcoded to 25) — defer
- Configurable refresh interval — defer
- Raw OI delta value in tooltip (currently only %) — defer
