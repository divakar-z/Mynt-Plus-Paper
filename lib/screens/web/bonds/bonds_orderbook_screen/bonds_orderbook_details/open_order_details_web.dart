// ignore_for_file: prefer_is_empty, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/models/bonds_model/bonds_order_book_model.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/screens/Mobile/bonds/bonds_orderbook_screen/bond_cancel_alert/bonds_cancel_alert.dart';
import '../../../../../res/global_state_text.dart';
import '../../../../../res/res.dart';
import '../../../../../sharedWidget/custom_drag_handler.dart';
import '../../../../../sharedWidget/functions.dart';

Widget data(String name, String value, ThemesProvider theme) {
  return Column(
    children: [
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextWidget.subText(
            text: name,
            theme: theme.isDarkMode,
            color: theme.isDarkMode
                ? colors.textSecondaryDark
                : colors.textSecondaryLight,
          ),
          SizedBox(
            width: 200,
            child: TextWidget.subText(
              text: value,
              theme: theme.isDarkMode,
              color: theme.isDarkMode
                  ? colors.textPrimaryDark
                  : colors.textPrimaryLight,
              align: TextAlign.right,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Divider(
        thickness: 0,
        color: theme.isDarkMode ? colors.dividerDark : colors.dividerLight,
      )
    ],
  );
}

class BondsOpenOrderDetailsWeb extends ConsumerWidget {
  final BondsOrderBookModel bondsdetails;
  const BondsOpenOrderDetailsWeb({
    super.key,
    required this.bondsdetails,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);

    return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.05,
        maxChildSize: 0.99,
        builder: (context, scrollController) {
          return Consumer(
            builder: (context, ref, _) {
              return SafeArea(
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  // appBar: _buildAppBar(context, theme),
                  body: Container(
                  decoration: BoxDecoration(
                           borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                         color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
                         border: Border(
                                    top: BorderSide(
                                      color: theme.isDarkMode
                                          ? colors.textSecondaryDark
                                              .withOpacity(0.5)
                                          : colors.colorWhite,
                                    ),
                                    left: BorderSide(
                                      color: theme.isDarkMode
                                          ? colors.textSecondaryDark
                                              .withOpacity(0.5)
                                          : colors.colorWhite,
                                    ),
                                    right: BorderSide(
                                      color: theme.isDarkMode
                                          ? colors.textSecondaryDark
                                              .withOpacity(0.5)
                                          : colors.colorWhite,
                                    ),
                                  ),
                
                         
                        ),
                    child: Column(
                      children: [
                        const CustomDragHandler(),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            controller: scrollController,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                
                                _HeaderSection(
                                    bondsdetails: bondsdetails, theme: theme),
                                    
                                // Divider(
                                //   height: 0,
                                //   color: theme.isDarkMode
                                //       ? colors.darkColorDivider
                                //       : colors.colorDivider,
                                // ),
                
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16),
                                  child: _OrderDetailsSection(
                                      bondsdetails: bondsdetails, theme: theme),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16),
                                  child: _ReasonSection(
                                      bondsdetails: bondsdetails, theme: theme),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16),
                                  child: _BidDetailsSection(
                                      bondsdetails: bondsdetails, theme: theme),
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
            },
          );
        });
  }

  AppBar _buildAppBar(BuildContext context, ThemesProvider theme) {
    return AppBar(
      elevation: .2,
      centerTitle: false,
      titleSpacing: -8,
      leading: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: InkWell(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              Icons.arrow_back_ios,
              color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
              size: 22,
            ),
          ),
        ),
      ),
      backgroundColor: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
      // shadowColor: const Color(0xffECEFF3),
      title: Text(
        "Order Details",
        style: _textStyle(
          theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
          16,
          FontWeight.w600,
        ),
      ),
    );
  }

  static TextStyle _textStyle(
      Color color, double fontSize, FontWeight fWeight) {
    return dysInter(
      textStyle: TextStyle(
        fontWeight: fWeight,
        color: color,
        fontSize: fontSize,
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final BondsOrderBookModel bondsdetails;
  final ThemesProvider theme;

  const _HeaderSection({
    required this.bondsdetails,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SymbolInfo(bondsdetails: bondsdetails, theme: theme),
            _CancelOrderButton(
                                  bondsdetails: bondsdetails, theme: theme),
          // const SizedBox(height: 16),
          _OrderIdRow(bondsdetails: bondsdetails, theme: theme),
          // const SizedBox(height: 16),
          _PaymentStatusRow(bondsdetails: bondsdetails, theme: theme),
        ],
      ),
    );
  }
}

class _SymbolInfo extends StatelessWidget {
  final BondsOrderBookModel bondsdetails;
  final ThemesProvider theme;

