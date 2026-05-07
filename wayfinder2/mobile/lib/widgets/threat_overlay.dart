/// WayFinder 2.0 — Threat Overlay Widget
/// Draws colored bounding boxes over camera preview for detected threats.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../providers/safety_provider.dart';

class ThreatOverlay extends StatelessWidget {
  const ThreatOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SafetyProvider>(
      builder: (ctx, safety, _) {
        if (safety.threats.isEmpty) return const SizedBox.shrink();

        return CustomPaint(
          painter: _ThreatPainter(safety.threats),
        );
      },
    );
  }
}

class _ThreatPainter extends CustomPainter {
  final List threats;
  _ThreatPainter(this.threats);

  @override
  void paint(Canvas canvas, Size size) {
    for (final threat in threats) {
      final bbox = (threat.bbox as List<double>);
      if (bbox.length < 4) continue;

      // RynnBrain coords are normalized 0-1000, map to screen
      final left = bbox[0] / 1000 * size.width;
      final top = bbox[1] / 1000 * size.height;
      final right = bbox[2] / 1000 * size.width;
      final bottom = bbox[3] / 1000 * size.height;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      // Red bounding box
      canvas.drawRect(
        rect,
        Paint()
          ..color = AppTheme.danger.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      // Semi-transparent fill
      canvas.drawRect(
        rect,
        Paint()
          ..color = AppTheme.danger.withOpacity(0.08),
      );

      // Warning label
      const textStyle = TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        backgroundColor: Color(0xAAFF4444),
      );
      final tp = TextPainter(
        text: const TextSpan(text: '⚠ ПРЕПЯТСТВИЕ', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left + 4, top + 4));
    }
  }

  @override
  bool shouldRepaint(_ThreatPainter old) => old.threats != threats;
}
