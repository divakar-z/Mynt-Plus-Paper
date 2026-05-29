# InstaOptions Analytics — Build Handoff

Last updated: 2026-05-29 (Phase α — backend audit + spec updates)
Spec: [INSTAOPTIONS_FEATURE_README.md](INSTAOPTIONS_FEATURE_README.md)
Audit: `.claude/insta-options-qa/data-audit.md` (OptionZ vs our backend)
Backend tickets: [INSTAOPTIONS_BACKEND_TICKETS.md](INSTAOPTIONS_BACKEND_TICKETS.md) (also mirrored at `.claude/insta-options-qa/backend-tickets.md` for local audit)
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
| 3 | OI Buildup (sub-screen 8) | ✅ verified | (this commit) | `.claude/insta-options-qa/phase-3/` | QA PASS on all 10 criteria. SegmentedButton filter (All/CE/PE/FUT), sort dropdown (\|ΔOI\| desc / Strike asc), DataTable2 with BuildupPill rendering server's classification verbatim. Deferred: row tap → Per-Strike (Phase 5 dependency), right-click bottom-sheet (manual verify), WS LTP/OI live updates. |
| 4 | OI Statistics + PCR (sub-screens 4 + 6) | ✅ verified | (this commit) | `.claude/insta-options-qa/phase-4/` | QA PASS on 8/8 testable criteria via Playwright MCP. OI Stats: CustomPainter cumulative panel (stacked CE/PE + ΔOI tint overlay) + fl_chart per-strike bars (CE up / PE down) + ATM dashed line + 3 KpiCards. PCR Ratio: fl_chart LineChart with PCR (zone-coloured) + scaled spot overlay + dashed 0.7/1.0 reference lines + 3 KpiCards. Both screens own start/stop polling timers (4s for OI Stats, 60s for PCR) tied to mount/unmount. Deferred: live render-path acceptance (backend `/symbols` timing out same as Phase 2/3), BrushChart zoom selector, PCR crosshair tap-drag, WS deltas. |

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
| β | Per-Strike Options Chart finalized: drop writer bands, switch to `ResponsiveSnackBar`, prune dead caption + param | ✅ verified | (this commit) | n/a (Phase 5 code commits + dead-code cleanup) | Removed `_detectWriterAccumulation` + `_WriterBand` + `extraLinesData` bands from `per_strike_screen.dart`. `bs_badges.dart` now uses `ResponsiveSnackBar.showSuccess` with message "Added BUY/SELL {tradingSymbol} to strategy". Removed dead "ΔOI overlay enabled" caption + unused `showChangeOverlay` param plumbed through `_PerStrikeBars` in `oi_stats_screen.dart`. `flutter analyze` clean on insta_options paths. |
| γ | Option Chain: add LTP %Change column | ⚠️ blocked | — | — | Blocked on Ticket 1 (`prev_close` on `/analytics/chain`). |
| δ | PCR Ratio + Per-Strike: Time bucket selector (1/3/5/15 min) | ⚠️ blocked | — | — | Blocked on Ticket 2 (`bucket_minutes` query param). |
| ε | Markets Dashboard (index ticker tiles + 2×2 buildup quadrants) | ☐ todo | — | — | Replaces `markets_placeholder_screen.dart`. Uses `/market/snapshot` + `/buildup/symbols`. New screen + tile + quadrant widgets + provider + models. |
| ζ | Index Contributors | ☐ todo | — | — | New `DataTable2`-based screen using `/contributors/{index}`. |
| η | Trending OI | ⚠️ blocked | — | — | Blocked on Ticket 3 (new `/oi/trending` endpoint). |
| θ | Find Strategy | ☐ todo | — | — | New screen using `POST /strategy/scan`. Investigate "Direction" column meaning at build time. |
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

