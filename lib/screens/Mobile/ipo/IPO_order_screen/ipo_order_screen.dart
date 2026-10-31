// ignore_for_file: unused_local_variable
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/screens/Mobile/ipo/mainstream_order_screen/orderscreenbottompage.dart';
import '../../../../models/ipo_model/ipo_details_model.dart';
import '../../../../models/ipo_model/ipo_place_order_model.dart';
import '../../../../models/ipo_model/ipo_sme_model.dart';
import '../../../../models/ipo_model/ipo_mainstream_model.dart';
import '../../../../provider/iop_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../provider/transcation_provider.dart';
import '../../../../res/global_state_text.dart';
import '../../../../res/res.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../../sharedWidget/snack_bar.dart';

class UnifiedIpoOrderScreen extends ConsumerStatefulWidget {
  final dynamic ipoData; // Can be either SMEIPO or MainIPO
  const UnifiedIpoOrderScreen({
    super.key,
    required this.ipoData,
  });

  @override
  ConsumerState<UnifiedIpoOrderScreen> createState() =>
      _UnifiedIpoOrderScreenState();
}

class _UnifiedIpoOrderScreenState extends ConsumerState<UnifiedIpoOrderScreen> {
  String upierrortext = "";
  String selectedChip = "Individual";
  List<IpoDetails> addIpo = [];

  // Helper getters to determine IPO type and access data
  bool get isSME => widget.ipoData is SMEIPO;
  bool get isMainstream => widget.ipoData is MainIPO;

  dynamic get ipoData => widget.ipoData;
  String get ipoName => isSME ? (ipoData.name ?? "") : (ipoData.name ?? "");
  String get ipoKey => isSME ? (ipoData.key ?? "") : (ipoData.key ?? "");
  String get ipoSymbol =>
      isSME ? (ipoData.symbol ?? "") : (ipoData.symbol ?? "");
  String get ipoType => isSME ? (ipoData.type ?? "") : (ipoData.type ?? "");
  String get lotSize =>
      isSME ? (ipoData.lotSize ?? "") : (ipoData.lotSize ?? "");
  String get minPrice =>
      isSME ? (ipoData.minPrice ?? "") : (ipoData.minPrice ?? "");
  String get maxPrice =>
      isSME ? (ipoData.maxPrice ?? "") : (ipoData.maxPrice ?? "");
  String get minBidQuantity =>
      isSME ? (ipoData.minBidQuantity ?? "") : (ipoData.minBidQuantity ?? "");
  String get dailyStartTime =>
      isSME ? (ipoData.dailyStartTime ?? "") : (ipoData.dailyStartTime ?? "");
  String get dailyEndTime =>
      isSME ? (ipoData.dailyEndTime ?? "") : (ipoData.dailyEndTime ?? "");
  String get biddingStartDate => isSME
      ? (ipoData.biddingStartDate ?? "")
      : (ipoData.biddingStartDate ?? "");
  String get biddingEndDate =>
      isSME ? (ipoData.biddingEndDate ?? "") : (ipoData.biddingEndDate ?? "");

  @override
  void initState() {
    setState(() {
      addNewItem();
    });
    super.initState();
  }

  void addNewItem() {
    setState(() {
      addIpo.add(IpoDetails(
          qualitytext: lotSize,
          bidprice:
              "${double.parse(minPrice.isEmpty ? "0" : minPrice).toInt()}",
          lotsize: int.parse(lotSize.isEmpty ? "0" : lotSize),
          requriedprice: mininv(
                  double.parse(minPrice.isEmpty ? "0" : minPrice).toDouble(),
                  int.parse(minBidQuantity.isEmpty ? "0" : minBidQuantity)
                      .toInt())
              .toInt(),
          isChecked: false));
    });
  }

  void removeItem(int index) {
    setState(() {
      addIpo.removeAt(index);
    });
  }

