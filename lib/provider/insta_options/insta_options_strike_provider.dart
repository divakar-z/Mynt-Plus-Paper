import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/insta_options_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/oi_timeseries_point.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';

final instaOptionsStrikeProvider =
    ChangeNotifierProvider((ref) => InstaOptionsStrikeProvider(ref));

/// Powers the Per-Strike Options Chart screen (README §10.7).
///
/// Holds CE + PE 1-min timeseries for a single strike. Polls every 60s while
/// the screen is mounted via [start] / [stop]; strike selection is owned by
/// the screen itself (mount-time default = ATM) and pushed in via [setStrike].
class InstaOptionsStrikeProvider extends DefaultChangeNotifier {
  static const Duration _interval = Duration(seconds: 60);

  final InstaOptionsApi _api = locator<InstaOptionsApi>();
  final Ref ref;

  double? _strike;
  List<OiTimeseriesPoint> _ce = const [];
  List<OiTimeseriesPoint> _pe = const [];
  String? _error;
  Timer? _timer;
  bool _active = false;

  InstaOptionsStrikeProvider(this.ref) {
    ref.listen<InstaOptionsSelectionProvider>(
      instaOptionsSelectionProvider,
      (_, __) {
        if (_active) _fetch();
      },
    );
  }

  double? get strike => _strike;
  List<OiTimeseriesPoint> get cePoints => _ce;
  List<OiTimeseriesPoint> get pePoints => _pe;
  String? get error => _error;

  void start() {
    if (_active) return;
    _active = true;
    if (_strike != null) _fetch();
    _timer = Timer.periodic(_interval, (_) => _fetch());
  }

  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> setStrike(double strike) async {
    if (_strike == strike) return;
    _strike = strike;
    _ce = const [];
    _pe = const [];
    notifyListeners();
    if (_active) await _fetch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() => _fetch(force: true);

  Future<void> _fetch({bool force = false}) async {
    final sel = ref.read(instaOptionsSelectionProvider).selection;
    final k = _strike;
    if (sel.expiry.isEmpty || k == null) return;
    if (loading && !force) return;
    loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getOiTimeseries(
          exchange: sel.exchange,
          symbol: sel.symbol,
          expiry: sel.expiry,
          optionType: 'CE',
          strike: k,
        ),
        _api.getOiTimeseries(
          exchange: sel.exchange,
          symbol: sel.symbol,
          expiry: sel.expiry,
          optionType: 'PE',
          strike: k,
        ),
      ]);
      _ce = results[0];
      _pe = results[1];
    } catch (e) {
      _error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
