import 'dart:async';
import 'dart:math';

import 'paper_order_engine.dart';

/// Simulates LTP (Last Traded Price) updates using a random walk model.
/// Use this when no real WebSocket connection is available.
///
/// Exposes data in the same shape as WebSocketProvider's _socketDatas:
///   _socketDatas[token] = {'lp': '1234.50', 'pc': '1.25', ...}
///
/// To use alongside the real WebSocket instead, skip this service
/// and let the real WebSocket feed LTP. The PaperOrderEngine.onLtpUpdate()
/// can be called from either source.
class PaperLtpService {
  static PaperLtpService? _instance;
  static PaperLtpService get instance {
    _instance ??= PaperLtpService._();
    return _instance!;
  }

  PaperLtpService._();

  Timer? _timer;
  final Random _random = Random();

  /// token -> simulated market data map
  final Map<String, Map<String, dynamic>> _socketDatas = {};

  /// Stream that emits the full _socketDatas map on each tick,
  /// mimicking WebSocketProvider's socketDataStream.
  final StreamController<Map<String, Map<String, dynamic>>> _controller =
      StreamController.broadcast();

  Stream<Map<String, Map<String, dynamic>>> get ltpStream => _controller.stream;

  Map<String, Map<String, dynamic>> get currentData =>
      Map.unmodifiable(_socketDatas);

  /// Last real WebSocket LTP per token (fed by WebSocketProvider).
  final Map<String, String> _liveLtp = {};

  /// Get the current LTP for a token, or null if not tracked.
  /// Real market data wins over the random-walk simulation.
  String? getLtp(String token) {
    return _liveLtp[token] ?? _socketDatas[token]?['lp']?.toString();
  }

  /// Called for every real tick so market orders fill at the live price and
  /// pending LIMIT / SL orders can trigger against it.
  void feedLive(String token, String lp) {
    final price = double.tryParse(lp) ?? 0;
    if (price <= 0) return;
    _liveLtp[token] = lp;
    PaperOrderEngine.instance.onLtpUpdateByToken(token, price);
  }

  // ── Subscription Management ─────────────────────────────────────

  /// Start simulating LTP for a symbol.
  /// [token] is the scrip token (e.g., "26000").
  /// [initialLtp] is the starting price (from a quote or last known price).
  /// [exchange] is optional metadata (e.g., "NSE").
  void subscribe(String token, double initialLtp, {String? exchange}) {
    if (initialLtp <= 0) initialLtp = 100.0; // safety fallback

    _socketDatas[token] = {
      'lp': initialLtp.toStringAsFixed(2),
      'pc': '0.00',
      'c': initialLtp.toStringAsFixed(2), // close/prev price
      'tk': token,
      'e': exchange ?? 'NSE',
      'h': initialLtp.toStringAsFixed(2), // high
      'l': initialLtp.toStringAsFixed(2), // low
      'o': initialLtp.toStringAsFixed(2), // open
      'v': '${_random.nextInt(100000) + 10000}', // volume
      'bp1': (initialLtp - 0.05).toStringAsFixed(2), // best bid
      'sp1': (initialLtp + 0.05).toStringAsFixed(2), // best ask
      'bq1': '${_random.nextInt(500) + 50}',
      'sq1': '${_random.nextInt(500) + 50}',
      '_basePrice': initialLtp, // internal: base for volatility calc
    };

    _ensureTimerRunning();
  }

  /// Stop simulating LTP for a token.
  void unsubscribe(String token) {
    _socketDatas.remove(token);
    if (_socketDatas.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Unsubscribe all and stop timer.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _socketDatas.clear();
    _controller.close();
  }

  // ── Internal Simulation Loop ────────────────────────────────────

  void _ensureTimerRunning() {
    if (_timer != null && _timer!.isActive) return;
    // Tick every 1 second — realistic enough for paper trading
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_socketDatas.isEmpty) return;

    for (final token in _socketDatas.keys) {
      final data = _socketDatas[token]!;
      final double currentLtp = double.tryParse(data['lp'].toString()) ?? 0;
      final double basePrice = (data['_basePrice'] as num?)?.toDouble() ?? currentLtp;

      if (currentLtp <= 0) continue;

      // Random walk: change = random(-0.5% to +0.5%) of base price
      // This gives realistic tick-level movement
      final double volatility = basePrice * 0.005; // 0.5% of base
      final double change = (_random.nextDouble() - 0.5) * volatility;
      final double newLtp = (currentLtp + change).clamp(basePrice * 0.9, basePrice * 1.1);

      final double closePrice = double.tryParse(data['c'].toString()) ?? basePrice;
      final double priceChange = newLtp - closePrice;
      final double pctChange = closePrice > 0 ? (priceChange / closePrice) * 100 : 0;

      final double high = double.tryParse(data['h'].toString()) ?? newLtp;
      final double low = double.tryParse(data['l'].toString()) ?? newLtp;

      data['lp'] = newLtp.toStringAsFixed(2);
      data['pc'] = pctChange.toStringAsFixed(2);
      data['h'] = (newLtp > high ? newLtp : high).toStringAsFixed(2);
      data['l'] = (newLtp < low ? newLtp : low).toStringAsFixed(2);

      // Simulate bid/ask spread
      data['bp1'] = (newLtp - 0.05).toStringAsFixed(2);
      data['sp1'] = (newLtp + 0.05).toStringAsFixed(2);
      data['bq1'] = '${_random.nextInt(500) + 50}';
      data['sq1'] = '${_random.nextInt(500) + 50}';

      // Volume tick
      final int vol = int.tryParse(data['v'].toString()) ?? 0;
      data['v'] = '${vol + _random.nextInt(200)}';

      // Check pending orders against new LTP
      // Uses tsym from order matching — we need to find orders by token
      PaperOrderEngine.instance.onLtpUpdate(
        _findTsymForToken(token) ?? '',
        newLtp,
      );
    }

    if (!_controller.isClosed) {
      _controller.add(Map.from(_socketDatas));
    }
  }

  /// Reverse lookup: find tsym for a token from current orders.
  String? _findTsymForToken(String token) {
    for (final order in PaperOrderEngine.instance.orders) {
      if (order.token == token) return order.tsym;
    }
    return null;
  }

  // ── Bulk Update (for integration with real WebSocket) ───────────

  /// If you want to feed real WebSocket data through the paper system,
  /// call this to update a token's LTP and trigger pending order matching.
  Future<void> updateFromRealData(String token, String tsym, double ltp) async {
    if (_socketDatas.containsKey(token)) {
      _socketDatas[token]!['lp'] = ltp.toStringAsFixed(2);
    }
    await PaperOrderEngine.instance.onLtpUpdate(tsym, ltp);
  }
}
