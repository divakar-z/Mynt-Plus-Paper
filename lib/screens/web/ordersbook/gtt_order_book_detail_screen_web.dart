import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/screens/web/ordersbook/modify_gtt_web.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../models/order_book_model/gtt_order_book.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../utils/responsive_snackbar.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../main.dart' show getNavigatorContext;

class GttOrderBookDetailScreenWeb extends ConsumerStatefulWidget {
  final GttOrderBookModel gttOrder;
  final BuildContext? parentContext;

  const GttOrderBookDetailScreenWeb({
    super.key,
    required this.gttOrder,
    this.parentContext,
  });

  @override
  ConsumerState<GttOrderBookDetailScreenWeb> createState() =>
      _GttOrderBookDetailScreenWebState();
}

class _GttOrderBookDetailScreenWebState
    extends ConsumerState<GttOrderBookDetailScreenWeb> {
  StreamSubscription? _socketSubscription;
  late GttOrderBookModel _gttOrder;

  @override
  void initState() {
    super.initState();
    _gttOrder = _copyGttOrderData(widget.gttOrder);
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  GttOrderBookModel _copyGttOrderData(GttOrderBookModel original) {
    final copy = GttOrderBookModel();
    copy.stat = original.stat;
    copy.emsg = original.emsg;
    copy.aiT = original.aiT;
    copy.alId = original.alId;
    copy.tsym = original.tsym;
    copy.exch = original.exch;
    copy.token = original.token;
    copy.remarks = original.remarks;
    copy.validity = original.validity;
    copy.norentm = original.norentm;
    copy.pp = original.pp;
    copy.ls = original.ls;
    copy.ti = original.ti;
    copy.brkname = original.brkname;
    copy.actid = original.actid;
    copy.trantype = original.trantype;
    copy.prctyp = original.prctyp;
    copy.qty = original.qty;
    copy.prc = original.prc;
    copy.c = original.c;
    copy.prd = original.prd;
    copy.ordersource = original.ordersource;
    copy.placeOrderParams = original.placeOrderParams;
    copy.placeOrderParamsLeg2 = original.placeOrderParamsLeg2;
    copy.d = original.d;
    copy.oivariable = original.oivariable;
    copy.symbol = original.symbol;
    copy.expDate = original.expDate;
    copy.option = original.option;
    copy.ltp = original.ltp;
    copy.open = original.open;
    copy.high = original.high;
    copy.close = original.close;
    copy.low = original.low;
    copy.change = original.change;
    copy.perChange = original.perChange;
    copy.gttOrderCurrentStatus = original.gttOrderCurrentStatus;
    copy.ordDate = original.ordDate;
    return copy;
  }

  // Pre-load data to avoid flickering
  Future<void> _preLoadData() async {
    if (!mounted) return;

    // Get the latest socket data for this token immediately
    final wsProvider = ref.read(websocketProvider);
    final socketData = wsProvider.socketDatas[_gttOrder.token];

    if (socketData != null) {
      final lp = socketData['lp']?.toString();
      final pc = socketData['pc']?.toString();
      final chng = socketData['chng']?.toString();

      if (lp != null && lp != "null" && lp != "0" && lp != "0.00") {
        _gttOrder.ltp = lp;
      }

      if (pc != null && pc != "null" && pc != "0" && pc != "0.00") {
        _gttOrder.perChange = pc;
      }

      if (chng != null && chng != "null" && chng != "" &&
          chng != "0" && chng != "0.0" && chng != "0.00") {
        _gttOrder.change = chng;
      }
    }

    // Set up socket subscription
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _setupSocketSubscription();
        setState(() {});
      }
    });
  }

  void _setupSocketSubscription() {
    if (!mounted) return;

    try {
      final wsProvider = ref.read(websocketProvider);

      _socketSubscription = wsProvider.socketDataStream.listen((socketData) {
        if (!mounted) return;

        final data = socketData[_gttOrder.token];
        if (data != null) {
          setState(() {
            final lp = data['lp']?.toString();
            final pc = data['pc']?.toString();
            final chng = data['chng']?.toString();

            if (_isValidValue(lp)) _gttOrder.ltp = lp;
            if (_isValidValue(pc)) _gttOrder.perChange = pc;
            if (_isValidValue(chng)) _gttOrder.change = chng;
          });
        }
      });
    } catch (e) {
    }
  }

  bool _isValidValue(String? value) {
    return value != null &&
        value != "null" &&
        value != "0" &&
        value != "0.0" &&
        value != "0.00";
  }

  bool _didInitDependencies = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didInitDependencies) {
      _didInitDependencies = true;

      Future.microtask(() {
        if (mounted) {
          _preLoadData();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeProvider);
    final marketwatch = ref.watch(marketWatchProvider);

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Order Details title
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.dividerDark,
                        light: MyntColors.divider,
                      ),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        shadcn.closeSheet(context);
                      },
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Order Details',
                      style: MyntWebTextStyles.title(
                        context,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Symbol Info Section
                        _buildSymbolSection(theme, marketwatch),
                        const SizedBox(height: 16),
                        // Action Buttons
                        _buildActionButtons(theme, marketwatch),
                        // Details Section
                        _buildOrderParametersSection(theme),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSymbolSection(
      ThemesProvider theme, MarketWatchProvider marketwatch) {
    DepthInputArgs depthArgs = DepthInputArgs(
      exch: _gttOrder.exch ?? "",
      token: _gttOrder.token ?? "",
      tsym: _gttOrder.tsym ?? '',
      instname: marketwatch.getQuotes?.instname ?? "",
      symbol: _gttOrder.symbol ?? '',
      expDate: _gttOrder.expDate ?? '',
      option: _gttOrder.option ?? '',
    );

    return GestureDetector(
      onTap: () async {
        shadcn.closeSheet(context);
        await marketwatch.scripdepthsize(false);
        await marketwatch.calldepthApis(context, depthArgs, "");
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Symbol with its exchange beside it, the way the trade and order
          // detail panes already show it. The exchange used to be a row down
          // among the order fields, which is not where the other panes put it.
          Row(
            children: [
              Flexible(
                child: Text(
                  "${_gttOrder.displayName} ",
                  style: MyntWebTextStyles.title(
                    context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _gttOrder.exch ?? '',
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Price and Change
          Row(
            children: [
              Text(
                _gttOrder.ltp ?? _gttOrder.prc ?? '0.00',
                style: MyntWebTextStyles.title(
                  context,
                  color: (_gttOrder.change == "null" ||
                              _gttOrder.change == null) ||
                          _gttOrder.change == "0.00"
                      ? resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary)
                      : (_gttOrder.change?.startsWith("-") == true ||
                              _gttOrder.perChange?.startsWith("-") == true)
                          ? resolveThemeColor(context,
                              dark: MyntColors.lossDark, light: MyntColors.loss)
                          : resolveThemeColor(context,
                              dark: MyntColors.profitDark,
                              light: MyntColors.profit),
                  fontWeight: MyntFonts.medium,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                "${(double.tryParse(_gttOrder.change ?? '0.00') ?? 0.00).toStringAsFixed(2)} (${_gttOrder.perChange ?? '0.00'}%)",
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                  fontWeight: MyntFonts.medium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      ThemesProvider theme, MarketWatchProvider marketwatch) {
    final status = _gttOrder.gttOrderCurrentStatus?.toUpperCase() ?? '';
    final isPending = status == 'PENDING' || status == 'TRIGGER_PENDING';

    if (!isPending) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  "Modify",
                  false, // Outlined
                  theme,
                  () => _handleModify(marketwatch),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  "Cancel",
                  true, // Primary
                  theme,
                  _handleCancel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, bool isPrimary, ThemesProvider theme,
      VoidCallback onPressed) {
    if (isPrimary) {
      return MyntPrimaryButton(
        label: text,
        onPressed: onPressed,
        isFullWidth: true,
      );
    } else {
      return MyntOutlinedButton(
        label: text,
        onPressed: onPressed,
        isFullWidth: true,
      );
    }
  }

  Widget _buildOrderParametersSection(ThemesProvider theme) {
    // Leg 1 is always the Target and leg 2 always the Stoploss, on both buy and
    // sell - GttOrderBookModel.fromJson normalises a buy OCO back into that
    // order. A single GTT has one leg that is neither, so it keeps a plain
    // trigger header.
    final bool isOco = _gttOrder.placeOrderParamsLeg2 != null;
    final conds = _gttOrder.oivariable;
    final String leg1Trigger = (conds != null && conds.isNotEmpty)
        ? (conds.first.d ?? '-')
        : (_gttOrder.d ?? '-');
    final String leg2Trigger =
        (conds != null && conds.length > 1) ? (conds.last.d ?? '-') : '-';

    // Which direction each trigger fires in. A single GTT states it outright in
    // ai_t; an OCO carries one ai_t for the pair, so the higher of the two
    // levels is the "above" leg and the lower one the "below" leg. Without
    // this the header said only "Trigger @ 18.00", which does not say whether
    // it fires on a rise or a fall to that level.
    String leg1Cond = '';
    String leg2Cond = '';
    if (isOco) {
      // Taken from the wire position, not by comparing the two levels. The
      // broker's first slot is always the "above" condition; fromJson reverses
      // that pair for a buy, so after normalising leg 1 is the above leg on a
      // sell and the below leg on a buy. Comparing the numbers instead would
      // read a non-straddling pair backwards - the vendor terminal accepts one
      // (a buy with "above 9" and "below 16"), and such a rule can reach this
      // screen even though our own screens block it.
      final String side =
          _gttOrder.trantype ?? _gttOrder.placeOrderParams?.trantype ?? '';
      final bool leg1IsAbove = side != 'B';
      leg1Cond = _conditionLabel(leg1IsAbove);
      leg2Cond = _conditionLabel(!leg1IsAbove);
    } else {
      final String ait = _gttOrder.aiT ?? '';
      if (ait == 'LTP_A_O') {
        leg1Cond = _conditionLabel(true);
      } else if (ait == 'LTP_B_O') {
        leg1Cond = _conditionLabel(false);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Facts about the whole GTT, listed once. These used to sit inside the
          // leg 1 block, which made them read as if they described that leg
          // alone while leg 2 appeared to be missing them.
          //
          // "GTT Id" not "Order Id": while the rule is pending no order exists
          // and this is the rule's own al_id, shared by both legs. Each leg
          // gets its own order id only once it fires, and the pending response
          // does not carry one.
          _rowOfInfoData("GTT Order Id", _gttOrder.alId ?? "-", theme),
          _rowOfInfoData("Created on", _formatCreatedAt(), theme),
          // Exchange moved up beside the symbol, where the other detail panes
          // put it. Validity read "GTT" on every rule and Status was a constant
          // stamped on at parse time, so neither varied or told the reader
          // anything on this screen.
          /*
          _rowOfInfoData("Exchange", _gttOrder.exch ?? '-', theme),
          _rowOfInfoData("Validity", _gttOrder.validity ?? '-', theme),
          _rowOfInfoDataWithColor(
            "Status",
            _getGttStatusText(),
            theme,
            _getGttStatusColor(theme),
          ),
          */

          if (_gttOrder.placeOrderParams != null) ...[
            _legHeader(
              isOco
                  ? "Target trigger @ $leg1Trigger$leg1Cond"
                  : "Trigger @ $leg1Trigger$leg1Cond",
              theme,
            ),
            ..._legRows(
              theme: theme,
              trantype: _gttOrder.placeOrderParams?.trantype,
              qty: _gttOrder.placeOrderParams?.qty,
              prd: _gttOrder.placeOrderParams?.prd,
              prctyp: _gttOrder.placeOrderParams?.prctyp,
              prc: _gttOrder.placeOrderParams?.prc,
            ),
          ],

          if (_gttOrder.placeOrderParamsLeg2 != null) ...[
            _legHeader("Stoploss trigger @ $leg2Trigger$leg2Cond", theme),
            ..._legRows(
              theme: theme,
              trantype: _gttOrder.placeOrderParamsLeg2?.trantype,
              qty: _gttOrder.placeOrderParamsLeg2?.qty,
              prd: _gttOrder.placeOrderParamsLeg2?.prd,
              prctyp: _gttOrder.placeOrderParamsLeg2?.prctyp,
              prc: _gttOrder.placeOrderParamsLeg2?.prc,
            ),
          ],
          if (_gttOrder.remarks != null && _gttOrder.remarks != "") ...[
            // Remarks is usually a reason type field
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.dividerDark,
                      light: MyntColors.divider,
                    ),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Remarks",
                    style: MyntWebTextStyles.body(
                      context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary),
                      fontWeight: MyntFonts.medium,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "${_gttOrder.remarks}",
                      textAlign: TextAlign.end,
                      style: MyntWebTextStyles.body(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Header above a leg's rows, carrying that leg's own trigger level. Leg 1
  /// previously had no header at all while leg 2 was labelled "Leg 2", so the
  /// two blocks did not read as a pair and leg 1's trigger had to be repeated
  /// as a row.
  /// Suffix naming the direction a trigger fires in.
  String _conditionLabel(bool isAbove) =>
      isAbove ? " (LTP goes above)" : " (LTP goes below)";

  Widget _legHeader(String label, ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        label,
        style: MyntWebTextStyles.title(
          context,
          color: resolveThemeColor(context,
              dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
          fontWeight: MyntFonts.bold,
        ),
      ),
    );
  }

  /// The rows under a leg header. Both legs carry the same fields in the
  /// response, so both blocks now show the same five. Leg 1 used to show a
  /// trigger price and no price while leg 2 showed a price and no trigger,
  /// which read as missing data on each side.
  List<Widget> _legRows({
    required ThemesProvider theme,
    String? trantype,
    int? qty,
    String? prd,
    String? prctyp,
    String? prc,
  }) {
    final bool isMarket = prctyp == "MKT" || prctyp == "SL-MKT";
    return [
      _rowOfInfoData("Type", trantype == 'B' ? 'Buy' : 'Sell', theme),
      _rowOfInfoData("Qty", "${qty ?? 0}", theme),
      _rowOfInfoData("Product", _getProductName(prd), theme),
      _rowOfInfoData("Order type", _orderTypeLabel(prctyp), theme),
      // A market leg carries a price of 0.00 on the wire, which would read as a
      // real limit of zero. The Order type row above already says MARKET.
      _rowOfInfoData("Price", isMarket ? "-" : (prc ?? '-'), theme),
    ];
  }

  /// Creation stamp for the top block. norentm arrives as "HH:mm:ss dd-MM-yyyy"
  /// on this call, so it is reordered into "yyyy-MM-dd HH:mm:ss" to read the
  /// same way as the Created on column in the GTT table.
  String _formatCreatedAt() {
    final String raw = _gttOrder.norentm ?? '';
    if (raw.isEmpty) return _gttOrder.ordDate ?? '-';

    if (raw.contains('T')) return raw.replaceFirst('T', ' ');

    final parts = raw.split(' ');
    if (parts.length >= 2) {
      final dateParts = parts[1].split('-');
      if (dateParts.length == 3) {
        return '${dateParts[2]}-${dateParts[1]}-${dateParts[0]} ${parts[0]}';
      }
      return '${parts[1]} ${parts[0]}';
    }
    return raw;
  }

  String _orderTypeLabel(String? prctyp) {
    switch (prctyp) {
      case "LMT":
        return "LIMIT";
      case "MKT":
        return "MARKET";
      case "SL-LMT":
        return "SL";
      case "SL-MKT":
        return "SL-M";
      default:
        return prctyp ?? '-';
    }
  }

  String _getProductName(String? prd) {
    switch (prd) {
      case "C":
        return "CNC";
      case "I":
        return "MIS";
      case "M":
        return "NRML";
      default:
        return "-";
    }
  }

  Widget _rowOfInfoData(String title1, String value1, ThemesProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(
              context,
              dark: MyntColors.dividerDark,
              light: MyntColors.divider,
            ),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title1,
              style: MyntWebTextStyles.body(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
                fontWeight: MyntFonts.medium,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value1,
              textAlign: TextAlign.end,
              style: MyntWebTextStyles.body(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
                fontWeight: MyntFonts.medium,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Retired with the Status row above - kept commented rather than deleted
  // so the badge can be restored if the Triggered tab ever needs it here.
  /*
  Widget _rowOfInfoDataWithColor(
      String title, String value, ThemesProvider theme, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(
              context,
              dark: MyntColors.dividerDark,
              light: MyntColors.divider,
            ),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: MyntWebTextStyles.body(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
                fontWeight: MyntFonts.medium,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: valueColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: MyntWebTextStyles.body(
                  context,
                  color: valueColor,
                  fontWeight: MyntFonts.medium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
  */

  // Retired with the Status row above - kept commented rather than deleted
  // so the badge can be restored if the Triggered tab ever needs it here.
  /*
  String _getGttStatusText() {
    final status = _gttOrder.gttOrderCurrentStatus?.toUpperCase() ?? 'PENDING';
    switch (status) {
      case 'PENDING':
        return 'Pending';
      case 'TRIGGER_PENDING':
        return 'Trigger Pending';
      case 'CANCELLED':
      case 'CANCELED':
        return 'Cancelled';
      case 'TRIGGERED':
        return 'Triggered';
      case 'EXECUTED':
        return 'Executed';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status;
    }
  }
  */

  // Retired with the Status row above - kept commented rather than deleted
  // so the badge can be restored if the Triggered tab ever needs it here.
  /*
  Color _getGttStatusColor(ThemesProvider theme) {
    final status = _gttOrder.gttOrderCurrentStatus?.toUpperCase() ?? 'PENDING';

    switch (status) {
      case 'PENDING':
      case 'TRIGGER_PENDING':
        return resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary);
      case 'EXECUTED':
        return resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
      case 'CANCELLED':
      case 'CANCELED':
      case 'REJECTED':
        return resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);
      case 'TRIGGERED':
        return resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
      default:
        return resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary);
    }
  }
  */

  Future<void> _handleCancel() async {
    try {
      final targetContext =
          widget.parentContext ?? getNavigatorContext();
      if (targetContext == null) {
        if (mounted) {
          ResponsiveSnackBar.showError(
              context, "Unable to access target context");
        }
        return;
      }

      // Save provider reference and data BEFORE closing sheet
      // (widget might be disposed after sheet closes)
      final orderProviderRef = ref.read(orderProvider);
      final theme = ref.read(themeProvider);
      final gttOrderId = _gttOrder.alId ?? '';

      // Close the sheet first (exact same pattern as open order details)
      if (mounted) {
        try {
          shadcn.closeSheet(context);
        } catch (e) {
          // Ignore sheet close errors
        }
      }

      // Wait for sheet to close, then show dialog (exact same pattern as open order details)
      await Future.delayed(const Duration(milliseconds: 150));

      // Show dialog after sheet closes using targetContext (same as open order details)
      final shouldCancel =
          await _showCancelGttOrderDialog(theme, targetContext);

      if (shouldCancel != true) {
        return;
      }

      // Cancel the GTT order using saved provider reference
      await orderProviderRef.cancelGttOrder(gttOrderId, targetContext,
          isOco: _gttOrder.placeOrderParamsLeg2 != null);
    } catch (e) {
      final rootCtx = getNavigatorContext();
      if (rootCtx != null && rootCtx.mounted) {
        ResponsiveSnackBar.showError(
            rootCtx, 'Failed to cancel GTT order: ${e.toString()}');
      }
    }
  }

  Future<bool?> _showCancelGttOrderDialog(
      ThemesProvider theme, BuildContext targetContext) async {
    final symbol = _gttOrder.displayName.trim();

    return showDialog<bool>(
      context: targetContext,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: resolveThemeColor(
                dialogContext,
                dark: Colors.black,
                light: Colors.white,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row with title and close button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
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
                        'Cancel GTT Order',
                        style: MyntWebTextStyles.title(
                          dialogContext,
                          color: resolveThemeColor(
                            dialogContext,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: resolveThemeColor(
                                dialogContext,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content area
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Confirmation text with symbol in quotes
                      Text(
                        'Are you sure you want to cancel "$symbol"?',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.body(
                          dialogContext,
                          color: resolveThemeColor(
                            dialogContext,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),

                      // Red Cancel button
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: resolveThemeColor(dialogContext,
                                dark: MyntColors.errorDark,
                                light: MyntColors.tertiary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Cancel',
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

  Future<void> _handleModify(MarketWatchProvider marketwatch) async {
    try {
      // Use parent context (table context) - same as action handler uses
      final targetContext =
          widget.parentContext ?? getNavigatorContext();
      if (targetContext == null) {
        if (mounted) {
          ResponsiveSnackBar.showError(
              context, "Unable to access target context");
        }
        return;
      }

      await marketwatch.fetchScripInfo(
        "${_gttOrder.token}",
        "${_gttOrder.exch}",
        targetContext,
        true,
      );

      if (!mounted) return;

      final scripInfo = marketwatch.scripInfoModel;
      if (scripInfo == null) {
        if (mounted) {
          ResponsiveSnackBar.showError(
              targetContext, 'Unable to fetch scrip information');
        }
        return;
      }

      // Close the sheet first (like position/holdings screens)
      if (mounted) {
        try {
          shadcn.closeSheet(context);
        } catch (e) {
          // Ignore sheet close errors
        }
      }

      // Wait for sheet to close
      await Future.delayed(const Duration(milliseconds: 150));

      // Check context is still valid after sheet close
      if (!targetContext.mounted) {
        return;
      }

      // Show modify dialog - use exact same pattern as action handler
      ModifyGttWeb.showDraggable(
        context: targetContext,
        gttOrderBook: _gttOrder,
        scripInfo: scripInfo,
      );
    } catch (e) {
      final rootCtx = getNavigatorContext();
      if (rootCtx != null && rootCtx.mounted) {
        ResponsiveSnackBar.showError(
            rootCtx, 'Failed to open modify GTT order: ${e.toString()}');
      }
    }
  }
}
