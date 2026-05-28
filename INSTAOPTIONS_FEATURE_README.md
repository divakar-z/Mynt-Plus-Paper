# InstaOptions Analytics — Build Guide (Mynt Plus Web edition)

> **Agent directive.** This is the self-contained build spec for the InstaOptions Analytics module inside the existing Mynt Plus Web Flutter app. Read sections 0–7 in full before writing any code. Then build the phases in the order in section 14. Every concrete file path, colour token, and class name below is grounded in the real codebase as of 2026-05-28. **Order placement / strategy hand-off is intentionally deferred — see section 3.** Buttons and chips render visually only; tap is a no-op or a "coming soon" toast until a later sprint wires them up.

---

## 0. What you are building

A new standalone section called **InstaOptions Analytics** inside the existing Mynt Plus Web app. It is reached from the main navigation drawer under the Options group. The section contains nine read-only screens that consume the OI Data API (default base URL `http://192.168.5.61:8000`, configurable via `Preferences`).

### 0.1 The nine sub-screens

The module is mounted as a **single route** (`/insta-options`) that opens a right-panel shell with an internal side-rail. The side-rail switches between the nine sub-views below — there is no per-screen route in v1.

| # | Sub-screen | Side-rail key | One-liner |
|---|---|---|---|
| 1 | Markets Dashboard | `markets` (default landing) | Cross-symbol futures buildup, advances/declines, index summary |
| 2 | Index Contributors | `contributors` | Per-index constituent contribution to today's points |
| 3 | Option Chain | `chain` | Strike-by-strike chain with Greeks |
| 4 | OI Statistics | `oiStats` | Cumulative + per-strike OI bars |
| 5 | Trending OI | `trending` | Intraday OI sentiment + cumulative chart + bucket table |
| 6 | PCR Ratio | `pcr` | Chain-level PCR over time |
| 7 | Per-Strike Options Chart | `strike` | Per-strike CE & PE LTP-vs-OI charts |
| 8 | OI Buildup | `buildup` | Per-contract classification table |
| 9 | Find Strategy | `findStrategy` | Strategy scanner |

### 0.2 In / out of scope

In scope: read-only analytics, in-memory basket assembly (legs accumulate for visual feedback only), separate OI Data backend integration, separate WebSocket multiplexer for OI Data topics.

Out of scope: order placement, broker integration, algorithmic execution, signal generation, scheduled tasks, backtesting, and **hand-off to the existing `/strategy-builder` route**.

### 0.3 Hand-off / order placement policy

**Deferred — see section 3.** Until that section says otherwise, InstaOptions never navigates to `/strategy-builder`, never calls broker endpoints, and never opens an order-confirmation flow. When the user clicks "Add 1 lot BUY" / "B" / "S" / "Add to basket", the leg is appended to an **in-memory basket** that lives inside `InstaOptionsBasketProvider`. The floating BasketChip renders the count visually. Tap on the chip or on any leg-add button shows a toast: `"Order placement coming in a future release."` That is the entire current behaviour.

---

## 1. Stack & packages

InstaOptions reuses the host app's existing dependencies. **No new packages need to be added to [pubspec.yaml](pubspec.yaml).** Verify these are already present (they are, as of 2026-05-28):

| Concern | Package | Mynt source-of-truth |
|---|---|---|
| Language / framework | Dart 3.x on Flutter (Web target) | `pubspec.yaml` |
| State management | `flutter_riverpod: ^3.1.0` | already in pubspec |
| Routing | `go_router: ^17.0.1` | [lib/routes/web_router.dart](lib/routes/web_router.dart) |
| HTTP client | `http: ^1.1.0` wrapped by `ApiExporter` | [lib/api/core/api_export.dart](lib/api/core/api_export.dart) |
| WebSocket | `web_socket_channel: ^3.0.3` | already used by [lib/provider/websocket_provider.dart](lib/provider/websocket_provider.dart) |
| Models / JSON | Hand-written (no code-gen) | mirror [lib/models/marketwatch_model/opt_chain_model.dart](lib/models/marketwatch_model/opt_chain_model.dart) |
| Charts | `fl_chart: ^1.1.1` (primary), `syncfusion_flutter_charts: ^27.1.48` (fallback) | both already in pubspec |
| Tables | `data_table_2: ^2.7.2` | already in pubspec |
| Number formatting | `intl: ^0.19.0` + project's `RupeeFormat` | [lib/utils/rupee_convert_format.dart](lib/utils/rupee_convert_format.dart) |
| Local persistence | `shared_preferences: ^2.5.4` via `Preferences` from `locator` | [lib/locator/locator.dart](lib/locator/locator.dart) |

**Do NOT introduce** `dio`, `freezed`, `json_serializable`, `riverpod_generator`, `Inter` font, or `Roboto Mono`. The project does not use these and adding them would be inconsistent with the rest of the codebase.

After any code change in this module:
- `flutter analyze` must be clean for `lib/api/insta_options/`, `lib/models/insta_options/`, `lib/provider/insta_options/`, `lib/screens/Web/insta_options/`.
- `flutter run -d chrome --web-port 8080` must reach `http://localhost:8080/#/insta-options` without console errors.

---

## 2. Routing & navigation

InstaOptions adds **one route** to the host app's existing `GoRouter`. The route uses Mynt's standard pattern: it opens [CustomizableSplitHomeScreen](lib/screens/Web/customizable_split_home_screen.dart) with a new `initialRightPanel`. Internal navigation between the nine sub-screens happens **inside** the right panel via a side-rail.

### 2.1 Files to modify

1. [lib/routes/route_names.dart](lib/routes/route_names.dart) — add:
   ```dart
   static const String instaOptions = '/insta-options';
   ```

2. [lib/routes/web_router.dart](lib/routes/web_router.dart) — register a new `GoRoute` alongside the existing `/strategy-builder`, `/option-chain`, etc.:
   ```dart
   GoRoute(
     path: WebRoutes.instaOptions,
     builder: (context, state) => const CustomizableSplitHomeScreen(
       initialRightPanel: ScreenTypeParam.instaOptions,
     ),
   ),
   ```

3. [lib/screens/Web/customizable_split_home_screen.dart](lib/screens/Web/customizable_split_home_screen.dart) — add `instaOptions` to the `ScreenTypeParam` enum and route the panel switch to `const InstaOptionsShell()` for that case.

4. [lib/screens/Web/home/widgets/app_bar/navigation_drawer_web.dart](lib/screens/Web/home/widgets/app_bar/navigation_drawer_web.dart) — add a new menu entry "InstaOptions Analytics" under the Options group, following the existing pattern used for "Strategy Builder" (icon, "NEW" badge, `VoidCallback? onInstaOptionsTap`). The callback navigates to `WebRoutes.instaOptions` via `context.go(WebRoutes.instaOptions)`.

### 2.2 Internal side-rail navigation

Inside `InstaOptionsShell` (the right-panel widget) the active sub-screen is held in a single piece of state:

```dart
enum InstaSubScreen {
  markets, contributors, chain, oiStats, trending, pcr, strike, buildup, findStrategy,
}
```

The shell renders a 220-wide side-rail on the left and the active sub-screen widget on the right. Switching sub-screens **does not** call `context.go(...)`; it only updates local state. (Optional deep-linking via `?screen=chain&symbol=NIFTY&expiry=30-JUN-2026` may be wired later — see section 14, Phase 10.)

### 2.3 Symbol / expiry selection

Each sub-screen has a top **SymbolExpiryBar** widget (section 9.1). The bar reads/writes `InstaOptionsSelectionProvider` (section 5.1). Selection is persisted to `Preferences` so the next visit lands on the same symbol/expiry.

---

## 3. Deferred — order placement integration

The original spec defined an `/strategy-builder?legs=...` hand-off. **That is not built in v1.** When InstaOptions is ready for order placement, a follow-up sprint will:

1. Decide how legs flow from InstaOptions to the existing [StrategyBuilderProvider](lib/provider/strategy_builder_provider.dart). Options under consideration:
   - A new shared `BasketHandoffProvider` consumed by the existing Strategy Builder on mount.
   - A `?legs=` query-string parser added to the existing `/strategy-builder` route.
   - A typed object passed via `GoRouter`'s `state.extra`.
2. Implement an "Open in Strategy Builder" tap handler on `BasketChip`.
3. Wire BUY/SELL bottom-sheet buttons and Find-Strategy "Add to basket" to the same handler.

**Until that sprint lands:**
- All "add leg" actions only mutate `InstaOptionsBasketProvider` (in-memory list).
- The floating chip renders the count but tap is a no-op or a toast.
- BUY/SELL buttons in the bottom sheet are visually present but tap shows `"Order placement coming in a future release."` via the project's existing snack-bar helper in [lib/sharedWidget/snack_bar.dart](lib/sharedWidget/snack_bar.dart).
- The Find-Strategy "Add to basket" button replaces the in-memory basket with the strategy's legs and shows the same toast.

This boundary keeps the analytics surface fully usable today while the hand-off contract is being designed.

---

## 4. Folder layout

```
lib/api/insta_options/
├── insta_options_config.dart            # base URL from Preferences; default http://192.168.5.61:8000
├── insta_options_api.dart               # http-package client; one method per endpoint in section 8
└── insta_options_ws_client.dart         # singleton WS multiplexer for the OI Data feed (NOT the Mynt WS)

lib/models/insta_options/                # hand-written models (factory <Model>.fromJson)
├── chain_row.dart                       # /oi/chain + /analytics/chain row
├── greeks.dart                          # iv, delta, gamma, theta, vega, rho, iv_solver_ok
├── multistrike_row.dart
├── ts_bar.dart                          # /oi/timeseries bar + /spot/timeseries bar
├── aggregate.dart                       # /oi/aggregate envelope
├── buildup_row.dart                     # /oi/buildup row
├── symbol_buildup.dart                  # /buildup/symbols entry
├── market_snapshot.dart                 # /market/snapshot
├── contributor.dart                     # /contributors/{index}
├── atm_iv.dart                          # /analytics/atm_iv
├── strategy_template.dart               # /strategy/templates
├── scan_request.dart                    # POST /strategy/scan request body
├── scan_result.dart                     # POST /strategy/scan result
├── reference.dart                       # /reference/* responses
├── stream_envelope.dart                 # WS server envelope
├── basket_leg.dart                      # in-memory basket leg
└── selection.dart                       # { exchange, symbol, expiry }

lib/provider/insta_options/              # all are ChangeNotifierProvider extending DefaultChangeNotifier
├── insta_options_selection_provider.dart    # selection + URL/Preferences sync
├── insta_options_basket_provider.dart       # in-memory List<BasketLeg> (no hand-off)
├── insta_options_stream_provider.dart       # wraps the WS client
├── insta_options_reference_provider.dart    # caches /symbols, /expiries, /reference/*
├── insta_options_chain_provider.dart        # screen 3
├── insta_options_buildup_provider.dart      # screen 8
├── insta_options_oi_stats_provider.dart     # screen 4
├── insta_options_pcr_provider.dart          # screen 6
├── insta_options_strike_chart_provider.dart # screen 7
├── insta_options_trending_provider.dart     # screen 5
├── insta_options_markets_provider.dart      # screen 1
├── insta_options_contributors_provider.dart # screen 2
└── insta_options_scan_provider.dart         # screen 9

lib/screens/Web/insta_options/
├── insta_options_shell.dart             # side-rail + active-sub-screen switcher
├── insta_options_theme.dart             # InstaOptionsTokens.of(context) resolved MyntColors
├── insta_options_format.dart            # thin wrappers over RupeeFormat (formatOi, formatIv, …)
├── widgets/
│   ├── side_rail.dart
│   ├── symbol_expiry_bar.dart
│   ├── streaming_dot.dart
│   ├── oi_bar_cell.dart
│   ├── kpi_card.dart
│   ├── buildup_pill.dart
│   ├── strike_picker.dart
│   ├── basket_chip.dart                 # disabled visual chip; tap → toast
│   └── chain_leg_bottom_sheet.dart      # BUY/SELL buttons; tap → enqueue + toast
└── screens/
    ├── markets_screen.dart
    ├── contributors_screen.dart
    ├── chain_screen.dart
    ├── oi_stats_screen.dart
    ├── trending_screen.dart
    ├── pcr_screen.dart
    ├── strike_chart_screen.dart
    ├── buildup_screen.dart
    └── find_strategy_screen.dart

assets/insta_options_fixtures/           # offline-QA fixtures (section-8 sample JSON)
├── symbols.json
├── expiries-nifty.json
├── chain-nifty-30jun2026.json
├── analytics-chain-nifty-30jun2026.json
└── ...one file per endpoint in section 8

test/insta_options/                      # added in Phase 10
├── sentiment_formula_test.dart
├── format_oi_test.dart
├── atm_detection_test.dart
├── basket_provider_test.dart
└── *_golden_test.dart                   # per-screen × 2 themes × 2 viewports
```

