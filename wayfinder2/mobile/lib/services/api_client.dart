/// WayFinder 2.0 — Backend API Client
/// Communicates with Django RynnBrain 2B backend via HTTP + WebSocket
/// Sends Firebase ID token as Bearer auth on all protected endpoints.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../core/app_config.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Result from any RynnBrain analysis call
class RynnBrainResult {
  final String mode;
  final String rawText;
  final String? navigationAction;
  final List<SpatialPoint> spatialPoints;
  final List<ThreatInfo> threats;
  final List<AudioCue> audioCues;
  final double confidence;
  final int? inferenceMs;

  const RynnBrainResult({
    required this.mode,
    required this.rawText,
    this.navigationAction,
    this.spatialPoints = const [],
    this.threats = const [],
    this.audioCues = const [],
    this.confidence = 0.0,
    this.inferenceMs,
  });

  factory RynnBrainResult.fromJson(Map<String, dynamic> json) {
    return RynnBrainResult(
      mode: json['mode'] ?? 'base',
      rawText: json['raw_text'] ?? '',
      navigationAction: json['navigation_action'],
      spatialPoints: (json['spatial_points'] as List? ?? [])
          .map((p) => SpatialPoint.fromJson(p))
          .toList(),
      threats: (json['threats'] as List? ?? [])
          .map((t) => ThreatInfo.fromJson(t))
          .toList(),
      audioCues: (json['audio_cues'] as List? ?? [])
          .map((a) => AudioCue.fromJson(a))
          .toList(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      inferenceMs: json['inference_ms']?.toInt(),
    );
  }

  bool get hasThreats => threats.isNotEmpty;
  bool get isHighAlert => threats.length >= 2;
}

class SpatialPoint {
  final double x, y, azimuth, elevation;
  SpatialPoint({
    required this.x,
    required this.y,
    required this.azimuth,
    required this.elevation,
  });
  factory SpatialPoint.fromJson(Map<String, dynamic> j) => SpatialPoint(
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        azimuth: (j['azimuth'] as num?)?.toDouble() ?? 0.0,
        elevation: (j['elevation'] as num?)?.toDouble() ?? 0.0,
      );
}

class ThreatInfo {
  final String type;
  final List<double> bbox;
  final double azimuth;
  final double elevation;

  ThreatInfo({
    required this.type,
    required this.bbox,
    required this.azimuth,
    required this.elevation,
  });

  factory ThreatInfo.fromJson(Map<String, dynamic> j) => ThreatInfo(
        type: j['type'] ?? 'obstacle',
        bbox: (j['bbox'] as List? ?? []).map((e) => (e as num).toDouble()).toList(),
        azimuth: (j['azimuth'] as num?)?.toDouble() ?? 0.0,
        elevation: (j['elevation'] as num?)?.toDouble() ?? 0.0,
      );
}

class AudioCue {
  final String message;
  final double azimuth;     // -90 left ... 0 center ... +90 right
  final double elevation;   // -30 below ... 0 level ... +30 above
  final String priority;    // LOW | MEDIUM | HIGH
  final String type;        // NAV | THREAT | INFO

  AudioCue({
    required this.message,
    required this.azimuth,
    required this.elevation,
    required this.priority,
    required this.type,
  });

  factory AudioCue.fromJson(Map<String, dynamic> j) => AudioCue(
        message: j['message'] ?? '',
        azimuth: (j['azimuth'] as num?)?.toDouble() ?? 0.0,
        elevation: (j['elevation'] as num?)?.toDouble() ?? 0.0,
        priority: j['priority'] ?? 'MEDIUM',
        type: j['type'] ?? 'INFO',
      );
}

class SearchResult {
  final String target;
  final bool found;
  final SpatialPoint? location;
  final String instructions;
  final List<AudioCue> audioCues;
  final double confidence;

  SearchResult({
    required this.target,
    required this.found,
    this.location,
    required this.instructions,
    this.audioCues = const [],
    this.confidence = 0.0,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        target: j['target'] ?? '',
        found: j['found'] ?? false,
        location: j['location'] != null ? SpatialPoint.fromJson(j['location']) : null,
        instructions: j['instructions'] ?? '',
        audioCues: (j['audio_cues'] as List? ?? [])
            .map((a) => AudioCue.fromJson(a))
            .toList(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
      );
}

/// API Client — communicates with Django backend
class WayFinderApi {
  static String get baseUrl => AppConfig.baseUrl;

  static const Duration _timeout = Duration(seconds: 60);

  /// Check if the backend server is reachable
  static Future<bool> isServerReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health/'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Helper ─────────────────────────────────────────────────────────────

  /// Get the current Firebase ID token for authenticated requests.
  /// Returns null if no user is signed in.
  static Future<String?> _getAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken();
    } catch (e) {
      _log.w('Failed to get Firebase ID token: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> _postMultipart(
    String endpoint,
    Map<String, String> fields, {
    File? videoFile,
    File? imageFile,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri);

    // Attach Firebase Bearer token
    final token = await _getAuthToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields.addAll(fields);

    if (videoFile != null) {
      request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));
    }
    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }

