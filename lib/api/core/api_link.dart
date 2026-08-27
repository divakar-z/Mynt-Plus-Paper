import 'package:flutter/foundation.dart' show kIsWeb;

/// Point the trade-journal notes API at a local `journal_notes.py` dev server
/// instead of live:
///
///   flutter run -d chrome --web-port 8080 \
///       --dart-define=JOURNAL_NOTES_LOCAL=true
///
/// Read from the environment rather than hardcoded so a dev pointer cannot be
/// committed by accident — the default is always live.
///
/// Note the dev server is cross-origin from the Flutter web app, so the browser
/// preflights every call. `journal_notes.py` must answer `OPTIONS` with
/// `Access-Control-Allow-Headers: Authorization, clientid, Content-Type` or the
/// requests fail before reaching Flask. `curl` will not reveal this — it does
/// not preflight.
const bool kJournalNotesUseLocalDev =
    bool.fromEnvironment('JOURNAL_NOTES_LOCAL');

/// Point the client support API at a different osTicket host — a staging
/// instance, say.
///
/// Empty by default, which falls back to the live `ticket.mynt.in`. Read from
/// the environment so a dev pointer cannot be committed by accident.
const String kSupportApiBaseOverride =
    String.fromEnvironment('SUPPORT_API_BASE');

// The app used to carry an HMAC signing key here and mint its own JWT. It no
// longer does, and must not again: `POST /auth/session` takes the trading
// session token the app already holds, and osTicket proves the client code
// against the trading backend's own `validate_session` before issuing anything.
// Nothing secret ships, so there is nothing in the bundle left to extract.
//
// Removed 2026-08-27 with the backend's SUPPORT_AUTH_CHANGE note. The old key
// stays in this file's git history — treat it as burnt and rotate it
// server-side rather than assuming its removal here retired it.

class ApiLinks {
// UAT----

  // String get goMyntURL => "https://uat.mynt.in/NorenWClient";
  // static String wsURL = 'wss://uat.mynt.in/NorenWSMob/';

  static String source = kIsWeb ? "WEB" : "MOB";
  static String otp = "";
  static String userName = "";
  static bool showAppTutorial = true;

// GO MYNT-----

  String get goMyntURL => "https://go.mynt.in/NorenWClientWeb";
  static String wsURL = 'wss://go.mynt.in/NorenWSWeb/';
  String get bemynt => "https://be.mynt.in/";
  String get oauthBase => "https://ws.mynt.in/login/";

  /// OAuth partner-app authorization endpoints (used by OAuthLoginScreen).
  String get myntValidate => '${oauthBase}api/mynt-validate';
  String get myntAuth => '${oauthBase}api/mynt-auth';

  String get newsurl => "$bemynt/news";
  String get weblog => "$bemynt/weblog/addlogversion";

  String get getpref => "$bemynt/weblog/getpreference";
  String get setpref => "$bemynt/weblog/savepreference";

  ///generate api key
  String get apiKey => '$goMyntURL/RequestApiKey';
  String get generateapiKey => '$goMyntURL/UserApiKeyRenReq';
  String get generateapiKeynewuser => '$goMyntURL/GetUserApiKey';
  String get getapikeynew => '$goMyntURL/GetAppKeyData';
  String get appkeystore => '$goMyntURL/AppKeyStore';
  String get gettotp => "$goMyntURL/GetSecretKey";
  String get gentotp => "$goMyntURL/GenSecretKey";

  // Notification service
  String get exchStatus => '$goMyntURL/ExchStatus';
  String get exchMsg => '$goMyntURL/ExchMsg';
  String get brokermsg => '$goMyntURL/GetBrokerMsg';

  ////Set Alert
  String get setAlert => '$goMyntURL/SetAlert';
  String get cancelAlert => '$goMyntURL/CancelAlert';
  String get pendingalert => '$goMyntURL/GetPendingAlert';
  String get modifyalert => '$goMyntURL/ModifyAlert';

// Market watxhlist

