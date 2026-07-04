import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'dart:typed_data';
import 'package:mynt_plus/models/client_profile_all_details/details_change_current_status_model.dart';
import 'package:mynt_plus/models/client_profile_all_details/profile_all_details_model.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/fund_provider.dart';
import 'package:mynt_plus/screens/Mobile/profile_screen/in_app_webview_screen.dart';

import '../screens/Mobile/profile_screen/profile_main_screen.dart';
import '../sharedWidget/snack_bar.dart';


final profileAllDetailsProvider =
    ChangeNotifierProvider((ref) => ProfileProvider(ref));

class ProfileProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();
  final Preferences pref = locator<Preferences>();
  final Ref ref;
  ProfileProvider(this.ref);

  ProfileAllDetails? _clientAllDetails;
  ProfileAllDetails get clientAllDetails => _clientAllDetails!;
  ProfileAllDetails? get clientAllDetailsSafe => _clientAllDetails;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future fetchClientProfileAllDetails() async {
    _isLoading = true;
    notifyListeners();
    try {
      _clientAllDetails = await api.getClientProfileAllDetailsApi();
      // Debug log of the entire decrypted profile response
      // if (kDebugMode) {
      //   final isClosed =
      //       _clientAllDetails?.clientData?.isClientClosed ?? false;
      //   debugPrint(
      //     '[ProfileDecrypt] clientStatus='
      //     '${isClosed ? 'client_close' : 'not_close'}',
      //   );
      //   final encoded =
      //       jsonEncode(_clientAllDetails?.toJson() ?? <String, dynamic>{});
      //   // Chunked print to avoid Logcat/devtools truncation of large payloads.
      //   const int chunk = 800;
      //   for (int i = 0; i < encoded.length; i += chunk) {
      //     debugPrint(
      //       '[ProfileDecrypt] '
      //       '${encoded.substring(i, i + chunk > encoded.length ? encoded.length : i + chunk)}',
      //     );
      //   }
      // }
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  final allDetailsSectionList = [
    'Personal Info',
    'Bank',
    'Demat',
    'Trading Preference',
    'MTF',
    'Annual Income',
    'Nominee',
    'Family Account',
    'Closure',
  ];

  String _allDetailsSelectedSection = 'Personal Info';
  String get allDetailsSelectedSection => _allDetailsSelectedSection;

  set setAllDetailsSelectedSection(String selectedTab) {
    _allDetailsSelectedSection = selectedTab;
  }

// On Personal Info Tab Section
  final TextEditingController newEmailController = TextEditingController();
  final TextEditingController newEmailOTPController = TextEditingController();

  final TextEditingController newMobController = TextEditingController();
  final TextEditingController newMobOTPController = TextEditingController();

  final TextEditingController newAddressController = TextEditingController();
  final TextEditingController newAddressPincodeController =
      TextEditingController();
  final TextEditingController newAddressDistrictController =
      TextEditingController();
  final TextEditingController newAddressStateController =
      TextEditingController();
  final TextEditingController newAddressCountryController =
      TextEditingController();
  final TextEditingController newAddressProofTypeController =
      TextEditingController();

// On Bank Tab Section
  final TextEditingController newBankAccController = TextEditingController();
  final TextEditingController newBankIFSCController = TextEditingController();
  bool selectedBankTypeValue = false;
  String? selectedBankProofTypeValue;

// On Annual Income Tab Section
  final List<String> annualIncomeRangeList = [
    'Below 1L',
    '1L to 5L',
    '5L to 10L',
    '10L to 25L',
    'Above 25L'
  ];
  final int selectedAnnualIncomeRangeValue = 1;
  final TextEditingController newIncomeOTPController = TextEditingController();

// On Account Closure Tab Section
  String? selectedAccountClosureReasonValue;

  final TextEditingController closureDPIDController = TextEditingController();
  final TextEditingController closureBOIDController = TextEditingController();

// On family Account Tab Section
  final TextEditingController newFamilyMemberIDController =
      TextEditingController();
  final TextEditingController newFamilyRelationshipController =
      TextEditingController();
  final TextEditingController newFamilyPANController = TextEditingController();
  final TextEditingController newFamilyMobController = TextEditingController();

  String? _responseval = "";
  String? get responseval => _responseval;

  String? _emilotpres = "";
  String? get emilotpres => _emilotpres;

  String? _mobileotpo = "";
  String? get mobileotp => _mobileotpo;

  String? _mobileotpverres = "";
  String? get mobileotpverres => _mobileotpverres;

  String? _manualaddbank = "";
  String? get manualaddbank => _manualaddbank;

  String? _ddpiledgerbalace = "";
  String? get ddpiledgerbalace => _ddpiledgerbalace;

  final String _ddpiesignfile = "";
  String? get ddpiesignfile => _ddpiesignfile;

  final String _mtfenabrespoce = "";
  String? get mtfenabrespoce => _mtfenabrespoce;

  String? _imcomeptsenres = "";
  String? get imcomeptsenres => _imcomeptsenres;

  final String _incomeotpverres = "";
  String? get incomeotpverres => _incomeotpverres;

  final String _incomupdaqres = "";
  String? get incomupdaqres => _incomupdaqres;

  String? _ifsccoderess = "";
  String? get ifsccoderess => _ifsccoderess;

  final String _banksumbres = "";
  String? get banksumbres => _banksumbres;

  final String _familyaccress = "";
  String? get familyaccress => _familyaccress;

  Map<String, dynamic> _chackaccbalace = {};
  Map<String, dynamic> get chackaccbalace => _chackaccbalace;
  clearProfilePop(BuildContext context, String type) {
    if (type == "email") {
      _responseval = "";
    }
    if (type == "emailotp") {
      _emilotpres = "";
    }
    if (type == "mobile") {
      _mobileotpo = "";
    }

    if (type == "mobilotp") {
      _mobileotpverres = "";
    }

    if (type == "manbank") {
      _manualaddbank = "";
    }
    if (type == "ddpibalace") {
      _ddpiledgerbalace = "";
    }
    if (type == "incomeotpres") {
      _imcomeptsenres = "";
    }

    if (type == "bankifsc") {
      _ifsccoderess = "";
    }
    if (type == "accclose") {
      _chackaccbalace = {};
    }
  }

  validateChnageEmail() {}

  formateDataToDisplay(String data, int firstPart, int lastPart) {
    if (data.length > 1) {
      int remaining = data.length - lastPart;
      return "${data.substring(0, firstPart)} ********* ${data.substring(remaining)}";
    } else {
      return "";
    }
    // profileprovider.clientAllDetails.bankData![index].bankAcNo?.length - 4 ;
  }

// void downloadFile(String url) {
//    html.AnchorElement anchorElement =  new html.AnchorElement(href: url);
//    anchorElement.download = url;
//    anchorElement.click();
// }

  void openInWebURL(BuildContext context, String urlArgs) async {
    await ref.read(fundProvider).fetchHstoken(context);
    String url = 'https://profile.mynt.in/$urlArgs/?sAccountId=${pref.clientId}&sToken=${ref.read(fundProvider).fundHstoken!.hstk}';
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InAppWebViewScreen(url: url),
      ),
    );
  }
  void openInWebURLWithbank(BuildContext context, String urlArgs, String type, String bankAcNo) async {
    await ref.read(fundProvider).fetchHstoken(context);
    String url = 'https://profile.zebuetrade.com/$urlArgs/?uid=${pref.clientId}&token=${pref.token}&type=$type&acno=$bankAcNo&src=mobileapp';
    
     Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => InAppWebViewScreen(url: url),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  void openInWebURLk(BuildContext context, String urlArgs, String type) async {
    await ref.read(fundProvider).fetchHstoken(context);
    String url = 'https://profile.zebuetrade.com/$urlArgs/?uid=${pref.clientId}&token=${pref.token}&type=$type&src=mobileapp';
     Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => InAppWebViewScreen(url: url),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  // void openInWebURLtest(
  //     BuildContext context, String urlArgs, String type) async {
  //   await ref.read(fundProvider).fetchHstoken(context);

  //   // debugPrint(
  //   //     '$urlArgs  ==== ${pref.clientId} =====  ${ref.read(fundProvider).fundHstoken!.hstk}');
  //   String url =
  //       'http://192.168.5.148:8080/${urlArgs}?uid=${pref.clientId}&token=${pref.token}&type=${type}&src=mobileapp';
  //   debugPrint('weburl ::: $url');
  //   Navigator.push(
  //     context,
  //     PageRouteBuilder(
  //       pageBuilder: (_, __, ___) => InAppWebViewScreen(url: url),
  //       transitionsBuilder: (_, animation, __, child) {
  //         return SlideTransition(
  //           position: Tween<Offset>(
  //             begin: const Offset(-1.0, 0.0),
  //             end: Offset.zero,
  //           ).animate(animation),
  //           child: child,
  //         );
  //       },
  //     ),
  //   );
  // }

  List<PendingStatus> _pendingStatusList = [];
  List<PendingStatus> get pendingStatusList => _pendingStatusList;
  
  Future fetchPendingstatus() async {
    try {
      PendingStatus response = await api.fetchPendingstatusApi();
      _pendingStatusList = [response];
      notifyListeners();
    } 
    catch (e) {
    } finally {
      notifyListeners();
    }
    }
    bool _cancelpendingloader = false;
    bool get cancelpendingloader => _cancelpendingloader;
    cancelPendingloader(bool value){
      _cancelpendingloader = value;
      notifyListeners();
    }

  Future cancelPendingStatus(String type, BuildContext context) async {
    try {
      cancelPendingloader(true);
      String? fileid = await api.fetctfileidapi(type);
      String response = await api.cancelPendingStatusApi(type, fileid ?? "");
      Navigator.pop(context);
      if(response == "Cancel Success"){
      _pendingStatusList = [];
      fetchPendingstatus();
      successMessage(context, "Esign Cancellation Success");
      notifyListeners();
      }else{
        warningMessage(context, "Esign Cancellation Failed");
      }
    } catch (e) {
      warningMessage(context, "Something Went Wrong");
    } finally {
      cancelPendingloader(false);
      notifyListeners();
    }
  }



  // ─── Segment Change Status ───
  DetailsChangeCurrentStatus? _mobEmailStatus;
  DetailsChangeCurrentStatus? get mobEmailStatus => _mobEmailStatus;

  // True until the first /add_mob_email_stat response arrives. Used by the UI to show a loader
  bool _mobEmailStatusLoading = true;
  bool get mobEmailStatusLoading => _mobEmailStatusLoading;

  bool _segmentSubmitting = false;
  bool get segmentSubmitting => _segmentSubmitting;

  Future fetchMobEmailStatus() async {
    _mobEmailStatusLoading = true;
    notifyListeners();
    try {
      _mobEmailStatus = await api.fetchMobEmailStatusApi();
    } catch (e) {
    } finally {
      _mobEmailStatusLoading = false;
      notifyListeners();
    }
  }

  // ─── Re-KYC status (Personal Info gate) ───
  // the raw 'Yes'/'No' string. Email/Mobile edits are blocked when == 'Yes'.
  String _rekycStatus = '';
  String get rekycStatus => _rekycStatus;

  Future fetchRekycStatus() async {
    _rekycStatus = '';
    try {
      final status = await api.checkRekycStatusApi();
      _rekycStatus = status ?? '';
    } catch (_) {
      _rekycStatus = '';
    } finally {
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> submitSegmentChange({
    required List<String> newSegments,
    required List<String> existingSegments,
    required String addingSegments,
    required String reActiveSegments,
    required bool equitySelected,
    required bool fnoSelected,
    required bool currencySelected,
    required bool commoditySelected,
    Uint8List? proofBytes,
    String? proofFileName,
    required String passwordRequired,
    required String password,
  }) async {
    _segmentSubmitting = true;
    notifyListeners();
    try {
      final clientData = _clientAllDetails?.clientData;
      final result = await api.addSegmentApi(
        newSegments: newSegments,
        existingSegments: existingSegments,
        dpCode: clientData?.cLIENTDPCODE ?? '',
        addingSegments: addingSegments,
        reActiveSegments: reActiveSegments,
        clientId: pref.clientId ?? '',
        equitySelected: equitySelected,
        fnoSelected: fnoSelected,
        currencySelected: currencySelected,
        commoditySelected: commoditySelected,
        clientEmail: clientData?.cLIENTIDMAIL ?? '',
        clientName: clientData?.cLIENTNAME ?? '',
        address: clientData?.cLRESIADD1 ?? '',
        proofBytes: proofBytes,
        proofFileName: proofFileName,
        passwordRequired: passwordRequired,
        password: password,
      );
      await fetchMobEmailStatus();
      return result;
    } catch (e) {
      return null;
    } finally {
      _segmentSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> reportFiledownload({
    required String fileId,
    required String response,
    required String type,
  }) async {
    try {
      await api.filedownloadApi(
        clientId: pref.clientId ?? '',
        fileId: fileId,
        response: response,
        type: type,
      );
      await fetchMobEmailStatus();
    } catch (e) {
    }
  }

  Future emaileotpfun(String newEmail, String oldEmail, String clientName,
      String dpcode) async {
    try {
      String response = await api.sendOTPtoChangeEmailApi(
          newEmail, oldEmail, clientName, dpcode);
      // _mobileotpo = response;
      notifyListeners();

    } finally {
      notifyListeners();
    }
  }

  Future emailotpres(String otpres, String newemail) async {
    try {
      String response = await api.verifyOTPtoChangeEmailApi(otpres, newemail);
      // _emilotpres = response;
      notifyListeners();

    } finally {
      notifyListeners();
    }
  }

  Future<String?> mobileotpfun(
      String newmo, String clemail, String oldmobilmo, fulldataprf) async {
    try {
      String response =
          await api.mobileotpapifun(newmo, clemail, oldmobilmo, fulldataprf);
      // _mobileotpo = response;
      notifyListeners();
      return response;
    } catch (e) {
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future mobileotpverify(String newmo, String mbotp, fulldataprf) async {
    try {
      String response = await api.mobileotpverify(newmo, mbotp, fulldataprf);
      // _mobileotpverres = response;
      notifyListeners();

    } catch (e) {
      // debugPrint("$e");
    } finally {
      notifyListeners();
    }
  }

  Future addmanbankverf(String newadd, String pincoderes, String dist,
      String state, String county, String profty, fulldataprf, filepath) async {
    try {
      String response = await api.manaddbankapi(newadd, pincoderes, dist, state,
          county, profty, fulldataprf, filepath);
      // _manualaddbank = response;
      notifyListeners();

    } catch (e) {
      // debugPrint("$e");
    } finally {
      notifyListeners();
    }
  }

  Future<dynamic> ddpiledgerbaapi() async {
    try {
      var response = await api.ledgerbalanceapi();
      notifyListeners();
      return response;
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, dynamic>?> ddpifinalstep(fulldataprf) async {
    try {
      var response = await api.finalddpisubmitapi(fulldataprf);
      notifyListeners();
      return response is Map<String, dynamic> ? response : null;
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> mtfenbprovi(fulldataprf) async {
    try {
      final response = await api.mtfenabapipage(fulldataprf);
      notifyListeners();
      return response;
    } catch (e) {
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<String?> incomeotpsenpro(mobilno) async {
    try {
      String response = await api.incomeotesendapi(mobilno);
      notifyListeners();
      return response;
    } catch (e) {
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<String?> incomeotpverpro(otpno, fulldataprf, chipval,
      {List<int>? fileBytes, String? fileName, String? proftye}) async {
    try {
      String response = await api.incomeotpverfapi(
          otpno, fulldataprf, chipval, "", proftye ?? "");
      notifyListeners();
      if (response == "otp valid") {
        // Submit income update after OTP verified
        final result = await api.incomeupdateaapi(
          fulldataprf, chipval, proftye ?? "",
          fileBytes: fileBytes, fileName: fileName,
        );
        await fetchMobEmailStatus();
        return result?['msg'];
      }
      return response;
    } catch (e) {
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<dynamic> pdfLockCheck({required List<int> fileBytes, required String fileName}) async {
    try {
      return await api.pdfLockCheckApi(fileBytes: fileBytes, fileName: fileName);
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> pdfPasswordCheck({
    required List<int> fileBytes,
    required String fileName,
    required String password,
  }) async {
    try {
      return await api.pdfPasswordCheckApi(
        fileBytes: fileBytes, fileName: fileName, password: password,
      );
    } catch (e) {
      return null;
    }
  }

  // ─── Web: Mobile OTP verify only (no auto file_write) ───
  Future<String?> mobileOtpVerifyWeb(String newMobile, String otp, dynamic clientData) async {
    try {
      return await api.mobileOtpVerifyWebApi(newMobile, otp, clientData);
    } catch (e) {
      return null;
    }
  }

  // ─── Web: Email OTP verify only (no auto file_write) ───
  Future<String?> emailOtpVerifyWeb(String otp, String newEmail) async {
    try {
      return await api.emailOtpVerifyWebApi(otp, newEmail);
    } catch (e) {
      return null;
    }
  }

  // ─── Web: Mobile file write ───
  Future<Map<String, dynamic>?> mobileFileWriteWeb(String newMobile, dynamic clientData) async {
    try {
      final result = await api.mobileFileWriteWebApi(newMobile, clientData);
      if (result != null && result['fileid'] != null) {
        await fetchMobEmailStatus();
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  // ─── Web: Email file write ───
  Future<Map<String, dynamic>?> emailFileWriteWeb(String newEmail, String oldEmail, String dpCode) async {
    try {
      final result = await api.emailFileWriteWebApi(newEmail, oldEmail, dpCode);
      if (result != null && result['fileid'] != null) {
        await fetchMobEmailStatus();
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  // ─── KRA Image Check ───
  Future<bool> kraImageCheck() async {
    try {
      return await api.kraImageCheckApi();
    } catch (e) {
      return false;
    }
  }

  // ─── KRA Image Upload ───
  Future<String?> uploadKraSelfie({required List<int> imageBytes}) async {
    try {
      return await api.imgUploadApi(imageBytes: imageBytes);
    } catch (e) {
      return null;
    }
  }

  Future ifscapiporov(String ifsccode) async {
    try {
      String response = await api.ifsccodecheckapi(ifsccode);
      notifyListeners();
    } catch (e) {
      // debugPrint("$e");
    } finally {
      notifyListeners();
    }
  }

  // IFSC lookup returning full data
  Future<Map<String, dynamic>?> ifscLookup(String ifscCode) async {
    try {
      return await api.ifscLookupApi(ifscCode);
    } catch (e) {
      return null;
    }
  }

  // Pincode lookup
  Future<Map<String, dynamic>?> pincodeLookup(String pincode) async {
    try {
      return await api.pincodeLookupApi(pincode);
    } catch (e) {
      return null;
    }
  }

  // Address change web
  Future<Map<String, dynamic>?> addressChangeWeb({
    required String newAddress,
    required String pincode,
    required String district,
    required String state,
    required String country,
    required String proofType,
    List<int>? proofBytes,
    String? proofFileName,
  }) async {
    try {
      final clientData = clientAllDetails.clientData;
      if (clientData == null) return null;

      final result = await api.addressChangeApiWeb(
        newAddress: newAddress,
        pincode: pincode,
        district: district,
        state: state,
        country: country,
        proofType: proofType,
        clientData: clientData,
        proofBytes: proofBytes,
        proofFileName: proofFileName,
      );

      if (result != null) {
        await fetchMobEmailStatus();
        await fetchClientProfileAllDetails();
      }

      return result;
    } catch (e) {
      return null;
    } finally {
      notifyListeners();
    }
  }

  // Aadhaar/Digilocker address change
  Future<Map<String, dynamic>?> addressChangeDigilocker({
    required String code,
    required String state,
  }) async {
    try {
      final clientData = clientAllDetails.clientData;
      if (clientData == null) return null;

      final result = await api.addressChangeDigilockerApiWeb(
        code: code,
        state: state,
        clientData: clientData,
      );

      if (result != null) {
        await fetchMobEmailStatus();
        await fetchClientProfileAllDetails();
      }

      return result;
    } catch (e) {
      return null;
    } finally {
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  NOMINEE
  // ═══════════════════════════════════════════════════════════════

  Map<String, dynamic>? _nomineeStatus;
  Map<String, dynamic>? get nomineeStatus => _nomineeStatus;

  /// Nominee status data from nom_stat[0]
  Map<String, dynamic>? get nomineeStatusData {
    if (_nomineeStatus == null) return null;
    final nomStat = _nomineeStatus!['nom_stat'];
    if (nomStat is List && nomStat.isNotEmpty) {
      return nomStat[0] as Map<String, dynamic>;
    }
    return null;
  }

  /// Whether nominee account is active (can modify)
  bool get isNomineeActive => _nomineeStatus?['acc_sgt_atve_sts'] == 'active';

  /// Fetch nominee status from /nom_stat
  Future<void> fetchNomineeStatus() async {
    try {
      _nomineeStatus = await api.nomineeStatusApi();
      notifyListeners();
    } catch (e) {
    }
  }

  /// Submit nominee form to /nominee
  Future<Map<String, dynamic>?> submitNominee({
    required Map<String, String> fields,
    Map<String, ({String filename, Uint8List bytes})>? files,
  }) async {
    try {
      final result = await api.nomineeSubmitApi(fields: fields, files: files);
      if (result != null && result['msg'] == 'Success') {
        await fetchNomineeStatus();
        await fetchClientProfileAllDetails();
      }
      return result;
    } catch (e) {
      return null;
    } finally {
      notifyListeners();
    }
  }

  // Build existing banks list for API
  List<Map<String, String>> _buildExistingBanksList() {
    final banks = clientAllDetails.bankData ?? [];
    return banks.map((b) => {
      'acc_no': b.bankAcNo ?? '',
      'ifsc_no': b.iFSCCode ?? '',
    }).toList();
  }

  // Web bank operations (add/edit/delete/set-primary)
  Future<Map<String, dynamic>?> addBankWeb({
    required String option,
    required String accountNo,
    required String bankName,
    required String ifsc,
    required String branch,
    required String bankAccountType,
    required String setDefault,
    required String micr,
    String? proffType,
    List<int>? proofBytes,
    String? proofFileName,
    String? passwordRequired,
    String? password,
  }) async {
    try {
      final clientData = clientAllDetails.clientData;
      if (clientData == null) return null;

      final result = await api.addBankApiWeb(
        option: option,
        accountNo: accountNo,
        bankName: bankName,
        ifsc: ifsc,
        branch: branch,
        bankAccountType: bankAccountType,
        setDefault: setDefault,
        micr: micr,
        dpCode: clientData.cLIENTDPCODE ?? '',
        mobile: clientData.mOBILENO ?? '',
        clientEmail: clientData.cLIENTIDMAIL ?? '',
        existingBanks: _buildExistingBanksList(),
        proffType: proffType,
        proofBytes: proofBytes,
        proofFileName: proofFileName,
        passwordRequired: passwordRequired,
        password: password,
      );

      if (result != null && !result.containsKey('msg')) {
        // Success - refresh data
        await fetchMobEmailStatus();
        await fetchClientProfileAllDetails();
      }

      return result;
    } catch (e) {
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future addbankprovui(
      String banacc,
      String bankifc,
      String filepath,
      String profftype,
      String setpri,
      String accty,
      fulldataprf,
      bankdata) async {
    try {
      String response = await api.addbankapi(banacc, bankifc, filepath,
          profftype, setpri, accty, fulldataprf, bankdata);
      // _banksumbres = response;
      notifyListeners();

    } catch (e) {
      // debugPrint("$e");
    } finally {
      notifyListeners();
    }
  }

  Future addfamilaccprov(String menid, String relation, String menpan,
      String mobilno, fulldataprf) async {
    try {
      String response = await api.addfamilaccapi(
          menid, relation, menpan, mobilno, fulldataprf);
      // _banksumbres = response;
      notifyListeners();

    } catch (e) {
      // debugPrint("$e");
    } finally {
      notifyListeners();
    }
  }

  Future<dynamic> closeaccnalprov(String resaqon, fulldataprf) async {
    try {
      dynamic chackaccbalace = await api.closeacbalapi(resaqon, fulldataprf);
      notifyListeners();
      return chackaccbalace;
    } catch (e) {
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<dynamic> closeaccfinalspro(String dpid, String boid, String filepath,
      String reason, fulldataprf, bankdata,
      {bool hasHoldings = false,
      Uint8List? fileBytes,
      String? fileName}) async {
    try {
      dynamic chackaccClosureResp = await api.acccloserapi(
          dpid, boid, filepath, reason, fulldataprf, bankdata,
          hasHoldings: hasHoldings,
          fileBytes: fileBytes,
          fileName: fileName);
      notifyListeners();
      return chackaccClosureResp;
    } catch (e) {
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> checkHoldingsForClosure() async {
    try {
      final resp = await api.holdingsapiceckapi();
      notifyListeners();
      return resp;
    } catch (e) {
      return null;
    }
  }
}
