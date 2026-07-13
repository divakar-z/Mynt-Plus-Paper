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

  static const double _cardWidth = 232;
  static const double _spacing = 12;

  @override
  Widget build(BuildContext context) {
    if (widget.indices.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = widget.indices.length;
        final contentWidth = n * _cardWidth + (n - 1) * _spacing;
        final needsScrolling = contentWidth > constraints.maxWidth;

        // Fits: plain left-aligned row, no chevrons, no scrollbar.
        if (!needsScrolling) {
          return Row(children: _cardChildren());
        }

        // Overflows: chevron buttons page the strip one card at a time
        // (same pattern as the Home dashboard Indices section — no scrollbar).
        return Row(
          children: [
            _ScrollButton(
              icon: Icons.arrow_back_ios,
              onTap: () => _page(-(_cardWidth + _spacing)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(children: _cardChildren()),
              ),
            ),
            const SizedBox(width: 8),
            _ScrollButton(
              icon: Icons.arrow_forward_ios,
              onTap: () => _page(_cardWidth + _spacing),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _cardChildren() {
    final children = <Widget>[];
    for (var i = 0; i < widget.indices.length; i++) {
      if (i > 0) children.add(const SizedBox(width: _spacing));
      children.add(
        SizedBox(width: _cardWidth, child: _IndexTile(card: widget.indices[i])),
      );
    }
    return children;
  }

  void _page(double delta) {
    if (!_hScroll.hasClients) return;
    final target = (_hScroll.offset + delta)
        .clamp(0.0, _hScroll.position.maxScrollExtent);
    _hScroll.animateTo(target,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }
}

/// Circular chevron paging button — mirrors the Home dashboard Indices scroller
/// (`_buildIndexScrollButton`): 28px card-coloured circle with a border + soft
/// shadow, vertically centred against the card strip.
class _ScrollButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ScrollButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: shadcn.Theme.of(context).colorScheme.card,
                border: Border.all(
                  color: shadcn.Theme.of(context).colorScheme.border,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 12,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                ),
              ),
            ),
          ),
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
    final divider = resolveThemeColor(context,
            dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary)
        .withValues(alpha: 0.2);

    return Container(
      // Fixed height so every card is the same size and the stats row (pinned
      // to the bottom by the Spacer) lines up across all cards.
      height: 130,
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
        border: Border.all(color: divider, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  style: MyntWebTextStyles.title(
                    context,
                     color: dashChangeColor(context, card.changePct),
                   
                    fontWeight: MyntFonts.medium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  InstaOptionsFormat.changePct(card.changePct),
                  style: MyntWebTextStyles.para(
                    context,
                     color: resolveThemeColor(
          context,
          dark: MyntColors.textSecondaryDark,
          light: MyntColors.textSecondary,
        ),               
                    fontWeight: MyntFonts.medium,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Horizontal divider above the pinned stats row.
            Divider(height: 1, thickness: 1, color: divider),
            const SizedBox(height: 10),
            // PCR | Max pain with a vertical divider between them.
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                        label: 'PCR', value: InstaOptionsFormat.pcr(card.pcr)),
                  ),
                  VerticalDivider(width: 24, thickness: 1, color: divider),
                  Expanded(
                    child: _MiniStat(
                        label: 'Max pain',
                        value: InstaOptionsFormat.price(card.maxPain)),
                  ),
                ],
              ),
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
            fontWeight: MyntFonts.medium,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: MyntWebTextStyles.body(
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
