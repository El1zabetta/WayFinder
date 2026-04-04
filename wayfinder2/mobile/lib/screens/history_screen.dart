/// WayFinder 3.0 — History Screen
/// Fetches real Q&A history from backend API, scoped by authenticated user.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/accessibility.dart';
import '../services/api_client.dart';
import 'conversation_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await WayFinderApi.fetchHistory(limit: 50);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
        announceToScreenReader(
          items.isEmpty
              ? 'History screen. No past questions yet.'
              : 'History screen. ${items.length} past questions loaded.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load history. Check your connection.';
        });
        announceToScreenReader('Error loading history.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: Semantics(
          button: true,
          label: 'Go back',
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppTheme.textPrimary),
          ),
        ),
        title: const Text('History'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Semantics(
        label: 'Loading history',
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentPrimary),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Semantics(
                button: true,
                label: 'Retry loading history',
                child: GestureDetector(
                  onTap: _loadHistory,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.accentPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('Retry',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = _items ?? [];

    if (items.isEmpty) {
      return Semantics(
        label: 'No history yet. Ask a question first.',
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded,
                  size: 64, color: AppTheme.glassBorder),
              SizedBox(height: 16),
              Text(
                'No history yet',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'Ask WayFinder a question to see it here.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: AppTheme.accentPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          // Date grouping
          final dateLabel = _formatDateLabel(item.createdAt);
          bool showDateHeader = false;
          if (index == 0) {
            showDateHeader = true;
          } else {
            final prevLabel = _formatDateLabel(items[index - 1].createdAt);
            showDateHeader = dateLabel != prevLabel;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDateHeader) ...[
                if (index > 0) const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12, left: 4),
                    child: Text(
                      dateLabel,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
              _buildHistoryCard(item),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(HistoryItem item) {
    final isAsk = item.interactionType == 'ask';
    final timeStr = DateFormat.Hm().format(item.createdAt);

    return Semantics(
      button: true,
      label:
          '${isAsk ? "Question" : "Navigation"} at $timeStr: ${item.question}. Tap to view detail.',
      child: GestureDetector(
        onTap: () {
          HapticPatterns.tap();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConversationDetailScreen(interactionId: item.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isAsk ? AppTheme.accentPrimary : AppTheme.safe)
                      .withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAsk ? Icons.mic_rounded : Icons.explore_rounded,
                  color: isAsk ? AppTheme.accentPrimary : AppTheme.safe,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.question,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.answerPreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat.yMMMd().format(dt);
  }
}
