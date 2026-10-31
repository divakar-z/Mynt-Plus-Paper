import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/core/api_link.dart';
import '../locator/constant.dart';
import '../res/res.dart';
import 'core/default_change_notifier.dart';
import 'network_state_provider.dart';
import 'websocket_provider.dart';

final showcaseProvide =
    ChangeNotifierProvider((ref) => ShowCaseProvider(ref));

class ShowCaseProvider extends DefaultChangeNotifier {
  final FToast _fToast = FToast();
  FToast get fToast => _fToast;
  final ScrollController depthScrolCtrl = ScrollController();
  final Ref ref;
  ShowCaseProvider(this.ref);

  showToast(String content, BuildContext context) {
    Widget toast = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5.0),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25.0), color: Colors.orange),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(content, style: textStyles.scripNameTxtStyle)),
          const CircularProgressIndicator(color: Colors.blue)
        ],
      ),
    );

    _fToast.showToast(
      child: toast,
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(minutes: 5),
    );

    // Web restores its own subscriptions (WebSubscriptionManager + the depth
    // owner registry). Replaying the legacy globals here re-subscribed the last
    // TOUCHLINE scrip as DEPTH — an owner-less depth feed nothing released.
    if (!kIsWeb &&
        ref.read(networkStateProvider).connectionStatus != ConnectivityResult.none) {
      Future.delayed(const Duration(seconds: 3), () {
        ref.read(websocketProvider).establishConnection(
            channelInput: ConstantName.lastSubscribe,
            task: "t",
            context: context);
        ref.read(websocketProvider).establishConnection(
            channelInput: ConstantName.lastSubscribeDepth,
            task: "d",
            context: context);
        fToast.removeQueuedCustomToasts();
      });
    }
  }

  ScrollController controller = ScrollController();

  Future setTutorialStatus(bool status) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTutorial', status);

    ApiLinks.showAppTutorial = prefs.getBool('showTutorial') ?? true;

    notifyListeners();
  }

  GlobalKey overviewcase = GlobalKey();
  GlobalKey chartcase = GlobalKey();
  GlobalKey optioncase = GlobalKey();
  GlobalKey futurecase = GlobalKey();
  GlobalKey fundamentalcase = GlobalKey();
  GlobalKey creategtt = GlobalKey();
  GlobalKey searchtabcase = GlobalKey();
  GlobalKey watchlisttabcase = GlobalKey();
  GlobalKey sortbycase = GlobalKey();
  GlobalKey createwatchlistcase = GlobalKey();
  GlobalKey filtercase = GlobalKey();
  GlobalKey searchiconcase = GlobalKey();
  GlobalKey indexcardcase = GlobalKey();
  GlobalKey watchlisticoncase = GlobalKey();
  GlobalKey portfolioiconcase = GlobalKey();
  GlobalKey ordericoncase = GlobalKey();
  GlobalKey profileiconcase = GlobalKey();
  GlobalKey scripdatainfocase = GlobalKey();
  GlobalKey sip = GlobalKey();
  GlobalKey createnewwl = GlobalKey();
  GlobalKey changewlcase = GlobalKey();
  GlobalKey changewldeletecase = GlobalKey();
  GlobalKey scripinfobtncase = GlobalKey();
  GlobalKey positiontabcase = GlobalKey();
  GlobalKey holdingstabcase = GlobalKey();
  GlobalKey netmtmcase = GlobalKey();
  GlobalKey netplcase = GlobalKey();
  GlobalKey alltabcase = GlobalKey();
  GlobalKey alllistcardcase = GlobalKey();
  GlobalKey opentabcase = GlobalKey();
  GlobalKey executedtabcase = GlobalKey();
  GlobalKey gttttabcase = GlobalKey();
  GlobalKey tradebooktabcase = GlobalKey();
  GlobalKey viewswitchaccountcase = GlobalKey();
  GlobalKey optionmonthfilter = GlobalKey();
  GlobalKey strikepricecase = GlobalKey();
  GlobalKey indexsegmentchangecase = GlobalKey();
  GlobalKey favindexchangecase = GlobalKey();
  GlobalKey reorderlistcase = GlobalKey();
  GlobalKey selectscripcase = GlobalKey();
  GlobalKey deletescripdetailcase = GlobalKey();
  GlobalKey daynetswitchcase = GlobalKey();
  GlobalKey exiteallpositioncase = GlobalKey();
  GlobalKey postiondetailscase = GlobalKey();
  GlobalKey postionconvertioncase = GlobalKey();
  GlobalKey postionaddmorebtncase = GlobalKey();
  GlobalKey postionexitbtncase = GlobalKey();
  GlobalKey holdingsediscase = GlobalKey();
  GlobalKey holdingsfilterlinecase = GlobalKey();
  GlobalKey holdingsearchcase = GlobalKey();
  GlobalKey holdingsearchfiedcase = GlobalKey();
  GlobalKey holdingclosecase = GlobalKey();
  GlobalKey holdinglistcard = GlobalKey();
  GlobalKey holdingdetailsaddmorecase = GlobalKey();
  GlobalKey holdingexitcase = GlobalKey();
  GlobalKey orderswitchbtncase = GlobalKey();
  GlobalKey notificationcase = GlobalKey();
  GlobalKey optionstrikecase = GlobalKey();
  GlobalKey gttorderscreen = GlobalKey();
  GlobalKey gttcondition = GlobalKey();
  GlobalKey gttvalue = GlobalKey();
  GlobalKey intradaycase = GlobalKey();
  GlobalKey deliverycase = GlobalKey();
  GlobalKey minusiconcase = GlobalKey();
  GlobalKey pluseiconcase = GlobalKey();
  GlobalKey gttocoiconcase = GlobalKey();
  GlobalKey placeoderaddvalcase = GlobalKey();
  GlobalKey placeoderamocase = GlobalKey();
  GlobalKey placeodermargincase = GlobalKey();
  GlobalKey placeoderchargescase = GlobalKey();
  GlobalKey placebuybutton = GlobalKey();
  GlobalKey placesellbutton = GlobalKey();
  GlobalKey buynowcase = GlobalKey();
  GlobalKey orderpricecase = GlobalKey();
  GlobalKey filterlinecase = GlobalKey();
  GlobalKey searchcase = GlobalKey();
  GlobalKey searchtextfiledcase = GlobalKey();
  GlobalKey vistourcase = GlobalKey();

  GlobalKey orderscreenregularcase = GlobalKey();
  GlobalKey orderscreenCovercase = GlobalKey();
  GlobalKey orderscreenBracketcase = GlobalKey();
  GlobalKey limitprctype = GlobalKey();
  GlobalKey marketprctype = GlobalKey();
  GlobalKey sllimitprctype = GlobalKey();
  GlobalKey sllimktprctype = GlobalKey();

  GlobalKey fundcase = GlobalKey();
  GlobalKey accountcase = GlobalKey();
  GlobalKey accdetails = GlobalKey();
  GlobalKey reportcase = GlobalKey();
  GlobalKey corporateactioncase = GlobalKey();
  GlobalKey pledgeunpcase = GlobalKey();
  GlobalKey changepasswordcase = GlobalKey();
  GlobalKey apikeycase = GlobalKey();
  GlobalKey apptour = GlobalKey();
  GlobalKey theamcase = GlobalKey();
  GlobalKey logcase = GlobalKey();
  GlobalKey stokscase = GlobalKey();
