import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../provider/fund_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../provider/transcation_provider.dart';
import '../../../../res/global_state_text.dart';
import '../../../../res/res.dart';
import '../../../../routes/route_names.dart';
import '../../../../sharedWidget/functions.dart';

class SecureFund extends ConsumerStatefulWidget {
  const SecureFund({super.key});

  @override
  ConsumerState<SecureFund> createState() => _SecureFundState();
}

class _SecureFundState extends ConsumerState<SecureFund> {
  bool isAvailableCashExpanded = false;
  bool isMarginUsedExpanded = false;
  bool isCollateralExpanded = false;

  @override
  Widget build(BuildContext context) {
    final funds = ref.watch(fundProvider);
    final theme = ref.watch(themeProvider);
    final trancation = ref.watch(transcationProvider);

    return Container(
      color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          // Available Margin Section
          Container(
            color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 🔷 Top Text Section with full padding
                Padding(
                  padding: const EdgeInsets.all(
                      16), // Only this section gets full padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TextWidget.subText(
                          text: "Available Margin",
                          color: theme.isDarkMode
                              ? colors.textSecondaryDark
                              : colors.textSecondaryLight,
                          fw: 0,
                          theme: false),
                      const SizedBox(height: 8),
                      Text(
                        getFormatter(
                          value: double.parse(
                              "${funds.fundDetailModel?.avlMrg ?? 0.00}"),
                          v4d: false,
                          noDecimal: false,
                        ),
                        style: TextWidget.textStyle(
                          fontSize: 18,
                          theme: false,
                          color: theme.isDarkMode
                              ? colors.textPrimaryDark
                              : colors.textPrimaryLight,
                          fw: 0,
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔷 Button Row with border and horizontal padding only
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Add Fund Button
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: theme.isDarkMode
                                      ? colors.primaryDark
                                      : colors.primaryLight,
                                  width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              backgroundColor: theme.isDarkMode
                                  ? colors.primaryDark
                                  : colors.primaryLight,
                            ),
                            onPressed: () {
                              print('🔵 Add Money button pressed!');
                              // trancation.changebool(true);
                              Navigator.pushNamed(context, Routes.fundscreen,
                                  arguments: trancation);
                            },
                            child: TextWidget.subText(
                                text: "Add Money",
                                theme: false,
                                color: colors.colorWhite,
                                fw: 2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Withdraw Button
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: theme.isDarkMode
                                                          ? null : BorderSide(
                                  color: theme.isDarkMode
                                      ? colors.primaryLight
                                      : colors.primaryDark,
                                  width: 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              backgroundColor:   theme.isDarkMode
                                                          ? colors
                                                              .textSecondaryDark
                                                              .withOpacity(0.6)
                                                          : colors.fundbuttonBg,
                            ),
                            onPressed: () async {
                              print('🟢 Withdraw button pressed!');
                              await trancation.fetchValidateToken(context);
                              Future.delayed(
                                const Duration(milliseconds: 100),
                                () async {
                                  await trancation.ip();
                                  await trancation.fetchupiIdView(
                                    trancation.bankdetails!
                                        .dATA![trancation.indexss][1],
                                    trancation.bankdetails!
                                        .dATA![trancation.indexss][2],
                                  );
                                  await trancation.fetchcwithdraw(context);
                                },
                              );
                              trancation.changebool(false);
                              Navigator.pushNamed(
                                  context, Routes.withdrawscreen,
                                  arguments: trancation);
                            },
                            child: Text(
                              "Withdraw",
                              style: TextWidget.textStyle(
                                fontSize: 14,
                                theme: false,
                                color: theme.isDarkMode
                                    ? colors.colorWhite
                                    : colors.primaryLight,
                                fw: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: theme.isDarkMode ? colors.darkColorDivider : colors.colorDivider,),
              ],
            ),
          ),

          // Detailed Financial Information
          Container(
            color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
            child: Column(
              children: [
                // Available cash - Expandable
                _buildExpandableInfoRow(
                  "Available Capital",
                  getFormatter(
                      value: _safeParseDouble(
                          "${funds.fundDetailModel?.totCredit ?? 0.00}"),
                      v4d: false,
                      noDecimal: false),
                  theme,
                  isExpanded: isAvailableCashExpanded,
                  onTap: () {
                    setState(() {
                      isAvailableCashExpanded = !isAvailableCashExpanded;
                      isMarginUsedExpanded = false;
                    });
                  },
                  expandedContent: _buildAvailableCashContent(funds, theme),
                ),

                _buildExpandableInfoRow(
                  "Margin Used",
                  getFormatter(
                      value: double.parse(
                          "${funds.fundDetailModel?.utilizedMrgn ?? 0.00}"),
                      v4d: false,
                      noDecimal: false),
                  isExpanded: isMarginUsedExpanded,
                  onTap: () {
                    setState(() {
                      isMarginUsedExpanded = !isMarginUsedExpanded;
                      isAvailableCashExpanded = false;
                    });
                  },
                  expandedContent: _buildMarginUsedContent(funds, theme),
                  theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableInfoRow(
    String title,
    String value,
    ThemesProvider theme, {
    required bool isExpanded,
    required VoidCallback onTap,
    Widget? expandedContent,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    TextWidget.subText(
                        text: title,
                        theme: false,
                        color: theme.isDarkMode
                            ? colors.textSecondaryDark
                            : colors.textSecondaryLight,
                        fw: 0),
                  ],
                ),
                Row(
                  children: [
                    TextWidget.subText(
                        text: value,
                        theme: false,
                        color: theme.isDarkMode
                            ? colors.textPrimaryDark
                            : colors.textPrimaryLight,
                        fw: 0),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: theme.isDarkMode
                          ? colors.textSecondaryDark
                          : colors.textSecondaryLight,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && expandedContent != null) expandedContent,
        Divider(color: theme.isDarkMode ? colors.darkColorDivider : colors.colorDivider),
      ],
    );
  }

  Widget _buildAvailableCashContent(funds, theme) {
    // Only sublist if there is more than one item
    final filteredCredits = funds.listOfCredits.length > 1
        ? funds.listOfCredits
            .sublist(1)
            .where((item) =>
                item["name"] != "Collateral" &&
                item["name"] != "Opening Balance" &&
                item["name"] != "Payin")
            .toList()
        : [];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextWidget.subText(
                      text: "Cash Balance",
                      theme: false,
                      color: theme.isDarkMode
                          ? colors.textSecondaryDark
                          : colors.textSecondaryLight,
                      fw: 0),
                  TextWidget.subText(
                      text: getFormatter(
                          value: funds.listOfCredits.isNotEmpty
                              ? double.parse(
                                  "${funds.listOfCredits[0]["value"]}")
                              : 0.00,
                          v4d: false,
                          noDecimal: false),
                      theme: false,
                      color: theme.isDarkMode
                          ? colors.textPrimaryDark
                          : colors.textPrimaryLight,
                      fw: 0),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  color: theme.isDarkMode ? colors.darkColorDivider : colors.colorDivider,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextWidget.subText(
                    text: "Payin",
                    theme: false,
                    color: theme.isDarkMode
                        ? colors.textSecondaryDark
                        : colors.textSecondaryLight,
                    fw: 0,
                  ),
                  TextWidget.subText(
                    text:
                        getFormatter(value: _safeParseDouble("${funds.fundDetailModel?.payin ?? 0.00}"), v4d: false, noDecimal: false),
                    theme: false,
                    color: theme.isDarkMode
                        ? colors.textPrimaryDark
                        : colors.textPrimaryLight,
                    fw: 0,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  color: theme.isDarkMode ? colors.darkColorDivider : colors.colorDivider,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextWidget.subText(
                    text: "Collateral Equity",
                    theme: false,
                    color: theme.isDarkMode
                        ? colors.textSecondaryDark
                        : colors.textSecondaryLight,
                    fw: 0,
                  ),
                  TextWidget.subText(
                    text:
                        getFormatter(value: _safeParseDouble("${funds.pledgeAndUnpledgeModel?.noncashEquivalent ?? 0.00}"), v4d: false, noDecimal: false),
                    theme: false,
                    color: theme.isDarkMode
                        ? colors.textPrimaryDark
                        : colors.textPrimaryLight,
                    fw: 0,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  color: theme.isDarkMode ? colors.darkColorDivider : colors.colorDivider,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextWidget.subText(
                    text: "Collateral Liquid",
                    theme: false,
                    color: theme.isDarkMode
                        ? colors.textSecondaryDark
                        : colors.textSecondaryLight,
                    fw: 0,
                  ),
                  TextWidget.subText(
                    text:
                        getFormatter(value: _safeParseDouble("${funds.pledgeAndUnpledgeModel?.cashEquivalent ?? 0.00}"), v4d: false, noDecimal: false),
                    theme: false,
                    color: theme.isDarkMode
                        ? colors.textPrimaryDark
                        : colors.textPrimaryLight,
                    fw: 0,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  color: theme.isDarkMode ? colors.darkColorDivider : colors.colorDivider,
                ),
              ),
              (funds.fundDetailModel?.brkcollamt == null &&
                      funds.fundDetailModel?.brkcollamt != 0.00)
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextWidget.subText(
                          text: "Collateral Additional",
                          theme: false,
                          color: theme.isDarkMode
                              ? colors.textSecondaryDark
                              : colors.textSecondaryLight,
                          fw: 0,
                        ),
                        TextWidget.subText(
                          text:
                              getFormatter(value: _safeParseDouble("${funds.fundDetailModel?.brkcollamt ?? 0.00}"), v4d: false, noDecimal: false),
                          theme: false,
                          color: theme.isDarkMode
                              ? colors.textPrimaryDark
                              : colors.textPrimaryLight,
                          fw: 0,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
              filteredCredits.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                        color: theme.isDarkMode ? colors.darkColorDivider : colors.colorDivider,
                      ),
                    )
                  : const SizedBox.shrink(),
            ],
          ),
          if (funds.listOfCredits.isNotEmpty) ...[
            ListView.separated(
              padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredCredits.length,
                itemBuilder: (BuildContext context, int index) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextWidget.subText(
                          text: "${filteredCredits[index]["name"]}",
                          theme: false,
                          color: theme.isDarkMode
                              ? colors.textSecondaryDark
                              : colors.textSecondaryLight,
                          fw: 0),
                      TextWidget.subText(
                          text: getFormatter(
                              value: _safeParseDouble(
                                  "${filteredCredits[index]["value"]}"),
                              v4d: false,
                              noDecimal: false),
                          theme: false,
                          color: theme.isDarkMode
                              ? colors.textPrimaryDark
                              : colors.textPrimaryLight,
                          fw: 0),
                    ],
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: theme.isDarkMode ? colors.darkColorDivider : colors.colorDivider,
                        ),
                      ),
                    ],
                  );
                }),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildMarginUsedContent(funds, theme) {
    final filteredMargin = funds.listOfUsedMrgn.length > 1
        ? funds.listOfUsedMrgn
            .sublist(1)
            .where((item) =>
                item["name"] != "Span" &&
                item["name"] != "Exposure" &&
                item["name"] != "Option Premium" &&
                item["name"] != "Unrealized Expenses")
            .toList()
        : [];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          // Span, Exposure, Option Premium from listOfUsedMrgn

          // Unrealized Expenses

          buildPeakMarginInfo(
            isDarkMode: theme.isDarkMode,
            theme: theme,
            value: getFormatter(
                value:
                    _safeParseDouble("${funds.fundDetailModel?.span ?? 0.00}"),
                v4d: false,
                noDecimal: false),
            text: "Span",
          ),
          buildPeakMarginInfo(
            isDarkMode: theme.isDarkMode,
            theme: theme,
            value: getFormatter(
                value:
                    _safeParseDouble("${funds.fundDetailModel?.expo ?? 0.00}"),
                v4d: false,
                noDecimal: false),
            text: "Exposure",
          ),
          // The Limits response carries basket margin as `scripbskmrg`; the
          // `scripbskmar` key this row used to read is never sent, so the row
          // always printed 0.00 while the vendor showed the real figure.
          // value: _safeParseDouble("${funds.fundDetailModel?.scripbskmar ?? 0.00}"),
          buildPeakMarginInfo(
            isDarkMode: theme.isDarkMode,
            theme: theme,
            value: getFormatter(
                value: _safeParseDouble(
                    "${funds.fundDetailModel?.scripbskmrg ?? 0.00}"),
                v4d: false,
                noDecimal: false),
            text: "Basket Margin",
          ),
          buildPeakMarginInfo(
            isDarkMode: theme.isDarkMode,
            theme: theme,
            value: getFormatter(
                value: _safeParseDouble(
                    "${funds.fundDetailModel?.cobomargin ?? 0.00}"),
                v4d: false,
                noDecimal: false),
            text: "CO / BO Margin",
          ),
          buildPeakMarginInfo(
            isDarkMode: theme.isDarkMode,
            theme: theme,
            value: getFormatter(
                value: _safeParseDouble(
                    "${funds.fundDetailModel?.premium ?? 0.00}"),
                v4d: false,
                noDecimal: false),
            text: "Option Premium",
          ),
          buildPeakMarginInfo(
            isDarkMode: theme.isDarkMode,
            theme: theme,
            value: getFormatter(
                value: _safeParseDouble(
                    "${funds.fundDetailModel?.deliverySellBenefit ?? 0.00}"),
                v4d: false,
                noDecimal: false),
            text: "Delivery Sell Benefit",
          ),
          buildPeakMarginInfo(
            isDarkMode: theme.isDarkMode,
            theme: theme,
            value: getFormatter(
                value: _safeParseDouble(
                    "${funds.fundDetailModel?.brokerage ?? 0.00}"),
                v4d: false,
                noDecimal: false),
            text: "Unrealized Expenses",
          ),

          if (funds.listOfUsedMrgn.isNotEmpty) ...[
            ListView.separated(
              padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredMargin.length,
                itemBuilder: (BuildContext context, int index) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextWidget.subText(
                              text: "${filteredMargin[index]["name"]}",
                              theme: false,
                              color: theme.isDarkMode
                                  ? colors.textSecondaryDark
                                  : colors.textSecondaryLight,
                              fw: 3),
                          TextWidget.subText(
                              text: getFormatter(
                                  value: _safeParseDouble(
                                      "${filteredMargin[index]["value"]}"),
                                  v4d: false,
                                  noDecimal: false),
                              theme: false,
                              color: theme.isDarkMode
                                  ? colors.textPrimaryDark
                                  : colors.textPrimaryLight,
                              fw: 3),
                        ]),
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return Divider(
                    color: theme.isDarkMode ? colors.darkColorDivider : colors.colorDivider,
                  );
                }),
            Divider(
              color: theme.isDarkMode ? colors.darkColorDivider : colors.colorDivider,
            ),
          ],

          // Peak Margin
          // Container(
          //   padding: const EdgeInsets.symmetric(vertical: 12),
          //   child: Row(
          //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //       children: [
          //         TextWidget.subText(
          //             text: "Peak Margin",
          //             theme: false,
          //             color: theme.isDarkMode
          //                 ? colors.textSecondaryDark
          //                 : colors.textSecondaryLight,
          //             fw: 3),
          //         TextWidget.subText(
          //             text: getFormatter(
          //                 value: double.parse(
          //                     "${funds.fundDetailModel?.peakMar ?? 0.00}"),
          //                 v4d: false,
          //                 noDecimal: false),
          //             theme: false,
          //             color: theme.isDarkMode
          //                 ? colors.textPrimaryDark
          //                 : colors.textPrimaryLight,
          //             fw: 3),
          //       ]),
          // ),
          // Divider(
          //   color: colors.colorDivider.withOpacity(0.5),
          // ),

          // Expiry Margin
          // Container(
          //   padding: const EdgeInsets.symmetric(vertical: 12),
          //   child: Row(
          //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //       children: [
          //         TextWidget.subText(
          //             text: "Expiry Margin",
          //             theme: false,
          //             color: theme.isDarkMode
          //                 ? colors.textSecondaryDark
          //                 : colors.textSecondaryLight,
          //             fw: 3),
          //         TextWidget.subText(
          //             text: getFormatter(
          //                 value: double.parse(
          //                     "${funds.fundDetailModel?.expiryMar ?? 0.00}"),
          //                 v4d: false,
          //                 noDecimal: false),
          //             theme: false,
          //             color: theme.isDarkMode
          //                 ? colors.textPrimaryDark
          //                 : colors.textPrimaryLight,
          //             fw: 3),
          //       ]),
          // ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget buildPeakMarginInfo({
    required dynamic value,
    required String text,
    required bool isDarkMode,
    required ThemesProvider theme,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextWidget.subText(
                text: text,
                theme: false,
                color: isDarkMode
                    ? colors.textSecondaryDark
                    : colors.textSecondaryLight,
                fw: 0,
              ),
              TextWidget.subText(
                text: value,
                theme: false,
                color: isDarkMode
                    ? colors.textPrimaryDark
                    : colors.textPrimaryLight,
                fw: 0,
              ),
            ],
          ),
        ),
        Divider(
          color: theme.isDarkMode ? colors.darkColorDivider : colors.colorDivider,
        ),
      ],
    );
  }

  Row rowOfInfoData(
      String title1, String value1, String title2, String value2) {
    return Row(children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextWidget.paraText(
            text: title1, theme: false, color: const Color(0xff666666), fw: 0),
        const SizedBox(height: 3),
        TextWidget.subText(
            text: value1, theme: false, color: const Color(0xff000000), fw: 0),
        const SizedBox(height: 2),
        Divider(color: colors.colorDivider.withOpacity(0.5))
      ])),
      const SizedBox(width: 24),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextWidget.paraText(
            text: title2, theme: false, color: const Color(0xff666666), fw: 0),
        const SizedBox(height: 3),
        TextWidget.subText(
            text: value2, theme: false, color: const Color(0xff000000), fw: 0),
        const SizedBox(height: 2),
        Divider(color: colors.colorDivider.withOpacity(0.5))
      ]))
    ]);
  }

  double _safeParseDouble(String value) {
    try {
      if (value.isEmpty || value == "null" || value == "undefined") {
        return 0.0;
      }
      return double.parse(value);
    } catch (e) {
      return 0.0;
    }
  }
}

class ChartData {
  ChartData(this.x, this.y, this.color);
  final String x;
  final double y;
  final Color color;
}
