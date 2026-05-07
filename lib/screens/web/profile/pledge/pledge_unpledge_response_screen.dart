// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:mynt_plus/provider/ledger_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';

class PledgenUnpledgeResponse extends StatelessWidget {
  final String ddd;
  const PledgenUnpledgeResponse({super.key, required this.ddd});

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, WidgetRef ref, _) {
      final theme = ref.watch(themeProvider);
      final ledgerprovider = ref.watch(ledgerProvider);

      return WillPopScope(
        onWillPop: () async {
          await ledgerprovider.getCurrentDate("pandu");
          ledgerprovider.fetchpledgeandunpledge(context);
          Navigator.pop(context);
          return true;
        },
        child: Scaffold(
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      CustomBackBtn(
                        onBack: () async {
                          await ledgerprovider.getCurrentDate("pandu");
                          ledgerprovider.fetchpledgeandunpledge(context);
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pledge Report Details',
                        style: MyntWebTextStyles.title(context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary,
                            fontWeight: MyntFonts.semiBold),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ledgerprovider.cdslresponsedata == null ||
                  ledgerprovider.pledgeloader
              ? Center(
                  child: Container(
                    color: resolveThemeColor(context,
                        dark: MyntColors.backgroundColorDark,
                        light: MyntColors.backgroundColor),
                    child: MyntLoader.branded(),
                  ),
                )
              : _PledgeResponseBody(
                  theme: theme,
                  ledgerprovider: ledgerprovider,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _PledgeResponseBody extends StatelessWidget {
  final ThemesProvider theme;
  final LDProvider ledgerprovider;

  const _PledgeResponseBody({
    required this.theme,
    required this.ledgerprovider,
  });

  // ── Text style helpers ──

  TextStyle _labelStyle(BuildContext context) {
    return MyntWebTextStyles.body(
      context,
      darkColor: MyntColors.textSecondaryDark,
      lightColor: MyntColors.textSecondary,
      fontWeight: MyntFonts.medium,
    );
  }

  TextStyle _valueStyle(BuildContext context) {
    return MyntWebTextStyles.body(
      context,
      darkColor: MyntColors.textPrimaryDark,
      lightColor: MyntColors.textPrimary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  TextStyle _headerStyle(BuildContext context) {
    return MyntWebTextStyles.body(
      context,
      darkColor: MyntColors.textSecondaryDark,
      lightColor: MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  TextStyle _cellStyle(BuildContext context) {
    return MyntWebTextStyles.body(
      context,
      darkColor: MyntColors.textPrimaryDark,
      lightColor: MyntColors.textPrimary,
      fontWeight: MyntFonts.medium,
    );
  }

  // ── Status helpers ──
  // CDSL's new pledge API exposes reqstatus alongside resstatus; either being
  // '1' means rejected. Anything else is treated as a successful response.

  bool _isRejected(String? a, String? b) => a == '1' || b == '1';

  Widget _buildStatusBadge(BuildContext context,
      {String? reqstatus, String? resstatus}) {
    final rejected = _isRejected(reqstatus, resstatus);
    final label = rejected ? 'Rejected' : 'Success';
    final color = rejected
        ? resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss)
        : resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
    final bgColor = color.withValues(alpha: 0.1);
    final textColor = color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: bgColor,
      ),
      child: Text(
        label,
        style: MyntWebTextStyles.body(
          context,
          color: textColor,
          darkColor: textColor,
          lightColor: textColor,
          fontWeight: MyntFonts.semiBold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary Card ──
        _buildSummaryCard(context),

        const SizedBox(height: 16),

        // ── ISIN Table ──
        Expanded(
          child: _buildIsinTable(context),
        ),
      ],
    );
  }

  // ── Summary Card ──

  Widget _buildSummaryCard(BuildContext context) {
    final data = ledgerprovider.cdslresponsedata;
    final pledgeTwo =
        data?.cDSLResp?.pledgeresdtls?.pledgeresdtlstwo;
    // CDSL ID: prefer resid, fall back to reqid so an ID is always visible
    // while the response is still pending.
    final resid = pledgeTwo?.resid;
    final cdslId = (resid != null && resid.isNotEmpty)
        ? resid
        : (pledgeTwo?.reqid ?? '--');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: shadcn.OutlinedContainer(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left column
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(context, 'Client Name',
                          data?.cLIENTNAME ?? '--'),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                          context, 'Client ID', data?.uccid ?? '--'),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                          context, 'BO ID', data?.clientBoId ?? '--'),
                      const SizedBox(height: 16),
                      _buildInfoRow(context, 'Request ID',
                          pledgeTwo?.reqid ?? '--'),
                    ],
                  ),
                ),
              ),
              // Vertical divider
              VerticalDivider(
                width: 1,
                thickness: 0.5,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.dividerDark,
                  light: MyntColors.divider,
                ),
              ),
              // Right column
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Status', style: _labelStyle(context)),
                          _buildStatusBadge(
                            context,
                            reqstatus: pledgeTwo?.reqstatus,
                            resstatus: pledgeTwo?.resstatus,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        context,
                        'CDSL Requested Time',
                        data?.pledgeReqTime ?? '--',
                        alignRight: true,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        context,
                        'CDSL Response Time',
                        data?.cDSLRespTime ?? '--',
                        alignRight: true,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        context,
                        'CDSL ID',
                        cdslId,
                        alignRight: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value,
      {bool alignRight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: _labelStyle(context)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: _valueStyle(context),
            textAlign: alignRight ? TextAlign.right : TextAlign.right,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  // ── ISIN Table ──

  Widget _buildIsinTable(BuildContext context) {
    final isinList = ledgerprovider.cdslresponsedata?.cDSLResp?.pledgeresdtls
        ?.pledgeresdtlstwo?.isinresdtls;

    if (isinList == null || isinList.isEmpty) {
      return const Center(
        child: NoDataFound(secondaryEnabled: false),
      );
    }

    // Final column order: Script, ISIN, Req Id, Res Id, Quantity, Price, Value, Status.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth - 48;
        final columnWidths = {
          0: shadcn.FixedTableSize(totalWidth * 0.14), // Script
          1: shadcn.FixedTableSize(totalWidth * 0.14), // ISIN
          2: shadcn.FixedTableSize(totalWidth * 0.13), // Req Id
          3: shadcn.FixedTableSize(totalWidth * 0.13), // Res Id
          4: shadcn.FixedTableSize(totalWidth * 0.10), // Quantity
          5: shadcn.FixedTableSize(totalWidth * 0.10), // Price
          6: shadcn.FixedTableSize(totalWidth * 0.10), // Value
          7: shadcn.FixedTableSize(totalWidth * 0.16), // Status
        };

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: shadcn.OutlinedContainer(
            child: Column(
              children: [
                // Fixed Header
                shadcn.Table(
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  columnWidths: columnWidths,
                  rows: [
                    shadcn.TableHeader(
                      cells: [
                        _buildHeaderCellWidget(context, 'Script', 0),
                        _buildHeaderCellWidget(context, 'ISIN', 1),
                        _buildHeaderCellWidget(context, 'Req Id', 2),
                        _buildHeaderCellWidget(context, 'Res Id', 3),
                        _buildHeaderCellWidget(context, 'Quantity', 4, true),
                        _buildHeaderCellWidget(context, 'Price', 5, true),
                        _buildHeaderCellWidget(context, 'Value', 6, true),
                        _buildHeaderCellWidget(context, 'Status', 7),
                      ],
                    ),
                  ],
                ),
                // Scrollable data rows
                Expanded(
                  child: SingleChildScrollView(
                    child: shadcn.Table(
                      defaultRowHeight: const shadcn.FixedTableSize(52),
                      columnWidths: columnWidths,
                      rows: isinList.asMap().entries.map((entry) {
                        final index = entry.key;
                        final val = entry.value;

                        return shadcn.TableRow(
                          cells: [
                            _buildDataCellWidget(
                              context,
                              rowIndex: index,
                              columnIndex: 0,
                              child: Text(val.script ?? '--',
                                  style: _cellStyle(context),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1),
                            ),
                            _buildDataCellWidget(
                              context,
                              rowIndex: index,
                              columnIndex: 1,
                              child: Text(val.isin ?? '--',
                                  style: _cellStyle(context),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1),
                            ),
                            _buildDataCellWidget(
                              context,
                              rowIndex: index,
                              columnIndex: 2,
                              child: Text(val.isinreqid ?? '--',
                                  style: _cellStyle(context),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1),
                            ),
                            _buildDataCellWidget(
                              context,
                              rowIndex: index,
                              columnIndex: 3,
                              child: Text(val.isinresid ?? '--',
                                  style: _cellStyle(context),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1),
                            ),
                            _buildDataCellWidget(
                              context,
                              rowIndex: index,
                              columnIndex: 4,
                              alignRight: true,
                              child: Text(val.quantity ?? '--',
                                  style: _cellStyle(context)),
                            ),
                            _buildDataCellWidget(
                              context,
                              rowIndex: index,
                              columnIndex: 5,
                              alignRight: true,
                              child: Text(val.price ?? '--',
                                  style: _cellStyle(context)),
                            ),
                            _buildDataCellWidget(
                              context,
                              rowIndex: index,
                              columnIndex: 6,
                              alignRight: true,
                              child: Text(val.value ?? '--',
                                  style: _cellStyle(context)),
                            ),
                            _buildDataCellWidget(
                              context,
                              rowIndex: index,
                              columnIndex: 7,
                              child: _buildStatusBadge(
                                context,
                                reqstatus: val.reqstatus,
                                resstatus: val.status,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Table cell builders ──

  shadcn.TableCell _buildHeaderCellWidget(
      BuildContext context, String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 7;

    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding = const EdgeInsets.fromLTRB(16, 0, 8, 0);
    } else if (isLastColumn) {
      headerPadding = const EdgeInsets.fromLTRB(8, 0, 16, 0);
    } else {
      headerPadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 0);
    }

    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: Container(
        padding: headerPadding,
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(label, style: _headerStyle(context)),
      ),
    );
  }

  shadcn.TableCell _buildDataCellWidget(
    BuildContext context, {
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 7;

    EdgeInsets cellPadding;
    if (isFirstColumn) {
      cellPadding = const EdgeInsets.fromLTRB(16, 12, 12, 12);
    } else if (isLastColumn) {
      cellPadding = const EdgeInsets.fromLTRB(12, 12, 16, 12);
    } else {
      cellPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
    }

    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: Container(
        padding: cellPadding,
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
  }
}
