import 'package:flutter/material.dart';

/// 36a — solid color fill, single initial, no outline. Used next to each
/// message in the ticket chat sidepanel (33a) and reply footer context.
/// "You" gets navy (matches the sent-bubble color); other senders get a
/// neutral slate so the two are never confused at a glance.
class ProfileCircle extends StatelessWidget {
  const ProfileCircle({
    super.key,
    required this.initial,
    this.isSelf = false,
    this.size = 28,
  });

  /// Convenience constructor: takes a full name, derives the single initial.
  factory ProfileCircle.fromName(String name,
          {bool isSelf = false, double size = 28}) =>
      ProfileCircle(
        initial: name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
        isSelf: isSelf,
        size: size,
      );

  final String initial;
  final bool isSelf;
  final double size;

  static const navy = Color(0xFF12379B);
  static const slate = Color(0xFF5A6473);

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelf ? navy : slate,
          shape: BoxShape.circle,
        ),
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.39,
            height: 1,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
}
