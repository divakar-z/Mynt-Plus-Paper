# Chart Engine — Phase 3 Design

**Date:** 2026-05-22
**Builds on:** Phase 2 (multi-pane layouts with per-pane independent state, click-to-focus, persistent layout)
**Scope summary:** Per-pane read-only overlays for open positions, pending LIMIT orders, and SL trigger orders, plus a single mutating action — `×` close button that cancels an order or squares off a position behind a confirm dialog.

---

## 1. Goal

For each pane, render horizontal lines for the entries the user has live with that pane's scrip:

- **Open position** — solid line at `netavgprc`, label with `signed qty` + live P&L + `×` close.
- **Pending LIMIT order** — dashed line at `prc`, label with `signed qty` + `×` cancel.
- **SL trigger (SL-M / SL-L)** — dotted line at `trgprc`, label with `signed qty` + `×` cancel; SL-L additionally draws a second dashed line at `prc` for the limit cap.

Clicking on a line (outside the label) highlights it and opens a Flutter popup with full details. Clicking `×` opens a confirm dialog and, on confirm, calls the existing cancel/square-off API.

---

## 2. Visual specification

### 2.1 Line styles

| Kind | Stroke | Dash | Color rule |
|---|---|---|---|
| Position avg | 1.5px | solid | `qty > 0` → blue `#3B82F6`, `qty < 0` → red `#EF4444` |
| LIMIT order | 1px | `[6, 4]` | BUY → blue, SELL → red |
| SL trigger | 1px | `[2, 3]` | always red `#EF4444` with amber `#F59E0B` accent on the label border |
| SL-L limit cap | 1px | `[4, 4]` | same colour as the SL trigger (paired) |

Line spans `plot.left` → `plot.right` (the candle plot area; **not** the right price gutter).

### 2.2 Price marker

A small filled dot (3px radius) on each line at the x-coordinate of the rightmost candle's centre, in the line's colour. Conveys "the price the line represents" without needing text on the line.

### 2.3 Inline label chip

Anchored to the right of the dot, sliding leftward if it would clip past `plot.right`. Pill shape with rounded corners.

Segments:
- **Position:** `[ 20  +₹220  × ]` — signed qty, P&L (₹ with sign and 0 dp under 1k, abbreviated above), close.
- **Order:** `[ -10  × ]` — signed qty (sell shown as negative), close. No P&L.

Background = `palette.crosshairChip` for positions and LIMIT, `palette.crosshairChip` with a 1px amber outline for SL.
Text colour = line colour for the qty and P&L; close icon uses `palette.axisText`.

### 2.4 Right-gutter price chip

A separate small chip inside the right gutter at the line's y, in the line's colour, showing the precise price (3 dp). Replaces the auto axis tick at that y. Uses the existing `_drawChip(x, y, text)` helper with the line's colour overriding the default `crosshairChip` background.

### 2.5 Stacking and clamping

- If two labels would overlap vertically, the lower-y one shifts down by `chipHeight + 2px` (greedy top-to-bottom by price).
- If a line's price is outside the visible `[lo, hi]` window, draw the dot + label as a flat caret at the corresponding plot edge (top or bottom), at the same x. The line itself is NOT drawn.
- Same clamping for the gutter price chip.

### 2.6 Hit areas

- **Line hit area:** 6px-tall horizontal band centred on the line, spanning `plot.left` → label's left edge. Cursor → `pointer` on hover.
- **Label hit area:** the chip's bounding box. Cursor → `pointer`. The `×` icon's own bounding box steals the hit for the close action.
- **Off-screen caret:** the caret bounding box is one combined hit area.

---

## 3. Data model

### 3.1 Bridge payload shape

```dart
// New encoder in chart_engine_bridge.dart
String encodeSetPaneOverlays(String paneId, List<Map<String, Object?>> overlays);
```

Each overlay map:

```dart
{
  'id': 'pos-NSE-2885' | 'ord-28456' | 'sl-28457' | 'sl-l-28457',
  'kind': 'position' | 'limit' | 'sl' | 'sl-l',
  'side': 'buy' | 'sell',
  'qty': 20,         // SIGNED — positive = long/buy, negative = short/sell
  'price': 1356.80,  // for position: netavgprc; LIMIT: prc; SL: trgprc; SL-L cap: prc
  'pnl': 220.0,      // positions only — null/absent otherwise
  'pnlPct': 0.81,    // positions only — null/absent otherwise
}
```

`id` is stable per source row, so the iframe can diff between updates without rebuilding everything (useful when extending to drag-to-modify later).

### 3.2 Inbound messages from iframe

```dart
// Click on a line (not the × button) — opens the detail popup.
{ type: 'overlayClicked', value: { paneId: '0', overlayId: 'pos-NSE-2885', clientX: 824, clientY: 312 } }

// Click on the × button — opens the close-confirm dialog.
{ type: 'overlayCloseRequested', value: { paneId: '0', overlayId: 'ord-28456' } }
```

`clientX`/`clientY` are iframe-local coordinates; the shell adds the iframe's `getBoundingClientRect()` offset to place the popup in app coordinates.

