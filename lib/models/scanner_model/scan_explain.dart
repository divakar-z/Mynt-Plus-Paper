import 'package:mynt_plus/models/scanner_model/ohlcv.dart';

/// Whether the explain endpoint refers to a built-in scanner or a saved
/// custom scan. The two have different URL paths but identical response
/// shapes, so this enum just picks the path at the API boundary.
enum ExplainScope { builtin, custom }

/// Cache + request key for a scan-explanation fetch. The endpoint resolves
/// `'latest'` server-side; we don't include the date in the key because the
/// response carries its own `as_of` and the user always wants the latest
/// match when clicking through from a fresh results table.
class ExplainKey {
  final ExplainScope scope;
  final String id;
  final String ticker;

  const ExplainKey({
    required this.scope,
    required this.id,
    required this.ticker,
  });

  @override
  bool operator ==(Object other) =>
      other is ExplainKey &&
      other.scope == scope &&
      other.id == id &&
      other.ticker == ticker;

  @override
  int get hashCode => Object.hash(scope, id, ticker);

  @override
  String toString() =>
      'ExplainKey($scope, id=$id, ticker=$ticker)';
}

/// Column metadata for one indicator series in the explain response. The
/// `sub_panel` and `color_hint` fields come directly from the server — no
/// client-side oscillator heuristic. `colorHint` is nullable; renderers fall
/// back to a default rotation when absent.
enum ExplainColumnKind { float, boolean, enumKind }

ExplainColumnKind _parseColumnKind(String? s) {
  switch (s) {
    case 'boolean':
      return ExplainColumnKind.boolean;
    case 'enum':
      return ExplainColumnKind.enumKind;
    case 'float':
    default:
      return ExplainColumnKind.float;
  }
}

class ExplainColumn {
  final String key;
  final String label;
  final ExplainColumnKind kind;
  final bool subPanel;
  final String? colorHint;

  const ExplainColumn({
    required this.key,
    required this.label,
    required this.kind,
    required this.subPanel,
    required this.colorHint,
  });

  factory ExplainColumn.fromJson(Map<String, dynamic> j) => ExplainColumn(
        key: j['key'] as String,
        label: (j['label'] ?? j['key']) as String,
        kind: _parseColumnKind(j['kind'] as String?),
        subPanel: (j['sub_panel'] ?? false) as bool,
        colorHint: j['color_hint'] as String?,
      );
}

/// Indicator-side operand on a leaf comparison. Always carries the
/// indicator kind so renderers can format the value correctly
/// ("Yes"/"No" for boolean, the enum label for enum, etc.).
class ExplainLeftOperand {
  final String label;
  final double? value;
  final String? display;
  final ExplainColumnKind indicatorKind;

  const ExplainLeftOperand({
    required this.label,
    required this.value,
    required this.display,
    required this.indicatorKind,
  });

  factory ExplainLeftOperand.fromJson(Map<String, dynamic> j) =>
      ExplainLeftOperand(
        label: (j['label'] ?? '') as String,
        value: _asDouble(j['value']),
        display: j['display'] as String?,
        indicatorKind: _parseColumnKind(j['indicator_kind'] as String?),
      );
}

/// Right-hand side of a comparison. Three variants by `operand_type`:
///   - `scalar`  → literal value or another indicator's value
///   - `range`   → `{lo, hi}`, only for `op == "between"`
///   - `none`    → no right side, for `op in {"is_true", "is_false"}`
sealed class ExplainRightOperand {
  const ExplainRightOperand();

  factory ExplainRightOperand.fromJson(Map<String, dynamic> j) {
    final t = (j['operand_type'] ?? 'scalar') as String;
    switch (t) {
      case 'range':
        return ExplainRangeOperand(
          lo: _asDouble(j['lo']) ?? 0,
          hi: _asDouble(j['hi']) ?? 0,
          display: (j['display'] ?? '') as String,
        );
      case 'none':
        return const ExplainNoOperand();
      case 'scalar':
      default:
        return ExplainScalarOperand(
          label: (j['label'] ?? '') as String,
          value: _asDouble(j['value']),
          display: j['display'] as String?,
        );
    }
  }
}

class ExplainScalarOperand extends ExplainRightOperand {
  final String label;
  final double? value;
  final String? display;
  const ExplainScalarOperand({
    required this.label,
    required this.value,
    required this.display,
  });
}

