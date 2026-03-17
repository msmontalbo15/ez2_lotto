// lib/connectivity_service.dart
// Network connectivity monitoring for offline support

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  /// Stream of connectivity status (true = online, false = offline)
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Current connectivity status
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Initialize and start listening to connectivity changes
  Future<void> init() async {
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    // Listen for changes
    _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;

    // Consider online if any connectivity type is available
    _isOnline =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);

    // Notify listeners if status changed
    if (wasOnline != _isOnline) {
      _controller.add(_isOnline);
    }
  }

  /// Check current connectivity explicitly
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    return _isOnline;
  }

  void dispose() {
    _controller.close();
  }
}
