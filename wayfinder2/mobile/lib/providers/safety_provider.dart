/// WayFinder 2.0 — Safety Provider
/// Continuous threat monitoring state using RynnBrain-CoP
/// Supports offline fallback with cached safety data and hints.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../services/api_client.dart';
import '../services/spatial_audio_service.dart';
import '../services/offline_cache_service.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

enum AlertLevel { low, medium, high, critical }

class SafetyProvider extends ChangeNotifier {
  AlertLevel _alertLevel = AlertLevel.low;
  List<ThreatInfo> _threats = [];
  bool _monitoringActive = false;
  String _lastAnalysis = '';
  bool _isOffline = false;

  final SpatialAudioService _audio = SpatialAudioService();
  final OfflineCacheService _cache = OfflineCacheService();

  AlertLevel get alertLevel => _alertLevel;
  List<ThreatInfo> get threats => _threats;
  bool get monitoringActive => _monitoringActive;
  String get lastAnalysis => _lastAnalysis;
  bool get isDangerous => _alertLevel.index >= AlertLevel.high.index;
  bool get isOffline => _isOffline;

  Future<void> checkSafety(File videoFile) async {
    try {
      _isOffline = false;
      final data = await WayFinderApi.detectThreats(videoFile);

      _lastAnalysis = data['analysis_text'] ?? '';
      _threats = (data['threats'] as List? ?? [])
          .map((t) => ThreatInfo.fromJson(t))
          .toList();

      final levelStr = (data['alert_level'] as String? ?? 'LOW').toUpperCase();
      _alertLevel = switch (levelStr) {
        'CRITICAL' => AlertLevel.critical,
        'HIGH' => AlertLevel.high,
        'MEDIUM' => AlertLevel.medium,
        _ => AlertLevel.low,
      };

      notifyListeners();

      // Cache the analysis for offline use
      if (_lastAnalysis.isNotEmpty) {
        await _cache.cacheSafety(_lastAnalysis);
      }

      // Speak narrative analysis first
      if (_lastAnalysis.isNotEmpty) {
        await _audio.speakAnalysis(_lastAnalysis);
      }

      // Audio alert for threats
      if (isDangerous) {
        await _audio.announceThreats(_threats);
      }

      final cues = (data['audio_cues'] as List? ?? [])
          .map((a) => AudioCue.fromJson(a))
          .toList();
      await _audio.playCues(cues);

    } on ApiException catch (e) {
      _log.e('Safety check error: $e');

      // ─── Offline fallback ────────────────────────────────────────────────
      if (e.isNetwork || e.isTimeout) {
        _isOffline = true;
        notifyListeners();

        final cachedSafety = await _cache.getCachedSafetyText();
        if (cachedSafety != null && cachedSafety.isNotEmpty) {
          await _audio.speak(
            'Offline. Using last safety data. $cachedSafety',
          );
        } else {
          final hint = OfflineCacheService.getRandomHint();
          await _audio.speak(
            'Offline. No cached safety data. Safety tip: $hint',
          );
        }
      }
    } catch (e) {
      _log.e('Safety check error: $e');
    }
  }

  void clearThreats() {
    _threats = [];
    _alertLevel = AlertLevel.low;
    _isOffline = false;
    notifyListeners();
  }
}
