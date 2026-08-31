import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/models/marketwatch_model/get_quotes.dart';

import 'package:mynt_plus/provider/index_list_provider.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../res/res.dart';
import '../../../locator/preference.dart';
import '../../../models/marketwatch_model/search_scrip_new_model.dart';
import '../../../provider/thems.dart';
import '../../../res/global_state_text.dart';
import '../../../routes/app_routes.dart';
import '../../../sharedWidget/custom_exch_badge.dart';
import '../../../sharedWidget/list_divider.dart';
import '../../../sharedWidget/no_data_found.dart';
import '../../../sharedWidget/snack_bar.dart';
import '../../../provider/chart_provider.dart';
import '../../../models/marketwatch_model/market_watch_scrip_model.dart';
import '../../../provider/stocks_provider.dart';

class SearchScripList extends StatefulWidget {
  final List<ScripNewValue> searchValue;
  final String wlName;
  final String isBasket;
  final String searchText;
  const SearchScripList({
    super.key,
    required this.wlName,
    required this.searchValue,
    required this.searchText,
    required this.isBasket,
  });

  @override
  State<SearchScripList> createState() => _searchScripList();
}

class _searchScripList extends State<SearchScripList> {
  Preferences pref = Preferences();
  late bool scripisAscending;
  late bool pricepisAscending;
  late bool perchangisAscending;

