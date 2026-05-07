/// WayFinder 2.0 — Home Screen
/// Voice-first dashboard with large touch targets for accessibility.
/// Follows WCAG AAA contrast standards for visually impaired users.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../providers/navigation_provider.dart';
import '../providers/safety_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/pulse_button.dart';
import '../widgets/status_indicator.dart';
import '../services/spatial_audio_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _announceReady();
  }

  Future<void> _announceReady() async {
    final audio = SpatialAudioService();
    // Providing a "system ready" check and welcome
    await audio.speak("WayFinder 2.0 активен. Агент RynnBrain подключен и готов к работе.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background glow
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.bgGlow,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildAlertBanner(context),
                const SizedBox(height: 24),
                _buildMainActions(context),
                const Spacer(),
                _buildBottomBar(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          // RynnBrain logo pulse
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPrimary.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 26),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 2400.ms, color: Colors.white.withOpacity(0.3)),

          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WayFinder 2.0',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'RynnBrain 2B · Активен',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.safe,
                      fontSize: 12,
                    ),
              ),
            ],
          ),
          const Spacer(),
          // Settings
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/settings'),
            child: Semantics(
              button: true,
              label: 'Настройки',
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.glassBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: const Icon(Icons.tune_rounded, color: AppTheme.textSecondary, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(BuildContext context) {
    return Consumer<SafetyProvider>(
      builder: (ctx, safety, _) {
        if (!safety.isDangerous) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppTheme.dangerGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.danger.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ВНИМАНИЕ: Обнаружено опасностей: ${safety.threats.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 300.ms)
              .shake(hz: 3, duration: 600.ms),
        );
      },
    );
  }

  Widget _buildMainActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Primary CTA — Navigate
          _BigActionButton(
            icon: Icons.directions_walk_rounded,
            label: 'Начать навигацию',
            sublabel: 'RynnBrain-Нав · Голосовое сопровождение',
            gradient: AppTheme.primaryGradient,
            glowColor: AppTheme.accentPrimary,
            onTap: () => Navigator.pushNamed(context, '/camera'),
            semanticLabel: 'Запустить камеру в режиме навигации',
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),

          const SizedBox(height: 16),

          Row(
            children: [
              // Safety Check
              Expanded(
                child: _MediumActionButton(
                  icon: Icons.shield_rounded,
                  label: 'Безопасность',
                  sublabel: 'Угрозы CoP',
                  color: AppTheme.warning,
                  onTap: () => Navigator.pushNamed(context, '/camera',
                      arguments: {'mode': 'cop'}),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
              ),

              const SizedBox(width: 14),

              // Object Search
              Expanded(
                child: _MediumActionButton(
                  icon: Icons.search_rounded,
                  label: 'Найти объект',
                  sublabel: 'RynnBrain-План',
                  color: AppTheme.accentTeal,
                  onTap: () => Navigator.pushNamed(context, '/search'),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (ctx, nav, _) {
        final isActive = nav.isActive;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusIndicator(active: isActive),
                    const SizedBox(width: 10),
                    Text(
                      isActive ? 'Анализ...' : 'Готов',
                      style: Theme.of(ctx).textTheme.labelLarge,
                    ),
                    const Spacer(),
                    if (nav.lastResult != null)
                      Text(
                        '${(nav.lastResult!.confidence * 100).toStringAsFixed(0)}% довер.',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                if (nav.lastResult != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    nav.lastResult!.rawText.length > 120
                        ? '${nav.lastResult!.rawText.substring(0, 120)}...'
                        : nav.lastResult!.rawText,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                    maxLines: 3,
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(delay: 400.ms),
        );
      },
    );
  }
}

// ─── Reusable action button widgets ──────────────────────────────────────────

class _BigActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Gradient gradient;
  final Color glowColor;
  final VoidCallback onTap;
  final String semanticLabel;

  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.glowColor,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 110,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 18),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sublabel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediumActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _MediumActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                color: color.withOpacity(0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
