import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/refined_controls.dart';

/// Settings → Customize tab. Pure UI surface over [chartPaletteProvider].
/// The shell screen owns the postMessage pipeline that ships palette changes
/// into the iframe; this widget only mutates the provider.
class ChartCustomizeTab extends ConsumerStatefulWidget {
  const ChartCustomizeTab({super.key});

  @override
  ConsumerState<ChartCustomizeTab> createState() => _ChartCustomizeTabState();
}

class _ChartCustomizeTabState extends ConsumerState<ChartCustomizeTab> {
  // Inline-palette open key. At most ONE palette row is expanded at a time
  // so the popover doesn't balloon to twice its height. null = all closed.
  String? _openField;

  void _toggle(String key) => setState(
      () => _openField = _openField == key ? null : key);

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(chartPaletteProvider);
    final notifier = ref.read(chartPaletteProvider.notifier);
    final divider = _dividerColor(context);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RefinedSectionLabel(label: 'Candle colors'),
        _PaletteRow(
          label: 'Body — Up',
          color: palette.bullBody,
          defaultHex: ChartPalette.dBullBody,
          open: _openField == 'bullBody',
          onToggle: () => _toggle('bullBody'),
          onPick: (hex) {
            notifier.setBullBody(hex);
            setState(() => _openField = null);
          },
        ),
        Container(height: 1, color: divider),
        _PaletteRow(
          label: 'Body — Down',
          color: palette.bearBody,
          defaultHex: ChartPalette.dBearBody,
          open: _openField == 'bearBody',
          onToggle: () => _toggle('bearBody'),
          onPick: (hex) {
            notifier.setBearBody(hex);
            setState(() => _openField = null);
          },
        ),
        Container(height: 1, color: divider),
        _PaletteRow(
          label: 'Wick — Up',
          color: palette.bullWick,
          defaultHex: ChartPalette.dBullWick,
          open: _openField == 'bullWick',
          onToggle: () => _toggle('bullWick'),
          onPick: (hex) {
            notifier.setBullWick(hex);
            setState(() => _openField = null);
          },
        ),
        Container(height: 1, color: divider),
        _PaletteRow(
          label: 'Wick — Down',
          color: palette.bearWick,
          defaultHex: ChartPalette.dBearWick,
          open: _openField == 'bearWick',
          onToggle: () => _toggle('bearWick'),
          onPick: (hex) {
            notifier.setBearWick(hex);
            setState(() => _openField = null);
          },
        ),

        const RefinedSectionLabel(label: 'Canvas'),
        _PaletteRow(
          label: 'Background',
          color: palette.background,
          defaultHex: '',
          themeFallback: true,
          open: _openField == 'background',
          onToggle: () => _toggle('background'),
          onPick: (hex) {
            notifier.setBackground(hex);
            setState(() => _openField = null);
          },
          onClearToTheme: () => notifier.setBackground(''),
        ),
        Container(height: 1, color: divider),
        _PaletteRow(
          label: 'Text',
          color: palette.text,
          defaultHex: '',
          themeFallback: true,
          open: _openField == 'text',
          onToggle: () => _toggle('text'),
          onPick: (hex) {
            notifier.setText(hex);
            setState(() => _openField = null);
          },
          onClearToTheme: () => notifier.setText(''),
        ),
        Container(height: 1, color: divider),
        _PaletteRow(
          label: 'Grid',
          color: palette.grid,
          defaultHex: '',
          themeFallback: true,
          open: _openField == 'grid',
          onToggle: () => _toggle('grid'),
          onPick: (hex) {
            notifier.setGrid(hex);
            setState(() => _openField = null);
          },
          onClearToTheme: () => notifier.setGrid(''),
        ),
        Container(height: 1, color: divider),
        _PaletteRow(
          label: 'Session break',
          color: palette.sessionBreak,
          defaultHex: '',
          themeFallback: true,
          open: _openField == 'sessionBreak',
          onToggle: () => _toggle('sessionBreak'),
          onPick: (hex) {
            notifier.setSessionBreak(hex);
            setState(() => _openField = null);
          },
          onClearToTheme: () => notifier.setSessionBreak(''),
        ),
        Container(height: 1, color: divider),
        _PaletteRow(
          label: 'Crosshair',
          color: palette.crosshair,
          defaultHex: '',
          themeFallback: true,
          open: _openField == 'crosshair',
          onToggle: () => _toggle('crosshair'),
          onPick: (hex) {
            notifier.setCrosshair(hex);
            setState(() => _openField = null);
          },
          onClearToTheme: () => notifier.setCrosshair(''),
        ),

