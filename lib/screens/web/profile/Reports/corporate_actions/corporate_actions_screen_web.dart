// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;

import 'package:flutter_svg/svg.dart';
import '../../../../../models/desk_reports_model/cp_action_model.dart';
import '../../../../../provider/fund_provider.dart';
import '../../../../../provider/ledger_provider.dart';
import '../../../../../provider/thems.dart';
import '../../../../../res/res.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../sharedWidget/custom_back_btn.dart';
import '../../../../../sharedWidget/mynt_loader.dart';
import '../../../../../sharedWidget/no_data_found_web.dart';
import '../../../../../sharedWidget/snack_bar.dart';
import 'ca_buyback_order_dialog_web.dart';

/// Web screen for Corporate Actions: Buyback / Delisting / Takeover / OFS.
///
/// Mirrors the Positions table pattern: shadcn Table inside an OutlinedContainer,
/// with sticky header and scrollable body. Uses the existing [ledgerProvider]
/// (selectvalueofcpaction filter, filteredCPActionData, fetchcpactiondata,
/// putordercopaction).
class CorporateActionsScreenWeb extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const CorporateActionsScreenWeb({super.key, this.onBack});

  @override
  ConsumerState<CorporateActionsScreenWeb> createState() =>
      _CorporateActionsScreenWebState();
}

