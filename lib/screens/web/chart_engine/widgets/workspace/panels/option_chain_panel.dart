// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/marketwatch_model/linked_scrips.dart';
import 'package:mynt_plus/models/marketwatch_model/opt_chain_model.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';

import 'watchlist_panel.dart';

/// Right-tray option chain panel. Defaults the underlying to the active
/// pane's scrip. Flow:
///   1) getLinkedScrip(token, exch) on the effective scrip
///   2) if `optExp` is non-empty → fetch getOptionChain for the selected
///      expiry, subscribe each strike token to WS touchline
///   3) else → "No option chain"
///
/// The header's "change" button slides the existing WatchlistPanel into the
/// body so the user can pick any scrip from the watchlist as the override.
class OptionChainPanel extends ConsumerStatefulWidget {
  final ValueChanged<ChartScrip> onSymbolPick;
  const OptionChainPanel({super.key, required this.onSymbolPick});

  @override
  ConsumerState<OptionChainPanel> createState() => _OptionChainPanelState();
}

class _OptionChainPanelState extends ConsumerState<OptionChainPanel> {
  // Cached while mounted — ref.read throws in dispose (Riverpod 3).
  WebSocketProvider? _ws;
  late final String _owner = 'chart-oc-panel:${identityHashCode(this)}';

  @override
  void dispose() {
    try { _ws?.releaseAllTouchline(_owner); } catch (_) {}
    super.dispose();
  }

  ChartScrip? _override;        // user-picked underlying (overrides active pane)
  String? _fetchedScripKey;     // 'exch|token' of the scrip getLinkedScrip ran on
  bool _loadingLinked = false;
  List<OptionExp> _expiries = const [];
  OptionExp? _selectedExpiry;
  String? _fetchedStrikesKey;   // 'underlying|expiry.tsym'
  bool _loadingStrikes = false;
  List<OptionValues> _strikes = const [];
  bool _pickerOpen = false;

  ChartScrip? _effectiveScrip(ChartScrip? activeScrip) {
    return _override ?? activeScrip;
  }

  Future<void> _ensureLinked(ChartScrip scrip) async {
    final key = '${scrip.exch}|${scrip.token}';
    if (_fetchedScripKey == key) return;
    if (_loadingLinked) return;
    setState(() {
      _loadingLinked = true;
      _fetchedScripKey = key;
      _expiries = const [];
      _selectedExpiry = null;
      _strikes = const [];
      _fetchedStrikesKey = null;
    });
    try {
      final linked = await locator<ApiExporter>()
          .getLinkedScrip(scrip.token, scrip.exch);
      if (!mounted || _fetchedScripKey != key) return;
      final list = (linked.optExp ?? const <OptionExp>[])
          .where((e) => (e.tsym ?? '').isNotEmpty && (e.exch ?? '').isNotEmpty)
          .toList()
        ..sort((a, b) => _parseExpiryDate(a.exd ?? '')
            .compareTo(_parseExpiryDate(b.exd ?? '')));
      setState(() {
        _expiries = list;
        _selectedExpiry = list.isNotEmpty ? list.first : null;
      });
      if (_selectedExpiry != null) {
        await _ensureStrikes(scrip, _selectedExpiry!);
      }
    } catch (_) {
      // Silent — user can pick another underlying.
    } finally {
      if (mounted) setState(() => _loadingLinked = false);
    }
  }

  Future<void> _ensureStrikes(ChartScrip underlying, OptionExp expiry) async {
    final key = '${underlying.exch}|${underlying.token}|${expiry.tsym}';
    if (_fetchedStrikesKey == key && _strikes.isNotEmpty) return;
    if (_loadingStrikes) return;
    setState(() {
      _loadingStrikes = true;
      _strikes = const [];
      _fetchedStrikesKey = key;
    });
    try {
      // Anchor the chain around the underlying's live LTP (if available).
      // Broker accepts strPrc='0' and returns its own default slice.
      final spotData = ref.read(websocketProvider).socketDatas[underlying.token]
          as Map<dynamic, dynamic>?;
      final spotLp = double.tryParse('${spotData?['lp'] ?? '0'}') ?? 0;
      final strPrc = spotLp > 0 ? spotLp.toStringAsFixed(0) : '0';
      final res = await locator<ApiExporter>().getOptionChain(
        strPrc: strPrc,
        tradeSym: expiry.tsym ?? '',
        exchange: expiry.exch ?? '',
        context: context,
        numofStrike: '25',
      );
      if (!mounted || _fetchedStrikesKey != key) return;
      if (res == null || res.stat != 'Ok' || res.optValue == null) {
        setState(() => _strikes = const []);
        return;
      }
      // Subscribe each strike to the WS touchline feed so LTP/OI stay live.
      // Owned by this panel: replaced on an underlying / expiry change,
      // restored after a reconnect, released when the panel closes (raw "t"
      // subscriptions here were never released or restored).
      _ws = ref.read(websocketProvider);
      _ws!.setOwnedTouchline(_owner, [
        for (final v in res.optValue!)
          if ((v.token ?? '').isNotEmpty && (v.exch ?? '').isNotEmpty)
            '${v.exch}|${v.token}'
      ], context);
      setState(() => _strikes = res.optValue!);
    } catch (_) {
      // Silent — row will display snapshot data only.
    } finally {
      if (mounted) setState(() => _loadingStrikes = false);
    }
  }