### 3.3 Source-of-truth mapping

**Open-orders predicate (mirrors `OrderProvider` lines 1483-1491 — the same split the existing Order Book "Open" tab uses):**

```dart
bool isOpenOrder(OrderBookModel o) =>
    o.stat == 'Ok' &&
    o.status != 'REJECTED' &&
    o.status != 'CANCELED' &&
    o.status != 'COMPLETE' &&
    o.status != 'INVALID_STATUS_TYPE';
```

For pane `i` with scrip `s = panes[i].scrip` (if non-null):

1. **Positions:** `portfolioProvider.postionBookModel` filtered by `p.exch == s.exch && p.token == s.token && int.parse(p.netqty ?? '0') != 0`. Map each →
   ```
   { id: 'pos-${exch}-${token}', kind: 'position', side: netqty>0?'buy':'sell',
     qty: netqty, price: parseDouble(netavgprc),
     pnl: parseDouble(mTm), pnlPct: (pnl / (avg * qty.abs())) * 100 }
   ```
2. **LIMIT orders:** open-orders filter + matching exch+token + `prctyp == 'LMT'`. Map each →
   ```
   { id: 'ord-${norenordno}', kind: 'limit', side: trantype=='B'?'buy':'sell',
     qty: trantype=='B'?+parseInt(qty):-parseInt(qty), price: parseDouble(prc) }
   ```
3. **SL orders:** open-orders filter + matching exch+token + `prctyp` in `{'SL-MKT','SL-LMT'}`. Emit one overlay with kind `sl` at `parseDouble(trgprc)`. If `prctyp == 'SL-LMT'` ALSO emit a second overlay with kind `sl-l` at `parseDouble(prc)` and id `sl-l-${norenordno}` so the pair stays linked.

**Field reference (verified from existing code):**
- `trantype` values: `'B'` / `'S'` (NOT `BUY`/`SELL`).
- `prctyp` values: `'LMT'`, `'MKT'`, `'SL-LMT'`, `'SL-MKT'` (NOT `LIMIT`/`MARKET`).
- `status` "executed-or-terminal" values to exclude: `REJECTED`, `CANCELED`, `COMPLETE`, `INVALID_STATUS_TYPE`.
- `stat == 'Ok'` is required (filters out bad rows).
- Most numeric fields on the models are strings — parse to `int`/`double` defensively.

---

## 4. Architecture and message flow

### 4.1 Provider observation

In `chart_engine_shell_screen.dart`:

```dart
ref.listen<List<PositionBookModel>?>(
  portfolioProvider.select((p) => p.postionBookModel),
  (_, __) => _pushSession(),
);
ref.listen<List<OrderBookModel>?>(
  orderProvider.select((p) => p.orderBookModel),
  (_, __) => _pushSession(),
);
```

Both providers are legacy `ChangeNotifierProvider` and `ref.listen` on a `.select` works directly. The `_pushSession` call re-runs the diff-cached push logic for ALL panes (which is cheap because of the JSON-equal cache).

### 4.2 Per-pane diff cache

In `chart_engine_shell_screen.dart`, alongside the existing `_pushedSymbolKey` / `_pushedTimeframe` / `_pushedOverlaysJson` maps, add:

```dart
final Map<int, String> _pushedPaneOverlaysJson = {};
```

Inside `_pushSession`, after the per-pane symbol/timeframe/overlay-flag pushes, compute overlays for pane `i`, JSON-encode, compare to `_pushedPaneOverlaysJson[i]`, push only on diff. Layout change clears this map too.

### 4.3 JS engine state

In `chart.js`:

```js
this._overlays = [];          // current overlays for this pane
this._overlayHits = [];       // computed each draw: { rect, kind, action, overlay }
this._highlightedOverlayId = null;
```

New methods:

- `setOverlays(list)` — replaces `this._overlays`, calls `this.scheduleRedraw()`.
- `_drawOverlays(plot, lo, hi, priceToY)` — renders all overlays in stacking order: positions first (bottom in z-order), then orders. Computes `_overlayHits` array.
- `_drawOverlayPriceChips(plot, lo, hi, priceToY)` — separate pass that draws the right-gutter price chips.
- `_overlayHitTest(x, y)` — returns `{ overlayId, action }` or null. `action` is `'open' | 'close'`.

Wiring:

- `mousemove` (existing handler): after the zone classification, if not dragging, call `_overlayHitTest` and set cursor to `pointer` when a hit is found.
- `mousedown` (existing handler): if `_overlayHitTest` returns a hit, `e.preventDefault()`, `e.stopPropagation()`, post `overlayClicked` or `overlayCloseRequested` to parent, return BEFORE the existing pan/zoom/dragMode logic.
- `_drawOhlc`, crosshair, time chip etc. are drawn AFTER overlays so the chip and crosshair sit on top.

### 4.4 Detail popup

New file `lib/screens/web/chart_engine/widgets/overlay_detail_popup.dart`. Exports a function:

```dart
void showOverlayDetailPopup({
  required BuildContext context,
  required Offset anchorAppCoords,   // where to position the card
  required OverlayDetailData data,
  required VoidCallback onClose,
});
```

