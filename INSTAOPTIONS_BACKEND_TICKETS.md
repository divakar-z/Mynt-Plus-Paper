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

## Ticket dependencies → phase blocking

| Backend ticket | Frontend phase blocked | If ticket slips |
|---|---|---|
| 1 (`prev_close` on `/analytics/chain`) | γ — Option Chain LTP%Change | Hide column; ship rest of chain screen |
| 2 (`bucket_minutes` on timeseries) | δ — PCR + Options Chart Time selector | Show selector disabled with "Coming soon" tooltip |
| 3 (new `/oi/trending`) | η — Trending OI screen | Phase η pauses; ship Phases ε, ζ, θ first |

## Out of scope for this batch (not tickets, just notes)

- **Bottom pagination `1|2|3|4|5` on OptionZ's Option Data screens** — meaning unconfirmed (could be saved layouts, date pages, etc.). To investigate at build time before deciding if it should be replicated.
- **"Direction" column in `/strategy/scan` result legs** (values like `0.00, 100.00, 200.00`) — meaning unclear from screenshot alone. To investigate at Phase θ by hitting the live endpoint and inspecting an actual response.
- **`/analytics/chain` IV / Greeks already cover OptionZ's CE/PE Delta and IV columns** — no backend ticket needed.
- **Writer-accumulation bands** — dropped from scope (not in OptionZ). Not a backend ticket.

## Handoff format

When backend delivers a ticket, update `INSTAOPTIONS_HANDOFF.md` to flip the corresponding phase from `⚠️ blocked` → `☐ todo`, and add a note linking back to this file. The frontend phase then proceeds.
