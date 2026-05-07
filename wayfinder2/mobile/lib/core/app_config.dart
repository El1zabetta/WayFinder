import 'package:flutter/foundation.dart';

/// WayFinder 3.0 — Environment Configuration
/// Manages API URLs and feature flags via --dart-define.
class AppConfig {
  /// Defines the environment: 'dev', 'staging', 'prod'
  static const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: kReleaseMode ? 'prod' : 'dev');

  /// Base URL for REST API.
  static String get baseUrl {
    const String envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Fallbacks for convenience in development
    if (appEnv == 'prod') {
      return 'https://api.wayfinder-ai.com/api/v2';
    }
    // Android emulator default
    return 'http://10.0.2.2:8000/api/v2';
  }

  /// WebSocket URL.
  static String get wsUrl {
    const String envUrl = String.fromEnvironment('WS_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (appEnv == 'prod') {
      return 'wss://api.wayfinder-ai.com/ws';
    }
    // Android emulator default
    return 'ws://10.0.2.2:8000/ws';
  }

  static bool get isProduction => appEnv == 'prod';
  
  static const String appName = 'WayFinder';
  static const String version = '3.0.0';
}
