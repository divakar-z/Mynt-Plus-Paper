/// An open-interest "wall" — a strike carrying heavy OI. The peak PUT-OI walls
/// act as **support**; the peak CALL-OI walls act as **resistance**.
class OiWall {
  final double strike;
  final int oi;

  const OiWall({required this.strike, required this.oi});

  factory OiWall.fromJson(Map<String, dynamic> json) => OiWall(
        strike: (json['strike'] as num?)?.toDouble() ?? 0,
        oi: (json['oi'] as num?)?.toInt() ?? 0,
      );
}
