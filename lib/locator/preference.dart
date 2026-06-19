import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static SharedPreferences? _prefInstance;

  Future<void> init() async {
    _prefInstance = await SharedPreferences.getInstance();
  }

  Future clearLocalPref() async {
    await _prefInstance?.clear();
  }

  Future clearClientSession() async {
    await _prefInstance?.remove(_clientSession);
  }

  /// Clears the logged-in user's identity + session keys (the "Client Details"
  /// group) while leaving device, theme, and filter prefs intact. Used by the
  /// URL token-based auto-login so a new user can never inherit the previous
  /// user's session, profile token, or mobile number.
  Future clearUserSession() async {
    await _prefInstance?.remove(_clientId);
    await _prefInstance?.remove(_clientSession);
    await _prefInstance?.remove(_apiToken);
    await _prefInstance?.remove(_clientMob);
    await _prefInstance?.remove(_clientName);
    await _prefInstance?.remove(_clientList);
  }

  // QR session invalidation — stores the device UUID of the currently active
  // QR login session so we can tell the backend to invalidate it when the
  // user refreshes the browser, closes the tab, or re-enters the QR screen
  // (which generates a new UUID). Prevents the race where mobile confirms
  // an orphaned QR session.
  Future setPendingQrUuid(String uuid) async =>
      await _prefInstance?.setString(_pendingQrUuid, uuid);

  String? get pendingQrUuid => _prefInstance?.getString(_pendingQrUuid);

  Future clearPendingQrUuid() async =>
      await _prefInstance?.remove(_pendingQrUuid);

  // setters

  Future setTheme(bool theme) async {
    await _prefInstance!.setBool(_userTheme, theme);
  }

  Future setMobileLogin(bool isMobile) async =>
      await _prefInstance!.setBool(_ismobileLogin, isMobile);

  Future setLogout(bool isLogout) async =>
      await _prefInstance!.setBool(_isLogout, isLogout);

  Future setHideLoginOptBtn(bool isHide) async =>
      await _prefInstance!.setBool(_hideLoginOptBtn, isHide);

  Future setAppTheme(String theme) async {
    await _prefInstance!.setString(_userAppTheme, theme);
  }

  Future setChartEngineSession(String json) async {
    await _prefInstance!.setString(_chartEngineSession, json);
  }

  String? getChartEngineSession() =>
      _prefInstance?.getString(_chartEngineSession);

  // Generic accessors used by chart-engine modules that own their own keys
  // (e.g. chartEngineOrderDefaultsV1). Avoid adding bespoke wrappers per key
  // when the data shape is opaque JSON owned by the calling notifier.
  SharedPreferences? get sharedPreferences => _prefInstance;

  Future<void> setString(String key, String value) async {
    await _prefInstance!.setString(key, value);
  }

  Future setDeviceName(String deviceName) async {
    await _prefInstance!.setString(_deviceName, deviceName);
  }

// SET Cleint Details

  Future setClientId(String id) async =>
      await _prefInstance!.setString(_clientId, id);
  Future setClientSession(String session) async =>
      await _prefInstance!.setString(_clientSession, session);
  Future setApiToken(String session) async =>
      await _prefInstance!.setString(_apiToken, session);
  Future setClientName(String name) async =>
      await _prefInstance!.setString(_clientName, name);
  Future setImei(String val) async =>
      await _prefInstance!.setString(_imei, val);
  Future setClientMob(String mob) async =>
      await _prefInstance!.setString(_clientMob, mob);
  // Future setLogoutClient(String logout) async =>
  //     await _prefInstance!.setString(_logOutClient, logout);
  Future setLoggedClientList(List<String> clients) async =>
      await _prefInstance!.setStringList(_clientList, clients);

  //// ORDER BOOK FILTER
  Future setOBScrip(bool isselect) async =>
      await _prefInstance!.setBool(_isObScripName, isselect);

  Future setOBPrice(bool isselect) async =>
      await _prefInstance!.setBool(_isObPrice, isselect);

  Future setOBtime(bool isselect) async =>
      await _prefInstance!.setBool(_isTime, isselect);

  Future setOBqty(bool isselect) async =>
      await _prefInstance!.setBool(_isObQuantity, isselect);

  Future setOBproduct(bool isselect) async =>
      await _prefInstance!.setBool(_isProduct, isselect);

  //// ORDER BOOK GTT FILTER
  Future setGTTScrip(bool isselect) async =>
      await _prefInstance!.setBool(_isGttScripName, isselect);

  Future setGTTPrice(bool isselect) async =>
      await _prefInstance!.setBool(_isGttPrice, isselect);

  Future setGTTtime(bool isselect) async =>
      await _prefInstance!.setBool(_isGttTime, isselect);

  Future setGTTqty(bool isselect) async =>
      await _prefInstance!.setBool(_isGttQuantity, isselect);

  Future setGTTproduct(bool isselect) async =>
      await _prefInstance!.setBool(_isGttProduct, isselect);

