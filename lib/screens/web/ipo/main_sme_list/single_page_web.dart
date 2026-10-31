import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mynt_plus/models/ipo_model/ipo_mainstream_model.dart';
import 'package:mynt_plus/models/ipo_model/ipo_sme_model.dart';
import 'package:mynt_plus/provider/transcation_provider.dart';
import 'package:mynt_plus/res/global_state_text.dart';
import 'package:mynt_plus/routes/route_names.dart';
import 'package:mynt_plus/sharedWidget/custom_drag_handler.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../provider/iop_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/res.dart';
import '../../../../sharedWidget/ipo_time_line.dart';

class MainSmeSinglePage extends StatefulWidget {
  final String ipotype;
  final String startdate;
  final String enddate;
  final String mininv;
  final String pricerange;
  final String ipodetails;
  final bool isDialog; // Flag to indicate if used in dialog

  const MainSmeSinglePage({
    super.key,
    required this.ipotype,
    required this.startdate,
    required this.enddate,
    required this.mininv,
    required this.pricerange,
    required this.ipodetails,
    this.isDialog = false,
  });

  @override
  State<MainSmeSinglePage> createState() => _MainSmeSinglePageState();
}

class _MainSmeSinglePageState extends State<MainSmeSinglePage> {
  static const double _initialChildSize = 0.88;
  static const double _maxChildSize = 0.99;
  bool _isExpanded = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final theme = ref.watch(themeProvider);
        final singlepage = ref.watch(ipoProvide);
        final upi = ref.watch(transcationProvider);

        if (singlepage.iposinglepage?.data == null ||
            singlepage.iposinglepage?.data == "no data" ||
            singlepage.iposinglepage?.data is! Map) {
          return const _NoDataWidget();
        }

        // If used in dialog, skip DraggableScrollableSheet and SafeArea
        if (widget.isDialog) {
          return _IPODetailsContainer(
            theme: theme,
            singlepage: singlepage,
            upi: upi,
            ref: ref,
            widget: widget,
            scrollController: _scrollController,
            isExpanded: _isExpanded,
            onExpandToggle: () => setState(() => _isExpanded = !_isExpanded),
          );
        }

        // Original bottom sheet implementation
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: _initialChildSize,
            maxChildSize: _maxChildSize,
            expand: false,
            builder: (context, scrollController) {
              return _IPODetailsContainer(
                theme: theme,
                singlepage: singlepage,
                upi: upi,
                ref: ref,
                widget: widget,
                scrollController: scrollController,
                isExpanded: _isExpanded,
                onExpandToggle: () => setState(() => _isExpanded = !_isExpanded),
              );
            },
          ),
        );
      },
    );
  }
}

class _NoDataWidget extends StatelessWidget {
  const _NoDataWidget();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CustomDragHandler(),
        SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 250),
          child: NoDataFoundWeb(),
        ),
      ],
    );
  }
}

class _IPODetailsContainer extends StatelessWidget {
  final ThemesProvider theme;
  final dynamic singlepage;
  final dynamic upi;
  final MainSmeSinglePage widget;
  final ScrollController scrollController;
  final bool isExpanded;
  final VoidCallback onExpandToggle;
  final WidgetRef ref;

