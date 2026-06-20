import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/instrument_symbol.dart';
import 'package:mynt_plus/provider/insta_options/contribution/contribution_provider.dart';
import 'package:mynt_plus/provider/insta_options/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/date_calendar.dart';

/// Index Contribution app bar: index picker (indices only, from `/symbols`) +
/// trade-date calendar + refresh.
class ContributionAppBar extends ConsumerWidget {
  const ContributionAppBar({super.key});

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(contributionProvider);
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
          _IndexPicker(
            current: p.index,
            onSelect: (i) => ref.read(contributionProvider).selectIndex(i),
          ),
          const Spacer(),
          DashDateButton(
            tradeDate: p.tradeDate.isEmpty ? null : p.tradeDate,
            selectedDate: p.selectedDateTime,
            availableDates: p.availableDates,
            onSelected: (d) =>
                ref.read(contributionProvider).selectDate(_iso(d)),
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onTap: () => ref.read(contributionProvider).refresh(),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Index picker — popover with the (few) F&O indices.
// ----------------------------------------------------------------------------
class _IndexPicker extends ConsumerStatefulWidget {
  final String current;
  final ValueChanged<String> onSelect;

  const _IndexPicker({required this.current, required this.onSelect});

  @override
  ConsumerState<_IndexPicker> createState() => _IndexPickerState();
}

class _IndexPickerState extends ConsumerState<_IndexPicker> {
  final OverlayPortalController _ctrl = OverlayPortalController();
  final LayerLink _link = LayerLink();

  void _pick(String i) {
    _ctrl.hide();
    widget.onSelect(i);
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
            child: _IndexList(current: widget.current, onPick: _pick),
          ),
        ],
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _ctrl.show,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(minWidth: 160),
              decoration: BoxDecoration(
                color: resolveThemeColor(context,
                    dark: MyntColors.cardDark, light: MyntColors.card),
                border: Border.all(color: border, width: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance, size: 15, color: fg),
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

class _IndexList extends ConsumerWidget {
  final String current;
  final void Function(String) onPick;

  const _IndexList({required this.current, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sym = ref.watch(symbolsProvider);
    final indices = sym.indices;
    final card = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 250,
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
        child: (sym.isLoading && indices.isEmpty)
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: accent),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  for (final s in indices) _item(context, s, accent),
                  const SizedBox(height: 4),
                ],
              ),
      ),
    );
  }

  Widget _item(BuildContext context, InstrumentSymbol s, Color accent) {
    final active = s.underlyingId == current;
    final fg = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    return InkWell(
      onTap: () => onPick(s.underlyingId),
      child: Container(
        color: active ? accent.withValues(alpha: 0.10) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                          color: active ? accent : fg,
                          fontWeight:
                              active ? MyntFonts.bold : MyntFonts.semiBold)),
                  Text(s.underlyingId,
                      style: MyntWebTextStyles.caption(context, color: muted)),
                ],
              ),
            ),
            if (active) Icon(Icons.check, size: 16, color: accent),
          ],
        ),
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
