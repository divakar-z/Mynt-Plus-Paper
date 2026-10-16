import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/insta_options_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';

final instaOptionsReferenceProvider =
    ChangeNotifierProvider((ref) => InstaOptionsReferenceProvider(ref));

/// Caches `/symbols` and `/expiries` responses per (exchange, symbol).
///
/// Hits the network at most once per (exchange, symbol) per app session.
/// In-memory only — Phase 1's plumbing skipped persistent caching to
/// `Preferences`; if reload thrash becomes a problem in Phase 2+, persist on
/// success and hydrate on construct.
class InstaOptionsReferenceProvider extends DefaultChangeNotifier {
  final InstaOptionsApi _api = locator<InstaOptionsApi>();
  final Ref ref;

  // exchange -> symbol list
  final Map<String, List<String>> _symbolsByExchange = {};
  final Set<String> _symbolsLoading = {};
  final Map<String, String> _symbolsError = {};

  // "$exchange:$symbol" -> expiry list
  final Map<String, List<String>> _expiriesByKey = {};
  final Set<String> _expiriesLoading = {};
  final Map<String, String> _expiriesError = {};

  InstaOptionsReferenceProvider(this.ref);

  List<String>? symbolsFor(String exchange) => _symbolsByExchange[exchange];
  bool isSymbolsLoading(String exchange) => _symbolsLoading.contains(exchange);
  String? symbolsError(String exchange) => _symbolsError[exchange];

  List<String>? expiriesFor(String exchange, String symbol) =>
      _expiriesByKey['$exchange:$symbol'];
  bool isExpiriesLoading(String exchange, String symbol) =>
      _expiriesLoading.contains('$exchange:$symbol');
  String? expiriesError(String exchange, String symbol) =>
      _expiriesError['$exchange:$symbol'];

  Future<void> ensureSymbols(String exchange) async {
    if (_symbolsByExchange.containsKey(exchange) ||
        _symbolsLoading.contains(exchange)) {
      return;
    }
    _symbolsLoading.add(exchange);
    _symbolsError.remove(exchange);
    notifyListeners();
    try {
      final res = await _api.getSymbols(exchange: exchange);
      _symbolsByExchange[exchange] = res.symbols;
    } catch (e) {
      _symbolsError[exchange] = e.toString();
    } finally {
      _symbolsLoading.remove(exchange);
      notifyListeners();
    }
  }

  Future<void> ensureExpiries(String exchange, String symbol) async {
    final key = '$exchange:$symbol';
    if (_expiriesByKey.containsKey(key) || _expiriesLoading.contains(key)) {
      return;
    }
    _expiriesLoading.add(key);
    _expiriesError.remove(key);
    notifyListeners();
    try {
      final res = await _api.getExpiries(exchange: exchange, symbol: symbol);
      _expiriesByKey[key] = res.expiries;
    } catch (e) {
      _expiriesError[key] = e.toString();
    } finally {
      _expiriesLoading.remove(key);
      notifyListeners();
    }
  }

  /// First expiry in the list — the "nearest" expiry, per README §8.2 (sorted asc).
  String? nearestExpiry(String exchange, String symbol) {
    final list = expiriesFor(exchange, symbol);
    if (list == null || list.isEmpty) return null;
    return list.first;
  }
}
