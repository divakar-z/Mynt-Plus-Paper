class Symbol {
  final String ticker;
  final String ySymbol;
  final String? isin;
  final String name;
  final String series;
  final bool isActive;
  final String? historyStart;
  final String? historyEnd;

  const Symbol({
    required this.ticker,
    required this.ySymbol,
    required this.isin,
    required this.name,
    required this.series,
    required this.isActive,
    required this.historyStart,
    required this.historyEnd,
  });

  factory Symbol.fromJson(Map<String, dynamic> j) => Symbol(
        ticker: j['ticker'] as String,
        ySymbol: (j['y_symbol'] ?? '') as String,
        isin: j['isin'] as String?,
        name: (j['name'] ?? '') as String,
        series: (j['series'] ?? 'EQ') as String,
        isActive: (j['is_active'] ?? true) as bool,
        historyStart: j['history_start'] as String?,
        historyEnd: j['history_end'] as String?,
      );
}

class SymbolListResponse {
  final List<Symbol> items;
  final int total;
  final int page;
  final int pageSize;

  const SymbolListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory SymbolListResponse.fromJson(Map<String, dynamic> j) =>
      SymbolListResponse(
        items: (j['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(Symbol.fromJson)
            .toList(),
        total: (j['total'] ?? 0) as int,
        page: (j['page'] ?? 1) as int,
        pageSize: (j['page_size'] ?? 50) as int,
      );
}
