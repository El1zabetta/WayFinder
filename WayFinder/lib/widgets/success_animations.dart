import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;

/// Success Celebration Widget
/// Shows confetti animation on successful actions
class SuccessCelebration extends StatefulWidget {
  final Widget child;
  final bool trigger;
  
  const SuccessCelebration({
    super.key,
    required this.child,
    required this.trigger,
  });

  @override
  State<SuccessCelebration> createState() => _SuccessCelebrationState();
}

class _SuccessCelebrationState extends State<SuccessCelebration> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void didUpdateWidget(SuccessCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        widget.child,
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: math.pi / 2, // Down
          emissionFrequency: 0.05,
          numberOfParticles: 20,
          gravity: 0.3,
          colors: const [
            Color(0xFF00D4FF),
            Color(0xFF00E676),
            Color(0xFFFF2E63),
            Color(0xFFFFB800),
          ],
        ),
      ],
    );
  }
}

/// Animated Success Checkmark
class AnimatedCheckmark extends StatefulWidget {
  final double size;
  final Color color;
  
  const AnimatedCheckmark({
    super.key,
    this.size = 100,
    this.color = const Color(0xFF00E676),
  });

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
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
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: CheckmarkPainter(
                progress: _checkAnimation.value,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw circle
    final circlePaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      circlePaint,
    );

    // Draw checkmark
    final path = Path();
    final checkStart = Offset(size.width * 0.25, size.height * 0.5);
    final checkMiddle = Offset(size.width * 0.45, size.height * 0.7);
    final checkEnd = Offset(size.width * 0.75, size.height * 0.3);

    if (progress > 0) {
      path.moveTo(checkStart.dx, checkStart.dy);
      
      if (progress <= 0.5) {
        // First part of checkmark
        final currentProgress = progress * 2;
        final currentX = checkStart.dx + (checkMiddle.dx - checkStart.dx) * currentProgress;
        final currentY = checkStart.dy + (checkMiddle.dy - checkStart.dy) * currentProgress;
        path.lineTo(currentX, currentY);
      } else {
        // Complete first part
        path.lineTo(checkMiddle.dx, checkMiddle.dy);
        
        // Second part of checkmark
        final currentProgress = (progress - 0.5) * 2;
        final currentX = checkMiddle.dx + (checkEnd.dx - checkMiddle.dx) * currentProgress;
        final currentY = checkMiddle.dy + (checkEnd.dy - checkMiddle.dy) * currentProgress;
        path.lineTo(currentX, currentY);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Floating Success Message
class FloatingSuccessMessage extends StatefulWidget {
  final String message;
  final VoidCallback? onComplete;
  
  const FloatingSuccessMessage({
    super.key,
    required this.message,
    this.onComplete,
  });

  @override
  State<FloatingSuccessMessage> createState() => _FloatingSuccessMessageState();
}

class _FloatingSuccessMessageState extends State<FloatingSuccessMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 100.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
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
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF00C853)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
