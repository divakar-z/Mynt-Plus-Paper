import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/layout_picker.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/overlay_close_dialog.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/refined_controls.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/symbol_type_ahead.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/timeframe_picker.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/top_bar_flags.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/order_defaults_tabs.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/customize_tab.dart';

class ChartEngineTopBar extends ConsumerWidget {
  final ValueChanged<bool> onPopupVisibilityChanged;
  const ChartEngineTopBar({super.key, required this.onPopupVisibilityChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final pane = ref.watch(chartEngineSessionProvider).active;
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    final activeIdx = ref.watch(chartEngineSessionProvider).activePaneIndex;
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
          // Layout picker moved into the iframe top bar. See [TopBarFlags].
          if (!TopBarFlags.kJsLayoutPicker)
            LayoutPicker(onPopupVisibilityChanged: onPopupVisibilityChanged),
          // Symbol typeahead moved into the iframe top bar. See [TopBarFlags].
          if (!TopBarFlags.kJsSymbolTypeAhead)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Symbol', style: MyntWebTextStyles.caption(context)),
              const SizedBox(width: 8),
              SymbolTypeAhead(
                current: pane.scrip,
                onPicked: (s) => notifier.setPaneSymbol(activeIdx, s),
                onPopupVisibilityChanged: onPopupVisibilityChanged,
              ),
            ]),
          // Timeframe dropdown moved into the iframe top bar. See [TopBarFlags].
          if (!TopBarFlags.kJsTimeframeDropdown)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Timeframe', style: MyntWebTextStyles.caption(context)),
              const SizedBox(width: 8),
              TimeframePicker(
                valueMinutes: pane.timeframeMinutes,
                onChanged: (m) => notifier.setPaneTimeframe(activeIdx, m),
                onPopupVisibilityChanged: onPopupVisibilityChanged,
              ),
            ]),
          // Candle-style picker moved into the iframe top bar. See [TopBarFlags].
          if (!TopBarFlags.kJsStylePicker)
            _CandleStyleButton(
              onPopupVisibilityChanged: onPopupVisibilityChanged,
            ),
          // Cursor-mode picker moved into the iframe top bar. See [TopBarFlags].
          if (!TopBarFlags.kJsCursorMode)
            _CursorModeButton(
              onPopupVisibilityChanged: onPopupVisibilityChanged,
            ),
          // Settings button moved into the iframe top bar. See [TopBarFlags].
          if (!TopBarFlags.kJsSettings)
            _SettingsButton(
              onPopupVisibilityChanged: onPopupVisibilityChanged,
            ),
          // Order Defaults moved into the iframe top bar. See [TopBarFlags].
          if (!TopBarFlags.kJsOrderDefaults)
            _OrderDefaultsButton(
              onPopupVisibilityChanged: onPopupVisibilityChanged,
            ),
          // Draw button moved into the iframe top bar. See [TopBarFlags].
          if (!TopBarFlags.kJsDrawToolbar)
            _DrawButton(onPopupVisibilityChanged: onPopupVisibilityChanged),
          // Snap (screenshot) moved into the iframe top bar. See [TopBarFlags].
          if (!TopBarFlags.kJsSnapButton)
            TextButton.icon(
              icon: const Icon(Icons.camera_alt_outlined, size: 14),
              label: const Text('Snap'),
              onPressed: () {
                final session = ref.read(chartEngineSessionProvider);
                final activeIdx = session.activePaneIndex;
                ref.read(screenshotRequestProvider.notifier).request(activeIdx);
              },
            ),
          // Indicators (fx) button moved into the iframe top bar. See [TopBarFlags].
          if (!TopBarFlags.kJsIndicatorsButton)
            _IndicatorsButton(onPopupVisibilityChanged: onPopupVisibilityChanged),
          // The INSTANT chip has moved into the iframe's HTML top bar
          // (`web/chart-engine/topbar.js`). Hidden here so the two
          // implementations never both render. See [TopBarFlags].
          if (!TopBarFlags.kJsInstantBadge)
            _InstantBadge(
              onTap: () {
                // Reuses the Settings button's open mechanism — for now we
                // just surface this hint and let the user click Settings
                // manually. (A direct wire-up would require a GlobalKey on
                // _SettingsButton.)
              },
            ),
        ],
      ),
    );
  }
}

// ─── Chart Settings popover (3 tabs) ─────────────────────────────────────────

enum _ChartSettingsTab { chartType, customize, viewOnChart }

extension on _ChartSettingsTab {
  String get label {
    switch (this) {
      case _ChartSettingsTab.chartType:
        return 'Chart type';
      case _ChartSettingsTab.customize:
        return 'Customize';
      case _ChartSettingsTab.viewOnChart:
        return 'View on chart';
    }
  }
}

class _SettingsButton extends ConsumerStatefulWidget {
  final ValueChanged<bool> onPopupVisibilityChanged;
  const _SettingsButton({required this.onPopupVisibilityChanged});

  @override
  ConsumerState<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends ConsumerState<_SettingsButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  _ChartSettingsTab _tab = _ChartSettingsTab.chartType;

