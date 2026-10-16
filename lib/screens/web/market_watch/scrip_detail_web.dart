import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../provider/market_watch_provider.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/custom_exch_badge.dart';

class ScripDetailWeb extends ConsumerStatefulWidget {
  const ScripDetailWeb({super.key});

  @override
  ConsumerState<ScripDetailWeb> createState() => _ScripDetailWebState();
}

class _ScripDetailWebState extends ConsumerState<ScripDetailWeb> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scripInfo = ref.watch(marketWatchProvider).scripInfoModel!;

    return shadcn.Card(
      borderRadius: BorderRadius.circular(8),
      padding: EdgeInsets.zero,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with title and close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: shadcn.Theme.of(context).colorScheme.border,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Symbol info
                  Expanded(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        // mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${scripInfo.symbol} ',
                              style: MyntWebTextStyles.title(
                                context,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              ' ${scripInfo.option}',
                              style: MyntWebTextStyles.para(
                                context,
                                fontWeight: MyntFonts.medium,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.textSecondaryDark,
                                  light: MyntColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // CustomExchBadge(exch: "${scripInfo.exch}"),
                            // const SizedBox(width: 6),
                            Text(
                              scripInfo.expDate ?? "",
                              style: MyntWebTextStyles.para(
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
                      ],
                    ),
                  ),
                  // Close button
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () async {
                        await Future.delayed(const Duration(milliseconds: 150));
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      splashColor: resolveThemeColor(
                        context,
                        dark: MyntColors.rippleDark,
                        light: MyntColors.rippleLight,
                      ),
                      highlightColor: resolveThemeColor(
                        context,
                        dark: MyntColors.highlightDark,
                        light: MyntColors.highlightLight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.iconDark,
                            light: MyntColors.icon,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content area
            Expanded(
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
                child: RawScrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  thickness: 6,
                  radius: const Radius.circular(0),
                  thumbColor: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark.withValues(alpha: 0.5),
                          light: MyntColors.textSecondary)
                      .withValues(alpha: 0.5),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      children: [
                        // const SizedBox(height: 12),
                        _rowOfInfoData(
                          context,
                          "Company Name",
                          scripInfo.cname ?? "-",
                          "Symbol Name",
                          // BFO symname is the instrument code ("BSXOPT"); show the
                          // friendly symbol ("SENSEX") instead. Other exch unchanged.
                          (scripInfo.exch == "BFO"
                                  ? scripInfo.symbol
                                  : scripInfo.symname) ??
                              "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Expiry Date",
                          scripInfo.expDate ?? "-",
                          "Expiry Time",
                          scripInfo.exptime ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Instrument Name",
                          scripInfo.instname ?? "-",
                          "Segment",
                          scripInfo.seg ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Option Type",
                          scripInfo.optt ?? "-",
                          "ISIN",
                          scripInfo.isin ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Tick Size",
                          scripInfo.ti ?? "-",
                          "Lot Size",
                          scripInfo.ls ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Price Precision",
                          scripInfo.pp ?? "-",
                          "Multiplier",
                          scripInfo.mult ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Gn/Gd * Pn/Pd",
                          scripInfo.prcftrD ?? "-",
                          "Price Units",
                          scripInfo.prcunt ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Price Quote Qty",
                          scripInfo.prcqqty ?? "-",
                          "Trade Units",
                          scripInfo.trdunt ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Delivery Units",
                          scripInfo.delunt ?? "-",
                          "Freeze Qty",
                          scripInfo.frzqty ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Gsm Ind",
                          scripInfo.gsmind ?? "-",
                          "Elm Buy Margin",
                          scripInfo.elmbmrg ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Additional Long Margin",
                          scripInfo.addbmrg ?? "-",
                          "Elm Sell Margin",
                          scripInfo.elmsmrg ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Additional Short Margin",
                          scripInfo.addsmrg ?? "-",
                          "Special Long Margin",
                          scripInfo.splbmrg ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Delivery Margin",
                          scripInfo.delmrg ?? "-",
                          "Special Short Margin",
                          scripInfo.splsmrg ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Tender Margin",
                          scripInfo.tenmrg ?? "-",
                          "Tender Start Date",
                          scripInfo.tenstrd ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Exercise Start Date",
                          scripInfo.exestrd ?? "-",
                          "Tender End Date",
                          scripInfo.tenendd ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Exercise End Date",
                          scripInfo.exeendd ?? "-",
                          "Contract Token",
                          scripInfo.token ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Var Margin",
                          scripInfo.varmrg ?? "-",
                          "Elm Margin",
                          scripInfo.elmmrg ?? "-",
                        ),
                        const SizedBox(height: 3),
                        _rowOfInfoData(
                          context,
                          "Last Trading Date",
                          scripInfo.lastTrdD ?? "-",
                          "Strike Price",
                          scripInfo.strprc ?? "-",
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Exposure Margin",
                                    style: MyntWebTextStyles.para(
                                      context,
                                      color: resolveThemeColor(
                                        context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    scripInfo.expmrg ?? "-",
                                    style: MyntWebTextStyles.body(
                                      context,
                                      color: resolveThemeColor(
                                        context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowOfInfoData(
    BuildContext context,
    String title1,
    String value1,
    String title2,
    String value2,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title1,
                style: MyntWebTextStyles.para(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value1,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Divider(
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.dividerDark,
                  light: MyntColors.divider,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title2,
                style: MyntWebTextStyles.para(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value2,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Divider(
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.dividerDark,
                  light: MyntColors.divider,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
