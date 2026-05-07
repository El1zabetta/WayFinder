import 'package:flutter/foundation.dart';

/// WayFinder 3.0 — Environment Configuration
/// Manages API URLs and feature flags for different build flavors.
class AppConfig {
  static const String devBaseUrl = 'http://localhost:8000/api/v2';
  static const String devWsUrl = 'ws://localhost:8000/ws';
  
  static const String prodBaseUrl = 'https://api.wayfinder-ai.com/api/v2';
  static const String prodWsUrl = 'wss://api.wayfinder-ai.com/ws';

  /// Returns the base API URL based on build mode.
  /// To use production in debug mode, manually change this or use flavors.
  static String get baseUrl {
    if (kReleaseMode) {
      return prodBaseUrl;
    }
    return devBaseUrl;
  }

  /// Returns the WebSocket URL based on build mode.
  static String get wsUrl {
    if (kReleaseMode) {
      return prodWsUrl;
    }
    return devWsUrl;
  }

  static bool get isProduction => kReleaseMode;
  
  static const String appName = 'WayFinder';
  static const String version = '3.0.0';
}