  // Helper method to get appropriate provider methods based on IPO type
  void _updateProviderState(IPOProvider ipo) {
    if (isSME) {
      if (ipo.checkForErrorsInSMEPlaceOrder(addIpo)) {
        ipo.setisSMEPlaceOrderBtnActiveValue = true;
      }
      ipo.setsmePlaceOrderRequiredMaxPrice = addIpo;
    } else {
      if (ipo.checkForErrorsInSMEPlaceOrder(addIpo)) {
        ipo.setisMainIPOPlaceOrderBtnActiveValue = true;
      }
      ipo.setMainIPOPlaceOrderRequiredMaxPrice = addIpo;
    }
  }

  // Helper method to get button active state
  bool _getButtonActiveState(IPOProvider ipo) {
    return isSME
        ? ipo.isSMEPlaceOrderBtnActive
        : ipo.isMainIPOPlaceOrderBtnActive;
  }

  // Helper method to get max price
  int _getMaxPrice(IPOProvider ipo) {
    return isSME
        ? ipo.smePlaceOrderRequiredMaxPrice
        : ipo.mainIPOPlaceOrderRequiredMaxPrice;
  }

  // Helper method to set button active state
  void _setButtonActiveState(IPOProvider ipo, bool value) {
    if (isSME) {
      ipo.setisSMEPlaceOrderBtnActiveValue = value;
    } else {
      ipo.setisMainIPOPlaceOrderBtnActiveValue = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Consumer(
        builder: (context, ref, child) {
          final ipo = ref.watch(ipoProvide);
          final theme = ref.watch(themeProvider);
          final status = ipostartdate(biddingStartDate, biddingEndDate);
          final isOpen = status == "Open";
          // Open green, Pre-open grey, Closed red (same on every IPO screen).
          final isPreOpen = status == "Pre-open";

          var chips =
              ipo.ipoCategory.map((e) => e['subCatCode']).toSet().toList();
          // Only set selectedChip to first chip if it's still the default value
          if (selectedChip == "Individual" && chips.isNotEmpty) {
            selectedChip = chips[0];
          }

          _updateProviderState(ipo);

          return Scaffold(
            appBar: AppBar(
              elevation: .2,
              centerTitle: false,
              leadingWidth: 38,
              titleSpacing: 1,
              leading: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  splashColor: theme.isDarkMode
                      ? colors.splashColorDark
                      : colors.splashColorLight,
                  highlightColor: theme.isDarkMode
                      ? colors.highlightDark
                      : colors.highlightLight,
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.arrow_back_ios_outlined,
                    size: 18,
                    color: theme.isDarkMode
                        ? colors.textSecondaryDark
                        : colors.textSecondaryLight,
                  ),
                ),
              ),
              backgroundColor:
                  theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
              title: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget.titleText(
                        text: ipoName,
                        theme: theme.isDarkMode,
                        color: theme.isDarkMode
                            ? colors.textPrimaryDark
                            : colors.textPrimaryLight,
                        fw: 1),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TextWidget.paraText(
                            text: ipoKey,
                            theme: theme.isDarkMode,
                            color: theme.isDarkMode
                                ? colors.textSecondaryDark
                                : colors.textSecondaryLight,
                            fw: 0),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOpen
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
                            fw: 0,
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(chips.isNotEmpty ? 50 : 0),
                child: chips.isNotEmpty
                    ? Row(
                        children: [
                          DefaultTabController(
                            length: chips.length,
                            initialIndex: chips.contains(selectedChip)
                                ? chips.indexOf(selectedChip)
                                : 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TabBar(
                                    tabAlignment: TabAlignment.start,
                                    indicatorSize: TabBarIndicatorSize.tab,
                                    isScrollable: true,
                                    indicatorColor: theme.isDarkMode
                                        ? colors.secondaryDark
                                        : colors.secondaryLight,
                                    unselectedLabelColor: theme.isDarkMode
                                        ? colors.textSecondaryDark
                                        : colors.textSecondaryLight,
                                    unselectedLabelStyle: TextWidget.textStyle(
                                      fontSize: 14,
                                      theme: false,                                    
                                      fw: 0,
                                    ),
                                    labelPadding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    indicatorPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16),
                                    labelColor: theme.isDarkMode
                                        ? colors.secondaryDark
                                        : colors.secondaryLight,
                                    labelStyle: TextWidget.textStyle(
                                        fontSize: 14,
                                        theme: false,
                                        color: theme.isDarkMode
                                            ? colors.secondaryDark
                                            : colors.secondaryLight,
                                        fw: 2),
                                    tabs: chips.map((chip) {
                                      return Tab(
                                        child: TextWidget.subText(
                                          text: chip,
                                          theme: false,
                                          fw: 0,
                                          color: theme.isDarkMode
                                              ? colors.secondaryDark
                                              : colors.secondaryLight,
                                        ),
                                      );
                                    }).toList(),
                                    onTap: (index) async {
                                      final chip = chips[index];
                                      setState(() {
                                        selectedChip = chip;
                                        _updateProviderState(ipo);
                                      });
                                      ipo.chngCategoryType(chip);
                                      await ipo.categoryOnChange(
                                        addIpo,
                                        ipo.maxUPIAmt,
                                        _getButtonActiveState(ipo),
                                        selectedChip,
                                      );
                                    },
                                  ),
                                  Divider(
                                    height: 1,
                                    color: theme.isDarkMode
                                        ? colors.dividerDark
                                        : colors.dividerLight,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox(),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          // Container(
                          //   color: Color(0xFFFCEFD4),
                          //   height: 30,
                          //   child: Center(
                          //     child: Text(
                          //         "IPO window is open from $dailyStartTime till $dailyEndTime on trading days.",
                          //         style: textStyle(
                          //             theme.isDarkMode
                          //                 ? colors.colorWhite
                          //                 : colors.colorBlack,
                          //             10,
                          //             FontWeight.w600)),
                          //   ),
                          // ),
                        
                          // Category chips container with conditional styling
                        
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: addIpo.length,
                            itemBuilder: (context, index) {
                              _updateProviderState(ipo);
                        
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          // Text("Bid - 0${index + 1}",
                                          //     style: textStyle(
                                          //         theme.isDarkMode
                                          //             ? colors.colorWhite
                                          //             : colors.colorBlack,
                                          //         14,
                                          //         FontWeight.w600)),
                                          index > 0
                                              ? InkWell(
                                                  splashFactory: InkSparkle
                                                      .constantTurbulenceSeedSplashFactory,
                                                  onTap: ipo.loading
                                                      ? null
                                                      : () {
                                                          removeItem(index);
                                                        },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(5),
                                                    child: Row(
                                                      children: [
                                                        SvgPicture.asset(
                                                          assets.trash,
                                                          color: theme.isDarkMode ? colors.lossDark : colors.lossLight,
                                                        ),
                                                        const SizedBox(width: 5),
                                                        TextWidget.subText(
                                                          text: "Delete",
                                                          theme: false,
                                                          fw: 2,
                                                          color:  theme.isDarkMode ? colors.lossDark : colors.lossLight,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              : Container()
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                TextWidget.subText(
                                                  text: "Qty",
                                                  theme: false,
                                                  fw: 1,
                                                  color: theme.isDarkMode
                                                      ? colors.textPrimaryDark
                                                      : colors.textPrimaryLight,
                                                ),
                                                const SizedBox(height: 8),
                                                SizedBox(
                                                  height: 45,
                                                  child: TextFormField(
                                                    readOnly: true,
                                                    textAlign: TextAlign.center,
                                                    style: TextWidget.textStyle(
                                                      fontSize: 16,
                                                      theme: false,
                                                      color: theme.isDarkMode
                                                          ? colors.textPrimaryDark
                                                          : colors
                                                              .textPrimaryLight,
                                                      fw: 0,
                                                      
                                                    ),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    controller: addIpo[index]
                                                        .qualityController,
                                                    decoration: InputDecoration(
                                                       fillColor: theme.isDarkMode
                              ? colors.darkGrey
                              : const Color(0xffF1F3F8),
                                                        filled: true,
                                                        enabledBorder: OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                                color: colors
                                                                    .btnOutlinedBorder),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    5)),
                                                        disabledBorder:
                                                            InputBorder.none,
                                                        focusedBorder: OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                                color: colors
                                                                    .btnOutlinedBorder),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    5)),
                                                        contentPadding:
                                                            const EdgeInsets.all(
                                                                13),
                                                        border: OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                                color: colors
                                                                    .btnOutlinedBorder),
                                                            borderRadius:
                                                                BorderRadius.circular(5)),
                                                        suffixIcon: Material(
                                                          color:
                                                              Colors.transparent,
                                                          shape:
                                                              const CircleBorder(),
                                                          clipBehavior:
                                                              Clip.hardEdge,
                                                          child: InkWell(
                                                            customBorder:
                                                                const CircleBorder(),
                                                            splashColor: theme
                                                                    .isDarkMode
                                                                ? colors
                                                                    .splashColorDark
                                                                : colors
                                                                    .splashColorLight,
                                                            highlightColor: theme
                                                                    .isDarkMode
                                                                ? colors
                                                                    .highlightDark
                                                                : colors
                                                                    .highlightLight,
                                                            onTap: ipo.loading
                                                                ? null
                                                                : () {
                                                                    if (isSME) {
                                                                      ipo.smequalityplusefunction(
                                                                          addIpo[
                                                                              index],
                                                                          _getButtonActiveState(
                                                                              ipo),
                                                                          ipoData,
                                                                          ipo.maxUPIAmt,
                                                                          selectedChip);
                                                                    } else {
                                                                      ipo.qualityplusefunction(
                                                                          addIpo[
                                                                              index],
                                                                          _getButtonActiveState(
                                                                              ipo),
                                                                          ipo,
                                                                          ipoData,
                                                                          selectedChip);
                                                                    }
                                                                    setState(() {
                                                                      _updateProviderState(
                                                                          ipo);
                                                                    });
                                                                  },
                                                            child: SvgPicture.asset(
                                                                theme.isDarkMode
                                                                    ? assets
                                                                        .darkAdd
                                                                    : assets
                                                                        .addIcon,
                                                                fit: BoxFit
                                                                    .scaleDown),
                                                          ),
                                                        ),
                                                        prefixIcon: InkWell(
                                                          onTap: addIpo[index]
                                                                      .qualityController
                                                                      .text ==
                                                                  addIpo[index]
                                                                      .qualitytext
                                                              ? null
                                                              : ipo.loading
                                                                  ? null
                                                                  : () {
                                                                      if (isSME) {
                                                                        ipo.smequantityminusfunction(
                                                                            addIpo[
                                                                                index],
                                                                            _getButtonActiveState(
                                                                                ipo),
                                                                            ipoData,
                                                                            ipo.maxUPIAmt,
                                                                            selectedChip);
                                                                      } else {
                                                                        ipo.quantityminusfunction(
                                                                            addIpo[
                                                                                index],
                                                                            _getButtonActiveState(
                                                                                ipo),
                                                                            ipo,
                                                                            ipoData,
                                                                            selectedChip);
                                                                      }
                                                                      setState(
                                                                          () {
                                                                        _updateProviderState(
                                                                            ipo);
                                                                      });
                                                                    },
                                                          child: SvgPicture.asset(
                                                              theme.isDarkMode
                                                                  ? assets
                                                                      .darkCMinus
                                                                  : assets
                                                                      .minusIcon,
                                                              fit: BoxFit
                                                                  .scaleDown),
                                                        )),
                                                    onChanged: (value) {
                                                      if (isSME) {
                                                        ipo.smequantityOnchange(
                                                            value,
                                                            addIpo[index],
                                                            ipoData,
                                                            _getButtonActiveState(
                                                                ipo),
                                                            ipo.maxUPIAmt,
                                                            selectedChip);
                                                      } else {
                                                        ipo.quantityOnchange(
                                                            addIpo[index],
                                                            _getButtonActiveState(
                                                                ipo),
                                                            ipo,
                                                            value,
                                                            ipoData,
                                                            selectedChip);
                                                      }
                                                      setState(() {
                                                        _updateProviderState(ipo);
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    TextWidget.subText(
                                                      text: "Bid Price",
                                                      theme: false,
                                                      fw: 1,
                                                      color: theme.isDarkMode
                                                          ? colors
                                                              .textPrimaryDark
                                                          : colors
                                                              .textPrimaryLight,
                                                    ),
                                                    // Text(
                                                    //     "(${double.parse(minPrice).toInt()}- ${double.parse(maxPrice).toInt()})",
                                                    //     style: textStyle(
                                                    //         theme.isDarkMode
                                                    //             ? colors.colorWhite
                                                    //             : colors.colorBlack,
                                                    //         10,
                                                    //         FontWeight.w600)),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                SizedBox(
                                                  height: 45,
                                                  child: TextFormField(
                                                    style: TextWidget.textStyle(
                                                      fontSize: 16,
                                                      theme: false,
                                                      color: theme.isDarkMode
                                                          ? colors.textPrimaryDark
                                                          : colors
                                                              .textPrimaryLight,
                                                      fw: 0,
                                                    ),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    readOnly: ipo.loading
                                                        ? true
                                                        : addIpo[index]
                                                                    .isChecked ==
                                                                true
                                                            ? true
                                                            : false,
                                                    controller: addIpo[index]
                                                        .bidpricecontroller,
                                                    decoration: InputDecoration(
                                                    fillColor: theme.isDarkMode
                              ? colors.darkGrey
                              : const Color(0xffF1F3F8),
                                                      filled: true,
                                                      labelStyle:
                                                          TextWidget.textStyle(
                                                        fontSize: 16,
                                                        theme: false,
                                                        color: theme.isDarkMode
                                                            ? colors.textPrimaryDark
                                                            : colors
                                                                .textPrimaryLight,
                                                        
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                              color: colors
                                                                  .btnOutlinedBorder),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(5)),
                                                      disabledBorder:
                                                          InputBorder.none,
                                                      focusedBorder: OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                              color: colors
                                                                  .btnOutlinedBorder),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(5)),
                                                      contentPadding:
                                                          const EdgeInsets.all(
                                                              13),
                                                      border: OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                              color: colors
                                                                  .btnOutlinedBorder),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(5)),
                                                      suffixIcon: Material(
                                                        color: Colors.transparent,
                                                        shape:
                                                            const CircleBorder(),
                                                        clipBehavior:
                                                            Clip.hardEdge,
                                                        child: InkWell(
                                                          customBorder:
                                                              const CircleBorder(),
                                                          splashColor: theme
                                                                  .isDarkMode
                                                              ? colors
                                                                  .splashColorDark
                                                              : colors
                                                                  .splashColorLight,
                                                          highlightColor: theme
                                                                  .isDarkMode
                                                              ? colors
                                                                  .highlightDark
                                                              : colors
                                                                  .highlightLight,
                                                          onTap: ipo.loading
                                                              ? null
                                                              : () {
                                                                  if (isSME) {
                                                                    ipo.smecutoffprice(
                                                                      addIpo[
                                                                          index],
                                                                      ipoData,
                                                                    );
                                                                  } else {
                                                                    ipo.cutoffprice(
                                                                        addIpo[
                                                                            index],
                                                                        ipoData);
                                                                  }
                                                                  FocusScope.of(
                                                                          context)
                                                                      .unfocus();
                                                                  _updateProviderState(
                                                                      ipo);
                                                                },
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(14.0),
                                                            child: SvgPicture.asset(
                                                                assets.switchIcon,
                                                                fit: BoxFit
                                                                    .contain),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    onChanged: (value) {
                                                      if (isSME) {
                                                        ipo.smebidpriceOnChange(
                                                            value,
                                                            addIpo[index],
                                                            _getButtonActiveState(
                                                                ipo),
                                                            ipoData);
                                                      } else {
                                                        ipo.bidpricefunction(
                                                            addIpo[index],
                                                            ipoData,
                                                            value,
                                                            _getButtonActiveState(
                                                                ipo));
                                                      }
                                                      setState(() {
                                                        _updateProviderState(ipo);
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      // Row(
                                      //   mainAxisAlignment: MainAxisAlignment.center,
                                      //   children: [
                                      //     const Padding(
                                      //         padding: EdgeInsets.symmetric(
                                      //             horizontal: 55, vertical: 20)),
                        
                                      //   ],
                                      // ),
                                     if (addIpo[index]
                                            .qualityerrortext
                                            .isNotEmpty ||
                                        addIpo[index]
                                            .biderrortext
                                            .isNotEmpty) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: TextWidget.captionText(
                                              theme: false,
                                              text:
                                                  addIpo[index].qualityerrortext,
                                              color: colors.error,
                                              fw: 0,
                                            ),
                                          ),
                                          Expanded(
                                            child: TextWidget.captionText(
                                              theme: false,
                                              text: addIpo[index].biderrortext,
                                              color: colors.error,
                                              fw: 0,
                                            ),
                                          ),
                                        ],
                                      ),
                        
                                      // if (addIpo[index]
                                      //     .qualityerrortext
                                      //     .isNotEmpty) ...[
                                      //   const SizedBox(height: 6),
                                      //   IpoErrorBadge(
                                      //     errorName:
                                      //         addIpo[index].qualityerrortext,
                                      //   )
                                      // ],
                                      // if (addIpo[index]
                                      //     .biderrortext
                                      //     .isNotEmpty) ...[
                                      //   const SizedBox(height: 6),
                                      //   IpoErrorBadge(
                                      //     errorName: addIpo[index].biderrortext,
                                      //   )
                                      // ],
                                    ],
                                    ],
                              ),
                              );
                            },
                          ),
                          addIpo.length == 3
                              ? Container()
                              : Material(
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
                                    onTap: ipo.loading
                                        ? null
                                        : () {
                                            addNewItem();
                                            ipo.categoryOnChange(
                                                addIpo,
                                                ipo.maxUPIAmt,
                                                _getButtonActiveState(ipo),
                                                selectedChip);
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          TextWidget.subText(
                                            text: "Add another bid",
                                            theme: false,
                                            fw: 0,
                                            color: theme.isDarkMode
                                                ? colors.primaryDark
                                                : colors.primaryLight,
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.keyboard_arrow_down,
                                            color: colors.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.isDarkMode ? colors.darkGrey : colors.btnBg,
                          border: Border(
                            top: BorderSide(
                              color: theme.isDarkMode
                                  ? colors.dividerDark
                                  : colors.dividerLight,
                            ),
                            bottom: BorderSide(
                              color: theme.isDarkMode
                                  ? colors.dividerDark
                                  : colors.dividerLight,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              TextWidget.paraText(
                                text: "Margin",
                                theme: false,
                                color: theme.isDarkMode
                                    ? colors.textSecondaryDark
                                    : colors.textSecondaryLight,
                                fw: 0,
                              ),
                              TextWidget.paraText(
                                text: " ${_getMaxPrice(ipo)}",
                                theme: false,
                                color: theme.isDarkMode
                                    ? colors.primaryDark
                                    : colors.primaryLight,
                                fw: 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 45,
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _getButtonActiveState(ipo)
                                ? () {
                                    if (addIpo[addIpo.length - 1].requriedprice >
                                        ipo.maxUPIAmt) {
                                          warningMessage(context,
                                              "Maximum investment upto ₹${double.parse(ipo.maxUPIAmt.toString()).toInt()} only ");
                                      _setButtonActiveState(ipo, false);
                                    } else if (addIpo[addIpo.length - 1]
                                            .bidpricecontroller
                                            .text
                                            .isEmpty ||
                                        addIpo[addIpo.length - 1]
                                                .bidpricecontroller
                                                .text ==
                                            "0") {
                                          warningMessage(
                                              context,
                                              addIpo[addIpo.length - 1]
                                                          .bidpricecontroller
                                                          .text ==
                                                      "0"
                                                  ? "Bid Price Value cannot be 0"
                                                  : "*Bid Price Value is required");
                                    } else if (addIpo[addIpo.length - 1]
                                            .qualityController
                                            .text
                                            .isEmpty ||
                                        addIpo[addIpo.length - 1]
                                                .qualityController
                                                .text ==
                                            "0") {
                                          warningMessage(
                                              context,
                                              addIpo[addIpo.length - 1]
                                                          .qualityController
                                                          .text ==
                                                      "0"
                                                  ? '* Quantity cannot be 0'
                                                  : '* Quantity cannot be empty');
                                    } else {
                                      if (ipo.checkForErrorsInSMEPlaceOrder(
                                          addIpo)) {
                                        _setButtonActiveState(ipo, true);
                                        showModalBottomSheet(
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          isDismissible: true,
                                          shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.vertical(
                                                  top: Radius.circular(16))),
                                          context: context,
                                          builder: (context) => Container(
                                            padding: EdgeInsets.only(
                                              bottom: MediaQuery.of(context)
                                                  .viewInsets
                                                  .bottom,
                                            ),
                                            child: OrderScreenbottomPage(
                                              mainstream: ipoData,
                                              addIpo: addIpo,
                                            ),
                                          ),
                                        );
                                      } else {
                                        warningMessage(context,
                                                "can't able place Order with current selected combination of Bids");
                                        _setButtonActiveState(ipo, false);
                                      }
                                    }
                                  }
                                : () {},
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 45),
                              backgroundColor: _getButtonActiveState(ipo) == false
                                  ?  theme.isDarkMode
                                              ? colors.primaryDark
                                                  .withOpacity(0.5)
                                              : colors.primaryLight
                                                  .withOpacity(0.5) 
                                  : theme.isDarkMode
                                              ? colors.primaryDark
                                              : colors.primaryLight,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            child: TextWidget.titleText(
                              text: "Continue",
                              theme: false,
                              color: _getButtonActiveState(ipo) == false
                              ? colors.colorWhite
                                                      .withOpacity(0.5)
                                  // ? colors.textDisabled
                                  : colors.colorWhite,
                              fw: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  ipoplaceorder(TranctionProvider upiid, IPOProvider ipo) async {
    MenuData menudata = MenuData(
      flow: "now",
      type: ipoType,
      symbol: ipoSymbol,
      category:
          ipo.ipoCategoryvalue == "Individual" || ipo.ipoCategoryvalue == "HNI"
              ? "IND"
              : ipo.ipoCategoryvalue == "Employee"
                  ? "EMP"
                  : ipo.ipoCategoryvalue == "Shareholder"
                      ? "SHA"
                      : ipo.ipoCategoryvalue == "Policyholder"
                          ? "POL"
                          : "",
      name: ipoName,
      applicationNumber: '',
      respBid: [BidReference(bidReferenceNumber: '')],
    );
    final String iposupiid = upiid.upiid.text;
    List<IposBid> iposbids = [];
    for (int i = 0; i < addIpo.length; i++) {
      iposbids.add(IposBid(
          bitis: true,
          qty: int.parse(addIpo[i].qualityController.text).toInt(),
          cutoff: addIpo[i].isChecked,
          price: double.parse(addIpo[i].bidpricecontroller.text).toDouble(),
          total: addIpo[i].requriedprice.toDouble()));
    }

    await ref.read(ipoProvide).fetchupiidvalidation(
        context, upiid.upiid.text, "343245", menudata, iposbids, iposupiid);
  }
}

TextStyle textStyle(Color color, double fontSize, fWeight) {
  return TextStyle(
    fontWeight: fWeight,
    color: color,
    fontSize: fontSize,
  );
}
