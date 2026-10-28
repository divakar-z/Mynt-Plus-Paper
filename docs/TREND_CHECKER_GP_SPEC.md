# Trend Checker by GP / Future Trend Checker by GP — observed behaviour

Both TradingView scripts are closed-source (author: the client, Gajapriya).
Everything below was read off the live scripts on TradingView on 27 Oct 2026
(NIFTY 50, NSE) — inputs, Data Window values, tags and tables — and checked
by hand. Values marked **assumed** were not observable.

## Shared maths

- Pivot P = (H+L+C)/3, BC = (H+L)/2, TC = 2P − BC (not swapped; BC can be
  above TC). R1 = 2P−L, S1 = 2P−H, R2/S2 = P ± (H−L), R3 = R1+(H−L),
  S3 = S1−(H−L), **R4 = 2·R3 − R2, S4 = 2·S3 − S2**.
- H/L/C are the official daily bars (NIFTY 27 Oct: C = 22,749.75 official
  close, not the last 5m close 22,762.00).
- CPR width % = |TC − BC| / P × 100.
- Width class (≤ thresholds, else Wide):

  | TF | Ultra Narrow ≤ | Narrow ≤ | Medium ≤ |
  |---|---|---|---|
  | Daily | 0.05 | 0.1 | 0.2 |
  | Weekly | 0.125 | 0.25 | 0.5 |
  | Monthly | 0.25 | 0.5 | 1 |

- Relationship of a CPR to the one before it (top = max(BC,TC), bot = min):
  - Ascending: bot > prev top
  - Descending: top < prev bot
  - Outside: top > prev top and bot < prev bot
  - Inside: top < prev top and bot > prev bot
  - Overlapping Higher / Lower: otherwise, by direction (pivot up / down)
- ATR phase: ratio = TRUE RANGE of the reference period / average true range
  of the last 14 periods of the same TF (true range = max(H−L, |H−prevC|,
  |L−prevC|) — the Data Window's "Prev day range" is this: 5 Oct shows 403.15
  where H−L is 393.30, = 22,620.45 (30 Sep close) − 22,217.30).
  Contraction < 0.7, Expansion > 1.3, else Normal. Averaging Simple (SMA) or
  Wilder (RMA). Ratio text uses Pine "#.##" → ".58x", "1.09x".

## Trend Checker by GP (update)

Inputs (new in **bold**), defaults:
- CPR Settings: Auto Select (off), Daily CPR (on), PDH/PDL (on), Weekly
  (off), PWH/PWL (off), Monthly (off), PMH/PML (off). Yearly removed.
- **CPR Summary (right edge)**: "Show CPR summary under the pivot label"
  (on) → lines under "Daily CPR": "Wide CPR", "ATR Normal", "Outside CPR".
- **Backtest Tags**: show tag at start of each period (off), add CPR width
  (on), add ATR phase (on), Tag position Auto (free space) / Above CPR /
  Below CPR, Tag style Full / Compact.
  - Full: "▼ Descending CPR · Wide" / "ATR Normal"
  - Compact: "▼ DESC · Wide · ATR •" (ATR ↑ expansion, ↓ contraction,
    • normal)
  - Symbols: ▲ Ascending (ASC), ▼ Descending (DESC), △ Overlapping Higher
    (OL Higher), ▽ Overlapping Lower (OL Lower), ⊙ Outside, ◆ Inside.
- **Virgin CPR**: "Show Virgin CPR zone (extends one period)" (on), zone text
  "Virgin CPR". A period's CPR is virgin when that period's price never
  traded inside [bot, top]; the box is drawn across the NEXT period.
- **ATR Phase**: length 14, averaging Simple (SMA) / Wilder (RMA), "Include
  yesterday in the 14-day average" (on), Contraction below 0.7, Expansion
  above 1.3. Reference range = previous period (yesterday for daily).
  Data Window plots: "ATR check · Prev day range", "ATR check · 14-day
  average", "ATR check · Ratio".
  - Verified 27 Oct: 365.85 / 336.43 = 1.09 (avg of the 14 daily ranges
    ending 26 Oct incl.). 13 daily tags 9–27 Oct all match.
