import 'dart:convert';

class IpoOrderBookModel {
  String? section;
  String? applicationNumber;
  String? bidReferenceNumber;
  List<BidDetail>? bidDetail;
  String? biddingendDate;
  String? biddingenddate;
  String? biddingstartdate;
  String? category;
  String? clientApplicationStringber;
  String? clientID;
  String? clientRelationID;
  String? companyName;
  String? cutoffprice;
  String? dailyendtime;
  String? dailystarttime;
  String? discounttype;
  String? discountvalue;
  String? failReason;
  String? failReasonCode;
  String? investmentValue;
  String? issuesize;
  String? lotsize;
  String? maxbidqty;
  String? maxprice;
  String? maxvalue;
  String? minbidquantity;
  String? minprice;
  String? minvalue;
  String? price;
  String? reponseStatus;
  String? respApplicationStringber;
  List<RespBid>? respBid;
  String? responseDatetime;
  String? responseJson;
  String? symbol;
  List<Subcategorysettings>? subcategorysettings;
  String? type;
  String? upi;
  String? upiPaymentStatus;
  String? upiPaymentStatusFlag;

  IpoOrderBookModel(
      {this.section,
      this.applicationNumber,
      this.bidReferenceNumber,
      this.bidDetail,
      this.biddingenddate,
      this.biddingendDate,
      this.biddingstartdate,
      this.clientApplicationStringber,
      this.category,
      this.clientID,
      this.clientRelationID,
      this.companyName,
      this.cutoffprice,
      this.dailyendtime,
      this.dailystarttime,
      this.failReason,
      this.discounttype,
      this.discountvalue,
      this.failReasonCode,
      this.investmentValue,
      this.issuesize,
      this.lotsize,
      this.maxprice,
      this.maxbidqty,
      this.minbidquantity,
      this.maxvalue,
      this.minprice,
      this.price,
      this.minvalue,
      this.reponseStatus,
      this.respApplicationStringber,
      this.respBid,
      this.responseDatetime,
      this.responseJson,
      this.subcategorysettings,
      this.symbol,
      this.type,
      this.upi,
      this.upiPaymentStatus,
      this.upiPaymentStatusFlag});

