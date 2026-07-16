# Chart Engine — Phase 12 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Surface server-side price alerts on the chart. Render `marketWatchProvider.alertPendingModel` entries as overlay lines, `+` menu gets a `Set Alert at <price>` item that calls `fetchSetAlert`, `×` on alert chip calls `fetchCancelAlert` with a confirm.

**Architecture:** Alerts piggy-back on the Phase 3 per-pane overlay payload — new `'alert'` kind in the `kind` field. Existing rendering, hit-test, and message paths are extended. Auto-refresh via `ref.listen(marketWatchProvider, _pushSession)`. WS `'am'` triggers are already handled by the existing app.

## Project conventions

- **No git commits.**
- **Static gates after every edit:** `flutter analyze lib/screens/web/chart_engine` + `node --check web/chart-engine/chart.js`.
- **Spec reference:** `docs/superpowers/specs/2026-05-25-chart-engine-phase12-design.md`.
- **Reuse:** Phase 3's `overlayCloseRequested` outbound + branching shell handler; Phase 4's `+` menu popup widget; `_showIframeSafeDialog` from `overlay_close_dialog.dart`.

## File map

| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/overlay_payload.dart` | Add `alerts: List<AlertPendingModel>` param + emit alert overlay maps. |
| `lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart` | New `showAlertCancelDialog(...)` helper. |
| `lib/screens/web/chart_engine/widgets/plus_menu_popup.dart` | Add "Set Alert at <price>" row + `onSetAlert` callback. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | `ref.listen(marketWatchProvider)`; pass alerts into `overlaysForPane`; branch `_handleOverlayCloseRequested` on `alert-` prefix; new `_handleAlertSetRequested`; wire the menu callback. |
| `web/chart-engine/chart.js` | `_overlayLineColor` / `_overlayDash` for `'alert'` kind; alert chip label `↑ ALERT` / `↓ ALERT` in `_drawOverlays`. |

No new files. No bridge encoders. No `chart-engine.js` changes.

## Task ordering

1. **Group A — Overlay payload + JS render.**
2. **Group B — `+` menu Set Alert + shell wiring.**
3. **Group C — Cancel-alert dialog + close branch.**
4. **Group D — Static gates + smoke.**

---

# Group A — Overlay payload + JS render

### Task A1: Extend `overlaysForPane` to include alerts

**Files:** `lib/screens/web/chart_engine/state/overlay_payload.dart`

- [ ] **Step 1: Add import + extend signature**

Add at the top:

```dart
import 'package:mynt_plus/models/alert_pending_model/alert_pending_model.dart';
```

(If the actual model file lives at a different path — grep for `class AlertPendingModel` — use that.)

Find `List<Map<String, Object?>> overlaysForPane({required ChartScrip? scrip, required List<PositionBookModel> positions, required List<OrderBookModel> orders})`. Add a 4th required param:

```dart
List<Map<String, Object?>> overlaysForPane({
  required ChartScrip? scrip,
  required List<PositionBookModel> positions,
  required List<OrderBookModel> orders,
  required List<AlertPendingModel> alerts,
}) {
```

- [ ] **Step 2: Append alert mapping after the existing position/order loops**

At the bottom of the function (before `return out;`):

```dart
  for (final a in alerts) {
    if (a.exch != scrip!.exch || a.token != scrip.token) continue;
    final price = double.tryParse(a.pp ?? '');
    if (price == null || price <= 0) continue;
    final aiT = a.aiT ?? '';
    out.add({
      'id': 'alert-${a.alId ?? ''}',
      'kind': 'alert',
      'side': aiT == 'LTP_A' ? 'buy' : 'sell',
      'qty': 0,
      'price': price,
    });
  }
```

(Wrap the scrip-null check correctly — the existing function returns early if scrip is null. Place the loop only inside the non-null branch.)

- [ ] **Step 3: Static check**

`flutter analyze lib/screens/web/chart_engine/state/overlay_payload.dart 2>&1 | tail -5`.

---

### Task A2: Render alert kind in chart.js

**Files:** `web/chart-engine/chart.js`

- [ ] **Step 1: Extend `_overlayLineColor`**

Find:

```javascript
  _overlayLineColor(ov) {
    if (ov.kind === 'sl' || ov.kind === 'sl-l') return this.palette.short;
    return ov.side === 'buy' ? this.palette.long : this.palette.short;
  }
```

Replace:

```javascript
  _overlayLineColor(ov) {
    if (ov.kind === 'alert') return '#F59E0B';
    if (ov.kind === 'sl' || ov.kind === 'sl-l') return this.palette.short;
    return ov.side === 'buy' ? this.palette.long : this.palette.short;
  }
```

- [ ] **Step 2: Extend `_overlayDash`**

Find:

```javascript
  _overlayDash(ov) {
    if (ov.kind === 'position') return [];
    if (ov.kind === 'limit') return [6, 4];
    if (ov.kind === 'sl-l') return [4, 4];
    return [2, 3]; // sl
  }
```

Replace:

```javascript
  _overlayDash(ov) {
    if (ov.kind === 'position') return [];
    if (ov.kind === 'alert') return [6, 4];
    if (ov.kind === 'limit') return [6, 4];
    if (ov.kind === 'sl-l') return [4, 4];
    return [2, 3]; // sl
  }
```

- [ ] **Step 3: Extend `_overlayTypeLabel`**

Find:

```javascript
  _overlayTypeLabel(ov) {
    if (ov.kind === 'limit') return 'LMT';
    if (ov.kind === 'sl') return 'SL';
    if (ov.kind === 'sl-l') return 'SL-L';
    return null; // position has no type label
  }
```

Replace:

```javascript
  _overlayTypeLabel(ov) {
    if (ov.kind === 'limit') return 'LMT';
    if (ov.kind === 'sl') return 'SL';
    if (ov.kind === 'sl-l') return 'SL-L';
    if (ov.kind === 'alert') return ov.side === 'buy' ? '↑ ALERT' : '↓ ALERT';
    return null;
  }
```

- [ ] **Step 4: Suppress qty/pnl text for alerts**

In `_drawOverlays`, find the label composition near the top of the per-overlay loop:

```javascript
      const qtyText = this._formatOverlayQty(ov.qty);
      const typeText = this._overlayTypeLabel(ov);
      const pnlText = ov.kind === 'position' ? this._formatOverlayPnl(ov.pnl) : '';
      const segs = [qtyText];
      if (typeText) segs.push(typeText);
      if (pnlText) segs.push(pnlText);
```

Replace with:

```javascript
      const isAlert = ov.kind === 'alert';
      const qtyText = isAlert ? '' : this._formatOverlayQty(ov.qty);
      const typeText = this._overlayTypeLabel(ov);
      const pnlText = ov.kind === 'position' ? this._formatOverlayPnl(ov.pnl) : '';
      const segs = [];
      if (qtyText) segs.push(qtyText);
      if (typeText) segs.push(typeText);
      if (pnlText) segs.push(pnlText);
```

(Alerts show only the `↑/↓ ALERT` type label, no qty or pnl.)

- [ ] **Step 5: Static check**

`node --check web/chart-engine/chart.js`.

---

# Group B — `+` menu Set Alert + shell wiring

### Task B1: Add "Set Alert" item to PlusMenuPopup

**Files:** `lib/screens/web/chart_engine/widgets/plus_menu_popup.dart`

- [ ] **Step 1: Extend the constructor with `onSetAlert` callback**

```dart
class PlusMenuPopup extends StatelessWidget {
  final Offset anchor;
  final String symbol;
  final int qty;
  final double price;
  final ValueChanged<OrderPrefillKind> onPick;
  final VoidCallback onSetAlert;      // NEW
  final VoidCallback onDismiss;

  const PlusMenuPopup({
    super.key,
    required this.anchor,
    required this.symbol,
    required this.qty,
    required this.price,
    required this.onPick,
    required this.onSetAlert,
    required this.onDismiss,
  });
```

- [ ] **Step 2: Add a Set Alert row above "Create new order"**

Find the existing menu items in `build`. After the SL-LMT item and before the Divider, insert:

```dart
item('🔔  Set Alert at ${price.toStringAsFixed(2)}',
    Icons.notifications_active_outlined,
    resolveThemeColor(context,
        dark: const Color(0xFFF59E0B),
        light: const Color(0xFFD97706)),
    onSetAlert),
```

(The existing `item(label, icon, color, onTap)` helper is local to this build; verify its signature and use the same shape.)

- [ ] **Step 3: Static check**

`flutter analyze lib/screens/web/chart_engine/widgets/plus_menu_popup.dart`.

---

### Task B2: Wire alerts + `_pushSession` + set-alert handler in shell

**Files:** `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add import**

```dart
import 'package:mynt_plus/models/alert_pending_model/alert_pending_model.dart';
```

(Adjust path if the model lives elsewhere.)

- [ ] **Step 2: Pass alerts into `overlaysForPane`**

Find in `_pushSession`:

```dart
      final overlays = overlaysForPane(
        scrip: pane.scrip,
        positions: positions,
        orders: orders,
      );
```

Add the alerts argument:

```dart
      final alerts =
          ref.read(marketWatchProvider).alertPendingModel ?? const [];
      final overlays = overlaysForPane(
        scrip: pane.scrip,
        positions: positions,
        orders: orders,
        alerts: alerts,
      );
```

(`alerts` is read once per `_pushSession` call — works because `_pushSession` is invoked from `ref.listen` whenever `marketWatchProvider` changes.)

- [ ] **Step 3: Listen on `marketWatchProvider`**

Near the existing `ref.listen(portfolioProvider, ...)` / `ref.listen(orderProvider, ...)` calls in `build`:

```dart
    ref.listen(marketWatchProvider, (_, __) {
      if (_iframeReady) _pushSession();
    });
```

- [ ] **Step 4: Branch `_handleOverlayCloseRequested` on `alert-` prefix**

Find the existing handler. Add a branch BEFORE the position/order resolution:

```dart
    if (overlayId.startsWith('alert-')) {
      final alertId = overlayId.substring('alert-'.length);
      final alerts =
          ref.read(marketWatchProvider).alertPendingModel ?? const [];
      AlertPendingModel? alert;
      for (final a in alerts) {
        if (a.alId == alertId) { alert = a; break; }
      }
      if (alert != null) {
        showAlertCancelDialog(context: context, ref: ref, alert: alert);
      }
      return;
    }
```

- [ ] **Step 5: Add `_handleAlertSetRequested` method**

Near `_handlePositionTpSlRequested`:

```dart
Future<void> _handleAlertSetRequested(int paneIndex, double price) async {
  final session = ref.read(chartEngineSessionProvider);
  if (paneIndex < 0 || paneIndex >= session.panes.length) return;
  final scrip = session.panes[paneIndex].scrip;
  if (scrip == null) return;
  final mw = ref.read(marketWatchProvider);
  final socketEntry = mw.socketDatas[scrip.token];
  final ltpStr = socketEntry is Map ? socketEntry['lp']?.toString() : null;
  final ltp = double.tryParse(ltpStr ?? '');
  if (ltp == null || ltp <= 0) return;
  final alertType = price > ltp ? 'LTP_A' : 'LTP_B';
  final existing = mw.alertPendingModel ?? const [];
  await mw.fetchSetAlert(
    scrip.exch,
    scrip.tsym,
    price.toStringAsFixed(2),
    alertType,
    context,
    existing.length,
    ltp.toStringAsFixed(2),
    '',
  );
}
```

(If `fetchSetAlert`'s signature differs from this — grep the provider and use the canonical form. The existing `set_alert_screen.dart` caller is the reference.)

- [ ] **Step 6: Wire the menu callback in `_openPlusMenu`**

Find:

```dart
    _plusMenuEntry = OverlayEntry(
      builder: (_) => PlusMenuPopup(
        anchor: anchor,
        symbol: scrip.tsym,
        qty: pane.qty,
        price: price,
        onPick: (kind) {
          closeMenu();
          _openPlaceOrderScreen(
            scrip: scrip,
            qty: pane.qty,
            kind: kind,
            price: kind == OrderPrefillKind.blank ? null : price,
          );
        },
        onDismiss: closeMenu,
      ),
    );
```

Add the new callback param:

```dart
        onSetAlert: () {
          closeMenu();
          _handleAlertSetRequested(paneIdx, price);
        },
```

- [ ] **Step 7: Static check**

`flutter analyze lib/screens/web/chart_engine 2>&1 | tail -10`.

---

# Group C — Cancel-alert dialog

### Task C1: `showAlertCancelDialog` helper

**Files:** `lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart`

- [ ] **Step 1: Add import**

```dart
import 'package:mynt_plus/models/alert_pending_model/alert_pending_model.dart';
import 'package:mynt_plus/provider/market_watch_provider.dart';
```

- [ ] **Step 2: Append the helper at the bottom**

```dart
Future<void> showAlertCancelDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AlertPendingModel alert,
}) async {
  final price = alert.pp ?? '';
  final tsym = alert.tsym ?? '';
  return _showIframeSafeDialog<void>(
    context: context,
    child: AlertDialog(
      title: const Text('Cancel alert'),
      content: Text('Cancel alert at $price for $tsym?'),
      actions: [
        Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Keep'),
        )),
        Builder(builder: (ctx) => FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await ref
                .read(marketWatchProvider)
                .fetchCancelAlert(alert.alId ?? '', context);
          },
          child: const Text('Cancel alert'),
        )),
      ],
    ),
  );
}
```

- [ ] **Step 3: Static check**

`flutter analyze lib/screens/web/chart_engine/widgets/overlay_close_dialog.dart`.

---

# Group D — Static gates + smoke

- [ ] `flutter analyze lib/screens/web/chart_engine` → No issues
- [ ] `node --check web/chart-engine/chart.js web/chart-engine/chart-engine.js web/chart-engine/aggregator.js web/chart-engine/theme.js` → no output
- [ ] `node web/chart-engine/aggregator.test.js` → 15 passed

Then spec §7 smoke list.

---

## Notes for the executing engineer

- **`AlertPendingModel` import path**: the explore confirmed alerts exist; if the file lives at a different path than the plan's guess, grep `class AlertPendingModel` and adjust.
- **`fetchSetAlert` signature**: the explore captured `fetchSetAlert(exch, tsym, value, alertTypeVal, context, currentLen, currentLtp, remark)`. If the provider's actual signature has different param names or ordering, match it exactly.
- **`fetchCancelAlert`** signature: `(String alertId, BuildContext context)`. Confirmed.
- **`marketWatchProvider.socketDatas`** — for LTP lookup. Same map used elsewhere in shell.
- **Pause and ask** only if any of the provider methods truly doesn't exist or has wildly different shape.
