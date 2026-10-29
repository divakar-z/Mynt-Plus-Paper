import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../provider/privacy_provider.dart';
import '../../../../../provider/withdraw_provider.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../sharedWidget/functions.dart';

/// One group in the breakdown: Closing balance, Deductions, Additions.
class _BreakdownGroup {
  final String name;
  final List<WithdrawBreakdownRow> rows;
  final double total;

  /// Sign shown before the group total: "-", "+" or "" for the opening figure.
  final String sign;
  const _BreakdownGroup(this.name, this.rows, this.total, this.sign);
}

/// Withdrawable breakdown, shown in the withdraw screen's right column:
/// label / value rows with dividers, deductions and additions collapsible.
class WithdrawBreakdownView extends ConsumerStatefulWidget {
  final WithdrawBreakdown breakdown;
  const WithdrawBreakdownView({super.key, required this.breakdown});

  @override
  ConsumerState<WithdrawBreakdownView> createState() =>
      _WithdrawBreakdownViewState();
}

class _WithdrawBreakdownViewState
    extends ConsumerState<WithdrawBreakdownView> {
  final Map<String, bool> _open = {};

  Color get _divider => resolveThemeColor(context,
      dark: MyntColors.dividerDark, light: MyntColors.divider);
  Color get _textPrimary => resolveThemeColor(context,
      dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
  Color get _textSecondary => resolveThemeColor(context,
      dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

  String _fmt(double v, {String sign = ''}) =>
      ref.watch(privacyProvider).mask(
            getFormatter(value: v, v4d: false, noDecimal: false),
            prefix: sign,
          );

  List<_BreakdownGroup> _groups() {
    final rows = widget.breakdown.rows;
    double sum(Iterable<WithdrawBreakdownRow> r) =>
        r.fold<double>(0.0, (a, e) => a + e.value);

    final closing = rows.where((r) => r.sign == 0).toList();
    final deductions = rows.where((r) => r.sign < 0).toList();
    final additions = rows.where((r) => r.sign > 0).toList();
    return [
      if (closing.isNotEmpty)
        _BreakdownGroup('Closing balance', closing, sum(closing), ''),
      _BreakdownGroup('Deductions', deductions, sum(deductions), '-'),
      if (additions.isNotEmpty)
        _BreakdownGroup('Additions', additions, sum(additions), '+'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in _groups()) _group(g),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Withdrawable',
                  style: MyntWebTextStyles.body(context,
                      color: _textPrimary, fontWeight: MyntFonts.semiBold)),
              Text(_fmt(widget.breakdown.withdrawable, sign: '₹ '),
                  style: MyntWebTextStyles.body(context,
                      color: _textPrimary, fontWeight: MyntFonts.semiBold)),
            ],
          ),
        ),
      ],
    );
  }

  /// One expandable row: label and total with an arrow, then its lines
  /// underneath. The closing balance only expands when it has parts.
  Widget _group(_BreakdownGroup g) {
    final lines = <Widget>[];
    void add(String label, double value, {bool sub = false, String? caption}) {
      if (lines.isNotEmpty) lines.add(Divider(color: _divider, height: 1));
      lines.add(_line(label, value, sub: sub, caption: caption));
    }

    if (g.sign.isEmpty) {
      for (final r in g.rows) {
        for (final p in r.parts) {
          add(p.label, p.value);
        }
      }
    } else if (g.rows.isEmpty) {
      add('None', 0);
    } else {
      for (final r in g.rows) {
        add(r.label, r.value, caption: r.caption);
        for (final p in r.parts) {
          add(p.label, p.value, sub: true);
        }
      }
    }

    final bool expandable = lines.isNotEmpty;
    final bool open = expandable && (_open[g.name] ?? true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: expandable
              ? () => setState(() => _open[g.name] = !open)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(g.name,
                      style: MyntWebTextStyles.bodySmall(context,
                          color: _textSecondary,
                          fontWeight: MyntFonts.medium)),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Text(_fmt(g.total, sign: g.sign),
                        style: MyntWebTextStyles.bodySmall(context,
                            color: _textPrimary,
                            fontWeight: MyntFonts.semiBold)),
                    const SizedBox(width: 4),
                    expandable
                        ? Icon(
                            open
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: _textSecondary,
                            size: 20,
                          )
                        : const SizedBox(width: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 24, bottom: 8),
            child: Column(children: lines),
          ),
        Divider(color: _divider, height: 1),
      ],
    );
  }

  /// A label / value line inside an expanded row. [sub] lines are the parts
  /// of the line above them, indented. [caption] shows as a hover tooltip.
  Widget _line(String label, double value,
      {bool sub = false, String? caption}) {
    Widget labelText = Text(label,
        style: MyntWebTextStyles.bodySmall(context,
            color: _textSecondary, fontWeight: MyntFonts.medium));
    if (caption != null && caption.isNotEmpty) {
      labelText = Tooltip(message: caption, child: labelText);
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(sub ? 12 : 0, 8, 0, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: labelText),
          const SizedBox(width: 12),
          Text(_fmt(value),
              style: MyntWebTextStyles.bodySmall(context,
                  color: _textPrimary, fontWeight: MyntFonts.medium)),
        ],
      ),
    );
  }
}
