import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/filter_inputs.dart';
import 'package:mynt_plus/screens/web/scanner/sub_pages/fundamentals_builder_state.dart';

class FundamentalFilterRow extends StatefulWidget {
  final List<FundamentalField> fields;
  final FundamentalFilter filter;
  final ValueChanged<FundamentalFilter> onChange;
  final VoidCallback onRemove;

  const FundamentalFilterRow({
    super.key,
    required this.fields,
    required this.filter,
    required this.onChange,
    required this.onRemove,
  });

  @override
  State<FundamentalFilterRow> createState() => _FundamentalFilterRowState();
}

class _FundamentalFilterRowState extends State<FundamentalFilterRow> {
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
      onChanged: (v) =>
          widget.onChange(FundamentalFilter(field: v, op: widget.filter.op)),
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
