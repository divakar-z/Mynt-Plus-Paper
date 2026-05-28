import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/chain_row.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_chain_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/chain_leg_bottom_sheet.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/oi_bar_cell.dart';

/// Option Chain screen (README §10.3). Phase 2: REST-only.
///
/// Loads `/analytics/chain` + `/spot` on mount and on selection change.
/// Highlights the ATM row. Right-click (or long-press) on any CE/PE cell
/// opens the bottom sheet for visual basket enqueue. Sticky ATM scrolling,
/// the Change-ref dropdown, and WS streaming are deferred to a polish sprint.
class ChainScreen extends ConsumerStatefulWidget {
  const ChainScreen({super.key});

  @override
  ConsumerState<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends ConsumerState<ChainScreen> {
  bool _showGreeks = true;

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final chain = ref.watch(instaOptionsChainProvider);
    final selection = ref.watch(instaOptionsSelectionProvider).selection;

    if (selection.expiry.isEmpty) {
      return _EmptyState(
        icon: Icons.event_busy,
        title: 'Pick an expiry',
        message: 'Choose an expiry from the bar above to load the chain.',
        tokens: tokens,
      );
    }
    if (chain.loading && chain.rows.isEmpty) {
      return _LoadingState(tokens: tokens);
    }
    if (chain.error != null && chain.rows.isEmpty) {
      return _ErrorState(
        message: chain.error!,
        tokens: tokens,
        onRetry: chain.refresh,
      );
    }
    if (chain.rows.isEmpty) {
      return _EmptyState(
        icon: Icons.table_chart,
        title: 'No chain data',
        message: 'Selection may be stale. Retry to fetch again.',
        tokens: tokens,
        onRetry: chain.refresh,
      );
    }

    return Container(
      color: tokens.bgPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChainHeader(
            spot: chain.spot,
            futLtp: chain.futRow?.ltp,
            atm: chain.atmStrike,
            showGreeks: _showGreeks,
            onToggleGreeks: (v) => setState(() => _showGreeks = v),
            tokens: tokens,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _ChainTable(
                strikes: chain.strikes,
                atm: chain.atmStrike,
                showGreeks: _showGreeks,
                maxOi: chain.maxOi,
                chain: chain,
                tokens: tokens,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChainHeader extends StatelessWidget {
  final double spot;
  final double? futLtp;
  final double? atm;
  final bool showGreeks;
  final ValueChanged<bool> onToggleGreeks;
  final InstaOptionsTokens tokens;

  const _ChainHeader({
    required this.spot,
    required this.futLtp,
    required this.atm,
    required this.showGreeks,
    required this.onToggleGreeks,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _Stat(label: 'Spot', value: InstaOptionsFormat.price(spot), tokens: tokens),
          const SizedBox(width: 24),
          _Stat(
            label: 'FUT',
            value: futLtp == null ? '—' : InstaOptionsFormat.price(futLtp!),
            tokens: tokens,
          ),
          const SizedBox(width: 24),
          _Stat(
            label: 'ATM',
            value: atm == null ? '—' : atm!.toStringAsFixed(0),
            tokens: tokens,
          ),
          const Spacer(),
          Text(
            'Show Greeks',
            style: MyntWebTextStyles.body(
              context,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: showGreeks,
            activeThumbColor: tokens.accent,
            onChanged: onToggleGreeks,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final InstaOptionsTokens tokens;

  const _Stat({required this.label, required this.value, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label:',
          style: MyntWebTextStyles.caption(
            context,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: MyntWebTextStyles.price(
            context,
            color: tokens.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ChainTable extends StatelessWidget {
  final List<double> strikes;
  final double? atm;
  final bool showGreeks;
  final int maxOi;
  final InstaOptionsChainProvider chain;
  final InstaOptionsTokens tokens;

  const _ChainTable({
    required this.strikes,
    required this.atm,
    required this.showGreeks,
    required this.maxOi,
    required this.chain,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border.all(color: tokens.border, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: DataTable2(
        columnSpacing: 6,
        horizontalMargin: 8,
        dataRowHeight: 32,
        headingRowHeight: 40,
        headingTextStyle: MyntWebTextStyles.para(
          context,
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        headingRowColor: WidgetStateProperty.all(tokens.bgTertiary),
        dataTextStyle: MyntWebTextStyles.tableCell(
          context,
          color: tokens.textPrimary,
        ),
        dividerThickness: 0.5,
        columns: _buildColumns(),
        rows: strikes
            .map((strike) => _buildRow(context, strike))
            .toList(growable: false),
      ),
    );
  }

  List<DataColumn2> _buildColumns() {
    return [
      if (showGreeks) const DataColumn2(label: Text('Δ'), fixedWidth: 60, numeric: true),
      const DataColumn2(label: Text('OI'), fixedWidth: 110, numeric: true),
      if (showGreeks) const DataColumn2(label: Text('IV'), fixedWidth: 60, numeric: true),
      const DataColumn2(label: Text('LTP'), fixedWidth: 80, numeric: true),
      const DataColumn2(label: Text('STRIKE'), fixedWidth: 96, numeric: true),
      const DataColumn2(label: Text('LTP'), fixedWidth: 80, numeric: true),
      if (showGreeks) const DataColumn2(label: Text('IV'), fixedWidth: 60, numeric: true),
      const DataColumn2(label: Text('OI'), fixedWidth: 110, numeric: true),
      if (showGreeks) const DataColumn2(label: Text('Δ'), fixedWidth: 60, numeric: true),
      const DataColumn2(label: Text('PCR'), fixedWidth: 60, numeric: true),
    ];
  }

  DataRow2 _buildRow(BuildContext context, double strike) {
    final pair = chain.atStrike(strike);
    final ce = pair.ce;
    final pe = pair.pe;
    final isAtm = atm != null && strike == atm;
    final rowColor = isAtm ? tokens.atmHighlight : null;
    final pcr = (ce == null || ce.oi == 0)
        ? double.nan
        : (pe?.oi ?? 0) / ce.oi.toDouble();

    return DataRow2(
      color: rowColor == null ? null : WidgetStateProperty.all(rowColor),
      cells: [
        if (showGreeks) _centerCell(_greekText(context, ce?.delta)),
        _oiCell(context, ce, isCallSide: true),
        if (showGreeks) _centerCell(_ivText(context, ce?.iv, ce?.ivSolverOk)),
        _centerCell(_priceText(context, ce?.ltp)),
        _strikeCell(context, strike, isAtm),
        _centerCell(_priceText(context, pe?.ltp)),
        if (showGreeks) _centerCell(_ivText(context, pe?.iv, pe?.ivSolverOk)),
        _oiCell(context, pe, isCallSide: false),
        if (showGreeks) _centerCell(_greekText(context, pe?.delta)),
        _centerCell(_pcrText(context, pcr)),
      ],
    );
  }

  DataCell _centerCell(Widget child) => DataCell(Center(child: child));

  DataCell _oiCell(BuildContext context, ChainRow? row, {required bool isCallSide}) {
    final oi = row?.oi ?? 0;
    return DataCell(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTap: row == null
            ? null
            : () => ChainLegBottomSheet.show(context, row),
        onLongPress: row == null
            ? null
            : () => ChainLegBottomSheet.show(context, row),
        child: OIBarCell(value: oi, maxValue: maxOi, isCallSide: isCallSide),
      ),
    );
  }

  DataCell _strikeCell(BuildContext context, double strike, bool isAtm) {
    return DataCell(
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: isAtm
            ? BoxDecoration(
                border: Border(left: BorderSide(color: tokens.accent, width: 2)),
              )
            : null,
        child: Text(
          strike.toStringAsFixed(0),
          style: MyntWebTextStyles.price(
            context,
            color: tokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _priceText(BuildContext context, double? ltp) => Text(
        InstaOptionsFormat.price(ltp),
        style: MyntWebTextStyles.price(
          context,
          color: tokens.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _greekText(BuildContext context, double? value) => Text(
        InstaOptionsFormat.greek(value),
        style: MyntWebTextStyles.tableCell(context, color: tokens.textSecondary),
      );

  Widget _ivText(BuildContext context, double? iv, bool? ivOk) {
    final value = (ivOk == false) ? null : iv;
    return Text(
      InstaOptionsFormat.iv(value),
      style: MyntWebTextStyles.tableCell(context, color: tokens.textSecondary),
    );
  }

  Widget _pcrText(BuildContext context, double pcr) => Text(
        InstaOptionsFormat.pcr(pcr.isFinite ? pcr : null),
        style: MyntWebTextStyles.tableCell(context, color: tokens.textSecondary),
      );
}

class _LoadingState extends StatelessWidget {
  final InstaOptionsTokens tokens;
  const _LoadingState({required this.tokens});
  @override
  Widget build(BuildContext context) => Container(
        color: tokens.bgPrimary,
        child: Center(
          child: CircularProgressIndicator(color: tokens.accent),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final InstaOptionsTokens tokens;
  final Future<void> Function() onRetry;
  const _ErrorState({
    required this.message,
    required this.tokens,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.bgPrimary,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.loss.withValues(alpha: 0.1),
            border: Border.all(color: tokens.loss, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: tokens.loss, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Failed to load chain',
                    style: MyntWebTextStyles.body(
                      context,
                      color: tokens.loss,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: MyntWebTextStyles.caption(
                  context,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final InstaOptionsTokens tokens;
  final Future<void> Function()? onRetry;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.tokens,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.bgPrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: tokens.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: MyntWebTextStyles.head(context, color: tokens.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: MyntWebTextStyles.body(
                context,
                color: tokens.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
