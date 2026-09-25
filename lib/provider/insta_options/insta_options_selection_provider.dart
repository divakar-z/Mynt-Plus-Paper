import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/models/insta_options/selection.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

final instaOptionsSelectionProvider =
    ChangeNotifierProvider((ref) => InstaOptionsSelectionProvider(ref));

class InstaOptionsSelectionProvider extends DefaultChangeNotifier {
  static const String _prefKey = 'instaoptions:selection';

  final Ref ref;

  InstaOptionsSelection _selection = InstaOptionsSelection.defaultSelection;
  bool _hydrated = false;

  InstaOptionsSelection get selection => _selection;
  bool get hydrated => _hydrated;

  InstaOptionsSelectionProvider(this.ref) {
    _hydrate();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _selection = InstaOptionsSelection.fromJson(json);
      } catch (_) {
        _selection = InstaOptionsSelection.defaultSelection;
      }
    }
    _hydrated = true;
    notifyListeners();
  }

  Future<void> update({
    String? exchange,
    String? symbol,
    String? expiry,
  }) async {
    _selection = _selection.copyWith(
      exchange: exchange,
      symbol: symbol,
      expiry: expiry,
    );
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(_selection.toJson()));
  }
}
