/// WayFinder 3.0 — Main Entry Point
/// Accessibility-first navigation assistant powered by RynnBrain + DeepSeek.
///
/// Flow: Splash → (Auth) → Home/Camera → Ask | Settings | History

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';

import 'core/app_theme.dart';
import 'core/navigation_service.dart';
import 'providers/navigation_provider.dart';
import 'providers/safety_provider.dart';
import 'providers/assistant_provider.dart';
import 'providers/auth_provider.dart';
import 'services/wakeword_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/home_camera_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';
import 'screens/accessibility_prefs_screen.dart';
import 'screens/system_status_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Force portrait — optimal for egocentric camera capture
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Immersive dark UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF080B14),
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => SafetyProvider()),
        ChangeNotifierProvider(create: (_) => AssistantProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WakewordService()..init()),
      ],
      child: const WayFinderApp(),
    ),
  );
}

class WayFinderApp extends StatelessWidget {
  const WayFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WayFinder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorKey: NavigationService.navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (ctx) => const SplashScreen(),
        '/auth': (ctx) => const AuthScreen(),
        '/onboarding': (ctx) => const OnboardingScreen(),
        '/permissions': (ctx) => const PermissionsScreen(),
        '/home': (ctx) => const HomeCameraScreen(),
        '/settings': (ctx) => const SettingsScreen(),
        '/history': (ctx) => const HistoryScreen(),
        '/accessibility_prefs': (ctx) => const AccessibilityPrefsScreen(),
        '/system_status': (ctx) => const SystemStatusScreen(),
      },
    );
  }
}
