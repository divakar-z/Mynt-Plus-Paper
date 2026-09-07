# Chart Engine — Phase 4 Design

**Date:** 2026-05-22
**Builds on:** Phase 3 (per-pane read-only overlays + popup + close dialog)
**Scope summary:** Make each chart pane an interactive trading surface — bid/ask/qty header strip, hover `+` icon in the right gutter, action menu, qty selector, all order-placement entry points opening the existing `PlaceOrderScreenWeb` widget pre-filled.

---

## 1. Goal

For each pane with a scrip:

1. Render a 3rd header row showing `[bid] [spread] [qty] [ask]`. Bid/ask come from existing LTP packets (`bp1`/`sp1`); qty is per-pane store state (default = `scrip.ls`).
2. Clicking the **bid chip** opens `PlaceOrderScreenWeb` pre-filled with Sell LMT at the bid price + current qty. Clicking the **ask chip** opens it pre-filled with Buy LMT at the ask price + current qty. (Future "instant orders" mode will skip the screen and fire MARKET orders directly — see `[[project-chart-instant-orders]]`.)
3. Clicking the **qty chip** opens a qty selector popup with text input, ±lotsize buttons, and multiplier presets (1×, 5×, 25×, 100×, 500×, 1000×). All edits round to a multiple of `scrip.ls`.
4. Hovering inside the plot shows a `+` icon at the crosshair y in the right gutter. Clicking it opens an action menu at the click coords:
   - Buy `qty` `tsym` @ `price` limit
   - Sell `qty` `tsym` @ `price` stop
   - Sell `qty` `tsym` @ `price` stop, `price - ti` limit
   - ────
   - Create new order …

Each menu item opens `PlaceOrderScreenWeb` pre-filled with the corresponding side/prctype/price.

5. All entry points reuse `PlaceOrderScreenWeb` (via `ResponsiveNavigation.toPlaceOrderScreen(...)`) with `fromChart: true`. The screen is the confirm — no custom Phase 4 confirm dialogs for placing.

---

## 2. Visual specification

### 2.1 Header — row 3 (NEW)

Stacked directly below the OHLC line (`O H L C V`), starting at y ≈ 46:

```
[ 243.20 ]   0.65   [ 260 ]   [ 243.85 ]
   bid     spread    qty         ask
```

| Chip | Style |
|---|---|
| Bid | Filled rect, `palette.bear` (red) bg, white text, weight 700, padding 6×4, 12px font, rounded 3px |
| Spread | Plain text, `palette.axisText`, weight 500, 11px, no chip |
| Qty | Hairline-bordered rect, transparent bg, `palette.axisTextStrong` text, weight 600, 12px, rounded 3px |
| Ask | Filled rect, `palette.bull` (blue/green — TradingView uses blue but the existing palette uses `bull`=green; align Phase 4 to **TradingView convention** by adding a new `palette.long` = blue and `palette.short` = red to `theme.js`) |

**Palette additions** (must land before any rendering):
- `dark.long = '#3B82F6'`, `dark.short = '#EF4444'`
- `light.long = '#2563EB'`, `light.short = '#DC2626'`

Bid/ask chips and position-line overlays both use `long`/`short` so a long position line, the ask chip, and the Buy LMT line are all visually unified blue; short position, bid chip, Sell LMT all unified red. This supersedes the Phase 3 inline `#3B82F6`/`#EF4444` literals in `_overlayLineColor` and `_overlayLabelAccent` — refactor to read from the palette.

Spread is computed as `ask - bid` formatted to `_priceDecimals()`. Hidden when bid or ask is null.

### 2.2 `+` icon in the right gutter

While the crosshair is inside the plot, draw a 16×16 square chip in the right gutter at the cursor's y:

- Position: `x = plot.right + 8`, `y = hoverY - 8`
- Style: hairline border in `palette.axisText`, no fill, centered `+` glyph in `palette.axisTextStrong`
- Hidden while: a button is being dragged (`_dragMode != null`), the overlay hit-test already returned a hit, or no `scrip` is set
- Hit-test: 16×16 box; cursor → `pointer` on hover
- Click → post `plusClicked` to parent with `{paneId, price, clientX, clientY}` where `price = yToPrice(hoverY)`

### 2.3 Qty selector popup

Flutter `OverlayEntry` anchored to the bottom-left of the qty chip in iframe→app coordinates:

