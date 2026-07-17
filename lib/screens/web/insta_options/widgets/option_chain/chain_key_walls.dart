import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/option_chain/oi_wall.dart';
import 'package:mynt_plus/models/insta_options/option_chain/option_chain_data.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';

/// The key OI walls: heaviest CALL walls (resistance) and PUT walls (support),
/// each with its OI bar and whether it is **building** (OI up) or **easing**
/// (OI down) — from that strike's OI-change. Answers "which levels are real,
/// and are they strengthening or weakening".
class ChainKeyWalls extends StatelessWidget {
  final OptionChainData data;

  const ChainKeyWalls({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.support.isEmpty && data.resistance.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxOi = _maxWallOi();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: _col(context, 'Resistance · call walls', data.resistance,
                true, maxOi)),
        const SizedBox(width: 20),
        Expanded(
            child: _col(
                context, 'Support · put walls', data.support, false, maxOi)),
      ],
    );
  }

  int _maxWallOi() {
    var m = 0;
    for (final w in data.support) {
      if (w.oi > m) m = w.oi;
    }
    for (final w in data.resistance) {
      if (w.oi > m) m = w.oi;
    }
    return m;
  }

  /// OI Δ% at [strike] for the CE (resistance) or PE (support) leg.
  double? _chgAt(double strike, bool call) {
    for (final r in data.rows) {
      if (r.strike == strike) {
        return call ? r.ce?.oiChangePct : r.pe?.oiChangePct;
      }
    }
    return null;
  }

  Widget _col(BuildContext context, String title, List<OiWall> walls, bool call,
      int maxOi) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final color = call
        ? resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss)
        : resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    // Title in primary; the descriptor rides in brackets, muted.
    final parts = title.split(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: parts.first,
                style: MyntWebTextStyles.body(context,
                    color: fg, fontWeight: MyntFonts.semiBold)),
            if (parts.length > 1)
              TextSpan(
                  text: ' (${parts.sublist(1).join(' · ')})',
                  style: MyntWebTextStyles.para(context, color: muted)),
          ]),
        ),
        const SizedBox(height: 6),
        for (final w in walls.take(3)) _row(context, w, call, color, maxOi),
      ],
    );
  }

  Widget _row(
      BuildContext context, OiWall w, bool call, Color color, int maxOi) {
    final chg = _chgAt(w.strike, call);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final track = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final frac = maxOi <= 0 ? 0.0 : (w.oi / maxOi).clamp(0.0, 1.0);
    final building = chg != null && chg > 0;
    // Neutral chip: the word stays black; only the arrow + percentage carry
    // the direction colour (green building / red easing).
    final dirColor = building ? profit : loss;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(w.strike.toStringAsFixed(0),
                style: MyntWebTextStyles.body(context,
                    color: color, fontWeight: MyntFonts.semiBold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: Container(
                height: 10,
                color: track,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: frac,
                  child: Container(color: color.withValues(alpha: 0.4)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            // Wide enough for "9.99Cr" at body size — one line, no wrap.
            width: 56,
            child: Text(InstaOptionsFormat.oi(w.oi),
                textAlign: TextAlign.right,
                maxLines: 1,
                softWrap: false,
                style: MyntWebTextStyles.body(context, color: secondary)),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 104,
            child: chg == null
                ? Text('—',
                    textAlign: TextAlign.right,
                    style:
                        MyntWebTextStyles.caption(context, color: tertiary))
                : Align(
                    alignment: Alignment.centerRight,
                    // Neutral chip — word in black, arrow + % in the
                    // direction colour.
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          
                          Flexible(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                    text: building ? 'Building ' : 'Easing ',
                                    style: MyntWebTextStyles.para(context,
                                            color: fg,
                                            fontWeight: MyntFonts.regular)
                                        ),
                                TextSpan(
                                    text: InstaOptionsFormat.pctCompact(
                                        chg.abs(),
                                        showSign: false),
                                    style: MyntWebTextStyles.para(context,
                                            color: dirColor,
                                            fontWeight: MyntFonts.medium)
                                        ),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    
                  ),
          ),
        ],
      ),
    );
  }
}