////_accountmenu GKEY
  GlobalKey profilecase = GlobalKey();
  GlobalKey bankcase = GlobalKey();
  GlobalKey dpcase = GlobalKey();
  GlobalKey closurecase = GlobalKey();
  GlobalKey segmentcase = GlobalKey();
  GlobalKey annualincomecase = GlobalKey();
  GlobalKey nomineecase = GlobalKey();
////_reportmenu GKEY
  GlobalKey ledegercase = GlobalKey();
  GlobalKey holdingcase = GlobalKey();
  GlobalKey profitandlosscase = GlobalKey();
  GlobalKey taxplcase = GlobalKey();
  GlobalKey tradecase = GlobalKey();
  // List<GlobalKey> showCaseKeys = [];
  GlobalKey alterprice = GlobalKey();
  GlobalKey alert = GlobalKey();
  // initShowCaseKeys() {
  //   showCaseKeys = [
  //     createwatchlistcase,
  //     createnewwl,
  //     watchlisttabcase,
  //     changewlcase,
  //     changewldeletecase,
  //     filtercase,
  //     sortbycase,
  //     searchiconcase,
  //     searchtextfiledcase,
  //     searchtabcase,
  //     indexcardcase,
  //     indexsegmentchangecase,
  //     favindexchangecase,
  //     scripdatainfocase,
  //     overviewcase,
  //     chartcase,
  //     optioncase,
  //        futurecase,

  //     fundamentalcase,
  //     creategtt,
  //     placesellbutton,
  //     placebuybutton,
  //     portfolioiconcase,
  //     daynetswitchcase,
  //     positiontabcase,
  //     netmtmcase,
  //     netplcase,
  //     holdingstabcase,
  //     holdingsediscase,
  //     holdingsfilterlinecase,
  //     holdingsearchcase,
  //     holdinglistcard,
  //     holdingdetailsaddmorecase,
  //     holdingexitcase,
  //     ordericoncase,
  //     alltabcase,
  //     alllistcardcase,
  //     opentabcase,
  //     executedtabcase,
  //     gttttabcase,
  //     tradebooktabcase,
  //     profileiconcase,
  //     viewswitchaccountcase,
  //     fundcase,
  //     accountcase,
  //     reportcase,
  //     corporateactioncase,
  //     pledgeunpcase,
  //     changepasswordcase,
  //     vistourcase,
  //     theamcase,
  //     logcase,
  //     stokscase
  //   ];
  //   notifyListeners();
  // }
}
