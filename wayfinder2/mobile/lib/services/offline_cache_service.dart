/// WayFinder 2.0 — Offline Cache Service
/// Caches last analysis results for offline fallback.
/// Provides hardcoded safety hints when server is unreachable.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._();

  static const _keyLastNavResult = 'offline_last_nav_result';
  static const _keyLastNavText = 'offline_last_nav_text';
  static const _keyLastSafetyText = 'offline_last_safety_text';
  static const _keyLastQAPairs = 'offline_last_qa_pairs';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _storage async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ─── Navigation Cache ──────────────────────────────────────────────────────

  /// Save last navigation analysis text
  Future<void> cacheNavigation(String rawText, Map<String, dynamic> resultJson) async {
    final prefs = await _storage;
    await prefs.setString(_keyLastNavText, rawText);
    await prefs.setString(_keyLastNavResult, jsonEncode(resultJson));
    _log.d('Cached navigation result (${rawText.length} chars)');
  }

  /// Get last cached navigation text
  Future<String?> getCachedNavigationText() async {
    final prefs = await _storage;
    return prefs.getString(_keyLastNavText);
  }

  // ─── Safety Cache ─────────────────────────────────────────────────────────

  /// Save last safety analysis
  Future<void> cacheSafety(String analysisText) async {
    final prefs = await _storage;
    await prefs.setString(_keyLastSafetyText, analysisText);
  }

  /// Get last cached safety analysis
  Future<String?> getCachedSafetyText() async {
    final prefs = await _storage;
    return prefs.getString(_keyLastSafetyText);
  }

  // ─── Q&A Cache ────────────────────────────────────────────────────────────

  /// Cache a Q&A pair
  Future<void> cacheQA(String question, String answer) async {
    final prefs = await _storage;
    final existing = prefs.getString(_keyLastQAPairs);
    Map<String, String> pairs = {};
    if (existing != null) {
      try {
        pairs = Map<String, String>.from(jsonDecode(existing));
      } catch (_) {}
    }
    // Keep last 20 Q&A pairs
    if (pairs.length >= 20) {
      pairs.remove(pairs.keys.first);
    }
    pairs[question.toLowerCase().trim()] = answer;
    await prefs.setString(_keyLastQAPairs, jsonEncode(pairs));
  }

  /// Find a cached answer for a similar question
  Future<String?> findCachedAnswer(String question) async {
    final prefs = await _storage;
    final existing = prefs.getString(_keyLastQAPairs);
    if (existing == null) return null;
    try {
      final pairs = Map<String, String>.from(jsonDecode(existing));
      final key = question.toLowerCase().trim();
      // Exact match
      if (pairs.containsKey(key)) return pairs[key];
      // Partial match — find the closest
      for (final entry in pairs.entries) {
        if (key.contains(entry.key) || entry.key.contains(key)) {
          return entry.value;
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── Offline Safety Hints ─────────────────────────────────────────────────

  /// Hardcoded baseline safety hints for when server is completely unreachable
  static const List<String> offlineSafetyHints = [
    'Двигайтесь медленно и используйте трость для сканирования пути впереди.',
    'Слушайте звуки транспорта перед тем, как переходить дорогу.',
    'Держитесь ближе к стене или краю здания для ориентации.',
    'Если не уверены, остановитесь и попросите помощи у прохожих.',
    'Не сходите с бордюра, не проверив наличие препятствий.',
    'Обращайте внимание на изменение текстуры земли — это могут быть лестницы или пандусы.',
    'Держите телефон заряженным для экстренных вызовов.',
    'Используйте пешеходные переходы со звуковыми сигналами, если они доступны.',
  ];

  /// Get a random offline safety hint
  static String getRandomHint() {
    final index = DateTime.now().millisecond % offlineSafetyHints.length;
    return offlineSafetyHints[index];
  }
}
