import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;

import '../../../../locator/locator.dart';
import '../../../../locator/preference.dart';
import '../../../../provider/ledger_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/common_search_fields_web.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import '../../../../sharedWidget/custom_back_btn.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../../sharedWidget/snack_bar.dart';
import '../../../../utils/rupee_convert_format.dart';
import 'positions_download_helper.dart';

class PositionScreen extends ConsumerStatefulWidget {
  final String ddd;
  final VoidCallback? onBack;
  const PositionScreen({super.key, required this.ddd, this.onBack});

  @override
  ConsumerState<PositionScreen> createState() => _PositionScreenState();
}

class _PositionScreenState extends ConsumerState<PositionScreen> {
  late ScrollController _horizontalScrollController;
  late ScrollController _tableScrollController;

  // Sorting state
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // P&L / MTM toggle
  bool _showMtm = false;

  // Exchange filter
  Set<String> _selectedExchanges = {};

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _tableScrollController = ScrollController();
    // The search field's X empties the controller without firing onChanged,
    // so reset the query whenever the field becomes empty (same as TC_344).
    _searchController.addListener(() {
      if (!mounted) return;
      if (_searchController.text.isEmpty && _searchQuery.isNotEmpty) {
        setState(() => _searchQuery = '');
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ledger = ref.read(ledgerProvider);
      if (ledger.positiondata == null) {
        ledger.fetchposition(context);
      }
    });
  }

