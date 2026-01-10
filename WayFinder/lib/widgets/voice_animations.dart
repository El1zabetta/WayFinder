import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Voice Wave Visualization Widget
/// Shows animated sound waves when recording or processing voice
class VoiceWaveAnimation extends StatefulWidget {
  final bool isActive;
  final Color color;
  final double height;
  
  const VoiceWaveAnimation({
    super.key,
    required this.isActive,
    this.color = const Color(0xFF00D4FF),
    this.height = 60,
  });

  @override
  State<VoiceWaveAnimation> createState() => _VoiceWaveAnimationState();
}

class _VoiceWaveAnimationState extends State<VoiceWaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(VoiceWaveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: VoiceWavePainter(
              animationValue: _controller.value,
              color: widget.color,
              isActive: widget.isActive,
            ),
            size: Size(double.infinity, widget.height),
          );
        },
      ),
    );
  }
}

class VoiceWavePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final bool isActive;

  VoiceWavePainter({
    required this.animationValue,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    final barWidth = 4.0;
    final spacing = 8.0;
    final barCount = (size.width / (barWidth + spacing)).floor();

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing) + barWidth / 2;
      
      // Create wave effect with different frequencies
      final frequency = 2 + (i % 3);
      final phase = animationValue * 2 * math.pi * frequency;
      final amplitude = 15 + math.sin(i * 0.5) * 10;
      
      final height = amplitude * math.sin(phase + i * 0.3).abs();
      
      final startY = centerY - height;
      final endY = centerY + height;

      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(VoiceWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isActive != isActive;
  }
}

/// Circular Audio Visualizer
class CircularAudioVisualizer extends StatefulWidget {
  final bool isActive;
  final Color color;
  final double size;
  
  const CircularAudioVisualizer({
    super.key,
    required this.isActive,
    this.color = const Color(0xFF00D4FF),
    this.size = 200,
  });

  @override
  State<CircularAudioVisualizer> createState() => _CircularAudioVisualizerState();
}

class _CircularAudioVisualizerState extends State<CircularAudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(CircularAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: CircularVisualizerPainter(
              animationValue: _controller.value,
              color: widget.color,
              isActive: widget.isActive,
            ),
          );
        },
      ),
    );
  }
}

class CircularVisualizerPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final bool isActive;

  CircularVisualizerPainter({
    required this.animationValue,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    final barCount = 60;

    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * math.pi;
      
      // Create pulsing effect
      final frequency = 1 + (i % 5) * 0.5;
      final phase = animationValue * 2 * math.pi * frequency;
      final amplitude = 10 + math.sin(i * 0.2) * 5;
      final barHeight = amplitude * (0.5 + 0.5 * math.sin(phase + i * 0.1).abs());

      final startX = center.dx + radius * math.cos(angle);
      final startY = center.dy + radius * math.sin(angle);
      
      final endX = center.dx + (radius + barHeight) * math.cos(angle);
      final endY = center.dy + (radius + barHeight) * math.sin(angle);

      final paint = Paint()
        ..color = color.withOpacity(0.5 + 0.5 * math.sin(phase).abs())
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CircularVisualizerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isActive != isActive;
  }
}
