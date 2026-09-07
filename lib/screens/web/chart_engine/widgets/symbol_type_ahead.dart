import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/marketwatch_model/search_scrip_new_model.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';

/// Debounced inline symbol search. Uses
/// `searchScripForStrategyBuilder` (proper jsonEncoded `fil:["NSE"]`) and
/// shows results in an Overlay anchored to the field. PointerInterceptor
/// + onPopupVisibilityChanged keeps the popup clickable above the chart
/// iframe — same gating pattern proven in OrderflowTopBar.
class SymbolTypeAhead extends StatefulWidget {
  final ChartScrip? current;
  final ValueChanged<ChartScrip> onPicked;
  final ValueChanged<bool> onPopupVisibilityChanged;
  const SymbolTypeAhead({
    super.key,
    required this.current,
    required this.onPicked,
    required this.onPopupVisibilityChanged,
  });

  @override
  State<SymbolTypeAhead> createState() => _SymbolTypeAheadState();
}

class _SymbolTypeAheadState extends State<SymbolTypeAhead> {
  final LayerLink _link = LayerLink();
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  OverlayEntry? _entry;
  Timer? _debounce;
  List<ScripNewValue> _results = const [];
  bool _loading = false;

  static const _exchanges = ['NSE', 'BSE', 'NFO', 'BFO', 'MCX', 'CDS'];

  @override
  void initState() {
    super.initState();
    _ctl.text = widget.current?.dispName ?? '';
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant SymbolTypeAhead old) {
    super.didUpdateWidget(old);
    if (widget.current != old.current && !_focus.hasFocus) {
      _ctl.text = widget.current?.dispName ?? '';
    }
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _openDropdown();
      _ctl.selection =
          TextSelection(baseOffset: 0, extentOffset: _ctl.text.length);
    } else {
      // Defer close so a tap on a result lands first.
      Future.delayed(const Duration(milliseconds: 100), _closeDropdown);
    }
  }

  void _openDropdown() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
  }

  void _closeDropdown() {
    _entry?.remove();
    _entry = null;
    widget.onPopupVisibilityChanged(true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctl.dispose();
    if (_entry != null) {
      _entry!.remove();
      widget.onPopupVisibilityChanged(true);
    }
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      _entry?.markNeedsBuild();
      return;
    }
    setState(() {
      _loading = true;
    });
    _entry?.markNeedsBuild();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final resp = await locator<ApiExporter>().searchScripForStrategyBuilder(
          searchText: text.trim(),
          exchanges: _exchanges,
        );
        if (!mounted) return;
        setState(() {
          _results = resp.values ?? const [];
          _loading = false;
        });
        _entry?.markNeedsBuild();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _results = const [];
          _loading = false;
        });
        _entry?.markNeedsBuild();
      }
    });
  }

  /// Decorative title for a search result — prefer the DerivativeMaster name,
  /// falling back to the raw dname/tsym. Matches the JS typeahead flow driven
  /// by the shell's `searchSymbols` reply so both search paths read the same.
  String _resultTitle(ScripNewValue r) =>
      (r.masterName ?? r.tsym ?? r.dname ?? r.symbol ?? '')
          .replaceAll('-EQ', '');

  void _pick(ScripNewValue v) {
    final scrip = ChartScrip(
      exch: v.exch ?? 'NSE',
      token: v.token ?? '',
      tsym: v.tsym ?? '',
      dispName: _resultTitle(v),
      ls: int.tryParse(v.ls ?? '') ?? 1,
      ti: double.tryParse(v.ti ?? '') ?? 0.05,
      instname: v.instname ?? '',
    );
    widget.onPicked(scrip);
    _ctl.text = scrip.dispName;
    _focus.unfocus();
    _closeDropdown();
  }

  Widget _buildOverlay(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final hover = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return Positioned(
      width: 320,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: const Offset(0, 38),
        child: PointerInterceptor(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 380),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 4)),
                ],
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))),
                    )
                  : (_results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _ctl.text.trim().length < 2
                                ? 'Type at least 2 characters to search'
                                : 'No matches',
                            style: MyntWebTextStyles.caption(context),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final r = _results[i];
                            return InkWell(
                              onTap: () => _pick(r),
                              hoverColor: hover,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(_resultTitle(r),
                                            style: MyntWebTextStyles.body(
                                                context,
                                                fontWeight:
                                                    MyntFonts.semiBold)),
                                        const SizedBox(height: 2),
                                        Text(
                                            '${r.exch ?? ''} · ${r.instname ?? ''}',
                                            style: MyntWebTextStyles.caption(
                                                context)),
                                      ],
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          },
                        )),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    return CompositedTransformTarget(
      link: _link,
      child: SizedBox(
        width: 220,
        child: TextField(
          controller: _ctl,
          focusNode: _focus,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search symbol…',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: border),
            ),
          ),
          style: MyntWebTextStyles.body(context),
          onChanged: _onChanged,
        ),
      ),
    );
  }
}