`OverlayDetailData` is a sealed-like union:

- `OverlayDetailData.position(PositionBookModel)` — shows tsym, product, signed qty, avg, LTP, day P&L, MTM, entry time if available.
- `OverlayDetailData.order(OrderBookModel)` — shows tsym, product, side, prctyp, qty (remaining/total), price, trgprc (if SL), status, order id, exchange order id, placed-at time.

Layout: a `PointerInterceptor`-wrapped Material `Card` anchored at `anchorAppCoords`, clamped to stay within the screen. No action buttons. Dismisses on outside tap (clear background gesture) or when the underlying overlay disappears from the providers (popup observes and self-dismisses).

### 4.5 Close-confirm dialog

Reuses the app's existing AlertDialog pattern. Single dialog with title, body explaining what's about to happen, and Cancel / Confirm buttons.

- **Order overlay:** confirm → `ref.read(orderProvider.notifier).fetchOrderCancel(order.norenordno.toString(), context, false)`. Internal API call already wires the success toast.
- **Position overlay:** confirm → `ref.read(portfolioProvider.notifier).fetchExitPosition(context, placeOrderInput, true, false)` where `placeOrderInput` is built exactly like `lib/provider/portfolio_provider.dart` lines 1689-1711:
  ```dart
  PlaceOrderInput(
    exch: position.exch!, tsym: position.tsym!,
    qty: position.netqty!.replaceAll('-', ''),
    prc: '0', prctype: 'MKT',
    trantype: int.parse(position.netqty!) < 0 ? 'B' : 'S',  // flipped
    prd: position.prd!, ret: 'DAY',
    trgprc: '', blprc: '', bpprc: '', dscqty: '', amo: '', trailprc: '', mktProt: '',
  )
  ```

Both providers are legacy `ChangeNotifierProvider` — use `ref.read(orderProvider)` (no `.notifier`) and call the methods directly. They handle their own toasts.

---

## 5. Edge cases and decisions

| Case | Behaviour |
|---|---|
| Pane scrip is null (empty pane) | Push `[]` overlays → iframe clears its list |
| Position closes (netqty becomes 0) | Filter drops it → next `_pushSession` removes it from the iframe |
| Order completes/cancelled | Same — filter excludes non-OPEN statuses |
| Symbol changes mid-overlay | New scrip filter → old overlays disappear, new ones appear; existing pane animation handled by setOverlays replacement |
| Theme switch | Colours derived from `palette` on every draw, so they auto-track |
| Layout change (pane count up/down) | Existing `applyLayout` destroy path nukes the pane's `Chart` instance; per-pane diff cache is cleared by the existing layout-change branch in `_pushSession` |
| Overlapping labels at same y | Greedy vertical stacking by descending y |
| Off-screen price (above hi or below lo) | Caret-shaped chip at the plot edge, no line drawn |
| Multiple panes show the same symbol | Each pane independently renders the same overlays — correct, no de-dup needed |
| Network error on close-confirm action | `errorMessage` toast, dialog stays open, no overlay change |
| App opens with stale order book before WS connects | First REST fetch populates `orderProvider`; once WS connects, OM updates flow through. Chart picks up both via `ref.listen` automatically |
| Hover on a line during a pan/drag | Hit-test is skipped while `_dragMode != null` — drag wins |

---

## 6. Out of scope (Phase 4+)

- Drag-to-modify (drag the line to reprice the order/position SL)
- `+ TP` / `+ SL` quick-add buttons on the position label
- Reverse-position toggle (the `↕` icon in TradingView's screenshot)
- Qty edit inline on the chip
- GTT (Good-Till-Triggered) order overlays
- Alerts overlays
- Bracket / cover order grouping (when those become first-class in the app)
- Per-overlay show/hide toggles in Settings
- Multi-leg combined P&L row

---

## 7. Acceptance smoke

1. Open `/charts` with a layout that has a pane showing a symbol you have an open position in → solid line at avg, label `[qty pnl ×]`, blue if long / red if short.
2. Place a LIMIT order in that symbol from another screen → return to `/charts` → dashed line appears at the order price within ~1 second (WS OM update).
3. Place an SL-L for the position → dotted red line at trigger price + dashed line at the limit cap.
4. Click the dashed LIMIT line (not the `×`) → detail card pops up at click point with full order details.
5. Click `×` on the LIMIT label → confirm dialog → confirm → order cancels, toast shows, dashed line disappears.
6. Click `×` on the position label → confirm dialog explaining "square off N qty MARKET opposite side" → confirm → MARKET order fires, position disappears once fill comes through OM.
7. Switch pane to a symbol with no positions/orders → all lines clear.
8. Change layout from `single` to `cols2`, point second pane at the same symbol → same overlays render in both panes independently.
9. Pan and zoom the chart → lines stay anchored to their price, labels track the rightmost candle, gutter chips stay at their y.
10. Reload the page → overlays re-appear after providers re-hydrate.
11. Theme switch → all overlay colours update with the rest of the chart.

If any smoke step fails, do not declare Phase 3 done.
