// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;

import '../../../../locator/locator.dart';
import '../../../../locator/preference.dart';
import '../../../../models/desk_reports_model/tradebook_model.dart';
import '../../../../provider/ledger_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/custom_back_btn.dart';
import '../../../../sharedWidget/common_search_fields_web.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../sharedWidget/scroll_to_load_mixin.dart';
import '../../../../sharedWidget/snack_bar.dart';
import 'tradebook_download_helper.dart';

class TradebookScreenWeb extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const TradebookScreenWeb({super.key, this.onBack});

  @override
  ConsumerState<TradebookScreenWeb> createState() =>
      _TradebookScreenWebState();
}

class _TradebookScreenWebState extends ConsumerState<TradebookScreenWeb>
    with ScrollToLoadMixin {
  late ScrollController _horizontalScrollController;
  late ScrollController _tableScrollController;

  @override
  ScrollController get tableScrollController => _tableScrollController;

  // Sorting state
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Date range
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  // Filter state
  String _exchangeFilter = 'All'; // All, Equities, Future & Options, Commodities, Currencies
  String _tradeTypeFilter = 'All'; // All, Buy, Sell

  // Custom date picker state
  bool _showDatePickerPopup = false;
  late DateTime _leftMonth;
  late DateTime _rightMonth;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  String _dateValidationMsg = '';

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _tableScrollController = ScrollController();
    initScrollToLoad();
    // The search field's X empties the controller without firing onChanged,
    // so reset the query whenever the field becomes empty (same as TC_344).
    _searchController.addListener(() {
      if (!mounted) return;
      if (_searchController.text.isEmpty && _searchQuery.isNotEmpty) {
        setState(() {
          _searchQuery = '';
          displayedItemCount = ScrollToLoadMixin.itemsPerPage;
        });
      }
    });

    // Init calendar months
    final now = DateTime.now();
    _rightMonth = DateTime(now.year, now.month);
    _leftMonth = DateTime(now.year, now.month - 1);

    // Fetch data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    disposeScrollToLoad();
    _tableScrollController.dispose();
    _hoveredRowIndex.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _fetchData({bool force = false}) {
    final ledger = ref.read(ledgerProvider);
    if (!force && ledger.tradebookdata != null) return;
    final from = DateFormat('dd/MM/yyyy').format(_startDate);
    final to = DateFormat('dd/MM/yyyy').format(_endDate);
    ledger.fetchtradebookdata(context, from, to);
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

  List<Trades> _getFilteredAndSortedList(TradeBookModel? data) {
    if (data?.trades == null || data!.trades!.isEmpty) return [];

    List<Trades> filteredList = List.from(data.trades!);

    // Apply exchange filter
    if (_exchangeFilter != 'All') {
      filteredList = filteredList.where((trade) {
        final exchange = (trade.cOMPANYCODE ?? '').toUpperCase();
        switch (_exchangeFilter) {
          case 'Equities':
            return exchange.contains('CASH') ||
                exchange.contains('BSE_CASH') ||
                exchange.contains('NSE_CASH');
          case 'Future & Options':
            return exchange.contains('FNO') ||
                exchange.contains('NFO') ||
                exchange.contains('BFO');
          case 'Commodities':
            return exchange.contains('MCX') ||
                exchange.contains('NCDEX') ||
                exchange.contains('COM');
          case 'Currencies':
            return exchange.contains('CD_') ||
                exchange.contains('CDS');
          default:
            return true;
        }
      }).toList();
    }

    // Apply trade type filter
    if (_tradeTypeFilter != 'All') {
      filteredList = filteredList.where((trade) {
        final type = (trade.showtype ?? '').toUpperCase();
        return type == _tradeTypeFilter.toUpperCase();
      }).toList();
    }

    // Apply search filter — match the full Scrip cell text (name, strike,
    // option type, expiry) plus the segment, same as the main screens.
    final query = _searchQuery.toLowerCase().trim();
    if (query.isNotEmpty) {
      filteredList = filteredList.where((trade) {
        final searchable = [
          _scripDisplayText(trade),
          trade.cOMPANYCODE ?? '',
        ];
        return searchable.any((f) => f.toLowerCase().contains(query));
      }).toList();
    }

    // Apply sorting
    if (_sortColumnIndex != null) {
      filteredList.sort((a, b) {
        int compareResult = 0;
        switch (_sortColumnIndex) {
          case 0: // Trade Date
            final aDate = _tryParseTradeDate(a.tRADEDATE);
            final bDate = _tryParseTradeDate(b.tRADEDATE);
            if (aDate != null && bDate != null) {
              compareResult = aDate.compareTo(bDate);
            } else if (aDate == null && bDate == null) {
              compareResult =
                  (a.tRADEDATE ?? '').compareTo(b.tRADEDATE ?? '');
            } else {
              compareResult = aDate == null ? 1 : -1;
            }
            break;
          case 1: // Exchange
            compareResult =
                (a.cOMPANYCODE ?? '').compareTo(b.cOMPANYCODE ?? '');
            break;
          case 2: // Scrip
            compareResult =
                (a.sCRIPNAME ?? '').compareTo(b.sCRIPNAME ?? '');
            break;
          case 3: // Trade Type
            compareResult =
                (a.showtype ?? '').compareTo(b.showtype ?? '');
            break;
          case 4: // Quantity
            compareResult =
                (double.tryParse(a.showqnt ?? '0') ?? 0)
                    .compareTo(double.tryParse(b.showqnt ?? '0') ?? 0);
            break;
          case 5: // Price
            compareResult =
                (double.tryParse(a.showprice ?? '0') ?? 0)
                    .compareTo(double.tryParse(b.showprice ?? '0') ?? 0);
            break;
          case 6: // Amount
            compareResult =
                (double.tryParse(a.showamt ?? '0') ?? 0)
                    .compareTo(double.tryParse(b.showamt ?? '0') ?? 0);
            break;
          case 7: // Trade No
            compareResult = (int.tryParse(a.tRADENUMBER ?? '') ?? 0)
                .compareTo(int.tryParse(b.tRADENUMBER ?? '') ?? 0);
            break;
        }
        return _sortAscending ? compareResult : -compareResult;
      });
    }

    return filteredList;
  }

  void _toggleDatePicker() {
    setState(() {
      if (!_showDatePickerPopup) {
        _tempStartDate = _startDate;
        _tempEndDate = _endDate;
        _dateValidationMsg = '';
        _rightMonth = DateTime(_endDate.year, _endDate.month);
        _leftMonth = DateTime(_rightMonth.year, _rightMonth.month - 1);
      }
      _showDatePickerPopup = !_showDatePickerPopup;
    });
  }

  void _onDateTap(DateTime date) {
    setState(() {
      if (_tempStartDate == null || _tempEndDate != null) {
        // Start new selection
        _tempStartDate = date;
        _tempEndDate = null;
        _dateValidationMsg = '';
      } else {
        // Complete selection
        DateTime start = _tempStartDate!;
        DateTime end = date;
        if (end.isBefore(start)) {
          final temp = start;
          start = end;
          end = temp;
        }
        // Validate 3-month max
        final diff = DateTime(end.year, end.month, end.day)
            .difference(DateTime(start.year, start.month, start.day))
            .inDays;
        if (diff > 90) {
          _dateValidationMsg =
              'You can only select a date range of Three month.';
          _tempStartDate = date;
          _tempEndDate = null;
          return;
        }
        _dateValidationMsg = '';
        _tempStartDate = start;
        _tempEndDate = end;
        // Apply and fetch
        _startDate = start;
        _endDate = end;
        displayedItemCount = ScrollToLoadMixin.itemsPerPage;
        _showDatePickerPopup = false;
        _fetchData(force: true);
      }
    });
  }

  void _applyQuickDate(int days) {
    setState(() {
      _endDate = DateTime.now();
      _startDate = _endDate.subtract(Duration(days: days));
      displayedItemCount = ScrollToLoadMixin.itemsPerPage;
      _showDatePickerPopup = false;
    });
    _fetchData(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider);
    final theme = ref.watch(themeProvider);
    final filteredList = _getFilteredAndSortedList(ledger.tradebookdata);
    final tradeCount = filteredList.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme, tradeCount),
            // const Divider(height: 1),
            Expanded(
              child: Stack(
                children: [
                  ledger.tradebookloading
                      ? Center(child: MyntLoader.simple())
                      : _buildTable(context, theme, filteredList),
                  // Date picker overlay
                  if (_showDatePickerPopup) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showDatePickerPopup = false;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    _buildDatePickerOverlay(context),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PDF / Excel download menu. Exports the same filtered + sorted list the
  /// table is showing, for the currently selected date range.
  Widget _buildDownloadButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.download,
          size: 20,
          color: resolveThemeColor(context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.textSecondary)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'Download',
      color: resolveThemeColor(context,
          dark: MyntColors.cardDark, light: MyntColors.card),
      onSelected: (value) {
        final ledger = ref.read(ledgerProvider);
        final trades = _getFilteredAndSortedList(ledger.tradebookdata);

        if (trades.isEmpty) {
          warningMessage(context, 'No data to download');
          return;
        }

        final pref = locator<Preferences>();
        final clientId = pref.clientId ?? '';
        final clientName = pref.clientName ?? '';
        final dateRange =
            '${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}';

        if (value == 'pdf') {
          TradebookDownloadHelper.downloadPdf(
            trades: trades,
            clientId: clientId,
            clientName: clientName,
            dateRange: dateRange,
          );
        } else if (value == 'excel') {
          TradebookDownloadHelper.downloadExcel(
            trades: trades,
            clientId: clientId,
            clientName: clientName,
            dateRange: dateRange,
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, size: 18, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text('Download PDF',
                  style: TextStyle(
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  )),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'excel',
          child: Row(
            children: [
              Icon(Icons.table_chart, size: 18, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text('Download Excel',
                  style: TextStyle(
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
      BuildContext context, ThemesProvider theme, int tradeCount) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;
    final dateStr =
        '${DateFormat('dd/MM/yyyy').format(_startDate)}_to_${DateFormat('dd/MM/yyyy').format(_endDate)}';

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 16,
          vertical: isSmallScreen ? 10 : 16),
      child: Row(
        children: [
          CustomBackBtn(onBack: widget.onBack),
          SizedBox(width: isSmallScreen ? 4 : 8),
          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tradebook',
                  style: MyntWebTextStyles.head(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: FontWeight.w500),
                ),
                // const SizedBox(height: 2),
                // Text(
                //   'All your trade activity based on dates',
                //   style: MyntWebTextStyles.para(context,
                //       darkColor: MyntColors.textSecondaryDark,
                //       lightColor: MyntColors.textSecondary),
                // ),
              ],
            ),
          ),
          // Trade count
          // Text(
          //   '$tradeCount Trades',
          //   style: MyntWebTextStyles.tableCell(context,
          //       darkColor: MyntColors.textPrimaryDark,
          //       lightColor: MyntColors.textPrimary,
          //       fontWeight: FontWeight.w600),
          // ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          // Download button
          _buildDownloadButton(context),
          const SizedBox(width: 8),
          // Filter button

          // Date range button
          InkWell(
            onTap: _toggleDatePicker,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: resolveThemeColor(context,
                      dark: MyntColors.cardBorderDark,
                      light: MyntColors.cardBorder),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: MyntWebTextStyles.para(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          // Search
          SizedBox(
            width: isSmallScreen ? screenWidth * 0.2 : 200,
            height: isSmallScreen ? 36 : 40,
            child: MyntSearchTextField.withSmartClear(
              controller: _searchController,
              placeholder: 'Search',
              leadingIcon: 'assets/icon/search.svg',
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  displayedItemCount = ScrollToLoadMixin.itemsPerPage;
                });
              },
            ),
          ),
        const SizedBox(width: 8),
          Builder(
            builder: (buttonContext) {
              return _buildIconButton(
                icon: Icons.tune,
                tooltip: 'Filter',
                isActive: _exchangeFilter != 'All' || _tradeTypeFilter != 'All',
                onTap: () => _showFilterPopover(buttonContext),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? resolveThemeColor(context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary)
                : resolveThemeColor(context,
                    dark: MyntColors.cardDark,
                    light: MyntColors.card),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive
                ? Colors.white
                : resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
          ),
        ),
      ),
    );
  }

  void _showFilterPopover(BuildContext buttonContext) {
    final exchangeOptions = ['All', 'Equities', 'Future & Options', 'Commodities', 'Currencies'];
    final tradeTypeOptions = ['All', 'Buy', 'Sell'];

    shadcn.showPopover(
      context: buttonContext,
      alignment: Alignment.bottomCenter,
      offset: const Offset(0, 8),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(buttonContext).borderRadiusLg,
      ),
      builder: (popoverContext) {
        return Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.backgroundColorDark,
                light: MyntColors.backgroundColor),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exchange section header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  'Exchange',
                  style: MyntWebTextStyles.bodySmall(context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary),
                      fontWeight: MyntFonts.semiBold),
                ),
              ),
              ...exchangeOptions.map((f) {
                final isSelected = _exchangeFilter == f;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _exchangeFilter = f;
                      displayedItemCount = ScrollToLoadMixin.itemsPerPage;
                    });
                    shadcn.closeOverlay(popoverContext);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: isSelected
                        ? resolveThemeColor(context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary)
                            .withValues(alpha: 0.1)
                        : null,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            f,
                            style: MyntWebTextStyles.bodySmall(context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                                fontWeight: isSelected
                                    ? MyntFonts.semiBold
                                    : MyntFonts.medium),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check,
                              size: 16,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.primaryDark,
                                  light: MyntColors.primary)),
                      ],
                    ),
                  ),
                );
              }),
              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Divider(
                  height: 1,
                  color: resolveThemeColor(context,
                      dark: MyntColors.dividerDark,
                      light: MyntColors.divider),
                ),
              ),
              // Trade Type section header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  'Trade Type',
                  style: MyntWebTextStyles.bodySmall(context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary),
                      fontWeight: MyntFonts.semiBold),
                ),
              ),
              ...tradeTypeOptions.map((f) {
                final isSelected = _tradeTypeFilter == f;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _tradeTypeFilter = f;
                      displayedItemCount = ScrollToLoadMixin.itemsPerPage;
                    });
                    shadcn.closeOverlay(popoverContext);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: isSelected
                        ? resolveThemeColor(context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary)
                            .withValues(alpha: 0.1)
                        : null,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            f,
                            style: MyntWebTextStyles.bodySmall(context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                                fontWeight: isSelected
                                    ? MyntFonts.semiBold
                                    : MyntFonts.medium),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check,
                              size: 16,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.primaryDark,
                                  light: MyntColors.primary)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // Custom date picker overlay
  Widget _buildDatePickerOverlay(BuildContext context) {
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondaryTextColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final cardColor = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: cardColor,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Two calendars side by side
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCalendarMonth(
                      context,
                      _leftMonth,
                      primaryColor,
                      textColor,
                      secondaryTextColor,
                      onPrev: () {
                        setState(() {
                          _leftMonth = DateTime(
                              _leftMonth.year, _leftMonth.month - 1);
                          _rightMonth = DateTime(
                              _leftMonth.year, _leftMonth.month + 1);
                        });
                      },
                      onNext: () {
                        setState(() {
                          _leftMonth = DateTime(
                              _leftMonth.year, _leftMonth.month + 1);
                          _rightMonth = DateTime(
                              _leftMonth.year, _leftMonth.month + 1);
                        });
                      },
                    ),
                    const SizedBox(width: 16),
                    _buildCalendarMonth(
                      context,
                      _rightMonth,
                      primaryColor,
                      textColor,
                      secondaryTextColor,
                      onPrev: () {
                        setState(() {
                          _rightMonth = DateTime(
                              _rightMonth.year, _rightMonth.month - 1);
                          _leftMonth = DateTime(
                              _rightMonth.year, _rightMonth.month - 1);
                        });
                      },
                      onNext: () {
                        setState(() {
                          _rightMonth = DateTime(
                              _rightMonth.year, _rightMonth.month + 1);
                          _leftMonth = DateTime(
                              _rightMonth.year, _rightMonth.month - 1);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Quick presets and validation
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQuickPresetButton('Last 7 days', 7, textColor),
                    const SizedBox(width: 16),
                    _buildQuickPresetButton('Last 30 days', 30, textColor),
                    if (_dateValidationMsg.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Text(
                        _dateValidationMsg,
                        style: MyntWebTextStyles.para(context,
                            darkColor: MyntColors.lossDark,
                            lightColor: MyntColors.loss),
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

  Widget _buildQuickPresetButton(
      String label, int days, Color textColor) {
    return InkWell(
      onTap: () => _applyQuickDate(days),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: MyntWebTextStyles.body(context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildCalendarMonth(
    BuildContext context,
    DateTime month,
    Color primaryColor,
    Color textColor,
    Color secondaryTextColor, {
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    final monthName = DateFormat('MMMM yyyy').format(month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;
    final today = DateTime.now();
    final dayHeaders = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return SizedBox(
      width: 260,
      child: Column(
        children: [
          // Month header with navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: onPrev,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.chevron_left,
                      size: 20, color: secondaryTextColor),
                ),
              ),
              Text(
                monthName,
                style: MyntWebTextStyles.body(context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                    fontWeight: FontWeight.w600),
              ),
              InkWell(
                onTap: onNext,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.chevron_right,
                      size: 20, color: secondaryTextColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Day headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dayHeaders
                .map((d) => SizedBox(
                      width: 34,
                      child: Center(
                        child: Text(d,
                            style: MyntWebTextStyles.para(context,
                                darkColor: MyntColors.textSecondaryDark,
                                lightColor: MyntColors.textSecondary,
                                fontWeight: FontWeight.w500)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Day grid
          ...List.generate(6, (weekIndex) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (dayIndex) {
                final dayNum =
                    weekIndex * 7 + dayIndex - firstWeekday + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox(width: 34, height: 34);
                }

                final date =
                    DateTime(month.year, month.month, dayNum);
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final isFuture = date.isAfter(today);
                final isStart = _tempStartDate != null &&
                    _isSameDay(date, _tempStartDate!);
                final isEnd = _tempEndDate != null &&
                    _isSameDay(date, _tempEndDate!);
                final isInRange = _tempStartDate != null &&
                    _tempEndDate != null &&
                    date.isAfter(_tempStartDate!
                        .subtract(const Duration(days: 1))) &&
                    date.isBefore(
                        _tempEndDate!.add(const Duration(days: 1)));

                Color? bgColor;
                Color dayTextColor = textColor;

                if (isStart || isEnd) {
                  bgColor = primaryColor;
                  dayTextColor = Colors.white;
                } else if (isInRange) {
                  bgColor = primaryColor.withValues(alpha: 0.1);
                }

                if (isFuture) {
                  dayTextColor = secondaryTextColor.withValues(alpha: 0.4);
                }

                return GestureDetector(
                  onTap: isFuture ? null : () => _onDateTap(date),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: (isStart || isEnd)
                          ? BoxShape.circle
                          : BoxShape.rectangle,
                      borderRadius: (isStart || isEnd)
                          ? null
                          : BorderRadius.zero,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w400,
                        color: dayTextColor,
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _tryParseTradeDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateFormat('dd-MM-yyyy').parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  /// Text shown in the Scrip cell — also what search matches against.
  String _scripDisplayText(Trades trade) {
    final scripName = trade.sCRIPNAME ?? '--';
    final strikePrice = (trade.sTRIKEPRICE ?? '').trim();
    final optionType = (trade.oPTIONTYPE ?? '').trim();
    final expiryDate = (trade.eXPIRYDATE ?? '').trim();

    final hasStrike = strikePrice.isNotEmpty && strikePrice != '0' && strikePrice != 'null';
    final hasOption = optionType.isNotEmpty && optionType != '--' && optionType != 'null';
    final hasExpiry = expiryDate.isNotEmpty && expiryDate != '--' && expiryDate != 'null';

    final parts = [
      scripName,
      if (hasStrike) strikePrice,
      if (hasOption) optionType,
      if (hasExpiry) expiryDate,
    ];
    return parts.join(' ');
  }

  // Text style helpers
  Widget _buildScripCell(BuildContext context, Trades trade) {
    final fullText = _scripDisplayText(trade);

    return Tooltip(
      message: fullText,
      child: Text(
        fullText,
        style: _getTextStyle(context),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  TextStyle _getTextStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableCell(
      context,
      color: color,
      darkColor: color ?? MyntColors.textPrimaryDark,
      lightColor: color ?? MyntColors.textPrimary,
      fontWeight: MyntFonts.medium,
    );
  }

  TextStyle _getHeaderStyle(BuildContext context) {
    return MyntWebTextStyles.tableHeader(
      context,
      darkColor: MyntColors.textSecondaryDark,
      lightColor: MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  // Build sortable header cell
  shadcn.TableCell _buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 7;

    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding = const EdgeInsets.fromLTRB(16, 0, 8, 0);
    } else if (isLastColumn) {
      headerPadding = const EdgeInsets.fromLTRB(8, 0, 16, 0);
    } else {
      headerPadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 0);
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
      child: InkWell(
        onTap: () => _onSort(columnIndex),
        child: Container(
          padding: headerPadding,
          alignment:
              alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (alignRight && _sortColumnIndex == columnIndex)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              if (alignRight && _sortColumnIndex == columnIndex)
                const SizedBox(width: 4),
              Text(label, style: _getHeaderStyle(context)),
              if (!alignRight && _sortColumnIndex == columnIndex)
                const SizedBox(width: 4),
              if (!alignRight && _sortColumnIndex == columnIndex)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  shadcn.TableCell _buildDataCell({
    required Widget child,
    required int columnIndex,
    bool alignRight = false,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 7;

    EdgeInsets cellPadding;
    if (isFirstColumn) {
      cellPadding = const EdgeInsets.fromLTRB(16, 12, 12, 12);
    } else if (isLastColumn) {
      cellPadding = const EdgeInsets.fromLTRB(12, 12, 16, 12);
    } else {
      cellPadding =
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
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
        padding: cellPadding,
        alignment: alignRight ? Alignment.topRight : null,
        child: child,
      ),
    );
  }

  // Row-level hover: a single MouseRegion + ValueListenableBuilder per row
  // (not per cell). Keeps hover repaints O(rows) instead of O(rows * 8).
  Widget _buildHoverableRow(
    BuildContext context,
    int rowIndex,
    Trades trade,
    Map<int, shadcn.FixedTableSize> columnWidths,
  ) {
    return MouseRegion(
      onEnter: (_) => _hoveredRowIndex.value = rowIndex,
      onExit: (_) {
        if (_hoveredRowIndex.value == rowIndex) {
          _hoveredRowIndex.value = null;
        }
      },
      child: ValueListenableBuilder<int?>(
        valueListenable: _hoveredRowIndex,
        builder: (context, hoveredIndex, _) {
          final isRowHovered = hoveredIndex == rowIndex;
          return Container(
            color: isRowHovered
                ? resolveThemeColor(
                    context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary,
                  ).withValues(alpha: 0.08)
                : null,
            child: shadcn.Table(
              defaultRowHeight: const shadcn.FixedTableSize(52),
              columnWidths: columnWidths,
              rows: [
                shadcn.TableRow(
                  cells: [
                    _buildDataCell(
                      columnIndex: 0,
                      child: Text(
                        trade.tRADEDATE ?? '--',
                        style: _getTextStyle(context),
                      ),
                    ),
                    _buildDataCell(
                      columnIndex: 1,
                      child: Text(
                        trade.cOMPANYCODE ?? '--',
                        style: _getTextStyle(context),
                      ),
                    ),
                    _buildDataCell(
                      columnIndex: 2,
                      child: _buildScripCell(context, trade),
                    ),
                    _buildDataCell(
                      columnIndex: 3,
                      child: Text(
                        trade.showtype ?? '--',
                        style: _getTextStyle(
                          context,
                          color:
                              _getTradeTypeColor(context, trade.showtype),
                        ),
                      ),
                    ),
                    _buildDataCell(
                      columnIndex: 4,
                      alignRight: true,
                      child: Text(
                        trade.showqnt ?? '--',
                        style: _getTextStyle(context),
                      ),
                    ),
                    _buildDataCell(
                      columnIndex: 5,
                      alignRight: true,
                      child: Text(
                        '₹${_formatPrice(trade.showprice)}',
                        style: _getTextStyle(context),
                      ),
                    ),
                    _buildDataCell(
                      columnIndex: 6,
                      alignRight: true,
                      child: Text(
                        '₹${_formatPrice(trade.showamt)}',
                        style: _getTextStyle(context),
                      ),
                    ),
                    _buildDataCell(
                      columnIndex: 7,
                      alignRight: true,
                      child: Text(
                        trade.tRADENUMBER ?? '--',
                        style: _getTextStyle(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static const List<String> _headers = [
    'Trade Date', 'Exchange', 'Scrip', 'Trade Type', 'Quantity', 'Price',
    'Amount', 'Trade No',
  ];
  // Previous fixed split - now only used to share out spare width.
  static const List<double> _columnWeights = [
    0.11, 0.11, 0.24, 0.09, 0.09, 0.12, 0.12, 0.12,
  ];

  /// Text of every cell in a row, in column order - same strings the row
  /// renders in [_buildHoverableRow].
  List<String> _cellTexts(Trades trade) => [
        trade.tRADEDATE ?? '--',
        trade.cOMPANYCODE ?? '--',
        _scripDisplayText(trade),
        trade.showtype ?? '--',
        trade.showqnt ?? '--',
        '\u20B9${_formatPrice(trade.showprice)}',
        '\u20B9${_formatPrice(trade.showamt)}',
        trade.tRADENUMBER ?? '--',
      ];

  double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      // Directionality, not TextDirection.ltr — intl's TextDirection
      // shadows Flutter's in this file.
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  List<double> _fitColumnWidths(
      BuildContext context, double available, List<Trades> rows) {
    const sortIcon = 20.0; // 16 icon + 4 gap, shown on the sorted column
    const safety = 4.0; // sub-pixel rounding headroom
    // Tradebook can hold thousands of rows, so only the few longest strings
    // per column (by character count) are actually measured.
    const candidatesPerColumn = 5;
    final cellStyle = _getTextStyle(context);
    final headerStyle = _getHeaderStyle(context);
    final last = _headers.length - 1;

    // Same horizontal padding as _buildHeaderCell / _buildDataCell.
    double headerPad(int i) => i == 0 || i == last ? 24 : 12;
    double cellPad(int i) => i == 0 || i == last ? 28 : 24;

    final mins = List<double>.generate(
        _headers.length,
        (i) =>
            _textWidth(context, _headers[i], headerStyle) +
            sortIcon +
            headerPad(i) +
            safety);

    final longest =
        List<List<String>>.generate(_headers.length, (_) => <String>[]);
    for (final trade in rows) {
      final texts = _cellTexts(trade);
      for (int i = 0; i < texts.length; i++) {
        final list = longest[i];
        final t = texts[i];
        if (list.length < candidatesPerColumn) {
          list.add(t);
        } else {
          int shortest = 0;
          for (int k = 1; k < list.length; k++) {
            if (list[k].length < list[shortest].length) shortest = k;
          }
          if (t.length > list[shortest].length) list[shortest] = t;
        }
      }
    }
    for (int i = 0; i < _headers.length; i++) {
      for (final t in longest[i]) {
        final w = _textWidth(context, t, cellStyle) + cellPad(i) + safety;
        if (w > mins[i]) mins[i] = w;
      }
    }

    final totalMin = mins.fold<double>(0, (a, b) => a + b);
    if (totalMin >= available) return mins; // scrolls horizontally
    final extra = available - totalMin;
    final weightSum = _columnWeights.fold<double>(0, (a, b) => a + b);
    return [
      for (int i = 0; i < mins.length; i++)
        mins[i] + extra * _columnWeights[i] / weightSum,
    ];
  }

  Widget _buildTable(
      BuildContext context, ThemesProvider theme, List<Trades> sortedList) {
    final bool hasData = sortedList.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth - 32;
        // 8 columns: Trade Date, Exchange, Scrip, Trade Type, Quantity, Price, Amount, Trade No
        // Each column is at least as wide as its header and its widest value,
        // so the scrip name is never cut off. Spare width is shared in the
        // old proportions; when the minimums don't fit, the table scrolls
        // horizontally instead of truncating.
        final widths = _fitColumnWidths(context, totalWidth, sortedList);
        final double tableWidth = widths.fold<double>(0, (a, b) => a + b);
        final columnWidths = {
          for (int i = 0; i < widths.length; i++)
            i: shadcn.FixedTableSize(widths[i]),
        };
        // Same as main Positions/Holdings: keep the horizontal scrollbar
        // visible only while the columns are wider than the screen.
        final bool needsHorizontalScroll = tableWidth > totalWidth;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: shadcn.OutlinedContainer(
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: needsHorizontalScroll,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: totalWidth),
                  child: Column(
                    children: [
                      // Fixed Header
                      shadcn.Table(
                        defaultRowHeight: const shadcn.FixedTableSize(50),
                        columnWidths: columnWidths,
                        rows: [
                          shadcn.TableHeader(
                            cells: [
                              _buildHeaderCell('Trade Date', 0),
                              _buildHeaderCell('Exchange', 1),
                              _buildHeaderCell('Scrip', 2),
                              _buildHeaderCell('Trade Type', 3),
                              _buildHeaderCell('Quantity', 4, true),
                              _buildHeaderCell('Price', 5, true),
                              _buildHeaderCell('Amount', 6, true),
                              _buildHeaderCell('Trade No', 7, true),
                            ],
                          ),
                        ],
                      ),
                      // Scrollable Body
                      Expanded(
                        child: hasData
                            ? Builder(
                                builder: (context) {
                                  final visibleCount = sortedList.length <
                                          displayedItemCount
                                      ? sortedList.length
                                      : displayedItemCount;
                                  final hasMore = displayedItemCount <
                                      sortedList.length;
                                  return SizedBox(
                                    width: tableWidth,
                                    child: ListView.builder(
                                      controller: _tableScrollController,
                                      itemCount:
                                          visibleCount + (hasMore ? 1 : 0),
                                      itemBuilder: (context, index) {
                                      if (index == visibleCount) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.all(16.0),
                                          child: Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Theme.of(context)
                                                    .primaryColor,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      return _buildHoverableRow(
                                        context,
                                        index,
                                        sortedList[index],
                                        columnWidths,
                                      );
                                    },
                                    ),
                                  );
                                },
                              )
                            : const Center(
                                child: NoDataFound(
                                  secondaryEnabled: false,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getTradeTypeColor(BuildContext context, String? type) {
    if (type == null) return Colors.grey;
    final upperType = type.toUpperCase();
    if (upperType == 'BUY') {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    } else if (upperType == 'SELL') {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    }
    return resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
  }

  String _formatPrice(String? price) {
    if (price == null || price.isEmpty) return '0.00';
    try {
      final value = double.parse(price);
      return value.toStringAsFixed(2);
    } catch (e) {
      return price;
    }
  }
}
