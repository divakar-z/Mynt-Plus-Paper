import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/insta_options_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/pcr_point.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/insta_options/insta_market_hours.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';

final instaOptionsPcrProvider =
    ChangeNotifierProvider.autoDispose((ref) => InstaOptionsPcrProvider(ref));

/// Powers the PCR Ratio screen (README §10.6).
///
/// REST-only `/oi/pcr/timeseries`; ticks at
/// [InstaMarketHours.tickIntervalInsideHours] during the IST session, makes
/// a single mount fetch (no timer) outside market hours.
class InstaOptionsPcrProvider extends DefaultChangeNotifier {
  final InstaOptionsApi _api = locator<InstaOptionsApi>();
  final Ref ref;

  static const List<int> bucketMinutesOptions = [1, 3, 5, 15];

  List<PcrPoint> _points = const [];
  String? _error;
  Timer? _timer;
  bool _active = false;
  int _bucketMinutes = 1;

  int get bucketMinutes => _bucketMinutes;

  void setBucketMinutes(int v) {
    if (_bucketMinutes == v) return;
    if (!bucketMinutesOptions.contains(v)) return;
    _bucketMinutes = v;
    _points = const [];
    notifyListeners();
    if (_active) _fetch(force: true);
  }

  InstaOptionsPcrProvider(this.ref) {
    ref.listen<InstaOptionsSelectionProvider>(
      instaOptionsSelectionProvider,
      (_, __) {
        if (_active) _fetch();
      },
    );
  }

  List<PcrPoint> get points => _points;
  String? get error => _error;

  double? get currentPcr => _points.isEmpty ? null : _points.last.pcr;

  double? get dayHigh {
    if (_points.isEmpty) return null;
    var m = _points.first.pcr;
    for (final p in _points) {
      if (p.pcr > m) m = p.pcr;
    }
    return m;
  }

  double? get dayLow {
    if (_points.isEmpty) return null;
    var m = _points.first.pcr;
    for (final p in _points) {
      if (p.pcr < m) m = p.pcr;
    }
    return m;
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
      _points = await _api.getPcrTimeseries(
        exchange: sel.exchange,
        symbol: sel.symbol,
        expiry: sel.expiry,
        bucketMinutes: _bucketMinutes,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
