/// In-memory basket leg for the InstaOptions Analytics screens.
///
/// Order placement is intentionally deferred — these legs accumulate visually
/// but never navigate to `/strategy-builder` until a later sprint wires the
/// hand-off (see INSTAOPTIONS_FEATURE_README.md §3).
class BasketLeg {
  final String side;
  final int lot;
  final String expiry;
  final double strike;
  final String optionType;
  final double entryPrice;
  final String tradingSymbol;

  const BasketLeg({
    required this.side,
    required this.lot,
    required this.expiry,
    required this.strike,
    required this.optionType,
    required this.entryPrice,
    required this.tradingSymbol,
  });
}
