# Chart Engine — Phase 15 Design

**Date:** 2026-05-25
**Builds on:** Phases 1-14 (Phase 6 global Instant toggle)
**Scope summary:** Add a per-pane override to the global Instant-orders flag. Each pane can be in one of three states: **Follow global** (default), **Force ON**, or **Force OFF**. The effective instant for a given pane = its override (when set) else the session-level global. Toggle exposed in the per-pane Settings popup as a 3-state radio. Visual hint: a small `INSTANT` chip appears next to the SYMBOL chip on any pane whose effective instant is ON (regardless of source).

---

## 1. Goal

For each pane, surface three choices in the Settings popup:

- **Follow global** (default; effective = session.instantOrders)
- **Always instant** (effective = true; overrides global)
- **Always confirm** (effective = false; overrides global)

The five mutation paths gated on instant in Phases 6 / 9 now use the per-pane effective flag:

- cancel × (order) → effective for the pane that owns the order's overlay
- square-off × (position) → same
- drag-modify release → same
- `+` menu Buy/Sell/SL items → same
- keyboard Alt+B / Alt+S → same

The existing `keyToggleInstant` (Alt+I) toggles the SESSION-LEVEL `instantOrders` flag (not the per-pane override). Per-pane override is mouse-only (Settings popup).

---

## 2. Visual

### 2.1 Settings popup — Instant section

Replace the existing single Switch with a 3-state segmented control:

```
Instant orders for this pane
  ( ) Follow global        [if global is ON, shows "global ON"; else "global OFF"]
  ( ) Always instant
  ( ) Always confirm
⚠ skips confirm dialogs when active
```

(The existing "Instant orders" Switch toggles GLOBAL. The new 3-state control sits BELOW it and labels itself "for this pane".)

### 2.2 Per-pane `INSTANT` badge inside the chart

The Phase 6 top-bar `⚠ INSTANT` badge is global. Add a small in-canvas `⚡` icon next to the SYMBOL · TIMEFRAME chip (top-left of each pane's chart) when THAT pane's effective instant is ON. Visible to make it clear which panes are live-firing.

(Skip if implementation cost is too high for Phase 15; the top-bar badge alone is sufficient for global. The per-pane indicator is the nice-to-have.)

---

## 3. Data model

`PaneState` gains:

```dart
final String? instantOverride; // 'on' | 'off' | null (= follow global)
```

`copyWith` / `toJson` / `fromJson` updated.

Computed effective flag per pane:

```dart
bool effectiveInstantFor(int paneIndex) {
  final p = panes[paneIndex];
  if (p.instantOverride == 'on')  return true;
  if (p.instantOverride == 'off') return false;
  return instantOrders;
}
```

(Method on `ChartEngineSession`.)

Notifier method:

```dart
void setPaneInstantOverride(int index, String? override);
// override ∈ {'on', 'off', null}
```

---

## 4. Architecture

### 4.1 Flutter — branch updates

Every existing `session.instantOrders` check in `chart_engine_shell_screen.dart` gets replaced with `session.effectiveInstantFor(paneIndex)`. Specifically:

- `_handleOverlayCloseRequested` — resolves the pane index from the overlayId's containing pane (need to look up which pane the overlayId belongs to — overlays are pushed per-pane).
- `_handleOverlayDragEnded` — uses `paneIndex` arg.
- `_openPlaceOrderScreen` — `_openPlusMenu`'s caller knows `paneIdx`; pipe it into `_openPlaceOrderScreen`.

Wait — `_handleOverlayCloseRequested` is invoked with `(paneIndex, overlayId)` so the pane index is already known. Likewise for `_handleOverlayDragEnded(paneIndex, ...)`. Easy.

`_openPlaceOrderScreen` currently takes `(scrip, qty, kind, price)` — needs a new `paneIndex` arg threaded through from `_openPlusMenu`'s `onPick` callback so the effective flag can be computed correctly.

### 4.2 Settings popup

Replace the existing Instant Switch row with:
- The existing global Switch (unchanged) — toggles `session.instantOrders`.
- Below it: a 3-radio segmented control bound to `pane.instantOverride` of the **active pane** (`session.activePaneIndex`).
- Sub-text below: warning copy (same as before).

### 4.3 No bridge / JS changes

The override is Flutter-side state. The iframe doesn't need to know — it just shows the global badge (which reflects the session toggle, NOT per-pane override). Per-pane in-canvas badge is optional and rendered only if we wire a `setPaneInstant(paneId, bool)` push.

For Phase 15 MVP, **skip the in-canvas per-pane badge** — the top-bar global badge stays, and the 3-state control in Settings is the source of truth. The user knows which pane is set because they configured it in Settings. Phase 15.1 can add the in-canvas indicator.

---

## 5. Edge cases

| Case | Behaviour |
|---|---|
| Pane has override 'on' but global is OFF | Effective = true for that pane only |
| Pane has override 'off' but global is ON | Effective = false for that pane only |
| User changes global ON via Alt+I | Panes with override stay overridden; others follow |
| Layout change | New panes default `instantOverride = null` (follow global) |
| Override persists across reload | Yes (part of PaneState.toJson/fromJson) |

---

## 6. Files

| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | `PaneState.instantOverride` field + JSON; `ChartEngineSession.effectiveInstantFor(int)`; notifier `setPaneInstantOverride(index, override)`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | Five existing instant branches switch from `session.instantOrders` to `session.effectiveInstantFor(paneIdx)`. `_openPlaceOrderScreen` gains `paneIndex` arg threaded from `_openPlusMenu`. `keyToggleInstant` continues to toggle GLOBAL. |
| `lib/screens/web/chart_engine/widgets/chart_engine_top_bar.dart` | Settings popup adds the 3-state radio block below the existing Instant Switch. |

No bridge changes. No JS changes.

---

## 7. Acceptance smoke

1. Open `/charts` with default layout. Settings → toggle global Instant ON → badge appears, all panes fire instant.
2. Open Settings on a pane. New `For this pane` row shows three radio options. Pick `Always confirm` → that pane now confirms even with global ON. Click `+` Buy → PlaceOrderScreen opens (not instant).
3. Pick `Follow global` → reverts to global behaviour.
4. Pick `Always instant` while global is OFF → that pane fires instant; others still confirm.
5. Reload tab → per-pane override persists.
6. `cols2` layout, configure each pane independently → each follows its own override.
7. Alt+I toggles global (unchanged behaviour).

---

## 8. Out of scope

- In-canvas per-pane instant indicator (the small `⚡` chip)
- Override for keyboard Alt+I (it only toggles global)
- Override for ticker bar / order book (chart-engine only)
- "Confirm only large qty" hybrid
