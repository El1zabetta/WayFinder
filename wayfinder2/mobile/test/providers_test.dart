import 'package:flutter_test/flutter_test.dart';
import 'package:wayfinder2/core/secrets.dart';

void main() {
  group('Secrets Tests', () {
    test('Default picovoiceAccessKey should be empty', () {
      expect(Secrets.picovoiceAccessKey, '');
      expect(Secrets.hasPicovoiceKey, false);
    });
  });
}
