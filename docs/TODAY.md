# Chart Engine — Running Log (2026-05-27)

Short list of everything we touched today. Append as we go. **Nothing committed yet** — flip the positions-API mock in `lib/api/portfolio_api.dart` to `mockEnabled = false` before any commit.

## Shipped today

### Phase 25.6 — Infinite-scroll history + watchlist change% fix
- **Infinite-scroll history** — chart was loading a single fixed window (5d for intraday, 60d for hourly, etc.) and going completely blank when the user panned past the leftmost loaded candle. Implemented top-up: every `scheduleRedraw` checks if leftmost visible candle index is within 20 bars of the array start; if so, fires a separate `_pendingExtendId` history request for the window before the oldest loaded candle. Throttled (one in-flight + 500ms cooldown). Response handler:
  - Prepends new candles (deduped by ts < oldestExisting.ts)
  - Compensates `offsetX -= merged.length * cellW` so the visible candles stay anchored in place instead of visually jumping right when the array grows
  - Marks `_noMoreHistory = true` if the server returns an empty page (so we stop pestering for symbols at the start of available data)
  - Resets `_noMoreHistory` on full reload (symbol/timeframe change) so new symbols start fresh
- **Watchlist change% always 0** — the panel was reading `socket['Change']` / `socket['PerChange']` (the API snapshot keys). The WS push uses `chng` / `pc` (lowercase). Fixed `_ScripTile` to read `socket['lp']` / `socket['chng']` / `socket['pc']` with model-field fallbacks. Now change values update live via WS.
- **Files touched:**
  - `web/chart-engine/chart.js` — `_pendingExtendId` / `_extendBlockedUntil` / `_noMoreHistory` fields, `_maybeExtendHistory()` method, `onHistoryResult` branch for extend, `scheduleRedraw` hook, reset in `_resetData`
  - `lib/screens/web/chart_engine/widgets/workspace/panels/watchlist_panel.dart` — `_ScripTile` socket keys (`chng`/`pc` instead of `Change`/`PerChange`)
- **Static gates:** `flutter analyze lib/screens/web/chart_engine` clean; `node --check web/chart-engine/chart.js` clean.

### Phase 25.5 — Leaked window message listeners (root cause of "Uncaught Error" spam)
- **Symptom:** console flooded with 5x/4x `Uncaught Error` on opening Charts, plus `Bad state: Using "ref" when a widget is about to or has been unmounted`.
- **Root cause:** `html.window.addEventListener('message', _onWindowMessage)` and the matching `removeEventListener('message', _onWindowMessage)` looked correct, but Dart's `this.method` tearoff creates a **new closure object on every access**. The reference passed to `removeEventListener` in `dispose` didn't match the one registered in `initState`, so the browser couldn't find it. Listeners leaked forever, each holding a `ref` from an unmounted state. Every iframe `chart-engine-ready` / `requestHistory` postMessage fired ALL the dead listeners → each one tried to use `ref` → threw "Bad state". The 5x/4x error counts matched the number of times the user had visited Charts in that session.
- **Fixes:**
  - Cache the tearoff once in `_windowMessageRef = _onWindowMessage` field; use it for both add and remove. Now they pair correctly.
  - Belt-and-braces: `if (!mounted) return;` at the top of `_onWindowMessageInner` so a future leak no-ops instead of throwing.
  - Wrap `_pushTheme` + the message handler in try/catch + `print` so any future failures surface a real error message instead of "Uncaught Error" with no info.
- **Files touched:** `lib/screens/web/chart_engine/chart_engine_shell_screen.dart`.
- **Static gates:** clean.

