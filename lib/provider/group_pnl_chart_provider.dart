import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../api/core/api_export.dart';
import '../locator/locator.dart';
import '../models/marketwatch_model/tpseries.dart';
import '../models/order_book_model/trade_book_model.dart';
import '../models/portfolio_model/group_pnl_chart_model.dart';

final groupPnlChartProvider =
    ChangeNotifierProvider((ref) => GroupPnlChartProvider());

/// Group P&L chart provider — API-cached, socket-driven live extension.
///
/// On open: fetch trade book + 1-min candles for the group's positions,
/// build the cached settled series. Render.
///
/// While open: a 60-second timer appends synthetic minute snapshots from
/// the latest socket LTPs into a TRANSIENT `_socketPoints` list. These are
/// shown on the chart but NOT cached. Live tip continues to move with every
/// websocket tick.
///
/// On close: timer cancelled, transient socket state cleared. The cache
/// (API-derived `settled`, `lastSettledEpoch`, `settledPeak`) is preserved.
///
/// On reopen: API fetches the gap from the cached `lastSettledEpoch` to
/// now, ONLY if at least 60s have passed since the last cached candle.
/// Brief reopens hit cache with zero API calls. Trade book refetched only
/// if the qty signature changed. Full rebuild only if the group's position
/// set changed.
class GroupPnlChartProvider extends ChangeNotifier {
  final _api = locator<ApiExporter>();

  // ─── Display state ───
  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  String _interval = '5';
  String get interval => _interval;

  String? _activeGroupName;
  String? get activeGroupName => _activeGroupName;

  String? _activeBaseKey;

  List<GroupPnlDataPoint> _dataPoints = [];
  List<GroupPnlDataPoint> get dataPoints => _dataPoints;

  List<Map<String, dynamic>> _positions = [];

  // ─── Caches ───
  final Map<String, List<Data>> _tpCacheOneMin = {};
  final Map<String, _CanonicalSeries> _canonicalSeriesCache = {};
  final Map<String, _PositionTimeline> _timelineMap = {};
  bool _tradeBookFetched = false;

  // ─── Lifecycle ───
  bool _dialogOpen = false;
  bool get isOpen => _dialogOpen;
  Timer? _socketTimer;
  Timer? _notifyDebounce;

  // ─── Transient (not cached): socket-driven minute snapshots taken
  // while the dialog is open. Reset every open session. ───
  final List<GroupPnlDataPoint> _socketPoints = [];
  double _socketPeak = double.negativeInfinity;
  int _lastSocketEpoch = 0;

  // ─── Summary getters ───

  double get currentPnl {
    final c = _activeCanonical;
    if (c == null) return 0;
    if (c.liveTip != null) return c.liveTip!.pnl;
    if (_socketPoints.isNotEmpty) return _socketPoints.last.pnl;
    if (c.settled.isNotEmpty) return c.settled.last.pnl;
    return 0;
  }

  double get peak {
    final c = _activeCanonical;
    if (c == null) return 0;
    final candidates = <double>[];
    if (c.settledPeak != double.negativeInfinity) {
      candidates.add(c.settledPeak);
    }
    if (_socketPeak != double.negativeInfinity) {
      candidates.add(_socketPeak);
    }
    if (c.liveTip != null) candidates.add(c.liveTip!.pnl);
    if (candidates.isEmpty) return 0;
    return candidates.reduce(max);
  }

  double get drawdown {
    final c = _activeCanonical;
    if (c == null) return 0;
    return currentPnl - peak;
  }

  _CanonicalSeries? get _activeCanonical =>
      _activeBaseKey == null ? null : _canonicalSeriesCache[_activeBaseKey];

  // ─── Public API ───

