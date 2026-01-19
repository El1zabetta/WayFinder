import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

/// Premium Haptic Feedback Service
/// Provides various haptic patterns for different interactions
class HapticService {
  // Light tap - for button presses
  static Future<void> lightImpact() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 10);
    }
  }

  // Medium impact - for selections
  static Future<void> mediumImpact() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 20);
    }
  }

  // Heavy impact - for important actions
  static Future<void> heavyImpact() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 50);
    }
  }

  // Success pattern - double tap
  static Future<void> success() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 30);
      await Future.delayed(const Duration(milliseconds: 100));
      await Vibration.vibrate(duration: 30);
    }
  }

  // Error pattern - long vibration
  static Future<void> error() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 200);
    }
  }

  // Wake word detected - triple tap pattern
  static Future<void> wakeWordDetected() async {
    if (await Vibration.hasVibrator() ?? false) {
      // Triple vibration pattern
      await Vibration.vibrate(duration: 50);
      await Future.delayed(const Duration(milliseconds: 100));
      await Vibration.vibrate(duration: 50);
      await Future.delayed(const Duration(milliseconds: 100));
      await Vibration.vibrate(duration: 50);
    }
  }

  // Recording started - pulsing pattern
  static Future<void> recordingStarted() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 100);
    }
  }

  // Recording stopped
  static Future<void> recordingStopped() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 30);
    }
  }

  // --- NAVIGATION SPECIFIC HAPTICS ---

  /// Pulsing pattern for approaching a turn
  static Future<void> turnApproaching() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(pattern: [0, 100, 100, 100], intensities: [0, 128, 0, 128]);
    }
  }

  /// Sharp double-tap for obstacle detection
  static Future<void> obstacleAlert() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(pattern: [0, 200, 50, 200], intensities: [0, 255, 0, 255]);
    }
  }

  /// Urgent rapid vibration for dangerous situations (red light, hole)
  static Future<void> emergencyWarning() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(pattern: [0, 500, 100, 500, 100, 500], intensities: [0, 255, 0, 255, 0, 255]);
    }
  }

  /// Success melody for reaching destination
  static Future<void> destinationReached() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 300], intensities: [0, 100, 0, 150, 0, 255]);
    }
  }

  /// Directional haptic for LEFT turn
  static Future<void> leftTurn() async {
    if (await Vibration.hasVibrator() ?? false) {
      // Two quick pulses (left pattern)
      await Vibration.vibrate(duration: 100);
      await Future.delayed(const Duration(milliseconds: 80));
      await Vibration.vibrate(duration: 50);
    }
  }

  /// Directional haptic for RIGHT turn
  static Future<void> rightTurn() async {
    if (await Vibration.hasVibrator() ?? false) {
      // One short, one long (right pattern)
      await Vibration.vibrate(duration: 50);
      await Future.delayed(const Duration(milliseconds: 80));
      await Vibration.vibrate(duration: 100);
    }
  }

  /// Haptic for going straight
  static Future<void> goStraight() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 150);
    }
  }

  /// Gentle warning - attention needed but not urgent
  static Future<void> gentleWarning() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(pattern: [0, 50, 100, 50, 100, 50], intensities: [0, 128, 0, 128, 0, 128]);
    }
  }

  /// Confirmation haptic - action completed
  static Future<void> confirmation() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 40);
    }
  }
}
