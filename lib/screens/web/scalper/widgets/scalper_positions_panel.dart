import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../../models/order_book_model/gtt_order_book.dart';
import '../../../../models/order_book_model/order_book_model.dart';
import '../../../../models/order_book_model/place_gtt_order.dart';
import '../../../../models/portfolio_model/position_book_model.dart';
import '../../../../provider/order_provider.dart';
import '../../../../provider/portfolio_provider.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../../res/assets.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../sharedWidget/common_buttons_web.dart';
import '../../../../sharedWidget/common_text_fields_web.dart';
import '../../../../sharedWidget/no_data_found_web.dart';
import '../../../../utils/responsive_snackbar.dart';
import '../../position/group/position_group_screen_web.dart';
import '../scalper_provider.dart';

final _assets = Assets();

/// Positions and Orders panel at the bottom of the scalper screen
/// Supports collapse/expand and drag-to-resize
class ScalperPositionsPanel extends ConsumerStatefulWidget {
  const ScalperPositionsPanel({super.key});

  @override
  ConsumerState<ScalperPositionsPanel> createState() =>
      _ScalperPositionsPanelState();
}

class _ScalperPositionsPanelState extends ConsumerState<ScalperPositionsPanel> {
  int _selectedTabIndex = 0;
  bool _isGrouped = false;
  bool _isDragging = false;
  String _selectedOrderFilter = 'All';