  static DateTime _parseExpiryDate(String s) {
    try {
      final parts = s.split('-');
      if (parts.length != 3) return DateTime(2100);
      const months = {
        'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
        'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
      };
      final day = int.tryParse(parts[0]) ?? 1;
      final mon = months[parts[1].toUpperCase()] ?? 1;
      final yr = int.tryParse(parts[2]) ?? 2100;
      return DateTime(yr, mon, day);
    } catch (_) {
      return DateTime(2100);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(chartEngineSessionProvider);
    final ws = ref.watch(websocketProvider);
    final activeScrip = session.active.scrip;
    final scrip = _effectiveScrip(activeScrip);

    // Picker mode — embed the existing WatchlistPanel and capture its
    // selection as the override (instead of changing the active pane).
    if (_pickerOpen) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Header(
          title: 'Pick underlying',
          subtitle: '',
          onChange: _togglePicker,
          isPickerOpen: true,
        ),
        Container(height: 1, color: Theme.of(context).dividerColor),
        Expanded(
          child: WatchlistPanel(
            onSymbolPick: (s) {
              setState(() {
                _override = s;
                _pickerOpen = false;
              });
            },
          ),
        ),
      ]);
    }

    if (scrip == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Header(
          title: 'Option chain',
          subtitle: '',
          onChange: _togglePicker,
          isPickerOpen: false,
        ),
        Container(height: 1, color: Theme.of(context).dividerColor),
        const Expanded(child: _EmptyPanel(message: 'Open a chart first')),
      ]);
    }

    final scripKey = '${scrip.exch}|${scrip.token}';
    if (_fetchedScripKey != scripKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureLinked(scrip);
      });
    }

    final border = Theme.of(context).dividerColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: 'Option chain',
          subtitle: scrip.dispName.isNotEmpty ? scrip.dispName : scrip.tsym,
          onChange: _togglePicker,
          isPickerOpen: false,
          showResetOverride: _override != null,
          onResetOverride: () => setState(() => _override = null),
        ),
        Container(height: 1, color: border),
        if (_loadingLinked)
          const SizedBox(
            height: 40,
            child: Center(
              child: SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5))),
          )
        else if (_expiries.isEmpty && _fetchedScripKey == scripKey)
          Expanded(
            child: _EmptyPanel(
              message:
                  'No option chain for ${scrip.dispName.isNotEmpty ? scrip.dispName : scrip.tsym}.\n'
                  'Tap the search icon to pick another symbol.',
            ),
          )
        else if (_expiries.isNotEmpty) ...[
          _ExpiryStrip(
            expiries: _expiries,
            selected: _selectedExpiry,
            onPick: (e) {
              setState(() => _selectedExpiry = e);
              _ensureStrikes(scrip, e);
            },
          ),
          Container(height: 1, color: border),
          _StrikeHeader(),
          Container(height: 1, color: border),
          Expanded(
            child: _loadingStrikes && _strikes.isEmpty
                ? const Center(
                    child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : _strikes.isEmpty
                    ? const _EmptyPanel(message: 'No strikes for this expiry')
                    : _StrikeList(
                        strikes: _strikes,
                        socketDatas: ws.socketDatas,
                        onChartPick: (v) => widget.onSymbolPick(
                          ChartScrip(
                            exch: v.exch ?? '',
                            token: v.token ?? '',
                            tsym: v.tsym ?? '',
                            dispName: v.tsym ?? '',
                            ls: int.tryParse(v.ls ?? '') ?? 1,
                            ti: double.tryParse(v.ti ?? '') ?? 0.05,
                            // OptionValues from getOptionChain doesn't carry
                            // `instname`, but every row IS an option (CE/PE).
                            // Tag it 'OPT' so setPaneSymbol's qty rule
                            // (`instname.startsWith('OPT')` → optionsDefaultQty
                            // × ls) applies instead of the equity fallback
                            // that left qty at 1.
                            instname: 'OPT',
                          ),
                        ),
                      ),
          ),
        ] else
          const Expanded(child: SizedBox.shrink()),
      ],
    );
  }

  void _togglePicker() => setState(() => _pickerOpen = !_pickerOpen);
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onChange;
  final bool isPickerOpen;
  final bool showResetOverride;
  final VoidCallback? onResetOverride;
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onChange,
    required this.isPickerOpen,
    this.showResetOverride = false,
    this.onResetOverride,
  });

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Text(title,
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.semiBold)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              subtitle.isEmpty ? '' : '· $subtitle',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.caption(context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary),
            ),
          ),
          const Spacer(),
          if (showResetOverride && onResetOverride != null)
            Tooltip(
              message: 'Follow active pane',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onResetOverride,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                    child: Icon(Icons.link_off, size: 14, color: muted),
                  ),
                ),
              ),
            ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onChange,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Icon(
                  isPickerOpen ? Icons.close : Icons.search,
                  size: 16,
                  color: isPickerOpen ? accent : muted,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ExpiryStrip extends StatelessWidget {
  final List<OptionExp> expiries;
  final OptionExp? selected;
  final ValueChanged<OptionExp> onPick;
  const _ExpiryStrip({
    required this.expiries,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in expiries)
              _ExpiryChip(
                label: e.exd ?? '',
                selected: identical(e, selected) ||
                    (selected != null && e.tsym == selected!.tsym),
                onTap: () => onPick(e),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ExpiryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  State<_ExpiryChip> createState() => _ExpiryChipState();
}

class _ExpiryChipState extends State<_ExpiryChip> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary);
    final hover = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final color = widget.selected ? accent : muted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: _h && !widget.selected ? hover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Text(widget.label,
                  style: MyntWebTextStyles.bodySmall(context,
                      fontWeight: widget.selected
                          ? MyntFonts.semiBold
                          : MyntFonts.medium,
                      darkColor: color,
                      lightColor: color)),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 2,
                width: widget.selected ? 28 : 0,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrikeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary);
    Widget cell(String label, TextAlign a) => Expanded(
          child: Text(label,
              textAlign: a,
              style: MyntWebTextStyles.caption(context,
                  darkColor: c, lightColor: c)),
        );
    return SizedBox(
      height: 26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          cell('LTP', TextAlign.left),
          cell('OI',  TextAlign.right),
          const SizedBox(width: 28),
          SizedBox(
            width: 54,
            child: Text('STR',
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.caption(context,
                    darkColor: c, lightColor: c)),
          ),
          const SizedBox(width: 28),
          cell('OI',  TextAlign.left),
          cell('LTP', TextAlign.right),
        ]),
      ),
    );
  }
}

