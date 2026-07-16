# StockScanner — Client Integration Spec

A self-contained brief for building a **read-only consumer UI** against the StockScanner backend, with four pages: Symbols, Scanners, Fundamentals, and Custom Scans. The consumer project should use **its own design system** — this document specifies behaviour, data, and API contracts only.

---

## 1. Quick start

The backend lives at `http://<host>:<port>` (FastAPI, single process). It already serves a complete admin app at `/` — but **the JSON API at `/api/v1/*` is what you'll consume.** Treat the admin app as out of scope.

### Endpoints you'll use

| Group | Base path |
|---|---|
| Symbols (universe + detail tabs) | `/api/v1/symbols/*` |
| Scanners (technical) | `/api/v1/scanners/*` |
| Fundamental screener + saved screens | `/api/v1/scans/fundamental*` |
| Custom predicate scanners | `/api/v1/scans/*` (run + saved) |

### Endpoints you'll NOT use

`/api/v1/jobs/*` (data ingestion triggers), `/api/v1/admin/api-keys/*` (key management), `/api/v1/setup/*` (first-run), `/api/v1/meta` (dashboard counts) — these are admin-only and not relevant for a consumer app.

---

## 2. Making the read endpoints public

The StockScanner backend currently requires `X-API-Key` on every `/api/v1/*` request. For a public consumer you have two options.

### Option A — Env flag (cleanest, recommended)

Add a `PUBLIC_READ_MODE=true` env var on the backend. Then in `app/api/deps.py`, modify `require_api_key`:

```python
def require_api_key(
    x_api_key: str | None = Header(default=None, alias="X-API-Key"),
    db: Session = Depends(get_db),
) -> models.ApiKey | None:
    settings = get_settings()
    if settings.public_read_mode:
        # Bypass auth for read endpoints. Return a synthetic "public" key.
        return None  # callers must handle None for rate-limiting/logging
    # ... existing auth code
```

And in `app/api/deps.py::require_admin`, keep the strict check — only READ endpoints become public.

Result: `GET /api/v1/scanners`, `GET /api/v1/symbols/...`, etc. work without any header. `POST /api/v1/jobs/update` still needs an admin key.

### Option B — Strip auth from specific routers

In `app/main.py`, mount fresh router instances without the `dependencies=[Depends(require_api_key)]`:

```python
# In app/api/symbols.py, change:
router = APIRouter(prefix="/symbols", dependencies=[Depends(require_api_key)])
# To:
router = APIRouter(prefix="/symbols")  # no auth
```

Same for `app/api/scanners.py` and the GET routes in `app/api/scans.py`. Leaves POST mutations (custom scans run / save / delete) requiring auth, which is reasonable since those write to the DB.

**Recommended split**: read endpoints (GET) → public; mutation endpoints (POST saved-screen save, POST custom-scan run) → public too if you trust the network, else gated.

### CORS for cross-origin consumers

If your consumer app is on a different origin (e.g. `your-app.com` calling `stockscanner.api.com`), add CORS middleware in `app/main.py`:

```python
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten to your consumer's domain in prod
    allow_credentials=False,
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["*"],
)
```

If you keep public mode same-origin only (consumer served by the same FastAPI), CORS is not needed.

---

## 3. Data model — what each thing is

### 3.1 Symbol

A tradeable NSE equity (e.g. `RELIANCE`, `BAJFINANCE`, `TCS`). Each Symbol has:
- `ticker` — the NSE code (e.g. `"RELIANCE"`)
- `y_symbol` — Yahoo-suffixed form (e.g. `"RELIANCE.NS"`) — useful for charting integrations
- `name`, `isin`, `series` (always `"EQ"` for equities), `is_active`
- `history_start`, `history_end` — date range of OHLCV we have

There are ~2,442 active EQ symbols at any time.

### 3.2 Scanner (technical)

A **named predicate** that filters the universe based on price/volume indicators. Examples:
- `RSI14_OVERSOLD` — "RSI(14) < 30 (oversold zone)"
- `MS10_NEGATIVE` — "Smoothed Rate of Change over 10 bars is negative"
- `MB_HIGH` — "Stock just made a new 22-day high"
- `MACD_BULL_CROSS` — "MACD line crossed above signal"

~163 such scanners exist, organised by `group_name` (Price / Volume / Technical / Candlestick) and `sub_group` (RSI / MACD / Bollinger Band / etc.). Each scanner runs nightly and stores **scan results** — the set of symbols matching that day.

### 3.3 Fundamental screener

A flexible filter over per-symbol fundamentals stored in `symbol_info` (sector, market cap, P/E, ROE, debt/equity, dividend yield, etc.). Users build queries from atomic filters:

```json
{
  "field": "pe_trailing",  "op": "<",  "value": 25
}
```

Combined as AND. ~35 fields available. The screener supports a **median-over-N-years** mode (set `years: 3` on a filter to compare against the median of the last 3 annual values rather than the latest snapshot).

### 3.4 Saved fundamental screens

Persistent named screens. User creates a filter set, gives it a name, saves it — later loads + runs it. Lives at `/api/v1/scans/fundamental/saved`.

### 3.5 Custom predicate scanner

User-authored technical scanner using the same predicate DSL the built-in ones use. Can be run inline (one-shot) or saved for reuse. Useful when none of the 163 built-ins match the user's exact criteria.

### 3.6 Predicate DSL (used by built-in scanners + custom scans)

A JSON tree representing a boolean expression. Three node kinds:

**Leaf comparison:**
```json
{ "left": <ref>, "op": <operator>, "right": <ref> }
```

where `<ref>` is one of:
- Literal: `{"value": 30}` or `{"value": [20, 80]}` (range form, for `between`)
- Indicator call: `{"indicator": "rsi", "period": 14}`
- Indicator with transforms: `{"indicator": "sma", "source": "volume", "period": 20, "scale": 2.0, "offset_bars": -1}`
  - `source` is the column the indicator operates on (defaults vary per indicator)
  - `scale` multiplies the resulting series (e.g. "2× SMA20 of volume")
  - `offset_bars` shifts (e.g. `-1` means "yesterday's value")

**Operators**: `<, <=, >, >=, ==, !=, between, crossed_above, crossed_below, is_true, is_false`

**Combinators:**
```json
{ "all":  [ <node>, <node>, … ] }     // AND
{ "any":  [ <node>, <node>, … ] }     // OR
{ "none": [ <node>, <node>, … ] }     // NOT (negate-AND)
```

**Worked example** — "RSI(14) crossed above 30 AND Volume > 2× SMA(Volume, 20) AND Close > SMA(Close, 200)":
```json
{
  "all": [
    { "left":  {"indicator": "rsi", "period": 14},
      "op":    "crossed_above",
      "right": {"value": 30} },
    { "left":  {"indicator": "volume"},
      "op":    ">",
      "right": {"indicator": "sma", "source": "volume", "period": 20, "scale": 2.0} },
    { "left":  {"indicator": "close"},
      "op":    ">",
      "right": {"indicator": "sma", "period": 200} }
  ]
}
```

### 3.7 Indicator vocabulary (frozen, ~57 names)

Indicators are organised by family. Common ones:

- **Raw price/volume**: `open, high, low, close, adjclose, volume`
- **Aggregations**: `rolling_max(col, lookback)`, `rolling_min(col, lookback)`, `bars_since(condition)`
- **Moving averages**: `sma(col, period)`, `ema(col, period)`, `wma(col, period)`, `vwap(anchor)`, `wsma`, `wema`
- **Oscillators**: `rsi(period)`, `cci(period)`, `mfi(period)`, `william_r(period)`, `stoch_k(k_period, smooth)`, `stoch_d(k_period, smooth, d_period)`, `roc(period)`, `momentum_score(lookback, smoothing)`
- **Bands**: `bollinger_upper/middle/lower(period, std)`, `bollinger_bandwidth`, `keltner_upper/lower(period, mult)`
- **Trend**: `macd_line/signal/hist(fast, slow, signal)`, `adx(period)`, `di_plus(period)`, `di_minus(period)`, `supertrend_line/dir(period, mult)`, `psar(step, max)`
- **Volatility**: `atr(period)`, `narrow_range(lookback)`, `beta(period, benchmark)`
- **Ichimoku**: `tenkan, kijun, senkou_a, senkou_b, chikou`
- **Candlestick patterns**: `cdl_doji, cdl_hammer, cdl_shooting_star, cdl_bullish_engulfing, cdl_bearish_engulfing, cdl_morning_star, cdl_evening_star, cdl_three_white_soldiers, cdl_three_black_crows, cdl_harami_bull, cdl_harami_bear`
- **Relative strength**: `relative_strength(period, benchmark='^NSEI')`

