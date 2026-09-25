import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Time bucket selector (`1 / 3 / 5 / 15 min`) used by the PCR Ratio and
/// Per-Strike Options Chart screens (README §10.6 + §10.7).
///
/// Wired to the backend `bucket_minutes` query param on
/// `GET /oi/pcr/timeseries` and `GET /oi/timeseries` (Ticket 2).
class BucketMinutesSelector extends StatelessWidget {
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;
  final InstaOptionsTokens tokens;

  const BucketMinutesSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Time bucket',
          style: MyntWebTextStyles.caption(
            context,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: tokens.bgTertiary,
            border: Border.all(color: tokens.border, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isDense: true,
              value: value,
              dropdownColor: tokens.bgSecondary,
              icon: Icon(
                Icons.expand_more,
                color: tokens.textSecondary,
                size: 16,
              ),
              items: options
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          '$m min',
                          style: MyntWebTextStyles.body(
                            context,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ))
                  .toList(growable: false),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
