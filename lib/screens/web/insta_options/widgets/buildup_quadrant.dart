import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/buildup_symbol.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// One of the four buildup quadrants in the Markets Dashboard (README §10.1).
///
/// Card with a coloured icon header + DataTable2 of rows sorted by
/// `|oi_change|` desc. Tap a row → caller switches the side-rail to the
/// Option Chain pre-loaded with the row's symbol.
class BuildupQuadrant extends StatelessWidget {
  final BuildupBucket bucket;
  final List<BuildupSymbol> rows;
  final void Function(BuildupSymbol row) onRowTap;

  const BuildupQuadrant({
    super.key,
    required this.bucket,
    required this.rows,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final accent = _bucketColor(tokens);
    final sorted = [...rows]
      ..sort((a, b) => b.oiChange.abs().compareTo(a.oiChange.abs()));

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
            bucket: bucket,
            accent: accent,
            count: sorted.length,
            tokens: tokens,
          ),
          Expanded(
            child: sorted.isEmpty
                ? _Empty(tokens: tokens)
                : _Table(
                    rows: sorted,
                    accent: accent,
                    tokens: tokens,
                    onRowTap: onRowTap,
                  ),
          ),
        ],
      ),
    );
  }

  Color _bucketColor(InstaOptionsTokens tokens) {
    switch (bucket) {
      case BuildupBucket.longBuildup:
        return tokens.profit;
      case BuildupBucket.shortBuildup:
        return tokens.loss;
      case BuildupBucket.shortCovering:
        return tokens.info;
      case BuildupBucket.longUnwinding:
        return tokens.warning;
    }
  }
}

IconData _bucketIcon(BuildupBucket b) {
  switch (b) {
    case BuildupBucket.longBuildup:
      return Icons.trending_up;
    case BuildupBucket.shortBuildup:
      return Icons.trending_down;
    case BuildupBucket.shortCovering:
      return Icons.refresh;
    case BuildupBucket.longUnwinding:
      return Icons.exit_to_app;
  }
}

class _Header extends StatelessWidget {
  final BuildupBucket bucket;
  final Color accent;
  final int count;
  final InstaOptionsTokens tokens;

  const _Header({
    required this.bucket,
    required this.accent,
    required this.count,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: tokens.bgTertiary,
        border: Border(bottom: BorderSide(color: tokens.border, width: 1)),
      ),
      child: Row(
        children: [
          Icon(_bucketIcon(bucket), size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bucket.display,
              style: MyntWebTextStyles.head(
                context,
                color: tokens.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$count',
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

class _Empty extends StatelessWidget {
  final InstaOptionsTokens tokens;
  const _Empty({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No symbols in this bucket right now.',
          style: MyntWebTextStyles.caption(
            context,
            color: tokens.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  final List<BuildupSymbol> rows;
  final Color accent;
  final InstaOptionsTokens tokens;
  final void Function(BuildupSymbol row) onRowTap;

  const _Table({
    required this.rows,
    required this.accent,
    required this.tokens,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable2(
      columnSpacing: 6,
      horizontalMargin: 12,
      dataRowHeight: 36,
      headingRowHeight: 36,
      minWidth: 340,
      headingTextStyle: MyntWebTextStyles.para(
        context,
        color: tokens.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      headingRowColor: WidgetStateProperty.all(tokens.bgSecondary),
      dataTextStyle:
          MyntWebTextStyles.tableCell(context, color: tokens.textPrimary),
      dividerThickness: 0.5,
      columns: const [
        DataColumn2(label: Text('Symbol'), size: ColumnSize.L),
        DataColumn2(label: Text('LTP'), fixedWidth: 60, numeric: true),
        DataColumn2(label: Text('Chg %'), fixedWidth: 60, numeric: true),
        DataColumn2(label: Text('ΔOI'), fixedWidth: 70, numeric: true),
        DataColumn2(label: Text('ΔOI %'), fixedWidth: 60, numeric: true),
      ],
      rows: rows.map((r) => _row(context, r)).toList(growable: false),
    );
  }

  DataRow2 _row(BuildContext context, BuildupSymbol r) {
    final priceCol = r.changePct == 0
        ? tokens.textSecondary
        : (r.changePct > 0 ? tokens.profit : tokens.loss);
    final oiCol = r.oiChange == 0
        ? tokens.textSecondary
        : (r.oiChange > 0 ? tokens.profit : tokens.loss);
    return DataRow2(
      onTap: () => onRowTap(r),
      cells: [
        DataCell(
          Text(
            r.symbol,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(Text(InstaOptionsFormat.price(r.ltp))),
        DataCell(
          Text(
            InstaOptionsFormat.changePct(r.changePct),
            style: MyntWebTextStyles.tableCell(context, color: priceCol),
          ),
        ),
        DataCell(
          Text(
            r.oiChange == 0
                ? '0'
                : '${r.oiChange > 0 ? '+' : '-'}${InstaOptionsFormat.oi(r.oiChange.abs())}',
            style: MyntWebTextStyles.tableCell(context, color: oiCol),
          ),
        ),
        DataCell(
          Text(
            InstaOptionsFormat.changePct(r.oiChangePct),
            style: MyntWebTextStyles.tableCell(context, color: oiCol),
          ),
        ),
      ],
    );
  }
}
