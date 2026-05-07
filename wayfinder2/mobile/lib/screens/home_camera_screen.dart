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
        'Экран камеры WayFinder. Нажмите центральную кнопку, чтобы проанализировать окружение. '
        'Нажмите на микрофон слева, чтобы задать вопрос, или скажите: Way Finder.',
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
          _audio.speak('Анализирую, двигайтесь осторожно.');
          announceToScreenReader('Высокая задержка сети. Анализирую, двигайтесь осторожно.');
        }
      };
    });
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _cameraState = CameraState.error);
        _audio.speak('Камера не найдена на этом устройстве.');
        announceToScreenReader('Камера недоступна.');
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
          _audio.speak('Доступ к камере запрещен. Пожалуйста, откройте настройки и разрешите доступ для WayFinder.');
          announceToScreenReader('Доступ к камере запрещен. Откройте настройки устройства.');
        } else {
          _audio.speak('Не удалось запустить камеру. Попробуйте еще раз.');
          announceToScreenReader('Ошибка камеры. Нажмите кнопку повтора.');
        }
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() => _cameraState = CameraState.error);
        _audio.speak('Не удалось запустить камеру.');
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
    announceToScreenReader('Записываю окружение. Пожалуйста, подождите.');

    try {
      // Immediate voice feedback
      _audio.speak('Анализирую...');

      // Record 3-second clip
      await _controller!.startVideoRecording();
      await Future.delayed(AppDurations.recordingLength);
      final videoFile = await _controller!.stopVideoRecording();

      HapticPatterns.recordingEnd();
      setState(() => _cameraState = CameraState.analyzing);
      announceToScreenReader('Обработка...');

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
        String spokenError = 'Произошла ошибка. Попробуйте еще раз.';
        if (e is CameraException) {
          spokenError = 'Ошибка камеры. Пожалуйста, попробуйте еще раз.';
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
                _buildStatusBar(),
                _buildAskButton(), // Large button for manual "Ask mode"
                const Spacer(),
                _buildAudioCompass(),
                const SizedBox(height: 12),
                _buildGuidanceCard(),
                const SizedBox(height: 20),
                _buildBottomControls(),
                const SizedBox(height: 32),
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
              ? 'Камера недоступна. Нажмите дважды, чтобы повторить.'
              : 'Камера загружается',
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
                isError ? 'Камера недоступна' : 'Инициализация камеры...',
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
                    child: const Text('Повторить',
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
              Colors.black.withOpacity(0.5),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
            stops: const [0.0, 0.2, 0.6, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final statusConfig = _getStatusConfig();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Semantics(
        liveRegion: true,
        label: 'Статус: ${statusConfig.text}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            border: Border.all(color: statusConfig.color.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status dot
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
    );
  }

  Widget _buildAskButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Semantics(
        button: true,
        label: 'Спросить WayFinder. Нажмите, чтобы задать вопрос голосом.',
        child: GestureDetector(
          onTap: () {
            HapticPatterns.success();
            _openAssistant();
          },
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accentPrimary.withOpacity(0.4),
                  AppTheme.accentPrimary.withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              border: Border.all(
                color: AppTheme.accentPrimary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentPrimary.withOpacity(0.8),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentPrimary.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_rounded, size: 56, color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Спросить\nWayFinder',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(
            duration: 2.seconds,
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.05, 1.05),
            curve: Curves.easeInOut,
          ),
      ),
    );
  }

  ({String text, Color color}) _getStatusConfig() {
    return switch (_cameraState) {
      CameraState.idle => (text: 'Готов', color: AppTheme.safe),
      CameraState.recording => (text: 'Слушаю...', color: AppTheme.danger),
      CameraState.analyzing => (text: 'Анализирую...', color: AppTheme.accentPrimary),
      CameraState.speaking => (text: 'Говорю...', color: AppTheme.accentTeal),
      CameraState.error => (text: 'Ошибка', color: AppTheme.danger),
      CameraState.offline => (text: 'Оффлайн', color: AppTheme.textMuted),
    };
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

  Widget _buildGuidanceCard() {
    return Consumer<NavigationProvider>(
      builder: (ctx, nav, _) {
        if (nav.lastResult == null && _cameraState != CameraState.analyzing) {
          return const SizedBox.shrink();
        }

        if (_cameraState == CameraState.analyzing) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
              child: Row(
                children: [
                  const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentPrimary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Анализирую окружение...',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        // Show error state from navigation provider
        if (nav.state == NavigationState.error && nav.errorMessage != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Semantics(
              liveRegion: true,
              label: nav.errorMessage,
              child: GlassCard(
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.danger, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        nav.errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Semantics(
            liveRegion: true,
            label: 'Указания по навигации: ${result.rawText}',
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Navigation action pill
                  if (result.navigationAction != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.safe.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: AppTheme.safe.withOpacity(0.4)),
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

                  // Guidance text
                  Text(
                    result.rawText.length > 140
                        ? '${result.rawText.substring(0, 140)}...'
                        : result.rawText,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 8),
                  // Confidence
                  Row(
                    children: [
                      Icon(Icons.psychology_rounded,
                          size: 14,
                          color: AppTheme.accentPrimary.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Уверенность: ${(result.confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
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

  Widget _buildBottomControls() {
    final isActive = _cameraState == CameraState.recording ||
        _cameraState == CameraState.analyzing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ─── Ask Button (left, 64×64) ────────────────
          Semantics(
            button: true,
            label: 'Задать вопрос о том, что вы видите',
            child: GestureDetector(
              onTap: isActive ? null : _openAssistant,
              child: Container(
                width: AppSizes.touchPrimary,
                height: AppSizes.touchPrimary,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.4)),
                ),
                child: const Icon(Icons.mic_rounded,
                    color: AppTheme.accentPrimary, size: 30),
              ),
            ),
          ),

          // ─── Main Navigate Button (center, 80×80) ────────────────
          Semantics(
            button: true,
            label: isActive
                ? 'Навигация активна. Пожалуйста, подождите.'
                : 'Проанализировать окружение. Нажмите, чтобы начать.',
            child: GestureDetector(
              onTap: isActive ? null : _captureAndAnalyze,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (ctx, child) {
                  final pulse = isActive ? _pulseController.value : 0.0;
                  return Container(
                    width: AppSizes.touchHero,
                    height: AppSizes.touchHero,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isActive
                          ? AppTheme.dangerGradient
                          : AppTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: (isActive
                                  ? AppTheme.danger
                                  : AppTheme.accentPrimary)
                              .withOpacity(
                                  isActive ? 0.3 + pulse * 0.4 : 0.4),
                          blurRadius: isActive ? 20 + pulse * 20 : 20,
                          spreadRadius: isActive ? pulse * 8 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      isActive
                          ? Icons.pending_rounded
                          : Icons.explore_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  );
                },
              ),
            ),
          ),

          // ─── Settings Button (right, 56×56) ────────────────
          Semantics(
            button: true,
            label: 'Открыть настройки',
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/settings'),
              child: Container(
                width: AppSizes.touchSecondary,
                height: AppSizes.touchSecondary,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(Icons.settings_rounded,
                    color: AppTheme.textSecondary, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
