// WayFinder 3.0 — Ask Assistant Sheet
// Voice-first Q&A overlay. Camera stays live behind.
//
// Flow: tap mic → STT listens → live transcript → auto-submit → /ask → TTS answer
// Keyboard fallback only if STT is unavailable on the device.
//
// Primary action: Large mic button (80px, bottom-center)
// Secondary: Repeat answer, Ask again, Close

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/accessibility.dart';
import '../core/constants.dart';
import '../providers/assistant_provider.dart';
import '../services/stt_service.dart';

class AskAssistantSheet extends StatefulWidget {
  final CameraController? cameraController;

  const AskAssistantSheet({
    super.key,
    this.cameraController,
  });

  @override
  State<AskAssistantSheet> createState() => _AskAssistantSheetState();
}

class _AskAssistantSheetState extends State<AskAssistantSheet> {
  final SttService _stt = SttService();

  bool _sttAvailable = false;
  bool _isListening = false;
  String _liveTranscript = '';

  // Keyboard fallback — only shown when STT is physically unavailable
  final TextEditingController _textController = TextEditingController();
  bool _showKeyboardFallback = false;

  @override
  void initState() {
    super.initState();
    _initStt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      announceToScreenReader(
        'Ask assistant opened. Tap the microphone to ask a question about what you see.',
      );
    });
  }

  Future<void> _initStt() async {
    final available = await _stt.init();
    if (mounted) {
      setState(() {
        _sttAvailable = available;
        _showKeyboardFallback = !available;
      });
      if (!available) {
        announceToScreenReader(
          'Voice recognition is not available on this device. You can type your question instead.',
        );
      }
    }
  }

  @override
  void dispose() {
    _stt.cancelListening();
    _textController.dispose();
    super.dispose();
  }

  // ─── STT Lifecycle ─────────────────────────────────────────────────────

  Future<void> _startListening() async {
    HapticPatterns.tap();

    // If STT is unavailable, show keyboard
    if (!_sttAvailable) {
      setState(() => _showKeyboardFallback = true);
      announceToScreenReader('Type your question.');
      return;
    }

    setState(() {
      _isListening = true;
      _liveTranscript = '';
    });
    announceToScreenReader('Listening. Speak your question now.');

    final started = await _stt.startListening(
      onResult: _onSttResult,
      onDone: _onSttDone,
      onError: _onSttError,
      listenForSeconds: 15,
    );

    if (!started && mounted) {
      setState(() => _isListening = false);
      announceToScreenReader('Could not start voice recognition. Try typing instead.');
      setState(() => _showKeyboardFallback = true);
    }
  }

  Future<void> _stopListening() async {
    HapticPatterns.tap();
    await _stt.stopListening();
    // _onSttDone will be called by the service
  }

  void _cancelListening() {
    HapticPatterns.tap();
    _stt.cancelListening();
    setState(() {
      _isListening = false;
      _liveTranscript = '';
    });
    announceToScreenReader('Listening cancelled.');
  }

  void _onSttResult(String text, bool isFinal) {
    if (!mounted) return;
    setState(() => _liveTranscript = text);
  }

  void _onSttDone() {
    if (!mounted) return;
    setState(() => _isListening = false);

    final transcript = _liveTranscript.trim();
    if (transcript.isEmpty) {
      announceToScreenReader("I didn't hear anything. Tap the microphone to try again.");
      HapticPatterns.error();
      return;
    }

    // Auto-submit the recognized speech
    announceToScreenReader('Got it. Processing your question.');
    _sendQuestion(transcript);
  }

  void _onSttError(String errorMsg) {
    if (!mounted) return;
    setState(() => _isListening = false);
    announceToScreenReader("Voice recognition error. Tap the microphone to try again.");
    HapticPatterns.error();
  }

  // ─── Question Submission ───────────────────────────────────────────────

  Future<void> _sendQuestion(String question) async {
    if (question.trim().isEmpty) return;

    setState(() {
      _isListening = false;
      _liveTranscript = question;
    });

    final provider = context.read<AssistantProvider>();

    // Capture current frame for visual context
    File? imageFile;
    if (widget.cameraController != null &&
        widget.cameraController!.value.isInitialized) {
      try {
        final xFile = await widget.cameraController!.takePicture();
        imageFile = File(xFile.path);
      } catch (_) {}
    }

    await provider.askQuestion(
      question,
      imageFile: imageFile,
    );

    // Clean up temp image
    if (imageFile != null) {
      try {
        imageFile.deleteSync();
      } catch (_) {}
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<AssistantProvider>(
      builder: (ctx, assistant, _) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: AppTheme.glassBorder),
                  left: BorderSide(color: AppTheme.glassBorder),
                  right: BorderSide(color: AppTheme.glassBorder),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Semantics(
                    header: true,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Text(
                        'Ask about what you see',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Content area (scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Listening indicator
                          if (_isListening) _buildListeningIndicator(),
                          // Transcript area
                          _buildTranscriptArea(assistant),
                          const SizedBox(height: 16),
                          // Answer area
                          _buildAnswerArea(assistant),
                          const SizedBox(height: 16),
                          // Action buttons (Repeat / Ask Again)
                          if (assistant.state == AssistantState.done)
                            _buildActionButtons(assistant),
                        ],
                      ),
                    ),
                  ),

                  // Keyboard fallback — ONLY when STT is unavailable
                  if (_showKeyboardFallback && !_sttAvailable)
                    _buildKeyboardFallback(),

                  // Bottom: Mic button + Close
                  _buildBottomControls(assistant),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Listening Indicator ───────────────────────────────────────────────

  Widget _buildListeningIndicator() {
    return Semantics(
      liveRegion: true,
      label: 'Listening for your voice',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentPrimary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppTheme.danger,
                shape: BoxShape.circle,
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(duration: 600.ms)
                .then()
                .fadeOut(duration: 600.ms),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _liveTranscript.isNotEmpty
                    ? _liveTranscript
                    : 'Listening... speak now',
                style: TextStyle(
                  color: _liveTranscript.isNotEmpty
                      ? AppTheme.textPrimary
                      : AppTheme.textMuted,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Transcript Area ───────────────────────────────────────────────────

  Widget _buildTranscriptArea(AssistantProvider assistant) {
    final question = assistant.transcript.isNotEmpty
        ? assistant.transcript
        : _liveTranscript;

    if (question.isEmpty &&
        assistant.state == AssistantState.idle &&
        !_isListening) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.glassBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Text(
          _sttAvailable
              ? 'Tap the microphone and speak your question.\nFor example: "What is in front of me?"'
              : 'Voice recognition is not available.\nType your question below.',
          style: const TextStyle(
              color: AppTheme.textMuted, fontSize: 14, height: 1.5),
        ),
      );
    }

    if (question.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your question:',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            question,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Answer Area ───────────────────────────────────────────────────────

  Widget _buildAnswerArea(AssistantProvider assistant) {
    if (assistant.state == AssistantState.processing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.glassBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accentPrimary,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Thinking...',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (assistant.answer.isEmpty) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      label: 'Answer: ${assistant.answer}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.safe.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.safe.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy_outlined,
                    size: 16, color: AppTheme.safe.withOpacity(0.8)),
                const SizedBox(width: 6),
                const Text(
                  'WayFinder',
                  style: TextStyle(
                    color: AppTheme.safe,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              assistant.answer,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            if (assistant.confidence > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${(assistant.confidence * 100).toStringAsFixed(0)}% confidence',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ).animate().fadeIn(),
    );
  }

  // ─── Action Buttons ────────────────────────────────────────────────────

  Widget _buildActionButtons(AssistantProvider assistant) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Repeat the answer',
            child: GestureDetector(
              onTap: () {
                HapticPatterns.tap();
                assistant.repeatAnswer();
              },
              child: Container(
                height: AppSizes.touchSecondary,
                decoration: BoxDecoration(
                  color: AppTheme.glassBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volume_up_rounded,
                        color: AppTheme.accentPrimary, size: 20),
                    SizedBox(width: 8),
                    Text('Repeat',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            button: true,
            label: 'Ask another question',
            child: GestureDetector(
              onTap: () {
                HapticPatterns.tap();
                assistant.resetForNewQuestion();
                setState(() {
                  _liveTranscript = '';
                  _isListening = false;
                });
              },
              child: Container(
                height: AppSizes.touchSecondary,
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.accentPrimary.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_rounded,
                        color: AppTheme.accentPrimary, size: 20),
                    SizedBox(width: 8),
                    Text('Ask Again',
                        style: TextStyle(
                            color: AppTheme.accentPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Keyboard Fallback ─────────────────────────────────────────────────
  // Only visible when STT is physically unavailable on the device.

  Widget _buildKeyboardFallback() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Type your question',
              child: TextField(
                controller: _textController,
                autofocus: true,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Type your question...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.glassBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppTheme.glassBorder),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onSubmitted: (text) {
                  _sendQuestion(text);
                  _textController.clear();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Send question',
            child: GestureDetector(
              onTap: () {
                _sendQuestion(_textController.text);
                _textController.clear();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Controls ───────────────────────────────────────────────────

  Widget _buildBottomControls(AssistantProvider assistant) {
    final bool canTap = !_isListening &&
        (assistant.state == AssistantState.idle ||
            assistant.state == AssistantState.done ||
            assistant.state == AssistantState.error);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Close / Cancel button
            Semantics(
              button: true,
              label: _isListening ? 'Cancel listening' : 'Close assistant',
              child: GestureDetector(
                onTap: () {
                  if (_isListening) {
                    _cancelListening();
                  } else {
                    context.read<AssistantProvider>().reset();
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: AppSizes.touchMinimum,
                  height: AppSizes.touchMinimum,
                  decoration: BoxDecoration(
                    color: _isListening
                        ? AppTheme.danger.withOpacity(0.15)
                        : AppTheme.glassBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isListening
                          ? AppTheme.danger.withOpacity(0.3)
                          : AppTheme.glassBorder,
                    ),
                  ),
                  child: Icon(
                    _isListening
                        ? Icons.close_rounded
                        : Icons.close_rounded,
                    color: _isListening
                        ? AppTheme.danger
                        : AppTheme.textSecondary,
                    size: 22,
                  ),
                ),
              ),
            ),

            // Large mic / stop button (center)
            Semantics(
              button: true,
              label: _isListening
                  ? 'Tap to stop listening and send your question'
                  : canTap
                      ? 'Tap to ask a question by voice'
                      : 'Please wait, processing your question',
              child: GestureDetector(
                onTap: _isListening
                    ? _stopListening
                    : canTap
                        ? _startListening
                        : null,
                child: Container(
                  width: AppSizes.touchPrimary,
                  height: AppSizes.touchPrimary,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isListening
                        ? const LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFFF5252)],
                          )
                        : canTap
                            ? AppTheme.primaryGradient
                            : const LinearGradient(
                                colors: [
                                  AppTheme.surface,
                                  AppTheme.surfaceElevated
                                ],
                              ),
                    boxShadow: (_isListening || canTap)
                        ? [
                            BoxShadow(
                              color: _isListening
                                  ? const Color(0xFFE53935).withOpacity(0.4)
                                  : AppTheme.accentPrimary.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    _isListening
                        ? Icons.stop_rounded
                        : assistant.state == AssistantState.processing
                            ? Icons.hourglass_top_rounded
                            : Icons.mic_rounded,
                    color: (_isListening || canTap)
                        ? Colors.white
                        : AppTheme.textMuted,
                    size: 30,
                  ),
                ),
              ),
            ),

            // Spacer (to balance layout)
            const SizedBox(width: AppSizes.touchMinimum),
          ],
        ),
      ),
    );
  }
}
