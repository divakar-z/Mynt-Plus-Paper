import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Paints a high-contrast ring around the widget currently holding primary
/// focus OR the nearest tappable widget under the mouse cursor. Satisfies
/// WCAG 2.4.7 (Focus Visible). On Flutter web InkWell/GestureDetector do not
/// normally claim keyboard focus on click, so we also semantics-hit-test the
/// pointer position and ring the smallest tappable node we find there — this
/// matches the visible-hover behaviour expected by accessibility users.
class FocusIndicatorOverlay extends StatefulWidget {
  const FocusIndicatorOverlay({
    super.key,
    required this.enabled,
    required this.child,
    this.color = const Color(0xFF1976D2),
    this.thickness = 2.5,
    this.radius = 8,
  });

  final bool enabled;
  final Widget child;
  final Color color;
  final double thickness;
  final double radius;

  @override
  State<FocusIndicatorOverlay> createState() => _FocusIndicatorOverlayState();
}

class _FocusIndicatorOverlayState extends State<FocusIndicatorOverlay> {
  // Cap the hover hit-test (a semantics-tree walk in _recomputeHover) to at
  // most once per this window. Pointer moves fire up to once per frame
  // (~60x/sec) during a drag; throttling cuts that ~6x. 100ms keeps the ring
  // feeling responsive, and a trailing pass lands it exactly when the cursor
  // stops.
  static const Duration _hoverThrottle = Duration(milliseconds: 100);

  Rect? _focusRect;
  Rect? _hoverRect;
  Offset? _lastPointer;
  bool _hoverScheduled = false;
  final Stopwatch _sinceLastHover = Stopwatch();
  Timer? _hoverTrailingTimer;
  SemanticsHandle? _semanticsHandle;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _attach();
  }

  @override
  void didUpdateWidget(covariant FocusIndicatorOverlay old) {
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
    // Enable semantics so the hover/focus hit-test against the semantics
    // tree can find tappable buttons and links. The TradingView chart
    // panels already wrap their HtmlElementView with `excludeSemantics:
    // true`, so the platform-view pointer pipeline stays intact.
    _semanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
    FocusManager.instance.addListener(_scheduleFocus);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _scheduleFocus();
  }

  void _detach() {
    _hoverTrailingTimer?.cancel();
    _hoverTrailingTimer = null;
    _sinceLastHover
      ..stop()
      ..reset();
    FocusManager.instance.removeListener(_scheduleFocus);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _semanticsHandle?.dispose();
    _semanticsHandle = null;
    if (mounted && (_focusRect != null || _hoverRect != null)) {
      setState(() {
        _focusRect = null;
        _hoverRect = null;
      });
    }
  }

  void _onPointer(PointerEvent e) {
    if (!widget.enabled) return;
    if (e is PointerHoverEvent ||
        e is PointerMoveEvent ||
        e is PointerDownEvent) {
      _lastPointer = e.position;
      _scheduleHover();
    }
  }

  void _scheduleFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeFocus());
  }

  // Leading-edge throttle: the first move after an idle gap recomputes right
  // away; moves inside the window are coalesced into one trailing recompute so
  // the ring still lands on the element the cursor finally rests on.
  void _scheduleHover() {
    final elapsed = _sinceLastHover.elapsed;
    if (!_sinceLastHover.isRunning || elapsed >= _hoverThrottle) {
      _runHoverRecompute();
    } else {
      _scheduleHoverTrailing(_hoverThrottle - elapsed);
    }
  }

  void _runHoverRecompute() {
    _sinceLastHover
      ..reset()
      ..start();
    _hoverTrailingTimer?.cancel();
    _hoverTrailingTimer = null;
    if (_hoverScheduled) return;
    _hoverScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hoverScheduled = false;
      _recomputeHover();
    });
  }

  void _scheduleHoverTrailing(Duration delay) {
    if (_hoverTrailingTimer != null) return;
    _hoverTrailingTimer = Timer(delay, () {
      _hoverTrailingTimer = null;
      if (!mounted || !widget.enabled) return;
      _runHoverRecompute();
    });
  }

  void _recomputeFocus() {
    if (!mounted || !widget.enabled) return;
    final focusCtx = FocusManager.instance.primaryFocus?.context;
    final target = focusCtx?.findRenderObject();
    final host = context.findRenderObject();
    if (target is! RenderBox ||
        host is! RenderBox ||
        !target.attached ||
        !host.attached ||
        !target.hasSize) {
      if (_focusRect != null) setState(() => _focusRect = null);
      return;
    }
    final topLeft = target.localToGlobal(Offset.zero, ancestor: host);
    final next = topLeft & target.size;
    if (next != _focusRect) setState(() => _focusRect = next);
  }

  void _recomputeHover() {
    if (!mounted || !widget.enabled) return;
    final pointer = _lastPointer;
    if (pointer == null) return;
    final globalRect = _hitTappable(pointer);
    final host = context.findRenderObject();
    if (host is! RenderBox || !host.attached) return;
    if (globalRect == null) {
      if (_hoverRect != null) setState(() => _hoverRect = null);
      return;
    }
    final origin = host.localToGlobal(Offset.zero);
    final next = globalRect.shift(-origin);
    if (next != _hoverRect) setState(() => _hoverRect = next);
  }

  Rect? _hitTappable(Offset globalPos) {
    try {
      for (final view in RendererBinding.instance.renderViews) {
        final root = view.owner?.semanticsOwner?.rootSemanticsNode;
        if (root == null) continue;
        final r = _visit(root, globalPos, Matrix4.identity());
        if (r != null) return r;
      }
    } catch (_) {
      // Semantics tree mid-rebuild — drop this frame, next hover retries.
    }
    return null;
  }

  Rect? _visit(SemanticsNode node, Offset pos, Matrix4 parentT) {
    final t = parentT.clone();
    if (node.transform != null) t.multiply(node.transform!);
    final rect = MatrixUtils.transformRect(t, node.rect);
    if (!rect.contains(pos)) return null;

    Rect? deeper;
    node.visitChildren((child) {
      final found = _visit(child, pos, t);
      if (found != null) {
        deeper = found;
        return false;
      }
      return true;
    });
    if (deeper != null) return deeper;
    if (_tappable(node)) return rect;
    return null;
  }

  /// Only ring real buttons and links — not generic tappable containers,
  /// list rows, or scroll surfaces. Framework widgets (ElevatedButton,
  /// TextButton, IconButton, InkResponse, shadcn buttons, MaterialBanner
  /// actions, Dialog actions, Links) all set one of these flags.
  bool _tappable(SemanticsNode node) {
    final flags = node.getSemanticsData().flagsCollection;
    return flags.isButton || flags.isLink;
  }

  @override
  Widget build(BuildContext context) {
    final rect = _focusRect ?? _hoverRect;
    return Stack(
      children: [
        widget.child,
        if (widget.enabled && rect != null)
          Positioned.fromRect(
            rect: rect.inflate(widget.thickness + 1),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: Border.all(
                    color: widget.color,
                    width: widget.thickness,
                  ),
                  color: widget.color.withValues(alpha: 0.10),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.30),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
