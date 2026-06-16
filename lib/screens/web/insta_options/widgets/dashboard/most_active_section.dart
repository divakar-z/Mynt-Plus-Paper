import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/most_active.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';

/// §5.7 Most active — toggle between futures Volume and |OI change|.
class MostActiveSection extends StatefulWidget {
  final MostActive mostActive;

  const MostActiveSection({super.key, required this.mostActive});

  @override
  State<MostActiveSection> createState() => _MostActiveSectionState();
}

class _MostActiveSectionState extends State<MostActiveSection> {
  MostActiveBy _by = MostActiveBy.volume;

  TextStyle _cell(BuildContext c, {Color? color, bool bold = false}) =>
      MyntWebTextStyles.tableCell(
        c,
        color: color,
        darkColor: color ?? MyntColors.textPrimaryDark,
        lightColor: color ?? MyntColors.textPrimary,
        fontWeight: bold ? MyntFonts.semiBold : MyntFonts.medium,
      );

  List<DashCol<MostActiveRow>> _volumeCols() => [
        DashCol(
          label: 'Symbol',
          sortKey: (r) => r.symbol,
          cell: (c, r) => Text(r.symbol,
              overflow: TextOverflow.ellipsis, style: _cell(c, bold: true)),
        ),
        DashCol(
          label: 'Volume',
          width: 110,
          numeric: true,
          sortKey: (r) => r.volume ?? 0,
          cell: (c, r) => Text(InstaOptionsFormat.oi(r.volume), style: _cell(c)),
        ),
        DashCol(
          label: 'OI',
          width: 110,
          numeric: true,
          sortKey: (r) => r.oi,
          cell: (c, r) => Text(InstaOptionsFormat.oi(r.oi), style: _cell(c)),
        ),
      ];

  List<DashCol<MostActiveRow>> _oiCols() => [
        DashCol(
          label: 'Symbol',
          sortKey: (r) => r.symbol,
          cell: (c, r) => Text(r.symbol,
              overflow: TextOverflow.ellipsis, style: _cell(c, bold: true)),
        ),
        DashCol(
          label: 'OI',
          width: 84,
          numeric: true,
          sortKey: (r) => r.oi,
          cell: (c, r) => Text(InstaOptionsFormat.oi(r.oi), style: _cell(c)),
        ),
        DashCol(
          label: 'OI %',
          width: 82,
          numeric: true,
          sortKey: (r) => r.oiChangePct ?? 0,
          cell: (c, r) => Text(InstaOptionsFormat.changePct(r.oiChangePct),
              style: _cell(c, color: dashChangeColor(c, r.oiChangePct))),
        ),
        DashCol(
          label: 'Price %',
          width: 82,
          numeric: true,
          sortKey: (r) => r.priceChangePct ?? 0,
          cell: (c, r) => Text(InstaOptionsFormat.changePct(r.priceChangePct),
              style: _cell(c, color: dashChangeColor(c, r.priceChangePct))),
        ),
        DashCol(
          label: 'Cat',
          width: 56,
          cell: (c, r) => r.category == null
              ? Text('—', style: _cell(c))
              : DashCategoryChip(category: r.category!, short: true),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final rows = widget.mostActive.rowsFor(_by);
    return DashSectionCard(
      title: 'Most Active',
      trailing: _Toggle(
        by: _by,
        onSelect: (b) => setState(() => _by = b),
      ),
      child: DashTable<MostActiveRow>(
        key: ValueKey(_by),
        columns: _by == MostActiveBy.volume ? _volumeCols() : _oiCols(),
        rows: rows,
        initialSortCol: 1,
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final MostActiveBy by;
  final ValueChanged<MostActiveBy> onSelect;

  const _Toggle({required this.by, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final b in MostActiveBy.values) _seg(context, b),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, MostActiveBy value) {
    final active = by == value;
    final activeBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final activeFg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final inactiveFg = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSelect(value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            value.label,
            style: MyntWebTextStyles.caption(
              context,
              color: active ? activeFg : inactiveFg,
              fontWeight: active ? MyntFonts.semiBold : MyntFonts.medium,
            ),
          ),
        ),
      ),
    );
  }
}
