import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/insta_options_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/trending_bucket.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/insta_options/insta_market_hours.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';

final instaOptionsTrendingProvider =
    ChangeNotifierProvider.autoDispose((ref) => InstaOptionsTrendingProvider(ref));

/// Powers the Trending OI screen (README §10.5).
///
/// Owns the user's selected strikes + bucket-minutes choice and pulls
/// `GET /oi/trending` (Ticket 3) for the matching window. Inside market
/// hours we tick at [InstaMarketHours.tickIntervalInsideHours]; outside,
/// one mount fetch + the user's Refresh button.
class InstaOptionsTrendingProvider extends DefaultChangeNotifier {
  static const List<int> bucketMinutesOptions = [3, 5, 15];
  static const List<String> optionTypes = ['CE', 'PE'];

  final InstaOptionsApi _api = locator<InstaOptionsApi>();
  final Ref ref;

  List<double> _strikes = const [];
  int _bucketMinutes = 3;
  List<TrendingBucket> _buckets = const [];
  String? _error;
  Timer? _timer;
  bool _active = false;

  InstaOptionsTrendingProvider(this.ref) {
    ref.listen<InstaOptionsSelectionProvider>(
      instaOptionsSelectionProvider,
      (_, __) {
        if (_active && _strikes.isNotEmpty) _fetch(force: true);
      },
    );
  }

  List<double> get strikes => _strikes;
  int get bucketMinutes => _bucketMinutes;
  List<TrendingBucket> get buckets => _buckets;
  String? get error => _error;

  void setStrikes(List<double> picked) {
    final dedup = {...picked}.toList()..sort();
    if (_listEquals(dedup, _strikes)) return;
    _strikes = dedup;
    _buckets = const [];
    notifyListeners();
    if (_active) _fetch(force: true);
  }

  void setBucketMinutes(int v) {
    if (_bucketMinutes == v) return;
    if (!bucketMinutesOptions.contains(v)) return;
    _bucketMinutes = v;
    _buckets = const [];
    notifyListeners();
    if (_active) _fetch(force: true);
  }

  void start() {
    if (_active) return;
    _active = true;
    if (_strikes.isNotEmpty) _fetch();
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
    if (sel.expiry.isEmpty || _strikes.isEmpty) return;
    if (loading && !force) return;
    loading = true;
    _error = null;
    notifyListeners();
    try {
      _buckets = await _api.getTrending(
        exchange: sel.exchange,
        symbol: sel.symbol,
        expiry: sel.expiry,
        strikes: _strikes,
        types: optionTypes,
        bucketMinutes: _bucketMinutes,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
