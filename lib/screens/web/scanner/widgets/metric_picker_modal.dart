import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/indicator_catalog.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/common_search_fields_web.dart';

/// Two-part result of the picker: fundamental field keys and technical
/// indicator wire-names. Kept as two sets so the caller can decide how to
/// merge them into its own state (the fundamentals sub-page keeps two
/// independent lists internally so it can route Run by row-kind).
class MetricPickerResult {
  final Set<String> fundamentalKeys;
  final Set<String> technicalNames;
  const MetricPickerResult({
    required this.fundamentalKeys,
    required this.technicalNames,
  });
}

/// Tickertape-style "Add filters" picker for the redesigned Fundamentals
/// screen: metric categories on the left, the metrics in the selected
/// category (or search results) as checkboxes on the right. When [catalog]
/// is provided, the left rail also lists technical-indicator categories so
/// users can add e.g. RSI / SMA to the same filter sidebar. Returns null if
/// the dialog was dismissed without "Done".
Future<MetricPickerResult?> showMetricPicker(
  BuildContext context, {
  required List<FundamentalField> fields,
  IndicatorCatalog? catalog,
  required Set<String> selectedFundamentals,
  required Set<String> selectedTechnicals,
  bool allIndicatorKinds = false,
}) {
  return showDialog<MetricPickerResult>(
    context: context,
    builder: (_) => _MetricPicker(
      fields: fields,
      catalog: catalog,
      selectedFundamentals: selectedFundamentals,
      selectedTechnicals: selectedTechnicals,
      allIndicatorKinds: allIndicatorKinds,
    ),
  );
}

class _MetricPicker extends StatefulWidget {
  final List<FundamentalField> fields;
  final IndicatorCatalog? catalog;
  final Set<String> selectedFundamentals;
  final Set<String> selectedTechnicals;
  /// Also list boolean (candlestick patterns) and enum indicators — used by
  /// the predefined-scanner filter row, which edits those as Yes/No or a
  /// label dropdown.
  final bool allIndicatorKinds;
  const _MetricPicker({
    required this.fields,
    required this.catalog,
    required this.selectedFundamentals,
    required this.selectedTechnicals,
    required this.allIndicatorKinds,
  });

  @override
  State<_MetricPicker> createState() => _MetricPickerState();
}

/// Category rail entry — either a fundamental group (fundamentals list) or a
/// technical indicator category from the catalog.
class _RailEntry {
  final String label;
  final bool isTechnical;
  final String? indicatorCategoryKey; // null for fundamental groups
  const _RailEntry.fund(this.label)
      : isTechnical = false,
        indicatorCategoryKey = null;
  const _RailEntry.tech(this.label, this.indicatorCategoryKey)
      : isTechnical = true;
}

class _MetricPickerState extends State<_MetricPicker> {
  late final Set<String> _workingFund = {...widget.selectedFundamentals};
  late final Set<String> _workingTech = {...widget.selectedTechnicals};
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _rail = 0;
  late final List<_RailEntry> _railEntries;
  late final Map<String, List<FundamentalField>> _byGroup;
  late final Map<String, List<CatalogIndicator>> _byIndCat;

