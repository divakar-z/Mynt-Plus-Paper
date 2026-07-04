import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/utils/cdsl_web_launcher.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/models/desk_reports_model/contract_note_model.dart';
import 'package:mynt_plus/models/desk_reports_model/pdf_download_model.dart';
import 'package:mynt_plus/models/desk_reports_model/pnl_seg_charges_model.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../api/core/api_core.dart';
import '../api/core/api_export.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../models/client_profile_all_details/profile_all_details_model.dart';
import '../models/desk_reports_model/SharingResponseCalendar_model.dart';
import '../models/desk_reports_model/approved_pledge_list_model.dart';
import '../models/desk_reports_model/ca_events_model.dart';
import '../models/desk_reports_model/calender_pnl_model.dart';
import '../models/desk_reports_model/cdsl_response_model.dart';
import '../models/desk_reports_model/cmr_download_model.dart';
import '../models/desk_reports_model/cp_action_model.dart';
import '../models/desk_reports_model/dercomcur_taxpnl_model.dart';
import '../models/desk_reports_model/editreport_model.dart';
import '../models/desk_reports_model/holdings_model.dart';
import '../models/desk_reports_model/ledger_bill_model.dart';
import '../models/desk_reports_model/ledger_model.dart';
import '../models/desk_reports_model/order_response_cop.dart';
import '../models/desk_reports_model/pledge_history_model.dart';
import '../models/desk_reports_model/pledge_segment_check_model.dart';
import '../models/desk_reports_model/pledge_unpledge_model.dart';
import '../models/desk_reports_model/pnl_model.dart';
import '../models/desk_reports_model/pnl_summary_model.dart';
import '../models/desk_reports_model/position_model.dart';
import '../models/desk_reports_model/sharing_on_off_model.dart';
import '../models/desk_reports_model/tax_pnl_Eq_charge_model.dart';
import '../models/desk_reports_model/taxpnl_eq_model.dart';
import '../models/desk_reports_model/tradebook_model.dart';
import '../models/desk_reports_model/unpledge_history_model.dart';
import '../res/global_state_text.dart';
import '../res/res.dart';
import '../routes/route_names.dart';
// import '../screens/desk_reports/bottom_sheets/ledger_filter.dart';
import '../screens/Mobile/desk_reports/bottom_sheets/ledger_filter.dart';
import '../sharedWidget/fund_function.dart';
import 'core/default_change_notifier.dart';
import 'package:intl/intl.dart';

final ledgerProvider = ChangeNotifierProvider((ref) => LDProvider(ref));

// Helper class for document details
class DocumentDetail {
  final String docType;
  final String recno;
  final String docFileName;
  final String docDate;
  DocumentDetail({
    required this.docType,
    required this.recno,
    required this.docFileName,
    required this.docDate,
  });
}

class LDProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();
  final Preferences pref = locator<Preferences>();
  final Ref ref;
  LDProvider(this.ref);
  List<dynamic> _taxpnlyeararray = [];
  List<dynamic> get taxpnlyeararray => _taxpnlyeararray;

  List<dynamic> _listforpledge = [];
  List<dynamic> get listforpledge => _listforpledge;

  List<dynamic> _tradebookfilterarray = [];

  List<dynamic> _isinlistforcopedisdata = [];

  List<dynamic> get tradebookfilterarray => _tradebookfilterarray;

  Map<DateTime, double> _heatmapData = {};
  Map<DateTime, double> get heatmapData => _heatmapData;

  Map<DateTime, List<TradeData>> grouped = {};

  LedgerModelData? _ledgerAllData;
  LedgerModelData? get ledgerAllData => _ledgerAllData;

  LedgerModelData? _ledgerAllDataDummy;
  LedgerModelData? get ledgerAllDataDummy => _ledgerAllDataDummy;

  CmrDownloadModel? _cmrdownload;
  CmrDownloadModel? get cmrdownload => _cmrdownload;

  CPActionModule? _cpactiondata;
  CPActionModule? get cpactiondata => _cpactiondata;

  GetOrderlistCopModel? _orderdetailsdatacop;
  GetOrderlistCopModel? get orderdetailsdatacop => _orderdetailsdatacop;

  EdisReportModel? _edisreportdata;
  EdisReportModel? get edisreportdata => _edisreportdata;

  // ProfileAllDetails? _profiledetails;
  // ProfileAllDetails? get profiledetails => _profiledetails;

  PnlModel? _pnlAllData;
  PnlModel? get pnlAllData => _pnlAllData;

  UnpledgeHistoryModel? _unPledgeHistoryData;
  UnpledgeHistoryModel? get unPledgeHistoryData => _unPledgeHistoryData;

  PledgeHistoryModel? _pledgeHistoryData;
  PledgeHistoryModel? get pledgeHistoryData => _pledgeHistoryData;

  List<dynamic> _historyalterlist = [];
  List<dynamic> get historyalterlist => _historyalterlist;

  PnlModel? _pnlAllDatadummy;
  PnlModel? get pnlAllDataDummy => _pnlAllDatadummy;

  // Calendar PNL data per segment
  Map<String, CalenderpnlModel> _calenderpnlDataBySegment = {};
  Map<String, CalenderpnlModel> get calenderpnlDataBySegment => _calenderpnlDataBySegment;

  // Legacy single data variable (keeping for backward compatibility)
  CalenderpnlModel? _calenderpnlAllData;
  CalenderpnlModel? get calenderpnlAllData {
    final data = _calenderpnlDataBySegment[selectedSegment];
    return data;
  }

  TradeBookModel? _tradebookdata;
  TradeBookModel? get tradebookdata => _tradebookdata;

  TradeBookModel? _tradebookdataDummy;
  TradeBookModel? get tradebookdataDummy => _tradebookdataDummy;
  PdfDownloadModel? _pdfdaataDummy;
  PdfDownloadModel? get pdfdaataDummy => _pdfdaataDummy;

  PdfDownloadModel? _pdfdownload;
  PdfDownloadModel? get pdfdownload => _pdfdownload;

  // PDF Download screen (all documents, no filter)
  PdfDownloadModel? _allPdfDownloads;
  PdfDownloadModel? get allPdfDownloads => _allPdfDownloads;
  PdfDownloadModel? _allPdfDownloadsDummy;
  PdfDownloadModel? get allPdfDownloadsDummy => _allPdfDownloadsDummy;
  bool _allPdfLoading = false;
  bool get allPdfLoading => _allPdfLoading;

  PledgeAndUnpledgeModel? _pledgeandunpledge;
  PledgeAndUnpledgeModel? get pledgeandunpledge => _pledgeandunpledge;

  ApprovedPledgeListModel? _approvepledge;
  ApprovedPledgeListModel? get approvepledge => _approvepledge;

  PledgeAndUnpledgeModel? _pledgedataonly;
  PledgeAndUnpledgeModel? get pledgedataonly => _pledgedataonly;

  CAEventsModel? _caeventalldata;
  CAEventsModel? get caeventalldata => _caeventalldata;

  CdslReponseModel? _cdslresponsedata;
  CdslReponseModel? get cdslresponsedata => _cdslresponsedata;

  // CDSL web flow state: full-panel loader → report
  bool _cdslWebWaiting = false;
  bool get cdslWebWaiting => _cdslWebWaiting;

  bool _cdslWebShowReport = false;
  bool get cdslWebShowReport => _cdslWebShowReport;

  Timer? _cdslApiPollTimer;

  PledgeSegmentCheckModel? _pledgesegmentcheck;
  PledgeSegmentCheckModel? get pledgesegmentcheck => _pledgesegmentcheck;

  TaxPnlEqModel? _taxpnleq;
  TaxPnlEqModel? get taxpnleq => _taxpnleq;

  DercomcurModel? _taxpnldercomcur;
  DercomcurModel? get taxpnldercomcur => _taxpnldercomcur;

  PositionModel? _positiondata;
  PositionModel? get positiondata => _positiondata;

  var taxpnleqselectedtabdata;

  var taxpnlderselectedtabdata;

  var taxpnlcomselectedtabdata;

  var taxpnlcurselectedtabdata;

  HoldingModel? _holdingsAllData;
  HoldingModel? get holdingsAllData => _holdingsAllData;

  SharingResponse? _sharingdatacalendar;
  SharingResponse? get sharingdatacalendar => _sharingdatacalendar;

  OnorOffSharingModel? _sharingturonandoff;
  OnorOffSharingModel? get sharingturonandoff => _sharingturonandoff;

  LedgerBillModel? _ledgerBillData;
  LedgerBillModel? get ledgerBillData => _ledgerBillData;

  PnlSummaryModel? _pnlSummaryData;
  PnlSummaryModel? get pnlSummaryData => _pnlSummaryData;

  PnlSegCharge? _pnlsegCharge;
  PnlSegCharge? get pnlsegCharge => _pnlsegCharge;

  // Calendar PnL — per-segment charges cache
  final Map<String, PnlSegCharge?> _calendarChargesBySegment = {};
  static String _calSegCode(String segment) => switch (segment) {
        'FNO'       => 'fno',
        'Commodity' => 'comm',
        'Currency'  => 'curr',
        _           => 'eq',
      };
  PnlSegCharge? get currentCalendarCharge =>
      _calendarChargesBySegment[_calSegCode(selectedSegment)];
  bool get calendarChargesLoading => _calendarChargesLoading;
  bool _calendarChargesLoading = false;

  TaxPnlEqCharges? _taxpnleqCharge;
  TaxPnlEqCharges? get taxpnleqCharge => _taxpnleqCharge;

  final List<List<dynamic>> _tablearray = [];
  List<List<dynamic>> get tablearray => _tablearray;

