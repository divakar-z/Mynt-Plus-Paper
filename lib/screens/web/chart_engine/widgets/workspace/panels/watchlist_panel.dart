// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/marketwatch_model/market_watch_scrip_model.dart';
import 'package:mynt_plus/provider/market_watch_provider.dart';
import 'package:mynt_plus/provider/portfolio_provider.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

import '../../../state/chart_engine_store.dart';

const Set<String> _kPredefined = {
  'My Stocks',
  'My Positions',
  'Nifty50',
  'Niftybank',
  'Sensex',
};

const List<String> _kFallbackNames = <String>[
  'My Stocks',
  'Nifty50',
  'Niftybank',
  'Sensex',
];

class WatchlistPanel extends ConsumerStatefulWidget {
  final ValueChanged<ChartScrip> onSymbolPick;
  const WatchlistPanel({super.key, required this.onSymbolPick});

  @override
  ConsumerState<WatchlistPanel> createState() => _WatchlistPanelState();
}

class _WatchlistPanelState extends ConsumerState<WatchlistPanel> {
  bool _bootstrapRunning = false;
  bool _bootstrapDone = false;
  bool _switching = false;

  Future<void> _bootstrap() async {
    if (_bootstrapDone || _bootstrapRunning) return;
    _bootstrapRunning = true;
    try {
      final mw = ref.read(marketWatchProvider);
      try {
        await mw.fetchPreDefMWScrip(context);
      } catch (_) {}
      if (!mounted) return;
      if (mw.marketWatchlist == null ||
          (mw.marketWatchlist?.values?.isEmpty ?? true)) {
        try {
          await mw.fetchMWList(context, false);
        } catch (_) {}
      }
      if (!mounted) return;
      final names = _availableNames();
      if (names.isEmpty) {
        _bootstrapDone = true;
        return;
      }
      final target = names.contains(mw.wlName) && mw.wlName.isNotEmpty
          ? mw.wlName
          : names.first;
      await _switchTo(target, force: true);
      _bootstrapDone = true;
    } finally {
      _bootstrapRunning = false;
    }
  }

  Future<void> _switchTo(String name, {bool force = false}) async {
    if (_switching) return;
    final mw = ref.read(marketWatchProvider);
    if (!force && mw.wlName == name) return;
    _switching = true;
    try {
      try {
        await mw.requestMWScrip(context: context, isSubscribe: false);
      } catch (_) {}
      final isPre = _kPredefined.contains(name) ? 'Yes' : 'No';
      try {
        mw.changeWlName(name, isPre);
      } catch (_) {}
      try {
        await mw.changeWLScrip(name, context);
      } catch (_) {}
      // `changeWLScrip` already issues its own subscribe for non-portfolio
      // watchlists, so no explicit re-subscribe is needed here.
    } finally {
      _switching = false;
      if (mounted) setState(() {});
    }
  }

  List<String> _availableNames() {
    final mw = ref.read(marketWatchProvider);
    final fromProvider =
        (mw.marketWatchlist?.values ?? const <dynamic>[]).cast<String>();
    if (fromProvider.isNotEmpty) return fromProvider;
    final portfolio = ref.read(portfolioProvider);
    final hasPositions = (portfolio.postionBookModel ?? const []).isNotEmpty &&
        portfolio.postionBookModel![0].stat != 'Not_Ok';
    return <String>[
      if (hasPositions) 'My Positions',
      ..._kFallbackNames,
    ];
  }

