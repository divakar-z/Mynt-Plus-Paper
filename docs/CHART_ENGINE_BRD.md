# Business Requirements Document — In-House Charts (Chart Engine)

**Platform:** Mynt Plus — Web Trading Platform (Flutter Web)
**Module:** Charts → In-House Chart Engine
**Document Version:** 2.0
**Date:** June 2026
**Status:** Issued for Review
**Classification:** Internal Use Only

---

## Document Control

| Field | Value |
|---|---|
| **Document Title** | In-House Charts — Business Requirements Document |
| **Module Scope** | The full in-house chart engine — the TradingView-style charting surface where a trader views price, applies indicators and drawings, lays out multiple charts, and places / manages orders directly from the chart, together with the trading panels (Watchlist, Positions, Holdings, Orders, Option Chain, Depth of Market) that surround it. |
| **Audience** | Quality Assurance, Product Management, Engineering |
| **Purpose** | To document, in plain English, every user-facing and testable behaviour of the chart engine so a manual tester can verify each feature without reading code. |
| **How to read** | Each numbered section is a functional area. Within it, every requirement has a unique ID (e.g. CE-SYM-005), a **Description** (what it is and why it matters), a **Business rule** (the precise rules, values, and on-screen wording), **Acceptance criteria** (specific things to confirm), and **Edge cases & negative scenarios** (tricky situations and the expected handling). |
| **Out of Scope** | The legacy/third-party chart engine, the mobile chart, back-end data correctness, and ladder click-to-trade on the Depth-of-Market panel (data display only at this stage). |

---

## Table of Contents

1. Scope & Context
2. Workspace, Layout & Panes
3. Symbol Search & Selection
4. Timeframe
5. Chart Type & Appearance
6. View-on-Chart Overlays
7. Technical Indicators
8. ICT / SMC Indicator Pack
9. Drawing Tools
10. Placing Orders from the Chart
11. Order Defaults
12. On-Chart Overlays (Positions, Orders, Alerts)
13. Confirmation & Instant-Orders Behaviour
14. Workspace Panels
15. Depth of Market (DOM)
16. Option Chain Panel
17. Keyboard Shortcuts
18. Chart Data States & Error Handling
19. Theme, Persistence & Cross-Cutting Behaviour

---

## 1. Scope & Context

The in-house chart engine is the primary surface for technical analysis and chart-based trading on the web platform. It is a multi-pane charting workspace embedded in the trading shell. A trader can:

- Search for and load any tradeable symbol across NSE, BSE, NFO, BFO, MCX and CDS.
- View price in six chart styles across a wide range of timeframes.
- Add, configure and remove 30+ technical indicators, including a dedicated ICT / SMC pack.
- Draw and annotate using seven drawing tools.
- Place, modify, cancel and exit orders directly from the chart.
- See live positions, pending orders and alerts as overlay lines on the chart.
- Open side panels for Watchlist, Positions, Holdings, Orders, Option Chain and Depth of Market.

This document describes the expected behaviour of every one of those capabilities at a level of detail a manual tester can act on. Where a requirement depends on another (for example, the active-pane concept underpins almost every per-pane control), the dependency is noted in the relevant requirement.

---

## 2. Workspace, Layout & Panes

#### CE-LAY-001 — Multi-pane layouts

**Description.** A trader can split the chart workspace into between one and six independent chart panes, so several symbols, timeframes, or chart styles can be watched side by side at once. The available arrangements are chosen from a layout picker that previews each option as a small grid drawing (glyph).

**Business rule.**
- The system supports exactly these pane counts: 1, 2, 3, 4, 5, and 6 panes.
- The picker lists every available arrangement grouped into rows by pane count, ordered ascending (1 first, then 2, 3, 4, 5, 6). A small numeric label (1–6) marks each row.
- The full set of arrangements offered is: 1 pane (single full-width); 2 panes (side-by-side, and stacked); 3 panes (three columns; three rows; one-on-top/two-below; two-on-top/one-below; one-left/two-right; two-left/one-right); 4 panes (2x2 grid; four columns; four rows; one-on-top/three-below; three-on-top/one-below; one-left/three-right; three-left/one-right); 5 panes (one-on-top/four-below; four-on-top/one-below; one-left/four-right; four-left/one-right; two-over-three); 6 panes (3-across by 2-down; 2-across by 3-down).
- Each option is shown as a miniature grid glyph reflecting the real cell shapes; the active arrangement is highlighted with an accent colour and outline. The trigger button shows the active layout's glyph.

**Acceptance criteria.**
- Opening the picker shows arrangements grouped under numeric headings 1 through 6, in that order.
- Every glyph visually matches its arrangement (e.g. "one-on-top/two-below" shows one wide cell above two cells).
- The currently active arrangement is visibly highlighted.
- The trigger button displays the active layout's glyph and updates when the layout changes.
- A brand-new session opens on the single full-width pane.

**Edge cases & negative scenarios.**
- If the layout is changed from another source while the picker is open, the highlighted selection updates to match.
- Clicking the trigger again while the picker is open closes it rather than duplicating it.
- Clicking outside the picker closes it without changing the layout.

#### CE-LAY-002 — Applying a layout

**Description.** Selecting an arrangement from the picker immediately reshapes the workspace into that many panes, letting the trader reconfigure their screen in a single click.

**Business rule.**
- Selecting an arrangement applies it immediately and closes the picker.
- Selecting the already-active arrangement makes no change (no flicker, no pane reset).
- After applying, the number of live panes always equals the selected arrangement's pane count.

**Acceptance criteria.**
- Choosing an arrangement reshapes the workspace at once and dismisses the picker.
- The pane count after applying matches the chosen arrangement exactly.
- Re-selecting the already-active arrangement leaves the workspace unchanged.

**Edge cases & negative scenarios.**
- Rapidly clicking several arrangements ends on the last one chosen, with the workspace consistent with that final choice.
- The layout can also be changed from within the chart area's own toolbar; both entry points produce the same result.

#### CE-LAY-003 — Active pane concept

**Description.** Exactly one pane is the "active" pane at any time. Toolbar controls (symbol search, timeframe, chart style, indicators, view toggles, draw tool) act on the active pane, so the trader always knows which chart their next action will affect.

**Business rule.**
- At all times exactly one pane is active; its index is remembered.
- Clicking into a pane makes it the active pane.
- Toolbar actions — choosing a symbol, timeframe, chart style, adding/removing an indicator, toggling a view option, picking a draw tool — apply to the active pane only.
- The toolbar reflects the active pane's current symbol, timeframe and chart style.

**Acceptance criteria.**
- Clicking a different pane switches the active pane, and the toolbar's symbol, timeframe and style update to that pane's values.
- A symbol/timeframe/style/indicator change affects only the active pane; the others are untouched.
- In a single-pane layout, that one pane is always the active pane.

**Edge cases & negative scenarios.**
- If a message identifying the newly activated pane is malformed or names a non-existent pane index, the active pane is left unchanged.
- Switching the active pane to the pane that is already active makes no change.

#### CE-LAY-004 — Per-pane independence

**Description.** Every pane holds its own complete set of settings — symbol, timeframe, chart style, indicators, on-chart view toggles, order quantity, instant-order override, and drawings — so a trader can run a 1-minute candle chart of one symbol next to a daily line chart of another.

**Business rule.**
- Each pane independently stores: selected symbol, timeframe, chart style, list of indicators, order quantity, per-pane instant-order override, and all on-chart view toggles (high/low markers, option-chain OI, bar countdown, key levels and pivot variant, auto-pattern, magnet, volume profile, crosshair lines, gridlines, volume sub-pane).
- Changing any of these on one pane must not alter the same setting on any other pane.
- Drawings are stored against the symbol, not the pane (see CE-LAY-007).

**Acceptance criteria.**
- Setting different symbols, timeframes and styles in two panes shows two independent charts.
- Adding an indicator to one pane does not add it to others.
- Toggling a view option (e.g. gridlines, volume sub-pane, key levels) in one pane leaves the other panes unchanged.
- Each pane shows its own order-quantity and instant-order behaviour.

**Edge cases & negative scenarios.**
- A pane with no symbol still retains its own timeframe, style and toggle settings.
- View toggles set on the active pane apply only to that pane even when several panes show the same symbol.

#### CE-LAY-005 — Resizing panes via splitters

**Description.** When more than one pane is shown, the dividers between panes can be dragged to give more space to one chart and less to another.

**Business rule.**
- In any multi-pane layout, the boundaries between panes act as draggable splitters.
- Dragging a splitter reallocates space between the adjacent panes/rows/columns; the workspace stays fully filled (no gaps).
- Panes begin at equal proportions for the chosen arrangement.

**Acceptance criteria.**
- With two or more panes, hovering a divider indicates it can be dragged.
- Dragging a divider enlarges one pane and shrinks its neighbour, and the charts re-render to the new sizes.
- The whole workspace remains gap-free during and after a resize.

**Edge cases & negative scenarios.**
- A splitter cannot be dragged so far that a neighbouring pane collapses to nothing.
- In a single-pane layout there are no splitters to drag.
- Dragging a splitter does not change which pane is active or any pane's symbol/timeframe.
- Note: resized pane proportions are not currently remembered across reloads; panes return to equal proportions on the next session (see CE-LAY-008).

#### CE-LAY-006 — Expanding the layout (new panes inherit from active pane)

**Description.** When a trader switches to a layout with more panes than before, the newly created panes start as copies of the currently active pane, so the trader gets a useful starting point instead of blank charts.

**Business rule.**
- When the new arrangement has more panes than the current one, all existing panes are kept, and each additional pane is created as a copy of the active pane (its symbol, timeframe, style, indicators, quantity, overrides and toggles).
- The active pane remains the same pane after expanding.

**Acceptance criteria.**
- Going from a smaller to a larger arrangement preserves the contents of all existing panes.
- Each newly added pane initially shows the same symbol, timeframe and style as the active pane.
- The active pane indicator does not move to a new pane when expanding.

**Edge cases & negative scenarios.**
- Expanding when the active pane has no symbol creates additional empty panes rather than failing.
- Going from 1 pane straight to 6 panes fills all five new panes from the single existing pane.

#### CE-LAY-007 — Shrinking the layout (drawings retained, keyed to symbol)

**Description.** When a trader switches to a layout with fewer panes, the system keeps the active pane and a subset of the others, and any drawings the trader made are not lost because drawings are remembered per symbol rather than per pane.

**Business rule.**
- When the new arrangement has fewer panes, the active pane is kept as the first pane, then the remaining panes are kept in order until the new count is reached; surplus panes are dropped.
- After shrinking, the first (kept active) pane becomes the active pane.
- Drawings are stored against each symbol, so dropping a pane does not delete that symbol's drawings; re-selecting the symbol in any pane restores them.

**Acceptance criteria.**
- Going from a larger to a smaller arrangement keeps the active pane's chart, now shown as the first pane.
- After shrinking, the active pane is the first pane.
- A symbol that had drawings, if re-opened in any pane, shows those drawings again.

**Edge cases & negative scenarios.**
- Drawings made on a symbol shown only in a dropped pane are not erased — they reappear when that symbol is loaded again.
- Shrinking never leaves zero panes; the minimum is one.

#### CE-LAY-008 — Layout & pane-size persistence across sessions

**Description.** The workspace remembers the trader's layout and per-pane setup between visits, so reopening the chart restores their working environment instead of resetting to a blank single chart.

**Business rule.**
- The active layout, the active pane index, and every pane's full configuration (symbol, timeframe, style, indicators, quantity, overrides, view toggles) are saved locally and restored on the next session.
- Saved drawings (keyed by symbol), global instant-orders state, the instant-orders warning-acknowledged flag, the keyboard-shortcuts on/off state, and the global drawings-locked / drawings-hidden flags are also persisted.
- Persistence is written shortly after a change (debounced), not on every keystroke.
- The stored pane count is reconciled to the saved layout's pane count on restore (padding with empty panes or truncating extras as needed).
- The currently selected draw tool is intentionally not persisted; it resets to "none" on reload.

**Acceptance criteria.**
- After setting up multiple panes with symbols/timeframes/styles and reloading, the same layout and pane contents reappear.
- The active pane after reload is the one that was active before.
- Saved drawings reappear on reload for their symbols.
- A first-time session with nothing saved opens on the default single pane.

**Edge cases & negative scenarios.**
- If saved data is missing, empty, or corrupted, the workspace falls back cleanly to the default single-pane state rather than erroring.
- If the saved pane count disagrees with the saved layout, the pane list is padded or trimmed to match, with extra panes created empty.
- After reload, no draw tool is pre-selected even if one was active when the page was last closed.

#### CE-LAY-009 — No active pane state

**Description.** Toolbar panels that act on the active pane must behave gracefully in the rare moment when no pane is available to act on.

**Business rule.**
- When there is no valid active pane, pane-targeted toolbar tabs/popovers must not act on a missing pane.
- The "1-Tap" order-defaults panel shows the message "No active pane." in its per-pane override section when no pane is available.
- Pane-targeted settings tabs render nothing (collapse) rather than throwing when the active pane index is out of range.

**Acceptance criteria.**
- With no active pane, the per-pane instant-override control is replaced by the text "No active pane."
- Pane-specific settings/view tabs do not error when no valid pane exists; they show nothing.
- Global settings (instant orders, drawings lock/hide, keyboard shortcuts) remain usable even when no pane is active.

**Edge cases & negative scenarios.**
- A view-toggle or style change attempted while no pane is active is safely ignored.
- The condition is transient; once a pane exists the controls return to normal.

---

## 3. Symbol Search & Selection

#### CE-SYM-001 — Symbol search field

**Description.** A search field lets the trader type a company or instrument name/code and load it into the active pane, which is the primary way to choose what a chart displays.

**Business rule.**
- The field shows the placeholder "Search symbol…" when empty.
- When a pane already has a symbol, the field pre-fills with that symbol's display name.
- Focusing the field opens the results dropdown and selects existing text so the trader can type over it.
- Typing is debounced (a short pause after the last keystroke) before a search runs.

**Acceptance criteria.**
- An empty field shows "Search symbol…".
- The field reflects the active pane's current symbol name when one is loaded.
- Clicking into the field selects any existing text and opens the dropdown.
- The field follows the active pane (changing active pane updates it) when not being edited.

**Edge cases & negative scenarios.**
- Switching the active pane while the field has focus does not overwrite what the trader is currently typing.
- Clearing the field shows the placeholder again.

#### CE-SYM-002 — Minimum 2 characters

**Description.** The search requires at least two characters before it queries, preventing noisy results from a single character.

**Business rule.**
- A search only runs when the trimmed input is two characters or more.
- With fewer than two characters, no search runs and the dropdown shows "Type at least 2 characters to search".

**Acceptance criteria.**
- Typing one character shows "Type at least 2 characters to search" and runs no search.
- Typing a second character triggers a search.
- Leading/trailing spaces do not count toward the two-character minimum.

**Edge cases & negative scenarios.**
- Typing two characters then deleting back to one clears prior results and returns to the hint message.
- Two spaces (which trim to empty) are treated as under the minimum.

#### CE-SYM-003 — Search results

**Description.** Results list matching instruments with enough detail (name, exchange, instrument type) for the trader to pick the right one, covering all the major Indian exchanges.

**Business rule.**
- The search covers NSE, BSE, NFO, BFO, MCX and CDS.
- Each row shows the display name prominently, with the exchange and instrument type beneath it, separated by a middot (for example, "NSE · EQ").
- Results appear in the order returned by the search service.

**Acceptance criteria.**
- A search returns matches drawn from NSE, BSE, NFO, BFO, MCX and CDS as applicable.
- Each row shows a name plus an exchange-and-instrument-type line.
- Equities, derivatives, and commodity/currency instruments all appear when matched.

**Edge cases & negative scenarios.**
- A result missing a display name falls back to showing its trading symbol.
- A result missing exchange or instrument type still renders without breaking the row layout.

#### CE-SYM-004 — Loading spinner

**Description.** While a search is in progress the dropdown shows a spinner, so the trader knows the system is working.

**Business rule.**
- From the moment a qualifying search starts until results (or an empty result) arrive, the dropdown shows a centred loading spinner that replaces the result list and any hint message.

**Acceptance criteria.**
- Typing a valid query shows a spinner until results arrive.
- Once results arrive the spinner is replaced by the result list.
- Once an empty/failed result arrives the spinner is replaced by the appropriate empty message.

**Edge cases & negative scenarios.**
- Typing additional characters while a search is in flight shows the spinner again for the new query.
- The spinner never persists indefinitely; it always resolves to results or an empty-state message.

#### CE-SYM-005 — No matches

**Description.** When a valid search returns nothing, the trader is clearly told there are no matches, and a failed request is handled the same friendly way rather than showing an error.

**Business rule.**
- A search of two or more characters returning no results shows "No matches".
- If the underlying request fails, the result is treated as empty — the dropdown shows "No matches" (not an error), and the field stays usable.

**Acceptance criteria.**
- A valid query with no matches shows "No matches".
- A search that fails behind the scenes shows the same "No matches" rather than a crash or error banner.
- The field remains usable after a no-match or failed search; the trader can edit and search again.

**Edge cases & negative scenarios.**
- A network/server failure does not surface a raw error in this field; it shows "No matches".
- After "No matches", refining the query and matching shows results normally.

#### CE-SYM-006 — Selecting a symbol loads it into the active pane

**Description.** Choosing a result loads that instrument into the active pane and tidies up the search UI.

**Business rule.**
- Tapping a result sets that symbol on the active pane, updates the field text, removes focus, and closes the dropdown.
- The active pane's chart then loads the selected symbol's data.
- Selecting a symbol also sets a sensible starting order quantity for that pane based on the instrument family and the trader's configured default quantities.

**Acceptance criteria.**
- Selecting a result changes the active pane's chart to that symbol.
- After selection, the field shows the chosen symbol's name and the dropdown closes.
- Other panes are unaffected.

**Edge cases & negative scenarios.**
- Selecting a result while the field is losing focus still registers the selection (the close is deferred briefly so the tap lands first).
- Selecting a derivative contract yields a lot-aware starting quantity rather than a quantity of one.

#### CE-SYM-007 — Dismiss via Esc / outside click

**Description.** The trader can dismiss the results dropdown without making a choice, by pressing Escape or clicking away.

**Business rule.**
- Clicking outside closes the dropdown shortly afterward.
- Pressing Escape dismisses the open dropdown.
- Dismissing without selecting leaves the active pane's symbol unchanged.

**Acceptance criteria.**
- Clicking outside the field closes the dropdown.
- Pressing Escape closes the dropdown.
- After dismissing without a selection, the chart still shows the previously loaded symbol.

