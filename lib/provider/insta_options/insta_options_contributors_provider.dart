import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/insta_options_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/contributor_row.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/insta_options/insta_market_hours.dart';

final instaOptionsContributorsProvider =
    ChangeNotifierProvider.autoDispose((ref) => InstaOptionsContributorsProvider());

/// Powers the Index Contributors screen (README §10.2).
///
/// REST-only `/contributors/{index}`; refreshes every 4 s during IST market
/// hours, 30 s otherwise. Active index changes are immediate — cached rows
/// are cleared and the new fetch fires before the next tick.
class InstaOptionsContributorsProvider extends DefaultChangeNotifier {
  static const List<String> supportedIndices = [
    'NIFTY',
    'BANKNIFTY',
    'FINNIFTY',
    'MIDCPNIFTY',
    'SENSEX',
    'BANKEX',
  ];

  final InstaOptionsApi _api = locator<InstaOptionsApi>();

  String _activeIndex = 'NIFTY';
  List<ContributorRow> _rows = const [];
  String? _error;
  DateTime? _lastUpdated;
  Timer? _timer;
  bool _active = false;

  String get activeIndex => _activeIndex;
  List<ContributorRow> get rows => _rows;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;

  void setActiveIndex(String index) {
    if (_activeIndex == index) return;
    if (!supportedIndices.contains(index)) return;
    _activeIndex = index;
    _rows = const [];
    _error = null;
    notifyListeners();
    if (_active) _fetch();
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
    if (loading && !force) return;
    loading = true;
    _error = null;
    notifyListeners();
    try {
      _rows = await _api.getContributors(index: _activeIndex);
      _lastUpdated = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

}
