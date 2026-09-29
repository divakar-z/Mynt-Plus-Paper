import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:mynt_plus/provider/ledger_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/screens/web/profile/pledge/pledge_approve_list_screen.dart';
import 'package:mynt_plus/screens/web/profile/pledge/pledge_history_main_screen.dart';
import 'package:mynt_plus/screens/web/profile/pledge/pledge_filter_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mynt_plus/routes/web_router.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/common_search_fields_web.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';

class PledgenUnpledge extends StatefulWidget {
  final String ddd;

  /// When set, an app-bar back button is shown that calls this instead of
  /// popping — used by the Holdings screen to return to its own view.
  final VoidCallback? onBack;
  const PledgenUnpledge({super.key, required this.ddd, this.onBack});

  @override
  State<PledgenUnpledge> createState() => _PledgenUnpledgeScreenState();
}

class _PledgenUnpledgeScreenState extends State<PledgenUnpledge> {
  // Selected tab: '0' = Available Balance (Pledge), '1' = Pledge Balance (Unpledge), '2' = Non Approved
  String selectedFilterType = '0';

  // Inline screen states
  bool showApproveList = false;
  bool showHistory = false;

  // Search state
  TextEditingController searchController = TextEditingController();
  FocusNode searchFocusNode = FocusNode();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    // TC_344 — the search field's X button empties the controller without
    // firing onChanged/onClear, so the filter kept the old query. Reset it
    // whenever the field becomes empty (same approach as Positions).
    searchController.addListener(() {
      if (!mounted) return;
      if (searchController.text.isEmpty && searchQuery.isNotEmpty) {
        _onSearchChanged('');
      }
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value.toLowerCase();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenheight = MediaQuery.of(context).size.height;

    return Consumer(builder: (context, WidgetRef ref, _) {
      final theme = ref.watch(themeProvider);
      final ledgerprovider = ref.watch(ledgerProvider);

      Future<void> _refresh() async {
        await Future.delayed(Duration(seconds: 0));
        ledgerprovider.getCurrentDate("pandu");
        ledgerprovider.fetchpledgeandunpledge(context);
      }

      // Calculate counts for cards
      int pledgeListCount = 0;
      int unpledgeListCount = 0;
      int nonApprovedCount = 0;

      if (ledgerprovider.pledgeandunpledge?.data != null) {
        for (var item in ledgerprovider.pledgeandunpledge!.data!) {
          final int soh =
              (double.tryParse(item.sOHQTY?.toString() ?? '0') ?? 0).toInt();
          final int nsoh =
              (double.tryParse(item.nSOHQTY?.toString() ?? '0') ?? 0).toInt();
          final int colQty =
              (double.tryParse(item.cOLQTY?.toString() ?? '0') ?? 0).toInt();

          // Tab "0" — Available Balance (Pledge)
          if (item.initiated == "0" &&
              item.status == 'Ok' &&
              (soh + nsoh) != 0) {
            pledgeListCount++;
          }
          // Tab "1" — Pledge Balance (Unpledge)
          if (colQty != 0) {
            unpledgeListCount++;
          }
          // Tab "2" — Non Approved
          if ((item.status ?? '').trim().toLowerCase() == "not_ok") {
            nonApprovedCount++;
          }
        }
      }

      double nonApprovedSum = 0.0;
      if (ledgerprovider.pledgeandunpledge?.data != null) {
        for (var item in ledgerprovider.pledgeandunpledge!.data!) {
          if ((item.status ?? '').trim().toLowerCase() == "not_ok") {
            double scripValue =
                double.tryParse(item.aMOUNT?.toString() ?? '0') ?? 0.0;
            nonApprovedSum += scripValue;
          }
        }
      }

      // Stats for the selected tab
      String displayLabel = '';
      String displayValue = '0.00';

      if (selectedFilterType == '1') {
        displayLabel = 'Available Margin';
        displayValue =
            ledgerprovider.pledgeandunpledge?.marginTotalAvailable?.toString() ??
                '0.00';
        if (displayValue == 'null') displayValue = '0.00';
      } else if (selectedFilterType == '0') {
        displayLabel = 'Est Margin';
        displayValue =
            ledgerprovider.pledgeandunpledge?.estTotalAvailable?.toString() ??
                '0.00';
        if (displayValue == 'null') displayValue = '0.00';
      } else {
        displayLabel = 'Non-Approved';
        displayValue = nonApprovedSum.toStringAsFixed(2);
      }

      // Approve Securities inline screen
      if (showApproveList) {
        return Navigator(
          onDidRemovePage: (page) {
            setState(() {
              showApproveList = false;
            });
          },
          pages: const [
            MaterialPage(child: PledgeApproveListScreen()),
          ],
        );
      }

      // History inline screen
      if (showHistory) {
        return Navigator(
          onDidRemovePage: (page) {
            setState(() {
              showHistory = false;
            });
          },
          pages: const [
            MaterialPage(child: PledgeHistoryMainScreen()),
          ],
        );
      }

      // CDSL web waiting state: show full-panel loader
      if (ledgerprovider.cdslWebWaiting && !ledgerprovider.cdslWebShowReport) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: resolveThemeColor(context,
                dark: MyntColors.backgroundColorDark,
                light: MyntColors.backgroundColor),
            leadingWidth: 41,
            titleSpacing: 6,
            centerTitle: false,
            elevation: 0,
          surfaceTintColor: Colors.transparent,
            leading: const SizedBox(),
            title: Text(
                "CDSL Verification",
                overflow: TextOverflow.ellipsis,
                style: MyntWebTextStyles.title(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                    fontWeight: MyntFonts.semiBold)),
          ),
          body: Container(
            color: resolveThemeColor(context,
                dark: MyntColors.backgroundColorDark,
                light: MyntColors.backgroundColor),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Awaiting CDSL confirmation',
                    style: MyntWebTextStyles.title(context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                        fontWeight: MyntFonts.semiBold),
                  ),
                  const SizedBox(height: 24),
                  // Animated dots
                  SizedBox(
                    width: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.3, end: 1.0),
                          duration: Duration(milliseconds: 600 + (index * 100)),
                          builder: (context, value, child) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Opacity(
                                opacity: value,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark,
                                        light: MyntColors.textSecondary),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This will take a few seconds.',
                    style: MyntWebTextStyles.bodySmall(context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary)),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 200,
                    height: 35,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: resolveThemeColor(context,
                            dark: MyntColors.secondary,
                            light: MyntColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: () {
                        ledgerprovider.cancelCdslWebFlow();
                      },
                      child: Text("Cancel Transaction",
                          style: MyntWebTextStyles.bodySmall(context,
                              color: MyntColors.textWhite,
                              fontWeight: MyntFonts.semiBold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // CDSL web report state: show full-panel pledge report
      if (ledgerprovider.cdslWebShowReport &&
          ledgerprovider.cdslresponsedata != null) {
        return _buildCdslReportScreen(ledgerprovider, theme);
      }

      return Scaffold(
        appBar: AppBar(
          backgroundColor: resolveThemeColor(context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          leadingWidth: widget.onBack == null ? null : 44,
          titleSpacing: 6,
          centerTitle: false,
          leading: widget.onBack == null
              ? null
              : CustomBackBtn(onBack: widget.onBack),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding:
                    EdgeInsets.only(left: widget.onBack == null ? 16.0 : 0),
                child: Text("Pledge",
                    overflow: TextOverflow.ellipsis,
                    style: MyntWebTextStyles.title(context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                        fontWeight: MyntFonts.semiBold)),
              ),
              Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    shape: const RoundedRectangleBorder(),
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      customBorder: const RoundedRectangleBorder(),
                      splashColor: resolveThemeColor(context,
                          dark: MyntColors.rippleDark,
                          light: MyntColors.rippleLight),
                      highlightColor: resolveThemeColor(context,
                          dark: MyntColors.highlightDark,
                          light: MyntColors.highlightLight),
                      onTap: () async {
                        ledgerprovider.fetchunpledgehistory(context);
                        ledgerprovider.fetchpledgehistory(context);
                        ledgerprovider.taxpnlExTabchange(0);
                        setState(() {
                          showHistory = true;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: Text("History",
                            style: MyntWebTextStyles.bodySmall(context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.primaryDark,
                                    light: MyntColors.primary),
                                fontWeight: MyntFonts.semiBold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: Colors.transparent,
                    shape: const RoundedRectangleBorder(),
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      customBorder: const RoundedRectangleBorder(),
                      splashColor: resolveThemeColor(context,
                          dark: MyntColors.rippleDark,
                          light: MyntColors.rippleLight),
                      highlightColor: resolveThemeColor(context,
                          dark: MyntColors.highlightDark,
                          light: MyntColors.highlightLight),
                      onTap: () async {
                        ledgerprovider.fetchapprovepledge();
                        setState(() {
                          showApproveList = true;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: Text("Approve Securities",
                            style: MyntWebTextStyles.bodySmall(context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.primaryDark,
                                    light: MyntColors.primary),
                                fontWeight: MyntFonts.semiBold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: ledgerprovider.pledgeloader
            ? Center(
                child: Container(
                  color: resolveThemeColor(context,
                      dark: MyntColors.backgroundColorDark,
                      light: MyntColors.backgroundColor),
                  child: MyntLoader.branded(),
                ),
              )
            : SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // ── Stats Cards ──
                        _buildSummaryCards(
                          theme: theme,
                          ledgerprovider: ledgerprovider,
                          displayLabel: displayLabel,
                          displayValue: displayValue,
                        ),

                        // ── Tabs + Search Row ──
                        _buildTabsAndSearchRow(
                          theme: theme,
                          pledgeListCount: pledgeListCount,
                          unpledgeListCount: unpledgeListCount,
                          nonApprovedCount: nonApprovedCount,
                        ),

                        // Divider
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: resolveThemeColor(context,
                              dark: MyntColors.dividerDark,
                              light: MyntColors.divider),
                        ),

                        // ── Table ──
                        Expanded(
                          child: PledgeFilter(
                            activetabe: selectedFilterType,
                            searchQuery: searchQuery,
                          ),
                        ),

                        // Space for bottom action buttons
                        if (ledgerprovider.listforpledge.isNotEmpty)
                          Container(height: screenheight * 0.07),
                      ],
                    ),

                    // ── Bottom Action Buttons ──
                    if (ledgerprovider.listforpledge.isNotEmpty)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: resolveThemeColor(context,
                                dark: MyntColors.backgroundColorDark,
                                light: MyntColors.backgroundColor),
                            border: Border(
                              top: BorderSide(
                                color: resolveThemeColor(context,
                                    dark: MyntColors.cardBorderDark,
                                    light: MyntColors.cardBorder),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Selected scripts count + hover tooltip
                              Expanded(
                                child: _buildSelectedScriptsLabel(
                                    ledgerprovider, theme),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 35,
                                child: ElevatedButton(
                                  onPressed: () {
                                    ledgerprovider
                                        .cancelpledgetotal(
                                            ledgerprovider
                                                .screenpledge);
                                    ledgerprovider
                                        .changesegvaldummy('');
                                  },
                                  style:
                                      ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: resolveThemeColor(context,
                                        dark: MyntColors.textSecondaryDark
                                            .withValues(alpha: 0.6),
                                        light: MyntColors.backgroundColor),
                                    side: isDarkMode(context)
                                        ? null
                                        : BorderSide(
                                            color: MyntColors.primary,
                                            width: 1,
                                          ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              4),
                                    ),
                                  ),
                                  child: Text("Cancel",
                                      style: MyntWebTextStyles.bodySmall(context,
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.textWhite,
                                              light: MyntColors.primary),
                                          fontWeight: MyntFonts.semiBold)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 35,
                                child: ElevatedButton(
                                  style:
                                      ElevatedButton.styleFrom(
                                    elevation: 0,
                                    shadowColor:
                                        Colors.transparent,
                                    backgroundColor: resolveThemeColor(context,
                                        dark: MyntColors.secondary,
                                        light: MyntColors.primary),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              4),
                                    ),
                                  ),
                                          onPressed: () async {
                                            // Skip confirmation dialog on
                                            // Pledge Balance tab (unpledge).
                                            if (selectedFilterType != '1') {
                                              final confirmed =
                                                  await _showPledgeConfirmDialog(
                                                      context, ledgerprovider);
                                              if (confirmed != true) return;
                                              if (!context.mounted) return;
                                            }
                                            ledgerprovider
                                                .changesegvaldummy('');
                                            if (ledgerprovider
                                                    .pledgeoruppledgedelete ==
                                                'unpledgedelete') {
                                              ledgerprovider
                                                  .unpldgedeletefun(
                                                      context,
                                                      ledgerprovider
                                                          .pledgeandunpledge!
                                                          .cLIENTCODE
                                                          .toString(),
                                                      ledgerprovider
                                                          .listforpledge);
                                            } else {
                                              if (ledgerprovider
                                                      .pledgeorunpledge ==
                                                  'unpledge') {
                                                ledgerprovider
                                                    .sendunpledgerequest(
                                                        context,
                                                        ledgerprovider
                                                            .pledgeandunpledge!
                                                            .cLIENTCODE
                                                            .toString(),
                                                        ledgerprovider
                                                            .pledgeandunpledge!
                                                            .bOID
                                                            .toString(),
                                                        ledgerprovider
                                                            .pledgeandunpledge!
                                                            .cLIENTNAME
                                                            .toString(),
                                                        ledgerprovider
                                                            .listforpledge);
                                              } else if (ledgerprovider
                                                      .pledgeorunpledge ==
                                                  'pledge') {
                                                // Show a temporary dialog so beforecdsl's
                                                // Navigator.pop closes it, not the main screen
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  barrierColor: Colors.transparent,
                                                  builder: (_) => const SizedBox.shrink(),
                                                );
                                                ledgerprovider.beforecdsl(
                                                    context,
                                                    ledgerprovider
                                                        .pledgeandunpledge!
                                                        .cLIENTCODE
                                                        .toString(),
                                                    ledgerprovider
                                                        .pledgeandunpledge!
                                                        .bOID
                                                        .toString(),
                                                    ledgerprovider
                                                        .pledgeandunpledge!
                                                        .cLIENTNAME
                                                        .toString(),
                                                    ledgerprovider
                                                        .listforpledge);
                                              }
                                            }
                                          },
                                  child: Text("Submit",
                                      style: MyntWebTextStyles.bodySmall(context,
                                          color: MyntColors.textWhite,
                                          fontWeight: MyntFonts.semiBold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      );
    });
  }

  // ============================================================
  // Pledge / Unpledge Confirmation Dialog
  // ============================================================

  Future<bool?> _showPledgeConfirmDialog(
      BuildContext context, LDProvider ledgerprovider) async {
    final isDelete =
        ledgerprovider.pledgeoruppledgedelete == 'unpledgedelete';
    final base = ledgerprovider.pledgeorunpledge;
    final mode = isDelete ? 'cancel_$base' : base;

    final String title;
    final String submitLabel;
    switch (mode) {
      case 'unpledge':
        title = 'Unpledge Details';
        submitLabel = 'Submit Request';
        break;
      case 'cancel_pledge':
        title = 'Delete Pledge request';
        submitLabel = 'Submit Request';
        break;
      case 'cancel_unpledge':
        title = 'Delete Unpledge request';
        submitLabel = 'Submit Request';
        break;
      case 'pledge':
      default:
        title = 'Pledge Details';
        submitLabel = 'Submit Request';
        break;
    }

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final screenHeight = MediaQuery.of(dialogContext).size.height;
        final dialogWidth =
            screenWidth * 0.9 > 400.0 ? 400.0 : screenWidth * 0.9;
        final listMaxHeight = screenHeight * 0.5;
        final items = ledgerprovider.listforpledge;

        return Center(
          child: shadcn.Card(
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            child: Container(
              width: dialogWidth,
              decoration: BoxDecoration(
                color: resolveThemeColor(dialogContext,
                    dark: MyntColors.dialogDark,
                    light: MyntColors.dialog),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: shadcn.Theme.of(dialogContext)
                              .colorScheme
                              .border,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: MyntWebTextStyles.title(
                              dialogContext,
                              color: resolveThemeColor(dialogContext,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary),
                            ),
                          ),
                        ),
                        MyntCloseButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ConstrainedBox(
                            constraints:
                                BoxConstraints(maxHeight: listMaxHeight),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  for (int i = 0; i < items.length; i++) ...[
                                    _buildConfirmScriptRow(
                                        dialogContext, items[i]),
                                    if (i != items.length - 1)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: Divider(
                                          height: 1,
                                          thickness: 0.5,
                                          color: shadcn.Theme.of(dialogContext)
                                              .colorScheme
                                              .border,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          MyntButton(
                            type: MyntButtonType.primary,
                            size: MyntButtonSize.large,
                            label: submitLabel,
                            isFullWidth: true,
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
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
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale:
                Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildConfirmScriptRow(
      BuildContext context, Map<dynamic, dynamic> value) {
    final symbol = '${value['symbol'] ?? '-'}';
    final qty = '${value['quantity'] ?? '-'}';
    final segment = '${value['segments'] ?? '-'}';

    final labelStyle = MyntWebTextStyles.bodySmall(
      context,
      darkColor: MyntColors.textSecondaryDark,
      lightColor: MyntColors.textSecondary,
      fontWeight: MyntFonts.medium,
    );
    final valueStyle = MyntWebTextStyles.bodySmall(
      context,
      darkColor: MyntColors.textPrimaryDark,
      lightColor: MyntColors.textPrimary,
      fontWeight: MyntFonts.semiBold,
    );

    Widget row(String label, String val) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: labelStyle),
            ),
            Expanded(
              child: Text(
                val,
                style: valueStyle,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row('Symbol :', symbol),
        row('Total Qty :', qty),
        row('Segment :', segment),
      ],
    );
  }

  // ============================================================
  // CDSL Report Full-Panel Screen (shadcn table)
  // ============================================================

  TextStyle _reportCellStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableCell(
      context,
      color: color,
      darkColor: color ?? MyntColors.textPrimaryDark,
      lightColor: color ?? MyntColors.textPrimary,
      fontWeight: MyntFonts.medium,
    );
  }

  TextStyle _reportHeaderStyle(BuildContext context) {
    return MyntWebTextStyles.tableHeader(
      context,
      darkColor: MyntColors.textSecondaryDark,
      lightColor: MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  shadcn.TableCell _reportHeaderCell(String label) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Text(label, style: _reportHeaderStyle(context)),
      ),
    );
  }

  shadcn.TableCell _reportDataCell(String value, {Widget? child}) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.centerLeft,
        child: child ?? Text(value, style: _reportCellStyle(context)),
      ),
    );
  }

  Widget _buildCdslReportScreen(
      LDProvider ledgerprovider, ThemesProvider theme) {
    final data = ledgerprovider.cdslresponsedata!;
    final two = data.cDSLResp?.pledgeresdtls?.pledgeresdtlstwo;
    // CDSL's new pledge API: rejected if either reqstatus or resstatus == '1'.
    // Anything else is treated as Success (Pending state dropped).
    final rejected = two?.reqstatus == '1' || two?.resstatus == '1';
    final isinList = two?.isinresdtls ?? [];

    final isDark = theme.isDarkMode;
    final borderColor =
        isDark ? MyntColors.cardBorderDark : MyntColors.cardBorder;
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        leadingWidth: 41,
        titleSpacing: 6,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: CustomBackBtn(
          onBack: () {
            ledgerprovider.resetCdslWebReport(context);
          },
        ),
        title: Text("Pledge Report Details",
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.title(context,
                color: textPrimary,
                fontWeight: MyntFonts.semiBold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary Card (table layout) ──
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left column
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _summaryRow('Client Name',
                                '${data.cLIENTNAME}', theme),
                            const SizedBox(height: 12),
                            _summaryRow(
                                'Client ID', '${data.uccid}', theme),
                            const SizedBox(height: 12),
                            _summaryRow('BO ID',
                                '${data.clientBoId}', theme),
                            const SizedBox(height: 12),
                            _summaryRow(
                                'Request ID',
                                '${data.cDSLResp?.pledgeresdtls?.pledgeresdtlstwo?.reqid}',
                                theme),
                          ],
                        ),
                      ),
                    ),
                    // Vertical divider
                    Container(
                      width: 1,
                      color: borderColor,
                    ),
                    // Right column
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Status row with badge
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Status',
                                    style: MyntWebTextStyles.bodySmall(
                                      context,
                                      darkColor:
                                          MyntColors.textSecondaryDark,
                                      lightColor:
                                          MyntColors.textSecondary,
                                      fontWeight: MyntFonts.medium,
                                    )),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    color: rejected
                                        ? MyntColors.lossDark
                                            .withValues(alpha: 0.15)
                                        : MyntColors.profitDark
                                            .withValues(alpha: 0.15),
                                  ),
                                  child: Text(
                                    rejected ? 'Rejected' : 'Success',
                                    style: MyntWebTextStyles.para(context,
                                        fontWeight: MyntFonts.semiBold,
                                        color: rejected
                                            ? resolveThemeColor(context,
                                                dark: MyntColors.lossDark,
                                                light: MyntColors.loss)
                                            : resolveThemeColor(context,
                                                dark: MyntColors.profitDark,
                                                light: MyntColors.profit)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _summaryRow(
                                'CDSL Requested Time',
                                '${data.pledgeReqTime}',
                                theme),
                            const SizedBox(height: 12),
                            _summaryRow(
                                'CDSL Response Time',
                                '${data.cDSLRespTime}',
                                theme),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Pledge Report Details Table (shadcn) ──
            LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final isinWidth = totalWidth * 0.25;
                final reqIdWidth = totalWidth * 0.20;
                final resIdWidth = totalWidth * 0.20;
                final qtyWidth = totalWidth * 0.15;
                final statusWidth = totalWidth * 0.20;

                final columnWidths = {
                  0: shadcn.FixedTableSize(isinWidth),
                  1: shadcn.FixedTableSize(reqIdWidth),
                  2: shadcn.FixedTableSize(resIdWidth),
                  3: shadcn.FixedTableSize(qtyWidth),
                  4: shadcn.FixedTableSize(statusWidth),
                };

                return shadcn.OutlinedContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isinList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child:
                                NoDataFound(secondaryEnabled: false),
                          ),
                        )
                      else ...[
                        // Header row
                        shadcn.Table(
                          defaultRowHeight:
                              const shadcn.FixedTableSize(44),
                          columnWidths: columnWidths,
                          rows: [
                            shadcn.TableHeader(
                              cells: [
                                _reportHeaderCell('ISIN'),
                                _reportHeaderCell('Reqired Id'),
                                _reportHeaderCell('Res Id'),
                                _reportHeaderCell('Quantity'),
                                _reportHeaderCell('Status'),
                              ],
                            ),
                          ],
                        ),
                        // Data rows
                        shadcn.Table(
                          defaultRowHeight:
                              const shadcn.FixedTableSize(48),
                          columnWidths: columnWidths,
                          rows: isinList.map((val) {
                            final isCompleted = val.status == '0';
                            return shadcn.TableRow(
                              cells: [
                                _reportDataCell('${val.isin}'),
                                _reportDataCell('${val.isinreqid}'),
                                _reportDataCell('${val.isinresid}'),
                                _reportDataCell('${val.quantity}'),
                                _reportDataCell(
                                  '',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      color: isCompleted
                                          ? MyntColors.profitDark
                                              .withValues(alpha: 0.15)
                                          : MyntColors.lossDark
                                              .withValues(alpha: 0.15),
                                    ),
                                    child: Text(
                                      isCompleted
                                          ? 'Completed'
                                          : 'Rejected',
                                      style: MyntWebTextStyles.para(context,
                                          fontWeight: MyntFonts.semiBold,
                                          color: isCompleted
                                              ? resolveThemeColor(context,
                                                  dark: MyntColors.profitDark,
                                                  light: MyntColors.profit)
                                              : resolveThemeColor(context,
                                                  dark: MyntColors.lossDark,
                                                  light: MyntColors.loss)),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, ThemesProvider theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
              fontWeight: MyntFonts.medium,
            )),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
              fontWeight: MyntFonts.semiBold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Tabs + Search Row (combined, matching order book style)
  // ============================================================

  Widget _buildTabsAndSearchRow({
    required ThemesProvider theme,
    required int pledgeListCount,
    required int unpledgeListCount,
    required int nonApprovedCount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Tabs on the left
          _buildTabItem('Available Balance', pledgeListCount, '0', theme),
          _buildTabItem('Pledge Balance', unpledgeListCount, '1', theme),
          _buildTabItem('Non Approved', nonApprovedCount, '2', theme),
          const Spacer(),
          // Search field
          SizedBox(
            width: 260,
            child: MyntSearchTextField.withSmartClear(
              controller: searchController,
              focusNode: searchFocusNode,
              placeholder: 'Search',
              leadingIcon: assets.searchIcon,
              onChanged: (value) {
                _onSearchChanged(value);
              },
              onClear: () {
                searchController.clear();
                _onSearchChanged('');
              },
            ),
          ),
          const SizedBox(width: 8),
          // Filter button
          _buildFilterButton(theme),
        ],
      ),
    );
  }

  Widget _buildFilterButton(ThemesProvider theme) {
    return Builder(
      builder: (buttonContext) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _showFilterPopup(buttonContext, theme),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SvgPicture.asset(
                  assets.searchFilter,
                  width: 20,
                  colorFilter: ColorFilter.mode(
                    resolveThemeColor(
                      context,
                      dark: MyntColors.iconDark,
                      light: MyntColors.icon,
                    ),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFilterPopup(BuildContext context, ThemesProvider theme) {
    shadcn.showPopover(
      context: context,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 8),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(context).borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: shadcn.ModalContainer(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 160,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterMenuItem('All', 'all', theme),
                  _buildFilterMenuItem('Cash', 'cash', theme),
                  _buildFilterMenuItem('Non-Cash', 'noncash', theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterMenuItem(
      String label, String filterValue, ThemesProvider theme) {
    return Consumer(
      builder: (context, ref, _) {
        final ledgerprovider = ref.watch(ledgerProvider);
        final isSelected = ledgerprovider.pledgeCashFilter == filterValue;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ledgerprovider.setPledgeCashFilter(filterValue);
              shadcn.closeOverlay(context);
            },
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
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isSelected
                    ? resolveThemeColor(
                        context,
                        dark: MyntColors.primaryDark.withValues(alpha: 0.12),
                        light: const Color(0xFFE8F0FE),
                      )
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: isSelected
                            ? MyntFonts.semiBold
                            : MyntFonts.medium,
                        color: isSelected
                            ? resolveThemeColor(
                                context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary,
                              )
                            : resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
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
  }

  Widget _buildTabItem(
      String title, int count, String filterType, ThemesProvider theme) {
    final isActive = selectedFilterType == filterType;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedFilterType = filterType;
            searchController.clear();
            searchQuery = '';
          });
        },
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? resolveThemeColor(context,
                    dark: Colors.white.withValues(alpha: 0.1),
                    light: Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: isActive ? MyntFonts.semiBold : MyntFonts.medium,
                ).copyWith(
                  color: isActive
                      ? shadcn.Theme.of(context).colorScheme.foreground
                      : shadcn.Theme.of(context).colorScheme.mutedForeground,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Text(
                    '$count',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      fontWeight:
                          isActive ? MyntFonts.semiBold : MyntFonts.medium,
                    ).copyWith(
                      fontSize: 13,
                      color: isActive
                          ? shadcn.Theme.of(context).colorScheme.foreground
                          : shadcn.Theme.of(context)
                              .colorScheme
                              .mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Stats Header
  // ============================================================

  Widget _buildSummaryCards({
    required ThemesProvider theme,
    required LDProvider ledgerprovider,
    required String displayLabel,
    required String displayValue,
  }) {
    final pledgeData = ledgerprovider.pledgeandunpledge;
    final totalValue = pledgeData?.stocksValue?.toString() ?? '0.00';
    final cashEquivalent = pledgeData?.cashEquivalent?.toString() ?? '0.00';
    final nonCashEquivalent = pledgeData?.noncashEquivalent?.toString() ?? '0.00';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth >= 800 ? 3 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 100,
            ),
            children: [
              _buildStatCard(
                label: 'Total Value',
                value: totalValue == 'null' ? '0.00' : totalValue,
                theme: theme,
              ),
              _buildStatCard(
                label: 'Cash Equivalent / Non Cash',
                value: '${cashEquivalent == 'null' ? '0.00' : cashEquivalent} / ${nonCashEquivalent == 'null' ? '0.00' : nonCashEquivalent}',
                theme: theme,
              ),
              _buildStatCard(
                label: displayLabel,
                value: displayValue,
                prefix: '₹ ',
                theme: theme,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required ThemesProvider theme,
    String? prefix,
  }) {
    return shadcn.Theme(
      data: shadcn.Theme.of(context).copyWith(radius: () => 0.3),
      child: shadcn.Card(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          child: Row(
            children: [
              const SizedBox(width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
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
                    const SizedBox(height: 4),
                    Text(
                      '${prefix ?? ''}$value',
                      style: MyntWebTextStyles.head(
                        context,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary,
                        ),
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Selected Scripts Label with hover tooltip
  // ============================================================

  Widget _buildSelectedScriptsLabel(
      LDProvider ledgerprovider, ThemesProvider theme) {
    final count = ledgerprovider.listforpledge.length;

    final tooltipLines = ledgerprovider.listforpledge.map((item) {
      final symbol = item['symbol'] ?? '-';
      final qty = item['quantity'] ?? '-';
      final segment = item['segments'] ?? '';
      return segment.isNotEmpty
          ? '$symbol  ·  Qty: $qty  ·  $segment'
          : '$symbol  ·  Qty: $qty';
    }).join('\n');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count Script Selected',
          style: MyntWebTextStyles.bodySmall(
            context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.medium,
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: tooltipLines,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.overlayBgDark,
                light: MyntColors.overlayBg),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: resolveThemeColor(context,
                  dark: MyntColors.borderMutedDark,
                  light: MyntColors.borderMuted),
            ),
          ),
          textStyle: MyntWebTextStyles.para(
            context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.medium,
          ),
          waitDuration: const Duration(milliseconds: 200),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              'Hover to view scripts',
              style: MyntWebTextStyles.bodySmall(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary),
                fontWeight: MyntFonts.medium,
              ).copyWith(
                // decoration: TextDecoration.underline,
                decorationColor: resolveThemeColor(context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PledgeListDetails - kept for backward compatibility
// ============================================================

class PledgeListDetails extends StatefulWidget {
  final String filterType;
  final String title;

  const PledgeListDetails(
      {super.key, required this.filterType, required this.title});

  @override
  State<PledgeListDetails> createState() => _PledgeListDetailsState();
}

class _PledgeListDetailsState extends State<PledgeListDetails> {
  bool isSearching = false;
  TextEditingController searchController = TextEditingController();
  FocusNode searchFocusNode = FocusNode();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      setState(() {});
    });
  }

  void _toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      if (isSearching) {
        searchFocusNode.requestFocus();
      } else {
        searchController.clear();
        searchQuery = '';
        searchFocusNode.unfocus();
      }
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value.toLowerCase();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, WidgetRef ref, _) {
      ref.watch(themeProvider);
      final ledgerprovider = ref.watch(ledgerProvider);

      return Scaffold(
        appBar: AppBar(
          backgroundColor: resolveThemeColor(context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          leadingWidth: 41,
          titleSpacing: 6,
          centerTitle: false,
          leading: const CustomBackBtn(),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(widget.title,
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.title(context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                  fontWeight: MyntFonts.semiBold)),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PledgeFilter(
                  activetabe: widget.filterType,
                  searchQuery: searchQuery,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

