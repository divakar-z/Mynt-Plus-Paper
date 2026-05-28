# InstaOptions Analytics — Build Handoff

Last updated: 2026-05-28
Spec: [INSTAOPTIONS_FEATURE_README.md](INSTAOPTIONS_FEATURE_README.md)
Plan: `~/.claude/plans/instaoptions-feature-readme-md-i-wanted-twinkling-leaf.md`

This file is the single source of truth for cross-session progress on the InstaOptions Analytics module. Update it after every phase's QA passes, in the same commit that lands the phase's code.

## Conventions

- ☐ todo
- ⏳ in progress
- ✅ verified (QA passed + git commit landed)
- ⚠️ blocked

## Phase status

| # | Phase | Status | Commit | QA evidence | Notes |
|---|---|---|---|---|---|
| 0 | Rewrite README + create this file | ✅ verified | (this commit) | `.claude/insta-options-qa/phase-0/qa-report.md` (local, gitignored) | QA verdict PASS on all 6 criteria; no blocking edits |
| 1 | Plumbing — config, API, WS, models, theme, route, shell, menu | ☐ todo | — | — | — |
| 2 | Option Chain (sub-screen 3) | ☐ todo | — | — | — |
| 3 | OI Buildup (sub-screen 8) | ☐ todo | — | — | — |
| 4 | OI Statistics + PCR (sub-screens 4 + 6) | ☐ todo | — | — | — |
| 5 | Per-Strike Options Chart (sub-screen 7) | ☐ todo | — | — | — |
| 6 | Trending OI (sub-screen 5) | ☐ todo | — | — | — |
| 7 | Markets Dashboard (sub-screen 1) | ☐ todo | — | — | — |
| 8 | Index Contributors (sub-screen 2) | ☐ todo | — | — | — |
| 9 | Find Strategy (sub-screen 9) | ☐ todo | — | — | — |
| 10 | Polish, golden tests, accessibility | ☐ todo | — | — | — |
| 11 | Open follow-ups housekeeping | ☐ todo | — | — | — |

## Confirmed scope (locked at start of build)

1. **OI Data backend is separate** from Mynt's Noren/`go.mynt.in` APIs. Base URL configurable via `Preferences` key `instaoptions:baseUrl`, default `http://192.168.5.61:8000`.
2. **No order placement / hand-off** in v1. BUY/SELL/chip buttons render visually only; tap shows a "coming soon" toast. Order wiring is a future sprint (section 3 of the README).
3. **Theme uses MyntColors light + dark** via `InstaOptionsTokens.of(context)`. No hex literals in widget code.
4. **Navigation:** single `/insta-options` route → `CustomizableSplitHomeScreen(initialRightPanel: ScreenTypeParam.instaOptions)` → internal side-rail in `InstaOptionsShell` switches between the 9 sub-screens.

## Open follow-ups (collected during the build)

- [ ] Wire order placement on `BasketChip` / B / S badges / Find-Strategy "Add to basket" (deferred — see README §3). Needs a decision on how legs flow to the existing `StrategyBuilderProvider`.
- [ ] Confirm production OI Data backend URL (currently dev IP `192.168.5.61:8000`).
- [ ] Add CI workflow for golden tests once Phase 10 lands.
- [ ] Decide whether to add per-sub-screen deep-link query params (e.g. `?screen=chain&symbol=NIFTY&expiry=30-JUN-2026`) — currently sub-screen state is in-memory only.

## How to resume

1. Read this file top-to-bottom.
2. Find the first row with status ☐ or ⏳.
3. Open [INSTAOPTIONS_FEATURE_README.md](INSTAOPTIONS_FEATURE_README.md) section that maps to that phase (see the build-order table in README §14).
4. Pick up from the phase's "Implementation steps" in the plan at `~/.claude/plans/instaoptions-feature-readme-md-i-wanted-twinkling-leaf.md`.
5. Each phase ends with: QA via a Chrome DevTools MCP sub-agent → save screenshots to `.claude/insta-options-qa/phase-N/` → `flutter analyze` clean → git commit with `instaoptions(phase-N): …` (no Co-Authored-By) → update this file in the same commit.
