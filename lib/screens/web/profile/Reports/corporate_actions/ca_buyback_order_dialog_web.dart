// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../models/desk_reports_model/cp_action_model.dart';
import '../../../../../provider/fund_provider.dart';
import '../../../../../provider/ledger_provider.dart';
import '../../../../../provider/thems.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../sharedWidget/common_text_fields_web.dart';
import '../../../../../utils/rupee_convert_format.dart';

/// Web order/cancel dialog for Corporate Actions (Buyback / OFS).
class CABuybackOrderDialogWeb extends ConsumerStatefulWidget {
  final CorporateAction action;
  final bool isCancel;

  const CABuybackOrderDialogWeb({
    super.key,
    required this.action,
    required this.isCancel,
  });

  @override
  ConsumerState<CABuybackOrderDialogWeb> createState() =>
      _CABuybackOrderDialogWebState();
}

class _CABuybackOrderDialogWebState
    extends ConsumerState<CABuybackOrderDialogWeb> {
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  // UX: hide field errors until the user has actually interacted with that
  // field (avoids showing "X cannot be empty" the moment the dialog opens).
  bool _qtyTouched = false;
  bool _priceTouched = false;

  @override
  void initState() {
    super.initState();
    final lp = ref.read(ledgerProvider);
    _qtyCtrl.text = lp.selectedqtyforcpaction.text;
    _priceCtrl.text = lp.selectedpriceforcpaction.text;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // ── Computed values ────────────────────────────────────────────────────

  bool get _isOFS =>
      widget.action.issueType == 'IS' || widget.action.issueType == 'RS';

  double get _minPrice =>
      double.tryParse(widget.action.minPrice ?? '0') ??
      double.tryParse(widget.action.baseprice ?? '0') ??
      0;

  double get _maxPrice =>
      double.tryParse(widget.action.maxPrice ?? '0') ?? _minPrice;

  String get _maxQty {
    if (_isOFS) return '';
    final qty = widget.action.havingqty;
    return (qty == null || qty == 'null') ? '0' : qty;
  }

  /// Qty cap shown / enforced in the order form.
  ///
  /// Always the e-DIS-approved count (`approvedqty` ← Noren's `npoadqty`).
  /// Per backend: the depository will only release shares for which e-DIS
  /// has been done, so the user can never tender more than that — regardless
  /// of POA/DDPI status.
  String _qtyCapForUser() {
    if (_isOFS) return '';
    final approved = widget.action.approvedqty;
    return (approved == null || approved == 'null') ? '0' : approved;
  }

  /// Price to pre-fill into the OFS price field when "Cut off price" is ticked.
  ///
  /// Tries the API's `cutOffPrice` first (the discovered cutoff for the issue,
  /// when populated). Falls back to `baseprice` if `cutOffPrice` is null /
  /// empty / "0" — which is mobile's hard-coded behaviour. Finally falls back
  /// to "0" if even `baseprice` is missing.
  ///
  /// Strips a trailing ".0" if the value parses to a whole number, because
  /// the provider's validator still uses `int.tryParse` and would otherwise
  /// reject "453.0" as invalid.
  String _cutoffFillPrice() {
    bool valid(String? v) =>
        v != null && v.isNotEmpty && v != '0' && v != 'null';
    String value;
    final cutoff = widget.action.cutOffPrice;
    if (valid(cutoff)) {
      value = cutoff!;
    } else {
      final base = widget.action.baseprice;
      value = valid(base) ? base! : '0';
    }
    final parsed = double.tryParse(value);
    if (parsed != null && parsed == parsed.truncate()) {
      return parsed.toInt().toString();
    }
    return value;
  }

  String get _exchange {
    final ex = widget.action.exchange;
    if (ex == null || ex.isEmpty) return '-';
    return ex == 'NSETender' ? 'NSE' : ex;
  }

  /// Returns the trimmed value or "-" if null / empty / the literal string
  /// "null" (the API sometimes serialises missing values as that string).
  String _displayOr(String? v, [String fallback = '-']) {
    if (v == null) return fallback;
    final t = v.trim();
    if (t.isEmpty || t == 'null') return fallback;
    return t;
  }

  /// Normalises the issueType into a single display label, mirroring the
  /// helper used by the corporate-actions list screen.
  String get _typeLabel {
    switch (widget.action.issueType) {
      case 'BB':
      case 'BUYBACK':
        return 'BUYBACK';
      case 'DLST':
      case 'DS':
        return 'DELISTING';
      case 'TAKEOVER':
      case 'TO':
        return 'TAKEOVER';
      case 'IS':
      case 'RS':
        return 'OFS';
      default:
        return widget.action.issueType ?? '-';
    }
  }

  Color _typeColor() {
    switch (_typeLabel) {
      case 'BUYBACK':
        return resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);
      case 'DELISTING':
        return resolveThemeColor(context,
            dark: MyntColors.warningDark, light: MyntColors.warning);
      case 'TAKEOVER':
        return resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
      case 'OFS':
        return resolveThemeColor(context,
            dark: MyntColors.secondaryDark, light: MyntColors.secondary);
      default:
        return resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary);
    }
  }

  String get _submitLabel {
    if (widget.isCancel) return 'Cancel';
    return _isOFS ? 'Place Bid' : 'Place Order';
  }

  // ── Submit ─────────────────────────────────────────────────────────────

  /// Triggered when the user clicks the submit button.
  /// Reveals inline errors first (by marking fields touched), then either
  /// returns early (if invalid) or proceeds to place the order.
  void _onSubmitPressed() {
    if (!widget.isCancel) {
      setState(() {
        _qtyTouched = true;
        _priceTouched = true;
      });
      final lp = ref.read(ledgerProvider);
      if (!_canSubmit(lp)) return;
    }
    _submit();
  }

  Future<void> _submit() async {
    final lp = ref.read(ledgerProvider);
    final a = widget.action;

    if (widget.isCancel) {
      await lp.putordercopaction(
        lp.selectvalueofcpaction,
        a.symbol ?? '',
        a.exchange ?? '',
        a.issueType ?? '',
        a.bidqty ?? '',
        a.orderprice ?? '',
        context,
        'CR',
        a.appno ?? '',
      );
      return;
    }

    await lp.putordercopaction(
      lp.selectvalueofcpaction,
      a.symbol ?? '',
      a.exchange ?? '',
      a.issueType ?? '',
      _qtyCtrl.text,
      _priceCtrl.text,
      context,
      'ER',
      a.appno ?? '',
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Gate 2 (per backend): mirror the Holdings tab's e-DIS button condition.
    // The button fires when any holding's `npoadqty` is not the literal
    // "null" — meaning the user has shares needing e-DIS attention.
    // Per-scrip equivalent here: if THIS scrip's npoadqty != "null" AND
    // there's nothing saleable yet, route to the authorize prompt.
    final npoadqty = widget.action.npoadqty;
    final needsEdis = npoadqty != null && npoadqty != 'null';
    final approvedQty =
        int.tryParse(widget.action.approvedqty ?? '0') ?? 0;
    final needsEdisAuth = !widget.isCancel &&
        !_isOFS &&
        needsEdis &&
        approvedQty == 0;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.cardDark, light: MyntColors.card),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: resolveThemeColor(context,
                  dark: MyntColors.dividerDark, light: MyntColors.divider),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: widget.isCancel ? _cancelBody() : _orderBody(),
                  ),
                ),
                if (!needsEdisAuth) _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _header() {
    final typeColor = _typeColor();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Line 1: company name + exchange
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.action.name ?? '-',
                        overflow: TextOverflow.ellipsis,
                        style: MyntWebTextStyles.title(
                          context,
                          fontWeight: MyntFonts.semiBold,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _exchange,
                      style: MyntWebTextStyles.caption(
                        context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary,
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Line 2: type badge + optional "Need e-DIS" pill
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _typeLabel,
                        style: MyntWebTextStyles.caption(
                          context,
                          color: typeColor,
                          fontWeight: MyntFonts.semiBold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              size: 20,
              color: resolveThemeColor(context,
                  dark: MyntColors.iconSecondaryDark,
                  light: MyntColors.iconSecondary),
            ),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  // ── Body: Cancel ───────────────────────────────────────────────────────

  Widget _cancelBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Are you sure you want to cancel this order?',
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.body(
            context,
            fontWeight: MyntFonts.medium,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        _summaryCard([
          _SummaryRow('Quantity bid', widget.action.bidqty ?? '-'),
          _SummaryRow('Order price', '₹ ${widget.action.orderprice ?? '-'}'),
        ]),
      ],
    );
  }

  // ── Body: Order ────────────────────────────────────────────────────────

  Widget _orderBody() {
    final lp = ref.watch(ledgerProvider);
    final fund = ref.watch(fundProvider);
    final a = widget.action;

    // Gate 2 (per backend): mirror the Holdings tab's e-DIS button — if
    // npoadqty is non-null AND nothing is currently saleable, the user
    // must authorize e-DIS first.
    final needsEdis = a.npoadqty != null && a.npoadqty != 'null';
    final approvedQty = int.tryParse(a.approvedqty ?? '0') ?? 0;
    final needsEdisAuth = !_isOFS && needsEdis && approvedQty == 0;
    if (needsEdisAuth) {
      return _edisAuthBody(lp);
    }

    final qtyCap = _qtyCapForUser();

    final rows = <_SummaryRow>[
      if (_isOFS) ...[
        _SummaryRow('Closes On', _displayOr(a.biddingEndDate)),
        _SummaryRow('Base Price', '₹ ${_displayOr(a.baseprice)}'),
        _SummaryRow('Issue Size', _displayOr(a.issueSize)),
      ] else ...[
        _SummaryRow('Opens On', _displayOr(a.biddingStartDate)),
        _SummaryRow('Closes On', _displayOr(a.biddingEndDate)),
        _SummaryRow('Min Price', '₹ ${_displayOr(a.minPrice)}'),
        _SummaryRow('Max Price', '₹ ${_displayOr(a.maxPrice)}'),
        _SummaryRow(
          'Held / Approved',
          '${_maxQty.isEmpty ? '0' : _maxQty} / '
              '${_displayOr(a.approvedqty, '0')}',
        ),
      ],
    ];

    final qtyHint = (!_isOFS && qtyCap.isNotEmpty) ? '(Max: $qtyCap)' : '';
    final priceHint = _isOFS
        ? '(₹${a.baseprice ?? '-'})'
        : '(₹$_minPrice - ₹$_maxPrice)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _summaryCard(rows),
        const SizedBox(height: 16),

        // Quantity (label on the left, "Max: X" hint on the right)
        _fieldHeader(label: 'Quantity', hint: qtyHint),
        const SizedBox(height: 10),
        MyntFormTextField(
          controller: _qtyCtrl,
          placeholder: 'Enter quantity',
          height: 40,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            if (!_qtyTouched) setState(() => _qtyTouched = true);
            lp.setCPActionQty(
              v,
              _isOFS ? '' : qtyCap,
              _isOFS ? 'OFS' : '',
              fund.fundDetailModel?.cash ?? '0',
            );
          },
        ),
        if (_qtyTouched && _qtyErrorFor(lp).isNotEmpty) ...[
          const SizedBox(height: 6),
          _fieldError(_qtyErrorFor(lp)),
        ],
        const SizedBox(height: 16),

        // Price (label on the left, range/base-price hint on the right)
        _fieldHeader(label: 'Price', hint: priceHint),
        const SizedBox(height: 10),
        MyntFormTextField(
          controller: _priceCtrl,
          placeholder: 'Enter price',
          height: 40,
          readOnly: _isOFS && lp.cutoffcheckboxofs,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,9}$')),
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: (v) {
            if (!_priceTouched) setState(() => _priceTouched = true);
            lp.setCPActionPrice(
              v,
              _minPrice,
              _maxPrice,
              _isOFS ? 'OFS' : '',
              fund.fundDetailModel?.cash ?? '0',
            );
          },
        ),
        if (_priceTouched && lp.cpactionerrormsg.isNotEmpty) ...[
          const SizedBox(height: 6),
          _fieldError(lp.cpactionerrormsg),
        ],

        if (_isOFS) ...[
          const SizedBox(height: 8),
          _cutoffCheckbox(
            lp,
            cash: fund.fundDetailModel?.cash ?? '0',
          ),
        ],

        // OFS: required amount (big black, Indian-formatted). Always visible
        // as a ₹0 anchor when no valid bid yet. The status caption is hidden
        // when amount is 0 — the inline field errors already say what's
        // missing, so showing "Enter bid quantity and price" alongside them
        // is just noisy and sometimes wrong.
        if (_isOFS) ...[
          const SizedBox(height: 10),
          Text(
            (lp.requiredamountforofs.isEmpty
                    ? '0'
                    : lp.requiredamountforofs)
                .toIndianRupee(decimalPlaces: 0),
            style: MyntWebTextStyles.body(
              context,
              fontWeight: MyntFonts.semiBold,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textPrimary,
            ),
          ),
          // Only surface true balance/limit errors here. The provider also
          // sets "Required amount for bid…" and "Enter bid quantity and
          // price" as captions, but those are redundant — the big ₹ amount
          // above already communicates the bid value, and field-level errors
          // already cover invalid qty/price. Painting either of those in red
          // is just noise.
          if ((lp.captionforofs.contains('Insufficient') ||
                  lp.captionforofs.contains('exceeds')) &&
              lp.requiredamountforofs.isNotEmpty &&
              lp.requiredamountforofs != '0') ...[
            const SizedBox(height: 4),
            Text(
              lp.captionforofs,
              style: MyntWebTextStyles.caption(
                context,
                darkColor: MyntColors.lossDark,
                lightColor: MyntColors.loss,
                fontWeight: MyntFonts.medium,
              ),
            ),
          ],
        ],
      ],
    );
  }

  /// Field label followed by an optional helper hint immediately next to it.
  Widget _fieldHeader({required String label, String hint = ''}) {
    return Row(
      // crossAxisAlignment: CrossAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(label),
        if (hint.isNotEmpty) ...[
          const SizedBox(width: 8),
          _helper(hint),
        ],
      ],
    );
  }

  /// Inline error shown directly below a single field.
  Widget _fieldError(String text) {
    return Text(
      text,
      style: MyntWebTextStyles.caption(
        context,
        darkColor: MyntColors.lossDark,
        lightColor: MyntColors.loss,
        fontWeight: MyntFonts.medium,
      ),
    );
  }

  // ── Submit gating (mobile parity) ──────────────────────────────────────

  /// Read the current qty cap (always approvedqty — see [_qtyCapForUser]).
  String _currentQtyCap() => _qtyCapForUser();

  /// Web-only friendlier qty errors:
  ///   • qty <= 0  → "Quantity must be greater than 0"
  ///   • cap == 0 (no eligible shares)  → "You don't hold enough shares to tender"
  ///     (replaces the provider's awkward "must be less than or equal to 0")
  String _webOnlyQtyError() {
    if (_isOFS) return '';
    final v = int.tryParse(_qtyCtrl.text);
    if (v != null && v <= 0) return 'Quantity must be greater than 0';
    final cap = int.tryParse(_currentQtyCap());
    if (cap != null && cap == 0 && v != null && v > 0) {
      return "You don't hold enough shares to tender";
    }
    return '';
  }

  /// Effective error string for the qty field. Web-only overrides take
  /// precedence over the provider's message so the awkward cap=0 wording
  /// never reaches the user.
  String _qtyErrorFor(LDProvider lp) {
    final webErr = _webOnlyQtyError();
    if (webErr.isNotEmpty) return webErr;
    return lp.cpactionerrormsgqty;
  }

  bool _canSubmit(LDProvider lp) {
    if (widget.isCancel) return true;
    if (_isOFS) return lp.cpactionsubtn;
    if (lp.cpactionerrormsgqty.isNotEmpty || lp.cpactionerrormsg.isNotEmpty) {
      return false;
    }
    return _webOnlyQtyError().isEmpty;
  }

  // ── OFS: cut-off price checkbox ───────────────────────────────────────────

  Widget _cutoffCheckbox(LDProvider lp, {required String cash}) {
    final checked = lp.cutoffcheckboxofs;
    final fillPriceStr = _cutoffFillPrice();
    final theme = ref.watch(themeProvider);
    final checkboxColor =
        theme.isDarkMode ? MyntColors.secondary : MyntColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: Checkbox(
              value: checked,
              onChanged: (v) {
                final next = v ?? false;
                lp.setCutoffcheckboxforofs(next, fillPriceStr, cash);
                // setCutoffcheckboxforofs uses the stale required-amount
                // when it calls checkbalace internally, so the bid amount
                // stays at 0 if price was previously empty. Force a
                // re-validate + recalculate via setCPActionPrice.
                if (next) {
                  lp.setCPActionPrice(
                      fillPriceStr, _minPrice, _maxPrice, 'OFS', cash);
                }
                _priceCtrl.text = lp.selectedpriceforcpaction.text;
              },
              activeColor: checkboxColor,
              checkColor: Colors.white,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Cut off price',
            style: MyntWebTextStyles.body(
              context,
              fontWeight: MyntFonts.medium,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Body: e-DIS authorisation prompt (non-OFS, npoadqty > 0, 0 approved) ──

  Widget _edisAuthBody(LDProvider lp) {
    final theme = ref.watch(themeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "You have shares pending e-DIS authorization. "
          "Complete e-DIS to make them available for this action.",
          style: MyntWebTextStyles.body(
            context,
            fontWeight: MyntFonts.medium,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: () async {
              final fund = ref.read(fundProvider);
              await fund.fetchHstoken(context);
              await fund.eDisWeb();
              if (mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.isDarkMode
                  ? MyntColors.secondary
                  : MyntColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
              elevation: 0,
            ),
            child: Text(
              'Authorize e-DIS',
              style: MyntWebTextStyles.bodySmall(
                context,
                fontWeight: MyntFonts.semiBold,
                color: MyntColors.backgroundColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────

  Widget _footer() {
    final lp = ref.watch(ledgerProvider);
    final theme = ref.watch(themeProvider);
    final bgColor = widget.isCancel
        ? resolveThemeColor(context,
            dark: MyntColors.errorDark, light: MyntColors.tertiary)
        : (theme.isDarkMode ? MyntColors.secondary : MyntColors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton(
          // Always enabled (apart from while the API is in flight). On click,
          // _onSubmitPressed reveals inline field errors if the form is invalid.
          onPressed: lp.cpactionloader ? null : _onSubmitPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5)),
            elevation: 0,
            disabledBackgroundColor: bgColor,
          ),
          child: lp.cpactionloader
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _submitLabel,
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    color: MyntColors.backgroundColor,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Reusable building blocks ───────────────────────────────────────────

  /// Summary card: labels on the left column, values on the right column.
  Widget _summaryCard(List<_SummaryRow> rows) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              // Left column: label
              Expanded(
                child: Text(
                  rows[i].label,
                  style: MyntWebTextStyles.body(
                    context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                    fontWeight: MyntFonts.medium
                  ),
                ),
              ),
              // Right column: value
              Expanded(
                child: Text(
                  rows[i].value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: MyntWebTextStyles.body(
        context,
        fontWeight: MyntFonts.medium,
        darkColor: MyntColors.textPrimaryDark,
        lightColor: MyntColors.textPrimary,
      ),
    );
  }

  Widget _helper(String text) {
    return Text(
      text,
      style: MyntWebTextStyles.para(
        context,
         fontWeight: MyntFonts.medium,
       darkColor: MyntColors.textPrimaryDark,
        lightColor: MyntColors.textPrimary,
      ),
    );
  }
}

/// Simple label/value pair used inside the summary card.
class _SummaryRow {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);
}
