// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';
import 'package:mynt_plus/provider/transcation_provider.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../../models/ipo_model/ipo_mainstream_model.dart';
import '../../../../models/ipo_model/ipo_pre_close_model.dart';
import '../../../../models/ipo_model/ipo_sme_model.dart';
import '../../../../provider/iop_provider.dart';
import '../../../../provider/stocks_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../IPO_order_screen/ipo_order_screen_web.dart';
import '../ipo_details_sheet_web.dart';

class MainSmeListCard extends ConsumerStatefulWidget {
  const MainSmeListCard({super.key});

  @override
  ConsumerState<MainSmeListCard> createState() => _MainSmeListCardState();
}

class _MainSmeListCardState extends ConsumerState<MainSmeListCard> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  String? _hoveredRowId;

  // Popover state management
  shadcn.PopoverController? _activePopoverController;
  String? _popoverRowId;
  bool _isHoveringDropdown = false;
  Timer? _popoverCloseTimer;

  // Prevent multiple clicks opening multiple detail sheets
  bool _isNavigating = false;

  @override
  void dispose() {
    _cancelPopoverCloseTimer();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _startPopoverCloseTimer() {
    _cancelPopoverCloseTimer();
    _popoverCloseTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_isHoveringDropdown && _hoveredRowId != _popoverRowId) {
        _closePopover();
      }
    });
  }

  void _cancelPopoverCloseTimer() {
    _popoverCloseTimer?.cancel();
    _popoverCloseTimer = null;
  }

  void _closePopover() {
    _cancelPopoverCloseTimer();
    try {
      _activePopoverController?.close();
    } catch (_) {}
    final needsRebuild = _activePopoverController != null || _popoverRowId != null;
    _activePopoverController = null;
    _popoverRowId = null;
    _isHoveringDropdown = false;
    if (needsRebuild && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ipos = ref.watch(ipoProvide);
    final mainstreamipo = ref.watch(ipoProvide);
    final theme = ref.watch(themeProvider);

    // Get filtered IPOs based on search
    final filteredIpos = _getFilteredIPOs(ipos, mainstreamipo, ref);

    List<dynamic> openIpos = filteredIpos.where((ipo) {
      if (ipo is! SMEIPO && ipo is! MainIPO) {
        return false;
      }
      return ipostartdate(ipo.biddingStartDate, ipo.biddingEndDate) == "Open";
    }).toList();

    List<dynamic> preOpenIpos = filteredIpos.where((ipo) {
      if (ipo is! SMEIPO && ipo is! MainIPO) {
        return false;
      }
      return ipostartdate(ipo.biddingStartDate, ipo.biddingEndDate) ==
          "Pre-open";
    }).toList();

    final preCloseMsg = ipos.ipoPreClose?.msg;
    // final List<Msg> closedIpos =
    //     preCloseMsg != null ? List<Msg>.from(preCloseMsg) : <Msg>[];
    // Search covers closed IPOs too (same name match as the open list);
    // before, closed rows were always added unfiltered.
    final searchText =
        ref.watch(stocksProvide).searchController.text.toUpperCase();
    final List<Msg> closedIpos = preCloseMsg != null
        ? List<Msg>.from(preCloseMsg)
            .where((m) =>
                searchText.isEmpty ||
                (m.companyName ?? "").toUpperCase().contains(searchText) ||
                (m.name ?? "").toUpperCase().contains(searchText))
            .toList()
        : <Msg>[];
    if (closedIpos.isNotEmpty) {
      ipos.sortpreCloseIPOListByDate(closedIpos);
    }
    // TC_58/59: closed rows stay at the bottom but follow the column sort
    // within their own group.
    final List<dynamic> sortedClosedIpos = _getSortedIPOs(closedIpos);

    // Combine all IPOs for table display (open + pre-open, sortable;
    // closed appended at the end and not sorted by column headers).
    List<dynamic> allIpos = [...openIpos, ...preOpenIpos];

    final hasAnyData =
        openIpos.isNotEmpty || preOpenIpos.isNotEmpty || closedIpos.isNotEmpty;

    // Show loader while data is being fetched
    if (ipos.loading) {
      return const Center(
        child: MyntLoader(size: MyntLoaderSize.large),
      );
    }

    // if (ref.watch(stocksProvide).searchController.text.isNotEmpty &&
    //     ipos.ipoCommonSearchList.isEmpty) {
    // No Data only when neither open nor closed IPOs match the search.
    if (searchText.isNotEmpty &&
        ipos.ipoCommonSearchList.isEmpty &&
        closedIpos.isEmpty) {
      return const Center(
        child: NoDataFoundWeb(),
      );
    }

    if (!hasAnyData) {
      return const Center(
        child: NoDataFoundWeb(),
      );
    }

    // Apply sorting to open/pre-open, then append closed rows at the end.
    // Sorting Type (status) descending puts Closed first; otherwise the
    // closed group stays at the bottom.
    final closedFirst = _sortColumnIndex == 2 && !_sortAscending;
    final List<dynamic> sortedIpos = closedFirst
        ? [...sortedClosedIpos, ..._getSortedIPOs(allIpos)]
        : [
            ..._getSortedIPOs(allIpos),
            // ...closedIpos,
            ...sortedClosedIpos,
          ];

    return SizedBox.expand(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        child: _buildIPOTable(
            sortedIpos, theme, ipos, ref.read(transcationProvider)),
      ),
    );
  }

  List<dynamic> _getFilteredIPOs(
      IPOProvider ipos, IPOProvider mainstreamipo, WidgetRef ref) {
    // if (ref.watch(stocksProvide).searchController.text.isNotEmpty &&
    //     ipos.ipoCommonSearchList.isNotEmpty) {
    // While searching, show only the matches, even when no open IPO matches
    // (closed matches may still be listed).
    if (ref.watch(stocksProvide).searchController.text.isNotEmpty) {
      return ipos.ipoCommonSearchList;
    }
    return mainstreamipo.mainsme;
  }