- **Market Pulse panel**: show (on), position Top Right / Top Left / Bottom
  Right / Bottom Left / Middle Right, text size Tiny / Small / Normal, panel
  background (white), text (black), columns CPR Type / Width / ATR Phase /
  Read (all on). One row per enabled TF (Daily/Weekly/Monthly).
  - Columns: TF | CPR Type | Width | ATR Phase | [Virgin CPR] | Read.
    Virgin CPR column appears only when some row has a live zone
    ("✓ Zone live", else "—").
  - CPR Type cell: "⊙ Outside", "▽ OL Lower", "▼ DESC" (and ▲ ASC,
    △ OL Higher, ◆ Inside) — solid colour, white text.
  - Width cell: "Wide 0.539%" (3 dp daily, 2 dp weekly/monthly as seen).
  - ATR cell: "• Normal 1.09x", "↑ Expansion 1.41x", "↓ Contraction
    1.15x · 5 months" (streak of consecutive contraction periods, shown when
    ≥ 2 — **assumed** threshold).
  - Read (width × ATR):

    | | Contraction | Normal | Expansion |
    |---|---|---|---|
    | Ultra Narrow | Strong Compression | Breakout watch | Stretched |
    | Narrow | Strong Compression | Breakout watch | Stretched |
    | Medium | Compressed | Balanced - follow price | Stretched |
    | Wide | Compressed | Range day likely | Overstretched |

- **CPR Width (% of pivot)** thresholds per TF (table above), editable.
- Moving Averages: MA #1–5 now default **off**; colours #F6C309, #157A11,
  #FC1A1A, #160101, #0C7DF6.
- PDH/PDL (and PWH/PWL, PMH/PML) now drawn **black**.

Verified 27 Oct NIFTY: Daily Outside · Wide 0.539% · Normal 1.09x · Range
day likely; Weekly OL Lower · Wide 0.51% · Expansion 1.41x · Overstretched;
Monthly DESC · Wide 2.123% · Normal 1.15x · Zone live · Range day likely.

## Future Trend Checker by GP (new)

Projects NEXT period's CPR from the CURRENT period's H/L/C (live while the
period trades), drawn on the next trading date (weekends + NSE holiday list
skipped), plus today's levels as plots.

Inputs:
- CPR Levels: Mode Auto / Manual; "Auto: show previous high / low" (on);
  Manual: Day CPR (on), PDH/PDL (on), Week CPR (off), PWH/PWL (off), Month
  CPR (off), PMH/PML (off). Auto = Day on intraday (Week on 1D, Month on 1W+
  **assumed** like Trend Checker).
- Today's CPR dot thickness 2, Next CPR dot thickness 2.
- Next CPR placement: draw on its next trading date (on), show level names
  and prices (on), NSE trading holidays list (2026-01-15, 2026-01-26,
  2026-03-03, 2026-03-26, 2026-03-31, 2026-04-03, 2026-04-14, 2026-05-01,
  2026-05-28, 2026-06-26, 2026-09-14, 2026-10-02, 2026-10-20, 2026-11-10,
  2026-11-24, 2026-12-25).
- Trend Table: show (on), position Top Right, text Small, show % values (on).
- ATR Phase: 14, SMA/RMA, "Include the latest period in the average" (on),
  0.7 / 1.3. Ratio = current period range / avg incl. current.
- Per TF: width thresholds (as above), CPR → Zone Narrow ≤ / Normal ≤
  (D 0.3/0.5, W 0.7/1, M 2/3), R1↔PDH / S1↔PDL Narrow ≤ / Normal ≤
  (D 0.1/0.3, W 0.25/0.5, M 0.5/1).

Next-period labels (right of the projection): "D R4 23135.55" … "PDH
22829.75", "D CPR 22738.80 · Next Day · 28 Oct", "PDL 22636.85" … (prices
rounded to tick). PDH/PDL = the current period's high/low.

Trend table ("Next CPR" | Day | Week | Month):
- CPR Width: class + % of next CPR.
- CPR → R1/PDH: (max(R1, PDH) − top) / P %, class by CPR→Zone thresholds.
- CPR → S1/PDL: (bot − min(S1, PDL)) / P %.
- R1 ↔ PDH, S1 ↔ PDL: |R1 − PDH| / P %, |S1 − PDL| / P %.
- Relationship (next vs current CPR): Ascending, Descending, Overlap Higher,
  Overlap Lower, Inside, Outside.
- Bias: Ascending → Bullish, Overlap Higher → Mild Bullish, Descending →
  Bearish, Overlap Lower → Mild Bearish, Outside → Sideways, Inside →
  "Compression (wait for breakout)".
- ATR Phase: "↓ Contraction .58x".

Verified 27 Oct NIFTY (H 22829.75, L 22636.85, C 22749.75): next CPR
22738.80, R4 23135.55, R3 23033.60, R2 22931.70, S2 22545.90, S3 22454.90,
S4 22363.95; width 0.05% Ultra Narrow; CPR→zone 0.42% Normal; R1↔PDH 0.05%
Narrow; Ascending / Bullish; Contraction .58x (192.90 / 334.47).
