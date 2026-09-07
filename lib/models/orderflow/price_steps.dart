/// Per-symbol price tick step. Defines the bucket size for footprint rows.
const Map<String, double> kPriceStep = {
  'NIFTY': 1.0,
  'BANKNIFTY': 1.0,
  'SENSEX': 1.0,
  'GOLD': 1.0,
  'SILVER': 1.0,
  'CRUDEOIL': 1.0,
  'NATURALGAS': 0.1,
};

/// Symbols exposed by the orderflow backend, in display order.
const List<String> kOrderflowSymbols = [
  'NIFTY',
  'BANKNIFTY',
  'SENSEX',
];

double priceStepFor(String symbol) => kPriceStep[symbol] ?? 1.0;
