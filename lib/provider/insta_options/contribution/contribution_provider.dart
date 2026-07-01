import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/contribution/contribution_api.dart';
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api.dart'
    show DashboardApiException;
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dates_response.dart';
import 'package:mynt_plus/models/insta_options/freshness.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/insta_options/live_polling.dart';

final contributionProvider = ChangeNotifierProvider.autoDispose(
  (ref) => ContributionProvider(),
);

/// Powers the date-based **Index Contribution** (Screen 3).
///
/// On mount: `/dates` → if today's live snapshot is held, default to **Live /
/// Today** (polled); else the latest finalized day. `/contribution?index=&...`.
/// Changing the **index** or the **date** refetches the single contribution call
/// in the current mode.
class ContributionProvider extends DefaultChangeNotifier with LivePolling {
  final ContributionApi _api = locator<ContributionApi>();

  static const String _defaultIndex = 'NIFTY';

  String _index = _defaultIndex;
  DatesResponse _dates = DatesResponse.empty;
  String? _selectedDate;
  bool _liveMode = false;
  IndexContribution? _data;

  bool _started = false;
  bool _loadingDates = false;
  bool _loadingData = false;
  String? _error;

  // ---- selectors / mode ----
  String get index => _index;
  DatesResponse get dates => _dates;
  LiveChannel? get liveChannel => _dates.live;
  bool get liveMode => _liveMode;
  String? get selectedDate => _selectedDate;

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
  String? get freshnessHm => _liveMode ? freshness.hm : null;

  // ---- data ----
  IndexContribution? get data => _data;
  String get tradeDate => _data?.tradeDate ?? _selectedDate ?? '';

  // ---- status ----
  bool get loadingData => _loadingData;
  String? get error => _error;
  bool get isInitialLoading => _data == null && (_loadingDates || _loadingData);
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
    await _loadData();
    _syncPolling();
  }

  Future<void> selectLive() async {
    if (_liveMode) return;
    _liveMode = true;
    _selectedDate = null;
    _data = null;
    notifyListeners();
    await _loadData();
    _syncPolling();
  }

  /// Index change → refetch for the new index, keeping the current mode.
  Future<void> selectIndex(String index) async {
    if (index == _index) return;
    _index = index;
    _data = null; // clear stale data while the new index loads
    notifyListeners();
    await _loadData();
    _syncPolling();
  }

  /// Pick a finalized day → immutable, polling stops.
  Future<void> selectDate(String isoDate) async {
    if (!_liveMode && isoDate == _selectedDate) return;
    _liveMode = false;
    _selectedDate = isoDate;
    notifyListeners();
    stopPolling();
    await _loadData();
  }

  Future<void> refresh() async {
    await _loadDates();
    await _loadData();
    _syncPolling();
  }

  void _syncPolling() {
    if (_liveMode) {
      startPolling(() => _loadData(silent: true));
    } else {
      stopPolling();
    }
  }

  // ---- loaders ----
  Future<void> _loadDates() async {
    _loadingDates = true;
    notifyListeners();
    try {
      _dates = await _api.getDates();
    } catch (_) {
      // Non-fatal: the contribution call still loads; the calendar/live option
      // just can't populate until /dates succeeds.
    } finally {
      _loadingDates = false;
      notifyListeners();
    }
  }

  /// [silent] = a background poll: keep the last good data on a transient
  /// failure, no loader flash.
  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      _loadingData = true;
      _error = null;
      notifyListeners();
    }
    try {
      final data = await _api.getContribution(
          index: _index, date: _liveMode ? null : _selectedDate, live: _liveMode);
      _data = data;
      // Asked live but the server fell back to a finalized day → historical.
      if (_liveMode && !data.freshness.isLive) {
        _liveMode = false;
        stopPolling();
      }
      if (!_liveMode && data.tradeDate.isNotEmpty) _selectedDate = data.tradeDate;
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
