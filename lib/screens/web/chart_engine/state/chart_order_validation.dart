// Order-input validation for the WEB in-house chart's DIRECT order paths — the
// instant Buy/Sell + SL, OCO place, and drag-to-modify flows that bypass
// PlaceOrderScreenWeb and therefore used to place with NO circuit / trigger /
// LTP checks at all.
//
// Verbatim port of the mobile chart's `chart_order_validation.dart`. The
// price/trigger messages come from `place_order_screen_web.dart` (~6756-6868);
// the OCO LTP-directional messages match the chart's own OCO card
// (`overlay_close_dialog.dart` _OcoTpSlCard). Keep the two platform copies in
// sync.

/// True when the scrip's circuit band is usable — mirrors the screen's
/// `_hasValidCircuitBreakerValues`: both bounds present, parseable, > 0, and
/// not the "0.00" placeholder the info API returns when it has no band.
bool hasValidCircuit(String? uc, String? lc) {
  final u = double.tryParse(uc ?? '');
  final l = double.tryParse(lc ?? '');
  return u != null &&
      l != null &&
      u > 0 &&
      l > 0 &&
      uc != '0.00' &&
      lc != '0.00';
}

/// Validates a limit price and/or SL trigger for a chart Buy/Sell order.
/// Returns a user-facing error string, or null when the order may proceed.
///
/// [prctype] is the chart's wire code: 'LMT' | 'MKT' | 'SL-LMT' | 'SL-MKT'.
/// [price] is the limit price (LMT / SL-LMT); [trigger] the stop trigger
/// (SL-LMT / SL-MKT). [ltp] is the live last price; when null or <= 0 the
/// LTP-directional checks are skipped (the circuit checks never need LTP).
String? validateChartOrder({
  required bool isBuy,
  required String prctype,
  double? price,
  double? trigger,
  String? uc,
  String? lc,
  double? ltp,
}) {
  final hasCircuit = hasValidCircuit(uc, lc);
  final ucv = double.tryParse(uc ?? '');
  final lcv = double.tryParse(lc ?? '');
  final isLimit = prctype == 'LMT';
  final isSlLmt = prctype == 'SL-LMT';
  final isSlMkt = prctype == 'SL-MKT';

  // ── Limit / SL-Limit price vs circuit band (not side-directional) ──
  if ((isLimit || isSlLmt) && hasCircuit && price != null) {
    if (price < lcv!) {
      return 'Price cannot be lesser than Lower Circuit Limit $lc';
    }
    if (price > ucv!) {
      return 'Price cannot be greater than Upper Circuit Limit $uc';
    }
  }

  // ── SL trigger checks (SL-Limit / SL-MKT) ──
  if (isSlLmt || isSlMkt) {
    if (trigger == null || trigger == 0) {
      return trigger == null ? 'Trigger cannot be empty' : 'Trigger cannot be 0';
    }
    final hasLtp = ltp != null && ltp > 0;
    if (isBuy) {
      if (isSlMkt) {
        if (hasLtp && trigger < ltp) {
          return 'Trigger should be greater than LTP';
        }
        if (hasCircuit && trigger > ucv!) {
          return 'Trigger cannot be greater than upper circuit limit of $uc';
        }
      } else {
        // BUY SL-Limit
        if (hasLtp && trigger < ltp) {
          return 'Trigger should be greater than LTP';
        }
        if (hasCircuit && trigger < lcv!) {
          return 'Trigger cannot be lesser than lower circuit limit of $lc';
        }
        if (price != null && price < trigger) {
          return 'Trigger should be less than price';
        }
        if (hasCircuit && trigger > ucv!) {
          return 'Trigger cannot be greater than upper circuit limit of $uc';
        }
      }
    } else {
      if (isSlMkt) {
        if (hasLtp && trigger > ltp) {
          return 'Trigger should be lesser than LTP';
        }
        if (hasCircuit && trigger < lcv!) {
          return 'Trigger cannot be lesser than lower circuit limit of $lc';
        }
      } else {
        // SELL SL-Limit
        if (hasLtp && trigger > ltp) {
          return 'Trigger should be lesser than LTP';
        }
        if (hasCircuit && trigger > ucv!) {
          return 'Trigger cannot be greater than upper circuit limit of $uc';
        }
        if (price != null && price > trigger) {
          return 'Trigger should be greater than price';
        }
        if (hasCircuit && trigger < lcv!) {
          return 'Trigger cannot be lesser than lower circuit limit of $lc';
        }
      }
    }
  }
  return null;
}

/// Validates an OCO (Target + Stop-loss) pair against the circuit band. The
/// caller keeps its own LTP-straddle checks; this ADDS the circuit-limit checks
/// (TC_523/524): neither leg may sit outside [lc, uc]. Skips when no band.
String? validateChartOco({
  required double target,
  required double stop,
  String? uc,
  String? lc,
}) {
  if (!hasValidCircuit(uc, lc)) return null;
  final ucv = double.parse(uc!);
  final lcv = double.parse(lc!);
  if (target > ucv) {
    return 'Target cannot be greater than Upper Circuit Limit $uc';
  }
  if (target < lcv) {
    return 'Target cannot be lesser than Lower Circuit Limit $lc';
  }
  if (stop > ucv) {
    return 'Stoploss cannot be greater than Upper Circuit Limit $uc';
  }
  if (stop < lcv) {
    return 'Stoploss cannot be lesser than Lower Circuit Limit $lc';
  }
  return null;
}

/// Validates a SINGLE dragged OCO leg (drag-to-modify a TP or SL line).
/// Enforces BOTH the LTP-directional rule (a long's Target must stay above the
/// live price and its Stop below — mirrored for a short) AND the circuit band.
/// [isTp] = target leg vs stop leg; [isLong] = position direction (exit SELL);
/// [ltp] live price (directional check skipped when null/≤0). Returns an error
/// or null.
String? validateChartOcoLeg({
  required bool isTp,
  required bool isLong,
  required double price,
  String? uc,
  String? lc,
  double? ltp,
  int decimals = 2,
}) {
  // LTP-directional — matches the OCO place card's "must be above/below the
  // current price" messages. This is what a leg drag was missing: dragging a
  // long's Target BELOW the LTP was wrongly accepted.
  if (ltp != null && ltp > 0) {
    final ltpStr = ltp.toStringAsFixed(decimals);
    if (isTp) {
      if (isLong && price <= ltp) {
        return 'Target must be above the current price ($ltpStr).';
      }
      if (!isLong && price >= ltp) {
        return 'Target must be below the current price ($ltpStr).';
      }
    } else {
      if (isLong && price >= ltp) {
        return 'Stop-loss must be below the current price ($ltpStr).';
      }
      if (!isLong && price <= ltp) {
        return 'Stop-loss must be above the current price ($ltpStr).';
      }
    }
  }
  // Circuit band.
  if (hasValidCircuit(uc, lc)) {
    final ucv = double.parse(uc!);
    final lcv = double.parse(lc!);
    final label = isTp ? 'Target' : 'Stoploss';
    if (price > ucv) {
      return '$label cannot be greater than Upper Circuit Limit $uc';
    }
    if (price < lcv) {
      return '$label cannot be lesser than Lower Circuit Limit $lc';
    }
  }
  return null;
}
