
class PortfolioResponse {
  final double xirrResult;
  final Map<String, double> accountAllocation;
  final Map<String, double> marketCapAllocation;
  final Map<String, double> sectorAllocation;
  final List<TopStocks> topStocks;
  final List<Fundamental> fundamentals;
  final ChartData? chartData;
  final String? message;

  PortfolioResponse({
    required this.xirrResult,
    required this.accountAllocation,
    required this.marketCapAllocation,
    required this.sectorAllocation,
    required this.topStocks,
    required this.fundamentals,
    this.chartData,
    this.message,
  });

  /// Marker carried by [PortfolioResponse.empty] so the provider can tell a
  /// genuinely empty portfolio from a payload. Not shown to the client.
  static const String noDataMessage = 'No data found';

  /// The account has nothing to analyse — a normal outcome, not a failure.
  factory PortfolioResponse.empty() => PortfolioResponse(
        xirrResult: 0.0,
        accountAllocation: {},
        marketCapAllocation: {},
        sectorAllocation: {},
        topStocks: [],
        fundamentals: [],
        chartData: null,
        message: noDataMessage,
      );

  factory PortfolioResponse.fromJson(Map<String, dynamic> json) {
    return PortfolioResponse(
      xirrResult: (json['xirr_result'] ?? 0.0).toDouble(),
      accountAllocation: Map<String, double>.from(
        (json['account_allocation'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0.0).toDouble()),
        ),
      ),
      marketCapAllocation: Map<String, double>.from(
        (json['market_cap_allocation'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0.0).toDouble()),
        ),
      ),
      sectorAllocation: Map<String, double>.from(
        (json['sector_allocation'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0.0).toDouble()),
        ),
      ),
      topStocks: (json['top_stocks'] as List<dynamic>? ?? [])
          .map((item) => TopStocks.fromJson(item))
          .toList(),
      fundamentals: (json['fundamentals'] as List<dynamic>? ?? [])
          .map((item) => Fundamental.fromJson(item))
          .toList(),
      chartData: json['chart_data'] != null 
          ? ChartData.fromJson(json['chart_data']) 
          : null,
      message: json['message'] ?? "",
    );
  }
}

class TopStocks {
  String? name;
  String? tsym;
  double? allocationPercent;
  double? inverstedAmount;
  String? exch;
  String? qty;
  String? category;
  String? zebuToken;
  String? marketCapType;
  double? currentPrice;
  double? currentAmount;
  double? pnl;
  double? pnlPercent;

  TopStocks(
      {this.name,
      this.tsym,
      this.allocationPercent,
      this.inverstedAmount,
      this.exch,
      this.qty,
      this.category,
      this.zebuToken,
      this.marketCapType,
      this.currentPrice,
      this.currentAmount,
      this.pnl,
      this.pnlPercent});

  TopStocks.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    tsym = json['tsym'];
    allocationPercent = json['allocation_percent'];
    inverstedAmount = json['inversted_amount'];
    exch = json['exch'];
    qty = json['qty'].toString();
    category = json['category'];
    zebuToken = json['zebuToken'];
    marketCapType = json['market_cap_type'];
    currentPrice = json['current_price'];
    currentAmount = json['current_amount'];
    pnl = json['pnl'];
    pnlPercent = json['pnl_percent'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['tsym'] = tsym;
    data['allocation_percent'] = allocationPercent;
    data['inversted_amount'] = inverstedAmount;
    data['exch'] = exch;
    data['qty'] = qty;
    data['category'] = category;
    data['zebuToken'] = zebuToken;
    data['market_cap_type'] = marketCapType;
    data['current_price'] = currentPrice;
    data['current_amount'] = currentAmount;
    data['pnl'] = pnl;
    data['pnl_percent'] = pnlPercent;
    return data;
  }
}


class Fundamental {
  final int? code;
  final String? sector;
  final double? marketCap;
  final String? companyName;
  final String? marketCapType;
  final String? exch;
  final String? tsym;
  final String? industry;
  final String? house;
  final int? bseCode;
  final String? bseGroup;
  final String? bseScripName;
  final String? tradingStatus;
  final String? nseSymbol;
  final String? nseSeries;
  final String? bseScripId;
  final String? listingStatus;
  final String? isinNo;
  final int? incorporationYear;
  final String? symbol;
  final String? zebuToken;
  final int? qty;
  final double? uploadedPrice;
  final double? value;
  final String? category;
  final double? roePercent;
  final double? rocePercent;
  final double? roaPercent;
  final double? debtToEquity;
  final double? evEbitda;
  final double? bookValue;
  final double? salesToWorkingCapital;
  final double? fixedCapitalToSales;
  final double? priceBookValue;
  final double? eps;
  final double? dividendYieldPercent;
  final double? fv;
  final double? pe;
  final double? sectorPe;

  Fundamental({
    this.code,
    this.sector,
    this.marketCap,
    this.companyName,
    this.marketCapType,
    this.exch,
    this.tsym,
    this.industry,
    this.house,
    this.bseCode,
    this.bseGroup,
    this.bseScripName,
    this.tradingStatus,
    this.nseSymbol,
    this.nseSeries,
    this.bseScripId,
    this.listingStatus,
    this.isinNo,
    this.incorporationYear,
    this.symbol,
    this.zebuToken,
    this.qty,
    this.uploadedPrice,
    this.value,
    this.category,
    this.roePercent,
    this.rocePercent,
    this.roaPercent,
    this.debtToEquity,
    this.evEbitda,
    this.bookValue,
    this.salesToWorkingCapital,
    this.fixedCapitalToSales,
    this.priceBookValue,
    this.eps,
    this.dividendYieldPercent,
    this.fv,
    this.pe,
    this.sectorPe,
  });