  const _SymbolInfo({
    required this.bondsdetails,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text(
            //   bondsdetails.symbol.toString(),
            //   style: textStyles.scripNameTxtStyle.copyWith(
            //     color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
            //   ),
            // ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextWidget.titleText(
                text: bondsdetails.symbol.toString(),
                theme: theme.isDarkMode,
                color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                fw: 1,
              ),
            ),

            // const SizedBox(height: 5),
            // Text(
            //   bondsdetails.symbol.toString(),
            //   style: textStyles.scripExchTxtStyle,
            // ),
          ],
        ),
      ],
    );
  }
}

class _OrderIdRow extends StatelessWidget {
  final BondsOrderBookModel bondsdetails;
  final ThemesProvider theme;

  const _OrderIdRow({
    required this.bondsdetails,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              data(
                "Order Id",
                bondsdetails.applicationNumber != ""
                    ? bondsdetails.applicationNumber.toString()
                    : " - ",
                theme,
              ),
              Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextWidget.subText(
                        text: "Order Status",
                        theme: theme.isDarkMode,
                        color: theme.isDarkMode
                            ? colors.textSecondaryDark
                            : colors.textSecondaryLight,
                      ),
                      _StatusBadge(bondsdetails: bondsdetails, theme: theme),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    thickness: 0,
                    color: theme.isDarkMode
                        ? colors.dividerDark
                        : colors.dividerLight,
                  )
                ],
              ),

              //     Text.rich(
              //       TextSpan(
              //         children: [
              //           TextSpan(
              //             text: "Order Id : ",
              //             style: BondsOpenOrderDetails._textStyle(
              //               colors.colorGrey,
              //               14,
              //               FontWeight.w600,
              //             ),
              //           ),
              //           TextSpan(
              //             text: bondsdetails.applicationNumber != ""
              //                 ? bondsdetails.applicationNumber.toString()
              //                 : " - ",
              //             style: BondsOpenOrderDetails._textStyle(
              //               theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
              //               12,
              //               FontWeight.w600,
              //             ),
              //           ),
              //         ],
              //       ),
              //     ),
              //   ],
              // ),
              // _StatusBadge(bondsdetails: bondsdetails, theme: theme),
            ],
          )
        ]);
  }
}

class _StatusBadge extends StatelessWidget {
  final BondsOrderBookModel bondsdetails;
  final ThemesProvider theme;

  const _StatusBadge({
    required this.bondsdetails,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = bondsdetails.reponseStatus == "success";

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSuccess
                ? theme.isDarkMode ? colors.profitDark.withOpacity(0.1) : colors.profitLight.withOpacity(0.1)
                : theme.isDarkMode ? colors.pending.withOpacity(0.1) : colors.pending.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextWidget.paraText(
            text: isSuccess ? "Success" : "Pending",
            theme: false,
            color: isSuccess ? theme.isDarkMode ? colors.profitDark : colors.profitLight : theme.isDarkMode ? colors.pending : colors.pending,
          ),
        ),

        // SvgPicture.asset(
        //   isSuccess ? "assets/icon/success.svg" : "assets/icon/pendingicon.svg",
        // ),
        // const SizedBox(width: 4),
        // Text(
        //   isSuccess ? "Success" : "Pending",
        //   style: BondsOpenOrderDetails._textStyle(
        //     theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
        //     14,
        //     FontWeight.w600,
        //   ),
        // ),
      ],
    );
  }
}

class _PaymentStatusRow extends StatelessWidget {
  final BondsOrderBookModel bondsdetails;
  final ThemesProvider theme;

  const _PaymentStatusRow({
    required this.bondsdetails,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // final isEmpty = bondsdetails.clearingStatus == "";

    return Column(
      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextWidget.subText(
              text: "Payment",
              theme: theme.isDarkMode,
              color: theme.isDarkMode
                  ? colors.textSecondaryDark
                  : colors.textSecondaryLight,
            ),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bondsdetails.clearingStatus.toString() == "Allotted"
                        ? theme.isDarkMode ? colors.profitDark.withOpacity(0.1) : colors.profitLight.withOpacity(0.1)
                        : bondsdetails.clearingStatus.toString() ==
                                "Fund Pending"
                            ? colors.pending.withOpacity(0.1)
                            : theme.isDarkMode ? colors.lossDark.withOpacity(0.1) : colors.lossLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: TextWidget.paraText(
                    text: bondsdetails.clearingStatus.toString() == "Allotted"
                        ? "Success"
                        : bondsdetails.clearingStatus.toString() ==
                                "Fund Pending"
                            ? "Pending"
                            : "Failed",
                    theme: false,
                    color: bondsdetails.clearingStatus.toString() == "Allotted"
                        ?  theme.isDarkMode ?   colors.profitDark : colors.profitLight
                        : bondsdetails.clearingStatus.toString() ==
                                "Fund Pending"
                            ? theme.isDarkMode ? colors.pending : colors.pending
                            : theme.isDarkMode ? colors.lossDark : colors.lossLight,
                  ),
                ),
              ],
            )
          ],
        ),
        // Row(
        //   children: [
        //     SvgPicture.asset(
        //       isPending
        //           ? "assets/icon/pendingicon.svg"
        //           : "assets/icon/success.svg",
        //     ),
        //     const SizedBox(width: 4),
        //     Text(
        //       isPending ? "Pending" : bondsdetails.clearingStatus.toString(),
        //       style: BondsOpenOrderDetails._textStyle(
        //         theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
        //         14,
        //         FontWeight.w600,
        //       ),
        //     ),
        //   ],
        // ),
        const SizedBox(height: 8),
        Divider(
          thickness: 0,
          color: theme.isDarkMode ? colors.dividerDark : colors.dividerLight,
        )
      ],
    );
  }
}

