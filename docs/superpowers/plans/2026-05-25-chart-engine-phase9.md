# Chart Engine — Phase 9 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Inline `TP` and `SL` buttons inside the position chip. Click → opens `PlaceOrderScreenWeb` pre-filled with opposite-side LMT (TP at avg ± 1%) or SL-MKT (Stop at avg ∓ 0.5%). In Instant mode (Phase 6 toggle ON), fires the order directly without the screen.

**Architecture:** Iframe-side chart.js extends `_drawOverlays`' position branch to draw two TP/SL buttons inside the chip; mousedown intercept routes `tp`/`sl` actions to NEW outbound messages `positionTpRequested` / `positionSlRequested`. Flutter shell handlers branch on `session.instantOrders` between opening `PlaceOrderScreenWeb` (default) and firing `orderProvider.fetchPlaceOrder` directly (instant). Prefill values come from new `buildTpSlOrderScreenArgs` / `buildTpSlPlaceOrderInput` helpers in `place_order_prefill.dart`.

**Tech Stack:** Flutter (Riverpod 3) + vanilla JS + Canvas 2D. No `chart-engine.js` changes.

## Project conventions

- **No git commits.**
- **Static gates after every edit:** `flutter analyze lib/screens/web/chart_engine` (Dart) + `node --check web/chart-engine/chart.js` (JS — only this one file changes).
- **Spec reference:** `docs/superpowers/specs/2026-05-25-chart-engine-phase9-design.md`.
- **Reuse:** `_overlayHits` hit-test pattern; existing `_handleOverlayCloseRequested` for position-resolution template; `buildPlaceOrderInput` / `buildOrderScreenArgs` constructor patterns; instant-vs-confirm branch pattern from Phase 6 `_openPlaceOrderScreen`.

## File map

### Modified (Flutter)
| Path | What |
|---|---|
| `lib/screens/web/chart_engine/state/place_order_prefill.dart` | Add default % constants; add `buildTpSlOrderScreenArgs(...)` + `buildTpSlPlaceOrderInput(...)` helpers. Don't extend `OrderPrefillKind` — the new helpers stand alone since the price math depends on `isLong`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | New `case 'positionTpRequested'` + `'positionSlRequested'` in `_onWindowMessage`; new method `_handlePositionTpSlRequested(int paneIndex, String overlayId, bool isTp)`. |

### Modified (JS)
| Path | What |
|---|---|
| `web/chart-engine/chart.js` | `_drawOverlays` position branch: reserve width for TP+SL buttons, draw them with text + border, register hit rects with `action: 'tp'` / `action: 'sl'`. Mousedown intercept: handle `tp`/`sl` actions with new outbound message types. |

No new files. No `chart-engine.js` changes.

## Task ordering

1. **Group A — Prefill helpers.**
2. **Group B — Chart.js render + click.**
3. **Group C — Shell handlers.**
4. **Group D — Static gates.**

---

# Group A — Prefill helpers

### Task A1: Add default percentages + two TP/SL helpers

**Files:** `lib/screens/web/chart_engine/state/place_order_prefill.dart`

Append at the bottom (after `buildPlaceOrderInput`):

