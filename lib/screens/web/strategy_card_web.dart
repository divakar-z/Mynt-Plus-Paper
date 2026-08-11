import 'dart:math' as math; // used by the risk gauge painters

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/rupeecase_model/algo_strategy_model.dart';
import '../../models/rupeecase_model/rupeecase_strategy_model.dart';
import '../../provider/fund_provider.dart';
import '../../res/mynt_web_color_styles.dart';
import '../../res/mynt_web_text_styles.dart';
import '../../res/res.dart';
import '../../utils/rupee_convert_format.dart';

/// Which risk dial the card draws beside its header label.
enum StrategyRiskGauge {
  /// Five-segment rainbow arc (58 × 25) with the benchmark caption beneath —
  /// used by the curated RupeeCase cards.
  rainbow,

  /// Compact single-hue speedometer (42 × 20) — used by the algo cards.
  dial,
}

/// How the footer metrics are arranged inside the card's stat panel.
enum StrategyMetricsLayout {
  /// Two per row (MIN.CAP | CAGR over ALPHA | NET RETURNS).
  grid,

  /// All metrics side by side in a single row.
  row,
}

/// Colour role of a metric's value.
enum StrategyMetricTone {
  /// Plain card text — used for figures that aren't profit/loss (min. capital).
  neutral,

  /// Green/red picked from [StrategyMetric.pnlBasis]'s sign.
  pnl,

  /// Always the profit green (win rate).
  profit,

  /// Always the loss red (drawdown).
  loss,

  /// Muted — used when a figure is unavailable and renders as "—".
  muted,
}

/// One footer figure on a strategy card: a small captioned label over a
/// coloured value, with an optional hover tooltip explaining the metric.
@immutable
class StrategyMetric {
  const StrategyMetric({
    required this.label,
    required this.value,
    this.tooltip,
    this.tone = StrategyMetricTone.neutral,
    this.pnlBasis = 0,
  });

  final String label;
  final String value;
  final String? tooltip;
  final StrategyMetricTone tone;

  /// The figure behind [StrategyMetricTone.pnl] — its sign picks the colour.
  final double pnlBasis;

  Color color(BuildContext context) {
    switch (tone) {
      case StrategyMetricTone.neutral:
        return _cardPrimaryText(context);
      case StrategyMetricTone.pnl:
        return _pnlColor(context, pnlBasis);
      case StrategyMetricTone.profit:
        return resolveThemeColor(context,
            dark: const Color(0xFF56D364), light: MyntColors.profit);
      case StrategyMetricTone.loss:
        return resolveThemeColor(context,
            dark: const Color(0xFFFF8981), light: MyntColors.loss);
      case StrategyMetricTone.muted:
        return _cardMutedText(context);
    }
  }
}

/// Neutral view-model the one [StrategyCard] renders from, so curated
/// (RupeeCase) and algo strategies share a single card implementation. Adapt
/// each source type with [StrategyCardData.fromRupeeCase] /
/// [StrategyCardData.fromAlgo]; everything that differs between the two — the
/// header label, risk dial, footer metrics and tap target — is data, not a
/// second widget.
@immutable
class StrategyCardData {
  const StrategyCardData({
    required this.name,
    required this.headerLabel,
    required this.metrics,
    this.riskLevel = '',
    this.benchmark = '',
    this.gauge = StrategyRiskGauge.rainbow,
    this.metricsLayout = StrategyMetricsLayout.grid,
    this.metricLabelGap = 5,
    this.titleBesideGauge = true,
    this.compactTitle = true,
    this.titleFontSize,
    this.minHeight = kStrategyCardMinHeight,
    this.tapUrl = '',
    this.ssoVc = '',
    this.accentColor,
  });

  /// Strategy / basket name (title line).
  final String name;

  /// Single muted line above the title — "Rebalance 4W" or "Subscribed 120".
  final String headerLabel;

  /// Footer figures, rendered in [metricsLayout].
  final List<StrategyMetric> metrics;

  /// Free-text risk label; empty hides the gauge.
  final String riskLevel;

