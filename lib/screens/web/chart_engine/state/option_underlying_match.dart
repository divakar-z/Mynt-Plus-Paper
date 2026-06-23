import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';

/// Parsed option-tsym components. Returned by [parseOptionTsym] when the
/// passed-in tsym matches the standard Indian option naming convention.
class ParsedOption {
  final String underlying; // e.g. 'NIFTY', 'BANKNIFTY'
  final String expiryDay;  // e.g. '30'
  final String expiryMon;  // e.g. 'SEP'
  final String expiryYr;   // e.g. '25'
  final String optType;    // 'CE' or 'PE'
  final double strike;
  const ParsedOption({
    required this.underlying,
    required this.expiryDay,
    required this.expiryMon,
    required this.expiryYr,
    required this.optType,
    required this.strike,
  });

  /// Short display label, e.g. "25250 CE" — used in chip text.
  String get shortLabel => '${_fmtStrike(strike)} $optType';

  /// Longer display label, e.g. "25250 CE 30 SEP" — currently unused but
  /// available for future tooltip / detail uses.
  String get longLabel => '${_fmtStrike(strike)} $optType $expiryDay $expiryMon';

  static String _fmtStrike(double s) {
    if (s == s.truncateToDouble()) return s.toStringAsFixed(0);
    return s.toStringAsFixed(2);
  }
}

/// Indian option tsym pattern. Examples:
///   NIFTY30SEP25C25250
///   BANKNIFTY30SEP25P50000
///   FINNIFTY28OCT25C26000
///   SENSEX30SEP25C81000
///
/// Underlying name: leading letters. Day: 2 digits. Month: 3 letters.
/// Year: 2 digits. Type: C or P (we'll normalize to CE / PE). Strike: 1+
/// digits with optional decimal.
///
/// Weekly expiries (e.g. NIFTY07SEP25C25250) parse identically — the 2-digit
/// day field covers 01–31.
final RegExp _kOptionTsymRe =
    RegExp(r'^([A-Z]+?)(\d{2})([A-Z]{3})(\d{2})([CP])(\d+(?:\.\d+)?)$');

ParsedOption? parseOptionTsym(String? tsym) {
  if (tsym == null || tsym.isEmpty) return null;
  final m = _kOptionTsymRe.firstMatch(tsym.toUpperCase());
  if (m == null) return null;
  final strike = double.tryParse(m.group(6)!);
  if (strike == null || strike <= 0) return null;
  return ParsedOption(
    underlying: m.group(1)!,
    expiryDay: m.group(2)!,
    expiryMon: m.group(3)!,
    expiryYr: m.group(4)!,
    optType: m.group(5)! == 'C' ? 'CE' : 'PE',
    strike: strike,
  );
}

/// Maps each option underlying name (as it appears in the option tsym) to
/// the spot scrip (exch + token) for that underlying. Sourced from the same
/// list used in `lib/provider/option_strategy.dart`'s `_optionIndex`.
///
/// Stock options are intentionally NOT included — Phase 17.A MVP is
/// index-only.
const Map<String, _UnderlyingScrip> _kIndexUnderlyings = {
  'NIFTY':      _UnderlyingScrip(exch: 'NSE', token: '26000'),
  'BANKNIFTY':  _UnderlyingScrip(exch: 'NSE', token: '26009'),
  'FINNIFTY':   _UnderlyingScrip(exch: 'NSE', token: '26037'),
  'MIDCPNIFTY': _UnderlyingScrip(exch: 'NSE', token: '26074'),
  'SENSEX':     _UnderlyingScrip(exch: 'BSE', token: '1'),
  'CRUDEOIL':   _UnderlyingScrip(exch: 'MCX', token: '294'),
  'NATURALGAS': _UnderlyingScrip(exch: 'MCX', token: '401'),
  'GOLD':       _UnderlyingScrip(exch: 'MCX', token: '114'),
};

class _UnderlyingScrip {
  final String exch;
  final String token;
  const _UnderlyingScrip({required this.exch, required this.token});
}

/// Returns true when the position is an option whose UNDERLYING index
/// matches `paneScrip`. Used by `overlay_payload.dart` to decide whether to
/// emit an `optionStrike` overlay on the current pane.
///
/// Returns the parsed option metadata as a side effect via [parsedOut] so
/// the caller can reuse it for the overlay label without re-parsing.
bool positionOptionMatchesPane({
  required ChartScrip paneScrip,
  required PositionBookModel pos,
  required void Function(ParsedOption) parsedOut,
}) {
  final parsed = parseOptionTsym(pos.tsym);
  if (parsed == null) return false;
  final underlying = _kIndexUnderlyings[parsed.underlying];
  if (underlying == null) return false;
  if (underlying.exch != paneScrip.exch) return false;
  if (underlying.token != paneScrip.token) return false;
  parsedOut(parsed);
  return true;
}

/// Maps each supported index underlying name to the exchange code used by
/// `getOptionChain` (NFO for NSE indices, BFO for BSE). MCX commodities
/// also have option chains but are out of scope for Phase 18.
const Map<String, String> _kIndexOptionExchanges = {
  'NIFTY':      'NFO',
  'BANKNIFTY':  'NFO',
  'FINNIFTY':   'NFO',
  'MIDCPNIFTY': 'NFO',
  'SENSEX':     'BFO',
};

/// Returns `(underlying, optionExch)` when [paneScrip] is a supported index
/// spot whose option chain we can fetch. Otherwise null. Used by the shell
/// screen's OI fetch loop in Phase 18.
({String underlying, String optionExch})? optionChainTargetForPane(
    ChartScrip paneScrip) {
  for (final entry in _kIndexUnderlyings.entries) {
    final us = entry.value;
    if (us.exch == paneScrip.exch && us.token == paneScrip.token) {
      final ex = _kIndexOptionExchanges[entry.key];
      if (ex == null) return null;
      return (underlying: entry.key, optionExch: ex);
    }
  }
  return null;
}
