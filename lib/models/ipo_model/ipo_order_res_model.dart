class IpoOrderResponcesModel {
  String? msg;
  // Result of the call, e.g. "order initiated success" (added by backend
  // 28 Oct 2026 alongside a longer msg). Older replies only carry msg.
  String? status;

  IpoOrderResponcesModel({this.msg, this.status});

  IpoOrderResponcesModel.fromJson(Map<String, dynamic> json) {
    msg = json['msg'];
    status = json['status']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['msg'] = msg;
    data['status'] = status;
    return data;
  }
}
