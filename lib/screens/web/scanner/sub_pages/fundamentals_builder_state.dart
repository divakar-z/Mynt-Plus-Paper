import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';

class FundamentalsBuilderState {
  final List<FundamentalFilter> filters;
  final String treatNullAs; // 'fail' | 'pass'
  final String orderBy;
  final String orderDir; // 'asc' | 'desc'
  final int limit;

  const FundamentalsBuilderState({
    this.filters = const [],
    this.treatNullAs = 'fail',
    this.orderBy = 'market_cap',
    this.orderDir = 'desc',
    this.limit = 100,
  });

  FundamentalsBuilderState copyWith({
    List<FundamentalFilter>? filters,
    String? treatNullAs,
    String? orderBy,
    String? orderDir,
    int? limit,
  }) =>
      FundamentalsBuilderState(
        filters: filters ?? this.filters,
        treatNullAs: treatNullAs ?? this.treatNullAs,
        orderBy: orderBy ?? this.orderBy,
        orderDir: orderDir ?? this.orderDir,
        limit: limit ?? this.limit,
      );

  FundamentalScanRequest toRequest() => FundamentalScanRequest(
        filters: filters,
        treatNullAs: treatNullAs,
        orderBy: orderBy,
        orderDir: orderDir,
        limit: limit,
      );
}

List<String> validOpsForDtype(String dtype, {bool multiYear = false}) {
  switch (dtype) {
    case 'string':
      return const ['==', '!=', 'in', 'not_in', 'is_null', 'is_not_null'];
    default:
      final base = ['<', '<=', '>', '>=', '==', '!=', 'between', 'is_null', 'is_not_null'];
      if (multiYear) base.add('min_years');
      return base;
  }
}

bool isMultiYearField(String field) =>
    FundamentalField.multiYearCapable.contains(field);

/// Descriptive label for an operator — matches the React reference dropdown
/// (e.g. `>= greater or equal` instead of bare `>=`).
String opLabel(String op) {
  switch (op) {
    case '<': return '< less than';
    case '<=': return '<= less or equal';
    case '>': return '> greater than';
    case '>=': return '>= greater or equal';
    case '==': return '= equals';
    case '!=': return '≠ not equal';
    case 'between': return 'between';
    case 'in': return 'in (list)';
    case 'not_in': return 'not in (list)';
    case 'is_null': return 'is empty';
    case 'is_not_null': return 'not empty';
    case 'min_years': return 'min years';
    default: return op;
  }
}
