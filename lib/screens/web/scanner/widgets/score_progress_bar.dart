import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

class ScoreProgressBar extends StatelessWidget {
  final String label;
  final double? score; // 0–100
  const ScoreProgressBar({super.key, required this.label, required this.score});

  Color _color(double s) {
    if (s >= 80) return MyntColors.success;
    if (s >= 60) return const Color(0xFF10B981); // emerald
    if (s >= 40) return MyntColors.warning;
    return MyntColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final s = (score ?? 0).clamp(0, 100).toDouble();
    final color = _color(s);
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: MyntWebTextStyles.body(context)),
            Text(
              score == null ? '—' : s.round().toString(),
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.semiBold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 8, color: bg),
              FractionallySizedBox(
                widthFactor: s / 100,
                child: Container(height: 8, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
