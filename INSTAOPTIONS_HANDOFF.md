# InstaOptions Analytics — Build Handoff

Last updated: 2026-05-29 (Phase β — Per-Strike finalized + writer bands dropped)
Spec: [INSTAOPTIONS_FEATURE_README.md](INSTAOPTIONS_FEATURE_README.md)
Audit: [INSTAOPTIONS_DATA_AUDIT.md](INSTAOPTIONS_DATA_AUDIT.md) (OptionZ vs our backend; mirrored at `.claude/insta-options-qa/data-audit.md` for local working copy)
Backend tickets: [INSTAOPTIONS_BACKEND_TICKETS.md](INSTAOPTIONS_BACKEND_TICKETS.md) (also mirrored at `.claude/insta-options-qa/backend-tickets.md`)
Plan (original): `~/.claude/plans/instaoptions-feature-readme-md-i-wanted-twinkling-leaf.md`
Plan (post-audit): `~/.claude/plans/now-you-have-complete-purring-turtle.md`

This file is the single source of truth for cross-session progress on the InstaOptions Analytics module. Update it after every phase's QA passes, in the same commit that lands the phase's code.

## Conventions

- ☐ todo
- ⏳ in progress
- ✅ verified (QA passed + git commit landed)
- ⚠️ blocked

## Phase status

| # | Phase | Status | Commit | QA evidence | Notes |
|---|---|---|---|---|---|
| 0 | Rewrite README + create this file | ✅ verified | fd6e6e21 | `.claude/insta-options-qa/phase-0/qa-report.md` (local, gitignored) | QA PASS on all 6 criteria. |
| 1 | Plumbing — config, API, models, theme, route, shell, menu | ✅ verified | 206a9480 | `.claude/insta-options-qa/phase-1/` | QA PASS on all 10 criteria via Playwright MCP. Real `/health` call succeeded against `192.168.5.61:8000`. WS, fixtures, top-nav entry, URL sticking deferred. |
| 2 | Option Chain (sub-screen 3) | ✅ verified | eb614a78 | `.claude/insta-options-qa/phase-2/` | QA PASS on 12/16 criteria. Sticky ATM, Change-ref, WS, automated bottom-sheet click deferred. |
| 3 | OI Buildup (sub-screen 8) | ✅ verified | 4ff9285c | `.claude/insta-options-qa/phase-3/` | QA PASS on all 10 criteria. SegmentedButton filter (All/CE/PE/FUT), sort dropdown (\|ΔOI\| desc / Strike asc), DataTable2 with BuildupPill rendering server's classification verbatim. Deferred: row tap → Per-Strike (Phase 5 dependency), right-click bottom-sheet (manual verify), WS LTP/OI live updates. |
| 4 | OI Statistics + PCR (sub-screens 4 + 6) | ✅ verified | 700f64a4 | `.claude/insta-options-qa/phase-4/` | QA PASS on 8/8 testable criteria via Playwright MCP. OI Stats: CustomPainter cumulative panel (stacked CE/PE + ΔOI tint overlay) + fl_chart per-strike bars (CE up / PE down) + ATM dashed line + 3 KpiCards. PCR Ratio: fl_chart LineChart with PCR (zone-coloured) + scaled spot overlay + dashed 0.7/1.0 reference lines + 3 KpiCards. Both screens own start/stop polling timers (4s for OI Stats, 60s for PCR) tied to mount/unmount. Deferred: live render-path acceptance (backend `/symbols` timing out same as Phase 2/3), BrushChart zoom selector, PCR crosshair tap-drag, WS deltas. |

---

## 2026-05-29 — OptionZ audit + scope clarification

After Phase 4, we opened the live OptionZ app at https://zebu.instaoptions.trade (via Mynt home → OptionZ tile), captured reference screenshots to `.claude/insta-options-qa/optionz-reference/`, and audited our backend (README §8) for data coverage. Conclusions:

