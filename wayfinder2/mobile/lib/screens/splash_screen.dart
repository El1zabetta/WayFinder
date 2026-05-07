/// WayFinder 3.0 — Splash Screen
/// Auth check, backend health check, fast transition.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_theme.dart';
import '../core/accessibility.dart';
import '../services/api_client.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Запуск...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _runStartup();
  }

  Future<void> _runStartup() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      announceToScreenReader('WayFinder запускается. Пожалуйста, подождите.');
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    try {
      setState(() => _status = 'Подключение...');
      await WayFinderApi.health().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Backend down is not fatal
    }

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    if (!hasSeenOnboarding) {
      Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }

    final camera = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    if (!camera.isGranted || !mic.isGranted) {
      Navigator.pushReplacementNamed(context, '/permissions');
      return;
    }

    if (mounted) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Semantics(
        label: 'Заставочный экран WayFinder. $_status',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo circle
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentPrimary.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.8, 0.8)),

              const SizedBox(height: 24),

              // App name
              Text(
                'WayFinder',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 8),

              // Status text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _status,
                  key: ValueKey(_status),
                  style: TextStyle(
                    color: _hasError
                        ? AppTheme.danger
                        : AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Loading indicator
              if (!_hasError)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.accentPrimary.withOpacity(0.6),
                  ),
                ).animate().fadeIn(delay: 400.ms),

              // Retry button on error
              if (_hasError) ...[
                const SizedBox(height: 16),
                AccessibleButton(
                  onTap: () {
                    setState(() {
                      _hasError = false;
                      _status = 'Повторная попытка...';
                    });
                    _runStartup();
                  },
                  label: 'Повторить',
                  icon: Icons.refresh_rounded,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
