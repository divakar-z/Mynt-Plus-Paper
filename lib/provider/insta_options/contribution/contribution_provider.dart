import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/contribution/contribution_api.dart';
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api.dart'
    show DashboardApiException;
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dates_response.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';

final contributionProvider = ChangeNotifierProvider.autoDispose(
  (ref) => ContributionProvider(),
);

/// Powers the date-based **Index Contribution** (Screen 3).
///
/// On mount: `/dates` → latest → `/contribution?index=&date=`. Changing the
/// **index** or the **date** refetches the single contribution call. Data is
/// historical (immutable per day), so there is no polling.
class ContributionProvider extends DefaultChangeNotifier {
  final ContributionApi _api = locator<ContributionApi>();

  static const String _defaultIndex = 'NIFTY';

  String _index = _defaultIndex;
  DatesResponse _dates = DatesResponse.empty;
  String? _selectedDate;
  IndexContribution? _data;

  bool _started = false;
  bool _loadingDates = false;
  bool _loadingData = false;
  String? _error;

  // ---- selectors ----
  String get index => _index;
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

  // ---- data ----
  IndexContribution? get data => _data;
  String get tradeDate => _data?.tradeDate ?? _selectedDate ?? '';

  // ---- status ----
  bool get loadingData => _loadingData;
  String? get error => _error;
  bool get isInitialLoading =>
      _data == null && (_loadingDates || _loadingData);
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
    await _loadData();
  }

  /// Index change → refetch the contribution call for the new index.
  Future<void> selectIndex(String index) async {
    if (index == _index) return;
    _index = index;
    _data = null; // clear stale data while the new index loads
    notifyListeners();
    await _loadData();
  }

  /// Date change → refetch the contribution call for the new day.
  Future<void> selectDate(String isoDate) async {
    if (isoDate == _selectedDate) return;
    _selectedDate = isoDate;
    notifyListeners();
    await _loadData();
  }

  Future<void> refresh() async {
    await _loadDates();
    await _loadData();
  }

  // ---- loaders ----
  Future<void> _loadDates() async {
    _loadingDates = true;
    notifyListeners();
    try {
      _dates = await _api.getDates();
    } catch (_) {
      // Non-fatal: the contribution call still loads the latest day; the
      // calendar just can't restrict selectable days until /dates succeeds.
    } finally {
      _loadingDates = false;
      notifyListeners();
    }
  }

  Future<void> _loadData() async {
    _loadingData = true;
    _error = null;
    notifyListeners();
    try {
      _data = await _api.getContribution(index: _index, date: _selectedDate);
      // Sync the selected day from the authoritative response.
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