  /// Index the strategy is measured against; captions the [rainbow] gauge.
  final String benchmark;

  final StrategyRiskGauge gauge;
  final StrategyMetricsLayout metricsLayout;

  /// Gap between a metric's label and its value.
  final double metricLabelGap;

  /// When true the title sits in the header row beside the gauge; when false it
  /// spans the full card width beneath that row.
  final bool titleBesideGauge;

  /// Compact titles use the body size, break after the first two words and wrap
  /// onto three lines — the narrow-card treatment. Full titles use the larger
  /// title size on two lines.
  final bool compactTitle;

  /// Pins the title to an absolute size, opting it out of the width-based font
  /// scaling every other line on the card follows. Null keeps the scaling.
  final double? titleFontSize;

  /// Shortest the card may render. Beyond that it grows with its content, and
  /// the row's stretch alignment brings every sibling card up to match.
  final double minHeight;

  /// Plain deep-link opened on tap. Empty → the card isn't clickable unless
  /// [ssoVc] is set.
  final String tapUrl;

  final String ssoVc;
  final Color? accentColor;

  factory StrategyCardData.fromRupeeCase(RupeeCaseStrategy s,
          {Color? accentColor}) =>
      StrategyCardData(
        name: s.name,
        headerLabel: _weeksLabel(s.rebalanceWeeks),
        riskLevel: s.riskLevel,
        benchmark: s.benchmark,
        gauge: StrategyRiskGauge.rainbow,
        // The curated title has always rendered at a flat 14px, unlike the algo
        // one which follows the width-based scale.
        titleFontSize: MyntFonts.body,
        metrics: [
          StrategyMetric(
            label: 'MIN.CAP',
            tooltip: 'Minimum capital required to run this strategy.',
            value: _compactRupee(s.minInvest),
          ),
          StrategyMetric(
            label: 'CAGR',
            tooltip:
                'Compound Annual Growth Rate — the average yearly return if gains were reinvested over 5 years.',
            value: _unsignedPct(s.cagr),
            tone: StrategyMetricTone.pnl,
            pnlBasis: s.cagr,
          ),
          StrategyMetric(
            label: 'ALPHA',
            tooltip:
                'How much this strategy beat (or trailed) NIFTY 50 over the full 5-year history period.',
            value: _unsignedPct(s.alpha),
            tone: StrategyMetricTone.pnl,
            pnlBasis: s.alpha,
          ),
          StrategyMetric(
            label: 'NET RETURNS',
            tooltip:
                'Total net return after all estimated charges (brokerage, STT, taxes) over the 5-year history period.',
            // Net returns keep their sign; the other figures are unsigned.
            value: '${s.netReturn.toStringAsFixed(2)}%',
            tone: StrategyMetricTone.pnl,
            pnlBasis: s.netReturn,
          ),
        ],
        tapUrl: s.marketplaceUrl,
        // Tapping a curated card signs into RupeeCase (SSO), not the plain link.
        ssoVc: 'rupeecase',
        accentColor: accentColor,
      );

