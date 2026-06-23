import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// Preset timeframes (label → minutes). The "Custom…" entry opens a small
/// dialog so users can enter any positive integer minutes value.
const Map<String, int> kPresetTimeframes = {
  '1m': 1,
  '2m': 2,
  '3m': 3,
  '5m': 5,
  '10m': 10,
  '15m': 15,
  '30m': 30,
  '1h': 60,
  '2h': 120,
  '4h': 240,
  '1D': 1440,
  '1W': 10080,
  '1M': 43200,
};

/// Returns the human label for an integer minute count, falling back to
/// `<n>m` / `<n>h` / `<n>D` formats for custom values.
String formatTimeframeLabel(int minutes) {
  for (final e in kPresetTimeframes.entries) {
    if (e.value == minutes) return e.key;
  }
  if (minutes % 1440 == 0) return '${minutes ~/ 1440}D';
  if (minutes % 60 == 0) return '${minutes ~/ 60}h';
  return '${minutes}m';
}

class TimeframePicker extends StatefulWidget {
  final int valueMinutes;
  final ValueChanged<int> onChanged;
  final ValueChanged<bool> onPopupVisibilityChanged;
  const TimeframePicker({
    super.key,
    required this.valueMinutes,
    required this.onChanged,
    required this.onPopupVisibilityChanged,
  });

  @override
  State<TimeframePicker> createState() => _TimeframePickerState();
}

class _TimeframePickerState extends State<TimeframePicker> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _open() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _buildOverlay);
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

  Future<void> _pickCustom() async {
    _close();
    final ctl = TextEditingController();
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom timeframe'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Minutes (e.g. 7 for 7m, 90 for 90m)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(ctl.text.trim());
              if (n != null && n > 0) Navigator.pop(ctx, n);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (picked != null) widget.onChanged(picked);
  }

  Widget _buildOverlay(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final hover = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
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
        width: 140,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in kPresetTimeframes.entries)
                      InkWell(
                        onTap: () {
                          widget.onChanged(e.value);
                          _close();
                        },
                        hoverColor: hover,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Row(children: [
                            Expanded(
                                child: Text(e.key,
                                    style: MyntWebTextStyles.body(context))),
                            if (e.value == widget.valueMinutes)
                              Icon(shadcn.LucideIcons.check,
                                  size: 14,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.primaryDark,
                                      light: MyntColors.primary)),
                          ]),
                        ),
                      ),
                    const Divider(height: 1),
                    InkWell(
                      onTap: _pickCustom,
                      hoverColor: hover,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Text('Custom…',
                            style: MyntWebTextStyles.body(context,
                                fontWeight: MyntFonts.semiBold)),
                      ),
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
    final border = shadcn.Theme.of(context).colorScheme.border;
    return CompositedTransformTarget(
      link: _link,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _entry == null ? _open() : _close(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(formatTimeframeLabel(widget.valueMinutes),
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold)),
            const SizedBox(width: 6),
            Icon(shadcn.LucideIcons.chevronDown, size: 14),
          ]),
        ),
      ),
    );
  }
}
