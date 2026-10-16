/// Schema-driven parameter definitions for each indicator kind. The settings
/// dialog reads [schemaFor] to know which numeric rows to render; chart.js
/// reads the same values back through `IndicatorConfig.params`.
///
/// Kinds not in the registry fall back to the single-`period` row from the
/// generic dialog (governed by `_kKindsWithPeriod` in the shell screen).
/// One choice in a dropdown (enum) param. The value persisted in
/// `IndicatorConfig.params` is the option's INDEX in [IndicatorParam.options]
/// — kept numeric so the params map stays `Map<String, num>`. The engine maps
/// the same index order back to a behavior, so keep option order in sync with
/// the matching tables in `chart-indicators.js` / `chart-overlays.js`.
class IndicatorOption {
  final String label;
  const IndicatorOption(this.label);
}

class IndicatorParam {
  /// Map key inside `IndicatorConfig.params`.
  final String key;
  /// Short label shown next to the control.
  final String label;
  /// One-line caption below the label.
  final String description;
  /// Default stored value. For enum params this is the default option index;
  /// for bool params it is 0 or 1.
  final num defaultValue;
  final num min;
  final num max;
  /// Step size — 1 for integer params, fractional (e.g. 0.1) for floats.
  final num step;
  /// Forces integer storage when true; floats round-trip as `double`.
  final bool isInt;
  /// Non-null => render a dropdown; the stored value is the selected index.
  final List<IndicatorOption>? options;
  /// True => render a switch; the stored value is 0 or 1.
  final bool isBool;
  const IndicatorParam({
    required this.key,
    required this.label,
    required this.description,
    required this.defaultValue,
    this.min = 0,
    this.max = 0,
    this.step = 1,
    this.isInt = true,
    this.options,
    this.isBool = false,
  });
  /// True when this param should render as a dropdown.
  bool get isEnum => options != null;
}

class IndicatorSchema {
  final String kind;
  final String displayName;
  final String shortDescription;
  final List<IndicatorParam> params;
  /// Schema key that the pre-schema `IndicatorConfig.period` should map to
  /// when hydrating a legacy persisted indicator that has no `params`. Lets
  /// users keep their custom period when BB used `period: 50` (now `length`).
  /// `null` means "ignore legacy period; just use schema defaults".
  final String? legacyPeriodKey;
  const IndicatorSchema({
    required this.kind,
    required this.displayName,
    required this.shortDescription,
    required this.params,
    this.legacyPeriodKey,
  });
}

/// Returns the schema for [kind] (case-insensitive), or `null` if it isn't
/// in the registry. Callers should fall back to the legacy single-`period`
/// row when null.
IndicatorSchema? schemaFor(String kind) {
  final k = kind.toLowerCase();
  if (k == 'cpr') return _kCprSchema;
  if (k == 'tcheck') return _kTcSchema;
  return _kSchemas[k];
}

