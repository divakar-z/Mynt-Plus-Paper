import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/insta_options_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/chain_row.dart';
import 'package:mynt_plus/models/insta_options/oi_aggregate.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/insta_options/insta_market_hours.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';

final instaOptionsAggregateProvider =
    ChangeNotifierProvider.autoDispose((ref) => InstaOptionsAggregateProvider(ref));

/// Powers the OI Statistics screen (README §10.4).
///
/// Owns `/oi/aggregate` (cumulative panel + KPIs) and `/analytics/chain` +
/// `/spot` (per-strike bars + ATM marker). REST-only; ticks at
/// [InstaMarketHours.tickIntervalInsideHours] during the IST session, and
/// makes a single mount fetch (no timer) outside market hours.
class InstaOptionsAggregateProvider extends DefaultChangeNotifier {
  final InstaOptionsApi _api = locator<InstaOptionsApi>();
  final Ref ref;

  OiAggregate? _aggregate;
  List<ChainRow> _chain = const [];
  double _spot = 0;
  String? _error;
  Timer? _timer;
  bool _active = false;

  InstaOptionsAggregateProvider(this.ref) {
    ref.listen<InstaOptionsSelectionProvider>(
      instaOptionsSelectionProvider,
      (_, __) {
        if (_active) _fetch();
      },
    );
  }

  OiAggregate? get aggregate => _aggregate;
  List<ChainRow> get chain => _chain;
  double get spot => _spot;
  String? get error => _error;

  /// Per-strike CE/PE OI pairs, sorted by strike.
  List<({double strike, int ceOi, int peOi})> get perStrike {
    final byStrike = <double, ({int ce, int pe})>{};
    for (final r in _chain) {
      if (r.isFut) continue;
      final cur = byStrike[r.strike] ?? (ce: 0, pe: 0);
      byStrike[r.strike] = (
        ce: r.isCe ? r.oi : cur.ce,
        pe: r.isPe ? r.oi : cur.pe,
      );
    }
    final out = byStrike.entries
        .map((e) => (strike: e.key, ceOi: e.value.ce, peOi: e.value.pe))
        .toList()
      ..sort((a, b) => a.strike.compareTo(b.strike));
    return out;
  }

  void start() {
    if (_active) return;
    _active = true;
    _fetch();
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

  Future<void> refresh() => _fetch(force: true);

  Future<void> _fetch({bool force = false}) async {
    final sel = ref.read(instaOptionsSelectionProvider).selection;
    if (sel.expiry.isEmpty) return;
    if (loading && !force) return;
    loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getOiAggregate(
          exchange: sel.exchange,
          symbol: sel.symbol,
          expiry: sel.expiry,
        ),
        _api.getAnalyticsChain(
          exchange: sel.exchange,
          symbol: sel.symbol,
          expiry: sel.expiry,
        ),
        _api.getSpot(
          exchange: sel.exchange,
          symbol: sel.symbol,
        ),
      ]);
      _aggregate = results[0] as OiAggregate;
      _chain = results[1] as List<ChainRow>;
      _spot = results[2] as double;
    } catch (e) {
      _error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
