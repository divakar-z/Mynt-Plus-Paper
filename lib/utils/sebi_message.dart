import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../locator/locator.dart';
import '../main.dart' show getNavigatorState;
import '../locator/preference.dart';
import '../sharedWidget/risk_disclosure_bottom_sheet.dart';

const _sebiUrl = 'https://dwld.zebuetrade.com/strapi/api/jagrook-message';
const _weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

const _defaultSchedule = {
  'from': '2026-11-01',
  'days': {
    'mon': 'jagrook',
    'tue': 'risk',
    'wed': 'jagrook',
    'thu': 'risk',
    'fri': 'jagrook',
    'sat': 'risk',
    'sun': 'jagrook',
  },
};

// Built-in copy, used when Strapi is down and nothing is saved yet.
const _builtInJagrook = {
  'en': {
    'kicker': 'SEBI presents',
    'title': 'Samajh Se Investing Simple',
    'points': [
      'Understand Before You Invest',
      'Choose Regulated Investment Products',
      'Start Early, Stay Invested',
      'Beware of Investment Frauds',
    ],
    'note': 'Investor awareness initiative by SEBI',
  },
  'hi': {
    'kicker': 'SEBI प्रस्तुत करता है',
    'title': '‘समझ से निवेश’',
    'points': [
      'सरल निवेश: निवेश करने से पहले समझें',
      'विनियमित निवेश उत्पादों का चयन करें',
      'जल्दी शुरुआत करें, निवेशित बने रहें',
      'निवेश संबंधी धोखाधड़ी से सावधान रहें।',
    ],
    'note': 'SEBI की निवेशक जागरूकता पहल',
  },
};

const _builtInRisk = {
  'en': {
    'title': 'Risk Disclosures on Derivatives',
    'points': [
      '9 out of 10 individual traders in the equity Futures and Options (F&O) segment incurred net losses.',
      'On average, the loss-making traders registered a net trading loss close to ₹50,000.',
      'Over and above the net trading losses incurred, loss makers expended an additional 28% of net trading losses as transaction costs.',
      'Those making net trading profits incurred between 15% to 50% of such profits as transaction costs.',
    ],
    'source':
        "Source: SEBI study dated January 25, 2023, on 'Analysis of Profit and Loss of Individual Traders dealing in equity Futures and Options (F&O) Segment,' wherein Aggregate Level findings are based on annual Profit/Loss incurred by individual traders in equity F&O during FY 2021-22.",
  },
};

class SebiMessage {
  const SebiMessage({
    required this.isRisk,
    required this.en,
    required this.hi,
    required this.ackValue,
    required this.date,
    required this.version,
    required this.started,
  });

  final bool isRisk;
  final bool started; // false before schedule.from: old one-time Risk Disclosure
  final Map en;
  final Map? hi; // null when there is no valid Hindi block
  final String ackValue; // "<date>|<version>"
  final String date;
  final String version;
}

bool isValidBlock(dynamic c) =>
    c is Map &&
    c['title'] is String &&
    (c['title'] as String).isNotEmpty &&
    c['points'] is List &&
    (c['points'] as List).isNotEmpty;

String _two(int n) => n.toString().padLeft(2, '0');

Map _scheduleOf(dynamic schedule) =>
    schedule is Map && schedule['from'] is String && schedule['days'] is Map
        ? schedule
        : _defaultSchedule;

/// Whether the day-wise schedule has started on [now] (the device's local date).
bool scheduleStarted(dynamic schedule, DateTime now) {
  final date = '${now.year}-${_two(now.month)}-${_two(now.day)}';
  return date.compareTo(_scheduleOf(schedule)['from'] as String) >= 0;
}

/// "risk" or "jagrook" for [now] (the device's local date).
String messageFor(dynamic schedule, DateTime now) {
  final day = _weekdays[now.weekday - 1];
  return scheduleStarted(schedule, now) &&
          (_scheduleOf(schedule)['days'] as Map)[day] == 'risk'
      ? 'risk'
      : 'jagrook';
}

Future<Map?> _fetchEntry(Preferences pref) async {
  try {
    final res =
        await http.get(Uri.parse(_sebiUrl)).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final attrs = body is Map && body['data'] is Map
        ? body['data']['attributes']
        : null;
    if (attrs is! Map || attrs['content'] == null) throw Exception('empty');
    final entry = {
      'content': attrs['content'],
      'risk': attrs['risk'],
      'schedule': attrs['schedule'],
      'version': attrs['updatedAt'],
    };
    await pref.setSebiCopy(jsonEncode(entry));
    return entry;
  } catch (_) {
    try {
      final saved = jsonDecode(pref.sebiCopy ?? 'null');
      return saved is Map && saved['content'] != null ? saved : null;
    } catch (_) {
      return null; // built-in copy is used
    }
  }
}

Future<SebiMessage> loadSebiMessage() async {
  final pref = locator<Preferences>();
  final entry = await _fetchEntry(pref);
  final now = DateTime.now();
  final started = scheduleStarted(entry?['schedule'], now);
  final isRisk = !started || messageFor(entry?['schedule'], now) == 'risk';
  final dynamic live = entry?[isRisk ? 'risk' : 'content'];
  final Map builtIn = isRisk ? _builtInRisk : _builtInJagrook;

  Map? block(String lang) {
    if (live is Map && isValidBlock(live[lang])) return live[lang] as Map;
    final dynamic fallback = builtIn[lang];
    if (isValidBlock(fallback)) return fallback as Map;
    return null;
  }

  final date = '${now.year}-${_two(now.month)}-${_two(now.day)}';
  final version = entry?['version']?.toString() ?? '';
  return SebiMessage(
    isRisk: isRisk,
    en: block('en')!,
    hi: block('hi'),
    ackValue: '$date|$version',
    date: date,
    version: version,
    started: started,
  );
}

/// Shows today's SEBI message once per day (and again after a Strapi republish).
Future<void> showSebiMessageIfNeeded() async {
  final pref = locator<Preferences>();
  final message = await loadSebiMessage();
  final ack = pref.sebiAck ?? '';
  // Before the schedule starts, keep the old flow: Risk Disclosure until acked once.
  // With no version known (Strapi down + nothing saved), any ack today counts.
  final seen = !message.started
      ? pref.showRiskDis == 'true'
      : message.version.isNotEmpty
          ? ack == message.ackValue
          : ack.startsWith('${message.date}|');
  if (seen) return;

  // The login screen's context is gone once the app navigates home, so show
  // the dialog on the app's root navigator instead.
  final overlayContext = getNavigatorState()?.overlay?.context;
  if (overlayContext == null || !overlayContext.mounted) return;

  await showDialog(
    context: overlayContext,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: RiskDisclousreBottomSheet(message: message),
          ),
        ),
      );
    },
  );
  // The dialog only closes via "I Understand".
  if (!message.started) await pref.setRiskDiscloser(true);
}
