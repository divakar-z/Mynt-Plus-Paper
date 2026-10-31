import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../api/core/api_export.dart';
import '../locator/constant.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../models/auth_model/totp_model.dart';
import '../models/profile_model/apikeymodel.dart';
import '../models/profile_model/generateapikey_model.dart';
import '../models/profile_model/generatenewapikey_model.dart';
import '../models/profile_model/oauth_app_model.dart';
import 'auth_provider.dart';
import 'core/default_change_notifier.dart';
import 'index_list_provider.dart';

final apikeyprovider =
    ChangeNotifierProvider((ref) => ApikeyProvider(ref));

class ApikeyProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();
  final Preferences pref = locator<Preferences>();
  final Ref ref;
  ApikeyProvider(this.ref);

  Apikeymodel? _apikeyres;
  Apikeymodel? get apikeyres => _apikeyres;

  GenerateApikeyModel? _generateApikey;
  GenerateApikeyModel? get generateApikey => _generateApikey;

  GenerateNewApiKeyModel? _generateApikeyNew;
  GenerateNewApiKeyModel? get generateApikeyNew => _generateApikeyNew;

  TotpKey? _totpKey;
  TotpKey? get totpkey => _totpKey;

  bool _hidePass = true;
  bool get hidePass => _hidePass;

  // Form Controllers
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _primaryIpController = TextEditingController();
  final TextEditingController _backupIpController = TextEditingController();
  final TextEditingController _dnameController = TextEditingController();

  TextEditingController get urlController => _urlController;
  TextEditingController get primaryIpController => _primaryIpController;
  TextEditingController get backupIpController => _backupIpController;
  TextEditingController get dnameController => _dnameController;

  // Form Variables
  bool _isHighFrequency = false;
  bool _hideSecret = true;
  String? _generatedSecretCode;

  bool get isHighFrequency => _isHighFrequency;
  bool get hideSecret => _hideSecret;
  String? get generatedSecretCode => _generatedSecretCode;

  hiddenPass() {
    _hidePass = !_hidePass;
    notifyListeners();
  }

  // Form Methods
  void toggleSecretVisibility() {
    _hideSecret = !_hideSecret;
    notifyListeners();
  }

  void setSecretHidden(bool value) {
    _hideSecret = value;
    notifyListeners();
  }

  void setHighFrequency(bool value) {
    _isHighFrequency = value;
    notifyListeners();
  }

  void populateFormFields() {
    if (_generateApikeyNew != null) {
      // If user has existing data (STAT = "Ok"), pre-fill the fields
      if (_generateApikeyNew!.stat == "Ok") {
        _urlController.text = _generateApikeyNew!.redirectUrl;
        if (_generateApikeyNew!.ipAddresses.isNotEmpty) {
          _primaryIpController.text = _generateApikeyNew!.ipAddresses.first.ipAddress;
        }
        if (_generateApikeyNew!.ipAddresses.length > 1) {
          _backupIpController.text = _generateApikeyNew!.ipAddresses[1].ipAddress;
        }
      } else {
        // If user has no data (STAT = "Not_Ok"), clear fields for new entry
        _urlController.clear();
        _primaryIpController.clear();
        _backupIpController.clear();
      }
    }
  }

  // Generate a random secret code that changes on each refresh
  String generateSecretCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(32, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  // Generate new secret code for existing API key (when user clicks regenerate)
  void generateNewSecretCode() {
    _generatedSecretCode = generateSecretCode();
    notifyListeners();
  }

  void clearFormFields() {
    _urlController.clear();
    _primaryIpController.clear();
    _backupIpController.clear();
    _isHighFrequency = false;
    _hideSecret = true;
    notifyListeners();
  }

  // Validation Methods

  @override
  void dispose() {
    _urlController.dispose();
    _primaryIpController.dispose();
    _backupIpController.dispose();
    _dnameController.dispose();
    super.dispose();
  }

// Fetching data from the api and stored in a variable

  Future fetchapikey(BuildContext context) async {
    try {
      _apikeyres = await api.getapikey();
      ConstantName.sessCheck = true;
      if (_apikeyres!.emsg == "Session Expired :  Invalid Session Key" &&
          _apikeyres!.stat == "Not_Ok") {
        ref.read(authProvider).ifSessionExpired(context);
      }
      notifyListeners();
      return _apikeyres;
    } catch (e) {
      ref.read(indexListProvider).logError.add({"type": "Fetch API", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

// Fetching data from the api and stored in a variable

Future fetchgenerateapikey(BuildContext context, String month, String apistatus) async {
    try {
      _generateApikey = await api.generateapikeynewuser(month, apistatus);
      ConstantName.sessCheck = true;
      if (_generateApikey!.emsg == "Session Expired :  Invalid Session Key" &&
          _generateApikey!.stat == "Not_Ok") {
        ref.read(authProvider).ifSessionExpired(context);
      }
      notifyListeners();
      return _generateApikey;
    } catch (e) {
      ref.read(indexListProvider)
          .logError
          .add({"type": "Regenerate API", "Error": "$e"});
      notifyListeners();
    } finally {
      //_
    }
  }


// neww

  Future fetchgenerateapikeynew(BuildContext context) async {
    try {
      _generateApikeyNew = await api.getapikeynew();
      
      // If no existing data (STAT = "Not_Ok"), generate a new secret code and create new model with client ID from prefs
      if (_generateApikeyNew != null && _generateApikeyNew!.stat != "Ok") {
        _generatedSecretCode = generateSecretCode();
        // Create new model instance with hardcoded client ID for now
        _generateApikeyNew = GenerateNewApiKeyModel(
          stat: _generateApikeyNew!.stat,
          appKey: "${pref.clientId ?? ""}_U", 
          displayName: "${pref.clientId ?? ""} API Key", // Default display name for new API key
          secretCode: _generateApikeyNew!.secretCode,
          redirectUrl: _generateApikeyNew!.redirectUrl,
          ipAddresses: _generateApikeyNew!.ipAddresses,
          exchangeAlgos: _generateApikeyNew!.exchangeAlgos,
          userIds: [UserIdEntry(userId: pref.clientId ?? "")], // Default user ID for new API key
        );
      } else {
        _generatedSecretCode = null; // Use existing secret code
      }
      
      populateFormFields(); // Populate form fields when data is loaded
      notifyListeners();
      return _generateApikeyNew;
    } catch (e) {
      ref.read(indexListProvider)
          .logError
          .add({"type": "Generate API", "Error": "$e"});
      notifyListeners();
    }
  }


  Future fetchregenerateapikey(BuildContext context, String month) async {
    try {
      _generateApikey = await api.regenerateapikey(month);
      ConstantName.sessCheck = true;
      if (_generateApikey!.emsg == "Session Expired :  Invalid Session Key" &&
          _generateApikey!.stat == "Not_Ok") {
        ref.read(authProvider).ifSessionExpired(context);
      }
      notifyListeners();
      return _generateApikey;
    } catch (e) {
      ref.read(indexListProvider)
          .logError
          .add({"type": "Regenerate API", "Error": "$e"});
      notifyListeners();
    } finally {
      //_
    }
  }

  bool _isFetchingTotp = false;
  bool get isFetchingTotp => _isFetchingTotp;

  /// Fetch existing TOTP key via GetSecretKey.
  /// Leaves `_totpKey.pwd` empty when the user has not generated one yet —
  /// the UI uses that to show the "Generate Key" button.
  Future<void> fetchTotp() async {
    _isFetchingTotp = true;
    notifyListeners();
    try {
      _totpKey = await api.getTotp(false);
    } finally {
      _isFetchingTotp = false;
      notifyListeners();
    }
  }

  /// Generate a new TOTP secret via GenSecretKey. Called only when the user
  /// explicitly taps the "Generate" button — never as a fallback from fetch.
  Future<void> generateTotp() async {
    _isFetchingTotp = true;
    notifyListeners();
    try {
      _totpKey = await api.getTotp(true);
    } finally {
      _isFetchingTotp = false;
      notifyListeners();
    }
  }

  /// Reset all per-user state. Called from the logout flow so the next
  /// logged-in user does not see the previous user's TOTP / API keys.
  void clearOnLogout() {
    _apikeyres = null;
    _generateApikey = null;
    _generateApikeyNew = null;
    _totpKey = null;
    _generatedSecretCode = null;
    _hidePass = true;
    _hideSecret = true;
    _isHighFrequency = false;
    _isFetchingTotp = false;
    _oauthApps = [];
    _remaining = 0;
    _selectedIdx = 0;
    _oauthLoaded = false;
    _createdKey = null;
    _dnameController.clear();
    _urlController.clear();
    _primaryIpController.clear();
    _backupIpController.clear();
    notifyListeners();
  }

  // ---- Global-Login OAuth apps (multi-app) ----
  List<OAuthApp> _oauthApps = [];
  int _maxApps = 6;
  int _remaining = 0;
  int _selectedIdx = 0;
  bool _oauthLoading = false;
  bool _oauthLoaded = false;

  List<OAuthApp> get oauthApps => _oauthApps;
  int get maxApps => _maxApps;
  int get remaining => _remaining;
  int get selectedIdx => _selectedIdx;
  bool get oauthLoading => _oauthLoading;
  bool get oauthLoaded => _oauthLoaded;
  OAuthApp? get selectedApp =>
      _selectedIdx < _oauthApps.length ? _oauthApps[_selectedIdx] : null;

  // Key of an app just created, to show the "is ready" banner.
  String? _createdKey;
  String? get createdKey => _createdKey;

  void dismissCreatedBanner() {
    _createdKey = null;
    notifyListeners();
  }

  /// Key the next create will get: first free letter in U..Z, A..T order.
  String get nextOauthKey {
    const order = 'UVWXYZABCDEFGHIJKLMNOPQRST';
    final used = _oauthApps.map((a) => a.appKey.substring(a.appKey.length - 1));
    final free = order.split('').firstWhere((c) => !used.contains(c), orElse: () => '');
    return '${pref.clientId ?? ''}_$free';
  }

  void startOauthCreate() {
    _createdKey = null;
    _dnameController.clear();
    _urlController.clear();
    _primaryIpController.clear();
    _backupIpController.clear();
    notifyListeners();
  }

  void _fillFormFromSelected() {
    final app = selectedApp;
    _dnameController.text = app?.displayName ?? '';
    _urlController.text = app?.redirectUrl ?? '';
    _primaryIpController.text = app?.primaryIp ?? '';
    _backupIpController.text = app?.backupIp ?? '';
  }

  /// Returns null on success, otherwise the message to show the user.
  String? _oauthFailure(BuildContext context, Map<String, dynamic> json) {
    final emsg = json['emsg'] as String? ?? 'Something went wrong';
    if (emsg == 'Invalid session') {
      ref.read(authProvider).ifSessionExpired(context);
    }
    return emsg;
  }

  Future<String?> fetchOauthApps(BuildContext context,
      {String? selectKey}) async {
    _oauthLoading = true;
    notifyListeners();
    try {
      final json = await api.oauthAppsCall('list', {});
      if (json['stat'] != 'Ok') return _oauthFailure(context, json);
      _oauthApps = (json['apps'] as List<dynamic>? ?? [])
          .map((e) => OAuthApp.fromJson(e as Map<String, dynamic>))
          .toList();
      _maxApps = json['max_apps'] as int? ?? 6;
      _remaining = json['remaining'] as int? ?? 0;
      final idx = selectKey == null
          ? _selectedIdx
          : _oauthApps.indexWhere((a) => a.appKey == selectKey);
      _selectedIdx = (idx < 0 || idx >= _oauthApps.length) ? 0 : idx;
      _oauthLoaded = true;
      _fillFormFromSelected();
      return null;
    } catch (e) {
      ref.read(indexListProvider).logError.add({"type": "OAuth Apps", "Error": "$e"});
      return 'Unable to reach server, please try again';
    } finally {
      _oauthLoading = false;
      notifyListeners();
    }
  }

  void selectOauthApp(int index) {
    _selectedIdx = index;
    _createdKey = null;
    _hideSecret = true;
    _fillFormFromSelected();
    notifyListeners();
  }

  Future<String?> createOauthApp(BuildContext context) async {
    try {
      final json = await api.oauthAppsCall('create', {
        'red_url': _urlController.text.trim(),
        'primary_ip': _primaryIpController.text.trim(),
        'backup_ip': _backupIpController.text.trim(),
        if (_dnameController.text.trim().isNotEmpty)
          'dname': _dnameController.text.trim(),
      });
      if (json['stat'] != 'Ok') return _oauthFailure(context, json);
      final key = json['app_key'] as String?;
      final err = await fetchOauthApps(context, selectKey: key);
      if (err == null) {
        _createdKey = key;
        _hideSecret = false;
        notifyListeners();
      }
      return err;
    } catch (e) {
      ref.read(indexListProvider).logError.add({"type": "OAuth Apps", "Error": "$e"});
      return 'Unable to reach server, please try again';
    }
  }

  /// Update the form fields, or only regenerate the secret when [regenerate].
  /// Both IP fields are always sent: the backend replaces them together.
  Future<String?> updateOauthApp(BuildContext context,
      {bool regenerate = false}) async {
    final app = selectedApp;
    if (app == null) return 'No app selected';
    try {
      final json = await api.oauthAppsCall('update', {
        'app_key': app.appKey,
        if (regenerate)
          'regenerate': true
        else ...{
          'red_url': _urlController.text.trim(),
          'primary_ip': _primaryIpController.text.trim(),
          'backup_ip': _backupIpController.text.trim(),
          if (_dnameController.text.trim().isNotEmpty)
            'dname': _dnameController.text.trim(),
        },
      });
      if (json['stat'] != 'Ok') return _oauthFailure(context, json);
      _oauthApps[_selectedIdx] = OAuthApp.fromJson(json);
      notifyListeners();
      return null;
    } catch (e) {
      ref.read(indexListProvider).logError.add({"type": "OAuth Apps", "Error": "$e"});
      return 'Unable to reach server, please try again';
    }
  }

  Future<String?> deleteOauthApp(BuildContext context) async {
    final app = selectedApp;
    if (app == null) return 'No app selected';
    try {
      final json = await api.oauthAppsCall('delete', {'app_key': app.appKey});
      if (json['stat'] != 'Ok') return _oauthFailure(context, json);
      _selectedIdx = 0;
      return fetchOauthApps(context);
    } catch (e) {
      ref.read(indexListProvider).logError.add({"type": "OAuth Apps", "Error": "$e"});
      return 'Unable to reach server, please try again';
    }
  }

  Future<GenerateNewApiKeyModel?> submitApiKeyNew({
    required String appKey,
    required String secretCode,
    required String redirectUrl,
    required String displayName,
    required List<String> ipAddresses,
    required List<String> userIds,
  }) async {
    try {
      final res = await api.submitApiKeyNew(
        appKey: appKey,
        secretCode: secretCode,
        redirectUrl: redirectUrl,
        displayName: displayName,
        ipAddresses: ipAddresses,
        userIds: userIds,
      );

      // Only overwrite existing data if the update succeeded.
      // If it failed (stat != 'Ok'), keep existing fields (secretCode, etc.) intact.
      if (res.stat == "Ok") {
        _generateApikeyNew = res;
        notifyListeners();
      }

      return res;
    } catch (e) {
      rethrow;
    }
  }
}
