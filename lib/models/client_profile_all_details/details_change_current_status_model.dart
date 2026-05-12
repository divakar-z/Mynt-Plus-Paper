class DetailsChangeCurrentStatus {
  String? dDPIClientEmail;
  String? dDPIESignedPdfPath;
  String? dDPIFileid;
  String? dDPISession;
  String? dDPIStatus;
  String? addressClientEmail;
  String? addressESignPath;
  String? addressFileId;
  String? addressSession;
  String? addressStatus;
  String? bankClientEmail;
  String? bankESignPath;
  String? bankFileId;
  String? bankSession;
  String? bankStatus;
  String? clientId;
  String? closureClientEmail;
  String? closureESignedPdfPath1;
  String? closureESignedPdfPath2;
  String? closureFileid;
  String? closureSession;
  String? closureStatus;
  String? emailClientEmail;
  String? emailESignPath;
  String? emailExistingEmailId;
  String? emailFileId;
  String? emailNewEmailId;
  String? emailSession;
  String? emailStatus;
  String? incomeClientEmail;
  String? incomeESignPath;
  String? incomeStatus;
  String? mobClientEmail;
  String? mobSession;
  String? mobileESignPath;
  String? mobileFileId;
  String? mobileStatus;
  String? mtfClientEmail;
  String? mtfESignedPdfPath;
  String? mtfFileid;
  String? mtfSession;
  String? mtfStatus;
  String? segmentClientEmail;
  String? segmentESignPath;
  String? segmentFileId;
  String? segmentSession;
  String? segmentStatus;
  String? accSgtAtveSts;
  bool? last7DaysCheck;
  bool? rekycStatus;

  DetailsChangeCurrentStatus(
      {this.dDPIClientEmail,
      this.dDPIESignedPdfPath,
      this.dDPIFileid,
      this.dDPISession,
      this.dDPIStatus,
      this.addressClientEmail,
      this.addressESignPath,
      this.addressFileId,
      this.addressSession,
      this.addressStatus,
      this.bankClientEmail,
      this.bankESignPath,
      this.bankFileId,
      this.bankSession,
      this.bankStatus,
      this.clientId,
      this.closureClientEmail,
      this.closureESignedPdfPath1,
      this.closureESignedPdfPath2,
      this.closureFileid,
      this.closureSession,
      this.closureStatus,
      this.emailClientEmail,
      this.emailESignPath,
      this.emailExistingEmailId,
      this.emailFileId,
      this.emailNewEmailId,
      this.emailSession,
      this.emailStatus,
      this.incomeClientEmail,
      this.incomeESignPath,
      this.incomeStatus,
      this.mobClientEmail,
      this.mobSession,
      this.mobileESignPath,
      this.mobileFileId,
      this.mobileStatus,
      this.mtfClientEmail,
      this.mtfESignedPdfPath,
      this.mtfFileid,
      this.mtfSession,
      this.mtfStatus,
      this.segmentClientEmail,
      this.segmentESignPath,
      this.segmentFileId,
      this.segmentSession,
      this.segmentStatus,
      this.accSgtAtveSts,
      this.last7DaysCheck,
      this.rekycStatus});

  DetailsChangeCurrentStatus.fromJson(Map<String, dynamic> json) {
    dDPIClientEmail = json['DDPI_client_email'];
    dDPIESignedPdfPath = json['DDPI_e_signed_pdf_path'];
    dDPIFileid = json['DDPI_fileid'];
    dDPISession = json['DDPI_session'];
    dDPIStatus = json['DDPI_status'];
    addressClientEmail = json['address_client_email'];
    addressESignPath = json['address_e_sign_path'];
    addressFileId = json['address_file_id'];
    addressSession = json['address_session'];
    addressStatus = json['address_status'];
    bankClientEmail = json['bank_client_email'];
    bankESignPath = json['bank_e_sign_path'];
    bankFileId = json['bank_file_id'];
    bankSession = json['bank_session'];
    bankStatus = json['bank_status'];
    clientId = json['client_id'];
    closureClientEmail = json['closure_client_email'];
    closureESignedPdfPath1 = json['closure_e_signed_pdf_path_1'];
    closureESignedPdfPath2 = json['closure_e_signed_pdf_path_2'];
    closureFileid = json['closure_fileid'];
    closureSession = json['closure_session'];
    closureStatus = json['closure_status'];
    emailClientEmail = json['email_client_email'];
    emailESignPath = json['email_e_sign_path'];
    emailExistingEmailId = json['email_existing_email_id'];
    emailFileId = json['email_file_id'];
    emailNewEmailId = json['email_new_email_id'];
    emailSession = json['email_session'];
    emailStatus = json['email_status'];
    incomeClientEmail = json['income_client_email'];
    incomeESignPath = json['income_e_sign_path'];
    incomeStatus = json['income_status'];
    mobClientEmail = json['mob_client_email'];
    mobSession = json['mob_session'];
    mobileESignPath = json['mobile_e_sign_path'];
    mobileFileId = json['mobile_file_id'];
    mobileStatus = json['mobile_status'];
    mtfClientEmail = json['mtf_client_email'];
    mtfESignedPdfPath = json['mtf_e_signed_pdf_path'];
    mtfFileid = json['mtf_fileid'];
    mtfSession = json['mtf_session'];
    mtfStatus = json['mtf_status'];
    segmentClientEmail = json['segment_client_email'];
    segmentESignPath = json['segment_e_sign_path'];
    segmentFileId = json['segment_file_id'];
    segmentSession = json['segment_session'];
    segmentStatus = json['segment_status'];
    accSgtAtveSts = json['acc_sgt_atve_sts']?.toString();
    last7DaysCheck = json['last_7_days_check'] is bool
        ? json['last_7_days_check'] as bool
        : json['last_7_days_check']?.toString().toLowerCase() == 'true';
    rekycStatus = json['rekyc_status'] is bool
        ? json['rekyc_status'] as bool
        : json['rekyc_status']?.toString().toLowerCase() == 'true';
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['DDPI_client_email'] = dDPIClientEmail;
    data['DDPI_e_signed_pdf_path'] = dDPIESignedPdfPath;
    data['DDPI_fileid'] = dDPIFileid;
    data['DDPI_session'] = dDPISession;
    data['DDPI_status'] = dDPIStatus;
    data['address_client_email'] = addressClientEmail;
    data['address_e_sign_path'] = addressESignPath;
    data['address_file_id'] = addressFileId;
    data['address_session'] = addressSession;
    data['address_status'] = addressStatus;
    data['bank_client_email'] = bankClientEmail;
    data['bank_e_sign_path'] = bankESignPath;
    data['bank_file_id'] = bankFileId;
    data['bank_session'] = bankSession;
    data['bank_status'] = bankStatus;
    data['client_id'] = clientId;
    data['closure_client_email'] = closureClientEmail;
    data['closure_e_signed_pdf_path_1'] = closureESignedPdfPath1;
    data['closure_e_signed_pdf_path_2'] = closureESignedPdfPath2;
    data['closure_fileid'] = closureFileid;
    data['closure_session'] = closureSession;
    data['closure_status'] = closureStatus;
    data['email_client_email'] = emailClientEmail;
    data['email_e_sign_path'] = emailESignPath;
    data['email_existing_email_id'] = emailExistingEmailId;
    data['email_file_id'] = emailFileId;
    data['email_new_email_id'] = emailNewEmailId;
    data['email_session'] = emailSession;
    data['email_status'] = emailStatus;
    data['income_client_email'] = incomeClientEmail;
    data['income_e_sign_path'] = incomeESignPath;
    data['income_status'] = incomeStatus;
    data['mob_client_email'] = mobClientEmail;
    data['mob_session'] = mobSession;
    data['mobile_e_sign_path'] = mobileESignPath;
    data['mobile_file_id'] = mobileFileId;
    data['mobile_status'] = mobileStatus;
    data['mtf_client_email'] = mtfClientEmail;
    data['mtf_e_signed_pdf_path'] = mtfESignedPdfPath;
    data['mtf_fileid'] = mtfFileid;
    data['mtf_session'] = mtfSession;
    data['mtf_status'] = mtfStatus;
    data['segment_client_email'] = segmentClientEmail;
    data['segment_e_sign_path'] = segmentESignPath;
    data['segment_file_id'] = segmentFileId;
    data['segment_session'] = segmentSession;
    data['segment_status'] = segmentStatus;
    data['acc_sgt_atve_sts'] = accSgtAtveSts;
    data['last_7_days_check'] = last7DaysCheck;
    data['rekyc_status'] = rekycStatus;
    return data;
  }
}
