import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/symbols_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/instrument_symbol.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';

/// Caches the global F&O symbol universe (`GET /api/v1/symbols`) — indices +
/// stocks usable as option-chain underlyings. Loaded once and reusable by any
/// screen (the Option Chain underlying picker today; more later).
final symbolsProvider = ChangeNotifierProvider(
  (ref) => SymbolsProvider()..ensureLoaded(),
);

class SymbolsProvider extends DefaultChangeNotifier {
  final SymbolsApi _api = locator<SymbolsApi>();

  List<InstrumentSymbol> _all = const [];
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  List<InstrumentSymbol> get all => _all;
  bool get isLoading => _loading;
  bool get isReady => _loaded;
  String? get error => _error;

  /// Indices only (already pinned first in [_all]).
  List<InstrumentSymbol> get indices =>
      _all.where((s) => s.isIndex).toList(growable: false);

  /// F&O stocks only.
  List<InstrumentSymbol> get stocks =>
      _all.where((s) => !s.isIndex).toList(growable: false);

  /// Indices (pinned) then stocks, filtered by [query] over id / name.
  List<InstrumentSymbol> search(String query) {
    final q = query.trim().toLowerCase();
    bool match(InstrumentSymbol s) =>
        q.isEmpty ||
        s.underlyingId.toLowerCase().contains(q) ||
        s.name.toLowerCase().contains(q);
    return [
      ...indices.where(match),
      ...stocks.where(match),
    ];
  }

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    await reload();
  }

  Future<void> reload() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await _api.getSymbols();
      // Indices pinned on top, then alphabetical by name within each group.
      list.sort((a, b) {
        if (a.isIndex != b.isIndex) return a.isIndex ? -1 : 1;
        return a.name.compareTo(b.name);
      });
      _all = list;
      _loaded = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
