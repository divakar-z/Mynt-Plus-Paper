// Public PnL viewer screen — opens at /dailypnl?ucode=<code>.
//
// Read-only replica of the in-app Calendar PnL summary, rendered for an
// unauthenticated visitor who clicked someone's shared link. The visitor
// cannot change the segment, edit dates, trade, or navigate elsewhere in
// the app — this screen is fully self-contained.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../api/shared_pnl_api.dart';
import '../../../models/shared_pnl_model.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';

class PnlInsightsScreen extends ConsumerStatefulWidget {
  final String? ucode;
  const PnlInsightsScreen({super.key, required this.ucode});

  @override
  ConsumerState<PnlInsightsScreen> createState() => _PnlInsightsScreenState();
}

class _PnlInsightsScreenState extends ConsumerState<PnlInsightsScreen> {
  final SharedPnlApi _api = SharedPnlApi();
  SharedPnlModel? _model;
  bool _loading = true;
  String? _error;

  bool _isMonthly = false;
  bool _isDateWise = true;
  // Index of the currently-expanded Date Wise row (single-expand, like Vue).
  int? _expandedDateIndex;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final code = widget.ucode?.trim();
    if (code == null || code.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing share code in URL.';
      });
      return;
    }
    try {
      final res = await _api.fetchByUcode(code);
      if (!mounted) return;
      setState(() {
        _model = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load shared P&L. Please try again later.';
      });
    }
  }

  // --- Derived data --------------------------------------------------------

  // Parse the share's from_date / to_date (DD/MM/YYYY) into DateTimes so we can
  // filter all rendered sections to the originally-shared date range.
  DateTime? _parseDdMmYyyy(String? s) {
    if (s == null) return null;
    final parts = s.split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  DateTime? get _fromDate => _parseDdMmYyyy(_model?.fromDate);
  DateTime? get _toDate => _parseDdMmYyyy(_model?.toDate);

  // True if [date] falls within the share's stated date range. If either bound
  // is missing, that side is unconstrained. A null date is treated as out-of-range.
  bool _inRange(DateTime? date) {
    if (date == null) return false;
    final from = _fromDate;
    final to = _toDate;
    final dKey = DateTime(date.year, date.month, date.day);
    if (from != null && dKey.isBefore(from)) return false;
    if (to != null && dKey.isAfter(to)) return false;
    return true;
  }

  // Daily heatmap built from journal entries, keyed by midnight date.
  // Filtered to the share's date range — viewers only see what was shared.
  Map<DateTime, double> get _heatmap {
    final out = <DateTime, double>{};
    final journal = _model?.data?.journal ?? const <SharedJournalEntry>[];
    for (final entry in journal) {
      if (!_inRange(entry.tradeDate)) continue;
      final d = entry.tradeDate!;
      final key = DateTime(d.year, d.month, d.day);
      out[key] = (out[key] ?? 0) + entry.realisedPnl;
    }
    return out;
  }

  // Monthly aggregation, keyed "YYYY-MM". Sourced from journal entries within
  // the share's date range so stats stay consistent across all views.
  Map<String, double> get _monthlyPnl {
    final out = <String, double>{};
    for (final entry in _model?.data?.journal ?? const <SharedJournalEntry>[]) {
      if (!_inRange(entry.tradeDate)) continue;
      final d = entry.tradeDate!;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      out[key] = (out[key] ?? 0) + entry.realisedPnl;
    }
    return out;
  }

  // Stats are recomputed from the filtered set so they match what's visible
  // in the Date Wise / Script Wise lists below.
  double get _realisedPnl {
    // For both commodity and non-commodity, journal has per-date realised
    // values — summing journal within range gives the right number.
    final journal = _model?.data?.journal ?? const <SharedJournalEntry>[];
    return journal
        .where((e) => _inRange(e.tradeDate))
        .fold<double>(0, (s, e) => s + e.realisedPnl);
  }

  double get _unrealisedPnl {
    // Commodity hardcodes 0 (matches Vue Daily_pnl.vue:2857). For other
    // segments, sum unrealised across trades whose date is in range.
    if (_model?.isCommodity == true) return 0;
    final trades = _model?.data?.trades ?? const <SharedTrade>[];
    return trades
        .where((t) => _inRange(t.tradeDate))
        .fold<double>(0, (s, t) => s + t.unrealisedPnl);
  }

  double get _totalCharges => _model?.data?.totalCharges ?? 0;
  double get _netRealised => _realisedPnl - _totalCharges;

  // Date Wise — filtered to the share's date range, newest first.
  List<MapEntry<DateTime, List<SharedTrade>>> get _dateWiseRows {
    final groups =
        _model?.data?.dateGrouped ?? const <String, List<SharedTrade>>{};
    final list = <MapEntry<DateTime, List<SharedTrade>>>[];
    groups.forEach((dateStr, trades) {
      DateTime? parsed;
      try {
        parsed = DateTime.parse(dateStr.replaceAll(' ', 'T').split('T').first);
      } catch (_) {}
      if (parsed == null) return;
      if (!_inRange(parsed)) return;
      list.add(MapEntry(parsed, trades));
    });
    list.sort((a, b) => b.key.compareTo(a.key));
    return list;
  }

  // Script Wise:
  //   • Commodity — use Data2 entries directly (already symbol-aggregated from
  //     symbolWise; in-app does the same).
  //   • Non-commodity — re-aggregate per symbol from the date-filtered
  //     Date Wise rows: sum qty/amt across days, recompute avg rates as
  //     amt / qty. Mirrors the in-app aggregation in
  //     calenderPnl_screen.dart:_buildScriptWiseSection (lines 1013-1075).
  List<SharedTrade> get _scriptWiseRows {
    final isCommodity = _model?.isCommodity == true;
    if (isCommodity) {
      return (_model?.data?.trades ?? const <SharedTrade>[])
          .where((t) => t.isLast)
          .toList();
    }

    final groups =
        _model?.data?.dateGrouped ?? const <String, List<SharedTrade>>{};
    final accs = <String, _ScriptAggregate>{};

    groups.forEach((dateKey, trades) {
      DateTime? d;
      try {
        d = DateTime.parse(dateKey.replaceAll(' ', 'T').split('T').first);
      } catch (_) {}
      if (!_inRange(d)) return;

      for (final t in trades) {
        if (t.symbol.isEmpty) continue;
        final buyAmt = t.buyQty * t.buyRate;
        final sellAmt = t.sellQty * t.sellRate;
        final acc = accs.putIfAbsent(
          t.symbol,
          () => _ScriptAggregate(symbol: t.symbol),
        );
        acc.buyQty += t.buyQty;
        acc.buyAmt += buyAmt;
        acc.sellQty += t.sellQty;
        acc.sellAmt += sellAmt;
        acc.netQty += t.netQty;
        acc.closePrice = t.closePrice; // last seen wins, like in-app
        acc.realisedPnl += t.realisedPnl;
        acc.unrealisedPnl += t.unrealisedPnl;
      }
    });

    return accs.values
        .map((a) => SharedTrade(
              symbol: a.symbol,
              tradeDate: null,
              buyQty: a.buyQty,
              buyRate: a.buyQty > 0 ? a.buyAmt / a.buyQty : 0,
              sellQty: a.sellQty,
              sellRate: a.sellQty > 0 ? a.sellAmt / a.sellQty : 0,
              netQty: a.netQty,
              closePrice: a.closePrice,
              realisedPnl: a.realisedPnl,
              unrealisedPnl: a.unrealisedPnl,
              openQty: 0,
              openRate: 0,
              isLast: true,
            ))
        .toList()
      ..sort((a, b) => a.symbol.compareTo(b.symbol));
  }

  // Heatmap window mirrors Vue's cal-heatmap config (Daily_pnl.vue:2392).
  // Anchors on the financial year containing from_date:
  //   - if from/to year match and from_date.month < 4 → previous FY (Apr of year-1)
  //   - else → current FY (Apr of from_date.year)
  // Range is fixed at 12 months (Vue: range: 12).
  // Falls back to the FY of the earliest journal entry when from_date is absent
  // (commodity responses sometimes omit it).
  ({DateTime start, DateTime end}) get _heatmapWindow {
    final fromParts = (_model?.fromDate ?? '').split('/');
    final toParts = (_model?.toDate ?? '').split('/');

    int? fromMonth;
    int? fromYear;
    int? toYear;
    if (fromParts.length >= 3) {
      fromMonth = int.tryParse(fromParts[1]);
      fromYear = int.tryParse(fromParts[2]);
    }
    if (toParts.length >= 3) {
      toYear = int.tryParse(toParts[2]);
    }

    if (fromYear == null || fromMonth == null) {
      final journalDates = (_model?.data?.journal ?? const <SharedJournalEntry>[])
          .map((e) => e.tradeDate)
          .whereType<DateTime>()
          .toList();
      if (journalDates.isNotEmpty) {
        journalDates.sort();
        final earliest = journalDates.first;
        fromMonth = earliest.month;
        fromYear = earliest.year;
        toYear ??= journalDates.last.year;
      } else {
        final now = DateTime.now();
        fromMonth = now.month;
        fromYear = now.year;
      }
    }
    toYear ??= fromYear;

    final DateTime start = (fromYear == toYear)
        ? ((fromMonth < 4)
            ? DateTime(fromYear - 1, 4, 1)
            : DateTime(fromYear, 4, 1))
        : DateTime(fromYear, 4, 1);
    final end = DateTime(start.year + 1, 3, 31);
    return (start: start, end: end);
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return _buildEmpty(_error!);
    }
    final m = _model;
    if (m == null || m.isSharingTurnedOff || m.data == null) {
      return Column(
        children: [
          _buildAppBar(uname: m?.uname ?? ''),
          Expanded(child: _buildEmpty('Sharing is turned off.')),
        ],
      );
    }

    return Column(
      children: [
        _buildAppBar(uname: m.uname ?? ''),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleRow(m),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: resolveThemeColor(context,
                      dark: MyntColors.cardBorderDark,
                      light: MyntColors.cardBorder),
                ),
                const SizedBox(height: 20),
                _buildStatCards(),
                const SizedBox(height: 20),
                _buildDailyMonthlyTabs(),
                const SizedBox(height: 8),
                _buildHeatmapCard(),
                const SizedBox(height: 24),
                _buildDateScriptTabs(),
                const SizedBox(height: 12),
                _isDateWise ? _buildDateWiseList() : _buildScriptWiseTable(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- App bar -------------------------------------------------------------

  Widget _buildAppBar({required String uname}) {
    final initial = uname.isNotEmpty ? uname[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: resolveThemeColor(
            context, dark: MyntColors.cardDark, light: MyntColors.card),
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
          SvgPicture.asset(
            'assets/icon/Mynt New logo.svg',
            height: 28,
          ),
          const Spacer(),
          if (uname.isNotEmpty) ...[
            Text(
              uname.toUpperCase(),
              style: MyntWebTextStyles.bodySmall(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 16,
              backgroundColor: resolveThemeColor(context,
                  dark: MyntColors.cardHoverDark,
                  light: MyntColors.cardHover),
              child: Text(
                initial,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Title + segment / search / date row ---------------------------------

  Widget _buildTitleRow(SharedPnlModel m) {
    final dateRange = (m.fromDate != null && m.toDate != null)
        ? '${m.fromDate}_to_${m.toDate}'
        : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'P&L Insights',
                style: MyntWebTextStyles.title(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.semiBold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Straight to the point about profit and loss analysis.',
                style: MyntWebTextStyles.caption(
                  context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _readonlyChip(
          icon: null,
          text: m.segment ?? 'Equity',
          width: 140,
          showCaret: true,
        ),
        const SizedBox(width: 8),
        _readonlyChip(
          icon: Icons.calendar_today,
          text: dateRange.isEmpty ? '-' : dateRange,
          width: 220,
        ),
      ],
    );
  }

  Widget _readonlyChip(
      {required IconData? icon,
      required String text,
      required double width,
      bool showCaret = false}) {
    return Container(
      width: width,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: resolveThemeColor(context,
              dark: MyntColors.cardBorderDark,
              light: MyntColors.cardBorder),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 14,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.bodySmall(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
              ),
            ),
          ),
          if (showCaret)
            Icon(Icons.keyboard_arrow_down,
                size: 16,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary)),
        ],
      ),
    );
  }

  // --- Stat cards ----------------------------------------------------------

  Widget _buildStatCards() {
    return LayoutBuilder(builder: (context, c) {
      const spacing = 16.0;
      final cardWidth = (c.maxWidth - spacing * 3) / 4;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          _statCard('Realised P&L', _realisedPnl, cardWidth, _signColor(_realisedPnl)),
          _statCard('Unrealised P&L', _unrealisedPnl, cardWidth, _signColor(_unrealisedPnl)),
          _statCard('Charges & taxes', _totalCharges, cardWidth,
              _redIfNonZero(_totalCharges)),
          _statCard('Net Realised P&L', _netRealised, cardWidth, _signColor(_netRealised)),
        ],
      );
    });
  }

  Widget _statCard(String label, double value, double width, Color valueColor) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: resolveThemeColor(
            context, dark: MyntColors.cardDark, light: MyntColors.card),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: resolveThemeColor(context,
              dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
              fontWeight: MyntFonts.medium,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            _formatAmount(value),
            style: MyntWebTextStyles.head(
              context,
              darkColor: valueColor,
              lightColor: valueColor,
              fontWeight: MyntFonts.medium,
            ),
          ),
        ],
      ),
    );
  }

  Color _signColor(double v) {
    if (v > 0) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    }
    if (v < 0) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    }
    return resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
  }

  Color _redIfNonZero(double v) => v == 0
      ? resolveThemeColor(context,
          dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)
      : resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);

  // Indian rupee formatter — matches the in-app `_formatAmount`
  // (calenderPnl_screen.dart): "₹1,23,456.78" with negatives as "-₹...".
  static final NumberFormat _inrFormat = NumberFormat('#,##,##0.00', 'en_IN');
  String _formatAmount(double value) {
    final prefix = value < 0 ? '-₹' : '₹';
    return '$prefix${_inrFormat.format(value.abs())}';
  }

  // --- Daily/Monthly tabs + heatmap ----------------------------------------

  Widget _buildDailyMonthlyTabs() {
    return Row(
      children: [
        _underlineTab('Daily', !_isMonthly,
            onTap: () => setState(() => _isMonthly = false)),
        const SizedBox(width: 24),
        _underlineTab('Monthly', _isMonthly,
            onTap: () => setState(() => _isMonthly = true)),
      ],
    );
  }

  Widget _underlineTab(String label, bool active, {required VoidCallback onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active
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
              fontWeight: active ? MyntFonts.semiBold : MyntFonts.medium,
            ).copyWith(
              color: active
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

  Widget _buildHeatmapCard() {
    final w = _heatmapWindow;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: resolveThemeColor(
            context, dark: MyntColors.cardDark, light: MyntColors.card),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: resolveThemeColor(context,
              dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder),
        ),
      ),
      child: _isMonthly
          ? _MonthlyGrid(monthlyPnl: _monthlyPnl, startFy: w.start, endFy: w.end)
          : _DailyHeatmap(
              heatmap: _heatmap,
              startDate: w.start,
              endDate: w.end,
            ),
    );
  }

  // --- Date Wise / Script Wise ---------------------------------------------

  Widget _buildDateScriptTabs() {
    return Row(
      children: [
        _underlineTab('Date Wise', _isDateWise,
            onTap: () => setState(() => _isDateWise = true)),
        const SizedBox(width: 24),
        _underlineTab('Script Wise', !_isDateWise,
            onTap: () => setState(() => _isDateWise = false)),
      ],
    );
  }

  Widget _buildDateWiseList() {
    final rows = _dateWiseRows;
    if (rows.isEmpty) {
      return _buildEmpty('No trades in this period.');
    }
    final divider = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: divider),
      ),
      child: Column(
        children: [
          _dateWiseHeader(),
          Divider(height: 1, color: divider),
          for (int i = 0; i < rows.length; i++) ...[
            _dateWiseRow(rows[i], i),
            if (i < rows.length - 1)
              Divider(height: 1, color: divider),
          ],
        ],
      ),
    );
  }

  Widget _dateWiseHeader() {
    final isCommodity = _model?.isCommodity == true;
    final headerStyle = MyntWebTextStyles.bodySmall(
      context,
      darkColor: MyntColors.textSecondaryDark,
      lightColor: MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 24), // chevron column
          Expanded(child: Text('Date', style: headerStyle)),
          if (isCommodity) ...[
            SizedBox(
              width: 140,
              child: Text(
                'Unrealised P&L',
                textAlign: TextAlign.right,
                style: headerStyle,
              ),
            ),
            const SizedBox(width: 24),
          ],
          SizedBox(
            width: 120,
            child: Text(
              'Realised P&L',
              textAlign: TextAlign.right,
              style: headerStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateWiseRow(
      MapEntry<DateTime, List<SharedTrade>> entry, int index) {
    final date = entry.key;
    final trades = entry.value;
    final realised = trades.fold<double>(0, (s, t) => s + t.realisedPnl);
    final unrealised = trades.fold<double>(0, (s, t) => s + t.unrealisedPnl);
    final dateText = DateFormat('dd/MM/yyyy').format(date);
    final expanded = _expandedDateIndex == index;

    final divider = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              _expandedDateIndex = expanded ? null : index;
            }),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: AnimatedRotation(
                      turns: expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          dateText,
                          style: MyntWebTextStyles.body(
                            context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
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
                            '${trades.length}',
                            style: MyntWebTextStyles.caption(
                              context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_model?.isCommodity == true) ...[
                    SizedBox(
                      width: 140,
                      child: Text(
                        _formatAmount(unrealised),
                        textAlign: TextAlign.right,
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          darkColor: _signColor(unrealised),
                          lightColor: _signColor(unrealised),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                  SizedBox(
                    width: 120,
                    child: Text(
                      _formatAmount(realised),
                      textAlign: TextAlign.right,
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        darkColor: _signColor(realised),
                        lightColor: _signColor(realised),
                        fontWeight: MyntFonts.semiBold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[
          Divider(height: 1, color: divider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: _buildInnerTradeTable(trades),
          ),
        ],
      ],
    );
  }

  Widget _buildInnerTradeTable(List<SharedTrade> trades) {
    final isCommodity = _model?.isCommodity == true;
    return shadcn.OutlinedContainer(
      child: shadcn.Table(
        defaultRowHeight: const shadcn.FixedTableSize(60),
        columnWidths: isCommodity
            ? const {
                0: shadcn.FlexTableSize(flex: 20),
                1: shadcn.FlexTableSize(flex: 9),
                2: shadcn.FlexTableSize(flex: 11),
                3: shadcn.FlexTableSize(flex: 9),
                4: shadcn.FlexTableSize(flex: 11),
                5: shadcn.FlexTableSize(flex: 9),
                6: shadcn.FlexTableSize(flex: 10),
                7: shadcn.FlexTableSize(flex: 11),
                8: shadcn.FlexTableSize(flex: 10),
              }
            : const {
                0: shadcn.FlexTableSize(flex: 22),
                1: shadcn.FlexTableSize(flex: 10),
                2: shadcn.FlexTableSize(flex: 12),
                3: shadcn.FlexTableSize(flex: 10),
                4: shadcn.FlexTableSize(flex: 12),
                5: shadcn.FlexTableSize(flex: 10),
                6: shadcn.FlexTableSize(flex: 12),
                7: shadcn.FlexTableSize(flex: 12),
              },
        rows: [
          shadcn.TableHeader(cells: [
            _headerCell('Symbol'),
            _headerCell('Buy Qty', alignRight: true),
            _headerCell('Buy Rate', alignRight: true),
            _headerCell('Sell Qty', alignRight: true),
            _headerCell('Sell Rate', alignRight: true),
            _headerCell('Net Qty', alignRight: true),
            _headerCell('Close Price', alignRight: true),
            if (isCommodity)
              _headerCell('Unrealised P&L', alignRight: true),
            _headerCell('Realised P&L', alignRight: true),
          ]),
          for (final t in trades)
            shadcn.TableRow(cells: [
              shadcn.TableCell(
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          t.symbol,
                          overflow: TextOverflow.ellipsis,
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary,
                            fontWeight: MyntFonts.semiBold,
                          ),
                        ),
                      ),
                      if (t.openQty > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: resolveThemeColor(context,
                                  dark: MyntColors.profitDark,
                                  light: MyntColors.profit),
                            ),
                          ),
                          child: Text(
                            '${t.openQty.toStringAsFixed(0)} @ ${t.openRate.toStringAsFixed(2)}',
                            style: MyntWebTextStyles.caption(
                              context,
                              darkColor: MyntColors.profitDark,
                              lightColor: MyntColors.profit,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _dataCell(t.buyQty.toStringAsFixed(0), alignRight: true),
              _twoLineCell(
                t.buyRate.toStringAsFixed(2),
                _inrFormat.format(t.buyRate * t.buyQty),
                alignRight: true,
              ),
              _dataCell(t.sellQty.toStringAsFixed(0), alignRight: true),
              _twoLineCell(
                t.sellRate.toStringAsFixed(2),
                _inrFormat.format(t.sellRate * t.sellQty),
                alignRight: true,
              ),
              _dataCell(t.netQty.toStringAsFixed(0), alignRight: true),
              _dataCell(t.closePrice.toStringAsFixed(2), alignRight: true),
              if (isCommodity)
                _dataCell(
                  _formatAmount(t.unrealisedPnl),
                  alignRight: true,
                  color: _signColor(t.unrealisedPnl),
                ),
              _dataCell(
                _formatAmount(t.realisedPnl),
                alignRight: true,
                color: _signColor(t.realisedPnl),
              ),
            ]),
        ],
      ),
    );
  }

  shadcn.TableCell _twoLineCell(String top, String bottom,
      {bool alignRight = false}) {
    final align =
        alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return shadcn.TableCell(
      child: Container(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: align,
          children: [
            Text(
              top,
              style: MyntWebTextStyles.bodySmall(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
              ),
            ),
            Text(
              bottom,
              style: MyntWebTextStyles.caption(
                context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScriptWiseTable() {
    final rows = _scriptWiseRows;
    final isCommodity = _model?.isCommodity == true;
    if (rows.isEmpty) {
      return _buildEmpty(
          'No trades in this period.');
    }
    return shadcn.OutlinedContainer(
      child: shadcn.Table(
        defaultRowHeight: const shadcn.FixedTableSize(60),
        columnWidths: {
          0: const shadcn.FlexTableSize(flex: 22),
          1: const shadcn.FlexTableSize(flex: 9),
          2: const shadcn.FlexTableSize(flex: 11),
          3: const shadcn.FlexTableSize(flex: 9),
          4: const shadcn.FlexTableSize(flex: 11),
          5: const shadcn.FlexTableSize(flex: 9),
          6: const shadcn.FlexTableSize(flex: 10),
          7: const shadcn.FlexTableSize(flex: 11),
          if (isCommodity)
            8: const shadcn.FlexTableSize(flex: 10),
        },
        rows: [
          shadcn.TableHeader(cells: [
            _headerCell('Script Symbol'),
            _headerCell('Buy qty', alignRight: true),
            _headerCell('Buy rate', alignRight: true),
            _headerCell('Sell qty', alignRight: true),
            _headerCell('Sell rate', alignRight: true),
            _headerCell('Net Qty', alignRight: true),
            _headerCell('Close Price', alignRight: true),
            if (isCommodity)
              _headerCell('Unrealised P&L', alignRight: true),
            _headerCell('Realised P&L', alignRight: true),
          ]),
          for (final r in rows)
            shadcn.TableRow(cells: [
              _dataCell(r.symbol),
              _dataCell(r.buyQty.toStringAsFixed(0), alignRight: true),
              _twoLineCell(
                r.buyRate.toStringAsFixed(2),
                _inrFormat.format(r.buyRate * r.buyQty),
                alignRight: true,
              ),
              _dataCell(r.sellQty.toStringAsFixed(0), alignRight: true),
              _twoLineCell(
                r.sellRate.toStringAsFixed(2),
                _inrFormat.format(r.sellRate * r.sellQty),
                alignRight: true,
              ),
              _dataCell(r.netQty.toStringAsFixed(0), alignRight: true),
              _dataCell(r.closePrice.toStringAsFixed(2), alignRight: true),
              if (isCommodity)
                _dataCell(
                  _formatAmount(r.unrealisedPnl),
                  alignRight: true,
                  color: _signColor(r.unrealisedPnl),
                ),
              _dataCell(
                _formatAmount(r.realisedPnl),
                alignRight: true,
                color: _signColor(r.realisedPnl),
              ),
            ]),
        ],
      ),
    );
  }

  shadcn.TableCell _headerCell(String text, {bool alignRight = false}) {
    return shadcn.TableCell(
      child: Container(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          text,
          style: MyntWebTextStyles.bodySmall(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
            fontWeight: MyntFonts.semiBold,
          ),
        ),
      ),
    );
  }

  shadcn.TableCell _dataCell(String text,
      {bool alignRight = false, Color? color}) {
    return shadcn.TableCell(
      child: Container(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: MyntWebTextStyles.bodySmall(
            context,
            darkColor: color ?? MyntColors.textPrimaryDark,
            lightColor: color ?? MyntColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // --- Empty / error states -----------------------------------------------

  Widget _buildEmpty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.body(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily heatmap — GitHub-style contribution graph for the financial year.
// ---------------------------------------------------------------------------
class _DailyHeatmap extends StatelessWidget {
  final Map<DateTime, double> heatmap;
  final DateTime startDate;
  final DateTime endDate;

  const _DailyHeatmap({
    required this.heatmap,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final firstMonday =
        startDate.subtract(Duration(days: (startDate.weekday - 1) % 7));
    final lastSunday = endDate.add(Duration(days: (7 - endDate.weekday) % 7));

    // Collect weeks (each week has 7 day slots).
    final weeks = <List<DateTime?>>[];
    DateTime cur = firstMonday;
    while (!cur.isAfter(lastSunday)) {
      final w = <DateTime?>[];
      for (int d = 0; d < 7; d++) {
        final day = cur.add(Duration(days: d));
        w.add((day.isBefore(startDate) || day.isAfter(endDate)) ? null : day);
      }
      weeks.add(w);
      cur = cur.add(const Duration(days: 7));
    }

    // Group weeks by month for label rendering.
    final monthGroups = <_MonthGroup>[];
    int? curMonth;
    int? curYear;
    var curWeeks = <List<DateTime?>>[];
    for (final w in weeks) {
      final firstReal = w.firstWhere((d) => d != null, orElse: () => null);
      if (firstReal == null) {
        curWeeks.add(w);
        continue;
      }
      if (firstReal.month != curMonth || firstReal.year != curYear) {
        if (curWeeks.isNotEmpty && curMonth != null) {
          monthGroups.add(
              _MonthGroup(month: curMonth, year: curYear!, weeks: curWeeks));
        }
        curMonth = firstReal.month;
        curYear = firstReal.year;
        curWeeks = [w];
      } else {
        curWeeks.add(w);
      }
    }
    if (curWeeks.isNotEmpty && curMonth != null) {
      monthGroups
          .add(_MonthGroup(month: curMonth, year: curYear!, weeks: curWeeks));
    }

    const dayLabels = ['Mon', '', 'Wed', '', 'Fri', '', ''];
    const dayLabelWidth = 36.0;
    const monthGap = 6.0;

    final emptyColor = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return LayoutBuilder(builder: (context, constraints) {
      final totalWeeks = monthGroups.fold<int>(0, (s, g) => s + g.weeks.length);
      if (totalWeeks == 0) return const SizedBox(height: 120);
      final totalGap = (monthGroups.length - 1) * monthGap;
      final available = constraints.maxWidth - dayLabelWidth - totalGap;
      final step = available / totalWeeks;
      final gap = (step * 0.18).clamp(2.0, 4.0);
      final cell = step - gap;

      Widget buildCell(DateTime? date) {
        if (date == null) {
          return SizedBox(width: step, height: cell + gap);
        }
        final v = heatmap[DateTime(date.year, date.month, date.day)] ?? 0;
        Color bg;
        if (v > 0) {
          bg = resolveThemeColor(context,
              dark: MyntColors.profitDark, light: MyntColors.profit);
        } else if (v < 0) {
          bg = resolveThemeColor(context,
              dark: MyntColors.lossDark, light: MyntColors.loss);
        } else {
          bg = emptyColor;
        }
        return Tooltip(
          message:
              '${DateFormat('dd MMM yyyy').format(date)}: ${v != 0 ? v.toStringAsFixed(2) : 'No trades'}',
          child: Container(
            width: cell,
            height: cell,
            margin: EdgeInsets.only(right: gap, bottom: gap),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: dayLabelWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final lbl in dayLabels)
                      SizedBox(
                        height: cell + gap,
                        child: Text(
                          lbl,
                          style: TextStyle(fontSize: 10, color: secondary),
                        ),
                      ),
                  ],
                ),
              ),
              for (int gi = 0; gi < monthGroups.length; gi++) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int row = 0; row < 7; row++)
                      Row(
                        children: [
                          for (final week in monthGroups[gi].weeks)
                            buildCell(week[row]),
                        ],
                      ),
                  ],
                ),
                if (gi < monthGroups.length - 1) const SizedBox(width: monthGap),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: dayLabelWidth),
            child: Row(
              children: [
                for (int gi = 0; gi < monthGroups.length; gi++) ...[
                  SizedBox(
                    width: monthGroups[gi].weeks.length * step,
                    child: Text(
                      _monthShort(monthGroups[gi].month),
                      style: TextStyle(fontSize: 10, color: secondary),
                    ),
                  ),
                  if (gi < monthGroups.length - 1) const SizedBox(width: monthGap),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  String _monthShort(int month) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return m[month - 1];
  }
}

class _MonthGroup {
  final int month;
  final int year;
  final List<List<DateTime?>> weeks;
  _MonthGroup({required this.month, required this.year, required this.weeks});
}

// Mutable per-symbol accumulator for Script Wise aggregation.
// Mirrors the in-app `_ScriptWiseRowData` accumulator shape used in
// calenderPnl_screen.dart:_buildScriptWiseSection.
class _ScriptAggregate {
  final String symbol;
  double buyQty = 0;
  double buyAmt = 0;
  double sellQty = 0;
  double sellAmt = 0;
  double netQty = 0;
  double closePrice = 0;
  double realisedPnl = 0;
  double unrealisedPnl = 0;
  _ScriptAggregate({required this.symbol});
}

// ---------------------------------------------------------------------------
// Monthly grid — 12 month tiles with aggregated PnL.
// ---------------------------------------------------------------------------
class _MonthlyGrid extends StatelessWidget {
  final Map<String, double> monthlyPnl;
  final DateTime startFy;
  final DateTime endFy;

  const _MonthlyGrid({
    required this.monthlyPnl,
    required this.startFy,
    required this.endFy,
  });

  @override
  Widget build(BuildContext context) {
    final months = <DateTime>[];
    DateTime cur = DateTime(startFy.year, startFy.month, 1);
    while (!cur.isAfter(endFy)) {
      months.add(cur);
      cur = DateTime(cur.year, cur.month + 1, 1);
    }
    return LayoutBuilder(builder: (context, c) {
      const cols = 6;
      const spacing = 8.0;
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: months.map((m) {
          final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
          final v = monthlyPnl[key];
          final disp = (v == null || v == 0) ? '-' : v.toStringAsFixed(2);
          Color color;
          if (v == null || v == 0) {
            color = resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary);
          } else if (v < 0) {
            color = resolveThemeColor(context,
                dark: MyntColors.lossDark, light: MyntColors.loss);
          } else {
            color = resolveThemeColor(context,
                dark: MyntColors.profitDark, light: MyntColors.profit);
          }
          return SizedBox(
            width: w,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                color: resolveThemeColor(context,
                    dark: MyntColors.cardHoverDark,
                    light: MyntColors.cardHover),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_monthShort(m.month),
                      style: MyntWebTextStyles.body(
                        context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 4),
                  Text(disp,
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        darkColor: color,
                        lightColor: color,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  String _monthShort(int month) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return m[month - 1];
  }
}