  /// [stackedMetrics] renders the narrow card copy: a 2×2 footer grid and the
  /// compact title, instead of a single four-column metric row.
  factory StrategyCardData.fromAlgo(
    AlgoStrategy s, {
    Color? accentColor,
    bool stackedMetrics = false,
  }) {
    final double ddPct = s.maxDrawdownPct;
    return StrategyCardData(
      name: s.title,
      headerLabel: 'Subscribed ${s.subscriberCount}',
      riskLevel: s.riskLevel,
      gauge: StrategyRiskGauge.dial,
      metricsLayout: stackedMetrics
          ? StrategyMetricsLayout.grid
          : StrategyMetricsLayout.row,
      metricLabelGap: stackedMetrics ? 3 : 5,
      titleBesideGauge: false,
      compactTitle: stackedMetrics,
      metrics: [
        StrategyMetric(
          label: 'MIN. CAP',
          tooltip: 'Minimum capital required to run this basket.',
          value: _compactRupee(s.capitalRequired),
        ),
        StrategyMetric(
          label: 'CAGR',
          tooltip:
              'Compound Annual Growth Rate — back-tested annualised return.',
          value: _unsignedPct(s.cagr),
          tone: StrategyMetricTone.pnl,
          pnlBasis: s.cagr,
        ),
        StrategyMetric(
          label: 'DD',
          tooltip: 'Max drawdown — the worst peak-to-trough equity drop over '
              'the back-test, as a percentage of the required capital.',
          value: ddPct > 0 ? _unsignedPct(ddPct) : '—',
          tone:
              ddPct > 0 ? StrategyMetricTone.loss : StrategyMetricTone.muted,
        ),
        StrategyMetric(
          label: 'WIN RATE',
          tooltip:
              'Percentage of trades that closed in profit during the back-test.',
          value: _unsignedPct(s.winRate),
          tone: StrategyMetricTone.profit,
        ),
      ],
      // Every algo card opens the Zebu Algo marketplace on tap.
      tapUrl: kAlgoMarketplaceUrl,
      accentColor: accentColor,
    );
  }
}

String _weeksLabel(int weeks) {
  if (weeks <= 0) return '';
  return 'Rebalance ${weeks}W';
}

const List<Color> kStrategyAccentPalette = [
  Color(0xFF2563EB), // blue
  Color(0xFF0D9488), // teal
  Color(0xFF7C3AED), // violet
  Color(0xFFDB2777), // magenta
  Color(0xFFEA580C), // orange
  Color(0xFF16A34A), // green
  Color(0xFFCA8A04), // gold
  Color(0xFF0891B2), // cyan
];

/// Distinct palette for automated strategies; the cooler, more saturated hues
/// keep the Algo collection visually separate from curated RupeeCase cards.
const List<Color> kAlgoStrategyAccentPalette = [
  Color(0xFF6D28D9), // violet
  Color(0xFF4338CA), // indigo
  Color(0xFFBE185D), // fuchsia
  Color(0xFF0F766E), // deep teal
  Color(0xFFC2410C), // burnt orange
  Color(0xFF0369A1), // deep blue
  Color(0xFF7E22CE), // purple
  Color(0xFFB45309), // amber
];

/// Every algo strategy card (dashboard scroller and the "see all" table) opens
/// this Zebu Algo marketplace link on tap.
const String kAlgoMarketplaceUrl = 'https://algo.zebuetrade.com/marketplace';

/// Shared floor for every strategy card so the curated row and the algo row
/// render at the same height. Cards only grow past it when a long title needs
/// a third line, and then the whole row grows with them.
const double kStrategyCardMinHeight = 200;

/// The single strategy card used by both dashboard rows. Everything that
/// differs between a curated and an algo strategy comes in through
/// [StrategyCardData].
class StrategyCard extends ConsumerStatefulWidget {
  const StrategyCard({super.key, required this.data});

  final StrategyCardData data;

  @override
  ConsumerState<StrategyCard> createState() => _StrategyCardState();
}

class _StrategyCardState extends ConsumerState<StrategyCard> {
  bool _hovered = false;

  StrategyCardData get data => widget.data;