class _StrikeList extends StatelessWidget {
  final List<OptionValues> strikes;
  final Map<dynamic, dynamic> socketDatas;
  final ValueChanged<OptionValues> onChartPick;
  const _StrikeList({
    required this.strikes,
    required this.socketDatas,
    required this.onChartPick,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <double, List<OptionValues?>>{};
    for (final v in strikes) {
      final s = double.tryParse(v.strprc ?? '');
      if (s == null || s <= 0) continue;
      final pair = grouped.putIfAbsent(s, () => [null, null]);
      if (v.optt == 'CE') {
        pair[0] = v;
      } else if (v.optt == 'PE') {
        pair[1] = v;
      }
    }
    final sortedKeys = grouped.keys.toList()..sort();

    final border = Theme.of(context).dividerColor;
    return ListView.separated(
      itemCount: sortedKeys.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: border, thickness: 0.5),
      itemBuilder: (ctx, i) {
        final key = sortedKeys[i];
        final pair = grouped[key]!;
        return _StrikeRow(
          strike: key,
          ce: pair[0],
          pe: pair[1],
          socketDatas: socketDatas,
          onChartPick: onChartPick,
        );
      },
    );
  }
}

class _StrikeRow extends StatefulWidget {
  final double strike;
  final OptionValues? ce;
  final OptionValues? pe;
  final Map<dynamic, dynamic> socketDatas;
  final ValueChanged<OptionValues> onChartPick;
  const _StrikeRow({
    required this.strike,
    required this.ce,
    required this.pe,
    required this.socketDatas,
    required this.onChartPick,
  });
  @override
  State<_StrikeRow> createState() => _StrikeRowState();
}

