class mf_holdoing_new {
  List<Data>? data;
  Summary? summary;
  String? stat;

  mf_holdoing_new({this.data, this.summary, this.stat});

  mf_holdoing_new.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
    summary =
        json['summary'] != null ? Summary.fromJson(json['summary']) : null;
    stat = json['stat'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    if (summary != null) {
      data['summary'] = summary!.toJson();
    }
    data['stat'] = stat;
    return data;
  }
}

class Data {
  String? clientCode;
  String? name;
  String? foliono;
  String? iSIN;
  String? stampduty;
  String? stt;
  String? avgQty;
  String? avgNav;
  String? curNav;
  String? investedValue;
  String? currentValue;
  String? profitLoss;
  String? changeprofitLoss;
  String? minRedemptionQty;
  String? sCHEMECODE;
  String? minimumPurchaseAmount;

  /// Backend gates for the row actions, sent as "Y" / "N".
  ///
  /// Absent is treated as ALLOWED so the Add and Redeem actions keep working
  /// on responses that predate these fields — only an explicit non-"Y" hides
  /// an action. Flip [_flagAllows] to return false on null if the gate should
  /// instead default to hidden.
  String? purchaseAllowed;
  String? redemptionAllowed;

  bool get isPurchaseAllowed => _flagAllows(purchaseAllowed);
  bool get isRedemptionAllowed => _flagAllows(redemptionAllowed);

  static bool _flagAllows(String? value) {
    if (value == null) return true;
    final v = value.trim();
    // Older parsers in this file use `.toString()` on a null JSON value, which
    // yields the literal string "null" — treat that as absent too.
    if (v.isEmpty || v.toLowerCase() == 'null') return true;
    return v.toUpperCase() == 'Y';
  }
  String? aUM;
  String? type;
  String? subType;
  String? aMCCode;
  List<Transactions>? transactions;

  Data(
      {this.clientCode,
      this.name,
      this.foliono,
      this.iSIN,
      this.stampduty,
      this.stt,
      this.avgQty,
      this.avgNav,
      this.curNav,
      this.investedValue,
      this.currentValue,
      this.changeprofitLoss,
      this.profitLoss,
      this.transactions});

  Data.fromJson(Map<String, dynamic> json) {
    clientCode = json['ClientCode'].toString();
    changeprofitLoss = json['changeprofitloss'].toString(); 
    name = json['name'].toString();
    foliono = json['foliono'].toString();
    iSIN = json['ISIN'].toString();
    stampduty = json['stampduty'].toString();
    stt = json['stt'].toString();
    avgQty = json['avg_qty'].toString();
    avgNav = json['avg_nav'].toString();
    curNav = json['Cur_Nav'].toString();
    investedValue = json['invested_value'].toString();
    currentValue = json['current_value'].toString();
    profitLoss = json['profit_loss'].toString();
    sCHEMECODE= json["Scheme_Code"].toString();

    minRedemptionQty=json["Minimum_Redemption_Qty"].toString();
    minimumPurchaseAmount=json["Minimum_Purchase_Amount"].toString();
    purchaseAllowed = json["Purchase_Allowed"]?.toString();
    redemptionAllowed = json["Redemption_Allowed"]?.toString();
    aUM=json["AUM"].toString();
    type=json["Type"].toString();
    subType=json["SubType"].toString();
    aMCCode=json["AMC_Code"].toString();
    if (json['transactions'] != null) {
      transactions = <Transactions>[];
      json['transactions'].forEach((v) {
        transactions!.add(Transactions.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['ClientCode'] = clientCode;
    data['name'] = name;
    data['foliono'] = foliono;
    data['ISIN'] = iSIN;
    data['stampduty'] = stampduty;
    data['stt'] = stt;
    data['avg_qty'] = avgQty;
    data['avg_nav'] = avgNav;
    data['Cur_Nav'] = curNav;
    data['invested_value'] = investedValue;
    data['current_value'] = currentValue;
    data['profit_loss'] = profitLoss;
    data['Minimum_Redemption_Qty'] = minRedemptionQty;
    data['Scheme_Code'] = sCHEMECODE;
    data['Minimum_Purchase_Amount'] = minimumPurchaseAmount;
    data['Purchase_Allowed'] = purchaseAllowed;
    data['Redemption_Allowed'] = redemptionAllowed;
    data['AUM'] = aUM;
    data['Type'] = type;
    data['SubType'] = subType;
    data['AMC_Code'] = aMCCode;
    data['changeprofitLoss'] = changeprofitLoss;
    
    
 
    if (transactions != null) {
      data['transactions'] = transactions!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Transactions {
  String? txnDate;
  String? txnType;
  String? txnNo;
  String? seqNo;
  String? arnNo;
  String? units;
  String? avgNav;
  String? invAmount;
  String? stampDuty;
  String? sTT;
  String? pR;
  String? purRed;

  Transactions(
      {this.txnDate,
      this.txnType,
      this.txnNo,
      this.seqNo,
      this.arnNo,
      this.units,
      this.avgNav,
      this.invAmount,
      this.stampDuty,
      this.sTT,
      this.pR,
      this.purRed});

  Transactions.fromJson(Map<String, dynamic> json) {
    txnDate = json['TxnDate'].toString();
    txnType = json['txnType'].toString();
    txnNo = json['txnNo'].toString();
    seqNo = json['seqNo'].toString();
    arnNo = json['arnNo'].toString();
    units = json['units'].toString();
    avgNav = json['avg_nav'].toString();
    invAmount = json['Inv_amount'].toString();
    stampDuty = json['stampDuty'].toString();
    sTT = json['STT'].toString();
    pR = json['PR'].toString();
    purRed = json['pur_red'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['TxnDate'] = txnDate;
    data['txnType'] = txnType;
    data['txnNo'] = txnNo;
    data['seqNo'] = seqNo;
    data['arnNo'] = arnNo;
    data['units'] = units;
    data['avg_nav'] = avgNav;
    data['Inv_amount'] = invAmount;
    data['stampDuty'] = stampDuty;
    data['STT'] = sTT;
    data['PR'] = pR;
    data['pur_red'] = purRed;
    return data;
  }
}

class Summary {
  String? invested;
  String? currentValue;
  String? absReturnValue;
  String? absReturnPercent;

  Summary(
      {this.invested,
      this.currentValue,
      this.absReturnValue,
      this.absReturnPercent});

  Summary.fromJson(Map<String, dynamic> json) {
    invested = json['invested'].toString();
    currentValue = json['current_value'].toString();
    absReturnValue = json['abs_return_value'].toString();
    absReturnPercent = json['abs_return_percent'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['invested'] = invested;
    data['current_value'] = currentValue;
    data['abs_return_value'] = absReturnValue;
    data['abs_return_percent'] = absReturnPercent;
    return data;
  }
}
