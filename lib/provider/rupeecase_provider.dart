import 'package:flutter_riverpod/legacy.dart';

import '../api/core/api_export.dart';
import '../locator/locator.dart';
import '../models/rupeecase_model/algo_strategy_model.dart';
import '../models/rupeecase_model/rupeecase_strategy_model.dart';
import 'core/default_change_notifier.dart';

final rupeeCaseProvider =
    ChangeNotifierProvider<RupeeCaseProvider>((ref) => RupeeCaseProvider());

/// Holds the RupeeCase curated strategies shown above the Portfolio section on
/// the web dashboard. Fetches once per session unless [fetchStrategies] is
/// called with `force: true`.
class RupeeCaseProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();

  List<RupeeCaseStrategy> _strategies = [];
  List<RupeeCaseStrategy> get strategies => _strategies;

  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  // --- Algo strategies (second tab of the dashboard Strategies section) -------
  // Kept in a separate loading flag from [loading] so the two tabs load and
  // render their skeletons independently.
  List<AlgoStrategy> _algoStrategies = [];
  List<AlgoStrategy> get algoStrategies => _algoStrategies;

  bool _algoLoading = false;
  bool get algoLoading => _algoLoading;

  bool _algoLoaded = false;
  bool get algoLoaded => _algoLoaded;

  Future<void> fetchStrategies({bool force = false}) async {
    // Guard against duplicate/concurrent loads (the dashboard fires this on
    // every mount).
    if (loading) return;
    if (_hasLoaded && !force) return;

    loading = true;
    errorMessage = null;
    _safeNotify();

    try {
      final res = await api.fetchRupeeCaseStrategies();
      if (res != null) {
        _strategies = res.strategies;
        _hasLoaded = true;
      } else {
        errorMessage = 'Unable to load strategies';
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      loading = false;
      _safeNotify();
    }
  }

  /// Loads the algo strategy baskets. Same fetch-once-per-session semantics as
  /// [fetchStrategies], guarded by its own [_algoLoading] / [_algoLoaded] flags.
  Future<void> fetchAlgoStrategies({bool force = false}) async {
    if (_algoLoading) return;
    if (_algoLoaded && !force) return;

    _algoLoading = true;
    _safeNotify();

    try {
      final res = await api.fetchAlgoStrategies();
      if (res != null) {
        _algoStrategies = res.strategies;
        _algoLoaded = true;
      }
    } catch (_) {
      // Fail soft — the Algo tab simply shows its empty state.
    } finally {
      _algoLoading = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!disposed) notifyListeners();
  }
}