- [ ] Wire order placement on `BasketChip` / B / S badges / Find-Strategy "Add to basket" (deferred — see README §3). Needs a decision on how legs flow to the existing `StrategyBuilderProvider`.
- [ ] Confirm production OI Data backend URL (currently dev IP `192.168.5.61:8000`).
- [ ] Add CI workflow for golden tests once Phase 10 lands.
- [ ] Decide whether to add per-sub-screen deep-link query params (e.g. `?screen=chain&symbol=NIFTY&expiry=30-JUN-2026`) — currently sub-screen state is in-memory only.
- [ ] After Phase 1: URL doesn't stay at `/insta-options` — `CustomizableSplitHomeScreen` rewrites to `/` after mount. Direct-URL navigation works for first mount; the URL just doesn't reflect the InstaOptions panel afterward. Polish in Phase 10.
- [ ] After Phase 1: Top-nav (wide-viewport ≥ 1200 px) entry for "InstaOptions Analytics" not yet added — only the hamburger nav drawer (narrow-viewport) entry is wired. Wide-viewport top-nav entry in Phase 10.
- [ ] After Phase 1: Dark theme not exercised in automated QA — manual verification needed using the host's theme toggle. (Light theme verified.)
- [ ] Phase 1 deferred: WS client (`InstaOptionsWsClient`) + fixture mode + remaining 23 API endpoints — all land with Phase 2 (Option Chain).
- [ ] Phase 4 deferred: BrushChart zoom selector under the OI Stats per-strike bar chart (README §10.4) — non-trivial fl_chart custom widget, Phase 10 polish.
- [ ] Phase 4 deferred: PCR crosshair tap-and-drag tooltip with 50 ms latency (README §10.6 acceptance #2) — current implementation has hover tooltip only; Phase 10 polish.
- [ ] Phase 4 deferred: Live render-path acceptance for OI Stats / PCR — backend `/symbols` keeps timing out, blocking automated QA of populated cumulative panel + KpiCards + chart series. Re-run QA when backend `/symbols` reliability improves or fixtures land.

### Backend tickets pending (added 2026-05-29)

See [INSTAOPTIONS_BACKEND_TICKETS.md](INSTAOPTIONS_BACKEND_TICKETS.md) for full ticket text.

- [ ] **Ticket 1**: Add `prev_close` field to each row of `GET /analytics/chain`. **Blocks Phase γ** (Option Chain LTP %Change column).
- [ ] **Ticket 2**: Add `bucket_minutes` query param (1/3/5/15) to `GET /oi/pcr/timeseries` AND `GET /oi/timeseries`. **Blocks Phase δ** (PCR + Per-Strike Time selector).
- [ ] **Ticket 3**: New endpoint `GET /oi/trending` returning per-bucket `{time, sentiment, cum_ce_oi, cum_pe_oi, delta_ce_oi, delta_pe_oi, pcr, ltp, ltp_pct, dir_spot, dir_oi}`. **Blocks Phase η** (Trending OI screen entirely).

### Open investigations (added 2026-05-29)

- [ ] Bottom pagination `1|2|3|4|5` on OptionZ's Option Data screens (OI Stats, Trending OI, PCR, Options Chart) — meaning unknown. Hypotheses: saved layouts, date-page navigation, alternate views. Confirm in Phase κ before deciding whether to replicate.
- [ ] "Direction" column in Find Strategy result legs (values like `0.00, 100.00, 200.00`) — meaning unclear. Inspect live `/strategy/scan` response at Phase θ.

## How to resume

1. Read this file top-to-bottom.
2. Find the first row with status ☐ or ⏳.
3. Open [INSTAOPTIONS_FEATURE_README.md](INSTAOPTIONS_FEATURE_README.md) section that maps to that phase (see the build-order table in README §14).
4. Pick up from the phase's "Implementation steps" in the plan at `~/.claude/plans/instaoptions-feature-readme-md-i-wanted-twinkling-leaf.md`.
5. Each phase ends with: QA via a Chrome DevTools MCP sub-agent → save screenshots to `.claude/insta-options-qa/phase-N/` → `flutter analyze` clean → git commit with `instaoptions(phase-N): …` (no Co-Authored-By) → update this file in the same commit.
