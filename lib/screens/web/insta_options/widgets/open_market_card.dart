import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/market_snapshot.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_markets_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Open Market card on the Markets Dashboard (README §10.1).
///
/// Header — title + inline KPIs (Advances / Declines).
/// Controls — underlined tab strip for symbol filter + 2-segment Adv/Dec
/// toggle (same Stock/Sector recipe used in Index Contributors).
/// Body — side-by-side Stocks + Index tables. Stocks follows the symbol tab
/// + direction; Index follows only the direction toggle (matches OptionZ).
class OpenMarketCard extends ConsumerStatefulWidget {
  const OpenMarketCard({super.key});

  @override
  ConsumerState<OpenMarketCard> createState() => _OpenMarketCardState();
}

class _OpenMarketCardState extends ConsumerState<OpenMarketCard> {
  String _symbolFilter = 'ALL';
  bool _showAdvanced = true;

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final provider = ref.watch(instaOptionsMarketsProvider);

    final filterKeys = <String>['ALL', ...provider.stockFilterKeys];
    if (!filterKeys.contains(_symbolFilter)) {
      _symbolFilter = 'ALL';
    }

    bool dirFilter(double changePct) =>
        _showAdvanced ? changePct > 0 : changePct < 0;

    final stocks = provider
        .stocksFor(_symbolFilter)
        .where((r) => dirFilter(r.changePct))
        .toList(growable: false)
      ..sort((a, b) => b.changePct.abs().compareTo(a.changePct.abs()));

    final indices = provider.snapshot.indices
        .where((q) => dirFilter(q.changePct))
        .toList(growable: false)
      ..sort((a, b) => b.changePct.abs().compareTo(a.changePct.abs()));

    final bodyHeight = _bodyHeight(stocks.length, indices.length);

