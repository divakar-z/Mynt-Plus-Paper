import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/buildup_sentiment.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';

/// §5.4 Sentiment gauge — bullish vs bearish semicircle + the four buildup
/// quadrant counts.
class SentimentGauge extends StatelessWidget {
  final BuildupSentiment sentiment;

  const SentimentGauge({super.key, required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final s = sentiment;
    final denom = s.bullish + s.bearish;
    final frac = denom == 0 ? 0.5 : s.bullish / denom;
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final track = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    return DashSectionCard(
      title: 'Sentiment',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 176,
            height: 98,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                CustomPaint(
                  size: const Size(176, 98),
                  painter: _GaugePainter(
                      frac: frac.toDouble(),
                      bull: profit,
                      bear: loss,
                      track: track),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(frac * 100).round()}%',
                        style: MyntWebTextStyles.hero(context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary,
                            fontWeight: MyntFonts.bold),
                      ),
                      Text('Bullish',
                          style:
                              MyntWebTextStyles.body(context, color: primary, fontWeight: MyntFonts.medium  )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _Count(label: 'Bullish', value: s.bullish, color: profit),
                    const SizedBox(width: 24),
                    _Count(label: 'Bearish', value: s.bearish, color: loss),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Quad('Long buildup', s.longBuildup, profit),
                    _Quad('Short covering', s.shortCovering, kDashShortCov),
                    _Quad('Short buildup', s.shortBuildup, loss),
                    _Quad('Long covering', s.longCovering, kDashOrange),
                    if (s.na > 0)
                      _Quad('NA', s.na, muted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Count({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('$value',
            style: MyntWebTextStyles.hero(context,
                color: color, fontWeight: MyntFonts.bold)),
        const SizedBox(width: 5),
        Text(label, style: MyntWebTextStyles.body(context, color: primary, fontWeight: MyntFonts.medium)),
      ],
    );
  }
}

class _Quad extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Quad(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    // Match the table Category chip: colour-tinted background, uppercase label
    // in the category colour, and the count in a solid circular badge.
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: MyntWebTextStyles.para(context,
                color: color, fontWeight: MyntFonts.medium),
          ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: MyntWebTextStyles.caption(context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary
                  ),
                fontWeight: MyntFonts.bold),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double frac;
  final Color bull;
  final Color bear;
  final Color track;

  _GaugePainter({
    required this.frac,
    required this.bull,
    required this.bear,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final radius = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height - 3);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final clamped = frac.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    final seg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    if (clamped > 0) {
      canvas.drawArc(rect, math.pi, math.pi * clamped, false, seg..color = bull);
    }
    if (clamped < 1) {
      canvas.drawArc(rect, math.pi + math.pi * clamped, math.pi * (1 - clamped),
          false, seg..color = bear);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.frac != frac ||
      old.bull != bull ||
      old.bear != bear ||
      old.track != track;
}