  @override
  Widget build(BuildContext context) {
    final bool clickable =
        data.ssoVc.trim().isNotEmpty || data.tapUrl.trim().isNotEmpty;

    final Color hoverOverlay = resolveThemeColor(context,
        dark: Colors.white.withValues(alpha: 0.05),
        light: Colors.black.withValues(alpha: 0.035));

    return MouseRegion(
      cursor: clickable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: clickable ? () => _handleTap(context, ref) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          foregroundDecoration: BoxDecoration(
            color: _hovered ? hoverOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: _StrategyCardBody(data: data),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final String vc = data.ssoVc.trim();
    if (vc.isEmpty) {
      debugPrint(
          "[SSO] card '${data.name}' tapped — plain link: ${data.tapUrl}");
      await openExternalUrl(data.tapUrl);
      return;
    }
    debugPrint("[SSO:$vc] card '${data.name}' tapped — fetching HS token…");
    final funds = ref.read(fundProvider);
    await funds.fetchHstoken(context);
    await funds.openSsoInNewTab(vc);
  }
}

/// The card's visuals: a bordered accent-gradient panel holding the header
/// label + risk gauge, the strategy title and the footer metric panel.
class _StrategyCardBody extends StatelessWidget {
  const _StrategyCardBody({required this.data});

  final StrategyCardData data;

  @override
  Widget build(BuildContext context) {
    final Color? accent = data.accentColor;
    final Color sectionBorder = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final Color base = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);

    // Diagonal accent wash — strongest at the top-left, fading out toward the
    // bottom-right. Inner stats stay on the white stat panel. Flat — no shadow.
    final Color cardStrong = accent == null
        ? base
        : resolveThemeColor(context,
            dark: Color.lerp(MyntColors.cardDark, accent, 0.20)!,
            light: Color.lerp(MyntColors.card, accent, 0.11)!);
    final Color cardSoft = accent == null
        ? base
        : resolveThemeColor(context,
            dark: Color.lerp(MyntColors.cardDark, accent, 0.05)!,
            light: Color.lerp(MyntColors.card, accent, 0.02)!);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: data.minHeight),
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: accent == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cardStrong, cardSoft],
              ),
        color: accent == null ? base : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: sectionBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._header(context),
          const SizedBox(height: 12),
          const Spacer(),
          _metricsFooter(context),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────── header ──

  /// Header label + risk gauge, with the title either sharing that row (curated
  /// cards) or spanning the full width beneath it (algo cards).
  List<Widget> _header(BuildContext context) {
    final Widget? gauge = _riskGauge();
    if (data.titleBesideGauge) {
      return [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _headerLabel(context),
                  const SizedBox(height: 6),
                  _titleLine(context),
                ],
              ),
            ),
            if (gauge != null) ...[const SizedBox(width: 8), gauge],
          ],
        ),
      ];
    }
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _headerLabel(context)),
          if (gauge != null) ...[const SizedBox(width: 8), gauge],
        ],
      ),
      const SizedBox(height: 8),
      _titleLine(context),
    ];
  }

  Widget? _riskGauge() {
    if (data.riskLevel.trim().isEmpty) return null;
    return data.gauge == StrategyRiskGauge.rainbow
        ? _RiskGauge(riskLevel: data.riskLevel, benchmark: data.benchmark)
        : _AlgoRiskGauge(riskLevel: data.riskLevel);
  }

  /// Single muted line above the title ("Rebalance 4W" / "Subscribed 120").
  Widget _headerLabel(BuildContext context) {
    return Text(
      data.headerLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: MyntWebTextStyles.para(
        context,
        color: _cardMutedText(context),
        fontWeight: MyntFonts.semiBold,
      ),
    );
  }

  /// Title in Title Case. The compact copy shows the first two words on line
  /// one and wraps the rest beneath so the whole name stays visible on a narrow
  /// card; the full copy wraps naturally onto two lines.
  Widget _titleLine(BuildContext context) {
    final TextStyle base = data.compactTitle
        ? MyntWebTextStyles.body(
            context,
            darkColor: const Color(0xFFEDF2F7),
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.semiBold,
          )
        : MyntWebTextStyles.title(
            context,
            darkColor: const Color(0xFFEDF2F7),
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.semiBold,
          );
    return Text(
      data.compactTitle
          ? _titleTwoWordsFirstLine(data.name)
          : _titleCase(data.name),
      maxLines: data.compactTitle ? 3 : 2,
      overflow: TextOverflow.ellipsis,
      style: base.copyWith(
        fontSize: data.titleFontSize,
        letterSpacing: 0.4,
        height: 1.2,
      ),
    );
  }

  // ───────────────────────────────────────────────────────── metric footer ──

  /// All metrics inside one white panel — either a single row or a 2×2 grid.
  Widget _metricsFooter(BuildContext context) {
    final List<Widget> tiles = [
      for (final metric in data.metrics)
        _MetricTile(metric: metric, labelGap: data.metricLabelGap),
    ];

    final Color panelBg = resolveThemeColor(context,
        dark: Colors.white.withValues(alpha: 0.10), light: Colors.white);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: data.metricsLayout == StrategyMetricsLayout.row
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final tile in tiles) Expanded(child: tile)],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: _metricPairs(tiles),
            ),
    );
  }

  /// The tiles two-per-row, separated by a 10px gutter.
  List<Widget> _metricPairs(List<Widget> tiles) {
    final List<Widget> rows = [];
    for (int i = 0; i < tiles.length; i += 2) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: tiles[i]),
          Expanded(
            child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink(),
          ),
        ],
      ));
    }
    return rows;
  }
}

