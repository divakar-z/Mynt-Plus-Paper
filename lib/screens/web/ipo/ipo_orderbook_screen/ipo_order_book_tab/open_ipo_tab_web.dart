import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/res/global_state_text.dart';
import '../../../../../provider/iop_provider.dart';
import '../../../../../provider/thems.dart';
import '../../../../../res/res.dart';
import '../../../../../sharedWidget/functions.dart';
import '../../../../../sharedWidget/list_divider.dart';
import '../ipo_orderbook_details/open_order_details_web.dart';

class IpoOpenOrder extends ConsumerWidget {
  final List<dynamic>? filteredOrders;

  const IpoOpenOrder({super.key, this.filteredOrders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final ipo = ref.watch(ipoProvide);

    // Use filtered orders if provided, otherwise use original orders
    final ordersToDisplay = filteredOrders ?? ipo.openorder ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ipo.showSearch) _SearchBar(ipo: ipo, theme: theme),
          ipo.iposearch!.isEmpty
              ? _OpenOrderList(orders: ordersToDisplay, theme: theme)
              : _OpenOrderList(
                  orders: ipo.iposearch!, theme: theme, isSearch: true),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final dynamic ipo;
  final dynamic theme;

  const _SearchBar({required this.ipo, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.only(left: 16, top: 8),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: theme.isDarkMode
                      ? colors.darkGrey
                      : const Color(0xffF1F3F8),
                  width: 6))),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: ipo.openOrderController,
             style: TextWidget.textStyle(
                                    fontSize: 16,
                                    color: theme.isDarkMode
                                        ? colors.textPrimaryDark
                                        : colors.textPrimaryLight,
                                    theme: theme.isDarkMode,
                                    fw: 0,
                                  ),
              decoration: InputDecoration(
                  fillColor: theme.isDarkMode
                      ? colors.darkGrey
                      : const Color(0xffF1F3F8),
                  filled: true,
                 hintStyle: TextWidget.textStyle(
                                      fontSize: 14,
                                      theme: theme.isDarkMode,
                                     color: (theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight).withOpacity(0.4),
                                    fw: 0,
                                    ),
                  prefixIconColor: const Color(0xff586279),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: SvgPicture.asset(assets.searchIcon,
                        color: const Color(0xff586279),
                        fit: BoxFit.contain,
                        width: 20),
                  ),
                  suffixIcon: InkWell(
                    onTap: ipo.clearopenoreder,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: SvgPicture.asset(assets.removeIcon,
                          fit: BoxFit.scaleDown, width: 20),
                    ),
                  ),
                  enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(20))),
                  disabledBorder: InputBorder.none,
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(20))),
                  hintText: "Search Ipo",
                  contentPadding: const EdgeInsets.only(top: 20),
                  border: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(20)))),
              onChanged: (value) async {
                ipo.openOrderSearch(value, context);
              },
            ),
          ),
          TextButton(
              onPressed: () {
                ipo.showOpenSearch(false);
                ipo.getipoorderbookmodel(false);
              },
              child: Text("Close",
                  style: textStyles.textBtn.copyWith(
                      color: theme.isDarkMode
                          ? colors.colorLightBlue
                          : colors.colorBlue)))
        ],
      ),
    );
  }

  static TextStyle _textStyle(
      Color color, double fontSize, FontWeight fWeight) {
    return dysInter(
        textStyle:
            TextStyle(fontWeight: fWeight, color: color, fontSize: fontSize));
  }
}

class _OpenOrderList extends StatelessWidget {
  final List<dynamic> orders;
  final dynamic theme;
  final bool isSearch;

  const _OpenOrderList({
    required this.orders,
    required this.theme,
    this.isSearch = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.length,
      itemBuilder: (context, index) => _OpenOrderItem(
        order: orders[index],
        theme: theme,
        isSearch: isSearch,
      ),
      separatorBuilder: (BuildContext context, int index) {
        return const ListDivider();
      },
    );
  }
}

class _OpenOrderItem extends StatelessWidget {
  final dynamic order;
  final dynamic theme;
  final bool isSearch;

  const _OpenOrderItem({
    required this.order,
    required this.theme,
    this.isSearch = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          isDismissible: true,
          enableDrag: false,
          useSafeArea: true,
          context: context,
          builder: (context) => Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: IpoOpenOrderDetails(ipodetails: order)),
        );

        // Navigator.pushNamed(context, Routes.ipoopendetailsscreen,
        //     arguments: order);
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTopRow(context),
            const SizedBox(height: 8),
            _buildBottomRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          child: TextWidget.subText(
            text: order.companyName.toString(),
            theme: false,
            color: theme.isDarkMode
                ? colors.textPrimaryDark
                : colors.textPrimaryLight,
            textOverflow: TextOverflow.ellipsis,
            maxLines: 2,
            fw: 0,
          ),
        ),
        Row(
          children: [
            // SvgPicture.asset(order.reponseStatus == "new success"
            //     ? "assets/icon/success.svg"
            //     : "assets/icon/pendingicon.svg"),
            // SizedBox(width: isSearch ? 4 : 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: order.reponseStatus == "new success"
                    ? theme.isDarkMode
                        ? colors.profitDark.withOpacity(0.1)
                        : colors.profitLight.withOpacity(0.1)
                    : colors.pending.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: TextWidget.paraText(
                text: order.reponseStatus == "new success"
                    ? "Success"
                    : "Pending",
                theme: false,
                fw: 0,
                color: order.reponseStatus == "new success"
                    ? theme.isDarkMode
                        ? colors.profitDark
                        : colors.profitLight
                    : theme.isDarkMode
                        ? colors.pending
                        : colors.pending,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextWidget.paraText(
          text: order.responseDatetime.toString() == ""
              ? "----"
              : ipodateres(order.responseDatetime.toString()),
          theme: false,
          fw: 0,
          color: theme.isDarkMode
              ? colors.textSecondaryDark
              : colors.textSecondaryLight,
        ),
        TextWidget.subText(
          text: _getInvestedAmount(),
          theme: false,
          fw: 0,
          color: theme.isDarkMode
              ? colors.textPrimaryDark
              : colors.textPrimaryLight,
        ),
      ],
    );
  }

  String _getInvestedAmount() {
    if (isSearch) {
      return order.type == "BSE"
          ? getFormatter(noDecimal: true, v4d: false, value: double.parse(order.bidDetail![0].rate!) * double.parse(order.bidDetail![0].quantity!)).toString()
          : getFormatter(noDecimal: true, v4d: false, value: double.parse(order.bidDetail![0].amount.toString()));
    } else {
      // For regular orders, calculate max value
      List<String> stringList = [];
      for (var i = 0; i < order.bidDetail!.length; i++) {
        stringList.add(order.type == "BSE"
            ? (double.parse(order.bidDetail![i].rate!) *
                    double.parse(order.bidDetail![i].quantity!))
                .toString()
            : order.bidDetail![i].amount.toString());
      }
      String maxValue = stringList
          .reduce((curr, next) =>
              double.parse(curr) > double.parse(next) ? curr : next)
          .toString();
      return getFormatter(noDecimal: true, v4d: false, value: double.parse(maxValue));
    }
  }
}
