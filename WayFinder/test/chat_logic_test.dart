import 'package:flutter_test/flutter_test.dart';
import 'package:way_finder/services/chat_history_service.dart';

void main() {
  group('ChatHistoryService Tests', () {
    test('ChatMessage JSON serialization', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        text: 'Hello test',
        isUser: true,
        timestamp: now,
      );

      final json = msg.toJson();
      expect(json['text'], 'Hello test');
      expect(json['isUser'], true);
      expect(json['timestamp'], now.toIso8601String());

      final fromJson = ChatMessage.fromJson(json);
      expect(fromJson.text, msg.text);
      expect(fromJson.isUser, msg.isUser);
      // Compare ISO strings to avoid millisecond precision issues with DateTime objects
      expect(fromJson.timestamp.toIso8601String(), msg.timestamp.toIso8601String());
    });
  });
}