```dart
// Default percentage offsets from position avg for the chart's quick
// TP / SL buttons. Hardcoded for Phase 9; configurable in a later phase.
const double _defaultTpPct = 0.01;   // 1% — favourable side
const double _defaultSlPct = 0.005;  // 0.5% — protective side

double tpPriceFromAvg({required double avg, required bool isLong}) =>
    isLong ? avg * (1 + _defaultTpPct) : avg * (1 - _defaultTpPct);

double slTriggerFromAvg({required double avg, required bool isLong}) =>
    isLong ? avg * (1 - _defaultSlPct) : avg * (1 + _defaultSlPct);

/// Builds the `arguments` map for opening `PlaceOrderScreenWeb` pre-filled
/// to add a TP (`isTp == true`) or SL (`isTp == false`) for an existing
/// position. Side is automatically opposite of the position.
Map<String, dynamic> buildTpSlOrderScreenArgs({
  required ChartScrip scrip,
  required int qty,
  required bool isLong,
  required bool isTp,
  required double avg,
  ScripInfoModel? realScripInfo,
}) {
  final price = isTp
      ? tpPriceFromAvg(avg: avg, isLong: isLong)
      : slTriggerFromAvg(avg: avg, isLong: isLong);
  final kind = isTp
      ? (isLong ? OrderPrefillKind.sellLimit : OrderPrefillKind.buyLimit)
      : (isLong ? OrderPrefillKind.sellStopMkt : OrderPrefillKind.buyStopMkt);
  return buildOrderScreenArgs(
    scrip: scrip,
    qty: qty,
    kind: kind,
    price: price,
    realScripInfo: realScripInfo,
  );
}

/// Builds a typed `PlaceOrderInput` for instant-mode TP/SL placement.
PlaceOrderInput buildTpSlPlaceOrderInput({
  required ChartScrip scrip,
  required int qty,
  required bool isLong,
  required bool isTp,
  required double avg,
  required Map<String, dynamic> deviceInfo,
}) {
  final price = isTp
      ? tpPriceFromAvg(avg: avg, isLong: isLong)
      : slTriggerFromAvg(avg: avg, isLong: isLong);
  final kind = isTp
      ? (isLong ? OrderPrefillKind.sellLimit : OrderPrefillKind.buyLimit)
      : (isLong ? OrderPrefillKind.sellStopMkt : OrderPrefillKind.buyStopMkt);
  return buildPlaceOrderInput(
    scrip: scrip,
    qty: qty,
    kind: kind,
    price: price,
    deviceInfo: deviceInfo,
  );
}
```

Static check: `flutter analyze lib/screens/web/chart_engine/state/place_order_prefill.dart 2>&1 | tail -5`.

---

# Group B — chart.js render + click

### Task B1: Reserve chip width + draw TP/SL buttons inside position chip

**Files:** `web/chart-engine/chart.js`

Locate the position-branch inside `_drawOverlays` (the per-overlay loop). It currently composes `labelText` from qty + (type) + pnl segments, then computes `labelW` + `chipW` + draws the chip body + label text + close × box. Phase 9 inserts two button rects between the label area and the close box.

- [ ] **Step 1: Reserve width for TP+SL buttons (positions only)**

Find:

```javascript
      const labelText = segs.join('   ');
      const labelW = ctx.measureText(labelText).width;
      const chipW = labelW + chipPad * 2 + closeBoxW;
```

Replace with:

```javascript
      const labelText = segs.join('   ');
      const labelW = ctx.measureText(labelText).width;
      const isPosition = ov.kind === 'position';
      // TP/SL buttons live inline before the close × for positions only.
      const tpslBtnW = 22;     // each button — 22px wide
      const tpslGap = 4;       // gap between buttons
      const tpslBlockW = isPosition
          ? (tpslBtnW * 2 + tpslGap + 6)   // 6 = pre-buttons gap from label
          : 0;
      const chipW = labelW + chipPad * 2 + tpslBlockW + closeBoxW;
```

- [ ] **Step 2: Draw the two buttons**

Find the existing close-box drawing block (with `xBoxLeft` / `xCenterX`). Insert BEFORE it:

```javascript
      // TP / SL buttons (positions only) — small bordered text pills.
      let tpRect = null, slRect = null;
      if (isPosition) {
        const btnY = chipTop;
        const btnH = chipH;
        const tpX = chipLeft + chipPad + labelW + 6;
        const slX = tpX + tpslBtnW + tpslGap;
        ctx.font = '700 9px Geist, sans-serif';
        ctx.textBaseline = 'middle';
        ctx.textAlign = 'center';
        for (const [bx, label, rectOut] of [
          [tpX, 'TP', 'tp'], [slX, 'SL', 'sl'],
        ]) {
          ctx.strokeStyle = '#FFFFFF';
          ctx.lineWidth = 1;
          this._roundedRect(bx, btnY + 2, tpslBtnW, btnH - 4, 3);
          ctx.stroke();
          ctx.fillStyle = '#FFFFFF';
          ctx.fillText(label, bx + tpslBtnW / 2, chipY);
          const rect = { x: bx, y: btnY, w: tpslBtnW, h: btnH };
          if (rectOut === 'tp') tpRect = rect; else slRect = rect;
        }
        // Restore the chip-text font that the rest of the loop expects.
        ctx.font = '700 11px Geist, sans-serif';
      }
```

