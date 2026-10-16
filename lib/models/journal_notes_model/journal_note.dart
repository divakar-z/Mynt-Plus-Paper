import 'package:mynt_plus/models/desk_reports_model/calender_pnl_model.dart';
import 'package:mynt_plus/models/journal_notes_model/journal_tag.dart';
import 'package:mynt_plus/models/journal_notes_model/note_attachment.dart';
import 'package:mynt_plus/models/journal_notes_model/segment_group.dart';

/// ISO-8601 with an explicit UTC offset, e.g. `2026-07-15T18:30:00+05:30`.
///
/// `DateTime.toIso8601String()` cannot produce this: it emits no offset at all
/// for a local time and a bare `Z` for a UTC one. The backend compares
/// `snapshot_at` against `note_date` and rejects a snapshot that precedes it
/// (`400 BAD_PNL`), so an absent or wrong offset can push the timestamp across
/// a day boundary and fail a save that should have succeeded.
String toIso8601WithOffset(DateTime dt) {
  final local = dt.isUtc ? dt.toLocal() : dt;
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final hh = abs.inHours.toString().padLeft(2, '0');
  final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
  // Drop sub-second precision; the backend does not need it and it only makes
  // the payload harder to read in a network log.
  final base = local.toIso8601String().split('.').first;
  return '$base$sign$hh:$mm';
}

/// `YYYY-MM-DD`, the only date format these routes accept in either direction.
///
/// The rest of this backend speaks `DD/MM/YYYY` — the P&L Summary screen sends
/// that to `getJournalDiary`. Both formats go to the same host. Do not share a
/// formatter between the two; `"14/07/2026"` here is a `400 BAD_DATE`.
final RegExp kNoteDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// The day's P&L as it stood on the user's screen when the note was written.
///
/// The backend cannot recompute this. Realised P&L comes from FIFO lot matching
/// across the whole financial year, which is why the journal endpoints fetch
/// from `01/04/<fyear>` regardless of the requested `from` date; re-deriving one
/// day's P&L would mean re-running a full-year computation per note. Because the
/// client sends it, the analytics endpoint makes zero upstream calls and is a
/// single database query. That is the whole design.
class NotePnlSnapshot {
  final double realised;
  final double unrealised;

  /// When the number was *read*, not when the trade happened. Defaults to now
  /// server-side if omitted. Must not precede the note's date.
  final DateTime? snapshotAt;

  /// The exact COCD CSV passed to the journal endpoint, e.g. `NSE_FNO,BSE_FNO`.
  /// Optional, but it records which universe the number covers. Unknown codes
  /// are rejected with `400 BAD_PNL`.
  final String? cocdScope;

  const NotePnlSnapshot({
    required this.realised,
    this.unrealised = 0,
    this.snapshotAt,
    this.cocdScope,
  });

  /// Builds a snapshot from a `getJournalDiary` row — Equity, F&O and Currency.
  ///
  /// [Journal] is the backend's own per-day rollup and the source the heat map
  /// already trusts (`LDProvider._rebuildGroupedAndHeatmapForSegment`). Note the
  /// date-wise *table* on the same screen shows a different derivation: it folds
  /// the individual trades' `realisedpnl`. The two should agree; if they ever
  /// diverge, this follows the backend's rollup.
  ///
  /// Not valid for commodity — see [NotePnlSnapshot.fromDateWise].
  factory NotePnlSnapshot.fromJournalRow(Journal row, SegmentGroup group) {
    assert(!group.usesJournalDiary3,
        'Commodity journal[] rows hardcode unrealisedpnl to 0 — use fromDateWise');
    return NotePnlSnapshot(
      realised: double.tryParse(row.realisedpnl ?? '') ?? 0,
      // Deliberately zeroed by the backend on every day except the last in this
      // response. A 0 here carries no meaning.
      unrealised: double.tryParse(row.unrealisedpnl ?? '') ?? 0,
      snapshotAt: DateTime.now(),
      cocdScope: group.cocdScope,
    );
  }

