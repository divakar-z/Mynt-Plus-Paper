# Chart Engine — Phase 14 Design

**Date:** 2026-05-25
**Builds on:** Phases 1-13
**Scope summary:** Keyboard shortcuts inside the chart iframe: **B / S** quick-place LMT at the hovered price, **I** toggles Instant orders, **1 / 5 / 15 / 60 / D** quick-switch timeframe on the active pane. Ignored when the cursor is over a text input (so qty / order-form typing works normally).

---

## 1. Goal

| Key | Action |
|---|---|
| `B` | Buy LMT at the crosshair's snapped price — same path as `+` menu Buy item (PlaceOrderScreen or instant). |
| `S` | Sell LMT at the crosshair's snapped price. |
| `I` | Toggle `instantOrders` global flag (same flow as Settings → Instant orders, including first-enable warning dialog if not yet acked). |
| `1` | Switch active pane to 1-minute timeframe. |
| `5` | 5-minute timeframe. |
| `1` `5` typed in <500ms | 15-minute (sequence; the `5` alone still works after timeout). |
| `1` `H` | 1-hour (60 min). Or just `H` for 1-hour. For simplicity: `60` typed as digits within 500ms also works. |
| `D` | Daily (1440 min). |
| (existing) `Esc` | Cancel draw mode / drag / popup — already handled. |

For Phase 14 MVP, **simplify timeframe keys** to single-key shortcuts: `1` = 1m, `5` = 5m, `Shift+1` = 15m, `H` = 1h, `D` = 1d. (Sequences are tricky; one key per shortcut keeps the implementation clean.)

Final key map:

| Key | Action |
|---|---|
| `B` / `b` | Buy LMT at hovered price |
| `S` / `s` | Sell LMT at hovered price |
| `I` / `i` | Toggle Instant orders |
| `1` | 1m |
| `5` | 5m |
| `Shift+1` (`!`) | 15m |
| `H` / `h` | 1h |
| `D` / `d` | 1d |
| `Esc` | (already handled — draw / drag / popup cancel) |

---

## 2. Visual + interaction

- Shortcuts fire **only when the cursor is inside the chart pane** (the iframe is focused — `chart-engine.js` already grabs focus on mouseenter).
- Shortcuts are **suppressed when `e.target` is an INPUT or TEXTAREA** (so typing in qty selector / order form works normally).
- No on-screen hint for Phase 14 (a `?` overlay listing shortcuts is Phase 14.1).
- For B / S: the price used is `_snapPrice(yToPrice(this.hover.y))` — same math as the `+` icon.
- If `hover.inside` is false (no current hover), B / S are no-ops.
- For I: the toggle flips immediately; if going OFF→ON for the first time the existing first-enable warning dialog fires (per Phase 6).
- For timeframe keys: applies to the **active pane** (the one with the blue focus border). The user clicked it last; that's the implicit target.

---

## 3. Architecture

### 3.1 chart.js

Add a new `window.keydown` listener (separate from the existing Esc handler for clarity, OR extend the Esc handler — extending is fine):

```js
window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    // ... existing Esc handling ...
    return;
  }
  // Ignore when typing in a form element.
  const t = e.target;
  if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' ||
            t.isContentEditable)) return;
  // Ignore when modifier keys (besides Shift) are held — leave OS shortcuts alone.
  if (e.ctrlKey || e.metaKey || e.altKey) return;

  switch (e.key) {
    case 'b': case 'B':
      this._postQuickPlace('buy');
      break;
    case 's': case 'S':
      this._postQuickPlace('sell');
      break;
    case 'i': case 'I':
      this._postToggleInstant();
      break;
    case '1':
      this._postTimeframe(1);
      break;
    case '5':
      this._postTimeframe(5);
      break;
    case '!':  // Shift+1 on US layout
      this._postTimeframe(15);
      break;
    case 'h': case 'H':
      this._postTimeframe(60);
      break;
    case 'd': case 'D':
      this._postTimeframe(1440);
      break;
  }
});
```

Helpers:

```js
_postQuickPlace(side) {
  if (!this.scrip || !this.hover.inside || this.hover.x == null) return;
  const price = this._snapPrice(this._yToPriceForDrag(this.hover.y));
  if (!Number.isFinite(price) || price <= 0) return;
  try {
    parent.postMessage(JSON.stringify({
      type: side === 'buy' ? 'keyBuyAtPrice' : 'keySellAtPrice',
      value: { paneId: this.paneId, price },
    }), '*');
  } catch (_) {}
}

_postToggleInstant() {
  try {
    parent.postMessage(JSON.stringify({
      type: 'keyToggleInstant',
      value: { paneId: this.paneId },
    }), '*');
  } catch (_) {}
}

_postTimeframe(minutes) {
  try {
    parent.postMessage(JSON.stringify({
      type: 'keyTimeframe',
      value: { paneId: this.paneId, minutes },
    }), '*');
  } catch (_) {}
}
```

