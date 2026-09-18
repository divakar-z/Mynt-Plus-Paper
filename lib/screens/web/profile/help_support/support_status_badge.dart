import 'package:flutter/material.dart';

import '../../../../res/mynt_web_text_styles.dart';

/// The two colours a status badge is drawn in, plus its variant.
class _StatusStyle {
  const _StatusStyle(this.background, this.ink,
      {this.outlined = false, this.strikethrough = false, this.border});

  final Color background;
  final Color ink;

  /// Outline variants have a transparent fill and a dashed edge.
  final bool outlined;
  final bool strikethrough;
  final Color? border;
}

/// A ticket status, drawn to the support design spec.
///
/// One label, two colours — every badge is otherwise identical.
///
/// Statuses are **admin-editable strings**, so the lookup below is a display
/// mapping, not a classification: an unrecognised value falls through to the
/// neutral "closed / unknown" pair rather than being guessed at. A status the
/// helpdesk adds tomorrow renders correctly-shaped and uncoloured instead of
/// breaking the row.
class SupportStatusBadge extends StatelessWidget {
  const SupportStatusBadge(this.status, {super.key, this.dense = false});

  final String? status;

  /// Tighter padding for a table row, where the badge sits in a 42px cell.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final label = (status ?? '').trim().isEmpty ? 'Unknown' : status!.trim();
    final style = _styleFor(label, _isDark(context));

    // Outline variants trade a pixel of padding each side for the border they
    // gain, so both kinds end up the same box.
    final padding = style.outlined
        ? EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 2 : 3)
        : EdgeInsets.symmetric(horizontal: dense ? 9 : 11, vertical: dense ? 3 : 4);

    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: MyntWebTextStyles.body(
        context,
        fontWeight: MyntFonts.semiBold,
        color: style.ink,
      ).copyWith(
        fontSize: 12,
        height: 16 / 12,
        decoration:
            style.strikethrough ? TextDecoration.lineThrough : TextDecoration.none,
        decorationColor: style.ink,
      ),
    );

    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: text,
    );

    if (!style.outlined) return box;

    // Dashed, and painted over the child rather than under it — Flutter's
    // Border has no dash support, so the edge is drawn by hand.
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: style.border ?? style.ink,
        radius: 6,
      ),
      child: box,
    );
  }

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Normalised so the spec's own spellings all land.
  ///
  /// `Re-Open`, `re open` and `REOPEN` are one status; `In Progress` and
  /// `in_progress` are another. Case, spaces, hyphens and underscores are all
  /// dropped before matching, because the API returns whatever an admin typed.
  static String _key(String status) =>
      status.toLowerCase().replaceAll(RegExp(r'[\s\-_/]+'), '');

  static _StatusStyle _styleFor(String status, bool dark) {
    final key = _key(status);

    if (dark) {
      switch (key) {
        case 'escalated':
        case 'overdue':
          return const _StatusStyle(Color(0xFF3A1D24), Color(0xFFE79AA9));
        case 'unassigned':
          return const _StatusStyle(Color(0xFF272040), Color(0xFFBFA9F0));
        case 'reopen':
          return const _StatusStyle(Color(0xFF3A2033), Color(0xFFE59DCE));
        case 'reopened':
          return const _StatusStyle(Color(0xFF3A241C), Color(0xFFE8AC90));
        case 'new':
          return const _StatusStyle(Color(0xFF1B203C), Color(0xFFA1AEEE));
        case 'open':
          return const _StatusStyle(Color(0xFF16263C), Color(0xFF8CB6E8));
        case 'inprogress':
          return const _StatusStyle(Color(0xFF33260F), Color(0xFFE0AC62));
        case 'pending':
          return const _StatusStyle(Color(0xFF302A12), Color(0xFFD8BE6C));
        case 'answered':
          return const _StatusStyle(Color(0xFF11292F), Color(0xFF7EC0CF));
        case 'resolved':
          return const _StatusStyle(Color(0xFF14291D), Color(0xFF77C795));
        case 'completed':
        case 'complete':
          return const _StatusStyle(Color(0xFF2A2620), Color(0xFFC4B392));
        case 'archived':
          return const _StatusStyle(Colors.transparent, Color(0xFF8B949E),
              outlined: true, border: Color(0xFF3D444D));
        case 'deleted':
          return const _StatusStyle(Colors.transparent, Color(0xFF8B949E),
              outlined: true, strikethrough: true, border: Color(0xFF3D444D));
        default:
          // Closed, and anything the helpdesk invents later.
          return const _StatusStyle(Color(0xFF21262D), Color(0xFF9BA5B4));
      }
    }

    switch (key) {
      case 'escalated':
      case 'overdue':
        return const _StatusStyle(Color(0xFFF7E9EC), Color(0xFF7B2233));
      case 'unassigned':
        return const _StatusStyle(Color(0xFFF2EDFA), Color(0xFF5B41A6));
      case 'reopen':
        return const _StatusStyle(Color(0xFFF9EBF3), Color(0xFF86306A));
      case 'reopened':
        return const _StatusStyle(Color(0xFFFAEBE6), Color(0xFF8A452C));
      case 'new':
        return const _StatusStyle(Color(0xFFE9EEFB), Color(0xFF31418F));
      case 'open':
        return const _StatusStyle(Color(0xFFEAF1FA), Color(0xFF245086));
      case 'inprogress':
        return const _StatusStyle(Color(0xFFFBF0E2), Color(0xFF8C551D));
      case 'pending':
        return const _StatusStyle(Color(0xFFFAF3E1), Color(0xFF836223));
      case 'answered':
        return const _StatusStyle(Color(0xFFE6F1F4), Color(0xFF1C5A6B));
      case 'resolved':
        return const _StatusStyle(Color(0xFFE7F2EA), Color(0xFF276B48));
      case 'completed':
      case 'complete':
        return const _StatusStyle(Color(0xFFF7F4EE), Color(0xFF6B5836));
      case 'archived':
        return const _StatusStyle(Colors.transparent, Color(0xFF5F6773),
            outlined: true, border: Color(0xFFD3D7DD));
      case 'deleted':
        return const _StatusStyle(Colors.transparent, Color(0xFF5F6773),
            outlined: true, strikethrough: true, border: Color(0xFFD3D7DD));
      default:
        return const _StatusStyle(Color(0xFFEDEFF2), Color(0xFF4C5462));
    }
  }
}

/// A 1px dashed rounded rectangle: 3px on, 3px off.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _on = 3;
  static const double _off = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Inset by half the stroke so the line sits inside the box rather than
    // straddling its edge, which would clip to half a pixel on both sides.
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.5);

    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _on).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _off;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
