// ignore_for_file: prefer_is_empty, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import '../../../../../models/ipo_model/ipo_order_book_model.dart';
import '../../../../../sharedWidget/functions.dart';

class IpoOpenOrderDetails extends ConsumerStatefulWidget {
  final IpoOrderBookModel ipodetails;
  const IpoOpenOrderDetails({
    super.key,
    required this.ipodetails, 
  });

  @override
  ConsumerState<IpoOpenOrderDetails> createState() =>
      _IpoOpenOrderDetailsState();
}

class _IpoOpenOrderDetailsState extends ConsumerState<IpoOpenOrderDetails> {
  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final isSuccess = widget.ipodetails.reponseStatus == "new success";
    final statusText = isSuccess ? "Success" : "Pending";
    final statusColor = isSuccess
        ? resolveThemeColor(
            context,
            dark: MyntColors.profitDark,
            light: MyntColors.profit,
          )
        : MyntColors.pending;

    return Container(
      padding: const EdgeInsets.only(top: 0, bottom: 20, left: 20, right: 20),
                  child: Column(
        mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
          // Order Details Section (two columns like holdings)
          _buildOrderDetailsSection(theme, statusText, statusColor),
          
          // Bid Date & Time Section - Show separately below
          if (widget.ipodetails.responseDatetime != null && widget.ipodetails.responseDatetime.toString().isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildBidDateAndTimeWidget(theme),
          ],
          
          // Reason Section - Show separately below
          if (widget.ipodetails.failReason != null && widget.ipodetails.failReason.toString().isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildReasonWidget(theme),
          ],
          
          const SizedBox(height: 20),
          
          // Bid Details Section
          Text(
            'Bid Details',
            style: MyntWebTextStyles.title(
              context,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary,
              ),
              fontWeight: MyntFonts.semiBold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            // decoration: BoxDecoration(
            //   color: theme.isDarkMode
            //       ? WebDarkColors.backgroundTertiary
            //       : WebColors.backgroundTertiary,
            //   borderRadius: BorderRadius.circular(5),
            // ),
                                              child: DataTable(
              columnSpacing: 24,
              horizontalMargin: 16,
              headingRowHeight: 40,
              dataRowHeight: 48,
              headingRowColor: WidgetStateProperty.all(Colors.transparent),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                return Colors.transparent;
              }),
              dividerThickness: 1,
                                                border: TableBorder(
                                                  horizontalInside: BorderSide(
                    // color: shadcn.Theme.of(context).colorScheme.border
                    width: 1,
                  ),
                ),
                                                columns: [
                                                  DataColumn(
                  label: Text(
                    'Bid No.',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary,
                      ),
                      fontWeight: MyntFonts.semiBold,
                    ),
                                                    ),
                                                  ),
                                                  DataColumn(
                  label: Text(
                    'Qty',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary,
                      ),
                      fontWeight: MyntFonts.semiBold,
                    ),
                  ),
                                                  ),
                                                  DataColumn(
                  label: Text(
                    'Price (₹)',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary,
                      ),
                      fontWeight: MyntFonts.semiBold,
                    ),
                  ),
                                                  ),
                                                  DataColumn(
                  label: Text(
                    'Amount (₹)',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary,
                      ),
                      fontWeight: MyntFonts.semiBold,
                    ),
                              ),
                                                  ),
                                                  DataColumn(
                  label: Text(
                    'Cut Off',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary,
                      ),
                      fontWeight: MyntFonts.semiBold,
                    ),
                                              ),
                                                  ),
                                                ],
                                                rows: List<DataRow>.generate(
                widget.ipodetails.bidDetail!.length,
                                                  (index) {
                  final bid = widget.ipodetails.bidDetail![index];
                  final isCutOff = bid.isCutOffFor(widget.ipodetails.type);
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                                                                "${index + 1}",
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                                                      DataCell(
                        Text(
                          bid.quantity!,
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                        ),
                                                      ),
                                                      DataCell(
                        Text(
                          widget.ipodetails.type == "BSE"
                              ? bid.rate.toString()
                                                                : "${double.parse(bid.price.toString()).toInt()}",
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                        ),
                                                      ),
                                                      DataCell(
                        Text(
                          widget.ipodetails.type == "BSE"
                                                                ? "₹${getFormatter(noDecimal: true, v4d: false, value: (double.parse(bid.rate!) * double.parse(bid.quantity!)))}"
                                                                : "₹${getFormatter(noDecimal: true, v4d: false, value: double.parse(bid.amount!).toDouble())}",
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                                              ),
                                            ),
                      DataCell(
                        Icon(
                          isCutOff ? Icons.check_circle : Icons.cancel,
                          size: 20,
                                                          color: isCutOff
                              ? resolveThemeColor(
                                  context,
                                  dark: MyntColors.profitDark,
                                  light: MyntColors.profit,
                                )
                              : resolveThemeColor(
                                  context,
                                  dark: MyntColors.lossDark,
                                  light: MyntColors.loss,
                                ),
                                              ),
                                            ),
                                          ],
                  );
                                                  },
                                                ),
                                              ),
                                            ),

                    ],
                  ),
    );
  }

  Widget _buildOrderDetailsSection(ThemesProvider theme, String statusText, Color statusColor) {
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
                  _buildInfoRow(
                    "Order ID",
                    widget.ipodetails.applicationNumber.toString(),
                    theme,
                  ),
                                        _buildInfoRow(
                    "App No",
                                          widget.ipodetails.type == "BSE"
                        ? widget.ipodetails.bidReferenceNumber.toString()
                        : widget.ipodetails.respBid != null
                            ? widget.ipodetails.respBid![0].bidReferenceNumber.toString()
                                                  : " - ",
                                          theme,
                                        ),
                                        _buildInfoRow(
                    "Quantity",
                                          (widget.ipodetails.respBid != null &&
                            widget.ipodetails.respBid!.isNotEmpty)
                        ? widget.ipodetails.respBid![0].quantity.toString()
                                              : "-",
                                          theme,
                                        ),
                  _buildInfoRowWithStatus(
                    "Status",
                    statusText,
                    statusColor,
                    theme,
                  ),
                                  ],
                                ),
                              ),
            // Vertical divider
            Container(
              width: 0.5,
              margin: const EdgeInsets.symmetric(horizontal: 16),
                // color: shadcn.Theme.of(context).colorScheme.border
            ),
            // Right column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                                        _buildInfoRow(
                                          "Price",
                    (widget.ipodetails.bidDetail != null &&
                            widget.ipodetails.bidDetail!.isNotEmpty)
                                              ? widget.ipodetails.type == "BSE"
                            ? "₹${widget.ipodetails.bidDetail![0].rate}"
                            : "₹${double.tryParse(widget.ipodetails.bidDetail![0].price.toString())?.toInt() ?? "-"}"
                                              : "-",
                                          theme,
                                        ),
                  _buildInfoRow(
                    "Total Amount",
                    widget.ipodetails.type == "BSE"
                        ? "₹${getFormatter(noDecimal: true, v4d: false, value: double.parse(widget.ipodetails.bidDetail![0].rate!) * double.parse(widget.ipodetails.bidDetail![0].quantity!)).toString()}"
                        : "₹${getFormatter(noDecimal: true, v4d: false, value: double.parse(widget.ipodetails.bidDetail![0].amount!).toDouble())}",
                    theme,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
  }

  Widget _buildInfoRow(String title, String value, ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: MyntWebTextStyles.bodySmall(
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
    );
  }

  Widget _buildInfoRowWithStatus(String title, String value, Color statusColor, ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: statusColor,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBidDateAndTimeWidget(ThemesProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bid Date & Time Title
        Text(
          "Bid Date & Time:",
          style: MyntWebTextStyles.bodySmall(
            context,
            color: resolveThemeColor(
              context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.textSecondary,
            ),
            fontWeight: MyntFonts.medium,
          ),
      ),
      const SizedBox(height: 8),
        // Bid Date & Time Text
        Text(
          widget.ipodetails.responseDatetime.toString() == ""
              ? "-"
              : ipodateres(widget.ipodetails.responseDatetime.toString()),
          style: MyntWebTextStyles.bodySmall(
            context,
            color: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonWidget(ThemesProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reason Title
        Text(
          "Reason:",
          style: MyntWebTextStyles.bodySmall(
            context,
            color: resolveThemeColor(
              context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.textSecondary,
            ),
            fontWeight: MyntFonts.medium,
          ),
        ),
        const SizedBox(height: 8),
        // Reason Text
        Text(
          widget.ipodetails.failReason == "" || widget.ipodetails.failReason == null
              ? "Order placed successfully"
              : widget.ipodetails.failReason.toString(),
          style: MyntWebTextStyles.bodySmall(
            context,
            color: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
