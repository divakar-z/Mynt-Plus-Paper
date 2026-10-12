# Basket / Order Book QA — Oct 9 test round

Worked on 2026-10-11, branch `fix/basket-qa-oct9-testcases`.
Source: QA sheet "basket in orderbook" test cases, run on Oct 9.

This file is the hand-off for whoever picks this up next. It lists every test
case we looked at, what was wrong, what was changed (or why it was parked),
and what is still needed.

**Status of the code on this branch:** analysed and `flutter analyze` clean
(no errors). **Not yet retested on live** — run the retest steps under each
fixed case before merging.

## Summary

| # | Case | Result |
|---|---|---|
| 1 | TC_312 — row click opens Delivery for BO/CO | Fixed |
| 2 | TC_308 — disclosed qty > qty not validated in basket | Fixed |
| 3 | TC_293 — old statuses come back after Reset Orders | Fixed |
| 4 | TC_275 — Lot label missing on order screen (NCOM) | Parked |
| 5 | TC_276 — option (PE/CE) slice price in basket | Parked |
| 6 | TC_263 — one-segment basket rule vs Kite | Parked |
| 7 | TC_257 — basket search "NIFTY 50" / "NIFTY" shows nothing | Parked |

Extra issues found while checking (not in the QA sheet):

| Found during | Issue | Result |
|---|---|---|
| TC_308 | Editing a basket row could delete it; edited row jumped to the bottom | Fixed |
| TC_308 | Split basket rows kept the full disclosed qty (> row qty) | Fixed |
| TC_293 | Place button placed rows the user had not ticked | Fixed |
| TC_308 | Normal Place Order slice sheet sends full disclosed qty on every slice | Parked |
| TC_275 | NCOM exchange not handled across the app | Parked |

Checked, no bug: a NIFTY basket row of qty 2340 was not sliced. NSE raised the
NIFTY freeze limit from 27 lots (1755) to 54 lots (3510) effective
2026-10-05, so 2340 (36 lots) is within one order. The app reads `frzqty`
from scrip info, so it picked this up automatically. QA cases that hard-code
old slice counts need updating.

---

## Fixed

### TC_312 — Modify a Bracket/Cover order in a basket

- **Expected:** opening a BO/CO basket row for modify opens the order screen
  on **CO - BO** with Bracket/Cover selected.
- **Actual:** the modify (pencil) icon worked; **clicking the row** opened the
  Delivery screen.
- **Cause:** the row tap in `basket_list_web.dart` was a copy of the edit
  handler made before the TC_237 fix. It passed `prd: item['prd']` (raw `B` /
  `H`), which the order screen does not recognise as a product, so it fell
  back to Delivery. The icon path (`_handleEditBasketScript`) passes
  `_prdArgForBasketRow(item)`, which sends `null` for BO/CO so the screen
  reads the product from `raw` and selects CO - BO.
- **Fix:** the row tap now calls `_handleEditBasketScript(item,
  originalIndex, theme)` — one code path for icon and row. ~70 duplicated
  lines removed.
- **File:** `lib/screens/web/ordersbook/basket/basket_list_web.dart`
- **Retest:** in a basket add one BO and one CO item. Click each row and each
  modify icon → all four open CO - BO with the right option. Click a CNC row
  → opens Delivery.

### TC_308 — Disclosed Quantity greater than Order Quantity (basket)

- **Expected:** "Disclosed quantity cannot be greater than Quantity" warning;
  item not saved.
- **Actual:** no message; item saved.
- **Cause:** `placeOrder` in `place_order_screen_web.dart` splits into a
  basket branch (`Basket` / `BasketEdit` / `BasketMode` → `addBasketScrip`)
  and a normal-order `else` branch. All field checks lived in the `else`
  branch, so the basket never ran them. Normal Place Order was fine.
