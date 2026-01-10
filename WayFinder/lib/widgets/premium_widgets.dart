import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Premium Loading Widget with Shimmer Effect
class PremiumLoadingWidget extends StatelessWidget {
  final String? message;
  final bool showMessage;
  
  const PremiumLoadingWidget({
    super.key,
    this.message,
    this.showMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated gradient circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D4FF),
                  const Color(0xFF00E676),
                  const Color(0xFFFF2E63),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0A0E27),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
          ),
          
          if (showMessage) ...[
            const SizedBox(height: 24),
            Shimmer.fromColors(
              baseColor: Colors.white54,
              highlightColor: Colors.white,
              child: Text(
                message ?? 'Processing...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmer Loading Card
class ShimmerLoadingCard extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  
  const ShimmerLoadingCard({
    super.key,
    this.height = 100,
    this.width,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white10,
      highlightColor: Colors.white24,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Pulsing Microphone Animation
class PulsingMicAnimation extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onTap;
  
  const PulsingMicAnimation({
    super.key,
    required this.isActive,
    this.onTap,
  });

  @override
  State<PulsingMicAnimation> createState() => _PulsingMicAnimationState();
}

class _PulsingMicAnimationState extends State<PulsingMicAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(PulsingMicAnimation oldWidget) {
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
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing rings
          if (widget.isActive)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 70 * _scaleAnimation.value,
                  height: 70 * _scaleAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF2E63).withOpacity(_opacityAnimation.value),
                      width: 3,
                    ),
                  ),
                );
              },
            ),
          
          // Main button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: widget.isActive ? const Color(0xFFFF2E63) : const Color(0xFF00D4FF),
              borderRadius: BorderRadius.circular(widget.isActive ? 8 : 35),
              boxShadow: [
                BoxShadow(
                  color: (widget.isActive ? const Color(0xFFFF2E63) : const Color(0xFF00D4FF))
                      .withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: widget.isActive ? 3 : 0,
                ),
              ],
            ),
            child: Icon(
              widget.isActive ? Icons.stop_rounded : Icons.mic,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}