  String get watchList => '$goMyntURL/MWList';
  String get tpseries => '$goMyntURL/TPSeries';
  String get preDefinedMWList => '$goMyntURL/PreDefinedMWList';
  String get marketWatchScrip => '$goMyntURL/MarketWatch';
  String get securityInfo => '$goMyntURL/GetSecurityInfo';
  String get getQuotes => '$goMyntURL/GetQuotes';
  String get getLinkedScrip => '$goMyntURL/GetLinkedScrips';
  String get optionChain => '$goMyntURL/GetOptionChain';
  String get deleteMWScrips => '$goMyntURL/DeleteMultiMWScrips';
  String get addMWScrips => '$goMyntURL/AddMultiScripsToMW';
  String get reorderMWScrips => '$goMyntURL/ReorderMWScrips';
  String get searchScrip => '$goMyntURL/SearchScrip';
  // String get searchScripNew => '${bemynt}global/SearchScrip';
String get searchScripNew => 'https://ws.mynt.in/search/SearchScrip';
  String get derivativeMaster => 'https://ws.mynt.in/search/DerivativeMaster';
  String get searchOptScript => '${bemynt}global/SearchOptScript';
  String get technicalData => '$goMyntURL/GetTechnicals';
  String get watchListrename => '$goMyntURL/RenameMW';
  String get spanCalc => 'https://go.mynt.in/NorenWClientWeb/SpanCalc';
  String get eodchartdata => '$goMyntURL/EODChartData';

  // Cams
  String get goCamsURL => "https://rekycbe.mynt.in/portfolio";
  String get getCames => '$goCamsURL/broker_dateils_get';
  String get getCamesauth => '$goCamsURL/login/auth';

// Market Index

  String get marketIndex => '$goMyntURL/GetIndexList';

// Profile

  String get userDetail => '$goMyntURL/UserDetails';
  String get clientDetail => '$goMyntURL/ClientDetails';
  String get freezeAccount => '$goMyntURL/FreezeAccount';
  String get blockAcct => '$goMyntURL/BlockAcct';
  String get algoStrategy => 'http://192.168.5.119:9005/api/getall';
  String get createAlgoStrategy => 'http://192.168.5.119:9005/api/new';
  String get updateAlgoStrategy => 'http://192.168.5.119:9005/api/update';
  String get deleteAlgoStrategy => 'http://192.168.5.119:9005/api/delete';

// Trade data

  String get getPosition => '$goMyntURL/PositionBook';
  String get getHoldings => '$goMyntURL/Holdings';
  String get getMFHoldings => '$goMyntURL/GetMFSSHoldInfo';
  String get getQuotesMF => '$goMyntURL/GetQuotesMF';

  String get getOrder => '$goMyntURL/OrderBook';
  String get positionConvert => '$goMyntURL/ProductConversion';
  String get orderHistory => '$goMyntURL/SingleOrdHist';
  String get modifySipOrder => '$goMyntURL/ModifySipOrder';
  String get sipOrderBook => '$goMyntURL/SipOrderBook';
  String get multiLegOrderBook => '$goMyntURL/MultiLegOrderBook';
  String get tradeBook => '$goMyntURL/TradeBook';
  String get cancleSiporder => '$goMyntURL/CancelSipOrder';
  String get pendingGttorder => '$goMyntURL/GetPendingGTTOrder';
  String get triggeredGttorder => '$goMyntURL/GetTrgOi';
  String get cancelGTTOrderURL => '$goMyntURL/CancelGTTOrder';
  String get basketMargin => '$goMyntURL/GetBasketMargin';

// Payoff & Greeks
  String get payoffCalculation => '${bemynt}payoff-calculation';
  String get optionGreeks => '${bemynt}getoptiongreeks';

// Option Strategy API
  String get optionStrategyBaseURL => 'https://agg.zebuetrade.com';
  String get selectSymbols => '$optionStrategyBaseURL/select-symbols';
  String get strategies => '$optionStrategyBaseURL/strategies';

// RupeeCase curated-strategies marketplace (dashboard "Curated Strategies" cards)
  String get rupeeCaseBaseURL => 'https://agg.zebuetrade.com/rupeecase/api/v1';
  String get rupeeCaseStrategies => '$rupeeCaseBaseURL/strategies';

