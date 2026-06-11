import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Paints a persistent yellow background + border over every tappable
/// element (buttons, links) in the tree while the "Highlight Links"
/// accessibility toggle is on. Uses the semantics tree so the overlay
/// automatically covers every framework widget that advertises a button
/// or link role — no per-widget adoption required.
class HighlightLinksOverlay extends StatefulWidget {
  const HighlightLinksOverlay({
    super.key,
    required this.enabled,
    required this.child,
    this.background = const Color(0x66FFEB3B),
    this.border = const Color(0xFFF9A825),
    this.borderWidth = 1.5,
    this.radius = 4,
  });

  final bool enabled;
  final Widget child;
  final Color background;
  final Color border;
  final double borderWidth;
  final double radius;

  @override
  State<HighlightLinksOverlay> createState() => _HighlightLinksOverlayState();
}

class _HighlightLinksOverlayState extends State<HighlightLinksOverlay> {
  SemanticsHandle? _semanticsHandle;
  List<Rect> _rects = const <Rect>[];
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _attach();
  }

  @override
  void didUpdateWidget(covariant HighlightLinksOverlay old) {
    super.didUpdateWidget(old);
    if (widget.enabled == old.enabled) return;
    widget.enabled ? _attach() : _detach();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _attach() {
    _semanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
    // Persistent frame callback so we pick up semantics changes as they
    // happen (scroll, dialog open/close, navigation) without polling.
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
    _schedule();
  }

  void _detach() {
    _semanticsHandle?.dispose();
    _semanticsHandle = null;
    if (mounted && _rects.isNotEmpty) {
      setState(() => _rects = const <Rect>[]);
    }
  }

  void _onFrame(Duration _) {
    if (!widget.enabled) return;
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _recompute();
    });
  }

  void _recompute() {
    if (!mounted || !widget.enabled) return;
    final host = context.findRenderObject();
    if (host is! RenderBox || !host.attached) return;

    final next = <Rect>[];
    try {
      for (final view in RendererBinding.instance.renderViews) {
        final root = view.owner?.semanticsOwner?.rootSemanticsNode;
        if (root == null) continue;
        _collect(root, Matrix4.identity(), next);
      }
    } catch (_) {
      // Semantics tree mid-rebuild — drop this frame.
      return;
    }

    final origin = host.localToGlobal(Offset.zero);
    final local = <Rect>[for (final r in next) r.shift(-origin)];

    if (_listEquals(local, _rects)) return;
    setState(() => _rects = local);
  }

  void _collect(SemanticsNode node, Matrix4 parentT, List<Rect> out) {
    final t = parentT.clone();
    if (node.transform != null) t.multiply(node.transform!);

    final data = node.getSemanticsData();
    if (!data.flagsCollection.isHidden && _tappable(data)) {
      final rect = MatrixUtils.transformRect(t, node.rect);
      if (_reasonablySized(rect)) out.add(rect);
    }

    node.visitChildren((child) {
      _collect(child, t, out);
      return true;
    });
  }

  /// A node counts as "a link" if the framework flagged it as a button/link,
  /// OR it advertises a tap action (which is what GestureDetector.onTap sets
  /// — that's how this app builds its header nav, tabs, cards, and most
  /// "See all" / "Add Money" / "Insights" taps). Excludes the implicit tap
  /// action auto-added to text fields so we don't outline every input.
  bool _tappable(SemanticsData data) {
    if (data.flagsCollection.isButton || data.flagsCollection.isLink) {
      return true;
    }
    if (data.flagsCollection.isTextField) return false;
    return (data.actions & SemanticsAction.tap.index) != 0;
  }

  /// Skip full-page tap surfaces (scaffold/backdrops/scrollables with an
  /// onTap) so the overlay doesn't paint a sheet of yellow over the whole
  /// screen. 480x480 is larger than any real button/link but smaller than
  /// any container-level tap target we'd want to ignore.
  bool _reasonablySized(Rect r) {
    if (!r.isFinite || r.isEmpty) return false;
    if (r.width > 480 || r.height > 480) return false;
    return true;
  }

  bool _listEquals(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.enabled && _rects.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HighlightPainter(
                  rects: _rects,
                  background: widget.background,
                  border: widget.border,
                  borderWidth: widget.borderWidth,
                  radius: widget.radius,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter({
    required this.rects,
    required this.background,
    required this.border,
    required this.borderWidth,
    required this.radius,
  });

  final List<Rect> rects;
  final Color background;
  final Color border;
  final double borderWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..style = PaintingStyle.fill
      ..color = background;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = border;
    final r = Radius.circular(radius);

    for (final rect in rects) {
      final rr = RRect.fromRectAndRadius(rect, r);
      canvas.drawRRect(rr, bg);
      canvas.drawRRect(rr, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter old) =>
      old.rects != rects ||
      old.background != background ||
      old.border != border ||
      old.borderWidth != borderWidth ||
      old.radius != radius;
}
