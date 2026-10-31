// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart' hide Table, TableRow, TableCell, Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;

import '../../../../models/desk_reports_model/ca_events_model.dart';
import '../../../../provider/ledger_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/custom_back_btn.dart';
import '../../../../sharedWidget/common_search_fields_web.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../sharedWidget/scroll_to_load_mixin.dart';

class CAEventsScreenWeb extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const CAEventsScreenWeb({super.key, this.onBack});

  @override
  ConsumerState<CAEventsScreenWeb> createState() => _CAEventsScreenWebState();
}

class _CAEventsScreenWebState extends ConsumerState<CAEventsScreenWeb>
    with ScrollToLoadMixin {
  final ScrollController _tableScrollController = ScrollController();

  @override
  ScrollController get tableScrollController => _tableScrollController;

  int _selectedTabIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);

  // Date range
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // Date picker state
  bool _showDatePickerPopup = false;
  late DateTime _leftMonth;
  late DateTime _rightMonth;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  String _dateValidationMsg = '';

  static const List<String> _tabLabels = [
    'Board Meeting',
    'AGM / EGMs',
    'Bonus',
    'Dividend',
    'Rights',
    'Split',
  ];

  @override
  void initState() {
    super.initState();
    initScrollToLoad();
    final now = DateTime.now();
    _rightMonth = DateTime(now.year, now.month);
    _leftMonth = DateTime(now.year, now.month - 1);
    // The search field's X button only empties the text box; it never fires
    // onChanged. Reset the filter here when the box goes empty.
    _searchController.addListener(_onSearchTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    disposeScrollToLoad();
    _tableScrollController.dispose();
    _hoveredRowIndex.dispose();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    if (_searchController.text.isEmpty && _searchQuery.isNotEmpty) {
      setState(() {
        _searchQuery = '';
        displayedItemCount = ScrollToLoadMixin.itemsPerPage;
      });
    }
  }

  void _fetchData({bool force = false}) {
    resetDisplayCount();
    final ledger = ref.read(ledgerProvider);
    if (!force && ledger.caeventalldata != null) return;
    final from = DateFormat('dd/MM/yyyy').format(_startDate);
    final to = DateFormat('dd/MM/yyyy').format(_endDate);
    ledger.fetchcaeventsdata(context, from, to);
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
        _tempStartDate = date;
        _tempEndDate = null;
        _dateValidationMsg = '';
      } else {
        DateTime start = _tempStartDate!;
        DateTime end = date;
        if (end.isBefore(start)) {
          final temp = start;
          start = end;
          end = temp;
        }
        _dateValidationMsg = '';
        _tempStartDate = start;
        _tempEndDate = end;
        _startDate = start;
        _endDate = end;
        _showDatePickerPopup = false;
        _fetchData(force: true);
      }
    });
  }

  void _applyQuickDate(int days) {
    setState(() {
      _endDate = DateTime.now();
      _startDate = _endDate.subtract(Duration(days: days));
      _showDatePickerPopup = false;
    });
    _fetchData(force: true);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final ledgerprovider = ref.watch(ledgerProvider);
    final theme = ref.watch(themeProvider);
    final isLoading = ledgerprovider.caeventloading;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme, ledgerprovider),
            // Tabs
            _buildTabBar(context),
            Expanded(
              child: Stack(
                children: [
                  if (isLoading)
                    Center(child: MyntLoader.simple())
                  else if (ledgerprovider.caeventalldata == null)
                    const Center(
                        child: NoDataFound(secondaryEnabled: false))
                  else
                    _buildBody(context, ledgerprovider),
                  if (_showDatePickerPopup) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _showDatePickerPopup = false),
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

  Widget _buildHeader(
      BuildContext context, ThemesProvider theme, LDProvider ledgerprovider) {
    final dateStr =
        '${DateFormat('dd/MM/yyyy').format(_startDate)}_to_${DateFormat('dd/MM/yyyy').format(_endDate)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CustomBackBtn(onBack: widget.onBack),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event calendar',
                  style: MyntWebTextStyles.head(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
                // const SizedBox(height: 2),
                // Text(
                //   'Upcoming events at a glance.',
                //   style: MyntWebTextStyles.para(context,
                //       darkColor: MyntColors.textSecondaryDark,
                //       lightColor: MyntColors.textSecondary),
                // ),
              ],
            ),
          ),
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
          const SizedBox(width: 12),
          // Search
          SizedBox(
            width: 200,
            child: MyntSearchTextField.withSmartClear(
              controller: _searchController,
              placeholder: 'Search',
              height: 36,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  displayedItemCount = ScrollToLoadMixin.itemsPerPage;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final isDark =
        shadcn.Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _tabLabels.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isActive = index == _selectedTabIndex;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedTabIndex = index;
                displayedItemCount = ScrollToLoadMixin.itemsPerPage;
              }),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight:
                        isActive ? MyntFonts.semiBold : MyntFonts.medium,
                  ).copyWith(
                    color: isActive
                        ? shadcn.Theme.of(context).colorScheme.foreground
                        : shadcn.Theme.of(context).colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LDProvider ledgerprovider) {
    final data = ledgerprovider.caeventalldata;
    if (data == null) {
      return const Center(child: NoDataFound(secondaryEnabled: false));
    }

    switch (_selectedTabIndex) {
      case 0:
        return _buildBoardMeetingTable(context, data.boardmeeting ?? []);
      case 1:
        return _buildAgmEgmTable(context, data.aGMEGM ?? []);
      case 2:
        return _buildBonusTable(context, data.bonus ?? []);
      case 3:
        return _buildDividendTable(context, data.dividend ?? []);
      case 4:
        return _buildRightsTable(context, data.rights ?? []);
      case 5:
        return _buildSplitTable(context, data.split ?? []);
      default:
        return const SizedBox();
    }
  }

  // ==================== Board Meeting Table ====================
  Widget _buildBoardMeetingTable(
      BuildContext context, List<Boardmeeting> items) {
    final filtered = _applySearch(
        items, (item) => item.companyName ?? '');
    if (filtered.isEmpty) {
      return const Center(child: NoDataFound(secondaryEnabled: false));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth - 32;
        final columnWidths = {
          0: shadcn.FixedTableSize(totalWidth * 0.30),
          1: shadcn.FixedTableSize(totalWidth * 0.15),
          2: shadcn.FixedTableSize(totalWidth * 0.55),
        };

        return Padding(
          padding: const EdgeInsets.all(16),
          child: shadcn.OutlinedContainer(
            child: Column(
              children: [
                shadcn.Table(
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  columnWidths: columnWidths,
                  rows: [
                    shadcn.TableHeader(cells: [
                      _headerCell('Company name'),
                      _headerCell('Date'),
                      _headerCell('Agenda'),
                    ]),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    child: Column(
                      children: takeDisplayed(filtered).asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        return _boardMeetingRow(
                          context,
                          rowIndex: i,
                          totalWidth: totalWidth,
                          companyName: item.companyName ?? '--',
                          date: item.boardMeetingDate ?? '--',
                          agenda: (item.agenda ?? '--').trim(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== AGM/EGM Table ====================
  Widget _buildAgmEgmTable(BuildContext context, List<AGMEGM> items) {
    final filtered = _applySearch(items, (item) => item.companyName ?? '');
    if (filtered.isEmpty) {
      return const Center(child: NoDataFound(secondaryEnabled: false));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth - 32;
        final columnWidths = {
          0: shadcn.FixedTableSize(totalWidth * 0.30),
          1: shadcn.FixedTableSize(totalWidth * 0.15),
          2: shadcn.FixedTableSize(totalWidth * 0.55),
        };

        return Padding(
          padding: const EdgeInsets.all(16),
          child: shadcn.OutlinedContainer(
            child: Column(
              children: [
                shadcn.Table(
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  columnWidths: columnWidths,
                  rows: [
                    shadcn.TableHeader(cells: [
                      _headerCell('Company name'),
                      _headerCell('Date'),
                      _headerCell('Agenda'),
                    ]),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    child: Column(
                      children: takeDisplayed(filtered).asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        return _boardMeetingRow(
                          context,
                          rowIndex: i,
                          totalWidth: totalWidth,
                          companyName: item.companyName ?? '--',
                          date: item.eGMDate ?? '--',
                          agenda: (item.agenda ?? '--').trim(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== Bonus Table ====================
  Widget _buildBonusTable(BuildContext context, List<Bonus> items) {
    final filtered = _applySearch(items, (item) => item.companyName ?? '');
    if (filtered.isEmpty) {
      return const Center(child: NoDataFound(secondaryEnabled: false));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth - 32;
        final columnWidths = {
          0: shadcn.FixedTableSize(totalWidth * 0.35),
          1: shadcn.FixedTableSize(totalWidth * 0.20),
          2: shadcn.FixedTableSize(totalWidth * 0.25),
          3: shadcn.FixedTableSize(totalWidth * 0.20),
          // 4: shadcn.FixedTableSize(totalWidth * 0.15),
        };

        return Padding(
          padding: const EdgeInsets.all(16),
          child: shadcn.OutlinedContainer(
            child: Column(
              children: [
                shadcn.Table(
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  columnWidths: columnWidths,
                  rows: [
                    shadcn.TableHeader(cells: [
                      _headerCell('Company name'),
                      // _headerCell('Source Date'),
                      _headerCell('Ratio'),
                      _headerCell('Record Date'),
                      _headerCell('Ex Bonus Date'),
                    ]),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    child: shadcn.Table(
                      defaultRowHeight: const shadcn.FixedTableSize(52),
                      columnWidths: columnWidths,
                      rows: takeDisplayed(filtered).asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        return shadcn.TableRow(cells: [
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.companyName ?? '--',
                              style: _textStyle(context,
                                  fontWeight: MyntFonts.semiBold),
                            ),
                          ),
                          _dataCell(
                            rowIndex: i,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_cutDecimal(item.ratioN)} : ${_cutDecimal(item.ratioD)}',
                                  style: _textStyle(context),
                                ),
                                if (item.ratioN != null && item.ratioD != null) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'For every ${_cutDecimal(item.ratioD)} shares you own,\nyou will get ${_cutDecimal(item.ratioN)} extra share.',
                                    preferBelow: true,
                                    verticalOffset: 16,
                                    child: Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.textSecondaryDark,
                                          light: MyntColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.recordDate ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                          // _dataCell(
                          //   rowIndex: i,
                          //   child: Text(
                          //     item.sourceDate ?? '--',
                          //     style: _textStyle(context),
                          //   ),
                          // ),
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.exBonusDate ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== Dividend Table ====================
  Widget _buildDividendTable(BuildContext context, List<Dividend> items) {
    final filtered = _applySearch(items, (item) => item.companyName ?? '');
    if (filtered.isEmpty) {
      return const Center(child: NoDataFound(secondaryEnabled: false));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth - 32;
        final columnWidths = {
          0: shadcn.FixedTableSize(totalWidth * 0.25),
          1: shadcn.FixedTableSize(totalWidth * 0.15),
          2: shadcn.FixedTableSize(totalWidth * 0.15),
          3: shadcn.FixedTableSize(totalWidth * 0.15),
          4: shadcn.FixedTableSize(totalWidth * 0.15),
          5: shadcn.FixedTableSize(totalWidth * 0.15),
        };

        return Padding(
          padding: const EdgeInsets.all(16),
          child: shadcn.OutlinedContainer(
            child: Column(
              children: [
                shadcn.Table(
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  columnWidths: columnWidths,
                  rows: [
                    shadcn.TableHeader(cells: [
                      _headerCell('Company name'),
                      _headerCell('Ex Date'),
                      _headerCell('Dividend %'),
                      _headerCell('Per Share'),
                      _headerCell('Record Date'),
                      _headerCell('Details'),
                    ]),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    child: shadcn.Table(
                      defaultRowHeight: const shadcn.FixedTableSize(52),
                      columnWidths: columnWidths,
                      rows: takeDisplayed(filtered).asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        return shadcn.TableRow(cells: [
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.companyName ?? '--',
                              style: _textStyle(context,
                                  fontWeight: MyntFonts.semiBold),
                            ),
                          ),
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.exDate ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.dividendPercent ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.dividendpershare ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.recordDate ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                          _dataCell(
                            rowIndex: i,
                            child: _tooltipText(
                              context,
                              (item.details ?? '--').trim(),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== Rights Table ====================
  Widget _buildRightsTable(BuildContext context, List<Rights> items) {
    final filtered = _applySearch(items, (item) => item.companyName ?? '');
    if (filtered.isEmpty) {
      return const Center(child: NoDataFound(secondaryEnabled: false));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth - 32;
        final columnWidths = {
          0: shadcn.FixedTableSize(totalWidth * 0.25),
          1: shadcn.FixedTableSize(totalWidth * 0.20),
          2: shadcn.FixedTableSize(totalWidth * 0.20),
          3: shadcn.FixedTableSize(totalWidth * 0.18),
          4: shadcn.FixedTableSize(totalWidth * 0.17),
          // 5: shadcn.FixedTableSize(totalWidth * 0.0),
          // 6: shadcn.FixedTableSize(totalWidth * 0.10),
        };

        return Padding(
          padding: const EdgeInsets.all(16),
          child: shadcn.OutlinedContainer(
            child: Column(
              children: [
                shadcn.Table(
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  columnWidths: columnWidths,
                  rows: [
                    shadcn.TableHeader(cells: [
                      _headerCell('Company name'),
                      // _headerCell('Offer Price'),
                      _headerCell('Rights Ratio'),
                      _headerCell('Premium'),
                      // _headerCell('Source Date'),
                      _headerCell('Record Date'),
                      _headerCell('Ex Rights Date'),
                    ]),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    child: shadcn.Table(
                      defaultRowHeight: const shadcn.FixedTableSize(52),
                      columnWidths: columnWidths,
                      rows: takeDisplayed(filtered).asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        return shadcn.TableRow(cells: [
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.companyName ?? '--',
                              style: _textStyle(context,
                                  fontWeight: MyntFonts.semiBold),
                            ),
                          ),
                           _dataCell(
                            rowIndex: i,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_cutDecimal(item.ratioN)} : ${_cutDecimal(item.rationD)}',
                                  style: _textStyle(context),
                                ),
                                if (item.ratioN != null && item.rationD != null) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'For every ${_cutDecimal(item.rationD)} shares you currently own,\nyou are entitled to ${_cutDecimal(item.ratioN)} additional right.',
                                    preferBelow: true,
                                    verticalOffset: 16,
                                    child: Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.textSecondaryDark,
                                          light: MyntColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // _dataCell(
                          //   rowIndex: i,
                          //   child: Text(
                          //     item.offerPrice ?? '--',
                          //     style: _textStyle(context),
                          //   ),
                          // ),
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.premiumRs ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                         
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.recordDate ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                          // _dataCell(
                          //   rowIndex: i,
                          //   child: Text(
                          //     item.sourceDate ?? '--',
                          //     style: _textStyle(context),
                          //   ),
                          // ),
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.exRightsDate ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== Split Table ====================
  Widget _buildSplitTable(BuildContext context, List<Split> items) {
    final filtered = _applySearch(items, (item) => item.companyName ?? '');
    if (filtered.isEmpty) {
      return const Center(child: NoDataFound(secondaryEnabled: false));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth - 32;
        final columnWidths = {
          0: shadcn.FixedTableSize(totalWidth * 0.28),
          1: shadcn.FixedTableSize(totalWidth * 0.18),
          2: shadcn.FixedTableSize(totalWidth * 0.18),
          3: shadcn.FixedTableSize(totalWidth * 0.18),
          4: shadcn.FixedTableSize(totalWidth * 0.18),
        };

        return Padding(
          padding: const EdgeInsets.all(16),
          child: shadcn.OutlinedContainer(
            child: Column(
              children: [
                shadcn.Table(
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  columnWidths: columnWidths,
                  rows: [
                    shadcn.TableHeader(cells: [
                      _headerCell('Company name'),
                      _headerCell('Ex Date'),
                      _headerCell('FV From'),
                      _headerCell('FV To'),
                      _headerCell('Record Date'),
                    ]),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    child: shadcn.Table(
                      defaultRowHeight: const shadcn.FixedTableSize(52),
                      columnWidths: columnWidths,
                      rows: takeDisplayed(filtered).asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        return shadcn.TableRow(cells: [
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.companyName ?? '--',
                              style: _textStyle(context,
                                  fontWeight: MyntFonts.semiBold),
                            ),
                          ),
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.exDate ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.fvChangeFrom ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.fvChangeTo ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                          _dataCell(
                            rowIndex: i,
                            child: Text(
                              item.recordDate ?? '--',
                              style: _textStyle(context),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _boardMeetingRow(
    BuildContext context, {
    required int rowIndex,
    required double totalWidth,
    required String companyName,
    required String date,
    required String agenda,
  }) {
    return MouseRegion(
      onEnter: (_) => _hoveredRowIndex.value = rowIndex,
      onExit: (_) => _hoveredRowIndex.value = null,
      child: ValueListenableBuilder<int?>(
        valueListenable: _hoveredRowIndex,
        builder: (context, hoveredIndex, _) {
          final isRowHovered = hoveredIndex == rowIndex;
          return Container(
            color: isRowHovered
                ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary)
                    .withValues(alpha: 0.06)
                : null,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: totalWidth * 0.30,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Text(
                        companyName,
                        style: _textStyle(context,
                            fontWeight: MyntFonts.semiBold),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: totalWidth * 0.15,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Text(date, style: _textStyle(context)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Text(agenda, style: _textStyle(context)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== Helpers ====================

  List<T> _applySearch<T>(List<T> items, String Function(T) getName) {
    if (_searchQuery.isEmpty) return items;
    return items
        .where(
            (item) => getName(item).toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Widget _tooltipText(BuildContext context, String text) {
    return Tooltip(
      richMessage: WidgetSpan(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
      child: Text(
        text,
        style: _textStyle(context),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }


  shadcn.TableCell _headerCell(String label) {
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
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Text(label,
            style: MyntWebTextStyles.tableHeader(context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
                fontWeight: MyntFonts.semiBold)),
      ),
    );
  }

  shadcn.TableCell _dataCell({
    required int rowIndex,
    required Widget child,
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
        onEnter: (_) => _hoveredRowIndex.value = rowIndex,
        onExit: (_) => _hoveredRowIndex.value = null,
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredRowIndex,
          builder: (context, hoveredIndex, _) {
            final isRowHovered = hoveredIndex == rowIndex;
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              color: isRowHovered
                  ? resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary)
                      .withValues(alpha: 0.06)
                  : null,
              child: child,
            );
          },
        ),
      ),
    );
  }

  TextStyle _textStyle(BuildContext context, {FontWeight? fontWeight}) {
    return MyntWebTextStyles.tableCell(
      context,
      darkColor: MyntColors.textPrimaryDark,
      lightColor: MyntColors.textPrimary,
      fontWeight: fontWeight ?? MyntFonts.medium,
    );
  }

  String _cutDecimal(String? value) {
    if (value == null) return '-';
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed.toInt().toString();
    return value;
  }

  // ==================== Date Picker ====================
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCalendarMonth(context, _leftMonth, primaryColor,
                        textColor, secondaryTextColor,
                        onPrev: () => setState(() {
                              _leftMonth = DateTime(
                                  _leftMonth.year, _leftMonth.month - 1);
                              _rightMonth = DateTime(
                                  _leftMonth.year, _leftMonth.month + 1);
                            }),
                        onNext: () => setState(() {
                              _leftMonth = DateTime(
                                  _leftMonth.year, _leftMonth.month + 1);
                              _rightMonth = DateTime(
                                  _leftMonth.year, _leftMonth.month + 1);
                            })),
                    const SizedBox(width: 16),
                    _buildCalendarMonth(context, _rightMonth, primaryColor,
                        textColor, secondaryTextColor,
                        onPrev: () => setState(() {
                              _rightMonth = DateTime(
                                  _rightMonth.year, _rightMonth.month - 1);
                              _leftMonth = DateTime(
                                  _rightMonth.year, _rightMonth.month - 1);
                            }),
                        onNext: () => setState(() {
                              _rightMonth = DateTime(
                                  _rightMonth.year, _rightMonth.month + 1);
                              _leftMonth = DateTime(
                                  _rightMonth.year, _rightMonth.month - 1);
                            })),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPresetChip('Today', () {
                      setState(() {
                        _startDate = DateTime.now();
                        _endDate = DateTime.now();
                        _showDatePickerPopup = false;
                      });
                      _fetchData(force: true);
                    }),
                    _buildPresetChip(
                        'Last 7 days', () => _applyQuickDate(7)),
                    _buildPresetChip(
                        'Last 30 days', () => _applyQuickDate(30)),
                    _buildPresetChip(
                        'Last 90 days', () => _applyQuickDate(90)),
                  ],
                ),
                if (_dateValidationMsg.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _dateValidationMsg,
                    style: MyntWebTextStyles.para(context,
                        darkColor: MyntColors.lossDark,
                        lightColor: MyntColors.loss),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: resolveThemeColor(context,
                dark: MyntColors.cardBorderDark,
                light: MyntColors.cardBorder),
          ),
        ),
        child: Text(
          label,
          style: MyntWebTextStyles.para(context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
              fontWeight: FontWeight.w500),
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
          ...List.generate(6, (weekIndex) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (dayIndex) {
                final dayNum = weekIndex * 7 + dayIndex - firstWeekday + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox(width: 34, height: 34);
                }

                final date = DateTime(month.year, month.month, dayNum);
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final isStart =
                    _tempStartDate != null && _isSameDay(date, _tempStartDate!);
                final isEnd =
                    _tempEndDate != null && _isSameDay(date, _tempEndDate!);
                final isInRange = _tempStartDate != null &&
                    _tempEndDate != null &&
                    date.isAfter(
                        _tempStartDate!.subtract(const Duration(days: 1))) &&
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

                return GestureDetector(
                  onTap: () => _onDateTap(date),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: (isStart || isEnd)
                          ? BoxShape.circle
                          : BoxShape.rectangle,
                      borderRadius:
                          (isStart || isEnd) ? null : BorderRadius.zero,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
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
}