/// One footer metric — a small muted label (with its info glyph) over a larger
/// coloured value. The white background comes from the panel that wraps them.
class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.labelGap});

  final StrategyMetric metric;

  /// Gap between the label and the value.
  final double labelGap;

  @override
  Widget build(BuildContext context) {
    final Color labelColor = _cardLabelText(context);
    final String? tooltip = metric.tooltip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                metric.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                // Fixed 10px caption so every label renders at the same size,
                // however long it is.
                style: webText(
                  context,
                  size: 10,
                  weight: MyntFonts.semiBold,
                  color: labelColor,
                ),
              ),
            ),
            if (tooltip != null) ...[
              const SizedBox(width: 2),
              _InfoTooltip(message: tooltip, color: labelColor),
            ],
          ],
        ),
        SizedBox(height: labelGap),
        Text(
          metric.value,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          // Fixed size so all values render uniformly (price / 14px).
          style: MyntWebTextStyles.price(
            context,
            color: metric.color(context),
            fontWeight: MyntFonts.medium,
          ),
        ),
      ],
    );
  }
}

/// The small `info` glyph + hover tooltip shown beside a stat label.
class _InfoTooltip extends StatelessWidget {
  const _InfoTooltip({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Color tooltipBg = resolveThemeColor(context,
        dark: const Color(0xFF252A33), light: Colors.white);
    final Color tooltipText = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 200),
      showDuration: const Duration(seconds: 6),
      preferBelow: false,
      verticalOffset: 12,
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: tooltipBg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      textStyle: MyntWebTextStyles.bodySmall(context,
          color: tooltipText, fontWeight: MyntFonts.regular),
      child: SvgPicture.asset(
        assets.info,
        width: 10,
        height: 10,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

/// Shimmer placeholder mirroring a loaded [StrategyCard] while fetching — the
/// same bordered shell with a header line + gauge, a two-line title and the
/// metric footer. Uses [Skeletonizer.zone] so only the [Bone] blocks shimmer
/// while the card shell stays crisp.
class StrategyCardSkeleton extends StatelessWidget {
  const StrategyCardSkeleton({
    super.key,
    this.minHeight = kStrategyCardMinHeight,
    this.footer = StrategyMetricsLayout.grid,
  });

  /// Matches the loaded card's [StrategyCardData.minHeight], so the row doesn't
  /// resize when the data lands.
  final double minHeight;

  /// [StrategyMetricsLayout.grid] shimmers a 2×2 white panel;
  /// [StrategyMetricsLayout.row] shimmers four separate tinted tiles.
  final StrategyMetricsLayout footer;

  // Per-column bone widths, so the footer shimmer reads like real
  // labels/values rather than four identical bars.
  static const List<double> _labelWidths = [46, 34, 20, 50];
  static const List<double> _valueWidths = [34, 42, 40, 40];

  @override
  Widget build(BuildContext context) {
    final Color sectionBorder = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final Color base = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final bool grid = footer == StrategyMetricsLayout.grid;

    return Skeletonizer.zone(
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sectionBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header line + risk gauge ──
            Row(
              children: const [
                Bone(width: 70, height: 12, uniRadius: 6),
                Spacer(),
                Bone(width: 42, height: 20, uniRadius: 6),
              ],
            ),
            const SizedBox(height: 10),
            // ── Title (two lines) ──
            const Bone(width: 160, height: 14, uniRadius: 6),
            const SizedBox(height: 6),
            Bone(width: grid ? 110 : 100, height: 14, uniRadius: 6),
            const Spacer(),
            grid ? _gridFooter(context) : _rowFooter(context),
          ],
        ),
      ),
    );
  }

