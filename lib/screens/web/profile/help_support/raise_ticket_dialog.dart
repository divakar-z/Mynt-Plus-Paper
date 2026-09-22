import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../../locator/locator.dart';
import '../../../../locator/preference.dart';
import '../../../../models/support_ticket_model/support_ticket.dart';
import '../../../../models/support_ticket_model/support_ticket_validation.dart';
import '../../../../provider/support_ticket_provider.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../sharedWidget/common_buttons_web.dart';
import '../../../../sharedWidget/common_text_fields_web.dart';
import '../../../../sharedWidget/snack_bar.dart';
import 'support_download.dart';

/// Opens the raise-a-ticket form.
///
/// [screen] is where the client was when they asked to report something. It
/// travels in the ticket's context block so the agent can see it without
/// asking, so pass the surface the client was actually looking at rather than
/// a constant.
///
/// The form state lives in [supportTicketProvider] rather than in this dialog,
/// because a failed submit must not cost someone the description they just
/// typed. Closing is different: that is a deliberate cancel, so the form is
/// cleared on the way out and the next open starts empty.
Future<void> showRaiseTicketDialog(
  BuildContext context, {
  required WidgetRef ref,
  required String screen,
  VoidCallback? onViewTickets,
}) {
  final provider = ref.read(supportTicketProvider);

  // The category picker has nothing to draw until the form arrives, and this
  // is also the call that establishes the support session — so a failure here
  // is what tells the client support is unreachable, rather than the form
  // silently offering no choices.
  //
  // `GET /topics` is not called at all: the server files every ticket under
  // General, so there is no topic to choose and no failure to inherit from
  // fetching a list nothing offers.
  //
  // Not awaited: the dialog opens immediately and fills in when the form
  // arrives, which reads better than a blank pause after the button click.
  provider.loadFormFields(
    onError: (message) {
      if (context.mounted) error(context, message);
    },
  );

  return showDialog<void>(
    context: context,
    // Not dismissible. With the form clearing on close, a stray click beside
    // the dialog would silently bin a half-written description — closing has
    // to be something the client meant to do.
    barrierDismissible: false,
    builder: (dialogContext) =>
        _RaiseTicketDialog(screen: screen, onViewTickets: onViewTickets),
  ).then((_) {
    // Covers every exit: the close button, Done on the success state, and a
    // system back. Clears the text, the attachments, the validation errors and
    // `lastResult` — so reopening starts empty rather than showing the files
    // and red text from the attempt that was abandoned.
    provider.reset();
  });
}

class _RaiseTicketDialog extends ConsumerWidget {
  const _RaiseTicketDialog({required this.screen, this.onViewTickets});

  final String screen;

