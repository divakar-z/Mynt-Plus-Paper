import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

class QtySelectorPopup extends StatefulWidget {
  final Offset anchor;
  final int initialQty;
  final int lotSize;
  final int? lastUsed;
  final ValueChanged<int> onCommit;
  final VoidCallback onDismiss;

  const QtySelectorPopup({
    super.key,
    required this.anchor,
    required this.initialQty,
    required this.lotSize,
    required this.onCommit,
    required this.onDismiss,
    this.lastUsed,
  });

  @override
  State<QtySelectorPopup> createState() => _QtySelectorPopupState();
}

class _QtySelectorPopupState extends State<QtySelectorPopup> {
  late final TextEditingController _ctl;
  late int _qty;
  final List<int> _multipliers = const [1, 2, 5, 10, 25, 50, 100, 500];

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty;
    _ctl = TextEditingController(text: _qty.toString());
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  int _roundToLot(int v) {
    final ls = widget.lotSize > 0 ? widget.lotSize : 1;
    final stepped = ((v / ls).round()).clamp(1, 1 << 30) * ls;
    return stepped;
  }

  void _set(int v) {
    final r = _roundToLot(v);
    setState(() {
      _qty = r;
      _ctl.text = r.toString();
    });
    widget.onCommit(r);
  }

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final accent = resolveThemeColor(context,
        dark: MyntColors.secondary, light: MyntColors.primary);
    final mute = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    final screen = MediaQuery.of(context).size;
    const w = 260.0;
    final left = widget.anchor.dx.clamp(8.0, screen.width - w - 8.0);
    final top = widget.anchor.dy.clamp(8.0, screen.height - 240.0);

    Widget stepBtn({
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: mute),
          ),
        ),
      );
    }

    Widget presetChip(int m) {
      final qty = m * widget.lotSize;
      final selected = qty == _qty;
      final label = widget.lotSize == 1 ? '$m' : '${m}x';
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _set(qty),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              border: Border.all(
                  color: selected ? accent : border),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: MyntWebTextStyles.caption(context,
                  color: selected ? Colors.white : mute,
                  fontWeight: MyntFonts.medium),
            ),
          ),
        ),
      );
    }

    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
          ),
        ),
      ),
      Positioned(
        left: left,
        top: top,
        width: w,
        child: PointerInterceptor(
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row 1: qty input flanked by - / + step buttons.
                  Row(children: [
                    stepBtn(
                      icon: Icons.remove,
                      onTap: () => _set(_qty - widget.lotSize),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Align(
                          alignment: Alignment.center,
                          child: TextField(
                          controller: _ctl,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          textAlign: TextAlign.center,
                          style: MyntWebTextStyles.body(context,
                              fontWeight: MyntFonts.semiBold)
                                .copyWith(height: 1.0),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 0),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          onSubmitted: (s) {
                            final v = int.tryParse(s) ?? _qty;
                            _set(v);
                            widget.onDismiss();
                          },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    stepBtn(
                      icon: Icons.add,
                      onTap: () => _set(_qty + widget.lotSize),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  // Row 2: lot-size hint + reset/last quick actions.
                  Row(children: [
                    Expanded(
                      child: Text(
                        widget.lotSize > 1
                            ? 'Lot ${widget.lotSize}'
                            : 'Step 1',
                        style: MyntWebTextStyles.caption(context, color: mute),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _set(widget.lotSize),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.refresh, size: 16, color: mute),
                      ),
                    ),
                    if (widget.lastUsed != null)
                      GestureDetector(
                        onTap: () => _set(widget.lastUsed!),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.history, size: 16, color: mute),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  // Row 3: 4x2 grid of multiplier presets.
                  GridView.count(
                    crossAxisCount: 4,
                    childAspectRatio: 1.9,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [for (final m in _multipliers) presetChip(m)],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
