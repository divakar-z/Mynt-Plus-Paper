import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/buildup_row.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Pill-shaped classification label per README §9.6. Background is the kind's
/// colour at 20% opacity; text is the same colour at full intensity.
class BuildupPill extends StatelessWidget {
  final BuildupKind kind;

  const BuildupPill({super.key, required this.kind});

  Color _colorFor(InstaOptionsTokens tokens) {
    switch (kind) {
      case BuildupKind.longBuildup:
        return tokens.profit;
      case BuildupKind.shortBuildup:
        return tokens.loss;
      case BuildupKind.shortCovering:
        return tokens.info;
      case BuildupKind.longUnwinding:
        return tokens.warning;
      case BuildupKind.neutral:
        return tokens.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final base = _colorFor(tokens);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        kind.display,
        style: MyntWebTextStyles.caption(
          context,
          color: base,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
