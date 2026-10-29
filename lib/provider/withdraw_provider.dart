import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/core/api_export.dart';
import '../locator/locator.dart';
import '../models/fund_model_testing_copy/withdraw_request_model.dart';
import '../models/profile_model/fund_detial_model.dart';
import 'auth_provider.dart';
import 'core/default_change_notifier.dart';
import 'fund_provider.dart';
import 'index_list_provider.dart';

/// Withdraw screen state (WITHDRAW_SCREEN_FRONTEND.md). Auto-disposed so a
/// reopened screen never shows the previous visit's balance.
final withdrawProvider =
    ChangeNotifierProvider.autoDispose((ref) => WithdrawProvider(ref));

/// Outcome of placing or cancelling, for the screen to turn into UI.
enum WithdrawActionOutcome {
  success,

  /// Backend or backoffice refused; show [WithdrawActionResult.message].
  rejected,

  /// Another request for this client is still being processed.
  inProgress,

  /// The request changed under us; the list has been reloaded.
  stale,

  /// Session invalid; the user is being sent to login.
  sessionExpired,

  /// Session validation service is down (HTTP 503).
  serviceUnavailable,

  /// No answer (timeout or network). The request may still have gone
  /// through, so the list has been reloaded.
  unknown,

  /// Unexpected server or parse error.
  failed,
}

class WithdrawActionResult {
  final WithdrawActionOutcome outcome;
  final String message;
  final WithdrawActionResponse? response;
  const WithdrawActionResult(this.outcome, this.message, [this.response]);
}

class WithdrawProvider extends DefaultChangeNotifier {
  final Ref ref;
  final api = locator<ApiExporter>();

  WithdrawProvider(this.ref);

  static const _genericError = 'Something went wrong, please try again';
  static const _maxPayoutErrorText =
      'Unable to fetch withdrawable balance, please try again';

  // --- Max payout (authoritative total) ---
  MaxPayoutModel? _maxPayout;
  bool _maxPayoutLoading = false;
  String? _maxPayoutError;

  bool get maxPayoutLoading => _maxPayoutLoading;
  String? get maxPayoutError => _maxPayoutError;

  /// Withdrawable balance, or null while unknown / failed. Never falls back
  /// to the calculated value.
  double? get withdrawable =>
      (_maxPayout != null && _maxPayout!.isOk) ? _maxPayout!.amount : null;

  // --- Limits (breakdown rows) ---
  bool _limitsLoading = false;
  bool _limitsOk = false;
  bool get limitsLoading => _limitsLoading;
  bool get limitsOk => _limitsOk;

  // --- Requests ---
  List<WithdrawRequest> _requests = const [];
  bool _requestsLoading = false;
  bool _requestsLoaded = false;
  String? _requestsError;

  List<WithdrawRequest> get requests => _requests;

  /// Requests still in flight, newest first. The full history lives in
  /// Transaction History.
  List<WithdrawRequest> get activeRequests =>
      _requests.where((r) => r.isActive).toList(growable: false);
  bool get requestsLoading => _requestsLoading;
  bool get requestsLoaded => _requestsLoaded;
  String? get requestsError => _requestsError;

  /// The pending request a new withdrawal would replace, if any.
  WithdrawRequest? get pendingRequest {
    for (final r in _requests) {
      if (r.isPlaced) return r;
    }
    return null;
  }

  // --- Actions ---
  bool _placing = false;
  bool get placing => _placing;

  final Set<int> _cancelling = {};
  bool isCancelling(int? id) => id != null && _cancelling.contains(id);

  /// Set while the backend reports another request in progress; the screen
  /// keeps Continue disabled until the refresh after the cool-down.
  bool _cooldown = false;
  bool get cooldown => _cooldown;
  Timer? _cooldownTimer;

  bool _sessionHandled = false;

  /// The last screen context handed in, for the web `ifSessionExpired`, which
  /// needs one to route to login.
  BuildContext? _context;

  /// For screens that only list requests (Transaction History), so a session
  /// error there can still route to login.
  void attachContext(BuildContext context) => _context = context;

  void _notify() {
    if (!disposed) notifyListeners();
  }

  void _logError(String type, Object e) {
    try {
      ref.read(indexListProvider).logError.add({"type": type, "Error": "$e"});
    } catch (_) {}
  }

  void _expireSession() {
    if (_sessionHandled) return;
    _sessionHandled = true;
    // `ref` throws once this auto-disposed provider is gone (Riverpod 3).
    if (disposed) return;
    final context = _context;
    if (context == null || !context.mounted) return;
    try {
      ref.read(authProvider).ifSessionExpired(context);
    } catch (_) {}
  }

