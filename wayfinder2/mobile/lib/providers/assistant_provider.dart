/// WayFinder 3.0 — Assistant Provider
/// State management for Ask-Wayfinder mode.
/// Handles: listening → processing → answering → done cycle.
/// Includes structured error handling with user-friendly spoken feedback.
/// Supports offline fallback with cached Q&A answers.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../core/accessibility.dart';
import '../services/api_client.dart';
import '../services/spatial_audio_service.dart';
import '../services/offline_cache_service.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

enum AssistantState {
  idle,
  listening,
  processing,
  answering,
  done,
  error,
  offline,
  wakeWordListening,
  wakeWordDetected,
}

class AssistantProvider extends ChangeNotifier {
  AssistantState _state = AssistantState.idle;
  String _transcript = '';
  String _answer = '';
  double _confidence = 0.0;
  String? _errorMessage;
  bool _isAuthError = false;
  bool _isOffline = false;

  final SpatialAudioService _audio = SpatialAudioService();
  final OfflineCacheService _cache = OfflineCacheService();

  // Public getters
  AssistantState get state => _state;
  String get transcript => _transcript;
  String get answer => _answer;
  double get confidence => _confidence;
  String? get errorMessage => _errorMessage;
  bool get isAuthError => _isAuthError;
  bool get isOffline => _isOffline;
  bool get isProcessing =>
      _state == AssistantState.listening ||
      _state == AssistantState.processing ||
      _state == AssistantState.answering;

  String get stateText {
    switch (_state) {
      case AssistantState.idle:
        return 'Wake word disabled';
      case AssistantState.wakeWordListening:
        return 'Listening for WayFinder';
      case AssistantState.wakeWordDetected:
        return 'WayFinder activated';
      case AssistantState.listening:
        return 'Listening to question';
      case AssistantState.processing:
        return 'Sending question';
      case AssistantState.answering:
        return 'Answer ready';
      case AssistantState.done:
        return 'Answer spoken';
      case AssistantState.error:
        return 'Error';
      case AssistantState.offline:
        return 'Offline';
    }
  }

  void setIdle() {
    _setState(AssistantState.idle);
  }

  void setWakeWordListening() {
    _setState(AssistantState.wakeWordListening);
  }

  void setWakeWordDetected() {
    _setState(AssistantState.wakeWordDetected);
    HapticPatterns.success();
  }

  void setListening() {
    _setState(AssistantState.listening);
  }

  /// Set the transcript from speech recognition
  void setTranscript(String text) {
    _transcript = text;
    notifyListeners();
  }

  /// Submit a question with optional visual context
  Future<void> askQuestion(
    String question, {
    File? imageFile,
    File? videoFile,
  }) async {
    _transcript = question;
    _answer = '';
    _errorMessage = null;
    _isAuthError = false;
    _isOffline = false;
    _setState(AssistantState.processing);

    try {
      final result = await WayFinderApi.askWayfinder(
        question,
        imageFile: imageFile,
        videoFile: videoFile,
      );

      _answer = result.answer;
      _confidence = result.confidence;
      _setState(AssistantState.answering);

      // Cache the Q&A for offline use
      await _cache.cacheQA(question, result.answer);

      // Speak the answer — prefix with uncertainty if low confidence
      String spokenAnswer = result.answer;
      if (result.confidence < 0.5 && result.confidence > 0.0) {
        spokenAnswer = "I'm not entirely sure, but $spokenAnswer";
      }
      await _audio.speak(spokenAnswer);

      _setState(AssistantState.done);

    } on ApiException catch (e) {
      _log.e('Ask-Wayfinder API error: $e');
      _isAuthError = e.isAuth;

      // ─── Offline fallback ────────────────────────────────────────────────
      if (e.isNetwork || e.isTimeout) {
        _isOffline = true;
        final cachedAnswer = await _cache.findCachedAnswer(question);
        if (cachedAnswer != null) {
          _answer = cachedAnswer;
          _confidence = 0.0;
          _errorMessage = 'Offline mode. Showing cached answer.';
          _setState(AssistantState.offline);
          await _audio.speak(
            'Server unreachable. From my memory: $cachedAnswer',
          );
          return;
        } else {
          _errorMessage = 'Offline. No cached answer for this question.';
          _setState(AssistantState.offline);
          await _audio.speak(
            'Server unreachable. I have no cached answer for this question. '
            'Please try again when you have an internet connection.',
          );
          return;
        }
      }

      _errorMessage = e.userMessage;
      _answer = '';
      _setState(AssistantState.error);

      // Speak a clear, specific error message
      if (e.isAuth) {
        await _audio.speak('Your session has expired. Please sign in again.');
      } else {
        await _audio.speak("I cannot answer this right now. Please try again.");
      }
    } catch (e) {
      _log.e('Ask-Wayfinder unexpected error: $e');
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _isAuthError = false;
      _answer = '';
      _setState(AssistantState.error);
      await _audio.speak("Something went wrong. Please try again.");
    }
  }

  /// Repeat the last answer via TTS
  Future<void> repeatAnswer() async {
    if (_answer.isNotEmpty) {
      _setState(AssistantState.answering);
      try {
        await _audio.speak(_answer);
      } catch (e) {
        _log.w('TTS replay failed: $e');
        // Don't break state — just log and continue
      }
      _setState(AssistantState.done);
    }
  }

  /// Reset for a new question
  void resetForNewQuestion() {
    _transcript = '';
    _answer = '';
    _errorMessage = null;
    _isAuthError = false;
    _isOffline = false;
    _setState(AssistantState.idle);
  }

  /// Full reset
  void reset() {
    _state = AssistantState.idle;
    _transcript = '';
    _answer = '';
    _confidence = 0.0;
    _errorMessage = null;
    _isAuthError = false;
    _isOffline = false;
    _audio.stop();
    notifyListeners();
  }

  void _setState(AssistantState s) {
    _state = s;
    notifyListeners();
  }
}