  /// Builds a snapshot from a `getJournalDiary3` `dateWise[date]` entry — Commodity.
  ///
  /// Must not be sourced from `journal[]` for this group: [CalenderpnlModel]
  /// synthesises those rows for commodity with `unrealisedpnl` hardcoded to
  /// `'0'`, so reading them would silently always send zero unrealised.
  factory NotePnlSnapshot.fromDateWise(
    Map<dynamic, dynamic> dayData,
    SegmentGroup group,
  ) {
    return NotePnlSnapshot(
      realised: (dayData['realised_pnl'] as num?)?.toDouble() ?? 0,
      unrealised: (dayData['total_unrealized_pnl'] as num?)?.toDouble() ?? 0,
      snapshotAt: DateTime.now(),
      cocdScope: group.cocdScope,
    );
  }

  factory NotePnlSnapshot.fromJson(Map<String, dynamic> json) {
    return NotePnlSnapshot(
      realised: (json['realised'] as num?)?.toDouble() ?? 0,
      unrealised: (json['unrealised'] as num?)?.toDouble() ?? 0,
      snapshotAt: DateTime.tryParse(json['snapshot_at']?.toString() ?? ''),
      cocdScope: json['cocd_scope']?.toString(),
    );
  }

  /// Money goes out as JSON numbers, not strings.
  Map<String, dynamic> toJson() => {
        'realised': realised,
        'unrealised': unrealised,
        if (snapshotAt != null) 'snapshot_at': toIso8601WithOffset(snapshotAt!),
        if (cocdScope != null) 'cocd_scope': cocdScope,
      };

  double get total => realised + unrealised;
}

/// A trader's note on one day of one asset class.
class JournalNote {
  final int noteId;

  /// `YYYY-MM-DD`. Kept as a string: it is the natural key, and it is exactly
  /// what `_DateRowData.dateString` on the P&L Summary screen already holds.
  final String noteDate;

  final SegmentGroup? segmentGroup;
  final String title;
  final String comment;

  /// Null when the note was saved without one. Such a note is excluded from
  /// analytics entirely — not counted as zero.
  final NotePnlSnapshot? pnl;

  final List<JournalTag> tags;

  /// Not documented in the API spec's note payload. Parsed defensively so the
  /// editor can show existing attachments if the backend does return them;
  /// there is no list-attachments endpoint to fall back on.
  final List<NoteAttachment> attachments;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const JournalNote({
    required this.noteId,
    required this.noteDate,
    this.segmentGroup,
    this.title = '',
    this.comment = '',
    this.pnl,
    this.tags = const [],
    this.attachments = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory JournalNote.fromJson(Map<String, dynamic> json) {
    final rawPnl = json['pnl'];
    return JournalNote(
      noteId: (json['note_id'] as num?)?.toInt() ?? 0,
      noteDate: json['note_date']?.toString() ?? '',
      segmentGroup: SegmentGroup.fromWire(json['segment_group']?.toString()),
      title: json['title']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      pnl: rawPnl is Map
          ? NotePnlSnapshot.fromJson(Map<String, dynamic>.from(rawPnl))
          : null,
      tags: JournalTag.listFrom(json['tags']),
      attachments: NoteAttachment.listFrom(json['attachments']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  /// True when the snapshot was taken on the note's own date, i.e. before
  /// end-of-day settlement. The stored number is unsettled and is never
  /// refreshed. The analytics response reports these in aggregate; this is the
  /// per-note equivalent.
  bool get hasProvisionalSnapshot {
    final at = pnl?.snapshotAt;
    if (at == null) return false;
    final local = at.isUtc ? at.toLocal() : at;
    final onDay = '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    return onDay == noteDate;
  }

  bool get hasContent => title.isNotEmpty || comment.isNotEmpty;

  @override
  String toString() => 'JournalNote($noteId, $noteDate, ${segmentGroup?.wire})';
}

/// A page of `/notes/list`, sorted by `note_date` descending.
class NoteListResult {
  final List<JournalNote> notes;

  /// The unpaginated count — use this for pagination, not `notes.length`.
  final int total;
  final int limit;
  final int offset;

  const NoteListResult({
    required this.notes,
    required this.total,
    this.limit = 100,
    this.offset = 0,
  });

  factory NoteListResult.fromJson(Map<String, dynamic> json) {
    final raw = json['notes'];
    return NoteListResult(
      notes: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => JournalNote.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 100,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }

  /// Indexed by `note_date` for merging onto the journal grid. One note per day
  /// per group, so the key is unique within a single-group listing.
  Map<String, JournalNote> get byDate => {for (final n in notes) n.noteDate: n};
}
