import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Modal strike picker used by the Trending OI screen (README §10.5 +
/// §9.5). Lets the user pick up to [maxStrikes] strikes from the chain.
class StrikeMultiPicker {
  StrikeMultiPicker._();

  static const int maxStrikes = 7;

  /// Shows the picker centred over [context] and returns the new selection,
  /// or `null` if the user cancelled.
  static Future<List<double>?> show({
    required BuildContext context,
    required List<double> allStrikes,
    required List<double> initial,
    double? atmStrike,
  }) {
    return showDialog<List<double>>(
      context: context,
      builder: (_) => _PickerDialog(
        allStrikes: allStrikes,
        initial: initial,
        atmStrike: atmStrike,
      ),
    );
  }
}

class _PickerDialog extends StatefulWidget {
  final List<double> allStrikes;
  final List<double> initial;
  final double? atmStrike;

  const _PickerDialog({
    required this.allStrikes,
    required this.initial,
    required this.atmStrike,
  });

  @override
  State<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends State<_PickerDialog> {
  late Set<double> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initial};
  }

  void _toggle(double strike) {
    setState(() {
      if (_selected.contains(strike)) {
        _selected.remove(strike);
      } else {
        if (_selected.length >= StrikeMultiPicker.maxStrikes) return;
        _selected.add(strike);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final atm = widget.atmStrike;
    int? atmIdx;
    if (atm != null) {
      for (var i = 0; i < widget.allStrikes.length; i++) {
        if (widget.allStrikes[i] == atm) {
          atmIdx = i;
          break;
        }
      }
    }
    return Dialog(
      backgroundColor: tokens.bgSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Pick strikes',
                    style: MyntWebTextStyles.head(
                      context,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_selected.length}/${StrikeMultiPicker.maxStrikes}',
                    style: MyntWebTextStyles.caption(
                      context,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Choose up to ${StrikeMultiPicker.maxStrikes} strikes. ATM tagged below.',
                style: MyntWebTextStyles.caption(
                  context,
                  color: tokens.textSecondary,
                ),
              ),
            ),
            Container(height: 1, color: tokens.border),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.allStrikes.length,
                itemBuilder: (context, i) {
                  final s = widget.allStrikes[i];
                  final selected = _selected.contains(s);
                  final isAtm = atmIdx == i;
                  return InkWell(
                    onTap: () => _toggle(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      color: selected
                          ? tokens.bgTertiary
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 18,
                            color: selected
                                ? tokens.accent
                                : tokens.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            s.toStringAsFixed(0),
                            style: MyntWebTextStyles.body(
                              context,
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isAtm) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ATM',
                                style: MyntWebTextStyles.caption(
                                  context,
                                  color: tokens.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(height: 1, color: tokens.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context)
                            .pop(_selected.toList()..sort()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
