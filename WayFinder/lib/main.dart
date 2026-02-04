import 'dart:convert';
import 'dart:async'; // Added for StreamSubscription
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_compass/flutter_compass.dart'; // Added for Compass
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';

import 'theme/app_theme.dart';
import 'services/advanced_ai_service.dart';
import 'services/spatial_audio_service.dart'; // Added for Spatial Audio
import 'services/porcupine_service.dart';
import 'services/navigation_service.dart';
import 'services/chat_history_service.dart';
import 'services/haptic_service.dart';
import 'services/enhanced_speech_service.dart';
import 'services/welcome_voice_service.dart';
import 'services/performance_service.dart';
import 'screens/chat_screen.dart';
import 'screens/vision_mode.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/premium_settings_screen.dart';
import 'widgets/glass_container.dart';
import 'widgets/premium_widgets.dart';
import 'widgets/ai_animations.dart'; // Added for typing indicators

import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides(); // Fix HandshakeException
  await Firebase.initializeApp();
  runApp(const VisionApp());
}

// Bypass SSL certification for dev
 class MyHttpOverrides extends HttpOverrides{
  @override
  HttpClient createHttpClient(SecurityContext? context){
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port)=> true;
  }
}

class VisionApp extends StatefulWidget {
  const VisionApp({super.key});

  @override
  State<VisionApp> createState() => _VisionAppState();
}

class _VisionAppState extends State<VisionApp> {
  Locale? _locale;

  void setLocale(Locale l) {
    setState(() {
      _locale = l;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WayFinder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
        Locale('ky'),
      ],
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => MainNavScreen(onLocaleChange: setLocale),
      },
    );
  }
}

// Authentication Wrapper
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isAuthenticated(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // For now, skip auth and go directly to home
        // Change to: snapshot.data == true ? MainNavScreen(...) : LoginScreen()
        // when you want to enforce authentication
        return MainNavScreen(onLocaleChange: (Locale l) {
          // Access parent state through context if needed
        });
      },
    );
  }
}

