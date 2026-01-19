import 'dart:async';
import 'haptic_service.dart';

/// Safety Service - Placeholder
/// Fall detection has been disabled for performance optimization
class SafetyService {
  final Function(int seconds)? onFallDetected;
  final Function()? onSafetyConfirmed;
  final Function()? onEmergencyTriggered;

  SafetyService({
    this.onFallDetected,
    this.onSafetyConfirmed,
    this.onEmergencyTriggered,
  });

  void startMonitoring() {
    // Disabled for performance
  }

  void stopMonitoring() {
    // Disabled for performance
  }

  void confirmSafety() {
    onSafetyConfirmed?.call();
    HapticService.success();
  }
}
