import 'package:flutter/material.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

enum ExportColumnsMode { visible, all, custom }

class ExportModalResult {
  final ExportColumnsMode mode;
  final List<String> customColumns;
  const ExportModalResult({required this.mode, this.customColumns = const []});
}

Future<ExportModalResult?> showExportModal(
  BuildContext context, {
  bool allowCustom = false,
  List<String> availableCustomKeys = const [],
}) {
  return showDialog<ExportModalResult>(
    context: context,
    builder: (_) => _ExportDialog(
      allowCustom: allowCustom,
      availableCustomKeys: availableCustomKeys,
    ),
  );
}

class _ExportDialog extends StatefulWidget {
  final bool allowCustom;
  final List<String> availableCustomKeys;
  const _ExportDialog({required this.allowCustom, required this.availableCustomKeys});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  ExportColumnsMode _mode = ExportColumnsMode.visible;
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Export to Excel',
          style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioListTile<ExportColumnsMode>(
              value: ExportColumnsMode.visible,
              groupValue: _mode,
              title: Text('Visible columns only',
                  style: MyntWebTextStyles.body(context)),
              onChanged: (v) => setState(() => _mode = v!),
            ),
            RadioListTile<ExportColumnsMode>(
              value: ExportColumnsMode.all,
              groupValue: _mode,
              title: Text('All columns',
                  style: MyntWebTextStyles.body(context)),
              onChanged: (v) => setState(() => _mode = v!),
            ),
            if (widget.allowCustom) ...[
              RadioListTile<ExportColumnsMode>(
                value: ExportColumnsMode.custom,
                groupValue: _mode,
                title: Text('Custom columns',
                    style: MyntWebTextStyles.body(context)),
                onChanged: (v) => setState(() => _mode = v!),
              ),
              if (_mode == ExportColumnsMode.custom)
                SizedBox(
                  width: 320,
                  height: 200,
                  child: ListView(
                    children: [
                      for (final k in widget.availableCustomKeys)
                        CheckboxListTile(
                          value: _selected.contains(k),
                          title: Text(k,
                              style: MyntWebTextStyles.body(context)),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(k);
                            } else {
                              _selected.remove(k);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: MyntWebTextStyles.body(context)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ExportModalResult(mode: _mode, customColumns: _selected.toList()),
          ),
          child: Text('Download',
              style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium)),
        ),
      ],
    );
  }
}
