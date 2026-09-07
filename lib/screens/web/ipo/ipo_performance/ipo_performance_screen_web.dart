// ignore_for_file: deprecated_member_use

//import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/provider/market_watch_provider.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';

import '../../../../models/ipo_model/ipo_performance_model.dart';
import '../../../../provider/iop_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/res.dart';
import '../../../../sharedWidget/custom_text_btn.dart';
import '../../../../sharedWidget/no_data_found.dart';

class IPOPerformance extends ConsumerStatefulWidget {
  const IPOPerformance({super.key});

  @override
  ConsumerState<IPOPerformance> createState() => _IPOPerformanceState();
}

class _IPOPerformanceState extends ConsumerState<IPOPerformance> {
  late List<IpoScrip> ipoList;
  bool showAll = false;

  @override
  void initState() {
    super.initState();
    ipoList = ref.read(ipoProvide).ipoPerformanceModel!.data!;
    ref.read(ipoProvide).sortIPOListByDate(ipoList);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, WidgetRef ref, _) {
      final performance = ref.watch(ipoProvide);
      final theme = ref.watch(themeProvider);
      final market = ref.watch(marketWatchProvider);
      
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildContent(performance, theme, market),
            _buildShowMoreButton(performance, theme),
          ],
        ),
      );
    });
  }

  Widget _buildContent(performance, theme, market) {
    if (performance.ipoPerformanceModel?.emsg == "no data") {
      return const Center(child: NoDataFoundWeb());
    }

    return performance.performancesearch!.isEmpty
        ? _buildMainList(performance, theme, market)
        : _buildSearchList(performance, theme);
  }

  Widget _buildMainList(performance, theme, market) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const ScrollPhysics(),
      itemBuilder: (context, index) {
        final ipo = ipoList[index];
        return _IPOPerformanceItem(
          ipo: ipo,
          theme: theme,
          market: market,
          performance: performance,
          index: index,
        );
      },
      separatorBuilder: (context, index) => _buildSeparator(theme),
      itemCount: showAll ? ipoList.length : 5,
    );
  }

  Widget _buildSearchList(performance, theme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => _SearchResultItem(
        ipo: performance.performancesearch![index],
        theme: theme,
        performance: performance,
        index: index,
      ),
      separatorBuilder: (context, index) => _buildSeparator(theme, height: 8),
      itemCount: performance.performancesearch!.length,
    );
  }

  Widget _buildSeparator(theme, {double height = 7}) {
    return Container(
      height: height,
      color: theme.isDarkMode
          ? colors.darkColorDivider
          : const Color(0xffF1F3F8),
    );
  }

  Widget _buildShowMoreButton(performance, theme) {
    if (performance.performancesearch!.isNotEmpty ||
        performance.ipoPerformanceModel!.emsg == "no data") {
      return Container();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: CustomTextBtn(
        icon: assets.downArrow,
        label: showAll ? "See less IPOs" : "See more IPOs",
        onPress: () {
          setState(() {
            showAll = !showAll;
          });
        },
      ),
    );
  }
}

class _IPOPerformanceItem extends ConsumerWidget {
  final IpoScrip ipo;
  final dynamic theme;
  final dynamic market;
  final dynamic performance;
  final int index;

  const _IPOPerformanceItem({
    required this.ipo,
    required this.theme,
    required this.market,
    required this.performance,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    DateTime listedDate = ref.read(ipoProvide).convertDatetime(ipo.listedDate);
    
    return InkWell(
      onTap: () => _handleTap(context, market),
      child: Column(
        children: [
          ListTile(
            title: Text(
              "${ipo.companyName}",
              overflow: TextOverflow.ellipsis,
              style: _textStyle(
                  theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                  15,
                  FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  "Listed on ${listedDate.day} ${ipo.listedDate?.substring(0, 3)}",
                  style: _textStyle(
                      const Color(0xff666666), 11, FontWeight.w500),
                ),
              ],
            ),
          ),
          Divider(
            color: theme.isDarkMode
                ? colors.darkColorDivider
                : const Color(0xffECEDEE),
          ),
          _buildPerformanceMetrics(),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMetricColumn("Issue Price", "₹ ${ipo.priceRange}"),
          _buildMetricColumn("Close Price", "₹ ${ipo.clsPric}"),
          _buildMetricColumn("Gain/Loss", "₹ ${ipo.listingGain}",
              color: _getGainLossColor()),
          _buildMetricColumn("Listing Gain", "${ipo.listingGainPer}%",
              color: _getGainLossColor()),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: dysInter(
            textStyle: _textStyle(
                const Color(0xff666666), 10, FontWeight.w500),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: _textStyle(
            color ?? (theme.isDarkMode ? colors.colorWhite : colors.colorBlack),
            15,
            FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getGainLossColor() {
    return performance.ipoPerformanceModel!.data![index].listingGain!
            .toStringAsFixed(2)
            .startsWith("-")
        ? colors.darkred
        : colors.ltpgreen;
  }

  void _handleTap(BuildContext context, market) async {
    var listdata = ipo.toJson();
    listdata['exch'] = ipo.exchange;
    listdata['expDate'] = "";
    listdata['option'] = "";
    listdata['instname'] = "";
    market.chngshareHold("Promoter Holding");
    await market.calldepthApis(context, listdata, "");
  }

  static TextStyle _textStyle(Color color, double fontSize, FontWeight fWeight) {
    return TextStyle(
      fontWeight: fWeight,
      color: color,
      fontSize: fontSize,
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final dynamic ipo;
  final dynamic theme;
  final dynamic performance;
  final int index;

  const _SearchResultItem({
    required this.ipo,
    required this.theme,
    required this.performance,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: ClipOval(
            child: Container(
              color: colors.colorDivider.withOpacity(.3),
              width: 50,
              height: 50,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Image.network(ipo.imageLink.toString()),
              ),
            ),
          ),
          title: Text(
            "${ipo.companyName}",
            style: _textStyle(
                theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                15,
                FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                "Listing on : ${ipo.listedDate}",
                style: _textStyle(
                    const Color(0xff666666), 13, FontWeight.w500),
              ),
            ],
          ),
        ),
        Divider(
          color: theme.isDarkMode
              ? colors.darkColorDivider
              : const Color(0xffECEDEE),
        ),
        _buildSearchMetrics(),
      ],
    );
  }

  Widget _buildSearchMetrics() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMetricColumn("Issue Price", "₹${ipo.priceRange}"),
          _buildMetricColumn("Close Price", "₹ ${ipo.clsPric}"),
          _buildMetricColumn("Gain/Loss", "₹${ipo.listingGain}",
              color: _getGainLossColor()),
          _buildMetricColumn("Listing Gain", "${ipo.listingGainPer}%",
              color: _getGainLossColor()),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: dysInter(
            textStyle: _textStyle(
                const Color(0xff666666), 13, FontWeight.w500),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: _textStyle(
            color ?? (theme.isDarkMode ? colors.colorWhite : colors.colorBlack),
            15,
            FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getGainLossColor() {
    return performance.performancesearch![index].listingGain!
            .toStringAsFixed(2)
            .startsWith("-")
        ? colors.darkred
        : colors.ltpgreen;
  }

  static TextStyle _textStyle(Color color, double fontSize, FontWeight fWeight) {
    return dysInter(
      fontWeight: fWeight,
      color: color,
      fontSize: fontSize,
    );
  }
}