  @override
  void initState() {
    super.initState();
    _byGroup = {};
    for (final f in widget.fields) {
      _byGroup
          .putIfAbsent(f.group.isEmpty ? 'Other' : f.group, () => [])
          .add(f);
    }
    _byIndCat = {};
    final cat = widget.catalog;
    if (cat != null) {
      // Only float indicators for the sidebar — booleans and enums make less
      // sense as "value < N" chips and stay in the Custom Scans page.
      for (final i in cat.indicators) {
        if (!widget.allIndicatorKinds && i.kind != IndicatorKind.floatKind) {
          continue;
        }
        _byIndCat.putIfAbsent(i.category, () => []).add(i);
      }
    }
    _railEntries = [
      for (final g in _byGroup.keys) _RailEntry.fund(g),
      if (cat != null)
        for (final c in cat.categories)
          if ((_byIndCat[c.key] ?? const []).isNotEmpty)
            _RailEntry.tech(c.label, c.key),
    ];
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _searching => _query.trim().isNotEmpty;

  /// Right-side list. In search mode, spans both catalogs so users find
  /// e.g. "rsi" and "revenue" together; otherwise, shows the entries for
  /// the selected rail row.
  List<_Entry> get _rightList {
    if (_searching) {
      final q = _query.toLowerCase();
      final out = <_Entry>[];
      for (final f in widget.fields) {
        if (f.label.toLowerCase().contains(q)) out.add(_Entry.fund(f));
      }
      for (final list in _byIndCat.values) {
        for (final i in list) {
          if (i.label.toLowerCase().contains(q) ||
              i.name.toLowerCase().contains(q)) {
            out.add(_Entry.tech(i));
          }
        }
      }
      return out;
    }
    if (_railEntries.isEmpty) return const [];
    final entry = _railEntries[_rail.clamp(0, _railEntries.length - 1)];
    if (entry.isTechnical) {
      return (_byIndCat[entry.indicatorCategoryKey] ?? const [])
          .map(_Entry.tech)
          .toList();
    }
    return (_byGroup[entry.label] ?? const []).map(_Entry.fund).toList();
  }

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final totalMetrics = widget.fields.length +
        _byIndCat.values.fold<int>(0, (a, b) => a + b.length);
    final totalSelected = _workingFund.length + _workingTech.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: shadcn.Card(
        borderRadius: BorderRadius.circular(8),
        padding: EdgeInsets.zero,
        child: Container(
          width: 720,
          height: 520,
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.dialogDark, light: MyntColors.dialog),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: title + subtitle, a positions-style search box, close.
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add filters',
                              style: MyntWebTextStyles.title(context,
                                  color: textPrimary)),
                          const SizedBox(height: 4),
                          Text(
                              widget.fields.isEmpty
                                  ? '$totalMetrics technical indicators'
                                  : '$totalMetrics metrics · fundamentals + technicals',
                              style: MyntWebTextStyles.caption(context,
                                  color: secondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 260,
                      height: 40,
                      child: MyntSearchTextField.withSmartClear(
                        controller: _search,
                        placeholder: 'Search filters…',
                        leadingIcon: assets.searchIcon,
                        textCapitalization: TextCapitalization.none,
                        onChanged: (v) => setState(() => _query = v),
                        onClear: () => setState(() => _query = ''),
                      ),
                    ),
                    const SizedBox(width: 12),
                    MyntCloseButton(
                        onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Category rail — hidden while searching (search spans all).
                    if (!_searching)
                      SizedBox(
                        width: 220,
                        child: Container(
                          decoration: BoxDecoration(
                            border:
                                Border(right: BorderSide(color: border)),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _railEntries.length,
                            itemBuilder: (_, i) => _railItem(i),
                          ),
                        ),
                      ),
                    Expanded(child: _checkList(secondary)),
                  ],
                ),
              ),
              // Footer: selected count + Done.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Row(children: [
                  Text('$totalSelected selected',
                      style: MyntWebTextStyles.body(context, color: secondary)),
                  const Spacer(),
                  MyntButton(
                    type: MyntButtonType.primary,
                    label: 'Done',
                    onPressed: () => Navigator.of(context).pop(
                      MetricPickerResult(
                        fundamentalKeys: _workingFund,
                        technicalNames: _workingTech,
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _railItem(int i) {
    final entry = _railEntries[i];
    final active = _rail == i;
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    // How many entries in this rail row are currently selected.
    int selCount;
    if (entry.isTechnical) {
      selCount = (_byIndCat[entry.indicatorCategoryKey] ?? const [])
          .where((i) => _workingTech.contains(i.name))
          .length;
    } else {
      selCount = (_byGroup[entry.label] ?? const [])
          .where((f) => _workingFund.contains(f.key))
          .length;
    }
    return Material(
      color: active ? hoverBg : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _rail = i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: [
            if (entry.isTechnical) ...[
              Icon(shadcn.LucideIcons.activity,
                  size: 13, color: active ? primary : secondary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.body(context,
                      fontWeight:
                          active ? MyntFonts.semiBold : MyntFonts.medium,
                      color: active ? primary : textColor)),
            ),
            if (selCount > 0)
              Text('$selCount',
                  style: MyntWebTextStyles.caption(context, color: primary)),
            const SizedBox(width: 6),
            Icon(shadcn.LucideIcons.chevronRight,
                size: 14, color: active ? primary : secondary),
          ]),
        ),
      ),
    );
  }

  Widget _checkList(Color secondary) {
    final list = _rightList;
    if (list.isEmpty) {
      return Center(
        child: Text('No metrics found',
            style: MyntWebTextStyles.body(context, color: secondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (_, i) => _checkRow(list[i]),
    );
  }

  Widget _checkRow(_Entry e) {
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final isFund = e.field != null;
    final key = isFund ? e.field!.key : e.indicator!.name;
    final checked =
        isFund ? _workingFund.contains(key) : _workingTech.contains(key);
    final label = isFund ? e.field!.label : e.indicator!.label;
    final groupLabel = isFund
        ? e.field!.group
        : (widget.catalog?.categories
                .where((c) => c.key == e.indicator!.category)
                .map((c) => c.label)
                .firstOrNull ??
            e.indicator!.category);
    return InkWell(
      onTap: () => setState(() {
        final target = isFund ? _workingFund : _workingTech;
        if (checked) {
          target.remove(key);
        } else {
          target.add(key);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 18,
              color: checked ? primary : secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: MyntWebTextStyles.body(context, color: textColor)),
          ),
          if (!isFund) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('technical',
                  style: MyntWebTextStyles.exch(context,
                      fontWeight: FontWeight.w600, color: primary)),
            ),
          ],
          if (_searching && groupLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(groupLabel,
                style: MyntWebTextStyles.caption(context, color: tertiary)),
          ],
        ]),
      ),
    );
  }
}

/// Internal — either a fundamental field or a technical indicator, held as
/// a small union so the right-side list can be built once and iterated.
class _Entry {
  final FundamentalField? field;
  final CatalogIndicator? indicator;
  _Entry.fund(this.field) : indicator = null;
  _Entry.tech(this.indicator) : field = null;
}