- Backend covers ~95% of OptionZ's data points directly. ~5% require trivial client-side transforms (single-line math; not workarounds). 3 backend tickets filed for the rest. See `.claude/insta-options-qa/data-audit.md`.
- Scope clarified: **replicate the DATA OptionZ shows, in our existing Mynt design idiom** (left side-rail, MyntColors, MyntWebTextStyles, existing widget patterns). Do NOT switch to OptionZ's top-tab nav or visual layout.
- **No frontend workarounds** for missing backend data — gaps go to backend team. See [INSTAOPTIONS_BACKEND_TICKETS.md](INSTAOPTIONS_BACKEND_TICKETS.md).
- Phase 5 (uncommitted, Per-Strike Options Chart) scope updated: drop writer-accumulation bands (non-trivial client compute, not in OptionZ).
- Remaining work renumbered to phases α-κ below. Original sequential Phase numbers 5-11 are superseded.

## Phase status (post-audit)

| # | Phase | Status | Commit | QA evidence | Notes |
|---|---|---|---|---|---|
| α | Docs: backend tickets + audit + README §3.1 Reuse Contract + README §10.x Data points + HANDOFF | ✅ verified | d3128f05 | n/a (docs) | [INSTAOPTIONS_BACKEND_TICKETS.md](INSTAOPTIONS_BACKEND_TICKETS.md) at repo root; `.claude/insta-options-qa/{backend-tickets.md, data-audit.md}` local mirrors; README §3.1 + §10.1-§10.9 Data points; §10.7 writer-bands removed; HANDOFF divider added. |
| β | Per-Strike Options Chart finalized: drop writer bands, switch to `ResponsiveSnackBar`, prune dead caption + param | ✅ verified | 97fd8825 | n/a (Phase 5 code commits + dead-code cleanup) | Removed `_detectWriterAccumulation` + `_WriterBand` + `extraLinesData` bands from `per_strike_screen.dart`. `bs_badges.dart` now uses `ResponsiveSnackBar.showSuccess` with message "Added BUY/SELL {tradingSymbol} to strategy". Removed dead "ΔOI overlay enabled" caption + unused `showChangeOverlay` param plumbed through `_PerStrikeBars` in `oi_stats_screen.dart`. `flutter analyze` clean on insta_options paths. |
| γ | Option Chain: add LTP %Change column | ✅ verified | (uncommitted) | n/a (code-only); live Playwright QA confirms CE LTP `−44.44%` red / PE LTP `+153.76%` green at ATM strike 23550 NIFTY 02-JUN-2026 | `ChainRow.prevClose` added; `ChainRow.ltpChangePct` computes `(ltp − prevClose) / prevClose × 100` when `prevClose > 0`. `chain_screen.dart` `_priceText()` now stacks LTP + small coloured `±x.xx%` caption per CE/PE cell. Column widths unchanged. Returns null (LTP-only render) for FUT row (no `prev_close`) + brand-new contracts. `flutter analyze` clean. |
| δ | PCR Ratio + Per-Strike: Time bucket selector (1/3/5/15 min) | ☐ todo | — | — | Unblocked 2026-05-29: Ticket 2 param accepted (`bucket_minutes=1/3/5/15`). |
| ε | Markets Dashboard (index ticker tiles + 2×2 buildup quadrants) | ✅ verified | (uncommitted) | n/a (code-only); live Playwright QA on `localhost:8082/insta-options` confirms 3 endpoints 200 OK + polling active + render correct | Replaces `markets_placeholder_screen.dart`. New `MarketsDashboardScreen` + `IndexTickerTile` + `BuildupQuadrant` + `InstaOptionsMarketsProvider` (4 s / 30 s polling, IST market-hours aware) + 3 models (`MarketSnapshot`/`IndexQuote`, `BuildupSymbolsResponse`/`BuildupBucket`, `SpotTimeseriesPoint`). API extended with `getMarketSnapshot`/`getBuildupSymbols`/`getSpotTimeseries`. Quadrant row tap → updates `selectionProvider.symbol` and switches side-rail to `chain`. Sparklines per tile via `/spot/timeseries`. `flutter analyze` clean on insta_options paths. **Visible data zeroed by [Ticket 4](INSTAOPTIONS_BACKEND_TICKETS.md): backend's `today_open`/`yesterday_close`/`change_pct` + `open_oi`/`close_oi`/`price_change` not populated → tiles show `0.00%`, all quadrants empty (every contract classified Neutral). Frontend renders correctly; will populate when backend ships.** |
| ζ | Index Contributors | ✅ verified | (uncommitted) | n/a (code-only); live Playwright QA confirms `/contributors/{NIFTY,BANKNIFTY}` 200 OK + Stock/Sector views + tab switch + sort indicator | New `IndexContributorsScreen` + `InstaOptionsContributorsProvider` (per-index 4 s/30 s polling, IST market-hours aware) + `ContributorRow` + `SectorAggregate` models. API extended with `getContributors(index)`. Index tab strip (NIFTY/BANKNIFTY/FINNIFTY/MIDCPNIFTY/SENSEX/BANKEX) + Stock/Sector segmented button + sortable DataTable2 columns + live `Sum: ±N.NN points` header. Sector mode = client-side `SectorAggregate.from(rows)` group-by. `flutter analyze` clean. **Visible `Change %` + `Index Pts` zeroed by [Ticket 4](INSTAOPTIONS_BACKEND_TICKETS.md): backend's `change_pct` + `index_points` not populated on `/contributors/{index}`.** Tap-stock popover with mini chart deferred to Phase κ. |
| η | Trending OI | ☐ todo | — | — | Unblocked 2026-05-29: Ticket 3 endpoint live with full per-bucket records (`ltp` field zero until Ticket 4 closes — spot overlay will follow). |
| θ | Find Strategy | ✅ verified | (uncommitted) | n/a (code-only); live Playwright QA confirms `POST /strategy/scan` 200 OK with 3 strategies rendered for `direction=Positive, min_reward=100 INR` against NIFTY 02-JUN-2026 expiry | New `FindStrategyScreen` + `StrategyResultCard` + `InstaOptionsStrategyScanProvider` + `StrategyScanResult` / `StrategyLeg` / `StrategyDirection` / `StrategyMinRewardType`. API extended with `scanStrategies(...)` (POST) + internal `_post` helper. Filter card (Direction dropdown + ₹/% toggle + min reward text field + Run scan button) + result cards (template name + Max P&L / Max Loss / BE KPIs + Add to basket + DataTable2 of legs with green B / red S side chips). **Build-time investigation resolved**: backend `/strategy/scan` legs return `{side, trading_symbol, strike, option_type, lot, ltp, oi}` only — no "Direction" field; OptionZ's "Direction" column does not map to our backend, dropped from scope. Add-to-basket currently surfaces a `ResponsiveSnackBar.showSuccess` toast; full wiring to `StrategyBuilderProvider` deferred to **Phase ι**. Inspect icon + breakeven-click-to-copy deferred to **Phase κ**. `flutter analyze` clean. |
| ι | Basket / order rewire to `StrategyBuilderProvider` | ☐ todo | — | — | Optional, on user request. Deletes `InstaOptionsBasketProvider`, `BasketLeg`, `BasketChip`. Adds `ChainRow → OptionValues` adapter. Routes B/S taps and Find Strategy cart icon through existing strategy builder. |
| κ | Polish: top-nav entry, URL persistence, brush slider, goldens, investigate pagination ❓ | ☐ todo | — | — | Final phase. |

