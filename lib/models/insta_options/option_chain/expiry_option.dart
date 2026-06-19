/// One expiry from `GET /option-chain/expiries` and the chain's
/// `available_expiries`. The `is_near` one is the default selection.
class ExpiryOption {
  final String expiry;
  final bool isNear;

  const ExpiryOption({required this.expiry, required this.isNear});

  factory ExpiryOption.fromJson(Map<String, dynamic> json) => ExpiryOption(
        expiry: (json['expiry'] ?? '').toString(),
        isNear: json['is_near'] as bool? ?? false,
      );
}
