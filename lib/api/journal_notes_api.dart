import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mynt_plus/models/journal_notes_model/journal_note.dart';
import 'package:mynt_plus/models/journal_notes_model/journal_notes_exception.dart';
import 'package:mynt_plus/models/journal_notes_model/journal_tag.dart';
import 'package:mynt_plus/models/journal_notes_model/note_attachment.dart';
import 'package:mynt_plus/models/journal_notes_model/segment_group.dart';
import 'package:mynt_plus/models/journal_notes_model/tag_pnl_analytics.dart';

import 'core/api_core.dart';

/// The trade-journal notes backend (`journal_notes.py`).
///
/// This service is completely independent of the journal/P&L endpoints — it
/// knows nothing about trades. Fetch the P&L summary as today, fetch notes
/// separately, and merge them client-side on the date.
///
/// It differs from the rest of this app's API layer in three ways that matter:
///
///  * **Real HTTP status codes.** Most routes here return `200` even on failure
///    and put the outcome in `stat`. These return 200/201/400/401/404/409/413/
///    415/500/503. Do not reach for a "check the body, ignore the status" helper.
///  * **`YYYY-MM-DD` dates**, where the P&L endpoints on the same host take
///    `DD/MM/YYYY`. Do not share a formatter — see [kNoteDatePattern].
///  * **JSON numbers for money**, not strings.
///
/// Errors surface as [JournalNotesException], except where a non-2xx is routine:
/// `404 NOTE_NOT_FOUND` ([getNote]), `409 TAG_EXISTS` ([createTag]) and
/// `409 TAG_IN_USE` ([deleteTag]) are returned as domain outcomes so the ordinary
/// empty/conflict paths never present as failures.
///
/// Never send `cc`. These routes derive the client code from the validated
/// session and ignore the body — a note always belongs to the logged-in client.
mixin JournalNotesApi on ApiCore {
  /// `_ConditionalTimeoutClient` is currently a no-op (its URL list is empty),
  /// so without this there is no timeout at all.
  static const Duration _kTimeout = Duration(seconds: 20);

  /// Uploads carry up to 5 MB and are re-encoded server-side before responding.
  static const Duration _kUploadTimeout = Duration(seconds: 60);

  // --- Shared helpers ------------------------------------------------------

  Uri _u(String path) => Uri.parse('${apiLinks.journalNotesApi}$path');

  Future<http.Response> _postRaw(String path, Map<String, dynamic> body) async {
    try {
      return await apiClient
          .post(_u(path), headers: funddefaultHeaders, body: jsonEncode(body))
          .timeout(_kTimeout);
    } catch (e) {
      throw JournalNotesException.network(e);
    }
  }

  /// POST and return the `data` object from the `{stat: "Ok", data: {...}}`
  /// envelope, throwing on any non-2xx.
  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    return _dataOrThrow(await _postRaw(path, body));
  }

  Map<String, dynamic> _dataOrThrow(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      _throwFromResponse(r);
    }
    final json = _decodeBody(r);
    final data = json?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    // 2xx with no `data` — delete routes and the like. Give callers an empty map
    // rather than null so they need not null-check a success path.
    return const {};
  }

  /// Decodes the body, or null if it was absent or not JSON.
  ///
  /// Always decodes UTF-8 from bytes: `r.body` uses Latin-1 unless the response
  /// sets `charset=utf-8` explicitly, which mangles anything non-ASCII a user
  /// typed into a note.
  Map<String, dynamic>? _decodeBody(http.Response r) {
    if (r.bodyBytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(r.bodyBytes));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  /// The `code` from a failure envelope, or `''` when the body was not one.
  ///
  /// Used to tell a real domain outcome from an incidental status match — a
  /// `404` carrying no `NOTE_NOT_FOUND` code is a routing failure (the proxy not
  /// forwarding `/report/journal/*`, say), not an absent note.
  String _codeOf(http.Response r) => _decodeBody(r)?['code']?.toString() ?? '';

  Never _throwFromResponse(http.Response r) {
    final json = _decodeBody(r);
    throw JournalNotesException.fromResponse(
      statusCode: r.statusCode,
      backendMessage: json?['msg']?.toString() ?? '',
      code: json?['code']?.toString() ?? '',
      data: json?['data'] is Map
          ? Map<String, dynamic>.from(json!['data'] as Map)
          : null,
    );
  }

  /// Guards the documented footgun: this app sends `DD/MM/YYYY` to the P&L
  /// endpoints on the same host, and `"14/07/2026"` here is a `400 BAD_DATE`.
  /// Also catches the literal `"unknown"` key from `getJournalDiary3.dateWise`,
  /// which is not a date and must never be sent as one.
  void _assertNoteDate(String date) {
    assert(kNoteDatePattern.hasMatch(date),
        'note dates must be YYYY-MM-DD, got "$date"');
  }

  // --- Notes ---------------------------------------------------------------

  /// Idempotent upsert — there is no separate create/update.
  ///
  /// [pnl] is required-but-nullable on purpose: **omitting it on an update
  /// clears the stored snapshot**, which removes the note from analytics
  /// entirely. Always resend it on edit; backoffice restates days, so
  /// re-sending refreshes the stored number. Passing null must be a deliberate
  /// choice, not an oversight.
  ///
  /// Tags are not set here — save first, then [attachTags] by `note_id`.
  ///
  /// Returns the saved note and whether it was newly created (`201`) rather
  /// than updated (`200`).
  Future<({JournalNote note, bool created})> saveNote({
    required String noteDate,
    required SegmentGroup group,
    required NotePnlSnapshot? pnl,
    String title = '',
    String comment = '',
  }) async {
    _assertNoteDate(noteDate);
    final r = await _postRaw('/notes/save', {
      'note_date': noteDate,
      'segment_group': group.wire,
      'title': title,
      'comment': comment,
      if (pnl != null) 'pnl': pnl.toJson(),
    });
    final data = _dataOrThrow(r);
    return (
      note: JournalNote.fromJson(Map<String, dynamic>.from(data['note'] as Map)),
      created: r.statusCode == 201,
    );
  }

  /// The note for a day, or **null when none exists yet**.
  ///
  /// A null is the ordinary empty state — render the "add a note" affordance.
  /// It is not an error and must not surface as one.
  Future<JournalNote?> getNote({
    required String noteDate,
    required SegmentGroup group,
  }) async {
    _assertNoteDate(noteDate);
    final r = await _postRaw('/notes/get', {
      'note_date': noteDate,
      'segment_group': group.wire,
    });
    if (r.statusCode == 404 && _codeOf(r) == 'NOTE_NOT_FOUND') return null;
    final data = _dataOrThrow(r);
    return JournalNote.fromJson(Map<String, dynamic>.from(data['note'] as Map));
  }

  /// Notes in a window, sorted by `note_date` descending.
  ///
  /// This is the call that decorates the P&L grid — one per visible range, then
  /// merge by date. Do not call [getNote] per row.
  ///
  /// An empty result is a success, never an error. The range is capped at 400
  /// days server-side (`400 BAD_DATE_RANGE`).
  ///
  /// [group] omitted returns every group. [tagIds] matches notes having ANY of
  /// them. [q] is case-insensitive over title and comment.
  Future<NoteListResult> listNotes({
    required String from,
    required String to,
    SegmentGroup? group,
    List<int>? tagIds,
    String? q,
    int limit = 100,
    int offset = 0,
  }) async {
    _assertNoteDate(from);
    _assertNoteDate(to);
    final data = await _post('/notes/list', {
      'from': from,
      'to': to,
      if (group != null) 'segment_group': group.wire,
      if (tagIds != null && tagIds.isNotEmpty) 'tag_ids': tagIds,
      if (q != null && q.isNotEmpty) 'q': q,
      'limit': limit,
      'offset': offset,
    });
    return NoteListResult.fromJson(data);
  }

  /// Soft delete. Immediately invisible to every read and to analytics, and its
  /// attachments go too. The day becomes free — saving that
  /// `(date, segment_group)` again creates a fresh note.
  ///
  /// There is no undo exposed. Confirm in the UI before calling.
  Future<void> deleteNote(int noteId) async {
    await _post('/notes/delete', {'note_id': noteId});
  }

  // --- Tags ----------------------------------------------------------------

  /// Every tag for this client, alphabetical by name. Cache it — tags change
  /// rarely, and the type-ahead filters locally.
  Future<List<JournalTag>> listTags() async {
    final data = await _post('/tags/list', const {});
    return JournalTag.listFrom(data['tags']);
  }

  /// Create a tag, or return the existing one on a name collision.
  ///
  /// Names are unique per client, case- and whitespace-insensitive, so
  /// `"Revenge-Trade"` collides with `"revenge-trade"`. The backend returns the
  /// existing tag on `409 TAG_EXISTS`, so this is not an error path: a
  /// create-or-attach flow attaches `result.tag.tagId` either way.
  ///
  /// [color] is a 6-digit hex with the `#` required. [name] is 1-40 chars; any
  /// characters are safe, quotes and apostrophes round-trip intact.
  Future<TagCreateResult> createTag({
    required String name,
    String? color,
  }) async {
    final r = await _postRaw('/tags/create', {
      'name': name,
      if (color != null) 'color': color,
    });
    if (r.statusCode == 409 && _codeOf(r) == 'TAG_EXISTS') {
      final existing = _decodeBody(r)?['data']?['tag'];
      if (existing is Map) {
        return TagCreateResult(
          tag: JournalTag.fromJson(Map<String, dynamic>.from(existing)),
          alreadyExisted: true,
        );
      }
    }
    final data = _dataOrThrow(r);
    return TagCreateResult(
      tag: JournalTag.fromJson(Map<String, dynamic>.from(data['tag'] as Map)),
      alreadyExisted: false,
    );
  }

  /// Rename and/or recolour. Sending neither is `400 NOTHING_TO_UPDATE`.
  Future<JournalTag> updateTag({
    required int tagId,
    String? name,
    String? color,
  }) async {
    assert(name != null || color != null, 'updateTag needs a name or a color');
    final data = await _post('/tags/update', {
      'tag_id': tagId,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
    });
    return JournalTag.fromJson(Map<String, dynamic>.from(data['tag'] as Map));
  }

  /// Delete a tag.
  ///
  /// If it is attached to any live note the backend refuses and reports the
  /// count — check `result.refusedInUse`, show the count, confirm, then call
  /// again with [force] true.
  ///
  /// Deletion is permanent and detaches from every note. There is no undo.
  Future<TagDeleteResult> deleteTag({
    required int tagId,
    bool force = false,
  }) async {
    final r = await _postRaw('/tags/delete', {
      'tag_id': tagId,
      if (force) 'force': true,
    });
    if (r.statusCode == 409 && _codeOf(r) == 'TAG_IN_USE') {
      final count = _decodeBody(r)?['data']?['note_count'];
      return TagDeleteResult(
        noteCount: (count as num?)?.toInt() ?? 0,
        refusedInUse: true,
      );
    }
    final data = _dataOrThrow(r);
    return TagDeleteResult(
      noteCount: (data['detached_note_count'] as num?)?.toInt() ?? 0,
      refusedInUse: false,
    );
  }

  /// Attach tags to a note. Idempotent — attaching an already-attached tag is a
  /// no-op, not a conflict. Max 20 tags per note.
  ///
  /// Returns the note's **full resulting tag list**. Never diff: send the
  /// intent, render the result as the new truth.
  Future<List<JournalTag>> attachTags({
    required int noteId,
    required List<int> tagIds,
  }) async {
    final data = await _post(
        '/notes/tags/attach', {'note_id': noteId, 'tag_ids': tagIds});
    return JournalTag.listFrom(data['tags']);
  }

  /// Detach tags from a note. Idempotent — detaching an absent tag is fine.
  /// Returns the note's full resulting tag list, as [attachTags] does.
  Future<List<JournalTag>> detachTags({
    required int noteId,
    required List<int> tagIds,
  }) async {
    final data = await _post(
        '/notes/tags/detach', {'note_id': noteId, 'tag_ids': tagIds});
    return JournalTag.listFrom(data['tags']);
  }

  // --- Attachments ---------------------------------------------------------

  /// Upload one file to an existing note. `multipart/form-data`, one per request.
  ///
  /// **The note must exist first** — save it, take the `note_id`, then upload.
  /// That ordering is deliberate: were uploads folded into the save, a rejected
  /// file would discard the text the user typed. A note with 0-2 attachments is
  /// a valid state, so on failure keep the note and offer a retry.
  ///
  /// 5 MB per file, 3 files per note, JPEG/PNG/PDF only — the type is detected
  /// from file *content*, so renaming `.exe` to `.png` does not work and the
  /// extension is not worth validating beyond a friendly `accept` hint.
  ///
  /// Throws with code `FILE_TOO_LARGE` (413), `ATTACHMENT_LIMIT` (409, already
  /// 3), `UNSUPPORTED_TYPE` (415) or `NO_FILE` (400).
  Future<NoteAttachment> uploadAttachment({
    required int noteId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', _u('/notes/attachments/upload'))
      // Drop the JSON content-type: `http` would overwrite it with the
      // multipart boundary anyway, but relying on that is accidental.
      ..headers.addAll(
          Map<String, String>.from(funddefaultHeaders)..remove('Content-Type'))
      ..fields['note_id'] = noteId.toString()
      // fromBytes, never fromPath — fromPath needs dart:io and breaks on web.
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    http.Response r;
    try {
      final streamed = await apiClient.send(request).timeout(_kUploadTimeout);
      r = await http.Response.fromStream(streamed);
    } catch (e) {
      throw JournalNotesException.network(e);
    }
    final data = _dataOrThrow(r);
    return NoteAttachment.fromJson(
        Map<String, dynamic>.from(data['attachment'] as Map));
  }

  /// Fetch an attachment's bytes.
  ///
  /// Returns raw binary, not JSON. This is the only way to render an
  /// attachment: `Image.network` cannot attach the `Authorization` header the
  /// download route requires, and the route is a POST with a JSON body anyway,
  /// so there is no URL form to point an image widget at. Feed the bytes to
  /// `Image.memory`; for PDFs, trigger a browser download instead — the server
  /// forces `Content-Disposition: attachment` regardless.
  ///
  /// A missing id **and another client's id** both give `404
  /// ATTACHMENT_NOT_FOUND`; a 403 would confirm the id exists. Do not write
  /// "permission denied" copy for this.
  Future<({Uint8List bytes, String? filename, String? contentType})>
      downloadAttachment(String attachmentId) async {
    http.Response r;
    try {
      r = await apiClient
          .post(_u('/notes/attachments/download'),
              headers: funddefaultHeaders,
              body: jsonEncode({'attachment_id': attachmentId}))
          .timeout(_kTimeout);
    } catch (e) {
      throw JournalNotesException.network(e);
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      _throwFromResponse(r);
    }
    String? filename;
    final disposition = r.headers['content-disposition'];
    if (disposition != null) {
      final match = RegExp(r'filename="?([^"]+)"?').firstMatch(disposition);
      if (match != null) filename = match.group(1);
    }
    return (
      bytes: r.bodyBytes,
      filename: filename,
      contentType: r.headers['content-type'],
    );
  }

  Future<void> deleteAttachment(String attachmentId) async {
    await _post('/notes/attachments/delete', {'attachment_id': attachmentId});
  }

  // --- Analytics -----------------------------------------------------------

  /// Tag → P&L correlation for one asset class over one window.
  ///
  /// [group] is required and has no default; omitting it is
  /// `400 SEGMENT_GROUP_REQUIRED`. Aggregating across asset classes would sum
  /// snapshots taken over different universes.
  ///
  /// [minSample] is the threshold below which a tag's `avg_pnl` and `win_rate`
  /// come back null. Leave it at 5 — see [TagPnlStats].
  ///
  /// [pnlBasis] is `total`, `realised` or `unrealised`.
  Future<TagPnlAnalytics> fetchTagPnl({
    required String from,
    required String to,
    required SegmentGroup group,
    String pnlBasis = 'total',
    int minSample = 5,
  }) async {
    _assertNoteDate(from);
    _assertNoteDate(to);
    final data = await _post('/analytics/tagPnl', {
      'from': from,
      'to': to,
      'segment_group': group.wire,
      'pnl_basis': pnlBasis,
      'min_sample': minSample,
    });
    return TagPnlAnalytics.fromJson(data);
  }
}