### Phase 25.4 — Watchlist tray rewritten on the provider's real data flow
- **Symptom:** clicking Nifty 50 / Bank Nifty / Sensex did nothing, user-defined watchlists (5 / Ram / Sectors / Abc) never appeared, "Watchlist · 5" header showed but body stayed "Open a watchlist to see scrips".
- **Root causes (multiple):**
  1. My first cut called `fetchMWScrip(name)` for predefined names like "Nifty50" — but the backend's `getMWScrip` API returns nothing for those because they're NOT real user watchlists. Predefined scrips live in a separate `_preDefinedMWlist` that's loaded by `fetchPreDefMWScrip(context)`, then `changeWLScrip(name)` decides which source to read from (predefined cache vs user-cache vs portfolio).
  2. I was reading `marketWatchScrip?.values` (the response of the LAST `fetchMWScrip` call) instead of `mw.scrips` (the actually-displayed list maintained by `changeWLScrip`).
  3. I was duplicating predefined names — prepending my own hardcoded `[My Stocks, Nifty50, Niftybank, Sensex]` AND appending `marketWatchlist?.values` (which already contains user+predefined combined after `fetchMWList`). When `marketWatchlist` was empty I only saw my 4 hardcoded names; when it loaded I would have shown 14 with dupes.
  4. The `_bootstrapped` boolean was set to `true` BEFORE the async work, so any exception silently locked out retry forever.
