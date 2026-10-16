# StockScanner Integration — Design Spec

**Status:** Approved (brainstorming phase)
**Date:** 2026-05-16
**Author:** Brainstormed with the user via the superpowers/brainstorming workflow
**Source spec:** `API_AND_PAGES_SPEC.md` (StockScanner Client Integration Spec)

---

## 1. Goal

Integrate the StockScanner backend (a FastAPI service exposing read-only stock research data — symbols, technical scanners, fundamentals, custom predicate scans) as a new "Scanner" feature inside the existing Mynt Plus Web Flutter app. Users land on a single "Scanner" entry point that opens a full-page area containing four sub-pages (Symbols, Scanners, Fundamentals, Custom Scans), each consuming the StockScanner JSON API.

The integration must:
- Reuse the existing Mynt Plus design system (`MyntColors`, `MyntWebTextStyles`, `shadcn_flutter`, `resolveThemeColor`)
- Support both light and dark themes end-to-end with zero hardcoded colors
- Follow established conventions for routing (`GoRouter` + `CustomizableSplitHomeScreen`), state (`Riverpod`), API (`ApiCore` mixins), and models (plain Dart classes with `fromJson`)

## 2. Non-goals

- No Chart tab on the Symbol detail (deferred — requires a charting library and significant effort)
- No client-side caching invalidation beyond the spec's stale-time guidance; users can re-trigger fetches to refresh
- No write access from the consumer except for the two POST/DELETE flows the spec exposes (saved fundamental screens, saved custom scans)
- No admin features (`/api/v1/jobs/*`, `/api/v1/admin/*`, `/api/v1/setup/*`, `/api/v1/meta`) — explicitly out of scope per spec §1
- Deliveries sparkline is dropped (would require a chart library)

## 3. Backend Contract

**Base URL:** `http://192.168.5.47:8000` (dev / internal network). Added to `lib/api/core/api_link.dart` as `stockScannerBaseURL` with a `TODO` comment to swap for the production host when ready.

**API prefix:** `/api/v1` — exposed as `stockScannerApi` getter.

**Auth:** Assumes `PUBLIC_READ_MODE=true` on the backend (no `X-API-Key` header required). If the backend enforces auth later, the API key can be added to the request headers via a new override in `ApiCore`.

**CORS:** Assumed to be configured server-side (allow-origin set to the Mynt Plus web origin or `*` for development).

**Endpoint groups consumed:**
- `GET /api/v1/symbols/*` — universe, detail, OHLCV, technicals, performance, scanners, info, fundamental-score, financials, peers, holders, news, dividends, deliveries
- `GET /api/v1/scanners/*` — built-in scanner list, metadata, results, Excel export
- `GET|POST|DELETE /api/v1/scans/fundamental/*` — field catalog, presets, ad-hoc/saved fundamental screens, Excel export
- `GET|POST|DELETE /api/v1/scans/*` — custom predicate scanners (inline run, saved CRUD)

Endpoints explicitly **not** consumed: `/api/v1/jobs/*`, `/api/v1/admin/api-keys/*`, `/api/v1/setup/*`, `/api/v1/meta`.

## 4. User-facing Navigation

### 4.1 Entry point (desktop)

A single new menu item **"Scanner"** is appended to the existing "Options" dropdown in `customizable_split_home_screen.dart::_buildTradingToolsMenu` (line 2253). It uses `shadcn.LucideIcons.radar` and follows the same `MenuButton` styling as OptionZ / Option Flash / Strategy Builder / Scalper. The dropdown order becomes:

```
Options ▾
  ── OptionZ
  ── Option Flash
  ── Strategy Builder
  ── Scalper           Beta
  ── Scanner
```

### 4.2 Entry point (hamburger drawer)

The same item is added to `navigation_drawer_web.dart` under the `TRADE` section, between Strategy Builder and the `INVEST` section divider. Gated by a new `showScanner` bool flag passed through from `_openShadcnDrawer` in the split home screen, matching the existing visibility-control pattern.

### 4.3 Routing

Five new routes added to `web_router.dart`:

