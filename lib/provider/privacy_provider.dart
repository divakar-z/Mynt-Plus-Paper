import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../locator/locator.dart';
import '../locator/preference.dart';
import '../res/mynt_web_color_styles.dart';
import 'core/default_change_notifier.dart';

/// Global provider for Privacy Mode.
///
/// When enabled, sensitive monetary values across the app (P&L, holdings
/// value, invested value, fund balances, day change, etc.) are masked so
/// they are not visible over-the-shoulder. The choice is persisted in
/// [Preferences] so it survives app restarts.
///
/// Any widget that renders a sensitive value should `ref.watch(privacyProvider)`
/// and pass the raw value through [PrivacyProvider.mask] (or use the
/// [privacyMask] helper) so it rebuilds when the toggle changes.
final privacyProvider = ChangeNotifierProvider((ref) => PrivacyProvider());

/// Mask string used in place of a hidden monetary value.
const String kPrivacyMask = "...";

class PrivacyProvider extends DefaultChangeNotifier {
  final _pref = locator<Preferences>();

  String get _userId => _pref.clientId ?? '';

  /// Always resolved through the CURRENT client id (no cached copy), so an
  /// account switch can never carry the previous account's choice over —
  /// every rebuild after login reads the new account's own setting.
  bool get isPrivate => _pref.getPrivacyMode(_userId);

  /// Re-announces the state so subscribed widgets re-read it (available for
  /// login / account-switch flows; reads are already live via [isPrivate]).
  void refresh() => notifyListeners();

  Future<void> setPrivacy(bool enabled) async {
    if (isPrivate == enabled) return;
    await _pref.setPrivacyMode(_userId, enabled);
    notifyListeners();
  }

  Future<void> toggle() => setPrivacy(!isPrivate);

  /// Returns [value] when privacy is off, otherwise a masked placeholder.
  ///
  /// [prefix]/[suffix] (e.g. a `₹ ` prefix or ` %` suffix) are preserved so
  /// the layout stays stable while the number itself is hidden.
  String mask(String value,
      {String prefix = '', String suffix = '', String mask = kPrivacyMask}) {
    if (!isPrivate) return '$prefix$value$suffix';
    return '$prefix$mask$suffix';
  }

  /// Colour for a (possibly masked) value.
  ///
  /// When privacy is OFF, returns [visible] (e.g. the profit/loss green/red).
  /// When privacy is ON, returns a neutral grey so the mask doesn't leak
  /// profit/loss through colour. Pass [primary] `true` for prominent values
  /// (headers) to use the high-contrast primary grey; the default is the
  /// softer secondary grey. Grey shade follows [isDark].
  Color maskColor(Color visible, {required bool isDark, bool primary = false}) {
    if (!isPrivate) return visible;
    if (primary) {
      return isDark ? MyntColors.textPrimaryDark : MyntColors.textPrimary;
    }
    return isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary;
  }
}

/// Convenience: mask [value] based on the given privacy state.
String privacyMask(bool isPrivate, String value,
    {String prefix = '', String suffix = '', String mask = kPrivacyMask}) {
  if (!isPrivate) return '$prefix$value$suffix';
  return '$prefix$mask$suffix';
}
