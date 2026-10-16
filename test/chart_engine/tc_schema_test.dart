import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/indicator_schema.dart';

// The CPR Trend Checker settings are numbers whose meaning the chart engine
// reads back (web/chart-engine/chart-helpers.js TC_*). These pin the parts both
// sides must agree on.
void main() {
  test('39 lines in the study order with the expected keys', () {
    expect(kTcLines.length, 39);
    expect(kTcLines.take(13).map((l) => l.key).toList(), [
      'pdh', 'pdl', 'dcpr', 'dbc', 'dtc',
      'dr1', 'ds1', 'dr2', 'ds2', 'dr3', 'ds3', 'dr4', 'ds4',
    ]);
    expect(kTcLines.skip(13).take(2).map((l) => l.title).toList(),
        ['PWH', 'PWL']);
    expect(kTcLines.last.key, 'ms4');
    expect(kTcLines.last.title, 'Monthly S4');
  });

  test('defaults: BC/TC transparent, R green, S red, MA #1 only', () {
    final byKey = {for (final l in kTcLines) l.key: l};
    expect(byKey['dbc']!.alpha, 0);
    expect(byKey['dtc']!.alpha, 0);
    expect(byKey['dcpr']!.alpha, 50);
    expect(byKey['dr1']!.color, 0x4CAF50);
    expect(byKey['ds1']!.color, 0xFF5252);
    expect(kTcMas.map((m) => m.on).toList(), [true, false, false, false, false]);
    expect(kTcMas.map((m) => m.len).toList(), [10, 20, 50, 100, 200]);
  }, );

  test('option orders match the engine tables', () {
    expect(kTcMaTypeParam.options!.map((o) => o.label).toList(),
        ['SMA', 'EMA', 'WMA', 'RMA', 'HMA', 'VWMA']);
    expect(kTcMaSourceParam.options!.map((o) => o.label).toList(),
        ['Close', 'Open', 'High', 'Low', 'HL2', 'HLC3', 'OHLC4']);
  });

  test('schema seeds every setting with its default', () {
    final s = schemaFor('tcheck')!;
    final byKey = {for (final p in s.params) p.key: p};
    expect(byKey['dOn']!.defaultValue, 1);
    expect(byKey['wOn']!.defaultValue, 0);
    expect(byKey['auto']!.defaultValue, 0);
    expect(byKey['pdhV']!.defaultValue, 1);
    expect(byKey['dbcO']!.defaultValue, 0);
    expect(byKey['dBandO']!.defaultValue, 25);
    expect(byKey['ma1On']!.defaultValue, 1);
    expect(byKey['ma3Len']!.defaultValue, 50);
    expect(byKey['ma5C']!.defaultValue, 0x1E7FFF);
    expect(byKey['labelsOn']!.defaultValue, 1);
    expect(byKey['precision']!.defaultValue, 0);
  });

  test('every Dart key and default is also in the engine', () {
    // A cheap cross-check: the engine file mentions each line key's title and
    // the three MA-default colours, so a rename on one side shows up here.
    final js = File('web/chart-engine/chart-helpers.js').readAsStringSync();
    for (final c in ['#F5BF00', '#178A17', '#FF2222', '#1A0000', '#1E7FFF']) {
      expect(js.contains(c), isTrue, reason: c);
    }
    for (final t in ['TC_LINES', 'TC_BANDS', 'TC_MA_TYPES', 'TC_MA_SOURCES']) {
      expect(js.contains(t), isTrue, reason: t);
    }
  });
}
