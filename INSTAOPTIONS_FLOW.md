# InstaOptions Workflow Playbook (FLOW)

## Goal

Work on the InstaOptions Analytics module one **screen-section** at a time. Each of the 9 sub-screens is a section. A section completes only after running the full lifecycle and landing a commit. The next section starts only after the previous one closes.

## The three docs

| Doc | Path | Lifetime | Purpose |
|---|---|---|---|
| **FLOW** | [INSTAOPTIONS_FLOW.md](INSTAOPTIONS_FLOW.md) (this file) | Durable | Workflow playbook + section catalog. Read first in every session. |
| **PLAN** | [INSTAOPTIONS_PLAN.md](INSTAOPTIONS_PLAN.md) | Per-section | Active section's working notes. Replaced when a section starts. |
| **HANDOFF** | [INSTAOPTIONS_HANDOFF.md](INSTAOPTIONS_HANDOFF.md) | Cross-session | Status of every section + pending items + caveats. |

All three tracked in git.

When a section completes, its filled PLAN is archived to `.claude/insta-options-qa/plans/<section-name>.md` and `INSTAOPTIONS_PLAN.md` is reset to "no section active".

## Reference triad

Every section has three reference sources that fully specify what to build. Read all three at the start of each section's Analyze phase.

1. **Spec** — [INSTAOPTIONS_FEATURE_README.md](INSTAOPTIONS_FEATURE_README.md) §10.x (target behaviour + acceptance criteria).
2. **Visual** — `.claude/insta-options-qa/optionz-reference/NN-*.png` (how the equivalent OptionZ screen looks).
3. **Data audit** — [INSTAOPTIONS_DATA_AUDIT.md](INSTAOPTIONS_DATA_AUDIT.md) "Screen NN" entry (each data point's backend mapping or gap).

## Per-section lifecycle (7 phases)

1. **Pick** — User names the next section. Write section name + reference triad into a fresh PLAN.
2. **Analyze** — Read screen file + provider + models + the three references. Document current vs target gap in PLAN Phase 1.
3. **Plan** — Step-by-step edit list in PLAN Phase 2. Each step = one file + one concrete change.
4. **Explain** — Post chat summary. Wait for user ack.
5. **Implement** — Execute. `flutter analyze` clean on touched paths. Log per-edit in PLAN Phase 4.
6. **QA** — Spawn `general-purpose` subagent with Playwright MCP brief. Loop fix + re-QA until pass. Brief + report in PLAN Phase 5.
7. **Commit + HANDOFF update** — Same commit: code + HANDOFF updates + PLAN archived + PLAN reset.

## Section catalog (9 screens, side-rail order)

### 1 — Markets Dashboard
- File: [lib/screens/web/insta_options/screens/markets_dashboard_screen.dart](lib/screens/web/insta_options/screens/markets_dashboard_screen.dart)
- Provider: `instaOptionsMarketsProvider`
- APIs: `/market/snapshot`, `/buildup/symbols`, `/spot/timeseries`
- Spec: [§10.1](INSTAOPTIONS_FEATURE_README.md) (line 1402) · Visual: `.claude/insta-options-qa/optionz-reference/01-markets-dashboard.png` · Audit: [Screen 01](INSTAOPTIONS_DATA_AUDIT.md) (line 16)
- Sub-processes:
  - Polls 3 endpoints on mount; autoDispose teardown
  - Header: title + `Updated HH:MM IST` + Refresh
  - 4 index ticker tiles (NIFTY / BANKNIFTY / FINNIFTY / SENSEX) with sparklines
  - Responsive: tiles row when ≥ 4×200px, else Wrap
  - 2×2 buildup quadrant grid
  - Tap quadrant row → switches to Option Chain with that symbol
  - Loading / fatal-error / partial-error states

### 2 — Index Contributors
- File: [lib/screens/web/insta_options/screens/index_contributors_screen.dart](lib/screens/web/insta_options/screens/index_contributors_screen.dart)
- Provider: `instaOptionsContributorsProvider`
- APIs: `/contributors/{NIFTY,BANKNIFTY,FINNIFTY,MIDCPNIFTY,SENSEX,BANKEX}`
- Spec: [§10.2](INSTAOPTIONS_FEATURE_README.md) (line 1501) · Visual: `.claude/insta-options-qa/optionz-reference/07-index-contributors.png` · Audit: [Screen 07](INSTAOPTIONS_DATA_AUDIT.md) (line 138)
- Sub-processes:
  - 6-index horizontal tab strip
  - Stock/Sector segmented button view toggle
  - `Sum: ±N.NN points` zone-coloured header value
  - Refresh button
  - Stock table: Company / Sector / LTP / Change% / Index Pts — sortable, default `|Index Pts|` desc
  - Sector table: client-side aggregation, Sector / Avg Change% / Total Pts — sortable
  - Loading / error / empty states

### 3 — Option Chain
- File: [lib/screens/web/insta_options/screens/chain_screen.dart](lib/screens/web/insta_options/screens/chain_screen.dart)
- Provider: `instaOptionsChainProvider`
- APIs: `/analytics/chain`, `/spot`
- Spec: [§10.3](INSTAOPTIONS_FEATURE_README.md) (line 1585) · Visual: `.claude/insta-options-qa/optionz-reference/02-option-chain.png` · Audit: [Screen 02](INSTAOPTIONS_DATA_AUDIT.md) (line 32)
- Sub-processes:
  - Header: spot + futures LTP + ATM strike + Greeks toggle
  - Mirror table: strikes centre, PE left / CE right
  - ATM row highlighted with left-border accent
  - OI bars gradient-scaled to max OI per side
  - Per-cell LTP %change below LTP (from `prev_close`)
  - Per-strike PCR column (PE OI / CE OI)
  - Greek cells null when `iv_solver_ok=false`
  - Long-press / right-click on OI cell → `ChainLegBottomSheet`
  - Loading / error / empty states

### 4 — OI Statistics
- File: [lib/screens/web/insta_options/screens/oi_stats_screen.dart](lib/screens/web/insta_options/screens/oi_stats_screen.dart)
- Provider: `instaOptionsAggregateProvider`
- Spec: [§10.4](INSTAOPTIONS_FEATURE_README.md) (line 1702) · Visual: `.claude/insta-options-qa/optionz-reference/03-oi-statistics.png` · Audit: [Screen 03](INSTAOPTIONS_DATA_AUDIT.md) (line 58)
- Sub-processes:
  - Header control bar: "Oi change" toggle + timestamp + Refresh
  - Cumulative panel (CustomPainter): stacked CE/PE bar with ΔOI tint overlay
  - KPI row: Total CE OI / Total PE OI / PCR + deltas
  - Per-strike bars (fl_chart): CE up / PE down, ATM dashed marker
  - Bar hover tooltip
  - Aggregator-warmup placeholder
  - Loading / error / empty states

### 5 — Trending OI
- File: [lib/screens/web/insta_options/screens/trending_oi_screen.dart](lib/screens/web/insta_options/screens/trending_oi_screen.dart)
- Provider: `instaOptionsTrendingProvider`
- API: `/oi/trending`
- Spec: [§10.5](INSTAOPTIONS_FEATURE_README.md) (line 1790) · Visual: `.claude/insta-options-qa/optionz-reference/04-trending-oi.png` · Audit: [Screen 04](INSTAOPTIONS_DATA_AUDIT.md) (line 81)
- Sub-processes:
  - "Change strikes" button → `StrikeMultiPicker` modal (max 7, ATM tagged)
  - Selected-strike pills
  - BucketMinutesSelector (3 / 5 / 15 min)
  - Auto-seed ATM±3 on first mount
  - Top-left chart: Sentiment line clamped [-1, +1] with filled areas
  - Top-right chart: Cumulative OI dual-line (CE / PE)
  - Chart hover tooltips
  - Bottom table: Time · LTP · ΔCallOI · ΔPutOI · DiffOI · Dir · ΔDir · Dir% · PCR
  - Empty state when buckets array empty

### 6 — PCR Ratio
- File: [lib/screens/web/insta_options/screens/pcr_screen.dart](lib/screens/web/insta_options/screens/pcr_screen.dart)
- Provider: `instaOptionsPcrProvider`
- API: `/oi/pcr/timeseries`
- Spec: [§10.6](INSTAOPTIONS_FEATURE_README.md) (line 1907) · Visual: `.claude/insta-options-qa/optionz-reference/05-pcr-ratio.png` · Audit: [Screen 05](INSTAOPTIONS_DATA_AUDIT.md) (line 103)
- Sub-processes:
  - Controls bar: BucketMinutesSelector + Refresh
  - 3 KPI cards: Current PCR / Day High / Day Low
  - Dual-axis line chart: PCR left, spot (scaled) right
  - PCR line zone-coloured (green > 1.0, red < 0.7, grey between)
  - Horizontal guide lines at PCR 1.0 and 0.7
  - Hover tooltip
  - Loading / error / empty states

### 7 — Per-Strike Chart
- File: [lib/screens/web/insta_options/screens/per_strike_screen.dart](lib/screens/web/insta_options/screens/per_strike_screen.dart)
- Provider: `instaOptionsStrikeProvider`
- API: `/oi/timeseries`
- Spec: [§10.7](INSTAOPTIONS_FEATURE_README.md) (line 1982) · Visual: `.claude/insta-options-qa/optionz-reference/06-options-chart.png` · Audit: [Screen 06](INSTAOPTIONS_DATA_AUDIT.md) (line 119)
- Sub-processes:
  - Header: "Strike XXXXX" + ATM offset + BucketMinutesSelector + strike dropdown
  - Auto-seed ATM strike on first mount
  - Left card: Call OI Analysis (DualAxisLineChart + BSBadges B/S)
  - Right card: Put OI Analysis (mirrored)
  - Bottom card: Call vs Put OI dual-line
  - Loading / inline-error / empty (no strikes)

### 8 — OI Buildup
- File: [lib/screens/web/insta_options/screens/buildup_screen.dart](lib/screens/web/insta_options/screens/buildup_screen.dart)
- Provider: `instaOptionsBuildupProvider`
- API: `/oi/buildup`
- Spec: [§10.8](INSTAOPTIONS_FEATURE_README.md) (line 2084) · Visual: no dedicated screenshot (see §10.8 spec + `03-oi-statistics.png`) · Audit: [Cross-screen surfaces](INSTAOPTIONS_DATA_AUDIT.md) (line 182)
- Sub-processes:
  - Control bar: All / CE / PE / FUT segmented filter + sort dropdown (`|ΔOI|` desc / Strike asc) + contract count
  - Table columns: Symbol · Type · Strike · LTP · ΔLTP % · OI · ΔOI · Buildup
  - `Buildup` cell uses `BuildupPill` colour-coded by classification
  - Row-level colouring: price-change, OI-change
  - Loading / error / empty states

### 9 — Find Strategy
- File: [lib/screens/web/insta_options/screens/find_strategy_screen.dart](lib/screens/web/insta_options/screens/find_strategy_screen.dart)
- Provider: `instaOptionsStrategyScanProvider`
- API: `POST /strategy/scan`
- Spec: [§10.9](INSTAOPTIONS_FEATURE_README.md) (line 2165) · Visual: `.claude/insta-options-qa/optionz-reference/08-find-strategy.png` · Audit: [Screen 08](INSTAOPTIONS_DATA_AUDIT.md) (line 156)
- Sub-processes:
  - Filter bar: Direction dropdown + Unit segmented button (₹ / %) + Min reward text field + Run scan
  - Run scan disabled when expiry empty or scan in flight
  - Loading: button text "Scanning…"
  - Result list: scrollable `StrategyResultCard` — template name + KPIs + leg table + "Add to basket"
  - Banners: initial / no-results / error
  - "Add to basket" → success snackbar

## QA subagent contract

**Agent**: `general-purpose` (Playwright MCP access).

**Brief template** (in PLAN Phase 5, copied into agent prompt):

```
Section: <screen name>
What changed: <files + 1-line summary of each>
Reference triad (verify against all three):
  - Spec: <README §10.x link>
  - Visual: <OptionZ screenshot path>
  - Data audit: <DATA_AUDIT entry>
Acceptance criteria:
  - <criterion 1>
  - <criterion 2>
How to verify:
  - For criterion N: <Playwright steps>

Environment:
  - App at http://192.168.5.127:8081
  - Viewport: 1920x1080
  - Path: /insta-options → side-rail "<screen label>"

Report format:
  ## QA Report — <section name>
  ### Verified
  - [criterion → pass + evidence path]
  ### Failed
  - [criterion → observed → suggested cause]
  ### Cannot verify
  - [criterion → reason blocked]
```

**Pass rule**: every Verified + zero Failed. Cannot-verify items become HANDOFF caveats; don't block commit.

## Commit format

`instaoptions(<section-name>): <one-line summary>`

Same commit contains:
- All code changes (implementation + QA fixes).
- HANDOFF updates (completed items checked off, caveats added).
- PLAN archived to `.claude/insta-options-qa/plans/<section-name>.md`.
- Top-level PLAN reset to "no section active".

## Resumption protocol (new session)

1. Read this FLOW top-to-bottom.
2. Open [INSTAOPTIONS_PLAN.md](INSTAOPTIONS_PLAN.md) — if a section is active, resume at its next unfinished phase.
3. If PLAN says "no section active", open [INSTAOPTIONS_HANDOFF.md](INSTAOPTIONS_HANDOFF.md) and ask the user which section to pick next.
