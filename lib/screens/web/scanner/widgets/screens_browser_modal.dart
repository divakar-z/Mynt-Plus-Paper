import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';
import 'package:mynt_plus/provider/scanner/fundamentals_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';

/// Tickertape-style "Manage screens" modal for the redesigned Fundamentals
/// screen: Saved / Presets tabs on top, a list of screens on the left, and the
/// selected screen's filter preview + Load on the right. `onLoad` receives the
/// screen's filters + missing-data rule to apply into the builder.
void showScreensBrowser(
  BuildContext context, {
  required void Function(List<FundamentalFilter> filters, String treatNullAs)
      onLoad,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _ScreensBrowser(onLoad: onLoad),
  );
}

class _ScreensBrowser extends ConsumerStatefulWidget {
  final void Function(List<FundamentalFilter>, String) onLoad;
  const _ScreensBrowser({required this.onLoad});

  @override
  ConsumerState<_ScreensBrowser> createState() => _ScreensBrowserState();
}

class _ScreensBrowserState extends ConsumerState<_ScreensBrowser> {
  int _tab = 0; // 0 = Saved, 1 = Presets
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final fields = ref.watch(fundamentalFieldsProvider).maybeWhen(
          data: (l) => {for (final f in l) f.key: f},
          orElse: () => <String, FundamentalField>{},
        );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: shadcn.Card(
        borderRadius: BorderRadius.circular(8),
        padding: EdgeInsets.zero,
        child: Container(
          width: 760,
          height: 520,
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.dialogDark, light: MyntColors.dialog),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: title + close, then the Saved / Presets tabs
              // (positions-page rounded-pill style).
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Screens',
                            style: MyntWebTextStyles.title(context,
                                color: textPrimary)),
                        MyntCloseButton(
                            onPressed: () => Navigator.of(context).pop()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      _tabPill('Saved', 0),
                      const SizedBox(width: 4),
                      _tabPill('Presets', 1),
                    ]),
                  ],
                ),
              ),
              Expanded(
                child: _tab == 0
                    ? _savedBody(fields, border)
                    : _presetsBody(fields, border),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Positions-page rounded-pill tab: transparent when inactive, subtle
  /// white/black tint when active, 6px radius, no border.
  Widget _tabPill(String label, int idx) {
    final active = _tab == idx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);
    final foreground = shadcn.Theme.of(context).colorScheme.foreground;
    final mutedForeground =
        shadcn.Theme.of(context).colorScheme.mutedForeground;
    final textColor = active ? foreground : mutedForeground;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() {
          _tab = idx;
          _selected = 0;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: MyntWebTextStyles.body(context,
                fontWeight:
                    active ? MyntFonts.semiBold : MyntFonts.medium,
              ).copyWith(color: textColor)),
        ),
      ),
    );
  }

  Widget _savedBody(Map<String, FundamentalField> fields, Color border) {
    final async = ref.watch(savedScreensProvider);
    return async.when(
      loading: () => Center(child: MyntLoader.simple()),
      error: (e, _) => _message('Could not load saved screens', e.toString()),
      data: (list) {
        if (list.isEmpty) {
          return _message('No saved screens yet',
              'Build a screen and hit "Save as…" to reuse it later.');
        }
        final sel = list[_selected.clamp(0, list.length - 1)];
        return _split(
          count: list.length,
          nameAt: (i) => list[i].name,
          border: border,
          detailName: sel.name,
          detailSub: sel.createdAt != null
              ? 'Created ${formatDateTime(sel.createdAt)}'
              : '${sel.filters.length} filters',
          filters: sel.filters,
          fields: fields,
          onLoad: () {
            widget.onLoad(sel.filters, sel.treatNullAs);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Widget _presetsBody(Map<String, FundamentalField> fields, Color border) {
    final async = ref.watch(fundamentalPresetsProvider);
    return async.when(
      loading: () => Center(child: MyntLoader.simple()),
      error: (e, _) => _message('Could not load presets', e.toString()),
      data: (list) {
        if (list.isEmpty) return _message('No presets available', null);
        final sel = list[_selected.clamp(0, list.length - 1)];
        return _split(
          count: list.length,
          nameAt: (i) => list[i].name,
          border: border,
          detailName: sel.name,
          detailSub: sel.description.isNotEmpty ? sel.description : null,
          filters: sel.filters,
          fields: fields,
          onLoad: () {
            widget.onLoad(sel.filters, sel.treatNullAs);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Widget _split({
    required int count,
    required String Function(int) nameAt,
    required Color border,
    required String detailName,
    required String? detailSub,
    required List<FundamentalFilter> filters,
    required Map<String, FundamentalField> fields,
    required VoidCallback onLoad,
  }) {
    if (_selected >= count) _selected = 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: border)),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: count,
              itemBuilder: (_, i) => _listItem(nameAt(i), i),
            ),
          ),
        ),
        Expanded(
          child: _detail(
            name: detailName,
            sub: detailSub,
            filters: filters,
            fields: fields,
            onLoad: onLoad,
          ),
        ),
      ],
    );
  }

  Widget _listItem(String name, int i) {
    final active = _selected == i;
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return Material(
      color: active ? hoverBg : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selected = i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.body(context,
                fontWeight: active ? MyntFonts.semiBold : MyntFonts.medium,
                color: active ? primary : textColor),
          ),
        ),
      ),
    );
  }

  Widget _detail({
    required String name,
    required String? sub,
    required List<FundamentalFilter> filters,
    required Map<String, FundamentalField> fields,
    required VoidCallback onLoad,
  }) {
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(name,
                    style: MyntWebTextStyles.title(context,
                        fontWeight: MyntFonts.semiBold, color: textPrimary)),
              ),
              const SizedBox(width: 12),
              MyntButton(
                type: MyntButtonType.primary,
                label: 'Load',
                onPressed: onLoad,
              ),
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub, style: MyntWebTextStyles.body(context, color: secondary)),
          ],
          const SizedBox(height: 18),
          Text('FILTERS',
              style: MyntWebTextStyles.caption(context,
                      fontWeight: MyntFonts.semiBold, color: tertiary)
                  .copyWith(letterSpacing: 1.0)),
          const SizedBox(height: 8),
          Expanded(
            child: filters.isEmpty
                ? Text('No filters in this screen.',
                    style: MyntWebTextStyles.body(context, color: secondary))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final f in filters)
                          _filterLine(f, fields[f.field]),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterLine(FundamentalFilter f, FundamentalField? fld) {
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(fld?.label ?? f.field,
                style: MyntWebTextStyles.body(context, color: secondary)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _valueText(f, fld),
              textAlign: TextAlign.right,
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.semiBold, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String title, String? sub) {
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold, color: textPrimary)),
            if (sub != null) ...[
              const SizedBox(height: 6),
              Text(sub,
                  textAlign: TextAlign.center,
                  style:
                      MyntWebTextStyles.caption(context, color: secondary)),
            ],
          ],
        ),
      ),
    );
  }
}