class _ReasonSection extends StatelessWidget {
  final BondsOrderBookModel bondsdetails;
  final ThemesProvider theme;

  const _ReasonSection({
    required this.bondsdetails,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return data(
      "Reason",
      bondsdetails.failReason == ""
          ? "Order placed successfully"
          : bondsdetails.failReason.toString(),
      theme,
    );
  }
}

class _CancelOrderButton extends StatelessWidget {
  final BondsOrderBookModel bondsdetails;
  final ThemesProvider theme;

  const _CancelOrderButton({
    required this.bondsdetails,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding:
            const EdgeInsets.only( top: 16, bottom: 16),
        child: Row(children: [
          Expanded(
              child: Row(
            children: [
              Expanded(
                child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                        border: theme.isDarkMode
                          ? null :  Border.all(
                       color: colors.primaryLight,
                          width: 1,
                        ),
                        color: theme.isDarkMode
                          ? colors.textSecondaryDark.withOpacity(0.6)
                          : colors.btnBg,
                        borderRadius: BorderRadius.circular(5)),
                    child: Material(
                      color: Colors.transparent,
                      shape: const BeveledRectangleBorder(),
                      child: InkWell(
                        customBorder: const BeveledRectangleBorder(),
                        splashColor: theme.isDarkMode
                            ? colors.splashColorDark
                            : colors.splashColorLight,
                        highlightColor: theme.isDarkMode
                            ? colors.highlightDark
                            : colors.highlightLight,
                        onTap: () => _showCancelDialog(context),
                        child: Center(
                          child: TextWidget.subText(
                              text: "Cancel Order",
                              theme: false,
                              color: theme.isDarkMode
                          ? colors.colorWhite
                          : colors.primaryLight,
                              fw: 2),
                        ),
                      ),
                    )),

                // child: OutlinedButton(

                //   style: OutlinedButton.styleFrom(
                //     side: BorderSide(
                //       width: 1.4,
                //       color:
                //           theme.isDarkMode ? colors.colorGrey : colors.colorBlack,
                //     ),
                //     padding: const EdgeInsets.symmetric(vertical: 9),
                //     shape: const RoundedRectangleBorder(
                //       borderRadius: BorderRadius.all(Radius.circular(30)),
                //     ),
                //   ),
                //   child: Padding(
                //     padding: const EdgeInsets.symmetric(horizontal: 20),
                //     child: Text(
                //       "Cancel Order",
                //       style: BondsOpenOrderDetails._textStyle(
                //         theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                //         14,
                //         FontWeight.w600,
                //       ),
                //     ),
                //   ),
                // ),
              ),
            ],
          ))
        ]));
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BondCancelAlert(bondcancel: bondsdetails);
      },
    );
  }
}

class _OrderDetailsSection extends StatelessWidget {
  final BondsOrderBookModel bondsdetails;
  final ThemesProvider theme;

  const _OrderDetailsSection({
    required this.bondsdetails,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // _buildDetailRow(
        //     "Order no",
        //     bondsdetails.orderNumber != null
        //         ? bondsdetails.orderNumber!.toString()
        //         : " - ",
        //     theme),

       

        // _buildDetailRow(
        //     "Quantity",
        //     "${(double.parse(bondsdetails.totalAmountPayable!) / bondsdetails.bidDetail!.price!).toStringAsFixed(0)}",
        //     theme),

        data(
          "Quantity",
          (double.parse(bondsdetails.totalAmountPayable!) / bondsdetails.bidDetail!.price!).toStringAsFixed(0),
          theme,
        ),

        // _buildDetailRow("Price", "${bondsdetails.bidDetail!.price!}", theme),

        data(
          "Price",
          "${bondsdetails.bidDetail!.price!}",
          theme,
        ),

        // _buildDetailRow(
        //     "Total amount",
        //     "₹${getFormatter(
        //       noDecimal: true,
        //       v4d: false,
        //       value: double.parse(bondsdetails.totalAmountPayable!.toString())
        //           .toDouble(),
        //     )}",
        //     theme),

        data(
          "Total amount",
          "₹${getFormatter(
            noDecimal: true,
            v4d: false,
            value: double.parse(bondsdetails.totalAmountPayable!.toString())
                .toDouble(),
          )}",
          theme,
        ),
         data(
          "Order no",
          bondsdetails.orderNumber != null
              ? bondsdetails.orderNumber!.toString()
              : " - ",
          theme,
        ),

