# Chart Engine — Phase 9 Design

**Date:** 2026-05-25
**Builds on:** Phases 1-8
**Scope summary:** Add `+TP` and `+SL` quick-add icons next to the existing position chip. Each click opens `PlaceOrderScreenWeb` pre-filled to create the corresponding protective order (Target = opposite-side LMT above/below avg by N%; Stop = opposite-side SL-MKT below/above avg by N%). In Instant mode (Phase 6 ON), fires the order directly without the screen.

---

## 1. Goal

For each open position overlay (the existing solid line + `[qty pnl ×]` chip rendered by Phase 3), add two small icon buttons inline with the chip:

```
[ +20  +₹220   +TP   +SL   × ]
        ↑      ↑     ↑      ↑
       PnL  add TP add SL  close
```

- **`+TP`** click → opens PlaceOrderScreen pre-filled with:
  - Side = opposite of position (long → SELL, short → BUY)
  - Type = `LMT`
  - Price = `avg ± defaultTpPct%` (long → above avg; short → below avg)
  - Qty = position's `|netqty|`
  - Product = position's `prd`
- **`+SL`** click → opens PlaceOrderScreen pre-filled with:
  - Side = opposite of position
  - Type = `SL-MKT`
  - Trigger price = `avg ∓ defaultSlPct%` (long → below avg; short → above avg)
  - Qty = position's `|netqty|`
  - Product = position's `prd`

Default percentages: `defaultTpPct = 1.0` (1%), `defaultSlPct = 0.5` (0.5%). Hardcoded constants for Phase 9; UI configuration deferred.

Instant mode (Phase 6 toggle ON) → fires the same orders directly via `orderProvider.fetchPlaceOrder` instead of opening the screen.

Position chips ONLY (kind == 'position'). Order chips don't get these icons.

---

## 2. Visual + interaction

### 2.1 Chip layout (positions only)

Position chip currently shows `[ qty   pnl   × ]`. Phase 9 inserts two icon segments before the close `×`:

```
| qty   pnl   |TP| |SL|   × |
```

- `TP` button: small box with text "TP" in 9px white bold on a transparent background with a thin white border. Width 24px, height = chipH.
- `SL` button: same styling, text "SL".
- Spacing: 6px between PnL and TP, 4px between TP and SL, 6px between SL and ×.

The close `×` stays at the chip's right edge per Phase 3+.

### 2.2 Hit-test

Three NEW hit rects per position chip:
- `tp` rect (covers the TP button) — action `tp`
- `sl` rect (covers the SL button) — action `sl`
- existing `close` rect — unchanged

Hit-test priority: `close` > `sl` > `tp` > `open` (line/chip body click). Clicking TP/SL posts a new outbound message (NOT the existing `overlayClicked` / `overlayCloseRequested`):

```js
{ type: 'positionTpRequested', value: { paneId, overlayId, clientX, clientY } }
{ type: 'positionSlRequested', value: { paneId, overlayId, clientX, clientY } }
```

### 2.3 Cursor

Hovering over TP/SL boxes → `pointer` cursor (existing hit-test cursor logic; `tp`/`sl` actions also count).

### 2.4 Behaviour on click

#### Confirm mode (default)

Flutter shell receives `positionTpRequested` / `positionSlRequested` → resolves the position from the overlayId (`pos-{exch}-{token}`) → computes the target/stop price → opens `PlaceOrderScreenWeb` via the existing `_openPlaceOrderScreen` helper using new `OrderPrefillKind.tpFromPosition` / `OrderPrefillKind.slFromPosition`.

#### Instant mode (Phase 6 ON)

The same path branches through the instant-place-order code: `buildPlaceOrderInput(...)` with the new prefill kinds → `orderProvider.fetchPlaceOrder(context, input, false)`. No PlaceOrderScreen, just a toast.

### 2.5 No price preview during hover

For Phase 9, the TP/SL buttons just fire on click — no hover preview of where the line will sit. Phase 9.1+ may add a tentative line during hover.

