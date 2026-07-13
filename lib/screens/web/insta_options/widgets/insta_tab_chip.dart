import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Shared tab / filter chip for the InstaOptions module — the single source of
/// truth for the Holdings-style pill. Used by both the top navigation strip
/// ([InstaTopTabs]) and in-screen filter rows (e.g. the Buildup category
/// filter), so size, font and label styling are guaranteed identical.
///
/// Pill: padding 16×8, radius 6, subtle background when [selected], transparent
/// otherwise. Label is semiBold + primary text when selected, medium +
/// secondary text otherwise. An optional [count] renders as a muted trailing
/// number (same size) for filter rows that show a per-category tally.
class InstaTabChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const InstaTabChip({
    super.key,
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final labelColor = selected ? tokens.textPrimary : tokens.textSecondary;
    final weight = selected ? MyntFonts.semiBold : MyntFonts.medium;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? tokens.bgTertiary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: MyntWebTextStyles.body(
                  context,
                  color: labelColor,
                  fontWeight: weight,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                // Superscript count — matches the Orders / Holdings tab badge
                // (raised, smaller, same colour as the label).
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Text(
                    '$count',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      fontWeight: weight,
                    ).copyWith(fontSize: 13, color: labelColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
