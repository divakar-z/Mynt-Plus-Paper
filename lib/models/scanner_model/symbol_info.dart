class SymbolInfo {
  final String ticker;
  final String? fetchedAt;
  final Map<String, dynamic> raw;

  const SymbolInfo({
    required this.ticker,
    required this.fetchedAt,
    required this.raw,
  });

  factory SymbolInfo.fromJson(Map<String, dynamic> j) => SymbolInfo(
        ticker: j['ticker'] as String,
        fetchedAt: j['fetched_at'] as String?,
        raw: Map<String, dynamic>.from(j),
      );

  // Typed accessors for the fields the UI references.
  String? get sector => raw['sector'] as String?;
  String? get industry => raw['industry'] as String?;
  String? get longName => raw['long_name'] as String?;
  String? get businessSummary => raw['business_summary'] as String?;
  double? get marketCap => _toDouble(raw['market_cap']);
  double? get enterpriseValue => _toDouble(raw['enterprise_value']);
  double? get peTrailing => _toDouble(raw['pe_trailing']);
  double? get peForward => _toDouble(raw['pe_forward']);
  double? get pegRatio => _toDouble(raw['peg_ratio']);
  double? get pbRatio => _toDouble(raw['pb_ratio']);
  double? get bookValue => _toDouble(raw['book_value']);
  double? get epsTrailing => _toDouble(raw['eps_trailing']);
  double? get returnOnEquity => _toDouble(raw['return_on_equity']);
  double? get dividendYield => _toDouble(raw['dividend_yield']);
  double? get debtToEquity => _toDouble(raw['debt_to_equity']);
  double? get currentRatio => _toDouble(raw['current_ratio']);
  double? get profitMargins => _toDouble(raw['profit_margins']);
  double? get ebitda => _toDouble(raw['ebitda']);
  double? get fiftyTwoWeekHigh => _toDouble(raw['fifty_two_week_high']);
  double? get fiftyTwoWeekLow => _toDouble(raw['fifty_two_week_low']);
  double? get beta => _toDouble(raw['beta']);

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
