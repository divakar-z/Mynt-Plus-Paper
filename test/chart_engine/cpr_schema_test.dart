import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/indicator_schema.dart';

// The CPR settings are stored as numbers whose meaning the chart engine reads
// back (web/chart-engine/chart-helpers.js CPR_*). These pin the parts both
// sides must agree on.
void main() {
  test('CPR plots match the TradingView study (order, colours, visibility)', () {
    expect(kCprPlots.map((p) => p.key).toList(), [
      'pivot', 'high', 'low', 'bc', 'tc',
      's1', 'r1', 's2', 'r2', 's3', 'r3', 's4', 'r4',
    ]);
    expect(kCprPlots.where((p) => p.visible).map((p) => p.key).toList(),
        ['pivot', 'bc', 'tc']);
    expect(kCprPlots.first.color, 0xF8AF85);
  });

  test('CPR option orders match the engine tables', () {
    expect(kCprPlotTypeParam.options!.map((o) => o.label).toList(), [
      'Line', 'Line with breaks', 'Step line', 'Step line with breaks',
      'Step line with diamonds', 'Histogram', 'Cross', 'Area',
      'Area with breaks', 'Columns', 'Circles',
    ]);
    expect(kCprPlotTypeParam.options![kCprDefaultPlotType].label, 'Circles');
    expect(kCprLineStyleParam.options!.map((o) => o.label).toList(),
        ['Solid', 'Dotted', 'Dashed']);
    expect(kCprPrecisionParam.options!.first.label, 'Default');
    expect(kCprPrecisionParam.options!.length, 10);
  });

  test('CPR schema seeds every per-line setting with its default', () {
    final s = schemaFor('CPR')!;
    expect(s.kind, 'cpr');
    expect(s.params.length, 1 + 13 * 6);
    final byKey = {for (final p in s.params) p.key: p};
    expect(byKey['precision']!.defaultValue, 0);
    expect(byKey['pivotV']!.defaultValue, 1);
    expect(byKey['highV']!.defaultValue, 0);
    expect(byKey['bcC']!.defaultValue, 0x9C50E4);
    expect(byKey['r4C']!.defaultValue, 0x008000);
    expect(byKey['tcW']!.defaultValue, 3);
    expect(byKey['s1T']!.defaultValue, kCprDefaultPlotType);
    expect(byKey['s1S']!.defaultValue, 0);
    expect(byKey['r2P']!.defaultValue, 0);
  });
}
