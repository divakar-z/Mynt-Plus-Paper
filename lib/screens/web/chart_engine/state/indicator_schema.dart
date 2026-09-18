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
IndicatorSchema? schemaFor(String kind) => _kSchemas[kind.toLowerCase()];

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
