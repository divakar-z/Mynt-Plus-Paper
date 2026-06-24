import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/scanner.dart';
import 'package:mynt_plus/provider/scanner/scanners_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class ScannersListPane extends ConsumerStatefulWidget {
  final ValueChanged<String> onSelect;
  const ScannersListPane({super.key, required this.onSelect});

  @override
  ConsumerState<ScannersListPane> createState() => _ScannersListPaneState();
}

class _ScannersListPaneState extends ConsumerState<ScannersListPane> {
  String? _activeGroup; // null = All
  /// Sentiment pill filter. null = all sentiments. Driven entirely by
  /// the backend's `sentiment` field — scanners with no sentiment yet
  /// (older payloads) show only when "All" is active so we never
  /// invent a classification client-side.
  ScannerSentiment? _activeSentiment;
  final TextEditingController _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(scannerListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load scanners',
        message: e.toString(),
        onRetry: () => ref.invalidate(scannerListProvider),
      ),
      data: (resp) {
        final groups = <String, int>{};
        final sentimentCounts = <ScannerSentiment, int>{
          ScannerSentiment.bullish: 0,
          ScannerSentiment.bearish: 0,
          ScannerSentiment.neutral: 0,
        };
        for (final s in resp.items) {
          groups.update(s.groupName, (n) => n + 1, ifAbsent: () => 1);
          // Only count scanners whose backend `sentiment` field is set.
          // Unclassified scanners show under "All" but contribute 0 to
          // any specific pill — no client-side guessing.
          final sent = s.sentiment;
          if (sent != null) {
            sentimentCounts.update(sent, (n) => n + 1, ifAbsent: () => 1);
          }
        }
        final filtered = resp.items.where((s) {
          if (_activeGroup != null && s.groupName != _activeGroup) return false;
          if (_activeSentiment != null && s.sentiment != _activeSentiment) {
            return false;
          }
          if (_q.text.isEmpty) return true;
          final q = _q.text.toLowerCase();
          // Search still matches against `code` even though the column
          // is no longer rendered — users typing "RSI14" expect a hit.
          return s.displayName.toLowerCase().contains(q) ||
              s.code.toLowerCase().contains(q);
        }).toList();

        final wide = MediaQuery.of(context).size.width >= 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar(context, resp.items.length, filtered.length),
            const SizedBox(height: 12),
            _sentimentPills(context, sentimentCounts, resp.items.length),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    SizedBox(
                      width: 180,
                      child: _facets(context, groups, resp.items.length),
                    ),
                  if (wide) const SizedBox(width: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? const EmptyState(
                            kind: EmptyStateKind.search,
                            title: 'No scanners match this filter',
                          )
                        : _ScannerTable(
                            items: filtered,
                            onTap: widget.onSelect,
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sentimentPills(
    BuildContext ctx,
    Map<ScannerSentiment, int> counts,
    int total,
  ) {
    final entries = <(String, ScannerSentiment?, int, Color)>[
      ('All', null, total, MyntColors.primary),
      ('Bullish', ScannerSentiment.bullish,
          counts[ScannerSentiment.bullish] ?? 0,
          const Color(0xFF16A34A)),
      ('Bearish', ScannerSentiment.bearish,
          counts[ScannerSentiment.bearish] ?? 0,
          const Color(0xFFDC2626)),
      ('Neutral', ScannerSentiment.neutral,
          counts[ScannerSentiment.neutral] ?? 0,
          const Color(0xFF64748B)),
    ];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, value, count, color) = entries[i];
          final active = _activeSentiment == value;
          return _SentimentPill(
            label: label,
            count: count,
            color: color,
            active: active,
            onTap: () => setState(() => _activeSentiment = value),
          );
        },
      ),
    );
  }

  Widget _topBar(BuildContext context, int total, int shown) {
    return Row(
      children: [
        Text(
          'Scanners',
          style: MyntWebTextStyles.head(context, fontWeight: MyntFonts.bold),
        ),
        const SizedBox(width: 8),
        Text('/ $total total',
            style: MyntWebTextStyles.caption(context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary))),
        const Spacer(),
        SizedBox(
          width: 280,
          child: TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search scanners…',
              prefixIcon: const Icon(shadcn.LucideIcons.search, size: 14),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            style: MyntWebTextStyles.body(context),
          ),
        ),
        const SizedBox(width: 12),
        Text('$shown shown',
            style: MyntWebTextStyles.caption(context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary))),
      ],
    );
  }

  Widget _facets(BuildContext ctx, Map<String, int> groups, int total) {
    final entries = <(String, int, String?)>[
      ('All', total, null),
      for (final e in groups.entries) (e.key, e.value, e.key),
    ];
    return Container(
      padding: const EdgeInsets.only(top: 8, right: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: shadcn.Theme.of(ctx).colorScheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text('GROUPS',
                style: MyntWebTextStyles.caption(ctx,
                    fontWeight: MyntFonts.semiBold,
                    color: resolveThemeColor(ctx,
                        dark: MyntColors.textTertiaryDark,
                        light: MyntColors.textTertiary))
                    .copyWith(letterSpacing: 1.0)),
          ),
          for (final e in entries)
            _FacetRow(
              label: e.$1,
              count: e.$2,
              active: _activeGroup == e.$3,
              onTap: () => setState(() => _activeGroup = e.$3),
            ),
        ],
      ),
    );
  }
}

