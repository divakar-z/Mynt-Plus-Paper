import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/indicator_catalog.dart';
import 'package:mynt_plus/models/scanner_model/predicate.dart';
import 'package:mynt_plus/provider/scanner/custom_scans_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/indicator_picker.dart';

// ---------------------------------------------------------------------------
// Internal mutable tree used by the builder. Converts to/from PredicateNode.
// ---------------------------------------------------------------------------

abstract class _BNode {
  PredicateNode toNode();
}

class _BGroup extends _BNode {
  /// Wire DSL combinator keys: `all` (AND), `any` (OR), `none` (NOT).
  String op;
  List<_BNode> children;
  _BGroup({required this.op, required this.children});

  @override
  PredicateNode toNode() {
    final kids = children.map((c) => c.toNode()).toList();
    switch (op) {
      case 'any':
        return PredicateOr(kids);
      case 'none':
        return PredicateNone(kids);
      case 'all':
      default:
        return PredicateAnd(kids);
    }
  }
}

class _BLeaf extends _BNode {
  String? leftIndicator;
  Map<String, dynamic> leftParams;
  String op;
  bool rightIsValue;
  num? rightValueA;
  num? rightValueB;
  String? rightIndicator;
  Map<String, dynamic> rightParams;

  _BLeaf({
    this.leftIndicator,
    Map<String, dynamic>? leftParams,
    this.op = '<',
    this.rightIsValue = true,
    this.rightValueA,
    this.rightValueB,
    this.rightIndicator,
    Map<String, dynamic>? rightParams,
  })  : leftParams = leftParams ?? <String, dynamic>{},
        rightParams = rightParams ?? <String, dynamic>{};

  @override
  PredicateNode toNode() {
    final left = leftIndicator == null
        ? IndicatorRef.number(0)
        : IndicatorRef.indicator(leftIndicator!, leftParams);
    IndicatorRef right;
    if (rightIsValue) {
      if (op == 'between' && rightValueA != null && rightValueB != null) {
        right = IndicatorRef.range(rightValueA!, rightValueB!);
      } else {
        right = IndicatorRef.number(rightValueA ?? 0);
      }
    } else {
      right = rightIndicator == null
          ? IndicatorRef.number(0)
          : IndicatorRef.indicator(rightIndicator!, rightParams);
    }
    return PredicateLeaf(left: left, op: op, right: right);
  }
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

class PredicateBuilder extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initial;
  final ValueChanged<Map<String, dynamic>> onChange;

  const PredicateBuilder({super.key, this.initial, required this.onChange});

  @override
  ConsumerState<PredicateBuilder> createState() => _PredicateBuilderState();
}