---

## 3. Data model

### 3.1 Prefill kinds (NEW)

`OrderPrefillKind` enum (in `place_order_prefill.dart`) gains two values:

```dart
enum OrderPrefillKind {
  buyLimit,
  sellLimit,
  buyStopMkt,
  sellStopMkt,
  buyStopLmt,
  sellStopLmt,
  blank,
  tpFromPosition,    // NEW — opposite-side LMT at avg ± defaultTpPct%
  slFromPosition,    // NEW — opposite-side SL-MKT at avg ∓ defaultSlPct%
}
```

Both `buildOrderScreenArgs(...)` and `buildPlaceOrderInput(...)` get the new branches:

| kind | side | prctyp | prc | trgprc |
|---|---|---|---|---|
| tpFromPosition (long) | SELL | LMT | avg * 1.01 | '' |
| tpFromPosition (short) | BUY | LMT | avg * 0.99 | '' |
| slFromPosition (long) | SELL | SL-MKT | '0' | avg * 0.995 |
| slFromPosition (short) | BUY | SL-MKT | '0' | avg * 1.005 |

For these two kinds, the helper takes an additional `bool isLong` parameter (since the same kind value means different sides depending on the existing position). Alternatively, the caller passes the resolved side/prctype directly — simpler to add a brand-new helper `buildTpSlArgs(...)` / `buildTpSlPlaceInput(...)` that takes `isLong`.

### 3.2 Bridge messages (NEW inbound)

```js
{ type: 'positionTpRequested', value: { paneId, overlayId, clientX, clientY } }
{ type: 'positionSlRequested', value: { paneId, overlayId, clientX, clientY } }
```

No outbound changes — the iframe already knows the overlay kind from `setPaneOverlays`.

### 3.3 No store changes

Phase 9 is pure rendering + new bridge messages + new shell handlers. The `defaultTpPct` and `defaultSlPct` are constants in `place_order_prefill.dart`.

---

## 4. Architecture

### 4.1 JS — chart.js

Modify `_drawOverlays` per-position branch to:

1. After computing chip segments (qty, pnl), reserve extra width for two TP/SL buttons.
2. Draw the two buttons inside the chip (or as siblings inside the same bg).
3. Add two new `_overlayHits` entries: `{ rect, action: 'tp', overlayId }` and `{ rect, action: 'sl', overlayId }`.

Modify the mousedown hit-test handler to route `tp` / `sl` actions to new outbound message types.

### 4.2 Flutter — shell

In `_onWindowMessage`:

```dart
case 'positionTpRequested':
case 'positionSlRequested':
  _handlePositionTpSlRequested(msg);
  break;
```

`_handlePositionTpSlRequested`:
1. Resolve overlayId → `PositionBookModel` (existing pattern from `_handleOverlayCloseRequested`).
2. Compute side / price / trgprc from `isLong = qty > 0` + the percentages.
3. If `session.instantOrders`: build `PlaceOrderInput` and call `orderProvider.fetchPlaceOrder(context, input, false)` directly.
4. Else: build `OrderScreenArgs` and open `PlaceOrderScreenWeb` via `ResponsiveNavigation.toPlaceOrderScreen`.

### 4.3 Prefill helper

Add to `place_order_prefill.dart`:

```dart
const _defaultTpPct = 0.01;   // 1%
const _defaultSlPct = 0.005;  // 0.5%

double tpPriceFor({required double avg, required bool isLong}) =>
    isLong ? avg * (1 + _defaultTpPct) : avg * (1 - _defaultTpPct);
double slTriggerFor({required double avg, required bool isLong}) =>
    isLong ? avg * (1 - _defaultSlPct) : avg * (1 + _defaultSlPct);

Map<String, dynamic> buildTpSlOrderScreenArgs({
  required ChartScrip scrip,
  required int qty,
  required bool isLong,
  required bool isTp,           // true → TP (LMT), false → SL (SL-MKT)
  required double avg,
  ScripInfoModel? realScripInfo,
});

PlaceOrderInput buildTpSlPlaceOrderInput({
  required ChartScrip scrip,
  required int qty,
  required bool isLong,
  required bool isTp,
  required double avg,
  required Map<String, dynamic> deviceInfo,
});
```

