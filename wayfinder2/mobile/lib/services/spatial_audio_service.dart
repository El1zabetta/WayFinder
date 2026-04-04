/// WayFinder 2.0 — 3D Spatial Audio Service
/// Converts RynnBrain spatial coordinates to immersive directional audio cues.
/// Uses flutter_tts for voice synthesis with left/right panning.

import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:logger/logger.dart';

import '../services/api_client.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class SpatialAudioService {
  static final SpatialAudioService _instance = SpatialAudioService._();
  factory SpatialAudioService() => _instance;
  SpatialAudioService._() {
    _init();
  }

  late FlutterTts _tts;
  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _initialized = false;

  Future<void> _init() async {
    _tts = FlutterTts();

    // Set default to English, but we'll dynamic switch in _ensureLanguage
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5); 
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    _initialized = true;
    _log.d('[SpatialAudio] Initialized TTS');
  }

  Future<void> _ensureLanguage(String text) async {
    final isRussian = RegExp(r'[а-яА-Я]').hasMatch(text);
    final targetLang = isRussian ? 'ru-RU' : 'en-US';
    await _tts.setLanguage(targetLang);
  }

  String _stripTags(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '') // remove <tags>
        .replaceAll(RegExp(r'[\(（][↑←→STOP]+[\)）]'), '') // remove symbols in brackets
        .replaceAll(RegExp(r'→|←|↑|STOP'), '') // remove raw symbols
        .replaceAll(RegExp(r'\s+'), ' ') // normalize spaces
        .trim();
  }

  /// Speak text with direction, stripping AI tags first.
  Future<void> speak(String text, {double azimuth = 0.0, String priority = 'MEDIUM'}) async {
    final cleanText = _stripTags(text);
    if (cleanText.isEmpty) return;

    if (!_initialized) await _init();
    await _ensureLanguage(cleanText);

    String spatialText = _buildSpatialText(cleanText, azimuth);
    final pan = (azimuth / 45.0).clamp(-1.0, 1.0);
    await _sfxPlayer.setBalance(pan);

    _log.d('[SpatialAudio] Speaking: "$spatialText"');
    await _tts.speak(spatialText);
  }

  /// Specialized for narrating what RynnBrain sees.
  Future<void> speakAnalysis(String text) async {
    await speak(text, azimuth: 0.0, priority: 'MEDIUM');
  }

  /// Play a sequence of AudioCue objects from RynnBrain response.
  /// High-priority threats are spoken first.
  Future<void> playCues(List<AudioCue> cues) async {
    final sorted = List<AudioCue>.from(cues)
      ..sort((a, b) => _priorityValue(b.priority) - _priorityValue(a.priority));

    for (final cue in sorted) {
      await speak(cue.message, azimuth: cue.azimuth, priority: cue.priority);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  /// Speak a threat alert — always urgent, with direction.
  Future<void> announceThreats(List<ThreatInfo> threats) async {
    if (threats.isEmpty) return;

    for (final threat in threats) {
      final dir = _aziToWord(threat.azimuth);
      await speak(
        'Warning! Obstacle $dir.',
        azimuth: threat.azimuth,
        priority: 'HIGH',
      );
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Announce navigation action.
  Future<void> announceNavAction(String? action) async {
    if (action == null) return;
    final Map<String, String> actionPhrases = {
      'MOVE_FORWARD': 'Move forward.',
      'TURN_LEFT': 'Turn left.',
      'TURN_RIGHT': 'Turn right.',
      'STOP': 'Stop. Hold position.',
    };
    final phrase = actionPhrases[action] ?? action;
    await speak(phrase, azimuth: 0.0, priority: 'HIGH');
  }

  /// Object found announcement with direction.
  Future<void> announceObjectFound(String objectName, double azimuth) async {
    final dir = _aziToWord(azimuth);
    await speak('$objectName found $dir.', azimuth: azimuth, priority: 'HIGH');
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  String _buildSpatialText(String text, double azimuth) {
    if (azimuth.abs() < 10) return text;  // Center — no prefix needed
    final dir = _aziToWord(azimuth);
    return '$dir: $text';
  }

  String _aziToWord(double azimuth) {
    if (azimuth < -30) return 'to your left';
    if (azimuth > 30) return 'to your right';
    if (azimuth < -10) return 'slightly left';
    if (azimuth > 10) return 'slightly right';
    return 'ahead';
  }

  int _priorityValue(String p) {
    switch (p) {
      case 'CRITICAL': return 4;
      case 'HIGH': return 3;
      case 'MEDIUM': return 2;
      case 'LOW': return 1;
      default: return 0;
    }
  }
}