If the consumer app lets users write custom predicates, expose a dropdown of these names with their params.

The full machine-readable catalog — categories, per-indicator kind/params/defaults — is served by `GET /api/v1/indicators` (see §4.5). **Drive your scan-builder UI from that response**, not from a hardcoded copy of this list.

---

## 4. API reference

All endpoints return JSON. All errors follow:

```json
{ "error": "<code>", "message": "<human-readable>", "detail": { ... } }
```

with HTTP status 400 / 404 / 422 / 429 / 500 as appropriate.

### 4.1 Symbols

#### `GET /api/v1/symbols`

List the active universe (paginated).

**Query params**:
- `q` (optional) — full-text search on `ticker` or `name`
- `page` (default 1)
- `page_size` (default 50, max 10000)

**Response**:
```json
{
  "items": [
    { "ticker": "RELIANCE", "y_symbol": "RELIANCE.NS",
      "isin": "INE002A01018", "name": "RELIANCE INDUSTRIES LIMITED",
      "series": "EQ", "is_active": true,
      "history_start": "2000-01-03", "history_end": "2026-05-15" },
    ...
  ],
  "total": 2442, "page": 1, "page_size": 50
}
```

#### `GET /api/v1/symbols/{ticker}`

Single symbol's metadata. 404 if not found.

#### `GET /api/v1/symbols/{ticker}/ohlcv`

OHLCV history. Use for charts.

**Query params**:
- `from` (ISO date, optional) — earliest date
- `to` (ISO date, optional) — latest date
- `adjusted` (default `true`) — when true, the `close` field is adjusted for splits/dividends

**Response**:
```json
{
  "ticker": "RELIANCE",
  "adjusted": true,
  "bars": [
    { "date": "2026-05-15", "open": 1280.0, "high": 1290.0,
      "low": 1275.0, "close": 1287.4, "adjclose": 1287.4, "volume": 1000000 },
    ...
  ]
}
```

#### `GET /api/v1/symbols/{ticker}/technicals`

Current values of ~25 indicators (SMA 20/50/200, EMA 9/21, RSI 14, MACD, Bollinger Bands, ATR, SuperTrend, ADX, +/-DI, PSAR, ROC, VWAP, Stoch K/D, MFI 14, Williams %R 14, CCI 20).

**Response**:
```json
{
  "ticker": "RELIANCE",
  "as_of": "2026-05-15",
  "indicators": {
    "sma_20": 1248.0, "sma_50": 1210.0, "sma_200": 1180.0,
    "rsi_14": 62.3, "macd_line": 1.23, "macd_signal": 0.98,
    "bb_upper": 1320.0, "bb_lower": 1230.0,
    "supertrend_dir": 1, "atr_14": 18.4, ...
  }
}
```

Render as a grid of metric cards with interpretive badges ("overbought", "strong trend", etc.) based on standard thresholds.

#### `GET /api/v1/symbols/{ticker}/performance`

% returns over standard periods, plus optional vs-NIFTY relative.

**Response**:
```json
{
  "ticker": "RELIANCE",
  "as_of": "2026-05-15",
  "returns":  { "1D": 1.7, "1W": 5.2, "1M": 12.5, "3M": 18.0, "6M": 28.0,
                "1Y": 35.4, "2Y": 80.0, "5Y": 145.0, "10Y": 320.0, "MAX": 1200.0 },
  "relative": { "1D": 1.4, "1W": 4.8, ... }  // null if NIFTY data not loaded
}
```

#### `GET /api/v1/symbols/{ticker}/scanners`

Which built-in scanners match this stock today.

**Query params**: `date` (default `"latest"`)

**Response**: `string[]` — list of scanner codes (e.g. `["RSI14_OVERSOLD", "MACD_BEAR_CROSS"]`).

#### `GET /api/v1/symbols/{ticker}/info`

yfinance-enriched fundamentals (sector, industry, market cap, P/E, beta, dividend yield, ROE, etc.). 404 if symbol not enriched.

**Response**:
```json
{
  "ticker": "RELIANCE", "fetched_at": "2026-05-13T07:30:00+00:00",
  "sector": "Energy", "industry": "Oil & Gas Refining & Marketing",
  "long_name": "Reliance Industries Limited",
  "business_summary": "Reliance Industries Limited operates...",
  "market_cap": 18400101269504.0,
  "pe_trailing": 22.76, "pb_ratio": 2.1, "return_on_equity": 0.094,
  "dividend_yield": 0.003, "fifty_two_week_high": 1450.0, ...
}
```

#### `GET /api/v1/symbols/{ticker}/fundamental-score`

Composite 0–100 score across 6 dimensions.

**Response**:
```json
{
  "ticker": "RELIANCE",
  "valuation": 76.6, "growth": 20.8, "profitability": 21.6,
  "quality": 25.5, "solvency": 43.3, "efficiency": 18.9,
  "composite": 34.45,
  "notes": []
}
```

Render as horizontal progress bars (0–100). Color by threshold: 80+ green, 60–79 emerald, 40–59 amber, <40 rose.

#### `GET /api/v1/symbols/{ticker}/financials`

Quarterly / annual statements.

**Query**: `period` = `quarterly` | `annual`, `statement` = `income` | `balance` | `cashflow`

**Response**:
```json
{
  "ticker": "RELIANCE", "period_type": "quarterly", "statement": "income",
  "periods": ["2024-03-31", "2024-06-30", "2024-09-30", "2024-12-31", "2025-03-31"],
  "line_items": ["Total Revenue", "Operating Income", "Net Income", ...],
  "values": {
    "Total Revenue": {"2024-03-31": 1032310000000, ...},
    "Operating Income": {...},
    ...
  }
}
```

Render as a table with line items as rows, periods as columns. Values in INR raw — divide by 1e7 to display in Cr.

#### `GET /api/v1/symbols/{ticker}/peers`

Same-industry peers ordered by market cap.

**Query**: `limit` (default 10)

**Response**:
```json
{
  "ticker": "RELIANCE", "industry": "Oil & Gas Refining & Marketing", "sector": "Energy",
  "peers": [
    {"ticker": "ONGC", "name": "Oil & Natural Gas Corp", "market_cap": ...,
     "pe_trailing": 12.5, "sector": "Energy", "industry": "..."},
    ...
  ]
}
```

#### `GET /api/v1/symbols/{ticker}/news` and `/dividends` and `/holders` and `/deliveries` and `/announcements`

Standard list responses — see `/docs` OpenAPI for shapes. Holders and MF data are sparse for Indian stocks.

### 4.2 Scanners (technical)

#### `GET /api/v1/scanners`

List all built-in scanners.

**Query**: `group` (e.g. `"Technical"`), `sub_group` (e.g. `"RSI"`), `q` (search), `page`, `page_size` (max 2000)

**Response**:
```json
{
  "items": [
    { "code": "RSI14_OVERSOLD", "group_name": "Technical",
      "sub_group": "RSI", "display_name": "RSI(14) oversold",
      "description": "Stock is oversold — RSI(14) has dropped below 30...",
      "is_active": true },
    ...
  ],
  "total": 163, "page": 1, "page_size": 100
}
```

#### `GET /api/v1/scanners/{code}`

Scanner metadata + predicate JSON.

```json
{
  "code": "RSI14_OVERSOLD", "group_name": "Technical", "sub_group": "RSI",
  "display_name": "RSI(14) oversold", "description": "...",
  "is_active": true,
  "predicate": { "left": {"indicator":"rsi","period":14}, "op": "<", "right": {"value":30} }
}
```

#### `GET /api/v1/scanners/{code}/results?detail=true`

**Use this for the scanner-detail page.** Set `detail=true` to get computed indicator columns alongside the symbol list.

**Query**: `date` (`latest` or `YYYY-MM-DD`), `limit` (default 5000, max 10000), `offset`, `detail` (default false)

