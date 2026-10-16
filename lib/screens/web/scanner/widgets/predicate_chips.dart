import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/indicator_catalog.dart';
import 'package:mynt_plus/models/scanner_model/predicate.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/scanner_tokens.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/filter_inputs.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/metric_picker_modal.dart';

// ---------------------------------------------------------------------------
// Fundamentals-style chip editor for technical scan predicates. Used by the
// predefined-scanner detail page and the Custom Scans builder.
// ---------------------------------------------------------------------------

/// Deep copy, so edits never touch the source predicate.
Map<String, dynamic> copyPredicate(Map<String, dynamic> p) =>
    jsonDecode(jsonEncode(p)) as Map<String, dynamic>;

/// Number of comparison conditions in a predicate.
int predicateConditionCount(Map<String, dynamic> p) => _leavesOf(p).length;

/// Copy of [p] with empty groups (`{all: []}` etc.) removed at every level,
/// ready to send to the server.
Map<String, dynamic> cleanPredicate(Map<String, dynamic> p) {
  final out = copyPredicate(p);
  void prune(Map<String, dynamic> g) {
    final k = _groupKey(g);
    if (k == null) return;
    final kids = g[k] as List;
    for (final c in kids) {
      if (c is Map<String, dynamic>) prune(c);
    }
    kids.removeWhere((c) =>
        c is Map<String, dynamic> &&
        _groupKey(c) != null &&
        (c[_groupKey(c)] as List).isEmpty);
  }

  prune(out);
  return out;
}

/// `all` / `any` / `none` when [n] is a group, else null.
String? _groupKey(Map<String, dynamic> n) {
  for (final k in const ['all', 'any', 'none']) {
    if (n[k] is List) return k;
  }
  return null;
}

/// The filter tray from the fundamental screener, over a scan predicate:
/// [+ add] [add group] [reset] [group…] [actions]. The root is always shown
/// as a group with its own All (AND) / Any (OR) / None (NOT) selector; nested
/// groups render as bordered boxes inline with the chips. Everything edits
/// [predicate] in place and then calls [onChanged].
class PredicateFilterTray extends StatelessWidget {
  final Map<String, dynamic> predicate;
  final IndicatorCatalog? catalog;
  final ValueChanged<Map<String, dynamic>> onChanged;

  /// Null hides nothing — the Reset button just shows disabled.
  final VoidCallback? onReset;
  final String resetTooltip;

  /// Predefined scanners keep at least one condition; a custom scan may be
  /// emptied completely.
  final bool keepOne;

  /// Custom Scans edit AND / OR / NOT groups (selector, connectors, Add
  /// group). Predefined scanners only edit their chips — any existing
  /// grouping shows as a plain "Any of" / "None of" label.
  final bool allowGroups;
  final List<Widget> actions;

  const PredicateFilterTray({
    super.key,
    required this.predicate,
    required this.catalog,
    required this.onChanged,
    required this.onReset,
    this.resetTooltip = 'Reset',
    this.keepOne = false,
    this.allowGroups = true,
    this.actions = const [],
  });

  int get _min => keepOne ? 1 : 0;

  /// Nested groups can go this deep below the root.
  static const int _maxDepth = 3;

  /// Every control in the tray (buttons, selector, chips) is [_kCtl] tall and
  /// sits centred in a [_kSlot]-tall row slot. A one-line nested group box is
  /// exactly [_kSlot] tall, so everything shares one centre line.
  static const double _kCtl = 32;
  static const double _kSlot = 40;

  /// The root is always edited as a group — a bare-leaf (or unreadable)
  /// root is wrapped as `{all: [...]}` in place, which matches the same.
  void _normalizeRoot() {
    if (_groupKey(predicate) != null) return;
    final isLeaf = predicate['left'] is Map && predicate['right'] is Map;
    final leaf = isLeaf ? Map<String, dynamic>.from(predicate) : null;
    predicate
      ..clear()
      ..['all'] = <dynamic>[if (leaf != null) leaf];
  }

