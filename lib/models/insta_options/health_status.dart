/// `GET /health` response from the OI Data backend.
///
/// Used by the StreamingDot tooltip and the optional "Backend status" badge.
class InstaOptionsHealth {
  final String status;
  final int nfoTokens;
  final int bfoTokens;
  final bool wsConnected;
  final double? lastTickTime;
  final int subscribedCount;
  final int tickQueueSize;

  const InstaOptionsHealth({
    required this.status,
    required this.nfoTokens,
    required this.bfoTokens,
    required this.wsConnected,
    required this.lastTickTime,
    required this.subscribedCount,
    required this.tickQueueSize,
  });

  factory InstaOptionsHealth.fromJson(Map<String, dynamic> json) {
    final wsFeed = json['ws_feed'] as Map<String, dynamic>? ?? const {};
    return InstaOptionsHealth(
      status: json['status'] as String? ?? 'unknown',
      nfoTokens: (json['nfo_tokens'] as num?)?.toInt() ?? 0,
      bfoTokens: (json['bfo_tokens'] as num?)?.toInt() ?? 0,
      wsConnected: wsFeed['ws_connected'] as bool? ?? false,
      lastTickTime: (wsFeed['last_tick_time'] as num?)?.toDouble(),
      subscribedCount: (wsFeed['subscribed_count'] as num?)?.toInt() ?? 0,
      tickQueueSize: (wsFeed['tick_queue_size'] as num?)?.toInt() ?? 0,
    );
  }
}
