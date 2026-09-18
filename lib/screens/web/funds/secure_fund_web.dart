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
import '../../../provider/privacy_provider.dart';
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
                        // Privacy Mode: balance masked, colour neutralized.
                        final privacy = ref.watch(privacyProvider);
                        final marginValue = privacy.isPrivate
                            ? 0.0
                            : double.parse(
                                "${funds.fundDetailModel?.avlMrg ?? 0.00}");
                        if (privacy.isPrivate) {
                          return Text(
                            kPrivacyMask,
                            style: MyntWebTextStyles.head(
                              context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                              fontWeight: MyntFonts.medium,
                            ),
                          );
                        }
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
                onTap: () => _showSegmentBreakdown(funds),
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
                  onTap: () => _showSegmentBreakdown(funds),
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
    VoidCallback? onTap,
  }) {
    final header = Container(
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
          Row(
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
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ref.watch(privacyProvider).mask(getFormatter(
                  value: double.tryParse(value) ?? 0.00,
                  v4d: false,
                  noDecimal: false,
                )),
            style: MyntWebTextStyles.title(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onTap == null)
          header
        else
          InkWell(
            onTap: onTap,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: header,
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
            value: (_safeParseDouble(
                        "${funds.fundDetailModel?.collateral ?? 0.00}") +
                    _safeParseDouble(
                        "${funds.fundDetailModel?.brkcollamt ?? 0.00}")) -
                _safeParseDouble("${funds.fundDetailModel?.cashcoll ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // Collateral Liquid
        _buildInfoRow(
          "Collateral Liquid",
          getFormatter(
            value:
                _safeParseDouble("${funds.fundDetailModel?.cashcoll ?? 0.00}"),
            v4d: false,
            noDecimal: false,
          ),
          theme,
        ),

        // // Collateral Cash
        // if(funds.fundDetailModel?.brkcollamt != "0.00" && funds.fundDetailModel?.brkcollamt != null)...[
        // _buildInfoRow(
        //   "Collateral MF",
        //   getFormatter(
        //     value: _safeParseDouble(
        //         "${funds.fundDetailModel?.brkcollamt ?? 0.00}"),
        //     v4d: false,
        //     noDecimal: false,
        //   ),
        //   theme,
        // ),
        // ],

        // Peak Margin
        _buildInfoRow(
          "Peak Margin",
          getFormatter(
            value:
                _safeParseDouble("${funds.fundDetailModel?.peakMar ?? 0.00}"),
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
        // The Limits response carries basket margin as `scripbskmrg`; the
        // `scripbskmar` key this row used to read is never sent, so the row
        // always printed 0.00 while the vendor showed the real figure.
        // value: _safeParseDouble("${funds.fundDetailModel?.scripbskmar ?? 0.00}"),
        _buildInfoRow(
          "Basket Margin",
          getFormatter(
            value: _safeParseDouble(
                "${funds.fundDetailModel?.scripbskmrg ?? 0.00}"),
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
            ref.watch(privacyProvider).mask(value),
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

  /// Segment-wise utilisation breakdown, opened from the Margin Used header.
  ///
  /// Every component key below was verified one by one against the vendor
  /// Margins page on 17-08-2026 (account ZV100, holding equity CNC and MIS,
  /// derivative MIS and NRML, commodity MIS and NRML). Each of their tiles
  /// matched the sums here to the paisa.
  ///
  /// Deliberately NOT included:
  ///  - Brokerage. The vendor keeps the `brkage_*` keys out of the segment
  ///    tiles and reports them once as Unrealized Expenses, which is why that
  ///    sits on its own row at the bottom here rather than inside a segment.
  ///  - Span, exposure and additional margin. No position on the test account
  ///    blocked span, so those keys never arrived and their per-segment names
  ///    are unconfirmed. Add them here once the backend field list lands —
  ///    until then a span-blocking position will under-report these rows.
  ///  - Currency Intraday and Currency CF. The vendor draws both, but Zebu
  ///    trades NSE, BSE, NFO, BFO and MCX only, so they would sit at zero for
  ///    every client.
  void _showSegmentBreakdown(dynamic funds) {
    final m = funds.fundDetailModel;
    double val(String? raw) => _safeParseDouble("${raw ?? 0.00}");

    // Option premium counts towards a segment only when it was PAID. Premium
    // received on a sold option does not reduce margin — the backend proves
    // it: marginused equals span + exposure + paid premium exactly, and never
    // subtracts received premium. Received premium is a next-day credit
    // instead. Verified 17-08-2026 against the vendor, whose Commodity CF tile
    // reads 1,12,572.38 and omits its own premium_c_m of -15,812.50.
    double paid(String? raw) {
      final v = val(raw);
      return v > 0 ? v : 0.0;
    }

    final segments = <_MarginSegment>[
      _MarginSegment("Equity", [
        _MarginProduct("Intraday", [
          _MarginComponent("Unrealised MToM MIS", val(m?.uzpnlEI)),
          _MarginComponent("Basket Margin MIS", val(m?.scripbskmarEI)),
        ]),
        const _MarginProduct("Normal", []),
        _MarginProduct("Delivery", [
          _MarginComponent("Delivery Margin", val(m?.cbu)),
        ]),
      ]),
      _MarginSegment("Derivative", [
        _MarginProduct("Intraday", [
          _MarginComponent("Span MIS", val(m?.spanDI)),
          _MarginComponent("Exposure MIS", val(m?.expoDI)),
          _MarginComponent("Premium MIS", paid(m?.premiumDI)),
        ]),
        _MarginProduct("Carry Forward", [
          _MarginComponent("Span CF", val(m?.spanDM)),
          _MarginComponent("Exposure CF", val(m?.expoDM)),
          _MarginComponent("Premium CF", paid(m?.premiumDM)),
          _MarginComponent("Unrealised MToM CF", val(m?.uzpnlDM)),
        ]),
      ]),
      _MarginSegment("Commodity", [
        _MarginProduct("Intraday", [
          _MarginComponent("Span MIS", val(m?.spanCI)),
          _MarginComponent("Exposure MIS", val(m?.expoCI)),
          _MarginComponent("Premium MIS", paid(m?.premiumCI)),
        ]),
        _MarginProduct("Carry Forward", [
          _MarginComponent("Span CF", val(m?.spanCM)),
          _MarginComponent("Exposure CF", val(m?.expoCM)),
          _MarginComponent("Premium CF", paid(m?.premiumCM)),
          _MarginComponent("Unrealised MToM CF", val(m?.uzpnlCM)),
        ]),
      ]),
      // Currency (CDS). Segment token is `f` for FX — Noren REST API spec
      // (Feb 2025) pages 113 and 117, where the segments are EQT / DER / FX
      // / COM. Same components as the other derivative segments.
      _MarginSegment("Currency", [
        _MarginProduct("Intraday", [
          _MarginComponent("Span MIS", val(m?.spanFI)),
          _MarginComponent("Exposure MIS", val(m?.expoFI)),
          _MarginComponent("Premium MIS", paid(m?.premiumFI)),
        ]),
        _MarginProduct("Carry Forward", [
          _MarginComponent("Span CF", val(m?.spanFM)),
          _MarginComponent("Exposure CF", val(m?.expoFM)),
          _MarginComponent("Premium CF", paid(m?.premiumFM)),
        ]),
      ]),
    ];

    final double totalUsed = val(m?.utilizedMrgn);
    final double brokerage = val(m?.brokerage);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _MarginBreakdownDialog(
        segments: segments,
        totalUsed: totalUsed,
        brokerage: brokerage,
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

/// One market segment in the Margin Used breakdown: Equity, Derivative,
/// Commodity and Currency. Currency is enabled for Zebu clients (CDS) but is
/// not wired to the API yet — see the TODO in _showSegmentBreakdown.
class _MarginSegment {
  final String name;
  final List<_MarginProduct> products;
  const _MarginSegment(this.name, this.products);

  double get total => products.fold<double>(0.0, (sum, p) => sum + p.total);
}

/// One product within a segment (Intraday, Normal, Delivery, Carry Forward).
/// The displayed figure is the sum of its components, mirroring how the
/// vendor totals each tile.
class _MarginProduct {
  final String name;
  final List<_MarginComponent> components;
  const _MarginProduct(this.name, this.components);

  double get total => components.fold<double>(0.0, (sum, c) => sum + c.value);
}

/// A single API-backed line inside a product, e.g. "Premium MIS".
class _MarginComponent {
  final String label;
  final double value;
  const _MarginComponent(this.label, this.value);
}

/// Margin Used Breakdown dialog.
///
/// Presentation follows the approved mockup: a pinned header, a summary block
/// with a proportional utilisation bar and legend, one collapsible card per
/// segment, and Unrealized Expenses on its own card at the foot.
///
/// The mockup's palette is reproduced literally so the dialog looks exactly as
/// designed; only the light/dark switch is taken from themeProvider rather
/// than a constructor flag. Values keep the app's existing behaviour — Indian
/// grouping via getFormatter and privacy masking via privacyProvider.
class _MarginBreakdownDialog extends ConsumerStatefulWidget {
  final List<_MarginSegment> segments;
  final double totalUsed;
  final double brokerage;

  const _MarginBreakdownDialog({
    required this.segments,
    required this.totalUsed,
    required this.brokerage,
  });

  @override
  ConsumerState<_MarginBreakdownDialog> createState() =>
      _MarginBreakdownDialogState();
}

class _MarginBreakdownDialogState
    extends ConsumerState<_MarginBreakdownDialog> {
  late final Map<String, bool> _open = {
    for (final s in widget.segments) s.name: true,
  };

  final ScrollController _scrollController = ScrollController();

  bool _d = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Surfaces, borders and text all come from MyntColors so the dialog matches
  // every other dialog in the app and follows the theme. The mockup's literals
  // were already these same values, so the look is unchanged in light mode.
  Color get _surface => _d ? MyntColors.cardDark : MyntColors.card;
  Color get _surfaceAlt => _d ? MyntColors.cardHoverDark : MyntColors.cardHover;
  Color get _subRowBg => _surface;
  Color get _border => _d ? MyntColors.cardBorderDark : MyntColors.cardBorder;
  Color get _divider =>
      _d ? MyntColors.borderMutedDark : MyntColors.borderMuted;
  Color get _textPrimary =>
      _d ? MyntColors.textPrimaryDark : MyntColors.textPrimary;
  Color get _textSecondary =>
      _d ? MyntColors.textSecondaryDark : MyntColors.textSecondary;
  Color get _textMuted =>
      _d ? MyntColors.textTertiaryDark : MyntColors.textTertiary;
  Color get _barTrack =>
      _d ? MyntColors.cardPressedDark : MyntColors.cardPressed;

  // Data colours for the utilisation bar and segment dots. These stay as
  // literals — they encode which segment is which, not a surface.
  Color get _primary => _d ? const Color(0xFF58A6FF) : const Color(0xFF0037B7);
  Color get _primarySoft =>
      _d ? const Color(0xFF388BFD) : const Color(0xFF4D7CD6);

  /// Unrealized Expenses slice. Deliberately a neutral slate rather than a
  /// blue, so it reads as "not a segment" — but dark enough to separate from
  /// the pale empty track behind it, which the original tone did not.
  Color get _barUnrl => _d ? const Color(0xFF8B949E) : const Color(0xFF7D8898);

  /// The mockup named colours for Derivative and Commodity only. Equity and
  /// Currency get their own tones in the same family so a segment carrying
  /// value is never drawn in the muted "empty" grey.
  Color get _accentEquity =>
      _d ? const Color(0xFF79C0FF) : const Color(0xFF002A8A);
  Color get _accentCurrency =>
      _d ? const Color(0xFFA5D6FF) : const Color(0xFF8AA9E8);

  Color _dotColor(_MarginSegment s) {
    if (s.total == 0) return _border;
    switch (s.name.toUpperCase()) {
      case 'DERIVATIVE':
        return _primary;
      case 'COMMODITY':
        return _primarySoft;
      case 'EQUITY':
        return _accentEquity;
      case 'CURRENCY':
        return _accentCurrency;
      default:
        return _textMuted;
    }
  }

  TextStyle _ts(double size, FontWeight w, Color c, {double? ls}) => TextStyle(
        fontFamily: MyntFonts.fontFamily,
        fontSize: size,
        fontWeight: w,
        color: c,
        letterSpacing: ls,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Keeps the app's existing number behaviour: Indian grouping, then the
  /// privacy mask. Never plain toStringAsFixed.
  String _fmt(double v) => ref.watch(privacyProvider).mask(
        getFormatter(value: v, v4d: false, noDecimal: false),
      );

  @override
  Widget build(BuildContext context) {
    _d = ref.watch(themeProvider).isDarkMode;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double maxDialogHeight =
        screenHeight * 0.85 > 640 ? 640 : screenHeight * 0.85;

    // Standard Mynt web dialog container: transparent Dialog wrapping a
    // shadcn.Card, same as the Create Strategy dialog. Without this the
    // Material default surface shows through and the dialog looks grey.
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Center(
        child: shadcn.Card(
          borderRadius: BorderRadius.circular(8),
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: 460, maxHeight: maxDialogHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                _summary(),
                Flexible(
                  // Always-on scrollbar, same treatment as the Market Info
                  // panel: the platform bar is suppressed and a RawScrollbar
                  // with thumbVisibility draws in its place. The wider right
                  // padding keeps the thumb clear of the segment cards.
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior()
                        .copyWith(scrollbars: false),
                    child: RawScrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      thickness: 6,
                      radius: const Radius.circular(0),
                      thumbColor: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary)
                          .withValues(alpha: 0.4),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
                        child: Column(
                          children: [
                            for (final s in widget.segments) _segmentCard(s),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _unrealized(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Margin Used Breakdown',
                style: _ts(16, FontWeight.w600, _textPrimary),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, size: 16, color: _textSecondary),
              ),
            ),
          ],
        ),
      );

  Widget _summary() {
    final double total = widget.totalUsed;
    // Guard the divide. An account with nothing blocked reports zero here, and
    // dividing by it would yield NaN or Infinity and throw inside .round().
    final bool hasBar = total > 0;

    final segmentSlices = <MapEntry<Color, double>>[
      for (final s in widget.segments)
        if (s.total > 0) MapEntry(_dotColor(s), s.total / total),
    ];
    final entries = <MapEntry<Color, double>>[
      ...segmentSlices,
      MapEntry(_barUnrl, widget.brokerage / (total == 0 ? 1 : total)),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Total Utilised',
                  style: _ts(13, FontWeight.w500, _textSecondary),
                ),
              ),
              Text(
                '₹${_fmt(total)}',
                style: _ts(20, FontWeight.w700, _textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              // width must be explicit: the Column is CrossAxisAlignment.start
              // and every bar slice is an Expanded, so there is no intrinsic
              // width to size against and the strip collapses to nothing.
              width: double.infinity,
              height: 6,
              child: hasBar
                  ? Row(
                      // stretch is required: a ColoredBox with no child sizes
                      // to constraints.smallest, and a Row's default centre
                      // alignment hands children a loose 0-to-6 height, so
                      // every slice would collapse to zero and paint nothing.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final e in entries)
                          Expanded(
                            flex: (e.value * 1000).round().clamp(0, 1000),
                            child: ColoredBox(color: e.key),
                          ),
                        Expanded(
                          flex: (1000 -
                                  entries.fold<double>(
                                      0, (a, e) => a + e.value * 1000))
                              .round()
                              .clamp(0, 1000),
                          child: ColoredBox(color: _barTrack),
                        ),
                      ],
                    )
                  : ColoredBox(color: _barTrack),
            ),
          ),
          const SizedBox(height: 10),
          // Legend is derived from whichever segments actually carry value, so
          // a colour never appears in the bar without an entry explaining it.
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final s in widget.segments)
                if (s.total > 0) _legend(s.name, _dotColor(s)),
              if (widget.brokerage > 0) _legend('Unrealized', _barUnrl),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: _ts(11, FontWeight.w500, _textSecondary)),
        ],
      );

  Widget _segmentCard(_MarginSegment s) {
    final bool zero = s.total == 0;
    final bool open = _open[s.name] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open[s.name] = !open),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _surfaceAlt,
                border:
                    open ? Border(bottom: BorderSide(color: _border)) : null,
              ),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(Icons.chevron_right,
                        size: 16, color: _textSecondary),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _dotColor(s),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.name.toUpperCase(),
                      style: _ts(
                          12, FontWeight.w700, zero ? _textMuted : _textPrimary,
                          ls: 0.8),
                    ),
                  ),
                  Text(
                    _fmt(s.total),
                    style: _ts(
                        14, FontWeight.w700, zero ? _textMuted : _textPrimary),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            for (final p in s.products) ...[
              _row(p.name, p.total, sub: false),
              // Empty components stay hidden, matching the vendor — a product
              // with nothing blocked shows its heading row alone.
              for (final c in p.components)
                if (c.value != 0) _row(c.label, c.value, sub: true),
            ],
        ],
      ),
    );
  }

  Widget _row(String label, double value, {required bool sub}) {
    final Color color =
        sub ? _textSecondary : (value == 0 ? _textMuted : _textPrimary);
    final double size = sub ? 12.0 : 13.0;
    final FontWeight weight = sub ? FontWeight.w400 : FontWeight.w500;

    return Container(
      padding: EdgeInsets.fromLTRB(sub ? 34 : 12, 7, 12, 7),
      decoration: BoxDecoration(
        color: sub ? _subRowBg : _surface,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          if (sub) ...[
            Icon(Icons.subdirectory_arrow_right, size: 12, color: _textMuted),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(label, style: _ts(size, weight, color))),
          Text(_fmt(value), style: _ts(size, weight, color)),
        ],
      ),
    );
  }

  Widget _unrealized() => Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          // color: _surfaceAlt,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Unrealized Expenses',
                    style: _ts(13, FontWeight.w600, _textPrimary),
                  ),
                ),
                Text(
                  _fmt(widget.brokerage),
                  style: _ts(13, FontWeight.w600, _textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Charged across all segments, not split by segment',
              style: _ts(11, FontWeight.w400, _textMuted),
            ),
          ],
        ),
      );
}