  IpoOrderBookModel.fromJson(Map<String, dynamic> json) {
    section = json['Section'].toString();
    applicationNumber = json['applicationNumber'].toString();
    bidReferenceNumber = json['bidReferenceNumber'].toString();
    if (json['bid_detail'] != '' && json['bid_detail'] != null) {
      bidDetail = <BidDetail>[];
      // Check if bid_detail is a List or String
      if (json['bid_detail'] is List) {
        json['bid_detail'].forEach((v) {
          bidDetail!.add(BidDetail.fromJson(v));
        });
      } else if (json['bid_detail'] is String) {
        // If bid_detail is a string, try to parse it as JSON
        try {
          final parsedList = jsonDecode(json['bid_detail'] as String);
          if (parsedList is List) {
            for (var v in parsedList) {
              bidDetail!.add(BidDetail.fromJson(v));
            }
          }
        } catch (e) {
        }
      }
    }
    biddingendDate = json['biddingendDate'].toString();
    biddingenddate = json['biddingenddate'].toString();
    biddingstartdate = json['biddingstartdate'].toString();
    category = json['category'].toString();
    clientApplicationStringber = json['clientApplicationNumber'].toString();
    clientID = json['client_ID'].toString();
    clientRelationID = json['client_relationID'].toString();
    companyName = json['company_name'].toString();
    cutoffprice = json['cutoffprice'].toString();
    dailyendtime = json['dailyendtime'].toString();
    dailystarttime = json['dailystarttime'].toString();
    discounttype = json['discounttype'].toString();
    discountvalue = json['discountvalue'].toString();
    failReason = json['fail_reason'].toString();
    failReasonCode = json['fail_reasonCode'].toString();
    investmentValue = json['investmentValue'].toString();
    issuesize = json['issuesize'].toString();
    lotsize = json['lotsize'].toString();
    maxbidqty = json['maxbidqty'].toString();
    maxprice = json['maxprice'].toString();
    maxvalue = json['maxvalue'].toString();
    minbidquantity = json['minbidquantity'].toString();
    minprice = json['minprice'].toString();
    minvalue = json['minvalue'].toString();
    price = json['price'].toString();
    reponseStatus = json['reponse_status'].toString();
    respApplicationStringber = json['resp_applicationNumber'].toString();
    if (json['resp_bid'] != '' && json['resp_bid'] != null) {
      respBid = <RespBid>[];
      // Check if resp_bid is a List or String
      if (json['resp_bid'] is List) {
        json['resp_bid'].forEach((v) {
          respBid!.add(RespBid.fromJson(v));
        });
      } else if (json['resp_bid'] is String) {
        // If resp_bid is a string, try to parse it as JSON
        try {
          final parsedList = jsonDecode(json['resp_bid'] as String);
          if (parsedList is List) {
            for (var v in parsedList) {
              respBid!.add(RespBid.fromJson(v));
            }
          }
        } catch (e) {
        }
      }
    }
    responseDatetime = json['response_datetime'].toString();
    responseJson = json['response_json'].toString();
    if (json['subcategorysettings'] != null) {
      subcategorysettings = <Subcategorysettings>[];
      // Check if subcategorysettings is a List or String
      if (json['subcategorysettings'] is List) {
        json['subcategorysettings'].forEach((v) {
          subcategorysettings!.add(Subcategorysettings.fromJson(v));
        });
      } else if (json['subcategorysettings'] is String) {
        // If subcategorysettings is a string, try to parse it as JSON
        try {
          final parsedList = jsonDecode(json['subcategorysettings'] as String);
          if (parsedList is List) {
            for (var v in parsedList) {
              subcategorysettings!.add(Subcategorysettings.fromJson(v));
            }
          }
        } catch (e) {
        }
      }
    }
    symbol = json['symbol'].toString();
    type = json['type'].toString();
    upi = json['upi'].toString();
    upiPaymentStatus = json['upiPaymentStatus'].toString();
    upiPaymentStatusFlag = json['upiPaymentStatusFlag'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['Section'] = section;
    data['applicationNumber'] = applicationNumber;
    data['bidReferenceNumber'] = bidReferenceNumber;
    if (bidDetail != null) {
      data['bid_detail'] = bidDetail!.map((v) => v.toJson()).toList();
    }
    data['category'] = category;
    data['biddingendDate'] = biddingendDate;
    data['biddingenddate'] = biddingenddate;
    data['biddingstartdate'] = biddingstartdate;
    data['clientApplicationNumber'] = clientApplicationStringber;
    data['client_ID'] = clientID;
    data['client_relationID'] = clientRelationID;
    data['company_name'] = companyName;
    data['cutoffprice'] = cutoffprice;
    data['dailyendtime'] = dailyendtime;
    data['dailystarttime'] = dailystarttime;
    data['discounttype'] = discounttype;
    data['discountvalue'] = discountvalue;
    data['fail_reason'] = failReason;
    data['fail_reasonCode'] = failReasonCode;
    data['investmentValue'] = investmentValue;
    data['issuesize'] = issuesize;
    data['lotsize'] = lotsize;
    data['maxbidqty'] = maxbidqty;
    data['maxprice'] = maxprice;
    data['maxvalue'] = maxvalue;
    data['minbidquantity'] = minbidquantity;
    data['minprice'] = minprice;
    data['minvalue'] = minvalue;
    data['price'] = price;
    data['reponse_status'] = reponseStatus;
    data['resp_applicationNumber'] = respApplicationStringber;
    if (respBid != null) {
      data['resp_bid'] = respBid!.map((v) => v.toJson()).toList();
    }
    data['response_datetime'] = responseDatetime;
    data['response_json'] = responseJson;
    if (subcategorysettings != null) {
      data['subcategorysettings'] =
          subcategorysettings!.map((v) => v.toJson()).toList();
    }
    data['symbol'] = symbol;
    data['type'] = type;
    data['upi'] = upi;
    data['upiPaymentStatus'] = upiPaymentStatus;
    data['upiPaymentStatusFlag'] = upiPaymentStatusFlag;
    return data;
  }
}

class BidDetail {
  String? actioncode;
  String? bidid;
  String? cuttoffflag;
  String? orderno;
  String? activityType;
  String? amount;
  bool? atCutOff;
  String? price;
  String? quantity;
  String? rate;

  BidDetail(
      {this.actioncode,
      this.bidid,
      this.cuttoffflag,
      this.orderno,
      this.activityType,
      this.amount,
      this.atCutOff,
      this.price,
      this.quantity,
      this.rate});

