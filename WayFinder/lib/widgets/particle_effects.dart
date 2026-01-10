import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Particle Effect System
class ParticleEffect extends StatefulWidget {
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
  State<ParticleEffect> createState() => _ParticleEffectState();
}

class _ParticleEffectState extends State<ParticleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _controller.addListener(() {
      setState(() {
        for (var particle in _particles) {
          particle.update();
        }
      });
    });
  }

  @override
  void didUpdateWidget(ParticleEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _createParticles();
      _controller.forward(from: 0.0);
    }
  }

  void _createParticles() {
    _particles.clear();
    final particleCount = widget.type == ParticleType.explosion ? 30 : 20;
    
    for (int i = 0; i < particleCount; i++) {
      _particles.add(Particle(
        x: 0,
        y: 0,
        vx: (_random.nextDouble() - 0.5) * 400,
        vy: (_random.nextDouble() - 0.5) * 400,
        size: _random.nextDouble() * 8 + 4,
        color: widget.color,
        lifetime: 1.5,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_particles.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              painter: ParticlePainter(
                particles: _particles,
                progress: _controller.value,
              ),
            ),
          ),
      ],
    );
  }
}

enum ParticleType {
  explosion,
  sparkle,
  trail,
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double lifetime;
  double age = 0;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.lifetime,
  });

  void update() {
    age += 0.016; // ~60fps
    x += vx * 0.016;
    y += vy * 0.016;
    vy += 500 * 0.016; // Gravity
  }

  double get opacity => (1 - (age / lifetime)).clamp(0.0, 1.0);
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(centerX + particle.x, centerY + particle.y),
        particle.size * (1 - progress * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

/// Glowing Border Effect
class GlowingBorder extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double glowSize;
  final bool animate;
  
  const GlowingBorder({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF00D4FF),
    this.glowSize = 20,
    this.animate = true,
  });

  @override
  State<GlowingBorder> createState() => _GlowingBorderState();
}

class _GlowingBorderState extends State<GlowingBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(0.3 + _controller.value * 0.4),
                blurRadius: widget.glowSize,
                spreadRadius: widget.glowSize / 4,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Ripple Effect
class RippleEffect extends StatefulWidget {
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
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _radiusAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _radiusAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(RippleEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
        _controller.forward(from: 0.0);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: RipplePainter(
              radius: _radiusAnimation.value,
              opacity: _opacityAnimation.value,
              color: widget.color,
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final double radius;
  final double opacity;
  final Color color;

  RipplePainter({
    required this.radius,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radius > 0) {
      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      final center = Offset(size.width / 2, size.height / 2);
      final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) / 2;

      canvas.drawCircle(center, maxRadius * radius, paint);
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.opacity != opacity;
  }
}

/// Matrix Rain Effect (like in The Matrix)
class MatrixRain extends StatefulWidget {
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
  State<MatrixRain> createState() => _MatrixRainState();
}

class _MatrixRainState extends State<MatrixRain>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<MatrixColumn> _columns = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 100),
      vsync: this,
    )..repeat();

    // Create columns
    for (int i = 0; i < 20; i++) {
      _columns.add(MatrixColumn(
        x: i * 20.0,
        speed: _random.nextDouble() * 2 + 1,
        length: _random.nextInt(15) + 10,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, widget.height ?? MediaQuery.of(context).size.height),
          painter: MatrixPainter(
            columns: _columns,
            progress: _controller.value,
            color: widget.color,
            globalOpacity: widget.opacity,
          ),
        );
      },
    );
  }
}

class MatrixColumn {
  final double x;
  final double speed;
  final int length;
  double y = 0;

  MatrixColumn({
    required this.x,
    required this.speed,
    required this.length,
  });
}

class MatrixPainter extends CustomPainter {
  final List<MatrixColumn> columns;
  final double progress;
  final Color color;
  final double globalOpacity;
  static const String chars = '01アイウエオカキクケコサシスセソタチツテト';

  MatrixPainter({
    required this.columns,
    required this.progress,
    required this.color,
    required this.globalOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var column in columns) {
      column.y = (column.y + column.speed) % (size.height + 100);
      
      for (int i = 0; i < column.length; i++) {
        final opacity = ((1 - (i / column.length)) * 0.8 * globalOpacity).clamp(0.0, 1.0);
        final charPaint = TextPainter(
          text: TextSpan(
            text: chars[math.Random().nextInt(chars.length)],
            style: TextStyle(
              color: color.withOpacity(opacity),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        charPaint.paint(
          canvas,
          Offset(column.x, column.y - i * 20),
        );
      }
    }
  }

  @override
  bool shouldRepaint(MatrixPainter oldDelegate) => true;
}
