import 'package:mynt_plus/models/insta_options/option_chain/option_leg.dart';

/// One strike row, pairing the CALL (CE) and PUT (PE) leg at that strike.
/// Either leg may be `null` — that side didn't trade at this strike, so its
/// cells render blank.
class ChainStrikeRow {
  final double strike;
  final bool isAtm;
  final OptionLeg? ce;
  final OptionLeg? pe;

  const ChainStrikeRow({
    required this.strike,
    required this.isAtm,
    this.ce,
    this.pe,
  });

  factory ChainStrikeRow.fromJson(Map<String, dynamic> json) => ChainStrikeRow(
        strike: (json['strike'] as num?)?.toDouble() ?? 0,
        isAtm: json['is_atm'] as bool? ?? false,
        ce: json['ce'] == null
            ? null
            : OptionLeg.fromJson(json['ce'] as Map<String, dynamic>),
        pe: json['pe'] == null
            ? null
            : OptionLeg.fromJson(json['pe'] as Map<String, dynamic>),
      );
}