class _StrikeRowState extends State<_StrikeRow> {
  bool _h = false;

  String _liveLtp(OptionValues? v) {
    if (v == null) return '—';
    final s = widget.socketDatas[v.token] as Map<dynamic, dynamic>?;
    final lp = s?['lp'] ?? v.lp ?? '';
    return _fmtPrice(lp);
  }

  String _liveOi(OptionValues? v) {
    if (v == null) return '—';
    final s = widget.socketDatas[v.token] as Map<dynamic, dynamic>?;
    final oi = s?['oi'] ?? v.oi ?? '';
    return _fmtOi(oi);
  }

  static String _fmtPrice(dynamic v) {
    final s = v?.toString() ?? '';
    if (s.isEmpty || s == 'null' || s == '0') return '—';
    final n = double.tryParse(s);
    if (n == null) return s;
    return n.toStringAsFixed(2);
  }

  static String _fmtOi(dynamic v) {
    final s = v?.toString() ?? '';
    if (s.isEmpty || s == 'null' || s == '0') return '—';
    final n = double.tryParse(s);
    if (n == null) return s;
    if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)}Cr';
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  static String _fmtStrike(double s) {
    if (s == s.truncateToDouble()) return s.toStringAsFixed(0);
    return s.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary);
    final long = resolveThemeColor(context,
        dark: const Color(0xFF3B82F6), light: const Color(0xFF2563EB));
    final short = resolveThemeColor(context,
        dark: const Color(0xFFEF4444), light: const Color(0xFFDC2626));

    final ceLtp = _liveLtp(widget.ce);
    final ceOi = _liveOi(widget.ce);
    final peLtp = _liveLtp(widget.pe);
    final peOi = _liveOi(widget.pe);

    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: Container(
        height: 38,
        color: _h ? hoverBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          Expanded(
            child: Text(ceLtp,
                textAlign: TextAlign.left,
                style: MyntWebTextStyles.bodySmall(context,
                    fontWeight: MyntFonts.semiBold,
                    darkColor: textPrimary, lightColor: textPrimary)),
          ),
          Expanded(
            child: Text(ceOi,
                textAlign: TextAlign.right,
                style: MyntWebTextStyles.caption(context,
                    darkColor: muted, lightColor: muted)),
          ),
          _ChartIconButton(
            color: long,
            enabled: widget.ce != null,
            tooltip: widget.ce == null
                ? 'No CE'
                : 'Open ${widget.ce!.tsym} in chart',
            onTap: widget.ce == null
                ? null
                : () => widget.onChartPick(widget.ce!),
          ),
          SizedBox(
            width: 54,
            child: Text(_fmtStrike(widget.strike),
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold,
                    darkColor: textPrimary, lightColor: textPrimary)),
          ),
          _ChartIconButton(
            color: short,
            enabled: widget.pe != null,
            tooltip: widget.pe == null
                ? 'No PE'
                : 'Open ${widget.pe!.tsym} in chart',
            onTap: widget.pe == null
                ? null
                : () => widget.onChartPick(widget.pe!),
          ),
          Expanded(
            child: Text(peOi,
                textAlign: TextAlign.left,
                style: MyntWebTextStyles.caption(context,
                    darkColor: muted, lightColor: muted)),
          ),
          Expanded(
            child: Text(peLtp,
                textAlign: TextAlign.right,
                style: MyntWebTextStyles.bodySmall(context,
                    fontWeight: MyntFonts.semiBold,
                    darkColor: textPrimary, lightColor: textPrimary)),
          ),
        ]),
      ),
    );
  }
}

class _ChartIconButton extends StatelessWidget {
  final Color color;
  final bool enabled;
  final String tooltip;
  final VoidCallback? onTap;
  const _ChartIconButton({
    required this.color,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 28,
        child: MouseRegion(
          cursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Center(
              child: Icon(
                Icons.candlestick_chart,
                size: 16,
                color: enabled ? color : color.withValues(alpha: 0.25),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String message;
  const _EmptyPanel({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.caption(context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary),
        ),
      ),
    );
  }
}