const Map<String, IndicatorSchema> _kSchemas = {
  // ── Single-period overlays / oscillators ────────────────────────────────
  'sma': IndicatorSchema(
    kind: 'sma',
    displayName: 'Simple Moving Average',
    shortDescription: 'Arithmetic mean of close over the period.',
    params: [
      IndicatorParam(
        key: 'period', label: 'Period',
        description: 'Number of bars to average',
        defaultValue: 20, min: 1, max: 999,
      ),
    ],
  ),
  'ema': IndicatorSchema(
    kind: 'ema',
    displayName: 'Exponential Moving Average',
    shortDescription: 'EMA — weights recent bars more heavily.',
    params: [
      IndicatorParam(
        key: 'period', label: 'Period',
        description: 'Number of bars to average',
        defaultValue: 20, min: 1, max: 999,
      ),
    ],
  ),
  'zlema': IndicatorSchema(
    kind: 'zlema',
    displayName: 'Zero-Lag EMA',
    shortDescription: 'EMA with the lag mathematically subtracted out.',
    params: [
      IndicatorParam(
        key: 'period', label: 'Period',
        description: 'Number of bars to average',
        defaultValue: 20, min: 1, max: 999,
      ),
    ],
  ),
  'mcginley': IndicatorSchema(
    kind: 'mcginley',
    displayName: 'McGinley Dynamic',
    shortDescription: 'Adaptive MA that speeds up in trends, slows in chop.',
    params: [
      IndicatorParam(
        key: 'period', label: 'Period',
        description: 'Number of bars to average',
        defaultValue: 14, min: 1, max: 999,
      ),
    ],
  ),
  // RSI gains a Source selector + an optional smoothing MA line (the
  // "SMA-based RSI" users asked for). Enum option order MUST match the tables
  // in chart-indicators.js: RSI_SOURCES and RSI_SMOOTHINGS.
  'rsi': IndicatorSchema(
    kind: 'rsi',
    displayName: 'Relative Strength Index',
    shortDescription: 'Bounded 0-100 momentum oscillator.',
    params: [
      IndicatorParam(
        key: 'period', label: 'Period',
        description: 'Lookback length for the oscillator',
        defaultValue: 14, min: 2, max: 200,
      ),
      IndicatorParam(
        key: 'source', label: 'Source',
        description: 'Price series the RSI is computed on',
        defaultValue: 0,
        options: [
          IndicatorOption('Close'), IndicatorOption('Open'),
          IndicatorOption('High'), IndicatorOption('Low'),
          IndicatorOption('HL2'), IndicatorOption('HLC3'),
          IndicatorOption('OHLC4'),
        ],
      ),
      IndicatorParam(
        key: 'smoothingType', label: 'Smoothing',
        description: 'Moving average drawn over the RSI',
        defaultValue: 1, // SMA
        options: [
          IndicatorOption('None'), IndicatorOption('SMA'),
          IndicatorOption('SMA + Bollinger Bands'), IndicatorOption('EMA'),
          IndicatorOption('SMMA (RMA)'), IndicatorOption('WMA'),
          IndicatorOption('VWMA'),
        ],
      ),
      IndicatorParam(
        key: 'smoothingLength', label: 'Smoothing Length',
        description: 'Length of the smoothing moving average',
        defaultValue: 14, min: 1, max: 200,
      ),
      IndicatorParam(
        key: 'bbStdDev', label: 'BB StdDev',
        description: 'Std-dev multiplier (SMA + Bollinger Bands only)',
        defaultValue: 2, min: 0.5, max: 5, step: 0.1, isInt: false,
      ),
    ],
  ),
  'atr': IndicatorSchema(
    kind: 'atr',
    displayName: 'Average True Range',
    shortDescription: "Wilder's true-range smoothing — volatility gauge.",
    params: [
      IndicatorParam(
        key: 'period', label: 'Period',
        description: 'True-range averaging period',
        defaultValue: 14, min: 2, max: 200,
      ),
    ],
  ),
  'mfi': IndicatorSchema(
    kind: 'mfi',
    displayName: 'Money Flow Index',
    shortDescription: 'Volume-weighted RSI — 0-100 bounded.',
    params: [
      IndicatorParam(
        key: 'period', label: 'Period',
        description: 'Lookback period in bars',
        defaultValue: 14, min: 2, max: 200,
      ),
    ],
  ),
  'cmf': IndicatorSchema(
    kind: 'cmf',
    displayName: 'Chaikin Money Flow',
    shortDescription: 'Signed CLV-weighted volume sum, -1..+1 bounded.',
    params: [
      IndicatorParam(
        key: 'period', label: 'Period',
        description: 'Lookback period in bars',
        defaultValue: 20, min: 2, max: 200,
      ),
    ],
  ),
  'wr': IndicatorSchema(
    kind: 'wr',
    displayName: 'Williams %R',
    shortDescription: '-100..0 bounded mean-reversion oscillator.',
    params: [
      IndicatorParam(
        key: 'period', label: 'Period',
        description: 'Lookback period in bars',
        defaultValue: 14, min: 2, max: 200,
      ),
    ],
  ),
  'efi': IndicatorSchema(
    kind: 'efi',
    displayName: "Elder's Force Index",
    shortDescription: 'EMA-smoothed (close-change × volume).',
    params: [
      IndicatorParam(
        key: 'period', label: 'Period',
        description: 'EMA smoothing length',
        defaultValue: 13, min: 2, max: 200,
      ),
    ],
  ),

  // ── No-param kinds: color + thickness only ──────────────────────────────
  'vwap': IndicatorSchema(
    kind: 'vwap',
    displayName: 'Volume-Weighted Average Price',
    shortDescription: 'Session-anchored typical-price VWAP.',
    params: [],
  ),
  'obv': IndicatorSchema(
    kind: 'obv',
    displayName: 'On-Balance Volume',
    shortDescription: 'Cumulative signed volume.',
    params: [],
  ),
  'ao': IndicatorSchema(
    kind: 'ao',
    displayName: 'Awesome Oscillator',
    shortDescription: 'SMA(median,5) − SMA(median,34) histogram.',
    params: [],
  ),
  'ribbon': IndicatorSchema(
    kind: 'ribbon',
    displayName: 'Moving Average Ribbon',
    shortDescription: '8 EMAs at 5/10/20/30/40/50/60/80 (fixed).',
    params: [],
  ),

  // ── Multi-param kinds ───────────────────────────────────────────────────
  'bb': IndicatorSchema(
    kind: 'bb',
    displayName: 'Bollinger Bands',
    shortDescription: 'SMA wrapped by ±N standard deviations.',
    legacyPeriodKey: 'length',
    params: [
      IndicatorParam(
        key: 'length', label: 'Length',
        description: 'SMA length the bands wrap',
        defaultValue: 20, min: 2, max: 200,
      ),
      IndicatorParam(
        key: 'mult', label: 'Std-dev multiplier',
        description: 'Band width as N standard deviations',
        defaultValue: 2, min: 0.5, max: 5, step: 0.1, isInt: false,
      ),
    ],
  ),
  'macd': IndicatorSchema(
    kind: 'macd',
    displayName: 'MACD',
    shortDescription: 'EMA(fast) − EMA(slow), signal-EMA(signal).',
    params: [
      IndicatorParam(
        key: 'fast', label: 'Fast EMA',
        description: 'Short-period EMA length',
        defaultValue: 12, min: 2, max: 50,
      ),
      IndicatorParam(
        key: 'slow', label: 'Slow EMA',
        description: 'Long-period EMA length',
        defaultValue: 26, min: 2, max: 200,
      ),
      IndicatorParam(
        key: 'signal', label: 'Signal',
        description: 'EMA of the MACD line',
        defaultValue: 9, min: 2, max: 50,
      ),
    ],
  ),
  'stoch': IndicatorSchema(
    kind: 'stoch',
    displayName: 'Stochastic Oscillator',
    shortDescription: '%K and SMA-smoothed %D, 0-100 bounded.',
    legacyPeriodKey: 'kPeriod',
    params: [
      IndicatorParam(
        key: 'kPeriod', label: '%K Length',
        description: 'Lookback window for raw %K',
        defaultValue: 14, min: 2, max: 200,
      ),
      IndicatorParam(
        key: 'dPeriod', label: '%D Length',
        description: 'SMA length for the %D line',
        defaultValue: 3, min: 2, max: 50,
      ),
      IndicatorParam(
        key: 'smooth', label: 'Smoothing',
        description: 'Initial %K smoothing window',
        defaultValue: 3, min: 1, max: 20,
      ),
    ],
  ),
  'stochrsi': IndicatorSchema(
    kind: 'stochrsi',
    displayName: 'Stochastic RSI',
    shortDescription: 'Stochastic of the RSI series.',
    legacyPeriodKey: 'rsiLength',
    params: [
      IndicatorParam(
        key: 'rsiLength', label: 'RSI Length',
        description: 'Lookback for the underlying RSI',
        defaultValue: 14, min: 2, max: 200,
      ),
      IndicatorParam(
        key: 'stochLength', label: 'Stoch Length',
        description: 'Window for the stoch transform',
        defaultValue: 14, min: 2, max: 200,
      ),
      IndicatorParam(
        key: 'kPeriod', label: '%K Smoothing',
        description: 'SMA length applied to raw %K',
        defaultValue: 3, min: 1, max: 20,
      ),
      IndicatorParam(
        key: 'dPeriod', label: '%D Smoothing',
        description: 'SMA length for the %D line',
        defaultValue: 3, min: 1, max: 20,
      ),
    ],
  ),
  'squeeze': IndicatorSchema(
    kind: 'squeeze',
    displayName: 'Squeeze Momentum',
    shortDescription: 'Bollinger inside Keltner — squeeze + release.',
    legacyPeriodKey: 'bbLength',
    params: [
      IndicatorParam(
        key: 'bbLength', label: 'BB Length',
        description: 'Bollinger SMA length',
        defaultValue: 20, min: 2, max: 200,
      ),
      IndicatorParam(
        key: 'bbMult', label: 'BB Multiplier',
        description: 'Bollinger std-dev multiplier',
        defaultValue: 2, min: 0.5, max: 5, step: 0.1, isInt: false,
      ),
      IndicatorParam(
        key: 'kcLength', label: 'KC Length',
        description: 'Keltner channel length',
        defaultValue: 20, min: 2, max: 200,
      ),
      IndicatorParam(
        key: 'kcMult', label: 'KC Multiplier',
        description: 'Keltner ATR multiplier',
        defaultValue: 1.5, min: 0.5, max: 5, step: 0.1, isInt: false,
      ),
    ],
  ),
  'ichi': IndicatorSchema(
    kind: 'ichi',
    displayName: 'Ichimoku Cloud',
    shortDescription: 'Tenkan/Kijun + Senkou A/B cloud + Chikou span.',
    params: [
      IndicatorParam(
        key: 'tenkan', label: 'Tenkan',
        description: 'Conversion line length',
        defaultValue: 9, min: 2, max: 200,
      ),
      IndicatorParam(
        key: 'kijun', label: 'Kijun',
        description: 'Base line length',
        defaultValue: 26, min: 2, max: 200,
      ),
      IndicatorParam(
        key: 'senkouB', label: 'Senkou B',
        description: 'Leading span B lookback',
        defaultValue: 52, min: 2, max: 400,
      ),
      IndicatorParam(
        key: 'displacement', label: 'Displacement',
        description: 'Forward shift for cloud and Chikou',
        defaultValue: 26, min: 1, max: 200,
      ),
    ],
  ),
  'wt': IndicatorSchema(
    kind: 'wt',
    displayName: 'WaveTrend Oscillator',
    shortDescription: 'LazyBear WaveTrend — wt1 + wt2.',
    legacyPeriodKey: 'channelLength',
    params: [
      IndicatorParam(
        key: 'channelLength', label: 'Channel Length',
        description: 'EMA length for ESA and dispersion',
        defaultValue: 10, min: 2, max: 50,
      ),
      IndicatorParam(
        key: 'averageLength', label: 'Average Length',
        description: 'EMA length for wt1',
        defaultValue: 21, min: 2, max: 50,
      ),
    ],
  ),
  'crsi': IndicatorSchema(
    kind: 'crsi',
    displayName: 'Connors RSI',
    shortDescription: 'Mean of RSI(close), RSI(streak), PercentRank(roc).',
    legacyPeriodKey: 'rsiLength',
    params: [
      IndicatorParam(
        key: 'rsiLength', label: 'RSI Length',
        description: 'Length for the close-RSI leg',
        defaultValue: 3, min: 2, max: 50,
      ),
      IndicatorParam(
        key: 'streakLength', label: 'Streak Length',
        description: 'Length for the streak-RSI leg',
        defaultValue: 2, min: 2, max: 50,
      ),
      IndicatorParam(
        key: 'rocLength', label: 'ROC Window',
        description: 'PercentRank window for the ROC leg',
        defaultValue: 100, min: 2, max: 400,
      ),
    ],
  ),
  'vstop': IndicatorSchema(
    kind: 'vstop',
    displayName: 'Volatility Stop',
    shortDescription: 'ATR-based trailing stop, flips on close-cross.',
    legacyPeriodKey: 'length',
    params: [
      IndicatorParam(
        key: 'length', label: 'ATR Length',
        description: 'ATR averaging period',
        defaultValue: 14, min: 2, max: 200,
      ),
      IndicatorParam(
        key: 'multiplier', label: 'ATR Multiplier',
        description: 'Distance from price as ATR multiples',
        defaultValue: 2.0, min: 0.5, max: 10, step: 0.1, isInt: false,
      ),
    ],
  ),
  // ICT/SMC Change in State of Delivery — mode toggle encoded as 0/1 int
  // because the schema doesn't yet support enum field kinds. 1 = strict
  // (pivot + body-ratio filter, emits ▲/▼ markers), 0 = permissive (every
  // CISD drawn as a line). Defaults sourced from EmpArchitect's TradingView
  // CISD Detector + FibAlgo ICT Displacement (the two most-used community
  // implementations) — see docs/superpowers/specs/2026-05-30-cisd-indicator-design.md.
  'cisd': IndicatorSchema(
    kind: 'cisd',
    displayName: 'Change in State of Delivery',
    shortDescription: 'ICT/SMC body-close shift through opposing leg open.',
    params: [
      IndicatorParam(
        key: 'strictMode', label: 'Strict mode',
        description: '1 = filter by swing pivot + body ratio (markers). '
                     '0 = mark every state change.',
        defaultValue: 1, min: 0, max: 1,
      ),
      IndicatorParam(
        key: 'pivotWidth', label: 'Pivot width',
        description: 'Bars each side of a swing pivot (strict only).',
        defaultValue: 2, min: 1, max: 10,
      ),
      IndicatorParam(
        key: 'minBodyRatio', label: 'Min body ratio',
        description: 'Displacement filter: body / (high − low).',
        defaultValue: 0.65, min: 0.10, max: 0.95, step: 0.05, isInt: false,
      ),
      IndicatorParam(
        key: 'expiryBars', label: 'Level lifetime',
        description: 'Bars a CISD line lives before auto-expiring.',
        defaultValue: 50, min: 5, max: 500,
      ),
      IndicatorParam(
        key: 'maxLines', label: 'Max visible lines',
        description: 'Oldest lines are pruned when this is exceeded.',
        defaultValue: 10, min: 1, max: 50,
      ),
    ],
  ),
  // ICT Fair Value Gap — 3-candle imbalance zone. strictMode encoded 0/1
  // since the schema is numeric-only; 1 requires the middle candle's body
  // ratio to clear `minBodyRatio` (displacement filter).
  'fvg': IndicatorSchema(
    kind: 'fvg',
    displayName: 'Fair Value Gap',
    shortDescription: 'ICT 3-candle imbalance zone, fades when mitigated.',
    params: [
      IndicatorParam(
        key: 'strictMode', label: 'Strict mode',
        description: '1 = require middle-candle body displacement. '
                     '0 = show every gap.',
        defaultValue: 0, min: 0, max: 1,
      ),
      IndicatorParam(
        key: 'minBodyRatio', label: 'Min body ratio',
        description: 'Body / range threshold for the impulse candle (strict only).',
        defaultValue: 0.50, min: 0.10, max: 0.95, step: 0.05, isInt: false,
      ),
      IndicatorParam(
        key: 'extendBars', label: 'Extend bars',
        description: 'Bars an unmitigated gap extends forward.',
        defaultValue: 30, min: 5, max: 200,
      ),
      IndicatorParam(
        key: 'maxBoxes', label: 'Max visible boxes',
        description: 'Most-recent N gaps drawn; older are pruned.',
        defaultValue: 20, min: 1, max: 100,
      ),
      IndicatorParam(
        key: 'showMitigated', label: 'Show mitigated',
        description: '1 = keep filled gaps as faded outlines. 0 = hide.',
        defaultValue: 1, min: 0, max: 1,
      ),
    ],
  ),
  // ICT/SMC Order Block — last opposing-color candle before an ATR-scaled
  // impulse move. `useBodyOnly` encoded 0/1 (1 = box uses open/close body,
  // 0 = full high/low range).
  'ob': IndicatorSchema(
    kind: 'ob',
    displayName: 'Order Block',
    shortDescription: 'Last opposing candle before an ATR-scaled impulse.',
    params: [
      IndicatorParam(
        key: 'atrPeriod', label: 'ATR Period',
        description: 'ATR length used to scale impulse strength.',
        defaultValue: 14, min: 2, max: 100,
      ),
      IndicatorParam(
        key: 'impulseThreshold', label: 'Impulse threshold',
        description: 'ATR multiple a candle body must clear to qualify.',
        defaultValue: 1.5, min: 0.5, max: 5.0, step: 0.1, isInt: false,
      ),
      IndicatorParam(
        key: 'useBodyOnly', label: 'Body only',
        description: '1 = box spans open/close body. 0 = full high/low.',
        defaultValue: 1, min: 0, max: 1,
      ),
      IndicatorParam(
        key: 'extendBars', label: 'Extend bars',
        description: 'Bars an unmitigated OB extends forward.',
        defaultValue: 100, min: 5, max: 500,
      ),
      IndicatorParam(
        key: 'maxBoxes', label: 'Max visible boxes',
        description: 'Most-recent N order blocks drawn.',
        defaultValue: 10, min: 1, max: 50,
      ),
      IndicatorParam(
        key: 'showMitigated', label: 'Show mitigated',
        description: '1 = keep mitigated OBs as faded outlines. 0 = hide.',
        defaultValue: 0, min: 0, max: 1,
      ),
    ],
  ),
  // ICT Liquidity Sweep — wick pierces a prior swing pivot but body
  // closes back inside. Signals stop-hunt rejection at the level.
  'liqsweep': IndicatorSchema(
    kind: 'liqsweep',
    displayName: 'Liquidity Sweep',
    shortDescription: 'Wick pierces a swing pivot, body closes back inside.',
    params: [
      IndicatorParam(
        key: 'pivotWidth', label: 'Pivot width',
        description: 'Bars each side that define a fractal swing pivot.',
        defaultValue: 2, min: 1, max: 10,
      ),
      IndicatorParam(
        key: 'showSweepLine', label: 'Show sweep line',
        description: '1 = dashed line from swept pivot to sweep candle.',
        defaultValue: 1, min: 0, max: 1,
      ),
      IndicatorParam(
        key: 'maxMarkers', label: 'Max markers',
        description: 'Most-recent N sweeps rendered.',
        defaultValue: 20, min: 1, max: 100,
      ),
    ],
  ),
  // ICT/SMC Market Structure — labels BOS (continuation), CHoCH (first
  // opposite break) and MSS (CHoCH with displacement body) at the candle
  // that closes through a confirmed swing pivot.
  'mss': IndicatorSchema(
    kind: 'mss',
    displayName: 'Market Structure (BOS/CHoCH/MSS)',
    shortDescription: 'Structural breaks at swing pivots — BOS / CHoCH / MSS.',
    params: [
      IndicatorParam(
        key: 'pivotWidth', label: 'Pivot width',
        description: 'Bars each side that define a fractal swing pivot.',
        defaultValue: 2, min: 1, max: 10,
      ),
      IndicatorParam(
        key: 'minBodyRatio', label: 'MSS body ratio',
        description: 'Displacement threshold to upgrade CHoCH → MSS.',
        defaultValue: 0.65, min: 0.10, max: 0.95, step: 0.05, isInt: false,
      ),
      IndicatorParam(
        key: 'maxLabels', label: 'Max labels',
        description: 'Most-recent N structural labels rendered.',
        defaultValue: 15, min: 1, max: 100,
      ),
      IndicatorParam(
        key: 'showBreakLine', label: 'Show break line',
        description: '1 = dashed level line from pivot to break candle.',
        defaultValue: 1, min: 0, max: 1,
      ),
    ],
  ),
  // ── Phase 29 — multi-param additions ────────────────────────────────────
  'supertrend': IndicatorSchema(
    kind: 'supertrend',
    displayName: 'SuperTrend',
    shortDescription: 'ATR-banded trend follower; flips on the close cross.',
    legacyPeriodKey: 'atrLength',
    params: [
      IndicatorParam(
        key: 'atrLength', label: 'ATR Length',
        description: 'Average True Range period',
        defaultValue: 10, min: 2, max: 200,
      ),
      IndicatorParam(
        key: 'mult', label: 'Multiplier',
        description: 'Band width as ATR multiples',
        defaultValue: 3.0, min: 0.5, max: 10, step: 0.1, isInt: false,
      ),
    ],
  ),
  'keltner': IndicatorSchema(
    kind: 'keltner',
    displayName: 'Keltner Channels',
    shortDescription: 'EMA midline with ATR-scaled upper/lower bands.',
    legacyPeriodKey: 'length',
    params: [
      IndicatorParam(
        key: 'length', label: 'EMA Length',
        description: 'Midline EMA period',
        defaultValue: 20, min: 1, max: 999,
      ),
      IndicatorParam(
        key: 'mult', label: 'Multiplier',
        description: 'Band width as ATR multiples',
        defaultValue: 2.0, min: 0.5, max: 10, step: 0.1, isInt: false,
      ),
      IndicatorParam(
        key: 'atrLength', label: 'ATR Length',
        description: 'ATR period for the band width',
        defaultValue: 10, min: 1, max: 200,
      ),
    ],
  ),
  'psar': IndicatorSchema(
    kind: 'psar',
    displayName: 'Parabolic SAR',
    shortDescription: 'Wilder stop-and-reverse dots; accel ramps to a cap.',
    params: [
      IndicatorParam(
        key: 'accel', label: 'Acceleration',
        description: 'Starting/step acceleration factor',
        defaultValue: 0.02, min: 0.01, max: 0.2, step: 0.01, isInt: false,
      ),
      IndicatorParam(
        key: 'maxAccel', label: 'Max Acceleration',
        description: 'Acceleration factor ceiling',
        defaultValue: 0.2, min: 0.01, max: 0.2, step: 0.01, isInt: false,
      ),
    ],
  ),
  // Pivot Points — support/resistance levels from the prior period's OHLC,
  // drawn as a price-pane overlay. Enum option order MUST match the tables in
  // chart-overlays.js (PIVOT_VARIANTS) and chart-indicators.js (PIVOT_TIMEFRAMES).
  // Line color = IndicatorConfig.color, line width = IndicatorConfig.thickness.
  'pivots': IndicatorSchema(
    kind: 'pivots',
    displayName: 'Pivot Points',
    shortDescription: 'Support/resistance pivots from the prior period.',
    params: [
      IndicatorParam(
        key: 'variant', label: 'Type',
        description: 'Pivot calculation method',
        defaultValue: 0,
        options: [
          IndicatorOption('Classical'), IndicatorOption('Fibonacci'),
          IndicatorOption('Camarilla'), IndicatorOption('Woodie'),
          IndicatorOption('DeMark'),
        ],
      ),
      IndicatorParam(
        key: 'pivotTimeframe', label: 'Timeframe',
        description: 'Period each pivot set is derived from',
        defaultValue: 0,
        options: [
          IndicatorOption('Daily'), IndicatorOption('Weekly'),
        ],
      ),
      IndicatorParam(
        key: 'showLabels', label: 'Show labels',
        description: 'Draw the P / S / R label on each level',
        defaultValue: 1, isBool: true,
      ),
      IndicatorParam(
        key: 'showPrices', label: 'Show prices',
        description: 'Draw the price next to each level',
        defaultValue: 1, isBool: true,
      ),
    ],
  ),
};
// ── CPR with Pivot Level Daily ──────────────────────────────────────────────
// Port of the TradingView study. Its settings are per-line styles
// (TradingView's Style tab), so the settings dialog renders a dedicated
// section instead of one row per param. Every setting is a numeric param
// `<key><field>`: V visible 0/1, C colour 0xRRGGBB, W width 1-4, S line style
// index, T plot type index, P price line 0/1 — plus `precision` (index).
// Plot keys, defaults and option orders MUST match chart-helpers.js (CPR_*).
class CprPlotDef {
  final String key;
  final String title;
  final int color;
  final bool visible;
  const CprPlotDef(this.key, this.title, this.color, this.visible);
}