//// MARKET WATCH FILTER
  Future setMWScrip(bool isselect) async =>
      await _prefInstance!.setBool(_isMWScripName, isselect);

  Future setMWPrice(bool isselect) async =>
      await _prefInstance!.setBool(_isMWPrice, isselect);

  Future setMWPerchnage(bool isselect) async =>
      await _prefInstance!.setBool(_isMWPrechange, isselect);

//// Holding Filter
  Future setScrip(bool isselect) async =>
      await _prefInstance!.setBool(_isScripName, isselect);

  Future setPrice(bool isselect) async =>
      await _prefInstance!.setBool(_isPrice, isselect);

  Future setqty(bool isselect) async =>
      await _prefInstance!.setBool(_isQuantity, isselect);

  Future setPerchnage(bool isselect) async =>
      await _prefInstance!.setBool(_isPrechange, isselect);

  Future setLtppc(bool isselect) async =>
      await _prefInstance!.setBool(_isLtppc, isselect);

  Future setInvestby(bool isselect) async =>
      await _prefInstance!.setBool(_isInvest, isselect);
//// Mf Filter
  Future setMfScrip(bool isselect) async =>
      await _prefInstance!.setBool(_isMfScripName, isselect);

  Future setMfPrice(bool isselect) async =>
      await _prefInstance!.setBool(_isMfPrice, isselect);

  Future setMfqty(bool isselect) async =>
      await _prefInstance!.setBool(_isMfQuantity, isselect);

  Future setMfPerchnage(bool isselect) async =>
      await _prefInstance!.setBool(_isMfPrechange, isselect);

  Future setMfInvestby(bool isselect) async =>
      await _prefInstance!.setBool(_isMfInvest, isselect);

  // New MF Filter Methods for Holdings
  Future setMFName(bool isselect) async =>
      await _prefInstance!.setBool(_isMFName, isselect);

  Future setMFNav(bool isselect) async =>
      await _prefInstance!.setBool(_isMFNav, isselect);

  Future setMFUnit(bool isselect) async =>
      await _prefInstance!.setBool(_isMFUnit, isselect);

  Future setMFReturnPercChange(bool isselect) async =>
      await _prefInstance!.setBool(_isMFReturnPercChange, isselect);

  Future setMFInvestedPrice(bool isselect) async =>
      await _prefInstance!.setBool(_isMFInvestedPrice, isselect);

