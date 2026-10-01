import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../models/order_book_model/sip_order_book.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../utils/responsive_snackbar.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../sharedWidget/functions.dart';
import '../../../routes/web_router.dart' show webNavigatorKey;
import 'modify_sip_dialog_web.dart';

class SipOrderDetailScreenWeb extends ConsumerStatefulWidget {
  final SipDetails sipOrder;
  final BuildContext? parentContext;

  const SipOrderDetailScreenWeb({
    super.key,
    required this.sipOrder,
    this.parentContext,
  });

  @override
  ConsumerState<SipOrderDetailScreenWeb> createState() =>
      _SipOrderDetailScreenWebState();
}

class _SipOrderDetailScreenWebState
    extends ConsumerState<SipOrderDetailScreenWeb> {
  StreamSubscription? _socketSubscription;
  late SipDetails _sipOrder;

  @override
  void initState() {
    super.initState();
    _sipOrder = widget.sipOrder;
    _setupSocketSubscription();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  void _setupSocketSubscription() {
    if (!mounted || _sipOrder.scrips?.isEmpty == true) return;

    try {
      final wsProvider = ref.read(websocketProvider);

      _socketSubscription = wsProvider.socketDataStream.listen((socketData) {
        if (!mounted) return;

        bool hasUpdates = false;
        // Update LTP/change for all scrips in the basket
        for (int i = 0; i < _sipOrder.scrips!.length; i++) {
          final token = _sipOrder.scrips![i].token;
          if (token == null) continue;

          final data = socketData[token];
          if (data != null) {
            final lp = data['lp']?.toString();
            final pc = data['pc']?.toString();
            final chng = data['chng']?.toString();

            if (_isValidValue(lp)) {
              _sipOrder.scrips![i].ltp = lp;
              hasUpdates = true;
            }
            if (_isPresent(pc)) {
              _sipOrder.scrips![i].perChange = pc;
              hasUpdates = true;
            }
            if (_isPresent(chng)) {
              _sipOrder.scrips![i].change = chng;
              hasUpdates = true;
            }
          }
        }

        if (hasUpdates) {
          setState(() {});
        }
      });
    } catch (e) {
    }
  }

  // Change / % change may legitimately be 0.00 (back to flat); only a zero

  // LTP is a placeholder. Rejecting "0.00" left the last non-zero change.

  bool _isPresent(String? value) =>

      value != null && value != "null" && value.isNotEmpty;


  bool _isValidValue(String? value) {
    return value != null &&
        value != "null" &&
        value != "0" &&
        value != "0.0" &&
        value != "0.00";
  }

  String _getFrequencyText(String? frequency) {
    switch (frequency) {
      case '0':
        return 'Daily';
      case '1':
        return 'Weekly';
      case '2':
        return 'Fortnightly';
      case '3':
        return 'Monthly';
      default:
        return frequency ?? 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeProvider);

    return Container(
      constraints: const BoxConstraints(maxWidth: 480),     
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          _buildHeader(context, theme),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SIP Name + stock count in a row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _sipOrder.sipName ?? 'N/A',
                        style: MyntWebTextStyles.head(
                          context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary),
                          fontWeight: MyntFonts.semiBold,
                        ),
                      ),
                      if ((_sipOrder.scrips?.length ?? 0) > 1) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${_sipOrder.scrips!.length} stocks in basket)',
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  _buildActionButtons(context, theme),
                  const SizedBox(height: 16),

                  // SIP Detail Rows
                  _buildDetailRow(context, 'SIP ID',
                      _sipOrder.internal?.sipId ?? 'N/A'),
                  _buildDetailRow(context, 'Registered On',
                      duedateformate(value: _sipOrder.regDate ?? '')),
                  _buildDetailRow(context, 'Start Date',
                      duedateformate(value: _sipOrder.startDate ?? '')),
                  _buildDetailRow(context, 'Due Date',
                      duedateformate(value: _sipOrder.internal?.dueDate ?? '')),
                  _buildDetailRow(context, 'Execution Date',
                      duedateformate(value: _sipOrder.internal?.execDate ?? '')),
                  _buildDetailRow(
                      context, 'Frequency', _getFrequencyText(_sipOrder.frequency)),
                  _buildDetailRow(
                      context, 'Pending Period', _sipOrder.endPeriod ?? 'N/A'),
                  if (_sipOrder.scrips?.isNotEmpty == true) ...[
                    _buildDetailRow(
                        context,
                        'Product',
                        _sipOrder.scrips![0].sprdtali ?? 'N/A'),
                    _buildDetailRow(
                        context,
                        'Total Stocks',
                        '${_sipOrder.scrips!.length}',
                        showDivider: false),
                  ],
                  const SizedBox(height: 24),

                  // Scrip list
                  if (_sipOrder.scrips?.isNotEmpty == true) ...[
                    Text(
                      'Stocks List',
                      style: MyntWebTextStyles.titlesub(
                        context,
                        fontWeight: MyntFonts.semiBold,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Divider(
                    //   height: 1,
                    //   color: resolveThemeColor(context,
                    //       dark: MyntColors.dividerDark, light: MyntColors.divider),
                    // ),
                    ...(_sipOrder.scrips!.asMap().entries.map((entry) {
                      return _buildScripRow(
                          context, entry.value, entry.key, _sipOrder.scrips!.length > 1);
                    })),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemesProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          shadcn.IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => shadcn.closeSheet(context),
            variance: shadcn.ButtonVariance.ghost,
            size: shadcn.ButtonSize.small,
          ),
          const SizedBox(width: 12),
          Text(
            'SIP Order Details',
            style: MyntWebTextStyles.title(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScripRow(BuildContext context, Scrips scrip, int index, bool showIndex) {
    final ltp = scrip.ltp ?? '0.00';
    final perChange = scrip.perChange ?? '0.00';
    final changeValue = double.tryParse(perChange) ?? 0.0;

    // Determine if this is qty or amount (prc) based SIP
    final isQtyMode = scrip.sipType != 'prc';
    final investLabel = isQtyMode ? 'QTY' : 'AMOUNT';
    final investValue = isQtyMode ? (scrip.qty ?? '0') : '₹${scrip.prc ?? '0'}';

    Color changeColor;
    if (changeValue > 0) {
      changeColor = resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    } else if (changeValue < 0) {
      changeColor = resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    } else {
      changeColor = resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: showIndex
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: resolveThemeColor(context,
                      dark: MyntColors.dividerDark, light: MyntColors.divider),
                  width: 0.5,
                ),
              ),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scrip.tsym ?? 'N/A',
                  style: MyntWebTextStyles.symbol(
                    context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                    fontWeight: MyntFonts.medium,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      scrip.exch ?? '',
                      style: MyntWebTextStyles.exch(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$investLabel: $investValue',
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end, 
            children: [
              Text(
                '$ltp',
                style: MyntWebTextStyles.symbol(
                  context,
                  color: changeColor,
                  
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${scrip.change ?? '0.00'} ($perChange%)',
                style: MyntWebTextStyles.para(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary) ,
                  fontWeight: MyntFonts.medium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value,
      {bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: MyntWebTextStyles.body(
              context,
              color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                  fontWeight: MyntFonts.medium,
                 ),
          ),
          Text(
            value,
            style: MyntWebTextStyles.body(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
          ),
        ],
      ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemesProvider theme) {
    return Row(
      children: [
        Expanded(
          child: MyntPrimaryButton(
            label: 'Modify SIP',
            onPressed: () => _handleModifySip(context),
            isFullWidth: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MyntTertiaryButton(
            label: 'Cancel SIP',
            onPressed: () => _handleCancelSip(context),
            isFullWidth: true,
          ),
        ),
      ],
    );
  }

  Future<void> _handleModifySip(BuildContext context) async {
    // Capture SIP details before closing sheet
    final sipDetails = _sipOrder;
    final theme = ref.read(themeProvider);

    // Close the detail sheet first
    shadcn.closeSheet(context);

    // Get navigator context for dialog
    final navigatorContext = webNavigatorKey.currentContext;
    if (navigatorContext == null) return;

    // Show modify dialog (same pattern as CreateSipDialogWeb)
    await showDialog(
      context: navigatorContext,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: theme.isDarkMode
              ? MyntColors.backgroundColorDark
              : MyntColors.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            width: 580,
            height: 720,
            child: ModifySipDialogWeb(sipDetails: sipDetails),
          ),
        );
      },
    );
  }

  Future<void> _handleCancelSip(BuildContext context) async {
    // Capture needed data BEFORE closing sheet
    final orderProviderRef = ref.read(orderProvider);
    final sipId = _sipOrder.internal?.sipId ?? '';
    final sipName = _sipOrder.sipName ?? 'SIP';

    // Close the sheet FIRST
    shadcn.closeSheet(context);

    // Get navigator context for dialog and snackbar
    final navigatorContext = webNavigatorKey.currentContext;
    if (navigatorContext == null) return;

    // Show confirmation dialog after sheet is closed
    final shouldCancel = await _showCancelConfirmDialogStandalone(navigatorContext, sipName);
    if (shouldCancel != true) return;

    // Perform cancel operation - fetchSipOrderCancel handles refresh and snackbar
    try {
      await orderProviderRef.fetchSipOrderCancel(sipId, navigatorContext);
    } catch (e) {
      if (navigatorContext.mounted) {
        ResponsiveSnackBar.showError(
            navigatorContext, 'Failed to cancel SIP order: ${e.toString()}');
      }
    }
  }

  /// Standalone cancel confirmation dialog that uses navigator context
  Future<bool?> _showCancelConfirmDialogStandalone(
      BuildContext navigatorContext, String sipName) async {
    return showDialog<bool>(
      context: navigatorContext,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: resolveThemeColor(dialogContext,
                  dark: MyntColors.backgroundColorDark,
                  light: MyntColors.backgroundColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: shadcn.Border(
                      bottom: shadcn.BorderSide(
                        color: resolveThemeColor(
                          dialogContext,
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
                        'Cancel SIP Order',
                        style: MyntWebTextStyles.title(
                          dialogContext,
                          color: resolveThemeColor(dialogContext,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const shadcn.CircleBorder(),
                        child: InkWell(
                          customBorder: const shadcn.CircleBorder(),
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: resolveThemeColor(dialogContext,
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
                        'Are you sure you want to cancel "$sipName"?',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.body(
                          dialogContext,
                          color: resolveThemeColor(dialogContext,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: resolveThemeColor(dialogContext,
                                dark: MyntColors.errorDark,
                                light: MyntColors.tertiary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Cancel SIP',
                            style: MyntWebTextStyles.buttonMd(
                              dialogContext,
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
        );
      },
    );
  }
}
