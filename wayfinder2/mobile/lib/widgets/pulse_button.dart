/// WayFinder 2.0 — Status Indicator + Pulse Button Widgets

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';

/// Animated live status dot
class StatusIndicator extends StatelessWidget {
  final bool active;

  const StatusIndicator({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.accentPrimary : AppTheme.safe;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (active)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (c) => c.repeat())
              .scale(end: const Offset(1.6, 1.6), duration: 800.ms)
              .fadeOut(duration: 800.ms),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// Large accessible pulse button for voice activation
class PulseButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isActive;
  final IconData icon;
  final String label;

  const PulseButton({
    super.key,
    required this.onTap,
    required this.isActive,
    required this.icon,
    required this.label,
  });

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (ctx, child) {
            final pulse = widget.isActive ? _controller.value : 0.0;
            return Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.isActive
                    ? AppTheme.primaryGradient
                    : const LinearGradient(
                        colors: [AppTheme.surface, AppTheme.surfaceElevated]),
                boxShadow: [
                  BoxShadow(
                    color: widget.isActive
                        ? AppTheme.accentPrimary.withOpacity(0.2 + pulse * 0.4)
                        : Colors.transparent,
                    blurRadius: 20 + pulse * 20,
                    spreadRadius: pulse * 8,
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: widget.isActive ? Colors.white : AppTheme.textSecondary,
                size: 32,
              ),
            );
          },
        ),
      ),
    );
  }
}
