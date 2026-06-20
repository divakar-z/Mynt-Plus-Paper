import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:mynt_plus/provider/ledger_provider.dart';
import 'package:mynt_plus/provider/mf_provider.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/screens/web/profile/pledge/pledge_details.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';
import 'package:mynt_plus/sharedWidget/loader_ui.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';

import '../../../../models/desk_reports_model/pledge_unpledge_model.dart';
import '../../../../provider/thems.dart';
import '../../../../res/global_state_text.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../routes/route_names.dart';
import '../../../../sharedWidget/list_divider.dart';
import '../../../../sharedWidget/snack_bar.dart';

class PledgeFilter extends StatefulWidget {
  final String activetabe;
  final String searchQuery;
  const PledgeFilter(
      {super.key, required this.activetabe, this.searchQuery = ''});

  @override
  State<PledgeFilter> createState() => _PledgeFilterState();
}

class _PledgeFilterState extends State<PledgeFilter> {
  final Set<String> _expandedItems = {};
  final ScrollController _tableScrollController = ScrollController();

  static const int _pageSize = 15;
  int _displayedCount = _pageSize;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tableScrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PledgeFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activetabe != oldWidget.activetabe ||
        widget.searchQuery != oldWidget.searchQuery) {
      _displayedCount = _pageSize;
    }
  }

  @override
  void dispose() {
    _tableScrollController.removeListener(_onScroll);
    _tableScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;
    final maxScroll = _tableScrollController.position.maxScrollExtent;
    final currentScroll = _tableScrollController.offset;
    if (currentScroll >= maxScroll - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    setState(() {
      _isLoadingMore = true;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _displayedCount += _pageSize;
        _isLoadingMore = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenheight = MediaQuery.of(context).size.height;
    List<Data> showlist = [];
    List<Tab> orderTabName = [
      Tab(text: "Pledge"),
      Tab(text: "Non-Pledge"),
      Tab(text: "Non-Approved"),
    ];

    return Consumer(builder: (context, WidgetRef ref, _) {
      final theme = ref.watch(themeProvider);
      var cashstat = 0.0;
      var noncash = 0.0;
      var pledgedvalue = [];
      final ledgerprovider = ref.watch(ledgerProvider);
      if (ledgerprovider.pledgeandunpledge != null &&
          ledgerprovider.pledgeandunpledge!.data != null) {
        for (var i = 0;
            i < ledgerprovider.pledgeandunpledge!.data!.length;
            i++) {
          final value = ledgerprovider.pledgeandunpledge!.data![i];

          // Check if item matches the current tab filter
          bool matchesTab = false;
          if ((value.initiated == "0" &&
                  value.status == 'Ok' &&
                  (double.parse(value.nSOHQTY.toString()).toInt()) +
                          (double.parse(value.sOHQTY.toString()).toInt()) !=
                      0) &&
              (widget.activetabe == "0")) {
            matchesTab = true;
          } else if (((double.parse(value.cOLQTY.toString()).toInt()) != 0) &&
              widget.activetabe == "1") {
            matchesTab = true;
          } else if (value.status == "Not_ok" &&
              widget.activetabe == "2" &&
              ((double.parse(value.cOLQTY.toString()).toInt()) == 0)) {
            matchesTab = true;
          }

          // Apply cash/noncash filter
          if (matchesTab && ledgerprovider.pledgeCashFilter != 'all') {
            if (ledgerprovider.pledgeCashFilter == 'cash' && value.cRnc != 'cash') {
              matchesTab = false;
            } else if (ledgerprovider.pledgeCashFilter == 'noncash' && value.cRnc != 'noncash') {
              matchesTab = false;
            }
          }

          // If matches tab, check search query
          if (matchesTab) {
            if (widget.searchQuery.isEmpty) {
              showlist.add(value);
            } else {
              // Search in multiple fields
              String searchQuery = widget.searchQuery.toLowerCase();
              String nseSymbol = (value.nSESYMBOL ?? '').toLowerCase();
              String scripName = (value.sCRIPNAME ?? '').toLowerCase();
              String bseSymbol = (value.bSESYMBOL ?? '').toLowerCase();
              String isin = (value.iSIN ?? '').toLowerCase();

              if (nseSymbol.contains(searchQuery) ||
                  scripName.contains(searchQuery) ||
                  bseSymbol.contains(searchQuery) ||
                  isin.contains(searchQuery)) {
                showlist.add(value);
              }
            }
          }
        }
      }

      Future<void> _refresh() async {
        await Future.delayed(Duration(seconds: 0));
        ledgerprovider.getCurrentDate("pandu");
        ledgerprovider.fetchpledgeandunpledge(context);
      }

      final List<dynamic> displaypledgedvalue = pledgedvalue;

      if (showlist.length == 0 || showlist.isEmpty){
        return Center(
            child: NoDataFound(
              secondaryEnabled: false,
            ));
      }

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _mainpage(ledgerprovider, theme, context, showlist,
                      widget.activetabe, ref),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  _mainpage(LDProvider ledgerprovider, ThemesProvider theme,
      BuildContext context, dataval, String tab, ref) {
    // ── Progressive loading: only render up to _displayedCount rows ──
    final int totalItems = dataval.length;
    final bool hasMore = _displayedCount < totalItems;
    final int visibleCount = _displayedCount < totalItems ? _displayedCount : totalItems;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double totalWidth = constraints.maxWidth;
            final double symbolWidth = totalWidth * 0.25;
            final double qtyPledgeWidth = totalWidth * 0.15;
            final double totalQtyWidth = totalWidth * 0.12;
            final double valueWidth = totalWidth * 0.16;
            final double mrgEstWidth = totalWidth * 0.18;
            final double estPctWidth = totalWidth * 0.14;

            final Map<int, shadcn.TableSize> colWidths = {
              0: shadcn.FixedTableSize(symbolWidth),
              1: shadcn.FixedTableSize(qtyPledgeWidth),
              2: shadcn.FixedTableSize(totalQtyWidth),
              3: shadcn.FixedTableSize(valueWidth),
              4: shadcn.FixedTableSize(mrgEstWidth),
              5: shadcn.FixedTableSize(estPctWidth),
            };

            final String qtyHeader = tab == '0'
                ? 'Qty to pledge'
                : tab == '1'
                    ? 'Qty to unpledge'
                    : 'Qty';

            return shadcn.OutlinedContainer(
              child: Column(
                children: [
                  // Fixed Header
                  shadcn.Table(
                    defaultRowHeight: const shadcn.FixedTableSize(44),
                    columnWidths: colWidths,
                    rows: [
                      shadcn.TableHeader(
                        cells: [
                          _buildTableHeaderCell('Symbol', context),
                          _buildTableHeaderCell(qtyHeader, context, alignRight: true),
                          _buildTableHeaderCell('Total Qty', context, alignRight: true),
                          _buildTableHeaderCell('Value', context, alignRight: true),
                          _buildTableHeaderCell('Mrg / Est', context, alignRight: true),
                          _buildTableHeaderCell('Est %', context, alignRight: true),
                        ],
                      ),
                    ],
                  ),
                  // Data Rows
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _tableScrollController,
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        children: [
                          shadcn.Table(
                            defaultRowHeight: const shadcn.FixedTableSize(56),
                            columnWidths: colWidths,
                            rows: List.generate(visibleCount, (index) {
                              final value = dataval[index];
                              return _buildPledgeTableRow(
                                value: value,
                                index: index,
                                tab: tab,
                                ledgerprovider: ledgerprovider,
                                theme: theme,
                                context: context,
                                ref: ref,
                              );
                            }),
                          ),
                          // Loading indicator / record count footer
                          if (_isLoadingMore)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5),
                              ),
                            )
                          else if (hasMore)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Showing $visibleCount of $totalItems records — scroll down for more',
                                style: MyntWebTextStyles.tableCell(
                                  context,
                                  darkColor: MyntColors.textSecondaryDark,
                                  lightColor: MyntColors.textSecondary,
                                  fontWeight: MyntFonts.medium,
                                ).copyWith(fontSize: 12),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Showing all $totalItems records',
                                style: MyntWebTextStyles.tableCell(
                                  context,
                                  darkColor: MyntColors.textSecondaryDark,
                                  lightColor: MyntColors.textSecondary,
                                  fontWeight: MyntFonts.medium,
                                ).copyWith(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // Table Helper Methods
  // ============================================================

  shadcn.TableCell _buildTableHeaderCell(String label, BuildContext context,
      {bool alignRight = false}) {
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          style: MyntWebTextStyles.tableHeader(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
            fontWeight: MyntFonts.semiBold,
          ),
        ),
      ),
    );
  }

  shadcn.TableCell _buildTableDataCell(Widget child, BuildContext context,
      {bool alignRight = false, VoidCallback? onTap}) {
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: child,
    );
    if (onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: content,
        ),
      );
    }
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
      child: content,
    );
  }

  shadcn.TableRow _buildPledgeTableRow({
    required dynamic value,
    required int index,
    required String tab,
    required LDProvider ledgerprovider,
    required ThemesProvider theme,
    required BuildContext context,
    required dynamic ref,
  }) {
    final portfolio = ref.read(mfProvider);
    final isin = value.iSIN?.toString() ?? "";
    String mfname = "";
    if (portfolio.mfholdingnew?.data != null && isin.isNotEmpty) {
      for (var mfData in portfolio.mfholdingnew!.data!) {
        if (mfData.iSIN == isin) {
          mfname = mfData.name ?? "";
          break;
        }
      }
    }

    // Symbol display
    final String symbolName = value.sERIES == "GR" && mfname.isNotEmpty
        ? mfname
        : (value.nSESYMBOL ?? '--');

    // Calculate quantities based on tab
    int totalQty;
    String pledgeQty;

    if (tab == '0') {
      // Pledge tab: available qty
      totalQty = (double.tryParse(value.nSOHQTY?.toString() ?? '0')?.toInt() ?? 0) +
          (double.tryParse(value.sOHQTY?.toString() ?? '0')?.toInt() ?? 0);
      pledgeQty = value.dummvalue != null && value.dummvalue != 'null'
          ? '${double.tryParse(value.dummvalue.toString())?.toInt() ?? totalQty}'
          : '$totalQty';
    } else if (tab == '1') {
      // Unpledge tab: collateral qty
      totalQty = double.tryParse(value.cOLQTY?.toString() ?? '0')?.toInt() ?? 0;
      if (value.unPlegeQty != null && value.unPlegeQty != "0" && value.unPlegeQty != "") {
        pledgeQty = value.unPlegeQty!;
      } else if (value.dummunpledgevalue != null && value.dummunpledgevalue != 'null') {
        pledgeQty = '${double.tryParse(value.dummunpledgevalue.toString())?.toInt() ?? totalQty}';
      } else {
        pledgeQty = '$totalQty';
      }
    } else {
      // Non-approved tab
      totalQty = (double.tryParse(value.nSOHQTY?.toString() ?? '0')?.toInt() ?? 0) +
          (double.tryParse(value.sOHQTY?.toString() ?? '0')?.toInt() ?? 0);
      pledgeQty = value.dummvalue != null && value.dummvalue != 'null'
          ? '${double.tryParse(value.dummvalue.toString())?.toInt() ?? totalQty}'
          : '$totalQty';
    }

    // Value
    final double amountVal = double.tryParse(value.aMOUNT?.toString() ?? '0') ?? 0;

    // Margin / Estimated
    final bool isPledged = (double.tryParse(value.cOLQTY?.toString() ?? '0')?.toInt() ?? 0) != 0;
    final String mrgLabel = isPledged ? 'Mrg' : 'Est';
    final double mrgEstVal = isPledged
        ? (double.tryParse(value.margin?.toString() ?? '0') ?? 0)
        : (double.tryParse(value.estimated?.toString() ?? '0') ?? 0);

    // Est percentage
    final double estPct = double.tryParse(value.estPercentage?.toString() ?? '0') ?? 0;

    // Check if item has been selected/modified
    bool isItemSelected = false;
    if (tab == '0') {
      isItemSelected = value.dummvalue != null && value.dummvalue != 'null';
    } else if (tab == '1') {
      isItemSelected = value.dummunpledgevalue != null && value.dummunpledgevalue != 'null';
    }

    // Tap handler for qty edit
    void onQtyTap() {
      _handlePledgeRowTap(value, tab, ledgerprovider, context);
    }

    // Delete handler for removing item from pledge list.
    // Pledge Balance tab (tab == '1') deletes without confirmation;
    // other tabs go through _showDeleteConfirmDialog first.
    void onQtyDelete() async {
      if (tab != '1') {
        final confirmed =
            await _showDeleteConfirmDialog(context, symbolName, tab);
        if (confirmed != true) return;
      }
      final isinVal = value.iSIN?.toString() ?? '';
      ledgerprovider.removeSinglePledgeItem(
        isinVal,
        tab == '0' ? 'pledge' : 'unpledge',
        value,
      );
    }

    final textStyle = MyntWebTextStyles.tableCell(
      context,
      darkColor: MyntColors.textPrimaryDark,
      lightColor: MyntColors.textPrimary,
      fontWeight: MyntFonts.medium,
    );

    final greenStyle = MyntWebTextStyles.tableCell(
      context,
      darkColor: MyntColors.profitDark,
      lightColor: MyntColors.profit,
      fontWeight: MyntFonts.medium,
    );

    final cnc = (value.cRnc ?? '').toString().toLowerCase();
    final isCash = cnc == 'cash';
    final isNonCash = cnc == 'noncash';
    final showCashTag = tab == '1' && (isCash || isNonCash);

    // Row-level tap: clicking anywhere on the row opens the qty dialog.
    // Disabled on Non-Approved tab (no dialog) and on already-selected rows
    // in editable tabs (so the edit/delete icons stay reachable).
    final VoidCallback? rowTap =
        (tab != '2' && !isItemSelected) ? onQtyTap : null;

    return shadcn.TableRow(
      cells: [
        // Symbol + Cash / Non-Cash tag (only on Pledge Balance tab)
        _buildTableDataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  symbolName,
                  style: textStyle.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (showCashTag) ...[
                const SizedBox(width: 6),
                _buildCashTag(context, isCash: isCash),
              ],
            ],
          ),
          context,
          onTap: rowTap,
        ),
        // Qty to pledge/unpledge
        _buildTableDataCell(
          tab != '2'
              ? _buildQtyWidget(
                  pledgeQty,
                  onQtyTap,
                  context,
                  isSelected: isItemSelected,
                  onDelete: onQtyDelete,
                )
              : Text(pledgeQty, style: textStyle),
          context,
          alignRight: true,
          onTap: rowTap,
        ),
        // Total Qty
        _buildTableDataCell(
          Text('$totalQty', style: textStyle),
          context,
          alignRight: true,
          onTap: rowTap,
        ),
        // Value
        _buildTableDataCell(
          Text(amountVal.toStringAsFixed(2), style: textStyle),
          context,
          alignRight: true,
          onTap: rowTap,
        ),
        // Mrg / Est
        _buildTableDataCell(
          Text(
            '${mrgEstVal.toStringAsFixed(2)} ($mrgLabel)',
            style: greenStyle,
          ),
          context,
          alignRight: true,
          onTap: rowTap,
        ),
        // Est %
        _buildTableDataCell(
          Text('${estPct.toInt()} %', style: textStyle),
          context,
          alignRight: true,
          onTap: rowTap,
        ),
      ],
    );
  }

  Widget _buildQtyWidget(
    String qty,
    VoidCallback onTap,
    BuildContext context, {
    bool isSelected = false,
    VoidCallback? onDelete,
  }) {
    if (isSelected) {
      // Selected state: green color with edit/delete actions
      final profitColor = resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: profitColor.withValues(alpha: 0.1),
              border: Border.all(color: profitColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              qty,
              style: MyntWebTextStyles.tableCell(
                context,
                darkColor: MyntColors.profitDark,
                lightColor: MyntColors.profit,
                fontWeight: MyntFonts.semiBold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildActionIcon(
            icon: Icons.edit_outlined,
            color: resolveThemeColor(context,
                dark: MyntColors.primaryDark, light: MyntColors.primary),
            onTap: onTap,
            tooltip: 'Edit',
          ),
          const SizedBox(width: 2),
          _buildActionIcon(
            icon: Icons.delete_outline,
            color: resolveThemeColor(context,
                dark: MyntColors.lossDark, light: MyntColors.loss),
            onTap: onDelete ?? () {},
            tooltip: 'Remove',
          ),
        ],
      );
    }

    // Default unselected state
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: primaryColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              qty,
              style: MyntWebTextStyles.tableCell(
                context,
                darkColor: MyntColors.primaryDark,
                lightColor: MyntColors.primary,
                fontWeight: MyntFonts.medium,
              ),
            ),
            // const SizedBox(width: 4),
            // Text(
            //   '+',
            //   style: TextStyle(
            //     color: primaryColor,
            //     fontWeight: FontWeight.bold,
            //     fontSize: 14,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashTag(BuildContext context, {required bool isCash}) {
    final Color baseColor = isCash
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isCash ? 'Cash' : 'Non Cash',
        style: MyntWebTextStyles.tableCell(
          context,
          darkColor: baseColor,
          lightColor: baseColor,
          fontWeight: MyntFonts.semiBold,
        ).copyWith(fontSize: 10),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  void _handlePledgeRowTap(
      dynamic value, String tab, LDProvider ledgerprovider, BuildContext context) {
    if (tab == '0') {
      // Pledge tab
      if (ledgerprovider.pledgeorunpledge != 'unpledge') {
        if (double.parse(value.initiated.toString()).toInt() == 0) {
          ledgerprovider.screenclickedpledge = 'pledge';
          String val =
              "${double.parse(value.nSOHQTY.toString()).toInt() + double.parse(value.sOHQTY.toString()).toInt()}";
          String val2 =
              "${value.dummvalue != 'null' ? double.parse(value.dummvalue.toString()).toInt() : "null"}";
          ledgerprovider.setselectnetpledge(
              val2 == 'null' ? val : val2, val2 == 'null' ? val : val2);
          _showPledgeDialog(context, PledgeDeytails(data: value));
        } else {
          warningMessage(context, '${value.initiated} Qty is processing');
        }
      } else {
        warningMessage(context, 'Unpledged initiated so can\'t pledge');
      }
    } else if (tab == '1') {
      // Unpledge tab
      if (value.deleteselected != 'selected' && value.unPlegeQty == '') {
        if (ledgerprovider.pledgeorunpledge != 'pledge') {
          ledgerprovider.screenclickedpledge = 'unpledge';
          String val = "${double.parse(value.cOLQTY.toString()).toInt()}";
          String val2 =
              "${value.dummunpledgevalue != 'null' ? double.parse(value.dummunpledgevalue.toString()).toInt() : "null"}";
          ledgerprovider.setselectnetpledge(
              val2 == 'null' ? val : val2, val2 == 'null' ? val : val2);
          _showPledgeDialog(context, PledgeDeytails(data: value));
        } else {
          warningMessage(context, 'Pledged initiated so can\'t unpledge');
        }
      } else {
        warningMessage(context, 'Already pledged cant edit');
      }
    }
  }

  // ============================================================
  // Existing Helper Methods
  // ============================================================

  Future<bool?> _showDeleteConfirmDialog(
      BuildContext context, String symbolName, String tab) {
    final titleLabel =
        tab == '1' ? 'Remove Unpledge Item' : 'Remove Pledge Item';
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final dialogWidth =
            screenWidth * 0.9 > 400.0 ? 400.0 : screenWidth * 0.9;

        return Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: Container(
              width: dialogWidth,
              decoration: BoxDecoration(
                color: resolveThemeColor(dialogContext,
                    dark: MyntColors.dialogDark,
                    light: MyntColors.dialog),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: shadcn.Theme.of(dialogContext)
                              .colorScheme
                              .border,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            titleLabel,
                            overflow: TextOverflow.ellipsis,
                            style: MyntWebTextStyles.title(
                              dialogContext,
                              color: resolveThemeColor(dialogContext,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary),
                            ),
                          ),
                        ),
                        MyntCloseButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Are you sure you want to remove "$symbolName"?',
                          textAlign: TextAlign.center,
                          style: MyntWebTextStyles.body(
                            dialogContext,
                            fontWeight: FontWeight.w500,
                            color: resolveThemeColor(dialogContext,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 24),
                        MyntButton(
                          type: MyntButtonType.primary,
                          size: MyntButtonSize.large,
                          label: 'Delete',
                          isFullWidth: true,
                          backgroundColor: resolveThemeColor(
                            dialogContext,
                            dark: MyntColors.errorDark,
                            light: MyntColors.tertiary,
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale:
                Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  void _showPledgeDialog(BuildContext context, Widget content) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: content,
        ),
      ),
    );
  }

  int getDisplayQty(dynamic value) {
    final unPledge = int.tryParse(value.unPlegeQty.toString()) ?? 0;
    final nsoh = int.tryParse(value.nSOHQTY.toString()) ?? 0;
    final soh = int.tryParse(value.sOHQTY.toString()) ?? 0;

    if (unPledge > 0) return unPledge;
    if (nsoh > 0) return nsoh;
    if (soh > 0) return soh;

    return 0;
  }

  headingstat(String heading, String value, theme, String side) {
    return Column(
      crossAxisAlignment:
          side == 'right' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        TextWidget.subText(
            text: heading,
            color: Color(0xFF696969),
            textOverflow: TextOverflow.ellipsis,
            theme: theme.isDarkMode,
            fw: 0),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: TextWidget.titleText(
              text: "₹ $value",
              textOverflow: TextOverflow.ellipsis,
              theme: theme.isDarkMode,
              fw: 1),
        ),
      ],
    );
  }
}