```
┌──────────────────────────────┐
│ Quantity                     │
│ ┌──────────────────────────┐ │
│ │ 260                  ⌫   │ │  <- TextField, autofocus
│ └──────────────────────────┘ │
│ ┌────┐  ┌────┐               │
│ │ −  │  │ +  │               │  <- step ±ls
│ └────┘  └────┘               │
│ ┌────┐ ┌────┐ ┌────┐         │
│ │ 1× │ │ 5× │ │25× │         │
│ ├────┼─┼────┼─┼────┤         │
│ │100×│ │500×│ │ 1k×│         │
│ └────┘ └────┘ └────┘         │
│ ┌──────────┐  ┌──────────┐   │
│ │ Reset    │  │ Last     │   │
│ └──────────┘  └──────────┘   │
└──────────────────────────────┘
```

- Text field: integer-only, validates on blur; on commit, value = `max(ls, round(input / ls) * ls)`.
- `−` / `+` step by `ls` (clamped to min `ls`).
- Multiplier chips: each sets qty to `n × ls`.
- `Reset` → `scrip.ls`; `Last` → most recently committed qty for this scrip (per-scrip in-memory map, not persisted).
- Dismiss: outside click, `Esc`, or `Enter` (which commits).

### 2.4 `+` action menu

Flutter `OverlayEntry` anchored at click coords (Material card, ~340px wide):

```
┌──────────────────────────────────────────────────────────────┐
│ ▲  Buy 260 NIFTY26MAY26C23600 @ 223.15 limit                 │
│ ▼  Sell 260 NIFTY26MAY26C23600 @ 223.15 stop                 │
│ ▼  Sell 260 NIFTY26MAY26C23600 @ 223.15 stop, 223.10 limit   │
│ ──────────────────────────────────────────────────────────── │
│ ⨁  Create new order …                                        │
└──────────────────────────────────────────────────────────────┘
```

- Icons (▲ = blue/long upward triangle, ▼ = red/short downward triangle, ⨁ = neutral) for quick scan.
- Each item, when tapped, dismisses the menu and opens `PlaceOrderScreenWeb` via `ResponsiveNavigation.toPlaceOrderScreen` with `fromChart: true` and pre-fill mapping per §3.3.
- "Create new order" pre-fills only symbol/exchange/qty (no side, no price, no prctype) so the user starts from a blank-ish form.
- Outside click dismisses without action.

---

## 3. Data model

### 3.1 PaneState — new field

```dart
class PaneState {
  final ChartScrip? scrip;
  final int timeframeMinutes;
  final ChartOverlays overlays;
  final int qty;                  // NEW — default = scrip?.ls ?? 1
  // copyWith / toJson / fromJson updated accordingly
}
```

