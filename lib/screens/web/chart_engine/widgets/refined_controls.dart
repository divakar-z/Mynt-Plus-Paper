import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

// Refined trading-terminal control kit shared between the top-bar popovers
// and the per-indicator settings dialog. The visual language follows the
// gear-icon settings dialog (TradingView × Linear) so all popovers feel
// like one product. Keeping these widgets private to the chart_engine
// widgets folder so they evolve with the chart and don't leak into the
// rest of the app.

/// The card surface used by every popover. Keeps the dark-1F2937 1px border,
/// 12px radius, and 32px-blur drop shadow consistent across all popups.
class RefinedPopoverCard extends StatelessWidget {
  final Widget child;
  final double width;
  const RefinedPopoverCard({
    super.key,
    required this.child,
    this.width = 340,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    // Cap card height to 78% of the viewport so long bodies (Settings →
    // View on chart has 11 rows) become scrollable instead of clipping
    // below the screen edge. The inner ClipRRect-wrapped child renders
    // inside a SingleChildScrollView so the user can reach every row.
    final maxH = MediaQuery.of(context).size.height * 0.78;
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxH),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Header block: a 18-20px semi-bold title with an optional muted subtitle and
/// optional trailing close button. Sits above the tab strip / body.
class RefinedPopoverHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final Widget? trailing;
  const RefinedPopoverHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: MyntWebTextStyles.head(context,
                        fontWeight: MyntFonts.semiBold)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!,
                      style: MyntWebTextStyles.caption(context, color: muted)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (onClose != null)
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, size: 16, color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Underline-on-active tab strip used at the top of multi-tab popovers.
/// Active chip is MyntColors.primary; inactive is muted. Underline animates
/// with AnimatedContainer (180ms ease).
class RefinedTabStrip extends StatelessWidget {
  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;
  const RefinedTabStrip({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final mute = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final divider = _dividerColor(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: SizedBox(
        height: 40,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _TabChip(
                  label: tabs[i],
                  selected: i == activeIndex,
                  accent: accent,
                  muted: mute,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color muted;
  final VoidCallback onTap;
  const _TabChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.muted,
    required this.onTap,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? widget.accent : widget.muted;
    final hoverColor = widget.selected
        ? widget.accent
        : (resolveThemeColor(context,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 140),
                style: MyntWebTextStyles.bodySmall(
                  context,
                  fontWeight: widget.selected
                      ? MyntFonts.semiBold
                      : MyntFonts.medium,
                  darkColor: _hover ? hoverColor : color,
                  lightColor: _hover ? hoverColor : color,
                ),
                child: Text(widget.label),
              ),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 2,
                width: widget.selected ? 28 : 0,
                decoration: BoxDecoration(
                  color: widget.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical body row: [label + optional description on the left, control on
/// right]. Used for toggles, steppers, color buttons, segmented selectors.
/// Hover-lifts to indicate interactivity when `onTap` is supplied.
class RefinedRow extends StatefulWidget {
  final String label;
  final String? description;
  final Widget control;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  const RefinedRow({
    super.key,
    required this.label,
    this.description,
    required this.control,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 16, 12),
  });

  @override
  State<RefinedRow> createState() => _RefinedRowState();
}

class _RefinedRowState extends State<RefinedRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final inner = Container(
      // Instant hover swap — animating bg colour leaves a multi-row trail
      // when the user moves through the list quickly. Hover state changes
      // are visible-enough without the 140ms tween.
      color: widget.onTap != null && _hover
          ? hoverBg.withValues(alpha: 0.5)
          : Colors.transparent,
      padding: widget.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label,
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.semiBold)),
                if (widget.description != null) ...[
                  const SizedBox(height: 2),
                  Text(widget.description!,
                      style:
                          MyntWebTextStyles.caption(context, color: muted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          widget.control,
        ],
      ),
    );
    final child = MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.onTap == null
          ? inner
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: inner,
            ),
    );
    return child;
  }
}

/// 1px hairline divider used between every body row.
class RefinedDivider extends StatelessWidget {
  const RefinedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: _dividerColor(context));
  }
}

Color _dividerColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9);
}

