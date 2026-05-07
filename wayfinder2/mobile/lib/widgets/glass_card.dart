/// WayFinder 2.0 — Glass Card Widget
library;
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glassBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentPrimary.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
