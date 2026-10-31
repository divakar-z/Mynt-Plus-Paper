import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../locator/constant.dart';
import 'index_list_provider.dart';
import 'market_watch_provider.dart';
import 'order_provider.dart';
import 'portfolio_provider.dart';
import 'stocks_provider.dart';
import 'websocket_provider.dart';
import 'subscription_manager.dart';

final networkStateProvider =
    ChangeNotifierProvider((ref) => NetworkStateProvider(ref));

class NetworkStateProvider extends ChangeNotifier {
  final Ref ref;
  NetworkStateProvider(this.ref);
  StreamController<ConnectivityResult> networkState =
      StreamController<ConnectivityResult>.broadcast();
  late StreamSubscription connection;

  // ConnectivityResult connectionResult = ConnectivityResult.none;

  ConnectivityResult _connectionStatus = ConnectivityResult.mobile;
  ConnectivityResult _previousConnectionStatus = ConnectivityResult.mobile;
  ConnectivityResult get connectionStatus => _connectionStatus;
  ConnectivityResult get previousConnectionStatus => _previousConnectionStatus;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> connectivitySubscription;
  
  // Network type change detection
  bool _isNetworkTypeChange = false;
  bool get isNetworkTypeChange => _isNetworkTypeChange;
  DateTime? _lastNetworkChange;
  
  // Connection quality tracking
  int _connectionQualityScore = 100;
  int get connectionQualityScore => _connectionQualityScore;
  
  // Subscription restoration tracking
  bool _isRestoringSubscriptions = false;
  bool get isRestoringSubscriptions => _isRestoringSubscriptions;
  
  // Enhanced connection state tracking
  DateTime? _lastConnectionAttempt;
  DateTime? _lastSuccessfulConnection;
  String _connectionStatusMessage = "";
  bool _isManualRetry = false;
  int _consecutiveFailures = 0;
  
  // Connection state getters
  DateTime? get lastConnectionAttempt => _lastConnectionAttempt;
  DateTime? get lastSuccessfulConnection => _lastSuccessfulConnection;
  String get connectionStatusMessage => _connectionStatusMessage;
  bool get isManualRetry => _isManualRetry;
  int get consecutiveFailures => _consecutiveFailures;
  
  // Check if we're in a good connection state
  bool get isConnectionHealthy => 
      _connectionStatus != ConnectivityResult.none && 
      _consecutiveFailures < 3 && 
      !_isRestoringSubscriptions;

  BuildContext? _globbcontext;
  BuildContext? get context => _globbcontext; // Public getter for lifecycle manager
  // void streamNetworkStatus() {
  //   connectStatus();
  //   connection = Connectivity().onConnectivityChanged.listen((event) {
  //     networkState.add(event);
  //     connectionResult = event;
  //     log('STATUS CHANGED ::: $event');
  //     if (event.toString().toLowerCase() == 'connectivityresult.none') {
  //       log("PRINTER ::: $event");
  //     }
  //     notifyListeners();
  //   });
  // }

  void netWorkDispose() {
    connectivitySubscription.cancel();
  }

  // connectStatus() async {
  //   final ConnectivityResult connectivityResult =
  //       await Connectivity().checkConnectivity();
  //   if (connectivityResult == ConnectivityResult.mobile) {
  //     log("Mobile");
  //     networkState.add(connectivityResult);
  //     connectionResult = connectivityResult;
  //     // I am connected to a mobile network.
  //   } else if (connectivityResult == ConnectivityResult.wifi) {
  //     // I am connected to a wifi network.
  //     log("WIFI");
  //     networkState.add(connectivityResult);
  //     connectionResult = connectivityResult;
  //   }log("_connectionStatus{$connectionResult}");
  //   notifyListeners();
  // }

// Assigning context - delayed to avoid build cycle modification
  getContext(BuildContext context) {
    _globbcontext = context;
    // Delay notification to avoid modifying provider during build
    Future(() {
      notifyListeners();
    });
  }

// Listening  Network status
  networkStream() {
    initConnectivity();
    connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      // connectivity_plus 7.0.0 returns List<ConnectivityResult>
      // Take the first result or check if any connection is available
      final result = results.isNotEmpty 
          ? (results.contains(ConnectivityResult.none) 
              ? ConnectivityResult.none 
              : results.first)
          : ConnectivityResult.none;
      updateConnectionStatus(result);
    });
  }

