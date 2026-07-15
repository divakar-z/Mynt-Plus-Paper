import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../models/order_book_model/trade_book_model.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/common_buttons_web.dart';

class TradeBookDetailScreenWeb extends ConsumerStatefulWidget {
  final TradeBookModel tradeData;

  const TradeBookDetailScreenWeb({
    super.key,
    required this.tradeData,
  });

  @override
  ConsumerState<TradeBookDetailScreenWeb> createState() =>
      _TradeBookDetailScreenWebState();
}

class _TradeBookDetailScreenWebState
    extends ConsumerState<TradeBookDetailScreenWeb>
    with SingleTickerProviderStateMixin {
  late TradeBookModel _tradeData;
  late AnimationController _animationController;

  // Track processing states

  @override
  void initState() {
    super.initState();
    // Make a copy of the trade data to avoid modifying the original
    _tradeData = _copyTradeData(widget.tradeData);

    // Set up animation controller for smooth transitions
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Socket subscription is now handled by StreamBuilder
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Create a copy of the TradeBookModel to avoid modifying the original
  TradeBookModel _copyTradeData(TradeBookModel original) {
    final copy = TradeBookModel();
    copy.token = original.token;
    copy.exch = original.exch;
    copy.tsym = original.tsym;
    copy.symbol = original.symbol;
    copy.expDate = original.expDate;
    copy.option = original.option;
    copy.ltp = original.ltp;
    copy.perChange = original.perChange;
    copy.change = original.change;
    copy.trantype = original.trantype;
    copy.qty = original.qty;
    copy.avgprc = original.avgprc;
    copy.sPrdtAli = original.sPrdtAli;
    copy.norenordno = original.norenordno;
    copy.norentm = original.norentm;
    copy.flqty = original.flqty;
    copy.flprc = original.flprc;
    copy.flid = original.flid;
    copy.fltm = original.fltm;
    copy.prc = original.prc;
    copy.prcftr = original.prcftr;
    copy.fillshares = original.fillshares;
    copy.ls = original.ls;
    copy.ti = original.ti;
    copy.pp = original.pp;
    copy.exchTm = original.exchTm;
    copy.exchordid = original.exchordid;
    copy.dname = original.dname;
    copy.stat = original.stat;
    copy.emsg = original.emsg;
    copy.uid = original.uid;
    copy.actid = original.actid;
    copy.prctyp = original.prctyp;
    copy.ret = original.ret;
    copy.prd = original.prd;
    return copy;
  }

  // Helper method to check if a value is valid
  bool _isValidValue(String? value) {
    return value != null &&
        value != "null" &&
        value != "0" &&
        value != "0.0" &&
        value != "0.00";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final theme = ref.watch(themeProvider);
        final marketwatch = ref.watch(marketWatchProvider);

        // PERFORMANCE FIX: Use ref.read() for stream - watching causes double rebuild
        return StreamBuilder<Map>(
          stream: ref.read(websocketProvider).socketDataStream,
          builder: (context, snapshot) {
            final socketDatas = snapshot.data ?? {};

            // Create a copy of trade data for real-time updates
            TradeBookModel updatedTradeData = _tradeData;

            // Update trade data with real-time values if available
            if (socketDatas.containsKey(_tradeData.token)) {
              final lp = socketDatas["${_tradeData.token}"]['lp']?.toString();
              final pc = socketDatas["${_tradeData.token}"]['pc']?.toString();
              final chng =
                  socketDatas["${_tradeData.token}"]['chng']?.toString();

              if (lp != null && lp != "null" && lp != "0" && lp != "0.00") {
                updatedTradeData.ltp = lp;
              }

              if (pc != null && pc != "null" && pc != "0" && pc != "0.00") {
                updatedTradeData.perChange = pc;
              }

              if (chng != null && chng != "null" && chng != "" &&
                  chng != "0" && chng != "0.0" && chng != "0.00") {
                updatedTradeData.change = chng;
              }
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fixed Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: resolveThemeColor(context,
                            dark: MyntColors.dividerDark,
                            light: MyntColors.divider),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSymbolSection(theme, marketwatch, updatedTradeData),
                      MyntCloseButton(
                        onPressed: () => shadcn.closeSheet(context),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                        top: 0, bottom: 20, left: 20, right: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Trade Value Section
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child:
                              _buildTradeValueSection(theme, updatedTradeData),
                        ),

                        // Trade Details Section
                        _buildTradeDetailsSection(theme, updatedTradeData),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSymbolSection(ThemesProvider theme,
      MarketWatchProvider marketwatch, TradeBookModel displayData) {
    DepthInputArgs depthArgs = DepthInputArgs(
      exch: displayData.exch ?? "",
      token: displayData.token ?? "",
      tsym: marketwatch.getQuotes?.tsym ?? '',
      instname: marketwatch.getQuotes?.instname ?? "",
      symbol: marketwatch.getQuotes?.symbol ?? '',
      expDate: marketwatch.getQuotes?.expDate ?? '',
      option: marketwatch.getQuotes?.option ?? '',
    );

    return Material(
      color: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(),
        borderRadius: BorderRadius.circular(0),
        splashColor: resolveThemeColor(context,
            dark: MyntColors.primary.withOpacity(0.1),
            light: MyntColors.primary.withOpacity(0.1)),
        highlightColor: resolveThemeColor(context,
            dark: MyntColors.primary.withOpacity(0.2),
            light: MyntColors.primary.withOpacity(0.2)),
        onTap: () async {
          Navigator.pop(context);
          await marketwatch.scripdepthsize(false);
          await marketwatch.calldepthApis(context, depthArgs, "");
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Symbol and Exchange
            Row(
              children: [
                Text(
                  "${displayData.displayName} ",
                  style: MyntWebTextStyles.title(
                    context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "${displayData.exch}",
                  style: MyntWebTextStyles.title(
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
                  displayData.ltp ?? displayData.prc ?? '0.00',
                  style: MyntWebTextStyles.title(
                    context,
                    color: (displayData.change == "null" ||
                                displayData.change == null) ||
                            displayData.change == "0.00"
                        ? resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary)
                        : (displayData.change?.startsWith("-") == true ||
                                displayData.perChange?.startsWith("-") == true)
                            ? resolveThemeColor(context,
                                dark: MyntColors.lossDark,
                                light: MyntColors.loss)
                            : resolveThemeColor(context,
                                dark: MyntColors.profitDark,
                                light: MyntColors.profit),
                    fontWeight: MyntFonts.medium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${(double.tryParse(displayData.change ?? '0.00') ?? 0.00).toStringAsFixed(2)} (${displayData.perChange ?? '0.00'}%)",
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
      ),
    );
  }

  Widget _buildTradeValueSection(
      ThemesProvider theme, TradeBookModel displayData) {
    final tradeValue = _calculateTradeValue(displayData);
    final isProfit = tradeValue >= 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(
              "Trade Value",
              style: MyntWebTextStyles.title(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
                fontWeight: MyntFonts.medium,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "₹${tradeValue.toStringAsFixed(2)}",
              style: MyntWebTextStyles.head(
                context,
                color: isProfit
                    ? resolveThemeColor(context,
                        dark: MyntColors.profitDark, light: MyntColors.profit)
                    : resolveThemeColor(context,
                        dark: MyntColors.lossDark, light: MyntColors.loss),
                fontWeight: MyntFonts.medium,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTradeDetailsSection(
      ThemesProvider theme, TradeBookModel displayData) {
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow("Transaction Type",
                      displayData.trantype == "B" ? "Buy" : "Sell", theme),
                  _buildInfoRow("Quantity", displayData.qty ?? '0', theme),
                  _buildInfoRow("Price", displayData.avgprc ?? '0.00', theme),
                  _buildInfoRow("Product", displayData.sPrdtAli ?? '-', theme),
                  _buildInfoRow(
                      "Order Number", displayData.norenordno ?? '-', theme),
                  _buildInfoRow(
                      "Trade Time", displayData.norentm ?? "-", theme),
                ],
              ),
            ),
            // Vertical divider
            Container(
              width: 0.5,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: resolveThemeColor(context,
                  dark: MyntColors.dividerDark, light: MyntColors.divider),
            ),
            // Right column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                      "Fill Quantity", displayData.flqty ?? '0', theme),
                  _buildInfoRow(
                      "Fill Price", displayData.flprc ?? '0.00', theme),
                  _buildInfoRow("Fill ID", displayData.flid ?? '-', theme),
                  _buildInfoRow("Fill Time", displayData.fltm ?? "-", theme),
                  _buildInfoRow(
                      "Fill Shares", displayData.fillshares ?? '0', theme),
                  _buildInfoRow(
                      "Product Type", displayData.prctyp ?? '-', theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, ThemesProvider theme,
      [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: MyntWebTextStyles.body(
                context,
                color: valueColor ??
                    resolveThemeColor(context,
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

  double _calculateTradeValue(TradeBookModel tradeData) {
    try {
      final qty = double.tryParse(tradeData.qty?.toString() ?? "0") ?? 0.0;
      final price = double.tryParse(tradeData.avgprc?.toString() ?? "0") ?? 0.0;
      return qty * price;
    } catch (e) {
      return 0.0;
    }
  }

  // Action handlers
}