- On `setPaneSymbol(index, scrip)`: qty is reset to `scrip.ls` (NOT carried over from the prior symbol — a NIFTY ls of 75 doesn't make sense for RELIANCE-EQ which has ls=1).
- On `fromJson`: if qty is missing/zero, default to `scrip?.ls ?? 1`.

### 3.2 Bridge messages

**Outbound (Flutter → iframe):**

```dart
String encodeSetPaneQty(String paneId, int qty); // {type:'setPaneQty', value:{paneId, qty}}
```

Pushed in `_pushSession` per-pane with a new `_pushedQty: Map<int, int>` diff cache (same pattern as the other per-pane caches).

**Inbound (iframe → Flutter):**

```js
{ type: 'qtyChipClicked', value: { paneId, clientX, clientY } }
{ type: 'plusClicked',    value: { paneId, price, clientX, clientY } }
```

### 3.3 PlaceOrderScreen pre-fill mapping

Each chart entry point constructs `OrderScreenArgs` then calls `ResponsiveNavigation.toPlaceOrderScreen(context, arguments)` with `fromChart: true`.

| Entry point | side | prctyp | price | qty |
|---|---|---|---|---|
| Bid chip click | SELL | LMT | `bid` | pane qty |
| Ask chip click | BUY | LMT | `ask` | pane qty |
| `+` Buy LMT | BUY | LMT | clicked price | pane qty |
| `+` Sell SL-MKT | SELL | SL-MKT | clicked price (as trgprc) | pane qty |
| `+` Sell SL-LMT | SELL | SL-LMT | clicked price (as trgprc) + `clicked - ti` (as prc) | pane qty |
| `+` Create new order | (none) | (default) | (none) | pane qty |

`scrip.ts`, `scrip.exch`, `scrip.token`, `scrip.tsym` map to `tSym`, `exchange`, `token`, `tSym` on `OrderScreenArgs`. `transType = (side == 'BUY')`. `ltp` = price. `raw['prctyp']`, `raw['qty']`, `raw['prc']` carry the pre-fill values per the existing widget's prefill convention.

---

## 4. Architecture

### 4.1 Bid/ask flow

- `chart.js` `ingestTick(packet)`: alongside `lp/v/ft`, parse `bp1` → `tickState.bid`, `sp1` → `tickState.ask`. Always update (no aggregation — bid/ask reflect the most recent snapshot only).
- `draw()` reads `tickState.bid` / `tickState.ask` for the header row 3.
- No store changes — bid/ask are transient, not persisted, not cross-pushed.

### 4.2 Qty state

- `ChartEngineSessionNotifier.setPaneQty(int index, int qty)` — clamps to multiple of `scrip.ls`, schedules persist.
- Symbol change resets qty (within `setPaneSymbol`).
- Shell `_pushSession` pushes `setPaneQty` per-pane via `_pushedQty` diff cache.
- Chart-engine.js `case 'setPaneQty'` → `chart.setQty(qty)` → updates `this.qty`, calls `scheduleRedraw()`.

### 4.3 Header row 3 rendering

New `_drawBidAskQtyStrip(plot)` method in `chart.js`, called from `_drawOhlc` after the OHLC line. Computes chip rects, draws each, registers hit-test entries:

- Bid chip hit → post `bidClicked` with `{paneId, price: bid, clientX, clientY}`.
- Ask chip hit → post `askClicked` with `{paneId, price: ask, clientX, clientY}`.
- Qty chip hit → post `qtyChipClicked`.

(Same hit-test pattern as Phase 3 overlay hits; extended array.)

### 4.4 `+` icon rendering

In `draw()`, after the existing crosshair block (which draws the right-gutter price chip on hover), add:

```js
if (this.hover.inside && this.hover.x != null && this.scrip && !this._dragMode) {
  this._drawPlusIcon(plot, this.hover.y); // 16×16 in the right gutter
}
```

Hit-test registers a `plusClicked` entry at the same rect.

### 4.5 Flutter popup plumbing

Three new popups, all `PointerInterceptor`-wrapped `OverlayEntry`s anchored at iframe-relative coords (same coord-translation helper as Phase 3's detail popup):

- `QtySelectorPopup` (`widgets/qty_selector_popup.dart`) — opened from `qtyChipClicked`.
- `PlusMenuPopup` (`widgets/plus_menu_popup.dart`) — opened from `plusClicked`. Each menu item closes the popup, then calls `_openPlaceOrderScreen(...)` (helper) with the right pre-fill.
- (Bid/ask chips don't need their own popup; they directly call `_openPlaceOrderScreen(...)`.)

`_openPlaceOrderScreen(...)` is a private helper on the shell screen state that constructs `OrderScreenArgs` per §3.3 and calls `ResponsiveNavigation.toPlaceOrderScreen(context: context, arguments: {...})`.

---

## 5. Edge cases

| Case | Behaviour |
|---|---|
| Pane has no scrip | Header row 3 skipped; `+` icon never appears; qty chip absent |
| Bid or ask null (no tick yet) | Hide that chip; show "—" placeholder so the layout doesn't jump |
| Spread negative (cross book) | Display in red |
| `scrip.ls` is 0 (bad data) | Fallback to `ls = 1` for all qty math |
| User types non-integer in qty input | Reject keystroke; preserve last valid |
| User types qty below ls | On commit, clamp to `ls` |
| Symbol change while qty popup open | Popup auto-dismisses (listens on `chartEngineSessionProvider`) |
| Layout change while `+` menu open | Popup auto-dismisses (same listener) |
| User opens `+` menu, then resizes pane via splitter | Popup stays at its absolute coords; user can re-click |
| PlaceOrderScreen opens, user closes it without placing | No-op; chart returns to its previous state |
| Click on bid/ask chip while iframe is being dragged | Ignored (drag wins, matches Phase 3 behaviour) |
| Two panes show same symbol | Both render their own bid/ask/qty independently; both can open the same PlaceOrderScreen separately |
| Theme switch | Palette `long`/`short` constants change → next redraw shows new colours |

---

## 6. Files to create / modify

### Created (Flutter)
| Path | Responsibility |
|---|---|
| `lib/screens/web/chart_engine/widgets/qty_selector_popup.dart` | Qty input popup with ±, multipliers, reset/last. |
| `lib/screens/web/chart_engine/widgets/plus_menu_popup.dart` | `+` action menu — 4 items, each opens PlaceOrderScreen with pre-fill. |
| `lib/screens/web/chart_engine/state/place_order_prefill.dart` | Pure function `buildOrderScreenArgs(scrip, side, prctype, prc, trgprc, qty)` → `Map` payload for `ResponsiveNavigation.toPlaceOrderScreen`. Unit-testable. |

### Modified (Flutter)
| Path | What changes |
|---|---|
| `lib/screens/web/chart_engine/state/chart_engine_store.dart` | `PaneState.qty` field + copyWith/toJson/fromJson; `setPaneQty(index, qty)` setter on the notifier; symbol-set resets qty to `scrip.ls`. |
| `lib/screens/web/chart_engine/utils/chart_engine_bridge.dart` | `encodeSetPaneQty(paneId, qty)`. |
| `lib/screens/web/chart_engine/chart_engine_shell_screen.dart` | `_pushedQty` diff cache; push in `_pushSession`; new inbound handlers for `bidClicked`/`askClicked`/`qtyChipClicked`/`plusClicked`; `_openPlaceOrderScreen` helper; popup OverlayEntry plumbing. |

### Modified (JS — `web/chart-engine/`)
| Path | What changes |
|---|---|
| `theme.js` | `long`/`short` palette colour constants in both themes. |
| `chart.js` | `this.qty`, `this.tickState.bid/ask`; `setQty(qty)`; parse `bp1`/`sp1` in `ingestTick`; `_drawBidAskQtyStrip(plot)`; `_drawPlusIcon(plot, hoverY)`; extend hit-test for the new clickable zones; refactor `_overlayLineColor` to read from `palette.long`/`palette.short`. |
| `chart-engine.js` | `case 'setPaneQty'` handler. |

No new dependencies. No test changes (visual-only; manual smoke per §7).

---

## 7. Acceptance smoke

1. Open `/charts` on a symbol with active market. After the first tick, header row 3 shows `[bid]  spread  [qty]  [ask]`, qty = lot size.
2. Click the **ask chip** → `PlaceOrderScreenWeb` opens pre-filled: BUY, LMT, price = ask, qty = pane qty, symbol = pane scrip. Close it → chart unchanged.
3. Click the **bid chip** → same, but SELL.
4. Click the **qty chip** → popup appears under the chip. Type `750`, press Enter → chip now shows `750` (rounded to nearest multiple of `ls`). Reload tab → qty persists.
5. Click the same chip → popup → tap `5×` → chip now shows `5 × ls`. Tap `Reset` → chip back to `ls`.
6. Hover anywhere in the plot → `+` icon appears in the right gutter at the cursor y. Move cursor → `+` follows.
7. Click `+` → action menu opens with 4 items, each correctly showing `qty SYMBOL @ PRICE …`. Click "Buy … limit" → `PlaceOrderScreenWeb` opens with BUY/LMT/price/qty pre-filled.
8. Click `+` → "Sell … stop, … limit" → `PlaceOrderScreenWeb` opens with SELL/SL-LMT/trgprc=price/prc=price-ti.
9. Click `+` → "Create new order" → `PlaceOrderScreenWeb` opens with symbol+qty pre-filled, but no side/price defaults.
10. In a `cols2` layout, point both panes at the same symbol; both header rows show the same bid/ask updating live; each pane's qty is independent (change qty in pane 0 → pane 1 unaffected).
11. Theme switch → bid red, ask blue (long colour), qty chip text colours update.
12. Resize a pane via splitter → header row 3 stays anchored at the top-left, chips re-rendered correctly.
13. Place an order from the chart → after fill, the position overlay (Phase 3) appears on the chart at the avg price, in matching blue/red.

If everything passes, Phase 4 is done.

---

## 8. Out of scope (Phase 5+)

- Per-pane "instant orders" toggle — design intent saved in `[[project-chart-instant-orders]]`; will skip PlaceOrderScreen for closes/cancels.
- Drag a position/order overlay line to reprice/modify (drag-to-modify).
- Keyboard shortcuts (B/S to fire LMT at hover price etc.).
- Drawing tools (horizontal lines / trendlines / fib / etc.).
- Per-pane independent bid/ask depth (multi-level ladder).
- Hover preview of P&L if order fills at the hovered price.
- Right-click on chart for quick actions.
