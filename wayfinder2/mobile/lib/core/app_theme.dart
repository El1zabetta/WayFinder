/// WayFinder 2.0 — App Theme
/// Dark, premium glassmorphism design optimized for accessibility

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Color Palette ──────────────────────────────────────────────────────
  static const Color background = Color(0xFF080B14);       // Deep navy black
  static const Color surface = Color(0xFF0F1526);          // Card surface
  static const Color surfaceElevated = Color(0xFF162035);  // Elevated card

  static const Color accentPrimary = Color(0xFF4E9CFF);    // Electric blue
  static const Color accentSecondary = Color(0xFF7B5CFF);  // Purple
  static const Color accentTeal = Color(0xFF00D4C8);       // Teal glow

  static const Color danger = Color(0xFFFF4444);           // Threat red
  static const Color warning = Color(0xFFFFB340);          // Warning amber
  static const Color safe = Color(0xFF2FD770);             // Safe green

  static const Color textPrimary = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF8B9BB4);
  static const Color textMuted = Color(0xFF4A5568);

  // ─── Glass Effect ───────────────────────────────────────────────────────
  static const Color glassBg = Color(0x1A4E9CFF);          // Blue-tinted glass
  static const Color glassBorder = Color(0x334E9CFF);

  // ─── Theme ──────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accentPrimary,
          secondary: accentSecondary,
          surface: surface,
          error: danger,
        ),
        textTheme: GoogleFonts.interTextTheme(
          const TextTheme(
            displayLarge: TextStyle(
              color: textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            displayMedium: TextStyle(
              color: textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
            titleLarge: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            titleMedium: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: TextStyle(
              color: textPrimary,
              fontSize: 16,
              height: 1.6,
            ),
            bodyMedium: TextStyle(
              color: textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
            labelLarge: TextStyle(
              color: accentPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        iconTheme: const IconThemeData(color: accentPrimary),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        useMaterial3: true,
      );

  // ─── Gradient Presets ───────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentPrimary, accentSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF4444), Color(0xFFFF7B00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient safeGradient = LinearGradient(
    colors: [Color(0xFF2FD770), Color(0xFF00D4C8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient bgGlow = RadialGradient(
    colors: [Color(0x1A4E9CFF), Colors.transparent],
    center: Alignment.topCenter,
    radius: 1.5,
  );
}
