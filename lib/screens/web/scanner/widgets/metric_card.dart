import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/technical_interpretations.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final TechnicalBadge? badge;
  final String? secondaryLine;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.badge,
    this.secondaryLine,
  });

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(5),
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: MyntWebTextStyles.para(context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary)),
          ),
          const SizedBox(height: 4),
          // Value on the left, badge opposite it on the right (same row).
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.semiBold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badge!.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!.label,
                    style: MyntWebTextStyles.caption(context,
                        color: badge!.color, fontWeight: MyntFonts.medium),
                  ),
                ),
              ],
            ],
          ),
          if (secondaryLine != null) ...[
            const SizedBox(height: 4),
            Text(secondaryLine!,
                style: MyntWebTextStyles.caption(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary))),
          ],
        ],
      ),
    );
  }
}