const List<CprPlotDef> kCprPlots = [
  CprPlotDef('pivot', 'Daily Central Pivot', 0xF8AF85, true),
  CprPlotDef('high', 'Prev Day High', 0x6CAC6E, false),
  CprPlotDef('low', 'Prev Day Low', 0xEB2D2D, false),
  CprPlotDef('bc', 'Daily Bottom Pivot', 0x9C50E4, true),
  CprPlotDef('tc', 'Daily Top Pivot', 0x91A9F1, true),
  CprPlotDef('s1', 'Daily S1', 0xFF0000, false),
  CprPlotDef('r1', 'Daily R1', 0x008000, false),
  CprPlotDef('s2', 'Daily S2', 0xFF0000, false),
  CprPlotDef('r2', 'Daily R2', 0x008000, false),
  CprPlotDef('s3', 'Daily S3', 0xFF0000, false),
  CprPlotDef('r3', 'Daily R3', 0x008000, false),
  CprPlotDef('s4', 'Daily S4', 0xFF0000, false),
  CprPlotDef('r4', 'Daily R4', 0x008000, false),
];

const int kCprDefaultWidth = 3;
const int kCprDefaultLineStyle = 0;   // Solid
const int kCprDefaultPlotType = 10;   // Circles (the study's plottype 6)

