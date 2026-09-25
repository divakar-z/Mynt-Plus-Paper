import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/dashboard/most_active.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/paginated_dash_table.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

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
          // Equal share with the data columns (a bigger flex leaves too much
          // empty space after the short symbol names on this wide table).
          sortKey: (r) => r.symbol,
          cell: (c, r) => Text(r.symbol,
              overflow: TextOverflow.ellipsis, style: _cell(c, bold: true)),
        ),
        DashCol(
          label: 'Volume',
          sortKey: (r) => r.volume ?? 0,
          cell: (c, r) => Text(InstaOptionsFormat.oi(r.volume), style: _cell(c)),
        ),
        DashCol(
          label: 'OI',
          sortKey: (r) => r.oi,
          cell: (c, r) => Text(InstaOptionsFormat.oi(r.oi), style: _cell(c)),
        ),
      ];

  List<DashCol<MostActiveRow>> _oiCols() => [
        DashCol(
          label: 'Symbol',
          // Equal share with the data columns (a bigger flex leaves too much
          // empty space after the short symbol names on this wide table).
          sortKey: (r) => r.symbol,
          cell: (c, r) => Text(r.symbol,
              overflow: TextOverflow.ellipsis, style: _cell(c, bold: true)),
        ),
        DashCol(
          label: 'Category',
          width: 160,
          cell: (c, r) => r.category == null
              ? Text('—', style: _cell(c))
              : DashCategoryChip(category: r.category!),
        ),
        DashCol(
          label: 'OI',
          // OI value coloured by its change direction (like BuildUp); the OI %
          // column stays neutral.
          sortKey: (r) => r.oi,
          cell: (c, r) => Text(InstaOptionsFormat.oi(r.oi),
              style: _cell(c, color: dashChangeColor(c, r.oiChangePct))),
        ),
        DashCol(
          label: 'OI chg %',
          sortKey: (r) => r.oiChangePct ?? 0,
          cell: (c, r) => Text(InstaOptionsFormat.changePct(r.oiChangePct),
              style: _cell(c)),
        ),
        DashCol(
          label: 'Price %',
          sortKey: (r) => r.priceChangePct ?? 0,
          cell: (c, r) => Text(InstaOptionsFormat.changePct(r.priceChangePct),
              style: _cell(c, color: dashChangeColor(c, r.priceChangePct))),
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
      child: PaginatedDashTable<MostActiveRow>(
        key: ValueKey(_by),
        columns: _by == MostActiveBy.volume ? _volumeCols() : _oiCols(),
        rows: rows,
        // Volume view sorts by Volume (index 1); OI view sorts by OI — now
        // index 2 since Category sits right after Symbol.
        initialSortCol: _by == MostActiveBy.volume ? 1 : 2,
        emptyLabel: 'No symbols.',
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
    // Segmented toggle matching the scanner Financials pickers (same as the
    // OI Statistics OI ⇄ OI-change toggle): selected = solid brand-blue fill
    // + white text; fixed 36 to line up with the other bar controls.
    final border = shadcn.Theme.of(context).colorScheme.border;
    final values = MostActiveBy.values;
    return Container(
      height: 30,
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < values.length; i++)
            _seg(context, values[i],
                isFirst: i == 0, isLast: i == values.length - 1),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, MostActiveBy value,
      {required bool isFirst, required bool isLast}) {
    final selected = by == value;
    final inactiveFg = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    // Selected segment's outer corners round to match the container (5).
    const r = Radius.circular(5);
    final radius = BorderRadius.only(
      topLeft: isFirst ? r : Radius.zero,
      bottomLeft: isFirst ? r : Radius.zero,
      topRight: isLast ? r : Radius.zero,
      bottomRight: isLast ? r : Radius.zero,
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSelect(value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? resolveThemeColor(context,
                    dark: MyntColors.secondary, light: MyntColors.primary)
                : Colors.transparent,
            borderRadius: radius,
          ),
          child: Text(
            value.label,
            style: MyntWebTextStyles.para(
              context,
              color: selected ? Colors.white : inactiveFg,
              fontWeight: selected ? MyntFonts.semiBold : MyntFonts.medium,
            ),
          ),
        ),
      ),
    );
  }
}
