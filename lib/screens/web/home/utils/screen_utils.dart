import 'package:flutter/material.dart';
import '../models/screen_type.dart';

class ScreenUtils {
  // Get screen title from type
  static String getScreenTitle(ScreenType type) {
    switch (type) {
      case ScreenType.dashboard:
        return 'Dashboard';
      case ScreenType.watchlist:
        return 'Watchlist';
      case ScreenType.holdings:
        return 'Holdings';
      case ScreenType.positions:
        return 'Positions';
      case ScreenType.orderBook:
        return 'Order Book';
      case ScreenType.funds:
        return 'Funds';
      case ScreenType.mutualFund:
        return 'Mutual Fund';
      case ScreenType.ipo:
        return 'IPO';
      case ScreenType.bond:
        return 'Bonds';
      case ScreenType.scripDepthInfo:
        return 'Chart View';
      case ScreenType.optionChain:
        return 'Option Chain';
      case ScreenType.pledgeUnpledge:
        return 'Pledge/Unpledge';
      case ScreenType.corporateActions:
        return 'Corporate Actions';
      case ScreenType.clientMaster:
        return 'Client Master';
      case ScreenType.reports:
        return 'Reports';
      case ScreenType.ledger:
        return 'Ledger';
      case ScreenType.contractNote:
        return 'Contract Note';
      case ScreenType.settings:
        return 'Settings';
      case ScreenType.tradeAction:
        return 'Trade Action';
      case ScreenType.mfNfo:
        return 'New Fund Offerings';
      case ScreenType.mfCollection:
        return 'Collections';
      case ScreenType.mfCategory:
        return 'Categories';
      case ScreenType.sipCalculator:
        return 'SIP Calculator';
      case ScreenType.cagrCalculator:
        return 'CAGR Calculator';
      case ScreenType.mfStockDetail:
        return 'Fund Details';
      case ScreenType.notification:
        return 'Notification';
      case ScreenType.portfolioAnalysis:
        return 'Portfolio Analysis';
      case ScreenType.strategyBuilder:
        return 'Strategy Builder';
      case ScreenType.scalper:
        return 'Scalper';
      case ScreenType.charts:
        return 'Charts';
      case ScreenType.tradingViewWebHook:
        return 'WebHook';
      case ScreenType.refer:
        return 'Refer & Earn';
      case ScreenType.helpSupport:
        return 'Help & Support';
      case ScreenType.tradebook:
        return 'Tradebook';
      case ScreenType.calendarPnl:
        return 'P&L Summary';
      case ScreenType.reportPositions:
        return 'Positions';
      case ScreenType.pdfDownload:
        return 'PDF Download';
      case ScreenType.taxPnl:
        return 'Tax P&L';
      case ScreenType.notionalPnl:
        return 'Notional P&L';
      case ScreenType.myAccount:
        return 'My Account';
      case ScreenType.tradingPreferences:
        return 'Trading Preferences';
      case ScreenType.profileDetails:
        return 'Profile Details';
      case ScreenType.bankDetails:
        return 'Bank';
      case ScreenType.depositoryDetails:
        return 'Depository';
      case ScreenType.mtfDetails:
        return 'Margin Trading Facility (MTF)';
      case ScreenType.nomineeDetails:
        return 'Nominee';
      case ScreenType.formDownload:
        return 'Form Download';
      case ScreenType.closureDetails:
        return 'Closure';
      case ScreenType.caBuyback:
        return 'Buyback';
    }
  }

  // Get icon for screen type
  static IconData getIconForScreenType(ScreenType type) {
    switch (type) {
      case ScreenType.dashboard:
        return Icons.dashboard;
      case ScreenType.watchlist:
        return Icons.list;
      case ScreenType.holdings:
        return Icons.inventory;
      case ScreenType.positions:
        return Icons.trending_up;
      case ScreenType.orderBook:
        return Icons.receipt;
      case ScreenType.funds:
        return Icons.account_balance;
      case ScreenType.mutualFund:
        return Icons.trending_up;
      case ScreenType.ipo:
        return Icons.public;
      case ScreenType.bond:
        return Icons.account_balance;
      case ScreenType.scripDepthInfo:
        return Icons.analytics;
      case ScreenType.optionChain:
        return Icons.table_chart;
      case ScreenType.pledgeUnpledge:
        return Icons.security;
      case ScreenType.corporateActions:
        return Icons.business;
      case ScreenType.clientMaster:
        return Icons.description;
      case ScreenType.reports:
        return Icons.assessment;
      case ScreenType.ledger:
        return Icons.book;
      case ScreenType.contractNote:
        return Icons.description;
      case ScreenType.settings:
        return Icons.settings;
      case ScreenType.tradeAction:
        return Icons.trending_up;
      case ScreenType.mfNfo:
        return Icons.card_giftcard;
      case ScreenType.mfCollection:
        return Icons.collections_bookmark;
      case ScreenType.mfCategory:
        return Icons.category;
      case ScreenType.sipCalculator:
        return Icons.calculate;
      case ScreenType.cagrCalculator:
        return Icons.calculate;
      case ScreenType.mfStockDetail:
        return Icons.show_chart;
      case ScreenType.notification:
        return Icons.notifications_outlined;
      case ScreenType.portfolioAnalysis:
        return Icons.pie_chart;
      case ScreenType.strategyBuilder:
        return Icons.architecture;
      case ScreenType.scalper:
        return Icons.speed;
      case ScreenType.charts:
        return Icons.show_chart;
      case ScreenType.tradingViewWebHook:
        return Icons.web;
      case ScreenType.refer:
        return Icons.card_giftcard;
      case ScreenType.helpSupport:
        return Icons.help_outline;
      case ScreenType.tradebook:
        return Icons.receipt_long;
      case ScreenType.calendarPnl:
        return Icons.calendar_month;
      case ScreenType.reportPositions:
        return Icons.trending_up;
      case ScreenType.pdfDownload:
        return Icons.picture_as_pdf;
      case ScreenType.taxPnl:
        return Icons.receipt_long;
      case ScreenType.notionalPnl:
        return Icons.bar_chart;
      case ScreenType.myAccount:
        return Icons.person_outline;
      case ScreenType.tradingPreferences:
        return Icons.tune;
      case ScreenType.profileDetails:
        return Icons.person;
      case ScreenType.bankDetails:
        return Icons.account_balance;
      case ScreenType.depositoryDetails:
        return Icons.inventory;
      case ScreenType.mtfDetails:
        return Icons.trending_up;
      case ScreenType.nomineeDetails:
        return Icons.people;
      case ScreenType.formDownload:
        return Icons.download;
      case ScreenType.closureDetails:
        return Icons.cancel;
      case ScreenType.caBuyback:
        return Icons.recycling;
    }
  }

  // Get screen title with null safety
  static String getScreenTitleNullable(ScreenType? type) {
    if (type == null) return 'Empty';
    return getScreenTitle(type);
  }

  // Get icon with null safety
  static IconData getIconForScreenTypeNullable(ScreenType? type) {
    if (type == null) return Icons.add;
    return getIconForScreenType(type);
  }
}
