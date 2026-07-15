import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dashboard_enums.dart';
import 'package:mynt_plus/models/insta_options/option_chain/oi_wall.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Index Contribution header — one section card in the [DashSectionCard]
/// family: the index + level + signed change as the header row, a full-width
/// divider, then a row of bordered mini-tiles (PCR / Rollover / Buildup /
/// Max pain / Basis / Support / Resistance), each label-over-value. Colour
/// only where the field is directional; the Support / Resistance tiles carry
/// it on their labels with the strikes joined on one neutral line.
class ContributionHeader extends StatelessWidget {
  final IndexContribution data;

  const ContributionHeader({super.key, required this.data});

  /// Fixed width of the combined Support | Resistance card on wide panels.
  static const double _wallCardWidth = 280;

  @override
  Widget build(BuildContext context) {
    final walls = _wallCard(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (walls == null) return _statsCard(context);

        // Wide enough: the walls card sits to the right, both stretched to
        // the same height. Otherwise it breaks onto its own row below.
        final wide = constraints.maxWidth >= 720;
        if (wide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _statsCard(context)),
                const SizedBox(width: 12),
                SizedBox(width: _wallCardWidth, child: walls),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statsCard(context),
            const SizedBox(height: 12),
            walls,
          ],
        );
      },
    );
  }

  Color _divider(BuildContext context) => resolveThemeColor(context,
          dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary)
      .withValues(alpha: 0.2);

  // ---------------------------------------------------------------------------
  // Card A — index level + mini-stat row.
  // ---------------------------------------------------------------------------
  /// Section-card layout matching [DashSectionCard] ("Contribution to the
  /// move"): the index + level + change as the header row, a full-width
  /// divider, then the mini-stat row as the body.
  Widget _statsCard(BuildContext context) {
    final stats = _stats(context);
    final headerBorder = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    return shadcn.Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // With a bounded height (stretched beside the wall cards) this pins
        // the stats row to the bottom; unbounded it collapses to natural size.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: headerBorder)),
            ),
            child: _headerRow(context),
          ),
          if (stats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _statTile(context, stats[i])),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// One stat as its own bordered mini-card inside the stats card.
  Widget _statTile(BuildContext context, _Stat stat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: _divider(context), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: _miniStat(context, stat),
    );
  }

  /// Header row — index name, level and signed change on one line (the same
  /// title treatment as the other section-card headers).
  Widget _headerRow(BuildContext context) {
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final pc = data.pointChange;
    final moveColor = dashChangeColor(context, pc);

    return Row(
      children: [
        Text(
          data.index,
          style: MyntWebTextStyles.title(context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
              fontWeight: MyntFonts.bold),
        ),
        const SizedBox(width: 12),
        Text(
          data.level == null ? '—' : InstaOptionsFormat.price(data.level),
          style: MyntWebTextStyles.title(context,
              color: primary, fontWeight: MyntFonts.semiBold),
        ),
        if (pc != null) ...[
          const SizedBox(width: 6),
          Icon(
            pc >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            size: 22,
            color: moveColor,
          ),
          Text(
            '${InstaOptionsFormat.price(pc.abs())} pts',
            style: MyntWebTextStyles.body(context,
                color: moveColor, fontWeight: MyntFonts.semiBold),
          ),
          const SizedBox(width: 6),
          Text(
            '(${InstaOptionsFormat.changePct(data.changePct)})',
            style: MyntWebTextStyles.bodySmall(context, color: moveColor),
          ),
        ],
      ],
    );
  }

  /// The mini-stat row entries. Colour only where the field is directional:
  /// PCR (band), Buildup (its category colour), Basis (sign); Rollover and
  /// Max pain stay neutral.
  List<_Stat> _stats(BuildContext context) {
    final out = <_Stat>[];
    final opt = data.options;
    final oi = data.indexOi;

    if (opt != null) {
      out.add(_Stat('PCR', InstaOptionsFormat.pcr(opt.pcr),
          _pcrColor(context, opt.pcr)));
    }
    if (oi != null && oi.rolloverPct != null) {
      out.add(_Stat(
          'Rollover',
          InstaOptionsFormat.changePct(oi.rolloverPct).replaceAll('+', ''),
          null));
    }
    if (oi != null && oi.buildup != null) {
      final cat = BuildupCategory.fromWire(oi.buildup);
      out.add(_Stat('Buildup', dashCategoryChipLabel(cat),
          dashCategoryColor(context, cat)));
    }
    if (opt != null && opt.maxPain != null) {
      out.add(_Stat('Max pain', InstaOptionsFormat.price(opt.maxPain), null));
    }
    if (oi != null && oi.basis != null) {
      final pctPart = oi.basisPct == null
          ? ''
          : ' (${InstaOptionsFormat.changePct(oi.basisPct)})';
      out.add(_Stat('Basis', '${_signed(oi.basis)}$pctPart',
          dashChangeColor(context, oi.basis)));
    }
    return out;
  }

  Widget _miniStat(BuildContext context, _Stat stat) {
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stat.label,
          style: MyntWebTextStyles.body(
            context,
            darkColor: MyntColors.textTertiaryDark,
            lightColor: MyntColors.textTertiary,
            fontWeight: MyntFonts.regular,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          stat.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MyntWebTextStyles.body(context,
              color: stat.color ?? fg, fontWeight: MyntFonts.medium),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Card B — one Support | Resistance card, two columns split by a divider.
  // ---------------------------------------------------------------------------
  Widget? _wallCard(BuildContext context) {
    final opt = data.options;
    if (opt == null) return null;
    final r = _wallStrikeList(opt.resistance);
    final s = _wallStrikeList(opt.support);
    if (r.isEmpty && s.isEmpty) return null;

    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);

    final halves = <Widget>[
      if (s.isNotEmpty)
        _wallHalf(context, label: 'Support', strikes: s, color: profit),
      if (r.isNotEmpty)
        _wallHalf(context, label: 'Resistance', strikes: r, color: loss),
    ];

    return shadcn.Card(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < halves.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                    width: 1, thickness: 1, color: _divider(context)),
              Expanded(child: halves[i]),
            ],
          ],
        ),
      ),
    );
  }

  /// One column of the walls card: coloured label in a header cell (same
  /// border treatment as the card-A header) with the strikes stacked beneath.
  Widget _wallHalf(BuildContext context,
      {required String label,
      required List<String> strikes,
      required Color color}) {
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final headerBorder = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: headerBorder)),
          ),
          child: Text(
            label,
            style: MyntWebTextStyles.body(context,
                color: color, fontWeight: MyntFonts.semiBold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < strikes.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                Text(strikes[i],
                    style: MyntWebTextStyles.body(context,
                        color: fg, fontWeight: MyntFonts.semiBold)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<String> _wallStrikeList(List<OiWall> walls) =>
      walls.take(3).map((w) => w.strike.toStringAsFixed(0)).toList();

  String _signed(double? v) {
    if (v == null) return '—';
    final s = InstaOptionsFormat.price(v.abs());
    return v >= 0 ? '+$s' : '-$s';
  }

  Color _pcrColor(BuildContext context, double? pcr) {
    if (pcr == null) {
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    }
    if (pcr <= 0.7) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    }
    if (pcr > 1.3) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    }
    return kDashOrange;
  }
}

/// One mini-stat: label over value, with an optional directional colour.
class _Stat {
  final String label;
  final String value;
  final Color? color;

  const _Stat(this.label, this.value, this.color);
}
