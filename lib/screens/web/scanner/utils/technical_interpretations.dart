import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';

/// A label + color for an indicator value, used by the Technicals tab badges.
class TechnicalBadge {
  final String label;
  final Color color;
  const TechnicalBadge(this.label, this.color);
}

/// Interpret a numeric indicator value into a human-readable badge.
TechnicalBadge? interpretIndicator({
  required String key,
  required num? value,
  required Map<String, num?> allIndicators,
}) {
  if (value == null) return null;
  final n = value.toDouble();
  switch (key) {
    case 'rsi_14':
      if (n < 30) return const TechnicalBadge('Oversold', MyntColors.error);
      if (n > 70) return const TechnicalBadge('Overbought', MyntColors.warning);
      return null;
    case 'adx_14':
    case 'adx':
      if (n > 25) return const TechnicalBadge('Strong trend', MyntColors.success);
      if (n < 20) return const TechnicalBadge('Weak trend', MyntColors.warning);
      return null;
    case 'supertrend_dir':
      return n > 0
          ? const TechnicalBadge('Up trend', MyntColors.success)
          : const TechnicalBadge('Down trend', MyntColors.error);
    case 'macd_hist':
      return n >= 0
          ? const TechnicalBadge('Bullish', MyntColors.success)
          : const TechnicalBadge('Bearish', MyntColors.error);
    case 'mfi_14':
      if (n < 20) return const TechnicalBadge('Oversold', MyntColors.error);
      if (n > 80) return const TechnicalBadge('Overbought', MyntColors.warning);
      return null;
    case 'william_r_14':
      if (n < -80) return const TechnicalBadge('Oversold', MyntColors.error);
      if (n > -20) return const TechnicalBadge('Overbought', MyntColors.warning);
      return null;
    case 'cci_20':
      if (n < -100) return const TechnicalBadge('Oversold', MyntColors.error);
      if (n > 100) return const TechnicalBadge('Overbought', MyntColors.warning);
      return null;
  }
  if (key == 'close') {
    final sma200 = allIndicators['sma_200']?.toDouble();
    if (sma200 != null) {
      return n >= sma200
          ? const TechnicalBadge('Above 200-DMA', MyntColors.success)
          : const TechnicalBadge('Below 200-DMA', MyntColors.error);
    }
  }
  return null;
}

/// Human-readable label for a technical indicator key.
String indicatorLabel(String key) {
  switch (key) {
    case 'sma_20': return 'SMA (20)';
    case 'sma_50': return 'SMA (50)';
    case 'sma_200': return 'SMA (200)';
    case 'ema_9': return 'EMA (9)';
    case 'ema_21': return 'EMA (21)';
    case 'rsi_14': return 'RSI (14)';
    case 'macd_line': return 'MACD Line';
    case 'macd_signal': return 'MACD Signal';
    case 'macd_hist': return 'MACD Histogram';
    case 'bb_upper': return 'Bollinger Upper';
    case 'bb_middle': return 'Bollinger Middle';
    case 'bb_lower': return 'Bollinger Lower';
    case 'atr_14': return 'ATR (14)';
    case 'supertrend_line': return 'SuperTrend Line';
    case 'supertrend_dir': return 'SuperTrend Direction';
    case 'adx_14': case 'adx': return 'ADX (14)';
    case 'di_plus_14': return '+DI (14)';
    case 'di_minus_14': return '-DI (14)';
    case 'psar': return 'Parabolic SAR';
    case 'roc_12': return 'ROC (12)';
    case 'vwap': return 'VWAP';
    case 'stoch_k': return 'Stoch %K';
    case 'stoch_d': return 'Stoch %D';
    case 'mfi_14': return 'MFI (14)';
    case 'william_r_14': return 'Williams %R (14)';
    case 'cci_20': return 'CCI (20)';
    case 'close': return 'Close';
    default:
      return key.replaceAll('_', ' ').toUpperCase();
  }
}