  Future<void> loadGroupChart({
    required String groupName,
    required List groupList,
    required bool isDay,
    required bool isNetPnl,
    String interval = '5',
  }) async {
    final groupChanged = _activeGroupName != groupName;
    _activeGroupName = groupName;
    _interval = interval;
    _dialogOpen = true;
    _positions = groupList
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Group switch: only refresh the trade book flag. Per-group canonical,
    // candle, and timeline caches survive — they're keyed appropriately
    // (canonical by group, candles by token, timeline by token+prd) and can
    // be reused if the user comes back to a previous group.
    if (groupChanged) {
      _tradeBookFetched = false;
    }

    final baseKey = _baseCacheKey(groupName, isDay, isNetPnl);
    _activeBaseKey = baseKey;

    var existing = _canonicalSeriesCache[baseKey];

    // A previously-cached canonical with `lastSettledEpoch == 0` means the
    // initial fetch returned no candles (API failure / no candles yet).
    // Don't try the incremental path against epoch 0 — drop it and rebuild.
    if (existing != null && existing.lastSettledEpoch == 0) {
      _canonicalSeriesCache.remove(baseKey);
      existing = null;
    }

    // If the group's position set has changed since we cached the canonical
    // (e.g., a new strike joined the same-underlying group), the cached
    // settled curve is wrong because it was summed over a different set.
    // Drop it and fall through to a full rebuild.
    if (existing != null) {
      final cachedKeys = existing.positionCorrections.keys.toSet();
      final currentKeys = _positions
          .map((p) =>
              '${p['token']?.toString() ?? ''}|${p['prd']?.toString() ?? ''}')
          .toSet();
      if (cachedKeys.length != currentKeys.length ||
          !cachedKeys.containsAll(currentKeys)) {
        _canonicalSeriesCache.remove(baseKey);
        _tradeBookFetched = false;
        existing = null;
      }
    }

    // If the qty signature has changed since the canonical was built, a
    // trade has filled. The cached per-position `correction` was computed
    // against the pre-trade timeline; reusing it would leave a constant
    // offset on the historical curve (especially visible after closing a
    // position). Invalidate and let the initial branch rebuild correction
    // against the post-trade timeline. Candle cache survives.
    if (existing != null && _computeQtySig() != existing.lastQtySig) {
      _canonicalSeriesCache.remove(baseKey);
      _tradeBookFetched = false;
      existing = null;
    }

    // Fresh open session: drop any transient socket points from a prior
    // session. Cache (API-derived) is preserved.
    _socketPoints.clear();
    _socketPeak = double.negativeInfinity;
    _lastSocketEpoch = 0;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      if (existing == null) {
        await _fetchTradeInfo();
        await _fetchOneMinFromMarketOpen();
        final canonical =
            _buildInitialCanonical(isDay: isDay, isNetPnl: isNetPnl);
        canonical.lastQtySig = _computeQtySig();
        _canonicalSeriesCache[baseKey] = canonical;
        _refreshLiveTipFromCurrentPnl(canonical, isNetPnl: isNetPnl);
        _dataPoints = _downsample(canonical, _interval);
      } else {
        // Reopen path: sig was already verified equal above, so no trade
        // book refetch. Skip candle gap fetch if less than 60s since the
        // last cached candle (no new candle would exist anyway).
        final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (nowEpoch - existing.lastSettledEpoch >= 60) {
          await _fetchOneMinIncremental(existing.lastSettledEpoch);
          _appendIncremental(existing, isDay: isDay, isNetPnl: isNetPnl);
        }
        _refreshLiveTipFromCurrentPnl(existing, isNetPnl: isNetPnl);
        _dataPoints = _downsample(existing, _interval);
      }
    } catch (e) {
      _error = 'Failed to load chart data';
      if (existing != null) {
        _refreshLiveTipFromCurrentPnl(existing, isNetPnl: isNetPnl);
        _dataPoints = _downsample(existing, _interval);
        _error = null;
      }
    } finally {
      _loading = false;
    }

