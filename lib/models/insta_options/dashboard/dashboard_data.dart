import 'package:mynt_plus/models/insta_options/dashboard/buildup_sentiment.dart';
import 'package:mynt_plus/models/insta_options/dashboard/day_summary.dart';
import 'package:mynt_plus/models/insta_options/dashboard/gainers_losers.dart';
import 'package:mynt_plus/models/insta_options/dashboard/index_card.dart';
import 'package:mynt_plus/models/insta_options/dashboard/most_active.dart';
import 'package:mynt_plus/models/insta_options/dashboard/sector_performance.dart';
import 'package:mynt_plus/models/insta_options/freshness.dart';

/// `GET /api/v1/dashboard?date=YYYY-MM-DD` — the entire dashboard for one
/// trading day in a single payload (the only data call after `/dates`).
class DashboardData {
  final String tradeDate;
  final DaySummary summary;
  final List<IndexCard> indices;
  final BuildupSentiment buildupSentiment;
  final Freshness freshness;
  final List<SectorPerformanceRow> sectorPerformance;
  final MostActive mostActive;
  final GainersLosers gainersLosers;

  const DashboardData({
    required this.tradeDate,
    required this.summary,
    required this.indices,
    required this.buildupSentiment,
    required this.freshness,
    required this.sectorPerformance,
    required this.mostActive,
    required this.gainersLosers,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>?;
    final sentiment = json['buildup_sentiment'] as Map<String, dynamic>?;
    final mostActive = json['most_active'] as Map<String, dynamic>?;
    final gl = json['gainers_losers'] as Map<String, dynamic>?;
    return DashboardData(
      tradeDate: json['trade_date'] as String? ?? '',
      summary: summary == null ? DaySummary.empty : DaySummary.fromJson(summary),
      indices: (json['indices'] as List<dynamic>? ?? const [])
          .map((e) => IndexCard.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      buildupSentiment: sentiment == null
          ? BuildupSentiment.empty
          : BuildupSentiment.fromJson(sentiment),
      freshness: Freshness.fromJson(json['freshness'] as Map<String, dynamic>?),
      sectorPerformance:
          (json['sector_performance'] as List<dynamic>? ?? const [])
              .map((e) =>
                  SectorPerformanceRow.fromJson(e as Map<String, dynamic>))
              .toList(growable: false),
      mostActive:
          mostActive == null ? MostActive.empty : MostActive.fromJson(mostActive),
      gainersLosers: gl == null ? GainersLosers.empty : GainersLosers.fromJson(gl),
    );
  }
}
