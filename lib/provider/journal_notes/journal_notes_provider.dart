import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/journal_notes_model/journal_note.dart';
import 'package:mynt_plus/models/journal_notes_model/journal_tag.dart';
import 'package:mynt_plus/models/journal_notes_model/segment_group.dart';
import 'package:mynt_plus/models/journal_notes_model/tag_pnl_analytics.dart';

ApiExporter get _api => locator<ApiExporter>();

/// Deliberately kept out of `LDProvider`, which backs the P&L Summary screen.
/// That is a 4,100-line ChangeNotifier shared across Ledger, Tradebook,
/// Positions, Tax P&L and P&L Summary; adding notes to it would make this
/// feature untestable and couple it to four unrelated screens.

/// Every tag for this client. Cache-friendly: tags change rarely and the
/// type-ahead filters locally, so read this once and reuse.
///
/// Invalidate after create/update/delete.
final journalTagsProvider =
    FutureProvider<List<JournalTag>>((_) => _api.listTags());

/// Identifies a window of notes for one asset class.
class NotesRangeKey {
  /// `YYYY-MM-DD` — the notes API's format, not the `DD/MM/YYYY` the P&L
  /// endpoints take.
  final String from;
  final String to;

  /// Null lists every group.
  final SegmentGroup? group;

  const NotesRangeKey({required this.from, required this.to, this.group});

  @override
  bool operator ==(Object other) =>
      other is NotesRangeKey &&
      other.from == from &&
      other.to == to &&
      other.group == group;

  @override
  int get hashCode => Object.hash(from, to, group);

  @override
  String toString() => 'NotesRangeKey($from..$to, ${group?.wire ?? 'all'})';
}

/// Notes in a window, indexed by `note_date` for merging onto the P&L grid.
///
/// One call per visible range — never one per row. A note is unique per
/// (day, group), so the date key does not collide within a single-group listing.
///
/// Requests the maximum page size. The API caps a range at 400 days, so 500
/// cannot truncate and no pagination is needed here.
final notesForRangeProvider =
    FutureProvider.family<Map<String, JournalNote>, NotesRangeKey>(
        (_, key) async {
  final result = await _api.listNotes(
    from: key.from,
    to: key.to,
    group: key.group,
    limit: 500,
  );
  assert(result.total <= result.notes.length,
      'notes truncated: ${result.total} total vs ${result.notes.length} fetched');
  return result.byDate;
});

/// Whether this client has journalled anything in the window — the gate for the
/// Insights tab.
///
/// Deliberately not scoped to a segment group, and deliberately keyed on the
/// financial year rather than the user's selected sub-range: gating on the
/// live date range would make the tab appear and vanish as they move the dates,
/// and gating per-segment would make it flicker as they switch tabs. Once a
/// user has journalled, Insights stays available; if the analytics for the
/// active segment happen to be empty, the view says so.
///
/// Cheap by design — asks for a single row and reads `total`.
final hasAnyNotesProvider =
    FutureProvider.family<bool, NotesRangeKey>((_, key) async {
  final result = await _api.listNotes(from: key.from, to: key.to, limit: 1);
  return result.total > 0;
});

/// Identifies one analytics query.
class TagPnlKey {
  final String from;
  final String to;

  /// Required — analytics has no default and refuses to aggregate across asset
  /// classes, which would sum snapshots taken over different universes.
  final SegmentGroup group;

  final String pnlBasis;

  /// The threshold below which per-tag averages are suppressed as noise.
  final int minSample;

  const TagPnlKey({
    required this.from,
    required this.to,
    required this.group,
    this.pnlBasis = 'total',
    this.minSample = 5,
  });

  @override
  bool operator ==(Object other) =>
      other is TagPnlKey &&
      other.from == from &&
      other.to == to &&
      other.group == group &&
      other.pnlBasis == pnlBasis &&
      other.minSample == minSample;

  @override
  int get hashCode => Object.hash(from, to, group, pnlBasis, minSample);

  @override
  String toString() => 'TagPnlKey($from..$to, ${group.wire}, $pnlBasis)';
}

final tagPnlProvider =
    FutureProvider.family<TagPnlAnalytics, TagPnlKey>((_, key) => _api.fetchTagPnl(
          from: key.from,
          to: key.to,
          group: key.group,
          pnlBasis: key.pnlBasis,
          minSample: key.minSample,
        ));

/// An attachment's bytes, keyed by attachment id.
///
/// Authenticated image loading has no precedent in this app — every existing
/// `Image.network` / `CachedNetworkImage` call site loads a public URL. It
/// cannot work here: the download route needs an `Authorization` header and is
/// a POST with a JSON body, so there is no URL to hand an image widget. Fetch
/// the bytes and feed `Image.memory`.
///
/// Holding the bytes in the provider is what stops a refetch on every rebuild.
/// The flip side is that they stay resident until the provider is disposed, so
/// a gallery of 5 MB images will sit in memory — invalidate when the editor
/// closes. Lazy-load only what becomes visible; the upload/list response already
/// carries `filename`, `byteSize` and `contentType`, which is enough to render
/// a tile without fetching anything.
final attachmentBytesProvider =
    FutureProvider.family<Uint8List, String>((_, attachmentId) async {
  final result = await _api.downloadAttachment(attachmentId);
  return result.bytes;
});
