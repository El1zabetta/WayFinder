/// WayFinder 3.0 — Accessibility Preferences Screen
/// Detailed control over contrast, text sizes, and haptic intensity.

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/accessibility.dart';
import '../core/constants.dart';

class AccessibilityPrefsScreen extends StatefulWidget {
  const AccessibilityPrefsScreen({super.key});

  @override
  State<AccessibilityPrefsScreen> createState() => _AccessibilityPrefsScreenState();
}

class _AccessibilityPrefsScreenState extends State<AccessibilityPrefsScreen> {
  double _textSizeMultiplier = 1.0;
  bool _highContrast = false;
  double _hapticLevel = 1.0;
  bool _screenReaderHints = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      announceToScreenReader('Accessibility preferences screen.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Accessibility'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Display'),
          _buildToggleRow(
            label: 'High Contrast Mode',
            value: _highContrast,
            onChanged: (v) => setState(() => _highContrast = v),
          ),
          _buildSliderRow(
            label: 'Text Size',
            value: _textSizeMultiplier,
            min: 1.0,
            max: 2.5,
            semanticLabel: 'Text size multiplier. Current value: ${_textSizeMultiplier.toStringAsFixed(1)}x',
            onChanged: (v) => setState(() => _textSizeMultiplier = v),
          ),
          
          const SizedBox(height: 32),
          
          _buildSectionHeader('Feedback & Cues'),
          _buildSliderRow(
            label: 'Haptic Intensity',
            value: _hapticLevel,
            min: 0.0,
            max: 1.0,
            semanticLabel: 'Haptic intensity. Current value: ${(_hapticLevel * 100).round()}%',
            onChanged: (v) {
              setState(() => _hapticLevel = v);
              HapticPatterns.tap();
            },
          ),
          _buildToggleRow(
            label: 'Verbose Screen Reader Hints',
            value: _screenReaderHints,
            onChanged: (v) => setState(() => _screenReaderHints = v),
          ),
        ],
      ),
    );
  }

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

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Semantics(
      toggled: value,
      label: label,
      child: Container(
        height: AppSizes.touchSecondary,
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
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
    required String semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
              const Spacer(),
              Text(
                value.toStringAsFixed(1),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
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
}
