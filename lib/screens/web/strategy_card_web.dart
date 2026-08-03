import 'dart:math' as math; // used by the risk gauge painter

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/rupeecase_model/algo_strategy_model.dart';
import '../../models/rupeecase_model/rupeecase_strategy_model.dart';
import '../../provider/fund_provider.dart';
import '../../res/mynt_web_color_styles.dart';
import '../../res/mynt_web_text_styles.dart';
import '../../res/res.dart';
import '../../utils/rupee_convert_format.dart';

/// Neutral view-model the [StrategyCard] renders from, so curated (RupeeCase)
/// and algo strategies share one identical card layout. Adapt each source type
/// with [StrategyCardData.fromRupeeCase] / [StrategyCardData.fromAlgo].
class StrategyCardData {
  const StrategyCardData({
    required this.name,
    required this.stocksLabel,
    required this.cagr,
    required this.returnValue,
    required this.returnLabel,
    required this.minInvest,
    this.assetClass = 'EQUITY',
    this.benchmark = '',
    this.compositionTags = const [],
    this.alpha,
    this.riskLevel = '',
    this.rebalanceLabel = '',
    this.tapUrl = '',
    this.ssoVc = '',
    this.accentColor,
  });

  /// Strategy / basket name (title line).
  final String name;

  final String stocksLabel;

  /// Asset-composition tags (`EQ DYNAMIC · 50 stocks`…) rendered after the
  /// instrument tag. Empty when the strategy carries no breakdown.
  final List<String> compositionTags;

  /// Annualised return (%), shown as the neutral `CAGR` headline.
  final double cagr;

  /// Cumulative return (%). Rendered with profit/loss colour and captioned by
  /// [returnLabel].
  final double returnValue;

  final String returnLabel;
  final double minInvest;

  /// Instrument-type chip label shown top-left (`EQUITY`, the basket category…).
  final String assetClass;
  final String benchmark;
  final double? alpha;
  final String riskLevel;
  final String rebalanceLabel;

  /// Plain deep-link opened on tap. Empty → the card isn't clickable unless
  /// [ssoVc] is set.
  final String tapUrl;

  final String ssoVc;
  final Color? accentColor;

  factory StrategyCardData.fromRupeeCase(RupeeCaseStrategy s,
          {Color? accentColor}) =>
      StrategyCardData(
        name: s.name,
        stocksLabel:
            '${s.totalStocks} ${s.totalStocks == 1 ? 'Stock' : 'Stocks'}',
        cagr: s.cagr,
        returnValue: s.netReturn,
        returnLabel: 'Net Returns',
        minInvest: s.minInvest,
        assetClass: '',
        benchmark: s.benchmark,
        compositionTags: _compositionTags(s),
        alpha: s.alpha,
        riskLevel: s.riskLevel,
        rebalanceLabel: _weeksLabel(s.rebalanceWeeks),
        tapUrl: s.marketplaceUrl,
        // Tapping a curated card signs into RupeeCase (SSO), not the plain link.
        ssoVc: 'rupeecase',
        accentColor: accentColor,
      );

  factory StrategyCardData.fromAlgo(AlgoStrategy s) => StrategyCardData(
        name: s.title,
        stocksLabel:
            '${s.strategiesCount} ${s.strategiesCount == 1 ? 'Strategy' : 'Strategies'}',
        cagr: s.cagr,
        returnValue: s.totalReturn,
        returnLabel: 'Total Return',
        minInvest: s.capitalRequired,
        assetClass: s.category.isEmpty ? 'ALGO' : s.category.toUpperCase(),
        benchmark: '',
        compositionTags: s.tags,
        alpha: null,
        riskLevel: s.riskLevel,
        rebalanceLabel: '',
      );
}

List<String> _compositionTags(RupeeCaseStrategy s) => s.composition
    .where((a) => a.name.trim().isNotEmpty)
    .map((a) =>
        '${a.name} · ${a.stockCount} ${a.stockCount == 1 ? 'stock' : 'stocks'}')
    .toList();