  /// 2×2 metric footer inside one white panel (MIN.CAP|CAGR over ALPHA|NR).
  Widget _gridFooter(BuildContext context) {
    final Color panelBg = resolveThemeColor(context,
        dark: Colors.white.withValues(alpha: 0.10), light: Colors.white);

    // One bone row: two label-over-value pairs side by side.
    Widget boneRow(double lw1, double vw1, double lw2, double vw2) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _bonePair(lw1, vw1)),
            Expanded(child: _bonePair(lw2, vw2)),
          ],
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          boneRow(48, 36, 30, 40), // MIN.CAP | CAGR
          const SizedBox(height: 10),
          boneRow(36, 36, 20, 44), // ALPHA | NR
        ],
      ),
    );
  }

  /// Four-column metric footer as separate tinted tiles.
  Widget _rowFooter(BuildContext context) {
    final Color tileBg = resolveThemeColor(context,
        dark: Colors.white.withValues(alpha: 0.10), light: Colors.white);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < _labelWidths.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _bonePair(_labelWidths[i], _valueWidths[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One shimmering label-over-value pair.
  Widget _bonePair(double labelWidth, double valueWidth) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Bone(width: labelWidth, height: 9, uniRadius: 6),
          const SizedBox(height: 6),
          Bone(width: valueWidth, height: 13, uniRadius: 6),
        ],
      );
}

/// Title-cases [text]: lower-cases everything, then capitalises the first letter
/// of each whitespace-separated word — "BANKNIFTY MONTHLY BUY" → "Banknifty
/// Monthly Buy".
String _titleCase(String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed
      .split(RegExp(r'\s+'))
      .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}

/// Title-cases [text] and forces a line break after the first two words, so the
/// first row shows two words and the remaining words wrap beneath. Used by the
/// compact (narrow) card copy.
String _titleTwoWordsFirstLine(String text) {
  final String t = _titleCase(text);
  final List<String> words = t.split(RegExp(r'\s+'));
  if (words.length <= 2) return t;
  return '${words.take(2).join(' ')}\n${words.skip(2).join(' ')}';
}

/// Formats a percentage without a leading +/- sign, e.g. `-8.3` → `"8.30%"`.
/// The card conveys profit/loss through colour, so the sign is dropped.
String _unsignedPct(double value) => '${value.abs().toStringAsFixed(2)}%';

/// Compact ₹ figure for the cards' "Min. Cap" metric (`₹25K`, `₹2L`, `₹1.5Cr`),
/// trimming a redundant `.00` and the space before the unit so the value reads
/// compactly. Thousands are shown as `K` (₹10,000 → `₹10K`); the shared
/// [RupeeFormat] compact helper only goes down to lakhs, so that tier is
/// applied here.
String _compactRupee(double value) {
  final double abs = value.abs();
  final String s = (abs >= 1000 && abs < 100000)
      ? '${value < 0 ? '-' : ''}₹${(abs / 1000).toStringAsFixed(2)} K'
      : RupeeFormat.formatCompactWithRupee(value, decimalPlaces: 2);
  return s
      .replaceAll(RegExp(r'\.00(?= |$)'), '') // trim redundant ".00"
      .replaceAll(' Cr', 'Cr')
      .replaceAll(' L', 'L')
      .replaceAll(' K', 'K');
}

/// A risk tier: needle position (0 = lowest … 1 = highest) and dial hue.
class _RiskTier {
  const _RiskTier(this.fraction, this.color);
  final double fraction;
  final Color color;
}

const Color _kRiskGreen = Color(0xFF16A34A);
const Color _kRiskLime = Color(0xFF84CC16);
const Color _kRiskAmber = Color(0xFFF5B70A);
const Color _kRiskOrange = Color(0xFFF97316);
const Color _kRiskRed = Color(0xFFEF4444);