//// POSTION Filter
  Future setPosScrip(bool isselect) async =>
      await _prefInstance!.setBool(_isPosScripName, isselect);

  Future setPosPrice(bool isselect) async =>
      await _prefInstance!.setBool(_isPosPrice, isselect);

  Future setPosqty(bool isselect) async =>
      await _prefInstance!.setBool(_isPosQuantity, isselect);

  Future setPosPerchnage(bool isselect) async =>
      await _prefInstance!.setBool(_isPosPrechange, isselect);

  Future setPostion(bool isselect) async =>
      await _prefInstance!.setBool(_isPostion, isselect);

  //// PENDING ALERT FILTER
  Future setPAScrip(bool isselect) async =>
      await _prefInstance!.setBool(_isPAScripName, isselect);

  Future setPAPrice(bool isselect) async =>
      await _prefInstance!.setBool(_isPAPrice, isselect);

  Future setPAPriceAlert(bool isselect) async =>
      await _prefInstance!.setBool(_isPApricealert, isselect);

   Future setPAChange(bool isselect) async =>
      await _prefInstance!.setBool(_isPAChange, isselect);

  //// TRADE BOOK FILTER
  Future setTbScrip(bool isselect) async =>
      await _prefInstance!.setBool(_isTbScripName, isselect);

  Future setTbPrice(bool isselect) async =>
      await _prefInstance!.setBool(_isTbPrice, isselect);

  Future setTbBuyOrSell(bool isselect) async =>
      await _prefInstance!.setBool(_isTbBuyorSell, isselect);

  Future setTbTime(bool isselect) async =>
      await _prefInstance!.setBool(_isTbTime, isselect);

  //// SIP  FILTER
  Future setSipScrip(bool isselect) async =>
      await _prefInstance!.setBool(_isSipScripName, isselect);

  Future setSipPrice(bool isselect) async =>
      await _prefInstance!.setBool(_isSipPrice, isselect);

  Future setSipChange(bool isselect) async =>
      await _prefInstance!.setBool(_isSipPerchange, isselect);

  Future setSipDate(bool isselect) async =>
      await _prefInstance!.setBool(_isSipDate, isselect);

  Future setOrderprefer(String keys, String value) async =>
      await _prefInstance!.setString(keys, value);

  String? get showOrderpref => _prefInstance?.getString("ord_prf_$clientId");

  Future setRiskDiscloser(bool statis) async =>
      await _prefInstance!.setString('rist_dis', statis ? 'true' : '');

  String? get showRiskDis => _prefInstance?.getString("rist_dis");

  /// ORDER BOOK Filter
  bool? get isObScripname => _prefInstance?.getBool(_isObScripName) ?? true;
  bool? get isObPrice => _prefInstance?.getBool(_isObPrice) ?? true;
  bool? get isObqty => _prefInstance?.getBool(_isObQuantity) ?? true;
  bool? get isObtime => _prefInstance?.getBool(_isTime) ?? true;
  bool? get isObProduct => _prefInstance?.getBool(_isProduct) ?? true;

  /// ORDER BOOK GTT Filter
  bool? get isGttScripname => _prefInstance?.getBool(_isGttScripName) ?? true;
  bool? get isGttPrice => _prefInstance?.getBool(_isGttPrice) ?? true;
  bool? get isGttqty => _prefInstance?.getBool(_isGttQuantity) ?? true;
  bool? get isGtttime => _prefInstance?.getBool(_isGttTime) ?? true;
  bool? get isGttProduct => _prefInstance?.getBool(_isGttProduct) ?? true;

  /// MARKET WATCH Filter
  bool? get isMWScripname => _prefInstance?.getBool(_isMWScripName) ?? true;
  bool? get isMWPrice => _prefInstance?.getBool(_isMWPrice) ?? true;
  bool? get isMWPerchang => _prefInstance?.getBool(_isMWPrechange) ?? true;

  /// Holdings Filter
  bool? get isScripname => _prefInstance?.getBool(_isScripName) ?? true;
  bool? get isPrice => _prefInstance?.getBool(_isPrice) ?? true;
  bool? get isQuantity => _prefInstance?.getBool(_isQuantity) ?? true;
  bool? get isPerchang => _prefInstance?.getBool(_isPrechange) ?? true;
  bool? get isLtppc => _prefInstance?.getBool(_isLtppc) ?? true;
  bool? get isInvestby => _prefInstance?.getBool(_isInvest) ?? true;

  ////// MF Filter
  bool? get isMfScripname => _prefInstance?.getBool(_isMfScripName) ?? true;
  bool? get isMfQuantity => _prefInstance?.getBool(_isMfQuantity) ?? true;
  bool? get isMfPrice => _prefInstance?.getBool(_isMfPrice) ?? true;
  bool? get isMfPerchang => _prefInstance?.getBool(_isMfPrechange) ?? true;
  bool? get isMfInvestby => _prefInstance?.getBool(_isMfInvest) ?? true;

  ////// MF Holdings Filter (New)
  bool? get isMFName => _prefInstance?.getBool(_isMFName) ?? true;
  bool? get isMFNav => _prefInstance?.getBool(_isMFNav) ?? true;
  bool? get isMFUnit => _prefInstance?.getBool(_isMFUnit) ?? true;
  bool? get isMFReturnPercChange => _prefInstance?.getBool(_isMFReturnPercChange) ?? true;
  bool? get isMFInvestedPrice => _prefInstance?.getBool(_isMFInvestedPrice) ?? true;

  ////// Postion Filter
  bool? get isPosScripname => _prefInstance?.getBool(_isPosScripName) ?? true;
  bool? get isPosQuantity => _prefInstance?.getBool(_isPosQuantity) ?? true;
  bool? get isPosPrice => _prefInstance?.getBool(_isPosPrice) ?? true;
  bool? get isPosPerchang => _prefInstance?.getBool(_isPosPrechange) ?? true;
  bool? get isPostion => _prefInstance?.getBool(_isPostion) ?? true;

  /// PENDING ALERT FILTER
  bool? get isPAScripname => _prefInstance?.getBool(_isPAScripName) ?? true;
  bool? get isPAPrice => _prefInstance?.getBool(_isPAPrice) ?? true;
  bool? get isPAPricealert => _prefInstance?.getBool(_isPApricealert) ?? true;
  bool? get isPAChange => _prefInstance?.getBool(_isPAChange) ?? true;

  /// TRADE BOOK FILTER
  bool? get isTBScripname => _prefInstance?.getBool(_isTbScripName) ?? true;
  bool? get isTBPrice => _prefInstance?.getBool(_isTbPrice) ?? true;
  bool? get isTBBuyorSell => _prefInstance?.getBool(_isTbBuyorSell) ?? true;
  bool? get isTBTime => _prefInstance?.getBool(_isTbTime) ?? true;

  /// SIP FILTER
  bool? get isSipScripname => _prefInstance?.getBool(_isSipScripName) ?? true;
  bool? get isSipPrice => _prefInstance?.getBool(_isSipPrice) ?? true;
  bool? get isSipChange => _prefInstance?.getBool(_isSipPerchange) ?? true;
  bool? get isSipDate => _prefInstance?.getBool(_isSipDate) ?? true;

  // getters

  bool? get userTheme => _prefInstance?.getBool(_userTheme);
  bool? get isMobileLogin => _prefInstance?.getBool(_ismobileLogin) ?? true;
  bool? get islogOut => _prefInstance?.getBool(_isLogout) ?? false;
  bool? get hideLoginOptBtn =>
      _prefInstance?.getBool(_hideLoginOptBtn) ?? false;

  String? get userAppTheme =>
      _prefInstance?.getString(_userAppTheme) ?? "System Default";

  // String? get logoutClient => _prefInstance?.getString(_logOutClient) ?? "";
  String? get deviceName => _prefInstance?.getString(_deviceName) ?? "";
  String? get imei => _prefInstance?.getString(_imei) ?? "";

