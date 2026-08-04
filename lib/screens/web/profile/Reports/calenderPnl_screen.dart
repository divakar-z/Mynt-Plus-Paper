// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/desk_reports_model/calender_pnl_model.dart';
import '../../../../models/journal_notes_model/journal_note.dart';
import '../../../../models/journal_notes_model/journal_tag.dart';
import '../../../../models/journal_notes_model/segment_group.dart';
import '../../../../models/journal_notes_model/tag_pnl_analytics.dart';
import '../../../../locator/locator.dart';
import '../../../../locator/preference.dart';
import '../../../../provider/journal_notes/journal_notes_provider.dart';
import '../../../../provider/ledger_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/common_buttons_web.dart';
import '../../../../sharedWidget/custom_back_btn.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../sharedWidget/no_data_found_web.dart';
import '../../../../sharedWidget/scroll_to_load_mixin.dart';
import '../../../../sharedWidget/snack_bar.dart';
import 'charges_dialog_web.dart';
import 'note_editor_sheet_web.dart';
import 'pnl_stats_summary_web.dart';

/// The table view under the heat map. "Journal" is conditional — it only
/// exists once the client has journalled at least once (see [hasAnyNotesProvider]).
enum _ReportView { dateWise, scriptWise, journal }

class CalenderpnlScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const CalenderpnlScreen({super.key, this.onBack});

  @override
  ConsumerState<CalenderpnlScreen> createState() => _CalenderpnlScreenState();
}

