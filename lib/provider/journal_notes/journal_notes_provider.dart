import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/models/journal_notes_model/journal_note.dart';
import 'package:mynt_plus/models/journal_notes_model/journal_tag.dart';
import 'package:mynt_plus/models/journal_notes_model/segment_group.dart';
import 'package:mynt_plus/models/journal_notes_model/tag_pnl_analytics.dart';

ApiExporter get _api => locator<ApiExporter>();

/// The account every journal cache entry belongs to.
///
/// Load-bearing, not decoration. These providers are not auto-disposed and
/// used to be keyed by date range alone, so their entries were shared across
/// accounts on the same browser. Logging out invalidates them (see
/// `auth_provider`), but invalidating a provider that still has listeners
/// makes it refetch *immediately* — and at that moment the P&L Summary screen
/// is still mounted while `apiToken` and `clientId` are still in prefs
/// (`clearClientSession` only drops `clientSession`). The refetch therefore
/// succeeded as the outgoing account and re-cached its notes, tags and
/// analytics right after the invalidation; the next login on the same browser
/// read them straight out of the cache without a request, and drew another
/// client's notes and note markers.
///
/// Keying every entry by client id removes the shared slot altogether, so the
/// fix does not depend on the order of steps in any logout path.
String get _cacheClientId => locator<Preferences>().clientId ?? '';

/// Deliberately kept out of `LDProvider`, which backs the P&L Summary screen.
/// That is a 4,100-line ChangeNotifier shared across Ledger, Tradebook,
/// Positions, Tax P&L and P&L Summary; adding notes to it would make this
/// feature untestable and couple it to four unrelated screens.

/// Every tag for one client. Cache-friendly: tags change rarely and the
/// type-ahead filters locally, so read this once and reuse.
///
/// Keyed by client id — see [_cacheClientId]. Callers pass
/// [journalTagsKey]; the argument exists to separate accounts, not to let a
/// screen ask for somebody else's tags.
///
/// Invalidate after create/update/delete.
final journalTagsProvider =
    FutureProvider.family<List<JournalTag>, String>((_, __) => _api.listTags());

/// The current account's key for [journalTagsProvider].
String journalTagsKey() => _cacheClientId;

/// Identifies a window of notes for one asset class.
class NotesRangeKey {
  /// `YYYY-MM-DD` — the notes API's format, not the `DD/MM/YYYY` the P&L
  /// endpoints take.
  final String from;
  final String to;

  /// Null lists every group.
  final SegmentGroup? group;

  /// The account this window belongs to. Defaulted from prefs so every
  /// existing call site is scoped without passing it — see [_cacheClientId]
  /// for why the cache must never be shared between accounts.
  final String clientId;

  NotesRangeKey({
    required this.from,
    required this.to,
    this.group,
    String? clientId,
  }) : clientId = clientId ?? _cacheClientId;

  @override
  bool operator ==(Object other) =>
      other is NotesRangeKey &&
      other.from == from &&
      other.to == to &&
      other.group == group &&
      other.clientId == clientId;

  @override
  int get hashCode => Object.hash(from, to, group, clientId);

  @override
  String toString() =>
      'NotesRangeKey($clientId, $from..$to, ${group?.wire ?? 'all'})';
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

  /// The account these analytics belong to — see [NotesRangeKey.clientId].
  final String clientId;

  TagPnlKey({
    required this.from,
    required this.to,
    required this.group,
    this.pnlBasis = 'total',
    this.minSample = 5,
    String? clientId,
  }) : clientId = clientId ?? _cacheClientId;

  @override
  bool operator ==(Object other) =>
      other is TagPnlKey &&
      other.from == from &&
      other.to == to &&
      other.group == group &&
      other.pnlBasis == pnlBasis &&
      other.minSample == minSample &&
      other.clientId == clientId;

  @override
  int get hashCode =>
      Object.hash(from, to, group, pnlBasis, minSample, clientId);

  @override
  String toString() =>
      'TagPnlKey($clientId, $from..$to, ${group.wire}, $pnlBasis)';
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
