import 'dart:async';

import 'package:flutter/material.dart';

import '../res/mynt_web_color_styles.dart';
import '../res/mynt_web_text_styles.dart';

/// A validation bubble anchored under a text field.
///
/// Client feedback 15 Sep 2026: the password-rules message read like a wall of
/// red error text sitting under the field. This shows the same message the way
/// a browser shows its own constraint-validation popup — a small card with a
/// warning icon, pointing up at the field it belongs to.
///
/// Flutter Web paints text fields onto a canvas, so there is no real `<input>`
/// for the browser to validate and no native bubble to reuse; this is the
/// hand-built equivalent, which also means it looks identical in every browser
/// instead of following whatever chrome the user happens to be running.
///
/// It lives in an [OverlayEntry] rather than in the widget tree, so showing it
/// never shifts the fields under the user's cursor, and it is wrapped in an
/// [IgnorePointer] so it can never swallow a click meant for the submit button
/// underneath.
///
/// Usage:
/// ```dart
/// final _bubble = PasswordErrorBubbleController();
/// // ...
/// CompositedTransformTarget(link: _bubble.link, child: TextFormField(...))
/// // ...
/// _bubble.show(context, 'Please enter an uppercase letter, ...');
/// ```
/// Call [dispose] from the State's dispose.
class PasswordErrorBubbleController {
  /// Links the bubble to the field it points at. Wrap that field in a
  /// [CompositedTransformTarget] with this link.
  final LayerLink link = LayerLink();

  OverlayEntry? _entry;

  bool get isShowing => _entry != null;

  /// Shows [message] under the linked field, replacing any bubble already up.
  ///
  /// When [points] is non-empty the message becomes a heading and the points
  /// are listed as bullets beneath it — a run-on sentence of requirements was
  /// hard to read (client review 18 Sep 2026).
  void show(
    BuildContext context,
    String message, {
    List<String> points = const [],
  }) {
    hide();
    if (message.trim().isEmpty) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _entry = OverlayEntry(
      // No fixed width — the bubble sizes to its text (capped inside
      // _PasswordErrorBubble) the way a browser's own popup does, so short
      // messages stay on one line instead of filling a set-width box.
      // left/top are placeholders — the real position comes from the follower's
      // transform. They matter only to keep this a *positioned* child of the
      // overlay's stack: a non-positioned child is laid out with tight,
      // full-screen constraints, which would stretch the bubble edge to edge.
      builder: (_) => Stack(
        children: [
          // Dismiss on a click anywhere. The bubble hangs over whatever sits
          // below the field — usually the next password box — so leaving it up
          // after the user has moved on means it covers the field they are
          // typing into.
          //
          // HitTestBehavior.translucent is what makes this safe: the listener
          // is added to the hit-test result (so it hears the press) but reports
          // a miss, so the field or button underneath still receives the very
          // same click. Nothing is swallowed.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              // Deferred: removing our own overlay entry in the middle of
              // pointer dispatch would pull the render object out from under
              // the event still being delivered.
              onPointerDown: (_) => scheduleMicrotask(hide),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: link,
              showWhenUnlinked: false,
              // Hang below the field's bottom-left corner.
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 4),
              child: IgnorePointer(
                child: _PasswordErrorBubble(message: message, points: points),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_entry!);
  }

  /// Removes the bubble if one is up. Safe to call when there isn't.
  ///
  /// There is deliberately no auto-hide timer. Chrome's native bubble times
  /// out after ~5s, but that is one short line — this one is a heading plus
  /// up to five bullets, and timing out mid-read leaves no way back to the
  /// message short of submitting again. It stays until the user clicks or
  /// types anywhere, the change succeeds, or they leave the screen.
  void hide() {
    _entry?.remove();
    _entry = null;
  }

  void dispose() => hide();
}

/// Geometry shared by the painter and the content padding, so the text can
/// never sit on top of the tail.
const double _tailHeight = 8;
const double _tailWidth = 16;

/// How far in from the left edge the tail sits. The bubble is anchored to the
/// field's bottom-left, so this puts the point under the start of the field
/// rather than out at the corner.
const double _tailInset = 20;

const double _cornerRadius = 6;

/// The badge colour. Deliberately a flat orange rather than [MyntColors.loss]:
/// a browser's validation popup reads as a hint, and the app's pure red
/// (#FF1717) makes the same sentence read as an alarm.
const Color _badgeOrange = Color(0xFFEA6B26);

/// Heading above the bullet list. Kept here so both Change Password surfaces
/// use the same wording.
const String passwordRulesHeading = 'Password must contain';

class _PasswordErrorBubble extends StatelessWidget {
  const _PasswordErrorBubble({required this.message, this.points = const []});

  final String message;

  /// Listed as bullets under [message]. Empty means message-only.
  final List<String> points;

  /// The rules arrive lowercase ("a number") because they were written to be
  /// comma-joined into a sentence. As list items they want a capital.
  String _asListItem(String point) =>
      point.isEmpty ? point : point[0].toUpperCase() + point.substring(1);

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final background = dark ? MyntColors.cardDark : MyntColors.card;
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    return ConstrainedBox(
      // Wide enough for the longest rules sentence to take two lines rather
      // than three, narrow enough that a short message doesn't stretch.
      constraints: const BoxConstraints(maxWidth: 300),
      child: CustomPaint(
        painter: _BubblePainter(
          fill: background,
          stroke: border,
          shadow: Colors.black.withValues(alpha: dark ? 0.5 : 0.22),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              12, _tailHeight + 10, 14, 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 16,
                height: 16,
                // Nudged down so the badge centres on the first line of text
                // rather than on the top of its ascender.
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: _badgeOrange,
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: MyntWebTextStyles.body(
                        context,
                        // Bold only when it is heading a list; on its own it
                        // is just a sentence.
                        fontWeight: points.isEmpty
                            ? MyntFonts.regular
                            : MyntFonts.bold,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                      ),
                    ),
                    if (points.isNotEmpty) const SizedBox(height: 6),
                    for (final point in points)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              // Sits on the text's midline rather than its top.
                              margin: const EdgeInsets.only(top: 7, right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                _asListItem(point),
                                style: MyntWebTextStyles.bodySmall(
                                  context,
                                  fontWeight: MyntFonts.medium,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the card and its tail as ONE continuous outline.
///
/// The first version stacked a triangle on top of a bordered [Container],
/// which left the container's own top border running straight across the base
/// of the tail — the tail looked glued on instead of being part of the shape.
/// Tracing a single path avoids that seam entirely.
class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.fill,
    required this.stroke,
    required this.shadow,
  });

  final Color fill;
  final Color stroke;
  final Color shadow;

  Path _outline(Size size) {
    const r = _cornerRadius;
    const top = _tailHeight;
    final w = size.width;
    final h = size.height;

    return Path()
      ..moveTo(r, top)
      // Top edge, interrupted by the tail.
      ..lineTo(_tailInset, top)
      ..lineTo(_tailInset + _tailWidth / 2, 0)
      ..lineTo(_tailInset + _tailWidth, top)
      ..lineTo(w - r, top)
      ..arcToPoint(Offset(w, top + r), radius: const Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, top + r)
      ..arcToPoint(Offset(r, top), radius: const Radius.circular(r))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _outline(size);

    // Soft, tight drop shadow — a browser's popup sits just above the page,
    // it doesn't float like a dialog.
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.fill != fill || old.stroke != stroke || old.shadow != shadow;
}