// Initially check internet connection
  initConnectivity() async {
    late ConnectivityResult result;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      final results = await _connectivity.checkConnectivity();
      // connectivity_plus 7.0.0 returns List<ConnectivityResult>
      result = results.isNotEmpty 
          ? (results.contains(ConnectivityResult.none) 
              ? ConnectivityResult.none 
              : results.first)
          : ConnectivityResult.none;
    } on PlatformException catch (e) {
      ref.read(indexListProvider)
          .logError
          .add({"type": "Internet connection", "Error": "$e"});
      notifyListeners();
      return;
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.

    return updateConnectionStatus(result);
  }

  Future<void> updateConnectionStatus(ConnectivityResult result) async {
    _previousConnectionStatus = _connectionStatus;
    _connectionStatus = result;
    
    // Update connection tracking
    _lastConnectionAttempt = DateTime.now();
    
    // Detect network type changes
    _isNetworkTypeChange = _detectNetworkTypeChange(_previousConnectionStatus, result);
    if (_isNetworkTypeChange) {
      _lastNetworkChange = DateTime.now();
    }

    if (_connectionStatus == ConnectivityResult.none) {
      // Connection lost
      _connectionQualityScore = 0;
      _consecutiveFailures++;
      _connectionStatusMessage = "No internet connection";
      
      ref.read(websocketProvider).closeSocket(true);
      ref.read(websocketProvider).websockConn(false);
      
    } else {
      // Connection available
      final wasDisconnected = _previousConnectionStatus == ConnectivityResult.none;
      
      if (wasDisconnected || _consecutiveFailures > 0) {
        _lastSuccessfulConnection = DateTime.now();
        _consecutiveFailures = 0; // Reset failure count on successful connection
        _connectionStatusMessage = "Connection restored";
        
      } else {
        _connectionStatusMessage = "Connected";
      }
      
      _connectionQualityScore = 100; // Reset to full quality initially
      
      if (ConstantName.sessCheck) {
        _connectionStatusMessage = "Restoring data...";
        await restoreAllSubscriptions();
        _connectionStatusMessage = "Connected";
      }
    }
    
    notifyListeners();
  }
  
  /// Detect if this is a network type change vs initial connection
  bool _detectNetworkTypeChange(ConnectivityResult previous, ConnectivityResult current) {
    // If previous was none, this is not a type change but initial connection
    if (previous == ConnectivityResult.none) return false;
    
    // If current is none, this is connection loss, not type change  
    if (current == ConnectivityResult.none) return false;
    
    // If both are the same, no change
    if (previous == current) return false;
    
    // Different non-none types = network type change
    return true;
  }
  
  /// Manual retry method for user-initiated reconnection
  Future<void> manualRetry() async {
    if (_globbcontext == null) return;
    
    _isManualRetry = true;
    _connectionStatusMessage = "Retrying connection...";
    notifyListeners();
    
    try {
      // Force check connectivity
      final results = await Connectivity().checkConnectivity();
      // connectivity_plus 7.0.0 returns List<ConnectivityResult>
      final result = results.isNotEmpty 
          ? (results.contains(ConnectivityResult.none) 
              ? ConnectivityResult.none 
              : results.first)
          : ConnectivityResult.none;
      await updateConnectionStatus(result);
      
      // If we have connection, force websocket reconnection
      if (result != ConnectivityResult.none) {
        final wsProvider = ref.read(websocketProvider);
        wsProvider.changeconnectioncount(); // Reset connection attempts
        
        if (_globbcontext != null) {
          wsProvider.reconnect(_globbcontext!);
        }
      }
    } catch (e) {
      _connectionStatusMessage = "Retry failed. Please check your connection.";
      _consecutiveFailures++;
    } finally {
      _isManualRetry = false;
      notifyListeners();
    }
  }
  
  /// Reset connection failure tracking
  void resetConnectionTracking() {
    _consecutiveFailures = 0;
    _lastSuccessfulConnection = DateTime.now();
    _connectionStatusMessage = "Connected";
    notifyListeners();
  }

  /// Restore all subscriptions using captured subscription data
  Future<void> restoreAllSubscriptions() async {
    if (_globbcontext == null) return;
    
    _isRestoringSubscriptions = true;
    _connectionStatusMessage = "Restoring subscriptions...";
    notifyListeners();
    
    try {
      final wsProvider = ref.read(websocketProvider);
      
      // Force websocket reconnection on network type changes
      if (_isNetworkTypeChange) {
        wsProvider.closeSocket(true);
        
        // Small delay to ensure clean disconnection
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Use SubscriptionManager for efficient batch restoration
      final subscriptionManager = ref.read(subscriptionManagerProvider);
      
      if (!subscriptionManager.hasActiveSubscriptions) {
        subscriptionManager.printCurrentState();
      } else {
        
        // Use SubscriptionManager's efficient batch reconnection
        await subscriptionManager.forceReconnection();
        
      }
      
      // Restore legacy subscriptions for compatibility (existing code)
      await _restoreLegacySubscriptions();
      
      // Restore tab-based subscriptions (existing code)
      await _restoreTabBasedSubscriptions();
      
    } catch (e) {
      _connectionStatusMessage = "Failed to restore some data";
      _consecutiveFailures++;
    } finally {
      _isRestoringSubscriptions = false;
      _isNetworkTypeChange = false; // Reset flag
      
      // Update final status message
      if (_connectionStatus != ConnectivityResult.none && _consecutiveFailures == 0) {
        _connectionStatusMessage = "Connected";
      }
      
      notifyListeners();
    }
  }
  
  /// Restore legacy subscriptions for backward compatibility (mobile only).
  ///
  /// Web is skipped: WebSubscriptionManager owns web restoration (its master
  /// list plus the tracked depth symbol), as WebSocketProvider's own restore
  /// path already notes. Replaying the legacy globals here on web did harm:
  /// `lastSubscribe` holds only the most recent single TOUCHLINE request, and it
  /// was replayed as DEPTH ("d") — so every connectivity event subscribed depth
  /// for whatever scrip was requested last (an option-chain key, the top
  /// watchlist row), a depth feed no screen tracked and nothing ever released.
  Future<void> _restoreLegacySubscriptions() async {
    if (kIsWeb) return;
    if (ConstantName.lastSubscribe.isNotEmpty) {
      ref.read(websocketProvider).establishConnection(
          channelInput: ConstantName.lastSubscribe,
          task: "t",
          context: _globbcontext!);
    }
    if (ConstantName.lastSubscribeDepth.isNotEmpty) {
      ref.read(websocketProvider).establishConnection(
          channelInput: ConstantName.lastSubscribeDepth,
          task: "d",
          context: _globbcontext!);
    }
  }
  
  /// Restore tab-based subscriptions based on current tab
  Future<void> _restoreTabBasedSubscriptions() async {
    final selectedTab = ref.read(indexListProvider).selectedBtmIndx;
    
    if (selectedTab == 0) {
      // Dashboard tab
      await ref.read(marketWatchProvider)
          .requestMWScrip(context: _globbcontext!, isSubscribe: true);
      ref.read(stocksProvide)
          .requestWSTradeaction(isSubscribe: true, context: _globbcontext!);
    } else if (selectedTab == 1) {
      // Watchlist tab
      await ref.read(marketWatchProvider)
          .requestMWScrip(context: _globbcontext!, isSubscribe: true);
    } else if (selectedTab == 2) {
      // Portfolio tab
      await ref.read(portfolioProvider)
          .requestWSHoldings(isSubscribe: true, context: _globbcontext!);
      await ref.read(portfolioProvider)
          .requestWSPosition(isSubscribe: true, context: _globbcontext!);
      await ref.read(orderProvider)
          .requestWSOrderBook(isSubscribe: true, context: _globbcontext!);
    }
  }
  
  /// Print network restoration debug information
  void _printRestorationDebugInfo() {
    final subscriptionManager = ref.read(subscriptionManagerProvider);
    
    
    if (subscriptionManager.hasActiveSubscriptions) {
      final debugInfo = subscriptionManager.getDebugInfo();
    }
    
  }
}
