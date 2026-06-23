import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class SymbolsSearchPane extends ConsumerStatefulWidget {
  final ValueChanged<String> onSelect;
  const SymbolsSearchPane({super.key, required this.onSelect});

  @override
  ConsumerState<SymbolsSearchPane> createState() => _SymbolsSearchPaneState();
}

class _SymbolsSearchPaneState extends ConsumerState<SymbolsSearchPane> {
  final TextEditingController _ctl = TextEditingController();
  Timer? _debounce;
  String _activeQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _activeQuery = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: TextField(
            controller: _ctl,
            onChanged: _onChanged,
            style: MyntWebTextStyles.body(context),
            decoration: InputDecoration(
              hintText: 'Search by ticker or company name',
              hintStyle: MyntWebTextStyles.body(context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary)),
              prefixIcon: Icon(shadcn.LucideIcons.search,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    if (_activeQuery.isEmpty) {
      return const EmptyState(
        kind: EmptyStateKind.search,
        title: 'Search to find a stock',
        message: 'Try RELIANCE, TCS, or INFY.',
      );
    }
    final async = ref.watch(symbolSearchProvider(_activeQuery));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not search',
        message: e.toString(),
        onRetry: () => ref.invalidate(symbolSearchProvider(_activeQuery)),
      ),
      data: (resp) {
        if (resp.items.isEmpty) {
          return EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No stocks found for "$_activeQuery"',
            message: 'Try a different ticker.',
          );
        }
        return ListView.separated(
          itemCount: resp.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, i) {
            final s = resp.items[i];
            return _ResultRow(
              ticker: s.ticker,
              name: s.name,
              onTap: () => widget.onSelect(s.ticker),
            );
          },
        );
      },
    );
  }
}

class _ResultRow extends StatefulWidget {
  final String ticker;
  final String name;
  final VoidCallback onTap;

  const _ResultRow({
    required this.ticker,
    required this.name,
    required this.onTap,
  });

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final chipBg = resolveThemeColor(context,
        dark: MyntColors.listItemBgDark, light: MyntColors.listItemBg);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  widget.ticker,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.semiBold),
                ),
              ),
              Expanded(
                child: Text(
                  widget.name,
                  style: MyntWebTextStyles.body(context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('NSE',
                    style: MyntWebTextStyles.caption(context,
                        fontWeight: MyntFonts.medium)),
              ),
              const SizedBox(width: 8),
              Icon(shadcn.LucideIcons.chevronRight,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textTertiaryDark,
                      light: MyntColors.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}
