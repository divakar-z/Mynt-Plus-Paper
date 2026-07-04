# Chart Engine — Phase 13 Design

**Date:** 2026-05-25
**Builds on:** Phases 1-12
**Scope summary:** Visually group all overlays (position + open orders + alerts) that belong to the same `exch+token` (i.e., the same scrip the pane is showing) by drawing a thin vertical "bracket bar" on the right edge of the plot, just inside the gutter, that spans from the lowest paired chip y to the highest. Each scrip's group also gets a tiny "leg" connecting individual chips to the bar. This makes it obvious at a glance which lines belong together when several orders + a position coexist for the same instrument.

---

## 1. Goal

For each pane, collect every overlay that's actually on-screen (positions, LMT orders, SL trigger lines, SL-LMT pairs, alerts) and group them by `overlay.id`'s scrip family. Since the chart is per-scrip, every overlay in a pane belongs to the same scrip — so the grouping reduces to "all non-empty overlays in this pane".

When ≥2 overlays are present:
- Draw a thin vertical **bracket bar** in the right gutter (just inside `plot.right`), spanning from `minY` to `maxY` of the grouped chips.
- Draw a small horizontal **leg** from each chip's right edge to the bracket bar.
- Color: muted (axisText). Width: 1px. Length: 8px gutter inset.

Effect: at a glance the user sees "these N order/position/alert lines are for the same scrip and form a logical group."

This is a pure visual cue — no new state, no new bridge messages, no behavior changes.

---

## 2. Visual

```
... candles ...   [chip 1 — long position] ─┐
                                              │
... candles ...   [chip 2 — sell LMT]     ─┤  ← bracket bar in gutter
                                              │
... candles ...   [chip 3 — SL trigger]  ─┘
```

- Bar `x = plot.right + 70` (inside the gutter, beyond the gutter price chips at `plot.right + 2..+66`).
- Bar `y = [minChipY .. maxChipY]`.
- Leg: short horizontal line at each chip's `chipY`, from chip's right edge to the bar.
- Color: `palette.axisText` (muted, theme-aware).
- Hidden when fewer than 2 overlays are on-screen.

---

## 3. Architecture

Pure render-side change in `chart.js`:

- Inside `_drawOverlays`, after the per-overlay loop completes (when all chip positions are known), compute:
  - `overlayChipYs = placements.filter(p => p.onScreen).map(p => p.chipY)` — but actually we also want off-screen carets; include all `chipY`s.
  - If `overlayChipYs.length >= 2`, draw the bracket bar + legs.
- One new method `_drawGroupBracket(plot, chipYs, chipRights)`.

No store / Flutter / bridge changes.

---

## 4. Edge cases

| Case | Behaviour |
|---|---|
| 0 or 1 overlay | No bracket drawn |
| All overlays at same y | Bracket degenerate (no height); skip |
| Off-screen overlay with caret at top/bottom edge | Include in bracket span |
| Theme toggle | Color from palette updates automatically |
| Phase 12 alert chips | Treated identically — bracket spans them too |
| Multi-pane same symbol | Each pane draws its own bracket independently |

---

## 5. Files

| Path | What |
|---|---|
| `web/chart-engine/chart.js` | `_drawOverlays` collects chip y-positions; new private method `_drawGroupBracket(plot, ys)`. |

No new files. No bridge / Flutter / store changes.

---

## 6. Acceptance smoke

1. Open `/charts` on a symbol with 1 position + 1 LMT order + 1 alert → bracket bar visible in the gutter spanning all three chip y's; each chip has a tiny leg connecting to the bar.
2. Single overlay → no bracket.
3. Add a second LMT order at a different price → bracket extends to include it.
4. Cancel one order → bracket shrinks.
5. Different pane with different symbol → its own bracket independent.
6. Theme toggle → bracket color updates.

If everything passes, Phase 13 is done.

---

## 7. Out of scope (Phase 13.1+)

- Per-bracket-instance highlight on hover
- Bracket labels ("Group A", "OCO")
- True BO/CO parent detection from order data
- Cancel-all-in-group action