const IndicatorParam kCprPlotTypeParam = IndicatorParam(
  key: 'T', label: 'Plot type', description: 'How the level is drawn',
  defaultValue: kCprDefaultPlotType,
  options: [
    IndicatorOption('Line'), IndicatorOption('Line with breaks'),
    IndicatorOption('Step line'), IndicatorOption('Step line with breaks'),
    IndicatorOption('Step line with diamonds'), IndicatorOption('Histogram'),
    IndicatorOption('Cross'), IndicatorOption('Area'),
    IndicatorOption('Area with breaks'), IndicatorOption('Columns'),
    IndicatorOption('Circles'),
  ],
);

const IndicatorParam kCprLineStyleParam = IndicatorParam(
  key: 'S', label: 'Line style', description: 'For line and step types',
  defaultValue: kCprDefaultLineStyle,
  options: [
    IndicatorOption('Solid'), IndicatorOption('Dotted'), IndicatorOption('Dashed'),
  ],
);

const IndicatorParam kCprPrecisionParam = IndicatorParam(
  key: 'precision', label: 'Precision', description: 'Decimals shown for the levels',
  defaultValue: 0,
  options: [
    IndicatorOption('Default'), IndicatorOption('0'), IndicatorOption('1'),
    IndicatorOption('2'), IndicatorOption('3'), IndicatorOption('4'),
    IndicatorOption('5'), IndicatorOption('6'), IndicatorOption('7'),
    IndicatorOption('8'),
  ],
);

