import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      print('🌐 Initializing ConnectivityService...');

      // Check initial connectivity
      _isOnline = await checkConnectivity();
      print('📡 Initial connectivity: ${_isOnline ? "✅ Online" : "❌ Offline"}');

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) async {
          final wasOnline = _isOnline;
          _isOnline = await checkConnectivity();

          // Only notify if state actually changed
          if (wasOnline != _isOnline) {
            _connectivityController.add(_isOnline);

            // Log connectivity changes
            if (!wasOnline && _isOnline) {
              print('🌐 ✅ Internet connection restored');
            } else if (wasOnline && !_isOnline) {
              print('📴 ⚠️ Internet connection lost');
            }
          }
        },
        onError: (error) {
          print('❌ Connectivity stream error: $error');
        },
        cancelOnError: false,
      );

      print('✅ ConnectivityService initialized successfully');
    } catch (e) {
      print('❌ Error initializing connectivity service: $e');
      // On web, assume online by default if there's an error
      _isOnline = kIsWeb ? true : false;
    }
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      // For web platform, assume always online
      // connectivity_plus has limited web support
      if (kIsWeb) {
        return true;
      }

      final results = await _connectivity.checkConnectivity().timeout(
            const Duration(seconds: 3),
            onTimeout: () => [ConnectivityResult.none],
          );

      final hasConnection = results.any((result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet);

      return hasConnection;
    } catch (e) {
      print('❌ Error checking connectivity: $e');
      // On web, assume online by default if there's an error
      return kIsWeb ? true : false;
    }
  }

  /// Get connectivity type
  Future<String> getConnectivityType() async {
    try {
      // For web platform, return 'Web'
      if (kIsWeb) {
        return 'Web';
      }

      final results = await _connectivity.checkConnectivity().timeout(
            const Duration(seconds: 2),
            onTimeout: () => [ConnectivityResult.none],
          );

      if (results.contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      } else if (results.contains(ConnectivityResult.mobile)) {
        return 'Mobile Data';
      } else if (results.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      } else {
        return 'Offline';
      }
    } catch (e) {
      return kIsWeb ? 'Web' : 'Unknown';
    }
  }

  /// Dispose resources
  void dispose() {
    print('🔌 Disposing ConnectivityService');
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
}
