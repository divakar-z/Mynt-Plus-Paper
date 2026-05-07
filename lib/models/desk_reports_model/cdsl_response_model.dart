class CdslReponseModel {
  CDSLResp? cDSLResp;
  String? cDSLRespTime;
  String? cLIENTNAME;
  String? clientBoId;
  String? pledgeReqTime;
  String? uccid;

  CdslReponseModel(
      {this.cDSLResp,
      this.cDSLRespTime,
      this.cLIENTNAME,
      this.clientBoId,
      this.pledgeReqTime,
      this.uccid});

  CdslReponseModel.fromJson(Map<String, dynamic> json) {
    cDSLResp = json['CDSL_resp'] != null
        ? CDSLResp.fromJson(json['CDSL_resp'])
        : null;
    cDSLRespTime = json['CDSL_resp_time'];
    cLIENTNAME = json['CLIENT_NAME'];
    clientBoId = json['client_bo_id'];
    pledgeReqTime = json['pledge_req_time'];
    uccid = json['uccid'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (cDSLResp != null) {
      data['CDSL_resp'] = cDSLResp!.toJson();
    }
    data['CDSL_resp_time'] = cDSLRespTime;
    data['CLIENT_NAME'] = cLIENTNAME;
    data['client_bo_id'] = clientBoId;
    data['pledge_req_time'] = pledgeReqTime;
    data['uccid'] = uccid;
    return data;
  }
}

class CDSLResp {
  String? pledgeidentifier;
  Pledgeresdtls? pledgeresdtls;
  String? reqid;

  CDSLResp({this.pledgeidentifier, this.pledgeresdtls, this.reqid});

  CDSLResp.fromJson(Map<String, dynamic> json) {
    pledgeidentifier = json['pledgeidentifier'];
    pledgeresdtls = json['pledgeresdtls'] != null
        ? Pledgeresdtls.fromJson(json['pledgeresdtls'])
        : null;
    reqid = json['reqid'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['pledgeidentifier'] = pledgeidentifier;
    if (pledgeresdtls != null) {
      data['pledgeresdtls'] = pledgeresdtls!.toJson();
    }
    data['reqid'] = reqid;
    return data;
  }
}

class Pledgeresdtls {
  Pledgeresdtlstwo? pledgeresdtlstwo;

  Pledgeresdtls({this.pledgeresdtlstwo});

  // Handles two response shapes from /reqid_details:
  //  - OLD: pledgeresdtls is an Object containing isinresdtls (array).
  //  - NEW: pledgeresdtls is an Array of ISIN items; card-level fields
  //    (resid, reqid, resstatus, reqstatus, restime, ...) live on the
  //    OUTER object (this json). Normalize both into Pledgeresdtlstwo.
  Pledgeresdtls.fromJson(Map<String, dynamic> json) {
    final inner = json['pledgeresdtls'];
    if (inner is List) {
      pledgeresdtlstwo = Pledgeresdtlstwo.fromJson(json)
        ..isinresdtls = inner
            .map((v) => Isinresdtls.fromJson(v as Map<String, dynamic>))
            .toList();
    } else if (inner is Map<String, dynamic>) {
      pledgeresdtlstwo = Pledgeresdtlstwo.fromJson(inner);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (pledgeresdtlstwo != null) {
      data['pledgeresdtls'] = pledgeresdtlstwo!.toJson();
    }
    return data;
  }
}

class Pledgeresdtlstwo {
  List<Isinresdtls>? isinresdtls;
  String? pledgeidentifier;
  String? remarks;
  String? reqid;
  String? reqstatus;
  String? reserrmsg;
  String? reserror;
  String? resid;
  String? resstatus;
  String? restime;

  Pledgeresdtlstwo(
      {this.isinresdtls,
      this.pledgeidentifier,
      this.remarks,
      this.reqid,
      this.reqstatus,
      this.reserrmsg,
      this.reserror,
      this.resid,
      this.resstatus,
      this.restime});

  Pledgeresdtlstwo.fromJson(Map<String, dynamic> json) {
    if (json['isinresdtls'] != null && json['isinresdtls'] is List) {
      isinresdtls = <Isinresdtls>[];
      json['isinresdtls'].forEach((v) {
        isinresdtls!.add(Isinresdtls.fromJson(v));
      });
    }
    pledgeidentifier = json['pledgeidentifier'];
    remarks = json['remarks'];
    reqid = json['reqid']?.toString();
    reqstatus = json['reqstatus']?.toString();
    reserrmsg = json['reserrmsg'];
    reserror = json['reserror'];
    resid = json['resid']?.toString();
    resstatus = json['resstatus']?.toString();
    restime = json['restime'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (isinresdtls != null) {
      data['isinresdtls'] = isinresdtls!.map((v) => v.toJson()).toList();
    }
    data['pledgeidentifier'] = pledgeidentifier;
    data['remarks'] = remarks;
    data['reqid'] = reqid;
    data['reserrmsg'] = reserrmsg;
    data['reserror'] = reserror;
    data['resid'] = resid;
    data['resstatus'] = resstatus;
    data['reqstatus'] = reqstatus;
    data['restime'] = restime;
    return data;
  }
}

class Isinresdtls {
  String? errorcode;
  String? errormsg;
  String? isin;
  String? isinreqid;
  String? isinresid;
  String? quantity;
  String? status;
  String? reqstatus;
  String? script;
  String? price;
  String? value;

  Isinresdtls(
      {this.errorcode,
      this.errormsg,
      this.isin,
      this.isinreqid,
      this.isinresid,
      this.quantity,
      this.status,
      this.reqstatus,
      this.script,
      this.price,
      this.value});

  Isinresdtls.fromJson(Map<String, dynamic> json) {
    errorcode = json['errorcode'];
    errormsg = json['errormsg'];
    isin = json['isin'];
    isinreqid = json['isinreqid']?.toString();
    isinresid = json['isinresid']?.toString();
    quantity = json['quantity']?.toString();
    status = json['status']?.toString();
    reqstatus = json['reqstatus']?.toString();
    // New format may carry only reqstatus; surface it as status for UI fallbacks.
    if ((status == null || status!.isEmpty) && reqstatus != null) {
      status = reqstatus;
    }
    script = json['script']?.toString();
    price = json['Price']?.toString() ?? json['price']?.toString();
    value = json['value']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['errorcode'] = errorcode;
    data['errormsg'] = errormsg;
    data['isin'] = isin;
    data['isinreqid'] = isinreqid;
    data['isinresid'] = isinresid;
    data['quantity'] = quantity;
    data['status'] = status;
    data['reqstatus'] = reqstatus;
    data['script'] = script;
    data['Price'] = price;
    data['value'] = value;
    return data;
  }
}
