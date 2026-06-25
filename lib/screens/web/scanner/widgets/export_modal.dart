import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';

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
  const _ExportDialog(
      {required this.allowCustom, required this.availableCustomKeys});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  ExportColumnsMode _mode = ExportColumnsMode.visible;
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    // App-standard dialog shell (matches the Watchlist delete dialog):
    // shadcn.Card → bordered header (title + close) → padded content → actions.
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: shadcn.Card(
        borderRadius: BorderRadius.circular(8),
        padding: EdgeInsets.zero,
        child: Container(
          width: 400,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.dialogDark, light: MyntColors.dialog),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: shadcn.Theme.of(context).colorScheme.border),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Export to Excel',
                        style:
                            MyntWebTextStyles.title(context, color: textPrimary)),
                    MyntCloseButton(
                        onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              // Content (scrolls if it grows tall)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _radio(ExportColumnsMode.visible, 'Visible columns only'),
                      _radio(ExportColumnsMode.all, 'All columns'),
                      if (widget.allowCustom) ...[
                        _radio(ExportColumnsMode.custom, 'Custom columns'),
                        if (_mode == ExportColumnsMode.custom)
                          SizedBox(
                            height: 200,
                            child: ListView(
                              children: [
                                for (final k in widget.availableCustomKeys)
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
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
              ),
              // Action — full-width Download (dismiss via the × in the header).
              Padding(
                padding: const EdgeInsets.all(16),
                child: MyntButton(
                  type: MyntButtonType.primary,
                  label: 'Download',
                  isFullWidth: true,
                  onPressed: () => Navigator.of(context).pop(
                    ExportModalResult(
                        mode: _mode, customColumns: _selected.toList()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radio(ExportColumnsMode value, String label) {
    return RadioListTile<ExportColumnsMode>(
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeColor: MyntColors.primary,
      value: value,
      groupValue: _mode,
      title: Text(label, style: MyntWebTextStyles.body(context)),
      onChanged: (v) => setState(() => _mode = v!),
    );
  }
}
