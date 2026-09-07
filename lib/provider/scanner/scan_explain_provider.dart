import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/scan_explain.dart';

ApiExporter get _api => locator<ApiExporter>();

/// Per-(scope, id, ticker) scan explanation. The endpoint is deterministic
/// — same key always returns the same payload until the next nightly run —
/// so we don't invalidate on refresh; users hit retry explicitly via the
/// error UI when needed.
final scanExplainProvider =
    FutureProvider.family<ScanExplainResponse, ExplainKey>((_, key) {
  switch (key.scope) {
    case ExplainScope.builtin:
      return _api.fetchBuiltinExplain(key.id, key.ticker);
    case ExplainScope.custom:
      final cid = int.tryParse(key.id);
      if (cid == null) {
        throw ArgumentError(
            'ExplainKey.id must parse to int for custom scope (got "${key.id}")');
      }
      return _api.fetchCustomExplain(cid, key.ticker);
  }
});
