import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/provider/ledger_provider.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/screens/Mobile/desk_reports/bottom_sheets/ledger_filter.dart';
import 'package:mynt_plus/screens/web/profile/Reports/ledger/ledger_bill.dart';
// import 'package:mynt_plus/screens/web/profile/Reports/ledger/ledger_filter.dart';
// import 'package:mynt_plus/screens/web/profile/Reports/ledger_filter.dart';
// import 'package:mynt_plus/screens/desk_reports/bottom_sheets/ledger_bill.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/custom_exch_badge.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';
import 'package:mynt_plus/sharedWidget/loader_ui.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';

import '../../../../../../provider/thems.dart';
import '../../../../../../res/global_state_text.dart';
import '../../../../../../sharedWidget/custom_switch_btn.dart';
import '../../../../../../sharedWidget/list_divider.dart';
import '../../../../../../sharedWidget/splash_loader.dart';
import '../../../../../../utils/no_emoji_inputformatter.dart';


class LedgerScreen extends ConsumerStatefulWidget {
  final String ddd;
  const LedgerScreen({super.key, required this.ddd});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  @override
  void initState() {
    super.initState();
    if (ref.read(ledgerProvider).selectedFilters.isNotEmpty) {
      // If there are selected filters, apply them immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(ledgerProvider).applyLedgerMultiFilter(
            context, ref.read(ledgerProvider).selectedFilters.toList());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> staticColumn = [
      'Row 1',
      'Row 2',
      'Row 3',
      'Row 4',
      // 'Row 4'
    ];
    final List<String> Header = [
      'Date',
      "Debit",
      "Credit",
      "Net Amount",
      "Details"
    ];
    double screenWidth = MediaQuery.of(context).size.width;
    double screenheight = MediaQuery.of(context).size.height;

    return Consumer(builder: (context, WidgetRef ref, _) {
      final theme = ref.watch(themeProvider);
      double crdamount = 0.0;
      double dtamount = 0.0;

      final ledgerprovider = ref.watch(ledgerProvider);
      // Future<void> _refresh() async {
      //   // Show confirmation dialog
      //   bool shouldRefresh = await showDialog(
      //     context: context,
      //     barrierDismissible: false,
      //     builder: (BuildContext dialogContext) {
      //       return Consumer(builder: (context, ref, _) {
      //         final theme = ref.watch(themeProvider);
      //         return AlertDialog(
      //           backgroundColor: colors.colorWhite,
      //           titlePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      //           shape: const RoundedRectangleBorder(
      //             borderRadius: BorderRadius.all(Radius.circular(8)),
      //           ),
      //           scrollable: true,
      //           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      //           actionsPadding: const EdgeInsets.only(bottom: 16, right: 16, left: 16, top: 8),
      //           insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      //           title: Column(
      //             children: [
      //               Row(
      //                 mainAxisAlignment: MainAxisAlignment.end,
      //                 children: [
      //                   Material(
      //                     color: Colors.transparent,
      //                     shape: const CircleBorder(),
      //                     child: InkWell(
      //                       onTap: () async {
      //                         await Future.delayed(const Duration(milliseconds: 150));
      //                         Navigator.pop(dialogContext, false);
      //                       },
      //                       borderRadius: BorderRadius.circular(20),
      //                       splashColor: theme.isDarkMode
      //                           ? colors.splashColorDark
      //                           : colors.splashColorLight,
      //                       highlightColor: theme.isDarkMode
      //                           ? colors.splashColorDark
      //                           : colors.splashColorLight,
      //                       child: Padding(
      //                         padding: const EdgeInsets.all(6.0),
      //                         child: Icon(
      //                           Icons.close_rounded,
      //                           size: 22,
      //                           color: theme.isDarkMode
      //                               ? colors.colorWhite
      //                               : colors.colorBlack,
      //                         ),
      //                       ),
      //                     ),
      //                   ),
      //                 ],
      //               ),
      //               const SizedBox(height: 12),
      //               SizedBox(
      //                 width: MediaQuery.of(context).size.width,
      //                 child: Column(
      //                   crossAxisAlignment: CrossAxisAlignment.center,
      //                   children: [
      //                     const SizedBox(height: 10),
      //                     TextWidget.subText(
      //                       text: "Do you want to refresh?",
      //                       theme: theme.isDarkMode,
      //                       color: theme.isDarkMode
      //                           ? colors.textPrimaryDark
      //                           : colors.textPrimaryLight,
      //                       fw: 3,
      //                       align: TextAlign.center,
      //                     ),
      //                   ],
      //                 ),
      //               ),
      //             ],
      //           ),
      //           actions: [
      //             SizedBox(
      //               width: double.infinity,
      //               child: OutlinedButton(
      //                 onPressed: () async {
      //                   Navigator.pop(dialogContext, true);
      //                 },
      //                 style: OutlinedButton.styleFrom(
      //                   minimumSize: const Size(0, 40),
      //                   side: BorderSide(color: colors.btnOutlinedBorder),
      //                   shape: RoundedRectangleBorder(
      //                     borderRadius: BorderRadius.circular(5),
      //                   ),
      //                   backgroundColor: colors.primaryDark,
      //                 ),
      //                 child: TextWidget.titleText(
      //                   text: "Yes",
      //                   theme: theme.isDarkMode,
      //                   color: !theme.isDarkMode
      //                       ? colors.colorWhite
      //                       : colors.colorBlack,
      //                   fw: 0,
      //                 ),
      //               ),
      //             ),
      //           ],
      //         );
      //       });
      //     },
      //   ) ?? false;

      //   if (shouldRefresh) {

      //   }
      // }

      String opbalance = ledgerprovider.ledgerAllData?.openingBalance ?? '0.0';
      // String tdebit = ledgerprovider.ledgerAllData?.drAmt ?? '0.0';
      // String tcredit = ledgerprovider.ledgerAllData?.crAmt ?? '0.0';
      String clbalance = ledgerprovider.ledgerAllData?.closingBalance ?? '0.0';

      return RefreshIndicator(
        onRefresh: () async {
          await ledgerprovider.getCurrentDate('else');
          await ledgerprovider.fetchLegerData(
              context, ledgerprovider.startDate, ledgerprovider.endDate, ledgerprovider.includeBillMargin);
        },
        child: PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) async {
            ledgerprovider.falseloader('ledger');
            ledgerprovider.showledgerSearch(true);
          },
          child: Scaffold(
            appBar: AppBar(
              // automaticallyImplyLeading: false,
              leadingWidth: 41,
              titleSpacing: 6,
              centerTitle: false,
              leading: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  splashColor: theme.isDarkMode
                      ? colors.splashColorDark
                      : colors.splashColorLight,
                  highlightColor: theme.isDarkMode
                      ? colors.highlightDark
                      : colors.highlightLight,
                  onTap: () {
                    ledgerprovider.falseloader('ledger');
                    ledgerprovider.showledgerSearch(true);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 44, // Increased touch area
                    height: 44,
                    alignment: Alignment.center,
                    child: Icon(Icons.arrow_back_ios_outlined,
                        size: 18,
                        color: theme.isDarkMode
                        ? colors.textSecondaryDark
                        : colors.textSecondaryLight,),
                  ),
                ),
              ),
              elevation: 0.2,
              title: TextWidget.titleText(
                  text: "Ledger",
                  textOverflow: TextOverflow.ellipsis,
                  color: theme.isDarkMode
                      ? colors.textPrimaryDark
                      : colors.textPrimaryLight,
                  theme: theme.isDarkMode,
                  fw: 1),
              // leading: InkWell(
              //   onTap: () {
          
              //   },
              //   child: Icon(Icons.ios_share)),
            ),
            body: ledgerprovider.ledgerloading
                ? Center(
                    child: Container(
                      color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
                      child: CircularLoaderImage(),
                    ),
                  )
                : SafeArea(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text("${ddd}")
                        // Padding(
                        //     padding: EdgeInsets.only(left: 4.0, top: 10.0),
                        //     child: Text(
                        //       "Financial activities through debits and credits ",
                        //       style: textStyle(colors.colorBlack, 14, FontWeight.w600),
                        //     )),
                        Row(
                          // mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: screenWidth,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0, vertical: 16.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        ledgerprovider.availableFinancialYears
                                                    .indexOf(ledgerprovider
                                                        .selectedFinancialYear) <
                                                ledgerprovider
                                                        .availableFinancialYears
                                                        .length -
                                                    1
                                            ? Material(
                                                color: Colors.transparent,
                                                shape: const CircleBorder(),
                                                child: InkWell(
                                                  splashColor: theme.isDarkMode
                                                      ? colors.splashColorDark
                                                      : colors.splashColorLight,
                                                  highlightColor: theme.isDarkMode
                                                      ? colors.highlightDark
                                                      : colors.highlightLight,
                                                  customBorder:
                                                      const CircleBorder(),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(8.0),
                                                    child: Icon(
                                                      Icons
                                                          .arrow_back_ios_outlined,
                                                      size: 18,
                                                      color: theme.isDarkMode
                                                          ? colors
                                                              .textSecondaryDark
                                                          : colors
                                                              .textSecondaryLight,
                                                    ),
                                                  ),
                                                  onTap: () async {
                                                    await Future.delayed(
                                                        const Duration(
                                                            milliseconds: 150));
                                                    final index = ledgerprovider
                                                        .availableFinancialYears
                                                        .indexOf(ledgerprovider
                                                            .selectedFinancialYear);
                                                    if (index <
                                                        ledgerprovider
                                                                .availableFinancialYears
                                                                .length -
                                                            1) {
                                                      final newFY = ledgerprovider
                                                              .availableFinancialYears[
                                                          index + 1];
                                                      ledgerprovider
                                                          .setFinancialYear(
                                                              newFY);
                                                      ledgerprovider
                                                          .fetchLegerData(
                                                        context,
                                                        ledgerprovider
                                                            .formattedStartDate,
                                                        ledgerprovider
                                                            .formattedendDate,
                                                        ledgerprovider.includeBillMargin
                                                      );
                                                    }
                                                  },
                                                ),
                                              )
                                            : const SizedBox(width: 20),
                                        Column(
                                          children: [
                                            TextWidget.subText(
                                              text: ledgerprovider
                                                  .selectedFinancialYear,
                                              color: theme.isDarkMode
                                                  ? colors.textSecondaryDark
                                                  : colors.textSecondaryLight,
                                              textOverflow: TextOverflow.ellipsis,
                                              theme: theme.isDarkMode,
                                              fw: 0,
                                            ),
                                            SizedBox(
                                              height: 6,
                                            ),
                                            TextWidget.subText(
                                                text: "Balance  ",
                                                color: theme.isDarkMode
                                                  ? colors.textSecondaryDark
                                                  : colors.textSecondaryLight,
                                                textOverflow:
                                                    TextOverflow.ellipsis,
                                                theme: theme.isDarkMode,
                                                fw: 0),
                                            const SizedBox(height: 6),
                                            TextWidget.subText(
                                                text: ledgerprovider.ledgerAllData
                                                            ?.closingBalance ==
                                                        'null'
                                                    ? '0.00'
                                                    : (double.tryParse(ledgerprovider
                                                                    .ledgerAllData
                                                                    ?.closingBalance ??
                                                                '')
                                                            ?.toStringAsFixed(
                                                                2) ??
                                                        '0.00'),
                                                textOverflow:
                                                    TextOverflow.ellipsis,
                                                color: theme.isDarkMode
                                                ? colors.textPrimaryDark
                                                : colors.textPrimaryLight,
                                                theme: theme.isDarkMode,
                                                fw: 0),
                                            // const SizedBox(height: 10),
                                          ],
                                        ),
                                        ledgerprovider.availableFinancialYears
                                                    .indexOf(ledgerprovider
                                                        .selectedFinancialYear) >
                                                0
                                            ? Material(
                                                color: Colors.transparent,
                                                shape: const CircleBorder(),
                                                child: InkWell(
                                                  splashColor: theme.isDarkMode
                                                      ? colors.splashColorDark
                                                      : colors.splashColorLight,
                                                  highlightColor: theme.isDarkMode
                                                      ? colors.highlightDark
                                                      : colors.highlightLight,
                                                  customBorder:
                                                      const CircleBorder(),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(8.0),
                                                    child: Icon(
                                                      Icons
                                                          .arrow_forward_ios_outlined,
                                                      size: 18,
                                                      color: theme.isDarkMode
                                                          ? colors
                                                              .textSecondaryDark
                                                          : colors
                                                              .textSecondaryLight,
                                                    ),
                                                  ),
                                                  onTap: () async {
                                                    await Future.delayed(
                                                        const Duration(
                                                            milliseconds: 150));
                                                    final index = ledgerprovider
                                                        .availableFinancialYears
                                                        .indexOf(ledgerprovider
                                                            .selectedFinancialYear);
                                                    if (index > 0) {
                                                      final newFY = ledgerprovider
                                                              .availableFinancialYears[
                                                          index - 1];
                                                      ledgerprovider
                                                          .setFinancialYear(
                                                              newFY);
                                                      ledgerprovider
                                                          .fetchLegerData(
                                                        context,
                                                        ledgerprovider
                                                            .formattedStartDate,
                                                        ledgerprovider
                                                            .formattedendDate,
                                                        ledgerprovider.includeBillMargin
                                                      );
                                                    }
                                                  },
                                                ),
                                              )
                                            : const SizedBox(width: 20),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Expanded(
                            //   child: Padding(
                            //     padding: const EdgeInsets.all(14.0),
                            //     child: TextField(
                            
                            //       decoration: InputDecoration(
                            //         filled: true,
                            //          fillColor: const Color(0xffF1F3F8),
                            //       hintText: "Search",
                            //         border: OutlineInputBorder(
                            //           borderRadius: BorderRadius.circular(30.0),
                            //         ),
                            //         focusedBorder: OutlineInputBorder(
                            //           borderRadius: BorderRadius.circular(30.0),
                            //           borderSide: BorderSide(color:  Colors.grey, width: 2.0),
                            //         ),
                            //         enabledBorder: OutlineInputBorder(
                            //           borderRadius: BorderRadius.circular(30.0),
                            //           borderSide: BorderSide(color: Colors.grey, width: 1.0),
                            //         ),
                            //         contentPadding: EdgeInsets.symmetric(
                            //           horizontal: 20.0,
                            //           vertical: 15.0,
                            //         ),
                            //         prefixIconColor: const Color(0xff586279),
                            //         prefixIcon: SvgPicture.asset(
                            //           "assets/icon/appbarIcon/search.svg",
                            //           color: const Color(0xff586279),
                            //           fit: BoxFit.scaleDown,
                            //           width: 14,
                            //           height: 14,
                            //         ),
                            //       ),
                            //     ),
                            //   ),
                            
                            // ),
                          ],
                        ),
                        const ListDivider(),
                        ledgerprovider.showLedgerSearch
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 40,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5),
                                        decoration: BoxDecoration(
                                      color: theme.isDarkMode
                  ? colors.searchBgDark
                  : colors.searchBg,
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 10),
                                              child: Row(
                                                children: [
                                                  Material(
                                                    color: Colors.transparent,
                                                    shape: const CircleBorder(),
                                                    clipBehavior: Clip.hardEdge,
                                                    child: InkWell(
                                                      customBorder:
                                                          const CircleBorder(),
                                                      splashColor: theme
                                                              .isDarkMode
                                                          ? colors.splashColorDark
                                                          : colors
                                                              .splashColorLight,
                                                      highlightColor: theme
                                                              .isDarkMode
                                                          ? colors.highlightDark
                                                          : colors.highlightLight,
                                                      onTap: () {
                                                        Future.delayed(
                                                            const Duration(
                                                                milliseconds:
                                                                    150), () {
                                                          // positionBook.showPositionSearch(true);
                                                          ledgerprovider
                                                              .showledgerSearch(
                                                                  false);
                                                        });
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                                8.0),
                                                        child: SvgPicture.asset(
                                                          assets.searchIcon,
                                                         color: theme.isDarkMode
                                ? colors.textSecondaryDark
                                : colors.textSecondaryLight,
                                                          width: 18,
                                                          height: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Material(
                                                    color: Colors.transparent,
                                                    shape: const CircleBorder(),
                                                    clipBehavior: Clip.hardEdge,
                                                    child: InkWell(
                                                      customBorder:
                                                          const CircleBorder(),
                                                      splashColor: theme
                                                              .isDarkMode
                                                          ? colors.splashColorDark
                                                          : colors
                                                              .splashColorLight,
                                                      highlightColor: theme
                                                              .isDarkMode
                                                          ? colors.highlightDark
                                                          : colors.highlightLight,
                                                      onTap: () async {
                                                        await Future.delayed(
                                                            const Duration(
                                                                milliseconds:
                                                                    150));
                                                        ledgerprovider
                                                                .setfilterpage =
                                                            'ledger';
                                                        _showBottomSheet(context,
                                                            const LedgerFilter(), theme);
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                                8.0),
                                                        child: SvgPicture.asset(
                                                          assets.searchFilter,
                                                          width: 16,
                                                          height: 16,
                                                          color: theme.isDarkMode
                                                              ? colors
                                                                  .textSecondaryDark
                                                              : colors
                                                                  .textSecondaryLight,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Material(
                                              color: Colors.transparent,
                                              shape: const CircleBorder(),
                                              clipBehavior: Clip.hardEdge,
                                              child: InkWell(
                                                customBorder:
                                                    const CircleBorder(),
                                                splashColor: theme.isDarkMode
                                                    ? colors.splashColorDark
                                                    : colors.splashColorLight,
                                                highlightColor: theme.isDarkMode
                                                    ? colors.highlightDark
                                                    : colors.highlightLight,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: SvgPicture.asset(
                                                    assets.downloadIcon,
                                                    width: 16,
                                                    height: 16,
                                                  color: theme.isDarkMode
                                ? colors.textSecondaryDark
                                : colors.textSecondaryLight,
                                                  ),
                                                ),
                                                                                                 onTap: () async {
                                                   await Future.delayed(
                                                       const Duration(
                                                           milliseconds: 150));
                                                  showModalBottomSheet(
  context: context,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: true,
  backgroundColor: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
  builder: (context) => downloadBottomSheet(context, theme, ledgerprovider),
);
                                                 },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                            
                                    // TextButton(
                                    //     onPressed: () {
                                    //       positionBook.showPositionSearch(false);
                                    //     },
                                    //     child: TextWidget.paraText(
                                    //         text: "Close",
                                    //         theme: false,
                                    //         color: theme.isDarkMode
                                    //             ? colors.colorLightBlue
                                    //             : colors.colorBlue,
                                    //         fw: 0))
                                  ],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: SizedBox(
                                  height: 40,
                                  child: TextFormField(
                                    autofocus: true,
                                    controller: ledgerprovider.ledgerSearchCtrl,
                                   style: TextWidget.textStyle(
                                    fontSize: 16,
                                    color: theme.isDarkMode
                                        ? colors.textPrimaryDark
                                        : colors.textPrimaryLight,
                                    theme: theme.isDarkMode,
                                    fw: 0,
                                  ),
                                    keyboardType: TextInputType.text,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [
                                      NoEmojiInputFormatter(),
                                      FilteringTextInputFormatter.deny(
                                          RegExp('[π£•₹€℅™∆√¶/.,]'))
                                    ],
                                    decoration: InputDecoration(
                                        hintText: "Search",
                                         hintStyle: TextWidget.textStyle(
                                      fontSize: 14,
                                      theme: theme.isDarkMode,
                                     color: (theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight).withOpacity(0.4),
                                fw: 0,
                                    ),
                                         fillColor: theme.isDarkMode ? colors.searchBgDark : colors.searchBg,
                              filled: true,
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: SvgPicture.asset(
                                              assets.searchIcon,
                                             color: theme.isDarkMode
                                ? colors.textSecondaryDark
                                : colors.textSecondaryLight,
                                              fit: BoxFit.scaleDown,
                                              width: 20),
                                        ),
                                        suffixIcon: Material(
                                          color: Colors.transparent,
                                          shape: const CircleBorder(),
                                          clipBehavior: Clip.hardEdge,
                                          child: InkWell(
                                            customBorder: const CircleBorder(),
                                            splashColor: theme.isDarkMode
                                                ? colors.splashColorDark
                                                : colors.splashColorLight,
                                            highlightColor: theme.isDarkMode
                                                ? colors.highlightDark
                                                : colors.highlightLight,
                                            onTap: () async {
                                              Future.delayed(
                                                  const Duration(
                                                      milliseconds: 150), () {
                                                FocusScope.of(context).unfocus();
                                                ledgerprovider
                                                    .clearLedgerSearch();
                                                ledgerprovider
                                                    .showledgerSearch(true);
                                              });
                                            },
                                            child: SvgPicture.asset(
                                                assets.removeIcon,
                                                 color: theme.isDarkMode
                                ? colors.textSecondaryDark
                                : colors.textSecondaryLight,
                                                fit: BoxFit.scaleDown,
                                                width: 20),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide.none,
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        disabledBorder: InputBorder.none,
                                        focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide.none,
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 5),
                                        border: OutlineInputBorder(
                                            borderSide: BorderSide.none,
                                            borderRadius:
                                                BorderRadius.circular(20))),
                                    onChanged: (value) {
                                      if (value.isNotEmpty) {
                                        // positionBook.showPositionSearch(false);
                                      } else {
                                        // positionBook.showPositionSearch(false);
                                      }
                            
                                      ledgerprovider.searchLedgerType(value);
                                    },
                                  ),
                                ),
                              ),
                        // Bill margin
                        // Padding(
                        //   padding: const EdgeInsets.only(
                        //       right: 16.0, left: 16.0, top: 16.0, bottom: 8.0),
                        //   child: Row(
                        //     children: [
                        //       Expanded(
                        //         child: Row(
                        //           mainAxisAlignment:
                        //               MainAxisAlignment.spaceBetween,
                        //           children: [
                        //             TextWidget.subText(
                        //                 text: "Bill Margin  :",
                        //                 textOverflow: TextOverflow.ellipsis,
                        //                 theme: theme.isDarkMode,
                        //                 fw: 3),
                        //             Padding(
                        //               padding: const EdgeInsets.only(
                        //                   top: 8.0, bottom: 8.0),
                        //               child: Row(
                        //                 mainAxisAlignment:
                        //                     MainAxisAlignment.start,
                        //                 children: [
                        //                   TextWidget.paraText(
                        //                       text: "Yes",
                        //                       textOverflow: TextOverflow.ellipsis,
                        //                       theme: theme.isDarkMode,
                        //                       fw: 3),
                        //                   const SizedBox(width: 10),
                        //                   CustomSwitch(
                        //                       onChanged: (bool value) {
                        //                         ledgerprovider.billnotbill(value);
                        //                         print("${value}");
                        //                       },
                        //                       color: theme.isDarkMode
                        //                           ? const Color(0xffB5C0CF)
                        //                               .withOpacity(.15)
                        //                           : const Color(0xffF1F3F8),
                        //                       value: ledgerprovider.billmargin),
                        //                   const SizedBox(width: 10),
                        //                   TextWidget.paraText(
                        //                       text: "No",
                        //                       textOverflow: TextOverflow.ellipsis,
                        //                       theme: theme.isDarkMode,
                        //                       fw: 3),
                        //                 ],
                        //               ),
                        //             ),
                        //           ],
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        // Padding(
                        //   padding: const EdgeInsets.only(left: 30 , right: 30),
                        //   child: Row(
                        //     children: [
                        //       // Static Column
                        //       Column(
                        //         children: [
                        //           Container(
                        //             margin: EdgeInsets.only(top: 20),
                        //             width: 100,
                        //             color: Colors
                        //                 .cardbgrey, // Header cell for the static column
                        //             padding: EdgeInsets.all(8.0),
                        //             child: Text(
                        //               'Exchange',
                        //               style: TextStyle(fontWeight: FontWeight.bold),
                        //             ),
                        //           ),
                        //           for (var item in ledgerprovider.ledgerAllData!.fullStat!)
                        //             Container(
                        //               width: 100, // Fixed width for the static column
                        //               height: 50,
                            
                        //               padding: EdgeInsets.all(8.0),
                        //               decoration: BoxDecoration(
                        //                 border: Border.all(color: const Color.fromARGB(255, 224, 224, 224)),
                        //               ),
                        //               child: Text("${item.cOCD}",
                        //               style: textStyle(Colors.black, 14, FontWeight.w600),
                        //               ),
                        //             ),
                        //         ],
                        //       ),
                        //       // Scrollable Content
                            
                        //       Expanded(
                        //         child: SingleChildScrollView(
                        //           scrollDirection: Axis.horizontal,
                        //           child: Column(
                        //             children: [
                        //               // Header Row for the scrollable content
                        //               Row(
                        //                 children: [
                        //                   for (int i = 0; i < Header.length; i++)
                        //                     Container(
                        //                        margin: EdgeInsets.only(top: 20),
                        //                       width: i == 4 ? 275 : 100, // Column width
                            
                        //                       padding: EdgeInsets.all(8.0),
                        //                       color: Color(0xFFEEEEEE),
                        //                       child: Text(
                        //                         '${Header[i]}',
                        //                         style:
                        //                             TextStyle(fontWeight: FontWeight.bold),
                        //                       ),
                        //                     ),
                        //                 ],
                        //               ),
                        //               // Data Rows for the scrollable content
                        //               for (int rowIndex = 0;
                        //                   rowIndex <
                        //                       ledgerprovider
                        //                           .ledgerAllData!.fullStat!.length;
                        //                   rowIndex++)
                        //                 Row(
                        //                   children: [
                        //                     for (int colIndex = 0; colIndex < 5; colIndex++)
                        //                       Container(
                        //                          width: colIndex == 4 ? 275 : 100,  // Column width
                        //                         height: 50,
                        //                         padding: EdgeInsets.all(8.0),
                        //                         decoration: BoxDecoration(
                        //                           border: Border.all(color: Color.fromARGB(255, 224, 224, 224)),
                        //                         ),
                        //                         child: Text(colIndex == 0 ? dateFormatChangeForLedger(ledgerprovider
                        //                             .tablearray[rowIndex][colIndex]) : ledgerprovider
                        //                             .tablearray[rowIndex][colIndex] ,
                        //                             textAlign: colIndex == 1 ||colIndex == 2 || colIndex == 3  ? TextAlign.right : TextAlign.start ,
                        //                             ) ,
                        //                         //  child: Text(  ledgerprovider
                        //                         //     .tablearray[rowIndex][colIndex] ) ,
                        //                       ),
                        //                   ],
                        //                 ),
                        //             ],
                        //           ),
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        const ListDivider(),
                        ledgerprovider.ledgerAllData?.fullStat?.isEmpty ?? true
                            ? Expanded(
                              child: Center(
                                  child: NoDataFound(
                                    secondaryEnabled: false,
                                  )),
                            )
                            : Expanded(
                                child: SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  child: ListView.separated(
                                    physics: ClampingScrollPhysics(),
                                    itemCount: ledgerprovider
                                            .ledgerAllData?.fullStat?.length ??
                                        0,
                                    shrinkWrap: true,
                                    itemBuilder: (context, index) {
                                      return InkWell(
                                        onTap: () async {
                                          if (ledgerprovider.ledgerAllData
                                                      ?.fullStat?[index].tYPE ==
                                                  'Bill' &&
                                              ledgerprovider.ledgerAllData
                                                      ?.fullStat?[index].bill ==
                                                  'Yes') {
                                            final ledgerEntry = ledgerprovider
                                                .ledgerAllData?.fullStat?[index];
                            
                                            if (ledgerEntry != null) {
                                              // Show logo loader
                                              showDialog(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (_) =>
                                                    const CircularLoaderImage(),
                                              );
                                              await ledgerprovider
                                                  .fetchBillDetails(
                                                context,
                                                ledgerEntry.sETTLEMENTNO ?? '',
                                                ledgerEntry.mKTTYPE ?? '',
                                                ledgerEntry.cOCD ?? '',
                                                dateFormatChangeForLedger(
                                                    ledgerEntry.vOUCHERDATE ??
                                                        ''),
                                              );
                                              // Hide loader
                                              Navigator.of(context,
                                                      rootNavigator: true)
                                                  .pop();
                            
                                              if (context.mounted) {
                                                await _showBottomSheet(
                                                  context,
                                                  const LedgerBillBottom(),
                                                  theme
                                                );
                                              }
                                            }
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16.0, vertical: 12.0),
                                          child: Column(
                                            children: [
                                              // if (index != 0 &&
                                              //     ledgerprovider.ledgerAllData!
                                              //             .fullStat![index].vOUCHERDATE !=
                                              //         ledgerprovider
                                              //             .ledgerAllData!
                                              //             .fullStat![index - 1]
                                              //             .vOUCHERDATE) ...[
                                              //   Card(
                                              //     elevation: 0.0,
                                              //     color: theme.isDarkMode
                                              //         ? const Color(0xffB5C0CF)
                                              //             .withOpacity(.15)
                                              //         : const Color(0xffF1F3F8),
                                              //     child: Row(
                                              //       mainAxisAlignment:
                                              //           MainAxisAlignment.start,
                                              //       children: [
                                              //         Padding(
                                              //           padding: const EdgeInsets.all(8.0),
                                              //           child: Text(
                                              //               "${index == 0 ? dateFormatChangeForLedger(ledgerprovider.ledgerAllData!.fullStat![index].vOUCHERDATE.toString()) : ledgerprovider.ledgerAllData!.fullStat![index].vOUCHERDATE == ledgerprovider.ledgerAllData!.fullStat![index - 1].vOUCHERDATE ? '' : dateFormatChangeForLedger(ledgerprovider.ledgerAllData!.fullStat![index].vOUCHERDATE.toString())}",
                                              //               style: textStyle(
                                              //                   theme.isDarkMode
                                              //                       ? colors.colorWhite
                                              //                       : colors.colorBlack,
                                              //                   14,
                                              //                   FontWeight.w600)),
                                              //         ),
                                              //       ],
                                              //     ),
                                              //   ),
                                              // ],
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 4.0),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        TextWidget.subText(
                                                          text:
                                                              "${ledgerprovider.ledgerAllData!.fullStat![index].tYPE} ",
                                                          color: theme.isDarkMode
                                                              ? colors
                                                                  .textPrimaryDark
                                                              : colors
                                                                  .textPrimaryLight,
                                                          textOverflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          theme: theme.isDarkMode,
                                                          fw: 0,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        ledgerprovider
                                                                    .ledgerAllData!
                                                                    .fullStat![
                                                                        index]
                                                                    .billMargin ==
                                                                'Yes'
                                                            ? Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            4,
                                                                        vertical:
                                                                            2),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: colors
                                                                      .primaryLight
                                                                      .withOpacity(
                                                                          0.1),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                ),
                                                                child: TextWidget
                                                                    .paraText(
                                                                  text: "MARGIN",
                                                                  theme: false,
                                                                  color: colors
                                                                      .primaryLight,
                                                                  fw: 0,
                                                                ),
                                                              )
                                                            : const SizedBox
                                                                .shrink(),
                                                      ],
                                                    ),
                                                    TextWidget.subText(
                                                      align: TextAlign.right,
                                                      text: ledgerprovider
                                                                  .ledgerAllData!
                                                                  .fullStat![
                                                                      index]
                                                                  .cRAMT !=
                                                              "0.0"
                                                          ? "+${(double.tryParse(ledgerprovider.ledgerAllData!.fullStat![index].cRAMT ?? '')?.toStringAsFixed(2) ?? '0.00')}"
                                                          : " -${ledgerprovider.ledgerAllData!.fullStat![index].dRAMT}  ",
                                                      color: ledgerprovider
                                                                  .ledgerAllData!
                                                                  .fullStat![
                                                                      index]
                                                                  .cRAMT !=
                                                              "0.0"
                                                          ? colors.profit
                                                          : colors.loss,
                                                      textOverflow:
                                                          TextOverflow.ellipsis,
                                                      theme: theme.isDarkMode,
                                                      fw: 0,
                                                    ),
                                                  ],
                                                ),
                                              ),
                            
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4.0, bottom: 4.0),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        // CustomExchBadge(exch: "${ledgerprovider.ledgerAllData!.fullStat![index].tYPE}",),
                                                        TextWidget.paraText(
                                                            align:
                                                                TextAlign.right,
                                                            text:
                                                                "${ledgerprovider.ledgerAllData!.fullStat![index].cOCD}",
                                                            color: theme
                                                                    .isDarkMode
                                                                ? colors
                                                                    .textSecondaryDark
                                                                : colors
                                                                    .textSecondaryLight,
                                                            textOverflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            theme:
                                                                theme.isDarkMode,
                                                            fw: 0),
                            
                                                        TextWidget.paraText(
                                                            text:
                                                                " ${dateFormatChangeForLedger(ledgerprovider.ledgerAllData!.fullStat![index].vOUCHERDATE.toString())}",
                                                             color: theme
                                                                    .isDarkMode
                                                                ? colors
                                                                    .textSecondaryDark
                                                                : colors
                                                                    .textSecondaryLight,
                                                            textOverflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            theme:
                                                                theme.isDarkMode,
                                                            fw: 0),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        TextWidget.paraText(
                                                            align:
                                                                TextAlign.right,
                                                            text: "BAL ",
                                                            color: theme
                                                                    .isDarkMode
                                                                ? colors
                                                                    .textSecondaryDark
                                                                : colors
                                                                    .textSecondaryLight,
                                                            textOverflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            theme:
                                                                theme.isDarkMode,
                                                            fw: 0),
                                                        TextWidget.paraText(
                                                            align:
                                                                TextAlign.right,
                                                            text:
                                                                " ${(double.tryParse(ledgerprovider.ledgerAllData!.fullStat![index].nETAMT ?? '')?.toStringAsFixed(2) ?? '0.00')}",
                                                          color: theme
                                                                    .isDarkMode
                                                                ? colors
                                                                    .textSecondaryDark
                                                                : colors
                                                                    .textSecondaryLight,
                                                            textOverflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            theme:
                                                                theme.isDarkMode,
                                                            fw: 0),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                            
                                              // ledgerprovider
                                              //             .ledgerAllData!
                                              //             .fullStat![index]
                                              //             .billMargin ==
                                              //         'Yes'
                                              //     ? TextWidget.captionText(
                                              //         text: "Bill",
                                              //         theme: theme.isDarkMode,
                                              //       )
                                              //     : SizedBox(),
                                              // const SizedBox(height: 4),
                            
                                              // ledgerprovider.ledgerAllData!.fullStat![index].bill == 'Yes' ?
                            
                                              // Padding(
                                              //   padding: const EdgeInsets.only(top: 4.0),
                                              //   child: Column(
                                              //     crossAxisAlignment: CrossAxisAlignment
                                              //         .start, // Ensures left alignment
                                              //     mainAxisSize: MainAxisSize
                                              //         .min, // Prevents unnecessary centering
                                              //     children: [
                                              //       Align(
                                              //         alignment: Alignment
                                              //             .centerLeft, // Forces text to the left
                                              //         child: TextWidget.paraText(
                                              //             align: TextAlign.start,
                                              //             maxLines: 5,
                                              //             text:
                                              //                 "${ledgerprovider.ledgerAllData!.fullStat![index].nARRATION}",
                                              //             color: ledgerprovider
                                              //                             .ledgerAllData
                                              //                             ?.fullStat?[
                                              //                                 index]
                                              //                             .tYPE ==
                                              //                         'Bill' &&
                                              //                     ledgerprovider
                                              //                             .ledgerAllData
                                              //                             ?.fullStat?[
                                              //                                 index]
                                              //                             .bill ==
                                              //                         'Yes'
                                              //                 ? theme.isDarkMode
                                              //                     ? colors
                                              //                         .primaryDark
                                              //                     : colors
                                              //                         .primaryLight
                                              //                 : theme.isDarkMode
                                              //                     ? colors
                                              //                         .textSecondaryDark
                                              //                     : colors
                                              //                         .textSecondaryLight,
                                              //             textOverflow:
                                              //                 TextOverflow.ellipsis,
                                              //             theme: theme.isDarkMode,
                                              //             ),
                                              //       ),
                                              //     ],
                                              //   ),
                                              // ) : const SizedBox.shrink(),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    separatorBuilder:
                                        (BuildContext context, int index) {
                                      // if (index != 0 &&
                                      //     ledgerprovider.ledgerAllData!.fullStat![index - 1]
                                      //             .vOUCHERDATE ==
                                      //         ledgerprovider.ledgerAllData!
                                      //             .fullStat![index ].vOUCHERDATE) {
                                      return const ListDivider();
                                      // }else{
                                      // return SizedBox();
                                      // }
                                    },
                                  ),
                                ),
                              )
                      ],
                    ),
                ),
          ),
        ),
      );
    });
  }

 Widget downloadBottomSheet(BuildContext context, ThemesProvider theme, LDProvider ledgerprovider) {
  String selectedFormat = "PDF";

  return StatefulBuilder(
    builder: (context, setState) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextWidget.titleText(
                    text: "Download as",
                    theme: theme.isDarkMode,
                    fw: 1,
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () async {
                        await Future.delayed(const Duration(milliseconds: 150));
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      splashColor: theme.isDarkMode
                          ? colors.splashColorDark.withOpacity(0.15)
                          : colors.splashColorLight.withOpacity(0.15),
                      highlightColor: theme.isDarkMode
                          ? colors.splashColorDark.withOpacity(0.08)
                          : colors.splashColorLight.withOpacity(0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: !theme.isDarkMode
                              ? colors.colorGrey
                              : colors.colorWhite,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              /// Options (PDF / Excel) - Updated Icons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // PDF Option
                  InkWell(
                    onTap: () {
                          setState(() => selectedFormat = "PDF");
                          String currentDate = DateFormat("dd/MM/yyyy").format(DateTime.now()); 
                          ledgerprovider.pdfdownloadforledger( context, 
                          ledgerprovider .ledgerAllData ?.toJson() ?? {}, 
                          ledgerprovider.ledgerAllData ?.drAmt ?? '0.00', 
                          ledgerprovider.ledgerAllData ?.crAmt ?? '0.00', 
                          ledgerprovider.ledgerAllData ?.openingBalance ?? '0.00', 
                          ledgerprovider.ledgerAllData ?.closingBalance ?? '0.00', 
                          ledgerprovider.startDate, currentDate);
                        },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          SvgPicture.asset(assets.pdfIcon,
                            height: 50,
                            width: 50,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download, size: 16, color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight),
                              TextWidget.subText(
                                text: " PDF",
                                theme: theme.isDarkMode,
                                color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
                                fw: 0,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Excel Option
                  // InkWell(
                  //   onTap: () {
                  //         setState(() => selectedFormat = "Excel");
                  //         String currentDate = DateFormat("dd/MM/yyyy").format(DateTime.now()); 
                  //         ledgerprovider.pdfdownloadforledger( context, 
                  //         ledgerprovider .ledgerAllData ?.toJson() ?? {}, 
                  //         ledgerprovider.ledgerAllData ?.drAmt ?? '0.00', 
                  //         ledgerprovider.ledgerAllData ?.crAmt ?? '0.00', 
                  //         ledgerprovider.ledgerAllData ?.openingBalance ?? '0.00', 
                  //         ledgerprovider.ledgerAllData ?.closingBalance ?? '0.00', 
                  //         ledgerprovider.startDate, currentDate);
                  //       },
                  //   child: Padding(
                  //     padding: const EdgeInsets.all(8.0),
                  //     child: Column(
                  //       children: [
                  //         SvgPicture.asset(assets.excelIcon,
                  //           height: 60,
                  //           width: 60,
                  //           fit: BoxFit.contain,
                  //         ),
                  //         Row(
                  //           mainAxisAlignment: MainAxisAlignment.center,
                  //           children: [
                  //             Icon(Icons.download, size: 16, color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight),
                  //             TextWidget.subText(
                  //               text: " Excel",
                  //               theme: theme.isDarkMode,
                  //               color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
                  //               fw: 0,
                  //             ),
                  //           ],
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                ],
              ),
              const SizedBox(height: 30),

              // Download Button - Updated to handle both formats
              
            ],
          ),
        ),
      );
    },
  );
}



  _showBottomSheet(BuildContext context, Widget bottomSheet, ThemesProvider theme) {
    showModalBottomSheet(
        shape:  RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        useSafeArea: true,
        isDismissible: true,
        backgroundColor: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
        context: context,
        isScrollControlled: true,
        builder: (context) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: bottomSheet));
  }
}
