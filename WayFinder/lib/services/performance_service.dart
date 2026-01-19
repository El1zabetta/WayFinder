import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:battery_plus/battery_plus.dart';

/// Performance Optimization Service
/// Handles cache cleanup, battery monitoring, and performance tuning
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final Battery _battery = Battery();
  bool _lowPowerMode = false;
  int _batteryLevel = 100;
  
  /// Initialize performance monitoring
  Future<void> initialize() async {
    await _checkBattery();
    await _cleanOldCache();
    
    // Monitor battery changes
    _battery.onBatteryStateChanged.listen((state) async {
      await _checkBattery();
    });
  }

  /// Check battery level and enable power saving if low
  Future<void> _checkBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _lowPowerMode = _batteryLevel < 20;
      print("🔋 Battery: $_batteryLevel%, Low Power Mode: $_lowPowerMode");
    } catch (e) {
      print("⚠️ Battery check failed: $e");
    }
  }

  /// Clean old temporary files (audio, images) older than 1 hour
  Future<void> _cleanOldCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      int deletedCount = 0;
      int savedBytes = 0;
      
      await for (final entity in tempDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);
          
          // Delete files older than 1 hour
          if (age.inHours >= 1) {
            savedBytes += await entity.length();
            await entity.delete();
            deletedCount++;
          }
        }
      }
      
      if (deletedCount > 0) {
        print("🧹 Cleaned $deletedCount old cache files (${(savedBytes / 1024 / 1024).toStringAsFixed(1)} MB)");
      }
    } catch (e) {
      print("⚠️ Cache cleanup failed: $e");
    }
  }

  /// Get optimal settings based on battery and performance
  PerformanceSettings getOptimalSettings() {
    if (_lowPowerMode) {
      return PerformanceSettings(
        imageQuality: 20,
        gpsUpdateInterval: 20, // meters
        enableSafetyScan: false, // Disable heavy AI scans
        useFastTTS: true,
      );
    }
    
    return PerformanceSettings(
      imageQuality: 25,
      gpsUpdateInterval: 10,
      enableSafetyScan: true,
      useFastTTS: true,
    );
  }

  /// Check if we should show low battery warning
  bool get shouldWarnLowBattery => _batteryLevel < 15;
  
  /// Get battery percentage
  int get batteryLevel => _batteryLevel;
  
  /// Check if in low power mode
  bool get isLowPowerMode => _lowPowerMode;

  /// Force cache cleanup (can be called manually)
  Future<void> forceCleanup() async {
    await _cleanOldCache();
  }
}

/// Performance settings based on device state
class PerformanceSettings {
  final int imageQuality;
  final int gpsUpdateInterval;
  final bool enableSafetyScan;
  final bool useFastTTS;

  PerformanceSettings({
    required this.imageQuality,
    required this.gpsUpdateInterval,
    required this.enableSafetyScan,
    required this.useFastTTS,
  });
}
