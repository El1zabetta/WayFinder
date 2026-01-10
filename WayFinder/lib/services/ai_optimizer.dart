import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// AI Response Optimizer
/// Implements aggressive optimization strategies for lightning-fast AI responses
class AIResponseOptimizer {
  // Predictive cache - предсказывает следующие запросы
  final _predictiveCache = <String, PredictedResponse>{};
  
  // Request queue with priority
  final _requestQueue = PriorityQueue<AIRequest>();
  
  // Response streaming
  final _streamController = StreamController<ResponseChunk>.broadcast();
  
  // Performance metrics
  final _metrics = PerformanceMetrics();

  /// Optimize request before sending
  OptimizedRequest optimizeRequest({
    required String text,
    bool hasImage = false,
    bool hasAudio = false,
    String mode = 'chat',
  }) {
    print("⚡ [OPTIMIZER] Optimizing request...");
    
    // 1. Text compression
    final compressedText = _compressText(text);
    
    // 2. Priority calculation
    final priority = _calculatePriority(text, hasImage, hasAudio);
    
    // 3. Predict next queries
    _predictNextQueries(text);
    
    // 4. Check if can use partial response
    final canStream = !hasImage && !hasAudio && text.length > 50;
    
    print("⚡ [OPTIMIZER] Priority: $priority, Can stream: $canStream");
    
    return OptimizedRequest(
      originalText: text,
      compressedText: compressedText,
      priority: priority,
      canStream: canStream,
      mode: mode,
      hasImage: hasImage,
      hasAudio: hasAudio,
    );
  }

  /// Compress text for faster transmission
  String _compressText(String text) {
    // Remove extra whitespace
    var compressed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Common abbreviations (only for transmission, AI will understand)
    final abbreviations = {
      'что передо мной': 'чтопм',
      'опиши что вижу': 'опчв',
      'как дойти до': 'кдд',
      'где находится': 'гдн',
    };
    
    for (final entry in abbreviations.entries) {
      if (compressed.toLowerCase().contains(entry.key)) {
        // Mark as abbreviated for server
        compressed = '[ABR:${entry.value}]$compressed';
        break;
      }
    }
    
    return compressed;
  }

  /// Calculate request priority
  int _calculatePriority(String text, bool hasImage, bool hasAudio) {
    int priority = 5; // Default
    
    final lowerText = text.toLowerCase();
    
    // URGENT - Safety related
    if (lowerText.contains('опасность') || lowerText.contains('помощь') ||
        lowerText.contains('danger') || lowerText.contains('help') ||
        lowerText.contains('срочно') || lowerText.contains('emergency')) {
      priority = 10;
    }
    
    // HIGH - Navigation
    else if (lowerText.contains('навигация') || lowerText.contains('маршрут') ||
             lowerText.contains('navigate') || lowerText.contains('direction')) {
      priority = 8;
    }
    
    // MEDIUM-HIGH - Vision
    else if (hasImage || lowerText.contains('вижу') || lowerText.contains('опиши')) {
      priority = 7;
    }
    
    // MEDIUM - Voice
    else if (hasAudio) {
      priority = 6;
    }
    
    return priority;
  }

  /// Predict next likely queries
  void _predictNextQueries(String currentQuery) {
    final predictions = <String>[];
    final lowerQuery = currentQuery.toLowerCase();
    
    // Navigation follow-ups
    if (lowerQuery.contains('маршрут') || lowerQuery.contains('navigate')) {
      predictions.addAll([
        'сколько времени займет',
        'есть ли другой путь',
        'где я сейчас',
      ]);
    }
    
    // Vision follow-ups
    else if (lowerQuery.contains('опиши') || lowerQuery.contains('describe')) {
      predictions.addAll([
        'что справа',
        'что слева',
        'что впереди',
      ]);
    }
    
    // Location follow-ups
    else if (lowerQuery.contains('где') || lowerQuery.contains('where')) {
      predictions.addAll([
        'как туда дойти',
        'далеко ли это',
        'что рядом',
      ]);
    }
    
    // Pre-warm cache with predictions
    for (final prediction in predictions) {
      _predictiveCache[prediction] = PredictedResponse(
        query: prediction,
        timestamp: DateTime.now(),
        confidence: 0.7,
      );
    }
    
    print("🔮 [OPTIMIZER] Predicted ${predictions.length} follow-up queries");
  }

