import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

// COMMENTED OUT: No longer using dialog screens, redirecting to external URLs instead
// import 'fund_screen_web.dart';
// import 'withdraw_screen_web.dart';

import '../../../locator/locator.dart';
import '../../../locator/preference.dart';
import '../../../provider/fund_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/transcation_provider.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../sharedWidget/functions.dart';
import '../../../sharedWidget/snack_bar.dart';
import '../profile/fund_screen/fund_screen.dart';
import '../profile/fund_screen/withdraw/withdraw_screen.dart';
import '../profile/fund_screen/mtf/mtf_transfer_screen.dart';
import '../profile/fund_screen/transaction_history_screen.dart';

class SecureFundWeb extends ConsumerStatefulWidget {
  final String? initialAction;
  const SecureFundWeb({super.key, this.initialAction});

  @override
  ConsumerState<SecureFundWeb> createState() => _SecureFundWebState();
}

class _SecureFundWebState extends ConsumerState<SecureFundWeb> {
  bool _showAddMoney = false;
  bool _showWithdraw = false;
  bool _showMtf = false;
  bool _showTransactionHistory = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.initialAction == 'addMoney') {
          _openAddMoney();
        } else if (widget.initialAction == 'withdraw') {
          _openWithdraw();
        }
      });
    }
  }

  void _openAddMoney() {
    final trancation = ref.read(transcationProvider);
    // Ensure bank details and client data are fetched
    if (trancation.bankdetails == null) {
      trancation.fetchfundbanks(context);
    }
    if (trancation.decryptclientcheck == null) {
      trancation.fetchc(context);
    }
    setState(() {
      _showAddMoney = true;
    });
  }

  void _openWithdraw() async {
    final trancation = ref.read(transcationProvider);
    // Ensure bank details and client data are fetched
    if (trancation.bankdetails == null) {
      trancation.fetchfundbanks(context);
    }
    if (trancation.decryptclientcheck == null) {
      trancation.fetchc(context);
    }
    await trancation.fetchValidateToken(context);
    Future.delayed(
      const Duration(milliseconds: 100),
      () async {
        await trancation.ip();
        await trancation.fetchupiIdView(
          trancation.bankdetails!.dATA![trancation.indexss][1],
          trancation.bankdetails!.dATA![trancation.indexss][2],
        );
        await trancation.fetchcwithdraw(context);
      },
    );
    trancation.changebool(false);
    setState(() {
      _showWithdraw = true;
    });
  }

  /// Opens the fund management page in a new window
  /// Similar to Vue.js function: openFunds(pageis)
  ///
  /// @param pageis - 'fund' for add money, or 'withdraw' for withdraw page
  void openFunds(String pageis, BuildContext context) {
    if (!kIsWeb) {
      showResponsiveWarningMessage(
          context, "This feature is only available on web");
      return;
    }

    try {
      final pref = locator<Preferences>();
      String? uid = pref.clientId;
      String? stoken = pref.token;

      // Check if credentials are missing
      if (uid == null || uid.isEmpty || stoken == null || stoken.isEmpty) {
        showResponsiveWarningMessage(context, "Please login to continue");
        return;
      }

      // Construct URL based on page type
      String url;
      if (pageis == 'fund') {
        url = 'https://fund.zebuetrade.com?uid=$uid&token=$stoken';
      } else if (pageis == 'mtf') {
        url = 'https://fund.zebuetrade.com/mtf?uid=$uid&token=$stoken';
      } else {
        url = 'https://fund.zebuetrade.com/withdrawal?uid=$uid&token=$stoken';
      }
      html.window.open(url, '_blank');
    } catch (e) {
      showResponsiveWarningMessage(
          context, "Error opening fund page. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final funds = ref.watch(fundProvider);
    final theme = ref.watch(themeProvider);
    final trancation = ref.watch(transcationProvider);

    if (_showAddMoney) {
      return FundScreen(
        dd: trancation,
        onBack: () {
          setState(() {
            _showAddMoney = false;
          });
        },
        onViewTransactions: () {
          setState(() {
            _showAddMoney = false;
            _showTransactionHistory = true;
          });
        },
      );
    }

    if (_showWithdraw) {
      return WithdrawScreen(
        withdarw: trancation,
        foucs: trancation.focusNode,
        theme: theme,
        segment: trancation.textValue,
        onBack: () {
          setState(() {
            _showWithdraw = false;
          });
        },
      );
    }

    if (_showMtf) {
      return MtfTransferScreen(
        onBack: () {
          setState(() {
            _showMtf = false;
          });
        },
      );
    }

    if (_showTransactionHistory) {
      return TransactionHistoryScreen(
        onBack: () {
          setState(() {
            _showTransactionHistory = false;
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: resolveThemeColor(
        context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 800;
          final hPadding = isSmallScreen ? 16.0 : 24.0;

          return SingleChildScrollView(
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: hPadding, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Available Margin Card
                  _buildAvailableMarginCard(
                      funds, theme, trancation, isSmallScreen),
                  const SizedBox(height: 24),

                  // Financial Information Cards
                  _buildFinancialInfoCards(funds, theme, isSmallScreen),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection(funds, ThemesProvider theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            ref.read(fundProvider).fetchFunds(context);
          },
          icon: Icon(
            Icons.refresh,
            color: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
          ),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildAvailableMarginCard(
      funds, ThemesProvider theme, trancation, bool isSmallScreen) {
    return shadcn.Theme(
      data: shadcn.Theme.of(context).copyWith(radius: () => 0.3),
      child: shadcn.Card(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Left side: Available Margin label and value
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Available Margin",
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary,
                        ),
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Builder(
                      builder: (context) {
                        final marginValue = double.parse(
                            "${funds.fundDetailModel?.avlMrg ?? 0.00}");
                        final Color marginColor = marginValue > 0
                            ? resolveThemeColor(
                                context,
                                dark: MyntColors.profitDark,
                                light: MyntColors.profit,
                              )
                            : marginValue < 0
                                ? resolveThemeColor(
                                    context,
                                    dark: MyntColors.errorDark,
                                    light: MyntColors.tertiary,
                                  )
                                : resolveThemeColor(
                                    context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary,
                                  );
                        return Text(
                          getFormatter(
                            value: marginValue,
                            v4d: false,
                            noDecimal: false,
                          ),
                          style: MyntWebTextStyles.head(
                            context,
                            color: marginColor,
                            fontWeight: MyntFonts.medium,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Right side: Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MyntPrimaryButton(
                    label: "Add Money",
                    isFullWidth: false,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    onPressed: () {
                      _openAddMoney();
                    },
                  ),
                  const SizedBox(width: 12),
                  MyntOutlinedButton(
                    label: "Withdraw",
                    isFullWidth: false,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    onPressed: () {
                      _openWithdraw();
                    },
                  ),
                  const SizedBox(width: 12),
                  MyntOutlinedButton(
                    label: "Transfer to MTF",
                    isFullWidth: false,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    onPressed: () {
                      setState(() {
                        _showMtf = true;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Action button helper has been replaced by MyntPrimaryButton and MyntOutlinedButton from common_buttons_web.dart

  Widget _buildFinancialInfoCards(
      funds, ThemesProvider theme, bool isSmallScreen) {
    final content = isSmallScreen
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: "Available Capital",
                value: "${funds.fundDetailModel?.totCredit ?? 0.00}",
                content: _buildAvailableCashContent(funds, theme),
                context: context,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.dividerDark,
                    light: MyntColors.divider,
                  ),
                  height: 1,
                ),
              ),
              _buildSection(
                title: "Margin Used",
                value: "${funds.fundDetailModel?.utilizedMrgn ?? 0.00}",
                content: _buildMarginUsedContent(funds, theme),
                context: context,
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildSection(
                  title: "Available Capital",
                  value: "${funds.fundDetailModel?.totCredit ?? 0.00}",
                  content: _buildAvailableCashContent(funds, theme),
                  context: context,
                ),
              ),
              Container(
                width: 0.5,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.dividerDark,
                  light: MyntColors.divider,
                ),
              ),
              Expanded(
                child: _buildSection(
                  title: "Margin Used",
                  value: "${funds.fundDetailModel?.utilizedMrgn ?? 0.00}",
                  content: _buildMarginUsedContent(funds, theme),
                  context: context,
                ),
              ),
            ],
          );

    return IntrinsicHeight(
      child: Container(
        decoration: BoxDecoration(
          color: resolveThemeColor(
            context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor,
          ),
          borderRadius: BorderRadius.circular(0),
          border: Border.all(
            color: resolveThemeColor(
              context,
              dark: MyntColors.dividerDark,
              light: MyntColors.divider,
            ),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: content,
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String value,
    required Widget content,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                  fontWeight: MyntFonts.medium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                getFormatter(
                  value: double.tryParse(value) ?? 0.00,
                  v4d: false,
                  noDecimal: false,
                ),
                style: MyntWebTextStyles.title(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.semiBold,
                ),
              ),
            ],
          ),
        ),
        content,
      ],
    );
  }

  Widget _buildAvailableCashContent(funds, theme) {
    final filteredCredits = funds.listOfCredits.length > 1
        ? funds.listOfCredits
            .sublist(1)
            .where((item) =>
                item["name"] != "Collateral" &&
                item["name"] != "Opening Balance" &&
                item["name"] != "Payin")
            .toList()
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cash Balance
        _buildInfoRow(
          "Cash Balance",
          getFormatter(
            value: funds.listOfCredits.isNotEmpty
                ? double.parse("${funds.listOfCredits[0]["value"]}")
                : 0.00,
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // Payin
        _buildInfoRow(
          "Payin",
          getFormatter(
            value: _safeParseDouble("${funds.fundDetailModel?.payin ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // Collateral Equity
        _buildInfoRow(
          "Collateral Equity",
          getFormatter(
            value:_safeParseDouble("${funds.fundDetailModel?.collateral ?? 0.00}") - _safeParseDouble("${funds.fundDetailModel?.cashcoll ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // Collateral Liquid
        _buildInfoRow(
          "Collateral Liquid",
          getFormatter(
            value: _safeParseDouble(
                "${funds.fundDetailModel?.cashcoll ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // // Collateral Cash
        if(funds.fundDetailModel?.brkcollamt != "0.00" && funds.fundDetailModel?.brkcollamt != null)...[
        _buildInfoRow(
          "Collateral MF",
          getFormatter(
            value: _safeParseDouble(
                "${funds.fundDetailModel?.brkcollamt ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),
        ],

        // Peak Margin
        _buildInfoRow(
          "Peak Margin",
          getFormatter(
            value: _safeParseDouble("${funds.fundDetailModel?.peakMar ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // Collateral Additional (conditional)
        // if (funds.fundDetailModel?.brkcollamt != null &&
        //     funds.fundDetailModel?.brkcollamt != 0.00)
        //   _buildInfoRow(
        //     "Collateral Additional",
        //     getFormatter(
        //       value: _safeParseDouble(
        //           "${funds.fundDetailModel?.brkcollamt ?? 0.00}"),
        //       v4d: false,
        //       noDecimal: false,
        //     ),
        //     theme,
        //   ),

        // Additional Credits
        if (filteredCredits.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...filteredCredits.map((item) => _buildInfoRow(
                "${item["name"]}",
                getFormatter(
                  value: _safeParseDouble("${item["value"]}"),
                  v4d: false,
                  noDecimal: false,
                ),
                theme,
              )),
        ],
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Span
        _buildInfoRow(
          "Span",
          getFormatter(
            value: _safeParseDouble("${funds.fundDetailModel?.span ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // Exposure
        _buildInfoRow(
          "Exposure",
          getFormatter(
            value: _safeParseDouble("${funds.fundDetailModel?.expo ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // Basket Margin
        _buildInfoRow(
          "Basket Margin",
          getFormatter(
            value: _safeParseDouble(
                "${funds.fundDetailModel?.scripbskmar ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // CO / BO Margin
        _buildInfoRow(
          "CO / BO Margin",
          getFormatter(
            value: _safeParseDouble(
                "${funds.fundDetailModel?.cobomargin ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // Option Premium
        _buildInfoRow(
          "Option Premium",
          getFormatter(
            value:
                _safeParseDouble("${funds.fundDetailModel?.premium ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // Delivery Sell Benefit
        _buildInfoRow(
          "Delivery Sell Benefit",
          getFormatter(
            value: _safeParseDouble(
                "${funds.fundDetailModel?.deliverySellBenefit ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // Unrealized Expenses
        _buildInfoRow(
          "Unrealized Expenses",
          getFormatter(
            value:
                _safeParseDouble("${funds.fundDetailModel?.brokerage ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // Additional Margin Items
        if (filteredMargin.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...filteredMargin.map((item) => _buildInfoRow(
                "${item["name"]}",
                getFormatter(
                  value: _safeParseDouble("${item["value"]}"),
                  v4d: false,
                  noDecimal: false,
                ),
                theme,
              )),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: MyntWebTextStyles.body(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
              fontWeight: MyntFonts.medium,
            ),
          ),
          Text(
            value,
            style: MyntWebTextStyles.body(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
              fontWeight: MyntFonts.medium,
            ),
          ),
        ],
      ),
    );
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