## Confirmed scope (locked at start of build, refined 2026-05-29 after OptionZ audit)

1. **OI Data backend is separate** from Mynt's Noren/`go.mynt.in` APIs. Base URL configurable via `Preferences` key `instaoptions:baseUrl`, default `http://192.168.5.61:8000`.
2. **Order placement** now wires to existing `StrategyBuilderProvider` in Phase ι (was deferred indefinitely; reuse-contract surfaces documented in README §3.1).
3. **Theme uses MyntColors light + dark** via `InstaOptionsTokens.of(context)`. No hex literals in widget code.
4. **Navigation:** single `/insta-options` route → `CustomizableSplitHomeScreen(initialRightPanel: ScreenTypeParam.instaOptions)` → internal **left side-rail** in `InstaOptionsShell` switches between the 9 sub-screens. (Kept; we do NOT match OptionZ's top-tab structure.)
5. **Replicate DATA only, not OptionZ's visual layout.** Mynt design idiom stays.
6. **No frontend workarounds for missing backend data.** Gaps go to backend team via [INSTAOPTIONS_BACKEND_TICKETS.md](INSTAOPTIONS_BACKEND_TICKETS.md). Trivial single-line transforms on already-returned fields are OK.
7. **Writer-accumulation bands** (originally spec'd on Per-Strike) **dropped** — not in OptionZ.

## Open follow-ups (collected during the build)

> Order-placement integration (was a follow-up before 2026-05-29) is now scheduled as **Phase ι** in the phase table above. Remove from this list once Phase ι lands.

- [ ] Confirm production OI Data backend URL (currently dev IP `192.168.5.61:8000`).
- [ ] Add CI workflow for golden tests once **Phase κ** lands.
- [ ] Decide whether to add per-sub-screen deep-link query params (e.g. `?screen=chain&symbol=NIFTY&expiry=30-JUN-2026`) — currently sub-screen state is in-memory only. **Phase κ**.
- [ ] After Phase 1: URL doesn't stay at `/insta-options` — `CustomizableSplitHomeScreen` rewrites to `/` after mount. Direct-URL navigation works for first mount; the URL just doesn't reflect the InstaOptions panel afterward. **Phase κ**.
- [ ] After Phase 1: Top-nav (wide-viewport ≥ 1200 px) entry for "InstaOptions Analytics" not yet added — only the hamburger nav drawer (narrow-viewport) entry is wired. Wide-viewport top-nav entry in **Phase κ**.
- [ ] After Phase 1: Dark theme not exercised in automated QA — manual verification needed using the host's theme toggle. (Light theme verified.) **Phase κ**.
- [ ] Phase 1 deferred: WS client (`InstaOptionsWsClient`) + fixture mode + remaining 23 API endpoints — partially landed alongside Phases 2-β; remaining WS topics (`chain_delta`, `iv_update`, `oi_bucket_close`) deferred to a dedicated streaming phase post-κ.
- [ ] Phase 4 deferred: BrushChart zoom selector under the OI Stats per-strike bar chart (README §10.4) — non-trivial fl_chart custom widget, **Phase κ** polish.
- [ ] Phase 4 deferred: PCR crosshair tap-and-drag tooltip with 50 ms latency (README §10.6 acceptance #2) — current implementation has hover tooltip only; **Phase κ** polish.
- [ ] Phase 4 deferred: Live render-path acceptance for OI Stats / PCR — backend `/symbols` keeps timing out, blocking automated QA of populated cumulative panel + KpiCards + chart series. Re-run QA when backend `/symbols` reliability improves or fixtures land.
- [ ] Phase α / β legacy: `oi_stats_screen.dart`'s "Oi change" toggle is wired in the header but no longer drives any visible behavior (the per-strike chart was never extended with ΔOI bar overlays; the cumulative panel always shows ΔOI tints regardless). Either wire the toggle to gate the cumulative-panel tints, or hide the toggle. **Phase ε or κ**.
- [ ] Phase ζ deferred: tap-stock popover (480×320) with mini intraday chart sourced from `/spot/timeseries?symbol=<stock>` (README §10.2 Interactions). Phase ζ ships sort + Stock/Sector + tabs without it. **Phase κ** polish.
- [ ] Phase θ deferred: "Inspect" icon (Icons.fullscreen) per result card — expand to show payoff math (Max Profit, Max Loss, Breakevens, premium estimate). Spec calls it optional in v1. **Phase κ**.
- [ ] Phase θ deferred: Breakeven number click-to-copy + "Copied" toast. **Phase κ**.
- [ ] Phase ε / ζ to investigate: confirm `Markets` and `Contributors` providers correctly cancel their polling timer when the side-rail switches to another sub-screen (observed network requests during Phase ζ QA suggest the `/market/snapshot` poll may continue briefly after navigating to Contributors). If a real leak, add `keepAlive: false` or audit the `start()`/`stop()` mount/dispose pairing. **Phase κ**.

### Backend tickets pending (added 2026-05-29)

See [INSTAOPTIONS_BACKEND_TICKETS.md](INSTAOPTIONS_BACKEND_TICKETS.md) for full ticket text.

- [x] ~~**Ticket 1**: Add `prev_close` field to each row of `GET /analytics/chain`.~~ ✅ **Resolved 2026-05-29** — CE/PE rows populated; FUT row correctly excluded. Phase γ unblocked.
- [x] ~~**Ticket 2**: Add `bucket_minutes` query param (1/3/5/15) to `GET /oi/pcr/timeseries` AND `GET /oi/timeseries`.~~ ✅ **Resolved 2026-05-29** — param accepted on both endpoints (verified `bm=1/5/15` window correctly). Phase δ unblocked.
- [x] ~~**Ticket 3**: New endpoint `GET /oi/trending` returning per-bucket `{time, sentiment, cum_ce_oi, cum_pe_oi, delta_ce_oi, delta_pe_oi, pcr, ltp, ltp_pct, dir_spot, dir_oi}`.~~ ✅ **Resolved 2026-05-29** — endpoint live, real per-bucket records returned. Phase η unblocked. (Spot overlay's `ltp` will follow once Ticket 4 closes.)
- [~] **Ticket 4** (added 2026-05-29 during Phase ε live QA): Populate `today_open` / `yesterday_close` / `change_pct` on `/market/snapshot.indices[]` + `.per_index[].stocks[]` + `/contributors/{index}`; populate `open_oi` / `close_oi` / `price_change` on `/oi/buildup`. ⚠ **Partially resolved 2026-05-29** — `/oi/buildup` per-contract fix landed (OI Buildup screen Phase 3 will start showing real pills automatically). Still outstanding: `/market/snapshot` indices/stocks/advances, `/contributors/{index}` change_pct/index_points, `/buildup/symbols` empty cascade. Phase ε tiles + Phase ζ %change remain blocked on this remainder.

### Open investigations (added 2026-05-29)

- [ ] Bottom pagination `1|2|3|4|5` on OptionZ's Option Data screens (OI Stats, Trending OI, PCR, Options Chart) — meaning unknown. Hypotheses: saved layouts, date-page navigation, alternate views. Confirm in Phase κ before deciding whether to replicate.
- [ ] "Direction" column in Find Strategy result legs (values like `0.00, 100.00, 200.00`) — meaning unclear. Inspect live `/strategy/scan` response at Phase θ.

## How to resume

1. Read this file top-to-bottom.
2. Find the first row with status ☐ or ⏳ in the **Phase status (post-audit)** table (Phases α-κ supersede the original Phases 0-11 sequence).
3. Open [INSTAOPTIONS_FEATURE_README.md](INSTAOPTIONS_FEATURE_README.md) — see §3.1 Reuse Contract for surfaces to integrate with, and the corresponding §10.x sub-screen for visual + data spec.
4. Pick up from the phase's bullet list in the post-audit plan at `~/.claude/plans/now-you-have-complete-purring-turtle.md`. The original plan at `~/.claude/plans/instaoptions-feature-readme-md-i-wanted-twinkling-leaf.md` is retained for historical reference (its Phase 5-11 sequence is superseded).
5. Each phase ends with: `flutter analyze` clean on insta_options paths → git commit with `instaoptions(phase-X): …` (no Co-Authored-By, per `feedback_no_coauthor` memory) → update this file's phase row in the same commit.
6. If the next phase is blocked on a backend ticket (γ, δ, η), check [INSTAOPTIONS_BACKEND_TICKETS.md](INSTAOPTIONS_BACKEND_TICKETS.md) for the ticket details + the frontend fallback if the backend slips.