---

## 5. Module-scoped state

All providers follow the **hand-written `ChangeNotifierProvider`** pattern already used across this repo (e.g. [lib/provider/option_flash_provider.dart](lib/provider/option_flash_provider.dart) and [lib/provider/websocket_provider.dart](lib/provider/websocket_provider.dart)). Do NOT introduce `riverpod_generator` or `StateNotifierProvider` for this module — it would be inconsistent with the surrounding codebase.

Skeleton pattern (copy this verbatim and adapt for each provider):

```dart
final instaOptionsXProvider = ChangeNotifierProvider((ref) => InstaOptionsXProvider(ref));

class InstaOptionsXProvider extends DefaultChangeNotifier {
  final InstaOptionsApi _api = locator<InstaOptionsApi>();
  final Preferences _pref = locator<Preferences>();
  final Ref ref;

  InstaOptionsXProvider(this.ref);

  // state fields with private setters
  // public getters
  // async fetch methods that call notifyListeners()
}
```

### 5.1 Selection

```dart
class Selection {
  final String exchange;   // 'NFO' | 'BFO'
  final String symbol;     // 'NIFTY' | 'BANKNIFTY' | ...
  final String expiry;     // '30-JUN-2026' (DD-MON-YYYY)
}
```

Persisted to `Preferences` under the key `instaoptions:selection`. Read on first mount of `InstaOptionsShell`; if missing, default to `{exchange: 'NFO', symbol: 'NIFTY', expiry: <nearest>}` after fetching `/expiries`. Every screen reads from `instaOptionsSelectionProvider`.

### 5.2 Basket (in-memory only)

```dart
class BasketLeg {
  final String side;            // 'B' | 'S'
  final int lot;
  final String expiry;
  final double strike;
  final String optionType;      // 'CE' | 'PE' | 'FUT'
  final double entryPrice;
  final String tradingSymbol;
}
```

Methods: `add(leg)`, `removeAt(i)`, `clear()`, getter `queuedLegs`. **No `toUrl()` and no `navigateToStrategyBuilder()` until the deferred sprint in section 3.**

### 5.3 Streaming

A singleton `InstaOptionsWsClient` (registered in [lib/locator/locator.dart](lib/locator/locator.dart)) multiplexes the WS connection to the OI Data feed. **This is distinct from Mynt's existing `websocketProvider`** because the OI Data backend speaks a different protocol on a separate endpoint.

Subscribers (one per active screen) request a filtered stream by `(topic, key)`. On `Provider.dispose`, the provider calls `ws.unsubscribe`. Reconnect policy: exponential backoff `1, 2, 4, 8, 16, 30` seconds (cap). On reconnect, re-issue every prior `subscribe` and call `GET /stream/replay-since?topic=<t>&since_ts=<lastEnvelopeTsInSeconds>` per subscription.

### 5.4 Reference cache

`InstaOptionsReferenceProvider` caches `/symbols`, `/expiries`, `/reference/lot_size`, `/reference/index/{index}`, `/reference/risk_free_rate` to `Preferences` keyed on `as_of` / `last_rebalance`. Refresh when those dates change.

---

## 6. Theme tokens — map every README colour onto MyntColors

Use the resolved [MyntColors](lib/res/mynt_web_color_styles.dart) field for every colour, then pick light or dark based on `Theme.of(context).brightness`. **No hex literals in widget code.** Wrap the resolution in `InstaOptionsTokens.of(context)` so every widget calls a single helper.

### 6.1 Colour token mapping

| Local token | MyntColors field (light) | MyntColors field (dark) | Used for |
|---|---|---|---|
| `bgPrimary` | `backgroundColor` | `backgroundColorDark` | App / shell background |
| `bgSecondary` | `card` | `cardDark` | Card / panel background |
| `bgTertiary` | `cardHover` | `cardHoverDark` | Hover / selected row |
| `border` | `cardBorder` | `cardBorderDark` | Card borders, dividers |
| `textPrimary` | `textPrimary` | `textPrimaryDark` | Body text |
| `textSecondary` | `textSecondary` | `textSecondaryDark` | Labels, sub-text |
| `textMuted` | `textTertiary` | `textTertiaryDark` | Disabled, placeholder |
| `accent` | `primary` | `primaryDark` | Active tab, primary button |
| `accentDim` | `secondary` | `secondaryDark` | Hover on accent |
| `profit` | `profit` | `profitDark` | Positive change, CE OI bars |
| `loss` | `loss` | `lossDark` | Negative change, PE OI bars |
| `warning` | `warning` | `warningDark` | Long-Unwinding pill, stale chip |
| `info` | `secondary` | `secondaryDark` | Short-Covering pill |
| `neutral` | `textTertiary` | `textTertiaryDark` | Neutral pill, no change |
| `barCe` | `profit.withValues(alpha: 0.4)` | `profitDark.withValues(alpha: 0.4)` | OI bar background for CE cells |
| `barPe` | `loss.withValues(alpha: 0.4)` | `lossDark.withValues(alpha: 0.4)` | OI bar background for PE cells |
| `atmHighlight` | `selectedBg` | `selectedBgDark` | Background of ATM row |
| `sdMarker` | `textSecondary.withValues(alpha: 0.6)` | `textSecondaryDark.withValues(alpha: 0.6)` | ±σ vertical line on Payoff |

### 6.2 Typography

All text uses [MyntWebTextStyles](lib/res/mynt_web_text_styles.dart) (Geist font, already loaded by the host app). The README's original `Inter` / `Roboto Mono` stack is **not** used.

| Original spec name | Replacement (Mynt) | Used for |
|---|---|---|
| `textDisplay` (24sp, 700) | `MyntWebTextStyles.hero(context)` | Page titles |
| `textTitle` (18sp, 600) | `MyntWebTextStyles.head(context)` | Card titles |
| `textBody` (14sp, 400) | `MyntWebTextStyles.body(context)` | Body |
| `textLabel` (12sp, 500) | `MyntWebTextStyles.para(context)` | Form labels, table headers |
| `textCaption` (11sp, 400) | `MyntWebTextStyles.caption(context)` | Hints, footnotes |
| `textNumeric` (13sp, 400) | `MyntWebTextStyles.tableCell(context)` | Tabular numbers |
| `textNumericBold` (13sp, 600) | `MyntWebTextStyles.price(context)` | Tabular emphasis |

Pass colour via the `color:` parameter on each style method. Example: `MyntWebTextStyles.price(context, color: tokens.profit)`.

### 6.3 Spacing scale

Use only these values: `4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 56`.

Defaults: card padding `16`, section margins `24`, dense-table row `28`, standard-table row `36`, tabs `40` tall.

### 6.4 Borders & radii

Card border `1px` solid `border`. Card radius `8px`. Pill radius `12px`. Button radius `6px`. Modal radius `12px`.

---

## 7. Formatting

### 7.1 Numbers — reuse RupeeFormat

Use [RupeeFormat](lib/utils/rupee_convert_format.dart) for all Indian-formatted numbers. Wrap commonly-used patterns in `lib/screens/Web/insta_options/insta_options_format.dart`:

| Field | Function | Example |
|---|---|---|
| OI / Volume (compact) | `RupeeFormat.formatCompact(value)` | `12,30,825 → 12.31 L`; `4,50,00,000 → 4.50 Cr`; `820 → 820` |
| OI / Volume (full, with grouping) | `RupeeFormat.format(value)` | `12,30,825` |
| LTP, strike, premium | `RupeeFormat.format(value, decimalPlaces: 2)` | `13.75`, `23,900.00` |
| Change % (colored) | `RupeeFormat.format(pct, decimalPlaces: 2, showSign: true)` + `%` suffix | `+1.42%`, `-0.83%` |
| IV | `value.toStringAsFixed(1) + '%'` | `12.8%` |
| Greeks (Δ Γ Θ V Ρ) | `value.toStringAsFixed(4)` with sign | `0.5715`, `-0.4354` |
| PCR | `value.toStringAsFixed(2)` | `0.97` |

If `RupeeFormat.formatCompact` outputs `1.25 L` and the design calls for `1.25L` (no space), trim in the wrapper.

### 7.2 Time

Server timestamps are IST. Display as `HH:mm` (`DateFormat.Hm()`); on tooltip, show full `YYYY-MM-DD HH:mm:ss`. Use the existing helpers in [lib/sharedWidget/functions.dart](lib/sharedWidget/functions.dart) where applicable; otherwise call `intl`'s `DateFormat` directly.

### 7.3 Empty / unknown

- IV solver failed (`iv_solver_ok: false`) → render `—` for IV and all Greeks; do not skip the row.
- Field missing → `—`.
- Zero value that means "not yet computed" → render `—` AND show "Aggregator warming up" placeholder.

---

## 8. Backend API — complete reference

The OI Data backend is **a separate service** from Mynt's Noren/`go.mynt.in` APIs. Base URL is configurable via `InstaOptionsConfig` (backed by `Preferences` key `instaoptions:baseUrl`, default `http://192.168.5.61:8000`). WebSocket at `${wsBaseUrl}/stream`, default `ws://192.168.5.61:8000`.

Every endpoint returns JSON. Every non-2xx response uses this envelope:

```json
{
  "error": {
    "code":    "INVALID_PARAM | NOT_FOUND | UPSTREAM | RATE_LIMITED | INTERNAL",
    "message": "human readable",
    "detail":  { /* optional structured fields */ }
  }
}
```

| HTTP status | Meaning | `code` |
|---|---|---|
| 200 | OK | — |
| 400 | Invalid query param | `INVALID_PARAM` |
| 404 | Not found (symbol / expiry / strike) | `NOT_FOUND` |
| 429 | Rate limit exceeded | `RATE_LIMITED` |
| 502 | Upstream broker feed down | `UPSTREAM` |
| 500 | Unhandled | `INTERNAL` |

`InstaOptionsApi` throws a typed `InstaOptionsApiException(code, message, detail)` on non-2xx; UI shows the message in the inline `ErrorBanner`.

For each endpoint below: request, sample response captured from the live backend on 28 May 2026, edge cases, and refresh cadence.

---

### 8.1 GET /symbols

List F&O underlying symbols on an exchange.

**Query parameters**

| name | type | required | description |
|---|---|---|---|
| exchange | string | yes | `NFO` or `BFO` |

**Sample request**

```
GET /symbols?exchange=NFO
```

**Sample response (live, 28-May-2026)**

```json
{
  "exchange": "NFO",
  "count": 5,
  "symbols": ["BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "NIFTY", "NIFTYNXT50"]
}
```

**Edge cases**

- Empty exchange → 400 `INVALID_PARAM`
- Stock F&O symbols are returned by the same shape once the backend universe is widened

**Refresh**: once per app session (cached in `InstaOptionsReferenceProvider`).

---

### 8.2 GET /expiries