String _fmtNum(num v, FundamentalField? fld) {
  if (fld?.dtype == 'pct') {
    final p = v * 100;
    return p == p.roundToDouble()
        ? '${p.toInt()}%'
        : '${p.toStringAsFixed(2)}%';
  }
  if (v is int) return v.toString();
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

String _valueText(FundamentalFilter f, FundamentalField? fld) {
  switch (f.op) {
    case 'is_null':
      return 'is empty';
    case 'is_not_null':
      return 'not empty';
    case 'between':
      final v = f.value;
      if (v is List && v.length == 2 && v[0] is num && v[1] is num) {
        return '${_fmtNum(v[0] as num, fld)} – ${_fmtNum(v[1] as num, fld)}';
      }
      return '—';
    case 'in':
      final v = f.value;
      return v is List ? v.join(', ') : '—';
    case 'not_in':
      final v = f.value;
      return v is List ? 'not ${v.join(', ')}' : '—';
    case 'min_years':
      return 'min ${f.value ?? f.years ?? '?'} yrs';
    default:
      const sym = {
        '<': '<',
        '<=': '≤',
        '>': '>',
        '>=': '≥',
        '==': '=',
        '!=': '≠',
      };
      final s = sym[f.op] ?? f.op;
      final v = f.value;
      if (v is num) return '$s ${_fmtNum(v, fld)}';
      if (v == null) return s;
      return '$s $v';
  }
}