    try {
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw ApiException.network();
    } on TimeoutException catch (_) {
      throw ApiException.timeout();
    } on HttpException catch (_) {
      throw ApiException.network();
    } on FormatException catch (_) {
      throw ApiException.server('Сервер вернул нечитаемый ответ.');
    }
  }

  // ─── Endpoints ──────────────────────────────────────────────────────────

  /// Analyze video clip with RynnBrain-2B
  static Future<RynnBrainResult> analyzeVideo(
    File videoFile, {
    String query = 'Проанализируй эту сцену для безопасной навигации.',
    String mode = 'nav',
  }) async {
    _log.d('analyzeVideo: mode=$mode');
    final json = await _postMultipart(
      '/analyze/video/',
      {'query': query, 'mode': mode},
      videoFile: videoFile,
    );
    return RynnBrainResult.fromJson(json);
  }

  /// Analyze single image
  static Future<RynnBrainResult> analyzeImage(
    File imageFile, {
    String query = 'Опиши эту сцену и выяви опасности.',
    String mode = 'cop',
  }) async {
    _log.d('analyzeImage: mode=$mode');
    final json = await _postMultipart(
      '/analyze/image/',
      {'query': query, 'mode': mode},
      imageFile: imageFile,
    );
    return RynnBrainResult.fromJson(json);
  }

  /// Get next navigation action (RynnBrain-Nav)
  static Future<RynnBrainResult> navigate(
    File videoFile,
    String destination,
  ) async {
    _log.d('navigate to: $destination');
    final json = await _postMultipart(
      '/navigate/',
      {'destination': destination},
      videoFile: videoFile,
    );
    // Ensure the mode is set for RynnBrainResult.fromJson
    if (json['mode'] == null) json['mode'] = 'nav';
    if (json['raw_text'] == null && json['guidance_text'] != null) {
      json['raw_text'] = json['guidance_text'];
    }
    if (json['navigation_action'] == null && json['action'] != null) {
      json['navigation_action'] = json['action'];
    }
    if (json['threats'] == null && json['obstacles'] != null) {
      json['threats'] = json['obstacles'];
    }
    return RynnBrainResult.fromJson(json);
  }

  /// Detect safety threats (RynnBrain-CoP)
  static Future<Map<String, dynamic>> detectThreats(File videoFile) async {
    _log.d('detectThreats');
    return _postMultipart('/threats/', {}, videoFile: videoFile);
  }

  /// Search for object (RynnBrain-Plan)
  static Future<SearchResult> searchObject(File videoFile, String target) async {
    _log.d('searchObject: $target');
    final json = await _postMultipart(
      '/search/',
      {'target': target},
      videoFile: videoFile,
    );
    return SearchResult.fromJson(json);
  }

  /// Ask a question about the current scene (Ask-Wayfinder)
  static Future<QAResult> askWayfinder(
    String question, {
    File? videoFile,
    File? imageFile,
  }) async {
    _log.d('askWayfinder: "$question"');
    final json = await _postMultipart(
      '/ask/',
      {'question': question},
      videoFile: videoFile,
      imageFile: imageFile,
    );
    return QAResult.fromJson(json);
  }

  /// Health check
  static Future<Map<String, dynamic>> health() async {
    final response = await http.get(Uri.parse('$baseUrl/health/')).timeout(_timeout);
    return json.decode(response.body) as Map<String, dynamic>;
  }

  // ─── Authenticated GET helper ──────────────────────────────────────────

