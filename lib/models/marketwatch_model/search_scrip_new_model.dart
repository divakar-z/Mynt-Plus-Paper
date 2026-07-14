import 'package:mynt_plus/sharedWidget/functions.dart';

class SearchScripNewModel {
  String? stat;
  List<ScripNewValue>? values;
  String? emsg;
  SearchScripNewModel({this.stat, this.values});

  SearchScripNewModel.fromJson(Map<String, dynamic> json) {
    stat = json['stat'];
    if (json['values'] != null) {
      values = <ScripNewValue>[];
      json['values'].forEach((v) {
        values!.add(ScripNewValue.fromJson(v));
      });
    }
    emsg = json['stat'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['stat'] = stat;
    if (values != null) {
      data['values'] = values!.map((v) => v.toJson()).toList();
    }
    data['emsg'] = emsg;
    return data;
  }
}

class ScripNewValue {
  /// Backend display name from the DerivativeMaster (keyed by exch:token), or
  /// null when the contract isn't in the master (indices / equities).
  String? get masterName => DerivativeMaster.nameFor(exch, token);

  String? exch;
  String? token;
  String? tsym;
  String? cname;
  String? dname;
  String? instname;
  String? symbol;
  String? ls;
  String? ti;
  String? optt;
  String? weekly;
  bool? isAdded;
  String? expDate;
  String? option;
  String? idx;

  ScripNewValue({
    this.exch,
    this.token,
    this.tsym,
    this.cname,
    this.dname,
    this.instname,
    this.symbol,
    this.ls,
    this.ti,
    this.optt,
    this.weekly,
    this.isAdded,
    this.expDate,
    this.option,
    this.idx,
  });

  ScripNewValue.fromJson(Map<String, dynamic> json) {
    exch = json['exch'];
    token = json['token'];
    tsym = json['tsym'];
    cname = json['cname'];
    dname = json['dname'];
    instname = json['instname'];
    symbol = json['symname'];
    ls = json['ls'];
    ti = json['ti'];
    optt = json['OptionType'];
    weekly = json['weekly'];
    isAdded = isAdded == null ? false : json['isAdded'];
    expDate = json['expDate'];
    option = json['option'];
    idx = json['idx'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['exch'] = exch;
    data['token'] = token;
    data['tsym'] = tsym;
    data['cname'] = cname;
    data['dname'] = dname;
    data['instname'] = instname;
    data['symname'] = symbol;
    data['ls'] = ls;
    data['ti'] = ti;
    data['OptionType'] = optt;
    data['weekly'] = weekly;
    data['isAdded'] = isAdded;
    data['option'] = option;
    data['expDate'] = expDate;
    data['idx'] = idx;
    return data;
  }
}