### 3.2 Flutter shell

New inbound cases in `_onWindowMessage`:

```dart
case 'keyBuyAtPrice':
case 'keySellAtPrice': {
  final v = msg['value'];
  if (v is Map) {
    final pid = v['paneId'];
    final price = (v['price'] as num?)?.toDouble();
    if (pid is String && price != null) {
      final idx = int.tryParse(pid);
      if (idx != null) {
        final session = ref.read(chartEngineSessionProvider);
        if (idx >= 0 && idx < session.panes.length) {
          final pane = session.panes[idx];
          final scrip = pane.scrip;
          if (scrip != null) {
            _openPlaceOrderScreen(
              scrip: scrip,
              qty: pane.qty,
              kind: msg['type'] == 'keyBuyAtPrice'
                  ? OrderPrefillKind.buyLimit
                  : OrderPrefillKind.sellLimit,
              price: price,
            );
          }
        }
      }
    }
  }
  break;
}
case 'keyToggleInstant': {
  final session = ref.read(chartEngineSessionProvider);
  final notifier = ref.read(chartEngineSessionProvider.notifier);
  final next = !session.instantOrders;
  if (next && !session.instantWarningAck) {
    final ok = await showInstantWarningDialog(context: context);
    if (!ok) return;
    notifier.markInstantWarningAck();
  }
  notifier.setInstantOrders(next);
  break;
}
case 'keyTimeframe': {
  final v = msg['value'];
  if (v is Map) {
    final pid = v['paneId'];
    final minutes = (v['minutes'] as num?)?.toInt();
    if (pid is String && minutes != null) {
      final idx = int.tryParse(pid);
      if (idx != null) {
        ref
            .read(chartEngineSessionProvider.notifier)
            .setPaneTimeframe(idx, minutes);
      }
    }
  }
  break;
}
```

(The `keyToggleInstant` case needs the enclosing `_onWindowMessage` to be `async` — wrap that case body in an inline `Future(() async { ... })` if you want to avoid refactoring the whole switch.)

---

## 4. Edge cases

| Case | Behaviour |
|---|---|
| User typing in qty input | INPUT check suppresses chart shortcuts |
| Cursor outside pane | B / S no-op (no `hover.inside`); timeframe still works because keys fire on the iframe's window |
| Multi-pane: which pane gets the keyboard? | The pane the cursor is over (each pane's chart.js has its own listener; only one is focused) |
| `I` while Instant is OFF and never acked | Warning dialog fires; user can cancel |
| Conflict with browser shortcuts | We early-return on Ctrl/Cmd/Alt to avoid hijacking |
| `5` pressed twice fast | Each fires `setPaneTimeframe(5)` — no-op on the second |
| Pane has no scrip | B / S no-op |
| Esc | Existing handling — unchanged |

---

## 5. Files

| Path | What |
|---|---|
| `web/chart-engine/chart.js` | Extend the existing window-level keydown listener (or add a new one) with B / S / I / 1 / 5 / ! / H / D handling + 3 helper methods. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | 3 new inbound cases in `_onWindowMessage`. |

No bridge encoders. No store changes. No new files.

---

## 6. Acceptance smoke

1. Hover over the chart, press `B` → PlaceOrderScreen opens with BUY LMT at the crosshair's price.
2. Press `S` → opens with SELL LMT.
3. Press `I` → first time pops the warning; click Enable → INSTANT badge appears.
4. Press `I` again → no warning, just toggles back OFF.
5. Click into the qty selector text input, type `5` → typed `5` shows in input; chart's 5m timeframe does NOT switch.
6. Hover chart, press `5` → active pane switches to 5m.
7. Press `1` → 1m. `Shift+1` (`!`) → 15m. `H` → 1h. `D` → 1d.
8. Press `Esc` mid-draw → draw cancels (existing behavior unchanged).

---

## 7. Out of scope (Phase 14.1+)

- Cheat-sheet overlay (`?` to show all shortcuts)
- Customizable bindings
- Numpad keys
- Sequences (e.g., `g s` for "go to settings")
- Layout shortcuts (cols2, grid2x2 etc.)
- Chart navigation (left / right pan, +/- zoom)
- Indicator add via keyboard
- Drawing tool keyboard activation
