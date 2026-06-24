import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/models/scanner_model/predicate.dart';

void main() {
  group('IndicatorRef', () {
    test('indicator with no params → bare {indicator: name}', () {
      final ref = IndicatorRef.indicator('close');
      expect(ref.toJson(), {'indicator': 'close'});
    });

    test('indicator with params — params are FLAT siblings of indicator', () {
      final ref = IndicatorRef.indicator('rsi', {'period': 14});
      expect(ref.toJson(), {'indicator': 'rsi', 'period': 14});
    });

    test('SMA(close, 20) emits col + period at top level', () {
      final ref = IndicatorRef.indicator('sma', {'col': 'close', 'period': 20});
      expect(ref.toJson(), {
        'indicator': 'sma',
        'col': 'close',
        'period': 20,
      });
    });

    test('literal number / literal range', () {
      expect(IndicatorRef.number(30).toJson(), {'value': 30});
      expect(IndicatorRef.range(20, 80).toJson(), {
        'value': [20, 80],
      });
    });

    test('flat decode round-trip', () {
      final json = {
        'indicator': 'supertrend_dir',
        'period': 10,
        'mult': 3.0,
      };
      final ref = IndicatorRef.fromJson(json);
      expect(ref.toJson(), json);
    });

    test('legacy nested {indicator, params:{}} is tolerated → flattened', () {
      final ref = IndicatorRef.fromJson({
        'indicator': 'rsi',
        'params': {'period': 14},
      });
      // Re-serializes in the corrected flat form.
      expect(ref.toJson(), {'indicator': 'rsi', 'period': 14});
    });
  });

  group('PredicateNode', () {
    test('PredicateLeaf round-trip — RSI(14) < 30', () {
      final node = PredicateLeaf(
        left: IndicatorRef.indicator('rsi', {'period': 14}),
        op: '<',
        right: IndicatorRef.number(30),
      );
      expect(node.toJson(), {
        'left': {'indicator': 'rsi', 'period': 14},
        'op': '<',
        'right': {'value': 30},
      });
    });

    test('PredicateAnd serialises as {"all": [...]}', () {
      final node = PredicateAnd([
        PredicateLeaf(
          left: IndicatorRef.indicator('rsi', {'period': 14}),
          op: '<',
          right: IndicatorRef.number(30),
        ),
      ]);
      expect(node.toJson(), {
        'all': [
          {
            'left': {'indicator': 'rsi', 'period': 14},
            'op': '<',
            'right': {'value': 30},
          }
        ],
      });
    });

    test('PredicateOr serialises as {"any": [...]}', () {
      final node = PredicateOr([
        PredicateLeaf(
          left: IndicatorRef.indicator('cdl_doji'),
          op: '!=',
          right: IndicatorRef.number(0),
        ),
      ]);
      expect(node.toJson(), {
        'any': [
          {
            'left': {'indicator': 'cdl_doji'},
            'op': '!=',
            'right': {'value': 0},
          }
        ],
      });
    });

    test('PredicateNone serialises as {"none": [...]}', () {
      final node = PredicateNone([
        PredicateLeaf(
          left: IndicatorRef.indicator('rsi', {'period': 14}),
          op: '<',
          right: IndicatorRef.number(30),
        ),
      ]);
      expect((node.toJson()).keys.first, 'none');
    });

    test('Nested OR inside AND — spec example', () {
      final json = {
        'all': [
          {
            'left': {'indicator': 'rsi', 'period': 14},
            'op': '<',
            'right': {'value': 30},
          },
          {
            'any': [
              {
                'left': {'indicator': 'cdl_doji'},
                'op': '!=',
                'right': {'value': 0},
              },
              {
                'left': {'indicator': 'cdl_hammer'},
                'op': '!=',
                'right': {'value': 0},
              },
            ],
          },
        ],
      };
      final node = PredicateNode.fromJson(json);
      expect(node, isA<PredicateAnd>());
      expect(node.toJson(), json);
    });

    test('SuperTrend uptrend (enum) — flat params, == 1', () {
      final json = {
        'all': [
          {
            'left': {
              'indicator': 'supertrend_dir',
              'period': 10,
              'mult': 3.0,
            },
            'op': '==',
            'right': {'value': 1},
          },
        ],
      };
      final node = PredicateNode.fromJson(json);
      expect(node.toJson(), json);
    });

    test('Legacy {op:"and", clauses:[]} form decodes to PredicateAnd', () {
      final legacy = {
        'op': 'and',
        'clauses': [
          {
            'left': {'indicator': 'rsi', 'period': 14},
            'op': '<',
            'right': {'value': 30}
          }
        ]
      };
      final node = PredicateNode.fromJson(legacy);
      expect(node, isA<PredicateAnd>());
      // Re-serializes in the corrected `{all:[...]}` form.
      final j = node.toJson();
      expect(j.containsKey('all'), true);
      expect(j.containsKey('op'), false);
      expect(j.containsKey('clauses'), false);
    });
  });
}
