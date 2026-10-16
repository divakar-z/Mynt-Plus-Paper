import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/orderflow/price_steps.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/orderflow/state/orderflow_store.dart';

/// Top toolbar for the Orderflow shell — symbol picker, timeframe picker
/// (both dropdowns) and a Refresh button.
///
/// Both pickers use a hand-rolled overlay instead of [DropdownButton]: the
/// chart below is rendered in an [HtmlElementView] iframe, and Material's
/// default dropdown overlay loses pointer hit-testing to the iframe's DOM
/// element. We solve this by wrapping the popup in [PointerInterceptor] AND
/// toggling the iframe's `pointer-events` via [onPopupVisibilityChanged].
class OrderflowTopBar extends StatelessWidget {
  final OrderflowStore store;
  final VoidCallback onRefresh;
  final ValueChanged<bool> onPopupVisibilityChanged;
  const OrderflowTopBar({
    super.key,
    required this.store,
    required this.onRefresh,
    required this.onPopupVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ChoicePicker<String>(
            label: 'Symbol',
            value: store.symbol,
            options: kOrderflowSymbols,
            optionLabel: (s) => s,
            onChanged: store.setSymbol,
            onPopupVisibilityChanged: onPopupVisibilityChanged,
            menuWidth: 180,
          ),
          _ChoicePicker<Timeframe>(
            label: 'Timeframe',
            value: store.timeframe,
            options: Timeframe.values,
            optionLabel: (t) => t.label,
            triggerLabel: (t) => t.label,
            onChanged: store.setTimeframe,
            onPopupVisibilityChanged: onPopupVisibilityChanged,
            menuWidth: 120,
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            icon: Icon(shadcn.LucideIcons.refreshCw,
                size: 14, color: secondary),
            label: Text('Refresh',
                style: MyntWebTextStyles.body(context, color: secondary)),
            onPressed: onRefresh,
          ),
          _OverlaySettingsButton(
            store: store,
            onPopupVisibilityChanged: onPopupVisibilityChanged,
          ),
        ],
      ),
    );
  }
}

/// Settings cog beside Refresh. Opens a small popup with toggles for the
/// four overlay indicators (Imbalance, POC, VAH/VAL, VWAP). Uses the same
/// PointerInterceptor + iframe-gate dance as the symbol/timeframe pickers
/// so the popup wins hit-testing over the chart iframe.
class _OverlaySettingsButton extends StatefulWidget {
  final OrderflowStore store;
  final ValueChanged<bool> onPopupVisibilityChanged;
  const _OverlaySettingsButton({
    required this.store,
    required this.onPopupVisibilityChanged,
  });

  @override
  State<_OverlaySettingsButton> createState() => _OverlaySettingsButtonState();
}

