/// Current InstaOptions Analytics selection (exchange + symbol + expiry).
///
/// Persisted to `Preferences` under the key `instaoptions:selection`.
class InstaOptionsSelection {
  final String exchange;
  final String symbol;
  final String expiry;

  const InstaOptionsSelection({
    required this.exchange,
    required this.symbol,
    required this.expiry,
  });

  static const InstaOptionsSelection defaultSelection = InstaOptionsSelection(
    exchange: 'NFO',
    symbol: 'NIFTY',
    expiry: '',
  );

  InstaOptionsSelection copyWith({
    String? exchange,
    String? symbol,
    String? expiry,
  }) {
    return InstaOptionsSelection(
      exchange: exchange ?? this.exchange,
      symbol: symbol ?? this.symbol,
      expiry: expiry ?? this.expiry,
    );
  }

  Map<String, dynamic> toJson() => {
        'exchange': exchange,
        'symbol': symbol,
        'expiry': expiry,
      };

  factory InstaOptionsSelection.fromJson(Map<String, dynamic> json) {
    return InstaOptionsSelection(
      exchange: json['exchange'] as String? ?? 'NFO',
      symbol: json['symbol'] as String? ?? 'NIFTY',
      expiry: json['expiry'] as String? ?? '',
    );
  }
}
