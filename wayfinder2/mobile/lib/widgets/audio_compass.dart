/// WayFinder 2.0 — Audio Compass Widget
/// Visual representation of 3D spatial audio cues on a horizontal compass arc.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/api_client.dart';

class AudioCompass extends StatelessWidget {
  final List<AudioCue> cues;

  const AudioCompass({super.key, required this.cues});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: CustomPaint(
        painter: _CompassPainter(cues),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Text('L', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              Text('CENTER', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              Text('R', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final List<AudioCue> cues;
  _CompassPainter(this.cues);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Center line
    final centerPaint = Paint()
      ..color = AppTheme.textMuted.withOpacity(0.3)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(center.dx, 10), Offset(center.dx, size.height - 10), centerPaint);

    // Arc
    final arcPaint = Paint()
      ..color = AppTheme.accentPrimary.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCenter(center: center, width: size.width * 0.95, height: size.height * 1.5),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      arcPaint,
    );

    // Draw each audio cue as a dot
    for (final cue in cues) {
      final t = (cue.azimuth + 90) / 180; // map -90..+90 → 0..1
      final x = size.width * t.clamp(0.0, 1.0);
      final y = center.dy;

      final color = switch (cue.priority) {
        'HIGH' || 'CRITICAL' => AppTheme.danger,
        'MEDIUM' => AppTheme.warning,
        _ => AppTheme.safe,
      };

      final dotPaint = Paint()..color = color;
      canvas.drawCircle(Offset(x, y), 6, dotPaint);

      // Glow
      canvas.drawCircle(
        Offset(x, y),
        12,
        Paint()
          ..color = color.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.cues != cues;
}