class _OverlaySettingsButtonState extends State<_OverlaySettingsButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _open() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    widget.onPopupVisibilityChanged(true);
  }

  @override
  void dispose() {
    if (_entry != null) {
      _entry!.remove();
      _entry = null;
      widget.onPopupVisibilityChanged(true);
    }
    super.dispose();
  }

  Widget _buildOverlay(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
      ),
      Positioned(
        width: 220,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(-180, 40),
          child: PointerInterceptor(
            child: ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) => _SettingsCard(
                overlays: widget.store.overlays,
                onChanged: widget.store.setOverlays,
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return CompositedTransformTarget(
      link: _link,
      child: TextButton.icon(
        icon: Icon(shadcn.LucideIcons.settings, size: 14, color: secondary),
        label: Text('Settings',
            style: MyntWebTextStyles.body(context, color: secondary)),
        onPressed: () => _entry == null ? _open() : _close(),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final OverlaySettings overlays;
  final ValueChanged<OverlaySettings> onChanged;
  const _SettingsCard({required this.overlays, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: Text('Indicators',
                  style: MyntWebTextStyles.caption(context,
                      fontWeight: MyntFonts.semiBold,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textTertiaryDark,
                          light: MyntColors.textTertiary))),
            ),
            _ToggleRow(
              label: 'Imbalance',
              value: overlays.imbalance,
              onChanged: (v) => onChanged(overlays.copyWith(imbalance: v)),
            ),
            _ToggleRow(
              label: 'POC',
              value: overlays.poc,
              onChanged: (v) => onChanged(overlays.copyWith(poc: v)),
            ),
            _ToggleRow(
              label: 'Value Area (VAH / VAL)',
              value: overlays.valueArea,
              onChanged: (v) => onChanged(overlays.copyWith(valueArea: v)),
            ),
            _ToggleRow(
              label: 'VWAP',
              value: overlays.vwap,
              onChanged: (v) => onChanged(overlays.copyWith(vwap: v)),
            ),
            _ToggleRow(
              label: 'Gridlines',
              value: overlays.gridlines,
              onChanged: (v) => onChanged(overlays.copyWith(gridlines: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Material's Switch is sized for touch; in a desktop popup it dominates
    // the row. Scale it down + cap the tap target so the row stays compact.
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(label, style: MyntWebTextStyles.body(context)),
          ),
          SizedBox(
            height: 24,
            child: Transform.scale(
              scale: 0.7,
              alignment: Alignment.centerRight,
              child: Switch(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Generic dropdown trigger + popup. T is the option type; `optionLabel`
/// formats how each row appears in the menu, `triggerLabel` (optional) lets
/// the closed-state button show a different short form.
class _ChoicePicker<T> extends StatefulWidget {
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) optionLabel;
  final String Function(T)? triggerLabel;
  final ValueChanged<T> onChanged;
  final ValueChanged<bool> onPopupVisibilityChanged;
  final double menuWidth;
  const _ChoicePicker({
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    required this.onPopupVisibilityChanged,
    this.triggerLabel,
    this.menuWidth = 160,
  });

  @override
  State<_ChoicePicker<T>> createState() => _ChoicePickerState<T>();
}

class _ChoicePickerState<T> extends State<_ChoicePicker<T>> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _open() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    widget.onPopupVisibilityChanged(true);
  }

  @override
  void dispose() {
    if (_entry != null) {
      _entry!.remove();
      _entry = null;
      widget.onPopupVisibilityChanged(true);
    }
    super.dispose();
  }

  Widget _buildOverlay(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
      ),
      Positioned(
        width: widget.menuWidth,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: PointerInterceptor(
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final o in widget.options)
                      _ChoiceItem(
                        label: widget.optionLabel(o),
                        selected: o == widget.value,
                        hoverBg: hoverBg,
                        onTap: () {
                          widget.onChanged(o);
                          _close();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final trigger = widget.triggerLabel ?? widget.optionLabel;
    return CompositedTransformTarget(
      link: _link,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.label,
            style: MyntWebTextStyles.caption(context, color: secondary)),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            if (_entry == null) {
              _open();
            } else {
              _close();
            }
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(trigger(widget.value),
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.semiBold)),
              const SizedBox(width: 6),
              Icon(shadcn.LucideIcons.chevronDown, size: 14, color: secondary),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ChoiceItem extends StatefulWidget {
  final String label;
  final bool selected;
  final Color hoverBg;
  final VoidCallback onTap;
  const _ChoiceItem({
    required this.label,
    required this.selected,
    required this.hoverBg,
    required this.onTap,
  });

  @override
  State<_ChoiceItem> createState() => _ChoiceItemState();
}

class _ChoiceItemState extends State<_ChoiceItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: _hover || widget.selected ? widget.hoverBg : Colors.transparent,
          child: Row(children: [
            Expanded(
              child: Text(widget.label,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: widget.selected
                          ? MyntFonts.semiBold
                          : MyntFonts.regular)),
            ),
            if (widget.selected)
              Icon(shadcn.LucideIcons.check,
                  size: 14,
                  color: resolveThemeColor(context,
                      dark: MyntColors.primaryDark, light: MyntColors.primary)),
          ]),
        ),
      ),
    );
  }
}