List expiries for a symbol.

**Query parameters**

| name | type | required |
|---|---|---|
| exchange | string | yes |
| symbol | string | yes |

**Sample request**

```
GET /expiries?exchange=NFO&symbol=NIFTY
```

**Sample response**

```json
{
  "exchange": "NFO",
  "symbol": "NIFTY",
  "expiries": [
    "02-JUN-2026", "09-JUN-2026", "16-JUN-2026", "23-JUN-2026",
    "30-JUN-2026", "28-JUL-2026", "25-AUG-2026", "29-SEP-2026",
    "29-DEC-2026", "30-MAR-2027", "29-JUN-2027", "28-DEC-2027",
    "27-JUN-2028", "26-DEC-2028", "26-JUN-2029", "24-DEC-2029",
    "25-JUN-2030", "31-DEC-2030"
  ]
}
```

**Edge cases**

- Format is always `DD-MON-YYYY` uppercase
- Sorted ascending
- Weekly + monthly + quarterly + half-yearly all in one array; UI must not assume monthly-only

**Refresh**: once per (exchange, symbol).

---

### 8.3 GET /spot

Current spot LTP snapshot for the underlying.

**Query parameters**: `exchange`, `symbol`.

**Sample response**

```json
{ "spot": 23907.15 }
```

**Refresh**: every 4 s while a screen is mounted that needs it, OR replaced by the WS `spot` topic when streaming is active.

---

### 8.4 GET /spot/timeseries

Spot 1-min OHLC bars for a date.

**Query parameters**: `exchange`, `symbol`, optional `date=YYYY-MM-DD` (default today).

**Sample response (partial; 6 bars in this test)**

```json
{
  "symbol": "NIFTY",
  "bars": [
    { "time": "2026-05-28 06:08:00", "open": 23907.15, "high": 23907.15, "low": 23907.15, "close": 23907.15 },
    { "time": "2026-05-28 07:06:00", "open": 23907.15, "high": 23907.15, "low": 23907.15, "close": 23907.15 }
  ]
}
```

**Edge cases**

- Empty `bars` outside trading hours
- Times in IST

**Refresh**: per-minute REST poll on visible chart; no WS for this in v1.

---

### 8.5 GET /oi/chain

Full chain snapshot for one symbol-expiry: every contract. Includes one FUT row as the first element.

**Query parameters**: `exchange`, `symbol`, `expiry` (DD-MON-YYYY).

**Sample response (3 selected rows from a 567-row array)**

```json
[
  {
    "token": 62329, "symbol": "NIFTY", "expiry": "30-JUN-2026",
    "option_type": "FUT", "strike": "0",
    "trading_symbol": "NIFTY30JUN26F",
    "ltp": 23996.7, "oi": 14782950, "volume": 2889965
  },
  {
    "token": 79722, "symbol": "NIFTY", "expiry": "30-JUN-2026",
    "option_type": "CE", "strike": "23900.0",
    "trading_symbol": "NIFTY30JUN26C23900",
    "ltp": 445.25, "oi": 684840, "volume": 1655745
  },
  {
    "token": 79723, "symbol": "NIFTY", "expiry": "30-JUN-2026",
    "option_type": "PE", "strike": "23900.0",
    "trading_symbol": "NIFTY30JUN26P23900",
    "ltp": 349.7, "oi": 624000, "volume": 1512615
  }
]
```

**Notes**

- First row is the FUT for the expiry. For weekly expiries that have no own future, the backend prepends the nearest-month FUT and adds `"nearest_month_fut": true` on that row.
- Strikes are returned as strings with one decimal (`"23900.0"`). Parse to double for sorting; keep the string for joining with other endpoints that use the same convention.
- Order: FUT first, then strikes ascending, CE then PE per strike.
- `volume` resets to 0 at session start.

**Refresh**: REST on mount, then WS `chain_delta` deltas.

---

### 8.6 GET /oi/change

Per-strike OI change between two timestamps.

**Query parameters**

| name | type | required |
|---|---|---|
| exchange | string | yes |
| symbol | string | yes |
| expiry | string | yes |
| last_minutes | int | one of |
| start_offset | int | one of (use with end_offset, minutes since 9:15) |
| end_offset | int | one of |

**Sample request**

```
GET /oi/change?exchange=NFO&symbol=NIFTY&expiry=30-JUN-2026&last_minutes=15
```

**Sample response (2 rows from a 566-row array)**

```json
{
  "start_time": "2026-05-28 13:18:00",
  "end_time":   "2026-05-28 13:18:00",
  "records": [
    {
      "token": 43869, "strike": 1500, "option_type": "PE",
      "trading_symbol": "NIFTY30JUN26P1500",
      "open_oi": 0, "current_oi": 0, "oi_change": 0, "ltp": 0.05
    },
    {
      "token": 43868, "strike": 1500, "option_type": "CE",
      "trading_symbol": "NIFTY30JUN26C1500",
      "open_oi": 0, "current_oi": 0, "oi_change": 0, "ltp": 22415.5
    }
  ]
}
```

**Notes**

- Timestamps in full ISO `YYYY-MM-DD HH:mm:ss`. When market is closed `start_time == end_time` (single snapshot).
- `strike` returned as a number here, not a string (in contrast to `/oi/chain`).

**Refresh**: triggered when the user changes the "Change reference" dropdown on Option Chain.

---

### 8.7 GET /oi/multistrike

Per-strike flat CE/PE OI + LTP summary. No FUT row.

**Query parameters**: `exchange`, `symbol`, `expiry`.

**Sample response (2 rows from a 285-row array)**

```json
[
  { "strike": "1500.0",  "ce_oi": 0,      "pe_oi": 0,      "ce_ltp": 22415.5, "pe_ltp": 0.05 },
  { "strike": "23900.0", "ce_oi": 684840, "pe_oi": 624000, "ce_ltp": 445.25,  "pe_ltp": 349.7 }
]
```

**Refresh**: REST every 4 s on screens that need OI bar background overlays.

---

### 8.8 GET /oi/multistrike/timeseries

Per-strike per-side 1-min OI series. Keys are `"<strike>_<type>"`.

**Query parameters**

| name | type | required |
|---|---|---|
| exchange | string | yes |
| symbol | string | yes |
| expiry | string | yes |
| strikes | string | yes, comma-separated, one decimal e.g. `23900.0,23950.0` |
| types | string | yes, comma-separated, `CE,PE` |

**Sample request**

```
GET /oi/multistrike/timeseries?exchange=NFO&symbol=NIFTY&expiry=30-JUN-2026&strikes=23900.0,23950.0&types=CE,PE
```

**Sample response (partial)**

```json
{
  "23900.0_CE": [
    { "time": "2026-05-28 06:08:00", "oi": 684840, "close": 445.25 },
    { "time": "2026-05-28 07:06:00", "oi": 684840, "close": 445.25 }
  ],
  "23900.0_PE": [ ... ],
  "23950.0_CE": [ ... ],
  "23950.0_PE": [ ... ]
}
```

**Notes**

- Key format is exactly `<strike-with-one-decimal>_<type>`. Match this string when joining with other endpoints.
- `close` is the leg LTP at bucket close.

**Refresh**: REST on mount; WS `oi_bucket_close` topic appends a new bucket every ~3 min.

---

### 8.9 GET /oi/timeseries

Single-contract 1-min OHLCV + OI series for a chosen date.

**Query parameters**: `exchange`, `symbol`, `expiry`, `option_type` (`FUT | CE | PE`), `strike` (ignored for FUT), `date` (optional).

**Sample response shape**

```json
[
  {
    "time": "2026-05-28 09:15:00",
    "open": 155.1, "high": 164.05, "low": 97.05, "close": 99.75,
    "volume": 1979120, "oi": 2830295, "oi_change": 0
  }
]
```

**Edge cases**

- Empty array if no backfill has been run for that contract on that date

**Refresh**: REST on mount, then per-minute poll.

---

### 8.10 GET /oi/aggregate

Chain-level totals at the most recent minute-close.

**Sample response**

```json
{
  "symbol": "NIFTY", "expiry": "30-JUN-2026",
  "ready": false,
  "total_ce_oi": 0, "total_pe_oi": 0,
  "total_ce_oi_change": 0, "total_pe_oi_change": 0,
  "pcr": 0,
  "computed_at": null
}
```

**Notes**

- When `ready: false`, the aggregator worker has not yet produced a snapshot. Treat every numeric field as undefined and show the "Aggregator warming up" placeholder.
- When `ready: true`, `computed_at` will be a full ISO timestamp.

**Refresh**: REST every 4 s on OI Statistics.

---

### 8.11 GET /oi/pcr/timeseries

Chain-level PCR per bucket with spot overlay.

**Query parameters**: `exchange`, `symbol`, `expiry`, optional `date`.

**Sample response shape**

```json
[
  { "time": "2026-05-28 09:15:00", "pcr": 0.84, "spot": 24038.1 }
]
```

In this test the array is empty because the aggregator was not running.

**Refresh**: REST every 60 s.

---

### 8.12 GET /oi/buildup

Per-contract buildup classification.

**Sample response (2 rows from a 566-row array)**

```json
[
  {
    "token": 79722, "strike": 23900, "option_type": "CE",
    "trading_symbol": "NIFTY30JUN26C23900",
    "open_price": 445.25, "close_price": 445.25, "price_change": 0,
    "open_oi": 684840, "close_oi": 684840, "oi_change": 0,
    "buildup": "Neutral"
  },
  {
    "token": 79723, "strike": 23900, "option_type": "PE",
    "trading_symbol": "NIFTY30JUN26P23900",
    "open_price": 349.7, "close_price": 349.7, "price_change": 0,
    "open_oi": 624000, "close_oi": 624000, "oi_change": 0,
    "buildup": "Neutral"
  }
]
```

**`buildup` values**: `"Long Buildup" | "Short Buildup" | "Long Unwinding" | "Short Covering" | "Neutral"`.

Server-side classification rules (reference only; do NOT re-classify on the client):
- price ↑ & OI ↑ → Long Buildup
- price ↓ & OI ↑ → Short Buildup
- price ↑ & OI ↓ → Short Covering
- price ↓ & OI ↓ → Long Unwinding
- `|price_change| < 0.05%` AND `|oi_change| < 0.5%` → Neutral

**Refresh**: REST every 4 s + WS `chain_delta` deltas applied for LTP and OI.

---

### 8.13 GET /buildup/symbols

Per-symbol futures buildup grouped by bucket — powers the Markets Dashboard.

**Query parameters**: `exchange`.

**Sample response shape**

```json
{
  "long_buildup":    [ { "symbol": "...", "prev_close": ..., "ltp": ..., "change_pct": ..., "new_oi": ..., "old_oi": ..., "oi_change": ..., "oi_change_pct": ... } ],
  "short_buildup":   [ ... ],
  "short_covering":  [ ... ],
  "long_unwinding":  [ ... ]
}
```

Sample arrays are empty in this test because the market was closed and every symbol classified as Neutral (Neutral is excluded by spec).

**Refresh**: REST every 4 s during market hours.

---

### 8.14 GET /fut/oi

Futures intraday OHLCV + OI for a single expiry.

**Sample response shape**

```json
{
  "symbol": "NIFTY", "expiry": "30-JUN-2026",
  "bars": [
    { "time": "...", "open": ..., "high": ..., "low": ..., "close": ..., "volume": ..., "oi": ..., "oi_change": ... }
  ]
}
```

**Edge cases**

- Returns 404 with structured envelope if no FUT exists for the expiry (e.g. some weekly indices)

**Used by**: nothing in v1 of InstaOptions — this is reserved for the Markets Dashboard's per-symbol drill-down in a later sprint.

---

### 8.15 GET /market/snapshot

Single payload that powers the Markets Dashboard's advances/declines, per-index stock list, and index summary.

**Sample response (abbreviated)**

