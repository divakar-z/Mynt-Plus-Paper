import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

enum EmptyStateKind { empty, search, error, insufficientData }

class EmptyState extends StatelessWidget {
  final EmptyStateKind kind;
  final String title;
  final String? message;
  /// Optional action button callback. The default label is `Retry` (intended
  /// for error states); override with [actionLabel] for empty-state CTAs.
  final VoidCallback? onRetry;
  final String? actionLabel;

  const EmptyState({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.onRetry,
    this.actionLabel,
  });

  IconData get _icon {
    switch (kind) {
      case EmptyStateKind.empty: return shadcn.LucideIcons.inbox;
      case EmptyStateKind.search: return shadcn.LucideIcons.search;
      case EmptyStateKind.error: return shadcn.LucideIcons.circleAlert;
      case EmptyStateKind.insufficientData: return shadcn.LucideIcons.database;
    }
  }

  Color _iconColor(BuildContext context) {
    switch (kind) {
      case EmptyStateKind.error: return MyntColors.error;
      default:
        return resolveThemeColor(context,
            dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 48, color: _iconColor(context)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium)),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: MyntWebTextStyles.caption(context)),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: onRetry,
                  child: Text(actionLabel ?? 'Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
