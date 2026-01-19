import 'package:flutter/material.dart';

/// Lightweight Particle Effect System - Optimized for Performance
/// All effects are minimal to ensure smooth 60fps

enum ParticleType {
  explosion,
  sparkle,
  trail,
}

/// Ultra-light particle effect - only triggers on demand, minimal particles
class ParticleEffect extends StatelessWidget {
  final Widget child;
  final bool trigger;
  final ParticleType type;
  final Color color;
  
  const ParticleEffect({
    super.key,
    required this.child,
    required this.trigger,
    this.type = ParticleType.explosion,
    this.color = const Color(0xFF00D4FF),
  });

  @override
  Widget build(BuildContext context) {
    // Simply return child - particles disabled for performance
    return child;
  }
}

/// Simplified Glowing Border - static glow, no animation
class GlowingBorder extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double glowSize;
  final bool animate;
  
  const GlowingBorder({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF00D4FF),
    this.glowSize = 15,
    this.animate = false, // Ignored - always static
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.4),
            blurRadius: glowSize,
            spreadRadius: glowSize / 4,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Simplified Ripple Effect - uses built-in InkWell
class RippleEffect extends StatelessWidget {
  final Widget child;
  final bool trigger;
  final Color color;
  final VoidCallback? onTap;
  
  const RippleEffect({
    super.key,
    required this.child,
    required this.trigger,
    this.color = const Color(0xFF00D4FF),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: color.withOpacity(0.3),
      highlightColor: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  }
}

/// Matrix Rain Effect - DISABLED for performance
/// Returns empty container
class MatrixRain extends StatelessWidget {
  final double? height;
  final Color color;
  final double opacity;
  
  const MatrixRain({
    super.key,
    this.height,
    this.color = const Color(0xFF00E676),
    this.opacity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    // Disabled - returns empty for performance
    return const SizedBox.shrink();
  }
}
