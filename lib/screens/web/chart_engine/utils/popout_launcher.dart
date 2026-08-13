import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';

const _slotsKey = 'popoutSlots';

int _allocSlot() {
  List slots;
  try {
    slots = (json.decode(html.window.localStorage[_slotsKey] ?? '[]') as List);
  } catch (_) {
    slots = [];
  }
  var n = 1;
  final used = slots.map((e) => (e as num).toInt()).toSet();
  while (used.contains(n)) {
    n++;
  }
  used.add(n);
  html.window.localStorage[_slotsKey] = json.encode(used.toList()..sort());
  return n;
}

void openPopoutForPane({required ChartScrip scrip, required int timeframeMinutes}) {
  final n = _allocSlot();
  final qs = Uri(queryParameters: {
    'exch': scrip.exch,
    'token': scrip.token,
    'tsym': scrip.tsym,
    'tf': '$timeframeMinutes',
    'n': '$n',
  }).query;
  html.window.open('/chart-popout/?$qs', 'mynt_popout_$n');
}
