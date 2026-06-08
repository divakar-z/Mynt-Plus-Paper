import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../provider/iop_provider.dart';
import '../../../../provider/transcation_provider.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../../sharedWidget/common_buttons_web.dart';
import '../../../../sharedWidget/no_data_found_web.dart';
import '../../../../models/ipo_model/ipo_pre_close_model.dart';
import '../../../../models/ipo_model/ipo_sme_model.dart';
import '../../../../models/ipo_model/ipo_mainstream_model.dart';
import 'IPO_order_screen/ipo_order_screen_web.dart';
import 'package:url_launcher/url_launcher.dart';

class IpoDetailsSheetWeb extends ConsumerWidget {
  final dynamic ipo;
  final BuildContext parentContext;

  const IpoDetailsSheetWeb({
    super.key,
    required this.ipo,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ipoProvider = ref.watch(ipoProvide);
    final upiProvider = ref.watch(transcationProvider);
    final singlePageData = ipoProvider.iposinglepage?.data;

    final bool isClosed = ipo is Msg;

    String companyName = isClosed
        ? ((ipo as Msg).companyName ?? ipo.name ?? '')
        : (ipo.name ?? '');
    String? imageLink;
    String ipoType = isClosed
        ? ((ipo as Msg).ipoType ?? "IPO")
        : (ipo is SMEIPO ? "SME" : "IPO");

    if (singlePageData != null && singlePageData is Map) {
      if (singlePageData['Company Name'] != null) {
        companyName = singlePageData['Company Name'].toString();
      }
      if (singlePageData['image_link'] != null) {
        imageLink = singlePageData['image_link'].toString();
      }
    }

    final status = isClosed
        ? "Closed"
        : ipostartdate(
          ipo.biddingStartDate ?? '',
      ipo.biddingEndDate ?? '',
    );
    final isOpen = status == "Open";
    final isPreOpen = status == "Pre-open";

    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company Info Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                companyName,
                                style: MyntWebTextStyles.title(
                                  context,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary),
                                  fontWeight: MyntFonts.semiBold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    ipoType,
                                    style: MyntWebTextStyles.body(
                                      context,
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.textSecondaryDark,
                                          light: MyntColors.textSecondary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatusBadge(context, status, isOpen),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Company Logo/Avatar
                        _buildCompanyLogo(context, imageLink, companyName),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Apply Button (hidden for closed IPOs)
                    if (!isClosed) ...[
                      MyntButton(
                      label: isPreOpen ? "Pre Apply" : "Apply",
                      onPressed: () =>
                          _handleApply(context, ref, ipoProvider, upiProvider),
                      isFullWidth: true,
                    ),
                      const SizedBox(height: 24),
                    ],

                    // Details List
                    if (singlePageData != null &&
                        singlePageData is Map &&
                        singlePageData['IpoDetails'] != null) ...[
                      _buildDetailRow(
                          context,
                          "Min amount",
                          isClosed
                              ? _closedMinAmount(ipo as Msg)
                              : convertCurrencyINRStandard(mininv(
                                  double.parse(ipo.minPrice ?? "0").toDouble(),
                                  int.parse(ipo.minBidQuantity ?? "0").toInt())
                              .toInt())),
                      _buildDetailRow(
                          context,
                          "Lot size",
                          singlePageData['IpoDetails']['LotSize']?.toString() ??
                              "--"),
                      _buildDetailRow(
                          context,
                          "Price range",
                          isClosed
                              ? _closedPriceRange(ipo as Msg)
                              : "₹${double.parse(ipo.minPrice ?? "0").toInt()} - ₹${double.parse(ipo.maxPrice ?? "0").toInt()}"),
                      _buildDetailRow(
                          context,
                          "Date",
                          singlePageData['IpoDetails']['IpoDate']?.toString() ??
                              "--"),
                      _buildDetailRow(
                          context,
                          "Issue size",
                          singlePageData['IpoDetails']['tlShares']
                                  ?.toString() ??
                              "--"),
                      _buildDetailRow(
                          context,
                          "Listing at",
                          singlePageData['IpoDetails']['ListingAt']
                                  ?.toString() ??
                              "--"),
                      _buildDetailRow(
                          context,
                          "Listing date",
                          singlePageData['IpoDetails']['ListingDt']
                                  ?.toString() ??
                              "--"),
                      _buildDetailRow(
                          context,
                          "RHP Doc",
                          singlePageData['IpoDetails']['RHP'] != ""
                              ? "Download"
                              : "--",
                          isLink: singlePageData['IpoDetails']['RHP'] != "",
                          onTap: () {
                        if (singlePageData['IpoDetails']['RHP'] != "" &&
                            singlePageData['IpoDetails']['RHP'] != null) {
                          launchUrl(
                              Uri.parse(singlePageData['IpoDetails']['RHP']),
                              mode: LaunchMode.externalApplication);
                        }
                      }),
                    ] else ...[
                      const NoDataFoundWeb(
                        title: "No Details Available",
                        subtitle: "IPO details are not available at the moment.",
                        primaryEnabled: false,
                        secondaryEnabled: false,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => shadcn.closeSheet(context),
            child: Icon(
              Icons.close,
              size: 20,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            "IPO Details",
            style: MyntWebTextStyles.title(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status, bool isOpen) {
    final Color statusColor = isOpen
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: MyntWebTextStyles.bodySmall(
          context,
          color: statusColor,
          fontWeight: MyntFonts.semiBold,
        ),
      ),
    );
  }

  Widget _buildCompanyLogo(
      BuildContext context, String? imageLink, String companyName) {
    return ClipOval(
      child: Container(
        color: resolveThemeColor(context,
            dark: MyntColors.dividerDark, light: MyntColors.divider),
        width: 50,
        height: 50,
        child: imageLink != null && imageLink.isNotEmpty
            ? Container(
                padding: const EdgeInsets.all(8),
                child: CachedNetworkImage(
                  imageUrl: imageLink,
                  memCacheWidth: 100,
                  memCacheHeight: 100,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) =>
                      _buildInitials(companyName),
                ),
              )
            : _buildInitials(companyName),
      ),
    );
  }

  Widget _buildInitials(String name) {
    String initials = "";
    if (name.isNotEmpty) {
      List<String> parts = name.split(" ");
      if (parts.length > 1) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else {
        initials = parts[0][0].toUpperCase();
      }
    }
    return Center(
      child: Text(
        initials,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value,
      {bool isLink = false, VoidCallback? onTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: MyntWebTextStyles.body(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
          ),
          InkWell(
            onTap: onTap,
            child: Text(
              value,
              style: MyntWebTextStyles.body(
                context,
                color: isLink
                    ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary)
                    : resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _closedMinAmount(Msg ipo) {
    final minPrice = ipo.minPrice;
    final minQty = ipo.minBidQu;
    if (minPrice == null || minQty == null || minPrice <= 0 || minQty <= 0) {
      return "--";
    }
    return convertCurrencyINRStandard((minPrice * minQty).toInt());
  }

  String _closedPriceRange(Msg ipo) {
    final range = ipo.priceRange;
    if (range == null || range.isEmpty) return "--";
    final parts = range.split('-').map((s) => s.trim()).toList();
    if (parts.length == 2) {
      return "₹${parts[0]} - ₹${parts[1]}";
    }
    return "₹$range";
  }

  Future<void> _handleApply(BuildContext context, WidgetRef ref,
      IPOProvider ipoProvider, TranctionProvider upiProvider) async {
    ipoProvider.setisSMEPlaceOrderBtnActiveValue = false;
    ipoProvider.setisMainIPOPlaceOrderBtnActiveValue = false;

    // Ensure bank details are available
    if (upiProvider.bankdetails == null ||
        upiProvider.bankdetails?.dATA == null ||
        upiProvider.bankdetails!.dATA!.isEmpty) {
      await upiProvider.fetchfundbank(context);
    }

    // Fetch UPI ID if bank details are now available
    if (upiProvider.bankdetails?.dATA != null &&
        upiProvider.bankdetails!.dATA!.isNotEmpty) {
      final bankData = upiProvider.bankdetails!.dATA![upiProvider.indexss];
      if (bankData.length >= 3) {
        upiProvider.fetchupiIdView(
          bankData[1] ?? "",
          bankData[2] ?? "",
        );
      }
    }

    // Fetch categories while sheet is open to ensure data is ready for the dialog
    if (ipo is SMEIPO) {
      await ipoProvider.smeipocategory(ipo);
    } else {
      await ipoProvider.mainipocategory(ipo as MainIPO);
    }

    if (context.mounted) {
      // Open the draggable order dialog using parent context
      UnifiedIpoOrderScreen.showDraggable(
        context: parentContext,
        ipoData: ipo,
      );

      // Close the side sheet after opening the dialog
      shadcn.closeSheet(context);
    }
  }
}
