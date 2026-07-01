import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api.dart'
    show DashboardApiException;
import 'package:mynt_plus/api/insta_options/option_chain/option_chain_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dates_response.dart';
import 'package:mynt_plus/models/insta_options/freshness.dart';
import 'package:mynt_plus/models/insta_options/option_chain/expiry_option.dart';
import 'package:mynt_plus/models/insta_options/option_chain/option_chain_data.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/insta_options/live_polling.dart';

final optionChainProvider = ChangeNotifierProvider.autoDispose(
  (ref) => OptionChainProvider(),
);

/// Powers the date-based **Option Chain** (Screen 2).
///
/// On mount: `/dates` → if today's live snapshot is held, default to **Live /
/// Today** (polled); else the latest finalized day. `/expiries` (pick near) →
/// `/option-chain`. Changing **underlying** or **date** refetches expiries then
/// the chain; changing **expiry** refetches only the chain — all in the current
/// mode. A cold live symbol/expiry's first load may take ~1–4s (server warm-up)
/// — that surfaces as the normal loading state, not an error.
class OptionChainProvider extends DefaultChangeNotifier with LivePolling {
  final OptionChainApi _api = locator<OptionChainApi>();

  static const String _defaultUnderlying = 'NIFTY';

  String _underlying = _defaultUnderlying;
  DatesResponse _dates = DatesResponse.empty;
  String? _selectedDate;
  bool _liveMode = false;
  List<ExpiryOption> _expiries = const [];
  String? _selectedExpiry;
  OptionChainData? _data;

  bool _started = false;
  bool _loadingDates = false;
  bool _loadingExpiries = false;
  bool _loadingChain = false;
  String? _error;

  // ---- selectors / mode ----
  String get underlying => _underlying;
  DatesResponse get dates => _dates;
  LiveChannel? get liveChannel => _dates.live;
  bool get liveMode => _liveMode;
  String? get selectedDate => _selectedDate;
  List<ExpiryOption> get expiries => _expiries;
  String? get selectedExpiry => _selectedExpiry;

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
  OptionChainData? get data => _data;
  String get tradeDate => _data?.tradeDate ?? _selectedDate ?? '';

  // ---- status ----
  bool get loadingChain => _loadingChain;
  bool get loadingExpiries => _loadingExpiries;
  String? get error => _error;
  bool get isInitialLoading =>
      _data == null && (_loadingDates || _loadingExpiries || _loadingChain);
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
    await _loadExpiries(resetExpiry: true);
    await _loadChain();
    _syncPolling();
  }

  Future<void> selectLive() async {
    if (_liveMode) return;
    _liveMode = true;
    _selectedDate = null;
    _data = null;
    notifyListeners();
    await _loadExpiries(resetExpiry: true);
    await _loadChain();
    _syncPolling();
  }

  /// Underlying change → reload expiries + chain (different strike universe),
  /// keeping the current mode.
  Future<void> selectUnderlying(String underlying) async {
    if (underlying == _underlying) return;
    _underlying = underlying;
    _data = null; // clear stale chain while the new one loads (cold = slow)
    notifyListeners();
    await _loadExpiries(resetExpiry: true);
    await _loadChain();
    _syncPolling();
  }

  /// Pick a finalized day → immutable, polling stops.
  Future<void> selectDate(String isoDate) async {
    if (!_liveMode && isoDate == _selectedDate) return;
    _liveMode = false;
    _selectedDate = isoDate;
    notifyListeners();
    stopPolling();
    await _loadExpiries(resetExpiry: true);
    await _loadChain();
  }

  /// Expiry change → only the chain refetches.
  Future<void> selectExpiry(String expiry) async {
    if (expiry == _selectedExpiry) return;
    _selectedExpiry = expiry;
    notifyListeners();
    await _loadChain();
  }

  Future<void> refresh() async {
    await _loadDates();
    await _loadExpiries(resetExpiry: false);
    await _loadChain();
    _syncPolling();
  }

  void _syncPolling() {
    if (_liveMode) {
      startPolling(() => _loadChain(silent: true));
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
      // Non-fatal: the chain still loads; the calendar/live option just can't
      // populate until /dates succeeds.
    } finally {
      _loadingDates = false;
      notifyListeners();
    }
  }

  Future<void> _loadExpiries({required bool resetExpiry}) async {
    _loadingExpiries = true;
    notifyListeners();
    try {
      _expiries = await _api.getExpiries(
          underlying: _underlying,
          date: _liveMode ? null : _selectedDate,
          live: _liveMode);
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
    final near =
        _expiries.firstWhere((e) => e.isNear, orElse: () => _expiries.first);
    return near.expiry;
  }

  /// [silent] = a background poll: keep the last good chain on a transient
  /// failure, no loader flash.
  Future<void> _loadChain({bool silent = false}) async {
    if (!silent) {
      _loadingChain = true;
      _error = null;
      notifyListeners();
    }
    try {
      final data = await _api.getChain(
        underlying: _underlying,
        date: _liveMode ? null : _selectedDate,
        expiry: _selectedExpiry,
        live: _liveMode,
      );
      _data = data;
      // Asked live but the server fell back to a finalized day → historical.
      if (_liveMode && !data.freshness.isLive) {
        _liveMode = false;
        stopPolling();
      }
      // Sync selections from the authoritative response.
      if (!_liveMode && data.tradeDate.isNotEmpty) _selectedDate = data.tradeDate;
      if (data.expiry != null) _selectedExpiry = data.expiry;
      if (data.availableExpiries.isNotEmpty) _expiries = data.availableExpiries;
    } on DashboardApiException catch (e) {
      if (!silent) _error = e.message;
    } catch (e) {
      if (!silent) _error = e.toString();
    } finally {
      if (!silent) _loadingChain = false;
      notifyListeners();
    }
  }
}
