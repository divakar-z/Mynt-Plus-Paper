import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/privacy_provider.dart';
import 'package:mynt_plus/provider/transcation_provider.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../../../models/fund_model_testing_copy/withdraw_request_model.dart';
import '../../../../../provider/fund_provider.dart';
import '../../../../../provider/withdraw_provider.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../sharedWidget/common_buttons_web.dart';
import '../../../../../sharedWidget/common_text_fields_web.dart';
import '../../../../../sharedWidget/functions.dart';
import 'withdraw_break_up.dart';
import 'withdraw_request_tile.dart';

/// Withdraw funds (WITHDRAW_SCREEN_FRONTEND.md): withdrawable balance, the
/// amount form beside its breakdown, then active withdrawals. The screen
/// loads its own balance, limits, requests and IP on open.
class WithdrawScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const WithdrawScreen({super.key, this.onBack});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  /// The screen loader shows until the first load finishes (pass or fail).
  bool _initialLoaded = false;

  /// Validation messages show only after the user has typed something.
  bool _touched = false;

  /// True from confirmation until the place call returns (covers the balance
  /// re-check and the place call).
  bool _submitting = false;

  // Up to 9 integer digits and 2 decimals.
  static final RegExp _amountPattern = RegExp(r'^\d{0,9}(\.\d{0,2})?$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
      if (mounted) setState(() => _initialLoaded = true);
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final trans = ref.read(transcationProvider);
    await Future.wait([
      ref.read(withdrawProvider).loadAll(context),
      // company_code comes from the client check; load it if missing.
      if (trans.decryptclientcheck?.companyCode == null)
        _safe(() => trans.fetchc(context)),
      if (trans.ipAddress.isEmpty) _safe(() => trans.ip()),
    ]);
  }

  Future<void> _safe(Future<dynamic> Function() f) async {
    try {
      await f();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- helpers

  /// The segment the payout is placed under, using the same priority the
  /// fund screen applies when it initialises (NSE_FNO, NSE_CASH, MCX, first).
  String? _companyCode(TranctionProvider trans) {
    final codes = trans.decryptclientcheck?.companyCode;
    if (codes == null || codes.isEmpty) return null;
    for (final c in const ['NSE_FNO', 'NSE_CASH', 'MCX']) {
      if (codes.contains(c)) return c;
    }
    final first = codes.first.toString();
    return first.isEmpty ? null : first;
  }

  static int _cents(double v) => (v * 100).round();

  /// Max payout truncated to paisa, so validation never rounds above it.
  static int _limitCents(double v) => (v * 100 + 1e-6).floor();

  double? get _enteredAmount {
    final t = _amountCtrl.text.trim();
    if (t.isEmpty || t == '.') return null;
    final v = double.tryParse(t);
    return (v == null || !v.isFinite) ? null : v;
  }

  // Non-breaking space keeps ₹ on the same line as the amount when wrapped.
  String _money(double v) => ref.read(privacyProvider).mask(
      getFormatter(value: v, v4d: false, noDecimal: false),
      prefix: '₹ ');

  /// Null when the amount is fine (or untouched); otherwise the message.
  String? _amountError(double? withdrawable) {
    final text = _amountCtrl.text.trim();
    if (text.isEmpty) return _touched ? 'Please enter an amount' : null;
    final v = _enteredAmount;
    if (v == null) return 'Please enter a valid amount';
    if (_cents(v) <= 0) return 'Amount must be greater than 0';
    if (withdrawable != null && _cents(v) > _limitCents(withdrawable)) {
      return 'Amount exceeds withdrawable balance ${_money(withdrawable)}';
    }
    return null;
  }

  Color _c(Color dark, Color light) =>
      resolveThemeColor(context, dark: dark, light: light);

  Color get _textPrimary =>
      _c(MyntColors.textPrimaryDark, MyntColors.textPrimary);
  Color get _textSecondary =>
      _c(MyntColors.textSecondaryDark, MyntColors.textSecondary);
  Color get _primary => _c(MyntColors.primaryDark, MyntColors.primary);
  Color get _loss => _c(MyntColors.lossDark, MyntColors.loss);
  Color get _border => _c(MyntColors.cardBorderDark, MyntColors.cardBorder);

  // ---------------------------------------------------------------- actions

  Future<void> _onWithdraw() async {
    final wp = ref.read(withdrawProvider);
    final trans = ref.read(transcationProvider);
    _amountFocus.unfocus();
    setState(() => _touched = true);

    final amount = _enteredAmount;
    final withdrawable = wp.withdrawable;
    if (amount == null ||
        withdrawable == null ||
        _amountError(withdrawable) != null) {
      return;
    }
    final companyCode = _companyCode(trans);
    if (companyCode == null) {
      showResponsiveWarning(context, 'No active segment found for withdrawal');
      return;
    }

    final pending = wp.pendingRequest;
    final confirmed = await _confirmDialog(
      title: 'Withdraw Fund',
      message: 'Are you sure you want to withdraw ${_money(amount)}?',
      note: pending != null
          ? 'This will replace your pending request of ${_money(pending.amount)}'
          : null,
    );
    if (!mounted || confirmed != true || _submitting) return;

    setState(() => _submitting = true);
    try {
      // The balance can move while the screen is open (orders, MTM), so check
      // it again right before placing.
      final latest = await wp.fetchMaxPayout();
      if (!mounted) return;
      if (latest == null) {
        showResponsiveError(
            context, 'Unable to fetch withdrawable balance, please try again');
        return;
      }
      if (_cents(amount) > _limitCents(latest)) {
        showResponsiveWarning(context,
            'Your withdrawable balance is now ${_money(latest)}. Please update the amount');
        return;
      }

      final ip = trans.ipAddress.trim();
      final result = await wp.placeWithdraw(
        context: context,
        amount: amount.toStringAsFixed(2),
        companyCode: companyCode,
        ip: ip.isEmpty ? null : ip,
      );
      if (!mounted) return;
      _showResult(result);
      if (result.outcome == WithdrawActionOutcome.success) {
        setState(() {
          _amountCtrl.clear();
          _touched = false;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _onCancelRequest(WithdrawRequest r) async {
    final wp = ref.read(withdrawProvider);
    final confirmed = await _confirmDialog(
      title: 'Cancel Withdrawal',
      message:
          'Are you sure you want to cancel the withdrawal of ${_money(r.amount)}?',
    );
    if (!mounted || confirmed != true) return;
    final result = await wp.cancelWithdraw(context: context, request: r);
    if (!mounted) return;
    // On success the reloaded list already shows the new status (CANCELLED or
    // UNDER REVIEW), so only failures get a toast.
    if (result.outcome == WithdrawActionOutcome.success) return;
    _showResult(result);
  }

  void _showResult(WithdrawActionResult result) {
    switch (result.outcome) {
      case WithdrawActionOutcome.success:
        showResponsiveSuccess(context, result.message);
        break;
      case WithdrawActionOutcome.inProgress:
      case WithdrawActionOutcome.stale:
      case WithdrawActionOutcome.unknown:
      case WithdrawActionOutcome.serviceUnavailable:
        showResponsiveWarning(context, result.message);
        break;
      case WithdrawActionOutcome.sessionExpired:
        // The login flow takes over; nothing more to show here.
        break;
      case WithdrawActionOutcome.rejected:
      case WithdrawActionOutcome.failed:
        showResponsiveError(context, result.message);
        break;
    }
  }

  /// Confirmation in the web alert design (as the IPO cancel alert): title
  /// and close icon, centred question, one full-width primary button.
  /// Resolves true only on the button.
  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    String? note,
    String confirmLabel = 'Yes',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: resolveThemeColor(dialogContext,
                dark: MyntColors.dialogDark, light: MyntColors.dialog),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: resolveThemeColor(dialogContext,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: MyntWebTextStyles.title(dialogContext,
                          color: resolveThemeColor(dialogContext,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary)),
                    ),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(dialogContext).pop(false),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: resolveThemeColor(dialogContext,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: MyntWebTextStyles.body(dialogContext,
                          color: resolveThemeColor(dialogContext,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary)),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 12),
                      _banner(note),
                    ],
                    const SizedBox(height: 24),
                    MyntPrimaryButton(
                      label: confirmLabel,
                      isFullWidth: true,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
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

  // ---------------------------------------------------------------- widgets

  /// Amber warning banner, same as the old Pending Request card. With [info]
  /// it is a blue info note instead, so it reads apart from the warning.
  Widget _banner(String text, {bool info = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: info
            ? _primary.withValues(alpha: 0.08)
            : _c(const Color(0xFF2D2200), const Color(0xFFFFF8E1)),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: info
                ? _primary.withValues(alpha: 0.3)
                : _c(const Color(0xFF5C4400), const Color(0xFFFFE082))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(info ? Icons.info_outline : Icons.error_outline,
              size: 18, color: info ? _primary : MyntColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: MyntWebTextStyles.bodySmall(context,
                  color: _textPrimary, fontWeight: MyntFonts.medium),
            ),
          ),
        ],
      ),
    );
  }

  Widget _caption(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          style: MyntWebTextStyles.caption(context,
              color: color, fontWeight: MyntFonts.medium),
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _c(MyntColors.transparent, MyntColors.card),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: _border),
        ),
        child: child,
      );

  // ── Top bar: withdrawable amount ───────────────────────────────

  Widget _buildTopBar(WithdrawProvider wp) {
    final withdrawable = wp.withdrawable;
    final balanceFailed = wp.maxPayoutError != null && !wp.maxPayoutLoading;
    final hasBalance = withdrawable != null && withdrawable > 0;
    final busy = _submitting || wp.placing;
    final isPrivate = ref.watch(privacyProvider).isPrivate;

    return shadcn.Theme(
      data: shadcn.Theme.of(context).copyWith(radius: () => 0.3),
      child: shadcn.Card(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Withdrawable Amount',
                    style: MyntWebTextStyles.bodySmall(context,
                        fontWeight: MyntFonts.medium,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  if (balanceFailed)
                    Row(
                      children: [
                        Text(
                          wp.maxPayoutError!,
                          style: MyntWebTextStyles.bodySmall(context,
                              color: _loss, fontWeight: MyntFonts.medium),
                        ),
                        const SizedBox(width: 8),
                        MyntTextButton(
                          label: 'Retry',
                          onPressed: () => wp.fetchMaxPayout(),
                        ),
                      ],
                    )
                  else
                    Text(
                      wp.maxPayoutLoading && withdrawable == null
                          ? '₹ --'
                          : _money(withdrawable ?? 0),
                      style: MyntWebTextStyles.head(context,
                          color: !isPrivate && hasBalance
                              ? _c(MyntColors.profitDark, MyntColors.profit)
                              : _textPrimary,
                          fontWeight: MyntFonts.medium),
                    ),
                ],
              ),
              const Spacer(),
              if (withdrawable != null && withdrawable > 0 && !busy)
                MyntOutlinedButton(
                  label: 'Withdraw All',
                  onPressed: () {
                    // Truncated to paisa so it never exceeds the balance.
                    final text =
                        (_limitCents(withdrawable) / 100).toStringAsFixed(2);
                    setState(() {
                      _amountCtrl.text = text;
                      _amountCtrl.selection =
                          TextSelection.collapsed(offset: text.length);
                      _touched = true;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Left column: amount form ───────────────────────────────────

  Widget _buildForm(WithdrawProvider wp, TranctionProvider trans) {
    final withdrawable = wp.withdrawable;
    final balanceFailed = wp.maxPayoutError != null && !wp.maxPayoutLoading;
    final hasBalance = withdrawable != null && withdrawable > 0;
    final busy = _submitting || wp.placing;
    final amountError = _amountError(withdrawable);
    final companyCode = _companyCode(trans);
    final segmentMissing = companyCode == null &&
        trans.decryptclientcheck != null &&
        !trans.loading;

    final canWithdraw = hasBalance &&
        !wp.maxPayoutLoading &&
        !busy &&
        !wp.cooldown &&
        companyCode != null &&
        _enteredAmount != null &&
        amountError == null;

    final pending = wp.pendingRequest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Amount',
          style: MyntWebTextStyles.bodySmall(context,
              fontWeight: MyntFonts.medium,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: MyntTextField(
                controller: _amountCtrl,
                focusNode: _amountFocus,
                enabled: hasBalance && !busy,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) =>
                      _amountPattern.hasMatch(newValue.text)
                          ? newValue
                          : oldValue),
                ],
                placeholder: '0.00',
                leadingWidget: Center(
                  widthFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '₹',
                      style: MyntWebTextStyles.body(context,
                          fontWeight: MyntFonts.medium,
                          darkColor: MyntColors.textSecondaryDark,
                          lightColor: MyntColors.textSecondary),
                    ),
                  ),
                ),
                onChanged: (_) => setState(() => _touched = true),
                onSubmitted: (_) {
                  if (canWithdraw) _onWithdraw();
                },
              ),
            ),
            const SizedBox(width: 12),
            MyntPrimaryButton(
              label: 'Withdraw',
              isFullWidth: false,
              isLoading: busy,
              onPressed: canWithdraw ? _onWithdraw : null,
            ),
          ],
        ),
        if (amountError != null)
          _caption(amountError, _loss)
        else if (!balanceFailed && withdrawable != null && !hasBalance)
          _caption('No balance available to withdraw', _textSecondary),
        if (segmentMissing)
          _caption('No active segment found for withdrawal', _loss),
        if (wp.cooldown)
          _caption('Another request is being processed. Refreshing shortly…',
              _textSecondary),
        if (pending != null) ...[
          const SizedBox(height: 12),
          _banner(
              'Placing a new request will replace your pending request of ${_money(pending.amount)}',
              info: true),
        ],
      ],
    );
  }

  // ── Right column: withdrawable breakdown ───────────────────────

  static const bool _showBreakdown = false;

  Widget _buildBreakdown(WithdrawProvider wp) {
    final model = ref.watch(fundProvider).fundDetailModel;
    final withdrawable = wp.withdrawable;
    Widget body;
    if (wp.limitsOk && withdrawable != null && model != null) {
      body = WithdrawBreakdownView(
          breakdown: WithdrawBreakdown.from(model, withdrawable));
    } else if (wp.limitsLoading || wp.maxPayoutLoading) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
          ),
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Breakdown unavailable',
          style: MyntWebTextStyles.bodySmall(context,
              color: _textSecondary, fontWeight: MyntFonts.medium),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Withdrawable Breakdown',
          style: MyntWebTextStyles.bodySmall(context,
              fontWeight: MyntFonts.medium,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary),
        ),
        const SizedBox(height: 4),
        body,
      ],
    );
  }

  Widget _buildMainCard(WithdrawProvider wp, TranctionProvider trans) {
    return LayoutBuilder(builder: (context, constraints) {
      final form = Padding(
        padding: const EdgeInsets.all(20),
        child: _buildForm(wp, trans),
      );
      // Breakdown is hidden for now; flip to show it again.
      // Without it, the form and Active withdrawals share the row on wide
      // panes and stack on narrow ones.
      if (!_showBreakdown) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              _card(child: form),
              const SizedBox(height: 16),
              _buildActive(wp),
            ],
          );
        }
        // Both cards stretch to the taller one so they line up.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _card(child: form)),
              const SizedBox(width: 16),
              Expanded(child: _buildActive(wp)),
            ],
          ),
        );
      }
      final breakdown = Padding(
        padding: const EdgeInsets.all(20),
        child: _buildBreakdown(wp),
      );
      // Stacked on narrow panes, side by side otherwise.
      if (constraints.maxWidth < 720) {
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              form,
              Container(height: 1, color: _border),
              breakdown,
            ],
          ),
        );
      }
      return _card(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: form),
              Container(width: 1, color: _border),
              Expanded(child: breakdown),
            ],
          ),
        ),
      );
    });
  }

  // ── Active withdrawals ─────────────────────────────────────────

  Widget _buildActive(WithdrawProvider wp) {
    final rows = wp.activeRequests;

    Widget message(String title, String? subtitle, {VoidCallback? onRetry}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Center(
          child: Column(
            children: [
              Text(title,
                  style: MyntWebTextStyles.body(context,
                      color: _textPrimary, fontWeight: MyntFonts.medium)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: MyntWebTextStyles.bodySmall(context,
                        color: _textSecondary, fontWeight: MyntFonts.medium)),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                MyntTextButton(label: 'Retry', onPressed: onRetry),
              ],
            ],
          ),
        ),
      );
    }

    Widget content;
    if (wp.requestsError != null && wp.requests.isEmpty) {
      content = message('Unable to load withdrawals', wp.requestsError,
          onRetry: wp.requestsLoading ? null : () => wp.fetchRequests());
    } else if (!wp.requestsLoaded && wp.requestsLoading) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
          ),
        ),
      );
    } else if (rows.isEmpty) {
      content = message('No active withdrawals',
          'Past withdrawals are in Transaction History.');
    } else {
      content = Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Container(height: 1, color: _border),
            WithdrawRequestTile(
              request: rows[i],
              cancelling: wp.isCancelling(rows[i].id),
              onCancel: wp.placing ? null : () => _onCancelRequest(rows[i]),
            ),
          ],
        ],
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'Active withdrawals',
              style: MyntWebTextStyles.bodySmall(context,
                  fontWeight: MyntFonts.medium,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary),
            ),
          ),
          Container(height: 1, color: _border),
          content,
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      centerTitle: false,
      leadingWidth: 48,
      titleSpacing: 6,
      backgroundColor:
          _c(MyntColors.backgroundColorDark, MyntColors.backgroundColor),
      elevation: .2,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: CustomBackBtn(onBack: widget.onBack),
      ),
      title: Text(
        'Withdraw Fund',
        style: MyntWebTextStyles.title(context,
            fontWeight: MyntFonts.semiBold,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary),
      ),
      actions: [
        if (_initialLoaded)
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: Icon(Icons.refresh, size: 20, color: _textSecondary),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wp = ref.watch(withdrawProvider);
    final trans = ref.watch(transcationProvider);
    // Rebuild when the privacy mask is toggled.
    ref.watch(privacyProvider);

    final background =
        _c(MyntColors.backgroundColorDark, MyntColors.backgroundColor);

    if (!_initialLoaded) {
      return Scaffold(
        backgroundColor: background,
        appBar: _buildAppBar(),
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    return Scaffold(
      backgroundColor: background,
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () => _amountFocus.unfocus(),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(wp),
                const SizedBox(height: 16),
                _buildMainCard(wp, trans),
                if (_showBreakdown) ...[
                  const SizedBox(height: 16),
                  _buildActive(wp),
                ],
                const SizedBox(height: 16),
                _banner(
                    'Payout requests submitted before 8:00 AM on any working day will be processed in the first batch, and requests submitted before 4:00 PM will be processed in the second batch on the same day. Requests received after 4:00 PM will be processed on the next working day. In case of multiple requests, the latest one will be considered.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
