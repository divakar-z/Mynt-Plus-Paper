import 'package:http/http.dart' as http;
import 'package:mynt_plus/models/scanner_model/custom_scan.dart';
import 'package:mynt_plus/models/scanner_model/financials.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_categories.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_score.dart';
import 'package:mynt_plus/models/scanner_model/indicator_catalog.dart';
import 'package:mynt_plus/models/scanner_model/market_index.dart';
import 'package:mynt_plus/models/scanner_model/ohlcv.dart';
import 'package:mynt_plus/models/scanner_model/peers.dart';
import 'package:mynt_plus/models/scanner_model/performance.dart';
import 'package:mynt_plus/models/scanner_model/saved_screen.dart';
import 'package:mynt_plus/models/scanner_model/scan_details.dart';
import 'package:mynt_plus/models/scanner_model/scan_explain.dart';
import 'package:mynt_plus/models/scanner_model/scan_result.dart';
import 'package:mynt_plus/models/scanner_model/scanner.dart' as model;
import 'package:mynt_plus/models/scanner_model/scanner_exception.dart';
import 'package:mynt_plus/models/scanner_model/symbol.dart' as model;
import 'package:mynt_plus/models/scanner_model/symbol_info.dart';
import 'package:mynt_plus/models/scanner_model/technicals.dart';
import 'core/api_core.dart';

