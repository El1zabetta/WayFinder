import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/haptic_service.dart';
import '../widgets/glass_container.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';

class PremiumSettingsScreen extends StatefulWidget {
  final Function(Locale) onLocaleChange;
  final bool wakeWordEnabled;
  final VoidCallback onToggleWakeWord;
  final VoidCallback onClearHistory;
  final int messageCount;
  
  const PremiumSettingsScreen({
    super.key,
    required this.onLocaleChange,
    required this.wakeWordEnabled,
    required this.onToggleWakeWord,
    required this.onClearHistory,
    required this.messageCount,
  });

  @override
  State<PremiumSettingsScreen> createState() => _PremiumSettingsScreenState();
}

class _PremiumSettingsScreenState extends State<PremiumSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEffectsEnabled = true;
  double _voiceSpeed = 1.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A0E27),
            const Color(0xFF1A1F3A).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Header
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF0066FF)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.settings, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settings,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'Customize your experience',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // User Profile Section
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 100),
                child: _buildUserProfile(context),
              ),
              
              const SizedBox(height: 30),
              
              // Voice Settings
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 200),
                child: _buildSection(
                  'Voice & Audio',
                  Icons.mic,
                  [
                    _buildWakeWordToggle(l10n),
                    _buildVoiceSpeedSlider(),
                    _buildSoundEffectsToggle(),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Language Settings
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 300),
                child: _buildSection(
                  'Language / Язык',
                  Icons.language,
                  [
                    _buildLanguageOption('🇺🇸 English', const Locale('en')),
                    _buildLanguageOption('🇷🇺 Русский', const Locale('ru')),
                    _buildLanguageOption('🇰🇬 Кыргызча', const Locale('ky')),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Notifications
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 400),
                child: _buildSection(
                  'Notifications',
                  Icons.notifications,
                  [
                    _buildNotificationsToggle(),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Data & Privacy
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 500),
                child: _buildSection(
                  'Data & Privacy',
                  Icons.security,
                  [
                    _buildClearHistoryButton(context),
                    _buildPrivacyPolicyButton(),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // About
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 600),
                child: _buildAboutSection(),
              ),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfile(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService().getProfile(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          return GlassContainer(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Avatar with gradient border
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D4FF), Color(0xFF00E676)],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: const Color(0xFF0A0E27),
                      child: Text(
                        user['username']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D4FF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['username'] ?? 'User',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user['email'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E676), Color(0xFF00C853)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (user['subscription_type'] ?? 'FREE').toString().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    onPressed: () async {
                      HapticService.mediumImpact();
                      await AuthService().logout();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        }
        
        return GlassContainer(
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF0066FF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.login, color: Colors.white),
            ),
            title: const Text('Sign In', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Get unlimited access', style: TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
            onTap: () {
              HapticService.lightImpact();
              Navigator.of(context).pushNamed('/login');
            },
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF00D4FF), size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassContainer(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildWakeWordToggle(AppLocalizations l10n) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.wakeWordEnabled 
            ? const Color(0xFF00E676).withOpacity(0.2)
            : Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.mic_none,
          color: widget.wakeWordEnabled ? const Color(0xFF00E676) : Colors.white54,
        ),
      ),
      title: const Text(
        '"WayFinder" Activation',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        widget.wakeWordEnabled 
          ? "Listening for 'WayFinder'..." 
          : "Voice activation disabled",
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      value: widget.wakeWordEnabled,
      onChanged: (value) {
        HapticService.mediumImpact();
        widget.onToggleWakeWord();
      },
      activeColor: const Color(0xFF00E676),
    );
  }

  Widget _buildVoiceSpeedSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              const Text(
                'Voice Speed',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              const Spacer(),
              Text(
                '${_voiceSpeed.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Color(0xFF00D4FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF00D4FF),
              inactiveTrackColor: Colors.white24,
              thumbColor: const Color(0xFF00D4FF),
              overlayColor: const Color(0xFF00D4FF).withOpacity(0.2),
            ),
            child: Slider(
              value: _voiceSpeed,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (value) {
                setState(() => _voiceSpeed = value);
                HapticService.lightImpact();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundEffectsToggle() {
    return SwitchListTile(
      secondary: Icon(
        Icons.volume_up,
        color: _soundEffectsEnabled ? const Color(0xFF00D4FF) : Colors.white54,
      ),
      title: const Text(
        'Sound Effects',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      subtitle: const Text(
        'Play sounds for actions',
        style: TextStyle(color: Colors.white70, fontSize: 13),
      ),
      value: _soundEffectsEnabled,
      onChanged: (value) {
        setState(() => _soundEffectsEnabled = value);
        HapticService.lightImpact();
      },
      activeColor: const Color(0xFF00D4FF),
    );
  }

  Widget _buildLanguageOption(String label, Locale locale) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
      onTap: () {
        HapticService.lightImpact();
        widget.onLocaleChange(locale);
      },
    );
  }

  Widget _buildNotificationsToggle() {
    return SwitchListTile(
      secondary: Icon(
        Icons.notifications_active,
        color: _notificationsEnabled ? const Color(0xFFFFB800) : Colors.white54,
      ),
      title: const Text(
        'Push Notifications',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      subtitle: const Text(
        'Get updates and reminders',
        style: TextStyle(color: Colors.white70, fontSize: 13),
      ),
      value: _notificationsEnabled,
      onChanged: (value) {
        setState(() => _notificationsEnabled = value);
        HapticService.lightImpact();
      },
      activeColor: const Color(0xFFFFB800),
    );
  }

  Widget _buildClearHistoryButton(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      title: const Text(
        'Clear Chat History',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${widget.messageCount} messages stored',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
      onTap: () async {
        HapticService.mediumImpact();
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Clear History?', style: TextStyle(color: Colors.white)),
            content: const Text(
              'This will delete all chat messages permanently.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  HapticService.lightImpact();
                  Navigator.pop(context, false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  HapticService.heavyImpact();
                  Navigator.pop(context, true);
                },
                child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          widget.onClearHistory();
        }
      },
    );
  }

  Widget _buildPrivacyPolicyButton() {
    return ListTile(
      leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
      title: const Text(
        'Privacy Policy',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
      onTap: () {
        HapticService.lightImpact();
        // TODO: Open privacy policy
      },
    );
  }

  Widget _buildAboutSection() {
    return GlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF00E676)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.explore, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'WayFinder',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'AI-Powered Visual Assistant',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(Icons.language, 'Website'),
                const SizedBox(width: 16),
                _buildSocialButton(Icons.email, 'Support'),
                const SizedBox(width: 16),
                _buildSocialButton(Icons.star, 'Rate Us'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String label) {
    return InkWell(
      onTap: () => HapticService.lightImpact(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF00D4FF), size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
