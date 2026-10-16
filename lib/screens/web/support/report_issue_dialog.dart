import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../locator/locator.dart';
import '../../../locator/preference.dart';
import '../../../models/support_ticket_model/support_ticket_area.dart';
import '../../../models/support_ticket_model/support_ticket.dart';
import '../../../provider/support_ticket_provider.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';

/// Opens the raise-a-ticket form.
///
/// [screen] is where the client was when they asked for help — it rides along
/// in the ticket's context block so the agent can see it without asking.
Future<void> showReportIssueDialog(
  BuildContext context, {
  required String screen,
}) {
  return showDialog<void>(
    context: context,
    // A half-typed description must not vanish on a stray click outside.
    barrierDismissible: false,
    builder: (_) => _ReportIssueDialog(screen: screen),
  );
}

class _ReportIssueDialog extends ConsumerStatefulWidget {
  const _ReportIssueDialog({required this.screen});

  final String screen;

  @override
  ConsumerState<_ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends ConsumerState<_ReportIssueDialog> {
  /// Where the client says it happened. Seeded from the route they raised it
  /// from, which is only a guess — the entry point lives on the dashboard, so
  /// that route is usually not where the problem was.
  SupportTicketArea? _area;

  @override
  void initState() {
    super.initState();
    _area = SupportTicketArea.fromRoute(widget.screen);
    // A dialog reopened after a previous success would otherwise show that
    // ticket's confirmation instead of an empty form.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportTicketProvider).reset();
    });
  }

  Future<void> _submit() async {
    final provider = ref.read(supportTicketProvider);
    final result = await provider.raise(
      // What the client said beats what the app captured: they were there.
      // Falls back to the raw route when they leave it unset.
      screen: _area?.apiValue ?? widget.screen,
      onError: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
      // The ticket exists; only a file did not attach. Reporting it as a
      // failure would make the client raise a second one.
      onAttachmentsFailed: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
    // Success repaints this same dialog as the confirmation; the provider
    // holds the ticket number.
    if (result != null && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(supportTicketProvider);
    final dark = isDarkMode(context);

    return Dialog(
      backgroundColor: dark ? MyntColors.cardDark : MyntColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: dark ? MyntColors.cardBorderDark : MyntColors.cardBorder,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: provider.lastResult == null
              ? _form(context, provider, dark)
              : _success(context, provider, dark),
        ),
      ),
    );
  }

  // --- Form ----------------------------------------------------------------

  Widget _form(
    BuildContext context,
    SupportTicketProvider provider,
    bool dark,
  ) {
    final clientId = locator<Preferences>().clientId ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Report an issue',
                style: MyntWebTextStyles.title(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close, size: 20),
              onPressed: provider.submitting
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Naming who this is filed as saves the agent asking, and shows the
        // client their code is already attached.
        Text(
          clientId.isEmpty
              ? 'Our team will reply by email.'
              : 'Reporting as $clientId · our team will reply by email.',
          style: MyntWebTextStyles.caption(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        _label(context, 'What is this about?'),

        _label(context, 'Where did this happen?'),
        const SizedBox(height: 6),
        DropdownButtonFormField<SupportTicketArea>(
          initialValue: _area,
          isExpanded: true,
          // Eleven options is past the point where chips scan well, so this
          // one is a menu while the five categories above stay chips.
          items: [
            for (final area in SupportTicketArea.values)
              DropdownMenuItem(value: area, child: Text(area.label)),
          ],
          onChanged: provider.submitting
              ? null
              : (value) => setState(() => _area = value),
          decoration: _fieldDecoration(
            context,
            dark: dark,
            hint: 'Pick the screen',
            hasError: false,
          ),
        ),
        const SizedBox(height: 16),

        _label(context, 'Subject'),
        const SizedBox(height: 6),
        TextField(
          controller: provider.subject,
          enabled: !provider.submitting,
          maxLength: SupportTicketProvider.kSubjectMaxLength,
          onChanged: provider.onSubjectChanged,
          decoration: _fieldDecoration(
            context,
            dark: dark,
            hint: 'e.g. Order page not loading',
            hasError: provider.fieldErrors.containsKey('subject'),
            counter: true,
          ),
        ),
        _error(context, provider.fieldErrors['subject']),
        const SizedBox(height: 8),

        _label(context, 'What went wrong?'),
        const SizedBox(height: 6),
        TextField(
          controller: provider.message,
          enabled: !provider.submitting,
          maxLines: 5,
          maxLength: SupportTicketProvider.kMessageMaxLength,
          onChanged: provider.onMessageChanged,
          decoration: _fieldDecoration(
            context,
            dark: dark,
            hint: 'What you were doing, and what happened instead.',
            hasError: provider.fieldErrors.containsKey('message'),
            counter: true,
          ),
        ),
        _error(context, provider.fieldErrors['message']),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: provider.submitting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              // Only an in-flight submit disables this. Validation never does —
              // a dead button explains nothing; a click that answers with an
              // inline error does.
              onPressed: provider.submitting ? null : _submit,
              child: provider.submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send'),
            ),
          ],
        ),
      ],
    );
  }

  // --- Success -------------------------------------------------------------

  Widget _success(
    BuildContext context,
    SupportTicketProvider provider,
    bool dark,
  ) {
    final number = provider.lastResult!.number;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: MyntColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ticket #$number raised',
                style: MyntWebTextStyles.title(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Our team will look into it and reply by email. Quote this number '
          'if you call us about it.',
          style: MyntWebTextStyles.body(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => provider.raiseAnother(),
              child: const Text('Report another'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }

  // --- Bits ----------------------------------------------------------------

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: MyntWebTextStyles.bodySmall(
          context,
          darkColor: MyntColors.textPrimaryDark,
          lightColor: MyntColors.textPrimary,
        ),
      );

  /// Inline, under the field it belongs to — never a banner at the top, which
  /// names a problem a scroll away from the control that has it.
  Widget _error(BuildContext context, String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: MyntWebTextStyles.caption(
          context,
          color: Colors.red.shade400,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required bool dark,
    required String hint,
    required bool hasError,
    bool counter = false,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: hasError
            ? Colors.red.shade400
            : (dark ? MyntColors.cardBorderDark : MyntColors.cardBorder),
      ),
    );
    return InputDecoration(
      hintText: hint,
      isDense: true,
      // The maxLength counter is the only length cue; a silently truncating
      // field reads as the app eating what was typed.
      counterText: counter ? null : '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: hasError ? Colors.red.shade400 : MyntColors.primary,
        ),
      ),
    );
  }
}

