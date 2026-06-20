import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dashboard_enums.dart';
import 'package:mynt_plus/models/insta_options/option_chain/oi_wall.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';

/// Index Contribution header: the index level + signed point-change/percent,
/// then a chip strip carrying PCR (band-coloured), max-pain, futures basis +
/// OI-buildup, rollover %, and the support/resistance OI walls. Everything here
/// comes from the index's own data, so it renders even when the constituent
/// weightage feed is unavailable.
class ContributionHeader extends StatelessWidget {
  final IndexContribution data;

  const ContributionHeader({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final walls = _wallChips(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _levelRow(context),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: _primaryChips(context)),
          if (walls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: walls),
          ],
        ],
      ),
    );
  }

  Widget _levelRow(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final pc = data.pointChange;
    final moveColor = dashChangeColor(context, pc);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.index,
                style: MyntWebTextStyles.caption(context, color: muted)
                    .copyWith(letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(
              data.level == null
                  ? '—'
                  : InstaOptionsFormat.price(data.level),
              style: MyntWebTextStyles.title(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.bold)
                  .copyWith(fontSize: 26, height: 1.05),
            ),
          ],
        ),
        const SizedBox(width: 14),
        if (pc != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  style:
                      MyntWebTextStyles.bodySmall(context, color: moveColor),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('—',
                style: MyntWebTextStyles.body(context, color: primary)),
          ),
      ],
    );
  }

  /// Line 1 — PCR, rollover (next to PCR), the futures OI-buildup chip, then
  /// max-pain and basis.
  List<Widget> _primaryChips(BuildContext context) {
    final out = <Widget>[];
    final opt = data.options;
    final oi = data.indexOi;

    if (opt != null) {
      out.add(_chip(context,
          label: 'PCR',
          value: InstaOptionsFormat.pcr(opt.pcr),
          valueColor: _pcrColor(context, opt.pcr)));
    }
    if (oi != null && oi.rolloverPct != null) {
      out.add(_chip(context,
          label: 'Rollover',
          value: InstaOptionsFormat.changePct(oi.rolloverPct)
              .replaceAll('+', '')));
    }
    if (oi != null && oi.buildup != null) {
      out.add(
          DashCategoryChip(category: BuildupCategory.fromWire(oi.buildup)));
    }
    if (opt != null && opt.maxPain != null) {
      out.add(_chip(context,
          label: 'Max pain', value: InstaOptionsFormat.price(opt.maxPain)));
    }
    if (oi != null && oi.basis != null) {
      final pctPart = oi.basisPct == null
          ? ''
          : ' (${InstaOptionsFormat.changePct(oi.basisPct)})';
      out.add(_chip(context,
          label: 'Basis',
          value: '${_signed(oi.basis)}$pctPart',
          valueColor: dashChangeColor(context, oi.basis)));
    }
    return out;
  }

  /// Line 2 — the OI-wall resistance / support strikes.
  List<Widget> _wallChips(BuildContext context) {
    final out = <Widget>[];
    final opt = data.options;
    if (opt == null) return out;
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final r = _wallStrikes(opt.resistance);
    final s = _wallStrikes(opt.support);
    if (r.isNotEmpty) {
      out.add(_chip(context, label: 'R', value: r, valueColor: loss));
    }
    if (s.isNotEmpty) {
      out.add(_chip(context, label: 'S', value: s, valueColor: profit));
    }
    return out;
  }

  String _wallStrikes(List<OiWall> walls) =>
      walls.take(3).map((w) => w.strike.toStringAsFixed(0)).join(' · ');

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

  Widget _chip(BuildContext context,
      {required String label, required String value, Color? valueColor}) {
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final hover = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hover,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: MyntWebTextStyles.caption(context, color: muted)),
          Text(value,
              style: MyntWebTextStyles.bodySmall(context,
                  color: valueColor ?? fg, fontWeight: MyntFonts.semiBold)),
        ],
      ),
    );
  }
}
