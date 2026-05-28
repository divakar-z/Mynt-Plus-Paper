import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Shared placeholder used by every InstaOptions sub-screen until its real
/// implementation lands in Phases 2–9.
class InstaPlaceholderScreen extends StatelessWidget {
  final String title;
  final String phaseLabel;
  final IconData icon;

  const InstaPlaceholderScreen({
    super.key,
    required this.title,
    required this.phaseLabel,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    return Container(
      color: tokens.bgPrimary,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: tokens.bgSecondary,
            border: Border.all(color: tokens.border, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: tokens.textMuted),
              const SizedBox(height: 16),
              Text(
                title,
                style: MyntWebTextStyles.head(context, color: tokens.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Coming in $phaseLabel',
                style: MyntWebTextStyles.body(
                  context,
                  color: tokens.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
