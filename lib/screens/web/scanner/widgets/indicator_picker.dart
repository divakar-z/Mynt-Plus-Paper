import 'package:flutter/material.dart';
import 'package:mynt_plus/models/scanner_model/indicator_catalog.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/filter_inputs.dart';

/// Single-select dropdown over a fetched [IndicatorCatalog] — uses the app's
/// standard [FilterSelect] overlay (boxed trigger + grouped overlay panel),
/// the same dropdown style used across the scanner. Items are grouped by
/// category in the order the server declares them; category names render as
/// tinted, uppercase, non-selectable headers.
///
/// Callers fetch the catalog (via `indicatorCatalogProvider`) and render any
/// per-indicator param inputs — this widget only returns the selected name.
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
    final options = <FilterSelectOption>[
      for (final entry in byCategory.entries) ...[
        FilterSelectOption('', entry.key.label, isHeader: true),
        for (final ind in entry.value)
          FilterSelectOption(ind.name, ind.label),
      ],
    ];
    return FilterSelect(
      value: value,
      hint: hint ?? 'Pick indicator',
      options: options,
      onChanged: onChanged,
    );
  }
}
