import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for the InstaOptions Analytics backend (OI Data API).
///
/// This is a **separate** service from the Mynt Noren/`go.mynt.in` APIs.
/// Base URLs are read from / written to `SharedPreferences` under the keys
/// below, with the documented defaults applied when unset.
class InstaOptionsConfig {
  static const String _httpKey = 'instaoptions:baseUrl';
  static const String _wsKey = 'instaoptions:wsBaseUrl';

  static const String defaultHttpBaseUrl = 'http://192.168.5.61:8000';
  static const String defaultWsBaseUrl = 'ws://192.168.5.61:8000';

  SharedPreferences? _prefs;

  Future<void> _ensureLoaded() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String> httpBaseUrl() async {
    await _ensureLoaded();
    final raw = _prefs?.getString(_httpKey);
    if (raw == null || raw.isEmpty) return defaultHttpBaseUrl;
    return raw;
  }

  Future<String> wsBaseUrl() async {
    await _ensureLoaded();
    final raw = _prefs?.getString(_wsKey);
    if (raw == null || raw.isEmpty) return defaultWsBaseUrl;
    return raw;
  }

  Future<void> setHttpBaseUrl(String value) async {
    await _ensureLoaded();
    await _prefs?.setString(_httpKey, value);
  }

  Future<void> setWsBaseUrl(String value) async {
    await _ensureLoaded();
    await _prefs?.setString(_wsKey, value);
  }
}