**Edge cases & negative scenarios.**
- The close is deferred just long enough that a click on a result still selects it.
- Dismissing an empty/typing-state dropdown simply closes it with no side effects.

#### CE-SYM-008 — Long lists scroll without overflow

**Description.** When a search returns many matches, the dropdown scrolls within a bounded area instead of overflowing the page.

**Business rule.**
- The results dropdown has a maximum height; longer lists scroll inside that area.
- The dropdown is anchored to the search field and renders above the chart so its contents stay clickable.

**Acceptance criteria.**
- A search returning many results shows a scrollable list bounded to the dropdown's height.
- Scrolling reveals further results without the dropdown growing past its bounds.
- Every visible row remains clickable, including those over the chart area.

**Edge cases & negative scenarios.**
- A very long list does not push other page elements or extend off-screen.
- A short list shows without an unnecessary scrollbar.

---

## 4. Timeframe

#### CE-TF-001 — Preset timeframes

**Description.** A timeframe dropdown lets the trader switch the active pane's candle interval among common presets, with the currently selected one clearly marked.

**Business rule.**
- The preset timeframes offered, in order, are: 1m, 2m, 3m, 5m, 10m, 15m, 30m, 1h, 2h, 4h, 1D, 1W, 1M.
- These map to minutes: 1, 2, 3, 5, 10, 15, 30, 60, 120, 240, 1440, 10080, 43200.
- The active timeframe is marked with a tick. A "Custom…" entry sits below the presets, separated by a divider. The trigger button shows the active timeframe's label.

**Acceptance criteria.**
- Opening the dropdown lists all 13 presets in order, with "Custom…" beneath a divider.
- The active timeframe row shows a tick; only one row is ticked at a time.
- The trigger button text matches the active pane's timeframe.

**Edge cases & negative scenarios.**
- When the active timeframe is a custom value, no preset row is ticked, and the trigger shows the custom label (see CE-TF-005).
- Clicking the trigger while the dropdown is open closes it instead of duplicating it.

#### CE-TF-002 — Applying a timeframe

**Description.** Choosing a timeframe immediately re-draws the active pane's chart at the new interval.

**Business rule.**
- Selecting a preset applies that timeframe to the active pane and closes the dropdown.
- Applying a timeframe affects only the active pane; the chart reloads its candle history for the new interval.

**Acceptance criteria.**
- Selecting a preset re-draws the active pane at that interval and closes the dropdown.
- The trigger button updates to the chosen timeframe.
- Other panes' timeframes are unchanged.

**Edge cases & negative scenarios.**
- Selecting the already-active timeframe causes no disruptive reload beyond what is expected.
- Rapidly switching timeframes ends on the last one chosen, with the chart consistent with that choice.

#### CE-TF-003 — Custom timeframe dialog

**Description.** Beyond the presets, the trader can enter any custom interval in minutes (for example 7-minute or 90-minute candles).

**Business rule.**
- Choosing "Custom…" closes the dropdown and opens a small "Custom timeframe" dialog.
- The dialog has a number input with the hint "Minutes (e.g. 7 for 7m, 90 for 90m)", a Cancel button, and an Apply button. The input is focused automatically.

**Acceptance criteria.**
- Choosing "Custom…" opens a dialog titled "Custom timeframe" with a minutes input, Cancel, and Apply.
- The input is ready for typing (focused) when the dialog opens.
- The input hint reads "Minutes (e.g. 7 for 7m, 90 for 90m)".

**Edge cases & negative scenarios.**
- Opening the custom dialog first closes the preset dropdown so the two do not overlap.

#### CE-TF-004 — Custom validation

**Description.** The custom dialog only accepts a positive whole number of minutes, and cancelling makes no change.

**Business rule.**
- Apply accepts the value only when it parses to a whole number greater than zero.
- If the entry is empty, zero, negative, or not a whole number, Apply does nothing.
- Cancel closes the dialog and makes no change.

**Acceptance criteria.**
- Entering a positive whole number and pressing Apply sets that timeframe and closes the dialog.
- Pressing Apply with an empty input, 0, a negative number, or a non-numeric entry does not change the timeframe.
- Pressing Cancel leaves the active pane's timeframe exactly as it was.

**Edge cases & negative scenarios.**
- A value with surrounding spaces is trimmed before validation.
- A decimal or non-integer entry is rejected rather than rounded silently.
- Dismissing the dialog without applying makes no change.

#### CE-TF-005 — Custom label formatting

**Description.** A custom interval is shown using a tidy human label so the trader can read it at a glance.

**Business rule.**
- If the minute value matches a preset, that preset's label is shown.
- Otherwise: an exact multiple of 1440 minutes shows as days with a "D" suffix (1440 → "1D"); an exact multiple of 60 (but not 1440) shows as hours with an "h" suffix (120 → "2h"); any other value shows as minutes with an "m" suffix (7 → "7m").

**Acceptance criteria.**
- Entering 7 shows "7m"; entering 120 shows "2h"; entering 1440 shows "1D".
- A custom value equal to a preset (e.g. 60) shows the preset label ("1h").

**Edge cases & negative scenarios.**
- A large multiple of a day (e.g. 2880) shows as "2D".
- A value like 90 shows as "90m".

#### CE-TF-006 — Per-pane timeframe independence

**Description.** Timeframe is a per-pane setting, so the trader can watch the same or different symbols at different intervals across panes.

**Business rule.**
- Each pane stores and displays its own timeframe.
- Changing the timeframe affects only the active pane; the trigger always reflects the active pane's timeframe.

**Acceptance criteria.**
- Two panes can show different timeframes at the same time.
- Switching the active pane updates the timeframe control to that pane's timeframe.
- Changing the active pane's timeframe leaves all other panes' timeframes unchanged.

**Edge cases & negative scenarios.**
- Newly added panes inherit the active pane's timeframe at the moment of expansion, then become independent.
- Each pane's timeframe (including custom values) is remembered across sessions.

---

## 5. Chart Type & Appearance

#### CE-TYPE-001 — Six chart styles

**Description.** The trader can render the price series in one of six visual styles from a dedicated chart-type button on the chart toolbar. Each pane remembers its own style.

**Business rule.** The six styles, in order, are: Candle (the default), Hollow Candle, OHLC Bars, Line, Area, and Heikin Ashi. Exactly one style is active per pane at a time. The active style shows a tick and is highlighted (its row label and icon use the accent colour, label in semi-bold). The toolbar button shows the icon of the currently active style next to a small down-arrow, with the tooltip "Chart type". Selecting a style applies it immediately and closes the dropdown. The same six styles also appear inside Settings (see CE-TYPE-004).

**Acceptance criteria.**
- On a brand-new chart with no saved preference, the style is Candle and the toolbar button shows the candle icon.
- Opening the chart-type dropdown lists all six styles with their labels and icons; the active one has a tick and accent-coloured text.
- Picking any style updates the price drawing on screen and the toolbar button's icon changes to match.
- The chosen style persists for that pane after closing/reopening the dropdown and after reloading.
- Hovering a row highlights it; clicking outside closes the dropdown without changing the style.

**Edge cases & negative scenarios.**
- A previously saved style that is no longer offered falls back to Candle rather than showing a broken style.
- With multiple panes, switching style in one pane must not change another pane's style.
- Rapidly clicking through styles leaves the chart on the last-clicked style with no leftover hover trail.

#### CE-TYPE-002 — Switching style re-renders with overlays intact

**Description.** Changing the chart style must redraw the price series while keeping all other on-chart content visible.

**Business rule.** When the style changes, indicators, drawings, view-on-chart overlays, and the volume sub-pane must continue to render against the newly styled series. No overlay or indicator is cleared as a side effect of a style change.

**Acceptance criteria.**
- With one or more indicators added, switching style keeps every indicator visible and correctly positioned.
- With the volume sub-pane on, switching style keeps the volume bars visible below the chart.
- With drawings and view overlays (e.g. High/Low markers, key levels) present, they remain on screen after the style change.
- The price series visibly changes shape to match the chosen style (e.g. bars to a single line for Line/Area, smoothed bars for Heikin Ashi).

**Edge cases & negative scenarios.**
- Switching to Line or Area (which have no separate up/down candle bodies) must not remove indicators or volume.
- Switching style while a drawing is mid-creation must not corrupt or drop existing completed drawings.

#### CE-TYPE-003 — Cursor mode toggle (Crosshair vs Cursor)

**Description.** A toolbar control lets the trader choose between a full crosshair (lines spanning the whole chart) and a plain pointer, per pane.

**Business rule.** The control offers two options: "Crosshair" (full spanning lines, the default) and "Cursor" (plain pointer, no spanning lines). The active option shows a tick and accent colour. The toolbar button's icon reflects the current mode (a crosshair icon when Crosshair is active, a mouse-pointer icon when Cursor is active) with the tooltip "Cursor mode". Regardless of mode, the price chip (price axis) and time chip (time axis) must still appear as the cursor moves. This setting is per pane and persists.

**Acceptance criteria.**
- Default state is Crosshair: moving the cursor shows full-width and full-height reference lines plus price and time chips.
- Selecting Cursor removes the spanning lines but still shows the price chip and time chip at the cursor position.
- The toolbar button icon and the checked row update to match the chosen mode and the choice persists across reloads.
- Selecting an option closes the dropdown.

**Edge cases & negative scenarios.**
- In Cursor mode the price/time chips must never disappear; only the spanning lines are hidden.
- Each pane keeps its own cursor mode; changing one pane must not change another.

#### CE-TYPE-004 — Settings → Chart type tab (duplicate card grid)

**Description.** Inside the Settings popover, a "Chart type" tab presents the same six styles as a two-column card grid, as an alternative entry point to the toolbar button.

**Business rule.** The Settings popover is titled "Settings" with subtitle "Chart appearance and on-chart overlays" and has three tabs: "Chart type", "Customize", "View on chart". The Chart type tab shows the six styles as selectable cards in a two-column grid, each with an icon and label. The active card is highlighted with an accent border, tinted background, and semi-bold label. Selecting a card applies that style to the active pane. The grid and the toolbar chart-type button always reflect the same single active style.

**Acceptance criteria.**
- Opening Settings and choosing the Chart type tab shows all six style cards in a 2-column grid; the current style's card is visibly selected.
- Tapping a card immediately changes the chart style and the selection highlight moves to that card.
- Changing the style via the toolbar button is reflected in the Settings grid when reopened, and vice versa.
- Hovering an unselected card gives a subtle highlight.

**Edge cases & negative scenarios.**
- If there is no valid active pane, the Chart type tab shows nothing rather than erroring.
- The Settings grid and the toolbar dropdown must never show two different "active" styles at once.

#### CE-TYPE-005 — Customize colours

**Description.** The Settings → Customize tab lets the trader recolour candle elements and canvas elements using a fixed palette of preset swatches.

**Business rule.** Two groups exist. "Candle colors": Body — Up, Body — Down, Wick — Up, Wick — Down. "Canvas": Background, Text, Grid, Session break, Crosshair. Each row has a label and a colour-swatch button; tapping the button (or the row) expands an inline palette of exactly 10 preset swatches: green, darker green, red, darker red, blue, sky blue, purple, amber, slate grey, and white. Picking a swatch applies that colour and collapses the palette. At most one row's palette is open at a time. Candle defaults: Body-Up green, Body-Down red, Wick-Up darker green, Wick-Down darker red. Canvas fields default to "follow theme" rather than a fixed colour.

**Acceptance criteria.**
- The Customize tab shows "Candle colors" (4 rows) and "Canvas" (5 rows) with the correct labels.
- Expanding any row shows exactly 10 colour swatches; the currently applied colour is ring-highlighted.
- Picking a swatch updates the chart colour live and closes the inline palette.
- Opening a second row's palette closes the first; only one palette is open at any time.
- Each candle-colour swatch shows its current colour; canvas fields set to "follow theme" show a neutral placeholder tile instead of a solid colour.

**Edge cases & negative scenarios.**
- Selecting white for a colour on a light background still applies (no silent rejection), even if visually faint.
- Choosing a colour that equals the current colour is a no-op (no flicker; palette still closes).
- Colour changes must apply to the live chart, not only the preview swatch.

#### CE-TYPE-006 — Theme default chip

**Description.** For canvas colour fields, a "Theme" chip lets the trader reset that single field back to the app's theme colour.

**Business rule.** Only the canvas fields (Background, Text, Grid, Session break, Crosshair) support following the theme. When such a field has no explicit colour, a small grey "Theme" chip appears next to its swatch and the swatch shows the neutral placeholder. Tapping the chip clears the field back to the theme colour. The chip is also offered alongside the swatches when that field's palette is expanded. Candle-colour fields do not offer a Theme chip.

**Acceptance criteria.**
- A canvas field following the theme shows the "Theme" chip and a placeholder swatch tile.
- After picking an explicit colour for a canvas field, tapping the "Theme" chip returns it to the theme default and restores the placeholder.
- The four candle-colour rows never show a "Theme" chip.

**Edge cases & negative scenarios.**
- Resetting a canvas field to theme visibly changes the chart back to the theme colour, not leaving the previous custom colour.
- Toggling app light/dark theme makes theme-following canvas fields adopt the new theme colour automatically.

#### CE-TYPE-007 — Reset to defaults

**Description.** A "Reset to defaults" action in the Customize tab restores all candle and canvas colours to their defaults, but only when something has been customized.

**Business rule.** The control is labelled "Reset to defaults" with a refresh icon, in the loss/red colour. It is enabled only when the current palette differs from defaults; when the palette already equals defaults it is disabled. Activating it restores all candle colours to default and all canvas fields to "follow theme", and collapses any open palette.

**Acceptance criteria.**
- On an unmodified palette, "Reset to defaults" is visibly disabled and does nothing.
- After changing any colour, the button becomes enabled.
- Activating it returns every candle colour to default and every canvas field to theme-following, with the chart updating live.
- Any open inline palette closes after the reset.

**Edge cases & negative scenarios.**
- If only one field was changed, reset still returns every field to default.
- After a reset, the button returns to its disabled state.

#### CE-TYPE-008 — Snap / screenshot

**Description.** A "Snap" toolbar action captures the current chart as an image and downloads it.

**Business rule.** The control is labelled "Snap" with a camera icon and captures the active pane. The browser downloads the image as a PNG named "chart.png" by default (a server/engine-supplied filename is used only if provided).

**Acceptance criteria.**
- Activating Snap produces a downloaded image of the current chart.
- The default filename is chart.png.
- The captured image reflects the chart as currently shown (active style, indicators, overlays, colours).

**Edge cases & negative scenarios.**
- If the capture returns no image data, no empty/broken file is downloaded.
- Triggering Snap multiple times produces multiple downloads without errors.
- Snap captures the active pane only, not other panes.

---

## 6. View-on-Chart Overlays

All toggles in this section live in the Settings → "View on chart" tab and are remembered per pane, except the Drawings and Keyboard-shortcuts toggles, which are chart-wide (see CE-VIEW-010 and CE-VIEW-011). Each toggle row shows a label, a short description, and a switch; tapping the switch or the row toggles it.

#### CE-VIEW-001 — Gridlines

**Description.** Toggles the background reference grid on the chart.

**Business rule.** Label "Gridlines", description "Background reference grid". Default ON. Per pane.

**Acceptance criteria.**
- By default the grid is visible and the switch is ON.
- Turning it off removes the background grid; turning it back on restores it.
- The state is remembered for that pane after closing the popover and reloading.

**Edge cases & negative scenarios.**
- Turning the grid off must not hide price/time axes or any indicators.
- Each pane keeps its own gridlines state.

#### CE-VIEW-002 — Volume sub-pane

**Description.** Toggles the volume bars shown below the main chart.

**Business rule.** Label "Volume sub-pane", description "Below-chart volume bars". Default ON. Per pane.

**Acceptance criteria.**
- By default the volume sub-pane shows below the chart and the switch is ON.
- Turning it off removes the volume bars; turning it on restores them.
- State persists per pane.

**Edge cases & negative scenarios.**
- This below-chart volume sub-pane is distinct from the right-gutter Volume profile (CE-VIEW-009); toggling one must not toggle the other.
- For instruments without volume data, the sub-pane should not show misleading bars (empty/blank is acceptable).

#### CE-VIEW-003 — High / Low markers

**Description.** Marks the highest and lowest prices in the visible range.

**Business rule.** Label "High / Low markers", description "Visible-range price extremes". Default ON. Per pane.

**Acceptance criteria.**
- By default the visible-range high and low are marked and the switch is ON.
- Panning/zooming updates which bars are marked as the visible extremes.
- Turning it off removes the markers; state persists per pane.

**Edge cases & negative scenarios.**
- When the visible range changes, the high/low markers move to the new extremes, not stay pinned to old bars.
- Turning the markers off must not affect any other overlay.

#### CE-VIEW-004 — Bar countdown

**Description.** Shows a countdown to when the current (forming) bar will close.

**Business rule.** Label "Bar countdown", description "Time until current bar closes". Default ON. Per pane.

**Acceptance criteria.**
- By default a countdown is shown for the current bar and the switch is ON.
- The countdown decreases over time and resets when a new bar starts.
- Turning it off hides the countdown; state persists per pane.

**Edge cases & negative scenarios.**
- Changing the timeframe resets the countdown to the new bar interval.
- The countdown reflects the active pane's timeframe, not a different pane's.

#### CE-VIEW-005 — Option-chain OI bars

**Description.** Overlays open-interest bars at option strikes for supported index symbols, fetched only while the toggle is on and refreshed periodically.

**Business rule.** Label "Option-chain OI", description "Open-interest bars at strikes". Default OFF. Per pane. Data is fetched only while the toggle is ON; it auto-refreshes roughly every 120 seconds. Cached OI data is cleared when the toggle is turned off, when the pane's symbol changes, or when the pane is removed. The overlay is only meaningful on a supported index symbol.

**Acceptance criteria.**
- By default the switch is OFF, no OI bars are shown, and no OI fetch occurs.
- Turning it on for a supported index fetches OI and draws bars at strikes; the data refreshes about every 120 seconds while on.
- Turning it off clears the OI bars and stops fetching.
- Changing the pane's symbol clears the previously fetched OI; removing the pane clears its cached OI.

**Edge cases & negative scenarios.**
- On a symbol that is not a supported index, enabling the toggle shows no OI bars (no stale data from a previous symbol).
- If the OI fetch returns empty or fails, the chart shows no partial/garbage bars; the rest of the chart stays usable.
- Switching from a supported index (with OI on) to a non-index symbol removes the bars rather than keeping stale strikes.

#### CE-VIEW-006 — Key levels / pivots

**Description.** Draws pivot levels (PP and R1–R3, S1–S3) computed from the previous session, with a selectable calculation variant.

