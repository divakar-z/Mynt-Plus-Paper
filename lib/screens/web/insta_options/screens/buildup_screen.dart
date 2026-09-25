import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/buildup_row.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_buildup_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/buildup_pill.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';

/// OI Buildup screen (README §10.8). Per-contract classification table.
class BuildupScreen extends ConsumerWidget {
  const BuildupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = InstaOptionsTokens.of(context);
    final selection = ref.watch(instaOptionsSelectionProvider).selection;
    final buildup = ref.watch(instaOptionsBuildupProvider);

    if (selection.expiry.isEmpty) {
      return _EmptyState(
        icon: Icons.event_busy,
        title: 'Pick an expiry',
        message: 'Choose an expiry from the bar above to load the buildup view.',
        tokens: tokens,
      );
    }
    if (buildup.loading && buildup.rows.isEmpty) {
      return Container(
        color: tokens.bgPrimary,
        child: Center(child: CircularProgressIndicator(color: tokens.accent)),
      );
    }
    if (buildup.error != null && buildup.rows.isEmpty) {
      return _ErrorState(
        message: buildup.error!,
        tokens: tokens,
        onRetry: buildup.refresh,
      );
    }
    if (buildup.rows.isEmpty) {
      return _EmptyState(
        icon: Icons.layers,
        title: 'No buildup data',
        message: 'Try a different expiry, or retry once the backend has data.',
        tokens: tokens,
        onRetry: buildup.refresh,
      );
    }

    final rows = buildup.visible;
    return Container(
      color: tokens.bgPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ControlBar(buildup: buildup, count: rows.length, tokens: tokens),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _BuildupTable(rows: rows, tokens: tokens),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  final InstaOptionsBuildupProvider buildup;
  final int count;
  final InstaOptionsTokens tokens;

  const _ControlBar({
    required this.buildup,
    required this.count,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          SegmentedButton<BuildupFilter>(
            segments: const [
              ButtonSegment(value: BuildupFilter.all, label: Text('All')),
              ButtonSegment(value: BuildupFilter.ce, label: Text('CE')),
              ButtonSegment(value: BuildupFilter.pe, label: Text('PE')),
              ButtonSegment(value: BuildupFilter.fut, label: Text('FUT')),
            ],
            selected: {buildup.filter},
            onSelectionChanged: (s) => buildup.setFilter(s.first),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              foregroundColor: tokens.textSecondary,
              selectedForegroundColor: tokens.textPrimary,
              selectedBackgroundColor: tokens.bgTertiary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const Spacer(),
          Text(
            'Sort:',
            style: MyntWebTextStyles.caption(
              context,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<BuildupSort>(
              value: buildup.sort,
              isDense: true,
              dropdownColor: tokens.bgSecondary,
              icon: Icon(
                Icons.expand_more,
                color: tokens.textSecondary,
                size: 16,
              ),
              items: const [
                DropdownMenuItem(
                  value: BuildupSort.oiChangeDesc,
                  child: Text('|ΔOI| desc'),
                ),
                DropdownMenuItem(
                  value: BuildupSort.strikeAsc,
                  child: Text('Strike asc'),
                ),
              ],
              onChanged: (v) => v == null ? null : buildup.setSort(v),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$count contracts',
            style: MyntWebTextStyles.caption(
              context,
              color: tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildupTable extends StatelessWidget {
  final List<BuildupRow> rows;
  final InstaOptionsTokens tokens;

  const _BuildupTable({required this.rows, required this.tokens});

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
        columnSpacing: 8,
        horizontalMargin: 12,
        dataRowHeight: 36,
        headingRowHeight: 40,
        minWidth: 1000,
        headingTextStyle: MyntWebTextStyles.para(
          context,
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        headingRowColor: WidgetStateProperty.all(tokens.bgTertiary),
        dataTextStyle:
            MyntWebTextStyles.tableCell(context, color: tokens.textPrimary),
        dividerThickness: 0.5,
        columns: const [
          DataColumn2(label: Text('Symbol'), size: ColumnSize.L),
          DataColumn2(label: Text('Type'), fixedWidth: 60),
          DataColumn2(label: Text('Strike'), fixedWidth: 90, numeric: true),
          DataColumn2(label: Text('LTP'), fixedWidth: 90, numeric: true),
          DataColumn2(label: Text('ΔLTP %'), fixedWidth: 90, numeric: true),
          DataColumn2(label: Text('OI'), fixedWidth: 110, numeric: true),
          DataColumn2(label: Text('ΔOI'), fixedWidth: 110, numeric: true),
          DataColumn2(label: Text('Buildup'), fixedWidth: 140),
        ],
        rows: rows.map((r) => _row(context, r)).toList(growable: false),
      ),
    );
  }

  DataRow2 _row(BuildContext context, BuildupRow r) {
    final priceCol = r.priceChange == 0
        ? tokens.textSecondary
        : (r.priceChange > 0 ? tokens.profit : tokens.loss);
    final oiCol = r.oiChange == 0
        ? tokens.textSecondary
        : (r.oiChange > 0 ? tokens.profit : tokens.loss);

    return DataRow2(
      cells: [
        DataCell(
          Text(
            r.tradingSymbol,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(Text(r.optionType)),
        DataCell(Text(r.strike == 0 ? '—' : r.strike.toStringAsFixed(0))),
        DataCell(Text(InstaOptionsFormat.price(r.closePrice))),
        DataCell(
          Text(
            InstaOptionsFormat.changePct(r.priceChangePct),
            style: MyntWebTextStyles.tableCell(context, color: priceCol),
          ),
        ),
        DataCell(Text(InstaOptionsFormat.oi(r.closeOi))),
        DataCell(
          Text(
            r.oiChange == 0
                ? '0'
                : '${r.oiChange > 0 ? '+' : ''}${InstaOptionsFormat.oi(r.oiChange.abs())}',
            style: MyntWebTextStyles.tableCell(context, color: oiCol),
          ),
        ),
        DataCell(BuildupPill(kind: r.buildup)),
      ],
    );
  }
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
    // App-standard error state (same widget Positions / Holdings / Scanner
    // use) instead of the bespoke red panel.
    return Container(
      color: tokens.bgPrimary,
      child: Center(
        child: NoDataFoundWeb(
          title: 'Failed to load buildup',
          subtitle: message,
          primaryEnabled: true,
          onPrimary: onRetry,
          primaryLabel: 'Retry',
          secondaryEnabled: false,
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