  /// Where "View my tickets" should take them, or null when they are already
  /// looking at the list.
  ///
  /// Null is the Help and Support screen itself: the table is behind this
  /// dialog and has already refreshed, so offering to navigate there would
  /// send someone to the page they are standing on. Raised from the profile
  /// menu the client could be anywhere, and then the trip is worth offering.
  final VoidCallback? onViewTickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(supportTicketProvider);
    final raised = provider.lastResult;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Center(
        child: shadcn.Card(
          borderRadius: BorderRadius.circular(8),
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(context, raised != null),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: raised == null
                      ? _form(context, ref, provider)
                      : _success(context, ref, provider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool isSuccess) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: shadcn.Theme.of(context).colorScheme.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isSuccess ? 'Ticket raised' : 'Raise a Ticket',
            style: MyntWebTextStyles.title(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
          ),
          MyntCloseButton(onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  // --- Form ----------------------------------------------------------------

  Widget _form(
      BuildContext context, WidgetRef ref, SupportTicketProvider provider) {
    // Built once: the list is also what decides whether a gap belongs above
    // Subject, and building it twice would run the whole loop on every
    // keystroke for an answer already in hand.
    final formFields = _topicFields(context, provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // No topic picker. Every client ticket is raised under General and
        // support re-routes it — a client whose order just failed should not
        // have to decide between "MII-s" and "Partner/AP". Same as mobile.
        //
        // What the client does choose is the Category, and it comes first: it
        // is the one filing decision they make, and a picker placed after the
        // description reads as an afterthought to text already written.
        // [SupportTicketProvider.collectableFields] puts it at the head of the
        // list whatever order the admin panel returns.
        ...formFields,
        // Only when something was drawn above. An install whose form defines
        // no visible fields would otherwise open on 16px of empty space.
        if (formFields.isNotEmpty) const SizedBox(height: 16),
        _label(context, 'Subject'),
        const SizedBox(height: 10),
        MyntFormTextField(
          controller: provider.subject, 
          placeholder: 'Buy order for RELIANCE rejected',
          height: 40,
          // Capped with a formatter rather than `maxLength`, which would draw a
          // character counter below the input. MyntTextField clamps its height
          // unconditionally, so that counter has nowhere to go and pushes out
          // past the border.
          inputFormatters: [
            LengthLimitingTextInputFormatter(
                SupportTicketProvider.kSubjectMaxLength),
          ],
          onChanged: provider.onSubjectChanged,
        ),
        _error(context, provider.fieldErrors['subject']),
        const SizedBox(height: 16),
        _label(context, 'Describe the issue'),
        const SizedBox(height: 10),
        MyntFormTextField(
          controller: provider.message,
          placeholder:
              'Example: Buy order for 10 RELIANCE at 10:15 AM was rejected '
              'with "RMS: margin shortfall".',
          maxLines: 5,
          // Capped with a formatter, not `maxLength`. The counter `maxLength`
          // draws sits below the input but *inside* the field's fixed-height
          // SizedBox, so the height had to be padded out to make room for it —
          // and that slack is what pushed the validation message down into the
          // gap below, far enough from the field to read as unrelated to it.
          inputFormatters: [
            LengthLimitingTextInputFormatter(
                SupportTicketProvider.kMessageMaxLength),
          ],
          // Explicit, because MyntTextField always wraps the field in a
          // SizedBox and defaults it to 40 — five lines would otherwise render
          // inside a single-line box and spill out of the border. Five lines of
          // body text plus the 10px content padding top and bottom, with
          // nothing spare now the counter is gone.
          height: 122,
          onChanged: provider.onMessageChanged,
        ),
        _error(context, provider.fieldErrors['message']),
        _descriptionProgress(context, provider),
        const SizedBox(height: 16),
        // Once files are listed the picker moves up beside the label: the list
        // owns the space below, and a control stranded under a long list is
        // easy to miss.
        Row(
          children: [
            _label(context, 'Attachment (optional)'),
            if (provider.attachments.isNotEmpty && provider.canAddAttachment) ...[
              const Spacer(),
              MyntOutlinedButton(
                label: 'Add another',
                icon: Icons.attach_file,
                size: MyntButtonSize.small,
                onPressed: provider.submitting
                    ? null
                    : () => _pickAttachments(context, provider),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _attachmentField(context, provider),
        const SizedBox(height: 8),
        // Names the account out loud. On an app where one person may handle a
        // family's several client codes, "attached automatically" is not the
        // same as knowing which one got attached.
        Text(
          'Raising this for ${locator<Preferences>().clientId ?? ''} — your '
          'name and contact details are attached automatically.',
          style: MyntWebTextStyles.caption(
            context,
            fontWeight: MyntFonts.regular,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        MyntPrimaryButton(
          label: 'Create Ticket',
          isFullWidth: true,
          // Loading is the only thing that disables this. Validation never
          // does: the click always fires and answers with an inline error,
          // matching the login screen.
          isLoading: provider.submitting,
          onPressed: () => _submit(context, ref, provider),
        ),
      ],
    );
  }

  /// A dropdown in the app's form style.
  ///
  /// Chips were fine for five short labels but do not survive the real data:
  /// MII-s offers twelve Products, which wraps to four rows and pushes the
  /// rest of the form off screen. A dropdown costs one click and stays one
  /// line whatever the list length.
  // Retired: the Material dropdown these two built.
  //
  // Its menu is a full-width overlay that covers the dialog it was opened
  // from, and it marks the current option by tinting the whole row rather
  // than colouring the text. Replaced by [_choiceField], which is the
  // picker Create SIP uses — a popover anchored under the field and sized
  // to it.
  //
  // Kept commented rather than deleted: nothing else on this form needs a
  // select today, and the next one that does should read what was wrong
  // with this before reaching for it again.
  //
  //   /// A select that reads as one of this form's fields.
  //   ///
  //   /// Every value here is lifted from [MyntFormTextField], which is what sits
  //   /// directly under it — a stock [DropdownButtonFormField] is transparent
  //   /// where those are filled, pads a further 2px, and turns its border the
  //   /// primary colour on focus, none of which the text fields do. Beside them it
  //   /// read as a control borrowed from somewhere else.
  //   ///
  //   /// Matched rather than replaced with a shadcn select: the neighbours are
  //   /// Mynt fields, and the thing a picker has to agree with is the field above
  //   /// and below it, not the dialog's frame.
  //   Widget _dropdown<T>(
  //     BuildContext context, {
  //     required T? value,
  //     required List<DropdownMenuItem<T>> items,
  //     required ValueChanged<T?> onChanged,
  //     required String hint,
  //     bool enabled = true,
  //   }) {
  //     // MyntTextField's own fill and border, read off the same theme resolution
  //     // so a change there does not leave this one behind.
  //     final fillColor = resolveThemeColor(
  //       context,
  //       dark: const Color(0xffB5C0CF).withValues(alpha: .15),
  //       light: const Color(0xffF1F3F8),
  //     );
  //     final borderColor = resolveThemeColor(
  //       context,
  //       dark: MyntColors.textSecondaryDark,
  //       light: MyntColors.primary,
  //     );
  //
  //     // One border for every state. The text fields do not brighten on focus,
  //     // and a picker that does is the single loudest thing on the form.
  //     OutlineInputBorder border() => OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(5),
  //           borderSide: BorderSide(color: borderColor, width: 1),
  //         );
  //
  //     return SizedBox(
  //       // The 40 the neighbouring fields are given, so the three line up.
  //       height: 40,
  //       child: DropdownButtonFormField<T>(
  //         // `initialValue` only seeds the first build; the widget is rebuilt with
  //         // a new value each time the provider changes, which is what keeps it in
  //         // step with a form cleared by reset().
  //         initialValue: value,
  //         isExpanded: true,
  //         isDense: true,
  //         items: items,
  //         onChanged: enabled ? onChanged : null,
  //         style: MyntWebTextStyles.bodyMedium(context),
  //         // The menu itself, which otherwise opens stock white over a dark form.
  //         dropdownColor: resolveThemeColor(
  //           context,
  //           dark: MyntColors.backgroundColorDark,
  //           light: MyntColors.backgroundColor,
  //         ),
  //         borderRadius: BorderRadius.circular(5),
  //         icon: Icon(
  //           Icons.keyboard_arrow_down_rounded,
  //           size: 18,
  //           color: resolveThemeColor(
  //             context,
  //             dark: MyntColors.textSecondaryDark,
  //             light: MyntColors.textSecondary,
  //           ),
  //         ),
  //         hint: Text(hint, style: MyntWebTextStyles.placeholder(context)),
  //         decoration: InputDecoration(
  //           isDense: true,
  //           filled: true,
  //           fillColor: fillColor,
  //           // The text fields' padding exactly — 12 across, 10 down.
  //           contentPadding:
  //               const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  //           border: border(),
  //           enabledBorder: border(),
  //           focusedBorder: border(),
  //           disabledBorder: border(),
  //         ),
  //       ),
  //     );
  //   }
  //
  //   DropdownMenuItem<T> _item<T>(BuildContext context, T value, String label) =>
  //       DropdownMenuItem<T>(
  //         value: value,
  //         child: Text(
  //           label,
  //           overflow: TextOverflow.ellipsis,
  //           style: MyntWebTextStyles.body(
  //             context,
  //             fontWeight: MyntFonts.regular,
  //             darkColor: MyntColors.textPrimaryDark,
  //             lightColor: MyntColors.textPrimary,
  //           ),
  //         ),
  //       );

  /// The attached files, and the control that adds more.
  ///
  /// Files are named rather than previewed: a thumbnail tells the client
  /// nothing they do not already know, and a PDF has none anyway.
  Widget _attachmentField(
      BuildContext context, SupportTicketProvider provider) {
    final files = provider.attachments;

    if (files.isEmpty) {
      return _AddFilesDropZone(
        enabled: !provider.submitting,
        onTap: () => _pickAttachments(context, provider),
        onDropped: (dropped) {
          final failure = provider.addDroppedAttachments(dropped);
          if (failure != null && context.mounted) {
            error(context, failure);
          }
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The list scrolls inside its own box rather than growing the form.
        // Twenty files is ten rows, which pushed the dialog past the viewport
        // and took Send off screen with it — capped here, the rest of the form
        // stays put however many are attached.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 196),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
        // Two per row. One per row wasted most of the dialog's width on short
        // names and turned six files into a column taller than the form above.
        for (var i = 0; i < files.length; i += 2) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _attachmentRow(context, provider, i),
              ),
              const SizedBox(width: 8),
              // An odd last file keeps its half rather than stretching across
              // both, so the column edge stays straight.
              Expanded(
                child: i + 1 < files.length
                    ? _attachmentRow(context, provider, i + 1)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
              ],
            ),
          ),
        ),
        Text(
          // The per-file cap is stated here rather than only in the rejection
          // message — a limit a client only learns by breaking it is a limit
          // they meet as a failure.
          '${files.length} of ${SupportTicketProvider.kAttachmentMaxCount} '
          'files · ${_fileSize(provider.attachmentsTotalBytes)} · max '
          '${SupportTicketProvider.formatMb(SupportTicketProvider.kAttachmentMaxBytes)} each',
          style: MyntWebTextStyles.caption(
            context,
            fontWeight: MyntFonts.regular,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// One attached file: icon, name, size, and a way to take it off again.
  Widget _attachmentRow(
      BuildContext context, SupportTicketProvider provider, int index) {
    final file = provider.attachments[index];
    final border = resolveThemeColor(context,
        dark: MyntColors.borderMutedDark, light: MyntColors.borderMuted);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 18,
            color: resolveThemeColor(context,
                dark: MyntColors.iconDark, light: MyntColors.icon),
          ),
          const SizedBox(width: 8),
          Expanded(
            // Half-width cells clip most real filenames, so the full name is
            // always one hover away rather than only when it happens to fit.
            child: Tooltip(
              message: file.name,
              waitDuration: const Duration(milliseconds: 400),
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.medium,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fileSize(file.size),
            style: MyntWebTextStyles.caption(
              context,
              fontWeight: MyntFonts.regular,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          MyntCloseButton(
            onPressed: provider.submitting
                ? null
                : () => provider.removeAttachmentAt(index),
          ),
        ],
      ),
    );
  }

  /// Opens the picker and surfaces anything it refused.
  Future<void> _pickAttachments(
      BuildContext context, SupportTicketProvider provider) async {
    final failure = await provider.pickAttachments();
    if (failure != null && context.mounted) error(context, failure);
  }

  /// `842 KB` / `1.4 MB` — enough for someone to see why a file was rejected.
  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// The topic picker.
  ///
  /// Chips rather than a dropdown so every option stays visible, but the set is
  /// whatever `GET /topics` returns — admins add and remove help topics from
  /// the admin panel with no release, so nothing here is hard-coded.
  ///
  /// Picking one loads that topic's own fields, which is why it is awaited
  /// rather than fire-and-forget.
  /// The chosen topic's own fields, rendered from whatever the API describes.
  ///
  /// Only editable fields are offered: `subject` and `priority` commonly arrive
  /// visible-but-locked, and sending a locked field back is a `422`.
  ///
  /// An unrecognised type falls back to a text input rather than being skipped.
  /// osTicket's type strings are open-ended (`list-<id>` for each custom list),
  /// so a type we have never seen is expected, not exceptional — and dropping
  /// the field would silently make a required answer unfillable.
  List<Widget> _topicFields(
      BuildContext context, SupportTicketProvider provider) {
    // A refetch clears the old fields before the new ones arrive. Without
    // something here the section collapses to nothing and pops back a moment
    // later, which reads as the form glitching rather than working.
    if (provider.loadingFields) {
      return [
        const SizedBox(height: 16),
        Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading the support form…',
              style: MyntWebTextStyles.caption(
                context,
                fontWeight: MyntFonts.regular,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
              ),
            ),
          ],
        ),
      ];
    }

    if (provider.formError != null) {
      return [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                provider.formError!,
                style: MyntWebTextStyles.caption(
                  context,
                  fontWeight: MyntFonts.regular,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Worth its own tap: with no form there is no category to pick,
            // and the category is required — so a form that failed to load
            // means no ticket at all, not merely a missing optional answer.
            MyntTextButton(
              label: 'Retry',
              onPressed: () => provider.loadFormFields(
                force: true,
                onError: (m) {
                  if (context.mounted) error(context, m);
                },
              ),
            ),
          ],
        ),
      ];
    }

    final fields = provider.collectableFields;
    if (fields.isEmpty) return const [];

    return [
      for (final field in fields) ...[
        const SizedBox(height: 16),
        // From the provider so the label on screen and the label inside the
        // validation message can never disagree — the category is shown as
        // "Category", not the helpdesk's own "Sub Issue Categories".
        _label(context, provider.fieldLabel(field)),
        const SizedBox(height: 10),
        if (field.isChoice)
          _choiceField(context, provider, field)
        else
          MyntFormTextField(
            // From the provider, not built here: a controller created during
            // build is replaced on every rebuild, and the form rebuilds on
            // every keystroke — so the caret jumps to the start and the text
            // comes out reversed.
            controller: provider.fieldController(field.name),
            placeholder: '',
            height: field.type == 'memo' ? 90 : 40,
            maxLines: field.type == 'memo' ? 3 : 1,
            onChanged: (value) => provider.setCustomField(field.name, value),
          ),
        // The server's own rejection outranks the local "you did not pick
        // one": it is about the choice that was actually sent, and by now the
        // list on screen has been refetched.
        _error(
          context,
          provider.fieldErrors[field.name] ??
              (field.name.trim().toLowerCase() == subIssueFieldName
                  ? provider.subIssueError
                  : null),
        ),
      ],
    ];
  }

  /// A choice-backed field.
  ///
  /// The item shows the label but carries the **key** — the API hands back
  /// labels on read and expects keys on write, and sending a label is a `422`.
  /// A choice field — the Category, and anything else the helpdesk's form
  /// defines with options.
  ///
  /// Built the way Create SIP builds its Frequency picker: a 40px box that
  /// matches the text fields around it, opening a popover anchored under
  /// itself and sized to its own width. A [DropdownButtonFormField] was tried
  /// first and was wrong twice over — its menu is a full-width overlay that
  /// covers the dialog it was opened from, and it marks the current option by
  /// greying its row rather than colouring its text.
  Widget _choiceField(BuildContext context, SupportTicketProvider provider,
      SupportTicketField field) {
    final selectedKey = provider.customFieldAnswers[field.name];
    // Only a label the current form still offers. A key that went stale while
    // the dialog was open has to read as "nothing picked", not as blank text
    // beside a chevron.
    final selectedLabel = selectedKey == null ? null : field.choices?[selectedKey];
    final hasValue = selectedLabel != null && selectedLabel.isNotEmpty;
    final enabled = !provider.submitting;

    return Builder(
      builder: (btnContext) => GestureDetector(
        onTap: enabled ? () => _showChoicePopup(btnContext, provider, field) : null,
        child: Container(
          // The height, fill, radius and border the neighbouring Mynt text
          // fields use, so the three controls line up down the form.
          height: 40,
          decoration: BoxDecoration(
            color: resolveThemeColor(
              context,
              dark: MyntColors.transparent,
              light: const Color(0xffF1F3F8),
            ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.primary,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  hasValue
                      ? selectedLabel
                      : 'Select ${provider.fieldLabel(field).toLowerCase()}',
                  overflow: TextOverflow.ellipsis,
                  style: hasValue
                      ? MyntWebTextStyles.body(
                          context,
                          fontWeight: MyntFonts.medium,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                        )
                      : MyntWebTextStyles.placeholder(context),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The options, in a popover under the field and no wider than it.
  ///
  /// Scrolls past a handful of rows. Category carries a dozen on the live
  /// install and a column that long runs off the bottom of the dialog, taking
  /// the last options with it.
  void _showChoicePopup(
    BuildContext btnContext,
    SupportTicketProvider provider,
    SupportTicketField field,
  ) {
    final btnWidth = (btnContext.findRenderObject() as RenderBox).size.width;
    final selectedKey = provider.customFieldAnswers[field.name];

    shadcn.showPopover(
      context: btnContext,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 4),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(btnContext).borderRadiusLg,
      ),
      builder: (popoverContext) => Container(
        decoration: BoxDecoration(
          borderRadius: shadcn.Theme.of(popoverContext).borderRadiusLg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: shadcn.ModalContainer(
          padding: const EdgeInsets.all(4),
          child: SizedBox(
            width: btnWidth - 8,
            child: ConstrainedBox(
              // About seven rows. Enough that a short list never scrolls, low
              // enough that a long one cannot outgrow the dialog behind it.
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final choice in field.choices!.entries)
                      _choiceRow(
                        btnContext,
                        label: choice.value,
                        selected: choice.key == selectedKey,
                        onTap: () {
                          shadcn.closeOverlay(popoverContext);
                          provider.setCustomField(field.name, choice.key);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One option. The current one is named in the primary colour rather than
  /// given a tinted row — the same way Create SIP marks its frequency.
  Widget _choiceRow(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: resolveThemeColor(
          context,
          dark: MyntColors.rippleDark,
          light: MyntColors.rippleLight,
        ),
        highlightColor: resolveThemeColor(
          context,
          dark: MyntColors.highlightDark,
          light: MyntColors.highlightLight,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            style: MyntWebTextStyles.body(
              context,
              fontWeight: selected ? MyntFonts.semiBold : MyntFonts.medium,
              color: selected
                  ? resolveThemeColor(context,
                      dark: MyntColors.primaryDark, light: MyntColors.primary)
                  : resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref,
      SupportTicketProvider provider) async {
    await provider.raise(
      screen: screen,
      // Backend wording goes to a toast and nowhere else. A field it names is
      // shown inline instead — never both, since the same message in two places
      // reads as two separate problems.
      onError: (message) {
        if (context.mounted) error(context, message);
      },
      // The ticket exists; only a file did not attach. A warning, never an
      // error — calling it a failure makes the client raise a second ticket.
      onAttachmentsFailed: (message) {
        if (context.mounted) warningMessage(context, message);
      },
    );
  }

  // --- Success -------------------------------------------------------------

  Widget _success(
      BuildContext context, WidgetRef ref, SupportTicketProvider provider) {
    final result = provider.lastResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(
          Icons.check_circle_outline,
          size: 44,
          color: resolveThemeColor(context,
              dark: MyntColors.successDark, light: MyntColors.success),
        ),
        const SizedBox(height: 12),
        Text(
          'Ticket #${result.number} raised',
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.title(
            context,
            fontWeight: MyntFonts.semiBold,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "We'll reply by email. Quote this number if you call us about it. "
          'You can track this ticket and your past ones in Help and Support.',
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.body(
            context,
            fontWeight: MyntFonts.regular,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        // One button, never a dead end. It closes either way; when the client
        // came from somewhere other than the tickets list it also takes them
        // there, where the ticket they just raised is at the top.
        MyntPrimaryButton(
          label: onViewTickets == null ? 'Done' : 'View my tickets',
          isFullWidth: true,
          onPressed: () {
            Navigator.of(context).pop();
            onViewTickets?.call();
          },
        ),
      ],
    );
  }

  // --- Shared bits ---------------------------------------------------------

  /// The live line under the description: how far short of the minimum it
  /// still is on the left, and the character count on the right.
  ///
  /// The count runs up to the cap, the hint counts down to the floor — a ticket
  /// has never been stalled by being too long, so the number worth nudging on
  /// is the one the client has not reached yet.
  ///
  /// Listens to the controller directly rather than through the provider, so a
  /// keystroke repaints this line alone instead of the whole dialog.
  Widget _descriptionProgress(
      BuildContext context, SupportTicketProvider provider) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: provider.message,
      builder: (context, value, _) {
        final progress = ticketDescriptionProgress(value.text);
        // Nothing to say on an empty field: the placeholder is still showing
        // and "40 more characters" under it reads as a complaint about a box
        // nobody has touched yet.
        if (progress == null && value.text.isEmpty) {
          return const SizedBox.shrink();
        }
        final style = MyntWebTextStyles.caption(
          context,
          fontWeight: MyntFonts.regular,
          darkColor: MyntColors.textSecondaryDark,
          lightColor: MyntColors.textSecondary,
        );
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  progress == null ? '' : '$progress to go',
                  style: style,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${value.text.characters.length}/'
                '${SupportTicketProvider.kMessageMaxLength}',
                style: style,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: MyntWebTextStyles.body(
        context,
        fontWeight: MyntFonts.semiBold,
        darkColor: MyntColors.textPrimaryDark,
        lightColor: MyntColors.textPrimary,
      ),
    );
  }

  /// Inline validation message. Nothing is rendered when there is no error, so
  /// the form does not reserve blank space under every field.
  Widget _error(BuildContext context, String? message) {
    if (message == null || message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        style: MyntWebTextStyles.caption(
          context,
          fontWeight: MyntFonts.medium,
          color: resolveThemeColor(context,
              dark: MyntColors.errorDark, light: MyntColors.error),
        ),
      ),
    );
  }
}

/// The empty-state attachment control: a dashed drop target that also opens
/// the file picker when clicked.
///
/// Stateful because it holds a live subscription to the browser's drag events.
/// Those listeners are hung off `document`, so they must come down when this
/// goes away — the widget is only ever on screen inside the modal dialog, and
/// a leaked listener would keep firing into a disposed provider after the
/// dialog closed.
///
/// The whole box is the target rather than a button inside it: a client
/// aiming for a dashed rectangle expects the rectangle to take the click.
class _AddFilesDropZone extends StatefulWidget {
  const _AddFilesDropZone({
    required this.enabled,
    required this.onTap,
    required this.onDropped,
  });

  final bool enabled;
  final VoidCallback onTap;
  final void Function(List<PlatformFile> files) onDropped;

  @override
  State<_AddFilesDropZone> createState() => _AddFilesDropZoneState();
}

class _AddFilesDropZoneState extends State<_AddFilesDropZone> {
  void Function()? _stopListening;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _stopListening = listenForFileDrops(
      (dropped) {
        if (!mounted || !widget.enabled) return;
        widget.onDropped([
          for (final file in dropped)
            PlatformFile(name: file.name, size: file.size, bytes: file.bytes),
        ]);
      },
      onHoverChanged: (active) {
        if (!mounted || _hovering == active) return;
        setState(() => _hovering = active);
      },
    );
  }

  @override
  void dispose() {
    _stopListening?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final border = resolveThemeColor(context,
        dark: MyntColors.borderMutedDark, light: MyntColors.divider);
    // Dragging over it borrows the accent so there is some sign the browser
    // will actually take the file — without it the cursor is the only feedback
    // and it reads as a dead area.
    final active = _hovering && widget.enabled;

    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          behavior: HitTestBehavior.opaque,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: active ? primary : border,
              radius: 6,
            ),
            // Full width, and tall enough for the icon row and the hint under
            // it. No fill — the dashes are the whole affordance.
            child: SizedBox(
              width: double.infinity,
              height: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.attach_file, size: 15, color: primary),
                      const SizedBox(width: 6),
                      Text(
                        'Add files',
                        style: MyntWebTextStyles.body(
                          context,
                          fontWeight: MyntFonts.medium,
                          darkColor: MyntColors.primaryDark,
                          lightColor: MyntColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'or drag and drop',
                    style: MyntWebTextStyles.caption(
                      context,
                      fontWeight: MyntFonts.regular,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws a dashed rounded rectangle.
///
/// Flutter has no dashed [Border], and `BoxDecoration` cannot be coaxed into
/// one — the outline has to be walked and stroked in segments by hand.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  /// Dash and gap lengths, in logical pixels.
  static const double dash = 5;
  static const double gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Inset by half the stroke, or the outer half of the line falls outside
    // the box and gets clipped to a hairline.
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
          Radius.circular(radius),
        ),
      );

    for (final metric in outline.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = (start + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
