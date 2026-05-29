import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/contributor_row.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_contributors_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Index Contributors screen (README §10.2). Per-index per-stock breakdown
/// with Stock/Sector views, sortable columns, and live `Sum: ±N.NN points`.
class IndexContributorsScreen extends ConsumerStatefulWidget {
  const IndexContributorsScreen({super.key});

  @override
  ConsumerState<IndexContributorsScreen> createState() =>
      _IndexContributorsScreenState();
}

enum _ViewMode { stock, sector }

enum _StockSortKey { stock, sector, ltp, changePct, indexPoints }

enum _SectorSortKey { sector, avgChangePct, totalIndexPoints }

class _IndexContributorsScreenState
    extends ConsumerState<IndexContributorsScreen> {
  _ViewMode _mode = _ViewMode.stock;
  _StockSortKey _stockSort = _StockSortKey.indexPoints;
  _SectorSortKey _sectorSort = _SectorSortKey.totalIndexPoints;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(instaOptionsContributorsProvider).start();
    });
  }

  @override
  void dispose() {
    ref.read(instaOptionsContributorsProvider).stop();
    super.dispose();
  }

  void _toggleStockSort(_StockSortKey key) {
    setState(() {
      if (_stockSort == key) {
        _ascending = !_ascending;
      } else {
        _stockSort = key;
        _ascending = false;
      }
    });
  }

  void _toggleSectorSort(_SectorSortKey key) {
    setState(() {
      if (_sectorSort == key) {
        _ascending = !_ascending;
      } else {
        _sectorSort = key;
        _ascending = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final provider = ref.watch(instaOptionsContributorsProvider);
    final rows = provider.rows;
    final sumPts = rows.fold<double>(0, (s, r) => s + r.indexPoints);

    return Container(
      color: tokens.bgPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IndexTabs(
            indices: InstaOptionsContributorsProvider.supportedIndices,
            active: provider.activeIndex,
            onSelect: (i) => provider.setActiveIndex(i),
            tokens: tokens,
          ),
          _Controls(
            mode: _mode,
            onModeChange: (m) => setState(() => _mode = m),
            sumPts: sumPts,
            loading: provider.loading,
            onRefresh: provider.refresh,
            tokens: tokens,
          ),
          Expanded(
            child: _Body(
              provider: provider,
              mode: _mode,
              stockSort: _stockSort,
              sectorSort: _sectorSort,
              ascending: _ascending,
              onStockSort: _toggleStockSort,
              onSectorSort: _toggleSectorSort,
              tokens: tokens,
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexTabs extends StatelessWidget {
  final List<String> indices;
  final String active;
  final ValueChanged<String> onSelect;
  final InstaOptionsTokens tokens;

  const _IndexTabs({
    required this.indices,
    required this.active,
    required this.onSelect,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border(bottom: BorderSide(color: tokens.border, width: 1)),
      ),
      child: Row(
        children: indices
            .map((i) => _Tab(
                  name: i,
                  isActive: i == active,
                  onTap: () => onSelect(i),
                  tokens: tokens,
                ))
            .toList(growable: false),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final String name;
  final bool isActive;
  final VoidCallback onTap;
  final InstaOptionsTokens tokens;

  const _Tab({
    required this.name,
    required this.isActive,
    required this.onTap,
    required this.tokens,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 3,
                color: widget.isActive ? tokens.accent : Colors.transparent,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.name,
            style: MyntWebTextStyles.body(
              context,
              color: color,
              fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final _ViewMode mode;
  final ValueChanged<_ViewMode> onModeChange;
  final double sumPts;
  final bool loading;
  final Future<void> Function() onRefresh;
  final InstaOptionsTokens tokens;

  const _Controls({
    required this.mode,
    required this.onModeChange,
    required this.sumPts,
    required this.loading,
    required this.onRefresh,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final sumColor = sumPts == 0
        ? tokens.textSecondary
        : (sumPts > 0 ? tokens.profit : tokens.loss);
    final sumLabel = sumPts == 0
        ? '0.00 points'
        : '${sumPts > 0 ? '+' : '−'}${sumPts.abs().toStringAsFixed(2)} points';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          SegmentedButton<_ViewMode>(
            segments: const [
              ButtonSegment(value: _ViewMode.stock, label: Text('Stock')),
              ButtonSegment(value: _ViewMode.sector, label: Text('Sector')),
            ],
            selected: {mode},
            onSelectionChanged: (s) => onModeChange(s.first),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              foregroundColor: tokens.textSecondary,
              selectedForegroundColor: tokens.textPrimary,
              selectedBackgroundColor: tokens.bgTertiary,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const Spacer(),
          Text(
            'Sum: ',
            style: MyntWebTextStyles.body(
              context,
              color: tokens.textSecondary,
            ),
          ),
          Text(
            sumLabel,
            style: MyntWebTextStyles.head(context, color: sumColor),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final InstaOptionsContributorsProvider provider;
  final _ViewMode mode;
  final _StockSortKey stockSort;
  final _SectorSortKey sectorSort;
  final bool ascending;
  final ValueChanged<_StockSortKey> onStockSort;
  final ValueChanged<_SectorSortKey> onSectorSort;
  final InstaOptionsTokens tokens;

  const _Body({
    required this.provider,
    required this.mode,
    required this.stockSort,
    required this.sectorSort,
    required this.ascending,
    required this.onStockSort,
    required this.onSectorSort,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.loading && provider.rows.isEmpty) {
      return Center(child: CircularProgressIndicator(color: tokens.accent));
    }
    if (provider.error != null && provider.rows.isEmpty) {
      return _Error(message: provider.error!, onRetry: provider.refresh, tokens: tokens);
    }
    if (provider.rows.isEmpty) {
      return _Empty(
        message: 'No constituents for ${provider.activeIndex}',
        tokens: tokens,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.bgSecondary,
          border: Border.all(color: tokens.border, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: mode == _ViewMode.stock
            ? _StockTable(
                rows: _sortedStocks(provider.rows),
                tokens: tokens,
                sortKey: stockSort,
                ascending: ascending,
                onSort: onStockSort,
              )
            : _SectorTable(
                rows: _sortedSectors(SectorAggregate.from(provider.rows)),
                tokens: tokens,
                sortKey: sectorSort,
                ascending: ascending,
                onSort: onSectorSort,
              ),
      ),
    );
  }

  List<ContributorRow> _sortedStocks(List<ContributorRow> rows) {
    final sorted = [...rows];
    int cmpDouble(double a, double b) => a.compareTo(b);
    sorted.sort((a, b) {
      int order;
      switch (stockSort) {
        case _StockSortKey.stock:
          order = a.stock.compareTo(b.stock);
          break;
        case _StockSortKey.sector:
          order = a.sector.compareTo(b.sector);
          break;
        case _StockSortKey.ltp:
          order = cmpDouble(a.ltp, b.ltp);
          break;
        case _StockSortKey.changePct:
          order = cmpDouble(a.changePct, b.changePct);
          break;
        case _StockSortKey.indexPoints:
          order = cmpDouble(a.indexPoints.abs(), b.indexPoints.abs());
          break;
      }
      return ascending ? order : -order;
    });
    return sorted;
  }

  List<SectorAggregate> _sortedSectors(List<SectorAggregate> rows) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      int order;
      switch (sectorSort) {
        case _SectorSortKey.sector:
          order = a.sector.compareTo(b.sector);
          break;
        case _SectorSortKey.avgChangePct:
          order = a.avgChangePct.compareTo(b.avgChangePct);
          break;
        case _SectorSortKey.totalIndexPoints:
          order = a.totalIndexPoints.abs().compareTo(b.totalIndexPoints.abs());
          break;
      }
      return ascending ? order : -order;
    });
    return sorted;
  }
}

class _StockTable extends StatelessWidget {
  final List<ContributorRow> rows;
  final InstaOptionsTokens tokens;
  final _StockSortKey sortKey;
  final bool ascending;
  final ValueChanged<_StockSortKey> onSort;

  const _StockTable({
    required this.rows,
    required this.tokens,
    required this.sortKey,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable2(
      columnSpacing: 8,
      horizontalMargin: 16,
      dataRowHeight: 36,
      headingRowHeight: 40,
      minWidth: 800,
      headingTextStyle: MyntWebTextStyles.para(
        context,
        color: tokens.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      headingRowColor: WidgetStateProperty.all(tokens.bgTertiary),
      dataTextStyle:
          MyntWebTextStyles.tableCell(context, color: tokens.textPrimary),
      dividerThickness: 0.5,
      columns: [
        _col('Company', _StockSortKey.stock, ColumnSize.L),
        _col('Sector', _StockSortKey.sector, ColumnSize.M),
        _col('LTP', _StockSortKey.ltp, ColumnSize.S, numeric: true),
        _col('Change %', _StockSortKey.changePct, ColumnSize.S, numeric: true),
        _col('Index Pts', _StockSortKey.indexPoints, ColumnSize.S, numeric: true),
      ],
      rows: rows.map((r) => _row(context, r)).toList(growable: false),
    );
  }

  DataColumn2 _col(String label, _StockSortKey key, ColumnSize size, {bool numeric = false}) {
    final isActive = sortKey == key;
    return DataColumn2(
      size: size,
      numeric: numeric,
      onSort: (_, __) => onSort(key),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isActive)
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: tokens.accent,
            ),
        ],
      ),
    );
  }

  DataRow2 _row(BuildContext context, ContributorRow r) {
    final chgCol = r.changePct == 0
        ? tokens.textSecondary
        : (r.changePct > 0 ? tokens.profit : tokens.loss);
    final ptsCol = r.indexPoints == 0
        ? tokens.textSecondary
        : (r.indexPoints > 0 ? tokens.profit : tokens.loss);
    return DataRow2(
      cells: [
        DataCell(
          Text(
            r.stock,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          Text(
            r.sector.isEmpty ? '—' : r.sector,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(Text(InstaOptionsFormat.price(r.ltp))),
        DataCell(
          Text(
            InstaOptionsFormat.changePct(r.changePct),
            style: MyntWebTextStyles.tableCell(context, color: chgCol),
          ),
        ),
        DataCell(
          Text(
            _formatPoints(r.indexPoints),
            style: MyntWebTextStyles.tableCell(context, color: ptsCol),
          ),
        ),
      ],
    );
  }
}

class _SectorTable extends StatelessWidget {
  final List<SectorAggregate> rows;
  final InstaOptionsTokens tokens;
  final _SectorSortKey sortKey;
  final bool ascending;
  final ValueChanged<_SectorSortKey> onSort;

  const _SectorTable({
    required this.rows,
    required this.tokens,
    required this.sortKey,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable2(
      columnSpacing: 8,
      horizontalMargin: 16,
      dataRowHeight: 40,
      headingRowHeight: 40,
      minWidth: 700,
      headingTextStyle: MyntWebTextStyles.para(
        context,
        color: tokens.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      headingRowColor: WidgetStateProperty.all(tokens.bgTertiary),
      dataTextStyle:
          MyntWebTextStyles.tableCell(context, color: tokens.textPrimary),
      dividerThickness: 0.5,
      columns: [
        _col('Sector', _SectorSortKey.sector, ColumnSize.L),
        _col('Avg Change %', _SectorSortKey.avgChangePct, ColumnSize.M, numeric: true),
        _col('Total Pts', _SectorSortKey.totalIndexPoints, ColumnSize.M, numeric: true),
      ],
      rows: rows.map((r) => _row(context, r)).toList(growable: false),
    );
  }

  DataColumn2 _col(String label, _SectorSortKey key, ColumnSize size, {bool numeric = false}) {
    final isActive = sortKey == key;
    return DataColumn2(
      size: size,
      numeric: numeric,
      onSort: (_, __) => onSort(key),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isActive)
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: tokens.accent,
            ),
        ],
      ),
    );
  }

  DataRow2 _row(BuildContext context, SectorAggregate r) {
    final chgCol = r.avgChangePct == 0
        ? tokens.textSecondary
        : (r.avgChangePct > 0 ? tokens.profit : tokens.loss);
    final ptsCol = r.totalIndexPoints == 0
        ? tokens.textSecondary
        : (r.totalIndexPoints > 0 ? tokens.profit : tokens.loss);
    return DataRow2(
      cells: [
        DataCell(
          Row(
            children: [
              Expanded(
                child: Text(
                  r.sector,
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${r.constituentCount})',
                style: MyntWebTextStyles.caption(
                  context,
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            InstaOptionsFormat.changePct(r.avgChangePct),
            style: MyntWebTextStyles.tableCell(context, color: chgCol),
          ),
        ),
        DataCell(
          Text(
            _formatPoints(r.totalIndexPoints),
            style: MyntWebTextStyles.tableCell(context, color: ptsCol),
          ),
        ),
      ],
    );
  }
}

String _formatPoints(double value) {
  if (value == 0) return '0.00';
  final sign = value > 0 ? '+' : '−';
  return '$sign${value.abs().toStringAsFixed(2)}';
}

class _Empty extends StatelessWidget {
  final String message;
  final InstaOptionsTokens tokens;

  const _Empty({required this.message, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: MyntWebTextStyles.body(context, color: tokens.textSecondary),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  final InstaOptionsTokens tokens;

  const _Error({
    required this.message,
    required this.onRetry,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 480),
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
                  'Failed to load contributors',
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
    );
  }
}
