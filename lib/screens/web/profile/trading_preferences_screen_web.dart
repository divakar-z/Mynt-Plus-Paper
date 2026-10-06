import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/client_profile_all_details/profile_all_details_model.dart';
import 'package:mynt_plus/provider/profile_all_details_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import 'package:mynt_plus/utils/digio_esign.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class TradingPreferencesScreenWeb extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const TradingPreferencesScreenWeb({super.key, this.onBack});

  @override
  ConsumerState<TradingPreferencesScreenWeb> createState() =>
      _TradingPreferencesScreenWebState();
}

class _TradingPreferencesScreenWebState
    extends ConsumerState<TradingPreferencesScreenWeb> {
  bool _segmentEsignLoading = false;
  bool _segmentCancelLoading = false;
  bool _initialLoadDone = false;
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _hoveredRowIndex.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = ref.read(profileAllDetailsProvider);
      await Future.wait([
        provider.fetchClientProfileAllDetails(),
        provider.fetchMobEmailStatus(),
      ]);
      if (!mounted) return;
      setState(() => _initialLoadDone = true);
    });
  }

  // Friendly display names for segment codes
  static const _segmentDisplayNames = {
    'BSE_CASH': 'BSE Cash',
    'NSE_CASH': 'NSE Cash',
    'BSE_FNO': 'BSE F&O',
    'NSE_FNO': 'NSE F&O',
    'CD_BSE': 'BSE Currency',
    'CD_NSE': 'NSE Currency',
    'MCX': 'MCX',
    'BSE_COM': 'BSE Commodity',
    'NSE_COM': 'NSE Commodity',
  };

  // Category grouping
  static const _categories = {
    'Equities': ['BSE_CASH', 'NSE_CASH'],
    'Futures & Options': ['BSE_FNO', 'NSE_FNO'],
    'Currency': ['CD_BSE', 'CD_NSE'],
    'Commodities': ['MCX', 'BSE_COM', 'NSE_COM'],
  };

  bool _allSegmentsActive(List<SegmentsData>? segmentsData) {
    if (segmentsData == null || segmentsData.isEmpty) return true;
    for (final cat in _categories.values) {
      final catSegments =
          segmentsData.where((s) => cat.contains(s.cOMPANYCODE)).toList();
      for (final s in catSegments) {
        if (s.exchangeACTIVEINACTIVE != 'A') return false;
      }
    }
    return true;
  }

  bool _hasNoActiveSegments(List<SegmentsData>? segmentsData) {
    if (segmentsData == null || segmentsData.isEmpty) return false;
    return !segmentsData.any((s) => s.exchangeACTIVEINACTIVE == 'A');
  }

  void _redirectToRekyc({required String panNo, required String clientId}) {
    final encoded = base64.encode(utf8.encode('$panNo||$clientId'));
    html.window.open('https://oa.mynt.in?rekyc=$encoded', '_blank');
  }

  void _showNoActiveSegmentsDialog({
    required String panNo,
    required String clientId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.dialogDark, light: MyntColors.dialog),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.dividerDark,
                        light: MyntColors.divider,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'No active segments found?',
                      style: MyntWebTextStyles.title(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: MyntWebTextStyles.body(
                          context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary),
                        ),
                        children: [
                          const TextSpan(
                              text:
                                  'You have in-active segments in your account '),
                          TextSpan(
                            text: '"$clientId"',
                            style: MyntWebTextStyles.body(
                              context,
                              fontWeight: MyntFonts.semiBold,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _redirectToRekyc(panNo: panNo, clientId: clientId);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: resolveThemeColor(context,
                              dark: MyntColors.secondary,
                              light: MyntColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Re-KYC',
                          style: MyntWebTextStyles.buttonMd(
                            context,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final profileDetails = ref.watch(profileAllDetailsProvider);
    final clientAllDetails = profileDetails.clientAllDetailsSafe;
    final segmentsData = clientAllDetails?.clientData?.segmentsData;
    final isLoading = profileDetails.isLoading;
    final mobStatus = profileDetails.mobEmailStatus;

    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final bgColor = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor);
    final successColor = resolveThemeColor(context,
        dark: MyntColors.successDark, light: MyntColors.success);
    final warningColor = resolveThemeColor(context,
        dark: MyntColors.warningDark, light: MyntColors.warning);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final errorColor = resolveThemeColor(context,
        dark: MyntColors.errorDark, light: MyntColors.error);

    final segmentStatus = mobStatus?.segmentStatus ?? '';
    final showActivateBtn = !_allSegmentsActive(segmentsData) &&
        segmentStatus != 'e-signed pending' &&
        segmentStatus != 'e-signed completed';

    // ─── Segment edit-gate reasons (for tooltip + button disable) ───
    // Only client-closed and non-individual block this button on web; the
    // atve_sts / 7-day / Re-KYC checks gate other screens, not this one.
    final clientData = clientAllDetails?.clientData;
    String? segmentEditBlockReason;
    if (clientData != null) {
      if (clientData.isClientClosed) {
        segmentEditBlockReason = 'Your trading account is closed.';
      } else if (!clientData.isIndividual) {
        segmentEditBlockReason =
            "Non-individual accounts can't modify data here. "
            "Please contact support at (+91) 93 8010 8010 for help.";
      }
    }
    final bool segmentEditDisabled = segmentEditBlockReason != null;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                if (widget.onBack != null)
                  InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_back_ios_outlined,
                        size: 18,
                        color: textColor,
                      ),
                    ),
                  ),
                if (widget.onBack != null) const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trading Preferences',
                        style: MyntWebTextStyles.title(context,
                            fontWeight: MyntFonts.semiBold, color: textColor)),
                    // const SizedBox(height: 2),
                    // Text(
                    //     'Your account has access to only these currently active segments.',
                    //     style: MyntWebTextStyles.caption(context,
                    //         color: subtitleColor)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!_initialLoadDone || isLoading)
            Expanded(child: Center(child: MyntLoader.simple()))
          else if (segmentsData == null || segmentsData.isEmpty)
            Expanded(
              child: Center(
                child: Text('No segment data available',
                    style: MyntWebTextStyles.body(context,
                        color: subtitleColor)),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Segments table
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final totalWidth = constraints.maxWidth;
                        final col0 = totalWidth * 0.40; // Segment
                        final col1 = totalWidth * 0.40; // Exchange
                        final col2 = totalWidth * 0.20; // Status

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
                                      _buildHeaderCell('Segment', 0),
                                      _buildHeaderCell('Exchange', 1),
                                      _buildHeaderCell('Status', 2),
                                    ],
                                  ),
                                ],
                              ),
                              // Data Rows
                              shadcn.Table(
                                defaultRowHeight:
                                    const shadcn.FixedTableSize(50),
                                columnWidths: columnWidths,
                                rows: _buildTableRows(
                                  segmentsData,
                                  textColor: textColor,
                                  successColor: successColor,
                                  errorColor: errorColor,
                                  warningColor: warningColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Segment status banners
                    if (segmentStatus == 'e-signed pending') ...[
                      const SizedBox(height: 16),
                      Builder(builder: (context) {
                        final warningBg = resolveThemeColor(context,
                            dark: const Color(0xFF3D2E00), light: const Color(0xFFFCEFD4));
                        final warningText = resolveThemeColor(context,
                            dark: const Color(0xFFFFD780), light: Colors.brown[800]!);
                        final warningIcon = resolveThemeColor(context,
                            dark: MyntColors.warningDark, light: MyntColors.warning);
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: warningBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                  Icon(Icons.info_outline, color: warningIcon, size: 20),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      'Esign Pending - Click here to complete',
                                      style: MyntWebTextStyles.bodySmall(context,
                                          color: warningText, fontWeight: MyntFonts.medium)
                                          .copyWith(decoration: TextDecoration.none),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  _segmentEsignLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: primaryColor))
                                      : Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _openEsignWebView(
                                              fileId: mobStatus?.segmentFileId ?? '',
                                              email: (mobStatus?.segmentClientEmail ?? '').toLowerCase(),
                                              session: mobStatus?.segmentSession ?? '',
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              child: Text('Click here E-sign',
                                                  style: MyntWebTextStyles.bodySmall(context,
                                                      color: primaryColor,
                                                      fontWeight: MyntFonts.semiBold)
                                                      .copyWith(decoration: TextDecoration.none)),
                                            ),
                                          ),
                                        ),
                                  const SizedBox(width: 4),
                                  _segmentCancelLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: errorColor))
                                      : Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _cancelSegmentRequest(),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              child: Text('Cancel request',
                                                  style: MyntWebTextStyles.bodySmall(context,
                                                      color: errorColor,
                                                      fontWeight: MyntFonts.semiBold)
                                                      .copyWith(decoration: TextDecoration.none)),
                                            ),
                                          ),
                                        ),
                            ],
                          ),
                        );
                      }),
                    ],
                    if (segmentStatus == 'e-signed completed') ...[
                      const SizedBox(height: 16),
                      Builder(builder: (context) {
                        final successBg = resolveThemeColor(context,
                            dark: const Color(0xFF0A3D1E), light: const Color(0xFFE6F9ED));
                        final successText = resolveThemeColor(context,
                            dark: MyntColors.successDark, light: MyntColors.success);
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: successBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_top_rounded, size: 20, color: successText),
                              const SizedBox(width: 12),
                              Text(
                                'Your Segment Change request is in process',
                                style: MyntWebTextStyles.bodySmall(context,
                                    color: successText,
                                    fontWeight: MyntFonts.medium)
                                    .copyWith(decoration: TextDecoration.none),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    // Activate Segments button
                    if (showActivateBtn) ...[
                      const SizedBox(height: 24),
                      Tooltip(
                        message: segmentEditBlockReason ?? '',
                        child: Opacity(
                          opacity: segmentEditDisabled ? 0.5 : 1.0,
                          child: InkWell(
                            onTap: segmentEditDisabled
                                ? () => warningMessage(
                                    context, segmentEditBlockReason!)
                                : () {
                                    if (_hasNoActiveSegments(segmentsData)) {
                                      _showNoActiveSegmentsDialog(
                                        panNo: clientAllDetails
                                                ?.clientData?.pANNO ??
                                            '',
                                        clientId: clientAllDetails
                                                ?.clientData?.cLIENTID ??
                                            '',
                                      );
                                    } else {
                                      _showSegmentChangeDialog(
                                          context, segmentsData);
                                    }
                                  },
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add,
                                      size: 18, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text('Activate Segments',
                                      style: MyntWebTextStyles.bodySmall(
                                          context,
                                          color: Colors.white,
                                          fontWeight: MyntFonts.semiBold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Shadcn Table Helpers ───────────────────────────────────────────

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
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 2;

    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding = const EdgeInsets.fromLTRB(16, 0, 8, 0);
    } else if (isLastColumn) {
      headerPadding = const EdgeInsets.fromLTRB(8, 0, 16, 0);
    } else {
      headerPadding = const EdgeInsets.symmetric(horizontal: 8);
    }

    return shadcn.TableCell(
      theme: _noBorder,
      child: Container(
        padding: headerPadding,
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: MyntWebTextStyles.tableHeader(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
          ),
        ),
      ),
    );
  }

  shadcn.TableCell _buildDataCell({
    required int rowIndex,
    required int columnIndex,
    required Widget child,
    bool isLastInCategory = false,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 2;

    EdgeInsets cellPadding;
    if (isFirstColumn) {
      cellPadding = const EdgeInsets.fromLTRB(16, 8, 8, 8);
    } else if (isLastColumn) {
      cellPadding = const EdgeInsets.fromLTRB(8, 8, 16, 8);
    } else {
      cellPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    }

    return shadcn.TableCell(
      theme: _noBorder,
      child: MouseRegion(
        onEnter: (_) => _hoveredRowIndex.value = rowIndex,
        onExit: (_) => _hoveredRowIndex.value = null,
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredRowIndex,
          builder: (context, hoveredIndex, _) {
            final isRowHovered = hoveredIndex == rowIndex;
            final dividerColor = resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider);
            return Container(
              padding: cellPadding,
              decoration: BoxDecoration(
                color: isRowHovered
                    ? resolveThemeColor(context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary)
                        .withValues(alpha: 0.08)
                    : null,
                border: isLastInCategory
                    ? Border(
                        bottom: BorderSide(color: dividerColor, width: 1))
                    : null,
              ),
              alignment: Alignment.centerLeft,
              child: child,
            );
          },
        ),
      ),
    );
  }

  List<shadcn.TableRow> _buildTableRows(
    List<SegmentsData> segmentsData, {
    required Color textColor,
    required Color successColor,
    required Color errorColor,
    required Color warningColor,
  }) {
    final rows = <shadcn.TableRow>[];
    int globalRowIndex = 0;

    for (final entry in _categories.entries) {
      final categoryName = entry.key;
      final codes = entry.value;
      final categorySegments = segmentsData
          .where((s) => codes.contains(s.cOMPANYCODE))
          .toList();

      if (categorySegments.isEmpty) continue;

      for (int i = 0; i < categorySegments.length; i++) {
        final segment = categorySegments[i];
        final exchStatus = segment.exchangeACTIVEINACTIVE ?? '';
        final isActive = exchStatus == 'A';
        final isInactive = exchStatus == 'I';
        final code = segment.cOMPANYCODE ?? '';
        final displayName = _segmentDisplayNames[code] ?? code;
        final isLast = i == categorySegments.length - 1;

        Color statusColor;
        String statusLabel;
        if (isActive) {
          statusColor = successColor;
          statusLabel = 'Active';
        } else if (isInactive) {
          statusColor = errorColor;
          statusLabel = 'Inactive';
        } else {
          statusColor = warningColor;
          statusLabel = 'Not open';
        }

        final rowIdx = globalRowIndex;
        rows.add(shadcn.TableRow(
          cells: [
            _buildDataCell(
              rowIndex: rowIdx,
              columnIndex: 0,
              isLastInCategory: isLast,
              child: Text(
                i == 0 ? categoryName : '',
                style: MyntWebTextStyles.tableCell(context,
                    color: textColor, fontWeight: MyntFonts.medium),
              ),
            ),
            _buildDataCell(
              rowIndex: rowIdx,
              columnIndex: 1,
              isLastInCategory: isLast,
              child: Text(
                displayName,
                style: MyntWebTextStyles.tableCell(context, color: textColor),
              ),
            ),
            _buildDataCell(
              rowIndex: rowIdx,
              columnIndex: 2,
              isLastInCategory: isLast,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: MyntWebTextStyles.caption(context,
                          fontWeight: MyntFonts.semiBold,
                          color: statusColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ));
        globalRowIndex++;
      }
    }
    return rows;
  }

  // ─── Cancel Segment Request (no Navigator.pop, just refresh status) ───
  Future<void> _cancelSegmentRequest() async {
    final provider = ref.read(profileAllDetailsProvider);
    setState(() => _segmentCancelLoading = true);
    try {
      provider.cancelPendingloader(true);
      final fileid = await provider.api.fetctfileidapi('segment_change');
      final response = await provider.api
          .cancelPendingStatusApi('segment_change', fileid ?? '');
      if (response == 'Cancel Success') {
        await provider.fetchMobEmailStatus();
        if (mounted) successMessage(context, 'Esign Cancellation Success');
      } else {
        if (mounted) warningMessage(context, 'Esign Cancellation Failed');
      }
    } catch (e) {
      if (mounted) warningMessage(context, 'Something Went Wrong');
    } finally {
      provider.cancelPendingloader(false);
      if (mounted) setState(() => _segmentCancelLoading = false);
    }
  }

  // ─── E-Sign via Digio JS SDK (inline, no external browser) ───
  Future<void> _openEsignWebView({
    required String fileId,
    required String email,
    required String session,
  }) async {
    final provider = ref.read(profileAllDetailsProvider);

    if (fileId.isEmpty || email.isEmpty) {
      warningMessage(context, 'E-Sign details not available');
      return;
    }

    setState(() => _segmentEsignLoading = true);


    try {
      // Call Digio JS SDK directly (opens inline overlay)
      final result = await startDigioEsign(
        fileId: fileId,
        email: email,
        session: session,
      );

      // Report esign result to backend
      if (fileId.isNotEmpty) {
        provider.reportFiledownload(
          fileId: fileId,
          response: result,
          type: 'segment_change',
        );
      }

      // Refresh data
      provider.fetchClientProfileAllDetails();
      provider.fetchMobEmailStatus();

      if (mounted) {
        if (result == 'success') {
          successMessage(context, 'E-Sign completed successfully');
        } else {
          warningMessage(context, 'E-Sign was cancelled');
        }
      }
    } finally {
      if (mounted) setState(() => _segmentEsignLoading = false);
    }
  }

  // ─── E-Sign Confirmation Dialog (shown after /add_segment success) ───
  void _showEsignConfirmationDialog({
    required String fileId,
    required String email,
    required String session,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.dialogDark, light: MyntColors.dialog),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.dividerDark,
                        light: MyntColors.divider,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'E-Sign Is Pending!',
                      style: MyntWebTextStyles.title(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ref
                              .read(profileAllDetailsProvider)
                              .fetchMobEmailStatus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Your Segment Change request is not yet Completed.',
                      textAlign: TextAlign.center,
                      style: MyntWebTextStyles.body(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _openEsignWebView(
                            fileId: fileId,
                            email: email,
                            session: session,
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: resolveThemeColor(context,
                              dark: MyntColors.secondary,
                              light: MyntColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Click here E-sign',
                          style: MyntWebTextStyles.buttonMd(
                            context,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSegmentChangeDialog(
      BuildContext context, List<SegmentsData>? segmentsData) {
    if (segmentsData == null) return;

    // Determine which chips should be disabled (all active = disabled)
    bool isChipDisabled(List<String> codes) {
      final catSegments =
          segmentsData.where((s) => codes.contains(s.cOMPANYCODE)).toList();
      return catSegments.every((s) => s.exchangeACTIVEINACTIVE == 'A');
    }

    // Determine existing & inactive segments (like Vue's mobileEdit)
    final existingSegments = <String>[];
    final inactiveSegments = <String>[];
    for (final s in segmentsData) {
      if (s.exchangeACTIVEINACTIVE == 'A') {
        existingSegments.add(s.cOMPANYCODE ?? '');
      } else if (s.exchangeACTIVEINACTIVE == 'I') {
        inactiveSegments.add(s.cOMPANYCODE ?? '');
      }
    }

    final equityDisabled = isChipDisabled(['BSE_CASH', 'NSE_CASH']);
    final fnoDisabled = isChipDisabled(['BSE_FNO', 'NSE_FNO']);
    final currencyDisabled = isChipDisabled(['CD_BSE', 'CD_NSE']);
    final commodityDisabled = isChipDisabled(['MCX', 'BSE_COM', 'NSE_COM']);

    // Pre-select chips that are already active
    final equityPreselected = !equityDisabled &&
        segmentsData
            .where((s) => ['BSE_CASH', 'NSE_CASH'].contains(s.cOMPANYCODE))
            .any((s) => s.exchangeACTIVEINACTIVE == 'A');
    final fnoPreselected = !fnoDisabled &&
        segmentsData
            .where((s) => ['BSE_FNO', 'NSE_FNO'].contains(s.cOMPANYCODE))
            .any((s) => s.exchangeACTIVEINACTIVE == 'A');
    final currencyPreselected = !currencyDisabled &&
        segmentsData
            .where((s) => ['CD_BSE', 'CD_NSE'].contains(s.cOMPANYCODE))
            .any((s) => s.exchangeACTIVEINACTIVE == 'A');
    final commodityPreselected = !commodityDisabled &&
        segmentsData
            .where(
                (s) => ['MCX', 'BSE_COM', 'NSE_COM'].contains(s.cOMPANYCODE))
            .any((s) => s.exchangeACTIVEINACTIVE == 'A');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SegmentChangeRequestDialog(
        equityDisabled: equityDisabled,
        fnoDisabled: fnoDisabled,
        currencyDisabled: currencyDisabled,
        commodityDisabled: commodityDisabled,
        equityPreselected: equityPreselected,
        fnoPreselected: fnoPreselected,
        currencyPreselected: currencyPreselected,
        commodityPreselected: commodityPreselected,
        existingSegments: existingSegments,
        inactiveSegments: inactiveSegments,
        onSubmit: (equity, fno, currency, commodity, proofBytes,
            proofFileName) async {
          final provider = ref.read(profileAllDetailsProvider);

          // Build new segments list (like Vue's segmentChange)
          final newSegments = <String>[];
          if (equity) {
            newSegments.addAll(['NSE_CASH', 'BSE_CASH']);
          }
          if (fno) {
            newSegments.addAll(['NSE_FNO', 'BSE_FNO']);
          }
          if (currency) {
            newSegments.addAll(['CD_NSE', 'CD_BSE']);
          }
          if (commodity) {
            newSegments.addAll(['NSE_COM', 'BSE_COM', 'MCX']);
          }

          if (newSegments.isEmpty) {
            warningMessage(ctx, 'Select any segment, please.');
            return;
          }

          // Determine if adding new or re-activating
          String addingNew = 'NO';
          String reActive = 'NO';
          final allCodes = segmentsData.map((s) => s.cOMPANYCODE).toList();
          for (final seg in newSegments) {
            if (inactiveSegments.contains(seg)) reActive = 'YES';
            if (!allCodes.contains(seg) ||
                segmentsData.any((s) =>
                    s.cOMPANYCODE == seg &&
                    s.exchangeACTIVEINACTIVE == 'NOT OPEN')) {
              addingNew = 'YES';
            }
          }

          final result = await provider.submitSegmentChange(
            newSegments: newSegments,
            existingSegments: existingSegments,
            addingSegments: addingNew,
            reActiveSegments: reActive,
            equitySelected: equity,
            fnoSelected: fno,
            currencySelected: currency,
            commoditySelected: commodity,
            proofBytes: proofBytes,
            proofFileName: proofFileName,
            passwordRequired: 'NO',
            password: '',
          );

          if (!ctx.mounted) return;
          Navigator.pop(ctx);

          if (result != null &&
              result['fileid'] != null &&
              result['mailid'] != null) {
            // Show esign confirmation dialog (like Vue's esignconfirmation)
            _showEsignConfirmationDialog(
              fileId: result['fileid']?.toString() ?? '',
              email: (result['mailid']?.toString() ?? '').toLowerCase(),
              session: result['session']?.toString() ?? '',
            );
          } else if (result != null &&
              result['msg'] ==
                  'pan name miss match so redirect to ekyc') {
            warningMessage(
                context, 'PAN name mismatch. Please complete eKYC.');
          } else {
            warningMessage(
                context, 'Error in Server, please try again later');
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  SEGMENT CHANGE REQUEST DIALOG
// ═══════════════════════════════════════════════════════════════════════

class _SegmentChangeRequestDialog extends StatefulWidget {
  final bool equityDisabled;
  final bool fnoDisabled;
  final bool currencyDisabled;
  final bool commodityDisabled;
  final bool equityPreselected;
  final bool fnoPreselected;
  final bool currencyPreselected;
  final bool commodityPreselected;
  final List<String> existingSegments;
  final List<String> inactiveSegments;
  final Future<void> Function(
    bool equity,
    bool fno,
    bool currency,
    bool commodity,
    Uint8List? proofBytes,
    String? proofFileName,
  ) onSubmit;

  const _SegmentChangeRequestDialog({
    required this.equityDisabled,
    required this.fnoDisabled,
    required this.currencyDisabled,
    required this.commodityDisabled,
    required this.equityPreselected,
    required this.fnoPreselected,
    required this.currencyPreselected,
    required this.commodityPreselected,
    required this.existingSegments,
    required this.inactiveSegments,
    required this.onSubmit,
  });

  @override
  State<_SegmentChangeRequestDialog> createState() =>
      _SegmentChangeRequestDialogState();
}

class _SegmentChangeRequestDialogState
    extends State<_SegmentChangeRequestDialog> {
  late bool _equity;
  late bool _fno;
  late bool _currency;
  late bool _commodity;
  Uint8List? _proofBytes;
  String? _proofFileName;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _equity = widget.equityPreselected;
    _fno = widget.fnoPreselected;
    _currency = widget.currencyPreselected;
    _commodity = widget.commodityPreselected;
  }

  // F&O, Currency, or Commodity selected → need income proof
  bool get _needsProof => _fno || _currency || _commodity;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _proofBytes = result.files.first.bytes;
        _proofFileName = result.files.first.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final successColor = resolveThemeColor(context,
        dark: MyntColors.successDark, light: MyntColors.success);

    final canSubmit = _equity || _fno || _currency || _commodity;

    final bgColor = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor);
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      elevation: 0,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with bottom border
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Segment Change Request',
                      style: MyntWebTextStyles.title(context,
                          fontWeight: MyntFonts.semiBold, color: textColor),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        // borderRadius: BorderRadius.circular(6),
                        // color: dividerColor.withValues(alpha: 0.3),
                      ),
                      child: Icon(Icons.close, size: 16, color: subtitleColor),
                    ),
                  ),
                ],
              ),
            ),

            // Body content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Segments',
                      style: MyntWebTextStyles.bodySmall(context,
                          color: subtitleColor, fontWeight: MyntFonts.medium)),
                  const SizedBox(height: 12),

                  // Segment chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildChip('Equity', _equity, widget.equityDisabled,
                          (v) => setState(() => _equity = v)),
                      _buildChip('F&O', _fno, widget.fnoDisabled,
                          (v) => setState(() => _fno = v)),
                      _buildChip('Currency', _currency, widget.currencyDisabled,
                          (v) => setState(() => _currency = v)),
                      _buildChip('Commodity', _commodity, widget.commodityDisabled,
                          (v) => setState(() => _commodity = v)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Info text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: primaryColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'As per the latest guidelines by SEBI & Exchange, you need to upload any one of the below mentioned document to trade in Derivatives.',
                            style: MyntWebTextStyles.caption(context,
                                color: subtitleColor),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // File upload section
                  if (_needsProof) ...[
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: _pickFile,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.cloud_upload_outlined,
                                  size: 22, color: primaryColor),
                            ),
                            const SizedBox(height: 12),
                            Text('Upload your Income Proof',
                                style: MyntWebTextStyles.body(context,
                                    fontWeight: MyntFonts.semiBold,
                                    color: textColor)),
                            const SizedBox(height: 4),
                            Text(
                                'Click to browse or drag & drop your file here',
                                style: MyntWebTextStyles.caption(context,
                                    color: subtitleColor)),
                            const SizedBox(height: 6),
                            Text('PDF only, max 5MB',
                                style: MyntWebTextStyles.caption(context,
                                    color: subtitleColor.withValues(
                                        alpha: 0.6))),
                          ],
                        ),
                      ),
                    ),
                    if (_proofFileName != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: successColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: successColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 16, color: successColor),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(_proofFileName!,
                                  style: MyntWebTextStyles.bodySmall(context,
                                      color: textColor,
                                      fontWeight: MyntFonts.medium)),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () => setState(() {
                                _proofBytes = null;
                                _proofFileName = null;
                              }),
                              child: Icon(Icons.close,
                                  size: 14, color: subtitleColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Submit button with top border
            Container(
              padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: dividerColor)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (canSubmit && !_submitting)
                      ? () async {
                          if (_needsProof && _proofBytes == null) {
                            warningMessage(
                                context, 'Upload your income proof');
                            return;
                          }
                          setState(() => _submitting = true);
                          await widget.onSubmit(
                            _equity,
                            _fno,
                            _currency,
                            _commodity,
                            _proofBytes,
                            _proofFileName,
                          );
                          if (mounted) setState(() => _submitting = false);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: resolveThemeColor(context,
                        dark: MyntColors.secondary,
                        light: MyntColors.primary),
                    disabledBackgroundColor: dividerColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 25,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Submit',
                          style: MyntWebTextStyles.body(context,
                              fontWeight: MyntFonts.semiBold,
                              color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
      String label, bool selected, bool disabled, ValueChanged<bool> onChanged) {
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    return GestureDetector(
      onTap: disabled ? null : () => onChanged(!selected),
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? primaryColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: selected ? primaryColor : dividerColor),
          ),
          child: Text(
            label,
            style: MyntWebTextStyles.bodySmall(context,
                fontWeight: MyntFonts.medium,
                color: selected ? primaryColor : (disabled ? subtitleColor : textColor)),
          ),
        ),
      ),
    );
  }
}

