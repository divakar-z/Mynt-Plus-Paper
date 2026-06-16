/// Model for the "Mutual Fund Beta" holdings tab.
///
/// Sourced from `…/mfapi/order/demat_holdings` (payload `{"ClientCode": <id>}`).
/// This is a SEPARATE model from [mf_holdoing_new] because the demat response
/// uses a different shape (SCRIP_NAME, PlanType, total_units, trades[] with
/// symbol/qty/price/date/source, plus has_missing_units / missing_units).
///
/// Numeric values are stored as String (via toString) to match the existing
/// MF holdings convention so the Beta table can reuse the same
/// `double.tryParse(field ?? '0')` rendering helpers.
class MfDematHolding {
  List<MfDematHoldingData>? data;
  MfDematHoldingSummary? summary;
  String? stat;

  MfDematHolding({this.data, this.summary, this.stat});

  MfDematHolding.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <MfDematHoldingData>[];
      json['data'].forEach((v) {
        data!.add(MfDematHoldingData.fromJson(v));
      });
    }
    summary = json['summary'] != null
        ? MfDematHoldingSummary.fromJson(json['summary'])
        : null;
    stat = json['stat']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
    if (data != null) {
      json['data'] = data!.map((v) => v.toJson()).toList();
    }
    if (summary != null) {
      json['summary'] = summary!.toJson();
    }
    json['stat'] = stat;
    return json;
  }
}

class MfDematHoldingData {
  String? iSIN;
  String? scripName;
  String? planType;
  String? totalUnits;
  String? avgNav;
  String? curNav;
  String? investedValue;
  String? currentValue;
  String? profitLoss;
  String? changeprofitLoss;
  bool? hasMissingUnits;
  String? missingUnits;
  List<MfDematTrade>? trades;

  MfDematHoldingData({
    this.iSIN,
    this.scripName,
    this.planType,
    this.totalUnits,
    this.avgNav,
    this.curNav,
    this.investedValue,
    this.currentValue,
    this.profitLoss,
    this.changeprofitLoss,
    this.hasMissingUnits,
    this.missingUnits,
    this.trades,
  });

  MfDematHoldingData.fromJson(Map<String, dynamic> json) {
    iSIN = json['ISIN']?.toString();
    scripName = json['SCRIP_NAME']?.toString();
    planType = json['PlanType']?.toString();
    totalUnits = json['total_units']?.toString();
    avgNav = json['avg_nav']?.toString();
    curNav = json['Cur_Nav']?.toString();
    investedValue = json['invested_value']?.toString();
    currentValue = json['current_value']?.toString();
    profitLoss = json['profit_loss']?.toString();
    changeprofitLoss = json['changeprofitLoss']?.toString();
    hasMissingUnits = json['has_missing_units'] == true;
    missingUnits = json['missing_units']?.toString();
    if (json['trades'] != null) {
      trades = <MfDematTrade>[];
      json['trades'].forEach((v) {
        trades!.add(MfDematTrade.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
    json['ISIN'] = iSIN;
    json['SCRIP_NAME'] = scripName;
    json['PlanType'] = planType;
    json['total_units'] = totalUnits;
    json['avg_nav'] = avgNav;
    json['Cur_Nav'] = curNav;
    json['invested_value'] = investedValue;
    json['current_value'] = currentValue;
    json['profit_loss'] = profitLoss;
    json['changeprofitLoss'] = changeprofitLoss;
    json['has_missing_units'] = hasMissingUnits;
    json['missing_units'] = missingUnits;
    if (trades != null) {
      json['trades'] = trades!.map((v) => v.toJson()).toList();
    }
    return json;
  }
}

class MfDematTrade {
  String? symbol;
  String? qty;
  String? price;
  String? date;
  String? source;

  MfDematTrade({this.symbol, this.qty, this.price, this.date, this.source});

  MfDematTrade.fromJson(Map<String, dynamic> json) {
    symbol = json['symbol']?.toString();
    qty = json['qty']?.toString();
    price = json['price']?.toString();
    date = json['date']?.toString();
    source = json['source']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
    json['symbol'] = symbol;
    json['qty'] = qty;
    json['price'] = price;
    json['date'] = date;
    json['source'] = source;
    return json;
  }
}

class MfDematHoldingSummary {
  String? invested;
  String? currentValue;
  String? absReturnValue;
  String? absReturnPercent;

  MfDematHoldingSummary({
    this.invested,
    this.currentValue,
    this.absReturnValue,
    this.absReturnPercent,
  });

  MfDematHoldingSummary.fromJson(Map<String, dynamic> json) {
    invested = json['invested']?.toString();
    currentValue = json['current_value']?.toString();
    absReturnValue = json['abs_return_value']?.toString();
    absReturnPercent = json['abs_return_percent']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{};
    json['invested'] = invested;
    json['current_value'] = currentValue;
    json['abs_return_value'] = absReturnValue;
    json['abs_return_percent'] = absReturnPercent;
    return json;
  }
}
