import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/models/insta_options/instrument_symbol.dart';
import 'package:mynt_plus/models/insta_options/option_chain/expiry_option.dart';
import 'package:mynt_plus/provider/insta_options/charts/oi_charts_provider.dart';
import 'package:mynt_plus/provider/insta_options/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/live_date_selector.dart';

/// Shared app bar for the OI-chart screens: searchable underlying picker +
/// expiry pills + (optional) intraday interval + trade-date calendar + refresh,
/// all bound to [oiChartsProvider]. Pass [showInterval] for the timeline screens
/// (PCR / Trending); OI Statistics leaves it off.
class ChartsAppBar extends ConsumerWidget {
  final bool showInterval;

  const ChartsAppBar({super.key, this.showInterval = false});

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(oiChartsProvider);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      child: Row(
        children: [
          _UnderlyingPicker(
            current: p.underlying,
            onSelect: (u) => ref.read(oiChartsProvider).selectUnderlying(u),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _ExpirySelector(
              expiries: p.expiries,
              selected: p.selectedExpiry,
              loading: p.loadingExpiries,
              onSelect: (e) => ref.read(oiChartsProvider).selectExpiry(e),
            ),
          ),
          if (showInterval) ...[
            const SizedBox(width: 12),
            _IntervalSelector(
              current: p.interval,
              onSelect: (i) => ref.read(oiChartsProvider).setInterval(i),
            ),
          ],
          const SizedBox(width: 12),
          LiveDateSelector(
            liveMode: p.liveMode,
            liveChannel: p.liveChannel,
            freshnessHm: p.freshnessHm,
            tradeDate: p.tradeDate.isEmpty ? null : p.tradeDate,
            selectedDate: p.selectedDateTime,
            availableDates: p.availableDates,
            onSelectLive: () => ref.read(oiChartsProvider).selectLive(),
            onSelectDate: (d) => ref.read(oiChartsProvider).selectDate(_iso(d)),
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onTap: () => ref.read(oiChartsProvider).refresh(),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Underlying picker — searchable popover (indices pinned, then stocks).
// ----------------------------------------------------------------------------
class _UnderlyingPicker extends ConsumerStatefulWidget {
  final String current;
  final ValueChanged<String> onSelect;

  const _UnderlyingPicker({required this.current, required this.onSelect});

  @override
  ConsumerState<_UnderlyingPicker> createState() => _UnderlyingPickerState();
}

class _UnderlyingPickerState extends ConsumerState<_UnderlyingPicker> {
  final OverlayPortalController _ctrl = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final TextEditingController _search = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (_search.text != _q) setState(() => _q = _search.text);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open() {
    _search.clear();
    _q = '';
    _ctrl.show();
  }

  void _pick(String u) {
    _ctrl.hide();
    widget.onSelect(u);
  }

  @override
  Widget build(BuildContext context) {
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    return OverlayPortal(
      controller: _ctrl,
      overlayChildBuilder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _ctrl.hide,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: _PickerCard(controller: _search, query: _q, onPick: _pick),
          ),
        ],
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _open,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(minWidth: 150),
              decoration: BoxDecoration(
                color: resolveThemeColor(context,
                    dark: MyntColors.cardDark, light: MyntColors.card),
                border: Border.all(color: border, width: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.show_chart, size: 15, color: fg),
                  const SizedBox(width: 8),
                  Text(widget.current,
                      style: MyntWebTextStyles.bodySmall(context,
                          color: fg, fontWeight: MyntFonts.bold)),
                  const SizedBox(width: 8),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerCard extends ConsumerWidget {
  final TextEditingController controller;
  final String query;
  final void Function(String) onPick;

  const _PickerCard({
    required this.controller,
    required this.query,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sym = ref.watch(symbolsProvider);
    final results = sym.search(query);
    final card = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: card,
          border: Border.all(color: border, width: 0.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: DashSearchBox(
                  controller: controller, hint: 'Search underlying'),
            ),
            Divider(height: 1, color: border),
            SizedBox(
              height: 320,
              child: (sym.isLoading && results.isEmpty)
                  ? Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: resolveThemeColor(context,
                              dark: MyntColors.primaryDark,
                              light: MyntColors.primary)))
                  : results.isEmpty
                      ? Center(
                          child: Text('No symbols',
                              style: MyntWebTextStyles.caption(context,
                                  color: muted)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: results.length,
                          itemBuilder: (context, i) =>
                              _item(context, results[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, InstrumentSymbol s) {
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    return InkWell(
      onTap: () => onPick(s.underlyingId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.bodySmall(context,
                          color: fg, fontWeight: MyntFonts.semiBold)),
                  if (!s.isIndex && (s.sector?.isNotEmpty ?? false))
                    Text(s.sector!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            MyntWebTextStyles.caption(context, color: muted)),
                ],
              ),
            ),
            if (s.isIndex)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('INDEX',
                    style: MyntWebTextStyles.caption(context,
                            color: accent, fontWeight: MyntFonts.bold)
                        .copyWith(fontSize: 9, letterSpacing: 0.5)),
              ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Expiry selector — horizontally-scrollable pills.
// ----------------------------------------------------------------------------
class _ExpirySelector extends StatelessWidget {
  final List<ExpiryOption> expiries;
  final String? selected;
  final bool loading;
  final ValueChanged<String> onSelect;

  const _ExpirySelector({
    required this.expiries,
    required this.selected,
    required this.loading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    if (expiries.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(loading ? 'Loading expiries…' : 'No expiries',
            style: MyntWebTextStyles.caption(context, color: muted)),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in expiries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _pill(context, e),
            ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, ExpiryOption e) {
    final active = e.expiry == selected;
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final bg = active
        ? accent.withValues(alpha: 0.14)
        : resolveThemeColor(context,
            dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final fg = active
        ? accent
        : resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSelect(e.expiry),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(
                color: active ? accent : Colors.transparent, width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_short(e.expiry),
                  style: MyntWebTextStyles.caption(context,
                      color: fg,
                      fontWeight:
                          active ? MyntFonts.semiBold : MyntFonts.medium)),
              if (e.isNear) ...[
                const SizedBox(width: 5),
                Text('near',
                    style: MyntWebTextStyles.caption(context, color: fg)
                        .copyWith(fontSize: 9)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _short(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd MMM').format(d);
  }
}

// ----------------------------------------------------------------------------
// Interval selector — compact pills (1m … 60m).
// ----------------------------------------------------------------------------
class _IntervalSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;

  const _IntervalSelector({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final iv in OiChartsProvider.intervals)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onSelect(iv),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: iv == current
                        ? accent.withValues(alpha: 0.14)
                        : Colors.transparent,
                  ),
                  child: Text(iv,
                      style: MyntWebTextStyles.caption(context,
                          color: iv == current ? accent : muted,
                          fontWeight: iv == current
                              ? MyntFonts.semiBold
                              : MyntFonts.medium)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.cardDark, light: MyntColors.card),
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: fg),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
