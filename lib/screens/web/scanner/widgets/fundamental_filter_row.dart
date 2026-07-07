import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/filter_inputs.dart';
import 'package:mynt_plus/provider/scanner/fundamentals_provider.dart';
import 'package:mynt_plus/screens/web/scanner/sub_pages/fundamentals_builder_state.dart';

class FundamentalFilterRow extends ConsumerStatefulWidget {
  final List<FundamentalField> fields;
  final FundamentalFilter filter;
  final ValueChanged<FundamentalFilter> onChange;
  final VoidCallback onRemove;

  /// When true, render the field / operator / value controls stacked
  /// vertically (for the redesigned left filter sidebar) instead of one
  /// horizontal row. The current screen keeps the default horizontal layout.
  final bool stacked;

  /// When true (only meaningful with [stacked]), drop the field dropdown and
  /// remove-× and render only the condition (operator + value / multiselect).
  /// Used by the metric accordion, where the field is fixed by the row itself.
  final bool hideField;

  const FundamentalFilterRow({
    super.key,
    required this.fields,
    required this.filter,
    required this.onChange,
    required this.onRemove,
    this.stacked = false,
    this.hideField = false,
  });

  @override
  ConsumerState<FundamentalFilterRow> createState() =>
      _FundamentalFilterRowState();
}

class _FundamentalFilterRowState extends ConsumerState<FundamentalFilterRow> {
  late final TextEditingController _v1 = TextEditingController();
  late final TextEditingController _v2 = TextEditingController();
  late final TextEditingController _years = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  void _hydrate() {
    final v = widget.filter.value;
    if (v is num) {
      _v1.text = _isPct ? (v * 100).toString() : v.toString();
    } else if (v is String) {
      _v1.text = v;
    } else if (v is List && v.length == 2) {
      _v1.text = (_isPct ? (v[0] as num) * 100 : v[0]).toString();
      _v2.text = (_isPct ? (v[1] as num) * 100 : v[1]).toString();
    }
    if (widget.filter.years != null) _years.text = widget.filter.years.toString();
  }

  FundamentalField? get _field {
    for (final f in widget.fields) {
      if (f.key == widget.filter.field) return f;
    }
    return null;
  }

  bool get _isPct => _field?.dtype == 'pct';
  bool get _isMultiYear => isMultiYearField(widget.filter.field);

