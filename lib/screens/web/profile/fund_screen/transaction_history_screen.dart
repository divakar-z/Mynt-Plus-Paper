import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/fund_model_testing_copy/client_history_model.dart';
import 'package:mynt_plus/models/fund_model_testing_copy/withdraw_request_model.dart';
import 'package:mynt_plus/provider/privacy_provider.dart';
import 'package:mynt_plus/provider/withdraw_provider.dart';
import 'package:mynt_plus/res/assets.dart';
import 'package:mynt_plus/sharedWidget/common_search_fields_web.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../res/responsive_extensions.dart';
import 'withdraw/withdraw_request_tile.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const TransactionHistoryScreen({super.key, this.onBack});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  /// 0 = Add Fund (pay-in history), 1 = Withdraw (`/withdraw/requests`).
  int _tab = 0;

  // Withdraw tab filters: display label -> request status groups it includes
  static const Map<String, List<WithdrawStatusGroup>> _withdrawFilterGroups = {
    'Pending': [WithdrawStatusGroup.pending],
    'Processed': [WithdrawStatusGroup.processed],
    'Cancelled': [WithdrawStatusGroup.cancelled, WithdrawStatusGroup.replaced],
    'Under review': [WithdrawStatusGroup.review],
    'Failed': [WithdrawStatusGroup.failed],
  };
  final ValueNotifier<String> _withdrawFilter = ValueNotifier<String>('All');

  bool _isLoading = true;
  List<ClientHistoryItem> _transactions = [];
  String? _error;
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);
  final ScrollController _verticalScrollController = ScrollController();
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  final TextEditingController _searchController = TextEditingController();
   final ValueNotifier<String> _selectedFilter = ValueNotifier<String>('All');
  List<String> _availableFilters = ['All'];
  final _assets = Assets();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchController.text != _searchQuery.value) {
        _searchQuery.value = _searchController.text;
      }
    });
    _fetchHistory();
  }

  @override
  void dispose() {
    _hoveredRowIndex.dispose();
    _verticalScrollController.dispose();
    _searchQuery.dispose();
    _searchController.dispose();
    _selectedFilter.dispose();
    _withdrawFilter.dispose();
    super.dispose();
  }

  /// On a tab switch the search is cleared (a query typed for one list would
  /// only empty the other), and withdrawals load the first time their tab
  /// is shown.
  void _selectTab(int index) {
    if (index == _tab) return;
    _searchController.clear();
    setState(() => _tab = index);
    if (index == 1) {
      final wp = ref.read(withdrawProvider);
      wp.attachContext(context);
      if (!wp.requestsLoaded && !wp.requestsLoading) {
        wp.fetchRequests();
      }
    }
  }

  /// True when [query] is a number found in [amount], however either is
  /// written: "1500", "1,500", "₹1500.5" and "1500.50" all match 1500.50.
  static bool _amountMatches(String query, double? amount) {
    if (amount == null || !amount.isFinite) return false;
    final q = query.replaceAll(RegExp(r'[₹,\s]'), '');
    if (q.isEmpty || !RegExp(r'^\d*\.?\d*$').hasMatch(q) || q == '.') {
      return false;
    }
    final fixed = amount.toStringAsFixed(2); // 1500.50
    final plain = fixed.endsWith('.00')
        ? fixed.substring(0, fixed.length - 3) // 1500
        : fixed.endsWith('0')
            ? fixed.substring(0, fixed.length - 1) // 1500.5
            : fixed;
    return fixed.contains(q) || plain.contains(q);
  }

  List<WithdrawRequest> _getFilteredWithdrawals(List<WithdrawRequest> rows) {
    final query = _searchQuery.value.toLowerCase().trim();
    final allowed =
        _withdrawFilterGroups[_withdrawFilter.value]?.toSet() ?? const {};
    return rows.where((r) {
      if (allowed.isNotEmpty && !allowed.contains(r.group)) return false;
      if (query.isEmpty) return true;
      if (_amountMatches(query, r.amount)) return true;
      final fields = [
        WithdrawRequestTile.formatDate(r.createdAt),
        r.createdAt ?? '',
        r.statusLabel,
        r.companyCode ?? '',
        r.remarks ?? '',
        '${r.id ?? ''}',
      ];
      return fields.any((f) => f.toLowerCase().contains(query));
    }).toList();
  }

  List<ClientHistoryItem> _getFilteredTransactions() {
    final query = _searchQuery.value.toLowerCase().trim();
    final filter = _selectedFilter.value;
    return _transactions.where((item) {
      // Status filter
      if (filter != 'All') {
        final status = (item.status ?? '').toUpperCase();
        if (status != filter.toUpperCase()) return false;
      }
      // Search filter
      if (query.isNotEmpty) {
        final date = _formatDate(item.dateTime).toLowerCase();
        final order = (item.orderNumber ?? '').toLowerCase();
        final type = (item.transtype ?? '').toLowerCase();
        final amount = (item.amount ?? '').toLowerCase();
        return date.contains(query) ||
            order.contains(query) ||
            type.contains(query) ||
            amount.contains(query) ||
            _amountMatches(
                query, double.tryParse((item.amount ?? '').replaceAll(',', '')));
      }
      return true;
    }).toList();
  }

  Future<void> _fetchHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final api = locator<ApiExporter>();
      final response = await api.getClientHistory();
      if (mounted) {
        final data = response.data ?? [];
        final statuses = data
            .map((e) => e.status?.toUpperCase())
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();
        setState(() {
          _transactions = data;
          _availableFilters = ['All', ...statuses];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load transactions";
          _isLoading = false;
        });
      }
    }
  }

  // Text styles matching holdings table
  TextStyle _cellStyle({Color? color}) {
    return MyntWebTextStyles.tableCell(
      context,
      color: color,
      darkColor: color ?? MyntColors.textPrimaryDark,
      lightColor: color ?? MyntColors.textPrimary,
      fontWeight: MyntFonts.medium,
    );
  }

  TextStyle _headerStyle() {
    return MyntWebTextStyles.tableHeader(
      context,
      darkColor: MyntColors.textSecondaryDark,
      lightColor: MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watched here so the auto-disposed provider lives as long as the screen.
    final withdraw = ref.watch(withdrawProvider);
    ref.watch(privacyProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Scaffold(
        backgroundColor: resolveThemeColor(
          context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor,
        ),
        appBar: AppBar(
          centerTitle: false,
          leadingWidth: 48,
          titleSpacing: 6,
          backgroundColor: resolveThemeColor(
            context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor,
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: MyntColors.transparent,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_outlined,
              size: 18,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
            ),
            onPressed: widget.onBack ?? () => Navigator.pop(context),
          ),
          title: Text(
            'Transaction History',
            style: MyntWebTextStyles.title(
              context,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary,
              ),
              fontWeight: MyntFonts.semiBold,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: context.responsiveValue<double>(
                  mobile: 140,
                  smallTablet: 180,
                  tablet: 220,
                  desktop: 300,
                  largeDesktop: 350,
                  widescreen: 400,
                ),
                child: MyntSearchTextField.withSmartClear(
                  controller: _searchController,
                  placeholder:
                      _tab == 0 ? 'Search transactions' : 'Search withdrawals',
                  leadingIcon: _assets.searchIcon,
                  onClear: () => _searchController.clear(),
                ),
              ),
            ),  
            _buildFilterButton(),
            const SizedBox(width: 15)
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTabs(),
            Expanded(
              child: _tab == 0
                  ? _buildAddFundTab()
                  : _buildWithdrawTab(withdraw),
            ),
          ],
        ),
      ),
    );
  }

  /// Pill tabs: Add Fund / Withdraw.
  Widget _buildTabs() {
    Widget tab(String label, int index) {
      final selected = _tab == index;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _selectTab(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? resolveThemeColor(context,
                      dark: MyntColors.listItemBgDark,
                      light: MyntColors.listItemBg)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              label,
              style: MyntWebTextStyles.body(
                context,
                fontWeight: selected ? MyntFonts.semiBold : MyntFonts.medium,
                color: selected
                    ? resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary)
                    : resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          tab('Add Fund', 0),
          const SizedBox(width: 8),
          tab('Withdraw', 1),
        ],
      ),
    );
  }

  /// Add Fund tab: the pay-in history with search and status filter.
  Widget _buildAddFundTab() {
    return _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: resolveThemeColor(context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary),
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: MyntWebTextStyles.body(context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.errorDark,
                                    light: MyntColors.error))),
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: _fetchHistory,
                            child: const Text("Retry")),
                      ],
                    ),
                  )
                : _transactions.isEmpty
                    ? Center(
                        child: Text(
                          "No transactions found",
                          style: MyntWebTextStyles.body(
                            context,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ),
                      )
                    : LayoutBuilder(builder: (context, constraints) {
                        return _buildTable(constraints);
                      });
  }

  Widget _centerText(String text, {Color? color}) => Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.body(
            context,
            color: color ??
                resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
          ),
        ),
      );

  /// Withdraw tab: every request `/withdraw/requests` returns, newest first.
  Widget _buildWithdrawTab(WithdrawProvider wp) {
    if (!wp.requestsLoaded && wp.requestsError == null) {
      return Center(
        child: CircularProgressIndicator(
          color: resolveThemeColor(context,
              dark: MyntColors.primaryDark, light: MyntColors.primary),
        ),
      );
    }
    if (wp.requestsError != null && wp.requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Unable to load withdrawals',
                style: MyntWebTextStyles.body(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.errorDark,
                        light: MyntColors.error))),
            const SizedBox(height: 4),
            Text(wp.requestsError!,
                style: MyntWebTextStyles.bodySmall(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary))),
            const SizedBox(height: 12),
            TextButton(
                onPressed: wp.requestsLoading ? null : wp.fetchRequests,
                child: const Text("Retry")),
          ],
        ),
      );
    }
    if (wp.requests.isEmpty) {
      return _centerText('No withdrawals found');
    }
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildWithdrawTable(wp.requests, constraints),
    );
  }

  Widget _buildWithdrawTable(
      List<WithdrawRequest> requests, BoxConstraints constraints) {
    final totalWidth = constraints.maxWidth;
    final privacy = ref.read(privacyProvider);

    // Column: Date 20%, Request ID 12%, Segment 13%, Amount 15%, Status 15%, Remarks 25%
    final columnWidths = <int, shadcn.TableSize>{
      0: shadcn.FixedTableSize(totalWidth * 0.20),
      1: shadcn.FixedTableSize(totalWidth * 0.12),
      2: shadcn.FixedTableSize(totalWidth * 0.13),
      3: shadcn.FixedTableSize(totalWidth * 0.15),
      4: shadcn.FixedTableSize(totalWidth * 0.15),
      5: shadcn.FixedTableSize(totalWidth * 0.25),
    };
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          shadcn.Table(
            columnWidths: columnWidths,
            defaultRowHeight: const shadcn.FixedTableSize(44),
            rows: [
              shadcn.TableHeader(
                cells: [
                  _buildHeaderCell('Date & Time', isFirst: true),
                  _buildHeaderCell('Request ID'),
                  _buildHeaderCell('Segment'),
                  _buildHeaderCell('Amount', alignRight: true),
                  _buildHeaderCell('Status'),
                  _buildHeaderCell('Remarks', isLast: true),
                ],
              ),
            ],
          ),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _withdrawFilter,
              builder: (context, filter, _) {
                return ValueListenableBuilder<String>(
                  valueListenable: _searchQuery,
                  builder: (context, query, _) {
                    final rows = _getFilteredWithdrawals(requests);
                    if (rows.isEmpty) {
                      return _centerText('No matching withdrawals');
                    }
                    return RawScrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      trackColor: resolveThemeColor(context,
                          dark: MyntColors.scrollbarTrackDark,
                          light: MyntColors.scrollbarTrack),
                      thumbColor: resolveThemeColor(context,
                          dark: MyntColors.scrollbarThumbDark,
                          light: MyntColors.scrollbarThumbLight),
                      thickness: 6,
                      radius: const Radius.circular(3),
                      interactive: true,
                      child: ListView.builder(
                        controller: _verticalScrollController,
                        itemCount: rows.length,
                        itemExtent: 50.0,
                        itemBuilder: (context, index) {
                          final r = rows[index];
                          final remarks = (r.remarks ?? '').trim();
                          return shadcn.Table(
                            columnWidths: columnWidths,
                            defaultRowHeight: const shadcn.FixedTableSize(50),
                            rows: [
                              shadcn.TableRow(
                                cells: [
                                  _buildCellWithHover(
                                    rowIndex: index,
                                    columnIndex: 0,
                                    isFirst: true,
                                    child: Text(
                                        WithdrawRequestTile.formatDate(
                                            r.createdAt),
                                        style: _cellStyle(),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  _buildCellWithHover(
                                    rowIndex: index,
                                    columnIndex: 1,
                                    child: Text('${r.id ?? '-'}',
                                        style: _cellStyle(color: secondary),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  _buildCellWithHover(
                                    rowIndex: index,
                                    columnIndex: 2,
                                    child: Text(
                                        (r.companyCode ?? '').isEmpty
                                            ? '-'
                                            : r.companyCode!,
                                        style: _cellStyle(),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  _buildCellWithHover(
                                    rowIndex: index,
                                    columnIndex: 3,
                                    alignRight: true,
                                    child: Text(
                                        privacy.mask(
                                            getFormatter(
                                                value: r.amount,
                                                v4d: false,
                                                noDecimal: false),
                                            prefix: '₹'),
                                        style: _cellStyle().copyWith(
                                            fontWeight: MyntFonts.semiBold),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  _buildCellWithHover(
                                    rowIndex: index,
                                    columnIndex: 4,
                                    child: WithdrawRequestTile.statusChip(
                                        context, r),
                                  ),
                                  _buildCellWithHover(
                                    rowIndex: index,
                                    columnIndex: 5,
                                    isLast: true,
                                    child: remarks.isEmpty
                                        ? Text('-',
                                            style:
                                                _cellStyle(color: secondary))
                                        : Tooltip(
                                            message: remarks,
                                            child: Text(remarks,
                                                style: _cellStyle(
                                                    color: secondary),
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BoxConstraints constraints) {
    final totalWidth = constraints.maxWidth;

    // Column: Icon 5%, Date 18%, OrderNo 22%, Type 13%, Gateway 10%, Amount 16%, Status 16%
    final iconW    = totalWidth * 0.05;
    final dateW    = totalWidth * 0.18;
    final orderW   = totalWidth * 0.22;
    final typeW    = totalWidth * 0.13;
    final gatewayW = totalWidth * 0.10;
    final amountW  = totalWidth * 0.16;
    final statusW  = totalWidth * 0.16;

    final columnWidths = <int, shadcn.TableSize>{
      0: shadcn.FixedTableSize(iconW),
      1: shadcn.FixedTableSize(dateW),
      2: shadcn.FixedTableSize(orderW),
      3: shadcn.FixedTableSize(typeW),
      4: shadcn.FixedTableSize(gatewayW),
      5: shadcn.FixedTableSize(amountW),
      6: shadcn.FixedTableSize(statusW),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Fixed header
          shadcn.Table(
            columnWidths: columnWidths,
            defaultRowHeight: const shadcn.FixedTableSize(44),
            rows: [
              shadcn.TableHeader(
                cells: [
                  _buildHeaderCell('', isFirst: true),
                  _buildHeaderCell('Date & Time'),
                  _buildHeaderCell('Order No'),
                  _buildHeaderCell('Type'),
                  _buildHeaderCell('Gateway'),
                  _buildHeaderCell('Amount', alignRight: true),
                  _buildHeaderCell('Status', isLast: true),
                ],
              ),
            ],
          ),
        // Scrollable body
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: _selectedFilter,
            builder: (context, filter, _) {
              return ValueListenableBuilder<String>(
                valueListenable: _searchQuery,
                builder: (context, query, _) {
              final filtered = _getFilteredTransactions();
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'No matching transactions',
                    style: MyntWebTextStyles.body(
                      context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary),
                    ),
                  ),
                );
              }
              return RawScrollbar(
            controller: _verticalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            trackColor: resolveThemeColor(context,
                dark: MyntColors.scrollbarTrackDark,
                light: MyntColors.scrollbarTrack),
            thumbColor: resolveThemeColor(context,
                dark: MyntColors.scrollbarThumbDark,
                light: MyntColors.scrollbarThumbLight),
            thickness: 6,
            radius: const Radius.circular(3),
            interactive: true,
            child: ListView.builder(
              controller: _verticalScrollController,
              itemCount: filtered.length,
              itemExtent: 50.0,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return shadcn.Table(
                  columnWidths: columnWidths,
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  rows: [
                    shadcn.TableRow(
                      cells: [
                        _buildCellWithHover(
                          rowIndex: index,
                          columnIndex: 0,
                          isFirst: true,
                          child: _buildBankLogo(
                              _extractBankCode(item.bankifsc)),
                        ),
                        _buildCellWithHover(
                          rowIndex: index,
                          columnIndex: 1,
                          child: Text(_formatDate(item.dateTime),
                              style: _cellStyle(),
                              overflow: TextOverflow.ellipsis),
                        ),
                        _buildCellWithHover(
                          rowIndex: index,
                          columnIndex: 2,
                          child: Text(item.orderNumber ?? "-",
                              style: _cellStyle(
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                              ),
                              overflow: TextOverflow.ellipsis),
                        ),
                        _buildCellWithHover(
                          rowIndex: index,
                          columnIndex: 3,
                          child: Text(item.transtype ?? "-",
                              style: _cellStyle(),
                              overflow: TextOverflow.ellipsis),
                        ),
                        _buildCellWithHover(
                          rowIndex: index,
                          columnIndex: 4,
                          child: Text(item.vendor ?? "-",
                              style: _cellStyle(
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                              ),
                              overflow: TextOverflow.ellipsis),
                        ),
                        _buildCellWithHover(
                          rowIndex: index,
                          columnIndex: 5,
                          alignRight: true,
                          child: Text("₹${item.amount ?? "0.00"}",
                              style: _cellStyle().copyWith(
                                  fontWeight: MyntFonts.semiBold),
                              overflow: TextOverflow.ellipsis),
                        ),
                        _buildCellWithHover(
                          rowIndex: index,
                          columnIndex: 6,
                          isLast: true,
                          child: _buildStatusChip(item),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
              );
                },
              );
            },
          ),
        ),
      ],
      ),
    );
  }

  // Filter button matching positions page
  Widget _buildFilterButton() {
    final buttonSize = context.responsiveValue<double>(
      mobile: 32,
      smallTablet: 34,
      tablet: 36,
      desktop: 40,
      largeDesktop: 40,
      widescreen: 40,
    );
    final iconSize = context.responsiveValue<double>(
      mobile: 16,
      smallTablet: 17,
      tablet: 18,
      desktop: 20,
      largeDesktop: 20,
      widescreen: 20,
    );

    return Builder(
      builder: (buttonContext) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _showFilterPopup(buttonContext),
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SvgPicture.asset(
                  _assets.searchFilter,
                  width: iconSize,
                  colorFilter: ColorFilter.mode(
                    resolveThemeColor(
                      context,
                      dark: MyntColors.iconSecondaryDark,
                      light: MyntColors.iconSecondary,
                    ),
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

  void _showFilterPopup(BuildContext context) {
    shadcn.showPopover(
      context: context,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 8),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(context).borderRadiusLg,
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
              width: 160,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: (_tab == 0
                        ? _availableFilters
                        : ['All', ..._withdrawFilterGroups.keys])
                    .map((filter) => _buildFilterMenuItem(filter))
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterMenuItem(String value) {
    final notifier = _tab == 0 ? _selectedFilter : _withdrawFilter;
    return ValueListenableBuilder<String>(
      valueListenable: notifier,
      builder: (context, currentFilter, child) {
        final isSelected = currentFilter == value;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              notifier.value = value;
              shadcn.closeOverlay(context);
            },
            splashColor: resolveThemeColor(
              context,
              dark: MyntColors.rippleDark,
              light: MyntColors.rippleLight,
            ),
            highlightColor: resolveThemeColor(
              context,
              dark: MyntColors.highlightDark,
              light: MyntColors.highlightLight,
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isSelected
                    ? resolveThemeColor(
                        context,
                        dark: MyntColors.primaryDark.withValues(alpha: 0.12),
                        light: const Color(0xFFE8F0FE),
                      )
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: isSelected
                            ? MyntFonts.semiBold
                            : MyntFonts.medium,
                        color: isSelected
                            ? resolveThemeColor(
                                context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary,
                              )
                            : resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  shadcn.TableCell _buildHeaderCell(String label,
      {bool alignRight = false, bool isFirst = false, bool isLast = false}) {
    EdgeInsets padding;
    if (isFirst) {
      padding = const EdgeInsets.fromLTRB(16, 6, 4, 6);
    } else if (isLast) {
      padding = const EdgeInsets.fromLTRB(4, 6, 16, 6);
    } else {
      padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
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
      child: Container(
        padding: padding,
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(label, style: _headerStyle()),
      ),
    );
  }

  shadcn.TableCell _buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    bool isFirst = false,
    bool isLast = false,
  }) {
    EdgeInsets cellPadding;
    if (isFirst) {
      cellPadding = const EdgeInsets.fromLTRB(16, 8, 4, 8);
    } else if (isLast) {
      cellPadding = const EdgeInsets.fromLTRB(4, 8, 16, 8);
    } else {
      cellPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
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
      child: MouseRegion(
        onEnter: (_) => _hoveredRowIndex.value = rowIndex,
        onExit: (_) => _hoveredRowIndex.value = null,
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredRowIndex,
          child: child,
          builder: (context, hoveredIndex, cachedChild) {
            final isRowHovered = hoveredIndex == rowIndex;
            return Container(
              padding: cellPadding,
              alignment:
                  alignRight ? Alignment.centerRight : Alignment.centerLeft,
              color: isRowHovered
                  ? resolveThemeColor(
                      context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary,
                    ).withValues(alpha: 0.06)
                  : Colors.transparent,
              child: cachedChild,
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusChip(ClientHistoryItem item) {
    final statusColor = _getStatusColor(item.status);
    final reason = item.statusDescription ?? item.status ?? "-";
    return Tooltip(
      message: reason,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          (item.status ?? "-").toUpperCase(),
          style: MyntWebTextStyles.bodySmall(
            context,
            color: statusColor,
            fontWeight: MyntFonts.medium,
          ),
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }

  Widget _buildBankLogo(String? bankCode) {
    if (bankCode == null) {
      return Icon(
        Icons.account_balance_rounded,
        size: 18,
        color: resolveThemeColor(context,
            dark: MyntColors.iconSecondaryDark,
            light: MyntColors.iconSecondary),
      );
    }

    final logoUrl =
        "https://ekycbe.mynt.in/zebu/banklogo?bank=$bankCode&type=svg";
    return SvgPicture.network(
      logoUrl,
      width: 24,
      height: 24,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => Icon(
        Icons.account_balance_rounded,
        size: 18,
        color: resolveThemeColor(context,
            dark: MyntColors.iconSecondaryDark,
            light: MyntColors.iconSecondary),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'SUCCESS':
        return resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
      case 'FAILURE':
      case 'FAILED':
      case 'REJECTED':
      case 'EXPIRED':
        return resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);
      case 'INITIATED':
      case 'PENDING':
        return resolveThemeColor(context,
            dark: MyntColors.warning, light: MyntColors.warning);
      default:
        return resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary);
    }
  }

  String _formatDate(String? dateTime) {
    if (dateTime == null) return "-";
    try {
      final parsed =
          DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'").parse(dateTime);
      return DateFormat("dd MMM yyyy, hh:mm a").format(parsed);
    } catch (_) {
      return dateTime;
    }
  }

  String? _extractBankCode(String? ifsc) {
    if (ifsc == null || ifsc == "NA" || ifsc == "None" || ifsc.length < 4) {
      return null;
    }
    return ifsc.substring(0, 4);
  }
}
