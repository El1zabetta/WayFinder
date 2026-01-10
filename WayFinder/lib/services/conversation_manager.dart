import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Advanced Conversation Manager with Context Intelligence
/// Manages conversation history, context, and user preferences
class ConversationManager {
  static const String _historyKey = 'conversation_history';
  static const String _contextKey = 'conversation_context';
  static const String _userPrefsKey = 'user_preferences';
  static const int _maxHistoryLength = 50; // Last 50 exchanges
  static const int _contextWindow = 10; // Last 10 for context

  /// Add a conversation exchange
  Future<void> addExchange(String userMessage, String aiResponse) async {
    final prefs = await SharedPreferences.getInstance();
    
    final exchange = ConversationExchange(
      userMessage: userMessage,
      aiResponse: aiResponse,
      timestamp: DateTime.now(),
    );

    // Load existing history
    final history = await getHistory();
    history.add(exchange);

    // Keep only recent history
    final trimmedHistory = history.length > _maxHistoryLength
        ? history.sublist(history.length - _maxHistoryLength)
        : history;

    // Save history
    final jsonList = trimmedHistory.map((e) => e.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(jsonList));

    print("💾 [CONVERSATION] Saved exchange. Total: ${trimmedHistory.length}");
  }

  /// Get full conversation history
  Future<List<ConversationExchange>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_historyKey);
      
      if (jsonString == null) return [];
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => ConversationExchange.fromJson(json)).toList();
    } catch (e) {
      print("❌ [CONVERSATION] Error loading history: $e");
      return [];
    }
  }

  /// Get conversation context for AI (recent exchanges)
  Future<Map<String, dynamic>> getContext() async {
    final history = await getHistory();
    
    // Get last N exchanges for context
    final recentHistory = history.length > _contextWindow
        ? history.sublist(history.length - _contextWindow)
        : history;

    // Extract key information
    final topics = _extractTopics(recentHistory);
    final userPreferences = await getUserPreferences();

    return {
      'recent_exchanges': recentHistory.map((e) => {
        'user': e.userMessage,
        'ai': e.aiResponse,
        'time_ago': _getTimeAgo(e.timestamp),
      }).toList(),
      'topics_discussed': topics,
      'user_preferences': userPreferences,
      'conversation_length': history.length,
      'session_start': history.isEmpty ? null : history.first.timestamp.toIso8601String(),
    };
  }

  /// Extract topics from conversation
  List<String> _extractTopics(List<ConversationExchange> exchanges) {
    final topics = <String>{};
    
    for (final exchange in exchanges) {
      final text = '${exchange.userMessage} ${exchange.aiResponse}'.toLowerCase();
      
      // Navigation keywords
      if (text.contains('навигация') || text.contains('маршрут') || 
          text.contains('navigate') || text.contains('direction')) {
        topics.add('navigation');
      }
      
      // Vision keywords
      if (text.contains('вижу') || text.contains('опиши') || 
          text.contains('see') || text.contains('describe')) {
        topics.add('vision');
      }
      
      // Location keywords
      if (text.contains('где') || text.contains('место') || 
          text.contains('where') || text.contains('location')) {
        topics.add('location');
      }
      
      // Help keywords
      if (text.contains('помощь') || text.contains('help') || 
          text.contains('как') || text.contains('how')) {
        topics.add('assistance');
      }
    }
    
    return topics.toList();
  }

  /// Get time ago string
  String _getTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Save user preferences
  Future<void> saveUserPreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final preferences = await getUserPreferences();
    
    preferences[key] = value;
    
    await prefs.setString(_userPrefsKey, jsonEncode(preferences));
    print("💾 [CONVERSATION] Saved preference: $key = $value");
  }

  /// Get user preferences
  Future<Map<String, dynamic>> getUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_userPrefsKey);
      
      if (jsonString == null) return _getDefaultPreferences();
      
      return Map<String, dynamic>.from(jsonDecode(jsonString));
    } catch (e) {
      print("❌ [CONVERSATION] Error loading preferences: $e");
      return _getDefaultPreferences();
    }
  }

  Map<String, dynamic> _getDefaultPreferences() {
    return {
      'language': 'ru',
      'voice_speed': 1.0,
      'detail_level': 'medium', // low, medium, high
      'safety_alerts': true,
      'distance_units': 'metric',
    };
  }

  /// Clear conversation history
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_contextKey);
    print("🗑️ [CONVERSATION] History cleared");
  }

  /// Get conversation statistics
  Future<ConversationStats> getStats() async {
    final history = await getHistory();
    
    if (history.isEmpty) {
      return ConversationStats(
        totalExchanges: 0,
        averageResponseLength: 0,
        mostActiveDay: null,
        topicsDiscussed: [],
        firstInteraction: null,
        lastInteraction: null,
      );
    }

    // Calculate stats
    final totalExchanges = history.length;
    final avgLength = history
        .map((e) => e.aiResponse.length)
        .reduce((a, b) => a + b) / history.length;

    final topics = _extractTopics(history);
    
    // Find most active day
    final dayGroups = <String, int>{};
    for (final exchange in history) {
      final day = exchange.timestamp.toIso8601String().split('T')[0];
      dayGroups[day] = (dayGroups[day] ?? 0) + 1;
    }
    
    final mostActiveDay = dayGroups.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return ConversationStats(
      totalExchanges: totalExchanges,
      averageResponseLength: avgLength.round(),
      mostActiveDay: mostActiveDay,
      topicsDiscussed: topics,
      firstInteraction: history.first.timestamp,
      lastInteraction: history.last.timestamp,
    );
  }

  /// Search conversation history
  Future<List<ConversationExchange>> search(String query) async {
    final history = await getHistory();
    final lowerQuery = query.toLowerCase();
    
    return history.where((exchange) {
      return exchange.userMessage.toLowerCase().contains(lowerQuery) ||
             exchange.aiResponse.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Export conversation history
  Future<String> exportHistory() async {
    final history = await getHistory();
    final stats = await getStats();
    
    final export = {
      'export_date': DateTime.now().toIso8601String(),
      'statistics': stats.toJson(),
      'conversations': history.map((e) => e.toJson()).toList(),
    };
    
    return jsonEncode(export);
  }
}

/// Conversation Exchange Model
class ConversationExchange {
  final String userMessage;
  final String aiResponse;
  final DateTime timestamp;

  ConversationExchange({
    required this.userMessage,
    required this.aiResponse,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'user_message': userMessage,
    'ai_response': aiResponse,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ConversationExchange.fromJson(Map<String, dynamic> json) {
    return ConversationExchange(
      userMessage: json['user_message'],
      aiResponse: json['ai_response'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Conversation Statistics
class ConversationStats {
  final int totalExchanges;
  final int averageResponseLength;
  final String? mostActiveDay;
  final List<String> topicsDiscussed;
  final DateTime? firstInteraction;
  final DateTime? lastInteraction;

  ConversationStats({
    required this.totalExchanges,
    required this.averageResponseLength,
    this.mostActiveDay,
    required this.topicsDiscussed,
    this.firstInteraction,
    this.lastInteraction,
  });

  Map<String, dynamic> toJson() => {
    'total_exchanges': totalExchanges,
    'average_response_length': averageResponseLength,
    'most_active_day': mostActiveDay,
    'topics_discussed': topicsDiscussed,
    'first_interaction': firstInteraction?.toIso8601String(),
    'last_interaction': lastInteraction?.toIso8601String(),
  };
}