final IndicatorSchema _kCprSchema = IndicatorSchema(
  kind: 'cpr',
  displayName: 'CPR with Pivot Level Daily',
  shortDescription: 'Central pivot range and S/R levels from the previous day.',
  params: [
    kCprPrecisionParam,
    for (final p in kCprPlots) ...[
      IndicatorParam(key: '${p.key}V', label: '${p.title} visible',
          description: '', defaultValue: p.visible ? 1 : 0, isBool: true),
      IndicatorParam(key: '${p.key}C', label: '${p.title} colour',
          description: '', defaultValue: p.color, min: 0, max: 0xFFFFFF),
      IndicatorParam(key: '${p.key}W', label: '${p.title} width',
          description: '', defaultValue: kCprDefaultWidth, min: 1, max: 4),
      IndicatorParam(key: '${p.key}S', label: '${p.title} line style',
          description: '', defaultValue: kCprDefaultLineStyle,
          options: kCprLineStyleParam.options),
      IndicatorParam(key: '${p.key}T', label: '${p.title} plot type',
          description: '', defaultValue: kCprDefaultPlotType,
          options: kCprPlotTypeParam.options),
      IndicatorParam(key: '${p.key}P', label: '${p.title} price line',
          description: '', defaultValue: 0, isBool: true),
    ],
  ],
);