```json
{
  "advances": 0, "declines": 0, "unchanged": 146,
  "per_index": {
    "NIFTY":       { "stocks": [{ "name": "HDFCBANK", "today_open": 0, "yesterday_close": 0, "gap_pct": 0, "change_pct": 0, "ltp": 758.65 }, ... 49 more ] },
    "BANKNIFTY":   { "stocks": [ ... ] },
    "FINNIFTY":    { "stocks": [ ... ] },
    "MIDCPNIFTY":  { "stocks": [ ... ] },
    "NIFTYNXT50":  { "stocks": [ ... ] },
    "SENSEX":      { "stocks": [ ... ] },
    "BANKEX":      { "stocks": [ ... ] }
  },
  "indices": [
    { "name": "NIFTY",      "today_open": 0, "yesterday_close": 0, "change_pct": 0, "ltp": 23907.15 },
    { "name": "BANKNIFTY",  "today_open": 0, "yesterday_close": 0, "change_pct": 0, "ltp": 54853.85 },
    { "name": "FINNIFTY",   "today_open": 0, "yesterday_close": 0, "change_pct": 0, "ltp": 25752.20 },
    { "name": "MIDCPNIFTY", "today_open": 0, "yesterday_close": 0, "change_pct": 0, "ltp": 14705.95 },
    { "name": "NIFTYNXT50", "today_open": 0, "yesterday_close": 0, "change_pct": 0, "ltp": 75867.80 },
    { "name": "SENSEX",     "today_open": 0, "yesterday_close": 0, "change_pct": 0, "ltp": 81234.50 },
    { "name": "BANKEX",     "today_open": 0, "yesterday_close": 0, "change_pct": 0, "ltp": 62110.30 }
  ],
  "computed_at": "..."
}
```

**Refresh**: REST every 4 s.

---

### 8.16 GET /contributors/{index}

Per-index constituent contribution to today's index points.

**Path parameter**: `index` (`NIFTY | BANKNIFTY | FINNIFTY | MIDCPNIFTY | SENSEX | BANKEX`).

**Sample response (3 of 50 rows)**

```json
[
  { "stock": "HDFCBANK",  "sector": "Financial Services", "ltp": 758.65,  "change_pct": 0, "weight": 0.1182, "divisor": 13.621, "index_points": 0 },
  { "stock": "RELIANCE",  "sector": "Energy",             "ltp": 1350.5,  "change_pct": 0, "weight": 0.0931, "divisor": 13.621, "index_points": 0 },
  { "stock": "ICICIBANK", "sector": "Financial Services", "ltp": 1272.7,  "change_pct": 0, "weight": 0.0844, "divisor": 13.621, "index_points": 0 }
]
```

**Notes**

- `index_points = (ltp - prev_close) * weight / divisor`, server-side
- Sorted descending by `|index_points|`

**Refresh**: every 4 s.

---

### 8.17 GET /analytics/chain

Same shape as `/oi/chain` (including FUT first) but each CE/PE row carries `iv`, `delta`, `gamma`, `theta`, `vega`, `rho`, `iv_solver_ok`. FUT row carries no Greeks.

**Sample response (3 rows of 567)**

```json
[
  {
    "token": 62329, "symbol": "NIFTY", "expiry": "30-JUN-2026",
    "option_type": "FUT", "strike": "0",
    "trading_symbol": "NIFTY30JUN26F",
    "ltp": 23996.7, "oi": 14782950, "volume": 2889965
  },
  {
    "token": 79722, "symbol": "NIFTY", "expiry": "30-JUN-2026",
    "option_type": "CE", "strike": "23900.0",
    "trading_symbol": "NIFTY30JUN26C23900",
    "ltp": 445.25, "oi": 684840, "volume": 1655745,
    "iv": 12.8214,
    "delta": 0.571499, "gamma": 0.0004258356, "theta": -7.845491,
    "vega": 28.219064, "rho": 11.952694,
    "iv_solver_ok": true
  },
  {
    "token": 79723, "symbol": "NIFTY", "expiry": "30-JUN-2026",
    "option_type": "PE", "strike": "23900.0",
    "trading_symbol": "NIFTY30JUN26P23900",
    "ltp": 349.7, "oi": 624000, "volume": 1512615,
    "iv": 14.6726,
    "delta": -0.435388, "gamma": 0.0003732285, "theta": -4.366241,
    "vega": 28.303941, "rho": -9.728938,
    "iv_solver_ok": true
  }
]
```

**Edge cases**

- `iv_solver_ok: false` → `iv` and all Greeks are `null`. UI renders `—` for those columns
- `iv` is expressed as a percentage so the UI displays it directly

**Refresh**: REST on mount + WS `iv_update` deltas applied per row.

---

### 8.18 GET /analytics/atm_iv

ATM IV and 1-SD expected move. Used by the Per-Strike chart's σ bands and by Find Strategy's reward math.

**Sample response**

```json
{
  "symbol": "NIFTY", "expiry": "30-JUN-2026",
  "spot": 23907.15,
  "atm_strike": 23900,
  "atm_call_iv": 12.8214,
  "atm_put_iv": 14.6726,
  "atm_iv": 13.747,
  "days_to_expiry": 33.0066,
  "one_sd_move": 988.3025
}
```

**Refresh**: REST every 30 s.

---

### 8.19 GET /strategy/templates

The 12 default strategy templates with their leg specs and strike-offset configuration.

**Sample response (first template, abbreviated)**

```json
[
  {
    "name": "bullCallSpread",
    "label": "Bull Call Spread",
    "view": "Bullish",
    "legs": [
      { "side": "BUY",  "option_type": "CE", "strike_offset": 0 },
      { "side": "SELL", "option_type": "CE", "strike_offset": 5 }
    ],
    "config": { "strike_offset_default": 5, "strike_offset_range": [1, 20] }
  },
  /* ... 11 more ... */
]
```

**Distribution**: 4 Bullish, 4 Bearish, 4 Neutral.

**`strike_offset`** is in strike-spacing units; positive = above ATM, negative = below ATM.

**Refresh**: once per app session.

---

### 8.20 POST /strategy/scan

Rank legal strategies by reward.

**Request body**

```json
{
  "exchange": "NFO",
  "symbol":   "NIFTY",
  "expiry":   "30-JUN-2026",
  "direction": "Positive",
  "min_reward": 100,
  "min_reward_type": "INR"
}
```

`direction` ∈ `"Positive" | "Negative" | "Neutral"`. `min_reward_type` ∈ `"INR" | "PCT"`.

**Sample response (first 2 of 3 results)**

```json
[
  {
    "template_name": "Long Call",
    "max_pl": 5538.69,
    "max_loss": -445.25,
    "breakeven": [24325.53],
    "legs": [
      {
        "side": "BUY", "trading_symbol": "NIFTY30JUN26C23900",
        "strike": 23900, "option_type": "CE", "lot": 1,
        "ltp": 445.25, "oi": 684840
      }
    ]
  },
  {
    "template_name": "Call Ratio Backspread",
    "max_pl": 5296.19,
    "max_loss": -433.97,
    "breakeven": [24564.6],
    "legs": [
      { "side": "SELL", "trading_symbol": "NIFTY30JUN26C23900", "strike": 23900, "option_type": "CE", "lot": 1, "ltp": 445.25, "oi": 684840 },
      { "side": "BUY",  "trading_symbol": "NIFTY30JUN26C24150", "strike": 24150, "option_type": "CE", "lot": 2, "ltp": 316.5,  "oi": ... }
    ]
  }
]
```

**Notes**

- Top 20 returned, sorted by `max_pl` descending
- `lot` is the number of lots; rupees ≈ `lot × lot_size × leg_price`

**Refresh**: on-demand only.

---

### 8.21 GET /reference/lot_size

Lot size for one symbol.

**Query parameters**: `symbol` (yes), `exchange` (no, default NFO).

**Sample response**

```json
{ "symbol": "NIFTY", "exchange": "NFO", "lot_size": 65 }
```

**Refresh**: once per app session per symbol.

---

### 8.22 GET /reference/index/{index}

Index constituent list with free-float weights.

**Sample response (abbreviated)**

```json
{
  "index": "NIFTY",
  "divisor": 13.621,
  "last_rebalance": "2026-03-31",
  "constituents": [
    { "stock": "HDFCBANK",  "sector": "Financial Services", "weight": 0.1182 },
    { "stock": "RELIANCE",  "sector": "Energy",             "weight": 0.0931 },
    { "stock": "ICICIBANK", "sector": "Financial Services", "weight": 0.0844 }
  ]
}
```

**Refresh**: once per month (rebalance cycle).

---

### 8.23 GET /reference/risk_free_rate

Current annualised risk-free rate.

**Sample response**

```json
{ "rate": 0.0653, "source": "91-day T-bill", "as_of": "2026-05-01" }
```

**Refresh**: once per day.

---

### 8.24 GET /health

**Sample response**

```json
{
  "status": "ok",
  "nfo_tokens": 11369,
  "bfo_tokens": 4654,
  "ws_feed": {
    "ts": 1779961721.2442572,
    "ws_connected": true,
    "last_tick_time": 1779954520.3936763,
    "subscribed_count": 20681,
    "tick_queue_size": 0
  },
  "analytics": {
    "ts": 1779961725.945735,
    "iv_jobs_per_sec": ...,
    "last_run_ts": ...
  }
}
```

Used by the `StreamingDot` tooltip and the optional "Backend status" badge.

---

### 8.WS  WebSocket /stream

Connect to `${wsBaseUrl}/stream`.

**Client → server messages**

```json
{ "action": "subscribe",   "topic": "spot",            "symbol": "NIFTY" }
{ "action": "subscribe",   "topic": "chain_delta",     "symbol": "NIFTY", "expiry": "30-JUN-2026" }
{ "action": "subscribe",   "topic": "iv_update",       "symbol": "NIFTY", "expiry": "30-JUN-2026" }
{ "action": "subscribe",   "topic": "oi_bucket_close", "symbol": "NIFTY", "expiry": "30-JUN-2026" }
{ "action": "unsubscribe", "topic": "...", "symbol": "...", "expiry": "..." }
{ "action": "ping" }
```

**Server ack** (after subscribe / unsubscribe)

```json
{ "ok": true, "subscribed": ["spot", "NIFTY"] }
```

**Server data envelope** (one shape for every topic)

```json
{
  "topic": "spot",
  "key":   "NIFTY",
  "ts":    1779953957.2946892,
  "seq":   1,
  "data":  { /* topic-specific payload */ }
}
```

`ts` is unix SECONDS as float — do NOT treat as ms. `seq` is monotonic per `(topic, key)` since server start. For chain/iv/oi-bucket topics, `key` is `"<symbol>:<expiry>"` (e.g. `"NIFTY:30-JUN-2026"`).

**Topic payloads**

```jsonc
// topic: spot   (max 5/s per symbol)
"data": { "symbol": "NIFTY", "spot": 23907.15 }

// topic: chain_delta   (batched ~1/s per symbol+expiry)
"data": {
  "symbol": "NIFTY", "expiry": "30-JUN-2026",
  "updates": [
    { "strike": 23900.0, "option_type": "CE", "ltp": 445.25, "oi": 684840 },
    { "strike": 23900.0, "option_type": "PE", "ltp": 349.70, "oi": 624000 }
  ]
}

// topic: iv_update   (~1-2/s per symbol+expiry)
"data": {
  "symbol": "NIFTY", "expiry": "30-JUN-2026",
  "updates": [
    { "strike": 23900.0, "option_type": "CE",
      "iv": 12.8214, "delta": 0.571499, "gamma": 0.0004258356,
      "theta": -7.845491, "vega": 28.219064, "rho": 11.952694,
      "iv_solver_ok": true }
  ]
}

// topic: oi_bucket_close   (1 message per 3-min bucket close)
"data": {
  "symbol": "NIFTY", "expiry": "30-JUN-2026", "bucket_time": "2026-05-28 13:09:00",
  "total_ce_oi": ..., "total_pe_oi": ..., "total_ce_oi_change": ..., "total_pe_oi_change": ..., "pcr": ...,
  "rows": [
    { "strike": 23900.0, "option_type": "CE", "oi": ..., "oi_change": ..., "close": ... }
  ]
}
```