**Response (detail=true)**:
```json
{
  "code": "RSI14_OVERSOLD",
  "as_of": "2026-05-15",
  "total": 87,
  "columns": [
    { "key": "rsi", "label": "RSI(14)", "fmt": "raw",
      "description": "Relative Strength Index (14-bar) — measures momentum; <30 oversold, >70 overbought" },
    { "key": "close", "label": "Close", "fmt": "price",
      "description": "Adjusted closing price on the trade date" },
    { "key": "chg_pct", "label": "Chg %", "fmt": "pct",
      "description": "Daily % change from the previous trading day's close" }
  ],
  "matches": [
    { "ticker": "21STCENMGM", "name": "21ST CENTURY MGMT SERVICE",
      "values": {"rsi": 28.13, "close": 32.52, "chg_pct": -1.54} },
    ...
  ]
}
```

**Column-rendering rules**:
- `fmt: "price"` → format as currency (₹ XX.XX)
- `fmt: "pct"` → format as percentage (XX.XX %), color green when ≥ 0, red when < 0
- `fmt: "raw"` → 2 decimals
- `fmt: "int"` → integer with thousands separators
- `fmt: "ratio"` → 2 decimals

Column labels are **already parameterised**: a scanner with predicate `momentum_score(lookback=10)` returns label `"Momentum Score (ROC over 10 bars)"`. RSI variants return `"RSI(14)"` or `"RSI(21)"` depending on the scanner. **Use these labels verbatim** so the table matches the filter.

#### `GET /api/v1/scanners/{code}/results` (no detail)

Lightweight version — just `ticker + name + total`. Use when you only need a list.

#### `GET /api/v1/scanners/{code}/export?columns=visible|all`

Returns an `.xlsx` file (`Content-Disposition: attachment; filename=...`). `columns=all` adds every `symbol_info` field. Use for the Download button.

#### `GET /api/v1/scanners/{code}/explain/{ticker}`

Per-ticker scan explanation: returns the evaluated predicate tree, OHLCV bars, per-bar match mask, and per-bar indicator series so a client can render the "why did this stock match?" detail view (chart with matched bars highlighted + condition list with check/x). See §4.6 for the full response shape.

### 4.3 Fundamental Screener

#### `GET /api/v1/scans/fundamental/fields`

Catalog of 35 fields the screener supports.

**Response**:
```json
[
  { "key": "market_cap", "label": "Market Cap", "group": "Valuation",
    "dtype": "currency_inr",
    "description": "Total market value of outstanding shares" },
  { "key": "pe_trailing", "label": "P/E (TTM)", "group": "Valuation",
    "dtype": "number",
    "description": "Price / earnings, trailing twelve months" },
  { "key": "return_on_equity", "label": "ROE", "group": "Profitability",
    "dtype": "pct",
    "description": "Return on equity" },
  ...
]
```

`group` values: `"Categorical" | "Valuation" | "Profitability" | "Liquidity" | "Dividend" | "Price"` — for grouping the field dropdown in the filter builder.

`dtype` values:
- `"number"` — generic float
- `"pct"` — fraction (0.15 means 15%). UI should display as `15.0%` and accept percentage input from the user (`5` → `0.05`).
- `"currency_inr"` — raw INR amount. Display via the formatter in §6.
- `"string"` — categorical (sector, industry, etc.). Use with `in` / `not_in` / `==` operators.

#### `GET /api/v1/scans/fundamental/presets`

Curated preset templates (Quality / Value / Growth / Dividend / Magic Formula / etc.).

**Response**: array of `{id, name, description, filters, treat_null_as}`.

#### `POST /api/v1/scans/fundamental`

Run an ad-hoc screen.

**Body**:
```json
{
  "filters": [
    { "field": "revenue_growth", "op": ">=", "value": 0.10, "years": 3 },
    { "field": "pe_trailing", "op": "<", "value": 25 },
    { "field": "sector", "op": "in", "value": ["Energy", "Financial Services"] }
  ],
  "treat_null_as": "fail",
  "order_by": "market_cap",
  "order_dir": "desc",
  "limit": 100,
  "offset": 0
}
```

Operators by field type:

| Field dtype | Valid ops |
|---|---|
| `number` / `pct` / `currency_inr` | `<, <=, >, >=, ==, !=, between, is_null, is_not_null, min_years` |
| `string` | `==, !=, in, not_in, is_null, is_not_null` |

**`years` sidecar**: Optional integer 2–15. Only valid on fields in the multi-year-capable list (revenue_growth, earnings_growth, return_on_equity, return_on_assets, profit_margins, operating_margins, current_ratio, quick_ratio, debt_to_equity). When set, the comparison is against the **median over the last N years** computed from historical statements.

`treat_null_as`: `"fail"` excludes rows with NULL on the filtered field; `"pass"` includes them.

**Response**:
```json
{
  "total": 121,
  "returned": 100,
  "column_labels": [
    {"field": "revenue_growth", "label": "Revenue Growth (3y median)"},
    {"field": "pe_trailing", "label": "P/E (TTM)"}
  ],
  "matches": [
    { "ticker": "ITC", "name": "ITC LIMITED",
      "sector": "Consumer Defensive", "industry": "Tobacco",
      "market_cap": 3822740000000,
      "values": {
        "revenue_growth": 0.12,    // median over 3 years (because filter had years=3)
        "pe_trailing": 18.8,
        "close": 320.5, "chg_pct": -0.8, ...
      }
    },
    ...
  ]
}
```

The `column_labels` array tells you which column labels to use in the results table. If a filter has `years=N`, the corresponding column will be labelled `"<Field Label> (median over N years)"` — and `values[field]` will be the median, not the latest. **Use the backend-provided label verbatim**; don't synthesize your own.

#### `POST /api/v1/scans/fundamental/export`

