import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/contribution_bar.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';

/// Top contributors and detractors as diverging bars — the centerpiece of the
/// Index Contribution screen. Bars share one scale (the largest |point| in
/// view), so the biggest mover up or down spans its half; the per-stock values
/// sum to the index's point move.
class ContributionMovers extends StatelessWidget {
  final IndexContribution data;
  final int perSide;

  const ContributionMovers({super.key, required this.data, this.perSide = 8});

  @override
  Widget build(BuildContext context) {
    final maxAbs = data.maxAbsContribution;
    final contributors = data.contributors.take(perSide).toList();
    final detractors = data.detractors.take(perSide).toList();
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    return DashSectionCard(
      title: 'Contribution to the move',
      trailing: _netChip(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (contributors.isNotEmpty) ...[
            _group(context, 'Top contributors', muted),
            for (final c in contributors)
              ContribBar(
                label: c.symbol,
                sublabel: c.sector,
                value: c.pointContribution ?? 0,
                maxAbs: maxAbs,
              ),
          ],
          if (detractors.isNotEmpty) ...[
            const SizedBox(height: 12),
            _group(context, 'Top detractors', muted),
            for (final d in detractors)
              ContribBar(
                label: d.symbol,
                sublabel: d.sector,
                value: d.pointContribution ?? 0,
                maxAbs: maxAbs,
              ),
          ],
        ],
      ),
    );
  }

  Widget _group(BuildContext context, String label, Color muted) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text(
          label.toUpperCase(),
          style: MyntWebTextStyles.body(context,
                  color: muted, fontWeight: MyntFonts.semiBold)
              .copyWith(letterSpacing: 0.5),
        ),
      );

  Widget _netChip(BuildContext context) {
    final pc = data.pointChange;
    // Softened a touch toward white so the fill isn't a heavy block of colour.
    final color =
        Color.lerp(dashChangeColor(context, pc), Colors.white, 0.10)!;
    // Solid rounded chip, coloured by the net point move.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('Net ${signedPts(pc)} pts',
          style: MyntWebTextStyles.bodySmall(context,
              color: Colors.white, fontWeight: MyntFonts.semiBold)),
    );
  }
}
