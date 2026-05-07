/// WayFinder 3.0 — Permissions Screen
/// Camera + Mic + Internet permissions with clear, accessible human explanations.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';
import '../core/accessibility.dart';
import '../core/constants.dart';
import '../services/spatial_audio_service.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final SpatialAudioService _audio = SpatialAudioService();
  bool _cameraGranted = false;
  bool _micGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      announceToScreenReader(
        'WayFinder требуется доступ к камере, чтобы видеть ваше окружение, '
        'и к микрофону, чтобы слышать ваши вопросы. Пожалуйста, разрешите доступ.',
      );
    });
  }

  Future<void> _checkPermissions() async {
    final camera = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    setState(() {
      _cameraGranted = camera.isGranted;
      _micGranted = mic.isGranted;
    });
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    setState(() => _cameraGranted = status.isGranted);
    if (status.isPermanentlyDenied) {
      announceToScreenReader('Доступ к камере окончательно отклонен. Пожалуйста, включите его в настройках устройства.');
      openAppSettings();
    } else if (status.isGranted) {
      announceToScreenReader('Доступ к камере разрешен.');
      HapticPatterns.success();
    }
  }

  Future<void> _requestMic() async {
    final status = await Permission.microphone.request();
    setState(() => _micGranted = status.isGranted);
    if (status.isPermanentlyDenied) {
      announceToScreenReader('Доступ к микрофону окончательно отклонен. Пожалуйста, включите его в настройках устройства.');
      openAppSettings();
    } else if (status.isGranted) {
      announceToScreenReader('Доступ к микрофону разрешен.');
      HapticPatterns.success();
    }
  }

  Future<void> _playWelcomeInstruction() async {
    final prefs = await SharedPreferences.getInstance();
    final voiceEnabled = prefs.getBool('voice_enabled') ?? true;
    if (!voiceEnabled) return;

    const instruction = 'Добро пожаловать в WayFinder. Наведите камеру перед собой. '
        'Я буду сообщать о препятствиях и помогать ориентироваться. '
        'Чтобы задать вопрос, скажите: WayFinder. '
        'Приложение помогает с навигацией, но не заменяет трость, собаку-поводыря или вашу осторожность.';
    
    await prefs.setBool('has_heard_welcome', true);
    announceToScreenReader(instruction);
    _audio.speak(instruction);
  }

  void _finish() {
    if (!_cameraGranted) {
      announceToScreenReader('Доступ к камере обязателен для работы WayFinder.');
      _audio.speak('Доступ к камере обязателен для работы WayFinder.');
      return;
    }
    _playWelcomeInstruction();
    Navigator.pushReplacementNamed(context, '/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Разрешения'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WayFinder нужен доступ',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // Camera Permission
              _buildPermissionCard(
                icon: Icons.camera_alt_rounded,
                title: 'Камера',
                description: 'Камера нужна, чтобы анализировать окружение и сообщать о препятствиях перед вами.',
                isGranted: _cameraGranted,
                onRequest: _requestCamera,
              ),

              const SizedBox(height: 24),

              // Microphone Permission
              _buildPermissionCard(
                icon: Icons.mic_rounded,
                title: 'Микрофон',
                description: 'Микрофон нужен, чтобы услышать wake word "WayFinder" и ваши голосовые вопросы.',
                isGranted: _micGranted,
                onRequest: _requestMic,
              ),

              const SizedBox(height: 24),

              // Internet Info Card
              _buildInfoCard(
                icon: Icons.wifi_rounded,
                title: 'Интернет',
                description: 'Интернет нужен, чтобы отправить кадры на AI сервер и получить ответ.',
              ),

              const Spacer(),

              // Continue Button
              AccessibleButton(
                onTap: _finish,
                label: 'Продолжить',
                enabled: _cameraGranted, // Camera is strictly required
                icon: Icons.arrow_forward_rounded,
              ),
              if (!_cameraGranted)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      'Для продолжения необходим доступ к камере',
                      style: TextStyle(color: AppTheme.danger, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? AppTheme.safe : AppTheme.glassBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.accentPrimary, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (isGranted)
                const Icon(Icons.check_circle_rounded, color: AppTheme.safe),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (!isGranted)
            Semantics(
              button: true,
              label: 'Разрешить доступ к разделу $title.',
              child: GestureDetector(
                onTap: onRequest,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Разрешить доступ',
                      style: TextStyle(
                        color: AppTheme.accentPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.accentPrimary, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }
}
