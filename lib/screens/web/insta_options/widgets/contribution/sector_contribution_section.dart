import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/contribution/contribution_bar.dart';

/// Sector contribution body — each macro sector's summed point contribution as
/// a diverging bar (green up / red down), strongest first. Rendered inside the
/// detail tab strip (no card of its own).
class SectorContributionSection extends StatelessWidget {
  final IndexContribution data;

  const SectorContributionSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final sectors = [...data.sectorContribution]
      ..sort((a, b) =>
          (b.pointContribution ?? 0).compareTo(a.pointContribution ?? 0));
    final maxAbs = sectors.fold<double>(0, (m, s) {
      final v = (s.pointContribution ?? 0).abs();
      return v > m ? v : m;
    });
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    if (sectors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('No sector data.',
              style: MyntWebTextStyles.caption(context, color: muted)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in sectors)
          ContribBar(
            label: s.sector,
            sublabel: '${s.stocks} stk · ${s.advances}▲ ${s.declines}▼',
            value: s.pointContribution ?? 0,
            maxAbs: maxAbs,
            labelWidth: 188,
          ),
      ],
    );
  }
}