class ExplainRangeOperand extends ExplainRightOperand {
  final double lo;
  final double hi;
  final String display;
  const ExplainRangeOperand({
    required this.lo,
    required this.hi,
    required this.display,
  });
}

class ExplainNoOperand extends ExplainRightOperand {
  const ExplainNoOperand();
}

/// Recursive predicate-evaluation tree. Two variants discriminated by
/// `node_type`:
///   - `group` — boolean combinator (`all` / `any` / `none`) with children
///   - `leaf`  — single comparison (`left op right`)
sealed class ExplainNode {
  final bool passed;
  const ExplainNode({required this.passed});

  factory ExplainNode.fromJson(Map<String, dynamic> j) {
    final t = (j['node_type'] ?? 'leaf') as String;
    if (t == 'group') {
      return ExplainGroup(
        kind: _parseGroupKind(j['kind'] as String?),
        passed: (j['passed'] ?? false) as bool,
        children: ((j['children'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ExplainNode.fromJson)
            .toList(),
      );
    }
    return ExplainLeaf(
      op: (j['op'] ?? '') as String,
      left: ExplainLeftOperand.fromJson(
          (j['left'] as Map).cast<String, dynamic>()),
      right: ExplainRightOperand.fromJson(
          (j['right'] as Map?)?.cast<String, dynamic>() ?? const {}),
      passed: (j['passed'] ?? false) as bool,
      display: (j['display'] ?? '') as String,
    );
  }
}

enum ExplainGroupKind { all, any, none }

ExplainGroupKind _parseGroupKind(String? s) {
  switch (s) {
    case 'any':
      return ExplainGroupKind.any;
    case 'none':
      return ExplainGroupKind.none;
    case 'all':
    default:
      return ExplainGroupKind.all;
  }
}

class ExplainGroup extends ExplainNode {
  final ExplainGroupKind kind;
  final List<ExplainNode> children;
  const ExplainGroup({
    required this.kind,
    required super.passed,
    required this.children,
  });
}

class ExplainLeaf extends ExplainNode {
  final String op;
  final ExplainLeftOperand left;
  final ExplainRightOperand right;
  final String display;
  const ExplainLeaf({
    required this.op,
    required this.left,
    required this.right,
    required super.passed,
    required this.display,
  });
}

class ScanExplainResponse {
  final String scannerName;
  final String ticker;
  final String asOf;
  final int windowBars;

  /// Raw predicate JSON echoed by the server. Useful for "view raw" toggles;
  /// rendering should consume [explanation] instead.
  final Map<String, dynamic> predicate;

  final ExplainNode explanation;
  final List<OhlcvBar> bars;
  final List<bool> matched;

  /// Indicator series keyed by `columns[].key`. Each list is the same length
  /// as `bars`, with `null` entries for "not warmed up" or "computation
  /// failed".
  final Map<String, List<double?>> indicators;

  final List<ExplainColumn> columns;

  const ScanExplainResponse({
    required this.scannerName,
    required this.ticker,
    required this.asOf,
    required this.windowBars,
    required this.predicate,
    required this.explanation,
    required this.bars,
    required this.matched,
    required this.indicators,
    required this.columns,
  });

  factory ScanExplainResponse.fromJson(Map<String, dynamic> j) {
    final indicatorsRaw = (j['indicators'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final indicators = <String, List<double?>>{};
    indicatorsRaw.forEach((k, v) {
      if (v is List) {
        indicators[k] = v.map(_asDouble).toList();
      }
    });

    return ScanExplainResponse(
      scannerName: (j['scanner_name'] ?? '') as String,
      ticker: (j['ticker'] ?? '') as String,
      asOf: (j['as_of'] ?? '') as String,
      windowBars: (j['window_bars'] ?? 0) as int,
      predicate: (j['predicate'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      explanation: ExplainNode.fromJson(
          (j['explanation'] as Map).cast<String, dynamic>()),
      bars: ((j['bars'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(OhlcvBar.fromJson)
          .toList(),
      matched: ((j['matched'] as List?) ?? const [])
          .map((e) => e == true)
          .toList(),
      indicators: indicators,
      columns: ((j['columns'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(ExplainColumn.fromJson)
          .toList(),
    );
  }
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
