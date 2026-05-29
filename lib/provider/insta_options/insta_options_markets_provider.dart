import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/insta_options_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/buildup_symbol.dart';
import 'package:mynt_plus/models/insta_options/market_snapshot.dart';
import 'package:mynt_plus/models/insta_options/spot_timeseries_point.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/insta_options/insta_market_hours.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';

final instaOptionsMarketsProvider =
    ChangeNotifierProvider.autoDispose((ref) => InstaOptionsMarketsProvider(ref));

/// Powers the Markets Dashboard (README §10.1).
///
/// Composes `/market/snapshot` (advances/declines + index ticker tiles) and
/// `/buildup/symbols` (2×2 quadrant grid). Sparklines load once per session
/// from `/spot/timeseries` for each tile index. Polling cadence follows
/// README §10.1 Refresh: 4 s during market hours, 30 s otherwise.
class InstaOptionsMarketsProvider extends DefaultChangeNotifier {
  /// Indices shown as ticker tiles in the top row (README §10.1).
  static const List<String> tileIndices = [
    'NIFTY',
    'BANKNIFTY',
    'FINNIFTY',
    'MIDCPNIFTY',
  ];

  final InstaOptionsApi _api = locator<InstaOptionsApi>();
  final Ref ref;

  MarketSnapshot _snapshot = MarketSnapshot.empty;
  BuildupSymbolsResponse _buildup = BuildupSymbolsResponse.empty;
  final Map<String, List<SpotTimeseriesPoint>> _sparklines = {};
  String? _error;
  DateTime? _lastUpdated;
  Timer? _timer;
  bool _active = false;
  String _lastExchange = '';

  InstaOptionsMarketsProvider(this.ref) {
    ref.listen<InstaOptionsSelectionProvider>(
      instaOptionsSelectionProvider,
      (_, next) {
        if (!_active) return;
        if (next.selection.exchange == _lastExchange) return;
        _fetch();
      },
    );
  }

  MarketSnapshot get snapshot => _snapshot;
  BuildupSymbolsResponse get buildup => _buildup;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;

  List<SpotTimeseriesPoint> sparklineFor(String index) =>
      _sparklines[index] ?? const <SpotTimeseriesPoint>[];

  IndexQuote? quoteFor(String index) {
    for (final q in _snapshot.indices) {
      if (q.name == index) return q;
    }
    return null;
  }

  void start() {
    if (_active) return;
    _active = true;
    _fetch();
    _loadSparklines();
    if (InstaMarketHours.isOpen()) {
      _timer = Timer.periodic(
        InstaMarketHours.tickIntervalInsideHours,
        (_) => _fetch(),
      );
    }
  }

  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    await _fetch(force: true);
    await _loadSparklines();
  }

  Future<void> _fetch({bool force = false}) async {
    final sel = ref.read(instaOptionsSelectionProvider).selection;
    if (loading && !force) return;
    loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getMarketSnapshot(),
        _api.getBuildupSymbols(exchange: sel.exchange),
      ]);
      _snapshot = results[0] as MarketSnapshot;
      _buildup = results[1] as BuildupSymbolsResponse;
      _lastExchange = sel.exchange;
      _lastUpdated = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSparklines() async {
    final sel = ref.read(instaOptionsSelectionProvider).selection;
    for (final index in tileIndices) {
      try {
        final bars = await _api.getSpotTimeseries(
          exchange: sel.exchange,
          symbol: index,
        );
        _sparklines[index] = bars;
        if (_active) notifyListeners();
      } catch (_) {
        // Sparkline failure is non-fatal — tile still renders LTP + change%.
        _sparklines[index] = const [];
      }
    }
  }

}
