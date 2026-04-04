// WayFinder 3.0 — Accessibility Helpers & Semantic Wrappers
// Provides consistent accessibility patterns across the entire app.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// Minimum touch target sizes (WCAG AAA)
class TouchTargets {
  static const double minimum = 48.0;
  static const double secondary = 56.0;
  static const double primary = 64.0;
  static const double hero = 80.0;
}

/// Announce a message to screen readers
void announceToScreenReader(String message) {
  SemanticsService.announce(message, TextDirection.ltr); // ignore: deprecated_member_use
}

/// Haptic patterns for different events
class HapticPatterns {
  static void recordingStart() => HapticFeedback.mediumImpact();
  static void recordingEnd() => HapticFeedback.lightImpact();
  static void threatDetected() => HapticFeedback.heavyImpact();
  static void success() => HapticFeedback.lightImpact();
  static void error() => HapticFeedback.vibrate();
  static void tap() => HapticFeedback.selectionClick();
}

/// Accessible large button — always meets minimum touch target
class AccessibleButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final double height;
  final bool enabled;
  final bool fullWidth;

  const AccessibleButton({
    super.key,
    required this.onTap,
    required this.label,
    this.icon,
    this.color,
    this.textColor,
    this.height = 56.0,
    this.enabled = true,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? Theme.of(context).colorScheme.primary;
    final fgColor = textColor ?? Colors.white;

    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () {
          HapticPatterns.tap();
          onTap();
        } : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: fullWidth ? double.infinity : null,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: enabled ? bgColor : bgColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fgColor, size: 24),
                const SizedBox(width: 12),
              ],
              Text(
                label,
                style: TextStyle(
                  color: enabled ? fgColor : fgColor.withOpacity(0.5),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status banner that announces state changes via screen reader
class StatusBanner extends StatelessWidget {
  final String message;
  final Color color;
  final bool isLive; // if true, auto-announce to screen reader

  const StatusBanner({
    super.key,
    required this.message,
    this.color = Colors.blue,
    this.isLive = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isLive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        announceToScreenReader(message);
      });
    }

    return Semantics(
      liveRegion: isLive,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          border: Border(bottom: BorderSide(color: color.withOpacity(0.3))),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable error state widget with spoken fallback
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String? spokenMessage;

  const ErrorStateWidget({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.spokenMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: spokenMessage ?? message,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFFF4444)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF0F4FF),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            AccessibleButton(
              onTap: onAction,
              label: actionLabel,
              icon: Icons.refresh_rounded,
              color: const Color(0xFF4E9CFF),
            ),
          ],
        ),
      ),
    );
  }
}