  factory Fundamental.fromJson(Map<String, dynamic> json) {
    return Fundamental(
      code: json['code']?.toInt(),
      sector: json['sector'],
      marketCap: json['market_cap']?.toDouble(),
      companyName: json['company_name'],
      marketCapType: json['market_cap_type'],
      exch: json['exch'],
      tsym: json['tsym'],
      industry: json['industry'],
      house: json['house'],
      bseCode: json['bse_code']?.toInt(),
      bseGroup: json['bse_group'],
      // Fixed: Handle the space in field name
      bseScripName: json['bse_scrip name'] ?? json['bse_scrip_name'],
      tradingStatus: json['trading_status'],
      nseSymbol: json['nse_symbol'],
      nseSeries: json['nse_series'],
      bseScripId: json['bse_scrip_id'],
      listingStatus: json['listing_status'],
      isinNo: json['isin_no'],
      incorporationYear: json['incorporation_year']?.toInt(),
      symbol: json['SYMBOL'],
      zebuToken: json['zebuToken'],
      qty: json['qty']?.toInt(),
      uploadedPrice: json['uploaded_price']?.toDouble(),
      value: json['value']?.toDouble(),
      category: json['category'],
      roePercent: json['roe_percent']?.toDouble(),
      rocePercent: json['roce_percent']?.toDouble(),
      roaPercent: json['roa_percent']?.toDouble(),
      debtToEquity: json['debt_to_equity']?.toDouble(),
      evEbitda: json['ev_ebitda']?.toDouble(),
      bookValue: json['book_value']?.toDouble(),
      salesToWorkingCapital: json['sales_to_working_capital']?.toDouble(),
      fixedCapitalToSales: json['fixed_capital_to_sales']?.toDouble(),
      priceBookValue: json['price_book_value']?.toDouble(),
      eps: json['eps']?.toDouble(),
      dividendYieldPercent: json['dividend_yield_percent']?.toDouble(),
      fv: json['fv']?.toDouble(),
      pe: json['pe']?.toDouble(),
      sectorPe: json['sector_pe']?.toDouble(),
    );
  }
}


class ChartData {
  final List<String> dates;
  final List<double> totalInvestedValue;
  final List<double> totalCurrentValue;

  ChartData({
    required this.dates,
    required this.totalInvestedValue,
    required this.totalCurrentValue,
  });

  factory ChartData.fromJson(Map<String, dynamic> json) {
    return ChartData(
      dates: (json['date'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      totalInvestedValue: (json['total_invested_value'] as List<dynamic>? ?? [])
          .map((item) => (item ?? 0.0).toDouble())
          .toList()
          .cast<double>(),
      totalCurrentValue: (json['total_current_value'] as List<dynamic>? ?? [])
          .map((item) => (item ?? 0.0).toDouble())
          .toList()
          .cast<double>(),
    );
  }
}

/// Thrown by `fetchPortfolioAnalysis` when the insights call genuinely fails.
///
/// An account with nothing to analyse is **not** a failure — that comes back as
/// a normal [PortfolioResponse] carrying [PortfolioResponse.noDataMessage], so
/// the screen can say "no data" only when the server actually said so.
///
/// [message] is what the client reads. [backendMessage] is the API's raw `emsg`
/// ("Error occured" and the like) — internal wording, kept for logs only.
class PortfolioAnalysisException implements Exception {
  PortfolioAnalysisException({
    required this.statusCode,
    required this.message,
    this.backendMessage = '',
  });

  /// HTTP status, or 0 if the request never reached the server.
  final int statusCode;

  /// User-presentable message.
  final String message;

  /// The API's raw `emsg`. Never shown to the client.
  final String backendMessage;

  /// Network-level failure (DNS, connection refused, timeout). On web a blocked
  /// CORS preflight also lands here, indistinguishable from the service being
  /// down.
  factory PortfolioAnalysisException.network(Object cause) =>
      PortfolioAnalysisException(
        statusCode: 0,
        message: "Couldn't reach the server — check your connection and try "
            'again.',
      );

  /// A non-2xx, or a body that was not the JSON object we expect.
  factory PortfolioAnalysisException.server(int statusCode) =>
      PortfolioAnalysisException(
        statusCode: statusCode,
        message: 'Something went wrong at our end — please try again.',
      );

  /// `stat: Not_Ok` with an `emsg` other than the empty-portfolio one.
  ///
  /// The account exists and has holdings; the analysis itself failed to build,
  /// so a retry is worth offering.
  factory PortfolioAnalysisException.analysisFailed(
          int statusCode, String emsg) =>
      PortfolioAnalysisException(
        statusCode: statusCode,
        message: "We couldn't build your portfolio insights right now — "
            'please try again.',
        backendMessage: emsg,
      );

  @override
  String toString() => 'PortfolioAnalysisException($statusCode): $message'
      '${backendMessage.isEmpty ? '' : ' [$backendMessage]'}';
}
