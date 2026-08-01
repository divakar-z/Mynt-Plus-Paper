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
import '../../../../sharedWidget/no_data_found_web.dart';
import '../../../../sharedWidget/snack_bar.dart';
import '../../../../utils/overlay_manager.dart';

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

  // openSheetOverlay rather than openSheet: the completer allows the sheet
  // to be force-closed from outside. Session expiry / logout / account
  // switch run OverlayManager.closeAll() — without registering there, this
  // sheet survives the navigation to /login (the drawer overlay is mounted
  // ABOVE the router in main.dart) and floats over the login screen as an
  // editable dead form whose Save can only return AUTH_INVALID.
  final completer = shadcn.openSheetOverlay<void>(
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
          // The sheet-local Overlay is load-bearing, not decoration:
          // EditableText's selection machinery (caret taps, handles, context
          // menu) requires an Overlay ancestor, and the shadcn drawer subtree
          // has none — the app Navigator's overlay sits BELOW the drawer
          // layer. Without it, every tap in a text field threw "No Overlay
          // widget found" mid-pipeline, which left the browser's hidden input
          // out of sync with the (cleared) controller — the resurrecting
          // stale-text bug in the tag field. The entry builds from the
          // sheet's fixed parameters, so the once-only initialEntries
          // construction cannot go stale.
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (overlayContext) => _NoteEditorContent(
                  noteDate: noteDate,
                  group: group,
                  existing: existing,
                  snapshot: snapshot,
                  rangeKey: rangeKey,
                  // A new note has nothing to view, so it always starts in
                  // the form.
                  startInEdit: startInEdit || existing == null,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  // Registered for the lifetime of the sheet; force-closing completes the
  // entry, which resumes the await below and unregisters again.
  void forceClose() => completer.remove();
  OverlayManager.registerSheetCloser(forceClose);
  await completer.future;
  OverlayManager.unregisterSheetCloser(forceClose);

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

/// RETIRED (2026-07-24): every confirmation now goes through
/// [_NoteEditorContentState._showConfirmDialog], the full-screen watchlist-style
/// dialog stacked as a drawer-overlay entry. This in-sheet prompt and its
/// overlay builder are kept dormant for cheap rollback — nothing sets
/// [_NoteEditorContentState._confirm] any more.
///
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

class _NoteEditorContentState extends ConsumerState<_NoteEditorContent>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _title;
  late final TextEditingController _comment;
  late final String _originalTitle;
  late final String _originalComment;
  bool _saving = false;
  bool _deleting = false;

  /// Inline validation message under the footer, set when Save is clicked
  /// with nothing to save. Rendered only while [_canSave] is still false, so
  /// it disappears on its own the moment the note becomes saveable.
  String? _saveError;

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

  /// `2026-05-15` → `Fri, 15 May 2026` for the header caption. The stored key
  /// stays ISO.
  String get _prettyDate {
    final d = DateTime.tryParse(widget.noteDate);
    // return d != null ? DateFormat('dd MMM yyyy').format(d) : widget.noteDate;
    return d != null
        ? DateFormat('EEE, dd MMM yyyy').format(d)
        : widget.noteDate;
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
    // The button is always enabled (app convention: submit buttons never
    // disable for validation) — the click validates instead. The message is
    // inline, not a toast: web toasts render top-right inside the Navigator's
    // overlay, which sits BELOW this drawer sheet — a toast here would be
    // invisible behind the sheet.
    if (!_canSave) {
      setState(() {
        _saveError = _isNew
            ? 'Add a title, note, tag or attachment before saving.'
            : 'No changes to save yet.';
      });
      return;
    }
    _saveError = null;
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
      // Full-screen dialog (Delete Watchlist style), no longer the in-sheet
      // _ConfirmPrompt overlay — confirmations match the rest of the app.
      // setState(() {
      //   _confirm = _ConfirmPrompt(
      //     title: 'Discard changes?',
      //     message: 'You have unsaved changes to this note. Closing now will '
      //         'discard them.',
      //     confirmLabel: 'Discard',
      //     onConfirm: () async {
      //       if (mounted) shadcn.closeSheet(context);
      //     },
      //   );
      // });
      _showConfirmDialog(
        title: 'Discard changes?',
        message: 'You have unsaved changes to this note. Closing now will '
            'discard them.',
        confirmLabel: 'Discard',
        onConfirm: () {
          if (mounted) shadcn.closeSheet(context);
        },
      );
      return;
    }
    shadcn.closeSheet(context);
  }

  /// Full-screen confirmation in the Delete Watchlist style: centred 400px
  /// card over a dimmed screen, title + close in a bordered header, centred
  /// message, one full-width red action (the header X is the cancel).
  /// Every confirmation in this sheet goes through here — discard changes,
  /// delete note, delete tag, remove attachment.
  ///
  /// NOT a Navigator dialog: main.dart mounts the app's shadcn DrawerOverlay
  /// ABOVE the router, so showDialog/showGeneralDialog render behind this
  /// sheet, unreachable inside its inert backdrop. The confirm is instead
  /// stacked as a second entry in the same drawer overlay — later entries
  /// paint above the sheet, and while this one is open the sheet itself
  /// becomes part of the backdrop, so it is properly modal.
  void _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    // Zero-duration controller pinned at 1: drawer entries slide in from
    // their edge, and a full-screen dim sliding out reads as a shutter
    // effect. Pinning the animation makes the dialog pop in/out like a
    // normal confirm instead.
    final animation = AnimationController(
      vsync: this,
      duration: Duration.zero,
      value: 1,
    );
    final confirmCompleter = shadcn.openRawDrawer<void>(
      context: context,
      position: shadcn.OverlayPosition.top,
      transformBackdrop: false,
      useSafeArea: false,
      animationController: animation,
      // Dismissal is handled by our own dim layer + the header X below.
      barrierDismissible: false,
      builder: (drawerContext, extraSize, size, padding, stackIndex) {
        return GestureDetector(
          // Clicking the dim behaves like a dialog barrier: cancel.
          onTap: () => shadcn.closeDrawer(drawerContext),
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {}, // absorb taps on the card itself
              // The drawer entry is outside the sheet's Material; the ink
              // widgets inside (MyntCloseButton, MyntButton) need one.
              child: Material(
                color: Colors.transparent,
                child: shadcn.Card(
                  borderRadius: BorderRadius.circular(8),
                  padding: EdgeInsets.zero,
                  child: Container(
                    width: 400,
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: resolveThemeColor(drawerContext,
                          dark: MyntColors.dialogDark, light: MyntColors.dialog),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: shadcn.Theme.of(drawerContext)
                                    .colorScheme
                                    .border,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                title,
                                style: MyntWebTextStyles.title(drawerContext,
                                    darkColor: MyntColors.textPrimaryDark,
                                    lightColor: MyntColors.textPrimary),
                              ),
                              MyntCloseButton(
                                onPressed: () =>
                                    shadcn.closeDrawer(drawerContext),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  message,
                                  textAlign: TextAlign.center,
                                  style: MyntWebTextStyles.body(drawerContext,
                                      fontWeight: FontWeight.w500,
                                      darkColor: MyntColors.textPrimaryDark,
                                      lightColor: MyntColors.textPrimary),
                                ),
                                const SizedBox(height: 24),
                                MyntButton(
                                  type: MyntButtonType.primary,
                                  size: MyntButtonSize.large,
                                  label: confirmLabel,
                                  isFullWidth: true,
                                  backgroundColor: resolveThemeColor(
                                      drawerContext,
                                      dark: MyntColors.errorDark,
                                      light: MyntColors.tertiary),
                                  onPressed: () {
                                    // Close the confirm entry first, then run
                                    // the action — each has its own context.
                                    shadcn.closeDrawer(drawerContext);
                                    onConfirm();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    // The confirm is its own drawer entry — a session-expiry sweep must
    // remove it just like the sheet beneath it.
    void forceClose() => confirmCompleter.remove();
    OverlayManager.registerSheetCloser(forceClose);
    confirmCompleter.future.whenComplete(() {
      OverlayManager.unregisterSheetCloser(forceClose);
      // The package only disposes controllers it created; this one is ours.
      animation.dispose();
    });
  }

  void _requestDelete() {
    if (widget.existing == null || _deleting) return;
    _showConfirmDialog(
      title: 'Delete this note?',
      message: 'Your note for ${widget.noteDate} will be removed, along with '
          'its tags and attachments. This cannot be undone.',
      confirmLabel: 'Delete',
      onConfirm: _performDelete,
    );
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
  /// Attaching consumes the query on every path (Enter, highlighted row,
  /// row click): the typed text belongs to the tag just attached, and leaving
  /// it behind meant the next keystroke appended to it ("hjt" + "f" showed
  /// "hjtf"). Originally the filter survived toggles to ease multi-attach
  /// under one filter, but stale text proved worse than retyping a filter.
  /// Post-frame refocus + optional clear. Doing either synchronously is not
  /// enough: attach/create rebuilds (setState, provider invalidation) drop
  /// the field's focus mid-flow, and on web a clear issued while the input
  /// connection is down never reaches the browser's hidden input — when the
  /// connection reopens, the browser pushes the stale text back into the
  /// controller. After the frame settles, the clear lands on a live input.
  void _refocusTagField({bool clearQuery = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tagFocus.requestFocus();
      if (clearQuery) _tagQuery.clear();
    });
  }

  Future<void> _attachTag(JournalTag tag) async {
    if (_tagBusy) return;
    if (_tags.length >= 20) {
      error(context, 'A note can carry at most 20 tags.');
      return;
    }
    // Immediate clear for the panel filter; the post-frame clear below is the
    // one that survives the web input-connection churn.
    _tagQuery.clear();
    final noteId = widget.existing?.noteId;
    if (noteId == null) {
      setState(() => _tags.add(tag));
      _refocusTagField(clearQuery: true);
      return;
    }
    // The round-trip's rebuilds can drop the field's focus and close the
    // panel mid-flow; restore it so multi-attach keeps working.
    setState(() => _tagBusy = true);
    try {
      final result = await locator<ApiExporter>()
          .attachTags(noteId: noteId, tagIds: [tag.tagId]);
      if (!mounted) return;
      setState(() {
        _tags = result;
        _tagBusy = false;
      });
      _refocusTagField(clearQuery: true);
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
      // Post-frame, not synchronous: the rebuild above can drop focus after
      // an early requestFocus, leaving the caret dead. Never grabs focus the
      // user did not have (chip × with the panel closed stays closed).
      if (hadFocus) _refocusTagField();
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
      _tagQuery.clear();
      setState(() => _tagBusy = false);
      // _attachTag schedules the post-frame refocus + clear that survives
      // this flow's rebuild churn (provider invalidation + setState).
      await _attachTag(result.tag);
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
    _showConfirmDialog(
      title: 'Delete tag "${tag.name}"?',
      message: count > 0
          ? 'It is attached to $count note(s) and will be removed from all '
              'of them. This cannot be undone.'
          : 'This cannot be undone.',
      confirmLabel: 'Delete',
      onConfirm: () => _performDeleteTag(tag),
    );
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
    _showConfirmDialog(
      title: 'Remove this attachment?',
      message: '"${attachment.filename}" will be removed from this note. '
          'This cannot be undone.',
      confirmLabel: 'Remove',
      onConfirm: () => _performDeleteAttachment(attachment),
    );
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
    // Dead-space clicks anywhere in the sheet close the tag panel. Deeper
    // interactive widgets (fields, chips, panel rows, buttons) win the
    // gesture arena, so this fires only on blank areas.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_tagFocus.hasFocus) _tagFocus.unfocus();
      },
      child: _buildEditorColumn(context),
    );
  }

  Widget _buildEditorColumn(BuildContext context) {
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
        // Field widget, height and spacing mirror the Create SIP dialog.
        const SizedBox(height: 10),
        // MyntTextField(
        //   controller: _title,
        //   placeholder: 'What happened today?',
        //   maxLength: 200,
        //   size: MyntTextFieldSize.medium,
        //   textStyle: MyntWebTextStyles.body(context,
        //       darkColor: MyntColors.textPrimaryDark,
        //       lightColor: MyntColors.textPrimary),
        // ),
        // The limits are enforced by formatters, not `maxLength` — the
        // built-in counter renders inside the field's fixed height and
        // squeezes the input box. The visible counter is drawn separately
        // below, so the box keeps its full height like the Create SIP fields.
        MyntFormTextField(
          controller: _title,
          placeholder: 'What happened today?',
          height: 40,
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
        ),
        _charCounter(context, _title, 200),
        const SizedBox(height: 16),
        _label(context, 'Notes'),
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: MyntFormTextField(
            controller: _comment,
            placeholder: 'Why did you take these trades? What would you do '
                'differently?',
            height: 180,
            maxLines: 8,
            inputFormatters: [LengthLimitingTextInputFormatter(20000)],
          ),
        ),
        _charCounter(context, _comment, 20000),
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
    // Empty-state styling no longer needed — empty sections are hidden.
    // final muted = resolveThemeColor(context,
    //     dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    // final meta = _viewMetaLine(); // fed the hidden created/edited line

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSnapshotSummary(context),
        const SizedBox(height: 20),
        // Empty sections are hidden entirely — a section renders only when
        // it has content, so the view is exactly as long as the note.
        if (title.isNotEmpty)
          _viewSection(
            context,
            Icons.title_rounded,
            'Title',
            Text(
              title,
              style: MyntWebTextStyles.title(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.semiBold),
            ),
          ),
        if (comment.isNotEmpty)
          _viewSection(
            context,
            Icons.notes_rounded,
            'Notes',
            Text(
              comment,
              style: MyntWebTextStyles.body(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary)
                  .copyWith(height: 1.55),
            ),
          ),
        if (_tags.isNotEmpty)
          _viewSection(
            context,
            // Lucide's tag glyph (with the hole) — used for all tag
            // iconography.
            shadcn.LucideIcons.tag,
            'Tags',
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tag in _tags) _tagChip(context, tag)],
            ),
          ),
        if (_attachments.isNotEmpty)
          _viewSection(
            context,
            Icons.attach_file_rounded,
            'Attachments',
            Wrap(
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
        // Header sized like the edit form's field labels (body, medium) so
        // both modes read at the same weight; icon scaled up to match.
        Row(
          children: [
            Icon(icon, size: 18, color: muted),
            const SizedBox(width: 7),
            Text(
              label.toUpperCase(),
              // style: MyntWebTextStyles.caption(context,
              //         color: muted, fontWeight: MyntFonts.medium)
              //     .copyWith(letterSpacing: 0.6),
              style: MyntWebTextStyles.body(context,
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

  /// Retired: empty sections are hidden now instead of showing "None".
  // Widget _viewNone(BuildContext context) => Text(
  //       'None',
  //       style: MyntWebTextStyles.caption(context,
  //           darkColor: MyntColors.textTertiaryDark,
  //           lightColor: MyntColors.textTertiary),
  //     );

  /// "Added 12 May 2026" (+ "· edited 13 May" when it was changed later).
  /// Hidden from the view per design review; kept for cheap re-enable.
  // String _viewMetaLine() {
  //   final c = widget.existing?.createdAt;
  //   if (c == null) return '';
  //   final added = 'Added ${DateFormat('d MMM yyyy').format(c)}';
  //   final u = widget.existing?.updatedAt;
  //   if (u != null && u.difference(c).inMinutes.abs() > 1) {
  //     return '$added · edited ${DateFormat('d MMM').format(u)}';
  //   }
  //   return added;
  // }

  // --- Attachments UI --------------------------------------------------------

  Widget _buildAttachmentsSection(BuildContext context) {
    final count = _attachmentCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Count rides next to the label — "Attachments (2/3)" — instead of
        // sitting detached at the far right of the row.
        Row(
          children: [
            _label(context, 'Attachments'),
            const SizedBox(width: 6),
            Text(
              '($count/$_kMaxAttachments)',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textTertiaryDark,
                  lightColor: MyntColors.textTertiary,
                  fontWeight: MyntFonts.medium),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in _attachments)
              _buildServerAttachmentTile(context, a),
            for (var i = 0; i < _queuedFiles.length; i++)
              _buildQueuedFileTile(context, i),
            if (count < _kMaxAttachments) _buildAddTile(context),
          ],
        ),
        // if (_queuedFiles.isNotEmpty) ...[
        //   const SizedBox(height: 6),
        //   Text(
        //     'Uploads when the note is saved.',
        //     style: MyntWebTextStyles.caption(context,
        //         darkColor: MyntColors.textTertiaryDark,
        //         lightColor: MyntColors.textTertiary),
        //   ),
        // ],
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

  /// The Add tile in the cloud-upload style: blue dashed border on a light
  /// primary wash (static — no hover state by design), accent cloud icon,
  /// semibold "Add image", size limit underneath. Clicking opens the picker;
  /// the spinner shows while a file round-trip is in flight.
  Widget _buildAddTile(BuildContext context) {
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Semantics(
      label: 'Add attachment',
      button: true,
      child: InkWell(
        onTap: _attachmentBusy ? null : _pickAttachments,
        // The tile's own tint is the affordance; the default grey ink hover
        // would muddy it.
        hoverColor: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _DashedBorderPainter(accent.withValues(alpha: 0.7)),
          child: Container(
            width: 120,
            height: 84,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
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
                      Icon(shadcn.LucideIcons.cloudUpload,
                          size: 24, color: accent),
                      const SizedBox(height: 6),
                      Text(
                        'Add image',
                        style: MyntWebTextStyles.bodySmall(context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary,
                            fontWeight: MyntFonts.semiBold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'up to 5 MB',
                        style: MyntWebTextStyles.caption(context,
                            color: secondary),
                      ),
                    ],
                  ),
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
    // Clamped: the create row lives OUTSIDE the list as a pinned footer, so
    // when the highlight moves onto it (index == rows.length) the raw target
    // would overshoot the list's scroll range.
    if (top < position.pixels) {
      position.jumpTo(top.clamp(0.0, position.maxScrollExtent));
    } else if (bottom > position.pixels + position.viewportDimension) {
      position.jumpTo((bottom - position.viewportDimension)
          .clamp(0.0, position.maxScrollExtent));
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
                    style: MyntWebTextStyles.para(context,
                        darkColor: MyntColors.primaryDark,
                        lightColor: MyntColors.primary,
                        fontWeight: MyntFonts.semiBold),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Same label-to-field gap as the Title/Notes fields.
        const SizedBox(height: 10),
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
    // Border matches MyntTextField's (used by the Title/Notes fields above):
    // one colour whether focused or not, so all fields in the form agree.
    // final focused = _tagFocus.hasFocus;
    // final borderColor = focused
    //     ? resolveThemeColor(context,
    //         dark: MyntColors.primaryDark, light: MyntColors.primary)
    //     : resolveThemeColor(context,
    //         dark: MyntColors.borderMutedDark, light: MyntColors.borderMuted);
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.primary);

    final input = TextField(
      controller: _tagQuery,
      focusNode: _tagFocus,
      maxLength: 40,
      // Text and placeholder styles mirror MyntTextField's medium defaults.
      style: MyntWebTextStyles.bodyMedium(context),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        hintText: _tags.isEmpty ? 'Add tags — setup, mistake, emotion…' : 'Add…',
        hintStyle: MyntWebTextStyles.placeholder(context),
      ),
      onSubmitted: (text) => _onTagSubmitted(text, rows, showCreate),
      // Explicit close-on-outside-click: the framework's default tap-outside
      // unfocus does not fire reliably inside the shadcn drawer overlay.
      // Clicks on the panel itself stay "inside" via TextFieldTapRegion.
      onTapOutside: (_) => _tagFocus.unfocus(),
    );

    // A plain tap target, not an InkWell: ink hover/press highlights painted
    // a grey wash over the field once its opaque fill was removed.
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _tagFocus.requestFocus(),
        child: Container(
          width: double.infinity,
        // Radius and minimum height match MyntTextField, so this chip field
        // reads as the same family as the Title/Notes inputs. No fill,
        // unlike those fields — the coloured chips sit directly on the sheet
        // background; a tinted fill behind them looked muddy.
        constraints: const BoxConstraints(minHeight: 40),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          // color: resolveThemeColor(context,
          //     dark: const Color(0xffB5C0CF).withValues(alpha: .15),
          //     light: const Color(0xffF1F3F8)),
          borderRadius: BorderRadius.circular(5),
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
      // True no-data uses the app-wide empty-state widget (as on Holdings);
      // the transient "no match while typing" stays a one-liner.
      // secondaryEnabled: false — the default shows an "Explore" button that
      // navigates to the watchlist, which makes no sense inside this panel.
      body = allTags.isEmpty
          ? NoDataFoundWeb(
              title: 'No tags yet',
              subtitle: 'Type a name and press Enter to create one.',
              secondaryEnabled: false,
              // Same tag glyph as the Manage tags empty state.
              iconWidget: Icon(shadcn.LucideIcons.tag,
                  size: 64,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary)),
            )
          : _panelMessage(
              context, 'No matching tags — keep typing to create one.');
    } else {
      // Only the existing tag rows scroll. The create row is pinned below
      // the list as a footer (see the panel Column) so it never scrolls out
      // of sight while the user is typing a new name.
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _kTagPanelMaxHeight),
        child: ListView.builder(
          controller: _tagPanelScroll,
          shrinkWrap: true,
          itemExtent: _kTagRowHeight,
          itemCount: rows.length,
          itemBuilder: (context, index) =>
              _buildTagPanelRow(context, rows[index], index),
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
          // The create row is a pinned footer under the scrollable list —
          // always in sight while typing, never scrolled away. Keyboard
          // navigation still treats it as the last index (rows.length).
          if (showCreate) ...[
            Divider(
              height: 1,
              color: resolveThemeColor(context,
                  dark: MyntColors.dividerDark, light: MyntColors.divider),
            ),
            SizedBox(
              height: _kTagRowHeight,
              child: _buildCreatePanelRow(context, allTags, rows.length),
            ),
          ],
          // Footer "Manage tags" removed: the header's Manage link (opposite
          // the Tags label) is always visible, so the duplicate here only ate
          // a row of the scrollable list.
          // Divider(
          //   height: 1,
          //   color: resolveThemeColor(context,
          //       dark: MyntColors.dividerDark, light: MyntColors.divider),
          // ),
          // // The panel's footer action, à la GitHub's label picker.
          // Semantics(
          //   label: 'Manage tags',
          //   button: true,
          //   child: InkWell(
          //     onTap: () {
          //       _tagFocus.unfocus();
          //       setState(() => _managingTags = true);
          //     },
          //     child: Padding(
          //       padding:
          //           const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          //       child: Row(
          //         children: [
          //           Icon(Icons.tune_rounded,
          //               size: 14,
          //               color: resolveThemeColor(context,
          //                   dark: MyntColors.textSecondaryDark,
          //                   light: MyntColors.textSecondary)),
          //           const SizedBox(width: 6),
          //           Text(
          //             'Manage tags',
          //             style: MyntWebTextStyles.caption(context,
          //                 darkColor: MyntColors.textSecondaryDark,
          //                 lightColor: MyntColors.textSecondary,
          //                 fontWeight: MyntFonts.medium),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
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

  /// One toggling row: name, usage count, and a ✓ when attached.
  Widget _buildTagPanelRow(BuildContext context, JournalTag tag, int index) {
    final attached = _isAttached(tag);
    final highlighted = _tagHighlight == index;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    // final color = hexToColor(tag.color, fallback: secondary); // fed the dot
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
              // Dot dropped, matching the chips.
              // Container(
              //   width: 10,
              //   height: 10,
              //   decoration:
              //       BoxDecoration(color: color, shape: BoxShape.circle),
              // ),
              // const SizedBox(width: 10),
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

  /// The pinned footer row when the query matches nothing exactly.
  Widget _buildCreatePanelRow(
      BuildContext context, List<JournalTag> allTags, int index) {
    final query = _tagQuery.text.trim();
    final highlighted = _tagHighlight == index;
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    // final previewColor =
    //     hexToColor(_kTagPalette[allTags.length % _kTagPalette.length]); // fed the preview dot

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
              // Palette-preview dot dropped along with the other dots — it
              // read as stray decoration; the colour can be changed in
              // Manage tags anyway.
              // Container(
              //   width: 10,
              //   height: 10,
              //   decoration: BoxDecoration(
              //       color: previewColor, shape: BoxShape.circle),
              // ),
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
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.50)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tag glyph in the tag's own colour (replaced the old dot) —
            // same icon the TAGS section header and empty states use.
            Icon(shadcn.LucideIcons.tag, size: 12, color: color),
            const SizedBox(width: 4),
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
                child: Row(
                  children: [
                    Text('Manage tags',
                        style: MyntWebTextStyles.title(context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary,
                            fontWeight: MyntFonts.semiBold)),
                    // Count rides beside the heading as a rounded tinted
                    // badge; the "N tags · most used first" subtitle is gone.
                    if (allTags.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: resolveThemeColor(context,
                                  dark: MyntColors.primaryDark,
                                  light: MyntColors.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${allTags.length}',
                          style: MyntWebTextStyles.para(context,
                              darkColor: MyntColors.primaryDark,
                              lightColor: MyntColors.primary,
                              fontWeight: MyntFonts.semiBold),
                        ),
                      ),
                    ],
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
                // Same separator as the Position Group tiles: full-width
                // hairline, 0.5 thickness (was inset 20/20).
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 0.5,
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
    // App-wide empty-state widget, keeping the tag glyph (no SVG asset for it
    // exists, hence iconWidget).
    // return Center(
    //   child: Column(
    //     mainAxisSize: MainAxisSize.min,
    //     children: [
    //       Icon(Icons.sell_outlined, size: 30, color: secondary),
    //       const SizedBox(height: 10),
    //       Text('No tags yet',
    //           style: MyntWebTextStyles.body(context,
    //               darkColor: MyntColors.textPrimaryDark,
    //               lightColor: MyntColors.textPrimary,
    //               fontWeight: MyntFonts.medium)),
    //       const SizedBox(height: 4),
    //       Text(
    //         'Create tags from the note editor\'s tag field —\n'
    //         'label your setups, mistakes and emotions.',
    //         textAlign: TextAlign.center,
    //         style: MyntWebTextStyles.caption(context, color: secondary),
    //       ),
    //     ],
    //   ),
    // );
    return NoDataFoundWeb(
      title: 'No tags yet',
      subtitle: "Create tags from the note editor's tag field — "
          'label your setups, mistakes and emotions.',
      secondaryEnabled: false,
      iconWidget: Icon(shadcn.LucideIcons.tag, size: 64, color: secondary),
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
    // final count = tag.noteCount ?? 0; // fed the commented-out usage text

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
              // Usage text dropped from the row — the delete confirmation
              // still spells out how many notes a tag is attached to.
              // Text(
              //   count == 0 ? 'unused' : '$count note${count == 1 ? '' : 's'}',
              //   style: MyntWebTextStyles.caption(context, color: secondary),
              // ),
              // const SizedBox(width: 6),
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

    // Position-group accordion treatment: while expanded, only the header
    // row carries a tint (same colours the group tiles use); the editor body
    // stays on the sheet background.
    // return Container(
    //   color: resolveThemeColor(context,
    //       dark: MyntColors.rowHoverDark, light: MyntColors.rowHover),
    //   child: Column( ... ),
    // );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: resolveThemeColor(context,
              dark: const Color(0xffB5C0CF).withValues(alpha: 0.15),
              light: const Color(0xffF1F3F8)),
          child: header,
        ),
        Padding(
            // Top gap separates the editor from the tinted header row.
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Same field recipe as the sheet's Title/Notes inputs: full
                // 40px box, limit via formatter, counter drawn below.
                // MyntTextField(
                //   controller: _editTagName,
                //   placeholder: 'Tag name',
                //   maxLength: 40,
                //   size: MyntTextFieldSize.medium,
                //   onSubmitted: (_) => _saveTagEdit(tag),
                //   textStyle: MyntWebTextStyles.body(context,
                //       darkColor: MyntColors.textPrimaryDark,
                //       lightColor: MyntColors.textPrimary),
                // ),
                MyntFormTextField(
                  controller: _editTagName,
                  placeholder: 'Tag name',
                  height: 40,
                  inputFormatters: [LengthLimitingTextInputFormatter(40)],
                  onSubmitted: (_) => _saveTagEdit(tag),
                ),
                _charCounter(context, _editTagName, 40),
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
                const SizedBox(height: 20),
                // Compact, right-aligned Delete | Save at intrinsic widths —
                // the footer's full-width pair overpowered an inline
                // accordion row. Delete keeps the watchlist dialog's red
                // fill. Cancel is dropped — collapsing the row via its
                // header is the cancel.
                // MyntTextButton(
                //   label: 'Cancel',
                //   onPressed: () => setState(() => _editingTagId = null),
                // ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 36,
                      child: MyntButton(
                        label: 'Delete',
                        type: MyntButtonType.primary,
                        backgroundColor: resolveThemeColor(context,
                            dark: MyntColors.errorDark,
                            light: MyntColors.tertiary),
                        onPressed:
                            _tagBusy ? null : () => _requestDeleteTag(tag),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 36,
                      child: MyntPrimaryButton(
                        label: 'Save',
                        isLoading: _tagBusy,
                        onPressed: _tagBusy ? null : () => _saveTagEdit(tag),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// One colour per asset class so the header badge identifies the segment
  /// at a glance. Presentation only; Equity keeps the app's primary blue and
  /// the rest use palette hexes.
  Color _segmentColor(BuildContext context) => switch (widget.group) {
        SegmentGroup.equity => resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary),
        SegmentGroup.fno => const Color(0xff6E56CF),
        SegmentGroup.commodity => const Color(0xffE5934D),
        SegmentGroup.currency => const Color(0xff12A594),
      };

  Widget _buildHeader(BuildContext context) {
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final segColor = _segmentColor(context);
    final d = DateTime.tryParse(widget.noteDate);
    return Padding(
      // padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          // The note icon badge anchors the header; the calendar tile sits at
          // the right end of the row, before the actions.
          Icon(Icons.edit_note_rounded, size: 36, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
    
              children: [
                Text(
                  _editing ? (_isNew ? 'Add note' : 'Edit note') : 'View note',
                  style: MyntWebTextStyles.title(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.semiBold),
                ),
                const SizedBox(width: 6),
                // Segment badge inline with the title keeps the header a
                // single line — count-badge recipe (10% tint, radius 5,
                // para semiBold).
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: segColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    widget.group.tabLabel.toUpperCase(),
                    style: MyntWebTextStyles.para(context,
                        fontWeight: MyntFonts.semiBold, color: segColor),
                  ),
                ),
                // The calendar tile is hidden when the date cannot be parsed —
                // fall back to plain text so the date is never lost.
                if (d == null) ...[
                  const SizedBox(width: 6),
                  Text(
                    _prettyDate,
                    style: MyntWebTextStyles.caption(context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary,
                        fontWeight: MyntFonts.medium),
                  ),
                ],
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

  /// Calendar tile — weekday strip on top, day number, month + year below.
  /// Null when the note date cannot be parsed; callers keep their old visual
  /// in that case so nothing renders blank.
  Widget? _calendarTile(BuildContext context) {
    final d = DateTime.tryParse(widget.noteDate);
    if (d == null) return null;
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return Container(
      // width: 56,
      width: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Solid sheet background so the tile stays readable on the banner's
        // red/green tint.
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            color: accent,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              DateFormat('EEE').format(d).toUpperCase(),
              textAlign: TextAlign.center,
              style: MyntWebTextStyles.caption(context, color: Colors.white)
                  .copyWith(height: 1.0, letterSpacing: 1.0),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            DateFormat('dd').format(d),
            // Day number leads the tile: head (18) instead of title (16).
            style: MyntWebTextStyles.head(context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                    fontWeight: MyntFonts.bold)
                .copyWith(height: 1.0),
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                DateFormat('MMM yyyy').format(d).toUpperCase(),
                maxLines: 1,
                style: MyntWebTextStyles.caption(context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary)
                    .copyWith(height: 1.0, letterSpacing: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// Shows the number being stored, so the note and the heat map visibly agree.
  Widget _buildSnapshotSummary(BuildContext context) {
    final snapshot = _effectiveSnapshot;
    if (snapshot == null) {
      // No P&L row for this day — the note saves, but analytics cannot see it.
      // The calendar tile still rides alongside so the date stays visible.
      final banner = _infoBanner(
        context,
        'No P&L was recorded for this day, so this note will not appear in '
        'your tag insights.',
        resolveThemeColor(context,
            dark: MyntColors.warningDark, light: MyntColors.warning),
      );
      final tile = _calendarTile(context);
      if (tile == null) return banner;
      return Row(
        children: [
          Expanded(child: banner),
          const SizedBox(width: 8),
          tile,
        ],
      );
    }

    final realised = snapshot.realised;
    final isProfit = realised >= 0;
    final color = isProfit
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);

    return Row(
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
                style: MyntWebTextStyles.hero(context,
                    color: color, fontWeight: MyntFonts.bold),
              ),
            ],
          ),
        ),
        
        
        _calendarTile(context) ??
            Container(
              width: 40,
              height: 40,
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
      // Same label recipe as the Create SIP dialog: body size, medium
      // weight, primary text colour.
      // style: MyntWebTextStyles.bodySmall(context,
      //     darkColor: MyntColors.textSecondaryDark,
      //     lightColor: MyntColors.textSecondary,
      //     fontWeight: MyntFonts.medium),
      style: MyntWebTextStyles.body(context,
          darkColor: MyntColors.textPrimaryDark,
          lightColor: MyntColors.textPrimary,
          fontWeight: MyntFonts.medium),
    );
  }

  /// Live "N/max" counter below a field. Replaces the TextField's built-in
  /// `maxLength` counter, which renders inside the field's fixed height and
  /// squeezes the input box.
  Widget _charCounter(
      BuildContext context, TextEditingController controller, int max) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => Text(
            '${value.text.length}/$max',
            style: MyntWebTextStyles.caption(context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
                fontWeight: MyntFonts.medium),
          ),
        ),
      ),
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
      // Half-and-half button row like the Holding Details sheet (Exit | Add);
      // on a new note the lone Save takes the full width. Both buttons stay
      // enabled always — validation happens on click (login pattern); only a
      // request in flight shows the loading state.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inline validation, red per app convention (client-side checks are
          // inline; toasts would render behind this sheet anyway). Tracks the
          // text live so it clears itself as soon as the note is saveable.
          AnimatedBuilder(
            animation: Listenable.merge([_title, _comment]),
            builder: (context, _) {
              if (_saveError == null || _canSave) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _saveError!,
                  style: MyntWebTextStyles.bodySmall(context,
                      darkColor: MyntColors.lossDark,
                      lightColor: MyntColors.loss,
                      fontWeight: MyntFonts.medium),
                ),
              );
            },
          ),
          Row(
            children: [
              if (!_isNew) ...[
                // Red filled Delete — the same button as the Delete Watchlist
                // dialog's action.
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: MyntButton(
                      label: 'Delete',
                      type: MyntButtonType.primary,
                      isFullWidth: true,
                      backgroundColor: resolveThemeColor(context,
                          dark: MyntColors.errorDark,
                          light: MyntColors.tertiary),
                      isLoading: _deleting,
                      onPressed: _requestDelete,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: MyntPrimaryButton(
                    label: _isNew ? 'Save note' : 'Save changes',
                    isLoading: _saving,
                    isFullWidth: true,
                    onPressed: _save,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasContent =>
      _title.text.trim().isNotEmpty || _comment.text.trim().isNotEmpty;
}

/// Dashed rounded-rect outline for the attachment Add tile. Flutter's
/// [Border] has no dashed style and the app carries no dashed-border package,
/// so the outline is painted: the rounded-rect path is walked and stroked in
/// 5px dashes with 4px gaps.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(8)));
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
