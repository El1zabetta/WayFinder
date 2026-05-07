/// WayFinder 3.0 — Wakeword Service
/// Uses Porcupine to listen for the "WayFinder" (.ppn file) wake word offline.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:logger/logger.dart';

import '../core/accessibility.dart';
import '../core/secrets.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class WakewordService extends ChangeNotifier {
  PorcupineManager? _porcupineManager;
  bool _isListening = false;
  bool _isInitialized = false;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  // Callback when wakeword is detected
  VoidCallback? onWakewordDetected;

  /// Initialize Porcupine with the custom .ppn file
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // NOTE: Picovoice requires an AccessKey from console.picovoice.ai
      const accessKey = Secrets.picovoiceAccessKey; 

      // Use platform-specific .ppn file paths
      final String keywordPath = Platform.isAndroid 
          ? "assets/models/wayfinder_android.ppn" 
          : "assets/models/wayfinder_ios.ppn";

      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        accessKey,
        [keywordPath],
        _wakeWordCallback,
      );

      _isInitialized = true;
      notifyListeners();
      _log.i("Porcupine Wakeword initialized successfully with $keywordPath");

    } on PorcupineException catch (e) {
      _log.e("Failed to initialize Porcupine: \${e.message}");
    } catch (e) {
      _log.e("Unexpected error initializing Porcupine: $e");
    }
  }

  void _wakeWordCallback(int keywordIndex) {
    if (keywordIndex == 0) {
      _log.i("Wakeword 'WayFinder' detected!");
      HapticPatterns.success();
      if (onWakewordDetected != null) {
        onWakewordDetected!();
      }
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized || _porcupineManager == null || _isListening) return;

    try {
      await _porcupineManager!.start();
      _isListening = true;
      notifyListeners();
      _log.d("Started listening for wakeword.");
    } on PorcupineException catch (e) {
      _log.e("Failed to start listening: \${e.message}");
    }
  }

  Future<void> stopListening() async {
    if (!_isListening || _porcupineManager == null) return;

    try {
      await _porcupineManager!.stop();
      _isListening = false;
      notifyListeners();
      _log.d("Stopped listening for wakeword.");
    } on PorcupineException catch (e) {
      _log.e("Failed to stop listening: \${e.message}");
    }
  }

  @override
  void dispose() {
    _porcupineManager?.delete();
    super.dispose();
  }
}