**Reconnect policy**

Exponential back-off `1, 2, 4, 8, 16, 30` (capped). On successful reconnect, re-issue every prior subscribe message; then call `GET /stream/replay-since?topic=<t>&since_ts=<lastEnvelopeTsInSeconds>&symbol=...&expiry=...` per subscription and apply the returned envelopes in order. Retention is 1 hour; beyond that, refetch a REST snapshot.

---

## 9. Shared widgets — pixel specs (Mynt edition)

Every widget below uses `InstaOptionsTokens.of(context)` (section 6.1) for colours and `MyntWebTextStyles.*` (section 6.2) for typography. Reuse [lib/sharedWidget/](lib/sharedWidget/) primitives where they fit. Do not introduce duplicate buttons / loaders / no-data widgets.

### 9.1 SymbolExpiryBar

Top of every sub-screen.

```
Row, height 56, padding-h 24, background tokens.bgSecondary, bottom border 1px tokens.border
[ Dropdown(Exchange, w=80)  Dropdown(Symbol, w=140)  Dropdown(Expiry, w=160)  ────────── flexible spacer ──────────  StreamingDot(20×20)  IconButton(refresh, 20×20)  ]
```

Dropdowns use the host's standard form dropdown. Active background `tokens.bgTertiary`. Arrow icon `tokens.textSecondary`.

On change, write to `instaOptionsSelectionProvider` (persists to `Preferences` automatically).

### 9.2 OIBarCell

Used inside Option Chain and OI Buildup.

```
Stack(
  Positioned.fill(Container(color: tokens.barCe or tokens.barPe, width: value/maxValue * cellWidth)),
  Center(Text(formatOi(value), style: MyntWebTextStyles.price(context)))
)
```

CE bars fill from the LEFT, PE bars from the RIGHT. Inner padding `8/0/8/0`. Animate width change with `AnimatedContainer(200ms, Curves.easeOut)` so deltas don't jump.

### 9.3 StreamingDot

A 12×12 filled circle with 4px halo when connected.

- Connected: `tokens.profit`
- Reconnecting: `tokens.warning`
- Disconnected > 5 s OR backend unreachable: `tokens.loss`

Tooltip on hover shows: `Last tick: <HH:mm:ss>  ·  Queue: <n>  ·  Subscribed: <n>` from `/health`. If backend unreachable, tooltip reads `"Backend unreachable"`.

### 9.4 KpiCard

Compact KPI block.

```
Container(
  width 160, height 72, padding 12,
  decoration BoxDecoration(color: tokens.bgSecondary, border 1px tokens.border, radius 8),
  child Column(
    crossAxisAlignment start,
    [ Text(label, style: MyntWebTextStyles.para(context, color: tokens.textSecondary)),
      SizedBox(h=4),
      Text(value, style: MyntWebTextStyles.price(context, color: tokens.textPrimary).copyWith(fontSize: 16)),
      if (delta != null) Text(deltaText, style: deltaStyle) ]
  )
)
```

Delta colour: `tokens.profit` if positive, `tokens.loss` if negative, `tokens.textSecondary` otherwise. Prefix `▲` / `▼` (none for zero).

### 9.5 StrikePicker

Modal dialog opened by a button.

```
Dialog(
  width 480, height 540, background tokens.bgSecondary, radius 12,
  child Column(
    AppBar(title "Pick strikes", close button),
    Padding 16:
      TextField (search by strike), SizedBox(h=12),
      Wrap(
        spacing 8, runSpacing 8,
        children: chips for every strike in the active chain — selected chips have colour tokens.accent,
                  unselected chips have tokens.bgTertiary
      ),
      Spacer(),
      Row(end-aligned): Button "Cancel" (text), Button "Apply" (filled tokens.accent)
  )
)
```

Default selection: ATM ± 3 strikes given current spot. Apply returns `Set<double>` to the caller.

### 9.6 BuildupPill

Pill-shaped label, 8px horizontal padding, 4px vertical, radius 12. Background and text colour by classification:

| Buildup value | Background | Text |
|---|---|---|
| Long Buildup | `tokens.profit.withValues(alpha: 0.2)` | `tokens.profit` |
| Short Buildup | `tokens.loss.withValues(alpha: 0.2)` | `tokens.loss` |
| Short Covering | `tokens.info.withValues(alpha: 0.2)` | `tokens.info` |
| Long Unwinding | `tokens.warning.withValues(alpha: 0.2)` | `tokens.warning` |
| Neutral | `tokens.neutral.withValues(alpha: 0.2)` | `tokens.neutral` |

Text style `MyntWebTextStyles.caption(context)` with weight 600.

### 9.7 BasketChip (replaces the README's HandoffChip)

Bottom-right floating button, visible inside `InstaOptionsShell` when `instaOptionsBasketProvider.queuedLegs.isNotEmpty`.

```
PositionedDirectional(end 24, bottom 24,
  child Material(
    elevation 6, color: tokens.accent.withValues(alpha: 0.5), radius 28,
    child InkWell(
      onTap → showSnackBar("Order placement coming in a future release."),
      padding 16/20,
      child Row(
        Icon(Icons.shopping_basket, 18, white),
        SizedBox(w=8),
        Text("$n legs queued — coming soon", style: MyntWebTextStyles.body(context, color: tokens.textWhite).copyWith(fontWeight: FontWeight.w600))
      )
    )
  )
)
```

Note the reduced opacity on `accent` and the "coming soon" copy — these signal the disabled state. Slide-up animation on first appearance (`AnimatedSlide` 240 ms). **The widget MUST NOT navigate anywhere** until the deferred sprint (section 3) lands.

### 9.8 SideRail

Left rail inside `InstaOptionsShell`, width 220, background `tokens.bgSecondary`, right border 1px `tokens.border`.

```
ListView with the 9 sub-screen entries, each 44 tall, 16 padding-left, 12 padding-vertical.
Active entry: background tokens.bgTertiary, left 3px strip in tokens.accent.
Inactive entry: hover gives background tokens.bgTertiary @ 50% opacity.
Icon (Icons.<varies>) 20×20 tokens.textSecondary, label MyntWebTextStyles.body(context).
```

Icons per entry: Markets `dashboard`, Contributors `account_tree`, Chain `view_list`, OI Stats `bar_chart`, Trending OI `trending_up`, PCR `show_chart`, Per-Strike `candlestick_chart`, Buildup `layers`, Find Strategy `search`.

### 9.9 ChainLegBottomSheet (replaces the README's "right-click bottom sheet")

Reusable bottom sheet for the Option Chain and OI Buildup screens.

```
showModalBottomSheet(
  context, height 200, backgroundColor: tokens.bgSecondary,
  builder: (ctx) => Column(
    Text(tradingSymbol, style: MyntWebTextStyles.head(context)),
    Text("LTP $ltp  ·  IV $iv%  ·  Δ $delta", style: MyntWebTextStyles.body(context, color: tokens.textSecondary)),
    Row(
      FilledButton("Add 1 lot BUY", background: tokens.profit, white text,
        onTap: () { basketProvider.add(BasketLeg(...)); showSnackBar("Added — n legs queued (order placement coming soon)"); Navigator.pop(ctx); }),
      FilledButton("Add 1 lot SELL", background: tokens.loss, white text,
        onTap: ...same...)
    )
  )
)
```

The tap handler **only mutates the in-memory basket** and shows the toast. It does NOT navigate to `/strategy-builder`. This boundary is non-negotiable until section 3's deferred sprint lands.

---

## 10. Per-screen specifications

Each subsection contains: side-rail key, purpose, layout, widget tree, data inputs (refer to section 8), interactions, states, acceptance criteria. All "hand-off / navigate to strategy builder" behaviour is **removed**; all leg-add actions follow the section 9.9 pattern.

---

### 10.1 Markets Dashboard

**Side-rail key**: `markets` (default landing).

**Purpose**: at-a-glance market state across all F&O symbols.

**Visual layout** (1920×1080 reference; reflows to 1280 wide)

```
+----------------------------------------------------------------------------+
| SymbolExpiryBar (Symbol/Expiry disabled and dimmed; Exchange active)        |
+----------------------------------------------------------------------------+
| Page header: "Markets Dashboard" (MyntWebTextStyles.hero)                   |
| Sub-text "Updated HH:mm IST" (MyntWebTextStyles.caption)                    |
+-------------------------+-------------------------+------------------------+
| Long Buildup            | Short Buildup           | (12px gap)             |
| (bucket table)          | (bucket table)          |                        |
| 360 wide each, 320 tall |                         |                        |
+-------------------------+-------------------------+------------------------+
| Short Covering          | Long Unwinding          |                        |
| (bucket table)          | (bucket table)          |                        |
+-------------------------+-------------------------+------------------------+
| KPIs row (advances, declines, unchanged) — KpiCard ×3                       |
+----------------------------------------------------------------------------+
| Index Summary table (NIFTY/BANKNIFTY/FINNIFTY/MIDCPNIFTY/NIFTYNXT50/        |
| SENSEX/BANKEX) — 5-column DataTable2, full width                            |
+----------------------------------------------------------------------------+
```

**Bucket table widget** (one of four)

```
Card (color tokens.bgSecondary, border, radius 8, padding 0):
  Header row (height 40, padding-h 16, background tokens.bgTertiary):
    Icon (24×24, coloured by bucket),  Text(bucket name, MyntWebTextStyles.head)
  DataTable2:
    columns: [
      "Symbol"        (text, weight 600, 80 wide),
      "LTP"           (numeric, 70 wide),
      "Chg %"         (numeric, color-coded, 70 wide),
      "OI"            (numeric, formatOi, 60 wide),
      "ΔOI %"         (numeric, color-coded, 60 wide),
      "→"             (IconButton "Open chain", 32 wide)
    ]
    row height 36, alternating bg tokens.bgSecondary / (tokens.bgPrimary @ 30% mix)
    show top 8; "View all" link at bottom if >8 items
```

Bucket icon and colour:
- Long Buildup → `Icons.trending_up`, `tokens.profit`
- Short Buildup → `Icons.trending_down`, `tokens.loss`
- Short Covering → `Icons.refresh`, `tokens.info`
- Long Unwinding → `Icons.exit_to_app`, `tokens.warning`

**Data inputs**

- `GET /buildup/symbols?exchange=<active>` (section 8.13)
- `GET /market/snapshot` (section 8.15)

**Frontend derivations**

- Sort each bucket by `|oi_change|` descending
- Compute `Chg %` from `(ltp - prev_close) / prev_close * 100` (the response also provides `change_pct`; use it directly when present)

**Interactions**

- Tap a row → switch side-rail to `chain` with the row's symbol + nearest expiry pre-selected (no URL change; selection provider mutated)
- Tap "View all" → expand the bucket card to show full list (max height 480, scrollable inside)
- Tap the row's "→" icon → same as row tap

**States**

- Loading: card body shows a skeleton (4 lines, 16 tall each, gap 12)
- Empty (all four buckets empty) → centred message "All symbols neutral right now. Live updates resume during market hours."
- Error → inline ErrorBanner inside the card

**Refresh**: every 4 s while market open; once per 30 s outside hours.

**Order placement**: none in v1 (deferred per section 3).

**Acceptance**

1. Four bucket cards render within 1.5 s of page load.
2. Tapping HDFCBANK in Long Buildup switches the side-rail to Chain and sets `selectionProvider.symbol = 'HDFCBANK'`.
3. With market closed, shows the "all neutral" empty state while the index summary table still populates.

---

