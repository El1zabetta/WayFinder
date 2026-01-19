import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Welcome Voice Service for first-time users
/// Explains the app functionality to visually impaired users
class WelcomeVoiceService {
  static const String _firstLaunchKey = 'app_first_launch_done';
  
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  /// The comprehensive welcome message for first-time users
  static const String welcomeMessage = '''
Welcome to WayFinder, your AI-powered visual assistant designed specifically for people with visual impairments.

This app helps you understand your surroundings, navigate safely, and interact with the world using voice commands.

Here are the main features:

First, Voice Activation. Simply say "WayFinder" at any time to activate voice control. The app is always listening for this wake word.

Second, Scene Description. Point your phone camera at anything and ask "What do I see?" or "Describe my surroundings". The AI will tell you what's in front of you.

Third, Object Search. Say "Find the door" or "Where is the exit?" to locate specific objects. The app will guide you to them.

Fourth, Navigation. Say "Navigate to" followed by an address to get turn-by-turn voice directions.

Fifth, Text Reading. Point the camera at any text and say "Read this" to have it read aloud.

Voice Commands you can use:
"What do I see?" - Describe the scene
"Find something" - Search for objects
"Navigate to address" - Start navigation
"Stop" - Cancel current action
"Help" - Hear these instructions again

The app uses your camera and microphone to assist you. All processing is done securely.

You can adjust settings by swiping left to the Settings tab.

WayFinder is ready to help you. Just say "WayFinder" to begin!
''';

  /// Initialize the TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.55); // Faster speech
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    _isInitialized = true;
  }

  /// Check if this is the first launch and speak welcome message
  Future<bool> checkAndPlayWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunchDone = prefs.getBool(_firstLaunchKey) ?? false;
    
    if (!firstLaunchDone) {
      await initialize();
      await speakWelcome();
      await prefs.setBool(_firstLaunchKey, true);
      return true;
    }
    return false;
  }

  /// Speak the full welcome message
  Future<void> speakWelcome() async {
    await initialize();
    await _tts.speak(welcomeMessage);
  }

  /// Speak custom text
  Future<void> speak(String text) async {
    await initialize();
    await _tts.speak(text);
  }

  /// Stop speaking
  Future<void> stop() async {
    await _tts.stop();
  }

  /// Speak the help message
  Future<void> speakHelp() async {
    await initialize();
    const helpMessage = '''
Команды WayFinder: 
"Что передо мной" - описание сцены.
"Прочитай" - чтение текста.
"Цвет" - определение цвета.
"Деньги" - номинал купюры.
"Светофор" - можно ли идти.
"Дверь" или "Вход" - поиск входа.
"Найди" - поиск объекта.
"Построй маршрут до" - навигация.
"Где я" - местоположение.
"Время" - текущее время.
"Повтори" - повтор инструкции.
"SOS" - экстренная помощь.
"Стоп" - остановить.
''';
    await _tts.speak(helpMessage);
  }

  void dispose() {
    _tts.stop();
  }
}
