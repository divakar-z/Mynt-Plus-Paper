import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// Display placeholder for null numbers.
const String kEmDash = '—';

/// Format an INR amount using the Indian crore/lakh convention.
String formatCurrencyINR(num? value) {
  if (value == null) return kEmDash;
  final crore = value / 1e7;
  if (crore >= 1e5) {
    return '${_indianFormat(crore / 1e5, maxFractionDigits: 2)} L Cr';
  }
  if (crore >= 1) {
    return '${_indianFormat(crore, maxFractionDigits: 0)} Cr';
  }
  return '₹${_indianFormat(value.toDouble(), maxFractionDigits: 0)}';
}

/// Format a fraction as a percentage (`0.15` → `15.00%`). Optional `+` prefix
/// for positive values when [signed] is true.
String formatPercent(num? value, {bool signed = false}) {
  if (value == null) return kEmDash;
  final pct = value * 100;
  final body = pct.toStringAsFixed(2);
  final sign = signed && pct >= 0 ? '+' : '';
  return '$sign$body%';
}

/// Format an absolute change value with `+`/`-` sign.
String formatSignedNumber(num? value, {int fractionDigits = 2}) {
  if (value == null) return kEmDash;
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(fractionDigits)}';
}

/// Color appropriate for a +/- value.
Color signedColor(BuildContext context, num? value) {
  if (value == null) {
    return resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
  }
  return value >= 0
      ? resolveThemeColor(context,
          dark: MyntColors.successDark, light: MyntColors.success)
      : resolveThemeColor(context,
          dark: MyntColors.errorDark, light: MyntColors.error);
}

/// Parse a backend ISO date that may be missing a timezone suffix. The
/// backend stores naive UTC and may serialize as either:
///   - date only: `2024-12-31`           → treat as UTC midnight
///   - date+time, no Tz: `2024-12-31 18:30:00` or `2024-12-31T18:30:00` → UTC
///   - explicit Tz: `2024-12-31T18:30:00Z` or `+05:30`                  → as-is
DateTime parseBackendDate(String s) {
  final hasTz = RegExp(r'Z|[+\-]\d{2}:?\d{2}$').hasMatch(s);
  if (hasTz) return DateTime.parse(s);
  // Date-only: append explicit UTC midnight.
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
    return DateTime.parse('${s}T00:00:00Z');
  }
  // Date+time, no Tz: replace space with T and append Z.
  if (RegExp(r'^\d{4}-\d{2}-\d{2}[ T]').hasMatch(s)) {
    return DateTime.parse('${s.replaceFirst(" ", "T")}Z');
  }
  return DateTime.parse(s);
}

/// Format a backend timestamp in IST (`Asia/Kolkata`).
String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return kEmDash;
  final utc = parseBackendDate(iso).toUtc();
  final ist = utc.add(const Duration(hours: 5, minutes: 30));
  return '${_pad(ist.day)} ${_monthShort(ist.month)} ${ist.year}, '
      '${_pad(ist.hour)}:${_pad(ist.minute)}';
}

/// Date-only variant (no time).
String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return kEmDash;
  final utc = parseBackendDate(iso).toUtc();
  final ist = utc.add(const Duration(hours: 5, minutes: 30));
  return '${_pad(ist.day)} ${_monthShort(ist.month)} ${ist.year}';
}

