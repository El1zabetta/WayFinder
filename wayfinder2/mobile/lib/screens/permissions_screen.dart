/// WayFinder 3.0 — Permissions Screen
/// Camera + Mic permissions with clear, accessible human explanations.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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
        'WayFinder needs access to your camera to see your surroundings, '
        'and your microphone to hear your questions. Please allow access.',
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
      announceToScreenReader('Camera access is permanently denied. Please enable it in device settings.');
      openAppSettings();
    } else if (status.isGranted) {
      announceToScreenReader('Camera access granted.');
      HapticPatterns.success();
    }
  }

  Future<void> _requestMic() async {
    final status = await Permission.microphone.request();
    setState(() => _micGranted = status.isGranted);
    if (status.isPermanentlyDenied) {
      announceToScreenReader('Microphone access is permanently denied. Please enable it in device settings.');
      openAppSettings();
    } else if (status.isGranted) {
      announceToScreenReader('Microphone access granted.');
      HapticPatterns.success();
    }
  }

  void _finish() {
    if (!_cameraGranted) {
      announceToScreenReader('Camera access is required for WayFinder to work.');
      _audio.speak('Camera access is required for WayFinder to work.');
      return;
    }
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Permissions'),
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
                'WayFinder needs access',
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
                title: 'Camera',
                description: "To see what's around you and detect obstacles.",
                isGranted: _cameraGranted,
                onRequest: _requestCamera,
              ),

              const SizedBox(height: 24),

              // Microphone Permission
              _buildPermissionCard(
                icon: Icons.mic_rounded,
                title: 'Microphone',
                description: 'To hear your questions and give voice answers.',
                isGranted: _micGranted,
                onRequest: _requestMic,
              ),

              const Spacer(),

              // Continue Button
              AccessibleButton(
                onTap: _finish,
                label: 'Continue',
                enabled: _cameraGranted, // Camera is strictly required
                icon: Icons.arrow_forward_rounded,
              ),
              if (!_cameraGranted)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      'Camera is required to continue',
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
              label: 'Allow $title access.',
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
                      'Allow Access',
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
}