  /// Algo (automated) strategy baskets — powers the "Algo" tab in the dashboard
  /// Strategies section.
  String get rupeeCaseAlgoStrategies => '$rupeeCaseBaseURL/algo-strategies';

// Order

  String get orderMargin => '$goMyntURL/GetOrderMargin';
  String get exitSNOOrder => '$goMyntURL/ExitSNOOrder';

  String get getBrokerage => '$goMyntURL/GetBrokerage';
  String get placeOrder => '$goMyntURL/PlaceOrder';
  String get cancelOrder => '$goMyntURL/CancelOrder';
  String get placeGTTOrderURL => '$goMyntURL/PlaceGTTOrder';
  String get placeOCOOrderURL => '$goMyntURL/PlaceOCOOrder';
  String get modifyGTTOrderURL => '$goMyntURL/ModifyGTTOrder';
  String get modifyOCOOrderURL => '$goMyntURL/ModifyOCOOrder';
  String get mdifyOrder => '$goMyntURL/ModifyOrder';
// Fund

  String get getHsToken => '$goMyntURL/GetHsToken';
  String get getlimits => '$goMyntURL/Limits';

// Logout

  String get logout => '$goMyntURL/Logout';
  String get deskLogout => 'https://rekycbe.mynt.in/autho/desklogout';

// Local Server ---------

  // UAT-----

  // String get mainBaseURL => 'https://copy.mynt.in/uat';

  String get mainBaseURL => 'https://copy.mynt.in';
  String get mainBaseURLnew => 'https://ws.mynt.in/login';

  String get mobileLogin => '$mainBaseURLnew/MobileLogin';

  String get mobileOtp => '$mainBaseURLnew/otp_verify';

  String get loginOtp => '$mainBaseURL/otp_send_Tv';
  String get loginOtpVerify => 'https://ws.mynt.in/login/otp_verify';
  String get deviceLogin => '$mainBaseURLnew/device_login';
  String get validateSession => '$mainBaseURLnew/validate_session';

  String get forgetPassword => '$mainBaseURLnew/ForgetPassword';

  String get myntchangePassword => 'https://go.mynt.in/NorenWClientWeb/Changepwd';

  String get placeSipOrder => '$goMyntURL/PlaceSipOrder';

  String get preDefdMWatchScrip => 'https://go.mynt.in/NorenWClientWeb/PreDefinedMW';
  String get getAllIndx => 'https://go.mynt.in/NorenWClientWeb/GetIndexList';

  // Position Group
  String get positionGrp => 'https://copy.mynt.in/Getpositiongrp';
  String get creatGrpName => 'https://copy.mynt.in/Createpositiongrp';
  String get addSymbolGrp => 'https://copy.mynt.in/addsymbolpositiongrp';
  String get delpositiongrpName => 'https://copy.mynt.in/Deletepositiongrp';
  String get delpositiongrpSym => 'https://copy.mynt.in/removesymbolpositiongrp';

  // Scrip Overview

  // String get scripOverviewUrl => 'http://192.168.5.142:5000';

  // String get fundamental => '$scripOverviewUrl/stockFundamentalDetails';
  // String get stockHoldings => '$scripOverviewUrl/stockHoldings';

  String get scripOverviewUrl1 => 'http://192.168.5.209:5005';

  String get mainBaseURL1 => 'http://192.168.5.82:5000';
  // String get mainBaseURL1 => 'http://192.168.5.83:5000';
  String get getClientTrades => '$mainBaseURL1/getClientTrades';

  // Stock data URL

  String dashBoardURL = "https://v3.mynt.in";
  String get portfolioAnalysisURL => "$dashBoardURL/dd/AnalysisHoldingsdata_mob";
  String get referralBonusURL => "http://192.168.5.207:8002/bonus_details/referal_bonus";

  // String tradeAction = "https://v3.mynt.in/equity/getadindicesAdvdec";