| Path | Behavior |
|---|---|
| `/scanner` | Opens Scanner shell; defaults to Symbols sub-page |
| `/scanner/symbols` | Opens Scanner shell with Symbols sub-page active |
| `/scanner/scanners` | Opens Scanner shell with Scanners sub-page active |
| `/scanner/fundamentals` | Opens Scanner shell with Fundamentals sub-page active |
| `/scanner/custom` | Opens Scanner shell with Custom Scans sub-page active |

All five resolve to `CustomizableSplitHomeScreen(initialRightPanel: ScreenTypeParam.scanner)` with an additional `initialScannerSubPage: ScannerSubPage?` constructor parameter (added as part of the `customizable_split_home_screen.dart` modification) that the shell reads on mount via the `scannerShellProvider`. Symbol detail and scanner detail are intra-page state — not in the URL.

## 5. Architecture

### 5.1 Scanner shell

`lib/screens/web/scanner/scanner_shell_screen.dart` — a `ConsumerStatefulWidget` rendered inside the right panel of `CustomizableSplitHomeScreen`. Two-column layout:

```
┌─────────────────────────────────────────────────────────────────┐
│  Scanner                                                         │
├──────────────┬──────────────────────────────────────────────────┤
│              │                                                  │
│  Symbols     │                                                  │
│  Scanners    │            <active sub-page content>             │
│  Fundamentals│                                                  │
│  Custom Scans│                                                  │
│              │                                                  │
└──────────────┴──────────────────────────────────────────────────┘
```

**Left rail (`ScannerLeftRail` widget):**
- Width: ~220px desktop, collapses to icon-only ~64px below 1100px, hidden behind a `LucideIcons.panelLeft` toggle below 760px
- Section label `RESEARCH` in uppercase muted caption
- Four nav items with `LucideIcons` icons: `search` (Symbols), `radar` (Scanners), `barChart3` (Fundamentals), `code2` (Custom Scans)
- Active state: 8px-radius pill background in `MyntColors.primary.withOpacity(0.10)`, primary-colored text/icon, semibold
- Hover state: `MyntColors.surfaceVariant` background
- Background: `resolveThemeColor(context, dark: MyntColors.surfaceDark, light: MyntColors.surfaceVariant)` so it visibly separates from content
- Vertical divider on right edge using `shadcn.Theme.of(context).colorScheme.border`

**Right content area:**
- Padding `EdgeInsets.symmetric(horizontal: 24, vertical: 20)` desktop, `12/16` mobile
- Top breadcrumb row (`ScannerBreadcrumb` widget): `Scanner › <SubPage> [ › <DetailName>]` — `Scanner ›` in caption, leaf in body, clickable segments
- Sub-pages rendered behind an `IndexedStack` to preserve scroll/filter state when switching tabs
- Independent scrolling per sub-page

**State management:** `scannerShellProvider` (`StateNotifierProvider`) holds `activeSubPage` (enum `ScannerSubPage { symbols, scanners, fundamentals, customScans }`). URL changes (via the `/scanner/*` routes) push into this provider on shell mount; the left rail dispatches updates when items are tapped.

### 5.2 Dark theme adherence

Every color in the new code resolves through one of:
- `resolveThemeColor(context, dark: MyntColors.xxxDark, light: MyntColors.xxx)`
- `shadcn.Theme.of(context).colorScheme.<token>`
- `MyntColors.primary` / `MyntColors.success` / `MyntColors.error` (semantic colors that work in both themes)

No hex literals. No `Colors.white` / `Colors.black`. Existing patterns from `customizable_split_home_screen.dart`, `holding_screen_web.dart`, and the navigation drawer are followed verbatim.

## 6. Sub-pages

### 6.1 Symbols sub-page

`lib/screens/web/scanner/sub_pages/symbols_sub_page.dart` — `ConsumerStatefulWidget` with two internal modes: **list** (default) and **detail**.

**List mode:**
- Sticky top: single search input, 480px max-width, with `LucideIcons.search` prefix. Placeholder "Search by ticker or company name". Debounce 200ms → `GET /api/v1/symbols?q={input}&page_size=20`
- Below search: card-list of up to 20 result rows. Each shows ticker (semibold body), name (muted body), exchange chip (`NSE`), trailing `LucideIcons.chevronRight`. Hover background `MyntColors.surfaceVariant`. Click → detail mode
- Empty state (no input): centered placeholder + "Search to find a stock by ticker or name. Try `RELIANCE`, `TCS`, or `INFY`."
- No-results state: centered "No stocks found for '{q}'. Try a different ticker."

