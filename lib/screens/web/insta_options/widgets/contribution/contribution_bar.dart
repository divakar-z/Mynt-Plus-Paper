import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// Signed points label, e.g. `+36.57` / `-95.44`; `—` when null.
String signedPts(double? v) =>
    v == null ? '—' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}';

/// A horizontal diverging bar for a signed contribution value: positive grows
/// right (profit-green), negative grows left (loss-red), scaled to [maxAbs] so
/// the largest mover spans its half. `label` (+ optional `sublabel`) sits on the
/// left, the signed value on the right.
class ContribBar extends StatelessWidget {
  final String label;
  final String? sublabel;

  /// Rich sublabel (e.g. coloured ▲/▼ counts); takes precedence over
  /// [sublabel] when both are given.
  final Widget? sublabelWidget;

  final double value;
  final double maxAbs;
  final double labelWidth;
  final double valueWidth;

  const ContribBar({
    super.key,
    required this.label,
    required this.value,
    required this.maxAbs,
    this.sublabel,
    this.sublabelWidget,
    this.labelWidth = 150,
    this.valueWidth = 72,
  });

  @override
  Widget build(BuildContext context) {
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final divider = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    final pos = value >= 0;
    final factor = maxAbs <= 0 ? 0.0 : (value.abs() / maxAbs).clamp(0.0, 1.0);
    final color = pos ? profit : loss;

    return Padding(
      // Tightened (was 10) — rows sit closer now the sector sublabel is gone.
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EllipsisText(label,
                    style: MyntWebTextStyles.body(context,
                        color: fg, fontWeight: MyntFonts.semiBold)),
                if (sublabelWidget != null) ...[
                  const SizedBox(height: 2),
                  sublabelWidget!,
                ] else if (sublabel != null) ...[
                  const SizedBox(height: 2),
                  EllipsisText(sublabel!,
                      style: MyntWebTextStyles.para(context,
                          color: muted, fontWeight: MyntFonts.regular)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 22,
              child: Row(
                children: [
                  Expanded(
                    child: FractionallySizedBox(
                      widthFactor: pos ? 0.0 : factor,
                      heightFactor: 1,
                      alignment: Alignment.centerRight,
                      child: _bar(loss),
                    ),
                  ),
                  Container(width: 1, color: divider),
                  Expanded(
                    child: FractionallySizedBox(
                      widthFactor: pos ? factor : 0.0,
                      heightFactor: 1,
                      alignment: Alignment.centerLeft,
                      child: _bar(profit),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: valueWidth,
            child: Text(signedPts(value),
                textAlign: TextAlign.right,
                style: MyntWebTextStyles.body(context,
                    color: color, fontWeight: MyntFonts.semiBold)),
          ),
        ],
      ),
    );
  }

  Widget _bar(Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(0),
          ),
        ),
      );
}

/// A single-line ellipsised label that reveals its full text in a [Tooltip]
/// **only when it's actually truncated** — measured against the width it's
/// given, so fully-visible names don't get a needless hover tooltip. Shared
/// by the movers bars and the contribution tables.
class EllipsisText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const EllipsisText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final label = Text(text,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
        return tp.width > constraints.maxWidth
            ? Tooltip(message: text, child: label)
            : label;
      },
    );
  }
}
