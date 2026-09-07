# CAS Indicative-Price Row — Design

**Date:** 2026-08-17
**Status:** Approved design (pre-implementation)
**Scope:** A new always-present row in the market-depth panel showing the exchange's live Closing-Auction-Session indicative price, sourced from the feed's `ic` field.

## Goal

In the market-depth panel, below the bid/ask ladder, add one row that displays the
exchange's **indicative closing price** during an auction, labelled with a solid
**`CAS`** badge. When no auction is running (no `ic` in the feed), the row shows `—`.

## Background — CAS and where the data comes from

The NSE/BSE **Closing Auction Session** (3:20–3:35 PM IST, for F&O-eligible
cash-segment stocks) discovers the closing price via an equilibrium auction. During
it the exchange broadcasts a live **indicative equilibrium price**.

**Confirmed empirically** (RELIANCE-EQ, token 2885, 2026-08-17 — captured via a
throwaway logger): the Kambala feed carries this as the **`ic`** field on the
`tf`/`tk`/`df`/`dk` frames. Observed series: `ic` 1308.60 (15:20:13) → 1311.70
(15:22:08) → 1316.00 (15:27:51); the stock closed at **1316.00** — an exact match.
`ic` also appears in the 9:00–9:08 pre-open auction, so this row lights up for both
auctions with no extra logic.

**Client-side computation is not viable and is explicitly rejected.** The depth feed
exposes only 5 band-edge-aggregated levels plus lumped market-order buckets
(`bp5/sp5 = 42949672.95` = a "no-price" sentinel). Running the max-executable-volume
algorithm on that snapshot yields a circuit edge (1279 or 1358 depending on
market-order handling), off the real price by ₹30–80. Only the exchange has the full
auction book; it hands us the answer as `ic`. **Use `ic`; never self-compute.**

## Data source & semantics

- **Field:** `ic` on the incoming socket frame (present on both touchline `tf`/`tk`
  and depth `df`/`dk`). It is a **delta field** — sent only when the value changes.
- **Latch:** hold the last-received `ic` for the currently-open scrip; it persists
  across subsequent frames that omit it. Reset naturally when the scrip changes
  (the depth screen rebuilds its `GetQuotes` object per scrip).
- **Validity:** treat `ic` as present only when non-null and `> 0`. Anything else →
  display `—`.

## UI

- **Placement:** a new row inside the depth panel, directly below the existing
  bid/ask 5-level ladder and the Total Buy Qty / Total Sell Qty row. The existing
  rows are unchanged.
- **Content:** `[CAS]  Indicative Close        ₹<ic>` when live; `[CAS]  Indicative
  Close        —` when idle.
- **`CAS` badge:** a solid, colored chip with white text (per the project chip
  convention — never transparent/grey). Uses the theme accent, matching the depth
  panel's other chips; 10px gap if adjacent to other chips.
- **Value formatting:** same price formatting as the ladder prices (2 decimals,
  themed text color via `MyntWebTextStyles` / `resolveThemeColor`).
- **Visibility:** **always shown** (product decision), on every scrip the depth
  screen displays, regardless of segment. Non-eligible instruments simply show `—`
  perpetually (they never receive `ic`).

## Files & changes (web)

- `lib/models/marketwatch_model/get_quotes.dart` — add `String? ic;` with `fromJson`
  (`json['ic']`) and `toJson` entries. This is the `depthData` object the panel reads.
- `lib/screens/web/market_watch/scrip_depth_info_web.dart`:
  - In `_processDepthData(GetQuotes depthData, Map socketData)` (~line 290): add
    `if (_isValidValue(socketData['ic'])) depthData.ic = "${socketData['ic']}";`
    (latch on valid, so absent/zero frames never clear a good value mid-auction).
  - Add the CAS row widget below the Total Buy/Sell Qty row. **Note:** this file
    renders the depth block in **two layouts** (the compact panel ~line 660 and the
    expanded/alternate layout ~line 2050); the row must be added in **both** so it
    appears consistently.
- **Remove the temporary debug instrument** in the same change: delete
  `lib/utils/cas_debug_logger.dart` and revert the two hooks in
  `lib/provider/websocket_provider.dart` and `scrip_depth_info_web.dart`.

**Mobile** (`lib/screens/Mobile/market_watch/scrip_depth_info.dart`): **out of scope
for v1** (web only for now, mobile later — user decision). The `GetQuotes` model +
`ic` parsing are shared, so the mobile follow-up is just the row widget.

## Testing

- **Unit:** a small pure helper `casIndicativeDisplay(String? ic)` → returns the
  formatted `₹<ic>` string or `—` (covers null, empty, `"0"`/`"0.00"`, and a valid
  value). Keeps the display rule testable without the widget.
- **Manual:** during a live auction (3:20–3:35 close or 9:00–9:08 pre-open) on a
  CAS-eligible stock (e.g. RELIANCE), the row shows the indicative price and updates
  as `ic` changes; outside auctions and on non-eligible scrips it shows `—`.

## Out of scope (v1)

- Auction total-buy/sell and **imbalance** display (`tbq`/`tsq` are already shown in
  the existing Total Buy/Sell Qty row; imbalance = `tbq − tsq` can be added later).
- Any order placement / trading during CAS.
- Self-computed equilibrium price (rejected above).
- Special handling of the band-edge/sentinel 5-level ladder shown during CAS.
- Mobile depth screen (fast follow).

## Notes

- **Branch:** implement on a fresh branch off `main` — NOT `popout-chart` (this is
  unrelated to the popout work).