**Detail mode:**

Sticky header band (~120px):
- Row 1: back button `LucideIcons.arrowLeft` "Back to search", ticker (`displaySmall` 24px bold), exchange chip, optional `N scanners` badge linking down to the Scans tab
- Row 2: latest price (`headlineMedium` semibold) from last OHLCV bar, day change `± abs (▲/▼ pct%)` in `MyntColors.success` / `MyntColors.error`, as-of timestamp (caption-tertiary)

Below the header: horizontal `shadcn.TabList` (scrollable on overflow) with **9 tabs**:

| Tab | Source endpoint | Notes |
|---|---|---|
| Prices | `GET /symbols/{t}/ohlcv` | Sortable shadcn table, last 90 bars default, "Load more" extends `from`, CSV export button |
| Scans | `GET /symbols/{t}/scanners` | Chips grouped by `group_name`. Click → switches to Scanners sub-page with that code preselected |
| Technicals | `GET /symbols/{t}/technicals` | Responsive `Wrap` grid of 220px metric cards with interpretive badges (thresholds in `utils/technical_interpretations.dart`) |
| Performance | `GET /symbols/{t}/performance` | Two-column: returns table left, pure-Flutter horizontal bar chart right. "vs NIFTY" column added when `relative` non-null |
| Fundamental | `GET /symbols/{t}/info` + `GET /symbols/{t}/fundamental-score` | Metric grid + six horizontal progress bars (color-thresholded per spec §4.1: ≥80 success, 60–79 emerald, 40–59 warning, <40 error) |
| Financials | `GET /symbols/{t}/financials?period=...&statement=...` | Two-level sub-tabs: `[Income · Balance · Cash Flow]` + `[Quarterly · Annual]`. Line items as rows, periods as columns. Values divided by 1e7 for ₹ Cr display |
| Peers | `GET /symbols/{t}/peers` | Sortable table; row click switches detail to that peer ticker in-place |
| Holders | `GET /symbols/{t}/holders` + `/news` + `/dividends` | Three collapsible sections. Each shows "Insufficient data" empty state when endpoint returns empty (per spec — Indian-stock data is patchy) |
| Deliveries | `GET /symbols/{t}/deliveries` | Sortable table: date, deliverable qty, delivery %. (Sparkline dropped.) |

Each tab is a separately lazy-loaded widget (built only when first tapped, then kept alive by `IndexedStack`). Each calls its own endpoint via a Riverpod `FutureProvider.family(ticker)`. Skeleton shimmer while loading; inline error card with a Retry button on failure.

### 6.2 Scanners sub-page

`lib/screens/web/scanner/sub_pages/scanners_sub_page.dart` — same two-mode pattern.

**List mode:**
- Left mini-rail (~180px inside the right content area): facet filter — "All (163)" + one row per `group_name` (Price / Volume / Technical / Candlestick) with counts. Selected facet pill-highlighted in primary. Below 900px width, collapses into a `LucideIcons.filter` button that opens a popover
- Top: search input "Search scanners by name or code" — filters client-side
- Main: shadcn table with columns `Group` (colored chip), `Sub-group`, `Display name`, `Code` (monospace, tertiary text). Sortable. Row click → detail mode
- Single fetch on mount: `GET /api/v1/scanners?page_size=2000`, cached in a Riverpod `FutureProvider` (staleTime 30 min). Client-side filter/sort after that

**Detail mode:**
- Sticky header: back button → "Back to scanners", display name (`displaySmall`), sub-group breadcrumb, `LucideIcons.download` "Export" button on right
- Expandable "View technical predicate" (`shadcn.Accordion`, collapsed by default) showing predicate JSON pretty-printed in a monospace code block with copy-to-clipboard
- Description block in `bodyMedium` secondary color
- Results table: sortable on every column, sticky header, `LucideIcons.info` tooltip per column header showing `columns[i].description` from the API. Columns rendered **verbatim from `response.columns`** — labels, fmt, descriptions are all server-provided. Format values via `formatColumn(value, fmt)`. Row click → switches to Symbols sub-page in detail mode with that ticker preselected
- Footer: "Showing X of Y matches" + (if `total > matches.length`) "Increase limit or refine" hint
- Export button → modal with `Visible` / `All columns` radio. Calls `GET /api/v1/scanners/{code}/export?columns=...` via `downloadXlsx` helper (`utils/download_xlsx.dart`)
- Data: `GET /api/v1/scanners/{code}/results?detail=true&limit=5000` (staleTime 60s)