- **Fix:** new `_basketFieldsValid()` runs, for the basket path only, the
  same checks and messages as normal Place Order:
  - CO/BO Stoploss multiple of tick size
  - BO Target multiple of tick size
  - Disclosed Qty ≤ Quantity
  - Price multiple of tick size (Limit / SL Limit)
  - Trigger multiple of tick size (SL Limit / SL MKT)
  - Market Protection 1–20% (Market / SL MKT)

  It is called at the top of the basket branch, **before** anything is
  removed. The normal-order branch is unchanged.
- **Deliberately not copied to the basket** (agreed with the user):
  surveillance warning sheet (Kite does not show it for baskets either),
  slice-order flow (basket already splits by freeze qty in
  `addBasketScrip`), lot-size check (already in `addBasketScrip`).
- **File:** `lib/screens/web/order/place_order_screen_web.dart`
- **Retest:** in a basket set Disclosed Qty above Qty → warning, row not
  saved; editing an existing row the same way → warning and the row stays.

### Extra (from TC_308) — Basket edit lost the row on a failed check

- **Problem:** a basket edit called `removeBsktScrip` (delete old row) and
  then `addBasketScrip`, which validates lot size and basket slots. If a
  check failed, the old row was already gone and nothing was re-added — the
  item silently disappeared. Also, every edited row moved to the bottom.
- **Fix:** `placeOrder` no longer deletes first. It passes `editIndex` to
  `addBasketScrip`, which:
  - counts the edited row's slot as free when checking basket capacity;
  - runs all checks; only if they pass, replaces the row **in place**
    (`replaceRange`), including when the edit now splits into several rows;
  - clears the replaced row's order tracking (`removeScriptOrderTracking`),
    as `removeBsktScrip` used to;
  - if `editIndex` is missing/out of range, treats it as a plain add
    (previously a missing index fell back to deleting row 0).

  On failure the warning shows and the order window stays open with the
  user's values.
- **File:** `lib/screens/web/order/place_order_screen_web.dart`
- **Retest:** edit a NIFTY basket row to a non-lot-multiple qty → error, row
  still there. Edit the 2nd of 3 rows → stays 2nd.

### Extra (from TC_308) — Disclosed qty on split basket rows

- **Problem:** when qty > freeze qty, `addBasketScrip` splits into several
  rows but stored the full disclosed qty on each. E.g. qty 2500, freeze 1000,
  disclosed 1200 → rows 1000/1200, 1000/1200, 500/1200 — exchange can reject.
- **Fix:** each row stores `min(disclosed, rowQty)` → 1000/1000, 1000/1000,
  500/500. Rows that are not split, or disclosed 0, are unchanged.
- **File:** `lib/screens/web/order/place_order_screen_web.dart`

### TC_293 — Add a scrip after Reset Orders

- **Expected:** after Reset Orders, adding a scrip leaves the existing rows
  blank.
- **Actual:** previously placed rows got their status (Cancelled / Rejected /
  Open) back.
- **Reproduced on live:** place → close the basket → reopen it → Reset →
  add a scrip → old statuses return. (Without the close/reopen it does not
  reproduce, which is why a first attempt passed.)
- **Cause:** row order fields (`orderIds`, `orderStatus`, …) live in three
  places: the in-memory list, order-tracking storage, and the **saved basket
  rows** (written back by `chngBsktName` → `_saveBasketToPreferences` when a
  basket is opened). `resetBasketOrderTracking` cleared the first two but not
  the saved rows. The next reload from storage (add scrip, reopen, F5)
  brought the `orderIds` back and `updateBasketOrderStatus` re-applied the
  statuses from the order book.
