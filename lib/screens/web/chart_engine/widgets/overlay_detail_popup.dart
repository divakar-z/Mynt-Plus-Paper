import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:mynt_plus/models/order_book_model/modify_order_model.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

class OverlayDetailPopup extends ConsumerStatefulWidget {
  final Offset anchor; // top-left of the card in app coordinates
  final OverlayDetailData data;
  final VoidCallback onDismiss;

  const OverlayDetailPopup({
    super.key,
    required this.anchor,
    required this.data,
    required this.onDismiss,
  });

  @override
  ConsumerState<OverlayDetailPopup> createState() => _OverlayDetailPopupState();
}

class _OverlayDetailPopupState extends ConsumerState<OverlayDetailPopup> {
  late final TextEditingController _qtyCtl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final initialQty = widget.data is _OrderDetail
        ? (widget.data as _OrderDetail).o.qty ?? '1'
        : '1';
    _qtyCtl = TextEditingController(text: initialQty);
  }

  @override
  void dispose() {
    _qtyCtl.dispose();
    super.dispose();
  }

  int _lotSize() {
    // We don't have scrip lot size here; default step = 1. The exchange
    // will reject non-multiples on submit if it's an F&O contract.
    return 1;
  }

  void _bumpQty(int delta) {
    final cur = int.tryParse(_qtyCtl.text) ?? 0;
    final next = (cur + delta).clamp(1, 1 << 30);
    setState(() => _qtyCtl.text = next.toString());
  }

  Future<void> _submitModify() async {
    if (widget.data is! _OrderDetail) return;
    final o = (widget.data as _OrderDetail).o;
    final newQty = int.tryParse(_qtyCtl.text) ?? 0;
    if (newQty <= 0) return;
    if (newQty.toString() == o.qty) return; // no-op
    setState(() => _submitting = true);
    try {
      final input = ModifyOrderInput(
        exch: o.exch ?? '',
        token: o.token ?? '',
        tsym: o.tsym ?? '',
        orderNum: o.norenordno ?? '',
        qty: newQty.toString(),
        dscqty: o.dscqty ?? '0',
        mktProt: o.mktProtection ?? '',
        prctyp: o.prctyp ?? '',
        prd: o.prd ?? '',
        trantype: o.trantype ?? '',
        ret: o.ret ?? 'DAY',
        blprc: o.blprc ?? '',
        bpprc: o.bpprc ?? '',
        prc: o.prc ?? '0',
        trgprc: o.trgprc ?? '0',
      );
      await ref.read(orderProvider).fetchModifyOrder(input, context);
    } finally {
      if (mounted) setState(() => _submitting = false);
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final mute = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final rows = widget.data.rows();
    final isOrder = widget.data is _OrderDetail;

    final screen = MediaQuery.of(context).size;
    const w = 280.0;
    // Order popup with the Modify-quantity section is ~440px tall; position
    // popup is ~280px. Reserve enough vertical room so the popup never spills
    // off-screen, and cap its height so it never exceeds the viewport (the
    // SingleChildScrollView below catches anything that still doesn't fit).
    final maxH = (screen.height - 16).clamp(200.0, 460.0);
    final reservedBottom = maxH + 8;
    final left = widget.anchor.dx.clamp(8.0, screen.width - w - 8.0);
    final top = widget.anchor.dy.clamp(8.0, screen.height - reservedBottom);

    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
          ),
        ),
      ),
      Positioned(
        left: left,
        top: top,
        width: w,
        child: PointerInterceptor(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(maxHeight: maxH),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.data.title(),
                      style: MyntWebTextStyles.caption(context,
                          fontWeight: MyntFonts.semiBold)),
                  const SizedBox(height: 8),
                  for (final r in rows) _row(context, r.$1, r.$2, mute),
                  if (isOrder) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: border),
                    const SizedBox(height: 10),
                    Text('Modify quantity',
                        style: MyntWebTextStyles.caption(context,
                            fontWeight: MyntFonts.semiBold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      _stepBtn(
                        icon: Icons.remove,
                        border: border,
                        mute: mute,
                        onTap: () => _bumpQty(-_lotSize()),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: TextField(
                            controller: _qtyCtl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.body(context,
                                fontWeight: MyntFonts.semiBold),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: accent),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _stepBtn(
                        icon: Icons.add,
                        border: border,
                        mute: mute,
                        onTap: () => _bumpQty(_lotSize()),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submitModify,
                        child: Text(_submitting ? 'Modifying…' : 'Modify'),
                      ),
                    ),
                  ],
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _stepBtn({
    required IconData icon,
    required Color border,
    required Color mute,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(6)),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: mute),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, Color mute) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: MyntWebTextStyles.caption(context, color: mute)),
          ),
          Expanded(
              child: Text(value, style: MyntWebTextStyles.body(context))),
        ],
      ),
    );
  }
}

/// Sealed-ish union of what the popup can display.
abstract class OverlayDetailData {
  String title();
  List<(String, String)> rows();
  factory OverlayDetailData.position(PositionBookModel p) = _PositionDetail;
  factory OverlayDetailData.order(OrderBookModel o) = _OrderDetail;
}

class _PositionDetail implements OverlayDetailData {
  final PositionBookModel p;
  _PositionDetail(this.p);
  @override
  String title() => 'Position · ${p.tsym ?? ''}';
  @override
  List<(String, String)> rows() => [
        ('Symbol', p.tsym ?? '—'),
        ('Exchange', p.exch ?? '—'),
        ('Qty (net)', p.netqty ?? '—'),
        ('Avg price', p.netavgprc ?? '—'),
        ('LTP', p.lp ?? '—'),
        ('Product', p.prd ?? '—'),
        ('MTM', p.mTm ?? '—'),
        ('Realised', p.rpnl ?? '—'),
      ];
}

class _OrderDetail implements OverlayDetailData {
  final OrderBookModel o;
  _OrderDetail(this.o);
  @override
  String title() => 'Order · ${o.tsym ?? ''}';
  @override
  List<(String, String)> rows() => [
        ('Symbol', o.tsym ?? '—'),
        ('Exchange', o.exch ?? '—'),
        ('Side', o.trantype == 'B' ? 'BUY' : (o.trantype == 'S' ? 'SELL' : '—')),
        ('Type', o.prctyp ?? '—'),
        ('Product', o.prd ?? '—'),
        ('Qty', o.qty ?? '—'),
        ('Price', o.prc ?? '—'),
        if ((o.trgprc ?? '').isNotEmpty) ('Trigger', o.trgprc!),
        ('Status', o.status ?? '—'),
        ('Order ID', o.norenordno ?? '—'),
      ];
}
