import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/order_book_model/gtt_order_book.dart';
import '../models/order_book_model/order_book_model.dart';
import '../sharedWidget/enums.dart';
import 'core/default_change_notifier.dart';
import 'market_watch_provider.dart';

final ordInputProvider =
    ChangeNotifierProvider((ref) => OrderInputProvider(ref));

class OrderInputProvider extends DefaultChangeNotifier {
  final Ref ref;

// Repeat order

  TextEditingController prcCtrl = TextEditingController();
  TextEditingController triggerPriceCtrl = TextEditingController();
  TextEditingController mktProtCtrl = TextEditingController();
  TextEditingController qtyCrl = TextEditingController();
  TextEditingController discQtyCtrl = TextEditingController();
  TextEditingController stopLossCtrl = TextEditingController();
  TextEditingController targetCtrl = TextEditingController();
  TextEditingController trailingTickCtrl = TextEditingController();

  String _orderName = "Delivery";
  String get orderName => _orderName;

  final List _orderNames = ["Delivery", "Intraday", "CO - BO"];
  List get orderNames => _orderNames;

  String _priceName = "Limit";
  String get priceName => _priceName;

  final List _priceNames = ["Limit", "Market", "SL Limit", "SL MKT"];
  List get priceNames => _priceNames;

  String _validityName = "DAY";
  String get validityName => _validityName;

  final List<String> _validityNames = ["DAY", "IOC", "EOS"];
  List<String> get validityNames => _validityNames;

  String priceVal = "0.00";

  // Change order Validaity(Day/Ioc)
  chngeValidity(String val) {
    _validityName = val;
    notifyListeners();
  }

  // Change order type
  chngOrderName(String val) {
    _orderName = val;
    notifyListeners();
  }

  // Change order Price type

  chngPriceName(String val) {
    _priceName = val;
    notifyListeners();
  }

  InvestType _investType = InvestType.intraday;
  InvestType get investType => _investType;

  String _ordType = "C";
  String get orderType => _ordType;

  String _ocoOrdType = "C";
  String get ocoOrderType => _ocoOrdType;

  String _prcType = "LMT";
  String get prcType => _prcType;

  OrderInputProvider(this.ref);

// Change investment type based on condition
  chngInvesType(InvestType val, String orderType) {
    if (orderType == "PlcOrder" || orderType == "GTT") {
      _investType = val;
      if (val == InvestType.intraday) {
        _ordType = "I";
      } else if (val == InvestType.delivery) {
        _ordType = "C";
      }
      else if (val == InvestType.mtf) {
        _ordType = "F";
      }
       else {
        _ordType = "M";
      }
    } else {
      _ocoInvestType = val;

      if (val == InvestType.intraday) {
        _ocoOrdType = "I";
      } else if (val == InvestType.delivery) {
        _ocoOrdType = "C";
      } else {
        _ocoOrdType = "M";
      }
    }

    notifyListeners();
  }

