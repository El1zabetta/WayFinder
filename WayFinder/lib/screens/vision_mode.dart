import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../widgets/glass_container.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ar_camera_overlay.dart';
import '../widgets/particle_effects.dart';
import 'dart:math' as math;

class VisionModeScreen extends StatefulWidget {
  final CameraController? cameraController;
  final String statusText;
  final bool isProcessing;
  final VoidCallback onScanTap;

  const VisionModeScreen({
    super.key,
    required this.cameraController,
    required this.statusText,
    required this.isProcessing,
    required this.onScanTap,
  });

  @override
  State<VisionModeScreen> createState() => _VisionModeScreenState();
}

class _VisionModeScreenState extends State<VisionModeScreen> with TickerProviderStateMixin {
  late AnimationController _scanLineController;
  late AnimationController _pulseController;
  late AnimationController _cornerController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _cornerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _pulseController.dispose();
    _cornerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameraController == null || !widget.cameraController!.value.isInitialized) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E27), Color(0xFF1A1F3A)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingAnimationWidget.hexagonDots(
                color: const Color(0xFF00E676),
                size: 60,
              ),
              const SizedBox(height: 20),
              const Text(
                'Initializing Vision System...',
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;

    var scale = 1.0;
    if (widget.cameraController != null && widget.cameraController!.value.isInitialized) {
      final size = MediaQuery.of(context).size;
      final deviceRatio = size.width / size.height;
      final cameraRatio = widget.cameraController!.value.aspectRatio;
      scale = 1 / (cameraRatio * deviceRatio);
      if (scale < 1) scale = 1 / scale;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Camera Feed with Vignette Effect
        Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Center(
            child: CameraPreview(widget.cameraController!),
          ),
        ),

        // AR Overlay with smart detections
        ARCameraOverlay(
          cameraSize: MediaQuery.of(context).size,
          detections: [
            if (widget.statusText.contains('door'))
              DetectionBox(
                rect: const Rect.fromLTWH(100, 200, 200, 300),
                label: 'DOOR',
                confidence: 0.98,
                color: const Color(0xFF00E676),
              ),
            if (widget.statusText.contains('person') || widget.statusText.contains('человек'))
              DetectionBox(
                rect: const Rect.fromLTWH(150, 100, 150, 400),
                label: 'PERSON',
                confidence: 0.95,
                color: const Color(0xFF00D4FF),
              ),
          ],
          showGrid: true,
          showCrosshair: true,
        ),

        // Matrix Rain on top when processing
        if (widget.isProcessing)
          const MatrixRain(
            opacity: 0.2,
            color: Color(0xFF00E676),
          ),

        // Vignette overlay
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.6),
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
        ),

        // 2. Animated Corner Brackets (Cyberpunk style)
        _buildAnimatedCorner(top: 60, left: 30, rotation: 0),
        _buildAnimatedCorner(top: 60, right: 30, rotation: math.pi / 2),
        _buildAnimatedCorner(bottom: 180, left: 30, rotation: -math.pi / 2),
        _buildAnimatedCorner(bottom: 180, right: 30, rotation: math.pi),

        // 3. Scanning Line Animation (when processing)
        if (widget.isProcessing)
          AnimatedBuilder(
            animation: _scanLineController,
            builder: (context, child) {
              return Positioned(
                top: 60 + (_scanLineController.value * (MediaQuery.of(context).size.height - 240)),
                left: 30,
                right: 30,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF00E676).withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        // 4. Central Loading Animation
        if (widget.isProcessing)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse ring
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 120 + (_pulseController.value * 40),
                          height: 120 + (_pulseController.value * 40),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00E676).withOpacity(0.3 - (_pulseController.value * 0.3)),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    ),
                    // Inner rotating arc
                    LoadingAnimationWidget.staggeredDotsWave(
                      color: const Color(0xFF00E676),
                      size: 80,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E676).withOpacity(0.5)),
                  ),
                  child: const Text(
                    'ANALYZING...',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // 5. Premium Status Panel
        Positioned(
          bottom: 160,
          left: 20,
          right: 20,
          child: AnimatedOpacity(
            opacity: widget.statusText.isNotEmpty ? 1.0 : 0.7,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E1E24).withOpacity(0.9),
                    const Color(0xFF2A2A35).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF00E676).withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.remove_red_eye,
                          color: Color(0xFF00E676),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'VISION AI',
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  if (widget.statusText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFF00E676).withOpacity(0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.statusText.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 1.2,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // 6. Top Info Bar
        Positioned(
          top: 50,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00E676).withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'NAVIGATOR MODE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedCorner({double? top, double? bottom, double? left, double? right, required double rotation}) {
    return AnimatedBuilder(
      animation: _cornerController,
      builder: (context, child) {
        final opacity = (0.5 + (0.5 * math.sin(_cornerController.value * 2 * math.pi))).clamp(0.0, 1.0);
        
        return Positioned(
          top: top,
          bottom: bottom,
          left: left,
          right: right,
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF00E676).withOpacity(opacity),
                    width: 3,
                  ),
                  left: BorderSide(
                    color: const Color(0xFF00E676).withOpacity(opacity),
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
