import 'package:mynt_plus/models/journal_notes_model/segment_group.dart';

/// P&L statistics for one tag, or for a baseline row (untagged / all days).
///
/// Read [sufficientSample] before rendering [avgPnl] or [winRate]: below the
/// threshold both are null, meaning *unknown*, not *break-even*. Never coerce
/// them to 0 — three days averaging -8,000 is noise, and it renders identically
/// to thirty days if you let it.
class TagPnlStats {
  /// Null on the untagged and all-days baseline rows.
  final int? tagId;
  final String? name;
  final String? color;

  /// Always populated, whatever the sample size. Show it prominently — it is
  /// what tells the user why the derived stats are missing.
  final int dayCount;

  /// Always populated, even below [sufficientSample]. Only the derived stats
  /// are suppressed.
  final double totalPnl;

  /// Null below the sample threshold.
  final double? avgPnl;

  /// Null below the sample threshold. A **fraction** (0.8333), not a percentage
  /// — multiply by 100 for display. Computed as [winDays] / [dayCount]; a flat
  /// day counts as neither a win nor a loss.
  final double? winRate;

  final int winDays;
  final int lossDays;
  final int flatDays;

  /// False when [dayCount] is below the request's `min_sample`.
  final bool sufficientSample;

  const TagPnlStats({
    this.tagId,
    this.name,
    this.color,
    required this.dayCount,
    required this.totalPnl,
    this.avgPnl,
    this.winRate,
    this.winDays = 0,
    this.lossDays = 0,
    this.flatDays = 0,
    this.sufficientSample = false,
  });

  factory TagPnlStats.fromJson(Map<String, dynamic> json) {
    return TagPnlStats(
      tagId: (json['tag_id'] as num?)?.toInt(),
      name: json['name']?.toString(),
      color: json['color']?.toString(),
      dayCount: (json['day_count'] as num?)?.toInt() ?? 0,
      totalPnl: (json['total_pnl'] as num?)?.toDouble() ?? 0,
      // Left null on purpose when the backend suppresses them.
      avgPnl: (json['avg_pnl'] as num?)?.toDouble(),
      winRate: (json['win_rate'] as num?)?.toDouble(),
      winDays: (json['win_days'] as num?)?.toInt() ?? 0,
      lossDays: (json['loss_days'] as num?)?.toInt() ?? 0,
      flatDays: (json['flat_days'] as num?)?.toInt() ?? 0,
      sufficientSample: json['sufficient_sample'] == true,
    );
  }

  @override
  String toString() => 'TagPnlStats(${name ?? tagId}, days=$dayCount)';
}

/// The window and settings the response was computed over, echoed back.
class AnalyticsScope {
  final String from;
  final String to;
  final SegmentGroup? segmentGroup;
  final String pnlBasis;
  final int minSample;

  const AnalyticsScope({
    required this.from,
    required this.to,
    this.segmentGroup,
    this.pnlBasis = 'total',
    this.minSample = 5,
  });

  factory AnalyticsScope.fromJson(Map<String, dynamic> json) {
    return AnalyticsScope(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      segmentGroup: SegmentGroup.fromWire(json['segment_group']?.toString()),
      pnlBasis: json['pnl_basis']?.toString() ?? 'total',
      minSample: (json['min_sample'] as num?)?.toInt() ?? 5,
    );
  }
}

/// Why the tag rows do not sum to the all-days total.
///
/// A note with N tags is counted once in each of its N tag rows. Tag rows
/// therefore overlap, and the only partition that holds is:
///
///     taggedNoteCount + untagged.dayCount == allDays.dayCount
///
/// Never render tag rows as a pie chart, a stacked bar, or a "% of total".
class DoubleCountingInfo {
  final int taggedNoteCount;
  final int tagRowCountSum;
  final int doubleCountedRows;

  /// The backend's own wording. Surface it (or an equivalent) wherever the tag
  /// table appears — otherwise the numbers look broken and get reported as a bug.
  final String explanation;

  const DoubleCountingInfo({
    this.taggedNoteCount = 0,
    this.tagRowCountSum = 0,
    this.doubleCountedRows = 0,
    this.explanation = '',
  });

  factory DoubleCountingInfo.fromJson(Map<String, dynamic> json) {
    return DoubleCountingInfo(
      taggedNoteCount: (json['tagged_note_count'] as num?)?.toInt() ?? 0,
      tagRowCountSum: (json['tag_row_count_sum'] as num?)?.toInt() ?? 0,
      doubleCountedRows: (json['double_counted_rows'] as num?)?.toInt() ?? 0,
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  /// True when at least one note carries more than one tag, i.e. when the
  /// overlap caveat is actually load-bearing for this response.
  bool get hasOverlap => doubleCountedRows > 0;
}

/// Notes whose snapshot was taken before their day settled.
class DataQualityInfo {
  /// Snapshots captured on the note's own date, i.e. before end-of-day
  /// settlement. They are never refreshed. Prompt the user to journal after the
  /// close, or to re-save.
  final int provisionalSnapshotCount;
  final String explanation;

  const DataQualityInfo({
    this.provisionalSnapshotCount = 0,
    this.explanation = '',
  });

  factory DataQualityInfo.fromJson(Map<String, dynamic> json) {
    return DataQualityInfo(
      provisionalSnapshotCount:
          (json['provisional_snapshot_count'] as num?)?.toInt() ?? 0,
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  bool get hasProvisional => provisionalSnapshotCount > 0;
}

/// The tag → P&L correlation for one asset class over one window.
///
/// [untagged] and [allDays] are not optional decoration: they are the
/// comparison. Users tag losses far more than wins — they remember to write
/// "FOMO" when it hurt, not when it worked — so a tag's average is partly
/// selection bias and overstates the effect on its own. "revenge-trade averages
/// -2,929" is misleading; "-2,929 vs +580 across all your days" is honest.
/// Never render the tag table without the baseline rows visible.
class TagPnlAnalytics {
  final AnalyticsScope scope;
  final List<TagPnlStats> tags;
  final TagPnlStats untagged;
  final TagPnlStats allDays;
  final DoubleCountingInfo doubleCounting;
  final DataQualityInfo dataQuality;

  const TagPnlAnalytics({
    required this.scope,
    required this.tags,
    required this.untagged,
    required this.allDays,
    required this.doubleCounting,
    required this.dataQuality,
  });

  factory TagPnlAnalytics.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return TagPnlAnalytics(
      scope: AnalyticsScope.fromJson(
          Map<String, dynamic>.from(json['scope'] as Map? ?? {})),
      tags: rawTags is List
          ? rawTags
              .whereType<Map>()
              .map((e) => TagPnlStats.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      untagged: TagPnlStats.fromJson(
          Map<String, dynamic>.from(json['untagged'] as Map? ?? {})),
      allDays: TagPnlStats.fromJson(
          Map<String, dynamic>.from(json['all_days'] as Map? ?? {})),
      doubleCounting: DoubleCountingInfo.fromJson(
          Map<String, dynamic>.from(json['double_counting'] as Map? ?? {})),
      dataQuality: DataQualityInfo.fromJson(
          Map<String, dynamic>.from(json['data_quality'] as Map? ?? {})),
    );
  }

  /// Nothing to correlate yet — no tagged or untagged days in the window.
  bool get isEmpty => tags.isEmpty && allDays.dayCount == 0;

  /// The partition the backend guarantees. A mismatch means the response is
  /// internally inconsistent and the numbers should not be trusted.
  bool get partitionHolds =>
      doubleCounting.taggedNoteCount + untagged.dayCount == allDays.dayCount;
}