  /// "Add filters" dialog (the fundamental screener's picker) for the group
  /// whose children are [kids]. Newly ticked indicators get a condition in
  /// that group; unticked ones lose theirs (only that group's own chips).
  Future<void> _openPicker(
      BuildContext context, IndicatorCatalog cat, List kids) async {
    String? nameOf(Object? c) {
      if (c is! Map<String, dynamic> || _groupKey(c) != null) return null;
      final left = c['left'];
      return left is Map ? left['indicator']?.toString() : null;
    }
    final current = {
      for (final c in kids)
        if (nameOf(c) != null) nameOf(c)!,
    };
    final result = await showMetricPicker(
      context,
      fields: const [],
      catalog: cat,
      selectedFundamentals: const {},
      selectedTechnicals: current,
      allIndicatorKinds: true,
    );
    if (result == null) return;
    final picked = result.technicalNames;
    final removed = current.difference(picked);
    for (final c in List.of(kids)) {
      if (!removed.contains(nameOf(c))) continue;
      if (_leavesOf(predicate).length <= _min) break;
      kids.remove(c);
    }
    for (final name in picked.difference(current)) {
      kids.add(_newLeaf(name, cat));
    }
    onChanged(predicate);
  }

  void _addGroup(List kids) {
    kids.add(<String, dynamic>{'all': <dynamic>[]});
    onChanged(predicate);
  }

  /// Switches a group between all / any / none, keeping its children.
  void _setGroupOp(Map<String, dynamic> g, String op) {
    final k = _groupKey(g);
    if (k == null || k == op) return;
    g[op] = g.remove(k);
    onChanged(predicate);
  }