// ── CPR Trend Checker (CPR + MAs) ───────────────────────────────────────────
// Previous-day / week / month CPR levels with up to five moving averages. All
// settings are numeric params the chart engine reads back (see the TC_* block
// in chart-helpers.js — keys, defaults and option orders MUST match):
//   inputs   auto dOn pdOn wOn pwOn mOn pmOn            switches 0/1
//   a line   <key><V|C|O|W|S|T>   visible, colour 0xRRGGBB, opacity %, width,
//                                 line style index, plot type index
//   a band   <d|w|m>Band<V|C|O>
//   an MA    ma<i>On / Type / Src / Len / C / W         (i = 1..5)
//   output   labelsOn precision axisOn statusOn inputsOn
// A saved indicator keeps only the values that differ from these defaults.
class TcLineDef {
  final String key;
  final String title;
  final String group; // 'd' | 'w' | 'm'
  final int color;
  final int alpha; // opacity %
  const TcLineDef(this.key, this.title, this.group, this.color, this.alpha);
}

class TcBandDef {
  final String key;
  final String title;
  final int color;
  final int alpha;
  const TcBandDef(this.key, this.title, this.color, this.alpha);
}

class TcMaDef {
  final int len;
  final int color;
  final bool on;
  const TcMaDef(this.len, this.color, this.on);
}

