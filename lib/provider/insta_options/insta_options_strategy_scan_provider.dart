import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/insta_options_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/strategy_scan_result.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';

final instaOptionsStrategyScanProvider =
    ChangeNotifierProvider((ref) => InstaOptionsStrategyScanProvider(ref));

/// Powers the Find Strategy screen (README §10.9).
///
/// On-demand only — no periodic polling. The user chooses direction +
/// min reward + reward type, taps "Run scan", we POST `/strategy/scan`
/// and surface the top results.
class InstaOptionsStrategyScanProvider extends DefaultChangeNotifier {
  final InstaOptionsApi _api = locator<InstaOptionsApi>();
  final Ref ref;

  StrategyDirection _direction = StrategyDirection.positive;
  StrategyMinRewardType _minRewardType = StrategyMinRewardType.inr;
  double _minReward = 100;

  List<StrategyScanResult> _results = const [];
  String? _error;
  bool _hasRun = false;

  InstaOptionsStrategyScanProvider(this.ref);

  StrategyDirection get direction => _direction;
  StrategyMinRewardType get minRewardType => _minRewardType;
  double get minReward => _minReward;
  List<StrategyScanResult> get results => _results;
  String? get error => _error;
  bool get hasRun => _hasRun;

  void setDirection(StrategyDirection v) {
    if (_direction == v) return;
    _direction = v;
    notifyListeners();
  }

  void setMinRewardType(StrategyMinRewardType v) {
    if (_minRewardType == v) return;
    _minRewardType = v;
    notifyListeners();
  }

  void setMinReward(double v) {
    if (_minReward == v) return;
    _minReward = v;
    notifyListeners();
  }

  void clear() {
    _results = const [];
    _error = null;
    _hasRun = false;
    notifyListeners();
  }

  Future<void> runScan() async {
    final sel = ref.read(instaOptionsSelectionProvider).selection;
    if (sel.expiry.isEmpty) {
      _error = 'Pick an expiry from the bar above first.';
      _hasRun = true;
      notifyListeners();
      return;
    }
    if (loading) return;
    loading = true;
    _error = null;
    _hasRun = true;
    notifyListeners();
    try {
      _results = await _api.scanStrategies(
        exchange: sel.exchange,
        symbol: sel.symbol,
        expiry: sel.expiry,
        direction: _direction,
        minReward: _minReward,
        minRewardType: _minRewardType,
      );
    } catch (e) {
      _error = e.toString();
      _results = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
