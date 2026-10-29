// Models for the withdraw screen: Noren GetMaxPayoutAmount and the backend
// `/withdraw/payment`, `/withdraw/cancel` and `/withdraw/requests` calls.
//
// Every field is parsed defensively: the backend sends numbers as either
// strings or numbers, and fields go missing when their value is zero.

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty || s == 'null' || s == 'undefined') return 0.0;
  return double.tryParse(s.replaceAll(',', '')) ?? 0.0;
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

String? _toStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s == 'null' ? null : s;
}

/// Noren `GetMaxPayoutAmount`: the most the client can withdraw right now.
///
/// Not to be confused with the Limits `payout` field, which is the amount
/// already requested today.
class MaxPayoutModel {
  final String? stat;
  final String? emsg;
  final String? requestTime;
  final String? actid;
  final String? payout;

  const MaxPayoutModel({
    this.stat,
    this.emsg,
    this.requestTime,
    this.actid,
    this.payout,
  });

  factory MaxPayoutModel.fromJson(Map<String, dynamic> json) => MaxPayoutModel(
        stat: _toStr(json['stat']),
        emsg: _toStr(json['emsg']),
        requestTime: _toStr(json['request_time']),
        actid: _toStr(json['actid']),
        payout: _toStr(json['payout']),
      );

  bool get isOk => stat == 'Ok';

  bool get isSessionExpired =>
      (emsg ?? '').toLowerCase().contains('session expired');

  /// Withdrawable amount. Negative values are shown as zero.
  double get amount {
    final v = _toDouble(payout);
    return v.isFinite && v > 0 ? v : 0.0;
  }
}

/// Lifecycle of a backend withdraw request, grouped the way the screen shows
/// it.
enum WithdrawStatusGroup { pending, processed, cancelled, replaced, review, failed }

/// One row from `/withdraw/requests`.
class WithdrawRequest {
  final int? id;
  final String? clientid;
  final String? companyCode;
  final double amount;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final String? remarks;

  const WithdrawRequest({
    this.id,
    this.clientid,
    this.companyCode,
    this.amount = 0.0,
    this.status = '',
    this.createdAt,
    this.updatedAt,
    this.remarks,
  });

  factory WithdrawRequest.fromJson(Map<String, dynamic> json) =>
      WithdrawRequest(
        id: _toInt(json['id']),
        clientid: _toStr(json['clientid']),
        companyCode: _toStr(json['company_code']),
        amount: _toDouble(json['amount']),
        status: (_toStr(json['status']) ?? '').trim().toUpperCase(),
        createdAt: _toStr(json['created_at']),
        updatedAt: _toStr(json['updated_at']),
        remarks: _toStr(json['remarks']),
      );

  /// Only PLACED requests can be cancelled, and only with a known id.
  bool get isCancellable => status == 'PLACED' && id != null;

  bool get isPlaced => status == 'PLACED';

  bool get isCompleted => status == 'COMPLETED';

  /// Still in flight: pending, or cancelling / under review. Processed,
  /// cancelled, replaced and failed requests are final.
  bool get isActive =>
      group == WithdrawStatusGroup.pending ||
      group == WithdrawStatusGroup.review;

  WithdrawStatusGroup get group {
    switch (status) {
      case 'INITIATED':
      case 'BLOCKED':
      case 'PLACED':
        return WithdrawStatusGroup.pending;
      case 'COMPLETED':
        return WithdrawStatusGroup.processed;
      case 'CANCELLED':
      case 'ROLLED_BACK':
        return WithdrawStatusGroup.cancelled;
      case 'SUPERSEDED':
        return WithdrawStatusGroup.replaced;
      case 'BLOCK_FAILED':
        return WithdrawStatusGroup.failed;
      case 'CANCELLING':
      case 'NEEDS_ATTENTION':
      default:
        // An unknown status is shown as "Under review" rather than guessed.
        return WithdrawStatusGroup.review;
    }
  }

  String get statusLabel {
    switch (group) {
      case WithdrawStatusGroup.pending:
        return 'Pending';
      case WithdrawStatusGroup.processed:
        return 'Processed';
      case WithdrawStatusGroup.cancelled:
        return 'Cancelled';
      case WithdrawStatusGroup.replaced:
        return 'Replaced';
      case WithdrawStatusGroup.failed:
        return 'Failed';
      case WithdrawStatusGroup.review:
        return 'Under review';
    }
  }
}

/// Response of `/withdraw/payment` and `/withdraw/cancel`, plus the
/// unencrypted session errors the backend can return instead.
class WithdrawActionResponse {
  final String? msg;
  final int? requestId;
  final String? status;

  /// Set when the backend answered with a session error (`emsg`, no `str`).
  final String? emsg;
  final int? httpStatus;

  const WithdrawActionResponse({
    this.msg,
    this.requestId,
    this.status,
    this.emsg,
    this.httpStatus,
  });

  factory WithdrawActionResponse.fromJson(Map<String, dynamic> json,
          {int? httpStatus}) =>
      WithdrawActionResponse(
        msg: _toStr(json['msg']),
        requestId: _toInt(json['request_id']),
        status: _toStr(json['status'])?.trim().toUpperCase(),
        emsg: _toStr(json['emsg']),
        httpStatus: httpStatus,
      );

  /// `"Sucess"` is the backoffice spelling; compare against it exactly.
  bool get isPlaced => msg == 'Sucess';

  bool get isCancelled => status == 'CANCELLED';

  bool get isUnderReview => status == 'NEEDS_ATTENTION';

  bool get isSessionError => emsg != null && msg == null;

  bool get isValidationUnavailable => httpStatus == 503;

  bool get isInProgress =>
      (msg ?? '').toLowerCase().contains('already in progress');

  bool get isStale =>
      (msg ?? '').toLowerCase().contains('updated by someone else');
}

/// Result of `/withdraw/requests`. [emsg] is set on a session error so the
/// screen can tell "no rows" apart from "could not load".
class WithdrawRequestsResult {
  final List<WithdrawRequest> requests;
  final String? emsg;
  final int? httpStatus;

  const WithdrawRequestsResult(
      {this.requests = const [], this.emsg, this.httpStatus});

  bool get isSessionError => emsg != null;
}
