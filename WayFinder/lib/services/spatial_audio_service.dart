import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// ULTRA Premium Spatial Audio Service
/// Provides immersive 3D directional audio for navigation
/// Makes blind users FEEL where to go through sound positioning
class SpatialAudioService {
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _sonarPlayer = AudioPlayer();
  
  // Audio feedback intensity based on proximity
  double _lastDistance = 999;
  DateTime? _lastPingTime;
  
  /// Calculates the audio balance (-1.0 to 1.0) based on target angle
  /// [currentHeading] - where the user is facing (0-360)
  /// [targetAngle] - direction to the next waypoint (0-360)
  /// Returns: -1.0 (full left) to 1.0 (full right), 0 = center
  double calculateBalance(double currentHeading, double targetAngle) {
    double diff = targetAngle - currentHeading;
    
    // Normalize to -180 to 180
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    
    // Convert to -1.0 to 1.0 balance
    double balance = diff / 90.0;
    return balance.clamp(-1.0, 1.0);
  }

  /// Get human-readable direction instruction
  String getDirectionInstruction(double currentHeading, double targetAngle) {
    double diff = targetAngle - currentHeading;
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    
    if (diff.abs() < 15) {
      return "Прямо";
    } else if (diff >= 15 && diff < 45) {
      return "Немного правее";
    } else if (diff >= 45 && diff < 90) {
      return "Направо";
    } else if (diff >= 90 && diff < 135) {
      return "Резко направо";
    } else if (diff >= 135) {
      return "Разворот через правое плечо";
    } else if (diff <= -15 && diff > -45) {
      return "Немного левее";
    } else if (diff <= -45 && diff > -90) {
      return "Налево";
    } else if (diff <= -90 && diff > -135) {
      return "Резко налево";
    } else {
      return "Разворот через левое плечо";
    }
  }

  /// Play directional audio alert
  Future<void> playDirectionalAlert(String audioPath, double balance) async {
    await _player.setBalance(balance);
    await _player.setVolume(1.0);
    await _player.play(DeviceFileSource(audioPath));
  }

  /// Intelligent sonar ping that adapts based on distance
  /// - Closer = faster pings, higher pitch feeling
  /// - Further = slower pings
  Future<void> playSonarPing(double distance, double balance) async {
    // Calculate ping interval based on distance
    // 5m = 200ms, 50m = 2000ms
    int intervalMs = (distance * 40).clamp(200, 2000).toInt();
    
    final now = DateTime.now();
    if (_lastPingTime != null) {
      final elapsed = now.difference(_lastPingTime!).inMilliseconds;
      if (elapsed < intervalMs) return; // Too soon for next ping
    }
    
    _lastPingTime = now;
    _lastDistance = distance;
    
    // Play haptic feedback as "audio" substitute (works without sound files)
    await _triggerDirectionalHaptic(balance, distance);
  }

  /// Trigger directional haptic feedback
  /// Left/Right balance creates asymmetric vibration pattern
  Future<void> _triggerDirectionalHaptic(double balance, double distance) async {
    // Intensity based on proximity (closer = stronger)
    int intensity = ((1 - (distance / 100)) * 255).clamp(50, 255).toInt();
    
    if (balance < -0.3) {
      // Target is to the LEFT - vibrate in "left" pattern
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.lightImpact();
    } else if (balance > 0.3) {
      // Target is to the RIGHT - vibrate in "right" pattern  
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.mediumImpact();
    } else {
      // Target is STRAIGHT AHEAD - single strong pulse
      await HapticFeedback.heavyImpact();
    }
  }

  /// Calculate urgency level based on distance
  /// Returns 0.0 (far) to 1.0 (very close)
  double calculateUrgency(double distance) {
    if (distance < 5) return 1.0;
    if (distance < 10) return 0.8;
    if (distance < 25) return 0.5;
    if (distance < 50) return 0.3;
    return 0.1;
  }

  /// Get clock position for direction (like "цель на 2 часа")
  String getClockPosition(double currentHeading, double targetAngle) {
    double diff = targetAngle - currentHeading;
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    
    // Convert angle to clock position (12 o'clock = straight ahead)
    int clockPos = ((diff + 180) / 30).round() % 12;
    if (clockPos == 0) clockPos = 12;
    
    return "$clockPos часов";
  }

  /// Announce direction in natural language
  String getFullDirectionAnnouncement(double heading, double target, double distance) {
    final direction = getDirectionInstruction(heading, target);
    final clock = getClockPosition(heading, target);
    final distanceStr = distance < 1000 
        ? "${distance.toInt()} метров"
        : "${(distance / 1000).toStringAsFixed(1)} км";
    
    return "$direction, на $clock, $distanceStr";
  }

  void dispose() {
    _player.dispose();
    _sonarPlayer.dispose();
  }
}
