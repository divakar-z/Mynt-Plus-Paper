import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// One row in a [FilterSelect] — either a selectable item (`isHeader` false)
/// or a tinted group header (`isHeader` true, non-selectable).
class FilterSelectOption {
  final String value;
  final String label;
  final bool isHeader;
  const FilterSelectOption(this.value, this.label, {this.isHeader = false});
}

/// Scalper-settings-style dropdown: a boxed trigger (light fill, primary
/// border, chevron) that opens an overlay panel (rounded, shadow) with the
/// selected option in brand-blue and a hover highlight — matching the scalper
/// Default-Strike dropdowns. Shared by the fundamental filter rows and the
/// Sort / Dir controls in the bottom toolbar.
class FilterSelect extends StatefulWidget {
  final String? value;
  final String hint;
  final List<FilterSelectOption> options;
  final ValueChanged<String> onChanged;
  const FilterSelect({
    super.key,
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
  });

  @override
  State<FilterSelect> createState() => _FilterSelectState();
}

class _FilterSelectState extends State<FilterSelect> {
  final GlobalKey _key = GlobalKey();
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  void _remove() {
    _overlay?.remove();
    _overlay = null;
  }

  String? get _label {
    for (final o in widget.options) {
      if (!o.isHeader && o.value == widget.value) return o.label;
    }
    return null;
  }

  void _toggle() {
    if (_overlay != null) {
      _remove();
      setState(() {});
      return;
    }
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MyntColors.overlayBgDark : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final tint = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    _overlay = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _remove();
              if (mounted) setState(() {});
            },
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: pos.dx,
          top: pos.dy + size.height + 4,
          width: size.width,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(6),
            color: bg,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final o in widget.options)
                        if (o.isHeader)
                          Container(
                            color: tint,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Text(o.label.toUpperCase(),
                                style: MyntWebTextStyles.caption(context,
                                        fontWeight: MyntFonts.semiBold,
                                        color: tertiary)
                                    .copyWith(letterSpacing: 1.0)),
                          )
                        else
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                widget.onChanged(o.value);
                                _remove();
                                if (mounted) setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Text(
                                  o.label,
                                  style: MyntWebTextStyles.body(context,
                                      fontWeight: o.value == widget.value
                                          ? MyntFonts.semiBold
                                          : MyntFonts.medium,
                                      color: o.value == widget.value
                                          ? MyntColors.primary
                                          : textColor),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final label = _label;
    return GestureDetector(
      key: _key,
      onTap: _toggle,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: Colors.transparent, light: const Color(0xFFF1F3F8)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: resolveThemeColor(context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.primary)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label ?? widget.hint,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium,
                    color: label == null ? muted : textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down, size: 20, color: muted),
          ],
        ),
      ),
    );
  }
}

/// Value field styled to match `MyntFormTextField` (light fill, primary border,
/// r5, 40px) but with a `suffixText` slot so a unit ("%") sits cleanly inside
/// the field, centered, with space reserved so it never overlaps the value.
class FilterTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  const FilterTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.suffix,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final shape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: BorderSide(
          color: resolveThemeColor(context,
              dark: MyntColors.textSecondaryDark, light: MyntColors.primary)),
    );
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: MyntWebTextStyles.body(context),
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: resolveThemeColor(context,
              dark: const Color(0xffB5C0CF).withValues(alpha: 0.15),
              light: const Color(0xFFF1F3F8)),
          hintText: hint,
          hintStyle: MyntWebTextStyles.body(context,
              color: secondary.withValues(alpha: 0.5)),
          suffixText: suffix,
          suffixStyle: MyntWebTextStyles.body(context, color: primary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: shape,
          focusedBorder: shape,
          border: shape,
        ),
      ),
    );
  }
}
