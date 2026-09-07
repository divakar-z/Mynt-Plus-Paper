import 'fundamental_scan.dart';

class SavedFundamentalScreen {
  final int id;
  final String name;
  final List<FundamentalFilter> filters;
  final String treatNullAs;
  final String? orderBy;
  final String? orderDir;
  final int? limit;
  final String? createdAt;

  const SavedFundamentalScreen({
    required this.id,
    required this.name,
    required this.filters,
    required this.treatNullAs,
    required this.orderBy,
    required this.orderDir,
    required this.limit,
    required this.createdAt,
  });

  factory SavedFundamentalScreen.fromJson(Map<String, dynamic> j) {
    final filters = ((j['filters'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((f) => FundamentalFilter(
              field: f['field'] as String,
              op: f['op'] as String,
              value: f['value'],
              years: f['years'] as int?,
            ))
        .toList();
    return SavedFundamentalScreen(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String,
      filters: filters,
      treatNullAs: (j['treat_null_as'] ?? 'fail') as String,
      orderBy: j['order_by'] as String?,
      orderDir: j['order_dir'] as String?,
      limit: (j['limit'] as num?)?.toInt(),
      createdAt: j['created_at'] as String?,
    );
  }
}
