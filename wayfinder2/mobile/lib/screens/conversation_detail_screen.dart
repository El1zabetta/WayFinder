/// WayFinder 3.0 — Conversation Detail Screen
/// Fetches and displays a single past Q&A interaction from the backend.
/// Supports TTS replay of the saved answer.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/accessibility.dart';
import '../services/api_client.dart';
import '../services/spatial_audio_service.dart';

class ConversationDetailScreen extends StatefulWidget {
  final int interactionId;

  const ConversationDetailScreen({super.key, required this.interactionId});

  @override
  State<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  HistoryItem? _item;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final item =
          await WayFinderApi.fetchInteractionDetail(widget.interactionId);
      if (mounted) {
        setState(() {
          _item = item;
          _loading = false;
        });
        announceToScreenReader(
          'Детали разговора. Вы спросили: ${item.question}. '
          'Ответ: ${item.answer}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Не удалось загрузить этот разговор.';
        });
        announceToScreenReader('Ошибка загрузки деталей разговора.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Детали сессии'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Semantics(
        label: 'Загрузка деталей разговора',
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentPrimary),
        ),
      );
    }

    if (_error != null || _item == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Разговор не найден.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final item = _item!;
    final timeStr = DateFormat.yMMMd('ru_RU').add_Hm().format(item.createdAt);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Semantics(
            label: 'Спрошено $timeStr',
            child: Text(
              timeStr,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),

          // Question Bubble
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.accentPrimary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Вы спросили:',
                  style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  item.question,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Answer Bubble
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.safe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.safe.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.smart_toy_rounded,
                        color: AppTheme.safe, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'WayFinder ответил:',
                      style: TextStyle(
                          color: AppTheme.safe,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.answer,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 18,
                      height: 1.5),
                ),
              ],
            ),
          ),

          // Confidence indicator
          if (item.confidence > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Уверенность: ${(item.confidence * 100).toStringAsFixed(0)}% • ${item.source ?? "модель"}',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12),
              ),
            ),

          const Spacer(),

          // Replay Audio
          Semantics(
            button: true,
            label: 'Повторно воспроизвести ответ вслух',
            child: AccessibleButton(
              onTap: () {
                SpatialAudioService().speak(item.answer);
              },
              label: 'Воспроизвести ответ',
              icon: Icons.volume_up_rounded,
              color: AppTheme.surfaceElevated,
              textColor: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
