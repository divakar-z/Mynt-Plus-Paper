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

  /// Overlay live values onto the snapshot. The index headline (level /
  /// point-change / change%) comes from the official index tick; the
  /// constituent / sector / concentration / explained-points blocks carry the
  /// live recompute (see [recomputeLive]). OI / PCR / max-pain stay snapshot.
  IndexContribution copyWith({
    double? level,
    double? pointChange,
    double? changePct,
    double? explainedPointChange,
    List<Constituent>? constituents,
    List<SectorContribution>? sectorContribution,
    Concentration? concentration,
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
        explainedPointChange: explainedPointChange ?? this.explainedPointChange,
        coveragePct: coveragePct,
        constituents: constituents ?? this.constituents,
        concentration: concentration ?? this.concentration,
        sectorContribution: sectorContribution ?? this.sectorContribution,
        indexOi: indexOi,
        options: options,
        freshness: freshness,
      );

  /// Contributors (positive points), in the list's current order. Callers keep
  /// [constituents] ordered by |points| desc (live: throttled re-rank), so this
  /// reads largest-positive first without re-sorting on every tick.
  List<Constituent> get contributors => constituents
      .where((c) => (c.pointContribution ?? 0) > 0)
      .toList(growable: false);

  /// Detractors (negative points), in the list's current order — with
  /// [constituents] ordered by |points| desc, that's biggest-drag first.
  List<Constituent> get detractors => constituents
      .where((c) => (c.pointContribution ?? 0) < 0)
      .toList(growable: false);

  /// Largest |point_contribution| across constituents — scales the bars.
  double get maxAbsContribution {
    var m = 0.0;
    for (final c in constituents) {
      final v = (c.pointContribution ?? 0).abs();
      if (v > m) m = v;
    }
    return m;
  }

  /// Recompute the constituent decomposition from **live prices**, exactly.
  ///
  /// A stock's index point-contribution is linear in its price, so its
  /// points-per-₹ slope is a daily constant we read straight back out of the
  /// snapshot (`point_contribution / change`); when a stock is flat at snapshot
  /// we fall back to `prevLevel × weight ÷ prevClose`. Applying that slope to
  /// the live price move gives the live points with no approximation. Sectors,
  /// share %, direction, advances/declines and top-N concentration all
  /// re-derive from those live points, so the whole screen stays self-consistent
  /// between the 5-min snapshot re-anchors. HHI / breadth (backend-specific
  /// formulas) and the index headline are left untouched.
  ///
  /// [liveLtpOf] returns a constituent's live last price, or null when no tick
  /// has arrived — those keep their snapshot values (never zeroed).
  IndexContribution recomputeLive(double? Function(Constituent c) liveLtpOf) {
    if (constituents.isEmpty) return this;
    final pl = prevLevel;

    final live = <Constituent>[];
    var sumAbs = 0.0;
    var adv = 0, dec = 0, unch = 0;

    for (final c in constituents) {
      final snapChange = c.change;
      final snapPts = c.pointContribution;
      final prevClose =
          (c.ltp != null && snapChange != null) ? c.ltp! - snapChange : null;
      final ltp = liveLtpOf(c);

      double? slope; // index points per ₹ of price move (daily constant)
      if (snapPts != null && snapChange != null && snapChange.abs() >= 0.005) {
        slope = snapPts / snapChange;
      } else if (pl != null &&
          c.weightPct != null &&
          prevClose != null &&
          prevClose > 0) {
        slope = pl * (c.weightPct! / 100) / prevClose;
      }

      Constituent nc;
      if (ltp == null ||
          ltp == 0 ||
          prevClose == null ||
          prevClose <= 0 ||
          slope == null) {
        // No usable tick — keep snapshot values (refresh ltp if we got one).
        nc = (ltp != null && ltp != 0) ? c.copyWith(ltp: ltp) : c;
      } else {
        final chg = ltp - prevClose;
        final pts = slope * chg;
        nc = c.copyWith(
          ltp: ltp,
          change: chg,
          priceChangePct: chg / prevClose * 100,
          pointContribution: pts,
          direction: pts > 0.0001
              ? 'contributor'
              : (pts < -0.0001 ? 'detractor' : 'flat'),
        );
      }
      live.add(nc);
      sumAbs += (nc.pointContribution ?? 0).abs();
      final pct = nc.priceChangePct ?? 0;
      if (pct > 0.0001) {
        adv++;
      } else if (pct < -0.0001) {
        dec++;
      } else {
        unch++;
      }
    }

    // share % = signed fraction of the total move magnitude.
    final liveCons = [
      for (final c in live)
        c.copyWith(
            sharePct: sumAbs > 0
                ? (c.pointContribution ?? 0) / sumAbs * 100
                : c.sharePct)
    ];

    // Sectors re-summed from the live constituents.
    final bySector = <String, List<Constituent>>{};
    for (final c in liveCons) {
      (bySector[c.sector] ??= <Constituent>[]).add(c);
    }
    final liveSectors = [
      for (final s in sectorContribution)
        s.copyWith(
          pointContribution: (bySector[s.sector] ?? const [])
              .fold<double>(0, (a, c) => a + (c.pointContribution ?? 0)),
          advances: (bySector[s.sector] ?? const [])
              .where((c) => (c.priceChangePct ?? 0) > 0.0001)
              .length,
          declines: (bySector[s.sector] ?? const [])
              .where((c) => (c.priceChangePct ?? 0) < -0.0001)
              .length,
        )
    ];

    // Concentration: top-N share + advances/declines re-derived; HHI/breadth kept.
    Concentration? conc = concentration;
    if (conc != null) {
      final absSorted = [
        for (final c in liveCons) (c.pointContribution ?? 0).abs()
      ]..sort((a, b) => b.compareTo(a));
      double topN(int n) {
        var s = 0.0;
        for (var i = 0; i < n && i < absSorted.length; i++) {
          s += absSorted[i];
        }
        return sumAbs > 0 ? s / sumAbs * 100 : 0;
      }

      conc = conc.copyWith(
        top3SharePct: topN(3),
        top5SharePct: topN(5),
        advances: adv,
        declines: dec,
        unchanged: unch,
        adRatio: dec > 0 ? adv / dec : (adv > 0 ? adv.toDouble() : 0),
      );
    }

    final explained =
        liveCons.fold<double>(0, (a, c) => a + (c.pointContribution ?? 0));

    return copyWith(
      constituents: liveCons,
      sectorContribution: liveSectors,
      concentration: conc,
      explainedPointChange: explained,
    );
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