        Container(height: 1, color: divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: palette.isDefault
                  ? null
                  : () {
                      notifier.resetToDefault();
                      setState(() => _openField = null);
                    },
              icon: Icon(Icons.refresh, size: 16, color: loss),
              label: Text(
                'Reset to defaults',
                style: MyntWebTextStyles.bodySmall(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  darkColor: loss,
                  lightColor: loss,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A label + colour-swatch button row with optional "Theme" chip + inline
/// 10-swatch palette popup below.
class _PaletteRow extends StatelessWidget {
  final String label;
  // Empty string means "follow theme" — only meaningful when [themeFallback]
  // is true. The swatch then shows a neutral preview tile.
  final String color;
  final String defaultHex;
  final bool themeFallback;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<String> onPick;
  final VoidCallback? onClearToTheme;

  const _PaletteRow({
    required this.label,
    required this.color,
    required this.defaultHex,
    required this.open,
    required this.onToggle,
    required this.onPick,
    this.themeFallback = false,
    this.onClearToTheme,
  });

  @override
  Widget build(BuildContext context) {
    final isThemeDefault = themeFallback && color.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefinedRow(
          label: label,
          control: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isThemeDefault) ...[
                _ThemeChip(
                  onTap: onClearToTheme,
                ),
                const SizedBox(width: 8),
              ],
              _ColorButton(
                color: color.isEmpty ? defaultHex : color,
                placeholder: color.isEmpty,
                open: open,
                onTap: onToggle,
              ),
            ],
          ),
          onTap: onToggle,
        ),
        if (open)
          _ColorPaletteRow(
            selected: color,
            onPick: onPick,
            extraTrailing: themeFallback
                ? _ThemeChip(
                    onTap: () {
                      onClearToTheme?.call();
                    },
                  )
                : null,
          ),
      ],
    );
  }
}

/// Small grey chip that flags a field as "following the theme default".
/// Tapping it resets the field back to the theme value.
class _ThemeChip extends StatelessWidget {
  final VoidCallback? onTap;
  const _ThemeChip({this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final fg = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Theme',
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bordered pill that previews the currently-picked colour and opens the
/// inline palette below the row. When [placeholder] is true (field set to
/// theme default) the preview tile renders a hatched grey square so users
/// see at a glance that no explicit colour is set.
class _ColorButton extends StatelessWidget {
  final String color;
  final bool open;
  final bool placeholder;
  final VoidCallback onTap;
  const _ColorButton({
    required this.color,
    required this.open,
    required this.onTap,
    this.placeholder = false,
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
                  color: placeholder
                      ? muted.withValues(alpha: 0.25)
                      : _hexToColor(color),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: placeholder
                    ? Icon(Icons.brightness_auto,
                        size: 12,
                        color: muted.withValues(alpha: 0.9))
                    : null,
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

const List<String> _kCustomizePalette = [
  '#22C55E', '#16A34A', '#EF4444', '#B91C1C', '#3B82F6',
  '#0EA5E9', '#8B5CF6', '#F59E0B', '#94A3B8', '#FFFFFF',
];

class _ColorPaletteRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onPick;
  final Widget? extraTrailing;
  const _ColorPaletteRow({
    required this.selected,
    required this.onPick,
    this.extraTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final hex in _kCustomizePalette)
            _SwatchTile(
              hex: hex,
              selected: hex.toLowerCase() == selected.toLowerCase(),
              onTap: () => onPick(hex),
            ),
          if (extraTrailing != null) extraTrailing!,
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

Color _dividerColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9);
}

Color _hexToColor(String hex) =>
    Color(int.parse(hex.replaceAll('#', '0xff')));
