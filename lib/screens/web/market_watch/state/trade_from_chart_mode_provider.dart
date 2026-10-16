import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';

// Old global toggle (one value per browser, default TradingView) — replaced by
// the per-client chart preference below.
//
// /// Persistent global toggle: when ON, the symbol details screen swaps its
// /// chart area from the existing TradingView portal to the in-house chart
// /// engine (`ChartEngineShellScreen`) embedded inline. Sticky across page
// /// refreshes via SharedPreferences; defaults to OFF for new users so the
// /// existing TradingView behaviour is unchanged until explicitly opted in.
// ///
// /// The depth panel's visibility is intentionally NOT touched by this
// /// toggle — the user controls that via the sidebar icon. Toggling
// /// Trade-from-Chart on while the depth panel is open just means the
// /// embedded chart renders in the narrower content area; toggling off
// /// brings back TradingView in the same area.
// class TradeFromChartModeNotifier extends Notifier<bool> {
//   static const _key = 'tradeFromChartMode';
//
//   @override
//   bool build() {
//     final raw = locator<Preferences>().sharedPreferences?.getString(_key);
//     return raw == '1';
//   }
//
//   void toggle() => set(!state);
//
//   void set(bool value) {
//     if (value == state) return;
//     state = value;
//     // Best-effort persist; never block the toggle on prefs IO.
//     // ignore: discarded_futures
//     locator<Preferences>().setString(_key, value ? '1' : '0');
//   }
// }
//
// final tradeFromChartModeProvider =
//     NotifierProvider<TradeFromChartModeNotifier, bool>(
//         TradeFromChartModeNotifier.new);

/// The client's preferred chart in symbol details: Trade from Chart (the
/// in-house chart engine) or TradingView. Set from Profile > Settings > Chart
/// and from the "Trade from Chart" pill in symbol details — both write the
/// same preference.
///
/// Stored per client id and read live (no cached copy), so logging in as
/// another client on the same browser never carries the previous client's
/// choice over. Defaults to Trade from Chart until the client switches.
class TradeFromChartMode extends DefaultChangeNotifier {
  final _pref = locator<Preferences>();

  String get _userId => _pref.clientId ?? '';

  /// true = Trade from Chart, false = TradingView.
  bool get isOn => _pref.getChartPreference(_userId) == 'tfc';

  void toggle() => set(!isOn);

  void set(bool value) {
    if (value == isOn) return;
    // Best-effort persist; never block the switch on prefs IO.
    // ignore: discarded_futures
    _pref.setChartPreference(_userId, value ? 'tfc' : 'tv');
    notifyListeners();
  }
}

final tradeFromChartModeProvider =
    ChangeNotifierProvider((ref) => TradeFromChartMode());