  chngOrderType(
      String val, bool isCoverOrderEnabled, bool isBracketOrderEnabled) {
    if (val == "CO - BO" && isCoverOrderEnabled) {
      _ordType = "H";
    } else if (val == "CO - BO" && isBracketOrderEnabled) {
      _ordType = "B";
    } else {
      _ordType = "F";
    }
    notifyListeners();
    log("val $_ordType");
  }

// This method for retrieving information from the order book to place orders again
  getOrderData(OrderBookModel data) {
    qtyCrl.text = "${data.qty}";
    prcCtrl.text = "${data.prc}";
    triggerPriceCtrl.text = data.trgprc ?? "";
    mktProtCtrl.text = data.mktProtection ?? "5";
    discQtyCtrl.text = data.dscqty ?? "0";
    stopLossCtrl.text = data.blprc ?? "";
    trailingTickCtrl.text = data.trailprc ?? "";
    if (data.sPrdtAli == "MIS" ||
        data.sPrdtAli == "CNC" ||
        data.sPrdtAli == "NRML"||
        data.sPrdtAli == "MTF") {
      _orderName = "Delivery";
      if (data.prd == "C") {
        _ordType = "C";
        _investType = InvestType.delivery;
      } else if (data.prd == "I") {
        _ordType = "I";
        _investType = InvestType.intraday;
      }
      else if (data.prd == "F") {
        _ordType = "F";
        _investType = InvestType.mtf;
      }
       else {
        _ordType = "M";
        _investType = InvestType.carryForward;
      }
    } else if (data.sPrdtAli == "CO") {
      _orderName = "CO - BO";
    } else {
      _orderName = "CO - BO";
    }

    if (data.prctyp == "LMT") {
      _priceName = "Limit";
    } else if (data.prctyp == "MKT") {
      _priceName = "Market";
    } else if (data.prctyp == "SL-LMT") {
      _priceName = "SL Limit";
    } else {
      _priceName = "SL MKT";
    }

    if (_priceName == "Market" || _priceName == "SL MKT") {
      prcCtrl.text = "Market";

      double ltp = (double.parse("${data.ltp}") *
              double.parse(mktProtCtrl.text.isEmpty ? "0" : mktProtCtrl.text)) /
          100;

      if (data.trantype == "B") {
        priceVal =
            (double.parse("${data.ltp ?? 0.00}") + ltp).toStringAsFixed(2);
      } else {
        priceVal =
            (double.parse("${data.ltp ?? 0.00}") - ltp).toStringAsFixed(2);
      }
      double result = double.parse(priceVal) + (double.parse("${data.ti}") / 2);
      result -= result % double.parse("${data.ti}");

      if (result >=
          double.parse(
              "${ref.read(marketWatchProvider).scripInfoModel!.uc ?? 0.00}")) {
        priceVal = "${ref.read(marketWatchProvider).scripInfoModel!.uc}";
      } else if (result <=
          double.parse(
              "${ref.read(marketWatchProvider).scripInfoModel!.lc ?? 0.00}")) {
        priceVal = "${ref.read(marketWatchProvider).scripInfoModel!.lc}";
      } else {
        priceVal = result.toStringAsFixed(2);
      }
    } else {
      prcCtrl.text = "${data.prc}";

      priceVal = prcCtrl.text;
    }
    chngPriceType(_priceName, "${data.exch}");

    notifyListeners();
  }

// Change price type Based on condition
  chngPriceType(String val, String exch) {
    if (val == "Limit") {
      _prcType = "LMT";
    } else if (val == "Market") {
      _prcType = "MKT";
      // _prcType = (exch == "MCX" || exch == "BSE") ? "MKT" : "LMT";
    } else if (val == "SL Limit") {
      _prcType = "SL-LMT";
    } else {
      _prcType = "SL-MKT";
      // _prcType = (exch == "MCX" || exch == "BSE") ? "SL-MKT" : "SL-LMT";
    }
    log(_prcType);
    notifyListeners();
  }

  // GTT ORDER INPUT

  bool _GTTPriceTypeIsMarket = false;
  bool get GTTPriceTypeIsMarket => _GTTPriceTypeIsMarket;

  setGTTPriceTypeIsMarket(bool value) {
    _GTTPriceTypeIsMarket = value;
    notifyListeners();
  }

  bool _GTTOCOPriceTypeIsMarket = false;
  bool get GTTOCOPriceTypeIsMarket => _GTTOCOPriceTypeIsMarket;

  setGTTOCOPriceTypeIsMarket(bool value) {
    _GTTOCOPriceTypeIsMarket = value;
    notifyListeners();
  }

  bool _GTTPriceTypeOrderIsMarket = false;
  bool get GTTPriceTypeOrderIsMarket => _GTTPriceTypeOrderIsMarket;

  setGTTPriceTypeOrderIsMarket(bool value) {
    _GTTPriceTypeOrderIsMarket = value;
    notifyListeners();
  }

