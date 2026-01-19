import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// Enhanced Speech Recognition Service
/// Properly handles wake word detection and command extraction
class EnhancedSpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  
  // Callbacks
  Function(String command)? onCommandDetected;
  Function(String error)? onError;
  Function(String partialText)? onPartialResult;
  
  // Wake words (case-insensitive)
  final List<String> _wakeWords = [
    'wayfinder',
    'вейфайндер',
    'вэйфайндер',
    'wayf',
  ];

  /// Initialize speech recognition
  Future<bool> initialize() async {
    print("🎤 [SPEECH] Initializing speech recognition...");
    
    // Check microphone permission
    final micStatus = await Permission.microphone.status;
    print("🎤 [SPEECH] Microphone permission: $micStatus");
    
    if (!micStatus.isGranted) {
      print("⚠️ [SPEECH] Requesting microphone permission...");
      final result = await Permission.microphone.request();
      
      if (!result.isGranted) {
        final error = "Microphone permission denied";
        print("❌ [SPEECH] $error");
        onError?.call(error);
        return false;
      }
    }

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          print("❌ [SPEECH] Error: ${error.errorMsg}");
          onError?.call(error.errorMsg);
        },
        onStatus: (status) {
          print("📊 [SPEECH] Status: $status");
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        debugLogging: true,
      );

      if (_isInitialized) {
        print("✅ [SPEECH] Speech recognition initialized successfully");
        
        // Get available locales
        final locales = await _speech.locales();
        print("🌍 [SPEECH] Available locales: ${locales.length}");
        
        // Find Russian locale
        final ruLocale = locales.firstWhere(
          (l) => l.localeId.startsWith('ru'),
          orElse: () => locales.first,
        );
        print("🇷🇺 [SPEECH] Selected locale: ${ruLocale.localeId}");
      }

      return _isInitialized;
    } catch (e) {
      print("❌ [SPEECH] Initialization error: $e");
      onError?.call(e.toString());
      return false;
    }
  }

  /// Listen for wake word + command
  Future<void> listenForCommand({
    Duration timeout = const Duration(seconds: 10),
    bool extractCommand = true,
  }) async {
    if (!_isInitialized) {
      print("⚠️ [SPEECH] Not initialized, initializing now...");
      final success = await initialize();
      if (!success) return;
    }

    if (_isListening) {
      print("⚠️ [SPEECH] Already listening");
      return;
    }

    print("👂 [SPEECH] Starting to listen for command...");
    print("⏱️ [SPEECH] Timeout: ${timeout.inSeconds} seconds");

    // Get Russian locale
    final locales = await _speech.locales();
    final ruLocale = locales.firstWhere(
      (l) => l.localeId.startsWith('ru'),
      orElse: () => locales.first,
    );

    _isListening = true;

    DateTime lastSoundTime = DateTime.now();

    await _speech.listen(
      onResult: (result) {
        final recognizedText = result.recognizedWords;
        final isFinal = result.finalResult;
        lastSoundTime = DateTime.now(); // Reset timer on any speech result
        
        print("🎯 [SPEECH] Recognized: '$recognizedText' (final: $isFinal)");
        
        // Show partial results
        if (!isFinal && onPartialResult != null) {
          onPartialResult!(recognizedText);
        }

        // Process final result or force process if recognized text is long enough
        if (recognizedText.isNotEmpty) {
          if (isFinal) {
            print("🚀 [SPEECH] FINAL Result received, processing immediately!");
            _processRecognizedText(recognizedText, extractCommand);
          }
        }
      },
      localeId: ruLocale.localeId,
      listenFor: timeout,
      pauseFor: const Duration(seconds: 5), // Increased for stability
      partialResults: true,
      listenMode: stt.ListenMode.dictation, // Dictation is much more reliable than confirmation
      cancelOnError: false,
      onSoundLevelChange: (level) {
        // Any sound activity resets the timer
        if (level > 0.5) { 
          lastSoundTime = DateTime.now();
        }
      },
    );

    // Monitoring loop for silence
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_isListening) return false;
      
      final silenceDuration = DateTime.now().difference(lastSoundTime);
      if (silenceDuration.inSeconds >= 5) { // Increased from 3s to 5s for thoughtful speech
        print("🤫 [SPEECH] Silence detected (5s). Forcing stop...");
        if (_speech.lastRecognizedWords.isNotEmpty) {
          _processRecognizedText(_speech.lastRecognizedWords, extractCommand);
        }
        await stop();
        return false;
      }
      return true;
    });
  }

  /// Process recognized text and extract command
  void _processRecognizedText(String text, bool extractCommand) {
    print("🔍 [SPEECH] Processing: '$text'");
    
    final lowerText = text.toLowerCase().trim();
    
    if (extractCommand) {
      // Extract command after wake word
      String? command = _extractCommand(lowerText);
      
      if (command != null && command.isNotEmpty) {
        print("✅ [SPEECH] Extracted command: '$command'");
        onCommandDetected?.call(command);
      } else {
        print("⚠️ [SPEECH] No command found after wake word");
        // If no command, use default
        onCommandDetected?.call("что передо мной?");
      }
    } else {
      // Return full text
      print("✅ [SPEECH] Full text: '$text'");
      onCommandDetected?.call(text);
    }
  }

  /// Extract command after wake word
  String? _extractCommand(String text) {
    print("🔎 [SPEECH] Extracting command from: '$text'");
    
    // Find wake word position
    int wakeWordEnd = -1;
    String foundWakeWord = '';
    
    for (final wakeWord in _wakeWords) {
      final index = text.indexOf(wakeWord);
      if (index != -1) {
        wakeWordEnd = index + wakeWord.length;
        foundWakeWord = wakeWord;
        print("✅ [SPEECH] Found wake word '$foundWakeWord' at position $index");
        break;
      }
    }

    // If wake word not found, check for partial matches
    if (wakeWordEnd == -1) {
      // Check if text contains parts of wake word
      if (text.contains('вей') || text.contains('файн') || text.contains('way')) {
        print("⚠️ [SPEECH] Partial wake word detected, using full text as command");
        return text;
      }
      
      print("⚠️ [SPEECH] No wake word found, using full text");
      return text;
    }

    // Extract everything after wake word
    String command = text.substring(wakeWordEnd).trim();
    
    // Remove common filler words at the start
    final fillers = ['эй', 'хей', 'привет', 'слушай', 'окей', 'ok', 'hey', 'hi'];
    for (final filler in fillers) {
      if (command.startsWith(filler)) {
        command = command.substring(filler.length).trim();
      }
    }

    print("📝 [SPEECH] Command after wake word: '$command'");
    
    // If command is too short, might be recognition error
    if (command.length < 3) {
      print("⚠️ [SPEECH] Command too short, might be error");
      return null;
    }

    return command;
  }

  /// Stop listening
  Future<void> stop() async {
    if (_isListening) {
      print("🛑 [SPEECH] Stopping speech recognition...");
      await _speech.stop();
      _isListening = false;
      print("✅ [SPEECH] Stopped");
    }
  }

  /// Cancel listening
  Future<void> cancel() async {
    if (_isListening) {
      print("❌ [SPEECH] Cancelling speech recognition...");
      await _speech.cancel();
      _isListening = false;
      print("✅ [SPEECH] Cancelled");
    }
  }

  /// Dispose
  void dispose() {
    print("🗑️ [SPEECH] Disposing speech service...");
    _speech.cancel();
    _isListening = false;
    _isInitialized = false;
  }

  /// Check if currently listening
  bool get isListening => _isListening;
  
  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Get available locales
  Future<List<stt.LocaleName>> getLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _speech.locales();
  }
}

/// Speech Recognition Result
class SpeechResult {
  final String text;
  final String? command;
  final bool hasWakeWord;
  final double confidence;

  SpeechResult({
    required this.text,
    this.command,
    required this.hasWakeWord,
    this.confidence = 1.0,
  });

  @override
  String toString() {
    return 'SpeechResult(text: $text, command: $command, hasWakeWord: $hasWakeWord)';
  }
}
