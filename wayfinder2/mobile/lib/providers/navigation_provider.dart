/// WayFinder 2.0 — Navigation Provider
/// State management for active navigation session with RynnBrain-Nav.
/// Includes structured error handling with spoken/accessible feedback.
/// Supports offline fallback with cached analysis when server is unreachable.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../services/api_client.dart';
import '../services/spatial_audio_service.dart';
import '../services/offline_cache_service.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

enum NavigationState { idle, recording, analyzing, navigating, error, offline }

class NavigationProvider extends ChangeNotifier {
  NavigationState _state = NavigationState.idle;
  RynnBrainResult? _lastResult;
  String? _errorMessage;
  String _destination = '';
  bool _isAuthError = false;
  bool _isNetworkError = false;
  bool _isOffline = false;
  String _lastGuidance = '';
  DateTime? _lastGuidanceTime;

  final SpatialAudioService _audio = SpatialAudioService();
  final OfflineCacheService _cache = OfflineCacheService();

  NavigationState get state => _state;
  RynnBrainResult? get lastResult => _lastResult;
  String? get errorMessage => _errorMessage;
  String get destination => _destination;
  bool get isActive => _state == NavigationState.navigating || _state == NavigationState.analyzing;
  bool get isAuthError => _isAuthError;
  bool get isNetworkError => _isNetworkError;
  bool get isOffline => _isOffline;

  void setDestination(String dest) {
    _destination = dest;
    notifyListeners();
  }

  Future<void> analyzeVideoClip(File videoFile) async {
    _setState(NavigationState.analyzing);
    _errorMessage = null;
    _isAuthError = false;
    _isNetworkError = false;
    _isOffline = false;

    try {
      final result = await WayFinderApi.analyzeVideo(
        videoFile,
        query: _destination.isNotEmpty
            ? 'Navigate to: $_destination. Identify obstacles.'
            : 'Analyze scene for safe navigation. Detect all hazards.',
        mode: 'nav',
      );

      _lastResult = result;
      _setState(NavigationState.navigating);

      // Cache the result for offline use
      await _cache.cacheNavigation(result.rawText, {
        'mode': result.mode,
        'raw_text': result.rawText,
        'navigation_action': result.navigationAction,
      });

      // 1. Narrative description (what's in front)
      // De-duplicate guidance: only speak if changed or > 5s passed
      final now = DateTime.now();
      if (result.rawText != _lastGuidance || 
          _lastGuidanceTime == null || 
          now.difference(_lastGuidanceTime!).inSeconds > 5) {
        await _audio.speakAnalysis(result.rawText);
        _lastGuidance = result.rawText;
        _lastGuidanceTime = now;
      }

      // 2. Immediate threats alert
      if (result.hasThreats) {
        await _audio.announceThreats(result.threats);
      }

      // 3. Audio cues (panned spatial dots)
      if (result.audioCues.isNotEmpty) {
        await _audio.playCues(result.audioCues);
      }

      // 4. Critical navigation action (TURN LEFT, etc.)
      if (result.navigationAction != null) {
        await _audio.announceNavAction(result.navigationAction);
      }

    } on ApiException catch (e) {
      _log.e('Navigation analysis API error: $e');
      _isAuthError = e.isAuth;
      _isNetworkError = e.isNetwork;

      // ─── Offline fallback ────────────────────────────────────────────────
      if (e.isNetwork || e.isTimeout) {
        _isOffline = true;
        final cachedText = await _cache.getCachedNavigationText();
        if (cachedText != null && cachedText.isNotEmpty) {
          _errorMessage = 'Offline mode. Showing last known analysis.';
          _setState(NavigationState.offline);
          await _audio.speak(
            'Server unreachable. Using last known analysis. $cachedText',
          );
          return;
        } else {
          // No cache — use safety hint
          final hint = OfflineCacheService.getRandomHint();
          _errorMessage = 'Offline. No saved data.';
          _setState(NavigationState.offline);
          await _audio.speak(
            'Server unreachable. No saved analysis available. Safety tip: $hint',
          );
          return;
        }
      }

      _errorMessage = e.userMessage;
      _setState(NavigationState.error);

      // Speak specific error
      if (e.isAuth) {
        await _audio.speak('Session expired. Please sign in again to continue.');
      } else {
        await _audio.speak('Could not analyze the scene. Tap to try again.');
      }
    } catch (e) {
      _log.e('Navigation analysis unexpected error: $e');
      _errorMessage = 'Scene analysis error. Tap to try again.';
      _isAuthError = false;
      _isNetworkError = false;
      _setState(NavigationState.error);
      await _audio.speak('A problem occurred. Tap to try again.');
    }
  }

  Future<void> runSafetyCheck(File videoFile) async {
    _setState(NavigationState.analyzing);
    _errorMessage = null;
    _isAuthError = false;
    _isNetworkError = false;

    try {
      final threats = await WayFinderApi.detectThreats(videoFile);
      final alertLevel = threats['alert_level'] ?? 'LOW';
      final cues = (threats['audio_cues'] as List? ?? [])
          .map((a) => AudioCue.fromJson(a))
          .toList();

      await _audio.speak(
        alertLevel == 'LOW'
            ? 'Path is clear. No immediate threats detected.'
            : 'Alert level: $alertLevel. Proceed with caution.',
        azimuth: 0.0,
        priority: alertLevel,
      );
      await _audio.playCues(cues);
      _setState(NavigationState.idle);

    } on ApiException catch (e) {
      _log.e('Safety check API error: $e');
      _errorMessage = e.userMessage;
      _isAuthError = e.isAuth;
      _isNetworkError = e.isNetwork;

      if (e.isNetwork || e.isTimeout) {
        _isOffline = true;
        final hint = OfflineCacheService.getRandomHint();
        _setState(NavigationState.offline);
        await _audio.speak('Offline. Cannot verify safety. Safety tip: $hint');
      } else {
        _setState(NavigationState.error);
        await _audio.speak('Safety check error. Please try again.');
      }
    } catch (e) {
      _log.e('Safety check failed: $e');
      _errorMessage = 'Safety check error. Please try again.';
      _setState(NavigationState.error);
      await _audio.speak('Safety check error.');
    }
  }

  void reset() {
    _state = NavigationState.idle;
    _lastResult = null;
    _errorMessage = null;
    _isAuthError = false;
    _isNetworkError = false;
    _isOffline = false;
    _destination = '';
    _audio.stop();
    notifyListeners();
  }

  void _setState(NavigationState s) {
    _state = s;
    notifyListeners();
  }
}