  bool _GTTOCOPriceTypeOrderIsMarket = false;
  bool get GTTOCOPriceTypeOrderIsMarket => _GTTOCOPriceTypeOrderIsMarket;

  setGTTOCOPriceTypeOrderIsMarket(bool value) {
    _GTTOCOPriceTypeOrderIsMarket = value;
    notifyListeners();
  }

  String _ait = "LTP_B_O";
  String get ait => _ait;

  TextEditingController _priceCtrl = TextEditingController();
  TextEditingController get priceCtrl => _priceCtrl;

  TextEditingController _ocoPriceCtrl = TextEditingController();
  TextEditingController get ocoPriceCtrl => _ocoPriceCtrl;

  TextEditingController _qtyCtrl = TextEditingController();
  TextEditingController get qtyCtrl => _qtyCtrl;

  TextEditingController _ocoQtyCtrl = TextEditingController();
  TextEditingController get ocoQtyCtrl => _ocoQtyCtrl;

// OCO
  final TextEditingController _val1Ctrl = TextEditingController();
  TextEditingController get val1Ctrl => _val1Ctrl;

  final TextEditingController _val2Ctrl = TextEditingController();
  TextEditingController get val2Ctrl => _val2Ctrl;

  final TextEditingController _trgPrcCtrl = TextEditingController();
  TextEditingController get trgPrcCtrl => _trgPrcCtrl;

  final TextEditingController _ocoTrgPrcCtrl = TextEditingController();
  TextEditingController get ocoTrgPrcCtrl => _ocoTrgPrcCtrl;

  final TextEditingController _reMarksCtrl = TextEditingController();
  TextEditingController get reMarksCtrl => _reMarksCtrl;

  final List<String> _prcTypes = ["Limit", "Market", "SL Limit", "SL MKT"];
  List<String> get prcTypes => _prcTypes;
  String _actPrcType = "Limit";
  String get actPrcType => _actPrcType;

  String _actOcoPrcType = "Limit";
  String get actOcoPrcType => _actOcoPrcType;

  String _ocoPrcType = "LMT";
  String get ocoPrcType => _ocoPrcType;

  InvestType _ocoInvestType = InvestType.intraday;
  InvestType get ocoInvestType => _ocoInvestType;

  bool _disableGTTCond = false;

  bool get disableGTTCond => _disableGTTCond;

  final List<String> _alertTypes = [
    "LTP",
    // "Perc. Change",
    // "ATP",
    // "OI",
    // "TOI",
    // "Volume"
  ];
  List<String> get alertTypes => _alertTypes;
  String _actAlert = "LTP";
  String get actAlert => _actAlert;

  final List<String> _condTypes = ["Less than", "Greater than"];
  List<String> get condTypes => _condTypes;
  String _actCond = "Less than";
  String get actCond => _actCond;

  updatePrcCtrl(String prc, qty) {
    _priceCtrl = TextEditingController(text: prc);
    _qtyCtrl = TextEditingController(text: qty);
    notifyListeners();
  }

  updateOcoPrcQtyCtrl(String prc, String qty) {
    _ocoPriceCtrl = TextEditingController(text: prc);

    _ocoQtyCtrl = TextEditingController(text: qty);
    notifyListeners();
  }

  chngAlert(String val) {
    _actAlert = val;
    if (_actAlert == "LTP" && _actCond == "Less than") {
      _ait = "LTP_B_O";
    }
    if (_actAlert == "LTP" && _actCond == "Greater than") {
      _ait = "LTP_A_O";
    }
    if (_actAlert == "Perc. Change" && _actCond == "Less than") {
      _ait = "CH_PER_B_O";
    }
    if (_actAlert == "Perc. Change" && _actCond == "Greater than") {
      _ait = "CH_PER_A_O";
    }
    if (_actAlert == "ATP" && _actCond == "Less than") {
      _ait = "ATP_B_O";
    }
    if (_actAlert == "ATP" && _actCond == "Greater than") {
      _ait = "ATP_A_O";
    }
    if (_actAlert == "OI" && _actCond == "Less than") {
      _ait = "OI_B_O";
    }
    if (_actAlert == "OI" && _actCond == "Greater than") {
      _ait = "OI_A_O";
    }
    if (_actAlert == "TOI" && _actCond == "Less than") {
      _ait = "TOI_B_O";
    }
    if (_actAlert == "TOI" && _actCond == "Greater than") {
      _ait = "TOI_A_O";
    }
    if (_actAlert == "Volume" && _actCond == "Less than") {
      _ait = "VOLUME_B_O";
    }
    if (_actAlert == "Volume" && _actCond == "Greater than") {
      _ait = "VOLUME_A_O";
    }

    notifyListeners();
  }