  /// Limits, GetMaxPayoutAmount and the request list, in parallel.
  Future<void> loadAll(BuildContext context) async {
    _context = context;
    await Future.wait([
      fetchMaxPayout(),
      _fetchLimits(context),
      fetchRequests(),
    ]);
  }

  Future<void> _fetchLimits(BuildContext context) async {
    _limitsLoading = true;
    _notify();
    try {
      final res = await ref.read(fundProvider).fetchFunds(context);
      _limitsOk = res is FundDetailModel && res.stat == 'Ok';
    } catch (e) {
      _limitsOk = false;
      _logError('withdraw Limits', e);
    } finally {
      _limitsLoading = false;
      _notify();
    }
  }

  /// Refreshes the withdrawable balance. Returns it, or null on failure.
  Future<double?> fetchMaxPayout() async {
    _maxPayoutLoading = true;
    _maxPayoutError = null;
    _notify();
    try {
      final res = await api.getMaxPayoutAmount();
      if (disposed) return null;
      if (res.isOk) {
        _maxPayout = res;
        return res.amount;
      }
      _maxPayout = null;
      if (res.isSessionExpired) {
        _expireSession();
      }
      _maxPayoutError = _maxPayoutErrorText;
      return null;
    } catch (e) {
      _maxPayout = null;
      _maxPayoutError = _maxPayoutErrorText;
      _logError('GetMaxPayoutAmount', e);
      return null;
    } finally {
      _maxPayoutLoading = false;
      _notify();
    }
  }

  Future<void> fetchRequests() async {
    _requestsLoading = true;
    _requestsError = null;
    _notify();
    try {
      final res = await api.getWithdrawRequests();
      if (disposed) return;
      if (res.isSessionError) {
        _requestsError = res.httpStatus == 503
            ? 'Session validation unavailable, please try again'
            : 'Unable to load withdrawals';
        if (res.httpStatus != 503) _expireSession();
        return;
      }
      _requests = _newestFirst(res.requests);
      _requestsLoaded = true;
    } catch (e) {
      _requestsError = 'Unable to load withdrawals';
      _logError('withdraw requests', e);
    } finally {
      _requestsLoading = false;
      _notify();
    }
  }

  /// Sorts by `created_at` (then `id`), newest first, rather than trusting the
  /// backend order. Rows without a parseable date go last.
  static List<WithdrawRequest> _newestFirst(List<WithdrawRequest> list) {
    DateTime? parse(String? s) =>
        s == null ? null : DateTime.tryParse(s.trim().replaceFirst(' ', 'T'));
    final sorted = [...list];
    sorted.sort((a, b) {
      final da = parse(a.createdAt), db = parse(b.createdAt);
      if (da != null && db != null && da != db) return db.compareTo(da);
      if (da == null && db != null) return 1;
      if (da != null && db == null) return -1;
      return (b.id ?? -1).compareTo(a.id ?? -1);
    });
    return sorted;
  }

  WithdrawActionResult? _sessionOutcome(WithdrawActionResponse res) {
    if (!res.isSessionError) return null;
    if (res.isValidationUnavailable) {
      return const WithdrawActionResult(WithdrawActionOutcome.serviceUnavailable,
          'Service unavailable, please try again');
    }
    _expireSession();
    return const WithdrawActionResult(
        WithdrawActionOutcome.sessionExpired, 'Session expired, please log in again');
  }

  Future<WithdrawActionResult> placeWithdraw({
    required BuildContext context,
    required String amount,
    required String companyCode,
    String? ip,
  }) async {
    _context = context;
    if (_placing) {
      return const WithdrawActionResult(
          WithdrawActionOutcome.inProgress, 'Please wait, your request is being placed');
    }
    _placing = true;
    _notify();
    try {
      final res = await api.placeWithdraw(
          amount: amount, companyCode: companyCode, ip: ip);
      final session = _sessionOutcome(res);
      if (session != null) return session;

      if (res.isPlaced) {
        unawaited(_refreshAfterAction(context));
        return WithdrawActionResult(WithdrawActionOutcome.success,
            'Withdrawal request placed successfully', res);
      }
      if (res.isInProgress) {
        _startCooldown(context);
        return WithdrawActionResult(WithdrawActionOutcome.inProgress,
            res.msg ?? 'A withdrawal request is already in progress, please wait', res);
      }
      final msg = res.msg;
      if (msg == null || msg.isEmpty || msg == 'error') {
        return WithdrawActionResult(WithdrawActionOutcome.failed, _genericError, res);
      }
      // Backoffice or Noren refused; the amount may have changed meanwhile.
      unawaited(_refreshAfterAction(context));
      return WithdrawActionResult(WithdrawActionOutcome.rejected, msg, res);
    } on TimeoutException catch (e) {
      _logError('withdraw payment timeout', e);
      unawaited(_refreshAfterAction(context));
      return const WithdrawActionResult(WithdrawActionOutcome.unknown,
          "We couldn't confirm your request. Check Active withdrawals before trying again");
    } catch (e) {
      _logError('withdraw payment', e);
      unawaited(_refreshAfterAction(context));
      return const WithdrawActionResult(WithdrawActionOutcome.failed, _genericError);
    } finally {
      _placing = false;
      _notify();
    }
  }