List<dynamic> _getSortedIPOs(List<dynamic> ipos) {
    if (_sortColumnIndex == null) return ipos;

    final sorted = List<dynamic>.from(ipos);
    sorted.sort((a, b) {
      int comparison = 0;

      // TC_58/59: header indexes are 0 = Stock name, 1 = IPO date. The old
      // switch had 1 = Type (hidden column) and 2 = date (no header), and
      // compared dates as text ("Fri, 24 Oct ..." sorts by weekday).
      switch (_sortColumnIndex) {
        case 0: // Stock name (same text the row shows, case-insensitive)
          comparison = _sortName(a).compareTo(_sortName(b));
          break;
        case 1: // IPO date: start date, then end date
          // Rows with no readable date stay last in both directions.
          final aStart = _sortStartDate(a);
          final bStart = _sortStartDate(b);
          if ((aStart == null) != (bStart == null)) {
            return aStart == null ? 1 : -1;
          }
          comparison = _compareDates(aStart, bStart);
          if (comparison == 0) {
            comparison = _compareDates(_sortEndDate(a), _sortEndDate(b));
          }
          break;
        case 3: // Min. amount: the same price x qty the row shows
          final aAmt = _minAmountValue(a);
          final bAmt = _minAmountValue(b);
          // Rows with no amount ("-") stay last in both directions.
          if ((aAmt == null) != (bAmt == null)) {
            return aAmt == null ? 1 : -1;
          }
          comparison = (aAmt == null || bAmt == null) ? 0 : aAmt.compareTo(bAmt);
          break;
        case 2: // Type = status: Open, Pre-open, Closed; then name
          // comparison = _ipoTypeLabel(a).compareTo(_ipoTypeLabel(b));
          comparison = _statusRank(a).compareTo(_statusRank(b));
          if (comparison == 0) {
            comparison = _sortName(a).compareTo(_sortName(b));
          }
          break;
        // case 1: // Type
        //   final aType = a.key ?? "";
        //   final bType = b.key ?? "";
        //   comparison = aType.compareTo(bType);
        //   break;
        // case 2: // IPO date
        //   final aDate = a.biddingEndDate ?? a.biddingStartDate ?? "";
        //   final bDate = b.biddingEndDate ?? b.biddingStartDate ?? "";
        //   comparison = aDate.compareTo(bDate);
        //   break;
        // case 5: // Subscription (index 5 after Price range and Min. amount)
        //   final aSub = double.tryParse(a.totalsub ?? "0") ?? 0.0;
        //   final bSub = double.tryParse(b.totalsub ?? "0") ?? 0.0;
        //   comparison = aSub.compareTo(bSub);
        //   break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  // Open rows come from separate Mainboard / SME lists; closed rows carry
  // ipo_type from the API ("MAIN_IPO" or "SME").
  String _ipoTypeLabel(dynamic ipo) {
    if (ipo is Msg) {
      return (ipo.ipoType ?? "").toUpperCase() == "SME" ? "SME" : "Mainboard";
    }
    return ipo is SMEIPO ? "SME" : "Mainboard";
  }

  // Type column shows the IPO status (Open / Pre-open / Closed).
  String _statusLabel(dynamic ipo) {
    if (ipo is Msg) return "Closed";
    return ipostartdate(ipo.biddingStartDate, ipo.biddingEndDate) ?? "Closed";
  }

  int _statusRank(dynamic ipo) {
    switch (_statusLabel(ipo)) {
      case "Open":
        return 0;
      case "Pre-open":
        return 1;
      default:
        return 2;
    }
  }

  shadcn.TableCell _buildTypeCell(dynamic ipo, String uniqueId,
      bool rowIsHovered, ThemesProvider theme, VoidCallback onTap) {
    final status = _statusLabel(ipo);
    return _buildShadcnCell(
      uniqueId: uniqueId,
      rowIsHovered: rowIsHovered,
      theme: theme,
      onTap: onTap,
      // Every status gets a badge: Open green, Pre-open grey, Closed red.
      child: Align(
          alignment: Alignment.centerLeft, child: _buildStatusBadge(status)),
      // child: status == "Closed"
      //     ? Align(alignment: Alignment.centerLeft, child: _buildClosedBadge())
      //     : Text(
      //   // _ipoTypeLabel(ipo),
      //   status,
      //   style: MyntWebTextStyles.bodyMedium(
      //         context,
      //         color: resolveThemeColor(context,
      //             dark: MyntColors.textPrimaryDark,
      //             light: MyntColors.textPrimary),
      //         fontWeight: MyntFonts.medium,
      //       ),
      //   overflow: TextOverflow.ellipsis,
      //   maxLines: 1,
      // ),
    );
  }

  double? _minAmountValue(dynamic ipo) {
    double price;
    double qty;
    if (ipo is Msg) {
      price = (ipo.minPrice ?? 0).toDouble();
      qty = (ipo.minBidQu ?? 0).toDouble();
    } else {
      price = double.tryParse(ipo.minPrice?.toString() ?? "") ?? 0;
      qty = double.tryParse(ipo.minBidQuantity?.toString() ?? "") ?? 0;
    }
    if (price <= 0 || qty <= 0) return null;
    return price * qty;
  }

  String _sortName(dynamic ipo) {
    final name = ipo is Msg ? (ipo.companyName ?? ipo.name ?? "") : (ipo.name ?? "");
    return name.toString().trim().toLowerCase();
  }

  DateTime? _sortStartDate(dynamic ipo) {
    final s = ipo is Msg ? ipo.iPOStartDate : ipo.biddingStartDate;
    return (s == null || s.isEmpty) ? null : _tryParseClosedDate(s);
  }

  DateTime? _sortEndDate(dynamic ipo) {
    final s = ipo is Msg ? ipo.iPOEndDate : ipo.biddingEndDate;
    return (s == null || s.isEmpty) ? null : _tryParseClosedDate(s);
  }

  int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  String _toTitleCase(String input) {
    return input
        .toLowerCase()
        .split(' ')
        .map((word) =>
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  Widget _buildIPOTable(List<dynamic> ipos, ThemesProvider theme,
      IPOProvider ipoProvider, TranctionProvider upiProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Allocation: All columns 25%
        // final nameWidth = width * 0.35;
        // final dateWidth = width * 0.25;
        // final priceWidth = width * 0.15;
        // final minWidth = width * 0.25;
        // Type column added so Mainboard/SME can be sorted on its own.
        final nameWidth = width * 0.30;
        final typeWidth = width * 0.12;
        final dateWidth = width * 0.23;
        final priceWidth = width * 0.15;
        final minWidth = width * 0.20;

        final columnWidths = {
          0: shadcn.FixedTableSize(nameWidth),
          1: shadcn.FixedTableSize(typeWidth),
          2: shadcn.FixedTableSize(dateWidth),
          3: shadcn.FixedTableSize(priceWidth),
          4: shadcn.FixedTableSize(minWidth),
        };

        return shadcn.OutlinedContainer(
          child: Column(
            children: [
              SizedBox(
                height: 50,
                child: shadcn.Table(
                  columnWidths: columnWidths,
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  rows: [
                    shadcn.TableHeader(
                      cells: [
                        _buildHeaderCell("Stock name", 0, theme,
                            padding: const EdgeInsets.only(
                                left: 15.0,
                                right: 12.0,
                                top: 12.0,
                                bottom: 12.0)),
                        // Sort index 2 = Status (0 name, 1 date kept as before).
                        // _buildHeaderCell("Type", 2, theme),
                        _buildHeaderCell("Status", 2, theme),
                        _buildHeaderCell("IPO date", 1, theme),
                        _buildHeaderCell("Price range", -1, theme,
                            alignRight: true),
                        // _buildHeaderCell("Min. amount", -1, theme,
                        _buildHeaderCell("Min. amount", 3, theme,
                            alignRight: true,
                            padding: const EdgeInsets.only(
                                left: 12.0,
                                right: 24.0,
                                top: 12.0,
                                bottom: 12.0)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ipos.isEmpty
                    ? const Center(child: NoDataFoundWeb())
                    : SingleChildScrollView(
                        child: shadcn.Table(
                          columnWidths: columnWidths,
                          defaultRowHeight: const shadcn.FixedTableSize(60),
                          rows: ipos.asMap().entries.map((entry) {
                            return _buildShadcnRow(entry.value, entry.key, theme,
                                ipoProvider, upiProvider);
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Header text style
  // 14px, weight 600, MyntColors for text
  TextStyle _getHeaderStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableHeader(
      context,
      color: color,
      darkColor: color ?? MyntColors.textSecondaryDark,
      lightColor: color ?? MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  Widget _buildSortArrow() {
    return Icon(
      _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
      size: 16,
      color: resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary),
    );
  }

  shadcn.TableCell _buildHeaderCell(
      String text, int sortIndex, ThemesProvider theme,
      {bool alignRight = false, EdgeInsets? padding}) {
    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: GestureDetector(
        // Whole header cell is tappable, not just the label text.
        behavior: HitTestBehavior.opaque,
        // onTap: sortIndex >= 0
        //     ? () => _onSortTable(sortIndex, !_sortAscending)
        //     : null,
        onTap: sortIndex >= 0 ? () => _onSortTable(sortIndex, true) : null,
        child: Container(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 12.0),
          // decoration: BoxDecoration(
          //   color: theme.isDarkMode
          //       ? Colors.white.withOpacity(0.04)
          //       : Colors.black.withOpacity(0.03),
          // ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sort arrow on the sorted column, as in the Bonds table:
              // before the label when right-aligned, after it otherwise.
              if (alignRight && sortIndex >= 0 && _sortColumnIndex == sortIndex) ...[
                _buildSortArrow(),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: _getHeaderStyle(context),
              ),
              if (!alignRight && sortIndex >= 0 && _sortColumnIndex == sortIndex) ...[
                const SizedBox(width: 4),
                _buildSortArrow(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  shadcn.TableRow _buildShadcnRow(dynamic ipo, int index, ThemesProvider theme,
      IPOProvider ipoProvider, TranctionProvider upiProvider) {
    if (ipo is Msg) {
      return _buildClosedShadcnRow(ipo, index, theme, ipoProvider);
    }
    final uniqueId = '${ipo.id ?? ""}$index';
    final isPreOpen =
        ipostartdate(ipo.biddingStartDate, ipo.biddingEndDate) == "Pre-open";
    final status =
        ipostartdate(ipo.biddingStartDate, ipo.biddingEndDate) ?? "Closed";
    // Also highlight when popover is open for this row
    final rowIsHovered = _hoveredRowId == uniqueId || _popoverRowId == uniqueId;

    return shadcn.TableRow(
      cells: [
        // Stock Name Cell with dropdown menu
        _buildNameCellWithActions(
          ipo: ipo,
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered || _popoverRowId == uniqueId,
          theme: theme,
          status: status,
          isPreOpen: isPreOpen,
          ipoProvider: ipoProvider,
          upiProvider: upiProvider,
        ),
        // Type Cell
        _buildTypeCell(ipo, uniqueId, rowIsHovered, theme,
            () => _onIPOTap(context, ipo, ipoProvider)),
        // IPO Date Cell
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          onTap: () => _onIPOTap(context, ipo, ipoProvider),
          child: Text(
            _formatIPODate(ipo),
            style: MyntWebTextStyles.bodyMedium(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        ),
        // Price Range Cell
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          alignRight: true,
          onTap: () => _onIPOTap(context, ipo, ipoProvider),
          child: Text(
            _formatPriceRange(ipo),
            style: MyntWebTextStyles.bodyMedium(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        // Min Amount Cell
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          alignRight: true,
          padding: const EdgeInsets.only(
              left: 8.0, right: 24.0, top: 8.0, bottom: 8.0),
          onTap: () => _onIPOTap(context, ipo, ipoProvider),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatMinAmount(ipo),
                style: MyntWebTextStyles.bodyMedium(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                  fontWeight: MyntFonts.medium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (_getLotSize(ipo) != null) ...[
                const SizedBox(height: 1),
                Text(
                  "${_getLotSize(ipo)} Qty",
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary),
                    fontWeight: MyntFonts.medium,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  shadcn.TableRow _buildClosedShadcnRow(
      Msg ipo, int index, ThemesProvider theme, IPOProvider ipoProvider) {
    final uniqueId = 'closed_${ipo.id ?? ""}_$index';
    final rowIsHovered = _hoveredRowId == uniqueId;
    void onTap() => _onClosedIPOTap(context, ipo, ipoProvider);

    return shadcn.TableRow(
      cells: [
        _buildClosedNameCell(ipo, uniqueId, rowIsHovered, theme, onTap),
        _buildTypeCell(ipo, uniqueId, rowIsHovered, theme, onTap),
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          onTap: onTap,
          child: Text(
            _formatClosedIPODate(ipo),
            style: MyntWebTextStyles.bodyMedium(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        ),
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          alignRight: true,
          onTap: onTap,
          child: Text(
            _formatClosedPriceRange(ipo),
            style: MyntWebTextStyles.bodyMedium(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        _buildShadcnCell(
          uniqueId: uniqueId,
          rowIsHovered: rowIsHovered,
          theme: theme,
          alignRight: true,
          padding: const EdgeInsets.only(
              left: 8.0, right: 24.0, top: 8.0, bottom: 8.0),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatClosedMinAmount(ipo),
                style: MyntWebTextStyles.bodyMedium(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                  fontWeight: MyntFonts.medium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (ipo.minBidQu != null && ipo.minBidQu! > 0) ...[
                const SizedBox(height: 1),
                Text(
                  "${ipo.minBidQu} Qty",
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary),
                    fontWeight: MyntFonts.medium,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  shadcn.TableCell _buildClosedNameCell(Msg ipo, String uniqueId,
      bool rowIsHovered, ThemesProvider theme, VoidCallback onTap) {
    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredRowId = uniqueId),
        onExit: (_) => setState(() => _hoveredRowId = null),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            color: rowIsHovered
                ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary)
                    .withOpacity(theme.isDarkMode ? 0.06 : 0.10)
                : Colors.transparent,
            padding: const EdgeInsets.only(
                left: 15.0, right: 8.0, top: 8.0, bottom: 8.0),
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _toTitleCase(ipo.companyName ?? ipo.name ?? ""),
                  style: MyntWebTextStyles.bodyMedium(
                    context,
                    fontWeight: MyntFonts.medium,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Text(
                    //   ipo.ipoType ?? "IPO",
                    // API sends "MAIN_IPO"; show "IPO" like the open rows.
                    Text(
                      // _ipoTypeLabel(ipo) == "SME" ? "SME" : "IPO",
                      _ipoTypeLabel(ipo) == "SME" ? "SME" : "Main",
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                    // Closed badge moved to the Type column.
                    // const SizedBox(width: 6),
                    // _buildClosedBadge(),
                    if (ipo.totalsub != null && ipo.totalsub!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        "${ipo.totalsub}x sub",
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary),
                          fontWeight: MyntFonts.medium,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatClosedIPODate(Msg ipo) {
    try {
      final startStr = ipo.iPOStartDate;
      final endStr = ipo.iPOEndDate;

      if (startStr == null ||
          startStr.isEmpty ||
          endStr == null ||
          endStr.isEmpty) {
        return "-";
      }

      DateTime? startDate;
      DateTime? endDate;

      startDate = _tryParseClosedDate(startStr);
      endDate = _tryParseClosedDate(endStr);

      if (startDate == null || endDate == null) return "-";

      final startDayStr = _getOrdinalSuffix(startDate.day);
      final endDayStr = _getOrdinalSuffix(endDate.day);
      final startMonthYear = DateFormat('MMM yyyy').format(startDate);
      final endMonthYear = DateFormat('MMM yyyy').format(endDate);

      final isSameDay = startDate.year == endDate.year &&
          startDate.month == endDate.month &&
          startDate.day == endDate.day;

      if (isSameDay) {
        return "$startDayStr $startMonthYear";
      } else if (startMonthYear == endMonthYear) {
        return "$startDayStr - $endDayStr $endMonthYear";
      } else {
        return "$startDayStr $startMonthYear - $endDayStr $endMonthYear";
      }
    } catch (_) {
      return "-";
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = status == "Open"
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : status == "Pre-open"
            ? resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary)
            : resolveThemeColor(context,
                dark: MyntColors.lossDark, light: MyntColors.loss);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: MyntWebTextStyles.bodySmall(
          context,
          color: color,
          fontWeight: MyntFonts.semiBold,
        ),
      ),
    );
  }

  // Replaced by _buildStatusBadge (all statuses get a badge).
  // Widget _buildClosedBadge() {
  //   final color = resolveThemeColor(context,
  //       dark: MyntColors.lossDark, light: MyntColors.loss);
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
  //     decoration: BoxDecoration(
  //       color: color.withOpacity(0.12),
  //       borderRadius: BorderRadius.circular(4),
  //     ),
  //     child: Text(
  //       "Closed",
  //       style: MyntWebTextStyles.bodySmall(
  //         context,
  //         color: color,
  //         fontWeight: MyntFonts.semiBold,
  //       ),
  //     ),
  //   );
  // }

  DateTime? _tryParseClosedDate(String s) {
    const formats = [
      "MMM dd, yyyy",
      "dd-MMM-yyyy",
      "dd-MM-yyyy",
      "EEE, dd MMM yyyy HH:mm:ss",
    ];
    for (final f in formats) {
      try {
        return DateFormat(f).parse(s);
      } catch (_) {}
    }
    return null;
  }

  String _formatClosedPriceRange(Msg ipo) {
    final range = ipo.priceRange;
    if (range == null || range.isEmpty) return "-";
    final parts = range.split('-').map((s) => s.trim()).toList();
    if (parts.length == 2) {
      return "₹${parts[0]} - ₹${parts[1]}";
    }
    return "₹$range";
  }

  String _formatClosedMinAmount(Msg ipo) {
    final minPrice = ipo.minPrice;
    final minQty = ipo.minBidQu;
    if (minPrice == null || minQty == null || minPrice <= 0 || minQty <= 0) {
      return "-";
    }
    final amount = minPrice * minQty;
    return "₹${convertCurrencyINRStandard(amount)}";
  }

  Future<void> _onClosedIPOTap(
      BuildContext context, Msg ipo, IPOProvider ipoProvider) async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      // await ipoProvider.getIpoSinglePage(ipoName: "${ipo.companyName}");
      // Bug fix: a failed request returns null but keeps the previous IPO's
      // details in the provider; tell the sheet so it doesn't show them.
      final details =
          await ipoProvider.getIpoSinglePage(ipoName: "${ipo.companyName}");

      if (!context.mounted) return;

      shadcn.openSheet(
        context: context,
        position: shadcn.OverlayPosition.end,
        barrierColor: Colors.transparent,
        builder: (sheetContext) {
          return Container(
            width: 480,
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.backgroundColorDark,
                  light: MyntColors.backgroundColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            // child: IpoDetailsSheetWeb(ipo: ipo, parentContext: context),
            child: IpoDetailsSheetWeb(
                ipo: ipo,
                parentContext: context,
                detailsLoaded: details != null),
          );
        },
      );
    } finally {
      _isNavigating = false;
    }
  }

  shadcn.TableCell _buildShadcnCell({
    required Widget child,
    required String uniqueId,
    required bool rowIsHovered,
    required ThemesProvider theme,
    VoidCallback? onTap,
    bool alignRight = false,
    EdgeInsets? padding,
  }) {
    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredRowId = uniqueId),
        onExit: (_) => setState(() => _hoveredRowId = null),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            color: rowIsHovered
                ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark, light: MyntColors.primary)
                    .withOpacity(theme.isDarkMode ? 0.06 : 0.10)
                : Colors.transparent,
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            width: double.infinity,
            height: double.infinity,
            child: Align(
              alignment:
                  alignRight ? Alignment.centerRight : Alignment.centerLeft,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  // Build name cell with hover dropdown menu
  shadcn.TableCell _buildNameCellWithActions({
    required dynamic ipo,
    required String uniqueId,
    required bool rowIsHovered,
    required ThemesProvider theme,
    required String status,
    required bool isPreOpen,
    required IPOProvider ipoProvider,
    required TranctionProvider upiProvider,
  }) {
    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _hoveredRowId = uniqueId);
          if (_activePopoverController != null && _popoverRowId == uniqueId) {
            _cancelPopoverCloseTimer();
          }
        },
        onExit: (_) {
          setState(() => _hoveredRowId = null);
          if (_activePopoverController != null && !_isHoveringDropdown) {
            _startPopoverCloseTimer();
          }
        },
        child: GestureDetector(
          onTap: () => _onIPOTap(context, ipo, ipoProvider),
          child: Container(
            color: rowIsHovered
                ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark, light: MyntColors.primary)
                    .withOpacity(theme.isDarkMode ? 0.06 : 0.10)
                : Colors.transparent,
            padding: const EdgeInsets.only(
                left: 15.0, right: 8.0, top: 8.0, bottom: 8.0),
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // IPO name and details
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(right: rowIsHovered ? 40.0 : 0.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _toTitleCase(ipo.name ?? ""),
                          style: MyntWebTextStyles.bodyMedium(
                            context,
                            fontWeight: MyntFonts.medium,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (ipo.symbol != null) ...[
                              Text(
                                ipo.symbol ?? "",
                                style: MyntWebTextStyles.bodySmall(
                                  context,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary),
                                  fontWeight: MyntFonts.medium,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              // ipo is SMEIPO ? "SME" : "IPO",
                              ipo is SMEIPO ? "SME" : "Main",
                              style: MyntWebTextStyles.bodySmall(
                                context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                                fontWeight: MyntFonts.medium,
                              ),
                            ),
                            // Status moved to the Type column.
                            // const SizedBox(width: 6),
                            // Text(
                            //   status,
                            //   style: MyntWebTextStyles.bodySmall(
                            //     context,
                            //     color: resolveThemeColor(context,
                            //         dark: MyntColors.textSecondaryDark,
                            //         light: MyntColors.textSecondary),
                            //     fontWeight: MyntFonts.medium,
                            //   ),
                            // ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Dropdown button on hover
                if (rowIsHovered)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildOptionsMenuButton(
                        ipo: ipo,
                        uniqueId: uniqueId,
                        isPreOpen: isPreOpen,
                        ipoProvider: ipoProvider,
                        upiProvider: upiProvider,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build the 3-dot options menu button with shadcn dropdown
  Widget _buildOptionsMenuButton({
    required dynamic ipo,
    required String uniqueId,
    required bool isPreOpen,
    required IPOProvider ipoProvider,
    required TranctionProvider upiProvider,
  }) {
    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          onTap: () {
            // Close any existing popover first
            _closePopover();

            // Build menu items
            List<shadcn.MenuItem> menuItems = [];
            final iconColor = resolveThemeColor(context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary);
            final textColor = resolveThemeColor(context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary);

            // Apply option
            menuItems.add(
              _buildMenuButton(
                icon: Icons.check_circle_outline,
                title: isPreOpen ? 'Pre Apply' : 'Apply',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  _onApplyPressed(context, ipo, ipoProvider, upiProvider);
                },
              ),
            );

            // Divider
            menuItems.add(const shadcn.MenuDivider());

            // Details option
            menuItems.add(
              _buildMenuButton(
                icon: Icons.info_outline,
                title: 'Details',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  _onIPOTap(context, ipo, ipoProvider);
                },
              ),
            );

            // Create a controller for this popover
            final controller = shadcn.PopoverController();
            _activePopoverController = controller;
            _popoverRowId = uniqueId;

            // Show the shadcn popover menu anchored to this button
            controller.show(
              context: buttonContext,
              alignment: Alignment.topRight,
              offset: const Offset(0, 4),
              builder: (ctx) {
                return MouseRegion(
                  onEnter: (_) {
                    _isHoveringDropdown = true;
                    _cancelPopoverCloseTimer();
                  },
                  onExit: (_) {
                    _isHoveringDropdown = false;
                    _startPopoverCloseTimer();
                  },
                  child: shadcn.DropdownMenu(
                    children: menuItems,
                  ),
                );
              },
            );

            // Force rebuild to show row highlight
            setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.textWhite,
                  light: MyntColors.textWhite),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: resolveThemeColor(context,
                      dark: Colors.transparent,
                      light: Colors.grey),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.more_vert,
              size: 18,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimary,
                  light: MyntColors.textPrimary),
            ),
          ),
        );
      },
    );
  }

  // Helper method for building menu buttons
  shadcn.MenuButton _buildMenuButton({
    required IconData icon,
    required String title,
    required void Function(BuildContext) onPressed,
    required Color iconColor,
    required Color textColor,
  }) {
    return shadcn.MenuButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Text(
              title,
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.medium,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Same column again reverses; a new column starts ascending (as Upcoming).
  void _onSortTable(int columnIndex, bool ascending) {
    setState(() {
      // _sortColumnIndex = columnIndex;
      // _sortAscending = ascending;
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = ascending;
      }
    });
  }

  String _formatIPODate(dynamic ipo) {
    try {
      String? startDateStr = ipo.biddingStartDate;
      String? endDateStr = ipo.biddingEndDate;

      if (startDateStr == null ||
          startDateStr.isEmpty ||
          endDateStr == null ||
          endDateStr.isEmpty) {
        return "-";
      }

      // Parse start date (format: dd-MM-yyyy)
      List<String> startParts = startDateStr.split('-');
      if (startParts.length >= 3) {
        int startDay = int.parse(startParts[0]);
        int startMonth = int.parse(startParts[1]);
        int startYear = int.parse(startParts[2]);
        DateTime startDate = DateTime(startYear, startMonth, startDay);

        // Parse end date (format: EEE, dd MMM yyyy HH:mm:ss)
        DateTime endDate;
        try {
          endDate = DateFormat("EEE, dd MMM yyyy HH:mm:ss").parse(endDateStr);
        } catch (e) {
          // Try alternative format if the above fails
          try {
            // Try parsing as dd-MM-yyyy if it's in that format
            List<String> endParts = endDateStr.split('-');
            if (endParts.length >= 3) {
              int endDay = int.parse(endParts[0]);
              int endMonth = int.parse(endParts[1]);
              int endYear = int.parse(endParts[2]);
              endDate = DateTime(endYear, endMonth, endDay);
            } else {
              return "-";
            }
          } catch (e2) {
            return "-";
          }
        }

        // Format with ordinal suffix
        String startDayStr = _getOrdinalSuffix(startDay);
        String endDayStr = _getOrdinalSuffix(endDate.day);

        // Format month and year
        String startMonthYear = DateFormat('MMM yyyy').format(startDate);
        String endMonthYear = DateFormat('MMM yyyy').format(endDate);

        // Check if same day
        bool isSameDay = startDate.year == endDate.year &&
            startDate.month == endDate.month &&
            startDate.day == endDate.day;

        // If same day, show: "28th Nov 2025"
        if (isSameDay) {
          return "$startDayStr $startMonthYear";
        }
        // If same month, show: "28th - 30th Nov 2025"
        else if (startMonthYear == endMonthYear) {
          return "$startDayStr - $endDayStr $endMonthYear";
        }
        // If different months, show: "28th Nov - 1st Dec 2025"
        else {
          return "$startDayStr $startMonthYear - $endDayStr $endMonthYear";
        }
      }
    } catch (e) {
      return "-";
    }
    return "-";
  }

  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return "${day}th";
    }
    switch (day % 10) {
      case 1:
        return "${day}st";
      case 2:
        return "${day}nd";
      case 3:
        return "${day}rd";
      default:
        return "${day}th";
    }
  }

  String _formatPriceRange(dynamic ipo) {
    try {
      String? minPrice = ipo.minPrice;
      String? maxPrice = ipo.maxPrice;

      if (minPrice == null ||
          minPrice.isEmpty ||
          maxPrice == null ||
          maxPrice.isEmpty) {
        return "-";
      }

      // Remove any decimal points if they're .00
      double min = double.tryParse(minPrice) ?? 0;
      double max = double.tryParse(maxPrice) ?? 0;

      String minStr =
          min == min.toInt() ? min.toInt().toString() : min.toStringAsFixed(2);
      String maxStr =
          max == max.toInt() ? max.toInt().toString() : max.toStringAsFixed(2);

      return "₹$minStr - ₹$maxStr";
    } catch (e) {
      return "-";
    }
  }

  String _formatMinAmount(dynamic ipo) {
    try {
      final minPrice = double.tryParse(ipo.minPrice ?? "0") ?? 0;
      final minQty = int.tryParse(ipo.minBidQuantity ?? "0") ?? 0;

      if (minPrice > 0 && minQty > 0) {
        final amount = (minPrice * minQty).toInt();
        return "₹${convertCurrencyINRStandard(amount)}";
      }

      return "-";
    } catch (e) {
      return "-";
    }
  }

  String? _getLotSize(dynamic ipo) {
    try {
      // Priority: lotSize, fallback to minBidQuantity
      String? lotSize = ipo.lotSize ?? ipo.minBidQuantity;
      if (lotSize == null || lotSize.isEmpty || lotSize == "null") {
        return null;
      }
      return lotSize;
    } catch (e) {
      return null;
    }
  }

  Future<void> _onIPOTap(
      BuildContext context, dynamic ipo, IPOProvider ipoProvider) async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
     // await ipoProvider.getIpoSinglePage(ipoName: "${ipo.name}");
     // Bug fix: a failed request returns null but keeps the previous IPO's
     // details in the provider; tell the sheet so it doesn't show them.
     final details =
         await ipoProvider.getIpoSinglePage(ipoName: "${ipo.name}");

    if (context.mounted) {
      shadcn.openSheet(
        context: context,
        position: shadcn.OverlayPosition.end,
        barrierColor: Colors.transparent,
        builder: (sheetContext) {
          return Container(
            width: 480,
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.backgroundColorDark,
                  light: MyntColors.backgroundColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            // child: IpoDetailsSheetWeb(ipo: ipo, parentContext: context),
            child: IpoDetailsSheetWeb(
                ipo: ipo,
                parentContext: context,
                detailsLoaded: details != null),
          );
        },
      );
      }
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _onApplyPressed(BuildContext context, dynamic ipo,
      IPOProvider ipoProvider, TranctionProvider upiProvider) async {
    ipoProvider.setisSMEPlaceOrderBtnActiveValue = false;
    ipoProvider.setisMainIPOPlaceOrderBtnActiveValue = false;

    // Ensure bank details are available
    if (upiProvider.bankdetails == null ||
        upiProvider.bankdetails?.dATA == null ||
        upiProvider.bankdetails!.dATA!.isEmpty) {
      await upiProvider.fetchfundbank(context);
    }

    // Fetch UPI ID if bank details are now available
    if (upiProvider.bankdetails?.dATA != null &&
        upiProvider.bankdetails!.dATA!.isNotEmpty) {
      final bankData = upiProvider.bankdetails!.dATA![upiProvider.indexss];
      if (bankData.length >= 3) {
        // Start fetching but don't strictly await if it takes too long
        upiProvider.fetchupiIdView(
          bankData[1] ?? "",
          bankData[2] ?? "",
        );
      }
    }

    if (ipo is SMEIPO) {
      await ipoProvider.smeipocategory(ipo);
      if (context.mounted) {
        UnifiedIpoOrderScreen.showDraggable(
          context: context,
          ipoData: ipo,
        );
      }
    } else {
      await ipoProvider.mainipocategory(ipo as MainIPO);
      if (context.mounted) {
        UnifiedIpoOrderScreen.showDraggable(
          context: context,
          ipoData: ipo,
        );
      }
    }
  }
}