- **Fix** in `resetBasketOrderTracking`:
  - new `_clearBasketRowsOrderFieldsInStorage(basketName)` strips
    `orderIds, orderStatus, orderError, avgPrice, filledQty,
    rejectionReason` from that basket's saved rows (per-user storage, else
    general);
  - the in-memory list is only cleared when the basket being reset is the
    open one (the option-chain basket picker can reset a different basket and
    used to wipe the open basket's statuses);
  - shared `_clearRowOrderFields` helper.
  Orders themselves are not touched — they stay in the order book.
- **File:** `lib/provider/order_provider.dart`
- **Retest:** place → close → reopen → Reset → (a) add a scrip, (b) F5 and
  reopen, (c) close and reopen → old rows stay blank every time.

### Extra (from TC_293) — Place button with only sent rows ticked

- **Problem:** ticking only already-sent rows (REJECTED / OPEN …) showed
  "Place Order", and clicking it placed every **unsent** row — rows the user
  had not ticked. Sent rows were never re-sent (no duplicate orders), but the
  wrong rows went out.
- **Fix:** when rows are ticked but none are placeable, the button is
  disabled with tooltip "Selected rows are already sent. Reset Orders to
  place them again." Nothing ticked → "Place Order" sends all unsent rows (as
  before); unsent rows ticked → "Place Selected (N)" (as before).
- **File:** `lib/screens/web/ordersbook/basket/basket_list_web.dart`
- **Retest:** tick only sent rows → button greyed + tooltip; untick → normal.

---

## Parked

### TC_275 — Lot field on the order screen (NCOM)

- **Expected:** the order screen shows the Lot field for derivatives.
- **What we found on live:** NFO / BFO show "Lot : N"; MCX shows header
  **Lot** with "Qty : 100" — both fine. QA's failing scrip was
  **CRUDEOIL FUT on NCOM**, which shows a plain "Qty" box with no label, in
  both normal Place Order and basket.
- **Cause:** the order screen only handles NFO/BFO and MCX for lot display.
  NCOM scrip info: `ls` = 1, `prcftr` = 100, `prcunt` = BBL, `mult` = 1,
  `frzqty` = 101. So on NCOM 1 qty = 1 lot = 100 BBL; the 100 is in
  `prcftr`, not `ls`. Quantities sent are correct (margin for NCOM qty 1
  matches MCX 1 lot); only the label is missing.
- **Why parked:** user chose to move on; low risk.
- **Needed:** on the order screen treat NCOM like MCX — header "Lot",
  sub-label "Qty : lots × prcftr prcunt" (e.g. "Qty : 100 BBL"). Open
  question: also show the unit for MCX.

### NCOM not handled across the app (found during TC_275)

- MCX vs NCOM checks: place order 67 vs 7, modify GTT 18 vs 0, quick order
  5 vs 0, positions/convert ~20 vs 0, order/trade book ~10 vs 0, basket 2 vs 0.
- Harmless today because NCOM `ls` = 1 (all ×/÷ lot size math is a no-op),
  and P&L already uses `prcftr` (`portfolio_provider.dart`,
  `group_pnl_chart_provider.dart`).
- **Needed:** a dedicated NCOM QA round (positions, order book, GTT, modify)
  before relying on this.

### TC_276 — Option (PE/CE) slice price in basket

- **Written steps** (lot 75, freeze 1800, qty 4050 → 1800 / 1800 / 450,
  SENSEX50 FUT) **pass**.
- **QA fail note:** "PE/CE Slice Price not updated in basket" — the exact
  steps for options were not recorded.
- **Code trace found no bug:** every split row stores the same `ordPrice`
  (which follows the Price box, depth tap and Market→Limit); the LTP cell
  (`_BasketLtpCell`) listens per token so all slices of one contract update
  together; market rows use each row's live `lp` at placement.
- **Why parked:** cannot reproduce without QA's exact steps.
- **Needed:** QA steps. Checks to run: NIFTY option qty 4000 @ 100.50 → both
  rows show 100.50? LTP moves on both rows in market hours? Editing one slice
  only changes that row — this is by design (each slice is its own order,
  same as Kite); if QA expects all slices to change, it is a design request.

### TC_263 — Mixed segments in one basket (vs Kite)