  Future<WithdrawActionResult> cancelWithdraw({
    required BuildContext context,
    required WithdrawRequest request,
  }) async {
    _context = context;
    final id = request.id;
    if (id == null || !request.isCancellable) {
      return const WithdrawActionResult(
          WithdrawActionOutcome.rejected, 'This request cannot be cancelled');
    }
    if (_cancelling.contains(id)) {
      return const WithdrawActionResult(
          WithdrawActionOutcome.inProgress, 'Cancellation is in progress');
    }
    _cancelling.add(id);
    _notify();
    try {
      final res = await api.cancelWithdraw(requestId: id);
      final session = _sessionOutcome(res);
      if (session != null) return session;

      // Reload in every remaining case: the status may have moved either way.
      unawaited(_refreshAfterAction(context));
      if (res.isCancelled) {
        return WithdrawActionResult(WithdrawActionOutcome.success,
            res.msg ?? 'Withdrawal cancelled', res);
      }
      if (res.isUnderReview) {
        return WithdrawActionResult(WithdrawActionOutcome.success,
            'Cancellation is under review. Support will complete it shortly', res);
      }
      if (res.isStale) {
        return WithdrawActionResult(WithdrawActionOutcome.stale,
            res.msg ?? 'Request was updated, please check the latest status', res);
      }
      final msg = res.msg;
      if (msg == null || msg.isEmpty || msg == 'error') {
        return WithdrawActionResult(WithdrawActionOutcome.failed, _genericError, res);
      }
      return WithdrawActionResult(WithdrawActionOutcome.rejected, msg, res);
    } on TimeoutException catch (e) {
      _logError('withdraw cancel timeout', e);
      unawaited(_refreshAfterAction(context));
      return const WithdrawActionResult(WithdrawActionOutcome.unknown,
          "We couldn't confirm the cancellation. Please check the status again");
    } catch (e) {
      _logError('withdraw cancel', e);
      unawaited(_refreshAfterAction(context));
      return const WithdrawActionResult(WithdrawActionOutcome.failed, _genericError);
    } finally {
      _cancelling.remove(id);
      _notify();
    }
  }

  Future<void> _refreshAfterAction(BuildContext context) async {
    if (disposed) return;
    await loadAll(context);
  }