  void _open() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _build);
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
      widget.onPopupVisibilityChanged(true);
    }
    super.dispose();
  }

  Widget _build(BuildContext context) {
    final session = ref.read(chartEngineSessionProvider);
    final activeIdx = session.activePaneIndex;
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
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(-280, 38),
          child: PointerInterceptor(
            child: RefinedPopoverCard(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RefinedPopoverHeader(
                    title: 'Settings',
                    subtitle: 'Chart appearance and on-chart overlays',
                    onClose: _close,
                  ),
                  RefinedTabStrip(
                    tabs: _ChartSettingsTab.values.map((t) => t.label).toList(),
                    activeIndex: _tab.index,
                    onTap: (i) {
                      _tab = _ChartSettingsTab.values[i];
                      _entry?.markNeedsBuild();
                    },
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: _buildBody(context, activeIdx),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildBody(BuildContext context, int activeIdx) {
    switch (_tab) {
      case _ChartSettingsTab.chartType:
        return _ChartTypeTab(paneIndex: activeIdx);
      case _ChartSettingsTab.customize:
        return const ChartCustomizeTab();
      case _ChartSettingsTab.viewOnChart:
        return _ViewOnChartTab(paneIndex: activeIdx);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChartEngineSession>(chartEngineSessionProvider, (_, __) {
      _entry?.markNeedsBuild();
    });
    return CompositedTransformTarget(
      link: _link,
      child: TextButton.icon(
        icon: const Icon(shadcn.LucideIcons.settings, size: 14),
        label: const Text('Settings'),
        onPressed: () => _entry == null ? _open() : _close(),
      ),
    );
  }
}

// Outer card sits in a `Stack`+`Positioned` so the popover hugs the trigger.
// Each tab body is just a vertical column of refined rows — no scroll
// gymnastics. ConstrainedBox elsewhere keeps the card from tearing off-screen.

class _ChartTypeTab extends ConsumerWidget {
  final int paneIndex;
  const _ChartTypeTab({required this.paneIndex});

  static const _items = <_StyleItem>[
    _StyleItem('candles', 'Candle', Icons.candlestick_chart),
    _StyleItem('hollow', 'Hollow Candle', Icons.crop_square),
    _StyleItem('bars', 'OHLC Bars', Icons.bar_chart),
    _StyleItem('line', 'Line', Icons.show_chart),
    _StyleItem('area', 'Area', Icons.area_chart),
    _StyleItem('heikin-ashi', 'Heikin Ashi', Icons.view_week),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) {
      return const SizedBox.shrink();
    }
    final current = session.panes[paneIndex].candleStyle;
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.4,
        children: [
          for (final it in _items)
            _ChartTypeCard(
              item: it,
              selected: it.id == current,
              onTap: () => notifier.setPaneCandleStyle(paneIndex, it.id),
            ),
        ],
      ),
    );
  }
}

class _ChartTypeCard extends StatefulWidget {
  final _StyleItem item;
  final bool selected;
  final VoidCallback onTap;
  const _ChartTypeCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ChartTypeCard> createState() => _ChartTypeCardState();
}

class _ChartTypeCardState extends State<_ChartTypeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final idleBg = isDark ? const Color(0xFF1A2030) : const Color(0xFFF8FAFC);
    final idleBorder =
        isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);
    final mute = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final bg = widget.selected
        ? accent.withValues(alpha: 0.14)
        : (_hover ? accent.withValues(alpha: 0.06) : idleBg);
    final borderColor = widget.selected ? accent : idleBorder;
    final iconColor = widget.selected
        ? accent
        : (_hover
            ? resolveThemeColor(context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary)
            : mute);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(
                color: borderColor, width: widget.selected ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.item.icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: widget.selected
                          ? MyntFonts.semiBold
                          : MyntFonts.medium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewOnChartTab extends ConsumerWidget {
  final int paneIndex;
  const _ViewOnChartTab({required this.paneIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(chartEngineSessionProvider);
    if (paneIndex < 0 || paneIndex >= session.panes.length) {
      return const SizedBox.shrink();
    }
    final pane = session.panes[paneIndex];
    final overlays = pane.overlays;
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    final mute = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefinedRow(
          label: 'High / Low markers',
          description: 'Visible-range price extremes',
          control: RefinedSwitch(
            value: pane.showHighLowMarkers,
            onChanged: (v) =>
                notifier.setPaneShowHighLowMarkers(paneIndex, v),
          ),
          onTap: () => notifier.setPaneShowHighLowMarkers(
              paneIndex, !pane.showHighLowMarkers),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Option-chain OI',
          description: 'Open-interest bars at strikes',
          control: RefinedSwitch(
            value: pane.showOptionChainOi,
            onChanged: (v) =>
                notifier.setPaneShowOptionChainOi(paneIndex, v),
          ),
          onTap: () => notifier.setPaneShowOptionChainOi(
              paneIndex, !pane.showOptionChainOi),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Bar countdown',
          description: 'Time until current bar closes',
          control: RefinedSwitch(
            value: pane.showBarCountdown,
            onChanged: (v) =>
                notifier.setPaneShowBarCountdown(paneIndex, v),
          ),
          onTap: () => notifier.setPaneShowBarCountdown(
              paneIndex, !pane.showBarCountdown),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Auto-pattern',
          description: 'HH / HL / LH / LL labels',
          control: RefinedSwitch(
            value: pane.showAutoPattern,
            onChanged: (v) =>
                notifier.setPaneShowAutoPattern(paneIndex, v),
          ),
          onTap: () => notifier.setPaneShowAutoPattern(
              paneIndex, !pane.showAutoPattern),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Magnet',
          description: 'While drawing, snap to the nearest candle Open / '
              'High / Low / Close within 8 px of the cursor',
          control: RefinedSwitch(
            value: pane.magnetEnabled,
            onChanged: (v) => notifier.setPaneMagnetEnabled(paneIndex, v),
          ),
          onTap: () => notifier.setPaneMagnetEnabled(
              paneIndex, !pane.magnetEnabled),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Volume profile',
          description: 'Right-gutter horizontal histogram',
          control: RefinedSwitch(
            value: pane.showVolumeProfile,
            onChanged: (v) =>
                notifier.setPaneShowVolumeProfile(paneIndex, v),
          ),
          onTap: () => notifier.setPaneShowVolumeProfile(
              paneIndex, !pane.showVolumeProfile),
        ),
        const RefinedDivider(),
        // Crosshair lines toggle moved to its own top-bar Cursor Mode
        // dropdown (next to the Chart Type button) — kept off the Settings
        // list to avoid duplication.
        RefinedRow(
          label: 'Gridlines',
          description: 'Background reference grid',
          control: RefinedSwitch(
            value: overlays.gridlines,
            onChanged: (v) => notifier.setPaneOverlays(
                paneIndex, overlays.copyWith(gridlines: v)),
          ),
          onTap: () => notifier.setPaneOverlays(
              paneIndex, overlays.copyWith(gridlines: !overlays.gridlines)),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Volume sub-pane',
          description: 'Below-chart volume bars',
          control: RefinedSwitch(
            value: overlays.volume,
            onChanged: (v) => notifier.setPaneOverlays(
                paneIndex, overlays.copyWith(volume: v)),
          ),
          onTap: () => notifier.setPaneOverlays(
              paneIndex, overlays.copyWith(volume: !overlays.volume)),
        ),
        const RefinedDivider(),
        // drawingsHidden is "true when hidden"; flip semantics so this reads
        // alongside the rest of the column's show-toggles.
        RefinedRow(
          label: 'Drawings',
          description: 'Show all drawing objects',
          control: RefinedSwitch(
            value: !session.drawingsHidden,
            onChanged: (v) => notifier.setDrawingsHidden(!v),
          ),
          onTap: () => notifier.setDrawingsHidden(!session.drawingsHidden),
        ),
        const RefinedDivider(),
        RefinedRow(
          label: 'Keyboard shortcuts',
          description: 'Alt+B/S, 1/5/H/D and more',
          control: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                waitDuration: const Duration(milliseconds: 200),
                richMessage: const TextSpan(
                  children: [
                    TextSpan(
                        text: 'Keyboard shortcuts\n\n',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                    TextSpan(
                        text: 'Alt + B  →  Buy LMT at hovered price\n'
                            'Alt + S  →  Sell LMT at hovered price\n'
                            'Alt + I  →  Toggle Instant orders\n\n'
                            '1 / 5 / Shift+1 / H / D  →  '
                            'switch timeframe to 1m / 5m / 15m / 1h / 1d\n\n'
                            'Esc  →  cancel draw / drag / popup',
                        style: TextStyle(fontSize: 11)),
                  ],
                ),
                child: Icon(Icons.info_outline, size: 16, color: mute),
              ),
              const SizedBox(width: 8),
              RefinedSwitch(
                value: session.keyboardShortcuts,
                onChanged: (v) => notifier.setKeyboardShortcuts(v),
              ),
            ],
          ),
          onTap: () =>
              notifier.setKeyboardShortcuts(!session.keyboardShortcuts),
        ),
      ],
    );
  }
}

