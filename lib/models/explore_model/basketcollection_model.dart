class SavedStrategyModel {
  String? msg;
  List<Data>? data;
  List<String>? basketNames;

  SavedStrategyModel({this.msg, this.data, this.basketNames});

  SavedStrategyModel.fromJson(Map<String, dynamic> json) {
    msg = json['msg'];
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
    if (json['basket_names'] != null) {
      basketNames = List<String>.from(json['basket_names']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['msg'] = msg;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    if (basketNames != null) {
      data['basket_names'] = basketNames;
    }
    return data;
  }
}

class PerformanceMetrics {
  double? gain;
  double? xirr;
  double? gainPerc;
  double? volatility;
  double? maxDrawdown;
  double? sharpeRatio;
  double? currentValue;
  double? investmentAmount;

  PerformanceMetrics({
    this.gain,
    this.xirr,
    this.gainPerc,
    this.volatility,
    this.maxDrawdown,
    this.sharpeRatio,
    this.currentValue,
    this.investmentAmount,
  });

  PerformanceMetrics.fromJson(Map<String, dynamic> json) {
    gain = (json['gain'] as num?)?.toDouble();
    xirr = (json['xirr'] as num?)?.toDouble();
    gainPerc = (json['gain_perc'] as num?)?.toDouble();
    volatility = (json['volatility'] as num?)?.toDouble();
    maxDrawdown = (json['max_drawdown'] as num?)?.toDouble();
    sharpeRatio = (json['sharpe_ratio'] as num?)?.toDouble();
    currentValue = (json['current_value'] as num?)?.toDouble();
    investmentAmount = (json['investment_amount'] as num?)?.toDouble();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['gain'] = gain;
    data['xirr'] = xirr;
    data['gain_perc'] = gainPerc;
    data['volatility'] = volatility;
    data['max_drawdown'] = maxDrawdown;
    data['sharpe_ratio'] = sharpeRatio;
    data['current_value'] = currentValue;
    data['investment_amount'] = investmentAmount;
    return data;
  }
}

class Data {
  List<SchemaValues>? schemaValues;
  String? uuid;
  int? years;
  double? investAmount;
  String? datetime;
  String? investmentDetails;
  String? basketName;
  String? name;
  PerformanceMetrics? performanceMetrics;

  Data(
      {this.schemaValues,
      this.uuid,
      this.years,
      this.investAmount,
      this.datetime,
      this.investmentDetails,
      this.basketName,
      this.name,
      this.performanceMetrics,
      });

  Data.fromJson(Map<String, dynamic> json) {
    if (json['schema_values'] != null) {
      schemaValues = <SchemaValues>[];
      json['schema_values'].forEach((v) {
        schemaValues!.add(SchemaValues.fromJson(v));
      });
    }
    uuid = json['uuid'];
    years = json['years'];
    investAmount = json['invest_amount'];
    datetime = json['datetime'];
    investmentDetails = json['investment_details'];
    basketName = json['basket_name'];
    name = json['name'];
    if (json['performance_metrics'] != null) {
      performanceMetrics = PerformanceMetrics.fromJson(json['performance_metrics']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (schemaValues != null) {
      data['schema_values'] =
          schemaValues!.map((v) => v.toJson()).toList();
    }
    data['uuid'] = uuid;
    data['years'] = years;
    data['invest_amount'] = investAmount;
    data['datetime'] = datetime;
    data['investment_details'] = investmentDetails;
    data['basket_name'] = basketName;
    data['name'] = name;
    if (performanceMetrics != null) {
      data['performance_metrics'] = performanceMetrics!.toJson();
    }
    return data;
  }
}

class SchemaValues {
  int? percentage;
  String? schemaName;
  String? schemeType;
  String? isin;
  String? aMCCode;
  double? aum;
  String? name;
  String? schemeCode;
  double? minimumPurchaseAmount;
  double fiveYearCAGR = 0.0;
  double threeYearCAGR = 0.0;

  SchemaValues({this.percentage, this.schemaName, this.schemeType, this.isin, this.name, this.schemeCode, this.minimumPurchaseAmount, this.fiveYearCAGR = 0.0, this.threeYearCAGR = 0.0});

  SchemaValues.fromJson(Map<String, dynamic> json) {
    percentage = json['percentage'];
    schemaName = json['schema_name'];
    schemeType = json['scheme_type'];
    isin = json['isin'];
    aMCCode = json['aMCCode'];
    aum = json['aum'];
    name = json['name'];
    schemeCode = json['scheme_code'];
    minimumPurchaseAmount = (json['minimum_purchase_amount'] as num?)?.toDouble();
    fiveYearCAGR = (json['five_year_cagr'] as num?)?.toDouble() ?? 0.0;
    threeYearCAGR = (json['three_year_cagr'] as num?)?.toDouble() ?? 0.0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['percentage'] = percentage;
    data['schema_name'] = schemaName;
    data['scheme_type'] = schemeType;
    data['isin'] = isin;
    data['aMCCode'] = aMCCode;
    data['aum'] = aum;
    data['name'] = name;
    data['scheme_code'] = schemeCode;
    data['minimum_purchase_amount'] = minimumPurchaseAmount;
    data['five_year_cagr'] = fiveYearCAGR;
    data['three_year_cagr'] = threeYearCAGR;
    return data;
  }
}


// Fund Model
class FundListModel {
  final String name;
  final String type;
  final double oneYearCAGR;
  final double fiveYearCAGR;
  final double threeYearCAGR;
  final double aum;
  final double sharpe;
  final String? aMCCode;
  final String? isin;
  double percentage;
  final String? schemeName;
  bool isLocked;
  final String? schemeCode;
  final double minimumPurchaseAmount;
  double nav;

  FundListModel({
    required this.name,
    required this.type,
    this.oneYearCAGR = 0.0,
    required this.fiveYearCAGR,
    required this.threeYearCAGR,
    required this.aum,
    required this.sharpe,
    this.aMCCode,
    this.percentage = 0.0,
    this.isin,
    this.schemeName,
    this.isLocked = false,
    this.schemeCode,
    this.minimumPurchaseAmount = 100.0,
    this.nav = 0.0,
  });
}

class BasketFundAllocation {
  final FundListModel fund;
  final double allocatedAmount;
  final bool isValid;
  final String? errorMessage;
  final double nav;
  final double estimatedUnits;

  BasketFundAllocation({
    required this.fund,
    required this.allocatedAmount,
    required this.isValid,
    this.errorMessage,
    this.nav = 0.0,
    this.estimatedUnits = 0.0,
  });
}

class BasketOrderResult {
  final FundListModel fund;
  final double amount;
  final bool isSuccess;
  final String? orderId;
  final String? message;

  BasketOrderResult({
    required this.fund,
    required this.amount,
    required this.isSuccess,
    this.orderId,
    this.message,
  });
}