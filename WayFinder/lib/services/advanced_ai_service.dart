import 'dart:convert';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'conversation_manager.dart';

/// Advanced Vision API Service with Intelligent Caching and Optimization
class AdvancedVisionApiService {
  static const String _defaultUrl = "https://tristian-weightier-loblolly.ngrok-free.dev";
  static const Duration _timeout = Duration(seconds: 10); // FAST: 10s timeout
  static const int _imageQuality = 25; // HIGH compression for speed
  
  // Cache for quick responses
  final Map<String, CachedResponse> _responseCache = {};
  final ConversationManager _conversationManager = ConversationManager();

  // Custom Client
  static final http.Client _client = IOClient(
    HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true
  );

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_url') ?? _defaultUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
  }

  /// Smart Analyze with Context-Aware AI
  Future<AIResponse> smartAnalyze({
    XFile? image,
    String? audioPath,
    String mode = 'chat',
    String text = '',
    bool useCache = true,
  }) async {
    print("🤖 [AI] Starting smart analysis...");
    print("🤖 [AI] Mode: $mode, Text: $text");
    
    final startTime = DateTime.now();
    
    // INSTANT OFFLINE RESPONSES for common queries (no network needed!)
    if (image == null && audioPath == null && text.isNotEmpty) {
      final offlineResponse = _getOfflineResponse(text);
      if (offlineResponse != null) {
        print("⚡ [AI] Instant offline response!");
        return offlineResponse;
      }
    }
    
    // Check cache for text-only queries
    if (useCache && image == null && audioPath == null && text.isNotEmpty) {
      final cached = _getCachedResponse(text);
      if (cached != null) {
        print("⚡ [AI] Using cached response (instant!)");
        return cached;
      }
    }

    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/smart-analyze/');

    // Get conversation context
    final context = await _conversationManager.getContext();
    
    var request = http.MultipartRequest('POST', uri);
    request.headers['ngrok-skip-browser-warning'] = 'true';
    
    // Enhanced fields with context
    request.fields['user_id'] = await _getUserId();
    request.fields['mode'] = mode;
    request.fields['text'] = text;
    request.fields['conversation_context'] = jsonEncode(context);
    request.fields['timestamp'] = DateTime.now().toIso8601String();
    
    // Add system prompt for better AI responses
    request.fields['system_prompt'] = _getSystemPrompt(mode);

    if (image != null) {
      print("📸 [AI] Adding image to request");
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }
    
    if (audioPath != null) {
      print("🎤 [AI] Adding audio to request");
      request.files.add(await http.MultipartFile.fromPath('audio', audioPath));
    }

    try {
      print("🌐 [AI] Sending request to server...");
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      final duration = DateTime.now().difference(startTime);
      print("⏱️ [AI] Response received in ${duration.inMilliseconds}ms");

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        final aiResponse = AIResponse(
          message: data['message'] ?? '',
          audio: data['audio'],
          debugVision: data['debug_vision'],
          detectedObjects: (data['detected_objects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
          confidence: data['confidence']?.toDouble() ?? 1.0,
          responseTime: duration,
          cached: false,
        );

        // Cache successful text responses
        if (image == null && audioPath == null && text.isNotEmpty) {
          _cacheResponse(text, aiResponse);
        }

        // Update conversation context
        await _conversationManager.addExchange(text, aiResponse.message);

        print("✅ [AI] Analysis complete!");
        return aiResponse;
      } else {
        print("❌ [AI] Server error: ${response.statusCode}");
        throw AIException("Server Error: ${response.statusCode}", response.body);
      }
    } on http.ClientException catch (e) {
      print("❌ [AI] Network error: $e");
      throw AIException("Network Error", e.toString());
    } catch (e) {
      print("❌ [AI] Unexpected error: $e");
      throw AIException("Connection Failed", e.toString());
    }
  }

  /// Navigation with AI-powered route optimization
  Future<AIResponse> requestNavigation({
    String? audioPath,
    required String text,
    double? currentLat,
    double? currentLon,
  }) async {
    print("🗺️ [AI] Starting navigation request...");
    
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/navigate/');

    var request = http.MultipartRequest('POST', uri);
    request.headers['ngrok-skip-browser-warning'] = 'true';
    
    request.fields['user_id'] = await _getUserId();
    request.fields['text'] = text;
    request.fields['system_prompt'] = _getNavigationPrompt();
    
    if (currentLat != null) {
      request.fields['current_lat'] = currentLat.toString();
    }
    if (currentLon != null) {
      request.fields['current_lon'] = currentLon.toString();
    }
    
    if (audioPath != null) {
      request.files.add(await http.MultipartFile.fromPath('audio', audioPath));
    }

    try {
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return AIResponse(
          message: data['message'] ?? '',
          audio: data['audio'],
          debugVision: data['debug_vision'],
          detectedObjects: (data['detected_objects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
          confidence: 1.0,
          responseTime: Duration.zero,
          cached: false,
        );
      } else {
        throw AIException("Server Error: ${response.statusCode}", response.body);
      }
    } catch (e) {
      throw AIException("Connection Failed", e.toString());
    }
  }

  /// Get optimized system prompt based on mode
  String _getSystemPrompt(String mode) {
    switch (mode) {
      case 'chat':
        return '''You are WayFinder, an advanced AI assistant designed specifically for visually impaired users. 

Your core principles:
1. CLARITY: Always provide clear, concise, and actionable information
2. SAFETY: Prioritize user safety in all responses, especially for navigation
3. EMPATHY: Be understanding and patient, adapting to user needs
4. CONTEXT: Use conversation history to provide relevant, personalized responses
5. BREVITY: Keep responses short but informative - users rely on voice output

Response guidelines:
- Use simple, direct language
- Describe visual elements in detail when asked
- Provide spatial information (left, right, ahead, distance)
- Alert to potential hazards immediately
- Confirm understanding before complex actions
192: - Use metric units (meters, kilometers)
193: - Do NOT use emojis.
194: 
195: Remember: You are the user's eyes. Be accurate, helpful, and trustworthy.''';

      case 'vision':
        return '''You are WayFinder's Vision AI, specialized in describing visual environments for visually impaired users.

When describing scenes:
1. Start with IMMEDIATE HAZARDS (stairs, obstacles, traffic)
2. Describe SPATIAL LAYOUT (what's ahead, left, right, distance)
3. Identify IMPORTANT OBJECTS (people, vehicles, signs, doors)
4. Note ENVIRONMENTAL CONDITIONS (lighting, weather, terrain)
5. Provide ACTIONABLE GUIDANCE (safe paths, next steps)

Format your responses:
- Lead with safety-critical information
- Use clock positions (12 o'clock = straight ahead)
- Include approximate distances in meters
- Describe colors and text when relevant
- Be specific about object locations

213: 
214: Example: "CAUTION: Steps ahead at 2 meters. Person approaching from your right at 5 meters. Clear path to your left. Bright sunlight, good visibility."
215: 
216: Do NOT use emojis.
217: 
218: Be the user's trusted eyes.''';

      case 'guide':
        return '''You are WayFinder's Ultimate Safety AI. 
Context: You are guiding a visually impaired person in real-time.

PRIORITY 1: IMMEDIATE SURVIVAL
- Open manholes (люки), deep pits, moving cars, approaching bikes.
- Say: "[DANGER] Стой, люк!", "[DANGER] Осторожно, машина!".

PRIORITY 2: TRAFFIC & CROSSINGS
- Identify traffic light colors. 
- If Red: Say "[STOP] Красный свет. Ждите."
- If Green: Check if path is actually clear from turning cars. Say "[GO] Зеленый. Путь свободен, идите."
- If no traffic lights: Observe flow of people. Say "Люди пошли, можете следовать за ними."

PRIORITY 3: PATH OBSTACLES
- Low-hanging branches, signboards at head level.
- Steps (вверх/вниз), curb (бордюр).
- Say: "Ступеньки вверх", "Бордюр через метр".

FORMAT RULES:
1. Short phrases only. 
2. Use [DANGER] for urgent threats.
3. Use [STOP] for traffic lights/wait.
4. Use [GO] for clear crossings.
5. If everything is safe, return exactly "[CLEAR]".

Be the most reliable eyes any human could have.''';

      case 'search':
        return '''You are WayFinder's Object Finder.
The user is looking for a specific object: "{QUERY}".
Analyze the image and:
1. If found: Describe its position using clock face orientation (e.g., "at 2 o'clock") and distance.
2. If not found: Say "Not in view".
3. Provide guidance: "Move camera slightly to the right".

Keep it very short and actionable.''';

      case 'analyze_text':
        return '''You are WayFinder's Intelligent Reader.
You have an image of a text (menu, document, sign).
The user asks: "{QUERY}".
Instead of reading everything, answer ONLY their specific question based on the text.
If the information is missing, say "I can't find that in the text".''';

      default:
        return 'You are WayFinder, a helpful AI assistant for visually impaired users. Provide clear, concise, and safe guidance.';
    }
  }

  String _getNavigationPrompt() {
    return '''You are WayFinder's Navigation AI, providing turn-by-turn directions for visually impaired users.

Navigation principles:
1. SAFETY FIRST: Always choose the safest route
2. CLARITY: Use simple, unambiguous directions
3. LANDMARKS: Reference tactile/audible landmarks when possible
4. WARNINGS: Alert to crossings, stairs, obstacles
5. CONFIRMATION: Provide distance and direction confirmations

Direction format:
- Use cardinal directions (North, South, East, West)
- Provide distances in meters
- Mention landmarks ("After the traffic light...")
- Warn about hazards ("Caution: busy intersection ahead")
- Confirm arrival ("You have reached your destination")

Example: "Head North for 50 meters. At the traffic light, turn right onto Main Street. Continue for 200 meters. Your destination will be on the left."

Do NOT use emojis.

Guide users safely to their destination.''';
  }

  /// Cache management
  void _cacheResponse(String query, AIResponse response) {
    final key = query.toLowerCase().trim();
    _responseCache[key] = CachedResponse(
      response: response,
      timestamp: DateTime.now(),
    );

    // Limit cache size
    if (_responseCache.length > 50) {
      final oldest = _responseCache.entries.first.key;
      _responseCache.remove(oldest);
    }
  }

  AIResponse? _getCachedResponse(String query) {
    final key = query.toLowerCase().trim();
    final cached = _responseCache[key];
    
    if (cached != null) {
      // Cache valid for 5 minutes
      if (DateTime.now().difference(cached.timestamp).inMinutes < 5) {
        return cached.response.copyWith(cached: true);
      } else {
        _responseCache.remove(key);
      }
    }
    
    return null;
  }

  /// Instant offline responses for common interactions
  AIResponse? _getOfflineResponse(String text) {
    final lower = text.toLowerCase().trim();
    
    // Greetings
    if (lower == 'привет' || lower == 'здравствуй' || lower == 'здравствуйте' || lower == 'hello' || lower == 'hi') {
      return AIResponse(
        message: "Привет! Я готов помочь. Скажите 'Что передо мной', чтобы описать сцену, или 'Построй маршрут', чтобы пойти куда-нибудь.",
        confidence: 1.0,
        responseTime: Duration.zero,
        cached: true,
      );
    }
    
    // Gratitude
    if (lower.contains('спасибо') || lower.contains('благодарю') || lower.contains('thank')) {
      return AIResponse(
        message: "Пожалуйста! Обращайтесь в любое время.",
        confidence: 1.0,
        responseTime: Duration.zero,
        cached: true,
      );
    }
    
    // Status
    if (lower == 'как дела' || lower == 'как ты' || lower == 'how are you') {
      return AIResponse(
        message: "Всё отлично! Системы работают в штатном режиме. Батарея и GPS в норме. Чем могу помочь?",
        confidence: 1.0,
        responseTime: Duration.zero,
        cached: true,
      );
    }

    // Identity
    if (lower == 'кто ты' || lower == 'как тебя зовут' || lower == 'who are you') {
      return AIResponse(
        message: "Я WayFinder, ваш персональный визуальный помощник. Я помогаю видеть мир через камеру вашего телефона.",
        confidence: 1.0,
        responseTime: Duration.zero,
        cached: true,
      );
    }
    
    return null;
  }

  Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    
    if (userId == null) {
      userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('user_id', userId);
    }
    
    return userId;
  }

  /// Clear cache
  void clearCache() {
    _responseCache.clear();
    print("🗑️ [AI] Cache cleared");
  }

  /// Get cache stats
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_responses': _responseCache.length,
      'oldest_cache': _responseCache.isEmpty 
        ? null 
        : _responseCache.values.first.timestamp.toIso8601String(),
    };
  }
}

