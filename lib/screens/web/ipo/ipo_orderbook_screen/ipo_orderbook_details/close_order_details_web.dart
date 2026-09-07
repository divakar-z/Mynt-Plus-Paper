// ignore_for_file: prefer_is_empty, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/global_font_web.dart';
import 'package:mynt_plus/res/web_colors.dart';
import '../../../../../models/ipo_model/ipo_order_book_model.dart';
import '../../../../../sharedWidget/functions.dart';

class IpoCloseOrderDetails extends ConsumerStatefulWidget {
  final IpoOrderBookModel ipoclose;
  const IpoCloseOrderDetails({
    super.key,
    required this.ipoclose,
  });

  @override
  ConsumerState<IpoCloseOrderDetails> createState() =>
      _IpoCloseOrderDetailsState();
}

class _IpoCloseOrderDetailsState extends ConsumerState<IpoCloseOrderDetails> {
  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final isCancelled = widget.ipoclose.reponseStatus == "cancel success";
    final statusText = isCancelled ? "Cancelled" : "Failed";
    final statusColor = isCancelled
        ? (theme.isDarkMode ? WebDarkColors.pending : WebColors.pending)
        : (theme.isDarkMode ? WebDarkColors.error : WebColors.error);

    return Container(
      padding: const EdgeInsets.only(top: 0, bottom: 20, left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Details Section (two columns like holdings)
          _buildOrderDetailsSection(theme, statusText, statusColor),
          
          // Bid Date & Time Section - Show separately below
          if (widget.ipoclose.responseDatetime != null && widget.ipoclose.responseDatetime.toString().isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildBidDateAndTimeWidget(theme),
          ],
          
          // Reason Section - Show separately below
          if (widget.ipoclose.failReason != null && widget.ipoclose.failReason.toString().isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildReasonWidget(theme),
          ],
          
          const SizedBox(height: 20),

          // Bid Details Section
          Text(
            'Bid Details',
            style: WebTextStyles.title(
              isDarkTheme: theme.isDarkMode,
              color: theme.isDarkMode
                  ? WebDarkColors.textPrimary
                  : WebColors.textPrimary,
              fontWeight: FontWeight.w600,
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
                  color: theme.isDarkMode
                      ? WebDarkColors.divider
                      : WebColors.divider,
                  width: 1,
                ),
              ),
              columns: [
                DataColumn(
                  label: Text(
                    'Bid No.',
                    style: WebTextStyles.sub(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? WebDarkColors.textSecondary
                          : WebColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Qty',
                    style: WebTextStyles.sub(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? WebDarkColors.textSecondary
                          : WebColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Price (₹)',
                    style: WebTextStyles.sub(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? WebDarkColors.textSecondary
                          : WebColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Amount (₹)',
                    style: WebTextStyles.sub(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? WebDarkColors.textSecondary
                          : WebColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Cut Off',
                    style: WebTextStyles.sub(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? WebDarkColors.textSecondary
                          : WebColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              rows: List<DataRow>.generate(
                widget.ipoclose.bidDetail!.length,
                (index) {
                  final bid = widget.ipoclose.bidDetail![index];
                  final isCutOff = bid.isCutOffFor(widget.ipoclose.type);
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          "${index + 1}",
                          style: WebTextStyles.sub(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? WebDarkColors.textPrimary
                                : WebColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          bid.quantity!,
                          style: WebTextStyles.sub(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? WebDarkColors.textPrimary
                                : WebColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          widget.ipoclose.type == "BSE"
                              ? bid.rate!
                              : bid.price!,
                          style: WebTextStyles.sub(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? WebDarkColors.textPrimary
                                : WebColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          widget.ipoclose.type == "BSE"
                              ? "₹${getFormatter(noDecimal: true, v4d: false, value: (double.parse(bid.rate!) * double.parse(bid.quantity!)))}"
                              : "₹${getFormatter(noDecimal: true, v4d: false, value: double.parse(bid.amount!).toDouble())}",
                          style: WebTextStyles.sub(
                            isDarkTheme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? WebDarkColors.textPrimary
                                : WebColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(
                        Icon(
                          isCutOff ? Icons.check_circle : Icons.cancel,
                          size: 20,
                          color: isCutOff
                              ? (theme.isDarkMode
                                  ? WebDarkColors.success
                                  : WebColors.success)
                              : (theme.isDarkMode
                                  ? WebDarkColors.error
                                  : WebColors.error),
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
                    widget.ipoclose.applicationNumber.toString(),
                    theme,
                  ),
                  _buildInfoRow(
                    "App No",
                    widget.ipoclose.type == "BSE"
                        ? widget.ipoclose.bidReferenceNumber.toString()
                        : widget.ipoclose.respBid != null
                            ? widget.ipoclose.respBid![0].bidReferenceNumber.toString()
                            : " - ",
                    theme,
                  ),
                  _buildInfoRow(
                    "Quantity",
                    (widget.ipoclose.respBid != null &&
                            widget.ipoclose.respBid!.isNotEmpty)
                        ? widget.ipoclose.respBid![0].quantity.toString()
                        : (widget.ipoclose.bidDetail != null && widget.ipoclose.bidDetail!.isNotEmpty)
                            ? widget.ipoclose.bidDetail![0].quantity.toString()
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
              color: theme.isDarkMode
                  ? WebDarkColors.divider
                  : WebColors.divider,
            ),
            // Right column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    "Price",
                    (widget.ipoclose.bidDetail != null &&
                            widget.ipoclose.bidDetail!.isNotEmpty)
                        ? widget.ipoclose.type == "BSE"
                            ? "₹${widget.ipoclose.bidDetail![0].rate}"
                            : "₹${double.tryParse(widget.ipoclose.bidDetail![0].price.toString())?.toInt() ?? "-"}"
                        : "-",
                    theme,
                  ),
                  _buildInfoRow(
                    "Total Amount",
                    widget.ipoclose.type == "BSE"
                        ? "₹${getFormatter(noDecimal: true, v4d: false, value: double.parse(widget.ipoclose.bidDetail![0].rate!) * double.parse(widget.ipoclose.bidDetail![0].quantity!)).toString()}"
                        : "₹${getFormatter(noDecimal: true, v4d: false, value: double.parse(widget.ipoclose.bidDetail![0].amount!).toDouble())}",
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
            style: WebTextStyles.dialogContent(
              isDarkTheme: theme.isDarkMode,
              color: theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: WebTextStyles.dialogContent(
              isDarkTheme: theme.isDarkMode,
              color: theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textPrimary,
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
            style: WebTextStyles.dialogContent(
              isDarkTheme: theme.isDarkMode,
              color: theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: WebTextStyles.dialogContent(
              isDarkTheme: theme.isDarkMode,
              color: statusColor,
            ).copyWith(fontWeight: FontWeight.w600),
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
          style: WebTextStyles.custom(
            fontSize: 14,
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode ? WebDarkColors.textSecondary : WebColors.textSecondary,
            fontWeight: WebFonts.medium,
          ),
        ),
        const SizedBox(height: 8),
        // Bid Date & Time Text
        Text(
          widget.ipoclose.responseDatetime.toString() == ""
              ? "-"
              : ipodateres(widget.ipoclose.responseDatetime.toString()),
          style: WebTextStyles.dialogContent(
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textPrimary,
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
          style: WebTextStyles.custom(
            fontSize: 14,
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode ? WebDarkColors.textSecondary : WebColors.textSecondary,
            fontWeight: WebFonts.medium,
          ),
        ),
        const SizedBox(height: 8),
        // Reason Text
        Text(
          widget.ipoclose.failReason == "" || widget.ipoclose.failReason == null
              ? " - "
              : widget.ipoclose.failReason.toString(),
          style: WebTextStyles.dialogContent(
            isDarkTheme: theme.isDarkMode,
            color: theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
