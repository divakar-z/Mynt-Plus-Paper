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
import 'package:mynt_plus/models/insta_options/dashboard/stock_pcr.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';

final marketsDashboardProvider = ChangeNotifierProvider.autoDispose(
  (ref) => MarketsDashboardProvider(),
);

/// Powers the date-based Markets Dashboard (Screen 1).
///
/// On mount: `GET /dates` → select `latest` → `GET /dashboard?date=`. The whole
/// screen comes from that one dashboard call; data is immutable per day, so
/// there is no polling — only a refetch when the calendar date changes.
class MarketsDashboardProvider extends DefaultChangeNotifier {
  final DashboardApi _api = locator<DashboardApi>();

  DatesResponse _dates = DatesResponse.empty;
  String? _selectedDate;
  DashboardData? _data;

  bool _started = false;
  bool _loadingDates = false;
  bool _loadingData = false;
  String? _error;

  // ---- calendar ----
  DatesResponse get dates => _dates;
  String? get selectedDate => _selectedDate;

  /// Available trading days parsed to [DateTime] for the calendar.
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

  // ---- sections (from the single dashboard payload) ----
  DashboardData? get data => _data;
  String? get tradeDate => _data?.tradeDate ?? _selectedDate;
  DaySummary get summary => _data?.summary ?? DaySummary.empty;
  List<IndexCard> get indices => _data?.indices ?? const [];
  BuildupSentiment get sentiment =>
      _data?.buildupSentiment ?? BuildupSentiment.empty;
  StockPcr get stockPcr => _data?.stockPcr ?? StockPcr.empty;
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

  void stop() => _started = false;

  Future<void> _init() async {
    await _loadDates();
    _selectedDate = _dates.latest ??
        (_dates.dates.isNotEmpty ? _dates.dates.last : null);
    await _loadDashboard();
  }

  /// Calendar date change → refetch the whole dashboard for that day.
  Future<void> selectDate(String isoDate) async {
    if (isoDate == _selectedDate) return;
    _selectedDate = isoDate;
    notifyListeners();
    await _loadDashboard();
  }

  Future<void> refresh() async {
    await _loadDates();
    await _loadDashboard();
  }

  Future<void> _loadDates() async {
    _loadingDates = true;
    notifyListeners();
    try {
      _dates = await _api.getDates();
    } catch (_) {
      // Non-fatal: the dashboard still loads the latest day; the calendar just
      // can't restrict selectable days until /dates succeeds.
    } finally {
      _loadingDates = false;
      notifyListeners();
    }
  }

  Future<void> _loadDashboard() async {
    _loadingData = true;
    _error = null;
    notifyListeners();
    try {
      _data = await _api.getDashboard(date: _selectedDate);
      if (_data!.tradeDate.isNotEmpty) _selectedDate = _data!.tradeDate;
    } on DashboardApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingData = false;
      notifyListeners();
    }
  }
}
