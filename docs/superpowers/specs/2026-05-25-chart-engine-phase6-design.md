# Chart Engine — Phase 6 Design

**Date:** 2026-05-25
**Builds on:** Phases 1-5 (multi-pane, overlays, drag-to-modify, `+` menu wired to PlaceOrderScreen)
**Scope summary:** Add a single "Instant orders" toggle that, when ON, bypasses every confirm dialog / order-screen prefill and fires the corresponding API call directly with the toast as the only feedback. Off by default; flip is persisted with the rest of the chart-engine session prefs. Visible "INSTANT" badge in the top bar so the user can never lose track of the mode.

---

## 1. Goal

For each of the four mutation paths in the chart engine, support a "fire immediately" alternative gated by a single global toggle:

| Path | Confirm mode (default) | Instant mode |
|---|---|---|
| Click `×` on **order** chip | `showCloseOrderDialog` (Keep / Cancel order) | `fetchOrderCancel` immediately |
| Click `×` on **position** chip | `showSquareOffDialog` (Keep / Square off MARKET) | `fetchExitPosition` MARKET immediately |
| **Drag-to-modify** line release | `showModifyOrderDialog` (Keep / Modify) | `fetchModifyOrder` with new price immediately |
| **`+` menu pick** (BuyLMT / SellSL / SellSL-LMT) | `PlaceOrderScreenWeb` prefilled | `placeOrder` API directly, then toast |

"Create new order…" entry in the `+` menu IS NOT covered by instant mode — its purpose is to open the blank-ish full form. It always opens `PlaceOrderScreenWeb`.

The qty editor in the **overlay detail popup** (Phase 5+) already has its own explicit "Modify" button — that's a user-initiated commit, not a confirm dialog, so instant mode does NOT change its behaviour.

---

## 2. Visual + interaction

### 2.1 Toggle location

In the existing per-pane `Settings` popup (`chart_engine_top_bar.dart` → `_SettingsButton`), add a third row below Gridlines + Volume:

```
Indicators
  Gridlines             [ON ]
  Volume                [ON ]
─────────────────────────────
  Instant orders        [OFF]
  ⚠ skips confirm dialog for cancels, square-offs, drags & quick place
```

The setting is **global to the chart engine** (NOT per-pane). The Settings popup is per-pane only because the existing overlay toggles are per-pane — the new row reads/writes a session-level field, not a pane-level one. Putting it here keeps discovery cost low.

A small **warning sub-text** under the row (only when OFF, to read as an explanation; not when ON, when the user has clearly opted in).

### 2.2 First-enable confirm

Flipping the toggle from OFF to ON pops a one-time confirm dialog:

```
Enable instant orders?
Mutations (cancel, square-off, drag-modify, quick-place) will fire
immediately on click. There will be no second chance to back out.
[Cancel]  [Enable]
```

On `Cancel` → toggle reverts to OFF and dialog dismisses. On `Enable` → toggle stays ON and we mark the user as "has seen the warning". Subsequent toggles (OFF → ON → OFF → ON) do NOT show the dialog again — once approved, the user is trusted.

The "has seen the warning" flag is stored alongside the toggle in prefs.

### 2.3 Top-bar INSTANT badge

When the toggle is ON, render a small red-amber pill `INSTANT` directly to the right of the `Settings` button:

```
[Layout] Symbol [...] Timeframe [...] [⚙ Settings]   ⚠ INSTANT
```

- Filled background `#F59E0B` (amber/warning), white text, 11px bold, ~60×20px.
- Hidden when toggle is OFF.
- Click the badge → opens the Settings popup (so the user can flip back).

### 2.4 Per-action behaviour

All four paths share the same shape: read the toggle, if ON skip dialog/screen, call the API method directly, show toast.

- **Cancel × on order chip**: instant → `ref.read(orderProvider).fetchOrderCancel(orderNum, context, false)`. Provider already does the toast. No popup, no dialog. The chart line vanishes ~1s later via the order-book WS push.
- **Square-off × on position chip**: instant → reuse the exact `PlaceOrderInput` builder from `showSquareOffDialog` (opposite-side MARKET for full qty) → `ref.read(portfolioProvider).fetchExitPosition(context, input, true, false)`. Provider does the toast.
- **Drag-to-modify mouseup**: instant → reuse the `ModifyOrderInput` builder from `showModifyOrderDialog` (preserves SL-LMT offset for trigger drag) → `ref.read(orderProvider).fetchModifyOrder(input, context)`. No dialog. Line snaps to the new price after the OM WS push.
- **`+` menu pick** (BuyLMT / SellSL-MKT / SellSL-LMT): instant → build a `PlaceOrderInput` mirroring what `PlaceOrderScreenWeb` would build for the chosen prctype/side, fire the existing place-order API. The `+` menu still uses the same prefill function (`buildOrderScreenArgs`) — but in instant mode, we don't open the screen, we synthesise the input directly and call the API.

