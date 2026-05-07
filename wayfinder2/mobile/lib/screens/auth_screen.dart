/// WayFinder 3.0 — Auth Screen
/// Simple Google Sign-In with screen reader support.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/accessibility.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      announceToScreenReader('Войдите в свой аккаунт Google, чтобы продолжить.');
    });
  }

  Future<void> _handleSignIn() async {
    final auth = context.read<AuthProvider>();
    announceToScreenReader('Вход в аккаунт...');
    final success = await auth.signInWithGoogle();
    
    if (success && mounted) {
      announceToScreenReader('Успешный вход.');
      Navigator.pushReplacementNamed(context, '/home');
    } else if (!success && mounted && auth.error != null) {
      announceToScreenReader('Ошибка входа. Пожалуйста, попробуйте снова.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: const Icon(
                      Icons.explore_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ).animate().fadeIn().scale(),
                  
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    'WayFinder',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  
                  const SizedBox(height: 8),
                  
                  // Tagline
                  const Text(
                    'Ваш ИИ-помощник в навигации',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                  
                  const Spacer(),
                  
                  // Sign-In Button
                  if (auth.isLoading)
                    const SizedBox(
                      height: AppSizes.touchPrimary,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.accentPrimary,
                        ),
                      ),
                    )
                  else
                    AccessibleButton(
                      onTap: _handleSignIn,
                      label: 'Войти через Google',
                      height: AppSizes.touchPrimary,
                      color: Colors.white,
                      textColor: Colors.black,
                      // The Google logo could be added here if needed
                    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
                    
                  if (auth.error != null && !auth.isLoading) ...[
                    const SizedBox(height: 16),
                    ErrorStateWidget(
                      message: 'Ошибка входа. Пожалуйста, попробуйте снова.',
                      actionLabel: 'Повторить',
                      onAction: _handleSignIn,
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Privacy Note
                  Semantics(
                    label: 'Ваши данные под защитой. Мы используем аккаунт только для входа.',
                    child: const Text(
                      'Ваши данные под защитой.\nМы используем аккаунт только для входа.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
