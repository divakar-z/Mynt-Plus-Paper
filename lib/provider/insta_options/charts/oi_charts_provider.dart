import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/charts/charts_api.dart';
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api.dart'
    show DashboardApiException;
import 'package:mynt_plus/api/insta_options/option_chain/option_chain_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/charts/oi_by_strike.dart';
import 'package:mynt_plus/models/insta_options/charts/oi_timeline.dart';
import 'package:mynt_plus/models/insta_options/charts/pcr_timeline.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dates_response.dart';
import 'package:mynt_plus/models/insta_options/option_chain/expiry_option.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';

/// One source of truth for the three OI-chart screens (OI Statistics, PCR Ratio,
/// Trending OI). Holds the shared `underlying / date / expiry / interval /
/// strikes` selection plus a slot per endpoint, fetched on demand: a screen
/// calls its `open*()` on mount, and selection changes refetch only the slots
/// that have been opened. Dates + expiries reuse [OptionChainApi]; not
/// auto-disposed so the selection persists as the user moves between the three
/// screens.
final oiChartsProvider = ChangeNotifierProvider((ref) => OiChartsProvider());

class OiChartsProvider extends DefaultChangeNotifier {
  final ChartsApi _api = locator<ChartsApi>();
  final OptionChainApi _ocApi = locator<OptionChainApi>();

  static const String _defaultUnderlying = 'NIFTY';
  static const List<String> intervals = ['1m', '5m', '15m', '30m', '60m'];

  String _underlying = _defaultUnderlying;
  DatesResponse _dates = DatesResponse.empty;
  String? _selectedDate;
  List<ExpiryOption> _expiries = const [];
  String? _selectedExpiry;
  String _interval = '5m';
  List<double>? _selectedStrikes;

  OiByStrike? _oiByStrike;
  PcrTimeline? _pcr;
  OiTimeline? _oiTimeline;

  bool _started = false;
  bool _loadingDates = false;
  bool _loadingExpiries = false;
  bool _loadingOiByStrike = false;
  bool _loadingPcr = false;
  bool _loadingOiTimeline = false;
  String? _oiByStrikeError;
  String? _pcrError;
  String? _oiTimelineError;

  bool _wantOiByStrike = false;
  bool _wantPcr = false;
  bool _wantOiTimeline = false;

  // ---- shared selection ----
  String get underlying => _underlying;
  DatesResponse get dates => _dates;
  String? get selectedDate => _selectedDate;
  List<ExpiryOption> get expiries => _expiries;
  String? get selectedExpiry => _selectedExpiry;
  String get interval => _interval;
  List<double>? get selectedStrikes => _selectedStrikes;
  bool get loadingExpiries => _loadingExpiries;

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

  String get tradeDate =>
      _oiByStrike?.tradeDate ??
      _pcr?.tradeDate ??
      _oiTimeline?.tradeDate ??
      _selectedDate ??
      '';

  // ---- data + status ----
  OiByStrike? get oiByStrike => _oiByStrike;
  bool get loadingOiByStrike => _loadingOiByStrike;
  String? get oiByStrikeError => _oiByStrikeError;
  bool get isOiByStrikeInitialLoading =>
      _oiByStrike == null &&
      (_loadingDates || _loadingExpiries || _loadingOiByStrike);
  bool get isOiByStrikeFatal => _oiByStrike == null && _oiByStrikeError != null;

  PcrTimeline? get pcrTimeline => _pcr;
  bool get loadingPcr => _loadingPcr;
  String? get pcrError => _pcrError;
  bool get isPcrInitialLoading =>
      _pcr == null && (_loadingDates || _loadingExpiries || _loadingPcr);
  bool get isPcrFatal => _pcr == null && _pcrError != null;

  OiTimeline? get oiTimeline => _oiTimeline;
  bool get loadingOiTimeline => _loadingOiTimeline;
  String? get oiTimelineError => _oiTimelineError;
  bool get isOiTimelineInitialLoading =>
      _oiTimeline == null &&
      (_loadingDates || _loadingExpiries || _loadingOiTimeline);
  bool get isOiTimelineFatal => _oiTimeline == null && _oiTimelineError != null;

  // ---- screen entry points (call from initState) ----
  Future<void> openOiByStrike() async {
    _wantOiByStrike = true;
    await _ensureStarted();
    await _loadOiByStrike();
  }

  Future<void> openPcr() async {
    _wantPcr = true;
    await _ensureStarted();
    await _loadPcr();
  }

  Future<void> openOiTimeline() async {
    _wantOiTimeline = true;
    await _ensureStarted();
    await _loadOiTimeline();
  }

  Future<void> _ensureStarted() async {
    if (_started) return;
    _started = true;
    await _loadDates();
    _selectedDate =
        _dates.latest ?? (_dates.dates.isNotEmpty ? _dates.dates.last : null);
    await _loadExpiries(resetExpiry: true);
  }

  // ---- selection mutations ----
  Future<void> selectUnderlying(String u) async {
    if (u == _underlying) return;
    _underlying = u;
    _selectedStrikes = null;
    _oiByStrike = null;
    _pcr = null;
    _oiTimeline = null;
    notifyListeners();
    await _loadExpiries(resetExpiry: true);
    await _refetchWanted();
  }