class _PredicateBuilderState extends ConsumerState<PredicateBuilder> {
  late _BGroup _root;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null && widget.initial!.isNotEmpty) {
      try {
        final node = PredicateNode.fromJson(widget.initial!);
        final fromNode = _hydrate(node);
        _root = fromNode is _BGroup
            ? fromNode
            : _BGroup(op: 'all', children: [fromNode]);
      } catch (_) {
        _root = _BGroup(op: 'all', children: [_BLeaf()]);
      }
    } else {
      _root = _BGroup(op: 'all', children: [_BLeaf()]);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  _BNode _hydrate(PredicateNode n) {
    if (n is PredicateAnd) {
      return _BGroup(op: 'all', children: n.children.map(_hydrate).toList());
    }
    if (n is PredicateOr) {
      return _BGroup(op: 'any', children: n.children.map(_hydrate).toList());
    }
    if (n is PredicateNone) {
      return _BGroup(op: 'none', children: n.children.map(_hydrate).toList());
    }
    if (n is PredicateLeaf) {
      final leaf = _BLeaf(op: n.op);
      if (n.left.indicator != null) {
        leaf.leftIndicator = n.left.indicator;
        leaf.leftParams = Map.of(n.left.indicatorParams);
      }
      if (n.right.indicator != null) {
        leaf.rightIsValue = false;
        leaf.rightIndicator = n.right.indicator;
        leaf.rightParams = Map.of(n.right.indicatorParams);
      } else if (n.right.literalRange != null) {
        leaf.rightIsValue = true;
        leaf.rightValueA = n.right.literalRange![0];
        leaf.rightValueB = n.right.literalRange![1];
      } else if (n.right.literalNumber != null) {
        leaf.rightIsValue = true;
        leaf.rightValueA = n.right.literalNumber;
      }
      return leaf;
    }
    return _BLeaf();
  }

  void _emit() => widget.onChange(_root.toNode().toJson());

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(indicatorCatalogProvider);
    return catalogAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load indicator catalog',
        message: e.toString(),
        onRetry: () => ref.invalidate(indicatorCatalogProvider),
      ),
      data: (catalog) => _buildGroup(catalog, _root, depth: 0),
    );
  }

  // -------------------------------------------------------------------------
  // GROUP — bordered card with combinator header, child cards separated by
  // connector chips, and a footer row of add-actions.
  // -------------------------------------------------------------------------

  Widget _buildGroup(IndicatorCatalog catalog, _BGroup g,
      {required int depth}) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final nestedBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);

    return Container(
      margin: EdgeInsets.symmetric(vertical: depth == 0 ? 0 : 6),
      decoration: BoxDecoration(
        color: depth == 0 ? Colors.transparent : nestedBg,
        border: Border.all(
            color: depth == 0 ? border.withValues(alpha: 0.5) : border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _groupHeader(g),
          // Body: child cards with connector chips between them.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < g.children.length; i++) ...[
                  if (i > 0) _ConnectorChip(op: g.op),
                  Builder(builder: (_) {
                    final child = g.children[i];
                    final index = i + 1;
                    if (child is _BGroup) {
                      return _buildGroup(catalog, child, depth: depth + 1);
                    }
                    return _buildLeafCard(
                      catalog,
                      child as _BLeaf,
                      index: index,
                      onRemove: () => setState(() {
                        g.children.removeAt(i);
                        _emit();
                      }),
                      cardBg: cardBg,
                      border: border,
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupHeader(_BGroup g) {
    final headerBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Row(children: [
        Text('MATCH',
            style: MyntWebTextStyles.caption(context,
                    fontWeight: MyntFonts.semiBold, color: secondary)
                .copyWith(letterSpacing: 1.0)),
        const SizedBox(width: 10),
        _CombinatorSegmented(
          value: g.op,
          onChanged: (v) => setState(() {
            g.op = v;
            _emit();
          }),
        ),
        const SizedBox(width: 10),
        Text('of the following:',
            style: MyntWebTextStyles.caption(context, color: secondary)),
        const Spacer(),
        TextButton.icon(
          icon: const Icon(shadcn.LucideIcons.plus, size: 14),
          label: const Text('Condition'),
          onPressed: () => setState(() {
            g.children.add(_BLeaf());
            _emit();
          }),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          icon: const Icon(shadcn.LucideIcons.layers, size: 14),
          label: const Text('Group'),
          onPressed: () => setState(() {
            g.children.add(_BGroup(op: 'all', children: [_BLeaf()]));
            _emit();
          }),
        ),
      ]),
    );
  }

  // -------------------------------------------------------------------------
  // LEAF CARD — numbered, field-labelled, kind-specific bottom section.
  // -------------------------------------------------------------------------

  Widget _buildLeafCard(
    IndicatorCatalog catalog,
    _BLeaf l, {
    required int index,
    required VoidCallback onRemove,
    required Color cardBg,
    required Color border,
  }) {
    final leftDef = l.leftIndicator == null
        ? null
        : catalog.byName(l.leftIndicator!);

    // Sync op to the appropriate set when the indicator changes.
    if (leftDef != null) {
      switch (leftDef.kind) {
        case IndicatorKind.booleanKind:
          if (l.op != '==' && l.op != '!=') l.op = '!=';
          l.rightIsValue = true;
          l.rightValueA = 0;
          break;
        case IndicatorKind.enumKind:
          if (!kEnumOperators.contains(l.op)) l.op = '==';
          l.rightIsValue = true;
          break;
        case IndicatorKind.floatKind:
          if (!kFloatOperators.contains(l.op) && l.op != 'between') {
            l.op = '<';
          }
          break;
      }
    }

    final category = leftDef == null
        ? null
        : catalog.categories.firstWhere(
            (c) => c.key == leftDef.category,
            orElse: () =>
                IndicatorCategory(key: leftDef.category, label: leftDef.category),
          );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card header — number + indicator title + remove
          _leafHeader(index, leftDef, category, onRemove),
          const Divider(height: 1),
          // Card body — INDICATOR row, then kind-specific OP/VALUE row.
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _indicatorSection(catalog, l, leftDef),
                if (leftDef != null) ...[
                  const SizedBox(height: 14),
                  _kindSpecificSection(catalog, leftDef, l),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leafHeader(int index, CatalogIndicator? leftDef,
      IndicatorCategory? category, VoidCallback onRemove) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          _NumberedBadge(index: index),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  leftDef?.label ?? 'New condition',
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.semiBold),
                ),
                if (category != null)
                  Text(category.label,
                      style: MyntWebTextStyles.caption(context,
                          color: secondary)),
              ],
            ),
          ),
          if (leftDef?.needsBenchmark == true) ...[
            const _BenchmarkChip(),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: onRemove,
            icon: const Icon(shadcn.LucideIcons.x, size: 16),
            tooltip: 'Remove condition',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _indicatorSection(
      IndicatorCatalog catalog, _BLeaf l, CatalogIndicator? leftDef) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('INDICATOR'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: IndicatorPicker(
                catalog: catalog,
                value: l.leftIndicator,
                onChanged: (v) => setState(() {
                  l.leftIndicator = v;
                  l.leftParams = _defaultParamsFor(catalog, v);
                  _emit();
                }),
              ),
            ),
            if (leftDef != null)
              ..._paramInputs(leftDef, l.leftParams, () => _emit()),
          ],
        ),
      ],
    );
  }

  Widget _kindSpecificSection(
      IndicatorCatalog catalog, CatalogIndicator leftDef, _BLeaf l) {
    switch (leftDef.kind) {
      case IndicatorKind.booleanKind:
        return _booleanSection(l);
      case IndicatorKind.enumKind:
        return _enumSection(leftDef, l);
      case IndicatorKind.floatKind:
        return _floatSection(catalog, l);
    }
  }

  // ----- BOOLEAN: pattern formed / not formed ------------------------------

  Widget _booleanSection(_BLeaf l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('PATTERN'),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: '!=',
              icon: Icon(Icons.check, size: 14),
              label: Text('Formed'),
            ),
            ButtonSegment(
              value: '==',
              icon: Icon(Icons.close, size: 14),
              label: Text('Not formed'),
            ),
          ],
          selected: {l.op == '==' ? '==' : '!='},
          onSelectionChanged: (s) => setState(() {
            l.op = s.first;
            l.rightIsValue = true;
            l.rightValueA = 0;
            _emit();
          }),
        ),
      ],
    );
  }

  // ----- ENUM: == / != + enum_values dropdown ------------------------------

  Widget _enumSection(CatalogIndicator leftDef, _BLeaf l) {
    final values = leftDef.enumValues ?? const <CatalogEnumValue>[];
    return Wrap(spacing: 14, runSpacing: 10, children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('IS'),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '==', label: Text('equal to')),
              ButtonSegment(value: '!=', label: Text('not equal to')),
            ],
            selected: {kEnumOperators.contains(l.op) ? l.op : '=='},
            onSelectionChanged: (s) => setState(() {
              l.op = s.first;
              _emit();
            }),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('VALUE'),
          const SizedBox(height: 6),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<num>(
              isDense: true,
              isExpanded: true,
              decoration: _boxDecoration(),
              value: l.rightValueA != null &&
                      values.any((v) => v.value == l.rightValueA)
                  ? l.rightValueA
                  : (values.isNotEmpty ? values.first.value : null),
              hint: const Text('Pick value'),
              items: [
                for (final v in values)
                  DropdownMenuItem(value: v.value, child: Text(v.label)),
              ],
              onChanged: (v) => setState(() {
                l.rightIsValue = true;
                l.rightValueA = v;
                _emit();
              }),
            ),
          ),
        ],
      ),
    ]);
  }

  // ----- FLOAT: op dropdown + Value/Indicator toggle -----------------------

  Widget _floatSection(IndicatorCatalog catalog, _BLeaf l) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Wrap(spacing: 14, runSpacing: 10, children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('OPERATOR'),
          const SizedBox(height: 6),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              isDense: true,
              isExpanded: true,
              decoration: _boxDecoration(),
              value: kFloatOperators.contains(l.op) ? l.op : '<',
              items: [
                for (final o in kFloatOperators)
                  DropdownMenuItem(value: o, child: Text(_opLabel(o))),
              ],
              onChanged: (v) => setState(() {
                if (v != null) l.op = v;
                _emit();
              }),
            ),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(l.rightIsValue ? 'VALUE' : 'INDICATOR'),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Value')),
                ButtonSegment(value: false, label: Text('Indicator')),
              ],
              selected: {l.rightIsValue},
              onSelectionChanged: (s) => setState(() {
                l.rightIsValue = s.first;
                _emit();
              }),
            ),
            const SizedBox(width: 10),
            if (l.rightIsValue)
              SizedBox(
                width: 140,
                child: TextFormField(
                  initialValue: l.rightValueA?.toString() ?? '',
                  decoration: _boxDecoration().copyWith(hintText: 'value'),
                  style: MyntWebTextStyles.body(context),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  onChanged: (v) {
                    l.rightValueA = num.tryParse(v);
                    _emit();
                  },
                ),
              )
            else
              SizedBox(
                width: 220,
                child: IndicatorPicker(
                  catalog: catalog,
                  value: l.rightIndicator,
                  onChanged: (v) => setState(() {
                    l.rightIndicator = v;
                    l.rightParams = _defaultParamsFor(catalog, v);
                    _emit();
                  }),
                ),
              ),
          ]),
          if (!l.rightIsValue && l.rightIndicator != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 220),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('with',
                      style: MyntWebTextStyles.caption(context,
                          color: secondary)),
                  ..._paramInputs(
                      catalog.byName(l.rightIndicator!) ??
                          _emptyIndicator(l.rightIndicator!),
                      l.rightParams,
                      () => _emit()),
                ],
              ),
            ),
          ],
        ],
      ),
    ]);
  }

  String _opLabel(String op) {
    switch (op) {
      case '<':
        return '<  less than';
      case '<=':
        return '≤  less or equal';
      case '>':
        return '>  greater than';
      case '>=':
        return '≥  greater or equal';
      case '==':
        return '=  equals';
      case '!=':
        return '≠  not equal';
      default:
        return op;
    }
  }

  InputDecoration _boxDecoration() => InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide:
              BorderSide(color: shadcn.Theme.of(context).colorScheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide:
              BorderSide(color: shadcn.Theme.of(context).colorScheme.border),
        ),
      );

  // -------------------------------------------------------------------------
  // Param inputs (unchanged behavior, lightly restyled to match _boxDecoration)
  // -------------------------------------------------------------------------

  List<Widget> _paramInputs(CatalogIndicator def, Map<String, dynamic> store,
      VoidCallback onChange) {
    if (def.params.isEmpty) return const [];
    return [
      for (final p in def.params)
        SizedBox(
          width: _paramWidthFor(p),
          child: _paramInput(p, store, onChange),
        ),
    ];
  }

  Widget _paramInput(CatalogParam p, Map<String, dynamic> store,
      VoidCallback onChange) {
    final current = store[p.name] ?? p.defaultValue;
    final label = p.label;
    final dec = _boxDecoration().copyWith(labelText: label);
    switch (p.type) {
      case CatalogParamType.intType:
      case CatalogParamType.floatType:
        return TextFormField(
          initialValue: current?.toString() ?? '',
          decoration: dec,
          style: MyntWebTextStyles.body(context),
          keyboardType: TextInputType.numberWithOptions(
            decimal: p.type == CatalogParamType.floatType,
            signed: true,
          ),
          onChanged: (v) {
            final parsed = p.type == CatalogParamType.intType
                ? int.tryParse(v)
                : num.tryParse(v);
            if (parsed == null) {
              store.remove(p.name);
            } else if (_inRange(parsed, p.min, p.max)) {
              store[p.name] = parsed;
            }
            onChange();
          },
        );
      case CatalogParamType.stringType:
        if (p.options != null && p.options!.isNotEmpty) {
          return DropdownButtonFormField<String>(
            isDense: true,
            isExpanded: true,
            value: p.options!.contains(current) ? current as String : null,
            decoration: dec,
            items: [
              for (final o in p.options!)
                DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: (v) {
              if (v != null) store[p.name] = v;
              onChange();
            },
          );
        }
        return TextFormField(
          initialValue: current?.toString() ?? '',
          decoration: dec,
          style: MyntWebTextStyles.body(context),
          onChanged: (v) {
            if (v.isEmpty) {
              store.remove(p.name);
            } else {
              store[p.name] = v;
            }
            onChange();
          },
        );
      case CatalogParamType.columnType:
        final opts = p.options ??
            const ['close', 'open', 'high', 'low', 'volume'];
        return DropdownButtonFormField<String>(
          isDense: true,
          isExpanded: true,
          value: opts.contains(current)
              ? current as String
              : (opts.isNotEmpty ? opts.first : null),
          decoration: dec,
          items: [
            for (final o in opts) DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) {
            if (v != null) store[p.name] = v;
            onChange();
          },
        );
    }
  }

  double _paramWidthFor(CatalogParam p) {
    switch (p.type) {
      case CatalogParamType.intType:
      case CatalogParamType.floatType:
        return 110;
      case CatalogParamType.columnType:
        return 130;
      case CatalogParamType.stringType:
        return p.options != null ? 150 : 180;
    }
  }

  bool _inRange(num v, num? min, num? max) {
    if (min != null && v < min) return false;
    if (max != null && v > max) return false;
    return true;
  }

  Map<String, dynamic> _defaultParamsFor(
      IndicatorCatalog catalog, String? indicatorName) {
    if (indicatorName == null) return <String, dynamic>{};
    final def = catalog.byName(indicatorName);
    if (def == null) return <String, dynamic>{};
    final out = <String, dynamic>{};
    for (final p in def.params) {
      if (p.defaultValue != null) out[p.name] = p.defaultValue;
    }
    return out;
  }

  CatalogIndicator _emptyIndicator(String name) => CatalogIndicator(
        name: name,
        label: name,
        category: 'other',
        kind: IndicatorKind.floatKind,
        description: '',
        params: const [],
      );
}

