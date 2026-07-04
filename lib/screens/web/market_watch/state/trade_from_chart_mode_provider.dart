import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';

/// Persistent global toggle: when ON, the symbol details screen swaps its
/// chart area from the existing TradingView portal to the in-house chart
/// engine (`ChartEngineShellScreen`) embedded inline. Sticky across page
/// refreshes via SharedPreferences; defaults to OFF for new users so the
/// existing TradingView behaviour is unchanged until explicitly opted in.
///
/// The depth panel's visibility is intentionally NOT touched by this
/// toggle — the user controls that via the sidebar icon. Toggling
/// Trade-from-Chart on while the depth panel is open just means the
/// embedded chart renders in the narrower content area; toggling off
/// brings back TradingView in the same area.
class TradeFromChartModeNotifier extends Notifier<bool> {
  static const _key = 'tradeFromChartMode';

  @override
  bool build() {
    final raw = locator<Preferences>().sharedPreferences?.getString(_key);
    return raw == '1';
  }

  void toggle() => set(!state);

  void set(bool value) {
    if (value == state) return;
    state = value;
    // Best-effort persist; never block the toggle on prefs IO.
    // ignore: discarded_futures
    locator<Preferences>().setString(_key, value ? '1' : '0');
  }
}

final tradeFromChartModeProvider =
    NotifierProvider<TradeFromChartModeNotifier, bool>(
        TradeFromChartModeNotifier.new);