  String get fundamentalDetail =>
      '$dashBoardURL/equity/stockFundamentalDetails';
  String get topListStock => '$dashBoardURL/equity/TopList';
  String get getGlobalIndex => '$dashBoardURL/equity/getGlobalIndex';
  String get getadindices => '$dashBoardURL/equity/getadindices';
  String get getadindicesAdvdec => '$dashBoardURL/equity/getadindicesAdvdec';
  String get getCorporateAction => '$dashBoardURL/ipo/getCorporateAction';
  String get getStockMonitor => '$dashBoardURL/equity/GetContentList';
  String get getCAevents => '$dashBoardURL/equity/eventsDashboard';

  /// Qr Scanner
  String get getQrScanner => '$mainBaseURL/QRMobileReq';

  ///ipo///
  String get ipourlendpoint => "$dashBoardURL/ipo/";
  String get dashboardipos => "${ipourlendpoint}IpoDashboard";
  String get smeipos => "${ipourlendpoint}getcurrentSMEIPOdetails";
  String get mainstreamipo => "${ipourlendpoint}getcurrentIPOdetails";
  String get ipoperformance => "${ipourlendpoint}ipo_performer?year=2024";
  String get placeipoorder => "${ipourlendpoint}addIPOtoPortfolio";
  String get ipoorderbook => "${ipourlendpoint}orderbookIPODetails";
  String get iposinglepage => "${ipourlendpoint}get_single_ipo_data_new";
  String get ipoprecloseurl => "${ipourlendpoint}precloseipo";
  String get ipoupcomingurl => "${ipourlendpoint}getupcomingdetails";

// Mutual Fund
  String get bestMf => "$dashBoardURL/mf/z_data_1";
  String get newbestMf => "$dashBoardURL/mf/getMfBaskets";
  String get mfCategoryList => "$dashBoardURL/mf/getCategoryschemes";
  String get mfCategoryListData => "$dashBoardURL/mf/get_title_values";
  String get mfCategoryTypes => "$dashBoardURL/mf/getCategoryType";
  String get mfsiplist => "$dashBoardURL/mf/client_approved_sips";
  String get mfsinglepage => "$dashBoardURL/mf/single_page_sip";
  String get mfsingleorder => "$dashBoardURL/mf/single_page_order_book";
  //  String get mfsingleorder => "$dashBoardURL/mf/single_page_order_book";
  String get mfholdsinlepageapi => "$dashBoardURL/mf/holdings_single_page";
  String get mfholdnewapi => "$dashBoardURL/mf/GetHoldings_mob";
  String get redemptioncancel => "$dashBoardURL/mf/lumsum_redemption_cancel";
  String get sipcancelapiend => "$dashBoardURL/mf/xsip_cancel";
  String get pausesipendpoint => "$dashBoardURL/mf/xsip_pause";

  String get mfallcatnewendpoit => "$dashBoardURL/mf/getCategoryschemes_new";
  String get masterMF => "$dashBoardURL/mf/master_file_datas";
  String get nfoMF => "https://v3.mynt.in/mf/NFO_datas";
  String get searchMF => "https://v3.mynt.in/mf/mfsearch";
  String get mfWatchlist => "$dashBoardURL/mf/watchlist_for_mobile";
  String get factSheetData => "$dashBoardURL/mf/getFactSheetData";
  String get navGraph => "$dashBoardURL/mf/getNavGraph";
  String get factSheetGraph => "$dashBoardURL/mf/getFactSheetGraph";
  String get schemePeers => "$dashBoardURL/mf/getSchemePeers";
  String get postRollingReturn => "$dashBoardURL/mf/postRollingReturn";
  String get bankDetail => "$dashBoardURL/mf/client_bank_details";
  String get mfSip => "$dashBoardURL/mf/sip_values";
  String get mandateDetail => "$newvenketmfurl/order/mandate_details";
  String get lumpsumOrder => "$dashBoardURL/mf/lumsum_purchase";
  String get lumpsumOrderbook => "$dashBoardURL/mf/mf_orderbook";
  String get mandatecreate => "$newvenketmfurl/mandate_creation";
  String get mfXSiporder => "$dashBoardURL/mf/xsip_purchase";
  String get mfXsipcancleRes => "$dashBoardURL/mf/reasons";
  String get mfxsipcancel => "$dashBoardURL/mf/xsip_cancel";
  // String get mfallpayment => "https://v3.mynt.in/mf//all_payment";
  String get mfallpayment => "$dashBoardURL/mf/lumsum_purchase_mob";
  String get topSchemes => "$dashBoardURL/mf/getTopschemes";
  String get redemption => "$dashBoardURL/mf/lumsum_redemption_mob";
  String get etfcategory => "$dashBoardURL/dd/etf-category";

