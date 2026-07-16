import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../../api/core/api_export.dart';
import '../../../../locator/locator.dart';
import '../../../../models/journal_notes_model/journal_note.dart';
import '../../../../models/journal_notes_model/journal_notes_exception.dart';
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
Future<void> openNoteEditorSheet(
  BuildContext context, {
  required WidgetRef ref,
  required String noteDate,
  required SegmentGroup group,
  required JournalNote? existing,
  required NotePnlSnapshot? snapshot,
  required NotesRangeKey rangeKey,
}) async {
  if (_isSheetOpening) return;
  _isSheetOpening = true;

  await shadcn.openSheet(
    context: context,
    position: shadcn.OverlayPosition.end,
    barrierColor: Colors.transparent,
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
          ),
        ),
      );
    },
  );

  _isSheetOpening = false;
}

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

  const _NoteEditorContent({
    required this.noteDate,
    required this.group,
    required this.existing,
    required this.snapshot,
    required this.rangeKey,
  });

  @override
  ConsumerState<_NoteEditorContent> createState() => _NoteEditorContentState();
}

class _NoteEditorContentState extends ConsumerState<_NoteEditorContent> {
  late final TextEditingController _title;
  late final TextEditingController _comment;
  late final String _originalTitle;
  late final String _originalComment;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _originalTitle = widget.existing?.title ?? '';
    _originalComment = widget.existing?.comment ?? '';
    _title = TextEditingController(text: _originalTitle);
    _comment = TextEditingController(text: _originalComment);
  }

  @override
  void dispose() {
    _title.dispose();
    _comment.dispose();
    super.dispose();
  }

  bool get _isNew => widget.existing == null;

  /// Whether the current text differs from what the note was opened with. Read
  /// live from the controllers rather than tracked with a flag, so it stays
  /// correct even after the user edits back to the original.
  bool get _dirty =>
      _title.text != _originalTitle || _comment.text != _originalComment;

  /// Save is allowed when a new note has something in it, or an existing note
  /// has been changed. Recomputed on every keystroke via the footer's
  /// [AnimatedBuilder] — the enabled state must not go stale.
  bool get _canSave =>
      !_saving && (_isNew ? _hasContent : _dirty);

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
      await locator<ApiExporter>().saveNote(
        noteDate: widget.noteDate,
        group: widget.group,
        title: _title.text,
        comment: _comment.text,
        // Always resent. Omitting it would clear the stored snapshot.
        pnl: _effectiveSnapshot,
      );
      ref.invalidate(notesForRangeProvider(widget.rangeKey));
      ref.invalidate(hasAnyNotesProvider);
      if (!mounted) return;
      // openSheet is a shadcn drawer, not a route — Navigator.pop would not
      // close it and would leave the save spinner hung.
      shadcn.closeSheet(context);
      successMessage(context, _isNew ? 'Note saved' : 'Note updated');
    } on JournalNotesException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      error(context, e.message);
    }
  }

  Future<void> _delete() async {
    final note = widget.existing;
    if (note == null || _deleting) return;

    final confirmed = await _confirmDelete();
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
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

  /// Deletion is soft server-side but there is no undo exposed, so confirm.
  Future<bool?> _confirmDelete() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: resolveThemeColor(dialogContext,
                  dark: MyntColors.cardDark, light: MyntColors.card),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delete this note?',
                    style: MyntWebTextStyles.title(dialogContext,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.semiBold)),
                const SizedBox(height: 8),
                Text(
                  'Your note for ${widget.noteDate} will be removed, along with '
                  'its tags and attachments. This cannot be undone.',
                  style: MyntWebTextStyles.bodySmall(dialogContext,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MyntTextButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                    const SizedBox(width: 8),
                    MyntPrimaryButton(
                      label: 'Delete',
                      backgroundColor: resolveThemeColor(dialogContext,
                          dark: MyntColors.lossDark, light: MyntColors.loss),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            child: Column(
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
                    placeholder:
                        'Why did you take these trades? What would you do '
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
              ],
            ),
          ),
        ),
        _buildFooter(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNew ? 'Add note' : 'Edit note',
                  style: MyntWebTextStyles.title(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.semiBold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.noteDate} · ${widget.group.tabLabel}',
                  style: MyntWebTextStyles.caption(context,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary),
                ),
              ],
            ),
          ),
          MyntCloseButton(onPressed: () => shadcn.closeSheet(context)),
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
    final color = realised >= 0
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.inputBgDark, light: MyntColors.inputBg),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: resolveThemeColor(context,
              dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder),
        ),
      ),
      child: Row(
        children: [
          Text(
            "This day's P&L",
            style: MyntWebTextStyles.bodySmall(context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary),
          ),
          const Spacer(),
          Text(
            _formatAmount(realised),
            style: MyntWebTextStyles.body(context,
                color: color, fontWeight: MyntFonts.semiBold),
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
              onPressed: _deleting ? null : _delete,
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
