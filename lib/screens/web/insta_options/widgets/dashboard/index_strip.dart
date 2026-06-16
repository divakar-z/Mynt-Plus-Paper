import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/index_card.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// §5.3 Index strip — one card per index merging level, day change, PCR,
/// max-pain and (where available) F&O advance/decline. Horizontal scroll.
class IndexStrip extends StatefulWidget {
  final List<IndexCard> indices;

  const IndexStrip({super.key, required this.indices});

  @override
  State<IndexStrip> createState() => _IndexStripState();
}

class _IndexStripState extends State<IndexStrip> {
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.indices.isEmpty) return const SizedBox.shrink();
    return Scrollbar(
      controller: _hScroll,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _hScroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            for (var i = 0; i < widget.indices.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              SizedBox(width: 232, child: _IndexTile(card: widget.indices[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _IndexTile extends StatelessWidget {
  final IndexCard card;

  const _IndexTile({required this.card});

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    return shadcn.Card(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card.index,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.bodySmall(
                context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
                fontWeight: MyntFonts.semiBold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  InstaOptionsFormat.price(card.level),
                  style: MyntWebTextStyles.head(
                    context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                    fontWeight: MyntFonts.semiBold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  InstaOptionsFormat.changePct(card.changePct),
                  style: MyntWebTextStyles.caption(
                    context,
                    color: dashChangeColor(context, card.changePct),
                    fontWeight: MyntFonts.semiBold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(label: 'PCR', value: InstaOptionsFormat.pcr(card.pcr)),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Max pain',
                    value: InstaOptionsFormat.price(card.maxPain),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (card.hasBreadth)
              DashAdBar(
                advances: card.advances!,
                declines: card.declines!,
                unchanged: card.unchanged!,
              )
            else
              Text(
                'No NSE breadth',
                style: MyntWebTextStyles.caption(context, color: muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: MyntWebTextStyles.caption(
            context,
            darkColor: MyntColors.textTertiaryDark,
            lightColor: MyntColors.textTertiary,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: MyntWebTextStyles.bodySmall(
            context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.semiBold,
          ),
        ),
      ],
    );
  }
}