/// Per-key formatter for custom-scan result columns.
///
/// The server returns column keys derived from the predicate (e.g. `rsi(14)`,
/// `sma(close,50)`, `volume`, `cdl_doji`). We dispatch on the key prefix to
/// pick a sensible format — the server doesn't carry an `fmt` field for
/// custom-scan responses.
({String text, Color? color}) formatCustomScanCell(
    BuildContext context, String key, dynamic value) {
  if (value == null) return (text: kEmDash, color: null);
  num? n;
  if (value is num) {
    n = value;
  } else {
    n = num.tryParse(value.toString());
  }
  if (n == null) return (text: value.toString(), color: null);

  final lower = key.toLowerCase();

  // Candlestick patterns → Yes/No (1.0 → Yes, 0.0 → No).
  if (lower.startsWith('cdl_')) {
    final positive = resolveThemeColor(context,
        dark: MyntColors.successDark, light: MyntColors.success);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return n >= 0.5
        ? (text: 'Yes', color: positive)
        : (text: 'No', color: muted);
  }

  // Volume keys → integer with Indian thousands separators.
  if (lower.startsWith('volume')) {
    return (
      text: _indianFormat(n.toDouble(), maxFractionDigits: 0),
      color: null,
    );
  }

  // Pure-2-decimal indicator keys (oscillators, momentum, regimes).
  const twoDecKeyPrefixes = <String>[
    'rsi', 'mfi', 'william_r', 'stoch_', 'cci', 'adx', 'di_',
    'momentum_score', 'roc', 'bollinger_bandwidth', 'narrow_range',
    'relative_strength', 'supertrend_dir',
  ];
  for (final p in twoDecKeyPrefixes) {
    if (lower.startsWith(p)) {
      return (text: n.toStringAsFixed(2), color: null);
    }
  }

  // Everything else (prices, SMAs, EMAs, ATR, MACD, Bollinger bands, etc.)
  // → 2 decimals with Indian-style thousands separators.
  return (
    text: _indianFormat(n.toDouble(), maxFractionDigits: 2),
    color: null,
  );
}

/// fmt-driven column formatter (used by scanner-results table).
({String text, Color? color}) formatColumn(
    BuildContext context, num? value, String fmt) {
  if (value == null) return (text: kEmDash, color: null);
  switch (fmt) {
    case 'price':
      return (
        text: _indianFormat(value.toDouble(), maxFractionDigits: 2),
        color: null,
      );
    case 'pct':
      final sign = value >= 0 ? '+' : '';
      return (
        text: '$sign${value.toStringAsFixed(2)}%',
        color: value >= 0 ? resolveThemeColor(context, dark: MyntColors.successDark, light: MyntColors.success)
       : resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.error)
      ,
      );
    case 'signed_price':
      final sign = value >= 0 ? '+' : '-';
      return (
        text:
            '$sign${_indianFormat(value.abs().toDouble(), maxFractionDigits: 2)}',
        color: value >= 0
            ? resolveThemeColor(context,
                dark: MyntColors.successDark, light: MyntColors.success)
            : resolveThemeColor(context,
                dark: MyntColors.errorDark, light: MyntColors.error),
      );
    case 'ratio':
      return (text: value.toStringAsFixed(2), color: null);
    case 'int':
      return (
        text: _indianFormat(value.toDouble(), maxFractionDigits: 0),
        color: null,
      );
    case 'raw':
    default:
      return (text: value.toStringAsFixed(2), color: null);
  }
}

// ---------------------------------------------------------------------------
// Indian comma format helpers
// ---------------------------------------------------------------------------

String _indianFormat(double value, {int maxFractionDigits = 2}) {
  final neg = value < 0;
  final abs = value.abs();
  final fixed = abs.toStringAsFixed(maxFractionDigits);
  final parts = fixed.split('.');
  final intPart = _indianGrouping(parts[0]);
  final hasFraction =
      parts.length == 2 && parts[1] != ''.padLeft(parts[1].length, '0');
  final out = hasFraction ? '$intPart.${parts[1]}' : intPart;
  return neg ? '-$out' : out;
}

String _indianGrouping(String intDigits) {
  // Indian grouping: last 3, then 2-2-2... e.g. 1,39,615
  if (intDigits.length <= 3) return intDigits;
  final last3 = intDigits.substring(intDigits.length - 3);
  String rest = intDigits.substring(0, intDigits.length - 3);
  // Insert commas every 2 chars from the right.
  final buf = StringBuffer();
  while (rest.length > 2) {
    final chunk = rest.substring(rest.length - 2);
    buf.write(',$chunk');
    rest = rest.substring(0, rest.length - 2);
  }
  // Combine: head (1-2 digits) + buffered ,XX,XX,XX (already in reverse order)
  // buf currently has format ",XX,XX..." in reverse insertion order.
  final tail = buf.toString().split(',').where((s) => s.isNotEmpty).toList();
  return '$rest${tail.isEmpty ? '' : ',${tail.reversed.join(',')}'},$last3';
}

String _pad(int n) => n.toString().padLeft(2, '0');

String _monthShort(int m) {
  const names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return names[m - 1];
}