  String get mainfund => 'https://fundapi.mynt.in/api';
  String get clientcheck => '$mainfund/client_check';
  String get bankcheck => '$mainfund/bank_check';

  ///withdraw
  String get fundUpiIdView => 'https://fundapi.mynt.in/withdraw/upi_id_view';
  String get withdraw => 'https://fundapi.mynt.in/withdraw/payout';
  String get paymentwithdraw => 'https://fundapi.mynt.in/withdraw/payment';
  String get withdrawstatus => 'https://fundapi.mynt.in/withdraw/status';
  String get upiIdUpdate => 'https://fundapi.mynt.in/withdraw/upi_id_update';

  String fundvalidatetoken = "https://ws.mynt.in/login/validate_session";

  /////
  String get upimainfund => 'https://fundapi.mynt.in';
  String get fundpayment => "$upimainfund/hdfc/upi/UPItransactionRequest";
  String get fundUpiStatus => "$upimainfund/hdfc/upi/MobileUPIstatus";

  // QR/Wrapper UPI APIs
  String get wrapperUrl => 'https://fundapi.mynt.in/wrapper';
  String get indentUpiRequest => '$wrapperUrl/IndentUPIRequest';
  String get upiCollectRequest => '$wrapperUrl/UPICollectRequest';
  String get wrapperCheckStatus => '$wrapperUrl/check_status';
  String get qrCodeUrl => 'https://copy.mynt.in/get_qr1';

  // Atom gateway
  String get atomUrl => 'https://fundapi.mynt.in/atom';
  String get atomNetBankingRedirect => '$atomUrl/atomredirect';
  String get atomUpiRedirect => '$atomUrl/atomupiredirect';
  String get atomCallback => '$atomUrl/fromatom';

  //hdfc mainurl//
  String get hdfcmainurl => 'https://fundapi.mynt.in/hdfc/upi';
  String get verifyUPI => '$hdfcmainurl/checkClientVPA';
  String get moneytransction => '$hdfcmainurl/transactionRequest';
  String get tranctiontstatus => '$hdfcmainurl/paymentstatus';

  //fund urlss///
  String get viewupiid => 'https://fundapi.mynt.in/withdraw/view_upi_id';
// Bonds
  String get bondBaseURL => "$dashBoardURL/ipo"; // 'https://besim.zebull.in';
  String get getSGB => "$bondBaseURL/getcurrentSGBdetails";
  String get getGSec => "$bondBaseURL/getcurrentNCB_Gsecdetails";
  String get getTBill => "$bondBaseURL/getcurrentNCB_TBilldetails";
  String get getSDL => "$bondBaseURL/getcurrentNCB_SDLdetails";
  String get placeBondOrder => "$bondBaseURL/addNCBtoPortfolio";
  String get getOrderBook => "$bondBaseURL/orderbookncbDetails";

  String get ledgerBaseURL => 'https://rekycbe.mynt.in';
  String get getLedgerBal => "$ledgerBaseURL/all_ledger_balance";

  // ###### Profile All Details  #############
  String get profileDetailsURL => "https://rekycbe.mynt.in/";
  String get detailschangecurrentstatusURL =>
      '$profileDetailsURL/add_mob_email_stat';
  String get profileAllDetailsURL => '$profileDetailsURL/profile';
  String get rekycpendingstatusURL => '$profileDetailsURL/rekyc_pending_details';
  String get checkRekycURL => 'https://ekycbe.mynt.in/zebu/checkrekyc';
  String get cancelPendingesignURL => '${profileDetailsURL}manual_cancel_request';
  String get fetctfileidURL => '$profileDetailsURL/add_mob_email_stat';
  String get fetctfileidURLnominee => '$profileDetailsURL/nom_stat';
  String get nomineeSubmitURL => '$profileDetailsURL/nominee';
  String get addSegmentURL => '${profileDetailsURL}add_segment';
  String get filedownloadURL => '${profileDetailsURL}filedownload';