### 10.2 Index Contributors

**Side-rail key**: `contributors`.

**Purpose**: per-index breakdown of which constituents are pulling the index up or down today.

**Visual layout**

```
+-------------------------------------------------+
| SymbolExpiryBar (Symbol/Expiry disabled)        |
+-------------------------------------------------+
| Tabs (height 44, full width):                   |
| NIFTY · BANKNIFTY · FINNIFTY · MIDCPNIFTY ·     |
| SENSEX · BANKEX                                 |
| Active tab: bottom 3px strip in tokens.accent.  |
+-------------------------------------------------+
| Row 16/24:                                       |
|  ToggleButtons( Stock | Sector ) (h=32)         |
|  Spacer                                          |
|  Text "Sum: <+/- N.NN points>" (head)           |
+-------------------------------------------------+
| DataTable2 (full remaining height):              |
| Stock mode columns:                              |
|   Company | Sector | LTP | Change % | Pts       |
| Sector mode columns:                             |
|   Sector | Avg Change % | Total Pts              |
+-------------------------------------------------+
```

**Column widths (Stock mode)**: 200 / 240 / 100 / 100 / 100, then expand-fill on remaining. Row height 36. Header height 40 with `para()` style.

**Cell formatting**

- `Pts` column uses `MyntWebTextStyles.price(context)`. Positive values prefixed with `+`, coloured `tokens.profit`. Negative coloured `tokens.loss`.
- `Change %` formatted with 2 decimals and `%` suffix, coloured.
- LTP: 2 decimals, `MyntWebTextStyles.tableCell(context)`.

**Sector view derivation**

Group by `sector`, then per group:
- `Avg Change %` = arithmetic mean of constituent `change_pct`
- `Total Pts` = sum of constituent `index_points`

Sort by `|Total Pts|` descending.

**Data inputs**

- `GET /contributors/{index}` (section 8.16)

**Interactions**

- Tap a stock row in Stock mode → opens a 480×320 popover positioned to the right of the row showing a mini spot intraday chart sourced from `/spot/timeseries?symbol=<stock>`
- Sort by tapping any column header (toggle asc/desc)

**States**

- Loading: full-table skeleton, 12 rows
- Empty (rare): "No constituents for $INDEX"
- Error: inline ErrorBanner

**Refresh**: every 4 s while market open.

**Order placement**: none.

**Acceptance**

1. Sum of all `index_points` equals the index's total point change within ±0.5 points.
2. Sector aggregation total per sector equals the sum of its stock rows within ±0.1 points.
3. Switching index tabs preserves the Stock/Sector toggle.

---

### 10.3 Option Chain (with Greeks)

**Side-rail key**: `chain`.

**Purpose**: strike-by-strike chain with Greeks and OI bar visualisation. Primary surface for browsing strikes and (in a future sprint) building a basket.

**Visual layout**

```
+--------------------------------------------------------------+
| SymbolExpiryBar                                                |
+--------------------------------------------------------------+
| Row 16/24, height 48:                                          |
|  Text "Spot: 23,907.15"  (price style)                         |
|  · Text "FUT: 23,996.70" (price style)                         |
|  · Text "ATM: 23,900"     (body style)                         |
|  Spacer                                                        |
|  Dropdown "Change ref: Prev Day | Open | 5m | 15m | 1h" w=180 |
|  ToggleButtons "Bar | %" w=80                                  |
|  Switch "Show Greeks" w=140                                    |
+--------------------------------------------------------------+
| DataTable2:                                                    |
|  Rows: one per strike (no FUT row in this table)              |
|  Sticky header, sticky ATM row (highlighted, see below)       |
|  Column groups (CE | STRIKE | PE):                            |
+--------------------------------------------------------------+
```

**Column spec** (left to right)

| Column | Width | Style | Notes |
|---|---|---|---|
| Δ (CE) | 60 | tableCell | Hidden when Greeks toggle off |
| OI (CE) | 110 | price inside OIBarCell | Bar fills from LEFT, tokens.barCe |
| ΔOI % (CE) | 70 | tableCell, color-coded | positive `tokens.profit`, negative `tokens.loss` |
| IV (CE) | 60 | tableCell | Hidden when Greeks toggle off |
| LTP (CE) | 80 | price | |
| ΔLTP % (CE) | 64 | tableCell, coloured | |
| **STRIKE** | 100 | price, centred | ATM row background = `tokens.atmHighlight` |
| ΔLTP % (PE) | 64 | tableCell, coloured | |
| LTP (PE) | 80 | price | |
| IV (PE) | 60 | tableCell | Hidden when Greeks toggle off |
| ΔOI % (PE) | 70 | tableCell, coloured | |
| OI (PE) | 110 | OIBarCell, bar fills from RIGHT, tokens.barPe | |
| Δ (PE) | 60 | tableCell | Hidden when Greeks toggle off |
| PCR | 60 | tableCell | Strike-level PCR = pe.oi / max(ce.oi, 1) |

Row height 32 (dense). Header height 40 with `para()`. Vertical divider 1px `tokens.border` between CE / STRIKE / PE column groups.

**ATM row highlighting**

- Row background: `tokens.atmHighlight`
- 2px strip on the very left edge of the row in `tokens.accent`
- Sticky-scrollable: the ATM row stays visible at the top of the visible window via `DataTable2.fixedTopRows`

**Data inputs**

- `GET /analytics/chain` on mount + selection change (section 8.17)
- `GET /oi/change?last_minutes=N` when Change-ref dropdown changes (section 8.6)
- `GET /spot` on mount, then WS `spot` topic
- WS `chain_delta` and `iv_update` subscriptions while the screen is mounted

**Frontend derivations**

- ATM = strike with `min |strike - spot|`
- Per-cell OI bar width = `oi / max(oi across visible rows)`
- Strike-level PCR = `pe.oi / max(ce.oi, 1)` rounded to 2 decimals
- Change % colour: positive `tokens.profit`, negative `tokens.loss`, zero `tokens.textSecondary`

**Interactions**

- Tap a strike row → switch side-rail to `strike` with `selectionProvider.strike = <row>` (no URL change)
- Right-click (or long-press on touch) any CE or PE cell → show `ChainLegBottomSheet` (section 9.9) — tap BUY/SELL only enqueues to basket + toast; no navigation
- Header taps sort that column (asc/desc toggle)

**States**

- Loading: table skeleton, 20 rows
- Empty: "No chain data — selection may be stale" + Retry
- Error: inline ErrorBanner with `code` + Retry
- Stale (WS disconnected > 5 s): amber chip "Stale — Reconnecting…" in the top-right corner of the table

**Refresh strategy**

- REST: on mount, on selection change, on Change-ref dropdown change
- WS: per-cell incremental updates. Use scoped notifier rebuilds per row so a single LTP delta doesn't repaint the entire table

**Order placement**: none in v1; the bottom sheet only mutates the in-memory basket (section 3).

**Acceptance**

1. Greeks columns populated for all ATM ± 20 strikes.
2. Rows with `iv_solver_ok: false` show `—` for IV and all Greeks.
3. ATM row visually highlighted with the strip and stays sticky on scroll.
4. OI bar widths recompute when chain max OI changes (animate 200 ms).
5. Right-clicking an ATM CE cell shows the bottom sheet; tapping BUY enqueues a leg; BasketChip updates count and shows the "coming soon" toast on tap.

---

### 10.4 OI Statistics

**Side-rail key**: `oiStats`.

**Purpose**: cumulative CE/PE OI and per-strike OI bars with day-change overlay.

**Visual layout**

```
+--------------------------------------------------------------+
| SymbolExpiryBar                                                |
+--------------------------------------------------------------+
| Row 16/24:                                                     |
|  Switch "Show OI change overlay" (default ON)                  |
|  Spacer                                                        |
|  Text "Last computed: HH:mm:ss" (caption)                      |
+----------+---------------------------------------------------+
| Cumulative| Per-strike OI bars                                |
| panel     |  (BarChart from fl_chart — config below)          |
| 280 wide  |                                                    |
| 400 tall  |  Below the chart: BrushChart (height 64,           |
|           |  acts as zoom selector for the main chart's x)     |
+----------+---------------------------------------------------+
```

**Cumulative panel** (left, 280×400, card)

A single vertical stacked bar 80px wide centred horizontally. Bottom segment: total CE OI (`tokens.barCe`). Top segment: total PE OI (`tokens.barPe`). On top of each segment, a lighter overlay of equal width but height proportional to the change (`*_change`): green tint for positive, red tint for negative. Numeric labels next to each segment via `formatOi`.

Bottom of card: KPI row of three KpiCards: `Total CE OI`, `Total PE OI`, `PCR`.

**Per-strike BarChart (fl_chart specifics)**

- `BarChart` with `groupsSpace: 6`, `alignment: BarChartAlignment.spaceBetween`
- Each x position holds a `BarChartGroupData` with two `BarChartRodData`:
  - Rod 1: CE OI, colour `tokens.profit`, width 8, drawn ABOVE the x-axis (positive y)
  - Rod 2: PE OI, colour `tokens.loss`, width 8, drawn BELOW the x-axis (`fromY: -peOi, toY: 0`)
- When "Show OI change overlay" is on, each rod has a second stacked-rod-overlay 50% opacity painted on top for `ΔOI`
- x-axis labels: every 5th strike (rotation 0°, `caption()` style `tokens.textSecondary`)
- y-axis labels: 5 ticks via `formatOi`
- y-axis grid: dashed 1px `tokens.border @ 30%`, 5 horizontal lines
- Vertical line at the current spot x-position: dashed 1px `tokens.accent`, label "ATM 23,900" just above the chart top
- Tooltip on hover: `Strike: 23,900 · CE OI: 6.85L (+0.05L) · PE OI: 6.24L (-0.10L)`
- Zoom is the brush chart below, not the main chart

**BrushChart** (height 64)

A smaller `BarChart` with reduced detail (rods 2px wide, no tooltips), with a draggable highlight rectangle over the visible window. Dragging the rectangle pans the main chart's x range.

**Data inputs**

- `GET /oi/aggregate` (section 8.10) — cumulative panel
- `GET /analytics/chain` (section 8.17) — per-strike bars (read only the OI fields)
- `GET /spot` — spot marker

**States**

- Loading: cumulative-panel skeleton + bar-chart skeleton
- Empty + `aggregate.ready: false` → cumulative panel shows "Aggregator warming up — try again in a minute". Per-strike bars still render if `/analytics/chain` has data.
- Error: inline ErrorBanner

**Refresh**: every 4 s.

**Order placement**: none.

**Acceptance**

1. Sum of per-strike CE OI matches `aggregate.total_ce_oi` within 0.1% once `ready: true`.
2. Spot vertical line is accurate to ± 0.5 strike spacing.
3. Brush window dragging updates the main chart x range within 50 ms.

---

### 10.5 Trending OI

**Side-rail key**: `trending`.

**Purpose**: intraday view of CE vs PE OI for a chosen set of strikes, plus a per-bucket table.

**Visual layout**

```
+--------------------------------------------------------------+
| SymbolExpiryBar                                                |
+--------------------------------------------------------------+
| Row 16/24:                                                     |
|  Button "Change strikes" (outlined, h=32)                     |
|  · Selected strikes as chips (height 24)                       |
|  Spacer                                                        |
|  Dropdown "Bucket size: 3 min | 5 min | 15 min" w=160         |
+--------+-----------------------------------------------------+
| Top half: two charts side by side, 50% width each              |
|  Left: Trending Sentiment chart                                |
|  Right: Cumulative OI chart                                    |
| Heights: 320                                                    |
+----------------------------------------------------------------+
| Bottom half: BucketTable, full width, 360 tall, scrollable      |
+----------------------------------------------------------------+
```

**Trending Sentiment chart (LineChart, fl_chart)**

