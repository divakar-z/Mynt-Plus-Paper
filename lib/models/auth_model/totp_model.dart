class TotpKey {
  final String uid;
  final String pwd;

  TotpKey({required this.uid, required this.pwd});

  factory TotpKey.fromJson(Map<String, dynamic> json) {
    return TotpKey(
      uid: json['uid'] as String? ?? '',
      pwd: json['pwd'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'pwd': pwd,
    };
  }
}