Both helpers wrap the existing primitive builders with TP/SL-specific side/prctype/price/trgprc logic.

---

## 5. Edge cases

| Case | Behaviour |
|---|---|
| Position has qty = 0 (just closed) | Overlay isn't drawn at all; TP/SL buttons never appear |
| Multiple positions in different panes | Each pane's overlays are independent; TP/SL fires for the clicked pane's position |
| Position chip overlapped (vertical stack) | TP/SL hit rects are per-chip; stacking already shifts y |
| Position avg is NaN/invalid | Skip the overlay (existing) — no TP/SL either |
| `+TP` clicked while instant ON | Order placed immediately, toast confirms, position line stays (the new LMT order line appears next via Phase 3 overlay push) |
| Two clicks on `+SL` before order completes | Two SL orders placed (each via OM push). Acceptable — user can cancel one |
| Symbol delisted / circuit hit / market closed | Existing place-order error toast surfaces |
| Position is intra-day MIS — TP triggers near close | Server enforces MIS rules; not Phase 9's concern |

---

## 6. Files to create / modify

### Modified (Flutter)
| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/place_order_prefill.dart` | New `tpFromPosition` / `slFromPosition` enum values; `buildTpSlOrderScreenArgs(...)` + `buildTpSlPlaceOrderInput(...)` helpers; default percentage constants. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | New `case 'positionTpRequested'` + `'positionSlRequested'`; new `_handlePositionTpSlRequested(msg, isTp)` method that branches on `session.instantOrders`. |

### Modified (JS)
| Path | What |
|---|---|
| `web/chart-engine/chart.js` | `_drawOverlays` position-chip branch reserves extra width for TP/SL buttons + draws them + adds new `_overlayHits` entries with `action: 'tp' | 'sl'`. Mousedown intercept routes `tp`/`sl` actions to new outbound message types. |

No JS-engine-side changes (`chart-engine.js` untouched — the new outbound messages don't pass through `handleMessage`). No new files.

---

## 7. Acceptance smoke

1. Open `/charts` on a symbol where you have an open position. The position chip now shows `[qty pnl TP SL ×]`.
2. Hover over the TP button → cursor `pointer`. Click → `PlaceOrderScreenWeb` opens pre-filled: SELL (if long), LMT, price = avg × 1.01, qty = abs(netqty), product = position's prd.
3. Hover/click SL → same screen, pre-filled with SL-MKT, trgprc = avg × 0.995.
4. For a short position: TP fills BUY LMT at avg × 0.99; SL fills BUY SL-MKT at avg × 1.005.
5. Click `×` → still opens the existing Square-off confirm (unchanged).
6. Click the chip body (not TP/SL/×) → still opens the detail popup (unchanged).
7. Toggle Instant ON in Settings → click TP → order fires immediately, toast confirms, new LMT line appears on chart within ~1s. Same for SL.
8. Symbol change → new symbol's position (if any) shows TP/SL too.
9. Order chips (non-position) → no TP/SL buttons (unchanged).
10. Reload tab → behavior persists.

If everything passes, Phase 9 is done.

---

## 8. Out of scope (Phase 9.1+)

- Configurable TP/SL percentages in Settings
- Hover preview of where the TP/SL line will sit
- Drag-to-adjust TP/SL price during the hover preview
- `+TP` / `+SL` rendering on order chips that already have a corresponding paired order (so the user doesn't accidentally double-place)
- `+TP%` / `+SL%` with multiple presets (1%, 2%, 5%, ...)
- Auto-paired bracket orders (link TP+SL to the position so closing one cancels the other) — that's Phase 13 (brackets)
