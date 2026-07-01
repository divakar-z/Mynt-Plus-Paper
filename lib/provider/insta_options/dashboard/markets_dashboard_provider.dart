import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/dashboard/buildup_sentiment.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dashboard_data.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dates_response.dart';
import 'package:mynt_plus/models/insta_options/dashboard/day_summary.dart';
import 'package:mynt_plus/models/insta_options/dashboard/gainers_losers.dart';
import 'package:mynt_plus/models/insta_options/dashboard/index_card.dart';
import 'package:mynt_plus/models/insta_options/dashboard/most_active.dart';
import 'package:mynt_plus/models/insta_options/dashboard/sector_performance.dart';
import 'package:mynt_plus/models/insta_options/freshness.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/insta_options/live_polling.dart';

final marketsDashboardProvider = ChangeNotifierProvider.autoDispose(
  (ref) => MarketsDashboardProvider(),
);

/// Powers the date-based Markets Dashboard (Screen 1).
///
/// On mount: `GET /dates` → if today's live snapshot is held, default to **Live
/// / Today** and poll it; otherwise select the latest finalized day (immutable,
/// no polling). A finalized day is fetched once; live mode refetches every ~90s
/// (see [LivePolling]). The whole screen comes from one `/dashboard` call.
class MarketsDashboardProvider extends DefaultChangeNotifier with LivePolling {
  final DashboardApi _api = locator<DashboardApi>();

  DatesResponse _dates = DatesResponse.empty;
  String? _selectedDate;
  bool _liveMode = false;
  DashboardData? _data;

  bool _started = false;
  bool _loadingDates = false;
  bool _loadingData = false;
  String? _error;

  // ---- calendar / mode ----
  DatesResponse get dates => _dates;
  LiveChannel? get liveChannel => _dates.live;
  bool get liveMode => _liveMode;
  String? get selectedDate => _selectedDate;

  /// Finalized (historical) trading days for the calendar.
  List<DateTime> get availableDates {
    final out = <DateTime>[];
    for (final s in _dates.dates) {
      final d = DateTime.tryParse(s);
      if (d != null) out.add(d);
    }
    return out;
  }

  DateTime? get selectedDateTime =>
      _selectedDate == null ? null : DateTime.tryParse(_selectedDate!);

  Freshness get freshness => _data?.freshness ?? Freshness.empty;

  /// `HH:mm` of the live snapshot (LIVE-pill time); null on a finalized day.
  String? get freshnessHm => _liveMode ? freshness.hm : null;

  // ---- sections (from the single dashboard payload) ----
  DashboardData? get data => _data;
  String? get tradeDate => _data?.tradeDate ?? _selectedDate;
  DaySummary get summary => _data?.summary ?? DaySummary.empty;
  List<IndexCard> get indices => _data?.indices ?? const [];
  BuildupSentiment get sentiment =>
      _data?.buildupSentiment ?? BuildupSentiment.empty;
  List<SectorPerformanceRow> get sectorPerformance =>
      _data?.sectorPerformance ?? const [];
  MostActive get mostActive => _data?.mostActive ?? MostActive.empty;
  GainersLosers get gainersLosers => _data?.gainersLosers ?? GainersLosers.empty;

  // ---- status ----
  bool get loadingData => _loadingData;
  bool get loadingDates => _loadingDates;
  String? get error => _error;
  bool get isInitialLoading => _data == null && (_loadingData || _loadingDates);
  bool get isFatalError => _data == null && _error != null;

  void start() {
    if (_started) return;
    _started = true;
    _init();
  }

  void stop() {
    _started = false;
    stopPolling();
  }

  Future<void> _init() async {
    await _loadDates();
    if (_dates.hasLive) {
      _liveMode = true;
      _selectedDate = null;
    } else {
      _liveMode = false;
      _selectedDate =
          _dates.latest ?? (_dates.dates.isNotEmpty ? _dates.dates.last : null);
    }
    await _loadDashboard();
    _syncPolling();
  }

  /// Switch to today's live snapshot (polled).
  Future<void> selectLive() async {
    if (_liveMode) return;
    _liveMode = true;
    _selectedDate = null;
    notifyListeners();
    await _loadDashboard();
    _syncPolling();
  }

  /// Pick a finalized day → immutable, polling stops.
  Future<void> selectDate(String isoDate) async {
    if (!_liveMode && isoDate == _selectedDate) return;
    _liveMode = false;
    _selectedDate = isoDate;
    notifyListeners();
    stopPolling();
    await _loadDashboard();
  }

  Future<void> refresh() async {
    await _loadDates();
    await _loadDashboard();
    _syncPolling();
  }

  void _syncPolling() {
    if (_liveMode) {
      startPolling(() => _loadDashboard(silent: true));
    } else {
      stopPolling();
    }
  }

  Future<void> _loadDates() async {
    _loadingDates = true;
    notifyListeners();
    try {
      _dates = await _api.getDates();
    } catch (_) {
      // Non-fatal: the dashboard still loads; the calendar/live option just
      // can't populate until /dates succeeds.
    } finally {
      _loadingDates = false;
      notifyListeners();
    }
  }

  /// [silent] = a background poll: don't flash the loader or clobber the last
  /// good data on a transient failure.
  Future<void> _loadDashboard({bool silent = false}) async {
    if (!silent) {
      _loadingData = true;
      _error = null;
      notifyListeners();
    }
    try {
      final data =
          await _api.getDashboard(date: _liveMode ? null : _selectedDate, live: _liveMode);
      _data = data;
      // Asked live but the server fell back to a finalized day (no live data
      // yet) → render it as historical and stop polling.
      if (_liveMode && !data.freshness.isLive) {
        _liveMode = false;
        stopPolling();
      }
      if (!_liveMode) {
        final td = data.freshness.tradeDate.isNotEmpty
            ? data.freshness.tradeDate
            : data.tradeDate;
        if (td.isNotEmpty) _selectedDate = td;
      }
    } on DashboardApiException catch (e) {
      if (!silent) _error = e.message;
    } catch (e) {
      if (!silent) _error = e.toString();
    } finally {
      if (!silent) _loadingData = false;
      notifyListeners();
    }
  }
}