  chngCond(String val) {
    _actCond = val;
    notifyListeners();
  }

  chngGTTPriceType(String val) {
    _actPrcType = val;
    if (val == "Limit") {
      _prcType = "LMT";
    } else if (val == "Market") {
      _prcType = "MKT";
    } else if (val == "SL Limit") {
      _prcType = "SL-LMT";
    } else {
      _prcType = "SL-MKT";
    }
    log(_prcType);
    notifyListeners();
  }

  chngOCOPriceType(String val) {
    _actOcoPrcType = val;
    if (val == "Limit") {
      _ocoPrcType = "LMT";
    } else if (val == "Market") {
      _ocoPrcType = "MKT";
    } else if (val == "SL Limit") {
      _ocoPrcType = "SL-LMT";
    } else {
      _ocoPrcType = "SL-MKT";
    }

    notifyListeners();
  }

  /// Resets all GTT/OCO controllers and derived state to defaults.
  clearTextField() {
    _reMarksCtrl.clear();
    _ocoTrgPrcCtrl.clear();
    _trgPrcCtrl.clear();
    _val2Ctrl.clear();
    _val1Ctrl.clear();
    _ocoQtyCtrl.clear();
    _qtyCtrl.clear();
    _ocoPriceCtrl.clear();
    _priceCtrl.clear();
    _GTTPriceTypeOrderIsMarket = false;
    _GTTOCOPriceTypeOrderIsMarket = false;
    _GTTPriceTypeIsMarket = false;
    _GTTOCOPriceTypeIsMarket = false;
    _disableGTTCond = false;
    _ait = "LTP_B_O";
    _actCond = "Less than";
    _actAlert = "LTP";
    _actPrcType = "Limit";
    _prcType = "LMT";
    _actOcoPrcType = "Limit";
    _ocoPrcType = "LMT";
    notifyListeners();
  }

  disableCondGTT(bool val) {
    _disableGTTCond = val;
    notifyListeners();
  }

  /// Clears the OCO leg-2 controllers and price-type state.
  clearOcoFields() {
    _val2Ctrl.clear();
    _ocoQtyCtrl.clear();
    _ocoPriceCtrl.clear();
    _ocoTrgPrcCtrl.clear();
    _GTTOCOPriceTypeOrderIsMarket = false;
    _GTTOCOPriceTypeIsMarket = false;
    _actOcoPrcType = "Limit";
    _ocoPrcType = "LMT";
    notifyListeners();
  }