    // The dialog may have been closed while we were awaiting the API.
    // Don't start a timer for a dialog that no longer exists.
    if (_dialogOpen) {
      _startSocketTimer(isNetPnl: isNetPnl);
    }
    notifyListeners();
  }

  Future<void> switchInterval({
    required String newInterval,
    required bool isDay,
    required bool isNetPnl,
  }) async {
    if (newInterval == _interval) return;
    _interval = newInterval;
    final c = _activeCanonical;
    if (c == null) return;
    _dataPoints = _downsample(c, _interval);
    notifyListeners();
  }

  /// WebSocket LTP update — touches only the live tip. Never mutates
  /// `settled`, `lastSettledEpoch`, or `settledPeak`. A bad tick is bounded
  /// to this single point and is overwritten by the next minute-roll settle
  /// or reopen incremental fetch.
  void onTickUpdate({
    required String token,
    required String ltp,
    required bool isDay,
    required bool isNetPnl,
  }) {
    if (!_dialogOpen) return;
    final c = _activeCanonical;
    if (c == null) return;

    bool updated = false;
    for (var pos in _positions) {
      if (pos['token']?.toString() != token) continue;

      final oldLp = double.tryParse(pos['lp']?.toString() ?? '0') ?? 0.0;
      final newLp = double.tryParse(ltp) ?? 0.0;
      if (oldLp == newLp) continue;

      final netQty =
          (int.tryParse(pos['netqty']?.toString() ?? '0') ?? 0).toDouble();
      final prcFtr =
          double.tryParse(pos['prcftr']?.toString() ?? '1.0') ?? 1.0;
      final mult = double.tryParse(pos['mult']?.toString() ?? '1.0') ?? 1.0;
      final pnlDelta = netQty * prcFtr * mult * (newLp - oldLp);

      pos['lp'] = ltp;
      // Store pnl as raw double to avoid cumulative paisa-level rounding
      // from toStringAsFixed(2) round-trips on every tick. Readers parse
      // via .toString() + tryParse which works for both String (initial
      // groupList values) and double (after first tick).
      final oldPnl =
          double.tryParse(pos['profitNloss']?.toString() ?? '0') ?? 0.0;
      final oldMtm = double.tryParse(pos['mTm']?.toString() ?? '0') ?? 0.0;
      pos['profitNloss'] = oldPnl + pnlDelta;
      pos['mTm'] = oldMtm + pnlDelta;
      updated = true;
    }
    if (!updated) return;

    // Refresh live tip cheaply on every tick (sub-millisecond), but
    // coalesce UI rebuilds. On a busy minute a liquid contract can fire
    // 10+ ticks/sec — we cap chart redraws at ~4/sec to keep CPU bounded.
    _refreshLiveTipFromCurrentPnl(c, isNetPnl: isNetPnl);
    _scheduleTickNotify();
  }

  void _scheduleTickNotify() {
    if (_notifyDebounce != null) return;
    _notifyDebounce = Timer(const Duration(milliseconds: 250), () {
      _notifyDebounce = null;
      final c = _activeCanonical;
      if (c != null) _dataPoints = _downsample(c, _interval);
      notifyListeners();
    });
  }

  /// Called from the dialog's `dispose`. Stops the socket timer, clears
  /// transient socket state, and nulls the live tip. Cache untouched.
  void markDialogClosed() {
    _dialogOpen = false;
    _socketTimer?.cancel();
    _socketTimer = null;
    _notifyDebounce?.cancel();
    _notifyDebounce = null;
    _socketPoints.clear();
    _socketPeak = double.negativeInfinity;
    _lastSocketEpoch = 0;
    final c = _activeCanonical;
    if (c != null) c.liveTip = null;
  }

  void clearCache() {
    _socketTimer?.cancel();
    _socketTimer = null;
    _notifyDebounce?.cancel();
    _notifyDebounce = null;
    _socketPoints.clear();
    _socketPeak = double.negativeInfinity;
    _lastSocketEpoch = 0;
    _tpCacheOneMin.clear();
    _canonicalSeriesCache.clear();
    _timelineMap.clear();
    _tradeBookFetched = false;
    _dataPoints = [];
    _activeGroupName = null;
    _activeBaseKey = null;
    _positions = [];
    _dialogOpen = false;
  }

  @override
  void dispose() {
    _socketTimer?.cancel();
    _notifyDebounce?.cancel();
    super.dispose();
  }

  // ─── Internals: lifecycle ───

  String _baseCacheKey(String group, bool isDay, bool isNetPnl) =>
      '$group|$isDay|$isNetPnl';

  /// Aggregate quantity signature: sum of trade-side qty fields across all
  /// positions in the group. Monotonically increases as new trades fill, so
  /// a change between two reads means a new trade happened. Used to gate
  /// trade book refetch.
  int _computeQtySig() {
    int sig = 0;
    for (final pos in _positions) {
      sig += int.tryParse(pos['daybuyqty']?.toString() ?? '0') ?? 0;
      sig += int.tryParse(pos['daysellqty']?.toString() ?? '0') ?? 0;
      sig += int.tryParse(pos['cfbuyqty']?.toString() ?? '0') ?? 0;
      sig += int.tryParse(pos['cfsellqty']?.toString() ?? '0') ?? 0;
    }
    return sig;
  }

  void _startSocketTimer({required bool isNetPnl}) {
    _socketTimer?.cancel();
    _socketTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _socketSettleTick(isNetPnl: isNetPnl);
    });
  }

  /// Once a minute, snapshot the current socket-driven LTPs (sitting in
  /// `_positions[i]['lp']`) as a synthetic settled point. NEVER writes to
  /// `_canonicalSeriesCache` — these points live only in `_socketPoints`
  /// and are discarded on close. No API calls.
  void _socketSettleTick({required bool isNetPnl}) {
    if (!_dialogOpen) return;
    final c = _activeCanonical;
    if (c == null) return;

    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final boundaryEpoch = (nowEpoch ~/ 60) * 60;
    // Don't add a duplicate point for the same minute.
    if (boundaryEpoch <= _lastSocketEpoch) return;
    // Don't add a synthetic point that overlaps cached settled history.
    if (boundaryEpoch <= c.lastSettledEpoch) return;

    final posCalcs = _buildPosCalcs(isNetPnl: isNetPnl);
    // Reuse cached corrections so the synthetic curve aligns with the
    // cached settled history.
    for (final pc in posCalcs) {
      pc.correction = c.positionCorrections[pc.posKey] ?? 0;
    }

    double groupPnl = 0;
    bool any = false;
    for (final pc in posCalcs) {
      if (boundaryEpoch < pc.entryEpoch) continue;
      double lp =
          double.tryParse(_lpForToken(pc.posKey).toString()) ?? double.nan;
      // Fallback: if the token hasn't ticked yet (LP is 0 or unparseable),
      // use its last cached candle close so we don't drop the position from
      // the synthetic point — that would create a visible kink.
      if (lp.isNaN || lp == 0) {
        if (pc.candles.isNotEmpty) {
          lp = double.tryParse(pc.candles.last.intc ?? '0') ?? 0;
        }
        if (lp.isNaN || lp == 0) continue;
      }
      if (pc.timeline.snapshots.isNotEmpty) {
        groupPnl += pc.timeline.pnlAtTime(boundaryEpoch, lp, pc.prcFtr,
                pc.mult) +
            pc.correction;
      } else {
        groupPnl += pc.currentPnl;
      }
      any = true;
    }
    if (!any) return;

    if (_socketPeak == double.negativeInfinity) {
      _socketPeak = c.settledPeak == double.negativeInfinity
          ? groupPnl
          : max(c.settledPeak, groupPnl);
    } else {
      _socketPeak = max(_socketPeak, groupPnl);
    }
    _lastSocketEpoch = boundaryEpoch;

    _socketPoints.add(GroupPnlDataPoint(
      time: DateTime.fromMillisecondsSinceEpoch(boundaryEpoch * 1000),
      pnl: groupPnl,
      peak: _socketPeak,
      drawdown: groupPnl - _socketPeak,
    ));

    _refreshLiveTipFromCurrentPnl(c, isNetPnl: isNetPnl);
    _dataPoints = _downsample(c, _interval);
    notifyListeners();
  }

  /// Look up the current LTP for a position key (token|prd) from
  /// `_positions`. Falls back to "" if not found.
  Object _lpForToken(String posKey) {
    for (final pos in _positions) {
      final key =
          '${pos['token']?.toString() ?? ''}|${pos['prd']?.toString() ?? ''}';
      if (key == posKey) return pos['lp'] ?? '';
    }
    return '';
  }

  // ─── Internals: API fetches ───

  Future<void> _fetchOneMinFromMarketOpen() async {
    final now = DateTime.now();
    final endEpoch = now.millisecondsSinceEpoch ~/ 1000;
    final futures = <Future>[];
    for (var pos in _positions) {
      final token = pos['token']?.toString() ?? '';
      final exch = pos['exch']?.toString() ?? 'NFO';
      if (token.isEmpty) continue;
      if (_tpCacheOneMin.containsKey(token) &&
          _tpCacheOneMin[token]!.isNotEmpty) {
        continue;
      }
      final entryEpoch = _getTimeline(pos).entryEpoch;
      futures.add(_fetchAndCacheOneMin(token, exch, entryEpoch, endEpoch));
    }
    if (futures.isNotEmpty) await Future.wait(futures);
  }

  Future<void> _fetchOneMinIncremental(int sinceEpoch) async {
    final now = DateTime.now();
    final endEpoch = now.millisecondsSinceEpoch ~/ 1000;
    if (endEpoch <= sinceEpoch) return;
    final futures = <Future>[];
    for (var pos in _positions) {
      final token = pos['token']?.toString() ?? '';
      final exch = pos['exch']?.toString() ?? 'NFO';
      if (token.isEmpty) continue;
      futures.add(_fetchAndAppendOneMin(token, exch, sinceEpoch, endEpoch));
    }
    if (futures.isNotEmpty) await Future.wait(futures);
  }

  Future<void> _fetchAndCacheOneMin(
      String token, String exchange, int startEpoch, int endEpoch) async {
    try {
      final result = await _api.getTPSeriesChart(
        exchange: exchange,
        token: token,
        interval: '1',
        startEpoch: startEpoch,
        endEpoch: endEpoch,
      );
      _tpCacheOneMin[token] = result.data ?? [];
    } catch (_) {
      _tpCacheOneMin[token] = [];
    }
  }

  Future<void> _fetchAndAppendOneMin(
      String token, String exchange, int startEpoch, int endEpoch) async {
    try {
      final result = await _api.getTPSeriesChart(
        exchange: exchange,
        token: token,
        interval: '1',
        startEpoch: startEpoch,
        endEpoch: endEpoch,
      );
      final newCandles = result.data ?? [];
      final existing = _tpCacheOneMin[token] ?? [];
      // Drop any candle whose epoch <= startEpoch to avoid duplicating the
      // boundary candle that already lives in `existing`.
      final filtered = newCandles.where((c) {
        final epoch = int.tryParse(c.ssboe ?? '0') ?? 0;
        return epoch > startEpoch;
      }).toList();
      _tpCacheOneMin[token] = [...existing, ...filtered];
    } catch (_) {
      // Keep prior data; surface no error so user keeps seeing the chart.
    }
  }

  // ─── Internals: trade timeline ───

  Future<void> _fetchTradeInfo() async {
    if (_tradeBookFetched) return;

    final now = DateTime.now();
    final marketOpenEpoch =
        DateTime(now.year, now.month, now.day, 9, 15).millisecondsSinceEpoch ~/
            1000;

    final posKeys = <String>{};
    for (var pos in _positions) {
      final token = pos['token']?.toString() ?? '';
      final prd = pos['prd']?.toString() ?? '';
      posKeys.add('$token|$prd');
    }

    final tradesPerKey = <String, List<TradeBookModel>>{};
    try {
      final response = await _api.getTradeBook();
      final allTrades = response['data'] as List<TradeBookModel>? ?? [];
      for (var trade in allTrades) {
        final key = '${trade.token ?? ''}|${trade.prd ?? ''}';
        if (!posKeys.contains(key)) continue;
        tradesPerKey.putIfAbsent(key, () => []).add(trade);
      }
    } catch (_) {}

    for (var pos in _positions) {
      final token = pos['token']?.toString() ?? '';
      final prd = pos['prd']?.toString() ?? '';
      final key = '$token|$prd';
      final trades = tradesPerKey[key];

      final cfBuyQty =
          (int.tryParse(pos['cfbuyqty']?.toString() ?? '0') ?? 0).toDouble();
      final cfSellQty =
          (int.tryParse(pos['cfsellqty']?.toString() ?? '0') ?? 0).toDouble();
      final cfNetQty = cfBuyQty - cfSellQty;
      final netUpldPrc =
          double.tryParse(pos['netupldprc']?.toString() ?? '0') ?? 0.0;
      final upldPrc =
          double.tryParse(pos['upldprc']?.toString() ?? '0') ?? 0.0;
      final cfPrice = netUpldPrc != 0 ? netUpldPrc : upldPrc;
      final hasCF = cfNetQty != 0;
      final hasTrades = trades != null && trades.isNotEmpty;

      if (!hasTrades && !hasCF) {
        _timelineMap[key] = _PositionTimeline(
          entryEpoch: marketOpenEpoch,
          snapshots: [],
        );
        continue;
      }

      if (hasTrades) {
        trades.sort((a, b) {
          final ea = _parseTradeTime(a.norentm) ?? 0;
          final eb = _parseTradeTime(b.norentm) ?? 0;
          if (ea != eb) return ea.compareTo(eb);
          final fa = int.tryParse(a.flid ?? '0') ?? 0;
          final fb = int.tryParse(b.flid ?? '0') ?? 0;
          return fa.compareTo(fb);
        });
      }

      final firstTradeEpoch = hasTrades
          ? (_parseTradeTime(trades.first.norentm) ?? marketOpenEpoch)
          : marketOpenEpoch;
      final entryEpoch = hasCF ? marketOpenEpoch : firstTradeEpoch;

      double runQty = cfNetQty;
      double avgEntry = (hasCF && cfPrice != 0) ? cfPrice : 0;
      double realizedPnl = 0;
      final snapshots = <_TimelineSnapshot>[];

      if (hasCF) {
        snapshots.add(_TimelineSnapshot(
          epoch: marketOpenEpoch,
          runningQty: runQty,
          avgEntryPrice: avgEntry,
          cumulativeRealizedPnl: 0,
        ));
      }

      for (var t in trades ?? <TradeBookModel>[]) {
        final epoch = _parseTradeTime(t.norentm) ?? 0;
        final fillQty =
            (int.tryParse(t.flqty ?? t.qty ?? '0') ?? 0).toDouble();
        final fillPrc = double.tryParse(t.flprc ?? '0') ?? 0.0;
        final isBuy = t.trantype == 'B';
        final signedQty = isBuy ? fillQty : -fillQty;

        if (runQty == 0) {
          runQty = signedQty;
          avgEntry = fillPrc;
        } else if ((runQty > 0 && isBuy) || (runQty < 0 && !isBuy)) {
          final newQty = runQty + signedQty;
          avgEntry =
              (avgEntry * runQty.abs() + fillPrc * fillQty) / newQty.abs();
          runQty = newQty;
        } else {
          final closedQty = min(fillQty, runQty.abs());
          if (runQty > 0) {
            realizedPnl += closedQty * (fillPrc - avgEntry);
          } else {
            realizedPnl += closedQty * (avgEntry - fillPrc);
          }
          final prevSign = runQty.sign;
          runQty += signedQty;
          if (runQty != 0 && prevSign != runQty.sign) {
            avgEntry = fillPrc;
          }
        }

        snapshots.add(_TimelineSnapshot(
          epoch: epoch,
          runningQty: runQty,
          avgEntryPrice: avgEntry,
          cumulativeRealizedPnl: realizedPnl,
        ));
      }

      _timelineMap[key] = _PositionTimeline(
        entryEpoch: entryEpoch,
        snapshots: snapshots,
      );
    }

    _tradeBookFetched = true;
  }

  int? _parseTradeTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final dt = DateFormat('HH:mm:ss dd-MM-yyyy').parse(timeStr);
      return dt.millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return null;
    }
  }

  _PositionTimeline _getTimeline(Map<String, dynamic> pos) {
    final token = pos['token']?.toString() ?? '';
    final prd = pos['prd']?.toString() ?? '';
    final key = '$token|$prd';
    final now = DateTime.now();
    final marketOpen =
        DateTime(now.year, now.month, now.day, 9, 15).millisecondsSinceEpoch ~/
            1000;
    return _timelineMap[key] ??
        _PositionTimeline(entryEpoch: marketOpen, snapshots: []);
  }

  // ─── Internals: canonical series construction ───

  _CanonicalSeries _buildInitialCanonical({
    required bool isDay,
    required bool isNetPnl,
  }) {
    final posCalcs = _buildPosCalcs(isNetPnl: isNetPnl);

    final allTimestamps = <int>{};
    for (var pc in posCalcs) {
      for (var c in pc.candles) {
        final epoch = int.tryParse(c.ssboe ?? '0') ?? 0;
        if (epoch >= pc.entryEpoch) allTimestamps.add(epoch);
      }
    }
    final sortedTimestamps = allTimestamps.toList()..sort();
    if (sortedTimestamps.isEmpty) {
      return _CanonicalSeries(
        settled: [],
        liveTip: null,
        lastSettledEpoch: 0,
        settledPeak: double.negativeInfinity,
      );
    }

    _buildPriceMaps(posCalcs, sortedTimestamps);
    _computePerPositionCorrections(posCalcs, sortedTimestamps.last);

    double runningPeak = double.negativeInfinity;
    final settled = <GroupPnlDataPoint>[];
    for (var epoch in sortedTimestamps) {
      final groupPnl = _aggregatePnlAt(posCalcs, epoch);
      if (groupPnl == null) continue;
      runningPeak = max(runningPeak, groupPnl);
      settled.add(GroupPnlDataPoint(
        time: DateTime.fromMillisecondsSinceEpoch(epoch * 1000),
        pnl: groupPnl,
        drawdown: groupPnl - runningPeak,
        peak: runningPeak,
      ));
    }

    final corrections = <String, double>{};
    for (var pc in posCalcs) {
      corrections[pc.posKey] = pc.correction;
    }

    return _CanonicalSeries(
      settled: settled,
      liveTip: null,
      lastSettledEpoch: settled.isEmpty
          ? 0
          : settled.last.time.millisecondsSinceEpoch ~/ 1000,
      settledPeak: runningPeak,
      positionCorrections: corrections,
    );
  }

  void _appendIncremental(
    _CanonicalSeries c, {
    required bool isDay,
    required bool isNetPnl,
  }) {
    final posCalcs = _buildPosCalcs(isNetPnl: isNetPnl);

    final newTimestamps = <int>{};
    for (var pc in posCalcs) {
      for (var cd in pc.candles) {
        final epoch = int.tryParse(cd.ssboe ?? '0') ?? 0;
        if (epoch > c.lastSettledEpoch && epoch >= pc.entryEpoch) {
          newTimestamps.add(epoch);
        }
      }
    }
    if (newTimestamps.isEmpty) return;
    final sortedNew = newTimestamps.toList()..sort();

    // Build price maps over the FULL candle set (so forward-fill works
    // correctly across the whole day) but only emit points for the new
    // range.
    final allTimestamps = <int>{};
    for (var pc in posCalcs) {
      for (var cd in pc.candles) {
        final epoch = int.tryParse(cd.ssboe ?? '0') ?? 0;
        if (epoch >= pc.entryEpoch) allTimestamps.add(epoch);
      }
    }
    final sortedAll = allTimestamps.toList()..sort();
    if (sortedAll.isEmpty) return;
    _buildPriceMaps(posCalcs, sortedAll);

    // Reuse cached corrections; compute fresh only for positions that didn't
    // exist on initial fetch.
    for (var pc in posCalcs) {
      final cached = c.positionCorrections[pc.posKey];
      if (cached != null) {
        pc.correction = cached;
      } else {
        if (pc.timeline.snapshots.isEmpty) {
          pc.correction = 0;
        } else {
          final lastEpoch = sortedAll.last;
          final lastPrice = pc.priceAtTime[lastEpoch] ?? 0;
          final timelineFinal = pc.timeline
              .pnlAtTime(lastEpoch, lastPrice, pc.prcFtr, pc.mult);
          pc.correction = pc.currentPnl - timelineFinal;
        }
        c.positionCorrections[pc.posKey] = pc.correction;
      }
    }

    double runningPeak = c.settledPeak == double.negativeInfinity
        ? double.negativeInfinity
        : c.settledPeak;
    for (var epoch in sortedNew) {
      final groupPnl = _aggregatePnlAt(posCalcs, epoch);
      if (groupPnl == null) continue;
      runningPeak = max(runningPeak, groupPnl);
      c.settled.add(GroupPnlDataPoint(
        time: DateTime.fromMillisecondsSinceEpoch(epoch * 1000),
        pnl: groupPnl,
        drawdown: groupPnl - runningPeak,
        peak: runningPeak,
      ));
    }
    c.settledPeak = runningPeak;
    if (c.settled.isNotEmpty) {
      c.lastSettledEpoch =
          c.settled.last.time.millisecondsSinceEpoch ~/ 1000;
    }
  }

  List<_PositionCalcInfo> _buildPosCalcs({required bool isNetPnl}) {
    final posCalcs = <_PositionCalcInfo>[];
    for (var pos in _positions) {
      final token = pos['token']?.toString() ?? '';
      final prd = pos['prd']?.toString() ?? '';
      final candles = _tpCacheOneMin[token] ?? [];
      final pnlField = isNetPnl ? 'profitNloss' : 'mTm';
      final currentPnl =
          double.tryParse(pos[pnlField]?.toString() ?? '0') ?? 0.0;
      final prcFtr =
          double.tryParse(pos['prcftr']?.toString() ?? '1.0') ?? 1.0;
      final mult = double.tryParse(pos['mult']?.toString() ?? '1.0') ?? 1.0;
      final timeline = _getTimeline(pos);
      posCalcs.add(_PositionCalcInfo(
        posKey: '$token|$prd',
        currentPnl: currentPnl,
        prcFtr: prcFtr,
        mult: mult,
        entryEpoch: timeline.entryEpoch,
        timeline: timeline,
        candles: candles,
      ));
    }
    return posCalcs;
  }

  void _buildPriceMaps(
      List<_PositionCalcInfo> posCalcs, List<int> sortedTimestamps) {
    for (var pc in posCalcs) {
      pc.priceAtTime.clear();
      for (var c in pc.candles) {
        final epoch = int.tryParse(c.ssboe ?? '0') ?? 0;
        final close = double.tryParse(c.intc ?? '0') ?? 0.0;
        if (epoch > 0) pc.priceAtTime[epoch] = close;
      }
      double? lastKnown;
      for (var t in sortedTimestamps) {
        if (pc.priceAtTime.containsKey(t)) {
          lastKnown = pc.priceAtTime[t];
        } else if (lastKnown != null) {
          pc.priceAtTime[t] = lastKnown;
        }
      }
    }
  }

  void _computePerPositionCorrections(
      List<_PositionCalcInfo> posCalcs, int lastEpoch) {
    for (var pc in posCalcs) {
      if (pc.timeline.snapshots.isEmpty) {
        pc.correction = 0;
        continue;
      }
      final lastPrice = pc.priceAtTime[lastEpoch] ?? 0;
      final timelineFinal =
          pc.timeline.pnlAtTime(lastEpoch, lastPrice, pc.prcFtr, pc.mult);
      pc.correction = pc.currentPnl - timelineFinal;
    }
  }

  double? _aggregatePnlAt(List<_PositionCalcInfo> posCalcs, int epoch) {
    double groupPnl = 0.0;
    bool any = false;
    for (var pc in posCalcs) {
      if (epoch < pc.entryEpoch) continue;
      final price = pc.priceAtTime[epoch];
      if (price == null) continue;
      if (pc.timeline.snapshots.isNotEmpty) {
        groupPnl += pc.timeline.pnlAtTime(epoch, price, pc.prcFtr, pc.mult) +
            pc.correction;
      } else {
        groupPnl += pc.currentPnl;
      }
      any = true;
    }
    return any ? groupPnl : null;
  }

  void _refreshLiveTipFromCurrentPnl(
    _CanonicalSeries c, {
    required bool isNetPnl,
  }) {
    final field = isNetPnl ? 'profitNloss' : 'mTm';
    double groupPnl = 0;
    for (var pos in _positions) {
      groupPnl += double.tryParse(pos[field]?.toString() ?? '0') ?? 0.0;
    }
    final basePeak = c.settledPeak == double.negativeInfinity
        ? groupPnl
        : c.settledPeak;
    final tipPeak = max(basePeak, groupPnl);
    c.liveTip = GroupPnlDataPoint(
      time: DateTime.now(),
      pnl: groupPnl,
      peak: tipPeak,
      drawdown: groupPnl - tipPeak,
    );
  }

  /// Returns a NEW List instance every call so Syncfusion's `dataSource`
  /// change detection picks it up on widget rebuild.
  ///
  /// Merges three sources:
  ///   1. `c.settled` — API-derived (cached).
  ///   2. `_socketPoints` — minute snapshots from socket LTP (transient).
  ///   3. `c.liveTip` — current moment.
  List<GroupPnlDataPoint> _downsample(
      _CanonicalSeries c, String interval) {
    final all = <GroupPnlDataPoint>[
      ...c.settled,
      ..._socketPoints,
    ];

    final result = <GroupPnlDataPoint>[];
    if (interval == '1') {
      result.addAll(all);
    } else {
      final bucketMins = int.tryParse(interval) ?? 5;
      final bucketMs = bucketMins * 60 * 1000;
      int? currentBucket;
      GroupPnlDataPoint? lastInBucket;
      for (var p in all) {
        final bucket = p.time.millisecondsSinceEpoch ~/ bucketMs;
        if (currentBucket == null) {
          currentBucket = bucket;
          lastInBucket = p;
        } else if (bucket == currentBucket) {
          lastInBucket = p;
        } else {
          if (lastInBucket != null) result.add(lastInBucket);
          currentBucket = bucket;
          lastInBucket = p;
        }
      }
      if (lastInBucket != null) result.add(lastInBucket);
    }
    if (c.liveTip != null) result.add(c.liveTip!);
    return result;
  }
}