    return Container(
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border.all(color: tokens.border, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            advances: provider.advances,
            declines: provider.declines,
            tokens: tokens,
          ),
          _SymbolTabStrip(
            keys: filterKeys,
            active: _symbolFilter,
            onSelect: (k) => setState(() => _symbolFilter = k),
            tokens: tokens,
          ),
          _ControlsRow(
            showAdvanced: _showAdvanced,
            onChanged: (v) => setState(() => _showAdvanced = v),
            stocksCount: stocks.length,
            indicesCount: indices.length,
            tokens: tokens,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              height: bodyHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StocksTable(
                      rows: stocks,
                      tokens: tokens,
                      showAdvanced: _showAdvanced,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _IndexTable(
                      rows: indices,
                      tokens: tokens,
                      showAdvanced: _showAdvanced,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Body height grows with whichever table has more rows, clamped so the
  /// section is meaningful when empty and not absurdly tall when packed.
  double _bodyHeight(int stocksCount, int indicesCount) {
    const rowH = 32.0;
    const headingH = 36.0;
    const cardChromeH = 40.0; // section title bar + bottom padding
    final tallest =
        stocksCount > indicesCount ? stocksCount : indicesCount;
    final natural = headingH + cardChromeH + tallest * rowH;
    return natural.clamp(180.0, 520.0);
  }
}

class _Header extends StatelessWidget {
  final int advances;
  final int declines;
  final InstaOptionsTokens tokens;

  const _Header({
    required this.advances,
    required this.declines,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Text(
            'Open Market',
            style: MyntWebTextStyles.title(
              context,
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _KpiInline(
            label: 'Advances',
            value: advances,
            tone: tokens.profit,
            tokens: tokens,
          ),
          const SizedBox(width: 18),
          _KpiInline(
            label: 'Declines',
            value: declines,
            tone: tokens.loss,
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

class _KpiInline extends StatelessWidget {
  final String label;
  final int value;
  final Color tone;
  final InstaOptionsTokens tokens;

  const _KpiInline({
    required this.label,
    required this.value,
    required this.tone,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$value',
          style: MyntWebTextStyles.title(
            context,
            color: tone,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: MyntWebTextStyles.bodySmall(
            context,
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SymbolTabStrip extends StatelessWidget {
  final List<String> keys;
  final String active;
  final ValueChanged<String> onSelect;
  final InstaOptionsTokens tokens;

  const _SymbolTabStrip({
    required this.keys,
    required this.active,
    required this.onSelect,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: keys
              .map((k) => _SymbolTab(
                    name: k,
                    isActive: k == active,
                    onTap: () => onSelect(k),
                    tokens: tokens,
                  ))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _SymbolTab extends StatefulWidget {
  final String name;
  final bool isActive;
  final VoidCallback onTap;
  final InstaOptionsTokens tokens;

  const _SymbolTab({
    required this.name,
    required this.isActive,
    required this.onTap,
    required this.tokens,
  });

  @override
  State<_SymbolTab> createState() => _SymbolTabState();
}

class _SymbolTabState extends State<_SymbolTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final color = widget.isActive
        ? tokens.textPrimary
        : (_hovered ? tokens.textPrimary : tokens.textSecondary);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color:
                    widget.isActive ? tokens.accent : Colors.transparent,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.name,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: color,
              fontWeight:
                  widget.isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlsRow extends StatelessWidget {
  final bool showAdvanced;
  final ValueChanged<bool> onChanged;
  final int stocksCount;
  final int indicesCount;
  final InstaOptionsTokens tokens;

  const _ControlsRow({
    required this.showAdvanced,
    required this.onChanged,
    required this.stocksCount,
    required this.indicesCount,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Text(
            '$stocksCount stocks · $indicesCount indices',
            style: MyntWebTextStyles.caption(
              context,
              color: tokens.textMuted,
            ),
          ),
          const Spacer(),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Advanced')),
              ButtonSegment(value: false, label: Text('Declined')),
            ],
            selected: {showAdvanced},
            onSelectionChanged: (s) => onChanged(s.first),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              foregroundColor: tokens.textSecondary,
              selectedForegroundColor: tokens.textPrimary,
              selectedBackgroundColor: tokens.bgTertiary,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: MyntWebTextStyles.bodySmall(
                context,
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StocksTable extends StatelessWidget {
  final List<StockGapRow> rows;
  final InstaOptionsTokens tokens;
  final bool showAdvanced;

  const _StocksTable({
    required this.rows,
    required this.tokens,
    required this.showAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Stocks',
      tokens: tokens,
      body: rows.isEmpty
          ? _emptyState(context, tokens, showAdvanced)
          : DataTable2(
              columnSpacing: 6,
              horizontalMargin: 12,
              dataRowHeight: 32,
              headingRowHeight: 36,
              minWidth: 420,
              headingTextStyle: MyntWebTextStyles.para(
                context,
                color: tokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              headingRowColor: WidgetStateProperty.all(tokens.bgSecondary),
              dataTextStyle: MyntWebTextStyles.tableCell(
                context,
                color: tokens.textPrimary,
              ),
              dividerThickness: 0.5,
              columns: const [
                DataColumn2(label: Text('Name'), size: ColumnSize.M),
                DataColumn2(
                    label: Text('Today Open'), fixedWidth: 90, numeric: true),
                DataColumn2(
                    label: Text('Yest. Close'),
                    fixedWidth: 90,
                    numeric: true),
                DataColumn2(
                    label: Text('Gap / Chg %'),
                    fixedWidth: 100,
                    numeric: true),
                DataColumn2(
                    label: Text('LTP'), fixedWidth: 80, numeric: true),
              ],
              rows: rows
                  .map((r) => _stockRow(context, r, tokens))
                  .toList(growable: false),
            ),
    );
  }
}

class _IndexTable extends StatelessWidget {
  final List<IndexQuote> rows;
  final InstaOptionsTokens tokens;
  final bool showAdvanced;

  const _IndexTable({
    required this.rows,
    required this.tokens,
    required this.showAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Index',
      tokens: tokens,
      body: rows.isEmpty
          ? _emptyState(context, tokens, showAdvanced)
          : DataTable2(
              columnSpacing: 6,
              horizontalMargin: 12,
              dataRowHeight: 32,
              headingRowHeight: 36,
              minWidth: 420,
              headingTextStyle: MyntWebTextStyles.para(
                context,
                color: tokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              headingRowColor: WidgetStateProperty.all(tokens.bgSecondary),
              dataTextStyle: MyntWebTextStyles.tableCell(
                context,
                color: tokens.textPrimary,
              ),
              dividerThickness: 0.5,
              columns: const [
                DataColumn2(label: Text('Name'), size: ColumnSize.M),
                DataColumn2(
                    label: Text('Today Open'), fixedWidth: 90, numeric: true),
                DataColumn2(
                    label: Text('Yest. Close'),
                    fixedWidth: 90,
                    numeric: true),
                DataColumn2(
                    label: Text('Chg %'),
                    fixedWidth: 80,
                    numeric: true),
                DataColumn2(
                    label: Text('LTP'), fixedWidth: 80, numeric: true),
              ],
              rows: rows
                  .map((r) => _indexRow(context, r, tokens))
                  .toList(growable: false),
            ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final String title;
  final Widget body;
  final InstaOptionsTokens tokens;

  const _TableCard({
    required this.title,
    required this.body,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.bgPrimary,
        border: Border.all(color: tokens.border, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: tokens.bgTertiary,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: MyntWebTextStyles.bodySmall(
                context,
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

Widget _emptyState(
    BuildContext context, InstaOptionsTokens tokens, bool showAdvanced) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        showAdvanced ? 'No advancers right now.' : 'No decliners right now.',
        style: MyntWebTextStyles.caption(context, color: tokens.textMuted),
      ),
    ),
  );
}

DataRow2 _stockRow(
    BuildContext context, StockGapRow r, InstaOptionsTokens tokens) {
  final tone = r.changePct == 0
      ? tokens.textSecondary
      : (r.changePct > 0 ? tokens.profit : tokens.loss);
  return DataRow2(
    cells: [
      DataCell(
        Text(
          r.name,
          style: MyntWebTextStyles.bodySmall(
            context,
            color: tokens.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      DataCell(Text(InstaOptionsFormat.price(r.todayOpen))),
      DataCell(Text(InstaOptionsFormat.price(r.yesterdayClose))),
      DataCell(
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              InstaOptionsFormat.changePct(r.gapPct),
              style:
                  MyntWebTextStyles.caption(context, color: tokens.textMuted),
            ),
            Text(
              InstaOptionsFormat.changePct(r.changePct),
              style: MyntWebTextStyles.tableCell(context, color: tone),
            ),
          ],
        ),
      ),
      DataCell(Text(InstaOptionsFormat.price(r.ltp))),
    ],
  );
}

DataRow2 _indexRow(
    BuildContext context, IndexQuote q, InstaOptionsTokens tokens) {
  final tone = q.changePct == 0
      ? tokens.textSecondary
      : (q.changePct > 0 ? tokens.profit : tokens.loss);
  return DataRow2(
    cells: [
      DataCell(
        Text(
          q.name,
          style: MyntWebTextStyles.bodySmall(
            context,
            color: tokens.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      DataCell(Text(InstaOptionsFormat.price(q.todayOpen))),
      DataCell(Text(InstaOptionsFormat.price(q.yesterdayClose))),
      DataCell(
        Text(
          InstaOptionsFormat.changePct(q.changePct),
          style: MyntWebTextStyles.tableCell(context, color: tone),
        ),
      ),
      DataCell(Text(InstaOptionsFormat.price(q.ltp))),
    ],
  );
}