/// Maps a free-text risk label to one of five tiers (Very Low → Very High).
/// More specific phrases ("moderately high/low") are matched before the plain
/// "high"/"low"/"moderate" terms they contain.
_RiskTier _riskTier(String riskLevel) {
  final String r = riskLevel.toLowerCase();
  if (r.contains('very high') || r.contains('aggressive')) {
    return const _RiskTier(0.9, _kRiskRed);
  }
  if (r.contains('moderately high') || r.contains('high')) {
    return const _RiskTier(0.72, _kRiskOrange);
  }
  if (r.contains('moderately low')) {
    return const _RiskTier(0.3, _kRiskLime);
  }
  if (r.contains('moderate') || r.contains('medium') || r.contains('balanced')) {
    return const _RiskTier(0.5, _kRiskAmber);
  }
  if (r.contains('very low')) {
    return const _RiskTier(0.1, _kRiskGreen);
  }
  if (r.contains('low') || r.contains('conservative')) {
    return const _RiskTier(0.3, _kRiskLime);
  }
  return const _RiskTier(0.5, _kRiskAmber);
}

/// Original 5-segment rainbow risk gauge for RupeeCase cards — a semicircular
/// arc split into five coloured segments (green → lime → yellow → orange → red)
/// with a needle that points to the strategy's risk position. Shows the full
/// risk label on hover. Larger than the algo gauge (58 × 25 px).
class _RiskGauge extends StatelessWidget {
  const _RiskGauge({required this.riskLevel, required this.benchmark});

  final String riskLevel;
  final String benchmark;

