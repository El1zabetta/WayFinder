/// WayFinder 3.0 — App Constants
/// Centralized sizing, durations, and configuration values.

class AppSizes {
  // Touch targets (WCAG AAA)
  static const double touchMinimum = 48.0;
  static const double touchSecondary = 56.0;
  static const double touchPrimary = 64.0;
  static const double touchHero = 80.0;

  // Spacing
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  // Border radius
  static const double radiusS = 12.0;
  static const double radiusM = 16.0;
  static const double radiusL = 20.0;
  static const double radiusXL = 28.0;

  // Icon sizes
  static const double iconS = 20.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 48.0;
}

class AppDurations {
  static const Duration recordingLength = Duration(seconds: 3);
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 400);
  static const Duration splashMinimum = Duration(milliseconds: 1500);
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration ttsDelay = Duration(milliseconds: 300);
}