  @override
  void dispose() {
    ref.read(ledgerProvider).ccancelalltimes();
    _horizontalScrollController.dispose();
    _tableScrollController.dispose();
    _hoveredRowIndex.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  List<dynamic> _getFilteredAndSortedList(LDProvider ledger) {
    final posData = ledger.positiondata;
    if (posData == null || posData.data == null) return [];

    List<dynamic> list = List.from(posData.data!);

    // Exchange filter
    if (_selectedExchanges.isNotEmpty) {
      list = list.where((p) {
        final exch = (p.exch?.toString() ?? '').toUpperCase();
        return _selectedExchanges.contains(exch);
      }).toList();
    }

    // Search filter — match what the Instrument cell shows (symbol, expiry,
    // strike/option, e.g. "NIFTY 24 JUL 26 24500 CE") plus the raw tsym and
    // exchange, same as the main Positions search.
    final query = _searchQuery.toLowerCase().trim();
    if (query.isNotEmpty) {
      list = list.where((p) {
        final tsym = p.tsym?.toString() ?? '';
        final parsed = spilitTsym(value: tsym);
        final symbolText = '${parsed["symbol"]}'.replaceAll('-EQ', '');
        final displaySymbol =
            '$symbolText ${parsed["expDate"]} ${parsed["option"]}'.trim();
        final searchable = [
          displaySymbol,
          symbolText,
          '${parsed["expDate"]}',
          '${parsed["option"]}',
          tsym,
          p.exch?.toString() ?? '',
        ];
        return searchable.any((f) => f.toLowerCase().contains(query));
      }).toList();
    }

    // Sorting
    if (_sortColumnIndex != null) {
      list.sort((a, b) {
        int cmp = 0;
        switch (_sortColumnIndex) {
          case 0: // Instrument
            cmp = (a.tsym?.toString() ?? '').compareTo(b.tsym?.toString() ?? '');
            break;
          case 1: // Qty
            cmp = _safeDouble(a.netqty).compareTo(_safeDouble(b.netqty));
            break;
          case 2: // Avg Price
            final aVal = _showMtm ? _safeDouble(a.netavgpricemtm) : _safeDouble(a.netAvgPrc);
            final bVal = _showMtm ? _safeDouble(b.netavgpricemtm) : _safeDouble(b.netAvgPrc);
            cmp = aVal.compareTo(bVal);
            break;
          case 3: // LTP
            cmp = _safeDouble(a.ltp).compareTo(_safeDouble(b.ltp));
            break;
          case 4: // P&L
            final aVal = _showMtm ? _safeDouble(a.rmtm) : _safeDouble(a.rpnl);
            final bVal = _showMtm ? _safeDouble(b.rmtm) : _safeDouble(b.rpnl);
            cmp = aVal.compareTo(bVal);
            break;
          case 5: // Buy Qty
            cmp = _safeDouble(a.buyQuantity).compareTo(_safeDouble(b.buyQuantity));
            break;
          case 6: // Sell Qty
            cmp = _safeDouble(a.sellQuantity).compareTo(_safeDouble(b.sellQuantity));
            break;
          case 7: // Buy Avg
            final aVal = _showMtm ? _safeDouble(a.buypricemtm) : _safeDouble(a.buyPrice);
            final bVal = _showMtm ? _safeDouble(b.buypricemtm) : _safeDouble(b.buyPrice);
            cmp = aVal.compareTo(bVal);
            break;
          case 8: // Buy Amt
            final aVal = _showMtm ? _safeDouble(a.buyvaluemtm) : _safeDouble(a.buyValue);
            final bVal = _showMtm ? _safeDouble(b.buyvaluemtm) : _safeDouble(b.buyValue);
            cmp = aVal.compareTo(bVal);
            break;
          case 9: // Sell Avg
            final aVal = _showMtm ? _safeDouble(a.sellPricemtm) : _safeDouble(a.sellPrice);
            final bVal = _showMtm ? _safeDouble(b.sellPricemtm) : _safeDouble(b.sellPrice);
            cmp = aVal.compareTo(bVal);
            break;
          case 10: // Sell Amt
            final aVal = _showMtm ? _safeDouble(a.sellValuemtm) : _safeDouble(a.sellValue);
            final bVal = _showMtm ? _safeDouble(b.sellValuemtm) : _safeDouble(b.sellValue);
            cmp = aVal.compareTo(bVal);
            break;
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    return list;
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0;
    try {
      return double.tryParse(value.toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // Compute summary values
  Map<String, double> _computeSummary(List<dynamic> positions) {
    double realised = 0, realisedMtm = 0, unrealised = 0, unrealisedMtm = 0;
    for (var p in positions) {
      final netqty = _safeDouble(p.netqty).toInt();
      final rpnl = _safeDouble(p.rpnl);
      final rmtm = _safeDouble(p.rmtm);
      if (netqty == 0) {
        realised += rpnl;
        realisedMtm += rmtm;
      } else {
        unrealised += rpnl;
        unrealisedMtm += rmtm;
      }
    }
    return {
      'realised': realised,
      'realisedMtm': realisedMtm,
      'unrealised': unrealised,
      'unrealisedMtm': unrealisedMtm,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider);
    final theme = ref.watch(themeProvider);

    // Sync toggle with provider
    _showMtm = !ledger.pnlrmtm;

    final posData = ledger.positiondata;
    final allPositions = (posData != null && posData.data != null) ? posData.data! : <dynamic>[];
    final summary = _computeSummary(allPositions);
    final filteredList = _getFilteredAndSortedList(ledger);
    final scriptCount = filteredList.length;

    return SizedBox.expand(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onBack != null) ...[
                _buildHeaderBar(context, theme),
                const SizedBox(height: 12),
              ],
              // Summary cards
              if (allPositions.isNotEmpty)
                _buildSummaryCards(context, summary),
              if (allPositions.isNotEmpty)
                const SizedBox(height: 16),
              // Toolbar: P&L/MTM toggle, search, refresh
              _buildToolbar(context, theme, scriptCount, ledger),
              const SizedBox(height: 16),
              // Table
              Expanded(
                child: ledger.positionloading
                    ? Center(child: MyntLoader.simple())
                    : _buildTable(context, theme, filteredList),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, ThemesProvider theme) {
    return Row(
      children: [
        CustomBackBtn(onBack: () {
          ref.read(ledgerProvider).ccancelalltimes();
          widget.onBack?.call();
        }),
        const SizedBox(width: 8),
        Text(
          'Positions',
          style: MyntWebTextStyles.title(context, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// PDF / Excel download menu. Exports the same filtered + sorted list the
  /// table is showing, in whichever valuation mode (P&L or MTM) is active.
  Widget _buildDownloadButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.download,
          size: 20,
          color: resolveThemeColor(context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.textSecondary)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'Download',
      color: resolveThemeColor(context,
          dark: MyntColors.cardDark, light: MyntColors.card),
      onSelected: (value) {
        final ledger = ref.read(ledgerProvider);
        final positions = _getFilteredAndSortedList(ledger);

        if (positions.isEmpty) {
          warningMessage(context, 'No data to download');
          return;
        }

        final pref = locator<Preferences>();
        final clientId = pref.clientId ?? '';
        final clientName = pref.clientName ?? '';

        if (value == 'pdf') {
          PositionsDownloadHelper.downloadPdf(
            positions: positions,
            clientId: clientId,
            clientName: clientName,
            showMtm: _showMtm,
          );
        } else if (value == 'excel') {
          PositionsDownloadHelper.downloadExcel(
            positions: positions,
            clientId: clientId,
            clientName: clientName,
            showMtm: _showMtm,
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, size: 18, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text('Download PDF',
                  style: TextStyle(
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  )),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'excel',
          child: Row(
            children: [
              Icon(Icons.table_chart, size: 18, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text('Download Excel',
                  style: TextStyle(
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, ThemesProvider theme,
      int scriptCount, LDProvider ledger) {
    return Row(
      children: [
        const Spacer(),
        _buildDownloadButton(context),
        const SizedBox(width: 16),
        // P&L / MTM toggle
        Text(
          'P&L',
          style: MyntWebTextStyles.body(context,
              color: !_showMtm
                  ? resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary)
                  : resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
              fontWeight:
                  !_showMtm ? MyntFonts.semiBold : MyntFonts.medium),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            final newVal = !_showMtm;
            ledger.clickchangemtmandpnl = !newVal;
            setState(() {
              _showMtm = newVal;
            });
          },
          child: Container(
            width: 36,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _showMtm
                  ? resolveThemeColor(context,
                      dark: MyntColors.secondary, light: MyntColors.primary)
                  : resolveThemeColor(context,
                      dark: MyntColors.secondary, light: MyntColors.primary),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  left: _showMtm ? 18 : 2,
                  top: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'MTM',
          style: MyntWebTextStyles.body(context,
              color: _showMtm
                  ? resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary)
                  : resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
              fontWeight:
                  _showMtm ? MyntFonts.semiBold : MyntFonts.medium),
        ),
        const SizedBox(width: 12),
        // Script count
        // Text(
        //   '$scriptCount scripts',
        //   style: MyntWebTextStyles.body(context,
        //       darkColor: MyntColors.textPrimaryDark,
        //       lightColor: MyntColors.textPrimary,
        //       fontWeight: FontWeight.w600),
        // ),
        // const SizedBox(width: 12),
        // Search
        SizedBox(
          width: 220,
          height: 36,
          child: MyntSearchTextField.withSmartClear(
            controller: _searchController,
            placeholder: 'Search',
            leadingIcon: 'assets/icon/search.svg',
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        // Filter button
        // Builder(
        //   builder: (buttonContext) {
        //     return SizedBox(
        //       width: 40,
        //       height: 40,
        //       child: MouseRegion(
        //         cursor: SystemMouseCursors.click,
        //         child: GestureDetector(
        //           onTap: () => _showFilterPopover(buttonContext),
        //           child: Container(
        //             decoration: BoxDecoration(
        //               borderRadius: BorderRadius.circular(8),
        //             ),
        //             child: Center(
        //               child: SvgPicture.asset(
        //                 'assets/icon/search-filter.svg',
        //                 width: 18,
        //                 height: 18,
        //                 colorFilter: ColorFilter.mode(
        //                   resolveThemeColor(context,
        //                       dark: MyntColors.textSecondaryDark,
        //                       light: MyntColors.textSecondary),
        //                   BlendMode.srcIn,
        //                 ),
        //               ),
        //             ),
        //           ),
        //         ),
        //       ),
        //     );
        //   },
        // ),
        // const SizedBox(width: 8),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => ledger.fetchposition(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Icon(
              Icons.refresh,
              size: 20,
              color: resolveThemeColor(context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Filter Popover ─────────────────────────────────────────────────

  void _showFilterPopover(BuildContext context) {
    final ledger = ref.read(ledgerProvider);
    final posData = ledger.positiondata;
    final allPositions = (posData != null && posData.data != null) ? posData.data! : [];
    final availableExchanges = allPositions
        .map((p) {
          try {
            return (p.exch?.toString() ?? '').toUpperCase();
          } catch (_) {
            return '';
          }
        })
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    shadcn.showPopover(
      context: context,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 8),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
      ),
      builder: (popoverContext) {
        return _PositionFilterPopover(
          availableExchanges: availableExchanges,
          selectedExchanges: _selectedExchanges,
          onApply: (selected) {
            setState(() {
              _selectedExchanges = selected;
            });
            shadcn.closeOverlay(popoverContext);
          },
          onClose: () => shadcn.closeOverlay(popoverContext),
        );
      },
    );
  }

  Widget _buildSummaryCards(BuildContext context, Map<String, double> summary) {
    final theme = ref.watch(themeProvider);

    final String netLabel;
    final String realisedLabel;
    final String unrealisedLabel;
    final double realised;
    final double unrealised;

    if (_showMtm) {
      netLabel = 'Net MTM';
      realisedLabel = 'Realised MTM';
      unrealisedLabel = 'Unrealised MTM';
      realised = summary['realisedMtm']!;
      unrealised = summary['unrealisedMtm']!;
    } else {
      netLabel = 'Net Profit/Loss';
      realisedLabel = 'Realised';
      unrealisedLabel = 'Unrealised';
      realised = summary['realised']!;
      unrealised = summary['unrealised']!;
    }

    final netPnl = realised + unrealised;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800 ? 3 : 2;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 115,
          ),
          children: [
            _buildStatCard(
              label: netLabel,
              value: _formatAmount(netPnl),
              valueColor: _getPnlColor(context, netPnl),
              theme: theme,
            ),
            _buildStatCard(
              label: realisedLabel,
              value: _formatAmount(realised),
              valueColor: _getPnlColor(context, realised),
              theme: theme,
            ),
            _buildStatCard(
              label: unrealisedLabel,
              value: _formatAmount(unrealised),
              valueColor: _getPnlColor(context, unrealised),
              theme: theme,
            ),
          ],
        );
      },
    );
  }

  String _formatAmount(double value) {
    return value.toStringAsFixed(2).toIndianRupee(showSign: true);
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color valueColor,
    required ThemesProvider theme,
  }) {
    return shadcn.Theme(
      data: shadcn.Theme.of(context).copyWith(radius: () => 0.3),
      child: shadcn.Card(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              const SizedBox(width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      style: MyntWebTextStyles.head(
                        context,
                        color: valueColor,
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable(
      BuildContext context, ThemesProvider theme, List<dynamic> sortedList) {
    final bool hasData = sortedList.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        // 11 columns. Each column is at least as wide as its header and its
        // widest value, so the instrument name is never cut off. Spare width
        // is shared in the old proportions; when the minimums don't fit, the
        // table scrolls horizontally instead of truncating.
        final widths = _fitColumnWidths(context, totalWidth, sortedList);
        final columnWidths = {
          for (int i = 0; i < widths.length; i++)
            i: shadcn.FixedTableSize(widths[i]),
        };
        // Same as main Positions/Holdings: keep the horizontal scrollbar
        // visible only while the columns are wider than the screen.
        final bool needsHorizontalScroll =
            widths.fold<double>(0, (a, b) => a + b) > totalWidth;

        return Padding(
          padding: EdgeInsets.zero,
          child: shadcn.OutlinedContainer(
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: needsHorizontalScroll,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: totalWidth),
                  child: Column(
                    children: [
                      // Header
                      shadcn.Table(
                        defaultRowHeight: const shadcn.FixedTableSize(50),
                        columnWidths: columnWidths,
                        rows: [
                          shadcn.TableHeader(
                            cells: [
                              _buildHeaderCell('Instrument', 0),
                              _buildHeaderCell('Qty', 1, true),
                              _buildHeaderCell('Avg Price', 2, true),
                              _buildHeaderCell('LTP', 3, true),
                              _buildHeaderCell('P&L', 4, true),
                              _buildHeaderCell('Buy Qty', 5, true),
                              _buildHeaderCell('Sell Qty', 6, true),
                              _buildHeaderCell('Buy Avg', 7, true),
                              _buildHeaderCell('Buy Amt', 8, true),
                              _buildHeaderCell('Sell Avg', 9, true),
                              _buildHeaderCell('Sell Amt', 10, true),
                            ],
                          ),
                        ],
                      ),
                      // Body
                      Expanded(
                        child: hasData
                            ? SingleChildScrollView(
                                controller: _tableScrollController,
                                child: shadcn.Table(
                                  defaultRowHeight:
                                      const shadcn.FixedTableSize(52),
                                  columnWidths: columnWidths,
                                  rows: [
                                    ...sortedList
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final p = entry.value;
                                      return _buildDataRow(
                                          context, index, p);
                                    }),
                                  ],
                                ),
                              )
                            : const Center(
                                child: NoDataFound(
                                  secondaryEnabled: false,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const List<String> _headers = [
    'Instrument', 'Qty', 'Avg Price', 'LTP', 'P&L', 'Buy Qty', 'Sell Qty',
    'Buy Avg', 'Buy Amt', 'Sell Avg', 'Sell Amt',
  ];
  // Previous fixed split - now only used to share out spare width.
  static const List<double> _columnWeights = [
    0.14, 0.06, 0.10, 0.08, 0.10, 0.07, 0.07, 0.09, 0.10, 0.09, 0.10,
  ];

  /// Text of every cell in a row, in column order. [0] is the display
  /// symbol (exchange is drawn after it separately). Shared by the row and
  /// the column-width measurement so they can't disagree.
  List<String> _cellTexts(dynamic p) {
    final parsed = spilitTsym(value: p.tsym?.toString() ?? '');
    final symbolText = '${parsed["symbol"]}'.replaceAll('-EQ', '');
    final displaySymbol =
        '$symbolText ${parsed["expDate"]} ${parsed["option"]}'.trim();
    final netqty = _safeDouble(p.netqty);
    final pnl = _showMtm ? _safeDouble(p.rmtm) : _safeDouble(p.rpnl);
    return [
      displaySymbol,
      netqty > 0 ? '+${netqty.toInt()}' : '${netqty.toInt()}',
      _showMtm ? _fmt(p.netavgpricemtm) : _fmt(p.netAvgPrc),
      _fmt(p.ltp),
      pnl.toStringAsFixed(2),
      (double.tryParse(p.buyQuantity ?? '0') ?? 0).toStringAsFixed(0),
      (double.tryParse(p.sellQuantity ?? '0') ?? 0).toStringAsFixed(0),
      _showMtm ? _fmt(p.buypricemtm) : _fmt(p.buyPrice),
      _showMtm ? _fmt(p.buyvaluemtm) : _fmt(p.buyValue),
      _showMtm ? _fmt(p.sellPricemtm) : _fmt(p.sellPrice),
      _showMtm ? _fmt(p.sellValuemtm) : _fmt(p.sellValue),
    ];
  }

  double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  List<double> _fitColumnWidths(
      BuildContext context, double available, List<dynamic> rows) {
    const sortIcon = 20.0; // 16 icon + 4 gap, shown on the sorted column
    const safety = 4.0; // sub-pixel rounding headroom
    final cellStyle = _getTextStyle(context);
    final nameStyle = _getTextStyle(context, fontWeight: MyntFonts.semiBold);
    final exchStyle = MyntWebTextStyles.caption(context,
        darkColor: MyntColors.textSecondaryDark,
        lightColor: MyntColors.textSecondary);
    final headerStyle = _getHeaderStyle(context);
    final last = _headers.length - 1;

    // Same horizontal padding as _buildHeaderCell / _buildDataCell.
    double headerPad(int i) => i == 0 || i == last ? 24 : 12;
    double cellPad(int i) => i == 0 || i == last ? 28 : 24;

    final mins = List<double>.generate(
        _headers.length,
        (i) =>
            _textWidth(context, _headers[i], headerStyle) +
            sortIcon +
            headerPad(i) +
            safety);

    for (final p in rows) {
      final texts = _cellTexts(p);
      final exchange = p.exch?.toString() ?? '';
      for (int i = 0; i < texts.length; i++) {
        double w = i == 0
            ? _textWidth(context, texts[0], nameStyle) +
                _textWidth(context, ' $exchange', exchStyle)
            : _textWidth(context, texts[i], cellStyle);
        w += cellPad(i) + safety;
        if (w > mins[i]) mins[i] = w;
      }
    }

    final totalMin = mins.fold<double>(0, (a, b) => a + b);
    if (totalMin >= available) return mins; // scrolls horizontally
    final extra = available - totalMin;
    final weightSum = _columnWeights.fold<double>(0, (a, b) => a + b);
    return [
      for (int i = 0; i < mins.length; i++)
        mins[i] + extra * _columnWeights[i] / weightSum,
    ];
  }

  shadcn.TableRow _buildDataRow(
      BuildContext context, int index, dynamic p) {
    final t = _cellTexts(p);
    final exchange = p.exch?.toString() ?? '';
    final displaySymbol = t[0];

    final netqty = _safeDouble(p.netqty);
    final avgPrice = t[2];
    final ltp = t[3];
    final pnl = _showMtm ? _safeDouble(p.rmtm) : _safeDouble(p.rpnl);
    final buyQty = t[5];
    final sellQty = t[6];
    final buyAvg = t[7];
    final buyAmt = t[8];
    final sellAvg = t[9];
    final sellAmt = t[10];

    final qtyColor = netqty > 0
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : netqty < 0
            ? resolveThemeColor(context,
                dark: MyntColors.lossDark, light: MyntColors.loss)
            : null;

    final pnlColor = _getPnlColor(context, pnl);

    return shadcn.TableRow(
      cells: [
        // Instrument
        _buildDataCell(
          rowIndex: index,
          columnIndex: 0,
          child: Tooltip(
            message: '$displaySymbol${exchange.isNotEmpty ? ' $exchange' : ''}',
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: displaySymbol,
                    style: _getTextStyle(context, fontWeight: MyntFonts.semiBold),
                  ),
                  TextSpan(
                    text: ' $exchange',
                    style: MyntWebTextStyles.caption(context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Qty
        _buildDataCell(
          rowIndex: index,
          columnIndex: 1,
          alignRight: true,
          child: Text(
            t[1],
            style: _getTextStyle(context, color: qtyColor),
          ),
        ),
        // Avg Price
        _buildDataCell(
          rowIndex: index,
          columnIndex: 2,
          alignRight: true,
          child: Text(avgPrice, style: _getTextStyle(context)),
        ),
        // LTP
        _buildDataCell(
          rowIndex: index,
          columnIndex: 3,
          alignRight: true,
          child: Text(ltp, style: _getTextStyle(context)),
        ),
        // P&L
        _buildDataCell(
          rowIndex: index,
          columnIndex: 4,
          alignRight: true,
          child: Text(
            t[4],
            style: _getTextStyle(context, color: pnlColor),
          ),
        ),
        // Buy Qty
        _buildDataCell(
          rowIndex: index,
          columnIndex: 5,
          alignRight: true,
          child: Text(buyQty, style: _getTextStyle(context)),
        ),
        // Sell Qty
        _buildDataCell(
          rowIndex: index,
          columnIndex: 6,
          alignRight: true,
          child: Text(sellQty, style: _getTextStyle(context)),
        ),
        // Buy Avg
        _buildDataCell(
          rowIndex: index,
          columnIndex: 7,
          alignRight: true,
          child: Text(buyAvg, style: _getTextStyle(context)),
        ),
        // Buy Amt
        _buildDataCell(
          rowIndex: index,
          columnIndex: 8,
          alignRight: true,
          child: Text(buyAmt, style: _getTextStyle(context)),
        ),
        // Sell Avg
        _buildDataCell(
          rowIndex: index,
          columnIndex: 9,
          alignRight: true,
          child: Text(sellAvg, style: _getTextStyle(context)),
        ),
        // Sell Amt
        _buildDataCell(
          rowIndex: index,
          columnIndex: 10,
          alignRight: true,
          child: Text(sellAmt, style: _getTextStyle(context)),
        ),
      ],
    );
  }

  // --- Helper methods ---

  String _fmt(dynamic value) {
    if (value == null) return '0.00';
    final str = value.toString();
    if (str.isEmpty) return '0.00';
    final v = double.tryParse(str);
    return v != null ? v.toStringAsFixed(2) : str;
  }

  Color _getPnlColor(BuildContext context, double value) {
    if (value > 0) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    } else if (value < 0) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    }
    return resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
  }

  TextStyle _getTextStyle(BuildContext context,
      {Color? color, FontWeight? fontWeight}) {
    return MyntWebTextStyles.tableCell(
      context,
      color: color,
      darkColor: color ?? MyntColors.textPrimaryDark,
      lightColor: color ?? MyntColors.textPrimary,
      fontWeight: fontWeight ?? MyntFonts.medium,
    );
  }

  TextStyle _getHeaderStyle(BuildContext context) {
    return MyntWebTextStyles.tableHeader(
      context,
      darkColor: MyntColors.textSecondaryDark,
      lightColor: MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  shadcn.TableCell _buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 10;

    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding = const EdgeInsets.fromLTRB(16, 0, 8, 0);
    } else if (isLastColumn) {
      headerPadding = const EdgeInsets.fromLTRB(8, 0, 16, 0);
    } else {
      headerPadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 0);
    }

    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: InkWell(
        onTap: () => _onSort(columnIndex),
        child: Container(
          padding: headerPadding,
          alignment:
              alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (alignRight && _sortColumnIndex == columnIndex)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              if (alignRight && _sortColumnIndex == columnIndex)
                const SizedBox(width: 4),
              Text(label, style: _getHeaderStyle(context)),
              if (!alignRight && _sortColumnIndex == columnIndex)
                const SizedBox(width: 4),
              if (!alignRight && _sortColumnIndex == columnIndex)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  shadcn.TableCell _buildDataCell({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 10;

    EdgeInsets cellPadding;
    if (isFirstColumn) {
      cellPadding = const EdgeInsets.fromLTRB(16, 8, 12, 8);
    } else if (isLastColumn) {
      cellPadding = const EdgeInsets.fromLTRB(12, 12, 16, 12);
    } else {
      cellPadding =
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
    }

    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => _hoveredRowIndex.value = rowIndex,
        onExit: (_) => _hoveredRowIndex.value = null,
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredRowIndex,
          builder: (context, hoveredIndex, _) {
            final isRowHovered = hoveredIndex == rowIndex;
            return Container(
              padding: cellPadding,
              color: isRowHovered
                  ? resolveThemeColor(
                      context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary,
                    ).withValues(alpha: 0.08)
                  : null,
              alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
              child: child,
            );
          },
        ),
      ),
    );
  }
}

// ─── Position Filter Popover ───────────────────────────────────────────

class _PositionFilterPopover extends StatefulWidget {
  final List<String> availableExchanges;
  final Set<String> selectedExchanges;
  final void Function(Set<String> selected) onApply;
  final VoidCallback onClose;

  const _PositionFilterPopover({
    required this.availableExchanges,
    required this.selectedExchanges,
    required this.onApply,
    required this.onClose,
  });

  @override
  State<_PositionFilterPopover> createState() => _PositionFilterPopoverState();
}

class _PositionFilterPopoverState extends State<_PositionFilterPopover> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedExchanges);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: shadcn.ModalContainer(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter',
                    style: MyntWebTextStyles.body(context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                        fontWeight: MyntFonts.semiBold),
                  ),
                  InkWell(
                    onTap: widget.onClose,
                    child: Icon(Icons.close,
                        size: 18,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Exchange checkboxes
              ...widget.availableExchanges.map((exch) {
                final isChecked = _selected.contains(exch);
                return _buildFilterCheckbox(exch, isChecked);
              }),
              const SizedBox(height: 8),
              // Apply button
              SizedBox(
                width: double.infinity,
                height: 34,
                child: ElevatedButton(
                  onPressed: () => widget.onApply(_selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Apply',
                      style: MyntWebTextStyles.bodySmall(context,
                          color: Colors.white,
                          fontWeight: MyntFonts.semiBold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCheckbox(String label, bool isChecked) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isChecked) {
              _selected.remove(label);
            } else {
              _selected.add(label);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: isChecked,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selected.add(label);
                      } else {
                        _selected.remove(label);
                      }
                    });
                  },
                  activeColor: resolveThemeColor(context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: MyntWebTextStyles.bodySmall(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                    fontWeight:
                        isChecked ? MyntFonts.semiBold : MyntFonts.medium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
