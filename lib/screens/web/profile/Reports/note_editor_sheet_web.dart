// ignore_for_file: avoid_web_libraries_in_flutter
// dart:html is deliberate — the P&L Summary is a web-only screen and the PDF
// attachment download needs the browser's blob/anchor machinery, the same
// pattern every report download helper in /screens/web uses.

import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../../api/core/api_export.dart';
import '../../../../locator/locator.dart';
import '../../../../models/journal_notes_model/journal_note.dart';
import '../../../../models/journal_notes_model/journal_notes_exception.dart';
import '../../../../models/journal_notes_model/journal_tag.dart';
import '../../../../models/journal_notes_model/note_attachment.dart';
import '../../../../models/journal_notes_model/segment_group.dart';
import '../../../../provider/journal_notes/journal_notes_provider.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../sharedWidget/common_buttons_web.dart';
import '../../../../sharedWidget/common_text_fields_web.dart';
import '../../../../sharedWidget/snack_bar.dart';

/// Guards against a double-click opening two sheets — the same pattern the
/// order-book screens use.
bool _isSheetOpening = false;

/// Opens the note editor for one trading day.
///
/// [existing] is the note already in hand from `notesForRangeProvider`, or null
/// for a day with no note. Nothing is re-fetched: the list call that decorates
/// the grid already returned the full note.
///
/// [snapshot] is the day's P&L read from the response already on screen. It is
/// resent on every save, including edits — omitting it clears the stored
/// snapshot and drops the note from analytics. A null [snapshot] means the day
/// had no P&L row to read, and the note will be invisible to analytics.
///
/// [startInEdit] opens straight into the editing form. Defaults to false, so an
/// existing note opens read-only (view) and the user taps the pencil to edit —
/// reading a note should never drop you into a form. Adding a note to a blank
/// day passes true, since there is nothing to view yet.
Future<void> openNoteEditorSheet(
  BuildContext context, {
  required WidgetRef ref,
  required String noteDate,
  required SegmentGroup group,
  required JournalNote? existing,
  required NotePnlSnapshot? snapshot,
  required NotesRangeKey rangeKey,
  bool startInEdit = false,
}) async {
  if (_isSheetOpening) return;
  _isSheetOpening = true;

  await shadcn.openSheet(
    context: context,
    position: shadcn.OverlayPosition.end,
    barrierColor: Colors.transparent,
    // The editor is persistent: an accidental click outside must not discard a
    // half-written note. It closes only through the X (or Save/Delete), and the
    // X asks before dropping unsaved edits.
    barrierDismissible: false,
    builder: (sheetContext) {
      final screenWidth = MediaQuery.of(sheetContext).size.width;
      final sheetWidth = screenWidth < 1300 ? screenWidth * 0.3 : 480.0;
      return Container(
        width: sheetWidth,
        decoration: BoxDecoration(
          color: resolveThemeColor(sheetContext,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 5,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        // MyntTextField wraps a Material TextField and has no Material ancestor
        // of its own; openSheet does not provide one.
        child: Material(
          color: Colors.transparent,
          child: _NoteEditorContent(
            noteDate: noteDate,
            group: group,
            existing: existing,
            snapshot: snapshot,
            rangeKey: rangeKey,
            // A new note has nothing to view, so it always starts in the form.
            startInEdit: startInEdit || existing == null,
          ),
        ),
      );
    },
  );

  _isSheetOpening = false;

  // Tag attach/detach on an existing note applies immediately, without going
  // through Save — so the grid's cached copy of the note can be stale by the
  // time the sheet closes. One refresh here covers every exit path.
  ref.invalidate(notesForRangeProvider(rangeKey));

  // Attachment bytes are held in the provider so thumbnails don't refetch on
  // every rebuild; the cost is they stay resident. Drop them all when the
  // editor closes — up to 3 × 5 MB per note is too much to keep around.
  ref.invalidate(attachmentBytesProvider);
}

/// Preset swatches offered when creating or recolouring a tag. Stored on the
/// backend as `#RRGGBB` strings.
const List<String> _kTagPalette = [
  '#E5484D', // red
  '#E5934D', // orange
  '#F2B01E', // amber
  '#46A758', // green
  '#12A594', // teal
  '#0091FF', // blue
  '#6E56CF', // violet
  '#D6409F', // magenta
  '#697177', // grey
  '#8E4EC6', // purple
];

/// Matches the P&L Summary screen's own formatting: the sign sits outside the
/// symbol (`-₹1,234.00`), so the number in the editor reads the same as the
/// number in the row it was opened from.
String _formatAmount(double value) {
  final prefix = value < 0 ? '-₹' : '₹';
  return '$prefix${NumberFormat('#,##,##0.00', 'en_IN').format(value.abs())}';
}

class _NoteEditorContent extends ConsumerStatefulWidget {
  final String noteDate;
  final SegmentGroup group;
  final JournalNote? existing;
  final NotePnlSnapshot? snapshot;
  final NotesRangeKey rangeKey;
  final bool startInEdit;

  const _NoteEditorContent({
    required this.noteDate,
    required this.group,
    required this.existing,
    required this.snapshot,
    required this.rangeKey,
    required this.startInEdit,
  });

  @override
  ConsumerState<_NoteEditorContent> createState() => _NoteEditorContentState();
}

/// An in-sheet confirmation prompt. Rendered inside the sheet's own Stack rather
/// than a Material `showDialog`, which layers *below* the shadcn drawer overlay
/// and so would be invisible and unreachable.
class _ConfirmPrompt {
  final String title;
  final String message;
  final String confirmLabel;
  final Future<void> Function() onConfirm;

  const _ConfirmPrompt({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
  });
}

class _NoteEditorContentState extends ConsumerState<_NoteEditorContent> {
  late final TextEditingController _title;
  late final TextEditingController _comment;
  late final String _originalTitle;
  late final String _originalComment;
  bool _saving = false;
  bool _deleting = false;

  /// Non-null while an inline confirm prompt (discard / delete) is showing.
  _ConfirmPrompt? _confirm;

  /// The note's tags as shown. For an existing note this mirrors the server
  /// (attach/detach apply immediately and this is set from the response); for
  /// a new note it is a local selection attached right after the first save.
  late List<JournalTag> _tags;

  /// Type-ahead filter for the tag combobox.
  final TextEditingController _tagQuery = TextEditingController();

  /// Focus drives the combobox: the tag panel is open exactly while the field
  /// has focus. The panel itself is wrapped in a [TextFieldTapRegion] so that
  /// clicking its rows does not count as "tapping outside" the text field.
  final FocusNode _tagFocus = FocusNode();

  /// Keyboard highlight in the tag panel (↑/↓), −1 when following the mouse.
  int _tagHighlight = -1;
  final ScrollController _tagPanelScroll = ScrollController();

  /// An attach/detach/create round-trip is in flight — rows ignore taps.
  bool _tagBusy = false;

  /// Swaps the sheet body to the manage-tags view.
  bool _managingTags = false;

  /// Tag whose manage-view row is expanded into the rename/recolour editor.
  /// Creation is NOT offered here — the editor's tag field already covers it,
  /// and two create flows a tap apart would just compete with each other.
  int? _editingTagId;
  final TextEditingController _editTagName = TextEditingController();
  String _editTagColor = _kTagPalette.first;

  /// Attachments already stored on the server for this note.
  late List<NoteAttachment> _attachments;

  /// Files picked on a NEW note, which has no note_id to upload to yet. They
  /// upload right after the first save — the same deferral as queued tags.
  final List<({Uint8List bytes, String filename})> _queuedFiles = [];

  /// An upload or delete is in flight — attachment controls ignore taps.
  bool _attachmentBusy = false;

  /// Non-null while the full-size image preview overlay is showing.
  ({String filename, Uint8List bytes})? _imagePreview;

  /// Whether the sheet is showing the editing form. False means the read-only
  /// view; the pencil in the header flips it true. A new note starts true
  /// (there is nothing to view); an existing note starts in view.
  late bool _editing;

  @override
  void initState() {
    super.initState();
    _editing = widget.startInEdit;
    _originalTitle = widget.existing?.title ?? '';
    _originalComment = widget.existing?.comment ?? '';
    _title = TextEditingController(text: _originalTitle);
    _comment = TextEditingController(text: _originalComment);
    _tags = List.of(widget.existing?.tags ?? const []);
    _attachments = List.of(widget.existing?.attachments ?? const []);
    // Open/close the tag panel with focus; new keystrokes restart keyboard
    // navigation from the top.
    _tagFocus.addListener(_onTagFocusChanged);
    _tagQuery.addListener(_resetTagHighlight);
  }

  @override
  void dispose() {
    _title.dispose();
    _comment.dispose();
    _tagQuery.dispose();
    _tagFocus.dispose();
    _tagPanelScroll.dispose();
    _editTagName.dispose();
    super.dispose();
  }

  void _onTagFocusChanged() {
    if (!mounted) return;
    setState(() {
      if (!_tagFocus.hasFocus) _tagHighlight = -1;
    });
  }

  void _resetTagHighlight() {
    // No setState: the panel already rebuilds via its AnimatedBuilder on
    // _tagQuery, which reads this field.
    _tagHighlight = -1;
  }

  bool get _isNew => widget.existing == null;

  /// `2026-05-15` → `15 May 2026` for display. The stored key stays ISO.
  String get _prettyDate {
    final d = DateTime.tryParse(widget.noteDate);
    return d != null ? DateFormat('dd MMM yyyy').format(d) : widget.noteDate;
  }

  /// Whether the current text differs from what the note was opened with. Read
  /// live from the controllers rather than tracked with a flag, so it stays
  /// correct even after the user edits back to the original.
  bool get _dirty =>
      _title.text != _originalTitle || _comment.text != _originalComment;

  /// Save is allowed when a new note has something in it (text, tags or
  /// queued files), or an existing note has been changed. Recomputed on every
  /// keystroke via the footer's [AnimatedBuilder] — the enabled state must
  /// not go stale.
  ///
  /// Tag and attachment edits on an existing note apply immediately and never
  /// pass through Save, so only the text drives dirtiness there.
  bool get _canSave =>
      !_saving &&
      (_isNew
          ? (_hasContent || _tags.isNotEmpty || _queuedFiles.isNotEmpty)
          : _dirty);

  /// The snapshot to send on save.
  ///
  /// Prefer the value just read from the screen, since the back office restates
  /// days and re-sending refreshes what is stored. Fall back to the snapshot
  /// already on the note: a day can lose its P&L row (a narrowed date range, a
  /// restatement), and sending null there would *clear* a perfectly good stored
  /// snapshot and silently drop the note out of analytics.
  NotePnlSnapshot? get _effectiveSnapshot =>
      widget.snapshot ?? widget.existing?.pnl;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await locator<ApiExporter>().saveNote(
        noteDate: widget.noteDate,
        group: widget.group,
        title: _title.text,
        comment: _comment.text,
        // Always resent. Omitting it would clear the stored snapshot.
        pnl: _effectiveSnapshot,
      );

      // A new note's tags and files were only held locally — it had no
      // note_id to attach them to until now. (Existing notes apply both
      // immediately.) The note itself is already saved, so failures here
      // warn rather than fail: reopening the note offers a retry.
      final warnings = <String>[];
      if (_isNew && _tags.isNotEmpty) {
        try {
          await locator<ApiExporter>().attachTags(
            noteId: saved.note.noteId,
            tagIds: [for (final t in _tags) t.tagId],
          );
        } on JournalNotesException catch (e) {
          warnings.add('tags could not be attached — ${e.message}');
        }
      }
      if (_isNew && _queuedFiles.isNotEmpty) {
        var failed = 0;
        for (final f in _queuedFiles) {
          try {
            await locator<ApiExporter>().uploadAttachment(
              noteId: saved.note.noteId,
              bytes: f.bytes,
              filename: f.filename,
            );
          } on JournalNotesException {
            failed++;
          }
        }
        if (failed > 0) {
          warnings.add(
              '$failed attachment${failed == 1 ? '' : 's'} could not be '
              'uploaded');
        }
      }

      ref.invalidate(notesForRangeProvider(widget.rangeKey));
      ref.invalidate(hasAnyNotesProvider);
      if (!mounted) return;
      // openSheet is a shadcn drawer, not a route — Navigator.pop would not
      // close it and would leave the save spinner hung.
      shadcn.closeSheet(context);
      if (warnings.isNotEmpty) {
        error(context, 'Note saved, but ${warnings.join('; ')}.');
      } else {
        successMessage(context, _isNew ? 'Note saved' : 'Note updated');
      }
    } on JournalNotesException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      error(context, e.message);
    }
  }

  /// The X. The editor is persistent, so this is the deliberate exit — if there
  /// are unsaved edits it asks before dropping them, otherwise it closes.
  ///
  /// On a new note the locally-queued tags and files are unsaved work too; on
  /// an existing note tag/attachment changes are already persisted and only
  /// text counts.
  void _handleClose() {
    if (_saving || _deleting) return;
    // The read-only view has no unsaved edits to protect — close straight away.
    final hasUnsavedWork = _editing &&
        (_isNew
            ? (_hasContent || _tags.isNotEmpty || _queuedFiles.isNotEmpty)
            : _dirty);
    if (hasUnsavedWork) {
      setState(() {
        _confirm = _ConfirmPrompt(
          title: 'Discard changes?',
          message: 'You have unsaved changes to this note. Closing now will '
              'discard them.',
          confirmLabel: 'Discard',
          onConfirm: () async {
            if (mounted) shadcn.closeSheet(context);
          },
        );
      });
      return;
    }
    shadcn.closeSheet(context);
  }

  void _requestDelete() {
    if (widget.existing == null || _deleting) return;
    setState(() {
      _confirm = _ConfirmPrompt(
        title: 'Delete this note?',
        message: 'Your note for ${widget.noteDate} will be removed, along with '
            'its tags and attachments. This cannot be undone.',
        confirmLabel: 'Delete',
        onConfirm: _performDelete,
      );
    });
  }

  Future<void> _performDelete() async {
    final note = widget.existing;
    if (note == null) return;
    setState(() {
      _confirm = null;
      _deleting = true;
    });
    try {
      await locator<ApiExporter>().deleteNote(note.noteId);
      ref.invalidate(notesForRangeProvider(widget.rangeKey));
      ref.invalidate(hasAnyNotesProvider);
      if (!mounted) return;
      shadcn.closeSheet(context);
      successMessage(context, 'Note deleted');
    } on JournalNotesException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      error(context, e.message);
    }
  }

  // --- Tag operations --------------------------------------------------------

  /// Attach on an existing note goes straight to the server — the API is an
  /// idempotent set operation whose response is the full resulting tag list,
  /// so what comes back is simply the new truth. A new note has no note_id
  /// yet; its selection stays local until the first save.
  ///
  /// The query filter deliberately survives a toggle: the panel stays open
  /// across selections, and clearing the filter under the user's caret would
  /// make attaching several matching tags in a row needlessly fiddly.
  Future<void> _attachTag(JournalTag tag) async {
    if (_tagBusy) return;
    if (_tags.length >= 20) {
      error(context, 'A note can carry at most 20 tags.');
      return;
    }
    final noteId = widget.existing?.noteId;
    if (noteId == null) {
      setState(() => _tags.add(tag));
      return;
    }
    // The round-trip's rebuilds can drop the field's focus and close the
    // panel mid-flow; restore it so multi-attach keeps working.
    final hadFocus = _tagFocus.hasFocus;
    setState(() => _tagBusy = true);
    try {
      final result = await locator<ApiExporter>()
          .attachTags(noteId: noteId, tagIds: [tag.tagId]);
      if (!mounted) return;
      setState(() {
        _tags = result;
        _tagBusy = false;
      });
      if (hadFocus) _tagFocus.requestFocus();
    } on JournalNotesException catch (e) {
      if (!mounted) return;
      setState(() => _tagBusy = false);
      error(context, e.message);
    }
  }

  Future<void> _removeTag(JournalTag tag) async {
    if (_tagBusy) return;
    final noteId = widget.existing?.noteId;
    if (noteId == null) {
      setState(() => _tags.removeWhere((t) => t.tagId == tag.tagId));
      return;
    }
    final hadFocus = _tagFocus.hasFocus;
    setState(() => _tagBusy = true);
    try {
      final result = await locator<ApiExporter>()
          .detachTags(noteId: noteId, tagIds: [tag.tagId]);
      if (!mounted) return;
      setState(() {
        _tags = result;
        _tagBusy = false;
      });
      if (hadFocus) _tagFocus.requestFocus();
    } on JournalNotesException catch (e) {
      if (!mounted) return;
      setState(() => _tagBusy = false);
      error(context, e.message);
    }
  }

  /// The create-or-attach flow: a name collision is not an error — the backend
  /// returns the existing tag on 409 TAG_EXISTS and we attach that instead.
  Future<void> _createAndAttachTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _tagBusy) return;
    if (trimmed.length > 40) {
      error(context, 'Tag names are limited to 40 characters.');
      return;
    }
    final hadFocus = _tagFocus.hasFocus;
    setState(() => _tagBusy = true);
    try {
      final allTags = ref.read(journalTagsProvider).value ?? const [];
      final result = await locator<ApiExporter>().createTag(
        name: trimmed,
        // Rotate through the palette so consecutive tags differ; recolour
        // later in Manage tags.
        color: _kTagPalette[allTags.length % _kTagPalette.length],
      );
      ref.invalidate(journalTagsProvider);
      if (!mounted) return;
      // Unlike a toggle, creating consumes the query — the filter text has
      // become a tag and leaving it would filter the panel by its own name.
      _tagQuery.clear();
      setState(() => _tagBusy = false);
      await _attachTag(result.tag);
      if (mounted && hadFocus) _tagFocus.requestFocus();
    } on JournalNotesException catch (e) {
      if (!mounted) return;
      setState(() => _tagBusy = false);
      error(context, e.message);
    }
  }

  void _startEditTag(JournalTag tag) {
    setState(() {
      _editingTagId = tag.tagId;
      _editTagName.text = tag.name;
      _editTagColor =
          tag.color != null && tag.color!.isNotEmpty ? tag.color! : _kTagPalette.first;
    });
  }

  Future<void> _saveTagEdit(JournalTag original) async {
    final newName = _editTagName.text.trim();
    if (newName.isEmpty) {
      error(context, 'Tag name cannot be empty.');
      return;
    }
    setState(() => _tagBusy = true);
    try {
      final updated = await locator<ApiExporter>().updateTag(
        tagId: original.tagId,
        name: newName == original.name ? null : newName,
        color: _editTagColor == original.color ? null : _editTagColor,
      );
      ref.invalidate(journalTagsProvider);
      if (!mounted) return;
      setState(() {
        // Reflect the rename/recolour on this note's chips too.
        _tags = [
          for (final t in _tags) t.tagId == updated.tagId ? updated : t,
        ];
        _editingTagId = null;
        _tagBusy = false;
      });
    } on JournalNotesException catch (e) {
      if (!mounted) return;
      setState(() => _tagBusy = false);
      // TAG_EXISTS on rename: another tag already has this name.
      error(context, e.code == 'TAG_EXISTS'
          ? 'A tag named "$newName" already exists.'
          : e.message);
    }
  }

  void _requestDeleteTag(JournalTag tag) {
    final count = tag.noteCount ?? 0;
    setState(() {
      _confirm = _ConfirmPrompt(
        title: 'Delete tag "${tag.name}"?',
        message: count > 0
            ? 'It is attached to $count note(s) and will be removed from all '
                'of them. This cannot be undone.'
            : 'This cannot be undone.',
        confirmLabel: 'Delete',
        onConfirm: () => _performDeleteTag(tag),
      );
    });
  }

  Future<void> _performDeleteTag(JournalTag tag) async {
    setState(() {
      _confirm = null;
      _tagBusy = true;
    });
    try {
      // force: the confirm the user just answered IS the "are you sure" the
      // backend's TAG_IN_USE refusal exists to prompt.
      await locator<ApiExporter>().deleteTag(tagId: tag.tagId, force: true);
      ref.invalidate(journalTagsProvider);
      if (!mounted) return;
      setState(() {
        _tags.removeWhere((t) => t.tagId == tag.tagId);
        // The deleted tag's manage row was expanded; don't leave the editor
        // pointing at a tag that no longer exists.
        if (_editingTagId == tag.tagId) _editingTagId = null;
        _tagBusy = false;
      });
      successMessage(context, 'Tag deleted');
    } on JournalNotesException catch (e) {
      if (!mounted) return;
      setState(() => _tagBusy = false);
      error(context, e.message);
    }
  }

  bool _isAttached(JournalTag tag) => _tags.any((t) => t.tagId == tag.tagId);

  /// Most-used first — the ordering every tag-management UI converges on —
  /// with an alphabetical tiebreak so the list is stable.
  static int _byUsage(JournalTag a, JournalTag b) {
    final byCount = (b.noteCount ?? 0).compareTo(a.noteCount ?? 0);
    if (byCount != 0) return byCount;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  // --- Attachment operations -------------------------------------------------

  static const int _kMaxAttachments = 3;
  static const int _kMaxAttachmentBytes = 5 * 1024 * 1024;

  int get _attachmentCount => _attachments.length + _queuedFiles.length;

  /// Pick files and upload (existing note) or queue them (new note). The
  /// backend enforces 3 × 5 MB × JPEG/PNG/PDF; the same limits are checked
  /// here first so obvious rejections never cost a round-trip.
  Future<void> _pickAttachments() async {
    if (_attachmentBusy) return;
    final slots = _kMaxAttachments - _attachmentCount;
    if (slots <= 0) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true, // bytes, not paths — dart:io paths don't exist on web
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    var files = result.files.where((f) => f.bytes != null).toList();
    final oversize = [
      for (final f in files)
        if (f.bytes!.length > _kMaxAttachmentBytes) f.name,
    ];
    if (oversize.isNotEmpty) {
      error(context,
          'Larger than 5 MB and skipped: ${oversize.join(', ')}.');
      files.removeWhere((f) => f.bytes!.length > _kMaxAttachmentBytes);
    }
    if (files.length > slots) {
      files = files.sublist(0, slots);
      error(context,
          'A note can carry at most $_kMaxAttachments attachments — extra '
          'files were skipped.');
    }
    if (files.isEmpty) return;

    final noteId = widget.existing?.noteId;
    if (noteId == null) {
      // No note to attach to yet — hold the bytes until the first save.
      setState(() => _queuedFiles
          .addAll([for (final f in files) (bytes: f.bytes!, filename: f.name)]));
      return;
    }

    setState(() => _attachmentBusy = true);
    for (final f in files) {
      try {
        final uploaded = await locator<ApiExporter>().uploadAttachment(
          noteId: noteId,
          bytes: f.bytes!,
          filename: f.name,
        );
        if (!mounted) return;
        setState(() => _attachments.add(uploaded));
      } on JournalNotesException catch (e) {
        if (!mounted) return;
        error(context, '${f.name}: ${e.message}');
      }
    }
    if (mounted) setState(() => _attachmentBusy = false);
  }

  void _requestDeleteAttachment(NoteAttachment attachment) {
    setState(() {
      _confirm = _ConfirmPrompt(
        title: 'Remove this attachment?',
        message: '"${attachment.filename}" will be removed from this note. '
            'This cannot be undone.',
        confirmLabel: 'Remove',
        onConfirm: () => _performDeleteAttachment(attachment),
      );
    });
  }

  Future<void> _performDeleteAttachment(NoteAttachment attachment) async {
    setState(() {
      _confirm = null;
      _attachmentBusy = true;
    });
    try {
      await locator<ApiExporter>().deleteAttachment(attachment.attachmentId);
      if (!mounted) return;
      setState(() {
        _attachments
            .removeWhere((a) => a.attachmentId == attachment.attachmentId);
        _attachmentBusy = false;
      });
    } on JournalNotesException catch (e) {
      if (!mounted) return;
      setState(() => _attachmentBusy = false);
      error(context, e.message);
    }
  }

  /// PDFs download rather than render — the server forces
  /// `Content-Disposition: attachment` — and `Image.network` can't send the
  /// Authorization header anyway, so the bytes come through the API client
  /// and leave through a browser blob.
  Future<void> _downloadAttachmentFile(NoteAttachment attachment) async {
    if (_attachmentBusy) return;
    setState(() => _attachmentBusy = true);
    try {
      final result = await locator<ApiExporter>()
          .downloadAttachment(attachment.attachmentId);
      if (!mounted) return;
      setState(() => _attachmentBusy = false);
      final blob = html.Blob(
          [result.bytes], result.contentType ?? attachment.contentType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', result.filename ?? attachment.filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } on JournalNotesException catch (e) {
      if (!mounted) return;
      setState(() => _attachmentBusy = false);
      error(context, e.message);
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
    return '$bytes B';
  }

  static bool _looksLikePdf(String filename) =>
      filename.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_managingTags)
          _buildManageTagsView(context)
        else
          _buildEditor(context),
        if (_imagePreview != null)
          _buildImagePreviewOverlay(context, _imagePreview!),
        // Confirm stays topmost — a delete confirm can open over the preview.
        if (_confirm != null) _buildConfirmOverlay(context, _confirm!),
      ],
    );
  }

  Widget _buildEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        Divider(
          height: 1,
          color: resolveThemeColor(context,
              dark: MyntColors.dividerDark, light: MyntColors.divider),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: _editing ? _buildEditBody(context) : _buildViewBody(context),
          ),
        ),
        // The read-only view has no footer actions; editing is entered from the
        // header pencil, and Save/Delete only make sense in the form.
        if (_editing) _buildFooter(context),
      ],
    );
  }

  Widget _buildEditBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSnapshotSummary(context),
        const SizedBox(height: 20),
        _label(context, 'Title'),
        const SizedBox(height: 6),
        MyntTextField(
          controller: _title,
          placeholder: 'What happened today?',
          maxLength: 200,
          size: MyntTextFieldSize.medium,
          textStyle: MyntWebTextStyles.body(context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary),
        ),
        const SizedBox(height: 16),
        _label(context, 'Notes'),
        const SizedBox(height: 6),
        SizedBox(
          height: 180,
          child: MyntTextField(
            controller: _comment,
            placeholder: 'Why did you take these trades? What would you do '
                'differently?',
            height: 180,
            maxLines: 8,
            maxLength: 20000,
            size: MyntTextFieldSize.medium,
            textStyle: MyntWebTextStyles.body(context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary),
          ),
        ),
        const SizedBox(height: 16),
        _buildTagsSection(context),
        const SizedBox(height: 16),
        _buildAttachmentsSection(context),
      ],
    );
  }

  /// The read-only view. Same content as the form — P&L hero, title, comment,
  /// tags, attachments — but nothing editable: no text fields, chips can't be
  /// removed, attachments open but can't be added or deleted.
  Widget _buildViewBody(BuildContext context) {
    final note = widget.existing;
    final title = note?.title.trim() ?? '';
    final comment = note?.comment.trim() ?? '';
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final meta = _viewMetaLine();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSnapshotSummary(context),
        const SizedBox(height: 20),
        // The title is the note's headline, not a labelled field.
        Text(
          title.isEmpty ? 'Untitled note' : title,
          style: MyntWebTextStyles.title(context,
              color: title.isEmpty ? muted : null,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
              fontWeight: MyntFonts.semiBold),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 12, color: muted),
              const SizedBox(width: 5),
              Text(meta,
                  style: MyntWebTextStyles.caption(context, color: muted)),
            ],
          ),
        ],
        const SizedBox(height: 18),
        _viewSection(
          context,
          Icons.notes_rounded,
          'Notes',
          Text(
            comment.isEmpty ? 'No notes written for this day.' : comment,
            style: MyntWebTextStyles.body(context,
                    color: comment.isEmpty ? muted : null,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary)
                .copyWith(height: 1.55),
          ),
        ),
        _viewSection(
          context,
          Icons.sell_outlined,
          'Tags',
          _tags.isEmpty
              ? _viewNone(context)
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final tag in _tags) _tagChip(context, tag)],
                ),
        ),
        _viewSection(
          context,
          Icons.attach_file_rounded,
          'Attachments',
          _attachments.isEmpty
              ? _viewNone(context)
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  // Read-only: the tile still previews / downloads, but readOnly
                  // hides the remove ×.
                  children: [
                    for (final a in _attachments)
                      _buildServerAttachmentTile(context, a, readOnly: true),
                  ],
                ),
          last: true,
        ),
      ],
    );
  }

  /// A read-only section: a divider, an icon-led uppercase header, then content.
  /// Gives the view real structure instead of a stack of tiny labels.
  Widget _viewSection(BuildContext context, IconData icon, String label,
      Widget child,
      {bool last = false}) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 1,
          color: resolveThemeColor(context,
              dark: MyntColors.dividerDark, light: MyntColors.divider),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(icon, size: 14, color: muted),
            const SizedBox(width: 7),
            Text(
              label.toUpperCase(),
              style: MyntWebTextStyles.caption(context,
                      color: muted, fontWeight: MyntFonts.medium)
                  .copyWith(letterSpacing: 0.6),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
        SizedBox(height: last ? 0 : 18),
      ],
    );
  }

  Widget _viewNone(BuildContext context) => Text(
        'None',
        style: MyntWebTextStyles.caption(context,
            darkColor: MyntColors.textTertiaryDark,
            lightColor: MyntColors.textTertiary),
      );

  /// "Added 12 May 2026" (+ "· edited 13 May" when it was changed later).
  String _viewMetaLine() {
    final c = widget.existing?.createdAt;
    if (c == null) return '';
    final added = 'Added ${DateFormat('d MMM yyyy').format(c)}';
    final u = widget.existing?.updatedAt;
    if (u != null && u.difference(c).inMinutes.abs() > 1) {
      return '$added · edited ${DateFormat('d MMM').format(u)}';
    }
    return added;
  }

  // --- Attachments UI --------------------------------------------------------

  Widget _buildAttachmentsSection(BuildContext context) {
    final count = _attachmentCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _label(context, 'Attachments'),
            const Spacer(),
            Text(
              '$count of $_kMaxAttachments',
              style: MyntWebTextStyles.caption(context,
                  darkColor: MyntColors.textTertiaryDark,
                  lightColor: MyntColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in _attachments) _buildServerAttachmentTile(context, a),
            for (var i = 0; i < _queuedFiles.length; i++)
              _buildQueuedFileTile(context, i),
            if (count < _kMaxAttachments) _buildAddTile(context),
          ],
        ),
        if (_queuedFiles.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Uploads when the note is saved.',
            style: MyntWebTextStyles.caption(context,
                darkColor: MyntColors.textTertiaryDark,
                lightColor: MyntColors.textTertiary),
          ),
        ],
      ],
    );
  }

  /// The shared tile frame: an 84px square with the content clipped inside,
  /// a remove × in the corner, and the filename captioned underneath. In
  /// [readOnly] the × is omitted — the read-only note view can still open the
  /// attachment but not remove it.
  Widget _buildAttachmentTileShell(
    BuildContext context, {
    required Widget child,
    required String filename,
    required String semanticsLabel,
    required VoidCallback onRemove,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return SizedBox(
      width: 84,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Semantics(
                label: semanticsLabel,
                button: onTap != null,
                child: InkWell(
                  onTap: _attachmentBusy ? null : onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 84,
                    height: 84,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: resolveThemeColor(context,
                          dark: MyntColors.inputBgDark,
                          light: MyntColors.inputBg),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: resolveThemeColor(context,
                              dark: MyntColors.borderMutedDark,
                              light: MyntColors.borderMuted)),
                    ),
                    child: child,
                  ),
                ),
              ),
              if (!readOnly)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Semantics(
                    label: 'Remove $filename',
                    button: true,
                    child: InkWell(
                      onTap: _attachmentBusy ? null : onRemove,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          // Dark scrim so the × stays visible over any image.
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.caption(context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildServerAttachmentTile(
      BuildContext context, NoteAttachment attachment,
      {bool readOnly = false}) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    if (attachment.isImage) {
      final bytesAsync =
          ref.watch(attachmentBytesProvider(attachment.attachmentId));
      final bytes = bytesAsync.value;
      return _buildAttachmentTileShell(
        context,
        readOnly: readOnly,
        filename: attachment.filename,
        semanticsLabel: 'Preview attachment ${attachment.filename}',
        onRemove: () => _requestDeleteAttachment(attachment),
        onTap: bytes == null
            ? null
            : () => setState(() => _imagePreview =
                (filename: attachment.filename, bytes: bytes)),
        child: bytesAsync.when(
          loading: () => const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) =>
              Icon(Icons.broken_image_outlined, size: 22, color: secondary),
          data: (b) =>
              Image.memory(b, width: 84, height: 84, fit: BoxFit.cover),
        ),
      );
    }

    // PDF: no inline render — the tile is a download button.
    return _buildAttachmentTileShell(
      context,
      readOnly: readOnly,
      filename: attachment.filename,
      semanticsLabel: 'Download attachment ${attachment.filename}',
      onRemove: () => _requestDeleteAttachment(attachment),
      onTap: () => _downloadAttachmentFile(attachment),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf_rounded, size: 24, color: secondary),
          const SizedBox(height: 4),
          Text(
            _formatBytes(attachment.byteSize),
            style: MyntWebTextStyles.caption(context, color: secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildQueuedFileTile(BuildContext context, int index) {
    final file = _queuedFiles[index];
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final isPdf = _looksLikePdf(file.filename);

    return _buildAttachmentTileShell(
      context,
      filename: file.filename,
      semanticsLabel: isPdf
          ? 'Queued attachment ${file.filename}'
          : 'Preview queued attachment ${file.filename}',
      // Nothing on the server yet — removing is instant, no confirm needed.
      onRemove: () => setState(() => _queuedFiles.removeAt(index)),
      onTap: isPdf
          ? null
          : () => setState(() =>
              _imagePreview = (filename: file.filename, bytes: file.bytes)),
      child: isPdf
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf_rounded, size: 24, color: secondary),
                const SizedBox(height: 4),
                Text(
                  _formatBytes(file.bytes.length),
                  style: MyntWebTextStyles.caption(context, color: secondary),
                ),
              ],
            )
          : Image.memory(file.bytes, width: 84, height: 84, fit: BoxFit.cover),
    );
  }

  Widget _buildAddTile(BuildContext context) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Semantics(
      label: 'Add attachment',
      button: true,
      child: InkWell(
        onTap: _attachmentBusy ? null : _pickAttachments,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: resolveThemeColor(context,
                  dark: MyntColors.borderMutedDark,
                  light: MyntColors.borderMuted),
            ),
          ),
          child: _attachmentBusy
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 22, color: secondary),
                    const SizedBox(height: 4),
                    Text(
                      'Add',
                      style: MyntWebTextStyles.caption(context,
                          color: secondary, fontWeight: MyntFonts.medium),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Full-size image view, drawn inside the sheet's own Stack for the same
  /// reason as the confirm prompt: a Material dialog would layer below the
  /// shadcn drawer. Scrim tap or the × closes it.
  Widget _buildImagePreviewOverlay(
      BuildContext context, ({String filename, Uint8List bytes}) preview) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _imagePreview = null),
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      preview.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.bodySmall(context,
                          color: Colors.white,
                          fontWeight: MyntFonts.medium),
                    ),
                  ),
                  Semantics(
                    label: 'Close preview',
                    button: true,
                    child: InkWell(
                      onTap: () => setState(() => _imagePreview = null),
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {}, // taps on the image itself don't close
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(preview.bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The discard / delete confirmation, drawn on top of the sheet content. It
  /// lives inside the sheet's own render tree — not a Material dialog — so it
  /// always paints above the shadcn drawer overlay and is actually reachable.
  Widget _buildConfirmOverlay(BuildContext context, _ConfirmPrompt prompt) {
    return Positioned.fill(
      child: GestureDetector(
        // Tapping the scrim cancels — but does not fall through to the editor.
        onTap: () => setState(() => _confirm = null),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: GestureDetector(
            onTap: () {}, // swallow taps on the card itself
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: resolveThemeColor(context,
                    dark: MyntColors.cardDark, light: MyntColors.card),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prompt.title,
                      style: MyntWebTextStyles.title(context,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                          fontWeight: MyntFonts.semiBold)),
                  const SizedBox(height: 8),
                  Text(prompt.message,
                      style: MyntWebTextStyles.bodySmall(context,
                          darkColor: MyntColors.textSecondaryDark,
                          lightColor: MyntColors.textSecondary)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      MyntTextButton(
                        label: 'Cancel',
                        onPressed: () => setState(() => _confirm = null),
                      ),
                      const SizedBox(width: 8),
                      MyntPrimaryButton(
                        label: prompt.confirmLabel,
                        backgroundColor: resolveThemeColor(context,
                            dark: MyntColors.lossDark, light: MyntColors.loss),
                        onPressed: () => prompt.onConfirm(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Tags UI ---------------------------------------------------------------
  //
  // A combobox in the ARIA sense: selected tags render as chips inside the
  // field, typing filters, and a panel below lists every tag as a toggling
  // row (click attaches, click again detaches — the panel stays open across
  // selections). ↑/↓ move a highlight, Enter toggles it, Esc closes,
  // Backspace on an empty query removes the last chip. The panel is laid out
  // inline rather than floated: the shadcn drawer provides no Overlay, and
  // anything Overlay-based dies inside this sheet.

  static const double _kTagRowHeight = 40;
  static const double _kTagPanelMaxHeight = 224; // ~5.5 rows, then scrolls

  /// The panel's tag rows for the current query, most-used first.
  List<JournalTag> _panelTags(List<JournalTag> allTags) {
    final query = _tagQuery.text.trim().toLowerCase();
    return [
      for (final t in allTags)
        if (query.isEmpty || t.name.toLowerCase().contains(query)) t,
    ];
  }

  bool _showCreateRow(List<JournalTag> allTags) {
    final query = _tagQuery.text.trim();
    return query.isNotEmpty &&
        !allTags.any((t) => t.name.toLowerCase() == query.toLowerCase());
  }

  KeyEventResult _handleTagKey(KeyEvent event, int rowCount) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      if (rowCount > 0) {
        final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
        setState(() =>
            _tagHighlight = (_tagHighlight + step).clamp(0, rowCount - 1));
        _scrollTagHighlightIntoView();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _tagFocus.unfocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace &&
        event is KeyDownEvent &&
        _tagQuery.text.isEmpty &&
        _tags.isNotEmpty) {
      _removeTag(_tags.last);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrollTagHighlightIntoView() {
    if (!_tagPanelScroll.hasClients || _tagHighlight < 0) return;
    final top = _tagHighlight * _kTagRowHeight;
    final bottom = top + _kTagRowHeight;
    final position = _tagPanelScroll.position;
    if (top < position.pixels) {
      position.jumpTo(top);
    } else if (bottom > position.pixels + position.viewportDimension) {
      position.jumpTo(bottom - position.viewportDimension);
    }
  }

  /// Enter: act on the keyboard highlight if there is one, else attach the
  /// exact match, else create. The field refocuses afterwards — onSubmitted
  /// blurs by default and the panel must survive multi-attach workflows.
  void _onTagSubmitted(
      String text, List<JournalTag> rows, bool showCreate) {
    final query = text.trim();
    if (_tagHighlight >= 0 && _tagHighlight < rows.length) {
      final tag = rows[_tagHighlight];
      _isAttached(tag) ? _removeTag(tag) : _attachTag(tag);
    } else if (showCreate && query.isNotEmpty) {
      // showCreate means no tag has this exact name.
      _createAndAttachTag(query);
    } else if (query.isNotEmpty) {
      final exact = rows.where(
          (t) => t.name.toLowerCase() == query.toLowerCase());
      if (exact.isNotEmpty && !_isAttached(exact.first)) {
        _attachTag(exact.first);
      }
    }
    _tagFocus.requestFocus();
  }

  Widget _buildTagsSection(BuildContext context) {
    final tagsAsync = ref.watch(journalTagsProvider);
    final allTags = [...(tagsAsync.value ?? const <JournalTag>[])]
      ..sort(_byUsage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _label(context, 'Tags'),
            const Spacer(),
            // NOTE: no Tooltip anywhere inside this sheet — Tooltip needs an
            // Overlay ancestor, and the shadcn drawer has none. It throws
            // "No Overlay widget found" at runtime.
            Semantics(
              label: 'Manage tags',
              button: true,
              child: InkWell(
                onTap: () => setState(() => _managingTags = true),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Manage',
                    style: MyntWebTextStyles.caption(context,
                        darkColor: MyntColors.primaryDark,
                        lightColor: MyntColors.primary,
                        fontWeight: MyntFonts.medium),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Clicking a panel row must not count as tapping outside the text
        // field (which would blur it and close the panel mid-selection).
        TextFieldTapRegion(
          child: AnimatedBuilder(
            // Driven directly by the controller: the panel must re-filter on
            // every keystroke, and a plain onChanged→setState proved
            // unreliable here (the same stale-rebuild trap the Save button
            // hit in Phase 2).
            animation: _tagQuery,
            builder: (context, _) {
              final rows = _panelTags(allTags);
              final showCreate = _showCreateRow(allTags);
              final rowCount = rows.length + (showCreate ? 1 : 0);
              return Focus(
                onKeyEvent: (_, event) => _handleTagKey(event, rowCount),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTagField(context, rows, showCreate),
                    if (_tagFocus.hasFocus)
                      _buildTagPanel(
                          context, tagsAsync, allTags, rows, showCreate),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Selected chips and the filter input share one bordered field, chips
  /// wrapping ahead of the caret.
  Widget _buildTagField(
      BuildContext context, List<JournalTag> rows, bool showCreate) {
    final focused = _tagFocus.hasFocus;
    final borderColor = focused
        ? resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary)
        : resolveThemeColor(context,
            dark: MyntColors.borderMutedDark, light: MyntColors.borderMuted);

    final input = TextField(
      controller: _tagQuery,
      focusNode: _tagFocus,
      maxLength: 40,
      style: MyntWebTextStyles.body(context,
          darkColor: MyntColors.textPrimaryDark,
          lightColor: MyntColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        hintText: _tags.isEmpty ? 'Add tags — setup, mistake, emotion…' : 'Add…',
        hintStyle: MyntWebTextStyles.bodySmall(context,
            darkColor: MyntColors.textTertiaryDark,
            lightColor: MyntColors.textTertiary),
      ),
      onSubmitted: (text) => _onTagSubmitted(text, rows, showCreate),
    );

    return InkWell(
      onTap: () => _tagFocus.requestFocus(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: MyntColors.inputBgDark, light: MyntColors.inputBg),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: _tags.isEmpty
            ? input
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final tag in _tags)
                    _tagChip(context, tag, onRemove: () => _removeTag(tag)),
                  SizedBox(width: 120, child: input),
                ],
              ),
      ),
    );
  }

  Widget _buildTagPanel(
    BuildContext context,
    AsyncValue<List<JournalTag>> tagsAsync,
    List<JournalTag> allTags,
    List<JournalTag> rows,
    bool showCreate,
  ) {
    final itemCount = rows.length + (showCreate ? 1 : 0);
    final isDark = isDarkMode(context);

    Widget body;
    if (tagsAsync.isLoading && allTags.isEmpty) {
      body = _panelMessage(context, 'Loading tags…');
    } else if (itemCount == 0) {
      body = _panelMessage(
          context,
          allTags.isEmpty
              ? 'No tags yet — type a name and press Enter to create one.'
              : 'No matching tags — keep typing to create one.');
    } else {
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _kTagPanelMaxHeight),
        child: ListView.builder(
          controller: _tagPanelScroll,
          shrinkWrap: true,
          itemExtent: _kTagRowHeight,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (showCreate && index == rows.length) {
              return _buildCreatePanelRow(context, allTags, index);
            }
            return _buildTagPanelRow(context, rows[index], index);
          },
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.overlayBgDark, light: MyntColors.overlayBg),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: resolveThemeColor(context,
                dark: MyntColors.borderMutedDark,
                light: MyntColors.borderMuted)),
        boxShadow: isDark ? MyntShadows.dropdownDark : MyntShadows.dropdown,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_tagBusy) const LinearProgressIndicator(minHeight: 2),
          body,
          Divider(
            height: 1,
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
          ),
          // The panel's footer action, à la GitHub's label picker.
          Semantics(
            label: 'Manage tags',
            button: true,
            child: InkWell(
              onTap: () {
                _tagFocus.unfocus();
                setState(() => _managingTags = true);
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded,
                        size: 14,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary)),
                    const SizedBox(width: 6),
                    Text(
                      'Manage tags',
                      style: MyntWebTextStyles.caption(context,
                          darkColor: MyntColors.textSecondaryDark,
                          lightColor: MyntColors.textSecondary,
                          fontWeight: MyntFonts.medium),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelMessage(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(
        message,
        style: MyntWebTextStyles.caption(context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary),
      ),
    );
  }

  /// One toggling row: colour dot, name, usage count, and a ✓ when attached.
  Widget _buildTagPanelRow(BuildContext context, JournalTag tag, int index) {
    final attached = _isAttached(tag);
    final highlighted = _tagHighlight == index;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final color = hexToColor(tag.color, fallback: secondary);
    final count = tag.noteCount ?? 0;

    return Semantics(
      label: attached ? 'Remove tag ${tag.name}' : 'Add tag ${tag.name}',
      button: true,
      child: InkWell(
        onTap: _tagBusy
            ? null
            : () {
                attached ? _removeTag(tag) : _attachTag(tag);
                _tagFocus.requestFocus();
              },
        child: Container(
          color: highlighted
              ? resolveThemeColor(context,
                  dark: MyntColors.rowHoverDark, light: MyntColors.rowHover)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tag.name,
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.body(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary),
                ),
              ),
              if (count > 0)
                Text(
                  '$count ${count == 1 ? 'note' : 'notes'}',
                  style: MyntWebTextStyles.caption(context, color: secondary),
                ),
              if (attached) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_rounded,
                    size: 16,
                    color: resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The last panel row when the query matches nothing exactly, previewing
  /// the palette colour the new tag will receive.
  Widget _buildCreatePanelRow(
      BuildContext context, List<JournalTag> allTags, int index) {
    final query = _tagQuery.text.trim();
    final highlighted = _tagHighlight == index;
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final previewColor =
        hexToColor(_kTagPalette[allTags.length % _kTagPalette.length]);

    return Semantics(
      label: 'Create tag $query',
      button: true,
      child: InkWell(
        onTap: _tagBusy ? null : () => _createAndAttachTag(query),
        child: Container(
          color: highlighted
              ? resolveThemeColor(context,
                  dark: MyntColors.rowHoverDark, light: MyntColors.rowHover)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Create "$query"',
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.body(context,
                      color: accent, fontWeight: MyntFonts.medium),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: previewColor, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A tag chip: colour dot, tinted rounded-rect background, and an optional
  /// trailing × to detach. Also used as the live preview in the manage view.
  Widget _tagChip(BuildContext context, JournalTag tag,
      {VoidCallback? onRemove}) {
    final color = hexToColor(tag.color,
        fallback: resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary));
    return Semantics(
      label: 'Tag ${tag.name}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tag.name,
                overflow: TextOverflow.ellipsis,
                style: MyntWebTextStyles.para(context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                    fontWeight: MyntFonts.medium),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 5),
              Semantics(
                label: 'Remove tag ${tag.name}',
                button: true,
                child: InkWell(
                  onTap: _tagBusy ? null : onRemove,
                  borderRadius: BorderRadius.circular(999),
                  child: Icon(Icons.close_rounded,
                      size: 13,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManageTagsView(BuildContext context) {
    final tagsAsync = ref.watch(journalTagsProvider);
    final allTags = [...(tagsAsync.value ?? const <JournalTag>[])]
      ..sort(_byUsage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
          child: Row(
            children: [
              Semantics(
                label: 'Back to the note',
                button: true,
                child: InkWell(
                  onTap: () => setState(() {
                    _managingTags = false;
                    _editingTagId = null;
                  }),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 20,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manage tags',
                        style: MyntWebTextStyles.title(context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary,
                            fontWeight: MyntFonts.semiBold)),
                    const SizedBox(height: 2),
                    Text(
                        allTags.isEmpty
                            ? 'Label your trading days'
                            : '${allTags.length} '
                                'tag${allTags.length == 1 ? '' : 's'} · '
                                'most used first',
                        style: MyntWebTextStyles.caption(context,
                            darkColor: MyntColors.textSecondaryDark,
                            lightColor: MyntColors.textSecondary)),
                  ],
                ),
              ),
              MyntCloseButton(onPressed: _handleClose),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: resolveThemeColor(context,
              dark: MyntColors.dividerDark, light: MyntColors.divider),
        ),
        Expanded(
          child: tagsAsync.when(
            loading: () => const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Center(
              child: Text(
                'Could not load tags',
                style: MyntWebTextStyles.bodySmall(context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary),
              ),
            ),
            data: (tags) {
              if (tags.isEmpty) return _buildManageEmptyState(context);
              final sorted = [...tags]..sort(_byUsage);
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: resolveThemeColor(context,
                      dark: MyntColors.dividerDark, light: MyntColors.divider),
                ),
                itemBuilder: (context, index) =>
                    _buildManageTagRow(context, sorted[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildManageEmptyState(BuildContext context) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sell_outlined, size: 30, color: secondary),
          const SizedBox(height: 10),
          Text('No tags yet',
              style: MyntWebTextStyles.body(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium)),
          const SizedBox(height: 4),
          Text(
            'Create tags from the note editor\'s tag field —\n'
            'label your setups, mistakes and emotions.',
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.caption(context, color: secondary),
          ),
        ],
      ),
    );
  }

  /// One accordion row. Collapsed, the entire row is the tap target and
  /// carries no icon chrome — just the tag as it really renders, its usage,
  /// and a chevron. Tapping expands it in place into the rename/recolour
  /// editor; Delete lives inside the expanded editor, not on every row.
  Widget _buildManageTagRow(BuildContext context, JournalTag tag) {
    final expanded = _editingTagId == tag.tagId;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final count = tag.noteCount ?? 0;

    // While expanded, the header chip doubles as the live preview.
    final headerChip = expanded
        ? AnimatedBuilder(
            animation: _editTagName,
            builder: (context, _) {
              final name = _editTagName.text.trim();
              return _tagChip(
                context,
                JournalTag(
                  tagId: tag.tagId,
                  name: name.isEmpty ? tag.name : name,
                  color: _editTagColor,
                ),
              );
            },
          )
        : _tagChip(context, tag);

    final header = Semantics(
      label: expanded ? 'Collapse tag ${tag.name}' : 'Edit tag ${tag.name}',
      button: true,
      child: InkWell(
        onTap: _tagBusy
            ? null
            : () => expanded
                ? setState(() => _editingTagId = null)
                : _startEditTag(tag),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: headerChip,
                ),
              ),
              Text(
                count == 0 ? 'unused' : '$count note${count == 1 ? '' : 's'}',
                style: MyntWebTextStyles.caption(context, color: secondary),
              ),
              const SizedBox(width: 6),
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
                color: secondary,
              ),
            ],
          ),
        ),
      ),
    );

    if (!expanded) return header;

    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.rowHoverDark, light: MyntColors.rowHover),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyntTextField(
                  controller: _editTagName,
                  placeholder: 'Tag name',
                  maxLength: 40,
                  size: MyntTextFieldSize.medium,
                  onSubmitted: (_) => _saveTagEdit(tag),
                  textStyle: MyntWebTextStyles.body(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final hex in _kTagPalette)
                      Semantics(
                        label: 'Colour $hex',
                        button: true,
                        child: InkWell(
                          onTap: () => setState(() => _editTagColor = hex),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: hexToColor(hex),
                              shape: BoxShape.circle,
                            ),
                            child: _editTagColor == hex
                                ? const Icon(Icons.check_rounded,
                                    size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    MyntButton(
                      label: 'Delete',
                      type: MyntButtonType.text,
                      textColor: resolveThemeColor(context,
                          dark: MyntColors.lossDark, light: MyntColors.loss),
                      onPressed:
                          _tagBusy ? null : () => _requestDeleteTag(tag),
                    ),
                    const Spacer(),
                    MyntTextButton(
                      label: 'Cancel',
                      onPressed: () => setState(() => _editingTagId = null),
                    ),
                    const SizedBox(width: 8),
                    MyntPrimaryButton(
                      label: 'Save',
                      isLoading: _tagBusy,
                      onPressed: _tagBusy ? null : () => _saveTagEdit(tag),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.edit_note_rounded, size: 22, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editing ? (_isNew ? 'Add note' : 'Edit note') : 'View note',
                  style: MyntWebTextStyles.title(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.semiBold),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_prettyDate · ${widget.group.tabLabel}',
                  style: MyntWebTextStyles.caption(context,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary,
                      fontWeight: MyntFonts.medium),
                ),
              ],
            ),
          ),
          // In the read-only view the pencil is the way into editing.
          if (!_editing)
            Semantics(
              label: 'Edit note',
              button: true,
              child: InkWell(
                onTap: () => setState(() => _editing = true),
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.edit_outlined, size: 20, color: accent),
                ),
              ),
            ),
          MyntCloseButton(onPressed: _handleClose),
        ],
      ),
    );
  }

  /// Shows the number being stored, so the note and the heat map visibly agree.
  Widget _buildSnapshotSummary(BuildContext context) {
    final snapshot = _effectiveSnapshot;
    if (snapshot == null) {
      // No P&L row for this day — the note saves, but analytics cannot see it.
      return _infoBanner(
        context,
        'No P&L was recorded for this day, so this note will not appear in '
        'your tag insights.',
        resolveThemeColor(context,
            dark: MyntColors.warningDark, light: MyntColors.warning),
      );
    }

    final realised = snapshot.realised;
    final isProfit = realised >= 0;
    final color = isProfit
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This day's realised P&L",
                  style: MyntWebTextStyles.bodySmall(context,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAmount(realised),
                  style: MyntWebTextStyles.head(context,
                      color: color, fontWeight: MyntFonts.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isProfit
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 20,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner(BuildContext context, String message, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: MyntWebTextStyles.caption(context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: MyntWebTextStyles.bodySmall(context,
          darkColor: MyntColors.textSecondaryDark,
          lightColor: MyntColors.textSecondary,
          fontWeight: MyntFonts.medium),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
          ),
        ),
      ),
      child: Row(
        children: [
          if (!_isNew)
            // MyntTextButton does not forward textColor, so use the base
            // button with the text variant to tint Delete red.
            MyntButton(
              label: 'Delete',
              type: MyntButtonType.text,
              textColor: resolveThemeColor(context,
                  dark: MyntColors.lossDark, light: MyntColors.loss),
              isLoading: _deleting,
              onPressed: _deleting ? null : _requestDelete,
            ),
          const Spacer(),
          // Rebuilds on every keystroke so the Save button's enabled state
          // tracks the text live. A plain field listener + setState would not
          // do: the button reads the controllers, and nothing else here
          // depends on their per-keystroke value.
          AnimatedBuilder(
            animation: Listenable.merge([_title, _comment]),
            builder: (context, _) {
              final canSave = _canSave;
              // MyntButton renders a null onPressed identically to an enabled
              // button — same fill, same text — so a disabled Save looks
              // clickable and silently does nothing. Mute it explicitly.
              return MyntPrimaryButton(
                label: _isNew ? 'Save note' : 'Save changes',
                isLoading: _saving,
                backgroundColor: canSave
                    ? null
                    : resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary)
                        .withValues(alpha: 0.25),
                onPressed: canSave ? _save : null,
              );
            },
          ),
        ],
      ),
    );
  }

  bool get _hasContent =>
      _title.text.trim().isNotEmpty || _comment.text.trim().isNotEmpty;
}
