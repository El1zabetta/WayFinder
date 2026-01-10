import 'dart:convert';
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
import 'package:animate_do/animate_do.dart';

import 'theme/app_theme.dart';
import 'services/advanced_ai_service.dart';
import 'services/porcupine_service.dart';
import 'services/navigation_service.dart';
import 'services/chat_history_service.dart';
import 'services/haptic_service.dart';
import 'services/enhanced_speech_service.dart';
import 'screens/chat_screen.dart';
import 'screens/vision_mode.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/premium_settings_screen.dart';
import 'widgets/glass_container.dart';
import 'widgets/premium_widgets.dart';
import 'widgets/voice_animations.dart';
import 'widgets/ai_animations.dart'; // Added for typing indicators

import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const VisionApp());
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
  
   // Advanced Features
  final _spatialAudio = SpatialAudioService();
  double _currentHeading = 0;
  StreamSubscription? _compassSubscription;


  // State
  int _currentIndex = 0;
  bool _isRecording = false;
  bool _isProcessing = false;
  List<ChatMessage> _messages = [];
  String _visionStatus = "";
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

  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      setState(() {
        _currentHeading = event.heading ?? 0;
      });
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
      _initCamera();
      // Restart wake word on resume if enabled
      if (_wakeWordEnabled && !_isRecording && !_isProcessing) {
        _porcupineService.startListening();
      }
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      try {
        _cameraController = CameraController(
          cameras.first, 
          ResolutionPreset.high, // Улучшаем качество камеры
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
Привет! Я WayFinder — твой новый виртуальный поводырь и помощник. 
Я создан, чтобы ты мог чувствовать себя увереннее:
1. Я могу строить маршруты и вести тебя за руку, подсказывая повороты.
2. Мои 'глаза' через камеру постоянно следят за путем и предупредят тебя об опасностях: люках, препятствиях или красном свете светофора.
3. Ты можешь просто спросить 'что я вижу?' или 'что передо мной?', и я опишу обстановку.

Давай быстро настроимся. Какой язык тебе удобнее - русский или английский?
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
       text: "Привет! Я WayFinder, ваш голосовой помощник. Скажите 'WayFinder' и задайте вопрос, или нажмите кнопку микрофона.", 
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
    // Re-init camera logic...
    await _initCamera();
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

    // 2. Check for Language selection (during onboarding)
    if (lowerText.contains('русский') || lowerText.contains('russian')) {
       widget.onLocaleChange(const Locale('ru'));
       _speak("Выбран русский язык. Теперь мы можем зарегистрироваться. Хочешь зайти через Google аккаунт? Просто скажи 'да' или 'зарегистрируй меня'.");
       return;
    } else if (lowerText.contains('английский') || lowerText.contains('english')) {
       widget.onLocaleChange(const Locale('en'));
       _speak("English language selected. Now we can register. Would you like to sign in with Google? Just say 'yes' or 'register me'.");
       return;
    }

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

    // 4. Check for Object Search
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
      _speak("Переключаюсь в режим навигатора. Камера активна.");
      return true;
    } else if (text.contains('стандартный режим') || text.contains('чат') || text.contains('standard mode')) {
      setState(() => _currentIndex = TAB_CHAT);
      _speak("Переключено в стандартный режим чата.");
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
    final navKeywords = ['как дойти', 'как доехать', 'маршрут', 'навигация', 'проведи', 'как пройти'];
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

  Future<void> _extractAndBuildRoute(String text) async {
    // Basic extraction - in production, the AI would give us coordinates or a clean address
    final cleanDest = text
      .replaceAll('построй маршрут до', '')
      .replaceAll('как пройти до', '')
      .replaceAll('как дойти до', '')
      .trim();
    
    if (cleanDest.isEmpty) return;

    try {
      _speak("Строю маршрут до $cleanDest. Пожалуйста, подождите.");
      
      final steps = await _navigationService.buildRoute(cleanDest);
      setState(() {
        _isNavigating = true;
        _destination = cleanDest;
        _routeSteps = steps;
        _currentStepIndex = 0;
      });

      if (steps.isNotEmpty) {
        final firstInstruct = _navigationService.getCurrentInstruction();
        _speak("Маршрут построен. $firstInstruct");
        _startNavigationLoop();
      }
    } catch (e) {
      _speak("Не удалось построить маршрут. Ошибка: $e");
    }
  }

  void _startNavigationLoop() {
    // Run navigation loop every 5 seconds
    Future.doWhile(() async {
      if (!_isNavigating || !mounted) return false;
      
      // 1. Check navigation progress
      // _checkNavigationProgress();
      
      // 2. Perform safety scan if enough time passed (every 3 seconds)
      final now = DateTime.now();
      if (_lastSafetyScan == null || now.difference(_lastSafetyScan!).inSeconds >= 3) {
        await _performSafetyScan();
        _lastSafetyScan = DateTime.now();
      }

      await Future.delayed(const Duration(seconds: 3));
      return _isNavigating;
    });
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

  Future<void> _speak(String text, {bool isPriority = false}) async {
    if (isPriority) {
      await _audioPlayer.stop();
      HapticService.mediumImpact();
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

    final aiResponse = await _api.smartAnalyze(text: text, mode: 'chat');
    if (aiResponse.audio != null) {
      final bytes = base64Decode(aiResponse.audio!);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      
      await _audioPlayer.setBalance(balance); // APPLY 3D PANNING
      await _audioPlayer.play(DeviceFileSource(file.path));
    }
  }

  void _stopNavigation() {
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
    try {
      XFile? imageFile;
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        // Делаем снимок для анализа, если мы в режиме Vision
        // Оптимизируем: делаем фото в низком разрешении для скорости ИИ
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

      final aiMsg = ChatMessage(text: msg, isUser: false, timestamp: DateTime.now());
      setState(() {
        if (mode == 'chat') {
           _messages.add(aiMsg);
        } else {
           _visionStatus = msg;
        }
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
          _isProcessing = false;
        });
        await _chatHistory.saveHistory(_messages);
      }
    } finally {
      if (mounted) {
          setState(() { _isProcessing = false; });
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
                onScanTap: () => {}, // Continuous scan usually
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
              child: FadeInDown(
                duration: const Duration(milliseconds: 600),
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
            ),

          // REAL-TIME SCANNING INDICATOR
          if (_isNavigating && _isSafetyScanning)
            Positioned(
              bottom: 120,
              left: 40,
              right: 40,
              child: FadeInUp(
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
              child: FadeInUp(
                duration: const Duration(milliseconds: 300),
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
            ),
          
          // Animated Wake Word Indicator
          if (_wakeWordEnabled && _currentIndex != TAB_SETTINGS)
            Positioned(
              top: 50,
              right: 20,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1500),
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
                setState(() => _currentIndex = 1);
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
}