- **Fixes (full rewrite of `watchlist_panel.dart`):**
  - **Tab list:** use `marketWatchlist?.values` directly when populated (it's the source of truth, already user-sorted + predefined-appended). Fall back to a small hardcoded list only when not loaded yet, so the tab strip is never blank.
  - **Bootstrap:** runs `fetchPreDefMWScrip` first (predefined cache), then `fetchMWList(ctx, false)` (no `waitis` shortcut — wait for ALL user-defined scrips to fetch), then forces a switch to the active wlName so the body shows scrips immediately. State guards (`_bootstrapRunning` + `_bootstrapDone`) prevent re-entry without locking out retry on transient failure.
  - **Switch:** mirrors the proven mobile/web pattern — `requestMWScrip(unsub) → changeWlName(name, isPredef) → changeWLScrip(name, ctx)`. `changeWLScrip` internally re-subscribes for the new scrips, so no manual re-sub needed.
  - **Source of scrips:** `mw.scrips` (the active list maintained by `changeWLScrip`) with `marketWatchScripData[wlName]` cache as fallback. Each entry decoded back into a typed `WatchListValues` for rendering.
  - **"My Stocks" / "My Positions" specials:** synthesise `WatchListValues` rows from `portfolio.holdingsModel` / `portfolio.postionBookModel` so those tabs render even though the provider leaves `_scrips` empty for them.
  - **Loading indicator** while bootstrap fetches or a tab switch is in flight.
- **Files touched:** `lib/screens/web/chart_engine/widgets/workspace/panels/watchlist_panel.dart` (full rewrite — same public API, internals replaced).
- **Static gates:** `flutter analyze lib/screens/web/chart_engine` clean.

### Phase 25.3 — Chart overflow + watchlist empty-state fixes
- **Chart no longer overflows the viewport in multi-pane layouts** — root cause: CSS grid items default to a `min-content` minimum size on their grid axis, so when a chart canvas reported a tall intrinsic content (price chips + volume bars + sub-pane indicators), it forced the grid row to expand past `1fr` and pushed sibling panes off-screen. The user had to browser-zoom-out to 30% to see anything past the first pane. Fix: add `min-height: 0; min-width: 0` to `.pane` AND `#layout`, plus `overflow: hidden` on `#layout`. Also switched `#root` from `height: 100vh` to `height: 100%` since `100vh` inside a Flutter Web iframe occasionally reports the parent window's viewport rather than the iframe's own.
- **Watchlist tray now auto-loads on mount** — was showing "Open a watchlist to see scrips" forever even though the WL tabs rendered. Root cause: `wlName` was persisted from a prior session (e.g. "5") but `marketWatchlist` (the LIST of watchlists) and `marketWatchScrip` (the scrips for the active WL) hadn't been fetched yet — they only load when the main Watchlist screen mounts. The chart workspace never visits that screen.
- Fix: `_WatchlistPanelState._bootstrap()` runs once on first `build`'s post-frame:
  1. If `marketWatchlist` is empty → `fetchMWList(context, true)`
  2. If `marketWatchScrip.values` is empty → pick `wlName` (if it's in the names list) or fall back to the first available name (My Positions / My Stocks / Nifty50 / …) and call the existing 3-step switch (`unsub → fetch → sub`). Force the fetch even if `wlName == target` so the empty case is recovered.
- **Files touched:**
  - `web/chart-engine/style.css` — `#root` height fix, `#layout` + `.pane` min-height/min-width fix
  - `lib/screens/web/chart_engine/widgets/workspace/panels/watchlist_panel.dart` — added `_bootstrap()` + `force` param on `_switchTo`
- **Static gates:** `flutter analyze lib/screens/web/chart_engine` clean; `node --check` clean on both JS files.

### Phase 25.2 — Full-width chart + real mobile-style tray panels with actions (4-agent parallel)
- **Charts mode now truly full-width** — dropped the 220px left strip entirely. Index slots moved into the top row (320px column alongside the live-P&L ticker, below the navbar). The chart workspace takes everything from the navbar down to the right tray.
- **4 parallel agents implemented self-contained panel files** (each in `lib/screens/web/chart_engine/widgets/workspace/panels/`):
  - **`watchlist_panel.dart`** — horizontal tab strip across the top with predefined (My Positions / My Stocks / Nifty50 / Niftybank / Sensex) + user watchlists. Tap a tab → `requestMWScrip(unsub) → fetchMWScrip(name) → requestMWScrip(sub)` (mirrors how the existing watchlist screen switches). Scrip rows show exch chip + dispName + instname + live LTP/change% from `socketDatas[token]`. Tap row → applies to active chart pane.
  - **`positions_panel.dart`** — Total P&L card at top (sums profitNloss across open positions, color-coded). "Exit All Positions" button with AlertDialog confirm. Each position row: exch chip + symbol + LONG/SHORT pill, qty/avg/LP caption, P&L + per-row Exit outlined button. Exit calls `fetchExitPosition(ctx, PlaceOrderInput, isPosition:true, multipleexit:true)` — the `multipleexit:true` flag prevents the known Navigator.pop bug. Builds `PlaceOrderInput` using the exact pattern from `chart_engine_shell_screen.dart`.
  - **`holdings_panel.dart`** — Summary card (1D Change | Total P&L on row 1, Invested | Current on row 2, all color-coded). Each holding row: exch chip + symbol from `exchTsym[0].tsym` + lock icon when pledged subset (`dpQty != currentQty`), QTY/AVG + INV captions, P&L + change% + LTP on the right.
  - **`orders_panel.dart`** — Open / Executed tabs with counts (underlined pill style). Per-row: B/S color chip + symbol + status pill (COMPLETE green / CANCELED red / OPEN amber / REJECTED red). Cancel calls `fetchOrderCancel(norenordno, ctx, loop:true)` after AlertDialog confirm — provider handles its own toast + book refresh. Modify shows a SnackBar "Modify from main Orders screen" (full modify wiring deferred — needs `ModifyPlaceOrderScreenWeb.showDraggable` which doesn't host cleanly in 320px). Cancel fully works.
- **`right_tray.dart` slimmed** — now just the 40px icon strip + 320px panel container + dispatcher to the 4 panel files (was 500+ lines of mixed concerns).
- **Files touched:**
  - `lib/screens/web/customizable_split_home_screen.dart` — charts-mode layout rewritten to full-width Column[navbar, Row[indices(320), ticker], Expanded(chart)]
  - `lib/screens/web/chart_engine/widgets/workspace/right_tray.dart` — full rewrite (slimmed to dispatcher)
  - NEW: `lib/screens/web/chart_engine/widgets/workspace/panels/{watchlist,positions,holdings,orders}_panel.dart`
- **Static gates:** `flutter analyze lib/screens/web/chart_engine` clean. (45 pre-existing issues in `customizable_split_home_screen.dart` are unrelated `withOpacity` deprecations + dead code.)
- **Known gaps:** Orders Modify is a SnackBar stub. BO/CO order cancels go through the standard `fetchOrderCancel` path (not `fetchExitSNOOrd`) — fine for normal orders, may not handle BO/CO leg cancellation correctly. Both addressable in a 25.3 follow-up if needed after smoke testing.

### Phase 25.1 — Charts mode (left collapse + right-tray wired with mobile-style rows)
- **Hidden watchlist body in charts mode** — added `_isChartsMode` to `customizable_split_home_screen.dart` (mirroring `_isScalperMode`). When the user taps "Charts" from the nav drawer or the URL hits `/charts`, the layout collapses to: 220px left strip (index slots only) + 1px divider + full-width Column [navbar, PortfolioTickerStrip, ChartWorkspaceScreen]. Search bar + watchlist tabs + scrip list are no longer rendered. Exits cleanly when any other nav item is tapped.
- **RightTray panels fully wired** — replaced the 4 placeholder panels with live data-bound compact rows:
  - **Watchlist** — `marketWatch.marketWatchScrip?.values` → list of `WatchListValues`. Each row: exch chip + dispName + instname subtitle + live LTP / change% / per-change (color-coded). Header shows current wlName.
  - **Positions** — `portfolio.postionBookModel` filtered by stat≠Not_Ok and tsym non-empty. Each row: exch chip + dispName + "Qty N [SHORT]  ·  LP X" subtitle + P&L color-coded.
  - **Holdings** — `portfolio.holdingsModel` → uses each row's first `exchTsym[0]` for the tradable scrip. Subtitle shows "Qty N · Avg X · LP Y". Trailing: totalPnL color-coded.
  - **Orders** — `order.orderBookModel`. B/S leading chip (green/red), title from dname, subtitle "Qty N · prctyp prc · STATUS".
  - **DOM** — unchanged (already wired in Phase 25).
- **Mobile-style row** — new `_CompactRow` (56px tall, hover bg, click→onSymbolPick → setPaneSymbol(activeIdx, scrip)). Reads live LTP from `websocketProvider.socketDatas[token]` with fallback to the model's snapshot fields (`lp`/`Change`/`PerChange`). Auto-rebuilds when WS pushes.
- **Files touched:**
  - `lib/screens/web/customizable_split_home_screen.dart` — `_isChartsMode` field, charts-mode branch in `_buildNewLayout`, setters in `_handleChartsTap` + `_navigateToScreen` + `_replaceScreenInPanel` + nav-item onTap + the activate-tab switch
  - `lib/screens/web/chart_engine/widgets/workspace/right_tray.dart` — full rewrite (placeholder MVP → 4 wired panels + shared `_CompactRow` / `_LiveLtp` / `_ExchChip` / `_PanelHeader` / `_PanelEmpty` helpers)
- **Static gates:** `flutter analyze lib/screens/web/chart_engine` clean.

### Phase 25 — Workspace overhaul + screenshot + auto-pattern + 5 indicators (3-agent parallel)
- **Fullscreen chart workspace** — new `ChartWorkspaceScreen` replaces the bare `ChartEngineShellScreen` in [customizable_split_home_screen.dart:2852](lib/screens/web/customizable_split_home_screen.dart#L2852). Chart fills the entire content area; a 40px vertical icon strip lives flush on the right.
- **Right tray** — 5 tabs (Watchlist / Positions / Holdings / Orders / DOM). Click an icon to slide out a 320px panel; click again to collapse. Active-tab indicator = 2px accent border on the right edge of the icon. Any symbol picked inside a panel applies to the currently active pane via `setPaneSymbol(activePaneIndex, scrip)`.
- **DOM panel** — fully wired. Reads `websocketProvider.socketDatas[scrip.token]` for `bp1-5 / bq1-5 / sp1-5 / sq1-5`, renders 5 rows with proportional depth-bar backgrounds (profit-green bid right→left, loss-red ask left→right, 0.18 alpha). Live-updates on every WS push via `ref.watch(websocketProvider)`.
- **Watchlist/Positions/Holdings/Orders panels** — MVP placeholders. Reason: the existing screens (`WatchlistScreenWeb` etc.) carry their own scaffolds + app bars + routing assumptions that would conflict with being hosted inside a 320px sidebar. Phase 25.1 will replace with lightweight list views.
- **Screenshot** — new "Screenshot" `TextButton.icon` in the chart top bar. Bumps `screenshotRequestProvider`'s counter; chart.js's `takeScreenshot()` runs `canvas.toDataURL()` and posts back a `chartScreenshot` message with the data URL + sanitised filename.
- **Auto-pattern markers** — per-pane Settings toggle "Show Auto-pattern (HH/HL/LH/LL)". `_computeSwingPoints(5)` walks the visible candles, marks pivot highs/lows, labels each with `HH`/`HL`/`LH`/`LL` based on the previous pivot of the same kind. Small magenta/teal dot + 9px label at the pivot wick.
- **5 new indicators** — `AO` (Awesome Oscillator), `MFI` (Money Flow Index, 14), `OBV` (On-Balance Volume), `CMF` (Chaikin Money Flow, 20), `WR` (Williams %R, 14). All as sub-pane oscillators; selectable from the fx Indicators dialog.
- **Files touched:**
  - JS: `web/chart-engine/chart.js` (screenshot + auto-pattern + 5 indicators), `web/chart-engine/chart-engine.js` (2 new postMessage handlers)
  - Dart store/bridge: `chart_engine_store.dart` (`PaneState.showAutoPattern` + persist as `showAp`, `setPaneShowAutoPattern`, `ScreenshotRequestNotifier` + `screenshotRequestProvider`), `chart_engine_bridge.dart` (2 encoders)
  - Dart UI: `chart_engine_top_bar.dart` (`_PaneShowAutoPatternSection`, 5 indicator catalog entries, screenshot button)
  - NEW: `lib/screens/web/chart_engine/widgets/workspace/{chart_workspace_screen,right_tray,dom_panel}.dart`
  - `customizable_split_home_screen.dart` (1-line import swap + `ChartEngineShellScreen` → `ChartWorkspaceScreen`)
- **Static gates:** `flutter analyze lib/screens/web/chart_engine` clean; `node --check` clean on both JS files.

### Phase 16 — Multiple candle styles + visible-range H/L markers
- 6 new chart styles selectable per pane (Hollow, OHLC Bars, Line, Area, Heikin-Ashi, Renko — Renko later hidden but code retained)
- Visible-range H/L dot markers (Sahi-style inline)
- Switched Renko OFF from the picker (kept JS infrastructure as dead code)

### Phase 17 — Order UX trio
- **17.C** drag-modify flicker fix (`_pendingOverlayMoves` keeps optimistic chip until server confirms)
- **17.B** TP/SL chips now show projected P&L instead of trigger price
- **17.A** Option position on underlying — strike line + "25250 PE" chip + close × that squares off the option

### Phase 18 — Option-chain OI + bar-close countdown
- **18.A** OI bars at strikes (CE teal + PE orange) with hover tooltip showing Strike / Call OI / Put OI / change %
- **18.B** Bar-close countdown extending the LTP chip downward
- Volume reworked as a transparent overlay (no separate panel — gave back 22% of vertical space)
- Strike-chip color darkened from `#A78BFA` → `#8B5CF6` for readable white-on-violet contrast
- WS subscribe priming push (forwards already-cached LTP into the iframe synchronously)
- Iframe focus-grab broadened (mousemove + pointerover + 3s polling fallback)

### Phase 19 — Drawings + Indicators UX
- **19.1** `_tsToX` binary-search lookup fix (trendline + rect now land where clicked)
- **19.2** Rectangle is click-drag-release (mousedown anchors, drag previews, mouseup commits)
- **19.3** New Horizontal Ray drawing kind
- **19.4** New "fx" button in top bar → Indicators dialog with search + categories (Trend / Momentum / Volatility) + active-list with period/color editor
- **19.5** Removed Indicators from Settings popup (now purely display toggles)

### Phase 20 — Polish + Key Levels + bulk indicators
- **20.1** Three bug fixes: tpseries dedup (setTimeout-0 scheduler), OI fires immediately on toggle ON, crosshair cursor in draw mode
- **20.2** Key Levels — per-pane toggle, computes PP / R1-R3 / S1-S3 from previous trading day's H/L/C, draws dashed lines with labels
- **20.3** Five new indicators in the fx dialog: **ZLEMA**, **McGinley Dynamic**, **Stochastic RSI**, **Squeeze Momentum**, **Elder's Force Index**

### Phase 20.1 — OI fetch flow rework
- Switched from single `getOptionChain(tradeSym: 'NIFTY')` (gives 400) to the 2-step flow used by `watchlist_oc_provider`:
  1. `getLinkedScrip(token, exch)` → expiry list (sorted by date, picks nearest)
  2. `getOptionChain(tradeSym: nearestExpiry.tsym)` → strikes
- New `ChartOptionExpiry` + `chartOptionExpiryProvider` per-pane cache
- Cache invalidated on toggle-off / scrip change
- 2s retry gap on linkedScrip; 120s refresh on chain (unchanged)

### Phase 21 — Drawing tools batch 2
- **Fib Retracement** — 2-click anchor; renders 7 horizontal lines at 0/23.6/38.2/50/61.8/78.6/100% with per-level colors + price labels at the left edge
- **Path (multi-point polyline)** — click to add point (cap 32); double-click OR Esc commits; in-progress preview from last point to cursor

### Phase 22 — Indicators batch 2 (5 more)
- **MA Ribbon** — 8 EMAs at 5/10/20/30/40/50/60/80 in HSL fading blue
- **Ichimoku Cloud** — Tenkan + Kijun + SpanA + SpanB lines + filled cloud (Trend overlay)
- **Volatility Stop** — ATR×2 trailing stop, dotted green/red flipping on direction
- **WaveTrend Oscillator** — LazyBear WT1+WT2 in own sub-pane with ±50/0 references
- **Connors RSI** — `(RSI+RSI(streak,2)+PctRank(ROC,100))/3` in sub-pane with 70/30 lines

### Phase 20.2 — WS forwarder also subscribes to `socketDataStream`
- Bug: NIFTY 50 / SENSEX spot charts didn't update (positions/options did), because the WS provider's `notifyListeners` is gated by `hasUpdates` and sometimes suppresses for index tokens while still pushing the stream
- Fix: chart's WS forwarder now listens on BOTH `addListener` AND `socketDataStream.listen` (same path every working consumer uses — watchlist, option chain, futures). Duplicate ticks are safe — iframe's bar aggregator is idempotent on identical lp.

### Phase 24.5 — `_lpOnly` detection missed `v === 0`
- After 24.4 the bid/ask chips updated live (showed LTP) but the chart bars STILL didn't tick. Root cause: `_lpOnly = (v == null)` only catches "v field absent". The broker actually sends `v: '0'` for indices (string zero, not null), which becomes the number `0` — passes `v != null` → `_lpOnly = false` → aggregator enters volume-tracked branch → `dv = 0 - 0 = 0` → skipped.
- Fix: `_lpOnly = (v == null || v === 0)`. Stocks at session-open with v=0 momentarily fall into lpOnly mode (harmless — bar's close still updates; volume tracking just doesn't accumulate the zero deltas until the first real volume tick).

### Phase 24.4 — Two more index-related fixes
- **LTP still stuck on indices after 24.2** — root cause: `_lpOnly` ticks synthesize `ft = Date.now()/1000`, but the last historical bar's `ts` came from the SERVER (which may be ahead of client by minutes due to clock skew). `bucketSec < c.ts` was firing → every tick skipped. Fix: in `lpOnly` mode, if `bucketSec < c.ts`, still update the existing bar's close instead of dropping. Bars stop advancing into NEW buckets in that scenario, but at least the current bar tracks live price.
- **`isNonTradable` not detecting persisted scrips** — Phase 24.3 added `instname` to ChartScrip but old persisted scrips don't have it. Also, the broker doesn't always return `'INDEX'` for SENSEX etc. Fix: dynamic heuristic — if `tickState.bid === 0 && tickState.ask === 0` (the signature of an index, since real instruments quote actual values), treat as non-tradable regardless of `instname`. Both the chip render AND the +/Alt-B/Alt-S gates use the same dual-detection (explicit OR heuristic).

### Phase 24.3 — Non-tradable scrips render bid/ask as LTP + lighter, no order paths
- Added `instname: String` field to `ChartScrip`. Symbol picker now passes `v.instname` from the search response.
- chart.js: when `instname` is `'UNDIND'` / `'INDEX'` / `'COM'`:
  - Bid + Ask chips both show LTP value (not the missing real bid/ask), with reduced 0.30 alpha on the red/blue fills + muted axis-text label (instead of bold white)
  - Center column shows a small `INDEX` / `COM` tag instead of the qty chip (no qty editor, can't place orders)
  - `_headerHits.push` skipped for bid/ask/qty → clicks are inert
  - `_drawPlusIcon` no-ops (no click-to-order popup)
  - `_postQuickPlace` (Alt+B / Alt+S) no-ops
- Other tradable instruments (stocks, options, futures, MCX commodities other than spot) unchanged.

### Phase 24.2 — Second-layer fix for index LTP (aggregator's volume-delta gate)
- After Phase 24.1 fix (`ingestTick` no longer required v+ft), the next gate inside `aggregator.js:ingestTickIntoBucket` STILL killed index ticks: `dv = cumVol - prevCumVol; if (dv <= 0) return 'skipped'`. For an index synthetic `v=0`, every tick had `dv = 0 - 0 = 0` → all skipped → bar's close still frozen.
- Fix: pass `_lpOnly: true` from `ingestTick` when broker omits `v`. The aggregator now bypasses the volume-delta gate in lpOnly mode and aggregates purely on `lp + ft`. Stock/option/futures ticks (with real `v`) continue to use the existing volume-tracked path.

### Phase 24.1 — Final root-cause fix for NIFTY/SENSEX LTP not updating
- Symptom: chart loaded, ticks reached the iframe (`tokenToPanesHas=true`, `targets=1`), but the LTP chip and bar's close stayed frozen.
- Root cause: `ingestTick`'s gate at chart.js line 419 required `lp != null && v != null && ft != null` before calling `ingestTickIntoBucket`. Indices (NIFTY 50 = NSE/26000, SENSEX = BSE/1) are calculated values with NO traded volume — broker never sends `v`. The function early-returned forever. Stocks/options had `v` so they worked, masking the bug.
- Fix: require ONLY `lp != null`. Synthesise `v=0` and `ft=now` when absent so the aggregator can still update the bar's close from `lp`.
- Z-order fix (also today): `_drawOverlayPriceChips` moved AFTER `_drawPriceAxis` so the strike's right-axis chip (purple white-on-violet) isn't overwritten by the standard nice-stride axis label at the same Y.

### Phase 24 — Fix-up batch (6 fixes + 1 removal, 3-agent parallel dispatch)
- **1s tick poll-forward** — added `Timer.periodic(1s)` that calls the same `_wsForwardAll` body. Belt-and-braces over the stream + addListener paths; guarantees chart updates at least 1Hz for every subscribed token, including indices where the WS provider's `hasUpdates` gate sometimes suppresses both paths.
- **OI flow now WS-driven** — chain API called ONCE per refresh window (now 10min instead of 2min) to enumerate strikes + initial OI; then subscribes via WS to all option tokens; on every WS tick, `_refreshOiFromWs` reads `socketDatas[token]['oi']` and re-publishes the strike list. Change % derived from `(oi - poi) / poi * 100`. Live updates instead of polling.
- **OI 2-step throttle bug** — linkedScrips stamp was using the same `chartOiDataProvider.fetchedAtByPane` map as the chain-fetch gate, so step 2 (chain fetch) was being skipped because "we just fetched". Fixed by separating throttles.
- **Rectangle drawing fix** — two root causes: (1) mousemove didn't update `this.hover.x/y` during rect drag, leaving the renderer with stale coords; (2) `_tsToX(_xToTs(rx))` round-trip snapped to candle center, collapsing same-candle drags to zero width. Fix: in-progress rect render now uses live `hover.x/y` directly instead of `_tsToX` of the stored point.
- **Magnet visual indicator** — when in draw mode + magnet ON + hovering near OHLC, a 4px white-filled cyan ring marks the snap target with a small `H 23980.50` label.
- **Instant labels shortened** — `Follow global / Always instant / Always confirm` → `Follow / Instant / Confirm` so the 3-button row fits inside the 220px popup width.
- **Removed Multi-TF sparkline** — entire feature deleted (PaneState field, notifier, bridge encoders, JS handlers, render method, Settings UI). User feedback: not wanted.

### Phase 23 — Polish + Sahi-parity batch (5 features, 3-agent parallel dispatch)
- **Pivot variants** — Key Levels toggle now picks Classical / Fibonacci / Camarilla via Settings dropdown (3-button row). Labels prefixed `F`/`C` when not Classical.
- **Magnet (snap to OHLC)** — per-pane toggle. When ON and in any draw mode, the click snaps to the nearest OHLC value of the candle under cursor (within 8px), plus snaps `ts` to the bar boundary.
- **Drawing lock + hide-all + trash** — three new actions in the Draw popup (after the drawing kinds). Lock = drag/delete hits disabled. Hide = `_drawDrawings` early-returns. Trash = `clearDrawingsForActivePane` removes all drawings for the active pane's scrip.
- **Volume profile** — per-pane toggle. 24-bin horizontal histogram in a 60px right-gutter (sits past the price axis labels). Sky-blue with 45% alpha.
- **Multi-TF sparkline** — per-pane dropdown: Off / 1h / 4h / 1D / 1W. Mini area+line chart 120×50 in the top-right corner. Shell fetches `getTPSeriesChart` for the chosen TF every 5min (or immediately on change), pushes `{ts, c}` payload to iframe.
- **Files touched (final):** chart.js + chart-engine.js + chart_engine_store.dart + chart_engine_bridge.dart + chart_engine_shell_screen.dart + chart_engine_top_bar.dart

---

## Pending / open

- **Smoke** — Phases 16–20 + 20.1 all uncommitted. ~25 files.
- **Mock** — positions-API mock is ON in `lib/api/portfolio_api.dart` — toggle off before commit.
- **20.1 in-flight** — OI fetch flow rework dispatched in background; will report when done.

## Next-up queue (your pick)

1. **Time-gap compression** — session-to-session blank space on X-axis (still on the table; you said you don't see it now)
2. **More indicators batch 2** — 5-7 more (WaveTrend, Connors RSI, Moving Average Ribbon, Ichimoku, Volatility Stop, …) to keep narrowing the Sahi indicator-count gap
3. **Pivot-point variants** — Fibonacci pivots + Camarilla pivots as a dropdown on the Key Levels toggle
4. **Drawing tools** — Fib Retracement, Path (multi-point), Channel, Text annotation, Brush
5. **Magnet / snap-to-candle** — drawings snap to OHLC values when within a few pixels
6. **Drawing lock + hide-all + trash all** — TradingView-style toolbar bottom buttons
7. **Volume Profile** — horizontal histogram on the right gutter showing volume at each price level
8. **Bar replay mode** — scroll back to a point in history and step-by-step forward
9. **Multi-timeframe analysis** — small sparkline of higher-TF inside the current pane
10. **Bulk-add OI strikes config** — let user pick strike count (15 / 25 / 50) + refresh interval (1m / 2m / 5m)