### 6.3 Fundamentals sub-page

`lib/screens/web/scanner/sub_pages/fundamentals_sub_page.dart` — single mode (no detail page; results render inline).

Top stacked sections:
- **Presets** row — horizontal scrolling `shadcn.Chip`s from `GET /api/v1/scans/fundamental/presets`. Click → loads filters into builder
- **Saved screens** row — chips from `GET /api/v1/scans/fundamental/saved`. Click loads; trailing `LucideIcons.x` deletes via `DELETE /api/v1/scans/fundamental/saved/{id}` with confirm dialog

**Filter builder** (card with theme border):
- Repeating rows: `[Field ▼] [Op ▼] [Value input(s)] [yrs ▼] [✕]`
- Field dropdown grouped by `group` from `GET /api/v1/scans/fundamental/fields` (Categorical / Valuation / Profitability / Liquidity / Dividend / Price) via `shadcn.Select` with grouped items
- Op dropdown items derived from `dtype`:
  - `string` → `==, !=, in, not_in, is_null, is_not_null`
  - `number` / `pct` / `currency_inr` → `<, <=, >, >=, ==, !=, between, is_null, is_not_null` (+ `min_years` when field is in the multi-year-capable list: revenue_growth, earnings_growth, return_on_equity, return_on_assets, profit_margins, operating_margins, current_ratio, quick_ratio, debt_to_equity)
- Value input adapts to op: `between` → two inputs; `in`/`not_in` → comma-separated text; `is_null`/`is_not_null` → none; `min_years` → only years input. Percentage fields get `%` suffix and `value / 100` conversion on submit
- "Years" sidecar (50px wide) appears only for multi-year-capable fields with comparison ops. Tooltip: "Optional. Compares against the median of the past N years from annual statements."
- Footer of builder: `+ Add filter` text button left; right side: radio `Missing data: Exclude / Include` (`treat_null_as`), `Sort by ▼` field, `Sort dir ▼`, `Limit` numeric

**Actions bar** (sticky below builder):
- `[Run scan]` (primary, `LucideIcons.play`) → `POST /api/v1/scans/fundamental`
- `[Save as…]` (outline, `LucideIcons.save`) → modal asking for name → `POST /api/v1/scans/fundamental/saved`
- `[Download]` (outline, `LucideIcons.download`) → modal with Visible / All / Custom column selection → `POST /api/v1/scans/fundamental/export`

**Results table:**
- Columns derived from `response.column_labels` verbatim — labels include "(median over N years)" suffix when applicable
- Standard prefix columns always: Ticker, Name, Sector, Industry, Market Cap (Cr)
- Filter-referenced fields appended; sortable on every column
- Row click → Symbols sub-page detail mode
- Header: `{returned} of {total} matches`
- Data staleTime 60s

Fields catalog and presets cached on mount (staleTime 1 hour per spec §7).

### 6.4 Custom Scans sub-page

`lib/screens/web/scanner/sub_pages/custom_scans_sub_page.dart` — same two-mode pattern (list ↔ builder).

**List mode:**
- Top right: `[+ New custom scan]` primary button
- Grid of saved-scan cards (`Wrap` of 320px cards) from `GET /api/v1/scans/saved`:
  - Card title: scan name (`titleMedium` semibold)
  - Caption: created at (IST), `Last run: ...`, `Runs: N`
  - Footer actions: `Run`, `Edit`, `Delete` (`LucideIcons.trash2` in rose) — Delete confirms before `DELETE /api/v1/scans/saved/{id}`
- Empty state: "No custom scans yet. Click '+ New custom scan' to write your first predicate."

