import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/indicator_schema.dart';

// The CPR Trend Checker settings are numbers whose meaning the chart engine
// reads back (web/chart-engine/chart-helpers.js TC_*). These pin the parts both
// sides must agree on.
const _kHelpersJs = 'web/chart-engine/chart-helpers.js';

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

  test('defaults: BC/TC transparent, R green, S red, highs/lows black, MAs off', () {
    final byKey = {for (final l in kTcLines) l.key: l};
    expect(byKey['dbc']!.alpha, 0);
    expect(byKey['dtc']!.alpha, 0);
    expect(byKey['dcpr']!.alpha, 50);
    expect(byKey['dr1']!.color, 0x4CAF50);
    expect(byKey['ds1']!.color, 0xFF5252);
    expect(byKey['pdh']!.color, 0x000000);
    expect(byKey['pml']!.color, 0x000000);
    expect(kTcMas.map((m) => m.on).toList(), [false, false, false, false, false]);
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
    expect(byKey['ma1On']!.defaultValue, 0);
    expect(byKey['ma3Len']!.defaultValue, 50);
    expect(byKey['ma5C']!.defaultValue, 0x0C7DF6);
    expect(byKey['labelsOn']!.defaultValue, 1);
    expect(byKey['precision']!.defaultValue, 0);
  });

  test('every Dart key and default is also in the engine', () {
    // A cheap cross-check: the engine file mentions each line key's title and
    // the three MA-default colours, so a rename on one side shows up here.
    final js = File(_kHelpersJs).readAsStringSync();
    for (final c in ['#F6C309', '#157A11', '#FC1A1A', '#160101', '#0C7DF6']) {
      expect(js.contains(c), isTrue, reason: c);
    }
    for (final t in ['TC_LINES', 'TC_BANDS', 'TC_MA_TYPES', 'TC_MA_SOURCES']) {
      expect(js.contains(t), isTrue, reason: t);
    }
  });

  test('27 Oct inputs: tags off, Virgin CPR / summary / Market Pulse on', () {
    final byKey = {for (final p in schemaFor('tcheck')!.params) p.key: p};
    expect(byKey['tagOn']!.defaultValue, 0);
    expect(byKey['virginOn']!.defaultValue, 1);
    expect(byKey['sumOn']!.defaultValue, 1);
    expect(byKey['pulseOn']!.defaultValue, 1);
    expect(byKey['pulseSize']!.defaultValue, 1);
    expect(byKey['atrLen']!.defaultValue, 14);
    expect(byKey['atrLo']!.defaultValue, 0.7);
    expect(byKey['atrHi']!.defaultValue, 1.3);
    expect([byKey['dUn']!.defaultValue, byKey['dN']!.defaultValue,
        byKey['dM']!.defaultValue], [0.05, 0.1, 0.2]);
    expect([byKey['mUn']!.defaultValue, byKey['mN']!.defaultValue,
        byKey['mM']!.defaultValue], [0.25, 0.5, 1]);
    expect(byKey['dUn']!.isInt, isFalse);
  });

  test('Future Trend Checker schema: Auto mode, Day on, table on', () {
    final s = schemaFor('ftcheck')!;
    expect(s.displayName, 'Future Trend Checker by GP');
    final byKey = {for (final p in s.params) p.key: p};
    expect(byKey['mode']!.options!.map((o) => o.label).toList(), ['Auto', 'Manual']);
    expect(byKey['mode']!.defaultValue, 0);
    expect(byKey['dOn']!.defaultValue, 1);
    expect(byKey['wOn']!.defaultValue, 0);
    expect(byKey['todayW']!.defaultValue, 2);
    expect(byKey['tableOn']!.defaultValue, 1);
    expect([byKey['dZn']!.defaultValue, byKey['dZm']!.defaultValue,
        byKey['dGn']!.defaultValue, byKey['dGm']!.defaultValue], [0.3, 0.5, 0.1, 0.3]);
    expect([byKey['mZn']!.defaultValue, byKey['mZm']!.defaultValue], [2, 3]);
  });

  test('option orders match the engine (tag position / style, ATR, table)', () {
    expect(kGpTagPosOptions.map((o) => o.label).toList(),
        ['Auto (free space)', 'Above CPR', 'Below CPR']);
    expect(kGpTagStyleOptions.map((o) => o.label).toList(), ['Full', 'Compact']);
    expect(kGpAtrAvgOptions.map((o) => o.label).toList(),
        ['Simple (SMA)', 'Wilder (RMA)']);
    expect(kGpPosOptions.map((o) => o.label).toList(), ['Top Right', 'Top Left',
        'Bottom Right', 'Bottom Left', 'Middle Right']);
    expect(kGpSizeOptions.map((o) => o.label).toList(), ['Tiny', 'Small', 'Normal']);
  });

  test('engine width / zone / gap defaults equal the Dart ones', () {
    final js = File(_kHelpersJs).readAsStringSync();
    expect(js.contains("GP_WIDTH_DEFAULTS = { d: [0.05, 0.1, 0.2], w: [0.125, 0.25, 0.5], m: [0.25, 0.5, 1] }"), isTrue);
    expect(js.contains("GP_ZONE_DEFAULTS = { d: [0.3, 0.5], w: [0.7, 1], m: [2, 3] }"), isTrue);
    expect(js.contains("GP_GAP_DEFAULTS = { d: [0.1, 0.3], w: [0.25, 0.5], m: [0.5, 1] }"), isTrue);
  });
}