  // email change
  String get sendOTPEmailURL => '$profileDetailsURL/mail_otpsend';
  String get verifyOTPEmailURL => '$profileDetailsURL/mail_otpverify';
  String get filewriteemailURL => '$profileDetailsURL/file_write_email';

  // mobile no change
  String get mobotpreq => '$profileDetailsURL/mob_otp_req';
  String get mobotpver => '$profileDetailsURL/mob_otp_ver';
  String get filewritemob => '$profileDetailsURL/file_write_mob';

  // KRA image check & upload
  String get checkingImgURL => '${profileDetailsURL}checking_img';
  String get imgUploadURL => '${profileDetailsURL}img_upload';

  // Address change
  String get adrchnURL => '$profileDetailsURL/adr_chn';
  // String get freezeAccount => '$profileDetailsURL/FreezeAccount';
  // String get blockAcct => '$profileDetailsURL/BlockAcct';

  // Bank
  String get bankURL => '$profileDetailsURL/bank';
  // String get freezeAccount => '$profileDetailsURL/FreezeAccount';
  // String get blockAcct => '$profileDetailsURL/BlockAcct';

  // Demat DDPI
  String get allledgerbalanceURL => '$profileDetailsURL/all_ledger_balance';
  String get ddpiURL => '$profileDetailsURL/DDPI';
  // String get blockAcct => '$profileDetailsURL/BlockAcct';

  // MTF
  String get mtfURL => '$profileDetailsURL/mtf';
  String get allLimits => '$ledgerBaseURL/all_limits';
  String get allLimitsMTF => '$ledgerBaseURL/all_limits_MTF';
  String get fundTransfer => '$ledgerBaseURL/FundTransfer';
  // String get freezeAccount => '$profileDetailsURL/FreezeAccount';
  // String get blockAcct => '$profileDetailsURL/BlockAcct';

  // Annual Income
  String get incomeotpreqURL => '$profileDetailsURL/income_otp_req';
  String get incomeotpverURL => '$profileDetailsURL/income_otp_ver';
  String get incomeURL => '$profileDetailsURL/income';
  String get pdfLockURL => '$profileDetailsURL/pdf_lock';
  String get pdfPasswordCheckURL => '$profileDetailsURL/pdf_password_check';

  //Add Famliy
  String get sendlinkrequestURL => '$profileDetailsURL/send_link_request';
  // String get freezeAccount => '$profileDetailsURL/FreezeAccount';
  // String get blockAcct => '$profileDetailsURL/BlockAcct';

  // account closure
  String get checkclosureURL => '$profileDetailsURL/check_closure';
  String get getholdingscheckURL => '$profileDetailsURL/getholdingscheck';
  String get closureURL => '$profileDetailsURL/closure';
  // reportss api

  String get reportsapi => 'https://rekycbe.mynt.in/report/';
  String get reportsapiforcpaction => 'https://v3.mynt.in/ipo/';
  String get reportspledge => 'https://rekycbe.mynt.in/pledge/';
  String get fundforprofile => 'https://fundapi.mynt.in/api/';
  String get caevents => 'https://v3.mynt.in/equity/';
  String get position => 'https://a1.zebuetrade.com/position/';
  String get cmrdownload => 'https://rekycbe.mynt.in/report/cmr';

  /// Trade-journal notes (`journal_notes.py`).
  ///
  /// Composed off [reportsapi] because the `/report` prefix is applied by the
  /// reverse proxy on live, not by Flask — no blueprint declares it. The local
  /// dev server exposes the same routes with no prefix at all, so both the host
  /// and the prefix difference are absorbed here and switching is one flag.
  ///
  /// No trailing slash: paths carry their own leading slash, following
  /// [stockScannerApi]. (The rest of the report family appends `/getLedger` to
  /// a base that already ends in `/`, producing a tolerated `//`.)
  ///
  /// Unlike its report-family siblings this service returns real HTTP status
  /// codes — see `JournalNotesApi`.
  String get journalNotesApi => kJournalNotesUseLocalDev
      ? 'http://localhost:9003/journal'
      : '${reportsapi}journal';

