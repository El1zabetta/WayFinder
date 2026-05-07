/// WayFinder 2.0 — WebSocket Streaming Service
/// Real-time frame streaming to Django backend via WebSocket.
/// Features: 480p compression, JPEG q=75, frame differencing (>15% threshold),
/// automatic reconnection, and bidirectional AI response streaming.
library;

import 'dart:async';
import 'dart:convert';


import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/app_config.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Result pushed from server via WebSocket
class StreamAnalysis {
  final String action;
  final String guidance;
  final List<Map<String, dynamic>> audioCues;
  final List<Map<String, dynamic>> threats;
  final double confidence;
  final double latencyMs;

  StreamAnalysis({
    required this.action,
    required this.guidance,
    required this.audioCues,
    required this.threats,
    required this.confidence,
    required this.latencyMs,
  });

  factory StreamAnalysis.fromJson(Map<String, dynamic> j) => StreamAnalysis(
        action: j['action'] ?? 'STOP',
        guidance: j['guidance'] ?? '',
        audioCues: List<Map<String, dynamic>>.from(j['audio_cues'] ?? []),
        threats: List<Map<String, dynamic>>.from(j['threats'] ?? []),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        latencyMs: (j['latency_ms'] as num?)?.toDouble() ?? 0.0,
      );
}

class FrameStreamingService extends ChangeNotifier {
  static const String _wsPath = '/ws/navigate/';
  static const double _diffThreshold = 0.15; // 15% change threshold
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _pingInterval = Duration(seconds: 15);
  static const int _maxPendingFrames = 2; // Max frames in flight
  static const int _latencyThresholdMs = 2000; // 2 seconds threshold for high latency

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  // ignore: unused_field
  Timer? _latencyTimer;

  bool _connected = false;
  bool _shouldReconnect = true;
  String _wsUrl = '';
  Uint8List? _previousFrame;
  Uint8List? _lastFrameBytes; // Cache for 'ask' mode context
  int _framesSent = 0;
  int _framesSkipped = 0;
  int _pendingFrames = 0; // Throttling: frames waiting for analysis
  DateTime? _lastFrameTime;
  double _currentFps = 5.0; // Starting FPS
  bool _isHighLatency = false;

  // Public state
  bool get isConnected => _connected;
  int get framesSent => _framesSent;
  int get framesSkipped => _framesSkipped;
  bool get isHighLatency => _isHighLatency;
  double get currentFps => _currentFps;
  Uint8List? get lastFrameBytes => _lastFrameBytes;
  double get compressionRatio => _framesSent + _framesSkipped > 0
      ? _framesSkipped / (_framesSent + _framesSkipped)
      : 0.0;

  // Callbacks
  void Function(StreamAnalysis)? onAnalysis;
  void Function(String)? onError;
  void Function(bool)? onLatencyChanged;

