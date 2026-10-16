# Chart Engine — Phase 12 Design

**Date:** 2026-05-25
**Builds on:** Phases 1-11 (Phase 3 overlay rendering, Phase 4 `+` menu)
**Scope summary:** Surface the app's existing server-side price alerts in the chart engine — render pending alerts as horizontal dashed lines per scrip, add "Set Alert at price" to the `+` menu (creates an LTP_A or LTP_B server alert depending on whether the clicked price is above or below current LTP), and `×` on an alert chip cancels it via the existing `fetchCancelAlert` API. No new persistence — `marketWatchProvider.alertPendingModel` is the source of truth.

---

## 1. Goal

For each pane's scrip:

1. **Render** every pending alert from `marketWatchProvider.alertPendingModel` whose `exch+token` matches the pane's scrip. Dashed amber line at the alert price, label `[ ALERT ↑/↓ ]` + close `×`.
2. **Create** a new alert via the `+` menu — a new menu item `Set Alert at <price>` (3rd from bottom). Click → `marketWatchProvider.fetchSetAlert(...)` with `LTP_A` if clicked price > current LTP, else `LTP_B`. Provider handles the toast + list refresh.
3. **Delete** an alert by clicking the `×` on its chip → confirm dialog → `marketWatchProvider.fetchCancelAlert(alertId, context)`.
4. **Auto-refresh** — `marketWatchProvider.alertPendingModel` is already updated by the existing app's WS `'am'` handler. The chart just `ref.listen`s and re-pushes overlays when the list changes.

No edit-in-place (drag-to-modify) for alerts in Phase 12. Existing alerts can be deleted + re-created.

---

## 2. Visual

### 2.1 Alert overlay

A new overlay kind `'alert'` in the existing per-pane overlay payload (Phase 3). Rendering:

- **Line:** dashed `[6, 4]` 1.5px in amber `#F59E0B`
- **Dot:** filled amber dot on rightmost candle (same pattern as order chips)
- **Chip:** anchored at the existing right-side position (per Phase 10 anchor logic). Text: `↑ ALERT` for `LTP_A`, `↓ ALERT` for `LTP_B`. Background amber + white text (consistent with chip rules)
- **Gutter price chip:** small amber chip with the alert price, mirroring the order overlay gutter chip

### 2.2 `+` menu

The Phase 4 `+` menu currently has 4 items:
- Buy N SYMBOL @ price limit
- Sell N SYMBOL @ price stop
- Sell N SYMBOL @ price stop, price-ti limit
- ──
- Create new order…

Add a 5th item (above "Create new order"):
```
🔔 Set Alert at <price>
```

Click → posts new `alertSetRequested { paneId, price, clientX, clientY }` to Flutter.

### 2.3 Close-confirm dialog

Same pattern as `showCloseOrderDialog`:

```
Title:  Cancel alert
Body:   Cancel alert at <price> for <tsym>?
        [Keep] [Cancel alert]
```

On confirm → `marketWatchProvider.fetchCancelAlert(alertId, context)`. Existing provider handles the toast and list refresh.

---

## 3. Data flow

### 3.1 Overlay computation

Extend `overlaysForPane(scrip, positions, orders)` in `lib/screens/web/chart_engine/state/overlay_payload.dart` to take a third source — alerts. Add an `alert` overlay map per matching alert:

```dart
{
  'id': 'alert-${alert.alId}',
  'kind': 'alert',
  'side': alert.aiT == 'LTP_A' ? 'buy' : 'sell', // up vs down arrow
  'qty': 0,            // unused for alert chip text
  'price': double.tryParse(alert.pp ?? '') ?? 0,
}
```

`buildPlaceOrderInput`-style: signature gains a `List<AlertPendingModel> alerts` parameter.

### 3.2 Shell wiring

In `_pushSession`:
- Read `ref.read(marketWatchProvider).alertPendingModel ?? const []`
- Filter by scrip in `overlaysForPane(...)`
- Existing per-pane overlay diff-cache pushes when the list changes

Add `ref.listen(marketWatchProvider, ...)` calling `_pushSession()` so an alert add/cancel/trigger updates the chart.

### 3.3 New inbound message

```js
// `+` menu "Set Alert" pick
{ type: 'alertSetRequested', value: { paneId, price, clientX, clientY } }
```

Handler in shell:
1. Resolve scrip from paneId
2. Get current LTP from `marketWatchProvider.socketDatas[scrip.token]?['lp']`
3. Compute `alertType = clickedPrice > ltp ? 'LTP_A' : 'LTP_B'`
4. Call `marketWatchProvider.fetchSetAlert(scrip.exch, scrip.tsym, price.toString(), alertType, context, alertPendingModel.length, ltp.toString(), '')`

### 3.4 Close × → cancel alert

The existing `overlayCloseRequested` handler in shell needs to branch on `overlayId.startsWith('alert-')` → opens `showAlertCancelDialog(...)` instead of the order/position dialogs.

---

## 4. Architecture

### 4.1 JS