List<TcLineDef> _buildTcLines() {
  const groups = [
    ('d', 'pd', 'Daily', 'PDH', 'PDL', 0x2962FF, 0x0D3CFF),
    ('w', 'pw', 'Weekly', 'PWH', 'PWL', 0xC41D9D, 0xC41D9D),
    ('m', 'pm', 'Monthly', 'PMH', 'PML', 0xF58FD8, 0xF58FD8),
  ];
  final out = <TcLineDef>[];
  for (final g in groups) {
    final id = g.$1;
    out.add(TcLineDef('${g.$2}h', g.$4, id, g.$7, 100));
    out.add(TcLineDef('${g.$2}l', g.$5, id, g.$7, 100));
    out.add(TcLineDef('${id}cpr', '${g.$3} CPR', id, g.$6, 50));
    out.add(TcLineDef('${id}bc', '${g.$3} BC', id, g.$6, 0));
    out.add(TcLineDef('${id}tc', '${g.$3} TC', id, g.$6, 0));
    for (final n in [1, 2, 3, 4]) {
      out.add(TcLineDef('${id}r$n', '${g.$3} R$n', id, 0x4CAF50, 100));
      out.add(TcLineDef('${id}s$n', '${g.$3} S$n', id, 0xFF5252, 100));
    }
  }
  return out;
}