### 2.5 Failure feedback

API errors flow through whatever toast/snack pattern the providers already use. The chart's UI does not need any extra handling — the toast appears, and the line stays at its old state because the WS won't push a confirmed update.

---

## 3. Data model

### 3.1 Session-level fields (NEW)

`ChartEngineSession` gains two new fields, persisted alongside `layout` / `activePaneIndex` / `panes`:

```dart
class ChartEngineSession {
  final ChartLayout layout;
  final int activePaneIndex;
  final List<PaneState> panes;
  final bool instantOrders;          // NEW — default false
  final bool instantWarningAck;      // NEW — sticky flag, default false
  // ... copyWith / toJson / fromJson updated accordingly
}
```

`instantWarningAck` is a one-way flag (false → true on first Enable, never reverts).

### 3.2 Notifier methods

Two new setters on `ChartEngineSessionNotifier`:

```dart
void setInstantOrders(bool enabled) {
  if (enabled == state.instantOrders) return;
  state = state.copyWith(instantOrders: enabled);
  _schedulePersist();
}

void markInstantWarningAck() {
  if (state.instantWarningAck) return;
  state = state.copyWith(instantWarningAck: true);
  _schedulePersist();
}
```

### 3.3 Iframe push (NEW message)

For the `+` icon to know whether to bypass the menu altogether (NOT in scope — `+` always opens the menu; menu items have the instant logic in Flutter), no iframe-side push is strictly needed. **No bridge changes.** Instant is purely a Flutter-side branch when handling outbound order actions.

---

## 4. Implementation paths

### 4.1 Place-order API for `+` menu in instant mode

`buildOrderScreenArgs` already produces the canonical OrderScreenArgs for each prefill kind. For instant mode we need a sibling helper that produces a `PlaceOrderInput` instead, ready to pass straight to the place-order API:

```dart
PlaceOrderInput buildPlaceOrderInput({
  required ChartScrip scrip,
  required int qty,
  required OrderPrefillKind kind,
  required double price,
  required Map<String, dynamic> deviceInfo,
  required int frzqty,
});
```

The mapping for each kind is the same as in `buildOrderScreenArgs`'s `raw` map — just packaged as a typed `PlaceOrderInput`:

| Kind | prctype | trantype | prc | trgprc |
|---|---|---|---|---|
| buyLimit | LMT | B | price | '' |
| sellLimit | LMT | S | price | '' |
| buyStopMkt | SL-MKT | B | '0' | price |
| sellStopMkt | SL-MKT | S | '0' | price |
| buyStopLmt | SL-LMT | B | price+ti | price |
| sellStopLmt | SL-LMT | S | price-ti | price |
| blank | (always opens screen — NOT instant-eligible) | — | — | — |

Common fields: `exch`, `tsym`, `prd` (CNC for NSE/BSE, NRML for NFO/BFO/MCX), `qty: qty.toString()`, `ret: 'DAY'`, plus the empty defaults that `PlaceOrderInput` requires (`amo: ''`, `blprc: ''`, `bpprc: ''`, `dscqty: ''`, `trailprc: ''`, `mktProt: ''`, `channel`, `frzqty`).