// ─── Order Defaults popover (4 tabs) ─────────────────────────────────────────

enum _OrderDefaultsTab { oneTap, slTp, tradeQty, productType }

extension on _OrderDefaultsTab {
  String get label {
    switch (this) {
      case _OrderDefaultsTab.oneTap:
        return '1-Tap';
      case _OrderDefaultsTab.slTp:
        return 'SL / TP';
      case _OrderDefaultsTab.tradeQty:
        return 'Quantity';
      case _OrderDefaultsTab.productType:
        return 'Product';
    }
  }
}

class _OrderDefaultsButton extends ConsumerStatefulWidget {
  final ValueChanged<bool> onPopupVisibilityChanged;
  const _OrderDefaultsButton({required this.onPopupVisibilityChanged});

  @override
  ConsumerState<_OrderDefaultsButton> createState() =>
      _OrderDefaultsButtonState();
}

class _OrderDefaultsButtonState extends ConsumerState<_OrderDefaultsButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  _OrderDefaultsTab _tab = _OrderDefaultsTab.oneTap;

  void _open() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _build);
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
      widget.onPopupVisibilityChanged(true);
    }
    super.dispose();
  }

  Widget _build(BuildContext context) {
    final session = ref.read(chartEngineSessionProvider);
    final activeIdx = session.activePaneIndex;
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
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(-260, 38),
          child: PointerInterceptor(
            child: RefinedPopoverCard(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RefinedPopoverHeader(
                    title: 'Order defaults',
                    subtitle: 'How orders behave from this chart',
                    onClose: _close,
                  ),
                  RefinedTabStrip(
                    tabs: _OrderDefaultsTab.values
                        .map((t) => t.label)
                        .toList(),
                    activeIndex: _tab.index,
                    onTap: (i) {
                      _tab = _OrderDefaultsTab.values[i];
                      _entry?.markNeedsBuild();
                    },
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: _buildBody(context, activeIdx),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildBody(BuildContext context, int activeIdx) {
    switch (_tab) {
      case _OrderDefaultsTab.oneTap:
        return _OneTapTab(paneIndex: activeIdx);
      case _OrderDefaultsTab.slTp:
        return SlTpDefaultsTab(activeIdx);
      case _OrderDefaultsTab.tradeQty:
        return TradeQtyDefaultsTab(activeIdx);
      case _OrderDefaultsTab.productType:
        return ProductTypeDefaultsTab(activeIdx);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChartEngineSession>(chartEngineSessionProvider, (_, __) {
      _entry?.markNeedsBuild();
    });
    return CompositedTransformTarget(
      link: _link,
      child: TextButton.icon(
        icon: const Icon(Icons.tune, size: 14),
        label: const Text('Order Defaults'),
        onPressed: () => _entry == null ? _open() : _close(),
      ),
    );
  }
}

class _OneTapTab extends ConsumerWidget {
  final int paneIndex;
  const _OneTapTab({required this.paneIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(chartEngineSessionProvider);
    final mute = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final notifier = ref.read(chartEngineSessionProvider.notifier);

    Future<void> onChangeInstant(bool v) async {
      // Preserve the existing warning-ack gate for the destructive direction.
      if (v && !session.instantWarningAck) {
        final ok = await showInstantWarningDialog(context: context);
        if (!ok) return;
        notifier.markInstantWarningAck();
      }
      notifier.setInstantOrders(v);
    }

    final hasPane = paneIndex >= 0 && paneIndex < session.panes.length;
    final current = hasPane ? session.panes[paneIndex].instantOverride : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefinedRow(
          label: 'Instant orders',
          description: session.instantOrders
              ? 'Skips confirmation for cancels, exits, drags'
              : 'Confirm dialog before every action',
          control: RefinedSwitch(
            value: session.instantOrders,
            onChanged: onChangeInstant,
          ),
          onTap: () => onChangeInstant(!session.instantOrders),
        ),
        const RefinedDivider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('For this pane',
                          style: MyntWebTextStyles.body(context,
                              fontWeight: MyntFonts.semiBold)),
                      const SizedBox(height: 2),
                      Text('Override the global setting just here.',
                          style: MyntWebTextStyles.caption(context,
                              color: mute)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              if (!hasPane)
                Text('No active pane.',
                    style:
                        MyntWebTextStyles.caption(context, color: mute))
              else
                RefinedSegmented<String?>(
                  value: current,
                  onChanged: (v) =>
                      notifier.setPaneInstantOverride(paneIndex, v),
                  options: const [
                    RefinedSegmentOption<String?>(
                        value: null, label: 'Follow'),
                    RefinedSegmentOption<String?>(
                        value: 'on', label: 'Instant'),
                    RefinedSegmentOption<String?>(
                        value: 'off', label: 'Confirm'),
                  ],
                ),
            ],
          ),
        ),
        const RefinedDivider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exit from charts',
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.semiBold)),
              const SizedBox(height: 2),
              Text('Sends a market order to the exchange.',
                  style: MyntWebTextStyles.caption(context, color: mute)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Draw popover ───────────────────────────────────────────────────────────

class _DrawTool {
  final String kind;
  final String label;
  final IconData icon;
  const _DrawTool(this.kind, this.label, this.icon);
}

// ─── Candle style — top-bar dropdown that lifts the chart-type picker out
// of the Settings popup and onto the main toolbar where it can be reached
// in one click. Shows the active style's icon as the trigger.
class _CandleStyleButton extends ConsumerStatefulWidget {
  final ValueChanged<bool> onPopupVisibilityChanged;
  const _CandleStyleButton({required this.onPopupVisibilityChanged});

  @override
  ConsumerState<_CandleStyleButton> createState() =>
      _CandleStyleButtonState();
}

class _CandleStyleEntry {
  final String id;
  final String label;
  final IconData icon;
  const _CandleStyleEntry(this.id, this.label, this.icon);
}

class _CandleStyleButtonState extends ConsumerState<_CandleStyleButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  static const _styles = <_CandleStyleEntry>[
    _CandleStyleEntry('candles', 'Candle', Icons.candlestick_chart),
    _CandleStyleEntry('hollow', 'Hollow Candle', Icons.crop_din),
    _CandleStyleEntry('bars', 'OHLC Bars', Icons.bar_chart),
    _CandleStyleEntry('line', 'Line', Icons.show_chart),
    _CandleStyleEntry('area', 'Area', Icons.area_chart),
    _CandleStyleEntry('heikin-ashi', 'Heikin Ashi', Icons.equalizer),
  ];

  void _open() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _build);
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

  Widget _build(BuildContext context) {
    final session = ref.read(chartEngineSessionProvider);
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    final activeIdx = session.activePaneIndex;
    final currentStyle = session.active.candleStyle;
    return Stack(children: [
      Positioned.fill(
        // PointerInterceptor MUST wrap GestureDetector (not the other way
        // around) for click-outside to land in Flutter — the interceptor
        // claims pointer events from the iframe; the GestureDetector then
        // turns them into onTap. Reversing the order means the iframe
        // keeps the click and the popover never closes.
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
      ),
      CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: const Offset(0, 36),
        child: PointerInterceptor(
          child: Material(
            color: Colors.transparent,
            child: RefinedPopoverCard(
              width: 220,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in _styles)
                    _StylePickerRow(
                      entry: s,
                      selected: s.id == currentStyle,
                      onTap: () {
                        notifier.setPaneCandleStyle(activeIdx, s.id);
                        _close();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  IconData _activeIcon(String id) {
    for (final s in _styles) {
      if (s.id == id) return s.icon;
    }
    return Icons.candlestick_chart;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(chartEngineSessionProvider);
    final currentStyle = session.active.candleStyle;
    return CompositedTransformTarget(
      link: _link,
      child: Tooltip(
        message: 'Chart type',
        child: TextButton.icon(
          icon: Icon(_activeIcon(currentStyle), size: 16),
          label: const Icon(Icons.arrow_drop_down, size: 16),
          onPressed: () => _entry == null ? _open() : _close(),
        ),
      ),
    );
  }
}

class _StylePickerRow extends StatefulWidget {
  final _CandleStyleEntry entry;
  final bool selected;
  final VoidCallback onTap;
  const _StylePickerRow({
    required this.entry,
    required this.selected,
    required this.onTap,
  });
  @override
  State<_StylePickerRow> createState() => _StylePickerRowState();
}

class _StylePickerRowState extends State<_StylePickerRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final color = widget.selected
        ? accent
        : resolveThemeColor(context,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          // Instant hover swap — animating the bg colour left a "trail" of
          // dark rows behind the cursor when the user moved fast through
          // the dropdown.
          color: _hover ? hoverBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(widget.entry.icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.entry.label,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: widget.selected
                          ? MyntFonts.semiBold
                          : MyntFonts.medium,
                      darkColor:
                          widget.selected ? accent : MyntColors.textPrimaryDark,
                      lightColor:
                          widget.selected ? accent : MyntColors.textPrimary)),
            ),
            if (widget.selected)
              Icon(Icons.check, size: 16, color: accent),
          ]),
        ),
      ),
    );
  }
}

// ─── Cursor mode — quick toggle between full crosshair and a plain
// pointer. Backed by the per-pane `showCrosshairLines` flag so price/time
// chips keep rendering even when the spanning lines are off.
class _CursorModeButton extends ConsumerStatefulWidget {
  final ValueChanged<bool> onPopupVisibilityChanged;
  const _CursorModeButton({required this.onPopupVisibilityChanged});

  @override
  ConsumerState<_CursorModeButton> createState() => _CursorModeButtonState();
}

class _CursorModeButtonState extends ConsumerState<_CursorModeButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _open() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _build);
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

  Widget _build(BuildContext context) {
    final session = ref.read(chartEngineSessionProvider);
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    final activeIdx = session.activePaneIndex;
    final crosshairOn = session.active.showCrosshairLines;
    return Stack(children: [
      Positioned.fill(
        // PointerInterceptor MUST wrap GestureDetector (not the other way
        // around) for click-outside to land in Flutter — the interceptor
        // claims pointer events from the iframe; the GestureDetector then
        // turns them into onTap. Reversing the order means the iframe
        // keeps the click and the popover never closes.
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
      ),
      CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: const Offset(0, 36),
        child: PointerInterceptor(
          child: Material(
            color: Colors.transparent,
            child: RefinedPopoverCard(
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CursorModeRow(
                    icon: Icons.add,
                    label: 'Crosshair',
                    selected: crosshairOn,
                    onTap: () {
                      notifier.setPaneShowCrosshairLines(activeIdx, true);
                      _close();
                    },
                  ),
                  _CursorModeRow(
                    icon: Icons.mouse_outlined,
                    label: 'Cursor',
                    selected: !crosshairOn,
                    onTap: () {
                      notifier.setPaneShowCrosshairLines(activeIdx, false);
                      _close();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(chartEngineSessionProvider);
    final crosshairOn = session.active.showCrosshairLines;
    return CompositedTransformTarget(
      link: _link,
      child: Tooltip(
        message: 'Cursor mode',
        child: TextButton.icon(
          icon: Icon(crosshairOn ? Icons.add : Icons.mouse_outlined, size: 16),
          label: const Icon(Icons.arrow_drop_down, size: 16),
          onPressed: () => _entry == null ? _open() : _close(),
        ),
      ),
    );
  }
}

class _CursorModeRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CursorModeRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  State<_CursorModeRow> createState() => _CursorModeRowState();
}

class _CursorModeRowState extends State<_CursorModeRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          // Instant hover swap — animating the bg colour left a "trail" of
          // dark rows behind the cursor when the user moved fast through
          // the dropdown.
          color: _hover ? hoverBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(widget.icon,
                size: 18,
                color: widget.selected
                    ? accent
                    : resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.label,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: widget.selected
                          ? MyntFonts.semiBold
                          : MyntFonts.medium,
                      darkColor:
                          widget.selected ? accent : MyntColors.textPrimaryDark,
                      lightColor:
                          widget.selected ? accent : MyntColors.textPrimary)),
            ),
            if (widget.selected)
              Icon(Icons.check, size: 16, color: accent),
          ]),
        ),
      ),
    );
  }
}