  Future<void> selectDate(String iso) async {
    if (iso == _selectedDate) return;
    _selectedDate = iso;
    notifyListeners();
    await _loadExpiries(resetExpiry: true);
    await _refetchWanted();
  }

  Future<void> selectExpiry(String expiry) async {
    if (expiry == _selectedExpiry) return;
    _selectedExpiry = expiry;
    notifyListeners();
    await _refetchWanted();
  }

  /// Interval only affects the two timeline endpoints.
  Future<void> setInterval(String interval) async {
    if (interval == _interval) return;
    _interval = interval;
    notifyListeners();
    if (_wantPcr) await _loadPcr();
    if (_wantOiTimeline) await _loadOiTimeline();
  }

  /// Strike selection only affects oi-timeline's `series`.
  Future<void> setStrikes(List<double>? strikes) async {
    _selectedStrikes = strikes;
    notifyListeners();
    if (_wantOiTimeline) await _loadOiTimeline();
  }

  Future<void> refresh() async => _refetchWanted();

  Future<void> _refetchWanted() async {
    if (_wantOiByStrike) await _loadOiByStrike();
    if (_wantPcr) await _loadPcr();
    if (_wantOiTimeline) await _loadOiTimeline();
  }

  // ---- loaders ----
  Future<void> _loadDates() async {
    _loadingDates = true;
    notifyListeners();
    try {
      _dates = await _ocApi.getDates();
    } catch (_) {
      // Non-fatal: charts still load the latest day; the calendar just can't
      // restrict selectable days until /dates succeeds.
    } finally {
      _loadingDates = false;
      notifyListeners();
    }
  }

  Future<void> _loadExpiries({required bool resetExpiry}) async {
    _loadingExpiries = true;
    notifyListeners();
    try {
      _expiries =
          await _ocApi.getExpiries(underlying: _underlying, date: _selectedDate);
      if (resetExpiry ||
          _selectedExpiry == null ||
          !_expiries.any((e) => e.expiry == _selectedExpiry)) {
        _selectedExpiry = _nearExpiry();
      }
    } catch (_) {
      _expiries = const [];
      if (resetExpiry) _selectedExpiry = null;
    } finally {
      _loadingExpiries = false;
      notifyListeners();
    }
  }

  String? _nearExpiry() {
    if (_expiries.isEmpty) return null;
    return _expiries
        .firstWhere((e) => e.isNear, orElse: () => _expiries.first)
        .expiry;
  }

  Future<void> _loadOiByStrike() async {
    _loadingOiByStrike = true;
    _oiByStrikeError = null;
    notifyListeners();
    try {
      _oiByStrike = await _api.getOiByStrike(
          underlying: _underlying, date: _selectedDate, expiry: _selectedExpiry);
      _syncFrom(_oiByStrike!.tradeDate, _oiByStrike!.expiry,
          _oiByStrike!.availableExpiries);
    } on DashboardApiException catch (e) {
      _oiByStrikeError = e.message;
    } catch (e) {
      _oiByStrikeError = e.toString();
    } finally {
      _loadingOiByStrike = false;
      notifyListeners();
    }
  }

  Future<void> _loadPcr() async {
    _loadingPcr = true;
    _pcrError = null;
    notifyListeners();
    try {
      _pcr = await _api.getPcrTimeline(
          underlying: _underlying,
          date: _selectedDate,
          expiry: _selectedExpiry,
          interval: _interval);
      _syncFrom(_pcr!.tradeDate, _pcr!.expiry, _pcr!.availableExpiries);
    } on DashboardApiException catch (e) {
      _pcrError = e.message;
    } catch (e) {
      _pcrError = e.toString();
    } finally {
      _loadingPcr = false;
      notifyListeners();
    }
  }

  Future<void> _loadOiTimeline() async {
    _loadingOiTimeline = true;
    _oiTimelineError = null;
    notifyListeners();
    try {
      _oiTimeline = await _api.getOiTimeline(
          underlying: _underlying,
          date: _selectedDate,
          expiry: _selectedExpiry,
          interval: _interval,
          strikes: _selectedStrikes);
      if (_oiTimeline!.selectedStrikes.isNotEmpty) {
        _selectedStrikes = _oiTimeline!.selectedStrikes;
      }
      _syncFrom(_oiTimeline!.tradeDate, _oiTimeline!.expiry,
          _oiTimeline!.availableExpiries);
    } on DashboardApiException catch (e) {
      _oiTimelineError = e.message;
    } catch (e) {
      _oiTimelineError = e.toString();
    } finally {
      _loadingOiTimeline = false;
      notifyListeners();
    }
  }

  void _syncFrom(
      String tradeDate, String? expiry, List<ExpiryOption> available) {
    if (tradeDate.isNotEmpty) _selectedDate = tradeDate;
    if (expiry != null) _selectedExpiry = expiry;
    if (available.isNotEmpty) _expiries = available;
  }
}