  /// osTicket's client-facing support API.
  ///
  /// Reached through the dispatcher script itself — there is no rewrite rule in
  /// front of it, exactly like the staff API is reached through `scp/api.php`.
  /// Dropping `/api/client.php` and calling `/tickets` directly gets osTicket's
  /// `400 URL not supported`, not a 404.
  ///
  /// The app talks to this host directly. That is safe here in a way the staff
  /// API is not: the credential is a short-lived per-client token obtained from
  /// [supportMintApi] and exchanged at `/auth/exchange`, never a shared service
  /// account. CORS is open on this entry point for exactly that reason.
  ///
  /// No trailing slash: paths carry their own leading slash, following
  /// [journalNotesApi].
  String get supportClientApi => kSupportApiBaseOverride.isNotEmpty
      ? '$kSupportApiBaseOverride/api/client.php'
      : 'https://ticket.mynt.in/api/client.php';



//mf new3
  String get newvenketmfurl => "https://v3.mynt.in/mfapi";
  
  String get mfholdingsnewapi => "$newvenketmfurl/order/holdings";
  String get mfAllHoldingsApi => "$newvenketmfurl/order/All_holdings";
  String get mfDematHoldingsApi => "$newvenketmfurl/order/demat_holdings";
  String get mfnewbestMf => "$newvenketmfurl/dashboard/getMfBaskets";
  String get mfnfoMF => "$newvenketmfurl/dashboard/NFO_datas";
  String get newmfallcatnewendpoit =>
      "$newvenketmfurl/dashboard/getCategoryschemes";
  String get mfnewwatchlist => "$newvenketmfurl/dashboard/watchlist_for_mobile";
  String get mfnewsearch => "$newvenketmfurl/dashboard/mfsearch";
  String get mfGetSchemesByIsins => "$newvenketmfurl/dashboard/get_schemes_by_isins";
  String get mfsinglepageapi => "$newvenketmfurl/singlepage/getFactSheetData";
  String get mfsinglepagechartapi => "$newvenketmfurl/singlepage/getNavGraph";
  String get mforderbookapi => "$newvenketmfurl/singlepage/getNavGraph";
  String get mftemporderlinkget => "$dashBoardURL/mf/payment_gateway_link";
  String get mflumsumorderplacenew => "$newvenketmfurl/order/PlaceLumpsumOrder";
  String get mfallpaymentnew => "$newvenketmfurl/order/all_payment";
  String get mfupipaymentchecknew => "$newvenketmfurl/order/get_payment_status";
  String get mfSipNew => "$newvenketmfurl/order/sip_values";
  String get mfXSipordernew => "$newvenketmfurl/order/xsip_purchase";
  String get lumpsumOrderbooknew => "$newvenketmfurl/order/OrderBook";
  String get mfsingleordernew => "$newvenketmfurl/order/SingleOrderHistory";
  String get mfsiplistnew => "$newvenketmfurl/order/FetchSIP";
  String get mfsipcancelnew => "$newvenketmfurl/order/xsip_cancel";
  String get mfsippausenew => "$newvenketmfurl/order/xsip_pause";
  String get mfredemptionenew => "$newvenketmfurl/order/PlaceRedeemOrder";
  String get mandatecreatenew => "$newvenketmfurl/order/mandate_creation";
  String get allClientBankDetails => "$newvenketmfurl/order/all_client_bank_details";

  String get mfbasketanalysis => "$dashBoardURL/mfbasket/collections/portfolio_store";
  String get mfbaskbacktest => "$dashBoardURL/mfbasket/collections/portfolio_analysis";

  // ===========================================================================
  // StockScanner (read-only stock research backend — FastAPI)
  // TODO: Swap to prod URL when StockScanner backend is hosted publicly.
  //       Assumes PUBLIC_READ_MODE=true on the backend (no API key required).
  // ===========================================================================
  String get stockScannerBaseURL => 'https://agg.zebuetrade.com/scanner';
  String get stockScannerApi => '$stockScannerBaseURL/api/v1';

}