- [ ] **Step 3: Update close-box x to account for TP/SL block**

Find:

```javascript
      const xBoxLeft = chipLeft + chipW - closeBoxW;
```

This formula still works because `chipW` was bumped in step 1 to include `tpslBlockW`. Verify by reading the surrounding code — the close × is positioned RELATIVE TO `chipLeft + chipW`, so adding to `chipW` automatically shifts × right. No change needed in this step.

- [ ] **Step 4: Register hit rects for TP/SL**

Find the existing two `this._overlayHits.push({ ... action: 'open' / 'close' ... })` blocks. Add directly above the line-hit-test block:

```javascript
      if (isPosition) {
        if (tpRect) this._overlayHits.push({
          rect: tpRect, action: 'tp', overlayId: ov.id,
        });
        if (slRect) this._overlayHits.push({
          rect: slRect, action: 'sl', overlayId: ov.id,
        });
      }
```

Also expand the `open` hit-rect's width: the existing rect uses `chipW - closeBoxW`. Now that we've inserted TP/SL inside, the "label body click" area should NOT cover them. Replace:

```javascript
      this._overlayHits.push({
        rect: { x: chipLeft, y: chipTop, w: chipW - closeBoxW, h: chipH },
        action: 'open', overlayId: ov.id,
      });
```

with:

```javascript
      // `open` body covers everything LEFT of the TP button (for positions)
      // or everything LEFT of the close box (for orders).
      final
      const openBodyW = isPosition
          ? Math.max(0, (tpRect ? tpRect.x : chipLeft + chipW) - chipLeft)
          : chipW - closeBoxW;
      this._overlayHits.push({
        rect: { x: chipLeft, y: chipTop, w: openBodyW, h: chipH },
        action: 'open', overlayId: ov.id,
      });
```

Drop the `final` keyword — that's Dart, not JS. The intent is `const openBodyW`. The leading `final` line is a typo to delete; the `const openBodyW` line stays.

- [ ] **Step 5: Mousedown intercept — route `tp` / `sl` actions**

Find the existing mousedown intercept block that branches on `hit.kind === 'overlay'` and `hit.action`. The current `else if (hit.action !== 'close')` path produces an `overlayClicked` message. Restructure to a switch (or extra `if`s):

Find:

```javascript
          if (hit.action === 'close') {
            msg = {
              type: 'overlayCloseRequested',
              ...
            };
          } else {
            // 'open' hit — could be a click (→ detail popup) OR the start of
            // a drag-to-modify on an order line.
            const ov = this._overlays.find((o) => o.id === hit.overlayId);
            const isDraggable = ...
            ...
          }
```

Insert a branch for `tp` / `sl` BEFORE the `if (hit.action === 'close')`:

```javascript
          if (hit.action === 'tp' || hit.action === 'sl') {
            msg = {
              type: hit.action === 'tp'
                  ? 'positionTpRequested'
                  : 'positionSlRequested',
              value: {
                paneId: this.paneId,
                overlayId: hit.overlayId,
                clientX: e.clientX,
                clientY: e.clientY,
              },
            };
          } else if (hit.action === 'close') {
            // ... existing close-requested branch ...
          } else {
            // ... existing open / drag branch ...
          }
```

- [ ] **Step 6: Static check**

`node --check web/chart-engine/chart.js`
Expected: no output.

---

# Group C — Shell handlers

### Task C1: Add inbound cases + `_handlePositionTpSlRequested`

**Files:** `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`

- [ ] **Step 1: Add cases to `_onWindowMessage`**

Alongside the existing `overlayClicked` / `overlayCloseRequested` cases:

```dart
      case 'positionTpRequested':
      case 'positionSlRequested': {
        final v = msg['value'];
        if (v is Map) {
          final pid = v['paneId'];
          final ovId = v['overlayId'];
          if (pid is String && ovId is String) {
            final idx = int.tryParse(pid);
            if (idx != null) {
              _handlePositionTpSlRequested(
                  idx, ovId, msg['type'] == 'positionTpRequested');
            }
          }
        }
        break;
      }
```