// ---------------------------------------------------------------------------
// Tiny visual primitives
// ---------------------------------------------------------------------------

/// Small caps label that sits above a form input.
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return Text(
      text,
      style: MyntWebTextStyles.caption(context,
              fontWeight: MyntFonts.semiBold, color: tertiary)
          .copyWith(letterSpacing: 0.9),
    );
  }
}

/// Numbered circle badge — `① ② ③` style for ordering conditions.
class _NumberedBadge extends StatelessWidget {
  final int index;
  const _NumberedBadge({required this.index});

  @override
  Widget build(BuildContext context) {
    const primary = MyntColors.primary;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        '$index',
        style: MyntWebTextStyles.caption(context,
            fontWeight: MyntFonts.bold, color: primary),
      ),
    );
  }
}

/// Connector chip rendered BETWEEN sibling cards. Shows AND / OR / NOT
/// in a small primary-tinted pill flanked by hairlines on both sides.
class _ConnectorChip extends StatelessWidget {
  /// Parent group's combinator: `all` / `any` / `none`.
  final String op;
  const _ConnectorChip({required this.op});

  String get _label {
    switch (op) {
      case 'any':
        return 'OR';
      case 'none':
        return 'NOT';
      case 'all':
      default:
        return 'AND';
    }
  }

  Color _color() {
    switch (op) {
      case 'any':
        return const Color(0xFFA855F7); // violet
      case 'none':
        return MyntColors.warning;
      case 'all':
      default:
        return MyntColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final border = shadcn.Theme.of(context).colorScheme.border;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Container(height: 1, color: border)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _label,
            style: MyntWebTextStyles.caption(context,
                    fontWeight: MyntFonts.bold, color: color)
                .copyWith(letterSpacing: 1.2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: border)),
      ]),
    );
  }
}

/// Segmented control for the group combinator — replaces the cramped
/// dropdown.
class _CombinatorSegmented extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CombinatorSegmented({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'all', label: Text('All (AND)')),
        ButtonSegment(value: 'any', label: Text('Any (OR)')),
        ButtonSegment(value: 'none', label: Text('None (NOT)')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
      ),
    );
  }
}

/// "Compared vs NIFTY benchmark" chip — surfaced for indicators with
/// `needs_benchmark === true`.
class _BenchmarkChip extends StatelessWidget {
  const _BenchmarkChip();
  @override
  Widget build(BuildContext context) {
    const primary = MyntColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(shadcn.LucideIcons.flag, size: 11, color: primary),
        const SizedBox(width: 4),
        Text('vs NIFTY benchmark',
            style: MyntWebTextStyles.caption(context,
                color: primary, fontWeight: MyntFonts.medium)),
      ]),
    );
  }
}
