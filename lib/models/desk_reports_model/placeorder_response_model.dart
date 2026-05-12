class placeOrderResponseCopModel {
  String? msg;
  String? emsg;

  placeOrderResponseCopModel({this.msg, this.emsg});

  placeOrderResponseCopModel.fromJson(Map<String, dynamic> json) {
    msg = json['msg'];
    emsg = json['emsg'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['msg'] = msg;
    data['emsg'] = emsg;
    return data;
  }
}