class _FacetRow extends StatefulWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _FacetRow({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  State<_FacetRow> createState() => _FacetRowState();
}

class _FacetRowState extends State<_FacetRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final primary = MyntColors.primary;
    final inactive = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final bg = widget.active
        ? primary.withValues(alpha: 0.10)
        : (_hover
            ? resolveThemeColor(context,
                dark: MyntColors.cardHoverDark, light: MyntColors.cardHover)
            : Colors.transparent);
    final color = widget.active ? primary : inactive;
    // No vertical margin (used to create a 1px gap that briefly cleared the
    // hover state when sweeping the cursor between items). No
    // AnimatedContainer either — the 120ms transition made two items appear
    // simultaneously lit during fast hover sweeps, looking "darker".
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.label,
                    style: MyntWebTextStyles.body(context,
                        fontWeight: widget.active
                            ? MyntFonts.semiBold
                            : MyntFonts.regular,
                        color: color)),
              ),
              Text('${widget.count}',
                  style: MyntWebTextStyles.caption(context,
                      color: widget.active ? primary : secondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentimentPill extends StatefulWidget {
  final String label;
  final int count;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _SentimentPill({
    required this.label,
    required this.count,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  State<_SentimentPill> createState() => _SentimentPillState();
}

class _SentimentPillState extends State<_SentimentPill> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final inactiveText = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final bg = widget.active
        ? color.withValues(alpha: 0.12)
        : (_hover
            ? color.withValues(alpha: 0.06)
            : Colors.transparent);
    final border = widget.active
        ? color.withValues(alpha: 0.55)
        : shadcn.Theme.of(context).colorScheme.border;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label,
                  style: MyntWebTextStyles.caption(context,
                      fontWeight: widget.active
                          ? MyntFonts.semiBold
                          : MyntFonts.medium,
                      color: widget.active ? color : inactiveText)),
              const SizedBox(width: 6),
              Text('${widget.count}',
                  style: MyntWebTextStyles.caption(context,
                      color: widget.active
                          ? color
                          : inactiveText.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact data-dense table — Group chip | Sub-group | Display name.
/// The CODE column was removed because end users don't read the codes
/// (RSI14_OVERSOLD, MACD_BULL_CROSS, …); the search box still matches
/// against code under the hood so typing "RSI" still works.
class _ScannerTable extends StatelessWidget {
  final List items;
  final ValueChanged<String> onTap;
  const _ScannerTable({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final headerBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            color: headerBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              SizedBox(width: 120, child: _hd(context, 'GROUP')),
              SizedBox(width: 220, child: _hd(context, 'SUB-GROUP')),
              Expanded(child: _hd(context, 'NAME')),
              const SizedBox(width: 24),
            ]),
          ),
          Divider(height: 1, color: border),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: border.withValues(alpha: 0.4)),
              itemBuilder: (_, i) {
                final s = items[i];
                return _ScannerRow(
                  group: s.groupName as String,
                  subGroup: (s.subGroup as String?) ?? '—',
                  name: s.displayName as String,
                  tertiary: tertiary,
                  onTap: () => onTap(s.code as String),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _hd(BuildContext ctx, String t) => Text(t,
      style: MyntWebTextStyles.caption(ctx, fontWeight: MyntFonts.semiBold,
          color: resolveThemeColor(ctx,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.textSecondary))
          .copyWith(letterSpacing: 0.6));
}

class _ScannerRow extends StatefulWidget {
  final String group;
  final String subGroup;
  final String name;
  final Color tertiary;
  final VoidCallback onTap;
  const _ScannerRow({
    required this.group,
    required this.subGroup,
    required this.name,
    required this.tertiary,
    required this.onTap,
  });

  @override
  State<_ScannerRow> createState() => _ScannerRowState();
}

class _ScannerRowState extends State<_ScannerRow> {
  bool _hover = false;

  Color _groupColor(String g) {
    switch (g.toLowerCase()) {
      case 'candlestick': return const Color(0xFFA855F7); // violet
      case 'price': return MyntColors.primary;
      case 'technical': return const Color(0xFF10B981); // emerald
      case 'volume': return MyntColors.warning;
      default: return MyntColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final gc = _groupColor(widget.group);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hover ? hoverBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            SizedBox(
              width: 120,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: gc.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(widget.group,
                      style: MyntWebTextStyles.caption(context,
                          fontWeight: MyntFonts.semiBold, color: gc)),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: Text(widget.subGroup,
                  style: MyntWebTextStyles.body(context),
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              child: Text(widget.name,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.medium),
                  overflow: TextOverflow.ellipsis),
            ),
            Icon(shadcn.LucideIcons.chevronRight,
                size: 14, color: widget.tertiary),
          ]),
        ),
      ),
    );
  }
}
