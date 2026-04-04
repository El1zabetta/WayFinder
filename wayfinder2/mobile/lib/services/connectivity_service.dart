/// WayFinder 2.0 — Connectivity Service
/// Monitors server reachability with periodic health checks.
/// Provides [isOnline] stream for reactive offline/online UI.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'api_client.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  bool _isOnline = true;
  Timer? _healthTimer;
  int _failCount = 0;

  bool get isOnline => _isOnline;

  /// Start periodic health checks (call once at app startup)
  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _healthTimer?.cancel();
    _checkNow(); // immediate first check
    _healthTimer = Timer.periodic(interval, (_) => _checkNow());
  }

  void stopMonitoring() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  Future<void> _checkNow() async {
    final reachable = await WayFinderApi.isServerReachable();

    if (reachable) {
      _failCount = 0;
      if (!_isOnline) {
        _isOnline = true;
        _log.i('Server back online');
        notifyListeners();
      }
    } else {
      _failCount++;
      // Mark offline after 2 consecutive failures to avoid flicker
      if (_isOnline && _failCount >= 2) {
        _isOnline = false;
        _log.w('Server offline (fail count: $_failCount)');
        notifyListeners();
      }
    }
  }

  /// Force an immediate connectivity check
  Future<bool> checkNow() async {
    await _checkNow();
    return _isOnline;
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
