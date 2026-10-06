import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../res/mynt_web_text_styles.dart';

/// "Fund at a glance" picture for the fund detail header (picked
/// 2026-10-06, MF Work Board option C): a white card with a ring split into
/// blue, sky and apricot (the fund's mix) and three rising bars (returns),
/// in the SIP calculator style. It stands on the header like the NFO rocket.
///
/// Animates once when shown (card rises in, ring sweeps round, bars grow,
/// sparkle pops) and plays again on hover; never loops. Drawn with a
/// CustomPainter so the parts can move separately; wrapped in a
/// RepaintBoundary. Reduced motion shows the finished picture.
class MfFundGlanceArt extends StatefulWidget {
  final double width;
  const MfFundGlanceArt({super.key, this.width = 180});

  @override
  State<MfFundGlanceArt> createState() => _MfFundGlanceArtState();
}

class _MfFundGlanceArtState extends State<MfFundGlanceArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) { 
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _replay() {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    if (_c.isAnimating) return;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final w = widget.width;
    return MouseRegion(
      onEnter: (_) => _replay(),
      child: RepaintBoundary(
        child: ExcludeSemantics(
          child: SizedBox(
            width: w,
            height: w * 134 / 170,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _GlancePainter(_c.value, dark),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlancePainter extends CustomPainter {
  final double t;
  final bool dark;
  _GlancePainter(this.t, this.dark);

  // Same palette as the mandate and redeem pictures.
  Color get blue => dark ? const Color(0xFF6E97FF) : const Color(0xFF0037B7);
  Color get blue2 => dark ? const Color(0xFF3B7BE0) : const Color(0xFF3F7FE8);
  Color get soft => dark ? const Color(0xFF1E3358) : const Color(0xFFBCD3FF);
  Color get peach => dark ? const Color(0xFFF7B07A) : const Color(0xFFF59E5B);
  Color get navy => dark ? const Color(0xFFA9C4FF) : const Color(0xFF1B2F73);
  Color get card => dark ? const Color(0xFF161B22) : Colors.white;

  /// Progress of a step that runs from [a] to [b] of the whole animation.
  double _step(double a, double b) =>
      Curves.easeOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    // Draw on the 170 x 134 grid of the mock.
    canvas.scale(size.width / 170, size.height / 134);

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(85, 127), width: 144, height: 10),
      Paint()..color = peach.withValues(alpha: 0.28),
    );

    // Card rises in.
    final cardT = _step(0, 0.3);
    canvas.save();
    canvas.translate(0, 8 * (1 - cardT));
    final cardPaint = Paint()..color = card.withValues(alpha: cardT);
    final cardRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 28, 142, 92), const Radius.circular(12));
    canvas.drawRRect(cardRect, cardPaint);
    canvas.drawRRect(
        cardRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = soft.withValues(alpha: cardT));

    // Name line.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(96, 40, 36, 5), const Radius.circular(2.5)),
        Paint()..color = navy.withValues(alpha: 0.85 * cardT));

    // Ring: track, then blue, sky and apricot sweep round in turn.
    const centre = Offset(56, 74);
    final ringRect = Rect.fromCircle(center: centre, radius: 24);
    Paint ring(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = c;
    canvas.drawArc(ringRect, 0, math.pi * 2, false,
        ring(soft.withValues(alpha: cardT)));
    double deg(double d) => d * math.pi / 180;
    final segments = [
      (-90.0, 102.0, blue),
      (12.0, 108.0, blue2),
      (120.0, 93.0, peach),
    ];
    for (var i = 0; i < segments.length; i++) {
      final (start, sweep, colour) = segments[i];
      final p = _step(0.18 + i * 0.14, 0.42 + i * 0.14);
      if (p <= 0) continue;
      canvas.drawArc(ringRect, deg(start), deg(sweep * p), false, ring(colour));
    }

    // Bars grow from the bottom, one after another.
    final bars = [
      (96.0, 26.0, soft),
      (114.0, 42.0, blue2),
      (132.0, 58.0, blue),
    ];
    for (var i = 0; i < bars.length; i++) {
      final (x, h, colour) = bars[i];
      final p = _step(0.45 + i * 0.12, 0.75 + i * 0.12);
      if (p <= 0) continue;
      final hh = h * p;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 108 - hh, 12, hh), const Radius.circular(3)),
          Paint()..color = colour);
    }
    canvas.restore();

    // Sparkle pops at the end.
    final s = _step(0.8, 1);
    if (s > 0) {
      canvas.save();
      canvas.translate(150, 20);
      canvas.scale(0.7 * s);
      final path = Path()
        ..moveTo(0, -9)
        ..lineTo(2.6, -2.6)
        ..lineTo(9, 0)
        ..lineTo(2.6, 2.6)
        ..lineTo(0, 9)
        ..lineTo(-2.6, 2.6)
        ..lineTo(-9, 0)
        ..lineTo(-2.6, -2.6)
        ..close();
      canvas.drawPath(path, Paint()..color = peach);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GlancePainter old) =>
      old.t != t || old.dark != dark;
}