// ─── Data classes ───

class _CanonicalSeries {
  List<GroupPnlDataPoint> settled;
  GroupPnlDataPoint? liveTip;
  int lastSettledEpoch;
  double settledPeak;
  Map<String, double> positionCorrections;
  int lastQtySig;

  _CanonicalSeries({
    required this.settled,
    required this.liveTip,
    required this.lastSettledEpoch,
    required this.settledPeak,
    Map<String, double>? positionCorrections,
  })  : lastQtySig = 0,
        positionCorrections = positionCorrections ?? {};
}

class _TimelineSnapshot {
  final int epoch;
  final double runningQty;
  final double avgEntryPrice;
  final double cumulativeRealizedPnl;

  const _TimelineSnapshot({
    required this.epoch,
    required this.runningQty,
    required this.avgEntryPrice,
    required this.cumulativeRealizedPnl,
  });
}

class _PositionTimeline {
  final int entryEpoch;
  final List<_TimelineSnapshot> snapshots;

  const _PositionTimeline({
    required this.entryEpoch,
    required this.snapshots,
  });

  _TimelineSnapshot? getSnapshot(int epoch) {
    if (snapshots.isEmpty) return null;
    _TimelineSnapshot? state;
    for (var s in snapshots) {
      if (s.epoch <= epoch) {
        state = s;
      } else {
        break;
      }
    }
    return state;
  }

  double pnlAtTime(int epoch, double candlePrice, double prcFtr, double mult) {
    final state = getSnapshot(epoch);
    if (state == null) return 0;
    final unrealized =
        state.runningQty * prcFtr * mult * (candlePrice - state.avgEntryPrice);
    return state.cumulativeRealizedPnl * prcFtr * mult + unrealized;
  }
}

class _PositionCalcInfo {
  final String posKey;
  final double currentPnl;
  final double prcFtr;
  final double mult;
  final int entryEpoch;
  final _PositionTimeline timeline;
  double correction = 0;

  final List<Data> candles;
  final Map<int, double> priceAtTime = {};

  _PositionCalcInfo({
    required this.posKey,
    required this.currentPnl,
    required this.prcFtr,
    required this.mult,
    required this.entryEpoch,
    required this.timeline,
    required this.candles,
  });
}
