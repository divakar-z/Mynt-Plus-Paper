class ProfileAllDetails {
  ClientData? clientData;
  List<BankData>? bankData;
  List<NomineeDetails>? nomineeData;

  ProfileAllDetails({this.clientData, this.bankData, this.nomineeData});

  ProfileAllDetails.fromJson(Map<String, dynamic> json) {
    clientData = json['client_data'] != null
        ? ClientData.fromJson(json['client_data'])
        : null;
    if (json['bank_data'] != null) {
      bankData = <BankData>[];
      json['bank_data'].forEach((v) {
        bankData!.add(BankData.fromJson(v));
      });
    }
    if (json['nominee_data'] != 'error') {
      nomineeData = <NomineeDetails>[];
      json['nominee_data'].forEach((v) {
        nomineeData!.add(NomineeDetails.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (clientData != null) {
      data['client_data'] = clientData!.toJson();
    }
    if (bankData != null) {
      data['bank_data'] = bankData!.map((v) => v.toJson()).toList();
    }
    data['nominee_data'] = nomineeData!.map((v) => v.toJson()).toList();
    return data;
  }
}

class ClientData {
  String? cLIENTID;
  String? cLIENTNAME;
  String? mOBILENO;
  String? cLIENTIDMAIL;
  String? pANNO;
  String? aadharCard;
  String? cLRESIADD1;
  String? cLRESIADD2;
  String? cLRESIADD3;
  String? dPNAME;
  String? cLIENTDPCODE;
  String? dPID;
  String? pOA;
  String? dPACTIVE;
  String? aNNUALINCOME;
  String? grossAnnualIncomeDate;
  String? netWorthDate;
  String? kRASTATUS;
  String? fORMNO;
  String? ckycrefno;
  String? nomineeName;
  String? nomineeDOB;
  String? nomineePan;
  String? nomineePhone;
  String? nomineeRelation;
  String? nomineeAddress;
  String? nomineeOptOut;
  String? dDPI;
  String? ddpiMarginPledge;
  String? ddpiBuyBack;
  String? mFTInterest;
  String? mFTMaxAmount;
  String? mFTScripMaxAmount;
  String? mTFCl;
  String? mTFClAuto;
  String? panName;
  String? sEX;
  String? bIRTHDATE;
  String? oCCUPATION;
  String? maritalStatus;
  String? cATEGORY;
  List<SegmentsData>? segmentsData;
  
  bool get isIndividual => cATEGORY == 'I';

  /// True when BIRTH_DATE shows the holder is under 18.
  /// Accepts yyyy-MM-dd[...], dd/MM/yyyy, dd-MM-yyyy and dd-MMM-yyyy;
  /// an unparseable date is treated as not minor.
  bool get isMinor {
    final dob = _parseBirthDate(bIRTHDATE);
    if (dob == null) return false;
    final now = DateTime.now();
    final eighteenth = DateTime(dob.year + 18, dob.month, dob.day);
    return now.isBefore(eighteenth);
  }

  static DateTime? _parseBirthDate(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty || s == 'null') return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final parts = s.split(RegExp(r'[/\-\s]+'));
    if (parts.length < 3) return null;
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun',
        'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]) ??
        (months.indexOf(parts[1].toLowerCase().substring(
                0, parts[1].length < 3 ? parts[1].length : 3)) + 1);
    final year = int.tryParse(parts[2]);
    if (day == null || year == null || month < 1 || month > 12) return null;
    return DateTime(year, month, day);
  }

  /// Derived account-closed flag
  /// Scans segments_data[].inactivetype_DESC for closure markers
  /// ("Close Client-Close" / "close-Close"), normalized for case + whitespace.
  bool get isClientClosed {
    final segs = segmentsData;
    if (segs == null) return false;
    for (final s in segs) {
      final desc = s.inactivetypeDESC?.trim().toLowerCase() ?? '';
      if (desc == 'close client-close' || desc == 'close-close') {
        return true;
      }
    }
    return false;
  }

  ClientData(
      {this.cLIENTID,
      this.cLIENTNAME,
      this.mOBILENO,
      this.cLIENTIDMAIL,
      this.pANNO,
      this.aadharCard,
      this.cLRESIADD1,
      this.cLRESIADD2,
      this.cLRESIADD3,
      this.dPNAME,
      this.cLIENTDPCODE,
      this.dPID,
      this.pOA,
      this.dPACTIVE,
      this.aNNUALINCOME,
      this.grossAnnualIncomeDate,
      this.netWorthDate,
      this.kRASTATUS,
      this.fORMNO,
      this.ckycrefno,
      this.nomineeName,
      this.nomineeDOB,
      this.nomineePan,
      this.nomineePhone,
      this.nomineeRelation,
      this.nomineeAddress,
      this.nomineeOptOut,
      this.dDPI,
      this.ddpiMarginPledge,
      this.ddpiBuyBack,
      this.mFTInterest,
      this.mFTMaxAmount,
      this.mFTScripMaxAmount,
      this.mTFCl,
      this.mTFClAuto,
      this.panName,
      this.sEX,
      this.bIRTHDATE,
      this.oCCUPATION,
      this.maritalStatus,
      this.segmentsData});

  ClientData.fromJson(Map<String, dynamic> json) {
    cLIENTID = json['CLIENT_ID'].toString();
    cLIENTNAME = json['CLIENT_NAME'].toString();
    mOBILENO = json['MOBILE_NO'].toString();
    cLIENTIDMAIL = json['CLIENT_ID_MAIL'].toString();
    pANNO = json['PAN_NO'].toString();
    aadharCard = json['AadharCard'].toString();
    cLRESIADD1 = json['CL_RESI_ADD1'].toString();
    cLRESIADD2 = json['CL_RESI_ADD2'].toString();
    cLRESIADD3 = json['CL_RESI_ADD3'].toString();
    dPNAME = json['DP_NAME'].toString();
    cLIENTDPCODE = json['CLIENT_DP_CODE'].toString();
    dPID = json['DP_ID'].toString();
    pOA = json['POA'].toString();
    dPACTIVE = json['DP_ACTIVE'].toString();
    aNNUALINCOME = json['ANNUAL_INCOME'].toString();
    grossAnnualIncomeDate = json['GrossAnnualIncomeDate'].toString();
    netWorthDate = json['Net_Worth_Date'].toString();
    kRASTATUS = json['KRA_STATUS'].toString();
    fORMNO = json['FORM_NO'].toString();
    ckycrefno = json['ckycrefno'].toString();
    nomineeName = json['Nominee_Name'].toString();
    nomineeDOB = json['Nominee_DOB'].toString();
    nomineePan = json['Nominee_pan'].toString();
    nomineePhone = json['Nominee_phone'].toString();
    nomineeRelation = json['Nominee_Relation'].toString();
    nomineeAddress = json['Nominee_address'].toString();
    nomineeOptOut = json['NomineeOptOut'].toString();
    dDPI = json['DDPI'].toString();
    ddpiMarginPledge = json['ddpi_margin_pledge'].toString();
    ddpiBuyBack = json['ddpi_buy_back'].toString();
    mFTInterest = json['MFT_Interest'].toString();
    mFTMaxAmount = json['MFT_Max_Amount'].toString();
    mFTScripMaxAmount = json['MFT_Scrip_Max_Amount'].toString();
    mTFCl = json['MTFCl'].toString();
    mTFClAuto = json['MTFClAuto'].toString();
    panName = json['Pan_Name'].toString();
    sEX = json['SEX'].toString();
    bIRTHDATE = json['BIRTH_DATE'].toString();
    oCCUPATION = json['OCCUPATION'].toString();
    maritalStatus = json['Marital_status'].toString();
    cATEGORY = json['CATEGORY']?.toString();
    if (json['segments_data'] != null) {
      segmentsData = <SegmentsData>[];
      json['segments_data'].forEach((v) {
        segmentsData!.add(SegmentsData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['CLIENT_ID'] = cLIENTID;
    data['CLIENT_NAME'] = cLIENTNAME;
    data['MOBILE_NO'] = mOBILENO;
    data['CLIENT_ID_MAIL'] = cLIENTIDMAIL;
    data['PAN_NO'] = pANNO;
    data['AadharCard'] = aadharCard;
    data['CL_RESI_ADD1'] = cLRESIADD1;
    data['CL_RESI_ADD2'] = cLRESIADD2;
    data['CL_RESI_ADD3'] = cLRESIADD3;
    data['DP_NAME'] = dPNAME;
    data['CLIENT_DP_CODE'] = cLIENTDPCODE;
    data['DP_ID'] = dPID;
    data['POA'] = pOA;
    data['DP_ACTIVE'] = dPACTIVE;
    data['ANNUAL_INCOME'] = aNNUALINCOME;
    data['GrossAnnualIncomeDate'] = grossAnnualIncomeDate;
    data['Net_Worth_Date'] = netWorthDate;
    data['KRA_STATUS'] = kRASTATUS;
    data['FORM_NO'] = fORMNO;
    data['ckycrefno'] = ckycrefno;
    data['Nominee_Name'] = nomineeName;
    data['Nominee_DOB'] = nomineeDOB;
    data['Nominee_pan'] = nomineePan;
    data['Nominee_phone'] = nomineePhone;
    data['Nominee_Relation'] = nomineeRelation;
    data['Nominee_address'] = nomineeAddress;
    data['NomineeOptOut'] = nomineeOptOut;
    data['DDPI'] = dDPI;
    data['ddpi_margin_pledge'] = ddpiMarginPledge;
    data['ddpi_buy_back'] = ddpiBuyBack;
    data['MFT_Interest'] = mFTInterest;
    data['MFT_Max_Amount'] = mFTMaxAmount;
    data['MFT_Scrip_Max_Amount'] = mFTScripMaxAmount;
    data['MTFCl'] = mTFCl;
    data['MTFClAuto'] = mTFClAuto;
    data['Pan_Name'] = panName;
    data['SEX'] = sEX;
    data['BIRTH_DATE'] = bIRTHDATE;
    data['OCCUPATION'] = oCCUPATION;
    data['Marital_status'] = maritalStatus;
    data['CATEGORY'] = cATEGORY;
    if (segmentsData != null) {
      data['segments_data'] = segmentsData!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class SegmentsData {
  String? cOMPANYCODE;
  String? aCTIVEINACTIVE;
  String? exchangeACTIVEINACTIVE;
  String? inactivetypeDESC;
  String? rEGISTRATIONDATE;

  SegmentsData(
      {this.cOMPANYCODE,
      this.aCTIVEINACTIVE,
      this.exchangeACTIVEINACTIVE,
      this.inactivetypeDESC,
      this.rEGISTRATIONDATE});

  SegmentsData.fromJson(Map<String, dynamic> json) {
    cOMPANYCODE = json['COMPANY_CODE'].toString();
    aCTIVEINACTIVE = json['ACTIVE_INACTIVE'].toString();
    exchangeACTIVEINACTIVE = json['Exchange_ACTIVE_INACTIVE'].toString();
    inactivetypeDESC = json['inactivetype_DESC'].toString();
    rEGISTRATIONDATE = json['REGISTRATION_DATE'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['COMPANY_CODE'] = cOMPANYCODE;
    data['ACTIVE_INACTIVE'] = aCTIVEINACTIVE;
    data['Exchange_ACTIVE_INACTIVE'] = exchangeACTIVEINACTIVE;
    data['inactivetype_DESC'] = inactivetypeDESC;
    data['REGISTRATION_DATE'] = rEGISTRATIONDATE;
    return data;
  }
}

class BankData {
  String? accountCode;
  String? bankName;
  String? bankAcNo;
  String? iFSCCode;
  String? micrCode;
  String? defaultAc;
  String? bANKACCTYPE;
  String? bankActive;

  BankData(
      {this.accountCode,
      this.bankName,
      this.bankAcNo,
      this.iFSCCode,
      this.micrCode,
      this.defaultAc,
      this.bANKACCTYPE,
      this.bankActive});

  BankData.fromJson(Map<String, dynamic> json) {
    accountCode = json['Account_Code'].toString();
    bankName = json['Bank_Name'].toString();
    bankAcNo = json['Bank_AcNo'].toString();
    iFSCCode = json['IFSC_Code'].toString();
    micrCode = json['Micr_code'].toString();
    defaultAc = json['Default_Ac'].toString();
    bANKACCTYPE = json['BANK_ACCTYPE'].toString();
    bankActive = json['BankActive'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['Account_Code'] = accountCode;
    data['Bank_Name'] = bankName;
    data['Bank_AcNo'] = bankAcNo;
    data['IFSC_Code'] = iFSCCode;
    data['Micr_code'] = micrCode;
    data['Default_Ac'] = defaultAc;
    data['BANK_ACCTYPE'] = bANKACCTYPE;
    data['BankActive'] = bankActive;
    return data;
  }
}

class NomineeDetails {
  String? cLIENTID;
  String? nominationName;
  String? nomRelation;
  String? nomPan;
  String? nomAddress;
  String? nomPhone;
  String? nomDOB;
  String? nOMEMAIL;
  String? nOMINEEPINCODE;
  String? nomCity;
  String? nomState;
  String? nomAddress2;
  String? nomAddress3;
  String? aadharCardNominee;
  String? sharePercentage;
  String? nomineeTelno;
  String? noOfNominee;
  String? nomMinor2;
  String? nomMinor3;
  String? aadharCardNominee2;
  String? aadharCardNominee3;
  String? nomCity2;
  String? nomCountry;
  String? nomCountry2;
  String? nomCountry3;
  String? nomDOB2;
  String? nomDOB3;
  String? nomEmail2;
  String? nomEmail3;
  String? nomPan2;
  String? nomPan3;
  String? nomPhone2;
  String? nomPhone3;
  String? nomRelation2;
  String? nomRelation3;
  String? nomState3;
  String? nomCity3;
  String? nomState2;
  String? nom3Address;
  String? nom3Address2;
  String? nominationName2;
  String? nominationName3;
  String? nomineePinCode2;
  String? nomineePinCode3;
  String? sameRegAddForNom2;
  String? sameRegAddForNom3;
  String? sharePercentage2;
  String? sharePercentage3;
  String? nOMINATIONTITLE;
  String? nOMINATIONTITLE2;
  String? nOMINATIONTITLE3;
  String? nomProofId;
  String? nomProofDetails;
  String? nomProofId2;
  String? nomProofDetails2;
  String? nomProofId3;
  String? nom3Address3;
  String? nom2Address;
  String? nom2Address2;
  String? nom2Address3;
  String? nomineeOptOut;
  String? relationShip;

  NomineeDetails(
      {this.cLIENTID,
      this.nominationName,
      this.nomRelation,
      this.nomPan,
      this.nomAddress,
      this.nomPhone,
      this.nomDOB,
      this.nOMEMAIL,
      this.nOMINEEPINCODE,
      this.nomCity,
      this.nomState,
      this.nomAddress2,
      this.nomAddress3,
      this.aadharCardNominee,
      this.sharePercentage,
      this.nomineeTelno,
      this.noOfNominee,
      this.nomMinor2,
      this.nomMinor3,
      this.aadharCardNominee2,
      this.aadharCardNominee3,
      this.nomCity2,
      this.nomCountry,
      this.nomCountry2,
      this.nomCountry3,
      this.nomDOB2,
      this.nomDOB3,
      this.nomEmail2,
      this.nomEmail3,
      this.nomPan2,
      this.nomPan3,
      this.nomPhone2,
      this.nomPhone3,
      this.nomRelation2,
      this.nomRelation3,
      this.nomState3,
      this.nomCity3,
      this.nomState2,
      this.nom3Address,
      this.nom3Address2,
      this.nominationName2,
      this.nominationName3,
      this.nomineePinCode2,
      this.nomineePinCode3,
      this.sameRegAddForNom2,
      this.sameRegAddForNom3,
      this.sharePercentage2,
      this.sharePercentage3,
      this.nOMINATIONTITLE,
      this.nOMINATIONTITLE2,
      this.nOMINATIONTITLE3,
      this.nomProofId,
      this.nomProofDetails,
      this.nomProofId2,
      this.nomProofDetails2,
      this.nomProofId3,
      this.nom3Address3,
      this.nom2Address,
      this.nom2Address2,
      this.nom2Address3,
      this.nomineeOptOut,
      this.relationShip});

  NomineeDetails.fromJson(Map<String, dynamic> json) {
    cLIENTID = json['CLIENT_ID'].toString();
    nominationName = json['Nomination_Name'].toString();
    nomRelation = json['Nom_Relation'].toString();
    nomPan = json['Nom_pan'].toString();
    nomAddress = json['Nom_address'].toString();
    nomPhone = json['Nom_Phone'].toString();
    nomDOB = json['Nom_DOB'].toString();
    nOMEMAIL = json['NOM_EMAIL'].toString();
    nOMINEEPINCODE = json['NOMINEE_PIN_CODE'];
    nomCity = json['Nom_City'].toString();
    nomState = json['Nom_State'].toString();
    nomAddress2 = json['Nom_address2'].toString();
    nomAddress3 = json['Nom_address3'].toString();
    aadharCardNominee = json['AadharCard_Nominee'].toString();
    sharePercentage = json['Share_Percentage'].toString();
    nomineeTelno = json['nominee_telno'].toString();
    noOfNominee = json['No_Of_Nominee'].toString();
    nomMinor2 = json['Nom_minor2'].toString();
    nomMinor3 = json['Nom_minor3'].toString();
    aadharCardNominee2 = json['AadharCard_Nominee2'].toString();
    aadharCardNominee3 = json['AadharCard_Nominee3'].toString();
    nomCity2 = json['Nom_City2'].toString();
    nomCountry = json['Nom_country'].toString();
    nomCountry2 = json['Nom_country2'].toString();
    nomCountry3 = json['Nom_country3'].toString();
    nomDOB2 = json['Nom_DOB2'].toString();
    nomDOB3 = json['Nom_DOB3'].toString();
    nomEmail2 = json['Nom_Email2'].toString();
    nomEmail3 = json['Nom_Email3'].toString();
    nomPan2 = json['Nom_pan2'].toString();
    nomPan3 = json['Nom_pan3'].toString();
    nomPhone2 = json['Nom_Phone2'].toString();
    nomPhone3 = json['Nom_Phone3'].toString();
    nomRelation2 = json['Nom_Relation2'].toString();
    nomRelation3 = json['Nom_Relation3'].toString();
    nomState3 = json['Nom_State3'].toString();
    nomCity3 = json['Nom_City3'].toString();
    nomState2 = json['Nom_State2'].toString();
    nom3Address = json['Nom3_address'].toString();
    nom3Address2 = json['Nom3_address2'].toString();
    nominationName2 = json['Nomination_Name2'].toString();
    nominationName3 = json['Nomination_Name3'].toString();
    nomineePinCode2 = json['Nominee_Pin_Code2'].toString();
    nomineePinCode3 = json['Nominee_Pin_Code3'].toString();
    sameRegAddForNom2 = json['SameRegAddFor_Nom2'].toString();
    sameRegAddForNom3 = json['SameRegAddFor_Nom3'].toString();
    sharePercentage2 = json['Share_Percentage2'].toString();
    sharePercentage3 = json['Share_Percentage3'].toString();
    nOMINATIONTITLE = json['NOMINATION_TITLE'].toString();
    nOMINATIONTITLE2 = json['NOMINATION_TITLE2'].toString();
    nOMINATIONTITLE3 = json['NOMINATION_TITLE3'].toString();
    nomProofId = json['Nom_proof_id'].toString();
    nomProofDetails = json['Nom_proof_details'].toString();
    nomProofId2 = json['Nom_proof_id2'].toString();
    nomProofDetails2 = json['Nom_proof_details2'].toString();
    nomProofId3 = json['Nom_proof_id3'].toString();
    nom3Address3 = json['Nom3_address3'].toString();
    nom2Address = json['Nom2_address'].toString();
    nom2Address2 = json['Nom2_address2'].toString();
    nom2Address3 = json['Nom2_address3'].toString();
    nomineeOptOut = json['NomineeOptOut'].toString();
    relationShip = json['RelationShip'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['CLIENT_ID'] = cLIENTID;
    data['Nomination_Name'] = nominationName;
    data['Nom_Relation'] = nomRelation;
    data['Nom_pan'] = nomPan;
    data['Nom_address'] = nomAddress;
    data['Nom_Phone'] = nomPhone;
    data['Nom_DOB'] = nomDOB;
    data['NOM_EMAIL'] = nOMEMAIL;
    data['NOMINEE_PIN_CODE'] = nOMINEEPINCODE;
    data['Nom_City'] = nomCity;
    data['Nom_State'] = nomState;
    data['Nom_address2'] = nomAddress2;
    data['Nom_address3'] = nomAddress3;
    data['AadharCard_Nominee'] = aadharCardNominee;
    data['Share_Percentage'] = sharePercentage;
    data['nominee_telno'] = nomineeTelno;
    data['No_Of_Nominee'] = noOfNominee;
    data['Nom_minor2'] = nomMinor2;
    data['Nom_minor3'] = nomMinor3;
    data['AadharCard_Nominee2'] = aadharCardNominee2;
    data['AadharCard_Nominee3'] = aadharCardNominee3;
    data['Nom_City2'] = nomCity2;
    data['Nom_country'] = nomCountry;
    data['Nom_country2'] = nomCountry2;
    data['Nom_country3'] = nomCountry3;
    data['Nom_DOB2'] = nomDOB2;
    data['Nom_DOB3'] = nomDOB3;
    data['Nom_Email2'] = nomEmail2;
    data['Nom_Email3'] = nomEmail3;
    data['Nom_pan2'] = nomPan2;
    data['Nom_pan3'] = nomPan3;
    data['Nom_Phone2'] = nomPhone2;
    data['Nom_Phone3'] = nomPhone3;
    data['Nom_Relation2'] = nomRelation2;
    data['Nom_Relation3'] = nomRelation3;
    data['Nom_State3'] = nomState3;
    data['Nom_City3'] = nomCity3;
    data['Nom_State2'] = nomState2;
    data['Nom3_address'] = nom3Address;
    data['Nom3_address2'] = nom3Address2;
    data['Nomination_Name2'] = nominationName2;
    data['Nomination_Name3'] = nominationName3;
    data['Nominee_Pin_Code2'] = nomineePinCode2;
    data['Nominee_Pin_Code3'] = nomineePinCode3;
    data['SameRegAddFor_Nom2'] = sameRegAddForNom2;
    data['SameRegAddFor_Nom3'] = sameRegAddForNom3;
    data['Share_Percentage2'] = sharePercentage2;
    data['Share_Percentage3'] = sharePercentage3;
    data['NOMINATION_TITLE'] = nOMINATIONTITLE;
    data['NOMINATION_TITLE2'] = nOMINATIONTITLE2;
    data['NOMINATION_TITLE3'] = nOMINATIONTITLE3;
    data['Nom_proof_id'] = nomProofId;
    data['Nom_proof_details'] = nomProofDetails;
    data['Nom_proof_id2'] = nomProofId2;
    data['Nom_proof_details2'] = nomProofDetails2;
    data['Nom_proof_id3'] = nomProofId3;
    data['Nom3_address3'] = nom3Address3;
    data['Nom2_address'] = nom2Address;
    data['Nom2_address2'] = nom2Address2;
    data['Nom2_address3'] = nom2Address3;
    data['NomineeOptOut'] = nomineeOptOut;
    data['RelationShip'] = relationShip;
    return data;
  }
}
