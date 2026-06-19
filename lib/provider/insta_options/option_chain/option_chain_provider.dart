import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api.dart'
    show DashboardApiException;
import 'package:mynt_plus/api/insta_options/option_chain/option_chain_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dates_response.dart';
import 'package:mynt_plus/models/insta_options/option_chain/expiry_option.dart';
import 'package:mynt_plus/models/insta_options/option_chain/option_chain_data.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';

final optionChainProvider = ChangeNotifierProvider.autoDispose(
  (ref) => OptionChainProvider(),
);

/// Powers the date-based **Option Chain** (Screen 2).
///
/// On mount: `/dates` → latest → `/expiries` (pick near) → `/option-chain`.
/// Changing **underlying** or **date** refetches expiries then the chain;
/// changing **expiry** refetches only the chain. Data is historical (immutable
/// per day), so there is no polling.
class OptionChainProvider extends DefaultChangeNotifier {
  final OptionChainApi _api = locator<OptionChainApi>();

  static const String _defaultUnderlying = 'NIFTY';

  String _underlying = _defaultUnderlying;
  DatesResponse _dates = DatesResponse.empty;
  String? _selectedDate;
  List<ExpiryOption> _expiries = const [];
  String? _selectedExpiry;
  OptionChainData? _data;

  bool _started = false;
  bool _loadingDates = false;
  bool _loadingExpiries = false;
  bool _loadingChain = false;
  String? _error;

  // ---- selectors ----
  String get underlying => _underlying;
  DatesResponse get dates => _dates;
  String? get selectedDate => _selectedDate;
  List<ExpiryOption> get expiries => _expiries;
  String? get selectedExpiry => _selectedExpiry;

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

  void stop() => _started = false;

  Future<void> _init() async {
    await _loadDates();
    _selectedDate = _dates.latest ??
        (_dates.dates.isNotEmpty ? _dates.dates.last : null);
    await _loadExpiries(resetExpiry: true);
    await _loadChain();
  }

  /// Underlying change → reload expiries + chain (different strike universe).
  Future<void> selectUnderlying(String underlying) async {
    if (underlying == _underlying) return;
    _underlying = underlying;
    _data = null; // clear stale chain while the new one loads
    notifyListeners();
    await _loadExpiries(resetExpiry: true);
    await _loadChain();
  }

  /// Date change → expiries differ per day, so refetch both.
  Future<void> selectDate(String isoDate) async {
    if (isoDate == _selectedDate) return;
    _selectedDate = isoDate;
    notifyListeners();
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
  }

  // ---- loaders ----
  Future<void> _loadDates() async {
    _loadingDates = true;
    notifyListeners();
    try {
      _dates = await _api.getDates();
    } catch (_) {
      // Non-fatal: the chain still loads the latest day; the calendar just
      // can't restrict selectable days until /dates succeeds.
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
          await _api.getExpiries(underlying: _underlying, date: _selectedDate);
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

  Future<void> _loadChain() async {
    _loadingChain = true;
    _error = null;
    notifyListeners();
    try {
      _data = await _api.getChain(
        underlying: _underlying,
        date: _selectedDate,
        expiry: _selectedExpiry,
      );
      // Sync selections from the authoritative response.
      if (_data!.tradeDate.isNotEmpty) _selectedDate = _data!.tradeDate;
      if (_data!.expiry != null) _selectedExpiry = _data!.expiry;
      if (_data!.availableExpiries.isNotEmpty) {
        _expiries = _data!.availableExpiries;
      }
    } on DashboardApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingChain = false;
      notifyListeners();
    }
  }
}
