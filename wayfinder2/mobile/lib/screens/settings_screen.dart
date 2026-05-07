/// WayFinder 3.0 — Settings Screen
/// Account, voice, navigation, system, accessibility.
/// Large touch targets, accessible labels, no tiny icons.

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/accessibility.dart';
import '../core/constants.dart';
import '../services/api_client.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../services/spatial_audio_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Voice settings
  double _voiceSpeed = 0.5;
  double _speechVolume = 1.0;
  String _audioCueStyle = 'Spoken';

  // Navigation settings
  bool _hapticFeedback = true;
  bool _autoStart = false;
  int _recordDuration = 3;
  String _language = 'English';

  // System status
  bool _isCheckingHealth = false;
  Map<String, dynamic>? _healthData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      announceToScreenReader('Экран настроек');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: Semantics(
          button: true,
          label: 'Назад',
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          ),
        ),
        title: const Text('Настройки'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ─── History ──────────────────────────────
          _buildNavigationRow(
            label: 'История сессий',
            subtitle: 'Просмотр предыдущих маршрутов и вопросов',
            onTap: () => Navigator.pushNamed(context, '/history'),
          ),
          const SizedBox(height: 24),

          // ─── Account ─────────────────────────────
          _buildSectionHeader('Аккаунт'),
          _buildAccountCard(),
          const SizedBox(height: 24),

          // ─── Voice & Audio ───────────────────────
          _buildSectionHeader('Голос и Аудио'),
          _buildSliderRow(
            label: 'Скорость речи',
            semanticLabel: 'Скорость речи. Текущее значение: ${(_voiceSpeed * 100).round()} процентов',
            value: _voiceSpeed,
            min: 0.2,
            max: 1.0,
            onChanged: (v) {
              setState(() => _voiceSpeed = v);
              SpatialAudioService().speak('Это моя скорость речи.');
            },
          ),
          _buildSliderRow(
            label: 'Громкость речи',
            semanticLabel: 'Громкость речи. Текущее значение: ${(_speechVolume * 100).round()} процентов',
            value: _speechVolume,
            min: 0.3,
            max: 1.0,
            onChanged: (v) => setState(() => _speechVolume = v),
          ),
          _buildDropdownRow(
            label: 'Стиль аудио-подсказок',
            value: _audioCueStyle == 'Spoken' ? 'Голос' : (_audioCueStyle == 'Tones' ? 'Звуки' : 'Оба'),
            options: ['Голос', 'Звуки', 'Оба'],
            onChanged: (v) => setState(() {
              if (v == 'Голос') _audioCueStyle = 'Spoken';
              else if (v == 'Звуки') _audioCueStyle = 'Tones';
              else _audioCueStyle = 'Both';
            }),
          ),
          _buildToggleRow(
            label: 'Виброотклик',
            semanticLabel: 'Виброотклик. Сейчас ${_hapticFeedback ? "включен" : "выключен"}',
            value: _hapticFeedback,
            onChanged: (v) {
              setState(() => _hapticFeedback = v);
              if (v) HapticPatterns.success();
            },
          ),
          const SizedBox(height: 24),

          // ─── Navigation ──────────────────────────
          _buildSectionHeader('Навигация'),
          _buildToggleRow(
            label: 'Автозапуск навигации при входе',
            semanticLabel: 'Автозапуск навигации. Сейчас ${_autoStart ? "включен" : "выключен"}',
            value: _autoStart,
            onChanged: (v) => setState(() => _autoStart = v),
          ),
          _buildDropdownRow(
            label: 'Длительность записи',
            value: '${_recordDuration}с',
            options: ['3с', '5с', '7с'],
            onChanged: (v) => setState(() {
              _recordDuration = int.parse(v!.replaceAll('с', ''));
            }),
          ),
          _buildDropdownRow(
            label: 'Язык',
            value: _language,
            options: ['English', 'Русский'],
            onChanged: (v) => setState(() => _language = v!),
          ),
          const SizedBox(height: 24),

          // ─── System ──────────────────────────────
          _buildSectionHeader('Система'),
          _buildNavigationRow(
            label: 'Статус системы',
            subtitle: 'Состояние бэкенда и нейросетей',
            onTap: () => Navigator.pushNamed(context, '/system_status'),
          ),
          const SizedBox(height: 24),

          // ─── Accessibility ───────────────────────
          _buildSectionHeader('Доступность'),
          _buildNavigationRow(
            label: 'Настройки доступности',
            subtitle: 'Размер текста, контрастность, виброотклик',
            onTap: () => Navigator.pushNamed(context, '/accessibility_prefs'),
          ),
          _buildRepeatInstructionButton(),
          const SizedBox(height: 32),

          // ─── Sign Out ────────────────────────────
          _buildSignOutButton(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ─── Components ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: const TextStyle(
            color: AppTheme.accentPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary.withOpacity(0.15),
              shape: BoxShape.circle,
              image: user?.photoURL != null ? DecorationImage(
                image: NetworkImage(user!.photoURL!),
              ) : null,
            ),
            child: user?.photoURL == null
                ? const Icon(Icons.person_rounded, color: AppTheme.accentPrimary, size: 24)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.displayName ?? 'WayFinder User',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(user?.email ?? 'Please sign in',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? semanticLabel,
  }) {
    return Semantics(
      toggled: value,
      label: semanticLabel ?? label,
      child: Container(
        height: AppSizes.touchSecondary,
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 15),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.accentPrimary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String? semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel ?? label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 15)),
              const Spacer(),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
          SizedBox(
            height: AppSizes.touchMinimum,
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: AppTheme.accentPrimary,
              inactiveColor: AppTheme.surface,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: AppSizes.touchSecondary,
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 15)),
          ),
          Semantics(
            label: '$label, текущее значение $value',
            child: DropdownButton<String>(
              value: value,
              dropdownColor: AppTheme.surfaceElevated,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14),
              underline: const SizedBox.shrink(),
              items: options.map((o) => DropdownMenuItem(
                value: o,
                child: Text(o),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      height: AppSizes.touchMinimum,
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 15)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildNavigationRow({
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$label. $subtitle',
      child: GestureDetector(
        onTap: () {
          HapticPatterns.tap();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckConnectionButton() {
    return AccessibleButton(
      onTap: _checkConnection,
      label: _isCheckingHealth ? 'Проверка...' : 'Проверить соединение',
      icon: Icons.wifi_find_rounded,
      color: AppTheme.surfaceElevated,
      textColor: AppTheme.textPrimary,
      enabled: !_isCheckingHealth,
    );
  }

  Future<void> _checkConnection() async {
    setState(() {
      _isCheckingHealth = true;
      _healthData = null;
    });

    try {
      final data = await WayFinderApi.health().timeout(
        const Duration(seconds: 10),
      );
      setState(() => _healthData = data);
      announceToScreenReader('Сервер подключен. Система работает нормально.');
    } catch (e) {
      setState(() => _healthData = {'status': 'error', 'error': e.toString()});
      announceToScreenReader('Ошибка подключения к серверу.');
    } finally {
      setState(() => _isCheckingHealth = false);
    }
  }

  Widget _buildRepeatInstructionButton() {
    return Semantics(
      button: true,
      label: 'Воспроизвести приветственную инструкцию снова',
      child: GestureDetector(
        onTap: () async {
          HapticPatterns.tap();
          announceToScreenReader('Воспроизведение приветственной инструкции.');
          const instruction = 'Добро пожаловать в WayFinder. Наведите камеру перед собой. '
              'Я буду сообщать о препятствиях и помогать ориентироваться. '
              'Чтобы задать вопрос, скажите: WayFinder. '
              'Приложение помогает с навигацией, но не заменяет трость, собаку-поводыря или вашу осторожность.';
          SpatialAudioService().speak(instruction);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.volume_up_rounded, color: AppTheme.accentPrimary, size: 24),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Повторить приветственную инструкцию',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Озвучить приветственную инструкцию повторно',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthStatus() {
    if (_healthData == null) return const SizedBox.shrink();

    final isOk = _healthData!['status'] == 'ok';
    final color = isOk ? AppTheme.safe : AppTheme.danger;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isOk ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                isOk ? 'Система исправна' : 'Ошибка подключения',
                style: TextStyle(
                    color: color, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (isOk) ...[
            const SizedBox(height: 8),
            Text(
              'Движок: ${_healthData!['engine_mode'] ?? 'неизвестно'}\n'
              'GPU: ${_healthData!['gpu_available'] == true ? _healthData!['gpu_name'] : 'Нет (режим симуляции)'}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return Semantics(
      button: true,
      label: 'Выйти из своего аккаунта',
      child: GestureDetector(
        onTap: () async {
          HapticPatterns.tap();
          final auth = context.read<AuthProvider>();
          await auth.signOut();
          announceToScreenReader('Выход из системы выполнен.');
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/auth');
          }
        },
        child: Container(
          height: AppSizes.touchSecondary,
          decoration: BoxDecoration(
            color: AppTheme.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
          ),
          child: const Center(
            child: Text(
              'Выйти',
              style: TextStyle(
                color: AppTheme.danger,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