  BidDetail.fromJson(Map<String, dynamic> json) {
    actioncode = json['actioncode'].toString();
    bidid = json['bidid'].toString();
    cuttoffflag = json['cuttoffflag'].toString();
    orderno = json['orderno'].toString();
    activityType = json['activityType'].toString();
    amount = json['amount'].toString();
    atCutOff = json['atCutOff'];
    price = json['price'].toString();
    quantity = json['quantity'].toString();
    rate = json['rate'].toString();
  }

  /// Whether the bid was placed at the cut-off price.
  ///
  /// The exchanges report this differently: NSE returns a real bool in
  /// `atCutOff`, while BSE echoes back the `cuttoffflag` that was posted, which
  /// lands here as a string ("false" for a bid placed without cut-off) and so
  /// has to be read as a flag rather than compared against a single value.
  ///
  /// [exchange] is the parent order's `type`, and decides whenever it is
  /// decisive. It is not relied on alone because the bid shape is chosen by
  /// `type == 'NSE'` when the order is placed: a missing or differently spelled
  /// type is written in the BSE shape, and so carries no `atCutOff` to read.
  bool isCutOffFor(String? exchange) {
    if (exchange == "BSE") return _cuttoffflagIsSet;
    if (atCutOff != null) return atCutOff!;
    return _cuttoffflagIsSet;
  }

  bool get _cuttoffflagIsSet {
    final flag = cuttoffflag?.toLowerCase();
    return flag == "true" || flag == "1" || flag == "y";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['actioncode'] = actioncode;
    data['bidid'] = bidid;
    data['cuttoffflag'] = cuttoffflag;
    data['orderno'] = orderno;
    data['activityType'] = activityType;
    data['amount'] = amount;
    data['atCutOff'] = atCutOff;
    data['price'] = price;
    data['quantity'] = quantity;
    data['rate'] = rate;
    return data;
  }
}

class RespBid {
  String? activityType;
  String? amount;
  bool? atCutOff;
  String? bidReferenceNumber;
  String? price;
  String? quantity;
  String? remark;
  String? series;
  String? status;

  RespBid(
      {this.activityType,
      this.amount,
      this.atCutOff,
      this.bidReferenceNumber,
      this.price,
      this.quantity,
      this.remark,
      this.series,
      this.status});

  RespBid.fromJson(Map<String, dynamic> json) {
    activityType = json['activityType'].toString();
    amount = json['amount'].toString();
    atCutOff = json['atCutOff'];
    bidReferenceNumber = json['bidReferenceNumber'].toString();
    price = json['price'].toString();
    quantity = json['quantity'].toString();
    remark = json['remark'].toString();
    series = json['series'].toString();
    status = json['status'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['activityType'] = activityType;
    data['amount'] = amount;
    data['atCutOff'] = atCutOff;
    data['bidReferenceNumber'] = bidReferenceNumber;
    data['price'] = price;
    data['quantity'] = quantity;
    data['remark'] = remark;
    data['series'] = series;
    data['status'] = status;
    return data;
  }
}

class Subcategorysettings {
  bool? allowCutOff;
  bool? allowUpi;
  String? caCode;
  String? discountPrice;
  String? discountType;
  String? maxQuantity;
  String? maxUpiLimit;
  String? maxValue;
  String? minValue;
  String? subCatCode;
  Subcategorysettings(
      {this.allowCutOff,
      this.allowUpi,
      this.caCode,
      this.discountPrice,
      this.discountType,
      this.maxQuantity,
      this.maxUpiLimit,
      this.maxValue,
      this.minValue,
      this.subCatCode});
  Subcategorysettings.fromJson(Map<String, dynamic> json) {
    allowCutOff = json['allowCutOff'];
    allowUpi = json['allowUpi'];
    caCode = json['caCode'].toString();
    discountPrice = json['discountPrice'].toString();
    discountType = json['discountType'].toString();
    maxQuantity = json['maxQuantity'].toString();
    maxUpiLimit = json['maxUpiLimit'].toString();
    maxValue = json['maxValue'].toString();
    minValue = json['minValue'].toString();
    subCatCode = json['subCatCode'].toString();
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['allowCutOff'] = allowCutOff;
    data['allowUpi'] = allowUpi;
    data['caCode'] = caCode;
    data['discountPrice'] = discountPrice;
    data['discountType'] = discountType;
    data['maxQuantity'] = maxQuantity;
    data['maxUpiLimit'] = maxUpiLimit;
    data['maxValue'] = maxValue;
    data['minValue'] = minValue;
    data['subCatCode'] = subCatCode;
    return data;
  }
}
