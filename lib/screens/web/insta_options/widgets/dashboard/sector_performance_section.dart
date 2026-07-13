import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/sector_performance.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';

/// §5.6 Sector performance — scanner-style cards: a white panel with an accent
/// (direction-tinted) border, the sector name + a Bullish / Bearish / Neutral
/// sentiment ribbon, the change % as the hero value, and an advances / declines
/// / net-OI footer. Sorted strongest → weakest, laid out in a responsive grid.
class SectorPerformanceSection extends StatelessWidget {
  final List<SectorPerformanceRow> sectors;

  const SectorPerformanceSection({super.key, required this.sectors});

  @override
  Widget build(BuildContext context) {
    final sorted = [...sectors]
      ..sort((a, b) => b.avgChangePct.compareTo(a.avgChangePct));
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    if (sorted.isEmpty) {
      return DashSectionCard(
        title: 'Sector Performance',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('No sector data.',
                style: MyntWebTextStyles.caption(context, color: muted)),
          ),
        ),
      );
    }

    return DashSectionCard(
      title: 'Sector Performance',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1280
              ? 4
              : constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 580
                      ? 2
                      : 1;
          const spacing = 14.0;
          final cardWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final s in sorted)
                SizedBox(width: cardWidth, child: _Cell(sector: s)),
            ],
          );
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final SectorPerformanceRow sector;

  const _Cell({required this.sector});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final up = sector.avgChangePct >= 0;
    final neutral = sector.avgChangePct.abs() < 0.05;
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final dir = neutral ? muted : (up ? profit : loss);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // No fill — the direction (green up / red down / grey flat) is carried
        // by the border colour only.
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
        border: Border.all(
            color: dir.withValues(alpha: isDark ? 0.55 : 0.5), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sector name — one line; ellipsised when too long, full name on hover.
          SizedBox(
            width: double.infinity,
            child: Tooltip(
              message: sector.sector,
              waitDuration: const Duration(milliseconds: 400),
              child: Text(
                sector.sector,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MyntWebTextStyles.title(context,
                    fontWeight: MyntFonts.semiBold, color: textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Change % — the hero value.
          Text(
            InstaOptionsFormat.changePct(sector.avgChangePct),
            style: MyntWebTextStyles.title(context,
                color: dir, fontWeight: MyntFonts.semiBold),
          ),
          const SizedBox(height: 10),
          // Advances / declines / net OI — directly under the change %.
          Row(
            children: [
              Text(
                '▲ ${sector.advances}',
                style: MyntWebTextStyles.para(context,
                    color: profit, fontWeight: MyntFonts.semiBold),
              ),
              const SizedBox(width: 10),
              Text(
                '▼ ${sector.declines}',
                style: MyntWebTextStyles.para(context,
                    color: loss, fontWeight: MyntFonts.semiBold),
              ),
              const Spacer(),
              Text(
                'OI ${sector.netOi}',
                style: MyntWebTextStyles.para(context, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