// GET Cleint Details
  String? get clientId => _prefInstance?.getString(_clientId) ?? "";
  String? get clientSession => _prefInstance?.getString(_clientSession) ?? "";
  String? get token => _prefInstance?.getString(_apiToken) ?? "";
  String? get clientMob => _prefInstance?.getString(_clientMob) ?? "";
  String? get clientName => _prefInstance?.getString(_clientName) ?? "";

  List<String>? get loggedClient =>
      _prefInstance?.getStringList(_clientList) ?? [];

  // Orders

  // Per-user basket storage
  Future setBasketScripForUser(String userId, String scrips) async =>
      await _prefInstance!.setString('basketScrips_$userId', scrips);
  Future setBasketListForUser(String userId, String scrips) async =>
      await _prefInstance!.setString('basketList_$userId', scrips);

  String? getBasketScripsForUser(String userId) =>
      _prefInstance?.getString('basketScrips_$userId') ?? "";
  String? getBasketListForUser(String userId) =>
      _prefInstance?.getString('basketList_$userId') ?? "";

  // Legacy (global, not per-user)
  Future setBasketScrip(String scrips) async =>
      await _prefInstance!.setString(_basketScrips, scrips);
  Future setBasketList(String scrips) async =>
      await _prefInstance!.setString(_basketList, scrips);

  String? get bsktScrips => _prefInstance?.getString(_basketScrips) ?? "";

  String? get bsktList => _prefInstance?.getString(_basketList) ?? "";
  
  // Order Tracking methods
  Future setOrderTrackingForUser(String userId, String data) async =>
      await _prefInstance!.setString('${_orderTracking}_$userId', data);
  
  String? getOrderTrackingForUser(String userId) =>
      _prefInstance?.getString('${_orderTracking}_$userId') ?? "";
      
  Future setOrderTracking(String data) async =>
      await _prefInstance!.setString(_orderTracking, data);

  String? get orderTracking => _prefInstance?.getString(_orderTracking) ?? "";
  
  // Camera permission tracking
  Future setCameraPermissionDeniedCount(int count) async =>
      await _prefInstance!.setInt(_cameraPermissionDeniedCount, count);

  int get cameraPermissionDeniedCount =>
      _prefInstance?.getInt(_cameraPermissionDeniedCount) ?? 0;

  // Banner image cache methods
  Future setBannerImageCache(String bannerId, String cacheData) async =>
      await _prefInstance!.setString('${_bannerImageCache}_$bannerId', cacheData);

  String? getBannerImageCache(String bannerId) =>
      _prefInstance?.getString('${_bannerImageCache}_$bannerId');

  Future removeBannerImageCache(String bannerId) async =>
      await _prefInstance!.remove('${_bannerImageCache}_$bannerId');

  Future<List<String>> getAllBannerCacheKeys() async {
    final keys = _prefInstance!.getKeys();
    return keys.where((key) => key.startsWith('${_bannerImageCache}_')).toList();
  }

  Future clearAllBannerCache() async {
    final keys = await getAllBannerCacheKeys();
    for (final key in keys) {
      await _prefInstance!.remove(key);
    }
  }

  // Banner seen tracking methods
  Future setBannerSeen(String userId, String bannerId) async =>
      await _prefInstance!.setBool('${_bannerSeen}_${userId}_$bannerId', true);

  bool isBannerSeen(String userId, String bannerId) =>
      _prefInstance?.getBool('${_bannerSeen}_${userId}_$bannerId') ?? false;

  Future<List<String>> getSeenBannerIds(String userId) async {
    final keys = _prefInstance!.getKeys();
    final seenKeys = keys.where((key) => key.startsWith('${_bannerSeen}_${userId}_')).toList();
    return seenKeys.map((key) => key.replaceFirst('${_bannerSeen}_${userId}_', '')).toList();
  }

  Future clearSeenBanners(String userId) async {
    final keys = _prefInstance!.getKeys();
    final seenKeys = keys.where((key) => key.startsWith('${_bannerSeen}_${userId}_')).toList();
    for (final key in seenKeys) {
      await _prefInstance!.remove(key);
    }
  }

  // Text Nugget seen tracking methods
  Future setTextNuggetSeen(String userId, String textId) async =>
      await _prefInstance!.setBool('${_textNuggetSeen}_${userId}_$textId', true);

  bool isTextNuggetSeen(String userId, String textId) =>
      _prefInstance?.getBool('${_textNuggetSeen}_${userId}_$textId') ?? false;

  Future<List<String>> getSeenTextNuggetIds(String userId) async {
    final keys = _prefInstance!.getKeys();
    final seenKeys = keys.where((key) => key.startsWith('${_textNuggetSeen}_${userId}_')).toList();
    return seenKeys.map((key) => key.replaceFirst('${_textNuggetSeen}_${userId}_', '')).toList();
  }

  Future clearSeenTextNuggets(String userId) async {
    final keys = _prefInstance!.getKeys();
    final seenKeys = keys.where((key) => key.startsWith('${_textNuggetSeen}_${userId}_')).toList();
    for (final key in seenKeys) {
      await _prefInstance!.remove(key);
    }
  }

  // Oplist cache methods with time-based expiry
  Future setOplistCache(String data) async =>
      await _prefInstance!.setString(_oplistCache, data);

  Future setOplistCacheTimestamp(int timestamp) async =>
      await _prefInstance!.setInt(_oplistCacheTimestamp, timestamp);

  String? get oplistCache => _prefInstance?.getString(_oplistCache);

  int? get oplistCacheTimestamp => _prefInstance?.getInt(_oplistCacheTimestamp);

  Future clearOplistCache() async {
    await _prefInstance?.remove(_oplistCache);
    await _prefInstance?.remove(_oplistCacheTimestamp);
  }

  // Ticker visibility
  Future setTickerVisible(bool isVisible) async =>
      await _prefInstance!.setBool(_isTickerVisible, isVisible);

  bool get isTickerVisible => _prefInstance?.getBool(_isTickerVisible) ?? true;

  // Saved custom strategies (per-user, stored as JSON string)
  Future setSavedCustomStrategies(String userId, String data) async =>
      await _prefInstance!.setString('${_savedCustomStrategies}_$userId', data);

  String? getSavedCustomStrategies(String userId) =>
      _prefInstance?.getString('${_savedCustomStrategies}_$userId');

  // Watchlist Option Chain - persisted symbol
  Future setWatchlistOCSymbol(String symbol) async =>
      await _prefInstance!.setString(_watchlistOCSymbol, symbol);

  String get watchlistOCSymbol =>
      _prefInstance?.getString(_watchlistOCSymbol) ?? '26000:NSE:Nifty 50:NFO';

  // Social / Spaces token storage
  Future setSocialAccessToken(String token) async =>
      await _prefInstance!.setString(_socialAccessToken, token);

  Future setSocialRefreshToken(String token) async =>
      await _prefInstance!.setString(_socialRefreshToken, token);

  Future setSocialUserId(String id) async =>
      await _prefInstance!.setString(_socialUserId, id);

  String? get socialAccessToken =>
      _prefInstance?.getString(_socialAccessToken) ?? "";

  String? get socialRefreshToken =>
      _prefInstance?.getString(_socialRefreshToken) ?? "";

  String? get socialUserId =>
      _prefInstance?.getString(_socialUserId) ?? "";

  Future clearSocialTokens() async {
    await _prefInstance?.remove(_socialAccessToken);
    await _prefInstance?.remove(_socialRefreshToken);
    await _prefInstance?.remove(_socialUserId);
  }

  // ── Scalper Settings ──────────────────────────────────────────────

  // Setters — called when user clicks Apply in scalper settings dialog (per-user)
  Future setScalperStrikeMode(String userId, String mode) async =>
      await _prefInstance!.setString('${_scalperStrikeMode}_$userId', mode);

  Future setScalperCallOffset(String userId, int offset) async =>
      await _prefInstance!.setInt('${_scalperCallOffset}_$userId', offset);

  Future setScalperPutOffset(String userId, int offset) async =>
      await _prefInstance!.setInt('${_scalperPutOffset}_$userId', offset);

  Future setScalperCallPremium(String userId, double premium) async =>
      await _prefInstance!.setDouble('${_scalperCallPremium}_$userId', premium);

  Future setScalperPutPremium(String userId, double premium) async =>
      await _prefInstance!.setDouble('${_scalperPutPremium}_$userId', premium);

  Future setScalperDefaultSymbol(String userId, int index) async =>
      await _prefInstance!.setInt('${_scalperDefaultSymbol}_$userId', index);

  Future setScalperMktProtEnabled(String userId, bool enabled) async =>
      await _prefInstance!.setBool('${_scalperMktProtEnabled}_$userId', enabled);

  Future setScalperMktProtPoints(String userId, int points) async =>
      await _prefInstance!.setInt('${_scalperMktProtPoints}_$userId', points);

  Future setScalperPosFilter(String userId, String filter) async =>
      await _prefInstance!.setString('${_scalperPosFilter}_$userId', filter);

  // Getters — called when ScalperProvider is created to restore saved values (per-user)
  String getScalperStrikeMode(String userId) =>
      _prefInstance?.getString('${_scalperStrikeMode}_$userId') ?? 'offset';

  int getScalperCallOffset(String userId) =>
      _prefInstance?.getInt('${_scalperCallOffset}_$userId') ?? 0;

  int getScalperPutOffset(String userId) =>
      _prefInstance?.getInt('${_scalperPutOffset}_$userId') ?? 0;

  double getScalperCallPremium(String userId) =>
      _prefInstance?.getDouble('${_scalperCallPremium}_$userId') ?? 100.0;

  double getScalperPutPremium(String userId) =>
      _prefInstance?.getDouble('${_scalperPutPremium}_$userId') ?? 100.0;

  int getScalperDefaultSymbol(String userId) =>
      _prefInstance?.getInt('${_scalperDefaultSymbol}_$userId') ?? 0;

  bool getScalperMktProtEnabled(String userId) =>
      _prefInstance?.getBool('${_scalperMktProtEnabled}_$userId') ?? false;

  int getScalperMktProtPoints(String userId) =>
      _prefInstance?.getInt('${_scalperMktProtPoints}_$userId') ?? 5;

  String getScalperPosFilter(String userId) =>
      _prefInstance?.getString('${_scalperPosFilter}_$userId') ?? 'all';

}

