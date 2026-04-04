/// WayFinder 2.0 — Camera Screen
/// Egocentric video capture with real-time RynnBrain 2B analysis.
/// Sends short video clips to backend and renders 3D audio + spatial overlays.

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../providers/navigation_provider.dart';
import '../providers/safety_provider.dart';
import '../services/spatial_audio_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/threat_overlay.dart';
import '../widgets/audio_compass.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  String? _currentMode; // 'nav' | 'cop'

  late AnimationController _recordingPulse;
  Timer? _autoRecordTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recordingPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _initCamera();

    // Read mode from navigation arguments (set by HomeScreen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      _currentMode = args?['mode'] ?? 'nav';
    });
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.medium, // 720p — good balance for RynnBrain-2B
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingPulse.dispose();
    _autoRecordTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ─── Recording & Analysis ─────────────────────────────────────────────

  Future<void> _captureAndAnalyze() async {
    if (_isRecording || _isAnalyzing || _controller == null) return;

    setState(() => _isRecording = true);

    try {
      // Record 3-second clip
      await _controller!.startVideoRecording();
      await Future.delayed(const Duration(seconds: 3));
      final videoFile = await _controller!.stopVideoRecording();

      setState(() {
        _isRecording = false;
        _isAnalyzing = true;
      });

      // Immediate voice feedback
      final audio = SpatialAudioService();
      await audio.speak("Analyzing scene...");

      final file = File(videoFile.path);
      final navProvider = context.read<NavigationProvider>();
      final safetyProvider = context.read<SafetyProvider>();

      if (_currentMode == 'cop') {
        await safetyProvider.checkSafety(file);
      } else {
        await navProvider.analyzeVideoClip(file);
      }

    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      if (mounted) setState(() {
        _isRecording = false;
        _isAnalyzing = false;
      });
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isCameraReady && _controller != null)
            CameraPreview(_controller!)
          else
            _buildCameraPlaceholder(),

          // Dark vignette overlay
          _buildVignette(),

          // Spatial threat overlay (colored bounding boxes)
          const ThreatOverlay(),

          // UI Controls overlay
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const Spacer(),
                _buildAudioCompass(),
                const SizedBox(height: 16),
                _buildAnalysisResult(),
                const SizedBox(height: 20),
                _buildControls(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      color: AppTheme.surface,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.accentPrimary),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVignette() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.6),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final mode = _currentMode ?? 'nav';
    final modeLabel = mode == 'cop' ? 'Safety Mode · CoP' : 'Navigation · Nav';
    final modeColor = mode == 'cop' ? AppTheme.warning : AppTheme.accentPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: modeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: modeColor.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: modeColor,
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (c) => c.repeat())
                    .scale(end: const Offset(1.5, 1.5), duration: 800.ms)
                    .then()
                    .scale(end: const Offset(1, 1), duration: 800.ms),
                const SizedBox(width: 8),
                Text(
                  modeLabel,
                  style: TextStyle(
                    color: modeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Recording indicator
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.danger.withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record_rounded,
                      color: AppTheme.danger, size: 14),
                  SizedBox(width: 6),
                  Text('REC 3s',
                      style: TextStyle(
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ).animate().fadeIn(),
        ],
      ),
    );
  }

  Widget _buildAudioCompass() {
    return Consumer<NavigationProvider>(
      builder: (ctx, nav, _) {
        final cues = nav.lastResult?.audioCues ?? [];
        if (cues.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AudioCompass(cues: cues),
        );
      },
    );
  }

  Widget _buildAnalysisResult() {
    return Consumer<NavigationProvider>(
      builder: (ctx, nav, _) {
        if (nav.lastResult == null && !_isAnalyzing) return const SizedBox.shrink();

        if (_isAnalyzing) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentPrimary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'RynnBrain 2B analyzing...',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
              ),
            ).animate().fadeIn(),
          );
        }

        final result = nav.lastResult!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Action pill
                if (result.navigationAction != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.safe.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.safe.withOpacity(0.4)),
                    ),
                    child: Text(
                      result.navigationAction!.replaceAll('_', ' '),
                      style: const TextStyle(
                        color: AppTheme.safe,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),

                Text(
                  result.rawText.length > 150
                      ? '${result.rawText.substring(0, 150)}...'
                      : result.rawText,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.psychology_rounded,
                        size: 14, color: AppTheme.accentPrimary.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      '${(result.confidence * 100).toStringAsFixed(0)}% confidence',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
        );
      },
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Mode toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _currentMode = _currentMode == 'cop' ? 'nav' : 'cop';
              });
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Icon(
                _currentMode == 'cop'
                    ? Icons.navigation_rounded
                    : Icons.shield_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),

          // Main capture button (large, accessible)
          GestureDetector(
            onTap: _captureAndAnalyze,
            child: AnimatedBuilder(
              animation: _recordingPulse,
              builder: (ctx, child) {
                final isActive = _isRecording || _isAnalyzing;
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive ? AppTheme.dangerGradient : AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: (isActive ? AppTheme.danger : AppTheme.accentPrimary).withOpacity(
                            isActive ? 0.3 + _recordingPulse.value * 0.4 : 0.5),
                        blurRadius: isActive ? 20 + _recordingPulse.value * 20 : 20,
                        spreadRadius: isActive ? _recordingPulse.value * 8 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    isActive ? Icons.stop_rounded : Icons.videocam_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                );
              },
            ),
          ),

          // Gallery / image pick placeholder
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }
}
