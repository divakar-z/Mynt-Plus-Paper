class MfPlaceOrderResponces {
  String? clientCode;
  String? orderNumber;
  String? responseMessage;
  String? emsg;
  String? stat;
  String? transactionCode;
  String? transactionNumber;
   String? transCode;
  String? transNo;
  String? orderId;
  String? userId;
  String? memberCode;
   
  String? remarks;
  String? status;
  String? name;
  
  String? source;
  String? placedBy;
  String? iPAddress;
  String? datetime;
  String? orderVal;
  String? folioNo;
  String? iSIN;
  String? dPFolioNo;

  MfPlaceOrderResponces(
      {
        
        this.transCode,
      this.transNo,
      this.orderId,
      this.userId,
      this.memberCode,
      this.clientCode,
      this.remarks,
      this.status,
      this.name,
       
      this.source,
      this.placedBy,
      this.iPAddress,
      this.datetime,
      this.orderVal,
      this.folioNo,
      this.iSIN,
      this.dPFolioNo, 
      this.orderNumber,
      this.responseMessage,
      this.emsg,
      this.stat,
      this.transactionCode,
      this.transactionNumber});

  MfPlaceOrderResponces.fromJson(Map<String, dynamic> json) {
      transCode = json['TransCode'].toString();
    transNo = json['TransNo'].toString();
    orderId = json['OrderId'].toString();
    userId = json['UserId'].toString();
    memberCode = json['MemberCode'].toString();
     
    remarks = json['Remarks'].toString();
    status = json['status'].toString();
    name = json['name'].toString();
    stat = json['stat'].toString();
    source = json['source'].toString();
    placedBy = json['placed_by'].toString();
    iPAddress = json['IPAddress'].toString();
    datetime = json['datetime'].toString();
    orderVal = json['OrderVal'].toString();
    folioNo = json['FolioNo'].toString();
    iSIN = json['ISIN'].toString();
    dPFolioNo = json['DPFolioNo'].toString();
    clientCode = json['client_code'] ?? json['ClientCode'].toString();
    orderNumber = json['order_number'].toString();
    responseMessage = json['response_message'].toString();
    emsg = json['emsg']?.toString();
     
    transactionCode = json['transaction_code'].toString();
    transactionNumber = json['transaction_number'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['client_code'] = clientCode;
    data['order_number'] = orderNumber;
    data['response_message'] = responseMessage;
    data['emsg'] = emsg;
    data['stat'] = stat;
    data['transaction_code'] = transactionCode;
    data['transaction_number'] = transactionNumber;
    data['TransCode'] = transCode;
    data['TransNo'] = transNo;
    data['OrderId'] = orderId;
    data['UserId'] = userId;
    data['MemberCode'] = memberCode;
    data['ClientCode'] = clientCode;
    data['Remarks'] = remarks;
    data['status'] = status;
    data['name'] = name;
    data['stat'] = stat;
    data['source'] = source;
    data['placed_by'] = placedBy;
    data['IPAddress'] = iPAddress;
    data['datetime'] = datetime;
    data['OrderVal'] = orderVal;
    data['FolioNo'] = folioNo;
    data['ISIN'] = iSIN;
    data['DPFolioNo'] = dPFolioNo;
    return data;
  }
}

class MfPlaceOrderInput {
  String transcode;
  String schemecode;
  String buysell;
  String buyselltype;
  String dptxn;
  String amount;
  String allredeem;
  String kycstatus;
  String qty;
  String euinflag;
  String minredeem;
  String dpc;

  MfPlaceOrderInput({
    required this.transcode,
    required this.schemecode,
    required this.buysell,
    required this.buyselltype,
    required this.dptxn,
    required this.amount,
    required this.allredeem,
    required this.kycstatus,
    required this.qty,
    required this.euinflag,
    required this.minredeem,
    required this.dpc,
  });
}


class MfPlaceSipInput {
  String transcode;
  String schemecode;
  String buysell;
  String buyselltype;
  String dptxn;
  String amount;
  String allredeem;
  String kycstatus;
  String qty;
  String euinflag;
  String minredeem;
  String dpc;

  MfPlaceSipInput({
    required this.transcode,
    required this.schemecode,
    required this.buysell,
    required this.buyselltype,
    required this.dptxn,
    required this.amount,
    required this.allredeem,
    required this.kycstatus,
    required this.qty,
    required this.euinflag,
    required this.minredeem,
    required this.dpc,
  });
}
