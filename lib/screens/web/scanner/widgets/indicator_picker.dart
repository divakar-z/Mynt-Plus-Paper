import 'package:flutter/material.dart';
import 'package:mynt_plus/models/scanner_model/indicator_catalog.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// Single-select dropdown over a fetched [IndicatorCatalog]. Renders items
/// grouped by category in the order the server declares them; group headers
/// are visually distinct (tinted bg, uppercase, tertiary color).
///
/// Callers are responsible for fetching the catalog (via
/// `indicatorCatalogProvider`) and rendering any per-indicator param inputs
/// — this widget only returns the selected indicator name.
class IndicatorPicker extends StatelessWidget {
  final IndicatorCatalog catalog;
  final String? value;
  final ValueChanged<String> onChanged;
  final String? hint;

  const IndicatorPicker({
    super.key,
    required this.catalog,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final byCategory = catalog.byCategory();
    return DropdownButton<String>(
      value: value,
      hint: Text(hint ?? 'Pick indicator'),
      isExpanded: true,
      items: [
        for (final entry in byCategory.entries) ...[
          DropdownMenuItem(
            enabled: false,
            value: '__cat_${entry.key.key}',
            child: _GroupHeader(label: entry.key.label),
          ),
          for (final ind in entry.value)
            DropdownMenuItem(value: ind.name, child: Text(ind.label)),
        ],
      ],
      onChanged: (v) {
        if (v == null || v.startsWith('__cat_')) return;
        onChanged(v);
      },
    );
  }
}

/// Same visual treatment as the fundamental field dropdown's group separator
/// — uppercase, tertiary color, tinted bg edge-to-edge inside the menu item.
class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tint = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: -16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: tint,
      child: Text(
        label.toUpperCase(),
        style: MyntWebTextStyles.caption(context,
                fontWeight: MyntFonts.semiBold, color: tertiary)
            .copyWith(letterSpacing: 1.0),
      ),
    );
  }
}
