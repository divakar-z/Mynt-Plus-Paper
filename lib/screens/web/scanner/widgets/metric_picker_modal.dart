import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/common_text_fields_web.dart';

/// Tickertape-style "Add filters" picker for the redesigned Fundamentals
/// screen: metric categories on the left, the metrics in the selected category
/// (or search results) as checkboxes on the right. Returns the new set of
/// selected metric keys, or null if the dialog was dismissed without "Done".
Future<Set<String>?> showMetricPicker(
  BuildContext context, {
  required List<FundamentalField> fields,
  required Set<String> selected,
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => _MetricPicker(fields: fields, selected: selected),
  );
}

class _MetricPicker extends StatefulWidget {
  final List<FundamentalField> fields;
  final Set<String> selected;
  const _MetricPicker({required this.fields, required this.selected});

  @override
  State<_MetricPicker> createState() => _MetricPickerState();
}

class _MetricPickerState extends State<_MetricPicker> {
  late final Set<String> _working = {...widget.selected};
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _group = 0;
  late final List<String> _groups;
  late final Map<String, List<FundamentalField>> _byGroup;

  @override
  void initState() {
    super.initState();
    _byGroup = {};
    for (final f in widget.fields) {
      _byGroup
          .putIfAbsent(f.group.isEmpty ? 'Other' : f.group, () => [])
          .add(f);
    }
    _groups = _byGroup.keys.toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _searching => _query.trim().isNotEmpty;

  List<FundamentalField> get _rightList {
    if (_searching) {
      final q = _query.toLowerCase();
      return widget.fields
          .where((f) => f.label.toLowerCase().contains(q))
          .toList();
    }
    if (_groups.isEmpty) return const [];
    return _byGroup[_groups[_group.clamp(0, _groups.length - 1)]] ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

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
              // Header: title + subtitle, a search box, and close.
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                          const SizedBox(height: 2),
                          Text('${widget.fields.length} metrics · pick what to show',
                              style: MyntWebTextStyles.caption(context,
                                  color: secondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 240,
                      child: MyntFormTextField(
                        controller: _search,
                        placeholder: 'Search filters…',
                        height: 38,
                        onChanged: (v) => setState(() => _query = v),
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
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _groups.length,
                            itemBuilder: (_, i) => _categoryItem(_groups[i], i),
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Row(children: [
                  Text('${_working.length} selected',
                      style: MyntWebTextStyles.body(context, color: secondary)),
                  const Spacer(),
                  MyntButton(
                    type: MyntButtonType.primary,
                    label: 'Done',
                    onPressed: () => Navigator.of(context).pop(_working),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryItem(String group, int i) {
    final active = _group == i;
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    // How many metrics in this group are currently selected.
    final selCount =
        (_byGroup[group] ?? const []).where((f) => _working.contains(f.key)).length;
    return Material(
      color: active ? hoverBg : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _group = i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Expanded(
              child: Text(group,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: list.length,
      itemBuilder: (_, i) => _checkRow(list[i]),
    );
  }

  Widget _checkRow(FundamentalField f) {
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final checked = _working.contains(f.key);
    return InkWell(
      onTap: () => setState(() {
        if (checked) {
          _working.remove(f.key);
        } else {
          _working.add(f.key);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(children: [
          Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 18,
              color: checked ? primary : secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(f.label,
                style: MyntWebTextStyles.body(context, color: textColor)),
          ),
          if (_searching && f.group.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(f.group,
                style: MyntWebTextStyles.caption(context, color: tertiary)),
          ],
        ]),
      ),
    );
  }
}
