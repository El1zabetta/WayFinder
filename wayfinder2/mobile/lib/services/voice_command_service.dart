/// WayFinder 2.0 — Voice Command Service
/// Listens for voice commands for hands-free navigation control.
/// Uses speech_to_text with keyword extraction for WayFinder commands.

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Recognized WayFinder voice commands
enum VoiceCommand {
  navigate,     // "navigate to [place]"
  findObject,   // "find my [object]"
  safetyCheck,  // "safety check" / "is it safe"
  stopListening,// "stop"
  repeatLast,   // "repeat" / "say again"
  settings,     // "settings"
  unknown,
}

class VoiceCommandResult {
  final VoiceCommand command;
  final String rawText;
  final String? parameter; // Extracted target (e.g., the object name or destination)

  const VoiceCommandResult({
    required this.command,
    required this.rawText,
    this.parameter,
  });
}

class VoiceCommandService extends ChangeNotifier {
  bool _isListening = false;
  String _lastTranscript = '';
  VoiceCommandResult? _lastCommand;

  bool get isListening => _isListening;
  String get lastTranscript => _lastTranscript;
  VoiceCommandResult? get lastCommand => _lastCommand;

  void simulateVoiceInput(String text) {
    _lastTranscript = text;
    _lastCommand = _parseCommand(text);
    notifyListeners();
  }

  /// Parse raw voice transcript into structured command.
  VoiceCommandResult _parseCommand(String text) {
    final lower = text.toLowerCase().trim();

    // "navigate to X" / "go to X" / "take me to X"
    final navMatch = RegExp(r'(?:navigate|go|take me|walk)(?:\s+to)?\s+(.+)')
        .firstMatch(lower);
    if (navMatch != null) {
      return VoiceCommandResult(
        command: VoiceCommand.navigate,
        rawText: text,
        parameter: navMatch.group(1)?.trim(),
      );
    }

    // "find my X" / "where is X" / "search for X"
    final findMatch = RegExp(r'(?:find|where is|search for|locate)\s+(?:my\s+)?(.+)')
        .firstMatch(lower);
    if (findMatch != null) {
      return VoiceCommandResult(
        command: VoiceCommand.findObject,
        rawText: text,
        parameter: findMatch.group(1)?.trim(),
      );
    }

    // Safety check
    if (lower.contains('safe') || lower.contains('danger') || lower.contains('hazard')) {
      return VoiceCommandResult(
        command: VoiceCommand.safetyCheck,
        rawText: text,
      );
    }

    // Stop
    if (lower == 'stop' || lower == 'cancel' || lower == 'quit') {
      return VoiceCommandResult(
        command: VoiceCommand.stopListening,
        rawText: text,
      );
    }

    // Repeat
    if (lower.contains('repeat') || lower.contains('say again') || lower.contains('again')) {
      return VoiceCommandResult(
        command: VoiceCommand.repeatLast,
        rawText: text,
      );
    }

    return VoiceCommandResult(command: VoiceCommand.unknown, rawText: text);
  }
}