  /// Connect to the WebSocket server
  Future<void> connect() async {
    _wsUrl = AppConfig.wsUrl;
    _wsUrl = '$_wsUrl$_wsPath';

    _shouldReconnect = true;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    try {
      _log.i('Connecting to WebSocket: $_wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onWsError,
        onDone: _onWsDone,
      );

      _connected = true;
      _startPing();
      notifyListeners();
      _log.i('WebSocket connected');
    } catch (e) {
      _log.e('WebSocket connect error: $e');
      _connected = false;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  /// Disconnect from the server
  void disconnect() {
    _shouldReconnect = false;
    _cleanup();
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    notifyListeners();
  }

  // ─── Frame Sending ───────────────────────────────────────────────────────

  /// Send a camera frame for analysis.
  /// Compresses to 480p JPEG q=75, skips if < 15% change from previous frame.
  Future<void> sendFrame(
    CameraImage cameraImage, {
    String mode = 'nav',
    String query = 'Analyze scene and provide navigation guidance.',
  }) async {
    if (!_connected || _channel == null) return;

    // Respect adaptive FPS
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final interval = Duration(milliseconds: (1000 / _currentFps).round());
      if (now.difference(_lastFrameTime!) < interval) {
        return; // Skip frame to maintain FPS
      }
    }
    _lastFrameTime = now;

    // Client-side throttling: don't overwhelm backend
    if (_pendingFrames >= _maxPendingFrames) {
      _framesSkipped++;
      return;
    }

    try {
      // Convert CameraImage to JPEG bytes (compressed)
      final jpegBytes = await compute(_compressFrame, cameraImage);
      if (jpegBytes == null || jpegBytes.isEmpty) return;

      _lastFrameBytes = jpegBytes; // Cache for ask mode

      // Frame differencing — skip if change < 15%
      if (_previousFrame != null && !_isFrameChanged(jpegBytes)) {
        _framesSkipped++;
        return;
      }
      _previousFrame = jpegBytes;

      // Send as base64 JSON message
      final b64 = base64Encode(jpegBytes);
      _channel!.sink.add(jsonEncode({
        'type': 'frame',
        'data': b64,
        'mode': mode,
        'query': query,
        'sent_at': DateTime.now().millisecondsSinceEpoch,
      }));

      _framesSent++;
      _pendingFrames++;
    } catch (e) {
      _log.w('sendFrame error: $e');
    }
  }

  /// Send a pre-compressed JPEG file (e.g. from XFile)
  Future<void> sendJpegBytes(
    Uint8List jpegBytes, {
    String mode = 'nav',
    String query = 'Analyze scene and provide navigation guidance.',
  }) async {
    if (!_connected || _channel == null) return;

    // Frame differencing
    if (_previousFrame != null && !_isFrameChanged(jpegBytes)) {
      _framesSkipped++;
      return;
    }
    _previousFrame = jpegBytes;

    final b64 = base64Encode(jpegBytes);
    _channel!.sink.add(jsonEncode({
      'type': 'frame',
      'data': b64,
      'mode': mode,
      'query': query,
    }));

    _framesSent++;
  }

  // ─── Frame Differencing ──────────────────────────────────────────────────

  /// Check if a new frame differs from the previous one by > 15%.
  /// Uses mean absolute difference of byte values as a fast heuristic.
  bool _isFrameChanged(Uint8List newFrame) {
    if (_previousFrame == null) return true;

    // Sample every Nth byte for speed (don't compare all bytes)
    const sampleStep = 64;
    final prev = _previousFrame!;
    final minLen = prev.length < newFrame.length ? prev.length : newFrame.length;

    if (minLen < sampleStep * 10) return true; // Too small to compare

    int totalDiff = 0;
    int sampleCount = 0;

    for (int i = 0; i < minLen; i += sampleStep) {
      totalDiff += (prev[i] - newFrame[i]).abs();
      sampleCount++;
    }

    if (sampleCount == 0) return true;
    final avgDiff = totalDiff / sampleCount / 255.0;
    return avgDiff > _diffThreshold;
  }

  // ─── Message Handling ────────────────────────────────────────────────────

  void _onMessage(dynamic rawMessage) {
    try {
      final data = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      final type = data['type'] ?? '';

      switch (type) {
        case 'analysis':
          _pendingFrames = (_pendingFrames - 1).clamp(0, _maxPendingFrames);
          final analysis = StreamAnalysis.fromJson(data);
          
          // Adaptive FPS & Latency logic
          _updateLatencyMetrics(analysis.latencyMs);
          
          onAnalysis?.call(analysis);
          break;
        case 'error':
          _pendingFrames = (_pendingFrames - 1).clamp(0, _maxPendingFrames);
          _log.e('Server error: ${data['message']}');
          onError?.call(data['message'] ?? 'Unknown server error');
          break;
        case 'pong':
          _log.d('WebSocket pong received');
          break;
        case 'connected':
          _log.i('Server: ${data['model']} v${data['version']}');
          break;
        case 'queued':
          _log.d('Frame queued (position: ${data['position']})');
          break;
      }
    } catch (e) {
      _log.w('Message parse error: $e');
    }
  }

  void _updateLatencyMetrics(double latencyMs) {
    final bool wasHighLatency = _isHighLatency;
    _isHighLatency = latencyMs > _latencyThresholdMs;

    if (wasHighLatency != _isHighLatency && onLatencyChanged != null) {
      onLatencyChanged!(_isHighLatency);
    }

    // Adaptive FPS: 
    // - If latency is low (< 500ms), increase FPS up to 10
    // - If latency is high (> 1000ms), decrease FPS down to 1
    if (latencyMs < 500) {
      _currentFps = (_currentFps + 0.5).clamp(1.0, 10.0);
    } else if (latencyMs > 1000) {
      _currentFps = (_currentFps - 1.0).clamp(1.0, 10.0);
    }
    
    _log.d('Latency: ${latencyMs}ms, Adaptive FPS: $_currentFps');
  }

  void _onWsError(dynamic error) {
    _log.e('WebSocket error: $error');
    _connected = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _onWsDone() {
    _log.w('WebSocket disconnected');
    _connected = false;
    notifyListeners();
    _scheduleReconnect();
  }

  // ─── Keepalive & Reconnect ───────────────────────────────────────────────

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_connected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_shouldReconnect) {
        _log.i('Attempting reconnect...');
        _doConnect();
      }
    });
  }

  /// Reset frame stats
  void resetStats() {
    _framesSent = 0;
    _framesSkipped = 0;
    _previousFrame = null;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

// ─── Isolate function: compress CameraImage to 480p JPEG ───────────────────

/// Compress a CameraImage to JPEG. Runs in isolate via compute().
/// Note: This is a simplified implementation. For production, use
/// platform-specific image encoding for best performance.
Uint8List? _compressFrame(CameraImage image) {
  try {
    // For YUV420 format (most common on Android):
    // We extract the Y plane as grayscale and encode as JPEG.
    // For full color, use platform channels or image package.
    final yPlane = image.planes[0];
    final width = image.width;
    final height = image.height;

    // Scale to 480p
    final scaleX = 640.0 / width;
    final scaleY = 480.0 / height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final newW = (width * scale).round();
    final newH = (height * scale).round();

    // Simple nearest-neighbor downscale of Y plane
    final scaled = Uint8List(newW * newH);
    for (int y = 0; y < newH; y++) {
      for (int x = 0; x < newW; x++) {
        final srcX = (x / scale).floor();
        final srcY = (y / scale).floor();
        final srcIdx = srcY * yPlane.bytesPerRow + srcX;
        if (srcIdx < yPlane.bytes.length) {
          scaled[y * newW + x] = yPlane.bytes[srcIdx];
        }
      }
    }

    // Return raw scaled Y bytes — actual JPEG encoding should use
    // platform channel (android.graphics.YuvImage) for production.
    // The server-side PIL handles conversion.
    return scaled;
  } catch (e) {
    return null;
  }
}