- `chart.js`: add `'alert'` to overlay rendering. Color = `#F59E0B`. Label text constructed differently (`↑ ALERT` / `↓ ALERT` instead of qty + pnl).
- `chart.js`: in the `+` popup menu builder (currently 4 items), add the "Set Alert" entry.
- Actually the `+` menu is in Flutter (`plus_menu_popup.dart`), not JS. The JS just posts `plusClicked` with the price; Flutter renders the menu.

### 4.2 Flutter

- `place_order_prefill.dart`: extend `OrderPrefillKind` with `setAlert` (just for menu labeling — handled via separate path).
- `plus_menu_popup.dart`: add a "🔔 Set Alert at <price>" row.
- `overlay_payload.dart`: extend signature + add alert mapping.
- `chart_engine_shell_screen.dart`:
  - `ref.listen(marketWatchProvider, ...)` → `_pushSession()`.
  - In `_pushSession`, pass `alertPendingModel` to `overlaysForPane`.
  - `_handleOverlayCloseRequested` branches on `alert-` prefix.
  - New handler `_handleAlertSetRequested(paneIndex, price)`.
- `overlay_close_dialog.dart`: new `showAlertCancelDialog(...)` helper.

### 4.3 No new bridge messages outbound

- Reuse `setPaneOverlays` (alerts are just another `kind`).
- Reuse `overlayCloseRequested` (shell branches on id prefix).
- Reuse `plusClicked` (Flutter menu handles the new item).

NEW outbound message: `alertSetRequested` from the `+` menu's "Set Alert" pick — only used inside Flutter (no JS round-trip needed since the menu is Flutter-only). Actually wait: the menu IS Flutter, so it can call the handler DIRECTLY. No outbound message needed.

Final wire: `plus_menu_popup.dart` adds an `onSetAlert` callback. Shell sets `_openPlusMenu` to pass a callback that, on "Set Alert" pick, calls `_handleAlertSetRequested(paneIndex, price)`.

---

## 5. Edge cases

| Case | Behaviour |
|---|---|
| Clicked price exactly equals current LTP | Default to `LTP_A` (above) — minor edge; server may reject and we surface error |
| LTP unknown (no tick yet) | Skip alert creation; toast "LTP unavailable" |
| Alert at LTP_A but price ≤ LTP | Existing server validation rejects → existing error toast surfaces |
| Multiple alerts at same price | Each renders independently; stacking handled by existing overlay placement |
| Alert triggers (server fires) | WS `'am'` already handled by app; alert disappears from `alertPendingModel`; chart's next `_pushSession` removes its line |
| User cancels an alert | `fetchCancelAlert` → provider refreshes list → chart updates |
| Symbol change | New scrip's alerts render; old scrip's alerts disappear |
| Alert price string is non-numeric | Skip the overlay silently |

---

## 6. Files to create / modify

### Modified (Flutter)
| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/overlay_payload.dart` | Extend `overlaysForPane` signature with `alerts: List<AlertPendingModel>`; emit alert overlays. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | `ref.listen(marketWatchProvider)` → `_pushSession`; pass `alertPendingModel` into `overlaysForPane`; branch `_handleOverlayCloseRequested` on `alert-` prefix; new method `_handleAlertSetRequested(paneIndex, price)`. |
| `lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart` | New `showAlertCancelDialog(...)` helper using existing `_showIframeSafeDialog`. |
| `lib/screens/web/chart_engine/widgets/plus_menu_popup.dart` | Add "🔔 Set Alert at <price>" row above "Create new order"; new `onSetAlert` callback. |

### Modified (JS)
| Path | What |
|---|---|
| `web/chart-engine/chart.js` | `_overlayLineColor` / `_overlayDash` / `_overlayLineWidth` extend for `'alert'` kind; chip label override (`↑ ALERT` / `↓ ALERT`) for alert kind in `_drawOverlays`. |

No new files. No bridge encoders.

---

## 7. Acceptance smoke

1. Open `/charts` on a symbol with existing pending alerts → dashed amber lines render at each alert price with `↑ ALERT` (above-LTP alerts) or `↓ ALERT` (below-LTP alerts) chips.
2. Click `+` icon at some price → menu opens with new item `🔔 Set Alert at 1356.80`.
3. Click "Set Alert" → server creates the alert; existing toast confirms; new amber line appears on the chart within ~1s.
4. Click `×` on an alert chip → confirm dialog `Cancel alert at 1356.80 for RELIANCE-EQ?` → Confirm → alert removed; line disappears.
5. When the alert actually triggers (LTP crosses the price), the server pushes `am` → existing alert handler fires (broker message toast); the alert disappears from `alertPendingModel`; chart's overlay disappears within the next push.
6. Reload tab → alerts persist (server-side).
7. Multi-pane same symbol → both panes show the same alerts.

If everything passes, Phase 12 is done.

---

## 8. Out of scope (Phase 12.1+)

- Drag-to-modify alert price (use cancel + re-create instead)
- Alert remarks editing
- Conditional alerts (price change %, volume, indicator crosses)
- In-chart trigger notification (toast appears via existing global handler; chart could later highlight the triggered line briefly)
- "Snooze" / re-arm
- Per-pane alert toggle (alerts always show)
- Sub-pane indicator alerts (e.g., RSI < 30)