/// API mixin for the StockScanner backend (FastAPI service).
///
/// Endpoints are grouped by spec section:
///   /symbols/*           — universe + per-symbol detail tabs
///   /scanners/*          — built-in technical scanners
///   /scans/fundamental/* — fundamental screener + saved screens
///   /scans/*             — custom predicate scanners (CRUD + run)
///
/// All methods throw [StockScannerException] on non-2xx responses or network
/// failures. Callers should catch at the provider boundary and surface to UI.
mixin StockScannerApi on ApiCore {
  // --- Shared helpers ------------------------------------------------------

  Uri _u(String path, [Map<String, dynamic>? q]) {
    final base = apiLinks.stockScannerApi;
    final url = '$base$path';
    if (q == null || q.isEmpty) return Uri.parse(url);
    final cleaned = <String, String>{};
    q.forEach((k, v) {
      if (v == null) return;
      cleaned[k] = v.toString();
    });
    return Uri.parse(url).replace(queryParameters: cleaned);
  }

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    http.Response r;
    try {
      r = await apiClient.get(_u(path, query), headers: defaultHeaders);
    } catch (e) {
      throw StockScannerException.network(e);
    }
    return _decodeOrThrow(r);
  }

  Future<dynamic> _post(
    String path,
    Map<String, dynamic> body, {
    Map<String, dynamic>? query,
  }) async {
    http.Response r;
    try {
      r = await apiClient.post(
        _u(path, query),
        headers: defaultHeaders,
        body: jsonEncode(body),
      );
    } catch (e) {
      throw StockScannerException.network(e);
    }
    return _decodeOrThrow(r);
  }

  Future<void> _delete(String path, {Map<String, dynamic>? query}) async {
    http.Response r;
    try {
      r = await apiClient.delete(_u(path, query), headers: defaultHeaders);
    } catch (e) {
      throw StockScannerException.network(e);
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      _throwFromResponse(r);
    }
  }

  /// Logged-in client code (e.g. "ZP00172") — saved custom scans and saved
  /// fundamental screens are scoped per-user on the backend as of
  /// 2026-06-12. Sent in the create body and as `?user_id=` on every
  /// by-id operation; the backend 404s when the item belongs to someone
  /// else. Empty when somehow not logged in — backend then treats the
  /// request as the legacy shared/admin scope.
  String get _scanUserId => prefs.clientId ?? '';

  Future<({List<int> bytes, String? filename})> _downloadBlob(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? postBody,
  }) async {
    http.Response r;
    try {
      if (postBody != null) {
        r = await apiClient.post(
          _u(path, query),
          headers: defaultHeaders,
          body: jsonEncode(postBody),
        );
      } else {
        r = await apiClient.get(_u(path, query), headers: defaultHeaders);
      }
    } catch (e) {
      throw StockScannerException.network(e);
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      _throwFromResponse(r);
    }
    String? filename;
    final cd = r.headers['content-disposition'];
    if (cd != null) {
      final m = RegExp(r'filename="?([^"]+)"?').firstMatch(cd);
      if (m != null) filename = m.group(1);
    }
    return (bytes: r.bodyBytes, filename: filename);
  }

  dynamic _decodeOrThrow(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      _throwFromResponse(r);
    }
    if (r.bodyBytes.isEmpty) return null;
    // Always decode as UTF-8 from bytes — `r.body` uses Latin-1 unless the
    // response sets `charset=utf-8` explicitly, which mangles symbols like ×.
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  Never _throwFromResponse(http.Response r) {
    String backendMessage = '';
    String errorCode = '';
    Map<String, dynamic>? detail;
    try {
      final body = r.bodyBytes.isEmpty ? '' : utf8.decode(r.bodyBytes);
      if (body.isNotEmpty) {
        final j = jsonDecode(body);
        if (j is Map) {
          backendMessage = (j['message'] ?? '').toString();
          errorCode = (j['error'] ?? '').toString();
          if (j['detail'] is Map) {
            detail = Map<String, dynamic>.from(j['detail'] as Map);
          }
        }
      }
    } catch (_) {
      // body wasn't JSON — leave fields empty
    }
    throw StockScannerException.fromResponse(
      statusCode: r.statusCode,
      backendMessage: backendMessage,
      errorCode: errorCode,
      detail: detail,
    );
  }

  // --- /symbols/* ----------------------------------------------------------

  Future<model.SymbolListResponse> fetchSymbols({
    String? q,
    int page = 1,
    int pageSize = 50,
  }) async {
    final j = await _get('/symbols', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      'page': page,
      'page_size': pageSize,
    });
    return model.SymbolListResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<model.Symbol> fetchSymbol(String ticker) async {
    final j = await _get('/symbols/$ticker');
    return model.Symbol.fromJson(j as Map<String, dynamic>);
  }

  Future<OhlcvResponse> fetchOhlcv(
    String ticker, {
    String? from,
    String? to,
    bool adjusted = true,
  }) async {
    final j = await _get('/symbols/$ticker/ohlcv', query: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      'adjusted': adjusted,
    });
    return OhlcvResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<TechnicalsResponse> fetchTechnicals(String ticker) async {
    final j = await _get('/symbols/$ticker/technicals');
    return TechnicalsResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<PerformanceResponse> fetchPerformance(String ticker) async {
    final j = await _get('/symbols/$ticker/performance');
    return PerformanceResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<List<String>> fetchSymbolScanners(String ticker,
      {String date = 'latest'}) async {
    final j = await _get('/symbols/$ticker/scanners', query: {'date': date});
    return (j as List).map((e) => e.toString()).toList();
  }

  /// Every built-in scanner this symbol matches, each with its own result
  /// `columns` and the symbol's computed `values` — backs the expandable
  /// "Scans" tab. `as_of` defaults to the symbol's latest scan date.
  Future<ScanDetailsResponse> fetchScanDetails(String ticker,
      {String? asOf}) async {
    final j = await _get('/symbols/$ticker/scan-details',
        query: {if (asOf != null) 'as_of': asOf});
    return ScanDetailsResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<SymbolInfo> fetchSymbolInfo(String ticker) async {
    final j = await _get('/symbols/$ticker/info');
    return SymbolInfo.fromJson(j as Map<String, dynamic>);
  }

  Future<FundamentalScore> fetchFundamentalScore(String ticker) async {
    final j = await _get('/symbols/$ticker/fundamental-score');
    return FundamentalScore.fromJson(j as Map<String, dynamic>);
  }

  Future<FinancialsResponse> fetchFinancials(
    String ticker, {
    String period = 'quarterly',
    String statement = 'income',
    String basis = 'standalone',
  }) async {
    final j = await _get('/symbols/$ticker/financials',
        query: {'period': period, 'statement': statement, 'basis': basis});
    return FinancialsResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<PeersResponse> fetchPeers(String ticker, {int limit = 10}) async {
    final j = await _get('/symbols/$ticker/peers', query: {'limit': limit});
    return PeersResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> fetchHolders(String ticker) async {
    final j = await _get('/symbols/$ticker/holders');
    if (j is! List) return const [];
    return j.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchSymbolNews(String ticker) async {
    final j = await _get('/symbols/$ticker/news');
    if (j is! List) return const [];
    return j.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchDividends(String ticker) async {
    final j = await _get('/symbols/$ticker/dividends');
    if (j is! List) return const [];
    return j.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchDeliveries(String ticker) async {
    final j = await _get('/symbols/$ticker/deliveries');
    if (j is! List) return const [];
    return j.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchAnnouncements(String ticker) async {
    final j = await _get('/symbols/$ticker/announcements');
    if (j is! List) return const [];
    return j.cast<Map<String, dynamic>>();
  }

  // --- /scanners/* ---------------------------------------------------------

  Future<model.ScannerListResponse> fetchScanners({
    String? group,
    String? subGroup,
    String? q,
    int page = 1,
    int pageSize = 100,
  }) async {
    final j = await _get('/scanners', query: {
      if (group != null) 'group': group,
      if (subGroup != null) 'sub_group': subGroup,
      if (q != null && q.isNotEmpty) 'q': q,
      'page': page,
      'page_size': pageSize,
    });
    return model.ScannerListResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<model.Scanner> fetchScanner(String code) async {
    final j = await _get('/scanners/$code');
    return model.Scanner.fromJson(j as Map<String, dynamic>);
  }

  Future<ScanResultsDetail> fetchScannerResults(
    String code, {
    String date = 'latest',
    int limit = 5000,
    int offset = 0,
    bool detail = true,
    List<String>? indices,
  }) async {
    final j = await _get('/scanners/$code/results', query: {
      'date': date,
      'limit': limit,
      'offset': offset,
      'detail': detail,
      // Server expects comma-separated index names, URL-encoded by the
      // http package. OR semantics across the list. Omit the key entirely
      // when nothing is selected so the backend returns the full universe.
      if (indices != null && indices.isNotEmpty)
        'indices': indices.join(','),
      // Ask for per-index match counts on every call. Backends that
      // haven't shipped the feature silently ignore it, so this is safe
      // forward-compat — the dropdown lights up automatically when the
      // server starts honouring the flag.
      'include_index_counts': true,
    });
    return ScanResultsDetail.fromJson(j as Map<String, dynamic>);
  }

  Future<({List<int> bytes, String? filename})>
      downloadScannerExportXlsx(String code, {String columns = 'visible'}) {
    return _downloadBlob('/scanners/$code/export', query: {'columns': columns});
  }

  /// Per-ticker explanation for a built-in scanner. See spec §4.6.
  /// Throws [StockScannerException] with `errorCode` of `symbol_not_found`
  /// (404), `scanner_not_found` (404), `no_prices` (409), or
  /// `benchmark_required` (422) — callers should switch on `errorCode` to
  /// surface the right user message.
  Future<ScanExplainResponse> fetchBuiltinExplain(
    String code,
    String ticker, {
    String date = 'latest',
  }) async {
    final j = await _get('/scanners/$code/explain/$ticker',
        query: {'date': date});
    return ScanExplainResponse.fromJson(j as Map<String, dynamic>);
  }

  /// Per-ticker explanation for a saved custom scan. Same response shape as
  /// [fetchBuiltinExplain]; the 404 error code is `custom_not_found` instead
  /// of `scanner_not_found` when the saved id doesn't exist.
  Future<ScanExplainResponse> fetchCustomExplain(
    int cid,
    String ticker, {
    String date = 'latest',
  }) async {
    final j = await _get('/scans/saved/$cid/explain/$ticker',
        query: {'date': date, 'user_id': _scanUserId});
    return ScanExplainResponse.fromJson(j as Map<String, dynamic>);
  }

  // --- /scans/fundamental/* -----------------------------------------------

  Future<List<FundamentalField>> fetchFundamentalFields() async {
    final j = await _get('/scans/fundamental/fields');
    return (j as List)
        .cast<Map<String, dynamic>>()
        .map(FundamentalField.fromJson)
        .toList();
  }

  Future<List<FundamentalPreset>> fetchFundamentalPresets() async {
    final j = await _get('/scans/fundamental/presets');
    return (j as List)
        .cast<Map<String, dynamic>>()
        .map(FundamentalPreset.fromJson)
        .toList();
  }

  /// Sector + industry option lists for the Sector / Industry multiselect
  /// filters — global reference data, fetched once and cached by the provider.
  Future<FundamentalCategories> fetchFundamentalCategories() async {
    final j = await _get('/scans/fundamental/categories');
    return FundamentalCategories.fromJson(j as Map<String, dynamic>);
  }

  Future<FundamentalScanResponse> runFundamentalScan(
      FundamentalScanRequest req) async {
    final j = await _post('/scans/fundamental', req.toJson());
    return FundamentalScanResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<({List<int> bytes, String? filename})> downloadFundamentalExportXlsx({
    required FundamentalScanRequest req,
    required String columns,
    List<String> customColumns = const [],
  }) {
    final body = {
      ...req.toJson(),
      'columns': columns,
      if (columns == 'custom') 'custom_columns': customColumns,
    };
    return _downloadBlob('/scans/fundamental/export', postBody: body);
  }

  Future<List<SavedFundamentalScreen>> listSavedScreens() async {
    final j = await _get('/scans/fundamental/saved',
        query: {'user_id': _scanUserId});
    return (j as List)
        .cast<Map<String, dynamic>>()
        .map(SavedFundamentalScreen.fromJson)
        .toList();
  }

  Future<SavedFundamentalScreen> getSavedScreen(int id) async {
    final j = await _get('/scans/fundamental/saved/$id',
        query: {'user_id': _scanUserId});
    return SavedFundamentalScreen.fromJson(j as Map<String, dynamic>);
  }

  Future<SavedFundamentalScreen> saveScreen({
    required String name,
    required List<FundamentalFilter> filters,
    String treatNullAs = 'fail',
    String? orderBy,
    String? orderDir,
    int? limit,
  }) async {
    final j = await _post('/scans/fundamental/saved', {
      'name': name,
      'filters': filters.map((f) => f.toJson()).toList(),
      'treat_null_as': treatNullAs,
      if (orderBy != null) 'order_by': orderBy,
      if (orderDir != null) 'order_dir': orderDir,
      if (limit != null) 'limit': limit,
      'user_id': _scanUserId,
    });
    return SavedFundamentalScreen.fromJson(j as Map<String, dynamic>);
  }

  Future<FundamentalScanResponse> runSavedScreen(int id) async {
    final j = await _post('/scans/fundamental/saved/$id/run', {},
        query: {'user_id': _scanUserId});
    return FundamentalScanResponse.fromJson(j as Map<String, dynamic>);
  }

  Future<void> deleteSavedScreen(int id) async {
    await _delete('/scans/fundamental/saved/$id',
        query: {'user_id': _scanUserId});
  }

  // --- /indices/* ----------------------------------------------------------

  /// All NSE indices the backend knows about (~86 entries, sorted
  /// alphabetically). Used to populate the multi-select dropdown above
  /// scanner results. The list is stable (refreshed daily server-side at
  /// 18:35 IST) — see `marketIndicesProvider` for the long-lived cache.
  Future<List<MarketIndex>> fetchMarketIndices() async {
    final j = await _get('/indices/market');
    final m = j as Map<String, dynamic>;
    final list = (m['indices'] as List?) ?? const [];
    return list
        .cast<Map<String, dynamic>>()
        .map(MarketIndex.fromJson)
        .toList();
  }

  // --- /indicators (static catalog) ----------------------------------------

  /// Catalog of all available indicators (categories, kinds, params,
  /// enum_values, needs_benchmark). The response is static metadata — cache
  /// it forever client-side (see `indicatorCatalogProvider`).
  Future<IndicatorCatalog> fetchIndicatorCatalog() async {
    final j = await _get('/indicators');
    return IndicatorCatalog.fromJson(j as Map<String, dynamic>);
  }

  // --- /scans/* (custom) ---------------------------------------------------

  Future<CustomScanRunResult> runCustomScan({
    required Map<String, dynamic> predicate,
    String asOf = 'latest',
    List<String>? indices,
  }) async {
    final j = await _post('/scans/run', {
      'predicate': predicate,
      'as_of': asOf,
      // Backend treats omitted/null as "no filter". Pass through only when
      // the user actually picked indices so we don't lock the universe to
      // empty unintentionally.
      if (indices != null && indices.isNotEmpty) 'indices': indices,
      'include_index_counts': true,
    });
    return CustomScanRunResult.fromJson(j as Map<String, dynamic>);
  }

  Future<SavedCustomScan> saveCustomScan({
    required String name,
    required Map<String, dynamic> predicate,
  }) async {
    final j = await _post('/scans/saved', {
      'name': name,
      'predicate': predicate,
      'user_id': _scanUserId,
    });
    return SavedCustomScan.fromJson(j as Map<String, dynamic>);
  }

  Future<List<SavedCustomScan>> listSavedCustomScans() async {
    final j = await _get('/scans/saved', query: {'user_id': _scanUserId});
    return (j as List)
        .cast<Map<String, dynamic>>()
        .map(SavedCustomScan.fromJson)
        .toList();
  }

  Future<SavedCustomScan> getSavedCustomScan(int id) async {
    final j =
        await _get('/scans/saved/$id', query: {'user_id': _scanUserId});
    return SavedCustomScan.fromJson(j as Map<String, dynamic>);
  }

  Future<CustomScanRunResult> runSavedCustomScan(
    int id, {
    List<String>? indices,
    String? asOf,
  }) async {
    // Saved-scan run accepts an OPTIONAL body — older servers tolerate
    // either {} or unknown extra keys, so it's safe to always include
    // include_index_counts here too. Backend ignores it until the
    // feature ships.
    final body = <String, dynamic>{
      if (indices != null && indices.isNotEmpty) 'indices': indices,
      if (asOf != null) 'as_of': asOf,
      'include_index_counts': true,
    };
    final j = await _post('/scans/saved/$id/run', body,
        query: {'user_id': _scanUserId});
    return CustomScanRunResult.fromJson(j as Map<String, dynamic>);
  }

  Future<void> deleteSavedCustomScan(int id) async {
    await _delete('/scans/saved/$id', query: {'user_id': _scanUserId});
  }
}
