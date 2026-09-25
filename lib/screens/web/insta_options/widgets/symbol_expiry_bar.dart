import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_reference_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Top bar with live Exchange / Symbol / Expiry dropdowns.
///
/// Reads `/symbols` and `/expiries` via `InstaOptionsReferenceProvider`. When a
/// user picks a new symbol, expiry resets to the nearest expiry of that symbol.
class SymbolExpiryBar extends ConsumerStatefulWidget {
  const SymbolExpiryBar({super.key});

  @override
  ConsumerState<SymbolExpiryBar> createState() => _SymbolExpiryBarState();
}

class _SymbolExpiryBarState extends ConsumerState<SymbolExpiryBar> {
  static const List<String> _exchanges = ['NFO', 'BFO'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  void _ensureLoaded() {
    final selection = ref.read(instaOptionsSelectionProvider).selection;
    final reference = ref.read(instaOptionsReferenceProvider);
    reference.ensureSymbols(selection.exchange);
    if (selection.symbol.isNotEmpty) {
      reference
          .ensureExpiries(selection.exchange, selection.symbol)
          .then((_) => _hydrateExpiryIfMissing());
    }
  }

  void _hydrateExpiryIfMissing() {
    if (!mounted) return;
    final sel = ref.read(instaOptionsSelectionProvider);
    if (sel.selection.expiry.isNotEmpty) return;
    final ref0 = ref.read(instaOptionsReferenceProvider);
    final nearest =
        ref0.nearestExpiry(sel.selection.exchange, sel.selection.symbol);
    if (nearest != null) sel.update(expiry: nearest);
  }

  Future<void> _onExchangeChanged(String? exch) async {
    if (exch == null) return;
    final sel = ref.read(instaOptionsSelectionProvider);
    final reference = ref.read(instaOptionsReferenceProvider);
    await sel.update(exchange: exch, expiry: '');
    await reference.ensureSymbols(exch);
    final symbols = reference.symbolsFor(exch);
    if (symbols != null && symbols.isNotEmpty) {
      final next = symbols.contains(sel.selection.symbol)
          ? sel.selection.symbol
          : symbols.first;
      await sel.update(symbol: next, expiry: '');
      await reference.ensureExpiries(exch, next);
      _hydrateExpiryIfMissing();
    }
  }

  Future<void> _onSymbolChanged(String? sym) async {
    if (sym == null) return;
    final sel = ref.read(instaOptionsSelectionProvider);
    final reference = ref.read(instaOptionsReferenceProvider);
    await sel.update(symbol: sym, expiry: '');
    await reference.ensureExpiries(sel.selection.exchange, sym);
    _hydrateExpiryIfMissing();
  }

  Future<void> _onExpiryChanged(String? exp) async {
    if (exp == null) return;
    await ref.read(instaOptionsSelectionProvider).update(expiry: exp);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final sel = ref.watch(instaOptionsSelectionProvider).selection;
    final reference = ref.watch(instaOptionsReferenceProvider);

    final symbols = reference.symbolsFor(sel.exchange);
    final expiries = sel.symbol.isEmpty
        ? null
        : reference.expiriesFor(sel.exchange, sel.symbol);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border(bottom: BorderSide(color: tokens.border, width: 1)),
      ),
      child: Row(
        children: [
          _Dropdown<String>(
            tokens: tokens,
            label: 'Exchange',
            width: 96,
            value: sel.exchange,
            items: _exchanges,
            display: (e) => e,
            onChanged: _onExchangeChanged,
          ),
          const SizedBox(width: 12),
          _Dropdown<String>(
            tokens: tokens,
            label: 'Symbol',
            width: 160,
            value: sel.symbol.isEmpty ? null : sel.symbol,
            items: symbols ?? const [],
            display: (s) => s,
            disabled: symbols == null,
            placeholder: symbols == null ? 'Loading…' : 'Pick',
            onChanged: _onSymbolChanged,
          ),
          const SizedBox(width: 12),
          _Dropdown<String>(
            tokens: tokens,
            label: 'Expiry',
            width: 180,
            value: sel.expiry.isEmpty ? null : sel.expiry,
            items: expiries ?? const [],
            display: (e) => e,
            disabled: expiries == null,
            placeholder: expiries == null ? 'Loading…' : 'Pick',
            onChanged: _onExpiryChanged,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final InstaOptionsTokens tokens;
  final String label;
  final double width;
  final T? value;
  final List<T> items;
  final String Function(T) display;
  final bool disabled;
  final String? placeholder;
  final ValueChanged<T?> onChanged;

  const _Dropdown({
    required this.tokens,
    required this.label,
    required this.width,
    required this.value,
    required this.items,
    required this.display,
    required this.onChanged,
    this.disabled = false,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final fadeColor = disabled ? tokens.textMuted : tokens.textPrimary;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: MyntWebTextStyles.caption(
              context,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 22,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                hint: Text(
                  placeholder ?? 'Pick',
                  style: MyntWebTextStyles.body(
                    context,
                    color: tokens.textMuted,
                  ),
                ),
                icon: Icon(
                  Icons.expand_more,
                  size: 16,
                  color: tokens.textSecondary,
                ),
                style: MyntWebTextStyles.body(
                  context,
                  color: fadeColor,
                  fontWeight: FontWeight.w600,
                ),
                dropdownColor: tokens.bgSecondary,
                onChanged: disabled ? null : onChanged,
                items: items
                    .map(
                      (e) => DropdownMenuItem<T>(
                        value: e,
                        child: Text(
                          display(e),
                          style: MyntWebTextStyles.body(
                            context,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
