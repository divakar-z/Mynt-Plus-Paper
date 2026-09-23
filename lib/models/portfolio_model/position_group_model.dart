import 'position_book_model.dart';

class CreateGroupName {
  int? id;
  String? status;

  /// The reason a group call was rejected, e.g. `Name already exists` when the
  /// user types a name they already have. The backend sends it as `detail` and
  /// sends no `status` at all on that path, so without this field the failure
  /// arrived empty and the UI could only say "Unknown error".
  String? detail;

  CreateGroupName({this.id, this.status, this.detail});

  CreateGroupName.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    status = json['status'];
    detail = json['detail']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['status'] = status;
    data['detail'] = detail;
    return data;
  }
}

class AddGroupSymbol {
  String? status;

  AddGroupSymbol({this.status});

  AddGroupSymbol.fromJson(Map<String, dynamic> json) {
    status = json['status'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    return data;
  }
}

class GetGroupSymbol {
  int? id;
  List<PositionBookModel>? posdata;
  String? posname;

  GetGroupSymbol({this.id, this.posdata, this.posname});

  GetGroupSymbol.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    if (json['posdata'] != null) {
      posdata = <PositionBookModel>[];
      json['posdata'].forEach((v) {
        posdata!.add(PositionBookModel.fromJson(v));
      });
    }
    posname = json['posname'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    if (posdata != null) {
      data['posdata'] = posdata!.map((v) => v.toJson()).toList();
    }
    data['posname'] = posname;
    return data;
  }
}
 