String _weeksLabel(int weeks) {
  if (weeks <= 0) return '';
  return 'Every ${weeks}W';
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
          child: _StrategyBody(data: data),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final String vc = data.ssoVc.trim();
    if (vc.isEmpty) {
      debugPrint(
          "[SSO] card '${data.name}' tapped — plain link: ${data.tapUrl}");
      await _launchUrl(data.tapUrl);
      return;
    }
    debugPrint("[SSO:$vc] card '${data.name}' tapped — fetching HS token…");
    final funds = ref.read(fundProvider);
    await funds.fetchHstoken(context);
    await funds.openSsoInNewTab(vc);
  }
}

class _StrategyBody extends StatelessWidget {
  const _StrategyBody({required this.data});

  final StrategyCardData data;

  @override
  Widget build(BuildContext context) {
    final bool showRisk = data.riskLevel.trim().isNotEmpty;
    final Color? accent = data.accentColor;
    final Color sectionBorder = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final Color base = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final BoxDecoration section1Deco = BoxDecoration(
      color: accent == null ? base : null,
      gradient: accent == null
          ? null
          : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                resolveThemeColor(context,
                    dark: Color.lerp(MyntColors.cardDark, accent, 0.26)!,
                    light: Color.lerp(MyntColors.card, accent, 0.16)!),
                base,
              ],
            ),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: sectionBorder),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------- Section 1: bordered card ----------------
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: section1Deco,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _nameLine(context)),
                  if (showRisk) ...[
                    const SizedBox(width: 12),
                    _RiskGauge(
                      riskLevel: data.riskLevel,
                      benchmark: data.benchmark,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              _statBlock(context),
              const SizedBox(height: 16),
              _metaRow(context),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ---------------- Section 2: tags (no border) ----------------
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: _tags(context),
        ),
      ],
    );
  }

  // ---- tags ---
  Widget _tags(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (data.assetClass.trim().isNotEmpty)
          _tagLabel(context, label: data.assetClass, color: _primary(context)),
        for (final tag in data.compositionTags)
          _tagLabel(
            context,
            label: tag,
            color: resolveThemeColor(context,
                dark: MyntColors.secondaryDark, light: MyntColors.secondary),
          ),
      ],
    );
  }

  Widget _tagLabel(
    BuildContext context, {
    required String label,
    required Color color,
  }) {
    // Chip: the label colour as text over a soft same-hue fill.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: MyntWebTextStyles.caption(
          context,
          color: color,
          fontWeight: MyntFonts.semiBold,
        ),
      ),
    );
  }

  // --- name ---

  /// Strategy name (title line), rendered in full uppercase.
  Widget _nameLine(BuildContext context) {
    // return Text(
    //   data.name.toUpperCase(),
    //   maxLines: 1,
    //   overflow: TextOverflow.ellipsis,
    //   style: MyntWebTextStyles.title(
    //     context,
    //     darkColor: MyntColors.textPrimaryDark,
    //     lightColor: MyntColors.textPrimary,
    //     fontWeight: MyntFonts.bold,
    //   ).copyWith(letterSpacing: 0.3),
    // );
    final TextStyle style = MyntWebTextStyles.title(
      context,
      darkColor: MyntColors.textPrimaryDark,
      lightColor: MyntColors.textPrimary,
      fontWeight: MyntFonts.bold,
    ).copyWith(letterSpacing: 0.3);
    return _smallCaps(data.name, style);
  }

  Widget _smallCaps(String text, TextStyle style) {
    final double smallSize = (style.fontSize ?? 14) * 0.80;
    final List<InlineSpan> spans = [];
    final StringBuffer run = StringBuffer();
    bool runSmall = false;

    void flush() {
      if (run.isEmpty) return;
      spans.add(TextSpan(
        text: run.toString(),
        style: runSmall ? TextStyle(fontSize: smallSize) : null,
      ));
      run.clear();
    }

    for (final int rune in text.runes) {
      final String ch = String.fromCharCode(rune);
      // A lowercase letter is one that changes when uppercased.
      final bool isLower = ch != ch.toUpperCase() && ch == ch.toLowerCase();
      if (run.isNotEmpty && runSmall != isLower) flush();
      runSmall = isLower;
      run.write(isLower ? ch.toUpperCase() : ch);
    }
    flush();

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ---- stat block ---

  Widget _statBlock(BuildContext context) {
    final bool hasAlpha = data.alpha != null;

    final stats = <Widget>[
      _statTile(
        context,
        caption: 'CAGR',
        tooltip: 'Compound Annual Growth Rate - the average yearly return if gains were reinvested over 5 years.',
        subtitle: 'YEARLY GROWTH',
        value: '${data.cagr.toStringAsFixed(2)}%',
        valueColor: _pnlColor(context, data.cagr),
      ),
      if (hasAlpha)
        _statTile(
          context,
          caption: 'ALPHA',
          tooltip: 'How much this strategy beat (or tailed) NIFTY 50 over the full 5-year history period.',
          subtitle: 'VS BENCHMARK',
          value: '${data.alpha!.toStringAsFixed(2)}%',
          valueColor: _pnlColor(context, data.alpha!),
        ),
      _statTile(
        context,
        caption: data.returnLabel.toUpperCase(),
        tooltip: 'Total net return after all estimated charges (brokerage, STT, taxes) over the 5-year history period.',
        subtitle: 'CUMULATIVE RETURN',
        value:
            '${data.returnValue >= 0 ? '+' : ''}${data.returnValue.toStringAsFixed(2)}%',
        valueColor: _pnlColor(context, data.returnValue),
      ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: stats[i]),
          ],
        ],
      ),
    );
  }

  Widget _statTile(
    BuildContext context, {
    required String caption,
    required String tooltip,
    required String subtitle,
    required String value,
    required Color valueColor,
  }) {
    final Color captionColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    // White tiles that read as clean panels over the accent-washed section.
    final Color tileBg = resolveThemeColor(context,
        dark: Colors.white.withValues(alpha: 0.06), light: const Color(0xFFFFFFFF));
    final Color tooltipBg = resolveThemeColor(context,
        dark: const Color(0xFF252A33), light: Colors.white);
    final Color tooltipText = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.caption(
                    context,
                    color: captionColor,
                    fontWeight: MyntFonts.semiBold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: tooltip,
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
                child: Icon(
                  Icons.info_outline,
                  size: 13,
                  color: captionColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: MyntWebTextStyles.title(
                context,
                color: valueColor,
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.caption(
              context,
              color: captionColor,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- meta row ---

  Widget _metaRow(BuildContext context) {
    final items = <Widget>[
      _metaItem(
        context,
        iconAsset: assets.rupee,
        value: 'Min ₹${RupeeFormat.format(data.minInvest, decimalPlaces: 0)}',
      ),
      _metaItem(
        context,
        iconAsset: assets.chart,
        value: data.stocksLabel,
      ),
      if (data.rebalanceLabel.trim().isNotEmpty)
        _metaItem(
          context,
          iconAsset: assets.rebalanceIcon,
          value: data.rebalanceLabel,
        ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final item in items) Flexible(child: item),
      ],
    );
  }

  Widget _metaItem(
    BuildContext context, {
    required String iconAsset,
    required String value,
  }) {
    final Color muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final Color primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          iconAsset,
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(muted, BlendMode.srcIn),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: primary,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
        ),
      ],
    );
  }
}