final List<TcLineDef> kTcLines = _buildTcLines();

const List<TcBandDef> kTcBands = [
  TcBandDef('dBand', 'Daily CPR Band', 0x2962FF, 25),
  TcBandDef('wBand', 'Weekly CPR Band', 0xC41D9D, 25),
  TcBandDef('mBand', 'Monthly CPR Band', 0xF58FD8, 25),
];

const List<TcMaDef> kTcMas = [
  TcMaDef(10, 0xF5BF00, true),
  TcMaDef(20, 0x178A17, false),
  TcMaDef(50, 0xFF2222, false),
  TcMaDef(100, 0x1A0000, false),
  TcMaDef(200, 0x1E7FFF, false),
];

const int kTcDefaultWidth = 1;
const int kTcMaDefaultWidth = 2;

const IndicatorParam kTcMaTypeParam = IndicatorParam(
  key: 'Type', label: 'Type', description: '', defaultValue: 0,
  options: [
    IndicatorOption('SMA'), IndicatorOption('EMA'), IndicatorOption('WMA'),
    IndicatorOption('RMA'), IndicatorOption('HMA'), IndicatorOption('VWMA'),
  ],
);

const IndicatorParam kTcMaSourceParam = IndicatorParam(
  key: 'Src', label: 'Source', description: '', defaultValue: 0,
  options: [
    IndicatorOption('Close'), IndicatorOption('Open'), IndicatorOption('High'),
    IndicatorOption('Low'), IndicatorOption('HL2'), IndicatorOption('HLC3'),
    IndicatorOption('OHLC4'),
  ],
);

IndicatorParam _tcBool(String key, bool on) => IndicatorParam(
    key: key, label: key, description: '', defaultValue: on ? 1 : 0,
    isBool: true);

final IndicatorSchema _kTcSchema = IndicatorSchema(
  kind: 'tcheck',
  displayName: 'Trend Checker by GP',
  shortDescription:
      'Previous day, week and month CPR levels with moving averages.',
  params: [
    _tcBool('auto', false),
    _tcBool('dOn', true), _tcBool('pdOn', true),
    _tcBool('wOn', false), _tcBool('pwOn', false),
    _tcBool('mOn', false), _tcBool('pmOn', false),
    for (final l in kTcLines) ...[
      _tcBool('${l.key}V', true),
      IndicatorParam(key: '${l.key}C', label: l.title, description: '',
          defaultValue: l.color, min: 0, max: 0xFFFFFF),
      IndicatorParam(key: '${l.key}O', label: l.title, description: '',
          defaultValue: l.alpha, min: 0, max: 100, step: 10),
      IndicatorParam(key: '${l.key}W', label: l.title, description: '',
          defaultValue: kTcDefaultWidth, min: 1, max: 4),
      IndicatorParam(key: '${l.key}S', label: l.title, description: '',
          defaultValue: kCprDefaultLineStyle,
          options: kCprLineStyleParam.options),
      IndicatorParam(key: '${l.key}T', label: l.title, description: '',
          defaultValue: kCprDefaultPlotType,
          options: kCprPlotTypeParam.options),
    ],
    for (final b in kTcBands) ...[
      _tcBool('${b.key}V', true),
      IndicatorParam(key: '${b.key}C', label: b.title, description: '',
          defaultValue: b.color, min: 0, max: 0xFFFFFF),
      IndicatorParam(key: '${b.key}O', label: b.title, description: '',
          defaultValue: b.alpha, min: 0, max: 100, step: 10),
    ],
    for (var i = 1; i <= 5; i++) ...[
      _tcBool('ma${i}On', kTcMas[i - 1].on),
      IndicatorParam(key: 'ma${i}Type', label: 'Type', description: '',
          defaultValue: 0, options: kTcMaTypeParam.options),
      IndicatorParam(key: 'ma${i}Src', label: 'Source', description: '',
          defaultValue: 0, options: kTcMaSourceParam.options),
      IndicatorParam(key: 'ma${i}Len', label: 'Length', description: '',
          defaultValue: kTcMas[i - 1].len, min: 1, max: 999),
      IndicatorParam(key: 'ma${i}C', label: 'Colour', description: '',
          defaultValue: kTcMas[i - 1].color, min: 0, max: 0xFFFFFF),
      IndicatorParam(key: 'ma${i}W', label: 'Width', description: '',
          defaultValue: kTcMaDefaultWidth, min: 1, max: 4),
    ],
    _tcBool('labelsOn', true),
    IndicatorParam(key: 'precision', label: 'Precision', description: '',
        defaultValue: 0, options: kCprPrecisionParam.options),
    _tcBool('axisOn', true),
    _tcBool('statusOn', true),
    _tcBool('inputsOn', true),
  ],
);