const String _userTheme = 'userTheme';
const String _userAppTheme = 'userAppTheme';

// const String _logOutClient = 'logOutClient';
const String _isLogout = "isLogout";
const String _deviceName = 'deviceName';
const String _imei = 'imei';

const String _ismobileLogin = 'ismobileLogin';

// QR session invalidation key — see setPendingQrUuid above.
const String _pendingQrUuid = 'pendingQrUuid';

const String _hideLoginOptBtn = 'hideLoginOptBtn';

// Cleint Details
const String _clientId = 'clientId';
const String _clientSession = 'clientSession';
const String _apiToken = 'apiToken';

const String _clientMob = 'clientMob';
const String _clientName = 'clientName';
const String _clientList = 'clientList';

const String _basketList = 'basketList';
const String _basketScrips = 'basketScrips';
const String _orderTracking = 'orderTracking';
const String _cameraPermissionDeniedCount = 'cameraPermissionDeniedCount';
const String _bannerImageCache = 'bannerImageCache';
const String _bannerSeen = 'bannerSeen';
const String _textNuggetSeen = 'textNuggetSeen';
const String _oplistCache = 'oplistCache';
const String _oplistCacheTimestamp = 'oplistCacheTimestamp';

////MARKET WATCH Filter
const String _isMWScripName = "isMWScripName";
const String _isMWPrice = "isMWPrice";
const String _isMWPrechange = "isMWPrechange";