**Builder mode** (`PredicateBuilder` widget):
- Header: scan name input (or display existing name when editing)
- Tree-style visual predicate builder:
  - Root combinator selector: `[All (AND)] [Any (OR)] [None (NOT)]` toggle, defaults to All
  - Inside each combinator: vertically stacked list of children. Each child = leaf condition or nested group
  - Leaf condition row: `[Indicator ▼] [params…] [Op ▼] [Right side: Value | Indicator] [params…] [✕]`
  - Indicator dropdown is grouped by family (Raw price/volume · Aggregations · Moving averages · Oscillators · Bands · Trend · Volatility · Ichimoku · Candlestick patterns · Relative strength) per spec §3.7. Param fields appear inline when the indicator needs them (e.g. RSI shows `period`; SMA shows `source`, `period`, optional `scale`, `offset_bars`)
  - Right-side toggle: `Value` (numeric) vs `Indicator` (full picker). For `between` op, two value inputs
  - `[+ Add condition]` and `[+ Add group]` buttons at the bottom of each combinator
  - Internal state serializes to the spec's predicate JSON on Run/Save
- Action row: `[Run inline]` → `POST /api/v1/scans/run` (returns ticker+name only — results render below as a simple table). `[Save]` → `POST /api/v1/scans/saved` (creates or updates if editing)
- Below builder: "Preview JSON" expandable `shadcn.Accordion` showing the generated predicate JSON (read-only) — debugging + visible learning

The indicator metadata (~57 indicators + their params) lives in `lib/screens/web/scanner/utils/indicator_catalog.dart` as a static Dart structure — single source of truth for what params each indicator accepts. Used by both the builder UI and the JSON serializer.

## 7. API & Data Layer

### 7.1 Mixin

`lib/api/stock_scanner_api.dart` — single mixin `StockScannerAPI on ApiCore` exposing one `Future<...>` method per spec endpoint, grouped by spec section:

- `symbols/*`: `fetchSymbols`, `fetchSymbol`, `fetchOhlcv`, `fetchTechnicals`, `fetchPerformance`, `fetchSymbolScanners`, `fetchSymbolInfo`, `fetchFundamentalScore`, `fetchFinancials`, `fetchPeers`, `fetchHolders`, `fetchNews`, `fetchDividends`, `fetchDeliveries`, `fetchAnnouncements`
- `scanners/*`: `fetchScanners`, `fetchScanner`, `fetchScannerResults`, `downloadScannerExportXlsx`
- `scans/fundamental/*`: `fetchFundamentalFields`, `fetchFundamentalPresets`, `runFundamentalScan`, `downloadFundamentalExportXlsx`, `listSavedScreens`, `getSavedScreen`, `saveScreen`, `runSavedScreen`, `deleteSavedScreen`
- `scans/*` (custom): `runCustomScan`, `saveCustomScan`, `listSavedCustomScans`, `getSavedCustomScan`, `runSavedCustomScan`, `deleteSavedCustomScan`

The mixin is mixed into the existing aggregated `ApiService` class registered in `lib/locator/locator.dart`.

### 7.2 Error normalization

Single private `_parseError(http.Response r)` helper in the mixin parses the spec's `{error, message, detail}` envelope into a typed `StockScannerException`:

