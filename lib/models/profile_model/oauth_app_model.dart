class OAuthApp {
  OAuthApp({
    required this.appKey,
    required this.displayName,
    required this.redirectUrl,
    required this.ipAddresses,
    required this.secretCode,
    this.emsg,
  });

  final String appKey;
  final String displayName;
  final String redirectUrl;
  final List<String> ipAddresses;
  final String secretCode;
  final String? emsg;

  String get primaryIp => ipAddresses.isNotEmpty ? ipAddresses[0] : '';
  String get backupIp => ipAddresses.length > 1 ? ipAddresses[1] : '';

  factory OAuthApp.fromJson(Map<String, dynamic> json) {
    return OAuthApp(
      appKey: json['app_key'] as String? ?? '',
      displayName: json['dname'] as String? ?? '',
      redirectUrl: json['red_url'] as String? ?? '',
      ipAddresses: (json['ipaddr'] as List<dynamic>? ?? [])
          .map((e) => (e as Map<String, dynamic>)['ipaddr'] as String? ?? '')
          .toList(),
      secretCode: json['sec_code'] as String? ?? '',
      emsg: json['emsg'] as String?,
    );
  }
}
