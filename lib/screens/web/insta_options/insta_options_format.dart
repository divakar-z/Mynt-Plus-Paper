import 'package:intl/intl.dart';
import 'package:mynt_plus/utils/rupee_convert_format.dart';

/// Number / time formatters for InstaOptions Analytics screens.
///
/// Thin wrappers over `RupeeFormat` (Indian L/Cr grouping) + `intl`. Use these
/// helpers — do NOT call `value.toString()` directly inside widgets.
class InstaOptionsFormat {
  InstaOptionsFormat._();

  /// Compact OI / Volume — `12,30,825 → 12.31L`, `4,50,00,000 → 4.50Cr`.
  /// Below 1 lakh, shows a grouped integer (no decimals) — `44,550`, not
  /// `44,550.00`. Empty / non-finite inputs render as the em-dash placeholder.
  static String oi(num? value) {
    if (value == null || !value.isFinite) return '—';
    if (value.abs() < 100000) {
      return RupeeFormat.format(value, decimalPlaces: 0);
    }
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

  /// Compact change % with magnitude-scaled precision so big values never get
  /// truncated: `+339%` (|x| ≥ 100), `+48.7%` (≥ 10), `+4.88%` (< 10). Set
  /// [showSign] false to drop the leading sign (e.g. paired with "building").
  static String pctCompact(num? value, {bool showSign = true}) {
    if (value == null || !value.isFinite) return '—';
    final a = value.abs();
    final n = a >= 100
        ? a.toStringAsFixed(0)
        : a >= 10
            ? a.toStringAsFixed(1)
            : a.toStringAsFixed(2);
    final sign = !showSign ? '' : (value > 0 ? '+' : (value < 0 ? '-' : ''));
    return '$sign$n%';
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

  /// ISO date `YYYY-MM-DD` → `15 Jun 2026`. Empty / invalid → em-dash.
  static String dateLabel(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('dd MMM yyyy').format(dt);
  }
}
