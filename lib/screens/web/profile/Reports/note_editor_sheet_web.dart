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

  /// The X. The editor is persistent, so this is the deliberate exit — if there
  /// are unsaved edits it asks before dropping them, otherwise it closes.
  void _handleClose() {
    if (_saving || _deleting) return;
    if (_dirty) {
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildEditor(context),
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
                  _isNew ? 'Add note' : 'Edit note',
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
