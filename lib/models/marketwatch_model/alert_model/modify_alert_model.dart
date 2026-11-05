class ModifyAlertModel {
  String? requestTime;
  String? stat;
  // Broker's reason when stat is Not_Ok.
  String? emsg;
  String? alId;


  ModifyAlertModel({this.requestTime, this.stat, this.alId});


  ModifyAlertModel.fromJson(Map<String, dynamic> json) {
    requestTime = json['request_time'];
    stat = json['stat'];
    emsg = json['emsg'];
    alId = json['al_id'];
  }


  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['request_time'] = requestTime;
    data['stat'] = stat;
    data['emsg'] = emsg;
    data['al_id'] = alId;
    return data;
  }
}





