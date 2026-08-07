import 'dart:async';
import 'dart:developer';

import '../models/rupeecase_model/algo_strategy_model.dart';
import '../models/rupeecase_model/rupeecase_strategy_model.dart';
import 'core/api_core.dart';

/// API mixin for the RupeeCase curated-strategies marketplace.
///
/// Read-only endpoint that powers the "Curated Strategies" card row on the web
/// dashboard. Returns `null` on any failure so the caller can silently hide the
/// section instead of surfacing an error to the user.
mixin RupeeCaseApi on ApiCore {
  Future<RupeeCaseStrategiesResponse?> fetchRupeeCaseStrategies() async {
    try {
      final uri = Uri.parse(apiLinks.rupeeCaseStrategies);

      final res = await apiClient.get(uri, headers: defaultHeaders).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException(
          'RupeeCase strategies request timed out',
          const Duration(seconds: 12),
        ),
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map<String, dynamic>) {
          return RupeeCaseStrategiesResponse.fromJson(json);
        }
        log('RupeeCase strategies: unexpected payload shape');
        return null;
      }

      log('RupeeCase strategies failed - Status: ${res.statusCode}');
      return null;
    } catch (e, stackTrace) {
      log('Error fetching RupeeCase strategies: $e');
      log('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Fetches the algo (automated) strategy baskets shown in the "Algo" tab of
  /// the dashboard Strategies section. Same read-only, fail-soft contract as
  /// [fetchRupeeCaseStrategies] — returns `null` on any failure.
  Future<AlgoStrategiesResponse?> fetchAlgoStrategies() async {
    try {
      final uri = Uri.parse(apiLinks.rupeeCaseAlgoStrategies);

      final res = await apiClient.get(uri, headers: defaultHeaders).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException(
          'Algo strategies request timed out',
          const Duration(seconds: 12),
        ),
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map<String, dynamic>) {
          return AlgoStrategiesResponse.fromJson(json);
        }
        log('Algo strategies: unexpected payload shape');
        return null;
      }

      log('Algo strategies failed - Status: ${res.statusCode}');
      return null;
    } catch (e, stackTrace) {
      log('Error fetching algo strategies: $e');
      log('Stack trace: $stackTrace');
      return null;
    }
  }
}