  static Future<Map<String, dynamic>> _getAuthenticated(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{};

    final token = await _getAuthToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await http.get(uri, headers: headers).timeout(_timeout);
      return _handleResponse(response);
    } on SocketException catch (_) {
      throw ApiException.network();
    } on TimeoutException catch (_) {
      throw ApiException.timeout();
    } on HttpException catch (_) {
      throw ApiException.network();
    } on FormatException catch (_) {
      throw ApiException.server('Сервер вернул нечитаемый ответ.');
    }
  }

  /// Shared response handler — classifies HTTP errors into typed ApiExceptions
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      _log.e('Auth rejected: ${response.statusCode}');
      throw ApiException.auth();
    }

    if (response.statusCode >= 500) {
      _log.e('Server error: ${response.statusCode}');
      throw ApiException.server('На сервере произошла ошибка. Пожалуйста, попробуйте позже.');
    }

    if (response.statusCode != 200) {
      _log.e('API error ${response.statusCode}: ${response.body}');
      // Try to extract a clean error message from backend JSON
      String msg = 'Что-то пошло не так.';
      try {
        final body = json.decode(response.body);
        if (body is Map && body['error'] != null) msg = body['error'];
      } catch (_) {}
      throw ApiException(response.statusCode, msg, errorType: ApiErrorType.unknown);
    }

    try {
      return json.decode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException.server('Сервер вернул нечитаемый ответ.');
    }
  }

  // ─── History ───────────────────────────────────────────────────────────

  /// Fetch user's Q&A history from the backend
  static Future<List<HistoryItem>> fetchHistory({int limit = 50}) async {
    _log.d('fetchHistory: limit=$limit');
    final data = await _getAuthenticated('/history/?limit=$limit');
    final results = data['results'] as List? ?? [];
    return results.map((j) => HistoryItem.fromJson(j)).toList();
  }

  /// Fetch detail for a single interaction
  static Future<HistoryItem> fetchInteractionDetail(int id) async {
    _log.d('fetchInteractionDetail: id=$id');
    final data = await _getAuthenticated('/history/$id/');
    return HistoryItem.fromJson(data);
  }
}

// ─── History Data Model ────────────────────────────────────────────────────

class HistoryItem {
  final int id;
  final String question;
  final String answer;
  final String interactionType;
  final double confidence;
  final bool? grounded;
  final String? source;
  final double? inferenceMs;
  final DateTime createdAt;

  const HistoryItem({
    required this.id,
    required this.question,
    required this.answer,
    this.interactionType = 'ask',
    this.confidence = 0.0,
    this.grounded,
    this.source,
    this.inferenceMs,
    required this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        id: j['id'] ?? 0,
        question: j['question'] ?? '',
        answer: j['answer'] ?? '',
        interactionType: j['interaction_type'] ?? 'ask',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        grounded: j['grounded'],
        source: j['source'],
        inferenceMs: (j['inference_ms'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      );

  /// Short preview of the answer for list views
  String get answerPreview {
    if (answer.length <= 80) return answer;
    return '${answer.substring(0, 80)}...';
  }
}

class QAResult {
  final String question;
  final String answer;
  final bool grounded;
  final double confidence;
  final String? source;
  final int? inferenceMs;

  const QAResult({
    required this.question,
    required this.answer,
    this.grounded = false,
    this.confidence = 0.0,
    this.source,
    this.inferenceMs,
  });

  factory QAResult.fromJson(Map<String, dynamic> j) => QAResult(
        question: j['question'] ?? '',
        answer: j['answer'] ?? '',
        grounded: j['grounded'] ?? false,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        source: j['source'],
        inferenceMs: j['inference_ms']?.toInt(),
      );
}

/// Error types for structured API failure handling
enum ApiErrorType {
  auth,      // 401/403 — token expired or missing
  network,   // No internet / DNS failure / connection refused
  timeout,   // Request took too long
  server,    // 500+ server error
  unknown,   // Other HTTP errors
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  final ApiErrorType errorType;

  ApiException(this.statusCode, this.body, {this.errorType = ApiErrorType.unknown});

  /// Auth failure — token expired or missing
  factory ApiException.auth() => ApiException(
        401,
        'Ваша сессия истекла. Пожалуйста, войдите снова.',
        errorType: ApiErrorType.auth,
      );

  /// No internet / connection error
  factory ApiException.network() => ApiException(
        0,
        'Нет подключения к интернету. Проверьте сеть и попробуйте снова.',
        errorType: ApiErrorType.network,
      );

  /// Request timed out
  factory ApiException.timeout() => ApiException(
        0,
        'Время ожидания запроса истекло. Сервер может быть занят, попробуйте еще раз.',
        errorType: ApiErrorType.timeout,
      );

  /// Server error (500+)
  factory ApiException.server(String detail) => ApiException(
        500,
        detail,
        errorType: ApiErrorType.server,
      );

  bool get isAuth => errorType == ApiErrorType.auth;
  bool get isNetwork => errorType == ApiErrorType.network;
  bool get isTimeout => errorType == ApiErrorType.timeout;
  bool get isServer => errorType == ApiErrorType.server;

  /// User-friendly message safe to announce via TTS or screen reader
  String get userMessage => body;

  @override
  String toString() => 'ApiException($statusCode, $errorType): $body';
}
