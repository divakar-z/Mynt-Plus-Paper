/// Dart-side mirror of the response from `GET /api/v1/indicators`.
///
/// The server is the source of truth — categories, indicators, params,
/// defaults, enum_values and needs_benchmark all flow from there. This file
/// defines the shapes plus a few convenience accessors.

class IndicatorCategory {
  final String key;
  final String label;
  const IndicatorCategory({required this.key, required this.label});

  factory IndicatorCategory.fromJson(Map<String, dynamic> j) =>
      IndicatorCategory(
        key: j['key'] as String,
        label: (j['label'] ?? j['key']) as String,
      );
}

enum IndicatorKind { floatKind, booleanKind, enumKind }

IndicatorKind _parseKind(String raw) {
  switch (raw) {
    case 'boolean':
      return IndicatorKind.booleanKind;
    case 'enum':
      return IndicatorKind.enumKind;
    case 'float':
    default:
      return IndicatorKind.floatKind;
  }
}

enum CatalogParamType { intType, floatType, stringType, columnType }

CatalogParamType _parseParamType(String raw) {
  switch (raw) {
    case 'int':
      return CatalogParamType.intType;
    case 'float':
      return CatalogParamType.floatType;
    case 'column':
      return CatalogParamType.columnType;
    case 'string':
    default:
      return CatalogParamType.stringType;
  }
}

class CatalogParam {
  final String name;
  final String label;
  final CatalogParamType type;
  /// Default value (num for int/float; String for string/column; may be null).
  final Object? defaultValue;
  final num? min;
  final num? max;
  /// Present for `column` always (OHLCV column names) and for `string` when
  /// the param has a closed set of choices.
  final List<String>? options;

  const CatalogParam({
    required this.name,
    required this.label,
    required this.type,
    this.defaultValue,
    this.min,
    this.max,
    this.options,
  });

  factory CatalogParam.fromJson(Map<String, dynamic> j) {
    final opts = j['options'];
    return CatalogParam(
      name: j['name'] as String,
      label: (j['label'] ?? j['name']) as String,
      type: _parseParamType((j['type'] ?? 'string') as String),
      defaultValue: j['default'],
      min: j['min'] is num ? j['min'] as num : null,
      max: j['max'] is num ? j['max'] as num : null,
      options:
          opts is List ? opts.map((e) => e.toString()).toList() : null,
    );
  }
}

class CatalogEnumValue {
  final num value;
  final String label;
  const CatalogEnumValue({required this.value, required this.label});

  factory CatalogEnumValue.fromJson(Map<String, dynamic> j) =>
      CatalogEnumValue(
        value: (j['value'] as num),
        label: (j['label'] ?? j['value'].toString()) as String,
      );
}

class CatalogIndicator {
  final String name; // wire name, e.g. "rsi", "cdl_doji"
  final String label; // user-facing, e.g. "RSI", "Doji"
  final String category; // matches IndicatorCategory.key
  final IndicatorKind kind;
  final String description;
  final List<CatalogParam> params;
  final List<CatalogEnumValue>? enumValues;
  final bool needsBenchmark;

  const CatalogIndicator({
    required this.name,
    required this.label,
    required this.category,
    required this.kind,
    required this.description,
    required this.params,
    this.enumValues,
    this.needsBenchmark = false,
  });

  factory CatalogIndicator.fromJson(Map<String, dynamic> j) {
    final paramsRaw = (j['params'] as List?) ?? const [];
    final enumRaw = j['enum_values'];
    return CatalogIndicator(
      name: j['name'] as String,
      label: (j['label'] ?? j['name']) as String,
      category: (j['category'] ?? 'other') as String,
      kind: _parseKind((j['kind'] ?? 'float') as String),
      description: (j['description'] ?? '') as String,
      params: paramsRaw
          .cast<Map<String, dynamic>>()
          .map(CatalogParam.fromJson)
          .toList(),
      enumValues: enumRaw is List
          ? enumRaw
              .cast<Map<String, dynamic>>()
              .map(CatalogEnumValue.fromJson)
              .toList()
          : null,
      needsBenchmark: (j['needs_benchmark'] ?? false) as bool,
    );
  }

  /// Returns the default value for a param, falling back to the param's
  /// declared min when no default is provided.
  Object? defaultFor(String paramName) {
    for (final p in params) {
      if (p.name == paramName) return p.defaultValue ?? p.min;
    }
    return null;
  }
}

class IndicatorCatalog {
  final List<IndicatorCategory> categories;
  final List<CatalogIndicator> indicators;

  const IndicatorCatalog({required this.categories, required this.indicators});

  factory IndicatorCatalog.fromJson(Map<String, dynamic> j) =>
      IndicatorCatalog(
        categories: ((j['categories'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(IndicatorCategory.fromJson)
            .toList(),
        indicators: ((j['indicators'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(CatalogIndicator.fromJson)
            .toList(),
      );

  /// Indicators grouped by category key, preserving the order of [categories].
  Map<IndicatorCategory, List<CatalogIndicator>> byCategory() {
    final map = <String, List<CatalogIndicator>>{};
    for (final i in indicators) {
      map.putIfAbsent(i.category, () => []).add(i);
    }
    // Build an ordered map keyed by IndicatorCategory.
    final out = <IndicatorCategory, List<CatalogIndicator>>{};
    for (final cat in categories) {
      final list = map[cat.key];
      if (list != null && list.isNotEmpty) out[cat] = list;
    }
    // Append any catch-all categories not declared in `categories` so we
    // don't silently drop indicators.
    for (final entry in map.entries) {
      if (categories.any((c) => c.key == entry.key)) continue;
      out[IndicatorCategory(key: entry.key, label: entry.key)] = entry.value;
    }
    return out;
  }

  CatalogIndicator? byName(String name) {
    for (final i in indicators) {
      if (i.name == name) return i;
    }
    return null;
  }
}