//   List<List<dynamic>> _tableArray;
// List get tablearray = _tableArray;
  DateTime? _endsDate;
  DateTime? get endsDate => _endsDate;

  DateTime _curDate = DateTime.now();

  DateTime get curDate => _curDate;
  DateTime? _pickedStartDate;
  DateTime? get pickedStartDate => _pickedStartDate;

  DateTime? _pickedEndDate;

  String _dummyStartYear = "";
  String _pdfresponse = "";
  String get pdfresponse => _pdfresponse;

  Timer? _timer;
  Timer? get timer => _timer;

  bool _edisclickfromcpaction = false;
  bool get edisclickfromcpaction => _edisclickfromcpaction;

  String _timedis = '';
  String get timedis => _timedis;

  String _requiredamountforofs = 'Required Amount to bid';
  String get requiredamountforofs => _requiredamountforofs;

  set requireamountsetter(val) {
    _requiredamountforofs = val;
  }

  String _captionforofs = 'Enter bid quantity and price';
  String get captionforofs => _captionforofs;

  String _noticenewfeature = '';
  String get noticenewfeature => _noticenewfeature;

  set settime(String? val) {
    _timedis = val.toString();
  }

  bool _valforcheck = false;
  bool get valforcheck => _valforcheck;

  bool _cutoffcheckboxofs = false;
  bool get cutoffcheckboxofs => _cutoffcheckboxofs;

  bool _pricevalidcp = false;
  bool get pricevalidcp => _pricevalidcp;

  bool _qtyvalidcp = false;
  bool get qtyvalidcp => _qtyvalidcp;

  bool _pnlrmtm = true;
  bool get pnlrmtm => _pnlrmtm;

  bool _loader = false;
  bool get loader => _loader;

  String _dummyStartdate = "";
  String _dummyStartmonth = "";
  String _dummyEndYear = "";

  SingingCharacter? _filterval;
  SingingCharacter? get filterval => _filterval;

  set setfilterval(SingingCharacter? val) {
    _filterval = val;
  }

  set setterfornullallSwitch(val) {
    _ledgerAllData = val;
    _holdingsAllData = val;
    _pnlAllData = val;
    _calenderpnlAllData = val;
    _taxpnleq = val;
    _taxpnldercomcur = val;
    _tradebookdata = val;
    _pdfdownload = val;
    _pledgeandunpledge = val;
    _positiondata = val;
    _caeventalldata = val;
    _sharingdatacalendar = val;
    _cpactiondata = val;

    // Clear calendar PnL related data structures when switching accounts
    if (val == null) {
      clearCalendarPnLData();
    }
  }

  String _eqtypestring = "";
  String get eqtypestring => _eqtypestring;

  String _ucode = "";
  String get ucode => _ucode;

  String _dayforpledgeunpledge = "";
  String get dayforpledgeunpledge => _dayforpledgeunpledge;

  String _segmentvalue = "";
  String get segmentvalue => _segmentvalue;

  String _segmentvaluedummy = "";
  String get segmentvaluedummy => _segmentvaluedummy;

  String _screenpledge = "";
  String get screenpledge => _screenpledge;

  String _pledgeorunpledge = "";
  String get pledgeorunpledge => _pledgeorunpledge;

  String _pledgeoruppledgedelete = "";
  String get pledgeoruppledgedelete => _pledgeoruppledgedelete;

  // Filter for pledge list: 'all', 'cash', 'noncash'
  String _pledgeCashFilter = "all";
  String get pledgeCashFilter => _pledgeCashFilter;

  void setPledgeCashFilter(String val) {
    _pledgeCashFilter = val;
    notifyListeners();
  }

  String _cpactionerrormsg = "";
  String get cpactionerrormsg => _cpactionerrormsg;

  bool _cpactionsubtn = false;
  bool get cpactionsubtn => _cpactionsubtn;

  Map _segresponse = {};
  Map get segresponse => _segresponse;

  int _holdingdetailindex = 0;
  int get holdingdetailindex => _holdingdetailindex;

  String _cpactionerrormsgqty = "";
  String get cpactionerrormsgqty => _cpactionerrormsgqty;

  set setholdingdetailindex(val) {
    _holdingdetailindex = val;
  }

  String _currentfilterpage = "";
  String get currentfilterpage => _currentfilterpage;

  set setfilterpage(val) {
    _currentfilterpage = val;
  }

  String _selectvalueofcpaction = "CA";
  String get selectvalueofcpaction => _selectvalueofcpaction;

  set setselectvalueofcpaction(val) {
    _selectvalueofcpaction = val;
    notifyListeners();
  }

  set setedisclickfromcpaction(val) {
    _edisclickfromcpaction = val;
    notifyListeners();
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  TextEditingController profitlossSearchCtrl = TextEditingController();
  clearProfitlossSearch() {
    profitlossSearchCtrl.clear();
    // Reset to original data when search is cleared
    if (_originalGrouped.isNotEmpty) {
      grouped = Map.from(_originalGrouped);
      notifyListeners();
    }
  }

  TextEditingController ledgerSearchCtrl = TextEditingController();
  clearLedgerSearch() {
    ledgerSearchCtrl.clear();
    // Reset to original data when search is cleared
    if (_ledgerAllDataDummy != null) {
      _ledgerAllData = LedgerModelData.fromJson(_ledgerAllDataDummy!.toJson());
      _ledgerAllData!.fullStat?.sort((a, b) {
        return int.parse(b.sortNo!).compareTo(int.parse(a.sortNo!));
      });
    }
    notifyListeners();
  }

  bool _showProfitlossSearch = false;
  bool get showProfitlossSearch => _showProfitlossSearch;

  showProfiossSearch(bool value) {
    _showProfitlossSearch = value;
    notifyListeners();
  }

  bool _showLedgerSearch = true;
  bool get showLedgerSearch => _showLedgerSearch;

  void showledgerSearch(bool value) {
    _showLedgerSearch = value;
    if (value) {
      // When closing search, reset the search and restore full data
      clearLedgerSearch();
      // Optionally, you can also re-fetch data if needed
      // fetchLegerData(context, startDate, endDate);
    }
    notifyListeners();
  }

  // Store original grouped data for search reset
  Map<DateTime, List<TradeData>> _originalGrouped = {};

  profitlossSearch(String value, BuildContext context) {
    // If this is the first search, store the original data
    if (_originalGrouped.isEmpty) {
      _originalGrouped = Map.from(grouped);
    }

    if (value.isEmpty) {
      // Reset to original data when search is cleared
      grouped = Map.from(_originalGrouped);
    } else {
      // Create a new filtered grouped map
      Map<DateTime, List<TradeData>> filteredGrouped = {};

      // Helper to format date as '15 Jun 2025'
      String formatDate(DateTime date) {
        const monthAbbrs = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        return '${date.day.toString().padLeft(2, '0')} '
            '${monthAbbrs[date.month - 1]} '
            '${date.year}';
      }

      final searchTerm = value.toLowerCase();

      _originalGrouped.forEach((date, trades) {
        // Check if search term matches the formatted date string
        final dateString = formatDate(date).toLowerCase();
        bool dateMatches = dateString.contains(searchTerm);

        // Filter trades for this date
        List<TradeData> filteredTrades = trades.where((element) {
          final symbol = element.sCRIPSYMBOL?.toLowerCase() ?? '';
          final scripName = element.sCRIPNAME?.toLowerCase() ?? '';
          return symbol.contains(searchTerm) || scripName.contains(searchTerm);
        }).toList();

        // If date matches, include all trades for that date
        if (dateMatches) {
          filteredGrouped[date] = trades;
        } else if (filteredTrades.isNotEmpty) {
          filteredGrouped[date] = filteredTrades;
        }
      });

      grouped = filteredGrouped;
    }

    notifyListeners();
  }

  // Filtered CP Action data based on selected action type
  List<dynamic> get filteredCPActionData {
    if (_cpactiondata?.corporateAction == null) return [];

    return _cpactiondata!.corporateAction!.where((item) {
      switch (_selectvalueofcpaction) {
        case 'CA':
          return item.issueType == 'BB' ||
              item.issueType == 'BUYBACK' ||
              item.issueType == 'DLST' ||
              item.issueType == 'DS' ||
              item.issueType == 'TAKEOVER' ||
              item.issueType == 'TO';
        // case 'Buyback':
        //   return item.issueType == 'BB' || item.issueType == 'BUYBACK';
        // case 'Delisting':
        //   return item.issueType == 'DLST' || item.issueType == 'DS';
        // case 'Takeover':
        //   return item.issueType == 'TAKEOVER' || item.issueType == 'TO';
        case 'OFS':
          return item.issueType == 'IS' || item.issueType == 'RS';
        // case 'RIGHTS':
        //   return item.issueType == 'RIGHTS';
        default:
          return false;
      }
    }).toList();
  }

//loadingsssssssssssssssssssssssssssssssss reportssssssssssssssss
  bool _reportsloading = false;
  bool get reportsloading => _reportsloading;

  bool _pledgeloader = false;
  bool get pledgeloader => _pledgeloader;

  bool _approvepledgeloader = false;
  bool get approvepledgeloader => _approvepledgeloader;

  bool _ledgerloading = false;
  bool get ledgerloading => _ledgerloading;

  bool _cpactionloader = false;
  bool get cpactionloader => _cpactionloader;

  bool _pledgehistory = false;
  bool get pledgehistory => _pledgehistory;

  bool _positionloading = false;
  bool get positionloading => _positionloading;

  bool _holdingsloading = false;
  bool get holdingsloading => _holdingsloading;

  bool _pnlloading = false;
  bool get pnlloading => _pnlloading;

  bool _calendarpnlloading = false;
  bool get calendarpnlloading => _calendarpnlloading;

  // Segment-specific loading states for Calendar PnL
  Map<String, bool> _calendarPnlLoadingBySegment = {};
  bool isCalendarPnlLoadingForSegment(String segment) {
    return _calendarPnlLoadingBySegment[segment] ?? false;
  }
  void setCalendarPnlLoadingForSegment(String segment, bool loading) {
    _calendarPnlLoadingBySegment[segment] = loading;
    notifyListeners();
  }

  bool _taxderloading = false;
  bool get taxderloading => _taxderloading;

  bool _taxpnlloading = false;
  bool get taxpnlloading => _taxpnlloading;

  bool _istaxpnlclosed = false;
  bool get istaxpnlclosed => _istaxpnlclosed;

  setistaxpnlclosed(val) {
    _istaxpnlclosed = val;
    notifyListeners();
  }

  bool _caeventloading = false;
  bool get caeventloading => _caeventloading;

  bool _tradebookloading = false;
  bool get tradebookloading => _tradebookloading;

  bool _pdfdownloadloading = false;
  bool get pdfdownloadloading => _pdfdownloadloading;

  bool _isDaily = false;
  bool get isDaily => _isDaily;

  bool _reportsloadingforcharges = false;
  bool get reportsloadingforcharges => _reportsloadingforcharges;

  String _dertypestring = "";
  String get dertypestring => _dertypestring;

  String _comtypestring = "";
  String get comtypestring => _comtypestring;

  String _curtypestring = "";
  String get curtypestring => _curtypestring;

  set clickedvaluecur(val) {
    _curtypestring = val;
  }

  int _activeTabTaxPnl = 0;
  int get activeTabTaxPnl => _activeTabTaxPnl;

  int _yearforTaxpnl = 0;
  int get yearforTaxpnl => _yearforTaxpnl;

  int _yearforTaxpnlDummy = 0;
  int get yearforTaxpnlDummy => _yearforTaxpnlDummy;

  set clickedvaluecom(val) {
    _comtypestring = val;
  }

  set clickedvalue(val) {
    _eqtypestring = val;
  }

  set screenclickedpledge(val) {
    _screenpledge = val;
  }

  int _eqdertabvalue = 0;
  int get eqdertabvalue => _eqdertabvalue;

  set clickedtabvalue(val) {
    _eqdertabvalue = val;
  }

  set clickedvalueder(val) {
    _dertypestring = val;
  }

  String _startDate = "";
  String get startDate => _startDate;
  set startDate(String val) {
    _startDate = val;
    notifyListeners();
  }

  String _lastweekdate = "";
  String get lastweekdate => _lastweekdate;

  String _today = "";
  String get today => _today;
  set today(String val) {
    _today = val;
    notifyListeners();
  }

  String _endDate = "";
  String get endDate => _endDate;
  set endDate(String val) {
    _endDate = val;
    notifyListeners();
  }

  set clickchangemtmandpnl(val) {
    _pnlrmtm = val;
    notifyListeners();
  }

  getYearlistTaxpnl() {
    DateTime today = DateTime.now();
    int yyyy = today.year;
    int mm = today.month;
    _taxpnlyeararray = [];
    int yearmount = (mm < 4) ? (yyyy - 1) : yyyy;
    // int startYear = yearmount - 4;
    int startYear = yearmount;
    _yearforTaxpnl = startYear;
    _yearforTaxpnlDummy = startYear;
    for (int year = yearmount; year >= startYear; year--) {
      _taxpnlyeararray.add(year);
    }

  }

  getCurrentDate(String trade) {
    if (trade == 'pandu') {
      var date = DateTime.now();

      _dayforpledgeunpledge = DateFormat('EEEE').format(date);
    }
    _curDate = DateTime.now();
    _pickedStartDate = null;

    DateTime seventhDayBefore = _curDate.subtract(Duration(days: 7));

    // Define the date format
    DateFormat dateFormat = DateFormat('dd/MM/yyyy');

    // Print in reverse order
    final date =
        _curDate.day.toString().padLeft(2, '0'); // Ensures "01", "02", etc.
    final month =
        _curDate.month.toString().padLeft(2, '0'); // Ensures "04" for April
    final year = _curDate.year.toString();


    if (_curDate.month > 3) {
      _dummyStartYear = _curDate.year.toString();
      _dummyEndYear = "${_curDate.year + 1}";
      _dummyStartdate = _curDate.day.toString();
      _dummyStartmonth = _curDate.month.toString();
    } else {
      _dummyStartYear = "${_curDate.year - 1}";
      _dummyEndYear = _curDate.year.toString();

    }

    _today = "$date/$month/$year";
    if (trade == 'tradebook') {
      _startDate = dateFormat.format(seventhDayBefore);
      _endDate = "$date/$month/$year";
    } else if (trade == 'caevent') {
      // _startDate = "$year-$month-$date";
      // _endDate = "$year-$month-$date";
      _startDate = "$date/$month/$year";
      _endDate = "$date/$month/$year";
    } else {
      _startDate = "01/04/$_dummyStartYear";
      _endDate = "31/03/${_dummyEndYear}";
    }

    notifyListeners();
  }

  void datePickerStart(BuildContext context, ThemesProvider theme) async {
    DateTime? pickedDate = _pickedStartDate ?? _curDate;

    await showModalBottomSheet(
      context: context,
      backgroundColor: theme.isDarkMode ? Colors.black : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 300, // Adjust the calendar height
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: theme.isDarkMode
                          ? Colors.white
                          : colors
                              .primaryLight, // Selected date highlight color
                      onPrimary: theme.isDarkMode
                          ? Colors.black
                          : colors.colorWhite, // Selected text color
                      surface: theme.isDarkMode ? Colors.black : Colors.white,
                      onSurface: theme.isDarkMode
                          ? Colors.white
                          : Colors.black, // Text color
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: pickedDate,
                    firstDate: DateTime(_curDate.year - 200),
                    lastDate: DateTime(_curDate.year + 200),
                    onDateChanged: (date) {
                      pickedDate = date;
                    },
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // TextButton(
                  //   onPressed: () => Navigator.pop(context),
                  //   child: Text(
                  //     "Cancel",
                  //     style: TextStyle(
                  //       color: theme.isDarkMode
                  //           ? Colors.grey[300]
                  //           : theme.isDarkMode
                  //               ? Colors.white
                  //               : Colors.black,
                  //     ),
                  //   ),
                  // ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      // minimumSize: const Size(0, 40), // width, height

                      backgroundColor: theme.isDarkMode
                          ? colors.primaryDark
                          : colors.primaryLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onPressed: () {
                      if (pickedDate != null) {
                        _pickedStartDate = pickedDate;
                        _startDate =
                            "${_pickedStartDate!.day}/${_pickedStartDate!.month}/${_pickedStartDate!.year}";
                        notifyListeners();
                      }
                      Navigator.pop(context);
                    },
                    child: TextWidget.subText(
                      text: "Ok",
                      theme: theme.isDarkMode,
                      fw: 2,
                      color: colors.colorWhite,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // datePickerEnd(BuildContext context) async {
  //   final DateTime? picked = await showDatePicker(
  //       currentDate: _pickedEndDate ?? _curDate,
  //       context: context,
  //       initialDate: _pickedEndDate ?? _curDate,
  //       firstDate: DateTime(_curDate.year - 200),
  //       lastDate: DateTime(_curDate.year + 200));
  //   if (picked != null) {
  //     _pickedEndDate = picked;
  //     _endDate =
  //         "${_pickedEndDate!.day}/${_pickedEndDate!.month}/${_pickedEndDate!.year}";

  //   }
  // }

  void datePickerEnd(BuildContext context, ThemesProvider theme) async {
    DateTime? pickedDate = _endsDate ?? _curDate;

    await showModalBottomSheet(
      context: context,
      backgroundColor: theme.isDarkMode ? Colors.black : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 300, // Adjust the calendar height
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: theme.isDarkMode
                          ? Colors.white
                          : Colors.black, // Selected date highlight color
                      onPrimary: theme.isDarkMode
                          ? Colors.black
                          : Colors.white, // Selected text color
                      surface: theme.isDarkMode ? Colors.black : Colors.white,
                      onSurface: theme.isDarkMode
                          ? Colors.white
                          : Colors.black, // Text color
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: pickedDate,
                    firstDate: DateTime(_curDate.year - 2),
                    lastDate: DateTime(_curDate.year + 2),
                    onDateChanged: (date) {
                      pickedDate = date;
                    },
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: theme.isDarkMode
                            ? Colors.grey[300]
                            : theme.isDarkMode
                                ? Colors.white
                                : Colors.black,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (pickedDate != null) {
                        _endsDate = pickedDate;
                        _endDate =
                            "${_endsDate!.day}/${_endsDate!.month}/${_endsDate!.year}";
                        notifyListeners();
                      }
                      Navigator.pop(context);
                    },
                    child: Text(
                      "OK",
                      style: TextStyle(
                        color: theme.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // datePickerEnd(BuildContext context) async {
  //   final DateTime? picked = await showDatePicker(
  //       currentDate: _endsDate ?? _curDate,
  //       context: context,
  //       initialDate: _endsDate ?? _curDate,
  //       firstDate: DateTime(_curDate.year - 2),
  //       lastDate: DateTime(_curDate.year + 2));
  //   if (picked != null) {
  //     _endsDate = picked;
  //     _endDate = "${_endsDate!.day}/${_endsDate!.month}/${_endsDate!.year}";
  //   }
  //   notifyListeners();
  // }

  filtervalchange() {
    _ledgerAllData = null;
    notifyListeners();
  }
  ////API CALL

  // Future fetchprofiledata() async {
  //   try {
  //     notifyListeners();

  //     _profiledetails = await api.getClientProfileAllDetailsApi();
  //     notifyListeners();
  //   } catch (e) {
  //     // ScaffoldMessenger.of(context).showSnackBar(
  //     //   warningMessage(context, 'Error occurred try again later'),
  //     // );
  //     debugPrint("$e");
  //   }
  // }

  Future fetchLegerData(BuildContext context, String from, String to, bool includeBillMargin) async {
    try {
      _ledgerloading = true;
      notifyListeners();

      _ledgerAllDataDummy = await api.getLedgerdata(from, to, includeBillMargin);
      _ledgerAllData = LedgerModelData.fromJson(_ledgerAllDataDummy!.toJson());
      _ledgerAllData!.fullStat?.sort((a, b) {
        return int.parse(b.sortNo!).compareTo(int.parse(a.sortNo!));
      });
      // Reset filters based on includeBillMargin parameter
      _selectedFilters = {
        SingingCharacter.receipt,
        SingingCharacter.payment,
        SingingCharacter.journal,
        SingingCharacter.systemjournal,
      };
      
      // Only add billmargin if includeBillMargin is true
      if (includeBillMargin) {
        _selectedFilters.add(SingingCharacter.billmargin);
      }
      _ledgerloading = false;
      notifyListeners();
    } catch (e) {
      _ledgerloading = false;
    }
  }

  Future fetchcmrdownload(BuildContext context) async {
    try {
      _cmrdownload = await api.cmrdownload();
      final Uri uri =
          Uri.parse("https://rekycbe.mynt.in/${_cmrdownload!.path}");
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch  ';
      }

      notifyListeners();
    } catch (e) {
    }
  }


  Future redirecttopositionsbeta(BuildContext context) async {
    try {
      final Uri uri =
          Uri.parse('https://profile.zebuetrade.com/positions/?uid=${pref.clientId}&token=${pref.token}');
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch  ';
      }

      notifyListeners();
    } catch (e) {
    }
  }
//  final Uri uri = Uri.parse(
//           "${apiLinks.reportsapi}/downloaddocmob?cc=${prefs.clientId}&recno=${recno}");
//       if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
//         throw 'Could not launch  ';
//       }

  Future fetchunpledgehistory(BuildContext context) async {
    try {
      _pledgehistory = true;
      notifyListeners();

      _unPledgeHistoryData = await api.getunpledgehistory();
      //  _ledgerAllData = new LedgerModelData();
    } catch (e) {
      _pledgehistory = false;
      // ScaffoldMessenger.of(context).showSnackBar(
      //   warningMessage(context, 'Error occurred try again later'),
      // );
    }
  }

  Future fetchpledgehistory(BuildContext context) async {
    try {
      _pledgehistory = true;
      _historyalterlist = [];
      notifyListeners();
      _pledgeHistoryData = await api.getpledgehistory();
      if (_pledgeHistoryData?.data?.isNotEmpty ?? false) {
        for (var i = 0; i < _pledgeHistoryData!.data!.length; i++) {
          final dataItem = _pledgeHistoryData!.data![i];
          if (dataItem.reqList != null && dataItem.reqList!.isNotEmpty) {
            for (var y = 0; y < dataItem.reqList!.length; y++) {
              dataItem.reqList![y].reqid = dataItem.reqid;
              dataItem.reqList![y].datetime = dataItem.datTim;
              _historyalterlist.add(dataItem.reqList![y]);
            }
          }
        }
      }


      //  _ledgerAllData = new LedgerModelData();
      _pledgehistory = false;
      notifyListeners();
    } catch (e) {
      _pledgehistory = false;
      // ScaffoldMessenger.of(context).showSnackBar(
      //   warningMessage(context, 'Error occurred try again later'),
      // );
    }
  }

  Future fetchposition(BuildContext context) async {
    try {
      _positionloading = true;
      notifyListeners();

      _positiondata = await api.getposition();
      _positionloading = false;
      calltimes();

      notifyListeners();
    } catch (e) {
      _positionloading = false;
      notifyListeners();
        warningMessage(context, 'Error occurred in positions try again later');
    }
  }

  calltimes() {
    if (_timer != null) {
      _timer!.cancel();

      _timer = null;
      notifyListeners();
    }
    if (_timedis == '') {
      final time = DateFormat('hh:mm:ss a').format(DateTime.now());
      _timedis = time;
    }
    _timer = Timer.periodic(Duration(seconds: 5), (_) async {
      final time = DateFormat('hh:mm:ss a').format(DateTime.now());
      _timedis = time;
      _positiondata = await api.getposition();
      // print("objectobjectobjectobjectobjectobjectobjectobject $time");
      notifyListeners();
    });
  }

  ccancelalltimes() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      notifyListeners();
    }
  }

  Future fetchholdingsData(String from, BuildContext context) async {
    try {
      _holdingsloading = true;

      notifyListeners();
      
      // _holdingsAllData = await api.mockHoldingsResponse();

      _holdingsAllData = await _holdingsFromNoren();

  
      _holdingsloading = false;
      notifyListeners();

    } catch (e) {
      _holdingsloading = false;
      // ScaffoldMessenger.of(context).showSnackBar(
      //   warningMessage(context, 'Error occurred try again later'),
      // );
    } finally {
      await requestWS(context: context, isSubscribe: true);
      notifyListeners();
    }
  }

  /// Re-uses the Noren `Holdings` call from PortfolioAPI (the same one that
  /// powers the Holdings tab) and transforms each item into the legacy
  /// {ISIN, NET, APPROVED, NPOADQTY} map shape.
  ///
  /// - `APPROVED` is the computed `saleableQty` (= holdqty+dpqty+btstqty-usedqty)
  ///   — represents what the user can actually tender.
  /// - `NPOADQTY` is Noren's raw npoadqty value, used by Gate 2 with the
  ///   same condition as the Holdings tab's e-DIS button: if present
  ///   (not the literal "null"), user needs to authorize e-DIS.
  Future<HoldingModel> _holdingsFromNoren() async {
    final result = await api.getHolding();
    final data = result['data'];
    if (data is! List) return HoldingModel.fromJson({});
    int parseQty(String? v) => int.tryParse(v ?? '0') ?? 0;
    final List<Map<String, dynamic>> mapped = [];
    for (final h in data) {
      final exchTsym = h.exchTsym;
      String? isin;
      if (exchTsym != null && exchTsym.isNotEmpty) {
        isin = exchTsym.first.isin;
      }
      if (isin == null || isin.isEmpty) continue;
      final saleable = (parseQty(h.holdqty) +
              parseQty(h.dpQty) +
              parseQty(h.btstqty)) -
          parseQty(h.usedqty);
      mapped.add({
        'ISIN': isin,
        'NET': h.holdqty ?? '0',
        'APPROVED': saleable.toString(),
        'NPOADQTY': h.npoadqty,
      });
    }
    return HoldingModel.fromJson({'Holdings': mapped});
  }

  Future fetchcpactiondata(BuildContext context) async {
    try {
      _cpactionloader = true;
      // notifyListeners();

      _cpactiondata = await api.getcpactiondata();

      // Make sure holdings are loaded *before* the ISIN eligibility check.
      // The screen kicks off both fetches in parallel — if holdings haven't
      // arrived yet, every row would stamp as "no" → "Not Eligible".
      if (_holdingsAllData == null) {
        await fetchholdingsData('', context);
      }

      await hodlingshavecheckfunction();

      //  _ledgerAllData = new LedgerModelData();

      _cpactionloader = false;
      notifyListeners();
    } catch (e) {
      _cpactionloader = false;
      // ScaffoldMessenger.of(context).showSnackBar(
      //   warningMessage(context, 'Error occurred try again later'),
      // );
      notifyListeners();
    }
  }

  ordercheckfunction() async {
    try {
      // Fetch order details once before processing
      _orderdetailsdatacop = await api.getorderdetails();

      for (var i = 0; i < _cpactiondata!.corporateAction!.length; i++) {
        final data = _cpactiondata!.corporateAction![i];
        bool matchFound = false;

        if (_orderdetailsdatacop?.msg != null) {
          // Search for matching order details
          for (var j = 0; j < _orderdetailsdatacop!.msg!.length; j++) {
            final data2 = _orderdetailsdatacop!.msg![j];
            if (data.symbol == data2.symbol &&
                data.issueType == data2.series) {
              // Match found - set order details
              data.orderstatus = data2.status;
              data.bidqty = data2.bidQuan;
              data.appno = data2.applicationNo;
              data.orderprice = data2.price;
              data.rejectionreason = data2.rejectionreason;

              matchFound = true;
              // Exit inner loop once match is found
            }
          }
        }

        // If no match found, set default values
        if (!matchFound) {
          data.orderstatus = 'null';
          data.bidqty = 'null';
          data.appno = 'null';
          data.orderprice = 'null';
          data.rejectionreason = null;
        }
      }

      // Backend confirmed EdisReport is deprecated/down — approvedqty now
      // comes from Noren saleableQty stamped in hodlingshavecheckfunction.
      // await edischeckfunction('');
      notifyListeners();
    } catch (e) {
    }
  }

  hodlingshavecheckfunction() async {
    for (var i = 0; i < _cpactiondata!.corporateAction!.length; i++) {
      final data = _cpactiondata!.corporateAction![i];
      data.eligibleornot = 'no';
      // Default approvedqty so non-matching rows show 0 instead of stale state
      data.approvedqty = '0';
      if (_holdingsAllData != null) {
        for (var y = 0; y < _holdingsAllData!.holdings!.length; y++) {
          final data2 = _holdingsAllData!.holdings![y];
          if (data.isin == data2['ISIN']) {
            data.eligibleornot = 'yes';
            data.havingqty = data2['NET'].toString();
            // approvedqty = computed saleableQty (cap for tendering)
            // npoadqty   = raw Noren value, used by Gate 2 (same logic as
            //              the Holdings tab's e-DIS button)
            data.approvedqty = data2['APPROVED']?.toString() ?? '0';
            data.npoadqty = data2['NPOADQTY']?.toString();
            _isinlistforcopedisdata.add(data2['ISIN']);

            break;
          }
        }
      }
    }
    await ordercheckfunction();

    notifyListeners();
  }

  edischeckfunction(String key) async {
    if (key == 'fromedit') {
      _cpactionloader = true;
    }
    _edisreportdata = await api.geteditsdata(_isinlistforcopedisdata);
    if (_edisreportdata?.data != null) {
      for (var i = 0; i < _cpactiondata!.corporateAction!.length; i++) {
        final data = _cpactiondata!.corporateAction![i];
        data.approvedqty = '0';
        for (var j = 0; j < _edisreportdata!.data!.length; j++) {
          final data2 = _edisreportdata!.data![j];
          if (data.isin == data2.isin) {
            data.approvedqty = data2.qty.toString();
          }
        }
      }
    }
    if (key == 'fromedit') {
      _cpactionloader = false;
    }
    notifyListeners();
  }

  Future putordercopaction(
      String tabval,
      String sym,
      String exchange,
      String issueType,
      String qty,
      String price,
      BuildContext context,
      String ordertype,
      String appno) async {
    try {
      _cpactionloader = true;
      Navigator.pop(context); // Pop after snackbar

      notifyListeners();

      // Pop only after API result to avoid context issues
      final res = await api.putorderapicopaction(
          tabval, sym, exchange, issueType, qty, price, ordertype, appno);

      // The dialog has already been popped above, so `context.mounted` is
      // false here. The shared snackbar helpers fall back to the global
      // navigator context — they don't need a live dialog context to render.
      if (res.msg == 'success') {
        await ordercheckfunction();
        _cpactionloader = false;
        successMessage(
          context,
          ordertype == 'ER' ? 'Order placed' : 'Order cancelled',
        );
      } else if (res.msg == 'error occured on data fetch') {
        await ordercheckfunction();
        _cpactionloader = false;
        warningMessage(context, "${res.msg}");
      } else {
        // Any other response — surface whatever the backend sent (msg, emsg,
        // or a generic message) instead of silently swallowing it.
        _cpactionloader = false;
        final fallback = (res.emsg?.isNotEmpty == true)
            ? res.emsg!
            : (res.msg?.isNotEmpty == true
                ? res.msg!
                : 'Something went wrong, please try again');
        warningMessage(context, fallback);
      }
    } catch (e) {
      if (context.mounted) {
          warningMessage(context, '$e'
        );
      }
      Navigator.pop(context); // Pop after snackbar
    } finally {
      _cpactionloader = false;
      notifyListeners();
    }
  }

  Future fetchsharingdata(
      String from, String to, String seg, BuildContext context) async {
    try {
      _sharingdatacalendar = await api.getsharingdata(from, to, seg);
      if (_sharingdatacalendar?.data != null) {
        if (_sharingdatacalendar!.data![0].sharing == 'True') {
          _ucode = "${_sharingdatacalendar!.data![0].uqCode}";
          notsharing = false;
        } else {
          notsharing = true;
          _ucode = '';
        }
      } else {
        notsharing = true;
        _ucode = '';
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   warningMessage(context, 'Error occurred try again later'),
      // );

    } finally {
      notifyListeners();
    }
  }

  Future sendsharing(String ucode, from, to, res, bool status, seg,
      BuildContext context) async {
    try {
      _calendarpnlloading = true;
      notifyListeners();

      _sharingturonandoff =
          await api.senddharingdataapi(ucode, from, to, res, status, seg);

      if (_sharingturonandoff != null &&
          _sharingturonandoff!.data != null &&
          _sharingturonandoff!.data!.uqCode != null) {
        notsharing = false;
        _calendarpnlloading = false;

        _ucode = "${_sharingturonandoff!.data!.uqCode}";
          successMessage(context, "Sharing Turned on"
        );
      } else {
        if (_sharingturonandoff!.msg != null) {
          if (_sharingturonandoff!.msg == 'Sharing Turned Off') {
            notsharing = true;
            _calendarpnlloading = false;
              successMessage(context, "Sharing Turned off"
            );
          } else {
            notsharing = false;
            _calendarpnlloading = false;
              successMessage(context, "Sharing Turned on"
            );
          }
        }
      }
    } catch (e) {
      _calendarpnlloading = false;

      if (notsharing == false) {
        notsharing == true;
      } else {
        notsharing == false;
      }
      notifyListeners();

        warningMessage(context, 'Sharing error'
      );
    } finally {
      _calendarpnlloading = false;
      notifyListeners();
    }
  }

  requestWS({required bool isSubscribe, required BuildContext context}) async {
    String input = "";
    if (_holdingsAllData != null) {
      if (_holdingsAllData!.holdings != null) {
        for (var element in _holdingsAllData!.holdings!) {
          if (element["Token"] != '') {
            input += "${element["Exchange"]}|${element["Token"]}#";
          }
        }
      }
    }

    if (input.isNotEmpty) {
      // lastScbTok(input);
      await ref.read(websocketProvider).establishConnection(
          channelInput: input, task: isSubscribe ? "t" : "u", context: context);
    }
  }

  Future fetchpnldata(
      BuildContext context, String from, String to, bool yrn) async {
    try {
      _pnlloading = true;
      _reportsloadingforcharges = true;
      notifyListeners();
      _pnlAllData = await api.getpnldata(from, to, yrn);
      _pnlAllDatadummy = PnlModel.fromJson(_pnlAllData!.toJson());
      _valforcheck = yrn;
      _pnlloading = false;
      _reportsloadingforcharges = false;
      // _selectedFilters = {}; // Reset filters
      notifyListeners();
    } catch (e) {
      _pnlloading = false;
      // ScaffoldMessenger.of(context).showSnackBar(
      //   warningMessage(context, 'Error occurred try again later'),
      // );
    }
  }

  setthenotice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("notice", "yes");
    _noticenewfeature = prefs.getString('notice').toString();
    notifyListeners();
  }

  // Add flag to track if calendar pnl data is loaded
  // bool isCalendarPnlDataLoaded = false;
  // void resetCalendarPnlDataLoaded() { isCalendarPnlDataLoaded = false; }

  // Future fetchcalenderpnldata(
  //     BuildContext context, String from, String to, String type,
  //     {bool force = false}) async {

  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     _noticenewfeature = prefs.getString("notice").toString();

  //     print(_noticenewfeature);

  //     _calendarpnlloading = true;
  //     notifyListeners();
  //     _calenderpnlAllData = await api.getcalenderpnldata(from, to, type);
  //     grouped = {};
  //     _originalGrouped = {};
  //     if (_calenderpnlAllData != null) {
  //       _heatmapData = {};
  //       if (_calenderpnlAllData!.journal != null) {
  //         _selectedFilters = {};
  //         for (var element in _calenderpnlAllData!.journal!) {
  //           print("realised : 33m");
  //           if (element.realisedpnl != '0.0') {
  //             String dateString = element.tRADEDATE!;
  //             try {
  //               DateFormat inputFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
  //               DateTime parsedDate = inputFormat.parse(dateString);
  //               print("${element.realisedpnl}");
  //               _heatmapData[DateTime(
  //                       parsedDate.year, parsedDate.month, parsedDate.day)] =
  //                   double.parse(element.realisedpnl ?? "0.0");
  //             } catch (e) {
  //               print("Error parsing date: $dateString - $e");
  //             }
  //           }
  //         }
  //       }
  //       if (_calenderpnlAllData!.data != null) {
  //         for (var trade in _calenderpnlAllData!.data!) {
  //           DateFormat inputFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
  //           DateTime parsedDate = inputFormat.parse(trade.tRADEDATE!);
  //           final dateKey =
  //               DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
  //           if (!grouped.containsKey(dateKey)) {
  //             grouped[dateKey] = [];
  //           }
  //           grouped[dateKey]!.add(trade);
  //         }
  //       }
  //     }
  //     setFinancialYear(selectedFinancialYear);
  //     print("objectobject");
  //     _calendarpnlloading = false;
  //     // isCalendarPnlDataLoaded = true; // removed
  //     if (profitlossSearchCtrl.text.isNotEmpty) {
  //       profitlossSearchCtrl.clear();
  //     }
  //     notifyListeners();
  //   } catch (e) {
  //     _calendarpnlloading = false;
  //     debugPrint("$e");
  //   }
  // }

  Future fetchtradebookdata(
      BuildContext context, String from, String to) async {
    try {
      _tradebookloading = true;
      notifyListeners();
      _tradebookdata = await api.gettradebookdata(from, to);

      _tradebookdataDummy = TradeBookModel.fromJson(_tradebookdata!.toJson());
      // _selectedFilters = {}; // Reset filters
      _tradebookloading = false;
      // print("${_calenderpnlAllData} valval");
      notifyListeners();
    } catch (e) {
      _tradebookloading = false;
      // ScaffoldMessenger.of(context).showSnackBar(
      //   warningMessage(context, 'Error occurred try again later'),
      // );
    }
  }

  Future pdfdownloadfunction(
      BuildContext context, String recno, String filename) async {
    try {
      _pdfdownloadloading = true;
      notifyListeners();

      // Request storage permission
      // var status = await Permission.storage.request();
      // if (status.isDenied || status.isPermanentlyDenied) {
      //   _reportsloading = false;
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text("Storage permission is required!")),
      //   );

      //   return;

      // }

      // Download the file
      _pdfresponse = await api.getpdffileapi(recno, filename);
      if (_pdfresponse == 'File downloaded successfully') {
          successMessage(context, 'PDF Downloaded, Check Your Download'
        );

        // Open the Downloads folder
        // String downloadsDir = "/storage/emulated/0/Download";
        // await OpenFile.open(downloadsDir);

        _pdfdownloadloading = false;
      }

      _pdfdownloadloading = false;
      notifyListeners();
    } catch (e) {
      _pdfdownloadloading = false;
      // ScaffoldMessenger.of(context).showSnackBar(
      //   warningMessage(context, 'Error occurred try again later'),
      // );
    }
  }

  Future downloadDocForWeb(
      BuildContext context, String recno, String filename) async {
    try {
      _pdfdownloadloading = true;
      notifyListeners();
      final result = await api.downloadDocWeb(recno, filename);
      if (result == 'File downloaded successfully') {
        successMessage(context, 'PDF Downloaded');
      } else {
        warningMessage(context, result);
      }
      _pdfdownloadloading = false;
      notifyListeners();
    } catch (e) {
      _pdfdownloadloading = false;
      notifyListeners();
    }
  }

  String _selectedFormat = "PDF";
  String get selectedFormat => _selectedFormat;
  void selectedFormatFunction(String value) {
    _selectedFormat = value;
    notifyListeners();
  }

  Future downloadTaxPnlForWeb(BuildContext context, int year, String format) async {
    try {
      _taxpnlloading = true;
      notifyListeners();
      final result = await api.downloadTaxPnlWeb(year, format);
      _taxpnlloading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _taxpnlloading = false;
      notifyListeners();
    }
  }

  Future pdfdownloadfortaxpnl(
      BuildContext context, eq, dercomcur, eqcharge, year) async {
    if (year <= _yearforTaxpnlDummy) {
      try {
        _taxpnlloading = true;
        notifyListeners();

        // _pdfresponse =
             api.getpdffileapitaxpnl(eq, dercomcur, eqcharge, year, selectedFormat);
        // if (_pdfresponse == 'File Sent to mail successfully') {
          // if (_istaxpnlclosed == false) {
          //   Navigator.pop(context);
          // }

          // Future.delayed(Duration(seconds: 1), () {
          //   ScaffoldMessenger.of(context).showSnackBar(
          //     successMessage(context, 'File sent to mail successfully'),
          //   );
          // });
          // _taxpnlloading = false;
        // } else {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   warningMessage(context, '$_pdfresponse'),
          // );
          // Navigator.pop(context);
        //   _taxpnlloading = false;
        //   throw _pdfresponse;
        // }

        _taxpnlloading = false;
        notifyListeners();
      } catch (e) {
        _taxpnlloading = false;
        //  ScaffoldMessenger.of(context).showSnackBar(
        //   warningMessage(context, 'Error occurred try again later'),
        // );
        // debugPrint("$e");
        throw e.toString();
      }
    } else {
      throw 'Cannot move beyond year $_yearforTaxpnlDummy';
    }
  }

  Future pdfdownloadforledger(
      BuildContext context, res, dr, cr, op, clb, stdate, edate) async {
    try {
      _ledgerloading = true;
      notifyListeners();
      _pdfresponse =
          await api.getpdffileapiledger(res, dr, cr, op, clb, stdate, edate);
      if (_pdfresponse == 'File downloaded successfully') {
          successMessage(context, 'PDF Downloaded, Check Your Download'
        );
        _ledgerloading = false;
      } else {
          warningMessage(context, '$_pdfresponse'
        );
        _ledgerloading = false;
      }

      _ledgerloading = false;
      notifyListeners();
    } catch (e) {
      _ledgerloading = false;
        warningMessage(context, 'Error occurred try again later'
      );
    }
  }

  Future pdfdownloadforpnl(BuildContext context, res, stdate, edate, string,
      notional, chargevalue) async {
    try {
      _pnlloading = true;
      notifyListeners();
      _pdfresponse = await api.getpdffileapipnl(
          res, stdate, edate, string, notional, chargevalue);
      if (_pdfresponse == 'File downloaded successfully') {
          successMessage(context, 'PDF Downloaded, Check Your Download'
        );
        _pnlloading = false;
      } else {
          warningMessage(context, '$_pdfresponse'
        );
        _pnlloading = false;
      }

      _pnlloading = false;
      notifyListeners();
    } catch (e) {
      _pnlloading = false;
      // ScaffoldMessenger.of(context).showSnackBar(
      //   warningMessage(context, 'Error occurred try again later'),
      // );
    }
  }

  Future fetchpdfdownload(BuildContext context, String from, String to) async {
    try {
      _reportsloading = true;
      notifyListeners();
      _pdfdownload = await api.getpdfdownload(from, to);
      _pdfdaataDummy = _pdfdownload;
      // _selectedFilters = {}; // Reset filters

      // Filter to show only Contract and CN documents
      if (_pdfdownload?.data != null) {
        _pdfdownload!.data = _pdfdownload!.data!
            .where((doc) => doc.docType == 'Contract' || doc.docType == 'CN')
            .toList();
      }

      _reportsloading = false;
      notifyListeners();
    } catch (e) {
      _reportsloading = false;
      // if (context.mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     warningMessage(context, 'Error occurred try again later'),
      //   );
      // }
    }
  }

  Future fetchAllPdfDownloads(BuildContext context, String from, String to) async {
    try {
      _allPdfLoading = true;
      notifyListeners();
      _allPdfDownloads = await api.getpdfdownload(from, to);
      _allPdfDownloadsDummy = PdfDownloadModel(
        data: List.from(_allPdfDownloads?.data ?? []),
      );
      _allPdfLoading = false;
      notifyListeners();
    } catch (e) {
      _allPdfLoading = false;
      notifyListeners();
    }
  }

  void filterAllPdfDownloads(String? docType) {
    if (_allPdfDownloadsDummy == null) return;
    if (docType == null || docType == 'All') {
      _allPdfDownloads = PdfDownloadModel(
        data: List.from(_allPdfDownloadsDummy!.data ?? []),
      );
    } else {
      _allPdfDownloads = PdfDownloadModel(
        data: (_allPdfDownloadsDummy!.data ?? [])
            .where((doc) => doc.docType == docType)
            .toList(),
      );
    }
    notifyListeners();
  }

  refreshforfilterdata() {
    if (_pledgeandunpledge!.data != null &&
        _pledgeandunpledge!.data!.isNotEmpty) {
      for (var i = 0; i < _pledgeandunpledge!.data!.length; i++) {
        final value = _pledgeandunpledge!.data![i];
        if (value.initiated == "0" &&
            value.status == 'Ok' &&
            (double.parse(value.nSOHQTY.toString()).toInt()) +
                    (double.parse(value.sOHQTY.toString()).toInt()) !=
                0) {
        }
      }
    }
  }

  Future fetchpledgeandunpledge(BuildContext context) async {
    try {
      _pledgeloader = true;
      notifyListeners();
      _pledgeandunpledge = await api.getpledgeandunpledge();
      _pledgesegmentcheck = await api.getsegforpledge();
      _listforpledge = [];
      if (_pledgesegmentcheck?.str != null) {}
      _segresponse =
          jsonDecode(decryptionFunction(_pledgesegmentcheck!.str.toString()));
      // final dummy = [];
      // for (var i = 0; i < _pdfdownload!.data!.length; i++) {
      //   dummy.add(_pdfdownload!.data![i].docType);
      // }
      // _tradebookfilterarray = dummy.toSet().toList();
      // print(_tradebookfilterarray);
      refreshforfilterdata();
      // _selectedFilters = {}; // Reset filters
      _pledgeloader = false;
      notifyListeners();
    } catch (e) {
      _pledgeloader = false;
      // ScaffoldMessenger.of(context).showSnackBar(
      //   warningMessage(context, 'Error occurred try again later'),
      // );
    }
  }

  fetchapprovepledge() async {
    try {
      _approvepledgeloader = true;
      notifyListeners();
      _approvepledge = await api.getapprovepledge();

    } catch (e) {
      rethrow;
    }finally{
      _approvepledgeloader = false;
      notifyListeners();
    }
  }

  Future fetchcaeventsdata(
      BuildContext context, String start, String end) async {
    try {
      _caeventloading = true;
      notifyListeners();
      _caeventalldata = await api.getcaevents(start, end);

      // final dummy = [];
      // for (var i = 0; i < _pdfdownload!.data!.length; i++) {
      //   dummy.add(_pdfdownload!.data![i].docType);
      // }
      // _tradebookfilterarray = dummy.toSet().toList();
      // print(_tradebookfilterarray);

      _caeventloading = false;
      notifyListeners();
    } catch (e) {
      _caeventloading = false;

      // ScaffoldMessenger.of(context).showSnackBar(
      //   warningMessage(context, 'Error occurred try again later'),
      // );
    }
  }

  Future fetchtaxpnleqdata(BuildContext context, int from) async {
    if (from <= _yearforTaxpnlDummy) {
      _yearforTaxpnl = from;

      try {
        _reportsloading = true;
        _taxderloading = true;
        notifyListeners();

        _taxpnleq = await api.gettaxpnleq(from);
        _taxpnldercomcur = await api.gettaxpnldercomcur(from);

        // _selectedFilters = {}; // Reset filters

        final taxEqData = _taxpnleq?.data;
        if (taxEqData != null) {
          if (taxEqData.aSSETS != null) {
            _eqtypestring = 'Asserts';
            taxpnleqselectedtab('Asserts');
          } else if (taxEqData.lIABILITIES != null) {
            _eqtypestring = 'Liabilities';
            taxpnleqselectedtab('Liabilities');
          } else if (taxEqData.sHORTTERM != null) {
            _eqtypestring = 'Short Term';
            taxpnleqselectedtab('Short Term');
          } else if (taxEqData.tRADING != null) {
            _eqtypestring = 'Long Term';
            taxpnleqselectedtab('Long Term');
          }
        }

        final derData = _taxpnldercomcur?.data?.derivatives;
        if (derData != null) {
          if (derData.derFutBooked != null) {
            _dertypestring = 'Future Closed';
            taxpnlderselectedtab();
          } else if (derData.derFutOpen != null) {
            _dertypestring = 'Future Open';
            taxpnlderselectedtab();
          } else if (derData.derOptBooked != null) {
            _dertypestring = 'Option Closed';
            taxpnlderselectedtab();
          } else if (derData.derOptOpen != null) {
            _dertypestring = 'Option Open';
          }
        }

        final comData = _taxpnldercomcur?.data?.commodity;
        if (comData != null) {
          if (comData.comFutBooked != null) {
            _comtypestring = 'Future Closed';
            taxpnlcomselectedtab();
          } else if (comData.comFutOpen != null) {
            _comtypestring = 'Future Open';
            taxpnlcomselectedtab();
          } else if (comData.comOptBooked != null) {
            _comtypestring = 'Option Closed';
            taxpnlcomselectedtab();
          } else if (comData.comOptOpen != null) {
            _comtypestring = 'Option Open';
            taxpnlcomselectedtab();
          }
        }

        final curData = _taxpnldercomcur?.data?.currency;
        if (curData != null) {
          if (curData.currFutBooked != null) {
            _curtypestring = 'Future Closed';
            taxpnlcurselectedtab();
          } else if (curData.currFutOpen != null) {
            _curtypestring = 'Future Open';
            taxpnlcurselectedtab();
          } else if (curData.currOptBooked != null) {
            _curtypestring = 'Option Closed';
            taxpnlcurselectedtab();
          } else if (curData.currOptOpen != null) {
            _curtypestring = 'Option Open';
            taxpnlcurselectedtab();
          }
        }

        final charges = _taxpnldercomcur?.data?.charges;
        _reportsloading = false;
        _taxderloading = false;
        notifyListeners();


        // notifyListeners();
      } catch (e) {
        _taxderloading = false;

        // ScaffoldMessenger.of(context).showSnackBar(
        //   warningMessage(context, 'Error occurred try again later'),
        // );
      }
    } else {
        warningMessage(context, 'Cant move already in $_yearforTaxpnlDummy'
      );
    }
  }

  Future fetchBillDetails(BuildContext context, String sett, String mrktyp,
      String comc, String tdate) async {
    try {
      // _ledgerloading = true;
      notifyListeners();

      _ledgerBillData = await api.getLedgerBilldata(sett, mrktyp, comc, tdate);

      // if (_ledgerAllData!.stat == "Ok") {
      //   // for (var element in _ledgerAllData!.topSchemes!) {

      //   // }
      // }
      // formatedList(_ledgerBillData!.fullStat!);
    } catch (e) {
      _ledgerloading = false;

        warningMessage(context, 'Error occurred try again later'
      );
    } finally {
      // _ledgerloading = false;
      notifyListeners();
    }
  }

  Future fetchpnlSummary(BuildContext context, String script, String comcode,
      String from, String to) async {
    try {
      _pnlloading = true;
      notifyListeners();
      _pnlSummaryData = await api.getPnlSummary(script, comcode, from, to);
      // if (_ledgerAllData!.stat == "Ok") {
      //   // for (var element in _ledgerAllData!.topSchemes!) {
      //   // }
      // }
      // formatedList(_ledgerBillData!.fullStat!);
      _pnlloading = false;
      notifyListeners();
    } catch (e) {
      _pnlloading = false;

      // ScaffoldMessenger.of(context).showSnackBar(
      //   warningMessage(context, 'Error occurred try again later'),
      // );
    }
  }

  Future sendunpledgerequest(BuildContext context, String uccid, String boid,
      String cname, List list) async {
    try {
      _pledgeloader = true;
      notifyListeners();
      final responce = await api.sendunpledgeapi(uccid, boid, cname, list);
      if (responce['msg'] == 'data updated successfully') {
        _pledgeandunpledge = await api.getpledgeandunpledge();
        _pledgeoruppledgedelete = '';
        _pledgeorunpledge = '';
        _listforpledge = [];
          successMessage(context, 'Scripts Unpledged'
        );
        // _reportsloading = false;
      }
      // if (_ledgerAllData!.stat == "Ok") {
      //   // for (var element in _ledgerAllData!.topSchemes!) {
      //   // }
      // }
      // formatedList(_ledgerBillData!.fullStat!);
      _pledgeloader = false;
      notifyListeners();
    } catch (e) {
      _pledgeloader = false;

        warningMessage(context, 'Error occurred try again later'
      );
    }
  }

  Future unpldgedeletefun(BuildContext context, String uccid, List list) async {
    try {
      _pledgeloader = true;
      notifyListeners();
      final responce = await api.sendunpledgedeleteapi(uccid, list);
      if (responce['msg'] == 'request deleted') {
        _pledgeandunpledge = await api.getpledgeandunpledge();
        _pledgeorunpledge = '';
        _listforpledge = [];
          successMessage(context, 'Request Deleted '
        );
        // _reportsloading = false;
      }
      // if (_ledgerAllData!.stat == "Ok") {
      //   // for (var element in _ledgerAllData!.topSchemes!) {
      //   // }
      // }
      // formatedList(_ledgerBillData!.fullStat!);
      _pledgeloader = false;
      notifyListeners();
    } catch (e) {
      _pledgeloader = false;

        warningMessage(context, 'Error occurred try again later'
      );
    }
  }

  Future chargesforpnlseg(BuildContext context, String seg) async {
    try {
      _reportsloadingforcharges = true;
      notifyListeners();
      _pnlsegCharge =
          await api.getpnlsegcharge(seg, _startDate, _today, _valforcheck);
      _pnlAllData!.expenseAmt = _pnlsegCharge!.expenseAmt;
      // if (_ledgerAllData!.stat == "Ok") {
      //   // for (var element in _ledgerAllData!.topSchemes!) {

      //   // }
      // }
      // formatedList(_ledgerBillData!.fullStat!);
      _reportsloadingforcharges = false;
      notifyListeners();
    } catch (e) {
      _reportsloadingforcharges = false;

        warningMessage(context, 'Error in getting charges'
      );
    }
  }

  /// Fetches charges for one segment using the calendar date range.
  Future chargesforCalendarPnlSeg(BuildContext context, String seg) async {
    if (_calendarChargesBySegment.containsKey(seg)) return;
    try {
      _calendarChargesLoading = true;
      notifyListeners();
      final charge = await api.getpnlsegcharge(
          seg, formattedStartDate, formattedendDate, false);
      _calendarChargesBySegment[seg] = charge;
      _calendarChargesLoading = false;
      notifyListeners();
    } catch (e) {
      _calendarChargesLoading = false;
      warningMessage(context, 'Error fetching charges');
    }
  }

  /// Fetches charges for all four segments in the background on screen entry.
  Future fetchChargesForAllCalendarSegments(BuildContext context) async {
    for (final seg in ['eq', 'fno', 'comm', 'curr']) {
      await chargesforCalendarPnlSeg(context, seg);
    }
  }

  Future chargesforeqtaxpnl(BuildContext context, int from) async {
    if (from <= _yearforTaxpnlDummy) {
      try {
        _reportsloadingforcharges = true;
        notifyListeners();
        _taxpnleqCharge = await api.GettaxpnleqCharge('eq', from);

        // _pnlAllData!.expenseAmt = _pnlsegCharge!.expenseAmt;

        // if (_ledgerAllData!.stat == "Ok") {
        //   // for (var element in _ledgerAllData!.topSchemes!) {

        //   // }
        // }
        // formatedList(_ledgerBillData!.fullStat!);
        _reportsloadingforcharges = false;
        notifyListeners();
      } catch (e) {
        _reportsloadingforcharges = false;
          warningMessage(context, 'Error occurred try again later'
        );
      }
    } else {
      warningMessage(
          context, 'Cant move already in ${_yearforTaxpnlDummy}');
    }
  }

  ledgerfiltercall(BuildContext context, val) {
    if (_currentfilterpage == 'ledger') {
      List<FullStat> originalList = [];
      originalList = List.from(_ledgerAllDataDummy!.fullStat ?? []);
      if (_ledgerAllDataDummy != null) {
        if (val == SingingCharacter.receipt) {
          _ledgerAllData!.fullStat =
              originalList.where((o) => o.tYPE == 'Reciept').toList();
          double totalCrAmt = 0.0;

          for (var i = 0; i < _ledgerAllData!.fullStat!.length; i++) {
            totalCrAmt += double.tryParse(
                    _ledgerAllData!.fullStat![i].cRAMT?.toString() ?? '0') ??
                0.0;
          }

          _ledgerAllData!.crAmt = totalCrAmt.toStringAsFixed(2);
          _ledgerAllData!.drAmt = '0.0';
          _ledgerAllData!.openingBalance = '0.0';
        } else if (val == SingingCharacter.journal) {
          _ledgerAllData!.fullStat =
              originalList.where((o) => o.tYPE == 'Journal').toList();
          double totalCrAmt = 0.0;
          double totalDrAmt = 0.0;

          for (var i = 0; i < _ledgerAllData!.fullStat!.length; i++) {
            totalCrAmt += double.tryParse(
                    _ledgerAllData!.fullStat![i].cRAMT?.toString() ?? '0') ??
                0.0;
            totalDrAmt += double.tryParse(
                    _ledgerAllData!.fullStat![i].dRAMT?.toString() ?? '0') ??
                0.0;
          }
          _ledgerAllData!.openingBalance = '0.0';

          _ledgerAllData!.crAmt = totalCrAmt.toStringAsFixed(2);
          _ledgerAllData!.drAmt = totalDrAmt.toStringAsFixed(2);
        } else if (val == SingingCharacter.payment) {
          _ledgerAllData!.fullStat =
              originalList.where((o) => o.tYPE == 'Payment').toList();
          double totalCrAmt = 0.0;
          double totalDrAmt = 0.0;

          for (var i = 0; i < _ledgerAllData!.fullStat!.length; i++) {
            totalDrAmt += double.tryParse(
                    _ledgerAllData!.fullStat![i].dRAMT?.toString() ?? '0') ??
                0.0;
          }
          _ledgerAllData!.openingBalance = '0.0';

          _ledgerAllData!.crAmt = '0.0';
          _ledgerAllData!.drAmt = totalDrAmt.toStringAsFixed(2);
        } else if (val == SingingCharacter.systemjournal) {
          _ledgerAllData!.fullStat =
              originalList.where((o) => o.tYPE == 'Bill').toList();
          double totalCrAmt = 0.0;
          double totalDrAmt = 0.0;

          for (var i = 0; i < _ledgerAllData!.fullStat!.length; i++) {
            totalCrAmt += double.tryParse(
                    _ledgerAllData!.fullStat![i].cRAMT?.toString() ?? '0') ??
                0.0;
            totalDrAmt += double.tryParse(
                    _ledgerAllData!.fullStat![i].dRAMT?.toString() ?? '0') ??
                0.0;
          }
          _ledgerAllData!.openingBalance = '0.0';

          _ledgerAllData!.crAmt = totalCrAmt.toStringAsFixed(2);
          _ledgerAllData!.drAmt = totalDrAmt.toStringAsFixed(2);
        } else {
          // No filter selected, show all data
          _ledgerAllData!.fullStat = List.from(originalList);
          double totalCrAmt = 0.0;
          double totalDrAmt = 0.0;

          for (var i = 0; i < _ledgerAllData!.fullStat!.length; i++) {
            totalCrAmt += double.tryParse(
                    _ledgerAllData!.fullStat![i].cRAMT?.toString() ?? '0') ??
                0.0;
            totalDrAmt += double.tryParse(
                    _ledgerAllData!.fullStat![i].dRAMT?.toString() ?? '0') ??
                0.0;
          }
          _ledgerAllData!.openingBalance = _ledgerAllDataDummy!.openingBalance;

          _ledgerAllData!.crAmt = totalCrAmt.toStringAsFixed(2);
          _ledgerAllData!.drAmt = totalDrAmt.toStringAsFixed(2);
        }
        _ledgerAllData!.fullStat?.sort((a, b) {
          return int.parse(a.sortNo!).compareTo(int.parse(b.sortNo!));
        });
        for (var i = 0; i < _ledgerAllData!.fullStat!.length; i++) {
          if (i == 0) {
            _ledgerAllData!.fullStat![i].nETAMT =
                (double.parse(_ledgerAllData!.fullStat![i].cRAMT!) -
                        double.parse(_ledgerAllData!.fullStat![i].dRAMT!))
                    .toStringAsFixed(2);
          } else {
            _ledgerAllData!.fullStat![i].nETAMT =
                (double.parse(_ledgerAllData!.fullStat![i - 1].nETAMT!) +
                        (double.parse(_ledgerAllData!.fullStat![i].cRAMT!) -
                            double.parse(_ledgerAllData!.fullStat![i].dRAMT!)))
                    .toStringAsFixed(2);
          }
        }
        _ledgerAllData!.fullStat?.sort((a, b) {
          return int.parse(b.sortNo!).compareTo(int.parse(a.sortNo!));
        });
        if (_ledgerAllData!.fullStat != null &&
            _ledgerAllData!.fullStat!.isNotEmpty) {
          if (_ledgerAllData!.fullStat![0].nETAMT != null) {
            _ledgerAllData!.closingBalance =
                _ledgerAllData!.fullStat![0].nETAMT!;
          }
        } else {
          _ledgerAllData!.closingBalance = '0.00';
        }
      }
    } else if (_currentfilterpage == 'pnl') {
      if (_pnlAllData?.transactions != null) {
        if (val == SingingCharacter.eq) {
          _pnlAllData!.transactions = _pnlAllDatadummy!.transactions!
              .where((o) =>
                  o.companyCode == 'BSE_CASH' ||
                  o.companyCode == 'NSE_CASH' ||
                  o.companyCode == 'MF_BSE' ||
                  o.companyCode == 'MF_NSE' ||
                  o.companyCode == 'NSE_SLBM' ||
                  o.companyCode == 'NSE_SPT')
              .toList();
          chargesforpnlseg(context, 'eq');
        }
        if (val == SingingCharacter.fno) {
          _pnlAllData!.transactions = _pnlAllDatadummy!.transactions!
              .where((o) =>
                  o.companyCode == 'NSE_FNO' || o.companyCode == 'BSE_FNO')
              .toList();
          chargesforpnlseg(context, 'fno');
        }
        if (val == SingingCharacter.com) {
          _pnlAllData!.transactions = _pnlAllDatadummy!.transactions!
              .where((o) =>
                  o.companyCode == 'MCX' ||
                  o.companyCode == 'NCDEX' ||
                  o.companyCode == 'NSE_COM' ||
                  o.companyCode == 'BSE_COM')
              .toList();
          chargesforpnlseg(context, 'comm');
        }
        if (val == SingingCharacter.cur) {
          _pnlAllData!.transactions = _pnlAllDatadummy!.transactions!
              .where((o) =>
                  o.companyCode == 'CD_NSE' ||
                  o.companyCode == 'CD_MCX' ||
                  o.companyCode == 'CD_USE' ||
                  o.companyCode == 'CD_BSE')
              .toList();
          chargesforpnlseg(context, 'curr');
        } else {
          // No filter selected, show all data
          _pnlAllData!.transactions =
              List.from(_pnlAllDatadummy!.transactions ?? []);
          _pnlAllData!.expenseAmt = _pnlAllDatadummy!.expenseAmt;
        }
      }
    } else if (_currentfilterpage == 'tradebook') {
      if (_tradebookdata!.trades != null) {
        if (val == SingingCharacter.eq) {
          _tradebookdata!.trades = _tradebookdataDummy!.trades!
              .where((o) => o.cOMPANYCODE == 'NSE_CASH')
              .toList();
        }
        if (val == SingingCharacter.fno) {
          _tradebookdata!.trades = (_tradebookdataDummy!.trades ?? [])
              .where((o) => o.cOMPANYCODE == 'NSE_FNO')
              .toList();
        }
        if (val == SingingCharacter.com) {
          _tradebookdata!.trades = (_tradebookdataDummy!.trades ?? [])
              .where((o) => o.cOMPANYCODE == 'MCX')
              .toList();
        }
        if (val == SingingCharacter.cur) {
          _tradebookdata!.trades = (_tradebookdataDummy!.trades ?? [])
              .where((o) => o.cOMPANYCODE == 'CD_NSE')
              .toList();
        }
        if (val == SingingCharacter.buy) {
          _tradebookdata!.trades = (_tradebookdataDummy!.trades ?? [])
              .where((o) => o.showtype == 'BUY')
              .toList();
        }
        if (val == SingingCharacter.sell) {
          _tradebookdata!.trades = (_tradebookdataDummy!.trades ?? [])
              .where((o) => o.showtype == 'SELL')
              .toList();
        } else {
          // No filter selected, show all data
          _tradebookdata!.trades = List.from(_tradebookdataDummy!.trades ?? []);
        }
      }
    } else if (_currentfilterpage == 'pdfdownload') {
      if (val == SingingCharacter.marginstatement) {
        _pdfdownload!.data = (_pdfdaataDummy!.data ?? [])
            .where((o) => o.docType == 'Margin Statement')
            .toList();
      } else if (val == SingingCharacter.contract) {
        _pdfdownload!.data = (_pdfdaataDummy!.data ?? [])
            .where((o) => o.docType == 'Contract')
            .toList();
      } else if (val == SingingCharacter.weekstate) {
        _pdfdownload!.data = (_pdfdaataDummy!.data ?? [])
            .where((o) => o.docType == 'Weekly Statement')
            .toList();
      } else if (val == SingingCharacter.rr) {
        _pdfdownload!.data = (_pdfdaataDummy!.data ?? [])
            .where((o) => o.docType == 'Retention Report')
            .toList();
      } else if (val == SingingCharacter.agts) {
        _pdfdownload!.data = (_pdfdaataDummy!.data ?? [])
            .where((o) => o.docType == 'AGTS Report')
            .toList();
      } else if (val == SingingCharacter.ledgerdetails) {
        _pdfdownload!.data = (_pdfdaataDummy!.data ?? [])
            .where((o) => o.docType == 'Ledger Detail')
            .toList();
      } else if (val == SingingCharacter.cn) {
        _pdfdownload!.data = (_pdfdaataDummy!.data ?? [])
            .where((o) => o.docType == 'CN')
            .toList();
      } else {
        // No filter selected, show all data
        _pdfdownload!.data = List.from(_pdfdaataDummy!.data ?? []);
      }
    }

    notifyListeners(); // Notify UI of changes
  }

  taxpnleqselectedtab(String value) {
    taxpnleqselectedtabdata = _eqtypestring == 'Asserts'
        ? taxpnleq!.data!.aSSETS!
        : _eqtypestring == 'Liabilities'
            ? taxpnleq!.data!.lIABILITIES!
            : _eqtypestring == 'Short Term'
                ? taxpnleq!.data!.sHORTTERM!
                : _eqtypestring == 'Long Term'
                    ? taxpnleq!.data!.tRADING!
                    : [];
  }

  taxpnlderselectedtab() {
    taxpnlderselectedtabdata = _dertypestring == 'Future Closed'
        ? taxpnldercomcur!.data!.derivatives!.derFutBooked != null
            ? taxpnldercomcur!.data!.derivatives!.derFutBooked!
            : []
        : _dertypestring == 'Future Open'
            ? taxpnldercomcur!.data!.derivatives!.derFutOpen!
            : _dertypestring == 'Option Closed'
                ? taxpnldercomcur!.data!.derivatives!.derOptBooked!
                : _dertypestring == 'Option Open'
                    ? taxpnldercomcur!.data!.derivatives!.derOptOpen!
                    : [];

    // taxpnlderselectedtabdata = _dertypestring == 'Future Closed'
    //     ? taxpnldercomcur!.data!.commodity!.comFutBooked!
    //     : _dertypestring == 'Future Open'
    //         ? taxpnldercomcur!.data!.commodity!.comFutOpen!
    //         : _dertypestring == 'Option Closed'
    //             ? taxpnldercomcur!.data!.commodity!.comOptBooked!
    //             : _dertypestring == 'Option Open'
    //                 ? taxpnldercomcur!.data!.commodity!.comOptOpen!
    //                 : [];

    // else if (value == '3') {
    //   taxpnlderselectedtabdata = _dertypestring == 'Future Closed'
    //       ? taxpnldercomcur!.data!.derivatives!.derFutBooked!
    //       : _dertypestring == 'Future Open'
    //           ? taxpnldercomcur!.data!.derivatives!.derFutOpen!
    //           : _dertypestring == 'Option Closed'
    //               ? taxpnldercomcur!.data!.derivatives!.derOptBooked!
    //               : _dertypestring == 'Option Open'
    //                   ? taxpnldercomcur!.data!.derivatives!.derOptOpen!
    //                   : [];
    // }
  }

  taxpnlcomselectedtab() {
    taxpnlcomselectedtabdata = _comtypestring == 'Future Closed'
        ? taxpnldercomcur!.data!.commodity!.comFutBooked!
        : _comtypestring == 'Future Open'
            ? taxpnldercomcur!.data!.commodity!.comFutOpen!
            : _comtypestring == 'Option Closed'
                ? taxpnldercomcur!.data!.commodity!.comOptBooked!
                : _comtypestring == 'Option Open'
                    ? taxpnldercomcur!.data!.commodity!.comOptOpen!
                    : [];

    // else if (value == '3') {
    //   taxpnlderselectedtabdata = _dertypestring == 'Future Closed'
    //       ? taxpnldercomcur!.data!.derivatives!.derFutBooked!
    //       : _dertypestring == 'Future Open'
    //           ? taxpnldercomcur!.data!.derivatives!.derFutOpen!
    //           : _dertypestring == 'Option Closed'
    //               ? taxpnldercomcur!.data!.derivatives!.derOptBooked!
    //               : _dertypestring == 'Option Open'
    //                   ? taxpnldercomcur!.data!.derivatives!.derOptOpen!
    //                   : [];
    // }
  }

  chngPnlmonthordaily(bool value) {
    isMonthly = value;
    notifyListeners();
  }

  sharingornotsharing(bool value) {
    notsharing = value;
    notifyListeners();
  }

  void billnotbill(bool value) {
    billmargin = value;

    if (_ledgerAllDataDummy?.fullStat == null) {
      // Defensive null check
      _ledgerAllData?.fullStat = [];
      notifyListeners();
      return;
    }

    List<FullStat> originalList = List.from(_ledgerAllDataDummy!.fullStat!);

    // Apply bill margin filter
    List<FullStat> filteredList = value
        ? originalList
            .where((o) => o.billMargin == 'Yes')
            .toList() // Show only entries with billMargin = Yes
        : originalList
            .where((o) => o.billMargin == 'No')
            .toList(); // Show only entries with billMargin = No

    // Then apply any active type filters
    if (_selectedFilters.isNotEmpty) {
      filteredList = filteredList.where((o) {
        return _selectedFilters.any((filter) {
          switch (filter) {
            case SingingCharacter.receipt:
              return o.tYPE == 'Reciept';
            case SingingCharacter.payment:
              return o.tYPE == 'Payment';
            case SingingCharacter.journal:
              return o.tYPE == 'Journal';
            case SingingCharacter.systemjournal:
              return o.tYPE == 'Bill';
            default:
              return false;
          }
        });
      }).toList();
    }

    _ledgerAllData!.fullStat = filteredList;

    // Recalculate totals
    double totalCrAmt = 0.0;
    double totalDrAmt = 0.0;

    for (var i = 0; i < _ledgerAllData!.fullStat!.length; i++) {
      totalCrAmt += double.tryParse(
              _ledgerAllData!.fullStat![i].cRAMT?.toString() ?? '0') ??
          0.0;
      totalDrAmt += double.tryParse(
              _ledgerAllData!.fullStat![i].dRAMT?.toString() ?? '0') ??
          0.0;
    }

    _ledgerAllData!.openingBalance = _ledgerAllDataDummy!.openingBalance;
    _ledgerAllData!.crAmt = totalCrAmt.toStringAsFixed(2);
    _ledgerAllData!.drAmt = totalDrAmt.toStringAsFixed(2);

    // Sort and calculate running balance
    _ledgerAllData!.fullStat?.sort((a, b) {
      return int.parse(a.sortNo!).compareTo(int.parse(b.sortNo!));
    });

    for (var i = 0; i < _ledgerAllData!.fullStat!.length; i++) {
      if (i == 0) {
        _ledgerAllData!.fullStat![i].nETAMT =
            (double.parse(_ledgerAllData!.fullStat![i].cRAMT!) -
                    double.parse(_ledgerAllData!.fullStat![i].dRAMT!))
                .toStringAsFixed(2);
      } else {
        _ledgerAllData!.fullStat![i].nETAMT =
            (double.parse(_ledgerAllData!.fullStat![i - 1].nETAMT!) +
                    (double.parse(_ledgerAllData!.fullStat![i].cRAMT!) -
                        double.parse(_ledgerAllData!.fullStat![i].dRAMT!)))
                .toStringAsFixed(2);
      }
    }

    _ledgerAllData!.fullStat?.sort((a, b) {
      return int.parse(b.sortNo!).compareTo(int.parse(a.sortNo!));
    });

    if (_ledgerAllData!.fullStat != null &&
        _ledgerAllData!.fullStat!.isNotEmpty) {
      _ledgerAllData!.closingBalance =
          _ledgerAllData!.fullStat![0].nETAMT ?? '0.00';
    } else {
      _ledgerAllData!.closingBalance = '0.00';
    }

    notifyListeners();
  }

  falseloader(String value) {
    if (value == 'ledger') {
      _ledgerloading = false;
    } else if (value == 'holdings') {
      _holdingsloading = false;
    } else if (value == 'pnl') {
      _pnlloading = false;
    } else if (value == 'calpnl') {
      _calendarpnlloading = false;
    } else if (value == 'tradebook') {
      _tradebookloading = false;
    } else if (value == 'taxpnl') {
      _taxderloading = false;
    } else if (value == 'download') {
      _pdfdownloadloading = false;
    }
    notifyListeners();
  }

  taxpnlcurselectedtab() {
    taxpnlcurselectedtabdata = _curtypestring == 'Future Closed'
        ? taxpnldercomcur!.data!.currency!.currFutBooked!
        : _curtypestring == 'Future Open'
            ? taxpnldercomcur!.data!.currency!.currFutOpen!
            : _curtypestring == 'Option Closed'
                ? taxpnldercomcur!.data!.currency!.currOptBooked!
                : _curtypestring == 'Option Open'
                    ? taxpnldercomcur!.data!.currency!.currOptOpen!
                    : [];

    // else if (value == '3') {
    //   taxpnlderselectedtabdata = _dertypestring == 'Future Closed'
    //       ? taxpnldercomcur!.data!.derivatives!.derFutBooked!
    //       : _dertypestring == 'Future Open'
    //           ? taxpnldercomcur!.data!.derivatives!.derFutOpen!
    //           : _dertypestring == 'Option Closed'
    //               ? taxpnldercomcur!.data!.derivatives!.derOptBooked!
    //               : _dertypestring == 'Option Open'
    //                   ? taxpnldercomcur!.data!.derivatives!.derOptOpen!
    //                   : [];
    // }
  }

  taxpnlExTabchange(val) {
    _activeTabTaxPnl = val;
    notifyListeners(); // Notify UI of changes
  }

  //

  // True if Monthly tab is active; false if Daily tab is active.
  bool isMonthly = false;

  bool notsharing = true;
  bool billmargin = true;

  // The selected financial year, e.g., "2024-2025"
  late String selectedFinancialYear;

  String selectedSegment = 'Equity';
  String changeornot = '';

  // A list of available financial years (only the most recent year).
  late List<String> availableFinancialYears;

  List<String> availableSegments = ['Equity', 'FNO', 'Commodity', 'Currency'];
  List<String> dailyormonthly = ['Monthly', 'Daily'];

  // Start and end dates for the selected financial year.
  late DateTime startTaxDate;
  late DateTime endTaxDate;

  late String formattedStartDate;
  late String formattedendDate;

  // The currently selected month for the Daily view.
  late DateTime selectedMonth;
  // late String selectnetpledge;
  TextEditingController selectnetpledge = TextEditingController();
  TextEditingController selectedqtyforcpaction =
      TextEditingController(text: '');
  TextEditingController selectedpriceforcpaction =
      TextEditingController(text: '');

  late bool pledgesubtn = true;
  late String pledgedropdown;

  String _pledgeerrormsg = "";
  String get pledgeerrormsg => _pledgeerrormsg;
  // Aggregated monthly P&L (key format: "YYYY-MM")
  Map<String, double> monthlyPnL = {};

  calendarProvider() {
    // Only generate the current financial year.
    availableFinancialYears = _generateFinancialYears(1);
    // Default to the first (current) financial year.
    selectedFinancialYear = availableFinancialYears.first;
    // Initialize startDate, endDate, selectedMonth, and monthlyPnL.
    setFinancialYear(selectedFinancialYear); // Only call ONCE here!
  }

  /// Sets the financial year and updates the startDate, endDate, selectedMonth,
  /// and monthlyPnL aggregation using the provided [heatmapData].
  void setFinancialYear(String fy) {
    // Only update if the value has changed.
    if (fy == "") {
      selectedFinancialYear = availableFinancialYears.first;
      fy = selectedFinancialYear;
    } else {
      selectedFinancialYear = fy;
    }

    // Parse "YYYY-YYYY" to extract the start year.
    final parts = fy.split('-');
    final startYear = int.parse(parts[0]);

    // Define the financial year range: April of startYear to March of startYear+1.
    startTaxDate = DateTime(startYear, 4, 1);
    formattedStartDate = DateFormat("dd/MM/yyyy").format(startTaxDate);
    endTaxDate = DateTime(startYear + 1, 3, 31);
    formattedendDate = DateFormat("dd/MM/yyyy").format(endTaxDate);

    // Determine current financial year based on today's date.
    final now = DateTime.now();
    final currentFYStartYear = now.month < 4 ? now.year - 1 : now.year;

    // If the selected FY is the current one, default to current month in Daily view;
    // otherwise, default to the FY start date.
    selectedMonth = (startYear == currentFYStartYear)
        ? DateTime(now.year, now.month, 1)
        : startTaxDate;

    if (_heatmapData != {}) {
      // Aggregate monthly P&L data for this financial year.
      monthlyPnL = _aggregateMonthlyPnL(_heatmapData, startTaxDate, endTaxDate);
    }
    // Schedule notifyListeners to run after the current frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Sets the active tab: true for Monthly, false for Daily.
  void setTab(bool monthly) {
    isMonthly = monthly;
    notifyListeners();
  }

  /// Sets the currently selected month (for Daily view).
  void setSelectedMonth(DateTime month) {
    selectedMonth = month;
    notifyListeners();
  }

  ///////////////////////////////////////////////////////////ofs/////////////////////////////////////////////////

  void setordervalueforofs(String qty, String price, String balance) {
    selectedqtyforcpaction.text = qty;

    final int qtyInt = int.parse(qty);
    final num priceNum =
        price.contains('.') ? double.parse(price) : int.parse(price);
    selectedpriceforcpaction.text = priceNum.toString();

    final num requiredAmount = qtyInt * priceNum;
    _requiredamountforofs = requiredAmount.toString();
    _cpactionerrormsg = '';
    // final balanceDouble =
    //     balance.contains('.') ? double.parse(balance) : int.parse(balance);
    //     _cpactionerrormsg = '';
    _pricevalidcp = true;
    _qtyvalidcp = true;
    checkbalace(_requiredamountforofs, balance);

    notifyListeners();
  }

  setCutoffcheckboxforofs(bool val, String cutOffPrice, String balance) {
    _cutoffcheckboxofs = val;
    if (val) {
      // Keep existing quantity, set price to cutoff price
      selectedpriceforcpaction.text = cutOffPrice;
      _pricevalidcp = true;
      checkbalace(_requiredamountforofs, balance);
      _cpactionerrormsg = '';
    } else {
      selectedpriceforcpaction.text = '';
      _pricevalidcp = false;
      _cpactionsubtn = false;
      _cpactionerrormsg = 'Price cannot be empty';
    }

    notifyListeners();
  }

  setofpricebox(String price, String balance, String base) {
    selectedpriceforcpaction.text = price;
    final baseprice = base.contains('.') ? double.parse(base) : int.parse(base);
    final priceText = selectedpriceforcpaction.text.trim();
    // final balanceDouble =
    //     balance.contains('.') ? double.parse(balance) : int.parse(balance);
    final parsedPrice = price != '' ? double.parse(priceText) : 0;

    _requiredamountforofs =
        (parsedPrice * int.parse(selectedqtyforcpaction.text)).toString();

    if (priceText.isEmpty) {
      _cpactionerrormsg = 'Price cannot be empty';
      _pricevalidcp = false;
      _cpactionsubtn = false;
    } else {
      final parsedPrice = int.tryParse(priceText);
      if (parsedPrice != null && parsedPrice > 0) {
        _cpactionerrormsg = '';
        if (baseprice > parsedPrice) {
          _captionforofs = 'Price cannot be less than base price ₹$base';
          _pricevalidcp = false;
          _cpactionsubtn = false;
        } else {
          _cpactionerrormsg = '';
          _qtyvalidcp = true;
          _pricevalidcp = true;
          _cpactionsubtn = true;
          checkbalace(_requiredamountforofs, balance);
        }
      } else {
        _cpactionerrormsg = 'Invalid price input';
        _pricevalidcp = false;
        _cpactionsubtn = false;
      }
    }

    notifyListeners();
  }

  setofqtybox(String qty, String balance) {
    selectedqtyforcpaction.text = qty;
    // Validate quantity input
    final int qtyInt = int.tryParse(qty) ?? 0;
    final num priceNum = selectedpriceforcpaction.text.contains('.')
        ? double.parse(selectedpriceforcpaction.text)
        : int.parse(selectedpriceforcpaction.text);
    // final balanceDouble =
    //     balance.contains('.') ? double.parse(balance) : int.parse(balance);

    _requiredamountforofs = (qtyInt * priceNum).toString();
    if (qty.isEmpty) {
      _cpactionerrormsgqty = 'Quantity cannot be empty';
      _cpactionsubtn = false;
      _qtyvalidcp = false;
    } else if (qty.contains('.')) {
      _cpactionerrormsgqty = 'Quantity cannot be decimal';
      _cpactionsubtn = false;

      _qtyvalidcp = false;
    } else {
      final qtyInt = int.parse(qty);
      if (qtyInt > 0) {
        _cpactionerrormsgqty = '';
        _cpactionsubtn = true;

        _qtyvalidcp = true;
      } else {
        _cpactionerrormsgqty = 'Invalid quantity input';
        _cpactionsubtn = false;

        _qtyvalidcp = false;
      }
    }

    checkbalace(_requiredamountforofs, balance);

    notifyListeners();
  }

  checkbalace(String req, String balance) {
    final balanceDouble =
        balance.contains('.') ? double.parse(balance) : int.parse(balance);
    final requiredAmount =
        req.contains('.') ? double.parse(req) : int.parse(req);

    if (requiredAmount > 200000) {
      _captionforofs = 'Bid amount ₹$requiredAmount exceeds limit of ₹200,000';
      _cpactionsubtn = false;
    } else if ((balanceDouble < requiredAmount)) {
      _captionforofs = 'Insufficient balance for bid';
      _cpactionsubtn = false;
    } else if (balanceDouble >= requiredAmount &&
        _qtyvalidcp == true &&
        _pricevalidcp == true) {
      _captionforofs = 'Required amount for bid';
      _cpactionsubtn = true;
    } else {
      _captionforofs = 'Enter bid quantity and price';
      _cpactionsubtn = false;
    }

    notifyListeners();
  }

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // Helper method to recalculate OFS amount
  void _recalculateOFSAmount(String balance) {
    final qtyText = selectedqtyforcpaction.text.trim();
    final priceText = selectedpriceforcpaction.text.trim();

    final qtyInt = int.tryParse(qtyText) ?? 0;
    final priceInt = int.tryParse(priceText) ?? 0;
    final balanceDouble = double.tryParse(balance) ?? 0.0;

    if (qtyInt > 0 && priceInt > 0) {
      final totalAmount = qtyInt * priceInt;
      _requiredamountforofs = totalAmount.toString();

      // Update caption based on validation rules
      if (totalAmount > 200000) {
        _captionforofs = 'Bid amount ₹$totalAmount exceeds limit of ₹200,000';
        _cpactionsubtn = false;
      } else if (totalAmount > balanceDouble) {
        _captionforofs = 'Insufficient balance for bid: ₹$totalAmount';
        _cpactionsubtn = false;
      } else {
        _captionforofs = 'Required amount for bid: ₹$totalAmount';
        _cpactionsubtn = _qtyvalidcp && _pricevalidcp;
      }
    } else {
      _requiredamountforofs = '0';
      _captionforofs = 'Enter bid quantity and price';
      _cpactionsubtn = false;
    }
    notifyListeners();
  }

  // void setCutoffcheckboxofs(bool val, String cutOffPrice, String balance) {
  //   _cutoffcheckboxofs = val;
  //   if (val) {
  //     // Keep existing quantity, set price to cutoff price
  //     selectedpriceforcpaction.text = cutOffPrice;
  //     _pricevalidcp = true;
  //     _cpactionerrormsg = '';
  //   } else {
  //     selectedpriceforcpaction.text = '';
  //     _pricevalidcp = false;
  //     _cpactionerrormsg = '';
  //   }
  //   _recalculateOFSAmount(balance);
  //   notifyListeners();
  // }

  void setCPActionQty(String setnet, String qty, String type, String balance) {
    if (type == 'OFS') {
      selectedqtyforcpaction.text = setnet;

      // Validate quantity input for OFS
      if (setnet.isEmpty) {
        _cpactionerrormsgqty = 'Quantity cannot be empty';
        _qtyvalidcp = false;
      } else {
        final qtyInt = int.tryParse(setnet);
        if (qtyInt != null && qtyInt > 0) {
          _qtyvalidcp = true;
          _cpactionerrormsgqty = '';
        } else {
          _cpactionerrormsgqty = 'Invalid quantity input';
          _qtyvalidcp = false;
        }
      }

      // Recalculate amount using existing price
      _recalculateOFSAmount(balance);
    } else {
      final net = int.tryParse(setnet);
      final qtyDouble = double.tryParse(qty);
      final qtyInt = qtyDouble != null ? (qtyDouble.toInt()) : null;
      if (setnet.isEmpty) {
        _cpactionerrormsgqty = 'Quantity cannot be empty';
        _qtyvalidcp = false;
      } else if (net != null && qtyInt != null) {
        if (net > qtyInt) {
          _cpactionerrormsgqty = 'Qty must be less than or equal to $qty';
          _qtyvalidcp = false;
        } else {
          _cpactionerrormsgqty = '';
          _qtyvalidcp = true;
        }
      } else {
        _cpactionerrormsgqty = 'Invalid quantity input';
        _qtyvalidcp = false;
      }

      selectedqtyforcpaction.text = setnet;
      _evaluateCPActionValidation();
    }
    notifyListeners();
  }

  showofserrormsg(String msg) {
    _cpactionerrormsgqty = msg;
    notifyListeners();
  }

  void setCPActionPrice(
      String setprice, double min, double max, String type, String balance) {
    if (type == 'OFS') {
      selectedpriceforcpaction.text = setprice;

      // Validate price input for OFS
      if (setprice.isEmpty) {
        _pricevalidcp = false;
        _cpactionerrormsg = 'Price cannot be empty';
      } else {
        final parsedPrice = int.tryParse(setprice);
        if (parsedPrice != null && parsedPrice > 0) {
          if (parsedPrice < min) {
            _pricevalidcp = false;
            _cpactionerrormsg =
                'Price cannot be below base price (₹${min.toInt()})';
          } else {
            _pricevalidcp = true;
            _cpactionerrormsg = '';
          }
        } else {
          _pricevalidcp = false;
          _cpactionerrormsg = 'Invalid price input';
        }
      }

      // Recalculate amount using existing quantity
      _recalculateOFSAmount(balance);
    } else {
      if (setprice.isEmpty) {
        _pricevalidcp = false;
        _cpactionerrormsg = 'Price cannot be empty';
        selectedpriceforcpaction.text = '';
        _evaluateCPActionValidation();
        notifyListeners();
        return;
      }

      final parsedValue = double.tryParse(setprice);

      if (parsedValue != null) {
        if (parsedValue >= min && parsedValue <= max) {
          _pricevalidcp = true;
          _cpactionerrormsg = '';
        } else {
          _pricevalidcp = false;
          _cpactionerrormsg = 'Price must be between $min - $max';
        }
      } else {
        _pricevalidcp = false;
        _cpactionerrormsg = 'Invalid price input'; /////
      }

      selectedpriceforcpaction.text = setprice;
      _evaluateCPActionValidation();
    }

    notifyListeners();
  }

  /// Combines the result of both validations
  void _evaluateCPActionValidation() {
    // For OFS, we need to check both validation flags and the required amount
    if (_qtyvalidcp && _pricevalidcp) {
      // Don't override the button state set by captioncheckofs for OFS
      // For non-OFS actions, enable the button
      if (_requiredamountforofs == '0') {
        _cpactionsubtn = false;
      } else {
        // For non-OFS or when OFS has valid amount
        if (_captionforofs.contains('exceeds') ||
            _captionforofs.contains('Insufficient')) {
          _cpactionsubtn = false;
        } else {
          _cpactionsubtn = true;
        }
      }
      _cpactionerrormsg = '';
    } else {
      _cpactionsubtn = false;
      // Error message is already set in the individual validation methods
    }
  }

  void setselectnetpledge(String setnet, String net) {
    _pledgeoruppledgedelete = '';
    selectnetpledge.text = setnet;

    if (setnet != 'null') {

      if (((int.tryParse(setnet) != null ? int.tryParse(setnet)! : 0) <=
              (int.tryParse(net) != null ? int.tryParse(net)! : 0)) &&
          int.tryParse(setnet) != 0 &&
          setnet != "") {
        _pledgeerrormsg = '';
        pledgesubtn = true;
      } else {
        _pledgeerrormsg = 'Qty between 0 - $net';
        pledgesubtn = false;
      }
    } else {
      _pledgeerrormsg = 'Qty between 0 - $net';
      pledgesubtn = false;
    }

    notifyListeners();
  }

  void setSegment(String seg) {
    if (selectedSegment == seg) {
      return; // Already on this segment
    }
    
    selectedSegment = seg;
    
    // If we have data for this segment, rebuild the UI
    if (hasDataForSegment(seg)) {
      _rebuildGroupedAndHeatmapForSegment(seg);
    } 
    
    notifyListeners();
  }

  void changeormountedsharing(String change) {
    changeornot = change;
    notifyListeners();
  }

  void changesegval(String seg, dynamic index) {
    index.segmentselect = seg;

    _segmentvalue = seg;
    notifyListeners();
  }

  void changesegvaldummy(String seg) {
    if (_listforpledge == []) {
      _segmentvaluedummy = '';
    } else {
      _segmentvaluedummy = seg;
    }
    notifyListeners();
  }

  void dummypledgeval(dynamic share, String net, String type) {
    if (type == 'pledge') {
      share.dummvalue = net;
      _pledgeorunpledge = 'pledge';
    } else {
      share.dummunpledgevalue = net;
      _pledgeorunpledge = 'unpledge';
    }
    notifyListeners();
  }

  void unpledgedeletereqfun(context, String isin, int index) {
    _pledgeoruppledgedelete = 'unpledgedelete';
    bool found = false;
    for (var i = 0; i < _pledgeandunpledge!.data!.length; i++) {
      _pledgeandunpledge!.data![index].deleteselected = 'selected';
    }
    for (var i = 0; i < _listforpledge.length; i++) {
      if (_listforpledge[i] == isin) {
          successMessage(context, 'Script Already added'
        );
        found = true;
        break; // No need to check further
      }
    }

    if (!found) {
      _listforpledge.add(isin);
        successMessage(context, 'Script Added'
      );
    }
    notifyListeners();
  }

  Future beforecdsl(BuildContext context, String ccode, String boid,
      String cname, List list) async {
    try {
      _pledgeloader = true;
      notifyListeners();

      final res = await api.geturlforcdsl(ccode, boid, cname, list);
      Navigator.pop(context);

      if (kIsWeb) {
        // On web, open CDSL in popup and auto-detect when done
        final reqId = res['reqid']?.toString() ?? '';
        _showCdslWebDialog(context, reqId, res);
      } else {
        Navigator.pushNamed(context, Routes.cdslWebView, arguments: res);
      }

      Future.delayed(Duration(milliseconds: 1000));

      cancelpledgetotal('pledge');
      _pledgeloader = false;
      notifyListeners();
    } catch (e) {
      _pledgeloader = false;

      notifyListeners();
    } finally {
      toggleLoad(false);
    }
  }

  void _showCdslWebDialog(BuildContext context, String reqId, Map res) {
    // Set full-panel waiting state
    _cdslWebWaiting = true;
    _cdslWebShowReport = false;
    _cdslresponsedata = null;
    notifyListeners();

    // Open the CDSL popup; onPopupClosed fires if user manually closes it
    openCdslInPopup(res, onPopupClosed: () {
      // User manually closed popup - check status
      _cdslApiPollTimer?.cancel();
      _cdslApiPollTimer = null;
      if (!_cdslWebShowReport) {
        cdslresponsepage(context, reqId).then((_) {
          _cdslWebShowReport = true;
          _cdslWebWaiting = false;
          notifyListeners();
        }).catchError((_) {
          // If API fails, go back to pledge screen
          _cdslWebWaiting = false;
          notifyListeners();
        });
      }
    });

    // Poll our API every 3 seconds to detect CDSL completion
    _cdslApiPollTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_cdslWebShowReport) {
        timer.cancel();
        return;
      }
      try {
        final response = await api.getresponsefromcdsl(reqId);
        final status = response.cDSLResp?.pledgeresdtls
            ?.pledgeresdtlstwo?.resstatus;
        // If API returns a valid status, CDSL is done
        if (status != null && status.isNotEmpty) {
          timer.cancel();
          _cdslApiPollTimer = null;
          _cdslresponsedata = response;
          // Close the popup window automatically
          closeCdslPopup();
          _cdslWebShowReport = true;
          _cdslWebWaiting = false;
          notifyListeners();
        }
      } catch (_) {
        // API not ready yet - keep polling
      }
    });
  }

  /// Cancel CDSL web flow and reset state
  void cancelCdslWebFlow() {
    _cdslApiPollTimer?.cancel();
    _cdslApiPollTimer = null;
    closeCdslPopup();
    _cdslWebWaiting = false;
    _cdslWebShowReport = false;
    _cdslresponsedata = null;
    notifyListeners();
  }

  /// Reset CDSL report state and refresh pledge data
  void resetCdslWebReport(BuildContext context) {
    _cdslWebWaiting = false;
    _cdslWebShowReport = false;
    notifyListeners();
    getCurrentDate("pandu");
    fetchpledgeandunpledge(context);
  }

  Future cdslresponsepage(BuildContext context, String response) async {
    try {
      _pledgeloader = true;
      notifyListeners();

      _cdslresponsedata = await api.getresponsefromcdsl(response);

      // Navigator.pushNamed(context, Routes.camsWebView,
      //     arguments: res);
      // notifyListeners();
    } catch (e) {

    } finally {
      _pledgeloader = false;
      notifyListeners();
      toggleLoad(false);
    }
  }

  void listforpledgefunction(
      BuildContext context,
      String seg,
      String sym,
      String isin,
      String value,
      String qty,
      String net,
      String type,
      dynamic index) {
    bool found = false;
    if (type == 'pledge') {
      index.segmentselect = seg;

      for (var i = 0; i < _listforpledge.length; i++) {
        if (_listforpledge[i]['isin'] == isin) {
          _listforpledge[i]['quantity'] = qty;
            successMessage(context, 'Script Updated'
          );
          found = true;
          break; // No need to check further
        }
      }

      if (!found) {
        _listforpledge.add({
          "segments": seg,
          "symbol": sym,
          "isin": isin,
          "value": value,
          "quantity": qty,
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar();
          
            successMessage(context, 'Script Added'
          );
      }
    } else {
      for (var i = 0; i < _listforpledge.length; i++) {
        if (_listforpledge[i]['ISIN'] == isin) {
          _listforpledge[i]['COLQTY'] = qty;
          _listforpledge[i]['unplege_qty'] = qty;
            successMessage(context, 'Script Updated'
          );
          found = true;
          break; // No need to check further
        }
      }

      if (!found) {
        _listforpledge.add({
          "COLQTY": qty,
          "ISIN": isin,
          "NET": net,
          "NSE_SYMBOL": sym,
          "unplege_qty": qty,
        });
          successMessage(context, 'Script Added'
        );
      }
    }
    notifyListeners();
  }

  void removeSinglePledgeItem(String isin, String type, dynamic dataItem) {
    if (type == 'pledge') {
      _listforpledge.removeWhere((item) => item['isin'] == isin);
      dataItem.dummvalue = 'null';
      dataItem.segmentselect = 'null';
    } else {
      _listforpledge.removeWhere((item) => item['ISIN'] == isin);
      dataItem.dummunpledgevalue = 'null';
      dataItem.deleteselected = '';
    }
    if (_listforpledge.isEmpty) {
      _pledgeorunpledge = '';
      _segmentvalue = '';
      _segmentvaluedummy = '';
    }
    notifyListeners();
  }

  void cancelpledgetotal(String type) {
    pledgesubtn = false;

    if (type == 'pledge') {
      if (_pledgeandunpledge != null && _pledgeandunpledge!.data != null) {
        for (var i = 0; i < _pledgeandunpledge!.data!.length; i++) {
          _pledgeandunpledge!.data![i].dummvalue = 'null';
          _pledgeandunpledge!.data![i].segmentselect = 'null';
          _pledgeandunpledge!.data![i].deleteselected = '';
        }
      }

      _pledgeoruppledgedelete = '';
      _pledgeorunpledge = '';

      _listforpledge = [];
    } else {
      if (_pledgeandunpledge != null && _pledgeandunpledge!.data != null) {
        for (var i = 0; i < _pledgeandunpledge!.data!.length; i++) {
          _pledgeandunpledge!.data![i].dummunpledgevalue = 'null';
          _pledgeandunpledge!.data![i].deleteselected = '';
        }
      }

      _listforpledge = [];
      _pledgeorunpledge = '';
    }
    //  _pledgeandunpledge!.data = [];

    notifyListeners();
  }

  void clearOnLogout() {
    _segmentvalue = '';
    _segmentvaluedummy = '';
    _listforpledge = [];
    _pledgeorunpledge = '';
    _pledgeoruppledgedelete = '';
    pledgesubtn = true;
    if (_pledgeandunpledge?.data != null) {
      for (final item in _pledgeandunpledge!.data!) {
        item.dummvalue = 'null';
        item.dummunpledgevalue = 'null';
        item.segmentselect = 'null';
        item.deleteselected = '';
      }
    }
    notifyListeners();
  }

  /// Aggregates daily P&L into monthly sums for the given [start] and [end] dates.
  /// The key format is "YYYY-MM".
  Map<String, double> _aggregateMonthlyPnL(
      Map<DateTime, double> data, DateTime start, DateTime end) {
    final Map<String, double> result = {};
    data.forEach((date, pnl) {
      if (date.isBefore(start) || date.isAfter(end)) return;
      final key = "${date.year}-${date.month.toString().padLeft(2, '0')}";
      result[key] = (result[key] ?? 0) + pnl;
    });
    return result;
  }

  /// Generates a list of the last [count] financial years (in descending order).
  /// Each financial year is represented as a string "YYYY-YYYY".
  List<String> _generateFinancialYears(int count) {
    final now = DateTime.now();
    int currentFYStartYear = now.month < 4 ? now.year - 1 : now.year;
    final years = <String>[];
    // Only add the current financial year
    final startY = currentFYStartYear;
    years.add("$startY-${startY + 1}");
    return years;
  }

  void clearOFSFields() {
    selectedqtyforcpaction.text = '';
    selectedpriceforcpaction.text = '';
    _requiredamountforofs = '0';
    _captionforofs = 'Enter bid quantity and price';
    _qtyvalidcp = false;
    _pricevalidcp = false;
    _cpactionsubtn = false;
    _cpactionerrormsg = '';
    _cpactionerrormsgqty = '';
    _cutoffcheckboxofs = false;
    notifyListeners();
  }

  // Add month picker function
  void monthPickerDialog(BuildContext context, ThemesProvider theme) async {
    // Always start with current date
    final initialDate = DateTime.now();
    DateTime selectedDate = initialDate;

    await showModalBottomSheet(
      context: context,
      backgroundColor: theme.isDarkMode ? Colors.black : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 300,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary:
                          theme.isDarkMode ? Colors.white : colors.primaryLight,
                      onPrimary:
                          theme.isDarkMode ? Colors.black : colors.colorWhite,
                      surface: theme.isDarkMode ? Colors.black : Colors.white,
                      onSurface: theme.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: initialDate,
                    firstDate: DateTime(initialDate.year - 2),
                    lastDate: DateTime(initialDate.year + 2),
                    onDateChanged: (date) {
                      selectedDate = date;
                    },
                    initialCalendarMode: DatePickerMode.year,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: theme.isDarkMode
                          ? colors.primaryDark
                          : colors.primaryLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onPressed: () {
                      // Set start date to first day of month
                      final firstDay =
                          DateTime(selectedDate.year, selectedDate.month, 1);
                      // Set end date to last day of month
                      final lastDay = DateTime(
                          selectedDate.year, selectedDate.month + 1, 0);

                      _startDate =
                          "${firstDay.day.toString().padLeft(2, '0')}/${firstDay.month.toString().padLeft(2, '0')}/${firstDay.year}";
                      _endDate =
                          "${lastDay.day.toString().padLeft(2, '0')}/${lastDay.month.toString().padLeft(2, '0')}/${lastDay.year}";

                      notifyListeners();
                      Navigator.pop(context);
                    },
                    child: TextWidget.subText(
                      text: "Ok",
                      theme: theme.isDarkMode,
                      fw: 2,
                      color: colors.colorWhite,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Contract Calendar related variables
  Map<DateTime, List<String>> _contractDocumentDates = {};
  Map<DateTime, List<String>> get contractDocumentDates =>
      _contractDocumentDates;

  // Store full document details for each date
  Map<DateTime, List<DocumentDetail>> _contractDocumentDetails = {};
  Map<DateTime, List<DocumentDetail>> get contractDocumentDetails =>
      _contractDocumentDetails;

  String _selectedContractFilter = 'CN'; // Default to CN
  String get selectedContractFilter => _selectedContractFilter;

  // Filter options for contract calendar
  List<String> contractFilterOptions = ['Contract', 'CN'];

  // Loading state for contract calendar
  bool _isContractCalendarLoading = false;
  bool get isContractCalendarLoading => _isContractCalendarLoading;

  // Contract Calendar methods
  void setContractFilter(String filter) {
    _selectedContractFilter = filter;
    notifyListeners();
  }

  Future fetchContractDocuments(int year, int month) async {
    try {
      _isContractCalendarLoading = true;
      notifyListeners();

      // Format dates for API (DD/MM/YYYY format)
      final startDate = "01/${month.toString().padLeft(2, '0')}/${year}";
      final endDate =
          "${DateTime(year, month + 1, 0).day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/${year}";

      // Call existing PDF download API
      _pdfdownload = await api.getpdfdownload(startDate, endDate);

      // Clear previous data
      _contractDocumentDates.clear();
      _contractDocumentDetails.clear();

      // Parse response and populate document dates
      if (_pdfdownload?.data != null) {
        for (var doc in _pdfdownload!.data!) {
          if (doc.docDate != null &&
              (doc.docType == 'CN' || doc.docType == 'Contract')) {
            // Parse date from DD/MM/YYYY format
            final dateParts = doc.docDate!.split('/');
            if (dateParts.length == 3) {
              final day = int.parse(dateParts[0]);
              final month = int.parse(dateParts[1]);
              final year = int.parse(dateParts[2]);
              final docDate = DateTime(year, month, day);

              if (!_contractDocumentDates.containsKey(docDate)) {
                _contractDocumentDates[docDate] = [];
              }
              _contractDocumentDates[docDate]!.add(doc.docType!);

              // Store full document details
              if (!_contractDocumentDetails.containsKey(docDate)) {
                _contractDocumentDetails[docDate] = [];
              }
              _contractDocumentDetails[docDate]!.add(DocumentDetail(
                docType: doc.docType!,
                recno: doc.recno ?? '',
                docFileName: doc.docFileName ?? '',
                docDate: doc.docDate!,
              ));
            }
          }
        }
      }

      _isContractCalendarLoading = false;
      notifyListeners();
    } catch (e) {
      _isContractCalendarLoading = false;
      notifyListeners();
    }
  }

  // ─── Contract Note Data ─────────────────────────────────────────────
  ContractNoteModel? _contractNoteModel;
  ContractNoteModel? get contractNoteModel => _contractNoteModel;

  bool _isContractNoteLoading = false;
  bool get isContractNoteLoading => _isContractNoteLoading;

  Future fetchContractNote(String from, String to) async {
    try {
      _isContractNoteLoading = true;
      notifyListeners();

      _contractNoteModel = await api.getContractNote(from, to);

      _isContractNoteLoading = false;
      notifyListeners();
    } catch (e) {
      _isContractNoteLoading = false;
      notifyListeners();
    }
  }

  void searchLedgerType(String value) {
    if (_ledgerAllDataDummy == null || _ledgerAllDataDummy!.fullStat == null)
      return;

    if (value.isEmpty) {
      // Reset to original data
      _ledgerAllData!.fullStat = List.from(_ledgerAllDataDummy!.fullStat!);
    } else {
      final searchTerm = value.toLowerCase();
      _ledgerAllData!.fullStat = _ledgerAllDataDummy!.fullStat!
          .where((entry) =>
              (entry.tYPE?.toLowerCase().contains(searchTerm) ?? false) ||
              (entry.nARRATION?.toLowerCase().contains(searchTerm) ?? false) ||
              (entry.vOUCHERDATE?.toLowerCase().contains(searchTerm) ?? false))
          .toList();
    }
    notifyListeners();
  }

  Set<SingingCharacter> _selectedFilters = {};
  Set<SingingCharacter> get selectedFilters => _selectedFilters;

  bool _includeBillMargin = true ;
  bool get includeBillMargin => _includeBillMargin;
  void setIncludeBillMargin(bool value) {
    _includeBillMargin = value;
    notifyListeners();
  }

  void applyLedgerMultiFilter(
      BuildContext context, List<SingingCharacter> filters) {
    _selectedFilters = Set.from(filters);

    if (_ledgerAllDataDummy == null) {
      _ledgerAllData?.fullStat = [];
      notifyListeners();
      return;
    }

    List<FullStat> originalList =
        List.from(_ledgerAllDataDummy!.fullStat ?? []);
    List<FullStat> filteredList = [];

    // If no filters selected, show no data
    // if (filters.isEmpty) {
    //   _ledgerAllData!.fullStat = [];
    //   _ledgerAllData!.openingBalance = '0.00';
    //   _ledgerAllData!.crAmt = '0.00';
    //   _ledgerAllData!.drAmt = '0.00';
    //   _ledgerAllData!.closingBalance = '0.00';
    //   notifyListeners();
    //   return;
    // }

    bool billMarginSelected = filters.contains(SingingCharacter.billmargin);
    _includeBillMargin = billMarginSelected;
    
    // Update _selectedFilters to match the actual data being shown
    if (!billMarginSelected) {
      // Remove billmargin from selected filters if it's not selected
      _selectedFilters.remove(SingingCharacter.billmargin);
    } else {
      // Add billmargin to selected filters if it's selected
      _selectedFilters.add(SingingCharacter.billmargin);
    }
    
    // Count only the type filters (not billmargin)
    int typeFilterCount =
        filters.where((f) => f != SingingCharacter.billmargin).length;
    bool allTypesSelected = (typeFilterCount == 4 && billMarginSelected) ||
        (typeFilterCount == 4 && !billMarginSelected);

    bool matchesType(FullStat o) {
      return filters.any((filter) {
        if (filter != SingingCharacter.billmargin && allTypesSelected) {
          // This block runs for anything EXCEPT billmargin
          // Add whatever condition you want here
          return o.tYPE == 'Opening Balance' ||
              o.tYPE == 'Reciept' ||
              o.tYPE == 'Payment' ||
              o.tYPE == 'Journal' ||
              o.tYPE == 'Bill';
        }
        switch (filter) {
          case SingingCharacter.receipt:
            return o.tYPE == 'Reciept';
          case SingingCharacter.payment:
            return o.tYPE == 'Payment';
          case SingingCharacter.journal:
            return o.tYPE == 'Journal';
          case SingingCharacter.systemjournal:
            return o.tYPE == 'Bill';
          case SingingCharacter.billmargin:
            return o.tYPE == 'Bill-Margin';
          default:
            return false;
        }
      });
    }

    // if (allTypesSelected && billMarginSelected) { o.billMargin != 'Yes'
    if (allTypesSelected && billMarginSelected) {
      // All types + Bill Margin: show all entries
      filteredList = originalList;
       fetchLegerData(context, startDate, endDate, includeBillMargin);
    } else if (allTypesSelected) {
      filteredList = originalList
          .where((o) => o.tYPE != 'Bill-Margin' && matchesType(o))
          .toList();
          fetchLegerData(context, startDate, endDate, includeBillMargin);
          
    } else if (typeFilterCount == 0 && !billMarginSelected) {
      filteredList =
          originalList.where((o) => o.tYPE == 'Opening Balance').toList();
    }
    // else if (allTypesSelected && !billMarginSelected) {
    //   // All types, but not Bill Margin: show all non-margin entries
    //   filteredList = originalList.where((o) => o.billMargin != 'Yes').toList();
    // } else if (billMarginSelected && typeFilterCount == 0) {
    //   // Only Bill Margin selected: show all margin entries
    //   filteredList = originalList.where((o) => o.billMargin == 'Yes').toList();
    // } else if (billMarginSelected && typeFilterCount > 0) {
    //   // Bill Margin + some types: show margin entries of those types
    //   filteredList = originalList.where((o) => o.billMargin == 'Yes' && matchesType(o)).toList();
    // }
    else {
      // Only type filters: show non-margin entries of those types
      filteredList = originalList.where((o) => matchesType(o)).toList();
    }

    _ledgerAllData!.fullStat = filteredList;

    // Recalculate totals
    double totalCrAmt = 0.0;
    double totalDrAmt = 0.0;

    for (var i = 0; i < filteredList.length; i++) {
      totalCrAmt +=
          double.tryParse(filteredList[i].cRAMT?.toString() ?? '0') ?? 0.0;
      totalDrAmt +=
          double.tryParse(filteredList[i].dRAMT?.toString() ?? '0') ?? 0.0;
    }

    _ledgerAllData!.openingBalance = _ledgerAllDataDummy!.openingBalance;
    _ledgerAllData!.crAmt = totalCrAmt.toStringAsFixed(2);
    _ledgerAllData!.drAmt = totalDrAmt.toStringAsFixed(2);

    // Sort and calculate running balance
    _ledgerAllData!.fullStat?.sort((a, b) {
      return int.parse(a.sortNo!).compareTo(int.parse(b.sortNo!));
    });

    for (var i = 0; i < filteredList.length; i++) {
      if (i == 0) {
        filteredList[i].nETAMT = (double.parse(filteredList[i].cRAMT!) -
                double.parse(filteredList[i].dRAMT!))
            .toStringAsFixed(2);
      } else {
        filteredList[i].nETAMT = (double.parse(filteredList[i - 1].nETAMT!) +
                (double.parse(filteredList[i].cRAMT!) -
                    double.parse(filteredList[i].dRAMT!)))
            .toStringAsFixed(2);
      }
    }

    _ledgerAllData!.fullStat?.sort((a, b) {
      return int.parse(b.sortNo!).compareTo(int.parse(a.sortNo!));
    });

    if (filteredList.isNotEmpty) {
      _ledgerAllData!.closingBalance = filteredList[0].nETAMT ?? '0.00';
    } else {
      _ledgerAllData!.closingBalance = '0.00';
    }

    notifyListeners();
  }

  // Check if data exists for a specific segment
  bool hasDataForSegment(String segment) {
    return _calenderpnlDataBySegment.containsKey(segment) && 
           _calenderpnlDataBySegment[segment] != null;
  }

  // Check if all segments have data
  bool get hasDataForAllSegments {
    return availableSegments.every((segment) => hasDataForSegment(segment));
  }

  // Get data for a specific segment without fetching
  CalenderpnlModel? getDataForSegment(String segment) {
    return _calenderpnlDataBySegment[segment];
  }

  // Get current segment data
  CalenderpnlModel? get currentSegmentData {
    return _calenderpnlDataBySegment[selectedSegment];
  }

  // Fetch data for all segments if none have data
  Future fetchDataForAllSegmentsIfEmpty(
      BuildContext context, String from, String to) async {
    if (hasDataForAllSegments) {
      return; // All segments already have data
    }
    
    // Set loading state for all segments initially
    for (String segment in availableSegments) {
      if (!hasDataForSegment(segment)) {
        setCalendarPnlLoadingForSegment(segment, true);
      }
    }
    notifyListeners();
    
    // Fetch data for all segments
    for (String segment in availableSegments) {
      if (!hasDataForSegment(segment)) {
        await fetchcalenderpnldata(context, from, to, segment);
      }
    }
  }

  // Simplified fetchcalenderpnldata without caching
  Future fetchcalenderpnldata(
      BuildContext context, String from, String to, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _noticenewfeature = prefs.getString("notice").toString();

      // Set segment-specific loading state
      setCalendarPnlLoadingForSegment(type, true);
      _calendarpnlloading = true;
      notifyListeners();
      
      CalenderpnlModel? fetchedData = await api.getcalenderpnldata(from, to, type);
      
      // Store data for this specific segment
      if (fetchedData != null) {
        fetchedData.segment = type;
        _calenderpnlDataBySegment[type] = fetchedData;
        
        // Only update the UI data if this is the currently selected segment
        if (selectedSegment == type) {
          // Use the centralized method to rebuild all data structures
          _rebuildGroupedAndHeatmapForSegment(type);
        }
      }
      
      // Clear segment-specific loading state
      setCalendarPnlLoadingForSegment(type, false);
      _calendarpnlloading = false;
      
      // Clear search if any
      if (profitlossSearchCtrl.text.isNotEmpty) {
        profitlossSearchCtrl.clear();
      }
      
      notifyListeners();
    } catch (e) {
      // Clear segment-specific loading state on error
      setCalendarPnlLoadingForSegment(type, false);
      _calendarpnlloading = false;
    }
  }

  // Switch to a different segment, fetching data only if needed
  Future switchToSegment(BuildContext context, String segment, String from, String to) async {
    if (selectedSegment == segment) {
      return; // Already on this segment
    }
    
    // Set loading state for the segment being switched to
    setCalendarPnlLoadingForSegment(segment, true);
    notifyListeners();
    
    try {
      selectedSegment = segment;
      
      if (!hasDataForSegment(segment)) {
        await fetchcalenderpnldata(context, from, to, segment);
      } else {
        _rebuildGroupedAndHeatmapForSegment(segment);
        
        final currentSegmentData = _calenderpnlDataBySegment[segment];
        if (grouped.isEmpty && currentSegmentData != null && currentSegmentData.data != null && currentSegmentData.data!.isNotEmpty) {
          _rebuildGroupedAndHeatmapForSegment(segment);
        }
      }
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      
    } finally {
      setCalendarPnlLoadingForSegment(segment, false);
      notifyListeners();
    }
  }

  // Rebuild grouped data and heatmap for a specific segment without refetching
  void _rebuildGroupedAndHeatmapForSegment(String segment) {
    final segmentData = _calenderpnlDataBySegment[segment];
    if (segmentData == null) {
      grouped = {};
      _originalGrouped = {};
      _heatmapData = {};
      monthlyPnL.clear();
      notifyListeners();
      return;
    }
    
    
    grouped = {};
    _originalGrouped = {};
    _heatmapData = {};
    
    // Clear search and filters when switching segments
    if (profitlossSearchCtrl.text.isNotEmpty) {
      profitlossSearchCtrl.clear();
    }
    // _selectedFilters = {};
    
    // Process journal data for heatmap
    if (segmentData.journal != null && segmentData.journal!.isNotEmpty) {
      for (var element in segmentData.journal!) {
        if (element.realisedpnl != null && element.realisedpnl != '0.0' && element.tRADEDATE != null) {
          try {
            DateFormat inputFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
            DateTime parsedDate = inputFormat.parse(element.tRADEDATE!);
            final dateKey = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
            _heatmapData[dateKey] = double.tryParse(element.realisedpnl ?? "0.0") ?? 0.0;
          } catch (e) {
          }
        }
      }
    }
    
    // Process trade data for grouping
    if (segmentData.data != null && segmentData.data!.isNotEmpty) {
      for (var trade in segmentData.data!) {
        if (trade.tRADEDATE != null) {
          try {
            DateFormat inputFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
            DateTime parsedDate = inputFormat.parse(trade.tRADEDATE!);
            final dateKey = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
            if (!grouped.containsKey(dateKey)) {
              grouped[dateKey] = [];
            }
            grouped[dateKey]!.add(trade);
          } catch (e) {
          }
          }
      }
      }
    
    // Store original grouped data for filtering
    _originalGrouped = Map.from(grouped);
    
    // Recalculate monthly P&L based on the new heatmap data
    if (_heatmapData.isNotEmpty) {
      monthlyPnL = _aggregateMonthlyPnL(_heatmapData, startTaxDate, endTaxDate);
    } else {
      monthlyPnL.clear();
    }
    
    if (grouped.isNotEmpty) {
      
      for (var dateKey in grouped.keys.take(3)) {
        final tradesForDate = grouped[dateKey]!;
        if (tradesForDate.isNotEmpty) {
        }
      }
    }
    
    // Ensure we have at least an empty map if no data was processed
    if (grouped.isEmpty) {
      grouped = {};
      _originalGrouped = {};
    }
    
    notifyListeners();
  }

  // Method to refresh the current segment's UI data without refetching
  void refreshCurrentSegmentUI() {
    if (hasDataForSegment(selectedSegment)) {
      _rebuildGroupedAndHeatmapForSegment(selectedSegment);
    } 
  }

  // Method to clear Calendar PnL data when switching accounts
  void clearCalendarPnLData() {
    // Clear segment-based data storage
    _calenderpnlDataBySegment.clear();
    _calendarChargesBySegment.clear();
    
    // Clear segment-specific loading states
    _calendarPnlLoadingBySegment.clear();
    
    // Clear legacy data structures
    _calenderpnlAllData = null;
    grouped.clear();
    _originalGrouped.clear();
    _heatmapData.clear();
    monthlyPnL.clear();

    // Reset financial year and date-related variables
    selectedFinancialYear = '';
    startTaxDate = DateTime.now();
    endTaxDate = DateTime.now();
    selectedMonth = DateTime.now();
    formattedStartDate = '';
    formattedendDate = '';

    // Reset loading state
    _calendarpnlloading = false;

    // Reset sharing-related variables
    _ucode = '';
    notsharing = true;
    changeornot = '';
    
    notifyListeners();
  }

}
// List<double> getCustItemsHeight() {
//   List<double> itemsHeights = [];
//   for (var i = 0; i < (_paymentMethod.length * 2) - 1; i++) {
//     if (i.isEven) {
//       itemsHeights.add(40);
//     }
//     if (i.isOdd) {
//       itemsHeights.add(4);
//     }
//   }
//   return itemsHeights;
// }