/// AI Response Model
class AIResponse {
  final String message;
  final String? audio;
  final String? debugVision;
  final List<String>? detectedObjects;
  final double confidence;
  final Duration responseTime;
  final bool cached;

  AIResponse({
    required this.message,
    this.audio,
    this.debugVision,
    this.detectedObjects,
    required this.confidence,
    required this.responseTime,
    required this.cached,
  });

    String? message,
    String? audio,
    String? debugVision,
    List<String>? detectedObjects,
    double? confidence,
    Duration? responseTime,
    bool? cached,
  }) {
    return AIResponse(
      message: message ?? this.message,
      audio: audio ?? this.audio,
      debugVision: debugVision ?? this.debugVision,
      detectedObjects: detectedObjects ?? this.detectedObjects,
      confidence: confidence ?? this.confidence,
      responseTime: responseTime ?? this.responseTime,
      cached: cached ?? this.cached,
    );
  }
}

/// Cached Response
class CachedResponse {
  final AIResponse response;
  final DateTime timestamp;

  CachedResponse({
    required this.response,
    required this.timestamp,
  });
}

/// AI Exception
class AIException implements Exception {
  final String message;
  final String? details;

  AIException(this.message, [this.details]);

  @override
  String toString() => 'AIException: $message${details != null ? ' - $details' : ''}';
}