Same body as `POST /scans/fundamental` + extra fields:
- `columns`: `"visible"` (filters' fields only) | `"all"` (every SymbolInfo field) | `"custom"`
- `custom_columns`: `list[str]` — required if `columns="custom"`. List of field keys to include.

Returns `.xlsx`.

#### Saved screens

- `POST /api/v1/scans/fundamental/saved` — body: `{name, filters, treat_null_as?, order_by?, order_dir?, limit?}` → saves and returns the row
- `GET /api/v1/scans/fundamental/saved` — list all saved
- `GET /api/v1/scans/fundamental/saved/{id}` — get one
- `POST /api/v1/scans/fundamental/saved/{id}/run` — run the saved filters fresh; returns same shape as `POST /scans/fundamental`
- `DELETE /api/v1/scans/fundamental/saved/{id}` — remove

### 4.4 Custom Predicate Scanners

For users who want to write their own technical scanners with the predicate DSL.

#### `POST /api/v1/scans/run`

Run a predicate inline (one-shot, not persisted).

**Body**: `{ "predicate": {...predicate JSON...}, "as_of": "latest" or "YYYY-MM-DD" }`

**Response**:
```json
{
  "as_of": "2026-05-15",
  "columns": [
    { "key": "rsi(14)",        "label": "RSI(14)" },
    { "key": "close",          "label": "Close" },
    { "key": "sma(close,200)", "label": "SMA(close, 200)" }
  ],
  "matches": [
    {
      "ticker": "RELIANCE",
      "name":   "RELIANCE INDUSTRIES LIMITED",
      "values": { "rsi(14)": 28.7, "close": 2845.3, "sma(close,200)": 2710.1 }
    },
    ...
  ]
}
```

**Columns are auto-derived from the predicate.** The server walks the predicate AST and emits one column per unique `IndicatorRef` it finds, in first-appearance order. `rsi(14)` shows up once even if you reference it on both sides of a Compare, and `sma(close, 20)` is distinct from `sma(close, 50)` (different params → different columns).

**Column key shape** (stable, machine-friendly): `"<name>"` for paramless indicators (`close`, `cdl_doji`), `"<name>(v1,v2,…)"` with params sorted alphabetically by key (`sma(close,20)`, `rsi(14)`). When `scale` ≠ 1.0 or `offset_bars` ≠ 0, those are appended: `sma(close,200)*2.0@-1`.

**Column labels** are human-friendly using the catalog labels and the catalog's param order (`SMA(close, 20)`, `RSI(14)`). Use them in table headers.

**Values** are scalar floats (or `null` when the indicator can't be computed — insufficient history, benchmark missing, etc.). Boolean indicators (candle patterns) return `0.0` or `1.0`. Format on display: use 2 decimals for prices/oscillators, integer for volume, `Yes`/`No` for candle patterns.

If you want columns the predicate doesn't reference (e.g. always show Market Cap), call `GET /symbols/{ticker}/technicals?indicators=...` per matched ticker as a follow-up fan-out.

#### `POST /api/v1/scans/saved`

Save a custom scanner for later.

**Body**: `{ "name": "my-rsi", "predicate": {...} }`

**Response**: `{id, name, predicate_json, created_by, created_at, last_run_at, run_count}`

#### `GET /api/v1/scans/saved` / `GET /api/v1/scans/saved/{id}` / `POST /api/v1/scans/saved/{id}/run` / `DELETE /api/v1/scans/saved/{id}`

Standard CRUD + run.

#### `GET /api/v1/scans/saved/{id}/explain/{ticker}`

Per-ticker scan explanation for a saved custom scanner. Same response shape as the built-in `GET /scanners/{code}/explain/{ticker}` — see §4.6.

### 4.5 Indicator Catalog

#### `GET /api/v1/indicators`

Returns the full catalog of indicators that the predicate DSL accepts. Drive your scan-builder UI from this — don't hardcode indicator lists or default params on the client. The server is the source of truth, and adding a new indicator only needs a server release.

**Response shape**:

```json
{
  "categories": [
    { "key": "price",          "label": "Price & Volume" },
    { "key": "moving_average", "label": "Moving Averages" },
    { "key": "oscillator",     "label": "Oscillators" },
    { "key": "band",           "label": "Bands & Channels" },
    { "key": "trend",          "label": "Trend" },
    { "key": "volatility",     "label": "Volatility" },
    { "key": "ichimoku",       "label": "Ichimoku Cloud" },
    { "key": "relative_strength", "label": "Relative Strength" },
    { "key": "aggregation",    "label": "Aggregations" },
    { "key": "candle_pattern", "label": "Candle Patterns" }
  ],
  "indicators": [
    {
      "name": "rsi",
      "label": "RSI",
      "category": "oscillator",
      "kind": "float",
      "description": "Relative Strength Index (0–100). Typical: >70 overbought, <30 oversold.",
      "params": [
        { "name": "period", "label": "Period", "type": "int",
          "default": 14, "min": 2, "max": 200 }
      ],
      "needs_benchmark": false
    },
    {
      "name": "cdl_doji",
      "label": "Doji",
      "category": "candle_pattern",
      "kind": "boolean",
      "description": "Open and close almost equal — indecision between buyers and sellers.",
      "params": []
    },
    {
      "name": "supertrend_dir",
      "label": "SuperTrend Direction",
      "category": "trend",
      "kind": "enum",
      "description": "SuperTrend regime: +1 = uptrend, −1 = downtrend.",
      "params": [
        { "name": "period", "type": "int", "default": 10, "min": 2, "max": 100 },
        { "name": "mult", "type": "float", "default": 3.0, "min": 0.5, "max": 10.0 }
      ],
      "enum_values": [
        { "value": 1, "label": "Uptrend" },
        { "value": -1, "label": "Downtrend" }
      ]
    }
  ]
}
```

**Field semantics**:

| Field | Meaning |
|---|---|
| `categories[]` | Display the indicator picker grouped by these, in this order. |
| `indicator.kind = "float"` | Numeric output. Right-hand side of predicate is a number OR another indicator. Show comparator (`<`, `<=`, `>`, `>=`, `==`, `!=`). |
| `indicator.kind = "boolean"` | Returns 0 or 1. Do **not** show a comparator. Show a single toggle ("Pattern formed" / "Pattern not formed"); emit `{indicator, op: "!=", value: 0}` or `op: "=="`. |
| `indicator.kind = "enum"` | Returns one of `enum_values`. Show a dropdown of `enum_values` (use the `label`, send the `value`); restrict comparator to `==` / `!=`. |
| `param.type = "int" \| "float"` | Numeric input; respect `min`/`max`. |
| `param.type = "string"` | Plain text input, or dropdown if `options` is present. |
| `param.type = "column"` | Dropdown of OHLCV column names (`options` is always supplied). |
| `needs_benchmark = true` | Indicator depends on a benchmark series (e.g. NIFTY). Server resolves the benchmark; client doesn't pass it. Just inform the user. |

**Predicate composition rules** (recap of §3.6 in light of `kind`).

> ⚠️ **Wire shape gotcha** — indicator params are **flat siblings** of `"indicator"`, NOT a nested `"params"` object. The server does not accept `{"indicator": "rsi", "params": {"period": 14}}`. Use `{"indicator": "rsi", "period": 14}`.

- `kind=float` ⇒ `{ "left": {"indicator": "rsi", "period": 14}, "op": "<", "right": {"value": 30} }`
- `kind=boolean` ⇒ `{ "left": {"indicator": "cdl_doji"}, "op": "!=", "right": {"value": 0} }`
- `kind=enum` ⇒ `{ "left": {"indicator": "supertrend_dir", "period": 10, "mult": 3.0}, "op": "==", "right": {"value": 1} }`

The `col` param has the alias `source` on the wire (both work). Per §3.6, two extra optional sibling keys exist for indicator refs: `scale` (multiplier, default 1.0) and `offset_bars` (shift, default 0 — `-1` means yesterday's value).

**Combinators** (composing multiple conditions) use the keys `"all"` / `"any"` / `"none"` — there is no `{"op":"and"}` form. See §3.6.

### 4.6 Scan Explanation

For one (scanner, ticker) pair: returns enough data to render a StockEdge-style detail view — the chart with matched bars highlighted, the predicate as a nested condition list with check/x marks, and per-bar indicator series for chart overlays. The history window scales with the predicate's lookback requirement (a 5-year breakout scan returns 5 years; a simple RSI scan returns ~250 bars).

Two endpoints, identical shape:

```
GET /api/v1/scanners/{code}/explain/{ticker}?date=latest        ← built-in scanners
GET /api/v1/scans/saved/{cid}/explain/{ticker}?date=latest      ← saved custom scanners
```

**Query params**: `date` (default `"latest"`, or `YYYY-MM-DD`).

**Response**: `application/json`

```json
{
  "scanner_name": "SuperTrend(10,3) bullish",
  "ticker": "ZOTA",
  "as_of": "2026-06-03",
  "window_bars": 283,
  "predicate": {
    "left":  { "indicator": "supertrend_dir", "period": 10, "mult": 3.0 },
    "op":    "==",
    "right": { "value": 1 }
  },
  "explanation": {
    "node_type": "leaf",
    "op": "==",
    "passed": true,
    "left":  {
      "label": "SuperTrend Direction(10, 3.0)",
      "value": 1.0,
      "display": "Uptrend",
      "indicator_kind": "enum"
    },
    "right": {
      "operand_type": "scalar",
      "label": "1",
      "value": 1.0,
      "display": "Uptrend"
    },
    "display": "SuperTrend Direction(10, 3.0): Uptrend ✓"
  },
  "bars": [
    { "date": "2026-04-21", "open": 1308, "high": 1323.5, "low": 1287, "close": 1299.3, "adjclose": 1299.3, "volume": 24223 }
  ],
  "matched":     [false, false, true, true, true],
  "indicators": {
    "supertrend_dir(3.0,10)":  [1.0, 1.0, 1.0, 1.0, 1.0]
  },
  "columns": [
    {
      "key":        "supertrend_dir(3.0,10)",
      "label":      "SuperTrend Direction(10, 3.0)",
      "kind":       "enum",
      "sub_panel":  false,
      "color_hint": null
    }
  ]
}
```

**Top-level fields**:

| Field | Meaning |
|---|---|
| `scanner_name` | Display name (built-in `display_name` or custom `name`). Use as page header. |
| `ticker` / `as_of` | The (ticker, date) the explanation is computed for. `as_of` is the effective trading day (nearest at-or-before the requested date). |
| `window_bars` | Number of bars in `bars` / `matched` / each `indicators` array. They are guaranteed equal length and aligned by index position. |
| `predicate` | Raw predicate JSON echoed back. Identical to `GET /scanners/{code}.predicate`. Useful for round-tripping into the scan-builder for editing. |
| `explanation` | Recursive tree (see below). Mirrors the predicate AST. |
| `bars` | OHLCV across the window. Same shape as `OhlcvBar` from `/symbols/{ticker}/ohlcv`. |
| `matched` | `boolean[]` — predicate truth at each bar. `matched[i]` corresponds to `bars[i]`. |
| `indicators` | `Record<string, (number\|null)[]>` — one entry per unique IndicatorRef in the predicate, keyed by `column_key(ref)` (e.g. `"rsi(14)"`, `"sma(close,200)"`). `null` is "not yet warmed up" or "computation failed". |
| `columns` | Metadata for each entry in `indicators`, in first-appearance order in the predicate. See "Column metadata" below for field-by-field semantics. |

**Column metadata** (each entry in `columns[]`):

| Field | Type | Meaning |
|---|---|---|
| `key` | `string` | Stable identifier matching a key in `indicators` (e.g. `"rsi(14)"`, `"sma(close,200)"`). |
| `label` | `string` | Human-readable label for chart legends / tooltips (e.g. `"RSI(14)"`, `"SMA(close, 200)"`). |
| `kind` | `"float" \| "boolean" \| "enum"` | Drives rendering choice. `float` → line/area trace. `boolean` → marker dots on matched bars. `enum` → background band (e.g. up/down regime). |
| `sub_panel` | `boolean` | **Server-derived chart placement hint.** `true` → render on an oscillator sub-panel with its own y-axis (RSI, MACD, CCI, Stoch, MFI, ROC, ADX, ±DI, ATR, momentum_score, narrow_range, beta, relative_strength, bollinger_bandwidth). `false` → overlay on the main price panel (MAs, Bollinger envelope, Keltner, Ichimoku, PSAR, SuperTrend line, VWAP, raw prices, aggregations). Use this directly instead of name-matching. |
| `color_hint` | `string \| null` | **Suggested hex color** for the trace (e.g. `"#F59E0B"` amber for oscillators, `"#3B82F6"` blue for MACD line, `"#10B981"` green for moving averages). `null` means the server has no opinion — pick from your default rotation or theme color (typical for `close`/raw price and candle patterns). Client may override. |

**The `explanation` tree** — discriminated union on `node_type`:

```ts
type ScanExplainNode = ScanExplainLeaf | ScanExplainGroup

interface ScanExplainGroup {
  node_type: 'group'
  kind: 'all' | 'any' | 'none'      // AND, OR, NOR
  passed: boolean                    // overall truth of this subtree
  children: ScanExplainNode[]
}

interface ScanExplainLeaf {
  node_type: 'leaf'
  op:  '<' | '<=' | '>' | '>=' | '==' | '!='
     | 'between' | 'crossed_above' | 'crossed_below'
     | 'is_true' | 'is_false'
  left:    ScanExplainLeftOperand
  right:   ScanExplainScalarOperand | ScanExplainRangeOperand | ScanExplainNoOperand
  passed:  boolean
  display: string                    // pre-rendered ("RSI(14) = 27.32 < 30 ✓")
}

interface ScanExplainLeftOperand {
  label:          string             // "RSI(14)", "Close", "SMA(close, 200)"
  value:          number | null      // scalar at as_of
  display:        string | null      // "27.32" / "Yes" / "Uptrend"
  indicator_kind: 'float' | 'boolean' | 'enum'
}

interface ScanExplainScalarOperand {
  operand_type: 'scalar'
  label:        string               // "30" or "SMA(close,200)"
  value:        number | null
  display:      string | null
}

interface ScanExplainRangeOperand {       // only for op = "between"
  operand_type: 'range'
  lo: number
  hi: number
  display: string                    // "[20, 30]"
}

interface ScanExplainNoOperand {          // only for op in {"is_true", "is_false"}
  operand_type: 'none'
}

interface ScanExplainColumn {
  key:        string                       // matches an indicators[] key
  label:      string                       // human-readable
  kind:       'float' | 'boolean' | 'enum'
  sub_panel:  boolean                      // true = oscillator sub-panel; false = price panel overlay
  color_hint: string | null                // suggested hex (e.g. "#F59E0B") or null
}
```

**Rendering rules per `left.indicator_kind`**:

- `float` — `display` is the value formatted to 2 decimals (e.g. `"27.32"`).
- `boolean` — `display` is `"Yes"` or `"No"`. The leaf's overall `display` string uses "formed" / "not formed" (e.g. `"Doji: formed ✓"`).
- `enum` — `display` is the catalog label (e.g. `"Uptrend"`, `"Downtrend"`). The leaf's overall `display` uses `"X: <label> ✓"` when the predicate's expected value matches.

The pre-rendered `display` string on each leaf is a convenience for simple list views; rich clients can compose their own text from `left`, `op`, `right`, `passed`.

**Operand variants — when each appears**:

| Predicate op | Right operand type |
|---|---|
| `<`, `<=`, `>`, `>=`, `==`, `!=`, `crossed_above`, `crossed_below` | `scalar` (literal OR another indicator) |
| `between` | `range` (`{lo, hi}` — never a single `value`) |
| `is_true`, `is_false` | `none` (no right side; check `left.value` + `passed`) |

**Error responses**: every non-2xx response uses the same envelope:

```json
{
  "error":   "<code>",
  "message": "<human-readable explanation>",
  "detail":  { /* optional, route-specific context */ }
}
```

| Status | `error` | When |
|---|---|---|
| 404 | `scanner_not_found` | built-in scanner code doesn't exist |
| 404 | `custom_not_found` | saved scanner id doesn't exist |
| 404 | `symbol_not_found` | ticker doesn't exist in the symbols table |
| 404 | `not_found` | unknown URL path (catch-all so clients always get the structured envelope, never FastAPI's default `{"detail": "Not Found"}`) |
| 409 | `no_data` | no prices loaded at all in the DB (rare; fresh install) |
| 409 | `no_prices` | the ticker exists but has no OHLCV in the requested window |
| 422 | `benchmark_required` | predicate uses `beta` or `relative_strength` but the benchmark series isn't loaded for explanation |
| 422 | `invalid_predicate` | for custom-saved scanners with malformed predicate JSON (rare) |
| 500 | `internal_error` | unexpected server-side exception. The `message` is a safe generic ("An unexpected error occurred. Please try again."); the full trace is logged server-side, not leaked to the client. Treat as transient — show a retry option in the UI. |

**Performance note**: each call does one `evaluate()` of the predicate over the loaded window, plus per-indicator series resolution from a warm cache. Typical cost: 20–60 ms for a 250-bar window with 1–3 indicators. Don't fan this out across thousands of tickers without batching — call it per click, not per row.

---

## 5. Page specs (behaviour, not visual design)

Four pages. Design system is up to your consumer project — use your own tokens, components, motion, typography. The specs below describe data flows and user interactions.

### 5.1 Symbols

#### `/symbols` — Search + list

- Search box (debounce 200 ms) → calls `GET /symbols?q={input}`. Show top 20 matches.
- Each result: ticker, name. Click → navigate to `/symbols/{ticker}`.
- Empty state: a hint sentence ("Type to find a stock by ticker or name").

#### `/symbols/{ticker}` — Detail with tabs

Header:
- Big ticker + name + exchange
- Latest price (from last OHLCV bar)
- Day change as `± abs (▲/▼ pct%)` colored green/red
- As-of timestamp
- (Optional) badge `"N scanners"` linking down to the Scans tab — value comes from `GET /symbols/{ticker}/scanners`

Tabs (active set for your consumer):
1. **Prices** — last N (e.g. 90) OHLCV bars in a sortable table. CSV export optional. Data: `GET /symbols/{ticker}/ohlcv`.
2. **Chart** — Plotly or your charting lib of choice. Candlestick + volume sub-chart. Optional overlays (SMA / EMA / Bollinger / SuperTrend) computed client-side from the OHLCV series. Optional sub-charts (RSI / MACD / Stochastic). Timeframe selector (1W, 1M, 3M, 6M, 1Y, 2Y, 5Y, 10Y, All).
3. **Scans** — list of scanner codes that match today, grouped by `group_name`. Click code → navigate to `/scanners/{code}`. Data: `GET /symbols/{ticker}/scanners`.
4. **Technicals** — grid of 25+ live indicator values from `GET /symbols/{ticker}/technicals`. Interpretive badges per indicator based on standard thresholds (RSI<30 → "oversold", ADX>25 → "strong trend", close>sma_200 → "above 200-DMA", etc.).
5. **Performance** — `GET /symbols/{ticker}/performance`. Table of % returns over standard periods. If `relative` is non-null, add a "vs NIFTY" column. Small inline bar chart of the returns.
6. **Fundamental** — `GET /symbols/{ticker}/info`. Render as a metric grid (sector, industry, market cap, P/E, P/B, EPS, ROE, dividend yield, beta, etc.). Use the currency / percentage formatters in §6. Also: `GET /symbols/{ticker}/fundamental-score` → render 6 progress bars (Valuation / Growth / Profitability / Quality / Solvency / Efficiency) with composite shown prominently.
7. **Financials** — `GET /symbols/{ticker}/financials`. Sub-tabs Income / Balance / Cash Flow × Quarterly / Annual. Table with line items as rows, periods as columns.
8. **Peers** — `GET /symbols/{ticker}/peers`. Sortable table; each row links to that peer's detail page.
9. **Holders / MF Holding / News / Dividends / Splits** — straightforward list rendering of the respective endpoints. Use sparingly — Indian-stock data here is patchy.
10. **Deliveries** — `GET /symbols/{ticker}/deliveries`. Table of date / deliverable qty / delivery %, sortable. Optional sparkline of delivery % over time.

Loading: each tab has its own query; show a skeleton during load. Use a library like TanStack Query (or your project's equivalent) for caching and request dedup.

### 5.2 Scanners

#### `/scanners` — List

Sidebar group facets:
- "All" + count
- One entry per `group_name` (Price / Volume / Technical / Candlestick) with count
- Click filters the main table

Main: TanStack-Table-style sortable, searchable. Columns:
- Group (badge)
- Sub-group
- Display name
- Code (monospace, dimmer)

Row click → `/scanners/{code}`. Data: `GET /scanners?page_size=2000` (small enough to fetch once and filter client-side).

#### `/scanners/{code}` — Detail

Header:
- Display name + sub-group breadcrumb
- Description block ("Stock is oversold — RSI(14) has dropped below 30...")
- Collapsible "view technical predicate" expanding to the predicate JSON pretty-printed
- "Download" button → opens a small modal: choose `visible` or `all` columns → calls `GET /scanners/{code}/export?columns=...` → triggers browser download

Results table:
- Sortable on every column
- Sticky header (clickable arrows for sort direction)
- Each column header has an **info icon** with a tooltip showing `columns[i].description` from the API
- Row click → navigate to `/symbols/{ticker}`
- Footer: "Showing X of Y matches" (X = `matches.length`, Y = `total`)

Data: `GET /scanners/{code}/results?detail=true&limit=5000`. Use the `columns` array verbatim — labels, fmt, descriptions are all server-provided so they always match the filter that produced each row.

**Pagination**: typically not needed since default limit is 5000 and most scanners match <500 stocks. If a scanner exceeds 5000, the `total` field will be higher than `matches.length` — show "Increase limit or refine" hint.

### 5.3 Fundamentals

#### `/fundamental`

Top section — **Presets**: chips from `GET /scans/fundamental/presets`. Clicking a chip loads its filters into the builder.

Saved screens section: chips from `GET /scans/fundamental/saved`. Clicking loads, deleting calls `DELETE /scans/fundamental/saved/{id}`.

Filter builder:
- Repeating rows: `[Field dropdown] [Op dropdown] [Value input(s)] [yrs input] [✕ remove]`
- Field dropdown grouped by `group` (Categorical / Valuation / Profitability / etc.) using `dtype` to drive op options:
  - string fields → `==, !=, in, not_in, is_null, is_not_null`
  - numeric fields → `<, <=, >, >=, ==, !=, between, is_null, is_not_null` + (if in multi-year list) `min_years`
- Value input adapts to op:
  - `between` → two inputs
  - `in`/`not_in` → comma-separated text
  - `is_null`/`is_not_null` → none
  - `min_years` → only the years input
- For percentage fields, suffix the input with `%` and convert before send (`5` → `0.05`)
- "Years" sidecar input (40–60 px wide) appears for multi-year-capable fields with comparison ops; tooltip: "Optional. Compares against the median of the past N years from annual statements."

Below the builder: `Missing data: ( ) Exclude ( ) Include` radio (`treat_null_as`). Sort by + direction + limit selects.

Actions:
- **[Run scan]** → `POST /scans/fundamental` → results table appears below
- **[Save as...]** → modal asks for name → `POST /scans/fundamental/saved`
- **[Download]** → modal: Visible / All / Custom column selection → `POST /scans/fundamental/export`

Results table:
- Columns derived from `response.column_labels` (use labels verbatim — they include "(median over N years)" suffix when applicable)
- Standard columns always present: Ticker, Name, Sector, Industry, Market Cap (Cr)
- Filter-referenced fields included in `values` and shown as additional columns
- Sortable on every column
- Click row → navigate to `/symbols/{ticker}`
- Header: `{returned} of {total} matches`

### 5.4 Custom Scans

#### `/custom-scans`

List of saved custom scanners from `GET /scans/saved`. Each card:
- Name
- Created at (IST timestamp)
- Run count + Last run
- Actions: **Run**, **Edit**, **Delete**

**[New custom scan]** button → opens the scan builder.

#### The scan builder

The builder is a **structured form**, not a JSON editor. On mount, fetch `GET /api/v1/indicators` (cache for the session) and use it to drive every input.

A single condition row has the shape **`[indicator-A] [op] [indicator-B | value]`**, where the controls shown for each slot depend on the chosen indicator's `kind`:

**Left side — indicator picker**:
- Single combobox grouped by `categories` (use the order from the API response). Filter by typing.
- After selecting an indicator, render a small inline params panel — one input per entry in `params`:
  - `type=int` / `type=float` → numeric input bounded by `min` / `max`, prefilled with `default`.
  - `type=string` with `options` → dropdown of options.
  - `type=string` without `options` → free text.
  - `type=column` → dropdown of `options` (always `[open, high, low, close, adjclose, volume]`).
- If `needs_benchmark = true`, show a quiet hint "Compared against benchmark (NIFTY)" — the user submits no benchmark value.

**Operator + right side — varies by `kind` of the left indicator**:

| `kind` | UI | Predicate emitted |
|---|---|---|
| `float` | Operator dropdown (`<`, `<=`, `>`, `>=`, `==`, `!=`, plus `crossed_above` / `crossed_below` for advanced users) + a two-way toggle "**Value** / **Indicator**". Value → number input. Indicator → another indicator picker (same component, recursively, with its own params). | `{ left: {indicator: "rsi", period: 14}, op: "<", right: {value: 30} }` |
| `boolean` | **Hide** the operator dropdown and the right-side input. Show a single radio/segmented control: "Pattern formed" / "Pattern not formed". | `{ left: {indicator: "cdl_doji"}, op: "!=", right: {value: 0} }` for formed; `op: "=="` for not formed |
| `enum` | Operator restricted to `==` / `!=`. Right side is a dropdown built from `enum_values` (display `label`, submit `value`). | `{ left: {indicator: "supertrend_dir", period: 10, mult: 3.0}, op: "==", right: {value: 1} }` |

This means **a user selecting "Doji" sees no comparator and no value input** — just one toggle. Same for every other candle pattern.

> ⚠️ Indicator params are emitted as **flat sibling keys** of `"indicator"`, not as a nested `"params"` object. `{"indicator": "rsi", "period": 14}` ✅ — `{"indicator": "rsi", "params": {"period": 14}}` ❌ (server returns 422).

Above the rows: **Match: All (AND) / Any (OR)** toggle. Below: **+ Add condition** and **+ Add group** (groups are nested AND/OR clauses). Conditions and groups compose into the `{all: [...]}` / `{any: [...]}` / `{none: [...]}` shapes per §3.6 — there is no `{op: "and"}` form. A two-row AND-builder emits `{ "all": [ <row1>, <row2> ] }`. A nested OR-group inside an AND-builder emits `{ "all": [ <row1>, { "any": [ <row2a>, <row2b> ] } ] }`.

Actions:
- **[Run inline]** → `POST /api/v1/scans/run` → results table.
- **[Preview JSON]** → modal showing the generated predicate (useful for debugging / power users).
- **[Save]** → modal asks for name → `POST /api/v1/scans/saved`.

Result table — **driven by `response.columns` + `response.matches[].values`**. Build table headers from `columns[].label` (in the response order) and rows from `matches[]`. Each cell is `match.values[column.key]`; render `null` as "—". Columns are auto-derived from the predicate's indicator references, so a "RSI(14) < 30 AND Close > SMA(close, 200)" scan yields `RSI(14) | Close | SMA(close, 200)` headers — exactly the indicators the user just picked in the builder.

If you want extra columns the predicate doesn't reference (e.g. always show Market Cap, Sector), fan out to `GET /api/v1/symbols/{ticker}/technicals?indicators=...` per matched ticker (cap at ~25 rows).

Custom scan detail (`/custom-scans/{id}`):
- Reload the saved predicate JSON, decode it back into the structured builder UI (use the same `/indicators` catalog to figure out which form controls to show).
- **[Run]** button → `POST /scans/saved/{id}/run` → same ticker+name results table.
- Clicking a result row → `/symbols/{ticker}`.

> Power-user escape hatch (optional): a "View raw JSON" toggle on the builder that swaps the structured form for a Monaco editor. Server still validates either way (422 on unknown indicator / op).

### 5.5 Scan Explanation View

A drill-in page that opens when the user clicks a row in any scanner's results table (built-in or saved custom). Backed by `GET /scanners/{code}/explain/{ticker}` (or `/scans/saved/{cid}/explain/{ticker}`). The goal is StockEdge-style transparency: show the user exactly why this stock matched.

#### Route

- `/scanners/{code}/explain/{ticker}` — built-in scanner detail per ticker
- `/custom-scans/{id}/explain/{ticker}` — saved custom scanner detail per ticker

The route must carry both pieces (scanner + ticker), so navigating back/forward from results works correctly. Pass `?date=YYYY-MM-DD` to show the explanation for a historical date.

#### Layout (three stacked sections)

**1. Header** (compact)
- Breadcrumb: `Scanner > {scanner_name} > {ticker}`
- Symbol info chip: `{ticker} • {company name}` — fetch via `GET /symbols/{ticker}` if not cached
- As-of date right-aligned: `as of {as_of}`
- Back arrow → previous scanner-results page (use browser history)

**2. Predicate evaluation panel** (the "why")

Render `response.explanation` as a nested condition tree.

- For `node_type === 'group'`:
  - Display the kind as a header pill: **ALL of** (kind=all), **ANY of** (kind=any), **NONE of** (kind=none)
  - Show a pass/fail badge to the right of the pill (✓ green / ✗ red) driven by `passed`
  - Indent the `children[]` one level
- For `node_type === 'leaf'`:
  - Single-line: `[checkbox-style icon based on passed] {display}` — the server-pre-rendered `display` is usually enough
  - On hover/expand: show the raw `op`, `left.value`, `right.value` (or `right.lo/hi` / "—" for the three operand types) as a small monospace label
  - Use `left.indicator_kind` to drive coloring or icons if desired (e.g. candle icon for `boolean`, trending arrow for `enum`)

Example rendering:

```
[✓] ALL of
   [✓] RSI(14) = 27.32 < 30 ✓
   [✓] ANY of
       [✗] SMA(close, 50) crossed above SMA(close, 200) ✗
       [✓] Volume = 2,500,000 > 1,000,000 ✓
```

Add a "View raw predicate JSON" toggle at the bottom — shows `response.predicate` for power users.

**3. Chart with overlays + matched-bar shading**

Build one chart (Plotly candlestick or equivalent) from `response.bars`. On top, render:

- **Matched-bar shading** — use `response.matched` to draw a semi-transparent vertical band (yellow/amber, ~15% opacity) on each bar where `matched[i] === true`. This is the most important visualisation — it shows "the scanner would have fired on these bars." Implement as a Plotly `shape` rectangle per contiguous run of true bars, or as marker dots on a secondary scatter trace.
- **Per-indicator overlays** — for each entry in `response.columns`:
  - `kind === 'float'`: line trace on the main panel if it's a price-scale indicator (SMA, EMA, Bollinger, SuperTrend Line, VWAP), or on a sub-panel if it's an oscillator (RSI, MACD, Stoch). Heuristic: indicators whose label starts with one of `SMA, EMA, WMA, VWAP, WSMA, WEMA, Bollinger, Keltner, SuperTrend, PSAR, Tenkan, Kijun, Senkou, Chikou` → main panel. Everything else (RSI, MACD, ADX, ATR, ROC, Williams %R, Stoch, CCI, MFI, Momentum) → sub-panel.
  - `kind === 'enum'`: render as a colored background band on the main panel — `supertrend_dir === 1` (Uptrend) → green tint, `=== -1` (Downtrend) → red tint. This complements the matched-bar shading and gives regime context.
  - `kind === 'boolean'`: render as marker dots on the matched bars only (candle pattern locations). Use the indicator's catalog `label` for the marker tooltip.

Data feed for each trace is just `bars` (x-axis = dates) + `indicators[column.key]` (y-axis = values; `null` becomes a gap in the line). All arrays are pre-aligned, so no client-side resampling.

#### Behaviour

- Date picker top-right of the chart — calling the same endpoint with `?date=YYYY-MM-DD` re-fetches the explanation as of that historical date. Useful for backtesting "would this scanner have fired on March 15?"
- Sticky tooltip at the cursor: shows close, all overlay indicator values, and `matched` (Yes/No) for the hovered bar.
- **No "Back to scanner" button — use the breadcrumb and browser history.** This avoids state coupling.

#### Errors

- 404 `symbol_not_found` → "We don't have data for this ticker." (rare from the scanner row click; usually means the symbol was removed since the scan was run)
- 409 `no_prices` → "No price history available for {ticker} in the required window." Suggest checking the ticker's price history elsewhere.
- 422 `benchmark_required` → "This scanner depends on a benchmark series we don't compute here yet." Hide the chart explanation, show the predicate text only as a fallback.

#### Performance

The endpoint typically responds in 20–60 ms. Cache per (scanner, ticker, as_of) using a query library — the response is deterministic. **Don't pre-fetch** the explanation for every row in a 1,000-stock scanner results table — that's 1,000 calls and ~60s of compute. Lazy-fetch on click only.

#### Navigation context

When the user clicks a row in `/scanners/{code}` or `/custom-scans/{id}` results, navigate to the explain route preserving the scanner identity. Don't navigate to bare `/symbols/{ticker}` — that drops the scanner context and the user can't see the explanation.

---

## 6. Formatting conventions

### Currency (INR)

Raw values are in INR. Use this helper:

```ts
function formatCurrencyINR(value: number | null): string {
  if (value == null) return '—'
  const crore = value / 1e7
  if (crore >= 1e5) return `${(crore / 1e5).toLocaleString('en-IN', { maximumFractionDigits: 2 })}L Cr`
  if (crore >= 1)   return `${crore.toLocaleString('en-IN', { maximumFractionDigits: 0 })} Cr`
  return `₹${value.toLocaleString('en-IN')}`
}
```

- 1 crore = 1e7
- 1 lakh crore = 1e5 Cr = 1e12 INR
- Indian-comma format (`1,39,615` not `139,615`)

### Percentages

API returns fractions (`0.15` means 15%). Display: `(value * 100).toFixed(2) + '%'`. Color: green when `>= 0`, red when `< 0`. For YoY growth and chg %, prefix with `+` when positive.

### Dates

Backend stores naive UTC; serializes without `Z` suffix. JavaScript's `new Date(iso)` then treats them as **local time**, which is wrong. Always parse as UTC and format in IST:

```ts
const IST = 'Asia/Kolkata'

function parseBackendDate(s: string): Date {
  const hasTz = /Z|[+-]\d{2}:?\d{2}$/.test(s)
  if (/^\d{4}-\d{2}-\d{2}([ T].*)?$/.test(s) && !hasTz) {
    return new Date(s.replace(' ', 'T') + 'Z')
  }
  return new Date(s)
}

function formatDateTime(s: string | null | undefined): string {
  if (!s) return '—'
  return parseBackendDate(s).toLocaleString('en-IN', {
    timeZone: IST, year: 'numeric', month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}
```

### Indicator values (`fmt`-driven)

The scanner-detail API gives each column a `fmt` field. Render accordingly:

```ts
function formatColumn(value: number | null, fmt: string): {text: string, className?: string} {
  if (value == null) return { text: '—', className: 'text-muted' }
  switch (fmt) {
    case 'price': return { text: value.toLocaleString('en-IN', {minimumFractionDigits:2, maximumFractionDigits:2}) }
    case 'pct':   return {
      text: `${value >= 0 ? '+' : ''}${value.toFixed(2)}%`,
      className: value >= 0 ? 'text-positive' : 'text-negative'
    }
    case 'ratio': return { text: value.toFixed(2) }
    case 'int':   return { text: Math.round(value).toLocaleString('en-IN') }
    default:      return { text: value.toFixed(2) }
  }
}
```

---

## 7. Integration patterns

### Querying

Use a query library with caching (TanStack Query, SWR, RTK Query, etc.). Recommended cache config:

- Symbol metadata (`/symbols/{t}`) — staleTime 5 min
- OHLCV (`/symbols/{t}/ohlcv`) — staleTime 5 min, but invalidate after market close
- Technicals / Performance / Fundamental Info / Score — staleTime 2 min
- Scanner list (`/scanners`) — staleTime 30 min (rarely changes)
- Scanner results (`/scanners/{c}/results`) — staleTime 60 s
- Fundamental presets / fields — staleTime 1 hour (these are essentially static)

### Error handling

All errors come back as `{error, message, detail}` with HTTP status. Translate to user-facing toast / inline message:

- 401 → only happens if you forgot to remove the auth dep; bail
- 404 → "Stock not found" / "Scanner not found"
- 422 → "Invalid input — {message}"
- 429 → "Rate limit exceeded — try again in a few seconds"
- 5xx → "Backend error — please retry"

### File downloads

For Excel exports, use a blob fetch:

```ts
async function downloadXlsx(url: string, body?: object): Promise<void> {
  const r = await fetch(url, body
    ? { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(body) }
    : { method: 'GET' }
  )
  if (!r.ok) throw new Error(`HTTP ${r.status}`)
  const blob = await r.blob()
  const link = document.createElement('a')
  link.href = URL.createObjectURL(blob)
  const cd = r.headers.get('content-disposition') ?? ''
  const m = /filename="?([^"]+)"?/.exec(cd)
  link.download = m?.[1] ?? 'export.xlsx'
  link.click()
  URL.revokeObjectURL(link.href)
}
```

### Rate limits

If `PUBLIC_READ_MODE` is on, no per-key rate limit applies. Default behaviour: token bucket per key (60 req/min). Add a global rate-limit middleware (e.g. `slowapi`) if exposing publicly to the internet.

---

## 8. Edge cases and known limitations

- **Holders / MF Holding**: yfinance returns empty data for ~95% of Indian stocks. Render an "Insufficient data" state, not empty rows.
- **PEG Ratio**: only ~45% coverage even after our compute-pass backfill. Many tickers will show `—`.
- **News**: yfinance news skews US-centric. Some tickers have 0 entries.
- **`as_of` consistency**: scanner results store the date the predicate evaluated true; the detail endpoint computes column values **at that date**, not "now." So if you query a historical date the values are historically accurate.
- **`^NSEI` benchmark**: filtered out of every EQ scan, but used internally by `relative_strength` and the performance vs-NIFTY relative.
- **Custom scan result columns are predicate-derived**: `POST /scans/run` and `POST /scans/saved/{id}/run` return one column per unique `IndicatorRef` in the predicate (auto-extracted from the AST). For columns the predicate doesn't reference, fan out to `GET /symbols/{ticker}/technicals?indicators=...` per matched ticker (~25 row cap). The built-in scanners (`GET /scanners/{code}/results?detail=true`) emit columns from a hand-curated profile instead, which can include extras like price/volume/sector that the predicate alone wouldn't.

---

## 9. Example integration snippets

### React + TanStack Query: load + display a scanner detail page

```tsx
import { useQuery } from '@tanstack/react-query'

interface ScanResultsDetail {
  code: string
  as_of: string
  total: number
  columns: { key: string, label: string, fmt: string, description: string }[]
  matches: { ticker: string, name: string, values: Record<string, number | null> }[]
}

const useScannerDetail = (code: string) =>
  useQuery<ScanResultsDetail>({
    queryKey: ['scanner-detail', code],
    queryFn: async () => {
      const r = await fetch(`/api/v1/scanners/${code}/results?detail=true&limit=5000`)
      if (!r.ok) throw new Error(`HTTP ${r.status}`)
      return r.json()
    },
    staleTime: 60_000,
  })

function ScannerDetail({ code }: { code: string }) {
  const { data, isLoading } = useScannerDetail(code)
  if (isLoading) return <Spinner />
  if (!data) return null
  return (
    <Table>
      <thead>
        <tr>
          <th>Ticker</th><th>Name</th>
          {data.columns.map(c => <th key={c.key} title={c.description}>{c.label}</th>)}
        </tr>
      </thead>
      <tbody>
        {data.matches.map(row => (
          <tr key={row.ticker}>
            <td>{row.ticker}</td><td>{row.name}</td>
            {data.columns.map(c => (
              <td key={c.key}>{formatColumn(row.values[c.key], c.fmt).text}</td>
            ))}
          </tr>
        ))}
      </tbody>
    </Table>
  )
}
```

### React: run a fundamental screen

```tsx
async function runFundamental(filters: FundamentalFilter[]) {
  const r = await fetch('/api/v1/scans/fundamental', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filters,
      treat_null_as: 'fail',
      order_by: 'market_cap',
      order_dir: 'desc',
      limit: 100,
    }),
  })
  return r.json()  // { total, returned, column_labels, matches }
}

// Buffett-style preset
const buffett = await runFundamental([
  { field: 'revenue_growth', op: '>=', value: 0.10, years: 3 },
  { field: 'pe_trailing',    op: '<',  value: 25 },
  { field: 'peg_ratio',      op: '<',  value: 2 },
  { field: 'return_on_equity', op: '>=', value: 0.05, years: 3 },
  { field: 'quick_ratio',    op: '>',  value: 1.5 },
])
console.log(`${buffett.total} stocks pass`)
```

### Run a custom predicate inline

```ts
const result = await fetch('/api/v1/scans/run', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    predicate: {
      all: [
        { left: { indicator: 'rsi', period: 14 }, op: 'crossed_above', right: { value: 30 } },
        { left: { indicator: 'volume' }, op: '>',
          right: { indicator: 'sma', source: 'volume', period: 20, scale: 2.0 } }
      ]
    },
    as_of: 'latest',
  }),
}).then(r => r.json())
// → response shape:
// {
//   as_of: '2026-05-15',
//   columns: [
//     { key: 'rsi(14)',            label: 'RSI(14)' },
//     { key: 'volume',             label: 'Volume' },
//     { key: 'sma(volume,20)*2.0', label: 'SMA(volume, 20) × 2.0' }
//   ],
//   matches: [
//     { ticker, name, values: { 'rsi(14)': 31.2, volume: 12345, 'sma(volume,20)*2.0': 6800.5 } },
//     ...
//   ]
// }
//
// Build the result table header from `response.columns` (Ticker | Name | …columns).
// Each cell value is `match.values[column.key]`; treat null as "—".
```

---

## 10. Checklist for the consumer project

- [ ] Configure backend's `PUBLIC_READ_MODE` (or strip auth from the 3 relevant routers)
- [ ] CORS middleware if cross-origin
- [ ] Implement the four pages: `/symbols`, `/scanners`, `/fundamental`, `/custom-scans`
- [ ] Build the formatters in §6 (currency / percentage / date / column)
- [ ] Wire each tab on the Symbol detail page to its endpoint
- [ ] Make all scanner column labels and descriptions render verbatim from the API response (never synthesize labels client-side)
- [ ] Make fundamental column labels render from `column_labels` in the response (so multi-year median labels show correctly)
- [ ] Add a chart implementation (Plotly / Recharts / Highcharts / your choice) — use the OHLCV endpoint as the data source
- [ ] Add Excel download UX on both scanner detail and fundamental screener
- [ ] Add empty/error states everywhere
- [ ] Apply your own design system — don't copy the StockScanner admin's Linear styling; use your project's tokens, components, motion, typography

This is the complete contract. Nothing else is needed from the StockScanner side — the backend is a sealed read-only data service for your consumer.
