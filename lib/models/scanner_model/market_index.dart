/// One NSE index that the scanner backend knows about — used to populate
/// the index-filter dropdown on scanner / custom-scan result pages.
/// Catalogue endpoint: `GET /api/v1/indices/market`.
class MarketIndex {
  /// Display name, sent over the wire verbatim. The filter API expects the
  /// EXACT same string back in the `indices` query param / body field
  /// (e.g. `"NIFTY 50"`, `"NIFTY BANK"`) — don't lower-case or normalize.
  final String name;

  /// Number of stocks in this index on the server's snapshot. Shown as a
  /// suffix in the dropdown ("NIFTY 50 (50)") so users see how aggressive
  /// the filter narrowing will be.
  final int memberCount;

  /// ISO timestamp of the last server-side refresh, or null if unknown.
  /// Backend refreshes daily at 18:35 IST.
  final String? lastRefreshed;

  const MarketIndex({
    required this.name,
    required this.memberCount,
    required this.lastRefreshed,
  });

  factory MarketIndex.fromJson(Map<String, dynamic> j) => MarketIndex(
        name: (j['name'] ?? '') as String,
        memberCount: (j['member_count'] is num)
            ? (j['member_count'] as num).toInt()
            : 0,
        lastRefreshed: j['last_refreshed'] as String?,
      );
}