  void _startCooldown(BuildContext context) {
    _cooldownTimer?.cancel();
    _cooldown = true;
    _notify();
    _cooldownTimer = Timer(const Duration(seconds: 5), () async {
      if (disposed) return;
      await loadAll(context);
      _cooldown = false;
      _notify();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}

/// One line of the withdrawable balance sheet.
class WithdrawBreakdownRow {
  final String label;
  final String caption;
  final double value;

  /// -1 subtracts, +1 adds, 0 is the opening figure (no sign shown).
  final int sign;

  /// Sub-lines shown under the row (e.g. the parts of unsettled credits).
  final List<WithdrawBreakdownPart> parts;

  const WithdrawBreakdownRow({
    required this.label,
    required this.caption,
    required this.value,
    required this.sign,
    this.parts = const [],
  });
}

/// A sub-line under a breakdown row. [isTotal] lines sum the lines above them.
class WithdrawBreakdownPart {
  final String label;
  final double value;
  final bool isTotal;
  const WithdrawBreakdownPart(this.label, this.value, {this.isTotal = false});
}

/// Explains the withdrawable balance from the Noren Limits fields
/// (WITHDRAW_SCREEN_FRONTEND.md section 3). The total is always [withdrawable]
/// (GetMaxPayoutAmount); any gap the rows don't model shows up as "Other
/// adjustments".
class WithdrawBreakdown {
  final List<WithdrawBreakdownRow> rows;
  final double withdrawable;

  const WithdrawBreakdown(this.rows, this.withdrawable);

  static double _d(String? v) {
    if (v == null) return 0.0;
    final s = v.trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return 0.0;
    final p = double.tryParse(s.replaceAll(',', ''));
    return (p == null || !p.isFinite) ? 0.0 : p;
  }

  static bool _nonZero(double v) => v.abs() >= 0.005;

  factory WithdrawBreakdown.from(FundDetailModel m, double withdrawable) {
    final cash = _d(m.cash);
    final payin = _d(m.payin);
    final payout = _d(m.payout);
    final marginUsed = _d(m.marginused);
    final collateral = _d(m.collateral);
    final brkCollAmt = _d(m.brkcollamt);
    final rpnl = _d(m.rpnl);
    final csc = _d(m.deliverySellBenefit);

    // rpnl is a margin-used component, so profit arrives negative.
    final profit = math.max(-rpnl, 0.0);
    final sellCredit = csc.abs();
    // Premium: positive = paid, negative = received.
    final premiumReceived = [
      m.premiumDI,
      m.premiumDM,
      m.premiumCI,
      m.premiumCM,
      m.premiumFI,
      m.premiumFM,
    ].map(_d).where((p) => p < 0).fold<double>(0.0, (a, p) => a + p.abs());
    final unsettled = profit + sellCredit + premiumReceived;

    // Total collateral, split the same way as the Funds screen: liquid is the
    // cash-equivalent part (`cash_coll`), equity is the rest.
    final totalCollateral = math.max(collateral + brkCollAmt, 0.0);
    final collateralLiquid =
        math.min(math.max(_d(m.cashcoll), 0.0), totalCollateral);
    final collateralEquity = totalCollateral - collateralLiquid;

    final collateralUtilised =
        math.max(0.0, math.min(totalCollateral, marginUsed));

    final calculated = math.max(
        cash - payout - marginUsed - unsettled + collateralUtilised, 0.0);
    final adjustment = withdrawable - calculated;

    final rows = <WithdrawBreakdownRow>[
      WithdrawBreakdownRow(
        label: 'Closing balance',
        caption: 'Ledger balance including funds added today',
        value: cash + payin,
        sign: 0,
        parts: [
          if (_nonZero(payin)) ...[
            WithdrawBreakdownPart('Opening balance', cash),
            WithdrawBreakdownPart('Funds added today', payin),
          ],
        ],
      ),
      if (_nonZero(payin))
        WithdrawBreakdownRow(
          label: 'Payin',
          caption: 'Funds added today cannot be withdrawn',
          value: payin,
          sign: -1,
        ),
      if (_nonZero(payout))
        WithdrawBreakdownRow(
          label: 'Withdrawals requested today',
          caption: 'Already held for withdrawal requests placed today',
          value: payout,
          sign: -1,
        ),
      WithdrawBreakdownRow(
        label: 'Margin used',
        caption: 'Margin blocked for positions and open orders',
        value: marginUsed,
        sign: -1,
      ),
      if (_nonZero(unsettled))
        WithdrawBreakdownRow(
          label: 'Unsettled credits',
          caption:
              "Today's profit and sell credits are available from the next day",
          value: unsettled,
          sign: -1,
          parts: [
            if (_nonZero(profit))
              WithdrawBreakdownPart('Realised profit', profit),
            if (_nonZero(sellCredit))
              WithdrawBreakdownPart('Delivery sell credit', sellCredit),
            if (_nonZero(premiumReceived))
              WithdrawBreakdownPart('Option premium received', premiumReceived),
          ],
        ),
      if (_nonZero(collateralUtilised))
        WithdrawBreakdownRow(
          label: 'Collateral utilised',
          caption: totalCollateral - collateralUtilised >= 0.005
              ? 'Margin covered by pledged stocks or liquid funds instead of cash. Only the part used for margin is counted'
              : 'Margin covered by pledged stocks or liquid funds instead of cash',
          value: collateralUtilised,
          sign: 1,
          parts: [
            if (_nonZero(collateralEquity))
              WithdrawBreakdownPart('Collateral equity', collateralEquity),
            if (_nonZero(collateralLiquid))
              WithdrawBreakdownPart('Collateral liquid', collateralLiquid),
            WithdrawBreakdownPart('Total collateral', totalCollateral,
                isTotal: true),
          ],
        ),
      if (adjustment.abs() >= 1)
        WithdrawBreakdownRow(
          label: 'Other adjustments',
          caption: 'Broker or exchange adjustments',
          value: adjustment.abs(),
          sign: adjustment < 0 ? -1 : 1,
        ),
    ];
    return WithdrawBreakdown(rows, withdrawable);
  }
}
