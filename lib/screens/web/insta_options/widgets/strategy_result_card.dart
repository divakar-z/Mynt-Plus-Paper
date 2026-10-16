import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/strategy_scan_result.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// One scan result rendered as a card (README §10.9 StrategyCard).
class StrategyResultCard extends StatelessWidget {
  final StrategyScanResult result;
  final VoidCallback onAddToBasket;

  const StrategyResultCard({
    super.key,
    required this.result,
    required this.onAddToBasket,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border.all(color: tokens.border, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(result: result, onAddToBasket: onAddToBasket, tokens: tokens),
          const SizedBox(height: 12),
          Container(height: 1, color: tokens.border),
          const SizedBox(height: 12),
          _LegsTable(legs: result.legs, tokens: tokens),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final StrategyScanResult result;
  final VoidCallback onAddToBasket;
  final InstaOptionsTokens tokens;

  const _Header({
    required this.result,
    required this.onAddToBasket,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      spacing: 16,
      children: [
        Text(
          result.templateName,
          style: MyntWebTextStyles.head(context, color: tokens.textPrimary),
        ),
        _Kpi(
          label: 'Max P&L',
          value: _signed(result.maxPl),
          color: result.maxPl >= 0 ? tokens.profit : tokens.loss,
          tokens: tokens,
        ),
        _Kpi(
          label: 'Max Loss',
          value: _signed(result.maxLoss),
          color: result.maxLoss < 0 ? tokens.loss : tokens.textSecondary,
          tokens: tokens,
        ),
        _Kpi(
          label: 'BE',
          value: result.breakeven.isEmpty
              ? '—'
              : result.breakeven
                  .map((b) => InstaOptionsFormat.price(b))
                  .join(' · '),
          color: tokens.textSecondary,
          tokens: tokens,
        ),
        ElevatedButton.icon(
          onPressed: onAddToBasket,
          icon: const Icon(Icons.add_shopping_cart, size: 16),
          label: const Text('Add to basket'),
          style: ElevatedButton.styleFrom(
            backgroundColor: tokens.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            textStyle: MyntWebTextStyles.bodySmall(
              context,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _signed(double v) {
    if (v == 0) return '0.00';
    final sign = v > 0 ? '+' : '−';
    return '$sign${InstaOptionsFormat.price(v.abs())}';
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final InstaOptionsTokens tokens;

  const _Kpi({
    required this.label,
    required this.value,
    required this.color,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: MyntWebTextStyles.caption(
            context,
            color: tokens.textSecondary,
          ),
        ),
        Text(
          value,
          style: MyntWebTextStyles.body(
            context,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LegsTable extends StatelessWidget {
  final List<StrategyLeg> legs;
  final InstaOptionsTokens tokens;

  const _LegsTable({required this.legs, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final rowHeight = 30.0;
    final headHeight = 32.0;
    final totalHeight = headHeight + rowHeight * legs.length + 8;
    return SizedBox(
      height: totalHeight,
      child: DataTable2(
        columnSpacing: 8,
        horizontalMargin: 8,
        dataRowHeight: rowHeight,
        headingRowHeight: headHeight,
        minWidth: 700,
        headingTextStyle: MyntWebTextStyles.caption(
          context,
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        headingRowColor: WidgetStateProperty.all(Colors.transparent),
        dataTextStyle:
            MyntWebTextStyles.tableCell(context, color: tokens.textPrimary),
        dividerThickness: 0.5,
        columns: const [
          DataColumn2(label: Text('Side'), fixedWidth: 50),
          DataColumn2(label: Text('Symbol'), size: ColumnSize.L),
          DataColumn2(label: Text('Lot'), fixedWidth: 50, numeric: true),
          DataColumn2(label: Text('Strike'), fixedWidth: 80, numeric: true),
          DataColumn2(label: Text('Type'), fixedWidth: 50),
          DataColumn2(label: Text('LTP'), fixedWidth: 80, numeric: true),
          DataColumn2(label: Text('OI'), fixedWidth: 90, numeric: true),
        ],
        rows: legs.map((l) => _row(context, l)).toList(growable: false),
      ),
    );
  }

  DataRow2 _row(BuildContext context, StrategyLeg leg) {
    return DataRow2(
      cells: [
        DataCell(_SideChip(leg: leg, tokens: tokens)),
        DataCell(
          Text(
            leg.tradingSymbol,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(Text(leg.lot.toString())),
        DataCell(Text(leg.strike == 0 ? '—' : leg.strike.toStringAsFixed(0))),
        DataCell(Text(leg.optionType)),
        DataCell(Text(InstaOptionsFormat.price(leg.ltp))),
        DataCell(Text(InstaOptionsFormat.oi(leg.oi))),
      ],
    );
  }
}

class _SideChip extends StatelessWidget {
  final StrategyLeg leg;
  final InstaOptionsTokens tokens;

  const _SideChip({required this.leg, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final bg = leg.isBuy ? tokens.profit : tokens.loss;
    final letter = leg.isBuy ? 'B' : (leg.isSell ? 'S' : '?');
    return Container(
      width: 24,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
