import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'porcupine_wake_word_service.dart';

class WakeWordService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final PorcupineWakeWordService _porcupine = PorcupineWakeWordService();
  
  bool _isListening = false;
  bool _usePorcupine = false;
  Function(String command)? onWakeWordDetected;
  
  // Wake words in different languages (for speech recognition fallback)
  final List<String> _wakeWords = [
    'эй вижион', 'эй вижен', 'хей вижион', 'hey vision', 'эй vision',
    'эй вижу', 'хей вижу', 'привет вижион', 'вижион', 'vision',
    'слушай вижион', 'ok vision', 'джарвис', 'jarvis', 'компьютер', 'computer'
  ];

  bool _isRestarting = false;

  Future<bool> initialize() async {
    print('🎤 Initializing Wake Word Service...');
    
    // Try to initialize Porcupine first
    _porcupine.onWakeWordDetected = (command) {
      print('🚀 Porcupine detected wake word!');
      onWakeWordDetected?.call(command);
    };
    
    _usePorcupine = await _porcupine.initialize();
    
    if (_usePorcupine) {
      print('✅ Using Porcupine for wake word detection');
      return true;
    } else {
      print('⚠️ Porcupine not available, using Speech Recognition fallback');
      // Initialize speech recognition as fallback
      return await _speech.initialize(
        onError: (error) {
          print('Speech error: $error');
          _restartListening();
        },
        onStatus: (status) {
          print('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _restartListening();
          }
        },
        debugLogging: false, 
      );
    }
  }

  void _restartListening() {
    if (!_isListening || _isRestarting || _usePorcupine) return;
    
    _isRestarting = true;
    Future.delayed(const Duration(milliseconds: 2000), () {
      _isRestarting = false;
      _listenContinuously();
    });
  }

  Future<void> startListening() async {
    if (_isListening) return;
    
    _isListening = true;
    
    if (_usePorcupine) {
      // Use Porcupine
      await _porcupine.startListening();
    } else {
      // Use speech recognition fallback
      bool available = await _speech.initialize(); 
      if (available) {
        _listenContinuously();
      } else {
        print('Speech recognition turned off or not available');
      }
    }
  }

  void _listenContinuously() async {
    if (!_isListening || _usePorcupine) return;

    // Force Russian locale if available
    var locales = await _speech.locales();
    var selectedLocale = locales.firstWhere(
      (element) => element.localeId.startsWith('ru'), 
      orElse: () => locales.first
    );

    print('Listening with locale: ${selectedLocale.localeId} (Mode: Search)');

    _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.toLowerCase();
        
        // BROAD MATCHING (Широкий поиск)
        final hasVision = text.contains('виж') || text.contains('vision') || text.contains('веж');
        final hasHey = text.contains('эй') || text.contains('хей') || text.contains('привет') || text.contains('hey') || text.contains('hi');
        final hasJarvis = text.contains('джарвис') || text.contains('jarvis');
        final hasComputer = text.contains('компьютер') || text.contains('computer');
        
        // Trigger logic
        bool detected = false;
        
        if ((hasVision && hasHey) || hasJarvis || hasComputer) {
          detected = true;
        } else {
           for (final w in _wakeWords) {
            if (text.contains(w)) {
              detected = true;
              break;
            }
          }
        }

        if (detected) {
          print('🚀 WAKE WORD DETECTED in: "$text"');
          
          String command = text.replaceAll(RegExp(r'(эй|хей|привет|hey|hi|vision|вижион|вижен|вижу|виж|джарвис|jarvis|компьютер|computer)'), '').trim();
          if (command.isEmpty || command.length < 3) {
             command = "что передо мной?";
          }
          
          if (_isListening) {
             onWakeWordDetected?.call(command);
             stopListening(); // Stop clean
          }
        }
      },
      localeId: selectedLocale.localeId, 
      listenFor: const Duration(seconds: 60), // Try max duration
      pauseFor: const Duration(seconds: 30),
      partialResults: true,
      listenMode: stt.ListenMode.search, // Better for commands
      cancelOnError: false,
    );
  }

  void stopListening() {
    _isListening = false;
    
    if (_usePorcupine) {
      _porcupine.stopListening();
    } else {
      _speech.stop();
    }
  }

  void dispose() {
    stopListening();
    _porcupine.dispose();
    _speech.cancel();
  }

  bool get isListening => _isListening;
  String get mode => _usePorcupine ? 'Porcupine' : 'Speech Recognition';
}
