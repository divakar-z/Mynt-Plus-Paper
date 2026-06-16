import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/sector_performance.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';

/// §5.6 Sector performance — heatmap cells coloured by avg change%, strongest
/// first. Each cell shows adv/decl and net OI.
class SectorPerformanceSection extends StatelessWidget {
  final List<SectorPerformanceRow> sectors;

  const SectorPerformanceSection({super.key, required this.sectors});

  @override
  Widget build(BuildContext context) {
    final sorted = [...sectors]
      ..sort((a, b) => b.avgChangePct.compareTo(a.avgChangePct));
    final maxAbs = sorted.fold<double>(
        0, (m, s) => s.avgChangePct.abs() > m ? s.avgChangePct.abs() : m);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    return DashSectionCard(
      title: 'Sector Performance',
      child: sorted.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No sector data.',
                    style: MyntWebTextStyles.caption(context, color: muted)),
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in sorted)
                  _Cell(
                    sector: s,
                    intensity: maxAbs == 0 ? 0 : s.avgChangePct.abs() / maxAbs,
                  ),
              ],
            ),
    );
  }
}

class _Cell extends StatelessWidget {
  final SectorPerformanceRow sector;
  final double intensity;

  const _Cell({required this.sector, required this.intensity});

  @override
  Widget build(BuildContext context) {
    final up = sector.avgChangePct >= 0;
    final base = up
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);
    final alpha = (0.10 + 0.42 * intensity).clamp(0.10, 0.55).toDouble();
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    return Container(
      width: 134,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: base.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: base.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sector.sector,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.caption(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            InstaOptionsFormat.changePct(sector.avgChangePct),
            style: MyntWebTextStyles.bodySmall(context,
                color: base, fontWeight: MyntFonts.bold),
          ),
          const SizedBox(height: 3),
          Text(
            '${sector.advances}▲ ${sector.declines}▼ · OI ${sector.netOi}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.caption(context, color: muted),
          ),
        ],
      ),
    );
  }
}
