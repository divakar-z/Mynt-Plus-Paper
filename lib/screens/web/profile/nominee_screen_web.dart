import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/provider/profile_all_details_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import 'package:mynt_plus/utils/digio_esign.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NomineeScreenWeb extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const NomineeScreenWeb({super.key, this.onBack});

  @override
  ConsumerState<NomineeScreenWeb> createState() => _NomineeScreenWebState();
}

class _NomineeScreenWebState extends ConsumerState<NomineeScreenWeb> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _esignLoading = false;

  // Nominee choice: 'yes' = add nominees, 'no' = opt out
  String? _yesOrNo;

  // Active nominee panel (0, 1, 2)
  int _activePanel = 0;
  int _nomineeCount = 1; // 1, 2, or 3

  // Pincode loader - fetching city/state/country.
  final Set<TextEditingController> _pincodeLoading = {};

  // Nominee status from /nom_stat
  bool _hasExistingNominee = false;
  bool _esignPending = false;
  bool _esignCompleted = false;
  // True once user has completed Digio e-sign for the current change request;
  bool _esignRequestInProcess = false;
  String? _fileId;
  String? _esignEmail;
  String? _esignSession;

  String _esignPrefKey() =>
      'nominee_esigned_${locator<Preferences>().clientId ?? ""}';

  // ── Nominee 1 Fields ──
  final _name1 = TextEditingController();
  final _percent1 = TextEditingController(text: '100');
  DateTime? _dob1;
  String? _relation1;
  bool _sameAddress1 = false;
  final _address1 = TextEditingController();
  final _city1 = TextEditingController();
  final _state1 = TextEditingController();
  final _country1 = TextEditingController(text: 'India');
  final _pincode1 = TextEditingController();
  final _mobile1 = TextEditingController();
  final _email1 = TextEditingController();
  String? _proofType1;
  final _proofValue1 = TextEditingController();

  // ── Nominee 2 Fields ──
  final _name2 = TextEditingController();
  final _percent2 = TextEditingController();
  DateTime? _dob2;
  String? _relation2;
  bool _sameAddress2 = false;
  final _address2 = TextEditingController();
  final _city2 = TextEditingController();
  final _state2 = TextEditingController();
  final _country2 = TextEditingController(text: 'India');
  final _pincode2 = TextEditingController();
  final _mobile2 = TextEditingController();
  final _email2 = TextEditingController();
  String? _proofType2;
  final _proofValue2 = TextEditingController();

  // ── Nominee 3 Fields ──
  final _name3 = TextEditingController();
  final _percent3 = TextEditingController();
  DateTime? _dob3;
  String? _relation3;
  bool _sameAddress3 = false;
  final _address3 = TextEditingController();
  final _city3 = TextEditingController();
  final _state3 = TextEditingController();
  final _country3 = TextEditingController(text: 'India');
  final _pincode3 = TextEditingController();
  final _mobile3 = TextEditingController();
  final _email3 = TextEditingController();
  String? _proofType3;
  final _proofValue3 = TextEditingController();

  // ── Guardian Fields (for minor nominees) ──
  final _guardianName1 = TextEditingController();
  DateTime? _guardianDob1;
  String? _guardianRelation1;
  final _guardianAddress1 = TextEditingController();
  final _guardianPincode1 = TextEditingController();
  final _guardianCity1 = TextEditingController();
  final _guardianState1 = TextEditingController();
  final _guardianCountry1 = TextEditingController();

  final _guardianName2 = TextEditingController();
  DateTime? _guardianDob2;
  String? _guardianRelation2;
  final _guardianAddress2 = TextEditingController();
  final _guardianPincode2 = TextEditingController();
  final _guardianCity2 = TextEditingController();
  final _guardianState2 = TextEditingController();
  final _guardianCountry2 = TextEditingController();

  final _guardianName3 = TextEditingController();
  DateTime? _guardianDob3;
  String? _guardianRelation3;
  final _guardianAddress3 = TextEditingController();
  final _guardianPincode3 = TextEditingController();
  final _guardianCity3 = TextEditingController();
  final _guardianState3 = TextEditingController();
  final _guardianCountry3 = TextEditingController();

  // ── Court-appointed guardian proof (PDF, max 5 MB) ──
  // Only required when nominee is minor AND guardian relation == COURT-APPOINTED GUARDIAN.
  PlatformFile? _guardianDocFile1;
  PlatformFile? _guardianDocFile2;
  PlatformFile? _guardianDocFile3;
  static const int _guardianDocMaxBytes = 5 * 1024 * 1024;

  bool _needsGuardianDoc(DateTime? dob, String? relation) =>
      _isMinor(dob) && relation == 'COURT-APPOINTED GUARDIAN';

  static const _relations = [
    'MOTHER', 'FATHER', 'BROTHER', 'SISTER', 'DAUGHTER',
    'WIFE', 'HUSBAND', 'SON', 'GRAND-SON', 'GRAND-FATHER',
    'GRAND-DAUGHTER', 'GRAND-MOTHER', 'FRIEND',
  ];

  static const _guardianRelations = [
    'MOTHER', 'FATHER', 'BROTHER', 'SISTER', 'DAUGHTER',
    'WIFE', 'HUSBAND', 'SON', 'GRAND-SON', 'GRAND-FATHER',
    'GRAND-DAUGHTER', 'GRAND-MOTHER', 'COURT-APPOINTED GUARDIAN',
  ];

  static const _proofTypes = [
    'PAN Number',
    'Aadhaar number(last 4 digits)',
    'Driving Licence Number',
  ];

  bool _isMinor(DateTime? dob) {
    if (dob == null) return false;
    final age = DateTime.now().difference(dob).inDays / 365.25;
    return age < 18;
  }

  /// Guardian DOB >> when picked DOB is < 18 it clears only the DOB field
  ValueChanged<DateTime?> _onGuardianDobChanged(int slot) {
    return (DateTime? picked) {
      DateTime? next = picked;
      if (picked != null && _isMinor(picked)) {
        warningMessage(context, 'Guardian must be above age 18');
        next = null;
      }
      setState(() {
        if (slot == 1) {
          _guardianDob1 = next;
        } else if (slot == 2) {
          _guardianDob2 = next;
        } else if (slot == 3) {
          _guardianDob3 = next;
        }
      });
    };
  }

  PlatformFile? _guardianDocForSlot(int slot) {
    switch (slot) {
      case 1: return _guardianDocFile1;
      case 2: return _guardianDocFile2;
      case 3: return _guardianDocFile3;
    }
    return null;
  }

  void _setGuardianDocForSlot(int slot, PlatformFile? file) {
    setState(() {
      switch (slot) {
        case 1: _guardianDocFile1 = file; break;
        case 2: _guardianDocFile2 = file; break;
        case 3: _guardianDocFile3 = file; break;
      }
    });
  }

  Future<void> _pickGuardianDoc(int slot) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final ext = (file.extension ?? '').toLowerCase();
    if (ext != 'pdf') {
      if (mounted) warningMessage(context, 'Only PDF files are allowed');
      return;
    }
    if (file.size > _guardianDocMaxBytes) {
      if (mounted) warningMessage(context, 'File size must be 5 MB or less');
      return;
    }
    _setGuardianDocForSlot(slot, file);
  }

  /// Returns the tooltip message when the nominee section is not editable,
  /// or `null` when edits/additions are allowed.

  /// - account closed       → `clientData.isClientClosed`
  /// - non-individual       → `clientData.isIndividual == false`
  /// - inactive segment     → `mobStatus.accSgtAtveSts != 'active'`
  /// - within 7 days        → `mobStatus.last7DaysCheck != true`
  String? _editDisabledReason() {
    final provider = ref.watch(profileAllDetailsProvider);
    final mobStatus = provider.mobEmailStatus;
    final clientData = provider.clientAllDetailsSafe?.clientData;

    // Profile data hasn't finished loading yet — don't block the user
    // pre-emptively, since we can't know which gate (if any) actually applies.
    // The user couldn't have changed anything yet either way.
    if (mobStatus == null || clientData == null) return null;

    if (clientData.isClientClosed) {
      return 'Your trading account is closed.';
    }
    if (!clientData.isIndividual) {
      return "Non-individual accounts can't modify data here. "
          "Please contact support at (+91) 93 8010 8010 for help.";
    }
    if ((mobStatus.accSgtAtveSts ?? '').toLowerCase() != 'active') {
      return 'Modification not allowed for inactive client codes. '
          'Please reactivate the account.';
    }
    if (mobStatus.last7DaysCheck != true) {
      return 'Modification request not allowed within 7 days of activation';
    }
    return null;
  }

  Widget _gatedTooltip(Widget child, String? reason) {
    if (reason == null) return child;
    return Tooltip(message: reason, child: child);
  }

  String _proofTypeToApiKey(String? type) {
    switch (type) {
      case 'PAN Number':
        return 'PAN';
      case 'Aadhaar number(last 4 digits)':
        return 'AADHAR';
      case 'Driving Licence Number':
        return 'PROOF OF IDENTITY';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNomineeStatus();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name1, _percent1, _address1, _city1, _state1, _country1, _pincode1,
      _mobile1, _email1, _proofValue1,
      _name2, _percent2, _address2, _city2, _state2, _country2, _pincode2,
      _mobile2, _email2, _proofValue2,
      _name3, _percent3, _address3, _city3, _state3, _country3, _pincode3,
      _mobile3, _email3, _proofValue3,
      _guardianName1, _guardianAddress1, _guardianPincode1,
      _guardianCity1, _guardianState1, _guardianCountry1,
      _guardianName2, _guardianAddress2, _guardianPincode2,
      _guardianCity2, _guardianState2, _guardianCountry2,
      _guardianName3, _guardianAddress3, _guardianPincode3,
      _guardianCity3, _guardianState3, _guardianCountry3,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadNomineeStatus() async {
    setState(() => _loading = true);
    final provider = ref.read(profileAllDetailsProvider);
    await provider.fetchNomineeStatus();
    if (!mounted) return;

    final statusData = provider.nomineeStatusData;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    // Restore the "in process" flag persisted at e-sign time.
    final bool inProcess = prefs.getBool(_esignPrefKey()) ?? false;

    if (statusData != null) {
      final appStatus = statusData['app_status']?.toString() ?? '';
      final name1 = statusData['nominee1_name']?.toString() ?? '';
      final fileId = statusData['file_id']?.toString() ?? '';

      setState(() {
        _hasExistingNominee = name1.isNotEmpty;
        _esignPending = appStatus == 'e-signed pending' && !inProcess;
        _esignCompleted = appStatus == 'e-signed completed';
        _esignRequestInProcess = inProcess;
        _fileId = fileId.isEmpty ? null : fileId;
        _esignEmail = statusData['client_email']?.toString();
        _esignSession = statusData['session']?.toString();

        // Populate existing nominee data (read-only display)
        if (_hasExistingNominee) {
          _name1.text = name1;
          _relation1 = statusData['nominee1_relation']?.toString();
          _percent1.text = statusData['nominee1_percentage']?.toString() ?? '';
          final dob1Str = statusData['nominee1_DOB']?.toString() ?? '';
          if (dob1Str.isNotEmpty) {
            try { _dob1 = DateFormat('yyyy-MM-dd').parse(dob1Str); } catch (_) {}
          }

          // Nominee 2
          final name2 = statusData['nominee2_name']?.toString() ?? '';
          if (name2.isNotEmpty) {
            _nomineeCount = _nomineeCount < 2 ? 2 : _nomineeCount;
            _name2.text = name2;
            _relation2 = statusData['nominee2_relation']?.toString();
            _percent2.text = statusData['nominee2_percentage']?.toString() ?? '';
            final dob2Str = statusData['nominee2_DOB']?.toString() ?? '';
            if (dob2Str.isNotEmpty) {
              try { _dob2 = DateFormat('yyyy-MM-dd').parse(dob2Str); } catch (_) {}
            }
          }

          // Nominee 3
          final name3 = statusData['nominee3_name']?.toString() ?? '';
          if (name3.isNotEmpty) {
            _nomineeCount = 3;
            _name3.text = name3;
            _relation3 = statusData['nominee3_relation']?.toString();
            _percent3.text = statusData['nominee3_percentage']?.toString() ?? '';
            final dob3Str = statusData['nominee3_DOB']?.toString() ?? '';
            if (dob3Str.isNotEmpty) {
              try { _dob3 = DateFormat('yyyy-MM-dd').parse(dob3Str); } catch (_) {}
            }
          }
        }
      });
    }

    // Fallback: if nom_stat didn't have nominee data, use profile API data
    if (!_hasExistingNominee) {
      final clientData = provider.clientAllDetailsSafe?.clientData;
      if (clientData != null) {
        final nomName = clientData.nomineeName ?? '';
        if (nomName.isNotEmpty) {
          setState(() {
            _hasExistingNominee = true;
            _name1.text = nomName;
            _relation1 = clientData.nomineeRelation?.toUpperCase();
            _percent1.text = '100';
            final nomDob = clientData.nomineeDOB ?? '';
            if (nomDob.isNotEmpty) {
              try { _dob1 = DateFormat('dd/MM/yyyy').parse(nomDob); } catch (_) {
                try { _dob1 = DateFormat('yyyy-MM-dd').parse(nomDob); } catch (_) {}
              }
            }
            _mobile1.text = clientData.nomineePhone ?? '';
            _address1.text = clientData.nomineeAddress ?? '';
          });
        }
      }
    }

    setState(() => _loading = false);
  }

  Future<void> _submitNominee() async {
    if (_editDisabledReason() != null) return;
    if (_yesOrNo == 'yes') {
      // Trigger form field validation (text fields, dropdowns)
      if (!(_formKey.currentState?.validate() ?? false)) {
        warningMessage(context, 'Please fill all required fields correctly');
        return;
      }

      // Validate DOB selections (not covered by TextFormField validators)
      if (_dob1 == null) {
        warningMessage(context, 'Please select date of birth for nominee 1');
        return;
      }
      if (_nomineeCount >= 2 && _dob2 == null) {
        warningMessage(context, 'Please select date of birth for nominee 2');
        return;
      }
      if (_nomineeCount >= 3 && _dob3 == null) {
        warningMessage(context, 'Please select date of birth for nominee 3');
        return;
      }

      // Validate guardian DOB for minor nominees
      if (_isMinor(_dob1) && _guardianDob1 == null) {
        warningMessage(context, 'Please select guardian date of birth for nominee 1');
        return;
      }
      if (_nomineeCount >= 2 && _isMinor(_dob2) && _guardianDob2 == null) {
        warningMessage(context, 'Please select guardian date of birth for nominee 2');
        return;
      }
      if (_nomineeCount >= 3 && _isMinor(_dob3) && _guardianDob3 == null) {
        warningMessage(context, 'Please select guardian date of birth for nominee 3');
        return;
      }

      // Block submission if guardian DOB is under 18
      final guardianDobs = [_guardianDob1, _guardianDob2, _guardianDob3];
      final nomineeDobs = [_dob1, _dob2, _dob3];
      for (var i = 0; i < _nomineeCount; i++) {
        if (_isMinor(nomineeDobs[i]) && _isMinor(guardianDobs[i])) {
          warningMessage(context, 'Guardian for nominee ${i + 1} must be above age 18');
          return;
        }
      }

      // Court-appointed guardian → PDF proof is required
      final guardianRelations = [
        _guardianRelation1, _guardianRelation2, _guardianRelation3,
      ];
      final guardianDocs = [
        _guardianDocFile1, _guardianDocFile2, _guardianDocFile3,
      ];
      for (var i = 0; i < _nomineeCount; i++) {
        if (_needsGuardianDoc(nomineeDobs[i], guardianRelations[i]) &&
            guardianDocs[i] == null) {
          warningMessage(context,
              'Please upload the guardian document (PDF) for nominee ${i + 1}');
          return;
        }
      }

      // Validate percentages add up to 100
      final p1 = int.tryParse(_percent1.text) ?? 0;
      final p2 = _nomineeCount >= 2 ? (int.tryParse(_percent2.text) ?? 0) : 0;
      final p3 = _nomineeCount >= 3 ? (int.tryParse(_percent3.text) ?? 0) : 0;
      final total = p1 + p2 + p3;
      if (total != 100) {
        warningMessage(context, 'Total percentage must be 100%. Currently: $total%');
        return;
      }
    }

    setState(() => _loading = true);

    final provider = ref.read(profileAllDetailsProvider);
    final clientData = provider.clientAllDetails.clientData;
    if (clientData == null) {
      setState(() => _loading = false);
      return;
    }

    final clientJson = clientData.toJson();
    String dob(DateTime? d) =>
        d != null ? DateFormat('yyyy-MM-dd').format(d) : '';
    final fields = <String, String>{
      'clientcode': clientJson['CLIENT_ID'] ?? '',

      // ── Nominee 1 ──
      'Nominee1_name': _yesOrNo == 'yes' ? _name1.text : '',
      'Nominee1_PAN': _yesOrNo == 'yes' ? _proofValue1.text : '',
      'Nominee1_DOB': _yesOrNo == 'yes' ? dob(_dob1) : '',
      'Nominee1_relation': _yesOrNo == 'yes' ? (_relation1 ?? '') : '',
      'Nominee1_address1': _yesOrNo == 'yes'
          ? (_sameAddress1
              ? (clientJson['CL_RESI_ADD1'] ?? '')
              : _address1.text)
          : '',
      'Nominee1_address2': _yesOrNo == 'yes' && _sameAddress1
          ? (clientJson['CL_RESI_ADD2'] ?? '')
          : '',
      'Nominee1_city': _yesOrNo == 'yes' ? _city1.text : '',
      'Nominee1_state': _yesOrNo == 'yes' ? _state1.text : '',
      'Nominee1_country': _yesOrNo == 'yes' ? _country1.text : '',
      'Nominee1_pincode': _yesOrNo == 'yes' ? _pincode1.text : '',
      'Nominee1_mobile': _yesOrNo == 'yes' ? _mobile1.text : '',
      'Nominee1_email': _yesOrNo == 'yes' ? _email1.text : '',
      'client_email': clientJson['CLIENT_ID_MAIL'] ?? '',
      'client_pan': clientJson['PAN_NO'] ?? '',
      'Nominee1_percentage': _yesOrNo == 'yes' ? _percent1.text : '',
      'Nominee1_Select_id':
          _yesOrNo == 'yes' ? _proofTypeToApiKey(_proofType1) : '',

      // ── Nominee
      'Nominee2_name': _nomineeCount >= 2 ? _name2.text : '',
      'dp_code': clientJson['CLIENT_DP_CODE'] ?? '',
      'nominee_req': _yesOrNo ?? 'no',
      'client_name': clientJson['CLIENT_NAME'] ?? '',
      'Nominee2_PAN': _nomineeCount >= 2 ? _proofValue2.text : '',
      'Nominee2_DOB': _nomineeCount >= 2 ? dob(_dob2) : '',
      'Nominee2_relation': _nomineeCount >= 2 ? (_relation2 ?? '') : '',
      'Nominee2_address1': _nomineeCount >= 2
          ? (_sameAddress2
              ? (clientJson['CL_RESI_ADD1'] ?? '')
              : _address2.text)
          : '',
      'Nominee2_address2': '',
      'Nominee2_city': _nomineeCount >= 2 ? _city2.text : '',
      'Nominee2_state': _nomineeCount >= 2 ? _state2.text : '',
      'Nominee2_country': _nomineeCount >= 2 ? _country2.text : '',
      'Nominee2_pincode': _nomineeCount >= 2 ? _pincode2.text : '',
      'Nominee2_mobile': _nomineeCount >= 2 ? _mobile2.text : '',
      'Nominee2_email': _nomineeCount >= 2 ? _email2.text : '',
      'Nominee2_percentage': _nomineeCount >= 2 ? _percent2.text : '',
      'Nominee2_Select_id':
          _nomineeCount >= 2 ? _proofTypeToApiKey(_proofType2) : '',

      // ── Nominee 3
      'Nominee3_name': _nomineeCount >= 3 ? _name3.text : '',
      'Nominee3_PAN': _nomineeCount >= 3 ? _proofValue3.text : '',
      'Nominee3_DOB': _nomineeCount >= 3 ? dob(_dob3) : '',
      'Nominee3_relation': _nomineeCount >= 3 ? (_relation3 ?? '') : '',
      'Nominee3_address1': _nomineeCount >= 3
          ? (_sameAddress3
              ? (clientJson['CL_RESI_ADD1'] ?? '')
              : _address3.text)
          : '',
      'Nominee3_address2': '',
      'Nominee3_city': _nomineeCount >= 3 ? _city3.text : '',
      'Nominee3_state': _nomineeCount >= 3 ? _state3.text : '',
      'Nominee3_country': _nomineeCount >= 3 ? _country3.text : '',
      'Nominee3_pincode': _nomineeCount >= 3 ? _pincode3.text : '',
      'Nominee3_mobile': _nomineeCount >= 3 ? _mobile3.text : '',
      'Nominee3_email': _nomineeCount >= 3 ? _email3.text : '',
      'Nominee3_percentage': _nomineeCount >= 3 ? _percent3.text : '',
      'Nominee3_Select_id': _nomineeCount >= 3
          ? _proofTypeToApiKey(_proofType3)
          : '',

      // Guardian 1
      'Guardian_name': _isMinor(_dob1) ? _guardianName1.text : '',
      'Guardian_dob': _isMinor(_dob1) ? dob(_guardianDob1) : '',
      'Guardian_address': _isMinor(_dob1) ? _guardianAddress1.text : '',
      'Guardian_city': _isMinor(_dob1) ? _guardianCity1.text : '',
      'Guardian_state': _isMinor(_dob1) ? _guardianState1.text : '',
      'Guardian_country': _isMinor(_dob1) ? _guardianCountry1.text : '',
      'Guardian_mobile': '',
      'Guardian_email': '',
      'Guardian_relation': _isMinor(_dob1) ? (_guardianRelation1 ?? '') : '',
      'Guardian_doc_type': '',
      'Guardian_pincode': _isMinor(_dob1) ? _guardianPincode1.text : '',

      // ── Guardian 2 ──
      'Guardian_name2': _isMinor(_dob2) ? _guardianName2.text : '',
      'Guardian_dob2': _isMinor(_dob2) ? dob(_guardianDob2) : '',
      'Guardian_address2': _isMinor(_dob2) ? _guardianAddress2.text : '',
      'Guardian_city2': _isMinor(_dob2) ? _guardianCity2.text : '',
      'Guardian_state2': _isMinor(_dob2) ? _guardianState2.text : '',
      'Guardian_country2': _isMinor(_dob2) ? _guardianCountry2.text : '',
      'Guardian_mobile2': '',
      'Guardian_email2': '',
      'Guardian_relation2': _isMinor(_dob2) ? (_guardianRelation2 ?? '') : '',
      'Guardian_doc_type2': '',
      'Guardian_pincode2': _isMinor(_dob2) ? _guardianPincode2.text : '',

      // ── Guardian 3 ──
      'Guardian_name3': _isMinor(_dob3) ? _guardianName3.text : '',
      'Guardian_dob3': _isMinor(_dob3) ? dob(_guardianDob3) : '',
      'Guardian_address3': _isMinor(_dob3) ? _guardianAddress3.text : '',
      'Guardian_city3': _isMinor(_dob3) ? _guardianCity3.text : '',
      'Guardian_state3': _isMinor(_dob3) ? _guardianState3.text : '',
      'Guardian_country3': _isMinor(_dob3) ? _guardianCountry3.text : '',
      'Guardian_mobile3': '',
      'Guardian_email3': '',
      'Guardian_relation3': _isMinor(_dob3) ? (_guardianRelation3 ?? '') : '',
      'Guardian_doc_type3': '',
      'Guardian_pincode3': _isMinor(_dob3) ? _guardianPincode3.text : '',

      // ── Documents trailer (binary OR empty string for guardian_doc*) ──
      'nominee_doc1': '',
      'nominee_doc2': '',
      'nominee_doc3': '',
    };

    // Attach guardian PDF only for slots that need it (minor + court-appointed).
    final files = <String, ({String filename, Uint8List bytes})>{};
    void attachIfNeeded(
        String key, DateTime? dob, String? relation, PlatformFile? file) {
      if (!_needsGuardianDoc(dob, relation) || file == null) {
        fields[key] = '';
        return;
      }
      final bytes = file.bytes;
      if (bytes == null) {
        fields[key] = '';
        return;
      }
      files[key] = (filename: file.name, bytes: bytes);
    }

    attachIfNeeded('guardian_doc', _dob1, _guardianRelation1, _guardianDocFile1);
    attachIfNeeded(
        'guardian_doc2',
        _nomineeCount >= 2 ? _dob2 : null,
        _nomineeCount >= 2 ? _guardianRelation2 : null,
        _nomineeCount >= 2 ? _guardianDocFile2 : null);
    attachIfNeeded(
        'guardian_doc3',
        _nomineeCount >= 3 ? _dob3 : null,
        _nomineeCount >= 3 ? _guardianRelation3 : null,
        _nomineeCount >= 3 ? _guardianDocFile3 : null);

    final result = await provider.submitNominee(fields: fields, files: files);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result != null && result['msg'] == 'Success') {
      setState(() {
        _esignPending = true;
        _fileId = result['fileid']?.toString();
      });
      _showEsignDialog();
    } else if (result != null && result['msg'] == 'Client already exists') {
      warningMessage(context, 'Nominee form already initiated');
    } else {
      warningMessage(context, result?['msg']?.toString() ?? 'Error in Server, please try again later');
    }
  }

  Future<void> _openDigioEsign() async {
    final statusData = ref.read(profileAllDetailsProvider).nomineeStatusData;
    final fileId = _fileId ?? statusData?['file_id']?.toString();
    final email = _esignEmail ?? statusData?['client_email']?.toString();
    final session = _esignSession ?? statusData?['session']?.toString();

    if (fileId == null || email == null || session == null) {
      warningMessage(context, 'E-Sign details not available');
      return;
    }

    setState(() => _esignLoading = true);
    final result = await startDigioEsign(
      fileId: fileId,
      email: email,
      session: session,
    );

    if (!mounted) return;
    setState(() => _esignLoading = false);

    if (result == 'success') {
      // Persist the in-process flag (keyed by clientId) so the banner.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_esignPrefKey(), true);
      await ref.read(profileAllDetailsProvider).fetchClientProfileAllDetails();
      if (!mounted) return;
      // Re-load local state from refreshed nom_stat so _hasExistingNominee and
      // form controllers reflect the just-signed nominee.
      await _loadNomineeStatus();
      if (mounted) {
        successMessage(context, 'Nominee e-signed successfully');
      }
    }
  }

  void _showEsignDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.dialogDark, light: MyntColors.dialog),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with divider
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: resolveThemeColor(context,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'E-Sign Is Pending!',
                      style: MyntWebTextStyles.title(context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary)),
                    ),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Your nominee form has been submitted. Please complete the e-sign to finalize.',
                      textAlign: TextAlign.center,
                      style: MyntWebTextStyles.body(context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _openDigioEsign();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: resolveThemeColor(context,
                              dark: MyntColors.secondary,
                              light: MyntColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Click here E-sign',
                          style: MyntWebTextStyles.buttonMd(context,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);

    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final subtitleColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final bgColor = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor);
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final cardBorder = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final primaryColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final successColor = resolveThemeColor(context,
        dark: MyntColors.successDark, light: MyntColors.success);
    final errorColor = resolveThemeColor(context,
        dark: MyntColors.errorDark, light: MyntColors.error);
    final dividerColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);

    return Scaffold(
      backgroundColor: bgColor,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      if (widget.onBack != null)
                        InkWell(
                          onTap: widget.onBack,
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.arrow_back_ios_outlined,
                              size: 18,
                              color: textColor,
                            ),
                          ),
                        ),
                      if (widget.onBack != null) const SizedBox(width: 8),
                      Text('Nominee',
                          style: MyntWebTextStyles.head(context,
                              fontWeight: MyntFonts.semiBold,
                              color: textColor)
                              .copyWith(decoration: TextDecoration.none)),
                      const SizedBox(width: 12),
                      // profile API's Nominee_Name is non-empty (active nominee only; not a pending e-sign request).
                      Builder(builder: (_) {
                        final profileNomName = ref
                                .watch(profileAllDetailsProvider)
                                .clientAllDetailsSafe
                                ?.clientData
                                ?.nomineeName ?? '';
                        final isSecured = profileNomName.isNotEmpty;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSecured
                                ? successColor.withValues(alpha: 0.1)
                                : errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSecured
                                  ? successColor.withValues(alpha: 0.3)
                                  : errorColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSecured
                                    ? Icons.verified_user_outlined
                                    : Icons.shield_outlined,
                                color: isSecured ? successColor : errorColor,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isSecured ? 'Secured' : 'Unsecured',
                                style: MyntWebTextStyles.caption(context,
                                    color: isSecured ? successColor : errorColor,
                                    fontWeight: MyntFonts.semiBold)
                                    .copyWith(decoration: TextDecoration.none),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Content ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Existing nominee display (read-only) ──
                        if (_hasExistingNominee) ...[
                          _buildExistingNomineeView(
                              textColor, subtitleColor, cardBorder, cardBg, dividerColor),
                          const SizedBox(height: 16),
                        ],

                        // Esign Pending
                        if (_esignRequestInProcess) ...[
                          _buildEsignPendingBanner(primaryColor, errorColor,
                              inProcess: true),
                          const SizedBox(height: 24),
                        ] else if (_esignPending) ...[
                          _buildEsignPendingBanner(primaryColor, errorColor),
                          const SizedBox(height: 24),
                        ],

                        // ── Single card for no-nominee state ──
                        if (!_hasExistingNominee &&
                            !_esignPending &&
                            !_esignCompleted &&
                            !_esignRequestInProcess)
                          _buildNoNomineeCard(textColor, subtitleColor, cardBg, cardBorder, primaryColor, errorColor),

                        // ── Nominee form (only show when editing/adding with existing nominee) ──
                        if (_hasExistingNominee &&
                            !_esignCompleted &&
                            !_esignPending &&
                            !_esignRequestInProcess) ...[
                          _buildChoiceSection(primaryColor, textColor, subtitleColor, cardBorder),
                          const SizedBox(height: 16),
                          if (_yesOrNo == 'yes') ...[
                            _buildNomineeForm(
                                textColor, subtitleColor, cardBorder, cardBg, primaryColor, dividerColor),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SINGLE CARD (no nominee state - info + actions combined)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildNoNomineeCard(Color textColor, Color subtitleColor,
      Color cardBg, Color borderColor, Color primaryColor, Color errorColor) {
    final disabledReason = _editDisabledReason();
    final canEdit = disabledReason == null;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
      color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.shield_outlined, color: errorColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your account is not secured',
                        style: MyntWebTextStyles.title(context,
                            fontWeight: MyntFonts.semiBold, color: textColor)
                            .copyWith(decoration: TextDecoration.none)),
                    const SizedBox(height: 4),
                    Text('Add a nominee to protect your investments and ensure smooth transfer of assets.',
                        style: MyntWebTextStyles.bodySmall(context,
                            color: subtitleColor, fontWeight: MyntFonts.regular)
                            .copyWith(decoration: TextDecoration.none)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              _gatedTooltip(
                OutlinedButton.icon(
                onPressed: !canEdit
                    ? null
                    : () {
                  setState(() {
                    if (_yesOrNo == 'yes') {
                      _yesOrNo = null;
                    } else {
                      _yesOrNo = 'yes';
                      _activePanel = 0;
                    }
                  });
                },
                icon: Icon(Icons.add,
                    size: 18,
                    color: _yesOrNo == 'yes' ? primaryColor : subtitleColor),
                label: Text('Add Nominee',
                    style: MyntWebTextStyles.bodySmall(context,
                        color: _yesOrNo == 'yes' ? primaryColor : subtitleColor,
                        fontWeight: _yesOrNo == 'yes'
                            ? MyntFonts.semiBold
                            : MyntFonts.medium)
                        .copyWith(decoration: TextDecoration.none)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _yesOrNo == 'yes' ? primaryColor : borderColor,
                    width: _yesOrNo == 'yes' ? 1.5 : 1,
                  ),
                  backgroundColor: _yesOrNo == 'yes'
                      ? primaryColor.withValues(alpha: 0.08)
                      : Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
                disabledReason,
              ),
              const SizedBox(width: 12),
              _gatedTooltip(
                OutlinedButton(
                  onPressed: !canEdit
                      ? null
                      : () {
                          setState(() {
                            if (_yesOrNo == 'no') {
                              _yesOrNo = null;
                            } else {
                              _yesOrNo = 'no';
                            }
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _yesOrNo == 'no' ? primaryColor : borderColor,
                      width: _yesOrNo == 'no' ? 1.5 : 1,
                    ),
                    backgroundColor: _yesOrNo == 'no'
                        ? primaryColor.withValues(alpha: 0.08)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  child: Text('Skip for now',
                      style: MyntWebTextStyles.bodySmall(context,
                              color: _yesOrNo == 'no'
                                  ? primaryColor
                                  : subtitleColor,
                              fontWeight: _yesOrNo == 'no'
                                  ? MyntFonts.semiBold
                                  : MyntFonts.medium)
                          .copyWith(decoration: TextDecoration.none)),
                ),
                disabledReason,
              ),
            ],
          ),

          // Opt-out continue button
          if (_yesOrNo == 'no') ...[
            const SizedBox(height: 16),
            _gatedTooltip(
              ElevatedButton(
              onPressed: (_loading || !canEdit) ? null : _submitNominee,
              style: ElevatedButton.styleFrom(
                backgroundColor: resolveThemeColor(context,
            dark: MyntColors.secondary, light: MyntColors.primary),
                disabledBackgroundColor:
                    resolveThemeColor(context,
                        dark: MyntColors.secondary, light: MyntColors.primary)
                        .withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Continue',
                      style: MyntWebTextStyles.bodySmall(context,
                          color: Colors.white, fontWeight: MyntFonts.semiBold)
                          .copyWith(decoration: TextDecoration.none)),
            ),
              disabledReason,
            ),
          ],

          // Nominee form (inline when "Add Nominee" is selected)
          if (_yesOrNo == 'yes') ...[
            const SizedBox(height: 20),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 20),
            _buildNomineeForm(textColor, subtitleColor, borderColor, cardBg, primaryColor,
                resolveThemeColor(context, dark: MyntColors.dividerDark, light: MyntColors.divider)),
          ],

          // Regulatory note
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.info_outline, color: subtitleColor, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'As per SEBI regulations, you can add up to 3 nominees for your trading and demat account.',
                  style: MyntWebTextStyles.caption(context,
                      color: subtitleColor, fontWeight: MyntFonts.regular)
                      .copyWith(decoration: TextDecoration.none),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  EXISTING NOMINEE DISPLAY
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildExistingNomineeView(
      Color textColor, Color subtitleColor, Color borderColor,
      Color cardBg, Color dividerColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Existing Nominee',
              style: MyntWebTextStyles.title(context,
                  fontWeight: MyntFonts.semiBold,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary)
                  .copyWith(decoration: TextDecoration.none)),
          const SizedBox(height: 16),

          // Nominee 1 — 3-column grid
          Row(
            children: [
              Expanded(child: _buildReadOnlyField('NOMINEE NAME', _name1.text, textColor, subtitleColor, borderColor)),
              const SizedBox(width: 24),
              Expanded(child: _buildReadOnlyField('NOMINEE RELATION', _relation1 ?? '', textColor, subtitleColor, borderColor)),
              const SizedBox(width: 24),
              Expanded(child: _buildReadOnlyField('NOMINEE DOB', _dob1 != null ? DateFormat('dd/MM/yyyy').format(_dob1!) : '-', textColor, subtitleColor, borderColor)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildReadOnlyField('PERCENTAGE', _percent1.text.isNotEmpty ? '${_percent1.text}%' : '-', textColor, subtitleColor, borderColor)),
              const SizedBox(width: 24),
              const Expanded(child: SizedBox()),
              const SizedBox(width: 24),
              const Expanded(child: SizedBox()),
            ],
          ),

          // Nominee 2
          if (_nomineeCount >= 2 && _name2.text.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: dividerColor),
            ),
            Text('Nominee 2',
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary)
                    .copyWith(decoration: TextDecoration.none)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildReadOnlyField('NOMINEE NAME', _name2.text, textColor, subtitleColor, borderColor)),
                const SizedBox(width: 24),
                Expanded(child: _buildReadOnlyField('NOMINEE RELATION', _relation2 ?? '', textColor, subtitleColor, borderColor)),
                const SizedBox(width: 24),
                Expanded(child: _buildReadOnlyField('NOMINEE DOB', _dob2 != null ? DateFormat('dd/MM/yyyy').format(_dob2!) : '-', textColor, subtitleColor, borderColor)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildReadOnlyField('PERCENTAGE', _percent2.text.isNotEmpty ? '${_percent2.text}%' : '-', textColor, subtitleColor, borderColor)),
                const SizedBox(width: 24),
                const Expanded(child: SizedBox()),
                const SizedBox(width: 24),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],

          // Nominee 3
          if (_nomineeCount >= 3 && _name3.text.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: dividerColor),
            ),
            Text('Nominee 3',
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary)
                    .copyWith(decoration: TextDecoration.none)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildReadOnlyField('NOMINEE NAME', _name3.text, textColor, subtitleColor, borderColor)),
                const SizedBox(width: 24),
                Expanded(child: _buildReadOnlyField('NOMINEE RELATION', _relation3 ?? '', textColor, subtitleColor, borderColor)),
                const SizedBox(width: 24),
                Expanded(child: _buildReadOnlyField('NOMINEE DOB', _dob3 != null ? DateFormat('dd/MM/yyyy').format(_dob3!) : '-', textColor, subtitleColor, borderColor)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildReadOnlyField('PERCENTAGE', _percent3.text.isNotEmpty ? '${_percent3.text}%' : '-', textColor, subtitleColor, borderColor)),
                const SizedBox(width: 24),
                const Expanded(child: SizedBox()),
                const SizedBox(width: 24),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(
      String label, String value, Color textColor, Color subtitleColor, Color borderColor) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      style: MyntWebTextStyles.body(context, color: textColor)
          .copyWith(decoration: TextDecoration.none),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: MyntWebTextStyles.caption(context,
            color: subtitleColor, fontWeight: MyntFonts.medium)
            .copyWith(decoration: TextDecoration.none, letterSpacing: 0.5),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: borderColor),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ESIGN PENDING BANNER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildEsignPendingBanner(Color primaryColor, Color errorColor,
      {bool inProcess = false}) {
    final warningBg = resolveThemeColor(context,
        dark: const Color(0xFF3D2E00), light: const Color(0xFFFCEFD4));
    final warningText = resolveThemeColor(context,
        dark: const Color(0xFFFFD780), light: Colors.brown[800]!);
    final warningIcon = resolveThemeColor(context,
        dark: MyntColors.warningDark, light: MyntColors.warning);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: warningIcon, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  inProcess
                      ? 'Your Nominee Change request is in process.'
                      : 'Esign Pending - Click here to complete',
                  style: MyntWebTextStyles.bodySmall(context,
                      color: warningText, fontWeight: MyntFonts.medium)
                      .copyWith(decoration: TextDecoration.none),
                ),
              ),
            ],
          ),
          // Action buttons only when e-sign is still pending (not after sign).
          if (!inProcess) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _esignLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: primaryColor))
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openDigioEsign,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Text('Click here E-sign',
                                style: MyntWebTextStyles.bodySmall(context,
                                    color: primaryColor,
                                    fontWeight: MyntFonts.semiBold)
                                    .copyWith(decoration: TextDecoration.none)),
                          ),
                        ),
                      ),
                const SizedBox(width: 4),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showCancelConfirmation,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Text('Cancel request',
                          style: MyntWebTextStyles.bodySmall(context,
                              color: errorColor,
                              fontWeight: MyntFonts.semiBold)
                              .copyWith(decoration: TextDecoration.none)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.dialogDark, light: MyntColors.dialog),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with divider
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: resolveThemeColor(context,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cancel request?',
                      style: MyntWebTextStyles.title(context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary)),
                    ),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Are you sure you want to cancel your "Nominee" request?',
                      textAlign: TextAlign.center,
                      style: MyntWebTextStyles.body(context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _cancelRequest();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: resolveThemeColor(context,
                              dark: MyntColors.errorDark,
                              light: MyntColors.tertiary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: MyntWebTextStyles.buttonMd(context,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resets the screen to the "no nominee" initial state. Used after a
  /// successful cancel so the cancelled-pending record no longer shows.
  void _resetToInitialState() {
    setState(() {
      _hasExistingNominee = false;
      _esignPending = false;
      _esignCompleted = false;
      _esignRequestInProcess = false;
      _fileId = null;
      _esignEmail = null;
      _esignSession = null;
      _yesOrNo = null;
      _activePanel = 0;
      _nomineeCount = 1;

      for (final c in [
        _name1, _percent1, _address1, _city1, _state1, _country1, _pincode1,
        _mobile1, _email1, _proofValue1,
        _name2, _percent2, _address2, _city2, _state2, _country2, _pincode2,
        _mobile2, _email2, _proofValue2,
        _name3, _percent3, _address3, _city3, _state3, _country3, _pincode3,
        _mobile3, _email3, _proofValue3,
        _guardianName1, _guardianAddress1, _guardianPincode1,
        _guardianCity1, _guardianState1, _guardianCountry1,
        _guardianName2, _guardianAddress2, _guardianPincode2,
        _guardianCity2, _guardianState2, _guardianCountry2,
        _guardianName3, _guardianAddress3, _guardianPincode3,
        _guardianCity3, _guardianState3, _guardianCountry3,
      ]) {
        c.clear();
      }
      _percent1.text = '100';
      _country1.text = 'India';
      _country2.text = 'India';
      _country3.text = 'India';

      _dob1 = _dob2 = _dob3 = null;
      _relation1 = _relation2 = _relation3 = null;
      _proofType1 = _proofType2 = _proofType3 = null;
      _sameAddress1 = _sameAddress2 = _sameAddress3 = false;
      _guardianDob1 = _guardianDob2 = _guardianDob3 = null;
      _guardianRelation1 = _guardianRelation2 = _guardianRelation3 = null;
      _guardianDocFile1 = _guardianDocFile2 = _guardianDocFile3 = null;
    });
  }

  Future<void> _cancelRequest() async {
    try {
      final fileId = _fileId ?? '';
      final api = locator<ApiExporter>();
      final response = await api.cancelPendingStatusApi('nominee', fileId);
      if (mounted) {
        if (response == 'Cancel Success') {
          // Drop the persisted in-process flag for this client.
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_esignPrefKey());
          final hadExisting = _hasExistingNominee;
          if (hadExisting) {
            // Keep existing nominee data
            setState(() {
              _esignPending = false;
              _esignCompleted = false;
              _esignRequestInProcess = false;
              _fileId = null;
            });
          } else {
            // No prior nominee — reset form to the "no nominee" empty state.
            _resetToInitialState();
          }
          successMessage(context, 'Esign Cancellation Success');
          // _loadNomineeStatus() internally calls provider.fetchNomineeStatus().
          await _loadNomineeStatus();
        } else {
          warningMessage(context, 'Esign Cancellation Failed');
        }
      }
    } catch (e) {
      if (mounted) {
        warningMessage(context, 'Something Went Wrong');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CHOICE SECTION
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildChoiceSection(
      Color primaryColor, Color textColor, Color subtitleColor, Color borderColor) {
    final isEdit = _hasExistingNominee;
    final disabledReason = _editDisabledReason();
    final canEdit = disabledReason == null;
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final hoverBg = resolveThemeColor(context,
        dark: const Color(0xFF21262D), light: const Color(0xFFF6F8FA));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEdit ? 'What would you like to do?' : 'Get started',
          style: MyntWebTextStyles.bodySmall(context,
              color: subtitleColor, fontWeight: MyntFonts.medium)
              .copyWith(decoration: TextDecoration.none),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _gatedTooltip(
              _buildChoiceButton(
                icon: isEdit ? Icons.edit_outlined : Icons.shield_outlined,
                label: isEdit ? 'Edit your nominee' : 'Add Nominee',
                subtitle: isEdit ? 'Update nominee details' : 'Secure your account now',
                isSelected: _yesOrNo == 'yes',
                isPrimary: true,
                primaryColor: primaryColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
                borderColor: borderColor,
                cardBg: cardBg,
                hoverBg: hoverBg,
                onTap: !canEdit
                    ? null
                    : () {
                        setState(() {
                          if (_yesOrNo == 'yes') {
                            _yesOrNo = null;
                          } else {
                            _yesOrNo = 'yes';
                            _activePanel = 0;
                          }
                        });
                      },
              ),
              disabledReason,
            ),
            if (!isEdit) ...[
              const SizedBox(width: 16),
              _gatedTooltip(
                _buildChoiceButton(
                  icon: Icons.schedule_outlined,
                  label: 'Skip for now',
                  subtitle: 'I\'ll do it later',
                  isSelected: _yesOrNo == 'no',
                  isPrimary: false,
                  primaryColor: primaryColor,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  borderColor: borderColor,
                  cardBg: cardBg,
                  hoverBg: hoverBg,
                  onTap: !canEdit
                      ? null
                      : () {
                          setState(() {
                            if (_yesOrNo == 'no') {
                              _yesOrNo = null;
                            } else {
                              _yesOrNo = 'no';
                            }
                          });
                        },
                ),
                disabledReason,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required bool isPrimary,
    required Color primaryColor,
    required Color textColor,
    required Color subtitleColor,
    required Color borderColor,
    required Color cardBg,
    required Color hoverBg,
    required VoidCallback? onTap,
  }) {
    final selectedBg = cardBg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: isSelected ? Colors.transparent : hoverBg,
        splashColor: primaryColor.withValues(alpha: 0.08),
        child: Container(
          width: 240,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? primaryColor : borderColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.1)
                      : subtitleColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    size: 18,
                    color: isSelected ? primaryColor : subtitleColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: MyntWebTextStyles.bodySmall(context,
                            color: isSelected ? primaryColor : textColor,
                            fontWeight: MyntFonts.semiBold)
                            .copyWith(decoration: TextDecoration.none)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: MyntWebTextStyles.caption(context,
                            color: subtitleColor,
                            fontWeight: MyntFonts.regular)
                            .copyWith(decoration: TextDecoration.none)),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: primaryColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  //  PINCODE AUTO-FETCH
  Future<void> _fetchPincodeData(
    String pincode,
    TextEditingController pincodeCtrl,
    TextEditingController cityCtrl,
    TextEditingController stateCtrl,
    TextEditingController countryCtrl,
  ) async {
    if (pincode.length != 6) return;
    setState(() => _pincodeLoading.add(pincodeCtrl));
    try {
      final uri = Uri.parse('https://api.postalpincode.in/pincode/$pincode');
      final res = await http.get(uri);
      if (!mounted) return;
      final data = jsonDecode(res.body) as List;
      if (data.isNotEmpty && data[0]['Status'] == 'Success') {
        final postOffices = data[0]['PostOffice'] as List;
        if (postOffices.isNotEmpty) {
          final po = postOffices[0];
          setState(() {
            cityCtrl.text = po['Division']?.toString() ?? '';
            stateCtrl.text = po['State']?.toString() ?? '';
            countryCtrl.text = po['Country']?.toString() ?? 'India';
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _pincodeLoading.remove(pincodeCtrl));
    }
  }

  Widget? _pincodeSuffix(TextEditingController pincodeCtrl, Color subtitleColor) {
    if (!_pincodeLoading.contains(pincodeCtrl)) return null;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(subtitleColor),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  NOMINEE FORM
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildNomineeForm(
      Color textColor, Color subtitleColor, Color borderColor,
      Color cardBg, Color primaryColor, Color dividerColor) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nominee tabs (1st, 2nd, 3rd)
          _buildNomineeTabs(primaryColor, subtitleColor, borderColor),
          const SizedBox(height: 16),

          // Active nominee panel form
          if (_activePanel == 0)
            _buildSingleNomineeForm(
              1, _name1, _percent1, _dob1, (d) => setState(() => _dob1 = d),
              _relation1, (r) => setState(() => _relation1 = r),
              _sameAddress1, (v) => setState(() => _sameAddress1 = v),
              _address1, _city1, _state1, _country1, _pincode1,
              _mobile1, _email1, _proofType1,
              (t) => setState(() => _proofType1 = t), _proofValue1,
              _guardianName1, _guardianDob1,
              _onGuardianDobChanged(1),
              _guardianRelation1,
              (r) => setState(() => _guardianRelation1 = r),
              _guardianAddress1, _guardianPincode1, _guardianCity1,
              _guardianState1, _guardianCountry1,
              textColor, subtitleColor, borderColor, primaryColor,
            ),
          if (_activePanel == 1 && _nomineeCount >= 2)
            _buildSingleNomineeForm(
              2, _name2, _percent2, _dob2, (d) => setState(() => _dob2 = d),
              _relation2, (r) => setState(() => _relation2 = r),
              _sameAddress2, (v) => setState(() => _sameAddress2 = v),
              _address2, _city2, _state2, _country2, _pincode2,
              _mobile2, _email2, _proofType2,
              (t) => setState(() => _proofType2 = t), _proofValue2,
              _guardianName2, _guardianDob2,
              _onGuardianDobChanged(2),
              _guardianRelation2,
              (r) => setState(() => _guardianRelation2 = r),
              _guardianAddress2, _guardianPincode2, _guardianCity2,
              _guardianState2, _guardianCountry2,
              textColor, subtitleColor, borderColor, primaryColor,
            ),
          if (_activePanel == 2 && _nomineeCount >= 3)
            _buildSingleNomineeForm(
              3, _name3, _percent3, _dob3, (d) => setState(() => _dob3 = d),
              _relation3, (r) => setState(() => _relation3 = r),
              _sameAddress3, (v) => setState(() => _sameAddress3 = v),
              _address3, _city3, _state3, _country3, _pincode3,
              _mobile3, _email3, _proofType3,
              (t) => setState(() => _proofType3 = t), _proofValue3,
              _guardianName3, _guardianDob3,
              _onGuardianDobChanged(3),
              _guardianRelation3,
              (r) => setState(() => _guardianRelation3 = r),
              _guardianAddress3, _guardianPincode3, _guardianCity3,
              _guardianState3, _guardianCountry3,
              textColor, subtitleColor, borderColor, primaryColor,
            ),

          const SizedBox(height: 24),

          // Add nominee buttons + Continue
          _buildActionButtons(primaryColor, subtitleColor, borderColor),
        ],
      ),
    );
  }

  Widget _buildNomineeTabs(Color primaryColor, Color subtitleColor, Color borderColor) {
    return Wrap(
      spacing: 8,
      children: [
        _buildNomineeTab(
          label: '1st nominee',
          index: 0,
          primaryColor: primaryColor,
          subtitleColor: subtitleColor,
          borderColor: borderColor,
        ),
        if (_nomineeCount >= 2)
          _buildNomineeTab(
            label: '2nd nominee',
            index: 1,
            primaryColor: primaryColor,
            subtitleColor: subtitleColor,
            borderColor: borderColor,
            onDelete: () => setState(() {
              _clearNominee2(); // handles promotion of 3rd→2nd if needed
              _activePanel = _nomineeCount >= 1 ? 0 : 0;
            }),
          ),
        if (_nomineeCount >= 3)
          _buildNomineeTab(
            label: '3rd nominee',
            index: 2,
            primaryColor: primaryColor,
            subtitleColor: subtitleColor,
            borderColor: borderColor,
            onDelete: () => setState(() {
              _nomineeCount = 2;
              _activePanel = 1;
              _clearNominee3();
            }),
          ),
      ],
    );
  }

  Widget _buildNomineeTab({
    required String label,
    required int index,
    required Color primaryColor,
    required Color subtitleColor,
    required Color borderColor,
    VoidCallback? onDelete,
  }) {
    final isSelected = _activePanel == index;
    final bgColor = isSelected ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary) : Colors.transparent;
    final labelColor = isSelected ? Colors.white : subtitleColor;
    final border = BorderSide(
      color: isSelected ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary) : borderColor,
      width: 1.5,
    );

    return GestureDetector(
      onTap: () => setState(() => _activePanel = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.fromBorderSide(border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: MyntWebTextStyles.bodySmall(context,
                  color: labelColor, fontWeight: MyntFonts.medium)
                  .copyWith(decoration: TextDecoration.none),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.close, size: 14, color: labelColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _clearNominee2() {
    if (_nomineeCount == 3) {
      // Promote 3rd nominee into 2nd slot, then clear 3rd
      _name2.text = _name3.text;
      _percent2.text = _percent3.text;
      _dob2 = _dob3;
      _relation2 = _relation3;
      _sameAddress2 = _sameAddress3;
      _address2.text = _address3.text;
      _city2.text = _city3.text;
      _state2.text = _state3.text;
      _country2.text = _country3.text;
      _pincode2.text = _pincode3.text;
      _mobile2.text = _mobile3.text;
      _email2.text = _email3.text;
      _proofType2 = _proofType3;
      _proofValue2.text = _proofValue3.text;
      _guardianName2.text = _guardianName3.text;
      _guardianDob2 = _guardianDob3;
      _guardianRelation2 = _guardianRelation3;
      _guardianAddress2.text = _guardianAddress3.text;
      _guardianPincode2.text = _guardianPincode3.text;
      _guardianCity2.text = _guardianCity3.text;
      _guardianState2.text = _guardianState3.text;
      _guardianCountry2.text = _guardianCountry3.text;
      _guardianDocFile2 = _guardianDocFile3;
      _clearNominee3();
      _nomineeCount = 2;
    } else {
      _name2.clear();
      _percent2.clear();
      _dob2 = null;
      _relation2 = null;
      _address2.clear();
      _city2.clear();
      _state2.clear();
      _pincode2.clear();
      _mobile2.clear();
      _email2.clear();
      _proofType2 = null;
      _proofValue2.clear();
      _guardianName2.clear();
      _guardianDob2 = null;
      _guardianRelation2 = null;
      _guardianAddress2.clear();
      _guardianPincode2.clear();
      _guardianCity2.clear();
      _guardianState2.clear();
      _guardianCountry2.clear();
      _guardianDocFile2 = null;
      _percent1.text = '100';
      _nomineeCount = 1; // ← was missing: tab stayed visible without this
    }
  }

  void _clearNominee3() {
    _name3.clear();
    _percent3.clear();
    _dob3 = null;
    _relation3 = null;
    _address3.clear();
    _city3.clear();
    _state3.clear();
    _pincode3.clear();
    _mobile3.clear();
    _email3.clear();
    _proofType3 = null;
    _proofValue3.clear();
    _guardianName3.clear();
    _guardianDob3 = null;
    _guardianRelation3 = null;
    _guardianAddress3.clear();
    _guardianPincode3.clear();
    _guardianCity3.clear();
    _guardianState3.clear();
    _guardianCountry3.clear();
    _guardianDocFile3 = null;
  }

  /// Returns true if the nominee at [index] (0, 1, 2) has all required fields filled.
  bool _isNomineeFilled(int index) {
    switch (index) {
      case 0:
        final baseOk = _name1.text.trim().isNotEmpty &&
            _dob1 != null &&
            _relation1 != null &&
            _proofType1 != null &&
            _proofValue1.text.trim().isNotEmpty &&
            _mobile1.text.trim().isNotEmpty &&
            _email1.text.trim().isNotEmpty;
        if (!baseOk) return false;
        if (!_sameAddress1) {
          return _address1.text.trim().isNotEmpty &&
              _pincode1.text.trim().isNotEmpty &&
              _city1.text.trim().isNotEmpty &&
              _state1.text.trim().isNotEmpty;
        }
        return true;
      case 1:
        final baseOk = _name2.text.trim().isNotEmpty &&
            _dob2 != null &&
            _relation2 != null &&
            _proofType2 != null &&
            _proofValue2.text.trim().isNotEmpty &&
            _mobile2.text.trim().isNotEmpty &&
            _email2.text.trim().isNotEmpty;
        if (!baseOk) return false;
        if (!_sameAddress2) {
          return _address2.text.trim().isNotEmpty &&
              _pincode2.text.trim().isNotEmpty &&
              _city2.text.trim().isNotEmpty &&
              _state2.text.trim().isNotEmpty;
        }
        return true;
      default:
        return false;
    }
  }

  Widget _buildActionButtons(Color primaryColor, Color subtitleColor, Color borderColor) {
    final disabledReason = _editDisabledReason();
    final canEdit = disabledReason == null;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        // + Add 2nd Nominee
        if (_nomineeCount < 2)
          _gatedTooltip(
            OutlinedButton(
              onPressed: !canEdit
                  ? null
                  : (_isNomineeFilled(0)
                      ? () => setState(() {
                            _nomineeCount = 2;
                            _activePanel = 1;
                            _percent1.text = '50';
                            _percent2.text = '50';
                          })
                      : () {
                          error(context, 'Please fill all required fields for 1st nominee to add another');
                        }),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                side: BorderSide(color: primaryColor),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text('+ Add 2nd Nominee',
                  style: MyntWebTextStyles.bodySmall(context,
                          color: primaryColor, fontWeight: MyntFonts.semiBold)
                      .copyWith(decoration: TextDecoration.none)),
            ),
            disabledReason,
          ),

        // + Add 3rd Nominee
        if (_nomineeCount == 2)
          _gatedTooltip(
            OutlinedButton(
              onPressed: !canEdit
                  ? null
                  : (_isNomineeFilled(1)
                      ? () => setState(() {
                            _nomineeCount = 3;
                            _activePanel = 2;
                          })
                      : () {
                          error(context, 'Please fill all required fields for 2nd nominee to add another');
                        }),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                side: BorderSide(color: primaryColor),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text('+ Add 3rd Nominee',
                  style: MyntWebTextStyles.bodySmall(context,
                          color: primaryColor, fontWeight: MyntFonts.semiBold)
                      .copyWith(decoration: TextDecoration.none)),
            ),
            disabledReason,
          ),

        // Continue button
        _gatedTooltip(
          ElevatedButton(
          onPressed: (_loading || !canEdit) ? null : _submitNominee,
          style: ElevatedButton.styleFrom(
            backgroundColor: resolveThemeColor(context,
            dark: MyntColors.secondary, light: MyntColors.primary),
            disabledBackgroundColor:
                resolveThemeColor(context,
                    dark: MyntColors.secondary, light: MyntColors.primary)
                    .withValues(alpha: 0.4),
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text('Continue',
                  style: MyntWebTextStyles.bodySmall(context,
                      color: Colors.white, fontWeight: MyntFonts.semiBold)
                      .copyWith(decoration: TextDecoration.none)),
        ),
          disabledReason,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SINGLE NOMINEE FORM
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSingleNomineeForm(
    int index,
    TextEditingController nameCtrl,
    TextEditingController percentCtrl,
    DateTime? dob,
    ValueChanged<DateTime?> onDobChanged,
    String? relation,
    ValueChanged<String?> onRelationChanged,
    bool sameAddress,
    ValueChanged<bool> onSameAddressChanged,
    TextEditingController addressCtrl,
    TextEditingController cityCtrl,
    TextEditingController stateCtrl,
    TextEditingController countryCtrl,
    TextEditingController pincodeCtrl,
    TextEditingController mobileCtrl,
    TextEditingController emailCtrl,
    String? proofType,
    ValueChanged<String?> onProofTypeChanged,
    TextEditingController proofValueCtrl,
    TextEditingController guardianNameCtrl,
    DateTime? guardianDob,
    ValueChanged<DateTime?> onGuardianDobChanged,
    String? guardianRelation,
    ValueChanged<String?> onGuardianRelationChanged,
    TextEditingController guardianAddressCtrl,
    TextEditingController guardianPincodeCtrl,
    TextEditingController guardianCityCtrl,
    TextEditingController guardianStateCtrl,
    TextEditingController guardianCountryCtrl,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Name + DOB + Percentage
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextField(
                'Nominee name *',
                nameCtrl,
                textColor,
                subtitleColor,
                borderColor,
                primaryColor,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter nominee name';
                  if (v.trim().length < 2) return 'Name must be at least 2 characters';
                  return null;
                },
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateField(
                'Date of birth *',
                dob,
                onDobChanged,
                textColor,
                subtitleColor,
                borderColor,
                primaryColor,
                helperText: '(Minor info displayed on DOB)',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                'Percentage *',
                percentCtrl,
                textColor,
                subtitleColor,
                borderColor,
                primaryColor,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter share percentage';
                  final n = int.tryParse(v);
                  if (n == null || n < 1 || n > 100) return 'Percentage must be between 1 and 100';
                  return null;
                },
                suffixIcon: Icon(Icons.percent, size: 16, color: subtitleColor),
                
                // Always editable — was previously disabled when nomineeCount == 1
                enabled: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Relationship + Mobile + Email
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDropdownField(
                'Relationship *',
                relation,
                _relations,
                onRelationChanged,
                textColor,
                subtitleColor,
                borderColor,
                primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                'Mobile number *',
                mobileCtrl,
                textColor,
                subtitleColor,
                borderColor,
                primaryColor,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter mobile number';
                  if (v.length < 10) return 'Mobile number must be 10 digits';
                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
                    return 'Mobile number must start with 6, 7, 8 or 9';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                'Email *',
                emailCtrl,
                textColor,
                subtitleColor,
                borderColor,
                primaryColor,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter email address';
                  if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                      .hasMatch(v)) {
                    return 'Please enter a valid email (e.g., name@example.com)';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 3: Proof type + Proof value + (empty spacer)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDropdownField(
                'Identity proof type *',
                proofType,
                _proofTypes,
                onProofTypeChanged,
                textColor,
                subtitleColor,
                borderColor,
                primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                proofType == 'PAN Number'
                    ? 'PAN Number *'
                    : proofType == 'Aadhaar number(last 4 digits)'
                        ? 'Aadhaar (last 4 digits) *'
                        : 'Proof Number *',
                proofValueCtrl,
                textColor,
                subtitleColor,
                borderColor,
                primaryColor,
                textCapitalization: proofType == 'PAN Number'
                    ? TextCapitalization.characters
                    : TextCapitalization.none,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    if (proofType == 'PAN Number') return 'Please enter PAN number';
                    if (proofType == 'Aadhaar number(last 4 digits)') return 'Please enter last 4 digits of Aadhaar';
                    return 'Please enter identity proof number';
                  }
                  if (proofType == 'PAN Number') {
                    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v)) {
                      return 'Invalid PAN format — must be like ABCDE1234F';
                    }
                  } else if (proofType == 'Aadhaar number(last 4 digits)') {
                    if (!RegExp(r'^\d{4}$').hasMatch(v)) {
                      return 'Please enter exactly 4 digits of Aadhaar';
                    }
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 12),

        // Same address checkbox
        Row(
          children: [
            Checkbox(
              value: sameAddress,
              onChanged: (v) => onSameAddressChanged(v ?? false),
              activeColor: primaryColor,
            ),
            Text('Nominee address is same as my address',
                style: MyntWebTextStyles.bodySmall(context,
                    color: textColor, fontWeight: MyntFonts.regular)
                    .copyWith(decoration: TextDecoration.none)),
          ],
        ),

        // Address fields (hidden if same address)
        if (!sameAddress) ...[
          const SizedBox(height: 8),
          _buildTextField('Address *', addressCtrl, textColor, subtitleColor,
              borderColor, primaryColor,
              validator: _requiredFieldValidator('nominee address')),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _buildTextField(
                      'Pincode *', pincodeCtrl, textColor, subtitleColor,
                      borderColor, primaryColor,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      suffixIcon: _pincodeSuffix(pincodeCtrl, subtitleColor),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter pincode';
                        if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'Pincode must be exactly 6 digits';
                        return null;
                      },
                      // Auto-fetch city, state, country when 6 digits entered
                      onChanged: (v) => _fetchPincodeData(v, pincodeCtrl, cityCtrl, stateCtrl, countryCtrl))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildTextField(
                      'City *', cityCtrl, textColor, subtitleColor,
                      borderColor, primaryColor,
                      validator: _requiredFieldValidator('city'))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildTextField(
                      'State *', stateCtrl, textColor, subtitleColor,
                      borderColor, primaryColor,
                      validator: _requiredFieldValidator('state'))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _buildTextField(
                      'Country *', countryCtrl, textColor, subtitleColor,
                      borderColor, primaryColor,
                      validator: _requiredFieldValidator('country'))),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],

        // Guardian section (if minor)
        if (_isMinor(dob)) ...[
          const SizedBox(height: 24),
          Text('Guardian Details',
              style: MyntWebTextStyles.title(context,
                  fontWeight: MyntFonts.semiBold,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary)
                  .copyWith(decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text('Nominee is under 18. Guardian details are required.',
              style: MyntWebTextStyles.caption(context,
                  color: subtitleColor)
                  .copyWith(decoration: TextDecoration.none)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField('Guardian name *', guardianNameCtrl,
                    textColor, subtitleColor, borderColor, primaryColor,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter guardian name';
                      if (v.trim().length < 2) return 'Name must be at least 2 characters';
                      return null;
                    },
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  'Guardian DOB *',
                  guardianDob,
                  onGuardianDobChanged,
                  textColor,
                  subtitleColor,
                  borderColor,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  'Guardian relationship *',
                  guardianRelation,
                  _guardianRelations,
                  onGuardianRelationChanged,
                  textColor,
                  subtitleColor,
                  borderColor,
                  primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Address *',
            guardianAddressCtrl,
            textColor,
            subtitleColor,
            borderColor,
            primaryColor,
            validator: _requiredFieldValidator('guardian address'),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  'Pincode *',
                  guardianPincodeCtrl,
                  textColor,
                  subtitleColor,
                  borderColor,
                  primaryColor,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  suffixIcon: _pincodeSuffix(guardianPincodeCtrl, subtitleColor),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter pincode';
                    if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'Pincode must be exactly 6 digits';
                    return null;
                  },
                  onChanged: (v) => _fetchPincodeData(
                      v, guardianPincodeCtrl, guardianCityCtrl, guardianStateCtrl, guardianCountryCtrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField('City *', guardianCityCtrl, textColor,
                    subtitleColor, borderColor, primaryColor,
                    validator: _requiredFieldValidator('city')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField('State *', guardianStateCtrl, textColor,
                    subtitleColor, borderColor, primaryColor,
                    validator: _requiredFieldValidator('state')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField('Country *', guardianCountryCtrl, textColor,
                    subtitleColor, borderColor, primaryColor,
                    validator: _requiredFieldValidator('country')),
              ),
            ],
          ),
          if (_needsGuardianDoc(dob, guardianRelation)) ...[
            const SizedBox(height: 16),
            _buildGuardianDocPicker(
                index, textColor, subtitleColor, borderColor, primaryColor),
          ],
        ],
      ],
    );
  }

  Widget _buildGuardianDocPicker(
    int slot,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color primaryColor,
  ) {
    final file = _guardianDocForSlot(slot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Guardian Document * (PDF only, max 5 MB)',
            style: MyntWebTextStyles.bodySmall(context,
                color: textColor, fontWeight: MyntFonts.medium)
                .copyWith(decoration: TextDecoration.none)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickGuardianDoc(slot),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_file, size: 18, color: subtitleColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    file?.name ?? 'Upload guardian document (PDF)',
                    overflow: TextOverflow.ellipsis,
                    style: MyntWebTextStyles.bodySmall(context,
                            color: file == null ? subtitleColor : textColor)
                        .copyWith(decoration: TextDecoration.none),
                  ),
                ),
                if (file != null)
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: subtitleColor),
                    splashRadius: 16,
                    tooltip: 'Remove',
                    onPressed: () => _setGuardianDocForSlot(slot, null),
                  )
                else
                  Text('Browse',
                      style: MyntWebTextStyles.bodySmall(context,
                              color: primaryColor,
                              fontWeight: MyntFonts.medium)
                          .copyWith(decoration: TextDecoration.none)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  FORM FIELD BUILDERS
  // ═══════════════════════════════════════════════════════════════════

  String? Function(String?) _requiredFieldValidator(String fieldName) =>
      (String? v) =>
          (v == null || v.trim().isEmpty) ? 'Please enter $fieldName' : null;

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color primaryColor, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? suffixIcon,
    bool enabled = true,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: MyntWebTextStyles.bodySmall(context,
                color: textColor, fontWeight: MyntFonts.medium)
                .copyWith(decoration: TextDecoration.none)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: enabled ? validator : null,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          enabled: enabled,
          onChanged: onChanged,
          style: MyntWebTextStyles.body(context,
              color: enabled ? textColor : textColor.withValues(alpha: 0.5))
              .copyWith(decoration: TextDecoration.none),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: resolveThemeColor(context,
                  dark: MyntColors.errorDark, light: MyntColors.error)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  Future<DateTime?> _showCustomDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        DateTime displayMonth = DateTime(initialDate.year, initialDate.month);
        DateTime? selectedDate;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final primaryColor = resolveThemeColor(ctx,
                dark: MyntColors.secondary, light: MyntColors.primary);
            final textColor = resolveThemeColor(ctx,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary);
            final secondaryTextColor = resolveThemeColor(ctx,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary);
            final cardColor = resolveThemeColor(ctx,
                dark: MyntColors.cardDark, light: MyntColors.card);
            final borderColor = resolveThemeColor(ctx,
                dark: MyntColors.cardBorderDark,
                light: MyntColors.cardBorder);

            final monthName = DateFormat('MMMM yyyy').format(displayMonth);
            final daysInMonth =
                DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
            final firstWeekday =
                DateTime(displayMonth.year, displayMonth.month, 1).weekday % 7;
            final today = DateTime.now();
            final dayHeaders = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

            return Dialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Month header with navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () {
                            setDialogState(() {
                              displayMonth = DateTime(displayMonth.year,
                                  displayMonth.month - 1);
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.chevron_left,
                                size: 20, color: secondaryTextColor),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            // Show year picker on tapping month name
                            final year = await showDialog<int>(
                              context: ctx,
                              builder: (yearCtx) {
                                final yearCardColor = resolveThemeColor(yearCtx,
                                    dark: MyntColors.cardDark,
                                    light: MyntColors.card);
                                final yearBorderColor = resolveThemeColor(
                                    yearCtx,
                                    dark: MyntColors.cardBorderDark,
                                    light: MyntColors.cardBorder);
                                return Dialog(
                                  backgroundColor: yearCardColor,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  child: Container(
                                    width: 280,
                                    height: 300,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: yearBorderColor),
                                    ),
                                    child: GridView.builder(
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        childAspectRatio: 2,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                      ),
                                      itemCount: lastDate.year -
                                          firstDate.year +
                                          1,
                                      itemBuilder: (_, index) {
                                        final y =
                                            lastDate.year - index;
                                        final isSelected = y ==
                                            displayMonth.year;
                                        return InkWell(
                                          onTap: () => Navigator.pop(
                                              yearCtx, y),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  8),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? primaryColor
                                                  : null,
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(8),
                                              border: Border.all(
                                                  color: isSelected
                                                      ? primaryColor
                                                      : yearBorderColor),
                                            ),
                                            alignment:
                                                Alignment.center,
                                            child: Text(
                                              '$y',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.w500,
                                                color: isSelected
                                                    ? Colors.white
                                                    : textColor,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                            if (year != null) {
                              setDialogState(() {
                                displayMonth = DateTime(
                                    year, displayMonth.month);
                              });
                            }
                          },
                          child: Text(
                            monthName,
                            style: MyntWebTextStyles.body(ctx,
                                darkColor: MyntColors.textPrimaryDark,
                                lightColor: MyntColors.textPrimary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setDialogState(() {
                              displayMonth = DateTime(displayMonth.year,
                                  displayMonth.month + 1);
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.chevron_right,
                                size: 20, color: secondaryTextColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Day headers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: dayHeaders
                          .map((d) => SizedBox(
                                width: 34,
                                child: Center(
                                  child: Text(d,
                                      style: MyntWebTextStyles.para(ctx,
                                          darkColor:
                                              MyntColors.textSecondaryDark,
                                          lightColor:
                                              MyntColors.textSecondary,
                                          fontWeight: FontWeight.w500)),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    // Day grid
                    ...List.generate(6, (weekIndex) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(7, (dayIndex) {
                          final dayNum =
                              weekIndex * 7 + dayIndex - firstWeekday + 1;
                          if (dayNum < 1 || dayNum > daysInMonth) {
                            return const SizedBox(width: 34, height: 34);
                          }

                          final date = DateTime(displayMonth.year,
                              displayMonth.month, dayNum);
                          final isToday = date.year == today.year &&
                              date.month == today.month &&
                              date.day == today.day;
                          final isBeforeFirst = date.isBefore(firstDate);
                          final isAfterLast = date.isAfter(lastDate);
                          final isDisabled =
                              isBeforeFirst || isAfterLast;
                          final isSelected = selectedDate != null &&
                              date.year == selectedDate!.year &&
                              date.month == selectedDate!.month &&
                              date.day == selectedDate!.day;

                          Color? bgColor;
                          Color dayTextColor = textColor;

                          if (isSelected) {
                            bgColor = primaryColor;
                            dayTextColor = Colors.white;
                          }

                          if (isDisabled) {
                            dayTextColor = secondaryTextColor
                                .withValues(alpha: 0.4);
                          }

                          return GestureDetector(
                            onTap: isDisabled
                                ? null
                                : () {
                                    setDialogState(() {
                                      selectedDate = date;
                                    });
                                  },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: bgColor,
                                shape: isSelected
                                    ? BoxShape.circle
                                    : BoxShape.rectangle,
                                borderRadius:
                                    isSelected ? null : BorderRadius.zero,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: dayTextColor,
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                    const SizedBox(height: 16),
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel',
                              style: TextStyle(color: secondaryTextColor)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: selectedDate != null
                              ? () => Navigator.pop(ctx, selectedDate)
                              : null,
                          child: Text('OK',
                              style: TextStyle(
                                
                                  color: selectedDate != null
                                      ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary)
                                      : secondaryTextColor)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color primaryColor, {
    String? helperText,
    bool required = true,
  }) {
    final errorColor = resolveThemeColor(context,
        dark: MyntColors.errorDark, light: MyntColors.error);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: label,
                  style: MyntWebTextStyles.bodySmall(context,
                      color: textColor, fontWeight: MyntFonts.medium)
                      .copyWith(decoration: TextDecoration.none)),
              if (helperText != null)
                TextSpan(
                    text: ' $helperText',
                    style: MyntWebTextStyles.caption(context,
                        color: subtitleColor)
                        .copyWith(decoration: TextDecoration.none, fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        FormField<DateTime>(
          initialValue: value,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: required ? (v) => v == null ? 'Please select ${label.replaceAll(' *', '').toLowerCase()}' : null : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await _showCustomDatePicker(
                    initialDate: value ?? DateTime(2000),
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    onChanged(picked);
                    field.didChange(picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: field.hasError ? errorColor : borderColor,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16,
                          color: field.hasError ? errorColor : subtitleColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          value != null
                              ? DateFormat('yyyy-MM-dd').format(value)
                              : 'Select date',
                          style: MyntWebTextStyles.body(context,
                              color: value != null
                                  ? textColor
                                  : (field.hasError
                                      ? errorColor
                                      : subtitleColor))
                              .copyWith(decoration: TextDecoration.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    field.errorText!,
                    style: TextStyle(color: errorColor, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color primaryColor,
  ) {
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: MyntWebTextStyles.bodySmall(context,
                color: textColor, fontWeight: MyntFonts.medium)
                .copyWith(decoration: TextDecoration.none)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value != null && items.contains(value) ? value : null,
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e,
                        style: MyntWebTextStyles.body(context, color: textColor)
                            .copyWith(decoration: TextDecoration.none)),
                  ))
              .toList(),
          onChanged: onChanged,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) => (v == null || v.isEmpty) ? 'Please select ${label.replaceAll(' *', '').toLowerCase()}' : null,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: resolveThemeColor(context,
                  dark: MyntColors.errorDark, light: MyntColors.error)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: resolveThemeColor(context,
                  dark: MyntColors.errorDark, light: MyntColors.error)),
            ),
          ),
          dropdownColor: cardBg,
        ),
      ],
    );
  }
}