class _CorporateActionsScreenWebState
    extends ConsumerState<CorporateActionsScreenWeb> {
  late final ScrollController _verticalScrollController;
  late final ScrollController _horizontalScrollController;

  // Sorting state
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Action-type filter (UI-only: "All" / "BUYBACK" / "TAKEOVER" / "DELISTING")
  String _actionTypeFilter = 'All';

  static const List<String> _headers = [
    'Company',
    'Exchange',
    'Closes On',
    'Type',
    'Action',
  ];

  @override
  void initState() {
    super.initState();
    _verticalScrollController = ScrollController();
    _horizontalScrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lp = ref.read(ledgerProvider);
      if (lp.cpactiondata == null && !lp.cpactionloader) {
        lp.fetchcpactiondata(context);
      }
    });
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Type / styling helpers
  // ---------------------------------------------------------------------------

  String _typeLabel(String? issueType) {
    switch (issueType) {
      case 'BB':
      case 'BUYBACK':
        return 'BUYBACK';
      case 'DLST':
      case 'DS':
        return 'DELISTING';
      case 'TAKEOVER':
      case 'TO':
        return 'TAKEOVER';
      case 'IS':
      case 'RS':
        return 'OFS';
      default:
        return issueType ?? '-';
    }
  }

  Color _typeColor(BuildContext context, String? issueType) {
    final label = _typeLabel(issueType);
    switch (label) {
      case 'BUYBACK':
        return resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);
      case 'DELISTING':
        return resolveThemeColor(context,
            dark: MyntColors.warningDark, light: MyntColors.warning);
      case 'TAKEOVER':
        return resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
      case 'OFS':
        return resolveThemeColor(context,
            dark: MyntColors.secondaryDark, light: MyntColors.secondary);
      default:
        return resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary);
    }
  }

  String _displayExchange(String? exchange) {
    if (exchange == null || exchange.isEmpty) return '-';
    return exchange == 'NSETender' ? 'NSE' : exchange;
  }

  // ---------------------------------------------------------------------------
  // Filter / sort
  // ---------------------------------------------------------------------------

  List<CorporateAction> _applyFilters(List<dynamic> raw) {
    final list = raw.cast<CorporateAction>().toList();

    final filtered = _actionTypeFilter == 'All'
        ? list
        : list
            .where((c) => _typeLabel(c.issueType) == _actionTypeFilter)
            .toList();

    if (_sortColumnIndex != null) {
      filtered.sort((a, b) {
        int cmp = 0;
        switch (_sortColumnIndex) {
          case 0:
            cmp = (a.name ?? '').compareTo(b.name ?? '');
            break;
          case 1:
            cmp = _displayExchange(a.exchange)
                .compareTo(_displayExchange(b.exchange));
            break;
          case 2:
            cmp = (a.biddingEndDate ?? '').compareTo(b.biddingEndDate ?? '');
            break;
          case 3:
            cmp = _typeLabel(a.issueType).compareTo(_typeLabel(b.issueType));
            break;
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    return filtered;
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Cell builders
  // ---------------------------------------------------------------------------

  TextStyle _bodyStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableCell(
      context,
      color: color,
      darkColor: color ?? MyntColors.textPrimaryDark,
      lightColor: color ?? MyntColors.textPrimary,
      fontWeight: MyntFonts.medium,
    );
  }

  TextStyle _headerStyle(BuildContext context) {
    return MyntWebTextStyles.tableHeader(
      context,
      darkColor: MyntColors.textSecondaryDark,
      lightColor: MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  shadcn.TableCell _headerCell(
      BuildContext context, String label, int columnIndex,
      {bool sortable = true}) {
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
      child: InkWell(
        onTap: sortable ? () => _onSort(columnIndex) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: _headerStyle(context)),
              if (sortable && _sortColumnIndex == columnIndex) ...[
                const SizedBox(width: 4),
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  shadcn.TableCell _bodyCell(BuildContext context, Widget child) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _typeBadge(BuildContext context, String? issueType) {
    final label = _typeLabel(issueType);
    final color = _typeColor(context, issueType);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label.toUpperCase(),
          style: MyntWebTextStyles.para(
            context,
            color: color,
            fontWeight: MyntFonts.medium,
          ),
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }

  Widget _orderActionCell(
      BuildContext context, CorporateAction item, LDProvider lp) {
    final isPending = item.orderstatus == 'pending';

    final actionColor = isPending
        ? resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss)
        : resolveThemeColor(context,
            dark: MyntColors.secondaryDark, light: MyntColors.secondary);

    final hasBidQty = item.bidqty != null &&
        item.bidqty != 'null' &&
        item.bidqty!.isNotEmpty;

    final button = shadcn.GhostButton(
      density: shadcn.ButtonDensity.compact,
      onPressed: () => _handleActionTap(context, item, lp, isPending),
      child: Text(
        isPending ? 'Cancel' : 'Order',
        style: MyntWebTextStyles.body(
          context,
          color: actionColor,
          fontWeight: MyntFonts.semiBold,
        ),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: hasBidQty
          ? Tooltip(
              message: '${item.bidqty} qty bid',
              child: button,
            )
          : button,
    );
  }

  Future<void> _handleActionTap(BuildContext context, CorporateAction item,
      LDProvider lp, bool isPending) async {
    final isOFS = _typeLabel(item.issueType) == 'OFS';

   
    // Mobile parity: pending → cancel dialog directly.
    // For new orders: only OFS or eligible CA users can place an order.
    if (!isPending && !isOFS && item.eligibleornot != 'yes') {
      warningMessage(context, 'Not Eligible');
      return;
    }

    // Reset / seed provider state before opening the dialog,
    // matching the mobile flow.
    if (isOFS) {
      final fund = ref.read(fundProvider);
      lp.setordervalueforofs(
        '1',
        item.baseprice ?? '0',
        fund.fundDetailModel?.cash ?? '0',
      );
    } else {
      lp.setCPActionQty('', '', '', '');
      lp.setCPActionPrice('', 0, 0, '', '');
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => CABuybackOrderDialogWeb(
        action: item,
        isCancel: isPending,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(ledgerProvider);
    final theme = ref.watch(themeProvider);
    final selectedTab = lp.selectvalueofcpaction; // "CA" or "OFS"

    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitleBar(context),
          _buildToolbar(context, theme, selectedTab, lp),
          Expanded(
            child: lp.cpactionloader
                ? Center(child: MyntLoader.simple())
                : _buildTable(context, lp),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: BoxDecoration(
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            CustomBackBtn(onBack: widget.onBack),
            const SizedBox(width: 4),
          ],
          Text(
            'Corporate Action',
            style: MyntWebTextStyles.title(
              context,
              fontWeight: MyntFonts.semiBold,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, ThemesProvider theme,
      String selectedTab, LDProvider lp) {
    final all = lp.cpactiondata?.corporateAction ?? const [];
    final caCount = all.where((c) {
      final t = c.issueType;
      return t == 'BB' ||
          t == 'BUYBACK' ||
          t == 'DLST' ||
          t == 'DS' ||
          t == 'TAKEOVER' ||
          t == 'TO';
    }).length;
    final ofsCount =
        all.where((c) => c.issueType == 'IS' || c.issueType == 'RS').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Pill-style tabs (matches Holdings page: label + small superscript count)
          _pillTab(
            context,
            theme,
            label: 'CA',
            count: caCount,
            selected: selectedTab == 'CA',
            onTap: () {
              if (lp.selectvalueofcpaction != 'CA') {
                lp.setselectvalueofcpaction = 'CA';
                setState(() => _actionTypeFilter = 'All');
              }
            },
          ),
          const SizedBox(width: 8),
          _pillTab(
            context,
            theme,
            label: 'OFS',
            count: ofsCount,
            selected: selectedTab == 'OFS',
            onTap: () {
              if (lp.selectvalueofcpaction != 'OFS') {
                lp.setselectvalueofcpaction = 'OFS';
                setState(() => _actionTypeFilter = 'All');
              }
            },
          ),
          const Spacer(),
          // Filter icon (only on CA — OFS has no sub-types)
          if (selectedTab == 'CA') _filterIconButton(context, theme),
          const SizedBox(width: 4),
          // Refresh
          _iconBtn(
            context,
            tooltip: 'Refresh',
            icon: Icons.refresh,
            onTap: () => lp.fetchcpactiondata(context),
          ),
        ],
      ),
    );
  }

  Widget _pillTab(
    BuildContext context,
    ThemesProvider theme, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int count = 0,
  }) {
    final fg = resolveThemeColor(
      context,
      dark: selected
          ? MyntColors.textPrimaryDark
          : MyntColors.textSecondaryDark,
      light: selected ? MyntColors.textPrimary : MyntColors.textSecondary,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? (theme.isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight:
                      selected ? MyntFonts.semiBold : MyntFonts.medium,
                  color: fg,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Text(
                    '$count',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      fontWeight:
                          selected ? MyntFonts.semiBold : MyntFonts.medium,
                      color: fg,
                    ).copyWith(fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final color = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }

  Widget _filterIconButton(BuildContext context, ThemesProvider theme) {
    final iconColor = resolveThemeColor(context,
        dark: MyntColors.iconDark, light: MyntColors.icon);
    final activeColor = resolveThemeColor(context,
        dark: MyntColors.secondaryDark, light: MyntColors.secondary);
    final isActive = _actionTypeFilter != 'All';

    return Builder(
      builder: (btnCtx) {
        return Tooltip(
          message: 'Filter by type',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showTypeFilterPopup(btnCtx),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isActive
                      ? activeColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                ),
                child: SvgPicture.asset(
                  assets.searchFilter,
                  width: 18,
                  colorFilter: ColorFilter.mode(
                    isActive ? activeColor : iconColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTypeFilterPopup(BuildContext btnContext) {
    const options = ['All', 'BUYBACK', 'TAKEOVER', 'DELISTING'];
    shadcn.showPopover(
      context: btnContext,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 8),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(btnContext).borderRadiusLg,
      ),
      builder: (popCtx) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(popCtx).borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: shadcn.ModalContainer(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 180,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final opt in options) _filterMenuItem(popCtx, opt),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filterMenuItem(BuildContext popCtx, String value) {
    final isSelected = _actionTypeFilter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _actionTypeFilter = value);
          shadcn.closeOverlay(popCtx);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isSelected
                ? resolveThemeColor(
                    popCtx,
                    dark: MyntColors.primaryDark.withValues(alpha: 0.12),
                    light: const Color(0xFFE8F0FE),
                  )
                : Colors.transparent,
          ),
          child: Text(
            value,
            style: MyntWebTextStyles.body(
              popCtx,
              fontWeight:
                  isSelected ? MyntFonts.semiBold : MyntFonts.medium,
              color: isSelected
                  ? resolveThemeColor(popCtx,
                      dark: MyntColors.primaryDark, light: MyntColors.primary)
                  : resolveThemeColor(popCtx,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, LDProvider lp) {
    final filtered = _applyFilters(lp.filteredCPActionData);

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: NoDataFoundWeb(
          title: 'No Corporate Actions',
          subtitle: lp.selectvalueofcpaction == 'OFS'
              ? "There are no OFS issues open right now."
              : "There are no corporate actions open right now.",
          primaryEnabled: false,
          secondaryEnabled: false,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: shadcn.OutlinedContainer(
        child: LayoutBuilder(builder: (context, constraints) {
          // Min widths per column (must fit header + typical content).
          const double companyMin = 220;
          const double companyPreferred = 340;
          const double exchMin = 100;
          const double dateMin = 120;
          const double typeMin = 120;
          const double actionMin = 140;

          final totalMin =
              companyMin + exchMin + dateMin + typeMin + actionMin;
          final extra =
              (constraints.maxWidth - totalMin).clamp(0.0, double.infinity);

          // Give Company a moderate share up to its preferred width,
          // then distribute the remainder equally across the other columns.
          final companyExtra =
              extra.clamp(0.0, companyPreferred - companyMin);
          final perOther = ((extra - companyExtra) / 4)
              .clamp(0.0, double.infinity);

          final companyW = companyMin + companyExtra;
          final exchW = exchMin + perOther;
          final dateW = dateMin + perOther;
          final typeW = typeMin + perOther;
          final actionW = actionMin + perOther;

          final columnWidths = <int, shadcn.TableSize>{
            0: shadcn.FixedTableSize(companyW),
            1: shadcn.FixedTableSize(exchW),
            2: shadcn.FixedTableSize(dateW),
            3: shadcn.FixedTableSize(typeW),
            4: shadcn.FixedTableSize(actionW),
          };

          return Column(
            children: [
              shadcn.Table(
                columnWidths: columnWidths,
                defaultRowHeight: const shadcn.FixedTableSize(44),
                rows: [
                  shadcn.TableHeader(
                    cells: [
                      _headerCell(context, _headers[0], 0),
                      _headerCell(context, _headers[1], 1),
                      _headerCell(context, _headers[2], 2),
                      _headerCell(context, _headers[3], 3),
                      _headerCell(context, _headers[4], 4, sortable: false),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: RawScrollbar(
                  controller: _verticalScrollController,
                  thumbVisibility: true,
                  thickness: 6,
                  radius: const Radius.circular(3),
                  child: ListView.builder(
                    controller: _verticalScrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildRow(context, lp, item, columnWidths);
                    },
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    LDProvider lp,
    CorporateAction item,
    Map<int, shadcn.TableSize> columnWidths,
  ) {
    return shadcn.Table(
        columnWidths: columnWidths,
        defaultRowHeight: const shadcn.FixedTableSize(56),
        rows: [
          shadcn.TableRow(
            cells: [
              _bodyCell(
                context,
                Tooltip(
                  message: item.name ?? '',
                  child: Text(
                    item.name ?? '-',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(context),
                  ),
                ),
              ),
              _bodyCell(
                context,
                Text(
                  _displayExchange(item.exchange),
                  style: _bodyStyle(context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary)),
                ),
              ),
              _bodyCell(
                context,
                Text(
                  item.biddingEndDate?.isNotEmpty == true
                      ? item.biddingEndDate!
                      : '-',
                  style: _bodyStyle(context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary)),
                ),
              ),
              _bodyCell(context, _typeBadge(context, item.issueType)),
              _bodyCell(context, _orderActionCell(context, item, lp)),
            ],
          ),
        ],
      );
  }
}
