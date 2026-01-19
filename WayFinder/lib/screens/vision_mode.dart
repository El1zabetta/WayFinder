import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../widgets/glass_container.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ar_camera_overlay.dart';

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

class _VisionModeScreenState extends State<VisionModeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
        // 1. Camera Feed
        Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Center(
            child: CameraPreview(widget.cameraController!),
          ),
        ),

        // AR Overlay - Minimal (Detection Boxes Only)
        ARCameraOverlay(
          cameraSize: MediaQuery.of(context).size,
          detections: [
            if (widget.statusText.contains('door'))
              DetectionBox(
                rect: const Rect.fromLTWH(100, 200, 200, 300),
                label: 'DOOR',
                confidence: 0.98,
                color: Colors.white, // Neutral color
              ),
          ],
          showGrid: false,     // Removed grid
          showCrosshair: false, // Removed crosshair
        ),

        // Central Loading Animation - Cleaner
        if (widget.isProcessing)
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Status Text - Minimal at bottom
        if (widget.statusText.isNotEmpty)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Removed unused helper methods and animations
}
