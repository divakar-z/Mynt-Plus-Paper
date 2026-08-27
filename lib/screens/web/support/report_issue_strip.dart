import 'package:flutter/material.dart';

import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';
import 'report_issue_dialog.dart';

/// The dashboard's way in to raising a support ticket.
///
/// Deliberately *not* built like the Tools cards above it. Those are feature
/// promos — accent colours, badges, a sales line each — because they exist to
/// be discovered. Support is the opposite: it needs to be findable at the
/// moment something breaks, and a loud "Report a problem" panel on a screen
/// showing someone's money reads as an admission that things break often.
///
/// So: one quiet line, last on the page, after the client has scrolled past
/// everything they actually came for.
class ReportIssueStrip extends StatelessWidget {
  const ReportIssueStrip({super.key, this.screen = '/dashboard'});

  /// Where the client was when they asked for help. Travels with the ticket so
  /// the agent can see it without asking.
  ///
  /// Defaulted rather than required because this is the dashboard's strip; a
  /// caller mounting it elsewhere should pass its own route.
  final String screen;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: dark ? MyntColors.cardDark : MyntColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? MyntColors.cardBorderDark : MyntColors.cardBorder,
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.support_agent_outlined,
                size: 20,
                color: dark
                    ? MyntColors.textSecondaryDark
                    : MyntColors.textSecondary,
              ),
              const SizedBox(width: 12),
              // Constrained so a narrow viewport wraps the copy instead of
              // overflowing the row.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Something not working?',
                      style: MyntWebTextStyles.bodyMedium(
                        context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tell us what happened and we will raise a ticket for '
                      'you — no need to call.',
                      style: MyntWebTextStyles.caption(
                        context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: () => showReportIssueDialog(context, screen: screen),
            icon: const Icon(Icons.edit_outlined, size: 16),
            // Says what happens, rather than "Help" — which reads as FAQs and
            // leaves the client hunting for the part that reaches a person.
            label: const Text('Report an issue'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              side: BorderSide(
                color: dark ? MyntColors.cardBorderDark : MyntColors.cardBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
