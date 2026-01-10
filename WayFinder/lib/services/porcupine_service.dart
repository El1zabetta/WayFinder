import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../secrets.dart';

class PorcupineWakeWordService {
  PorcupineManager? _porcupineManager;
  final Function() onWakeWordDetected;
  final Function(String error)? onError;
  
  bool _isListening = false;
  bool _isInitialized = false;

  PorcupineWakeWordService({
    required this.onWakeWordDetected,
    this.onError,
  });

  Future<void> initialize() async {
    print("🔧 [PORCUPINE] Starting initialization with WayFinder model...");
    
    // 1. Check microphone permission
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        onError?.call("Microphone permission denied.");
        return;
      }
    }
    
    // 2. Select access key based on platform
    String accessKey = Secrets.picovoiceAccessKey;
    if (Platform.isIOS) {
      accessKey = Secrets.picovoiceAccessKeyIos;
    }

    if (accessKey.isEmpty || accessKey == 'YOUR_PICOVOICE_ACCESS_KEY_HERE') {
      final errorMsg = "Picovoice Access Key missing for this platform. Please add it to secrets.dart";
      print("❌ [PORCUPINE] $errorMsg");
      onError?.call(errorMsg);
      return;
    }
    
    try {
      // 3. Initialize Porcupine with custom wake word "WayFinder"
      String keywordPath = '';
      if (Platform.isAndroid) {
        keywordPath = 'assets/words/way_finder_android.ppn';
      } else if (Platform.isIOS) {
        keywordPath = 'assets/words/way_finder_ios.ppn';
      } else {
        keywordPath = 'assets/words/way_finder.ppn'; // Default/Fallback
      }

      print("📂 [PORCUPINE] Loading platform model: $keywordPath");
      
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        accessKey,
        [keywordPath], 
        _wakeWordCallback,
        errorCallback: _errorCallback
      );
      
      _isInitialized = true;
      print("✅ [PORCUPINE] WayFinder wake word ready!");
      
    } on PorcupineException catch (err) {
      _isInitialized = false;
      String friendlyError = "Porcupine Error: ${err.message}";
      if (err.message?.contains("INVALID_ARGUMENT") ?? false) {
        friendlyError = "Invalid model file or Access Key";
      }
      print("❌ [PORCUPINE] $friendlyError");
      onError?.call(friendlyError);
    } catch (err) {
      _isInitialized = false;
      onError?.call("Initialization failed: $err");
    }
  }

  void _wakeWordCallback(int keywordIndex) {
    if (keywordIndex == 0) {
      print("🚀 [PORCUPINE] WAYFINDER ACTIVATED!");
      onWakeWordDetected();
    }
  }

  void _errorCallback(PorcupineException error) {
    print("❌ [PORCUPINE] Runtime error: $error");
    onError?.call(error.message ?? "Runtime error");
  }

  Future<void> startListening() async {
    if (!_isInitialized || _isListening) return;
    try {
      await _porcupineManager?.start();
      _isListening = true;
      print("👂 [PORCUPINE] Listening list for 'WayFinder'...");
    } catch (e) {
      _isListening = false;
      onError?.call("Failed to start: $e");
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _porcupineManager?.stop();
      _isListening = false;
    } catch (e) {
      print("❌ [PORCUPINE] Stop error: $e");
    }
  }

  Future<void> dispose() async {
    await stopListening();
    await _porcupineManager?.delete();
    _isInitialized = false;
  }
  
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
}
