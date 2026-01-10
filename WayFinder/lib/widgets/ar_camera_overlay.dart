import 'package:flutter/material.dart';
import 'dart:math' as math;

/// AR Camera Overlay with Detection Boxes
class ARCameraOverlay extends StatefulWidget {
  final List<DetectionBox> detections;
  final Size cameraSize;
  final bool showGrid;
  final bool showCrosshair;
  
  const ARCameraOverlay({
    super.key,
    required this.detections,
    required this.cameraSize,
    this.showGrid = true,
    this.showCrosshair = true,
  });

  @override
  State<ARCameraOverlay> createState() => _ARCameraOverlayState();
}

class _ARCameraOverlayState extends State<ARCameraOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
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
        // Grid overlay
        if (widget.showGrid)
          CustomPaint(
            size: widget.cameraSize,
            painter: GridPainter(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        
        // Crosshair
        if (widget.showCrosshair)
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(60, 60),
                  painter: CrosshairPainter(
                    progress: _controller.value,
                    color: const Color(0xFF00D4FF),
                  ),
                );
              },
            ),
          ),
        
        // Detection boxes
        ...widget.detections.map((detection) => 
          Positioned(
            left: detection.rect.left,
            top: detection.rect.top,
            width: detection.rect.width,
            height: detection.rect.height,
            child: AnimatedDetectionBox(detection: detection),
          ),
        ),
        
        // Corner indicators
        _buildCornerIndicators(),
        
        // Scan line effect
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: widget.cameraSize,
              painter: ScanLinePainter(
                progress: _controller.value,
                color: const Color(0xFF00E676),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCornerIndicators() {
    const size = 30.0;
    const thickness = 3.0;
    const color = Color(0xFF00D4FF);
    
    return Stack(
      children: [
        // Top-left
        Positioned(
          top: 20,
          left: 20,
          child: _buildCorner(color, size, thickness, [true, false, false, true]),
        ),
        // Top-right
        Positioned(
          top: 20,
          right: 20,
          child: _buildCorner(color, size, thickness, [true, true, false, false]),
        ),
        // Bottom-left
        Positioned(
          bottom: 20,
          left: 20,
          child: _buildCorner(color, size, thickness, [false, false, true, true]),
        ),
        // Bottom-right
        Positioned(
          bottom: 20,
          right: 20,
          child: _buildCorner(color, size, thickness, [false, true, true, false]),
        ),
      ],
    );
  }

  Widget _buildCorner(Color color, double size, double thickness, List<bool> sides) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: CornerPainter(
          color: color,
          thickness: thickness,
          top: sides[0],
          right: sides[1],
          bottom: sides[2],
          left: sides[3],
        ),
      ),
    );
  }
}

class DetectionBox {
  final Rect rect;
  final String label;
  final double confidence;
  final Color color;

  DetectionBox({
    required this.rect,
    required this.label,
    required this.confidence,
    this.color = const Color(0xFF00D4FF),
  });
}

class AnimatedDetectionBox extends StatefulWidget {
  final DetectionBox detection;
  
  const AnimatedDetectionBox({
    super.key,
    required this.detection,
  });

  @override
  State<AnimatedDetectionBox> createState() => _AnimatedDetectionBoxState();
}

class _AnimatedDetectionBoxState extends State<AnimatedDetectionBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();
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
        return Opacity(
          opacity: _controller.value,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.detection.color,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // Label background
                Positioned(
                  top: -25,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.detection.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${widget.detection.label} ${(widget.detection.confidence * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                // Corner markers
                ...List.generate(4, (index) {
                  final positions = [
                    const Alignment(-1, -1), // Top-left
                    const Alignment(1, -1),  // Top-right
                    const Alignment(-1, 1),  // Bottom-left
                    const Alignment(1, 1),   // Bottom-right
                  ];
                  
                  return Align(
                    alignment: positions[index],
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: widget.detection.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const divisions = 6;
    final cellWidth = size.width / divisions;
    final cellHeight = size.height / divisions;

    // Vertical lines
    for (int i = 1; i < divisions; i++) {
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(i * cellWidth, size.height),
        paint,
      );
    }

    // Horizontal lines
    for (int i = 1; i < divisions; i++) {
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(size.width, i * cellHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}

class CrosshairPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  CrosshairPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer circle
    canvas.drawCircle(center, radius, paint);

    // Inner pulsing circle
    final pulseRadius = radius * 0.3 * (1 + math.sin(progress * 2 * math.pi) * 0.2);
    canvas.drawCircle(center, pulseRadius, paint);

    // Crosshair lines
    const lineLength = 15.0;
    canvas.drawLine(
      Offset(center.dx - lineLength, center.dy),
      Offset(center.dx + lineLength, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - lineLength),
      Offset(center.dx, center.dy + lineLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(CrosshairPainter oldDelegate) => true;
}

class ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;
  
  ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0),
          color.withOpacity(0.5),
          color.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 3));

    final y = size.height * progress;
    canvas.drawRect(
      Rect.fromLTWH(0, y, size.width, 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(ScanLinePainter oldDelegate) => true;
}

class CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool top;
  final bool right;
  final bool bottom;
  final bool left;
  
  CornerPainter({
    required this.color,
    required this.thickness,
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    if (top && left) {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
    } else if (top && right) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (bottom && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else if (bottom && right) {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CornerPainter oldDelegate) => false;
}

/// HUD Info Display
class HUDInfoDisplay extends StatelessWidget {
  final String? distance;
  final String? direction;
  final int? objectCount;
  final double? batteryLevel;
  
  const HUDInfoDisplay({
    super.key,
    this.distance,
    this.direction,
    this.objectCount,
    this.batteryLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (objectCount != null)
            _buildHUDItem(
              Icons.visibility,
              '$objectCount objects',
              const Color(0xFF00D4FF),
            ),
          
          if (distance != null)
            _buildHUDItem(
              Icons.straighten,
              distance!,
              const Color(0xFF00E676),
            ),
          
          if (direction != null)
            _buildHUDItem(
              Icons.navigation,
              direction!,
              const Color(0xFFFFB800),
            ),
          
          if (batteryLevel != null)
            _buildHUDItem(
              Icons.battery_charging_full,
              '${(batteryLevel! * 100).toInt()}%',
              const Color(0xFF4CAF50),
            ),
        ],
      ),
    );
  }

  Widget _buildHUDItem(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
