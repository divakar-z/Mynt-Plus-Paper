/// Schema-driven parameter definitions for each indicator kind. The settings
/// dialog reads [schemaFor] to know which numeric rows to render; chart.js
/// reads the same values back through `IndicatorConfig.params`.
///
/// Kinds not in the registry fall back to the single-`period` row from the
/// generic dialog (governed by `_kKindsWithPeriod` in the shell screen).
class IndicatorParam {
  /// Map key inside `IndicatorConfig.params`.
  final String key;
  /// Short label shown next to the stepper.
  final String label;
  /// One-line caption below the label.
  final String description;
  final num defaultValue;
  final num min;
  final num max;
  /// Step size — 1 for integer params, fractional (e.g. 0.1) for floats.
  final num step;
  /// Forces integer storage when true; floats round-trip as `double`.
  final bool isInt;
  const IndicatorParam({
    required this.key,
    required this.label,
    required this.description,
    required this.defaultValue,
    required this.min,
    required this.max,
    this.step = 1,
    this.isInt = true,
  });
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
};