class _CalenderpnlScreenState extends ConsumerState<CalenderpnlScreen>
    with ScrollToLoadMixin {
  final ScrollController _tableScrollController = ScrollController();

  /// First-visit coach mark for the trading journal (dim + centred card).
  /// Shown once, and only while the client has no notes — once a note
  /// exists the feature has introduced itself. Any dismissal counts as seen.
  ///
  /// The seen-flag is scoped PER CLIENT ID: two accounts sharing a browser
  /// are introduced independently (the browser flag is the only local state;
  /// the has-notes check is already per-account on the server).
  static const _kJournalCoachSeenBase = 'journal_coach_mark_seen';
  String get _journalCoachKey =>
      '${_kJournalCoachSeenBase}_${locator<Preferences>().clientId ?? ''}';
  bool _journalCoachSeen = true; // safe default until the prefs read lands
  bool _journalCoachShowing = false;

  @override
  ScrollController get tableScrollController => _tableScrollController;

  bool _isInitialized = false;
  int _selectedSegmentIndex = 0;
  _ReportView _reportView = _ReportView.dateWise;

  /// Tag ids selected as filters in the Journal tab. Empty = show every note.
  /// Multi-select is match-any: a note is shown if it carries ANY selected tag.
  final Set<int> _journalTagFilter = {};

  /// The "Untagged" pseudo-filter: when on, notes with no tags match too.
  bool _journalUntagged = false;

  /// Scanner-style floating tag filter: the panel follows the trigger via an
  /// OverlayPortal and floats over the content instead of expanding inline
  /// and pushing the notes list down.
  // bool _journalFilterOpen = false; // retired with the inline panel
  final LayerLink _journalFilterLink = LayerLink();

  /// Identifies the trigger box so the floating panel can measure the room
  /// left below it (and above it) before choosing a height and a direction.
  final GlobalKey _journalFilterTriggerKey = GlobalKey();
  final OverlayPortalController _journalFilterPortal =
      OverlayPortalController();

  /// Search text inside the filter dropdown — the reason the filter scales past
  /// 20+ tags: you type to narrow instead of scrolling a wall of rows.
  final TextEditingController _journalTagSearch = TextEditingController();

  /// Retired: the ranking shows every tag tile at once now (tiles wrap), so
  /// the Show all/less toggle went away with it.
  // bool _journalRankingOpen = false;

  /// Which Journal sub-tab is active: 0 = Notes, 1 = What costs you most.
  int _journalSubTab = 0;

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
    // First-visit coach mark for the trading journal: read whether this
    // client has already been shown it. Defaults to "seen" until the prefs
    // read lands, so it can never flash while loading.
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(
          () => _journalCoachSeen = prefs.getBool(_journalCoachKey) ?? false);
    });
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
    _journalTagSearch.dispose();
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
            !ledgerprovider.hasDataForSegment(ledgerprovider.selectedSegment));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme, ledgerprovider),
            _buildSegmentTabs(context, ledgerprovider),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  isLoading
                      ? Center(child: MyntLoader.branded())
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
          if (ledgerprovider.calenderpnlAllData != null &&
              ledgerprovider.selectedSegment != "Equity")
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

    final double netValue =
        (data?.realized ?? 0.0) - (data?.totalCharges ?? 0.0);

    // --- Trade journal notes ---
    // One list call decorates the whole heat map; never one fetch per cell.
    // Reading the nullable `value` means a slow or failed notes call never
    // blocks the P&L view — markers simply appear once they land.
    final noteGroup = SegmentGroup.fromTabLabel(ledgerprovider.selectedSegment);
    final notesRangeKey = _notesRangeKey(ledgerprovider);
    final notesAsync = notesRangeKey == null
        ? null
        : ref.watch(notesForRangeProvider(notesRangeKey));
    final notesByDate = notesAsync?.value ?? const <String, JournalNote>{};
    // Until the notes list has resolved at least once, a noted day looks
    // un-noted (its marker hasn't loaded). Offering "add" in that window let a
    // tap open the editor in add-mode over a note that already exists — the
    // reported "says add but the note is there" bug. Withhold the add
    // affordance until notes are ready so the marker and the tap always agree.
    final notesReady = notesAsync?.hasValue ?? false;
    final snapshotsByDate = noteGroup == null
        ? const <String, NotePnlSnapshot>{}
        : _snapshotsByDate(ledgerprovider, noteGroup);

    // The Journal tab is offered only once the client has journalled at least
    // once. Gated on the whole financial year and across all segments — not the
    // visible sub-range or the active tab — so the tab does not blink in and out
    // as the user moves the dates or switches asset class. The list and
    // analytics *inside* it are still scoped to the visible range and segment.
    final fyStart = _getFinancialYearStart(ledgerprovider.startTaxDate);
    final fyEnd = _getFinancialYearEnd(ledgerprovider.startTaxDate);
    final hasAnyNotesAsync = ref.watch(hasAnyNotesProvider(
        NotesRangeKey(from: _isoDate(fyStart), to: _isoDate(fyEnd))));
    final hasAnyNotes = hasAnyNotesAsync.value ?? false;
    // The heat map the active tab renders — computed here so the coach-mark
    // gate below can read it too.
    final heatmapForTab = isCommodity
        ? _buildHeatmapForCommodity(ledgerprovider)
        : ledgerprovider.heatmapData;
    // First-visit coach mark: the Journal tab cannot advertise itself (it is
    // hidden until a note exists), so the feature is introduced once, over
    // this screen, to a client with no notes yet. Shown even when the
    // calendar has no traded days — it is an announcement, not a tutorial —
    // but only after BOTH the notes check and the P&L load have settled, so
    // the one-time flag can never be burnt over a loading screen.
    if (hasAnyNotesAsync.hasValue &&
        !hasAnyNotes &&
        !_journalCoachSeen &&
        !_journalCoachShowing &&
        !ledgerprovider.calendarpnlloading &&
        noteGroup != null) {
      _journalCoachShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showJournalCoachMark();
      });
    }
    // If the tab vanishes (e.g. the last note was deleted) while it is
    // selected, fall back rather than render an orphaned view.
    final showJournal = hasAnyNotes && noteGroup != null;
    final effectiveView = (_reportView == _ReportView.journal && !showJournal)
        ? _ReportView.dateWise
        : _reportView;

    return SingleChildScrollView(
      controller: _tableScrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards + share card
          _buildSummaryCards(context, data, netValue, ledgerprovider),
          const SizedBox(height: 16),
          // Calendar section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _WebCalendarTabs(
              heatmapData: heatmapForTab,
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
              notedDates: notesByDate.keys.toSet(),
              notableDates:
                  notesReady ? snapshotsByDate.keys.toSet() : const <String>{},
              onNoteTap: (notesRangeKey == null || noteGroup == null)
                  ? null
                  : (date) {
                      final iso = _isoDate(date);
                      openNoteEditorSheet(
                        context,
                        ref: ref,
                        noteDate: iso,
                        group: noteGroup,
                        existing: notesByDate[iso],
                        snapshot: snapshotsByDate[iso],
                        rangeKey: notesRangeKey,
                        trades: _tradesForDate(ledgerprovider, iso),
                      );
                    },
              onMonthChanged: (month) => ledgerprovider.setSelectedMonth(month),
            ),
          ),
          const SizedBox(height: 16),
          // Date Wise / Script Wise / Journal tabs, with the Journal's tag
          // filter at the right end of the row while that tab is active.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildViewTabs(
              context,
              showJournal: showJournal,
              // The tag filter narrows the NOTES list, so it hides on the
              // insights sub-tab.
              trailing: (effectiveView == _ReportView.journal &&
                      _journalSubTab == 0 &&
                      noteGroup != null)
                  ? _buildJournalTabsFilter(context, ledgerprovider, noteGroup)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          // Table content based on selected tab
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: switch (effectiveView) {
              _ReportView.dateWise => _buildDateWiseSection(
                  context, sortedDates, ledgerprovider, isCommodity),
              _ReportView.scriptWise => _buildScriptWiseSection(
                  context, sortedDates, ledgerprovider, isCommodity),
              _ReportView.journal =>
                _buildJournalSection(context, ledgerprovider, noteGroup!),
            },
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
  Widget _buildSummaryCards(BuildContext context, CalenderpnlModel? data,
      double netValue, LDProvider ledgerprovider) {
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
                width: cardWidth,
                height: 115,
                child: _buildSummaryCard(context, 'Realised P&L', realized),
              ),
              SizedBox(
                width: cardWidth,
                height: 115,
                child: _buildSummaryCard(context, 'Unrealised P&L', unrealized),
              ),
              SizedBox(
                width: cardWidth,
                height: 115,
                child: _buildSummaryCard(context, 'Charges & Taxes', charges,
                    isNeutral: true,
                    onTap: () => showChargesDialog(context, ref: ref)),
              ),
              SizedBox(
                width: cardWidth,
                height: 115,
                child: _buildSummaryCard(context, 'Net Realised P&L', netValue),
              ),
              if (hasData)
                SizedBox(
                  width: cardWidth,
                  height: 115,
                  child: _buildShareCard(context, ledgerprovider),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String label, double value,
      {bool isNeutral = false, VoidCallback? onTap}) {
    final valueColor = isNeutral || value == 0
        ? resolveThemeColor(context,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)
        : _getPnlColor(context, value);

    return shadcn.Theme(
      data: shadcn.Theme.of(context).copyWith(radius: () => 0.3),
      child: MouseRegion(
        cursor:
            onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                            Text('Click to share your triumphant journey.',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                                style: MyntWebTextStyles.bodySmall(context,
                                    color: textColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(
                                  text: '$sharingUrl${ledgerprovider.ucode}'));
                              successMessage(dialogContext, 'Text copied');
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
                              if (await canLaunchUrl(Uri.parse(twitterUrl))) {
                                await launchUrl(Uri.parse(twitterUrl),
                                    mode: LaunchMode.externalApplication);
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

  // --- Date Wise / Script Wise / Journal Tabs ---
  Widget _buildViewTabs(BuildContext context,
      {required bool showJournal, Widget? trailing}) {
    return Row(
      children: [
        _buildViewTab('Date Wise', _ReportView.dateWise),
        const SizedBox(width: 24),
        _buildViewTab('Script Wise', _ReportView.scriptWise),
        if (showJournal) ...[
          const SizedBox(width: 24),
          _buildViewTab('Journal', _ReportView.journal),
        ],
        // Right-aligned extras (the Journal's tag filter sits here, opposite
        // the tabs).
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  /// The Journal's tag-filter trigger for the tabs row. Watches the same
  /// analytics the Journal section uses (same provider key — cached, no
  /// second fetch); hidden until the analytics have loaded.
  Widget _buildJournalTabsFilter(
      BuildContext context, LDProvider lp, SegmentGroup group) {
    final a = ref
        .watch(tagPnlProvider(TagPnlKey(
          from: _isoDate(lp.startTaxDate),
          to: _isoDate(lp.endTaxDate),
          group: group,
        )))
        .value;
    if (a == null) return const SizedBox.shrink();
    return _buildJournalFilterBar(context, a);
  }

  Widget _buildViewTab(String label, _ReportView view) {
    final isActive = _reportView == view;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _reportView = view;
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
                        dark: MyntColors.primaryDark, light: MyntColors.primary)
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
                      dark: MyntColors.primaryDark, light: MyntColors.primary)
                  : resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  // --- Insights (tag → P&L) Section ---
  //
  // The whole point of this tab is honest comparison, so the baseline rows
  // ("All days", "Untagged days") are never hidden: users tag losses far more
  // than wins, so a tag's own average overstates its effect until you see it
  // next to the baseline. Tags below the sample threshold show their day count
  // and total but not an average — three unlucky days are not a pattern.
  // --- Journal (notes list + costly-behaviour tag ranking) -----------------
  //
  // One surface for the notes: a scannable list you can filter by tag, with a
  // "what costs me money" ranking on top. The ranking leans on TOTAL P&L (always
  // known) rather than averages — a per-day average stays hidden below 5 days,
  // but a tag's total is meaningful from the first day. Every tag row is a
  // multi-select filter over the list below (match-any).
  Widget _buildJournalSection(
      BuildContext context, LDProvider lp, SegmentGroup group) {
    final rangeKey = _notesRangeKey(lp);
    final pnlAsync = ref.watch(tagPnlProvider(TagPnlKey(
      from: _isoDate(lp.startTaxDate),
      to: _isoDate(lp.endTaxDate),
      group: group,
    )));
    final notesByDate = rangeKey == null
        ? const <String, JournalNote>{}
        : (ref.watch(notesForRangeProvider(rangeKey)).value ??
            const <String, JournalNote>{});
    // Most recent first — noteDate is ISO, so a lexical sort is a date sort.
    final notes = notesByDate.values.toList()
      ..sort((a, b) => b.noteDate.compareTo(a.noteDate));

    return pnlAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => _buildJournalMessage(
          context, 'Could not load your journal. Please try again.'),
      data: (analytics) {
        if (notes.isEmpty && analytics.isEmpty) {
          // The app-wide empty state (as on Holdings) with a journal glyph;
          // no Explore button. The plain-text _buildJournalMessage remains
          // for the error case only.
          // The SAME widget Date Wise uses for its empty state (NoDataFound,
          // bull icon, 16px title) — not the web variant, whose larger type
          // read as oversized next to the sibling tabs.
          return const Center(
            child: NoDataFound(
              title: 'No notes yet',
              subtitle: 'Add a note to a traded day on the heat map and it '
                  'will show up here.',
              secondaryEnabled: false,
            ),
          );
        }
        return _buildJournalContent(
            context, analytics, notes, group, lp, rangeKey);
      },
    );
  }

  Widget _buildJournalMessage(BuildContext context, String message) {
    return shadcn.OutlinedContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.bodySmall(context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary),
          ),
        ),
      ),
    );
  }

  /// A note passes the filter if no filter is set, or it carries any selected
  /// tag, or the untagged filter is on and it has no tags. Pure display filter
  /// — the per-tag numbers stay backend-computed.
  bool _journalMatches(JournalNote n) {
    if (_journalTagFilter.isEmpty && !_journalUntagged) return true;
    if (_journalUntagged && n.tags.isEmpty) return true;
    return n.tags.any((t) => _journalTagFilter.contains(t.tagId));
  }

  Widget _buildJournalContent(
    BuildContext context,
    TagPnlAnalytics a,
    List<JournalNote> notes,
    SegmentGroup group,
    LDProvider lp,
    NotesRangeKey? rangeKey,
  ) {
    final visible = notes.where(_journalMatches).toList();
    // Split into two sub-tabs (management request): Notes first, the tag
    // insights second — the Daily/Monthly pill-toggle recipe, so it reads
    // as a level below the underline tabs above.
    return Column(
      // Stretch: the cards must fill the tab's width — with start alignment
      // the notes container shrank to its content (the tiny filtered-empty
      // box).
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _journalSubTabButton(context, 'Notes', 0,
                badge: visible.isEmpty ? null : '${visible.length}'),
            const SizedBox(width: 8),
            _journalSubTabButton(context, 'Tags info', 1),
          ],
        ),
        const SizedBox(height: 12),
        if (_journalSubTab == 0)
          shadcn.OutlinedContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotesList(context, visible, group, lp, rangeKey),
                _buildJournalProvisionalNote(context, a),
              ],
            ),
          )
        else if (a.tags.isEmpty)
          shadcn.OutlinedContainer(
            child: const Center(
              child: NoDataFound(
                title: 'No tag insights yet',
                subtitle: 'Tag your notes and each tag\'s P&L will be '
                    'ranked here.',
                secondaryEnabled: false,
              ),
            ),
          )
        else
          // The tab is "Tags info"; the section keeps its own titled header
          // strip, as before the split.
          _journalSectionCard(
            context,
            title: 'What costs you most',
            bodyPadding: const EdgeInsets.only(bottom: 10),
            child: _buildJournalRanking(context, a),
          ),
      ],
    );
  }

  /// One pill of the Journal's sub-tab toggle — the calendar's
  /// Daily/Monthly button recipe, with the order book's superscript count
  /// riding beside the label.
  Widget _journalSubTabButton(BuildContext context, String label, int index,
      {String? badge}) {
    final isActive = _journalSubTab == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _journalSubTab = index),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: isActive ? MyntFonts.semiBold : MyntFonts.medium,
                ).copyWith(
                  color: isActive
                      ? shadcn.Theme.of(context).colorScheme.foreground
                      : shadcn.Theme.of(context).colorScheme.mutedForeground,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Text(
                    badge,
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      fontWeight:
                          isActive ? MyntFonts.semiBold : MyntFonts.medium,
                    ).copyWith(
                      fontSize: 13,
                      color: isActive
                          ? shadcn.Theme.of(context).colorScheme.foreground
                          : shadcn.Theme.of(context)
                              .colorScheme
                              .mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Titled section wrapper in the insta-options dashboard style: a bold
  /// title strip with a bottom hairline, an optional trailing widget, then
  /// the padded body. Local mirror of that module's DashSectionCard — the
  /// widget itself lives on another branch.
  Widget _journalSectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? trailing,
    EdgeInsets bodyPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  }) {
    return shadcn.Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: resolveThemeColor(context,
                      dark: MyntColors.cardBorderDark,
                      light: MyntColors.cardBorder),
                ),
              ),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: MyntWebTextStyles.title(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.bold),
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(padding: bodyPadding, child: child),
        ],
      ),
    );
  }

  // --- Tag ranking (what costs money) + filters -----------------------------

  /// The filter trigger, styled like the scanner's index filter: an input-
  /// looking box whose text IS the current value ("All tags", "abc",
  /// "abc +2"), semibold once something is selected, with a chevron that
  /// flips while the floating panel is open. The panel itself is anchored
  /// through an [OverlayPortal] and floats over the content.
  Widget _buildJournalFilterBar(BuildContext context, TagPnlAnalytics a) {
    final anyFilter = _journalTagFilter.isNotEmpty || _journalUntagged;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    // Same input fill the scanner trigger uses, so it reads as a field.
    final inputFill = resolveThemeColor(context,
        dark: const Color(0xffB5C0CF).withValues(alpha: 0.15),
        light: const Color(0xFFF1F3F8));
    final byId = {for (final t in a.tags) t.tagId: t};

    // Value-as-label: the first selection plus how many more.
    final names = <String>[
      for (final id in _journalTagFilter)
        if (byId[id] != null) byId[id]!.name ?? 'tag',
      if (_journalUntagged) 'Untagged',
    ];
    final String label = names.isEmpty
        ? 'All tags'
        : names.length == 1
            ? names.first
            : '${names.first} +${names.length - 1}';

    return CompositedTransformTarget(
      link: _journalFilterLink,
      child: OverlayPortal(
        controller: _journalFilterPortal,
        overlayChildBuilder: (ctx) => _buildJournalFilterOverlay(ctx, a),
        child: Semantics(
          label: 'Filter by tag',
          button: true,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                // setState: the chevron's AnimatedRotation reads
                // isShowing, and toggling the portal alone does not
                // rebuild this trigger.
                setState(() {
                  // Fresh search on every reopen, like the scanner.
                  if (!_journalFilterPortal.isShowing) {
                    _journalTagSearch.clear();
                  }
                  _journalFilterPortal.toggle();
                });
              },
              child: Container(
                // Keyed so the overlay can measure where this trigger sits
                // and size the panel to the space actually left on screen.
                key: _journalFilterTriggerKey,
                width: 220,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: inputFill,
                  border: Border.all(
                      color: resolveThemeColor(context,
                          dark: MyntColors.borderMutedDark,
                          light: MyntColors.borderMuted)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: MyntWebTextStyles.body(context,
                            color: anyFilter ? textPrimary : secondary,
                            fontWeight: anyFilter
                                ? MyntFonts.semiBold
                                : MyntFonts.regular),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _journalFilterPortal.isShowing ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 20, color: secondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The floating layer: an invisible full-screen tap-catcher that closes
  /// the panel, plus the panel itself anchored to the trigger. The trigger
  /// sits at the LEFT edge of the section, so the panel grows rightward
  /// (the scanner's grows leftward from its right-edge trigger).
  Widget _buildJournalFilterOverlay(BuildContext ctx, TagPnlAnalytics a) {
    // The panel used to be a fixed 480 tall and always dropped downward, so
    // on a short window (or with the tabs row scrolled low) its lower rows
    // fell past the bottom edge — unreachable, since an overlay does not
    // scroll with the page. Measure the trigger instead: fit the panel to the
    // room actually below it, and flip it above when that room is too tight.
    const gap = 6.0; // trigger-to-panel gap
    const margin = 12.0; // never touch the window edge
    const minHeight = 200.0; // below this, dropping down is not worth it
    const maxHeight = 480.0;

    final screen = MediaQuery.sizeOf(ctx);
    final box =
        _journalFilterTriggerKey.currentContext?.findRenderObject() as RenderBox?;

    var openUpward = false;
    var panelHeight = maxHeight;
    if (box != null && box.hasSize) {
      final top = box.localToGlobal(Offset.zero).dy;
      final below = screen.height - (top + box.size.height) - gap - margin;
      final above = top - gap - margin;
      openUpward = below < minHeight && above > below;
      panelHeight =
          (openUpward ? above : below).clamp(minHeight, maxHeight).toDouble();
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // setState so the trigger's chevron un-rotates on outside-click
            // close, not only on trigger clicks.
            onTap: () => setState(_journalFilterPortal.hide),
          ),
        ),
        CompositedTransformFollower(
          link: _journalFilterLink,
          // The trigger sits at the RIGHT end of the tabs row, so the panel
          // grows leftward from it — same as the scanner. Vertically it hangs
          // below the trigger, or sits on top of it when space runs out.
          targetAnchor:
              openUpward ? Alignment.topRight : Alignment.bottomRight,
          followerAnchor:
              openUpward ? Alignment.bottomRight : Alignment.topRight,
          offset: Offset(0, openUpward ? -gap : gap),
          child: Material(
            color: Colors.transparent,
            child: _buildJournalFilterPanel(ctx, a, maxHeight: panelHeight),
          ),
        ),
      ],
    );
  }

  // RETIRED with the scanner-style filter: the trigger's value-as-label
  // replaced the removable chips row (selection is edited in the panel).
  // Widget _buildJournalActiveChip(BuildContext context,
  //     {required String name,
  //     required Color color,
  //     required VoidCallback onRemove}) {
  //   return Container(
  //     padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
  //     decoration: BoxDecoration(
  //       color: color.withValues(alpha: 0.12),
  //       borderRadius: BorderRadius.circular(999),
  //       border: Border.all(color: color.withValues(alpha: 0.35)),
  //     ),
  //     child: Row(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Container(
  //             width: 8,
  //             height: 8,
  //             decoration:
  //                 BoxDecoration(color: color, shape: BoxShape.circle)),
  //         const SizedBox(width: 6),
  //         Text(name,
  //             style: MyntWebTextStyles.caption(context,
  //                 darkColor: MyntColors.textPrimaryDark,
  //                 lightColor: MyntColors.textPrimary,
  //                 fontWeight: MyntFonts.medium)),
  //         const SizedBox(width: 2),
  //         Semantics(
  //           label: 'Remove filter $name',
  //           button: true,
  //           child: InkWell(
  //             onTap: onRemove,
  //             borderRadius: BorderRadius.circular(999),
  //             child: Padding(
  //               padding: const EdgeInsets.all(2),
  //               child: Icon(Icons.close_rounded,
  //                   size: 13,
  //                   color: resolveThemeColor(context,
  //                       dark: MyntColors.textSecondaryDark,
  //                       light: MyntColors.textSecondary)),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  /// The searchable tag checklist, floated scanner-style: search on top, the
  /// tag list (worst P&L first) in the middle, the Untagged pseudo-filter
  /// pinned below the scroll, and a Clear-all footer. Each row shows the
  /// tag's total and day count so choosing a filter also tells you what it
  /// cost.
  Widget _buildJournalFilterPanel(BuildContext context, TagPnlAnalytics a,
      {double maxHeight = 480}) {
    final q = _journalTagSearch.text.trim().toLowerCase();
    final tags = [...a.tags]..sort((x, y) => x.totalPnl.compareTo(y.totalPnl));
    final shown = [
      for (final t in tags)
        if (q.isEmpty || (t.name ?? '').toLowerCase().contains(q)) t,
    ];
    final showUntagged =
        a.untagged.dayCount > 0 && (q.isEmpty || 'untagged'.contains(q));
    final border = shadcn.Theme.of(context).colorScheme.border;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final anyFilter = _journalTagFilter.isNotEmpty || _journalUntagged;

    return Container(
      width: 360,
      // Sized by the caller to the room left on screen, so the list always
      // ends above the window edge and scrolls inside itself instead.
      constraints: BoxConstraints(maxHeight: maxHeight),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                controller: _journalTagSearch,
                onChanged: (_) => setState(() {}),
                style: MyntWebTextStyles.bodySmall(context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 18, color: secondary),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 34, minHeight: 34),
                  hintText: 'Search tags',
                  hintStyle: MyntWebTextStyles.bodySmall(context,
                      darkColor: MyntColors.textTertiaryDark,
                      lightColor: MyntColors.textTertiary),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  filled: true,
                  fillColor: resolveThemeColor(context,
                      dark: MyntColors.inputBgDark, light: MyntColors.inputBg),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: resolveThemeColor(context,
                              dark: MyntColors.primaryDark,
                              light: MyntColors.primary))),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: border),
          // Only the scrollable list is Flexible. The empty states render at
          // natural height — inside a Flexible, the empty widget's internal
          // Center stretched to the panel's full height budget and pushed it
          // off-screen.
          if (shown.isEmpty && !showUntagged)
            // True no-data gets the app-wide empty widget (compact — this
            // is a popover); a search query with no match stays a
            // one-liner, it's a transient state.
            (q.isEmpty
                ? NoDataFoundWeb(
                    title: 'No tags yet',
                    subtitle: "Create tags from the note editor's tag field.",
                    secondaryEnabled: false,
                    compact: true,
                    iconWidget: Icon(shadcn.LucideIcons.tag,
                        size: 36, color: secondary),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No tags match “$q”.',
                        style: MyntWebTextStyles.caption(context,
                            color: secondary)),
                  ))
          else
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  for (final t in shown)
                    _filterPanelRow(
                      context,
                      name: t.name ?? 'tag',
                      color: hexToColor(t.color, fallback: secondary),
                      total: t.totalPnl,
                      dayCount: t.dayCount,
                      selected: _journalTagFilter.contains(t.tagId),
                      onTap: t.tagId == null
                          ? null
                          : () => setState(() {
                                final id = t.tagId!;
                                if (!_journalTagFilter.remove(id)) {
                                  _journalTagFilter.add(id);
                                }
                              }),
                    ),
                ],
              ),
            ),
          // Untagged is pinned below the scroll so it is always reachable,
          // however long the tag list grows.
          if (showUntagged) ...[
            Divider(height: 1, color: border),
            _filterPanelRow(
              context,
              name: 'Untagged',
              color: resolveThemeColor(context,
                  dark: MyntColors.textTertiaryDark,
                  light: MyntColors.textTertiary),
              total: a.untagged.totalPnl,
              dayCount: a.untagged.dayCount,
              selected: _journalUntagged,
              onTap: () => setState(() => _journalUntagged = !_journalUntagged),
            ),
          ],
          Divider(height: 1, color: border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                const Spacer(),
                MyntIconTextButton(
                  label: 'Clear all',
                  size: MyntButtonSize.small,
                  // Greys out when there is nothing to clear, like the
                  // scanner's footer.
                  textColor: anyFilter
                      ? null
                      : resolveThemeColor(context,
                          dark: MyntColors.textTertiaryDark,
                          light: MyntColors.textTertiary),
                  onPressed: anyFilter
                      ? () => setState(() {
                            _journalTagFilter.clear();
                            _journalUntagged = false;
                          })
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPanelRow(BuildContext context,
      {required String name,
      required Color color,
      required double total,
      required int dayCount,
      required bool selected,
      required VoidCallback? onTap}) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return Semantics(
      label: '${selected ? 'Remove filter' : 'Filter by'} $name',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              // The scanner's custom compact checkbox — filled primary with
              // a white check when selected.
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  border: Border.all(
                      color:
                          selected ? accent : secondary.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              // Tag glyph in the tag's colour, matching the chips app-wide.
              Icon(shadcn.LucideIcons.tag, size: 13, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: MyntWebTextStyles.bodySmall(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight:
                            selected ? MyntFonts.semiBold : MyntFonts.regular)),
              ),
              const SizedBox(width: 8),
              Text(_formatAmount(total),
                  style: MyntWebTextStyles.caption(context,
                      color: _getPnlColor(context, total))),
              const SizedBox(width: 8),
              Text('$dayCount ${dayCount == 1 ? 'day' : 'days'}',
                  style: MyntWebTextStyles.caption(context, color: secondary)),
            ],
          ),
        ),
      ),
    );
  }

  /// The "What costs you most" card body in the Concentration & breadth
  /// style: each tag is a bordered stat mini-card (tag glyph + name as the
  /// muted label, the coloured total as the value, DAYS / WINS / LOSSES
  /// badges under it). Worst three tags by default (biggest losses first);
  /// the card's trailing "Show all" link expands the rest. Read-only —
  /// filtering is the filter dropdown's job.
  Widget _buildJournalRanking(BuildContext context, TagPnlAnalytics a) {
    if (a.tags.isEmpty) return const SizedBox.shrink();
    final tags = [...a.tags]..sort((x, y) => x.totalPnl.compareTo(y.totalPnl));
    // The bar inside each tile is scaled against the biggest absolute total,
    // so tile bars stay comparable to each other.
    var maxAbs = 0.0;
    for (final t in tags) {
      if (t.totalPnl.abs() > maxAbs) maxAbs = t.totalPnl.abs();
    }
    if (maxAbs <= 0) maxAbs = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Design round 1: the ring tiles. Swap back to
              // _rankingStatTile to compare with the bar variant.
              for (final t in tags) _rankingRingTile(context, t, maxAbs)
            ],
          ),
        ),
        // Plain-English version of the backend's double-counting note: only
        // shown when a day actually carries more than one tag, right where the
        // overlapping totals are, so it reads as context rather than jargon.
        if (a.doubleCounting.hasOverlap)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: _insightCaveatLine(
              context,
              Icons.info_outline_rounded,
              'A day with more than one tag counts toward each of them, so '
              'these totals overlap and won’t add up to your overall P&L.',
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }

  /// "2 losing days" / "3 winning days" for pure splits, the mixed split
  /// spelled out otherwise, and a plain day count when the backend has
  /// suppressed the win/loss stats (sample too small). Formatting of
  /// backend numbers only.
  String _tagDaysLabel(TagPnlStats s) {
    if (s.sufficientSample && s.winRate != null) {
      if (s.lossDays > 0 && s.winDays == 0) {
        return '${s.lossDays} losing day${s.lossDays == 1 ? '' : 's'}';
      } else if (s.winDays > 0 && s.lossDays == 0) {
        return '${s.winDays} winning day${s.winDays == 1 ? '' : 's'}';
      }
      return '${s.dayCount} days · ${s.winDays}W ${s.lossDays}L';
    }
    return '${s.dayCount} day${s.dayCount == 1 ? '' : 's'}';
  }

  /// Design round 1 (manager's reference): the tag card as a soft tint of
  /// the tag's colour — name on top, a progress ring showing this tag's
  /// share of the biggest absolute total (the same comparison the bar tile
  /// encodes, drawn circular) with the percentage in the middle, then the
  /// coloured amount and the day count.
  Widget _rankingRingTile(BuildContext context, TagPnlStats s, double maxAbs) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final tagColor = hexToColor(s.color, fallback: secondary);
    final frac = (s.totalPnl.abs() / maxAbs).clamp(0.0, 1.0);
    // The ring reads P&L direction, exactly as the bar variant did: green
    // for profit, red for loss (softened like the bar). The tag's own
    // colour stays on the card border only.
    final ringColor =
        _getPnlColor(context, s.totalPnl).withValues(alpha: 0.55);

    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        // color: tagColor.withValues(alpha: 0.06),
        border: Border.all(color: tagColor.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.name ?? 'tag',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.body(context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.semiBold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: frac,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  color: ringColor,
                  backgroundColor: ringColor.withValues(alpha: 0.15),
                ),
                Center(
                  child: Text(
                    '${(frac * 100).round()}%',
                    style: MyntWebTextStyles.bodySmall(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.semiBold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatAmount(s.totalPnl),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.body(context,
                color: _getPnlColor(context, s.totalPnl),
                fontWeight: MyntFonts.semiBold),
          ),
          const SizedBox(height: 4),
          Text(
            _tagDaysLabel(s),
            style: MyntWebTextStyles.caption(context,
                darkColor: MyntColors.textTertiaryDark,
                lightColor: MyntColors.textTertiary),
          ),
        ],
      ),
    );
  }

  /// Design round 0 (kept for comparison): the bordered bar tile.
  // ignore: unused_element
  Widget _rankingStatTile(BuildContext context, TagPnlStats s, double maxAbs) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final tagColor = hexToColor(s.color, fallback: secondary);
    final border = resolveThemeColor(context,
            dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary)
        .withValues(alpha: 0.2);
    final daysLabel = _tagDaysLabel(s);

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name gets the full tile width (sharing its row with the amount
          // truncated longer names); the amount sits on its own line just
          // above the bar, right-aligned.
          Row(
            children: [
              Icon(shadcn.LucideIcons.tag, size: 16, color: tagColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  s.name ?? 'tag',
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.body(context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            // Indent past the 16px glyph + 6px gap so the day count starts
            // exactly under the tag NAME, not under the icon.
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              daysLabel,
              style: MyntWebTextStyles.caption(context,
                  darkColor: MyntColors.textTertiaryDark,
                  lightColor: MyntColors.textTertiary),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _formatAmount(s.totalPnl),
              style: MyntWebTextStyles.title(context,
                  color: _getPnlColor(context, s.totalPnl),
                  fontWeight: MyntFonts.semiBold),
            ),
          ),
          const SizedBox(height: 6),
          // Comparative bar — green for profit, red for loss, its length
          // relative to the biggest tag so tiles compare at a glance.
          _pnlBar(context, (s.totalPnl.abs() / maxAbs).clamp(0.02, 1.0),
              s.totalPnl >= 0),
        ],
      ),
    );
  }

  // RETIRED with the stat-tile ranking (Concentration & breadth recipe):
  // the dot + comparative bar rows, kept for rollback.
  // Widget _buildRankingRow(BuildContext context, TagPnlStats s, double maxAbs) {
  //   final color = hexToColor(s.color,
  //       fallback: resolveThemeColor(context,
  //           dark: MyntColors.textSecondaryDark,
  //           light: MyntColors.textSecondary));
  //   final frac = (s.totalPnl.abs() / maxAbs).clamp(0.02, 1.0);
  //   final meta = (s.sufficientSample && s.winRate != null)
  //       ? '${s.dayCount} days · ${(s.winRate! * 100).round()}% '
  //           '${s.winDays}W ${s.lossDays}L'
  //       : '${s.dayCount} day${s.dayCount == 1 ? '' : 's'}';
  //   return Padding(
  //     padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
  //     child: Column(
  //       children: [
  //         Row(
  //           children: [
  //             Container(
  //                 width: 9,
  //                 height: 9,
  //                 decoration:
  //                     BoxDecoration(color: color, shape: BoxShape.circle)),
  //             const SizedBox(width: 8),
  //             Expanded(
  //               child: Text(s.name ?? 'tag',
  //                   overflow: TextOverflow.ellipsis,
  //                   style: _getTextStyle(context)),
  //             ),
  //             Text(_formatAmount(s.totalPnl),
  //                 style: _getTextStyle(context,
  //                     color: _getPnlColor(context, s.totalPnl))),
  //           ],
  //         ),
  //         const SizedBox(height: 6),
  //         Row(
  //           children: [
  //             Expanded(child: _pnlBar(context, frac, s.totalPnl >= 0)),
  //             const SizedBox(width: 10),
  //             Text(meta,
  //                 style: MyntWebTextStyles.caption(context,
  //                     darkColor: MyntColors.textTertiaryDark,
  //                     lightColor: MyntColors.textTertiary)),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  /// The comparative P&L bar, now drawn inside each ranking stat tile.
  /// Fill softened to 55% so a wall of tiles doesn't shout.
  Widget _pnlBar(BuildContext context, double fraction, bool positive) {
    final track = resolveThemeColor(context,
        dark: MyntColors.borderMutedDark, light: MyntColors.borderMuted);
    final fill = (positive
            ? resolveThemeColor(context,
                dark: MyntColors.profitDark, light: MyntColors.profit)
            : resolveThemeColor(context,
                dark: MyntColors.lossDark, light: MyntColors.loss))
        .withValues(alpha: 0.55);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        color: track,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            heightFactor: 1,
            child: Container(color: fill),
          ),
        ),
      ),
    );
  }

  // --- Notes list -----------------------------------------------------------

  Widget _buildNotesList(
    BuildContext context,
    List<JournalNote> notes,
    SegmentGroup group,
    LDProvider lp,
    NotesRangeKey? rangeKey,
  ) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final snapshots = _snapshotsByDate(lp, group);
    // Render incrementally, like the Date Wise / Script Wise tables: only the
    // first `displayedItemCount` rows are built, and the shared scroll listener
    // ([ScrollToLoadMixin]) appends more as the page scrolls near the bottom.
    // A year of daily notes is 200+ rows — building them all at once would jank.
    final displayed = takeDisplayed(notes);
    final remaining = notes.length - displayed.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The note count now rides on the Notes sub-tab as a superscript, the
        // order book's recipe — so this header only speaks up while the list
        // is paginated.
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Showing ${displayed.length} of ${notes.length} notes',
              style: MyntWebTextStyles.caption(context, color: secondary),
            ),
          ),
        if (notes.isEmpty)
          // Two empty flavours: a set filter that matched nothing gets the
          // compact text + Clear action (transient state); genuinely no
          // notes in the range gets the app-wide empty widget — this branch
          // is reachable even though the upstream check exists, because the
          // analytics can carry tags while the range itself has no notes.
          (_journalTagFilter.isNotEmpty || _journalUntagged)
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No notes match this filter.',
                            style: MyntWebTextStyles.bodySmall(context,
                                color: secondary)),
                        const SizedBox(height: 8),
                        Semantics(
                          label: 'Clear tag filter',
                          button: true,
                          child: InkWell(
                            onTap: () => setState(() {
                              _journalTagFilter.clear();
                              _journalUntagged = false;
                            }),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              child: Text('Clear filter',
                                  style: MyntWebTextStyles.bodySmall(context,
                                      darkColor: MyntColors.primaryDark,
                                      lightColor: MyntColors.primary,
                                      fontWeight: MyntFonts.medium)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const NoDataFound(
                  title: 'No notes in this range',
                  subtitle: 'Add a note to a traded day on the heat map and '
                      'it will show up here.',
                  secondaryEnabled: false,
                )
        else ...[
          for (var i = 0; i < displayed.length; i++) ...[
            if (i > 0) _insightHairline(context),
            _buildJournalNoteRow(context, displayed[i], group, rangeKey,
                snapshots[displayed[i].noteDate], lp),
          ],
          // Scrolling loads more automatically; this is an explicit fallback
          // and makes the "there's more" state obvious.
          if (remaining > 0) ...[
            _insightHairline(context),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  label: 'Show more notes',
                  button: true,
                  child: InkWell(
                    onTap: () => setState(() =>
                        displayedItemCount += ScrollToLoadMixin.itemsPerPage),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Text(
                        'Show '
                        '${remaining < ScrollToLoadMixin.itemsPerPage ? remaining : ScrollToLoadMixin.itemsPerPage} '
                        'more',
                        style: MyntWebTextStyles.caption(context,
                            darkColor: MyntColors.primaryDark,
                            lightColor: MyntColors.primary,
                            fontWeight: MyntFonts.medium),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // RETIRED — rounded tinted count badge, replaced by the order book's
  // superscript count on the sub-tab itself. Kept for rollback:
  // Widget _journalCountBadge(BuildContext context, String label) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  //     decoration: BoxDecoration(
  //       color: resolveThemeColor(context,
  //               dark: MyntColors.primaryDark, light: MyntColors.primary)
  //           .withValues(alpha: 0.12),
  //       borderRadius: BorderRadius.circular(5),
  //     ),
  //     child: Text(
  //       label,
  //       style: MyntWebTextStyles.para(context,
  //           darkColor: MyntColors.primaryDark,
  //           lightColor: MyntColors.primary,
  //           fontWeight: MyntFonts.semiBold),
  //     ),
  //   );
  // }

  Widget _buildJournalNoteRow(
    BuildContext context,
    JournalNote note,
    SegmentGroup group,
    NotesRangeKey? rangeKey,
    NotePnlSnapshot? snapshot,
    // Held rather than resolved here: the day's trades are only read when the
    // row is actually opened, not for every row on every rebuild.
    LDProvider lp,
  ) {
    final pnl = note.pnl?.realised ?? snapshot?.realised;
    final title = note.title.trim();
    final comment = note.comment.trim();
    final headline = title.isNotEmpty
        ? title
        : (comment.isNotEmpty ? comment : 'Untitled note');
    // Only show the comment as a preview line when it isn't already the headline.
    final preview = title.isNotEmpty ? comment : '';
    final d = DateTime.tryParse(note.noteDate);
    // Day over month, both in the same size and weight — the old badge sized
    // the day up and greyed the month down, which read as a calendar tile.
    final day = d != null ? DateFormat('dd').format(d) : '';
    final mon = d != null ? DateFormat('MMM').format(d) : note.noteDate;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    return Semantics(
      label: 'View note ${note.noteDate}',
      button: true,
      child: InkWell(
        onTap: rangeKey == null
            ? null
            : () => openNoteEditorSheet(
                  context,
                  ref: ref,
                  noteDate: note.noteDate,
                  group: group,
                  existing: note,
                  snapshot: snapshot,
                  rangeKey: rangeKey,
                  // Reading a note opens it read-only; the pencil edits.
                  startInEdit: false,
                  trades: _tradesForDate(lp, note.noteDate),
                ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date column — day over month at one size; the day carries the
              // primary blue, the month stays in the normal text colour.
              SizedBox(
                width: 46,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day,
                        style: MyntWebTextStyles.body(context,
                            darkColor: MyntColors.primaryDark,
                            lightColor: MyntColors.primary,
                            fontWeight: MyntFonts.semiBold)),
                    Text(mon,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MyntWebTextStyles.body(context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary,
                            fontWeight: MyntFonts.semiBold)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _getTextStyle(context)
                            .copyWith(fontWeight: MyntFonts.semiBold)),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MyntWebTextStyles.para(context,
                              color: secondary)),
                    ],
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final t in note.tags.take(3))
                            _journalMiniTag(context, t),
                          if (note.tags.length > 3)
                            Text('+${note.tags.length - 3}',
                                style: MyntWebTextStyles.para(context,
                                    color: muted)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (pnl != null)
                    Text(_formatAmount(pnl),
                        style: _getTextStyle(context,
                                color: _getPnlColor(context, pnl))
                            .copyWith(fontWeight: MyntFonts.semiBold)),
                  if (note.attachments.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_file_rounded, size: 16, color: muted),
                        const SizedBox(width: 3),
                        Text('${note.attachments.length}',
                            style: MyntWebTextStyles.para(context,
                                color: muted)),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A compact tag pill for the note rows — the same recipe as the note
  /// editor's chips: borderless soft tint, the tag glyph in the tag's own
  /// colour, then the name. (The old dot + outlined pill is below, retired.)
  Widget _journalMiniTag(BuildContext context, JournalTag tag) {
    final color = hexToColor(tag.color,
        fallback: resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(shadcn.LucideIcons.tag, size: 12, color: color),
          const SizedBox(width: 4),
          Text(tag.name,
              style: MyntWebTextStyles.para(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium)),
        ],
      ),
    );
  }

  // RETIRED — dot + outlined pill version of [_journalMiniTag], kept for
  // rollback:
  // return Container(
  //   padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
  //   decoration: BoxDecoration(
  //     color: color.withValues(alpha: 0.10),
  //     borderRadius: BorderRadius.circular(999),
  //     border: Border.all(color: color.withValues(alpha: 0.30)),
  //   ),
  //   child: Row(
  //     mainAxisSize: MainAxisSize.min,
  //     children: [
  //       Container(
  //           width: 6,
  //           height: 6,
  //           decoration:
  //               BoxDecoration(color: color, shape: BoxShape.circle)),
  //       const SizedBox(width: 5),
  //       Text(tag.name,
  //           style: MyntWebTextStyles.caption(context,
  //               darkColor: MyntColors.textSecondaryDark,
  //               lightColor: MyntColors.textSecondary,
  //               fontWeight: MyntFonts.medium)),
  //     ],
  //   ),
  // );

  Widget _insightHairline(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        color: resolveThemeColor(context,
            dark: MyntColors.dividerDark, light: MyntColors.divider),
      );

  /// A plain-English "some of these are provisional" note at the foot of the
  /// Journal — only when a day was journalled before the market closed. The
  /// backend's raw wording is deliberately not used; it reads as jargon.
  Widget _buildJournalProvisionalNote(BuildContext context, TagPnlAnalytics a) {
    if (!a.dataQuality.hasProvisional) return const SizedBox.shrink();
    final n = a.dataQuality.provisionalSnapshotCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _insightHairline(context),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _insightCaveatLine(
            context,
            Icons.schedule_rounded,
            '$n ${n == 1 ? 'note was' : 'notes were'} saved before the market '
            'closed, so ${n == 1 ? 'its' : 'their'} P&L may still change.',
          ),
        ),
      ],
    );
  }

  Widget _insightCaveatLine(BuildContext context, IconData icon, String text) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: MyntWebTextStyles.caption(context, color: muted),
          ),
        ),
      ],
    );
  }

  // --- Script Wise Section ---
  Widget _buildScriptWiseSection(BuildContext context,
      List<DateTime> sortedDates, LDProvider ledgerprovider, bool isCommodity) {
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
        final sum = symbolData['sum'] is Map ? symbolData['sum'] as Map : null;

        final buyQty =
            readField(sum, symbolData, ['total_buy_qty', 'BUYQTY', 'buy_qty']);
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
        final netQty =
            readField(sum, symbolData, ['Updated_NETQTY', 'NETQTY', 'net_qty']);
        final closePrice = readField(
            sum, symbolData, ['CLOSING_PRICE', 'CL_PRICE', 'close_price']);
        final realisedPnl =
            readNum(symbolData, ['realised_pnl', 'realisedpnl', 'PL_AMT']);

        final buyAmt = readField(
            sum, symbolData, ['total_buy_amt', 'BUYAMT', 'buy_amt', 'BUY_AMT']);
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
          final buyAmt =
              double.tryParse(trade.bAMT ?? '0') ?? (buyQty * buyRate);
          final sellQty = trade.safeSellQty.toDouble();
          final sellRate = trade.safeSellRate;
          final sellAmt =
              double.tryParse(trade.sAMT ?? '0') ?? (sellQty * sellRate);
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
                          onTap: () => _showSymbolPnlDialog(
                              context, row.symbol, row.symbol),
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
                            style: MyntWebTextStyles.caption(
                              context,
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
                            style: MyntWebTextStyles.caption(
                              context,
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

  // --- Trade journal notes -------------------------------------------------

  /// `YYYY-MM-DD`, the only format the notes API accepts.
  ///
  /// Deliberately not the `DateFormat('dd/MM/yyyy')` this screen uses for the
  /// journal endpoints. Both formats go to the same host and must not share a
  /// formatter — `14/07/2026` is a `400 BAD_DATE` to the notes routes.
  static String _isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The scrip rows traded on [iso], read from the calendar P&L response
  /// already in memory — the note sheet lists them under the note, and no
  /// extra call is made.
  ///
  /// Same two sources the Date Wise tab reads: commodity keeps its own
  /// per-date bucket (`dateWise`), while the provider's `grouped` map dates a
  /// commodity row by its BUY date, which is not the day being viewed.
  List<TradeData> _tradesForDate(LDProvider lp, String iso) {
    final dateWise = lp.calenderpnlAllData?.dateWise;
    if (dateWise != null) {
      final dateData = dateWise[iso];
      final trades = dateData is Map ? dateData['trades'] : null;
      if (trades is! List) return const [];
      return trades
          .map((t) => TradeData.fromCommodityJson(t as Map<String, dynamic>))
          .toList();
    }
    final d = DateTime.tryParse(iso);
    if (d == null) return const [];
    return lp.grouped[DateTime(d.year, d.month, d.day)] ?? const [];
  }

  /// One-time introduction to the trading journal: dim the page, a centred
  /// card with a mini heat-map illustration, one line of copy, "Got it".
  /// Any dismissal (button, X-less barrier click, Esc) counts as seen — the
  /// card has said its piece and never shows again.
  Future<void> _showJournalCoachMark() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: resolveThemeColor(dialogContext,
                    dark: MyntColors.dialogDark, light: MyntColors.dialog),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mini heat-map strip: quiet days around a profit day and a
                  // loss day carrying the note marker.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: resolveThemeColor(dialogContext,
                              dark: MyntColors.borderMutedDark,
                              light: MyntColors.borderMuted)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _coachCell(dialogContext, kind: 'empty'),
                        _coachCell(dialogContext, kind: 'empty'),
                        _coachCell(dialogContext, kind: 'profit'),
                        _coachCell(dialogContext, kind: 'empty'),
                        _coachCell(dialogContext, kind: 'loss', marked: true),
                        _coachCell(dialogContext, kind: 'empty'),
                        _coachCell(dialogContext, kind: 'empty'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Add trading notes!',
                    textAlign: TextAlign.center,
                    style: MyntWebTextStyles.title(dialogContext,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.semiBold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click any traded day on the calendar to save your '
                    'thoughts, mistakes or strategy to review later.',
                    textAlign: TextAlign.center,
                    style: MyntWebTextStyles.body(dialogContext,
                        fontWeight: FontWeight.w500,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  MyntPrimaryButton(
                    label: 'Got it',
                    size: MyntButtonSize.large,
                    isFullWidth: true,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    // Persist however it was dismissed.
    _journalCoachSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_journalCoachKey, true);
  }

  /// One cell of the coach-mark illustration strip.
  Widget _coachCell(BuildContext context,
      {required String kind, bool marked = false}) {
    final Color fill = switch (kind) {
      'profit' => resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit),
      'loss' => resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss),
      _ => resolveThemeColor(context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.textSecondary)
          .withValues(alpha: 0.15),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
                color: fill, borderRadius: BorderRadius.circular(3)),
          ),
          if (marked)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: resolveThemeColor(context,
                      dark: MyntColors.primaryDark, light: MyntColors.primary),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Null when the active tab is not one of the four known asset classes — in
  /// which case notes are simply not offered, rather than guessed at.
  NotesRangeKey? _notesRangeKey(LDProvider lp) {
    final group = SegmentGroup.fromTabLabel(lp.selectedSegment);
    if (group == null) return null;
    return NotesRangeKey(
      from: _isoDate(lp.startTaxDate),
      to: _isoDate(lp.endTaxDate),
      group: group,
    );
  }

  /// Every day that has a P&L to snapshot, keyed `YYYY-MM-DD`.
  ///
  /// The backend cannot recompute this — realised P&L comes from FIFO matching
  /// across the whole financial year — so the client sends what it displayed.
  ///
  /// Equity/F&O/Currency read `journal[]`, the backend's own per-day rollup and
  /// the source the heat map itself is built from. Commodity reads `dateWise`:
  /// [CalenderpnlModel] synthesises commodity `journal[]` rows with
  /// `unrealisedpnl` hardcoded to `'0'`, so reading those would always send a
  /// zero unrealised.
  ///
  /// Built once per build rather than searched per cell — the calendar renders
  /// a full financial year of them.
  ///
  /// A day absent from this map has no P&L row, so a note on it would be
  /// invisible to analytics. Those days are not offered a note at all.
  Map<String, NotePnlSnapshot> _snapshotsByDate(
      LDProvider lp, SegmentGroup group) {
    final data = lp.calenderpnlAllData;
    if (data == null) return const {};
    final out = <String, NotePnlSnapshot>{};

    if (group.usesJournalDiary3) {
      (data.dateWise ?? const {}).forEach((key, day) {
        final iso = key.toString();
        // `dateWise` carries a literal "unknown" key holding trades whose dates
        // could not be parsed. It is not a date — never offer a note on it.
        if (!kNoteDatePattern.hasMatch(iso)) return;
        if (day is Map) out[iso] = NotePnlSnapshot.fromDateWise(day, group);
      });
      return out;
    }

    for (final row in data.journal ?? const <Journal>[]) {
      // TRADE_DATE is `yyyy-MM-ddTHH:mm:ss`; its date part is the note key.
      final raw = row.tRADEDATE;
      if (raw == null || raw.length < 10) continue;
      final iso = raw.substring(0, 10);
      if (!kNoteDatePattern.hasMatch(iso)) continue;
      out[iso] = NotePnlSnapshot.fromJournalRow(row, group);
    }
    return out;
  }

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
                0: shadcn.FixedTableSize(
                    totalWidth * 0.50), // Arrow + Date + Count
                1: shadcn.FixedTableSize(totalWidth * 0.25), // Unrealised P&L
                2: shadcn.FixedTableSize(totalWidth * 0.25), // Realised P&L
              }
            : {
                0: shadcn.FixedTableSize(
                    totalWidth * 0.60), // Arrow + Date + Count
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
            final dateData =
                (ledgerprovider.calenderpnlAllData!.dateWise as Map)[dateStr];
            tradesForDate = dateData != null && dateData['trades'] != null
                ? (dateData['trades'] as List)
                    .map((trade) => TradeData.fromCommodityJson(trade))
                    .toList()
                : [];
            totalRealisedPnl = dateData?['realised_pnl']?.toDouble() ?? 0.0;
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
                                                dark: MyntColors
                                                    .textSecondaryDark,
                                                light: MyntColors.textSecondary)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${row.tradesForDate.length}',
                                        style: MyntWebTextStyles.caption(
                                            context,
                                            darkColor:
                                                MyntColors.textSecondaryDark,
                                            lightColor:
                                                MyntColors.textSecondary,
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
                                        darkColor: _getPnlColor(
                                            context, row.totalUnrealisedPnl!),
                                        lightColor: _getPnlColor(
                                            context, row.totalUnrealisedPnl!),
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
          isDarkMode(context) ? MyntColors.transparent : MyntColors.overlayBg,
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
                        final newLeft =
                            DateTime(_leftMonth.year, _leftMonth.month - 1);
                        if (newLeft.isBefore(fyStartMonth)) return;
                        setState(() {
                          _leftMonth = newLeft;
                          _rightMonth =
                              DateTime(_leftMonth.year, _leftMonth.month + 1);
                        });
                      },
                      onNext: () {
                        final newLeft =
                            DateTime(_leftMonth.year, _leftMonth.month + 1);
                        final newRight =
                            DateTime(newLeft.year, newLeft.month + 1);
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
                        final newRight =
                            DateTime(_rightMonth.year, _rightMonth.month - 1);
                        final newLeft =
                            DateTime(newRight.year, newRight.month - 1);
                        if (newLeft.isBefore(fyStartMonth)) return;
                        setState(() {
                          _rightMonth = newRight;
                          _leftMonth = newLeft;
                        });
                      },
                      onNext: () {
                        final newRight =
                            DateTime(_rightMonth.year, _rightMonth.month + 1);
                        if (newRight.isAfter(fyEndMonth)) return;
                        setState(() {
                          _rightMonth = newRight;
                          _leftMonth =
                              DateTime(_rightMonth.year, _rightMonth.month - 1);
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
                    for (int y = currentFYStart - 2;
                        y >= currentFYStart - 4;
                        y--)
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
            dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
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
                final dayNum = weekIndex * 7 + dayIndex - firstWeekday + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox(width: 34, height: 34);
                }

                final date = DateTime(month.year, month.month, dayNum);
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final isFuture = date.isAfter(today);
                final isOutsideFY =
                    date.isBefore(fyStart) || date.isAfter(fyEnd);
                final isDisabled = isFuture || isOutsideFY;
                final isStart =
                    _tempStartDate != null && _isSameDay(date, _tempStartDate!);
                final isEnd =
                    _tempEndDate != null && _isSameDay(date, _tempEndDate!);
                final isInRange = _tempStartDate != null &&
                    _tempEndDate != null &&
                    date.isAfter(
                        _tempStartDate!.subtract(const Duration(days: 1))) &&
                    date.isBefore(_tempEndDate!.add(const Duration(days: 1)));

                Color? bgColor;
                Color dayTextColor = textColor;

                if (isStart || isEnd) {
                  bgColor = primaryColor;
                  dayTextColor = Colors.white;
                } else if (isInRange) {
                  bgColor = primaryColor.withValues(alpha: 0.1);
                }

                if (isDisabled) {
                  dayTextColor = secondaryTextColor.withValues(alpha: 0.4);
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // --- Trade Table (shadcn) ---
  Widget _buildTradeTable(BuildContext context, List<TradeData> trades) {
    final isCommodity = ref.read(ledgerProvider).selectedSegment == "Commodity";
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
                final displaySymbol =
                    scripSymbol.isNotEmpty ? scripSymbol : scripName;
                final realisedPnl =
                    double.tryParse(trade.realisedpnl ?? '0') ?? 0.0;
                final unrealisedPnl = trade.safeUnrealisedPnl;
                final rowKey = '${trade.tRADEDATE}_${index}_$scripSymbol';
                final openQty = trade.safeOpenQty;
                final openRate = trade.safeOpenRate;
                final buyAmt = double.tryParse(trade.bAMT ?? '0') ??
                    (trade.safeBuyQty * trade.safeBuyRate);
                final sellAmt = double.tryParse(trade.sAMT ?? '0') ??
                    (trade.safeSellQty * trade.safeSellRate);

                return shadcn.TableRow(
                  cells: [
                    // Symbol cell with company code + open qty badge
                    _buildTableDataCell(
                      rowKey: rowKey,
                      child: Tooltip(
                        message:
                            displaySymbol.isNotEmpty ? displaySymbol : '--',
                        child: GestureDetector(
                          onTap: () => _showSymbolPnlDialog(
                              context, scripSymbol, displaySymbol),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displaySymbol.isNotEmpty
                                          ? displaySymbol
                                          : '--',
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
                                        style: MyntWebTextStyles.caption(
                                            context,
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
                            style: MyntWebTextStyles.caption(
                              context,
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
                            style: MyntWebTextStyles.caption(
                              context,
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
                          unrealisedPnl == 0
                              ? '0'
                              : _formatAmount(unrealisedPnl),
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
    symbolTrades
        .sort((a, b) => (a.tRADEDATE ?? '').compareTo(b.tRADEDATE ?? ''));

    final dark = isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: dark
              ? MyntColors.backgroundColorDark
              : MyntColors.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                              final sellAmt = double.tryParse(t.sAMT ?? '0') ??
                                  (t.safeSellQty * t.safeSellRate);
                              final netQty = t.safeNetQty;
                              final netAmt =
                                  double.tryParse(t.nRATE ?? '0') ?? 0.0;
                              final realisedPnl = t.safeRealisedPnl;
                              final tradeDate = t.tRADEDATE != null
                                  ? t.tRADEDATE!.split('T').first
                                  : '';

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
                                                color: resolveThemeColor(
                                                    context,
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
                                              style: MyntWebTextStyles.caption(
                                                context,
                                                darkColor: MyntColors
                                                    .textSecondaryDark,
                                                lightColor:
                                                    MyntColors.textSecondary,
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
                                          style: MyntWebTextStyles.caption(
                                            context,
                                            darkColor:
                                                MyntColors.textSecondaryDark,
                                            lightColor:
                                                MyntColors.textSecondary,
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
                                          style: MyntWebTextStyles.caption(
                                            context,
                                            darkColor:
                                                MyntColors.textSecondaryDark,
                                            lightColor:
                                                MyntColors.textSecondary,
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
                                          style: MyntWebTextStyles.caption(
                                            context,
                                            darkColor:
                                                MyntColors.textSecondaryDark,
                                            lightColor:
                                                MyntColors.textSecondary,
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
    Color? baseTint,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              // A persistent tint (used for the analytics baseline rows) shows
              // through until hover, which paints its own wash on top.
              color: isHovered
                  ? resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary)
                      .withValues(alpha: 0.06)
                  : baseTint,
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

  /// Days that already carry a journal note, keyed `YYYY-MM-DD`.
  final Set<String> notedDates;

  /// Days that have a P&L to snapshot, and so can be noted. A day outside this
  /// set is not offered a note — one saved there would be invisible to
  /// analytics.
  final Set<String> notableDates;

  /// Null when notes are unavailable for the active tab, which hides the
  /// affordance entirely.
  final ValueChanged<DateTime>? onNoteTap;

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
    this.notedDates = const {},
    this.notableDates = const {},
    this.onNoteTap,
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
              dark: MyntColors.transparent,
              light: MyntColors.transparent),
        ),
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
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
              notedDates: widget.notedDates,
              notableDates: widget.notableDates,
              onNoteTap: widget.onNoteTap,
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
              fontWeight: isActive ? MyntFonts.semiBold : MyntFonts.medium,
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

    final numval = (monthValue == null || monthValue == 0)
        ? "-"
        : monthValue.toStringAsFixed(2);
    var displayText = numval != "-"
        ? NumberFormat.compactCurrency(
                decimalDigits: 2, locale: 'en_IN', symbol: '')
            .format(double.parse(numval))
        : '-';
    if (displayText.contains("T")) {
      displayText = displayText.replaceAll("T", "K");
    }

    final monthAbbrs = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    final monthName = monthAbbrs[monthDate.month - 1];

    Color valueColor;
    if (monthValue == null || monthValue == 0) {
      valueColor = resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    } else {
      valueColor = monthValue < 0
          ? resolveThemeColor(context,
              dark: MyntColors.lossDark, light: MyntColors.loss)
          : resolveThemeColor(context,
              dark: MyntColors.profitDark, light: MyntColors.profit);
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

  /// Days that already carry a journal note, keyed `YYYY-MM-DD`.
  final Set<String> notedDates;

  /// Days that have a P&L to snapshot, and so can be noted.
  final Set<String> notableDates;

  /// Null when notes are unavailable for the active tab.
  final ValueChanged<DateTime>? onNoteTap;

  const _WebDailyCalendar({
    required this.heatmapData,
    required this.startDate,
    required this.endDate,
    required this.currentMonth,
    required this.onMonthChanged,
    this.notedDates = const {},
    this.notableDates = const {},
    this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    // Build all weeks from startDate to endDate
    // Align to Monday of the week containing startDate
    final firstMonday =
        startDate.subtract(Duration(days: (startDate.weekday - 1) % 7));
    final lastSunday = endDate.add(Duration(days: (7 - endDate.weekday) % 7));

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
      final spansMultipleMonths =
          datesInWeek.any((d) => d!.month != firstMonth || d.year != firstYear);

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
            .map((d) =>
                (d != null && d.month == firstMonth && d.year == firstYear)
                    ? d
                    : null)
            .toList();
        final secondMonthWeek = week
            .map((d) =>
                (d != null && (d.month != firstMonth || d.year != firstYear))
                    ? d
                    : null)
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
        final totalWeeks =
            monthGroups.fold<int>(0, (sum, g) => sum + g.weeks.length);
        final totalMonthGaps = (monthGroups.length - 1) * monthGap;
        final availableWidth =
            constraints.maxWidth - dayLabelWidth - totalMonthGaps;

        // Fill the width so the whole financial year is always visible — no
        // horizontal scroll, no hidden months. Cells scale with the panel; the
        // note marker (a corner triangle) stays legible even when they are small.
        final double cellStep = availableWidth / totalWeeks;
        final double cellGap = (cellStep * 0.18).clamp(2.0, 4.0);
        final double cellSize = cellStep - cellGap;

        Widget buildCell(DateTime? date) {
          if (date == null) {
            return SizedBox(
              width: cellStep,
              height: cellSize + cellGap,
            );
          }

          final value = heatmapData[DateTime(date.year, date.month, date.day)];
          final today = DateTime.now();
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          Color bgColor;
          final val = value ?? 0;
          if (val > 0) {
            bgColor = resolveThemeColor(context,
                    dark: MyntColors.profitDark, light: MyntColors.profit)
                .withAlpha(900);
          } else if (val < 0) {
            // final intensity = _getIntensity(value.abs());
            bgColor = resolveThemeColor(context,
                    dark: MyntColors.lossDark, light: MyntColors.loss)
                .withAlpha(900);
          } else {
            // final intensity = _getIntensity(value.abs());
            bgColor = emptyColor;
          }

          final todayBorderColor = resolveThemeColor(context,
              dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

          final iso = _CalenderpnlScreenState._isoDate(date);
          final hasNote = notedDates.contains(iso);
          // A note can only be *added* on a day with a P&L row — one saved
          // elsewhere has no snapshot and would be invisible to analytics. But
          // an existing note must always open, snapshot or not: a day can lose
          // its P&L row (a restated back office, a narrowed date range), and
          // gating on the snapshot alone would strand the note with no way to
          // edit or delete it.
          final canNote =
              onNoteTap != null && (hasNote || notableDates.contains(iso));

          final dateLabel = DateFormat('dd MMM yyyy').format(date);
          final pnlLabel =
              value != null ? '₹${value.toStringAsFixed(2)}' : 'No trades';
          final String tooltip;
          if (hasNote) {
            tooltip = '$dateLabel: $pnlLabel\nNote added — click to edit';
          } else if (canNote) {
            tooltip = '$dateLabel: $pnlLabel\nClick to add a note';
          } else {
            tooltip = '$dateLabel: $pnlLabel';
          }

          return _HoverableHeatmapCell(
            tooltipMessage: tooltip,
            cellSize: cellSize,
            cellGap: cellGap,
            bgColor: bgColor,
            isToday: isToday,
            todayBorderColor: todayBorderColor,
            hasNote: hasNote,
            // The app's primary blue, theme-resolved: deep blue on the light
            // theme, the lighter primaryDark on the dark theme so the dot
            // stays visible on dark cells. The glow supplies edge separation
            // on the green/red fills.
            // noteMarkerColor: MyntColors.noteMarker,
            noteMarkerColor: resolveThemeColor(context,
                dark: MyntColors.primaryDark, light: MyntColors.primary),
            onTap: canNote ? () => onNoteTap!(date) : null,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heatmap grid — day labels pinned left, month groups fill the width.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int m = 0; m < monthGroups.length; m++) ...[
                        Expanded(
                          flex: monthGroups[m].weeks.length,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: monthGroups[m].weeks.map((weekDays) {
                              return Column(
                                children: weekDays
                                    .map((date) => buildCell(date))
                                    .toList(),
                              );
                            }).toList(),
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
            const SizedBox(height: 6),
            // Month labels below the grid — centered under each group.
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
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

  /// Draws a dot in the cell to mark a day that carries a journal note.
  final bool hasNote;

  /// The dot's colour — the page background, so it reads as a punched-out hole
  /// against both the profit and loss fills.
  final Color noteMarkerColor;

  /// Null makes the cell inert: no cursor change, no tap.
  final VoidCallback? onTap;

  const _HoverableHeatmapCell({
    required this.tooltipMessage,
    required this.cellSize,
    required this.cellGap,
    required this.bgColor,
    required this.isToday,
    required this.todayBorderColor,
    this.hasNote = false,
    this.noteMarkerColor = const Color(0xFFFFFFFF),
    this.onTap,
  });

  @override
  State<_HoverableHeatmapCell> createState() => _HoverableHeatmapCellState();
}

class _HoverableHeatmapCellState extends State<_HoverableHeatmapCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // A dot pinned to the top-right of the cell. Small enough that the day's
    // colour stays readable underneath — the glow supplies the visibility, so
    // the core itself must not swallow the box.
    final markerSize = (widget.cellSize * 0.32).clamp(3.5, 5.0);

    return MouseRegion(
      cursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltipMessage,
          child: Container(
            width: widget.cellSize,
            height: widget.cellSize,
            margin:
                EdgeInsets.only(bottom: widget.cellGap, right: widget.cellGap),
            // Clip children (the corner triangle) to the rounded cell.
            clipBehavior: Clip.antiAlias,
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
            child: widget.hasNote
                ? Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      // Flush into the corner (was inset 2/2).
                      padding: EdgeInsets.zero,
                      child: Container(
                        width: markerSize,
                        height: markerSize,
                        decoration: BoxDecoration(
                          color: widget.noteMarkerColor,
                          shape: BoxShape.circle,
                          // A lighter halo of the same hue — reads as a glow
                          // and gives the dot an edge on any fill colour. Kept
                          // tight so core + glow stay a corner badge rather
                          // than covering the box.
                          boxShadow: [
                            BoxShadow(
                              color: widget.noteMarkerColor
                                  .withValues(alpha: 0.55),
                              blurRadius: 2,
                              spreadRadius: 0.8,
                            ),
                          ],
                        ),
                      ),
                    ),
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