  const _IPODetailsContainer({
    required this.theme,
    required this.singlepage,
    required this.upi,
    required this.widget,
    required this.scrollController,
    required this.isExpanded,
    required this.onExpandToggle,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isDialog = widget.isDialog;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: isDialog 
            ? BorderRadius.circular(0) // No border radius for dialog (handled by parent)
            : const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
        color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
        border: isDialog 
            ? null // No border for dialog (handled by parent)
            : Border(
                top: BorderSide(
                  color: theme.isDarkMode
                      ? colors.textSecondaryDark.withOpacity(0.5)
                      : colors.colorWhite,
                ),
                left: BorderSide(
                  color: theme.isDarkMode
                      ? colors.textSecondaryDark.withOpacity(0.5)
                      : colors.colorWhite,
                ),
                right: BorderSide(
                  color: theme.isDarkMode
                      ? colors.textSecondaryDark.withOpacity(0.5)
                      : colors.colorWhite,
                ),
              ),
      ),
      child: isDialog
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // _buildStatusBanner(),
                // Company header is now in the dialog header, not here
                // Apply button is shown in the table on hover, not here
                // _buildApplyButton(context, ref),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: scrollController,
                    child: Column(
                      children: [
                        _buildScrollableContent(),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // _buildStatusBanner(),
                _buildCompanyHeader(),
                // _buildApplyButton(context, ref),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    controller: scrollController,
                    child: Column(
                      children: [
                        _buildScrollableContent(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusBanner() {
    if (singlepage.iposinglepage!.data["status"] == "CLOSED") {
      return const SizedBox();
    }

    return Container(
      height: 35,
      color: const Color(0xFFE6F7E4),
      child: Center(
        child: Text(
          "This IPO application is open for ${singlepage.iposinglepage!.data!['CloseAt']} days",
          style: _textStyle(colors.colorBlack, 12, FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildCompanyHeader() {
    return ListTile(
      leading: _buildCompanyLogo(),
      title: _buildCompanyInfo(),
    );
  }

  Widget _buildCompanyLogo() {
    return ClipOval(
      child: Container(
        color: colors.colorDivider.withOpacity(.3),
        width: 50,
        height: 50,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: CachedNetworkImage(
            imageUrl: singlepage.iposinglepage!.data!['image_link'].toString(),
            memCacheWidth: 100,
            memCacheHeight: 100,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorWidget: (context, url, error) => const Text('Failed to load image'),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget.titleText(
          text: "${singlepage.iposinglepage!.data!['Company Name']} ",
          theme: false,
          fw: 1,
          color: theme.isDarkMode
              ? colors.textPrimaryDark
              : colors.textPrimaryLight,
        ),
        const SizedBox(height: 8),
        _buildStatusChips(),
      ],
    );
  }

  Widget _buildStatusChips() {
    return Row(
      children: [
        _buildTypeChip(),
        const SizedBox(width: 10),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildStatusChip() {
    final status = ipostartdate(widget.startdate, widget.enddate);
    final isOpen = status == "Open";
    // Open green, Pre-open grey, Closed red (same on every IPO screen).
    final isPreOpen = status == "Pre-open";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color:isOpen
                                  ? theme.isDarkMode
                                      ? colors.profitDark.withOpacity(0.2)
                                      : colors.profitLight.withOpacity(0.2)
                                  : isPreOpen
                                      ? (theme.isDarkMode
                                          ? colors.textSecondaryDark.withOpacity(0.2)
                                          : colors.textSecondaryLight.withOpacity(0.2))
                                  : theme.isDarkMode
                                      ? colors.lossDark.withOpacity(0.2)
                                      : colors.lossLight.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextWidget.paraText(
        text: status.toUpperCase(),
        theme: false,
        fw: 3,
        color: isOpen
            ? theme.isDarkMode
                ? colors.profitDark
                : colors.profitLight
            : isPreOpen
                ? (theme.isDarkMode
                    ? colors.textSecondaryDark
                    : colors.textSecondaryLight)
            : theme.isDarkMode
                ? colors.lossDark
                : colors.lossLight,
      ),
    );
  }

  Widget _buildTypeChip() {
    return TextWidget.paraText(
      text: widget.ipotype,
      theme: false,
      fw: 0,
      color: theme.isDarkMode
          ? colors.textSecondaryDark
          : colors.textSecondaryLight,
    );
  }

  Widget _buildScrollableContent() {
    return Column(
      children: [
        _IPODetailsSection(
          theme: theme,
          singlepage: singlepage,
          widget: widget,
        ),
        _buildDivider(),
        _SubscriptionSection(theme: theme, singlepage: singlepage),
        _IPOTimelineSection(theme: theme, singlepage: singlepage),
        _buildDivider(),
        // _AboutCompanySection(
        //   theme: theme,
        //   singlepage: singlepage,
        //   isExpanded: isExpanded,
        //   onExpandToggle: onExpandToggle,
        // ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        color: theme.isDarkMode ? colors.darkColorDivider : colors.colorDivider,
      ),
    );
  }

  Widget _buildApplyButton(BuildContext context, WidgetRef ref) {
    bool isApplyButtonEnabled = true;
    // if (singlepage.iposinglepage!.data['status'] == "CLOSED") {
    //   return const SizedBox();
    // }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 45),
            side: BorderSide(color: colors.btnOutlinedBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            backgroundColor: colors.primary,
          ),
          onPressed: () {
            if (isApplyButtonEnabled) {
              isApplyButtonEnabled = false;
              ref.read(ipoProvide).setSinglepageapply(true);
              _handleApplyIPO(context);
            } else {
              return;
            }
          },
          child: TextWidget.subText(
            text: "Apply",
            theme: false,
            fw: 2,
            color: colors.colorWhite,
          ),
        ),
      ),
    );
  }

  Future<void> _handleApplyIPO(BuildContext context) async {
    if (widget.ipodetails.isNotEmpty) {
      try {
        final Map<String, dynamic> decodedJson = jsonDecode(widget.ipodetails);

        // Fetch UPI ID View
        if (upi.bankdetails?.dATA != null && upi.bankdetails!.dATA!.isNotEmpty) {
          await upi.fetchupiIdView(
            upi.bankdetails!.dATA![upi.indexss][1],
            upi.bankdetails!.dATA![upi.indexss][2],
          );
        }

        if (context.mounted) {
          if (decodedJson['key'] == "SME") {
            final ipoOrderbookData = SMEIPO.fromJson(decodedJson);
            await singlepage.smeipocategory(ipoOrderbookData);
            Navigator.pushNamed(
              context,
              Routes.applyIPO,
              arguments: ipoOrderbookData,
            );
          } else {
            final ipoOrderbookData = MainIPO.fromJson(decodedJson);
            await singlepage.mainipocategory(ipoOrderbookData);
            Navigator.pushNamed(
              context,
              Routes.applyIPO,
              arguments: ipoOrderbookData,
            );
          }
        }
      } catch (e) {
      }
    }
  }

  static TextStyle _textStyle(
      Color color, double fontSize, FontWeight fWeight) {
    return TextStyle(
      fontWeight: fWeight,
      color: color,
      fontSize: fontSize,
    );
  }
}

class _IPODetailsSection extends StatelessWidget {
  final ThemesProvider theme;
  final dynamic singlepage;
  final MainSmeSinglePage widget;

  const _IPODetailsSection({
    required this.theme,
    required this.singlepage,
    required this.widget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   "IPO Details",
          //   style: _textStyle(
          //     theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
          //     14,
          //     FontWeight.w600,
          //   ),
          // ),
          // const SizedBox(height: 16),
          _rowOfInfoData(
            "Min amount",
            widget.mininv,
          ),
          const SizedBox(height: 8),

          _rowOfInfoData(
              "Lot size",
              singlepage.iposinglepage!.data["IpoDetails"]["LotSize"] == "" ||
                      singlepage.iposinglepage!.data["IpoDetails"]["LotSize"] ==
                          null
                  ? "--"
                  : "${singlepage.iposinglepage!.data!["IpoDetails"]['LotSize']}"),
          const SizedBox(height: 8),

          _rowOfInfoData(
            "Price range",
            widget.pricerange,
          ),
          const SizedBox(height: 8),

          _rowOfInfoData(
            "Date",
            singlepage.iposinglepage!.data["IpoDetails"]["IpoDate"],
          ),
          const SizedBox(height: 8),

          _rowOfInfoData(
            "Issue size",
            singlepage.iposinglepage!.data["IpoDetails"]["tlShares"],
          ),
          const SizedBox(height: 8),
          _rowOfInfoData(
            "Listing at",
            singlepage.iposinglepage!.data["IpoDetails"]["ListingAt"] == "" ||
                    singlepage.iposinglepage!.data["IpoDetails"]["ListingAt"] ==
                        null
                ? "--"
                : "${singlepage.iposinglepage!.data['IpoDetails']['ListingAt']}",
          ),
          const SizedBox(height: 8),
          _rowOfInfoData(
            "Listing date",
            singlepage.iposinglepage!.data["IpoDetails"]["ListingDt"],
          ),
          const SizedBox(height: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget.subText(
                    text: "RHP Doc",
                    theme: false,
                    color: theme.isDarkMode
                        ? colors.textSecondaryDark
                        : colors.textSecondaryLight,
                    fw: 3),
                Material(
                  color: Colors.transparent,
                  shape: const RoundedRectangleBorder(),
                  child: InkWell(
                    customBorder: const RoundedRectangleBorder(),
                    splashColor: theme.isDarkMode
                        ? colors.splashColorDark
                        : colors.splashColorLight,
                    highlightColor: theme.isDarkMode
                        ? colors.highlightDark
                        : colors.highlightLight,
                    onTap: singlepage.iposinglepage!.data['IpoDetails']
                                ['RHP'] !=
                            ""
                        ? () => _launchURL(singlepage
                            .iposinglepage!.data!['IpoDetails']['RHP'])
                        : () {},
                    child: TextWidget.subText(
                        text: singlepage.iposinglepage!.data["IpoDetails"]
                                        ["RHP"] ==
                                    "" ||
                                singlepage.iposinglepage!.data["IpoDetails"]
                                        ["RHP"] ==
                                    null
                            ? "--"
                            : "Download",
                        theme: false,
                        color: theme.isDarkMode
                            ? colors.primaryDark
                            : colors.primaryLight,
                        fw: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(
                color:
                    theme.isDarkMode ? colors.dividerDark : colors.dividerLight,
                thickness: 0)
          ]),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _rowOfInfoData(String title1, String value1) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextWidget.subText(
              text: title1,
              theme: false,
              color: theme.isDarkMode
                  ? colors.textSecondaryDark
                  : colors.textSecondaryLight,
              fw: 0),
          TextWidget.subText(
              text: value1,
              theme: false,
              color: theme.isDarkMode
                  ? colors.textPrimaryDark
                  : colors.textPrimaryLight,
              fw: 0),
        ],
      ),
      const SizedBox(height: 8),
      Divider(
          color: theme.isDarkMode ? colors.dividerDark : colors.dividerLight,
          thickness: 0)
    ]);
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch "$url"';
    }
  }

  static TextStyle _textStyle(
      Color color, double fontSize, FontWeight fWeight) {
    return TextStyle(
      fontWeight: fWeight,
      color: color,
      fontSize: fontSize,
    );
  }
}

class _SubscriptionSection extends StatefulWidget {
  final ThemesProvider theme;
  final dynamic singlepage;

  const _SubscriptionSection({
    required this.theme,
    required this.singlepage,
  });

  @override
  State<_SubscriptionSection> createState() => _SubscriptionSectionState();
}

class _SubscriptionSectionState extends State<_SubscriptionSection> {
  bool showsubcription = false;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final subscriptionData =
            widget.singlepage.iposinglepage!.data['subsciption'];

        if (subscriptionData == null || subscriptionData.isEmpty) {
          return Container();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              shape: const RoundedRectangleBorder(),
              child: InkWell(
                customBorder: const RoundedRectangleBorder(),
                splashColor: widget.theme.isDarkMode
                    ? colors.splashColorDark
                    : colors.splashColorLight,
                highlightColor: widget.theme.isDarkMode
                    ? colors.highlightDark
                    : colors.highlightLight,
                onTap: () {
                  setState(() {
                    showsubcription = !showsubcription;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextWidget.subText(
                                text: "Subscription Status",
                                theme: false,
                                fw: 0,
                                color: widget.theme.isDarkMode
                                    ? colors.textPrimaryDark
                                    : colors.textPrimaryLight,
                              ),
                              const SizedBox(height: 4),
                              TextWidget.paraText(
                                text:
                                    "Subscribed by ${widget.singlepage.iposinglepage!.data['tlSub']['Subscription (times)']} times",
                                theme: false,
                                fw: 0,
                                color: widget.theme.isDarkMode
                                    ? colors.textSecondaryDark
                                    : colors.textSecondaryLight,
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Container(
                            height: 45,
                            width: 26,
                            padding: const EdgeInsets.all(7),
                            child: SvgPicture.asset(
                              assets.rightarrowcur,
                              width: 12,
                              height: 12,
                              color: colors.iconColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                color: widget.theme.isDarkMode
                    ? colors.darkColorDivider
                    : colors.colorDivider,
              ),
            ),
            showsubcription
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: subscriptionData.length,
                          separatorBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Divider(color: colors.colorDivider),
                          ),
                          itemBuilder: (context, index) {
                            final category = subscriptionData[index]
                                    ["Category"] ??
                                "Unknown";
                            final subscriptionTimes = subscriptionData[index]
                                        ["Subscription (times)"]
                                    ?.toString() ??
                                "N/A";

                            return _ipoDateDisplay(category, subscriptionTimes);
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  )
                : const SizedBox(),
          ],
        );
      },
    );
  }

  Widget _ipoDateDisplay(String text, String value) {
    double maxValue = 100;
    double convertedValue = 0.0;

    try {
      convertedValue = double.parse(value) * 100;
    } catch (e) {
      convertedValue = 0.0;
    }

    double progress = (convertedValue / maxValue);

    return Column(
      children: [
        Row(
          children: [
            TextWidget.subText(
              text: _getInvestorCategory(text),
              theme: false,
              fw: 0,
              color: widget.theme.isDarkMode
                  ? colors.textPrimaryDark
                  : colors.textPrimaryLight,
            ),
            TextWidget.subText(
              text: "$value x",
              theme: false,
              fw: 0,
              color: widget.theme.isDarkMode
                  ? colors.textPrimaryDark
                  : colors.textPrimaryLight,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: progress,
            backgroundColor: Colors.grey[300],
            color: progress < 1
                ? const Color.fromARGB(255, 233, 196, 7)
                : const Color(0xFF148564),
          ),
        ),
        const SizedBox(width: 20),
      ],
    );
  }

  String _getInvestorCategory(String category) {
    switch (category) {
      case "QIB":
        return "Qualified Institution";
      case "NII*":
        return "Non Institution";
      case "Retail":
        return "Retail";
      case "bNII (bids above ₹10L)":
        return "Non Individual - big";
      case "sNII (bids below ₹10L)":
        return "Non Individual - small";
      case "NII":
        return "Non Individual";
      default:
        return category;
    }
  }

  static TextStyle _textStyle(
      Color color, double fontSize, FontWeight fWeight) {
    return TextStyle(
      fontWeight: fWeight,
      color: color,
      fontSize: fontSize,
    );
  }
}

class _IPOTimelineSection extends StatelessWidget {
  final ThemesProvider theme;
  final dynamic singlepage;

  const _IPOTimelineSection({
    required this.theme,
    required this.singlepage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Text(
          //   "IPO TimeLine",
          //   style: _textStyle(
          //     !theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
          //     14,
          //     FontWeight.w600,
          //   ),
          // ),
          ListView.builder(
            itemCount:
                singlepage.iposinglepage!.data['IPO_Timeline'].length - 1,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemBuilder: (BuildContext context, int index) {
              final isFirst = index == 0;
              final isLasts = index ==
                  singlepage.iposinglepage!.data['IPO_Timeline'].length - 2;

              return IpoTimeLineWidget(
                isfFrist: isFirst,
                isLast: isLasts,
                orderHistoryData: singlepage.iposinglepage!.data['IPO_Timeline']
                    [index],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AboutCompanySection extends StatelessWidget {
  final ThemesProvider theme;
  final dynamic singlepage;
  final bool isExpanded;
  final VoidCallback onExpandToggle;

  const _AboutCompanySection({
    required this.theme,
    required this.singlepage,
    required this.isExpanded,
    required this.onExpandToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "About the company",
            style: _textStyle(
              theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
              14,
              FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding:
                const EdgeInsets.only(left: 0, right: 0, top: 8, bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  singlepage.iposinglepage!.data['about'],
                  textAlign: TextAlign.justify,
                  style: _textStyle(
                    theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                    12,
                    FontWeight.w400,
                  ).copyWith(height: 1.7),
                  maxLines: isExpanded ? null : 3,
                  overflow:
                      isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 0)),
                  onPressed: onExpandToggle,
                  child: Text(
                    isExpanded ? 'Read Less' : 'Read More',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0037B7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle _textStyle(
      Color color, double fontSize, FontWeight fWeight) {
    return TextStyle(
      fontWeight: fWeight,
      color: color,
      fontSize: fontSize,
    );
  }
}
