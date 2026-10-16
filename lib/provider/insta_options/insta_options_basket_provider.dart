import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/models/insta_options/basket_leg.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';

final instaOptionsBasketProvider =
    ChangeNotifierProvider((ref) => InstaOptionsBasketProvider(ref));

/// In-memory basket for InstaOptions Analytics.
///
/// Order placement / hand-off to `/strategy-builder` is intentionally deferred
/// (see INSTAOPTIONS_FEATURE_README.md §3). Tap handlers add legs here for
/// visual feedback only; the UI never navigates and never calls a broker.
class InstaOptionsBasketProvider extends DefaultChangeNotifier {
  final Ref ref;
  final List<BasketLeg> _legs = [];

  InstaOptionsBasketProvider(this.ref);

  List<BasketLeg> get queuedLegs => List.unmodifiable(_legs);
  int get count => _legs.length;
  bool get isEmpty => _legs.isEmpty;
  bool get isNotEmpty => _legs.isNotEmpty;

  void add(BasketLeg leg) {
    _legs.add(leg);
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _legs.length) return;
    _legs.removeAt(index);
    notifyListeners();
  }

  void replaceAll(List<BasketLeg> legs) {
    _legs
      ..clear()
      ..addAll(legs);
    notifyListeners();
  }

  void clear() {
    if (_legs.isEmpty) return;
    _legs.clear();
    notifyListeners();
  }
}