**Business rule.** Label "Key levels (pivots)", description "PP, R1–R3, S1–S3 from prev session". Default OFF. Per pane. A "Pivot variant" selector with three options — "Classical" (default), "Fibonacci", "Camarilla" — is always shown beneath the toggle, dimmed while Key levels is OFF and fully active when ON. The selected variant persists per pane.

**Acceptance criteria.**
- By default the switch is OFF, no pivot lines are drawn, and the variant selector is shown but dimmed.
- Turning Key levels on draws PP plus R1–R3 and S1–S3 and makes the variant selector fully active.
- Switching the variant (Classical / Fibonacci / Camarilla) recomputes and redraws the levels; the default variant is Classical.
- Toggle state and selected variant persist per pane.

**Edge cases & negative scenarios.**
- The variant selector remains visible (just dimmed) when the toggle is off; it must not vanish.
- A saved unknown/invalid variant falls back to Classical.
- Levels are based on the previous session's data, not the current forming bar.

#### CE-VIEW-007 — Auto-pattern HH/HL/LH/LL

**Description.** Automatically labels swing structure points as Higher High, Higher Low, Lower High, Lower Low.

**Business rule.** Label "Auto-pattern", description "HH / HL / LH / LL labels". Default OFF. Per pane.

**Acceptance criteria.**
- By default the switch is OFF and no swing labels are shown.
- Turning it on places HH/HL/LH/LL labels at the appropriate swing points; turning it off removes them.
- State persists per pane.

**Edge cases & negative scenarios.**
- Labels update as new bars form rather than remaining stale.
- Enabling auto-pattern must not interfere with manually drawn objects.

#### CE-VIEW-008 — Magnet snap to OHLC while drawing

**Description.** While drawing, the cursor snaps to the nearest candle Open/High/Low/Close near it.

**Business rule.** Label "Magnet", description "While drawing, snap to the nearest candle Open / High / Low / Close within 8 px of the cursor". Default OFF. Per pane. Snapping applies only during drawing and only within an 8-pixel radius of the cursor.

**Acceptance criteria.**
- By default the switch is OFF and drawing follows the free cursor position.
- Turning it on makes a drawing endpoint snap to the nearest O/H/L/C when the cursor is within roughly 8 pixels of one.
- State persists per pane.

**Edge cases & negative scenarios.**
- When the cursor is farther than ~8 px from any candle point, no snapping occurs.
- Magnet affects only drawing placement, not crosshair movement or normal chart interaction.

#### CE-VIEW-009 — Volume profile (right gutter)

**Description.** Shows a horizontal volume histogram in the chart's right gutter.

**Business rule.** Label "Volume profile", description "Right-gutter horizontal histogram". Default OFF. Per pane. Separate from the below-chart Volume sub-pane (CE-VIEW-002).

**Acceptance criteria.**
- By default the switch is OFF and no right-gutter histogram is shown.
- Turning it on draws a horizontal volume histogram on the right; turning it off removes it.
- State persists per pane.

**Edge cases & negative scenarios.**
- Toggling Volume profile must not toggle the below-chart Volume sub-pane, and vice versa.
- For instruments without volume data the histogram is empty/absent rather than misleading.

#### CE-VIEW-010 — Drawings visibility master toggle

**Description.** A single toggle shows or hides all drawing objects on the chart at once.

**Business rule.** Label "Drawings", description "Show all drawing objects". Chart-wide (not per-pane). The switch reads ON when drawings are visible. Turning it off hides all drawings; turning it on shows them again. The same show/hide is also reachable from the Draw tool's bottom toolbar.

**Acceptance criteria.**
- With drawings present, the switch shows ON and the drawings are visible.
- Turning it off hides all drawing objects without deleting them; turning it on restores them.
- Hiding/showing via the Draw toolbar reflects the same state as this Settings switch.

**Edge cases & negative scenarios.**
- Hiding drawings must not delete them; turning the toggle back on restores the same objects.
- This master toggle is global and affects drawings consistently, not limited to a single pane.

#### CE-VIEW-011 — Keyboard shortcuts toggle

**Description.** Enables or disables chart keyboard shortcuts, with an info icon that lists the available keys.

**Business rule.** Label "Keyboard shortcuts", description "Alt+B/S, 1/5/H/D and more". Chart-wide, default OFF. An info icon shows a tooltip listing the shortcuts: Alt + B = Buy limit at hovered price; Alt + S = Sell limit at hovered price; Alt + I = toggle Instant orders; 1 / 5 / Shift+1 / H / D = timeframe to 1m / 5m / 15m / 1h / 1d; Esc = cancel draw / drag / popup.

**Acceptance criteria.**
- The switch reflects whether keyboard shortcuts are enabled; by default it is OFF.
- Hovering the info icon shows the tooltip listing the shortcuts.
- With shortcuts ON, the listed keys perform their actions; with shortcuts OFF, these keys have no chart effect.

**Edge cases & negative scenarios.**
- With the toggle OFF, pressing the listed keys must not trigger orders or timeframe changes.
- Alt+B / Alt+S require a hovered price; with no hover target the action does not place a stray order.
- The shortcut toggle is global; enabling it applies across panes.

---

## 7. Technical Indicators

#### CE-IND-001 — Indicators (fx) picker — searchable, category-grouped

**Description.** A trader opens an "fx / Indicators" picker from the chart's top bar to browse and add technical studies, finding a study by typing its name, with studies shown under category headings.

**Business rule.** The picker presents every supported indicator grouped by category (Moving averages & overlays, Oscillators, Volume & volatility, and the ICT/SMC pack). Each entry shows a display name and a one-line description. A search box filters the list live by display name; clearing the search restores the full grouped list. The picker targets whichever pane is currently active.

**Acceptance criteria.**
- Opening the picker shows all indicators grouped under category headings, each with a name and short caption.
- Typing in the search box narrows the visible entries to those whose names match; removing the text restores the full list.
- An empty search result shows nothing addable rather than an error.
- The indicator added lands on the currently active pane.
- The picker can be dismissed without adding anything and leaves the chart unchanged.

**Edge cases & negative scenarios.**
- Searching with mixed upper/lower case still matches (case-insensitive).
- With several panes open, switching the active pane and then opening the picker targets the newly active pane.
- Re-opening the picker after adding a study still lists that study (studies can be added more than once).

#### CE-IND-002 — Add indicator (defaults applied; picker closes)

**Description.** When a trader selects an indicator, it is added to the active pane immediately using sensible default settings, and the picker closes.

**Business rule.** On selection the indicator is created with its schema default parameters, a default colour per indicator kind, and default line thickness of 1. Single-period kinds receive their default period (e.g. RSI 14, ATR 14, SMA/EMA 20); kinds with no scalar lookback (VWAP, On-Balance Volume, Awesome Oscillator, MA Ribbon) are added with no period. Each added instance gets its own identity, so the same indicator can be added multiple times with different settings. The new indicator draws on the next render and persists.

**Acceptance criteria.**
- Selecting an indicator closes the picker and draws the study on the active pane right away.
- The study appears with its default parameters, default colour, and thickness 1.
- Adding the same indicator twice produces two independent instances configured separately.
- A chip/label for the new indicator appears in the chart's indicator strip.

**Edge cases & negative scenarios.**
- Adding a no-period indicator (VWAP, OBV, AO, Ribbon) must not show or require a period value.
- Adding a multi-parameter indicator applies all of its default parameters, not just one.
- Adding many indicators to one pane keeps each one independent.

#### CE-IND-003 — Edit indicator (period/parameters, colour, thickness, visibility)

**Description.** A trader can open an existing indicator's settings to change its calculation parameters, line colour, line thickness, and whether it is shown.

**Business rule.** The settings dialog is schema-driven: it renders exactly the numeric parameter rows defined for that indicator kind, each with a label, a one-line description, and a stepper bounded by that parameter's minimum, maximum, and step. Integer parameters step by whole numbers; fractional parameters (e.g. Bollinger multiplier, ATR multiplier, body-ratio thresholds) step in decimals. Colour is a free choice; thickness is 1, 2, or 3 (applied to all lines a multi-line study draws). Edits take effect on the next render and are saved.

**Acceptance criteria.**
- Opening an indicator's settings shows one row per parameter, each with its label, caption, current value, and min/max-bounded stepper.
- Changing a parameter, colour, or thickness redraws the indicator without removing it.
- A multi-line study applies the chosen thickness to all of its lines.
- Edited values survive closing and reopening the settings dialog.

**Edge cases & negative scenarios.**
- A stepper will not go below its minimum or above its maximum; values clamp at the bounds.
- Fractional parameters step by their defined decimal step (not by 1).
- An indicator kind with no schema entry falls back to a single generic "Period" row.
- Editing one instance of a duplicated indicator does not change the other.

#### CE-IND-004 — Remove indicator

**Description.** A trader can permanently remove an indicator from a pane.

**Business rule.** Removing an indicator deletes that instance from the active pane's list. It stops rendering, its chip disappears, and a sub-pane oscillator's sub-pane is reclaimed. The removal is saved.

**Acceptance criteria.**
- Removing an indicator clears it from the chart and the indicator strip immediately.
- Removing a sub-pane oscillator returns the freed space to the candle area.
- Removing one instance leaves any other instances untouched.
- After removal, the indicator no longer reappears on reload.

**Edge cases & negative scenarios.**
- Removing the only indicator leaves a clean chart (no empty sub-pane residue).
- Removing a currently hidden indicator still fully deletes it.

#### CE-IND-005 — Hide vs remove (visibility toggle keeps settings)

**Description.** A trader can temporarily hide an indicator without losing its configured parameters, colour, or thickness, and later re-show it exactly as it was.

**Business rule.** Hiding sets visibility off: the indicator is skipped during drawing but stays in the list with all its settings. Hidden sub-pane oscillators release their sub-pane while hidden. Re-showing restores the study with its previous settings. The hidden state is saved. This is distinct from removal.

**Acceptance criteria.**
- Toggling visibility off stops the indicator drawing but keeps its chip present (hidden/dimmed).
- Toggling visibility back on redraws the indicator with the same settings.
- Hiding a sub-pane oscillator frees its sub-pane; un-hiding restores it.
- Hidden state persists across reload.

**Edge cases & negative scenarios.**
- Editing a hidden indicator's settings is preserved and visible once it is un-hidden.
- Hiding every indicator leaves only candles; un-hiding restores all of them.

#### CE-IND-006 — Sub-pane vs price-pane rendering

**Description.** Overlay studies draw over the price candles; oscillators draw in their own stacked panel below the candles. Each type must render in the correct place.

**Business rule.** Overlay studies render on the price pane sharing the candle price scale: SMA, EMA, ZLEMA, McGinley, VWAP, MA Ribbon, Bollinger Bands, Ichimoku Cloud, Volatility Stop, and the entire ICT/SMC pack. Oscillators render each in their own sub-pane below the candles: RSI, MACD, Stochastic, Stochastic RSI, Squeeze Momentum, Elder Force Index, WaveTrend, Connors RSI, Awesome Oscillator, Money Flow Index, On-Balance Volume, Chaikin Money Flow, Williams %R. Multiple oscillators stack. Bounded oscillators show fixed reference levels (e.g. RSI 30/70).

**Acceptance criteria.**
- Adding an overlay study draws it on top of the candles using the same price axis.
- Adding an oscillator creates a dedicated sub-pane beneath the candles; the candle area shrinks.
- Adding several oscillators stacks them as separate sub-panes.
- Removing/hiding all oscillators returns the full height to the candle area.

**Edge cases & negative scenarios.**
- Mixing overlays and oscillators renders each in its correct region simultaneously.
- A bounded oscillator shows its standard reference levels; an unbounded one auto-scales.

#### CE-IND-007 — Persistence across session reload

**Description.** A trader's indicators and their settings survive a page reload or returning later.

**Business rule.** Each pane's indicator list — kind, parameters, colour, thickness, hidden state — is saved and restored. Legacy saved indicators that predate the parameter schema still load: their stored period maps onto the schema's designated legacy key (e.g. Bollinger length, Stochastic %K length); where there is no legacy mapping, schema defaults apply. A corrupted saved session falls back to a clean default chart.

**Acceptance criteria.**
- Indicators added/edited/hidden before reload reappear with identical settings and placement.
- A hidden indicator is restored hidden; a visible one visible.
- Sub-pane oscillators reappear in sub-panes; overlays on the price pane.
- An older saved indicator that used a single period still loads with that period on the correct parameter.

**Edge cases & negative scenarios.**
- A corrupted/invalid saved session loads the default empty chart without crashing.
- An unknown saved indicator kind falls back to the generic single-period treatment.
- Restored parameter values outside current bounds are clamped into range.

#### CE-IND-008 — Indicator catalogue coverage

**Description.** Enumerates every indicator a tester must be able to add, configure, hide, and remove across the full lifecycle, confirming it renders in the correct region and exposes all of its parameters.

**Business rule.** The following must all be available and fully configurable:
- Moving averages & overlays (price pane): Simple Moving Average (period 20, 1–999); Exponential Moving Average (period 20); Zero-Lag EMA (period 20); McGinley Dynamic (period 14); VWAP (no parameters — colour/thickness only); MA Ribbon of 8 EMAs at fixed lengths 5/10/20/30/40/50/60/80 (no parameters); Bollinger Bands (Length 20, 2–200; Std-dev multiplier 2.0, 0.5–5.0 in 0.1 steps); Ichimoku Cloud (Tenkan 9; Kijun 26; Senkou B 52; Displacement 26); Volatility Stop (ATR length 14; ATR multiplier 2.0, 0.5–10 in 0.1 steps).
- Oscillators (sub-pane): RSI (period 14, 2–200); Stochastic (%K Length 14; %D Length 3; Smoothing 3); Stochastic RSI (RSI Length 14; Stoch Length 14; %K Smoothing 3; %D Smoothing 3); MACD (Fast 12; Slow 26; Signal 9); Awesome Oscillator (no parameters); Williams %R (period 14); Connors RSI (RSI Length 3; Streak Length 2; ROC Window 100); WaveTrend (Channel Length 10; Average Length 21); Squeeze Momentum (BB Length 20; BB Multiplier 2.0; KC Length 20; KC Multiplier 1.5).
- Volume & volatility: ATR (period 14, sub-pane); Money Flow Index (period 14, sub-pane); Chaikin Money Flow (period 20, sub-pane); On-Balance Volume (no parameters, sub-pane); Elder's Force Index (period 13, sub-pane).