  // Validate GTT order before submission
  Map<String, dynamic> validateGttOrder(bool isOco) {
    bool isValid = true;
    String errorMessage = "";

    // Check if value is provided for the condition
    if (val1Ctrl.text.isEmpty) {
      isValid = false;
      errorMessage = "Please enter a value for the condition";
      return {"isValid": isValid, "message": errorMessage};
    }

    // Check if quantity is provided
    if (qtyCtrl.text.isEmpty) {
      isValid = false;
      errorMessage = "Please enter quantity";
      return {"isValid": isValid, "message": errorMessage};
    }

    // Check if price is provided for Limit orders
    if ((actPrcType == "Limit" || actPrcType == "SL Limit") &&
        (priceCtrl.text.isEmpty || priceCtrl.text == "0" || priceCtrl.text == "0.0")) {
      isValid = false;
      errorMessage = "Please enter a valid price";
      return {"isValid": isValid, "message": errorMessage};
    }

    // Check trigger price for SL orders
    if ((actPrcType == "SL Limit" || actPrcType == "SL MKT") &&
        (trgPrcCtrl.text.isEmpty || trgPrcCtrl.text == "0" || trgPrcCtrl.text == "0.0")) {
      isValid = false;
      errorMessage = "Please enter a valid trigger price";
      return {"isValid": isValid, "message": errorMessage};
    }

    // Additional validations for OCO orders
    if (isOco) {
      if (val2Ctrl.text.isEmpty) {
        isValid = false;
        errorMessage = "Please enter a value for the OCO condition";
        return {"isValid": isValid, "message": errorMessage};
      }

      if (ocoQtyCtrl.text.isEmpty) {
        isValid = false;
        errorMessage = "Please enter OCO quantity";
        return {"isValid": isValid, "message": errorMessage};
      }

      if ((actOcoPrcType == "Limit" || actOcoPrcType == "SL Limit") &&
          (ocoPriceCtrl.text.isEmpty || ocoPriceCtrl.text == "0" || ocoPriceCtrl.text == "0.0")) {
        isValid = false;
        errorMessage = "Please enter a valid OCO price";
        return {"isValid": isValid, "message": errorMessage};
      }

      if ((actOcoPrcType == "SL Limit" || actOcoPrcType == "SL MKT") &&
          (ocoTrgPrcCtrl.text.isEmpty || ocoTrgPrcCtrl.text == "0" || ocoTrgPrcCtrl.text == "0.0")) {
        isValid = false;
        errorMessage = "Please enter a valid OCO trigger price";
        return {"isValid": isValid, "message": errorMessage};
      }
    }

    return {"isValid": isValid, "message": errorMessage};
  }

// This method for retrieving information from the GTT order book to Modify the order

