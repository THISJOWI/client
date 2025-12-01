import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';


/// Service to monitor network connectivity status
/// 
/// This service provides:
/// - Real-time connectivity status monitoring
/// - Stream of connectivity changes
/// - Simple boolean check for online/offline status
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = 
      StreamController<bool>.broadcast();
  
  bool _isOnline = true;
  
  factory ConnectivityService() => _instance;
  
  ConnectivityService._internal() {
    _initConnectivity();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  /// Initialize connectivity status
  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      // If we can't check connectivity, assume offline
      _isOnline = false;
      _connectionStatusController.add(false);
    }
  }

  /// Update connection status based on connectivity result
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // Check if any of the results indicates a connection
    final hasConnection = results.any((result) => 
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn
    );
    
    if (_isOnline != hasConnection) {
      _isOnline = hasConnection;
      _connectionStatusController.add(_isOnline);
    }
  }

  /// Get current online/offline status
  bool get isOnline => _isOnline;

  /// Stream of connectivity status changes
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  /// Check connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((result) => 
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn
      );
    } catch (e) {
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectionStatusController.close();
  }
}