class _DrawButton extends ConsumerStatefulWidget {
  final ValueChanged<bool> onPopupVisibilityChanged;
  const _DrawButton({required this.onPopupVisibilityChanged});

  @override
  ConsumerState<_DrawButton> createState() => _DrawButtonState();
}

class _DrawButtonState extends ConsumerState<_DrawButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  static const _tools = <_DrawTool>[
    _DrawTool('trendline', 'Trendline', Icons.show_chart),
    _DrawTool('hline', 'Horizontal line', Icons.horizontal_rule),
    _DrawTool('hray', 'Horizontal ray', Icons.east),
    _DrawTool('rect', 'Rectangle', Icons.crop_square),
    _DrawTool('fib', 'Fib retracement', Icons.timeline),
    _DrawTool('path', 'Path (multi-point)', Icons.polyline),
    _DrawTool('measure', 'Measure', Icons.straighten),
  ];

  void _openMenu() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _buildMenu);
    Overlay.of(context).insert(_entry!);
  }

  void _closeMenu() {
    _entry?.remove();
    _entry = null;
    widget.onPopupVisibilityChanged(true);
  }

  void _pick(String kind) {
    _closeMenu();
    ref.read(chartEngineSessionProvider.notifier).setActiveDrawTool(kind);
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

  Widget _buildMenu(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeMenu,
          ),
        ),
      ),
      Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(0, 38),
          child: PointerInterceptor(
            child: RefinedPopoverCard(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RefinedPopoverHeader(
                    title: 'Draw',
                    subtitle: 'Pick a tool, then click on the chart',
                    onClose: _closeMenu,
                  ),
                  const RefinedSectionLabel(label: 'Tools'),
                  for (final t in _tools)
                    _DrawToolRow(
                      tool: t,
                      onPick: () => _pick(t.kind),
                    ),
                  const SizedBox(height: 10),
                  const RefinedDivider(),
                  _DrawBottomToolbar(onAction: _closeMenu),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(
        chartEngineSessionProvider.select((s) => s.activeDrawTool));
    final label = active == null
        ? 'Draw'
        : active == 'hline'
            ? 'Drawing: HLine'
            : active == 'hray'
                ? 'Drawing: H.Ray'
                : active == 'rect'
                    ? 'Drawing: Rectangle'
                    : active == 'fib'
                        ? 'Drawing: Fib'
                        : active == 'path'
                            ? 'Drawing: Path'
                            : 'Drawing: Trendline';
    final isActive = active != null;
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return CompositedTransformTarget(
      link: _link,
      child: TextButton.icon(
        icon: const Icon(shadcn.LucideIcons.pencil, size: 14),
        label: Text(label),
        style: TextButton.styleFrom(
          backgroundColor: isActive ? accent : null,
          foregroundColor: isActive ? Colors.white : null,
        ),
        onPressed: () {
          if (isActive) {
            ref
                .read(chartEngineSessionProvider.notifier)
                .setActiveDrawTool(null);
          } else {
            _openMenu();
          }
        },
      ),
    );
  }
}