- [ ] **Step 2: Add `_handlePositionTpSlRequested` method**

Near the existing `_handleOverlayCloseRequested`:

```dart
void _handlePositionTpSlRequested(
    int paneIndex, String overlayId, bool isTp) async {
  final session = ref.read(chartEngineSessionProvider);
  if (paneIndex < 0 || paneIndex >= session.panes.length) return;
  final scrip = session.panes[paneIndex].scrip;
  if (scrip == null) return;
  if (!overlayId.startsWith('pos-')) return;

  // Resolve position from the providers (mirrors _handleOverlayCloseRequested
  // for positions).
  final positions =
      ref.read(portfolioProvider).postionBookModel ?? const [];
  PositionBookModel? position;
  for (final p in positions) {
    if (p.exch == scrip.exch && p.token == scrip.token &&
        (int.tryParse(p.netqty ?? '0') ?? 0) != 0) {
      position = p;
      break;
    }
  }
  if (position == null) return;

  final qtyInt = int.tryParse(position.netqty ?? '0') ?? 0;
  if (qtyInt == 0) return;
  final isLong = qtyInt > 0;
  final qtyAbs = qtyInt.abs();
  final avg = double.tryParse(position.netavgprc ?? '') ?? 0;
  if (avg <= 0) return;

  if (session.instantOrders) {
    // Instant: fire the order directly.
    final deviceInfo = ref.read(authProvider).deviceInfo;
    final input = buildTpSlPlaceOrderInput(
      scrip: scrip,
      qty: qtyAbs,
      isLong: isLong,
      isTp: isTp,
      avg: avg,
      deviceInfo: deviceInfo,
    );
    await ref.read(orderProvider).fetchPlaceOrder(context, input, false);
    return;
  }

  // Confirm-mode: open PlaceOrderScreenWeb. Prefer the cached real
  // ScripInfoModel if we have it (same pattern as _openPlaceOrderScreen).
  var realInfo = _cachedScripInfo(scrip);
  if (realInfo == null) {
    try {
      await ref
          .read(marketWatchProvider)
          .fetchScripInfo(scrip.token, scrip.exch, context, false);
    } catch (_) {}
    if (!mounted) return;
    realInfo = _cachedScripInfo(scrip) ??
        ref.read(marketWatchProvider).scripInfoModel;
  }
  final args = buildTpSlOrderScreenArgs(
    scrip: scrip,
    qty: qtyAbs,
    isLong: isLong,
    isTp: isTp,
    avg: avg,
    realScripInfo: realInfo,
  );
  await ResponsiveNavigation.toPlaceOrderScreen(
      context: context, arguments: args);
}
```

- [ ] **Step 3: Static check**

`flutter analyze lib/screens/web/chart_engine 2>&1 | tail -10`
Expected: `No issues found!`

---

# Group D — Static gates + smoke

### Task D1: Final gates

- [ ] `flutter analyze lib/screens/web/chart_engine` → No issues
- [ ] `node --check web/chart-engine/chart.js web/chart-engine/chart-engine.js web/chart-engine/aggregator.js web/chart-engine/theme.js` → no output
- [ ] `node web/chart-engine/aggregator.test.js` → 15 passed

### Task D2: Manual smoke

Spec §7's 10-step list.

---

## Notes

- **No `chart-engine.js` changes** — the new outbound messages are sent FROM chart.js directly to Flutter; chart-engine.js doesn't relay them.
- **Position resolution from overlayId** copies the exact pattern from `_handleOverlayCloseRequested`'s position arm.
- **`buildTpSlPlaceOrderInput` uses `qtyAbs`** (positive integer) because place-order qty is always positive; side is determined by `isLong` via the prefill kind.
- The chip's `chipLeft` (Phase 9 keeps the Phase 8 anchor of `plot.left + max(16, plot.width * 0.25)`) still gives the chip plenty of room for the extended layout.
- **Pause and ask** only if `PositionBookModel.netavgprc` is named differently or `OrderProvider.fetchPlaceOrder`'s signature differs.
