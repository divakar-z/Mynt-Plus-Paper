/// Categorical direction the scanner implies — bullish entry signal,
/// bearish entry signal, or neutral (indecision / no directional bias).
/// Populated either from a future backend `sentiment` field or from the
/// client-side heuristic in [scannerSentimentHeuristic].
enum ScannerSentiment { bullish, bearish, neutral }

class Scanner {
  final String code;
  final String groupName;
  final String? subGroup;
  final String displayName;
  final String description;
  /// Optional longer, layman-language explanation supplied by the backend.
  /// When non-null, render this in the detail-page info card instead of
  /// the brief tagline. Falls back to `description` when absent.
  final String? descriptionLong;
  /// Backend-supplied directional bias, or null if the backend hasn't
  /// shipped the classification yet. Render-side helpers should treat
  /// null by calling [scannerSentimentHeuristic] for a name-pattern
  /// guess so the bullish/bearish filter still works today.
  final ScannerSentiment? sentiment;
  final bool isActive;
  final Map<String, dynamic>? predicate;

  const Scanner({
    required this.code,
    required this.groupName,
    required this.subGroup,
    required this.displayName,
    required this.description,
    required this.descriptionLong,
    required this.sentiment,
    required this.isActive,
    required this.predicate,
  });

  factory Scanner.fromJson(Map<String, dynamic> j) => Scanner(
        code: j['code'] as String,
        groupName: (j['group_name'] ?? '') as String,
        subGroup: j['sub_group'] as String?,
        displayName: (j['display_name'] ?? j['code']) as String,
        description: (j['description'] ?? '') as String,
        descriptionLong: j['description_long'] as String?,
        sentiment: _parseSentiment(j['sentiment']),
        isActive: (j['is_active'] ?? true) as bool,
        predicate: j['predicate'] is Map
            ? Map<String, dynamic>.from(j['predicate'] as Map)
            : null,
      );
}

ScannerSentiment? _parseSentiment(Object? raw) {
  if (raw is! String) return null;
  switch (raw.toLowerCase()) {
    case 'bullish':
      return ScannerSentiment.bullish;
    case 'bearish':
      return ScannerSentiment.bearish;
    case 'neutral':
      return ScannerSentiment.neutral;
    default:
      return null;
  }
}

class ScannerListResponse {
  final List<Scanner> items;
  final int total;
  final int page;
  final int pageSize;

  const ScannerListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory ScannerListResponse.fromJson(Map<String, dynamic> j) =>
      ScannerListResponse(
        items: (j['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(Scanner.fromJson)
            .toList(),
        total: (j['total'] ?? 0) as int,
        page: (j['page'] ?? 1) as int,
        pageSize: (j['page_size'] ?? 100) as int,
      );
}
