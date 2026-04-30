// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../models/desk_reports_model/cp_action_model.dart';
import '../../../../../provider/fund_provider.dart';
import '../../../../../provider/ledger_provider.dart';
import '../../../../../res/mynt_web_color_styles.dart';
import '../../../../../res/mynt_web_text_styles.dart';
import '../../../../../sharedWidget/common_buttons_web.dart';
import '../../../../../sharedWidget/common_text_fields_web.dart';

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

  String get _exchange {
    final ex = widget.action.exchange;
    if (ex == null || ex.isEmpty) return '-';
    return ex == 'NSETender' ? 'NSE' : ex;
  }

  String get _title {
    if (widget.isCancel) return 'Cancel Order';
    return _isOFS ? 'Place OFS Bid' : 'Place Buyback Order';
  }

  String get _submitLabel {
    if (widget.isCancel) return 'Confirm Cancel';
    return _isOFS ? 'Place Bid' : 'Place Order';
  }

  // ── Submit ─────────────────────────────────────────────────────────────

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

    if (!lp.qtyvalidcp || !lp.pricevalidcp) return;

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
                  dark: MyntColors.cardBorderDark,
                  light: MyntColors.cardBorder),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: widget.isCancel ? _cancelBody() : _orderBody(),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  style: MyntWebTextStyles.title(
                    context,
                    fontWeight: MyntFonts.semiBold,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.action.name ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.caption(
                    context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          MyntCloseButton(onPressed: () => Navigator.of(context).pop()),
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
          style: MyntWebTextStyles.body(
            context,
            fontWeight: MyntFonts.medium,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
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

    final rows = <_SummaryRow>[
      _SummaryRow('Exchange', _exchange),
      _SummaryRow('Closes On', a.biddingEndDate ?? '-'),
      if (_isOFS) ...[
        _SummaryRow('Base Price', '₹ ${a.baseprice ?? '-'}'),
        _SummaryRow('Issue Size', a.issueSize ?? '-'),
      ] else ...[
        _SummaryRow('Min Price', '₹ ${a.minPrice ?? '-'}'),
        _SummaryRow('Max Price', '₹ ${a.maxPrice ?? '-'}'),
        _SummaryRow('Eligible Qty', _maxQty),
      ],
    ];

    final errorMsg = lp.cpactionerrormsgqty.isNotEmpty
        ? lp.cpactionerrormsgqty
        : lp.cpactionerrormsg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _summaryCard(rows),
        const SizedBox(height: 16),

        // Quantity
        _label('Quantity'),
        const SizedBox(height: 8),
        MyntFormTextField(
          controller: _qtyCtrl,
          placeholder: 'Enter quantity',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => lp.setCPActionQty(
            v,
            _isOFS ? '' : _maxQty,
            _isOFS ? 'OFS' : '',
            fund.fundDetailModel?.cash ?? '0',
          ),
        ),
        if (!_isOFS && _maxQty.isNotEmpty) ...[
          const SizedBox(height: 6),
          _helper('Max: $_maxQty'),
        ],
        const SizedBox(height: 14),

        // Price
        _label('Price'),
        const SizedBox(height: 8),
        MyntFormTextField(
          controller: _priceCtrl,
          placeholder: 'Enter price',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (v) => lp.setCPActionPrice(
            v,
            _minPrice,
            _maxPrice,
            _isOFS ? 'OFS' : '',
            fund.fundDetailModel?.cash ?? '0',
          ),
        ),
        const SizedBox(height: 6),
        _helper(
          _isOFS
              ? 'Base price ₹${a.baseprice ?? '-'}'
              : 'Range ₹$_minPrice - ₹$_maxPrice',
        ),

        if (errorMsg.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            errorMsg,
            style: MyntWebTextStyles.caption(
              context,
              darkColor: MyntColors.lossDark,
              lightColor: MyntColors.loss,
              fontWeight: MyntFonts.medium,
            ),
          ),
        ],
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────

  Widget _footer() {
    final lp = ref.watch(ledgerProvider);
    final cancelBg = widget.isCancel
        ? resolveThemeColor(context,
            dark: MyntColors.errorDark, light: MyntColors.tertiary)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
          ),
        ),
      ),
      child: MyntPrimaryButton(
        label: _submitLabel,
        isFullWidth: true,
        isLoading: lp.cpactionloader,
        backgroundColor: cancelBg,
        onPressed: lp.cpactionloader ? null : _submit,
      ),
    );
  }

  // ── Reusable building blocks ───────────────────────────────────────────

  /// Summary card: labels on the left column, values on the right column.
  Widget _summaryCard(List<_SummaryRow> rows) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.listItemBgDark, light: MyntColors.listItemBg);
    final border = resolveThemeColor(context,
        dark: MyntColors.borderMutedDark, light: MyntColors.borderMuted);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                // Left column: label
                Expanded(
                  child: Text(
                    rows[i].label,
                    style: MyntWebTextStyles.caption(
                      context,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary,
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
      ),
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
      style: MyntWebTextStyles.caption(
        context,
        darkColor: MyntColors.textTertiaryDark,
        lightColor: MyntColors.textTertiary,
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
