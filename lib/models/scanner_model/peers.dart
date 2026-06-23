class PeerEntry {
  final String ticker;
  final String name;
  final double? marketCap;
  final double? peTrailing;
  final String? sector;
  final String? industry;

  const PeerEntry({
    required this.ticker,
    required this.name,
    required this.marketCap,
    required this.peTrailing,
    required this.sector,
    required this.industry,
  });

  factory PeerEntry.fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    return PeerEntry(
      ticker: j['ticker'] as String,
      name: (j['name'] ?? '') as String,
      marketCap: d(j['market_cap']),
      peTrailing: d(j['pe_trailing']),
      sector: j['sector'] as String?,
      industry: j['industry'] as String?,
    );
  }
}

class PeersResponse {
  final String ticker;
  final String? industry;
  final String? sector;
  final List<PeerEntry> peers;

  const PeersResponse({
    required this.ticker,
    required this.industry,
    required this.sector,
    required this.peers,
  });

  factory PeersResponse.fromJson(Map<String, dynamic> j) => PeersResponse(
        ticker: j['ticker'] as String,
        industry: j['industry'] as String?,
        sector: j['sector'] as String?,
        peers: (j['peers'] as List)
            .cast<Map<String, dynamic>>()
            .map(PeerEntry.fromJson)
            .toList(),
      );
}
