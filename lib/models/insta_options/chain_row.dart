/// One row from `/oi/chain` or `/analytics/chain`.
///
/// For the FUT row, `strike` is `0` and Greeks are absent.
/// For CE/PE rows with `iv_solver_ok: false`, the Greeks fields are null.
class ChainRow {
  final int token;
  final String symbol;
  final String expiry;
  final String optionType;
  final double strike;
  final String tradingSymbol;
  final double ltp;
  final double? prevClose;
  final int oi;
  final int volume;
  final bool nearestMonthFut;

  // Greeks (only present on /analytics/chain; null on /oi/chain or when iv_solver_ok=false).
  final double? iv;
  final double? delta;
  final double? gamma;
  final double? theta;
  final double? vega;
  final double? rho;
  final bool? ivSolverOk;

  const ChainRow({
    required this.token,
    required this.symbol,
    required this.expiry,
    required this.optionType,
    required this.strike,
    required this.tradingSymbol,
    required this.ltp,
    required this.oi,
    required this.volume,
    this.prevClose,
    this.nearestMonthFut = false,
    this.iv,
    this.delta,
    this.gamma,
    this.theta,
    this.vega,
    this.rho,
    this.ivSolverOk,
  });

  bool get isCe => optionType == 'CE';
  bool get isPe => optionType == 'PE';
  bool get isFut => optionType == 'FUT';

  /// LTP % change vs `prev_close`. Returns null when `prev_close` is missing
  /// or non-positive (e.g. brand-new contracts, FUT rows pre-Ticket-1 fix).
  double? get ltpChangePct {
    final pc = prevClose;
    if (pc == null || pc <= 0) return null;
    return (ltp - pc) / pc * 100;
  }

  factory ChainRow.fromJson(Map<String, dynamic> json) {
    final strikeRaw = json['strike'];
    double strike;
    if (strikeRaw is num) {
      strike = strikeRaw.toDouble();
    } else {
      strike = double.tryParse(strikeRaw?.toString() ?? '0') ?? 0;
    }
    return ChainRow(
      token: (json['token'] as num?)?.toInt() ?? 0,
      symbol: json['symbol'] as String? ?? '',
      expiry: json['expiry'] as String? ?? '',
      optionType: json['option_type'] as String? ?? '',
      strike: strike,
      tradingSymbol: json['trading_symbol'] as String? ?? '',
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0,
      prevClose: (json['prev_close'] as num?)?.toDouble(),
      oi: (json['oi'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      nearestMonthFut: json['nearest_month_fut'] as bool? ?? false,
      iv: (json['iv'] as num?)?.toDouble(),
      delta: (json['delta'] as num?)?.toDouble(),
      gamma: (json['gamma'] as num?)?.toDouble(),
      theta: (json['theta'] as num?)?.toDouble(),
      vega: (json['vega'] as num?)?.toDouble(),
      rho: (json['rho'] as num?)?.toDouble(),
      ivSolverOk: json['iv_solver_ok'] as bool?,
    );
  }
}