- 401 → "Authentication required — please reload the app." (only fires if auth dep wasn't removed)
- 404 → "Not found — {message}"
- 422 → "Invalid input — {message}"
- 429 → "Rate limit exceeded — try again in a few seconds"
- 5xx → "Backend error — please retry"
- other / network → "Could not reach StockScanner — check your connection"

All endpoints throw `StockScannerException` on non-2xx. The provider layer translates the exception into UI-rendered toast / inline error card.

### 7.3 Models

`lib/models/scanner_model/*.dart` — one file per logical grouping:

- `symbol.dart` — `Symbol`, `SymbolListResponse`
- `ohlcv.dart` — `OhlcvBar`, `OhlcvResponse`
- `technicals.dart` — `TechnicalsResponse` (carries `Map<String, double?> indicators`)
- `performance.dart` — `PerformanceResponse`
- `fundamental_score.dart` — `FundamentalScore`
- `symbol_info.dart` — `SymbolInfo`
- `financials.dart` — `FinancialsResponse`
- `peers.dart` — `PeersResponse`, `PeerEntry`
- `scanner.dart` — `Scanner`, `ScannerListResponse`
- `scan_result.dart` — `ScanResultsDetail`, `ScanResultColumn`, `ScanResultRow`
- `fundamental_field.dart` — `FundamentalField` (with `key`, `label`, `group`, `dtype`, `description`)
- `fundamental_scan.dart` — `FundamentalFilter`, `FundamentalScanRequest`, `FundamentalScanResponse`, `FundamentalColumnLabel`
- `saved_screen.dart` — `SavedFundamentalScreen`
- `custom_scan.dart` — `SavedCustomScan`
- `predicate.dart` — `PredicateNode` (sealed-class-like via factory constructors: `PredicateLeaf`, `PredicateAll`, `PredicateAny`, `PredicateNone`); `IndicatorRef` (literal / indicator-call); operator enum; serialization to/from JSON for use by the visual builder
- `scanner_exception.dart` — `StockScannerException`

All models follow the existing pattern: plain Dart classes with `fromJson(Map<String, dynamic>)` factories and (where mutation is needed) `toJson()` methods.

### 7.4 Riverpod providers

`lib/provider/scanner/*.dart`:

- `scanner_shell_provider.dart` — `StateNotifierProvider<ScannerShellNotifier, ScannerShellState>` tracking `activeSubPage` and any pending sub-page detail key (e.g. preselected scanner code when arriving from a Scans-tab chip)
- `symbols_provider.dart` — search results provider (debounced), tab-specific `FutureProvider.family(ticker)` for each Symbol-detail tab endpoint
- `scanners_provider.dart` — scanner-list `FutureProvider` (cached 30 min), scanner-detail `FutureProvider.family(code)` (cached 60s)
- `fundamentals_provider.dart` — fields catalog (1 hr), presets (1 hr), saved screens list, ad-hoc run state
- `custom_scans_provider.dart` — saved-scan list, current builder state, inline run results

Stale-time enforcement is best-effort: providers re-fetch on user-triggered actions; long-running screens don't auto-refresh.

## 8. Formatters (spec §6)

`lib/screens/web/scanner/utils/formatters.dart` — implemented exactly per the spec:

- `formatCurrencyINR(double? value) → String` — Indian-crore convention. `1 Cr = 1e7`. `≥1L Cr` formatted as `X.XXL Cr`, `≥1 Cr` as `X Cr`, smaller as `₹X,XX,XXX` with Indian comma format
- `formatPercent(double? value) → String` — converts fraction to display (`0.15 → 15.00%`), prefixes `+` when positive
- `parseBackendDate(String iso) → DateTime` — handles the backend's naive-UTC quirk (appends `Z` when no TZ suffix), per spec §6
- `formatDateTime(String? iso) → String` — IST timezone, `en-IN` locale
- `formatColumn(double? value, String fmt) → ({String text, Color? color})` — driven by the `fmt` field returned in scanner result columns: `price`, `pct` (with sign + color), `raw`, `int`, `ratio`, default

All percentage and currency outputs gracefully render `—` for null.

## 9. File Structure (summary)

```
lib/
├── api/
│   ├── core/api_link.dart                     [MODIFY: add stockScannerBaseURL + stockScannerApi]
│   └── stock_scanner_api.dart                 [NEW]
├── locator/locator.dart                       [MODIFY: include StockScannerAPI mixin in the ApiService]
├── models/scanner_model/
│   ├── symbol.dart                            [NEW]
│   ├── ohlcv.dart                             [NEW]
│   ├── technicals.dart                        [NEW]
│   ├── performance.dart                       [NEW]
│   ├── fundamental_score.dart                 [NEW]
│   ├── symbol_info.dart                       [NEW]
│   ├── financials.dart                        [NEW]
│   ├── peers.dart                             [NEW]
│   ├── scanner.dart                           [NEW]
│   ├── scan_result.dart                       [NEW]
│   ├── fundamental_field.dart                 [NEW]
│   ├── fundamental_scan.dart                  [NEW]
│   ├── saved_screen.dart                      [NEW]
│   ├── custom_scan.dart                       [NEW]
│   ├── predicate.dart                         [NEW]
│   └── scanner_exception.dart                 [NEW]
├── provider/scanner/
│   ├── scanner_shell_provider.dart            [NEW]
│   ├── symbols_provider.dart                  [NEW]
│   ├── scanners_provider.dart                 [NEW]
│   ├── fundamentals_provider.dart             [NEW]
│   └── custom_scans_provider.dart             [NEW]
├── routes/
│   └── web_router.dart                        [MODIFY: add /scanner + 4 sub-routes]
└── screens/web/
    ├── customizable_split_home_screen.dart    [MODIFY: ScreenTypeParam.scanner, Options-dropdown menu item, panel routing, drawer wiring]
    ├── home/
    │   ├── models/screen_type.dart            [MODIFY: add ScreenType.scanner]
    │   ├── widgets/app_bar/navigation_drawer_web.dart  [MODIFY: showScanner + Scanner drawer item]
    │   └── widgets/panels/panel_content_builder.dart   [MODIFY: handle ScreenType.scanner → ScannerShellScreen]
    └── scanner/
        ├── scanner_shell_screen.dart                   [NEW: shell w/ left rail + right content]
        ├── widgets/
        │   ├── scanner_left_rail.dart                  [NEW]
        │   ├── scanner_breadcrumb.dart                 [NEW]
        │   ├── predicate_builder.dart                  [NEW: tree-style visual builder]
        │   ├── indicator_picker.dart                   [NEW: dropdown grouped by family]
        │   ├── fundamental_filter_row.dart             [NEW: single row of fundamental builder]
        │   ├── metric_card.dart                        [NEW: shared by Technicals + Fundamental tabs]
        │   ├── score_progress_bar.dart                 [NEW: fundamental-score 0–100 bar]
        │   ├── scanner_results_table.dart              [NEW: sortable table reused by Scanners + Fundamental]
        │   ├── export_modal.dart                       [NEW: visible/all/custom column picker]
        │   └── empty_state.dart                        [NEW]
        ├── sub_pages/
        │   ├── symbols_sub_page.dart                   [NEW: list + detail w/ 9 tabs]
        │   ├── symbols_tabs/
        │   │   ├── prices_tab.dart                     [NEW]
        │   │   ├── scans_tab.dart                      [NEW]
        │   │   ├── technicals_tab.dart                 [NEW]
        │   │   ├── performance_tab.dart                [NEW]
        │   │   ├── fundamental_tab.dart                [NEW]
        │   │   ├── financials_tab.dart                 [NEW]
        │   │   ├── peers_tab.dart                      [NEW]
        │   │   ├── holders_tab.dart                    [NEW: holders + MF + news collapsed]
        │   │   └── deliveries_tab.dart                 [NEW]
        │   ├── scanners_sub_page.dart                  [NEW]
        │   ├── fundamentals_sub_page.dart              [NEW]
        │   └── custom_scans_sub_page.dart              [NEW]
        └── utils/
            ├── formatters.dart                         [NEW: currency, %, dates, fmt-driven column]
            ├── indicator_catalog.dart                  [NEW: ~57 indicators + param metadata]
            ├── technical_interpretations.dart          [NEW: threshold-based badges]
            └── download_xlsx.dart                      [NEW: blob fetch + browser download]
```

~50 new files, 7 modifications. All new code is isolated under `lib/screens/web/scanner/`, `lib/models/scanner_model/`, `lib/provider/scanner/`, and the new `lib/api/stock_scanner_api.dart`. Existing screens are untouched apart from the 7 wiring modifications listed.

## 10. Edge cases & known limitations (spec §8)

- **Holders / MF Holding:** yfinance returns empty for ~95% of Indian stocks → render "Insufficient data" empty state, not empty rows
- **PEG Ratio:** only ~45% coverage → show `—` placeholder freely
- **News:** yfinance news skews US-centric → some tickers will have 0 entries → empty state
- **`as_of` consistency:** scanner-result column values are computed at the date the predicate evaluated true — historical queries return historically-accurate values. The Scanner detail page surfaces the `as_of` field prominently
- **`^NSEI` benchmark:** filtered out of EQ scans server-side; used internally for `relative_strength` and Performance "vs NIFTY"

## 11. Testing approach

Out of scope for this design doc — to be defined during the implementation-plan phase. At minimum: unit tests for `formatters.dart`, `predicate.dart` JSON serialization round-trip, and the `_parseError` helper.

## 12. Open follow-ups (post-MVP)

- Chart tab on Symbol detail (Syncfusion-based candlestick + overlays + sub-charts)
- Deliveries sparkline (needs a chart library)
- Auth-key support if backend disables `PUBLIC_READ_MODE`
- Backend URL configurability (env-var or runtime preference instead of hardcoded constant)
