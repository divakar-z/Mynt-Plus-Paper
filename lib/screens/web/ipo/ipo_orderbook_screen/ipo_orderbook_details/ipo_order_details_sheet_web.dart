import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../models/ipo_model/ipo_order_book_model.dart';
import '../../../../../sharedWidget/functions.dart';

class IpoOrderDetailsSheetWeb extends ConsumerWidget {
  final IpoOrderBookModel order;

  /// Close orders are cancelled/failed bids, so there is no UPI mandate left to
  /// pay — the Payment row is hidden for them.
  final bool isCloseOrder;

  const IpoOrderDetailsSheetWeb({
    super.key,
    required this.order,
    this.isCloseOrder = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String status = order.reponseStatus?.toLowerCase() ?? "";
    final bool isSuccess = status == "new success";
    final bool isCancelled = status == "cancel success";
    final bool isPending = status == "pending";

    final String statusText = isSuccess
        ? "Success"
        : isCancelled
            ? "Cancelled"
            : isPending
                ? "Pending"
                : "Failed";

    final Color statusColor = isSuccess
        ? resolveThemeColor(
            context,
            dark: MyntColors.profitDark,
            light: MyntColors.profit,
          )
        : isCancelled || isPending
            ? MyntColors.pending
            : resolveThemeColor(
                context,
                dark: MyntColors.lossDark,
                light: MyntColors.loss,
              );

    // Payment status comes from the order book response (`upiPaymentStatus`).
    // The field is parsed with `.toString()`, so a missing value arrives as the
    // literal "null" rather than null — treat that as "not yet reported".
    // The bid with the largest amount — the one the tables show.
    BidDetail? largestBid;
    for (final bid in order.bidDetail ?? <BidDetail>[]) {
      if (largestBid == null || _bidAmount(bid) > _bidAmount(largestBid)) {
        largestBid = bid;
      }
    }

    final String upiPayment = order.upiPaymentStatus?.trim() ?? "";
    final bool hasPaymentStatus =
        upiPayment.isNotEmpty && upiPayment.toLowerCase() != "null";
    final String paymentText = hasPaymentStatus ? upiPayment : "Pending";
    final bool paymentFailed = hasPaymentStatus &&
        RegExp(r'fail|reject|expire|decline|cancel')
            .hasMatch(upiPayment.toLowerCase());
    final Color paymentColor = !hasPaymentStatus
        ? MyntColors.pending
        : paymentFailed
            ? resolveThemeColor(
                context,
                dark: MyntColors.lossDark,
                light: MyntColors.loss,
              )
            : resolveThemeColor(
                context,
                dark: MyntColors.profitDark,
                light: MyntColors.profit,
              );

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
                    // Company Name
                    Text(
                      order.companyName ?? '-',
                      style: MyntWebTextStyles.title(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // // Cancel Order Button
                    // if (order.reponseStatus != "new success")
                    //   MyntOutlinedButton(
                    //     label: "Cancel Order",
                    //     onPressed: () {
                    //       showDialog(
                    //         context: context,
                    //         builder: (BuildContext context) {
                    //           return IpoCancelAlert(ipocancel: order);
                    //         },
                    //       );
                    //     },
                    //     isFullWidth: true,
                    //     // style: OutlinedButton.styleFrom(
                    //     //   side: const BorderSide(color: Color(0xFF3B82F6)),
                    //     //   foregroundColor: const Color(0xFF3B82F6),
                    //     // ),
                    //   ),

                    const SizedBox(height: 24),

                    // Details List
                    _buildDetailRow(context, "Order Id",
                        order.applicationNumber.toString()),
                    _buildDetailRowWithBadge(
                        context, "Order Status", statusText, statusColor),
                    if (!isCloseOrder)
                      _buildDetailRowWithBadge(
                          context, "Payment", paymentText, paymentColor),
                    _buildDetailRow(
                      context,
                      "App no",
                      order.type == "BSE"
                          ? order.bidReferenceNumber.toString()
                          : (order.respBid != null && order.respBid!.isNotEmpty)
                              ? order.respBid![0].bidReferenceNumber.toString()
                              : "-",
                    ),
                    // _buildDetailRow(
                    //   context,
                    //   "Qty",
                    //   (order.respBid != null && order.respBid!.isNotEmpty)
                    //       ? order.respBid![0].quantity.toString()
                    //       : "-",
                    // ),
                    // _buildDetailRow(
                    //   context,
                    //   "Price",
                    //   (order.bidDetail != null && order.bidDetail!.isNotEmpty)
                    //       ? order.type == "BSE"
                    //           ? "₹${order.bidDetail![0].rate}"
                    //           : "₹${double.tryParse(order.bidDetail![0].price.toString())?.toInt() ?? "-"}"
                    //       : "-",
                    // ),
                    // _buildDetailRow(
                    //   context,
                    //   "Total amount",
                    //   order.type == "BSE"
                    //       ? "₹${getFormatter(noDecimal: true, v4d: false, value: double.parse(order.bidDetail![0].rate!) * double.parse(order.bidDetail![0].quantity!))}"
                    //       : (order.bidDetail != null &&
                    //               order.bidDetail!.isNotEmpty)
                    //           ? "₹${getFormatter(noDecimal: true, v4d: false, value: double.parse(order.bidDetail![0].amount!).toDouble())}"
                    //           : "0",
                    // ),
                    // Bug fix: Qty / Price / Total amount showed the first bid;
                    // show the largest bid, the amount the tables show.
                    _buildDetailRow(
                      context,
                      "Qty",
                      largestBid?.quantity?.toString() ?? "-",
                    ),
                    _buildDetailRow(
                      context,
                      "Price",
                      largestBid == null
                          ? "-"
                          : order.type == "BSE"
                              ? "₹${largestBid.rate}"
                              : "₹${double.tryParse(largestBid.price.toString())?.toInt() ?? "-"}",
                    ),
                    _buildDetailRow(
                      context,
                      "Total amount",
                      largestBid == null
                          ? "0"
                          : "₹${getFormatter(noDecimal: true, v4d: false, value: _bidAmount(largestBid))}",
                    ),
                    _buildDetailRow(
                      context,
                      "Bid Date & Time",
                      order.responseDatetime.toString() == ""
                          ? "-"
                          : ipodateres(order.responseDatetime.toString()),
                    ),
                    _buildDetailRow(
                      context,
                      "Reason",
                      order.failReason == "" || order.failReason == null
                          ? "Order placed successfully"
                          : order.failReason.toString(),
                    ),

                    const SizedBox(height: 32),

                    // Bid Details Table
                    Text(
                      "Single bid order",
                      style: MyntWebTextStyles.body(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                        fontWeight: MyntFonts.semiBold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBidTable(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // BSE bids carry rate x quantity; NSE bids carry the amount.
  double _bidAmount(BidDetail bid) {
    return order.type == "BSE"
        ? (double.tryParse(bid.rate ?? "0") ?? 0) *
            (double.tryParse(bid.quantity ?? "0") ?? 0)
        : double.tryParse(bid.amount?.toString() ?? "0") ?? 0;
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
            "Order Details",
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

  Widget _buildDetailRow(BuildContext context, String label, String value) {
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
          Text(
            value,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithBadge(
      BuildContext context, String label, String value, Color statusColor) {
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
            style: MyntWebTextStyles.bodySmall(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: statusColor.withOpacity(0.5), width: 0.5),
            ),
            child: Text(
              value,
              style: MyntWebTextStyles.bodySmall(
                context,
                color: statusColor,
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBidTable(BuildContext context) {
    final bids = order.bidDetail ?? [];

    return Column(
      children: [
        // Table Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _tableHeaderCell("Bid", context),
            _tableHeaderCell("Qty", context),
            _tableHeaderCell("Price", context),
            _tableHeaderCell("Amount", context),
            _tableHeaderCell("Cut off", context, alignRight: true),
          ],
        ),
        const SizedBox(height: 12),
        // Table Rows
        ...bids.asMap().entries.map((entry) {
          final index = entry.key;
          final bid = entry.value;
          final isCutOff = bid.isCutOffFor(order.type);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _tableDataCell("${index + 1}", context),
                _tableDataCell(bid.quantity ?? "0", context),
                _tableDataCell(
                    order.type == "BSE"
                        ? bid.rate.toString()
                        : "${double.tryParse(bid.price.toString())?.toInt() ?? "-"}",
                    context),
                _tableDataCell(
                    order.type == "BSE"
                        ? "₹${getFormatter(noDecimal: true, v4d: false, value: (double.parse(bid.rate!) * double.parse(bid.quantity!)))}"
                        : "₹${getFormatter(noDecimal: true, v4d: false, value: double.parse(bid.amount!).toDouble())}",
                    context),
                _tableDataCellIcon(isCutOff, context),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _tableHeaderCell(String text, BuildContext context,
      {bool alignRight = false}) {
    return Expanded(
      child: Container(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: MyntWebTextStyles.bodySmall(
            context,
            color: resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary),
            fontWeight: MyntFonts.medium,
          ),
        ),
      ),
    );
  }

  Widget _tableDataCell(String text, BuildContext context) {
    return Expanded(
      child: Text(
        text,
        style: MyntWebTextStyles.body(
          context,
          color: resolveThemeColor(context,
              dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
          fontWeight: MyntFonts.medium,
        ),
      ),
    );
  }

  Widget _tableDataCellIcon(bool isCutOff, BuildContext context) {
    return Expanded(
      child: Container(
        alignment: Alignment.centerRight,
        child: Icon(
          isCutOff ? Icons.check_circle : Icons.cancel,
          size: 20,
          color: isCutOff
              ? resolveThemeColor(context,
                  dark: MyntColors.profitDark, light: MyntColors.profit)
              : resolveThemeColor(context,
                  dark: MyntColors.lossDark, light: MyntColors.loss),
        ),
      ),
    );
  }
}
