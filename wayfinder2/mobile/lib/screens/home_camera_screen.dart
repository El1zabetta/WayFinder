/// WayFinder 3.0 — Home Camera Screen ⭐
/// The operational center of the app.
/// Camera-first, voice-first, accessibility-first.
///
/// States: IDLE → RECORDING → ANALYZING → SPEAKING → IDLE
///
/// Primary actions:
///   1. Navigate (center, 80×80) — record + analyze
///   2. Ask (left, 64×64) — opens Ask Assistant sheet
///   3. Settings (right, 56×56)

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/accessibility.dart';
import '../core/constants.dart';
import '../providers/assistant_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/safety_provider.dart';
import '../services/spatial_audio_service.dart';
import '../services/frame_streaming_service.dart';
import '../services/wakeword_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/threat_overlay.dart';
import '../widgets/audio_compass.dart';
import 'ask_assistant_sheet.dart';

enum CameraState { idle, recording, analyzing, speaking, error, offline }

class HomeCameraScreen extends StatefulWidget {
  const HomeCameraScreen({super.key});

  @override
  State<HomeCameraScreen> createState() => _HomeCameraScreenState();
}

class _HomeCameraScreenState extends State<HomeCameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  CameraState _cameraState = CameraState.idle;

  late AnimationController _pulseController;
  final SpatialAudioService _audio = SpatialAudioService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _initCamera();

    // Announce screen to screen reader
    WidgetsBinding.instance.addPostFrameCallback((_) {
      announceToScreenReader(
        'WayFinder Camera Screen. Tap the central button to analyze surroundings. '
        'Tap the mic on the left to ask a question, or say: Way Finder.',
      );

      final wakeword = context.read<WakewordService>();
      wakeword.onWakewordDetected = () {
        if (_cameraState == CameraState.idle) {
          final assistant = context.read<AssistantProvider>();
          assistant.setWakeWordDetected();
          _openAssistant();
        }
      };
      wakeword.startListening();

      final streamer = context.read<FrameStreamingService>();
      streamer.connect();
      streamer.onLatencyChanged = (isHigh) {
        if (isHigh && _cameraState == CameraState.idle) {
          _audio.speak('Analyzing, move carefully.');
          announceToScreenReader('High network latency. Analyzing, move carefully.');
        }
      };
    });
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _cameraState = CameraState.error);
        _audio.speak('Camera not found on this device.');
        announceToScreenReader('Camera unavailable.');
        return;
      }

      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } on CameraException catch (e) {
      debugPrint('Camera permission/init error: $e');
      if (mounted) {
        setState(() => _cameraState = CameraState.error);
        if (e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt' || e.code == 'CameraAccessRestricted') {
          _audio.speak('Camera access denied. Please open settings and allow access for WayFinder.');
          announceToScreenReader('Camera access denied. Open device settings.');
        } else {
          _audio.speak('Failed to start camera. Please try again.');
          announceToScreenReader('Camera error. Tap retry button.');
        }
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() => _cameraState = CameraState.error);
        _audio.speak('Failed to start camera.');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Stop wakeword listening when screen disposed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<WakewordService>().stopListening();
    });

    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final wakeword = context.read<WakewordService>();
    
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      wakeword.stopListening();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
      wakeword.startListening();
    }
  }

  // ─── Core Action: Record + Analyze ──────────────────────────────────────

  Future<void> _captureAndAnalyze() async {
    if (_cameraState != CameraState.idle || _controller == null) return;

    setState(() => _cameraState = CameraState.recording);
    HapticPatterns.recordingStart();
    announceToScreenReader('Recording surroundings. Please wait.');

    try {
      // Immediate voice feedback
      _audio.speak('Analyzing...');

      // Record 3-second clip
      await _controller!.startVideoRecording();
      await Future.delayed(AppDurations.recordingLength);
      final videoFile = await _controller!.stopVideoRecording();

      HapticPatterns.recordingEnd();
      setState(() => _cameraState = CameraState.analyzing);
      announceToScreenReader('Processing...');

      // Send to backend
      final file = File(videoFile.path);
      final navProvider = context.read<NavigationProvider>();
      await navProvider.analyzeVideoClip(file);

      setState(() => _cameraState = CameraState.speaking);

      // Haptic feedback for threats
      if (navProvider.lastResult != null && navProvider.lastResult!.hasThreats) {
        HapticPatterns.threatDetected();
      } else {
        HapticPatterns.success();
      }

      // Wait a moment for TTS to begin, then return to idle
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _cameraState = CameraState.idle);

      // Clean up temp file
      try { file.deleteSync(); } catch (_) {}

    } catch (e) {
      debugPrint('Capture error: $e');
      HapticPatterns.error();
      if (mounted) {
        setState(() => _cameraState = CameraState.error);

        // Determine user-friendly message
        String spokenError = 'An error occurred. Please try again.';
        if (e is CameraException) {
          spokenError = 'Camera error. Please try again.';
        }
        
        // NavigationProvider already speaks its own error via TTS,
        // so only speak for camera-level errors here
        final nav = context.read<NavigationProvider>();
        if (nav.state != NavigationState.error) {
          _audio.speak(spokenError);
        }
        announceToScreenReader(spokenError);

        // Auto-recover after 4 seconds
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _cameraState = CameraState.idle);
        });
      }
    }
  }

  void _openAssistant() {
    HapticPatterns.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AskAssistantSheet(
        cameraController: _controller,
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview (full screen)
          if (_isCameraReady && _controller != null)
            CameraPreview(_controller!)
          else
            _buildCameraPlaceholder(),

          // Subtle vignette for readability
          _buildVignette(),

          // Threat overlay
          const ThreatOverlay(),

          // All controls
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 12),
                _buildAudioCompass(),
                _buildGuidanceCard(),
                const Spacer(),
                _buildMainArea(),
                const SizedBox(height: 16),
                _buildSafetyArea(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    final isError = _cameraState == CameraState.error;
    return Container(
      color: AppTheme.background,
      child: Center(
        child: Semantics(
          label: isError
              ? 'Camera unavailable. Double tap to retry.'
              : 'Camera loading',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isError)
                const Icon(Icons.videocam_off_rounded,
                    size: 48, color: AppTheme.textMuted)
              else
                const CircularProgressIndicator(color: AppTheme.accentPrimary),
              const SizedBox(height: 16),
              Text(
                isError ? 'Camera unavailable' : 'Initializing camera...',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 16),
              ),
              if (isError) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    HapticPatterns.tap();
                    setState(() => _cameraState = CameraState.idle);
                    _initCamera();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.accentPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('Retry',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVignette() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
            stops: const [0.0, 0.2, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  // ─── TOP BAR (Status & Small Actions) ──────────────────────────────────
  Widget _buildTopBar() {
    final statusConfig = _getStatusConfig();
    final wakeword = context.watch<WakewordService>();
    final isWakewordActive = wakeword.isListening;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: App Status & Wakeword Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  label: 'App Status: ${statusConfig.text}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusConfig.color.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusConfig.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusConfig.text,
                          style: TextStyle(
                            color: statusConfig.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  label: 'Wake word: ${isWakewordActive ? "Enabled" : "Disabled"}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isWakewordActive ? AppTheme.safe : AppTheme.textMuted).withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isWakewordActive ? Icons.mic_rounded : Icons.mic_off_rounded,
                          color: isWakewordActive ? AppTheme.safe : AppTheme.textMuted,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Wake word: ${isWakewordActive ? "On" : "Off"}',
                          style: TextStyle(
                            color: isWakewordActive ? AppTheme.safe : AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Right: Small Accessible Actions
          Column(
            children: [
              Semantics(
                button: true,
                label: 'System Status',
                hint: 'Check server and AI status',
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/system_status'),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: AppTheme.textSecondary, size: 24),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'Settings',
                hint: 'Open profile settings',
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.settings_rounded, color: AppTheme.textSecondary, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ({String text, Color color}) _getStatusConfig() {
    return switch (_cameraState) {
      CameraState.idle => (text: 'Ready', color: AppTheme.safe),
      CameraState.recording => (text: 'Listening...', color: AppTheme.danger),
      CameraState.analyzing => (text: 'Analyzing...', color: AppTheme.accentPrimary),
      CameraState.speaking => (text: 'Speaking...', color: AppTheme.accentTeal),
      CameraState.error => (text: 'Error', color: AppTheme.danger),
      CameraState.offline => (text: 'Offline', color: AppTheme.textMuted),
    };
  }

  Widget _buildAudioCompass() {
    return Consumer<NavigationProvider>(
      builder: (ctx, nav, _) {
        final cues = nav.lastResult?.audioCues ?? [];
        if (cues.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AudioCompass(cues: cues),
        );
      },
    );
  }

  Widget _buildGuidanceCard() {
    return Consumer<NavigationProvider>(
      builder: (ctx, nav, _) {
        if (nav.lastResult == null && _cameraState != CameraState.analyzing) {
          return const SizedBox.shrink();
        }

        if (_cameraState == CameraState.analyzing) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              child: Row(
                children: [
                  const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentPrimary),
                  ),
                  const SizedBox(width: 14),
                  Text('Analyzing surroundings...', style: Theme.of(ctx).textTheme.bodyMedium),
                ],
              ),
            ),
          );
        }

        if (nav.state == NavigationState.error && nav.errorMessage != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              liveRegion: true,
              label: nav.errorMessage,
              child: GlassCard(
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        nav.errorMessage!,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final result = nav.lastResult!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(
            liveRegion: true,
            label: 'Navigation guidance: ${result.rawText}',
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
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
                        style: const TextStyle(color: AppTheme.safe, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  Text(
                    result.rawText.length > 140 ? '${result.rawText.substring(0, 140)}...' : result.rawText,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.psychology_rounded, size: 14, color: AppTheme.accentPrimary.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Confidence: ${(result.confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.05),
          ),
        );
      },
    );
  }

  // ─── MAIN AREA (Massive Ask & Analyze Buttons) ─────────────────────────
  Widget _buildMainArea() {
    final isActive = _cameraState == CameraState.recording || _cameraState == CameraState.analyzing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Massive Ask Button
          Semantics(
            button: true,
            label: 'Ask WayFinder',
            hint: 'Ask a question with voice',
            child: GestureDetector(
              onTap: isActive ? null : _openAssistant,
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppTheme.accentPrimary.withOpacity(0.4), blurRadius: 15, spreadRadius: 2),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_rounded, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Text(
                      'Ask WayFinder',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Massive Analyze Button
          Semantics(
            button: true,
            label: 'Analyze Surroundings',
            hint: isActive ? 'Navigation active. Please wait.' : 'Get description of surroundings and obstacles',
            child: GestureDetector(
              onTap: isActive ? null : _captureAndAnalyze,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (ctx, child) {
                  final pulse = isActive ? _pulseController.value : 0.0;
                  return Container(
                    width: double.infinity,
                    height: 100,
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.danger.withOpacity(0.9) : AppTheme.safe.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (isActive ? AppTheme.danger : AppTheme.safe).withOpacity(0.3 + pulse * 0.4),
                          blurRadius: isActive ? 15 + pulse * 10 : 15,
                          spreadRadius: isActive ? pulse * 5 : 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isActive ? Icons.pending_rounded : Icons.explore_rounded, color: Colors.white, size: 40),
                        const SizedBox(width: 16),
                        Text(
                          isActive ? 'Analyzing...' : 'Analyze Surroundings',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SAFETY AREA (Stop & Repeat Buttons) ───────────────────────────────
  Widget _buildSafetyArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Stop Speaking Button
          Expanded(
            child: Semantics(
              button: true,
              label: 'Stop Speaking',
              hint: 'Immediately interrupt current voice message',
              child: GestureDetector(
                onTap: () {
                  HapticPatterns.tap();
                  _audio.stop();
                },
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.6), width: 2),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop_circle_rounded, color: AppTheme.danger, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Stop',
                        style: TextStyle(color: AppTheme.danger, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Repeat Button
          Expanded(
            child: Semantics(
              button: true,
              label: 'Repeat',
              hint: 'Repeat last message',
              child: GestureDetector(
                onTap: () {
                  HapticPatterns.tap();
                  final nav = context.read<NavigationProvider>();
                  if (nav.lastResult != null) {
                    _audio.speakAnalysis(nav.lastResult!.rawText);
                  } else {
                    final assistant = context.read<AssistantProvider>();
                    if (assistant.answer.isNotEmpty) {
                      assistant.repeatAnswer();
                    } else {
                      _audio.speak('No messages to repeat.');
                    }
                  }
                },
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.textSecondary.withOpacity(0.6), width: 2),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.replay_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Repeat',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