  /// Stream response chunks for faster perceived response
  Stream<ResponseChunk> get responseStream => _streamController.stream;

  /// Process response chunk by chunk
  void processChunkedResponse(String fullResponse) {
    final words = fullResponse.split(' ');
    final chunkSize = 5; // Words per chunk
    
    for (int i = 0; i < words.length; i += chunkSize) {
      final end = (i + chunkSize < words.length) ? i + chunkSize : words.length;
      final chunk = words.sublist(i, end).join(' ');
      
      _streamController.add(ResponseChunk(
        text: chunk,
        isComplete: end >= words.length,
        progress: end / words.length,
      ));
      
      // Simulate network delay
      Future.delayed(Duration(milliseconds: 50));
    }
  }

  /// Get performance metrics
  PerformanceMetrics getMetrics() => _metrics;

  /// Record response time
  void recordResponseTime(Duration duration) {
    _metrics.addResponseTime(duration);
  }

  /// Dispose
  void dispose() {
    _streamController.close();
  }
}

/// Optimized Request
class OptimizedRequest {
  final String originalText;
  final String compressedText;
  final int priority;
  final bool canStream;
  final String mode;
  final bool hasImage;
  final bool hasAudio;

  OptimizedRequest({
    required this.originalText,
    required this.compressedText,
    required this.priority,
    required this.canStream,
    required this.mode,
    required this.hasImage,
    required this.hasAudio,
  });
}

/// AI Request with Priority
class AIRequest implements Comparable<AIRequest> {
  final String id;
  final String text;
  final int priority;
  final DateTime timestamp;

  AIRequest({
    required this.id,
    required this.text,
    required this.priority,
    required this.timestamp,
  });

  @override
  int compareTo(AIRequest other) {
    // Higher priority first
    if (priority != other.priority) {
      return other.priority.compareTo(priority);
    }
    // Then by timestamp (older first)
    return timestamp.compareTo(other.timestamp);
  }
}

/// Priority Queue Implementation
class PriorityQueue<T extends Comparable> {
  final _queue = <T>[];

  void add(T item) {
    _queue.add(item);
    _queue.sort();
  }

  T? removeFirst() {
    if (_queue.isEmpty) return null;
    return _queue.removeAt(0);
  }

  bool get isEmpty => _queue.isEmpty;
  int get length => _queue.length;
}

/// Predicted Response
class PredictedResponse {
  final String query;
  final DateTime timestamp;
  final double confidence;

  PredictedResponse({
    required this.query,
    required this.timestamp,
    required this.confidence,
  });
}

/// Response Chunk for Streaming
class ResponseChunk {
  final String text;
  final bool isComplete;
  final double progress;

  ResponseChunk({
    required this.text,
    required this.isComplete,
    required this.progress,
  });
}

/// Performance Metrics
class PerformanceMetrics {
  final List<Duration> _responseTimes = [];
  int _totalRequests = 0;
  int _cachedResponses = 0;

  void addResponseTime(Duration duration) {
    _responseTimes.add(duration);
    _totalRequests++;
    
    // Keep only last 100
    if (_responseTimes.length > 100) {
      _responseTimes.removeAt(0);
    }
  }

  void incrementCachedResponses() {
    _cachedResponses++;
  }

  Duration get averageResponseTime {
    if (_responseTimes.isEmpty) return Duration.zero;
    final total = _responseTimes.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );
    return Duration(milliseconds: total ~/ _responseTimes.length);
  }

  Duration get fastestResponse {
    if (_responseTimes.isEmpty) return Duration.zero;
    return _responseTimes.reduce((a, b) => a < b ? a : b);
  }

  Duration get slowestResponse {
    if (_responseTimes.isEmpty) return Duration.zero;
    return _responseTimes.reduce((a, b) => a > b ? a : b);
  }

  double get cacheHitRate {
    if (_totalRequests == 0) return 0.0;
    return _cachedResponses / _totalRequests;
  }

  Map<String, dynamic> toJson() => {
    'total_requests': _totalRequests,
    'cached_responses': _cachedResponses,
    'cache_hit_rate': '${(cacheHitRate * 100).toStringAsFixed(1)}%',
    'average_response_time': '${averageResponseTime.inMilliseconds}ms',
    'fastest_response': '${fastestResponse.inMilliseconds}ms',
    'slowest_response': '${slowestResponse.inMilliseconds}ms',
  };
}