The exact API call to fire: `orderProvider.fetchPlaceOrder(input, context)` (or whatever the provider's direct place-order wrapper is — verified during plan execution; canonical example is `portfolio_provider.dart:1689-1711` for the exit-position pattern, but place-order has its own wrapper).

### 4.2 Branch points

Five existing call sites in `chart_engine_shell_screen.dart` get an `if (session.instantOrders)` branch:

1. `_handleOverlayCloseRequested` for orders — branch around `showCloseOrderDialog`.
2. `_handleOverlayCloseRequested` for positions — branch around `showSquareOffDialog`.
3. `_handleOverlayDragEnded` — branch around `showModifyOrderDialog`.
4. `_openPlaceOrderScreen` for non-blank kinds — branch BEFORE the screen launch.

(Path 4 is the most invasive — `_openPlaceOrderScreen` currently is a single method; refactor to delegate to an "open or instant-fire" helper that does the prefetch + branch.)

### 4.3 Toggle UI

`chart_engine_top_bar.dart`:
- The existing `_SettingsButton` ConsumerStatefulWidget popup gets a third row + a divider above it + the warning sub-text. Reads `session.instantOrders`; writes via `notifier.setInstantOrders(...)`. On OFF→ON, shows the first-enable warning dialog (iframe-safe `_showIframeSafeDialog`-like; can reuse the helper from `overlay_close_dialog.dart`).
- A new `_InstantBadge` widget sits as the LAST child of the top-bar `Wrap`, visible only when `session.instantOrders == true`. Tap → opens the Settings popup.

### 4.4 First-enable dialog

A new helper `showInstantWarningDialog(...)` in `overlay_close_dialog.dart` (or a new `instant_warning_dialog.dart`). Returns `Future<bool>` — true on Enable, false on Cancel. The Settings popup wires:

```dart
onChanged: (newValue) async {
  if (newValue && !session.instantWarningAck) {
    final approved = await showInstantWarningDialog(context: context);
    if (!approved) return; // popup stays OFF
    notifier.markInstantWarningAck();
  }
  notifier.setInstantOrders(newValue);
},
```

---

## 5. Edge cases

| Case | Behaviour |
|---|---|
| User toggles INSTANT OFF mid-action | The action that's already in-flight (e.g., a confirm dialog showing) completes normally per the mode that was active when it started |
| Drag a line then quickly toggle ON before mouseup | Toggle state is read on mouseup; if ON at that moment → instant. Slight race but harmless. |
| Multiple panes, instant ON | All panes share the same instant flag (it's session-level). Each pane's mutations are independent. |
| First-enable dialog dismissed via outside-click | Treated as Cancel; toggle stays OFF |
| Settings popup open while badge is also visible | Clicking the badge with the popup open dismisses the popup (and re-opens? — for simplicity: just toggle popup like clicking Settings) |
| API error in instant mode | Existing toast surfaces the error; chart line stays at original state (provider hasn't updated) |
| Page reload | `instantOrders` and `instantWarningAck` restore from prefs. If ON, badge shows immediately |
| Multi-pane qty mismatch | `+` menu uses the clicked pane's qty (already correct in existing code) |
| Network down during instant | Existing place-order/cancel-order error toasts show normally |

---

## 6. Files to create / modify

### Modified (Flutter)
| Path | What changes |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | Add `instantOrders` + `instantWarningAck` fields to `ChartEngineSession` + `copyWith` + `toJson` + `fromJson`; new notifier methods `setInstantOrders` + `markInstantWarningAck`. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | Add third row to Settings popup (Instant toggle + warning sub-text); add `_InstantBadge` widget at the end of the top-bar Wrap. |
| `lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart` | Add `showInstantWarningDialog` helper (Future&lt;bool&gt;). |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | Five branch points: `_handleOverlayCloseRequested` (orders + positions), `_handleOverlayDragEnded`, `_openPlaceOrderScreen` for non-blank kinds. Each reads `session.instantOrders` and either fires the dialog/screen (default) or calls the API directly. |
| `lib/screens/web/chart_engine/state/place_order_prefill.dart` | New helper `buildPlaceOrderInput(...)` that produces a typed `PlaceOrderInput` from the same prefill kinds (mirror of `buildOrderScreenArgs`). |

No JS changes. No bridge changes.

---

## 7. Acceptance smoke

Confirm-mode (toggle OFF — default) regression first:
1. Cancel × on order → dialog appears as before; Modify, Square off, Place from `+` menu all unchanged.

Instant-mode (toggle ON):
2. Open Settings → see "Instant orders" row + warning sub-text. Toggle ON → first-enable warning dialog appears. Click `Enable` → toggle stays ON, badge "⚠ INSTANT" appears in top bar.
3. Place a LMT order from another tab, return to chart, click × on the new chip → order cancels immediately (toast, no dialog).
4. Click × on a position chip → square-off MARKET fires immediately.
5. Drag a LMT line to a new price → on release, modify fires immediately (toast).
6. Click `+` → "Buy ... limit" → instant order placed (no PlaceOrderScreen). Toast confirms; the new LMT line appears on the chart after the OM WS push.
7. Click `+` → "Create new order…" → STILL opens PlaceOrderScreen blank-ish (this entry is not instant-eligible).
8. Toggle Instant OFF in Settings → no warning dialog. Badge disappears. Subsequent × / drag / `+` menu items revert to dialogs/screen.
9. Toggle ON again → no warning dialog (already acknowledged once).
10. Reload the tab → instant mode persists across reload; badge visible immediately.
11. Page error during instant cancel (e.g., disconnect WiFi) → existing error toast surfaces; chart line stays.
12. Click the `⚠ INSTANT` badge in the top bar → Settings popup opens.

---

## 8. Out of scope (Phase 7+)

- Per-pane instant override (e.g., turn off for one specific risky symbol while ON globally).
- Confirm-once-per-session pattern (i.e., re-prompt warning every session).
- Two-factor / re-authentication before enabling.
- Keyboard shortcuts to toggle instant (e.g., Ctrl+I).
- Audible feedback (beep on instant fire).
- "Instant only inside market hours" guard.
- Tooltip on the badge with current toggle state breakdown.