////Holdings Filter
const String _isScripName = "isScripName";
const String _isPrice = "isPrice";
const String _isQuantity = "isQuantity";
const String _isPrechange = "isPrechange";
const String _isLtppc = "isLtppc";
const String _isInvest = "isInvest";

///MF FILTER
const String _isMfScripName = "isMfScripName";
const String _isMfPrice = "isMfPrice";
const String _isMfQuantity = "isMfQuantity";
const String _isMfPrechange = "isMfPrechange";
const String _isMfInvest = "isMfInvest";

///MF HOLDINGS FILTER (New)
const String _isMFName = "isMFName";
const String _isMFNav = "isMFNav";
const String _isMFUnit = "isMFUnit";
const String _isMFReturnPercChange = "isMFReturnPercChange";
const String _isMFInvestedPrice = "isMFInvestedPrice";

///POSTION FILTER
const String _isPosScripName = "isPosScripName";
const String _isPosPrice = "isPosPrice";
const String _isPosQuantity = "isPosQuantity";
const String _isPosPrechange = "isPosPrechange";
const String _isPostion = "isPostion";

////OREDER BOOK FILTER
const String _isObScripName = "isObScripName";
const String _isObPrice = "isObPrice";
const String _isObQuantity = "isObQuantity";
const String _isTime = "isTime";
const String _isProduct = "isProduct";

