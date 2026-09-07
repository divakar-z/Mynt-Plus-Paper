import 'package:flutter/material.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';

/// Empty / no-results / error state for the Scanner feature.
///
/// Renders the app-standard [NoDataFoundWeb] (the same widget Positions /
/// Holdings use) so every scanner no-data screen matches the rest of the app.
/// [kind] is kept for call-site compatibility but no longer drives a bespoke
/// icon — the standard icon is used for all kinds, exactly like Positions.
enum EmptyStateKind { empty, search, error, insufficientData }

class EmptyState extends StatelessWidget {
  final EmptyStateKind kind;
  final String title;
  final String? message;

  /// Optional action callback — surfaced as [NoDataFoundWeb]'s primary button
  /// (default label "Retry"). Used by the error states.
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

  @override
  Widget build(BuildContext context) {
    return NoDataFoundWeb(
      title: title,
      subtitle: message,
      // Retry only appears for the error states that provide a callback.
      primaryEnabled: onRetry != null,
      onPrimary: onRetry,
      primaryLabel: actionLabel ?? 'Retry',
      // Match Positions — no "Explore" secondary button.
      secondaryEnabled: false,
    );
  }
}