- Left y-axis: Spot price line (`tokens.accent`, width 2)
- Right y-axis: Sentiment area chart, plotted as a `LineChartBarData` with `belowBarData: BarAreaData(show: true, gradient: ...)` (green when positive, red when negative)
- Sentiment range clamped to `[-1, +1]`
- Sentiment formula on each bucket `t`:
  ```
  CumPutOI(t)  = Σ_K (oi at K, type PE, time t)
  CumCallOI(t) = Σ_K (oi at K, type CE, time t)
  ΔCumPutOI(t)  = CumPutOI(t)  - CumPutOI(t-1)
  ΔCumCallOI(t) = CumCallOI(t) - CumCallOI(t-1)
  Sentiment(t) = (ΔCumPutOI - ΔCumCallOI) / (|ΔCumPut| + |ΔCumCall| + 1)
  ```
- Tooltip: `13:09 · Spot 23,910 · Sentiment +0.42 · PCR 0.84`

**Cumulative OI chart (LineChart, fl_chart)**

- Two `LineChartBarData`:
  - CE OI line: `tokens.profit`, width 2, smoothed via `isCurved: true`
  - PE OI line: `tokens.loss`, width 2, smoothed
- Single y-axis (left). x-axis is time, same range as the Sentiment chart
- Vertical reference lines at session open and current minute, dashed `tokens.textMuted`
- Tooltip: `13:09 · CE OI 6.85L · PE OI 6.24L · PCR 0.91`

**BucketTable (DataTable2)**

Columns:

| Col | Width | Style | Notes |
|---|---|---|---|
| Time | 80 | tableCell | `HH:mm` |
| LTP | 90 | price | spot at bucket close |
| ΔCallOI | 110 | tableCell, color-coded | green if +, red if − |
| ΔPutOI | 110 | tableCell, color-coded | |
| DiffOI | 110 | tableCell, color-coded | ΔPutOI − ΔCallOI |
| Dir | 50 | icon | `▲` if PCR(t) > PCR(t-1), `▼` if <, `—` else |
| ΔDir | 90 | tableCell | PCR(t) − PCR(t-1) |
| Dir % | 70 | tableCell, color-coded | ΔDir / PCR(t-1) × 100 |
| PCR | 60 | price | |

Sorted descending by time. Row height 32. Header 40.

**Data inputs**

- `GET /oi/multistrike/timeseries?strikes=...&types=CE,PE` (section 8.8)
- `GET /spot/timeseries` (section 8.4)
- WS `oi_bucket_close` subscription (section 8.WS)

**Frontend derivations**

- Build the bucket time index from the union of timestamps in all returned series
- For each bucket, compute `CumPutOI`, `CumCallOI`, `ΔCum*`, `PCR`, `Sentiment` as above

**Interactions**

- "Change strikes" → `StrikePicker` (section 9.5) — default ATM ± 3 strikes
- Hover a chart x position → cross-highlight the corresponding row in the BucketTable (scroll to row + brief flash background `tokens.accent @ 20% opacity`)
- Tap a table row → seek both charts to that bucket (vertical playhead line)
- Bucket-size dropdown → re-aggregate client-side (3-min buckets are the native granularity)

**States**

- Loading: skeleton lines for both charts + 6 skeleton rows in the table
- Empty (market closed): both charts show "Market closed" overlay; table shows latest available buckets if any
- Error: inline ErrorBanner

**Refresh**: REST on mount, WS push every 3 min bucket close. Selection is persisted to `Preferences` so picked strikes survive page refresh.

**Order placement**: none from this screen.

**Acceptance**

1. Sentiment area shaded green above zero, red below.
2. Selected strikes persist across symbol/expiry change AND across page refresh.
3. Bucket table is sorted descending by time.
4. Hovering an x position cross-highlights the matching row within 100 ms.

---

### 10.6 PCR Ratio

**Side-rail key**: `pcr`.

**Purpose**: chain-level PCR over time with spot overlay.

**Visual layout**

```
+--------------------------------------------------------------+
| SymbolExpiryBar                                                |
+--------------------------------------------------------------+
| Row of 3 KpiCards (Current PCR · Day High · Day Low)           |
| height 72, padding 24                                          |
+--------------------------------------------------------------+
| LineChart, full remaining height, padding 24                   |
+--------------------------------------------------------------+
```

**LineChart (fl_chart)**

- Two y-axes: left PCR (range auto with min 0.5 floor, max 1.5 ceiling unless data exceeds), right Spot price
- PCR series: line width 2, coloured by zone:
  - `pcr > 1` → `tokens.profit`
  - `pcr < 0.7` → `tokens.loss`
  - else → `tokens.textSecondary`
  - Use `LineChartBarData.gradient`; if fl_chart's stop-colouring is awkward, split into three masked series
- Spot series: line width 1.5, colour `tokens.accent @ 70%`
- x-axis: time, format `HH:mm`
- Horizontal reference lines: dashed at `pcr = 1.0` and `pcr = 0.7`, colour `tokens.textMuted @ 50%`
- Touch crosshair: tap-and-drag shows a vertical line + tooltip with `time · pcr · spot`
- Zoom: pinch / wheel; pan: drag

**KpiCard values**

- Current PCR: last value in series
- Day High: max
- Day Low: min

**Data inputs**

- `GET /oi/pcr/timeseries` (section 8.11)

**States**

- Loading: chart skeleton
- Empty: full-card placeholder "PCR series will appear once the aggregator runs"
- Error: ErrorBanner

**Refresh**: REST every 60 s.

**Order placement**: none.

**Acceptance**

1. Right-axis spot aligns to the same x range as left-axis PCR.
2. Crosshair tooltip shows three values within 50 ms of touch.
3. Pinch zoom maintains aspect ratio of axis ranges.

---

### 10.7 Per-Strike Options Chart

**Side-rail key**: `strike`.

**Purpose**: for a chosen strike, show how Call LTP+OI, Put LTP+OI, and Call-vs-Put OI evolve through the day. The most common follow-on from Option Chain.

**Visual layout**

```
+--------------------------------------------------------------+
| SymbolExpiryBar                                                |
+--------------------------------------------------------------+
| Row 16/24, height 64:                                          |
|  Text "Strike <strike>" (hero)                                 |
|  · Text "ATM ±N" (caption)                                     |
|  Spacer                                                        |
|  Dropdown "Strike" (lists all strikes in chain) w=140         |
+----------------------+---------------------------------------+
| Left half (50%)      | Right half (50%)                       |
|  Call OI Analysis    |  Put OI Analysis                       |
|  DualAxisLineChart   |  DualAxisLineChart                     |
|  height 320           |  height 320                            |
|  B / S badges         |  B / S badges                           |
+----------------------+---------------------------------------+
| Bottom: Call vs Put OI Analysis, full width, height 280        |
+----------------------------------------------------------------+
```

**DualAxisLineChart** (for Call OI Analysis and Put OI Analysis)

Workaround for fl_chart's single-axis limitation: render two `LineChart` widgets in a `Stack` aligned to the same x range; the bottom one drives x and the top one is `transparent` for hit-testing.

- Bottom chart (LTP): series colour `tokens.textPrimary`, width 2. y-axis on left.
- Top chart (OI): series colour `tokens.barCe` (Call) or `tokens.barPe` (Put), width 2 with `BarAreaData(show: true, gradient)`. y-axis on right.
- x-axis labels every 30 min, `HH:mm`
- Tooltip on touch: `13:09 · LTP 445.25 · OI 6.85L`

**B / S badges** (top-right of each chart, in the card header)

```
Container, padding 4/8, radius 12, background tokens.bgTertiary
Row:
  Mini button "B" — circle 28, background tokens.profit, white "B"
  Gap 6
  Mini button "S" — circle 28, background tokens.loss, white "S"
```

Tap `B` → `basketProvider.add(BasketLeg(side: 'B', ...))` + toast "Added — n legs queued (order placement coming soon)". Tap `S` → same with `side: 'S'`. **No navigation.**

**Call vs Put OI Analysis** (bottom, full width)

A single LineChart with two `LineChartBarData` series:
- Call OI line: `tokens.profit`, width 2
- Put OI line: `tokens.loss`, width 2
- Single y-axis with shared scale
- Vertical "writer accumulation" annotation: if for a contiguous span ≥ 3 buckets the OI rises while LTP falls (or vice versa), draw a faint vertical band `tokens.warning @ 15%` across that span

**Data inputs**

- `GET /oi/timeseries?option_type=CE&strike=<K>` (section 8.9)
- `GET /oi/timeseries?option_type=PE&strike=<K>` (section 8.9)

**Interactions**

- Strike dropdown → updates `selectionProvider.strike` → reloads charts
- B / S badges → `basketProvider.add(...)` + toast (no navigation)

**States**

- Loading: each chart skeleton
- Empty: chart shows "No bars yet — backfill in progress"
- Error: ErrorBanner

**Refresh**: REST per minute.

**Order placement**: deferred per section 3; badges only mutate the in-memory basket.

**Acceptance**

1. LTP and OI series readable on independent scales (one does not dwarf the other).
2. Writer-accumulation bands appear only when the 3-bucket rule fires.
3. Strike dropdown reloads the three charts within 1 s.
4. Tapping B enqueues a BUY leg; BasketChip count increments; toast appears.

---

### 10.8 OI Buildup

**Side-rail key**: `buildup`.

**Purpose**: per-option-contract buildup classification table.

**Visual layout**

```
+--------------------------------------------------------------+
| SymbolExpiryBar                                                |
+--------------------------------------------------------------+
| Row 16/24:                                                     |
|  ToggleButtons "All | CE | PE | FUT", h=32                    |
|  Spacer                                                        |
|  Dropdown "Sort by: |ΔOI| desc | Strike asc"  w=200           |
|  Text "n contracts" (caption)                                  |
+--------------------------------------------------------------+
| DataTable2 full remaining height:                              |
|  Columns:                                                       |
|    Symbol (trading_symbol, 200)                                 |
|    Type (CE/PE/FUT, 60)                                         |
|    Strike (numeric, 90)                                         |
|    LTP (numeric, 90)                                            |
|    ΔLTP % (numeric, color-coded, 90)                            |
|    OI (numeric formatOi, 110)                                   |
|    ΔOI (numeric formatOi, color-coded, 110)                     |
|    Buildup (BuildupPill, 130)                                   |
|  Row height 36                                                  |
+----------------------------------------------------------------+
```

**Row hover**: background `tokens.bgTertiary`.

**Data inputs**

- `GET /oi/buildup` (section 8.12)
- WS `chain_delta` to keep LTP and OI live

**Frontend derivations**

- Apply filter toggle
- Apply sort dropdown
- Pill colour from `BuildupPill` widget (section 9.6) — server values, no client reclassification

**Interactions**

- Tap a row → switch side-rail to `strike` with that strike selected
- Right-click row → `ChainLegBottomSheet` (section 9.9) — same enqueue + toast pattern, no navigation
- Header tap on Strike / OI / ΔOI → sort

**States**

- Loading: 12-row skeleton
- Empty: "No data for this expiry"
- Stale (WS disconnected > 5 s): top-right amber chip "Stale"

**Refresh**: REST every 4 s + WS deltas.

**Order placement**: deferred per section 3.

**Acceptance**

1. BuildupPill matches the backend's `buildup` value exactly (no client reclassification).
2. Filter toggle and sort persist across side-rail navigation (in-memory provider state, not URL in v1).
3. ΔOI cell respects the buildup colour rules.

---

### 10.9 Find Strategy

**Side-rail key**: `findStrategy`.

**Purpose**: backend-driven strategy scanner. User picks direction + min reward, server returns ranked viable strategies.

**Visual layout**