**Acceptance criteria.**
- Every indicator above can be added from the picker, appears in its correct region, and can be hidden, edited, and removed.
- Every multi-parameter indicator exposes all of its parameters as separate editable rows (Bollinger length + multiplier; MACD fast/slow/signal; Stochastic %K/%D/smoothing; Ichimoku Tenkan/Kijun/Senkou B/displacement; Squeeze's four BB/KC parameters; Connors RSI's three legs; Stochastic RSI's four).
- No-parameter indicators (VWAP, MA Ribbon, Awesome Oscillator, On-Balance Volume) expose only colour and thickness.
- After a reload, every indicator type restores correctly with its configured parameters.

**Edge cases & negative scenarios.**
- Driving each parameter to its minimum and maximum is accepted and clamped at the bounds.
- Fractional parameters step in decimals; integer parameters step by 1.
- The MA Ribbon always uses its fixed eight lengths regardless of any period field.

---

## 8. ICT / SMC Indicator Pack

All ICT/SMC studies render on the price pane (over the candles), each with its own settings dialog and its own visibility/colour/thickness controls. Each follows the standard add → edit → hide → remove → reload lifecycle and obeys its own "maximum visible" pruning and lifetime/extend rules.

#### CE-ICT-001 — CISD (Change in State of Delivery)

**Description.** Change in State of Delivery marks where price closes (by candle body) back through the open of the opposing leg that produced the prior move — to an ICT/SMC trader, an early signal that order delivery has flipped direction. It can flag only high-quality shifts with markers or mark every shift with a line.

**Business rule.** Parameters: Strict mode (1 = strict, default; 0 = permissive); Pivot width (bars each side of a swing pivot, default 2, range 1–10, strict only); Min body ratio (displacement filter, default 0.65, range 0.10–0.95 in 0.05 steps); Level lifetime (bars a line lives before auto-expiring, default 50, range 5–500); Max visible lines (default 10, range 1–50). In strict mode the study requires a confirmed swing pivot and a body-ratio clearing Min body ratio, drawing a filled triangle marker (bullish ▲ below the low, bearish ▼ above the high) plus the break line. In permissive mode it draws a line at every state change. Each line is drawn from its trigger forward until an opposite-direction close past the level or until Level-lifetime expiry. When more lines exist than Max visible lines, the oldest are pruned.

**Acceptance criteria.**
- Adding CISD with Strict mode on shows ▲/▼ markers at qualifying candles plus break lines.
- Switching Strict mode off draws a line at every crossing with no markers and no filtering.
- Reducing Level lifetime causes lines to disappear sooner.
- Lowering Max visible lines keeps only the most recent lines.
- It renders on the price pane and can be hidden, recoloured, re-thicknessed, and removed.

**Edge cases & negative scenarios.**
- Min body ratio at its maximum (0.95) yields very few/no strict signals; at its minimum (0.10) yields many.
- Pivot width has no effect in permissive mode.
- Max visible lines at 1 shows only the single most recent line.

#### CE-ICT-002 — FVG (Fair Value Gap)

**Description.** A Fair Value Gap is a three-candle imbalance where the middle candle's strong move leaves a price gap the outer candles' wicks do not cover — traders watch these zones as likely areas price returns to "fill." The zone fades once price trades back into it (mitigation).

**Business rule.** Parameters: Strict mode (1 = require the middle candle's body ÷ range to clear Min body ratio; 0 = show every gap, default 0); Min body ratio (default 0.50, range 0.10–0.95 in 0.05 steps, strict only); Extend bars (bars an unmitigated gap extends forward, default 30, range 5–200); Max visible boxes (default 20, range 1–100); Show mitigated (1 = keep filled gaps as faded outlines, default; 0 = hide). Each gap is drawn as a translucent box from its origin forward to the candle that first mitigates it (any wick entering the gap range), or to the Extend-bars cap if never mitigated. Only the most recent Max-visible-boxes gaps are drawn.

**Acceptance criteria.**
- Adding FVG draws translucent boxes at three-candle imbalances on the price pane.
- A gap price re-enters becomes a faded outline rather than a solid box.
- With Show mitigated off, mitigated gaps disappear entirely.
- Turning Strict mode on reduces the gaps shown to those with a strong middle candle.
- Lowering Max visible boxes prunes to the most recent gaps; Extend bars controls how far an unmitigated gap stretches.

**Edge cases & negative scenarios.**
- Strict mode at high Min body ratio shows very few gaps.
- A gap mitigated on the next candle shows a very short faded box.
- Max visible boxes at 1 shows only the single most recent gap.

#### CE-ICT-003 — Order Block

**Description.** An Order Block is the last opposing-colour candle before a strong impulse move — traders treat it as an institutional footprint and likely support/resistance. The block fades once price trades back through it.

**Business rule.** Parameters: ATR Period (default 14, range 2–100); Impulse threshold (ATR multiple the impulse body must clear, default 1.5, range 0.5–5.0 in 0.1 steps); Body only (1 = box spans open/close body, default; 0 = full high/low range); Extend bars (default 100, range 5–500); Max visible boxes (default 10, range 1–50); Show mitigated (1 = faded outline; 0 = hide, default). Each block is drawn from its origin forward to the candle that first mitigates it, or to the Extend-bars cap. Mitigated blocks render with reduced fill. Only the most recent Max-visible-boxes blocks are drawn.

**Acceptance criteria.**
- Adding Order Block draws zone boxes at the last opposing candle before qualifying impulses.
- With Body only on, the box spans only the candle body; off, the full high–low range.
- Raising Impulse threshold (or ATR period) qualifies fewer, stronger blocks.
- A block price crosses back through fades; with Show mitigated off it is hidden.
- Lowering Max visible boxes prunes to the most recent blocks; Extend bars controls forward reach.

**Edge cases & negative scenarios.**
- Impulse threshold at its maximum (5.0) may yield no blocks on quiet data.
- Show mitigated defaults off here, so mitigated blocks vanish unless turned on.
- Max visible boxes at 1 shows only the single most recent block.

#### CE-ICT-004 — Liquidity Sweep

**Description.** A Liquidity Sweep is when a candle's wick pierces a prior swing high/low (running stops) but the body closes back inside the prior range — a stop-hunt rejection read as a reversal cue.

**Business rule.** Parameters: Pivot width (bars each side defining a fractal swing pivot, default 2, range 1–10); Show sweep line (1 = dashed line from the swept pivot to the sweep candle, default; 0 = no line); Max markers (default 20, range 1–100). At each qualifying sweep the study draws a triangle marker at the sweeping candle (a swept low pivot below the candle low; a swept high pivot above the high), plus the dashed line when enabled. Only the most recent Max-markers sweeps are rendered.

**Acceptance criteria.**
- Adding Liquidity Sweep draws triangle markers at candles that pierce a prior swing pivot but close back inside.
- With Show sweep line on, a dashed line connects the swept pivot to the sweep candle; off removes only the line.
- Changing Pivot width changes which swings qualify (wider = stricter).
- Lowering Max markers keeps only the most recent sweeps.

**Edge cases & negative scenarios.**
- Pivot width at its maximum (10) yields fewer pivots and sweeps.
- Max markers at 1 shows only the single most recent sweep.
- A wick that pierces but whose body also closes outside is not a sweep and shows no marker.

#### CE-ICT-005 — Market Structure (MSS / BOS / CHoCH)

**Description.** Market Structure labels structural breaks at swing pivots: a Break of Structure (BOS) is a continuation in the prevailing direction; a Change of Character (CHoCH) is the first break in the opposite direction; a Market Structure Shift (MSS) is a CHoCH that also arrives with a strong displacement candle.

**Business rule.** Parameters: Pivot width (default 2, range 1–10); MSS body ratio (displacement threshold to upgrade a CHoCH to an MSS, default 0.65, range 0.10–0.95 in 0.05 steps); Max labels (default 15, range 1–100); Show break line (1 = dashed level line from the broken pivot to the break candle, default; 0 = no line). A candle closing through a confirmed pivot in the same direction as the tracked trend is labelled BOS; an opposite-direction break is CHoCH, upgraded to MSS if its body ratio clears the threshold; either break flips the tracked trend; the very first break is treated as BOS. MSS labels also render a filled triangle marker. Only the most recent Max-labels events are shown.

**Acceptance criteria.**
- Adding Market Structure places BOS/CHoCH/MSS text labels at break candles.
- A continuation break reads BOS; the first opposite break reads CHoCH; a CHoCH with a strong displacement body reads MSS (with a triangle marker).
- With Show break line on, a dashed level line connects the broken pivot to the break candle; off removes only the line.
- Raising MSS body ratio causes fewer CHoCH events to upgrade to MSS.
- Lowering Max labels keeps only the most recent labels.

**Edge cases & negative scenarios.**
- MSS body ratio at its maximum (0.95) yields essentially no MSS upgrades.
- Pivot width changes which swings qualify, changing label count and timing.
- Max labels at 1 shows only the single most recent label.

#### CE-ICT-006 — "Maximum visible" pruning and lifetime/extend behaviour

**Description.** Across the whole ICT/SMC pack, the chart caps how many objects are drawn and how long/far each lives, so the chart stays readable. Testers verify the cap and lifetime/extend rules for each study.

**Business rule.** Every ICT study exposes a "maximum visible" cap (Max visible lines for CISD; Max visible boxes for FVG and Order Block; Max markers for Liquidity Sweep; Max labels for Market Structure). When more objects exist than the cap, only the most recent are kept. Time-bound studies expire/extend by their own parameters: CISD lines expire after Level lifetime bars (or an earlier opposite close); FVG and Order Block boxes extend forward by Extend bars unless mitigated earlier (then fade per Show mitigated). Lowering a cap reduces the on-chart count immediately; raising it reveals more (up to what the data produces).

**Acceptance criteria.**
- For each ICT study, setting its cap low shows only the most recent N objects; raising it shows more.
- CISD lines disappear after their Level-lifetime bars or sooner on an opposite close.
- FVG and Order Block boxes stop extending at their Extend-bars cap when never mitigated, and earlier (fading) when mitigated.
- Mitigated FVG/Order Block objects honour their Show mitigated toggle (faded vs hidden).

**Edge cases & negative scenarios.**
- Each cap at its minimum (1) shows exactly one object — the most recent.
- Each cap at its maximum draws no more objects than the data actually produces.
- Very small Extend bars / Level lifetime values make objects very short-lived; very large values keep them on screen far longer.

---

## 9. Drawing Tools

#### CE-DRAW-001 — Tool list

**Description.** The chart offers a set of manual drawing tools a trader can place on the price pane.

**Business rule.** The available tools are: Trendline (two points), Horizontal line (one price level across the whole chart), Horizontal ray (a level extending in one direction from a point), Rectangle (a box drawn by dragging between two corners), Fib retracement (fibonacci levels between two points), Path / multi-point (a connected multi-segment line), and Measure (a transient one-shot measurement between two points). Each placed drawing carries its own colour, thickness, and lock state.

**Acceptance criteria.**
- All seven tools are selectable from the drawing toolbar.
- Each tool, when used, produces its expected shape on the price pane.
- The Measure tool produces a one-shot, transient measurement rather than a permanent saved drawing.

**Edge cases & negative scenarios.**
- An unrecognised/invalid tool selection is ignored rather than activating a broken tool.
- Horizontal line ignores the time/position of the click and spans the full width at the chosen price.

#### CE-DRAW-002 — Activating a tool

**Description.** Selecting a drawing tool puts the chart into a drawing mode, clearly indicated, that the trader can cancel.

**Business rule.** Activating a tool highlights its toolbar button and shows a "Drawing: <tool>" indication. The chart stays in that drawing mode until the user finishes the drawing, presses Esc, or clicks the same tool again to toggle it off. Switching to a different tool clears any pending one-shot Measure. Draw-mode selection is UI-only and is not persisted across reload.

**Acceptance criteria.**
- Clicking a tool highlights it and shows the "Drawing: <tool>" state.
- Pressing Esc exits drawing mode and de-highlights the tool.
- Clicking the active tool again cancels drawing mode.
- Selecting a different tool switches drawing mode to that tool and clears any pending Measure.

**Edge cases & negative scenarios.**
- After reload, no tool is active even if one was active before.
- For tools that stay active after one shape (e.g. Rectangle), the user can draw consecutive shapes until they cancel.

#### CE-DRAW-003 — Creating a drawing

**Description.** A trader places a drawing by clicking/dragging on the chart according to the active tool.

**Business rule.** Single-anchor tools (Horizontal line) need one click; two-point tools (Trendline, Horizontal ray, Fib retracement) need two clicks; Rectangle is drawn by dragging between two corners; Path/multi-point accepts a series of points. The finished drawing is added to the active pane's symbol, taking the current default colour and thickness, and is saved. Each drawing gets a stable identity so it can later be selected, moved, recoloured, or deleted.

**Acceptance criteria.**
- Each tool creates its drawing with the expected number of clicks/drag.
- A completed drawing appears immediately and persists for that symbol.
- A newly created drawing adopts the active drawing colour/thickness.

**Edge cases & negative scenarios.**
- Abandoning a partially-drawn two-point drawing (Esc before the second click) leaves no stray drawing.
- Measure produces a temporary readout that is not stored as a permanent drawing.

#### CE-DRAW-004 — Move & delete unless locked

**Description.** A trader can drag an existing drawing to reposition it and delete it, provided it is not locked.

**Business rule.** An unlocked drawing exposes a drag affordance and a delete affordance. A drawing that is individually locked, or any drawing while the global Lock-all is on, ignores both drag and delete. Moves and deletes update the saved drawings for that symbol.

**Acceptance criteria.**
- Dragging an unlocked drawing repositions it and the new position persists.
- Deleting an unlocked drawing removes it from the chart and the saved set.
- A locked drawing (individually or via Lock-all) cannot be dragged or deleted.

**Edge cases & negative scenarios.**
- Deleting the last drawing for a symbol leaves no empty residue.
- Attempting to drag while Lock-all is on has no effect.

#### CE-DRAW-005 — Per-drawing colour & thickness

**Description.** Each drawing can have its own colour and line thickness independent of other drawings.

**Business rule.** A drawing's colour is freely chosen; thickness is 1–4 pixels (default 1). Changing colour or thickness applies to that one drawing only and is saved. Legacy drawings without an explicit thickness render at thickness 1.

**Acceptance criteria.**
- Selecting a drawing and changing its colour recolours only that drawing.
- Changing a drawing's thickness changes only that drawing's line width.
- Colour/thickness changes persist across reload.

**Edge cases & negative scenarios.**
- A drawing with no stored thickness renders at the default width 1.
- Thickness values outside 1–4 are clamped into range.

#### CE-DRAW-006 — Lock all

**Description.** A trader can lock every drawing at once so none can be accidentally moved or deleted.

**Business rule.** Lock-all is a session-level flag applying to all drawings in all panes. While on, every drawing ignores drag and delete regardless of its individual lock state. The flag is saved and restored.

**Acceptance criteria.**
- Turning Lock-all on prevents moving/deleting any drawing in any pane.
- Turning Lock-all off restores normal drag/delete for unlocked drawings.
- Lock-all state persists across reload.

**Edge cases & negative scenarios.**
- With Lock-all on, an individually-unlocked drawing is still un-movable/un-deletable.
- Lock-all does not hide drawings — they remain visible, just immovable.

#### CE-DRAW-007 — Hide all (indicators/overlays unaffected)

**Description.** A trader can hide all drawings at once to declutter, without affecting indicators or other chart overlays.

**Business rule.** Hide-all is a session-level flag suppressing the rendering of all drawings in all panes. It does not delete them and does not affect indicators, key levels, volume, or other overlays. The flag is saved and restored.

**Acceptance criteria.**
- Turning Hide-all on removes all drawings from view while leaving indicators and overlays visible.
- Turning Hide-all off restores all drawings exactly as they were.
- Hide-all state persists across reload.

**Edge cases & negative scenarios.**
- Hide-all does not remove or alter any drawing's stored data.
- Indicators, ICT studies, and other overlays remain fully visible while drawings are hidden.

#### CE-DRAW-008 — Clear all (destructive)

**Description.** A trader can permanently delete all drawings for the current symbol in one action.

**Business rule.** Clear-all removes every drawing belonging to the active pane's symbol and saves the change. This is destructive — the drawings cannot be recovered. It operates per symbol (the symbol on the active pane).

**Acceptance criteria.**
- Clear-all removes all drawings for the active pane's symbol immediately.
- After clearing, those drawings do not reappear on reload.
- Clearing affects only the active pane's symbol, not drawings belonging to other symbols.

**Edge cases & negative scenarios.**
- Clear-all on a symbol with no drawings is a no-op.
- Switching to a different symbol that still has its own drawings shows them intact after clearing the first.

#### CE-DRAW-009 — Magnet snapping

**Description.** With magnet on, drawing anchor points snap to the nearest candle price (open/high/low/close) under the cursor for precise placement.

**Business rule.** Magnet is a per-pane toggle (default off). When on and candles exist, a drawing point being placed or dragged snaps to the nearest OHLC value of the candle under the cursor instead of the free cursor price. The setting is saved per pane.

**Acceptance criteria.**
- With magnet on, placing/dragging a drawing point snaps it to a nearby candle's open/high/low/close.
- With magnet off, points follow the free cursor price with no snapping.
- The magnet setting is per pane and persists across reload.

**Edge cases & negative scenarios.**
- Magnet has no effect on an empty chart (no candles to snap to).
- Magnet on one pane does not change the magnet state of another pane.

#### CE-DRAW-010 — Symbol-keyed persistence

**Description.** Drawings belong to the symbol they were drawn on, so switching symbols swaps the visible drawings, and returning to a symbol restores its own.

**Business rule.** Drawings are stored keyed by symbol. Switching a pane's symbol shows only that symbol's drawings; returning to a previous symbol restores its drawings. All drawings round-trip through the saved session, surviving reload.

**Acceptance criteria.**
- Drawing on symbol A, switching to symbol B, then back to A restores A's drawings; B shows only B's (or none).
- All of a symbol's drawings reappear after reload.
- Per-drawing colour, thickness, and lock state are restored with each drawing.

**Edge cases & negative scenarios.**
- A symbol that was never drawn on shows no drawings.
- A corrupted saved-drawings entry does not block the chart from loading.

---

## 10. Placing Orders from the Chart

#### CE-ORD-001 — Right-click / "+" price menu (options adapt above vs below LTP)

**Description.** The trader opens a small action menu at a specific price by right-clicking (or using the "+" affordance) at that level. The order-entry shortcuts change depending on whether the clicked price is above or below the current last-traded price (LTP).

**Business rule.** Each option label shows the symbol, the chart-default quantity, and the clicked price (two decimals). If the clicked price is strictly above the LTP, the "above LTP" set is shown; in all other cases (at or below LTP, or LTP unknown) the "below LTP" set is shown. Below the order options, every variant shows a "Set Alert at <price>" row and, after a divider, a "Create new order…" row.

**Acceptance criteria.**
- Clicking a price clearly above the current LTP shows the sell-limit / buy-stop oriented options.
- Clicking a price clearly below the current LTP shows the buy-limit / sell-stop oriented options.
- Every option label contains the correct quantity, symbol, and the clicked price to two decimals.
- The "Set Alert" and "Create new order…" rows appear regardless of side.
- Clicking outside the menu dismisses it without action.

**Edge cases & negative scenarios.**
- Clicking exactly at the LTP shows the below-LTP set.
- A menu that would render off-screen stays within the visible area (clamped with a small margin).
- Rapidly clicking another price replaces, not stacks, the menu.

#### CE-ORD-002 — Menu below LTP

**Description.** When the clicked price is at or below the current LTP, the menu presents the "buy on dip / cut a long" set.

**Business rule.** In order: "Buy <qty> <symbol> @ <price> limit"; "Sell <qty> <symbol> @ <price> stop"; "Sell <qty> <symbol> @ <price> stop, <price minus one tick> limit"; then "Set Alert at <price>"; then (after a divider) "Create new order…". Buy-limit uses a limit order. Sell-stop uses a stop-market with the trigger at the clicked price. Sell stop-plus-limit uses a stop-limit with the trigger at the clicked price and the limit one tick below.

**Acceptance criteria.**
- The three trading rows read Buy limit, Sell stop, and Sell stop-with-limit, in that order.
- The buy row uses the long (blue) accent; the two sell rows the short (red) accent.
- The sell stop-plus-limit row shows a second price exactly one tick below the clicked price.
- Selecting any row carries the displayed quantity and prices forward.

**Edge cases & negative scenarios.**
- With an unusually large tick size, the "stop, <limit>" second price is still exactly one tick below and snapped correctly.
- The displayed limit offset matches the price actually used downstream.

#### CE-ORD-003 — Menu above LTP

**Description.** When the clicked price is strictly above the current LTP, the menu presents the "sell on rally / breakout entry" set.

**Business rule.** In order: "Sell <qty> <symbol> @ <price> limit"; "Buy <qty> <symbol> @ <price> stop"; "Buy <qty> <symbol> @ <price> stop, <price plus one tick> limit"; then "Set Alert at <price>"; then (after a divider) "Create new order…". Sell-limit uses a limit order. Buy-stop uses a stop-market with the trigger at the clicked price. Buy stop-plus-limit uses a stop-limit with the trigger at the clicked price and the limit one tick above.

**Acceptance criteria.**
- The three trading rows read Sell limit, Buy stop, and Buy stop-with-limit, in that order.
- The sell row uses the short (red) accent; the two buy rows the long (blue) accent.
- The buy stop-plus-limit row shows a second price exactly one tick above the clicked price.
- Selecting any row carries the displayed quantity and prices forward.

**Edge cases & negative scenarios.**
- A price only a fraction above LTP still triggers the above-LTP set.
- The "stop, <limit>" second price reflects the symbol's real tick size.

#### CE-ORD-004 — Menu fallback when LTP unavailable

**Description.** If the chart has no live LTP at the moment the menu opens, it still works and defaults to a sensible set.

**Business rule.** When LTP is unavailable, the menu uses the below-LTP set. It does not hide options, show an error, or block the trader.

**Acceptance criteria.**
- Opening the menu while LTP is unknown shows the below-LTP set with the clicked price filled in.
- The Set Alert and Create new order rows are still present.
- No error message or empty menu appears.

**Edge cases & negative scenarios.**
- If LTP becomes available a moment later, a freshly opened menu respects the new LTP; an already-open menu need not re-evaluate live.

#### CE-ORD-005 — Quantity selector popup

**Description.** A compact popup lets the trader set the order quantity using a numeric field with minus/plus steppers, a lot/step hint, quick-action icons, and a grid of multiplier preset chips.

**Business rule.** The popup contains: a centred numeric input flanked by minus and plus step buttons (each step changes quantity by one lot/step); a hint reading "Lot <lotSize>" when lot size > 1, or "Step 1" when lot size is 1; quick-action icons (reset, and last-used when available); and a 4×2 grid of eight preset chips for multipliers 1, 2, 5, 10, 25, 50, 100, 500. Each chip sets quantity to that multiplier × lot size. Chip labels read as the plain number when lot size is 1 (e.g. "5") and as "<multiplier>x" when lot size > 1 (e.g. "5x"). The chip matching the current quantity is highlighted. The field accepts digits only. Enter commits the typed value and closes the popup. Tapping outside dismisses it.

**Acceptance criteria.**
- Minus and plus each change the quantity by one lot/step.
- All eight preset chips are present and produce quantity = multiplier × lot size.
- With lot size 1, chips read "1","2","5","10","25","50","100","500" and the hint reads "Step 1".
- With a multi-unit lot, chips read with an "x" suffix and the hint reads "Lot <lotSize>".
- The chip equal to the current quantity is highlighted; others are not.
- Typing a value and pressing Enter commits it and closes the popup.
- Tapping outside closes it.

**Edge cases & negative scenarios.**
- Non-digit characters cannot be entered into the field.
- A submitted value that is not a clean lot multiple is rounded per CE-ORD-006 before committing.
- The popup stays on-screen near the click point even near a screen edge.

#### CE-ORD-006 — Lot rounding

**Description.** Any quantity entered or stepped is normalised to a valid lot multiple before it is used for an order.

**Business rule.** A quantity is rounded to the nearest whole multiple of the lot size, with a minimum of one lot. If the lot size is invalid (zero or negative), a step of one is used. A value below one lot is raised to one lot (never zero or empty). Non-numeric input is not accepted.

**Acceptance criteria.**
- Entering a value between lots snaps to the nearest lot.
- Entering zero or a value below one lot results in exactly one lot.
- Stepping down from one lot does not go below one lot.
- The committed quantity is always a whole multiple of the lot size.

**Edge cases & negative scenarios.**
- A value exactly halfway between two lot multiples rounds consistently.
- Extremely large values are still accepted and rounded to a lot multiple.
- Empty or non-numeric input never reaches the order flow.

#### CE-ORD-007 — Quick actions (reset; restore last-used)

**Description.** The quantity popup offers quick shortcuts to reset to a single lot and to restore the last-used quantity for that symbol.

**Business rule.** The reset icon sets the quantity to exactly one lot. The last-used icon appears only when a last-used quantity exists for the symbol; tapping it sets that remembered value (re-rounded to a valid lot). When none exists, the last-used icon is not shown.

**Acceptance criteria.**
- Tapping reset sets the quantity to one lot.
- When a last-used quantity exists, its icon appears and tapping it restores that quantity.
- When none exists, the last-used icon is absent.

**Edge cases & negative scenarios.**
- A restored last-used value that is not lot-aligned is rounded to a valid lot.
- Switching to a different symbol does not surface another symbol's last-used quantity.

#### CE-ORD-008 — SL-LMT one-tick limit offset on the correct side

**Description.** When the trader chooses a stop-with-limit order, the limit price is automatically offset by one tick from the trigger, on the side that makes the order marketable.

**Business rule.** For a buy stop-limit, the limit price is the trigger plus one tick. For a sell stop-limit, the limit is the trigger minus one tick. The trigger equals the clicked price. This applies both when opening the full place-order screen and when placing instantly.

**Acceptance criteria.**
- A buy stop-limit shows and uses a limit exactly one tick above the trigger.
- A sell stop-limit shows and uses a limit exactly one tick below the trigger.
- The offset uses the symbol's actual tick size.

**Edge cases & negative scenarios.**
- The offset side never inverts (a buy never gets a limit below its trigger, and vice versa).
- The offset is always applied using the symbol's configured tick rather than sending a limit equal to the trigger.

#### CE-ORD-009 — Default product code

**Description.** Orders created from the chart default to a product type appropriate to the instrument, which the trader can change before submitting.

**Business rule.** For equity on NSE or BSE, the default product is Delivery (C). For everything else (NFO, BFO, MCX), the default is Normal (M). Applied to both the place-order-screen flow and the instant flow. The trader can override the product on the place-order screen.

**Acceptance criteria.**
- An NSE or BSE equity order opens pre-set to Delivery.
- An F&O or commodity order opens pre-set to Normal.
- The product field remains editable on the place-order screen.

**Edge cases & negative scenarios.**
- A product code is always present; an order is never sent with a blank product.
- Overriding the product on the screen takes precedence over the default.

#### CE-ORD-010 — Default duration DAY

**Description.** Orders created from the chart default to a DAY validity.

**Business rule.** The order duration is set to DAY for all chart-initiated orders (place-order-screen and instant flows). The duration is never left blank.

**Acceptance criteria.**
- A chart-initiated order shows DAY as its validity by default.
- The duration field is populated when the order reaches the server.

**Edge cases & negative scenarios.**
- An order is never sent with a blank duration.

#### CE-ORD-011 — Create new order opens full place-order screen

**Description.** The "Create new order…" row opens the app's full place-order screen with the symbol and quantity already filled in, leaving the trader to complete and explicitly submit.

**Business rule.** Selecting "Create new order…" opens the place-order screen pre-filled with the symbol and chart-default quantity, but with no side, order type, or price pre-chosen. The order is not placed until the trader submits it. The default product (CE-ORD-009) and DAY duration (CE-ORD-010) are carried in.

**Acceptance criteria.**
- The place-order screen opens with the correct symbol and quantity.
- No buy/sell side or price is pre-selected for the blank create-new-order case.
- Nothing is sent to the server until the trader submits.

**Edge cases & negative scenarios.**
- The screen opens fully populated and does not crash or render blank required fields.
- Closing the screen without submitting places no order.

#### CE-ORD-012 — Set Alert at clicked price

**Description.** The "Set Alert at <price>" row lets the trader create a price alert at the clicked level directly from the chart menu.

**Business rule.** The row shows the clicked price (two decimals) with a bell indicator and, when selected, creates a price alert for the symbol at that price. It is always present regardless of side.

**Acceptance criteria.**
- The Set Alert row shows the exact clicked price.
- Selecting it creates an alert at that price for the current symbol.
- The row is present in the above-LTP and below-LTP menus and the LTP-unavailable fallback.

**Edge cases & negative scenarios.**
- Setting an alert must not place any order.
- Creating the alert from the chart must not navigate away from or blank the chart screen.

#### CE-ORD-013 — Drag to modify

**Description.** The trader can drag an existing order's line to a new price; a confirmation reflects the change from old to new, and for stop-limit orders the limit-to-trigger offset is preserved.

**Business rule.** Dragging an order line raises a modify confirmation reading "Move <side> <type> <qty> <symbol> from <old> to <new>?". For a stop-market the old price shown is the trigger. For a stop-limit where the trigger is dragged, the dialog adds "Limit price will move to <price> to preserve offset.", maintaining the gap between trigger and limit at the new level.

**Acceptance criteria.**
- Dragging an order line opens a modify confirmation showing both old and new price.
- For a stop-market order, the old price reflects the trigger.
- For a dragged stop-limit trigger, the dialog explains the limit will shift to preserve the offset, and the resulting limit keeps the same gap.
- Confirming applies the new price(s); declining leaves the order unchanged.

**Edge cases & negative scenarios.**
- Releasing the drag at essentially the original price still lets the trader keep the order unchanged.
- The preserved offset for a stop-limit must not collapse the limit onto the trigger.

#### CE-ORD-014 — Quick TP/SL

**Description.** Quick take-profit and stop-loss shortcuts pre-fill a protective or profit-taking order for an existing position at sensible default distances from the average price.

**Business rule.** Quick take-profit is the position average moved about 3% in the favourable direction; quick stop-loss is the average moved about 1.5% in the protective direction (direction depends on long/short). Both prices snap to the symbol's tick size. The order is on the opposite side of the position. These are starting values the trader reviews, and they always require a confirmation step (they never fire instantly, even in Instant mode).

**Acceptance criteria.**
- Quick TP pre-fills a price roughly 3% favourable to the average, snapped to tick.
- Quick SL pre-fills a price roughly 1.5% protective to the average, snapped to tick.
- For a long position, TP is above and SL is below; for a short, reversed.
- The placement is on the side opposite the position.
- A confirmation is always shown before the TP/SL order is placed, regardless of Instant mode.

**Edge cases & negative scenarios.**
- Prices land on valid tick multiples (no exchange rejection for off-tick price).
- The trader can adjust the pre-filled values before submitting.
- Instant mode does not bypass the TP/SL confirmation.

---

## 11. Order Defaults

#### CE-DEF-001 — 1-Tap / Instant tab

**Description.** The 1-Tap (Instant) tab controls whether order mutations fire immediately, with a global Instant toggle and a per-pane override that can Follow the global setting, force Instant, or force Confirm.

**Business rule.** There is a global Instant toggle. Each pane has an override with three choices: Follow (use the global setting), Instant (always fire immediately for this pane), or Confirm (always ask). The default per-pane override is Follow.

**Acceptance criteria.**
- The tab shows a global Instant toggle and a per-pane override with Follow / Instant / Confirm.
- A new pane defaults to Follow.
- Setting a pane to Instant makes its mutations fire immediately; Confirm always asks; Follow tracks the global toggle.

**Edge cases & negative scenarios.**
- Changing the global toggle affects only panes set to Follow.
- A pane forced to Confirm still confirms even when the global Instant toggle is on.

#### CE-DEF-002 — Instant warning (first enable; shown once)

**Description.** The first time the trader enables Instant orders, a warning dialog explains the consequence and requires explicit confirmation; it is shown only once.

**Business rule.** On first enabling Instant, a dialog titled "Enable instant orders?" appears stating that mutations (cancel, square-off, drag-modify, quick-place) will fire immediately on click with no second chance to back out. Actions: "Cancel" and an amber "Enable". Instant is enabled only if the trader clicks Enable. After confirming once, the warning is not shown again.

**Acceptance criteria.**
- Enabling Instant for the first time shows the warning with the exact title and consequence wording.
- Clicking Enable turns Instant on; clicking Cancel leaves it off.
- The warning does not reappear on later toggles once confirmed once.

**Edge cases & negative scenarios.**
- Dismissing without clicking Enable leaves Instant disabled.
- The amber Enable button is the affirmative action; Cancel is the safe default.

#### CE-DEF-003 — SL/TP tab — Auto Stop Loss

**Description.** The SL/TP tab lets the trader enable an automatic stop-loss leg on every order and configure its type, trigger unit, and trigger distance.

**Business rule.** "Auto Stop Loss" is a switch ("Adds a stop-loss leg to every order"). "SL Type" is a two-option control: SL Limit (fires at price) or SL Market (fires immediately). "SL Trigger" is a three-option control: Points, Percent, or Ticks. A "Trigger value" stepper sets the distance; its hint reads "Points below entry", "Percent below entry", or "Ticks below entry" to match the unit. In Percent the stepper moves in 0.5 increments with one decimal; in Points or Ticks it moves in whole steps of 1.

**Acceptance criteria.**
- Auto Stop Loss can be switched on and off.
- SL Type offers exactly SL Limit and SL Market.
- SL Trigger offers exactly Points, Percent, and Ticks.
- The Trigger value hint changes to reflect the selected unit.
- In Percent the stepper steps by 0.5 with one decimal; in Points/Ticks by 1 whole unit.

**Edge cases & negative scenarios.**
- The trigger value cannot go below zero.
- Switching units between Percent and Points/Ticks changes the step granularity and decimals.

#### CE-DEF-004 — Trailing SL

**Description.** The SL/TP tab offers a trailing stop-loss that shifts the stop by a set amount for every set move in the LTP.

**Business rule.** "Trailing SL" is a switch described as "SL moves by X for every Y move in LTP". When enabled, two steppers appear: "SL moves by" (X) and "For every move of" (Y). Both move in 0.5 increments with one decimal and have a minimum above zero.

**Acceptance criteria.**
- Enabling Trailing SL reveals the "SL moves by" and "For every move of" steppers.
- Disabling Trailing SL hides those two steppers.
- Both steppers step by 0.5 with one decimal.
- Neither X nor Y can be set to zero.

**Edge cases & negative scenarios.**
- With Trailing SL off, the X and Y fields are not shown and do not affect orders.
- The values persist when toggling the trailing switch back on within the same session.

#### CE-DEF-005 — Auto Take Profit

**Description.** The SL/TP tab lets the trader enable an automatic take-profit leg and configure its type and trigger distance.

**Business rule.** "Auto Take Profit" is a switch ("Adds a take-profit leg to every order"). When enabled, "TP Type" appears as a two-option control: TP Limit (fires at price) or TP Market (fires immediately). "TP Trigger" is a stepper measured in points ("Points above entry"), stepping by whole units of 1.

**Acceptance criteria.**
- Auto Take Profit can be switched on and off.
- When on, TP Type offers exactly TP Limit and TP Market.
- TP Trigger is expressed in points above entry and steps by 1.
- When Auto Take Profit is off, the TP Type control is not shown.

**Edge cases & negative scenarios.**
- The TP Trigger value cannot go below zero.
- TP Type only appears while Auto Take Profit is enabled.

#### CE-DEF-006 — Quantity tab

**Description.** The Quantity tab sets the default order quantity per instrument class, in units for equity and in lots for futures and options.

**Business rule.** "Equity" sets a default quantity in units (minimum 1, very high upper bound). "Futures" sets a default number of lots (1 to 9999). "Options" sets a default number of lots (1 to 9999). Each is a numeric stepper.

**Acceptance criteria.**
- Equity default is in units and accepts at least 1.
- Futures default is a number of lots (1 to 9999).
- Options default is a number of lots (1 to 9999).
- None of the three can be set below 1.

**Edge cases & negative scenarios.**
- Attempting to go below the minimum holds at 1.
- Futures/Options cannot exceed 9999 lots.

#### CE-DEF-007 — Product tab

**Description.** The Product tab sets the default product type per instrument class.

**Business rule.** "Equity" offers Delivery (holds overnight) or Intraday (squares off EOD). "Futures" offers Normal (carries forward) or Intraday. "Options" offers Normal or Intraday. Each is a two-option control.

**Acceptance criteria.**
- Equity offers exactly Delivery and Intraday.
- Futures offers exactly Normal and Intraday.
- Options offers exactly Normal and Intraday.
- The selected product per class is reflected in new chart orders for that class.

**Edge cases & negative scenarios.**
- The descriptions clarify the behaviour (Delivery/Normal carry/hold; Intraday squares off EOD) and must match the chosen option.
- Exactly one option per class is selected at any time.

#### CE-DEF-008 — Defaults applied to new chart orders

**Description.** The configured defaults (quantity, product, and any auto SL/TP legs) are applied to new orders created from the chart.

**Business rule.** New chart orders adopt the per-class default quantity, the per-class default product, and — when Auto Stop Loss and/or Auto Take Profit are enabled — an attached SL and/or TP leg from the configured trigger settings. These are starting values the trader can adjust on the place-order screen.

**Acceptance criteria.**
- A new equity chart order uses the equity default quantity and product.
- A new futures/options chart order uses that class's default lot quantity and product.
- With Auto Stop Loss on, a stop-loss leg is attached per the configured SL Type and trigger.
- With Auto Take Profit on, a take-profit leg is attached per the configured TP Type and trigger.

**Edge cases & negative scenarios.**
- With both auto legs off, no SL/TP legs are attached.
- The trader's manual override on the place-order screen takes precedence.

#### CE-DEF-009 — Instant badge in top bar

**Description.** When Instant mode is active, an amber warning badge appears in the chart's top bar; clicking it opens the Order Defaults 1-Tap tab.

**Business rule.** While Instant is effectively on, the top bar shows an amber badge with a warning symbol reading "INSTANT". Clicking the badge opens the Order Defaults popover focused on the 1-Tap / Instant tab.

**Acceptance criteria.**
- The amber "INSTANT" badge is visible whenever Instant mode is effectively active.
- The badge is not shown when Instant is off.
- Clicking the badge opens Order Defaults on the 1-Tap tab.

**Edge cases & negative scenarios.**
- A pane forced to Confirm while the global toggle is on reflects its own effective state.
- The badge clearly reads as a warning (amber colour and warning symbol).

---

## 12. On-Chart Overlays (Positions, Orders, Alerts)

This section covers the horizontal marker lines the chart draws directly on the price axis of a pane. Overlays are derived from the trader's live positions, open orders, and pending price alerts, and only appear when they belong to the instrument shown in that pane. The one exception is index-option positions, which are surfaced on the underlying index's spot chart (see CE-OVL-003 and CE-OVL-004).

#### CE-OVL-001 — Position line (avg-entry line with side badge and live P&L)

**Description.** When the trader holds an open net position in the instrument displayed in a pane, a horizontal line is drawn at the position's average entry price, tagged with a BUY/SELL badge and the position's live profit/loss. Clicking it opens a detail card (CE-OVL-002).

**Business rule.**
- A position overlay appears only when the pane's instrument matches the position's exchange and token, and net quantity is non-zero. Zero net quantity produces no line.
- The line sits at the position's net average price.
- Side badge: a long net quantity is the BUY side; a short net quantity is the SELL side.
- The line carries the position's live mark-to-market P&L plus a P&L percentage against cost basis (average × absolute quantity). When average or quantity is unusable, the percentage shows zero rather than an error.
- The whole line is clickable to reveal the position detail card.

**Acceptance criteria.**
- With no open position in the pane's instrument, no position line is drawn.
- With one open position, exactly one line appears at the correct average price, with the correct BUY (long) or SELL (short) badge.
- The displayed P&L updates as the market price moves (see CE-OVL-008).
- Clicking the line opens the position detail card near the click point.

**Edge cases & negative scenarios.**
- A position fully closed (net quantity zero) stops drawing its line.
- A position on a different instrument does not appear on this pane (except the option-on-underlying case in CE-OVL-003).
- Missing/malformed average price must not crash the pane; the percentage falls back to zero.

#### CE-OVL-002 — Position detail popup

**Description.** Clicking a position line opens a small detail card summarising the position and offering a close action.

**Business rule.**
- Title reads "Position ·" followed by the trading symbol.
- Lists these labelled rows in order: Symbol, Exchange, Qty (net), Avg price, LTP, Product, MTM, Realised. Any field with no value displays "—".
- The card anchors to the clicked line; if it would run off-screen it nudges back into view, and scrolls internally if it cannot fit vertically.
- Tapping outside dismisses it.
- A close action squares off the position (shared with the chart's position-close behaviour).

**Acceptance criteria.**
- The card shows all eight rows with current values; MTM and Realised reflect live figures.
- Absent fields render as "—" rather than blank or "null".
- Clicking outside closes it without acting on the position.
- The card never renders partially off-screen; it repositions or scrolls.

**Edge cases & negative scenarios.**
- A position with no realised P&L yet shows "—" for Realised.
- On a very small viewport, all rows remain readable (vertical scroll inside the card).

#### CE-OVL-003 — Option position shown on its underlying chart

**Description.** When the trader holds an index-option position (e.g. a NIFTY 25250 Call) and the active pane shows the underlying index's spot chart, the option is surfaced as a horizontal marker at the option's strike price, tagged with a short option label and the option's own live P&L. Closing it squares off the option contract, not the index.

**Business rule.**
- The marker is placed at the option's strike price (parsed from the contract symbol), not the premium.
- The label is the short option label "<strike> <type>", e.g. "25250 CE". Whole-number strikes show with no decimals; fractional strikes show two decimals.
- Side badge follows the option's own direction: a long option is BUY, a short option is SELL.
- The marker carries the option position's live mark-to-market P&L (the option's P&L, not the index's).
- The close action squares off the option contract itself, routed to the option's own exchange and token, never the index.
- An option position on the exact same instrument as the pane is handled by the standard position line (CE-OVL-001) instead, to avoid a duplicate marker.

**Acceptance criteria.**
- Holding NIFTY 25250 CE while the pane shows the NIFTY spot chart shows a marker at the 25250 level labelled "25250 CE" with the option's live P&L.
- The marker's side badge matches whether the option holding is long or short.
- Invoking close on the marker squares off the option contract, and afterwards the marker disappears.

**Edge cases & negative scenarios.**
- An option whose underlying does not match the pane's instrument does not appear (see CE-OVL-004).
- An option holding with empty stored exchange or token is skipped silently (no malformed marker).
- A contract symbol not matching the recognised option pattern is skipped (no marker, no crash).

#### CE-OVL-004 — Underlying matching for option overlays

**Description.** Option-on-underlying markers appear only when the option's underlying genuinely corresponds to the index spot shown in the pane.

**Business rule.**
- The contract symbol is parsed to extract underlying, expiry, type (Call/Put) and strike.
- Recognised index underlyings are NIFTY, BANKNIFTY, FINNIFTY, MIDCPNIFTY (mapped to their NSE spot instruments) and SENSEX (mapped to its BSE spot instrument). The option exchanges are NFO for the NSE indices and BFO for SENSEX.
- A marker is emitted only when the parsed underlying maps to an index spot whose exchange and token exactly match the pane's instrument.
- Stock options and other non-index options are out of scope and produce no underlying marker.

**Acceptance criteria.**
- A NIFTY option appears on the NIFTY spot chart but not on any other chart.
- A BANKNIFTY, FINNIFTY, or MIDCPNIFTY option appears only on its own matching NSE index spot chart.
- A SENSEX option appears only on the SENSEX spot chart.
- An option on an unrecognised or non-index underlying produces no marker.

**Edge cases & negative scenarios.**
- An option whose underlying name resembles an index but maps to a different exchange/token does not appear.
- Weekly and monthly expiries of the same underlying both match the same spot chart.

#### CE-OVL-005 — Order lines (Limit, Take-Profit, Stop-Loss, Stop-Loss-Limit)

**Description.** Open orders on the pane's instrument are drawn as horizontal lines at their working price, colour-coded and styled by order type, with a projected P&L when the order would close an existing position.

**Business rule.**
- Only genuinely open orders are drawn (accepted and not rejected, cancelled, completed, or invalid).
- A plain limit order is drawn at its limit price. If it would close an existing opposite-direction position in the same instrument, it is styled as a Take-Profit line (green) with a projected P&L; otherwise it is a neutral limit line with no projected P&L.
- A stop-loss (market-trigger) order is a red line at its trigger price; a projected P&L shows when it would close a matching position.
- A stop-loss-limit order produces two red lines: one at the trigger price and a second at the limit price, each with its own projected P&L when applicable.
- Projected P&L is computed only in the closing direction for an open position (a sell against a long, or a buy against a short), using the close quantity capped at the position size, the position average, and the order price. It is omitted for fresh, non-closing orders or non-positive quantity/price.
- Each order line records the order side and the signed working quantity.

**Acceptance criteria.**
- A standalone limit order with no matching position shows a neutral limit line and no projected P&L.
- A limit order that would take profit on an open position shows a green Take-Profit line with a projected P&L.
- A stop-loss order shows a red line at the trigger; a stop-loss-limit shows two red lines (trigger and limit).
- A rejected, cancelled, or completed order draws no line.

**Edge cases & negative scenarios.**
- An order on a different instrument does not appear.
- A stop-loss-limit closing a smaller quantity than the open position uses the order quantity for the projected P&L.
- Orders with a zero or invalid price are not drawn at an absurd level.

#### CE-OVL-006 — Order detail popup with inline quantity modify

**Description.** Clicking an order line opens a detail card summarising the order and offering an inline quantity change that can be submitted.

**Business rule.**
- Title reads "Order ·" followed by the trading symbol.
- Lists these rows in order: Symbol, Exchange, Side (BUY or SELL, or "—"), Type, Product, Qty, Price, Trigger (only when the order has a trigger price), Status, Order ID. Absent fields show "—".
- A "Modify quantity" section provides a minus/plus stepper and an editable numeric field (digits only). The quantity cannot drop below 1.
- A submit button labelled "Modify"; while in progress it reads "Modifying…" and is disabled.
- Submitting with an unchanged quantity, a non-positive quantity, or while already submitting performs no action. After a successful submit, the card dismisses.
- The exchange validates lot-size multiples; the stepper moves in steps of one and does not enforce lot size locally.
- Tapping outside dismisses the card.

**Acceptance criteria.**
- The card displays all applicable rows; the Trigger row appears only for orders that have a trigger price.
- Increasing/decreasing quantity updates the field; the field accepts only digits and never goes below 1.
- Pressing Modify with a changed valid quantity submits, shows the "Modifying…" busy state, and the card closes afterwards.
- Pressing Modify with no change does nothing.

**Edge cases & negative scenarios.**
- Clearing the field or entering zero blocks submission.
- Submitting cannot happen twice simultaneously (button disabled while busy).
- An order with no trigger price does not show the Trigger row.

#### CE-OVL-007 — Alert line at target price

**Description.** A pending price alert on the pane's instrument is drawn as a horizontal line at the alert's target price.

**Business rule.**
- An alert line appears only for the pane's instrument and only when the alert's target price is a valid positive number.
- The line is placed at the alert's target price, not at any precision/decimal-count field.
- The alert carries no quantity. Its side indicator is derived from the alert type ("LTP above" → buy side; otherwise sell side) purely for styling.

**Acceptance criteria.**
- A pending alert with a valid target price draws a line at that exact price.
- An alert with a missing or non-positive target price draws no line.
- An alert on a different instrument does not appear on this pane.

**Edge cases & negative scenarios.**
- An alert whose target field is empty or zero is skipped (never rendered at an off-chart price).
- Multiple alerts at different targets each draw their own line.

#### CE-OVL-008 — Real-time overlay updates

**Description.** Overlays keep themselves current as positions, orders, alerts, and prices change, without any manual refresh.

**Business rule.**
- A newly opened position, newly placed open order, or newly created pending alert on the pane's instrument appears automatically.
- A closed position, a filled or cancelled order, and a removed alert cause their lines to disappear.
- Position and option-marker P&L and MTM recompute on each market tick using the latest price.

**Acceptance criteria.**
- Placing a new order on the displayed instrument adds its line without reloading the chart.
- Filling or cancelling an order removes its line.
- Closing a position removes its line; the P&L visibly changes as the price moves.

**Edge cases & negative scenarios.**
- A partial fill that leaves the order open keeps the line; a full fill removes it.
- Rapid sequential changes (place, modify, cancel) leave the overlay set consistent with the final state.

---

## 13. Confirmation & Instant-Orders Behaviour

#### CE-CNF-001 — Default = confirm; dialogs render above the chart and block interaction

**Description.** By default, every order mutation asks for confirmation, and the dialog renders above the chart and blocks interaction with it.

**Business rule.** The default behaviour is to confirm before mutating. Confirmation dialogs render above the embedded chart with a dark backdrop that visually covers and blocks clicks to the chart underneath. Tapping the backdrop dismisses the dialog without acting.

**Acceptance criteria.**
- With Instant off, every mutation (cancel, square-off, modify, alert cancel, exit-all) shows a confirmation first.
- The dialog appears clearly above the chart, not hidden behind it.
- The chart underneath cannot be clicked while the dialog is open.
- Tapping the dark backdrop closes the dialog and performs no action.

**Edge cases & negative scenarios.**
- The chart must never remain interactive behind an open dialog.
- Dismissing via the backdrop is treated as "do not proceed".

#### CE-CNF-002 — Cancel order dialog wording

**Description.** Cancelling an order from the chart shows a confirmation naming the order type, quantity, and symbol.

**Business rule.** Titled "Cancel order" with body "Cancel <type> order for <qty> <symbol>?" (e.g. "Cancel SL-MKT order for 50 NIFTY?"). Actions: "Keep" (dismiss, no action) and "Cancel order" (proceed).

**Acceptance criteria.**
- The body includes the correct order type, quantity, and symbol.
- "Keep" closes the dialog and cancels nothing.
- "Cancel order" cancels the order.

**Edge cases & negative scenarios.**
- The type/qty/symbol shown matches the actual order being cancelled.
- If fields are missing, the wording still renders without crashing.

#### CE-CNF-003 — Square-off dialog

**Description.** Squaring off a position from the chart shows a confirmation describing a market order on the opposite side for the net quantity.

**Business rule.** Titled "Square off position" with body "Place a MARKET <side> for <qty> <symbol> to close this position?". The side is the opposite of the position (long → SELL; short → BUY). The quantity shown is the absolute net quantity. The order is a market order with DAY validity, using the position's product. Frozen quantity is excluded/handled (rounded to whole lots). Actions: "Keep" and "Square off".

**Acceptance criteria.**
- A long position shows "MARKET SELL …"; a short shows "MARKET BUY …".
- The quantity shown is the absolute net quantity (no minus sign).
- "Square off" places a market order on the opposite side; "Keep" does nothing.
- The placement uses the position's product and a market price.

**Edge cases & negative scenarios.**
- Frozen quantity is accounted for (whole-lot rounded) so the exchange does not reject for freeze breach.
- Squaring off from the chart must not blank or close the chart screen.

#### CE-CNF-004 — Modify dialog

**Description.** Modifying an order (typically via drag) shows a confirmation of the price change, preserving the trigger-to-limit offset for stop-limit orders.

**Business rule.** Titled "Modify order". For a simple price change: "Move <side> <type> <qty> <symbol> from <old> to <new>?". For a stop-limit where the trigger is dragged, it adds "Limit price will move to <new limit> to preserve offset." For a stop-market the old price is the trigger. Actions: "Keep" and "Modify".

**Acceptance criteria.**
- The dialog shows both old and new price.
- For a stop-market order, the old price is the trigger.
- For a dragged stop-limit, the dialog states the limit will move to preserve the offset, and both trigger and limit update together.
- "Modify" applies; "Keep" leaves the order unchanged.

**Edge cases & negative scenarios.**
- The preserved offset must not collapse the limit onto the trigger.
- Side, type, quantity, symbol shown match the order being modified.

#### CE-CNF-005 — Cancel alert dialog

**Description.** Cancelling a price alert from the chart shows a confirmation naming the alert price and symbol.

**Business rule.** Titled "Cancel alert" with body "Cancel alert at <price> for <symbol>?". Actions: "Keep" and "Cancel alert".

**Acceptance criteria.**
- The body shows the correct alert price and symbol.
- "Cancel alert" cancels the alert; "Keep" leaves it active.

**Edge cases & negative scenarios.**
- The price and symbol shown match the actual pending alert.
- Cancelling an alert places no order and does not disturb open positions.

#### CE-CNF-006 — Exit all confirm

**Description.** Exiting all positions from the chart shows a single confirmation covering all open positions at market.

**Business rule.** The exit-all confirmation reads "Square off all <N> open position(s) at market?", where N is the count of open positions. Confirming places market square-off orders for all; declining does nothing.

**Acceptance criteria.**
- The confirmation states the correct count of open positions.
- Confirming squares off all open positions at market.
- Declining leaves all positions open.

**Edge cases & negative scenarios.**
- With zero open positions the action has nothing to do.
- The count shown matches the actual number of open positions at the moment of confirmation.

#### CE-CNF-007 — Instant mode skips confirm

**Description.** When Instant mode is effective, the four mutation types fire immediately without a confirmation dialog.

**Business rule.** With Instant effectively on (global toggle or a pane override of Instant), cancels, square-offs, drag-modifies, and quick-places execute immediately on click, skipping their confirmation dialogs — exactly the set named in the first-enable warning.

**Acceptance criteria.**
- With Instant on, cancelling an order fires immediately with no dialog.
- With Instant on, squaring off fires immediately with no dialog.
- With Instant on, a drag-modify applies immediately with no dialog.
- With Instant on, a quick-place fires immediately with no dialog.

**Edge cases & negative scenarios.**
- A pane explicitly set to Confirm still shows dialogs even when the global toggle is on.
- TP/SL placement is excluded from this skip (see CE-CNF-008).

#### CE-CNF-008 — TP/SL placement always confirms

**Description.** Quick take-profit and stop-loss placements always require a confirmation, regardless of Instant mode, because they open new exposure that deserves a deliberate step.

**Business rule.** TP/SL placement never fires instantly. Even when Instant is on, placing a quick TP or quick SL presents the pre-filled order for review/confirmation before it is sent.

**Acceptance criteria.**
- With Instant off, quick TP/SL is reviewed/confirmed before placement.
- With Instant on, quick TP/SL is still reviewed/confirmed and does not fire immediately.
- The pre-filled TP/SL values can be adjusted before confirming.

**Edge cases & negative scenarios.**
- No combination of global toggle or pane override causes TP/SL to bypass confirmation.
- Cancelling the TP/SL confirmation places no order.

---

## 14. Workspace Panels

The workspace has a fixed vertical icon strip on the right edge, with six icons in order: Watchlist, Positions, Holdings, Orders, DOM, and Option chain, each with a hover tooltip. Clicking an icon slides out a single side panel; only one panel is open at a time, and clicking the active icon again collapses it. The open icon is highlighted with the accent colour and an accent edge marker. Within any panel, clicking a row loads that instrument into the active chart pane (the tray does not auto-collapse, so the trader can pick several symbols in succession). All panels reflect live updates without manual refresh.

### 14.1 Watchlist

#### CE-WL-001 — Watchlist tabs

**Description.** The Watchlist panel offers a horizontal strip of named lists the trader can switch between.

**Business rule.**
- The header reads "Watchlist", followed by "· <list name>" for the selected list.
- The tab strip presents the available lists. Predefined lists are relabelled for display: "Holdings" (the trader's stocks), "Positions" (the trader's positions), "Nifty 50", "Nifty Bank", and "Sensex".
- The active tab's label is in the accent colour with a short underline marker; inactive tabs are muted.
- When the provider returns no lists, a fallback set is shown: Holdings, Nifty 50, Nifty Bank, Sensex, plus Positions only when open positions exist.

**Acceptance criteria.**
- On first open, the panel bootstraps and selects a sensible default list, with its tab underlined and named in the header.
- Switching tabs updates the underline, the header name, and the row list.
- The "Positions" tab is present only when open positions exist (in the fallback scenario).

**Edge cases & negative scenarios.**
- If no named lists are available, the empty state "No watchlists yet" is shown.
- Rapid tab switching must not double-load; switching to the already-active tab does nothing.

#### CE-WL-002 — Watchlist rows

**Description.** Each row shows a scrip with its exchange, name, instrument type, last price, and percent change.

**Business rule.**
- Each row shows an exchange chip, the display name, and (when present) an instrument-type line beneath the name.
- The right side shows the last price and, below it, the percent change suffixed with "%". A non-negative change is prefixed with "+".
- Price and percent are formatted to two decimals and colour-coded: green when change is non-negative, red when negative.
- For the Holdings list, rows are sourced from holdings; for the Positions list, from open positions (zero-quantity positions excluded).

**Acceptance criteria.**
- Each row renders an exchange chip, name, LTP and percent, with two-decimal formatting.
- Up moves render green (with "+" on percent), down moves red.
- The Holdings and Positions tabs render their respective instruments.

**Edge cases & negative scenarios.**
- A scrip with no live price yet falls back to its snapshot value, defaulting to "0.00" when nothing is available.
- A row with no instrument type omits that secondary line.

#### CE-WL-003 — Watchlist loading state

**Description.** While fetching or switching lists, a loading indicator is shown.

**Business rule.**
- A centred spinner is shown while switching lists, or while the initial bootstrap is running and no rows are yet available.

**Acceptance criteria.**
- Switching to a list that needs fetching shows the spinner until rows arrive.
- Once rows load, the spinner is replaced by the row list.

**Edge cases & negative scenarios.**
- If a fetch fails silently, the panel falls through to rows or the appropriate empty state, never a permanent spinner.

#### CE-WL-004 — Watchlist empty states

**Description.** The panel communicates clearly when there is nothing to show.

**Business rule.**
- "No watchlists yet" — when there are no named lists.
- "Pick a watchlist" — when no list is selected.
- "No scrips in \"<list name>\"" — when a list is selected but contains no scrips.

**Acceptance criteria.**
- Each condition shows its exact message, centred.
- The message updates as the trader switches lists.

**Edge cases & negative scenarios.**
- An empty Holdings or Positions list shows the "No scrips in …" message with the list's display name.

#### CE-WL-005 — Watchlist row click and live updates

**Description.** Clicking a row loads that instrument into the active pane; rows update live.

**Business rule.**
- Clicking a row applies that scrip to the active pane.
- Prices and percent changes update in real time.

**Acceptance criteria.**
- Clicking any row swaps the active pane to that instrument.
- LTP and percent values tick live without manual refresh.

**Edge cases & negative scenarios.**
- The tray remains open after a pick, allowing consecutive selections.

### 14.2 Positions

#### CE-POS-001 — Positions header

**Description.** The header shows the panel name and a count of open positions.

**Business rule.**
- Header reads "Positions"; when there is at least one open position it is followed by "· N open". When there are none, no count suffix is shown.
- Open positions are those with non-zero net quantity and a valid status.

**Acceptance criteria.**
- With open positions present, the header shows "· N open" with the correct count.
- With no open positions, only "Positions" is shown.

**Edge cases & negative scenarios.**
- Positions with zero net quantity are excluded from the count and list.

#### CE-POS-002 — Positions summary card

**Description.** Above the list, a summary card shows the aggregate live P&L across open positions.

**Business rule.**
- The card displays a single large total value (summed live P&L of all open positions) to two decimals, labelled "Total P&L".
- The value is green when non-negative and red when negative.
- The card appears only when at least one open position exists. (The per-position 1D Change/Invested/Current breakdown is provided in the Holdings panel, not here.)

**Acceptance criteria.**
- The summary value equals the sum of the open positions' P&L, to two decimals.
- The colour follows the sign of the total.
- With no open positions, no summary card is shown.

**Edge cases & negative scenarios.**
- Positions flagged not-OK are excluded from the total.
- The total updates live as prices move.

#### CE-POS-003 — Position rows

**Description.** Each open position is shown as a row with its identity, direction, key figures, and an Exit action.

**Business rule.**
- Each row shows an exchange chip, the display name, and a LONG/SHORT pill: LONG (green) for long net quantity, SHORT (red) for short.
- The exchange chip is colour-accented: derivative/commodity exchanges (NFO, BFO, MCX) use the warning colour; others the primary colour.
- A secondary line reads "Qty <abs qty> · Avg <avg price> · LP <last price>".
- The P&L is shown to two decimals, green when non-negative, red when negative.
- Each row has an "Exit" button in the loss colour.
- The last price prefers the live value and falls back to the stored value.

**Acceptance criteria.**
- Each row shows chip, name, correct LONG/SHORT pill, the Qty/Avg/LP line, P&L, and an Exit button.
- The P&L colour follows its sign and updates live.
- Clicking the row body (not Exit) loads that instrument into the active pane.

**Edge cases & negative scenarios.**
- A position lacking a live price shows the stored last price (or a dash if none).
- Long vs short colouring matches the sign of the net quantity, not the P&L.

#### CE-POS-004 — Exit a single position

**Description.** The Exit button on a row squares off that one position after confirmation.

**Business rule.**
- Tapping Exit opens a dialog titled "Exit position" asking "Exit <symbol>?" with Cancel and Exit (Exit in the loss colour).
- Confirming squares off the full net quantity at market in the closing direction (sell to close a long, buy to close a short), respecting freeze-quantity limits.
- Cancelling makes no change.

**Acceptance criteria.**
- The dialog shows "Exit <symbol>?" with the position's display name.
- Confirming sends a market square-off for that position; cancelling does nothing.

**Edge cases & negative scenarios.**
- A position with zero net quantity is not exited.
- Freeze-quantity is honoured so large positions are sliced appropriately.

#### CE-POS-005 — Exit all positions

**Description.** A panel-level action squares off all open positions after confirmation.

**Business rule.**
- An "Exit All Positions" action (loss colour) is shown above the list when open positions exist.
- Tapping it opens a dialog titled "Exit all positions" asking to square off all N open position(s) at market, with Cancel and "Exit All".
- Confirming squares off each open position in turn at market.

**Acceptance criteria.**
- The confirmation states the count of open positions to be squared off.
- Confirming exits every open position; cancelling exits none.

**Edge cases & negative scenarios.**
- With no open positions, the Exit All control is not shown.

#### CE-POS-006 — Positions empty state and live P&L

**Description.** The panel communicates an empty book and keeps figures live.

**Business rule.**
- With no open positions, the body shows "No open positions" centred.
- Position last prices, P&L, and the summary total update live.

**Acceptance criteria.**
- With no open positions, "No open positions" is shown and no summary card or Exit All control appears.
- With open positions, P&L figures tick live.

**Edge cases & negative scenarios.**
- When the last open position is closed, the panel transitions to the empty state.

### 14.3 Holdings

#### CE-HLD-001 — Holdings header and summary card

**Description.** The Holdings panel shows a count of held stocks and a four-figure portfolio summary card.

**Business rule.**
- Header reads "Holdings" followed by the stock count: "N stock" for one, "N stocks" otherwise; blank when there are no holdings.
- The summary card shows four cells: "1D Change", "Total P&L", "Invested", and "Current".
- "1D Change" and "Total P&L" each show a signed value (positive prefixed with "+") plus a signed percent, colour-coded green positive, red negative, neutral for zero.
- "Invested" and "Current" show plain two-decimal values in the primary text colour.
- All monetary values to two decimals; percents to two decimals with a sign.

**Acceptance criteria.**
- The header count uses singular/plural correctly.
- The summary card shows the four cells with correct signs, percents, and colours.

**Edge cases & negative scenarios.**
- With zero invested, the percent calculations fall back to zero rather than dividing by zero.
- Live prices feed the Current and P&L figures where available.

#### CE-HLD-002 — Holdings rows

**Description.** Each holding is shown with its identity, quantity, average, invested amount, P&L, percent, last price, and a pledge indicator.

**Business rule.**
- Each row shows an exchange chip, the symbol, a lock icon when pledged, a "QTY <qty>  AVG <avg>" line, and an "INV <invested>" line.
- The right side shows the signed P&L (two decimals, "+" when positive), the signed percent change, and "LTP <last price>".
- P&L and percent are colour-coded: green positive, red negative, neutral for zero.
- A holding is treated as pledged when its demat quantity differs from its current quantity.

**Acceptance criteria.**
- Each row shows chip, symbol, qty/avg, invested, P&L, percent, and LTP.
- A pledged holding shows the lock icon next to its symbol.
- Colour coding of P&L and percent follows sign.

**Edge cases & negative scenarios.**
- Average price falls back across available source fields; invested uses the upload price times quantity.
- A non-pledged holding shows no lock icon.

#### CE-HLD-003 — Holdings empty state

**Description.** The panel communicates an empty holdings book.

**Business rule.**
- When there are no holdings, the body shows "No holdings" centred.

**Acceptance criteria.**
- With no holdings, "No holdings" is shown and the header count text is blank.

**Edge cases & negative scenarios.**
- Holdings flagged not-OK or lacking instrument data are excluded from the list and totals.

#### CE-HLD-004 — Holdings row click and live updates

**Description.** Clicking a holding loads it into the active pane; figures update live.

**Business rule.**
- Clicking a row applies the holding's primary instrument to the active pane.
- Last price, current value, P&L, and the summary card update live.

**Acceptance criteria.**
- Clicking a row swaps the active pane to that holding's instrument.
- LTP, P&L, and summary figures tick live.

**Edge cases & negative scenarios.**
- When no live price is available, the stored last price is used.

### 14.4 Orders

#### CE-ORDP-001 — Orders header and Open/Executed tabs

**Description.** The Orders panel splits orders into Open and Executed tabs, each showing its own count, plus a total in the header.

**Business rule.**
- Header reads "Orders" followed by "· N total" (open plus executed shown).
- Two tabs: "Open" and "Executed", each label followed by its count (e.g. "Open 3", "Executed 12"). The active tab is in the accent colour with an underline marker.
- Open-tab orders have status OPEN, TRIGGER_PENDING, or OPEN_PARTIAL. Executed-tab orders have status COMPLETE, CANCELED/CANCELLED, REJECTED, or EXPIRED.

**Acceptance criteria.**
- The header shows the correct combined total.
- Each tab shows its correct count; switching tabs updates the underline and the list.

**Edge cases & negative scenarios.**
- Orders whose status falls outside both sets are not listed in either tab.
- Switching to the already-active tab does nothing.

#### CE-ORDP-002 — Order rows

**Description.** Each order row shows side, name, status, key attributes, and fill progress.

**Business rule.**
- Each row shows a side chip ("B" green for buy, "S" red for sell), the display name, and a status chip.
- Status chip colour: COMPLETE green; CANCELLED, CANCELED, REJECTED red; OPEN, OPEN_PARTIAL, TRIGGER_PENDING amber/gold; EXPIRED and anything else muted. CANCELED/CANCELLED display as "CANCELLED".
- A secondary line concatenates available attributes with " · ": exchange, product, order type, and time (HH:MM from the exchange/order timestamp).
- A figures line reads "Qty <filled>/<total> · @<price>", with "LTP <last price>" appended when a live price is available; prices two decimals.

**Acceptance criteria.**
- Each row shows the side chip, name, correctly coloured status chip, attribute line, and "filled/total @ price".
- Status chip colour matches the status category.

**Edge cases & negative scenarios.**
- A row missing some attributes omits them from the " · " line.
- When no live price is available, the "LTP …" suffix is omitted.

#### CE-ORDP-003 — Cancel an open order

**Description.** Open-tab orders offer a cancel action with confirmation and busy feedback.

**Business rule.**
- Cancel and Modify action icons appear only on the Open tab.
- Tapping Cancel opens a dialog titled "Cancel order?" showing the order name and a "<Buy/Sell> <qty> @ <price>" summary, with "Keep" and "Cancel order" (the latter in the loss colour).
- Confirming submits the cancellation; while in progress the cancel icon shows a busy state and is disabled.
- If the cancellation fails, a snackbar reading "Failed to cancel order" is shown.

**Acceptance criteria.**
- The confirmation shows the order name and Buy/Sell qty @ price summary.
- Confirming cancels the order and shows the busy state during the request.
- A failed cancel shows the "Failed to cancel order" snackbar.

**Edge cases & negative scenarios.**
- An order with no order number cannot be cancelled (no-op).
- The cancel action cannot be triggered twice while a cancel is already in progress.

#### CE-ORDP-004 — Modify an open order

**Description.** The Modify action on an open order directs the trader to the main Orders screen.

**Business rule.**
- Tapping the Modify icon shows a brief snackbar reading "Modify from main Orders screen" (modification is performed there, not inline).

**Acceptance criteria.**
- Tapping Modify shows the "Modify from main Orders screen" message.
- No modification is performed from within the panel.

**Edge cases & negative scenarios.**
- The Modify icon is not present on the Executed tab.

#### CE-ORDP-005 — Orders empty states, row click, and live updates

**Description.** Each tab communicates emptiness, rows are clickable, and the list updates live.

**Business rule.**
- The Open tab shows "No open orders" when empty; the Executed tab shows "No executed orders" when empty.
- Clicking a row body loads that order's instrument into the active pane.
- The order list and per-row figures update live.

**Acceptance criteria.**
- Each tab shows its exact empty message when it has no orders.
- Clicking a row swaps the active pane to that instrument.
- New orders, fills, cancellations, and status changes appear without manual refresh.

**Edge cases & negative scenarios.**
- An order moving from open to executed shifts from the Open tab to the Executed tab and updates both counts.

---

## 15. Depth of Market (DOM)

The DOM panel renders a five-level bid/ask ladder for the active pane's instrument, from the live market-depth feed.

#### CE-DOM-001 — DOM layout

**Description.** The DOM panel shows a titled, four-column, five-row depth ladder.

**Business rule.**
- The header reads "DOM ·" followed by the instrument's display name.
- Four centred column headers, in order: "Bid Qty", "Bid", "Ask", "Ask Qty".
- Exactly five depth rows are rendered, one per level.

**Acceptance criteria.**
- The header shows "DOM · <symbol>" for the active instrument.
- The four columns appear in the stated order, and five rows are shown.

**Edge cases & negative scenarios.**
- Levels with no data still occupy a row (showing zeroes) rather than collapsing the ladder.

#### CE-DOM-002 — DOM data and quantity bars

**Description.** Each row shows bid/ask prices and quantities, with quantity bars sized proportionally to the largest quantity on display.

**Business rule.**
- Bid and ask prices are shown to two decimals.
- Each row's bid quantity bar grows from the right edge toward the left; each ask quantity bar grows from the left edge toward the right.
- Bar width is proportional to that row's quantity relative to the largest bid or ask quantity across the five rows.

**Acceptance criteria.**
- Prices render with two decimals.
- The row with the largest quantity has a full-width bar; smaller quantities proportionally shorter.
- Bid bars are anchored to the right, ask bars to the left.

**Edge cases & negative scenarios.**
- When all quantities are zero, bars have zero width and no bar is visible.
- A single dominant quantity scales the others down proportionally.

#### CE-DOM-003 — DOM colour coding

**Description.** Bid and ask sides are visually distinguished by colour.

**Business rule.**
- Bid quantity bars use a soft (low-opacity) green fill; ask quantity bars use a soft (low-opacity) red fill.

**Acceptance criteria.**
- Bid bars appear soft green, ask bars soft red, with subtle (non-solid) fills.

**Edge cases & negative scenarios.**
- The fills remain readable behind the quantity text in both light and dark themes.

#### CE-DOM-004 — DOM live updates

**Description.** The ladder refreshes automatically as new depth data arrives.

**Business rule.**
- The panel updates on every depth push from the live feed, with no manual refresh control.

**Acceptance criteria.**
- Prices, quantities, and bar widths change in real time as the market moves.
- There is no refresh button and none is required.

**Edge cases & negative scenarios.**
- Rapid updates must not flicker the layout (row count stays fixed at five).

#### CE-DOM-005 — DOM empty states

**Description.** The panel communicates when there is no instrument or no depth data.

**Business rule.**
- When no symbol is loaded in the active pane, the body shows "Pick a symbol first".
- When a symbol is loaded but no depth data is available, the body shows "No depth data for <symbol>".

**Acceptance criteria.**
- With no active symbol, "Pick a symbol first" is shown under a plain "DOM" header.
- With an active symbol but no depth, "No depth data for <symbol>" is shown.

**Edge cases & negative scenarios.**
- Selecting a symbol that later receives depth data transitions the panel from the empty message to the ladder automatically.

---

## 16. Option Chain Panel

The Option Chain panel displays a strike-by-strike Call/Put chain for an underlying. By default it follows the active pane's instrument, but the trader can override it.

#### CE-OC-001 — Follows the active pane

**Description.** The panel defaults its underlying to the active pane's instrument.

**Business rule.**
- The header reads "Option chain" followed by "· <underlying>" (the active pane's display name or symbol).
- When no chart is open in the active pane, the body shows "Open a chart first".

**Acceptance criteria.**
- With an instrument in the active pane, the header names that underlying and the chain loads for it.
- With no active chart, "Open a chart first" is shown.

**Edge cases & negative scenarios.**
- Changing the active pane's instrument re-points the panel to the new underlying (unless an override is active — see CE-OC-002).

#### CE-OC-002 — Override the underlying

**Description.** The trader can pin the chain to a chosen underlying independent of the active pane, and later return to following the pane.

**Business rule.**
- A search icon in the header opens an embedded watchlist picker (titled "Pick underlying"); selecting a scrip sets it as the override and closes the picker.
- While the picker is open, the search icon becomes a close icon (accent colour) that closes the picker.
- When an override is active, an "unlink" icon (tooltip "Follow active pane") appears; tapping it clears the override and the panel returns to following the active pane.

**Acceptance criteria.**
- Tapping the search icon opens the underlying picker; choosing a scrip pins the chain to it.
- With an override active, the unlink control is shown and clears the override when tapped.

**Edge cases & negative scenarios.**
- Picking an underlying in the override picker must not change the active pane's instrument.
- Closing the picker without a selection leaves the previous underlying in place.

#### CE-OC-003 — Expiry strip

**Description.** Available expiries are shown as a selectable horizontal strip.

**Business rule.**
- Expiry chips are shown in date order, earliest first, labelled by expiry date (e.g. "19-JAN").
- The active expiry is in the accent colour with an underline marker; the earliest is selected by default.
- Selecting an expiry fetches that expiry's strikes.

**Acceptance criteria.**
- Expiries appear earliest-first; the first is selected on load.
- Selecting a different expiry underlines it and reloads the strike rows.

**Edge cases & negative scenarios.**
- Expiries with missing symbol/exchange data are excluded from the strip.

#### CE-OC-004 — Strike rows

**Description.** Each strike row shows Call and Put figures around a centred strike, with chart-open icons.

**Business rule.**
- The strike value is centred. Whole-number strikes show with no decimals; fractional strikes two decimals.
- For each side, the row shows the option's last price and open interest. A column-header row labels the columns (LTP / OI on each side, strike in the centre).
- Open interest is abbreviated: thousands as "K", lakhs (hundred-thousands) as "L", crores (ten-millions) as "Cr", each to one decimal; smaller values as a plain integer.
- Last prices show to two decimals. A missing or zero value shows "—".
- Each side has a chart-open icon: the Call icon is blue and the Put icon is red.

**Acceptance criteria.**
- Each strike row shows Call LTP/OI on one side, Put LTP/OI on the other, and the centred strike.
- OI values render with K/L/Cr abbreviations; prices to two decimals.
- The Call chart icon is blue and the Put chart icon is red.

**Edge cases & negative scenarios.**
- A side with no contract for a strike shows "—" for its LTP and OI.
- Strikes are sorted ascending regardless of feed order.

#### CE-OC-005 — Open an option in the chart

**Description.** Tapping a side's chart icon loads that option contract into the active pane.

**Business rule.**
- Tapping an enabled chart icon loads that Call or Put contract into the active pane, tagged as an option so the default order quantity uses the options-default lot rule (rather than the equity default of one).
- When a strike is missing one leg, that side's icon is disabled and dimmed, with a tooltip "No CE" or "No PE"; its price/OI cells show "—".
- An enabled icon's tooltip reads "Open <contract symbol> in chart".

**Acceptance criteria.**
- Tapping an enabled icon loads that contract into the active pane with the options-default quantity applied.
- A missing leg shows a disabled, dimmed icon with the "No CE"/"No PE" tooltip and "—" cells.

**Edge cases & negative scenarios.**
- The disabled icon is not clickable (no-op) and shows the basic cursor.

#### CE-OC-006 — Loading and empty states

**Description.** The panel communicates fetching and empty conditions for both the chain and the strikes.

**Business rule.**
- While resolving the underlying's linked option metadata, a small inline spinner is shown in the strip area.
- When the resolved underlying has no option chain, the body shows "No option chain for <underlying>. Tap the search icon to pick another symbol."
- While fetching strikes for a selected expiry (and none yet loaded), a centred spinner is shown.
- When a selected expiry returns no strikes, the body shows "No strikes for this expiry".

**Acceptance criteria.**
- A spinner is shown while linked metadata or strikes are loading.
- An underlying with no option chain shows the "No option chain for …" message.
- An expiry with no strikes shows "No strikes for this expiry".

**Edge cases & negative scenarios.**
- A silent fetch failure resolves to an empty/strikes message rather than a permanent spinner.
- Switching expiries shows the strikes spinner only until the new strikes arrive.

#### CE-OC-007 — Live LTP and OI updates

**Description.** Strike last prices and open interest update live.

**Business rule.**
- Each visible strike's contracts are subscribed to the live touchline feed; last price and open interest update in real time.

**Acceptance criteria.**
- Strike LTP and OI values tick live without manual refresh.
- Newly loaded strikes begin updating once subscribed.

**Edge cases & negative scenarios.**
- A contract that has not yet pushed live data shows its snapshot value (or "—" when none), then updates once live data arrives.

---

## 17. Keyboard Shortcuts

Keyboard shortcuts are a session-level convenience layer that lets a tester drive the active pane and order entry without the mouse. They are governed by a single master toggle ("Keyboard shortcuts") in the chart Settings popover. The toggle defaults to OFF for every new session, and its value is remembered across sessions. When the toggle is OFF, all shortcuts below are ignored — the only key that still acts is Esc (CE-KEY-004), which is always live. All shortcuts presuppose the toggle is ON unless a requirement states otherwise. A "hovered price" means the price level on the vertical axis directly under the mouse pointer at the moment the key is pressed. The "active pane" is the pane currently highlighted as active.

#### CE-KEY-001 — Buy/Sell at hovered price (Alt+B / Alt+S)

**Description.** With shortcuts enabled, a tester can place a buy or sell order at the exact price their mouse is hovering over, using a single key combination.

**Business rule.**
- Alt+B initiates a BUY at the price under the cursor on the active pane.
- Alt+S initiates a SELL at the price under the cursor on the active pane.
- The order uses the active pane's current quantity and the saved Order Defaults (product per family, any auto SL/TP) — the keyboard path constructs the same order the mouse-driven buy/sell would.
- Whether the order is placed immediately or shown as a confirmation depends on the effective Instant-orders state for that pane (per-pane override if set, otherwise the session global). Instant is OFF by default, so the default is to surface a confirmation.
- The keys act only on the active pane; the price used is the one under the pointer at the instant the combo is pressed.

**Acceptance criteria.**
- With shortcuts ON and a tradable symbol loaded, hovering at a price and pressing Alt+B starts a buy at that hovered price; Alt+S starts a sell.
- The order's side, price, and quantity match the pressed key, the hovered level, and the pane's quantity.
- With Instant OFF (default), a confirmation appears before anything is sent; with Instant effectively ON, the order is sent without a confirmation step.
- The order respects the saved product-type and SL/TP defaults for that instrument family.

**Edge cases & negative scenarios.**
- A non-tradable instrument (e.g. an index spot or commodity flagged non-tradable): Alt+B / Alt+S must NOT start an order.
- No symbol on the active pane: the combos do nothing.
- Pointer hovering outside the price plot area (axis gutter or a popover): no order is created from an undefined price.
- Pressing the combo while a confirmation/popover is already open must not start a second order behind it.

#### CE-KEY-002 — Toggle Instant orders (Alt+I)

**Description.** A tester can flip the session-level Instant-orders mode with a single combo, mirroring the Settings switch.

**Business rule.**
- Alt+I toggles the session-level Instant flag between ON and OFF.
- The new value is reflected everywhere it is shown (the Settings switch and any Instant badge) and is remembered across sessions.
- Turning Instant ON is gated by the one-time Instant warning acknowledgement (CE-X-003) — once acknowledged, the warning is not shown again.
- Per-pane Instant overrides continue to take precedence over the session flag; Alt+I changes only the session global.

**Acceptance criteria.**
- Pressing Alt+I with shortcuts ON flips Instant mode; pressing it again flips it back.
- The Settings Instant switch and any Instant badge update immediately.
- After toggling and reopening the chart in a fresh session, the last value persists.
- A pane carrying its own ON/OFF override keeps that override regardless of Alt+I.

**Edge cases & negative scenarios.**
- The first-ever switch to ON triggers the Instant warning flow; declining leaves Instant OFF.
- Rapidly pressing Alt+I settles on a single coherent state with no flicker or duplicated warnings.

#### CE-KEY-003 — Timeframe shortcuts (1, 5, Shift+1, H, D)

**Description.** A tester can switch the active pane's timeframe directly from the keyboard.

**Business rule.**
- 1 → 1-minute; 5 → 5-minute; Shift+1 → 15-minute; H → 1-hour (60-minute); D → 1-day.
- Each key changes only the active pane's timeframe; other panes are untouched.
- The new timeframe is persisted for that pane and reflected in the top bar's Timeframe control (CE-X-005).

**Acceptance criteria.**
- With shortcuts ON, each listed key/combo switches the active pane to the stated timeframe and the chart reloads candles at that interval.
- The top bar's Timeframe selector updates to show the chosen interval.
- Switching the active pane and pressing a timeframe key affects the newly active pane only.
- The chosen timeframe survives a session reload.

**Edge cases & negative scenarios.**
- Shift+1 must produce 15-minute, not 1-minute — the Shift modifier is honoured and the plain 1 path is not also triggered.
- Pressing a timeframe key while a text input (e.g. the symbol typeahead) has focus must not hijack typing.
- Pressing a timeframe key on a pane with no symbol changes the stored timeframe but shows no candles until a symbol is chosen.

#### CE-KEY-004 — Esc cancels tool / drag or closes popup

**Description.** Esc is the universal "back out" key: it cancels an in-progress drawing action or closes an open popover.

**Business rule.**
- Esc is always active regardless of the keyboard-shortcuts master toggle (the single exception when shortcuts are OFF).
- If a draw tool is armed or a drawing drag/placement is in progress, Esc cancels it: the tool disarms and any incomplete drawing is abandoned (no partial drawing is committed).
- If a popover/dialog (Settings, Indicators, layout picker, order confirmation, colour picker, etc.) is open, Esc closes it.
- Esc does not delete already-committed drawings; it only cancels the in-flight action or closes the open surface.

**Acceptance criteria.**
- With a draw tool selected, pressing Esc disarms it and leaves no new drawing on the chart.
- Mid-drag of a drawing/anchor, Esc abandons the move (no half-moved state).
- With any popover open, Esc closes that popover.
- Esc works even when the keyboard-shortcuts toggle is OFF.

**Edge cases & negative scenarios.**
- With both a popover open and a tool armed, Esc resolves the topmost interaction first (the open popover).
- Esc with nothing in progress and no popover open is a harmless no-op — it must not clear drawings, deselect the symbol, or change the layout.
- Esc must not cancel an already-submitted order; it only dismisses a pending confirmation not yet confirmed.

#### CE-KEY-005 — Shortcuts disabled (toggle OFF)

**Description.** When the master toggle is OFF, none of the chart shortcuts act, so a tester typing or working elsewhere is never surprised by an accidental order or timeframe change.

**Business rule.**
- With the toggle OFF, Alt+B, Alt+S, Alt+I, and all timeframe keys (1, 5, Shift+1, H, D) are ignored by the chart.
- Esc remains active even with the toggle OFF (CE-KEY-004).
- The toggle defaults to OFF for new sessions and persists across sessions.

**Acceptance criteria.**
- With the toggle OFF, Alt+B / Alt+S create no order; Alt+I does not change Instant mode; timeframe keys do not change the timeframe.
- Esc still cancels tools and closes popovers with the toggle OFF.
- Turning the toggle ON re-enables every shortcut immediately with no page reload; turning it OFF disables them again.
- A brand-new session starts with shortcuts OFF until the tester turns them on.

**Edge cases & negative scenarios.**
- Toggling the master switch while a popover is open must not leave shortcuts in an inconsistent half-on state.
- After enabling shortcuts, placing an order via Alt+B, then disabling shortcuts, the placed order is unaffected — disabling only stops future key handling.

---

## 18. Chart Data States & Error Handling

The chart moves through several data states per pane (no symbol, loading, no data, data error, and live). Each must present a clear, non-broken surface. Cached candles are reused wherever possible so the chart degrades gracefully instead of blanking out.

#### CE-STATE-001 — No symbol selected

**Description.** Before a symbol is chosen for a pane, the pane shows a clear prompt rather than an empty or broken canvas, and controls that only make sense with a symbol are disabled.

**Business rule.**
- An empty pane displays a "Select a symbol" prompt.
- Symbol-dependent controls (buy/sell, quantity, timeframe-driven data, indicators that need candles, drawings tied to the symbol) are disabled or inert while no symbol is loaded.
- Pane-independent session controls (layout picker, theme, the keyboard-shortcuts toggle) remain usable.

**Acceptance criteria.**
- A fresh/empty pane shows the "Select a symbol" message.
- Order-entry and price-driven controls are visibly disabled or do nothing while the pane has no symbol.
- Choosing a symbol clears the prompt and begins loading data.

**Edge cases & negative scenarios.**
- In a multi-pane layout, an empty pane shows the prompt independently while sibling panes with symbols render normally.
- Price-targeting and timeframe keyboard shortcuts must not act on an empty pane.

#### CE-STATE-002 — Loading

**Description.** While candle history is being fetched, the tester sees a loading indicator but can still work with the chart's non-data controls; cached candles remain visible during the fetch.

**Business rule.**
- During a history fetch the pane shows a loading indicator.
- Previously loaded/cached candles remain on screen during the load rather than being cleared to blank.
- The tester can still adjust indicators and overlays while loading; those changes apply when data is present.

**Acceptance criteria.**
- Triggering a data load (new symbol, timeframe change, range extend) shows a loading indicator.
- If candles were already shown, they stay visible until the new data replaces them.
- Indicator/overlay toggles remain operable during the load.

**Edge cases & negative scenarios.**
- Switching symbol rapidly several times ends on the data for the last-selected symbol, not a stale earlier response.
- A long load keeps showing the loading indicator and does not collapse the pane to a broken/empty state.

#### CE-STATE-003 — No data available

**Description.** When a symbol legitimately returns no candles for the requested range/timeframe, the pane states this clearly instead of showing a blank or broken chart.

**Business rule.**
- A successful fetch yielding zero candles shows a "No data available" message.
- The pane chrome (axes, header, controls) stays intact; only the data area communicates the empty result.

**Acceptance criteria.**
- A symbol/timeframe combination with no candles shows "No data available" rather than an empty canvas.
- The message is specific to the empty-result case, not confused with an error or a still-loading state.

**Edge cases & negative scenarios.**
- A symbol with data on one timeframe but none on another shows candles on the first and "No data available" on the second after switching.
- Recovering data (e.g. switching to a populated timeframe) clears the "No data available" message automatically.

#### CE-STATE-004 — Data error

**Description.** When a history request fails, the tester sees an error/retry message rather than a broken chart, and any cached candles stay on screen so the chart remains useful while recovering.

**Business rule.**
- A failed history request surfaces an error/retry affordance.
- If the pane already had cached candles, those remain displayed alongside the error indication rather than being wiped.
- Recovery (a successful retry or the next live update) restores the normal data view without a full page reload and without losing pane settings, indicators, or drawings.

**Acceptance criteria.**
- A simulated/observed fetch failure shows an error or retry message.
- Last-known candles, if cached, remain visible during the error.
- Retrying returns the pane to normal without a full reload and without losing the pane's indicators, drawings, or settings.

**Edge cases & negative scenarios.**
- Repeated failures keep showing the error affordance and do not stack multiple overlapping banners.
- An error on one pane must not break sibling panes.
- After an error then recovery, real-time updates resume normally.

#### CE-STATE-005 — Real-time updates

**Description.** Once data is loaded, the current in-progress candle and any live overlays update continuously as ticks arrive.

**Business rule.**
- The current (incomplete) candle updates live as price ticks arrive.
- Live-driven overlays and chips (e.g. the last-price chip, and, where enabled, the bar-close countdown) update with the stream.
- Live updates apply to the symbol currently loaded in each subscribed pane.

**Acceptance criteria.**
- With a live symbol loaded, the forming candle's high/low/close move as ticks arrive without manual refresh.
- The last-price chip reflects the live price; where the countdown is enabled, it counts toward the next bar.
- When a bar completes, a new forming candle begins and history stays consistent.

**Edge cases & negative scenarios.**
- After a data error and recovery, live ticks resume updating the forming candle.
- Multiple panes on different symbols each update from their own live stream independently.
- A pane with no symbol receives no live updates and stays on its "Select a symbol" prompt.

#### CE-STATE-006 — Modal blocking over the chart

**Description.** When a dialog or popover is shown over the chart, clicks on that surface must be captured by it and must NOT pass through to the chart underneath.

**Business rule.**
- Any dialog/popover layered over the chart (order confirmation, Settings, Indicators, layout picker, colour pickers, the Instant warning) must intercept pointer events; clicks on the modal/popover surface do not reach the chart.
- Clicks on the chart behind a blocking modal must not place orders, move drawings, move the crosshair, or otherwise mutate chart state.
- When the dialog/popover closes, normal chart interaction resumes immediately.

**Acceptance criteria.**
- With a confirmation dialog open, clicking its buttons/area affects only the dialog; the chart behind does not react.
- Clicking the chart region covered by a blocking modal does nothing to the chart.
- After dismissing the dialog, the chart responds to clicks/hover again.

**Edge cases & negative scenarios.**
- A lingering chart frame must not make an overlying dialog feel unresponsive — clicks must land on the dialog.
- Non-blocking popovers that close on outside-click are distinct from blocking dialogs: an outside click on the chart closes such a popover; it must not simultaneously trigger a chart action like placing an order.

---

## 19. Theme, Persistence & Cross-Cutting Behaviour

These requirements span the whole chart engine rather than a single control.

#### CE-X-001 — Theme support (light & dark)

**Description.** The chart engine supports both light and dark themes, and every part of it — chart canvas, top bar, popovers, panels, swatches — must be legible and correctly themed in each.

**Business rule.**
- The chart follows the app's light/dark theme. When the app theme changes, the chart re-themes to match.
- Both themes must provide adequate contrast on every control, popover, panel, and chart element (candles, gridlines, axes, crosshair chips, indicator lines, drawings, messages).
- No control, label, popover, or panel may become unreadable in either theme.

**Acceptance criteria.**
- Switching the app between light and dark re-themes the chart and all its surfaces without a reload.
- In both themes, every top-bar control, popover, settings panel, swatch, and message is readable with adequate contrast.
- Chart elements (candles up/down, gridlines, crosshair chips, indicators, drawings) remain distinguishable in both themes.

**Edge cases & negative scenarios.**
- Theme switching while a popover is open re-themes the open popover too.
- Custom palette colours the user has set (CE-X-003) must remain visible against both theme backgrounds; a colour that vanishes against one theme's background is a defect to flag.
- The read-only "explain"/lite chart view must also honour the current theme.

#### CE-X-002 — Popover containment

**Description.** Popovers and dropdowns stay fully on screen and close predictably on an outside click or Esc.

**Business rule.**
- Every popover/dropdown (Settings, Indicators, layout picker, timeframe/style menus, colour pickers, symbol typeahead, order popovers) must render fully within the visible screen area, repositioning as needed near edges.
- A non-blocking popover closes on a click outside it and on Esc.
- An outside click that closes a popover must not also perform an unrelated chart action at the click point (consistent with CE-STATE-006).

**Acceptance criteria.**
- Opening a popover near a screen edge keeps it fully visible (not clipped or off-screen).
- Clicking outside an open popover closes it; pressing Esc closes it.
- Closing via outside-click does not, in the same gesture, place an order or move a drawing.

**Edge cases & negative scenarios.**
- A popover opened in a small/compact pane in a busy multi-pane layout still stays within the viewport.
- Opening a second popover should not leave the first stranded open behind it.
- Resizing the window with a popover open must not push it off-screen or detach it from its anchor.

#### CE-X-003 — Persistence across sessions

**Description.** The chart engine remembers the tester's setup so reopening the chart restores the prior state.

**Business rule.**
- Remembered across sessions: the selected layout and pane arrangement/sizes; per-pane symbol, timeframe, chart style, overlays, and quantity; colour/palette customizations; per-pane indicators (kind, period/parameters, colour, thickness, hidden state); drawings stored per symbol; the global drawing lock/hide flags; order defaults (SL/TP, per-family default quantities, product types); the keyboard-shortcuts toggle; the Instant-orders flag; and the one-time Instant-warning acknowledgement.
- The currently-armed draw tool is intentionally NOT remembered — it resets to "no tool" on reload.
- A corrupted or unreadable saved state must not break the chart; it falls back to sensible defaults.
- Invalid stored values are coerced to safe defaults (an unsupported chart style falls back to candles; an out-of-range active pane is clamped; an unknown pivot variant falls back to classical).
- Order defaults are stored separately from the larger session data, so nudging a default does not disturb panes/drawings/indicators.

**Acceptance criteria.**
- Set up a layout with symbols, timeframes, indicators, drawings, custom colours, and order defaults, then reload — all of it returns as configured.
- Drawings made on symbol A appear when symbol A is loaded and not on symbol B; switching back to A shows A's drawings again.
- The Instant warning appears only the first time Instant is enabled; after acknowledgement it never reappears in later sessions.
- A reload starts with no draw tool armed even if one was armed before.

**Edge cases & negative scenarios.**
- Manually corrupting the saved state must not brick the chart — it loads defaults instead.
- An old saved state using a now-unsupported chart style loads as candles rather than failing.
- Changing the layout to fewer panes keeps the active pane and a sensible subset; changing to more panes fills the new panes without losing existing ones.
- A persisted derivative pane whose quantity was wrongly stored as a sub-lot value is healed to the correct lot-multiplied quantity on restore.

#### CE-X-004 — Hover feedback

**Description.** Interactive elements give clear hover feedback (a hover state plus a pointer cursor) so the tester can see what is clickable.

**Business rule.**
- Rows (lists, indicator rows, symbol suggestions), buttons, and colour swatches show a visible hover state when the pointer is over them.
- Clickable elements show a pointer cursor on hover; non-interactive text does not.

**Acceptance criteria.**
- Hovering list rows, buttons, and swatches produces a visible change (highlight/shade) and a pointer cursor.
- The hover state clears when the pointer leaves the element.
- Hover affordances are present and legible in both light and dark themes.

**Edge cases & negative scenarios.**
- Disabled controls (e.g. order controls with no symbol) should not present a clickable pointer cursor or a misleading hover state.
- Hover feedback must work for elements inside popovers, not just the main top bar.

#### CE-X-005 — Active-pane consistency

**Description.** In multi-pane layouts, the top bar and the View/Settings toggles always reflect the active pane, and switching the active pane re-points all of them.

**Business rule.**
- The top bar's per-pane controls (Timeframe, chart Style, cursor/crosshair-lines, indicators, symbol name) reflect the active pane's current values.
- The View-on-chart toggles in Settings (key levels, OI bars, bar countdown, high/low markers, volume profile, auto-pattern, magnet, pivot variant, crosshair lines, etc.) reflect the active pane's state.
- Switching the active pane updates the top bar and all these toggles to the newly active pane's values, and subsequent edits apply to that pane.

**Acceptance criteria.**
- With two panes on different timeframes/styles, clicking each pane updates the top bar's Timeframe and Style to that pane's values.
- The Settings View toggles show the active pane's on/off states and change which pane they affect when the active pane changes.
- Editing a control after switching panes changes only the now-active pane.

**Edge cases & negative scenarios.**
- Keyboard timeframe shortcuts must act on the same pane the top bar reflects — no mismatch between the "active" pane shown and the pane the keys change.
- After a layout change that reduces pane count, the active-pane indicator and the top bar agree on which pane is now active (no stale reference to a removed pane).
- Switching panes while a per-pane popover (e.g. Indicators) is open must either retarget cleanly to the new active pane or close, never silently keep editing the old pane.

---

*End of Document*
