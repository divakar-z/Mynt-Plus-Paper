import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../provider/accessibility_provider.dart';
import '../../res/mynt_web_color_styles.dart';
import '../../res/mynt_web_text_styles.dart';

/// Circular toggle button that anchors the accessibility dropdown.
class A11yIconButton extends StatefulWidget {
  const A11yIconButton({
    super.key,
    required this.anchorKey,
    required this.isDarkMode,
    required this.active,
    required this.onTap,
  });

  final GlobalKey anchorKey;
  final bool isDarkMode;
  final bool active;
  final VoidCallback onTap;

  @override
  State<A11yIconButton> createState() => _A11yIconButtonState();
}

class _A11yIconButtonState extends State<A11yIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.isDarkMode
        ? MyntColors.primaryDark
        : MyntColors.primary;
    final iconColor = widget.active || _hover
        ? Colors.white
        : (widget.isDarkMode
            ? MyntColors.textPrimaryDark
            : MyntColors.textPrimary);

    final bg = widget.active
        ? primary
        : _hover
            ? primary.withOpacity(0.18)
            : (widget.isDarkMode
                ? Colors.white.withOpacity(0.06)
                : primary.withOpacity(0.08));

    return Semantics(
      button: true,
      label: 'Open accessibility options',
      toggled: widget.active,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            key: widget.anchorKey,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.active
                    ? primary
                    : primary.withOpacity(_hover ? 0.35 : 0.18),
                width: 1,
              ),
              boxShadow: (_hover || widget.active)
                  ? [
                      BoxShadow(
                        color: primary.withOpacity(0.28),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.accessibility_new_rounded,
                  color: iconColor,
                  size: 20,
                ),
                if (widget.active)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: MyntColors.profit,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isDarkMode
                              ? MyntColors.backgroundColorDark
                              : Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds and inserts the accessibility dropdown overlay anchored to
/// [anchorKey]. Returns the inserted entry so the caller can dismiss it.
OverlayEntry buildAccessibilityOverlay({
  required BuildContext context,
  required GlobalKey anchorKey,
  required bool isDarkMode,
  required VoidCallback onClose,
}) {
  final RenderBox anchor =
      anchorKey.currentContext!.findRenderObject() as RenderBox;
  final Offset anchorBottomRight =
      anchor.localToGlobal(anchor.size.bottomRight(Offset.zero));

  final dialogBg = resolveThemeColor(context,
      dark: MyntColors.dialogDark, light: MyntColors.dialog);
  final borderColor = resolveThemeColor(context,
      dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
  final primaryColor = resolveThemeColor(context,
      dark: MyntColors.primaryDark, light: MyntColors.primary);
  final textPrimary = resolveThemeColor(context,
      dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
  final textSecondary = resolveThemeColor(context,
      dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

  const double menuWidth = 360;

  return OverlayEntry(
    builder: (overlayCtx) {
      final screenWidth = MediaQuery.of(overlayCtx).size.width;
      final rightInset = screenWidth - anchorBottomRight.dx;
      return Stack(
        children: [
          Positioned.fill(
            child: PointerInterceptor(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
              ),
            ),
          ),
          Positioned(
            right: rightInset.clamp(8.0, screenWidth - menuWidth - 8.0),
            top: anchorBottomRight.dy + 8,
            child: PointerInterceptor(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                builder: (_, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * -8),
                    child: child,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Consumer(
                    builder: (ctx, dialogRef, _) {
                      final a11y = dialogRef.watch(accessibilityProvider);
                      return Container(
                        width: menuWidth,
                        decoration: BoxDecoration(
                          color: dialogBg,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: borderColor, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                  isDarkMode ? 0.45 : 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding:
                            const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    'Accessibility',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                Semantics(
                                  button: true,
                                  label: 'Close accessibility panel',
                                  child: InkWell(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    onTap: onClose,
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(Icons.close,
                                          size: 18,
                                          color: textSecondary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 4,
                              shrinkWrap: true,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              childAspectRatio: 0.92,
                              children: [
                                _AccessibilityTile(
                                  icon: Icons.record_voice_over_outlined,
                                  label: 'Screen\nReader',
                                  active: a11y.screenReaderEnabled,
                                  primaryColor: primaryColor,
                                  borderColor: borderColor,
                                  textColor: textPrimary,
                                  onTap: () => dialogRef
                                      .read(accessibilityProvider)
                                      .toggleScreenReader(context),
                                ),
                                _AccessibilityTile(
                                  icon: Icons.contrast_outlined,
                                  label: 'Smart\nContrast',
                                  active: a11y.smartContrastEnabled,
                                  primaryColor: primaryColor,
                                  borderColor: borderColor,
                                  textColor: textPrimary,
                                  onTap: () => dialogRef
                                      .read(accessibilityProvider)
                                      .toggleSmartContrast(),
                                ),
                                _AccessibilityTile(
                                  icon: Icons.format_size,
                                  label: 'A-   A+',
                                  sublabel: 'Font Size',
                                  active: a11y.textScaleEnabled,
                                  primaryColor: primaryColor,
                                  borderColor: borderColor,
                                  textColor: textPrimary,
                                  splitActions: [
                                    _TileAction(
                                      label: 'A-',
                                      semanticsLabel:
                                          'Decrease font size',
                                      onTap: a11y.canDecreaseTextScale
                                          ? () => dialogRef
                                              .read(accessibilityProvider)
                                              .decreaseTextScale()
                                          : null,
                                    ),
                                    _TileAction(
                                      label: 'A+',
                                      semanticsLabel:
                                          'Increase font size',
                                      onTap: a11y.canIncreaseTextScale
                                          ? () => dialogRef
                                              .read(accessibilityProvider)
                                              .increaseTextScale()
                                          : null,
                                    ),
                                  ],
                                ),
                                _AccessibilityTile(
                                  icon: Icons.palette_outlined,
                                  label: 'Theme\nTone',
                                  active: a11y.themeToneEnabled,
                                  primaryColor: primaryColor,
                                  borderColor: borderColor,
                                  textColor: textPrimary,
                                  toneSelectors: [
                                    _ToneDot(
                                      color: const Color(0xFF4A9EFF),
                                      selected: a11y.themeTone ==
                                          ThemeTone.blue,
                                      semanticsLabel: 'Blue tone',
                                      onTap: () => dialogRef
                                          .read(accessibilityProvider)
                                          .setThemeTone(ThemeTone.blue),
                                    ),
                                    _ToneDot(
                                      color: const Color(0xFFF5B942),
                                      selected: a11y.themeTone ==
                                          ThemeTone.warm,
                                      semanticsLabel: 'Yellow tone',
                                      onTap: () => dialogRef
                                          .read(accessibilityProvider)
                                          .setThemeTone(ThemeTone.warm),
                                    ),
                                    _ToneDot(
                                      color: const Color(0xFF3FB964),
                                      selected: a11y.themeTone ==
                                          ThemeTone.cool,
                                      semanticsLabel: 'Green tone',
                                      onTap: () => dialogRef
                                          .read(accessibilityProvider)
                                          .setThemeTone(ThemeTone.cool),
                                    ),
                                    _ToneDot(
                                      color: const Color(0xFFE5484D),
                                      selected: a11y.themeTone ==
                                          ThemeTone.sepia,
                                      semanticsLabel: 'Red tone',
                                      onTap: () => dialogRef
                                          .read(accessibilityProvider)
                                          .setThemeTone(ThemeTone.sepia),
                                    ),
                                  ],
                                ),
                                _AccessibilityTile(
                                  icon:
                                      Icons.center_focus_strong_outlined,
                                  label: 'ADHD Focus\nAssist',
                                  active: a11y.adhdFocusAssistEnabled,
                                  primaryColor: primaryColor,
                                  borderColor: borderColor,
                                  textColor: textPrimary,
                                  onTap: () => dialogRef
                                      .read(accessibilityProvider)
                                      .toggleAdhdFocusAssist(),
                                ),
                                _AccessibilityTile(
                                  icon: Icons.text_fields_outlined,
                                  label: 'Dyslexia\nSupport',
                                  active: a11y.dyslexiaSupportEnabled,
                                  primaryColor: primaryColor,
                                  borderColor: borderColor,
                                  textColor: textPrimary,
                                  onTap: () => dialogRef
                                      .read(accessibilityProvider)
                                      .toggleDyslexiaSupport(),
                                ),
                                _AccessibilityTile(
                                  icon: Icons.link_outlined,
                                  label: 'Highlight\nLinks',
                                  active: a11y.highlightLinksEnabled,
                                  primaryColor: primaryColor,
                                  borderColor: borderColor,
                                  textColor: textPrimary,
                                  onTap: () => dialogRef
                                      .read(accessibilityProvider)
                                      .toggleHighlightLinks(),
                                ),
                                _AccessibilityTile(
                                  icon: Icons.crop_free_outlined,
                                  label: 'Focus\nIndicator',
                                  active: a11y.focusIndicatorEnabled,
                                  primaryColor: primaryColor,
                                  borderColor: borderColor,
                                  textColor: textPrimary,
                                  onTap: () => dialogRef
                                      .read(accessibilityProvider)
                                      .toggleFocusIndicator(),
                                ),
                                _AccessibilityTile(
                                  icon:
                                      Icons.invert_colors_on_outlined,
                                  label: 'Invert\nColours',
                                  active: a11y.invertColoursEnabled,
                                  primaryColor: primaryColor,
                                  borderColor: borderColor,
                                  textColor: textPrimary,
                                  onTap: () => dialogRef
                                      .read(accessibilityProvider)
                                      .toggleInvertColours(),
                                ),
                                _AccessibilityTile(
                                  icon: Icons.filter_b_and_w,
                                  label: 'Grayscale',
                                  active: a11y.grayscaleEnabled,
                                  primaryColor: primaryColor,
                                  borderColor: borderColor,
                                  textColor: textPrimary,
                                  onTap: () => dialogRef
                                      .read(accessibilityProvider)
                                      .toggleGrayscale(),
                                ),
                                _AccessibilityTile(
                                  icon: Icons.nightlight_outlined,
                                  label: 'Blue Light\nFilter',
                                  active: a11y.blueLightFilterEnabled,
                                  primaryColor: primaryColor,
                                  borderColor: borderColor,
                                  textColor: textPrimary,
                                  onTap: () => dialogRef
                                      .read(accessibilityProvider)
                                      .toggleBlueLightFilter(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  final a11yNotifier = dialogRef
                                      .read(accessibilityProvider);
                                  if (a11y.screenReaderEnabled) {
                                    a11yNotifier
                                        .toggleScreenReader(context);
                                  }
                                  if (a11y.grayscaleEnabled) {
                                    a11yNotifier.toggleGrayscale();
                                  }
                                  if (a11y.invertColoursEnabled) {
                                    a11yNotifier.toggleInvertColours();
                                  }
                                  if (a11y.blueLightFilterEnabled) {
                                    a11yNotifier.toggleBlueLightFilter();
                                  }
                                  if (a11y.smartContrastEnabled) {
                                    a11yNotifier.toggleSmartContrast();
                                  }
                                  if (a11y.textScaleEnabled) {
                                    a11yNotifier.resetTextScale();
                                  }
                                  if (a11y.themeToneEnabled) {
                                    a11yNotifier.resetThemeTone();
                                  }
                                  if (a11y.adhdFocusAssistEnabled) {
                                    a11yNotifier.toggleAdhdFocusAssist();
                                  }
                                  if (a11y.dyslexiaSupportEnabled) {
                                    a11yNotifier.toggleDyslexiaSupport();
                                  }
                                  if (a11y.highlightLinksEnabled) {
                                    a11yNotifier.toggleHighlightLinks();
                                  }
                                  if (a11y.focusIndicatorEnabled) {
                                    a11yNotifier.toggleFocusIndicator();
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  side: BorderSide(color: borderColor),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(26),
                                  ),
                                ),
                                child: const Text(
                                  'Reset All',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _AccessibilityTile extends StatefulWidget {
  const _AccessibilityTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.primaryColor,
    required this.borderColor,
    required this.textColor,
    this.sublabel,
    this.onTap,
    this.comingSoon = false,
    this.splitActions,
    this.toneSelectors,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final bool active;
  final Color primaryColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback? onTap;
  final bool comingSoon;
  final List<_TileAction>? splitActions;
  final List<_ToneDot>? toneSelectors;

  @override
  State<_AccessibilityTile> createState() => _AccessibilityTileState();
}

class _AccessibilityTileState extends State<_AccessibilityTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hasSplit = widget.splitActions != null;
    final hasToneSelectors = widget.toneSelectors != null;
    final disabled = widget.comingSoon ||
        (!hasSplit && !hasToneSelectors && widget.onTap == null);
    final bg = widget.active
        ? widget.primaryColor.withOpacity(0.10)
        : _hover && !disabled
            ? widget.primaryColor.withOpacity(0.05)
            : Colors.transparent;
    final border =
        widget.active ? widget.primaryColor : widget.borderColor;
    final iconColor = disabled
        ? widget.textColor.withOpacity(0.45)
        : widget.active
            ? widget.primaryColor
            : widget.textColor;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: widget.active ? 1.5 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.icon,
            size: hasToneSelectors ? 22 : 26,
            color: iconColor,
          ),
          SizedBox(height: hasToneSelectors ? 4 : 8),
          if (hasSplit)
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < widget.splitActions!.length; i++) ...[
                  _SplitActionButton(
                    action: widget.splitActions![i],
                    primaryColor: widget.primaryColor,
                    textColor: widget.textColor,
                  ),
                  if (i != widget.splitActions!.length - 1)
                    const SizedBox(width: 6),
                ],
              ],
            )
          else
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: disabled
                    ? widget.textColor.withOpacity(0.55)
                    : widget.textColor,
              ),
            ),
          if (widget.sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              widget.sublabel!,
              style: TextStyle(
                fontSize: 9,
                color: widget.textColor.withOpacity(0.55),
              ),
            ),
          ],
          if (hasToneSelectors) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0;
                    i < widget.toneSelectors!.length;
                    i++) ...[
                  _ToneDotButton(
                    dot: widget.toneSelectors![i],
                    borderColor: widget.borderColor,
                  ),
                  if (i != widget.toneSelectors!.length - 1)
                    const SizedBox(width: 3),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    final interactive = MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            disabled || hasSplit || hasToneSelectors ? null : widget.onTap,
        child: tile,
      ),
    );

    return Semantics(
      button: !disabled && !hasSplit && !hasToneSelectors,
      toggled: widget.active,
      label: widget.label.replaceAll('\n', ' '),
      hint: disabled ? 'Coming soon' : null,
      excludeSemantics: !hasSplit && !hasToneSelectors,
      child: disabled
          ? Tooltip(message: 'Coming soon', child: interactive)
          : interactive,
    );
  }
}

class _TileAction {
  const _TileAction({
    required this.label,
    required this.onTap,
    required this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final String semanticsLabel;
}

class _ToneDot {
  const _ToneDot({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.semanticsLabel,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String semanticsLabel;
}

class _ToneDotButton extends StatelessWidget {
  const _ToneDotButton({
    required this.dot,
    required this.borderColor,
  });

  final _ToneDot dot;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: dot.selected,
      label: dot.semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: dot.onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dot.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: dot.selected ? Colors.black87 : borderColor,
                width: dot.selected ? 1.5 : 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplitActionButton extends StatefulWidget {
  const _SplitActionButton({
    required this.action,
    required this.primaryColor,
    required this.textColor,
  });

  final _TileAction action;
  final Color primaryColor;
  final Color textColor;

  @override
  State<_SplitActionButton> createState() => _SplitActionButtonState();
}

class _SplitActionButtonState extends State<_SplitActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.action.onTap != null;
    final fg = enabled
        ? (_hover ? widget.primaryColor : widget.textColor)
        : widget.textColor.withOpacity(0.35);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.action.semanticsLabel,
      excludeSemantics: true,
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.action.onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              widget.action.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