  @override
  Widget build(BuildContext context) {
    final field = _field;
    if (widget.stacked) return _buildStacked(field);
    // Sector / Industry: no operator, no typing — a searchable multiselect
    // that builds an `in` filter from the checked values.
    if (widget.filter.field == 'sector' ||
        widget.filter.field == 'industry') {
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 200, child: _fieldDropdown()),
        const SizedBox(width: 8),
        SizedBox(width: 320, child: _categoryMultiSelect()),
        const SizedBox(width: 4),
        IconButton(
          onPressed: widget.onRemove,
          icon: const Icon(shadcn.LucideIcons.x, size: 14),
          tooltip: 'Remove',
          visualDensity: VisualDensity.compact,
        ),
      ]);
    }
    final ops = field == null
        ? const <String>[]
        : validOpsForDtype(field.dtype, multiYear: _isMultiYear);
    final op = widget.filter.op;
    // Fixed-width value column (like the dropdowns) instead of stretching the
    // whole row; `between` / list ops get a little more room.
    final valueW = op == 'between'
        ? 320.0
        : (op == 'in' || op == 'not_in')
            ? 280.0
            : 200.0;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(width: 200, child: _fieldDropdown()),
      const SizedBox(width: 8),
      SizedBox(width: 200, child: _opDropdown(ops)),
      const SizedBox(width: 8),
      SizedBox(width: valueW, child: _valueInputs(field)),
      if (_isMultiYear) ...[
        const SizedBox(width: 8),
        SizedBox(width: 78, child: _yearsInput()),
      ],
      const SizedBox(width: 4),
      IconButton(
        onPressed: widget.onRemove,
        icon: const Icon(shadcn.LucideIcons.x, size: 14),
        tooltip: 'Remove',
        visualDensity: VisualDensity.compact,
      ),
    ]);
  }

  /// Compact layout for the redesigned left filter sidebar: the field on its
  /// own line with the remove ×, then the operator + value (+ optional years)
  /// together on one line below — half the height of a fully stacked row.
  Widget _buildStacked(FundamentalField? field) {
    final isCat =
        widget.filter.field == 'sector' || widget.filter.field == 'industry';
    final ops = field == null
        ? const <String>[]
        : validOpsForDtype(field.dtype, multiYear: _isMultiYear);
    final body = _conditionBody(field, ops, isCat);
    // Accordion mode: the field is fixed by the row it lives under, so we drop
    // the field dropdown / remove-× and render only the condition.
    if (widget.hideField) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: _fieldDropdown()),
          const SizedBox(width: 4),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(shadcn.LucideIcons.x, size: 14),
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
          ),
        ]),
        const SizedBox(height: 8),
        body,
      ],
    );
  }

  /// The condition portion of a stacked row: the category multiselect, a bare
  /// operator (for null-checks), or operator + value (+ optional years) on one
  /// compact line.
  Widget _conditionBody(
      FundamentalField? field, List<String> ops, bool isCat) {
    if (isCat) return _categoryMultiSelect();
    final op = widget.filter.op;
    if (op == 'is_null' || op == 'is_not_null') return _opDropdown(ops);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _opDropdown(ops)),
        const SizedBox(width: 8),
        Expanded(child: _valueInputs(field)),
        if (_isMultiYear && op != 'min_years') ...[
          const SizedBox(width: 8),
          SizedBox(width: 60, child: _yearsInput()),
        ],
      ],
    );
  }

  Widget _fieldDropdown() {
    final byGroup = <String, List<FundamentalField>>{};
    for (final f in widget.fields) {
      byGroup.putIfAbsent(f.group, () => []).add(f);
    }
    final opts = <FilterSelectOption>[
      for (final entry in byGroup.entries) ...[
        FilterSelectOption('', entry.key, isHeader: true),
        for (final f in entry.value) FilterSelectOption(f.key, f.label),
      ],
    ];
    return FilterSelect(
      value: widget.filter.field.isEmpty ? null : widget.filter.field,
      hint: 'Field…',
      options: opts,
      onChanged: (v) {
        // Sector / Industry default to the `in` operator (multiselect); every
        // other field keeps the current operator.
        final isCat = v == 'sector' || v == 'industry';
        widget.onChange(FundamentalFilter(
            field: v, op: isCat ? 'in' : widget.filter.op));
      },
    );
  }

  Widget _categoryMultiSelect() {
    final cats = ref.watch(fundamentalCategoriesProvider);
    final options = cats.maybeWhen(
      data: (c) =>
          widget.filter.field == 'sector' ? c.sectors : c.industries,
      orElse: () => const <String>[],
    );
    final selected = widget.filter.value is List
        ? (widget.filter.value as List).map((e) => e.toString()).toList()
        : const <String>[];
    return FilterMultiSelect(
      options: options,
      selected: selected,
      hint: widget.filter.field == 'sector'
          ? 'Select sectors…'
          : 'Select industries…',
      onChanged: (list) => widget.onChange(FundamentalFilter(
        field: widget.filter.field,
        op: 'in',
        value: list.isEmpty ? null : list,
      )),
    );
  }

  Widget _opDropdown(List<String> ops) {
    return FilterSelect(
      value: ops.contains(widget.filter.op) ? widget.filter.op : null,
      hint: 'Op',
      options: [for (final o in ops) FilterSelectOption(o, opLabel(o))],
      onChanged: (v) => widget.onChange(FundamentalFilter(
        field: widget.filter.field,
        op: v,
        value: widget.filter.value,
        years: widget.filter.years,
      )),
    );
  }

  Widget _valueInputs(FundamentalField? f) {
    if (f == null) return _placeholder();
    final op = widget.filter.op;
    if (op == 'is_null' || op == 'is_not_null') return _placeholder();
    if (op == 'min_years') return _yearsInput();
    if (op == 'between') {
      return Row(children: [
        Expanded(child: _numericInput(_v1, suffix: _isPct ? '%' : null)),
        const SizedBox(width: 4),
        Text('to',
            style: MyntWebTextStyles.body(context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary))),
        const SizedBox(width: 4),
        Expanded(child: _numericInput(_v2, suffix: _isPct ? '%' : null)),
      ]);
    }
    if (op == 'in' || op == 'not_in') {
      return FilterTextField(
        controller: _v1,
        hint: 'a, b, c',
        onChanged: (txt) => widget.onChange(FundamentalFilter(
          field: widget.filter.field,
          op: op,
          value: txt
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
        )),
      );
    }
    return _numericInput(_v1, suffix: _isPct ? '%' : null);
  }

  Widget _placeholder() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border:
            Border.all(color: shadcn.Theme.of(context).colorScheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text('—',
          style: MyntWebTextStyles.body(context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textTertiaryDark,
                  light: MyntColors.textTertiary))),
    );
  }

  Widget _numericInput(TextEditingController c, {String? suffix}) {
    return FilterTextField(
      controller: c,
      hint: 'value',
      suffix: suffix,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      onChanged: (_) => _emit(),
    );
  }

  Widget _yearsInput() {
    return FilterTextField(
      controller: _years,
      hint: 'yrs',
      keyboardType: TextInputType.number,
      onChanged: (_) => _emit(),
    );
  }

  void _emit() {
    final field = _field;
    if (field == null) return;
    final op = widget.filter.op;
    dynamic value;
    if (op == 'is_null' || op == 'is_not_null') {
      value = null;
    } else if (op == 'between') {
      final a = double.tryParse(_v1.text);
      final b = double.tryParse(_v2.text);
      if (a != null && b != null) {
        value = _isPct ? [a / 100, b / 100] : [a, b];
      }
    } else if (op == 'in' || op == 'not_in') {
      value = _v1.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      final n = double.tryParse(_v1.text);
      if (n != null) value = _isPct ? n / 100 : n;
    }
    widget.onChange(FundamentalFilter(
      field: field.key,
      op: op,
      value: value,
      years: int.tryParse(_years.text),
    ));
  }
}