class _DrawToolRow extends StatefulWidget {
  final _DrawTool tool;
  final VoidCallback onPick;
  const _DrawToolRow({required this.tool, required this.onPick});

  @override
  State<_DrawToolRow> createState() => _DrawToolRowState();
}

class _DrawToolRowState extends State<_DrawToolRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final iconColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPick,
        child: Container(
          color: _hover ? hoverBg.withValues(alpha: 0.5) : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(children: [
            Icon(widget.tool.icon, size: 16, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.tool.label,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.medium)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DrawBottomToolbar extends ConsumerWidget {
  final VoidCallback onAction;
  const _DrawBottomToolbar({required this.onAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(chartEngineSessionProvider);
    final notifier = ref.read(chartEngineSessionProvider.notifier);
    final lossColor = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: _DrawToolbarButton(
              icon: session.drawingsLocked ? Icons.lock : Icons.lock_open,
              label: session.drawingsLocked ? 'Unlock' : 'Lock',
              onTap: () {
                notifier.setDrawingsLocked(!session.drawingsLocked);
                onAction();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DrawToolbarButton(
              icon: session.drawingsHidden
                  ? Icons.visibility_off
                  : Icons.visibility,
              label: session.drawingsHidden ? 'Show' : 'Hide',
              onTap: () {
                notifier.setDrawingsHidden(!session.drawingsHidden);
                onAction();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DrawToolbarButton(
              icon: Icons.delete_outline,
              label: 'Trash',
              destructive: true,
              destructiveColor: lossColor,
              onTap: () {
                notifier.clearDrawingsForActivePane();
                onAction();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawToolbarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final Color? destructiveColor;
  const _DrawToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.destructiveColor,
  });

  @override
  State<_DrawToolbarButton> createState() => _DrawToolbarButtonState();
}

class _DrawToolbarButtonState extends State<_DrawToolbarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2030) : const Color(0xFFF8FAFC);
    final stroke =
        isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);
    final accent = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final tint =
        widget.destructive ? widget.destructiveColor ?? accent : accent;
    final hoverBg = widget.destructive
        ? tint.withValues(alpha: 0.10)
        : (isDark ? const Color(0xFF222B3D) : const Color(0xFFEFF3F8));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 38,
          decoration: BoxDecoration(
            color: _hover ? hoverBg : bg,
            border: Border.all(
                color: _hover && widget.destructive
                    ? tint.withValues(alpha: 0.45)
                    : stroke,
                width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 14, color: tint),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: TextStyle(
                    color: tint,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Instant badge (unchanged behavior) ──────────────────────────────────────

class _InstantBadge extends ConsumerWidget {
  final VoidCallback onTap;
  const _InstantBadge({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
        chartEngineSessionProvider.select((s) => s.instantOrders));
    if (!on) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('⚠ INSTANT',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11)),
      ),
    );
  }
}

class _StyleItem {
  final String id;
  final String label;
  final IconData icon;
  const _StyleItem(this.id, this.label, this.icon);
}

// ─── Indicators popover ─────────────────────────────────────────────────────

enum _IndicatorCategory {
  all('All'),
  trend('Trend'),
  momentum('Momentum'),
  volatility('Volatility');

  final String label;
  const _IndicatorCategory(this.label);
}

class _IndicatorCatalogEntry {
  final String kind;
  final String label;
  final String fullName;
  final _IndicatorCategory category;
  const _IndicatorCatalogEntry(
      this.kind, this.label, this.fullName, this.category);
}

class _IndicatorsButton extends ConsumerStatefulWidget {
  final ValueChanged<bool> onPopupVisibilityChanged;
  const _IndicatorsButton({required this.onPopupVisibilityChanged});

  @override
  ConsumerState<_IndicatorsButton> createState() => _IndicatorsButtonState();
}

class _IndicatorsButtonState extends ConsumerState<_IndicatorsButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _open() {
    if (_entry != null) return;
    widget.onPopupVisibilityChanged(false);
    _entry = OverlayEntry(builder: _build);
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

  Widget _build(BuildContext context) {
    return _IndicatorsDialog(onClose: _close, link: _link);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChartEngineSession>(chartEngineSessionProvider, (_, __) {
      _entry?.markNeedsBuild();
    });
    return CompositedTransformTarget(
      link: _link,
      child: TextButton.icon(
        icon: const Icon(Icons.functions, size: 14),
        label: const Text('fx'),
        onPressed: () => _entry == null ? _open() : _close(),
      ),
    );
  }
}

class _IndicatorsDialog extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final LayerLink link;
  const _IndicatorsDialog({required this.onClose, required this.link});

  @override
  ConsumerState<_IndicatorsDialog> createState() => _IndicatorsDialogState();
}

class _IndicatorsDialogState extends ConsumerState<_IndicatorsDialog> {
  String _search = '';
  _IndicatorCategory _category = _IndicatorCategory.all;
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  static const _catalog = <_IndicatorCatalogEntry>[
    _IndicatorCatalogEntry('sma',      'SMA',    'Simple Moving Average',           _IndicatorCategory.trend),
    _IndicatorCatalogEntry('ema',      'EMA',    'Exponential Moving Average',      _IndicatorCategory.trend),
    _IndicatorCatalogEntry('bb',       'BB',     'Bollinger Bands',                 _IndicatorCategory.trend),
    _IndicatorCatalogEntry('vwap',     'VWAP',   'Volume Weighted Average Price',   _IndicatorCategory.trend),
    _IndicatorCatalogEntry('zlema',    'ZLEMA',  'Zero-Lag Exponential MA',         _IndicatorCategory.trend),
    _IndicatorCatalogEntry('mcginley', 'MGD',    'McGinley Dynamic',                _IndicatorCategory.trend),
    _IndicatorCatalogEntry('ribbon',   'RIBBON', 'EMA Ribbon (8 lines)',            _IndicatorCategory.trend),
    _IndicatorCatalogEntry('ichi',     'ICHI',   'Ichimoku Cloud',                  _IndicatorCategory.trend),
    _IndicatorCatalogEntry('vstop',    'VSTOP',  'Volatility Stop (ATR trailing)',  _IndicatorCategory.trend),
    _IndicatorCatalogEntry('rsi',      'RSI',    'Relative Strength Index',         _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('macd',     'MACD',   'Moving Average Convergence',      _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('stoch',    'STOCH',  'Stochastic Oscillator',           _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('stochrsi', 'SRSI',   'Stochastic RSI',                  _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('squeeze',  'SQZ',    'Squeeze Momentum',                _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('efi',      'EFI',    "Elder's Force Index",             _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('wt',       'WT',     'WaveTrend Oscillator',            _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('crsi',     'CRSI',   'Connors RSI',                     _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('ao',       'AO',     'Awesome Oscillator',              _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('mfi',      'MFI',    'Money Flow Index',                _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('obv',      'OBV',    'On-Balance Volume',               _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('cmf',      'CMF',    'Chaikin Money Flow',              _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('wr',       'WR',     "Williams %R",                     _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('atr',      'ATR',    'Average True Range',              _IndicatorCategory.volatility),
    _IndicatorCatalogEntry('cisd',     'CISD',   'Change in State of Delivery',     _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('fvg',      'FVG',    'Fair Value Gap (ICT)',            _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('ob',       'OB',     'Order Block (ICT/SMC)',           _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('liqsweep', 'LIQ',    'Liquidity Sweep (ICT)',           _IndicatorCategory.momentum),
    _IndicatorCatalogEntry('mss',      'MSS',    'Market Structure (BOS/CHoCH/MSS)', _IndicatorCategory.momentum),
  ];

  String _defaultColor(String kind) {
    switch (kind) {
      case 'sma':      return '#3B82F6';
      case 'ema':      return '#F59E0B';
      case 'rsi':      return '#8B5CF6';
      case 'bb':       return '#8B5CF6';
      case 'vwap':     return '#06B6D4';
      case 'macd':     return '#3B82F6';
      case 'stoch':    return '#8B5CF6';
      case 'atr':      return '#10B981';
      case 'zlema':    return '#EC4899';
      case 'mcginley': return '#0EA5E9';
      case 'stochrsi': return '#A855F7';
      case 'squeeze':  return '#22D3EE';
      case 'efi':      return '#84CC16';
      case 'ribbon':   return '#3B82F6';
      case 'ichi':     return '#10B981';
      case 'vstop':    return '#22C55E';
      case 'wt':       return '#3B82F6';
      case 'crsi':     return '#8B5CF6';
      case 'ao':       return '#22C55E';
      case 'mfi':      return '#06B6D4';
      case 'obv':      return '#84CC16';
      case 'cmf':      return '#A855F7';
      case 'wr':       return '#F59E0B';
    }
    return '#3B82F6';
  }

  int _defaultPeriod(String kind) {
    switch (kind) {
      case 'rsi':      return 14;
      case 'macd':     return 12;
      case 'stoch':    return 14;
      case 'atr':      return 14;
      case 'bb':       return 20;
      case 'vwap':     return 0;
      case 'zlema':    return 20;
      case 'mcginley': return 14;
      case 'stochrsi': return 14;
      case 'squeeze':  return 20;
      case 'efi':      return 13;
      case 'ribbon':   return 0;
      case 'ichi':     return 26;
      case 'vstop':    return 14;
      case 'wt':       return 10;
      case 'crsi':     return 3;
      case 'ao':       return 0;
      case 'mfi':      return 14;
      case 'obv':      return 0;
      case 'cmf':      return 20;
      case 'wr':       return 14;
      default:         return 20;
    }
  }

  String _newId() =>
      'i-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  void _add(int paneIndex, String kind) {
    ref.read(chartEngineSessionProvider.notifier).addIndicator(
          paneIndex,
          IndicatorConfig(
            id: _newId(),
            kind: kind,
            period: _defaultPeriod(kind),
            color: _defaultColor(kind),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(chartEngineSessionProvider);
    final activeIdx = session.activePaneIndex;
    final active = (activeIdx >= 0 && activeIdx < session.panes.length)
        ? session.panes[activeIdx].indicators
        : const <IndicatorConfig>[];
    final mute = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final q = _search.toLowerCase().trim();
    final filtered = _catalog.where((c) {
      if (_category != _IndicatorCategory.all && c.category != _category) {
        return false;
      }
      if (q.isEmpty) return true;
      return c.label.toLowerCase().contains(q) ||
          c.kind.toLowerCase().contains(q) ||
          c.fullName.toLowerCase().contains(q);
    }).toList();

    return Stack(children: [
      Positioned.fill(
        child: PointerInterceptor(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
          ),
        ),
      ),
      Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          offset: const Offset(-340, 38),
          child: PointerInterceptor(
            child: RefinedPopoverCard(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RefinedPopoverHeader(
                    title: 'Indicators',
                    subtitle:
                        'Add overlays and oscillators to the active pane',
                    onClose: widget.onClose,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: RefinedSearchField(
                      controller: _searchCtl,
                      onChanged: (v) => setState(() => _search = v),
                      hintText: 'Search indicators…',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        children: [
                          for (final cat in _IndicatorCategory.values) ...[
                            _CategoryChip(
                              label: cat.label,
                              selected: cat == _category,
                              onTap: () => setState(() => _category = cat),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (active.isNotEmpty) ...[
                    const RefinedDivider(),
                    const RefinedSectionLabel(label: 'Active'),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final ind in active)
                              _ActiveIndicatorRow(
                                paneIndex: activeIdx,
                                config: ind,
                              ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const RefinedDivider(),
                  RefinedSectionLabel(
                      label:
                          filtered.isEmpty ? 'No matches' : 'All indicators'),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (filtered.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 8, 20, 20),
                              child: Text(
                                  'Try a different search or category.',
                                  style: MyntWebTextStyles.caption(context,
                                      color: mute)),
                            )
                          else
                            for (final c in filtered)
                              _CatalogIndicatorRow(
                                entry: c,
                                onAdd: () => _add(activeIdx, c.kind),
                              ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _CategoryChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final mute = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final idleBg = isDark ? const Color(0xFF1A2030) : const Color(0xFFF8FAFC);
    final idleBorder =
        isDark ? const Color(0xFF2A3142) : const Color(0xFFE2E8F0);
    final bg = widget.selected ? accent : (_hover ? accent.withValues(alpha: 0.10) : idleBg);
    final fg = widget.selected ? Colors.white : (_hover ? accent : mute);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(
                color: widget.selected ? accent : idleBorder, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveIndicatorRow extends ConsumerStatefulWidget {
  final int paneIndex;
  final IndicatorConfig config;
  const _ActiveIndicatorRow({
    required this.paneIndex,
    required this.config,
  });

  @override
  ConsumerState<_ActiveIndicatorRow> createState() =>
      _ActiveIndicatorRowState();
}

class _ActiveIndicatorRowState extends ConsumerState<_ActiveIndicatorRow> {
  bool _hover = false;

  Color _hex(String hex) => Color(int.parse(hex.replaceAll('#', '0xff')));

  @override
  Widget build(BuildContext context) {
    final mute = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final lossColor = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color: _hover ? hoverBg.withValues(alpha: 0.5) : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
        child: Row(children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _hex(widget.config.color),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(widget.config.kind.toUpperCase(),
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.semiBold)),
                if (widget.config.period > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: mute.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${widget.config.period}',
                        style: TextStyle(
                          color: mute,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        )),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: Icon(Icons.delete_outline, size: 16, color: lossColor),
            onPressed: () => ref
                .read(chartEngineSessionProvider.notifier)
                .removeIndicator(widget.paneIndex, widget.config.id),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }
}

class _CatalogIndicatorRow extends StatefulWidget {
  final _IndicatorCatalogEntry entry;
  final VoidCallback onAdd;
  const _CatalogIndicatorRow({required this.entry, required this.onAdd});

  @override
  State<_CatalogIndicatorRow> createState() => _CatalogIndicatorRowState();
}

class _CatalogIndicatorRowState extends State<_CatalogIndicatorRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final mute = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onAdd,
        child: Container(
          color: _hover ? hoverBg.withValues(alpha: 0.5) : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
          child: Row(children: [
            SizedBox(
              width: 60,
              child: Text(widget.entry.label,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.semiBold)),
            ),
            Expanded(
              child: Text(
                widget.entry.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MyntWebTextStyles.caption(context, color: mute),
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _hover
                    ? accent
                    : accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.add,
                  size: 16, color: _hover ? Colors.white : accent),
            ),
          ]),
        ),
      ),
    );
  }
}