  double get _fraction {
    final String r = riskLevel.toLowerCase();
    if (r.contains('very high') || r.contains('aggressive')) return 0.94;
    if (r.contains('moderately high') || r.contains('high')) return 0.72;
    if (r.contains('moderate') ||
        r.contains('medium') ||
        r.contains('balanced')) {
      return 0.5;
    }
    if (r.contains('moderately low')) return 0.28;
    if (r.contains('low') || r.contains('conservative')) return 0.12;
    return 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final Color needle = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final Color muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final String bench = benchmark.trim();
    return Column(
      children: [
        Tooltip(
          message: riskLevel,
          child: CustomPaint(
            size: const Size(58, 25),
            painter: _RiskGaugePainter(fraction: _fraction, needleColor: needle),
          ),
        ),
        if (bench.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'vs $bench',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: webText(
              context,
              size: 10,
              weight: MyntFonts.semiBold,
              color: muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _RiskGaugePainter extends CustomPainter {
  _RiskGaugePainter({required this.fraction, required this.needleColor});

  final double fraction;
  final Color needleColor;

  static const List<Color> _segments = [
    Color(0xFF16A34A), // green
    Color(0xFF84CC16), // lime
    Color(0xFFFACC15), // yellow
    Color(0xFFF97316), // orange
    Color(0xFFEF4444), // red
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = size.height * 0.18;
    final Offset center = Offset(size.width / 2, size.height - stroke / 2);
    final double radius = math.min(size.width / 2, size.height) - stroke / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    const double start = math.pi;
    final double segSweep = math.pi / _segments.length;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    for (int i = 0; i < _segments.length; i++) {
      arc.color = _segments[i];
      canvas.drawArc(rect, start + segSweep * i, segSweep, false, arc);
    }

    // Needle.
    final double clamped = fraction.clamp(0.0, 1.0);
    final double angle = math.pi - clamped * math.pi;
    final double needleLen = radius + stroke * 0.15;
    final Offset tip = Offset(
      center.dx + needleLen * math.cos(angle),
      center.dy - needleLen * math.sin(angle),
    );
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = needleColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, stroke * 0.45, Paint()..color = needleColor);
  }

  @override
  bool shouldRepaint(_RiskGaugePainter old) =>
      old.fraction != fraction || old.needleColor != needleColor;
}

/// Speedometer-style risk gauge for the algo cards — a single-hue dial whose
/// colour and needle position map to the strategy's risk tier (green → red).
/// Sits top-right of the title; the full risk label shows on hover.
class _AlgoRiskGauge extends StatelessWidget {
  const _AlgoRiskGauge({required this.riskLevel});

  final String riskLevel;

  @override
  Widget build(BuildContext context) {
    final _RiskTier tier = _riskTier(riskLevel);
    return Tooltip(
      message: riskLevel,
      child: CustomPaint(
        size: const Size(42, 20),
        painter: _AlgoRiskGaugePainter(
          fraction: tier.fraction,
          color: tier.color,
          trackColor: resolveThemeColor(context,
              dark: Colors.white.withValues(alpha: 0.10),
              light: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
    );
  }
}

class _AlgoRiskGaugePainter extends CustomPainter {
  _AlgoRiskGaugePainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = size.height * 0.15;
    final Offset center = Offset(size.width / 2, size.height - stroke / 2);
    final double radius = math.min(size.width / 2, size.height) - stroke;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    // Faint full track under the coloured dial.
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = trackColor,
    );

    // Coloured dial — a light → full sweep of the tier hue.
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: math.pi,
          endAngle: 2 * math.pi,
          colors: [color.withValues(alpha: 0.55), color],
        ).createShader(rect),
    );

    // Tick marks around the outer edge.
    final Paint tickPaint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    const int ticks = 5;
    for (int i = 0; i <= ticks; i++) {
      final double a = math.pi - (i / ticks) * math.pi;
      final double rInner = radius + stroke * 0.15;
      final double rOuter = radius + stroke * 0.55;
      canvas.drawLine(
        Offset(center.dx + rInner * math.cos(a), center.dy - rInner * math.sin(a)),
        Offset(center.dx + rOuter * math.cos(a), center.dy - rOuter * math.sin(a)),
        tickPaint,
      );
    }

    // Needle.
    final double clamped = fraction.clamp(0.0, 1.0);
    final double angle = math.pi - clamped * math.pi;
    final double needleLen = radius - stroke * 0.15;
    final Offset tip = Offset(
      center.dx + needleLen * math.cos(angle),
      center.dy - needleLen * math.sin(angle),
    );
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    // Hub with a white centre.
    canvas.drawCircle(center, stroke * 0.62, Paint()..color = color);
    canvas.drawCircle(center, stroke * 0.28, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_AlgoRiskGaugePainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.trackColor != trackColor;
}

/// Brighter dark-mode text for the strategy cards' inner contents so the
/// values/labels read crisply on the dark card gradient.
Color _cardPrimaryText(BuildContext context) => resolveThemeColor(context,
    dark: const Color(0xFFEDF2F7), light: MyntColors.textPrimary);
Color _cardMutedText(BuildContext context) => resolveThemeColor(context,
    dark: const Color(0xFFB8C2CC), light: MyntColors.textSecondary);

/// Brighter dark-mode colour for the stat captions (CAGR, WIN RATE, ALPHA, NET
/// RETURNS…) so the labels stay legible against the accent-washed card instead
/// of fading into it. Light mode keeps the muted secondary tone.
Color _cardLabelText(BuildContext context) => resolveThemeColor(context,
    dark: const Color(0xFFDCE4EC), light: MyntColors.textSecondary);

Color _pnlColor(BuildContext context, double value) {
  if (value == 0) return _cardPrimaryText(context);
  return value < 0
      ? resolveThemeColor(context,
          dark: const Color(0xFFFF8981), light: MyntColors.loss)
      : resolveThemeColor(context,
          dark: const Color(0xFF56D364), light: MyntColors.profit);
}

/// Opens a URL in a new tab/app; failures are swallowed so a bad link never
/// crashes the page. Shared by the cards and the Algo Trading banner.
Future<void> openExternalUrl(String url) async {
  final String u = url.trim();
  if (u.isEmpty) return;
  final Uri uri = Uri.parse(u);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (_) {
    // Ignore — a failed launch should never surface an error.
  }
}
