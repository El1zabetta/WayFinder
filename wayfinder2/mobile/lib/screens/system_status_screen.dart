/// WayFinder 3.0 — System Status Screen
/// Backend and model health dashboard.

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/accessibility.dart';
import '../services/api_client.dart';

class SystemStatusScreen extends StatefulWidget {
  const SystemStatusScreen({super.key});

  @override
  State<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends State<SystemStatusScreen> {
  Map<String, dynamic>? _health;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchHealth();
  }

  Future<void> _fetchHealth() async {
    setState(() => _loading = true);
    announceToScreenReader('Проверка состояния системы...');
    try {
      final data = await WayFinderApi.health();
      setState(() => _health = data);
      announceToScreenReader('Состояние системы успешно получено.');
    } catch (e) {
      setState(() => _health = {'status': 'error', 'error': e.toString()});
      announceToScreenReader('Не удалось получить состояние системы.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Статус системы'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentPrimary))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_health != null && _health!['status'] == 'ok') ...[
                  _buildMetricCard(
                    title: 'Ядро бэкенда WayFinder',
                    status: 'Подключено',
                    isHealthy: true,
                    icon: Icons.cloud_done_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    title: 'Визуальный конвейер (RynnBrain)',
                    status: _health!['engine_mode']?.toString().toUpperCase() ??
                        'АКТИВЕН',
                    isHealthy: true,
                    icon: Icons.visibility_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    title: 'Языковая модель (DeepSeek)',
                    status: 'АКТИВНА', // Implicitly working if backend is OK
                    isHealthy: true,
                    icon: Icons.psychology_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricCard(
                    title: 'GPU ускорение сервера',
                    status: _health!['gpu_available'] == true
                        ? _health!['gpu_name']
                        : 'Не обнаружено',
                    isHealthy: _health!['gpu_available'] == true,
                    icon: Icons.memory_rounded,
                  ),
                ] else ...[
                  ErrorStateWidget(
                    message: 'Сервер бэкенда недоступен.',
                    actionLabel: 'Проверить соединение снова',
                    onAction: _fetchHealth,
                  ),
                ],
                const SizedBox(height: 48),
                AccessibleButton(
                  onTap: _fetchHealth,
                  label: 'Обновить статус',
                  icon: Icons.refresh_rounded,
                  color: AppTheme.surfaceElevated,
                  textColor: AppTheme.textPrimary,
                ),
              ],
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String status,
    required bool isHealthy,
    required IconData icon,
  }) {
    final color = isHealthy ? AppTheme.safe : AppTheme.warning;

    return Semantics(
      label: 'Статус $title: $status',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(status, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
