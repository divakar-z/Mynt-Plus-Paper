import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/insta_options_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/chain_row.dart';
import 'package:mynt_plus/models/insta_options/selection.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';

final instaOptionsChainProvider =
    ChangeNotifierProvider((ref) => InstaOptionsChainProvider(ref));

/// Fetches `/analytics/chain` + `/spot` whenever the active selection changes.
///
/// Phase 2 ships REST-only. Live WS deltas (`chain_delta` / `iv_update`) and
/// the Change-ref dropdown (`/oi/change`) arrive in a later sprint.
class InstaOptionsChainProvider extends DefaultChangeNotifier {
  final InstaOptionsApi _api = locator<InstaOptionsApi>();
  final Ref ref;

  List<ChainRow> _rows = const [];
  double _spot = 0;
  String? _error;
  InstaOptionsSelection? _lastLoaded;

  InstaOptionsChainProvider(this.ref) {
    ref.listen<InstaOptionsSelectionProvider>(
      instaOptionsSelectionProvider,
      (_, next) => _maybeFetch(next.selection),
      fireImmediately: true,
    );
  }

  List<ChainRow> get rows => _rows;
  double get spot => _spot;
  // `loading` is inherited from DefaultChangeNotifier.
  String? get error => _error;

  /// Strikes with CE/PE pair (FUT excluded), sorted ascending.
  List<double> get strikes {
    final set = <double>{};
    for (final r in _rows) {
      if (r.isFut) continue;
      set.add(r.strike);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Closest strike to spot. `null` when no CE/PE rows are loaded.
  double? get atmStrike {
    if (_spot <= 0) return null;
    final list = strikes;
    if (list.isEmpty) return null;
    double best = list.first;
    double bestDelta = (best - _spot).abs();
    for (final s in list) {
      final d = (s - _spot).abs();
      if (d < bestDelta) {
        best = s;
        bestDelta = d;
      }
    }
    return best;
  }

  /// FUT row if present (first row of `/analytics/chain` by spec).
  ChainRow? get futRow {
    for (final r in _rows) {
      if (r.isFut) return r;
    }
    return null;
  }

  /// CE+PE rows for a given strike. Tuple-shape via record.
  ({ChainRow? ce, ChainRow? pe}) atStrike(double strike) {
    ChainRow? ce;
    ChainRow? pe;
    for (final r in _rows) {
      if (r.strike != strike) continue;
      if (r.isCe) ce = r;
      if (r.isPe) pe = r;
    }
    return (ce: ce, pe: pe);
  }

  /// Max OI across visible CE/PE rows — used by OIBarCell to scale widths.
  int get maxOi {
    int max = 0;
    for (final r in _rows) {
      if (r.isFut) continue;
      if (r.oi > max) max = r.oi;
    }
    return max;
  }

  Future<void> refresh() async {
    final sel = ref.read(instaOptionsSelectionProvider).selection;
    await _fetch(sel, force: true);
  }

  Future<void> _maybeFetch(InstaOptionsSelection selection) async {
    if (selection.expiry.isEmpty) return;
    final same = _lastLoaded != null &&
        _lastLoaded!.exchange == selection.exchange &&
        _lastLoaded!.symbol == selection.symbol &&
        _lastLoaded!.expiry == selection.expiry;
    if (same) return;
    await _fetch(selection);
  }

  Future<void> _fetch(InstaOptionsSelection selection, {bool force = false}) async {
    if (loading) return;
    if (selection.expiry.isEmpty) return;
    loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getAnalyticsChain(
          exchange: selection.exchange,
          symbol: selection.symbol,
          expiry: selection.expiry,
        ),
        _api.getSpot(
          exchange: selection.exchange,
          symbol: selection.symbol,
        ),
      ]);
      _rows = results[0] as List<ChainRow>;
      _spot = results[1] as double;
      _lastLoaded = selection;
    } catch (e) {
      _error = e.toString();
      if (force) _rows = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