  @override
  void initState() {
    setState(() {
      scripisAscending = pref.isMWScripname ?? true;
      pricepisAscending = pref.isMWPrice ?? true;
      perchangisAscending = pref.isMWPerchang ?? true;
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final theme = ref.read(themeProvider);
        final searchScrip = ref.watch(marketWatchProvider);


        // Show most active list when text field is empty
        if (widget.searchText.isEmpty) {
          final stocksProvider = ref.watch(stocksProvide);
          final mostActiveList = stocksProvider.byValue;
          
          if (mostActiveList.isEmpty) {
            return const Center(
              child: NoDataFound(),
            );
          }
          
          final indexProvider = ref.watch(indexListProvider);
          final indices = indexProvider.defaultIndexList?.indValues ?? [];

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16.0,bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.isDarkMode
                              ? colors.dividerDark
                              : colors.dividerLight,
                        ),
                        top: BorderSide(
                          color: theme.isDarkMode
                              ? colors.dividerDark
                              : colors.dividerLight,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, top: 4, bottom: 4),
                          child: TextWidget.subText(
                            fw: 2,
                            text: "Indices",
                            textOverflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            color: theme.isDarkMode
                                ? colors.textPrimaryDark
                                : colors.textPrimaryLight,
                            theme: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: indices.length,
                  separatorBuilder: (context, index) => const ListDivider(),
                  itemBuilder: (BuildContext context, int index) {
                    final stock = indices[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        splashColor: theme.isDarkMode
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.15),
                        highlightColor: theme.isDarkMode
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.08),
                        onTap: () async {
                          final marketWatch = ref.read(marketWatchProvider);
                          searchScrip.scripdepthsize(false);
                          searchScrip.setETF(false);
                            if (widget.isBasket == "Chart||Is") {
                              await searchScrip.fetchScripQuoteIndex(
                                stock.token.toString(),
                                stock.exch.toString(),
                                context,
                              );
                              final quots = marketWatch.getQuotes;
                              if (quots == null) {
                                return;
                              }
                        searchScrip.setChartScript(
                          quots.exch.toString(),
                          quots.token.toString(),
                          quots.tsym.toString(),
                        );
                        
                        // Show chart overlay with the selected script
                        final chartArgs = ChartArgs(
                          tsym: quots.tsym.toString(),
                          token: quots.token.toString(),
                          exch: quots.exch.toString(),
                        );
                        
                        // Set search as the previous route for chart navigation
                        ref.read(chartProvider.notifier).showChart(
                          chartArgs, 
                          previousRoute: null
                          );
                        
                        currentRouteName = 'Chart';
                        await searchScrip.searchClear();
                        Navigator.of(context).pop();
                        }else{
                          await marketWatch.fetchScripQuoteIndex(stock.token ?? "", stock.exch ?? "", context);
                          final quots = marketWatch.getQuotes;
                          if (quots == null) {
                            return;
                          }
                          DepthInputArgs depthArgs = DepthInputArgs(
                              exch: quots.exch?.toString() ?? "",
                              token: quots.token?.toString() ?? "",
                              tsym: quots.tsym?.toString() ?? "",
                              instname: quots.instname?.toString() ?? "",
                              symbol: quots.symbol?.toString() ?? "",
                              expDate: quots.expDate?.toString() ?? "",
                              option: quots.option?.toString() ?? "");
                          await searchScrip.calldepthApis(context, depthArgs, widget.isBasket);
                  }
                        },
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          dense: false,
                          title: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${stock.idxname} ",
                                  style: TextWidget.textStyle(
                                    fontSize: 14,
                                    theme: theme.isDarkMode,
                                    color: theme.isDarkMode
                                        ? colors.textPrimaryDark
                                        : colors.textPrimaryLight,
                                    fw: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CustomExchBadge(exch: "${stock.exch}"),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          trailing: widget.isBasket == "Chart||Is" ||
                                  widget.isBasket == "Option||Is" ||
                                  widget.isBasket == "Basket" ||
                                  searchScrip.isPreDefWLs == "Yes"
                              ? const SizedBox(width: 0.2)
                              : Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Material(
                                    color: Colors.transparent,
                                    shape: const CircleBorder(),
                                    child: Builder(
                                      builder: (context) {
                                        final String stockKey =
                                            "${stock.exch}|${stock.token}";
                                        final bool isInWatchlist = searchScrip
                                            .scrips
                                            .any((scrip) =>
                                                "${scrip['exch']}|${scrip['token']}" ==
                                                stockKey);

                                        return TextButton(
                                          style: TextButton.styleFrom(
                                            shape: const CircleBorder(),
                                            padding: const EdgeInsets.all(0),
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.transparent,
                                            elevation: 0.0,
                                            minimumSize: const Size(0, 40),
                                            side: BorderSide.none,
                                          ),
                                          onPressed: () async {
                                            if (isInWatchlist) {
                                              await searchScrip.addDelMarketScrip(
                                                widget.wlName,
                                                "${stock.exch}|${stock.token}",
                                                context,
                                                false,
                                                false,
                                                false,
                                                false,
                                              );
                                            } else {
                                              if (searchScrip.scrips.length >= 50) {
                                                final wlTitle = widget.wlName.isNotEmpty
                                                    ? '${widget.wlName[0].toUpperCase()}${widget.wlName.substring(1)}'
                                                    : 'Watchlist';
                                                error(context, "Watchlist \"$wlTitle\" limit reached (50/50 stocks). Please remove stocks to add new ones.");
                                                return;
                                              }
                                              await searchScrip.addDelMarketScrip(
                                                widget.wlName,
                                                "${stock.exch}|${stock.token}",
                                                context,
                                                true,
                                                false,
                                                false,
                                                false,
                                              );

                                              try {
                                                final currentSort = ref
                                                    .read(marketWatchProvider)
                                                    .sortByWL;

                                                if (currentSort.isNotEmpty) {
                                                  await ref
                                                      .read(marketWatchProvider)
                                                      .filterMWScrip(
                                                        sorting: currentSort,
                                                        wlName: widget.wlName,
                                                        context: context,
                                                      );
                                                }

                                                scripisAscending =
                                                    !scripisAscending;
                                                pref.setMWScrip(
                                                    scripisAscending);

                                                pricepisAscending =
                                                    !pricepisAscending;
                                                pref.setMWPrice(
                                                    pricepisAscending);

                                                perchangisAscending =
                                                    !perchangisAscending;
                                                pref.setMWPerchnage(
                                                    perchangisAscending);
                                              } catch (e) {
                                                print(
                                                    "Error applying sort: $e");
                                              }
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: SvgPicture.asset(
                                              isInWatchlist
                                                  ? assets.bookmarkIcon
                                                  : assets.bookmarkedIcon,
                                              color: theme.isDarkMode &&
                                                      isInWatchlist
                                                  ? colors.colorLightBlue
                                                  : isInWatchlist
                                                      ? colors.colorBlue
                                                      : colors.textSecondaryDark,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0,bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.isDarkMode
                            ? colors.dividerDark
                            : colors.dividerLight,
                      ),
                      top: BorderSide(
                        color: theme.isDarkMode
                            ? colors.dividerDark
                            : colors.dividerLight,
                      ),
                    ),
                  ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, top: 4, bottom: 4),
                          child: TextWidget.subText(
                            fw: 2,
                            text: "Trending Stocks",
                            textOverflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            color: theme.isDarkMode
                                ? colors.textPrimaryDark
                                : colors.textPrimaryLight,
                            theme: false,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.trending_up,
                            color: theme.isDarkMode
                                ? colors.textSecondaryDark
                                : colors.textSecondaryLight,
                            size: 18),
                      ],
                    ),
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mostActiveList.length,
                  separatorBuilder: (context, index) => const ListDivider(),
                  itemBuilder: (BuildContext context, int index) {
                    final stock = mostActiveList[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        splashColor: theme.isDarkMode
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.15),
                        highlightColor: theme.isDarkMode
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.08),
                        onTap: () async {
                          // Handle tap on most active stock
                          
                          searchScrip.scripdepthsize(false);
                          searchScrip.setETF(false);
                          if (widget.isBasket == "Chart||Is") {
                    await searchScrip.fetchScripQuoteIndex(
                      stock.token.toString(),
                      stock.exch.toString(),
                      context,
                    );
                    searchScrip.setChartScript(
                      stock.exch.toString(),
                      stock.token.toString(),
                      stock.tsym.toString(),
                    );
                    
                    // Show chart overlay with the selected script
                    final chartArgs = ChartArgs(
                      tsym: stock.tsym.toString(),
                      token: stock.token.toString(),
                      exch: stock.exch.toString(),
                    );
                    
                    // Set search as the previous route for chart navigation
                    ref.read(chartProvider.notifier).showChart(
                      chartArgs, 
                      previousRoute: null
                      );
                    
                    currentRouteName = 'Chart';
                    await searchScrip.searchClear();
                    Navigator.of(context).pop();
                  }else{
                          DepthInputArgs depthArgs = DepthInputArgs(
                              exch: stock.exch.toString(),
                              token: stock.token.toString(),
                              tsym: stock.tsym.toString(),
                              instname: "",
                              symbol: stock.tsym.toString(),
                              expDate: "",
                              option: "");
                          await searchScrip.calldepthApis(
                              context, depthArgs, widget.isBasket);
                  }
                        },
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          dense: false,
                          title: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${stock.tsym} ",
                                  style: TextWidget.textStyle(
                                    fontSize: 14,
                                    theme: theme.isDarkMode,
                                    color: theme.isDarkMode
                                        ? colors.textPrimaryDark
                                        : colors.textPrimaryLight,
                                    fw: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CustomExchBadge(exch: "${stock.exch}"),
                                    const SizedBox(width: 4),
                                    if (stock.cname != null)
                                      Expanded(
                                        child: TextWidget.paraText(
                                          text: "${stock.cname}",
                                          textOverflow: TextOverflow.ellipsis,
                                          color: theme.isDarkMode
                                              ? colors.textSecondaryDark
                                              : colors.textSecondaryLight,
                                          theme: theme.isDarkMode,
                                          fw: 0,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          trailing: widget.isBasket == "Chart||Is" ||
                                  widget.isBasket == "Option||Is" ||
                                  widget.isBasket == "Basket" ||
                                  searchScrip.isPreDefWLs == "Yes"
                              ? const SizedBox(width: 0.2)
                              : Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Material(
                                    color: Colors.transparent,
                                    shape: const CircleBorder(),
                                    child: Builder(
                                      builder: (context) {
                                        // Check if this stock is already in the watchlist
                                        final String stockKey =
                                            "${stock.exch}|${stock.token}";
                                        final bool isInWatchlist = searchScrip
                                            .scrips
                                            .any((scrip) =>
                                                "${scrip['exch']}|${scrip['token']}" ==
                                                stockKey);

                                        return TextButton(
                                          style: TextButton.styleFrom(
                                            shape: const CircleBorder(),
                                            padding: const EdgeInsets.all(0),
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.transparent,
                                            elevation: 0.0,
                                            minimumSize: const Size(0, 40),
                                            side: BorderSide.none,
                                          ),
                                          onPressed: () async {
                                            if (isInWatchlist) {
                                              await searchScrip
                                                  .addDelMarketScrip(
                                                widget.wlName,
                                                "${stock.exch}|${stock.token}",
                                                context,
                                                false,
                                                false,
                                                false,
                                                false,
                                              );
                                            } else {
                                              if (searchScrip.scrips.length >= 50) {
                                                final wlTitle = widget.wlName.isNotEmpty
                                                    ? '${widget.wlName[0].toUpperCase()}${widget.wlName.substring(1)}'
                                                    : 'Watchlist';
                                                error(context, "Watchlist \"$wlTitle\" limit reached (50/50 stocks). Please remove stocks to add new ones.");
                                                return;
                                              }
                                              await searchScrip
                                                  .addDelMarketScrip(
                                                widget.wlName,
                                                "${stock.exch}|${stock.token}",
                                                context,
                                                true,
                                                false,
                                                false,
                                                false,
                                              );

                                              try {
                                                final currentSort = ref
                                                    .read(marketWatchProvider)
                                                    .sortByWL;

                                                if (currentSort.isNotEmpty) {
                                                  await ref
                                                      .read(marketWatchProvider)
                                                      .filterMWScrip(
                                                        sorting: currentSort,
                                                        wlName: widget.wlName,
                                                        context: context,
                                                      );
                                                }

                                                scripisAscending =
                                                    !scripisAscending;
                                                pref.setMWScrip(
                                                    scripisAscending);

                                                pricepisAscending =
                                                    !pricepisAscending;
                                                pref.setMWPrice(
                                                    pricepisAscending);

                                                perchangisAscending =
                                                    !perchangisAscending;
                                                pref.setMWPerchnage(
                                                    perchangisAscending);
                                              } catch (e) {
                                                print(
                                                    "Error applying sort: $e");
                                              }
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(
                                                8), // ensure adequate tap target
                                            child:
                                                // !searchScrip.exarr.contains('"${stock.exch}"') ?
                                                // SvgPicture.asset(assets.dInfo,
                                                //   color:  Colors.red,
                                                //   height: 20,
                                                //   width: 20,
                                                // ) :

                                                SvgPicture.asset(
                                              isInWatchlist
                                                  ? assets.bookmarkIcon
                                                  : assets.bookmarkedIcon,
                                              color: theme.isDarkMode &&
                                                      isInWatchlist
                                                  ? colors.colorLightBlue
                                                  : isInWatchlist
                                                      ? colors.colorBlue
                                                      : colors.textSecondaryDark,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }
        
        // Show no data found only when user has typed something but no results
        if (widget.searchValue.isEmpty) {
          return const NoDataFound(
            showTip: false,
            secondaryEnabled: false,
            primaryEnabled: false,
            subtitle: "Try more than 3 keywords or different keywords.",
          );
        }

        return ListView.separated(
          physics: const ClampingScrollPhysics(),
          itemCount: widget.searchValue.length,
          separatorBuilder: (context, index) => const ListDivider(),
          itemBuilder: (BuildContext context, int index) {
            final scrip = widget.searchValue[index];
print(!searchScrip.exarr.contains('"${scrip.exch}"'));
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                splashColor: theme.isDarkMode
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.15),
                highlightColor: theme.isDarkMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.08),
                onTap: () async {
                  searchScrip.setETF(false);
                  searchScrip.scripdepthsize(false);
                  if (widget.isBasket == "Chart||Is") {
                    await searchScrip.fetchScripQuoteIndex(
                      scrip.token.toString(),
                      scrip.exch.toString(),
                      context,
                    );
                    searchScrip.setChartScript(
                      scrip.exch.toString(),
                      scrip.token.toString(),
                      scrip.tsym.toString(),
                    );
                    
                    // Show chart overlay with the selected script
                    final chartArgs = ChartArgs(
                      tsym: scrip.tsym.toString(),
                      token: scrip.token.toString(),
                      exch: scrip.exch.toString(),
                    );
                    
                    // Set search as the previous route for chart navigation
                    ref.read(chartProvider.notifier).showChart(
                      chartArgs, 
                      previousRoute: null
                      );
                    
                    currentRouteName = 'Chart';
                    await searchScrip.searchClear();
                    Navigator.of(context).pop();
                  } else if (widget.isBasket == "Option||Is") {
                    currentRouteName = 'Optionchain';
                    searchScrip.setOptionScript(
                      context,
                      scrip.exch.toString(),
                      scrip.token.toString(),
                      scrip.tsym.toString(),
                    );
                    await searchScrip.searchClear();
                    Navigator.of(context).pop();
                  } else {
                    await searchScrip.calldepthApis(
                      context,
                      scrip,
                      widget.isBasket,
                    );
                  }
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  dense: false,
                  title: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${scrip.symbol?.isNotEmpty == true ? scrip.symbol : scrip.tsym} ",
                          style: TextWidget.textStyle(
                            fontSize: 14,
                            theme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? colors.textPrimaryDark
                                : colors.textPrimaryLight,
                            fw: 0,
                          ),
                        ),
                        if (scrip.option != null)
                          Text(
                            "${scrip.option}",
                            style: TextWidget.textStyle(
                              fontSize: 14,
                              color: theme.isDarkMode
                                  ? colors.textPrimaryDark
                                  : colors.textPrimaryLight,
                              theme: theme.isDarkMode,
                              fw: 0,
                            ),
                          )
                      ],
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            CustomExchBadge(exch: "${scrip.exch}"),
                            if (scrip.expDate != null)
                              TextWidget.paraText(
                                text: " ${scrip.expDate}",
                                color: theme.isDarkMode
                                    ? colors.textSecondaryDark
                                    : colors.textSecondaryLight,
                                theme: theme.isDarkMode,
                                fw: 0,
                              ),
                            if (scrip.expDate == "" && scrip.cname != null)
                              Expanded(
                                child: TextWidget.paraText(
                                  text: "${scrip.cname}",
                                  textOverflow: TextOverflow.ellipsis,
                                  color: theme.isDarkMode
                                      ? colors.textSecondaryDark
                                      : colors.textSecondaryLight,
                                  theme: theme.isDarkMode,
                                  fw: 0,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  trailing: widget.isBasket == "Chart||Is" ||
                          widget.isBasket == "Option||Is" ||
                          widget.isBasket == "Basket" ||
                          searchScrip.isPreDefWLs == "Yes"
                      ? const SizedBox(width: 0.2)
                      : Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(0),
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.transparent,
                                elevation: 0.0,
                                minimumSize: const Size(0, 40),
                                side: BorderSide.none,
                              ),
                              onPressed: () async {
                                if(!searchScrip.exarr.contains('"${scrip.exch}"')){
          error(context, "Segment is not active.");
                                }
                                else{
                                if (searchScrip.isAdded![index]) {
                                  await searchScrip.isActiveAddBtn(
                                      false, index);
                                  await searchScrip.addDelMarketScrip(
                                    widget.wlName,
                                    "${scrip.exch}|${scrip.token}",
                                    context,
                                    false,
                                    false,
                                    false,
                                    false,
                                  );
                                } else {
                                  if (searchScrip.scrips.length >= 50) {
                                    final wlTitle = widget.wlName.isNotEmpty
                                        ? '${widget.wlName[0].toUpperCase()}${widget.wlName.substring(1)}'
                                        : 'Watchlist';
                                    error(context, "Watchlist \"$wlTitle\" limit reached (50/50 stocks). Please remove stocks to add new ones.");
                                    return;
                                  }
                                  await searchScrip.isActiveAddBtn(true, index);
                                  await searchScrip.addDelMarketScrip(
                                    widget.wlName,
                                    "${scrip.exch}|${scrip.token}",
                                    context,
                                    true,
                                    false,
                                    false,
                                    false,
                                  );

                                  try {
                                    final currentSort =
                                        ref.read(marketWatchProvider).sortByWL;

                                    if (currentSort.isNotEmpty) {
                                      await ref
                                          .read(marketWatchProvider)
                                          .filterMWScrip(
                                            sorting: currentSort,
                                            wlName: widget.wlName,
                                            context: context,
                                          );
                                    }

                                    scripisAscending = !scripisAscending;
                                    pref.setMWScrip(scripisAscending);

                                    pricepisAscending = !pricepisAscending;
                                    pref.setMWPrice(pricepisAscending);

                                    perchangisAscending = !perchangisAscending;
                                    pref.setMWPerchnage(perchangisAscending);
                                  } catch (e) {
                                    print("Error applying sort: $e");
                                  }
                                }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(
                                    8), // ensure adequate tap target
                                child: !searchScrip.exarr.contains('"${scrip.exch}"') ?
                                SvgPicture.asset(assets.dInfo,
                                  color:  Colors.red,
                                  height: 20,
                                  width: 20,
                                ) :
                                
                                SvgPicture.asset(
                                  searchScrip.isAdded![index]
                                      ? assets.bookmarkIcon
                                      : assets.bookmarkedIcon,
                                  color:
                                  theme.isDarkMode &&
                                          searchScrip.isAdded![index]
                                      ? colors.colorLightBlue
                                      : searchScrip.isAdded![index]
                                          ? colors.colorBlue
                                          : colors.textSecondaryDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
