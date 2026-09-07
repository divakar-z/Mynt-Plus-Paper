import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';

/// Layout picker — button with the current-layout glyph; popup shows all
/// available layouts grouped by pane count (1, 2, 3, 4, 5, 6).
class LayoutPicker extends ConsumerStatefulWidget {
  final ValueChanged<bool> onPopupVisibilityChanged;
  const LayoutPicker({super.key, required this.onPopupVisibilityChanged});

  @override
  ConsumerState<LayoutPicker> createState() => _LayoutPickerState();
}

class _LayoutPickerState extends ConsumerState<LayoutPicker> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _open() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _build);
    Overlay.of(context).insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    widget.onPopupVisibilityChanged(true);
  }

  @override
  void dispose() {
    if (_entry != null) {
      _entry!.remove();
      widget.onPopupVisibilityChanged(true);
    }
    super.dispose();
  }

  Widget _build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final current = ref.read(chartEngineSessionProvider).layout;
    final notifier = ref.read(chartEngineSessionProvider.notifier);

    // Group all layouts by paneCount (1..6).
    final groups = <int, List<ChartLayout>>{};
    for (final l in ChartLayout.values) {
      groups.putIfAbsent(l.paneCount, () => []).add(l);
    }
    final orderedCounts = groups.keys.toList()..sort();

    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
      ),
      Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(0, 38),
          child: PointerInterceptor(
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final count in orderedCounts)
                      _Row(
                        label: count.toString(),
                        layouts: groups[count]!,
                        current: current,
                        onPicked: (l) {
                          notifier.setLayout(l);
                          _close();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(chartEngineSessionProvider).layout;
    // OverlayEntry doesn't auto-rebuild when our parent (provider listener)
    // notifies; markNeedsBuild here keeps the selected-state highlight in
    // sync if the layout is changed from elsewhere while the popup is open.
    _entry?.markNeedsBuild();
    final border = shadcn.Theme.of(context).colorScheme.border;
    return CompositedTransformTarget(
      link: _link,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _entry == null ? _open() : _close(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
                painter: _LayoutGlyph(current, _glyphColor(context))),
          ),
        ),
      ),
    );
  }
}

Color _glyphColor(BuildContext ctx) => resolveThemeColor(ctx,
    dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
Color _accent(BuildContext ctx) => resolveThemeColor(ctx,
    dark: MyntColors.primaryDark, light: MyntColors.primary);

class _Row extends StatelessWidget {
  final String label;
  final List<ChartLayout> layouts;
  final ChartLayout current;
  final ValueChanged<ChartLayout> onPicked;
  const _Row({
    required this.label,
    required this.layouts,
    required this.current,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(children: [
        SizedBox(
          width: 16,
          child: Text(label,
              style: TextStyle(
                fontSize: 11,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
              )),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final l in layouts)
                _Icon(
                  layout: l,
                  selected: l == current,
                  onTap: () => onPicked(l),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Icon extends StatelessWidget {
  final ChartLayout layout;
  final bool selected;
  final VoidCallback onTap;
  const _Icon({
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 32,
        height: 28,
        decoration: BoxDecoration(
          color: selected
              ? _accent(context).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? _accent(context) : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: CustomPaint(
          painter: _LayoutGlyph(layout,
              selected ? _accent(context) : _glyphColor(context)),
        ),
      ),
    );
  }
}

/// Parses a layout's grid-template-areas string and paints a miniature of
/// the layout. Each unique area letter is rendered as one stroked rectangle
/// covering its bounding box in the grid.
class _LayoutGlyph extends CustomPainter {
  final ChartLayout layout;
  final Color color;
  _LayoutGlyph(this.layout, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Parse areas: e.g. '"a a" "b c"' -> [['a','a'],['b','c']].
    final rows = <List<String>>[];
    final raw = layout.areas;
    final quoted = RegExp(r'"([^"]+)"').allMatches(raw);
    for (final m in quoted) {
      rows.add(m.group(1)!.trim().split(RegExp(r'\s+')));
    }
    if (rows.isEmpty) return;
    final rowCount = rows.length;
    final colCount = rows[0].length;
    final cellW = size.width / colCount;
    final cellH = size.height / rowCount;

    final seen = <String, Rect>{};
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < colCount; c++) {
        final letter = rows[r][c];
        final left = c * cellW;
        final top = r * cellH;
        final right = (c + 1) * cellW;
        final bottom = (r + 1) * cellH;
        final existing = seen[letter];
        if (existing == null) {
          seen[letter] = Rect.fromLTRB(left, top, right, bottom);
        } else {
          seen[letter] = Rect.fromLTRB(
            existing.left < left ? existing.left : left,
            existing.top < top ? existing.top : top,
            existing.right > right ? existing.right : right,
            existing.bottom > bottom ? existing.bottom : bottom,
          );
        }
      }
    }

    for (final rect in seen.values) {
      final inset = rect.deflate(1.0);
      canvas.drawRect(inset, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutGlyph old) =>
      old.layout != layout || old.color != color;
}
