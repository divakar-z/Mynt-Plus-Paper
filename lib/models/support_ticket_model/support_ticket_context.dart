import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The diagnostic block sent alongside a ticket.
///
/// None of this is typed by the client. The backend appends it to the ticket
/// body so the agent sees which screen, which build and which browser without
/// having to ask — that back-and-forth is most of what makes a phone call slow.
///
/// Best-effort by design: every field falls back to a placeholder rather than
/// throwing. A ticket that reaches the desk with an unknown browser is far
/// better than one the client could not raise because a lookup failed.
class SupportTicketContext {
  const SupportTicketContext({
    required this.screen,
    required this.appVersion,
    required this.platform,
    required this.browser,
    required this.occurredAt,
  });

  /// Where the client was when they hit Raise — e.g. `/orders`.
  final String screen;

  /// The running build, from `pubspec.yaml` via `PackageInfo`.
  final String appVersion;

  /// Always `web` — this project ships the browser build only. The field
  /// exists so the backend route can serve a mobile client later without a
  /// contract change.
  final String platform;

  /// Human-readable, e.g. `Chrome 128 / Windows 10 or 11` — for an agent to
  /// read, not to parse. The raw user-agent is deliberately not sent: it is
  /// long, noisy in a ticket body, and adds nothing an agent can act on.
  final String browser;

  /// Local time with offset, e.g. `2026-08-20T15:04:05+05:30`.
  final String occurredAt;

  /// Gathers the context at the moment the client submits.
  ///
  /// [screen] is passed in because only the caller knows which surface it was
  /// opened from — there is no reliable way to read the active panel from here.
  static Future<SupportTicketContext> capture({required String screen}) async {
    return SupportTicketContext(
      screen: screen,
      appVersion: await _appVersion(),
      platform: 'web',
      browser: await _browser(),
      occurredAt: nowWithOffset(),
    );
  }

  static Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version.isEmpty ? 'unknown' : info.version;
    } catch (_) {
      return 'unknown';
    }
  }

  /// `Chrome 128 / Windows 10/11`, degrading to whatever half could be read.
  ///
  /// The user agent is read through `device_info_plus` rather than
  /// `dart:html`, which is deprecated and slated for removal. The package is
  /// already a dependency here, so this costs nothing and the parsing below is
  /// unchanged. Async because the plugin's lookup is.
  static Future<String> _browser() async {
    try {
      final ua = (await DeviceInfoPlugin().webBrowserInfo).userAgent ?? '';
      final name = _browserName(ua);
      final os = _osName(ua);
      if (name.isEmpty && os.isEmpty) return 'unknown';
      if (os.isEmpty) return name;
      if (name.isEmpty) return os;
      return '$name / $os';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Order matters. Edge and Opera both carry `Chrome` in their user-agent, and
  /// Chrome carries `Safari` — testing for the more specific brand first is the
  /// only thing keeping every ticket from saying "Chrome".
  static String _browserName(String ua) {
    for (final probe in const [
      ['Edg/', 'Edge'],
      ['OPR/', 'Opera'],
      ['Chrome/', 'Chrome'],
      ['Firefox/', 'Firefox'],
      ['Safari/', 'Safari'],
    ]) {
      final token = probe[0];
      final index = ua.indexOf(token);
      if (index == -1) continue;
      final version = _majorVersion(ua.substring(index + token.length));
      return version.isEmpty ? probe[1] : '${probe[1]} $version';
    }
    return '';
  }

  /// Leading digits of `128.0.6613.120` — the major is all an agent needs.
  static String _majorVersion(String rest) {
    final digits = StringBuffer();
    for (final unit in rest.codeUnits) {
      if (unit < 0x30 || unit > 0x39) break;
      digits.writeCharCode(unit);
    }
    return digits.toString();
  }

  /// `Windows NT 10.0` covers both Windows 10 and 11 — the user-agent cannot
  /// tell them apart, so it is reported as the pair rather than guessed wrong.
  static String _osName(String ua) {
    if (ua.contains('Windows NT 10.0')) return 'Windows 10/11';
    if (ua.contains('Windows')) return 'Windows';
    if (ua.contains('Android')) return 'Android';
    if (ua.contains('iPhone') || ua.contains('iPad')) return 'iOS';
    if (ua.contains('Mac OS X')) return 'macOS';
    if (ua.contains('Linux')) return 'Linux';
    return '';
  }

  /// ISO 8601 in local time *with* the offset.
  ///
  /// `DateTime.toIso8601String()` on a local value emits no offset at all, so a
  /// ticket raised at 15:04 IST would read as 15:04 UTC on the desk — a five
  /// and a half hour error on exactly the timestamp an agent uses to find the
  /// event in a log.
  static String nowWithOffset([DateTime? at]) {
    final now = at ?? DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    final hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final mm = (minutes % 60).toString().padLeft(2, '0');
    // Trim the milliseconds Dart appends; the desk has no use for them.
    final stamp = now.toIso8601String().split('.').first;
    return '$stamp$sign$hh:$mm';
  }

  /// The block appended to the ticket body.
  ///
  /// Plain text, not HTML: the create route stores the body as given and an
  /// agent reads it in the console. A markup attempt here would either be shown
  /// as literal tags or stripped, depending on the topic's settings.
  String asMessageFooter() => [
        '---',
        'Screen: $screen',
        'Version: $appVersion ($platform)',
        'Browser: $browser',
        'Occurred: $occurredAt',
      ].join('\n');

  Map<String, dynamic> toJson() => {
        'screen': screen,
        'app_version': appVersion,
        'platform': platform,
        'browser': browser,
        'occurred_at': occurredAt,
      };
}