  @override
  Widget build(BuildContext context) {
    _normalizeRoot();
    final cat = catalog;
    final rootKids = predicate[_groupKey(predicate)] as List;
    return Container(
      decoration: ScannerTokens.tray(context),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        // Top-aligned so the buttons and actions stay on the first line when
        // the chips wrap; each side sits in a _kSlot-tall slot.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _kSlot,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ScannerChipButton(
                icon: Icons.add,
                tooltip: 'Add filter',
                height: _kCtl,
                onTap: cat == null
                    ? null
                    : () => _openPicker(context, cat, rootKids),
              ),
              if (allowGroups) ...[
                const SizedBox(width: 8),
                ScannerChipButton(
                  icon: shadcn.LucideIcons.layers,
                  tooltip: 'Add group',
                  height: _kCtl,
                  onTap: () => _addGroup(rootKids),
                ),
              ],
              const SizedBox(width: 8),
              ScannerChipButton(
                icon: shadcn.LucideIcons.rotateCcw,
                tooltip: resetTooltip,
                accent: true,
                height: _kCtl,
                onTap: onReset,
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: _group(context, predicate, 0)),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 12),
            SizedBox(
              height: _kSlot,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
          ],
        ],
      ),
    );
  }

  /// Centres a root-level item in a [_kSlot]-tall slot (nested group boxes
  /// are already that tall on one line, and grow when they wrap).
  Widget _slot(Widget child) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kSlot),
        child: Align(widthFactor: 1, heightFactor: 1, child: child),
      );

  /// One group's contents: its combinator selector, then each child (chip or
  /// nested group box) with an AND / OR / NOT connector between them.
  Widget _group(BuildContext context, Map<String, dynamic> g, int depth) {
    final key = _groupKey(g)!;
    final kids = g[key] as List;
    final total = _leavesOf(predicate).length;
    final muted = ScannerTokens.textSecondary(context);
    final children = <Widget>[
      if (allowGroups)
        _CombinatorSelect(
          value: key,
          onChanged: (v) => _setGroupOp(g, v),
        )
      // Read-only: plain chips read as AND, so only label ANY / NONE.
      else if (key != 'all')
        Text(key == 'any' ? 'Any of' : 'None of',
            style: MyntWebTextStyles.body(context,
                fontWeight: MyntFonts.medium,
                color: ScannerTokens.textBody(context))),
    ];
    if (kids.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
            depth == 0
                ? 'Click + to add your first filter'
                : 'Empty group — click + to add filters',
            style: MyntWebTextStyles.body(context, color: muted)),
      ));
    }
    var first = true;
    for (final c in kids) {
      if (c is! Map<String, dynamic>) continue;
      if (!first && allowGroups) children.add(_Connector(op: key));
      first = false;
      if (_groupKey(c) != null) {
        children.add(_nestedGroup(context, c, kids, depth + 1, total));
      } else {
        children.add(_ConditionChip(
          key: ObjectKey(c),
          leaf: c,
          catalog: catalog,
          onChanged: () => onChanged(predicate),
          onDelete: total > _min
              ? () {
                  kids.remove(c);
                  onChanged(predicate);
                }
              : null,
        ));
      }
    }
    // Root level: every item in a centred slot, top-aligned per line, so a
    // wrapping nested group doesn't push its neighbours off the centre line.
    // Inside a group everything is _kCtl tall, so plain centring is enough.
    final root = depth == 0;
    return Wrap(
      spacing: 8,
      runSpacing: root ? 4 : 6,
      crossAxisAlignment:
          root ? WrapCrossAlignment.start : WrapCrossAlignment.center,
      children: root ? [for (final w in children) _slot(w)] : children,
    );
  }

  /// A nested group as a bordered box inline with the chips: its contents,
  /// then small + (add filter), add-group and × (remove group) icons.
  Widget _nestedGroup(BuildContext context, Map<String, dynamic> g,
      List parentKids, int depth, int total) {
    final kids = g[_groupKey(g)] as List;
    final cat = catalog;
    final removable = total - _leavesOf(g).length >= _min;
    // 1px border + 3px padding around _kCtl-tall contents = _kSlot on one
    // line, matching the slots around it.
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 2, 3),
      decoration: BoxDecoration(
        color: ScannerTokens.surface(context),
        borderRadius: BorderRadius.circular(ScannerTokens.rControl),
        border: Border.all(
            color: ScannerTokens.accent(context).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _group(context, g, depth)),
          const SizedBox(width: 4),
          if (allowGroups) ...[
            _TinyIcon(
              icon: Icons.add,
              tooltip: 'Add filter to this group',
              onTap:
                  cat == null ? null : () => _openPicker(context, cat, kids),
            ),
            if (depth < _maxDepth)
              _TinyIcon(
                icon: shadcn.LucideIcons.layers,
                tooltip: 'Add group inside',
                onTap: () => _addGroup(kids),
              ),
            _TinyIcon(
              icon: shadcn.LucideIcons.x,
              tooltip: 'Remove group',
              onTap: removable
                  ? () {
                      parentKids.remove(g);
                      onChanged(predicate);
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// All (AND) / Any (OR) / None (NOT) selector at the head of each group.
class _CombinatorSelect extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CombinatorSelect({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      child: FilterSelect(
        value: value,
        hint: 'Match',
        height: PredicateFilterTray._kCtl,
        borderColor: ScannerTokens.accent(context).withValues(alpha: 0.35),
        options: const [
          FilterSelectOption('all', 'All (AND)'),
          FilterSelectOption('any', 'Any (OR)'),
          FilterSelectOption('none', 'None (NOT)'),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Small AND / OR / NOT tag between siblings of a group.
class _Connector extends StatelessWidget {
  final String op;
  const _Connector({required this.op});

  @override
  Widget build(BuildContext context) {
    final accent = ScannerTokens.accent(context);
    final label = switch (op) {
      'any' => 'OR',
      'none' => 'NOT',
      _ => 'AND',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: MyntWebTextStyles.caption(context,
                  fontWeight: MyntFonts.bold, color: accent)
              .copyWith(letterSpacing: 1)),
    );
  }
}

/// Compact icon action inside a nested group box.
class _TinyIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _TinyIcon({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = ScannerTokens.textSecondary(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon,
              size: 14,
              color: onTap == null ? muted.withValues(alpha: 0.4) : muted),
        ),
      ),
    );
  }
}

/// A fresh condition for [name] with the catalog's default params and the
/// same default comparison the old Custom Scans builder used.
Map<String, dynamic> _newLeaf(String name, IndicatorCatalog catalog) {
  final def = catalog.byName(name);
  final left = <String, dynamic>{'indicator': name};
  for (final p in def?.params ?? const <CatalogParam>[]) {
    if (p.defaultValue != null) left[p.name] = p.defaultValue;
  }
  return switch (def?.kind) {
    IndicatorKind.booleanKind => {
        'left': left,
        'op': '!=',
        'right': {'value': 0},
      },
    IndicatorKind.enumKind => {
        'left': left,
        'op': '==',
        'right': {'value': def?.enumValues?.firstOrNull?.value ?? 0},
      },
    _ => {
        'left': left,
        'op': '>',
        'right': {'value': 0},
      },
  };
}

/// One comparison leaf of the predicate tree plus the group list that holds
/// it (null when the whole predicate is a single leaf), so it can be removed.
class _LeafRef {
  final Map<String, dynamic> node;
  final List? parent;
  const _LeafRef(this.node, this.parent);
}

/// Flattens every `{left, op, right}` leaf under all / any / none groups.
List<_LeafRef> _leavesOf(Map<String, dynamic> node, [List? parent]) {
  for (final k in const ['all', 'any', 'none']) {
    final list = node[k];
    if (list is List) {
      return [
        for (final c in list)
          if (c is Map<String, dynamic>) ..._leavesOf(c, list),
      ];
    }
  }
  if (node['left'] is Map && node['right'] is Map) {
    return [_LeafRef(node, parent)];
  }
  return const [];
}

const Map<String, String> _opSymbols = {
  '<': '<',
  '<=': '≤',
  '>': '>',
  '>=': '≥',
  '==': '=',
  '!=': '≠',
  'between': 'between',
  'crossed_above': 'crossed above',
  'crossed_below': 'crossed below',
};

String _fmtNum(Object? v) {
  if (v is num) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
  return v?.toString() ?? '';
}

/// `{indicator: rsi, period: 14}` → `RSI(14)`, `{value: 30}` → `30`.
String _operandLabel(Map<String, dynamic> o, IndicatorCatalog? catalog) {
  if (o.containsKey('value')) {
    final v = o['value'];
    return v is List ? v.map(_fmtNum).join(' – ') : _fmtNum(v);
  }
  final name = o['indicator']?.toString() ?? '';
  final label = catalog?.byName(name)?.label ?? name.toUpperCase();
  final params = [
    for (final e in o.entries)
      if (e.key != 'indicator') _fmtNum(e.value),
  ];
  return params.isEmpty ? label : '$label(${params.join(', ')})';
}

/// Bordered chip button from the fundamental screener — the filter-row
/// + / Reset buttons (icon only) and the header Save / Download buttons
/// (icon + label, 34px tall). [accent] tints the icon with the brand colour.
class ScannerChipButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final bool accent;
  final double? height;

  /// Overrides the icon colour when enabled (e.g. red for Delete).
  final Color? iconColor;
  final VoidCallback? onTap;
  const ScannerChipButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
    this.accent = false,
    this.height,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = ScannerTokens.textSecondary(context);
    final disabled = onTap == null;
    final resolvedIcon = disabled
        ? secondary.withValues(alpha: 0.4)
        : iconColor ??
            (accent ? ScannerTokens.accent(context) : secondary);
    final labelColor = disabled
        ? secondary.withValues(alpha: 0.4)
        : ScannerTokens.textPrimary(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: resolveThemeColor(context,
              dark: MyntColors.cardHoverDark, light: MyntColors.cardHover),
          child: Container(
            height: height,
            // Icon-only buttons with a set height are square.
            width: label == null ? height : null,
            alignment: height != null ? Alignment.center : null,
            padding: height != null && label == null
                ? EdgeInsets.zero
                : EdgeInsets.symmetric(
                    horizontal: label != null ? 10 : 6, vertical: 4),
            decoration: BoxDecoration(
              color: ScannerTokens.surface(context),
              border: Border.all(color: ScannerTokens.border(context)),
              borderRadius: BorderRadius.circular(ScannerTokens.rTag),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: resolvedIcon),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(label!,
                      style: MyntWebTextStyles.body(context,
                          fontWeight: MyntFonts.medium, color: labelColor)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter chip for one predicate condition — label + current value, opening a
/// popover to edit the indicator's params, the operator and the value. Edits
/// are written straight into [leaf]; [onChanged] tells the pane it's dirty.
class _ConditionChip extends StatefulWidget {
  final Map<String, dynamic> leaf;
  final IndicatorCatalog? catalog;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const _ConditionChip({
    super.key,
    required this.leaf,
    required this.catalog,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_ConditionChip> createState() => _ConditionChipState();
}

class _ConditionChipState extends State<_ConditionChip> {
  final GlobalKey _key = GlobalKey();
  final TextEditingController _v1 = TextEditingController();
  final TextEditingController _v2 = TextEditingController();
  final Map<String, TextEditingController> _params = {};
  OverlayEntry? _overlay;
  bool _hover = false;

  Map<String, dynamic> get _left =>
      widget.leaf['left'] as Map<String, dynamic>;
  Map<String, dynamic> get _right =>
      widget.leaf['right'] as Map<String, dynamic>;
  String get _op => widget.leaf['op']?.toString() ?? '';

  CatalogIndicator? get _indicator {
    final name = _left['indicator']?.toString();
    return name == null ? null : widget.catalog?.byName(name);
  }

  /// Pattern / flag conditions (`cdl_x != 0`) edit as Yes / No instead of a
  /// raw comparison against zero.
  bool get _isFlag {
    final name = _left['indicator']?.toString() ?? '';
    final flagKind = _indicator?.kind == IndicatorKind.booleanKind ||
        name.startsWith('cdl_');
    return flagKind && _right['value'] == 0 && (_op == '!=' || _op == '==');
  }

  /// Enum indicators (e.g. trend regime) pick from the catalog's labels.
  List<CatalogEnumValue> get _enumValues =>
      _indicator?.kind == IndicatorKind.enumKind && _right['value'] is num
          ? (_indicator?.enumValues ?? const [])
          : const [];

  String get _summary {
    if (_isFlag) return _op == '!=' ? 'Yes' : 'No';
    for (final e in _enumValues) {
      if (e.value == _right['value']) {
        return '${_opSymbols[_op] ?? _op} ${e.label}';
      }
    }
    return '${_opSymbols[_op] ?? _op} ${_operandLabel(_right, widget.catalog)}';
  }

  @override
  void dispose() {
    _remove();
    _v1.dispose();
    _v2.dispose();
    for (final c in _params.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _remove() {
    _overlay?.remove();
    _overlay = null;
  }

  void _close() {
    _remove();
    if (mounted) setState(() {});
  }

  void _changed() {
    widget.onChanged();
    _overlay?.markNeedsBuild();
  }

  void _hydrate() {
    final v = _right['value'];
    if (v is List && v.length == 2) {
      _v1.text = _fmtNum(v[0]);
      _v2.text = _fmtNum(v[1]);
    } else if (v is num) {
      _v1.text = _fmtNum(v);
    }
    for (final e in _left.entries) {
      if (e.key == 'indicator' || e.value is! num) continue;
      (_params[e.key] ??= TextEditingController()).text = _fmtNum(e.value);
    }
  }

  void _toggle() {
    if (_overlay != null) {
      _close();
      return;
    }
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    _hydrate();
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MyntColors.overlayBgDark : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0);
    final screenW = MediaQuery.of(context).size.width;
    const panelW = 340.0;
    final left = (pos.dx + panelW > screenW - 12)
        ? (screenW - panelW - 12).clamp(12.0, double.infinity)
        : pos.dx;

    _overlay = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left.toDouble(),
          top: pos.dy + size.height + 6,
          width: panelW,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: bg,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: _popoverBody(),
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  Widget _popoverBody() {
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              _indicator?.label ?? _operandLabel(_left, widget.catalog),
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.semiBold, color: textPrimary),
            ),
          ),
          InkWell(
            onTap: _close,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(shadcn.LucideIcons.x, size: 14, color: secondary),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (_isFlag)
          FilterSelect(
            value: _op == '!=' ? 'yes' : 'no',
            hint: 'Select',
            height: 34,
            options: const [
              FilterSelectOption('yes', 'Yes — pattern formed'),
              FilterSelectOption('no', 'No — pattern not formed'),
            ],
            onChanged: (v) {
              widget.leaf['op'] = v == 'yes' ? '!=' : '==';
              _changed();
            },
          )
        else if (_enumValues.isNotEmpty)
          Row(children: [
            Expanded(
              child: FilterSelect(
                value: _op,
                hint: 'Op',
                height: 34,
                options: [
                  for (final o in kEnumOperators)
                    FilterSelectOption(o, _opSymbols[o] ?? o),
                ],
                onChanged: (v) {
                  widget.leaf['op'] = v;
                  _changed();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilterSelect(
                value: _fmtNum(_right['value']),
                hint: 'Value',
                height: 34,
                options: [
                  for (final e in _enumValues)
                    FilterSelectOption(_fmtNum(e.value), e.label),
                ],
                onChanged: (v) {
                  _right['value'] = num.parse(v);
                  _changed();
                },
              ),
            ),
          ])
        else ...[
          for (final k in _params.keys) ...[
            Row(children: [
              SizedBox(
                width: 110,
                child: Text(_paramLabel(k),
                    style: MyntWebTextStyles.body(context, color: secondary)),
              ),
              Expanded(
                child: _numField(_params[k]!, (n) {
                  _left[k] = _paramIsInt(k) ? n.round() : n;
                }),
              ),
            ]),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(
              child: FilterSelect(
                value: _op,
                hint: 'Op',
                height: 34,
                options: [
                  for (final o in [
                    ...kFloatOperators,
                    if (!_right.containsKey('indicator')) 'between',
                    // Keep a server-only op (e.g. crossed_below) selectable
                    // so opening the chip doesn't lose it.
                    if (!kFloatOperators.contains(_op) && _op != 'between')
                      _op,
                  ])
                    FilterSelectOption(o, _opSymbols[o] ?? o),
                ],
                onChanged: _setOp,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _valueInput(secondary)),
          ]),
        ],
      ],
    );
  }

  Widget _valueInput(Color secondary) {
    // Indicator-vs-indicator (e.g. close > SMA(50)): the right side's params
    // aren't editable here, only the operator.
    if (_right.containsKey('indicator')) {
      return Text(_operandLabel(_right, widget.catalog),
          style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium));
    }
    if (_op == 'between') {
      return Row(children: [
        Expanded(child: _numField(_v1, (_) => _setRange())),
        const SizedBox(width: 4),
        Text('to', style: MyntWebTextStyles.body(context, color: secondary)),
        const SizedBox(width: 4),
        Expanded(child: _numField(_v2, (_) => _setRange())),
      ]);
    }
    return _numField(_v1, (n) => _right['value'] = n);
  }

  Widget _numField(TextEditingController c, ValueChanged<num> onValue) {
    return FilterTextField(
      controller: c,
      hint: 'value',
      height: 34,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: TextInputValidators.signedDecimal(),
      onChanged: (t) {
        final n = num.tryParse(t);
        if (n == null) return;
        onValue(n);
        _changed();
      },
    );
  }

  void _setRange() {
    final a = num.tryParse(_v1.text);
    final b = num.tryParse(_v2.text);
    if (a != null && b != null) _right['value'] = [a, b];
  }

  void _setOp(String v) {
    final cur = _right['value'];
    if (v == 'between' && cur is num) {
      _right['value'] = [cur, cur];
      _v2.text = _v1.text;
    } else if (v != 'between' && cur is List && cur.isNotEmpty) {
      _right['value'] = cur.first;
    }
    widget.leaf['op'] = v;
    _changed();
  }

  CatalogParam? _param(String k) {
    for (final p in _indicator?.params ?? const <CatalogParam>[]) {
      if (p.name == k) return p;
    }
    return null;
  }

  String _paramLabel(String k) {
    final p = _param(k);
    if (p != null) return p.label;
    return k.isEmpty ? k : '${k[0].toUpperCase()}${k.substring(1)}';
  }

  bool _paramIsInt(String k) {
    final p = _param(k);
    if (p != null) return p.type == CatalogParamType.intType;
    return _left[k] is int;
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _overlay != null;
    final primary = resolveThemeColor(context,
        dark: MyntColors.secondaryDark, light: MyntColors.primary);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        key: _key,
        height: PredicateFilterTray._kCtl,
        padding: EdgeInsets.only(
            left: 10, right: widget.onDelete != null ? 4 : 8),
        decoration: BoxDecoration(
          border: Border.all(color: primary.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(ScannerTokens.rTag),
          color: _hover || isOpen ? hoverBg : ScannerTokens.surface(context),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _toggle,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _operandLabel(_left, widget.catalog),
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.medium, color: primary),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      _summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.body(context,
                          fontWeight: MyntFonts.medium, color: textPrimary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isOpen
                        ? shadcn.LucideIcons.chevronUp
                        : shadcn.LucideIcons.chevronDown,
                    size: 14,
                    color: primary,
                  ),
                ],
              ),
            ),
            if (widget.onDelete != null)
              InkWell(
                onTap: () {
                  if (isOpen) _remove();
                  widget.onDelete!();
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(shadcn.LucideIcons.x, size: 12, color: secondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