        data(
          "Bid Date & Time",
          bondsdetails.responseDatetime.toString() == ""
              ? "----"
              : ipodateres(bondsdetails.responseDatetime.toString()),
          theme,
        ),

        // _buildDetailRow(
        //     "Bid Date & Time",
        //     bondsdetails.responseDatetime.toString() == ""
        //         ? "----"
        //         : ipodateres(bondsdetails.responseDatetime.toString()),
        //     theme),
      ],
    );
  }

  // Widget _buildDetailRow(String name, String value, ThemesProvider theme) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     child: Column(
  //       children: [
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Text(
  //               name,
  //               style: BondsOpenOrderDetails._textStyle(
  //                 theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
  //                 14,
  //                 FontWeight.w600,
  //               ),
  //             ),
  //             Text(
  //               value,
  //               style: BondsOpenOrderDetails._textStyle(
  //                 theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
  //                 12,
  //                 FontWeight.w500,
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 8),
  //         Divider(
  //           height: 0,
  //           color: theme.isDarkMode
  //               ? colors.darkColorDivider
  //               : colors.colorDivider,
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

class _BidDetailsSection extends StatelessWidget {
  final BondsOrderBookModel bondsdetails;
  final ThemesProvider theme;

  const _BidDetailsSection({
    required this.bondsdetails,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 0, top: 16, bottom: 8),
          child: TextWidget.subText(
            text: "Bid order Details",
            theme: theme.isDarkMode,
            color: theme.isDarkMode
                ? colors.textPrimaryDark
                : colors.textPrimaryLight,
            fw: 0,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TextWidget.paraText(
            //   text: "Bid Details",
            //   theme: false,
            //   color: colors.colorGrey,
            //   fw: 0,
            // ),
            _BidDetailsTable(bondsdetails: bondsdetails, theme: theme),
          ],
        ),
      ],
    );
  }
}

class _BidDetailsTable extends StatelessWidget {
  final BondsOrderBookModel bondsdetails;
  final ThemesProvider theme;

  const _BidDetailsTable({
    required this.bondsdetails,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Theme(
        data: Theme.of(context).copyWith(
          cardColor: Colors.transparent,
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
          ),
          dataTableTheme: const DataTableThemeData(
            headingTextStyle: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            dataTextStyle: TextStyle(color: Colors.white),
            dividerThickness: 1.0,
          ),
        ),
        child: DataTable(
          columnSpacing: 16.0,
          horizontalMargin: 0,
          headingRowHeight: 40.0,
          border: const TableBorder(
            horizontalInside: BorderSide(color: Colors.white54, width: 0.8),
          ),
          columns: [
            DataColumn(
              label: TextWidget.subText(
                text: "Qty",
                theme: theme.isDarkMode,
                color: theme.isDarkMode
                    ? colors.textPrimaryDark
                    : colors.textPrimaryLight,
              ),
            ),
            DataColumn(
              label: TextWidget.subText(
                text: "Price",
                theme: theme.isDarkMode,
                color: theme.isDarkMode
                    ? colors.textPrimaryDark
                    : colors.textPrimaryLight,
              ),
            ),
            DataColumn(
              label: TextWidget.subText(
                text: "Amount",
                theme: theme.isDarkMode,
                color: theme.isDarkMode
                    ? colors.textPrimaryDark
                    : colors.textPrimaryLight,
              ),
            ),
          ],
          rows: [
            DataRow(cells: [
              DataCell(
                TextWidget.paraText(
                  text:
                      (double.parse(bondsdetails.totalAmountPayable!) / bondsdetails.bidDetail!.price!).toStringAsFixed(0),
                  theme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? colors.textSecondaryDark
                      : colors.textSecondaryLight,
                ),
              ),
              DataCell(
                TextWidget.paraText(
                  text: "${bondsdetails.bidDetail!.price!}",
                  theme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? colors.textSecondaryDark
                      : colors.textSecondaryLight,
                ),
              ),
              DataCell(
                TextWidget.paraText(
                  text: "₹${getFormatter(
                    noDecimal: true,
                    v4d: false,
                    value: double.parse(bondsdetails.totalAmountPayable!),
                  )}",
                  theme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? colors.textSecondaryDark
                      : colors.textSecondaryLight,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
