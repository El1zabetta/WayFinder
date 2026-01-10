import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;
    
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    
    if (onboardingCompleted) {
      Navigator.of(context).pushReplacementNamed('/');
    } else {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0A0E27),
              Color(0xFF1A1F3A),
              Color(0xFF0A0E27),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo
              Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating gradient ring
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _controller.value * 2 * math.pi,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                const Color(0xFF00D4FF),
                                const Color(0xFF00E676),
                                const Color(0xFFFF2E63),
                                const Color(0xFF00D4FF),
                              ],
                              stops: const [0.0, 0.33, 0.66, 1.0],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Inner circle
                  Container(
                    width: 160,
                    height: 160,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0A0E27),
                      shape: BoxShape.circle,
                    ),
                  ),
                  
                  // Logo icon
                  ZoomIn(
                    duration: const Duration(milliseconds: 1000),
                    child: const Icon(
                      Icons.explore,
                      size: 80,
                      color: Color(0xFF00D4FF),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // App name
              FadeInUp(
                duration: const Duration(milliseconds: 1200),
                delay: const Duration(milliseconds: 500),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF00D4FF),
                      Color(0xFF00E676),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'WayFinder',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Tagline
              FadeInUp(
                duration: const Duration(milliseconds: 1200),
                delay: const Duration(milliseconds: 800),
                child: const Text(
                  'AI-Powered Visual Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white54,
                    letterSpacing: 1,
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Loading indicator
              FadeIn(
                duration: const Duration(milliseconds: 1500),
                delay: const Duration(milliseconds: 1200),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00D4FF),
                    ),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
