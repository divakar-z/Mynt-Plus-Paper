import 'package:flutter/material.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/order_book_model/trade_book_model.dart';
import 'package:mynt_plus/models/order_book_model/gtt_order_book.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/res/web_colors.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';

class CellFormatters {
  // Get valid LTP value
  static String getValidLTP(OrderBookModel item) {
    if (item.ltp != null && item.ltp.toString() != "null" && item.ltp.toString().isNotEmpty) {
      return item.ltp.toString();
    }
    if (item.c != null && item.c.toString() != "null") {
      final closePrice = double.tryParse(item.c.toString());
      if (closePrice != null) {
        return closePrice.toString();
      }
    }
    return '0.00';
  }

  // Get valid LTP for GTT
  static String getValidLTPForGtt(GttOrderBookModel item) {
    if (item.ltp != null && item.ltp.toString() != "null" && item.ltp.toString().isNotEmpty) {
      return item.ltp.toString();
    }
    return '0.00';
  }

  // Get valid price value
  static String getValidPrice(OrderBookModel item) {
    if (item.prctyp == "MKT" || item.prctyp == "MARKET") {
      return "MKT";
    }
    if (item.prc != null && item.prc != '0' && item.prc != '0.00') {
      return item.prc!;
    }
    return '0.00';
  }

  // Get status text
  static String getStatusText(OrderBookModel item) {
    if (item.status == null) return 'N/A';

    final status = item.status!.toUpperCase();
    switch (status) {
      case 'OPEN':
        return 'Open';
      case 'COMPLETE':
      case 'EXECUTED':
        return 'Executed';
      case 'REJECTED':
        return 'Rejected';
      case 'CANCELLED':
      case 'CANCELED':
        return 'Cancelled';
      case 'PENDING':
        return 'Pending';
      case 'TRIGGER_PENDING':
        return 'Trigger Pending';
      case 'AFTER_MARKET_ORDER_REQ_RECEIVED':
        return 'AMO';
      default:
        return status;
    }
  }

  // Get status color
  static Color getStatusColor(String statusText, ThemesProvider theme) {
    switch (statusText.toUpperCase()) {
      case 'EXECUTED':
      case 'COMPLETE':
        return theme.isDarkMode ? colors.profitDark : colors.profitLight;
      case 'REJECTED':
      case 'CANCELLED':
      case 'CANCELED':
        return theme.isDarkMode ? colors.lossDark : colors.lossLight;
      case 'OPEN':
      case 'PENDING':
      case 'TRIGGER PENDING':
      case 'AMO':
        return const Color(0xffdf7c1a); // Orange/Yellow warning color
      default:
        return theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textPrimary;
    }
  }

  // Get GTT status text
  static String getGttStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pending';
      case 'TRIGGER_PENDING':
        return 'Trigger Pending';
      case 'CANCELLED':
      case 'CANCELED':
        return 'Cancelled';
      case 'EXECUTED':
        return 'Executed';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status;
    }
  }

  // Get GTT status color
  static Color getGttStatusColor(String status, ThemesProvider theme) {
    switch (status.toUpperCase()) {
      case 'EXECUTED':
        return theme.isDarkMode ? colors.profitDark : colors.profitLight;
      case 'REJECTED':
      case 'CANCELLED':
      case 'CANCELED':
        return theme.isDarkMode ? colors.lossDark : colors.lossLight;
      case 'PENDING':
      case 'TRIGGER_PENDING':
        return const Color(0xffdf7c1a); // Orange/Yellow warning color
      default:
        return theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textPrimary;
    }
  }

  // Format time
  static String formatTime(String timeString) {
    return formatDateTime(value: timeString);
  }

  // Calculate order value
  static String calculateOrderValue(OrderBookModel order) {
    try {
      double price = double.tryParse(order.avgprc ?? "0") ?? 0.0;
      int qty = int.tryParse(order.qty.toString()) ?? 0;
      return (price * qty).toStringAsFixed(2);
    } catch (e) {
      return '0.00';
    }
  }

  // Calculate trade value
  static String calculateTradeValue(TradeBookModel trade) {
    try {
      if (trade.flqty != null && trade.flprc != null) {
        return (double.parse(trade.flqty!) * double.parse(trade.flprc!))
            .toStringAsFixed(2);
      }
    } catch (e) {
      // Ignore error
    }
    return "0.00";
  }

  // Format instrument display text (Order)
  static String formatInstrumentText(OrderBookModel order) {
    // Prefer the backend display name (DerivativeMaster) for derivatives.
    String symbol = order.masterName ?? (order.tsym ?? '');
    String exchange = order.exch ?? '';
    String displayText = symbol.trim();
    if (exchange.isNotEmpty && exchange.trim().isNotEmpty) {
      displayText += ' ${exchange.trim()}';
    }
    return displayText;
  }

  // Format instrument display text (Trade)
  static String formatTradeInstrumentText(TradeBookModel trade) {
    // Prefer the backend display name (DerivativeMaster) for derivatives.
    final master = trade.masterName;
    if (master != null && master.isNotEmpty) return master;
    final symbol = trade.symbol?.replaceAll("-EQ", "") ?? trade.tsym ?? 'N/A';
    final expDate = trade.expDate ?? '';
    final option = trade.option ?? '';
    String displayText = symbol;
    if (expDate.isNotEmpty) {
      displayText += ' $expDate';
    }
    if (option.isNotEmpty) {
      displayText += ' $option';
    }
    return displayText;
  }

  // Format instrument display text (GTT)
  static String formatGttInstrumentText(GttOrderBookModel gttOrder) {
    // Prefer the backend display name (DerivativeMaster) for derivatives.
    String symbol = gttOrder.masterName ?? (gttOrder.tsym?.replaceAll("-EQ", "") ?? 'N/A');
    String exchange = gttOrder.exch ?? '';
    String displayText = symbol.trim();
    if (exchange.isNotEmpty && exchange.trim().isNotEmpty) {
      displayText += ' ${exchange.trim()}';
    }
    return displayText;
  }
}