  /// Pre-fills the controllers from an existing GTT order for the modify dialog.
  /// Pass [lotSize] for MCX so the qty field shows lot count.
  getModifyData(GttOrderBookModel gttOrderBook, {int? lotSize}) {
    _reMarksCtrl.text = "${gttOrderBook.remarks}";
    if (gttOrderBook.placeOrderParams != null) {
      if (gttOrderBook.placeOrderParams!.prctyp == "LMT") {
        chngGTTPriceType("Limit");
      } else if (gttOrderBook.placeOrderParams!.prctyp == "MKT") {
        chngGTTPriceType("Market");
      } else if (gttOrderBook.placeOrderParams!.prctyp == "SL-LMT") {
        chngGTTPriceType("SL Limit");
      } else {
        chngGTTPriceType("SL MKT");
      }
      if (gttOrderBook.placeOrderParams!.prd == "C") {
        _ordType = "C";
        _investType = InvestType.delivery;
      } else if (gttOrderBook.placeOrderParams!.prd == "I") {
        _ordType = "I";
        _investType = InvestType.intraday;
      } else {
        _ordType = "M";
        _investType = InvestType.carryForward;
      }
      if(gttOrderBook.placeOrderParams!.prctyp == "MKT") {
        _priceCtrl.text = "Market";
        _GTTPriceTypeIsMarket = true;
      } else {
        _priceCtrl.text = "${gttOrderBook.placeOrderParams!.prc}";
        _GTTPriceTypeIsMarket = false;
      }
      final bool isMcx = gttOrderBook.exch == "MCX";
      if (isMcx && lotSize != null && lotSize > 0) {
        final int storedQty = int.tryParse("${gttOrderBook.placeOrderParams!.qty}") ?? 0;
        _qtyCtrl.text = (storedQty ~/ lotSize).toString();
      } else {
        _qtyCtrl.text = "${gttOrderBook.placeOrderParams!.qty}";
      }
      _trgPrcCtrl.text = "${gttOrderBook.placeOrderParams!.trgprc}";
    }
    if (gttOrderBook.placeOrderParamsLeg2 != null) {
      disableCondGTT(true);
      if (gttOrderBook.placeOrderParamsLeg2!.prctyp == "LMT") {
        chngOCOPriceType("Limit");
      } else if (gttOrderBook.placeOrderParamsLeg2!.prctyp == "MKT") {
        chngOCOPriceType("Market");
      } else if (gttOrderBook.placeOrderParamsLeg2!.prctyp == "SL-LMT") {
        chngOCOPriceType("SL Limit");
      } else {
        chngOCOPriceType("SL MKT");
      }

      if (gttOrderBook.placeOrderParamsLeg2!.prd == "C") {
        _ocoOrdType = "C";
        _ocoInvestType = InvestType.delivery;
      } else if (gttOrderBook.placeOrderParamsLeg2!.prd == "I") {
        _ocoOrdType = "I";
        _ocoInvestType = InvestType.intraday;
      } else {
        _ocoOrdType = "M";
        _ocoInvestType = InvestType.carryForward;
      }
      if (gttOrderBook.placeOrderParamsLeg2!.prctyp == "MKT") {
        _ocoPriceCtrl.text = "Market";
        _GTTOCOPriceTypeIsMarket = true;
      } else {
        _ocoPriceCtrl.text = "${gttOrderBook.placeOrderParamsLeg2!.prc}";
        _GTTOCOPriceTypeIsMarket = false;
      }
      final bool isMcxOco = gttOrderBook.exch == "MCX";
      if (isMcxOco && lotSize != null && lotSize > 0) {
        final int storedOcoQty = int.tryParse("${gttOrderBook.placeOrderParamsLeg2!.qty}") ?? 0;
        _ocoQtyCtrl.text = (storedOcoQty ~/ lotSize).toString();
      } else {
        _ocoQtyCtrl.text = "${gttOrderBook.placeOrderParamsLeg2!.qty}";
      }
      _ocoTrgPrcCtrl.text = "${gttOrderBook.placeOrderParamsLeg2!.trgprc}";
    } else {
      disableCondGTT(false);
    }

    if (gttOrderBook.oivariable!.isNotEmpty) {
      _val1Ctrl.text = "${gttOrderBook.oivariable![0].d}";
      if (gttOrderBook.placeOrderParamsLeg2 != null) {
        _val2Ctrl.text = "${gttOrderBook.oivariable![1].d}";
      }
    }

    _ait = gttOrderBook.aiT!;
    if (_ait == "LTP_B_O") {
      _actAlert = "LTP";
      _actCond = "Less than";
    }
    if (_ait == "LTP_A_O") {
      _actAlert = "LTP";
      _actCond = "Greater than";
    }
    if (_ait == "CH_PER_B_O") {
      _actAlert = "Perc. Change";
      _actCond = "Less than";
    }
    if (_ait == "CH_PER_A_O") {
      _actAlert = "Perc. Change";
      _actCond = "Greater than";
    }
    if (_ait == "ATP_B_O") {
      _actAlert = "ATP";
      _actCond = "Less than";
    }
    if (_ait == "ATP_A_O") {
      _actAlert = "ATP";
      _actCond = "Greater than";
    }
    if (_ait == "OI_B_O") {
      _actAlert = "OI";
      _actCond = "Less than";
    }
    if (_ait == "OI_A_O") {
      _actAlert = "OI";
      _actCond = "Greater than";
    }
    if (_ait == "TOI_B_O") {
      _actAlert = "TOI";
      _actCond = "Less than";
    }
    if (_ait == "TOI_A_O") {
      _actAlert = "TOI";
      _actCond = "Greater than";
    }
    if (_ait == "VOLUME_B_O") {
      _actAlert = "Volume";
      _actCond = "Less than";
    }
    if (_ait == "VOLUME_A_O") {
      _actAlert = "Volume";
      _actCond = "Greater than";
    }
    notifyListeners();
  }
}
