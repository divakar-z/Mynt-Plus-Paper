import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/market_index.dart';

ApiExporter get _api => locator<ApiExporter>();

/// The NSE index catalog used by the scanner / custom-scan result-page
/// filter dropdown. Fetched once and kept alive for the rest of the
/// session — the server refreshes its list daily, so anything more
/// aggressive than that is wasted work.
final marketIndicesProvider = FutureProvider<List<MarketIndex>>((ref) async {
  ref.keepAlive();
  return _api.fetchMarketIndices();
});
