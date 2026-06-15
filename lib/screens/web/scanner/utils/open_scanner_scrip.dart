import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/marketwatch_model/get_quotes.dart'
    show DepthInputArgs;
import 'package:mynt_plus/models/marketwatch_model/search_scrip_new_model.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';

/// Click handler for "open symbol detail" from anywhere inside the Scanner
/// shell (scanner result row, fundamental result row, peers row).
///
/// Calls SearchScrip with the [ticker], picks the NSE-EQ entry, and stores a
/// [DepthInputArgs] in [scannerShellProvider] so the shell's right area
/// renders ChartWithDepthWeb. UI errors are surfaced via the same provider
/// state (`scripError`).
Future<void> openScannerScrip(
  WidgetRef ref, {
  required String ticker,
}) async {
  final notifier = ref.read(scannerShellProvider.notifier);
  notifier.setResolving(true);

  try {
    // Use searchScripForStrategyBuilder — it serializes `fil` with jsonEncode
    // so the body has `fil:["NSE"]` (proper JSON) instead of `fil:[NSE]` which
    // getSearchScripNew produces and the backend rejects.
    final SearchScripNewModel resp =
        await locator<ApiExporter>().searchScripForStrategyBuilder(
      searchText: ticker,
      exchanges: const ['NSE'],
    );

    final match = _pickBestEquityMatch(resp.values ?? const [], ticker);
    if (match == null) {
      notifier.setScripError(
        'Could not find "$ticker" on NSE. The ticker may be delisted or '
        'symbol mapping differs between scanner and broker.',
      );
      return;
    }

    notifier.setSelectedScrip(DepthInputArgs(
      exch: match.exch ?? 'NSE',
      token: match.token ?? '',
      tsym: match.tsym ?? ticker,
      instname: match.instname ?? 'EQ',
      symbol: match.symbol ?? ticker,
      expDate: match.expDate ?? '',
      option: match.option ?? '',
    ));
  } catch (e) {
    notifier.setScripError('Lookup failed: $e');
  }
}

/// Picks the best NSE EQ match for the given ticker. Falls back to the first
/// NSE entry, then to the first entry overall.
ScripNewValue? _pickBestEquityMatch(
    List<ScripNewValue> values, String ticker) {
  if (values.isEmpty) return null;
  final upper = ticker.toUpperCase();
  // Prefer exact NSE-EQ match like "RELIANCE-EQ".
  for (final v in values) {
    if (v.exch == 'NSE' &&
        (v.instname ?? '').toUpperCase() == 'EQ' &&
        (v.tsym ?? '').toUpperCase() == '$upper-EQ') {
      return v;
    }
  }
  // Fall back to symbol-name match on NSE-EQ.
  for (final v in values) {
    if (v.exch == 'NSE' &&
        (v.instname ?? '').toUpperCase() == 'EQ' &&
        (v.symbol ?? '').toUpperCase() == upper) {
      return v;
    }
  }
  // Any NSE entry.
  for (final v in values) {
    if (v.exch == 'NSE') return v;
  }
  return values.first;
}

/// Convenience for use inside a `ConsumerStatefulWidget` State — fire-and-
/// forget. The shell renders the loading / error / detail states from
/// `scannerShellProvider` automatically.
void openScannerScripFromContext(BuildContext context, WidgetRef ref,
    {required String ticker}) {
  // ignore: discarded_futures
  openScannerScrip(ref, ticker: ticker);
}
