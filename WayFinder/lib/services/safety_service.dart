import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'haptic_service.dart';

/// Premium Safety & SOS Service
/// Detects falls using accelerometer and manages emergency actions
class SafetyService {
  static const double _fallThreshold = 30.0; // G-force threshold for a fall
  static const Duration _countdownDuration = Duration(seconds: 15);
  
  StreamSubscription<AccelerometerEvent>? _subscription;
  bool _isCountdownActive = false;
  Timer? _countdownTimer;
  
  final Function(int seconds)? onFallDetected;
  final Function()? onSafetyConfirmed;
  final Function()? onEmergencyTriggered;

  SafetyService({
    this.onFallDetected,
    this.onSafetyConfirmed,
    this.onEmergencyTriggered,
  });

  void startMonitoring() {
    _subscription = accelerometerEvents.listen((AccelerometerEvent event) {
      // Calculate total acceleration
      double acceleration = (event.x * event.x + event.y * event.y + event.z * event.z);
      
      if (acceleration > (_fallThreshold * _fallThreshold) && !_isCountdownActive) {
        _handlePotentialFall();
      }
    });
  }

  void stopMonitoring() {
    _subscription?.cancel();
    _countdownTimer?.cancel();
  }

  void _handlePotentialFall() {
    _isCountdownActive = true;
    HapticService.emergencyWarning();
    
    int remaining = _countdownDuration.inSeconds;
    onFallDetected?.call(remaining);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (remaining <= 0) {
        timer.cancel();
        _triggerEmergency();
      } else {
        onFallDetected?.call(remaining);
      }
    });
  }

  void confirmSafety() {
    _isCountdownActive = false;
    _countdownTimer?.cancel();
    onSafetyConfirmed?.call();
    HapticService.success();
  }

  Future<void> _triggerEmergency() async {
    _isCountdownActive = false;
    onEmergencyTriggered?.call();
    
    // Example: Call emergency contact
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: '112', // Standard emergency number
    );
    
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }
}
