import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// A label + color for an indicator value, used by the Technicals tab badges.
class TechnicalBadge {
  final String label;
  final Color color;
  const TechnicalBadge(this.label, this.color);
}

/// Interpret a numeric indicator value into a human-readable badge.
TechnicalBadge? interpretIndicator({
  required BuildContext context,
  required String key,
  required num? value,
  required Map<String, num?> allIndicators,
}) {
  if (value == null) return null;
  final n = value.toDouble();
  late final success = resolveThemeColor(context,
      dark: MyntColors.successDark, light: MyntColors.success);
  late final error = resolveThemeColor(context,
      dark: MyntColors.errorDark, light: MyntColors.error);
  late final warning = resolveThemeColor(context,
      dark: MyntColors.warningDark, light: MyntColors.warning);
  switch (key) {
    case 'rsi_14':
      if (n < 30) return TechnicalBadge('Oversold', error);
      if (n > 70) return TechnicalBadge('Overbought', warning);
      return null;
    case 'adx_14':
    case 'adx':
      if (n > 25) return TechnicalBadge('Strong trend', success);
      if (n < 20) return TechnicalBadge('Weak trend', warning);
      return null;
    case 'supertrend_dir':
      return n > 0
          ? TechnicalBadge('Up trend', success)
          : TechnicalBadge('Down trend', error);
    case 'macd_hist':
      return n >= 0
          ? TechnicalBadge('Bullish', success)
          : TechnicalBadge('Bearish', error);
    case 'mfi_14':
      if (n < 20) return TechnicalBadge('Oversold', error);
      if (n > 80) return TechnicalBadge('Overbought', warning);
      return null;
    case 'william_r_14':
      if (n < -80) return TechnicalBadge('Oversold', error);
      if (n > -20) return TechnicalBadge('Overbought', warning);
      return null;
    case 'cci_20':
      if (n < -100) return TechnicalBadge('Oversold', error);
      if (n > 100) return TechnicalBadge('Overbought', warning);
      return null;
  }
  if (key == 'close') {
    final sma200 = allIndicators['sma_200']?.toDouble();
    if (sma200 != null) {
      return n >= sma200
          ? TechnicalBadge('Above 200-DMA', success)
          : TechnicalBadge('Below 200-DMA', error);
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