/// The category row. A segmented set rather than a dropdown: there are five,
/// they all fit, and seeing them at once is faster than opening a menu to find
/// out what the choices are.
/// The help-topic picker.
///
/// Retired: every client ticket is raised under General and support re-routes
/// it. Kept because re-exposing the choice is then a UI change only.
///
/// The set comes from `GET /topics` — osTicket's own public, enabled topics —
/// so it is never hard-coded: admins add and remove them with no release.
// ignore: unused_element
class _TopicPicker extends StatelessWidget {
  const _TopicPicker({
    required this.topics,
    required this.value,
    required this.error,
    required this.enabled,
    required this.onChanged,
    required this.dark,
  });

  final List<SupportTopic> topics;
  final SupportTopic? value;
  final String? error;
  final bool enabled;
  final ValueChanged<SupportTopic> onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final topic in topics)
          _Chip(
            label: topic.name,
            selected: topic.id == value?.id,
            enabled: enabled,
            hasError: error != null && value == null,
            dark: dark,
            onTap: () => onChanged(topic),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.hasError,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool hasError;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? MyntColors.primary
        : hasError
            ? Colors.red.shade400
            : (dark ? MyntColors.cardBorderDark : MyntColors.cardBorder);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? MyntColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: MyntWebTextStyles.bodySmall(
            context,
            color: selected
                ? MyntColors.primary
                : (dark
                    ? MyntColors.textSecondaryDark
                    : MyntColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