```
+--------------------------------------------------------------+
| SymbolExpiryBar                                                |
+--------------------------------------------------------------+
| Filter card (background tokens.bgSecondary, padding 24, radius 8):
|  Row, gap 16:                                                  |
|   Dropdown "Direction: Positive | Negative | Neutral" w=200   |
|   ToggleButtons "₹ | %"  w=80                                  |
|   NumberField "Min reward"  w=140                              |
|   Spacer                                                        |
|   ElevatedButton "Run scan" (background tokens.accent) w=140  |
+--------------------------------------------------------------+
| Results list (vertical, gap 12, padding 24)                    |
|  Each result is a StrategyCard:                                |
+--------------------------------------------------------------+
```

**StrategyCard layout** (radius 8, border 1px tokens.border, background tokens.bgSecondary, padding 20)

```
Row, height 48:
  Text template_name (head)
  Spacer
  KPI cluster (horizontal):
     "Max P&L: +5,538.69"   colour tokens.profit
     "Max Loss: -445.25"    colour tokens.loss
     "BE: 24,325.53"        colour tokens.textSecondary
  Spacer
  IconButton "Inspect" (Icons.fullscreen, 24)
  ElevatedButton "Add to basket" (background tokens.accent, 32 tall)

Divider 1px tokens.border, full width

Legs table (compact DataTable2, row height 30):
  Columns: Side · Symbol · Lot · Strike · CE/PE · LTP · OI
```

**Side** column shows a chip — green "B" for BUY, red "S" for SELL (24×20 rounded rectangle, white letter centred).

**Data inputs**

- `POST /strategy/scan` (section 8.20)

**Interactions**

- Run scan button → POST + render results below
- "Add to basket" → `basketProvider.clear(); basketProvider.add(...for each leg...);` + toast "Strategy queued — order placement coming soon" (no navigation)
- "Inspect" → expand the card to show payoff math inline (Max Profit, Max Loss, all Breakevens, premium estimate). Optional in v1.
- Click a breakeven number → copy to clipboard + brief toast "Copied"

**States**

- Initial (no scan run yet) → empty state: centred icon + text "Choose filters and tap Run scan"
- Loading: card skeleton (5 cards)
- Empty results: "No strategies match these filters — relax the min reward"
- Error: ErrorBanner

**Refresh**: on-demand only.

**Order placement**: deferred per section 3; "Add to basket" only mutates the in-memory basket.

**Acceptance**

1. Returns within 1 s for the nearest-week expiry (or fixture).
2. Direction `Positive` returns only Bullish-templated strategies (server filters).
3. "Add to basket" replaces existing queued legs and updates BasketChip count.
4. Breakeven copy-to-clipboard works and toasts within 200 ms.

---

## 11. Cross-cutting: error, loading, empty, stale states

Reuse existing project primitives wherever they fit:

- **Loading skeletons** — match the final shape; linear gradient shimmer between `tokens.bgSecondary` and `tokens.bgTertiary`, 1.5 s loop. For full-screen loaders use [lib/sharedWidget/mynt_loader.dart](lib/sharedWidget/mynt_loader.dart).
- **Empty** — use [lib/sharedWidget/no_data_found_web.dart](lib/sharedWidget/no_data_found_web.dart) when the spec doesn't require a screen-specific empty message; otherwise centred icon + `head()` title + `body()` reason + optional secondary action button.
- **Error (non-2xx)** — inline ErrorBanner: card with background `tokens.loss @ 10%` + border `tokens.loss`. Title = `error.code`. Body = `error.message`. Right-aligned "Retry" button.
- **Stale (WS down > 5 s)** — amber chip in top-right of the affected panel: "Stale — Reconnecting…" (`tokens.warning @ 20%` background, text `tokens.warning`). [lib/sharedWidget/socket_disconnect.dart](lib/sharedWidget/socket_disconnect.dart) handles the full-app variant.
- **Offline** — [lib/sharedWidget/no_internet_widget.dart](lib/sharedWidget/no_internet_widget.dart) handles offline detection; let it take over the shell if `connectivity_plus` reports no internet.

| State | When to render |
|---|---|
| Loading | First fetch, or selection change, or explicit Retry |
| Empty | `200` with empty body / `ready: false` / market closed |
| Error | Any non-2xx from the OI Data backend |
| Stale | WS dropped for > 5 s while screen mounted |

---

## 12. Performance

| Concern | Budget |
|---|---|
| First contentful paint (Markets Dashboard) | < 1.5 s on cold cache |
| Time to interactive | < 3 s on cold cache |
| Chain row repaint on WS push | < 100 ms per cell |
| OI Stats full chart re-render on 4 s tick | < 200 ms |
| Find Strategy scan round-trip | < 1 s for nearest week |
| WS reconnect attempt cycle | 1 s / 2 s / 4 s / 8 s / 16 s / 30 s cap |

Caching:
- REST: in-memory only via `ChangeNotifierProvider` fields
- Reference data (`/reference/lot_size`, `/reference/index/{index}`, `/reference/risk_free_rate`): `Preferences` keyed on `as_of` / `last_rebalance`; refresh when the date changes
- Service workers: do NOT use for data endpoints

Responsive helpers: prefer [lib/sharedWidget/safe_layouts.dart](lib/sharedWidget/safe_layouts.dart) (`SafeColumn`, `SafeRow`) where the screen has to reflow between 1280 and 1920 wide.

---

## 13. Testing

| Layer | What to test |
|---|---|
| Unit | `Sentiment(t)` formula on a fixture; `formatOi`; ATM detection; buildup pill colour mapping; basket provider add/remove/clear |
| Widget golden | Each of the 9 sub-screens at 1920×1080 and 1280×800, light + dark themes (4 goldens per screen → 36 goldens) |
| Integration | From Chain → tap row → Per-Strike → B badge → BasketChip count increments → tap chip → toast appears (NO navigation in v1) |
| Performance | Profile Chain with 200 rows + 5/s WS deltas; assert ≥ 50 fps |
| Contract | Stub backend that serves the section-8 sample JSON; full provider state tests |

Tests live in `test/insta_options/`. Run via `flutter test test/insta_options/`.

---

## 14. Build order (phases)

This matches the phase ordering in the implementation plan at `~/.claude/plans/instaoptions-feature-readme-md-i-wanted-twinkling-leaf.md`. Each phase ends with a dedicated QA sub-agent (Chrome DevTools MCP) and a git commit.

| Phase | Scope | What works at the end |
|---|---|---|
| 0 | Rewrite this README | This document itself; `INSTAOPTIONS_HANDOFF.md` created |
| 1 | Plumbing | config, API client, WS client, hand-written models, theme tokens, format wrappers; `/insta-options` route registers; nav-drawer menu entry; side-rail shell with 9 placeholder screens; `/health` smoke check; fixture mode for offline QA |
| 2 | Option Chain (screen 3) | SymbolExpiryBar, OIBarCell, ChainLegBottomSheet; chain repo + chain provider; ATM sticky row; WS deltas wired; basket enqueue + toast |
| 3 | OI Buildup (screen 8) | BuildupPill, filter/sort persistence, row-tap → strike screen; right-click bottom sheet reused |
| 4 | OI Statistics + PCR (screens 4 + 6) | fl_chart BarChart with above/below x-axis, BrushChart, KpiCards, dual-axis PCR LineChart |
| 5 | Per-Strike Chart (screen 7) | DualAxisLineChart, B/S badges, writer-accumulation band |
| 6 | Trending OI (screen 5) | StrikePicker, sentiment chart, cumulative chart, bucket table; WS `oi_bucket_close` wired |
| 7 | Markets Dashboard (screen 1) | 4 bucket cards, advances/declines KPIs, index summary table |
| 8 | Index Contributors (screen 2) | TabBar of indices, Stock / Sector toggle, mini-chart popover |
| 9 | Find Strategy (screen 9) | filter card, StrategyCard, scan results, breakeven clipboard |
| 10 | Polish | accessibility pass, dark/light goldens, error/empty/stale state polish, performance profiling, Lighthouse audit |
| 11 | Open follow-ups | Document order-placement wiring requirements (deferred) in `INSTAOPTIONS_HANDOFF.md` |

Per-phase QA is run via a dedicated sub-agent driving Chrome DevTools MCP (`navigate_page`, `take_snapshot`, `take_screenshot`, `list_console_messages`, `list_network_requests`, `resize_page`). QA evidence is saved to `.claude/insta-options-qa/phase-N/`. Each phase commits to git only after QA reports PASS.

---

## 15. Acceptance smoke test (run end-to-end before Phase 10 sign-off)

1. Navigate to the nav drawer → "InstaOptions Analytics". Land on Markets Dashboard inside the right panel.
2. Confirm 4 bucket tables render. Tap an entry → side-rail switches to Option Chain for that symbol.
3. Greeks columns are populated for ATM ± 20. ATM row is highlighted and sticky.
4. Right-click an ATM CE cell → bottom sheet → "Add 1 lot BUY". BasketChip appears: "1 leg queued — coming soon".
5. Tap a strike row → side-rail switches to Per-Strike Options Chart. Confirm 3 charts render.
6. Tap the "B" badge on the Call OI chart → BasketChip updates to "2 legs queued — coming soon".
7. Navigate via side-rail to OI Statistics. Cumulative panel + per-strike bars render. Brush chart pans the main chart.
8. Navigate to PCR. Line chart with spot overlay renders.
9. Navigate to Trending OI. Default strikes ATM ± 3 selected. Sentiment shows green / red shading.
10. Open StrikePicker → choose ATM ± 5 → Apply. Charts and table redraw.
11. Navigate to Find Strategy. Pick Positive, ₹100, Run scan. ≥ 1 result.
12. Tap "Add to basket" on the top result → queued legs are REPLACED with this strategy's legs. BasketChip count updates.
13. Tap the BasketChip → toast appears: "Order placement coming in a future release." **No navigation.**
14. Toggle the host app's theme switcher. Every screen repaints using `MyntColors` dark equivalents — no hex literals visible.
15. Disconnect the network for 10 s. The StreamingDot turns red. Reconnect. Dot goes green. Chain catches up via `/stream/replay-since`. No missing minutes in Trending OI.

If all 15 steps pass, the build is done.

---

## 16. Cheat sheet for the agent (Mynt edition)

- One section, mounted at `/insta-options`. Internal navigation between the 9 sub-screens via a side-rail in `InstaOptionsShell` — no per-screen GoRoute.
- All backend calls go through `locator<InstaOptionsApi>()`. Base URL from `Preferences`. No hard-coded URLs in widget code.
- All Greeks come from `/analytics/chain` or the `iv_update` WS topic. Never recompute Greeks in Dart.
- One InstaOptions WebSocket, multiplexed by `InstaOptionsWsClient` (singleton via `locator`). Distinct from Mynt's `websocketProvider`. Subscribe per-screen via `Provider.dispose` cleanup.
- Error envelope `{ error: { code, message, detail } }` is structured everywhere. Surface `code` + `message` in `ErrorBanner`.
- Number formatting goes through `RupeeFormat` + the thin wrappers in `insta_options_format.dart`. No raw `toString` on numbers in widgets.
- Time formatting uses `DateFormat.Hm()` for display and the existing helpers in [lib/sharedWidget/functions.dart](lib/sharedWidget/functions.dart) for parsing.
- The basket lives in `instaOptionsBasketProvider`. It is in-memory only. **No hand-off to `/strategy-builder` in v1.** Tap shows a "coming soon" toast.
- Theme tokens come from `InstaOptionsTokens.of(context)` which resolves to `MyntColors` light/dark. **No hex literals in widget files.**
- Typography uses `MyntWebTextStyles.*` (Geist). No `Inter`, no `Roboto Mono`.
- Tables use `data_table_2`. Charts use `fl_chart` (fallback `syncfusion_flutter_charts` only when needed).
- Phase order in section 14. Don't skip. Each phase ends with QA + commit.
- Per-phase QA evidence in `.claude/insta-options-qa/phase-N/`. Handoff state in [INSTAOPTIONS_HANDOFF.md](INSTAOPTIONS_HANDOFF.md).
