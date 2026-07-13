import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final Color? borderColor;
  /// Trigger height. Defaults to 40 (the scalper-settings size) but callers
  /// inside chip popovers pass a smaller value so the dropdown reads closer
  /// to a filter chip.
  final double height;
  const FilterSelect({
    super.key,
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
    this.borderColor,
    this.height = 40,
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
                                          ? resolveThemeColor(context, dark: MyntColors.secondaryDark, light: MyntColors.primary)
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
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: const Color(0xffB5C0CF).withValues(alpha: 0.15), light: const Color(0xFFF1F3F8)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: widget.borderColor ??
                  resolveThemeColor(context,
                      dark: MyntColors.borderMutedDark,
                      light: MyntColors.borderMuted)),
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
  /// Field height. Defaults to 40; smaller values are used inside chip
  /// popovers to keep the op + value pair compact.
  final double height;
  /// Character-level input filters. Null → free input. Numeric-only fields
  /// pass [TextInputValidators.signedDecimal] to block letters/symbols at
  /// the OS keystroke level so nothing invalid ever lands in the controller.
  final List<TextInputFormatter>? inputFormatters;
  const FilterTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.suffix,
    this.keyboardType,
    this.onChanged,
    this.height = 40,
    this.inputFormatters,
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
              dark: MyntColors.borderMutedDark,
              light: MyntColors.borderMuted)),
    );
    final valueStyle = MyntWebTextStyles.body(
      context,
      fontWeight: MyntFonts.medium,
    );
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: valueStyle,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: resolveThemeColor(context,
              dark: const Color(0xffB5C0CF).withValues(alpha: 0.15),
              light: const Color(0xFFF1F3F8)),
          hintText: hint,
          hintStyle: valueStyle.copyWith(color: secondary.withValues(alpha: 0.5)),
          suffixText: suffix,
          suffixStyle: valueStyle.copyWith(color: primary),
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

/// Shared input formatters used by the scanner's numeric filter fields.
/// Rejecting invalid characters at the OS keystroke level (via
/// `FilteringTextInputFormatter`) gives the same UX in both tabs and keeps
/// the value inputs unable to hold junk that later fails a Run scan.
class TextInputValidators {
  TextInputValidators._();

  /// Digits, decimal point, and a leading minus sign — the char set used by
  /// numeric price/ratio filters. Multi-`.` / multi-`-` inputs are still
  /// possible at the char level; the downstream `num.tryParse` guards the
  /// final value, so we don't over-engineer the regex here.
  static List<TextInputFormatter> signedDecimal() => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
      ];

  /// Digits only — used by year-count inputs where decimals/minus don't apply.
  static List<TextInputFormatter> digitsOnly() => [
        FilteringTextInputFormatter.digitsOnly,
      ];
}

/// Searchable multi-select (scalper-overlay style, matching [FilterSelect]) —
/// a boxed trigger showing "N selected" that opens an overlay with a search box
/// and a checkbox list. Used by the Sector / Industry filters, which build an
/// `in` filter from the checked values.
class FilterMultiSelect extends StatefulWidget {
  final List<String> options;
  final List<String> selected;
  final String hint;
  final ValueChanged<List<String>> onChanged;
  const FilterMultiSelect({
    super.key,
    required this.options,
    required this.selected,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<FilterMultiSelect> createState() => _FilterMultiSelectState();
}

class _FilterMultiSelectState extends State<FilterMultiSelect> {
  final GlobalKey _key = GlobalKey();
  final TextEditingController _search = TextEditingController();
  OverlayEntry? _overlay;
  late Set<String> _working;

  @override
  void dispose() {
    _remove();
    _search.dispose();
    super.dispose();
  }

  void _remove() {
    _overlay?.remove();
    _overlay = null;
  }

  void _toggle(String value) {
    if (_working.contains(value)) {
      _working.remove(value);
    } else {
      _working.add(value);
    }
    widget.onChanged(_working.toList());
    _overlay?.markNeedsBuild();
    if (mounted) setState(() {});
  }

  void _open() {
    if (_overlay != null) {
      _remove();
      setState(() {});
      return;
    }
    _working = {...widget.selected};
    _search.clear();
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
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    _overlay = OverlayEntry(
      builder: (_) {
        final q = _search.text.trim().toLowerCase();
        final filtered = q.isEmpty
            ? widget.options
            : widget.options
                .where((o) => o.toLowerCase().contains(q))
                .toList();
        final searchShape = OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: borderColor),
        );
        return Stack(children: [
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
                constraints: const BoxConstraints(maxHeight: 340),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _search,
                          autofocus: true,
                          style: MyntWebTextStyles.body(context),
                          onChanged: (_) => _overlay?.markNeedsBuild(),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixIcon:
                                Icon(Icons.search, size: 18, color: muted),
                            hintText: 'Search…',
                            hintStyle: MyntWebTextStyles.body(context,
                                color: muted.withValues(alpha: 0.6)),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            enabledBorder: searchShape,
                            focusedBorder: searchShape,
                            border: searchShape,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('No matches',
                                  style: MyntWebTextStyles.body(context,
                                      color: muted)),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final o in filtered)
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _toggle(o),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          child: Row(children: [
                                            Icon(
                                              _working.contains(o)
                                                  ? Icons.check_box
                                                  : Icons
                                                      .check_box_outline_blank,
                                              size: 18,
                                              color: _working.contains(o)
                                                  ? MyntColors.primary
                                                  : muted,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(o,
                                                  style:
                                                      MyntWebTextStyles.body(
                                                          context,
                                                          color: textColor),
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ),
                                          ]),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]);
      },
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
    final n = widget.selected.length;
    final label =
        n == 0 ? widget.hint : (n == 1 ? widget.selected.first : '$n selected');
    return GestureDetector(
      key: _key,
      onTap: _open,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: const Color(0xffB5C0CF).withValues(alpha: 0.15),
              light: const Color(0xFFF1F3F8)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: resolveThemeColor(context,
                  dark: MyntColors.borderMutedDark,
                  light: MyntColors.borderMuted)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium,
                    color: n == 0 ? muted : textColor),
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