class _RiskGauge extends StatelessWidget {
  const _RiskGauge({required this.riskLevel, this.benchmark = ''});

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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Tooltip(
          message: riskLevel,
          child: CustomPaint(
            size: const Size(58, 30),
            painter:
                _RiskGaugePainter(fraction: _fraction, needleColor: needle),
          ),
        ),
        if (bench.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'vs $bench',
            softWrap: false,
            style: MyntWebTextStyles.caption(
              context,
              color: muted,
              fontWeight: MyntFonts.medium,
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
    Color(0xFF16A34A),
    Color(0xFF84CC16),
    Color(0xFFFACC15),
    Color(0xFFF97316),
    Color(0xFFEF4444),
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

    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, needlePaint);
    canvas.drawCircle(center, stroke * 0.45, Paint()..color = needleColor);
  }

  @override
  bool shouldRepaint(_RiskGaugePainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.needleColor != needleColor;
}

Color _primary(BuildContext context) => resolveThemeColor(context,
    dark: MyntColors.primaryDark, light: MyntColors.primary);

Color _pnlColor(BuildContext context, double value) {
  if (value == 0) {
    return resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
  }
  return value < 0
      ? resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss)
      : resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
}

/// Opens a URL in a new tab/app; failures are swallowed so a bad link never
/// crashes the page.
Future<void> _launchUrl(String url) async {
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
