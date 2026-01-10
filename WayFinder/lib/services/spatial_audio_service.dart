import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

/// Premium Spatial Audio Service
/// Handles 3D-like directional audio feedback for navigation
class SpatialAudioService {
  final AudioPlayer _player = AudioPlayer();
  
  /// Calculates the audio balance (-1.0 to 1.0) based on target angle
  /// [currentHeading] - where the user is facing (0-360)
  /// [targetAngle] - direction to the next waypoint (0-360)
  double calculateBalance(double currentHeading, double targetAngle) {
    double diff = targetAngle - currentHeading;
    
    // Normalize to -180 to 180
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    
    // Convert to -1.0 to 1.0 balance
    // If diff is 0, balance is 0 (center)
    // If diff is -90 (left), balance is -1.0
    // If diff is 90 (right), balance is 1.0
    double balance = diff / 90.0;
    return balance.clamp(-1.0, 1.0);
  }

  Future<void> playDirectionalAlert(String audioPath, double balance) async {
    await _player.setBalance(balance);
    await _player.play(DeviceFileSource(audioPath));
  }

  /// Special "Sonar" ping that gets faster/louder as you get closer
  Future<void> playSonarPing(double distance, double balance) async {
    // Logic for sonar: higher pitch or faster repetition could be added here
    await _player.setBalance(balance);
    // await _player.play(AssetSource('sounds/ping.mp3')); // Assuming ping added
  }
}