- **Test text:** BUY on an option when derivatives segment is not active →
  order screen must not open, "Segment is not active."
  - This part is **already handled**: both basket search paths check
    `exarr` before opening the order screen
    (`basket_list_web.dart` `_handleBuySellClick`, `search_dialog_web.dart`),
    and search only returns entitled exchanges.
- **QA's actual point:** our basket allows adding NSE + NFO but then shows
  "Basket should contain orders of only 1 segment" and disables Place. Kite
  allows mixed baskets and places all (reference screenshot: HINDUNILVR BSE +
  TCS PE NFO + TCS BSE, "Place all" enabled).
- **Why parked:** the one-segment rule was added **on purpose**; needs a team
  decision.
- **Technical notes:** nothing requires the rule — rows are placed one by one
  (`_placeBasketElement`), and the basket margin request already sends `exch`
  per row. If the team drops it: remove the `_hasMultipleExchanges` warning
  bar and Place-button block in `basket_list_web.dart`,
  `market_watch/options/basket_sidebar_web.dart`,
  `market_watch/options/option_chain_ss_web.dart`; then verify the margin for
  a mixed basket on live.

### TC_257 — Basket search "NIFTY 50" shows no tradable contracts

- **Expected:** the index itself hidden (not tradable), NIFTY FUT/options
  shown.
- **Actual:** "No Results Found" — also for plain "NIFTY". Kite's "nifty 50"
  shows NIFTY ETFs and NIFTY OCT/NOV/DEC FUT, no index.
- **What we checked:** the basket hides rows with `idx == 'YES'`
  (`basket_list_web.dart` `_buildSearchResults`, added in 8821fa72) — this is
  correct; `idx` is read straight from the server; `fetchSearchScrip` keeps
  every row the server sends; the request sends the text, category "" and
  the user's exchanges.
- **Likely cause (not yet confirmed):** the search API returns a limited
  result set and for "NIFTY" it is filled with NSE indices (70+ "NIFTY …"
  indices), all `idx: YES`, so after our filter nothing is left. Also no
  index-name → F&O-symbol mapping exists ("NIFTY 50" does not text-match
  "NIFTY 27 OCT 26 FUT").
- **To confirm:** DevTools → Network → SearchScrip response for "NIFTY" —
  are all `values` `idx: YES` with no NFO rows?
- **Why parked:** depends on server behaviour.
- **Needed (pick one):**
  1. Backend (preferred): a search parameter to exclude indices server-side,
     so the limit is filled with tradable rows.
  2. Our side: when all results are indices, run a second search in the FO
     category (+EQ for ETFs) and map index names → F&O symbols
     (NIFTY 50 → NIFTY, NIFTY BANK → BANKNIFTY, NIFTY FIN SERVICE →
     FINNIFTY, NIFTY MID SELECT → MIDCPNIFTY).

### Slice sheet disclosed qty (normal Place Order, found during TC_308)

- `lib/screens/web/order/slice_order_sheet_web.dart` `_buildOrderInput`
  sends `dscqty: widget.discQtyCtrl.text` on every slice — the full
  disclosed qty even when it exceeds that slice's qty, and it does not force
  "0" for F&O the way the unsliced path does (`_dscqtyApplies`).
- **Why parked:** user chose to move on.
- **Needed:** same cap as the basket fix — `min(disclosed, sliceQty)` per
  slice, and "0" when disclosed qty does not apply.

---

## Files changed on this branch

- `lib/screens/web/ordersbook/basket/basket_list_web.dart` — TC_312 row tap;
  Place button disabled when only sent rows are ticked.
- `lib/screens/web/order/place_order_screen_web.dart` — TC_308
  `_basketFieldsValid`; in-place basket edit (`editIndex`); disclosed qty cap
  on split rows.
- `lib/provider/order_provider.dart` — TC_293 reset clears saved basket rows;
  reset only touches the open basket in memory.
