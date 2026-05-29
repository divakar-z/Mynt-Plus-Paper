# InstaOptions — Backend Tickets

**Generated**: 2026-05-29
**Source**: audit of live OptionZ (https://zebu.instaoptions.trade) against the user's OI Data backend (`192.168.5.61:8000`, documented in `INSTAOPTIONS_FEATURE_README.md` §8).
**Reference screenshots**: `.claude/insta-options-qa/optionz-reference/01-…09-*.png`.
**Detailed audit matrix**: `.claude/insta-options-qa/data-audit.md`.

## Why these tickets exist

After Phase 4 we opened the live OptionZ product (which our backend is informally modeled after) and mapped every data point each OptionZ screen shows to a field in our backend's response shapes. The audit found:

- ~95% of OptionZ's data points are already returned by existing endpoints.
- 3 gaps require backend extension. They cannot be worked around on the frontend per project rule (no client-side joins, no client-side re-aggregation of raw timeseries).

Each ticket below lists the affected endpoint, the missing field/param/endpoint, the screen that blocks on it, and the rationale.

---

## Ticket 1: Add `prev_close` to /analytics/chain rows

**Status**: ✅ **Resolved 2026-05-29** — verified live: CE + PE rows now include `prev_close`; FUT row is correctly excluded (consistent with the FUT-row-has-no-Greeks pattern). Phase γ unblocked.

**Priority**: High (Option Chain screen blocks)
**Endpoint**: `GET /analytics/chain` (README §8.17)
**Frontend phase blocked**: γ — Option Chain LTP %Change column.

### Current row shape
```json
{
  "token": 79722,
  "symbol": "NIFTY",
  "expiry": "30-JUN-2026",
  "option_type": "CE",
  "strike": "23900.0",
  "trading_symbol": "NIFTY30JUN26C23900",
  "ltp": 445.25,
  "oi": 684840,
  "volume": 1655745,
  "iv": 12.8214,
  "delta": 0.571499,
  "gamma": 0.0004258356,
  "theta": -7.845491,
  "vega": 28.219064,
  "rho": 11.952694,
  "iv_solver_ok": true
}
```

### Proposed addition
```diff
{
  ...existing fields,
+ "prev_close": 440.10
}
```

`prev_close` = previous trading day's close for that contract (float, same units as `ltp`). For new contracts without a previous close, return `null`.

### Why
OptionZ's Option Chain table renders LTP with a colored `+1.18%` / `-0.83%` % change next to it for both CE and PE columns. This % change is computed as `(ltp - prev_close) / prev_close * 100`. We currently have no field to support this and cannot derive it from `/oi/chain` either.

### What the frontend will do after delivery
Phase γ adds `prevClose` to `ChainRow` model, then renders `{ltp}  <colored>{±x.xx%}</colored>` in the CE LTP and PE LTP columns of the Option Chain table.

### Frontend fallback if not delivered
Hide the % change suffix. LTP column shows just the LTP value (current behavior is already this).

---

## Ticket 2: Add `bucket_minutes` query param to timeseries endpoints

**Status**: ✅ **Resolved 2026-05-29** — verified live: `/oi/pcr/timeseries` accepts `bucket_minutes=1|5|15` without error and windows accordingly (e.g. `bm=15` returns the 15:30 close bucket; default returns the underlying tick at 10:00). Underlying PCR series is sparse today but the param plumbs through. Phase δ unblocked.

**Priority**: Medium (PCR Ratio + Options Chart per-strike Time selector blocks)
**Endpoints**:
- `GET /oi/pcr/timeseries` (README §8.11)
- `GET /oi/timeseries` (README §8.9)
**Frontend phase blocked**: δ — Time bucket selectors on PCR Ratio and Options Chart per-strike.

### Current behavior
Both endpoints return 1-minute buckets. No control over bucket size.

### Proposed addition
New optional query parameter:

```
GET /oi/pcr/timeseries?exchange=NFO&symbol=NIFTY&expiry=30-JUN-2026&bucket_minutes=3
GET /oi/timeseries?exchange=NFO&symbol=NIFTY&expiry=30-JUN-2026&option_type=CE&strike=23900.0&bucket_minutes=5
```

`bucket_minutes` ∈ `1 | 3 | 5 | 15`. Default `1` (preserves current behavior). Server windows raw 1-min buckets and aggregates per bucket (PCR — average; OHLCV — open/high/low/close/sum-volume; OI — last value of bucket; oi_change — sum within bucket).

### Why
OptionZ exposes a "Time" dropdown on both PCR Ratio and Per-Strike Options Chart screens with options `1 min / 3 min / 5 min / 15 min`. Each selection re-fetches and re-renders the chart. Client-side downsampling is forbidden per project rule (re-aggregating raw timeseries is a workaround we want to avoid).

### What the frontend will do after delivery
Phase δ adds `bucketMinutes` to `InstaOptionsPcrProvider` and `InstaOptionsStrikeProvider`, wires a dropdown widget in `pcr_screen.dart` and `per_strike_screen.dart`, and re-fires the API on selection change.

### Frontend fallback if not delivered
Show the dropdown disabled with a "Coming soon" tooltip. Phase δ doesn't commit until backend ships.

---

## Ticket 3: New endpoint `/oi/trending`

**Status**: ✅ **Resolved 2026-05-29** — verified live: endpoint returns the contracted per-bucket records `{time, sentiment, cum_ce_oi, cum_pe_oi, delta_ce_oi, delta_pe_oi, pcr, ltp, ltp_pct, dir_spot, dir_oi}`. Sentiment values like `0.9692`, `-1.0`, `0.849` showing real classification. `ltp` is currently `0.0` due to the Ticket 4 cascade — Trending OI's spot overlay will populate once Ticket 4's snapshot/contributors gap is closed. Phase η unblocked.

**Priority**: Medium (Trending OI screen blocks entirely)
**Endpoint**: NEW
**Frontend phase blocked**: η — Trending OI screen.

### Proposed endpoint shape

```
GET /oi/trending
```

**Query parameters**

| name | type | required | description |
|---|---|---|---|
| exchange | string | yes | `NFO` or `BFO` |
| symbol | string | yes | e.g. `NIFTY` |
| expiry | string | yes | `DD-MON-YYYY` |
| strikes | string | yes | comma-separated, one decimal: `23900.0,23950.0,24000.0` |
| types | string | yes | `CE,PE` (always both for our use) |
| bucket_minutes | int | no | `1 \| 3 \| 5 \| 15`, default `3` |
| date | string | no | `YYYY-MM-DD`, default today |

**Response shape**

Array of per-bucket records:

```json
[
  {
    "time": "2026-05-28 09:15:00",
    "sentiment": 0.42,
    "cum_ce_oi": 6850000,
    "cum_pe_oi": 6240000,
    "delta_ce_oi": 15000,
    "delta_pe_oi": -8000,
    "pcr": 0.91,
    "ltp": 23910.5,
    "ltp_pct": 0.05,
    "dir_spot": 1,
    "dir_oi": -1
  }
]
```

Field meanings:
- `time` — bucket close time (ISO, IST).
- `sentiment` — clamped to `[-1, +1]`. Formula (server-side):
  ```
  ΔCumCallOI = cum_ce_oi(t) - cum_ce_oi(t-1)
  ΔCumPutOI  = cum_pe_oi(t) - cum_pe_oi(t-1)
  sentiment  = (ΔCumPutOI - ΔCumCallOI) / (|ΔCumPutOI| + |ΔCumCallOI| + 1)
  ```
- `cum_ce_oi` / `cum_pe_oi` — sum of OI across the selected strikes at this bucket, CE and PE separately.
- `delta_ce_oi` / `delta_pe_oi` — bucket-over-bucket diff of `cum_*_oi`.
- `pcr` — bucket-level PCR = `cum_pe_oi / max(cum_ce_oi, 1)`.
- `ltp` — spot price at bucket close.
- `ltp_pct` — % change from bucket-open to bucket-close.
- `dir_spot` — sign of `ltp(t) - ltp(t-1)`: `+1`, `-1`, or `0`.
- `dir_oi` — sign of `delta_pe_oi + delta_ce_oi`: `+1`, `-1`, or `0`.

### Why
OptionZ's Trending OI screen renders two charts + a per-bucket bottom table. Every value visible on that screen is one of the fields above. Per the project's no-frontend-workarounds rule, we cannot reconstruct sentiment + cumulative OI + per-bucket diffs from raw `/oi/multistrike/timeseries` on the client.

### What the frontend will do after delivery
Phase η:
- New: `models/insta_options/trending_bucket.dart` matching the response.
- New: `provider/insta_options/insta_options_trending_provider.dart`.
- New: `widgets/strike_multi_picker.dart` to pick up to ~7 strikes.
- New: `screens/trending_oi_screen.dart` — sentiment chart + cumulative OI chart + bottom `DataTable2`.

### Frontend fallback if not delivered
Phase η pauses entirely. The Trending OI sub-screen shows a "Coming soon — backend `/oi/trending` pending" placeholder.

---

## Ticket 4: Populate prior-bar reference fields on snapshot / contributors / buildup

**Status**: ✅ **Mostly resolved 2026-05-29** (re-probed live at 17:21 IST; `analytics.last_run_ts` still reads 15:29:59 IST so the fix likely came from a manual backfill or a distinct rollup job rather than a fresh analytics run). Verified live:
- ✅ `/oi/buildup` per-contract: `open_oi` / `close_oi` / `price_change` populated. Classification distribution real (Long Buildup 38, Short Buildup 22, Short Covering 71, Long Unwinding 19, Neutral 320 on 470 NIFTY 02-JUN-2026 contracts). OI Buildup screen (Phase 3) shows real pills.
- ✅ `/market/snapshot.indices[]`: `today_open` / `yesterday_close` / `change_pct` populated (NIFTY -1.50%, BANKNIFTY -1.12%, FINNIFTY -1.55%, MIDCPNIFTY -1.57%, NIFTYNXT50 -1.23%, SENSEX -1.44%, BANKEX -1.08%). Markets Dashboard tiles render real coloured change% + downsloping sparklines.
- ✅ `/market/snapshot` advances / declines / unchanged: real counts (19 / 124 / 3 today).
- ✅ `/market/snapshot.per_index[].stocks[]`: `today_open` / `yesterday_close` / `gap_pct` / `change_pct` populated (HDFCBANK -1.86%, RELIANCE -2.17%, ICICIBANK -1.28% etc.).
- ✅ `/contributors/{index}.{change_pct, index_points}`: 48 of 50 NIFTY constituents non-zero (top contributors MARUTI -0.33, ULTRACEMCO -0.21, RELIANCE -0.20 index points). Index Contributors screen `Change %` + `Index Pts` columns now populate. Phase ζ visible data unblocked.
- ⚠ **Still outstanding**: `/buildup/symbols` (NFO and BFO) still returns all four bucket arrays empty even though per-contract `/oi/buildup` already classifies symbols into Long Buildup / Short Buildup / Short Covering / Long Unwinding. This is a per-symbol futures roll-up bug, *distinct* from the field-population issue resolved above. Phase ε Markets Dashboard 2×2 quadrant grid remains empty until this is fixed.

**Priority**: High (Markets Dashboard + Index Contributors visibly broken; OI Buildup classifications collapse to Neutral)
**Endpoints**:
- `GET /market/snapshot` (README §8.15) — `indices[]` and `per_index[].stocks[]`
- `GET /contributors/{index}` (README §8.16)
- `GET /oi/buildup` (README §8.12)
- `GET /buildup/symbols` (README §8.13) — downstream of `/oi/buildup`
**Discovered**: 2026-05-29 during Phase ε live QA.
**Frontend phases impacted**: ε (Markets Dashboard data), ζ (Index Contributors), partial visibility on OI Buildup classifications.

### Observed (2026-05-29 15:46 IST, against `192.168.5.61:8000`)

`/health` reports `ws_connected: true`, but `analytics.last_run_ts = 15:29:59 IST` — analytics last ran *at market close* and hasn't refreshed since. The raw tick feed (`/spot/timeseries`) is healthy (real 1-min OHLC bars showing NIFTY dropped ~1.36% intraday). The aggregation/reference layer is the problem.

| Endpoint | Working | Broken (zero on a live trading day) |
|---|---|---|
| `/market/snapshot.indices[*]` | `ltp` | `today_open`, `yesterday_close`, `change_pct` |
| `/market/snapshot.per_index[*].stocks[*]` | `ltp` | `today_open`, `yesterday_close`, `gap_pct`, `change_pct` |
| `/market/snapshot` top-level | — | `advances`, `declines` (both 0) |
| `/contributors/{index}` | `ltp`, `sector`, `weight`, `divisor` | `change_pct`, `index_points` |
| `/oi/buildup` per-contract | `open_price`, `close_price`, `trading_symbol`, `strike` | `price_change`, `open_oi`, `close_oi`, `oi_change` → every row classified `Neutral` |
| `/buildup/symbols` | 200; structure correct | all four bucket arrays empty (Neutral cascade from `/oi/buildup`) |

### Why
Without these fields populated, Markets Dashboard tiles show `0.00%` change despite real intraday moves, the 2×2 buildup grid is fully empty, Index Contributors will show 0 points everywhere, and Advances/Declines are stuck at 0.

### Proposed fix (backend)
1. After each session close, persist the close snapshot per token; expose as `yesterday_close` / `prev_close` on next session.
2. On first tick of the session per symbol, capture `today_open`.
3. Recompute `change_pct = (ltp - yesterday_close) / yesterday_close * 100` per tick or per analytics-job.
4. Capture `open_oi` (start-of-bucket OI) and `close_oi` (end-of-bucket OI) on the OI snapshot task — currently both are 0 on `/oi/buildup`.
5. Once 1–4 land, `/buildup/symbols` self-populates (it's a roll-up of non-Neutral `/oi/buildup` rows).

### What the frontend will do after delivery
Nothing — Phase ε already renders these fields verbatim. Tiles will color change% green/red, quadrants will populate with real symbols, Phase ζ will surface real `index_points`.

### Frontend fallback if not delivered
None — per `feedback_no_frontend_workarounds`, no client-side synthesis from `/spot/timeseries`. Dashboard ships with the current empty/zero state; spec-defined empty messages already render.

---

## Ticket dependencies → phase blocking

| Backend ticket | Frontend phase blocked | Status (2026-05-29) |
|---|---|---|
| 1 (`prev_close` on `/analytics/chain`) | γ — Option Chain LTP%Change | ✅ Resolved — Phase γ ready to ship |
| 2 (`bucket_minutes` on timeseries) | δ — PCR + Options Chart Time selector | ✅ Resolved — Phase δ ready to ship |
| 3 (new `/oi/trending`) | η — Trending OI screen | ✅ Resolved — Phase η ready to ship (Trending OI's spot overlay will follow Ticket 4 closure) |
| 4 (prior-bar reference fields) | ε / ζ data visibility | ✅ Mostly resolved — `/oi/buildup` + `/market/snapshot` (indices + per_index + a/d/u) + `/contributors/{index}` all populated; only `/buildup/symbols` roll-up remains empty |

## Out of scope for this batch (not tickets, just notes)

- **Bottom pagination `1|2|3|4|5` on OptionZ's Option Data screens** — meaning unconfirmed (could be saved layouts, date pages, etc.). To investigate at build time before deciding if it should be replicated.
- **"Direction" column in `/strategy/scan` result legs** (values like `0.00, 100.00, 200.00`) — meaning unclear from screenshot alone. To investigate at Phase θ by hitting the live endpoint and inspecting an actual response.
- **`/analytics/chain` IV / Greeks already cover OptionZ's CE/PE Delta and IV columns** — no backend ticket needed.
- **Writer-accumulation bands** — dropped from scope (not in OptionZ). Not a backend ticket.

## Handoff format

When backend delivers a ticket, update `INSTAOPTIONS_HANDOFF.md` to flip the corresponding phase from `⚠️ blocked` → `☐ todo`, and add a note linking back to this file. The frontend phase then proceeds.
