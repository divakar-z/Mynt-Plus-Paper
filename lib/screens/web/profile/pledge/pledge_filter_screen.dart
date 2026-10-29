import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:mynt_plus/provider/ledger_provider.dart';
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
import '../../../../utils/responsive_snackbar.dart';

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
          } else if (widget.activetabe == "2" &&
              (value.status ?? '').trim().toLowerCase() == "not_ok") {
            // Every Not_ok scrip is non-approved, including ones that still
            // carry collateral qty (approved when pledged, de-listed later).
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
        ledgerprovider.fetchpledgeandunpledge(context, showLoadErrors: true);
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
            // Available Balance carries an extra "Qty to unpledge" column
            // for holdings that are already partly pledged — but only when
            // some holding in the list actually has collateral to release,
            // otherwise it is a column of "--".
            final bool showUnpledgeColumn = tab == '0' &&
                dataval.any((v) =>
                    (double.tryParse(v.cOLQTY?.toString() ?? '0')?.toInt() ??
                        0) !=
                    0);

            final List<double> shares = showUnpledgeColumn
                ? const [0.15, 0.11, 0.21, 0.10, 0.14, 0.16, 0.13]
                : const [0.22, 0.20, 0.10, 0.15, 0.18, 0.15];

            final Map<int, shadcn.TableSize> colWidths = {
              for (var i = 0; i < shares.length; i++)
                i: shadcn.FixedTableSize(totalWidth * shares[i]),
            };

            // Non-Approved lists what would be pledged once approved, so it
            // carries the same header as Available Balance.
            final String qtyHeader =
                tab == '1' ? 'Qty to unpledge' : 'Qty to pledge';

            final bool pledgePending = ledgerprovider.listforpledge.isNotEmpty;

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
                          if (showUnpledgeColumn)
                            _buildTableHeaderCell('Qty to unpledge', context,
                                alignRight: true),
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
                                showUnpledgeColumn: showUnpledgeColumn,
                                pledgePending: pledgePending,
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
    required bool showUnpledgeColumn,
    required bool pledgePending,
    required LDProvider ledgerprovider,
    required ThemesProvider theme,
    required BuildContext context,
    required dynamic ref,
  }) {
    // Symbol display — always NSE_SYMBOL (consistent with mobile).
    final String symbolName = value.nSESYMBOL ?? '--';

    // Total Qty is the API's NET field on every tab.
    final int totalQty = double.tryParse(value.nET?.toString() ?? '0')?.toInt() ?? 0;

    // Collateral qty already pledged for this scrip.
    final int collateralQty =
        double.tryParse(value.cOLQTY?.toString() ?? '0')?.toInt() ?? 0;

    // Pledge and Non-approved tabs: available qty. The Pledge Balance tab
    // shows the pledged-shares cell instead.
    final int availableQty =
        (double.tryParse(value.nSOHQTY?.toString() ?? '0')?.toInt() ?? 0) +
            (double.tryParse(value.sOHQTY?.toString() ?? '0')?.toInt() ?? 0);
    final String pledgeQty =
        value.dummvalue != null && value.dummvalue != 'null'
            ? '${double.tryParse(value.dummvalue.toString())?.toInt() ?? availableQty}'
            : '$availableQty';

    final String qtyLabel = _qtyDisplay(pledgeQty);

    // A holding on Available Balance can already be partly pledged. That
    // collateral gets its own column, carrying the same data and the same
    // flow the Pledge Balance tab uses. _mainpage owns whether the column
    // exists at all, so the flag comes in rather than being re-derived.
    final bool showUnpledgeChip = showUnpledgeColumn && collateralQty != 0;

    // Regular ("C") and MTF ("F") unpledge separately, one stock + product
    // at a time; a pending pledge selection disables both.
    final String isin = value.iSIN?.toString() ?? '';

    void onUnpledgeTap(String prd) {
      if (pledgePending) return;
      if (ledgerprovider.unpledgeLocked(isin, prd)) {
        ResponsiveSnackBar.showWarning(
            context, 'Only one stock can be unpledged at a time.',
            duration: const Duration(seconds: 4));
        return;
      }
      _handlePledgeRowTap(value, '1', ledgerprovider, context, prd: prd);
    }

    Widget pledgedSharesCell() => _buildPledgedSharesCell(
          value,
          context,
          ledgerprovider: ledgerprovider,
          disabled: pledgePending,
          onUnpledge: onUnpledgeTap,
        );

    // Value
    final double amountVal = double.tryParse(value.aMOUNT?.toString() ?? '0') ?? 0;

    // Margin / Estimated
    final bool isPledged = collateralQty != 0;
    final String mrgLabel = isPledged ? 'Mrg' : 'Est';
    final double mrgEstVal = isPledged
        ? (double.tryParse(value.margin?.toString() ?? '0') ?? 0)
        : (double.tryParse(value.estimated?.toString() ?? '0') ?? 0);

    // Est percentage
    final double estPct = double.tryParse(value.estPercentage?.toString() ?? '0') ?? 0;

    // Pledge rows are selected locally until Submit Request.
    final bool isItemSelected =
        tab == '0' && value.dummvalue != null && value.dummvalue != 'null';

    // Tap handler for qty edit
    void onQtyTap() {
      _handlePledgeRowTap(value, tab, ledgerprovider, context);
    }

    // ✕ on a pledge row only removes the local selection — nothing has been
    // sent yet, so no API call.
    void onQtyDelete() async {
      final confirmed =
          await _showDeleteConfirmDialog(context, symbolName, tab);
      if (confirmed != true) return;
      ledgerprovider.removeSinglePledgeItem(isin, 'pledge', value);
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

    // Dialogs open only from the qty chips, never from the rest of the row.

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
        ),
        // Qty to pledge/unpledge — a zero qty means there is nothing to act
        // on, so the cell stays blank instead of showing a '0' chip.
        // Non-Approved carries the same chip as Available Balance, disabled:
        // the qty is already submitted, so it reads but doesn't edit.
        _buildTableDataCell(
          tab == '1'
              ? pledgedSharesCell()
              : qtyLabel.isEmpty
                  ? const SizedBox.shrink()
                  : _buildQtyWidget(
                      qtyLabel,
                      onQtyTap,
                      context,
                      isSelected: isItemSelected,
                      onDelete: onQtyDelete,
                      enabled: tab != '2',
                    ),
          context,
          alignRight: true,
        ),
        // Pledged shares — Available Balance only, for holdings that already
        // carry collateral. Blank when there is nothing pledged to release.
        if (showUnpledgeColumn)
          _buildTableDataCell(
            showUnpledgeChip
                ? pledgedSharesCell()
                : Text('--', style: textStyle),
            context,
            alignRight: true,
          ),
        // Total Qty
        _buildTableDataCell(
          Text('$totalQty', style: textStyle),
          context,
          alignRight: true,
        ),
        // Value
        _buildTableDataCell(
          Text(amountVal.toStringAsFixed(2), style: textStyle),
          context,
          alignRight: true,
        ),
        // Mrg / Est
        _buildTableDataCell(
          Text(
            '${mrgEstVal.toStringAsFixed(2)} ($mrgLabel)',
            style: greenStyle,
          ),
          context,
          alignRight: true,
        ),
        // Est %
        _buildTableDataCell(
          Text('${estPct.toInt()} %', style: textStyle),
          context,
          alignRight: true,
        ),
      ],
    );
  }

  /// Qty cells hide a zero: nothing to act on reads as a blank cell rather
  /// than a '0' competing with the real quantities in the column.
  String _qtyDisplay(String qty) {
    final parsed = double.tryParse(qty);
    return (parsed == null || parsed == 0) ? '' : qty;
  }

  /// Old unpledge chip (lock + qty), one per product: Regular first, then
  /// MTF tagged "MTF". A product with a sent request shows the selected
  /// chip with ✎ / delete; a product with nothing pledged shows nothing.
  Widget _buildPledgedSharesCell(
    Data value,
    BuildContext context, {
    required LDProvider ledgerprovider,
    required bool disabled,
    required void Function(String prd) onUnpledge,
  }) {
    final String isin = value.iSIN?.toString() ?? '';

    Widget? chipFor(String prd) {
      final int pledged = value.pledgedQtyFor(prd);
      final int pending = value.pendingQtyFor(prd);
      if (pledged == 0 && pending == 0) return null;

      final String? tag = prd == 'F' ? 'MTF' : null;
      if (pending >= 1) {
        return Opacity(
          opacity: disabled ? 0.4 : 1,
          child: _buildPendingUnpledgeChip(
            context,
            label: '$pending/$pledged',
            tag: tag,
            onEdit: () => onUnpledge(prd),
            onDelete: () {
              if (disabled) return;
              _showDeleteUnpledgeDialog(context, value, prd, ledgerprovider);
            },
          ),
        );
      }
      // Locked chips stay tappable (they explain the one-at-a-time rule);
      // disabled ones do nothing.
      final bool faded = ledgerprovider.unpledgeLocked(isin, prd);
      return Opacity(
        opacity: faded || disabled ? 0.4 : 1,
        child: _buildQtyWidget('$pledged', () => onUnpledge(prd), context,
            isUnpledge: true, tag: tag),
      );
    }

    final chips = [chipFor('C'), chipFor('F')].whereType<Widget>().toList();
    if (chips.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          chips[i],
        ],
      ],
    );
  }

  /// Sent unpledge request: one red box with "requested/pledged" plus
  /// ✎ (edit) and ✕ (delete request) inside it.
  Widget _buildPendingUnpledgeChip(
    BuildContext context, {
    required String label,
    String? tag,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final lossColor = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final textStyle = MyntWebTextStyles.tableCell(
      context,
      darkColor: MyntColors.lossDark,
      lightColor: MyntColors.loss,
      fontWeight: MyntFonts.semiBold,
    );

    Widget icon(IconData data, VoidCallback onTap, String tooltip) => Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            // Same size as the lock glyph, no vertical padding, so this
            // box is exactly as tall as the plain unpledge chip.
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(data, size: 12, color: lossColor),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: lossColor.withValues(alpha: 0.1),
        border: Border.all(color: lossColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag != null) ...[
            Text(tag, style: textStyle.copyWith(fontSize: 10)),
            const SizedBox(width: 4),
          ],
          Text(label, style: textStyle),
          const SizedBox(width: 6),
          icon(Icons.edit, onEdit, 'Edit'),
          const SizedBox(width: 2),
          icon(Icons.close, onDelete, 'Delete request'),
        ],
      ),
    );
  }

  /// ✕ on a sent unpledge request: confirms, then calls del_unpledge for
  /// that product ("C" Regular / "F" MTF).
  void _showDeleteUnpledgeDialog(BuildContext context, Data value, String prd,
      LDProvider ledgerprovider) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final dialogWidth =
            screenWidth * 0.9 > 400.0 ? 400.0 : screenWidth * 0.9;
        final labelStyle = MyntWebTextStyles.bodySmall(
          dialogContext,
          darkColor: MyntColors.textSecondaryDark,
          lightColor: MyntColors.textSecondary,
          fontWeight: MyntFonts.medium,
        );

        return Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: Container(
              width: dialogWidth,
              decoration: BoxDecoration(
                color: resolveThemeColor(dialogContext,
                    dark: MyntColors.dialogDark, light: MyntColors.dialog),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color:
                              shadcn.Theme.of(dialogContext).colorScheme.border,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Delete Unpledge request',
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
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(value.nSESYMBOL ?? '--',
                            style: MyntWebTextStyles.body(dialogContext,
                                fontWeight: MyntFonts.semiBold,
                                color: resolveThemeColor(dialogContext,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary))),
                        const SizedBox(height: 12),
                        Text('Unpledge Qty', style: labelStyle),
                        const SizedBox(height: 8),
                        Container(
                          height: 44,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: resolveThemeColor(dialogContext,
                                dark: MyntColors.inputBgDark,
                                light: MyntColors.inputBg),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${value.pendingQtyFor(prd)}',
                              style: MyntWebTextStyles.body(dialogContext,
                                  color: resolveThemeColor(dialogContext,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary))),
                        ),
                        const SizedBox(height: 24),
                        Consumer(builder: (context, ref, _) {
                          final loading =
                              ref.watch(ledgerProvider).deployLoading;
                          return MyntButton(
                            type: MyntButtonType.primary,
                            size: MyntButtonSize.large,
                            label: 'Delete this request',
                            isFullWidth: true,
                            isLoading: loading,
                            backgroundColor: resolveThemeColor(
                              dialogContext,
                              dark: MyntColors.errorDark,
                              light: MyntColors.tertiary,
                            ),
                            onPressed: loading
                                ? null
                                : () => ledgerprovider.deleteUnpledgeRequest(
                                      context,
                                      value,
                                      prd,
                                      closeDialog: () {
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                      },
                                    ),
                          );
                        }),
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

  Widget _buildQtyWidget(
    String qty,
    VoidCallback onTap,
    BuildContext context, {
    bool isSelected = false,
    VoidCallback? onDelete,
    bool isUnpledge = false,
    bool enabled = true,
    String? tag,
  }) {
    // Non-Approved keeps the chip so the column reads like Available Balance,
    // but muted and inert: the qty is awaiting approval, not editable.
    if (!enabled) {
      final mutedColor = resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: mutedColor.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          qty,
          style: MyntWebTextStyles.tableCell(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
            fontWeight: MyntFonts.medium,
          ),
        ),
      );
    }

    // Unpledge chips carry a lock glyph so the two chips on Available
    // Balance can't be mistaken for each other.
    final Widget? lockIcon = isUnpledge
        ? Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.lock_outline,
              size: 12,
              color: resolveThemeColor(context,
                  dark: MyntColors.lossDark, light: MyntColors.loss),
            ),
          )
        : null;

    // Product tag (e.g. "MTF") sits inside the chip, before the qty, in the
    // chip's own colour.
    Widget? tagText(Color dark, Color light) => tag == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              tag,
              style: MyntWebTextStyles.tableCell(
                context,
                darkColor: dark,
                lightColor: light,
                fontWeight: MyntFonts.semiBold,
              ).copyWith(fontSize: 10),
            ),
          );

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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lockIcon != null) lockIcon,
                if (tag != null)
                  tagText(MyntColors.profitDark, MyntColors.profit)!,
                Text(
                  qty,
                  style: MyntWebTextStyles.tableCell(
                    context,
                    darkColor: MyntColors.profitDark,
                    lightColor: MyntColors.profit,
                    fontWeight: MyntFonts.semiBold,
                  ),
                ),
              ],
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

    // Default unselected state — unpledge chips use the loss accent.
    final accentColor = isUnpledge
        ? resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss)
        : resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: accentColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lockIcon != null) lockIcon,
            if (tag != null)
              tagText(
                isUnpledge ? MyntColors.lossDark : MyntColors.primaryDark,
                isUnpledge ? MyntColors.loss : MyntColors.primary,
              )!,
            Text(
              qty,
              style: MyntWebTextStyles.tableCell(
                context,
                darkColor: isUnpledge
                    ? MyntColors.lossDark
                    : MyntColors.primaryDark,
                lightColor:
                    isUnpledge ? MyntColors.loss : MyntColors.primary,
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
      dynamic value, String tab, LDProvider ledgerprovider, BuildContext context,
      {String prd = 'C'}) {
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
      // Unpledge (or ✎ on a sent request): qty prefilled to the pledged qty
      // of the chosen product, which is also the limit.
      ledgerprovider.screenclickedpledge = 'unpledge';
      ledgerprovider.setUnpledgePrd(prd);
      final int maxQty = value.pledgedQtyFor(prd);
      ledgerprovider.setselectnetpledge('$maxQty', '$maxQty');
      _showPledgeDialog(context, PledgeDeytails(data: value));
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