class MainNavScreen extends StatefulWidget {
  final Function(Locale) onLocaleChange;
  const MainNavScreen({super.key, required this.onLocaleChange});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> with WidgetsBindingObserver {
  // Services
  final _api = AdvancedVisionApiService();
  late PorcupineWakeWordService _porcupineService;
  late EnhancedSpeechService _speechService;
  final _navigationService = NavigationService();
  final _chatHistory = ChatHistoryService();
  CameraController? _cameraController;
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _wakeWordEnabled = true;
  bool _isNavigating = false;
  String? _destination;
  List<NavigationStep> _routeSteps = [];
  int _currentStepIndex = 0;
  DateTime? _lastSafetyScan;
  bool _isSafetyScanning = false;
  bool _isThinking = false;
  bool _isDanger = false;
  
   // Advanced Features
  final _spatialAudio = SpatialAudioService();
  final _welcomeVoice = WelcomeVoiceService();
  double _currentHeading = 0;
  StreamSubscription? _compassSubscription;
  StreamSubscription? _navigationSubscription;
  
  // Battery Monitor
  final Battery _battery = Battery();
  double _batteryLevel = 1.0;
  Timer? _batteryTimer;


  // State
  int _currentIndex = 0;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isSpeaking = false; // Track TTS playback
  List<ChatMessage> _messages = [];
  String _visionStatus = "";
  List<String>? _detectedObjects;
  String _partialSpeechText = "";
  
  // HUD Animation Controller
  late AnimationController _hudController;
  
  static const int TAB_CHAT = 0;
  static const int TAB_VISION = 1;
  static const int TAB_SETTINGS = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _initHardware();
    _loadChatHistory();

    _playWelcomeIfFirstLaunch();
    _initBattery();
    _initVisionLoop();
    
    _porcupineService = PorcupineWakeWordService(
      onWakeWordDetected: _handlePorcupineWake,
      onError: (err) {
        print("❌ [MAIN] Porcupine Error: $err");
        // Show error to user if mounted
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Wake Word Error: $err"),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    );
    
    // Initialize enhanced speech service
    _speechService = EnhancedSpeechService()
      ..onCommandDetected = (text) {
        setState(() => _partialSpeechText = "");
        _handleSpeechCommand(text);
      }
      ..onError = (err) {
        print("❌ [MAIN] Speech Error: $err");
        setState(() {
          _isRecording = false;
          _partialSpeechText = "";
        });
        // RESTART wake word on error to keep app alive
        if (_wakeWordEnabled && !_isProcessing) {
          _porcupineService.startListening();
        }
      }
      ..onPartialResult = (text) {
        setState(() => _partialSpeechText = text);
        print("📝 [MAIN] Partial: $text");
      };
    
    _initWakeWord();
    _initCompass();
  }

  /// Play welcome voice guide for first-time users (accessibility feature)
  Future<void> _playWelcomeIfFirstLaunch() async {
    // Small delay to let the app fully initialize
    await Future.delayed(const Duration(milliseconds: 500));
    final isFirstLaunch = await _welcomeVoice.checkAndPlayWelcome();
    if (isFirstLaunch && mounted) {
      // Show a subtle indicator that welcome is playing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎧 Playing welcome guide...'),
          backgroundColor: Color(0xFF00D4FF),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      setState(() {
        _currentHeading = event.heading ?? 0;
      });
    });
  }

  void _initBattery() {
    _battery.batteryLevel.then((level) {
      if (mounted) setState(() => _batteryLevel = level / 100);
    });
    
    _batteryTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level / 100);
    });
  }



  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _porcupineService.dispose();
    _speechService.dispose();
    _compassSubscription?.cancel();
    _navigationSubscription?.cancel(); // Clean up navigation stream
    _welcomeVoice.dispose();
    
    // Clean up cache on exit
    PerformanceService().forceCleanup();
    
    super.dispose();
  }

  void _disposeCamera() {
    if (_cameraController != null) {
      print("📸 [MAIN] Disposing camera...");
      _cameraController?.dispose();
      _cameraController = null; // Important: set to null after dispose
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _disposeCamera();
      _porcupineService.stopListening();
    } else if (state == AppLifecycleState.resumed) {
      // Add delay before reinitializing camera to prevent threading conflicts
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          _initCamera();
          // Restart wake word on resume if enabled
          if (_wakeWordEnabled && !_isRecording && !_isProcessing) {
            _porcupineService.startListening();
          }
        }
      });
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      try {
        _cameraController = CameraController(
          cameras.first, 
          ResolutionPreset.medium, // OPTIMIZED: Medium (720p) is much faster for AI uploads than High
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      } catch (e) {
        print('Camera error: $e');
      }
    }
  }

  Future<void> _loadChatHistory() async {
    final history = await _chatHistory.loadHistory();
    if (history.isEmpty) {
      _checkFirstRun();
    } else {
      setState(() {
        _messages = history;
      });
    }
  }

  Future<void> _checkFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isFirstRun = prefs.getBool('is_first_run') ?? true;
    
    if (isFirstRun) {
      await _startVoiceOnboarding();
      await prefs.setBool('is_first_run', false);
    } else {
      _addInitialMessage();
    }
  }

  Future<void> _startVoiceOnboarding() async {
    const welcomeText = """
Hello! I am WayFinder, your AI assistant for the visually impaired.

Here is what I can do for you:
1. Navigation: I can build routes and guide you step by step with voice directions.
2. Vision: My camera constantly watches the path ahead and warns you about obstacles, open manholes, traffic lights, and other hazards.
3. Description: Just ask 'What do I see?' or 'What is in front of me?' and I will describe your surroundings.
4. Smart Search: Say 'Find the door' or 'Where is the exit?' and I will help you locate objects.

You can activate me anytime by saying 'WayFinder' followed by your command.

To change language, say 'Change language to Russian' or 'Switch to English'.

Let's get started!
""";
    
    final aiMsg = ChatMessage(
        text: welcomeText, 
        isUser: false, 
        timestamp: DateTime.now()
    );
    setState(() => _messages.add(aiMsg));
    
    // Play greeting
    await _speak(welcomeText);
    
    // Start listening for language choice
    await Future.delayed(const Duration(seconds: 1));
    if (_wakeWordEnabled) _porcupineService.stopListening();
    
    await _speechService.initialize();
    _speechService.listenForCommand(timeout: const Duration(seconds: 5));
  }

  Future<void> _handleVoiceRegistration() async {
    _speak("Хорошо, давай зарегистрируемся через твой Google аккаунт. Сейчас откроется окно выбора аккаунта. Пожалуйста, подтверди свой выбор.");
    
    try {
      final result = await AuthService().signInWithGoogle();
      if (result['success']) {
        _speak("Отлично! Регистрация прошла успешно. Теперь ты в системе. Все твои настройки и история будут сохраняться.");
        // Reload history or just continue
        setState(() {}); 
      } else {
        _speak("К сожалению, произошла ошибка при входе через Google. Попробуй еще раз или попроси помощи у зрячего человека.");
      }
    } catch (e) {
      _speak("Произошла техническая ошибка. Пожалуйста, попробуй позже.");
    }
  }

  void _addInitialMessage() {
     final msg = ChatMessage(
       text: "Hello! I'm WayFinder, your voice assistant. Say 'WayFinder' and ask a question, or tap the microphone button.", 
       isUser: false, 
       timestamp: DateTime.now()
     );
     setState(() {
       _messages.add(msg);
     });
     _chatHistory.saveHistory(_messages);
  }

  Future<void> _initHardware() async {
    await [Permission.camera, Permission.microphone, Permission.location].request();
    
    // Initialize performance monitoring
    await PerformanceService().initialize();
    
    await _initCamera();
    
    // Start the Premium Startup Sequence
    _startupSequence();
  }

  Future<void> _startupSequence() async {
    print("🚀 [MAIN] Starting WayFinder System Sequence...");
    
    setState(() {
      _visionStatus = "INITIALIZING SYSTEMS...";
      _isProcessing = true;
    });

    // 1. BIOS / Core Check
    await HapticService.lightImpact();
    await Future.delayed(const Duration(milliseconds: 400));
    
    // 2. Sensor Sync
    setState(() => _visionStatus = "SENSORS SYNCING...");
    await HapticService.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 3. AI Brain Connection
    setState(() => _visionStatus = "AI BRAIN ONLINE");
    await HapticService.success();
    
    // 4. Final Voice Welcome (Subtle)
    _welcomeVoice.speak("Системы активны. Я готов помочь.");
    
    setState(() {
      _visionStatus = "SYSTEMS NOMINAL";
      _isProcessing = false;
    });
    
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _visionStatus = "");
  }

  Future<void> _initWakeWord() async {
    print("🔧 [MAIN] Initializing wake word service...");
    print("🔧 [MAIN] Wake word enabled: $_wakeWordEnabled");
    
    await _porcupineService.initialize();
    
    print("🔧 [MAIN] Porcupine initialized: ${_porcupineService.isInitialized}");
    
    if (_wakeWordEnabled) {
      print("🔧 [MAIN] Starting wake word listener...");
      await _porcupineService.startListening();
      print("🔧 [MAIN] Wake word listener started: ${_porcupineService.isListening}");
    } else {
      print("⚠️ [MAIN] Wake word is disabled, not starting listener");
    }
  }

  void _handlePorcupineWake() async {
    print("⚡⚡⚡ [MAIN] WAKE WORD 'WAYFINDER' DETECTED! ⚡⚡⚡");
    print("⚡ [MAIN] Current state - isRecording: $_isRecording, isProcessing: $_isProcessing");
    
    if (!_isRecording && !_isProcessing) {
      print("✅ [MAIN] State is valid, proceeding with wake word handling...");
      
      // 1. Stop Wake Word Listener
      print("🛑 [MAIN] Stopping wake word listener...");
      await _porcupineService.stopListening();
      print("✅ [MAIN] Wake word listener stopped");
      
      // 2. HAPTIC FEEDBACK - Premium vibration pattern
      print("📳 [MAIN] Triggering haptic feedback...");
      await HapticService.wakeWordDetected();
      print("✅ [MAIN] Haptic feedback completed");

      // 3. Visual Feedback
      print("🎨 [MAIN] Setting processing state for visual feedback...");
      setState(() { _isProcessing = true; });

      // 4. Start SPEECH RECOGNITION to get command
      print("🎤 [MAIN] Starting speech recognition for command...");
      
      try {
        // Initialize if needed
        if (!_speechService.isInitialized) {
          print("🔧 [MAIN] Initializing speech service...");
          await _speechService.initialize();
        }

        // Wait a moment for microphone to be released by Porcupine
        await Future.delayed(const Duration(milliseconds: 300));

        print("👂 [MAIN] Listening for user command...");
        setState(() { 
          _isRecording = true; 
          _isProcessing = false; 
          _partialSpeechText = "Слушаю...";
        });
        
        await _speechService.listenForCommand(
          timeout: const Duration(seconds: 10),
          extractCommand: false, // Use full text for better accuracy
        );
        
      } catch (e) {
        print("❌ [MAIN] Speech recognition error: $e");
        setState(() { _isRecording = false; _isProcessing = false; });
        
        // Restart wake word
        if (_wakeWordEnabled) {
          _porcupineService.startListening();
        }
      }
    } else {
      print("⚠️ [MAIN] Wake word ignored - state: Rec=$_isRecording, Proc=$_isProcessing");
    }
  }

  // Handle detected speech command
  void _handleSpeechCommand(String command) async {
    print("🎯 [MAIN] Speech command received: '$command'");
    
    setState(() { _isRecording = false; _isProcessing = true; });
    
    // Stop speech recognition
    await _speechService.stop();
    
    // Process the command
    await _processTextCommand(command);
    
    // Restart wake word listener
    if (_wakeWordEnabled && !_isRecording) {
      print("🔄 [MAIN] Restarting wake word listener...");
      await Future.delayed(const Duration(milliseconds: 500));
      _porcupineService.startListening();
    }
  }

  // Process text command
  Future<void> _processTextCommand(String text) async {
    print("💬 [MAIN] Processing text command: '$text'");
    
    final lowerText = text.toLowerCase();
    
    // 1. Check for Mode Switch Commands
    if (_processModeCommands(lowerText)) return;
    
    // 2. Check for STOP command - stops TTS playback
    if (lowerText.contains('stop') || lowerText.contains('стоп') || lowerText.contains('хватит') || lowerText.contains('замолчи')) {
      await _stopSpeaking();
      HapticService.mediumImpact();
      return;
    }
    
    // 3. Check for Help Command - plays voice guide
    if (lowerText.contains('help') || lowerText.contains('помощь') || lowerText.contains('что ты умеешь')) {
      _welcomeVoice.speakHelp();
      HapticService.mediumImpact();
      return;
    }

    // 4. QUICK COMMAND: "Что передо мной" - instant scene analysis
    if (lowerText.contains('что передо мной') || 
        lowerText.contains('что я вижу') || 
        lowerText.contains('опиши') ||
        lowerText.contains("what's in front") ||
        lowerText.contains('what do i see') ||
        lowerText.contains('describe')) {
      HapticService.mediumImpact();
      _speak("Анализирую...", useLocalOnly: true);
      await _processRequest(text: "Опиши что ты видишь кратко и чётко", mode: 'vision');
      return;
    }

    // 5. QUICK COMMAND: Battery status
    if (lowerText.contains('батарея') || lowerText.contains('заряд') || lowerText.contains('battery')) {
      final level = PerformanceService().batteryLevel;
      _speak("Уровень заряда батареи: $level процентов.", useLocalOnly: true);
      HapticService.lightImpact();
      return;
    }

    // 6. QUICK COMMAND: Read text in front of camera
    if (lowerText.contains('прочитай') || lowerText.contains('read') || lowerText.contains('текст')) {
      HapticService.mediumImpact();
      _speak("Читаю текст...", useLocalOnly: true);
      await _processRequest(text: "Прочитай весь текст на изображении вслух", mode: 'read');
      return;
    }

    // 7. QUICK COMMAND: Current time
    if (lowerText.contains('время') || lowerText.contains('который час') || lowerText.contains('time') || lowerText.contains('what time')) {
      final now = DateTime.now();
      final hour = now.hour;
      final minute = now.minute.toString().padLeft(2, '0');
      _speak("Сейчас $hour часов $minute минут.", useLocalOnly: true);
      HapticService.lightImpact();
      return;
    }

    // 8. QUICK COMMAND: "Где я" - current location
    if (lowerText.contains('где я') || lowerText.contains('мое местоположение') || lowerText.contains('where am i') || lowerText.contains('my location')) {
      HapticService.mediumImpact();
      _speak("Определяю местоположение...", useLocalOnly: true);
      try {
        final pos = await _navigationService.getCurrentLocation();
        if (pos != null) {
          final city = _navigationService.cityContext;
          if (city.isNotEmpty) {
            _speak("Вы находитесь в $city. Координаты: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}.", useLocalOnly: true);
          } else {
            _speak("Координаты: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}.", useLocalOnly: true);
          }
        } else {
          _speak("Не удалось определить местоположение. Проверьте GPS.", useLocalOnly: true);
        }
      } catch (e) {
        _speak("Ошибка определения местоположения.", useLocalOnly: true);
      }
      return;
    }

    // 9. QUICK COMMAND: "Повтори" - repeat last navigation instruction
    if (lowerText.contains('повтори') || lowerText.contains('repeat') || lowerText.contains('еще раз') || lowerText.contains('again')) {
      if (_isNavigating && _routeSteps.isNotEmpty) {
        final instruction = _navigationService.getCurrentInstruction();
        _speak(instruction, useLocalOnly: true);
        HapticService.lightImpact();
      } else {
        _speak("Нет активной навигации для повтора.", useLocalOnly: true);
      }
      return;
    }

    // 10. EMERGENCY: "SOS" / "Помогите"
    if (lowerText.contains('sos') || lowerText.contains('помогите') || lowerText.contains('emergency') || lowerText.contains('экстренно')) {
      HapticService.emergencyWarning();
      _speak("Режим экстренной помощи. Сейчас опишу ваше окружение максимально подробно.", useLocalOnly: true);
      await _processRequest(text: "СРОЧНО: Опиши всё вокруг максимально подробно. Укажи людей, выходы, опасности, ориентиры. Это экстренная ситуация для слепого человека.", mode: 'vision');
      return;
    }

    // 11. QUICK COMMAND: "Какой цвет" - color identification
    if (lowerText.contains('цвет') || lowerText.contains('какого цвета') || lowerText.contains('color') || lowerText.contains('what color')) {
      HapticService.mediumImpact();
      _speak("Определяю цвет...", useLocalOnly: true);
      await _processRequest(text: "Назови основной цвет того что ты видишь. Ответь одним-двумя словами, например: красный, тёмно-синий, бежевый.", mode: 'vision');
      return;
    }

    // 12. QUICK COMMAND: "Деньги" - currency recognition
    if (lowerText.contains('деньги') || lowerText.contains('купюра') || lowerText.contains('money') || lowerText.contains('банкнот')) {
      HapticService.mediumImpact();
      _speak("Определяю номинал...", useLocalOnly: true);
      await _processRequest(text: "Определи номинал и валюту купюры или монеты на изображении. Ответь кратко, например: 1000 сом, 500 рублей, 20 долларов.", mode: 'vision');
      return;
    }

    // 13. QUICK COMMAND: "Светофор" - traffic light status
    if (lowerText.contains('светофор') || lowerText.contains('traffic light') || lowerText.contains('можно идти') || lowerText.contains('перейти')) {
      HapticService.mediumImpact();
      _speak("Проверяю светофор...", useLocalOnly: true);
      await _processRequest(text: "Посмотри на светофор. Какой сейчас сигнал для пешеходов? Можно ли безопасно переходить дорогу? Ответь кратко и чётко.", mode: 'vision');
      return;
    }

    // 14. QUICK COMMAND: "Дверь" - find door/entrance
    if (lowerText.contains('дверь') || lowerText.contains('вход') || lowerText.contains('door') || lowerText.contains('entrance') || lowerText.contains('выход')) {
      HapticService.mediumImpact();
      _speak("Ищу вход...", useLocalOnly: true);
      await _processRequest(text: "Найди дверь, вход или выход на изображении. Опиши где она находится относительно центра кадра (слева, справа, прямо) и на каком расстоянии примерно.", mode: 'vision');
      return;
    }

    // 15. Check for Language Change Commands (voice activated)
    if (_processLanguageCommands(lowerText)) return;

    // 3. Check for Registration/Login Commands
    if (lowerText.contains('регистрация') || 
        lowerText.contains('зарегистрируй') || 
        lowerText.contains('войти') || 
        lowerText.contains('google') ||
        lowerText.contains('register') ||
        lowerText.contains('sign in')) {
      await _handleVoiceRegistration();
      return;
    }

    // 4. FAST-TRACK: Direct navigation commands (bypass chat)
    if (_isNavigationRequest(lowerText)) {
      await _extractAndBuildRoute(text);
      return;
    }

    // 5. Check for Object Search
    if (lowerText.contains('найди') || lowerText.contains('где') || lowerText.contains('find')) {
       final query = lowerText.replaceAll('найди', '').replaceAll('где', '').replaceAll('find', '').trim();
       _speak("Ищу $query. Пожалуйста, медленно поводите камерой вокруг.");
       await _processRequest(text: query, mode: 'search');
       return;
    }

    final userMsg = ChatMessage(text: text, isUser: true, timestamp: DateTime.now());
    setState(() {
      _messages.add(userMsg);
    });
    await _chatHistory.saveHistory(_messages);
    
    // Check if navigation request
    if (_isNavigationRequest(text)) {
      await _handleNavigationRequest(text: text);
    } else {
      await _processRequest(text: text, mode: 'chat');
    }
  }

  bool _processModeCommands(String text) {
    if (text.contains('режим навигатора') || text.contains('navigator mode')) {
      setState(() => _currentIndex = TAB_VISION);
      _speak("Switching to navigator mode. Camera active.");
      return true;
    } else if (text.contains('стандартный режим') || text.contains('чат') || text.contains('standard mode') || text.contains('chat mode')) {
      setState(() => _currentIndex = TAB_CHAT);
      _speak("Switched to standard chat mode.");
      return true;
    }
    return false;
  }

  // Voice-activated language switching
  bool _processLanguageCommands(String text) {
    // English commands to switch to Russian
    if (text.contains('change language to russian') || 
        text.contains('switch to russian') ||
        text.contains('russian language') ||
        text.contains('set language russian')) {
      widget.onLocaleChange(const Locale('ru'));
      _speak("Язык изменён на русский. Теперь я буду отвечать по-русски.");
      return true;
    }
    
    // English commands to switch to English
    if (text.contains('change language to english') || 
        text.contains('switch to english') ||
        text.contains('english language') ||
        text.contains('set language english')) {
      widget.onLocaleChange(const Locale('en'));
      _speak("Language changed to English. I will now respond in English.");
      return true;
    }
    
    // Russian commands to switch to Russian
    if (text.contains('поменяй язык на русский') || 
        text.contains('переключи на русский') ||
        text.contains('русский язык') ||
        text.contains('говори по русски')) {
      widget.onLocaleChange(const Locale('ru'));
      _speak("Язык изменён на русский.");
      return true;
    }
    
    // Russian commands to switch to English
    if (text.contains('поменяй язык на английский') || 
        text.contains('переключи на английский') ||
        text.contains('английский язык') ||
        text.contains('говори по английски')) {
      widget.onLocaleChange(const Locale('en'));
      _speak("Language changed to English.");
      return true;
    }
    
    return false;
  }

  void _toggleWakeWord() {
    print("🔄 [MAIN] Toggling wake word. Current state: $_wakeWordEnabled");
    setState(() {
      _wakeWordEnabled = !_wakeWordEnabled;
      print("🔄 [MAIN] Wake word now: ${_wakeWordEnabled ? 'ENABLED' : 'DISABLED'}");
      
      if (_wakeWordEnabled) {
        print("▶️ [MAIN] Starting wake word listener...");
        _porcupineService.startListening();
      } else {
        print("⏸️ [MAIN] Stopping wake word listener...");
        _porcupineService.stopListening();
      }
    });
  }

  // --- ACTIONS ---

  Future<void> _handleVoiceButton() async {
    if (_isProcessing) return;

    if (_isRecording) {
      // STOP manually
      await _speechService.stop();
      setState(() { 
        _isRecording = false; 
        _isProcessing = true; 
      });
    } else {
      // START SPEECH RECOGNITION MANUALLY
      try {
        await _porcupineService.stopListening(); // Pause wake word
        await _audioPlayer.stop();

        if (!_speechService.isInitialized) {
          await _speechService.initialize();
        }

        HapticService.recordingStarted();
        setState(() { 
          _isRecording = true; 
          _isProcessing = false; 
        });

        await _speechService.listenForCommand(
          timeout: const Duration(seconds: 10),
          extractCommand: false, // For manual button, take everything
        );
      } catch (e) {
        print("Error starting manual speech recording: $e");
        setState(() { 
          _isRecording = false; 
          _isProcessing = false; 
        });
        if (_wakeWordEnabled) _porcupineService.startListening();
      }
    }
  }

  Future<void> _handleTextSubmit(String text) async {
    final userMsg = ChatMessage(text: text, isUser: true, timestamp: DateTime.now());
    setState(() {
      _messages.add(userMsg);
      _isProcessing = true;
    });
    await _chatHistory.saveHistory(_messages);
    
    if (_isNavigationRequest(text)) {
      await _handleNavigationRequest(text: text);
    } else {
      await _processRequest(text: text, mode: 'chat');
    }
  }

  bool _isNavigationRequest(String text) {
    final navKeywords = [
      // Russian
      'как дойти', 'как доехать', 'маршрут до', 'построй маршрут', 'проложи маршрут',
      'веди меня', 'как пройти', 'отведи меня', 'навигация до', 'дорогу до',
      'как добраться', 'проведи до', 'покажи путь', 'путь до',
      // English
      'navigate to', 'route to', 'how to get to', 'directions to', 'take me to',
      'guide me to', 'walk me to', 'lead me to', 'show me the way to',
    ];
    final lowerText = text.toLowerCase();
    return navKeywords.any((keyword) => lowerText.contains(keyword));
  }

  Future<void> _handleNavigationRequest({String? audioPath, String text = ''}) async {
    try {
      final position = await _navigationService.getCurrentLocation();
      
      // If no text, we can't build a route, so just use visual context
      if (text.isEmpty || text == 'маршрут' || text == 'навигация') {
        await _processRequest(text: text, mode: 'chat');
        return;
      }

      // 1. Get AI intention and destination from text
      final aiResponse = await _api.requestNavigation(
        audioPath: audioPath,
        text: text,
        currentLat: position?.latitude,
        currentLon: position?.longitude,
      );
      
      final message = aiResponse.message;
      final audioB64 = aiResponse.audio;
      
      final aiMsg = ChatMessage(text: message, isUser: false, timestamp: DateTime.now());
      setState(() {
        _messages.add(aiMsg);
        _isProcessing = false;
      });
      await _chatHistory.saveHistory(_messages);

      if (audioB64 != null) {
         await _playAudioResponse(audioB64);
      }

      // 2. Extract destination name and start route building
      _extractAndBuildRoute(text);
      
    } catch (e) {
      final errorMsg = ChatMessage(text: "Ошибка: $e", isUser: false, timestamp: DateTime.now());
      setState(() {
        _messages.add(errorMsg);
        _isProcessing = false;
      });
      await _chatHistory.saveHistory(_messages);
    }
  }

  /// Extract destination from voice command and build navigation route
  Future<void> _extractAndBuildRoute(String text) async {
    // Comprehensive pattern removal for destination extraction
    final patternsToRemove = [
      // Russian patterns
      'построй маршрут до', 'проложи маршрут до', 'маршрут до', 'веди меня до',
      'как пройти до', 'как дойти до', 'как доехать до', 'отведи меня до',
      'навигация до', 'проведи до', 'покажи путь до', 'путь до', 'дорогу до',
      'как добраться до', 'веди меня к', 'отведи к', 'проведи к', 'веди к',
      'построй маршрут к', 'маршрут к', 'дорогу к', 'путь к',
      'построй маршрут', 'проложи маршрут', 'веди меня', 'отведи меня',
      // English patterns  
      'navigate to', 'route to', 'directions to', 'take me to', 'guide me to',
      'walk me to', 'lead me to', 'how to get to', 'show me the way to',
      'get directions to', 'find route to',
    ];
    
    String cleanDest = text.toLowerCase();
    for (final pattern in patternsToRemove) {
      cleanDest = cleanDest.replaceAll(pattern, '');
    }
    cleanDest = cleanDest.trim();
    
    if (cleanDest.isEmpty) {
      _speak("Пожалуйста, укажите место назначения. Например: построй маршрут до филармонии.");
      return;
    }

    // City context is now handled dynamically in NavigationService
    // based on user's actual GPS location
    final searchQuery = cleanDest;

    try {
      setState(() => _isProcessing = true);
      _speak("Строю маршрут до $cleanDest. Подождите.");
      
      final steps = await _navigationService.buildRoute(searchQuery);
      
      if (steps.isEmpty) {
        _speak("Не удалось найти маршрут до $cleanDest. Попробуйте уточнить адрес.");
        setState(() => _isProcessing = false);
        return;
      }
      
      setState(() {
        _isNavigating = true;
        _destination = cleanDest;
        _routeSteps = steps;
        _currentStepIndex = 0;
        _isProcessing = false;
      });

      // Calculate total distance and time
      final totalDistance = steps.fold<double>(0, (sum, step) => sum + step.distance);
      final totalTime = steps.fold<double>(0, (sum, step) => sum + step.duration);
      final distanceStr = totalDistance > 1000 
          ? "${(totalDistance / 1000).toStringAsFixed(1)} километра"
          : "${totalDistance.toInt()} метров";
      final timeStr = "${(totalTime / 60).ceil()} минут";

      final firstInstruct = _navigationService.getCurrentInstruction();
      _speak("Маршрут до $cleanDest построен. Расстояние $distanceStr, примерно $timeStr. $firstInstruct");
      
      // Switch to Vision mode for camera-assisted navigation
      setState(() => _currentIndex = TAB_VISION);
      
      _startNavigationLoop();
    } catch (e) {
      print("❌ Route building error: $e");
      _speak("Не удалось построить маршрут до $cleanDest. Проверьте подключение к интернету или уточните адрес.");
      setState(() => _isProcessing = false);
    }
  }

  void _startNavigationLoop() {
    // 1. Subscribe to real-time location stream for smooth navigation
    _navigationSubscription?.cancel();
    _navigationSubscription = _navigationService.getLocationStream().listen((position) {
      if (!_isNavigating) return;
      _checkNavigationProgress(position: position);
    });

    // 2. Run safety scan loop separately (check obstacles every 5 seconds)
    Future.doWhile(() async {
      if (!_isNavigating || !mounted) return false;
      
      final now = DateTime.now();
      if (_lastSafetyScan == null || now.difference(_lastSafetyScan!).inSeconds >= 5) {
        await _performSafetyScan();
        _lastSafetyScan = DateTime.now();
      }

      await Future.delayed(const Duration(seconds: 1)); // Check often but scan rarely
      return _isNavigating;
    });
  }

  /// Check if user has reached the next navigation step
  Future<void> _checkNavigationProgress({Position? position}) async {
    if (!_isNavigating || _routeSteps.isEmpty) return;
    
    try {
      // Pass position to service to avoid double GPS fetch
      final advanced = await _navigationService.checkStepProgress(position: position);
      
      if (advanced) {
        // User reached next step - announce new instruction
        setState(() => _currentStepIndex = _navigationService.currentStepIndex);
        
        if (_currentStepIndex >= _routeSteps.length - 1) {
          // Arrived at destination - CELEBRATION!
          _speak("Поздравляю! Вы прибыли к месту назначения: $_destination!");
          HapticService.destinationReached(); // Premium celebration haptic
          _stopNavigation();
        } else {
          // Announce next instruction with SMART directional haptic
          final instruction = _navigationService.getCurrentInstruction();
          final stepType = _routeSteps[_currentStepIndex].type.toLowerCase();
          
          // Choose haptic based on turn direction
          if (stepType.contains('left') || stepType.contains('лев')) {
            HapticService.leftTurn();
          } else if (stepType.contains('right') || stepType.contains('прав')) {
            HapticService.rightTurn();
          } else {
            HapticService.goStraight();
          }
          
          _speak(instruction);
        }
      }
    } catch (e) {
      print("⚠️ Navigation progress check failed: $e");
    }
  }

  Future<void> _performSafetyScan() async {
    if (_isSafetyScanning || _cameraController == null || !_cameraController!.value.isInitialized) return;
    
    setState(() => _isSafetyScanning = true);
    
    try {
      final image = await _cameraController!.takePicture();
      final response = await _api.smartAnalyze(
        image: image,
        mode: 'guide',
        text: 'Identify obstacles and give short safety instruction',
        useCache: false,
      );

      final msg = response.message;
      if (msg.isNotEmpty && msg != '[CLEAR]') {
        // PARSE TAGS FOR HAPTICS & SOUND
        if (msg.contains('[DANGER]')) {
          HapticService.emergencyWarning();
        } else if (msg.contains('[STOP]')) {
          HapticService.heavyImpact();
        } else if (msg.contains('[GO]')) {
          HapticService.success();
        } else {
          HapticService.obstacleAlert();
        }

        final cleanMsg = msg
            .replaceAll('[DANGER]', '')
            .replaceAll('[STOP]', '')
            .replaceAll('[GO]', '')
            .trim();
        
        _speak(cleanMsg, isPriority: true);
      }
    } catch (e) {
      print("⚠️ [SAFETY SCAN] Speed scan failed: $e");
    } finally {
      if (mounted) setState(() => _isSafetyScanning = false);
    }
  }

  Future<void> _speak(String text, {bool isPriority = false, bool useLocalOnly = false}) async {
    if (text.isEmpty) return;
    
    if (isPriority) {
      await _stopSpeaking();
      HapticService.mediumImpact();
    }
    
    setState(() => _isSpeaking = true);
    
    // NAVIGATION OPTIMIZATION:
    // If navigating or explicit local flag, use Local TTS immediately for zero latency.
    // Waiting for server audio while walking is dangerous and slow.
    if (useLocalOnly || (_isNavigating && text.length < 100)) {
       await _welcomeVoice.speak(text);
       if (mounted) setState(() => _isSpeaking = false);
       return;
    }
    
    // Calculate Balance for Spatial Audio if navigating
    double balance = 0;
    if (_isNavigating) {
      final targetBearing = _navigationService.getBearingToNextStep(
        _navigationService.currentPosition?.latitude ?? 0, 
        _navigationService.currentPosition?.longitude ?? 0
      );
      balance = _spatialAudio.calculateBalance(_currentHeading, targetBearing);
    }

    try {
      // Try high-quality backend TTS first (only for long chat responses)
      final aiResponse = await _api.smartAnalyze(text: text, mode: 'chat');
      if (aiResponse.audio != null) {
        final bytes = base64Decode(aiResponse.audio!);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await file.writeAsBytes(bytes);
        
        await _audioPlayer.setBalance(balance);
        await _audioPlayer.play(DeviceFileSource(file.path));
        // Wait for completion
        await _audioPlayer.onPlayerComplete.first;
        if (mounted) setState(() => _isSpeaking = false);
        return;
      }
    } catch (e) {
      print("⚠️ [TTS] Backend TTS failed, using local fallback: $e");
    }
    
    // FALLBACK: Use local TTS
    await _welcomeVoice.speak(text);
    if (mounted) setState(() => _isSpeaking = false);
  }
  
  /// Stop all audio playback
  Future<void> _stopSpeaking() async {
    await _audioPlayer.stop();
    await _welcomeVoice.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  void _stopNavigation() {
    _navigationSubscription?.cancel();
    _navigationSubscription = null;
    
    setState(() {
      _isNavigating = false;
      _destination = null;
      _routeSteps = [];
      _currentStepIndex = 0;
    });
    HapticService.mediumImpact();
    _speak("Навигация остановлена.");
  }

  Future<void> _processRequest({String? audioPath, String text = '', required String mode}) async {
    setState(() {
      _isProcessing = true;
      _isThinking = true;
    });

    try {
      XFile? imageFile;
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        try {
          imageFile = await _cameraController!.takePicture();
          print("📸 [MAIN] Picture taken for analysis: ${imageFile.path}");
        } catch (e) {
          print("❌ [MAIN] Error taking picture: $e");
        }
      }

      final aiResponse = await _api.smartAnalyze(
        image: imageFile, 
        audioPath: audioPath, 
        mode: mode, 
        text: text
      );
      
      final msg = aiResponse.message;
      final audioB64 = aiResponse.audio;

      if (!mounted) return;

      // HAPTIC FEEDBACK: Pulsing based on detected objects
      if (aiResponse.detectedObjects != null && aiResponse.detectedObjects!.isNotEmpty) {
        HapticService.mediumImpact();
      }

      final aiMsg = ChatMessage(text: msg, isUser: false, timestamp: DateTime.now());
      setState(() {
        if (mode == 'chat') {
           _messages.add(aiMsg);
        } else {
           _visionStatus = msg;
           _detectedObjects = aiResponse.detectedObjects;
           
           // Danger check
           final dangerWords = ['caution', 'danger', 'obstacle', 'warning', 'машина', 'яма', 'препятствие'];
           _isDanger = dangerWords.any((w) => msg.toLowerCase().contains(w.toLowerCase()));
        }
        _isThinking = false;
        _isProcessing = false;
      });
      
      if (mode == 'chat') {
        await _chatHistory.saveHistory(_messages);
      }

      if (audioB64 != null) {
        await _playAudioResponse(audioB64);
      }

    } catch (e) {
      if (mounted) {
        final errorMsg = ChatMessage(text: "Ошибка: $e", isUser: false, timestamp: DateTime.now());
        setState(() {
          _messages.add(errorMsg);
          _isThinking = false;
          _isProcessing = false;
        });
        await _chatHistory.saveHistory(_messages);
      }
    } finally {
      if (mounted) {
          setState(() { 
            _isProcessing = false; 
            _isThinking = false;
          });
          if (_wakeWordEnabled && !_isRecording) {
            _porcupineService.startListening();
          }
      }
    }
  }
  
  Future<void> _playAudioResponse(String audioB64) async {
     try {
       final bytes = base64Decode(audioB64);
       final dir = await getTemporaryDirectory();
       final file = File('${dir.path}/response.mp3');
       await file.writeAsBytes(bytes);
       await _audioPlayer.play(DeviceFileSource(file.path));
     } catch (e) {
       print("Audio play error: $e");
     }
  }

  // --- UI BUILDING ---
  
  @override
  Widget build(BuildContext context) {
    if (_cameraController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBody: true, // For transparency behind navbar
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              // TAB 0: CHAT
              SafeArea(
                child: ChatScreen(
                  messages: _messages,
                  isProcessing: _isProcessing,
                  onSendMessage: _handleTextSubmit,
                ),
              ),

              // TAB 1: VISION
              VisionModeScreen(
                cameraController: _cameraController,
                statusText: _visionStatus,
                isProcessing: _isProcessing,
                isThinking: _isThinking,
                isDanger: _isDanger,
                onScanTap: () => {}, 
                // Premium HUD Info
                distance: _getFormattedDistance(),
                direction: _getFormattedDirection(),
                batteryLevel: _batteryLevel,
                detectedObjects: _detectedObjects,
              ),

              // TAB 2: SETTINGS
              PremiumSettingsScreen(
                onLocaleChange: widget.onLocaleChange,
                wakeWordEnabled: _wakeWordEnabled,
                onToggleWakeWord: _toggleWakeWord,
                onClearHistory: _clearChatHistory,
                messageCount: _messages.length,
              ),
            ],
          ),
          
          // PREMIUM VIRTUAL GUIDE HUD
          if (_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    children: [
                      _buildRadarIcon(),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "АКТИВНЫЙ ПОВОДЫРЬ",
                                  style: TextStyle(
                                    color: Colors.blueAccent.shade100,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _destination ?? "Поиск пути...",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: _stopNavigation,
                      ),
                    ],
                  ),
                ),
            ),

          // REAL-TIME SCANNING INDICATOR
          if (_isNavigating && _isSafetyScanning)
            Positioned(
              bottom: 120,
              left: 40,
              right: 40,
              child: AnimatedOpacity(
                opacity: _isSafetyScanning ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "ИИ АНАЛИЗИРУЕТ ПУТЬ",
                        style: TextStyle(
                          color: Colors.blueAccent.shade100,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),


          
          // Speech Recognition Hub (Overlay)
          if (_isRecording && _partialSpeechText.isNotEmpty)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    children: [
                      const PulseAnimation(
                        child: Icon(Icons.mic, color: Color(0xFF00D4FF), size: 24),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Слушаю команда...",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _partialSpeechText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ),
          
          // Animated Wake Word Indicator
          if (_wakeWordEnabled && _currentIndex != TAB_SETTINGS)
            Positioned(
              top: 50,
              right: 20,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  final pulseValue = (value * 2 * 3.14159);
                  final scale = 1.0 + (0.1 * (1 + sin(pulseValue)));
                  // Corrected opacity calculation to ensure it stays in [0.0, 1.0]
                  final opacity = (0.7 + (0.15 * (1 + sin(pulseValue)))).clamp(0.0, 1.0);
                  
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: child,
                    ),
                  );
                },
                onEnd: () {
                  // Repeat animation
                  if (mounted && _wakeWordEnabled) {
                    setState(() {});
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00E676).withOpacity(0.3),
                        const Color(0xFF00E676).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E676), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withOpacity(0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00E676),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LISTENING',
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // STOP SPEAKING BUTTON - appears when TTS is playing
          if (_isSpeaking)
            Positioned(
              top: 50,
              left: 20,
              child: GestureDetector(
                onTap: () {
                  HapticService.mediumImpact();
                  _stopSpeaking();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stop, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'STOP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      
      // Floating Recording Button (only on Chat & Vision) - PREMIUM VERSION
      floatingActionButton: _currentIndex != TAB_SETTINGS 
        ? PulsingMicAnimation(
            isActive: _isRecording,
            onTap: () {
              HapticService.mediumImpact();
              _handleVoiceButton();
            },
          )
        : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF121426),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.chat_bubble_outline, color: _currentIndex == 0 ? const Color(0xFF00D4FF) : Colors.white38),
              onPressed: () {
                HapticService.lightImpact();
                setState(() => _currentIndex = 0);
              },
              tooltip: l10n.chatMode,
            ),
            const SizedBox(width: 20), // Spacer for FAB
            IconButton(
              icon: Icon(Icons.remove_red_eye_outlined, color: _currentIndex == 1 ? const Color(0xFF00D4FF) : Colors.white38),
              onPressed: () {
                HapticService.lightImpact();
                setState(() {
                  _currentIndex = 1;
                  // Start subtle ambient scan sound if needed
                });
              },
              tooltip: l10n.navigatorMode,
            ),
             IconButton(
              icon: Icon(Icons.settings_outlined, color: _currentIndex == 2 ? const Color(0xFF00D4FF) : Colors.white38),
              onPressed: () {
                HapticService.lightImpact();
                setState(() => _currentIndex = 2);
              },
              tooltip: l10n.settings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarIcon() {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PulseAnimation(
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Icon(Icons.navigation_rounded, color: Colors.white, size: 24),
        ],
      ),
    );
  }

  Future<void> _clearChatHistory() async {
    await _chatHistory.clearHistory();
    setState(() {
      _messages.clear();
    });
    _addInitialMessage();
    HapticService.heavyImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("История чата очищена")),
      );
    }
  }

  Timer? _visionLoopTimer;

  void _initVisionLoop() {
    _visionLoopTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentIndex == TAB_VISION && 
          !_isProcessing && 
          !_isRecording && 
          !_isSpeaking &&
          _cameraController != null && 
          _cameraController!.value.isInitialized) {
        
        print("🔍 [VISION LOOP] Automatic environment scan...");
        _processRequest(mode: 'vision');
      }
    });
  }

  @override
  void dispose() {
    _visionLoopTimer?.cancel();
    _batteryTimer?.cancel();
    _compassSubscription?.cancel();
    _navigationSubscription?.cancel();
    _hudController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _porcupineService.dispose();
    _speechService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String? _getFormattedDistance() {
    if (!_isNavigating || _routeSteps.isEmpty || _currentStepIndex >= _routeSteps.length) return null;
    final dist = _routeSteps[_currentStepIndex].distance;
    return dist < 1000 ? "${dist.toInt()} m" : "${(dist / 1000).toStringAsFixed(1)} km";
  }

  String? _getFormattedDirection() {
     if (!_isNavigating || _routeSteps.isEmpty || _currentStepIndex >= _routeSteps.length) return null;
     final step = _routeSteps[_currentStepIndex];
     return step.instruction.split(' ').take(2).join(' '); // Shorten
  }
}
