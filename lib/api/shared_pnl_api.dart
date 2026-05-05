// TODO: paste shared_pnl_api.dart contents from the other project here.
// Public, unauthenticated API for fetching a previously-shared PnL by ucode.
//
// Mirrors the Vue viewer's two-step flow:
//   1) POST https://rekycbe.mynt.in/report/getsharedata
//      Body: { "Unique_Code": "<ucode>" }
//      Headers: Content-Type only — no Authorization, no clientid.
//
//   2) Commodity-only follow-up call when seg == "Commodity":
//      POST https://rekycbe.mynt.in/report/getJournalDiary3
//      Body: { "cc", "from", "to", "segment": "MCX,NCDEX,NSE_COM,BSE_COM" }
//      Headers: Content-Type only.
//      The first call only returns metadata for commodity (cc, dates, seg);
//      this second call fetches the actual symbolWise / dateWise / stat data.
//      Mirrors Vue's `fetchCommodityShareData` (Daily_pnl.vue:2786-2895).

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shared_pnl_model.dart';
import 'core/api_link.dart';

class SharedPnlApi {
  Future<SharedPnlModel> fetchByUcode(String ucode) async {
    final base = ApiLinks().reportsapi;
    final initial = await _post(
      Uri.parse('${base}getsharedata'),
      {'Unique_Code': ucode},
    );

    // If /getsharedata already returned the full commodity payload inline,
    // skip the second call.
    final hasInlineData = (initial.data?.dateGrouped.isNotEmpty ?? false) ||
        (initial.data?.trades.isNotEmpty ?? false) ||
        (initial.data?.journal.isNotEmpty ?? false);

    if (initial.isCommodity &&
        !hasInlineData &&
        (initial.cc ?? '').isNotEmpty &&
        (initial.fromDate ?? '').isNotEmpty &&
        (initial.toDate ?? '').isNotEmpty) {
      final commodityRaw = await _postRaw(
        Uri.parse('${base}getJournalDiary3'),
        {
          'cc': initial.cc,
          'from': initial.fromDate,
          'to': initial.toDate,
          'segment': 'MCX,NCDEX,NSE_COM,BSE_COM',
        },
      );

      // Vue checks `response.data.stat == 'Not Ok'` (top-level stat, not the nested one)
      // to detect the empty case (Daily_pnl.vue:2804).
      if (commodityRaw['stat'] == 'Not Ok') {
        return initial;
      }
      final commodityData = SharedPnlData.fromCommodityJson(commodityRaw);
      return initial.withData(commodityData);
    }

    return initial;
  }

  Future<SharedPnlModel> _post(Uri uri, Map<String, dynamic> body) async {
    final json = await _postRaw(uri, body);
    return SharedPnlModel.fromJson(json);
  }

  Future<Map<String, dynamic>> _postRaw(
      Uri uri, Map<String, dynamic> body) async {
    final res = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('${uri.path} returned ${res.statusCode}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('${uri.path} response was not a JSON object');
    }
    return decoded;
  }
}
