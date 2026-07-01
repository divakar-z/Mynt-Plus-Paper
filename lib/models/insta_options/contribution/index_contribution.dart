import 'package:mynt_plus/models/insta_options/contribution/concentration.dart';
import 'package:mynt_plus/models/insta_options/contribution/constituent.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_future_oi.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_options.dart';
import 'package:mynt_plus/models/insta_options/contribution/sector_contribution.dart';
import 'package:mynt_plus/models/insta_options/freshness.dart';

/// Full `GET /api/v1/contribution?index=&date=` payload: how each constituent
/// moved the index that day (their `point_contribution` sum to [pointChange]),
/// plus concentration, sector breakdown, index-future OI, and the index options
/// snapshot.
///
/// When [weightageAvailable] is false the constituent / concentration / sector
/// blocks are empty, but [level]/[pointChange], [indexOi] and [options] still
/// populate (they come from our own data) — render a partial screen, not an
/// error.
class IndexContribution {
  final String tradeDate;
  final String index;
  final String underlyingId;
  final double? level;
  final double? prevLevel;
  final double? changePct;
  final double? pointChange; // level − prevLevel
  final bool weightageAvailable;
  final bool reconciled;
  final double? explainedPointChange;
  final double? coveragePct;
  final List<Constituent> constituents; // sorted by point_contribution desc
  final Concentration? concentration;
  final List<SectorContribution> sectorContribution;
  final IndexFutureOi? indexOi;
  final IndexOptions? options;
  final Freshness freshness;

  const IndexContribution({
    required this.tradeDate,
    required this.index,
    required this.underlyingId,
    required this.level,
    required this.prevLevel,
    required this.changePct,
    required this.pointChange,
    required this.weightageAvailable,
    required this.reconciled,
    required this.explainedPointChange,
    required this.coveragePct,
    required this.constituents,
    required this.concentration,
    required this.sectorContribution,
    required this.indexOi,
    required this.options,
    required this.freshness,
  });

  bool get hasConstituents => constituents.isNotEmpty;

  /// Overlay the socket-live index headline (level / point-change / change%) and
  /// the live constituents; point-contribution / share / weight / OI / PCR /
  /// sector / concentration stay the API snapshot.
  IndexContribution copyWith({
    double? level,
    double? pointChange,
    double? changePct,
    List<Constituent>? constituents,
  }) =>
      IndexContribution(
        tradeDate: tradeDate,
        index: index,
        underlyingId: underlyingId,
        level: level ?? this.level,
        prevLevel: prevLevel,
        changePct: changePct ?? this.changePct,
        pointChange: pointChange ?? this.pointChange,
        weightageAvailable: weightageAvailable,
        reconciled: reconciled,
        explainedPointChange: explainedPointChange,
        coveragePct: coveragePct,
        constituents: constituents ?? this.constituents,
        concentration: concentration,
        sectorContribution: sectorContribution,
        indexOi: indexOi,
        options: options,
        freshness: freshness,
      );

  /// Contributors (positive points), in the API's descending order.
  List<Constituent> get contributors => constituents
      .where((c) => (c.pointContribution ?? 0) > 0)
      .toList(growable: false);

  /// Detractors (negative points), biggest drag first.
  List<Constituent> get detractors {
    final out =
        constituents.where((c) => (c.pointContribution ?? 0) < 0).toList();
    out.sort((a, b) =>
        (a.pointContribution ?? 0).compareTo(b.pointContribution ?? 0));
    return out;
  }

  /// Largest |point_contribution| across constituents — scales the bars.
  double get maxAbsContribution {
    var m = 0.0;
    for (final c in constituents) {
      final v = (c.pointContribution ?? 0).abs();
      if (v > m) m = v;
    }
    return m;
  }

  factory IndexContribution.fromJson(Map<String, dynamic> j) =>
      IndexContribution(
        tradeDate: (j['trade_date'] ?? '').toString(),
        index: (j['index'] ?? '').toString(),
        underlyingId: (j['underlying_id'] ?? j['index'] ?? '').toString(),
        level: (j['level'] as num?)?.toDouble(),
        prevLevel: (j['prev_level'] as num?)?.toDouble(),
        changePct: (j['change_pct'] as num?)?.toDouble(),
        pointChange: (j['point_change'] as num?)?.toDouble(),
        weightageAvailable: j['weightage_available'] == true,
        reconciled: j['reconciled'] == true,
        explainedPointChange: (j['explained_point_change'] as num?)?.toDouble(),
        coveragePct: (j['coverage_pct'] as num?)?.toDouble(),
        constituents: (j['constituents'] as List<dynamic>? ?? const [])
            .map((e) => Constituent.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        concentration: j['concentration'] == null
            ? null
            : Concentration.fromJson(
                j['concentration'] as Map<String, dynamic>),
        sectorContribution:
            (j['sector_contribution'] as List<dynamic>? ?? const [])
                .map((e) =>
                    SectorContribution.fromJson(e as Map<String, dynamic>))
                .toList(growable: false),
        indexOi: j['index_oi'] == null
            ? null
            : IndexFutureOi.fromJson(j['index_oi'] as Map<String, dynamic>),
        options: j['options'] == null
            ? null
            : IndexOptions.fromJson(j['options'] as Map<String, dynamic>),
        freshness: Freshness.fromJson(j['freshness'] as Map<String, dynamic>?),
      );
}