  final ScrollController _positionsScrollController = ScrollController();
  final ScrollController _ordersScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scalperProvider).fetchGttOrders(context);
    });
  }

  @override
  void dispose() {
    _positionsScrollController.dispose();
    _ordersScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCollapsed = ref.watch(scalperProvider.select((s) => s.isPositionsPanelCollapsed));
    final positionFilter = ref.watch(scalperProvider.select((s) => s.positionFilter));
    // Use .select() on list reference so LTP ticks (in-place mutations) don't trigger rebuild
    final allPositionsList = ref.watch(portfolioProvider.select((p) => p.allPostionList));

    // Show ALL positions (open + closed), apply position filter
    final rawPositions = allPositionsList;
    final allPositions = positionFilter == 'fno'
        ? rawPositions
            .where((p) =>
                p.exch == 'NFO' || p.exch == 'BFO' || p.exch == 'MCX')
            .toList()
        : rawPositions;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle at the top
        _buildDragHandle(context, allPositions, isCollapsed),
        // Main content (collapsible)
        if (!isCollapsed)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.backgroundColorDark,
                  light: MyntColors.backgroundColor,
                ),
              ),
              child: Column(
                children: [
                  // Header with tabs and actions
                  _buildHeader(context, allPositions.length),
                  // Content
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        // Positions tab - show groups view or regular list (with footer included)
                        _isGrouped
                            ? const PositionGroupScreen()
                            : _buildPositionsListWithFooter(context, allPositions),
                        // Orders tab
                        _buildOrdersList(context, ref),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Drag handle for resizing the panel
  Widget _buildDragHandle(BuildContext context, List<PositionBookModel> allPositions, bool isCollapsed) {
    final scalper = ref.read(scalperProvider);

    // Count open positions (non-zero qty)
    final openCount = allPositions.where((p) => (int.tryParse(p.qty ?? '0') ?? 0) != 0).length;

    return GestureDetector(
      onVerticalDragStart: (_) {
        setState(() => _isDragging = true);
      },
      onVerticalDragUpdate: (details) {
        final newHeight = scalper.positionsPanelHeight - details.delta.dy;
        if (newHeight < ScalperProvider.minPanelHeight && !isCollapsed) {
          ref.read(scalperProvider).collapsePositionsPanel();
        } else if (isCollapsed && details.delta.dy < -5) {
          ref.read(scalperProvider).expandPositionsPanel();
        } else if (!isCollapsed) {
          ref.read(scalperProvider).setPositionsPanelHeight(newHeight);
        }
      },
      onVerticalDragEnd: (_) {
        setState(() => _isDragging = false);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: resolveThemeColor(
              context,
              dark: _isDragging
                  ? MyntColors.primaryDark.withValues(alpha: 0.08)
                  : MyntColors.backgroundColorDark,
              light: _isDragging
                  ? MyntColors.primary.withValues(alpha: 0.05)
                  : MyntColors.backgroundColor,
            ),
            border: Border(
              top: BorderSide(
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.dividerDark,
                  light: MyntColors.divider,
                ),
              ),
            ),
          ),
          child: Stack(
            children: [
              // Drag indicator centered
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.dividerDark,
                      light: MyntColors.divider,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Content row on top
              Row(
                children: [
                  // Show P&L summary only when collapsed
                  if (isCollapsed) ...[
                    const SizedBox(width: 16),
                    Text(
                      'Positions',
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: MyntFonts.medium,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                      ),
                    ),
                    if (openCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: resolveThemeColor(context,
                              dark: MyntColors.primaryDark,
                              light: MyntColors.primary).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$openCount',
                          style: MyntWebTextStyles.caption(
                            context,
                            fontWeight: MyntFonts.semiBold,
                            color: resolveThemeColor(context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 16),
                    // P&L chip — Consumer for live updates without full rebuild
                    Consumer(builder: (context, ref, _) {
                      final livePnL = ref.watch(portfolioProvider.select((_) {
                        double t = 0;
                        for (final pos in allPositions) {
                          t += double.tryParse(pos.profitNloss ?? '0') ?? 0;
                        }
                        return t;
                      }));
                      final isPositive = livePnL >= 0;
                      final pnlColor = isPositive
                          ? resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit)
                          : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: pnlColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'P&L',
                              style: MyntWebTextStyles.body(
                                context,
                                fontWeight: MyntFonts.medium,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${isPositive ? '+' : ''}${livePnL.toStringAsFixed(2)}',
                              style: MyntWebTextStyles.body(
                                context,
                                fontWeight: MyntFonts.semiBold,
                                color: pnlColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const Spacer(),
                  // Collapse/Expand button
                  InkWell(
                    onTap: () => ref.read(scalperProvider).togglePositionsPanel(),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        isCollapsed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 20,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int posCount) {
    final orders = ref.watch(orderProvider);
    final allOrders = orders.allOrder ?? [];
    final openOrders = orders.openOrder ?? [];
    final hasOpenOrders = openOrders.isNotEmpty;

    // Count open positions (non-zero qty, not BO/CO)
    // Use ref.read() — parent already watches list reference via .select(), so header
    // rebuilds when positions are added/removed but NOT on every LTP tick
    final portfolio = ref.read(portfolioProvider);
    final openPositions = portfolio.allPostionList
        .where((p) =>
            (int.tryParse(p.qty ?? '0') ?? 0) != 0 &&
            p.sPrdtAli != 'BO' &&
            p.sPrdtAli != 'CO')
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Tabs (matching holdings/positions page pattern)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Positions tab
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    if (mounted && _selectedTabIndex != 0) {
                      setState(() => _selectedTabIndex = 0);
                      ref.read(scalperProvider).fetchGttOrders(context);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedTabIndex == 0
                          ? (isDarkMode(context)
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Positions',
                          style: MyntWebTextStyles.body(
                            context,
                            fontWeight: _selectedTabIndex == 0
                                ? MyntFonts.semiBold
                                : MyntFonts.medium,
                          ).copyWith(
                            color: _selectedTabIndex == 0
                                ? shadcn.Theme.of(context).colorScheme.foreground
                                : shadcn.Theme.of(context).colorScheme.mutedForeground,
                          ),
                        ),
                        if (posCount > 0) ...[
                          const SizedBox(width: 4),
                          Transform.translate(
                            offset: const Offset(0, -6),
                            child: Text(
                              '$posCount',
                              style: MyntWebTextStyles.bodySmall(
                                context,
                                fontWeight: _selectedTabIndex == 0
                                    ? MyntFonts.semiBold
                                    : MyntFonts.medium,
                              ).copyWith(
                                fontSize: 12,
                                color: _selectedTabIndex == 0
                                    ? shadcn.Theme.of(context).colorScheme.foreground
                                    : shadcn.Theme.of(context).colorScheme.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Orders tab
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    if (mounted && _selectedTabIndex != 1) {
                      setState(() => _selectedTabIndex = 1);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedTabIndex == 1
                          ? (isDarkMode(context)
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Orders',
                          style: MyntWebTextStyles.body(
                            context,
                            fontWeight: _selectedTabIndex == 1
                                ? MyntFonts.semiBold
                                : MyntFonts.medium,
                          ).copyWith(
                            color: _selectedTabIndex == 1
                                ? shadcn.Theme.of(context).colorScheme.foreground
                                : shadcn.Theme.of(context).colorScheme.mutedForeground,
                          ),
                        ),
                        if (openOrders.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Transform.translate(
                            offset: const Offset(0, -6),
                            child: Text(
                              '${openOrders.length}',
                              style: MyntWebTextStyles.bodySmall(
                                context,
                                fontWeight: _selectedTabIndex == 1
                                    ? MyntFonts.semiBold
                                    : MyntFonts.medium,
                              ).copyWith(
                                fontSize: 12,
                                color: _selectedTabIndex == 1
                                    ? shadcn.Theme.of(context).colorScheme.foreground
                                    : shadcn.Theme.of(context).colorScheme.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Position Groups icon (only on Positions tab)
          if (_selectedTabIndex == 0) ...[
            Tooltip(
              message: _isGrouped ? 'Show Positions' : 'Show Position Groups',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () => setState(() => _isGrouped = !_isGrouped),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: _isGrouped
                        ? BoxDecoration(
                            color: resolveThemeColor(context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          )
                        : null,
                    child: SvgPicture.asset(
                      _assets.posgrp,
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        _isGrouped
                            ? resolveThemeColor(context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary)
                            : resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Order filter dropdown (only on Orders tab)
          if (_selectedTabIndex == 1) ...[
            _buildOrderFilterDropdown(context, allOrders),
            const SizedBox(width: 12),
          ],
          // Close All button (only on Positions tab)
          if (_selectedTabIndex == 0) ...[
            _buildActionButton(
              context,
              label: 'Close All',
              tooltip: 'Exit all positions',
              isEnabled: openPositions.isNotEmpty,
              color: resolveThemeColor(context,
                  dark: MyntColors.lossDark, light: MyntColors.loss),
              onPressed: openPositions.isNotEmpty
                  ? () => _showCloseAllDialog(context, openPositions)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          // Cancel All button
          _buildActionButton(
            context,
            label: 'Cancel All',
            isEnabled: hasOpenOrders,
            color: resolveThemeColor(context,
                dark: MyntColors.lossDark, light: MyntColors.loss),
            onPressed: hasOpenOrders
                ? () => _showCancelAllDialog(context, openOrders)
                : null,
          ),
        ],
      ),
    );
  }

  /// Get display status text for an order (same logic as _ScalperOrderTableRowState)
  String _getOrderStatusText(OrderBookModel order) {
    if (order.status == null) return 'N/A';
    final status = order.status!.toUpperCase();
    switch (status) {
      case 'OPEN':
        return 'OPEN';
      case 'COMPLETE':
      case 'EXECUTED':
        return 'EXECUTED';
      case 'REJECTED':
        return 'REJECTED';
      case 'CANCELLED':
      case 'CANCELED':
        return 'CANCELLED';
      case 'PENDING':
        return 'PENDING';
      case 'TRIGGER_PENDING':
        return 'TRIGGER PENDING';
      case 'AFTER_MARKET_ORDER_REQ_RECEIVED':
        return 'AMO';
      default:
        return status;
    }
  }

  void _showOrderFilterPopup(BuildContext context, List<OrderBookModel> allOrders) {
    // Build unique status options from actual orders
    final statusSet = <String>{};
    for (final order in allOrders) {
      statusSet.add(_getOrderStatusText(order));
    }
    final statuses = statusSet.toList()..sort();
    final options = ['All', ...statuses];

    shadcn.showPopover(
      context: context,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 4),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
      ),
      builder: (context) {
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
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: options.map((label) {
                  final isSelected = _selectedOrderFilter == label;
                  final count = label == 'All'
                      ? allOrders.length
                      : allOrders.where((o) => _getOrderStatusText(o) == label).length;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        shadcn.closeOverlay(context);
                        setState(() => _selectedOrderFilter = label);
                      },
                      splashColor: resolveThemeColor(
                        context,
                        dark: MyntColors.rippleDark,
                        light: MyntColors.rippleLight,
                      ),
                      highlightColor: resolveThemeColor(
                        context,
                        dark: MyntColors.highlightDark,
                        light: MyntColors.highlightLight,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: isSelected
                                      ? MyntFonts.semiBold
                                      : MyntFonts.medium,
                                  color: isSelected
                                      ? resolveThemeColor(context,
                                          dark: MyntColors.primaryDark,
                                          light: MyntColors.primary)
                                      : resolveThemeColor(context,
                                          dark: MyntColors.textPrimaryDark,
                                          light: MyntColors.textPrimary),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: resolveThemeColor(context,
                                        dark: MyntColors.dividerDark,
                                        light: MyntColors.divider)
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: MyntWebTextStyles.caption(
                                  context,
                                  fontWeight: MyntFonts.medium,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderFilterDropdown(BuildContext context, List<OrderBookModel> allOrders) {
    // Build unique status options from actual orders
    final statusSet = <String>{};
    for (final order in allOrders) {
      statusSet.add(_getOrderStatusText(order));
    }
    final statuses = statusSet.toList()..sort();

    // If current filter no longer exists in available statuses, reset to All
    if (_selectedOrderFilter != 'All' && !statuses.contains(_selectedOrderFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedOrderFilter = 'All');
      });
    }

    return Builder(
      builder: (btnContext) => GestureDetector(
        onTap: () => _showOrderFilterPopup(btnContext, allOrders),
        child: Container(
          width: 140,
          height: 40,
          decoration: BoxDecoration(
            color: resolveThemeColor(
              context,
              dark: MyntColors.transparent,
              light: const Color(0xffF1F3F8),
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.primary,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedOrderFilter,
                  style: MyntWebTextStyles.body(
                    context,
                    darkColor: MyntColors.textWhite,
                    lightColor: MyntColors.textBlack,
                    fontWeight: MyntFonts.medium,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary,
                ),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required bool isEnabled,
    required Color color,
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    final disabledColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final effectiveColor = isEnabled ? color : disabledColor;

    final button = MyntIconTextButton(
      label: label,
      size: MyntButtonSize.small,
      onPressed: isEnabled ? onPressed : null,
      textColor: effectiveColor,
    );

    return tooltip != null
        ? Tooltip(
            message: tooltip,
            child: button,
          )
        : button;
  }

  // Helper to measure text width using TextPainter (matches position_table.dart pattern)
  double _measureTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();
    return textPainter.width;
  }

  // Calculate minimum column widths based on actual content (matches position_table.dart pattern)
  Map<int, double> _calculateMinWidths(List<PositionBookModel> positions) {
    const textStyle = TextStyle(fontSize: 14, fontFamily: 'Geist');
    const padding = 16.0;

    // Headers for each column index (0=Product,1=Instrument,2=Qty,3=ActAvg,4=LTP,5=SL,6=Target,7=P&L,8=Actions)
    final headers = ['Product', 'Instrument', 'Qty', 'Act Avg', 'LTP', 'Stoploss', 'Target', 'P&L', ''];

    final minWidths = <int, double>{};

    for (int col = 0; col < headers.length; col++) {
      final header = headers[col];

      double maxWidth = 0.0;

      // Measure header width
      if (header.isNotEmpty) {
        maxWidth = _measureTextWidth(header, textStyle);
      }

      // Measure widest data value in this column
      for (final position in positions) {
        String cellText = '';
        switch (col) {
          case 0: cellText = position.sPrdtAli ?? 'N/A'; break;
          case 1:
            final sym = (position.dname != null && position.dname!.isNotEmpty)
                ? position.dname!.replaceAll('-EQ', '').trim()
                : (position.tsym ?? '').replaceAll('-EQ', '').trim();
            final exch = (position.exch != null && position.exch!.isNotEmpty &&
                (position.expDate == null || position.expDate!.isEmpty))
                ? ' ${position.exch}' : '';
            final symWidth = _measureTextWidth(sym, textStyle);
            final exchWidth = exch.isNotEmpty
                ? _measureTextWidth(exch, const TextStyle(fontSize: 12, fontFamily: 'Geist'))
                : 0.0;
            final total = symWidth + exchWidth + (exch.isNotEmpty ? 4.0 : 0.0) + 8.0;
            if (total > maxWidth) maxWidth = total;
            continue;
          case 2:
            final rawQty = int.tryParse(position.netqty?.toString() ?? '0') ?? 0;
            final lotSize = position.exch == 'MCX'
                ? (int.tryParse(position.ls?.toString() ?? '1') ?? 1) : 1;
            final qty = rawQty ~/ lotSize;
            cellText = qty > 0 ? '+$qty' : '$qty';
            break;
          case 3: cellText = position.avgPrc ?? '0.00'; break;
          case 4: cellText = position.lp ?? '0.00'; break;
          case 5: cellText = '0.00'; break; // Stoploss (GTT)
          case 6: cellText = '0.00'; break; // Target (GTT)
          case 7: cellText = position.profitNloss ?? '0.00'; break;
          case 8: // Actions column - fixed width for exit button
            maxWidth = 65.0; // Fixed width for icon button
            break;
        }
        if (col != 8) {
          final w = _measureTextWidth(cellText, textStyle);
          if (w > maxWidth) maxWidth = w;
        }
      }

      minWidths[col] = col == 8 ? maxWidth : (maxWidth + padding);
    }

    return minWidths;
  }

  static shadcn.TableCell _posHeaderCell(String label, {bool alignRight = false, EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 6)}) {
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
      child: Builder(
        builder: (context) => Container(
          width: double.infinity,
          height: double.infinity,
          padding: padding,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: label.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  label,
                  style: MyntWebTextStyles.tableHeader(
                    context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                    fontWeight: MyntFonts.semiBold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPositionsListWithFooter(
      BuildContext context, List<PositionBookModel> positions) {
    if (positions.isEmpty) {
      return const NoDataFoundWeb(
        title: 'No Positions',
        subtitle: 'You have no open positions.',
        primaryEnabled: false,
        secondaryEnabled: false,
        iconSize: 64,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate minimum widths from actual content (matches position_table.dart pattern)
        final minWidths = _calculateMinWidths(positions);
        final availableWidth = constraints.maxWidth;

        // Start with minimum widths
        final columnWidths = <int, double>{};
        for (int i = 0; i < 9; i++) {
          columnWidths[i] = minWidths[i] ?? 60.0;
        }

        // Distribute extra space proportionally (leave 16px padding on each side)
        const horizontalPadding = 32.0; // 16 left + 16 right
        final effectiveWidth = availableWidth - horizontalPadding;
        final totalMinWidth =
            columnWidths.values.fold<double>(0.0, (s, v) => s + v);
        if (totalMinWidth < effectiveWidth) {
          final extraSpace = effectiveWidth - totalMinWidth;
          // Instrument (col 1) grows 2x, Stoploss/Target (5,6) grow 2.5x for GTT controls, col 8 (Actions) fixed
          const growthFactors = <int, double>{
            0: 1.0, 1: 2.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 2.5, 6: 2.5, 7: 1.0, 8: 0.0,
          };
          final totalFactor =
              growthFactors.values.fold<double>(0.0, (s, v) => s + v);
          if (totalFactor > 0) {
            growthFactors.forEach((col, factor) {
              columnWidths[col] = columnWidths[col]! + (extraSpace * factor / totalFactor);
            });
          }
        } else if (totalMinWidth > effectiveWidth) {
          // Not enough space — shrink columns proportionally (matching position_table.dart pattern)
          final excessWidth = totalMinWidth - effectiveWidth;
          const absoluteMinWidths = <int, double>{
            0: 50.0, 1: 120.0, 2: 45.0, 3: 65.0,
            4: 50.0, 5: 80.0, 6: 80.0, 7: 55.0, 8: 65.0,
          };
          final shrinkableAmounts = <int, double>{};
          double totalShrinkable = 0.0;
          for (int i = 0; i < 9; i++) {
            final shrinkable = (columnWidths[i] ?? 0) - (absoluteMinWidths[i] ?? 50.0);
            shrinkableAmounts[i] = shrinkable > 0 ? shrinkable : 0.0;
            if (shrinkable > 0) totalShrinkable += shrinkable;
          }
          if (totalShrinkable > 0) {
            final shrinkFactor = excessWidth < totalShrinkable ? excessWidth / totalShrinkable : 1.0;
            for (int i = 0; i < 9; i++) {
              if ((shrinkableAmounts[i] ?? 0) > 0) {
                columnWidths[i] = columnWidths[i]! - shrinkableAmounts[i]! * shrinkFactor;
              }
            }
          }
        }

        final colWidths = columnWidths;
        final shadcnWidths = colWidths.map(
          (k, v) => MapEntry(k, shadcn.FixedTableSize(v)),
        );

        final totalRequiredWidth = columnWidths.values.fold<double>(0.0, (s, v) => s + v);
        final needsHorizontalScroll = totalRequiredWidth > effectiveWidth;

        final outlinedContent = shadcn.OutlinedContainer(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Fixed header — fills full available width
              shadcn.Table(
                columnWidths: shadcnWidths,
                defaultRowHeight: const shadcn.FixedTableSize(36),
                rows: [
                  shadcn.TableHeader(
                    cells: [
                      _posHeaderCell('Product'),    // 0
                      _posHeaderCell('Instrument', padding: const EdgeInsets.fromLTRB(16, 6, 4, 6)), // 1
                      _posHeaderCell('Qty',       alignRight: true), // 2
                      _posHeaderCell('Act Avg',   alignRight: true), // 3
                      _posHeaderCell('LTP',       alignRight: true), // 4
                      _posHeaderCell('Stoploss',  alignRight: true), // 5
                      _posHeaderCell('Target',    alignRight: true), // 6
                      _posHeaderCell('P&L',       alignRight: true), // 7
                      _posHeaderCell('',          alignRight: true, padding: const EdgeInsets.fromLTRB(4, 6, 16, 6)), // 8 - Actions
                    ],
                  ),
                ],
              ),
              // Scrollable body
              Expanded(
                child: RawScrollbar(
                  controller: _positionsScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  trackColor: resolveThemeColor(context,
                      dark: Colors.grey.withValues(alpha: 0.1),
                      light: Colors.grey.withValues(alpha: 0.1)),
                  thumbColor: resolveThemeColor(context,
                      dark: Colors.grey.withValues(alpha: 0.3),
                      light: Colors.grey.withValues(alpha: 0.3)),
                  thickness: 6,
                  radius: const Radius.circular(3),
                  child: SingleChildScrollView(
                    controller: _positionsScrollController,
                    scrollDirection: Axis.vertical,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: positions.map((p) => _ScalperPositionTableRow(
                        key: ValueKey('position_${p.token}'),
                        position: p,
                        colWidths: colWidths,
                      )).toList(),
                    ),
                  ),
                ),
              ),
              // Fixed footer with column-aligned totals (inside the container)
              _buildFooterWithColumns(context, positions, columnWidths),
            ],
          ),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: needsHorizontalScroll
              ? RawScrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  trackColor: resolveThemeColor(context,
                      dark: Colors.grey.withValues(alpha: 0.1),
                      light: Colors.grey.withValues(alpha: 0.1)),
                  thumbColor: resolveThemeColor(context,
                      dark: Colors.grey.withValues(alpha: 0.3),
                      light: Colors.grey.withValues(alpha: 0.3)),
                  thickness: 6,
                  radius: const Radius.circular(3),
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: totalRequiredWidth,
                      child: outlinedContent,
                    ),
                  ),
                )
              : outlinedContent,
        );
      },
    );
  }

  // Measure text width for order table columns
  double _measureOrderTextWidth(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width;
  }

  // Calculate minimum column widths for orders table from actual content
  Map<int, double> _calculateOrderMinWidths(List<OrderBookModel> orders) {
    const textStyle = TextStyle(fontSize: 14, fontFamily: 'Geist');
    const padding = 16.0;
    // cols: 0=Time,1=Type,2=Instrument,3=Product,4=Qty,5=LTP,6=Price,7=Status,8=cancel
    final headers = ['Time', 'Type', 'Instrument', 'Product', 'Qty', 'LTP', 'Price', 'Status', ''];
    final minWidths = <int, double>{};

    for (int col = 0; col < headers.length; col++) {
      if (col == 8) { minWidths[col] = 40.0; continue; } // cancel btn fixed

      double maxWidth = headers[col].isNotEmpty
          ? _measureOrderTextWidth(headers[col], textStyle)
          : 0.0;

      for (final order in orders) {
        String cellText = '';
        switch (col) {
          case 0:
            final raw = order.norentm ?? '';
            final parts = raw.split(' ');
            final tp = parts.isNotEmpty ? parts[0] : raw;
            final tps = tp.split(':');
            cellText = tps.length >= 2 ? '${tps[0]}:${tps[1]}' : tp;
            break;
          case 1: cellText = order.trantype == 'B' ? 'BUY' : 'SELL'; break;
          case 2:
            final sym = (order.dname != null && order.dname!.isNotEmpty)
                ? order.dname!.replaceAll('-EQ', '').trim()
                : (order.tsym ?? '').replaceAll('-EQ', '').trim();
            final exch = order.exch ?? '';
            final symW = _measureOrderTextWidth(sym, textStyle);
            final exchW = exch.isNotEmpty
                ? _measureOrderTextWidth(' $exch', const TextStyle(fontSize: 12, fontFamily: 'Geist'))
                : 0.0;
            final total = symW + exchW + 8.0;
            if (total > maxWidth) maxWidth = total;
            continue;
          case 3: cellText = order.sPrdtAli ?? order.prd ?? ''; break;
          case 4:
            final rawF = int.tryParse(order.fillshares ?? '0') ?? 0;
            final rawQ = int.tryParse(order.qty ?? '0') ?? 0;
            final ls = order.exch == 'MCX' ? (int.tryParse(order.ls ?? '1') ?? 1) : 1;
            cellText = '${rawF ~/ ls} / ${rawQ ~/ ls}';
            break;
          case 5:
            cellText = (order.ltp != null && order.ltp.toString() != '0' && order.ltp.toString() != '0.00')
                ? order.ltp.toString() : '0.00';
            break;
          case 6:
            cellText = (order.prctyp == 'MKT' || order.prctyp == 'MARKET') ? 'MKT'
                : (order.prc != null && order.prc != '0' && order.prc != '0.00') ? order.prc! : '0.00';
            break;
          case 7:
            final s = (order.status ?? '').toUpperCase();
            cellText = s == 'COMPLETE' || s == 'EXECUTED' ? 'EXECUTED'
                : s == 'CANCELLED' || s == 'CANCELED' ? 'CANCELLED'
                : s == 'TRIGGER_PENDING' ? 'TRIGGER PENDING'
                : s == 'AFTER_MARKET_ORDER_REQ_RECEIVED' ? 'AMO'
                : s.isEmpty ? 'N/A' : s;
            // Status has badge padding — add extra
            cellText = '  $cellText  ';
            break;
        }
        final w = _measureOrderTextWidth(cellText, textStyle);
        if (w > maxWidth) maxWidth = w;
      }
      minWidths[col] = maxWidth + padding;
    }
    return minWidths;
  }

  static shadcn.TableCell _orderHeaderCell(
    String label, {
    bool alignRight = false,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  }) {
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
      child: Builder(
        builder: (context) => Container(
          width: double.infinity,
          height: double.infinity,
          padding: padding,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: label.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  label,
                  style: MyntWebTextStyles.tableHeader(
                    context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                    fontWeight: MyntFonts.semiBold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context, WidgetRef ref) {
    final allOrders = ref.watch(orderProvider).allOrder ?? [];

    // Apply status filter
    final orders = _selectedOrderFilter == 'All'
        ? allOrders
        : allOrders.where((o) => _getOrderStatusText(o) == _selectedOrderFilter).toList();

    if (orders.isEmpty) {
      return const NoDataFoundWeb(
        title: 'No Orders',
        subtitle: 'You have no orders.',
        primaryEnabled: false,
        secondaryEnabled: false,
        iconSize: 64,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidths = _calculateOrderMinWidths(orders);
        final availableWidth = constraints.maxWidth;

        final columnWidths = <int, double>{};
        for (int i = 0; i < 9; i++) {
          columnWidths[i] = minWidths[i] ?? 60.0;
        }

        final totalMinWidth = columnWidths.values.fold<double>(0.0, (s, v) => s + v);
        const horizontalPadding = 32.0;
        final effectiveWidth = availableWidth - horizontalPadding;

        if (totalMinWidth < effectiveWidth) {
          // Grow: Instrument (col 2) gets 2x, others (0,1,3,4,5,6,7) get 1x; col 8 fixed
          final extraSpace = effectiveWidth - totalMinWidth;
          const growthFactors = <int, double>{
            0: 1.0, 1: 1.0, 2: 2.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0,
          };
          final totalFactor = growthFactors.values.fold<double>(0.0, (s, v) => s + v);
          if (totalFactor > 0) {
            growthFactors.forEach((col, factor) {
              columnWidths[col] = columnWidths[col]! + (extraSpace * factor / totalFactor);
            });
          }
        } else if (totalMinWidth > effectiveWidth) {
          // Shrink proportionally (col 8 fixed)
          final overflow = totalMinWidth - effectiveWidth;
          final shrinkableTotal = columnWidths.entries
              .where((e) => e.key != 8)
              .fold<double>(0.0, (s, e) => s + e.value);
          if (shrinkableTotal > 0) {
            for (int col = 0; col < 8; col++) {
              final share = columnWidths[col]! / shrinkableTotal;
              columnWidths[col] = columnWidths[col]! - (overflow * share);
            }
          }
        }

        final shadcnWidths = columnWidths.map((k, v) => MapEntry(k, shadcn.FixedTableSize(v)));

        Widget tableContent = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: shadcn.OutlinedContainer(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Fixed header
                shadcn.Table(
                  columnWidths: shadcnWidths,
                  defaultRowHeight: const shadcn.FixedTableSize(36),
                  rows: [
                    shadcn.TableHeader(
                      cells: [
                        _orderHeaderCell('Time'),         // 0: text — left
                        _orderHeaderCell('Type'),         // 1: text — left
                        _orderHeaderCell('Instrument',    // 2: text — left, extra left pad
                            padding: const EdgeInsets.fromLTRB(16, 6, 4, 6)),
                        _orderHeaderCell('Product'),      // 3: text — left
                        _orderHeaderCell('Qty',    alignRight: true), // 4: number
                        _orderHeaderCell('LTP',    alignRight: true), // 5: number
                        _orderHeaderCell('Price',  alignRight: true), // 6: number
                        _orderHeaderCell('Status', alignRight: true), // 7: badge — right
                        _orderHeaderCell('',              // 8: cancel btn — fixed, extra right pad
                            padding: const EdgeInsets.fromLTRB(4, 6, 16, 6)),
                      ],
                    ),
                  ],
                ),
                // Scrollable body
                Expanded(
                  child: RawScrollbar(
                    controller: _ordersScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    trackColor: resolveThemeColor(context,
                        dark: Colors.grey.withValues(alpha: 0.1),
                        light: Colors.grey.withValues(alpha: 0.1)),
                    thumbColor: resolveThemeColor(context,
                        dark: Colors.grey.withValues(alpha: 0.3),
                        light: Colors.grey.withValues(alpha: 0.3)),
                    thickness: 6,
                    radius: const Radius.circular(3),
                    child: SingleChildScrollView(
                      controller: _ordersScrollController,
                      scrollDirection: Axis.vertical,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: orders.map((o) => _ScalperOrderTableRow(
                          order: o,
                          colWidths: columnWidths,
                        )).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        return tableContent;
      },
    );
  }

  Widget _buildFooterWithColumns(BuildContext context, List<PositionBookModel> positions, Map<int, double> columnWidths) {
    final shadcnWidths = columnWidths.map((k, v) => MapEntry(k, shadcn.FixedTableSize(v)));

    shadcn.TableCell footerCell(Widget child, {bool alignRight = false, EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8)}) {
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
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: padding,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: resolveThemeColor(
              context,
              dark: MyntColors.dividerDark,
              light: MyntColors.divider,
            ),
          ),
        ),
      ),
      child: shadcn.Table(
        columnWidths: shadcnWidths,
        defaultRowHeight: const shadcn.FixedTableSize(36),
        rows: [
          shadcn.TableRow(
            cells: [
              footerCell(const SizedBox.shrink()),                                               // 0: product
              footerCell(const SizedBox.shrink(), padding: const EdgeInsets.fromLTRB(16, 8, 4, 8)), // 1: instrument
              footerCell(const SizedBox.shrink()),                                               // 2: qty
              footerCell(const SizedBox.shrink()),                                               // 3: act avg
              footerCell(const SizedBox.shrink()),                                               // 4: LTP
              footerCell(const SizedBox.shrink()),                                               // 5: stoploss
              footerCell(                                                                         // 6: target — "Total" label
                Text(
                  'Total',
                  style: MyntWebTextStyles.tableHeader(
                    context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                    fontWeight: MyntFonts.semiBold,
                  ),
                ),
                alignRight: true,
              ),
              footerCell(                                                                         // 7: P&L value
                Consumer(builder: (context, ref, _) {
                  final totalPnl = ref.watch(portfolioProvider.select((_) {
                    double t = 0;
                    for (final pos in positions) {
                      t += double.tryParse(pos.profitNloss ?? '0') ?? 0;
                    }
                    return t;
                  }));
                  final pnlColor = totalPnl > 0
                      ? resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit)
                      : totalPnl < 0
                          ? resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss)
                          : resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
                  return Text(
                    totalPnl.toStringAsFixed(2),
                    style: MyntWebTextStyles.body(
                      context,
                      fontWeight: MyntFonts.semiBold,
                      color: pnlColor,
                    ),
                  );
                }),
                alignRight: true,
              ),
              footerCell(const SizedBox.shrink(), padding: const EdgeInsets.fromLTRB(4, 8, 16, 8)), // 8: actions
            ],
          ),
        ],
      ),
    );
  }

  void _showCloseAllDialog(BuildContext context, List<PositionBookModel> openPositions) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => _ScalperExitPositionDialog(
        positions: openPositions,
        isExitAll: true,
      ),
    );
  }

  void _showCancelAllDialog(BuildContext context, List<OrderBookModel> openOrders) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => _ScalperCancelOrdersDialog(
        orders: openOrders,
        isCancelAll: true,
      ),
    );
  }
}

/// Editable GTT price field widget with proper controller management
class _GttPriceField extends StatefulWidget {
  final String initialPrice;
  final double tickSize;
  final GttOrderBookModel gtt;
  final ScalperProvider scalper;
  final Color textColor;

  const _GttPriceField({
    super.key,
    required this.initialPrice,
    required this.tickSize,
    required this.gtt,
    required this.scalper,
    required this.textColor,
  });

  @override
  State<_GttPriceField> createState() => _GttPriceFieldState();
}

class _GttPriceFieldState extends State<_GttPriceField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;
  // True while user is actively editing. Only cleared by explicit user actions
  // (tap outside, Enter, tick button). Survives transient focus loss from rebuilds.
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPrice);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_GttPriceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update text if user is NOT editing and price changed
    if (!_isEditing && oldWidget.initialPrice != widget.initialPrice) {
      _controller.text = widget.initialPrice;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      if (!_isFocused) setState(() => _isFocused = true);
      _isEditing = true;
    } else if (_isEditing) {
      // Focus lost while editing — this is transient (parent rebuild / WebSocket update).
      // Re-request focus to keep editing alive.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isEditing && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    } else {
      // _isEditing is false — genuine blur (user tapped outside, pressed Enter, etc.)
      if (_isFocused) setState(() => _isFocused = false);
      _controller.text = widget.initialPrice;
    }
  }

  /// Called when user taps outside this field — treat as genuine cancel
  /// but ignore taps that land on the +/- or confirm buttons (within this widget's bounds)
  void _handleTapOutside(PointerDownEvent event) {
    if (_isEditing) {
      // Check if tap is within this widget's bounds (includes +/- and confirm buttons)
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final localPos = renderBox.globalToLocal(event.position);
        if (renderBox.paintBounds.contains(localPos)) {
          return; // Tap is on the confirm/+/- button, not truly outside
        }
      }
      _isEditing = false;
      _controller.text = widget.initialPrice;
      _focusNode.unfocus();
    }
  }

  void _handleConfirm() {
    _isEditing = false; // Clear editing state before unfocus
    final newPrice = double.tryParse(_controller.text);
    if (newPrice != null && newPrice > 0) {
      final actualCurrentPrice = double.tryParse(widget.gtt.d ?? '0') ?? 0;
      final diff = newPrice - actualCurrentPrice;
      if (diff.abs() > 0.001) {
        widget.scalper.modifyGttPrice(widget.gtt, diff, context);
      }
    } else {
      _controller.text = widget.initialPrice;
    }
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = resolveThemeColor(
      context,
      dark: MyntColors.primaryDark,
      light: MyntColors.primary,
    );
    final dividerColor = resolveThemeColor(
      context,
      dark: MyntColors.dividerDark,
      light: MyntColors.divider,
    );

    // Always keep TextField in tree — just change surrounding buttons
    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(
          color: dividerColor,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus button (hidden when focused)
          if (!_isFocused)
            InkWell(
              onTap: () => widget.scalper.modifyGttPrice(widget.gtt, -widget.tickSize, context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
              ),
              child: Container(
                width: 26,
                height: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: dividerColor)),
                ),
                child: Icon(Icons.remove, size: 14, color: primaryColor),
              ),
            ),
          // Price text field — expands to fill remaining space
          Flexible(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.semiBold,
                color: widget.textColor,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                border: InputBorder.none,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              onSubmitted: (_) => _handleConfirm(),
              onTapOutside: _handleTapOutside,
            ),
          ),
          // Plus button (hidden when focused) / Tick button (shown when focused)
          if (_isFocused)
            InkWell(
              onTap: _handleConfirm,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
              child: Container(
                width: 26,
                height: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: dividerColor)),
                ),
                child: Icon(Icons.check, size: 14, color: primaryColor),
              ),
            )
          else
            InkWell(
              onTap: () => widget.scalper.modifyGttPrice(widget.gtt, widget.tickSize, context),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
              child: Container(
                width: 26,
                height: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: dividerColor)),
                ),
                child: Icon(Icons.add, size: 14, color: primaryColor),
              ),
            ),
        ],
      ),
    );
  }
}

/// Table row for positions - matches main positions page layout and calculations
class _ScalperPositionTableRow extends ConsumerStatefulWidget {
  final PositionBookModel position;
  final Map<int, double> colWidths;

  const _ScalperPositionTableRow({
    super.key,
    required this.position,
    required this.colWidths,
  });

  @override
  ConsumerState<_ScalperPositionTableRow> createState() =>
      _ScalperPositionTableRowState();
}

class _ScalperPositionTableRowState
    extends ConsumerState<_ScalperPositionTableRow> {
  final ValueNotifier<bool> _isHovered = ValueNotifier(false);
  // GlobalKeys ensure _GttPriceField state survives parent tree rebuilds
  // (shadcn.Table reinitializes cells on every rebuild, destroying ValueKey-based state)
  final GlobalKey _slGttFieldKey = GlobalKey(debugLabel: 'sl_gtt_field');
  final GlobalKey _targetGttFieldKey = GlobalKey(debugLabel: 'target_gtt_field');

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  /// Format position quantity - for MCX, divide by lot size (matches main page)
  String _formatPositionQty(PositionBookModel position) {
    final rawQty = int.tryParse(position.netqty?.toString() ?? '0') ?? 0;
    final lotSize = position.exch == 'MCX'
        ? (int.tryParse(position.ls?.toString() ?? '1') ?? 1)
        : 1;
    final qty = rawQty ~/ lotSize;
    return qty > 0 ? '+$qty' : '$qty';
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    final product = position.sPrdtAli ?? 'N/A';
    final formattedQty = _formatPositionQty(position);
    final actAvg = position.avgPrc ?? '0.00';
    final isClosed = (int.tryParse(position.qty ?? '0') ?? 0) == 0;

    final qtyNum = int.tryParse(formattedQty.replaceAll('+', '')) ?? 0;

    final textColor = isClosed
        ? resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary)
        : resolveThemeColor(context,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    final qtyColor = isClosed
        ? textColor
        : qtyNum > 0
            ? resolveThemeColor(context,
                dark: MyntColors.profitDark, light: MyntColors.profit)
            : qtyNum < 0
                ? resolveThemeColor(context,
                    dark: MyntColors.lossDark, light: MyntColors.loss)
                : resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    final textStyle = MyntWebTextStyles.para(
      context,
      fontWeight: MyntFonts.medium,
      color: textColor,
    );

    final instrumentText = (position.dname != null && position.dname!.isNotEmpty)
        ? position.dname!.replaceAll("-EQ", "").trim()
        : (position.tsym ?? '').replaceAll("-EQ", "").trim();

    final showExchange = position.exch != null &&
        position.exch!.isNotEmpty &&
        (position.expDate == null || position.expDate!.isEmpty);

    // Can exit: not closed, not BO/CO
    final canExit = !isClosed &&
        position.qty != "0" &&
        position.sPrdtAli != "BO" &&
        position.sPrdtAli != "CO";

    // Only rebuild when GTT orders change, not on every scalper state change
    // ignore: unused_local_variable
    final gttOrders = ref.watch(scalperProvider.select((s) => s.gttOrders));
    final scalper = ref.read(scalperProvider);
    final netqty = int.tryParse(position.netqty?.toString() ?? '0') ?? 0;
    final isOpen = !isClosed && netqty != 0;
    // final isExpanded = isOpen && scalper.expandedPositionTokens.contains(position.token);
    final secondaryColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    // GTT data for this position
    final slGtt = isOpen && position.token != null
        ? scalper.getGttByType(position.token!, 'SL', netqty)
        : null;
    final targetGtt = isOpen && position.token != null
        ? scalper.getGttByType(position.token!, 'Target', netqty)
        : null;

    final colWidths = widget.colWidths.map(
      (k, v) => MapEntry(k, shadcn.FixedTableSize(v)),
    );

    final rowBg = isClosed
        ? resolveThemeColor(context,
            dark: MyntColors.textPrimary.withValues(alpha: 0.05),
            light: const Color(0x8F121212).withValues(alpha: 0.03))
        : null;

    shadcn.TableCell cell(Widget child, {bool alignRight = false, double verticalPadding = 8, int columnIndex = -1}) {
      final EdgeInsets cellPadding = columnIndex == 8
          ? EdgeInsets.fromLTRB(4, verticalPadding, 16, verticalPadding) // Actions — last column
          : EdgeInsets.symmetric(horizontal: 8, vertical: verticalPadding);
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
        child: Container(
          color: rowBg,
          width: double.infinity,
          height: double.infinity,
          padding: cellPadding,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        ),
      );
    }

    // Row-level hover managed via ValueNotifier to survive rebuilds
    final hoverBgColor = resolveThemeColor(context,
        dark: Colors.white.withValues(alpha: 0.04),
        light: Colors.black.withValues(alpha: 0.04));

    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isHovered,
        builder: (context, hovered, child) {
          return Container(
            color: hovered ? hoverBgColor : Colors.transparent,
            child: child,
          );
        },
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
          // Main row using shadcn.Table for column alignment
          shadcn.Table(
            columnWidths: colWidths,
            defaultRowHeight: const shadcn.FixedTableSize(50),
            rows: [
              shadcn.TableRow(
                // Suppress Table's internal hover to prevent flicker on rebuilds
                cellTheme: const shadcn.TableCellTheme(),
                cells: [
                  // 0: Product
                  cell(
                    Text(
                      product,
                      style: MyntWebTextStyles.tableCell(
                        context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary,
                        fontWeight: MyntFonts.medium,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 1: Instrument
                  shadcn.TableCell(
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
                    child: Container(
                      color: rowBg,
                      width: double.infinity,
                      height: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                      alignment: Alignment.centerLeft,
                      child: Tooltip(
                        message: '$instrumentText${showExchange ? ' ${position.exch}' : ''}',
                        child: RichText(
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          softWrap: false,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: instrumentText,
                                style: MyntWebTextStyles.tableCell(
                                  context,
                                  darkColor: isClosed ? MyntColors.textSecondaryDark : MyntColors.textPrimaryDark,
                                  lightColor: isClosed ? MyntColors.textSecondary : MyntColors.textPrimary,
                                  fontWeight: MyntFonts.medium,
                                ),
                              ),
                              if (showExchange)
                                TextSpan(
                                  text: ' ${position.exch}',
                                  style: MyntWebTextStyles.tableCell(
                                    context,
                                    darkColor: MyntColors.textSecondaryDark,
                                    lightColor: MyntColors.textSecondary,
                                    fontWeight: MyntFonts.medium,
                                  ).copyWith(fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 2: Qty
                  cell(
                    Text(
                      formattedQty,
                      style: MyntWebTextStyles.tableCell(
                        context,
                        color: qtyColor,
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                    alignRight: true,
                  ),
                  // 3: Act Avg
                  cell(
                    Text(
                      actAvg,
                      style: MyntWebTextStyles.tableCell(
                        context,
                        darkColor: isClosed ? MyntColors.textSecondaryDark : MyntColors.textPrimaryDark,
                        lightColor: isClosed ? MyntColors.textSecondary : MyntColors.textPrimary,
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                    alignRight: true,
                  ),
                  // 4: LTP — Consumer for per-cell live updates
                  cell(
                    Consumer(builder: (context, ref, _) {
                      final liveLtp = ref.watch(portfolioProvider.select((_) => position.lp)) ?? '0.00';
                      return Text(
                        liveLtp,
                        style: MyntWebTextStyles.tableCell(
                          context,
                          darkColor: isClosed ? MyntColors.textSecondaryDark : MyntColors.textPrimaryDark,
                          lightColor: isClosed ? MyntColors.textSecondary : MyntColors.textPrimary,
                          fontWeight: MyntFonts.medium,
                        ),
                      );
                    }),
                    alignRight: true,
                  ),
                  // 5: Stoploss
                  cell(
                    isOpen
                        ? _buildGttCell(context, slGtt, 'SL', position, scalper, secondaryColor, textStyle, gttFieldKey: _slGttFieldKey)
                        : Text('-', style: textStyle),
                    alignRight: true,
                    verticalPadding: 4,
                  ),
                  // 6: Target
                  cell(
                    isOpen
                        ? _buildGttCell(context, targetGtt, 'Target', position, scalper, secondaryColor, textStyle, gttFieldKey: _targetGttFieldKey)
                        : Text('-', style: textStyle),
                    alignRight: true,
                    verticalPadding: 4,
                  ),
                  // 7: P&L — Consumer for per-cell live updates
                  cell(
                    Consumer(builder: (context, ref, _) {
                      final livePnlStr = ref.watch(portfolioProvider.select((_) => position.profitNloss)) ?? '0.00';
                      final livePnl = double.tryParse(livePnlStr) ?? 0;
                      final livePnlColor = livePnl > 0
                          ? resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit)
                          : livePnl < 0
                              ? resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss)
                              : resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
                      return Text(
                        livePnlStr,
                        style: MyntWebTextStyles.tableCell(
                          context,
                          color: livePnlColor,
                          fontWeight: MyntFonts.medium,
                        ),
                      );
                    }),
                    alignRight: true,
                  ),
                  // 8: Actions (Exit button)
                  cell(
                    canExit
                        ? Tooltip(
                            message: 'Exit Position',
                            child: GestureDetector(
                              onTap: () => _showExitPositionDialog(context, position),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.textWhite,
                                    light: MyntColors.textWhite,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: resolveThemeColor(
                                        context,
                                        dark: Colors.transparent,
                                        light: Colors.grey,
                                      ),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.output,
                                  size: 18,
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.lossDark,
                                    light: MyntColors.tertiary,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    alignRight: true,
                    columnIndex: 8,
                  ),
                ],
              ),
            ],
          ),
          // Expanded GTT sub-row
          // if (isExpanded)
          //   _buildExpandedGttRow(context, position, netqty, scalper, secondaryColor),
        ],
      ),
      ),
    );

  }

  /// Build a SL or Target cell with GTT segment controls
  Widget _buildGttCell(
    BuildContext context,
    GttOrderBookModel? gtt,
    String label,
    PositionBookModel position,
    ScalperProvider scalper,
    Color secondaryColor,
    TextStyle textStyle, {
    GlobalKey? gttFieldKey,
  }) {
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final hasGtt = gtt != null;
    final gttType = label == 'SL' ? 'stoploss' : 'target';

    if (!hasGtt) {
      // No GTT - just show edit icon
      return Tooltip(
        message: label == 'SL' ? 'Edit Stoploss' : 'Edit Target',
        child: GestureDetector(
          onTap: () => _showGttDialog(context, position, gttType),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.textWhite, light: MyntColors.textWhite),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: resolveThemeColor(context,
                      dark: Colors.transparent, light: Colors.grey),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.edit_outlined,
              size: 18,
              color: resolveThemeColor(context,
                  dark: MyntColors.primaryDark, light: MyntColors.primary),
            ),
          ),
        ),
      );
    }

    // GTT exists - show compact segment
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildCompactGttSegment(context, label, gtt, scalper, textColor, secondaryColor, position, gttFieldKey: gttFieldKey),
      ],
    );
  }

  /// Build a compact GTT segment for table cells
  Widget _buildCompactGttSegment(
    BuildContext context,
    String label,
    GttOrderBookModel gtt,
    ScalperProvider scalper,
    Color textColor,
    Color secondaryColor,
    PositionBookModel position, {
    GlobalKey? gttFieldKey,
  }) {
    final lossColor = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final labelColor = label == 'SL'
        ? lossColor
        : resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
    final price = gtt.d ?? '0.00';
    final tickSize = double.tryParse(gtt.ti ?? '') ?? 0.05;
    final gttType = label == 'SL' ? 'stoploss' : 'target';

    // Calculate percentage from avg price
    String? pctText;
    final triggerVal = double.tryParse(price) ?? 0;
    final avgVal = double.tryParse(position.avgPrc ?? '0') ?? 0;
    if (avgVal > 0 && triggerVal > 0) {
      final pct = ((triggerVal - avgVal) / avgVal * 100).abs();
      pctText = '${pct.round()}%';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Label (SL / Target)
        // Text(
        //   label,
        //   style: MyntWebTextStyles.body(
        //     context,
        //     fontWeight: MyntFonts.medium,
        //     color: labelColor,
        //   ),
        // ),
        // GTT Price stepper using MyntTextField
        SizedBox(
          height: 34,
          width: 160,
          child: _GttPriceField(
            key: gttFieldKey ?? ValueKey('gtt_${gtt.alId}_$label'),
            initialPrice: price,
            tickSize: tickSize,
            gtt: gtt,
            scalper: scalper,
            textColor: textColor,
          ),
        ),
        const SizedBox(width: 6),
        // Cancel (×) button - using EXACT same code as expanded row
        Tooltip(
          message: 'Cancel GTT',
          child: GestureDetector(
            onTap: () async {
              await ref.read(scalperProvider).cancelGttOrderSilent(gtt.alId!, context);
              await ref.read(scalperProvider).fetchGttOrders(context);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: resolveThemeColor(context,
                    dark: MyntColors.textWhite,
                    light: MyntColors.textWhite),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: resolveThemeColor(context,
                        dark: Colors.transparent,
                        light: Colors.grey),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.close,
                size: 18,
                color: resolveThemeColor(context,
                    dark: MyntColors.lossDark, light: MyntColors.loss),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Price and percentage column
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text(
            //   price,
            //   style: MyntWebTextStyles.tableCell(
            //     context,
            //     darkColor: textColor,
            //     lightColor: textColor,
            //     fontWeight: MyntFonts.medium,
            //   ),
            //   textAlign: TextAlign.right,
            // ),
            // if (pctText != null)
            //   Text(
            //     pctText,
            //     style: MyntWebTextStyles.para(
            //       context,
            //       color: secondaryColor,
            //     ),
            //     textAlign: TextAlign.right,
            //   ),
          ],
        ),
        const SizedBox(width: 4),
        // Edit icon
        Tooltip(
          message: label == 'SL' ? 'Edit Stoploss' : 'Edit Target',
          child: GestureDetector(
            onTap: () => _showGttDialog(context, position, gttType),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: resolveThemeColor(context,
                    dark: MyntColors.textWhite, light: MyntColors.textWhite),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: resolveThemeColor(context,
                        dark: Colors.transparent, light: Colors.grey),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.edit_outlined,
                size: 18,
                color: resolveThemeColor(context,
                    dark: MyntColors.primaryDark, light: MyntColors.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // /// Build the expanded GTT details row
  // Widget _buildExpandedGttRow(
  //   BuildContext context,
  //   PositionBookModel position,
  //   int netqty,
  //   ScalperProvider scalper,
  //   Color secondaryColor,
  // ) {
  //   final dividerColor = resolveThemeColor(context,
  //       dark: MyntColors.dividerDark, light: MyntColors.divider);
  //   final textColor = resolveThemeColor(context,
  //       dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
  //   final gttOrders = scalper.getPositionGttOrders(position.token!);
  //   final slGtt = scalper.getGttByType(position.token!, 'SL', netqty);
  //   final targetGtt = scalper.getGttByType(position.token!, 'Target', netqty);
  //   final hasAny = slGtt != null || targetGtt != null;

  //   return Container(
  //     padding: const EdgeInsets.only(left: 44, right: 16, top: 4, bottom: 8),
  //     height: 60,
  //     decoration: BoxDecoration(
  //       color: hasAny
  //           ? resolveThemeColor(context,
  //               dark: MyntColors.searchBgDark, light: MyntColors.searchBg)
  //           : null,
  //       border: Border(
  //         bottom: BorderSide(color: dividerColor, width: 0.5),
  //       ),
  //     ),
  //     child: hasAny
  //         ? Row(
  //             children: [
  //               // SL segment
  //               if (slGtt != null) ...[
  //                 _buildGttSegment(context, 'SL', slGtt, scalper, textColor, secondaryColor),
  //                 if (targetGtt != null) const SizedBox(width: 24),
  //               ],
  //               // Target segment
  //               if (targetGtt != null)
  //                 _buildGttSegment(context, 'Target', targetGtt, scalper, textColor, secondaryColor),
  //               // const Spacer(),
  //               // Qty label
  //               const SizedBox(width: 24),
  //               Text(
  //                 'Qty: ${gttOrders.isNotEmpty ? gttOrders.first.qty : ""}',
  //                 style: MyntWebTextStyles.body(context, color: resolveThemeColor(context,
  //                     dark: MyntColors.textPrimaryDark,
  //                     light: MyntColors.textPrimary)),
  //               ),
  //             ],
  //           )
  //         : Center(
  //           child: Text(
  //               'No active GTT orders',
  //               style: MyntWebTextStyles.tableCell(context,
  //                   color: resolveThemeColor(context,
  //                       dark: MyntColors.textPrimaryDark,
  //                       light: MyntColors.textPrimary),
  //                   fontWeight: MyntFonts.medium),
  //             ),
  //         ),
  //   );
  // }

  // /// Build a single SL or Target segment in the expanded row
  // Widget _buildGttSegment(
  //   BuildContext context,
  //   String label,
  //   GttOrderBookModel gtt,
  //   ScalperProvider scalper,
  //   Color textColor,
  //   Color secondaryColor,
  // ) {
  //   final dividerColor = resolveThemeColor(context,
  //       dark: MyntColors.dividerDark, light: MyntColors.divider);
  //   final lossColor = resolveThemeColor(context,
  //       dark: MyntColors.lossDark, light: MyntColors.loss);
  //   final labelColor = label == 'SL'
  //       ? lossColor
  //       : resolveThemeColor(context,
  //           dark: MyntColors.profitDark, light: MyntColors.profit);
  //   final price = gtt.d ?? '0.00';
  //   final tickSize = double.tryParse(gtt.ti ?? '') ?? 0.05;

  //   return Row(
  //     mainAxisSize: MainAxisSize.min,
  //     crossAxisAlignment: CrossAxisAlignment.center,
  //     children: [
  //       // Label (SL / Target)
  //       Text(
  //         label,
  //         style: MyntWebTextStyles.body(
  //           context,
  //           fontWeight: MyntFonts.medium,
  //           color: labelColor,
  //         ),
  //       ),
  //       const SizedBox(width: 8),
  //       // Stepper — matches lot stepper UI from scalper_order_bar.dart
  //       Container(
  //         height: 32,
  //         decoration: BoxDecoration(
  //           border: Border.all(color: dividerColor),
  //           borderRadius: BorderRadius.circular(5),
  //         ),
  //         child: Row(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             // Minus button
  //             InkWell(
  //               onTap: () => scalper.modifyGttPrice(gtt, -tickSize, context),
  //               borderRadius: const BorderRadius.only(
  //                 topLeft: Radius.circular(5),
  //                 bottomLeft: Radius.circular(5),
  //               ),
  //               child: Container(
  //                 width: 32,
  //                 alignment: Alignment.center,
  //                 decoration: BoxDecoration(
  //                   border: Border(right: BorderSide(color: dividerColor)),
  //                 ),
  //                 child: Icon(Icons.remove, size: 16, color: textColor),
  //               ),
  //             ),
  //             // Price display
  //             Container(
  //               constraints: const BoxConstraints(minWidth: 64),
  //               alignment: Alignment.center,
  //               padding: const EdgeInsets.symmetric(horizontal: 8),
  //               child: Text(
  //                 price,
  //                 textAlign: TextAlign.center,
  //                 style: MyntWebTextStyles.body(
  //                   context,
  //                   fontWeight: MyntFonts.semiBold,
  //                   color: textColor,
  //                 ),
  //               ),
  //             ),
  //             // Plus button
  //             InkWell(
  //               onTap: () => scalper.modifyGttPrice(gtt, tickSize, context),
  //               borderRadius: const BorderRadius.only(
  //                 topRight: Radius.circular(5),
  //                 bottomRight: Radius.circular(5),
  //               ),
  //               child: Container(
  //                 width: 32,
  //                 alignment: Alignment.center,
  //                 decoration: BoxDecoration(
  //                   border: Border(left: BorderSide(color: dividerColor)),
  //                 ),
  //                 child: Icon(Icons.add, size: 16, color: textColor),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       const SizedBox(width: 8),
  //       // Cancel (×) button

  //       GestureDetector(
  //   onTap: () async {
  //           await ref.read(scalperProvider).cancelGttOrderSilent(gtt.alId!, context);
  //           await ref.read(scalperProvider).fetchGttOrders(context);
  //         },
  //     child: Container(
  //       padding: const EdgeInsets.all(6),
  //       decoration: BoxDecoration(
  //         color: resolveThemeColor(context,
  //             // dark: MyntColors.loss.withValues(alpha: 0.15),
  //             // light: MyntColors.loss.withValues(alpha: 0.1)),
  //             dark: MyntColors.textWhite,
  //             light: MyntColors.textWhite),
  //         borderRadius: BorderRadius.circular(4),
  //         boxShadow: [
  //           BoxShadow(
  //             color: resolveThemeColor(context,
  //                 dark: Colors.transparent,
  //                 light: Colors.grey),
  //             blurRadius: 2,
  //             offset: const Offset(0, 1),
  //           ),
  //         ],
  //       ),
  //       child: Icon(
  //         Icons.close,
  //         size: 16,
  //         fontWeight: FontWeight.bold,
  //         color: resolveThemeColor(context,
  //             dark: MyntColors.lossDark, light: MyntColors.loss),
  //       ),
  //     ),
  //   )

  //     ],
  //   );
  // }

  void _showGttDialog(BuildContext context, PositionBookModel position, String gttType) {
    final scalper = ref.read(scalperProvider);
    final netqty = int.tryParse(position.netqty?.toString() ?? '0') ?? 0;
    final existingGtt = scalper.getGttByType(position.token!, gttType == 'stoploss' ? 'SL' : 'Target', netqty);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => _ScalperGttDialog(
        position: position,
        gttType: gttType,
        existingGtt: existingGtt,
      ),
    );
  }

  void _showExitPositionDialog(BuildContext context, PositionBookModel position) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => _ScalperExitPositionDialog(positions: [position], isExitAll: false),
    );
  }
}

/// Full-cell chevron button with hover highlight for the expand column
class _ChevronCell extends StatefulWidget {
  final bool isExpanded;
  final Color? rowBg;
  final Color secondaryColor;
  final VoidCallback onTap;

  const _ChevronCell({
    required this.isExpanded,
    required this.rowBg,
    required this.secondaryColor,
    required this.onTap,
  });

  @override
  State<_ChevronCell> createState() => _ChevronCellState();
}

class _ChevronCellState extends State<_ChevronCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hovered
        ? resolveThemeColor(context,
            dark: MyntColors.primaryDark.withValues(alpha: 0.15),
            light: MyntColors.primary.withValues(alpha: 0.15))
        : widget.rowBg;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: bg,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          child: Icon(
            widget.isExpanded ? Icons.expand_more : Icons.chevron_right,
            size: 18,
            color: _hovered
                ? resolveThemeColor(context,
                    dark: MyntColors.primaryDark, light: MyntColors.primary)
                : widget.secondaryColor,
          ),
        ),
      ),
    );
  }
}

/// Table row for orders - matches main orders page layout exactly
/// Columns: Time, Type, Instrument, Product, Qty, LTP, Price, Status, Cancel
class _ScalperOrderTableRow extends StatefulWidget {
  final OrderBookModel order;
  final Map<int, double> colWidths;

  const _ScalperOrderTableRow({required this.order, required this.colWidths});

  @override
  State<_ScalperOrderTableRow> createState() => _ScalperOrderTableRowState();
}

class _ScalperOrderTableRowState extends State<_ScalperOrderTableRow> {
  final _hovered = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  OrderBookModel get order => widget.order;

  /// Format order qty with MCX lot size handling (matches main page)
  String _formatOrderQty(OrderBookModel order) {
    final rawFilled = int.tryParse(order.fillshares ?? '0') ?? 0;
    final rawQty = int.tryParse(order.qty ?? '0') ?? 0;
    final lotSize = order.exch == 'MCX'
        ? (int.tryParse(order.ls ?? '1') ?? 1)
        : 1;
    final filledQty = rawFilled ~/ lotSize;
    final totalQty = rawQty ~/ lotSize;
    return '$filledQty / $totalQty';
  }

  /// Get valid price - show "MKT" for market orders (matches main page)
  String _getValidPrice(OrderBookModel order) {
    if (order.prctyp == 'MKT' || order.prctyp == 'MARKET') {
      return 'MKT';
    }
    if (order.prc != null && order.prc != '0' && order.prc != '0.00') {
      return order.prc!;
    }
    return '0.00';
  }

  /// Get status display text (matches main page CellFormatters.getStatusText)
  String _getStatusText(OrderBookModel order) {
    if (order.status == null) return 'N/A';
    final status = order.status!.toUpperCase();
    switch (status) {
      case 'OPEN':
        return 'OPEN';
      case 'COMPLETE':
      case 'EXECUTED':
        return 'EXECUTED';
      case 'REJECTED':
        return 'REJECTED';
      case 'CANCELLED':
      case 'CANCELED':
        return 'CANCELLED';
      case 'PENDING':
        return 'PENDING';
      case 'TRIGGER_PENDING':
        return 'TRIGGER PENDING';
      case 'AFTER_MARKET_ORDER_REQ_RECEIVED':
        return 'AMO';
      default:
        return status;
    }
  }

  /// Get status color (matches main page exactly)
  Color _getStatusColor(BuildContext context, String statusText) {
    final upper = statusText.toUpperCase();
    if (upper.contains('COMPLETE') || upper.contains('EXECUTED') || upper.contains('FILLED')) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    } else if (upper.contains('REJECT') || upper.contains('CANCEL')) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    } else if (upper.contains('PENDING') || upper.contains('OPEN') || upper.contains('AMO')) {
      return MyntColors.warning;
    }
    return resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
  }

  /// Get initial LTP value - fallback to close price if ltp is null/0 (matches main page)
  String _getValidLTP(OrderBookModel order) {
    if (order.ltp != null &&
        order.ltp.toString() != 'null' &&
        order.ltp.toString().isNotEmpty &&
        order.ltp.toString() != '0' &&
        order.ltp.toString() != '0.00') {
      return order.ltp.toString();
    }
    if (order.c != null && order.c.toString() != 'null') {
      final closePrice = double.tryParse(order.c.toString());
      if (closePrice != null) return closePrice.toString();
    }
    return '0.00';
  }

  String _formatTime(String norentm) {
    if (norentm.isEmpty) return '--';
    final parts = norentm.split(' ');
    if (parts.isNotEmpty) {
      final timePart = parts[0];
      final timeParts = timePart.split(':');
      if (timeParts.length >= 2) {
        return '${timeParts[0]}:${timeParts[1]}';
      }
      return timePart;
    }
    return norentm;
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = order.trantype == 'B';
    final statusText = _getStatusText(order);
    final statusColor = _getStatusColor(context, statusText);
    final product = order.sPrdtAli ?? order.prd ?? '';
    final time = _formatTime(order.norentm ?? '');

    final typeColor = isBuy
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);

    final textStyle = MyntWebTextStyles.tableCell(
      context,
      darkColor: MyntColors.textPrimaryDark,
      lightColor: MyntColors.textPrimary,
      fontWeight: MyntFonts.medium,
    );

    // Instrument display - use dname if available, otherwise tsym
    final instrumentText = (order.dname != null && order.dname!.isNotEmpty)
        ? order.dname!.replaceAll('-EQ', '').trim()
        : (order.tsym ?? '').replaceAll('-EQ', '').trim();

    // Check if order is open (cancellable)
    final isOpen = statusText == 'OPEN' ||
        statusText == 'PENDING' ||
        statusText == 'TRIGGER PENDING' ||
        statusText == 'AMO';

    final shadcnWidths = widget.colWidths.map((k, v) => MapEntry(k, shadcn.FixedTableSize(v)));

    // cell helper — fills full cell width, aligns content, variable padding per column
    shadcn.TableCell cell(
      Widget child, {
      bool alignRight = false,
      int columnIndex = -1,
      Color? rowBg,
    }) {
      EdgeInsets padding;
      if (columnIndex == 2) {
        padding = const EdgeInsets.fromLTRB(16, 8, 4, 8); // Instrument — extra left
      } else if (columnIndex == 8) {
        padding = const EdgeInsets.fromLTRB(4, 8, 16, 8); // Cancel — extra right
      } else {
        padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
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
        child: Container(
          color: rowBg,
          width: double.infinity,
          height: double.infinity,
          padding: padding,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: ValueListenableBuilder<bool>(
        valueListenable: _hovered,
        builder: (context, isHovered, _) {
          final rowBg = isHovered
              ? resolveThemeColor(context,
                  dark: MyntColors.primaryDark.withValues(alpha: 0.08),
                  light: MyntColors.primary.withValues(alpha: 0.08))
              : null;
          return shadcn.Table(
            columnWidths: shadcnWidths,
            defaultRowHeight: const shadcn.FixedTableSize(50),
            rows: [
              shadcn.TableRow(
                cells: [
                  // 0: Time — text, left
                  cell(Text(time, style: textStyle, overflow: TextOverflow.ellipsis),
                      columnIndex: 0, rowBg: rowBg),
                  // 1: Type — colored text, left
                  cell(Text(
                    isBuy ? 'BUY' : 'SELL',
                    style: MyntWebTextStyles.tableCell(context,
                        darkColor: typeColor, lightColor: typeColor,
                        fontWeight: MyntFonts.semiBold),
                  ), columnIndex: 1, rowBg: rowBg),
                  // 2: Instrument — text, left, extra left pad
                  cell(Tooltip(
                    message: '$instrumentText${order.exch != null ? ' ${order.exch}' : ''}',
                    child: RichText(
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      text: TextSpan(children: [
                        TextSpan(text: instrumentText, style: textStyle),
                        if (order.exch != null && order.exch!.isNotEmpty)
                          TextSpan(
                            text: ' ${order.exch}',
                            style: MyntWebTextStyles.tableCell(context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary,
                              fontWeight: MyntFonts.medium,
                            ).copyWith(fontSize: 10),
                          ),
                      ]),
                    ),
                  ), columnIndex: 2, rowBg: rowBg),
                  // 3: Product — text, left
                  cell(Text(product, style: textStyle, overflow: TextOverflow.ellipsis),
                      columnIndex: 3, rowBg: rowBg),
                  // 4: Qty — number, right
                  cell(
                    Text(_formatOrderQty(order), style: textStyle, textAlign: TextAlign.right),
                    alignRight: true, columnIndex: 4, rowBg: rowBg,
                  ),
                  // 5: LTP — number, right
                  cell(_ScalperOrderLTPCell(
                    token: order.token ?? '',
                    initialLtp: _getValidLTP(order),
                  ), alignRight: true, columnIndex: 5, rowBg: rowBg),
                  // 6: Price — number, right
                  cell(
                    Text(_getValidPrice(order), style: textStyle, textAlign: TextAlign.right),
                    alignRight: true, columnIndex: 6, rowBg: rowBg,
                  ),
                  // 7: Status badge — right-aligned
                  cell(
                    Tooltip(
                      message: statusText == 'REJECTED' ? (order.rejreason ?? 'Unknown reason') : '',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusText,
                          style: MyntWebTextStyles.bodySmall(context,
                            color: statusColor,
                            fontWeight: MyntFonts.medium),
                        ),
                      ),
                    ),
                    alignRight: true, columnIndex: 7, rowBg: rowBg,
                  ),
                  // 8: Cancel button (on hover for open orders), extra right pad
                  cell((isHovered && isOpen)
                      ? Tooltip(
                          message: 'Cancel Order',
                          child: InkWell(
                            onTap: () => _showCancelOrderDialog(context, order),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: resolveThemeColor(context,
                                    dark: MyntColors.lossDark, light: MyntColors.loss)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.close_rounded, size: 14,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.lossDark, light: MyntColors.loss)),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                      columnIndex: 8, rowBg: rowBg),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCancelOrderDialog(BuildContext context, OrderBookModel order) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => _ScalperCancelOrdersDialog(
        orders: [order],
        isCancelAll: false,
      ),
    );
  }
}

/// Live LTP cell for orders - subscribes to WebSocket stream
/// Matches the _OrderLTPCell pattern from the main orders page
class _ScalperOrderLTPCell extends ConsumerStatefulWidget {
  final String token;
  final String initialLtp;

  const _ScalperOrderLTPCell({
    required this.token,
    required this.initialLtp,
  });

  @override
  ConsumerState<_ScalperOrderLTPCell> createState() =>
      _ScalperOrderLTPCellState();
}

class _ScalperOrderLTPCellState extends ConsumerState<_ScalperOrderLTPCell> {
  late String ltp;
  StreamSubscription? _subscription;
  bool _didSetupSubscription = false;

  @override
  void initState() {
    super.initState();
    ltp = widget.initialLtp;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didSetupSubscription && widget.token.isNotEmpty) {
      _didSetupSubscription = true;

      // Check existing socket data first (tokens may already be subscribed)
      final existingData = ref.read(websocketProvider).socketDatas;
      if (existingData.containsKey(widget.token)) {
        final existingLtp = existingData[widget.token]['lp']?.toString();
        if (existingLtp != null &&
            existingLtp != '0.00' &&
            existingLtp != 'null' &&
            existingLtp != '0') {
          ltp = existingLtp;
        }
      }

      // Subscribe for future updates
      Future.microtask(() {
        if (!mounted) return;

        _subscription =
            ref.read(websocketProvider).socketDataStream.listen((data) {
          if (!mounted || !data.containsKey(widget.token)) return;

          final newLtp = data[widget.token]['lp']?.toString();
          if (newLtp != null &&
              newLtp != ltp &&
              newLtp != '0.00' &&
              newLtp != 'null') {
            setState(() => ltp = newLtp);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        ltp,
        style: MyntWebTextStyles.tableCell(
          context,
          darkColor: MyntColors.textPrimaryDark,
          lightColor: MyntColors.textPrimary,
          fontWeight: MyntFonts.medium,
        ),
      ),
    );
  }
}

/// GTT dialog for setting / editing Stoploss or Target trigger price
class _ScalperGttDialog extends ConsumerStatefulWidget {
  final PositionBookModel position;
  final String gttType; // 'stoploss' or 'target'
  final GttOrderBookModel? existingGtt;

  const _ScalperGttDialog({
    required this.position,
    required this.gttType,
    this.existingGtt,
  });

  @override
  ConsumerState<_ScalperGttDialog> createState() => _ScalperGttDialogState();
}

class _ScalperGttDialogState extends ConsumerState<_ScalperGttDialog> {
  final _triggerController = TextEditingController();
  final _percentageController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;
  bool _isSyncing = false; // prevents infinite listener loops

  bool get _isEditing => widget.existingGtt != null;
  bool get _isStoploss => widget.gttType == 'stoploss';

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _triggerController.text = widget.existingGtt!.d ?? '';
      // Back-calculate percentage from existing trigger price
      _syncPercentageFromTrigger();
    }
    _percentageController.addListener(_onPercentageChanged);
    _triggerController.addListener(_onTriggerChanged);
  }

  @override
  void dispose() {
    _percentageController.removeListener(_onPercentageChanged);
    _triggerController.removeListener(_onTriggerChanged);
    _percentageController.dispose();
    _triggerController.dispose();
    super.dispose();
  }

  /// Tick size from position data (defaults to 0.05 for options)
  double get _tickSize {
    final ti = double.tryParse(widget.position.ti ?? '');
    return (ti != null && ti > 0) ? ti : 0.05;
  }

  double get _avgPrice =>
      double.tryParse(widget.position.avgPrc ?? '0') ?? 0;

  /// Round a price to the nearest tick
  double _roundToTick(double price) {
    final tick = _tickSize;
    return (price / tick).round() * tick;
  }

  /// Percentage → Trigger: calculate trigger price from avg + percentage
  void _onPercentageChanged() {
    if (_isSyncing) return;
    final pctText = _percentageController.text.trim();
    if (pctText.isEmpty) {
      _isSyncing = true;
      _triggerController.text = '';
      _isSyncing = false;
      return;
    }
    final pct = int.tryParse(pctText);
    if (pct == null || pct <= 0) return;
    if (_avgPrice <= 0) return;

    final netqty = int.tryParse(widget.position.netqty?.toString() ?? '0') ?? 0;
    final isLong = netqty > 0;

    // SL: below avg for long, above avg for short
    // Target: above avg for long, below avg for short
    final goesUp = _isStoploss ? !isLong : isLong;
    final rawPrice = goesUp
        ? _avgPrice * (1 + pct / 100)
        : _avgPrice * (1 - pct / 100);

    final rounded = _roundToTick(rawPrice);
    _isSyncing = true;
    _triggerController.text = rounded.toStringAsFixed(2);
    _isSyncing = false;
  }

  /// Trigger → Percentage: back-calculate percentage from trigger price
  void _onTriggerChanged() {
    if (_isSyncing) return;
    _syncPercentageFromTrigger();
  }

  void _syncPercentageFromTrigger() {
    final triggerText = _triggerController.text.trim();
    if (triggerText.isEmpty || _avgPrice <= 0) {
      _isSyncing = true;
      _percentageController.text = '';
      _isSyncing = false;
      return;
    }
    final triggerVal = double.tryParse(triggerText);
    if (triggerVal == null || triggerVal <= 0) return;

    final pct = ((triggerVal - _avgPrice) / _avgPrice * 100).abs();
    final rounded = pct.round();
    if (rounded <= 0) {
      _isSyncing = true;
      _percentageController.text = '';
      _isSyncing = false;
      return;
    }
    _isSyncing = true;
    _percentageController.text = rounded.toString();
    _isSyncing = false;
  }

  /// Arrow ↑/↓ on trigger field: adjust by tick size
  void _adjustTrigger(int direction) {
    final current = double.tryParse(_triggerController.text.trim()) ?? 0;
    final newPrice = _roundToTick(current + direction * _tickSize);
    if (newPrice <= 0) return;
    _triggerController.text = newPrice.toStringAsFixed(2);
  }

  /// Arrow ↑/↓ on percentage field: adjust by 1
  void _adjustPercentage(int direction) {
    final current = int.tryParse(_percentageController.text.trim()) ?? 0;
    final newPct = current + direction;
    if (newPct < 0) return;
    _percentageController.text = newPct.toString();
  }

  Future<void> _handleSubmit() async {
    final triggerPrice = _triggerController.text.trim();
    if (triggerPrice.isEmpty) {
      setState(() => _errorText = 'Enter a trigger price');
      return;
    }
    final price = double.tryParse(triggerPrice);
    if (price == null || price <= 0) {
      setState(() => _errorText = 'Enter a valid price');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final position = widget.position;
      final netqty = int.tryParse(position.netqty?.toString() ?? '0') ?? 0;
      final isLong = netqty > 0;
      final absQty = netqty.abs();

      // Determine alert type based on SL/Target and position direction
      String ait;
      if (_isStoploss) {
        ait = isLong ? 'LTP_B_O' : 'LTP_A_O';
      } else {
        ait = isLong ? 'LTP_A_O' : 'LTP_B_O';
      }

      final trantype = isLong ? 'S' : 'B';

      final input = PlaceGTTOrderInput(
        tsym: position.tsym ?? '',
        exch: position.exch ?? '',
        ait: ait,
        validity: 'GTT',
        d: triggerPrice,
        remarks: '',
        trantype: trantype,
        prctyp: 'MKT',
        prd: position.prd ?? 'I',
        ret: 'DAY',
        qty: absQty.toString(),
        prc: '0',
        alid: widget.existingGtt?.alId ?? '',
        trgprc: '0',
      );

      final orderProv = ref.read(orderProvider);
      if (_isEditing) {
        await orderProv.modifyGTTOrder(input, context);
      } else {
        await orderProv.placeGTTOrder(input, context);
      }

      // Refresh GTT orders in scalper provider
      if (mounted) {
        await ref.read(scalperProvider).fetchGttOrders(context);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Failed to ${_isEditing ? 'modify' : 'place'} GTT order';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    final instrumentName = (position.dname ?? position.tsym ?? '')
        .replaceAll('-EQ', '')
        .trim();
    final netqty = int.tryParse(position.netqty?.toString() ?? '0') ?? 0;
    final absQty = netqty.abs();
    final isLong = netqty > 0;

    // Get real-time LTP from websocket
    final socketData = position.token != null
        ? ref.watch(websocketProvider).socketDatas[position.token]
        : null;
    final ltp = socketData?['lp']?.toString() ?? position.lp ?? '0.00';

    final title = _isEditing
        ? 'Edit ${_isStoploss ? 'Stoploss' : 'Target'}'
        : 'Set ${_isStoploss ? 'Stoploss' : 'Target'}';

    final hintText = _isStoploss
        ? (isLong
            ? 'Triggers sell when LTP falls below this price'
            : 'Triggers buy when LTP rises above this price')
        : (isLong
            ? 'Triggers sell when LTP rises above this price'
            : 'Triggers buy when LTP falls below this price');

    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondaryColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final accentColor = _isStoploss
        ? resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.tertiary)
        : resolveThemeColor(context,
            dark: MyntColors.secondary, light: MyntColors.primary);

    return PointerInterceptor(
      child: Center(
        child: shadcn.Card(
          borderRadius: BorderRadius.circular(8),
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: borderColor),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: MyntWebTextStyles.title(
                          context,
                          color: textColor,
                        ),
                      ),
                      MyntCloseButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Symbol info row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  instrumentName,
                                  style: MyntWebTextStyles.body(
                                    context,
                                    fontWeight: MyntFonts.semiBold,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Qty: $absQty',
                                      style: MyntWebTextStyles.exch(
                                        context,
                                        color: secondaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'LTP: $ltp',
                                      style: MyntWebTextStyles.exch(
                                        context,
                                        color: secondaryColor,
                                      ),
                                    ),
                                    // const SizedBox(width: 16),
                                    // Container(
                                    //   padding: const EdgeInsets.symmetric(
                                    //       horizontal: 6, vertical: 1),
                                    //   decoration: BoxDecoration(
                                    //     color: isLong
                                    //         ? resolveThemeColor(context,
                                    //                 dark: MyntColors.profitDark,
                                    //                 light: MyntColors.profit)
                                    //             .withValues(alpha: 0.15)
                                    //         : resolveThemeColor(context,
                                    //                 dark: MyntColors.lossDark,
                                    //                 light: MyntColors.loss)
                                    //             .withValues(alpha: 0.15),
                                    //     borderRadius: BorderRadius.circular(4),
                                    //   ),
                                    //   child: Text(
                                    //     isLong ? 'LONG' : 'SHORT',
                                    //     style: MyntWebTextStyles.exch(
                                    //       context,
                                    //       fontWeight: MyntFonts.regular,
                                    //       color: isLong
                                    //           ? resolveThemeColor(context,
                                    //               dark: MyntColors.profitDark,
                                    //               light: MyntColors.profit)
                                    //           : resolveThemeColor(context,
                                    //               dark: MyntColors.lossDark,
                                    //               light: MyntColors.loss),
                                    //     ),
                                    //   ),
                                    // ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Trigger price + Percentage row (bidirectional)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Trigger price input
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trigger Price',
                                  style: MyntWebTextStyles.body(
                                    context,
                                    fontWeight: MyntFonts.medium,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 40,
                                  child: Focus(
                                    onKeyEvent: (node, event) {
                                      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                                        return KeyEventResult.ignored;
                                      }
                                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                        _adjustTrigger(1);
                                        return KeyEventResult.handled;
                                      }
                                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                        _adjustTrigger(-1);
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: MyntTextField(
                                      controller: _triggerController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                                      ],
                                      textAlign: TextAlign.center,
                                      placeholder: '0.00',
                                      backgroundColor: resolveThemeColor(context,
                                        dark: const Color(0xFF2A2A2A),
                                        light: const Color(0xFFF1F3F8),
                                      ),
                                      textStyle: MyntWebTextStyles.body(
                                        context,
                                        fontWeight: MyntFonts.semiBold,
                                        color: textColor,
                                      ),
                                      onSubmitted: (_) => _handleSubmit(),
                                    ),
                                  ),
                                ),
                                if (_errorText != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _errorText!,
                                    style: MyntWebTextStyles.caption(
                                      context,
                                      fontWeight: FontWeight.w500,
                                      color: resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Percentage input
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '% of Avg (${position.avgPrc ?? "0.00"})',
                                  style: MyntWebTextStyles.body(
                                    context,
                                    fontWeight: MyntFonts.medium,
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 40,

                                  child: Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                                      return KeyEventResult.ignored;
                                    }
                                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                      _adjustPercentage(1);
                                      return KeyEventResult.handled;
                                    }
                                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                      _adjustPercentage(-1);
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  
                                  child: MyntTextField(
                                    controller: _percentageController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    textAlign: TextAlign.center,
                                    backgroundColor: resolveThemeColor(context,
                                      dark: const Color(0xFF2A2A2A),
                                      light: const Color(0xFFF1F3F8),
                                    ),
                                    textStyle: MyntWebTextStyles.body(
                                      context,
                                      fontWeight: MyntFonts.semiBold,
                                      color: textColor,
                                    ),
                                    placeholder: '%',
                                    onSubmitted: (_) => _handleSubmit(),
                                  ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tick: $_tickSize — price rounded to nearest tick',
                        style: MyntWebTextStyles.caption(
                          context,
                          color: secondaryColor.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Hint text
                      Text(
                        hintText,
                        style: MyntWebTextStyles.caption(
                          context,
                          color: secondaryColor.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // GTT note
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: MyntWebTextStyles.caption(
                              context,
                              color: secondaryColor,
                            ),
                            children: [
                              TextSpan(
                                text: 'Note: ',
                                style: MyntWebTextStyles.caption(
                                  context,
                                  fontWeight: MyntFonts.semiBold,
                                  color: textColor,
                                ),
                              ),
                              TextSpan(
                                text: _isStoploss
                                    ? 'Stoploss is placed as a GTT order. Remember to cancel it if you exit the position manually.'
                                    : 'Trigger is placed as a GTT order. Remember to cancel it if you exit the position manually.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Submit button
                      SizedBox(
                        height: 45,
                        child: MyntButton(
                          type: MyntButtonType.primary,
                          size: MyntButtonSize.large,
                          label: _isEditing ? 'Update' : 'Submit',
                          isFullWidth: true,
                          isLoading: _isLoading,
                          backgroundColor: accentColor,
                          onPressed: _isLoading ? null : _handleSubmit,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Exit position dialog - matches ExitAllPositionsDialogWeb design
class _ScalperExitPositionDialog extends ConsumerStatefulWidget {
  final List<PositionBookModel> positions;
  final bool isExitAll;

  const _ScalperExitPositionDialog({
    required this.positions,
    required this.isExitAll,
  });

  @override
  ConsumerState<_ScalperExitPositionDialog> createState() =>
      _ScalperExitPositionDialogState();
}

class _ScalperExitPositionDialogState
    extends ConsumerState<_ScalperExitPositionDialog> {
  bool _isLoading = false;

  Future<void> _handleExit() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final positionBook = ref.read(portfolioProvider);
      final scalper = ref.read(scalperProvider);

      if (widget.isExitAll) {
        // Select all and exit (uses provider's built-in exit all)
        positionBook.selectExitAllPosition(true);
        await positionBook.exitPosition(context, true);
      } else {
        // Mark specific positions for exit, then call exitPosition
        // First reset, then select only our positions
        positionBook.resetExitPositionSelection();

        final allPositions = positionBook.allPostionList;
        for (final pos in widget.positions) {
          final idx = allPositions.indexOf(pos);
          if (idx >= 0) {
            positionBook.selectExitPosition(idx);
          }
        }
        await positionBook.exitPosition(context, false);
      }

      // Auto-cancel GTT orders for exited positions
      for (final pos in widget.positions) {
        if (pos.token != null && pos.token!.isNotEmpty) {
          await scalper.cancelAllGttForPosition(pos.token!, context);
        }
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.positions.length;
    final isSingle = count == 1 && !widget.isExitAll;
    final instrumentName = isSingle
        ? (widget.positions.first.dname ?? widget.positions.first.tsym ?? '')
            .replaceAll('-EQ', '')
            .trim()
        : '';

    // Check if any position has active GTT orders
    final scalper = ref.read(scalperProvider);
    final hasActiveGtt = widget.positions.any((pos) =>
        pos.token != null && scalper.getPositionGttOrders(pos.token!).isNotEmpty);

    return PointerInterceptor(
      child: Center(
        child: shadcn.Card(
          borderRadius: BorderRadius.circular(8),
          padding: EdgeInsets.zero,
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: shadcn.Theme.of(context).colorScheme.border,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.isExitAll ? 'Exit All Positions' : 'Exit Position',
                        style: MyntWebTextStyles.title(
                          context,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),
                      MyntCloseButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          isSingle
                              ? 'Are you sure you want to exit $instrumentName?'
                              : 'Are you sure you want to square off all $count open positions?',
                          textAlign: TextAlign.center,
                          style: MyntWebTextStyles.body(
                            context,
                            fontWeight: FontWeight.w500,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                        ),
                        if (hasActiveGtt) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.isExitAll
                                ? 'Active GTT (SL/Target) orders will also be cancelled.'
                                : 'Active GTT orders for this position will also be cancelled.',
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.bodySmall(
                              context,
                              fontWeight: FontWeight.w500,
                               color: resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        MyntButton(
                          type: MyntButtonType.primary,
                          size: MyntButtonSize.large,
                          label: 'Exit Order',
                          isFullWidth: true,
                          isLoading: _isLoading,
                          backgroundColor: resolveThemeColor(
                            context,
                            dark: MyntColors.lossDark,
                            light: MyntColors.tertiary,
                          ),
                          onPressed: _isLoading ? null : _handleExit,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cancel orders dialog - matching exit all positions dialog design
class _ScalperCancelOrdersDialog extends ConsumerStatefulWidget {
  final List<OrderBookModel> orders;
  final bool isCancelAll;

  const _ScalperCancelOrdersDialog({
    required this.orders,
    required this.isCancelAll,
  });

  @override
  ConsumerState<_ScalperCancelOrdersDialog> createState() =>
      _ScalperCancelOrdersDialogState();
}

class _ScalperCancelOrdersDialogState
    extends ConsumerState<_ScalperCancelOrdersDialog> {
  bool _isLoading = false;

  Future<void> _handleCancel() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final orderProv = ref.read(orderProvider);

      for (final order in widget.orders) {
        final orderNo = order.norenordno?.toString() ?? '';
        if (orderNo.isEmpty) continue;

        if ((order.sPrdtAli == 'BO' || order.sPrdtAli == 'CO') &&
            order.snonum != null) {
          await orderProv.fetchExitSNOOrd(
            order.snonum.toString(),
            order.prd.toString(),
            context,
            false,
          );
        } else {
          await orderProv.fetchOrderCancel(orderNo, context, false);
        }
      }

      // Refresh order book
      await orderProv.fetchOrderBook(context, true);

      if (mounted) {
        Navigator.of(context).pop();
        ResponsiveSnackBar.showSuccess(
          context,
          widget.isCancelAll
              ? 'All open orders cancelled'
              : 'Order cancelled',
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.orders.length;
    final isSingle = count == 1 && !widget.isCancelAll;
    final instrumentName = isSingle
        ? (widget.orders.first.dname ?? widget.orders.first.tsym ?? '')
            .replaceAll('-EQ', '')
            .trim()
        : '';

    return PointerInterceptor(
      child: Center(
        child: shadcn.Card(
          borderRadius: BorderRadius.circular(8),
          padding: EdgeInsets.zero,
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 250),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: shadcn.Theme.of(context).colorScheme.border,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.isCancelAll ? 'Cancel All Orders' : 'Cancel Order',
                        style: MyntWebTextStyles.title(
                          context,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),
                      MyntCloseButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          isSingle
                              ? 'Are you sure you want to cancel the order for $instrumentName?'
                              : 'Are you sure you want to cancel all $count open orders?',
                          textAlign: TextAlign.center,
                          style: MyntWebTextStyles.body(
                            context,
                            fontWeight: FontWeight.w500,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        MyntButton(
                          type: MyntButtonType.primary,
                          size: MyntButtonSize.large,
                          label: widget.isCancelAll ? 'Cancel All' : 'Cancel Order',
                          isFullWidth: true,
                          isLoading: _isLoading,
                          backgroundColor: resolveThemeColor(
                            context,
                            dark: MyntColors.lossDark,
                            light: MyntColors.tertiary,
                          ),
                          onPressed: _isLoading ? null : _handleCancel,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