/// Compact switch styled to match the refined surface. Wrapper keeps the
/// thumb sized down so it sits cleanly in a 36px row.
class RefinedSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const RefinedSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return SizedBox(
      height: 24,
      child: Transform.scale(
        scale: 0.78,
        alignment: Alignment.centerRight,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: accent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// 36px bordered numeric stepper: [−][value][+]. Same look as the per-
/// indicator dialog's `_PeriodStepper`.
class RefinedStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double width;
  const RefinedStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
    this.width = 124,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2030) : const Color(0xFFF8FAFC);
    final stroke =
        isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);
    final iconColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Container(
      width: width,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: stroke, width: 1),
      ),
      child: Row(
        children: [
          _StepperButton(
            icon: Icons.remove,
            color: iconColor,
            onTap: () => onChanged(value <= min ? min : value - 1),
          ),
          Expanded(
            child: Center(
              child: Text(value.toString(),
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.semiBold)),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            color: iconColor,
            onTap: () => onChanged(value >= max ? max : value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StepperButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

/// Bordered pill that opens an 8-color palette inline below it.
class RefinedColorButton extends StatelessWidget {
  final String color;
  final bool open;
  final VoidCallback onTap;
  const RefinedColorButton({
    super.key,
    required this.color,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stroke =
        isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
          decoration: BoxDecoration(
            border: Border.all(color: stroke, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _hexToColor(color),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(open ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> kRefinedPalette = [
  '#3B82F6', '#EF4444', '#22C55E', '#F59E0B', '#8B5CF6',
  '#06B6D4', '#EC4899', '#84CC16', '#FFFFFF', '#FBBF24',
];

/// Horizontal palette row that pairs with [RefinedColorButton].
class RefinedColorPaletteRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onPick;
  final EdgeInsetsGeometry padding;
  const RefinedColorPaletteRow({
    super.key,
    required this.selected,
    required this.onPick,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 14),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final hex in kRefinedPalette)
            _SwatchTile(
              hex: hex,
              selected: hex.toLowerCase() == selected.toLowerCase(),
              onTap: () => onPick(hex),
            ),
        ],
      ),
    );
  }
}

class _SwatchTile extends StatefulWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;
  const _SwatchTile({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SwatchTile> createState() => _SwatchTileState();
}

class _SwatchTileState extends State<_SwatchTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ringIdle =
        isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);
    const size = 28.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _hexToColor(widget.hex),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.selected
                  ? Colors.white
                  : (_hover
                      ? Colors.white.withValues(alpha: 0.4)
                      : ringIdle),
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color:
                          _hexToColor(widget.hex).withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

/// Bordered 36px-tall pill containing 2+ segments; active is filled in
/// `MyntColors.primary` with white text.
class RefinedSegmented<T> extends StatelessWidget {
  final List<RefinedSegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double? width;
  const RefinedSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2030) : const Color(0xFFF8FAFC);
    final stroke =
        isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    Widget seg(RefinedSegmentOption<T> opt) {
      final sel = opt.value == value;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => onChanged(opt.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              height: 32,
              decoration: BoxDecoration(
                color: sel ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                opt.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sel ? Colors.white : muted,
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: stroke, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: options.map(seg).toList()),
    );
  }
}

class RefinedSegmentOption<T> {
  final T value;
  final String label;
  const RefinedSegmentOption({required this.value, required this.label});
}

/// Full-width 44–48px gradient action button (purple → magenta → orange).
class RefinedGradientButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final double height;
  const RefinedGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 46,
  });

  @override
  State<RefinedGradientButton> createState() => _RefinedGradientButtonState();
}

class _RefinedGradientButtonState extends State<RefinedGradientButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: widget.height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF7C3AED),
                Color(0xFFEC4899),
                Color(0xFFF59E0B),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED)
                    .withValues(alpha: _hover ? 0.45 : 0.28),
                blurRadius: _hover ? 22 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          transform: Matrix4.identity()
            ..scaleByDouble(
              _down ? 0.985 : (_hover ? 1.005 : 1.0),
              _down ? 0.985 : (_hover ? 1.005 : 1.0),
              1.0,
              1.0,
            ),
          transformAlignment: Alignment.center,
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Search field with dark fill, magnifying-glass prefix icon, subtle border.
class RefinedSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  const RefinedSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search…',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2030) : const Color(0xFFF8FAFC);
    final stroke =
        isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: stroke, width: 1),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
            child: Icon(Icons.search, size: 16, color: muted),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: MyntWebTextStyles.body(context),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 9, horizontal: 0),
                hintText: hintText,
                hintStyle: MyntWebTextStyles.body(context, color: muted),
                border: InputBorder.none,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            InkWell(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                child: Icon(Icons.close, size: 14, color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small uppercase muted section label used between rows.
class RefinedSectionLabel extends StatelessWidget {
  final String label;
  final EdgeInsetsGeometry padding;
  const RefinedSectionLabel({
    super.key,
    required this.label,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 6),
  });

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Padding(
      padding: padding,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      ),
    );
  }
}

/// Empty-state used when a tab's feature isn't built yet. Soft icon, label,
/// and a short hint — beats a sterile "Coming soon" stub.
class RefinedComingSoon extends StatelessWidget {
  final String label;
  final String? hint;
  const RefinedComingSoon({
    super.key,
    this.label = 'Coming soon',
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.auto_awesome,
                  size: 20, color: accent.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold)),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: MyntWebTextStyles.caption(context, color: muted)),
            ],
          ],
        ),
      ),
    );
  }
}

Color _hexToColor(String hex) =>
    Color(int.parse(hex.replaceAll('#', '0xff')));
