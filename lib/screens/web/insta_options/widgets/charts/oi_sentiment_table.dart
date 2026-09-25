import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/charts/oi_timeline.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dashboard_enums.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dash_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/paginated_dash_table.dart';

/// Per-strike OI + buildup-sentiment table for Trending OI — every listed
/// strike with its CE/PE OI, day OI Δ%, buildup category, and row PCR. Columns
/// flex to fill the width; rows default to most-active (highest CE+PE OI) first
/// so the liquid near-ATM strikes lead instead of deep-OTM blanks. Null legs
/// render blank; every column is re-sortable.
class OiSentimentTable extends StatelessWidget {
  final OiTimeline data;

  const OiSentimentTable({super.key, required this.data});

  TextStyle _cell(BuildContext c, {Color? color, bool bold = false}) =>
      MyntWebTextStyles.tableCell(
        c,
        color: color,
        darkColor: color ?? MyntColors.textPrimaryDark,
        lightColor: color ?? MyntColors.textPrimary,
        fontWeight: bold ? MyntFonts.semiBold : MyntFonts.medium,
      );

  Widget _dash(BuildContext c) => Text('—',
      style: _cell(c,
          color: resolveThemeColor(c,
              dark: MyntColors.textTertiaryDark,
              light: MyntColors.textTertiary)));

  /// Leg OI — value coloured by its day-change direction (BuildUp-table
  /// convention: OI carries the colour, the % column stays neutral).
  Widget _oiCell(BuildContext c, int? oi, double? pct) => oi == null
      ? _dash(c)
      : Text(InstaOptionsFormat.oi(oi),
          style: _cell(c, color: dashChangeColor(c, pct)));

  /// Leg day OI change % — neutral text.
  Widget _oiPctCell(BuildContext c, int? oi, double? pct) =>
      (oi == null || pct == null)
          ? _dash(c)
          : Text(InstaOptionsFormat.changePct(pct), style: _cell(c));

  Widget _buildup(BuildContext c, String? category) => category == null
      ? _dash(c)
      : Align(
          alignment: Alignment.centerLeft,
          // Full-label chip, same as the Market Dashboard BuildUp table.
          child: DashCategoryChip(category: BuildupCategory.fromWire(category)),
        );

  Widget _strike(BuildContext c, OiTimelineRow r) {
    final accent = resolveThemeColor(c,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(r.strike.toInt().toString(), style: _cell(c, bold: true)),
        if (r.isAtm) ...[
          const SizedBox(width: 6),
          // Same ATM badge as the strikes dropdown.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('ATM',
                style: MyntWebTextStyles.caption(c,
                        color: accent, fontWeight: MyntFonts.bold)
                    .copyWith(fontSize: 9, letterSpacing: 0.5)),
          ),
        ],
      ],
    );
  }

  // Eight columns, all flex (width null) — equal widths filling the panel;
  // on a narrow panel the table falls back to its horizontal scroll.
  List<DashCol<OiTimelineRow>> _cols(BuildContext context) {
    return [
      DashCol(
        label: 'Strike',
        sortKey: (r) => r.strike,
        cell: (c, r) => _strike(c, r),
      ),
      // All columns left-aligned (no `numeric`) — right-aligned values sat
      // flush against the next column and read as smashed pairs. OI and its
      // day % are separate columns, like the Market Dashboard BuildUp table.
      DashCol(
        label: 'CE OI',
        sortKey: (r) => r.ce?.oi ?? 0,
        cell: (c, r) => _oiCell(c, r.ce?.oi, r.ce?.oiChangePct),
      ),
      DashCol(
        label: 'CE OI chg %',
        sortKey: (r) => r.ce?.oiChangePct ?? 0,
        cell: (c, r) => _oiPctCell(c, r.ce?.oi, r.ce?.oiChangePct),
      ),
      DashCol(
        label: 'CE Buildup',
        sortKey: (r) => r.ce?.category ?? 'zz',
        cell: (c, r) => _buildup(c, r.ce?.category),
      ),
      DashCol(
        label: 'PCR',
        sortKey: (r) => r.pcr ?? 0,
        cell: (c, r) =>
            r.pcr == null ? _dash(c) : Text(InstaOptionsFormat.pcr(r.pcr), style: _cell(c)),
      ),
      DashCol(
        label: 'PE Buildup',
        sortKey: (r) => r.pe?.category ?? 'zz',
        cell: (c, r) => _buildup(c, r.pe?.category),
      ),
      DashCol(
        label: 'PE OI',
        sortKey: (r) => r.pe?.oi ?? 0,
        cell: (c, r) => _oiCell(c, r.pe?.oi, r.pe?.oiChangePct),
      ),
      DashCol(
        label: 'PE OI chg %',
        sortKey: (r) => r.pe?.oiChangePct ?? 0,
        cell: (c, r) => _oiPctCell(c, r.pe?.oi, r.pe?.oiChangePct),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Most-active strikes first (total CE+PE OI) so the populated near-ATM
    // strikes lead; the user can still sort by any column.
    final rows = [...data.table]
      ..sort((a, b) {
        final ta = (a.ce?.oi ?? 0) + (a.pe?.oi ?? 0);
        final tb = (b.ce?.oi ?? 0) + (b.pe?.oi ?? 0);
        return tb.compareTo(ta);
      });
    return PaginatedDashTable<OiTimelineRow>(
      columns: _cols(context),
      rows: rows,
      filterKey: '${data.underlying}|${data.tradeDate}|${data.expiry}',
      emptyLabel: 'No strikes.',
    );
  }
}
