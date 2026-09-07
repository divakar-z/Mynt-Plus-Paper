import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/models/journal_notes_model/segment_group.dart';
import 'package:mynt_plus/models/journal_notes_model/tag_pnl_analytics.dart';

/// Captured verbatim from a live `POST /journal/analytics/tagPnl` on
/// 2026-07-16, against a seeded set of 10 F&O notes: 6 planned-setup days,
/// 3 revenge-trade days, 2 untagged, and one day carrying both tags.
///
/// Kept as a raw JSON string, not a Dart literal, so the number types survive
/// exactly as the wire sent them — `total_pnl: 29500` and `avg_pnl: 1670`
/// arrive as ints while `avg_pnl: 4916.666666666667` arrives as a double. A
/// Dart map literal would quietly hide that distinction, which is the whole
/// point of this fixture.
const String _liveTagPnlResponse = '''
{
  "all_days": {
    "avg_pnl": 1670, "day_count": 10, "flat_days": 0, "loss_days": 4,
    "sufficient_sample": true, "total_pnl": 16700, "win_days": 6, "win_rate": 0.6
  },
  "data_quality": {
    "explanation": "10 snapshot(s) were captured on the note's own date, i.e. before end-of-day settlement, and are not refreshed.",
    "provisional_snapshot_count": 10
  },
  "double_counting": {
    "double_counted_rows": 1,
    "explanation": "A note with N tags is counted once in each of its N tag rows, so tag rows do not sum to all_days: 9 tag rows span 8 distinct tagged notes. Compare each tag against untagged and all_days, not against other tags.",
    "tag_row_count_sum": 9, "tagged_note_count": 8
  },
  "scope": {
    "from": "2026-06-01", "min_sample": 5, "pnl_basis": "total",
    "segment_group": "fno", "to": "2026-06-30"
  },
  "tags": [
    {
      "avg_pnl": 4916.666666666667, "color": "#2E9E4F", "day_count": 6,
      "flat_days": 0, "loss_days": 1, "name": "planned-setup",
      "sufficient_sample": true, "tag_id": 3, "total_pnl": 29500,
      "win_days": 5, "win_rate": 0.8333
    },
    {
      "avg_pnl": null, "color": "#CC3344", "day_count": 3,
      "flat_days": 0, "loss_days": 2, "name": "revenge-trade",
      "sufficient_sample": false, "tag_id": 1, "total_pnl": -4000,
      "win_days": 1, "win_rate": null
    }
  ],
  "untagged": {
    "avg_pnl": null, "day_count": 2, "flat_days": 0, "loss_days": 1,
    "sufficient_sample": false, "total_pnl": 200, "win_days": 1, "win_rate": null
  }
}
''';

TagPnlAnalytics _parseLive() => TagPnlAnalytics.fromJson(
    jsonDecode(_liveTagPnlResponse) as Map<String, dynamic>);

void main() {
  group('TagPnlAnalytics against a live captured response', () {
    test('parses integer-typed JSON numbers into doubles', () {
      // The backend emits whole numbers as ints (total_pnl: 29500) and
      // fractional ones as doubles (avg_pnl: 4916.66…). Typing these `as double`
      // rather than `as num` would throw on the int case at runtime.
      final a = _parseLive();
      expect(a.allDays.avgPnl, 1670.0);
      expect(a.allDays.totalPnl, 16700.0);
      expect(a.tags.first.totalPnl, 29500.0);
      expect(a.tags.first.avgPnl, closeTo(4916.6666, 0.001));
    });

    test('suppressed stats stay null and are never coerced to zero', () {
      final revenge = _parseLive().tags.firstWhere((t) => t.name == 'revenge-trade');
      expect(revenge.sufficientSample, isFalse);
      expect(revenge.avgPnl, isNull); // unknown, NOT break-even
      expect(revenge.winRate, isNull);
    });

    test('totals survive below the sample threshold', () {
      // Only the derived stats are suppressed; these must still render.
      final revenge = _parseLive().tags.firstWhere((t) => t.name == 'revenge-trade');
      expect(revenge.dayCount, 3);
      expect(revenge.totalPnl, -4000.0);
      expect(revenge.winDays, 1);
      expect(revenge.lossDays, 2);
      expect(revenge.flatDays, 0);
    });

    test('win rate is a fraction, not a percentage', () {
      final planned = _parseLive().tags.firstWhere((t) => t.name == 'planned-setup');
      expect(planned.winRate, 0.8333);
      expect(planned.winRate! * 100, closeTo(83.33, 0.01));
    });

    test('the baseline rows parse with no tag identity', () {
      final a = _parseLive();
      expect(a.untagged.tagId, isNull);
      expect(a.allDays.tagId, isNull);
      expect(a.untagged.dayCount, 2);
      expect(a.allDays.dayCount, 10);
      expect(a.allDays.winRate, 0.6);
    });

    test('the documented partition holds', () {
      // taggedNoteCount + untagged.dayCount == allDays.dayCount  ->  8 + 2 == 10
      final a = _parseLive();
      expect(a.doubleCounting.taggedNoteCount, 8);
      expect(a.untagged.dayCount, 2);
      expect(a.allDays.dayCount, 10);
      expect(a.partitionHolds, isTrue);
    });

    test('tag rows overlap and do not sum to all days', () {
      final a = _parseLive();
      expect(a.doubleCounting.hasOverlap, isTrue);
      expect(a.doubleCounting.doubleCountedRows, 1);
      expect(a.doubleCounting.tagRowCountSum, 9);
      expect(a.doubleCounting.explanation, isNotEmpty);

      // 6 + 3 = 9 tag-row days vs 10 all-days: the sum is meaningless. This is
      // why the tag table must never be a pie chart or a "% of total".
      final rowSum = a.tags.fold<int>(0, (s, t) => s + t.dayCount);
      expect(rowSum, isNot(a.allDays.dayCount));
    });

    test('provisional snapshots are surfaced', () {
      final a = _parseLive();
      expect(a.dataQuality.hasProvisional, isTrue);
      expect(a.dataQuality.provisionalSnapshotCount, 10);
      expect(a.dataQuality.explanation, contains('before end-of-day settlement'));
    });

    test('scope echoes the request', () {
      final s = _parseLive().scope;
      expect(s.from, '2026-06-01');
      expect(s.to, '2026-06-30');
      expect(s.segmentGroup, SegmentGroup.fno);
      expect(s.pnlBasis, 'total');
      expect(s.minSample, 5);
    });

    test('is not treated as empty when there is data', () {
      expect(_parseLive().isEmpty, isFalse);
    });
  });

  group('TagPnlAnalytics edge cases', () {
    test('an all-empty response parses rather than throwing', () {
      // A client with no notes in range. Must be a valid empty state.
      final a = TagPnlAnalytics.fromJson(jsonDecode('''
        {"scope": {"from":"2026-06-01","to":"2026-06-30","segment_group":"fno"},
         "tags": [], "untagged": {}, "all_days": {},
         "double_counting": {}, "data_quality": {}}
      ''') as Map<String, dynamic>);

      expect(a.tags, isEmpty);
      expect(a.allDays.dayCount, 0);
      expect(a.allDays.avgPnl, isNull);
      expect(a.isEmpty, isTrue);
      expect(a.dataQuality.hasProvisional, isFalse);
    });
  });
}
