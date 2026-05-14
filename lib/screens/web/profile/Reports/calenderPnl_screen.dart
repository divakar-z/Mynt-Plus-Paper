// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/desk_reports_model/calender_pnl_model.dart';
import '../../../../provider/ledger_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/custom_back_btn.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../sharedWidget/scroll_to_load_mixin.dart';
import '../../../../sharedWidget/snack_bar.dart';
import 'charges_dialog_web.dart';
import 'pnl_stats_summary_web.dart';

class CalenderpnlScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const CalenderpnlScreen({super.key, this.onBack});

  @override
  ConsumerState<CalenderpnlScreen> createState() => _CalenderpnlScreenState();
}

class _CalenderpnlScreenState extends ConsumerState<CalenderpnlScreen>
    with ScrollToLoadMixin {
  final ScrollController _tableScrollController = ScrollController();

  @override
  ScrollController get tableScrollController => _tableScrollController;

  bool _isInitialized = false;
  int _selectedSegmentIndex = 0;
  bool _isDateWiseView = true;

  // Expandable date rows
  final Set<DateTime> _expandedDates = {};

  // Hover tracking for table rows
  final ValueNotifier<String?> _hoveredRowKey = ValueNotifier<String?>(null);

  // Date picker state
  bool _showDatePickerPopup = false;
  late DateTime _startDate;
  late DateTime _endDate;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  late DateTime _leftMonth;
  late DateTime _rightMonth;
  String _dateValidationMsg = '';

  @override
  void initState() {
    super.initState();
    initScrollToLoad();
    // Initialize dates from provider
    final lp = ref.read(ledgerProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = lp.startTaxDate;
    _endDate = today;
    _rightMonth = DateTime(today.year, today.month);
    _leftMonth = DateTime(_startDate.year, _startDate.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() {
    if (!_isInitialized) {
      final ledgerprovider = ref.read(ledgerProvider);

      // Re-initialize FY if the provider was cleared (e.g. on account switch)
      if (ledgerprovider.formattedStartDate.isEmpty) {
        ledgerprovider.setFinancialYear('');
        _startDate = ledgerprovider.startTaxDate;
      }

      final startFormatted = DateFormat('dd/MM/yyyy').format(_startDate);
      final todayFormatted = DateFormat('dd/MM/yyyy').format(_endDate);

      // Sync provider dates with the screen's local state
      ledgerprovider.startTaxDate = _startDate;
      ledgerprovider.endTaxDate = _endDate;
      ledgerprovider.formattedStartDate = startFormatted;
      ledgerprovider.formattedendDate = todayFormatted;

      if (!ledgerprovider.hasDataForAllSegments) {
        ledgerprovider.fetchDataForAllSegmentsIfEmpty(
          context,
          startFormatted,
          todayFormatted,
        );
      }
      ledgerprovider.fetchsharingdata(
        startFormatted,
        todayFormatted,
        ledgerprovider.selectedSegment,
        context,
      );
      ledgerprovider.fetchChargesForAllCalendarSegments(context);
      // Sync selected segment index
      final idx = ledgerprovider.availableSegments
          .indexOf(ledgerprovider.selectedSegment);
      if (idx >= 0) _selectedSegmentIndex = idx;
      _isInitialized = true;
    }
  }


  @override
  void dispose() {
    disposeScrollToLoad();
    _tableScrollController.dispose();
    _hoveredRowKey.dispose();
    super.dispose();
  }

  DateTime _getFinancialYearStart(DateTime date) {
    final startYear = date.month < 4 ? date.year - 1 : date.year;
    return DateTime(startYear, 4, 1);
  }

  DateTime _getFinancialYearEnd(DateTime date) {
    final endYear = date.month < 4 ? date.year : date.year + 1;
    return DateTime(endYear, 3, 31);
  }

  void _toggleDatePicker() {
    setState(() {
      if (!_showDatePickerPopup) {
        _tempStartDate = _startDate;
        _tempEndDate = _endDate;
        _dateValidationMsg = '';
        _rightMonth = DateTime(_endDate.year, _endDate.month);
        _leftMonth = DateTime(_startDate.year, _startDate.month);
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
        _expandedDates.clear();
        _applyDateRange();
      }
    });
  }

  void _applyFYPreset(int startYear) {
    setState(() {
      _startDate = DateTime(startYear, 4, 1);
      _endDate = DateTime(startYear + 1, 3, 31);
      _leftMonth = DateTime(startYear, 4);
      _rightMonth = DateTime(startYear + 1, 3);
      _showDatePickerPopup = false;
      _expandedDates.clear();
    });
    _applyDateRange();
  }

  void _applyDateRange() {
    final lp = ref.read(ledgerProvider);
    final from = DateFormat('dd/MM/yyyy').format(_startDate);
    final to = DateFormat('dd/MM/yyyy').format(_endDate);

    // Clear existing data first (this resets dates internally)
    lp.clearCalendarPnLData();

    // Set provider dates AFTER clearing so they aren't overwritten
    lp.startTaxDate = _startDate;
    lp.endTaxDate = _endDate;
    lp.formattedStartDate = from;
    lp.formattedendDate = to;

    // Refetch with the user-selected date range
    lp.fetchDataForAllSegmentsIfEmpty(context, from, to);
    lp.fetchsharingdata(from, to, lp.selectedSegment, context);
    lp.fetchChargesForAllCalendarSegments(context);
  }

  void _onSegmentTap(int index, LDProvider ledgerprovider) {
    final selectedSegment = ledgerprovider.availableSegments[index];
    setState(() {
      _selectedSegmentIndex = index;
      _expandedDates.clear();
      displayedItemCount = ScrollToLoadMixin.itemsPerPage;
    });
    ledgerprovider.switchToSegment(
      context,
      selectedSegment,
      ledgerprovider.formattedStartDate,
      ledgerprovider.formattedendDate,
    );
    ledgerprovider.fetchsharingdata(
      ledgerprovider.formattedStartDate,
      ledgerprovider.formattedendDate,
      selectedSegment,
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledgerprovider = ref.watch(ledgerProvider);
    final theme = ref.watch(themeProvider);
    final isLoading = ledgerprovider
            .isCalendarPnlLoadingForSegment(ledgerprovider.selectedSegment) ||
        (ledgerprovider.calenderpnlAllData == null &&
            !ledgerprovider
                .hasDataForSegment(ledgerprovider.selectedSegment));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme, ledgerprovider),
            Expanded(
              child: Stack(
                children: [
                  isLoading
                      ? Center(child: MyntLoader.simple())
                      : ledgerprovider.calenderpnlAllData == null
                          ? const Center(
                            child: NoDataFound(secondaryEnabled: false))
                        : _buildBody(context, theme, ledgerprovider),
                  // Date picker overlay
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
            child: Text(
              'P&L Summary',
              style: MyntWebTextStyles.title(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.semiBold),
            ),
          ),
          // P&L Stats button
          if (ledgerprovider.calenderpnlAllData != null && ledgerprovider.selectedSegment != "Equity")
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: () => showPnlStatsSummaryDialog(
                  context,
                  data: ledgerprovider.calenderpnlAllData!,
                  segment: ledgerprovider.selectedSegment,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  // margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
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
                        Icons.bar_chart_rounded,
                        size: 16,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Analyse',
                        style: MyntWebTextStyles.para(context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
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
        ],
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, ThemesProvider theme, LDProvider ledgerprovider) {
    final data = ledgerprovider.calenderpnlAllData;
    final bool isCommodity = ledgerprovider.selectedSegment == "Commodity";

    // Build sorted dates
    List<DateTime> sortedDates;
    if (isCommodity && data?.dateWise != null) {
      sortedDates = (data!.dateWise as Map)
          .keys
          .map((dateStr) => DateTime.parse(dateStr))
          .where((date) =>
              !date.isBefore(ledgerprovider.startTaxDate) &&
              !date.isAfter(ledgerprovider.endTaxDate))
          .toList()
        ..sort((a, b) => b.compareTo(a));
    } else {
      sortedDates = ledgerprovider.grouped.keys
          .where((date) =>
              !date.isBefore(ledgerprovider.startTaxDate) &&
              !date.isAfter(ledgerprovider.endTaxDate))
          .toList()
        ..sort((a, b) => b.compareTo(a));
    }

    final double netValue = (data?.realized ?? 0.0) - (data?.totalCharges ?? 0.0);

    return SingleChildScrollView(
      controller: _tableScrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segment tabs
          _buildSegmentTabs(context, ledgerprovider),
          const SizedBox(height: 12),
          // Summary cards + share card
          _buildSummaryCards(context, data, netValue, ledgerprovider),
          const SizedBox(height: 16),
          // Calendar section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _WebCalendarTabs(
              heatmapData: isCommodity
                  ? _buildHeatmapForCommodity(ledgerprovider)
                  : ledgerprovider.heatmapData,
              monthlyPnL: isCommodity
                  ? _buildMonthlyPnLForCommodity(ledgerprovider)
                  : ledgerprovider.monthlyPnL,
              isMonthly: ledgerprovider.isMonthly,
              startFY: _getFinancialYearStart(ledgerprovider.startTaxDate),
              endFY: _getFinancialYearEnd(ledgerprovider.startTaxDate),
              selectedMonth: ledgerprovider.selectedMonth,
              onTabChanged: (isMonthly) => ledgerprovider.setTab(isMonthly),
              onMonthSelected: (month) {
                ledgerprovider.setSelectedMonth(month);
                ledgerprovider.setTab(false);
              },
              onMonthChanged: (month) =>
                  ledgerprovider.setSelectedMonth(month),
            ),
          ),
          const SizedBox(height: 16),
          // Date Wise / Script Wise tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildViewTabs(context),
          ),
          const SizedBox(height: 16),
          // Table content based on selected tab
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _isDateWiseView
                ? _buildDateWiseSection(
                    context, sortedDates, ledgerprovider, isCommodity)
                : _buildScriptWiseSection(
                    context, sortedDates, ledgerprovider, isCommodity),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- Segment Tabs ---
  Widget _buildSegmentTabs(BuildContext context, LDProvider ledgerprovider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ledgerprovider.availableSegments.asMap().entries.map((entry) {
          final index = entry.key;
          final segment = entry.value;
          final isSelected = index == _selectedSegmentIndex;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _onSegmentTap(index, ledgerprovider),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: isSelected
                      ? (isDarkMode(context)
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05))
                      : Colors.transparent,
                ),
                child: Text(
                  segment,
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight:
                        isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                  ).copyWith(
                    color: isSelected
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

  // --- Summary Cards ---
  Widget _buildSummaryCards(
      BuildContext context, CalenderpnlModel? data, double netValue, LDProvider ledgerprovider) {
    final realized = data?.realized ?? 0.0;
    final unrealized = data?.unrealized ?? 0.0;
    final charges = data?.totalCharges ?? 0.0;
    final hasData = data?.data != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          // 5 columns for wide (>=1000), 3 for medium (>=600), 2 for narrow
          final int columns;
          if (hasData && w >= 1000) {
            columns = 5;
          } else if (w >= 600) {
            columns = hasData ? 3 : 4;
          } else {
            columns = 2;
          }
          final spacing = 12.0;
          final totalSpacing = spacing * (columns - 1);
          final cardWidth = (w - totalSpacing) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              SizedBox(
                width: cardWidth, height: 115,
                child: _buildSummaryCard(context, 'Realised P&L', realized),
              ),
              SizedBox(
                width: cardWidth, height: 115,
                child: _buildSummaryCard(context, 'Unrealised P&L', unrealized),
              ),
              SizedBox(
                width: cardWidth, height: 115,
                child: _buildSummaryCard(context, 'Charges & Taxes', charges,
                    isNeutral: true, onTap: () => showChargesDialog(context, ref: ref)),
              ),
              SizedBox(
                width: cardWidth, height: 115,
                child: _buildSummaryCard(context, 'Net Realised P&L', netValue),
              ),
              if (hasData)
                SizedBox(
                  width: cardWidth, height: 115,
                  child: _buildShareCard(context, ledgerprovider),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, String label, double value,
      {bool isNeutral = false, VoidCallback? onTap}) {
    final valueColor = isNeutral || value == 0
        ? resolveThemeColor(context,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)
        : _getPnlColor(context, value);

    return shadcn.Theme(
      data: shadcn.Theme.of(context).copyWith(radius: () => 0.3),
      child: MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
          child: shadcn.Card(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const SizedBox(width: 1),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: MyntWebTextStyles.bodySmall(
                                  context,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary),
                                  fontWeight: MyntFonts.medium,
                                ),
                              ),
                            ),
                            if (onTap != null)
                              Icon(
                                Icons.open_in_new,
                                size: 13,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                              ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _formatAmount(value),
                          style: MyntWebTextStyles.head(
                            context,
                            color: valueColor,
                            fontWeight: MyntFonts.medium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Share Card ---
  Widget _buildShareCard(BuildContext context, LDProvider ledgerprovider) {
    return shadcn.Theme(
      data: shadcn.Theme.of(context).copyWith(radius: () => 0.3),
      child: shadcn.Card(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'P&L verified by Zebu',
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Share to Everyone',
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      final value = !ledgerprovider.notsharing;
                      ledgerprovider.sharingornotsharing(value);
                      if (value == false) {
                        // Turning ON — always send fresh response + segment
                        ledgerprovider.sendsharing(
                          ledgerprovider.ucode,
                          ledgerprovider.formattedStartDate,
                          ledgerprovider.formattedendDate,
                          ledgerprovider.calenderpnlAllData!.fullresponse!,
                          ledgerprovider.notsharing,
                          ledgerprovider.selectedSegment,
                          context,
                        );
                      } else {
                        // Turning OFF — ucode only
                        ledgerprovider.sendsharing(
                          ledgerprovider.ucode,
                          "",
                          "",
                          "",
                          ledgerprovider.notsharing,
                          "",
                          context,
                        );
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: !ledgerprovider.notsharing
                            ? resolveThemeColor(context,
                                dark: MyntColors.secondary,
                                light: MyntColors.primary)
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 200),
                            left: !ledgerprovider.notsharing ? 18 : 2,
                            top: 2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      if (ledgerprovider.notsharing == false) {
                        _showSharingDialog(context, ledgerprovider);
                      } else {
                        warningMessage(context, 'Sharing is not on');
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.share_outlined,
                      size: 20,
                      color: ledgerprovider.notsharing == false
                          ? resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSharingDialog(BuildContext context, LDProvider ledgerprovider) {
    const sharingUrl = 'https://app.mynt.in/dailypnl?ucode=';
    final secondaryColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: resolveThemeColor(context,
              dark: MyntColors.cardDark, light: MyntColors.card),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Grab your URL',
                                style: MyntWebTextStyles.head(context,
                                    darkColor: MyntColors.textPrimaryDark,
                                    lightColor: MyntColors.textPrimary,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                                'Click to share your triumphant journey.',
                                style: MyntWebTextStyles.caption(context,
                                    color: secondaryColor)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(dialogContext),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close,
                              size: 24, color: secondaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: borderColor),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Share this link Or copy link',
                          style: MyntWebTextStyles.bodySmall(context,
                              color: secondaryColor)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                                color: resolveThemeColor(context,
                                    dark: MyntColors.cardDark
                                        .withValues(alpha: 0.5),
                                    light: const Color(0xffF1F3F8)),
                              ),
                              child: Text(
                                '$sharingUrl${ledgerprovider.ucode}',
                                overflow: TextOverflow.ellipsis,
                                style: MyntWebTextStyles.bodySmall(
                                    context,
                                    color: textColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(
                                  text:
                                      '$sharingUrl${ledgerprovider.ucode}'));
                              successMessage(
                                  dialogContext, 'Text copied');
                              Navigator.pop(dialogContext);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: Icon(Icons.copy_rounded,
                                  size: 18, color: textColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              final twitterUrl =
                                  "https://twitter.com/intent/tweet?text=Excited about my recent trading triumph using Zebu—profits surging! Skillful moves on the Zebu app have significantly boosted my success !&url=$sharingUrl${ledgerprovider.ucode}&hashtags=Traders #Traders via @zebuetrade ";
                              if (await canLaunchUrl(
                                  Uri.parse(twitterUrl))) {
                                await launchUrl(Uri.parse(twitterUrl),
                                    mode:
                                        LaunchMode.externalApplication);
                                Navigator.pop(dialogContext);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: Center(
                                child: Text('X',
                                    style: TextStyle(
                                        color: textColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Date Wise / Script Wise Tabs ---
  Widget _buildViewTabs(BuildContext context) {
    return Row(
      children: [
        _buildViewTab('Date Wise', _isDateWiseView),
        const SizedBox(width: 24),
        _buildViewTab('Script Wise', !_isDateWiseView),
      ],
    );
  }

  Widget _buildViewTab(String label, bool isActive) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isDateWiseView = label == 'Date Wise';
            displayedItemCount = ScrollToLoadMixin.itemsPerPage;
          });
        },
        child: Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive
                    ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: MyntWebTextStyles.body(
              context,
              fontWeight: isActive ? MyntFonts.semiBold : MyntFonts.medium,
            ).copyWith(
              color: isActive
                  ? resolveThemeColor(context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary)
                  : resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  // --- Script Wise Section ---
  Widget _buildScriptWiseSection(BuildContext context, List<DateTime> sortedDates,
      LDProvider ledgerprovider, bool isCommodity) {
    // Aggregate trades by symbol
    final Map<String, _ScriptWiseRowData> scriptMap = {};

    if (isCommodity && ledgerprovider.calenderpnlAllData?.symbolWise != null) {
      // Commodity payload shape (mirrors Vue's commodity Script Wise
      // mapping at Daily_pnl.vue:2823-2831 — `details.sum` is spread into
      // the row and `details.realised_pnl` comes from outside `sum`):
      //   symbolWise: {
      //     "<symbol>": {
      //        realised_pnl,
      //        sum: { total_buy_qty, total_buy_rate, total_sell_qty,
      //               total_sell_rate, Updated_NETQTY, CLOSING_PRICE, ... },
      //        trades: [...]
      //     }
      //   }
      double readNum(Map? m, List<String> keys) {
        if (m == null) return 0;
        for (final k in keys) {
          final v = m[k];
          if (v == null) continue;
          if (v is num) return v.toDouble();
          if (v is String) {
            final parsed = double.tryParse(v);
            if (parsed != null) return parsed;
          }
        }
        return 0;
      }

      // Reads a value from `sum` first, then falls back to the symbol-level
      // map. Backend sometimes hoists fields up to the symbol level.
      double readField(Map? sum, Map symbolData, List<String> keys) {
        final fromSum = readNum(sum, keys);
        if (fromSum != 0) return fromSum;
        return readNum(symbolData, keys);
      }

      (ledgerprovider.calenderpnlAllData!.symbolWise as Map)
          .forEach((symbol, symbolData) {
        if (symbolData is! Map) return;
        final sum = symbolData['sum'] is Map
            ? symbolData['sum'] as Map
            : null;

        final buyQty = readField(
            sum, symbolData, ['total_buy_qty', 'BUYQTY', 'buy_qty']);
        final buyRate = readField(sum, symbolData, [
          'total_buy_rate',
          'avg_buy_rate',
          'BUYRATE',
          'buy_rate',
        ]);
        final sellQty = readField(
            sum, symbolData, ['total_sell_qty', 'SALEQTY', 'sell_qty']);
        final sellRate = readField(sum, symbolData, [
          'total_sell_rate',
          'avg_sell_rate',
          'SALERATE',
          'sell_rate',
        ]);
        final netQty = readField(
            sum, symbolData, ['Updated_NETQTY', 'NETQTY', 'net_qty']);
        final closePrice = readField(
            sum, symbolData, ['CLOSING_PRICE', 'CL_PRICE', 'close_price']);
        final realisedPnl = readNum(
            symbolData, ['realised_pnl', 'realisedpnl', 'PL_AMT']);

        final buyAmt = readField(sum, symbolData,
            ['total_buy_amt', 'BUYAMT', 'buy_amt', 'BUY_AMT']);
        final sellAmt = readField(sum, symbolData,
            ['total_sell_amt', 'SALEAMT', 'sell_amt', 'SALE_AMT']);

        final resolvedBuyRate = buyRate != 0
            ? buyRate
            : (buyQty > 0 && buyAmt != 0 ? buyAmt / buyQty : 0.0);
        final resolvedSellRate = sellRate != 0
            ? sellRate
            : (sellQty > 0 && sellAmt != 0 ? sellAmt / sellQty : 0.0);
        final resolvedBuyAmt = buyAmt != 0 ? buyAmt : buyQty * resolvedBuyRate;
        final resolvedSellAmt =
            sellAmt != 0 ? sellAmt : sellQty * resolvedSellRate;

        scriptMap[symbol] = _ScriptWiseRowData(
          symbol: symbol,
          buyQty: buyQty,
          buyRate: resolvedBuyRate,
          buyAmt: resolvedBuyAmt,
          sellQty: sellQty,
          sellRate: resolvedSellRate,
          sellAmt: resolvedSellAmt,
          netQty: netQty,
          closePrice: closePrice,
          realisedPnl: realisedPnl,
        );
      });
    } else {
      // Aggregate from trades list for equity/FNO
      for (final dateKey in sortedDates) {
        final trades = ledgerprovider.grouped[dateKey] ?? [];
        for (final trade in trades) {
          final symbol = trade.sCRIPSYMBOL ?? '';
          if (symbol.isEmpty) continue;

          final existing = scriptMap[symbol];
          final buyQty = trade.safeBuyQty.toDouble();
          final buyRate = trade.safeBuyRate;
          final buyAmt = double.tryParse(trade.bAMT ?? '0') ?? (buyQty * buyRate);
          final sellQty = trade.safeSellQty.toDouble();
          final sellRate = trade.safeSellRate;
          final sellAmt = double.tryParse(trade.sAMT ?? '0') ?? (sellQty * sellRate);
          final netQty = trade.safeNetQty.toDouble();
          final closePrice = double.tryParse(trade.cLOSINGPRICE ?? '0') ?? 0;
          final pnl = trade.safeRealisedPnl;

          if (existing != null) {
            scriptMap[symbol] = _ScriptWiseRowData(
              symbol: symbol,
              buyQty: existing.buyQty + buyQty,
              buyRate: 0, // recalculate below
              buyAmt: existing.buyAmt + buyAmt,
              sellQty: existing.sellQty + sellQty,
              sellRate: 0, // recalculate below
              sellAmt: existing.sellAmt + sellAmt,
              netQty: existing.netQty + netQty,
              closePrice: closePrice,
              realisedPnl: existing.realisedPnl + pnl,
            );
          } else {
            scriptMap[symbol] = _ScriptWiseRowData(
              symbol: symbol,
              buyQty: buyQty,
              buyRate: buyRate,
              buyAmt: buyAmt,
              sellQty: sellQty,
              sellRate: sellRate,
              sellAmt: sellAmt,
              netQty: netQty,
              closePrice: closePrice,
              realisedPnl: pnl,
            );
          }
        }
      }
      // Recalculate avg rates
      for (final key in scriptMap.keys) {
        final row = scriptMap[key]!;
        scriptMap[key] = _ScriptWiseRowData(
          symbol: row.symbol,
          buyQty: row.buyQty,
          buyRate: row.buyQty > 0 ? row.buyAmt / row.buyQty : 0,
          buyAmt: row.buyAmt,
          sellQty: row.sellQty,
          sellRate: row.sellQty > 0 ? row.sellAmt / row.sellQty : 0,
          sellAmt: row.sellAmt,
          netQty: row.netQty,
          closePrice: row.closePrice,
          realisedPnl: row.realisedPnl,
        );
      }
    }

    final scriptRows = scriptMap.values.toList();

    if (scriptRows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 30),
          child: NoDataFound(secondaryEnabled: false),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final columnWidths = {
          0: shadcn.FixedTableSize(totalWidth * 0.22),
          1: shadcn.FixedTableSize(totalWidth * 0.10),
          2: shadcn.FixedTableSize(totalWidth * 0.11),
          3: shadcn.FixedTableSize(totalWidth * 0.10),
          4: shadcn.FixedTableSize(totalWidth * 0.11),
          5: shadcn.FixedTableSize(totalWidth * 0.10),
          6: shadcn.FixedTableSize(totalWidth * 0.12),
          7: shadcn.FixedTableSize(totalWidth * 0.14),
        };

        return shadcn.OutlinedContainer(
          child: shadcn.Table(
            defaultRowHeight: const shadcn.FixedTableSize(57),
            columnWidths: columnWidths,
            rows: [
              shadcn.TableHeader(
                cells: [
                  _buildTableHeaderCell('Script Symbol'),
                  _buildTableHeaderCell('Buy qty', alignRight: true),
                  _buildTableHeaderCell('Buy rate', alignRight: true),
                  _buildTableHeaderCell('Sell qty', alignRight: true),
                  _buildTableHeaderCell('Sell rate', alignRight: true),
                  _buildTableHeaderCell('Net Qty', alignRight: true),
                  _buildTableHeaderCell('Close Price', alignRight: true),
                  _buildTableHeaderCell('Realisedpnl', alignRight: true),
                ],
              ),
              ...takeDisplayed(scriptRows).asMap().entries.map((entry) {
                final row = entry.value;
                final rowKey = 'script_${entry.key}_${row.symbol}';

                return shadcn.TableRow(
                  cells: [
                    _buildTableDataCell(
                      rowKey: rowKey,
                      child: Tooltip(
                        message: row.symbol,
                        child: GestureDetector(
                          onTap: () => _showSymbolPnlDialog(context, row.symbol, row.symbol),
                          child: Text(
                            row.symbol,
                            style: _getTextStyle(context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                    ),
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Text(
                        row.buyQty.toStringAsFixed(0),
                        style: _getTextStyle(context),
                      ),
                    ),
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            row.buyRate.toStringAsFixed(2),
                            style: _getTextStyle(context),
                          ),
                          Text(
                            row.buyAmt.toStringAsFixed(2),
                            style: MyntWebTextStyles.caption(context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Text(
                        row.sellQty.toStringAsFixed(0),
                        style: _getTextStyle(context),
                      ),
                    ),
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            row.sellRate.toStringAsFixed(2),
                            style: _getTextStyle(context),
                          ),
                          Text(
                            row.sellAmt.toStringAsFixed(2),
                            style: MyntWebTextStyles.caption(context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Text(
                        row.netQty.toStringAsFixed(0),
                        style: _getTextStyle(context),
                      ),
                    ),
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Text(
                        row.closePrice.toStringAsFixed(2),
                        style: _getTextStyle(context),
                      ),
                    ),
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Text(
                        _formatAmount(row.realisedPnl),
                        style: _getTextStyle(context,
                            color: _getPnlColor(context, row.realisedPnl)),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // --- Date-wise Section ---
  Widget _buildDateWiseSection(BuildContext context, List<DateTime> sortedDates,
      LDProvider ledgerprovider, bool isCommodity) {
    if (sortedDates.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 30),
          child: NoDataFound(secondaryEnabled: false),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final columnWidths = isCommodity
            ? {
                0: shadcn.FixedTableSize(totalWidth * 0.50), // Arrow + Date + Count
                1: shadcn.FixedTableSize(totalWidth * 0.25), // Unrealised P&L
                2: shadcn.FixedTableSize(totalWidth * 0.25), // Realised P&L
              }
            : {
                0: shadcn.FixedTableSize(totalWidth * 0.60), // Arrow + Date + Count
                1: shadcn.FixedTableSize(totalWidth * 0.40), // P&L
              };

        // Build rows data
        final List<_DateRowData> dateRows = sortedDates.map((dateKey) {
          List<TradeData> tradesForDate;
          double totalRealisedPnl;
          double? totalUnrealisedPnl;

          if (isCommodity) {
            final dateStr =
                "${dateKey.year}-${dateKey.month.toString().padLeft(2, '0')}-${dateKey.day.toString().padLeft(2, '0')}";
            final dateData = (ledgerprovider.calenderpnlAllData!.dateWise
                as Map)[dateStr];
            tradesForDate = dateData != null && dateData['trades'] != null
                ? (dateData['trades'] as List)
                    .map((trade) => TradeData.fromCommodityJson(trade))
                    .toList()
                : [];
            totalRealisedPnl =
                dateData?['realised_pnl']?.toDouble() ?? 0.0;
            totalUnrealisedPnl =
                dateData?['total_unrealized_pnl']?.toDouble() ?? 0.0;
          } else {
            tradesForDate = ledgerprovider.grouped[dateKey] ?? [];
            totalRealisedPnl = tradesForDate.fold(
              0.0,
              (sum, item) =>
                  sum + (double.tryParse(item.realisedpnl ?? '0') ?? 0.0),
            );
          }

          final dateString =
              '${dateKey.year}-${dateKey.month.toString().padLeft(2, '0')}-${dateKey.day.toString().padLeft(2, '0')}';
          final isExpanded = _expandedDates.contains(dateKey);

          return _DateRowData(
            dateKey: dateKey,
            tradesForDate: tradesForDate,
            totalRealisedPnl: totalRealisedPnl,
            totalUnrealisedPnl: totalUnrealisedPnl,
            dateString: dateString,
            isExpanded: isExpanded,
          );
        }).toList();

        return shadcn.OutlinedContainer(
          child: Column(
            children: [
              // Header row as shadcn Table
              shadcn.Table(
                defaultRowHeight: const shadcn.FixedTableSize(57),
                columnWidths: columnWidths,
                rows: [
                  shadcn.TableHeader(
                    cells: isCommodity
                        ? [
                            _buildDateSectionHeaderCell('Date',
                                isSecondary: true),
                            _buildDateSectionHeaderCell('Unrealised P&L',
                                alignRight: true, isSecondary: true),
                            _buildDateSectionHeaderCell('Realised P&L',
                                alignRight: true, isSecondary: true),
                          ]
                        : [
                            _buildDateSectionHeaderCell('Date Wise P&L'),
                            _buildDateSectionHeaderCell(
                                '${sortedDates.length} Days',
                                alignRight: true,
                                isSecondary: true),
                          ],
                  ),
                ],
              ),
              // Data rows
              ...takeDisplayed(dateRows).asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;

                return Column(
                  children: [
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: resolveThemeColor(context,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider),
                    ),
                    // Date row as shadcn Table
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (row.isExpanded) {
                            _expandedDates.remove(row.dateKey);
                          } else {
                            _expandedDates.add(row.dateKey);
                          }
                        });
                      },
                      child: shadcn.Table(
                        defaultRowHeight: const shadcn.FixedTableSize(50),
                        columnWidths: columnWidths,
                        rows: [
                          shadcn.TableRow(
                            cells: [
                              _buildDateRowCell(
                                rowIndex: index,
                                child: Row(
                                  children: [
                                    Icon(
                                      row.isExpanded
                                          ? Icons.keyboard_arrow_down
                                          : Icons.keyboard_arrow_right,
                                      size: 20,
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.textSecondaryDark,
                                          light: MyntColors.textSecondary),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      row.dateString,
                                      style: MyntWebTextStyles.body(context,
                                          darkColor: MyntColors.textPrimaryDark,
                                          lightColor: MyntColors.textPrimary,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: resolveThemeColor(context,
                                                dark: MyntColors.textSecondaryDark,
                                                light: MyntColors.textSecondary)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${row.tradesForDate.length}',
                                        style: MyntWebTextStyles.caption(context,
                                            darkColor: MyntColors.textSecondaryDark,
                                            lightColor: MyntColors.textSecondary,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (row.totalUnrealisedPnl != null)
                                _buildDateRowCell(
                                  rowIndex: index,
                                  alignRight: true,
                                  child: Text(
                                    _formatAmount(row.totalUnrealisedPnl!),
                                    style: MyntWebTextStyles.body(context,
                                        darkColor: _getPnlColor(context,
                                            row.totalUnrealisedPnl!),
                                        lightColor: _getPnlColor(context,
                                            row.totalUnrealisedPnl!),
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              _buildDateRowCell(
                                rowIndex: index,
                                alignRight: true,
                                child: Text(
                                  _formatAmount(row.totalRealisedPnl),
                                  style: MyntWebTextStyles.body(context,
                                      darkColor: _getPnlColor(
                                          context, row.totalRealisedPnl),
                                      lightColor: _getPnlColor(
                                          context, row.totalRealisedPnl),
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Expanded trade table
                    if (row.isExpanded && row.tradesForDate.isNotEmpty)
                      _buildTradeTable(context, row.tradesForDate),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // --- Date section header cell ---
  shadcn.TableCell _buildDateSectionHeaderCell(String label,
      {bool alignRight = false, bool isSecondary = false}) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          style: isSecondary
              ? MyntWebTextStyles.para(context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary)
              : MyntWebTextStyles.body(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // --- Date row cell ---
  shadcn.TableCell _buildDateRowCell({
    required int rowIndex,
    required Widget child,
    bool alignRight = false,
  }) {
    return shadcn.TableCell(
      theme: shadcn.TableCellTheme(
        border: const shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
        backgroundColor: shadcn.WidgetStatePropertyAll(
          isDarkMode(context)
              ? MyntColors.transparent
              : MyntColors.overlayBg,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
  }

  // --- Date Picker Overlay ---
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

    // Generate FY presets
    final now = DateTime.now();
    final currentFYStart = now.month < 4 ? now.year - 1 : now.year;

    // Active FY window — restricts which months/days are reachable
    final fyStart = _getFinancialYearStart(_startDate);
    final fyEnd = _getFinancialYearEnd(_startDate);
    final fyStartMonth = DateTime(fyStart.year, fyStart.month);
    final fyEndMonth = DateTime(fyEnd.year, fyEnd.month);

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
                        final newLeft = DateTime(
                            _leftMonth.year, _leftMonth.month - 1);
                        if (newLeft.isBefore(fyStartMonth)) return;
                        setState(() {
                          _leftMonth = newLeft;
                          _rightMonth = DateTime(
                              _leftMonth.year, _leftMonth.month + 1);
                        });
                      },
                      onNext: () {
                        final newLeft = DateTime(
                            _leftMonth.year, _leftMonth.month + 1);
                        final newRight = DateTime(
                            newLeft.year, newLeft.month + 1);
                        if (newRight.isAfter(fyEndMonth)) return;
                        setState(() {
                          _leftMonth = newLeft;
                          _rightMonth = newRight;
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
                        final newRight = DateTime(
                            _rightMonth.year, _rightMonth.month - 1);
                        final newLeft = DateTime(
                            newRight.year, newRight.month - 1);
                        if (newLeft.isBefore(fyStartMonth)) return;
                        setState(() {
                          _rightMonth = newRight;
                          _leftMonth = newLeft;
                        });
                      },
                      onNext: () {
                        final newRight = DateTime(
                            _rightMonth.year, _rightMonth.month + 1);
                        if (newRight.isAfter(fyEndMonth)) return;
                        setState(() {
                          _rightMonth = newRight;
                          _leftMonth = DateTime(
                              _rightMonth.year, _rightMonth.month - 1);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Quick presets
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPresetChip(
                      'Current FY',
                      () => _applyFYPreset(currentFYStart),
                      isActive: fyStart.year == currentFYStart,
                    ),
                    _buildPresetChip(
                      'Last FY',
                      () => _applyFYPreset(currentFYStart - 1),
                      isActive: fyStart.year == currentFYStart - 1,
                    ),
                    // Year presets going back
                    for (int y = currentFYStart - 2; y >= currentFYStart - 4; y--)
                      _buildPresetChip(
                        '$y',
                        () => _applyFYPreset(y),
                        isActive: fyStart.year == y,
                      ),
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

  Widget _buildPresetChip(String label, VoidCallback onTap,
      {bool isActive = false}) {
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final borderColor = isActive
        ? primaryColor
        : resolveThemeColor(context,
            dark: MyntColors.cardBorderDark,
            light: MyntColors.cardBorder);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isActive ? primaryColor.withValues(alpha: 0.1) : null,
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: MyntWebTextStyles.para(context,
              darkColor: isActive
                  ? MyntColors.primaryDark
                  : MyntColors.textPrimaryDark,
              lightColor:
                  isActive ? MyntColors.primary : MyntColors.textPrimary,
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
    final fyStart = _getFinancialYearStart(_startDate);
    final fyEnd = _getFinancialYearEnd(_startDate);

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
                final isOutsideFY =
                    date.isBefore(fyStart) || date.isAfter(fyEnd);
                final isDisabled = isFuture || isOutsideFY;
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

                if (isDisabled) {
                  dayTextColor =
                      secondaryTextColor.withValues(alpha: 0.4);
                }

                return GestureDetector(
                  onTap: isDisabled ? null : () => _onDateTap(date),
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

  // --- Trade Table (shadcn) ---
  Widget _buildTradeTable(BuildContext context, List<TradeData> trades) {
    final isCommodity =
        ref.read(ledgerProvider).selectedSegment == "Commodity";
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        // Commodity: 9 columns (with Unrealised P&L); others: 8 columns.
        final columnWidths = isCommodity
            ? {
                0: shadcn.FixedTableSize(totalWidth * 0.22),
                1: shadcn.FixedTableSize(totalWidth * 0.08),
                2: shadcn.FixedTableSize(totalWidth * 0.11),
                3: shadcn.FixedTableSize(totalWidth * 0.08),
                4: shadcn.FixedTableSize(totalWidth * 0.11),
                5: shadcn.FixedTableSize(totalWidth * 0.08),
                6: shadcn.FixedTableSize(totalWidth * 0.10),
                7: shadcn.FixedTableSize(totalWidth * 0.11),
                8: shadcn.FixedTableSize(totalWidth * 0.11),
              }
            : {
                0: shadcn.FixedTableSize(totalWidth * 0.24),
                1: shadcn.FixedTableSize(totalWidth * 0.09),
                2: shadcn.FixedTableSize(totalWidth * 0.12),
                3: shadcn.FixedTableSize(totalWidth * 0.09),
                4: shadcn.FixedTableSize(totalWidth * 0.12),
                5: shadcn.FixedTableSize(totalWidth * 0.09),
                6: shadcn.FixedTableSize(totalWidth * 0.11),
                7: shadcn.FixedTableSize(totalWidth * 0.14),
              };

        return Container(
          color: resolveThemeColor(context,
              dark: MyntColors.cardDark, light: MyntColors.cardHover),
          child: shadcn.Table(
            defaultRowHeight: const shadcn.FixedTableSize(57),
            columnWidths: columnWidths,
            rows: [
              // Header
              shadcn.TableHeader(
                cells: [
                  _buildTableHeaderCell('Symbol'),
                  _buildTableHeaderCell('Buy Qty', alignRight: true),
                  _buildTableHeaderCell('Buy Rate', alignRight: true),
                  _buildTableHeaderCell('Sell Qty', alignRight: true),
                  _buildTableHeaderCell('Sell Rate', alignRight: true),
                  _buildTableHeaderCell('Net Qty', alignRight: true),
                  _buildTableHeaderCell('Close Price', alignRight: true),
                  if (isCommodity)
                    _buildTableHeaderCell('Unrealised P&L', alignRight: true),
                  _buildTableHeaderCell('Realised P&L', alignRight: true),
                ],
              ),
              // Data rows
              ...trades.asMap().entries.map((entry) {
                final index = entry.key;
                final trade = entry.value;
                final scripName = trade.sCRIPNAME ?? '';
                final scripSymbol = trade.sCRIPSYMBOL ?? '';
                final displaySymbol = scripSymbol.isNotEmpty ? scripSymbol : scripName;
                final realisedPnl =
                    double.tryParse(trade.realisedpnl ?? '0') ?? 0.0;
                final unrealisedPnl = trade.safeUnrealisedPnl;
                final rowKey = '${trade.tRADEDATE}_${index}_$scripSymbol';
                final openQty = trade.safeOpenQty;
                final openRate = trade.safeOpenRate;
                final buyAmt = double.tryParse(trade.bAMT ?? '0') ?? (trade.safeBuyQty * trade.safeBuyRate);
                final sellAmt = double.tryParse(trade.sAMT ?? '0') ?? (trade.safeSellQty * trade.safeSellRate);

                return shadcn.TableRow(
                  cells: [
                    // Symbol cell with company code + open qty badge
                    _buildTableDataCell(
                      rowKey: rowKey,
                      child: Tooltip(
                        message: displaySymbol.isNotEmpty ? displaySymbol : '--',
                        child: GestureDetector(
                        onTap: () => _showSymbolPnlDialog(context, scripSymbol, displaySymbol),
                        child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displaySymbol.isNotEmpty ? displaySymbol : '--',
                                  style: _getTextStyle(context,
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.textPrimaryDark,
                                          light: MyntColors.textPrimary)),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (openQty != 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.profitDark,
                                          light: MyntColors.profit),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${openQty.abs().toStringAsFixed(0)} @ ${openRate.toStringAsFixed(4)}',
                                    style: MyntWebTextStyles.caption(context,
                                        color: resolveThemeColor(context,
                                            dark: MyntColors.profitDark,
                                            light: MyntColors.profit),
                                        fontWeight: MyntFonts.medium),
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
                    // Buy Qty
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Text(
                        trade.safeBuyQty.toString(),
                        style: _getTextStyle(context),
                      ),
                    ),
                    // Buy Rate — rate on top, amount below
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatPrice(trade.bRATE),
                            style: _getTextStyle(context),
                          ),
                          Text(
                            buyAmt.toStringAsFixed(2),
                            style: MyntWebTextStyles.caption(context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sell Qty
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Text(
                        trade.safeSellQty.toString(),
                        style: _getTextStyle(context),
                      ),
                    ),
                    // Sell Rate — rate on top, amount below
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatPrice(trade.sRATE),
                            style: _getTextStyle(context),
                          ),
                          Text(
                            sellAmt.toStringAsFixed(2),
                            style: MyntWebTextStyles.caption(context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Net Qty
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Text(
                        trade.safeNetQty.toString(),
                        style: _getTextStyle(context),
                      ),
                    ),
                    // Close Price
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Text(
                        _formatPrice(trade.cLOSINGPRICE),
                        style: _getTextStyle(context),
                      ),
                    ),
                    // Unrealised P&L (Commodity only)
                    if (isCommodity)
                      _buildTableDataCell(
                        rowKey: rowKey,
                        alignRight: true,
                        child: Text(
                          unrealisedPnl == 0 ? '0' : _formatAmount(unrealisedPnl),
                          style: _getTextStyle(context,
                              color: _getPnlColor(context, unrealisedPnl)),
                        ),
                      ),
                    // Realised P&L
                    _buildTableDataCell(
                      rowKey: rowKey,
                      alignRight: true,
                      child: Text(
                        realisedPnl == 0 ? '0' : _formatAmount(realisedPnl),
                        style: _getTextStyle(context,
                            color: _getPnlColor(context, realisedPnl)),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // --- Symbol P&L Insights Dialog ---
  void _showSymbolPnlDialog(
      BuildContext context, String scripSymbol, String displaySymbol) {
    final ledgerprovider = ref.read(ledgerProvider);
    // Collect all trades for this symbol across all dates
    final List<TradeData> symbolTrades = [];
    ledgerprovider.grouped.forEach((date, trades) {
      for (final trade in trades) {
        if ((trade.sCRIPSYMBOL ?? '') == scripSymbol) {
          symbolTrades.add(trade);
        }
      }
    });

    if (symbolTrades.isEmpty) return;

    // Sort by trade date
    symbolTrades.sort((a, b) =>
        (a.tRADEDATE ?? '').compareTo(b.tRADEDATE ?? ''));

    final dark = isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor:
              dark ? MyntColors.backgroundColorDark : MyntColors.backgroundColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'P&L Insights',
                              style: MyntWebTextStyles.title(
                                context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Straight to the point about profit and loss analysis.',
                              style: MyntWebTextStyles.caption(
                                context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(Icons.close,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Table
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double totalWidth = constraints.maxWidth;
                        final columnWidths = {
                          0: shadcn.FixedTableSize(totalWidth * 0.22),
                          1: shadcn.FixedTableSize(totalWidth * 0.09),
                          2: shadcn.FixedTableSize(totalWidth * 0.12),
                          3: shadcn.FixedTableSize(totalWidth * 0.09),
                          4: shadcn.FixedTableSize(totalWidth * 0.12),
                          5: shadcn.FixedTableSize(totalWidth * 0.10),
                          6: shadcn.FixedTableSize(totalWidth * 0.12),
                          7: shadcn.FixedTableSize(totalWidth * 0.14),
                        };
                        return shadcn.Table(
                          defaultRowHeight: const shadcn.FixedTableSize(57),
                          columnWidths: columnWidths,
                          rows: [
                            shadcn.TableHeader(
                              cells: [
                                _buildTableHeaderCell('Script Symbol'),
                                _buildTableHeaderCell('Buy qty',
                                    alignRight: true),
                                _buildTableHeaderCell('Buy rate',
                                    alignRight: true),
                                _buildTableHeaderCell('Sell qty',
                                    alignRight: true),
                                _buildTableHeaderCell('Sell rate',
                                    alignRight: true),
                                _buildTableHeaderCell('Net Qty',
                                    alignRight: true),
                                _buildTableHeaderCell('Close Price',
                                    alignRight: true),
                                _buildTableHeaderCell('Realisedpnl',
                                    alignRight: true),
                              ],
                            ),
                            ...symbolTrades.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final t = entry.value;
                              final rKey = 'dialog_${idx}_$scripSymbol';
                              final buyAmt = double.tryParse(t.bAMT ?? '0') ??
                                  (t.safeBuyQty * t.safeBuyRate);
                              final sellAmt =
                                  double.tryParse(t.sAMT ?? '0') ??
                                      (t.safeSellQty * t.safeSellRate);
                              final netQty = t.safeNetQty;
                              final netAmt = double.tryParse(t.nRATE ?? '0') ?? 0.0;
                              final realisedPnl = t.safeRealisedPnl;
                              final tradeDate = t.tRADEDATE != null ? t.tRADEDATE!.split('T').first : '';

                              return shadcn.TableRow(
                                cells: [
                                  // Symbol + date
                                  _buildTableDataCell(
                                    rowKey: rKey,
                                    child: Tooltip(
                                      message: displaySymbol,
                                      child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displaySymbol,
                                          style: _getTextStyle(context,
                                              color: resolveThemeColor(context,
                                                  dark: MyntColors
                                                      .textPrimaryDark,
                                                  light: MyntColors
                                                      .textPrimary)),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        if (tradeDate.isNotEmpty)
                                          Text(
                                            tradeDate,
                                            style: MyntWebTextStyles.caption(context,
                                              darkColor: MyntColors.textSecondaryDark,
                                              lightColor: MyntColors.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                    ),
                                  ),
                                  // Buy Qty
                                  _buildTableDataCell(
                                    rowKey: rKey,
                                    alignRight: true,
                                    child: Text(
                                      t.safeBuyQty.toStringAsFixed(0),
                                      style: _getTextStyle(context),
                                    ),
                                  ),
                                  // Buy Rate + amount
                                  _buildTableDataCell(
                                    rowKey: rKey,
                                    alignRight: true,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatPrice(t.bRATE),
                                          style: _getTextStyle(context),
                                        ),
                                        Text(
                                          buyAmt.toStringAsFixed(2),
                                          style: MyntWebTextStyles.caption(context,
                                            darkColor: MyntColors.textSecondaryDark,
                                            lightColor: MyntColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Sell Qty
                                  _buildTableDataCell(
                                    rowKey: rKey,
                                    alignRight: true,
                                    child: Text(
                                      t.safeSellQty.toStringAsFixed(0),
                                      style: _getTextStyle(context),
                                    ),
                                  ),
                                  // Sell Rate + amount
                                  _buildTableDataCell(
                                    rowKey: rKey,
                                    alignRight: true,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatPrice(t.sRATE),
                                          style: _getTextStyle(context),
                                        ),
                                        Text(
                                          sellAmt.toStringAsFixed(2),
                                          style: MyntWebTextStyles.caption(context,
                                            darkColor: MyntColors.textSecondaryDark,
                                            lightColor: MyntColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Net Qty + amount
                                  _buildTableDataCell(
                                    rowKey: rKey,
                                    alignRight: true,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          netQty.toStringAsFixed(0),
                                          style: _getTextStyle(context),
                                        ),
                                        Text(
                                          netAmt.toStringAsFixed(2),
                                          style: MyntWebTextStyles.caption(context,
                                            darkColor: MyntColors.textSecondaryDark,
                                            lightColor: MyntColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Close Price
                                  _buildTableDataCell(
                                    rowKey: rKey,
                                    alignRight: true,
                                    child: Text(
                                      _formatPrice(t.cLOSINGPRICE),
                                      style: _getTextStyle(context),
                                    ),
                                  ),
                                  // Realised P&L
                                  _buildTableDataCell(
                                    rowKey: rKey,
                                    alignRight: true,
                                    child: Text(
                                      realisedPnl == 0
                                          ? '0'
                                          : _formatAmount(realisedPnl),
                                      style: _getTextStyle(context,
                                          color: _getPnlColor(
                                              context, realisedPnl)),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        );
                      },
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

  // --- Table cell helpers ---
  shadcn.TableCell _buildTableHeaderCell(String label,
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(label, style: _getHeaderStyle(context)),
      ),
    );
  }

  shadcn.TableCell _buildTableDataCell({
    required String rowKey,
    required Widget child,
    bool alignRight = false,
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
        onEnter: (_) => _hoveredRowKey.value = rowKey,
        onExit: (_) => _hoveredRowKey.value = null,
        child: ValueListenableBuilder<String?>(
          valueListenable: _hoveredRowKey,
          builder: (context, hoveredKey, _) {
            final isHovered = hoveredKey == rowKey;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: isHovered
                  ? resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary)
                      .withValues(alpha: 0.06)
                  : null,
              alignment: alignRight ? Alignment.centerRight : null,
              child: child,
            );
          },
        ),
      ),
    );
  }

  // --- Style helpers ---
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

  Color _getPnlColor(BuildContext context, double value) {
    if (value > 0) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    } else if (value < 0) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    }
    return resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
  }

  String _formatAmount(double value) {
    final prefix = value < 0 ? '-₹' : '₹';
    return '$prefix${NumberFormat('#,##,##0.00', 'en_IN').format(value.abs())}';
  }

  String _formatPrice(String? price) {
    if (price == null || price.isEmpty) return '0.00';
    try {
      return double.parse(price).toStringAsFixed(2);
    } catch (e) {
      return price;
    }
  }

}

// --- Commodity daily heatmap builder ---
Map<DateTime, double> _buildHeatmapForCommodity(LDProvider provider) {
  final Map<DateTime, double> heatmap = {};
  if (provider.calenderpnlAllData?.dateWise != null) {
    (provider.calenderpnlAllData!.dateWise as Map).forEach((dateStr, dateData) {
      try {
        final date = DateTime.parse(dateStr);
        final pnl = dateData['realised_pnl']?.toDouble() ?? 0.0;
        heatmap[DateTime(date.year, date.month, date.day)] = pnl;
      } catch (e) {
        // Skip invalid dates
      }
    });
  }
  return heatmap;
}

// --- Commodity monthly PnL builder ---
Map<String, double> _buildMonthlyPnLForCommodity(LDProvider provider) {
  final Map<String, double> monthlyPnL = {};
  if (provider.calenderpnlAllData?.dateWise != null) {
    (provider.calenderpnlAllData!.dateWise as Map).forEach((dateStr, dateData) {
      try {
        final date = DateTime.parse(dateStr);
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final pnl = dateData['realised_pnl']?.toDouble() ?? 0.0;
        monthlyPnL[key] = (monthlyPnL[key] ?? 0.0) + pnl;
      } catch (e) {
        // Skip invalid dates
      }
    });
  }
  return monthlyPnL;
}

// ============================================================
// Web Calendar Tabs (Monthly Grid + Daily Heatmap)
// ============================================================
class _WebCalendarTabs extends StatefulWidget {
  final Map<DateTime, double> heatmapData;
  final Map<String, double> monthlyPnL;
  final bool isMonthly;
  final DateTime startFY;
  final DateTime endFY;
  final DateTime selectedMonth;
  final ValueChanged<bool> onTabChanged;
  final ValueChanged<DateTime> onMonthSelected;
  final ValueChanged<DateTime> onMonthChanged;

  const _WebCalendarTabs({
    required this.heatmapData,
    required this.monthlyPnL,
    required this.isMonthly,
    required this.startFY,
    required this.endFY,
    required this.selectedMonth,
    required this.onTabChanged,
    required this.onMonthSelected,
    required this.onMonthChanged,
  });

  @override
  State<_WebCalendarTabs> createState() => _WebCalendarTabsState();
}

class _WebCalendarTabsState extends State<_WebCalendarTabs> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: resolveThemeColor(context,
              // dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder),
              dark: MyntColors.transparent, light: MyntColors.transparent),
        ),
        color: resolveThemeColor(
            context, dark: MyntColors.cardDark, light: MyntColors.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monthly / Daily toggle
          Row(
            children: [
              _buildTabButton('Daily', !widget.isMonthly),
              const SizedBox(width: 8),
              _buildTabButton('Monthly', widget.isMonthly),
            ],
          ),
          const SizedBox(height: 16),
          // Calendar content
          if (widget.isMonthly)
            _buildMonthlyGrid(context)
          else
            _WebDailyCalendar(
              heatmapData: widget.heatmapData,
              startDate: widget.startFY,
              endDate: widget.endFY,
              currentMonth: widget.selectedMonth,
              onMonthChanged: widget.onMonthChanged,
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isActive) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onTabChanged(label == 'Monthly'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isActive
                ? (isDarkMode(context)
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
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
  }

  Widget _buildMonthlyGrid(BuildContext context) {
    // Generate 12 months from startFY to endFY
    final months = <DateTime>[];
    DateTime current = DateTime(widget.startFY.year, widget.startFY.month, 1);
    while (!current.isAfter(widget.endFY)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }

    // 4 columns per row
    final rows = <List<DateTime>>[];
    for (int i = 0; i < months.length; i += 6) {
      final endIndex = (i + 6 > months.length) ? months.length : (i + 6);
      rows.add(months.sublist(i, endIndex));
    }

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              ...row.map((monthDate) {
                return Expanded(
                  child: _buildMonthCard(context, monthDate),
                );
              }),
              // Fill remaining slots
              ...List.generate(
                6 - row.length,
                (_) => const Expanded(child: SizedBox()),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthCard(BuildContext context, DateTime monthDate) {
    final key =
        "${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}";
    final double? monthValue = widget.monthlyPnL[key];

    final numval =
        (monthValue == null || monthValue == 0) ? "-" : monthValue.toStringAsFixed(2);
    var displayText = numval != "-"
        ? NumberFormat.compactCurrency(
            decimalDigits: 2, locale: 'en_IN', symbol: '')
            .format(double.parse(numval))
        : '-';
    if (displayText.contains("T")) {
      displayText = displayText.replaceAll("T", "K");
    }

    final monthAbbrs = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    final monthName = monthAbbrs[monthDate.month - 1];

    Color valueColor;
    if (monthValue == null || monthValue == 0) {
      valueColor = resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    } else {
      valueColor = monthValue < 0
          ? resolveThemeColor(
              context, dark: MyntColors.lossDark, light: MyntColors.loss)
          : resolveThemeColor(
              context, dark: MyntColors.profitDark, light: MyntColors.profit);
    }

    return GestureDetector(
      onTap: () => widget.onMonthSelected(monthDate),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: MyntColors.cardHoverDark, light: MyntColors.cardHover),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              monthName,
              style: MyntWebTextStyles.para(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              displayText,
              style: MyntWebTextStyles.para(context,
                  darkColor: valueColor,
                  lightColor: valueColor,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Web Daily Calendar (Heatmap)
// ============================================================
// GitHub-style contribution heatmap for the full financial year
class _WebDailyCalendar extends StatelessWidget {
  final Map<DateTime, double> heatmapData;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime currentMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const _WebDailyCalendar({
    required this.heatmapData,
    required this.startDate,
    required this.endDate,
    required this.currentMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Build all weeks from startDate to endDate
    // Align to Monday of the week containing startDate
    final firstMonday = startDate.subtract(
        Duration(days: (startDate.weekday - 1) % 7));
    final lastSunday = endDate.add(
        Duration(days: (7 - endDate.weekday) % 7));

    // Build week columns (each column = 1 week, 7 rows for Mon-Sun)
    final weeks = <List<DateTime?>>[];
    DateTime current = firstMonday;
    while (!current.isAfter(lastSunday)) {
      final week = <DateTime?>[];
      for (int d = 0; d < 7; d++) {
        final day = current.add(Duration(days: d));
        if (day.isBefore(startDate) || day.isAfter(endDate)) {
          week.add(null);
        } else {
          week.add(day);
        }
      }
      weeks.add(week);
      current = current.add(const Duration(days: 7));
    }

    // Group weeks by month — split weeks that span two months
    final monthGroups = <_MonthGroup>[];
    int? currentMonthVal;
    int? currentYear;
    List<List<DateTime?>> currentGroup = [];

    for (final week in weeks) {
      final datesInWeek = week.where((d) => d != null).toList();
      if (datesInWeek.isEmpty) {
        currentGroup.add(week);
        continue;
      }

      final firstDate = datesInWeek.first!;
      final firstMonth = firstDate.month;
      final firstYear = firstDate.year;

      // Check if this week spans multiple months
      final spansMultipleMonths = datesInWeek
          .any((d) => d!.month != firstMonth || d.year != firstYear);

      if (!spansMultipleMonths) {
        // Entire week belongs to one month
        if (firstMonth != currentMonthVal || firstYear != currentYear) {
          if (currentGroup.isNotEmpty) {
            monthGroups.add(_MonthGroup(
              month: currentMonthVal ?? firstMonth,
              year: currentYear ?? firstYear,
              weeks: List.from(currentGroup),
            ));
          }
          currentMonthVal = firstMonth;
          currentYear = firstYear;
          currentGroup = [week];
        } else {
          currentGroup.add(week);
        }
      } else {
        // Week spans two months — split into two filtered weeks
        final firstMonthWeek = week
            .map((d) => (d != null && d.month == firstMonth && d.year == firstYear) ? d : null)
            .toList();
        final secondMonthWeek = week
            .map((d) => (d != null && (d.month != firstMonth || d.year != firstYear)) ? d : null)
            .toList();

        // Add first part to current group
        if (firstMonth != currentMonthVal || firstYear != currentYear) {
          if (currentGroup.isNotEmpty) {
            monthGroups.add(_MonthGroup(
              month: currentMonthVal ?? firstMonth,
              year: currentYear ?? firstYear,
              weeks: List.from(currentGroup),
            ));
          }
          currentMonthVal = firstMonth;
          currentYear = firstYear;
          currentGroup = [firstMonthWeek];
        } else {
          currentGroup.add(firstMonthWeek);
        }

        // Close current month group and start new one for second month
        monthGroups.add(_MonthGroup(
          month: currentMonthVal ?? firstMonth,
          year: currentYear ?? firstYear,
          weeks: List.from(currentGroup),
        ));

        final secondDate = secondMonthWeek.firstWhere((d) => d != null)!;
        currentMonthVal = secondDate.month;
        currentYear = secondDate.year;
        currentGroup = [secondMonthWeek];
      }
    }
    if (currentGroup.isNotEmpty && currentMonthVal != null) {
      monthGroups.add(_MonthGroup(
        month: currentMonthVal,
        year: currentYear!,
        weeks: List.from(currentGroup),
      ));
    }

    const double dayLabelWidth = 36;
    const double monthGap = 6;
    final dayLabels = ['Mon', '', 'Wed', '', 'Fri', '', ''];

    final secondaryColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final emptyColor = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate cell size to fill 100% width
        // Total width = dayLabels + sum(month groups) + gaps between months
        final totalWeeks = monthGroups.fold<int>(0, (sum, g) => sum + g.weeks.length);
        final totalMonthGaps = (monthGroups.length - 1) * monthGap;
        final availableWidth =
            constraints.maxWidth - dayLabelWidth - totalMonthGaps;
        final cellStep = availableWidth / totalWeeks;
        final cellGap = (cellStep * 0.18).clamp(2.0, 4.0);
        final cellSize = cellStep - cellGap;

        Widget buildCell(DateTime? date) {
          if (date == null) {
            return SizedBox(
              width: cellStep,
              height: cellSize + cellGap,
            );
          }

          final value =
              heatmapData[DateTime(date.year, date.month, date.day)];
          final today = DateTime.now();
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          Color bgColor;
          final val = value ?? 0;
          if (val > 0) {
             bgColor = resolveThemeColor(context,
                    dark: MyntColors.profitDark, light: MyntColors.profit).withAlpha(900);
          } else if (val < 0) {
            // final intensity = _getIntensity(value.abs());
            bgColor = resolveThemeColor(context,
                    dark: MyntColors.lossDark, light: MyntColors.loss).withAlpha(900);
          } else {
            // final intensity = _getIntensity(value.abs());
            bgColor = emptyColor;
          }

          final todayBorderColor = resolveThemeColor(context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary);

          return _HoverableHeatmapCell(
            tooltipMessage:
                '${DateFormat('dd MMM yyyy').format(date)}: ${value != null ? '₹${value.toStringAsFixed(2)}' : 'No trades'}',
            cellSize: cellSize,
            cellGap: cellGap,
            bgColor: bgColor,
            isToday: isToday,
            todayBorderColor: todayBorderColor,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heatmap grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day-of-week labels (Mon, Wed, Fri)
                SizedBox(
                  width: dayLabelWidth,
                  child: Column(
                    children: List.generate(7, (dayIndex) {
                      return Container(
                        height: cellSize + cellGap,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dayLabels[dayIndex],
                          style: TextStyle(
                            fontFamily: MyntFonts.fontFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: secondaryColor,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // Month groups with gaps between them
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int m = 0; m < monthGroups.length; m++) ...[
                        // Month group
                        Expanded(
                          flex: monthGroups[m].weeks.length,
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                monthGroups[m].weeks.map((weekDays) {
                              return Column(
                                children: weekDays
                                    .map((date) => buildCell(date))
                                    .toList(),
                              );
                            }).toList(),
                          ),
                        ),
                        // Gap between months
                        if (m < monthGroups.length - 1)
                          SizedBox(width: monthGap),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Month labels below the grid — centered under each group
            Row(
              children: [
                SizedBox(width: dayLabelWidth),
                Expanded(
                  child: Row(
                    children: [
                      for (int m = 0; m < monthGroups.length; m++) ...[
                        Expanded(
                          flex: monthGroups[m].weeks.length,
                          child: Center(
                            child: Text(
                              _monthAbbr(monthGroups[m].month),
                              style: TextStyle(
                                fontFamily: MyntFonts.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: secondaryColor,
                              ),
                            ),
                          ),
                        ),
                        if (m < monthGroups.length - 1)
                          SizedBox(width: monthGap),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Normalize intensity between 0.15 and 0.8 based on value
  double _getIntensity(double absValue) {
    if (absValue <= 0) return 0.15;
    if (absValue >= 10000) return 0.8;
    // Log scale for better distribution
    return 0.15 + (0.65 * (absValue / 10000).clamp(0.0, 1.0));
  }

  String _monthAbbr(int month) {
    const abbrs = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return abbrs[month - 1];
  }
}

class _MonthGroup {
  final int month;
  final int year;
  final List<List<DateTime?>> weeks;
  const _MonthGroup({
    required this.month,
    required this.year,
    required this.weeks,
  });
}

class _HoverableHeatmapCell extends StatefulWidget {
  final String tooltipMessage;
  final double cellSize;
  final double cellGap;
  final Color bgColor;
  final bool isToday;
  final Color todayBorderColor;

  const _HoverableHeatmapCell({
    required this.tooltipMessage,
    required this.cellSize,
    required this.cellGap,
    required this.bgColor,
    required this.isToday,
    required this.todayBorderColor,
  });

  @override
  State<_HoverableHeatmapCell> createState() => _HoverableHeatmapCellState();
}

class _HoverableHeatmapCellState extends State<_HoverableHeatmapCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltipMessage,
        child: Container(
          width: widget.cellSize,
          height: widget.cellSize,
          margin: EdgeInsets.only(
              bottom: widget.cellGap, right: widget.cellGap),
          decoration: BoxDecoration(
            color: widget.bgColor,
            borderRadius: BorderRadius.circular(3),
            border: widget.isToday
                ? Border.all(
                    color: widget.todayBorderColor,
                    width: 1.5,
                  )
                : _hovered
                    ? Border.all(
                        color: widget.todayBorderColor.withValues(alpha: 0.5),
                        width: 1.5,
                      )
                    : null,
          ),
        ),
      ),
    );
  }
}

class _DateRowData {
  final DateTime dateKey;
  final List<TradeData> tradesForDate;
  final double totalRealisedPnl;
  final double? totalUnrealisedPnl;
  final String dateString;
  final bool isExpanded;

  const _DateRowData({
    required this.dateKey,
    required this.tradesForDate,
    required this.totalRealisedPnl,
    this.totalUnrealisedPnl,
    required this.dateString,
    required this.isExpanded,
  });
}

class _ScriptWiseRowData {
  final String symbol;
  final double buyQty;
  final double buyRate;
  final double buyAmt;
  final double sellQty;
  final double sellRate;
  final double sellAmt;
  final double netQty;
  final double closePrice;
  final double realisedPnl;

  const _ScriptWiseRowData({
    required this.symbol,
    required this.buyQty,
    required this.buyRate,
    required this.buyAmt,
    required this.sellQty,
    required this.sellRate,
    required this.sellAmt,
    required this.netQty,
    required this.closePrice,
    required this.realisedPnl,
  });
}
