import 'package:intl/intl.dart';
import 'package:mynt_plus/utils/rupee_convert_format.dart';

/// Number / time formatters for InstaOptions Analytics screens.
///
/// Thin wrappers over `RupeeFormat` (Indian L/Cr grouping) + `intl`. Use these
/// helpers — do NOT call `value.toString()` directly inside widgets.
class InstaOptionsFormat {
  InstaOptionsFormat._();

  /// Compact OI / Volume — `12,30,825 → 12.31L`, `4,50,00,000 → 4.50Cr`.
  /// Empty / non-finite inputs render as the em-dash placeholder.
  static String oi(num? value) {
    if (value == null || !value.isFinite) return '—';
    final compact = RupeeFormat.formatCompact(value);
    return compact.replaceAll(' ', '');
  }

  /// LTP / strike / premium — 2 decimals with Indian grouping.
  static String price(num? value) {
    if (value == null || !value.isFinite) return '—';
    return RupeeFormat.format(value);
  }

  /// Signed change % — `+1.42%` / `-0.83%`. Caller applies colour.
  static String changePct(num? value) {
    if (value == null || !value.isFinite) return '—';
    return '${RupeeFormat.format(value, showSign: true)}%';
  }

  /// Implied volatility — `12.8%`.
  static String iv(num? value) {
    if (value == null || !value.isFinite) return '—';
    return '${value.toStringAsFixed(1)}%';
  }

  /// Greeks (Δ Γ Θ V Ρ) — 4 decimals; sign comes from the value itself.
  static String greek(num? value) {
    if (value == null || !value.isFinite) return '—';
    return value.toStringAsFixed(4);
  }

  /// PCR — 2 decimals.
  static String pcr(num? value) {
    if (value == null || !value.isFinite) return '—';
    return value.toStringAsFixed(2);
  }

  /// Display time `HH:mm` (IST, server provides IST already).
  static String time(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat.Hm().format(dt);
  }

  /// Tooltip time `YYYY-MM-DD HH:mm:ss`.
  static String tooltipTime(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }
}
