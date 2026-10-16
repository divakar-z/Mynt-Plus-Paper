/// A reference on either side of a comparison leaf.
///
/// Wire shapes (StockScanner DSL):
///   `{ "value": 30 }`                              — numeric literal
///   `{ "value": [20, 80] }`                        — range literal (for `between`)
///   `{ "indicator": "close" }`                     — indicator, no params
///   `{ "indicator": "rsi", "period": 14 }`         — indicator with params
///   `{ "indicator": "sma", "col": "close", "period": 50 }`
///
/// Params are FLAT siblings of `indicator`, NOT nested under a `params` key.
class IndicatorRef {
  final num? literalNumber;
  final List<num>? literalRange;
  final String? indicator;
  final Map<String, dynamic> indicatorParams;

  const IndicatorRef._({
    this.literalNumber,
    this.literalRange,
    this.indicator,
    this.indicatorParams = const {},
  });

  factory IndicatorRef.number(num n) => IndicatorRef._(literalNumber: n);
  factory IndicatorRef.range(num a, num b) =>
      IndicatorRef._(literalRange: [a, b]);
  factory IndicatorRef.indicator(String name, [Map<String, dynamic>? params]) =>
      IndicatorRef._(
        indicator: name,
        indicatorParams: params == null || params.isEmpty
            ? const {}
            : Map<String, dynamic>.from(params),
      );

  Map<String, dynamic> toJson() {
    if (literalNumber != null) return {'value': literalNumber};
    if (literalRange != null) return {'value': literalRange};
    // Flat: spread params as siblings of `indicator`.
    return {'indicator': indicator, ...indicatorParams};
  }

  factory IndicatorRef.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('value')) {
      final v = j['value'];
      if (v is num) return IndicatorRef.number(v);
      if (v is List && v.length == 2 && v.every((x) => x is num)) {
        return IndicatorRef.range(v[0] as num, v[1] as num);
      }
      throw ArgumentError('Unsupported literal value: $v');
    }
    if (j.containsKey('indicator')) {
      final ind = j['indicator'] as String;
      final params = Map<String, dynamic>.from(j)..remove('indicator');
      // Tolerate a legacy nested `params: {...}` shape that briefly went
      // out in earlier saved scans; flatten it back.
      if (params.length == 1 && params['params'] is Map) {
        return IndicatorRef.indicator(
            ind, Map<String, dynamic>.from(params['params'] as Map));
      }
      return IndicatorRef.indicator(ind, params);
    }
    throw ArgumentError('IndicatorRef must have "value" or "indicator"');
  }
}

/// A predicate tree.
///   Leaf:  `{ "left": {...}, "op": "<", "right": {...} }`
///   Group: `{ "all":  [<node>, ...] }`     // AND
///          `{ "any":  [<node>, ...] }`     // OR
///          `{ "none": [<node>, ...] }`     // NOT (negate-AND)
abstract class PredicateNode {
  Map<String, dynamic> toJson();

  static PredicateNode fromJson(Map<String, dynamic> j) {
    if (j['all'] is List) {
      return PredicateAnd((j['all'] as List)
          .cast<Map<String, dynamic>>()
          .map(PredicateNode.fromJson)
          .toList());
    }
    if (j['any'] is List) {
      return PredicateOr((j['any'] as List)
          .cast<Map<String, dynamic>>()
          .map(PredicateNode.fromJson)
          .toList());
    }
    if (j['none'] is List) {
      return PredicateNone((j['none'] as List)
          .cast<Map<String, dynamic>>()
          .map(PredicateNode.fromJson)
          .toList());
    }
    // Legacy form briefly used `{op: "and"|"or", clauses: [...]}`. Decode it
    // so older saved scans still load.
    if (j['clauses'] is List) {
      final op = ((j['op'] ?? 'and') as String).toLowerCase();
      final kids = (j['clauses'] as List)
          .cast<Map<String, dynamic>>()
          .map(PredicateNode.fromJson)
          .toList();
      if (op == 'or') return PredicateOr(kids);
      if (op == 'not' || op == 'none') return PredicateNone(kids);
      return PredicateAnd(kids);
    }
    if (j.containsKey('left') && j.containsKey('right')) {
      return PredicateLeaf(
        left: IndicatorRef.fromJson(j['left'] as Map<String, dynamic>),
        op: j['op'] as String,
        right: IndicatorRef.fromJson(j['right'] as Map<String, dynamic>),
      );
    }
    throw ArgumentError('Unknown predicate node: $j');
  }
}

class PredicateLeaf extends PredicateNode {
  final IndicatorRef left;
  final String op;
  final IndicatorRef right;
  PredicateLeaf({required this.left, required this.op, required this.right});

  @override
  Map<String, dynamic> toJson() => {
        'left': left.toJson(),
        'op': op,
        'right': right.toJson(),
      };
}

class PredicateAnd extends PredicateNode {
  final List<PredicateNode> children;
  PredicateAnd(this.children);
  @override
  Map<String, dynamic> toJson() =>
      {'all': children.map((c) => c.toJson()).toList()};
}

class PredicateOr extends PredicateNode {
  final List<PredicateNode> children;
  PredicateOr(this.children);
  @override
  Map<String, dynamic> toJson() =>
      {'any': children.map((c) => c.toJson()).toList()};
}

class PredicateNone extends PredicateNode {
  final List<PredicateNode> children;
  PredicateNone(this.children);
  @override
  Map<String, dynamic> toJson() =>
      {'none': children.map((c) => c.toJson()).toList()};
}

/// Comparator operators valid for `kind="float"` leaves.
const List<String> kFloatOperators = ['<', '<=', '>', '>=', '==', '!='];

/// Comparator operators valid for `kind="enum"` leaves (server honours
/// equality only).
const List<String> kEnumOperators = ['==', '!='];
