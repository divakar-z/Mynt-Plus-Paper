import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/provider/profile_all_details_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:url_launcher/url_launcher.dart';

class FormDownloadScreenWeb extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const FormDownloadScreenWeb({super.key, this.onBack});

  @override
  ConsumerState<FormDownloadScreenWeb> createState() =>
      _FormDownloadScreenWebState();
}

class _FormDownloadScreenWebState extends ConsumerState<FormDownloadScreenWeb> {
  bool _loading = true;
  bool _cmrLoading = false;
  String? _ekycDownloadPath;
  List<Map<String, String>> _modificationForms = [];
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);

  final _api = locator<ApiExporter>();

  @override
  void dispose() {
    _hoveredRowIndex.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    await Future.wait([_fetchModificationForms(), _fetchEkycForm()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchModificationForms() async {
    try {
      final uri = Uri.parse('https://rekycbe.mynt.in/pdfdownload');
      final res = await _api.apiClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'client_id': _api.prefs.clientId}),
      );
      final json = jsonDecode(res.body);
      if (json['stat'] == 'ok' && json['values'] != null) {
        final List values = json['values'];
        final List<Map<String, String>> forms = [];
        for (final item in values) {
          if (item is Map) {
            for (final entry in item.entries) {
              if (entry.value != null && entry.value.toString().isNotEmpty) {
                forms.add({
                  'name': entry.key.toString(),
                  'path': entry.value.toString(),
                });
              }
            }
          }
        }
        if (mounted) setState(() => _modificationForms = forms);
      }
    } catch (e) {
    }
  }

  Future<void> _fetchEkycForm() async {
    try {
      final provider = ref.read(profileAllDetailsProvider);
      final mobileNo =
          provider.clientAllDetailsSafe?.clientData?.mOBILENO ?? '';
      if (mobileNo.isEmpty) return;

      final uri = Uri.parse('https://ekycbe.mynt.in/dashboard/ekyc_form_download');
      final res = await _api.apiClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mobile_number': mobileNo}),
      );
      final json = jsonDecode(res.body);
      if (json['stat'] == 'ok' && json['values'] != null) {
        if (mounted) {
          setState(() => _ekycDownloadPath = json['values'].toString());
        }
      }
    } catch (e) {
    }
  }

  Future<void> _downloadCmr() async {
    setState(() => _cmrLoading = true);
    try {
      final uri = Uri.parse('https://rekycbe.mynt.in/report/cmr');
      final res = await _api.apiClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'client_id': _api.prefs.clientId}),
      );
      final json = jsonDecode(res.body);
      if (json['path'] != null) {
        _openLink('https://rekycbe.mynt.in${json['path']}');
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _cmrLoading = false);
    }
  }

  void _openLink(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final bgColor = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 28, 20),
            child: Row(
              children: [
                if (widget.onBack != null) ...[
                  CustomBackBtn(onBack: widget.onBack),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Form Download',
                        style: MyntWebTextStyles.title(context,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                          fontWeight: MyntFonts.semiBold,
                        ).copyWith(decoration: TextDecoration.none),
                      ),
                      // const SizedBox(height: 4),
                      // Text(
                      //   'Download all forms related to your trading account',
                      //   style: MyntWebTextStyles.para(context,
                      //     darkColor: MyntColors.textSecondaryDark,
                      //     lightColor: MyntColors.textSecondary,
                      //     fontWeight: MyntFonts.regular,
                      //   ).copyWith(decoration: TextDecoration.none),
                      // ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _cmrLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: primaryColor))
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _downloadCmr,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: resolveThemeColor(context,
                                  dark: MyntColors.secondary,
                                  light: MyntColors.primary),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CMR Download',
                              style: MyntWebTextStyles.bodySmall(context,
                                color: Colors.white,
                                fontWeight: MyntFonts.semiBold,
                              ).copyWith(decoration: TextDecoration.none),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: primaryColor))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── All forms in a single table ──
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final totalWidth = constraints.maxWidth;
                            final col0 = totalWidth * 0.40;
                            final col1 = totalWidth * 0.35;
                            final col2 = totalWidth * 0.25;

                            final columnWidths = {
                              0: shadcn.FixedTableSize(col0),
                              1: shadcn.FixedTableSize(col1),
                              2: shadcn.FixedTableSize(col2),
                            };

                            return shadcn.OutlinedContainer(
                              child: Column(
                                children: [
                                  // Fixed Header
                                  shadcn.Table(
                                    defaultRowHeight:
                                        const shadcn.FixedTableSize(50),
                                    columnWidths: columnWidths,
                                    rows: [
                                      shadcn.TableHeader(
                                        cells: [
                                          _buildHeaderCell('FORM NAME', 0),
                                          _buildHeaderCell('TYPE', 1),
                                          _buildHeaderCell('', 2),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // Data Rows
                                  if (_modificationForms.isEmpty &&
                                      (_ekycDownloadPath == null ||
                                          _ekycDownloadPath!.isEmpty))
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 24),
                                      child: Text(
                                        'No forms available',
                                        style: MyntWebTextStyles.body(context,
                                          darkColor: MyntColors.textSecondaryDark,
                                          lightColor: MyntColors.textSecondary,
                                        ).copyWith(decoration: TextDecoration.none),
                                      ),
                                    )
                                  else
                                    shadcn.Table(
                                      defaultRowHeight:
                                          const shadcn.FixedTableSize(50),
                                      columnWidths: columnWidths,
                                      rows: _buildTableRows(primaryColor),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── No-border theme for table cells ──
  static const _noBorder = shadcn.TableCellTheme(
    border: shadcn.WidgetStatePropertyAll(
      shadcn.Border(
        top: shadcn.BorderSide.none,
        bottom: shadcn.BorderSide.none,
        left: shadcn.BorderSide.none,
        right: shadcn.BorderSide.none,
      ),
    ),
  );

  shadcn.TableCell _buildHeaderCell(String label, int columnIndex) {
    return shadcn.TableCell(
      theme: _noBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment:
              columnIndex == 2 ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            label,
            style: MyntWebTextStyles.tableHeader(context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
              fontWeight: MyntFonts.semiBold,
            ).copyWith(decoration: TextDecoration.none),
          ),
        ),
      ),
    );
  }

  shadcn.TableCell _buildDataCell({
    required int rowIndex,
    required int columnIndex,
    required Widget child,
  }) {
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);

    return shadcn.TableCell(
      theme: _noBorder,
      child: MouseRegion(
        onEnter: (_) => _hoveredRowIndex.value = rowIndex,
        onExit: (_) => _hoveredRowIndex.value = null,
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredRowIndex,
          builder: (context, hoveredIndex, _) {
            return Container(
              color: hoveredIndex == rowIndex ? hoverBg : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: columnIndex == 2
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: child,
            );
          },
        ),
      ),
    );
  }

  List<shadcn.TableRow> _buildTableRows(Color primaryColor) {
    final List<shadcn.TableRow> rows = [];
    int rowIndex = 0;

    // ── eKYC Form ──
    if (_ekycDownloadPath != null && _ekycDownloadPath!.isNotEmpty) {
      final idx = rowIndex;
      rows.add(
        shadcn.TableRow(
          cells: [
            _buildDataCell(
              rowIndex: idx,
              columnIndex: 0,
              child: Text(
                'eKYC Form',
                style: MyntWebTextStyles.tableCell(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium,
                ).copyWith(decoration: TextDecoration.none),
              ),
            ),
            _buildDataCell(
              rowIndex: idx,
              columnIndex: 1,
              child: Text(
                'Account Opening',
                style: MyntWebTextStyles.tableCell(context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                  fontWeight: MyntFonts.regular,
                ).copyWith(decoration: TextDecoration.none),
              ),
            ),
            _buildDataCell(
              rowIndex: idx,
              columnIndex: 2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openLink(
                      'https://ekycbe.mynt.in/file?path=$_ekycDownloadPath'),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_outlined,
                            size: 16, color: primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          'Download',
                          style: MyntWebTextStyles.bodySmall(context,
                            color: primaryColor,
                            fontWeight: MyntFonts.semiBold,
                          ).copyWith(decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      rowIndex++;
    }

    // ── Modification Forms ──
    for (final form in _modificationForms) {
      final idx = rowIndex;
      rows.add(
        shadcn.TableRow(
          cells: [
            _buildDataCell(
              rowIndex: idx,
              columnIndex: 0,
              child: Text(
                form['name'] ?? '',
                style: MyntWebTextStyles.tableCell(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium,
                ).copyWith(decoration: TextDecoration.none),
              ),
            ),
            _buildDataCell(
              rowIndex: idx,
              columnIndex: 1,
              child: Text(
                'Modification',
                style: MyntWebTextStyles.tableCell(context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                  fontWeight: MyntFonts.regular,
                ).copyWith(decoration: TextDecoration.none),
              ),
            ),
            _buildDataCell(
              rowIndex: idx,
              columnIndex: 2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openLink(
                      'https://rekycbe.mynt.in${form['path']}'),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_outlined,
                            size: 16, color: primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          'Download',
                          style: MyntWebTextStyles.bodySmall(context,
                            color: primaryColor,
                            fontWeight: MyntFonts.semiBold,
                          ).copyWith(decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      rowIndex++;
    }

    return rows;
  }
}
