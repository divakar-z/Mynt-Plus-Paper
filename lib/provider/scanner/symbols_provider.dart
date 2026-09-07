import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/financials.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_score.dart';
import 'package:mynt_plus/models/scanner_model/ohlcv.dart';
import 'package:mynt_plus/models/scanner_model/peers.dart';
import 'package:mynt_plus/models/scanner_model/performance.dart';
import 'package:mynt_plus/models/scanner_model/scan_details.dart';
import 'package:mynt_plus/models/scanner_model/symbol.dart' as model;
import 'package:mynt_plus/models/scanner_model/symbol_info.dart';
import 'package:mynt_plus/models/scanner_model/technicals.dart';

ApiExporter get _api => locator<ApiExporter>();

/// Symbol-search results, keyed by the debounced query.
final symbolSearchProvider =
    FutureProvider.family<model.SymbolListResponse, String>((ref, q) async {
  if (q.trim().isEmpty) {
    return const model.SymbolListResponse(
        items: [], total: 0, page: 1, pageSize: 0);
  }
  return _api.fetchSymbols(q: q, pageSize: 20);
});

final symbolMetaProvider =
    FutureProvider.family<model.Symbol, String>((_, t) => _api.fetchSymbol(t));

/// Ohlcv keyed by ticker+optional `from` date.
final ohlcvProvider =
    FutureProvider.family<OhlcvResponse, ({String ticker, String? from})>(
        (_, args) => _api.fetchOhlcv(args.ticker, from: args.from));

final technicalsProvider = FutureProvider.family<TechnicalsResponse, String>(
    (_, t) => _api.fetchTechnicals(t));

final performanceProvider = FutureProvider.family<PerformanceResponse, String>(
    (_, t) => _api.fetchPerformance(t));

final symbolScannersProvider = FutureProvider.family<List<String>, String>(
    (_, t) => _api.fetchSymbolScanners(t));

/// Rich per-symbol scan matches (name + sentiment + columns + values) backing
/// the expandable Scans tab. Keyed by ticker; `as_of` defaults to latest.
final scanDetailsProvider =
    FutureProvider.family<ScanDetailsResponse, String>(
        (_, t) => _api.fetchScanDetails(t));

final symbolInfoProvider = FutureProvider.family<SymbolInfo, String>(
    (_, t) => _api.fetchSymbolInfo(t));

final fundamentalScoreProvider = FutureProvider.family<FundamentalScore, String>(
    (_, t) => _api.fetchFundamentalScore(t));

final financialsProvider = FutureProvider.family<FinancialsResponse,
    ({String ticker, String period, String statement, String basis})>(
        (_, args) => _api.fetchFinancials(
              args.ticker,
              period: args.period,
              statement: args.statement,
              basis: args.basis,
            ));

final peersProvider =
    FutureProvider.family<PeersResponse, String>((_, t) => _api.fetchPeers(t));

final holdersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (_, t) => _api.fetchHolders(t));

final newsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (_, t) => _api.fetchSymbolNews(t));

final dividendsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (_, t) => _api.fetchDividends(t));

final deliveriesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (_, t) => _api.fetchDeliveries(t));
