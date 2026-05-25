import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:intl/intl.dart';

import '../../../../provider/ledger_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/common_search_fields_web.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import '../../../../sharedWidget/custom_back_btn.dart';
import '../../../../sharedWidget/no_data_found.dart';

class PdfDownloadScreenWeb extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const PdfDownloadScreenWeb({super.key, this.onBack});

  @override
  ConsumerState<PdfDownloadScreenWeb> createState() =>
      _PdfDownloadScreenWebState();
}

class _PdfDownloadScreenWebState extends ConsumerState<PdfDownloadScreenWeb> {
  late ScrollController _horizontalScrollController;
  late ScrollController _tableScrollController;

  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Contract',
    'Margin Statement',
    'Weekly Statement',
    'Ledger Detail',
  ];

  // Date range
  late String _fromDate;
  late String _toDate;
  late String _displayDateRange;

  // Sorting
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Date picker overlay state
  bool _showDatePicker = false;
  late DateTime _leftMonth;
  late DateTime _rightMonth;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  bool _selectingEnd = false;
  final GlobalKey _datePickerButtonKey = GlobalKey();

  // List<String> get _quickPresets {
  //   final now = DateTime.now();
  //   final currentFYStart = now.month >= 4 ? now.year : now.year - 1;
  //   return [
  //     'Last 7 days',
  //     'Last 30 days',
  //     'Current FY',
  //     'Last FY',
  //     for (int y = currentFYStart - 2; y >= currentFYStart - 4; y--) '$y',
  //   ];
  // }

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _tableScrollController = ScrollController();
    _initDateRange();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  void _initDateRange() {
    final now = DateTime.now();
    // Financial year: April to March
    final int startYear = now.month >= 4 ? now.year : now.year - 1;
    final startDate = DateTime(startYear, 4, 1);
    _fromDate = DateFormat('dd/MM/yyyy').format(startDate);
    _toDate = DateFormat('dd/MM/yyyy').format(now);
    _displayDateRange =
        '${DateFormat('dd/MM/yyyy').format(startDate)}_to_${DateFormat('dd/MM/yyyy').format(now)}';

    // Initialize calendar months
    _leftMonth = DateTime(startDate.year, startDate.month);
    _rightMonth = DateTime(_leftMonth.year, _leftMonth.month + 1);
  }

  void _fetchData({bool force = false}) {
    final ledger = ref.read(ledgerProvider);
    if (!force && ledger.allPdfDownloads != null) return;
    ledger.fetchAllPdfDownloads(context, _fromDate, _toDate);
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _tableScrollController.dispose();
    _hoveredRowIndex.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ─── Date Picker Overlay ─────────────────────────────────────────────

  void _removeDatePickerOverlay() {
    if (_showDatePicker) {
      setState(() => _showDatePicker = false);
    }
  }

  void _toggleDatePicker(ThemesProvider theme) {
    if (_showDatePicker) {
      _removeDatePickerOverlay();
      return;
    }

    // Parse current dates to initialize temp selection
    _tempStartDate = _parseDateNullable(_fromDate);
    _tempEndDate = _parseDateNullable(_toDate);
    _selectingEnd = false;
    if (_tempStartDate != null) {
      _leftMonth = DateTime(_tempStartDate!.year, _tempStartDate!.month);
    }
    if (_tempEndDate != null) {
      _rightMonth = DateTime(_tempEndDate!.year, _tempEndDate!.month);
    }
    // Ensure right is after left
    if (!_rightMonth.isAfter(_leftMonth)) {
      _rightMonth = DateTime(_leftMonth.year, _leftMonth.month + 1);
    }

    setState(() => _showDatePicker = true);
  }

  // void _handleQuickSelect(String preset) {
  //   final now = DateTime.now();
  //   DateTime start;
  //   DateTime end = now;

  //   switch (preset) {
  //     case 'Last 7 days':
  //       start = now.subtract(const Duration(days: 7));
  //       break;
  //     case 'Last 30 days':
  //       start = now.subtract(const Duration(days: 30));
  //       break;
  //     case 'Current FY':
  //       final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
  //       start = DateTime(fyStartYear, 4, 1);
  //       end = DateTime(fyStartYear + 1, 3, 31);
  //       if (end.isAfter(now)) end = now;
  //       break;
  //     case 'Last FY':
  //       final fyStartYear = now.month >= 4 ? now.year - 1 : now.year - 2;
  //       start = DateTime(fyStartYear, 4, 1);
  //       end = DateTime(fyStartYear + 1, 3, 31);
  //       break;
  //     default:
  //       // Year presets like "2023", "2022", "2021"
  //       final year = int.tryParse(preset);
  //       if (year != null) {
  //         start = DateTime(year, 4, 1);
  //         end = DateTime(year + 1, 3, 31);
  //       } else {
  //         return;
  //       }
  //   }

  //   final startStr =
  //       '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';
  //   final endStr =
  //       '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';
  //   setState(() {
  //     _fromDate = startStr;
  //     _toDate = endStr;
  //     _displayDateRange = '${startStr}_to_$endStr';
  //     _selectedFilter = 'All';
  //   });
  //   ref.read(ledgerProvider).fetchAllPdfDownloads(context, startStr, endStr);
  // }

  bool _isSameDayInline(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDatePickerOverlayInline(BuildContext context) {
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
                    _buildMonthCalendarInline(context, _leftMonth, true),
                    const SizedBox(width: 16),
                    _buildMonthCalendarInline(context, _rightMonth, false),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  // children: _quickPresets.map((preset) {
                  //   return InkWell(
                  //     onTap: () {
                  //       _handleQuickSelect(preset);
                  //       _removeDatePickerOverlay();
                  //     },
                  //     borderRadius: BorderRadius.circular(6),
                  //     child: Container(
                  //       padding: const EdgeInsets.symmetric(
                  //           horizontal: 12, vertical: 8),
                  //       decoration: BoxDecoration(
                  //         borderRadius: BorderRadius.circular(6),
                  //         border: Border.all(color: borderColor),
                  //       ),
                  //       child: Text(
                  //         preset,
                  //         style: MyntWebTextStyles.bodySmall(context,
                  //             color: resolveThemeColor(context,
                  //                 dark: MyntColors.textPrimaryDark,
                  //                 light: MyntColors.textPrimary),
                  //             fontWeight: MyntFonts.medium),
                  //       ),
                  //     ),
                  //   );
                  // }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthCalendarInline(
      BuildContext context, DateTime month, bool isLeft) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstDayWeekday = DateTime(month.year, month.month, 1).weekday % 7;
    final monthName = DateFormat('MMMM yyyy').format(month);

    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondaryColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    if (isLeft) {
                      _leftMonth = DateTime(_leftMonth.year, _leftMonth.month - 1);
                      _rightMonth = DateTime(_leftMonth.year, _leftMonth.month + 1);
                    } else {
                      _rightMonth = DateTime(_rightMonth.year, _rightMonth.month - 1);
                      _leftMonth = DateTime(_rightMonth.year, _rightMonth.month - 1);
                    }
                  });
                },
                child: Icon(Icons.chevron_left, size: 20, color: secondaryColor),
              ),
              Text(monthName,
                  style: MyntWebTextStyles.body(context,
                      color: textColor, fontWeight: MyntFonts.semiBold)),
              InkWell(
                onTap: () {
                  setState(() {
                    if (isLeft) {
                      _leftMonth = DateTime(_leftMonth.year, _leftMonth.month + 1);
                      _rightMonth = DateTime(_leftMonth.year, _leftMonth.month + 1);
                    } else {
                      _rightMonth = DateTime(_rightMonth.year, _rightMonth.month + 1);
                      _leftMonth = DateTime(_rightMonth.year, _rightMonth.month - 1);
                    }
                  });
                },
                child: Icon(Icons.chevron_right, size: 20, color: secondaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: MyntWebTextStyles.caption(context,
                                color: secondaryColor)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          ...List.generate(6, (week) {
            return Row(
              children: List.generate(7, (day) {
                final dayNum = week * 7 + day - firstDayWeekday + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 36));
                }
                final date = DateTime(month.year, month.month, dayNum);
                final today = DateTime.now();
                final isToday = _isSameDayInline(date, today);
                final isFuture = date.isAfter(today);
                final isStart =
                    _tempStartDate != null && _isSameDayInline(date, _tempStartDate!);
                final isEnd =
                    _tempEndDate != null && _isSameDayInline(date, _tempEndDate!);
                final isInRange = _tempStartDate != null &&
                    _tempEndDate != null &&
                    date.isAfter(_tempStartDate!) &&
                    date.isBefore(_tempEndDate!);
                final isSelected = isStart || isEnd;

                return Expanded(
                  child: GestureDetector(
                    onTap: isFuture ? null : () {
                      if (!_selectingEnd || _tempStartDate == null) {
                        setState(() {
                          _tempStartDate = date;
                          _tempEndDate = null;
                          _selectingEnd = true;
                        });
                      } else {
                        DateTime start;
                        DateTime end;
                        if (date.isBefore(_tempStartDate!)) {
                          end = _tempStartDate!;
                          start = date;
                        } else {
                          start = _tempStartDate!;
                          end = date;
                        }
                        _selectingEnd = false;
                        final startStr =
                            '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';
                        final endStr =
                            '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';
                        setState(() {
                          _fromDate = startStr;
                          _toDate = endStr;
                          _displayDateRange = '${startStr}_to_$endStr';
                          _selectedFilter = 'All';
                          _showDatePicker = false;
                        });
                        ref.read(ledgerProvider).fetchAllPdfDownloads(context, startStr, endStr);
                      }
                    },
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor
                            : isInRange
                                ? primaryColor.withValues(alpha: 0.1)
                                : null,
                        shape: isSelected ? BoxShape.circle : BoxShape.rectangle,
                      ),
                      child: Center(
                        child: Text(
                          '$dayNum',
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            color: isFuture
                                ? secondaryColor.withValues(alpha: 0.4)
                                : isSelected
                                    ? Colors.white
                                    : isToday
                                        ? primaryColor
                                        : textColor,
                            fontWeight: isToday || isSelected
                                ? MyntFonts.semiBold
                                : MyntFonts.medium,
                          ),
                        ),
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

  DateTime? _parseDateNullable(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        return DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  // ─── Sorting & Filtering ─────────────────────────────────────────────

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

  List<dynamic> _getFilteredList() {
    final ledger = ref.read(ledgerProvider);
    final data = ledger.allPdfDownloads?.data;
    if (data == null) return [];

    List<dynamic> list = List.from(data);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((doc) {
        final fileName =
            (doc.docFileName?.toString() ?? '').toLowerCase();
        final docType = (doc.docType?.toString() ?? '').toLowerCase();
        final docDate = (doc.docDate?.toString() ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return fileName.contains(query) ||
            docType.contains(query) ||
            docDate.contains(query);
      }).toList();
    }

    // Sorting
    if (_sortColumnIndex != null) {
      list.sort((a, b) {
        int cmp = 0;
        switch (_sortColumnIndex) {
          case 0: // Doc Date
            cmp = _parseDate(a.docDate).compareTo(_parseDate(b.docDate));
            break;
          case 1: // Doc Type
            cmp = (a.docType?.toString() ?? '')
                .compareTo(b.docType?.toString() ?? '');
            break;
          case 2: // Doc FileName
            cmp = (a.docFileName?.toString() ?? '')
                .compareTo(b.docFileName?.toString() ?? '');
            break;
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    return list;
  }

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return DateTime(2000);
    try {
      return DateFormat('dd/MM/yyyy').parse(dateStr);
    } catch (_) {
      return DateTime(2000);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider);
    final theme = ref.watch(themeProvider);
    final filteredList = _getFilteredList();

    return SizedBox.expand(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onBack != null) ...[
                _buildHeaderBar(context),
                const SizedBox(height: 4),
              ],
              // Toolbar: date picker, filter, search
              _buildToolbar(context, theme),
              const SizedBox(height: 16),
              // Table
              Expanded(
                child: Stack(
                  children: [
                    ledger.allPdfLoading
                        ? Center(child: MyntLoader.simple())
                        : _buildTable(context, theme, filteredList),
                    if (_showDatePicker) ...[
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => _removeDatePickerOverlay(),
                          behavior: HitTestBehavior.opaque,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      _buildDatePickerOverlayInline(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context) {
    return Row(
      children: [
        CustomBackBtn(onBack: widget.onBack),
        const SizedBox(width: 8),
        Text(
          'PDF Download',
          style: MyntWebTextStyles.title(context, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, ThemesProvider theme) {
    return Row(
      children: [
        const Spacer(),
        // Date range picker button
        InkWell(
          key: _datePickerButtonKey,
          onTap: () => _toggleDatePicker(theme),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: resolveThemeColor(context,
                    dark: MyntColors.cardBorderDark,
                    light: MyntColors.cardBorder),
              ),
              borderRadius: BorderRadius.circular(8),
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
                  _displayDateRange,
                  style: MyntWebTextStyles.bodySmall(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Filter dropdown
        _buildFilterDropdown(context),
        const SizedBox(width: 12),
        // Search
        SizedBox(
          width: 220,
          height: 36,
          child: MyntSearchTextField(
            controller: _searchController,
            placeholder: 'Search',
            leadingIcon: 'assets/icon/search.svg',
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return InkWell(
          onTap: () => _showFilterPopover(buttonContext),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: resolveThemeColor(context,
                    dark: MyntColors.cardBorderDark,
                    light: MyntColors.cardBorder),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedFilter,
                  style: MyntWebTextStyles.bodySmall(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterPopover(BuildContext buttonContext) {
    shadcn.showPopover(
      context: buttonContext,
      alignment: Alignment.bottomCenter,
      offset: const Offset(0, 8),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(buttonContext).borderRadiusLg,
      ),
      builder: (popoverContext) {
        return Container(
          width: 180,
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
            children: _filterOptions.map((filter) {
              final isSelected = _selectedFilter == filter;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedFilter = filter;
                  });
                  ref.read(ledgerProvider).filterAllPdfDownloads(filter);
                  shadcn.closeOverlay(popoverContext);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
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
                          filter,
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
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTable(
      BuildContext context, ThemesProvider theme, List<dynamic> sortedList) {
    final bool hasData = sortedList.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double docDateWidth = totalWidth * 0.25;
        final double docTypeWidth = totalWidth * 0.30;
        final double docFileNameWidth = totalWidth * 0.45;

        final columnWidths = {
          0: shadcn.FixedTableSize(docDateWidth),
          1: shadcn.FixedTableSize(docTypeWidth),
          2: shadcn.FixedTableSize(docFileNameWidth),
        };

        return Padding(
          padding: EdgeInsets.zero,
          child: shadcn.OutlinedContainer(
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: false,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: totalWidth),
                  child: Column(
                    children: [
                      // Header
                      shadcn.Table(
                        defaultRowHeight: const shadcn.FixedTableSize(50),
                        columnWidths: columnWidths,
                        rows: [
                          shadcn.TableHeader(
                            cells: [
                              _buildHeaderCell('Doc Date', 0),
                              _buildHeaderCell('Doc Type', 1),
                              _buildHeaderCell('Doc FileName', 2),
                            ],
                          ),
                        ],
                      ),
                      // Body
                      Expanded(
                        child: hasData
                            ? SingleChildScrollView(
                                controller: _tableScrollController,
                                child: shadcn.Table(
                                  defaultRowHeight:
                                      const shadcn.FixedTableSize(52),
                                  columnWidths: columnWidths,
                                  rows: [
                                    ...sortedList
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final doc = entry.value;
                                      return _buildDataRow(
                                          context, index, doc);
                                    }),
                                  ],
                                ),
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

  shadcn.TableRow _buildDataRow(
      BuildContext context, int index, dynamic doc) {
    final docDate = doc.docDate?.toString() ?? '';
    final docType = doc.docType?.toString() ?? '';
    final docFileName = doc.docFileName?.toString() ?? '';
    final recno = doc.recno?.toString() ?? '';

    return shadcn.TableRow(
      cells: [
        // Doc Date
        _buildDataCell(
          rowIndex: index,
          columnIndex: 0,
          child: Text(
            docDate,
            style: _getTextStyle(context),
          ),
        ),
        // Doc Type
        _buildDataCell(
          rowIndex: index,
          columnIndex: 1,
          child: Text(
            docType,
            style: _getTextStyle(context),
          ),
        ),
        // Doc FileName (clickable)
        _buildDataCell(
          rowIndex: index,
          columnIndex: 2,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                ref
                    .read(ledgerProvider)
                    .downloadDocForWeb(context, recno, docFileName);
              },
              child: Tooltip(
                message: 'Click to download',
                preferBelow: true,
                verticalOffset: 10,
                child: Text(
                  docFileName,
                  style: _getTextStyle(context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Helper methods ---

  TextStyle _getTextStyle(BuildContext context,
      {Color? color, FontWeight? fontWeight}) {
    return MyntWebTextStyles.tableCell(
      context,
      color: color,
      darkColor: color ?? MyntColors.textPrimaryDark,
      lightColor: color ?? MyntColors.textPrimary,
      fontWeight: fontWeight ?? MyntFonts.medium,
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

  shadcn.TableCell _buildHeaderCell(String label, int columnIndex) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 2;

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
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: _getHeaderStyle(context)),
              if (_sortColumnIndex == columnIndex) const SizedBox(width: 4),
              if (_sortColumnIndex == columnIndex)
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
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 2;

    EdgeInsets cellPadding;
    if (isFirstColumn) {
      cellPadding = const EdgeInsets.fromLTRB(16, 12, 8, 12);
    } else if (isLastColumn) {
      cellPadding = const EdgeInsets.fromLTRB(8, 12, 16, 12);
    } else {
      cellPadding =
          const EdgeInsets.symmetric(horizontal: 6, vertical: 12);
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
          builder: (context, hoveredIndex, _) {
            final isRowHovered = hoveredIndex == rowIndex;
            return Container(
              padding: cellPadding,
              color: isRowHovered
                  ? resolveThemeColor(
                      context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary,
                    ).withValues(alpha: 0.08)
                  : null,
              alignment:
                  alignRight ? Alignment.centerRight : Alignment.centerLeft,
              child: child,
            );
          },
        ),
      ),
    );
  }
}