  List<WatchListValues> _currentScrips(MarketWatchProvider mw) {
    final wlName = mw.wlName;
    if (wlName.isEmpty) return const <WatchListValues>[];

    // For My Stocks / My Positions the provider stores no rows in `_scrips`;
    // surface holdings/positions as scrip rows so the tab is not visually empty.
    if (wlName == 'My Stocks') {
      final hs = ref.read(portfolioProvider).holdingsModel ?? const [];
      return hs
          .where((h) => h.stat != 'Not_Ok' && (h.exchTsym?.isNotEmpty ?? false))
          .map((h) {
        final ex = h.exchTsym![0];
        return WatchListValues(
          token: ex.token,
          tsym: ex.tsym,
          exch: ex.exch,
          ltp: ex.lp,
          change: ex.change,
          perChange: ex.perChange,
          ls: ex.ls,
          ti: ex.ti,
          dname: ex.tsym ?? ex.symbol,
          symbol: ex.symbol,
          instname: 'EQ',
        );
      }).toList();
    }
    if (wlName == 'My Positions') {
      final pos = ref.read(portfolioProvider).postionBookModel ?? const [];
      return pos
          .where((p) =>
              p.stat != 'Not_Ok' &&
              (p.tsym ?? '').isNotEmpty &&
              (int.tryParse(p.netqty ?? '0') ?? 0) != 0)
          .map((p) => WatchListValues(
                token: p.token,
                tsym: p.tsym,
                exch: p.exch,
                ltp: p.lp,
                change: p.chng,
                perChange: p.perChange,
                ls: p.ls,
                ti: p.ti,
                dname: p.dname ?? p.tsym,
                symbol: p.symbol,
                instname: '',
              ))
          .toList();
    }

    // Standard path — read the active scrips list. Fall back to the cache
    // (keyed by wl name) when `_scrips` hasn't been hydrated for this name yet.
    final rawList = mw.scrips;
    if (rawList.isNotEmpty) {
      return rawList
          .map((e) => WatchListValues.fromJson(
              (e as Map).cast<String, dynamic>()))
          .toList();
    }
    final cached = mw.marketWatchScripData[wlName];
    if (cached is String && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached) as List;
        return decoded
            .map((e) => WatchListValues.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList();
      } catch (_) {}
    }
    return const <WatchListValues>[];
  }

  @override
  Widget build(BuildContext context) {
    final mw = ref.watch(marketWatchProvider);
    final wlName = mw.wlName;
    final names = _availableNames();
    final scrips = _currentScrips(mw);

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());

    final border = Theme.of(context).dividerColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(currentName: wlName),
        Container(height: 1, color: border),
        _TabStrip(
          names: names,
          activeName: wlName,
          onTap: _switchTo,
        ),
        Container(height: 1, color: border),
        if (_switching || (_bootstrapRunning && scrips.isEmpty))
          const _LoadingPanel()
        else if (names.isEmpty)
          const _EmptyPanel(message: 'No watchlists yet')
        else if (scrips.isEmpty)
          _EmptyPanel(
            message: wlName.isEmpty
                ? 'Pick a watchlist'
                : 'No scrips in "$wlName"',
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: scrips.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: border, thickness: 0.5),
              itemBuilder: (ctx, i) => _ScripTile(
                value: scrips[i],
                onTap: widget.onSymbolPick,
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String currentName;
  const _Header({required this.currentName});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Text(
              'Watchlist',
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.semiBold,
              ),
            ),
            if (currentName.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '· $currentName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.caption(
                    context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  final List<String> names;
  final String activeName;
  final ValueChanged<String> onTap;
  const _TabStrip({
    required this.names,
    required this.activeName,
    required this.onTap,
  });

  static String _formatLabel(String v) {
    switch (v) {
      case 'My Stocks':
        return 'Holdings';
      case 'My Positions':
        return 'Positions';
      case 'Nifty50':
        return 'Nifty 50';
      case 'Niftybank':
        return 'Nifty Bank';
      default:
        return v;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = resolveThemeColor(
      context,
      dark: MyntColors.primaryDark,
      light: MyntColors.primary,
    );
    final muted = resolveThemeColor(
      context,
      dark: MyntColors.textSecondaryDark,
      light: MyntColors.textSecondary,
    );

    if (names.isEmpty) {
      return const SizedBox(height: 40);
    }

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final name in names)
              _TabChip(
                label: _formatLabel(name),
                selected: name == activeName,
                accent: accent,
                muted: muted,
                onTap: () => onTap(name),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color muted;
  final VoidCallback onTap;
  const _TabChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.muted,
    required this.onTap,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = resolveThemeColor(
      context,
      dark: MyntColors.cardHoverDark,
      light: MyntColors.cardHover,
    );
    final color = widget.selected ? widget.accent : widget.muted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: _hover && !widget.selected ? hoverBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  fontWeight: widget.selected
                      ? MyntFonts.semiBold
                      : MyntFonts.medium,
                  darkColor: color,
                  lightColor: color,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 2,
                width: widget.selected ? 28 : 0,
                decoration: BoxDecoration(
                  color: widget.accent,
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

class _EmptyPanel extends StatelessWidget {
  final String message;
  const _EmptyPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.caption(
              context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Expanded(
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ScripTile extends ConsumerStatefulWidget {
  final WatchListValues value;
  final ValueChanged<ChartScrip> onTap;
  const _ScripTile({required this.value, required this.onTap});

  @override
  ConsumerState<_ScripTile> createState() => _ScripTileState();
}

class _ScripTileState extends ConsumerState<_ScripTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final token = v.token ?? '';
    final exch = v.exch ?? '';
    final dispName = v.dname ?? v.tsym ?? v.symbol ?? '';
    final instname = v.instname ?? '';

    final socket = ref.watch(websocketProvider).socketDatas[token]
        as Map<dynamic, dynamic>?;
    // WS push uses `lp`/`chng`/`pc` (lowercase) — the model's API snapshot
    // uses `ltp`/`change`/`perChange`. Falling back to the snapshot when WS
    // hasn't pushed yet for this token.
    final ltp = _str(socket?['lp'] ?? v.ltp ?? '0');
    final change = _str(socket?['chng'] ?? v.change ?? '0');
    final perChange = _str(socket?['pc'] ?? v.perChange ?? '0');

    final chNum = double.tryParse(change) ?? 0.0;
    final isUp = chNum >= 0;
    final pnlColor = isUp ? MyntColors.profit : MyntColors.loss;

    final hoverBg = resolveThemeColor(
      context,
      dark: MyntColors.cardHoverDark,
      light: MyntColors.cardHover,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap(
          ChartScrip(
            exch: v.exch ?? 'NSE',
            token: v.token ?? '',
            tsym: v.tsym ?? '',
            dispName: dispName,
            ls: int.tryParse(v.ls ?? '') ?? 1,
            ti: double.tryParse(v.ti ?? '') ?? 0.05,
            instname: v.instname ?? '',
          ),
        ),
        child: Container(
          height: 56,
          color: _hover ? hoverBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (exch.isNotEmpty) ...[
                          _ExchChip(exch),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            dispName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MyntWebTextStyles.body(
                              context,
                              fontWeight: MyntFonts.semiBold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (instname.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        instname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MyntWebTextStyles.caption(
                          context,
                          darkColor: MyntColors.textSecondaryDark,
                          lightColor: MyntColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmt(ltp),
                    style: MyntWebTextStyles.body(
                      context,
                      fontWeight: MyntFonts.semiBold,
                      darkColor: pnlColor,
                      lightColor: pnlColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${isUp ? '+' : ''}${_fmt(perChange)}%',
                    style: MyntWebTextStyles.caption(
                      context,
                      darkColor: pnlColor,
                      lightColor: pnlColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _str(dynamic v) => v == null ? '' : v.toString();

  static String _fmt(String v) {
    if (v.isEmpty || v == 'null') return '0.00';
    final n = double.tryParse(v);
    return n == null ? v : n.toStringAsFixed(2);
  }
}

class _ExchChip extends StatelessWidget {
  final String exch;
  const _ExchChip(this.exch);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: MyntColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        exch,
        style: MyntWebTextStyles.caption(
          context,
          fontWeight: MyntFonts.semiBold,
        ),
      ),
    );
  }
}
