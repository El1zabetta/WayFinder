/// WayFinder 3.0 — Onboarding Screen
/// 3-page introduction with automatic screen reader announcements.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';
import '../core/accessibility.dart';
import '../core/constants.dart';
import '../services/spatial_audio_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final SpatialAudioService _audio = SpatialAudioService();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'WayFinder sees for you',
      'body': 'Point your phone camera ahead. WayFinder will describe what is around you.',
      'icon': Icons.visibility_rounded,
    },
    {
      'title': 'Safe navigation guidance',
      'body': 'WayFinder tells you about obstacles and guides you with voice directions.',
      'icon': Icons.explore_rounded,
    },
    {
      'title': 'Ask anything about the scene',
      'body': 'Tap the microphone or say "Way Finder" to ask: "What is in front of me?"',
      'icon': Icons.mic_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _announceCurrentPage(0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _announceCurrentPage(int index) {
    final page = _pages[index];
    final text = '${page['title']}. ${page['body']}';
    announceToScreenReader(text);
    _audio.speak(text);
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _announceCurrentPage(index);
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    
    if (mounted) {
      _audio.stop();
      Navigator.pushReplacementNamed(context, '/permissions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (Top Right)
            Align(
              alignment: Alignment.topRight,
              child: Semantics(
                button: true,
                label: 'Skip introduction',
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                ),
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                          ),
                          child: Icon(page['icon'] as IconData,
                              color: Colors.white, size: 60),
                        ).animate().scale(delay: 200.ms),
                        const SizedBox(height: 48),
                        Text(
                          page['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                        const SizedBox(height: 16),
                        Text(
                          page['body'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 18,
                            height: 1.5,
                          ),
                        ).animate().fadeIn(delay: 600.ms),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Controls (Dots + Next Button)
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppTheme.accentPrimary
                              : AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Next / Get Started button
                  AccessibleButton(
                    onTap: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _completeOnboarding();
                      }
                    },
                    label: _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Next',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