////OREDER BOOK GTT FILTER
const String _isGttScripName = "isgttScripName";
const String _isGttPrice = "isgttPrice";
const String _isGttQuantity = "isgttQuantity";
const String _isGttTime = "isgttTime";
const String _isGttProduct = "isgttProduct";

////PENDING ALERT FILTER
const String _isPAScripName = "ispaScripName";
const String _isPAPrice = "ispaPrice";
const String _isPApricealert = "ispapricealert";
const String _isPAChange = "ispaChange";

////TRADE BOOK FILTER
const String _isTbScripName = "isTbScripName";
const String _isTbPrice = "isTbPrice";
const String _isTbBuyorSell = "isTbBuyorSell";
const String _isTbTime = "isTbTime";

////SIP FILTER
const String _isSipScripName = "isSipScripName";
const String _isSipPrice = "isSipPrice";
const String _isSipPerchange = "isSipPerchange";
const String _isSipDate = "isSipDate";

////TICKER VISIBILITY
const String _isTickerVisible = "isTickerVisible";

////SAVED CUSTOM STRATEGIES
const String _savedCustomStrategies = "savedCustomStrategies";

////WATCHLIST OPTION CHAIN
const String _watchlistOCSymbol = "watchlistOCSymbol";

//// SOCIAL / SPACES
const String _socialAccessToken = "socialAccessToken";
const String _socialRefreshToken = "socialRefreshToken";
const String _socialUserId = "socialUserId";

//// SCALPER SETTINGS
const String _scalperStrikeMode = "scalperStrikeMode";
const String _scalperCallOffset = "scalperCallOffset";
const String _scalperPutOffset = "scalperPutOffset";
const String _scalperCallPremium = "scalperCallPremium";
const String _scalperPutPremium = "scalperPutPremium";
const String _scalperDefaultSymbol = "scalperDefaultSymbol";
const String _scalperMktProtEnabled = "scalperMktProtEnabled";
const String _scalperMktProtPoints = "scalperMktProtPoints";
const String _scalperPosFilter = "scalperPosFilter";

//// CHART ENGINE SESSION
const String _chartEngineSession = 'chartEngineSessionV1';
