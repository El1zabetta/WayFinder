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
      announceToScreenReader('Settings screen');
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
          label: 'Go back',
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          ),
        ),
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ─── History ──────────────────────────────
          _buildNavigationRow(
            label: 'Session History',
            subtitle: 'View your previous navigations and questions',
            onTap: () => Navigator.pushNamed(context, '/history'),
          ),
          const SizedBox(height: 24),

          // ─── Account ─────────────────────────────
          _buildSectionHeader('Account'),
          _buildAccountCard(),
          const SizedBox(height: 24),

          // ─── Voice & Audio ───────────────────────
          _buildSectionHeader('Voice & Audio'),
          _buildSliderRow(
            label: 'Voice Speed',
            semanticLabel: 'Voice speed. Current value: ${(_voiceSpeed * 100).round()} percent',
            value: _voiceSpeed,
            min: 0.2,
            max: 1.0,
            onChanged: (v) {
              setState(() => _voiceSpeed = v);
              SpatialAudioService().speak('This is my speaking speed.');
            },
          ),
          _buildSliderRow(
            label: 'Speech Volume',
            semanticLabel: 'Speech volume. Current value: ${(_speechVolume * 100).round()} percent',
            value: _speechVolume,
            min: 0.3,
            max: 1.0,
            onChanged: (v) => setState(() => _speechVolume = v),
          ),
          _buildDropdownRow(
            label: 'Audio Cue Style',
            value: _audioCueStyle,
            options: ['Spoken', 'Tones', 'Both'],
            onChanged: (v) => setState(() => _audioCueStyle = v!),
          ),
          _buildToggleRow(
            label: 'Haptic Feedback',
            semanticLabel: 'Haptic feedback. Currently ${_hapticFeedback ? "on" : "off"}',
            value: _hapticFeedback,
            onChanged: (v) {
              setState(() => _hapticFeedback = v);
              if (v) HapticPatterns.success();
            },
          ),
          const SizedBox(height: 24),

          // ─── Navigation ──────────────────────────
          _buildSectionHeader('Navigation'),
          _buildToggleRow(
            label: 'Auto-start navigation on launch',
            semanticLabel: 'Auto start navigation. Currently ${_autoStart ? "on" : "off"}',
            value: _autoStart,
            onChanged: (v) => setState(() => _autoStart = v),
          ),
          _buildDropdownRow(
            label: 'Recording Duration',
            value: '${_recordDuration}s',
            options: ['3s', '5s', '7s'],
            onChanged: (v) => setState(() {
              _recordDuration = int.parse(v!.replaceAll('s', ''));
            }),
          ),
          _buildDropdownRow(
            label: 'Language',
            value: _language,
            options: ['English', 'Русский'],
            onChanged: (v) => setState(() => _language = v!),
          ),
          const SizedBox(height: 24),

          // ─── System ──────────────────────────────
          _buildSectionHeader('System'),
          _buildNavigationRow(
            label: 'System Status Dashboard',
            subtitle: 'Backend, RynnBrain, DeepSeek health',
            onTap: () => Navigator.pushNamed(context, '/system_status'),
          ),
          const SizedBox(height: 24),

          // ─── Accessibility ───────────────────────
          _buildSectionHeader('Accessibility'),
          _buildNavigationRow(
            label: 'Accessibility Preferences',
            subtitle: 'Text size, contrast, haptics, audio cues',
            onTap: () => Navigator.pushNamed(context, '/accessibility_prefs'),
          ),
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
            label: '$label, current value $value',
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
      label: _isCheckingHealth ? 'Checking...' : 'Check Connection',
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
      announceToScreenReader('Backend is connected. System is healthy.');
    } catch (e) {
      setState(() => _healthData = {'status': 'error', 'error': e.toString()});
      announceToScreenReader('Backend connection failed.');
    } finally {
      setState(() => _isCheckingHealth = false);
    }
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
                isOk ? 'System Healthy' : 'Connection Error',
                style: TextStyle(
                    color: color, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (isOk) ...[
            const SizedBox(height: 8),
            Text(
              'Engine: ${_healthData!['engine_mode'] ?? 'unknown'}\n'
              'GPU: ${_healthData!['gpu_available'] == true ? _healthData!['gpu_name'] : 'None (Mock mode)'}',
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
      label: 'Sign out of your account',
      child: GestureDetector(
        onTap: () async {
          HapticPatterns.tap();
          final auth = context.read<AuthProvider>();
          await auth.signOut();
          announceToScreenReader('Signed out.');
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
              'Sign Out',
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
