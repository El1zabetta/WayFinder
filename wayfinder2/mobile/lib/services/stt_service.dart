// WayFinder 3.0 — Speech-to-Text Service
// Wraps the speech_to_text package for voice-first Q&A.
// Handles: init, locale detection, listening lifecycle, error states.

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Callback types for STT events
typedef SttResultCallback = void Function(String text, bool isFinal);
typedef SttErrorCallback = void Function(String errorMsg);

class SttService {
  static final SttService _instance = SttService._();
  factory SttService() => _instance;
  SttService._();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _initialized = false;
  bool _available = false;
  bool _listening = false;
  String _currentLocale = 'en_US';

  bool get isAvailable => _available;
  bool get isListening => _listening;
  bool get isInitialized => _initialized;

  /// Initialize the STT engine. Must be called once before use.
  /// Returns true if STT is available on this device.
  Future<bool> init() async {
    if (_initialized) return _available;

    try {
      _available = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
        debugLogging: false,
      );
      _initialized = true;

      if (_available) {
        // Try to find best locale (prefer system locale)
        final locales = await _speech.locales();
        final hasRussian = locales.any((l) => l.localeId.startsWith('ru'));
        final hasEnglish = locales.any((l) => l.localeId.startsWith('en'));
        _log.i('[STT] Available. Locales: ${locales.length} '
            '(en=$hasEnglish, ru=$hasRussian)');
      } else {
        _log.w('[STT] Speech recognition not available on this device.');
      }
    } catch (e) {
      _log.e('[STT] Initialization failed: $e');
      _available = false;
      _initialized = true; // Mark as initialized to prevent retry loops
    }

    return _available;
  }

  // Active callbacks during a listening session
  SttResultCallback? _onResult;
  SttErrorCallback? _onError;
  VoidCallback? _onDone;

  /// Start listening for speech.
  ///
  /// [onResult] fires with (text, isFinal) on each recognition update.
  /// [onDone] fires when recognition completes (user stopped speaking).
  /// [onError] fires on any STT error.
  /// [listenForSeconds] is the maximum listen duration before auto-stop.
  /// [localeId] overrides the locale (e.g. 'ru_RU'). Null = auto-detect.
  Future<bool> startListening({
    required SttResultCallback onResult,
    VoidCallback? onDone,
    SttErrorCallback? onError,
    int listenForSeconds = 15,
    String? localeId,
  }) async {
    if (!_available) {
      onError?.call('Speech recognition is not available on this device.');
      return false;
    }

    if (_listening) {
      await stopListening();
    }

    _onResult = onResult;
    _onDone = onDone;
    _onError = onError;

    try {
      _listening = true;
      await _speech.listen(
        onResult: _handleResult,
        listenFor: Duration(seconds: listenForSeconds),
        pauseFor: const Duration(seconds: 3),
        localeId: localeId ?? _currentLocale,
      );
      _log.d('[STT] Started listening (max ${listenForSeconds}s)');
      return true;
    } catch (e) {
      _listening = false;
      _log.e('[STT] Failed to start listening: $e');
      onError?.call('Could not start voice recognition.');
      return false;
    }
  }

  /// Stop listening immediately.
  Future<void> stopListening() async {
    if (!_listening) return;
    try {
      await _speech.stop();
    } catch (e) {
      _log.e('[STT] Error stopping: $e');
    }
    _listening = false;
  }

  /// Cancel listening without processing partial results.
  Future<void> cancelListening() async {
    if (!_listening) return;
    try {
      await _speech.cancel();
    } catch (e) {
      _log.e('[STT] Error cancelling: $e');
    }
    _listening = false;
    _onResult = null;
    _onDone = null;
    _onError = null;
  }

  /// Set the preferred locale for recognition.
  void setLocale(String localeId) {
    _currentLocale = localeId;
  }

  // ─── Internal Handlers ─────────────────────────────────────────────────

  void _handleResult(SpeechRecognitionResult result) {
    _onResult?.call(result.recognizedWords, result.finalResult);

    if (result.finalResult) {
      _listening = false;
      _onDone?.call();
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    _log.e('[STT] Error: ${error.errorMsg} (permanent=${error.permanent})');
    _listening = false;

    if (error.permanent) {
      _onError?.call('Voice recognition encountered a permanent error.');
    } else {
      // Transient errors (e.g. no match / silence) trigger onDone
      _onDone?.call();
    }
  }

  void _onSpeechStatus(String status) {
    _log.d('[STT] Status: $status');
    if (status == 'notListening' || status == 'done') {
      if (_listening) {
        _listening = false;
        _onDone?.call();
      }
    }
  }
}
